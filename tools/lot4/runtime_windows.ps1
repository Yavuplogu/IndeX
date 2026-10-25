# Recherche du runtime app-local ; aucune dépendance au registre ou à Windows pour les tests.
function Find-VisualCppRuntime {
  param([Parameter(Mandatory=$true)][string]$VisualStudioDirectory)
  $root = Join-Path $VisualStudioDirectory 'VC/Redist/MSVC'
  if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    throw "Dossier des redistribuables Microsoft introuvable : $root"
  }
  # Les dossiers v143 peuvent contenir des métadonnées, pas le runtime.
  # Classer les vraies versions numériquement, et ne retenir qu'un CRT x64 complet.
  $versions = @(Get-ChildItem -LiteralPath $root -Directory | Sort-Object -Property @{
    Expression = {
      if ($_.Name -match '^\d+(\.\d+){1,3}$') { [version]$_.Name }
      else { [version]'0.0' }
    }
  } -Descending)
  $required = @('vcruntime140.dll', 'vcruntime140_1.dll', 'msvcp140.dll')
  foreach ($version in $versions) {
    $x64 = Join-Path $version.FullName 'x64'
    if (-not (Test-Path -LiteralPath $x64 -PathType Container)) { continue }
    foreach ($crt in @(Get-ChildItem -LiteralPath $x64 -Directory -Filter 'Microsoft.VC*.CRT' | Sort-Object Name -Descending)) {
      $missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $crt.FullName $_) -PathType Leaf) })
      if ($missing.Count -eq 0) {
        return [PSCustomObject]@{
          RedistDirectory = $version.FullName
          CrtDirectory = $crt.FullName
          Version = $version.Name
        }
      }
    }
  }
  $checked = ($versions | ForEach-Object { $_.Name }) -join ', '
  throw "Aucun runtime Microsoft C++ x64 complet trouvé sous $root. Dossiers contrôlés : $checked. DLL requises : $($required -join ', ')."
}
