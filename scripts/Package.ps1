param(
    [string]$BuildDir = '',
    [Parameter(Mandatory=$true)][string]$SdkRoot,
    [Parameter(Mandatory=$true)][string]$ControllerDatabase
)
. "$PSScriptRoot/Common.ps1"
if (!$BuildDir) { $BuildDir = Join-Path $ProjectRoot 'out/build/publish-release' }
$build = (Resolve-Path -LiteralPath $BuildDir).Path
$sdk = (Resolve-Path -LiteralPath $SdkRoot).Path
if (!(Test-Path -LiteralPath (Join-Path $build 'build-info.json'))) { throw 'Run scripts/Build.ps1 first to record build provenance.' }
$info = Get-Content -LiteralPath (Join-Path $build 'build-info.json') -Raw | ConvertFrom-Json
Assert-Fingerprint (Join-Path $build 'rexruntime.dll') $info.rexruntime_sha256
Assert-Fingerprint (Join-Path $build 'rexgpu-xenos.dll') $info.rexgpu_xenos_sha256
Assert-Fingerprint (Join-Path $build 'bakugandotc.exe') $info.executable_sha256
Assert-Fingerprint (Join-Path $build 'BakuganLauncher.exe') $info.launcher_sha256
Assert-Fingerprint (Join-Path $sdk 'bin/rexruntime.dll') $info.rexruntime_sha256
if (!$info.dependencies_verified) { Write-Warning 'This candidate uses dependencies not yet validated with the project.' }
if (!(Test-Path -LiteralPath $ControllerDatabase -PathType Leaf)) { throw 'Supply the controller mapping database used by the tested build.' }
$version = (Get-Content (Join-Path $ProjectRoot 'compatibility.json') -Raw | ConvertFrom-Json).project_version
$destination = Join-Path $ProjectRoot ("dist/BakuganDOTCRecomp-$version-win64-" + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'))
if (Test-Path -LiteralPath $destination) { throw 'Package already exists.' }
New-Item -ItemType Directory -Path $destination | Out-Null
foreach ($file in @('bakugandotc.exe','BakuganLauncher.exe','rexruntime.dll','rexgpu-xenos.dll','build-info.json')) {
    Copy-Item -LiteralPath (Join-Path $build $file) -Destination $destination
}
Copy-Item -LiteralPath $ControllerDatabase -Destination (Join-Path $destination 'gamecontrollerdb.txt')
foreach ($file in @('README.md','README.es.md','LICENSE','THIRD_PARTY_NOTICES.md','compatibility.json','dependencies.lock.json')) {
    Copy-Item -LiteralPath (Join-Path $ProjectRoot $file) -Destination $destination
}
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'docs') -Destination $destination -Recurse
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'licenses') -Destination $destination -Recurse
if (Test-Path -LiteralPath (Join-Path $sdk 'licenses')) {
    Copy-Item -LiteralPath (Join-Path $sdk 'licenses') -Destination (Join-Path $destination 'licenses/sdk-installed') -Recurse
}
# Mark local packages as candidates until the playtest/release checklist is complete.
'Local release candidate. Complete docs/RELEASE_CHECKLIST.md before uploading.' | Set-Content (Join-Path $destination 'RELEASE-CANDIDATE.txt')
'@echo off' + "`r`n" + 'start "" "%~dp0BakuganLauncher.exe" --configure' + "`r`n" |
    Set-Content -LiteralPath (Join-Path $destination 'Configurar.cmd') -Encoding ASCII
$hashes = Get-ChildItem -LiteralPath $destination -Recurse -File | Sort-Object FullName | ForEach-Object {
    (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $_.FullName.Substring($destination.Length + 1).Replace('\','/')
}
$hashes | Set-Content (Join-Path $destination 'SHA256SUMS.txt') -Encoding ASCII
$unexpected = Get-ChildItem -LiteralPath $destination -Recurse -File | Where-Object {
    $_.Extension -in @('.xex','.dat','.iso','.i64','.id0','.id1','.log')
}
if ($unexpected) { throw 'Original game, analysis, or log files found in candidate. Refusing to create ZIP.' }
Compress-Archive -LiteralPath $destination -DestinationPath "$destination.zip"
Write-Host "Local release candidate: $destination"
Write-Host 'No original game files, generated sources, local configuration, or logs were packaged.'
