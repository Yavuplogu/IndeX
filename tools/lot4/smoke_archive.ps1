param([Parameter(Mandatory=$true)][string]$Archive)
$ErrorActionPreference = 'Stop'
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('IndeX-portable-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $temporary | Out-Null
$process = $null
try {
  Expand-Archive -LiteralPath $Archive -DestinationPath $temporary
  $exe = Join-Path $temporary 'IndeX.exe'
  if (-not (Test-Path $exe)) { throw 'IndeX.exe absent de l’archive.' }
  $process = Start-Process -FilePath $exe -WorkingDirectory $temporary -PassThru
  $deadline = [DateTime]::UtcNow.AddSeconds(25)
  do {
    Start-Sleep -Milliseconds 250
    $process.Refresh()
    if ($process.HasExited) { throw "Arrêt prématuré de l’application : $($process.ExitCode)" }
  } while ($process.MainWindowHandle -eq 0 -and [DateTime]::UtcNow -lt $deadline)
  if ($process.MainWindowHandle -eq 0) { throw 'Aucune fenêtre Windows détectée.' }
  if (-not $process.CloseMainWindow()) { throw 'Demande de fermeture impossible.' }
  if (-not $process.WaitForExit(15000)) { throw 'La fermeture Windows n’a pas abouti.' }
  if ($process.ExitCode -ne 0) { throw "Fermeture avec erreur : $($process.ExitCode)" }
  if (Test-Path (Join-Path $temporary 'index-portable.json')) { throw 'Un profil a été créé sans sélection utilisateur.' }
  Write-Host 'Archive extraite : lancement du premier démarrage et fermeture native vérifiés.'
} finally {
  if ($process -and -not $process.HasExited) { Stop-Process -Id $process.Id -Force }
  Remove-Item $temporary -Recurse -Force
}
