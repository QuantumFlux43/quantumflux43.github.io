---
title: "Dasar Hidden Number Problem"
date: 2026-08-23 09:20:00 +0700
lang: id
ref: dasar-hidden-number-problem
platform: knowledge
kn_cat: lattice
tags: [lattice-attack, hnp]
description: Hidden Number Problem - recover angka rahasia dari banyak persamaan modular dengan bocoran sebagian bit, diselesaikan lewat lattice.
---

Hidden Number Problem (HNP) adalah kerangka umum: ada satu angka rahasia yang
sama muncul di banyak persamaan modular, tiap persamaan bocor sebagian
informasi (beberapa bit MSB), dan tujuannya recover angka rahasia itu. HNP
adalah "mesin" di balik banyak serangan nonce leak (ECDSA, DSA, Schnorr).

## Konsep

### Rumusan formal

Diberi prima `n`, angka rahasia `D`, dan `m` sample. Untuk tiap sample kita
tahu multiplier publik `t_i` dan sebagian bit dari `t_i * D mod n`. Formalnya:
diberi pasangan `(t_i, u_i)` sehingga

$$
| t_i \cdot D - u_i \bmod n | < \frac{n}{2^{\ell}}
$$

dengan `l` = jumlah bit yang bocor. Tujuannya: temukan `D`.

Intuisi: tiap persamaan bilang "`t_i * D` mod n itu dekat dengan nilai publik
`u_i`, cuma beda selisih kecil (`e_i`)". Selisih kecil ini yang bikin masalah
bisa dipetakan ke pencarian vektor pendek di lattice.

### Kenapa jadi problem lattice

Tulis tiap sample sebagai `t_i D - u_i = e_i + k_i n` dengan `|e_i|` kecil.
Bangun lattice dari relasi ini; vektor `(e_1, ..., e_m, D)` (dengan scaling
tepat) menjadi vektor **sangat pendek** di lattice karena semua `e_i` kecil.
Vektor lattice "wajar" lain jauh lebih panjang. Jalankan LLL → vektor pendek
itu muncul → baca `D` dari komponennya.

Konstruksi lattice standar (skala `SCALE = n / 2^l`):

```text
baris i (0..m-1) : SCALE*n di diagonal kolom i
baris m          : SCALE*t_0 ... SCALE*t_{m-1}, 1, 0
baris m+1        : SCALE*u_0 ... SCALE*u_{m-1}, 0, n
```

### Hubungan ke ECDSA

Di ECDSA dengan nonce biased, persamaan `k = s^{-1}z + s^{-1}rD mod n` bisa
diatur jadi bentuk HNP: `t_i = r_i/s_i`, `u_i = z_i/s_i - prefix_i`, dan
`e_i` = bagian nonce yang tidak diketahui (kecil). Detail penerapannya di
[ECDSA Nonce Bias dan Hidden Number Problem](/posts/2026/08/22/ecdsa-nonce-bias-dan-hidden-number-problem/).

## Berapa sample yang dibutuhkan

Batas informasi kasar: total bit yang bocor harus melebihi ukuran rahasia.

$$
m \cdot \ell \gtrsim \log_2 n
$$

`m` = jumlah sample, `ℓ` = bit bocor per sample, `log2(n)` = ukuran rahasia
(mis. 256 bit). Ini syarat perlu (*necessary*), bukan jaminan. Praktiknya
diambil beberapa kali di atas batas ini sebagai margin, karena LLL bukan
oracle sempurna — vektor target harus benar-benar menonjol pendek supaya
muncul di hasil reduksi. Untuk `n` 256-bit:

| Bit bocor/sig (`ℓ`) | Sample praktis | Catatan |
|---|---|---|
| ~4 bit | ~80-100+ | mepet, kadang perlu BKZ |
| ~8 bit | ~40-60 | LLL cukup |
| ~10 bit | ~30-50 | nyaman |
| ~128 bit (short nonce) | 2-3 | trivial |
| 1 bit | ratusan+ | perlu BKZ / metode khusus (Albrecht-Heninger) |

## Kapan berlaku

- **Trade-off bit vs sample:** makin sedikit bit bocor, makin banyak sample
  dibutuhkan (lihat tabel di atas).
- **Butuh `n` prima** dan `t_i` acak/tersebar (kalau `t_i` berkorelasi, lattice
  degeneratif).
- **Gagal** kalau bocoran terlalu kecil untuk jumlah sample yang tersedia
  (vektor target tidak jadi yang terpendek), atau dimensi terlalu besar untuk
  LLL (butuh BKZ dengan block size besar).

## Contoh sederhana (angka kecil)

Supaya konkret, pakai angka mini yang bisa dicek manual. Misal rahasia
`D = 1234`, modulus prima `n = 10007` (14-bit), dan tiap sample cuma bocor
MSB-nya (nilai `u_i` = pembulatan `t_i·D mod n` ke atas beberapa bit).

**Membuat data sample (peran "server"):**

```python
import random
n = 10007          # modulus prima kecil
D = 1234           # rahasia yang mau dipulihkan (pura-pura tidak tahu)
BLEED = 4          # sisakan hanya sebagian bit rendah sebagai "error"

samples = []
for _ in range(30):
    t = random.randrange(1, n)         # multiplier publik
    full = (t * D) % n                 # nilai penuh (rahasia)
    e = full % (1 << BLEED)            # error kecil = bit bawah
    u = (full - e) % n                 # u = bagian yang "bocor" (MSB)
    samples.append((t, u))             # yang publik cuma (t, u)
```

Tiap sample memenuhi `t·D - u = e` dengan `e` kecil (`e < 2^4 = 16`). Kita
punya `t`, `u`; incar `D`.

**Menyelesaikan dengan lattice:**

```python
from fpylll import IntegerMatrix, LLL

def solve_hnp(samples, n, bleed):
    m = len(samples)
    scale = n >> bleed                 # ~ n / 2^bleed
    M = IntegerMatrix(m + 2, m + 2)
    for i in range(m):
        M[i, i] = scale * n            # kelipatan n (buang reduksi mod n)
    for i, (t, u) in enumerate(samples):
        M[m, i]     = scale * t        # baris untuk D
        M[m + 1, i] = scale * u        # baris untuk konstanta
    M[m, m]         = 1
    M[m + 1, m + 1] = n
    LLL.reduction(M)
    for row in range(m + 2):
        cand = int(M[row, m]) % n      # kolom komponen D
        for d in (cand, (-cand) % n):
            if d and all((t * d - u) % n < (1 << bleed) for t, u in samples):
                return d
    raise RuntimeError("gagal; tambah sample")

print(solve_hnp(samples, n, BLEED))    # -> 1234
```

Cek batas teoretis: `m·ℓ = 30·4 = 120 >> log2(10007) ≈ 13.3`, jadi 30 sample
jauh di atas syarat minimum — LLL menemukan `D = 1234` dengan mudah. Kalau
`BLEED` diperbesar (bit bocor makin sedikit), butuh lebih banyak sample.

**Kerangka umum** (versi ECDSA lengkap ada di writeup Crypto Siren) sama persis
strukturnya, hanya `t`, `u`, dan `check` yang diganti sesuai skema:

```python
def solve_hnp_generic(samples, n, l, check):
    # samples = list of (t, u); check(d) -> True kalau d benar
    m = len(samples)
    scale = n // (1 << l)
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
        cand = int(M[row, m]) % n
        for d in (cand, (-cand) % n):
            if d and check(d):
                return d
    raise RuntimeError("gagal, tambah sample atau cek konstruksi")
```

## Referensi

- Boneh & Venkatesan, "Hardness of Computing the Most Significant Bits of Secret Keys in Diffie-Hellman" (1996) — paper asal HNP.
- Nguyen & Shparlinski (2003), "The Insecurity of the ECDSA with Partially Known Nonces" — bound teoretis bit/sample untuk (EC)DSA.
- Howgrave-Graham & Smart (2001), "Lattice Attacks on Digital Signature Schemes" — analisis praktis jumlah sample.
- Albrecht & Heninger (2021), "On Bounded Distance Decoding with Predicate" — leak sangat kecil (1-bit) dengan BKZ + predicate.
- Dasar teknis lattice: [Dasar Lattice dan Reduksi LLL](/posts/2026/08/23/dasar-lattice-dan-reduksi-lll/).
</content>
