---
title: "Dasar Lattice dan Reduksi LLL"
date: 2026-08-23 09:10:00 +0700
lang: id
ref: dasar-lattice-dan-reduksi-lll
platform: knowledge
kn_cat: lattice
tags: [lattice-attack, fundamental]
description: Apa itu lattice, basis baik vs buruk, problem SVP/CVP, dan gimana LLL nemuin vector pendek - fondasi hampir semua serangan lattice di crypto.
---

Lattice adalah struktur matematika yang jadi fondasi banyak serangan crypto
modern (RSA Coppersmith, ECDSA nonce leak, knapsack) sekaligus dasar
post-quantum cryptography. Materi ini bahas intuisi lattice + LLL supaya paham
kenapa "reduksi basis" bisa jadi senjata.

## Konsep

### Definisi lattice

Diberikan vektor-vektor basis `b_1, ..., b_m` yang bebas linear di `R^n`,
lattice adalah himpunan semua kombinasi linear **berkoefisien integer**:

$$
\mathcal{L} = \left\{ \sum_{i=1}^{m} a_i b_i \;\middle|\; a_i \in \mathbb{Z} \right\}
$$

Bayangkan grid titik yang terentang tak hingga. Satu lattice yang sama bisa
direntang oleh **banyak basis berbeda** - ada yang "bagus" (vektornya pendek,
hampir tegak lurus) dan ada yang "jelek" (panjang, hampir sejajar).

### Basis bagus vs jelek

Kunci semua serangan lattice: lattice yang sama, tapi basis bagus bikin
problem gampang, basis jelek bikin susah. Public key skema lattice biasanya
sengaja dikasih dalam basis jelek; trapdoor rahasia = basis bagus.

### Problem inti

- **SVP (Shortest Vector Problem):** cari vektor non-nol terpendek di lattice.
- **CVP (Closest Vector Problem):** diberi titik target `t` (belum tentu di
  lattice), cari vektor lattice yang paling dekat ke `t`.

Kedua problem ini keras di dimensi tinggi (basis for post-quantum crypto),
TAPI di dimensi kecil-menengah (yang sering muncul di CTF), algoritma reduksi
basis seperti LLL bisa menyelesaikannya cukup baik.

### LLL (Lenstra-Lenstra-Lovasz)

LLL adalah algoritma **polynomial-time** yang mengubah basis jelek jadi basis
yang "cukup bagus": vektor-vektornya jadi relatif pendek dan hampir ortogonal.
Vektor pertama hasil LLL adalah **aproksimasi vektor terpendek** (dijamin dalam
faktor `2^{(m-1)/2}` dari SVP asli - cukup buat banyak serangan praktis).

Ide dasar serangan lattice: **bentuk lattice sedemikian rupa** sehingga solusi
rahasia (private key, nonce error, pesan) menjadi salah satu vektor terpendek,
lalu jalankan LLL, dan solusi muncul di baris hasil.

## Cara membangun lattice untuk serangan

Sebagian besar serangan lattice mengikuti alur yang sama. Yang berubah antar
serangan hanya bagaimana persamaan dituangkan ke baris matriks.

### Langkah umum

1. **Tulis relasi rahasia jadi persamaan linear** yang mengandung nilai kecil
   yang belum diketahui (error, nonce bias, pesan pendek). Bentuknya biasanya
   `Σ a_i·x_i = target + k·n`, dengan `n` modulus.
2. **Susun basis** sehingga kombinasi integer baris-barisnya bisa menghasilkan
   vektor `(nilai_kecil_1, ..., nilai_kecil_t, rahasia)`.
3. **Buang efek modulo** dengan menaruh kelipatan `n` pada baris tersendiri
   (kombinasi integer bebas menambah/mengurangi `n`, meniru operasi `mod n`).
4. **Scaling / weighting**: kalikan kolom/baris dengan faktor agar semua
   komponen vektor target berskala sama besar. Ini yang membuat vektor target
   benar-benar menjadi yang terpendek, bukan sekadar salah satu vektor pendek.
5. **Jalankan LLL**, lalu **pindai tiap baris hasil**: cari baris yang cocok
   dengan bentuk vektor target, ambil komponen rahasianya, dan verifikasi.

### Pola matriks yang sering dipakai

Untuk sistem `t·x ≡ u (mod n)` dengan `x` rahasia dan error kecil per sample
(pola Hidden Number Problem), basis berukuran `(m+2) × (m+2)`:

```text
             kol 0    kol 1   ...  kol m-1   kol m   kol m+1
baris 0    [ SCALE·n    0     ...    0         0       0    ]
baris 1    [   0     SCALE·n  ...    0         0       0    ]
  ...                    (diagonal SCALE·n)
baris m-1  [   0        0     ...  SCALE·n     0       0    ]
baris m    [ SCALE·t_0 SCALE·t_1 ... SCALE·t_{m-1}  1      0    ]
baris m+1  [ SCALE·u_0 SCALE·u_1 ... SCALE·u_{m-1}  0      n    ]
```

- **Baris diagonal `SCALE·n`**: menyediakan kelipatan `n` untuk menyerap
  reduksi modulo pada tiap sample.
- **Baris `m`**: membawa multiplier `t_i` dan sebuah `1` di kolom penanda,
  sehingga komponen `x` (rahasia) ikut terbawa saat kombinasi.
- **Baris `m+1`**: membawa konstanta `u_i` dan `n` di kolom terakhir.
- **`SCALE`**: faktor penyeimbang (pada HNP `SCALE ≈ 2^ℓ`, yaitu `n` dibagi 2
  pangkat jumlah bit error) supaya error kecil berskala setara dengan `x`.

Kombinasi integer yang "benar" dari baris-baris ini menghasilkan vektor:

```text
( SCALE·e_0, SCALE·e_1, ..., SCALE·e_{m-1}, x, konstanta )
```

Karena tiap `e_i` kecil dan sudah diskalakan seimbang, vektor ini pendek dan
LLL memunculkannya. Nilai `x` dibaca dari kolom penanda.

### Kode kerangka

```python
from fpylll import IntegerMatrix, LLL

def build_and_solve(samples, n, scale, check):
    # samples = list of (t, u) dengan  t·x - u = e kecil (mod n)
    m = len(samples)
    M = IntegerMatrix(m + 2, m + 2)
    for i in range(m):
        M[i, i] = scale * n                 # serap reduksi mod n
    for i, (t, u) in enumerate(samples):
        M[m, i]     = scale * t             # baris pembawa x
        M[m + 1, i] = scale * u             # baris konstanta
    M[m, m]         = 1                      # kolom penanda x
    M[m + 1, m + 1] = n
    LLL.reduction(M)
    for row in range(m + 2):
        x = int(M[row, m]) % n              # komponen rahasia
        for cand in (x, (-x) % n):
            if cand and check(cand):        # verifikasi solusi
                return cand
    raise RuntimeError("gagal; tambah sample atau perbaiki scaling")
```

Penerapan konkret pola ini (nonce ECDSA) ada di
[Dasar Hidden Number Problem](/posts/2026/08/23/dasar-hidden-number-problem/)
dan writeup [Crypto Siren](/posts/2026/08/22/crypto-siren-z0d1ak-ctf-2026/).

## Kapan berlaku

- **Efektif** kalau dimensi lattice kecil-menengah (puluhan sampai ~seratusan)
  dan vektor target benar-benar jauh lebih pendek dari vektor lattice lain.
- **Perlu tuning** lewat scaling/weighting: kolom tertentu dikali faktor besar
  supaya LLL "memaksa" komponen itu jadi nol/kecil (teknik ini muncul di HNP,
  Coppersmith, dll).
- **Gagal** kalau vektor target tidak cukup menonjol pendek dibanding basis, atau
  dimensi terlalu besar (butuh BKZ dengan block size besar, jauh lebih lambat).

## Contoh

LLL dengan `fpylll` di lattice sederhana:

```python
from fpylll import IntegerMatrix, LLL

# basis jelek (vektor panjang, hampir sejajar)
M = IntegerMatrix.from_matrix([
    [201, 37],
    [1537, 283],
])
print("sebelum:", [ [M[i,j] for j in range(2)] for i in range(2) ])

LLL.reduction(M)   # ubah jadi basis bagus (vektor pendek, ortogonal)
print("sesudah:", [ [M[i,j] for j in range(2)] for i in range(2) ])
# baris pertama sekarang ~ vektor terpendek di lattice
```

## Referensi

- Lenstra, Lenstra, Lovasz, "Factoring polynomials with rational coefficients" (1982) - paper asal LLL.
- Galbraith, "Mathematics of Public Key Cryptography" - bab lattice yang enak dibaca.
- Lanjut: [Dasar Hidden Number Problem](/posts/2026/08/23/dasar-hidden-number-problem/).
</content>
