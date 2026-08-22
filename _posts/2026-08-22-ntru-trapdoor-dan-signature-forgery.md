---
title: "NTRU Trapdoor dan Signature Forgery"
date: 2026-08-22 22:25:39 +0700
lang: id
ref: ntru-trapdoor-dan-signature-forgery
platform: knowledge
kn_cat: lattice
tags: [lattice-attack, signature-forgery]
description: Kenapa skema signature lattice ala NTRUSign/GGH/Falcon runtuh total kalau basis trapdoor rahasia (F, G, f, g) bocor, dan bagaimana forgery-nya dihitung.
---

Skema signature berbasis lattice trapdoor (NTRUSign, GGH, dan turunan modern
seperti Falcon) punya struktur yang sama: public key adalah lattice/bentuk
kuadrat berdimensi tinggi yang keliatan "keras" buat SVP/CVP, tapi si
penandatangan asli punya **basis rahasia pendek** yang bikin dia bisa
nyari vector pendek dekat target dengan cepat. Kalau basis rahasia ini bocor,
keamanan skema langsung nol — forge signature jadi operasi aljabar linear
biasa.

## Konsep

Kerja di ring cyclotomic `R = Z[x]/(x^N+1)`. Trapdoor terdiri dari 4
polinomial pendek `f, g, F, G` yang memenuhi identitas NTRU:

$$
fG - gF = 1
$$

Public key dibangun sebagai bentuk kuadrat (Gram matrix) dari trapdoor:

$$
a = f\bar f + g\bar g, \qquad b = F\bar f + G\bar g, \qquad c = \frac{1+b\bar b}{a}
$$

(`\bar x` = conjugate di ring cyclotomic.) Verifier cuma bisa mengecek: "apakah
`e^T Q e` (dengan `Q = [[a, \bar b],[b, c]]`) ada di rentang kecil tertentu?"
— dia TIDAK bisa membedakan signature dari signer asli vs. forgery yang
konstruksinya beda, selama norma akhirnya kecil dan valid.

### Kenapa trapdoor bikin forge trivial

Signer asli (atau siapapun yang punya `f, g, F, G`) bisa memilih vector kecil
`h0, h1` bebas (asal parity cocok sama target hash), lalu hitung:

$$
e_0 = G h_0 - F h_1, \qquad e_1 = f h_1 - g h_0
$$

Karena identitas `fG - gF = 1`, pasangan `(e0, e1)` ini **otomatis** short
vector yang valid relatif ke basis trapdoor — tidak perlu menyelesaikan CVP
sungguhan. Publik key `(a, b, c)` cuma proyeksi/bentuk kuadrat dari trapdoor,
jadi vector yang "pendek menurut trapdoor" juga pendek menurut publik key.

Tanpa trapdoor, penyerang harus menyelesaikan Closest Vector Problem beneran
di lattice dimensi `N` — itu yang (dianggap) hard problem. Begitu trapdoor
bocor, soal itu berubah jadi substitusi aljabar linear.

## Kapan berlaku

- **Prasyarat serangan:** basis trapdoor (`f,g,F,G` atau representasi
  ekuivalennya seperti private key file, debug dump, memory leak) harus
  bocor/didapat penyerang. Kalau trapdoor tetap rahasia, forgery balik jadi
  hard lattice problem seperti seharusnya.
- **Constraint teknis forge:** hasil `(e0, e1)` harus lolos bound norma
  verifier (`sum(h_i^2) <= BOUND`) dan syarat tanda (leading nonzero
  coefficient `e1` harus positif, atau aturan serupa) — kalau tidak lolos,
  ulangi pilih `h0, h1` baru (rejection sampling).
- **Binding ke instance:** skema modern mengikat hash target ke
  `instance_id`/session supaya forgery offline tidak reusable — servernya
  reject forgery lama begitu instance berganti. Serangan tetap jalan asal
  proses forge diulang tiap instance baru (murah, cuma butuh trapdoor +
  hash ulang).
- **Kapan gagal:** kalau implementasi pakai **Gaussian sampling** yang benar
  (GPV framework) alih-alih rounding sederhana, distribusi signature tidak
  bocor informasi soal trapdoor lewat statistik signature — beda topik dari
  "trapdoor bocor langsung", tapi relevan buat skema yang implementasinya
  benar (Falcon produksi pakai ini).

## Contoh

Operasi ring dasar (perkalian polinomial mod `x^N+1`, negacyclic convolution)
dan loop forge inti (detail penuh + solver lengkap ada di writeup
[Crypto Cyclotomic Echo](/posts/2026/08/22/crypto-cyclotomic-echo-z0d1ak-ctf-2026/)):

```python
def mul(a, b):
    N = len(a)
    r = [0] * N
    for i, ai in enumerate(a):
        if not ai: continue
        for j, bj in enumerate(b):
            if not bj: continue
            k = i + j
            if k >= N:
                r[k - N] -= ai * bj   # wrap: x^N = -1
            else:
                r[k] += ai * bj
    return r

def conj(a):
    N = len(a)
    return [a[0]] + [-a[N - i] for i in range(1, N)]

# forge inti: pilih h0, h1 kecil sesuai parity target hash, lalu
# e0 = G*h0 - F*h1 ; e1 = f*h1 - g*h0  --> otomatis short vector valid
```

## Referensi

- Hoffstein, Pipher, Silverman, "NTRUSign: Digital Signatures Using the
  NTRU Lattice" (2003) — skema asal, juga contoh historis kebocoran statistik
  signature (transcript leak lewat banyak signature, beda dari basis bocor
  langsung).
- Gentry, Peikert, Vaikuntanathan, "Trapdoors for Hard Lattices and New
  Cryptographic Constructions" (GPV, 2008) — Gaussian sampling sebagai
  mitigasi transcript-leak.
- Falcon (NIST PQC finalist) — implementasi modern skema ini dengan
  Gaussian sampling yang benar.
- Writeup terkait: [Crypto Cyclotomic Echo :: NTRU-style Trapdoor Signature Forgery](/posts/2026/08/22/crypto-cyclotomic-echo-z0d1ak-ctf-2026/).
</content>
