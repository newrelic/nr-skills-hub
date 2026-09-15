# Skill registry

Every published skill must have a named owning team. A skill with no owner, or one that has gone
unmaintained, expands customer attack surface for no benefit — see
[Deprecation policy](#deprecation-policy).

## Published skills

| Skill | Version | Owner | OAuth scope | Last tested |
|---|---|---|---|---|
| [`nl2-nrql`](skills/nl2-nrql/) | 1.0.0 | AIR team | `observability:read` | 2026-08-26 |
| [`discover-trace`](skills/discover-trace/) | 1.0.0 | AIR team | `observability:read` | 2026-08-26 |
| [`apm-error-investigation`](skills/apm-error-investigation/) | 1.0.0 | AIR team | `observability:read` | 2026-08-26 |

Owners are teams, not individuals, so an entry survives staffing changes. Report issues through
the routes in [`SECURITY.md`](SECURITY.md).

Test provenance — models, versions, results and known gaps — lives in each skill's
`skill-manifest.md` and `evals/eval_results.md`, so there is a single copy that cannot drift from
this file. `apm-error-investigation` has one outstanding pre-publish check, recorded in
[its manifest](skills/apm-error-investigation/skill-manifest.md).

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
