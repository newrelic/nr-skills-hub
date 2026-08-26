# Skill registry

Every published skill must have a named owning team. A skill with no owner, or one that has gone
unmaintained, expands customer attack surface for no benefit — see
[Deprecation policy](#deprecation-policy).

## Published skills

| Skill | Version | Owner | OAuth scope | Last tested | Status |
|---|---|---|---|---|---|
| [`nl2-nrql`](skills/nl2-nrql/) | 1.0.0 | AIR team | `observability:read` | 2026-08-26 | Ready for review |
| [`discover-trace`](skills/discover-trace/) | 1.0.0 | AIR team | `observability:read` | 2026-08-26 | Ready for review |
| [`apm-error-investigation`](skills/apm-error-investigation/) | 1.0.0 | AIR team | `observability:read` | 2026-08-26 | Ready for review — one tool dependency to confirm, see below |

Owners are teams, not individuals, so an entry survives staffing changes. Report issues through
the routes in [`SECURITY.md`](SECURITY.md).

**Coexistence verified 2026-08-26.** The three skills were scored together against a 32-case
routing set on `claude-sonnet-4-6` (31/31) and `claude-haiku-4-5` (30/31, the one divergence being a
conservative refusal on an injection-shaped message). No false-positive triggering and no ambiguity
collapse between them. This matters because all three operate on NRQL over error and trace data, so
over-triggering was the live risk. Re-score when adding a fourth skill, or when an upstream model
version ships.

**Known eval gaps.** End-to-end workflow execution is not yet scored — the trigger cases' `must`
clauses describe full runs and were not exercised. Adversarial cases passed 7/7 distinct samples, but
n=3 per case only rules out a control that fails often. Non-Anthropic model families are unverified
(the gateway did not serve them), and there is no runner, so re-running is manual.

### apm-error-investigation — confirm one tool dependency before publishing

Step 4 depends on `get_trace_summary` and `get_trace_entity_details`. **These are being promoted to
`public`**, which clears the skill for publication. The promotion had not shipped when this skill
was last audited on 2026-08-26 — both tools carried `internal` + `ga` at that point, and the MCP
server disables `internal`-tagged tools in production.

**Pre-publish check:** confirm both tools are tagged `public` on the production tool surface. That
is the only outstanding item; nothing else about the skill is waiting on it.

Steps 3a–3c use `execute_nrql_query`, which is already `public` + `ga`, so the error-ranking path
carries no availability risk either way. Step 4 is the only affected step, and it cannot fall back
to NRQL — the skill's own central finding is that a single-account query cannot resolve a
distributed trace. Detail in
[`skills/apm-error-investigation/evals/eval_results.md`](skills/apm-error-investigation/evals/eval_results.md).

## Ownership expectations

An owning team is responsible for:

- Reviewing PRs that touch its skill. Branch protection should require that review.
- Re-running `evals/` when an upstream model version ships, and when a New Relic agent or MCP
  tool release could move the attribute-coverage figures a skill depends on.
- Updating `skill-manifest.md` whenever the tool list, data handling, or required scope changes.
- Responding to vulnerability reports for its skill, per [`SECURITY.md`](SECURITY.md).

## Deprecation policy

A skill is flagged for deprecation when it has gone unmaintained for more than six months, or
when it depends on a deprecated MCP endpoint or a tool that has been removed. Flagged skills are
moved to `/deprecated` and formally sunsetted by the owning team. The New Relic MCP server
feature team owns this process for skills that target its tools.

## Adding a skill

New skills need SLC approval for the publication venue — including whether they ship as a plugin
and to which marketplaces — before they are merged here. The per-skill bar is:

- `SKILL.md` with a clear description, arguments, and execution steps — and nothing else. No test
  record, version, or licence text: `SKILL.md` is loaded into the agent's context at runtime, so
  anything there that the agent cannot act on is wasted context.
- The model, version, and date of the last test recorded in `skill-manifest.md` under **Provenance
  and testing** — one file, so the two copies cannot drift.
- `skill-manifest.md`, completed honestly. Copy
  [`skills/skill-manifest.template.md`](skills/skill-manifest.template.md) and fill in every
  required field.
- Minimum required OAuth 2.0 scopes stated explicitly.
- No `curl`, `wget`, or binary execution steps.
- `evals/test_cases.json` covering trigger accuracy, negative controls, and edge cases, plus
  `evals/eval_results.md` recording a real run.
- Coexistence tested against the skills already in this repository — the three published here
  overlap on NRQL, trace, and error territory, so false-positive triggering is the live risk.
- Apache 2.0 `LICENSE` in the skill directory.
- An owning team added to this file.
- PR approved by Security Engineering and a Product lead.
