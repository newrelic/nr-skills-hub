# New Relic Agent Skills

Agent Skills for working with New Relic observability data through the
[New Relic MCP server](https://docs.newrelic.com/). Each skill is a set of Markdown
instructions that an AI coding agent — Claude Code, Cursor, Codex, or a custom runtime — loads
to carry out one well-scoped observability workflow.

Everything here is **read-only** and needs a single OAuth 2.0 scope: `observability:read`.

## Skills

| Skill | What it does | Stops at |
|---|---|---|
| [`nl2-nrql`](skills/nl2-nrql/) | Turns a plain-English question into one schema-validated NRQL query. Discovers the account's real event types and attributes first, then proves the finished query parses. | One NRQL query |
| [`discover-trace`](skills/discover-trace/) | Finds distributed trace IDs matching what you describe and presents every match. | A candidate list, for you to choose from |
| [`apm-error-investigation`](skills/apm-error-investigation/) | Root-causes a backend APM error end to end: resolves the entity, ranks error groups by real impact, follows the chosen trace across services, correlates logs. | An evidence-backed report |

They are deliberately layered. `nl2-nrql` authors a query; `discover-trace` finds candidates and
hands off; `apm-error-investigation` runs the full investigation. Pick the one whose stopping
point matches what you want.

> [!NOTE]
> `apm-error-investigation` needs two trace tools that are in the process of being made public. If
> its trace-reconstruction step reports the tools as unavailable, that promotion has not reached
> your environment yet — the step has no NRQL fallback by design. Everything up to it works
> regardless. See [`REGISTRY.md`](REGISTRY.md).

## Before you enable any of this

Read [`SECURITY.md`](SECURITY.md). The short version:

- These skills read telemetry — error messages, log bodies, entity names — and **all of it is
  written by your applications and by anyone who can reach them.** Treat it as untrusted input.
- Everything a skill reads enters your agent's context, so **your model provider receives it.**
  If your applications log raw HTTP headers, that can include credentials.
- A `SKILL.md` is not a security boundary. Your boundaries are the OAuth scope you grant and
  your agent runtime's sandbox.

Each skill's `skill-manifest.md` discloses its untrusted inputs, data handling, egress,
privileges, and required scopes. Read it before enabling that skill.

## Layout

```
skills/
└── <skill-name>/
    ├── SKILL.md                  # the instructions the agent loads
    ├── queries.md                # NRQL reference the skill reads
    ├── skill-manifest.md         # provenance, test record, and security disclosure
    ├── LICENSE                   # Apache 2.0
    └── evals/
        ├── test_cases.json       # trigger, negative-control, edge, coexistence cases
        └── eval_results.md       # recorded run: model, version, date, findings
```

## Installing

Copy the skill directory you want into your agent's skills location — for Claude Code that is
`.claude/skills/<skill-name>/` in your project, or `~/.claude/skills/<skill-name>/` for all
projects. Keep `queries.md` alongside `SKILL.md`; the skills read it.

You will also need the New Relic MCP server configured in your client, authenticated with
`observability:read`.

## Testing and maintenance

Model behaviour drifts between versions, so each skill records the models, version, and date of its
last test in `skill-manifest.md` under **Provenance and testing**, with the full run in
`evals/eval_results.md`. Results are valid for those models and that date only.

Provenance lives in the manifest and nowhere else, on purpose. `SKILL.md` is loaded into the agent's
context when the skill runs, and test metadata is of no use to it there — it is for humans and
reviewers. Keeping it in one file also means one place to update after a test run, so the version and
scope cannot drift between two copies.

**When adding or re-testing a skill, update `skill-manifest.md` — do not add a test record to
`SKILL.md`.**

Re-run a skill's `evals/` when an upstream model version ships, and when a New Relic agent or
MCP tool release could move the attribute-coverage figures the skill depends on. Several of these
skills encode facts like "this attribute is populated on most rows but this one is not" — those
are measurements, and they go stale.

Ownership, the bar for adding a skill, and the deprecation policy are in
[`REGISTRY.md`](REGISTRY.md).

## Contributing

New skills need approval for the publication venue before merge, and must meet the checklist in
[`REGISTRY.md`](REGISTRY.md#adding-a-skill).

## License

Apache 2.0. See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).

A copy of the licence also sits in each skill directory. Skills are meant to be copied out
individually into an agent's skills location, and a copy that travels without its licence is a
copy a downstream redistributor cannot comply with — Apache 2.0 section 4(a) requires giving
recipients a copy of the License, not a link to it.
