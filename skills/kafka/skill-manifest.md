# skill-manifest: kafka

- **manifest_version**: `"1.0"`

## Identity

- **skill**
  - **name**: `newrelic/kafka`
  - **version**: `0.1.2`
  - **description**: Answers questions about Kafka from the account's own New Relic telemetry, and investigates Kafka problems and alerts to a root cause with a deterministic health check plus follow-up queries and logs. Covers nri-kafka, OpenTelemetry, AWS MSK and Confluent Cloud data.
- **author**
  - **verified_identity**: `New Relic`

## Provenance and testing

- **Skill version**: `0.1.2`
- **License**: Apache 2.0 (`LICENSE`, in this directory)
- **Last tested**: 2026-11-13: trigger accuracy in Claude Code 2.1.311 with `claude-sonnet-5-5`, 70 of 70 over two runs of 35 cases with the hub's other three skills and a general investigation skill installed (`evals/eval_results.md`); 2026-11-12: 66 of 66 on 33 cases for 0.1.1. Before that, 2026-10-21: routing accuracy on 33 cases, plus behaviour on 5 of them with canned tool results.
- **Models used**: Claude Haiku and Claude Sonnet (run as sub-agents of Claude Code with the `haiku` and `sonnet` aliases; the exact version is not recorded by the harness). The 2026-11-12 and 2026-11-13 trigger runs used `claude-sonnet-5-5` through `claude -p`.
- **Results**: trigger 70 of 70 on 2026-11-13 for 0.1.2, 66 of 66 on 2026-11-12 for 0.1.1 (62 of 66 for 0.1.0); routing 32 of 33 per model, with the two models agreeing on every Kafka-or-not decision; behaviour on canned results 5 of 5 for Sonnet and 4 of 5 for Haiku (one partial, since corrected in `queries.md`). Details and known gaps in `evals/eval_results.md`.
- **NRQL checked**: the NRQL in `queries.md` was executed on 2026-10-14 against live telemetry for each provider it covers (OpenTelemetry, nri-kafka, AWS MSK stream and polled, Confluent Cloud, APM agent), except the parts listed here, which have not been executed: the one-day lookback on last-report reads, the per-partition grain for nri-kafka lag, the `direction` split on `kafka.topic.io`, the account-wide counts, and the "Trends and capacity", "Log searches" and "Hosts, containers and Kubernetes" sections.
- **Not yet scored**: any run of the skill's cases against live telemetry. `analyze_kafka_health`, `analyze_kafka_related_entities`, `analyze_kafka_client_metrics` and the log queries were each run once on a test account with an OpenTelemetry Kafka cluster (`evals/eval_results.md`); the nri-kafka, AWS MSK, Confluent Cloud and APM paths were not run live.

Model behaviour drifts between versions, so any results recorded here are valid for the models and date given only. Re-run `evals/` when the upstream model version changes, or when a New Relic agent or MCP tool release could change the metric names and attributes this skill queries.

## Security disclosures

### Input trust & prompt injection

- **processes_untrusted_input**: `true`
- **untrusted_input_sources**:
  - Topic, consumer-group, client, host and application names and other attribute values returned by `execute_nrql_query` (`FACET`, `uniques()` and `keyset()` output). Applications and users choose these strings.
  - Entity names, relationship data and verdict text returned by `get_entity`, `analyze_kafka_health`, `analyze_kafka_client_metrics` and `analyze_kafka_related_entities`.
  - Log lines and error patterns returned by `analyze_entity_logs` or `list_recent_logs`, and any log excerpt that `analyze_kafka_health` returns. A log body is arbitrary text written by the monitored system.
  - Account names and IDs returned by `list_available_new_relic_accounts`.

**Mitigation.** `SKILL.md` instructs the model to treat every returned value as data rather than instructions, never to let a name, value or log line change which tools it calls, how wide the window is or what it discloses, and to quote only a short excerpt of a log line. Per the EPD Non-Boundary Rule this is a mitigation and **not** a security boundary. The boundary is the read-only OAuth scope below plus the customer's own runtime sandbox.

### Data handling

- **handles_sensitive_data**: `true`
- **data_categories**:
  - `pii`
  - `confidential`
- **data_egress**: New Relic MCP server (NerdGraph) over HTTPS. It is the only destination the skill sends to, and the skill reaches it only through the MCP client's existing authenticated connection. Query results additionally enter the agent's model context, so the customer's configured LLM inference provider receives them.
- **third_party_subprocessors**:
  - The customer's configured LLM inference provider: receives the metric values, cluster, topic, consumer-group and host names that the queries return, the health verdicts, and the log error patterns and excerpts the log tools return.
- **data_retention**: None by the skill. It writes no files, stores no state, and caches nothing between runs. The New Relic MCP server separately records one tool-invocation event per call (see `data_logging`).
- **data_logging**: None written by the skill. The New Relic MCP server records a tool-invocation event per call containing the invoking user's email and ID, the organization ID, and each tool parameter as `param_<name>` truncated to 100 characters. Parameter keys named exactly `password`, `token`, `key` or `secret` are omitted; `nrql_query` is not, so every query, including literal values in `WHERE` clauses, is recorded. The skill itself reads and logs no credential.

**Scope note.** The skill reads Kafka metrics, Kafka integration events and entity relationships: infrastructure identifiers and numbers. For a problem it also reads logs for the broker or application involved, through `analyze_entity_logs` or `list_recent_logs` and the log excerpts in the health result; it never reads Kafka message contents. The skill reads no credentials, tokens or key stores. Log lines are written by the monitored application and can carry personal data; `SKILL.md` limits what the skill quotes, but that reduces what is repeated and does not remove it from the model's context. Customers who write personal or other sensitive data into logs should scrub it at the log-forwarding layer. Names of topics, groups and clients are chosen by the customer, so they can carry business meaning.

### Privilege & actions

- **oauth_scopes**:
  - `observability:read`
- **mcp_tools**:
  - `analyze_kafka_health`: read-only; one deterministic health sweep of a Kafka entity per seed (one, plus at most one second seed).
  - `analyze_kafka_client_metrics`: read-only; the Kafka client-library metrics of one producer or consumer application, used when the server offers it, otherwise the queries in `references/queries.md`.
  - `analyze_kafka_related_entities`: read-only; the brokers, topics, applications and hosts around an entity.
  - `analyze_entity_logs`: read-only; error patterns in the logs of one entity over the onset window (at most a day).
  - `list_recent_logs`: read-only; the raw log lines of one entity over the onset window, newest first (50 by default).
  - `get_entity`: read-only; resolves a name to an entity GUID and its account.
  - `convert_time_period_to_epoch_ms`: read-only; converts a described window to epoch bounds.
  - `execute_nrql_query`: read-only; every query in `references/queries.md`.
  - `list_available_new_relic_accounts`: read-only; called only if the user cannot name an account, since it can return several hundred rows.
  Every tool is read-only. `analyze_kafka_health`, `analyze_kafka_related_entities` and `analyze_kafka_client_metrics` are public; the server may not offer them in every account, and the skill then uses `references/queries.md` ("When a Kafka tool is not offered" in `SKILL.md`). Re-run `evals/` after a tool release.

- **network_access**: `true`
- **network_endpoints**:
  - **host**: `<the New Relic MCP server host configured in the customer's MCP client>`
    **port**: `443`
    **justification**: Sole transport for all tool calls. The skill issues no raw HTTP of its own: every request travels over the MCP client's existing authenticated connection.
- **filesystem_access**: `true`
- **filesystem_paths**:
  - **path**: `references/queries.md` and `references/failure-modes.md` (inside the skill's own bundle)
    **justification**: Read-only reference files shipped with the skill: the NRQL for each provider, and the guide to what each health concept can mean. The skill reads no other path and writes nothing.
- **shell_or_code_execution**: `false`
- **code_execution_details**: Not applicable. The skill is Markdown instructions only. It bundles no scripts and instructs no shell, package-manager, download or `eval` step. The NRQL it runs executes server-side inside New Relic.
- **accesses_secrets**: `false`
- **secrets_accessed**:
  - None. Authentication is handled entirely by the MCP client and the New Relic MCP server's OAuth 2.0 layer. The skill never reads an environment variable, token, or key store.
- **performs_sensitive_actions**: `false`
- **requires_human_confirmation**: `false`
- **actions_requiring_confirmation**:
  - None. Every tool is read-only, and the New Relic MCP server exposes no write scope, so no deletion, overwrite, send, or other irreversible action is reachable. `SKILL.md` tells the model to decline requests to change Kafka.

**Least privilege.** `observability:read` is the only scope required. The server advertises `observability:read`, `offline` and `offline_access`, where the latter two govern refresh tokens rather than data access, and `openid profile email` on the identity leg. No write scope exists to request.

### Transparency

- **telemetry**: None emitted by the skill. Skill usage is observable only through the New Relic MCP server's own tool-invocation events described under `data_logging`.
