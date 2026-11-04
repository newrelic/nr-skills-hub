# skill-manifest — apm

- **manifest_version**: `"1.0"`

## Identity

- **skill**
  - **name**: `newrelic/apm`
  - **version**: `1.0.0`
  - **description**: Investigates application performance — error rate, latency, throughput, Apdex and transaction behaviour — and checks related entities, deployments and open issues to find a likely cause.
- **author**
  - **verified_identity**: `New Relic`

## Provenance and testing

- **Skill version**: `1.0.0`, taken from the source plugin's `plugin.json`.
- **Source**: copied unchanged from `newrelic/claude-code-plugin` at commit `f8e5f8b` (`skills/apm/`).
- **License**: Apache 2.0 (`LICENSE`, in this directory)
- **Last tested**: Not yet tested in this repository.
- **Models used**: None recorded.
- **Results**: None recorded. The cases are defined in `evals/test_cases.json` but have not been
  run, and there is no `evals/eval_results.md` yet.
- **Known gaps**, to resolve before publishing:
  - **Overlap with `apm-error-investigation`.** This skill's description covers "investigating
    application errors", which `apm-error-investigation` owns. False-positive triggering between
    the two is the main coexistence risk; see the `coexist-*` cases.
  - **Tools missing from `allowed-tools`.** `SKILL.md` tells the model to prefer
    `analyze_golden_metrics`, `list_top_transactions` and `analyze_transactions`, but none of them
    is in its `allowed-tools` list.
  - **Tools missing from the plugin's catalog.** `lookup_entity`, `list_recent_deployments` and
    `list_top_transactions` are not in the tool reference shipped with the source plugin's
    `newrelic-mcp` skill. Their availability on the production MCP server has not been checked.
  - **References to skills that are not here.** `SKILL.md` points to correlation analysis,
    database, network, data retrieval and metric analysis skills. None exists in this repository.
  - **No prompt-injection guidance** in `SKILL.md`. See Input trust below.
  - **No `argument-hint`** in the frontmatter.

Model behaviour drifts between versions, so any results recorded later are valid only for the
models and date they were recorded with. Re-run `evals/` when the upstream model version changes,
or when an MCP tool release changes the tools this skill calls.

## Security disclosures

### Input trust & prompt injection

- **processes_untrusted_input**: `true`
- **untrusted_input_sources**:
  - Transaction and error data from `Transaction`, `TransactionError` and `Span` — transaction names, error classes, error messages and stack traces, span names, request URIs and hosts. Error messages are written by the monitored application and often embed request-supplied data, so anyone who can reach the application can influence them.
  - Entity names, tags and relationships returned by `lookup_entity`, `search_entity_with_tag` and `list_related_entities`.
  - Issue titles and descriptions from `list_recent_issues`, and deployment descriptions and changelogs from `list_recent_deployments`. Both are free text written by people.

**Exposure note.** Retrieved data decides which dependency the skill blames and what it
recommends, so injected text could steer the conclusion, not just its wording.

**Mitigation.** None at present. `SKILL.md` has no instruction to treat retrieved telemetry as data
rather than instructions; the repository validator warns about this. Even once one is added, per the
EPD Non-Boundary Rule it is a mitigation and **not** a security boundary. The boundary is the
read-only OAuth scope below plus the customer's own runtime sandbox.

### Data handling

- **handles_sensitive_data**: `true`
- **data_categories**:
  - `pii`
  - `confidential`
- **data_egress**: New Relic MCP server (NerdGraph) over HTTPS — the only destination the skill sends to, and it reaches it only through the MCP client's existing authenticated connection. Everything the skill reads also enters the agent's model context, so the customer's configured LLM inference provider receives it.
- **third_party_subprocessors**:
  - The customer's configured LLM inference provider — receives transaction names, error messages and stack traces, span and entity names, hosts, request URIs, and issue and deployment text.
- **data_retention**: None by the skill. It writes no files and keeps no state between runs. The New Relic MCP server separately records one tool-invocation event per call — see `data_logging`.
- **data_logging**: None written by the skill. The New Relic MCP server records a tool-invocation event per call containing the invoking user's email and ID, the organization ID, and each tool parameter as `param_<name>` truncated to 100 characters. Parameter keys named exactly `password`, `token`, `key` or `secret` are omitted; `nrql_query` is not, so submitted NRQL text — including literal values in `WHERE` clauses — is recorded. The skill itself reads and logs no credential.

**PII note.** Error messages and request URIs routinely carry user identifiers, email addresses
and account or order IDs. `SKILL.md` also suggests segmenting by customer or tenant, which can
surface customer identifiers directly.

### Privilege & actions

- **oauth_scopes**:
  - `observability:read`
- **mcp_tools**:
  - In `allowed-tools`:
    - `execute_nrql_query` — read-only; custom NRQL against `Transaction`, `TransactionError` and `Span` when no specialised tool fits.
    - `lookup_entity` — read-only; resolves the application entity. Not in the source plugin's tool catalog.
    - `search_entity_with_tag` — read-only; finds entities by tag.
    - `list_recent_issues` — read-only; lists open alert issues.
    - `list_recent_deployments` — read-only; lists recent deployments for correlation. Not in the source plugin's tool catalog.
    - `list_related_entities` — read-only; finds upstream, downstream, database and external dependencies.
  - Named in `SKILL.md` but not in `allowed-tools`:
    - `analyze_golden_metrics` — read-only; throughput, error rate, latency and saturation for an entity.
    - `list_top_transactions` — read-only; top transactions by volume, latency or error rate. Not in the source plugin's tool catalog.
    - `analyze_transactions` — read-only; slow and error-prone transaction breakdown.

  Every tool is a read operation by name and description. None has been audited for general
  availability on the production MCP server.

  **Privilege note on the NRQL path.** `execute_nrql_query` takes a query string, so within
  `observability:read` it can read any event type in the account. `SKILL.md` gives example queries
  but does not restrict the model to them. This does not widen the OAuth scope, but it does widen
  what the skill could read if its instructions were subverted.
- **network_access**: `true`
- **network_endpoints**:
  - **host**: `<the New Relic MCP server host configured in the customer's MCP client>`
    **port**: `443`
    **justification**: Sole transport for all tool calls. The skill issues no raw HTTP of its own — every request travels over the MCP client's existing authenticated connection.
- **filesystem_access**: `true`
- **filesystem_paths**:
  - **path**: `references/ERROR_ANALYSIS.md` and `references/PERFORMANCE_METRICS.md` (inside the skill's own bundle)
    **justification**: Read-only reference files shipped with the skill, covering error patterns and performance metrics. The skill reads no other path and writes nothing.
- **shell_or_code_execution**: `false`
- **code_execution_details**: Not applicable. The skill is Markdown instructions only — it bundles no scripts and instructs no shell, package-manager, download or `eval` step.
- **accesses_secrets**: `false`
- **secrets_accessed**:
  - None. Authentication is handled entirely by the MCP client and the New Relic MCP server's OAuth 2.0 layer. The skill never reads an environment variable, token, or key store.
- **performs_sensitive_actions**: `false`
- **requires_human_confirmation**: `false`
- **actions_requiring_confirmation**:
  - None. Every tool the skill uses is read-only. Its recommendations, such as enabling a circuit breaker or contacting a provider, are advice for the user; the skill takes no action itself.

**Least privilege.** `observability:read` is the only scope required, matching the other skills in
this repository. The source plugin's `newrelic-mcp` skill shows `openid profile mcp:access` in its
sample OAuth configuration, so confirm the scope against the production MCP server before
publishing.

### Transparency

- **telemetry**: None emitted by the skill. Skill usage is observable only through the New Relic MCP server's own tool-invocation events described under `data_logging`.
