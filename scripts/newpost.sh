#!/usr/bin/env bash
# Bikin file writeup baru dari template.
#   ./scripts/newpost.sh RSA "Wiener Attack di SantaCTF 2026"
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 <kategori> <judul>"
  echo "  kategori: RSA | AES | ECC | Hash | PRNG | Lattice | Misc"
  exit 1
fi

CAT="$1"; shift
TITLE="$*"

SLUG=$(echo "$TITLE" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')

DATE=$(date +%Y-%m-%d)
STAMP=$(date "+%Y-%m-%d %H:%M:%S %z")
OUT="_posts/${DATE}-${SLUG}.md"

if [ -e "$OUT" ]; then echo "sudah ada: $OUT"; exit 1; fi
mkdir -p _posts

cat > "$OUT" <<EOF
---
title: "${TITLE}"
date: ${STAMP}
categories: [${CAT}]
tags: []
description:
---

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

echo "dibuat: $OUT"
