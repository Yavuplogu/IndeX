#!/usr/bin/env bash
set -euo pipefail
project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
python3 "$project_dir/tools/lot4/prepare_assets.py"
cd "$project_dir/apps/index_windows"
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true
flutter pub get --enforce-lockfile
# Un build intermédiaire local ne réserve pas de numéro de distribution.
# La CI fournit les trois valeurs issues du compteur partagé Windows/Android.
version_args=()
if [[ -n "${INDEX_VERSION:-}${INDEX_BUILD_NAME:-}${INDEX_BUILD_NUMBER:-}" ]]; then
  : "${INDEX_VERSION:?Version publique requise}"
  : "${INDEX_BUILD_NAME:?Version Flutter requise}"
  : "${INDEX_BUILD_NUMBER:?Code de build requis}"
  version_args=("--build-name=$INDEX_BUILD_NAME" "--build-number=$INDEX_BUILD_NUMBER" "--dart-define=INDEX_VERSION=$INDEX_VERSION")
fi
flutter build apk --debug --target-platform android-arm64 --no-pub "${version_args[@]}"
python3 "$project_dir/tools/lot6/inspect_apk.py" build/app/outputs/flutter-apk/app-debug.apk
