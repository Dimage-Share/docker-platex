#!/bin/bash
set -euo pipefail

# Usage: compile.sh input.tex
if [ "$#" -lt 1 ]; then
  echo "Usage: $0 file.tex"
  exit 2
fi

INPUT="$1"
DIR=$(dirname "$INPUT")
BASE=$(basename "$INPUT" .tex)

cd "$DIR"

# Run platex (pLaTeX) and convert to PDF using dvipdfmx
platex -interaction=nonstopmode "$BASE.tex"
dvipdfmx -o "$BASE.pdf" "$BASE.dvi"

echo "Generated: $DIR/$BASE.pdf"
