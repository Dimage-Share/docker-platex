FROM almalinux:9

# Locale / Language settings (ja_JP.UTF-8 を利用) および環境変数
ENV LANG=ja_JP.UTF-8 \
    LC_ALL=ja_JP.UTF-8 \
    LANGUAGE=ja_JP:ja \
    TEXLIVE_INSTALL_NO_CONTEXT_CACHE=1

RUN dnf -y update && \
    dnf -y install epel-release && \
    dnf -y install glibc-langpack-ja glibc-langpack-en \
    samba samba-client samba-common cyrus-sasl cyrus-sasl-plain \
    python3 python3-pip which make gcc git wget unzip tar && \
    dnf clean all && rm -rf /var/cache/dnf

# Install TeX Live using the upstream installer (non-interactive minimal install + japanese packages)
# TeX Live はサイズが大きいためイメージビルド時にはインストールしません。
# 起動時にマウントされたボリューム（例: ./volume -> /usr/local/texlive）へ
# 必要に応じてインストールする仕組みを `entrypoint.sh` に実装しています。

# Create share directory (samba 共有用)
RUN mkdir -p /srv/samba/share && chmod 0775 /srv/samba/share

COPY smb.conf /etc/samba/smb.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY compile.sh /usr/local/bin/compile.sh
COPY sample.tex /srv/samba/share/sample.tex
COPY sample_script.py /srv/samba/share/sample_script.py

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/compile.sh

EXPOSE 139 445

# 永続化: TeX Live (/usr/local/texlive) と Samba 共有ディレクトリ
VOLUME ["/srv/samba/share", "/usr/local/texlive"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
