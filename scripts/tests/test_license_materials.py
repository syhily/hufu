import hashlib
import json
import runpy
import tempfile
import unittest
from pathlib import Path

EMBED = runpy.run_path(str(Path(__file__).resolve().parents[1] / "embed-license-materials.py"))["embed"]


class LicenseMaterialsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="hufu-license-test-")
        self.root = Path(self.temporary.name)
        self.source, self.app = self.root / "source", self.root / "Hufu.app"
        for path in ["LICENSE", "THIRD_PARTY_NOTICES.md", "docs/release-checklist.md"]:
            self.write(self.source / path, path.encode())
        self.write(self.source / "licenses/example.LICENSE.txt", b"third-party license")

    def tearDown(self):
        self.temporary.cleanup()

    def write(self, path, data):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def test_embeds_license_and_notices_with_receipt(self):
        receipt = EMBED(self.source, self.app)
        destination = self.app / "Contents/Resources/LicenseMaterials"
        for path in ["LICENSE", "THIRD_PARTY_NOTICES.md", "docs/release-checklist.md"]:
            self.assertEqual((destination / path).read_bytes(), (self.source / path).read_bytes())
        self.assertEqual((destination / "licenses/example.LICENSE.txt").read_bytes(), b"third-party license")
        self.assertEqual(receipt["schemaVersion"], 2)
        self.assertFalse(receipt["nativePluginsBundled"])
        self.assertIn("no native librime plugins", (destination / "README.txt").read_text())
        for file in receipt["files"]:
            content = (destination / file["path"]).read_bytes()
            self.assertEqual(hashlib.sha256(content).hexdigest(), file["sha256"])
        self.assertEqual(json.loads((destination / "packaging-receipt.json").read_bytes()), receipt)

    def test_rejects_missing_input_before_writing_resources(self):
        (self.source / "THIRD_PARTY_NOTICES.md").unlink()
        with self.assertRaises(OSError):
            EMBED(self.source, self.app)
        self.assertFalse((self.app / "Contents/Resources").exists())

    def test_removes_stale_plugin_materials(self):
        stale = self.app / "Contents/Resources/LicenseMaterials/licenses/native-plugins/manifest.json"
        self.write(stale, b"old inventory")
        EMBED(self.source, self.app)
        self.assertFalse(stale.exists())
        self.assertTrue((self.app / "Contents/Resources/LicenseMaterials/LICENSE").is_file())


if __name__ == "__main__":
    unittest.main()
