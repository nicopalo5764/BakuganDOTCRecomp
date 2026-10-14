#!/usr/bin/env python3
"""Validate and build the supported Xbox 360 copy using the Linux AMD64 SDK."""

import argparse
import hashlib
import json
import platform
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import tomllib
from datetime import datetime, timezone
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[1]
APP_ID = "bakugan-defenders-of-the-core"
APP_NAME = "Bakugan: Defenders of the Core"


def launcher_metadata():
    # SDL hints override the SDK's generic "rexglue" metadata before SDL starts.
    return (f"export SDL_APP_NAME={shlex.quote(APP_NAME)}\n"
            f"export SDL_APP_ID={shlex.quote(APP_ID)}\n")


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def validate_game(root, compatibility):
    xex = compatibility["xex"]
    for entry in [xex, *compatibility["required_files"]]:
        path = root / entry["name"]
        if not path.is_file() or path.stat().st_size != entry["size"]:
            raise ValueError(f"Missing or unexpected size: {path}")
    if sha256(root / xex["name"]) != xex["sha256"]:
        raise ValueError("Unsupported or modified default.xex; see compatibility.json.")


def validate_sdk(root, lock):
    for relative, expected in lock["files"].items():
        path = root / relative
        if not path.is_file() or sha256(path) != expected:
            raise ValueError(f"Unverified SDK dependency: {path}")
    header = (root / "include/rex/version.h").read_text()
    if not re.search(r'REXGLUE_VERSION_STRING\s+"' + re.escape(lock["sdk_version"]) + '"', header):
        raise ValueError(f"This project requires ReXGlue {lock['sdk_version']}.")


def validate_codegen(stage, manifest):
    generated = stage / "generated/default"
    registration = (generated / "bakugandotc_init.cpp").read_text()
    functions = manifest["entrypoint"]["functions"]
    if not functions:
        raise ValueError("No manual function registrations in the manifest.")
    for address in functions:
        if not re.search(r"\{\s*" + re.escape(address) + r"\s*,", registration, re.I):
            raise ValueError(f"Codegen did not register required function {address}.")
    # Preserve the checks from Build.ps1 for the two upstream switch repairs.
    checks = {"sub_821F6A08": (4, 24), "sub_8238FEA8": (11, 13)}
    found = set()
    for path in generated.glob("*recomp*.cpp"):
        source = path.read_text()
        for function, (register, last_case) in checks.items():
            body = re.search(r"^DEFINE_REX_FUNC\(" + function + r"\).*?^}", source, re.M | re.S)
            if body is None:
                continue
            if not re.search(r"switch\s*\(ctx\.r" + str(register) + r"\.u32\)", body[0]) or not re.search(r"case\s+" + str(last_case) + r"\s*:", body[0]):
                raise ValueError(f"Incomplete generated switch in {function}.")
            found.add(function)
    if found != checks.keys():
        raise ValueError(f"Missing repaired switch functions: {sorted(checks.keys() - found)}")
    print(f"Verified {len(functions)} manual registrations and both repaired switches.")


def run(arguments, cwd):
    subprocess.run([str(arg) for arg in arguments], cwd=cwd, check=True)


def write_launcher(build, game):
    launcher = build / "Play Defenders of the Core.sh"
    arguments = shlex.join([
        "./bakugandotc", f"--game_data_root={game}", "--gpu_plugin=xenos",
        "--log_level=info",
    ])
    launcher.write_text(
        '#!/bin/sh\nset -eu\n'
        + launcher_metadata()
        + 'cd -- "$(dirname -- "$0")"\n'
        + f'exec {arguments} "$@"\n')
    launcher.chmod(0o755)
    return launcher


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk-root", type=Path, required=True)
    parser.add_argument("--game-root", type=Path)
    parser.add_argument("--check-sdk-only", action="store_true")
    parser.add_argument("--generate-only", action="store_true")
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--cxx", default="clang++")
    args = parser.parse_args()
    if not 1 <= args.jobs <= 64:
        parser.error("--jobs must be between 1 and 64")
    if platform.system() != "Linux" or platform.machine() not in ("x86_64", "AMD64"):
        parser.error("This build path requires Linux AMD64.")
    if not args.check_sdk_only and args.game_root is None:
        parser.error("--game-root is required unless using --check-sdk-only")
    if args.check_sdk_only and args.generate_only:
        parser.error("Choose --check-sdk-only or --generate-only, not both")

    lock = json.loads((PROJECT / "dependencies.linux-amd64.lock.json").read_text())
    compatibility = json.loads((PROJECT / "compatibility.json").read_text())
    sdk = args.sdk_root.resolve(strict=True)
    validate_sdk(sdk, lock)
    run([sdk / "bin/rexglue", "--version"], PROJECT)
    print("Linux SDK version and binary fingerprints verified.", flush=True)
    if args.check_sdk_only:
        return
    game = args.game_root.resolve(strict=True)
    validate_game(game, compatibility)
    if not args.generate_only:
        for tool in ("cmake", "ninja", args.cxx):
            if shutil.which(tool) is None:
                raise ValueError(f"Required build tool not found: {tool}")

    # Each attempt gets its own directory, preserving previous builds and logs.
    output = PROJECT / "out/linux-amd64"
    output.mkdir(parents=True, exist_ok=True)
    attempt = Path(tempfile.mkdtemp(prefix="build-", dir=output))
    stage = attempt / "source"
    stage.mkdir()
    for name in ("CMakeLists.txt", "src", "resources", "launcher"):
        source = PROJECT / name
        if source.is_dir():
            shutil.copytree(source, stage / name)
        else:
            shutil.copy2(source, stage / name)
    manifest_path = stage / "bakugandotc_manifest.toml"
    manifest_source = (PROJECT / manifest_path.name).read_text()
    # Keep Unicode literal: JSON surrogate-pair escapes are not valid TOML.
    for key, value in (("game_root", str(game)), ("file_path", str(game / "default.xex"))):
        manifest_source, count = re.subn(
            r"(?m)^" + key + r"\s*=.*$",
            lambda match: f"{key} = {json.dumps(value, ensure_ascii=False)}", manifest_source)
        if count != 1:
            raise ValueError(f"Expected one {key} entry in the manifest.")
    manifest_path.write_text(manifest_source)
    manifest = tomllib.loads(manifest_source)
    print(f"Build directory: {attempt}", flush=True)
    run([sdk / "bin/rexglue", "codegen", manifest_path], stage)
    validate_codegen(stage, manifest)
    if args.generate_only:
        print(f"Generated and checked sources: {stage / 'generated'}")
        return

    build = attempt / "build"
    run(["cmake", "-S", stage, "-B", build, "-G", "Ninja",
         "-DCMAKE_BUILD_TYPE=Release", f"-DCMAKE_CXX_COMPILER={args.cxx}",
         f"-DCMAKE_PREFIX_PATH={sdk}", f"-DREXSDK_VERSION={lock['sdk_version']}",
         "-DBAKUGAN_AUDIO_DEBUG=OFF", "-DBAKUGAN_MUSIC_TRACE=OFF"], stage)
    run(["cmake", "--build", build, "--parallel", args.jobs], stage)
    # The SDK sets $ORIGIN RPATH but does not stage Linux runtime libraries.
    for relative in lock["files"]:
        if relative.startswith("lib/"):
            shutil.copy2(sdk / relative, build / Path(relative).name)
    info = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "sdk_version": lock["sdk_version"], "platform": lock["platform"],
        "xex_sha256": sha256(game / "default.xex"),
        "manifest_sha256": sha256(PROJECT / manifest_path.name),
        "sdk_files": lock["files"], "dependencies_verified": True,
        "executable_sha256": sha256(build / "bakugandotc"),
        "playtested": False,
    }
    (build / "build-info.json").write_text(json.dumps(info, indent=2) + "\n")
    launcher = write_launcher(build, game)
    print(f"Build complete: {build / 'bakugandotc'}; game has not been launched.")
    print(f"Launch shortcut: {launcher}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Build failed: {error}", file=sys.stderr)
        sys.exit(1)
