---
title: "NAMA CHALLENGE"
date: 2026-08-16 20:00:00 +0700
platform: cryptohack
ch_cat: rsa
tags: [tag1, tag2]
description: Satu kalimat ringkas challenge + idenya.
---

<!--
  ch_cat WAJIB salah satu slug ini (sesuai kategori cryptohack.org):
    introduction | general | symmetric | mathematics | rsa |
    diffie-hellman | elliptic-curves | hash-functions | crypto-web |
    lattices | isogenies | zkp | misc

  BILINGUAL: prosa dibungkus blok bahasa (markdown="1" wajib):
    <div class="lang-en" markdown="1"> ... </div>
    <div class="lang-id" markdown="1"> ... </div>
  Heading, code, rumus cukup ditulis sekali di luar blok.

  GAMBAR: assets/img/posts/<slug-file>/ , embed:
    ![alt]({{ "/assets/img/posts/<slug-file>/nama.png" | relative_url }})
-->

<div class="callout info"><span class="lbl">challenge</span>
<b>Platform:</b> CryptoHack :: <b>Kategori:</b> RSA :: <b>Poin:</b> 40
</div>

<div class="lang-en" markdown="1">
One paragraph: what the challenge asks, where the flaw is.
</div>
<div class="lang-id" markdown="1">
Satu paragraf: challenge minta apa, celahnya di mana.
</div>

## Soal

```python
# tempel source / potongan yang relevan
```

## Ide

<div class="lang-en" markdown="1">
Why this attack is the one to pick.
</div>
<div class="lang-id" markdown="1">
Kenapa serangan ini yang dipilih.
</div>

## Solver

```python
#!/usr/bin/env python3
```

```console
$ python3 solve.py
crypto{...}
```

## Flag

```text
crypto{...}
```

## Catatan

<div class="lang-en" markdown="1">
- Key takeaway from this challenge.
</div>
<div class="lang-id" markdown="1">
- Poin penting yang dipelajari dari challenge ini.
</div>
