---
title: "ECDSA Nonce Reuse — Contoh Writeup"
date: 2026-08-05 09:00:00 +0700
categories: [ECC]
tags: [ecdsa, nonce-reuse]
description: Contoh writeup ketiga, kategori berbeda lagi untuk uji tampilan.
---

## Ringkasan

Dua signature dari pesan berbeda memakai nonce $k$ yang sama. Karena
$s = k^{-1}(h + rd) \bmod n$, dua persamaan dengan $k$ yang sama bisa
dieliminasi untuk memulihkan $k$, lalu private key $d$.

$$
k = \frac{h_1 - h_2}{s_1 - s_2} \bmod n, \qquad
d = \frac{s_1 k - h_1}{r} \bmod n
$$

## Flag

```text
FLAG{never_reuse_your_nonce}
```
