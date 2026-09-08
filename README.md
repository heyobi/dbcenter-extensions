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
