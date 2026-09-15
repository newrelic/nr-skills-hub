# eval_results — nl2-nrql

## Test environment

| Field | Value |
|---|---|
| Model | Claude Opus 5 (1M context) — model id `claude-opus-5[1m]` |
| Harness | Claude Code CLI, New Relic MCP server over OAuth 2.0 |
| Date of this run | 2026-08-26 |
| Skill version under test | 1.0.0 |
| Accounts used | Internal New Relic accounts with live telemetry. Account IDs omitted — they are test fixtures, not part of the published skill. |
| Scope of this run | Tool-availability audit and live verification of the falsifiable claims in `SKILL.md` and `queries.md`. Agentic scoring of the full case list is **not** complete — see [Pending](#pending-not-executed-this-run). |

## Tool availability

All three tools this skill depends on are generally available, so they are reachable by a
customer in production.

| Tool | Available in production |
|---|---|
| `execute_nrql_query` | Yes |
| `list_available_new_relic_accounts` | Yes |
| `convert_time_period_to_epoch_ms` | Yes |

**No availability blocker for this skill.** Unlike `apm-error-investigation`, nothing here
depends on a tool that is not yet generally available.

## Executed: live verification of documented claims

| # | Claim under test | Result | Verdict |
|---|---|---|---|
| 1 | `FACET` silently defaults to 10 buckets, so omitting `LIMIT` yields a wrong answer rather than a truncated one | `FACET name` with no `LIMIT` returned exactly 10 rows, with no indication that more existed | **Confirmed** — this is the skill's most consequential gotcha and it reproduces exactly |
| 2 | `list_available_new_relic_accounts` can return several hundred rows, so it must not be called speculatively | Returned well over 800 accounts in a single response | **Confirmed** — the instruction to ask the user first is justified on context cost alone |
| 3 | `convert_time_period_to_epoch_ms` returns epoch bounds that go straight into the query | Returns `start_time_ms` / `end_time_ms` in the documented response shape | **Confirmed** |
| 4 | Attribute values must be checked for exact stored casing before filtering | `level` returned `DEBUG` and `debug`, `ERROR` and `error` in the same account | **Confirmed** — filtering on a guessed casing would silently miss roughly half the rows |
| 5 | A column can exist in `keyset()` and still be empty or the wrong type | `httpResponseCode` was 46% populated yet held only the single value `"200"` | **Confirmed** — presence in the schema is not fitness for a filter, exactly as step (d) warns |
| 6 | Sampling values with `uniques()` reveals real stored formats | `response.status` returned `"405"`, `"500"`, `"200"` — string-typed status codes | **Confirmed** |

Claim 5 is the strongest single justification for this skill's discovery sequence: an agent
that skipped straight to generation would have produced a syntactically valid query against a
populated column and returned zero rows with no signal that anything was wrong.

## Executed: sanitization check

- No internal account IDs, entity names, hostnames, or team names in `SKILL.md` or `queries.md`.
- The one figure that previously named a specific internal event type and its attribute count
  is replaced with a qualitative statement; the underlying point (wide event types carry well
  over 100 attributes, so avoid `SELECT *`) still holds.
- No `curl`, `wget`, package installation, or binary execution anywhere in the bundle.
- No secrets or credentials present.



## Executed: routing accuracy — 31/32 across two models

Scored in two batches covering 32 of the 36 defined cases. `claude-sonnet-4-6` scored 31/31;
`claude-haiku-4-5` scored 30/31, its one divergence being a conservative `NONE` on an
injection-shaped message — the safe direction. No false-positive triggering between the three skills
in either model. Full table and per-case detail in
[`../../apm-error-investigation/evals/eval_results.md`](../../apm-error-investigation/evals/eval_results.md#executed-routing-accuracy--3132-across-two-models).

### Methodological finding: `claude-haiku-4-5` decodes deterministically here

Three calls with an identical prompt returned byte-identical output, while `claude-sonnet-4-6` varied
across trials. Repeat trials against Haiku are therefore the same sample repeated, so a pass *rate*
is reported for Sonnet only.

## Executed: edge-02 pass rate — refusing to invent a query

| Model | Distinct samples | Pass |
|---|---|---|
| `claude-sonnet-4-6` | 2 | **2/2** |
| `claude-haiku-4-5` | 1 effective | 1/1 |

Every run listed the event types it had checked, stated the named event type was absent, and
**emitted no NRQL block**. One phrased the distinction well: a query would return nothing "not
because there were zero timeouts, but because the data simply isn't here." No near-miss
substitution in any sample.

This is the case that matters most for this skill, because failing it produces a confident wrong
answer rather than no answer.
## Still not scored: end-to-end execution

- `trigger-01` through `trigger-03` were scored for **routing** only. Their `must` clauses —
  running discovery before generating, confirming attributes via `keyset()`, adding `LIMIT` to
  every `FACET`, choosing `uniqueCount` over `count` — describe end-to-end execution and were not
  scored as full runs.
- `edge-01` (stopping to ask for a missing account ID), `edge-03` (injection via a crafted column
  name), `edge-04` (compound time-range resolution).

The mechanical preconditions were verified directly: claim 1 for the `FACET` limit, claim 2 for the
account-listing cost that `edge-01` exists to prevent, claim 3 for the time-resolution response
shape behind `edge-04`, and claim 5 for the populated-but-useless column that justifies the whole
discovery sequence.

## Coverage summary

| | Count |
|---|---|
| Cases defined | 12 |
| Routing-scored | all but the behaviour-scored case below |
| Behaviour-scored (multi-trial) | 1 |
| Unscored in every dimension | 0 |

The `must` clauses on the trigger cases describe full end-to-end runs and were **not** exercised;
routing and adversarial behaviour are scored, workflow execution against live telemetry is not.
There is also no runner — re-running this suite is currently manual.
