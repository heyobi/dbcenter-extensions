#!/bin/bash
# Build PostGIS for one PostgreSQL major version and package it so it loads on a
# machine that has nothing installed.
#
# The archives this replaces carried the PostGIS modules and nothing else, so on
# any machine without libgeos and libproj already present the module failed to
# load - which is every machine the "no installation headaches" promise is aimed
# at. The libraries PostGIS links against are bundled beside it now, and the
# modules carry an $ORIGIN RUNPATH so the loader finds them there.
#
# Raster support is left out. It is what drags in GDAL, and GDAL's own closure -
# curl, gnutls, krb5, ldap, icu - is both large and exactly the set most likely
# to collide with what the host already has loaded.
set -euo pipefail

GIS_VER="${GIS_VER:-3.6.1}"
PG_VER="${PG_VER:-18}"
JOBS="${JOBS:-2}"          # Deliberately modest: -j$(nproc) has been enough to
                           # get this build OOM-killed.
OUTPUT_DIR=/packages
mkdir -p "$OUTPUT_DIR"

ARCH=$(uname -m); [ "$ARCH" = "x86_64" ] && ARCH=amd64
PKG="postgis-${GIS_VER}-linux-${ARCH}-pg${PG_VER}.tar.gz"

echo ">>> PostGIS ${GIS_VER} -> PostgreSQL ${PG_VER} (without raster)"

if [ ! -d "postgis-${GIS_VER}" ]; then
    wget -q "https://download.osgeo.org/postgis/source/postgis-${GIS_VER}.tar.gz"
    tar -xzf "postgis-${GIS_VER}.tar.gz"
fi

cd "postgis-${GIS_VER}"
./configure --with-pgconfig="/usr/lib/postgresql/${PG_VER}/bin/pg_config" \
            --without-raster > /configure.log 2>&1 \
    || { echo "!! configure failed"; tail -30 /configure.log; exit 1; }

# configure does not fail when an optional dependency is missing; it disables the
# feature and carries on. That is how a build shipped without GeoJSON support and
# only announced it at run time, from inside a user's query. Check for what the
# geo API actually calls.
# The macro names differ: json-c is a HAVE_, while PROJ and GEOS record their
# version instead. Checking for the wrong name fails a build that is fine.
echo ">>> configured with:"
check_macro() {
    if grep -qE "^#define $1( |\t)" postgis_config.h 2>/dev/null; then
        echo "    $2: $(grep -E "^#define $1( |\t)" postgis_config.h | head -1 | awk '{print $3}')"
    else
        echo "!! $2 is missing, so the functions that need it would fail at run time"
        grep -iE "json|proj|geos" /configure.log | tail -20
        exit 1
    fi
}
check_macro HAVE_LIBJSON          "GeoJSON (json-c)"
check_macro POSTGIS_PROJ_VERSION  "PROJ"
check_macro POSTGIS_GEOS_VERSION  "GEOS"
make -j"${JOBS}" > /make.log 2>&1 \
    || { echo "!! make failed"; tail -40 /make.log; exit 1; }

STAGING="dist_${GIS_VER}_pg${PG_VER}"
rm -rf "$STAGING"; mkdir -p "$STAGING/lib" "$STAGING/share/extension"

find . -name "postgis-*.so"              -exec cp {} "$STAGING/lib/" \;
find . -name "postgis_topology-*.so"     -exec cp {} "$STAGING/lib/" \; || true
find . -name "address_standardizer-*.so" -exec cp {} "$STAGING/lib/" \; || true
find extensions -name "*.sql"     -exec cp {} "$STAGING/share/extension/" \;
find extensions -name "*.control" -exec cp {} "$STAGING/share/extension/" \;

# Bundle the transitive closure, minus what every glibc system already provides.
# Those are deliberately left to the host: they are ABI-sensitive, PostgreSQL has
# already loaded its own, and a second copy is how you get symbol conflicts.
SYSTEM_LIBS='^(linux-vdso|ld-linux|libc|libm|libdl|libpthread|librt|libresolv|libgcc_s|libstdc\+\+)\.'

collect_deps() {
    ldd "$1" 2>/dev/null | awk '/=> \// {print $3}'
}

echo ">>> bundling dependencies"
queue=$(ls "$STAGING"/lib/*.so)
seen=""
while [ -n "$queue" ]; do
    next=""
    for obj in $queue; do
        for dep in $(collect_deps "$obj"); do
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

# Look next to me first. Without this the loader only searches the system paths,
# which is where the libraries are not.
for so in "$STAGING"/lib/*.so*; do
    patchelf --set-rpath '$ORIGIN' "$so" 2>/dev/null || true
done

# An archive with no loadable module installs cleanly and then fails at CREATE
# EXTENSION, which is a miserable thing to debug. Refuse to produce one.
if ! ls "$STAGING"/lib/postgis-*.so >/dev/null 2>&1; then
    echo "!! no postgis module was produced; refusing to package"
    exit 1
fi

tar -czf "$OUTPUT_DIR/$PKG" -C "$STAGING" .
echo ">>> built $PKG"
ls -la "$OUTPUT_DIR/$PKG"
echo ">>> bundled libraries:"
ls "$STAGING"/lib/
