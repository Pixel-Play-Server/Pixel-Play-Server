#!/usr/bin/env bash
# Embebe frameworks SPM en el .app y firma ad-hoc (necesario para SideStore / dyld).
set -euo pipefail

APP_PATH="${1:?Uso: embed-frameworks.sh path/to/AutoReel.app [DerivedData]}"
DERIVED_DATA="${2:-}"

FRAMEWORKS_DIR="$APP_PATH/Frameworks"
mkdir -p "$FRAMEWORKS_DIR"

copy_framework() {
  local src="$1"
  local name
  name=$(basename "$src")
  if [ ! -d "$FRAMEWORKS_DIR/$name" ]; then
    echo "  + $name"
    cp -R "$src" "$FRAMEWORKS_DIR/"
  fi
}

echo "Buscando frameworks para embeber…"

if [ -n "$DERIVED_DATA" ]; then
  PRODUCTS="$DERIVED_DATA/Build/Products/Release-iphoneos"

  if [ -d "$PRODUCTS/PackageFrameworks" ]; then
    for fw in "$PRODUCTS/PackageFrameworks/"*.framework; do
      [ -e "$fw" ] || continue
      copy_framework "$fw"
    done
  fi

  for fw in "$PRODUCTS/"*.framework; do
    [ -e "$fw" ] || continue
    copy_framework "$fw"
  done

  while IFS= read -r fw; do
    copy_framework "$fw"
  done < <(find "$DERIVED_DATA" -path "*Release-iphoneos/*.framework" -type d 2>/dev/null | sort -u)
fi

REQUIRED=(
  ffmpegkit.framework
  libavcodec.framework
  libavformat.framework
  libavutil.framework
)

echo ""
echo "Frameworks en el bundle:"
ls -1 "$FRAMEWORKS_DIR" || true

missing=0
for req in "${REQUIRED[@]}"; do
  if [ ! -d "$FRAMEWORKS_DIR/$req" ]; then
    echo "ERROR: falta $req"
    missing=1
  fi
done

if [ "$missing" -eq 1 ]; then
  exit 1
fi

SIGN_IDENTITY="${SIGN_IDENTITY:--}"
if [ "$SIGN_IDENTITY" = "-" ]; then
  echo ""
  echo "Firmando ad-hoc (codesign -)…"
else
  echo ""
  echo "Firmando con identidad: $SIGN_IDENTITY"
fi

while IFS= read -r fw; do
  /usr/bin/codesign --force --sign "$SIGN_IDENTITY" --timestamp=none "$fw"
done < <(find "$FRAMEWORKS_DIR" -maxdepth 1 -name "*.framework" -type d)

/usr/bin/codesign --force --sign "$SIGN_IDENTITY" --timestamp=none "$APP_PATH"

echo "Listo: $(find "$FRAMEWORKS_DIR" -maxdepth 1 -name '*.framework' | wc -l | tr -d ' ') frameworks embebidos."
