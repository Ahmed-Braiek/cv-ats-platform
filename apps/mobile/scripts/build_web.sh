#!/usr/bin/env bash
set -euo pipefail

# Vercel build: install a pinned Flutter SDK if the runner does not provide one.
# Flutter stable 3.38.3; update only after verifying the Android and web CI.
FLUTTER_VERSION="3.38.3"
if command -v flutter >/dev/null 2>&1; then
  FLUTTER_BIN="$(command -v flutter)"
else
  FLUTTER_DIR="${TMPDIR:-/tmp}/cv-ats-flutter"
  if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
    git clone --depth 1 --branch "$FLUTTER_VERSION" --single-branch       https://github.com/flutter/flutter.git "$FLUTTER_DIR"
  fi
  FLUTTER_BIN="$FLUTTER_DIR/bin/flutter"
fi

"$FLUTTER_BIN" --version
"$FLUTTER_BIN" config --enable-web
"$FLUTTER_BIN" pub get

# Only PUBLIC environment values are compiled into the browser build.
"$FLUTTER_BIN" build web --release   --dart-define="SUPABASE_URL=${SUPABASE_URL:-https://uqtyxhkevnyjvhwdgkyh.supabase.co}"   --dart-define="SUPABASE_PUBLISHABLE_KEY=${SUPABASE_PUBLISHABLE_KEY:-}"   --dart-define="CV_ATS_API_URL=${CV_ATS_API_URL:-}"   --dart-define="CV_ATS_ANALYSIS_ENABLED=${CV_ATS_ANALYSIS_ENABLED:-false}"

test -s build/web/index.html
echo "Flutter Web release assets ready."
