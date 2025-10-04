# docker-platex

AlmaLinux ベースのコンテナで Samba 共有を公開し、pLaTeX (platex) による PDF 生成と Python スクリプト実行を試せる構成です。

主なファイル:

- `Dockerfile` - イメージ定義
- `smb.conf` - Samba 設定
- `entrypoint.sh` - 起動時に smb ユーザ作成・smbd/nmbd 起動
- `compile.sh` - pLaTeX → DVI → PDF を行うスクリプト
- `sample.tex` - テスト用 LaTeX ソース
- `sample_script.py` - テスト用 Python スクリプト
- `docker-compose.yml` - 簡単に立ち上げるための compose 定義

使い方 (Windows クライアントからの例):

1. ビルド/起動

```powershell
docker compose build
docker compose up -d
```

2. Windows からネットワークドライブとしてマウント: エクスプローラーで `\\<docker-host-ip>\share` に接続（ゲストアクセスが有効）

3. 共有に置いた `sample.tex` をコンテナ内でコンパイル:

```powershell
docker exec -it platex-samba /usr/local/bin/compile.sh /srv/samba/share/sample.tex
```

4. Python スクリプトの実行確認:

```powershell
docker exec -it platex-samba python3 /srv/samba/share/sample_script.py
```

注意: Windows の SMB クライアントや環境によっては認証設定やファイアウォールの調整が必要です。
# docker-platex