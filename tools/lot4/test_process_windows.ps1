$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'process_windows.ps1')
$root = Join-Path ([IO.Path]::GetTempPath()) ('index-process-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $root | Out-Null
$executable = (Get-Process -Id $PID).Path
try {
  $codes = @(0, 7)
  if ($IsWindows) { $codes += -1073740771 }
  foreach ($expected in $codes) {
    $gate = Join-Path $root "exit-$expected"
    $escaped = $gate.Replace("'", "''")
    $script = "while (-not (Test-Path -LiteralPath '$escaped')) { Start-Sleep -Milliseconds 25 }; exit $expected"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
    $started = $null
    $tracked = $null
    try {
      $started = Start-Process -FilePath $executable -ArgumentList @('-NoProfile','-NonInteractive','-EncodedCommand',$encoded) -PassThru
      $tracked = Get-TrackedProcess -ProcessId $started.Id
      # Only the independently retrieved Process object now retains a handle.
      $started.Dispose()
      $started = $null
      $refused = $false
      try { Get-RequiredExitCode -Process $tracked | Out-Null } catch { $refused = $true }
      if (-not $refused) { throw 'Un processus actif ne doit pas être validé.' }
      'terminer' | Set-Content -LiteralPath $gate
      if (-not $tracked.WaitForExit(10000)) { throw 'Le processus témoin ne termine pas.' }
      $tracked.Refresh()
      $actual = Get-RequiredExitCode -Process $tracked
      if ($actual -ne $expected) { throw "Code de sortie incorrect : attendu $expected, obtenu $actual" }
    } finally {
      if ($tracked) {
        if (-not $tracked.HasExited) { $tracked.Kill(); $tracked.WaitForExit(5000) | Out-Null }
        $tracked.Dispose()
      }
      if ($started) {
        if (-not $started.HasExited) { $started.Kill(); $started.WaitForExit(5000) | Out-Null }
        $started.Dispose()
      }
    }
  }
  $refused = $false
  try { Get-RequiredExitCode -Process ([PSCustomObject]@{ HasExited = $true; ExitCode = $null }) | Out-Null }
  catch { $refused = $true }
  if (-not $refused) { throw 'Un code manquant ne doit jamais devenir un succès.' }
  Write-Host "Surveillance processus : handle indépendant, codes $($codes -join '/'), processus actif et code absent validés."
} finally { Remove-Item $root -Recurse -Force }
