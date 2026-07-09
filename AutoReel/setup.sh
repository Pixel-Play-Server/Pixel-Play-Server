#!/usr/bin/env bash
set -euo pipefail

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Instala XcodeGen: brew install xcodegen"
  exit 1
fi

cd "$(dirname "$0")"
xcodegen generate
echo "Proyecto generado: AutoReel.xcodeproj"
echo "Abre con: open AutoReel.xcodeproj"
