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
- Minimum required OAuth 2.0 scopes stated explicitly.
- No `curl`, `wget`, or binary execution steps.
- `evals/test_cases.json` covering trigger accuracy, negative controls, and edge cases, plus
  `evals/eval_results.md` recording a real run.
- Coexistence tested against the skills already in this repository — the three published here
  overlap on NRQL, trace, and error territory, so false-positive triggering is the live risk.
- Apache 2.0 `LICENSE` in the skill directory.
- An owning team added to [`REGISTRY.md`](REGISTRY.md).
- PR approved by Security Engineering and a Product lead.
