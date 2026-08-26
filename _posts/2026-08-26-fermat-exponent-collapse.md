---
title: "Fermat Exponent Collapse"
date: 2026-08-26 12:20:00 +0700
lang: id
ref: fermat-exponent-collapse
platform: knowledge
kn_cat: rsa
tags: [fermat-little-theorem, exponent-reduction, modular-root, tonelli-shanks]
description: Pangkat raksasa modulo prima runtuh ke pangkat kecil lewat Fermat's Little Theorem. Sering menyederhanakan hint pow(x, E, p) jadi pow(x, E mod (p-1), p) yang trivial.
---

Pengetahuan kecil yang sering jadi kunci: **pangkat raksasa modulo prima runtuh
ke pangkat kecil**. Kalau soal memberi `pow(x, E, p)` dengan `E` besar dan `p`
prima, hampir selalu langkah pertama adalah mereduksi `E` modulo `p-1`.

## Peta variabel

| variabel | peran | hubungan |
|---|---|---|
| `x` | basis (rahasia yang **dicari**) | `val = x^E mod p` |
| `E` | eksponen besar (diketahui) | direduksi jadi `E mod (p-1)` |
| `p` | modulus prima (diketahui) | orde grup = `p-1` |
| `val` | hasil `pow(x,E,p)` (diketahui) | `= x^(E mod (p-1)) mod p` |
| `k` | eksponen kecil setelah collapse | `k = E mod (p-1)` |

Alur: `E` besar → collapse via `mod (p-1)` → jadi `k` kecil → `val = x^k mod p`
→ ambil akar-`k` → dapat `x`. Jadi `p-1` (orde) adalah "jam" tempat eksponen
berputar; `E` dan `p` input, `x` output.

## Fermat's Little Theorem

Kalau `p` prima dan `gcd(a, p) = 1`:

$$
a^{p-1} \equiv 1 \pmod{p}
$$

Konsekuensi: pangkat cuma "berputar" tiap `p-1`, jadi yang menentukan hasil
hanya sisa pangkat modulo `p-1`:

$$
a^{E} \equiv a^{E \bmod (p-1)} \pmod{p}
$$

## Pola CTF: eksponen collapse

Sering hint bentuknya `pow(x, c*p, p)` atau `pow(x, k*p + r, p)`. Reduksi:

$$
c \cdot p \bmod (p-1) = c\,(p-1) + c \bmod (p-1) = c
$$

karena `p = (p-1) + 1`. Jadi `pow(x, 4*p, p) = pow(x, 4, p)` — pangkat 2048-bit
runtuh jadi pangkat 4. Contoh reduksi lain:

| eksponen `E` | `E mod (p-1)` | hasil |
|---|---|---|
| `p` | `1` | `x` |
| `4*p` | `4` | `x^4` |
| `p+1` | `2` | `x^2` |
| `p^2` | `1` | `x` (karena `p^2 = (p-1)(p+1)+1`) |

```python
# reduksi eksponen sebelum menghitung apa pun
E_red = E % (p - 1)
val = pow(x, E_red, p)     # sama dengan pow(x, E, p) tapi jauh lebih insightful
```

## Setelah collapse: akar modular

Kalau hasilnya `x^k mod p` dengan `k` kecil, dan kamu mau `x`, ambil akar
pangkat-`k` mod prima:

- **k = 2:** Tonelli-Shanks (`sympy.ntheory.residue_ntheory.sqrt_mod`).
- **k = 4:** sqrt dua kali. Jangan pakai `nthroot_mod(..., 4, ...)` all_roots pada
  modulus besar — lambat; dua `sqrt_mod` jauh lebih cepat.
- **k umum:** `nthroot_mod(val, k, p)` untuk `k` kecil.

Tiap akar-2 menghasilkan dua kandidat (`+r`, `-r`), jadi akar-4 sampai 4 kandidat.

```python
from sympy.ntheory.residue_ntheory import sqrt_mod

def fourth_roots(val, p):
    sq = sqrt_mod(val, p)
    out = set()
    for s in {sq % p, (-sq) % p}:
        r = sqrt_mod(s, p)
        if r is not None:
            out.add(r % p); out.add((-r) % p)
    return out
```

## Memilih akar yang benar

Ada banyak kandidat akar. Cara filter paling umum di CTF = **bit-length**. Kalau
nilai asli `x` diketahui lebih kecil dari `p` (sering, karena `x` dibangun dari
faktor + noise yang total `< p`), maka mod tidak memotong `x`, dan kandidat asli
= yang bit-length-nya mendekati ukuran asli. Lihat
[Bit-Length Reasoning](/posts/2026/08/26/bit-length-reasoning-ctf-crypto/).

```python
cands = [r for r in fourth_roots(val, p) if lo <= r.bit_length() <= hi]
```

## Kapan berlaku

| Syarat | Keterangan |
|---|---|
| `p` prima | supaya `a^{p-1} ≡ 1` dan akar mod p bisa dihitung |
| `gcd(x, p) = 1` | hampir selalu untuk `p` prima besar |
| butuh recover `x`: `bit(x) < bit(p)` | supaya mod tidak memotong; kandidat unik |
| `k` (pangkat setelah collapse) kecil | supaya akar-k praktis |

Kalau `p` komposit, `p-1` tak terdefinisi sebagai orde — pakai `lambda(n)` (Carmichael)
atau faktorkan dulu.

## Contoh nyata di CTF

Soal Naughty Boy: `hint_2 = pow(hidden_val, 4*modd, modd)` runtuh jadi
`hidden_val^4 mod modd`, akar-4 + filter bit-length balikin `hidden_val`. Lihat
[Naughty Boy writeup](/posts/2026/08/26/naughty-boy-fermat-collapse/).

## Referensi

- Fermat's Little Theorem; generalisasi Euler `a^{phi(n)} ≡ 1 (mod n)` untuk komposit.
- Tonelli-Shanks — akar kuadrat modulo prima.
- Carmichael `lambda(n)` — orde untuk modulus komposit.
