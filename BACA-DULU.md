# Starter Kit — Blog Terminal/Hacker Theme (Custom, Bukan Remote Theme)

Ini **bukan** dibangun dari `jekyll-theme-hacker` bawaan GitHub — semua
layout, CSS, dan struktur ditulis dari nol supaya kamu punya kontrol penuh
tanpa perlu custom GitHub Actions workflow (cuma pakai 3 plugin yang
di-whitelist GitHub Pages: `jekyll-feed`, `jekyll-sitemap`, `jekyll-seo-tag`).

## Isi

```
hacker-blog/
├── _config.yml            → GANTI: url, author.github, title
├── Gemfile
├── _layouts/               default.html, post.html, page.html
├── _includes/               head (MathJax), sidebar, footer, TOC script
├── assets/css/main.css     → warna tema di sini (root variabel :root{...})
├── index.html               homepage (daftar post)
├── categories.html          arsip per kategori
├── tags.html                arsip per tag
├── about.md                 → GANTI: isi & link GitHub
├── _posts/                  3 contoh writeup (RSA, AES, ECC) — hapus/edit
├── template/writeup-template.md
└── scripts/newpost.sh
```

## Ganti warna aksen

Semua warna didefinisikan sebagai CSS variable di baris paling atas
`assets/css/main.css`:

```css
:root{
  --bg:#080b12;      /* background utama */
  --acc:#3fa9ff;      /* warna aksen (link, heading, dsb) */
  --acc-dim:#2685da;  /* aksen redup (border, hover) */
  ...
}
html[data-theme="light"]{ ... }   /* versi mode terang */
```

Tinggal ganti nilai hex-nya kalau suatu saat mau ganti warna lagi.

## Cara pakai

Isi folder ini menggantikan **seluruh isi repo** `USERNAME.github.io` kamu
(bukan ditambahkan ke atas Chirpy — dua sistem ini beda total, jangan
dicampur). Langkah lengkapnya ada di file panduan HTML terpisah yang saya
kirim bareng kit ini.

Bikin writeup baru:

```bash
./scripts/newpost.sh RSA "Wiener Attack di SantaCTF 2026"
```

## Callout yang tersedia

```html
<div class="callout info"><span class="lbl">info soal</span>...</div>
<div class="callout tip"><span class="lbl">insight</span>...</div>
<div class="callout danger"><span class="lbl">peringatan</span>...</div>
<div class="callout"><span class="lbl">catatan</span>...</div>  <!-- default: kuning -->
```
