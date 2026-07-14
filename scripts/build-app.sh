#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP_NAME="余迹"
APP_DIR="$ROOT/dist/$APP_NAME.app"
ICONSET="$ROOT/.build/AppIcon.iconset"

cd "$ROOT"
swift build -c release
BUILD_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP_DIR" "$ICONSET"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$ICONSET"

cp "$BUILD_DIR/YuJi" "$APP_DIR/Contents/MacOS/YuJi"
cp "$ROOT/Info.plist" "$APP_DIR/Contents/Info.plist"

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
