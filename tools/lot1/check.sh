#!/usr/bin/env bash
set -euo pipefail
project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$project_dir"
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
export ANALYZER_STATE_LOCATION_OVERRIDE="$project_dir/.dart_tool/analyzer-state"
mkdir -p "$ANALYZER_STATE_LOCATION_OVERRIDE"
dart pub get --offline --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test bin
dart analyze --cache="$project_dir/.dart_tool/analyzer-cache" --fatal-infos
dart test --reporter expanded --concurrency=1
