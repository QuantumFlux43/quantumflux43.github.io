---
title: "Fermat Exponent Collapse dan Integer Division Leak"
date: 2026-08-26 10:00:00 +0700
lang: id
ref: fermat-exponent-collapse-integer-division-leak
platform: knowledge
kn_cat: rsa
tags: [fermat-little-theorem, integer-division, bit-length, multiprime, partial-leak]
description: Pola serangan di mana noise (rand) dibikin lebih kecil dari modulus, sehingga struktur rahasia bocor lewat Fermat exponent collapse dan pembagian bulat. Recover faktor RSA tanpa faktorisasi.
---

Banyak soal RSA "custom" tidak minta faktorisasi langsung, tapi memberi
beberapa *hint* yang katanya mengacak rahasia dengan noise. Kelemahan klasik:
**noise dibuat jauh lebih kecil dari term rahasia**, sehingga strukturnya bocor
lewat dua alat sederhana — Fermat's Little Theorem dan pembagian bulat. Catatan
ini merangkum polanya secara umum, dipisah dari writeup soal spesifik.

## Alat 1: Fermat Exponent Collapse

Fermat's Little Theorem: kalau `p` prima dan `gcd(a, p) = 1`, maka

$$
a^{p-1} \equiv 1 \pmod{p}
$$

Konsekuensi penting untuk CTF: **pangkat raksasa runtuh ke pangkat kecil**,
karena yang menentukan hasil hanya sisa pangkat dibagi `p-1`.

$$
a^{E} \equiv a^{E \bmod (p-1)} \pmod{p}
$$

Contoh pola yang sering muncul: server menghitung `hint = pow(x, 4*p, p)` dengan
`p` prima. Reduksi pangkat:

$$
4p \bmod (p-1) = 4(p-1) + 4 \bmod (p-1) = 4
$$

karena `p = (p-1) + 1`. Jadi `4p = 4(p-1) + 4`, bagian `4(p-1)` hilang. Hasilnya

$$
\text{hint} = x^{4p} \bmod p = x^{4} \bmod p
$$

Pangkat `4p` (2048-bit) runtuh jadi pangkat `4`. Sekarang tinggal ambil **akar
pangkat 4 modulo prima** — akar-2 dua kali pakai Tonelli-Shanks (`sqrt_mod` di
sympy), tiap level menghasilkan dua kandidat (`+r`, `-r`), total sampai 4 akar.

```python
from sympy.ntheory.residue_ntheory import sqrt_mod

# hint = x^4 mod modd, ambil semua akar-4
sq = sqrt_mod(hint, modd)
level2 = {sq % modd, (-sq) % modd}
roots = set()
for s in level2:
    r = sqrt_mod(s, modd)
    if r is not None:
        roots.add(r % modd); roots.add((-r) % modd)
```

> Jangan pakai `nthroot_mod(hint, 4, modd, all_roots=True)` pada modulus
> 2048-bit — lambat sekali. Dua kali `sqrt_mod` jauh lebih cepat (< 0.1 detik).

### Memilih kandidat yang benar: bit-length

Ada sampai 4 akar. Yang benar dipilih lewat **ukuran bit**. Kalau rahasia `x`
diketahui lebih kecil dari modulus (mis. `x ≈ 2^1279`, `modd ≈ 2^2048`), maka
operasi mod tidak pernah memotong `x`. Kandidat asli = satu-satunya yang punya
bit-length mendekati ukuran asli; sisanya nilai acak seukuran `modd`.

```python
cands = [r for r in roots if 1200 <= r.bit_length() <= 1300]
```

## Alat 2: Integer Division Leak

Persamaan seperti `hidden = n*z + rand` adalah **pembagian bersisa**:

$$
\text{hidden} = n \cdot z + \text{rand}, \qquad z = \text{hasil bagi},\ \text{rand} = \text{sisa}
$$

Kalau `rand < n`, maka `hidden // n = z` persis. Masalah muncul kalau sisa
`rand` sedikit lebih besar dari pembagi `n`: sisa "tumpah" ke hasil bagi.
Besarnya tumpahan dihitung dari selisih bit:

$$
\frac{\text{rand}}{n} \approx 2^{\,\text{bit(rand)} - \text{bit}(n)}
$$

Contoh: `rand ≈ 2^1035`, `n ≈ 2^1024` → tumpahan `≈ 2^{11} ≈ 2000`. Artinya
`hidden // n` meleset dari `z` paling banyak ~2000. Karena kecil, cukup
brute-force geser di sekitar hasil bagi:

```python
approx = hidden // n
for delta in range(0, 4000):
    for z in (approx - delta, approx + delta):
        rand = hidden - n * z
        if 0 <= rand and rand.bit_length() <= 1040:
            # verifikasi z (mis. lewat faktor yang membuat n habis dibagi)
            ...
```

## Alat 3: Term Dominan pada Penjumlahan

Kalau satu term jauh lebih besar dari sisanya, pembagian bulat membuang yang
kecil. Aturan bit-length pada penjumlahan/perkalian:

- perkalian → **jumlah** bit: `bit(a*b) = bit(a) + bit(b)`
- pangkat → **kali** bit: `bit(a^k) = bit(a) * k`
- penjumlahan → ambil **maksimum**: `bit(a+b) = max(bit a, bit b)`

Contoh: `hint = z3^8 * z2 + K*z2*z1^2 + rand2` dengan bit-length

| term | perkiraan bit |
|---|---|
| `z3^8 * z2` (256·8 + 512) | 2560 |
| `K*z2*z1^2` (512 + 1024) | ~1536 |
| `rand2` | 1024 |

Selisih term pertama vs sisa ~1000 bit. Bagi `hint` dengan `z3^8` (≈ 2048-bit):
term kedua+ketiga (≈ 2^1536) jadi `< 1` dan lenyap.

$$
\text{hint} // z3^{8} = z2 \quad (\text{persis})
$$

**Aturan praktis:** kalau selisih bit dua kuantitas `≥ ~30`, yang kecil bisa
dianggap nol dalam pembagian bulat.

## Rangkaian penuh (contoh soal multiprime + hint)

Diberi `n = z1*z2`, `modd` prima, dan dua hint:
`hint_1 = z3^8*z2 + c*z2*z1^2 + rand_2`,
`hint_2 = pow(z1*z2*z3 + rand_1, 4*modd, modd)`.

1. **Buka `hint_2`:** Fermat collapse → `hint_2 = hidden^4 mod modd`. Akar-4,
   pilih kandidat dengan bit ~1279 → dapat `hidden = n*z3 + rand_1` exact.
2. **Recover `z3`:** `z3 ≈ hidden // n`, meleset ~2000 → brute delta kecil.
3. **Faktor `n`:** `z2 = hint_1 // z3^8` (term dominan), lalu `z1 = n // z2`.
4. **Decrypt RSA:** `phi = (z1-1)(z2-1)`, `d = e^{-1} mod phi`, `m = c^d mod n`.

```python
from Crypto.Util.number import inverse, long_to_bytes

def try_hidden(hidden, n, hint_1, e, c):
    approx = hidden // n
    for delta in range(4000):
        for z3 in (approx - delta, approx + delta):
            rand_1 = hidden - n * z3
            if rand_1 < 0 or rand_1.bit_length() > 1040:
                continue
            z2 = hint_1 // (z3 ** 8)          # term z3^8 dominan
            if z2 <= 1 or n % z2:
                continue
            z1 = n // z2
            phi = (z1 - 1) * (z2 - 1)
            m = pow(c, inverse(e, phi), n)
            if pow(m, e, n) == c:
                return long_to_bytes(m)
```

## Checklist deteksi cepat

Refleks saat ketemu soal "hint mengacak rahasia":

1. **Print bit-length semua variabel dan tiap term rumus dulu.** Angka asli
   300-digit tidak berguna; bit-length 3-digit langsung menunjukkan struktur.
2. **Pangkat besar mod prima?** → cek Fermat, hitung `exp mod (p-1)`. Sering
   runtuh ke pangkat kecil.
3. **Noise lebih kecil dari modulus/pembagi?** → integer division bocor
   (`hidden // n` = rahasia, mungkin meleset kecil → brute).
4. **Satu term jauh lebih besar?** → term kecil kebuang di `//` (selisih bit ≥ 30).
5. **Rahasia lebih kecil dari mod?** → mod tidak menyembunyikan, recover penuh.

Inti kelemahan: desainer memilih ukuran noise yang **kekecilan** relatif
terhadap term rahasia, sehingga bit-length rahasia "menonjol" dan bocor lewat
operasi bulat yang deterministik.

## Syarat agar nilai bisa direcover

Serangan ini **hanya** jalan kalau kondisi ukuran di bawah terpenuhi. Kalau
desainer memilih noise cukup besar, tiap langkah gagal. Notasi: `bit(x)` =
`x.bit_length()`.

### Syarat Alat 1 (Fermat collapse + akar-4)

1. **Modulus prima.** `modd` harus prima supaya Fermat berlaku dan akar-2 mod
   `modd` bisa dihitung Tonelli-Shanks. Kalau komposit, `p-1` tak terdefinisi
   dan akar butuh faktorisasi.
2. **Basis koprima ke modulus.** `gcd(x, modd) = 1` (hampir selalu benar untuk
   `modd` prima besar).
3. **Rahasia lebih kecil dari modulus:** `bit(hidden) < bit(modd)`. Kalau
   `hidden ≥ modd`, operasi mod memotong nilai dan akar-4 tidak lagi mengembalikan
   `hidden` asli.
4. **Bit-length rahasia unik di antara kandidat akar.** Range filter
   (`1200 ≤ r.bit_length() ≤ 1300`) hanya menyisakan satu kandidat kalau
   `bit(hidden)` cukup jauh dari `bit(modd)`. Kalau `hidden` hampir seukuran
   `modd`, kandidat asli tidak bisa dibedakan dari akar acak.

### Syarat Alat 2 (integer division leak)

Persamaan `hidden = n·z + rand`. Error hasil bagi:

$$
\left| \frac{\text{hidden}}{n} - z \right| \approx \frac{\text{rand}}{n} \approx 2^{\,\text{bit(rand)} - \text{bit}(n)}
$$

- **Kasus ideal:** `bit(rand) ≤ bit(n)` → `rand < n` → `hidden // n = z` **exact**,
  tanpa brute.
- **Kasus brute (soal ini):** `bit(rand) - bit(n) ≲ 20` (mis. selisih 11 →
  error ~2000). Range brute `delta` harus `≥ 2^(bit(rand) - bit(n))`.
- **Gagal:** kalau `bit(rand) - bit(n) ≳ 40`, error `≳ 2^40` → range brute tidak
  praktis. Di sini keamanan "benar" seharusnya: buat `rand` seukuran `n·z`
  (mis. `bit(rand) ≈ bit(hidden)`) supaya `hidden // n` tak berkorelasi ke `z`.

Syarat umum langkah ini:

$$
\text{bit(rand)} - \text{bit}(n) \;\lesssim\; 20 \quad (\text{brute praktis})
$$

### Syarat Alat 3 (term dominan)

Untuk `hint = A + B + C` dengan `A` term dominan (`A = z3^8·z2`), pembagian
`hint // D` (dengan `D = z3^8`) mengembalikan `z2` **exact** hanya kalau term
sisa lenyap di pembagian bulat:

$$
\text{bit}(B + C) \;<\; \text{bit}(D) \quad\Longleftrightarrow\quad \frac{B + C}{D} < 1
$$

Praktisnya butuh margin: **selisih bit `≥ ~30`** antara term dominan `A` dan
gabungan term sisa. Kalau `bit(B+C) ≥ bit(D)`, sisa bocor ke hasil bagi dan
`z2` meleset (tak selalu bisa dibrute karena meleset bisa besar).

### Syarat langkah decrypt

- Faktorisasi `n = z1·z2` berhasil (`z2` exact dari langkah sebelumnya).
- `gcd(e, phi) = 1` supaya `d = e^{-1} mod phi` ada (default `e = 65537` aman).

### Ringkasan bound

| Langkah | Syarat wajib |
|---|---|
| Fermat + akar-4 | `modd` prima; `bit(hidden) < bit(modd)` dengan gap cukup |
| Integer division | `bit(rand) - bit(n) ≲ 20` (atau `< 0` untuk exact) |
| Term dominan | `bit(term_dominan) - bit(term_sisa) ≥ ~30` |
| Decrypt | `gcd(e, phi) = 1` |

Kalau **satu** syarat ukuran gagal, langkah bersangkutan tidak bisa direcover —
itulah cara desainer menutup celah (perbesar noise sampai seukuran term rahasia).

## Referensi

- Fermat's Little Theorem — dasar reduksi eksponen modular.
- Tonelli-Shanks (`sympy.ntheory.residue_ntheory.sqrt_mod`) — akar kuadrat mod prima.
- Dasar bit-length reasoning: lihat juga [Cube Root Attack](/posts/2026/08/16/easy-babyrsa-cube-root/) untuk pola "pesan < modulus".
