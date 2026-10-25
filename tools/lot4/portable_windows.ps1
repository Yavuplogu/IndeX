# Assemble without changing the Flutter bundle's internal DLL/data layout.
function New-PortableLayout {
  param([Parameter(Mandatory=$true)][string]$BundleDirectory,
    [Parameter(Mandatory=$true)][string]$Launcher,
    [Parameter(Mandatory=$true)][string]$Destination)
  if (-not (Test-Path -LiteralPath (Join-Path $BundleDirectory 'IndeX.exe') -PathType Leaf)) { throw 'Application compilée absente.' }
  if (-not (Test-Path -LiteralPath $Launcher -PathType Leaf)) { throw 'Lanceur portable absent.' }
  if (Test-Path -LiteralPath $Destination) { throw 'La destination de préparation doit être nouvelle.' }
  if (Get-ChildItem $BundleDirectory -Recurse -File | Where-Object { $_.Extension -eq '.mp3' -or $_.Name -eq 'index-portable.json' -or $_.Name -like 'index-utilisateur.sqlite*' }) { throw 'Audio ou données personnelles interdits dans la distribution.' }
  $application = Join-Path $Destination 'application'
  $documentation = Join-Path $Destination 'documentation'
  New-Item -ItemType Directory -Force $application, $documentation | Out-Null
  Copy-Item (Join-Path $BundleDirectory '*') $application -Recurse
  Copy-Item -LiteralPath $Launcher -Destination (Join-Path $Destination 'IndeX.exe')
  return [PSCustomObject]@{ Root = $Destination; Application = $application; Documentation = $documentation }
}
