# Bakugan DOTC Recompiled

🇬🇧 **English** · 🇪🇸 [Español](README.es.md)

An experimental community project that runs **Bakugan: Defenders of the
Core** (Xbox 360) natively on Windows x64 through static recompilation with
[ReXGlue](https://github.com/rexglue/rexglue-sdk). This is not an official
release and is not affiliated with the game's rights holders, Microsoft or Xbox.

**Status: 0.1.0-preview.** The game boots and plays sound effects, voices and
music. A full playthrough and all hardware configurations have not been
certified yet. See [known issues](docs/KNOWN_ISSUES.md).

> **This repository contains no game files.** No executable, no data and no
> recompiled code. You need your own legal copy of the Xbox 360 game. The
> game's C++ code is generated on your machine from that copy.

---

## Contents

1. [Requirements](#1-requirements)
2. [Prepare your copy of the game](#2-prepare-your-copy-of-the-game)
3. [Get the project](#3-get-the-project)
4. [Quick build: EasyBuild.bat](#4-quick-build-easybuildbat) ← **easiest**
5. [Manual build](#5-manual-build)
6. [Play](#6-play)
7. [Optional: portable package and installer](#7-optional-portable-package-and-installer)
8. [Troubleshooting](#8-troubleshooting)
9. [For developers](#9-for-developers)

---

## 1. Requirements

| What | Details |
|---|---|
| OS | Windows 10/11 **x64** (the only tested platform) |
| GPU | Modern, with up-to-date drivers |
| Visual Studio 2022 | **Desktop development with C++** workload, with the **C++ Clang tools for Windows** (LLVM) and **C++ CMake tools for Windows** components |
| ReXGlue SDK | Version **0.10.0**, Windows AMD64. `EasyBuild.bat` downloads it for you (manual: [step 5.1](#51-get-the-rexglue-sdk)) |
| Git | Optional: you can also download the project as a ZIP |
| Game | Your extracted copy of Bakugan: Defenders of the Core (Xbox 360) |
| Disk space | ~4 GB for the game + ~1 GB for the build |

You don't need to install CMake or Ninja separately: the script uses the ones
bundled with Visual Studio and finds your installation automatically.

---

## 2. Prepare your copy of the game

You need the **extracted** disc folder (not the ISO). If you only have the ISO
or GOD format, extract it following the
[Xenia guide](https://github.com/xenia-project/xenia/wiki/Quickstart#how-to-rip-games).

The folder must contain exactly these files:

```
Bakugan_TM__DOTC\
├── default.xex   (7,708,672 bytes)
├── d01.dat       (1,486,018,560 bytes)
├── d02.dat       (1,369,090,048 bytes)
└── d03.dat       (632,233,984 bytes)
```

Only the executable identified in [compatibility.json](compatibility.json) is supported:

- Title ID: `41560891` · Media ID: `01048E5A`
- `default.xex` SHA-256:
  `454b358a66585ed336dae4b9a44f00c2170a54dcd933a3b6f02cf21ed7863019`

Do not apply title updates or swap in the XEX from another edition: the
recompiled code depends on that exact binary.

---

## 3. Get the project

```powershell
git clone https://github.com/nicopalo5764/BakuganDOTCRecomp.git
cd BakuganDOTCRecomp
```

Check that your copy of the game is compatible before continuing:

```powershell
.\scripts\Verify-Game.ps1 -GameRoot "C:\Games\Bakugan_TM__DOTC"
```

If it prints `Compatible executable and expected data sizes`, you're good.

> **If PowerShell blocks the scripts**, you can allow them for the current
> window only (this doesn't change system settings):
>
> ```powershell
> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
> ```

---

## 4. Quick build: EasyBuild.bat

Once you have Visual Studio installed (step 1) and your extracted game (step 2),
**double-click `EasyBuild.bat`** in the project folder. It will:

1. Ask for your game folder with a folder picker and verify it.
2. Check that Visual Studio has the C++, Clang and CMake components. If they're
   missing, it tells you what to install and can install them for you with `winget`.
3. Download the official ReXGlue 0.10.0 SDK (~43 MB) into `tools\` and verify
   its fingerprint.
4. Generate the code and build, using as many parallel jobs as your CPU/RAM allow.
5. Pre-fill the launcher with your game folder and offer to open it.

It remembers your game folder for next time. When it finishes, the game is in
`out\build\publish-release\` and you can jump to [Play](#6-play).

> Don't have Git? On the GitHub page click **Code → Download ZIP**, extract it
> and double-click `EasyBuild.bat` inside.

---

## 5. Manual build

Only needed if you want full control over each step.

### 5.1 Get the ReXGlue SDK

1. Download **ReXGlue 0.10.0 for Windows AMD64** from the
   [official releases](https://github.com/rexglue/rexglue-sdk/releases).
2. Extract it to a fixed location, e.g. `C:\Tools`. It creates a `win-amd64` folder.
   That folder (the *SdkRoot*) must contain:

   ```
   C:\Tools\win-amd64\
   ├── bin\rexglue.exe
   ├── bin\rexruntime.dll
   └── include\rex\version.h
   ```

3. The graphics plugin is `bin\rexgpu-xenos.dll` inside the SDK.

The SHA-256 fingerprints of the tested tools are pinned in
[dependencies.lock.json](dependencies.lock.json). The official SDK matches them,
including its `rexgpu-xenos.dll`. A custom build of the plugin made by the
author is also accepted. For any other DLL, add `-AllowUnverifiedDependencies`;
the build will be flagged as "not yet validated". More details in
[dependencies](docs/DEPENDENCIES.md) (Spanish).

### 5.2 Generate and build

From the project folder, in PowerShell:

```powershell
.\scripts\Build.ps1 `
  -GameRoot      "C:\Games\Bakugan_TM__DOTC" `
  -SdkRoot       "C:\Tools\win-amd64" `
  -GpuPluginPath "C:\Tools\win-amd64\bin\rexgpu-xenos.dll"
```

What the script does, in order:

1. Verifies the SHA-256 of `default.xex` and the size of the three `.dat` files.
2. Verifies the SDK version and the fingerprints of `rexglue.exe`,
   `rexruntime.dll` and `rexgpu-xenos.dll`.
3. Copies the project sources to `out\recompile` and writes your game path there.
   Your game copy and the original manifest are not modified.
4. Runs `rexglue codegen`, which translates the XEX into C++ under `out\recompile\generated`.
5. Checks that the **11 manual functions** and **2 jump tables** from the
   manifest made it into the generated code. If anything is missing, it stops.
6. Configures CMake with Clang + Ninja and builds in Release mode.
7. Copies the graphics plugin and writes `build-info.json` with the output fingerprints.

The output ends up in:

```
out\build\publish-release\
├── bakugandotc.exe        ← the game
├── BakuganLauncher.exe    ← settings / launcher
├── rexruntime.dll
├── rexgpu-xenos.dll
└── build-info.json
```

Useful options:

| Option | Effect |
|---|---|
| `-Jobs 8` | Parallel build jobs (default 4; adjust to your cores/RAM) |
| `-GenerateOnly` | Only generates the C++ code and runs the checks, without compiling |
| `-AllowUnverifiedDependencies` | Allows an SDK/DLL whose fingerprints differ from the tested ones |

The first build takes a while: hundreds of large C++ files are generated and
compiled. Later builds are faster.

---

## 6. Play

### With the launcher (recommended)

1. Open `out\build\publish-release\BakuganLauncher.exe`.
2. Select your game folder (from step 2). The launcher validates it.
3. Choose **windowed** or **fullscreen** and, optionally, anti-aliasing.
4. Click **Play**.

The launcher appears in English or Spanish depending on your Windows display
language. To force one: `BakuganLauncher.exe --lang=en` or `--lang=es`.

Settings are stored in `%LOCALAPPDATA%\BakuganDOTCRecomp\launcher.ini`.
To bring the settings window back after disabling it, run
`BakuganLauncher.exe --configure`.

### Directly, without the launcher

```bat
bakugandotc.exe --game_data_root="C:\Games\Bakugan_TM__DOTC" --gpu_plugin xenos
```

You can save that line in a `.bat` file next to the executable so you don't
have to type it every time.

### Controllers

For non-Xbox controllers, place a
[`gamecontrollerdb.txt`](https://github.com/mdqinc/SDL_GameControllerDB)
next to `bakugandotc.exe`.

### Anti-aliasing (FXAA)

The **Anti-aliasing** selector offers Off, FXAA and FXAA Extreme. It's a
post-processing filter. It doesn't raise the internal resolution and may also
soften text. It's off by default. From the command line:
`--swap_post_effect=fxaa`, `--swap_post_effect=fxaa_extreme` or `none`.

Window size doesn't change the internal resolution either. Fullscreen uses
your desktop resolution.

---

## 7. Optional: portable package and installer

**Portable package** (ZIP with binaries, docs, licenses and SHA-256 sums):

```powershell
.\scripts\Package.ps1 -SdkRoot "C:\Tools\win-amd64" `
  -ControllerDatabase "C:\Path\gamecontrollerdb.txt"
```

It's created under `dist\`. It never includes game files, generated code or logs.

**Installer** (requires [Inno Setup 6](https://jrsoftware.org/isinfo.php)):

```powershell
ISCC.exe /DPackageDir="ABSOLUTE_PATH_TO_PACKAGE" installer\BakuganDOTC_Setup.iss
```

The installer is available in English and Spanish.

Before distributing binaries, go through the [release checklist](docs/RELEASE_CHECKLIST.md)
and [publishing guide](docs/PUBLISHING.md) (Spanish).

---

## 8. Troubleshooting

| Message / symptom | Cause and fix |
|---|---|
| `Missing default.xex` | `-GameRoot` doesn't point to the extracted folder. It must be the folder that directly contains `default.xex`. |
| `Unsupported or modified default.xex` | Your XEX isn't the supported version (different region, updated or modified). Compare its SHA-256 with `compatibility.json`. |
| `Missing or unexpected size: d0X.dat` | A `.dat` is missing or the extraction is incomplete. Extract the disc again. |
| `This project requires ReXGlue 0.10.0` | `-SdkRoot` points to another SDK version or the wrong folder. It must contain `include\rex\version.h`. |
| `Dependency hashes differ from the tested build` | Your SDK/DLL isn't one of the tested ones. Use the official 0.10.0 release, or add `-AllowUnverifiedDependencies`. |
| `Install Visual Studio with Desktop development with C++...` | Visual Studio or the C++ workload is missing. |
| `Missing build tool: ...clang++.exe` / `ninja.exe` | Install the **Clang** and **CMake** components in Visual Studio (step 1). |
| `Codegen did not register required function 0x...` | The generator didn't apply the manifest's functions. Make sure you use SDK 0.10.0 and the repo's unmodified `bakugandotc_manifest.toml`. |
| `Incomplete switch generated in sub_...` | Same, but for the jump tables (`[[entrypoint.switch_tables]]`). |
| PowerShell: "running scripts is disabled on this system" | See the note in [step 3](#3-get-the-project). |
| The game closes when reaching a certain scene | Possibly an unregistered function. Check the log and see [section 9](#9-for-developers). |
| Windows SmartScreen blocks the `.exe` | It's an unsigned binary you built yourself. Check where it came from before allowing it. |

To report a bug, open an *issue* with the project version, your hardware, the
XEX hash, steps to reproduce and the relevant part of the log. Remove personal
paths and **do not attach game files or IDA databases**.

---

## 9. For developers

### Layout

```
├── src/                        Original code: entry point, hooks and Discord RPC
│   └── hooks/music_startup_hooks.cpp   Music fix (see MUSIC_FIX.md)
├── launcher/                   Settings/launcher (Win32, independent of the SDK)
├── scripts/                    Build, verification, packaging, export
├── bakugandotc_manifest.toml   ReXGlue manifest (manual functions and switches)
├── compatibility.json          Supported XEX and DAT files
├── dependencies.lock.json      Fingerprints of the tested SDK and DLLs
├── installer/                  Inno Setup script
├── docs/                       Build, validation and publishing docs (Spanish)
└── licenses/                   Third-party licenses
```

The `generated/`, `out/` and `dist/` folders are created when building and are
listed in `.gitignore`. **They must not be committed**, because they contain
code derived from the game or binaries.

### Functions the generator can't find

ReXGlue can't detect some of the game's functions and two of its jump tables on
its own. They're declared in `bakugandotc_manifest.toml`, under
`[entrypoint.functions]` and `[[entrypoint.switch_tables]]`, so they're added
on every regeneration. `Build.ps1` checks that they're there.

If a playthrough hits another unregistered call:

1. Keep the log with the failing address.
2. Check the function's real start and size in the XEX (IDA or similar).
3. Add it to the **root** manifest under `[entrypoint.functions]`:
   `0x8XXXXXXX = { size = 0xNN }`.
4. Run `Build.ps1` again.

Don't hand-edit code in `generated/` or `out/recompile`: it's overwritten on
every build. More details in [docs/BUILD.md](docs/BUILD.md) (Spanish).

### Build only the launcher (no SDK or game needed)

```powershell
cmake -S launcher -B out/launcher -A x64
cmake --build out/launcher --config Release
```

`BakuganLauncher.exe --validate "FOLDER"` validates a copy without opening the
UI. It returns 0 if compatible, 2 if incompatible or incomplete, and 3 on a
read error. This is what continuous integration runs.

### Diagnostic CMake options

| Option | Effect |
|---|---|
| `BAKUGAN_MUSIC_TRACE=ON` | Builds detailed music playback traces |

---

## License

The original contributions in this project are distributed under the
[MIT](LICENSE) license. Dependencies keep their own licenses (see
[third-party notices](THIRD_PARTY_NOTICES.md) and `licenses/`). This license
does **not** cover the original code or assets of Bakugan: Defenders of the
Core, which belong to their respective owners.
