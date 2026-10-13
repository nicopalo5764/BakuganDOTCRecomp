param([Parameter(Mandatory=$true)][string]$GameRoot)
. "$PSScriptRoot/Common.ps1"
$verified = Assert-GameCopy $GameRoot
Write-Host "Compatible executable and expected data sizes: $verified"
Write-Host 'Data file sizes are checked; this is not a full integrity hash of the DAT archives.'
