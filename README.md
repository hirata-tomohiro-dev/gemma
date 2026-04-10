# Gemma 3 Linux Offline Bundle

このリポジトリは、社内オフライン環境の Linux x86_64 サーバで `Gemma 3 1B IT QAT` を `llama.cpp` の `llama-server` で起動し、既存の OpenWebUI から OpenAI 互換 API として接続するための primary repo です。

対象サーバは `4 vCPU / 7.7 GiB RAM / CPU-only` のため、今回は `Gemma 3 1B IT QAT` を採用しています。より大きい `4B` 以上は CPU-only では応答速度とメモリ余裕が厳しくなります。

## repo 構成

- primary repo: `gemma`
- secondary repo: `gemma-2`

この repo には以下を含めています。

- `llama.cpp` Linux x64 runtime
- install / start script
- モデル split file `part-00` から `part-04`
- 手順書 `docs/LINUX_GEMMA3_OPENAI_OFFLINE_SETUP.md`

不足分の `part-05` から `part-10` は `gemma-2` repo にあります。

## 500MB 制約

2026-04-10 に `git archive --format=zip` で確認した ZIP サイズは以下です。

- `gemma`: `412,313,326 bytes`
- `gemma-2`: `458,494,651 bytes`

どちらも `500MB` 未満です。

## 配置

GitHub の ZIP ダウンロードを使う場合は、2 つの repo を同じ親ディレクトリに展開してください。

```text
/opt/offline/
  gemma-main/
  gemma-2-main/
```

## Linux サーバでの実行

既知のホスト名または IP、ID、パスワードでサーバにログインし、primary repo 側で以下を実行します。

```bash
cd /opt/offline/gemma-main
chmod +x bundle/linux/install-gemma3-openai-offline.sh
chmod +x bundle/linux/start-gemma3-openai-server.sh
./bundle/linux/install-gemma3-openai-offline.sh
API_KEY=dummy ./bundle/linux/start-gemma3-openai-server.sh
```

## OpenWebUI からの接続

OpenWebUI では `Admin Settings -> Connections -> OpenAI -> Add Connection` から以下を設定してください。

- API URL: `http://<server-ip>:8000/v1`
- API Key: `dummy`
- Model ID allowlist: `gemma3-1b-it-qat` を必要に応じて指定

OpenWebUI 側に追加コードは不要です。

詳細な結合手順、疎通確認、注意点は `docs/LINUX_GEMMA3_OPENAI_OFFLINE_SETUP.md` を参照してください。`gemma-2` は必須です。
