# Third-party notices

Hufu's original code is licensed under [MIT](LICENSE), Copyright (c) 2026 syhily. Hufu is based on AIME (© 2026 ZOOL LLC, MIT); the original licence and attribution are retained. This does not relicense dependencies, dictionaries, or adapted community documents. Hufu is not a Squirrel fork and contains no Squirrel GPLv3 source code.

This inventory covers what the Hufu app bundles. It is not a substitute for the full license texts, which must accompany distributed components. The current local build has not yet passed the complete license-packaging audit; see [the release checklist](docs/release-checklist.md) and [the native plugin licence review](docs/native-plugin-license-audit.md).

## Components and data

| Component | Upstream / license | Status and handling |
| --- | --- | --- |
| librime 1.17.0 (33e7814) | [rime/librime](https://github.com/rime/librime), BSD-3-Clause | **Bundled** as `Contents/Frameworks/librime.1.dylib` from the official prebuilt release; sha256 pinned in `Vendor/librime.lock`. Statically includes yaml-cpp (MIT), leveldb (BSD-3), marisa-trie (BSD-2/LGPL-2.1 dual), glog (BSD-3), OpenCC (Apache-2.0). |
| librime-lua (ec52e48) | [Pinned license](https://github.com/hchunhui/librime-lua/blob/ec52e48ea18f11af37717a01c337f853215cf70b/LICENSE), BSD-3-Clause | **Bundled** in `Contents/Frameworks/rime-plugins/` from the same librime release. Embeds Lua (MIT); the embedded Lua version and full notices remain to be audited. librime-octagram (GPL-3.0) and librime-predict are **not bundled** — `scripts/fetch-librime.sh` excludes them, so the shipped bundle contains no GPL components. |
| OpenCC data | [BYVoid/OpenCC](https://github.com/BYVoid/OpenCC), Apache-2.0 | **Bundled** in `Contents/SharedSupport/opencc/` from the librime dependency archive. |
| 虎码官方词库与方案（虎码秃版 2026.08.15） | [tiger-code.com](https://www.tiger-code.com) / [huma.ysepan.com](https://huma.ysepan.com), official free release; mirrored by [syhily/hufu-scheme](https://github.com/syhily/hufu-scheme) | **Bundled** in `Contents/SharedSupport/` from the pinned `dicts/huma` git submodule (upstream mirror [hufu-scheme](https://github.com/syhily/hufu-scheme); the exact commit is the repository's gitlink): schemas, word table filtered to entries of four characters or fewer, Lua and OpenCC data. Product-side schema tweaks are applied to the staged copy, not to the submodule. Distributed under the official free-release terms; attribution to 虎码官方. The version string is recorded in `Contents/SharedSupport/hufu/VERSION`. |
| GitHub Octicon mark | [primer/octicons](https://github.com/primer/octicons), MIT | **Bundled** as the About page's repository icon. The unmodified `mark-github-16.svg`, pinned source commit and SHA-256 are recorded in `SharedSupport/hufu/licenses/github-octicon.source.json`; its full license accompanies the resource. Displayed as a monochrome template image. |
| Unicode Emoji 16.0 data | [Unicode, Inc.](https://www.unicode.org/Public/emoji/16.0/emoji-test.txt), Unicode License V3 | **Bundled derived data** in `SharedSupport/hufu/emoji.json`: 1,906 fully-qualified sequences in the nine official groups, excluding skin-tone variants and retaining hair styles, variation selectors and ZWJ sequences. Group titles are translated into Chinese; original CLDR ordering is retained. Source: © 2024 Unicode®, Inc.; the [source/filter record](SharedSupport/hufu/licenses/unicode-emoji-16.0.source.json) pins version, SHA-256 and counts. The [full Unicode license](SharedSupport/hufu/licenses/unicode-emoji-16.0.LICENSE.txt) accompanies the data. Original generation code is MIT; these data remain under the Unicode license. |
| Yams | [jpsim/Yams](https://github.com/jpsim/Yams), MIT | Swift package dependency (version pinned in `Package.resolved`). |
| swift-argument-parser | [apple/swift-argument-parser](https://github.com/apple/swift-argument-parser), Apache-2.0 | Swift package dependency of the `hufu` CLI. |
| Contributor Covenant 2.1 | [Contributor Covenant](https://www.contributor-covenant.org/version/2/1/code_of_conduct/), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | Adapted in `CODE_OF_CONDUCT.md` with an Hufu reporting contact. Its attribution is retained; the repository's MIT license does not replace this document's license. |

## Distribution checklist

The pinned plugin license texts and observed Vendor binary hashes are recorded in [the native-plugin manifest](licenses/native-plugins/manifest.json). The build embeds this partial inventory, the plugin license texts, Hufu's original license, and these notices under `Contents/Resources/LicenseMaterials/` before signing. It rejects license or pre-signing plugin inputs that differ from the audited hashes. This is not a complete corresponding-source package or distribution approval. See [the audit and remaining work](docs/native-plugin-license-audit.md).

Before publishing any binary or dictionary package:

1. Inventory the exact versions, source URLs, archive hashes, bundled libraries, plugins, scripts, and data files, including transitive components in prebuilt archives.
2. Include the full required license texts and copyright notices with the distributed artifacts, plus any applicable `NOTICE` file. This summary is not a substitute for those texts.
3. The installer no longer bundles any GPL component: librime-octagram and librime-predict are excluded at fetch time (`scripts/fetch-librime.sh`) and the license-embedding step rejects any plugin outside the audited inventory. The whole package is distributed under permissive terms (MIT/BSD/Apache); Hufu's original source remains MIT.
4. Ensure original MIT source contains no copied, translated, or adapted GPL implementation code, including Squirrel code. Data import compatibility is not permission to copy source.
5. For CC BY 4.0 data, include attribution, a license link, and modification notices. Do not imply endorsement by named brands or upstream authors.

Licensing must be checked against the pinned artifact, not only a moving upstream branch. Resolve missing or conflicting provenance before adding or distributing a component.
