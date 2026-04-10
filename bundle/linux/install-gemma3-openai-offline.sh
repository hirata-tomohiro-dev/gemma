#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ARTIFACTS_DIR="${REPO_ROOT}/artifacts/linux-gemma3-openai"
LLAMA_ARCHIVE="${SCRIPT_DIR}/vendor/llama.cpp/llama-b8740-bin-ubuntu-x64.tar.gz"
LLAMA_SHA256="aa06af98d4588248e3480acda2eca2daaf49867a42fd0c114c67cb618b39b203"
LLAMA_DIR="${ARTIFACTS_DIR}/llama.cpp"
LLAMA_SERVER="${LLAMA_DIR}/llama-b8740/llama-server"
CHECKSUMS_FILE="${SCRIPT_DIR}/vendor/SHA256SUMS.txt"

MODEL_PART_DIR="${SCRIPT_DIR}/vendor/models"
MODEL_DIR="${ARTIFACTS_DIR}/models"
MODEL_PATH="${MODEL_DIR}/gemma3-1b-it-qat.gguf"
MODEL_SHA256="57c9b4a897df8d1ba26a152eb7b98e8dc743e21a5d5492f8183270565b84932b"

file_size() {
    stat -c '%s' "$1"
}

sha256_file() {
    sha256sum "$1" | awk '{print $1}'
}

check_free_space_or_fail() {
    local path="$1"
    local required_bytes="$2"
    local available_kb
    local available_bytes

    available_kb="$(df -Pk "$path" | awk 'NR==2 {print $4}')"
    available_bytes="$((available_kb * 1024))"

    if (( available_bytes < required_bytes )); then
        echo "ERROR: Not enough free space to build the GGUF model file" >&2
        echo "  required bytes:  $required_bytes" >&2
        echo "  available bytes: $available_bytes" >&2
        echo "  target path:     $path" >&2
        exit 1
    fi
}

verify_or_fail() {
    local path="$1"
    local expected="$2"
    if [[ ! -f "$path" ]]; then
        echo "ERROR: Missing file: $path" >&2
        exit 1
    fi

    local actual
    actual="$(sha256_file "$path")"
    if [[ "$actual" != "$expected" ]]; then
        echo "ERROR: SHA256 mismatch for $path" >&2
        echo "  expected: $expected" >&2
        echo "  actual:   $actual" >&2
        exit 1
    fi
}

verify_model_parts_or_fail() {
    local expected
    local rel_path
    local path
    local expected_count=0

    if [[ ! -f "$CHECKSUMS_FILE" ]]; then
        echo "ERROR: Missing checksum manifest: $CHECKSUMS_FILE" >&2
        exit 1
    fi

    while read -r expected rel_path; do
        [[ -n "${expected:-}" ]] || continue
        [[ "${rel_path:-}" == vendor/models/gemma3-1b-it-qat.gguf.part-* ]] || continue

        path="${SCRIPT_DIR}/${rel_path}"
        echo "[*] Verifying split file $(basename "$path")"
        verify_or_fail "$path" "$expected"
        expected_count=$((expected_count + 1))
    done < "$CHECKSUMS_FILE"

    if (( expected_count == 0 )); then
        echo "ERROR: No split-file checksums were found in $CHECKSUMS_FILE" >&2
        exit 1
    fi

    if (( expected_count != ${#MODEL_PARTS[@]} )); then
        echo "ERROR: Split-file count mismatch" >&2
        echo "  expected count: $expected_count" >&2
        echo "  actual count:   ${#MODEL_PARTS[@]}" >&2
        exit 1
    fi
}

echo "[*] Verifying llama.cpp archive"
verify_or_fail "$LLAMA_ARCHIVE" "$LLAMA_SHA256"

mkdir -p "$ARTIFACTS_DIR" "$MODEL_DIR"

if [[ ! -x "$LLAMA_SERVER" ]]; then
    echo "[*] Extracting llama.cpp runtime"
    rm -rf "$LLAMA_DIR"
    mkdir -p "$LLAMA_DIR"
    tar -xzf "$LLAMA_ARCHIVE" -C "$LLAMA_DIR"
fi

if [[ ! -x "$LLAMA_SERVER" ]]; then
    echo "ERROR: llama-server was not found after extraction: $LLAMA_SERVER" >&2
    exit 1
fi

shopt -s nullglob
MODEL_PARTS=("${MODEL_PART_DIR}"/gemma3-1b-it-qat.gguf.part-*)
shopt -u nullglob

if [[ "${#MODEL_PARTS[@]}" -eq 0 ]]; then
    echo "ERROR: GGUF split files were not found in $MODEL_PART_DIR" >&2
    exit 1
fi

verify_model_parts_or_fail

model_total_bytes=0
for model_part in "${MODEL_PARTS[@]}"; do
    model_total_bytes="$((model_total_bytes + $(file_size "$model_part")))"
done

rebuild_model=false
if [[ -f "$MODEL_PATH" ]]; then
    current_sha="$(sha256_file "$MODEL_PATH")"
    if [[ "$current_sha" != "$MODEL_SHA256" ]]; then
        echo "[*] Existing GGUF checksum mismatch. Rebuilding model file."
        rebuild_model=true
    fi
else
    rebuild_model=true
fi

if [[ "$rebuild_model" == "true" ]]; then
    required_free_bytes="$((model_total_bytes + 67108864))"
    if [[ -f "$MODEL_PATH" ]]; then
        required_free_bytes="$((required_free_bytes + $(file_size "$MODEL_PATH")))"
    fi
    check_free_space_or_fail "$MODEL_DIR" "$required_free_bytes"

    echo "[*] Reassembling Gemma GGUF from split files"
    echo "    source size:   ${model_total_bytes} bytes"
    echo "    output file:   $MODEL_PATH"
    echo "    note:          this can take a few minutes on slow disks"
    tmp_model="${MODEL_PATH}.tmp"
    rm -f "$tmp_model"
    cat "${MODEL_PARTS[@]}" > "$tmp_model"
    tmp_sha="$(sha256_file "$tmp_model")"
    if [[ "$tmp_sha" != "$MODEL_SHA256" ]]; then
        echo "ERROR: Reassembled GGUF checksum mismatch" >&2
        echo "  expected: $MODEL_SHA256" >&2
        echo "  actual:   $tmp_sha" >&2
        exit 1
    fi
    mv "$tmp_model" "$MODEL_PATH"
    echo "[*] Reassembled GGUF successfully"
fi

echo "[*] Offline Gemma server bundle is ready"
echo "    llama-server: $LLAMA_SERVER"
echo "    model:        $MODEL_PATH"
