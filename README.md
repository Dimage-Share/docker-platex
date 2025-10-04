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

永続化 (Persistent Volumes):

以下はホスト側 (リポジトリ直下) にディレクトリとして作成・保持され、コンテナ再作成後も状態を維持します。

| ディレクトリ   | コンテナ内マウント先 | 用途                              |
| -------------- | -------------------- | --------------------------------- |
| `share/`       | `/srv/samba/share`   | 共有フォルダ (tex / pdf / script) |
| `volume/`      | `/usr/local/texlive` | TeX Live 本体 (大容量)            |
| `samba-lib/`   | `/var/lib/samba`     | Samba アカウント / TDB 状態       |
| `samba-cache/` | `/var/cache/samba`   | Samba キャッシュ (再生成可)       |
| `samba-log/`   | `/var/log/samba`     | Samba ログ                        |

初回起動後に TeX Live が最小インストールされ、必要パッケージ (platex など) は `tlmgr` が見つかった場合に追加されます。強制的に再インストールしたい場合は以下のように環境変数を指定してください。

```powershell
set FORCE_TEXLIVE=1; docker compose up -d --build
```

再インストール後 `FORCE_TEXLIVE` を解除する場合は環境変数を外して再起動するだけで構いません。

使い方 (Windows クライアントからの例):

1. ビルド/起動

```powershell
docker compose build
docker compose up -d
```

Ports (Host -> Container):

- 1139 -> 139 (NetBIOS セッション)
- 1445 -> 445 (SMB)

Windows では OS が 445/139 を占有しているため高番ポートへマッピングしています。ネットワークドライブ指定時は `\\<docker-host-ip>:1445\share` のようにポート付き UNC 形式を利用するか、`net use` コマンドで指定します (エクスプローラーはポート付き UNC を直接扱えない場合があります)。

例 (管理者 PowerShell):

```powershell
net use * \\<docker-host-ip>\share /user:smbuser smbpass /persistent:yes
# うまく行かない場合は SMB バージョンやファイアウォールを確認してください。
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

トラブルシュート (TeX Live):

- `platex: command not found` → `FORCE_TEXLIVE=1` を指定し再起動し、ログで `tlmgr` が検出されるか確認。
- インストールが途中で止まる → ネットワーク (プロキシ / ミラー) を確認し再実行。
- 追加パッケージが足りない → コンテナ内で `tlmgr install <pkg>` を実行。例: `tlmgr install latexmk`。

トラブルシュート (Samba):

- 接続不可 / タイムアウト → Windows ファイアウォールで 1445/TCP を許可。
- 認証失敗 → `smbuser` / `SMB_PASSWORD` を compose の environment で再設定し再起動。
- 古い認証情報が残る → `cmdkey /list` で資格情報を確認し削除後、再接続。

ライセンス: `LICENSE` を参照。
# docker-platex