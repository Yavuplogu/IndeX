param([string]$OutputDirectory = '')
$ErrorActionPreference = 'Stop'
$projectDir = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
if (-not $IsWindows -and $env:OS -ne 'Windows_NT') { throw 'Construction Windows requise.' }
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $projectDir 'dist' }
$app = Join-Path $projectDir 'apps/index_windows'
& python (Join-Path $PSScriptRoot 'prepare_assets.py')
if ($LASTEXITCODE -ne 0) { throw 'Préparation des assets échouée.' }
Push-Location $app
try {
  & flutter pub get --enforce-lockfile
  if ($LASTEXITCODE -ne 0) { throw 'Résolution des dépendances échouée.' }
  & flutter build windows --release
  if ($LASTEXITCODE -ne 0) { throw 'Build Windows échoué.' }
  $bundle = Join-Path $app 'build/windows/x64/runner/Release'
  if (-not (Test-Path (Join-Path $bundle 'IndeX.exe'))) { throw 'Exécutable IndeX absent.' }
  # Distribution app-local du runtime Microsoft, sans installateur.
  $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
  if (-not (Test-Path $vswhere)) { throw 'vswhere absent : impossible de vérifier le runtime redistribuable.' }
  $vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  if (-not $vs) { throw 'Visual Studio C++ requis.' }
  $redist = Get-ChildItem (Join-Path $vs 'VC/Redist/MSVC') -Directory | Sort-Object Name -Descending | Select-Object -First 1
  $crt = Get-ChildItem (Join-Path $redist.FullName 'x64') -Directory -Filter 'Microsoft.VC*.CRT' | Select-Object -First 1
  if (-not $crt) { throw 'Runtime Microsoft redistribuable x64 introuvable.' }
  Copy-Item (Join-Path $crt.FullName '*.dll') $bundle
  foreach ($required in @('vcruntime140.dll','msvcp140.dll')) {
    if (-not (Test-Path (Join-Path $bundle $required))) { throw "Runtime incomplet : $required" }
  }
  $licences = Join-Path $bundle 'licences'
  New-Item -ItemType Directory -Force $licences | Out-Null
  $config = Get-Content (Join-Path $app '.dart_tool/package_config.json') -Raw | ConvertFrom-Json
  foreach ($package in $config.packages) {
    $base = if ($package.rootUri -like 'file:*') { ([Uri]$package.rootUri).LocalPath } else { [IO.Path]::GetFullPath((Join-Path (Join-Path $app '.dart_tool') $package.rootUri)) }
    foreach ($name in @('LICENSE','LICENCE','LICENSE.txt')) {
      $path = Join-Path $base $name
      if (Test-Path $path) { Copy-Item $path (Join-Path $licences "$($package.name)-LICENSE.txt"); break }
    }
  }
  Get-ChildItem $redist.FullName -File | Where-Object { $_.Name -match 'license|licence|eula' } | ForEach-Object { Copy-Item $_.FullName (Join-Path $licences ('Microsoft-' + $_.Name)) }
  'Runtime Microsoft Visual C++ x64 app-local. Redistribution sous les conditions de licence Visual Studio/Microsoft Visual C++. UCRT fourni par Windows 10/11. Voir https://learn.microsoft.com/cpp/windows/redistributing-visual-cpp-files' | Set-Content (Join-Path $licences 'Microsoft-runtime.txt') -Encoding utf8
  Copy-Item (Join-Path $projectDir 'docs/lot4/UTILISATION_WINDOWS.md') (Join-Path $bundle 'LISEZ-MOI.md')
  if (Get-ChildItem $bundle -Recurse -File -Filter '*.mp3') { throw 'Un MP3 serait embarqué : distribution refusée.' }
  if (Get-ChildItem $bundle -Recurse -File | Where-Object { $_.Name -eq 'index-portable.json' -or $_.Name -eq 'index-utilisateur.sqlite' }) { throw 'Données personnelles interdites dans la distribution.' }
  $manifest = @()
  Get-ChildItem $bundle -Recurse -File | Where-Object { $_.Name -ne 'manifest-fichiers.json' } | ForEach-Object {
    $manifest += [PSCustomObject]@{ path = [IO.Path]::GetRelativePath($bundle,$_.FullName); bytes = $_.Length; sha256 = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower() }
  }
  $manifest | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $bundle 'manifest-fichiers.json') -Encoding utf8
  New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
  $archive = Join-Path $OutputDirectory 'IndeX_0.4.0_windows_x64_portable.zip'
  if (Test-Path $archive) { throw "Archive existante : $archive. Choisir un autre dossier de sortie." }
  Compress-Archive -Path (Join-Path $bundle '*') -DestinationPath $archive
  (Get-FileHash $archive -Algorithm SHA256).Hash.ToLower() | Set-Content "$archive.sha256" -Encoding ascii
  Write-Host "Archive portable créée : $archive"
} finally { Pop-Location }
