#!/usr/bin/env bash
set -euo pipefail
project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
python3 "$project_dir/tools/lot4/prepare_assets.py"
cd "$project_dir/apps/index_windows"
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true
flutter pub get --enforce-lockfile
flutter build apk --debug --target-platform android-arm64 --no-pub
