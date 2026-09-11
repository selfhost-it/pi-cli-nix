import base64
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest import mock

import sys
sys.dont_write_bytecode = True
SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))
import update_common as common  # noqa: E402

spec = importlib.util.spec_from_file_location("pi_update_profile", SCRIPTS / "update.py")
profile_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(profile_module)


def sri256(byte):
    return "sha256-" + base64.b64encode(bytes([byte]) * 32).decode()


def sri512(byte):
    return "sha512-" + base64.b64encode(bytes([byte]) * 64).decode()


class ProfileTests(unittest.TestCase):
    def test_prepare_refreshes_source_npm_and_exact_version_model_data(self):
        with tempfile.TemporaryDirectory() as temporary:
            work = Path(temporary)
            shutil.copy2(Path(__file__).resolve().parents[1] / "package.nix", work / "package.nix")
            ctx = common.Context(work, work)

            def learn(_ctx, setters, _attr="."):
                for _name, (_hint, setter) in setters.items():
                    setter(sri256(2))

            target = common.Target(common.Version.parse("0.85.2"), sri512(3))
            with mock.patch.object(profile_module, "source_hash", return_value=sri256(1)), mock.patch.object(profile_module, "learn_hashes", side_effect=learn):
                profile_module.Profile().prepare(ctx, target)
            text = (work / "package.nix").read_text()
            for expected in (sri256(1), sri256(2), sri512(3)):
                self.assertIn(expected, text)
            self.assertIn('version = "0.85.2";', text)


if __name__ == "__main__":
    unittest.main()
