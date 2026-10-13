"""Offline validation checks; never load a game or speech backend."""

import hashlib
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from build_linux import APP_ID, APP_NAME, validate_codegen, validate_game, validate_sdk, write_launcher


class ValidationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="bakugan-validation-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def test_rejects_modified_executable_with_correct_size(self):
        expected = b"supported"
        (self.root / "default.xex").write_bytes(b"different")
        compatibility = {"xex": {
            "name": "default.xex", "size": len(expected),
            "sha256": hashlib.sha256(expected).hexdigest(),
        }, "required_files": []}
        with self.assertRaisesRegex(ValueError, "Unsupported or modified"):
            validate_game(self.root, compatibility)

    def test_missing_data_file_blocks_supported_executable(self):
        expected = b"supported"
        (self.root / "default.xex").write_bytes(expected)
        compatibility = {"xex": {
            "name": "default.xex", "size": len(expected),
            "sha256": hashlib.sha256(expected).hexdigest(),
        }, "required_files": [{"name": "d01.dat", "size": 1}]}
        with self.assertRaisesRegex(ValueError, "d01.dat"):
            validate_game(self.root, compatibility)

    def generated_fixture(self):
        generated = self.root / "generated/default"
        generated.mkdir(parents=True)
        (generated / "bakugandotc_init.cpp").write_text("{ 0x821BE858, function },\n")
        source = generated / "bakugandotc_recomp.0.cpp"
        source.write_text(
            "DEFINE_REX_FUNC(sub_821F6A08) {\nswitch (ctx.r4.u32) {case 24: break;}\n}\n"
            "DEFINE_REX_FUNC(sub_8238FEA8) {\nswitch (ctx.r11.u32) {case 13: break;}\n}\n")
        return generated, source, {"entrypoint": {"functions": {"0x821BE858": {}}}}

    def test_accepts_registration_and_both_switch_repairs(self):
        _, _, manifest = self.generated_fixture()
        validate_codegen(self.root, manifest)

    def test_missing_manual_function_blocks_build(self):
        generated, _, manifest = self.generated_fixture()
        (generated / "bakugandotc_init.cpp").write_text("")
        with self.assertRaisesRegex(ValueError, "required function"):
            validate_codegen(self.root, manifest)

    def test_truncated_switch_blocks_build(self):
        _, source, manifest = self.generated_fixture()
        source.write_text(source.read_text().replace("case 24:", "case 23:"))
        with self.assertRaisesRegex(ValueError, "Incomplete generated switch"):
            validate_codegen(self.root, manifest)

    def test_missing_switch_function_blocks_build(self):
        _, source, manifest = self.generated_fixture()
        source.write_text(source.read_text().replace("sub_8238FEA8", "sub_00000000"))
        with self.assertRaisesRegex(ValueError, "Missing repaired switch"):
            validate_codegen(self.root, manifest)

    def test_sdk_binary_hash_mismatch_is_rejected(self):
        (self.root / "rexglue").write_bytes(b"unexpected generator")
        lock = {"files": {"rexglue": hashlib.sha256(b"expected generator").hexdigest()}}
        with self.assertRaisesRegex(ValueError, "Unverified SDK dependency"):
            validate_sdk(self.root, lock)

    def test_launcher_preserves_arguments_and_sets_game_metadata(self):
        build = self.root / "build with spaces"
        build.mkdir()
        stub = build / "bakugandotc"
        stub.write_text(
            '#!/usr/bin/env python3\nimport json, os, sys\n'
            'print(json.dumps([sys.argv[1:], os.environ["SDL_APP_NAME"], '
            'os.environ["SDL_APP_ID"], os.getcwd()]))\n')
        stub.chmod(0o755)
        game = self.root / "game with 'quotes' and $(literal)"
        launcher = write_launcher(build, game)
        result = subprocess.run(["sh", str(launcher), "--fullscreen=false", "extra argument"],
                                capture_output=True, text=True, check=True)
        arguments, name, app_id, cwd = json.loads(result.stdout)
        self.assertEqual(arguments, [f"--game_data_root={game}", "--gpu_plugin=xenos",
                                     "--log_level=info", "--fullscreen=false", "extra argument"])
        self.assertEqual((name, app_id, cwd), (APP_NAME, APP_ID, str(build)))


if __name__ == "__main__":
    unittest.main()
