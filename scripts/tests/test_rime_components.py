"""The gears whitelist in Vendor/hufu/gears_subset.cc must cover every component
mounted by the bundled schemas, and the shim must register exactly the whitelist."""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHIM = ROOT / "Vendor/hufu/gears_subset.cc"
SHARED = ROOT / "build/SharedSupport"
DEFAULT = ROOT / "SharedSupport/default.yaml"
KEY = re.compile(r"^(processors|segmentors|translators|filters|formatters):")


def clean(line):
    return line.split("#", 1)[0].rstrip()


def top_level_key(line):
    match = re.match(r"^([a-z][a-z0-9_]*):", line)
    return match.group(1) if match else None


def parse_engine(path, include_top_level=False, allowed_top_level=None):
    names, in_engine, in_list = set(), False, False
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = clean(raw)
        if not line.strip():
            continue
        if not raw.startswith((" ", "\t")):
            in_engine = line.strip() == "engine:"
            in_list = False
            if include_top_level and not in_engine:
                key = top_level_key(line.strip())
                if key and (allowed_top_level is None or key in allowed_top_level):
                    names.add(key)
            continue
        if not in_engine:
            continue
        stripped = line.strip()
        if KEY.match(stripped):
            in_list = True
        elif stripped.startswith("- ") and in_list:
            item = stripped[2:].strip().strip("'\"")
            name = item.split("@", 1)[0]
            if re.fullmatch(r"[a-z][a-z0-9_]*", name):
                names.add(name)
        elif not stripped.startswith("#"):
            in_list = False
    return names


def shim_names():
    return set(re.findall(r'Register\("([a-z0-9_]+)"', SHIM.read_text(encoding="utf-8")))


class RimeComponentTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(SHIM.is_file(), f"missing {SHIM}")
        self.registered = shim_names()
        self.assertTrue(SHARED.is_dir(), "build/SharedSupport missing; run scripts/stage-huma.sh")
        self.used = parse_engine(DEFAULT, include_top_level=True,
                                 allowed_top_level=self.registered)
        for path in sorted(SHARED.glob("*.schema.yaml")):
            self.used |= parse_engine(path)

    def test_shim_registers_the_expected_whitelist(self):
        self.assertEqual(len(self.registered), 26, sorted(self.registered))

    def test_every_mounted_component_is_registered(self):
        missing = sorted(self.used - self.registered)
        self.assertFalse(missing, f"schemas mount components missing from the shim: {missing}")

    def test_unused_registrations_are_reported(self):
        unused = sorted(self.registered - self.used)
        if unused:
            print(f"warning: registered but not mounted by bundled schemas: {unused}")


if __name__ == "__main__":
    unittest.main()
