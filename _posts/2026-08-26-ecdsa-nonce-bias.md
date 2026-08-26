---
title: "ECDSA Nonce Bias"
date: 2026-08-26 10:53:00 +0700
lang: id
ref: ecdsa-nonce-bias
platform: knowledge
kn_cat: ecc
tags: [ecdsa, nonce, hnp, lattice]
description: Kalau sebagian bit nonce bocor atau bias, private key ECDSA bisa dipulihkan lewat Hidden Number Problem dan lattice reduction.
---

Nonce ECDSA (`k`) wajib rahasia penuh dan acak seragam. Kalau sebagian bit `k`
bocor atau bias (misal MSB selalu nol, atau generator lemah), setiap signature
membocorkan sedikit info soal `k`. Kumpulkan cukup banyak, dan private key `D`
jatuh lewat **Hidden Number Problem (HNP)** yang diselesaikan pakai lattice.

## Titik awal

Persamaan tanda tangan ECDSA untuk satu pesan:

$$
s \equiv k^{-1}(z + rD) \pmod n
$$

dengan `z` = hash pesan (dipotong), `r` = koordinat-x dari `kG`, `D` = private
key, `n` = order grup. Susun ke `k`:

$$
k \equiv s^{-1}z + s^{-1}rD \pmod n
$$

## Bentuk HNP

Misal nonce bisa ditulis `k = prefix + e`, dengan `prefix` bagian yang diketahui
(published / predictable) dan `e` bagian kecil yang tidak diketahui
($|e| < 2^\ell$, dengan $\ell$ = jumlah bit bocor, $\ell \ll \log_2 n$).

Substitusi `k = prefix + e` ke persamaan di atas:

$$
\text{prefix} + e \equiv s^{-1}z + s^{-1}rD \pmod n
$$

Isolasi `e` (unknown kecil) di satu sisi:

$$
e \equiv s^{-1}rD + s^{-1}z - \text{prefix} \pmod n
$$

Susun ke bentuk HNP standar $t\,D - u \equiv e \pmod n$:

$$
\underbrace{(s^{-1}r)}_{t}\,D \;-\; \underbrace{\left(\text{prefix} - s^{-1}z\right)}_{u} \;\equiv\; e \pmod n
$$

Jadi untuk tiap signature ke-`i`:

$$
t_i D - u_i \equiv e_i \pmod n, \qquad
t_i = r_i\,s_i^{-1}, \qquad
u_i = \text{prefix}_i - z_i\,s_i^{-1}
$$

<div class="callout danger"><span class="lbl">koreksi tanda</span>
Perhatikan tanda <code>u_i</code>. Yang benar adalah
<code>u_i = prefix_i - z_i·s_i^{-1}</code>, <b>bukan</b>
<code>z_i·s_i^{-1} - prefix_i</code>. Cek balik: dari
<code>k = prefix + e</code> berarti <code>e = k - prefix</code>, dan
<code>k = s^{-1}z + s^{-1}rD</code>, sehingga
<code>e = tD + s^{-1}z - prefix = tD - (prefix - s^{-1}z)</code>.
Cocok hanya kalau <code>u = prefix - s^{-1}z</code>.
</div>

## Verifikasi turunan

Cek `t·D - u = e` dengan `u = prefix - s⁻¹z`:

$$
tD - u = s^{-1}rD - \bigl(\text{prefix} - s^{-1}z\bigr)
       = s^{-1}rD + s^{-1}z - \text{prefix}
$$

Karena `k = s⁻¹z + s⁻¹rD` maka `s⁻¹rD + s⁻¹z = k`, sehingga

$$
tD - u = k - \text{prefix} = e \quad\checkmark
$$

Konsisten. Kalau dipakai tanda terbalik (`u = s⁻¹z - prefix`), hasilnya
`tD - u = k - prefix + 2·prefix - 2s⁻¹z`, jelas bukan `e`.

## Dari HNP ke lattice

Setelah punya banyak pasangan $(t_i, u_i)$ dengan $|e_i|$ kecil, cari `D` yang
bikin semua $t_iD - u_i \bmod n$ kecil. Bangun basis lattice (konstruksi
klasik):

$$
B =
\begin{pmatrix}
n & 0 & \cdots & 0 & 0 \\
0 & n & \cdots & 0 & 0 \\
\vdots & & \ddots & & \vdots \\
t_1 & t_2 & \cdots & K/n & 0 \\
u_1 & u_2 & \cdots & 0 & K
\end{pmatrix}
$$

dengan `K` faktor skala (sekitar `2^ℓ`) buat nyeimbangin bobot. Reduksi pakai
**LLL** (atau BKZ kalau butuh lebih kuat); vektor pendek yang muncul mengandung
`D` (atau `e_i`), tinggal dibaca balik.

<div class="callout tip"><span class="lbl">catatan praktik</span>
Butuh sekitar <code>n / ℓ</code> signature supaya HNP punya solusi unik.
Makin sedikit bit bocor per signature (<code>ℓ</code> kecil), makin banyak
signature yang dibutuhin. 1 bit bias pun cukup kalau sample-nya banyak
(Bleichenbacher / FFT approach lebih cocok untuk bias sangat kecil).
</div>

## Kapan berlaku

- MSB nonce bocor / selalu nol (implementasi buruk, truncation).
- Nonce dari PRNG lemah (LCG, waktu, counter yang bisa ditebak sebagian).
- Nonce pendek (misal `k` cuma 128-bit di kurva 256-bit).

## Mitigasi

- Nonce deterministik **RFC 6979**: `k = HMAC(d, z)`, seragam penuh, tidak ada bias.
- Jangan pernah truncate atau reuse `k`.
- Skema modern (Ed25519) pakai nonce deterministik bawaan, kebal serangan ini.

## Referensi

- Howgrave-Graham & Smart, *Lattice Attacks on Digital Signature Schemes* (2001).
- Nguyen & Shparlinski, *The Insecurity of the DSA with Partially Known Nonces*.
