---
title: "NAMA SOAL :: NAMA CTF 2026"
date: 2026-08-16 20:00:00 +0700
categories: [RSA]
tags: [tag1, tag2]
description: Satu kalimat ringkas soal + teknik yang dipakai.
---

<!--
  BILINGUAL: prosa ditulis dua kali dalam blok
    <div class="lang-en" markdown="1"> ... teks Inggris ... </div>
    <div class="lang-id" markdown="1"> ... teks Indonesia ... </div>
  markdown="1" WAJIB supaya isi di dalamnya tetap dirender sebagai markdown.
  Heading (## ...), code block, dan rumus $$...$$ TIDAK perlu diterjemahin,
  tulis sekali saja di luar blok bahasa.

  GAMBAR: taruh di assets/img/posts/<slug-writeup>/ ; embed:
    ![alt]({{ "/assets/img/posts/<slug-writeup>/net.png" | relative_url }})
-->

<div class="callout info"><span class="lbl">info soal</span>
<b>CTF:</b> Nama CTF 2026 :: <b>Kategori:</b> Crypto :: <b>Poin:</b> 300
</div>

<div class="lang-en" markdown="1">
One paragraph: what the challenge is, where the flaw is.
</div>
<div class="lang-id" markdown="1">
Satu paragraf: soalnya apa, celahnya apa.
</div>

## Soal

```python
# chall.py
# tempel bagian yang relevan saja
```

## Analisis

<div class="lang-en" markdown="1">
Why I suspected this direction, not just what finally worked. Note the dead ends too.
</div>
<div class="lang-id" markdown="1">
Kenapa curiga ke arah tertentu, bukan cuma apa yang akhirnya berhasil.
Tulis juga jalan buntu yang sempat dicoba.
</div>

## Dasar matematika

$$
ed - k\varphi(n) = 1
$$

<div class="callout tip"><span class="lbl">insight</span>
<span class="lang-en">Explain the bound: when this attack applies and when it fails.</span>
<span class="lang-id">Jelaskan bound-nya: kapan serangan ini berlaku dan kapan gagal.</span>
</div>

## Solver

```python
#!/usr/bin/env python3
```

```console
$ python3 solve.py
FLAG{contoh_flag_di_sini}
```

## Flag

```text
FLAG{contoh_flag_di_sini}
```

## Catatan

<div class="lang-en" markdown="1">
- Reference papers / other writeups that helped.
</div>
<div class="lang-id" markdown="1">
- Referensi paper / writeup lain yang membantu.
</div>
