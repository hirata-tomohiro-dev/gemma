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
MODEL_PART_EXTRA_DIRS_DEFAULT=(
    "${REPO_ROOT}/../gemma-2/bundle/linux/vendor/models"
    "${REPO_ROOT}/../gemma-2-main/bundle/linux/vendor/models"
)

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

resolve_part_path_or_fail() {
    local filename="$1"
    local path
    local found_path=""
    local search_dir

    for search_dir in "${MODEL_PART_SEARCH_DIRS[@]}"; do
        [[ -d "$search_dir" ]] || continue
        path="${search_dir}/${filename}"
        if [[ -f "$path" ]]; then
            if [[ -n "$found_path" ]]; then
                echo "ERROR: Duplicate split file was found for ${filename}" >&2
                echo "  first:  $found_path" >&2
                echo "  second: $path" >&2
                exit 1
            fi
            found_path="$path"
        fi
    done

    if [[ -z "$found_path" ]]; then
        echo "ERROR: Missing split file: $filename" >&2
        echo "  searched directories:" >&2
        for search_dir in "${MODEL_PART_SEARCH_DIRS[@]}"; do
            echo "  - $search_dir" >&2
        done
        exit 1
    fi

    printf '%s\n' "$found_path"
}

build_model_part_search_dirs() {
    local extra_dir

    MODEL_PART_SEARCH_DIRS=("$MODEL_PART_DIR")

    for extra_dir in "${MODEL_PART_EXTRA_DIRS_DEFAULT[@]}"; do
        MODEL_PART_SEARCH_DIRS+=("$extra_dir")
    done

    if [[ -n "${MODEL_PART_EXTRA_DIRS:-}" ]]; then
        IFS=':' read -r -a user_extra_dirs <<< "${MODEL_PART_EXTRA_DIRS}"
        for extra_dir in "${user_extra_dirs[@]}"; do
            [[ -n "$extra_dir" ]] || continue
            MODEL_PART_SEARCH_DIRS+=("$extra_dir")
        done
    fi
}

prepare_model_parts_or_fail() {
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

        path="$(resolve_part_path_or_fail "$(basename "$rel_path")")"
        echo "[*] Verifying split file $(basename "$path")"
        verify_or_fail "$path" "$expected"
        MODEL_PARTS+=("$path")
        expected_count=$((expected_count + 1))
    done < "$CHECKSUMS_FILE"

    if (( expected_count == 0 )); then
        echo "ERROR: No split-file checksums were found in $CHECKSUMS_FILE" >&2
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

build_model_part_search_dirs
MODEL_PARTS=()
prepare_model_parts_or_fail

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
