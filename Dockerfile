FROM almalinux:9

# Locale / Language settings (ja_JP.UTF-8 を利用) および環境変数
ENV LANG=ja_JP.UTF-8 \
    LC_ALL=ja_JP.UTF-8 \
    LANGUAGE=ja_JP:ja \
    TEXLIVE_INSTALL_NO_CONTEXT_CACHE=1 \
    TEXLIVE_BIN=/usr/local/texlive/bin/x86_64-linux \
    PATH=/usr/local/texlive/bin/x86_64-linux:$PATH

RUN dnf -y update && \
    dnf -y install epel-release && \
    dnf -y install glibc-langpack-ja glibc-langpack-en \
    # (Samba removed) \
    python3 python3-pip which make gcc git wget unzip tar \
    procps-ng iproute net-tools findutils && \
    dnf clean all && rm -rf /var/cache/dnf

# Install TeX Live using the upstream installer (non-interactive minimal install + japanese packages)
# TeX Live はサイズが大きいためイメージビルド時にはインストールしません。
# 起動時にマウントされたボリューム（例: ./volume -> /usr/local/texlive）へ
# 必要に応じてインストールする仕組みを `entrypoint.sh` に実装しています。

RUN mkdir -p /workspace && chmod 0775 /workspace

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY compile.sh /usr/local/bin/compile.sh
COPY sample.tex /workspace/sample.tex
COPY sample_script.py /workspace/sample_script.py

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/compile.sh

VOLUME ["/workspace", "/usr/local/texlive"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
