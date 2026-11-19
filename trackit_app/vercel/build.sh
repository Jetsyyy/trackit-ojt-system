#!/usr/bin/env bash
# Vercel build step: the Flutter web app, talking to the API on the same
# site (an empty API_BASE_URL means "this page's own address").
set -euo pipefail

FLUTTER="$HOME/flutter/bin/flutter"

"$FLUTTER" pub get
"$FLUTTER" build web --release --dart-define=API_BASE_URL=
