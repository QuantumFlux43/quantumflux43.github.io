---
title: "Partial Factor Recovery mod 2^k"
date: 2026-08-26 12:00:00 +0700
lang: id
ref: partial-factor-recovery-mod-2k
platform: knowledge
kn_cat: rsa
tags: [partial-leak, mod-2k, multiprime, modular-inverse]
description: Kalau bocor sebagian bit bawah dari sebuah faktor (mod 2^k), sering cukup untuk recover faktor RSA lain exact lewat inverse modular mod 2^k. Tanpa faktorisasi.
---

Pengetahuan kecil tapi sering muncul: kalau kamu tahu **bit-bit bawah** dari
salah satu faktor (dalam bentuk `x mod 2^k`), dan modulusnya hasil kali faktor
itu dengan faktor lain, kamu bisa recover faktor lain lewat satu inverse modular
mod `2^k`. Sering bocor `k` bit bawah = cukup untuk recover faktor `k`-bit penuh.

## Ide dasar

Modulus RSA (atau multiprime) `n = a·b`. Misal bocor `s = b mod 2^k` (bit bawah
`b`). Ambil kedua sisi modulo `2^k`:

$$
n \equiv a \cdot b \equiv a \cdot s \pmod{2^{k}}
$$

Kalau `s` **ganjil** (`gcd(s, 2^k) = 1` — selalu benar untuk faktor prima ganjil),
maka `s` invertible mod `2^k`, jadi:

$$
a \equiv (n \bmod 2^{k}) \cdot s^{-1} \pmod{2^{k}}
$$

Kalau `bit(a) ≤ k`, hasil ini = `a` **exact** (mod `2^k` tidak memotong `a`).

```python
from Crypto.Util.number import inverse

M = 1 << k
a = (n % M) * inverse(s % M, M) % M     # a exact kalau bit(a) <= k
assert n % a == 0
```

## Kenapa jalan: rahasia < modulus

Ini contoh pola umum "**rahasia lebih kecil dari modulus → mod tidak
menyembunyikan**". `a` (`k`-bit) `< 2^k`, jadi `a mod 2^k = a`. Operasi mod `2^k`
cuma menyaring bit bawah; kalau seluruh `a` muat di `k` bit, seluruhnya kekembali.
Bandingkan dengan [Integer Division Leak](/posts/2026/08/26/integer-division-leak/)
yang polanya sama tapi lewat pembagian, bukan modular inverse.

## Inverse mod 2^k selalu ada untuk bilangan ganjil

Fakta berguna: **setiap bilangan ganjil punya inverse mod `2^k`**. Karena
`gcd(ganjil, 2^k) = 1`. Ini kenapa syarat "`s` ganjil" hampir selalu terpenuhi
untuk produk prima ganjil. (Kalau `s` genap, `n = a·s` juga tak bisa dibagi
langsung — butuh handle pangkat 2 terpisah.)

Ada juga cara Hensel lifting untuk menghitung inverse mod `2^k` bit-per-bit,
tapi `inverse(s, 1<<k)` di pycryptodome sudah cukup.

## Contoh mini (bisa dicek manual)

```python
from Crypto.Util.number import inverse
a = 0xADF3          # faktor "rahasia" 16-bit (ganjil)
b = 0xBEEF
n = a * b
k = 16
M = 1 << k
s = b % M           # bocoran: 16 bit bawah b (di sini b < 2^16 jadi s == b)
a_rec = (n % M) * inverse(s, M) % M
print(hex(a_rec))   # -> 0xadf3, exact
```

## Variasi: bocoran lebih kecil dari faktor

Kalau `bit(a) > k` (bocoran `k` bit bawah, tapi `a` lebih besar), kamu hanya
dapat `a mod 2^k` = bit bawah `a`, **parsial**. Ini justru input untuk teknik
lanjutan:

- **Coppersmith / `small_roots`**: kalau tahu setengah bit bawah (atau atas)
  sebuah faktor RSA `p`, sisanya bisa direcover dengan lattice (butuh `≥ 50%` bit).
- **Kombinasi mod 2^k + mod p_i lain lalu CRT** untuk merangkai bit dari beberapa
  bocoran kecil.

## Kapan berlaku

| Syarat | Keterangan |
|---|---|
| `s` ganjil | supaya `s^{-1} mod 2^k` ada (prima ganjil selalu) |
| `bit(a) ≤ k` | supaya `a` exact; kalau tidak → parsial (Coppersmith) |
| `s = b mod 2^k` benar | mask persis `2^k`; sesuaikan `M` kalau beda |
| `n = a·b` (tanpa faktor 2) | `n` ganjil; kalau ada pangkat 2 handle terpisah |

## Contoh nyata di CTF

Muncul di soal RSA multiprime YOKOSO: dlog membocorkan `s = (q*r) mod 2^512`,
lalu `p = (n mod 2^512)·s^{-1} mod 2^512` (exact, karena `p` 512-bit). Lihat
[YOKOSO writeup](/posts/2026/08/26/yokoso-pohlig-hellman-partial-factor/).

## Referensi

- Inverse modular mod `2^k` via Hensel lifting (Newton iteration untuk 2-adic).
- Coppersmith (1996) — recover faktor dari bit parsial (`small_roots` di SageMath).
- Pola dual lewat pembagian: [Integer Division Leak](/posts/2026/08/26/integer-division-leak/).
