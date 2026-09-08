# DBCenter extension builds

Prebuilt PostgreSQL extensions for [DBCenter](https://db.center), which downloads
them on first use and unpacks them into its embedded PostgreSQL installation.

They live here rather than in the engine's own repository because that one is
private, and GitHub only serves release assets from a private repository to
authenticated callers - which the engine, downloading anonymously on a user's
machine, is not.

## What is published

| Extension | Upstream | Licence |
|---|---|---|
| PostGIS | [postgis.net](https://postgis.net) | GPL-2.0-or-later |
| pgvector | [github.com/pgvector/pgvector](https://github.com/pgvector/pgvector) | PostgreSQL |
| pgsql-http | [github.com/pramsey/pgsql-http](https://github.com/pramsey/pgsql-http) | MIT |

These are builds of other people's software. The copyright and licence of each
belongs to its authors; this repository only carries binaries.

Provenance differs by platform, and it matters for the GPL obligation that comes
with redistributing PostGIS:

- **Linux** archives are compiled from upstream source by the scripts in
  `build-systems/`, which fetch the release tarballs from the projects
  themselves. Any of them can be reproduced by running the Dockerfile.
- **Windows PostGIS** archives are repackaged from the official PostGIS Windows
  bundles rather than compiled here; `build-systems/` only renames and restructures
  them. Their source is the one PostGIS publishes alongside those bundles.

## Naming

`<name>-<version>-<platform>-pg<major>.<tar.gz|zip>`, for example
`vector-0.8.1-linux-amd64-pg18.tar.gz`. Release assets are a flat namespace, so
the file name carries everything needed to identify a build.

A build is specific to one PostgreSQL major version. PostgreSQL stamps every
loadable module with the major version it was compiled against and refuses to
load one that disagrees, so a pg17 build is not a fallback for a pg18 server.

## Verification

Every archive's SHA-256 is pinned in the engine's source, in
`EXTENSION_CHECKSUMS`. The engine refuses anything whose digest is not pinned or
does not match, so this host is not trusted: a tampered asset fails even if the
account publishing it is compromised. `checksums.txt` on each release lists the
same digests for convenience; it is not what the engine checks against.

## Bundled dependencies

Linux PostGIS archives carry the libraries PostGIS links against - GEOS, PROJ and
their own dependencies - beside the modules, with an `$ORIGIN` RUNPATH so the
loader finds them there. Without that the module fails to load on any machine
that does not already have GEOS and PROJ installed, which is most of them.

`libc`, `libm`, `libpthread`, `libgcc_s` and `libstdc++` are deliberately left to
the host: they are ABI-sensitive, PostgreSQL has already loaded its own, and a
second copy is how symbol conflicts happen.

Raster support is left out of the PostgreSQL 18 build. It is what pulls in GDAL,
whose dependency closure is both large and exactly the set most likely to collide
with what the host has loaded.

## pg_duckdb

`pg_duckdb-<version>-linux-amd64-pg<major>.tar.gz`, PostgreSQL 14 through 18.

This is the one set of archives here that is not compiled by these build
systems. The modules come from the pg_duckdb project's own release images
(`pgduckdb/pgduckdb:<major>-v<version>`) and are repackaged the way everything
else is: the libraries they link against bundled beside them, `$ORIGIN` RUNPATH
so the loader finds them there. pg_duckdb's own Makefile writes an rpath
pointing at its build machine's PostgreSQL lib directory, which is nowhere on a
user's machine.

`build-systems/pg_duckdb` builds it from source and is how to reproduce or
replace them. It vendors DuckDB and compiles it, which is long and wants real
memory - `DISABLE_UNITY=1` is set because DuckDB's unity translation units do
not fit in a modest machine, and parallelism goes through
`CMAKE_BUILD_PARALLEL_LEVEL` because ninja ignores `MAKEFLAGS`.

There is no Windows build.
