# Vendor

Pinned source code for third-party components. Only `*.lock`, this file and `src/` are committed;
everything built from them lives under `build/rime/`.

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

`scripts/build-librime.sh` builds everything static and universal for macOS 15.0:

- `BUILD_SHARED_LIBS=OFF`, `BUILD_STATIC=ON`, `ENABLE_LOGGING=OFF` (no glog/gflags).
- Tests, samples, dependency tools and documentation are disabled; librime's own
  `rime_deployer`, `rime_dict_manager`, `rime_patch` and `rime_table_decompiler` are kept.
- OpenCC is built with `USE_SYSTEM_MARISA=ON`, so one marisa-trie version is shared.
- The libraries are merged with `libtool -static` into `build/rime/lib/librime.a`, then wrapped in
  `Packages/HufuKit/Frameworks/CRime.xcframework` (module `CRime`).

## Further source-level trimming

Candidates, in rough order of payoff:

1. Drop `darts-clone` by configuring OpenCC with `ENABLE_DARTS=OFF`; keep only `ocd2` dictionaries.
2. Strip unused librime features by removing translation/gear sources from `src/CMakeLists.txt`
   (only after checking the schema no longer references them).
3. Replace Boost.Regex with `std::regex` and remove Boost entirely; this needs source changes and
   is not currently done.
4. Re-enable `ENABLE_LOGGING=OFF` is already applied; adding a lightweight logger would be a source
   change, not a build flag.

`build/rime/` is ignored. Delete it to force a clean rebuild; the script also skips work when the
submodule pins and its own contents are unchanged.
