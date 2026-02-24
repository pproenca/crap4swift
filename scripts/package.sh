#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$SCRIPT_DIR/.."
DIST="$ROOT/dist/crap4swift"
TARBALL="$ROOT/dist/crap4swift-macos-arm64.tar.gz"

echo "Building release..."
cd "$ROOT"
swift build -c release 2>&1

echo "Packaging..."
rm -rf "$DIST" "$TARBALL"
mkdir -p "$DIST"

# Copy binary
cp .build/release/crap4swift "$DIST/crap4swift"

# Strip debug symbols for smaller size
strip -x "$DIST/crap4swift" 2>/dev/null || true

# Ad-hoc codesign (required on Apple Silicon)
codesign --force --sign - "$DIST/crap4swift" 2>/dev/null || true

# Create tarball for GitHub releases
cd "$ROOT/dist"
tar -czf crap4swift-macos-arm64.tar.gz crap4swift/

# Show result
echo ""
echo "Distribution:"
ls -lh "$DIST/crap4swift"
echo ""
echo "Tarball:"
ls -lh "$TARBALL"
