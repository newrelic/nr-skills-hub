# APM Error Investigation Queries

The hand-written NRQL path, for questions the purpose-built tools don't cover. If a typed tool answers the
step, prefer it — it resolves the attribute names below for you, and most of the traps here stop existing.

## Contents

- Attribute reference — trace-ID field and entity field per event type, and how to join `TransactionError` to `Log`
- §0 Resolve the entity from a trace ID — workflow step 0
- §1 Rank errors by impact — step 3a, plus the status-field preference order
- §2 Candidate traces for the chosen error — step 3b
- §2c Which candidates are inspectable — step 3c, the sampling check
- §3 Follow the trace through spans — step 4, and the fallback when the trace has no spans
- §4 Correlate logs — step 5, epoch-bound arithmetic, and the fallback across log levels
- Zero rows? — the `keyset()` probe and what to try before concluding data is absent

**Query 3 is not sufficient for trace reconstruction, and this is structural — not a query you can improve.**
NRQL is scoped to one account; a distributed trace is not. `FROM Span WHERE traceId = …` returns only the
queried account's slice and gives no sign that the rest exists. Measured twice: 269 of 1233 spans, and 25 of
163 spans, with the real bottleneck missing from both.

For "which service caused this", prefer a trace-level tool that takes a trace ID and resolves the whole trace
across accounts, returning per-service self-time, the service call graph, error spans and the slowest path.
Use query 3 for the narrower job it is good at: inspecting in depth what one service did, once you know which
service matters.

Run with `execute_nrql_query`. `{window}` is the time window agreed in step 2 (default `SINCE 24 hours ago`);
substitute the same value into 1, 2, and 3. `{guid}` is the entity GUID resolved in step 1.

Trace-ID field per event type — `TransactionError` uses **`traceId`**, `Log` uses **`trace.id`**:

| Event | Field |
|---|---|
| `Span` | `traceId` (`trace.id` also works — aliased) |
| `Transaction` | `traceId` |
| `TransactionError` | `traceId` — **there is no `trace.id`** |
| `Log` | `trace.id` — **there is no `traceId`** |

Entity field per event type. Both names exist on `TransactionError`, but only one is reliably populated,
so picking wrong silently undercounts instead of erroring:

| Event | Filter on | Coverage (air-staging) |
|---|---|---|
| `TransactionError` | **`entityGuid`** | 100% — `entity.guid` is only ~17%, dropping ~61% of an entity's errors |
| `Span` | `entity.guid` | populated |
| `Log` | `entity.guid` | populated |

To join `TransactionError` to `Log`, alias the Log side so the keys match:
`FROM Log ... FACET trace.id AS traceId ... ON traceId`.

## 0. Resolve the entity from a trace ID (step 0)

When a trace ID is handed over instead of an app name — confirm the result with the user before investigating.

```sql
SELECT latest(entityGuid), latest(error.class), latest(error.message), latest(timestamp)
FROM TransactionError WHERE traceId = '<id>'
SINCE 30 minutes ago  -- {window}
```

## 1. Rank errors by impact (step 3a)

Answers "which error actually matters". Do this **before** looking at traces — faceting by trace first
yields ~1 row per trace and cannot rank anything.

`AND error.expected IS FALSE` is part of the default, not an option. Handled errors normally outnumber real
ones — 89% of rows on `nrai-mcp-server (staging)` — so without it the ranking is topped by auth rejections
and probe 405s, and the investigation follows the healthy path.

```sql
SELECT count(*) AS occurrences,
       uniqueCount(traceId) AS traces,
       uniqueCount(host) AS hosts,
       latest(transactionName) AS transaction,
       latest(response.status) AS status,
       latest(timestamp) AS lastSeen
FROM TransactionError
WHERE entityGuid = '{guid}'
  AND error.expected IS FALSE
FACET error.class, error.message
SINCE 24 hours ago  -- {window}
LIMIT 10
```

`traces` is the impact figure to quote, not `occurrences`. Each layer that catches and re-raises writes its
own row, so one incident can appear as two or three groups with near-identical counts, and adding them up
overstates it. Verified: a query timeout returned 83 rows over 42 distinct traces, split across a group of 42
(inner exception) and a group of 40 (the wrapper around it). When one group's message contains another's,
collapse them and present the pair as a single failure.

Report what the expected filter removed, so the exclusion is visible rather than silent:

```sql
SELECT count(*) FROM TransactionError
WHERE entityGuid = '{guid}'
FACET error.expected, error.class
SINCE 24 hours ago  -- {window}
LIMIT 20
```

Drop `AND error.expected IS FALSE` — and say that you did — when the user named an expected error, asked
about total volume, or when nothing is unexpected.

Optional filters:
- Message substring: `AND error.message LIKE '%timeout%'`
- Error class: `AND error.class = 'java.lang.NullPointerException'`
- Endpoint: `AND request.uri LIKE '/api/checkout%'`
- Status: `AND numeric(response.status) >= 500` — see the status-field note below

### Status fields, in order of preference

1. **`response.status`** — reliably populated (99.8% of rows in air-staging), but stored as a **string**.
   A bare `WHERE response.status >= 500` silently returns **zero rows**. Always wrap it:
   `numeric(response.status) >= 500`.
2. **`http.statusCode`** — genuinely numeric, so it compares directly, but sparsely populated
   (3.8% in air-staging). Use only if `response.status` is absent.
3. **`httpResponseCode`** — legacy, absent on current agents. Do not use.

Check which one your target populates before filtering on it:
`SELECT filter(count(*), WHERE response.status IS NOT NULL), filter(count(*), WHERE http.statusCode IS NOT NULL), count(*) FROM TransactionError WHERE entityGuid = '{guid}' SINCE 24 hours ago`

## 2. Candidate traces for the chosen error (step 3b)

```sql
SELECT latest(timestamp) AS occurredAt,
       latest(error.class) AS errorClass,
       latest(error.message) AS errorMessage,
       latest(transactionName) AS transaction,
       latest(host) AS host,
       latest(request.uri) AS uri,
       count(*) AS occurrences
FROM TransactionError
WHERE entityGuid = '{guid}'
  AND error.class = '{chosen class}'
  AND traceId IS NOT NULL
FACET string(traceId)
SINCE 24 hours ago  -- {window}
LIMIT 10
```

Keep `latest(timestamp)` — it is epoch ms and anchors the ±5 min time window for the logs in query 4.

## 2c. Which candidates are inspectable (step 3c)

Sampling removes most candidates — 9 of 10 on two separate measurements. Settle it in one query before
committing to a trace, and prefer a candidate that has spans.

```sql
SELECT count(*) AS spans, uniqueCount(entity.name) AS services
FROM Span WHERE traceId IN ('<id1>','<id2>',…)
FACET string(traceId)
SINCE 24 hours ago  -- {window}
LIMIT 20
```

A count here reflects only this account's slice, so use it to answer "can I follow this trace at all", not
"how big is it" — see the query 3 preamble.

## 3. Follow the trace through spans (step 4)

```sql
SELECT name, duration, entity.name, category, error, span.kind
FROM Span
WHERE traceId = '{trace id}'
SINCE 24 hours ago  -- {window}
LIMIT MAX
```

Narrow to what failed or what was slow:
- Error spans only: `AND error IS TRUE`
- Slowest first: `ORDER BY duration DESC`
- One service: `AND entity.guid = '{guid}'`

Fallback when the chosen trace has no spans (sampling) — find error spans on the same entity instead:

```sql
SELECT latest(timestamp), latest(name), max(duration)
FROM Span
WHERE entity.guid = '{guid}' AND error IS TRUE
FACET string(traceId)
SINCE 24 hours ago  -- {window}
LIMIT 10
```

## 4. Correlate logs (step 5)

`Log` uses dot notation. Narrow to ±5 min around `occurredAt` from query 2 and say that you narrowed.

`occurredAt` is epoch **milliseconds**, so compute the bounds yourself: `SINCE occurredAt - 300000 UNTIL
occurredAt + 300000`, substituting the two integers. NRQL has no relative-to-a-timestamp form — the
`SINCE 5 minutes BEFORE '<ts>'` shape is a **syntax error** (`unexpected 'BEFORE'`).

Anchor the arithmetic to the `occurredAt` you read from query 2, not to a guess at the current time. Tools
that take typed epoch bounds reject a guessed "now" with `start time must be before its end time`. When the
time window is expressed in words instead of anchored to an error row, prefer a tool that converts a time
expression into epoch bounds over computing them yourself.

```sql
SELECT timestamp, level, substring(message, 0, 500) AS msg
FROM Log
WHERE trace.id = '{trace id}'
SINCE 1786098342080 UNTIL 1786098942080  -- occurredAt -/+ 300000
LIMIT 20
```

**Always truncate `message`.** Verified on a real trace: some log lines are full HTTP header dumps
thousands of characters long, including `authorization: Bearer …`. Selecting raw `message` floods context
and can surface credentials into the transcript. `substring(message, 0, 500)` keeps it readable; widen only
for a specific line you have already identified as interesting.

Expect apparent **duplicate rows** — the same line often appears twice (multiple log forwarders). Dedupe
when summarizing; it is not two separate events.

Fallback when the trace has no correlated logs — entity logs in the same time window:

```sql
SELECT timestamp, level, substring(message, 0, 500) AS msg
FROM Log
WHERE entity.guid = '{guid}'
  AND lower(level) IN ('error', 'fatal', 'warn', 'warning')
SINCE 1786098342080 UNTIL 1786098942080  -- occurredAt -/+ 300000
LIMIT 20
```

`level` casing varies by forwarder (`ERROR` vs `error`), so normalise with `lower(level)` rather than listing
spellings.

**Include `warn`/`warning`.** A handled exception logs its stack below error level — verified on a trace whose
only levels were `warning`, `debug` and `DEBUG`, with the raising line (`raise McpAuthenticationError`) in the
`warning` rows. An error-and-fatal-only filter returns nothing there and is indistinguishable from missing
logs. If even this is empty, widen to all levels for the trace before concluding anything:

```sql
SELECT count(*) FROM Log
WHERE entity.guid = '{guid}' FACET level
SINCE 1786098342080 UNTIL 1786098942080
```

If this returns rows but query 4 did not, that is a **logs-in-context gap**: the logs exist but are not
trace-decorated. Report it as a gap, not as absence of evidence.

## Zero rows?

Do this before concluding the data is missing — the usual cause is a field name that differs by ingest path
(APM agent vs OTel), and a wrong field name returns empty rather than erroring:

```sql
SELECT keyset() FROM TransactionError SINCE 1 day ago
```

Then, in order: widen the time window, drop filters one at a time, and only then conclude the data is absent.
