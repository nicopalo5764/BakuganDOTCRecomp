param()
. "$PSScriptRoot/Common.ps1"
$version = (Get-Content (Join-Path $ProjectRoot 'compatibility.json') -Raw | ConvertFrom-Json).project_version
$destination = Join-Path $ProjectRoot ("dist/BakuganDOTCRecomp-source-$version-" + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'))
if (Test-Path -LiteralPath $destination) { throw 'Export already exists. Retry with a new timestamp.' }
Copy-PublicSources $destination
$forbidden = Get-ChildItem -LiteralPath $destination -Recurse -File | Where-Object { $_.Extension -in @('.xex','.dat','.iso','.exe','.dll','.i64','.log') }
if ($forbidden) { throw 'Unexpected binary/game file in source export.' }
Compress-Archive -LiteralPath $destination -DestinationPath "$destination.zip"
Write-Host "Clean GitHub source folder: $destination"
Write-Host "Source archive: $destination.zip"
Write-Host 'No repository was created and nothing was uploaded.'
