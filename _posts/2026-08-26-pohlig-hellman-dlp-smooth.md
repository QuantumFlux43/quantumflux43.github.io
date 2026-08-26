---
title: "Pohlig-Hellman: DLP saat p-1 Smooth"
date: 2026-08-26 13:00:00 +0700
lang: id
ref: pohlig-hellman-dlp-smooth
platform: knowledge
kn_cat: rsa
tags: [discrete-log, pohlig-hellman, bsgs, smooth-prime, crt]
description: Discrete log modulo prima jadi mudah kalau p-1 smooth. Pohlig-Hellman pecah dlog jadi per faktor prima kecil lalu CRT gabung. BSGS untuk tiap sub-problem.
---

Pengetahuan kecil yang wajib jadi refleks: **tiap ketemu discrete log,
faktorkan `p-1` dulu**. Kalau `p-1` smooth (semua faktor prima kecil), DLP yang
biasanya keras jadi feasible lewat Pohlig-Hellman.

## Peta variabel

| variabel | peran | hubungan |
|---|---|---|
| `g` | basis / generator (diketahui) | `g^x ≡ h mod p` |
| `h` | target (diketahui) | `= g^x mod p` |
| `p` | modulus prima (diketahui) | orde grup = `p-1` |
| `x` | eksponen rahasia yang **dicari** | dlog basis `g` dari `h` |
| `p-1` | orde grup | harus **smooth** supaya feasible |
| `facs` | faktor prima dari `p-1` | `{p_i: e_i}`; sub-problem per `p_i` |
| `q, k` | satu faktor prima `q` pangkat `k` | `qk = q^k` (subgrup) |

Alur ketergantungan: `p-1` difaktorkan jadi `facs` → tiap faktor `q^k` jadi satu
sub-dlog kecil (BSGS) menghasilkan `x mod q^k` → semua digabung CRT jadi `x`.
Jadi `g,h,p` input, `x` output, dan `facs` (dari `p-1`) yang menentukan apakah
serangan jalan.

## Masalah

Discrete Logarithm Problem (DLP): diberi `g`, `h`, `p`, cari `x` sehingga

$$
\underbrace{g}_{\text{basis}}^{\;\underbrace{x}_{\text{cari}}} \equiv \underbrace{h}_{\text{target}} \pmod{\underbrace{p}_{\text{prima}}}
$$

Umumnya keras (dasar keamanan Diffie-Hellman). **Celah:** kalau orde `g`
(pembagi `p-1`) hanya punya faktor prima kecil, dlog pecah jadi potongan kecil.

## Apa itu smooth

`p-1` disebut **B-smooth** kalau semua faktor primanya `≤ B`. Contoh:

```
p-1 = 2 · 533213 · 543203 · ...   (semua ≤ ~10^6)  -> smooth, B ~ 2^20
```

Cek cepat pakai trial division — kalau habis dibagi sampai `1` oleh prima kecil,
smooth:

```python
def smooth_factor(m, B=1_100_000):
    facs = {}
    for p in range(2, B):
        while m % p == 0:
            facs[p] = facs.get(p, 0) + 1; m //= p
        if m == 1: break
    return facs if m == 1 else None      # None = ada faktor besar (tak smooth)
```

## Ide Pohlig-Hellman

Pecah `x` menjadi `x mod p_i^{e_i}` untuk tiap faktor prima `p_i` dari orde,
lalu gabung dengan CRT (Chinese Remainder Theorem). Tiap sub-problem hidup di
grup kecil berukuran `p_i`, jadi bisa diselesaikan cepat dengan Baby-step
Giant-step (`~√p_i` langkah).

$$
\text{biaya} \approx \sum_i e_i \sqrt{p_i} \quad\ll\quad \sqrt{p} \ (\text{brute penuh})
$$

## Baby-step Giant-step (BSGS)

Menyelesaikan `g^x = h` dalam grup berorde `n` dengan `O(√n)` waktu & memori:

```python
from math import isqrt

def bsgs(g, h, mod, n):
    step = isqrt(n) + 1
    tbl, cur = {}, 1
    for j in range(step):                       # baby steps: g^j
        tbl.setdefault(cur, j); cur = cur * g % mod
    factor = pow(g, (mod - 1 - step) % (mod - 1), mod)   # g^-step
    gamma = h
    for i in range(step):                       # giant steps
        if gamma in tbl:
            return i * step + tbl[gamma]
        gamma = gamma * factor % mod
    return None
```

## Pohlig-Hellman lengkap

```python
from sympy.ntheory.modular import crt

def pohlig_hellman(g, h, p, facs):     # facs = {prime: exp} dari p-1
    order = p - 1
    res, mods = [], []
    for q, k in facs.items():
        qk = q ** k
        exp = order // qk
        gq = pow(g, exp, p)            # elemen berorde qk
        hq = pow(h, exp, p)
        x = bsgs(gq, hq, p, qk)        # x = dlog dalam subgrup qk
        res.append(x % qk); mods.append(qk)
    return int(crt(mods, res)[0])      # gabung via CRT
```

> `sympy.discrete_log` bisa stuck atau minta `order_factors` dan error. Untuk
> `p-1` smooth, implementasi manual PH + BSGS lebih terkontrol dan cepat
> (dlog 780-bit < 0.3 detik). Selalu verifikasi: `pow(g, x, p) == h`.

## Kapan berlaku

| Syarat | Keterangan |
|---|---|
| `p-1` smooth | faktor prima terbesar `p_max ≲ 2^40` (feasible) |
| orde `g` memuat target | `x < ord(g)`; kalau `g` orde kecil, dlog ambigu |
| BSGS memori | `~√p_max` entri tabel; besar untuk `p_max` besar |

**Gagal** kalau `p-1` punya satu faktor prima besar (`≥ 2^80`) — dlog kembali
keras. Ini justru cara memilih grup DH/RSA yang aman: pastikan `p-1` punya faktor
prima besar.

## Konteks lebih luas

- **Orde grup lain:** untuk kurva eliptik, "smooth" berlaku pada orde kurva
  (bukan `p-1`). Untuk clock group `x^2+y^2=1`, orde `p+1`. PH sama saja.
- **Kombinasi:** PH sering dipadu invalid-curve / small-subgroup attack untuk
  memaksa target ke subgrup smooth.

## Contoh nyata di CTF

Soal YOKOSO: hint disederhanakan jadi `X = e^s mod N` dengan `N` prima dan `N-1`
smooth → PH balikin `s` (780-bit) dalam sekejap. Lihat
[YOKOSO writeup](/posts/2026/08/26/yokoso-pohlig-hellman-partial-factor/).

## Referensi

- Pohlig & Hellman (1978), "An Improved Algorithm for Computing Logarithms over GF(p)".
- Shanks — Baby-step Giant-step.
- Pollard's rho for logarithms — alternatif `O(√n)` dengan memori `O(1)`.
