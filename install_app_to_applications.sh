#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
SOURCE_APP="$ROOT/dist/余迹.app"
TARGET_APP="/Applications/余迹.app"

if [[ ! -d "$SOURCE_APP" ]]; then
  echo "未找到：$SOURCE_APP" >&2
  echo "请先运行 scripts/build-app.sh" >&2
  exit 1
fi

if [[ -e "$TARGET_APP" ]]; then
  backup="$HOME/.Trash/余迹-旧版本-$(date +%Y%m%d-%H%M%S).app"
  mv "$TARGET_APP" "$backup"
  echo "旧版本已移到废纸篓：$backup"
fi

ditto "$SOURCE_APP" "$TARGET_APP"
xattr -cr "$TARGET_APP"
codesign --verify --deep --strict "$TARGET_APP"

echo "安装完成：$TARGET_APP"
open "$TARGET_APP"
