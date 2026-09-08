#!/usr/bin/env bash
# Rebuild the Linux PostGIS archives with their dependencies bundled.
#
# The published ones carry the PostGIS modules alone, so they only load where
# GEOS and PROJ already are. Only the newest PostGIS each major can take is
# built: that is what version resolution picks anyway.
set -uo pipefail
for spec in "3.5.0 12" "3.5.0 13" "3.5.0 14" "3.5.0 15" "3.5.0 16" "3.5.0 17" "3.6.1 18"; do
    set -- $spec
    echo "############ PostGIS $1 -> PostgreSQL $2 ############"
    docker run --rm --memory=4g -e JOBS=2 -e GIS_VER="$1" -e PG_VER="$2" \
        -v ~/calisma/dbcenter-extensions/pg18-out:/packages \
        postgis-pg18-builder || echo "!! $1/pg$2 FAILED"
done
echo "=== HEPSI BITTI ==="
ls -la ~/calisma/dbcenter-extensions/pg18-out/
