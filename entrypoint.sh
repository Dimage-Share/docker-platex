#!/bin/bash
set -euo pipefail

log(){ echo "[entrypoint] $*"; }
set -x

# Environment variables:
# SMB_PASSWORD - password for smbuser (default: smbpass)

SMB_PASS=${SMB_PASSWORD:-smbpass}

# Ensure /srv/samba/share exists and ownership
mkdir -p /srv/samba/share
# Defer ownership change until after smbuser creation (we create user shortly below)

# Create system user for smb access
if ! id -u smbuser >/dev/null 2>&1; then
  useradd -M -s /sbin/nologin smbuser || true
fi
chown smbuser:smbuser /srv/samba/share || true
chmod 0775 /srv/samba/share
echo -e "$SMB_PASS\n$SMB_PASS" | smbpasswd -s -a smbuser || true
smbpasswd -e smbuser || true
log "Configured smbuser"

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

########################################
# Samba startup (robust)                #
########################################
log "Preparing Samba"
mkdir -p /var/log/samba && chmod 755 /var/log/samba
mkdir -p /var/lib/samba/private /var/cache/samba /run/samba
chmod 750 /var/lib/samba/private || true
chown root:root /var/lib/samba /var/lib/samba/private /var/cache/samba /run/samba || true

# Initialize secrets.tdb if missing
if [ ! -s /var/lib/samba/private/secrets.tdb ]; then
  log "Initializing secrets.tdb"
  # smbd --help で確認できるオプション: 一旦最小デーモン起動して自動生成させる
  (smbd -D -s /etc/samba/smb.conf || true)
  # 少し待つ
  sleep 2
fi

command -v smbd || log "smbd not in PATH?"
command -v samba || log "samba wrapper not found (ok)"

log "Starting Samba services"
if command -v nmbd >/dev/null 2>&1; then
  nmbd -D || log "nmbd start failed (ignored)"
else
  log "nmbd not found; NetBIOS disabled"
fi

if command -v samba >/dev/null 2>&1; then
  samba -i -s /etc/samba/smb.conf &
  SAMBA_PID=$!
  sleep 2
  if ! kill -0 $SAMBA_PID 2>/dev/null; then
    log "samba wrapper failed; falling back to smbd -F"
    smbd -F -s /etc/samba/smb.conf
  else
    wait $SAMBA_PID
  fi
elif command -v smbd >/dev/null 2>&1; then
  # Ensure user added AFTER secrets.tdb is initialized
  if ! pdbedit -L | grep -q '^smbuser:'; then
    echo -e "$SMB_PASS\n$SMB_PASS" | smbpasswd -s -a smbuser || log "Failed to add smbuser"
  fi
  smbpasswd -e smbuser || true
  log "Launching smbd (foreground)"
  exec smbd -F -s /etc/samba/smb.conf
else
  log "ERROR: Neither samba nor smbd found" >&2
  sleep 5
  exit 1
fi
