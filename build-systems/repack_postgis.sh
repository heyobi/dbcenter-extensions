#!/bin/bash
# Move a PostGIS bundle's dependency libraries out of the shared module
# directory and into one of its own.
#
# Two bundles that both drop their libraries into <pg_root>/lib overwrite each
# other: PostGIS and pg_duckdb ship different builds of libcurl under the same
# soname, and installing both left one of them broken. pg_duckdb already keeps
# its libraries in lib/pg_duckdb-libs; this does the same for PostGIS.
set -euo pipefail

IN=$1
OUT=$2

rm -rf /stage && mkdir -p /stage
tar xzf "$IN" -C /stage

cd /stage/lib
mkdir -p postgis-libs

moved=0
for f in *.so*; do
    [ -f "$f" ] || continue
    case "$f" in
        lib*)                       # a dependency, not a PostgreSQL module
            mv "$f" postgis-libs/
            patchelf --set-rpath '$ORIGIN' "postgis-libs/$f"
            moved=$((moved + 1))
            ;;
        *)                          # postgis-3.so and friends stay put
            patchelf --set-rpath '$ORIGIN/postgis-libs' "$f"
            ;;
    esac
done

if [ "$moved" -eq 0 ]; then
    echo "$(basename "$IN"): bundles no libraries, leaving it alone" >&2
    exit 3
fi

# Every module must still resolve against the new layout.
for f in *.so; do
    if ldd "$f" 2>/dev/null | grep -q "not found"; then
        echo "$(basename "$IN"): $f has unresolved libraries after the move" >&2
        ldd "$f" | grep "not found" >&2
        exit 1
    fi
done

cd /stage
tar czf "$OUT" ./*
echo "$(basename "$IN"): moved $moved libraries into lib/postgis-libs"
