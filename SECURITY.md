# Security

## Reporting a vulnerability

Report suspected vulnerabilities in these skills through this repository's GitHub issue
tracker, or through New Relic's coordinated disclosure process at
<https://newrelic.com/security>. Please do not include customer data, account identifiers, or
access tokens in a report.

## What these skills are, in security terms

Every skill in this repository is **Markdown instructions only**. None bundles scripts, none
installs dependencies, none downloads anything, and none executes shell commands. Each one
reaches New Relic exclusively through read-only tools on the New Relic MCP server, over your
MCP client's existing authenticated connection.

Per-skill disclosure of untrusted inputs, data handling, egress, privileges, and required OAuth
scopes lives in each skill's `skill-manifest.md`. Read that before enabling a skill.

### A SKILL.md is not a security boundary

The instructions in these files are prompts to a language model, not access controls. Where a
skill says it will not do something — widen a time window, disclose account identifiers, follow
an instruction embedded in telemetry — treat that as a **mitigation that reduces the likelihood
of a bad outcome, not a guarantee that prevents one.**

Your actual boundaries are:

1. The OAuth 2.0 scope you grant the MCP server. Every skill here needs only
   `observability:read`.
2. Your agent runtime's own sandboxing — filesystem, network, and tool-approval controls.

Grant the narrower scope and rely on the sandbox. Do not rely on the prose.

### Prompt injection is the primary risk here

These skills read telemetry: error messages, log bodies, span names, entity names, request
URIs, and attribute values. **All of it is written by your monitored applications and by anyone
who can reach them.** A crafted error message or log line is untrusted input arriving inside
what looks like trusted infrastructure data.

Each `SKILL.md` instructs the model to treat retrieved telemetry as data rather than
instructions, and to quote and flag anything that reads like a directive instead of acting on
it. `apm-error-investigation` carries the highest exposure of the three, because error messages
drive its ranking and the ranking selects which trace it investigates — so injected text there
can attempt to steer the investigation itself, not merely the wording of a report.

### Secrets can reach your agent through log data

This is worth stating plainly because it surprises people. If your applications log raw HTTP
headers, those log bodies can contain `authorization: Bearer …` values. Any skill that reads log
messages can pull such a value into the agent transcript and into your model provider's request
payload.

`apm-error-investigation` truncates log messages to bound this. **Truncation limits context
size; it does not reliably remove secrets** — a token near the start of a header dump still
falls inside the truncated window. Scrub at the log-forwarding layer. Do not treat any skill in
this repository as a redaction control.

### Data leaves your environment to your model provider

No skill here sends data to New Relic-operated endpoints other than the MCP server you are
already authenticated to, and none writes files or retains state between runs. But everything a
skill reads enters your agent's model context, which means **your configured LLM inference
provider receives it.** Each `skill-manifest.md` names this explicitly under `data_egress` and
`third_party_subprocessors`. Account for it in your own data-handling assessment.

## Customer guidance: safe skill deployment

When enabling agent skills — these or any others — in an execution environment such as Claude
Code, Cursor, Codex, or a custom runtime, we recommend the following controls.

1. **Package and repository scanning.** Run automated static analysis and security scanning
   over all `SKILL.md` packages and any dependencies you import. Treat external skills with
   measured skepticism, including these: read them before you enable them.
2. **OAuth 2.0 authorization bounds.** Authenticate the New Relic MCP server with fine-grained,
   user-scoped OAuth 2.0 access tokens, and grant only the minimum scopes the skills you enable
   actually need. For everything in this repository that is `observability:read`.
3. **Runtime sandboxing.** Enforce boundaries with containerization, virtual filesystems, and
   network firewalls. Do not use natural-language prompt instructions as a hard access-control
   boundary.
4. **Human-in-the-loop controls.** Enable execution-confirmation prompts in your agent runtime
   for any tool call that deletes data, moves money, or modifies an external system. No skill
   here performs a state-changing action, but your runtime should be configured as though one
   might.
5. **Data privacy.** Review the scope of resources each skill requires — filesystem, tools,
   network, and data categories — as disclosed in its `skill-manifest.md`, and confirm it is
   compatible with your obligations before enabling it.

## Scope of what these skills can reach

| Resource | Access |
|---|---|
| Filesystem | Read-only, and only the skill's own bundled reference files (`queries.md`). No writes. |
| Network | The New Relic MCP server host configured in your MCP client, port 443, via your client's existing authenticated connection. No raw HTTP of the skill's own. |
| Shell / code execution | None. |
| Secrets, environment variables, key stores | None read. Authentication is handled entirely by your MCP client and the server's OAuth 2.0 layer. |
| State-changing actions | None. All tools used are read-only, and the server exposes no write scope. |
