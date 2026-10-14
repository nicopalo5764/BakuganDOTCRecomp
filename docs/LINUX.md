# Linux development build

## Status

The Linux AMD64 Release game build succeeds on CachyOS/GNOME with Clang 23.1.1 and the official
ReXGlue 0.10.0 SDK. All 11 manual registrations and both switch-table checks pass.
The executable and GPU plugin resolve their shared libraries and relocations on
the development machine. Amethyst has launched the locally installed build and
confirmed audio and controller response. A supplied screenshot confirms the title
screen artwork, logo and "Press A" prompt render. Gameplay and saves are unverified.
Screen-reader support is planned separately from this Linux baseline.

## Requirements

- Python 3.11 or newer, CMake 3.25 or newer, Ninja and a C++23-capable Clang.
- The official ReXGlue 0.10.0 Linux AMD64 SDK, extracted into a writable local
  directory. Download URL and archive SHA-256 are in
  `dependencies.linux-amd64.lock.json`. Verify the archive before extraction.
- The extracted Xbox 360 game matching `compatibility.json`, including
  `default.xex`, `d01.dat`, `d02.dat` and `d03.dat`. PS3 files cannot be used.

## Validate the SDK

Download the [official Linux AMD64 SDK](https://github.com/rexglue/rexglue-sdk/releases/download/v0.10.0/rexglue-sdk-0.10.0-linux-amd64.zip).
Compare its SHA-256 with `sdk_zip_sha256` in
`dependencies.linux-amd64.lock.json` before extracting it. The extracted SDK root
is the `linux-amd64` directory containing `bin/`, `include/` and `lib/`.

```sh
python3 scripts/build_linux.py --sdk-root /path/to/linux-amd64 --check-sdk-only
```

This verifies the SDK version and generator, runtime, GPU plugin and Tracy
library fingerprints. It invokes the code generator's version command only.

## Build

```sh
python3 scripts/build_linux.py --sdk-root /path/to/linux-amd64 --game-root '/path/to/extracted game' --jobs 4
```

The script validates the supported executable hash and data file sizes before
generation. It preserves the Windows build's manual function and switch-table
checks. Each attempt uses a fresh ignored directory under `out/linux-amd64`,
retaining previous builds. Use `--generate-only` to stop after generation and
verification. Paths containing spaces are supported.

Successful builds include the runtime shared libraries next to the executable,
`build-info.json` with fingerprints, and `Play Defenders of the Core.sh`. The
shortcut selects the validated game directory and Xenos GPU plugin. Additional
command-line arguments are forwarded unchanged. It runs from the build directory
so local configuration and log locations are predictable. Saves use ReXGlue's
platform user directory and are independent of the build directory.

The build script never launches the game. There is no native Linux graphical
configuration launcher yet. Future manual playtests must
cover startup, menus, controller input, audio, saves and gameplay before Linux
support is described as working.

## First compiled Linux build

Built on 2026-10-13 from upstream commit
`69070f2adad27014cbb10288c329fb6a858b7849` and the supported XEX fingerprint in
`compatibility.json`. The extracted USA/Europe multilingual disc matched the
expected executable and all required data file sizes.

Executable SHA-256:
`30b08bdaca35c069ea45499108b9b7e1d097a908be0b0b6fd070ffc4fa7ce881`.

This is the Linux baseline before Prism or menu accessibility is added.

## First launch observations

On 2026-10-13, Amethyst confirmed title-screen music and controller response in
installed build `30b08bdaca35`. The screenshot shows the title screen rendering
at 16:9 with its logo, character artwork and controller prompt. This verifies
that screen only; it does not establish correctness of gameplay rendering.

The runtime log identifies the NVIDIA GeForce RTX 5090 Vulkan device and the
DualSense Edge controller. It also records startup GPU packet/ring-buffer errors
and an unimplemented profile setting (`00000000`). Their effect beyond the
observed title screen has not been established. Keep these observations in the
Linux validation report; do not describe the whole game as fully tested.

PipeWire reports the game's output stream as `rexglue`, while its process binary
is `bakugandotc`. ReXGlue v0.10.0's `src/audio/sdl/sdl_audio_driver.cpp`, in
`SDLAudioDriver::Initialize`, sets `SDL_PROP_APP_METADATA_NAME_STRING` to
`rexglue` before initializing audio. The bundled SDL header documents
`SDL_HINT_APP_NAME` as an application-name override; any correction needs to be
set before SDL initialization and verified on a subsequent user launch.
Both generated Linux launchers now export `SDL_APP_NAME` with the full game
title and `SDL_APP_ID` matching the desktop entry, before starting the process.
Launcher tests verify those values and argument forwarding with an inert stub.
An offline check against the bundled SDL library also confirms that the name
override takes precedence over the SDK's `rexglue` metadata without initializing
audio or video.
The updated label still requires confirmation in the audio control application
after a subsequent launch; the reported title-screen test predates that change.

## Local installation and updates

Install a completed build and its game data on the local drive:

```sh
python3 scripts/install_linux.py --build-dir out/linux-amd64/BUILD_DIRECTORY/build --game-root game
```

The default destination is `~/Games/bakugan-defenders-of-the-core`. The installer
copies and verifies every game file on first installation and registers
**Bakugan: Defenders of the Core** in the application menu. The installed launcher
and all game assets are local; starting the game does not require the NAS.

For subsequent builds, run the same installer with the new `--build-dir` and
omit `--game-root`. It retains the existing local game files, preserves the
current game configuration, and keeps previous builds under `releases/`.
After the new binaries are verified, the `current` symlink selects the new
release. The menu entry continues to use the stable `play.sh` launcher.
Changed installation metadata and menu/launcher files are backed up under
`backups/`. Saves continue using ReXGlue's existing platform user directory.

The installer never starts or stops the game. Close the game normally before
installing an update so its latest configuration is saved before copying it.
Select the same menu entry to launch the new build. Deployment tests use inert
files in temporary directories to check update preservation and rejection of
corrupted builds.

## Tooling tests

```sh
python3 -B -m unittest discover -s scripts -p 'test_*linux.py' -v
```

The Linux CI workflow runs these checks with Python 3.11 and desktop-file-utils.
They cover invalid game/SDK files, incomplete generated code, launcher arguments
and metadata, local installation, retained configurations/builds, and rejected
corrupt updates. They use synthetic fixtures and never launch the game. A full
game build and playtest still require the supported game files locally.
