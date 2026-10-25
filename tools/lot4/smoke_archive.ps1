param(
  [Parameter(Mandatory=$true)][string]$Archive,
  [string]$DiagnosticsDirectory = ''
)
$ErrorActionPreference = 'Stop'
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('IndeX-portable-' + [Guid]::NewGuid().ToString('N'))
if (-not $DiagnosticsDirectory) {
  $DiagnosticsDirectory = Join-Path (Split-Path ([IO.Path]::GetFullPath($Archive)) -Parent) 'diagnostics-smoke'
}
New-Item -ItemType Directory -Force $DiagnosticsDirectory | Out-Null
$DiagnosticsDirectory = [IO.Path]::GetFullPath($DiagnosticsDirectory)
$stdout = Join-Path $DiagnosticsDirectory 'stdout.txt'
$stderr = Join-Path $DiagnosticsDirectory 'stderr.txt'
$report = @{ stage = 'extraction'; success = $false; exit_code = $null; exit_hex = $null }
New-Item -ItemType Directory $temporary | Out-Null
$process = $null
$start = Get-Date
try {
  Expand-Archive -LiteralPath $Archive -DestinationPath $temporary
  $exe = Join-Path $temporary 'IndeX.exe'
  if (-not (Test-Path $exe)) { throw "IndeX.exe absent de l’archive." }
  $report.stage = 'startup'
  $process = Start-Process -FilePath $exe -WorkingDirectory $temporary -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
  $deadline = [DateTime]::UtcNow.AddSeconds(25)
  do {
    Start-Sleep -Milliseconds 250
    $process.Refresh()
    if ($process.HasExited) { throw "Arrêt prématuré de l’application : $($process.ExitCode)" }
  } while ($process.MainWindowHandle -eq 0 -and [DateTime]::UtcNow -lt $deadline)
  if ($process.MainWindowHandle -eq 0) { throw 'Aucune fenêtre Windows détectée.' }
  $report.stage = 'close'
  if (-not $process.CloseMainWindow()) { throw 'Demande de fermeture impossible.' }
  if (-not $process.WaitForExit(15000)) { throw "La fermeture Windows n’a pas abouti." }
  if ($process.ExitCode -ne 0) { throw "Fermeture avec erreur : $($process.ExitCode)" }
  if (Test-Path (Join-Path $temporary 'index-portable.json')) { throw 'Un profil a été créé sans sélection utilisateur.' }
  $report.success = $true
  $report.stage = 'complete'
  Write-Host 'Archive extraite : lancement du premier démarrage et fermeture native vérifiés.'
} catch {
  $report.error = $_.Exception.Message
  # Conserver les erreurs de l'application concernée, sans modifier le verdict.
  try {
    $events = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; Id = @(1000,1001); StartTime = $start } -ErrorAction SilentlyContinue |
      Where-Object { $_.Message -like '*IndeX.exe*' } |
      Select-Object TimeCreated, Id, ProviderName, Message)
    ConvertTo-Json -InputObject $events -Depth 5 | Set-Content (Join-Path $DiagnosticsDirectory 'evenements-windows.json') -Encoding utf8
  } catch { $_.Exception.Message | Set-Content (Join-Path $DiagnosticsDirectory 'evenements-indisponibles.txt') -Encoding utf8 }
  throw
} finally {
  if ($process) {
    $process.Refresh()
    if ($process.HasExited) {
      $report.exit_code = $process.ExitCode
      $bits = [BitConverter]::ToUInt32([BitConverter]::GetBytes([int]$process.ExitCode),0)
      $report.exit_hex = '0x{0:X8}' -f $bits
    } else { Stop-Process -Id $process.Id -Force }
  }
  $report | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $DiagnosticsDirectory 'resultat.json') -Encoding utf8
  Remove-Item $temporary -Recurse -Force
}
