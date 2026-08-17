#!/usr/bin/env bash
# Bikin file writeup/materi baru dari template (sudah bilingual EN/ID) + folder gambar.
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

case "$KIND" in
  ctf)        TPL="template/ctf-writeup.md" ;;
  cryptohack) TPL="template/cryptohack-writeup.md" ;;
  knowledge)  TPL="template/knowledge.md" ;;
  *) echo "jenis tidak dikenal: $KIND (pakai ctf | cryptohack | knowledge)"; exit 1 ;;
esac

if [ ! -f "$TPL" ]; then echo "template hilang: $TPL"; exit 1; fi

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

# salin template, lalu ganti field front matter
cp "$TPL" "$OUT"

# title
python3 - "$OUT" "$TITLE" "$STAMP" "$CAT" "$KIND" "$SLUG" <<'PY'
import sys, re
out, title, stamp, cat, kind, slug = sys.argv[1:7]
s = open(out, encoding='utf-8').read()
s = re.sub(r'^title:.*$',    f'title: "{title}"', s, count=1, flags=re.M)
s = re.sub(r'^date:.*$',     f'date: {stamp}',    s, count=1, flags=re.M)
if kind == 'ctf':
    s = re.sub(r'^categories:.*$', f'categories: [{cat}]', s, count=1, flags=re.M)
elif kind == 'cryptohack':
    s = re.sub(r'^ch_cat:.*$', f'ch_cat: {cat}', s, count=1, flags=re.M)
elif kind == 'knowledge':
    s = re.sub(r'^kn_cat:.*$', f'kn_cat: {cat}', s, count=1, flags=re.M)
# arahin path gambar contoh ke slug asli
s = s.replace('<slug-writeup>', slug).replace('<slug-file>', slug)
open(out, 'w', encoding='utf-8').write(s)
PY

echo "dibuat : $OUT  (sudah bilingual EN/ID, tinggal isi)"
echo "gambar : $IMGDIR/  (taruh file gambar di sini)"
