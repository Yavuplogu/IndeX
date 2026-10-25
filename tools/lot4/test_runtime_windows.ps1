# Tests du résolveur, sans Visual Studio, sans Pester ni vraie DLL exécutée.
$ErrorActionPreference = 'Stop'
# Détecter aussi les erreurs de syntaxe des étapes ultérieures avant compilation.
foreach ($script in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1') {
  $tokens = $null
  $parseErrors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
  if ($parseErrors.Count -gt 0) {
    throw "Syntaxe PowerShell invalide dans $($script.Name) : $($parseErrors.Message -join '; ')"
  }
}
. (Join-Path $PSScriptRoot 'runtime_windows.ps1')
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('index-crt-test-' + [Guid]::NewGuid().ToString('N'))
$fakeVs = Join-Path $temporary 'Visual Studio'
$root = Join-Path $fakeVs 'VC/Redist/MSVC'
function Add-FakeRuntime([string]$Version, [string]$Architecture = 'x64', [string[]]$Dlls = @('vcruntime140.dll','vcruntime140_1.dll','msvcp140.dll')) {
  $directory = Join-Path $root "$Version/$Architecture/Microsoft.VC143.CRT"
  New-Item -ItemType Directory -Path $directory -Force | Out-Null
  foreach ($dll in $Dlls) { 'fixture de sélection uniquement' | Set-Content (Join-Path $directory $dll) }
  return $directory
}
function Assert-Equal($Actual, $Expected, [string]$Reason) {
  if ($Actual -ne $Expected) { throw "$Reason : attendu $Expected, obtenu $Actual" }
}
try {
  New-Item -ItemType Directory -Path (Join-Path $root 'v143') -Force | Out-Null
  $old = Add-FakeRuntime '14.9.0'
  $expected = Add-FakeRuntime '14.10.0'
  $result = Find-VisualCppRuntime -VisualStudioDirectory $fakeVs
  Assert-Equal $result.CrtDirectory $expected 'Tri numérique et dossier v143 sans x64'
  Assert-Equal $result.Version '14.10.0' 'Version sélectionnée'
  $null = Add-FakeRuntime '14.11.0' 'x86'
  $null = Add-FakeRuntime '14.12.0' 'x64' @('vcruntime140.dll')
  $result = Find-VisualCppRuntime -VisualStudioDirectory $fakeVs
  Assert-Equal $result.CrtDirectory $expected 'Ignorer x86 et CRT incomplet'
  $newest = Add-FakeRuntime '14.13.0'
  Assert-Equal (Find-VisualCppRuntime -VisualStudioDirectory $fakeVs).CrtDirectory $newest 'Choisir le CRT complet le plus récent'
  Remove-Item (Join-Path $root '14.13.0') -Recurse -Force
  Remove-Item (Join-Path $root '14.10.0') -Recurse -Force
  Assert-Equal (Find-VisualCppRuntime -VisualStudioDirectory $fakeVs).CrtDirectory $old 'Repli sur une version complète plus ancienne'
  Remove-Item (Join-Path $root '14.9.0') -Recurse -Force
  $failed = $false
  try { $null = Find-VisualCppRuntime -VisualStudioDirectory $fakeVs }
  catch { $failed = $_.Exception.Message -like '*Aucun runtime*complet*' }
  Assert-Equal $failed $true 'Refuser un ensemble incomplet'
  $failed = $false
  try { $null = Find-VisualCppRuntime -VisualStudioDirectory (Join-Path $temporary 'absent') }
  catch { $failed = $_.Exception.Message -like '*introuvable*' }
  Assert-Equal $failed $true 'Dossier Visual Studio absent'
  Write-Host 'Résolveur CRT : versions numériques, v143, x86, DLL manquantes, repli et erreurs validés.'
} finally { if (Test-Path $temporary) { Remove-Item $temporary -Recurse -Force } }
