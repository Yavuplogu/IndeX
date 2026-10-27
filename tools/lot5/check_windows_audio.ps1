$ErrorActionPreference = 'Stop'
$projectDir = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $projectDir
try {
  python tools/lot4/prepare_assets.py
  if ($LASTEXITCODE -ne 0) { throw 'Préparation du catalogue échouée.' }
  $fixture = Join-Path $projectDir 'MP3_Files'
  Set-Location (Join-Path $projectDir 'apps/index_windows')
  flutter test integration_test/windows_smoke_test.dart -d windows "--dart-define=INDEX_TEST_MP3_DIR=$fixture" --dart-define=INDEX_TEST_AUDIO=true
  if ($LASTEXITCODE -ne 0) { throw 'Recette audio native échouée.' }
} finally { Pop-Location }
