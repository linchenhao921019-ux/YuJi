#!/bin/zsh
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "用法：$0 /path/to/App.app" >&2
  exit 2
fi

APP_PATH="$1"
LOCAL_IDENTITY_NAME="YuJi Local Code Signing"
IDENTITY="${YUJI_SIGN_IDENTITY:-}"

if [[ -z "$IDENTITY" ]]; then
  IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -v name="$LOCAL_IDENTITY_NAME" 'index($0, "\"" name "\"") { print $2; exit }')
fi

if [[ -n "$IDENTITY" ]]; then
  codesign --force --deep --options runtime --timestamp=none --sign "$IDENTITY" "$APP_PATH" >/dev/null
  echo "已使用稳定签名：$LOCAL_IDENTITY_NAME"
else
  codesign --force --deep --sign - "$APP_PATH" >/dev/null
  echo "警告：未找到稳定签名身份，已使用临时 ad-hoc 签名。覆盖安装会导致完全磁盘访问需要重新授权。" >&2
fi

codesign --verify --deep --strict "$APP_PATH"
