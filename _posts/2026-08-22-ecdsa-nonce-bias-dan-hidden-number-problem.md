---
title: "ECDSA Nonce Bias dan Hidden Number Problem"
date: 2026-08-22 22:25:39 +0700
lang: id
ref: ecdsa-nonce-bias-dan-hidden-number-problem
platform: knowledge
kn_cat: ecc
tags: [ecdsa, lattice-attack]
description: Kenapa nonce ECDSA yang bocor sebagian bit aja udah cukup buat recover private key lewat Hidden Number Problem dan reduksi lattice LLL.
---

ECDSA aman kalau nonce `k` per signature benar-benar rahasia dan uniform
random. Begitu ada bocoran bit dari `k` — walau cuma beberapa bit, walau
tidak langsung, cuma lewat properti statistik atau side-channel — private key
bisa direcover lewat teknik yang disebut **Hidden Number Problem (HNP)**,
diselesaikan pakai reduksi lattice (LLL / BKZ).

## Konsep

Persamaan signing ECDSA:

$$
s \equiv k^{-1}(z + rD) \pmod n
$$

`D` = private key, `z` = hash pesan, `r` = x-koordinat dari `k*G` mod `n`.
Disusun ulang jadi linear di `k`:

$$
k \equiv s^{-1}z + s^{-1}rD \pmod n
$$

Kalau nonce `k` bisa ditulis sebagai `k = a + e` dengan `a` diketahui
(published/predictable) dan `e` kecil (`|e| < 2^t` untuk `t` jauh lebih kecil
dari ukuran `n`), maka tiap signature ngasih persamaan:

$$
e_i \equiv t_i \cdot D + u_i \pmod n, \qquad t_i = -s_i^{-1} r_i, \quad
u_i = s_i^{-1} z_i - a_i
$$

`D` adalah unknown yang sama di semua persamaan, `e_i` kecil dan tidak
diketahui. Ini persis definisi HNP klasik: recover hidden number `D` dari
banyak sample linear dengan noise kecil.

### Kenapa lattice bisa nemuin `D`

Bangun matriks basis (skala `SCALE = n / 2^t`) berukuran `(m+2) x (m+2)`:

```text
baris i (0..m-1) : SCALE*n di diagonal kolom i, 0 di tempat lain
baris m          : SCALE*t_0 ... SCALE*t_{m-1}, 1, 0
baris m+1        : SCALE*u_0 ... SCALE*u_{m-1}, 0, n
```

Vector target rahasia `(SCALE*e_0, ..., SCALE*e_{m-1}, D, 1)` (atau bentuk
serupa) ada di lattice yang direntang baris-baris ini, dan normanya kecil
relatif ke basis lain karena tiap `e_i` kecil. LLL/BKZ efektif nemuin vector
pendek di lattice — begitu lattice-nya "dibentuk" biar target itu jadi
salah satu vector terpendek, reduksi basis akan menyingkapnya di salah satu
baris hasil.

## Kapan berlaku

- **Butuh berapa sample?** Rule of thumb: makin sedikit bit bocor per nonce,
  makin banyak sample dibutuhkan. Bocor 10-bit dari 256-bit nonce biasanya
  cukup dengan 30-60 sample buat lattice HNP standar.
- **Sumber bias nonce yang umum di CTF/dunia nyata:**
  - Nonce dibangun dari hash yang sebagian inputnya publik (prefix/suffix
    predictable) — kasus paling sering muncul di CTF.
  - LCG/PRNG lemah buat generate `k` (state predictable).
  - Bug implementasi: beberapa bit MSB/LSB nonce selalu nol (biased RNG).
  - Nonce reuse penuh (`k` sama di 2 signature beda pesan) — kasus paling
    mudah, `D` bisa dihitung langsung tanpa lattice sama sekali.
- **Kapan gagal:** kalau bocoran terlalu besar relatif ukuran nonce (`e`
  tidak cukup kecil dibanding `n`), lattice reduction gagal nemuin vector
  target karena bukan lagi vector terpendek.

## Contoh

Reduksi minimal pola serangan (detail penuh + solver lengkap ada di writeup
[Crypto Siren](/posts/2026/08/22/crypto-siren-z0d1ak-ctf-2026/)):

```python
from fpylll import IntegerMatrix, LLL

def recover_key(samples, n, scale, pubkey_x, G):
    m = len(samples)
    M = IntegerMatrix(m + 2, m + 2)
    for i in range(m):
        M[i, i] = scale * n
    for i, (t, u) in enumerate(samples):
        M[m, i] = scale * t
        M[m + 1, i] = scale * u
    M[m, m] = 1
    M[m + 1, m + 1] = n
    LLL.reduction(M)
    for row in range(m + 2):
        v = [int(M[row, col]) for col in range(m + 2)]
        for d in (v[-2] % n, (-v[-2]) % n):
            if d and (d * G).x() % n == pubkey_x:
                return d
    raise RuntimeError("D tidak ditemukan, tambah sample")
```

## Referensi

- Nguyen & Shparlinski, "The Insecurity of the Elliptic Curve Digital
  Signature Algorithm with Partially Known Nonces" (2003) — paper dasar HNP-ECDSA.
- Minerva attack (2019) — timing side-channel bocorin bit nonce di implementasi nyata.
- RFC 6979 — deterministic nonce generation, mitigasi standar buat masalah ini.
- Writeup terkait: [Crypto Siren :: Partial Nonce Leak (HNP + LLL)](/posts/2026/08/22/crypto-siren-z0d1ak-ctf-2026/).
</content>
