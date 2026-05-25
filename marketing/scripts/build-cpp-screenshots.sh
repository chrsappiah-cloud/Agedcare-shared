#!/bin/bash
# ---------------------------------------------------------------------------
# build-cpp-screenshots.sh
#
# Generates Custom Product Page promotional screenshots from SVG source files
# for AgedCare Monitor's App Store Connect Custom Product Pages.
#
# SVGs are rendered to PNG at 1290×2796 (6.7" iPhone display resolution).
#
# Usage:
#   ./marketing/scripts/build-cpp-screenshots.sh
#
# Output:
#   marketing/out/cpp/
#     cpp_hero_admin.png
#     cpp_hero_family.png
#     cpp_hero_staff.png
#     cpp_feature_privacy.png
#
# Requires: Inkscape or ImageMagick (prefers Inkscape)
# ---------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SRC_DIR="$PROJECT_DIR/marketing/src/cpp"
OUT_DIR="$PROJECT_DIR/marketing/out/cpp"
WIDTH=1290
HEIGHT=2796

mkdir -p "$OUT_DIR"

# Detect renderer
RENDERER=""
if command -v inkscape &>/dev/null; then
  RENDERER="inkscape"
elif command -v convert &>/dev/null; then
  RENDERER="imagemagick"
else
  echo "ERROR: Neither Inkscape nor ImageMagick found."
  echo "Install one of them:"
  echo "  brew install inkscape"
  echo "  brew install imagemagick"
  exit 1
fi

echo "Using renderer: $RENDERER"
echo ""

for svg in "$SRC_DIR"/*.svg; do
  name="$(basename "$svg" .svg)"
  out="$OUT_DIR/${name}.png"

  echo "Rendering $name ..."

  case "$RENDERER" in
    inkscape)
      inkscape "$svg" \
        --export-type=png \
        --export-filename="$out" \
        --export-width="$WIDTH" \
        --export-height="$HEIGHT" \
        --export-background=white 2>/dev/null
      ;;
    imagemagick)
      convert -background white -density 144 \
        "$svg" \
        -resize "${WIDTH}x${HEIGHT}" \
        "$out"
      ;;
  esac

  echo "  → $out ($(du -h "$out" | cut -f1))"
done

echo ""
echo "✅ All CPP screenshots generated in $OUT_DIR"
echo "Upload to App Store Connect → Custom Product Page → Screenshots"
