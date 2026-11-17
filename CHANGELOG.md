# Changelog

Changes to the published skills, newest first.

Each skill has its own version, recorded in its `skill-manifest.md` and in
[`REGISTRY.md`](REGISTRY.md). This repository does not cut releases. A skill is copied from `main`,
so every merge that changes what a skill does is a new version of that skill. Entries are dated by
merge and give the old and new version.

How to pick the version and write an entry is in
[`CONTRIBUTING.md`](CONTRIBUTING.md#changing-a-published-skill).

## 2026-11-17

### Added

- `kafka` 0.1.0. Answers Kafka questions from telemetry and investigates a Kafka problem or alert
  to a root cause. Works with nri-kafka, OpenTelemetry, AWS MSK and Confluent Cloud data.
  ([#12](https://github.com/newrelic/nr-skills-hub/pull/12))

## 2026-08-31

### Changed

- `apm-error-investigation` 1.0.0, version not bumped at the time. Step 4 reconstructs the trace
  with `get_distributed_trace_details` instead of `get_trace_summary` and
  `get_trace_entity_details`. A copy taken before this date has the same version number but calls
  the older tools. ([#6](https://github.com/newrelic/nr-skills-hub/pull/6))

## 2026-08-28

### Added

- `nl2-nrql` 1.0.0, `discover-trace` 1.0.0 and `apm-error-investigation` 1.0.0, the first
  versioned skills, under `skills/`. ([#5](https://github.com/newrelic/nr-skills-hub/pull/5))

### Removed

- `debug-mcp`, an unversioned skill at the repository root since 2026-08-26 that was never
  registered. ([#5](https://github.com/newrelic/nr-skills-hub/pull/5))
