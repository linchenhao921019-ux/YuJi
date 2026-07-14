#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
OUTPUT="$ROOT/.build/cache-scanner-harness"

cd "$ROOT"
swiftc \
  Sources/YuJi/Models.swift \
  Sources/YuJi/SafetyPolicy.swift \
  Sources/YuJi/ResidueScanner.swift \
  Tests/CacheScannerHarness/main.swift \
  -o "$OUTPUT"

"$OUTPUT"
