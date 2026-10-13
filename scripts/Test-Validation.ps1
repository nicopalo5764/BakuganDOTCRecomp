param(
    [Parameter(Mandatory=$true)][string]$Launcher,
    [string]$GameRoot = ''
)
. "$PSScriptRoot/Common.ps1"
$executable = (Resolve-Path -LiteralPath $Launcher).Path
$testRoot = Join-Path $ProjectRoot ('out/validation-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
function Assert-LauncherExit([string]$Folder, [int]$Expected) {
    $process = Start-Process -FilePath $executable -ArgumentList @('--validate',('"' + $Folder + '"')) -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne $Expected) { throw "Launcher expected $Expected, got $($process.ExitCode) for $Folder" }
}
function Assert-ScriptRejects([string]$Folder) {
    $rejected = $false
    try { $null = Assert-GameCopy $Folder } catch { $rejected = $true }
    if (!$rejected) { throw "Validation accepted invalid folder: $Folder" }
}
Assert-LauncherExit $testRoot 2
Assert-ScriptRejects $testRoot
$invalid = Join-Path $testRoot 'copia inválida con espacios'
New-Item -ItemType Directory -Path $invalid | Out-Null
[IO.File]::WriteAllText((Join-Path $invalid 'default.xex'), 'not an Xbox executable')
Assert-LauncherExit $invalid 2
Assert-ScriptRejects $invalid
if ($GameRoot) {
    $game = Assert-GameCopy $GameRoot
    Assert-LauncherExit $game 0
    Copy-Item -LiteralPath (Join-Path $game 'default.xex') -Destination (Join-Path $invalid 'default.xex') -Force
    # A correct XEX with missing DAT must also be rejected.
    Assert-LauncherExit $invalid 2
    Assert-ScriptRejects $invalid
    [IO.File]::WriteAllText((Join-Path $invalid 'd01.dat'), 'truncated archive')
    Assert-LauncherExit $invalid 2
    Assert-ScriptRejects $invalid
    # Preserve XEX size while changing its content: size checks alone must not pass.
    $stream = [IO.File]::Open((Join-Path $invalid 'default.xex'), [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite)
    try { $first = $stream.ReadByte(); $stream.Position = 0; $stream.WriteByte($first -bxor 255) } finally { $stream.Dispose() }
    Assert-LauncherExit $invalid 2
    Assert-ScriptRejects $invalid
}
Write-Host 'PASS: launcher and build script reject invalid copies.'
if ($GameRoot) { Write-Host 'PASS: supplied reference copy accepted; missing/truncated data and modified XEX rejected.' }
Write-Host "Temporary test fixtures remain in ignored folder: $testRoot"
