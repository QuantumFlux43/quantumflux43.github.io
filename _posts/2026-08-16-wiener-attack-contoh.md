---
title: "Small-d — Contoh Writeup (Wiener Attack)"
date: 2026-08-16 20:00:00 +0700
categories: [RSA]
tags: [wiener, continued-fractions]
description: Contoh writeup lengkap sebagai acuan format — serangan Wiener pada RSA dengan eksponen privat kecil.
---

<div class="callout danger"><span class="lbl">catatan</span>
Post ini contoh format saja. Hapus atau edit setelah kamu paham strukturnya.
</div>

<div class="callout info"><span class="lbl">info soal</span>
<b>CTF:</b> Contoh CTF 2026 &middot; <b>Kategori:</b> Crypto &middot; <b>Poin:</b> 200
</div>

Public exponent `e` berukuran hampir sepanjang `n` — tanda klasik bahwa `d`
dibuat kecil untuk mempercepat dekripsi. Serangan Wiener memulihkan `d` dalam
hitungan milidetik lewat ekspansi pecahan lanjut dari $e/n$.

## Soal

```python
# chall.py
from Crypto.Util.number import getPrime, bytes_to_long, inverse

p, q = getPrime(512), getPrime(512)
n, phi = p*q, (p-1)*(q-1)

while True:
    d = getPrime(200)          # d cuma 200 bit untuk n 1024 bit
    if GCD(d, phi) == 1: break
e = inverse(d, phi)

print(f"{n = }\n{e = }")
print("c =", pow(bytes_to_long(FLAG), e, n))
```

## Analisis

Hal pertama yang gua cek tiap soal RSA adalah ukuran `e`. Di sini `e` punya
~1024 bit, bukan `65537`. Karena $ed \equiv 1 \pmod{\varphi(n)}$, `e` yang
besar berarti `d` yang kecil — dan `d` kecil punya batas keamanan yang sudah
diketahui.

Cek cepat: $n$ 1024 bit, jadi $n^{1/4} \approx 2^{256}$. Karena
$d < 2^{200} < \tfrac{1}{3}n^{1/4}$, soal ini masuk tepat di dalam bound Wiener.

## Dasar matematika

Mulai dari persamaan kunci

$$
ed - k\varphi(n) = 1.
$$

Bagi dengan $d\varphi(n)$:

$$
\left|\frac{e}{\varphi(n)} - \frac{k}{d}\right| = \frac{1}{d\varphi(n)}.
$$

Karena $\varphi(n) = n - (p+q) + 1$ dan $p+q < 3\sqrt{n}$, maka $\varphi(n)$
sangat dekat ke $n$. Menggantinya menghasilkan

$$
\left|\frac{e}{n} - \frac{k}{d}\right| < \frac{3}{d\sqrt{n}} \le \frac{1}{2d^2}
\quad \text{bila } d < \tfrac{1}{3}n^{1/4}.
$$

<div class="callout tip"><span class="lbl">teorema legendre</span>
Kalau sebuah pecahan $k/d$ mendekati $x$ lebih rapat dari $1/(2d^2)$, maka
$k/d$ dijamin muncul sebagai salah satu konvergen ekspansi pecahan lanjut
$x$. Jadi kita tidak perlu menebak — cukup enumerasi $O(\log n)$ konvergen
dari $e/n$ dan uji satu per satu.
</div>

Verifikasi kandidat: dari $(k,d)$ hitung $\varphi = (ed-1)/k$, lalu selesaikan
$x^2 - (n - \varphi + 1)x + n = 0$. Kalau diskriminannya kuadrat sempurna,
kandidatnya benar dan akarnya adalah $p$ dan $q$.

## Solver

```python
#!/usr/bin/env python3
from gmpy2 import isqrt, is_square
from Crypto.Util.number import long_to_bytes

n = 0x...
e = 0x...
c = 0x...

def cf(a, b):
    while b:
        q = a // b
        yield q
        a, b = b, a - q * b

def convergents(gen):
    h1, h2, k1, k2 = 1, 0, 0, 1
    for q in gen:
        h1, h2 = q * h1 + h2, h1
        k1, k2 = q * k1 + k2, k1
        yield h1, k1

for k, d in convergents(cf(e, n)):
    if k == 0 or (e * d - 1) % k:
        continue
    phi = (e * d - 1) // k
    s = n - phi + 1
    if s % 2 or not is_square(s * s - 4 * n):
        continue
    r = isqrt(s * s - 4 * n)
    p, q = (s + r) // 2, (s - r) // 2
    assert p * q == n
    print(f"[+] d = {d}")
    print(long_to_bytes(pow(c, d, n)).decode())
    break
```

```console
$ python3 solve.py
[+] d = 1073...
FLAG{legendre_did_all_the_work}
```

## Flag

```text
FLAG{legendre_did_all_the_work}
```

## Catatan

- Kalau `d` sedikit di atas bound Wiener, lanjut ke **Boneh–Durfee** yang
  mendorong batasnya ke $d < N^{0.292}$ lewat lattice reduction.
- Referensi: M. Wiener, *Cryptanalysis of Short RSA Secret Exponents* (1990).
