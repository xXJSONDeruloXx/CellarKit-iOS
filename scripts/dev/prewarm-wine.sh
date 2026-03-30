#!/usr/bin/env bash
#
# prewarm-wine.sh — Start (or confirm) a wineserver for CellarKit E2E tests.
#
# WHY THIS IS NEEDED
# ==================
# CrossOver Wine uses Mach port IPC for wineserver ↔ client communication.
# The iOS Simulator creates a separate launchd bootstrap namespace; wine64
# spawned inside the sim process cannot register or look up Mach services
# in the host bootstrap.
#
# A wineserver started from the macOS terminal has the HOST bootstrap port
# and CAN register its Mach service.  The in-sim wine64 client then finds
# the running server and connects successfully.
#
# USAGE
#   ./scripts/dev/prewarm-wine.sh         # start & keep alive for 120 s
#   ./scripts/dev/prewarm-wine.sh --kill  # kill any running wineserver
#
# For CI, call this script in the pre-test phase.

set -euo pipefail

WINEPREFIX_PATH="/private/tmp/cellarkit-wine/shared"
PERSIST_SECONDS=120
WINE64=""

# Locate wine64
for candidate in /opt/homebrew/bin/wine64 /usr/local/bin/wine64; do
  if [[ -x "$candidate" ]]; then
    WINE64="$candidate"
    break
  fi
done

if [[ -z "$WINE64" ]]; then
  echo "❌ wine64 not found. Install with:" >&2
  echo "   brew install --cask gcenx/wine/wine-crossover" >&2
  exit 1
fi

WINESERVER="$(dirname "$WINE64")/wineserver"
if [[ ! -x "$WINESERVER" ]]; then
  echo "❌ wineserver not found at $WINESERVER" >&2
  exit 1
fi

# Handle --kill
if [[ "${1:-}" == "--kill" ]]; then
  echo "🛑 Stopping wineserver for prefix $WINEPREFIX_PATH"
  WINEPREFIX="$WINEPREFIX_PATH" "$WINESERVER" -k 2>/dev/null || true
  pkill -f "wineserver" 2>/dev/null || true
  echo "✅ Done"
  exit 0
fi

# Ensure prefix directory exists
mkdir -p "$WINEPREFIX_PATH"

echo "🍷 Starting wineserver for CellarKit E2E tests"
echo "   WINEPREFIX: $WINEPREFIX_PATH"
echo "   Persistent: ${PERSIST_SECONDS}s after last client"

# Start wineserver persistently
WINEPREFIX="$WINEPREFIX_PATH" \
WINEDEBUG=-all \
HOME="$HOME" \
TMPDIR=/private/tmp \
  "$WINESERVER" -p "$PERSIST_SECONDS"

sleep 0.8

# Verify it's running
if pgrep -q wineserver; then
  echo "✅ wineserver is running (PID $(pgrep wineserver | head -1))"
else
  echo "⚠️  wineserver didn't start; trying wineboot --init as fallback..."
  WINEPREFIX="$WINEPREFIX_PATH" \
  WINEDEBUG=-all \
  WINEDLLOVERRIDES="winemenubuilder.exe=d;mscoree,mshtml=" \
  HOME="$HOME" \
    "$WINE64" wineboot --init
  echo "✅ Prefix initialised (wineserver may be running transiently)"
fi

echo ""
echo "Now run your Wine E2E tests:"
echo "   xcodebuild test ... -only-testing:CellarAppUITests/CellarWine2Test"
