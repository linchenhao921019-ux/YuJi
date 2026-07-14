#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
BUILD_ROOT="${YUJI_BUILD_DIR:-$HOME/Library/Caches/YuJiBuild}"
OUTPUT="$BUILD_ROOT/cache-scanner-harness"

cd "$ROOT"
mkdir -p "$BUILD_ROOT"
swiftc \
  Sources/YuJi/Models.swift \
  Sources/YuJi/SafetyPolicy.swift \
  Sources/YuJi/ResidueScanner.swift \
  Tests/CacheScannerHarness/main.swift \
  -o "$OUTPUT"

"$OUTPUT"
