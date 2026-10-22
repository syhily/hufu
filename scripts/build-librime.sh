#!/usr/bin/env bash
# Builds librime and its dependencies from the pinned submodules under Vendor/src.
#
#   bash scripts/build-librime.sh              # full build: libraries, tools, data, CRime.xcframework
#   bash scripts/build-librime.sh opencc-data  # only marisa + OpenCC data (for dicts.yml)
#
# Outputs live under build/rime/ (ignored):
#   bin/rime_deployer, rime_dict_manager, rime_patch, rime_table_decompiler
#   share/opencc/*.ocd2, *.json
#   lib/librime.a                        merged static archive for the app and CLI
#   headers/                             CRime module headers
# Packages/HufuKit/Frameworks/CRime.xcframework is regenerated from lib/librime.a.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Vendor/src"
LOCK="$ROOT/Vendor/librime.lock"
BUILD="$ROOT/build/rime"
WORK="$BUILD/build"
PREFIX="$BUILD"
XCF="$ROOT/Packages/HufuKit/Frameworks/CRime.xcframework"
MODE="${1:-all}"
ARCHS="arm64;x86_64"
DEPLOYMENT_TARGET="15.0"
BOOST_CACHE="$BUILD/cache"
SHIM_SRC="$ROOT/Vendor/hufu/gears_subset.cc"

case "$MODE" in
  all|opencc-data) ;;
  *)
    echo "usage: bash scripts/build-librime.sh [all|opencc-data]" >&2
    exit 2
    ;;
esac

# shellcheck disable=SC1090
eval "$(grep -E '^(LIBRIME_VERSION|LIBRIME_COMMIT|LEVELDB_COMMIT|MARISA_COMMIT|OPENCC_COMMIT|YAML_CPP_COMMIT|BOOST_VERSION|BOOST_SHA256)=' "$LOCK")"

BOOST_UNDERSCORE="${BOOST_VERSION//./_}"
BOOST_TARBALL="boost_${BOOST_UNDERSCORE}.tar.gz"
BOOST_SRC="$BUILD/src/boost_${BOOST_UNDERSCORE}"
BOOST_STAGE="$BUILD/boost-${BOOST_VERSION}"

require_submodule() {
  local name="$1" expected="$2" actual
  [[ -f "$SRC/$name/CMakeLists.txt" ]] || {
    echo "missing Vendor/src/$name; run: git submodule update --init --recursive" >&2
    exit 1
  }
  actual="$(git -C "$SRC/$name" rev-parse HEAD 2>/dev/null || true)"
  [[ "$actual" == "$expected" ]] || {
    echo "Vendor/src/$name is at ${actual:-unknown}, expected $expected" >&2
    echo "run: git submodule update --init --recursive" >&2
    exit 1
  }
}

script_sha() {
  shasum -a 256 "$0" | cut -d' ' -f1
}

shim_sha() {
  shasum -a 256 "$SHIM_SRC" | cut -d' ' -f1
}

full_key() {
  {
    echo "$LIBRIME_COMMIT"
    echo "$LEVELDB_COMMIT"
    echo "$MARISA_COMMIT"
    echo "$OPENCC_COMMIT"
    echo "$YAML_CPP_COMMIT"
    echo "$BOOST_VERSION $BOOST_SHA256"
    shim_sha
    script_sha
  } | shasum -a 256 | cut -d' ' -f1
}

opencc_key() {
  {
    echo "$MARISA_COMMIT"
    echo "$OPENCC_COMMIT"
    script_sha
  } | shasum -a 256 | cut -d' ' -f1
}

cmake_configure() {
  local name="$1" source="$2"
  shift 2
  local bdir="$WORK/$name" generator=""
  command -v ninja >/dev/null 2>&1 && generator="-G Ninja"
  rm -rf "$bdir"
  cmake -S "$source" -B "$bdir" $generator \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="$ARCHS" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    "$@"
}

build_leveldb() {
  echo "==> leveldb $LEVELDB_COMMIT"
  cmake_configure leveldb "$SRC/leveldb" \
    -DBUILD_SHARED_LIBS=OFF \
    -DLEVELDB_BUILD_TESTS=OFF \
    -DLEVELDB_BUILD_BENCHMARKS=OFF \
    -DLEVELDB_INSTALL=ON \
    -DHAVE_SNAPPY=OFF \
    -DHAVE_CRC32C=OFF \
    -DHAVE_TCMALLOC=OFF
  cmake --build "$WORK/leveldb" --parallel
  cmake --install "$WORK/leveldb"
}

build_marisa() {
  echo "==> marisa-trie $MARISA_COMMIT"
  cmake_configure marisa "$SRC/marisa-trie" \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_TESTING=OFF \
    -DENABLE_TOOLS=OFF \
    -DENABLE_NATIVE_CODE=OFF
  cmake --build "$WORK/marisa" --parallel
  cmake --install "$WORK/marisa"
}

build_yaml_cpp() {
  echo "==> yaml-cpp $YAML_CPP_COMMIT"
  cmake_configure yaml-cpp "$SRC/yaml-cpp" \
    -DBUILD_SHARED_LIBS=OFF \
    -DYAML_BUILD_SHARED_LIBS=OFF \
    -DYAML_CPP_BUILD_TESTS=OFF \
    -DYAML_CPP_BUILD_TOOLS=OFF \
    -DYAML_CPP_BUILD_CONTRIB=OFF \
    -DYAML_CPP_INSTALL=ON
  cmake --build "$WORK/yaml-cpp" --parallel
  cmake --install "$WORK/yaml-cpp"
}

build_opencc() {
  echo "==> OpenCC $OPENCC_COMMIT (data and static library)"
  cmake_configure opencc "$SRC/opencc" \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_DOCUMENTATION=OFF \
    -DENABLE_GTEST=OFF \
    -DENABLE_BENCHMARK=OFF \
    -DBUILD_PYTHON=OFF \
    -DUSE_SYSTEM_MARISA=ON \
    -DUSE_SYSTEM_DARTS=OFF \
    -DUSE_SYSTEM_RAPIDJSON=OFF \
    -DUSE_SYSTEM_TCLAP=OFF \
    -DCMAKE_PREFIX_PATH="$PREFIX" \
    -DCMAKE_CXX_FLAGS="-I$PREFIX/include" \
    -DCMAKE_LIBRARY_PATH="$PREFIX/lib" \
    -DCMAKE_EXE_LINKER_FLAGS="-L$PREFIX/lib" \
    -DPYTHON_EXECUTABLE="$(command -v python3)"
  cmake --build "$WORK/opencc" --parallel
  cmake --install "$WORK/opencc"
}

download_boost() {
  mkdir -p "$BOOST_CACHE" "$BUILD/src"
  if [[ ! -f "$BOOST_CACHE/$BOOST_TARBALL" ]]; then
    echo "==> downloading Boost $BOOST_VERSION"
    curl -fL --retry 3 -o "$BOOST_CACHE/$BOOST_TARBALL.part" \
      "https://archives.boost.io/release/$BOOST_VERSION/source/$BOOST_TARBALL"
    mv "$BOOST_CACHE/$BOOST_TARBALL.part" "$BOOST_CACHE/$BOOST_TARBALL"
  fi
  echo "$BOOST_SHA256  $BOOST_CACHE/$BOOST_TARBALL" | shasum -a 256 -c -
  if [[ ! -d "$BOOST_SRC" ]]; then
    tar -xzf "$BOOST_CACHE/$BOOST_TARBALL" -C "$BUILD/src"
  fi
}

build_boost_regex() {
  download_boost
  [[ -f "$BOOST_STAGE/lib/libboost_regex.a" ]] && return
  echo "==> Boost.Regex $BOOST_VERSION (universal static)"
  (
    cd "$BOOST_SRC"
    if [[ ! -x ./b2 ]]; then
      ./bootstrap.sh --with-toolset=clang --with-libraries=regex
    fi
    ./b2 -q -a link=static runtime-link=shared threading=multi variant=release \
      architecture=arm+x86 address-model=64 \
      cxxflags="-arch arm64 -arch x86_64 -mmacosx-version-min=$DEPLOYMENT_TARGET" \
      linkflags="-arch arm64 -arch x86_64 -mmacosx-version-min=$DEPLOYMENT_TARGET" \
      --stagedir="$BOOST_STAGE" stage
  )
  lipo -info "$BOOST_STAGE/lib/libboost_regex.a"
}

patch_librime() {
  local rime_src="$1"
  python3 - "$rime_src/CMakeLists.txt" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()
boost_old = "find_package(Boost 1.77.0)"
boost_new = "find_package(Boost 1.77.0 REQUIRED COMPONENTS regex)"
tools_old = "if(BUILD_SHARED_LIBS)\n  add_subdirectory(tools)\n"
tools_new = "add_subdirectory(tools)\n\nif(BUILD_SHARED_LIBS)\n"
if boost_old not in text or tools_old not in text:
    raise SystemExit("unexpected librime CMakeLists.txt layout")
path.write_text(text.replace(boost_old, boost_new, 1).replace(tools_old, tools_new, 1))
PY
}

build_librime() {
  local rime_src="$BUILD/src/librime" rime_build="$WORK/librime"
  echo "==> librime $LIBRIME_VERSION ($LIBRIME_COMMIT)"
  mkdir -p "$BUILD/src" "$BUILD/bin" "$BUILD/lib"
  rsync -a --delete --exclude='.git' "$SRC/librime/" "$rime_src/"
  patch_librime "$rime_src"

  cmake_configure librime "$rime_src" \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_STATIC=ON \
    -DBUILD_MERGED_PLUGINS=OFF \
    -DENABLE_EXTERNAL_PLUGINS=OFF \
    -DBUILD_TEST=OFF \
    -DBUILD_SAMPLE=OFF \
    -DBUILD_DATA=OFF \
    -DENABLE_LOGGING=OFF \
    -DCMAKE_PREFIX_PATH="$PREFIX" \
    -DCMAKE_INCLUDE_PATH="$PREFIX/include;$BOOST_SRC" \
    -DCMAKE_LIBRARY_PATH="$PREFIX/lib;$BOOST_STAGE/lib" \
    -DBOOST_ROOT="$BOOST_SRC" \
    -DBoost_NO_BOOST_CMAKE=TRUE \
    -DBoost_NO_SYSTEM_PATHS=TRUE

  cmake --build "$rime_build" --parallel --target \
    rime-static rime_deployer rime_dict_manager rime_patch rime_table_decompiler

  local tool
  for tool in rime_deployer rime_dict_manager rime_patch rime_table_decompiler; do
    cp "$rime_build/bin/$tool" "$BUILD/bin/$tool"
  done

  echo "==> compiling gears subset shim"
  local shim_obj="$WORK/gears_subset.o"
  clang++ -std=c++17 -O2 -fPIC \
    -arch arm64 -arch x86_64 -mmacosx-version-min="$DEPLOYMENT_TARGET" \
    -I"$rime_src/src" -I"$rime_src/include" -I"$rime_build/src" \
    -I"$PREFIX/include" -I"$BOOST_SRC" \
    -c "$SHIM_SRC" -o "$shim_obj"
  lipo -info "$shim_obj"

  echo "==> merging static archives"
  rm -f "$BUILD/lib/librime.a"
  libtool -static -o "$BUILD/lib/librime.a" \
    "$shim_obj" \
    "$rime_build/lib/librime.a" \
    "$PREFIX/lib/libyaml-cpp.a" \
    "$PREFIX/lib/libleveldb.a" \
    "$PREFIX/lib/libmarisa.a" \
    "$PREFIX/lib/libopencc.a" \
    "$BOOST_STAGE/lib/libboost_regex.a"
  lipo -info "$BUILD/lib/librime.a"

  echo "==> building static CRime.xcframework"
  local hdr="$BUILD/headers"
  rm -rf "$hdr" "$XCF"
  mkdir -p "$hdr"
  cp "$rime_src/src/rime_api.h" "$rime_src/src/rime_api_stdbool.h" \
     "$rime_src/src/rime_levers_api.h" "$hdr/"
  cat > "$hdr/CRime.h" <<'H'
#include "rime_api_stdbool.h"
#include "rime_api.h"
#include "rime_levers_api.h"

#ifdef __cplusplus
extern "C" {
#endif
void hufu_rime_register_components(void);
int hufu_rime_check_components(void);
#ifdef __cplusplus
}
#endif
H
  cat > "$hdr/module.modulemap" <<'M'
module CRime {
  umbrella header "CRime.h"
  export *
}
M
  mkdir -p "$(dirname "$XCF")"
  xcodebuild -create-xcframework \
    -library "$BUILD/lib/librime.a" -headers "$hdr" \
    -output "$XCF" >/dev/null
}

check_inputs() {
  require_submodule librime "$LIBRIME_COMMIT"
  require_submodule leveldb "$LEVELDB_COMMIT"
  require_submodule marisa-trie "$MARISA_COMMIT"
  require_submodule opencc "$OPENCC_COMMIT"
  require_submodule yaml-cpp "$YAML_CPP_COMMIT"
  [[ -f "$SHIM_SRC" ]] || {
    echo "missing $SHIM_SRC" >&2
    exit 1
  }
}

check_inputs

if [[ "$MODE" == opencc-data ]]; then
  key="$(opencc_key)"
  if [[ -f "$BUILD/.opencc-data.stamp" && "$(cat "$BUILD/.opencc-data.stamp")" == "$key" \
        && -f "$BUILD/lib/libopencc.a" \
        && -f "$BUILD/share/opencc/STPhrases.ocd2" ]]; then
    echo "==> OpenCC data already built ($key)"
    exit 0
  fi
  mkdir -p "$BUILD"
  build_marisa
  build_opencc
  echo "$key" > "$BUILD/.opencc-data.stamp"
  rm -rf "$WORK"
  echo "==> done: $BUILD/share/opencc"
  exit 0
fi

key="$(full_key)"
if [[ -f "$BUILD/.stamp" && "$(cat "$BUILD/.stamp")" == "$key" \
      && -f "$BUILD/lib/librime.a" \
      && -x "$BUILD/bin/rime_deployer" \
      && -f "$BUILD/share/opencc/STPhrases.ocd2" \
      && -d "$XCF" ]]; then
  echo "==> librime already built ($key)"
  exit 0
fi

mkdir -p "$BUILD" "$WORK"
build_leveldb
build_marisa
build_yaml_cpp
build_opencc
build_boost_regex
build_librime

echo "$(opencc_key)" > "$BUILD/.opencc-data.stamp"
echo "$key" > "$BUILD/.stamp"
# Keep the installable outputs and stamps; transient source/build trees only
# bloat the CI cache.
rm -rf "$WORK" "$BUILD/src" "$BOOST_STAGE" "$BOOST_CACHE"
echo "==> done: $BUILD/lib/librime.a and $XCF"
