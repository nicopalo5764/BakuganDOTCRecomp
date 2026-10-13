$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$ProjectRoot = Split-Path $PSScriptRoot -Parent

function Invoke-Checked {
    param([string]$Program, [string[]]$Arguments)
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed with exit code $LASTEXITCODE" }
}

function Assert-GameCopy {
    param([string]$GameRoot)
    $info = Get-Content -LiteralPath (Join-Path $ProjectRoot 'compatibility.json') -Raw | ConvertFrom-Json
    $folder = (Resolve-Path -LiteralPath $GameRoot).Path
    $xex = Join-Path $folder $info.xex.name
    if (!(Test-Path -LiteralPath $xex -PathType Leaf)) { throw 'Missing default.xex. Select your extracted Xbox 360 game folder.' }
    if ((Get-Item -LiteralPath $xex).Length -ne $info.xex.size -or
        (Get-FileHash -LiteralPath $xex -Algorithm SHA256).Hash -ne $info.xex.sha256) {
        throw 'Unsupported or modified default.xex. See compatibility.json for the supported SHA-256.'
    }
    foreach ($file in $info.required_files) {
        $path = Join-Path $folder $file.name
        if (!(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -ne $file.size) {
            throw "Missing or unexpected size: $($file.name). Check your game extraction."
        }
    }
    return $folder
}

function Assert-Fingerprint {
    param([string]$Path, [string]$Expected)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing dependency: $Path" }
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Expected) {
        throw "Unverified dependency: $Path. Its SHA-256 differs from dependencies.lock.json. Do not silently replace the tested runtime or GPU plugin."
    }
}

function Initialize-BuildTools {
    # Discover VS rather than hardcoding a user's installation or drive.
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    if (!(Test-Path -LiteralPath $vswhere)) { throw 'Install Visual Studio with Desktop development with C++, LLVM/Clang and CMake tools.' }
    $installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (!$installation) { throw 'Visual Studio C++ tools were not found.' }
    $vcvars = Join-Path $installation 'VC/Auxiliary/Build/vcvars64.bat'
    $environment = & $env:ComSpec /d /c "`"$vcvars`" >nul && set"
    if ($LASTEXITCODE -ne 0) { throw 'Could not initialize the Visual Studio x64 environment.' }
    # Some hosts inherit both PATH and Path. vcvars updates uppercase PATH;
    # importing the stale mixed-case entry afterward would discard the SDK tools.
    $toolchainPath = $environment | Where-Object { $_.StartsWith('PATH=', [StringComparison]::Ordinal) } | Select-Object -First 1
    if (!$toolchainPath) { $toolchainPath = $environment | Where-Object { $_ -match '^Path=' } | Select-Object -First 1 }
    foreach ($line in $environment) {
        if ($line -match '^([^=]+)=(.*)$' -and $Matches[1] -ine 'PATH') { [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process') }
    }
    if ($toolchainPath) { $env:PATH = $toolchainPath.Substring(5) }
    $script:CMake = Join-Path $installation 'Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe'
    $script:Ninja = Join-Path $installation 'Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja/ninja.exe'
    $script:Clang = Join-Path $installation 'VC/Tools/Llvm/x64/bin/clang++.exe'
    foreach ($tool in @($script:CMake, $script:Ninja, $script:Clang)) {
        if (!(Test-Path -LiteralPath $tool)) { throw "Missing build tool: $tool" }
    }
}

function Get-PublicSourceFiles {
    # Explicit allowlist: never recursively export the entire workspace.
    $files = @('CMakeLists.txt','CMakePresets.json','bakugandotc_manifest.toml',
        'compatibility.json','dependencies.lock.json','README.md','README.es.md','LICENSE','THIRD_PARTY_NOTICES.md',
        'MUSIC_FIX.md','.gitignore','.gitattributes',
        'src/main.cpp','src/bakugandotc_app.h','src/hooks/music_startup_hooks.cpp',
        'src/hooks/music_trace_hooks.cpp','src/discord/discord_rpc.cpp','src/discord/discord_rpc.h',
        'installer/BakuganDOTC_Setup.iss','installer/INSTALADOR_LEEME.txt')
    foreach ($directory in @('scripts','launcher','resources','docs','.github','licenses')) {
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $ProjectRoot $directory) -Recurse -File) {
            $files += $file.FullName.Substring($ProjectRoot.Length + 1).Replace('\','/')
        }
    }
    return $files
}

function Copy-PublicSources {
    param([string]$Destination)
    foreach ($relative in Get-PublicSourceFiles) {
        $source = Join-Path $ProjectRoot $relative
        $target = Join-Path $Destination $relative
        New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
}
