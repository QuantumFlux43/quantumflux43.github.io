---
title: "easy_babyrsa :: Cube Root Attack"
date: 2026-08-16 20:00:00 +0700
lang: id
ref: easy-babyrsa-cube-root
categories: [RSA]
tags: [low-exponent, cube-root, e-3]
description: Public exponent e=3 dan pesan kecil bikin ciphertext cuma m pangkat 3 tanpa reduksi mod n. Cube root biasa langsung balikin flag.
---

<div class="callout info"><span class="lbl">info soal</span>
<b>CTF:</b> 0xV01D :: <b>Kategori:</b> Crypto :: <b>Soal:</b> 02_easy_babyrsa
</div>

Pada soal diberikan nilai `n`, `e = 3`, dan `c`. Ketika melihat `c = m^3`, ukuran nilai `c` ukurannya tidak sama dan lebih kecil jika dibandingkan dengan ukuran `n`. Dengan melihat kondisi itu, bisa diasumsikan bahwa ukuran pesan `m` memiliki ukuran yang lebih kecil dari `c` sehingga proses enkripsi nya tidak pernah kena
reduksi modulo. Oleh karena itu, flag tinggal diambil dari akar pangkat tiga.

## Soal

```text
n = 19079856583289673796614740682547240911232879513633706098802604985095556642330...913453
e = 3
c = 1678720587246671095744837808048280852040449638117561797172368829524200937354150...434149
```

`n` sekitar 1024 bit. `c` sekitar 190 digit desimal, jauh lebih kecil dari `n`. Itu petunjuk kuat kalau `m^3` tidak melebihi `n`.

## Analisis

Enkripsi RSA: `c = m^e mod n`. Dengan `e = 3`:

$$
c = m^3 \bmod n .
$$

Operasi `mod n` cuma berpengaruh kalau `m^3 >= n`. Kalau pesan `m` cukup kecil
sampai `m^3 < n`, maka tidak ada reduksi sama sekali dan

$$
c = m^3 \quad\text{(di bilangan bulat penuh)}.
$$

Artinya `m` tinggal diambil dari akar pangkat tiga integer dari `c`, tanpa perlu
tahu faktor `p` dan `q` sama sekali. Kunci privat ga relevan di sini.

<div class="callout tip"><span class="lbl">insight</span>
Serangan ini cuma jalan kalau <code>m^3 &lt; n</code>. Kalau pesan dipad dengan
benar (OAEP) atau `e` dibikin besar seperti 65537, `m^e` selalu membungkus
melewati `n` dan cube root polos gagal. Untuk kasus banyak ciphertext dengan
`e` kecil dan modulus beda, lanjut ke Hastad broadcast + CRT.
</div>

Verifikasi asumsi setelah dapat akar: cek apakah akar pangkat tiganya exact
(sisa nol) dan apakah `m^3 < n`. Dua-duanya harus benar.

## Solver

```python
#!/usr/bin/env python3
from gmpy2 import iroot
from Crypto.Util.number import long_to_bytes

n = 19079856583289673796614740682547240911232879513633706098802604985095556642330220283283556892618622484792206129011044708995617628773368301744462093428195884268359866907303313493659589337507409006909390771915375074230640919979454550183503948854556278583689931199652174750386122666416897255248410037067223913453
e = 3
c = 1678720587246671095744837808048280852040449638117561797172368829524200937354150960812322848174650642065474879850090979971953009065034874095987325080804392583680843658434149

m, exact = iroot(c, 3)      # akar pangkat tiga integer
assert exact                # sisa nol -> c memang m^3
assert m**3 < n             # tidak ada reduksi mod n
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

- Akar sifat: `iroot(c, 3)` balikin `(root, is_exact)`. `is_exact == True`
  memastikan `c` benar-benar kubik sempurna, bukan kebetulan mendekati.
- Mitigasi: jangan pakai `e` kecil tanpa padding. RSA aman butuh skema padding
  seperti OAEP; textbook RSA dengan `e = 3` bocor untuk pesan pendek.
- Variasi lanjutan yang bagus dipelajari: Hastad broadcast (satu pesan, tiga
  modulus, `e = 3`) dan Franklin-Reiter (dua pesan berelasi linear, `e` kecil).
