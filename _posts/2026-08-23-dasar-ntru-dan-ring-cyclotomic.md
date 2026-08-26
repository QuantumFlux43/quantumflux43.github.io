---
title: "Dasar NTRU dan Ring Cyclotomic"
date: 2026-08-23 09:30:00 +0700
lang: id
ref: dasar-ntru-dan-ring-cyclotomic
platform: knowledge
kn_cat: lattice
tags: [lattice-attack, ntru]
description: Ring cyclotomic Z[x]/(x^N+1), aritmetika polinomial negacyclic, struktur NTRU, dan kenapa basis trapdoor pendek jadi kunci skema signature/enkripsi lattice.
---

NTRU adalah keluarga skema kripto berbasis lattice yang bekerja di ring
polinomial, bukan langsung di vektor integer. Struktur ring ini bikin operasi
efisien dan basis trapdoor kompak - dasar dari NTRUEncrypt, NTRUSign, dan
Falcon (finalis post-quantum NIST). Materi ini bahas ring cyclotomic +
struktur trapdoor NTRU.

## Konsep

### Ring cyclotomic Z[x]/(x^N+1)

Elemen ring adalah polinomial derajat `< N` dengan koefisien integer. `N`
biasanya pangkat 2 (mis. 128, 256, 512). Penjumlahan = biasa (koefisien per
koefisien). Perkalian = perkalian polinomial, tapi karena `x^N ≡ -1`, suku
yang derajatnya `>= N` "membungkus" dengan **tanda negatif**:

$$
x^N \equiv -1 \pmod{x^N + 1}
$$

Ini disebut **negacyclic convolution**. Contoh: `x^{N-1} * x = x^N = -1`.

```python
def mul(a, b):        # a, b: list koefisien panjang N
    N = len(a)
    r = [0] * N
    for i, ai in enumerate(a):
        for j, bj in enumerate(b):
            k = i + j
            if k >= N:
                r[k - N] -= ai * bj   # wrap dengan tanda minus: x^N = -1
            else:
                r[k] += ai * bj
    return r
```

**Conjugate** (analog konjugat kompleks di ring ini): `conj(a)` membalik dan
menegasi koefisien. Dipakai buat bikin bentuk kuadrat (Gram) yang self-adjoint.

```python
def conj(a):
    N = len(a)
    return [a[0]] + [-a[N - i] for i in range(1, N)]
```

### Struktur NTRU

Trapdoor NTRU terdiri dari polinomial pendek `f, g` (dan pasangan `F, G`) yang
memenuhi identitas NTRU:

$$
fG - gF = q \quad(\text{sering } q=1 \text{ atau modulus kecil})
$$

Public key biasanya `h = g/f mod q` (untuk enkripsi) atau bentuk kuadrat dari
`f,g,F,G` (untuk signature). Kuncinya: `f, g, F, G` punya koefisien **kecil**
(basis bagus / short), sementara public key keliatan seperti basis jelek.

### Kenapa "pendek" itu penting

Lattice NTRU direntang oleh basis yang berkaitan dengan `h`. Basis publik itu
jelek (vektor panjang), tapi trapdoor `(f, g)` adalah pasangan vektor pendek di
lattice yang sama. Punya basis pendek = bisa:

- **Dekripsi / signing:** nyari vektor lattice terdekat ke target (CVP) dengan
  mudah.
- Tanpa trapdoor, penyerang harus solve SVP/CVP di lattice NTRU - dianggap
  keras (dasar keamanan post-quantum).

Kalau trapdoor bocor → forge/dekripsi jadi trivial. Lihat penerapan serangannya
di [NTRU Trapdoor dan Signature Forgery](/posts/2026/08/22/ntru-trapdoor-dan-signature-forgery/).

## NTRUEncrypt: alur lengkap

Bagian di atas pakai bentuk trapdoor gaya Falcon (`fG - gF = q`). Versi paling
gampang dipahami adalah **NTRUEncrypt klasik (1998)**. Di sini ring-nya
convolution **cyclic** `Z[x]/(x^N - 1)` (`x^N ≡ +1`, bukan negacyclic), dan ada
**dua modulus**:

- `q` = modulus besar (pangkat 2, mis. 2048) - ruang ciphertext.
- `p` = modulus kecil (mis. 3) - ruang pesan.

Syarat: `gcd(p, q) = 1`. Parameter umum (set NTRU-HPS): `(N, p, q) = (11, 3, 32)`
buat mainan, atau `(509, 3, 2048)` buat produksi.

### Notasi polinomial pendek

`f`, `g`, `r`, `m` semuanya polinomial derajat `< N` dengan koefisien kecil
(biasanya dari `{-1, 0, 1}`, "ternary"). Kecilnya koefisien inilah yang bikin
dekripsi bisa "membatalkan" modulo `q` dan balik ke pesan asli.

### Key generation

1. Pilih `f` kecil yang **invertible mod q dan mod p**. Hitung:

$$
f_q = f^{-1} \bmod q, \qquad f_p = f^{-1} \bmod p
$$

2. Pilih `g` kecil (ternary).
3. Public key:

$$
h = p \cdot f_q \cdot g \bmod q
$$

Private key = `(f, f_p)`. Yang dipublish cuma `h`.

### Enkripsi

Pesan `m` (koefisien di `{-1,0,1}`), nonce acak kecil `r`:

$$
c = r \cdot h + m \bmod q
$$

### Dekripsi

1. Kalikan ciphertext dengan `f`:

$$
a = f \cdot c \bmod q
$$

Pilih perwakilan koefisien `a` di rentang **terpusat** `(-q/2, q/2]` (center-lift).
Kenapa jalan: `f·c = f·(r·h + m) = f·(r·p·f_q·g + m) = p·r·g + f·m` (karena
`f·f_q = 1`). Semua suku kecil, jadi selama parameter benar, `a = p·r·g + f·m`
**tanpa** kena reduksi `q`.

2. Kurangi modulo `p` (suku `p·r·g` hilang):

$$
b = a \bmod p = f \cdot m \bmod p
$$

3. Kalikan `f_p`:

$$
m = f_p \cdot b \bmod p
$$

## Contoh numerik mini

Implementasi lengkap NTRUEncrypt cyclic `(N,p,q)=(11,3,32)`. Bagian tersulit
adalah **invers polinomial**: `mod p` (prima) pakai extended Euclid di ring,
`mod q = 2^5` pakai invers mod 2 lalu **Hensel lifting**. Kode ini sudah diuji
jalan (assert lolos):

```python
# NTRUEncrypt mainan, ring Z[x]/(x^N - 1) (cyclic). (N,p,q) = (11,3,32).
N, p, q = 11, 3, 32

def cmul(a, b, mod):                     # convolution cyclic mod
    r = [0]*N
    for i in range(N):
        for j in range(N):
            r[(i+j) % N] = (r[(i+j) % N] + a[i]*b[j]) % mod
    return r

def center(a, mod):                      # koefisien ke rentang (-mod/2, mod/2]
    return [((x + mod//2) % mod) - mod//2 for x in a]

def inv_mod_prime(a, mod):               # invers di Z_mod[x]/(x^N-1), mod prima
    def pd(v):
        d = len(v)-1
        while d > 0 and v[d] % mod == 0: d -= 1
        return d
    def pmul(u, v):
        r = [0]*(len(u)+len(v))
        for i, ui in enumerate(u):
            for j, vj in enumerate(v):
                r[i+j] = (r[i+j] + ui*vj) % mod
        return r
    def psub(u, v):
        r = [0]*max(len(u), len(v))
        for i in range(len(r)):
            r[i] = ((u[i] if i < len(u) else 0) - (v[i] if i < len(v) else 0)) % mod
        return r
    def pdivmod(A, B):
        A = A[:]; db = pd(B); lead = pow(B[db], mod-2, mod)
        Q = [0]*max(1, len(A)-db)
        while pd(A) >= db and any(x % mod for x in A):
            da = pd(A)
            if da < db: break
            co = (A[da]*lead) % mod; sh = da-db
            Q[sh] = co
            A = psub(A, [0]*sh + [(co*b) % mod for b in B])
            if pd(A) == 0 and A[0] % mod == 0: break
        return Q, A
    m = [(-1) % mod] + [0]*(N-1) + [1]   # modulus x^N - 1
    r0, r1 = m[:], a[:] + [0]*(N+1-len(a))
    t0, t1 = [0], [1]
    while any(x % mod for x in r1):
        Q, R = pdivmod(r0, r1)
        r0, r1 = r1, R
        t0, t1 = t1, psub(t0, pmul(Q, t1))
    if pd(r0) != 0: return None           # tak invertible
    c = pow(r0[0], mod-2, mod)
    res = [(x*c) % mod for x in (t0 + [0]*N)[:N]]
    out = [0]*N
    for i, v in enumerate(res): out[i % N] = (out[i % N] + v) % mod
    return out

def inv_mod_2power(a, k):                 # invers mod 2^k via Hensel dari mod 2
    g = inv_mod_prime([x % 2 for x in a], 2)
    if g is None: return None
    mod = 2
    while mod < (1 << k):                 # g <- g*(2 - a*g)
        mod *= mod
        ag = cmul(a, g, mod)
        g = cmul(g, [((2 if i == 0 else 0) - ag[i]) % mod for i in range(N)], mod)
    return [x % (1 << k) for x in g]

# --- keygen (f,g ternary; f invertible mod p dan mod q) ---
f = [0, -1, 1, -1, 0, 0, -1, 0, 1, 1, -1]
g = [-1, 1, 1, 0, -1, 1, 0, 1, 1, 1, 0]
fp = inv_mod_prime([x % p for x in f], p)      # f^-1 mod p
fq = inv_mod_2power(f, 5)                       # f^-1 mod q = 2^5
h  = cmul([(p*x) % q for x in fq], g, q)        # h = p*fq*g mod q  (public key)

# --- enkripsi ---
m = [1, 1, -1, 0, 0, 1, 0, 1, 0, 1, -1]         # pesan ternary
r = [0, -1, 1, 0, 0, 1, -1, 0, 1, 1, 1]         # nonce kecil
c = [(x+y) % q for x, y in zip(cmul(r, h, q), m)]

# --- dekripsi ---
a = center(cmul(f, c, q), q)                    # a = p*r*g + f*m (tanpa wrap q)
b = [x % p for x in a]                           # mod p -> f*m mod p
rec = center(cmul([x % p for x in fp], b, p), p) # fp*(f*m) = m

assert rec == m
print("pesan  :", m)      # [1, 1, -1, 0, 0, 1, 0, 1, 0, 1, -1]
print("recover:", rec)    # sama persis
```

<div class="callout tip"><span class="lbl">insight</span>
Dua hal krusial. <b>Satu:</b> invers polinomial. <code>mod p</code> pakai
extended Euclid di ring; <code>mod q=2^k</code> tidak bisa langsung (bukan
field) jadi cari invers <code>mod 2</code> dulu lalu Hensel lift
(<code>g &lt;- g(2 - ag)</code> yang menggandakan presisi tiap iterasi).
<b>Dua:</b> decryption failure. Dekripsi cuma benar kalau tiap koefisien
<code>p·r·g + f·m</code> tetap di dalam <code>(-q/2, q/2]</code> sebelum
center-lift. Kalau <code>q</code> terlalu kecil atau norm <code>f,g,r,m</code>
terlalu besar, ada koefisien yang wrap dan pesan rusak. Parameter di atas dipilih
supaya aman.
</div>

## Kapan berlaku

- **Keamanan bergantung** pada kerahasiaan basis pendek `f,g,F,G` DAN pada
  cara sampling signature (rounding sederhana bocor info trapdoor lewat
  transcript; Gaussian sampling / framework GPV mencegahnya).
- **Ring `x^N+1`** dipilih karena efisien (FFT/NTT) dan punya struktur aljabar
  bagus, tapi struktur ekstra ini juga sumber sebagian serangan (ring/ideal
  lattice attacks) - jadi parameter harus hati-hati.
- Modulus `q`, dimensi `N`, dan norm bound harus diset sesuai level keamanan;
  salah pilih bikin lattice-nya solvable.

## Contoh

Verifikasi identitas trapdoor `fG - gF = 1` di ring (cek satu file recovery):

```python
def sub(a, b): return [a[i] - b[i] for i in range(len(a))]

# f, g, F, G: list koefisien panjang N dari trapdoor
lhs = sub(mul(f, G), mul(g, F))
assert lhs[0] == 1 and all(c == 0 for c in lhs[1:])   # == 1 di ring
```

## Belajar lebih dalam

Materi ini cukup buat paham strukturnya. Kalau mau dalemin algoritma NTRU
penuh (parameter, keamanan, invers polinomial, decryption failure), belajar
dari sini:

- **Paper asli** - Hoffstein, Pipher, Silverman, *NTRU: A Ring-Based Public Key
  Cryptosystem* (1998). PDF: <https://ntru.org/f/hps98.pdf>. Bab keygen/enc/dec
  paling jelas dari sumber pertama.
- **Situs resmi NTRU** - <https://ntru.org/> - spesifikasi, parameter set
  (NTRU-HPS, NTRU-HRSS), dan referensi implementasi.
- **A Graduate Course in Applied Cryptography** (Boneh-Shoup),
  <https://toc.cryptobook.us/> - bab lattice-based crypto, gratis.
- **Wikipedia NTRUEncrypt** - <https://en.wikipedia.org/wiki/NTRUEncrypt> -
  ringkasan alur + contoh angka, bagus buat cek pemahaman.
- **Falcon** (Ducas et al.) - <https://falcon-sign.info/> - signature
  post-quantum modern berbasis NTRU + Gaussian sampling (yang dibahas di bagian
  trapdoor atas).

## Referensi silang

- Dasar lattice umum: [Dasar Lattice dan Reduksi LLL](/posts/2026/08/23/dasar-lattice-dan-reduksi-lll/).
- Serangan trapdoor NTRU: [NTRU Trapdoor dan Signature Forgery](/posts/2026/08/22/ntru-trapdoor-dan-signature-forgery/).
</content>
