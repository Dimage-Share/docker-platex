#!/bin/bash
set -euo pipefail

log(){ echo "[entrypoint] $*"; }

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

# Ensure TeX Live minimal install + required packages (platex etc.) exist
TEXROOT=/usr/local/texlive
NEED_INSTALL=0
if [ ! -x /usr/local/texlive/bin/x86_64-linux/platex ]; then
  if [ ! -d "$TEXROOT/texmf-dist" ]; then
    NEED_INSTALL=1
  else
    NEED_INSTALL=2 # only missing platex packages
  fi
fi

if [ "$NEED_INSTALL" -gt 0 ]; then
  log "TeX Live setup required (mode=$NEED_INSTALL). This may take several minutes..."
  if [ "$NEED_INSTALL" -eq 1 ]; then
    mkdir -p "$TEXROOT" && cd /tmp && \
    wget -q http://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz && \
    tar xzf install-tl-unx.tar.gz && \
    printf 'selected_scheme scheme-basic\n' > /tmp/profile.local && \
    printf 'tlpdbopt_install_docfiles 0\n' >> /tmp/profile.local && \
    printf 'tlpdbopt_install_srcfiles 0\n' >> /tmp/profile.local && \
    printf 'tlpdbopt_autobackup 0\n' >> /tmp/profile.local && \
    printf 'option_file_assocs 0\n' >> /tmp/profile.local && \
    for d in /tmp/install-tl-*; do
      if [ -d "$d" ]; then
        (cd "$d" && ./install-tl -profile /tmp/profile.local -repository http://mirror.ctan.org/systems/texlive/tlnet --no-gui --texdir "$TEXROOT") || true
        break
      fi
    done && rm -rf /tmp/install-tl-* /tmp/profile.local
  fi
  # Add bin to PATH and install missing Japanese/platex toolchain
  for b in /usr/local/texlive/*/bin/*; do PATH="$b:$PATH"; break; done
  tlmgr update --self || true
  tlmgr install platex uplatex ptex uptex collection-langjapanese dvipdfmx latex-extra latexmk || true
  log "TeX Live toolchain ensured"
fi

# Ensure locale exists (suppress perl locale warnings)
if command -v localedef >/dev/null 2>&1; then
  localedef -i ja_JP -f UTF-8 ja_JP.UTF-8 2>/dev/null || true
fi
export LANG=ja_JP.UTF-8
export LC_ALL=ja_JP.UTF-8

# Ensure texlive bin is on PATH for session
for b in /usr/local/texlive/*/bin/*; do PATH="$b:$PATH"; break; done
export PATH

# Samba startup (prefer 'samba -i', fallback to smbd)
log "Starting Samba services"
if command -v nmbd >/dev/null 2>&1; then
  nmbd -F &
else
  log "nmbd not found; NetBIOS name service disabled"
fi

if command -v samba >/dev/null 2>&1; then
  exec samba -i -s /etc/samba/smb.conf
elif command -v smbd >/dev/null 2>&1; then
  exec smbd -F -S -s /etc/samba/smb.conf
else
  log "ERROR: Neither samba nor smbd found" >&2
  sleep 5
  exit 1
fi
