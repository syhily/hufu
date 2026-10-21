# Changelog

User-facing changes in each Hufu release. 中文：[CHANGELOG.md](CHANGELOG.md).

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html):

- One section per release: `## [version] - YYYY-MM-DD`, followed by a quoted status line.
- Entries are grouped by type, using only these six, in this order: **Added**, **Changed**, **Fixed**, **Removed**, **Security**, **Known issues**. Omit empty types.
- One entry, one change a user can notice: where it happens and what changed. No internals or commit ids.
- Unreleased changes go under `## [Unreleased]` and move into the new version when it ships.
- Keep the versions, dates, status and types identical to CHANGELOG.md.

## [Unreleased]

### Added

- Four Simplified/Traditional modes: mixed (default, stably re-ranked by 《通用规范汉字表》 tier with traditional forms last), type Simplified get Traditional (candidates stay within the 8105 set, traditional forms judged by their simplified source), Traditional only (candidates that still carry a simplified glyph are dropped) and Simplified only (candidates outside 《通用规范汉字表》 are dropped), with Tiger-Code `st_tu`, Taiwan, Hong Kong or generic standards, under Settings › 输入习惯 › 简繁.
- Time, date, weekday and lunar calendar lookup: `/time`, `/date`, `/week` and `/cdate`, plus Tiger-Code homophone triggers.
- An `=expression` calculator that returns the result inline.
- `/number` uppercase amounts, now implemented natively in the front end.
- All three can be turned off in Settings › 输入习惯 › 便利功能.

### Changed

- Settings changes apply on their own: the redeploy button, menu item, status and progress bar are gone. Appearance edits apply in milliseconds, schema and phrase edits rebuild automatically; a failure shows the reason at the bottom of the window and retries once.
- The simplified↔traditional table (st_tu) now ships with the installer's librime/OpenCC layer; the schema repo no longer bundles stock OpenCC tables. Conversion covers Tiger-Code's full charset, and traditional characters remain directly typable with their own codes when conversion is off.
- librime 1.17.0 is now statically linked: the input method and `hufu` CLI are self-contained, the installer no longer ships a separate `librime.1.dylib`, and startup needs no external engine library, which also reduces the signing and distribution surface.
- librime, leveldb, marisa-trie, OpenCC and yaml-cpp are now built in-tree from pinned source submodules instead of downloaded prebuilt engines or static packages. Staging tools, the input method and the CLI share one build, with glog logging and test/documentation dependencies disabled.


### Removed

- The librime-lua native plugin, along with the exe-URL launcher, the Unicode hint filter and the common/full character-set toggle that depended on it.

## [0.1.0] - 2026-10-21

> First public release · Derived from AIME 0.1.10 · See the release notes for signing and notarization status

### Added

- A macOS input method built on librime 1.17.0 (prebuilt, sha256 pinned in `Vendor/librime.lock`), with a native candidate window offering a one-row or vertical-list layout and light/dark schemes.
- The official Tiger-Code 秃版 2026.08.15 tables (schema `tigress`), filtered to single characters and phrases of up to four characters: 117,662 characters, 125,655 phrases and 3,134 short-code phrases — 246,451 raw records.
- The official schema's helpers: `` ` `` Pinyin reverse lookup, `'` temporary English, component breakdown hints, Pinyin annotations, emoji annotations, Simplified/Traditional conversion (`st_tu.json` by default), and the full/common character-set toggle.
- Hufu Settings: Overview, AI Assistant, Usage Statistics, Typing, Chinese/English, Shortcuts, Appearance, Apps, Vocabulary, Custom Phrases, Snippets, Sync & Backup, Advanced and About.
- Theme and colour-scheme editing in Appearance, with `hufu-ime://theme` import links.
- AI Assistant: Apple's on-device Foundation Models (macOS 26) or an OpenAI-compatible endpoint; ⌃⌥P runs translation, polishing and custom actions; natural-language settings changes and vocabulary extraction (codes are entered by hand).
- Custom phrases: the `huma_custom` table is merged into the main Tiger-Code dictionary and applies on the next deployment.
- The installer ships librime's prebuilt binaries: first deploy finishes in about a second, and later custom-phrase edits only recompile the Tiger-Code tables (2–3 s).
- Snippets, optional usage statistics, frequency sync and local backup.
- Read-only import from Squirrel, Weasel and fcitx RIME directories; imported Pinyin tables must be recoded to Tiger-Code.
- The `hufu` CLI: deploy / bench / doctor / diagnostics / import-squirrel / get / set / sync / register.
- A tag-triggered release flow: GitHub Actions builds, signs (when credentials are configured) and notarizes, producing `Hufu-<version>.pkg`, `.zip` and checksums.

### Changed

- The project derives from AIME and is now Hufu (虎符输入法) at github.com/syhily/hufu.
- The user directory is now `~/Library/Hufu/Rime`, independent of Squirrel's `~/Library/Rime`.
- Tiger-Code is the default and only bundled schema; macOS 15+ is required; Apple Intelligence on-device AI needs macOS 26.
- librime-lua is the only native plugin; the installer no longer contains GPL components.

### Removed

- The schema-switching page and the fuzzy-Pinyin/spelling page.
- Online vocabulary subscriptions, schema package downloads and the sentence language model.
- Character-from-word selection and the online update check.
- The librime-octagram (GPL-3.0) and librime-predict native plugins.

### Known issues

- UI screenshots are pending.
- There is no Homebrew cask and no online theme gallery yet.
