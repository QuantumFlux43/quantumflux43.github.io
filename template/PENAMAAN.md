# Konvensi Penamaan File & Gambar

Ringkasan aturan supaya post + gambar otomatis ke-render di
quantumflux43.github.io. File ini catatan saja, tidak ikut di-build.

## 1. Nama file post (WAJIB format ini)

Semua post ditaruh di folder `_posts/` dengan pola:

```
_posts/YYYY-MM-DD-slug-judul.md
```

Aturan:
- `YYYY-MM-DD` = tanggal, HARUS di depan. Salah format = post tidak muncul.
- `slug-judul` = huruf kecil, spasi jadi tanda hubung `-`, tanpa simbol.
- Ekstensi `.md`.

Contoh:
```
_posts/2026-08-16-easy-babyrsa-cube-root.md
_posts/2026-08-20-modular-arithmetic-starter.md
```

Catatan tanggal: JANGAN pakai tanggal masa depan (lebih baru dari sekarang
dalam waktu UTC). Post bertanggal masa depan di-skip saat build. Aman: pakai
tanggal hari ini atau kemarin.

## 2. Jenis post -> front matter

Yang menentukan post masuk section mana adalah field `platform` di front matter,
BUKAN nama folder.

| Section       | platform            | field kategori | slug kategori |
|---------------|---------------------|----------------|---------------|
| CTF writeup   | (tidak ada / kosong)| categories     | RSA/AES/ECC/Hash/PRNG/Lattice/Misc |
| CryptoHack    | cryptohack          | ch_cat         | lihat tabel di bawah |
| Knowledge     | knowledge           | kn_cat         | rsa/aes/ecc/hash/prng/lattice |

Slug `ch_cat` (CryptoHack, sesuai cryptohack.org):
```
introduction | general | symmetric | mathematics | rsa |
diffie-hellman | elliptic-curves | hash-functions | crypto-web |
lattices | isogenies | zkp | misc
```

Template siap pakai:
- `template/ctf-writeup.md`
- `template/cryptohack-writeup.md`
- `template/knowledge.md`

## 3. Gambar

Struktur folder gambar (1 folder per post, nama = slug post tanpa tanggal):

```
assets/img/posts/<slug-post>/gambar.png
```

Contoh untuk post `2026-08-16-easy-babyrsa-cube-root.md`:
```
assets/img/posts/easy-babyrsa-cube-root/net.png
assets/img/posts/easy-babyrsa-cube-root/diagram.png
```

Cara embed di dalam .md (pakai path absolut lewat relative_url supaya jalan di
GitHub Pages, bukan path relatif):

```markdown
![deskripsi gambar]({{ "/assets/img/posts/easy-babyrsa-cube-root/net.png" | relative_url }})
```

Kenapa `relative_url`: bikin path benar walau baseurl berubah. Jangan pakai
`![](net.png)` atau `../` karena akan patah di halaman post.

Format gambar: PNG / JPG / SVG / WEBP. Kasih nama file deskriptif, huruf kecil,
tanpa spasi (`padding-oracle-flow.png`, bukan `Screenshot 2026.png`).

## 4. Alur publish

```
1. bikin file post (pakai script atau copy template)
2. isi kontennya
3. (opsional) taruh gambar di assets/img/posts/<slug>/
4. git add . && git commit -m "writeup: ..." && git push
5. tunggu ~1 menit, cek live
```

## 5. Script generator (auto bikin file + folder gambar)

```
./scripts/newpost.sh ctf RSA "Nama Soal - Nama CTF 2026"
./scripts/newpost.sh cryptohack rsa "Nama Challenge"
./scripts/newpost.sh knowledge rsa "Judul Materi"
```

Script otomatis: bikin file `_posts/` bertanggal benar, isi front matter sesuai
jenis, dan bikin folder `assets/img/posts/<slug>/` kosong siap diisi gambar.
