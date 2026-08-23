---
title: "Crypto Siren :: Partial Nonce Leak (HNP + LLL)"
date: 2026-08-22 22:25:39 +0700
lang: id
ref: crypto-siren-z0d1ak-ctf-2026
categories: [ECC]
tags: [ecdsa, nonce-leak, hidden-number-problem, lattice, lll, secp256k1]
description: Server ECDSA membocorkan 10 bit teratas nonce lewat hash publik. Hidden Number Problem + LLL balikin private key, tinggal forge signature buat pesan target.
---

<div class="callout info"><span class="lbl">info soal</span>
<b>CTF:</b> Z0D1AK CTF 2026 :: <b>Kategori:</b> Crypto (ECC) :: <b>Nama Soal:</b> Crypto Siren
</div>

Server ini punya oracle signing ECDSA di curve `secp256k1`. Semua pesan bisa
ditandatangani, kecuali satu pesan target `unlock:release-the-tide`. Tujuannya
bikin signature valid buat pesan target itu tanpa pernah dapat tanda tangannya
langsung dari server. Celahnya ada di nonce `k`: 10 bit teratasnya bisa dihitung
publik dari hash, sehingga banyak signature bisa dirangkai jadi Hidden Number
Problem dan diselesaikan pakai LLL buat recover private key.

## Soal

Server (`siren_server.py`) expose 3 command lewat socket line-JSON:

```text
pubkey          -> balikin curve, Qx, Qy, n, song_id, pitch_bits, priv_msg
sign {msg}      -> balikin (r, s) untuk pesan bebas (tolak kalau msg == priv_msg)
unlock {r, s}   -> verify signature untuk priv_msg, kalau valid balikin flag
```

Fungsi signing:

```python
def sign(msg):
    z = msg_hash(msg)
    while True:
        k = shaped_nonce(msg)
        R = k * G
        r = R.x() % N
        if r == 0:
            continue
        s = (pow(k, -1, N) * (z + r * D)) % N
        if s == 0:
            continue
        return r, s
```

Nonce `k` dibentuk bukan dari `os.urandom` penuh, tapi punya bagian atas yang
deterministik:

```python
PITCH_BITS = 10
SUFFIX_BITS = NBITS - PITCH_BITS   # 246

def public_pitch(msg):
    material = (SONG_ID + ":" + msg).encode()
    h = int.from_bytes(hashlib.sha256(material).digest(), "big")
    return h >> (256 - PITCH_BITS)

def shaped_nonce(msg):
    prefix = public_pitch(msg) << SUFFIX_BITS
    while True:
        k = prefix | (rng_below(SUFFIX_BOUND) - 1)
        if 1 <= k < N:
            return k
```

`SONG_ID` dikasih server lewat command `pubkey`, jadi `public_pitch(msg)` bisa
dihitung sendiri buat pesan apapun yang kita pilih. Artinya **10 bit teratas
nonce diketahui publik** untuk setiap signature yang kita minta.

### Struktur bit nonce

Nonce `k` berukuran 256 bit, tapi cuma dirakit dari dua bagian: 10 bit atas
deterministik (dari hash publik) dan 246 bit bawah random rahasia.

```text
                         NONCE k (256 bit)
 +---------------------+----------------------------------------------+
 |   PITCH (10 bit)    |            SUFFIX (246 bit)                   |
 |   diketahui publik  |            random rahasia                     |
 +---------------------+----------------------------------------------+
   ^                     ^
   public_pitch(msg)     rng_below(SUFFIX_BOUND) - 1
   = SHA256(SONG_ID:msg) = tak diketahui penyerang
     >> 246

 bit index: 255 ...... 246 245 ..................................... 0
            |-- 10 bit --|   |------------- 246 bit -------------|
               ketahuan            gelap (harus ditebak)
```

Cara `k` dirakit di kode:

```text
public_pitch(msg)  = b b b b b b b b b b            (10 bit hash, PUBLIK)

prefix = pitch << 246:
   b b b b b b b b b b 0 0 0 ... 0 0 0              (digeser ke atas)
   |---- 10 bit ------| |---- 246 nol ----|

random bawah (RAHASIA):
   0 0 0 0 0 0 0 0 0 0 r r r ... r r r

k = prefix | random:
   b b b b b b b b b b r r r ... r r r
   |-- diketahui ----| |-- tidak diketahui --|
```

Untuk tiap signature, penyerang menghitung sendiri 10 bit teratasnya:

```text
SONG_ID  -- dari command "pubkey" (publik)
msg      -- penyerang yang pilih
              |
              v
   SHA256(SONG_ID + ":" + msg) >> 246  =  pitch  =  10 bit teratas k
```

Jadi tiap nonce berbentuk `k = a + e`, dengan `a` (prefix) diketahui dan
`e` (246 bit bawah) kecil relatif ke `n`:

```text
k = [ prefix 10-bit publik ][ error 246-bit ]
    |-------- a (known) ----||--- e (< 2^246) ---|
```

Skala bocornya: cuma 10 dari 256 bit (~3.9%) yang bocor per nonce, tapi itu
sudah cukup buat HNP.

```text
n (256 bit): ########################################################  256
bocor:       ##                                                        10  (3.9%)
gelap:         ######################################################  246 (96.1%)
```

## Analisis

Ini pola klasik *biased nonce ECDSA* -> Hidden Number Problem. Nonce tidak
sepenuhnya random, sebagian bitnya bocor / predictable, dan itu cukup buat
recover private key kalau ada cukup banyak sample.

Poin kunci: server cuma menolak nonce lewat pesan yang identik dengan
`priv_msg`, tapi tidak membatasi bocornya prefix nonce untuk pesan lain. Jadi
strategi: minta signature buat banyak pesan pilihan sendiri, hitung `prefix`
tiap pesan, susun HNP, jalankan LLL, dapatkan `D`, lalu forge signature untuk
`priv_msg` pakai `D` yang sudah diketahui (signing manual, tidak lewat oracle).

## Dasar matematika

Persamaan ECDSA:

$$
s = k^{-1}(z + rD) \bmod n
$$

Disusun ulang jadi bentuk linear di `k`:

$$
k = s^{-1}z + s^{-1}rD \bmod n
$$

Karena `k = prefix + e` dengan `e` kecil (`e < 2^SUFFIX_BITS`), substitusi:

$$
s^{-1}z - \text{prefix} \equiv -\,s^{-1}r \cdot D + e \pmod n
$$

Definisikan `t = r/s mod n` dan `u = (z/s - prefix) mod n` per sample. Maka
`u - u' = -t \cdot D + e` (mod n) untuk tiap sample, alias tipe HNP standar:
diketahui `t_i`, `u_i` publik, incar `D` dengan error `e_i` kecil. Dibangun
matriks lattice (skala `SCALE = n / 2^SUFFIX_BITS`) berukuran `(m+2) x (m+2)`:

```text
baris i (0..m-1) : SCALE*n di diagonal kolom i
baris m          : SCALE*t_0 ... SCALE*t_{m-1}, 1, 0
baris m+1        : SCALE*u_0 ... SCALE*u_{m-1}, 0, n
```

LLL reduction bikin salah satu baris hasil punya entry kolom `-2` sama dengan
`D` (atau `-D mod n`), yang dicek balik dengan `(d*G).x() == pubkey_x`.

Dimensi matriks `= m + 2`: `m` baris untuk `m` sample, plus 2 baris ekstra
(satu untuk unknown `D`, satu untuk konstanta modulus `n`). Solver di sini
memakai `m = 50`, jadi lattice-nya berdimensi `52 x 52`.

### Berapa sample yang dibutuhkan?

Batas informasi kasar HNP: total bit bocor harus melebihi ukuran rahasia,

$$
m \cdot \ell \gtrsim \log_2 n
$$

dengan `ℓ` = bit bocor per sample dan `log2(n)` = ukuran private key. Di
sini `ℓ = 10`, `n` = 256-bit, jadi secara teoretis butuh
`m >= 256/10 ~ 26` sample. Praktiknya diambil lebih banyak sebagai margin,
karena LLL bukan oracle sempurna dan konstruksi lattice perlu vector target
menonjol jelas — solver memakai `m = 50` (sekitar dua kali batas teoretis)
supaya andal. Angka praktis kasar per tingkat leak:

| Bit bocor/sig (`ℓ`) | Sample praktis | Catatan |
|---|---|---|
| ~4 bit | ~80-100+ | mepet, kadang perlu BKZ |
| ~8 bit | ~40-60 | LLL cukup |
| ~10 bit | ~30-50 | nyaman (kasus ini) |
| ~128 bit (short nonce) | 2-3 | trivial |
| 1 bit | ratusan+ | perlu BKZ / metode khusus |

Estimasi ini kasar; keberhasilan aktual bergantung kualitas reduksi (LLL vs
BKZ), scaling lattice, dan margin di atas batas teoretis. Analisis formalnya
ada di rujukan bagian Catatan.

## Solver

```python
#!/usr/bin/env python3
import hashlib, json, socket, ssl, sys
from ecdsa import SECP256k1
from fpylll import IntegerMatrix, LLL

G = SECP256k1.generator
N = int(SECP256k1.order)
PITCH_BITS = 10
SUFFIX_BITS = N.bit_length() - PITCH_BITS
B = 1 << SUFFIX_BITS
SCALE = N // B
PRIV_MSG = "unlock:release-the-tide"

def sha_int(data):
    return int.from_bytes(hashlib.sha256(data).digest(), "big")

def msg_hash(msg):
    return sha_int(msg.encode()) % N

def public_pitch(song_id, msg):
    return sha_int((song_id + ":" + msg).encode()) >> (256 - PITCH_BITS)

class Client:
    def __init__(self, host, port, use_tls=False):
        self.sock = socket.create_connection((host, port))
        if use_tls:
            ctx = ssl.create_default_context()
            self.sock = ctx.wrap_socket(self.sock, server_hostname=host)
        self.f = self.sock.makefile("rwb", buffering=0)
        self.recv()

    def recv(self):
        return json.loads(self.f.readline().decode())

    def cmd(self, obj):
        self.f.write((json.dumps(obj) + "\n").encode())
        return self.recv()

def recover_key(samples, pubkey_x):
    m = len(samples)
    M = IntegerMatrix(m + 2, m + 2)
    for i in range(m):
        M[i, i] = SCALE * N
    for i, (t, u) in enumerate(samples):
        M[m, i] = SCALE * t
        M[m + 1, i] = SCALE * u
    M[m, m] = 1
    M[m + 1, m + 1] = N
    LLL.reduction(M)
    for row in range(m + 2):
        v = [int(M[row, col]) for col in range(m + 2)]
        for d in (v[-2] % N, (-v[-2]) % N):
            if d and (d * G).x() % N == pubkey_x:
                return d
    raise RuntimeError("private key not found; collect more signatures")

def forge(d, msg):
    z = msg_hash(msg)
    k = sha_int(("forge:" + msg + ":" + hex(d)).encode()) % (N - 1) + 1
    r = (k * G).x() % N
    s = (pow(k, -1, N) * (z + r * d)) % N
    return r, s

def main():
    c = Client(sys.argv[1], int(sys.argv[2]), len(sys.argv) == 4 and sys.argv[3] == "--ssl")
    pub = c.cmd({"cmd": "pubkey"})
    song_id = pub["song_id"]
    pubkey_x = int(pub["Qx"], 16)

    samples = []
    for i in range(50):
        msg = f"chosen-message-{i}"
        sig = c.cmd({"cmd": "sign", "msg": msg})
        r = int(sig["r"], 16); s = int(sig["s"], 16)
        z = msg_hash(msg)
        prefix = public_pitch(song_id, msg) << SUFFIX_BITS
        inv_s = pow(s, -1, N)
        t = (r * inv_s) % N
        u = (z * inv_s - prefix) % N
        samples.append((t, u))

    d = recover_key(samples, pubkey_x)
    r, s = forge(d, PRIV_MSG)
    print(c.cmd({"cmd": "unlock", "r": hex(r), "s": hex(s)}))

if __name__ == "__main__":
    main()
```

```console
$ python3 solve.py siren-b3984e5d4b96.chals.z0d1ak.org 1337 --ssl
{'flag': 'zdk{A_F3W_8lT5_Per_S1GNATuR3_SlnkS_7h3_KeY}'}
```

## Flag

```text
zdk{A_F3W_8lT5_Per_S1GNATuR3_SlnkS_7h3_KeY}
```

## Catatan

- Dengan `m = 50` sample (lattice `52 x 52`, karena dimensi `= m + 2`),
  bocoran 10 bit per nonce dari total 256 bit sudah cukup untuk recover
  private key. Batas teoretisnya sekitar 26 sample (`m·ℓ >= log2 n`), 50
  dipakai sebagai margin — HNP + LLL efisien walau leak-nya kecil.
- Mitigasi: nonce ECDSA wajib generate full-random per signature (atau
  deterministik lewat RFC 6979), jangan pernah campur input publik (`msg`,
  `song_id`) ke bit manapun dari `k`.
- Studi lanjut: Minerva attack, Lattice attack on repeated/related nonce,
  RFC 6979 deterministic nonce sebagai mitigasi standar.

## Referensi

- Nguyen & Shparlinski (2003), *The Insecurity of the Elliptic Curve Digital
  Signature Algorithm with Partially Known Nonces* — bound teoretis bit/sample.
- Howgrave-Graham & Smart (2001), *Lattice Attacks on Digital Signature
  Schemes* — analisis praktis jumlah sample untuk DSA/ECDSA nonce leak.
- Boneh & Venkatesan (1996), *Hardness of Computing the Most Significant Bits
  of Secret Keys in Diffie-Hellman* — paper asal Hidden Number Problem.
- Albrecht & Heninger (2021), *On Bounded Distance Decoding with Predicate* —
  state of the art untuk leak sangat kecil (butuh BKZ + predicate).
- Materi terkait: [Dasar Hidden Number Problem](/posts/2026/08/23/dasar-hidden-number-problem/),
  [ECDSA Nonce Bias dan Hidden Number Problem](/posts/2026/08/22/ecdsa-nonce-bias-dan-hidden-number-problem/).
</content>
