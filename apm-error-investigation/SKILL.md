---
name: apm-error-investigation
description: Root-cause backend/APM application errors end-to-end — resolve the APM entity, rank candidate TransactionError groups, follow the chosen trace through Span, and correlate Log. Trigger on 'why is my service erroring', 'root cause this error', 'investigate 500s', 'exception in <app>', 'NullPointerException', 'why is <app> failing'. Not for browser JavaScript errors, infra/mobile/synthetic/Kubernetes errors, or issue-id alert insight reports. Investigates one error end-to-end rather than listing candidate traces.
argument-hint: "<app-name-or-entity-guid> [time-window] [error-message]"
---

# APM Error Investigation

Take a backend/APM error signature and produce an evidence-backed root cause. Read `queries.md` for the NRQL
templates and the attribute-coverage reference before hand-writing any query.

Not for browser JavaScript errors (`JavaScriptError` / `AjaxRequest`), nor infra, mobile, synthetic or
Kubernetes errors unless the user narrows to an APM app.

## Tools

Pick whatever fits each step — that judgement is yours, and the available set changes. Purpose-built tools take
typed parameters and resolve attribute names internally, so they sidestep most of the Gotchas below;
hand-written NRQL does not. Either way the constraints in each step describe what the *evidence* must show, not
which tool to call. Do not call `generate_alert_insights_report` — it is evaluated separately. Put decisions to
the user with `AskUserQuestion`, not a prose list.

## Gotchas

Every item below returns **wrong or empty results rather than an error**. Append here whenever a run trips on
something new.

- **A single-account query cannot see a whole distributed trace**, and no rewrite fixes it — the remedy is a
  trace-level tool that resolves the full trace across accounts, returning per-service self-time, the call
  graph, error spans and the slowest path. Measured twice: 269/1233 spans and 2/32 services on one trace,
  25/163 and 1/14 on another, with **the real bottleneck absent both times**. Changes conclusions, not row
  counts.
- **Most errors on a public-facing service are `error.expected = true`** — handled rejections, probe 405s,
  deliberate raises — so a raw `count()` ranks benign traffic first. Measured 89% expected (3,682 of 4,135),
  with the real failures fifth and below.
- **One failure can occupy several ranking rows**: every layer that catches and re-raises writes its own
  `error.class`/`error.message`, so an incident appears two or three times with near-identical counts. Measured
  83 rows over **42 distinct traces**, split 42 + 40. Compare `count(*)` against `uniqueCount(traceId)`, quote
  impact in traces, and treat rows whose messages nest one inside the other as one failure.
- **`TransactionError` has no `trace.id`** — its field is `traceId`. `Log` is the mirror image: `trace.id` only.
  `Span` has both, aliased.
- **`TransactionError` has no usable `entity.guid`** — ~17% populated, so filtering on it silently drops most of
  the entity's errors. Use `entityGuid` there, `entity.guid` on `Span` and `Log`.
- **`response.status` is a string** — a bare `>= 500` returns zero rows; write `numeric(response.status) >= 500`.
  `http.statusCode` is numeric but sparse; `httpResponseCode` is legacy and absent.
- **Zero rows and genuinely absent data are indistinguishable.** Confirm the attribute exists
  (`SELECT keyset() FROM <EventType> SINCE 1 day ago`) before reporting "no data" — ingest path (APM agent vs
  OTel) changes names.
- **NRQL has no relative-to-a-timestamp syntax.** `SINCE 5 minutes BEFORE '<ts>'` is a syntax error; compute
  `SINCE <ts>-300000 UNTIL <ts>+300000` off a timestamp you actually read from a row. A guessed "now" comes back
  as `start time must be before its end time`. For a time window described in words, prefer a tool that converts a
  time expression into epoch bounds.
- **Raw `Log.message` can be a multi-KB HTTP header dump containing `authorization: Bearer …`** — it floods
  context and leaks credentials into the transcript. Always `substring(message, 0, 500)`.
- **Log rows arrive duplicated** (multiple forwarders emit the same line). Dedupe before counting.
- **`level` casing varies** by forwarder — normalise rather than listing spellings:
  `lower(level) IN ('error','fatal','warn','warning')`.
- **A handled exception is logged below `error`** — the stack lands at `warning`, sometimes `debug`. An
  error-only fallback then returns nothing and looks exactly like a logs-in-context gap. Verified on a trace
  whose only levels were `warning`, `debug` and `DEBUG`, with the raising line in the `warning` rows.
- **Logs-in-context gaps are common** — a meaningful fraction of logs are not trace-decorated, so a log miss is
  not evidence of anything.
- **`duration` is in SECONDS**, not milliseconds. `> 2.0`, not `> 2000`.
- **An empty `Span` result does not mean there were no errors** — tracing samples adaptively (a rate per agent,
  not a percentage). `TransactionError` is not sampled the same way.

## Workflow

**0. Handed a trace ID?** (e.g. from `discover-trace`) Skip ranking. Resolve the entity from the trace itself
(`queries.md` §0), confirm it with the user, then jump to step 4.

Reuse the time window the trace arrived with, and reuse it as **absolute epoch bounds** — not a relative
expression like `SINCE 30 minutes ago` re-evaluated now. A relative one slides forward between the two runs and
can leave the trace outside it entirely, returning zero rows that look identical to missing data. If no time
window came with the trace, read the error timestamp via `queries.md` §0 and bound queries to ±30 minutes
around it — wide enough to hold a whole trace plus clock skew between services, tight enough to stay quiet —
and say that is what you did. Either way this time window overrides step 2's default; do not widen it, because
a wider one drags in unrelated errors.

**1. Resolve the target to one APM `APPLICATION` entity.** Use the GUID if given; otherwise look the name up
constrained to that domain and type. What matters is whether **the user's input** identifies one entity, not how
many rows the lookup returned: a search for `checkout` returns every environment, but `checkout (staging)`
matching exactly one entity should resolve silently. Ask only when the ambiguity is real — several equal
matches, or no exact one — presenting environment, account and GUID so the choice is one click. State what you
settled on either way.

**2. Pick one time window and hold it.** Default 24h; ranking by impact needs volume. Log correlation narrows
to ±5 min around the error, which is fine as long as you say so. This default does not apply if you came in
through step 0 — a supplied trace already fixes the time window, and widening it to 24h would undo that.

**3. Rank before you drill. Ordering is the point here.**
- **3a** Aggregate by `error.class` and `error.message`, `count()` descending, filtered to
  **`error.expected IS FALSE`**. Report the excluded volume as one labelled figure rather than hiding it. Rank
  everything instead — and say so — when the user named an expected error, asked about total volume, or nothing
  is unexpected. Apply their message substring first if they gave one.
- **3b** Only then fetch traces for the chosen group, `FACET string(traceId)`. Faceting by trace first cannot
  rank anything — each trace is ~1 row, so every candidate looks equally important. Present the top 10 and say
  if more exist.
- **3c** Check which candidates are actually inspectable before committing (`queries.md` §2c). Prefer one that
  has spans, and say sampling constrained the choice — the user should know they are looking at an available
  trace rather than the worst one.

Do not pick one silently, but do not manufacture a choice either: offer it with `AskUserQuestion` when the top
groups are genuinely close; proceed and name your reason when one clearly dominates, only one returns, or every
other candidate is expected. If nothing matches the user's message, fall back to the latest errors and say so.

**4. Reconstruct what the trace did** — which services were involved, where the time went, which span carried
the error. Use a cross-account trace tool rather than assembling this from single-account span queries (first
gotcha), and sanity-check that the span and service counts look like a whole trace rather than one entity's
slice. Span queries remain right for the narrower question — what one service did in depth, once you know which
service matters. If the chosen trace has no spans at all, fall back to error spans on the entity and say plainly
that it is not the user's trace.

**5. Correlate logs.** `Log` on `trace.id`, ±5 min around the error timestamp, message truncated. With no
correlated logs, fall back to entity logs across levels — not just error and fatal — and report the gap rather
than treating silence as evidence.

**6. Report.** Say what the evidence supports and no more. Keep facts and hypotheses visibly separate; a
plausible story the data merely permits is worse than an honest gap, because it ends the investigation.

## Report

- **Target** — app, entity, account, time window.
- **Selected error** — message, class, transaction, timestamp, trace ID; how many candidates were offered and
  why this one.
- **Trace evidence** — services and spans involved, error spans, slowest span; whether data was sampled away.
- **Log evidence** — correlated logs, fallback logs, or the logs-in-context gap.
- **Impact** — distinct traces rather than summed occurrences, plus affected transactions and hosts.
- **Likely cause** — evidence-backed only, and "unknown" where that is the honest answer.
- **Next actions** — concrete checks or fixes for the owner.

**Evaluation runs only:** also report tool calls used, latency if measured, and any ambiguity or missing data.
A good run resolved the entity without guessing, ranked before drilling into traces, covered the whole trace
rather than the starting entity, held one time window and disclosed any narrowing, and either followed the trace or
explained the sampling gap.

**Do not cache** the resolved entity or GUID between runs — it would stale-target the next investigation. The
account-name-to-ID map is different: stable, and expensive to re-list, so reusing it within a session is fine.
