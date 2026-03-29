#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_DIR="$ROOT/App/CellarApp"

cd "$PROJECT_DIR"
xcodegen generate

echo "Generated $PROJECT_DIR/CellarApp.xcodeproj"
