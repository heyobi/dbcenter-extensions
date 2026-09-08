# pg_duckdb for PostgreSQL 14 through 18 on Linux.
#
# This is the extension that keeps the columnar read advantage without asking
# the user to speak a second protocol. DBCenter keeps cold data as Parquet on
# object storage; measured on this machine a columnar aggregate over that
# Parquet runs about 8x faster than the same aggregate in PostgreSQL, but
# DBCenter threw that away by materialising the Parquet into PostgreSQL tables
# before answering. pg_duckdb lets the read happen where it is fast - DuckDB,
# straight off object storage - while the client is still talking to PostgreSQL
# on port 5432 and does not have to know.
#
# pg_duckdb vendors DuckDB and builds it from source, so this image is large and
# the build is long. It is a release artifact, built once per version.
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      wget ca-certificates gnupg2 lsb-release git \
      build-essential cmake ninja-build pkg-config python3 \
      # DuckDB's httpfs extension, which is the whole point here, links these.
      libssl-dev libcurl4-openssl-dev liblz4-dev \
      patchelf \
 && rm -rf /var/lib/apt/lists/*

RUN echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
      > /etc/apt/sources.list.d/pgdg.list \
 && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      postgresql-server-dev-14 postgresql-server-dev-15 postgresql-server-dev-16 \
      postgresql-server-dev-17 postgresql-server-dev-18 \
 && rm -rf /var/lib/apt/lists/*

COPY builder.sh /builder.sh
RUN chmod +x /builder.sh
WORKDIR /build
ENTRYPOINT ["/builder.sh"]
