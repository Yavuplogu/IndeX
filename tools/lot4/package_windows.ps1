param([string]$OutputDirectory = '')
$ErrorActionPreference = 'Stop'
$projectDir = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
if (-not $IsWindows -and $env:OS -ne 'Windows_NT') { throw 'Construction Windows requise.' }
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $projectDir 'dist' }
$app = Join-Path $projectDir 'apps/index_windows'
# Chaque invocation locale réserve un numéro ; la CI le réserve avant les tests.
if (-not $env:INDEX_VERSION) {
  $reserved = & python (Join-Path $projectDir 'tools/versioning/reserve.py')
  if ($LASTEXITCODE -ne 0) { throw 'Réservation de version échouée.' }
  $version = $reserved | ConvertFrom-Json
} else {
  $version = [PSCustomObject]@{ display = $env:INDEX_VERSION; build_name = $env:INDEX_BUILD_NAME; build_number = $env:INDEX_BUILD_NUMBER }
}
if ($version.display -notmatch '^[01]\.\d+\.\d+$' -or -not $version.build_name -or -not $version.build_number) { throw 'Version de build invalide.' }
& python (Join-Path $PSScriptRoot 'prepare_assets.py')
if ($LASTEXITCODE -ne 0) { throw 'Préparation des assets échouée.' }
Push-Location $app
try {
  & flutter pub get --enforce-lockfile
  if ($LASTEXITCODE -ne 0) { throw 'Résolution des dépendances échouée.' }
  & flutter build windows --release "--build-name=$($version.build_name)" "--build-number=$($version.build_number)" "--dart-define=INDEX_VERSION=$($version.display)"
  if ($LASTEXITCODE -ne 0) { throw 'Build Windows échoué.' }
  $built = Join-Path $app 'build/windows/x64/runner/Release'
  if (-not (Test-Path (Join-Path $built 'just_audio_windows_plugin.dll'))) { throw 'Plugin audio WinRT absent du bundle.' }
  $launcher = Join-Path $app 'build/windows/x64/launcher/Release/IndeX.exe'
  if (-not (Test-Path $launcher)) { throw 'Lanceur portable absent.' }
  $stage = Join-Path ([IO.Path]::GetTempPath()) ('index-package-' + [Guid]::NewGuid().ToString('N'))
  $portable = Join-Path $stage 'IndeX'
  . (Join-Path $PSScriptRoot 'portable_windows.ps1')
  $layout = New-PortableLayout -BundleDirectory $built -Launcher $launcher -Destination $portable
  $bundle = $layout.Application
  $documentation = $layout.Documentation
  # Distribution app-local du runtime Microsoft, sans installateur.
  $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
  if (-not (Test-Path $vswhere)) { throw 'vswhere absent : impossible de vérifier le runtime redistribuable.' }
  $vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  if (-not $vs) { throw 'Visual Studio C++ requis.' }
  . (Join-Path $PSScriptRoot 'runtime_windows.ps1')
  $runtime = Find-VisualCppRuntime -VisualStudioDirectory $vs
  Write-Host "Runtime Microsoft sélectionné : $($runtime.CrtDirectory)"
  Copy-Item (Join-Path $runtime.CrtDirectory '*.dll') $bundle
  foreach ($required in @('vcruntime140.dll','vcruntime140_1.dll','msvcp140.dll')) {
    if (-not (Test-Path (Join-Path $bundle $required))) { throw "Runtime incomplet : $required" }
  }
  Copy-Item (Join-Path $projectDir 'LICENSE') (Join-Path $documentation 'LICENSE')
  Copy-Item (Join-Path $projectDir 'LICENSE_SCOPE.md') (Join-Path $documentation 'LICENSE_SCOPE.md')
  $licences = Join-Path $documentation 'licences'
  New-Item -ItemType Directory -Force $licences | Out-Null
  Copy-Item (Join-Path $app 'assets/icons/LICENSE-octicons.txt') (Join-Path $licences 'primer-octicons-LICENSE.txt')
  $config = Get-Content (Join-Path $app '.dart_tool/package_config.json') -Raw | ConvertFrom-Json
  foreach ($package in $config.packages) {
    $base = if ($package.rootUri -like 'file:*') { ([Uri]$package.rootUri).LocalPath } else { [IO.Path]::GetFullPath((Join-Path (Join-Path $app '.dart_tool') $package.rootUri)) }
    foreach ($name in @('LICENSE','LICENCE','LICENSE.txt')) {
      $path = Join-Path $base $name
      if (Test-Path $path) { Copy-Item $path (Join-Path $licences "$($package.name)-LICENSE.txt"); break }
    }
  }
  Get-ChildItem $runtime.RedistDirectory -File | Where-Object { $_.Name -match 'license|licence|eula' } | ForEach-Object { Copy-Item $_.FullName (Join-Path $licences ('Microsoft-' + $_.Name)) }
  'Runtime Microsoft Visual C++ x64 app-local. Redistribution sous les conditions de licence Visual Studio/Microsoft Visual C++. UCRT fourni par Windows 10/11. Voir https://learn.microsoft.com/cpp/windows/redistributing-visual-cpp-files' | Set-Content (Join-Path $licences 'Microsoft-runtime.txt') -Encoding utf8
  if ($env:INDEX_SOURCE_COMMIT) { $version | Add-Member -NotePropertyName source_commit -NotePropertyValue $env:INDEX_SOURCE_COMMIT -Force }
  if ($env:INDEX_COUNTER_COMMIT) { $version | Add-Member -NotePropertyName counter_commit -NotePropertyValue $env:INDEX_COUNTER_COMMIT -Force }
  $version | ConvertTo-Json | Set-Content (Join-Path $documentation 'version.json') -Encoding utf8
  Copy-Item (Join-Path $projectDir 'docs/lot4/UTILISATION_WINDOWS.md') (Join-Path $documentation 'LISEZ-MOI.md')
  if (Get-ChildItem $portable -Recurse -File -Filter '*.mp3') { throw 'Un MP3 serait embarqué : distribution refusée.' }
  if (Get-ChildItem $portable -Recurse -File | Where-Object { $_.Name -eq 'index-portable.json' -or $_.Name -eq 'index-utilisateur.sqlite' }) { throw 'Données personnelles interdites dans la distribution.' }
  $manifest = @()
  Get-ChildItem $portable -Recurse -File | Where-Object { $_.Name -ne 'manifest-fichiers.json' } | ForEach-Object {
    $manifest += [PSCustomObject]@{ path = [IO.Path]::GetRelativePath($portable,$_.FullName); bytes = $_.Length; sha256 = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower() }
  }
  $manifest | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $documentation 'manifest-fichiers.json') -Encoding utf8
  New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
  $archive = Join-Path $OutputDirectory "IndeX_$($version.display)_windows_x64_portable.zip"
  if (Test-Path $archive) { throw "Archive existante : $archive. Choisir un autre dossier de sortie." }
  $rootFiles = @(Get-ChildItem $portable -File)
  if ($rootFiles.Count -ne 1 -or $rootFiles[0].Name -ne 'IndeX.exe') { throw 'La racine doit contenir uniquement IndeX.exe et des dossiers.' }
  Compress-Archive -Path $portable -DestinationPath $archive
  (Get-FileHash $archive -Algorithm SHA256).Hash.ToLower() | Set-Content "$archive.sha256" -Encoding ascii
  Write-Host "Archive portable créée : $archive"
} finally {
  Pop-Location
  if ($stage -and (Test-Path $stage)) { Remove-Item $stage -Recurse -Force }
}
