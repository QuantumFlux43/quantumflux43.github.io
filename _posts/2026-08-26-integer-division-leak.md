---
title: "Integer Division Leak"
date: 2026-08-26 12:40:00 +0700
lang: id
ref: integer-division-leak
platform: knowledge
kn_cat: rsa
tags: [partial-leak, integer-division, noise, bit-length]
description: Persamaan hidden = n*z + rand adalah pembagian bersisa. Kalau noise (rand) lebih kecil dari pembagi, hasil bagi bulat langsung membocorkan z. Kalau sedikit lebih besar, meleset kecil dan bisa dibrute.
---

Pengetahuan kecil yang sering menyelesaikan soal "hint mengacak rahasia dengan
noise": persamaan `hidden = n*z + rand` sebenarnya cuma **pembagian bersisa**.
Kalau noise `rand` dibikin kekecilan, hasil bagi bulat `hidden // n` langsung
membocorkan `z`.

## Peta variabel

| variabel | peran | hubungan |
|---|---|---|
| `hidden` | nilai gabungan (diketahui) | `hidden = n·z + rand` |
| `n` | pembagi (diketahui) | biasanya modulus / faktor |
| `z` | rahasia yang **dicari** | `z = hasil bagi` `hidden/n` |
| `rand` | noise / sisa (tak diketahui) | `rand = sisa`; harus kecil |

Alur: `hidden` dan `n` adalah **input**, `z` adalah **output**, `rand` adalah
noise yang menentukan seberapa akurat `hidden // n` mendekati `z`. Yang penting
= perbandingan ukuran `rand` vs `n` (lihat bound di bawah).

## Ide dasar

Pembagian bersisa (yang dari SD):

$$
\underbrace{\text{hidden}}_{\text{diketahui}} = \underbrace{n}_{\text{pembagi}} \cdot \underbrace{z}_{\text{cari}} + \underbrace{\text{rand}}_{\text{sisa/noise}}, \qquad z = \text{hasil bagi}
$$

Aturan pembagian bersisa: **sisa harus lebih kecil dari pembagi**. Kalau
`rand < n`, maka `hidden // n = z` **exact**:

```python
z = hidden // n          # exact kalau rand < n
```

## Kalau noise sedikit lebih besar dari pembagi

Kalau `rand ≥ n`, sisa "tumpah" ke hasil bagi. Besarnya tumpahan dihitung dari
selisih bit-length:

$$
\left| \frac{\text{hidden}}{n} - z \right| \approx \frac{\text{rand}}{n} \approx 2^{\,\text{bit(rand)} - \text{bit}(n)}
$$

Contoh: `rand ≈ 2^1035`, `n ≈ 2^1024` → error `≈ 2^11 ≈ 2000`. Jadi `hidden // n`
meleset dari `z` paling banyak ~2000 → brute delta kecil di sekitar hasil bagi:

```python
approx = hidden // n
for delta in range(0, 4000):
    for z in (approx - delta, approx + delta):
        rand = hidden - n * z
        if 0 <= rand and rand.bit_length() <= bound:
            # verifikasi z (mis. z faktor -> n % something == 0)
            ...
```

## Kenapa jalan

Ini pola "**noise lebih kecil dari pembagi/modulus → operasi bulat
membocorkan struktur**". Sama keluarga dengan
[Partial Factor Recovery mod 2^k](/posts/2026/08/26/partial-factor-recovery-mod-2k/)
(pakai modular inverse) — bedanya di sini lewat pembagian bulat. Keduanya
bergantung pada [Bit-Length Reasoning](/posts/2026/08/26/bit-length-reasoning-ctf-crypto/).

## Bound praktis

$$
\boxed{\;\text{bit(rand)} - \text{bit}(n) \;\lesssim\; 20 \;\Longrightarrow\; z \text{ bisa dibrute}\;}
$$

| selisih bit | efek |
|---|---|
| `< 0` (`rand < n`) | `z = hidden // n` exact, tanpa brute |
| `0 .. ~20` | meleset kecil (`< 2^20`), brute praktis |
| `~20 .. ~40` | brute berat tapi mungkin |
| `> ~40` | meleset besar, tidak praktis — noise "benar" |

Cara desainer menutup celah: buat `bit(rand) ≈ bit(hidden)` (noise seukuran term
rahasia) supaya `hidden // n` tidak berkorelasi ke `z`.

## Contoh mini

```python
n = 1000003                 # "pembagi"
z = 42                      # rahasia
rand = 1234                 # noise < n  -> exact
hidden = n * z + rand
print(hidden // n)          # -> 42, exact

rand2 = 5 * n + 777         # noise > n  -> meleset ~5
hidden2 = n * z + rand2
approx = hidden2 // n
print(approx, approx - z)   # -> 47, meleset 5 -> brute delta kecil
```

## Contoh nyata di CTF

Soal Naughty Boy: `hidden_val = z1*z2*z3 + rand_1 = n*z3 + rand_1`, dengan
`rand_1 ≈ 2^1035` dan `n ≈ 2^1024`. `z3 ≈ hidden_val // n` meleset ~1500 → brute.
Lihat [Naughty Boy writeup](/posts/2026/08/26/naughty-boy-fermat-collapse/).

## Referensi

- Dasar pembagian bersisa Euclid `a = q·b + r`, `0 ≤ r < b`.
- Pola sibling lewat modular inverse: [Partial Factor Recovery mod 2^k](/posts/2026/08/26/partial-factor-recovery-mod-2k/).
