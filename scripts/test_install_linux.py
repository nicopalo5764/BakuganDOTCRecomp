"""Verify local deployment and update preservation using inert fixture files."""

import hashlib
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import install_linux


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="bakugan-install-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.project = self.root / "project"
        self.project.mkdir()
        self.game = self.project / "game"
        self.game.mkdir()
        (self.game / "default.xex").write_bytes(b"fixture executable")
        (self.game / "d01.dat").write_bytes(b"fixture data")
        self.xex_hash = install_linux.sha256(self.game / "default.xex")
        (self.project / "compatibility.json").write_text(json.dumps({
            "xex": {"name": "default.xex", "size": 18, "sha256": self.xex_hash},
            "required_files": [{"name": "d01.dat", "size": 12}],
        }))
        (self.project / "resources").mkdir()
        (self.project / "resources/bakugan.ico").write_bytes(b"fixture icon")
        (self.project / "licenses").mkdir()
        for name in ("LICENSE", "THIRD_PARTY_NOTICES.md"):
            (self.project / name).write_text("fixture notice")
        self.build = self.root / "build"
        self.build.mkdir()
        self.install = self.root / "local game with spaces"
        self.apps = self.root / "applications"
        self.patch = patch.object(install_linux, "PROJECT", self.project)
        self.patch.start()
        self.addCleanup(self.patch.stop)
        self.make_build(b"inert build one")

    def make_build(self, binary):
        (self.build / "bakugandotc").write_bytes(binary)
        (self.build / "librexruntime.so").write_bytes(b"inert runtime")
        files = {"lib/librexruntime.so": install_linux.sha256(self.build / "librexruntime.so")}
        (self.project / "dependencies.linux-amd64.lock.json").write_text(json.dumps({
            "sdk_version": "0.10.0", "files": files,
        }))
        (self.build / "build-info.json").write_text(json.dumps({
            "platform": "linux-amd64", "xex_sha256": self.xex_hash,
            "sdk_version": "0.10.0",
            "executable_sha256": hashlib.sha256(binary).hexdigest(),
            "sdk_files": files,
        }))

    def test_update_preserves_previous_build_game_and_configuration(self):
        install_linux.install(self.build, self.game, self.install, self.apps)
        previous = (self.install / "current").resolve()
        (previous / "bakugandotc.toml").write_text("fullscreen = false\n")
        self.make_build(b"inert build two")
        install_linux.install(self.build, None, self.install, self.apps)
        current = (self.install / "current").resolve()
        self.assertNotEqual(current, previous)
        self.assertEqual((previous / "bakugandotc").read_bytes(), b"inert build one")
        self.assertEqual((current / "bakugandotc").read_bytes(), b"inert build two")
        self.assertEqual((current / "bakugandotc.toml").read_text(), "fullscreen = false\n")
        self.assertEqual((self.install / "game/d01.dat").read_bytes(), b"fixture data")
        launcher = (self.install / "play.sh").read_text()
        self.assertNotIn(str(self.project), launcher)
        self.assertNotIn("--user_data_root", launcher)
        desktop = (self.apps / f"{install_linux.APP_ID}.desktop").read_text()
        self.assertIn("Name=Bakugan: Defenders of the Core\n", desktop)
        self.assertIn(str(self.install / "play.sh"), desktop)

    def test_corrupt_update_leaves_current_build_selected(self):
        install_linux.install(self.build, self.game, self.install, self.apps)
        previous = (self.install / "current").resolve()
        (self.build / "bakugandotc").write_bytes(b"corrupted")
        with self.assertRaisesRegex(ValueError, "fingerprint mismatch"):
            install_linux.install(self.build, None, self.install, self.apps)
        self.assertEqual((self.install / "current").resolve(), previous)

    def test_unpinned_dependencies_are_rejected(self):
        path = self.build / "build-info.json"
        info = json.loads(path.read_text())
        info["sdk_files"] = {}
        path.write_text(json.dumps(info))
        with self.assertRaisesRegex(ValueError, "pinned Linux SDK"):
            install_linux.install(self.build, self.game, self.install, self.apps)
        self.assertFalse(self.install.exists())

    def test_unrelated_menu_entry_is_preserved(self):
        self.apps.mkdir()
        desktop = self.apps / f"{install_linux.APP_ID}.desktop"
        desktop.write_text("[Desktop Entry]\nName=Another installation\n")
        with self.assertRaisesRegex(ValueError, "unrelated menu entry"):
            install_linux.install(self.build, self.game, self.install, self.apps)
        self.assertEqual(desktop.read_text(), "[Desktop Entry]\nName=Another installation\n")

    def test_installing_inside_source_game_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "inside the source game"):
            install_linux.install(self.build, self.game, self.game / "install", self.apps)
        self.assertFalse((self.game / "install").exists())

    def test_installed_launcher_uses_local_files_and_game_metadata(self):
        self.make_build(
            b'#!/usr/bin/env python3\nimport json, os, sys\n'
            b'print(json.dumps([sys.argv[1:], os.environ["SDL_APP_NAME"], '
            b'os.environ["SDL_APP_ID"], os.getcwd()]))\n')
        install_linux.install(self.build, self.game, self.install, self.apps)
        result = subprocess.run(["sh", str(self.install / "play.sh"), "argument with spaces"],
                                capture_output=True, text=True, check=True)
        args, name, app_id, cwd = json.loads(result.stdout)
        self.assertEqual(args, [f"--game_data_root={self.install / 'game'}",
                               "--gpu_plugin=xenos", "--log_level=info", "argument with spaces"])
        self.assertEqual(name, install_linux.APP_NAME)
        self.assertEqual(app_id, install_linux.APP_ID)
        self.assertEqual(Path(cwd).resolve(), (self.install / "current").resolve())


if __name__ == "__main__":
    unittest.main()
