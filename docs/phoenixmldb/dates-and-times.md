---
title: Dates and Times
description: PhoeniXML DB uses UTC; the date-time forms it accepts, API key expiry, value indexes on dates, and embedded hosts
sort: 17
---

# Dates and Times

PhoeniXML DB uses UTC. A date-time without a timezone is UTC wherever the engine stores, indexes or
compares it. A value written with a timezone (`Z`, `+02:00`) keeps its instant; write an offset to
mean another zone. There is no time-zone setting.

| | gRPC server, EPS REST server | Embedded engine |
|---|---|---|
| Typed dateTime metadata, value-index keys, JSON index keys | UTC | UTC |
| API key `Expires` | UTC | not applicable |
| Comparison in a query or stylesheet (`implicit-timezone()`, `current-dateTime()`, comparing a value that has a timezone with one that has not) | UTC | the zone of the host process ([below](#embedded-engine-in-a-host-that-is-not-in-utc)) |

In both servers `implicit-timezone()` is `PT0S`, and
`xs:dateTime('1996-12-12T13:13:00') < xs:dateTime('1996-12-12T13:13:00-02:00')` is `true`, whatever
the time zone of the machine.

A server process runs in UTC: it sets the `TZ` environment variable of its own process to `UTC` at
startup. Console log timestamps, when turned on without `UseUtcTimestamp`, are UTC. A configuration key
`PhoenixmlDb:Query:ImplicitTimezone` is ignored; the server starts and lists it in the
effective-configuration event (3001).

## What is read as a date-time

Typed dateTime metadata, dateTime value-index keys and API key `Expires` accept these forms and
nothing else:

| Form | Example | Read as |
|---|---|---|
| `yyyy-MM-dd` | `2024-01-15` | that day at 00:00:00 UTC |
| `yyyy-MM-ddTHH:mm:ss`, optional fraction, optional `Z` or `+hh:mm` / `-hh:mm` | `2024-01-15T12:00:00`, `2024-01-15T07:00:00.5-05:00` | UTC when no timezone is written |
| the same with a space in place of `T` | `2024-01-15 12:00:00` | the same |
| RFC 1123 | `Mon, 15 Jan 2024 12:00:00 GMT` | that instant |

The year has four digits (0001 to 9999). Seconds are required. A fraction has any number of digits
and is kept to 100 nanoseconds. Leading and trailing white space is ignored.

Refused, among others: a time with no date (`12:00:00`), a date with no year (`1/15`,
`January 15`), a year and month (`2024-01`), a two-digit year (`1/15/24`), `01/15/2024`,
`2024/01/15`, `2024-1-5`, `2024-01-15T12:00` (no seconds), `2024-01-15T12:00:00+0100`,
`2024-01-15T12:00:00+01`, a lower-case `t` or `z`, `2024-01-15Z`, and seconds since 1970.

A refused text:

- as typed dateTime metadata: the request is refused with the metadata validation error;
- in a document, at a path with a dateTime value index: the document is stored and that value has no
  index key;
- as an API key `Expires`: startup stops, naming the entry.

An `xs:date` in typed metadata or at a path with a date value index is `yyyy-MM-dd` (white space
around it ignored); any other text is refused as metadata and has no index key. An `xs:date` or
`xs:time` value that carries a timezone is refused as typed metadata and has no index key.

## API key expiry

`PhoenixmlDb:Auth:ApiKeys:<n>:Expires` (gRPC server) and `Auth:ApiKey:Clients:<n>:Expires` (EPS REST
server):

- Text in one of the forms above. Without a timezone it is UTC: `2027-01-31` is
  2027-01-31T00:00:00Z.
- Absent: the key does not expire.
- Empty, blank or not in one of the forms: startup stops with a message naming the entry. In the EPS
  REST server such an entry is also never valid when a request presents its key.
- In the options classes `ApiKeyOptions.Expires` (gRPC server) and `ApiKeyClientConfig.Expires` (EPS)
  the property is `string?`.

## Startup log

| Event | Level | Text |
|---|---|---|
| 3010 `ImplicitTimezone` | Information | `The implicit timezone of queries and stylesheets is UTC.` |
| 3011 `ImplicitTimezoneNotUtc` | Warning | Windows only, when the machine's time zone is not UTC ([below](#windows)) |

For each API key with an expiry still ahead, one Information line gives the instant in UTC, the entry
and its Id, for example
`PhoenixmlDb:Auth:ApiKeys:0 (Id 'svc') expires at 2026-12-31T00:00:00.0000000+00:00.` (gRPC server) or
`Auth:ApiKey:Clients:0 (Id 'svc') expires at 2026-12-31T00:00:00.0000000+00:00.` (EPS). A key already
expired has a warning with `expired at` and the instant in UTC. The effective-configuration event
(3001) shows `Expires` as configured.

## Value indexes on dates and times

A value index of type `xs:dateTime`, `xs:date` or `xs:time` answers one comparison: equality between
the attribute and a string literal that is a value of the index's type, for example
`/order[@at = '2024-01-15T12:00:00']`. That comparison is of text: it returns the rows whose attribute
has exactly that text.

Every other comparison on those index types is answered by a scan, with the same result as on a
container that has no index:

- a comparison with a typed value: `@at = xs:dateTime('…')`, `<`, `>=`;
- a comparison with a variable, of any type: `let $x := … return /order[@at = $x]`, an external `$v`;
- a range with a string: `@at >= '2024-01-15T12:00:00Z'`;
- a string literal that is not a value of the index's type: `@day = '2024-01-15Z'`.

For every index type, a string literal that is not a value of the index's type is answered by a scan.
An external variable that holds a CLR `DateTimeOffset` is compared as text by the XQuery library.

The index writer reads numbers and dates with the invariant culture. A value index must be rebuilt
when it was built on a machine whose time zone was not UTC (date-time values without a timezone), or
on a machine whose regional settings were not English/invariant (numbers and dates). Nothing detects
such an index. The rebuild operations:

| Host | Operation |
|---|---|
| EPS REST server | `POST /api/containers/{containerId}/indexes/rebuild` |
| gRPC server | `IndexService.RebuildIndex` |
| Embedded | `DocumentDatabase.RebuildIndexesAsync(containerName)` |

Typed dateTime metadata is stored as an instant. A value stored earlier keeps its instant; a rebuild
does not change it.

## Embedded engine in a host that is not in UTC

The embedded engine does not change the time zone of its host process. In a host that is not in UTC,
what the engine stores and indexes is UTC, and a comparison in a query reads a date-time without a
timezone in the host's zone. With rows a `2024-01-15T12:00:00` and b `2024-01-15T12:00:00Z`, in a host
in America/New_York:

| | Answer in the host | Answer in a UTC process |
|---|---|---|
| `/e[@t = xs:dateTime('2024-01-15T12:00:00')]` | a | a, b |
| `/e[@t = xs:dateTime('2024-01-15T12:00:00Z')]` | b | a, b |
| metadata query for `2024-01-15T12:00:00` | a, b | a, b |

Run the host in UTC (`TZ=UTC`), or write date-times with a timezone.

## Windows

On Windows a process cannot set its own time zone. A server on a Windows machine whose time zone is
UTC logs event 3010. On a machine in another zone it logs warning 3011 and starts; queries and
stylesheets then compare a date-time without a timezone in the machine's zone. What is stored, indexed
and read from configuration is UTC on Windows as elsewhere. Set the machine's time zone to UTC.

See also: [Metadata](metadata.md) · [Indexing](indexing.md) ·
[Server Mode](deployment/server-mode.md) · [Logging and Telemetry](logging.md)
