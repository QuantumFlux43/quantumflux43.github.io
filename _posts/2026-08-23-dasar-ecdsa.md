---
title: "Dasar ECDSA"
date: 2026-08-23 09:00:00 +0700
lang: id
ref: dasar-ecdsa
platform: knowledge
kn_cat: ecc
tags: [ecdsa, fundamental]
description: Cara kerja ECDSA dari nol, mulai dari key generation, signing, verifikasi, hingga alasan nonce k menjadi komponen paling rawan.
---

ECDSA (*Elliptic Curve Digital Signature Algorithm*) adalah skema tanda tangan digital yang dibangun di atas operasi titik pada *elliptic curve*. ECDSA digunakan pada berbagai sistem, seperti Bitcoin, Ethereum, TLS, SSH, dan dokumen bertanda tangan digital.

Materi ini membahas mekanisme dasar ECDSA agar pembaca memahami hubungan antara private key, public key, signature, dan nonce. Pemahaman tersebut penting sebelum mempelajari serangan seperti nonce reuse, nonce leak, dan biased nonce.

> ECDSA tidak mengenkripsi atau menyembunyikan pesan. ECDSA digunakan untuk membuktikan bahwa pesan ditandatangani oleh pemilik private key dan tidak berubah setelah ditandatangani.

## Konsep dasar

ECDSA berdiri di atas dua operasi:

- **Aritmetika modular.** Semua skalar bekerja modulo `n`. Invers modular `a⁻¹ mod n` (bilangan `b` dengan `a·b ≡ 1 mod n`) dipakai saat menghitung `s` (signing) dan `w` (verifikasi).
- **Scalar multiplication pada curve.** `kG` berarti titik `G` dijumlahkan `k` kali. Menghitung `kG` dari `k` mudah, tapi mencari `k` dari `kG` dan `G` sangat sulit — inilah **Elliptic Curve Discrete Logarithm Problem (ECDLP)**, dasar keamanan ECDSA.

## Parameter dan komponen

Parameter domain bersifat publik dan harus sama di semua pihak (mis. Bitcoin/Ethereum memakai `secp256k1`):

| Simbol | Nama | Definisi |
|---|---|---|
| `E` | Curve | Elliptic curve di atas field prima `F_p`. |
| `p` | Prima field | Menentukan field koordinat `F_p`. |
| `G` | Base point | Titik generator publik; semua titik diturunkan dari `G`. |
| `n` | Order dari `G` | Bilangan prima; semua skalar bekerja modulo `n`. |
| `h` | Cofactor | Rasio total titik terhadap `n`. Pada `secp256k1` = `1`. |

Nilai per kunci dan per signing:

| Simbol | Nama | Definisi | Rahasia? |
|---|---|---|---:|
| `D` | Private key | Skalar rahasia jangka panjang di `{1, ..., n-1}`. | Ya |
| `Q` | Public key | Titik `Q = D·G`. | Tidak |
| `m`, `H`, `z` | Pesan / hash | `z = H(m)` disesuaikan panjang bit `n`. | Tidak |
| `k` | Nonce | Skalar rahasia acak, baru tiap signing; menyamarkan `D`. | Ya |
| `R`, `r` | Titik nonce | `R = k·G`, `r = R.x mod n`. | `r` publik |
| `s` | Komponen s | `s = k⁻¹(z + rD) mod n`. | Tidak |
| `w`, `u₁`, `u₂`, `P` | Bantu verifikasi | `w = s⁻¹`, `u₁ = zw`, `u₂ = rw`, `P = u₁G + u₂Q`. | Tidak |

## Key generation

$$
D \xleftarrow{\$} \{1, \dots, n-1\}, \qquad Q = D \cdot G
$$

`D` adalah private key (skalar rahasia), `Q` public key (titik). Keamanannya bergantung pada ECDLP: `D` tidak dapat dihitung dari `Q` dan `G`.

## Signing pesan

Untuk menandatangani pesan `m`:

1. Hitung `z = H(m)` (disesuaikan panjang bit `n`).
2. Pilih nonce rahasia `k` dari `{1, ..., n-1}`.
3. Hitung `R = kG`, ambil `r = R.x mod n`.
4. Hitung `s = k⁻¹(z + rD) mod n`.
5. Signature = `(r, s)`. Ulangi dengan `k` baru jika `r = 0` atau `s = 0`.

$$
r = (k \cdot G).x \bmod n, \qquad s = k^{-1}(z + rD) \bmod n
$$

> Standar ECDSA menyesuaikan/memotong hash berdasarkan panjang bit `n`, bukan selalu `mod n`. Pada `secp256k1` + SHA-256 keduanya 256 bit, jadi hash langsung dipakai sebagai integer.

## Nonce `k`

Nonce (*number used once*) adalah skalar rahasia yang dibuat baru tiap signing, bukan bagian kunci, dan tidak dikirim bersama signature. Fungsinya menyamarkan `D` dalam `s = k⁻¹(z + rD)`. Jika `k` diketahui, persamaan hanya menyisakan satu unknown (`D`), sehingga private key langsung terhitung.

Ada dua cara aman menghasilkan nonce.

### 1. Nonce random

Spesifikasi ECDSA memilih `k` acak **uniform** dari `{1, ..., n-1}` memakai CSPRNG. Kata kuncinya uniform: tiap nilai harus punya peluang keluar sama persis.

Ukuran `n` mengikuti curve: `secp256k1`/`P-256` = 256 bit, `P-384` = 384 bit, `P-521` = 521 bit. Contoh di sini memakai 256 bit, jadi sumber acaknya `os.urandom(32)`.

Cara yang terlihat wajar tapi **salah**:

```python
# Hindari pola ini untuk implementasi kriptografi.
k = int.from_bytes(os.urandom(32), "big") % (n - 1) + 1
```

`os.urandom(32)` uniform di `0 .. 2^256-1`, tapi `n` (prima ~256-bit) tidak membagi `2^256` secara rapi — hampir pasti menyisakan sisa. Akibatnya sebagian nilai kecil di `{1, ..., n-1}` muncul lebih sering. Ini **modulo bias**.

Ilustrasi kecil: acak `0..9` dipetakan ke `0..6` lewat `% 7`:

```text
input : 0 1 2 3 4 5 6 7 8 9
% 7   : 0 1 2 3 4 5 6 0 1 2
```

Nilai `0,1,2` dapat "jatah tambahan" dari `7,8,9`. Di aplikasi biasa tak terasa, tapi pada nonce ECDSA bias sekecil apa pun bisa dieksploitasi lewat Hidden Number Problem.

Solusinya **rejection sampling**: ambil angka acak, buang jika di luar rentang, ulangi — tanpa modulo:

```python
import os

def random_scalar(n):
    size = (n.bit_length() + 7) // 8
    while True:
        value = int.from_bytes(os.urandom(size), "big")
        if 1 <= value < n:
            return value
```

Karena nilai tidak dipetakan ulang, distribusinya benar-benar uniform. Peluang reject kecil (`n` dekat `2^(size*8)`), jadi overhead-nya diabaikan. CSPRNG memenuhi dua syarat sekaligus: uniform dan tak terprediksi.

### 2. Nonce deterministik (RFC 6979)

RFC 6979 menurunkan `k` deterministik dari private key + hash pesan lewat HMAC-DRBG:

$$
k = \operatorname{HMAC\text{-}DRBG}(D, H(m))
$$

Tetap aman karena butuh `D` (rahasia) untuk menghitung `k` — penyerang tidak bisa memprediksinya. Pesan berbeda menghasilkan `k` berbeda. Keuntungannya: tidak bergantung kualitas RNG runtime. Dipakai `libsecp256k1`, Bitcoin, dll.

> RFC 6979 bukan sekadar `HMAC(D, H(m)) % n`; prosedur lengkapnya memakai HMAC-DRBG + konversi integer standar + rejection loop.

### Aturan keamanan nonce

`k` harus **rahasia**, **unik** (tak dipakai untuk dua pesan berbeda), dan **tak terprediksi** (uniform random atau RFC 6979). Melanggar salah satu = private key bocor.

## Verifikasi signature

Untuk memverifikasi `(r, s)` pada pesan `m`:

1. Pastikan `1 ≤ r < n` dan `1 ≤ s < n`, dan validasi `Q`.
2. Hitung `z = H(m)`, `w = s⁻¹ mod n`.
3. `u₁ = zw mod n`, `u₂ = rw mod n`.
4. `P = u₁G + u₂Q`. Tolak jika `P` point at infinity.
5. Valid jika `P.x mod n = r`.

Verifier hanya butuh pesan, signature, parameter domain, dan public key — tidak butuh `k` maupun `D`.

### Mengapa verifikasi bekerja?

Substitusi `s = k⁻¹(z + rD)` dan `Q = DG`:

$$
\begin{aligned}
P &= u_1G + u_2Q = zwG + rwDG \\
  &= w(z + rD)G = s^{-1}(z + rD)G = kG = R
\end{aligned}
$$

Verifier memperoleh kembali `R` tanpa tahu `k`, lalu cukup cek `P.x mod n = r`.

> **Validasi public key** penting sebelum dipakai: `Q` bukan point at infinity, koordinat valid, benar ada di curve, dan di subgroup yang sesuai. Melewatkan cek ini membuka celah invalid-curve.

## Titik rawan ECDSA

Titik rawan ECDSA umumnya berada pada cara nonce dihasilkan dan dilindungi, bukan pada matematika curve standar yang digunakan. Kegagalan nonce (bocor sepenuhnya, digunakan kembali, bias/bocor sebagian), signature malleability, dan celah lain yang sering muncul di CTF dibahas secara terpisah dan lebih lengkap di [Checklist Serangan ECDSA di CTF](/posts/2026/08/23/checklist-serangan-ecdsa-di-ctf/), termasuk urutan prioritas pengecekan dan tanda pemicu tiap serangan.

## Contoh signing dan verifikasi

Proses ECDSA manual di `secp256k1` (untuk pembelajaran, bukan produksi):

```python
from ecdsa import SECP256k1
import hashlib, os

G = SECP256k1.generator
n = int(SECP256k1.order)

def H(m):                     # SHA-256 = 256 bit = ukuran n
    return int.from_bytes(hashlib.sha256(m).digest(), "big")

def random_scalar(n):         # rejection sampling, uniform di [1, n)
    size = (n.bit_length() + 7) // 8
    while True:
        v = int.from_bytes(os.urandom(size), "big")
        if 1 <= v < n:
            return v

D = random_scalar(n)          # private key
Q = D * G                     # public key

def sign(m):
    z = H(m)
    while True:
        k = random_scalar(n)
        r = (k * G).x() % n
        if r == 0: continue
        s = (pow(k, -1, n) * (z + r * D)) % n
        if s == 0: continue
        return r, s

def verify(m, r, s):
    if not (1 <= r < n and 1 <= s < n): return False
    z = H(m); w = pow(s, -1, n)
    P = (z * w % n) * G + (r * w % n) * Q
    return P.x() % n == r

r, s = sign(b"hello")
print(verify(b"hello", r, s))      # True
print(verify(b"modified", r, s))   # False
```

Untuk produksi, pakai library kripto yang teraudit (validasi public key, serialisasi, proteksi side-channel, penyimpanan key aman).

## Ringkasan

- `D` = private key rahasia, `Q = DG` = public key.
- `k` = nonce rahasia, baru tiap signing; menyamarkan `D`.
- Signature `(r, s)` dengan `r` dari titik `kG`; verifier memperoleh kembali `kG` via public key tanpa tahu `D`/`k`.
- Nonce yang bocor, reuse, bias, atau predictable = private key bisa dipulihkan (detail di [Checklist Serangan ECDSA di CTF](/posts/2026/08/23/checklist-serangan-ecdsa-di-ctf/)).

## Referensi

- SEC 1: *Elliptic Curve Cryptography*.
- FIPS 186-5: *Digital Signature Standard*.
- RFC 6979: *Deterministic Usage of the Digital Signature Algorithm and Elliptic Curve Digital Signature Algorithm*.
- [Dasar Hidden Number Problem](/posts/2026/08/23/dasar-hidden-number-problem/).
- [ECDSA Nonce Bias dan Hidden Number Problem](/posts/2026/08/22/ecdsa-nonce-bias-dan-hidden-number-problem/).

