---
title: "Naughty Boy :: Fermat Collapse + Integer Division Leak"
date: 2026-08-26 20:00:00 +0700
lang: id
ref: naughty-boy-fermat-collapse
categories: [RSA]
tags: [multiprime, fermat-little-theorem, integer-division, partial-leak, bit-length]
description: RSA dengan dua hint yang katanya mengacak faktor pakai noise. Noise dibikin kekecilan, jadi faktor bocor lewat Fermat exponent collapse dan pembagian bulat. Recover z1,z2 tanpa faktorisasi.
---

<div class="callout info"><span class="lbl">info soal</span>
<b>CTF:</b> La La La :: <b>Kategori:</b> Crypto (RSA) :: <b>Soal:</b> Naughty Boy
</div>

Soal memberi `n = z1*z2` (RSA 512+512 bit), ciphertext `c`, dan dua *hint* yang
katanya menyembunyikan faktor dengan noise acak. Kelemahannya: noise dipilih
**jauh lebih kecil** dari term rahasia, sehingga struktur faktor bocor lewat dua
alat sederhana — Fermat's Little Theorem dan pembagian bulat.

## Soal

```python
from Crypto.Util.number import *
import os

secret_val = bytes_to_long(os.urandom(100))
z1 = getStrongPrime(512)
z2 = getStrongPrime(512)
z3 = getPrime(256)
modd = getPrime(2048)

n = z1*z2
e = 65537
c = pow(secret_val, e, n)

rand_1 = getRandomNBitInteger(modd.bit_length() - 1013)   # ~1035 bit
rand_2 = bytes_to_long(os.urandom(128))                   # ~1024 bit

hidden_val = z1*z2*z3 + rand_1
hint_1 = (z3**8)*z2 + 0x1337*z2*(z1**2) + rand_2
hint_2 = pow(hidden_val, 4*modd, modd)
# diberikan: e, c, n, modd, hint_1, hint_2
```

## Recon bit-length

Langkah pertama selalu: cek ukuran tiap variabel dan tiap term (bukan angka
aslinya). Angka 300-digit tidak berguna dibaca; bit-length langsung menunjukkan
struktur.

| kuantitas | perkiraan bit |
|---|---|
| `n = z1*z2` | ~1024 |
| `hidden_val = n*z3 + rand_1` | ~1279 |
| `rand_1` | ~1035 |
| `modd` | 2048 |
| `z3^8 * z2` (256·8 + 512) | 2560 |
| `0x1337*z2*z1^2` (512 + 1024) | ~1536 |
| `rand_2` | ~1024 |

Tiga pengamatan langsung: `hidden_val < modd`, `rand_1` cuma sedikit lebih besar
dari `n`, dan `z3^8*z2` mendominasi `hint_1`. Ketiganya jadi celah.

## Langkah 1: buka hint_2 (Fermat collapse)

`hint_2 = pow(hidden_val, 4*modd, modd)` dengan `modd` prima. Fermat's Little
Theorem membuat pangkat runtuh ke sisanya modulo `modd-1`:

$$
4 \cdot modd \bmod (modd-1) = 4(modd-1) + 4 \bmod (modd-1) = 4
$$

karena `modd = (modd-1) + 1`. Jadi

$$
\text{hint\_2} = \text{hidden\_val}^{4} \bmod modd .
$$

Pangkat `4*modd` (2048-bit) runtuh jadi pangkat `4`. Tinggal ambil akar-4 mod
prima (dua kali `sqrt_mod`). Ada sampai 4 akar; pilih yang bit-length ~1279
karena `hidden_val < modd` (mod tidak memotong nilai asli). Teori lengkap:
[Fermat Exponent Collapse](/posts/2026/08/26/fermat-exponent-collapse/).

```python
from sympy.ntheory.residue_ntheory import sqrt_mod

sq = sqrt_mod(hint_2, modd)
roots = set()
for s in {sq % modd, (-sq) % modd}:
    r = sqrt_mod(s, modd)
    if r is not None:
        roots.add(r % modd); roots.add((-r) % modd)
cands = [r for r in roots if 1200 <= r.bit_length() <= 1300]   # hidden_val
```

## Langkah 2: recover z3 (integer division leak)

`hidden_val = z1*z2*z3 + rand_1 = n*z3 + rand_1`. Ini pembagian bersisa: `z3` =
hasil bagi, `rand_1` = sisa. Karena `rand_1 ≈ 2^1035` sedikit lebih besar dari
`n ≈ 2^1024`, sisa "tumpah" ke hasil bagi sebesar `2^(1035-1024) = 2^11 ≈ 2000`.
Jadi `z3 ≈ hidden_val // n` meleset ~2000 → brute delta kecil. Detail:
[Integer Division Leak](/posts/2026/08/26/integer-division-leak/).

## Langkah 3: faktor n (term dominan)

`hint_1 = z3^8*z2 + 0x1337*z2*z1^2 + rand_2`. Term `z3^8*z2` (~2560 bit)
mendominasi; dua term sisa (~1536 bit) lenyap saat dibagi `z3^8` (~2048 bit)
karena selisih bit `≥ ~500 ≫ 30`. Jadi

$$
\text{hint\_1} // z3^{8} = z2 \quad (\text{exact}).
$$

Lalu `z1 = n // z2`. Konsep term dominan: bagian dari
[Bit-Length Reasoning](/posts/2026/08/26/bit-length-reasoning-ctf-crypto/).

## Solver

```python
from Crypto.Util.number import inverse, long_to_bytes
from sympy.ntheory.residue_ntheory import sqrt_mod

def solve(e, c, n, modd, hint_1, hint_2):
    # 1. Fermat collapse: hint_2 = hidden_val^4 mod modd
    sq = sqrt_mod(hint_2, modd)
    roots = set()
    for s in {sq % modd, (-sq) % modd}:
        r = sqrt_mod(s, modd)
        if r is not None:
            roots.add(r % modd); roots.add((-r) % modd)
    cands = [r for r in roots if 1200 <= r.bit_length() <= 1300]

    for hidden in cands:
        approx = hidden // n                      # 2. z3 ~ hidden // n
        for delta in range(4000):
            for z3 in (approx - delta, approx + delta):
                rand_1 = hidden - n * z3
                if rand_1 < 0 or rand_1.bit_length() > 1040:
                    continue
                z2 = hint_1 // (z3 ** 8)           # 3. term dominan
                if z2 <= 1 or n % z2:
                    continue
                z1 = n // z2
                phi = (z1 - 1) * (z2 - 1)
                m = pow(c, inverse(e, phi), n)
                if pow(m, e, n) == c:
                    return long_to_bytes(m)
```

Berjalan < 1 detik, faktorisasi exact tanpa menyerang `n` langsung.

## Flag

```text
flag{n4ughty_b0y_l4_l4_l4_f3rm4t_l1ttl3_th30r3m_4nd_int3g3r_div1s10n}
```

## Catatan

- Inti kelemahan: noise (`rand_1`, `rand_2`) dipilih **kekecilan** relatif ke
  term rahasia. Mitigasi: buat noise seukuran term rahasia
  (`bit(rand) ≈ bit(hidden)`) supaya operasi bulat tidak lagi membocorkan struktur.
- Tiga pengetahuan kecil yang dipakai berulang di CTF crypto, dipisah ke knowledge:
  [Fermat Exponent Collapse](/posts/2026/08/26/fermat-exponent-collapse/),
  [Integer Division Leak](/posts/2026/08/26/integer-division-leak/),
  [Bit-Length Reasoning](/posts/2026/08/26/bit-length-reasoning-ctf-crypto/).
