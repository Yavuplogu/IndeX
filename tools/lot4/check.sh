#!/usr/bin/env bash
set -euo pipefail
project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
bash "$project_dir/tools/lot3/check.sh"
python3 "$project_dir/tools/lot4/prepare_assets.py"
cd "$project_dir/apps/index_windows"
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true
export ANALYZER_STATE_LOCATION_OVERRIDE="$PWD/.dart_tool/analyzer-state"
mkdir -p "$ANALYZER_STATE_LOCATION_OVERRIDE"
flutter pub get --offline --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --no-pub --fatal-infos
flutter test --no-pub --reporter expanded --concurrency=1
