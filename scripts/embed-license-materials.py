#!/usr/bin/env python3
"""Embed Hufu's license texts and third-party notices before signing."""

import argparse
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

PAYLOAD = [
    "LICENSE",
    "THIRD_PARTY_NOTICES.md",
    "docs/release-checklist.md",
]


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def embed(source_root, app):
    source_root, app = Path(source_root).resolve(), Path(app).resolve()
    payload = {path: (source_root / path).read_bytes() for path in PAYLOAD}
    for path in sorted((source_root / "licenses").glob("*.txt")):
        payload[str(path.relative_to(source_root))] = path.read_bytes()
    payload["README.txt"] = (
        "Hufu license materials\n"
        "LICENSE applies to Hufu original code; dependencies retain their licenses.\n"
        "licenses/ contains the full license texts of the statically linked libraries.\n"
        "Hufu builds no native librime plugins.\n"
        "This bundle is not approved for public distribution by this embedding step.\n"
    ).encode("utf-8")
    receipt = {"schemaVersion": 2, "scope": "license materials",
               "nativePluginsBundled": False,
               "files": [{"path": path, "bytes": len(data), "sha256": sha256(data)}
                         for path, data in sorted(payload.items())]}
    payload["packaging-receipt.json"] = (json.dumps(receipt, indent=2) + "\n").encode()
    destination = app / "Contents/Resources/LicenseMaterials"
    shutil.rmtree(destination, ignore_errors=True)
    for path, data in sorted(payload.items()):
        target = destination / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, required=True)
    args = parser.parse_args()
    try:
        receipt = embed(ROOT, args.app)
    except (ValueError, OSError, KeyError, TypeError) as error:
        parser.exit(1, f"license embedding failed: {error}\n")
    print(f"Embedded {len(receipt['files'])} license materials before signing")


if __name__ == "__main__":
    main()
