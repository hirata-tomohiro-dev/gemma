#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

"${SCRIPT_DIR}/install-gemma3-openai-offline.sh"

ARTIFACTS_DIR="${REPO_ROOT}/artifacts/linux-gemma3-openai"
LLAMA_SERVER="${ARTIFACTS_DIR}/llama.cpp/llama-b8740/llama-server"
MODEL_PATH="${ARTIFACTS_DIR}/models/gemma3-1b-it-qat.gguf"
RUNTIME_LIB_DIR="${SCRIPT_DIR}/vendor/runtime/lib"

HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8000}"
THREADS="${THREADS:-4}"
CTX_SIZE="${CTX_SIZE:-4096}"
PARALLEL="${PARALLEL:-1}"
MODEL_ALIAS="${MODEL_ALIAS:-gemma3-1b-it-qat}"

EXTRA_ARGS=()
if [[ -n "${API_KEY:-}" ]]; then
    EXTRA_ARGS+=(--api-key "$API_KEY")
fi

if [[ -f "${RUNTIME_LIB_DIR}/libstdc++.so.6" ]]; then
    export LD_LIBRARY_PATH="${RUNTIME_LIB_DIR}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
fi

echo "[*] Starting Gemma OpenAI-compatible server"
echo "    host:        $HOST"
echo "    port:        $PORT"
echo "    threads:     $THREADS"
echo "    context:     $CTX_SIZE"
echo "    model alias: $MODEL_ALIAS"
if [[ -f "${RUNTIME_LIB_DIR}/libstdc++.so.6" ]]; then
    echo "    runtime lib: bundled libstdc++.so.6"
fi

exec "$LLAMA_SERVER" \
    -m "$MODEL_PATH" \
    --alias "$MODEL_ALIAS" \
    --host "$HOST" \
    --port "$PORT" \
    -t "$THREADS" \
    -c "$CTX_SIZE" \
    -np "$PARALLEL" \
    --jinja \
    "${EXTRA_ARGS[@]}"
