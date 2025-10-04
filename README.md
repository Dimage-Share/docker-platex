# docker-platex

AlmaLinux ベースのシンプルな pLaTeX + Python 実行用コンテナです。Samba は廃止し、ホストディレクトリをそのままコンテナへボリュームマウントして利用します。

主なファイル:

- `Dockerfile` - イメージ定義
- `entrypoint.sh` - TeX Live インストール (初回) および常駐ループ
- `compile.sh` - pLaTeX → DVI → PDF を行うスクリプト
- `sample.tex` - テスト用 LaTeX ソース
- `sample_script.py` - テスト用 Python スクリプト
- `docker-compose.yml` - ボリュームマウント設定

永続化 (Persistent Volumes):

| ディレクトリ | コンテナ内           | 用途                                 |
| ------------ | -------------------- | ------------------------------------ |
| `work/`      | `/workspace`         | LaTeX / PDF / 任意スクリプト作業領域 |
| `texlive/`   | `/usr/local/texlive` | TeX Live 本体 (再インストール抑制)   |

初回起動後に TeX Live が最小インストールされ、必要パッケージ (platex など) は自動追加されます。強制的に再インストールしたい場合は以下のように環境変数を指定してください。

```powershell
set FORCE_TEXLIVE=1; docker compose up -d --build
```

再インストール後 `FORCE_TEXLIVE` を解除する場合は環境変数を外して再起動するだけで構いません。

使い方:

1. ビルド/起動

```powershell
docker compose build
docker compose up -d
```

2. 作業ファイルを `work/` に配置。既存の `sample.tex` をコンパイル:

```powershell
docker exec -it platex /usr/local/bin/compile.sh /workspace/sample.tex
```

3. Python スクリプトの実行確認:

```powershell
docker exec -it platex python3 /workspace/sample_script.py
```

生成された PDF はホスト側 `work/` に出力されます。

トラブルシュート (TeX Live):

- `platex: command not found` → `FORCE_TEXLIVE=1` を指定し再起動し、ログで `tlmgr` が検出されるか確認。
- インストールが途中で止まる → ネットワーク (プロキシ / ミラー) を確認し再実行。
- 追加パッケージが足りない → コンテナ内で `tlmgr install <pkg>` を実行。例: `tlmgr install latexmk`。

トラブルシュート (一般):

- `platex: command not found` → `FORCE_TEXLIVE=1` を付けて再起動。
- パッケージが足りない → `docker exec -it platex tlmgr install <pkg>`。

ライセンス: `LICENSE` を参照。
# docker-platex