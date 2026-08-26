---
title: "Bit-Length Reasoning di CTF Crypto"
date: 2026-08-26 13:20:00 +0700
lang: id
ref: bit-length-reasoning-ctf-crypto
platform: knowledge
kn_cat: rsa
tags: [bit-length, partial-leak, methodology, integer-division, term-dominan]
description: Alat X-ray untuk soal crypto custom. Baca ukuran angka lewat bit-length (bukan nilai aslinya) untuk melihat mana yang bocor lewat operasi bulat. Aturan cepat + checklist.
---

Ini bukan satu serangan, tapi **cara berpikir** yang mendasari banyak serangan
"partial leak" di CTF crypto. Angka di soal sering 300+ digit dan tidak berguna
dibaca. Tapi **bit-length**-nya (`x.bit_length()`) kecil dan langsung menunjukkan
struktur mana yang bocor. Anggap bit-length sebagai X-ray.

## Aturan emas: konversi rasio ke selisih pangkat

$$
\frac{2^{a}}{2^{b}} = 2^{a-b}
$$

Rasio dua angka besar = **selisih bit-length** mereka. Tidak perlu hitung angka
asli. `2^1035 / 2^1024 = 2^11 ≈ 2000`. Selesai.

## Aritmetika bit-length

| operasi | efek pada bit |
|---|---|
| `a * b` | `bit(a) + bit(b)` (jumlah) |
| `a ^ k` | `bit(a) * k` (kali) |
| `a + b` | `max(bit a, bit b)` (yang kecil hampir tak berpengaruh) |
| `a mod m` | `≤ bit(m)` (dipotong ke ukuran modulus) |
| `a // b` | `bit(a) - bit(b)` (kira-kira) |

Contoh baca rumus `hint = z3^8 * z2 + c*z2*z1^2 + rand2` (z3=256, z2=z1=512 bit):

- `z3^8 * z2` = 256·8 + 512 = **2560**
- `c*z2*z1^2` = 512 + 512·2 = **1536** (konstanta kecil `c` diabaikan)
- `rand2` = **1024**
- total = max = **2560**, term pertama dominan telak.

## Tiga pola bocor yang paling sering

### Pola A — noise < modulus/pembagi → integer division bocor
`hidden = n*z + rand` dengan `bit(rand)` sedikit di atas `bit(n)`: `hidden // n`
meleset kecil → brute. Lihat
[Integer Division Leak](/posts/2026/08/26/integer-division-leak/).

### Pola B — satu term jauh lebih besar → term kecil kebuang
Selisih bit `≥ ~30` antara term dominan dan sisa → `hint // term_dominan` = koefisien,
sisa lenyap di pembagian bulat.

### Pola C — rahasia < modulus → mod tidak menyembunyikan
`bit(x) < bit(mod)` → `x mod m = x`, recover penuh. Muncul di akar modular
([Fermat Collapse](/posts/2026/08/26/fermat-exponent-collapse/)) dan
[Partial Factor mod 2^k](/posts/2026/08/26/partial-factor-recovery-mod-2k/).

## Aturan praktis "buang yang kecil"

$$
\boxed{\;\text{selisih bit} \ge \sim 30 \;\Longrightarrow\; \text{term kecil} \approx 0 \text{ di } // \;}
$$

Kalau dua kuantitas selisih bit-length `≥ 30`, yang kecil bisa dianggap nol saat
pembagian bulat atau saat mencari term dominan.

## Checklist saat ketemu soal "hint mengacak rahasia"

1. **Print bit-length semua variabel dan tiap term rumus dulu** — sebelum mikir
   apa pun. Ini first move wajib.

   ```python
   for name, v in vals.items():
       print(name, v.bit_length())
   ```

2. **Pangkat besar mod prima?** → Fermat, `exp mod (p-1)`
   ([collapse](/posts/2026/08/26/fermat-exponent-collapse/)).
3. **Noise lebih kecil dari modulus/pembagi?** → integer division / brute kecil (Pola A/C).
4. **Satu term jauh lebih besar?** → term kecil kebuang di `//` (Pola B).
5. **Rahasia lebih kecil dari mod?** → recover penuh (Pola C).
6. **DLP?** → faktorkan `p-1`, cek smooth
   ([Pohlig-Hellman](/posts/2026/08/26/pohlig-hellman-dlp-smooth/)).

## Kenapa efektif

Desainer soal menambahkan "noise" (rand) untuk menyamarkan rahasia. Tapi kalau
ukuran noise salah pilih (kekecilan relatif ke term rahasia), strukturnya bocor
lewat operasi bulat yang deterministik. Bit-length adalah cara paling cepat
melihat apakah noise cukup besar atau tidak — angka aslinya 300 digit tidak
memberi info itu, bit-length 4 digit memberi jawabannya.

## Contoh nyata di CTF

Kedua soal ini diselesaikan murni dengan bit-length reasoning:
[Naughty Boy](/posts/2026/08/26/naughty-boy-fermat-collapse/) (Pola A+B+C),
[YOKOSO](/posts/2026/08/26/yokoso-pohlig-hellman-partial-factor/) (Pola C untuk
`p < 2^k` dan `m < p`).

## Referensi

- Pola pesan `< n` klasik: [Cube Root Attack](/posts/2026/08/16/easy-babyrsa-cube-root/).
- Coppersmith `small_roots` — versi "berat" saat leak hanya sebagian bit rahasia.
