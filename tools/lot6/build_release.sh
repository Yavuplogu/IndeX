#!/usr/bin/env bash
# Les secrets sont lus par Gradle dans l'environnement, jamais sur sa ligne de commande.
set -euo pipefail
project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
for setting in INDEX_ANDROID_KEYSTORE INDEX_ANDROID_STORE_PASSWORD INDEX_ANDROID_KEY_ALIAS INDEX_ANDROID_KEY_PASSWORD INDEX_ANDROID_CERT_SHA256 INDEX_VERSION INDEX_BUILD_NAME INDEX_BUILD_NUMBER ANDROID_HOME; do
  if [[ -z "${!setting:-}" ]]; then
    printf 'Configuration release absente : %s\n' "$setting" >&2
    exit 1
  fi
done
if [[ ! -f "$INDEX_ANDROID_KEYSTORE" ]]; then
  printf 'Keystore release introuvable.\n' >&2
  exit 1
fi
python3 "$project_dir/tools/lot4/prepare_assets.py"
cd "$project_dir/apps/index_windows"
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true
flutter pub get --enforce-lockfile
# Flutter 3.47.7 ne régénère pas le registrant natif avec --no-pub : il garderait
# integration_test du diagnostic alors que Gradle l’exclut de la release.
# Le pub get verrouillé ci-dessus prépare les dépendances ; --pub (défaut)
# permet ensuite à Flutter de régénérer le registrant propre au mode release.
flutter build apk --release --target-platform android-arm64 \
  "--build-name=$INDEX_BUILD_NAME" "--build-number=$INDEX_BUILD_NUMBER" \
  "--dart-define=INDEX_VERSION=$INDEX_VERSION"
python3 "$project_dir/tools/lot6/inspect_apk.py" build/app/outputs/flutter-apk/app-release.apk \
  --release --sdk-tools "$ANDROID_HOME/build-tools/36.0.0" \
  --certificate-sha256 "$INDEX_ANDROID_CERT_SHA256" \
  --build-name "$INDEX_BUILD_NAME" --build-number "$INDEX_BUILD_NUMBER"
