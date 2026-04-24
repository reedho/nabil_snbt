#!/usr/bin/env bash
# ============================================================
# Build Script — SNBT 12-Hari Study Guide
# Converts markdown documents to print-ready HTML and PDF
#
# Usage:
#   ./build.sh          → Build all (HTML + PDF per file + combined PDF)
#   ./build.sh html     → Build HTML only
#   ./build.sh pdf      → Build PDF only
#   ./build.sh single   → Build single combined PDF only
#   ./build.sh clean    → Remove build output
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BUILD_DIR="$SCRIPT_DIR/build"
CSS="$SCRIPT_DIR/style.css"

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[BUILD]${NC} $1"; }
ok()  { echo -e "${GREEN}  ✓${NC} $1"; }
warn(){ echo -e "${YELLOW}  !${NC} $1"; }

# --- File order ---
FILES=(
  "00_RINGKASAN-12-HARI.md"
  "00_RUPA-RUPA-INFO-DAN-MOTIVASI.md"
  "00_SUMBER-LATIHAN-DAN-SIMULASI.md"
  "00_VOCAB-CHEATSHEET.md"
  "hari-01_8-april_diagnostik-dan-strategi.md"
  "hari-02_9-april_literasi-inggris-skimming-scanning.md"
  "hari-03_10-april_penalaran-umum-dan-vocab.md"
  "hari-04_11-april_inggris-inference-dan-main-idea.md"
  "hari-05_12-april_simulasi-penuh-1.md"
  "hari-06_13-april_matematika-kuantitatif-maintenance.md"
  "hari-07_14-april_literasi-indonesia-dan-pbm.md"
  "hari-08_15-april_inggris-vocab-context-dan-ppu.md"
  "hari-09_16-april_penalaran-umum-lanjutan.md"
  "hari-10_17-april_simulasi-penuh-2.md"
  "hari-11_18-april_review-targeted-dan-drilling.md"
  "hari-12_19-april_istirahat-dan-mental-prep.md"
)

# --- Pandoc options ---
PANDOC_OPTS=(
  --standalone
  --css="$CSS"
  --embed-resources
  --from=markdown+task_lists+smart
  --to=html5
  --highlight-style=breezeDark
  --toc=false
  --wrap=none
)

# --- Post-processing: force <details open>, fix title ---
postprocess_html() {
  local file="$1"
  local title="${2:-}"
  # Force all <details> to be open (so answers are visible when printed)
  sed -i 's/<details>/<details open>/g' "$file"
  # Fix title tag if provided
  if [[ -n "$title" ]]; then
    sed -i "s|<title>.*</title>|<title>${title}</title>|" "$file"
  fi
}

# --- Functions ---

build_html() {
  log "Building individual HTML files..."
  mkdir -p "$BUILD_DIR/html"

  for f in "${FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
      warn "Skipping $f (not found)"
      continue
    fi
    local base="${f%.md}"
    pandoc "${PANDOC_OPTS[@]}" \
      --metadata title="" \
      -o "$BUILD_DIR/html/${base}.html" "$f"
    postprocess_html "$BUILD_DIR/html/${base}.html" "$base"
    ok "$f → ${base}.html"
  done
}

build_combined_html() {
  log "Building combined HTML..."
  mkdir -p "$BUILD_DIR"

  # Create a combined markdown with page break markers
  local combined="$BUILD_DIR/_combined.md"
  > "$combined"

  for i in "${!FILES[@]}"; do
    local f="${FILES[$i]}"
    if [[ ! -f "$f" ]]; then
      warn "Skipping $f (not found)"
      continue
    fi
    # Add page break between documents (except before the first)
    if [[ $i -gt 0 ]]; then
      echo -e '\n<div style="page-break-before: always;"></div>\n' >> "$combined"
    fi
    cat "$f" >> "$combined"
    echo -e '\n' >> "$combined"
  done

  pandoc "${PANDOC_OPTS[@]}" \
    --metadata title="" \
    -o "$BUILD_DIR/SNBT-12-Hari-Lengkap.html" \
    "$combined"

  postprocess_html "$BUILD_DIR/SNBT-12-Hari-Lengkap.html" "Persiapan SNBT 12 Hari"
  ok "Combined → SNBT-12-Hari-Lengkap.html"
}

build_pdf_chromium() {
  local html_file="$1"
  local pdf_file="$2"

  if command -v chromium &>/dev/null; then
    chromium \
      --headless \
      --disable-gpu \
      --no-sandbox \
      --print-to-pdf="$pdf_file" \
      --print-to-pdf-no-header \
      --no-pdf-header-footer \
      "file://${html_file}" 2>/dev/null
    return 0
  elif command -v google-chrome &>/dev/null; then
    google-chrome \
      --headless \
      --disable-gpu \
      --no-sandbox \
      --print-to-pdf="$pdf_file" \
      --print-to-pdf-no-header \
      --no-pdf-header-footer \
      "file://${html_file}" 2>/dev/null
    return 0
  fi
  return 1
}

build_pdf() {
  log "Building individual PDFs via Chromium..."
  mkdir -p "$BUILD_DIR/pdf"

  # First make sure HTML exists
  build_html

  for f in "${FILES[@]}"; do
    local base="${f%.md}"
    local html="$BUILD_DIR/html/${base}.html"
    local pdf="$BUILD_DIR/pdf/${base}.pdf"

    if [[ ! -f "$html" ]]; then
      warn "Skipping $base (no HTML)"
      continue
    fi

    if build_pdf_chromium "$html" "$pdf"; then
      ok "$base → PDF"
    else
      warn "Failed: $base (no Chrome/Chromium found)"
      return 1
    fi
  done
}

build_single_pdf() {
  log "Building single combined PDF..."
  mkdir -p "$BUILD_DIR"

  # Build combined HTML first
  build_combined_html

  local html="$BUILD_DIR/SNBT-12-Hari-Lengkap.html"
  local pdf="$BUILD_DIR/SNBT-12-Hari-Lengkap.pdf"

  if build_pdf_chromium "$html" "$pdf"; then
    ok "Combined PDF → SNBT-12-Hari-Lengkap.pdf"
    echo ""
    log "Output: $pdf"
    ls -lh "$pdf"
  else
    warn "Chromium not found. Open the HTML file in a browser and print to PDF:"
    echo "    $html"
  fi
}

do_clean() {
  log "Cleaning build directory..."
  rm -rf "$BUILD_DIR"
  ok "Done"
}

# --- Main ---

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   SNBT 12-Hari Study Guide — Builder     ║"
echo "╚══════════════════════════════════════════╝"
echo ""

case "${1:-all}" in
  html)
    build_html
    build_combined_html
    echo ""
    log "HTML files in: $BUILD_DIR/html/"
    ;;
  pdf)
    build_pdf
    ;;
  single)
    build_single_pdf
    ;;
  clean)
    do_clean
    ;;
  all)
    build_html
    build_combined_html
    build_single_pdf
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║   Build complete!                        ║"
    echo "║                                          ║"
    echo "║   Per-file HTML : build/html/             ║"
    echo "║   Combined HTML : build/SNBT-...html     ║"
    echo "║   Combined PDF  : build/SNBT-...pdf      ║"
    echo "╚══════════════════════════════════════════╝"
    ;;
  *)
    echo "Usage: $0 [html|pdf|single|clean|all]"
    exit 1
    ;;
esac
