---
title: "Pohlig-Hellman dan Partial Factor Recovery mod 2^k"
date: 2026-08-26 11:00:00 +0700
lang: id
ref: pohlig-hellman-partial-factor-recovery
platform: knowledge
kn_cat: rsa
tags: [discrete-log, pohlig-hellman, bsgs, smooth-prime, multiprime, partial-leak]
description: Recover eksponen rahasia lewat discrete log saat p-1 smooth (Pohlig-Hellman + BSGS), lalu faktor RSA multiprime dari bocoran sebagian bit q*r modulo 2^k.
---

Pola soal: sebuah *hint* menyembunyikan rahasia `s` di dalam kombinasi pangkat
modular `e^s`, dan `s` sendiri adalah bocoran sebagian dari faktor RSA (mis.
`s = (q*r) mod 2^k`). Kalau modulus hint prima dengan `p-1` **smooth**, discrete
log jadi feasible lewat Pohlig-Hellman; lalu bocoran sebagian cukup untuk
memfaktorkan RSA multiprime lewat aritmetika mod `2^k`.

## Alat 1: Menyederhanakan hint jadi persamaan polinomial

Sering hint berbentuk kombinasi `e^s`, `e^{-s}`, `e^{-2s}`. Contoh:

```python
a = inverse(e, N)      # a = e^-1 mod N
b = pow(a, 2, N)       # b = e^-2 mod N
u = (pow(e, s, N) + pow(a, s, N) + pow(b, s, N)) % N
```

Substitusi `a = e^{-1}`, `b = e^{-2}`:

$$
u = e^{s} + e^{-s} + e^{-2s} \pmod N
$$

Kalikan `e^{2s}` untuk membuang pangkat negatif, lalu misalkan `X = e^{s}`:

$$
u \cdot e^{2s} = e^{3s} + e^{s} + 1
\;\Longrightarrow\;
X^{3} - u\,X^{2} + X + 1 \equiv 0 \pmod N
$$

`N` prima → faktorkan polinomial ini mod `N`, ambil akar linear `X = e^s`.

```python
import sympy
from Crypto.Util.number import inverse

x = sympy.symbols('x')
poly = sympy.Poly(x**3 - u*x**2 + x + 1, x, modulus=N)
roots = []
for fac, _ in poly.factor_list()[1]:
    if fac.degree() == 1:
        a1, a0 = fac.all_coeffs()
        roots.append((-a0 * inverse(int(a1), N)) % N)
```

## Alat 2: Discrete Log saat p-1 smooth (Pohlig-Hellman)

Punya `X = e^s mod N`, mau `s`. Ini **discrete logarithm** — umumnya keras.
**Celah:** kalau `N-1` smooth (semua faktor prima kecil), dlog jadi mudah.

> **Refleks:** tiap ketemu dlog, faktorkan `N-1` dulu. Kalau semua faktor
> ≤ ~2^20, langsung pikirkan Pohlig-Hellman.

Ide Pohlig-Hellman: pecah `s` menjadi `s mod p` untuk tiap faktor prima `p` dari
`N-1`, lalu gabung dengan CRT. Tiap `s mod p` dicari di range `0..p` (kecil)
pakai baby-step giant-step (`~√p` langkah).

```python
from math import isqrt
from sympy.ntheory.modular import crt

def bsgs(g, h, mod, nord):
    step = isqrt(nord) + 1
    tbl, cur = {}, 1
    for j in range(step):
        tbl.setdefault(cur, j); cur = cur * g % mod
    fac = pow(g, (mod - 1 - step) % (mod - 1), mod)   # g^-step
    gamma = h
    for i in range(step):
        if gamma in tbl:
            return i * step + tbl[gamma]
        gamma = gamma * fac % mod
    return None

def pohlig_hellman(base, target, N, facs):   # facs = {p: k, ...} faktor N-1
    order = N - 1
    res, mods = [], []
    for p, k in facs.items():
        pk = p ** k; exp = order // pk
        gp = pow(base, exp, N); hp = pow(target, exp, N)
        xacc = 0; gamma = pow(gp, p ** (k - 1), N)
        for j in range(k):
            tmp = pow(gp, (-xacc) % (N - 1), N) * hp % N
            hj = pow(tmp, p ** (k - 1 - j), N)
            dj = bsgs(gamma, hj, N, p)
            xacc += dj * (p ** j)
        res.append(xacc % pk); mods.append(pk)
    return int(crt(mods, res)[0])
```

> `sympy.discrete_log` bisa error/lambat (butuh `order_factors`, atau stuck).
> Implementasi manual PH + BSGS lebih terkontrol — dlog 780-bit selesai < 0.3 detik
> kalau `N-1` smooth. Faktorkan `N-1` dengan trial division saja (smooth → cepat).

## Alat 3: Partial Factor Recovery mod 2^k

Hasil dlog `s` sering hanya bocoran sebagian: `s = (q*r) mod 2^k`, yaitu `k` bit
bawah dari `q*r`. Untuk multiprime `n = p*q*r = p*(qr)`, ambil **mod 2^k** kedua
sisi:

$$
n \equiv p \cdot (qr) \equiv p \cdot s \pmod{2^{k}}
$$

Bagi dengan `s` (kali inversnya mod `2^k`):

$$
p \equiv (n \bmod 2^{k}) \cdot s^{-1} \pmod{2^{k}}
$$

Karena `p < 2^k` (mis. `p` 512-bit, `k = 512`), "512 bit bawah `p`" = `p`
seluruhnya → **recover `p` exact**. Ini pola yang sama dengan integer division
leak: *rahasia lebih kecil dari modulus → mod tidak menyembunyikan*.

```python
M = 1 << 512
p = (n % M) * inverse(s % M, M) % M      # p exact (p < 2^512)
assert n % p == 0
qr = n // p
```

## Alat 4: Decrypt tanpa memfaktorkan qr

Untuk RSA multiprime butuh `phi = (p-1)(q-1)(r-1)`, artinya butuh `q`, `r`
terpisah — dan memfaktorkan `qr` (produk dua prima 512-bit) itu keras.
**Shortcut lewat bit-length:** kalau plaintext `m` lebih kecil dari `p`
(flag ~488-bit `< p` 512-bit), maka `m mod p = m`, jadi cukup decrypt **mod p**:

```python
d_p = inverse(e, p - 1)
m = pow(c % p, d_p, p)          # m < p => hasilnya m penuh
flag = long_to_bytes(m)
```

## Rangkaian penuh

Diberi `N` (prima, `N-1` smooth), `e`, `u = able(s)`, `n = p*q*r`, `c`.

1. **Sederhanakan `u`** → cubic `X^3 - uX^2 + X + 1 = 0 mod N`, cari akar `X = e^s`.
2. **Pohlig-Hellman** dlog → `s = (q*r) mod 2^k`.
3. **Partial recovery** → `p = (n mod 2^k) * s^{-1} mod 2^k` (exact).
4. **Decrypt mod p** (karena `m < p`) → flag.

## Checklist deteksi cepat

1. **Print bit-length** semua variabel dulu. Cek: `N` prima? `n` berapa faktor?
2. **`N-1` smooth?** (faktorkan cepat trial division) → dlog feasible via PH.
3. **Hint pakai `e^s`, `e^{-s}`?** → aljabar pangkat + substitusi `X = e^s` →
   polinomial, faktorkan mod prima.
4. **Bocoran mod 2^k dari faktor?** → `p = (n mod 2^k) * s^{-1} mod 2^k` kalau
   `p < 2^k`.
5. **`m < p`?** → decrypt satu prima cukup, tak perlu faktor lengkap.

## Syarat agar nilai bisa direcover

Tiap langkah punya prasyarat ukuran/struktur. Kalau salah satu gagal, rantai
putus. Notasi: `bit(x) = x.bit_length()`.

### Syarat Alat 1 (hint → polinomial)

1. **`N` prima.** Diperlukan supaya `inverse(e, N)` ada dan faktorisasi
   polinomial mod `N` (`sympy.Poly(..., modulus=N)`) valid.
2. **`gcd(e, N) = 1`** supaya `a = e^{-1} mod N` terdefinisi.
3. **Cubic punya akar linear mod N.** `X^3 - uX^2 + X + 1` harus punya minimal
   satu faktor derajat-1 (yaitu `X = e^s`). Untuk `s` valid, akar ini pasti ada;
   kalau tidak muncul, berarti `N` bukan prima atau hint bukan bentuk yang
   diasumsikan.

### Syarat Alat 2 (Pohlig-Hellman) — paling kritis

Discrete log `X = e^s mod N` feasible **hanya kalau `N-1` smooth**. Biaya PH
didominasi faktor prima terbesar `p_max` dari `N-1`:

$$
\text{biaya} \;\approx\; \sum_{p_i \mid (N-1)} \sqrt{p_i} \;\lesssim\; \#\text{faktor} \cdot \sqrt{p_{\max}}
$$

- **Berhasil (soal ini):** semua faktor `N-1` `≤ ~2^20` → `√p_max ≈ 2^10 ≈ 1000`
  langkah per faktor → total < 0.3 detik.
- **Batas praktis:** `p_max ≲ 2^40` masih feasible (`√p_max ≈ 2^20` = ~jutaan
  langkah BSGS, butuh memori tabel besar tapi masih jalan).
- **Gagal:** kalau `N-1` punya **satu** faktor prima besar (mis. `≥ 2^80`), PH
  buntu di faktor itu — persis kenapa RSA aman: modulus dipilih dengan `p-1`
  punya faktor besar. Ini syarat mati/hidup serangan.
4. **`e` menghasilkan orde yang memuat `s`.** `s` harus `< ord_N(e)`; kalau `e`
   berorde kecil, hasil dlog ambigu modulo orde. Untuk `e = 65537` dan `N` prima
   besar, orde biasanya besar → aman.

### Syarat Alat 3 (partial factor recovery mod 2^k)

Dari `n ≡ p·s (mod 2^k)`, kita solve `p = (n mod 2^k)·s^{-1} mod 2^k`.

1. **`s` invertible mod `2^k`** → `s` harus **ganjil** (`gcd(s, 2^k) = 1`).
   Kalau `q·r` genap (mustahil untuk prima ganjil `q, r`), gagal. Untuk RSA
   prima > 2 selalu ganjil → aman.
2. **Faktor yang direcover lebih kecil dari modulus bocoran:** `bit(p) ≤ k`.
   Di sini `p` 512-bit dan `k = 512` → `p < 2^k` → recover **exact**. Kalau
   `bit(p) > k`, hanya `k` bit bawah `p` yang didapat (parsial), butuh langkah
   lanjutan (mis. Coppersmith untuk sisa bit).
3. **`s` benar-benar `k` bit bawah dari `qr`.** Yaitu bocoran memang
   `(q·r) mod 2^k` dengan `k = bit(p)`. Kalau mask-nya beda (`mod 2^j`, `j ≠ k`),
   sesuaikan modulus `M = 1 << j`.

$$
\boxed{\;\text{bit}(p) \le k \;\text{ dan }\; s \text{ ganjil} \;\Longrightarrow\; p \text{ recover exact}\;}
$$

### Syarat Alat 4 (decrypt mod p saja)

- **`m < p`.** Plaintext harus lebih kecil dari `p` supaya `m mod p = m`.
  Cek: `bit(flag_bytes·8) < bit(p)`. Flag ~488-bit `<` `p` 512-bit → aman.
  Kalau `m ≥ p`, hasil `pow(c%p, d_p, p)` hanya `m mod p` (rusak) — harus
  faktorkan `qr` juga dan pakai CRT penuh.
- **`gcd(e, p-1) = 1`** supaya `d_p = e^{-1} mod (p-1)` ada.

### Ringkasan bound

| Langkah | Syarat wajib |
|---|---|
| hint → cubic | `N` prima; `gcd(e,N)=1`; ada akar linear |
| Pohlig-Hellman | **`N-1` smooth** (`p_max ≲ 2^40`); orde `e` besar |
| partial recovery | `s` ganjil; `bit(p) ≤ k` |
| decrypt mod p | `m < p`; `gcd(e, p-1) = 1` |

Syarat paling menentukan = **`N-1` smooth**. Kalau desainer memilih `N` dengan
`N-1` punya faktor prima besar, discrete log kembali keras dan seluruh rantai
gagal sejak Alat 2.

## Referensi

- Pohlig & Hellman (1978), "An Improved Algorithm for Computing Logarithms over GF(p)".
- Shanks — Baby-step Giant-step untuk DLP `O(√n)`.
- Smoothness `p-1`: prasyarat kunci; kalau ada satu faktor besar, PH gagal.
- Pola "rahasia < modulus": lihat juga [Fermat Exponent Collapse dan Integer Division Leak](/posts/2026/08/26/fermat-exponent-collapse-integer-division-leak/).
