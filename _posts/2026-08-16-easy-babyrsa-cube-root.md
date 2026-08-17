---
title: "easy_babyrsa :: Cube Root Attack"
date: 2026-08-16 20:00:00 +0700
categories: [RSA]
tags: [low-exponent, cube-root, e-3]
description: Public exponent e=3 dan pesan kecil bikin ciphertext cuma m pangkat 3 tanpa reduksi mod n. Cube root biasa langsung balikin flag.
---

<div class="callout info"><span class="lbl">info soal</span>
<b>CTF:</b> 0xV01D :: <b>Kategori:</b> Crypto :: <b>Soal:</b> 02_easy_babyrsa
</div>

<div class="lang-en" markdown="1">
The challenge only gives `n`, `e = 3`, and `c`. Seeing `e = 3` next to a 1024-bit
`n`, the first suspicion is that the message is small, so encryption never wraps
around the modulus. If so, `c = m^3` over the plain integers and the flag is just
the integer cube root.
</div>
<div class="lang-id" markdown="1">
Soal cuma ngasih `n`, `e = 3`, dan `c`. Begitu liat `e = 3` yang gede sebelah
`n` 1024 bit, curiga pertama: pesannya kecil, jadi enkripsi ga pernah kena
reduksi modulo. Kalau bener, `c = m^3` di bilangan bulat biasa dan flag tinggal
diambil dari akar pangkat tiga.
</div>

## Soal

```text
n = 19079856583289673796614740682547240911232879513633706098802604985095556642330...913453
e = 3
c = 1678720587246671095744837808048280852040449638117561797172368829524200937354150...434149
```

<div class="lang-en" markdown="1">
`n` is about 1024 bits. `c` is only around 190 decimal digits, far smaller than
`n`. That is a strong hint that `m^3` does not exceed `n`.
</div>
<div class="lang-id" markdown="1">
`n` sekitar 1024 bit. `c` cuma sekitar 190 digit desimal, jauh lebih kecil dari
`n`. Itu petunjuk kuat kalau `m^3` ga melebihi `n`.
</div>

## Analisis

<div class="lang-en" markdown="1">
RSA encryption: `c = m^e mod n`. With `e = 3`:
</div>
<div class="lang-id" markdown="1">
Enkripsi RSA: `c = m^e mod n`. Dengan `e = 3`:
</div>

$$
c = m^3 \bmod n .
$$

<div class="lang-en" markdown="1">
The `mod n` only matters when `m^3 >= n`. If the message `m` is small enough that
`m^3 < n`, there is no reduction at all and
</div>
<div class="lang-id" markdown="1">
Operasi `mod n` cuma berpengaruh kalau `m^3 >= n`. Kalau pesan `m` cukup kecil
sampai `m^3 < n`, maka tidak ada reduksi sama sekali dan
</div>

$$
c = m^3 \quad\text{(over the full integers)}.
$$

<div class="lang-en" markdown="1">
So `m` is simply the integer cube root of `c`, with no need to know the factors
`p` and `q` at all. The private key is irrelevant here.
</div>
<div class="lang-id" markdown="1">
Artinya `m` tinggal diambil dari akar pangkat tiga integer dari `c`, tanpa perlu
tahu faktor `p` dan `q` sama sekali. Kunci privat ga relevan di sini.
</div>

<div class="callout tip"><span class="lbl">insight</span>
<span class="lang-en">This attack only works when <code>m^3 &lt; n</code>. With proper padding (OAEP)
or a large exponent like 65537, <code>m^e</code> always wraps past <code>n</code>
and a naive cube root fails. For many ciphertexts with a small <code>e</code> and
different moduli, move on to Hastad broadcast + CRT.</span>
<span class="lang-id">Serangan ini cuma jalan kalau <code>m^3 &lt; n</code>. Kalau pesan dipad dengan
benar (OAEP) atau <code>e</code> dibikin besar seperti 65537, <code>m^e</code>
selalu membungkus melewati <code>n</code> dan cube root polos gagal. Untuk kasus
banyak ciphertext dengan <code>e</code> kecil dan modulus beda, lanjut ke Hastad
broadcast + CRT.</span>
</div>

<div class="lang-en" markdown="1">
Verify the assumption after taking the root: check that the cube root is exact
(zero remainder) and that `m^3 < n`. Both must hold.
</div>
<div class="lang-id" markdown="1">
Verifikasi asumsi setelah dapat akar: cek apakah akar pangkat tiganya exact
(sisa nol) dan apakah `m^3 < n`. Dua-duanya harus benar.
</div>

## Solver

```python
#!/usr/bin/env python3
from gmpy2 import iroot
from Crypto.Util.number import long_to_bytes

n = 19079856583289673796614740682547240911232879513633706098802604985095556642330220283283556892618622484792206129011044708995617628773368301744462093428195884268359866907303313493659589337507409006909390771915375074230640919979454550183503948854556278583689931199652174750386122666416897255248410037067223913453
e = 3
c = 1678720587246671095744837808048280852040449638117561797172368829524200937354150960812322848174650642065474879850090979971953009065034874095987325080804392583680843658434149

m, exact = iroot(c, 3)      # integer cube root
assert exact                # zero remainder -> c really is m^3
assert m**3 < n             # no reduction mod n
print(long_to_bytes(m).decode())
```

```console
$ python3 solve.py
0xV0ID{cub3_r00t_4tt4ck}
```

## Flag

```text
0xV0ID{cub3_r00t_4tt4ck}
```

## Catatan

<div class="lang-en" markdown="1">
- Root property: `iroot(c, 3)` returns `(root, is_exact)`. `is_exact == True`
  confirms `c` is a perfect cube, not just a near miss.
- Mitigation: never use a small `e` without padding. Secure RSA needs a padding
  scheme like OAEP; textbook RSA with `e = 3` leaks for short messages.
- Good follow-ups to study: Hastad broadcast (one message, three moduli,
  `e = 3`) and Franklin-Reiter (two linearly related messages, small `e`).
</div>
<div class="lang-id" markdown="1">
- Akar sifat: `iroot(c, 3)` balikin `(root, is_exact)`. `is_exact == True`
  memastikan `c` benar-benar kubik sempurna, bukan kebetulan mendekati.
- Mitigasi: jangan pakai `e` kecil tanpa padding. RSA aman butuh skema padding
  seperti OAEP; textbook RSA dengan `e = 3` bocor untuk pesan pendek.
- Variasi lanjutan yang bagus dipelajari: Hastad broadcast (satu pesan, tiga
  modulus, `e = 3`) dan Franklin-Reiter (dua pesan berelasi linear, `e` kecil).
</div>
