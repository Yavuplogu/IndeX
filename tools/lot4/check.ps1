$ErrorActionPreference = 'Stop'
$projectDir = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
function Run-Checked([string]$program, [string[]]$arguments) {
  & $program @arguments
  if ($LASTEXITCODE -ne 0) { throw "$program a échoué ($LASTEXITCODE)." }
}
Push-Location $projectDir
try {
  $env:CI = 'true'
  $env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
  $env:ANALYZER_STATE_LOCATION_OVERRIDE = Join-Path $projectDir '.dart_tool/analyzer-state'
  Run-Checked python @('-m','unittest','discover','-s','tools/versioning','-p','test_*.py')
  Run-Checked dart @('pub','get','--enforce-lockfile')
  Run-Checked dart @('format','--output=none','--set-exit-if-changed','lib','test','bin')
  Run-Checked dart @('analyze','--fatal-infos')
  Run-Checked dart @('test','--reporter','expanded','--concurrency=1')
  Run-Checked python @('tools/lot4/prepare_assets.py')
  Set-Location (Join-Path $projectDir 'apps/index_windows')
  $env:ANALYZER_STATE_LOCATION_OVERRIDE = Join-Path (Get-Location) '.dart_tool/analyzer-state'
  Run-Checked flutter @('pub','get','--enforce-lockfile')
  Run-Checked dart @('format','--output=none','--set-exit-if-changed','lib','test','integration_test')
  Run-Checked flutter @('analyze','--no-pub','--fatal-infos')
  Run-Checked flutter @('test','--no-pub','--reporter','expanded','--concurrency=1')
  $fixture = Join-Path $projectDir 'MP3_Files'
  Run-Checked flutter @('test','integration_test/windows_smoke_test.dart','-d','windows',"--dart-define=INDEX_TEST_MP3_DIR=$fixture")
} finally { Pop-Location }
