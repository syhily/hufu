#!/usr/bin/env python3
"""Count the enabled Rime dictionary's raw records and record source hashes.

Offline, streaming, and deliberately not a general YAML parser. Supports the pinned
dictionary headers' scalar fields and block lists only; unfamiliar YAML is rejected.
Each reachable source file is read once. Word records are not deduplicated.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import tempfile

MAX_HEADER_BYTES = 1 << 20
MAX_LINE_BYTES = 1 << 20
MAX_FILES = 64
MAX_DEPTH = 16
SCALAR_KEYS = {"name", "version", "sort", "use_preset_vocabulary", "max_phrase_length"}
LIST_KEYS = {"import_tables", "columns"}
# Top-level keys whose (possibly nested) block is skipped without interpretation.
IGNORED_KEYS = {"encoder"}
TOKEN = re.compile(r"[A-Za-z0-9_./-]+")


def safe_name(value):
    path = PurePosixPath(value)
    if (not TOKEN.fullmatch(value) or value.startswith("/") or "\\" in value
            or any(part in ("", ".", "..") for part in value.split("/"))):
        raise ValueError(f"unsafe dictionary name: {value!r}")
    return path


def scalar(value, context):
    # The pinned headers use only ASCII identifiers and ISO/version strings. Reject
    # anchors, aliases, tags, flow collections and escapes instead of guessing YAML.
    if len(value) >= 2 and value[0] in "\"'" and value[-1] == value[0]:
        value = value[1:-1]
    if not TOKEN.fullmatch(value):
        raise ValueError(f"unsupported YAML scalar at {context}")
    return value


def read_dictionary(shared, name):
    relative = str(safe_name(name)) + ".dict.yaml"
    path = shared / relative
    if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(shared):
        raise ValueError(f"missing or unsafe dictionary source: {relative}")
    digest = hashlib.sha256()
    header = {}
    started = ended = False
    active_list = None
    header_bytes = rows = 0
    skipping = False
    with path.open("rb") as source:
        for number, raw in enumerate(source, 1):
            if len(raw) > MAX_LINE_BYTES:
                raise ValueError(f"line exceeds 1 MiB at {relative}:{number}")
            digest.update(raw)
            line = raw.decode("utf-8").rstrip("\r\n")
            if number == 1:
                line = line.removeprefix("\ufeff")
            if ended:
                if line.strip() and not line.lstrip().startswith("#"):
                    rows += 1
                continue
            header_bytes += len(raw)
            if header_bytes > MAX_HEADER_BYTES:
                raise ValueError(f"header exceeds 1 MiB: {relative}")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            if skipping:
                # Inside an ignored key's nested block: swallow indented lines.
                if line[:1] in (" ", "\t"):
                    continue
                skipping = False
            content = line.split("#", 1)[0].rstrip()
            context = f"{relative}:{number}"
            if content == "---" and not started:
                started = True
                continue
            if not started:
                # The upstream Tiger-Code tables omit the "---" prologue; the header
                # starts at the first key line instead.
                started = True
            if content == "..." and started:
                ended = True
                continue
            if not started or "\t" in content:
                raise ValueError(f"unsupported YAML header at {context}")
            if content.startswith("  - "):
                if active_list is None:
                    raise ValueError(f"list without supported header key at {context}")
                value = scalar(content[4:].strip(), context)
                if active_list == "import_tables":
                    safe_name(value)
                header[active_list].append(value)
                continue
            match = re.fullmatch(r"([a-z_]+):(?: (.*))?", content)
            if match is None:
                raise ValueError(f"unsupported YAML syntax at {context}")
            key, value = match.groups()
            if key in header or (key not in SCALAR_KEYS | LIST_KEYS and key not in IGNORED_KEYS):
                raise ValueError(f"duplicate or unsupported YAML key {key!r} at {context}")
            active_list = None
            if key in IGNORED_KEYS:
                # Skip the ignored key's nested block (indented lines that follow).
                skipping = True
                continue
            if key in LIST_KEYS:
                if value not in (None, "", "[]"):
                    raise ValueError(f"only block lists or [] supported at {context}")
                header[key] = []
                active_list = key if value != "[]" else None
            else:
                header[key] = scalar(value or "", context)
    if not ended or not header.get("name") or not header.get("version"):
        raise ValueError(f"incomplete dictionary header: {relative}")
    return {
        "path": relative, "dictionary": header["name"], "version": header["version"],
        "sha256": digest.hexdigest(), "rawRows": rows,
        "importTables": header.get("import_tables", []),
    }


def generate(shared, package_id, schema, dictionary, source_name, source_version, source_url, license_name):
    shared = shared.resolve()
    safe_name(schema)
    safe_name(dictionary)
    files, visiting, visited = [], set(), set()

    def visit(name, depth):
        if depth > MAX_DEPTH:
            raise ValueError("dictionary import depth exceeds 16")
        if name in visiting:
            raise ValueError(f"dictionary import cycle: {name}")
        if name in visited:
            return
        if len(files) >= MAX_FILES:
            raise ValueError("dictionary imports exceed 64 source files")
        visiting.add(name)
        record = read_dictionary(shared, name)
        files.append(record)
        for imported in record["importTables"]:
            visit(imported, depth + 1)
        visiting.remove(name)
        visited.add(name)

    visit(dictionary, 0)
    combined = hashlib.sha256(
        "\n".join(f'{item["path"]}:{item["sha256"]}' for item in files).encode("utf-8")
    ).hexdigest()
    return {
        "version": 1, "schema": schema, "dictionary": dictionary,
        "packageID": package_id, "sourceName": source_name, "sourceVersion": source_version,
        "sourceURL": source_url,
        "sourceSHA256": combined, "license": license_name,
        "rawRows": sum(item["rawRows"] for item in files),
        "rawRowsDescription": "按根词库及启用的 import_tables 递归统计，每个来源文件读取一次；排除空行和注释，不按词条去重，不代表唯一词数或实际候选数。未启用的词表不计入。",
        "sourceFiles": files,
    }


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shared-dir", type=Path, default=root / "build/SharedSupport")
    parser.add_argument("--package-id", default="huma-official")
    parser.add_argument("--schema", default="tigress")
    parser.add_argument("--dictionary", default="tigress")
    parser.add_argument("--source-name", default="虎码官方秃版（鼠须管 Mac 版）")
    parser.add_argument("--source-version", default="2026.08.15")
    parser.add_argument("--source-url", default="https://www.tiger-code.com")
    parser.add_argument("--license", default="虎码官方免费发布")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    output = args.output or args.shared_dir / "hufu/dictionary-metadata.json"
    protected = [Path.home() / "Library/Rime", Path.home() / "Library/Hufu/Rime"]
    try:
        for candidate in (args.shared_dir.resolve(), output.resolve()):
            if any(candidate == path or candidate.is_relative_to(path) for path in protected):
                raise ValueError("dictionary metadata must not read or write live user directories")
        metadata = generate(args.shared_dir, args.package_id, args.schema, args.dictionary,
                            args.source_name, args.source_version, args.source_url, args.license)
        data = (json.dumps(metadata, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        if args.check:
            if output.read_bytes() != data:
                raise ValueError("dictionary metadata differs from the enabled source files")
        else:
            output.parent.mkdir(parents=True, exist_ok=True)
            temporary = None
            try:
                with tempfile.NamedTemporaryFile(dir=output.parent, delete=False) as destination:
                    temporary = Path(destination.name)
                    destination.write(data)
                    # This is public bundled metadata. pkgbuild changes ownership
                    # to root, so NamedTemporaryFile's 0600 would hide it from users.
                    os.fchmod(destination.fileno(), 0o644)
                os.replace(temporary, output)
            finally:
                if temporary is not None:
                    temporary.unlink(missing_ok=True)
    except (OSError, UnicodeError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f"dictionary metadata failed: {error}\n")
    print(json.dumps({"mode": "check" if args.check else "generate", "output": str(output),
                      "schema": metadata["schema"], "dictionary": metadata["dictionary"],
                      "rawRows": metadata["rawRows"], "sourceFiles": len(metadata["sourceFiles"]),
                      "sha256": hashlib.sha256(data).hexdigest()}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
