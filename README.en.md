<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/brand/hufu/base-v1/lockup-white.png">
    <img src="assets/brand/hufu/base-v1/lockup-color.png" width="300" alt="Hufu">
  </picture>
</p>

<p align="center"><b>Hufu · 虎符 input method</b></p>

<p align="center">A macOS Tiger-Code input method built on librime · Tiger-Code only · local first · optional AI</p>

<p align="center">
  <a href="https://github.com/syhily/hufu/releases">Download</a> ·
  <a href="docs/README.md">Documentation</a> ·
  <a href="docs/privacy.md">Privacy</a> ·
  <a href="README.md">中文</a>
</p>

<p align="center">
  <a href="https://github.com/syhily/hufu/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/syhily/hufu/ci.yml?branch=main&style=flat-square&label=CI" alt="CI"></a>
  <a href="https://github.com/syhily/hufu/releases"><img src="https://img.shields.io/github/v/release/syhily/hufu?include_prereleases&style=flat-square&label=release" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-2f855a?style=flat-square" alt="MIT"></a>
  <img src="https://img.shields.io/badge/macOS-15%2B-111111?style=flat-square&logo=apple" alt="macOS 15+">
  <img src="https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6">
  <img src="https://img.shields.io/badge/librime-1.17-B64032?style=flat-square" alt="librime 1.17">
</p>

Hufu is a native macOS frontend for Tiger-Code (虎码). It embeds [librime](https://github.com/rime/librime) in the input-method process, ships the official Tiger-Code tables, and manages typing habits through a settings app. It does not switch between schemas and bundles no other Pinyin or shape-based input method. The project derives from AIME.

**Scope: Hufu does not offer Rime's usual schema customization.** You cannot add, remove or author schemas, and there is no schema-patch editor. What is open is the custom coded dictionary (`huma_custom`, maintained in Settings).

> **Early release (0.1.x).** Features are still settling. Official releases are Developer ID signed and submitted for Apple notarization; builds without signing credentials are ad-hoc signed previews. Check each release's notes for its actual status.

## Features

- **Tiger-Code only** — the schema list contains one entry, `tigress`. The official 秃版 2026.08.15 data comes from the `dicts/huma` submodule ([hufu-scheme](https://github.com/syhily/hufu-scheme)), trimmed there to single characters and phrases of up to four characters.
- **The bundled table** — 117,662 single-character entries, 125,655 phrases and 3,134 short-code phrases: 246,451 raw records in total, counted recursively per source file and not deduplicated.
- **The official schema's helpers** — `` ` `` Pinyin reverse lookup (`PY_c`), `'` temporary English (`easy_english`), component breakdown hints (`chaifen`), Pinyin annotations and emoji annotations.
- **Four script modes** — mixed Simplified/Traditional (default; ranked by 《通用规范汉字表》 tiers, with traditional forms last), type Simplified get Traditional (candidates stay within the 8105 character set), Traditional only and Simplified only; the Traditional standard can be Tiger-Code `st_tu`, Taiwan, Hong Kong or generic.
- **Native candidate window** — AppKit and Core Text, with a one-row or vertical-list layout, light/dark schemes, and adjustable fonts, radii and spacing. Themes can be imported through `hufu-ime://` links.
- **Visual settings** — Overview, AI Assistant, Usage Statistics, Typing, Chinese/English, Shortcuts, Appearance, Apps, Vocabulary, Custom Phrases, Snippets, Sync & Backup, Advanced and About.
- **Optional AI** — Apple's on-device Foundation Models (macOS 26) or an OpenAI-compatible endpoint. ⌃⌥P runs translation, polishing and custom actions; the assistant can also change settings in natural language and extract vocabulary from an article (you supply the Tiger-Code codes).
- **Custom phrases** — maintain the `huma_custom` table in Settings with hand-written Tiger-Code codes; it is merged into the main dictionary and takes effect a few seconds later.
- **Snippets and statistics** — categorized snippets for phone numbers, addresses and more; optional usage statistics stay on this Mac and can be turned off or cleared.
- **Sync and backup** — merge learned frequencies across Macs through a RIME sync folder; Hufu runs no sync server. A local backup file can be exported and restored.
- **Import from other input methods** — read-only import of dictionaries, custom phrases, colour schemes and frequency snapshots from Squirrel, Weasel or fcitx RIME directories. Schemas and schema patches are not imported; Pinyin tables must be recoded to Tiger-Code before they can be used.
- **Clean licensing** — no separately loaded native plugins and no GPL components ship in the bundle.

## Install

Requires **macOS 15 or later** (Apple Intelligence on-device AI needs macOS 26). The input method, settings app and the bundled `hufu` CLI are all universal builds (Apple silicon and Intel).

1. Download the latest `Hufu-<version>.pkg` from [Releases](https://github.com/syhily/hufu/releases) and verify it against `SHA256SUMS.txt` on the same page:

   ```bash
   shasum -a 256 -c SHA256SUMS.txt --ignore-missing
   ```

2. Read that release's signing and notarization status, then follow its installation notes. Until Developer ID credentials are configured, releases are ad-hoc signed preview builds (allow them once under System Settings › Privacy & Security).
3. Open **System Settings › Keyboard › Input Sources › Edit…**, click **+** and add **Hufu** under Chinese, Simplified. If it does not appear after the first install, log out and back in.

There is no Homebrew cask yet; install from Releases.

## Build from source

You need macOS 15+, Xcode 26+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) and Python 3.

```bash
git clone --recurse-submodules https://github.com/syhily/hufu.git
cd hufu

bash scripts/fetch-librime.sh    # download and verify librime 1.17.0, assemble the static CRime.xcframework
bash scripts/stage-huma.sh       # filter the Tiger-Code table, assemble build/SharedSupport
bash scripts/build-app.sh        # → build/Release/Hufu.app
bash scripts/install-dev.sh      # install into ~/Library/Input Methods and register
```

If the repository is already cloned, initialise the schema data first: `git submodule update --init`. `dicts/huma` is a submodule pinned to [hufu-scheme](https://github.com/syhily/hufu-scheme), the customised mirror of the official 秃版 2026.08.15 package. Schema content (table trimming, schema adjustments) is maintained in that repository; do not edit the submodule in place.

`stage-huma.sh` keeps phrases of up to four characters by default; override it with:

```bash
HUFU_MAX_PHRASE_LEN=4 bash scripts/stage-huma.sh
```

Or generate the Xcode project and build there:

```bash
bash scripts/fetch-librime.sh && bash scripts/stage-huma.sh
xcodegen generate
open Hufu.xcodeproj
```

The project is generated from `project.yml`; `.xcodeproj` is not committed. Development installs are ad-hoc signed unless `HUFU_SIGN_IDENTITY` names a valid Developer ID identity.

## Key bindings

| Key | Action |
| --- | --- |
| `;` | Select the second candidate |
| `'` | Select the third candidate (while candidates are shown) |
| `-` / `=` | Previous / next page |
| Tab | Clear the current code |
| `` ` `` | Pinyin reverse lookup (`PY_c`) |
| Leading `'` | Temporary English (`easy_english`); Return or Space commits |
| ⌃O | Toggle Simplified/Traditional for the session (mixed ↔ Traditional output) |
| ⌃H | Toggle full / common character set |
| ⌃P | Toggle Pinyin annotations |
| ⌃I | Toggle emoji annotations |
| ⌃J | Toggle component breakdown hints |
| ⌃⇧3 / ⌃⇧4 | Chinese/English punctuation / Simplified-Traditional (same as ⌃O) |
| F4 or Control + \` | Schema menu (toggle switches) |

These bindings come from the official Tiger-Code schema and the bundled `default.yaml`. Adjust them in **Settings › Shortcuts** or **Settings › Advanced**.

Settings pages:

- **Overview** — input-method status, configuration status, import, diagnostic export.
- **AI Assistant** — on-device or bring-your-own endpoint, AI actions, draft layer, settings assistant, vocabulary extraction.
- **Usage Statistics** — daily characters, hours and apps, pinning frequent words.
- **Typing** — candidate count, the four script modes and Traditional standard, Tiger-Code switches, punctuation.
- **Chinese/English** — Caps Lock and Shift behaviour, per-app state.
- **Shortcuts** — hold-to-open key, schema menu, paging and selection keys.
- **Appearance** — themes and colour schemes, fonts, candidate layout, radii and spacing; accepts `hufu-ime://` theme links.
- **Apps** — per-app Chinese/English defaults.
- **Vocabulary** — an information card for the bundled Tiger-Code dictionary (version, source, character/phrase/record counts).
- **Custom Phrases** — maintain `huma_custom` with hand-written Tiger-Code codes.
- **Snippets** — categorized reusable text.
- **Sync & Backup** — frequency sync folder, export and restore.
- **Advanced** — open the user directory and logs, or rerun the first-run guide; no raw YAML patch editor.
- **About** — version, licences and third-party notices.

### Custom phrases

Settings › Custom Phrases writes to `huma_custom.dict.yaml` in the user directory. The main `tigress` dictionary imports that table, so new phrases appear in candidates a few seconds after the edit. Codes are Tiger-Code and must be entered by hand; the weight is optional.

### Importing from another input method

**Import** on the Overview page reads a Squirrel, Weasel or fcitx RIME directory without modifying it: dictionaries, custom phrases, colour schemes and frequency snapshots are copied into Hufu's own user directory. Schemas and schema patches are not imported — Hufu maintains the Tiger-Code schema itself. If the imported tables use Pinyin codes, recode them to Tiger-Code first; the import screen says so.

## User data

| Path | Contents |
| --- | --- |
| `~/Library/Hufu/Rime/` | librime workspace: build output, user frequencies, `hufu/imported` (hand-written patches), `hufu/generated` (written by Settings) |
| `~/Library/Logs/Hufu/` | librime logs, WARNING by default, no typed text |

The settings app does not link librime. It reads and writes configuration layers and hands changes to the input method through distributed notifications, with no user action. Settings are composed from three layers: Hufu defaults → hand-written patches → changes made in Settings. See [Architecture](docs/architecture.md) and the [decision records](docs/decisions/).

## Privacy

Everyday input is processed locally by librime. The keystroke path makes no network requests, Hufu writes no input logs, never uploads codes, candidates or learned frequencies, and ships no telemetry, crash-reporting or analytics SDKs.

Text reaches an AI model only when you explicitly run an AI action. Apple's on-device model runs locally; an OpenAI-compatible endpoint requires a separate permission to send text and may be billed by its provider. Hufu does not check for online updates and does not download dictionaries or models in the background. See [Privacy](docs/privacy.md).

## Development

```bash
bash scripts/fetch-librime.sh && bash scripts/stage-huma.sh
swift build --package-path Packages/HufuKit
swift test --package-path Packages/HufuKit
xcodegen generate && open Hufu.xcodeproj

# Latency gate
swift build --package-path Packages/HufuKit -c release --product hufu
"$(swift build --package-path Packages/HufuKit -c release --show-bin-path)/hufu" bench \
  --schema tigress --keys tuja --iterations 2000 --assert-p99-ms 5
```

The `hufu` CLI provides `deploy / bench / doctor / diagnostics / import-squirrel / get / set / sync / register`. See [CONTRIBUTING.md](CONTRIBUTING.md) for contributing, [docs/releasing.md](docs/releasing.md) for releases, and report security issues privately as described in [SECURITY.md](SECURITY.md).

## Documentation

The [documentation index](docs/README.md) collects usage, configuration, development and distribution guides. Report reproducible problems in [Issues](https://github.com/syhily/hufu/issues). Use synthetic text in reports and keep personal word frequencies, input history and credentials private.

## Acknowledgements

[AIME](https://github.com/zoolapp/aime) · [RIME / librime](https://github.com/rime/librime) · [Squirrel](https://github.com/rime/squirrel) · [OpenCC](https://github.com/BYVoid/OpenCC) · [Yams](https://github.com/jpsim/Yams) · [swift-argument-parser](https://github.com/apple/swift-argument-parser) · [Tiger-Code](https://www.tiger-code.com)

## License and attribution

Hufu's original code is released under the [MIT License](LICENSE), copyright © 2026 syhily. Hufu is derived from AIME (© 2026 ZOOL LLC, MIT); the original licence and attribution are retained.

The bundle also contains:

- **librime 1.17.0** — BSD-3-Clause; statically linked from [ghostflyby/librime-xcframework](https://github.com/ghostflyby/librime-xcframework) `1.17.0-pack.10.0.0` (sha256 pinned). No separately loaded librime native plugin is bundled.
- **OpenCC data** — Apache-2.0.
- **Official Tiger-Code dictionary and schemas** (秃版 2026.08.15) — released free of charge by the Tiger-Code project at [tiger-code.com](https://www.tiger-code.com), brought in through the [hufu-scheme](https://github.com/syhily/hufu-scheme) submodule at `dicts/huma`.
- **Noto Sans SC** — SIL Open Font License 1.1, used for the glyph outlines in the icon and brand artwork.

The distribution contains only MIT/BSD/Apache/OFL components and officially free data; it contains no GPL components and no separately loaded native plugins. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the full inventory and the [release checklist](docs/release-checklist.md) for distribution checks.

<p align="center"><sub>Published and maintained by <a href="https://github.com/syhily">syhily</a> · Hufu and 虎符输入法 are product names of syhily</sub></p>

For troubleshooting and diagnostic exports, see the [troubleshooting guide (Chinese)](docs/troubleshooting.md).
