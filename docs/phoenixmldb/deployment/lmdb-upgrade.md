---
title: Upgrading to LMDB 1.0
description: The storage engine moved from LMDB 0.9 to 1.0; detecting and migrating 0.9 files, rolling upgrades and rollback
sort: 5
---

# Upgrading to LMDB 1.0

Since phoenixml `main` ee0c056, the storage engine uses LightningDB 0.23.1 (LMDB 1.0.1). LMDB 0.9
and 1.0 files can't read each other. The engine has had no public release on LMDB 0.9, so this
affects only databases created with earlier internal builds.

## What changes

- **0.9 files are detected and refused before LMDB opens them.** That covers a database, a Raft
  log, a backup file, a restore stream and a cluster snapshot. The engine throws
  `LmdbMigrationRequiredException`, whose message names the command to run; the file isn't touched.
  `LmdbFileFormatDetector.Detect(path)` reports a file's format (`LmdbFileFormatKind`).
- **Linux needs glibc 2.38 or later.** Debian 12, Ubuntu 22.04, RHEL 9 and Amazon Linux 2023 are not
  supported; Ubuntu 24.04 and the `mcr.microsoft.com/dotnet/aspnet:10.0` image are.
- LightningDB 0.23.1 no longer includes native libraries for browser WebAssembly or iOS (arm).
- **Restores are staged.** Every restore path writes `data.mdb.restore.tmp`, flushes it and checks
  its format before replacing anything. A restore needs a stopped database and throws
  `InvalidOperationException` if the database is open in this or another process.
- **Keys are limited to 511 bytes on every platform**, as before (LMDB 1.0's own limit is larger and
  depends on the page size). Values in duplicate-sorted databases are limited to 511 bytes too.
- For code that uses `LmdbStorageEngine` directly: LMDB 1.0 refuses an empty value in a
  duplicate-sorted database.

## Migrating a 0.9 database

Use the `PhoenixmlDb.Migrate` tool. It isn't yet published as a package. **Stop the database first**:
nothing may have the directory open, in any process, or the tool refuses.

```bash
PhoenixmlDb.Migrate <envDir> [--map-size <bytes>]          # a database or Raft log directory, in place
PhoenixmlDb.Migrate --backup <in.mdb> <out.mdb>            # one backup file, into a new file
```

The tool exports the 0.9 data through a separate process (`PhoenixmlDb.Migrate.Export`), writes a
new 1.0 file, reads every database back, and compares each one's entry count and SHA-256 with the
original. Only then is the original `data.mdb` renamed to `data.mdb.v09`; it's never modified. The
new file's map size defaults to twice the data in use (at least 1 MiB); `--map-size` overrides it.
Run the tool as the user the database runs as, since the new file belongs to whoever runs it.

| Exit code | Meaning |
|---|---|
| 0 | Migrated, or an interrupted migration was completed |
| 1 | Failed (an LMDB or I/O error, or a map size that's too small); the original wasn't replaced |
| 2 | Bad arguments |
| 3 | Nothing to migrate: already LMDB 1.0, no data file, or not an LMDB file |
| 4 | Refused: the database is open, `data.mdb.v09` or the output already exists, another migration is running, the data changed during migration, or `data.mdb` is missing beside `data.mdb.v09` |
| 5 | Verification failed; the original wasn't replaced |
| 6 | The export tool is missing, failed or timed out |
| 7 | The data holds an entry LMDB 1.0 can't store (the message names it) |

Verification proves the copy equals what LMDB 0.9 read. LMDB 0.9 keeps no checksums, so it can't
prove the original was undamaged.

### Embedded applications and single servers

Stop the application or server, run `PhoenixmlDb.Migrate` on the data directory, then start the new
version. Migrate any backups you might restore with `--backup`.

### A Raft cluster, one node at a time

The bytes of replicated commands and log entries are the same before and after the upgrade, so
nodes can be upgraded one at a time: stop the node, migrate its database directory and its Raft log
directory, then start it on the new version. A snapshot sent by a node still on LMDB 0.9 is refused,
so finish the rolling upgrade before a lagging node needs a snapshot. A real mixed-version cluster
hasn't been run.

## Rolling back

Stop the database, remove the new `data.mdb`, rename `data.mdb.v09` to `data.mdb`, and run the
previous version. Removing `lock.mdb` too is harmless but not needed. A migrated directory also keeps
`.phoenixml-migrate.lock`, the tool's guard against two migrations at once; it can stay or go.

## Known limits

- Windows hasn't been measured, and on Windows LMDB preallocates `data.mdb` to the full map size,
  so choose `--map-size` deliberately there.
- Only the linux-x64 build of the tool has been run.
- There's no up-front disk-space check. The export needs a little over twice the data, plus the new
  file; running out of space fails with the original untouched.

## Events

Migration and restore log storage events 1015–1021; see
[Logging and Telemetry](../logging.md).
