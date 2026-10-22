# Vendor

Pinned source code for third-party components. Only `*.lock`, this file, `src/` and `hufu/` are
committed; everything built from them lives under `build/rime/`.

- `librime.lock` — human-readable manifest of the librime/dependency pins and the Boost source
  archive checksum. The gitlinks in `.gitmodules` are authoritative for source; the script verifies
  each checkout against the manifest.
- `src/librime` — [rime/librime](https://github.com/rime/librime) 1.17.0 (`33e7814`).
- `src/leveldb` — [google/leveldb](https://github.com/google/leveldb) 1.23 (`99b3c03`), no Snappy/CRC32C.
- `src/marisa-trie` — [s-yata/marisa-trie](https://github.com/s-yata/marisa-trie) v0.3.1 (`3e87d53`).
- `src/opencc` — [BYVoid/OpenCC](https://github.com/BYVoid/OpenCC) ver.1.1.9 (`556ed22`).
- `src/yaml-cpp` — [jbeder/yaml-cpp](https://github.com/jbeder/yaml-cpp) `2f86d13`, the commit
  librime 1.17.0 pins.
- Boost 1.89.0 is downloaded as a source tarball (sha256 in `librime.lock`) because the Boost
  superproject is not practical as a recursive submodule; only `Boost.Regex` is compiled.

- `hufu/gears_subset.cc` — Hufu's consumer-side gears whitelist. It defines the same
  `rime_require_module_gears()` symbol so librime's `gears_module.o` is not linked, then
  registers the 26 components the bundled schemas need. See
  [ADR-0007](../docs/decisions/0007-binary-trimming.md).

`scripts/build-librime.sh` builds everything static and universal for macOS 15.0:

- `BUILD_SHARED_LIBS=OFF`, `BUILD_STATIC=ON`, `ENABLE_LOGGING=OFF` (no glog/gflags).
- Tests, samples, dependency tools and documentation are disabled; librime's own
  `rime_deployer`, `rime_dict_manager`, `rime_patch` and `rime_table_decompiler` are kept.
- OpenCC is built with `USE_SYSTEM_MARISA=ON`, so one marisa-trie version is shared.
- The gears shim is compiled into a universal object, placed **first** in
  `libtool -static`, and merged with librime and the dependencies into
  `build/rime/lib/librime.a`; that archive is wrapped in
  `Packages/HufuKit/Frameworks/CRime.xcframework` (module `CRime`).
- Release apps use Xcode's `DEPLOYMENT_POSTPROCESSING`/`STRIP_INSTALLED_PRODUCT`
  (`STRIP_STYLE=all`); the universal CLI is stripped with `strip -x` before signing.

## Applied trimming

- glog/gflags removed via `ENABLE_LOGGING=OFF`.
- Tests, benchmarks, documentation and dependency tools disabled; only librime's own
  `rime_deployer`, `rime_dict_manager`, `rime_patch` and `rime_table_decompiler` are built.
- leveldb built without Snappy, CRC32C and tcmalloc.
- Boost limited to the static `Boost.Regex` library required by librime.
- 26-component gears subset via the consumer shim (`hufu/gears_subset.cc`); see
  [ADR-0007](../docs/decisions/0007-binary-trimming.md).
- OpenCC built with `USE_SYSTEM_MARISA=ON` and `ENABLE_DARTS=OFF`: only the `.ocd2`/marisa
  path used by Hufu remains; legacy `ocd`/DartsDict support is not compiled.
  Note that librime's own Prism still uses its bundled `darts.h`, so darts-clone remains
  in the licence inventory even though OpenCC's `DartsDict` is gone.
- Release apps use Xcode's `DEPLOYMENT_POSTPROCESSING`/`STRIP_INSTALLED_PRODUCT`
  (`STRIP_STYLE=all`); the universal CLI is stripped with `strip -x` before signing.

## Not allowed (see AGENTS.md)

`Vendor/src/**` and the downloaded Boost source are read-only upstream code. These
candidates were evaluated and abandoned because they require editing third-party sources:

- Removing unused librime source files from the build or its `CMakeLists.txt`.
- Replacing Boost.Regex with `std::regex` inside librime.

The only existing source patch is the historical exception documented in
[ADR-0006](../docs/decisions/0006-in-tree-librime-build.md): enable librime's tools in a
static build and find Boost.Regex as a component. Do not add further patches.

## Future evaluation

- **ThinLTO**: potentially shrinks the merged archive and final binaries, but couples the
  build to a specific toolchain and needs real size/runtime measurements first.
- **`ENABLE_TIMESTAMP=OFF`**: negligible size benefit for Hufu's schemas; not worth the
  reproducibility/behaviour change today.

`build/rime/` is ignored. Delete it to force a clean rebuild; the script also skips work when the
submodule pins, the shim and its own contents are unchanged.
