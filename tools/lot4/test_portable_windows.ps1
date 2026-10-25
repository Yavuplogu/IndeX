$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'portable_windows.ps1')
$root = Join-Path ([IO.Path]::GetTempPath()) ('index-layout-' + [Guid]::NewGuid().ToString('N'))
try {
  $bundle = Join-Path $root 'build with spaces'
  New-Item -ItemType Directory -Force (Join-Path $bundle 'data/flutter_assets') | Out-Null
  foreach ($name in @('IndeX.exe', 'flutter_windows.dll', 'plugin.dll', 'data/flutter_assets/catalogue.sqlite')) {
    'fixture, jamais exécutée' | Set-Content (Join-Path $bundle $name)
  }
  $launcher = Join-Path $root 'launcher.exe'
  'lanceur fixture' | Set-Content $launcher
  $destination = Join-Path $root 'IndeX'
  $layout = New-PortableLayout -BundleDirectory $bundle -Launcher $launcher -Destination $destination
  $files = @(Get-ChildItem $destination -File)
  if ($files.Count -ne 1 -or $files[0].Name -ne 'IndeX.exe') { throw 'Racine portable incorrecte.' }
  if (-not (Test-Path (Join-Path $layout.Application 'data/flutter_assets/catalogue.sqlite'))) { throw 'Ressources Flutter déplacées incorrectement.' }
  if ((Get-Content (Join-Path $destination 'IndeX.exe')) -ne 'lanceur fixture') { throw 'Le fichier visible doit être le lanceur.' }
  $zip = Join-Path $root 'portable.zip'
  Compress-Archive -Path $destination -DestinationPath $zip
  $read = [IO.Compression.ZipFile]::OpenRead($zip)
  try {
    $entries = @($read.Entries | ForEach-Object { $_.FullName.Replace('\','/') })
    if ($entries -notcontains 'IndeX/IndeX.exe' -or $entries -notcontains 'IndeX/application/IndeX.exe') { throw 'Arborescence ZIP incorrecte.' }
  } finally { $read.Dispose() }
  foreach ($forbidden in @('audio.mp3','index-portable.json','index-utilisateur.sqlite-wal')) {
    $file = Join-Path $bundle $forbidden
    'interdit' | Set-Content $file
    $refused = $false
    try { New-PortableLayout -BundleDirectory $bundle -Launcher $launcher -Destination (Join-Path $root ('rejected-' + $forbidden)) | Out-Null }
    catch { $refused = $true }
    if (-not $refused) { throw "Fichier interdit accepté : $forbidden" }
    Remove-Item $file
  }
  Write-Host 'Archive portable : racine unique, sous-dossiers Flutter, ZIP et exclusion des données validés.'
} finally { Remove-Item $root -Recurse -Force }
