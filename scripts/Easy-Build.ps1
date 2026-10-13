# One-click builder: pick your game folder, everything else is automatic.
# Started by EasyBuild.bat in the project root. Works in Windows PowerShell 5.1.
param(
    [string]$GameRoot = '',
    [string]$SdkRoot = '',
    [string]$GpuPluginPath = '',
    [int]$Jobs = 0,
    [switch]$NoLaunch
)
. "$PSScriptRoot/Common.ps1"

$spanish = (Get-UICulture).TwoLetterISOLanguageName -eq 'es'
function T([string]$es, [string]$en) { if ($spanish) { $es } else { $en } }
function Step([string]$es, [string]$en) { Write-Host ''; Write-Host ('== ' + (T $es $en)) -ForegroundColor Cyan }
function Ok([string]$es, [string]$en) { Write-Host ('   OK  ' + (T $es $en)) -ForegroundColor Green }
function Warn([string]$es, [string]$en) { Write-Host ('   !   ' + (T $es $en)) -ForegroundColor Yellow }
function Ask([string]$es, [string]$en) {
    $answer = Read-Host ('   ' + (T "$es [S/N]" "$en [Y/N]"))
    return $answer -match '^(s|si|sí|y|yes)$'
}

trap {
    Write-Host ''
    Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host (T 'Revisa la sección "Solución de problemas" de README.es.md.' 'See the "Troubleshooting" section of README.md.') -ForegroundColor Red
    exit 1
}

$userDir = Join-Path $env:LOCALAPPDATA 'BakuganDOTCRecomp'
$rememberedGame = Join-Path $userDir 'builder-game-folder.txt'
$lock = Get-Content -LiteralPath (Join-Path $ProjectRoot 'dependencies.lock.json') -Raw | ConvertFrom-Json

Write-Host ''
Write-Host '  Bakugan: Defenders of the Core - Recompiled' -ForegroundColor White
Write-Host ('  ' + (T 'Compilador automático' 'One-click builder')) -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
# 1. Game folder
# ---------------------------------------------------------------------------
Step '1/5  Carpeta del juego' '1/5  Game folder'
function Select-GameFolder([string]$initial) {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.Application]::EnableVisualStyles()
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = T 'Selecciona la carpeta extraída del juego (la que contiene default.xex)' 'Select the extracted game folder (the one containing default.xex)'
        $dialog.ShowNewFolderButton = $false
        if ($initial -and (Test-Path -LiteralPath $initial)) { $dialog.SelectedPath = $initial }
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dialog.SelectedPath }
        return ''
    } catch {
        return (Read-Host ('   ' + (T 'Escribe la ruta de la carpeta del juego' 'Type the path of the game folder'))).Trim('"', ' ')
    }
}
if (!$GameRoot -and (Test-Path -LiteralPath $rememberedGame)) {
    $previous = (Get-Content -LiteralPath $rememberedGame -Raw -Encoding UTF8).Trim()
    if ($previous -and (Test-Path -LiteralPath $previous)) {
        Write-Host ('   ' + (T 'Última carpeta usada: ' 'Last folder used: ') + $previous)
        if (Ask '¿Usar esta carpeta?' 'Use this folder?') { $GameRoot = $previous }
    }
}
while ($true) {
    if (!$GameRoot) {
        Write-Host ('   ' + (T 'Se abrirá una ventana para elegir la carpeta...' 'A window will open to choose the folder...'))
        $GameRoot = Select-GameFolder ''
        if (!$GameRoot) { throw (T 'No se eligió ninguna carpeta.' 'No folder was selected.') }
    }
    try {
        $GameRoot = Assert-GameCopy $GameRoot
        break
    } catch {
        Warn ('La carpeta no es válida: ' + $_.Exception.Message) ('The folder is not valid: ' + $_.Exception.Message)
        Warn 'Debe ser la carpeta extraída que contiene default.xex, d01.dat, d02.dat y d03.dat.' 'It must be the extracted folder containing default.xex, d01.dat, d02.dat and d03.dat.'
        if (!(Ask '¿Elegir otra carpeta?' 'Choose another folder?')) { throw (T 'Copia del juego no válida.' 'Invalid game copy.') }
        $GameRoot = ''
    }
}
New-Item -ItemType Directory -Force -Path $userDir | Out-Null
[IO.File]::WriteAllText($rememberedGame, $GameRoot, [Text.UTF8Encoding]::new($false))
Ok "Copia compatible: $GameRoot" "Compatible copy: $GameRoot"

# ---------------------------------------------------------------------------
# 2. Visual Studio
# ---------------------------------------------------------------------------
Step '2/5  Herramientas de compilación' '2/5  Build tools'
try {
    Initialize-BuildTools
    Ok 'Visual Studio con C++, Clang y CMake encontrado.' 'Visual Studio with C++, Clang and CMake found.'
} catch {
    Warn $_.Exception.Message $_.Exception.Message
    Write-Host ''
    Write-Host ('   ' + (T 'Necesitas Visual Studio 2022 (la edición Community es gratis) con:' 'You need Visual Studio 2022 (Community edition is free) with:'))
    Write-Host ('     - ' + (T 'Desarrollo para el escritorio con C++' 'Desktop development with C++'))
    Write-Host ('     - ' + (T 'Herramientas de Clang de C++ para Windows' 'C++ Clang tools for Windows'))
    Write-Host ('     - ' + (T 'Herramientas de CMake de C++ para Windows' 'C++ CMake tools for Windows'))
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget -and (Ask '¿Instalarlo ahora automáticamente con winget? (descarga varios GB)' 'Install it now automatically with winget? (downloads several GB)')) {
        $override = '--add Microsoft.VisualStudio.Workload.NativeDesktop --add Microsoft.VisualStudio.Component.VC.Llvm.Clang ' +
                    '--add Microsoft.VisualStudio.Component.VC.Llvm.ClangToolset --add Microsoft.VisualStudio.Component.VC.CMake.Project ' +
                    '--includeRecommended --passive --norestart'
        & winget install --id Microsoft.VisualStudio.2022.Community -e --accept-package-agreements --accept-source-agreements --override $override
        Write-Host ''
        Warn 'Cuando termine la instalación, vuelve a ejecutar EasyBuild.bat.' 'When the installation finishes, run EasyBuild.bat again.'
        Warn 'Si ya tenías Visual Studio, añade los componentes desde el Visual Studio Installer (Modificar).' 'If you already had Visual Studio, add the components from the Visual Studio Installer (Modify).'
    } else {
        Write-Host ('   ' + (T 'Descarga: ' 'Download: ') + 'https://visualstudio.microsoft.com/downloads/')
    }
    throw (T 'Faltan herramientas de compilación.' 'Build tools are missing.')
}

# ---------------------------------------------------------------------------
# 3. ReXGlue SDK
# ---------------------------------------------------------------------------
Step "3/5  ReXGlue SDK $($lock.sdk_version)" "3/5  ReXGlue SDK $($lock.sdk_version)"
if (!$SdkRoot) {
    $toolsDir = Join-Path $ProjectRoot 'tools'
    $SdkRoot = Join-Path $toolsDir "rexglue-sdk-$($lock.sdk_version)/win-amd64"
    if (!(Test-Path -LiteralPath (Join-Path $SdkRoot 'bin/rexglue.exe'))) {
        $zip = Join-Path $toolsDir "rexglue-sdk-$($lock.sdk_version)-win-amd64.zip"
        New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
        Write-Host ('   ' + (T 'Descargando el SDK oficial (~43 MB)...' 'Downloading the official SDK (~43 MB)...'))
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $oldProgress = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
        try { Invoke-WebRequest -Uri $lock.sdk_download_url -OutFile $zip -UseBasicParsing }
        finally { $ProgressPreference = $oldProgress }
        $zipHash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($zipHash -ne $lock.sdk_zip_sha256) {
            Remove-Item -LiteralPath $zip -Force
            throw (T 'El SDK descargado no coincide con la huella esperada. Inténtalo de nuevo.' 'The downloaded SDK does not match the expected fingerprint. Try again.')
        }
        Write-Host ('   ' + (T 'Descomprimiendo...' 'Extracting...'))
        Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $toolsDir "rexglue-sdk-$($lock.sdk_version)") -Force
        Remove-Item -LiteralPath $zip -Force
    }
}
$SdkRoot = (Resolve-Path -LiteralPath $SdkRoot).Path
if (!$GpuPluginPath) { $GpuPluginPath = Join-Path $SdkRoot 'bin/rexgpu-xenos.dll' }
Ok "SDK: $SdkRoot" "SDK: $SdkRoot"
Ok "Plugin gráfico: $GpuPluginPath" "Graphics plugin: $GpuPluginPath"

# ---------------------------------------------------------------------------
# 4. Build
# ---------------------------------------------------------------------------
Step '4/5  Generar y compilar' '4/5  Generate and build'
if ($Jobs -le 0) {
    # Recompiled sources are large; budget roughly 2 GB of RAM per compiler job.
    $ramGb = [math]::Floor((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    $Jobs = [int][math]::Max(1, [math]::Min([math]::Min([Environment]::ProcessorCount, 64), [math]::Floor($ramGb / 2)))
}
$drive = (Get-Item -LiteralPath $ProjectRoot).PSDrive
if ($drive -and $drive.Free -and $drive.Free -lt 3GB) {
    Warn 'Queda poco espacio en disco (se recomiendan 3 GB libres).' 'Low disk space (3 GB free recommended).'
}
Write-Host ('   ' + (T "Usando $Jobs procesos en paralelo. La primera vez puede tardar bastante." "Using $Jobs parallel jobs. The first build can take a while."))
$started = Get-Date
& (Join-Path $PSScriptRoot 'Build.ps1') -GameRoot $GameRoot -SdkRoot $SdkRoot -GpuPluginPath $GpuPluginPath -Jobs $Jobs
$elapsed = (Get-Date) - $started
Ok ('Compilado en ' + [int]$elapsed.TotalMinutes + ' min.') ('Built in ' + [int]$elapsed.TotalMinutes + ' min.')

# ---------------------------------------------------------------------------
# 5. Launcher
# ---------------------------------------------------------------------------
Step '5/5  Listo' '5/5  Done'
$output = Join-Path $ProjectRoot 'out/build/publish-release'
$launcher = Join-Path $output 'BakuganLauncher.exe'
# Pre-fill the launcher with the verified game folder on first use.
$settings = Join-Path $userDir 'launcher.ini'
if (!(Test-Path -LiteralPath $settings)) {
    $ini = "[Launcher]`r`nGameFolder=$GameRoot`r`nFullscreen=0`r`nWindowSize=0`r`nPostEffect=0`r`nShow=1`r`n"
    [IO.File]::WriteAllText($settings, $ini, [Text.Encoding]::Unicode)
}
Write-Host ('   ' + (T 'El juego está en: ' 'The game is in: ') + $output)
Write-Host ('   ' + (T 'Para jugar, abre BakuganLauncher.exe de esa carpeta.' 'To play, open BakuganLauncher.exe from that folder.'))
if (!$NoLaunch -and (Ask '¿Abrir el launcher ahora?' 'Open the launcher now?')) {
    Start-Process -FilePath $launcher -WorkingDirectory $output
}
