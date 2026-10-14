#!/usr/bin/env python3
"""Install a verified Linux build locally without launching the game."""

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from build_linux import APP_ID, APP_NAME, PROJECT, launcher_metadata, sha256, validate_game


def copy_verified(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256()
    with source.open("rb") as incoming, target.open("xb") as outgoing:
        while chunk := incoming.read(1024 * 1024):
            digest.update(chunk)
            outgoing.write(chunk)
    expected = digest.hexdigest()
    if sha256(target) != expected:
        raise ValueError(f"Copy verification failed: {target}")
    target.chmod(0o644)
    return expected


def replace_text(path, contents, backups, executable=False):
    if path.exists():
        if path.read_text() == contents:
            path.chmod(0o755 if executable else 0o644)
            return
        backups.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, backups / path.name)
    staged = path.with_name(path.name + ".installing")
    with staged.open("x") as stream:
        stream.write(contents)
    staged.chmod(0o755 if executable else 0o644)
    os.replace(staged, path)


def desktop_string(value):
    return str(value).replace("\\", "\\\\").replace("\n", "\\n").replace("\t", "\\t").replace("\r", "\\r")


def desktop_argument(value):
    # Exec has an argument-quoting layer in addition to desktop string escapes.
    escaped = str(value).replace("%", "%%")
    for char in ('\\', '"', '`', '$'):
        escaped = escaped.replace(char, "\\" + char)
    return desktop_string('"' + escaped + '"')


def install(build, source_game, root, applications):
    compatibility = json.loads((PROJECT / "compatibility.json").read_text())
    info = json.loads((build / "build-info.json").read_text())
    lock = json.loads((PROJECT / "dependencies.linux-amd64.lock.json").read_text())
    if info["platform"] != "linux-amd64":
        raise ValueError("The selected build is not Linux AMD64.")
    if info.get("sdk_version") != lock["sdk_version"] or info["sdk_files"] != lock["files"]:
        raise ValueError("Build dependencies do not match the pinned Linux SDK.")
    binaries = {"bakugandotc": info["executable_sha256"]}
    binaries.update({Path(name).name: digest for name, digest in info["sdk_files"].items()
                     if name.startswith("lib/")})
    for name, digest in binaries.items():
        if sha256(build / name) != digest:
            raise ValueError(f"Build fingerprint mismatch: {name}")
    if info["xex_sha256"] != compatibility["xex"]["sha256"]:
        raise ValueError("Build and supported game executable do not match.")
    if source_game is not None and root.is_relative_to(source_game):
        raise ValueError("The installation must not be inside the source game directory.")

    marker = root / "installation.json"
    if root.exists() and any(root.iterdir()) and not marker.is_file():
        raise ValueError(f"Refusing to replace an unmanaged installation: {root}")
    if marker.exists() and json.loads(marker.read_text()).get("app_id") != APP_ID:
        raise ValueError("Installation belongs to a different application.")
    current = root / "current"
    if current.exists() and not current.is_symlink():
        raise ValueError("The current build path is not an installer-managed symlink.")
    desktop = applications / f"{APP_ID}.desktop"
    if desktop.exists() and "X-BakuganDOTC-Managed=true" not in desktop.read_text():
        raise ValueError(f"Refusing to replace an unrelated menu entry: {desktop}")

    root.mkdir(parents=True, exist_ok=True)
    # Record ownership before staging, so interrupted first installs can resume.
    if not marker.exists():
        marker.write_text(json.dumps({"app_id": APP_ID, "status": "installing"}) + "\n")
    game = root / "game"
    if not game.exists():
        if source_game is None:
            raise ValueError("The first installation requires --game-root.")
        validate_game(source_game, compatibility)
        staging = Path(tempfile.mkdtemp(prefix="game-installing-", dir=root))
        hashes = {}
        for source in sorted(source_game.rglob("*")):
            if source.is_symlink():
                raise ValueError(f"Game extraction contains a symbolic link: {source}")
            if source.is_file():
                relative = source.relative_to(source_game)
                hashes[str(relative)] = copy_verified(source, staging / relative)
        validate_game(staging, compatibility)
        (staging / "installation-checksums.json").write_text(json.dumps(hashes, indent=2) + "\n")
        staging.rename(game)
        print("Local game data copied and every file verified.", flush=True)
    else:
        validate_game(game, compatibility)

    releases = root / "releases"
    releases.mkdir(exist_ok=True)
    release = Path(tempfile.mkdtemp(prefix=info["executable_sha256"][:12] + "-", dir=releases))
    for name, digest in binaries.items():
        if copy_verified(build / name, release / name) != digest:
            raise ValueError(f"Build changed during installation: {name}")
    (release / "bakugandotc").chmod(0o755)
    copy_verified(build / "build-info.json", release / "build-info.json")
    copy_verified(PROJECT / "resources/bakugan.ico", release / "bakugan.ico")
    for name in ("LICENSE", "THIRD_PARTY_NOTICES.md"):
        copy_verified(PROJECT / name, release / name)
    shutil.copytree(PROJECT / "licenses", release / "licenses")
    for source_config in (current / "bakugandotc.toml", build / "bakugandotc.toml"):
        if source_config.is_file():
            copy_verified(source_config, release / "bakugandotc.toml")
            break

    launcher = root / "play.sh"
    launcher_text = '#!/bin/sh\nset -eu\n' + launcher_metadata() + '''install_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd -- "$install_dir/current"
exec ./bakugandotc "--game_data_root=$install_dir/game" --gpu_plugin=xenos --log_level=info "$@"
'''
    backups = root / "backups" / release.name
    replace_text(launcher, launcher_text, backups, executable=True)
    applications.mkdir(parents=True, exist_ok=True)
    desktop_text = f'''[Desktop Entry]
Type=Application
Name={APP_NAME}
Comment=Play Bakugan: Defenders of the Core
Exec={desktop_argument(launcher)}
TryExec={desktop_string(launcher)}
Path={desktop_string(root)}
Icon={desktop_string(root / "current/bakugan.ico")}
Terminal=false
Categories=Game;
Keywords=Bakugan;Defenders;Core;
X-BakuganDOTC-Managed=true
'''
    # Validate before changing the active build or installing the menu entry.
    desktop_check = release / f"{APP_ID}.desktop"
    desktop_check.write_text(desktop_text)
    if shutil.which("desktop-file-validate"):
        subprocess.run(["desktop-file-validate", str(desktop_check)], check=True)
    subprocess.run(["sh", "-n", str(launcher)], check=True)
    previous = os.readlink(current) if current.is_symlink() else None
    link = root / f"current-{release.name}.installing"
    link.symlink_to(release.relative_to(root))
    os.replace(link, current)
    replace_text(desktop, desktop_text, backups)
    record = {"app_id": APP_ID, "installed_utc": datetime.now(timezone.utc).isoformat(),
              "current": str(release.relative_to(root)), "previous": previous,
              "executable_sha256": info["executable_sha256"], "game_root": str(game)}
    replace_text(marker, json.dumps(record, indent=2) + "\n", backups)
    if shutil.which("update-desktop-database"):
        subprocess.run(["update-desktop-database", str(applications)], check=True)
    print(f"Installed {APP_NAME}: {root}")
    print(f"Build: {info['executable_sha256']}")
    if previous:
        print(f"Previous build retained: {root / previous}")
    print("The game has not been launched.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-dir", type=Path, required=True)
    parser.add_argument("--game-root", type=Path)
    parser.add_argument("--install-root", type=Path, default=Path.home() / "Games" / APP_ID)
    args = parser.parse_args()
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    install(args.build_dir.resolve(strict=True),
            args.game_root.resolve(strict=True) if args.game_root else None,
            args.install_root.resolve(), data_home / "applications")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f"Installation failed: {error}", file=sys.stderr)
        sys.exit(1)
