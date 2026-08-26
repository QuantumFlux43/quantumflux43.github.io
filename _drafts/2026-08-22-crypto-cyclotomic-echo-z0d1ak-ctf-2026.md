---
title: "Crypto Cyclotomic Echo :: NTRU-style Trapdoor Signature Forgery"
date: 2026-08-22 22:25:39 +0700
lang: id
ref: crypto-cyclotomic-echo-z0d1ak-ctf-2026
categories: [Lattice]
tags: [lattice, ntru, cyclotomic, trapdoor, signature-forgery, gpv]
description: recovery.json bocorin trapdoor basis F, G, f, g dari skema signature berbasis ring cyclotomic Z[x]/(x^128+1). Dengan trapdoor, short vector buat forgery tinggal dihitung langsung.
---

<div class="callout info"><span class="lbl">info soal</span>
<b>CTF:</b> Z0D1AK CTF 2026 :: <b>Kategori:</b> Crypto (Lattice) :: <b>Nama Soal:</b> Cyclotomic Echo
</div>

Skema signature di soal ini mirip NTRUSign/Falcon: kerja di ring cyclotomic
`Z[x]/(x^128+1)`, verifikasi cuma ngecek norm kuadrat suatu vector pendek
terhadap quadratic form publik. Server minta kita forge signature buat pesan
tetap `"Authorize release of the Cyclotomic Echo archive."`. File `recovery.json`
yang ikut di-provide ternyata isinya trapdoor basis asli (`F, G, f, g`) —
begitu punya trapdoor, bikin short vector valid jadi trivial tanpa perlu
memecahkan SVP/CVP beneran.

## Soal

```text
crypto_cyclotomic-echo/dist/verifier.py     -> logic verifikasi resmi
crypto_cyclotomic-echo/dist/recovery.json   -> trapdoor basis (F, G, f, g), harusnya rahasia
crypto_cyclotomic-echo/dist/solve.py        -> solver lokal (generate forgery.json)
crypto_cyclotomic-echo/dist/remote_solve.py -> otomasi terhadap remote instance
```

Verifikasi payload `{salt_hex, s1}` terhadap instance publik:

```python
def V(j: dict, t: bytes, u: list[int]) -> bool:
    a, b, c = Q(j)
    x, y = H(j, t)
    u = K(u)
    v = R(x / 2 + (y / 2 - u) * b / a)
    e = (x - 2 * v, y - 2 * u)
    if not S(e[1]):
        return False
    q = ((a, b.conjugate()), (b, c))
    z = sum(e[i] * q[i][k] * e[k].conjugate() for i in range(2) for k in range(2))
    return bool(0 <= z <= VERIFY_BOUND)
```

Publik key adalah quadratic form `Q = (a, b, c)` yang dibangun dari:

```text
a = f*conj(f) + g*conj(g)
b = F*conj(f) + G*conj(g)
c = (1 + b*conj(b)) / a
```

`x, y` didapat dari hash `H(instance, salt)` (bit 0/1 per koefisien, binding ke
`instance_id` + pesan target). Payload valid kalau norm kuadrat `z = e^T Q e`
(dengan `e` diturunkan dari `u` yang kita submit) ada di rentang
`[0, VERIFY_BOUND]`, plus syarat tanda `S(e1) == True`.

## Analisis

Ini pola trapdoor lattice signature ala GGH/NTRUSign: public key = quadratic
form besar, tapi si penandatangan asli punya basis rahasia berukuran kecil
(`f, g, F, G`) yang memenuhi identitas NTRU:

$$
f G - g F = 1
$$

Basis kecil ini yang bikin signer bisa nemuin vector pendek `e` deket target
hash `(x, y)` — tanpa trapdoor, itu setara CVP di lattice berdimensi tinggi
(susah). File `recovery.json` yang bocor persis berisi 4 polinomial ini, jadi
kita langsung berperan sebagai signer asli.

## Dasar matematika

Kerja di ring `R = Z[x]/(x^128+1)` (cyclotomic conductor 256). Bentuk kuadrat
publik dibentuk dari trapdoor:

$$
a = f\bar f + g\bar g, \quad
b = F\bar f + G\bar g, \quad
c = \frac{1 + b\bar b}{a}
$$

Signature `(salt, u)` valid kalau, dengan `x, y = H(pesan, salt)`:

$$
v = \mathrm{round}\!\left(\frac{x}{2} + \left(\frac{y}{2} - u\right)\frac{b}{a}\right), \qquad
e = (x - 2v,\; y - 2u)
$$

dan `0 <= e^T Q e <= BOUND` dengan tanda `e_1` positif (leading nonzero
coefficient).

Trik forge (pakai trapdoor): pilih vector kecil `h0, h1` acak sesuai parity
constraint dari hash, lalu hitung:

$$
e_0 = G h_0 - F h_1, \qquad e_1 = f h_1 - g h_0
$$

Karena `fG - gF = 1`, pasangan `(e0, e1)` ini otomatis short vector yang valid
relatif ke basis trapdoor. Lalu balikkan `u` dari `e1`:

$$
u = \frac{y - e_1}{2}
$$

Ini integer hanya kalau parity `y - e1` genap per-koefisien — makanya `h0, h1`
harus dipilih supaya paritasnya (`f*x + F*y` dan `g*x + G*y` mod 2) cocok
duluan, baru dicek verifier beneran menerima lewat simulasi `verifier_rounds_to`.

## Solver

Ring arithmetic manual (tanpa Sage) untuk perkalian polinomial mod `x^128+1`
(negacyclic convolution):

```python
def mul(a, b):
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
    return [a[0]] + [-a[N - i] for i in range(1, N)]
```

Loop forge inti:

```python
def main():
    rec = json.load(open("recovery.json"))
    F, G, f, g = (rec[k] for k in ("F", "G", "f", "g"))

    q00 = add(mul(f, conj(f)), mul(g, conj(g)))
    q10 = add(mul(F, conj(f)), mul(G, conj(g)))
    instance = json.load(open(sys.argv[1]))  # instance dari remote

    inv_a = solve_linear_for_divisor(q00)     # invers q00 di Z[x]/(x^N+1), atas QQ
    while True:
        salt = os.urandom(SALT_BYTES)
        x, y = H(instance, salt)
        h0_parity = [z & 1 for z in add(mul(f, x), mul(F, y))]
        h1_parity = [z & 1 for z in add(mul(g, x), mul(G, y))]
        h0 = [random.choice((-1, 1)) if z else random.choice((-2, 0, 2)) for z in h0_parity]
        h1 = [random.choice((-1, 1)) if z else random.choice((-2, 0, 2)) for z in h1_parity]
        e0 = sub(mul(G, h0), mul(F, h1))
        e1 = sub(mul(f, h1), mul(g, h0))
        if not any(e1) or next(z for z in e1 if z) < 0:
            continue
        if sum(z*z for z in h0) + sum(z*z for z in h1) > VERIFY_BOUND:
            continue
        u = [(y[i] - e1[i]) // 2 for i in range(N)]
        if verifier_rounds_to(instance, q10, salt, u, e0, inv_a):
            break   # payload valid, siap dikirim

    payload = {"salt_hex": salt.hex(), "s1": u}
```

Alur remote (`remote_solve.py`): connect TLS, baca `instance.json` yang
dikirim server (isi `instance_id` beda tiap koneksi — hash binding), jalankan
`solve.py remote_instance.json` supaya forgery dihitung ulang untuk
`instance_id` yang aktif, lalu kirim `forgery.json` di koneksi yang sama.

```console
$ python3 remote_solve.py cyclotomic-echo-7e7bd0c48c14.chals.z0d1ak.org 1337
{"scheme":"ce-v2","n":128, ... ,"instance_id":"4a080e6a..."}
{"flag":"zdk{CYCL0ToMIc_eCh0_0n3_bASI5_bIndS_3v3RY_TEAM_aRCHiV3}","ok":true}
```

## Flag

```text
zdk{CYCL0ToMIc_eCh0_0n3_bASI5_bIndS_3v3RY_TEAM_aRCHiV3}
```

## Catatan

- Trapdoor lattice signature (NTRUSign, GGH, dan turunannya) fatal kalau basis
  rahasia bocor — sekali `F,G,f,g` diketahui, forge signature jadi operasi
  polinomial linear, bukan lagi hard lattice problem.
- Verifier resmi cuma ngecek "vector pendek + tanda benar" terhadap public
  quadratic form; ini secara desain memang bisa dipenuhi siapapun yang punya
  trapdoor — makanya kerahasiaan basis adalah satu-satunya jaring pengaman.
- `instance_id` mengikat hash tantangan ke parameter publik supaya forgery
  offline tidak bisa dipakai ulang; solve harus dijalankan ulang per sesi
  remote (makanya ada `remote_solve.py` yang generate ulang tiap connect).
- Studi lanjut: Falcon/NTRUSign fault & trapdoor-leak attacks, GPV framework
  buat lattice trapdoor sampling yang aman (Gaussian sampling, bukan
  rounding sederhana kayak di soal ini).
</content>
