#!/usr/bin/env bash
# Bikin file writeup/materi baru + folder gambar-nya.
#
# Pemakaian:
#   ./scripts/newpost.sh ctf        <KATEGORI> "<judul>"
#   ./scripts/newpost.sh cryptohack <ch_cat>   "<judul>"
#   ./scripts/newpost.sh knowledge  <kn_cat>   "<judul>"
#
# Contoh:
#   ./scripts/newpost.sh ctf RSA "Wiener Attack - SantaCTF 2026"
#   ./scripts/newpost.sh cryptohack rsa "Modular Inverting"
#   ./scripts/newpost.sh knowledge ecc "Smart Attack"
set -euo pipefail

if [ $# -lt 3 ]; then
  echo "usage: $0 <jenis> <kategori> \"<judul>\""
  echo "  jenis    : ctf | cryptohack | knowledge"
  echo "  kategori :"
  echo "     ctf        -> RSA | AES | ECC | Hash | PRNG | Lattice | Misc"
  echo "     cryptohack -> introduction general symmetric mathematics rsa"
  echo "                   diffie-hellman elliptic-curves hash-functions"
  echo "                   crypto-web lattices isogenies zkp misc"
  echo "     knowledge  -> rsa | aes | ecc | hash | prng | lattice"
  exit 1
fi

KIND="$1"; CAT="$2"; shift 2
TITLE="$*"

SLUG=$(echo "$TITLE" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')

DATE=$(date +%Y-%m-%d)
STAMP=$(date "+%Y-%m-%d %H:%M:%S %z")
OUT="_posts/${DATE}-${SLUG}.md"
IMGDIR="assets/img/posts/${SLUG}"

if [ -e "$OUT" ]; then echo "sudah ada: $OUT"; exit 1; fi
mkdir -p _posts "$IMGDIR"
touch "$IMGDIR/.gitkeep"

img_hint="<!-- gambar: taruh di ${IMGDIR}/ , embed:
![alt]({{ \"/${IMGDIR}/nama.png\" | relative_url }}) -->"

case "$KIND" in
  ctf)
    cat > "$OUT" <<EOF
---
title: "${TITLE}"
date: ${STAMP}
categories: [${CAT}]
tags: []
description:
---

${img_hint}

<div class="callout info"><span class="lbl">info soal</span>
<b>CTF:</b> :: <b>Kategori:</b> Crypto :: <b>Poin:</b>
</div>

## Soal

\`\`\`python
\`\`\`

## Analisis

## Dasar matematika

\$\$
\$\$

## Solver

\`\`\`python
#!/usr/bin/env python3
\`\`\`

## Flag

\`\`\`text
\`\`\`

## Catatan
EOF
    ;;
  cryptohack)
    cat > "$OUT" <<EOF
---
title: "${TITLE}"
date: ${STAMP}
platform: cryptohack
ch_cat: ${CAT}
tags: []
description:
---

${img_hint}

<div class="callout info"><span class="lbl">challenge</span>
<b>Platform:</b> CryptoHack :: <b>Kategori:</b> ${CAT} :: <b>Poin:</b>
</div>

## Soal

\`\`\`python
\`\`\`

## Ide

## Solver

\`\`\`python
#!/usr/bin/env python3
\`\`\`

## Flag

\`\`\`text
crypto{}
\`\`\`

## Catatan
EOF
    ;;
  knowledge)
    cat > "$OUT" <<EOF
---
title: "${TITLE}"
date: ${STAMP}
platform: knowledge
kn_cat: ${CAT}
tags: []
description:
---

${img_hint}

## Konsep

## Kapan berlaku

## Contoh

\`\`\`python
\`\`\`

## Referensi
EOF
    ;;
  *)
    echo "jenis tidak dikenal: $KIND (pakai ctf | cryptohack | knowledge)"
    rm -rf "$IMGDIR"
    exit 1
    ;;
esac

echo "dibuat : $OUT"
echo "gambar : $IMGDIR/  (taruh file gambar di sini)"
