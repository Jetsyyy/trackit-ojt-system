#!/usr/bin/env bash
# Vercel install step: the server's Node packages, plus the Flutter SDK
# (Vercel has no Flutter built in). Keep FLUTTER_VERSION in step with the
# version used on your computer (`flutter --version`).
set -euo pipefail

FLUTTER_VERSION="3.44.9"
FLUTTER_DIR="$HOME/flutter"

npm ci --prefix server

# Flutter's first run downloads the Dart SDK, which needs unzip.
if ! command -v unzip >/dev/null 2>&1; then
  dnf install -y unzip
fi

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

"$FLUTTER_DIR/bin/flutter" config --no-analytics --enable-web
"$FLUTTER_DIR/bin/flutter" --version
