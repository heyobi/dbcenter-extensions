#!/bin/bash
# Build PostGIS for one PostgreSQL major version and package it the way
# DBCenter expects: a tarball whose root mirrors the PostgreSQL installation.
set -euo pipefail

GIS_VER="${GIS_VER:-3.6.1}"
PG_VER="${PG_VER:-18}"
JOBS="${JOBS:-2}"          # Deliberately modest: the full -j$(nproc) has been
                           # enough to get this build OOM-killed.
OUTPUT_DIR=/packages
mkdir -p "$OUTPUT_DIR"

ARCH=$(uname -m); [ "$ARCH" = "x86_64" ] && ARCH=amd64
PKG="postgis-${GIS_VER}-linux-${ARCH}-pg${PG_VER}.tar.gz"

echo ">>> PostGIS ${GIS_VER} -> PostgreSQL ${PG_VER}"

if [ ! -d "postgis-${GIS_VER}" ]; then
    wget -q "https://download.osgeo.org/postgis/source/postgis-${GIS_VER}.tar.gz"
    tar -xzf "postgis-${GIS_VER}.tar.gz"
fi

cd "postgis-${GIS_VER}"
./configure --with-pgconfig="/usr/lib/postgresql/${PG_VER}/bin/pg_config" > /configure.log 2>&1 \
    || { echo "!! configure failed"; tail -30 /configure.log; exit 1; }
make -j"${JOBS}" > /make.log 2>&1 \
    || { echo "!! make failed"; tail -40 /make.log; exit 1; }

STAGING="dist_${GIS_VER}_pg${PG_VER}"
rm -rf "$STAGING"; mkdir -p "$STAGING/lib" "$STAGING/share/extension"

find . -name "postgis-*.so"              -exec cp {} "$STAGING/lib/" \;
find . -name "rtpostgis-*.so"            -exec cp {} "$STAGING/lib/" \; || true
find . -name "postgis_topology-*.so"     -exec cp {} "$STAGING/lib/" \; || true
find . -name "address_standardizer-*.so" -exec cp {} "$STAGING/lib/" \; || true
find extensions -name "*.sql"     -exec cp {} "$STAGING/share/extension/" \;
find extensions -name "*.control" -exec cp {} "$STAGING/share/extension/" \;

# A tarball with no loadable module installs cleanly and then fails at CREATE
# EXTENSION, which is a miserable thing to debug. Refuse to produce one.
if ! ls "$STAGING"/lib/*.so >/dev/null 2>&1; then
    echo "!! no shared object was produced; refusing to package"
    exit 1
fi

tar -czf "$OUTPUT_DIR/$PKG" -C "$STAGING" .
echo ">>> built $PKG"
ls -la "$OUTPUT_DIR/$PKG"
tar tzf "$OUTPUT_DIR/$PKG" | head -20
