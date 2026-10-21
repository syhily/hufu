# Vendor

Downloaded, pinned third-party binaries. Nothing here except `*.lock` and this file is committed.

- `librime.lock` — official librime release (tools, OpenCC data and a dynamic engine used only by
  `rime_deployer` during staging) plus the pinned `ghostflyby/librime-xcframework` static package.
  `scripts/fetch-librime.sh` downloads them into `.cache/`, verifies the hashes and assembles
  `librime/` (`lib/librime.1.dylib`, `bin/`, `share/`, `static/`; no `rime-plugins/`) plus a **static**
  `Packages/HufuKit/Frameworks/CRime.xcframework`.
- Dictionary archives (rime-ice) are cached in `.cache/` by `scripts/fetch-dicts.sh`, pinned in `dicts/registry.json`.
