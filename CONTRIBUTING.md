# Contributing a skill

Ownership and the deprecation policy are in [`REGISTRY.md`](REGISTRY.md). Customer-facing security
guidance is in [`SECURITY.md`](SECURITY.md).

## Adding a skill

New skills need SLC approval for the publication venue — including whether they ship as a plugin
and to which marketplaces — before they are merged here. The per-skill bar is:

- `SKILL.md` with a clear description, arguments, and execution steps — and nothing else. No test
  record, version, or licence text: `SKILL.md` is loaded into the agent's context at runtime, so
  anything there that the agent cannot act on is wasted context.
- The model, version, and date of the last test recorded in `skill-manifest.md` under **Provenance
  and testing** — one file, so the two copies cannot drift.
- `skill-manifest.md`, completed honestly. Follow the structure of an existing one — e.g.
  [`skills/nl2-nrql/skill-manifest.md`](skills/nl2-nrql/skill-manifest.md) — and fill in every
  field it carries: identity, provenance and testing, input trust, data handling, privilege and
  actions, and transparency. Answer the security disclosures accurately; they drive the reviewer's
  risk rating and the customer's trust decision.
- Any other file the agent reads (NRQL, failure modes) under `references/`, linked from `SKILL.md`
  with when to read it, one level deep.
- Minimum required OAuth 2.0 scopes stated explicitly.
- No `curl`, `wget`, or binary execution steps.
- `evals/test_cases.json` covering trigger accuracy, negative controls, and edge cases, plus
  `evals/eval_results.md` recording a real run.
- Coexistence tested against the skills already in this repository — they overlap on NRQL, trace,
  error and Kafka territory, so false-positive triggering is the live risk.
- Apache 2.0 `LICENSE` in the skill directory.
- An owning team added to [`REGISTRY.md`](REGISTRY.md).
- An entry under **Added** in [`CHANGELOG.md`](CHANGELOG.md).
- PR approved by Security Engineering and a Product lead.

## Changing a published skill

A change to any file the agent loads (`SKILL.md`, anything under `references/`, or a `queries.md`
kept next to `SKILL.md`) is a new version of the skill. In the same PR:

- Bump `version` under **Identity** in `skill-manifest.md` and the skill's row in
  [`REGISTRY.md`](REGISTRY.md).
- Leave `Skill version` under **Provenance and testing** alone unless you re-ran the evals. It
  records the version the test results apply to.
- Add an entry to [`CHANGELOG.md`](CHANGELOG.md) under today's date, newest first: the skill, its
  old and new version, and what changed in words a user of the skill would follow. Link the PR.
  Written this way, #6 would have been:

  ```markdown
  - `apm-error-investigation` 1.0.0 → 2.0.0. Step 4 uses `get_distributed_trace_details` instead
    of `get_trace_summary` and `get_trace_entity_details`. ([#6](https://github.com/newrelic/nr-skills-hub/pull/6))
  ```

Pick the version with [semantic versioning](https://semver.org/):

- Major: someone already using the skill may need to act. It needs an MCP tool or OAuth scope it
  did not need before, drops something it used to do, or stops at a different point.
- Minor: the skill does something new and everything it did before still works the same way.
- Patch: a fix that leaves behaviour as documented, such as a corrected query or clearer wording.

Changes to `skill-manifest.md`, `evals/` or `LICENSE` alone do not change the version and need no
changelog entry.
