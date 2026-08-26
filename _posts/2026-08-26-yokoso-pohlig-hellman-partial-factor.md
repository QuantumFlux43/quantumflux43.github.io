---
title: "YOKOSO :: Pohlig-Hellman + Partial Factor Recovery"
date: 2026-08-26 20:30:00 +0700
lang: id
ref: yokoso-pohlig-hellman-partial-factor
categories: [RSA]
tags: [multiprime, discrete-log, pohlig-hellman, smooth-prime, partial-leak, mod-2k]
description: RSA multiprime dengan hint kombinasi e^s modulo N prima yang N-1 nya smooth. Discrete log via Pohlig-Hellman balikin s = q*r mod 2^512, lalu partial factor recovery balikin p exact.
---

<div class="callout info"><span class="lbl">info soal</span>
<b>CTF:</b> KIRAKIRA :: <b>Kategori:</b> Crypto (RSA) :: <b>Soal:</b> YOKOSO
</div>

RSA multiprime `n = p*q*r`. Ada hint `u = able(s)` yang menyembunyikan rahasia
`s = (q*r) mod 2^512` di dalam kombinasi pangkat modular `e^s`. Modulus hint `N`
prima dengan `N-1` **smooth**, jadi discrete log jadi feasible. Setelah dapat
`s`, bocoran sebagian cukup untuk memfaktorkan RSA lewat aritmetika mod `2^512`.

## Soal

```python
from Crypto.Util.number import *

flag = "YOKOSO_KIRAKIRA_..."
N = 0x11b4c225...a5a47          # 781-bit, prima

def able(s):
    a = inverse(e, N)           # e^-1 mod N
    b = pow(a, 2, N)            # e^-2 mod N
    return (pow(e, s, N) + pow(a, s, N) + pow(b, s, N)) % N

def solv(nbit):
    pbit = nbit // 3            # 512
    p, q, r = [getPrime(pbit) for _ in range(3)]
    return p*q*r, able((q * r) % (1 << pbit))   # s = (q*r) mod 2^512

m = bytes_to_long(flag.encode())
e = 65537
n, u = solv(1536)
c = pow(m, e, n)
# diberikan: n, u, c  (dan N, e di source)
```

## Recon

- `N` = 781-bit, **prima**. Faktorkan `N-1` (trial division) → semua faktor prima
  `≤ ~2^20` = **smooth**. Sinyal besar: discrete log mod N feasible via
  Pohlig-Hellman.
- `n = p*q*r`, tiap prima 512-bit → RSA multiprime (~1536-bit).
- `s = (q*r) mod 2^512` → cuma 512 bit bawah dari `q*r` (1024-bit).
- Flag ~488-bit `< p` (512-bit).

## Langkah 1: hint → persamaan polinomial

`able(s)` dengan `a = e^-1`, `b = e^-2`:

$$
u = e^{s} + e^{-s} + e^{-2s} \pmod N .
$$

Kalikan `e^{2s}` untuk membuang pangkat negatif, misalkan `X = e^s`:

$$
u \cdot e^{2s} = e^{3s} + e^{s} + 1
\;\Longrightarrow\;
X^{3} - u\,X^{2} + X + 1 \equiv 0 \pmod N .
$$

`N` prima → faktorkan polinomial mod N, ambil akar linear `X = e^s`.

```python
import sympy
from Crypto.Util.number import inverse
x = sympy.symbols('x')
poly = sympy.Poly(x**3 - u*x**2 + x + 1, x, modulus=N)
roots = [(-a0 * inverse(int(a1), N)) % N
         for fac, _ in poly.factor_list()[1] if fac.degree() == 1
         for a1, a0 in [fac.all_coeffs()]]
```

## Langkah 2: discrete log (Pohlig-Hellman)

`X = e^s mod N`, cari `s`. Karena `N-1` smooth, pakai Pohlig-Hellman: pecah `s`
jadi `s mod p` per faktor prima kecil `p` dari `N-1`, gabung dengan CRT. Tiap
`s mod p` dicari pakai BSGS (`~√p` langkah). Selesai < 0.3 detik. Teori + kode
lengkap: [Pohlig-Hellman DLP](/posts/2026/08/26/pohlig-hellman-dlp-smooth/).

> `sympy.discrete_log` bisa stuck/error; implementasi manual PH + BSGS lebih
> terkontrol. Faktorkan `N-1` cukup trial division (smooth → cepat).

Hasilnya `s = (q*r) mod 2^512`.

## Langkah 3: partial factor recovery mod 2^512

`s` hanya 512 bit bawah dari `q*r`. Untuk `n = p*(qr)`, ambil mod `2^512`:

$$
n \equiv p \cdot (qr) \equiv p \cdot s \pmod{2^{512}}
\;\Longrightarrow\;
p \equiv (n \bmod 2^{512}) \cdot s^{-1} \pmod{2^{512}} .
$$

Karena `p` 512-bit `< 2^512`, hasilnya `p` **exact**. Detail teknik:
[Partial Factor Recovery mod 2^k](/posts/2026/08/26/partial-factor-recovery-mod-2k/).

```python
M = 1 << 512
p = (n % M) * inverse(s % M, M) % M     # p exact
assert n % p == 0
```

## Langkah 4: decrypt tanpa memfaktorkan qr

RSA multiprime butuh `phi = (p-1)(q-1)(r-1)` — artinya harus faktorkan `qr`
(dua prima 512-bit, keras). **Shortcut:** flag `m < p`, jadi `m mod p = m`,
cukup decrypt mod p.

```python
from Crypto.Util.number import long_to_bytes
d_p = inverse(e, p - 1)
m = pow(c % p, d_p, p)                   # m < p => m penuh
flag = long_to_bytes(m)
```

## Solver lengkap

```python
from math import isqrt
from Crypto.Util.number import inverse, long_to_bytes
from sympy.ntheory.modular import crt
import sympy

def bsgs(g, h, mod, nord):
    step = isqrt(nord) + 1
    tbl, cur = {}, 1
    for j in range(step):
        tbl.setdefault(cur, j); cur = cur * g % mod
    fac = pow(g, (mod - 1 - step) % (mod - 1), mod)
    gamma = h
    for i in range(step):
        if gamma in tbl:
            return i * step + tbl[gamma]
        gamma = gamma * fac % mod

def solve(N, e, n, u, c):
    # 1. cubic root
    x = sympy.symbols('x')
    poly = sympy.Poly(x**3 - u*x**2 + x + 1, x, modulus=N)
    roots = [(-a0 * inverse(int(a1), N)) % N
             for fac, _ in poly.factor_list()[1] if fac.degree() == 1
             for a1, a0 in [fac.all_coeffs()]]
    # faktor N-1 (smooth)
    m = N - 1; facs = {}
    for pr in range(2, 1_100_000):
        while m % pr == 0:
            facs[pr] = facs.get(pr, 0) + 1; m //= pr
        if m == 1: break
    order = N - 1; M = 1 << 512
    for X in roots:
        # 2. Pohlig-Hellman dlog
        res, mods = [], []
        for pr, k in facs.items():
            pk = pr**k; exp = order // pk
            d = bsgs(pow(e, exp, N), pow(X, exp, N), N, pk)
            if d is None: break
            res.append(d % pk); mods.append(pk)
        else:
            s = int(crt(mods, res)[0])
            if pow(e, s, N) != X: continue
            # 3. partial factor recovery
            try: p = (n % M) * inverse(s % M, M) % M
            except ValueError: continue
            if p <= 1 or n % p: continue
            # 4. decrypt mod p (m < p)
            fb = long_to_bytes(pow(c % p, inverse(e, p - 1), p))
            if fb.isascii(): return fb
```

## Flag

```text
YOKOSO_KIRAKIRA_..._MOCHIMOCHI_PUYOPUYO_WAKUWAKU_WASHOI
```

## Catatan

- Syarat mati/hidup serangan = **`N-1` smooth**. Kalau `N-1` punya satu faktor
  prima besar, discrete log kembali keras dan rantai gagal sejak Langkah 2.
- Pengetahuan kecil yang dipisah ke knowledge:
  [Pohlig-Hellman DLP](/posts/2026/08/26/pohlig-hellman-dlp-smooth/),
  [Partial Factor Recovery mod 2^k](/posts/2026/08/26/partial-factor-recovery-mod-2k/),
  [Bit-Length Reasoning](/posts/2026/08/26/bit-length-reasoning-ctf-crypto/).
