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

### Modular arithmetic

Sebagian besar perhitungan ECDSA dilakukan modulo bilangan tertentu. Operasi modulo membuat hasil perhitungan selalu berada dalam rentang yang terbatas.

Sebagai contoh:

```text
17 mod 5 = 2
```

ECDSA juga menggunakan invers modular. Nilai `a^-1 mod n` adalah bilangan yang memenuhi:

```text
a × a^-1 ≡ 1 mod n
```

Invers modular digunakan ketika menghitung komponen `s` pada proses signing dan `w` pada proses verifikasi.

### Titik pada elliptic curve

Elliptic curve membentuk sekumpulan titik dengan aturan penjumlahan khusus. Jika dua titik pada curve dijumlahkan, hasilnya juga merupakan titik pada curve yang sama.

Operasi utama yang digunakan ECDSA adalah **scalar multiplication**:

```text
kG = G + G + ... + G
     sebanyak k kali
```

Dalam implementasi, operasi tersebut tidak dilakukan dengan penjumlahan satu per satu, tetapi menggunakan algoritma yang lebih efisien, seperti *double-and-add*.

Dari sebuah skalar `k`, menghitung titik `kG` relatif mudah. Sebaliknya, mencari `k` dari `G` dan `kG` dianggap sangat sulit. Masalah ini disebut **Elliptic Curve Discrete Logarithm Problem** atau ECDLP.

## Parameter domain

ECDSA menggunakan parameter curve yang bersifat publik. Sebagai contoh, Bitcoin dan Ethereum menggunakan `secp256k1`.

Parameter pentingnya meliputi:

- `E`: elliptic curve di atas field prima `F_p`.
- `p`: bilangan prima yang menentukan field koordinat curve.
- `G`: titik generator atau *base point*.
- `n`: order dari `G`, yaitu jumlah penjumlahan `G` sampai kembali ke titik identitas.
- `h`: cofactor curve.

Semua pihak harus menggunakan parameter domain yang sama agar proses signing dan verifikasi dapat dilakukan dengan benar.

## Komponen utama ECDSA

| Komponen | Bentuk | Rahasia? | Masa penggunaan |
|---|---|---:|---|
| Private key `D` | Skalar | Ya | Jangka panjang |
| Public key `Q` | Titik pada curve | Tidak | Jangka panjang |
| Nonce `k` | Skalar | Ya | Satu proses signing |
| Signature `(r, s)` | Dua skalar | Tidak | Dikirim atau disimpan bersama pesan |

Private key dan nonce sama-sama berbentuk skalar rahasia, tetapi fungsinya berbeda. Private key digunakan dalam jangka panjang, sedangkan nonce hanya boleh digunakan untuk satu proses signing.

## Notasi dan parameter pada rumus

Berikut arti setiap simbol yang muncul pada rumus signing, verifikasi, dan serangan. Semua operasi skalar dilakukan modulo `n`, kecuali operasi titik yang dilakukan pada curve.

### Parameter publik (domain)

| Simbol | Nama | Definisi |
|---|---|---|
| `E` | Curve | Elliptic curve tempat semua titik didefinisikan. |
| `p` | Prima field | Bilangan prima yang mendefinisikan field koordinat `F_p`. Menentukan besar koordinat `x`, `y` titik. |
| `G` | Base point / generator | Titik acuan publik pada curve. Semua public key dan titik signature diturunkan dari `G`. |
| `n` | Order dari `G` | Bilangan prima; jumlah kelipatan `G` sebelum kembali ke titik identitas. Semua skalar bekerja modulo `n`. |
| `h` | Cofactor | Rasio jumlah total titik curve terhadap `n`. Pada `secp256k1` bernilai `1`. |

### Kunci

| Simbol | Nama | Definisi |
|---|---|---|
| `D` | Private key | Skalar rahasia jangka panjang di rentang `{1, ..., n-1}`. Dipakai saat signing. |
| `Q` | Public key | Titik `Q = D·G` pada curve. Publik, dipakai saat verifikasi. |

### Nilai per-signing

| Simbol | Nama | Definisi |
|---|---|---|
| `m` | Pesan | Data yang ditandatangani. |
| `H` | Fungsi hash | Fungsi hash kriptografis (mis. SHA-256). |
| `z` | Hash pesan | Integer hasil hash pesan, disesuaikan panjang bit `n`. `z = H(m)` (mod n bila perlu). |
| `k` | Nonce | Skalar rahasia acak, **baru tiap signing**, di rentang `{1, ..., n-1}`. Menyamarkan `D`. |
| `R` | Titik nonce | Titik `R = k·G`. Tidak dikirim; hanya koordinat `x`-nya dipakai. |
| `r` | Komponen r | `r = R.x mod n`. Bagian pertama signature. |
| `s` | Komponen s | `s = k⁻¹(z + rD) mod n`. Bagian kedua signature. |
| `(r, s)` | Signature | Pasangan skalar hasil signing, dikirim bersama pesan. |

### Nilai bantu saat verifikasi

| Simbol | Nama | Definisi |
|---|---|---|
| `w` | Invers s | `w = s⁻¹ mod n`. |
| `u₁` | Skalar 1 | `u₁ = z·w mod n`. Pengali untuk `G`. |
| `u₂` | Skalar 2 | `u₂ = r·w mod n`. Pengali untuk `Q`. |
| `P` | Titik hasil | `P = u₁·G + u₂·Q`. Jika signature valid, `P = R`, sehingga `P.x mod n = r`. |

### Notasi operasi

| Notasi | Arti |
|---|---|
| `a·G` atau `aG` | Scalar multiplication: titik `G` dijumlahkan `a` kali pada curve. |
| `T.x` | Koordinat `x` dari titik `T`. |
| `a⁻¹ mod n` | Invers modular: nilai `b` dengan `a·b ≡ 1 (mod n)`. |
| `x mod n` | Sisa pembagian `x` oleh `n` (hasil di `{0, ..., n-1}`). |
| `x ← $ S` | `x` dipilih acak uniform dari himpunan `S`. |

## Key generation

Pilih private key `D` secara acak dari rentang:

$$
D \xleftarrow{\$} \{1, \dots, n-1\}
$$

Kemudian hitung public key:

$$
Q = D \cdot G
$$

- `D` adalah private key berupa skalar rahasia.
- `Q` adalah public key berupa titik pada curve.

Keamanan pasangan kunci ini bergantung pada ECDLP. Public key `Q` boleh diketahui siapa pun, tetapi private key `D` tidak dapat dihitung secara praktis hanya dari `Q` dan `G` jika curve dan implementasinya aman.

## Signing pesan

Untuk menandatangani pesan `m`, signer melakukan langkah berikut:

1. Hitung hash pesan dan ubah menjadi integer `z` yang panjangnya disesuaikan dengan panjang bit `n`.
2. Pilih nonce rahasia `k` dari rentang `{1, ..., n-1}`.
3. Hitung titik `R = kG`.
4. Ambil `r = R.x mod n`.
5. Hitung `s = k^-1(z + rD) mod n`.
6. Hasil signature adalah pasangan `(r, s)`.

Secara matematis:

$$
r = (k \cdot G).x \bmod n
$$

$$
s = k^{-1}(z + rD) \bmod n
$$

Jika `r = 0` atau `s = 0`, signer harus memilih nonce baru dan mengulangi proses signing.

### Catatan tentang hash pesan

Untuk menyederhanakan pembahasan, proses hash sering ditulis sebagai:

$$
z = H(m) \bmod n
$$

Namun, standar ECDSA pada dasarnya menyesuaikan atau memotong hash berdasarkan panjang bit `n`, bukan selalu melakukan operasi modulo secara langsung. Pada `secp256k1` dengan SHA-256, keduanya sama-sama memiliki panjang 256 bit sehingga hash dapat digunakan secara langsung sebagai integer.

## Nonce `k`

Nonce merupakan singkatan dari *number used once*. Dalam ECDSA, `k` adalah skalar rahasia yang dibuat untuk setiap proses signing. Nonce bukan bagian dari pasangan kunci dan tidak boleh dikirim bersama signature.

Fungsi `k` adalah menyamarkan private key `D` dalam persamaan:

$$
s = k^{-1}(z + rD) \bmod n
$$

Jika `k` diketahui, persamaan tersebut hanya memiliki satu nilai rahasia yang belum diketahui, yaitu `D`. Akibatnya, private key dapat dihitung secara langsung.

### Cara menghasilkan nonce

Terdapat dua pendekatan yang aman untuk menghasilkan nonce.

#### 1. Nonce random

Spesifikasi awal ECDSA memilih `k` secara acak dan uniform dari `{1, ..., n-1}` menggunakan CSPRNG atau *cryptographically secure pseudorandom number generator*. Kata kunci di sini adalah **uniform**: setiap nilai dalam rentang `{1, ..., n-1}` harus punya peluang keluar yang sama persis. Bagian ini membahas cara mencapai itu, dan jebakan yang harus dihindari.

**Ukuran `n` pada curve yang umum dipakai**

Besar `n` mengikuti tingkat keamanan curve yang dipakai:

| Curve | Ukuran `n` |
|---|---|
| `secp256k1`, `P-256` | 256 bit |
| `P-384` | 384 bit |
| `P-521` | 521 bit |

Karena `secp256k1` dan `P-256` yang paling umum dipakai (Bitcoin, Ethereum, TLS), contoh pada bagian ini memakai `n` berukuran 256 bit, sehingga `os.urandom(32)` (32 byte = 256 bit) dipakai sebagai sumber acak.

Sebagai gambaran konkret, nilai `n` pada `secp256k1`:

```text
n = 0xFFFFFFFF FFFFFFFF FFFFFFFF FFFFFFFE
    BAAEDCE6 AF48A03B BFD25E8C D0364141

n = 115792089237316195423570985008687907852837564279074904382605163141518161494337
```

`n` adalah bilangan prima 256-bit, tetapi nilainya **bukan** `2^256` maupun pangkat dua lain. Bandingkan dengan `2^256`:

```text
2^256 = 115792089237316195423570985008687907853269984665640564039457584007913129639936
n     = 115792089237316195423570985008687907852837564279074904382605163141518161494337
```

Keduanya sama-sama 256-bit dan nilainya berdekatan, tetapi berbeda. Selisih kecil inilah yang membuat `2^256 mod (n-1)` tidak nol, sehingga modulo langsung menghasilkan bias seperti dijelaskan berikut.

**Cara yang terlihat wajar, tapi salah**

`os.urandom(32)` menghasilkan angka acak uniform di rentang `0` sampai `2^256 - 1`. Karena nonce `k` harus berada di `{1, ..., n-1}`, cara yang sering terlihat masuk akal adalah memotongnya dengan modulo:

```python
# Hindari pola ini untuk implementasi kriptografi.
k = int.from_bytes(os.urandom(32), "big") % (n - 1) + 1
```

Masalahnya, `n` tidak membagi `2^256` secara rapi. Ini bukan kebetulan: `n` adalah bilangan prima besar (order dari grup titik pada curve), sedangkan `os.urandom(32)` menghasilkan rentang berukuran pangkat dua penuh (`2^256`). Satu-satunya bilangan prima yang juga merupakan pangkat dua adalah `2` itu sendiri, sehingga untuk `n` sebesar ini, `2^256` dibagi `n` hampir pasti menyisakan sisa. Sisa pembagian inilah yang menyebabkan sebagian nilai kecil di rentang `{1, ..., n-1}` punya peluang keluar sedikit lebih besar dibanding nilai lain saat dipotong pakai modulo. Fenomena ini disebut **modulo bias**.

Ilustrasi sederhana: misal sumber acak menghasilkan angka `0` sampai `9` (10 kemungkinan), lalu dipetakan ke rentang `0` sampai `6` (7 pilihan) lewat `% 7`:

```text
input acak : 0 1 2 3 4 5 6 7 8 9
hasil % 7  : 0 1 2 3 4 5 6 0 1 2
```

Nilai `0`, `1`, `2` mendapat "jatah tambahan" dari angka `7`, `8`, `9`, sehingga muncul lebih sering daripada `3`, `4`, `5`, `6`. Hasilnya tidak lagi uniform. Pada aplikasi biasa bias sekecil ini mungkin tidak terasa, tetapi pada nonce ECDSA, bias sekecil apa pun berpotensi dieksploitasi lewat Hidden Number Problem setelah cukup banyak signature terkumpul.

**Solusi: rejection sampling**

Untuk mendapatkan nilai yang benar-benar uniform, gunakan teknik **rejection sampling**: ambil angka acak seperti biasa, lalu jika hasilnya jatuh di luar rentang yang diinginkan, buang (*reject*) dan coba lagi, tanpa memotongnya dengan modulo.

```python
import os

def random_scalar(n):
    size = (n.bit_length() + 7) // 8

    while True:
        value = int.from_bytes(os.urandom(size), "big")
        if 1 <= value < n:      # dalam rentang -> pakai
            return value
        # di luar rentang -> buang, ulangi loop

k = random_scalar(n)
```

Karena nilai yang diterima hanya yang jatuh tepat di `{1, ..., n-1}` tanpa dipetakan ulang, tidak ada nilai yang mendapat "jatah tambahan" seperti pada kasus modulo. Distribusi hasilnya menjadi benar-benar uniform. Konsekuensinya, loop bisa perlu mengulang beberapa kali saat hasil di luar rentang, tetapi karena `n` biasanya sangat dekat dengan `2^(size*8)`, peluang reject ini kecil dan overhead-nya dapat diabaikan.

Selain distribusinya harus uniform, sumber acak itu sendiri juga harus tidak dapat diprediksi. CSPRNG memenuhi kedua syarat ini: hasilnya uniform dan tidak bisa ditebak penyerang, sehingga aman dipakai untuk `k`.

#### 2. Nonce deterministik

RFC 6979 menghasilkan nonce secara deterministik dari private key dan hash pesan menggunakan HMAC-DRBG:

$$
k = \operatorname{HMAC\text{-}DRBG}(D, H(m))
$$

Gambaran pemakaiannya dapat ditulis sebagai pseudocode berikut:

```python
k = rfc6979_generate_k(
    private_key=D,
    message_hash=hashlib.sha256(m).digest(),
    order=n,
)
```

> RFC 6979 tidak cukup diimplementasikan sebagai satu operasi `HMAC(D, H(m)) % n`. Prosedur lengkapnya menggunakan HMAC-DRBG, konversi integer yang ditentukan standar, dan rejection loop.

Metode deterministik tetap aman karena private key dibutuhkan untuk menghasilkan `k`. Pesan dengan hash berbeda secara praktis menghasilkan nonce yang berbeda. Pendekatan ini mengurangi ketergantungan proses signing terhadap kualitas RNG saat runtime dan digunakan oleh berbagai implementasi ECDSA modern, termasuk `libsecp256k1`.

### Aturan keamanan nonce

Nonce harus memenuhi tiga syarat:

1. **Rahasia**: nilai `k` tidak boleh diketahui penyerang.
2. **Unik**: satu nilai `k` tidak boleh digunakan untuk menandatangani dua pesan berbeda.
3. **Tidak dapat diprediksi**: nonce harus uniform random atau dihasilkan dengan metode deterministik yang aman, seperti RFC 6979.

Pelanggaran terhadap salah satu syarat tersebut dapat membocorkan private key.

## Verifikasi signature

Untuk memverifikasi signature `(r, s)` pada pesan `m`, verifier melakukan langkah berikut:

1. Pastikan `1 <= r < n` dan `1 <= s < n`.
2. Validasi public key `Q`.
3. Hitung integer hash pesan `z`.
4. Hitung `w = s^-1 mod n`.
5. Hitung `u1 = zw mod n`.
6. Hitung `u2 = rw mod n`.
7. Hitung titik `P = u1G + u2Q`.
8. Tolak signature jika `P` adalah *point at infinity*.
9. Signature valid jika `P.x mod n = r`.

Secara matematis:

$$
w = s^{-1} \bmod n
$$

$$
u_1 = zw \bmod n, \qquad u_2 = rw \bmod n
$$

$$
P = u_1G + u_2Q
$$

Verifier hanya membutuhkan pesan, signature, parameter domain, dan public key. Nonce `k` serta private key `D` tidak dibutuhkan dalam proses verifikasi.

### Mengapa verifikasi bekerja?

Dari proses signing diketahui:

$$
s = k^{-1}(z + rD) \bmod n
$$

Karena `w = s^-1 mod n`, titik yang dihitung verifier adalah:

$$
\begin{aligned}
P &= u_1G + u_2Q \\
  &= zwG + rwQ \\
  &= zwG + rwDG \\
  &= w(z + rD)G \\
  &= s^{-1}(z + rD)G \\
  &= kG \\
  &= R
\end{aligned}
$$

Verifier memperoleh kembali titik `R` tanpa mengetahui `k`. Karena `r` berasal dari koordinat `x` titik `R`, verifier cukup memeriksa:

$$
P.x \bmod n = r
$$

## Validasi public key

Sebelum public key digunakan, implementasi perlu memastikan bahwa:

- `Q` bukan *point at infinity*.
- Koordinat `Q` berada dalam field yang valid.
- `Q` benar-benar berada pada curve.
- `Q` berada pada subgroup yang sesuai.

Validasi ini mencegah public key yang tidak valid masuk ke dalam operasi kriptografi. Pada curve dengan cofactor `1`, seperti `secp256k1`, pemeriksaan subgroup menjadi lebih sederhana, tetapi validasi public key tetap diperlukan.

## Kegagalan nonce dan dampaknya

Titik rawan ECDSA umumnya berada pada cara nonce dihasilkan dan dilindungi, bukan pada matematika curve standar yang digunakan.

### Nonce bocor sepenuhnya

Jika `k` diketahui untuk satu signature, private key dapat dihitung:

$$
D = r^{-1}(sk - z) \bmod n
$$

Satu nonce yang bocor sudah cukup untuk membocorkan private key.

### Nonce digunakan kembali

Misalkan dua pesan berbeda ditandatangani menggunakan private key dan nonce yang sama:

$$
s_1 = k^{-1}(z_1 + rD) \bmod n
$$

$$
s_2 = k^{-1}(z_2 + rD) \bmod n
$$

Karena nilai `k` sama, nilai `r` juga sama. Nonce dapat dihitung dengan:

$$
k = (z_1-z_2)(s_1-s_2)^{-1} \bmod n
$$

Setelah itu, private key dapat dihitung:

$$
D = r^{-1}(s_1k-z_1) \bmod n
$$

Serangan ini hanya membutuhkan aljabar modular dan tidak memerlukan lattice.

### Nonce bias atau bocor sebagian

Jika sebagian bit `k` diketahui, dapat diprediksi, atau memiliki distribusi yang bias, kumpulan signature dapat membentuk **Hidden Number Problem**. Private key kemudian berpotensi dipulihkan menggunakan teknik lattice seperti LLL.

Contoh pola yang berbahaya:

```text
k = prefix_publik || random_bawah
```

Jika `prefix_publik` dapat dihitung penyerang, setiap signature membocorkan bit-bit atas nonce. Setelah mengumpulkan cukup banyak signature, penyerang dapat mencoba memulihkan private key.

| Cara `k` dibuat | Aman? | Dampak atau serangan |
|---|---:|---|
| CSPRNG uniform dengan rejection sampling | Aman | Tidak ada serangan praktis yang diketahui dari nonce |
| RFC 6979 yang diimplementasikan dengan benar | Aman | Mengurangi ketergantungan pada RNG runtime |
| RNG lemah atau sebagian bit dapat diprediksi | Tidak | HNP dan lattice |
| Sebagian bit diisi nilai publik | Tidak | HNP dan lattice |
| `k` digunakan untuk dua pesan berbeda | Tidak | Pemulihan private key dengan aljabar modular |
| `k` bocor penuh pada satu signature | Tidak | Pemulihan private key dengan aljabar modular |

Contoh kelemahan prefix nonce publik dibahas lebih lanjut dalam writeup [Crypto Siren](/posts/2026/08/22/crypto-siren-z0d1ak-ctf-2026/).

## Signature malleability

Pada ECDSA, jika `(r, s)` valid, pasangan berikut secara umum juga valid:

$$
(r, n-s)
$$

Keduanya mewakili signature yang ekuivalen secara matematis. Beberapa sistem menggunakan bentuk canonical **low-s**, yaitu memilih nilai `s` yang berada pada bagian bawah rentang, untuk mengurangi signature malleability.

Signature `(r, s)` pada rumus merupakan representasi matematis. Dalam protokol nyata, kedua nilai tersebut dapat dikodekan menggunakan DER, format raw dengan ukuran tetap, atau format khusus protokol.

## Contoh signing dan verifikasi

Contoh berikut menunjukkan proses ECDSA secara manual menggunakan curve `secp256k1`. Kode ini ditujukan untuk pembelajaran dan tidak boleh digunakan sebagai implementasi produksi.

```python
from ecdsa import SECP256k1
import hashlib
import os

G = SECP256k1.generator
n = int(SECP256k1.order)


def hash_message(message):
    # SHA-256 dan order secp256k1 sama-sama memiliki panjang 256 bit.
    return int.from_bytes(hashlib.sha256(message).digest(), "big")


def random_scalar(order):
    """Menghasilkan integer uniform dalam rentang 1 <= value < order."""
    size = (order.bit_length() + 7) // 8

    while True:
        value = int.from_bytes(os.urandom(size), "big")
        if 1 <= value < order:
            return value


D = random_scalar(n)  # Private key
Q = D * G             # Public key


def sign(message):
    z = hash_message(message)

    while True:
        k = random_scalar(n)
        R = k * G
        r = R.x() % n

        if r == 0:
            continue

        s = (pow(k, -1, n) * (z + r * D)) % n

        if s == 0:
            continue

        return r, s


def verify(message, r, s):
    if not (1 <= r < n and 1 <= s < n):
        return False

    z = hash_message(message)
    w = pow(s, -1, n)
    u1 = (z * w) % n
    u2 = (r * w) % n
    P = u1 * G + u2 * Q

    return P.x() % n == r


message = b"hello"
r, s = sign(message)

print(verify(message, r, s))          # True
print(verify(b"modified", r, s))     # False
```

Library kriptografi yang matang tetap harus digunakan untuk aplikasi nyata. Implementasi produksi juga perlu menangani validasi public key, serialisasi, kegagalan operasi titik, perlindungan side-channel, dan penyimpanan private key dengan aman.

## Ringkasan

- Private key `D` adalah skalar rahasia jangka panjang.
- Public key dihitung sebagai `Q = DG`.
- Nonce `k` adalah skalar rahasia yang hanya digunakan untuk satu signing.
- Signature dihitung sebagai `(r, s)` dengan `r` berasal dari titik `kG`.
- Verifier dapat memperoleh kembali hubungan dengan titik `kG` menggunakan public key, tanpa mengetahui `D` atau `k`.
- Nonce yang bocor, digunakan ulang, bias, atau dapat diprediksi dapat menyebabkan private key dipulihkan.
- Implementasi nyata harus menggunakan library kriptografi yang telah diaudit dan metode nonce yang aman.

## Referensi

- SEC 1: *Elliptic Curve Cryptography*.
- FIPS 186-5: *Digital Signature Standard*.
- RFC 6979: *Deterministic Usage of the Digital Signature Algorithm and Elliptic Curve Digital Signature Algorithm*.
- [Dasar Hidden Number Problem](/posts/2026/08/23/dasar-hidden-number-problem/).
- [ECDSA Nonce Bias dan Hidden Number Problem](/posts/2026/08/22/ecdsa-nonce-bias-dan-hidden-number-problem/).

