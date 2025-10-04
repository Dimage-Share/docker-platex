#!/bin/bash
set -euo pipefail

log(){ echo "[entrypoint] $*"; }
set -x

# (Samba removed) 余計なユーザー / ディレクトリ作成は不要になりました。

# --- TeX Live ensure block (improved) --------------------------------------
TEXROOT=/usr/local/texlive
BIN_DIR="$TEXROOT/bin/x86_64-linux"
PROFILE_FILE=/tmp/texlive.profile

add_tex_path() {
  if [ -d "$BIN_DIR" ]; then
    case :$PATH: in *:$BIN_DIR:*) :;; *) PATH="$BIN_DIR:$PATH";; esac
    export PATH
  fi
}

write_profile() {
  cat > "$PROFILE_FILE" <<'EOF'
selected_scheme scheme-basic
TEXDIR /usr/local/texlive
TEXMFCONFIG /usr/local/texlive/texmf-config
TEXMFVAR /usr/local/texlive/texmf-var
TEXMFHOME /usr/local/texlive/texmf-home
tlpdbopt_install_docfiles 0
tlpdbopt_install_srcfiles 0
tlpdbopt_autobackup 0
tlpdbopt_post_code 0
EOF
}

texlive_install_minimal() {
  log "(Re)installing TeX Live minimal into $TEXROOT"
  rm -rf "$TEXROOT" 2>/dev/null || true
  mkdir -p "$TEXROOT"
  write_profile
  cd /tmp
  wget -q http://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz
  tar xzf install-tl-unx.tar.gz
  local SRC
  SRC=$(find /tmp -maxdepth 1 -type d -name 'install-tl-*' | head -n1)
  if [ -z "$SRC" ]; then
    log "ERROR: install-tl directory not found"; return 1
  fi
  (cd "$SRC" && ./install-tl -profile "$PROFILE_FILE" --no-gui) || log "install-tl finished with non-zero status"
  rm -rf "$SRC" install-tl-unx.tar.gz "$PROFILE_FILE"
  add_tex_path
}

install_japanese_packages() {
  add_tex_path
  if ! command -v tlmgr >/dev/null 2>&1; then
    log "tlmgr still missing after installation"; return 0
  fi
  tlmgr update --self || true
  tlmgr install collection-langjapanese platex uplatex ptex uptex dvipdfmx latexmk || true
  fmtutil-sys --all >/dev/null 2>&1 || fmtutil-sys --byfmt platex || true
  log "Installed Japanese TeX packages (platex=$(command -v platex || echo missing))"
}

FORCE=${FORCE_TEXLIVE:-0}
[ "$FORCE" = "1" ] && log "FORCE_TEXLIVE=1 specified"

if [ "$FORCE" = "1" ] || [ ! -x "$BIN_DIR/platex" ]; then
  texlive_install_minimal
  install_japanese_packages
else
  add_tex_path
  if ! command -v platex >/dev/null 2>&1; then
    install_japanese_packages
  fi
  command -v platex >/dev/null 2>&1 && log "TeX Live ready (platex found)" || log "platex still missing"
fi
# ---------------------------------------------------------------------------

# Ensure locale exists (suppress perl locale warnings)
if command -v localedef >/dev/null 2>&1; then
  localedef -i ja_JP -f UTF-8 ja_JP.UTF-8 2>/dev/null || true
fi
export LANG=ja_JP.UTF-8
export LC_ALL=ja_JP.UTF-8

# Ensure texlive bin is on PATH (final)
add_tex_path

log "Container ready. Sleeping to keep container alive..."
while true; do sleep 3600; done
