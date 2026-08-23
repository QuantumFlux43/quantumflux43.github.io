---
title: "Checklist Serangan ECDSA di CTF"
date: 2026-08-23 10:00:00 +0700
lang: id
ref: checklist-serangan-ecdsa-di-ctf
platform: knowledge
kn_cat: ecc
tags: [ecdsa, checklist]
description: Urutan prioritas pengecekan saat ketemu soal ECDSA di CTF - dari nonce reuse yang paling gampang sampai serangan curve, plus tanda-tanda pemicu tiap serangan.
---

Waktu ketemu soal ECDSA di CTF, jangan langsung nyerang random. Ada urutan
"cek dulu yang paling murah" — dari serangan yang paling gampang (aljabar
langsung) sampai yang paling mahal (lattice / curve exotic). Catatan ini
adalah checklist prioritas + tanda pemicu tiap serangan.

Prasyarat: paham dulu mekanisme dasarnya di [Dasar ECDSA](/posts/2026/08/23/dasar-ecdsa/),
terutama kenapa nonce `k` jadi titik terlemah.

## Konsep

### Tabel prioritas cek

Urut dari yang pertama harus dicek (paling sering + paling murah):

| # | Cek di soal | Serangan | Biaya |
|---|---|---|---|
| 1 | Ada 2+ signature dengan `r` yang **sama**? | Nonce reuse | trivial |
| 2 | Satu `k` bocor / bisa dihitung? | Direct recovery | trivial |
| 3 | Verifier tidak cek range `r,s` / titik? | Malleability / forge | murah |
| 4 | Oracle sign banyak + sebagian bit `k` diketahui? | HNP + LLL | sedang |
| 5 | `k` dari PRNG (LCG/MT/`rand()`)? | PRNG predict | sedang |
| 6 | `k` antar-sig berelasi linear? | Related nonce | sedang |
| 7 | Server terima titik arbitrary (ECDH-ish)? | Invalid curve / small subgroup | sedang |
| 8 | Curve non-standar / custom? | Smart / MOV (ECDLP) | tergantung |

### 1. Nonce reuse (`k` sama)

Serangan paling klasik. Kalau `k` sama dipakai buat dua pesan beda, `r` juga
sama (`r = (k*G).x`), dan private key langsung terhitung TANPA lattice:

$$
k = \frac{z_1 - z_2}{s_1 - s_2} \bmod n, \qquad
D = \frac{s_1 k - z_1}{r} \bmod n
$$

- **Pemicu:** dua atau lebih signature punya `r` identik.
- **Real-world:** PS3 (Sony) pakai `k` konstan, dompet Bitcoin Android 2013.

### 2. Direct recovery (`k` satu bocor)

Kalau `k` satu signature diketahui (bocor lewat side-channel, dump, atau logika
soal), private key dari satu persamaan aja:

$$
D = \frac{s k - z}{r} \bmod n
$$

- **Pemicu:** soal ngasih `k` langsung, atau `k` gampang ditebak (mis. `k=1`,
  `k` = timestamp yang diketahui, `k` = counter).

### 3. Malleability & bug verifikasi

- **Malleability:** `(r, s)` valid → `(r, n - s)` juga valid. Bypass cek
  "signature harus beda dari yang ada".
- **Missing checks:** verifier tidak menolak `r == 0`, `s == 0`, atau `r,s` di
  luar `[1, n-1]`, atau tidak cek titik ada di curve → sering bisa forge tanpa
  private key.
- **Pemicu:** baca kode verifier, cari validasi yang hilang.

### 4. Partial nonce leak (HNP + LLL)

Sebagian bit `k` bocor/predictable di banyak signature → Hidden Number Problem
→ reduksi lattice. Ini yang paling sering muncul di soal ECDSA "serius".

- **Varian:** MSB bocor, LSB bocor, `k` pendek (short nonce), `k` dari RNG
  bias, `k` = prefix publik || random.
- **Pemicu:** ada oracle sign yang bisa dipanggil banyak kali DAN ada cara
  menghitung sebagian bit `k` tiap signature.
- **Detail:** [Dasar Hidden Number Problem](/posts/2026/08/23/dasar-hidden-number-problem/),
  contoh: [Crypto Siren](/posts/2026/08/22/crypto-siren-z0d1ak-ctf-2026/).

### 5. Nonce dari PRNG lemah

`k` di-generate dari LCG, Mersenne Twister, atau `rand()` yang statenya bisa
diprediksi.

- **Pemicu:** kode nge-seed RNG non-kripto buat bikin `k`, atau ada output RNG
  lain yang bisa dipakai recover state.
- **Alur:** recover state PRNG → prediksi `k` → direct recovery (kasus #2).
- Sering gabungan kategori PRNG + ECC.

### 6. Related nonce

`k` antar signature berelasi (mis. `k_2 = k_1 + c`, atau `k_i = a k_{i-1} + b`).

- **Pemicu:** ada struktur/relasi eksplisit antar nonce di kode.
- **Alur:** susun persamaan `s = k^{-1}(z + rD)` untuk tiap sig, substitusi
  relasi `k`, eliminasi → solve `D` (aljabar atau lattice tergantung kompleksitas).

### 7. Invalid curve / small subgroup

Lebih relevan ke ECDH, tapi kadang muncul di skema yang pakai titik dari user.

- **Pemicu:** server menerima titik dari user tanpa cek titik itu benar-benar
  ada di curve resmi / di subgroup order besar.
- **Alur:** kirim titik di subgroup kecil → bocor `D mod (order kecil)` →
  ulangi beberapa subgroup → CRT gabungin → recover `D`.

### 8. Curve parameter lemah (ECDLP langsung)

Ini serangan ke discrete log-nya, bukan ke ECDSA per se:

- **Smart attack:** kalau `#E = p` (anomalous curve), ECDLP jadi
  polynomial-time via additive transfer.
- **MOV/FR:** embedding degree kecil → transfer DLP ke finite field.
- **Pemicu:** curve custom / non-standar. Cek order curve vs `p`, hitung
  embedding degree.

## Kapan berlaku

- Selalu cek **dari atas ke bawah**: nonce reuse dan bug verifikasi jauh lebih
  murah dari lattice. Jangan langsung setup LLL sebelum yakin bukan reuse.
- Kumpulkan **banyak signature** dulu kalau ada oracle — mayoritas serangan
  nonce butuh multiple samples (khususnya HNP #4 dan related nonce #6).
- Baca kode `sign()` DAN `verify()` sama teliti — celah bisa di dua-duanya.

## Contoh

Cek cepat nonce reuse dari kumpulan signature:

```python
# sigs = list of (r, s, z)
seen = {}
for (r, s, z) in sigs:
    if r in seen:
        r2, s2, z2 = seen[r]        # ketemu k sama (r sama)
        k = (z - z2) * pow(s - s2, -1, n) % n
        D = (s * k - z) * pow(r, -1, n) % n
        print("private key:", D); break
    seen[r] = (r, s, z)
```

## Referensi

- [Dasar ECDSA](/posts/2026/08/23/dasar-ecdsa/) — mekanisme sign/verify + peran nonce.
- [Dasar Hidden Number Problem](/posts/2026/08/23/dasar-hidden-number-problem/) — teori serangan #4.
- [Crypto Siren](/posts/2026/08/22/crypto-siren-z0d1ak-ctf-2026/) — contoh nyata partial nonce leak.
- SafeCurves (safecurves.cr.yp.to) — referensi curve mana yang aman/rawan.
</content>
