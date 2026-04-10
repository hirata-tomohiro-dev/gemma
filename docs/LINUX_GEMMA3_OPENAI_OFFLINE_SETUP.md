# Gemma 3 Linux Server Offline Setup

この repo には、Linux x86_64 サーバ向けに `Gemma 3 1B` を OpenAI 互換 API として起動するためのオフライン bundle を含めています。

モデル分割ファイルは `500MB` 制約に合わせて 2 repo に分かれています。

- primary repo: `gemma`
- secondary repo: `gemma-2`

## 採用構成

- モデル: `Gemma 3 1B IT QAT`
- 実行基盤: `llama.cpp` の `llama-server`
- 接続方式: OpenAI 互換 API

## この構成を採用した理由

今回のサーバは `4 vCPU / 7.7 GiB RAM / CPU-only 前提` なので、より大きい `4B` 以上は重くなります。

また、社内ダウンロード制約に対して:

- `llama.cpp` Linux x64 binary: 約 `31.9 MB`
- `Gemma 3 1B` GGUF: 約 `957 MB`

で済みます。

一方、公式 `Ollama` の Linux amd64 runtime は現行 release で約 `2.05 GB` あり、この条件では不利です。

## 含まれるもの

- `bundle/linux/vendor/llama.cpp/llama-b8740-bin-ubuntu-x64.tar.gz`
- `bundle/linux/vendor/models/gemma3-1b-it-qat.gguf.part-00` から `part-04`
- `bundle/linux/install-gemma3-openai-offline.sh`
- `bundle/linux/start-gemma3-openai-server.sh`

`part-05` から `part-10` は `gemma-2` repo 側にあります。

## 前提

- Linux x86_64
- glibc 2.34 以上相当
- 外部インターネット接続不要
- サーバ上でユーザー権限で実行可能
- `bash`, `tar`, `sha256sum`, `cat` が利用可能

## セットアップ

2 つの repo を同じ親ディレクトリに配置します。

GitHub ZIP の場合:

```text
/opt/offline/
  gemma-main/
  gemma-2-main/
```

clone の場合:

```text
/opt/offline/
  gemma/
  gemma-2/
```

`install-gemma3-openai-offline.sh` は、同じ親ディレクトリにある `gemma-2` または `gemma-2-main` から不足 model part を自動検出します。

その上で primary repo 側の repo ルートで以下を実行します。

```bash
chmod +x bundle/linux/install-gemma3-openai-offline.sh
./bundle/linux/install-gemma3-openai-offline.sh
```

この処理で実行される内容:

- `llama.cpp` binary を `artifacts/linux-gemma3-openai/llama.cpp/` に展開
- `gemma` と `gemma-2` の両 repo に分かれた GGUF part を `artifacts/linux-gemma3-openai/models/gemma3-1b-it-qat.gguf` に再結合
- SHA256 を検証

## 起動

```bash
chmod +x bundle/linux/start-gemma3-openai-server.sh
./bundle/linux/start-gemma3-openai-server.sh
```

デフォルト設定:

- Host: `0.0.0.0`
- Port: `8000`
- Threads: `4`
- Context size: `4096`
- Model alias: `gemma3-1b-it-qat`

環境変数で上書きできます。

```bash
HOST=0.0.0.0 PORT=8000 THREADS=4 CTX_SIZE=4096 MODEL_ALIAS=gemma3-1b-it-qat ./bundle/linux/start-gemma3-openai-server.sh
```

## API 確認

同一サーバ上で:

```bash
curl http://127.0.0.1:8000/v1/models
```

## Windows Open WebUI から接続

Windows 側 repo ルートで以下を実行します。

```powershell
.\bundle\windows\start-openwebui.cmd -DisableOllama -OpenAIBaseUrl http://<server-ip>:8000/v1 -OpenAIApiKey dummy
```

`<server-ip>` は社内サーバの IP に置き換えてください。

## 注意

- この構成は `Ollama API` ではなく `OpenAI 互換 API` です。
- そのため、Windows 側では `-DisableOllama` を付けて `OpenAIBaseUrl` を指定します。
- `Gemma 3 1B` は軽量優先のため、品質は `4B` 以上より落ちます。
- ただし今回のサーバスペックとオフライン制約では現実的な選択です。
- `gemma-2` repo が同じ親ディレクトリに無いと、再結合に必要な model part が不足して install に失敗します。
