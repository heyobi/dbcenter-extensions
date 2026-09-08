#!/bin/bash
# Build pg_duckdb for one PostgreSQL major version and package it so it loads on
# a machine that has nothing installed.
#
# Same packaging rule as the PostGIS builder: the module and everything it links
# against, minus what glibc already provides, with an $ORIGIN RUNPATH so the
# loader finds the bundle instead of the system paths. pg_duckdb's own Makefile
# hardcodes an rpath pointing at the PostgreSQL lib directory of the build
# machine, which is not where anything is on the user's machine.
set -euo pipefail

DUCK_VER="${DUCK_VER:-v1.1.1}"
PG_VER="${PG_VER:-18}"
JOBS="${JOBS:-2}"          # DuckDB's translation units are enormous; -j4 on a
                           # 11 GB machine gets this OOM-killed.
OUTPUT_DIR=/packages
mkdir -p "$OUTPUT_DIR"

ARCH=$(uname -m); [ "$ARCH" = "x86_64" ] && ARCH=amd64
PKG="pg_duckdb-${DUCK_VER#v}-linux-${ARCH}-pg${PG_VER}.tar.gz"

echo ">>> pg_duckdb ${DUCK_VER} -> PostgreSQL ${PG_VER}"

# The DuckDB submodule is the expensive part of the checkout and does not change
# between PostgreSQL versions, so the source tree is shared across a build-all
# run and only the PostgreSQL-specific objects are rebuilt.
SRC=/build/pg_duckdb
if [ ! -d "$SRC" ]; then
    git clone --depth 1 --branch "$DUCK_VER" --recurse-submodules --shallow-submodules \
        https://github.com/duckdb/pg_duckdb "$SRC"
fi

cd "$SRC"
export PATH="/usr/lib/postgresql/${PG_VER}/bin:$PATH"

# DuckDB itself is PostgreSQL-agnostic, so it is built once and reused. Only the
# extension objects, which include PostgreSQL headers, are cleaned per version.
if [ ! -f third_party/duckdb/build/release/src/libduckdb.so ]; then
    echo ">>> building DuckDB (this is the long part)"
    # MAKEFLAGS does not reach ninja, which picks its own parallelism from the
    # core count and ignores it. DuckDB compiles unity translation units that
    # each want several gigabytes, so the default of nproc+2 exhausts memory
    # before it exhausts the file list. CMAKE_BUILD_PARALLEL_LEVEL is the knob
    # `cmake --build` actually reads.
    CMAKE_BUILD_PARALLEL_LEVEL="${JOBS}" \
        make duckdb > /duckdb.log 2>&1 \
        || { echo "!! DuckDB build failed"; grep -B2 "error\|exhausted" /duckdb.log | tail -30; exit 1; }
fi

find src -name '*.o' -delete
make -j"${JOBS}" > /make.log 2>&1 \
    || { echo "!! make failed"; tail -40 /make.log; exit 1; }

STAGING="/build/dist_pg${PG_VER}"
rm -rf "$STAGING"; mkdir -p "$STAGING/lib" "$STAGING/share/extension"

cp pg_duckdb.so "$STAGING/lib/"
cp third_party/duckdb/build/release/src/libduckdb.so "$STAGING/lib/"
cp sql/pg_duckdb--*.sql "$STAGING/share/extension/"
cp pg_duckdb.control    "$STAGING/share/extension/"

# httpfs, parquet and json do not need fetching: pg_duckdb builds DuckDB with
# DUCKDB_EXTENSION_HTTPFS_LINKED, _PARQUET_LINKED and _JSON_LINKED, so reading
# Parquet over s3:// is compiled into libduckdb.so. That matters beyond saving a
# download - a database that has to reach extensions.duckdb.org before it can
# answer its first query is not the offline-capable thing DBCenter claims to be.
for want in HTTPFS PARQUET JSON; do
    grep -q "DUCKDB_EXTENSION_${want}_LINKED" /duckdb.log \
        || { echo "!! DuckDB was built without ${want} linked in; s3:// Parquet reads would need a download at run time"; exit 1; }
done

SYSTEM_LIBS='^(linux-vdso|ld-linux|libc|libm|libdl|libpthread|librt|libresolv|libgcc_s|libstdc\+\+)\.'

echo ">>> bundling dependencies"
queue=$(ls "$STAGING"/lib/*.so)
seen=""
while [ -n "$queue" ]; do
    next=""
    for obj in $queue; do
        for dep in $(ldd "$obj" 2>/dev/null | awk '/=> \// {print $3}'); do
            base=$(basename "$dep")
            echo "$base" | grep -qE "$SYSTEM_LIBS" && continue
            case " $seen " in *" $base "*) continue ;; esac
            seen="$seen $base"
            cp -L "$dep" "$STAGING/lib/$base"
            next="$next $STAGING/lib/$base"
            echo "    + $base"
        done
    done
    queue="$next"
done

for so in "$STAGING"/lib/*.so*; do
    patchelf --set-rpath '$ORIGIN' "$so" 2>/dev/null || true
done

# An archive whose module cannot resolve its own libduckdb installs cleanly and
# fails at CREATE EXTENSION. Prove the loader is satisfied before packaging.
if ldd "$STAGING/lib/pg_duckdb.so" 2>/dev/null | grep -q "not found"; then
    echo "!! pg_duckdb.so has unresolved libraries after bundling:"
    ldd "$STAGING/lib/pg_duckdb.so" | grep "not found"
    exit 1
fi

tar -czf "$OUTPUT_DIR/$PKG" -C "$STAGING" .
echo ">>> built $PKG"
ls -la "$OUTPUT_DIR/$PKG"
