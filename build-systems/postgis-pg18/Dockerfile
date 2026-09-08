# PostGIS for PostgreSQL 18 on Linux.
#
# The original build system tops out at PostGIS 3.5.0, and every version up to
# that failed against PostgreSQL 18 with a source incompatibility - PostGIS only
# gained PostgreSQL 18 support in 3.6. That left the default configuration of
# DBCenter, which is PostgreSQL 18, unable to install PostGIS on Linux at all.
#
# This image builds 3.6.1, the same version already repackaged for Windows.
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      wget ca-certificates gnupg2 lsb-release \
      build-essential \
      # PostGIS's configure finds json-c through pkg-config. Without it the
      # build quietly comes out with no GeoJSON support and ST_GeomFromGeoJSON
      # fails at run time with "You need JSON-C".
      pkg-config \
      libxml2-dev libjson-c-dev libprotobuf-c-dev protobuf-c-compiler \
      libgeos-dev libproj-dev \
      patchelf \
 && rm -rf /var/lib/apt/lists/*

RUN echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
      > /etc/apt/sources.list.d/pgdg.list \
 && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
 && apt-get update \
 && apt-get install -y --no-install-recommends postgresql-server-dev-18 \
 && rm -rf /var/lib/apt/lists/*

COPY builder.sh /builder.sh
RUN chmod +x /builder.sh
WORKDIR /build
ENTRYPOINT ["/builder.sh"]
