---
title: "Dasar ECDSA"
date: 2026-08-23 09:00:00 +0700
lang: id
ref: dasar-ecdsa
platform: knowledge
kn_cat: ecc
tags: [ecdsa, fundamental]
description: Cara kerja ECDSA dari nol - key generation, signing, verifikasi, dan kenapa nonce k jadi titik paling rawan.
---

ECDSA (Elliptic Curve Digital Signature Algorithm) adalah skema tanda tangan
digital yang dibangun di atas grup titik pada elliptic curve. Dipakai di mana-
mana: Bitcoin/Ethereum, TLS, SSH, dokumen bertanda tangan. Materi ini bahas
mekanisme dasarnya supaya paham kenapa serangan seperti nonce leak bisa fatal.

## Konsep

### Parameter domain

Sebuah curve dipilih publik (misal `secp256k1`), dengan:

- `E` : elliptic curve atas field prima `F_p`.
- `G` : titik generator (base point) di curve.
- `n` : order dari `G` (bilangan prima, jumlah titik yang bisa dihasilkan `G`).

Operasi dasarnya adalah **scalar multiplication**: `k * G` artinya
menjumlahkan titik `G` sebanyak `k` kali di grup curve. Ini one-way: dari `k`
gampang hitung `k*G`, tapi dari titik `k*G` balik ke `k` itu Elliptic Curve
Discrete Log Problem (ECDLP) yang dianggap keras.

### Key generation

$$
D \xleftarrow{\$} \{1, \dots, n-1\}, \qquad Q = D \cdot G
$$

- `D` = private key (skalar rahasia).
- `Q` = public key (titik = `D*G`).

### Signing pesan `m`

1. Hitung hash `z = H(m) mod n`.
2. Pilih **nonce** `k` random di `{1, ..., n-1}` (WAJIB rahasia + unik per tanda tangan).
3. Hitung titik `R = k*G`, ambil `r = R.x mod n`.
4. Hitung `s = k^{-1}(z + rD) mod n`.
5. Signature = `(r, s)`.

$$
r = (k \cdot G).x \bmod n, \qquad s = k^{-1}(z + rD) \bmod n
$$

### Nonce `k` itu dari mana?

`k` (disebut **nonce** = *number used once*) adalah skalar rahasia yang
di-generate **baru tiap kali signing**, BUKAN bagian dari kunci dan bukan
turunan pesan secara langsung. Ini komponen paling krusial ECDSA, jadi penting
paham dari mana asalnya.

**Fungsi `k`:** dia yang "menyamarkan" private key `D` di persamaan
`s = k^{-1}(z + rD)`. Tanpa `k` (atau kalau `k` diketahui), persamaan itu cuma
punya satu unknown yaitu `D`, dan `D` langsung ketebak. `k` bikin tiap
signature acak dan tidak membocorkan `D`.

Ada dua cara sah men-generate `k`:

**1. Random (spec asli ECDSA).** Ambil dari CSPRNG (RNG kriptografis, mis.
`os.urandom`), uniform di `{1, ..., n-1}`:

```python
k = int.from_bytes(os.urandom(32), "big") % (n - 1) + 1   # dari CSPRNG
```

Syarat mutlak: sumbernya RNG yang benar-benar acak dan tak terprediksi. Kalau
RNG lemah/bias, `k` bocor sebagian → private key jebol.

**2. Deterministik (RFC 6979, best practice sekarang).** Alih-alih RNG, `k`
diturunkan **deterministik** dari private key `D` + hash pesan `z` lewat
HMAC-DRBG:

$$
k = \mathrm{HMAC\text{-}DRBG}(D,\; H(m))
$$

```python
import hmac, hashlib
# skema disederhanakan; RFC 6979 lengkap pakai loop HMAC-DRBG
k = int.from_bytes(hmac.new(D.to_bytes(32,"big"),
                            H_bytes(m), hashlib.sha256).digest(), "big") % n
```

Kenapa aman padahal deterministik? Karena butuh `D` (rahasia) buat menghitung
`k`, jadi penyerang tetap tidak bisa memprediksinya. Keuntungannya: tidak
bergantung kualitas RNG sama sekali — pesan sama selalu hasilkan `k` sama
(dan itu OK, karena pesan beda pasti hasilkan `k` beda). Dipakai Bitcoin, OpenSSL,
libsecp256k1, dll justru untuk menghindari bencana RNG jelek.

**Aturan emas `k`:** rahasia (tak boleh bocor), unik per signature (tak boleh
reuse), dan tak terprediksi (uniform random atau RFC 6979). Langgar salah satu
= private key bocor (lihat bagian "Kapan berlaku").

### Verifikasi `(r, s)` untuk pesan `m`

1. `z = H(m) mod n`, `w = s^{-1} mod n`.
2. `u1 = z*w mod n`, `u2 = r*w mod n`.
3. `P = u1*G + u2*Q`.
4. Valid kalau `P.x mod n == r`.

Verifikasi cuma butuh public key `Q`, jadi siapapun bisa cek keaslian tanpa
tahu `D`. Perhatikan verifier **tidak butuh `k`** — `k` cuma dipakai saat
signing dan tidak pernah dikirim; yang keluar cuma `r = (k*G).x`.

## Kapan berlaku

Titik rawan ECDSA hampir selalu ada di **nonce `k`**, bukan di curve-nya:

- **`k` harus rahasia total.** Kalau `k` bocor untuk satu signature saja,
  private key langsung terhitung:
  $$
  D = r^{-1}(s k - z) \bmod n
  $$
- **`k` harus unik per signature.** Pakai `k` sama untuk dua pesan beda (nonce
  reuse) bikin `D` bisa dihitung langsung tanpa lattice:
  $$
  k = \frac{z_1 - z_2}{s_1 - s_2} \bmod n, \quad\text{lalu}\quad D = r^{-1}(s_1 k - z_1)
  $$
- **`k` harus uniform random.** Kalau sebagian bit `k` predictable/bocor
  (biased nonce), private key tetap bisa direcover lewat Hidden Number Problem
  + lattice — lihat [Dasar Hidden Number Problem](/posts/2026/08/23/dasar-hidden-number-problem/).

Sumber bias `k` yang sering muncul:

| Cara `k` dibuat | Aman? | Serangan |
|---|---|---|
| CSPRNG uniform (spec) | Aman | - |
| RFC 6979 (HMAC dari `D`+`z`) | Aman | - |
| RNG lemah / sebagian bit predictable | JEBOL | HNP + LLL |
| Sebagian bit sengaja diisi nilai publik | JEBOL | HNP + LLL |
| `k` sama untuk 2 pesan (reuse) | JEBOL | aljabar langsung |
| `k` bocor total 1 signature | JEBOL | aljabar langsung |

Contoh kasus "sebagian bit diisi nilai publik": server yang membangun
`k = prefix_publik || random_bawah`, di mana `prefix_publik` bisa dihitung
penyerang. Tiap signature otomatis membocorkan bit-bit atas `k` → cukup buat
HNP. Ini persis celah di writeup
[Crypto Siren](/posts/2026/08/22/crypto-siren-z0d1ak-ctf-2026/).

Curve-nya sendiri (kalau standar seperti secp256k1/P-256) aman; yang jebol
hampir selalu cara `k` di-generate, bukan matematika curve-nya.

## Contoh

Signing & verifikasi manual (ilustrasi, jangan dipakai produksi):

```python
from ecdsa import SECP256k1
import hashlib, os

G = SECP256k1.generator
n = int(SECP256k1.order)

def H(m): return int.from_bytes(hashlib.sha256(m).digest(), "big") % n

D = int.from_bytes(os.urandom(32), "big") % (n - 1) + 1   # private
Q = D * G                                                 # public

def sign(m):
    z = H(m)
    k = int.from_bytes(os.urandom(32), "big") % (n - 1) + 1   # HARUS random + rahasia
    r = (k * G).x() % n
    s = (pow(k, -1, n) * (z + r * D)) % n
    return r, s

def verify(m, r, s):
    z = H(m); w = pow(s, -1, n)
    P = (z * w % n) * G + (r * w % n) * Q
    return P.x() % n == r

r, s = sign(b"hello")
print(verify(b"hello", r, s))   # True
```

## Referensi

- SEC 1: Elliptic Curve Cryptography (standar formal ECDSA).
- RFC 6979 — deterministic nonce generation (mitigasi masalah nonce).
- Lanjut: [ECDSA Nonce Bias dan Hidden Number Problem](/posts/2026/08/22/ecdsa-nonce-bias-dan-hidden-number-problem/) buat serangannya.
</content>
