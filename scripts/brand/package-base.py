#!/usr/bin/env python3
"""Maintain the bounded, hashed brand asset manifest (and optionally a zip archive)."""
from pathlib import Path
import hashlib
import json
import shutil
import sys
import zipfile

root = Path(__file__).resolve().parents[2]
base = root / "assets/brand/hufu/base-v1"

shutil.copy2(root / "LICENSE", base / "LICENSE")
source_files = sorted((root / "scripts/brand").glob("*"))
asset_files = sorted(p for p in base.rglob("*") if p.is_file() and p.name != "manifest.json")
entries = [(p, p.relative_to(base).as_posix()) for p in asset_files]
entries += [(p, "source/" + p.name) for p in source_files if p.is_file()]
assert len(entries) <= 128, "Archive entry hard limit exceeded"
manifest = {
    "version": "1.0", "direction": "soft-bookmark", "tagline": "中文常新，自在表达。",
    "limits": {"archive_entries": 128, "image_generation_calls": 1},
    "files": [{"path": name, "bytes": p.stat().st_size, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p, name in entries],
    "notes": ["Independent SVG masters are editable vectors", "Menu PDF is a 16pt vector candidate", "App and menu integration not tested"]
}
(base / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
print(f"Wrote manifest with {len(entries)} entries")

if "--archive" in sys.argv[1:]:
    archive = base.parent / "hufu-brand-base-v1.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as z:
        for p, name in entries + [(base / "manifest.json", "manifest.json")]:
            info = zipfile.ZipInfo("hufu-brand-base-v1/" + name, date_time=(2026, 10, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            z.writestr(info, p.read_bytes())
    print(f"Created {archive}: {len(entries) + 1} entries; {archive.stat().st_size} bytes")
