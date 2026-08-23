---
title: "Dasar NTRU dan Ring Cyclotomic"
date: 2026-08-23 09:30:00 +0700
lang: id
ref: dasar-ntru-dan-ring-cyclotomic
platform: knowledge
kn_cat: lattice
tags: [lattice-attack, ntru]
description: Ring cyclotomic Z[x]/(x^N+1), aritmetika polinomial negacyclic, struktur NTRU, dan kenapa basis trapdoor pendek jadi kunci skema signature/enkripsi lattice.
---

NTRU adalah keluarga skema kripto berbasis lattice yang bekerja di ring
polinomial, bukan langsung di vektor integer. Struktur ring ini bikin operasi
efisien dan basis trapdoor kompak — dasar dari NTRUEncrypt, NTRUSign, dan
Falcon (finalis post-quantum NIST). Materi ini bahas ring cyclotomic +
struktur trapdoor NTRU.

## Konsep

### Ring cyclotomic Z[x]/(x^N+1)

Elemen ring adalah polinomial derajat `< N` dengan koefisien integer. `N`
biasanya pangkat 2 (mis. 128, 256, 512). Penjumlahan = biasa (koefisien per
koefisien). Perkalian = perkalian polinomial, tapi karena `x^N ≡ -1`, suku
yang derajatnya `>= N` "membungkus" dengan **tanda negatif**:

$$
x^N \equiv -1 \pmod{x^N + 1}
$$

Ini disebut **negacyclic convolution**. Contoh: `x^{N-1} * x = x^N = -1`.

```python
def mul(a, b):        # a, b: list koefisien panjang N
    N = len(a)
    r = [0] * N
    for i, ai in enumerate(a):
        for j, bj in enumerate(b):
            k = i + j
            if k >= N:
                r[k - N] -= ai * bj   # wrap dengan tanda minus: x^N = -1
            else:
                r[k] += ai * bj
    return r
```

**Conjugate** (analog konjugat kompleks di ring ini): `conj(a)` membalik dan
menegasi koefisien. Dipakai buat bikin bentuk kuadrat (Gram) yang self-adjoint.

```python
def conj(a):
    N = len(a)
    return [a[0]] + [-a[N - i] for i in range(1, N)]
```

### Struktur NTRU

Trapdoor NTRU terdiri dari polinomial pendek `f, g` (dan pasangan `F, G`) yang
memenuhi identitas NTRU:

$$
fG - gF = q \quad(\text{sering } q=1 \text{ atau modulus kecil})
$$

Public key biasanya `h = g/f mod q` (untuk enkripsi) atau bentuk kuadrat dari
`f,g,F,G` (untuk signature). Kuncinya: `f, g, F, G` punya koefisien **kecil**
(basis bagus / short), sementara public key keliatan seperti basis jelek.

### Kenapa "pendek" itu penting

Lattice NTRU direntang oleh basis yang berkaitan dengan `h`. Basis publik itu
jelek (vektor panjang), tapi trapdoor `(f, g)` adalah pasangan vektor pendek di
lattice yang sama. Punya basis pendek = bisa:

- **Dekripsi / signing:** nyari vektor lattice terdekat ke target (CVP) dengan
  mudah.
- Tanpa trapdoor, penyerang harus solve SVP/CVP di lattice NTRU — dianggap
  keras (dasar keamanan post-quantum).

Kalau trapdoor bocor → forge/dekripsi jadi trivial. Lihat penerapan serangannya
di [NTRU Trapdoor dan Signature Forgery](/posts/2026/08/22/ntru-trapdoor-dan-signature-forgery/).

## Kapan berlaku

- **Keamanan bergantung** pada kerahasiaan basis pendek `f,g,F,G` DAN pada
  cara sampling signature (rounding sederhana bocor info trapdoor lewat
  transcript; Gaussian sampling / framework GPV mencegahnya).
- **Ring `x^N+1`** dipilih karena efisien (FFT/NTT) dan punya struktur aljabar
  bagus, tapi struktur ekstra ini juga sumber sebagian serangan (ring/ideal
  lattice attacks) — jadi parameter harus hati-hati.
- Modulus `q`, dimensi `N`, dan norm bound harus diset sesuai level keamanan;
  salah pilih bikin lattice-nya solvable.

## Contoh

Verifikasi identitas trapdoor `fG - gF = 1` di ring (cek satu file recovery):

```python
def sub(a, b): return [a[i] - b[i] for i in range(len(a))]

# f, g, F, G: list koefisien panjang N dari trapdoor
lhs = sub(mul(f, G), mul(g, F))
assert lhs[0] == 1 and all(c == 0 for c in lhs[1:])   # == 1 di ring
```

## Referensi

- Hoffstein, Pipher, Silverman, "NTRU: A Ring-Based Public Key Cryptosystem" (1998).
- Ducas et al., "Falcon" — signature post-quantum modern berbasis NTRU + Gaussian sampling.
- Dasar lattice umum: [Dasar Lattice dan Reduksi LLL](/posts/2026/08/23/dasar-lattice-dan-reduksi-lll/).
</content>
