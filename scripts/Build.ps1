param(
    [Parameter(Mandatory=$true)][string]$GameRoot,
    [Parameter(Mandatory=$true)][string]$SdkRoot,
    [Parameter(Mandatory=$true)][string]$GpuPluginPath,
    [ValidateRange(1,64)][int]$Jobs = 4,
    [switch]$GenerateOnly,
    [switch]$AllowUnverifiedDependencies
)
. "$PSScriptRoot/Common.ps1"
$game = Assert-GameCopy $GameRoot
$sdk = (Resolve-Path -LiteralPath $SdkRoot).Path
$gpu = (Resolve-Path -LiteralPath $GpuPluginPath).Path
$lock = Get-Content -LiteralPath (Join-Path $ProjectRoot 'dependencies.lock.json') -Raw | ConvertFrom-Json
$versionHeader = Get-Content -LiteralPath (Join-Path $sdk 'include/rex/version.h') -Raw
if ($versionHeader -notmatch ('REXGLUE_VERSION_STRING\s+"' + [regex]::Escape($lock.sdk_version) + '"')) {
    throw "This project requires ReXGlue $($lock.sdk_version)."
}
$actualGenerator = (Get-FileHash -LiteralPath (Join-Path $sdk 'bin/rexglue.exe')).Hash.ToLowerInvariant()
$actualRuntime = (Get-FileHash -LiteralPath (Join-Path $sdk 'bin/rexruntime.dll')).Hash.ToLowerInvariant()
$actualGpu = (Get-FileHash -LiteralPath $gpu).Hash.ToLowerInvariant()
# Several GPU plugin builds are known to work; any of them counts as verified.
$acceptedGpu = @($lock.rexgpu_xenos | ForEach-Object { $_.sha256.ToLowerInvariant() })
$dependenciesVerified = $actualGenerator -eq $lock.rexglue_sha256 -and $actualRuntime -eq $lock.rexruntime_sha256 -and ($acceptedGpu -contains $actualGpu)
if (!$dependenciesVerified) {
    if (!$AllowUnverifiedDependencies) { throw 'Dependency hashes differ from the tested build. Use -AllowUnverifiedDependencies explicitly to test another build of this SDK version.' }
    Write-Warning 'Using dependencies not yet validated with this project. Actual hashes will be recorded in build-info.json.'
}

# All generated sources and machine-specific paths stay in ignored out/.
# A fresh exported folder therefore starts from the public manifest and hooks.
$stage = Join-Path $ProjectRoot 'out/recompile'
$build = Join-Path $ProjectRoot 'out/build/publish-release'
Copy-PublicSources $stage
$manifestPath = Join-Path $stage 'bakugandotc_manifest.toml'
$manifest = Get-Content -LiteralPath $manifestPath -Raw
$tomlGame = $game.Replace('\','/').Replace('"','\"')
$manifest = [regex]::Replace($manifest, '(?m)^game_root\s*=.*$', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) 'game_root = "' + $tomlGame + '"' })
$manifest = [regex]::Replace($manifest, '(?m)^file_path\s*=.*$', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) 'file_path = "' + $tomlGame + '/default.xex"' })
[IO.File]::WriteAllText($manifestPath, $manifest, [Text.UTF8Encoding]::new($false))
Invoke-Checked (Join-Path $sdk 'bin/rexglue.exe') @('codegen',$manifestPath)
$hints = [regex]::Match($manifest, '(?ms)^\[entrypoint\.functions\]\s*\r?\n(?<hints>.*?)(?=^\[|\z)').Groups['hints'].Value
$registration = Get-Content -LiteralPath (Join-Path $stage 'generated/default/bakugandotc_init.cpp') -Raw
$required = [regex]::Matches($hints, '(?m)^(0x[0-9A-Fa-f]+)\s*=')
if ($required.Count -eq 0) { throw 'No manual functions found under [entrypoint.functions]. Check manifest schema.' }
foreach ($entry in $required) {
    $address = $entry.Groups[1].Value
    if ($registration -notmatch ('(?i)\{\s*' + [regex]::Escape($address) + '\s*,')) {
        throw "Codegen did not register required function $address. Refusing to build an incomplete dispatch table."
    }
}
Write-Host "Verified $($required.Count) manual function registrations."
$switchChecks = @(
    @{ Function='sub_821F6A08'; Register=4; LastCase=24 },
    @{ Function='sub_8238FEA8'; Register=11; LastCase=13 }
)
foreach ($check in $switchChecks) {
    $body = $null
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $stage 'generated/default') -Filter '*recomp*.cpp') {
        $source = Get-Content -LiteralPath $file.FullName -Raw
        $match = [regex]::Match($source, '(?ms)^DEFINE_REX_FUNC\(' + $check.Function + '\).*?^}')
        if ($match.Success) { $body = $match.Value; break }
    }
    if (!$body -or $body -notmatch ('switch\s*\(ctx\.r' + $check.Register + '\.u32\)') -or
        $body -notmatch ('case\s+' + $check.LastCase + '\s*:')) {
        throw "Incomplete switch generated in $($check.Function). Check [entrypoint.switch_tables]."
    }
}
Write-Host 'Verified both repaired switch tables.'
if ($GenerateOnly) { Write-Host "Generated sources: $stage/generated"; return }

Initialize-BuildTools
Invoke-Checked $CMake @('-S',$stage,'-B',$build,'-G','Ninja','-DCMAKE_BUILD_TYPE=Release',
    "-DCMAKE_CXX_COMPILER=$Clang","-DCMAKE_MAKE_PROGRAM=$Ninja", "-DCMAKE_PREFIX_PATH=$sdk",
    "-DREXSDK_VERSION=$($lock.sdk_version)",'-DBAKUGAN_AUDIO_DEBUG=OFF','-DBAKUGAN_MUSIC_TRACE=OFF')
Invoke-Checked $CMake @('--build',$build,'--parallel',"$Jobs")
Copy-Item -LiteralPath $gpu -Destination (Join-Path $build 'rexgpu-xenos.dll') -Force
[ordered]@{
    created_utc = [DateTime]::UtcNow.ToString('o')
    sdk_version = $lock.sdk_version
    xex_sha256 = (Get-FileHash -LiteralPath (Join-Path $game 'default.xex')).Hash.ToLowerInvariant()
    manifest_sha256 = (Get-FileHash -LiteralPath (Join-Path $ProjectRoot 'bakugandotc_manifest.toml')).Hash.ToLowerInvariant()
    rexglue_sha256 = $actualGenerator
    rexruntime_sha256 = $actualRuntime
    rexgpu_xenos_sha256 = $actualGpu
    dependencies_verified = $dependenciesVerified
    executable_sha256 = (Get-FileHash -LiteralPath (Join-Path $build 'bakugandotc.exe')).Hash.ToLowerInvariant()
    launcher_sha256 = (Get-FileHash -LiteralPath (Join-Path $build 'BakuganLauncher.exe')).Hash.ToLowerInvariant()
    audio_debug = $false
    music_trace = $false
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $build 'build-info.json') -Encoding UTF8
Write-Host "Build complete: $build"
Write-Host 'Launch BakuganLauncher.exe to configure and play. Run the playtest checklist before publishing.'
