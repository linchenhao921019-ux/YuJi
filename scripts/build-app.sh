#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP_NAME="余迹"
APP_DIR="${YUJI_APP_DIR:-$ROOT/.dist.noindex/$APP_NAME.app}"
SWIFT_BUILD_DIR="${YUJI_BUILD_DIR:-$HOME/Library/Caches/YuJiBuild}"
ICONSET="$SWIFT_BUILD_DIR/AppIcon.iconset"

cd "$ROOT"
mkdir -p "$SWIFT_BUILD_DIR"
swift build --scratch-path "$SWIFT_BUILD_DIR" -c release
BUILD_DIR="$(swift build --scratch-path "$SWIFT_BUILD_DIR" -c release --show-bin-path)"

rm -rf "$APP_DIR" "$ICONSET"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$ICONSET"

cp "$BUILD_DIR/YuJi" "$APP_DIR/Contents/MacOS/YuJi"
cp "$ROOT/Info.plist" "$APP_DIR/Contents/Info.plist"

bundle_id="${YUJI_BUNDLE_ID:-}"
LOCAL_BUNDLE_ID_FILE="$ROOT/.local-bundle-id"
if [[ -z "$bundle_id" && -f "$LOCAL_BUNDLE_ID_FILE" ]]; then
  bundle_id=$(tr -d '[:space:]' < "$LOCAL_BUNDLE_ID_FILE")
fi

if [[ -n "$bundle_id" ]]; then
  if [[ ! "$bundle_id" =~ '^[A-Za-z0-9.-]+$' ]]; then
    echo "无效的 Bundle ID：$bundle_id" >&2
    exit 1
  fi
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle_id" "$APP_DIR/Contents/Info.plist"
fi

for spec in \
  "16 icon_16x16.png" \
  "32 icon_16x16@2x.png" \
  "32 icon_32x32.png" \
  "64 icon_32x32@2x.png" \
  "128 icon_128x128.png" \
  "256 icon_128x128@2x.png" \
  "256 icon_256x256.png" \
  "512 icon_256x256@2x.png" \
  "512 icon_512x512.png" \
  "1024 icon_512x512@2x.png"; do
    size=${spec%% *}
    name=${spec#* }
    sips -z "$size" "$size" "$ROOT/Resources/AppIcon-1024.png" --out "$ICONSET/$name" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
xattr -cr "$APP_DIR"
/bin/zsh "$ROOT/scripts/sign-app.sh" "$APP_DIR"

echo "$APP_DIR"
