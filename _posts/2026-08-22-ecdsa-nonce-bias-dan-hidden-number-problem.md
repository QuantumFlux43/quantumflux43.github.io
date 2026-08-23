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

Kalau nonce `k` bisa ditulis sebagai `k = prefix + e` dengan `prefix` diketahui
(published/predictable) dan `e` kecil (`|e| < 2^ℓ`, dengan `ℓ` = jumlah bit
bocor, `ℓ` jauh lebih kecil dari ukuran `n`), maka tiap signature ngasih
persamaan HNP:

$$
t_i \cdot D - u_i \equiv e_i \pmod n, \qquad
t_i = r_i \cdot s_i^{-1}, \quad
u_i = z_i \cdot s_i^{-1} - \text{prefix}_i
$$

Notasi ini sama dengan yang dipakai di [Dasar Hidden Number Problem](/posts/2026/08/23/dasar-hidden-number-problem/):
`t_i`, `u_i` publik (dihitung dari signature), `D` unknown yang sama di semua
persamaan, `e_i` error kecil yang tidak diketahui. Ini persis definisi HNP
klasik: recover hidden number `D` dari banyak sample linear dengan noise kecil.

> Catatan tanda: bentuk `t·D - u ≡ e` di atas ekuivalen dengan `u ≡ t·D - e`;
> pemilihan tanda `t_i`/`u_i` boleh berbeda antar implementasi selama konsisten.
> Konstanta `prefix` di sini sama peran dengan `a` (bagian nonce yang diketahui).

### Kenapa lattice bisa nemuin `D`

Bangun matriks basis (skala `SCALE ≈ 2^ℓ`, yaitu `n` dibagi 2 pangkat jumlah
bit error `= n / 2^(log2 n - ℓ)`; sama seperti di note HNP) berukuran
`(m+2) x (m+2)`, dengan `m` = jumlah sample:

```text
baris i (0..m-1) : SCALE*n di diagonal kolom i, 0 di tempat lain
baris m          : SCALE*t_0 ... SCALE*t_{m-1}, 1, 0
baris m+1        : SCALE*u_0 ... SCALE*u_{m-1}, 0, n
```

Vector target rahasia `(SCALE*e_0, ..., SCALE*e_{m-1}, D, konstanta)` ada di
lattice yang direntang baris-baris ini, dan normanya kecil relatif ke basis
lain karena tiap `e_i` kecil. LLL/BKZ efektif nemuin vector pendek di lattice
— begitu lattice-nya "dibentuk" biar target itu jadi salah satu vector
terpendek, reduksi basis akan menyingkapnya di salah satu baris hasil.

## Kapan berlaku

- **Butuh berapa sample?** Rule of thumb: makin sedikit bit bocor (`ℓ`) per
  nonce, makin banyak sample dibutuhkan. Bocor `ℓ = 10` bit dari 256-bit nonce
  biasanya cukup dengan 30-60 sample buat lattice HNP standar. Batas teoretis
  dan tabel lengkap ada di [Dasar Hidden Number Problem](/posts/2026/08/23/dasar-hidden-number-problem/).
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
