#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
VERSION="${1:-v$(date +%Y.%m.%d)}"
OUTPUT="${2:-$ROOT/.dist.noindex/YuJi-macOS-arm64-$VERSION.dmg}"

if [[ ! "$VERSION" =~ '^v[0-9]{4}\.[0-9]{2}\.[0-9]{2}(\.[0-9]{2})?$' ]]; then
  echo "版本格式应为 vYYYY.MM.DD 或 vYYYY.MM.DD.01" >&2
  exit 2
fi

TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/yuji-dmg.XXXXXX")
trap 'rm -rf "$TEMP_DIR"' EXIT

PUBLIC_APP="$TEMP_DIR/余迹.app"
VOLUME_DIR="$TEMP_DIR/volume"
mkdir -p "$VOLUME_DIR" "${OUTPUT:h}"

YUJI_APP_DIR="$PUBLIC_APP" \
YUJI_BUNDLE_ID="com.example.yuji" \
YUJI_SIGN_IDENTITY="-" \
  "$ROOT/scripts/build-app.sh"

/usr/bin/ditto "$PUBLIC_APP" "$VOLUME_DIR/余迹.app"
ln -s /Applications "$VOLUME_DIR/Applications"

/usr/bin/hdiutil create \
  -volname "余迹 ${VERSION#v}" \
  -srcfolder "$VOLUME_DIR" \
  -ov \
  -format UDZO \
  "$OUTPUT"

/usr/bin/hdiutil verify "$OUTPUT"
/usr/bin/shasum -a 256 "$OUTPUT"
