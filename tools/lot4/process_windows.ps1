# Get-Process alone can lose ExitCode after a Windows process has exited.
# Opening Handle while the process is alive retains its kernel object until Dispose.
function Get-TrackedProcess {
  param([Parameter(Mandatory=$true)][int]$ProcessId)
  $tracked = Get-Process -Id $ProcessId -ErrorAction Stop
  try {
    $null = $tracked.Handle
    return $tracked
  } catch {
    $tracked.Dispose()
    throw
  }
}

function Get-RequiredExitCode {
  param([Parameter(Mandatory=$true)]$Process)
  if (-not $Process.HasExited) { throw 'Le processus est encore actif.' }
  $code = $Process.ExitCode
  if ($null -eq $code) { throw 'Code de sortie indisponible : fermeture non validée.' }
  return [int]$code
}
