---
title: "CBC Padding Oracle — Contoh Writeup"
date: 2026-08-10 14:00:00 +0700
categories: [AES]
tags: [cbc, padding-oracle]
description: Contoh writeup kedua untuk menguji tampilan kategori & tag.
math: false
---

<div class="callout danger"><span class="lbl">catatan</span>
Post contoh kedua, buat ngecek tampilan sidebar kategori & tag. Hapus kalau sudah tidak perlu.
</div>

## Ringkasan

Server membocorkan apakah padding PKCS#7 dari ciphertext yang dimodifikasi valid atau tidak. Itu cukup untuk mendekripsi seluruh blok tanpa kunci.

## Solver

```python
def decrypt_block(oracle, prev_block, target_block):
    intermediate = bytearray(16)
    for pad in range(1, 17):
        found = False
        for guess in range(256):
            crafted = bytearray(16)
            for i in range(pad - 1):
                crafted[15 - i] = intermediate[15 - i] ^ pad
            crafted[16 - pad] = guess
            if oracle(bytes(crafted) + target_block):
                intermediate[16 - pad] = guess ^ pad
                found = True
                break
        if not found:
            raise Exception("oracle gagal di posisi", pad)
    return bytes(a ^ b for a, b in zip(intermediate, prev_block))
```

## Flag

```text
FLAG{padding_oracle_leaks_everything}
```
