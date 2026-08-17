#!/usr/bin/env bash
# Bikin PASANGAN writeup bilingual (file ID + file EN) dari template + folder gambar.
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
#
# Hasil: 2 file .md ->  _posts/YYYY-MM-DD-slug.md  (ID)
#                       _posts/YYYY-MM-DD-slug-en.md (EN)
# Kedua file punya ref sama supaya toggle bahasa saling terhubung.
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

case "$KIND" in
  ctf)        TPL_ID="template/ctf-id.md";        TPL_EN="template/ctf-en.md" ;;
  cryptohack) TPL_ID="template/cryptohack-id.md"; TPL_EN="template/cryptohack-en.md" ;;
  knowledge)  TPL_ID="template/knowledge-id.md";  TPL_EN="template/knowledge-en.md" ;;
  *) echo "jenis tidak dikenal: $KIND"; exit 1 ;;
esac

SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
DATE=$(date +%Y-%m-%d)
STAMP=$(date "+%Y-%m-%d %H:%M:%S %z")
OUT_ID="_posts/${DATE}-${SLUG}.md"
OUT_EN="_posts/${DATE}-${SLUG}-en.md"
IMGDIR="assets/img/posts/${SLUG}"

if [ -e "$OUT_ID" ] || [ -e "$OUT_EN" ]; then echo "sudah ada: $OUT_ID / $OUT_EN"; exit 1; fi
mkdir -p _posts "$IMGDIR"; touch "$IMGDIR/.gitkeep"

fill(){  # $1=template $2=out $3=title
  cp "$1" "$2"
  python3 - "$2" "$3" "$STAMP" "$CAT" "$KIND" "$SLUG" <<'PY'
import sys, re
out, title, stamp, cat, kind, slug = sys.argv[1:7]
s = open(out, encoding='utf-8').read()
s = re.sub(r'^title:.*$', f'title: "{title}"', s, count=1, flags=re.M)
s = re.sub(r'^date:.*$',  f'date: {stamp}',    s, count=1, flags=re.M)
s = re.sub(r'^ref:.*$',   f'ref: {slug}',      s, count=1, flags=re.M)
if kind == 'ctf':
    s = re.sub(r'^categories:.*$', f'categories: [{cat}]', s, count=1, flags=re.M)
elif kind == 'cryptohack':
    s = re.sub(r'^ch_cat:.*$', f'ch_cat: {cat}', s, count=1, flags=re.M)
elif kind == 'knowledge':
    s = re.sub(r'^kn_cat:.*$', f'kn_cat: {cat}', s, count=1, flags=re.M)
s = s.replace('<slug>', slug)
open(out, 'w', encoding='utf-8').write(s)
PY
}

fill "$TPL_ID" "$OUT_ID" "$TITLE"
fill "$TPL_EN" "$OUT_EN" "$TITLE"

echo "dibuat : $OUT_ID   (Indonesia)"
echo "dibuat : $OUT_EN   (English)"
echo "gambar : $IMGDIR/"
echo "ref    : $SLUG  (sudah sama di kedua file)"
