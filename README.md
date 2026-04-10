# Gemma 3 Linux Offline Bundle

このリポジトリには、Linux x86_64 サーバ向けに `Gemma 3 1B IT QAT` を `llama.cpp` で起動し、OpenAI 互換 API として社内 Windows 11 の Open WebUI から接続するための資材だけを含めています。

## 含まれるもの

- `bundle/linux/`
- `docs/LINUX_GEMMA3_OPENAI_OFFLINE_SETUP.md`

## セットアップ

repo ルートで以下を実行してください。

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

詳細は `docs/LINUX_GEMMA3_OPENAI_OFFLINE_SETUP.md` を参照してください。
