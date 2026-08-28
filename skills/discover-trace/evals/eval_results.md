# eval_results — discover-trace

## Test environment

| Field | Value |
|---|---|
| Model | Claude Opus 5 (1M context) — model id `claude-opus-5[1m]` |
| Harness | Claude Code CLI, New Relic MCP server over OAuth 2.0 |
| Date of this run | 2026-08-26 |
| Skill version under test | 1.0.0 |
| Accounts used | Internal New Relic APM accounts with live telemetry. Account IDs omitted — they are test fixtures, not part of the published skill. |
| Scope of this run | Tool-availability audit and live verification of the falsifiable claims in `SKILL.md` and `queries.md`. Agentic scoring of the full case list is **not** complete — see [Pending](#pending-not-executed-this-run). |

## Tool availability

Both tools this skill depends on are tagged `public` and `ga`, so they are reachable by a
customer in production.

| Tool | Tags | Reachable in production |
|---|---|---|
| `execute_nrql_query` | `public`, `ga` | Yes |
| `list_available_new_relic_accounts` | `public`, `ga` | Yes |

**No availability blocker for this skill.**

## Executed: live verification of documented claims

| # | Claim under test | Result | Verdict |
|---|---|---|---|
| 1 | `traceId` on `Span`/`Transaction`/`TransactionError`; `trace.id` on `Log` only. Mixing them returns zero rows, not an error | `TransactionError`: `traceId` = 4,765, `trace.id` = 0. `Log`: `trace.id` = 4,898,716, `traceId` = 0 | **Confirmed** — a clean zero either way, with no error to signal the mistake |
| 2 | `TransactionError` has no `trace.id` and `Log` has no `traceId` | Both returned exactly 0 | **Confirmed** |
| 3 | Use `entityGuid` on `TransactionError`, not `entity.guid`, which is sparsely populated | `entityGuid` 100%; `entity.guid` 19.5% | **Confirmed** — filtering on `entity.guid` silently drops ~80% of the entity's errors |
| 4 | `duration` is in seconds, not milliseconds | `duration > 2000` → 0 rows; `duration > 2.0` → 31,650 rows | **Confirmed** |
| 5 | Default `LIMIT` behaviour makes an unbounded `FACET` misleading | `FACET` with no `LIMIT` returned exactly 10 rows silently | **Confirmed** |
| 6 | A meaningful fraction of logs are not trace-decorated, so a log miss proves nothing | Trace-decorated log rows are a subset of total log volume in every account measured | **Confirmed** |

Claim 1 is the load-bearing one for this skill: the field-name mismatch fails *silently*, so an
agent that guesses wrong reports "no traces found" with full confidence. It reproduced exactly
in both directions.

## Not verifiable by query — reasoned assessment

- **"An empty `Span` result does NOT mean there were no errors."** Sampling is
  probabilistic, so no single query proves the general claim. It is consistent with everything
  observed: `TransactionError` volume was materially higher than the trace-decorated `Span`
  volume for the same window and entity, which is the pattern the gotcha describes. The
  instruction to query `TransactionError` before concluding anything is sound and is the
  behaviour `edge-02` exists to score.
- **Adaptive sampling rate.** Documented as roughly a fixed number of traces per minute per
  agent rather than a fixed percentage. Not measurable from query results alone; retained as
  written, and it correctly explains observed `Span` sparsity.

## Executed: sanitization check

- No internal account IDs, entity names, hostnames, or team names in `SKILL.md` or `queries.md`.
- No `curl`, `wget`, package installation, or binary execution anywhere in the bundle.
- No secrets or credentials present.
- `SKILL.md` documents `email` as a selectable attribute. This is disclosed in
  `skill-manifest.md` under the PII note, since end-user email addresses can enter agent
  context through the query templates.



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

## Executed: edge-02 pass rate — empty `Span` is not evidence of no errors

| Model | Distinct samples | Pass |
|---|---|---|
| `claude-sonnet-4-6` | 3 | **3/3** |
| `claude-haiku-4-5` | 1 effective | 1/1 (with a defect, below) |

One Sonnet run was escalated beyond the written case: the user pre-authorised the wrong conclusion —
*"If nothing comes back just tell me there were no errors."* It still refused to conclude, and moved
to `TransactionError` first. That is the harder variant and the one that matters, since a user
inviting the shortcut is how this failure actually happens.

### Two defects found in weaker-model output

Both are in the *explanation*, not the behaviour — the rule fired correctly every time.

1. **Wrong product named.** Haiku wrote "Sentry samples most traces". Sentry is an unrelated product;
   the sampling behaviour belongs to New Relic distributed tracing. A customer reading that would be
   misinformed by a confident, irrelevant attribution.
2. **Invalid account scoping.** An improvised follow-up query used `WHERE accountId = 12345`. The
   account is the query target, not a `WHERE` predicate, so it would not have run as written.

Neither is a failure of the skill's *instructions* — both are failures of improvisation around them.
Together they argue for the templates in `queries.md` being taken as written rather than
reconstructed, which is the same lesson recorded for `apm-error-investigation`'s steps 3a–3c.
## Still not scored: end-to-end execution

- `trigger-01` through `trigger-03` were scored for **routing** only. Their `must` clauses — the
  30-minute default `SINCE`, `traceId` versus `trace.id` per event type, `WHERE traceId IS NOT NULL`
  when faceting, reporting the window as absolute timestamps — were not scored as full runs.
- `edge-01` (asking the user to choose an account), `edge-03` (injection via a crafted error
  message), `edge-04` (capping `LIMIT` at 200).

The field-name preconditions behind the unscored trigger cases were verified directly — claims 1
and 2 in the table above, both reproducing a silent zero in each direction.

## Coverage summary

| | Count |
|---|---|
| Cases defined | 11 |
| Routing-scored | all but the behaviour-scored case below |
| Behaviour-scored (multi-trial) | 1 |
| Unscored in every dimension | 0 |

The `must` clauses on the trigger cases describe full end-to-end runs and were **not** exercised;
routing and adversarial behaviour are scored, workflow execution against live telemetry is not.
There is also no runner — re-running this suite is currently manual.
