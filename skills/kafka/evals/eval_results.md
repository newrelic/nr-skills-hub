# eval_results: kafka

## Runs

This is the first version of the skill; the results are for it. The method is in the section below.

| Date | Version | Model | Harness | Scope | Result |
|---|---|---|---|---|---|
| 2026-11-13 | 0.1.0 | `claude-sonnet-5-5` | `claude -p` (Claude Code 2.1.311), this repository's skills plus a general investigation skill, only `Skill` and `Read` allowed, no MCP server | Trigger accuracy, 35 cases, two runs each | 70 of 70 |

The scored run used no real account or telemetry. The only live checks are one log-scoping query and one run of each Kafka tool (`analyze_kafka_health`, `analyze_kafka_related_entities`, `analyze_kafka_client_metrics`) on a test account (the 2026-11-13 and 2026-11-14 notes below); the rest of live execution is under [Still not scored](#still-not-scored-live-execution).

Re-run this suite whenever the upstream model version changes, and whenever a New Relic agent or MCP tool release could change the Kafka tools' concepts or the metric and attribute names in `references/queries.md`.

## Tool availability

Source: the New Relic MCP server's tool tags, checked on 2026-11-13, and the audit of 2026-08-26 in `../../apm-error-investigation/evals/eval_results.md`.

| Tool | Used for | In production |
|---|---|---|
| `execute_nrql_query` | every query in `queries.md` | Public |
| `convert_time_period_to_epoch_ms` | the time window | Public |
| `list_available_new_relic_accounts` | account lookup, only if the user cannot name it | Public |
| `get_entity` | resolving a name to an entity GUID and account | Public |
| `analyze_entity_logs` | logs around the onset | Public |
| `list_recent_logs` | the log lines in time order | Public |
| `analyze_kafka_health` | the health sweep | Public |
| `analyze_kafka_related_entities` | brokers, topics, applications and hosts around an entity | Public |
| `analyze_kafka_client_metrics` | an application's own client metrics | Public |

The three Kafka tools are public. The server may not offer them in every account; the skill then uses the queries in `references/queries.md` ("When a Kafka tool is not offered" in `SKILL.md`). Re-run this suite after a Kafka tool release.

## Executed: sanitization check

- No internal URLs or hosts, account IDs, ticket numbers, team names (other than the registry owner), or environment names in `SKILL.md`, `queries.md` or `failure-modes.md`. The hub validator's internal-reference check passes.
- No reference to any internal-only monitoring tables, internal tool names, or internal skill identifiers.
- No `curl`, `wget`, package installation, or binary execution. No secrets.
- No observed measurement is published as a fact. The only numbers are Kafka and tool defaults (for example `fetch.max.wait.ms` at 500 ms) and the 15-minute, 2-hour and 1-day windows the skill instructs.
- Not yet checked against docs.newrelic.com: the attribute and event names in `queries.md` and the "Identity attributes" table, and the infrastructure agent event fields in "Hosts, containers and Kubernetes".

## Executed: trigger accuracy, 70 of 70 (2026-11-13)

Method: `claude -p` (Claude Code 2.1.311, `claude-sonnet-5-5`) in an empty project whose `.claude/skills/` held this repository's four skills (`apm-error-investigation`, `discover-trace`, `kafka`, `nl2-nrql`) and a fifth, general investigation skill, and no user plugins (`--setting-sources project`). Each of the 35 cases ran twice on version 0.1.0 (the text in this commit), stopped after two turns, with only `Skill` and `Read` allowed and no MCP server attached. Scored: whether `Skill` loaded `kafka`, against `expect.skill_invoked`. Recorded, not scored: the first skill each run loaded, and which skill file it read next.

| Category | 0.1.0 |
|---|---|
| Trigger accuracy | 32 of 32 |
| Negative controls | 14 of 14 |
| Edge cases | 18 of 18 |
| Coexistence | 6 of 6 |
| **Total** | **70 of 70** |
| Runs that read a file under `references/` right after loading `kafka` (shows the links resolve from the new folder, not that the right file was chosen) | 42 of 54 |

Live checks on a test account (observed, not scored):

- **Executed once on live telemetry (2026-11-13, a test account, the syslog of one infrastructure-agent host).** `entity.guids = '<host guid>'` returned 409 rows, the `LIKE` form returned 409, and `entity.guid = '<host guid>'` returned 0: these host log rows carry `entity.guids` and not `entity.guid`, which is why "Log searches" scopes by `entity.guids`. `FACET entity.guids` separated the host rows from APM rows in one query; `entity.name` had no values on the host rows. Not run: OpenTelemetry broker logs and the exception-class filters.
- **`analyze_kafka_health` run live (2026-11-13, a test account, an OpenTelemetry test cluster with one producer service and one consumer service).** Seeded from the cluster with `include_topology`, the sweep returned the brokers, topics, both services and the broker containers and host, but `app_hosts` was empty, `app_host_cpu`, `app_host_memory` and `app_host_disk` were listed under `coverage.not_evaluated`, and the summary said it was not a clean bill of health. Seeded from the consumer service listed in `consumer_entities`, the same cluster scope came back with `app_hosts` filled (the consumer and producer containers and their host) and the app-host checks evaluated. This is the flow `edge-08` expects; it was observed, not scored.
- **`analyze_kafka_related_entities` and `analyze_kafka_client_metrics` run live (2026-11-14, the same test account and cluster).** `analyze_kafka_related_entities` returned the same scopes as the health sweep: from the cluster, the brokers, topics, both services and the broker containers and host with `app_hosts` empty; from the consumer service, the same plus `app_hosts` filled. `producer_entities` and `consumer_entities`, the fields `SKILL.md` names, were present in both. `analyze_kafka_client_metrics` on the consumer service returned one row per measure with `anomalies`, `measurements` and `query_nrql`, and a warning listing what it does not evaluate (per-topic breakdown, rebalance and commit counters, buffer exhaustion, authentication failures). Three readings to keep: the producer rows for a consumer-only service are constant zeros, because that service reports no `kafka.producer.*` metrics; every row's `metric_name` is `Throughput`, so the measure is in `timeseries_id`; and several `Low`-confidence spike and dip anomalies sat within 1% of the average (consumer fetch latency 142.4 to 144.1 ms), so `measurements` should be read beside an anomaly. `analyze_kafka_related_entities` was also run from two nri-kafka clusters (`provider` was `nri-kafka`; each has a `KAFKACLUSTER` entity). On a cluster with its own Kafka `cluster.id` it returned that cluster's 2 brokers, 3 topics and the producer and consumer APM applications, empty `broker_hosts` and `app_hosts`, and a note that the traversal found 2 topics where a tag-scoped search found 3 (true count about 4). Seeded instead from that cluster's producer application, consumer application or a topic, it returned the same cluster, brokers and topics (plus the same topics reported by a second account), both applications, and their two containers in `app_hosts`, which the cluster seed left empty; `broker_hosts` stayed empty from every seed. Six test clusters share one `cluster.id` (cloned hosts): seeded from one of them (the cluster, or a topic), it returned the brokers and topics of all six and named another cluster in `cluster`, and from the topic also the topics, applications and hosts of other test clusters in two more accounts. Where clusters can share an id, `cluster` and the names in each list need checking against the seed. On the unique-id cluster the broker checked has no edge to the container or host it runs in (its only edge is `CONTAINS` from the cluster), although the host has `HOSTS` edges to the `kafka-broker-1` and `kafka-broker-2` containers; the host layer is therefore "not checked" in the tool's output and is read with the nri-kafka queries in "Hosts, containers and Kubernetes". Run once on that cluster, the host query (hostnames from `KafkaBrokerSample`, then `SystemSample`) and the Docker query (`ContainerSample` by container `name`) each returned rows for the broker host and both broker containers. Not run live: AWS MSK, Confluent Cloud, and `analyze_kafka_client_metrics` on nri-kafka or APM applications. Observed, not scored.

## Coverage summary

| | Count | Of 35 |
|---|---|---|
| Trigger-scored | 35 | 100% |
| Behaviour-scored (tool calls and answers) | 0 | 0% |
| Scored against live telemetry | 0 | 0% |

## Still not scored: live execution

Behaviour is not scored for any case: the trigger run attaches no MCP server, and there is no runner that takes a case end to end against real tools and grades the answer. Live runs: `analyze_kafka_health` and `analyze_kafka_related_entities` were each run live twice (once seeded from a cluster, once from a consumer service) and `analyze_kafka_client_metrics` once (the consumer service), all on one OpenTelemetry test cluster, and `analyze_kafka_related_entities` also from two nri-kafka clusters, as recorded above; no AWS MSK or Confluent Cloud path has been run live, nor `analyze_kafka_client_metrics` on nri-kafka or APM applications. Not scored: the verdict fields and `root_cause_layer` on a fired verdict, and the quality of the root cause on real incidents.

NRQL: the NRQL in `queries.md` was executed on 2026-10-14 against live telemetry for each provider it covers (OpenTelemetry, nri-kafka, AWS MSK stream and polled, Confluent Cloud, APM agent), except the parts listed here, which have **not** been executed: the one-day lookback on last-report reads, the per-partition grain for nri-kafka lag, the `direction` split on `kafka.topic.io`, the account-wide counts, and the "Trends and capacity" section, the exception-class filters in "Log searches", and "Hosts, containers and Kubernetes" except its nri-kafka host query and Docker container query (each run once on 2026-11-14).

There is no runner yet; re-running this suite is manual.
