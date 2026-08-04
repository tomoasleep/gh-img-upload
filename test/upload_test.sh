#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/upload.sh"

assert_equal() {
  local actual="$1"
  local expected="$2"

  if [[ "$actual" != "$expected" ]]; then
    printf 'Expected: %s\nActual:   %s\n' "$expected" "$actual" >&2
    exit 1
  fi
}

image_snapshot='image src="https://github.com/user-attachments/assets/image-id"'
zip_snapshot='textbox "Leave a comment" value="[trace.zip](https://github.com/user-attachments/files/trace-id/trace.zip)"'

assert_equal "$(get_upload_url "$image_snapshot")" "https://github.com/user-attachments/assets/image-id"
assert_equal "$(get_upload_url "$zip_snapshot")" "https://github.com/user-attachments/files/trace-id/trace.zip"
assert_equal "$(get_upload_markdown "screenshot.png" "https://github.com/user-attachments/assets/image-id" "image/png")" "![screenshot.png](https://github.com/user-attachments/assets/image-id)"
assert_equal "$(get_upload_markdown "trace.zip" "https://github.com/user-attachments/files/trace-id/trace.zip" "application/zip")" "[trace.zip](https://github.com/user-attachments/files/trace-id/trace.zip)"

printf 'upload tests passed\n'
