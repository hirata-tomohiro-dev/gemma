# Gemma 3 Linux Server Offline Setup

この repo は、社内オフライン環境の Linux x86_64 サーバで `Gemma 3 1B IT QAT` を OpenAI 互換 API として起動し、既設の OpenWebUI から接続するための primary bundle です。

モデル split file は `500MB` 制約に合わせて 2 repo に分かれています。

- primary repo: `gemma`
- secondary repo: `gemma-2`

## 採用構成

- モデル: `Gemma 3 1B IT QAT`
- 実行基盤: `llama.cpp` の `llama-server`
- 接続方式: OpenAI 互換 API
- 想定サーバ: `4 vCPU / 7.7 GiB RAM / CPU-only`

今回のサーバでは、より大きい `4B` 以上は CPU-only では応答速度とメモリ余裕が厳しくなります。`1B` を使うのが現実的です。

## 500MB 制約への対応

2026-04-10 に `git archive --format=zip` で確認した ZIP サイズは以下です。

- `gemma`: `412,313,326 bytes`
- `gemma-2`: `458,494,651 bytes`

どちらも `500MB` 未満です。

## 含まれるもの

`gemma` repo:

- `bundle/linux/vendor/llama.cpp/llama-b8740-bin-ubuntu-x64.tar.gz`
- `bundle/linux/vendor/runtime/lib/libstdc++.so.6`
- `bundle/linux/vendor/models/gemma3-1b-it-qat.gguf.part-00` から `part-04`
- `bundle/linux/install-gemma3-openai-offline.sh`
- `bundle/linux/start-gemma3-openai-server.sh`

`gemma-2` repo:

- `bundle/linux/vendor/models/gemma3-1b-it-qat.gguf.part-05` から `part-10`

## 前提

- Linux x86_64
- `bash`, `tar`, `sha256sum`, `cat`, `curl` が利用可能
- サーバ上でユーザー権限で実行可能
- OpenWebUI からサーバの `8000/tcp` に到達できる

## 社内持ち込み手順

1. インターネット接続可能な環境で、以下 2 つの GitHub repo を ZIP ダウンロードします。
2. 社内へ `gemma` と `gemma-2` の ZIP を持ち込みます。
3. Linux サーバ上で同じ親ディレクトリに展開します。

```text
/opt/offline/
  gemma-main/
  gemma-2-main/
```

## 結合手順

`install-gemma3-openai-offline.sh` は、primary repo の `part-00` から `part-04` と、secondary repo の `part-05` から `part-10` を自動検出して結合します。

既知のホスト名または IP、ID、パスワードで Linux サーバにログイン後、primary repo 側で以下を実行してください。

```bash
cd /opt/offline/gemma-main
chmod +x bundle/linux/install-gemma3-openai-offline.sh
./bundle/linux/install-gemma3-openai-offline.sh
```

この処理で実行される内容:

- `llama.cpp` runtime を `artifacts/linux-gemma3-openai/llama.cpp/` に展開
- split file を `artifacts/linux-gemma3-openai/models/gemma3-1b-it-qat.gguf` に再結合
- SHA256 を検証

## 起動手順

```bash
cd /opt/offline/gemma-main
chmod +x bundle/linux/start-gemma3-openai-server.sh
API_KEY=dummy HOST=0.0.0.0 PORT=8000 THREADS=4 CTX_SIZE=4096 ./bundle/linux/start-gemma3-openai-server.sh
```

デフォルト値:

- Host: `0.0.0.0`
- Port: `8000`
- Threads: `4`
- Context size: `4096`
- Parallel: `1`
- Model alias: `gemma3-1b-it-qat`

メモリ余裕をさらに優先するなら、まず `CTX_SIZE=2048` で起動して問題ないか確認してください。

この start script は、同梱している `bundle/linux/vendor/runtime/lib/libstdc++.so.6` を自動で `LD_LIBRARY_PATH` に追加します。RHEL 9.2 の標準 `libstdc++.so.6` は `GLIBCXX_3.4.29` までのため、`llama.cpp` の `GLIBCXX_3.4.30` 要求をここで吸収します。

## API 疎通確認

同一サーバ上で:

```bash
curl http://127.0.0.1:8000/v1/models
```

`gemma3-1b-it-qat` が見えれば準備完了です。

## OpenWebUI 接続手順

OpenWebUI は既に社内にある前提なので、追加コードは不要です。管理画面で接続先を追加してください。

1. OpenWebUI を開く
2. `Admin Settings -> Connections -> OpenAI` に移動
3. `Add Connection` を押す
4. 以下を設定する

- API URL: `http://<server-ip>:8000/v1`
- API Key: `dummy`
- Model IDs allowlist: `gemma3-1b-it-qat` を必要に応じて指定

保存後、モデル一覧に `gemma3-1b-it-qat` が出れば接続完了です。

## 注意

- この構成は `Ollama API` ではなく `OpenAI 互換 API` です。
- OpenWebUI が Docker 上にある場合は、`127.0.0.1` ではなくコンテナから到達できるサーバ IP またはホスト名を使ってください。
- `gemma-2` repo が同じ親ディレクトリに無いと再結合に必要な split file が不足して install に失敗します。
- CPU-only のため、初回応答や長文生成は遅めです。
