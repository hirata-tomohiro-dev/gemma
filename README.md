# Gemma 3 Linux Offline Bundle

このリポジトリには、Linux x86_64 サーバ向けに `Gemma 3 1B IT QAT` を `llama.cpp` で起動し、OpenAI 互換 API として社内 Windows 11 の Open WebUI から接続するための資材を含めています。

モデル分割ファイルは ZIP サイズを `500MB` 未満に抑えるため、2 repo に分けています。

- primary repo: `gemma`
- secondary repo: `gemma-2`

## 含まれるもの

- `bundle/linux/`
- `docs/LINUX_GEMMA3_OPENAI_OFFLINE_SETUP.md`

この repo には以下を含めています。

- `llama.cpp` runtime
- setup / start script
- モデル part `00` から `04`

不足分のモデル part `05` から `10` は `gemma-2` repo にあります。

## セットアップ

GitHub ZIP を使う場合は、2 つの repo を同じ親ディレクトリに展開してください。

```text
/opt/offline/
  gemma-main/
  gemma-2-main/
```

clone する場合は以下でも動きます。

```text
/opt/offline/
  gemma/
  gemma-2/
```

その上で `gemma` 側 repo ルートで以下を実行してください。

```bash
chmod +x bundle/linux/install-gemma3-openai-offline.sh
chmod +x bundle/linux/start-gemma3-openai-server.sh
./bundle/linux/install-gemma3-openai-offline.sh
./bundle/linux/start-gemma3-openai-server.sh
```

## Windows Open WebUI から接続

```powershell
.\bundle\windows\start-openwebui.cmd -DisableOllama -OpenAIBaseUrl http://<server-ip>:8000/v1 -OpenAIApiKey dummy
```

詳細は `docs/LINUX_GEMMA3_OPENAI_OFFLINE_SETUP.md` を参照してください。`gemma-2` の補助 part repo も必須です。
