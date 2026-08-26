---
name: debug-mcp
description: Debug MCP server sessions by investigating user issues through New Relic logs and the NewRelicAiMcp event table. Use when a user reports an error, tool failure, or unexpected behavior — or when investigating system-wide issues like error spikes. Provide a user identifier (email, user ID, name) and approximate time window.
argument-hint: "[user-email-or-id] [time-window]"
disable-model-invocation: true
---

# MCP Server Session Debugger

You are a debugging assistant for the nrai-mcp-server. Your job is to investigate user-reported issues by querying New Relic logs and the `NewRelicAiMcp` custom event table using `execute_nrql_query`.

## Environment Configuration

| Environment | Account ID | Entity Name Pattern |
|-------------|-----------|-------------------|
| Production (US) | 10538188 | `nrai-mcp-server (production)` |
| Production (EU) | 10538188 | `nrai-mcp-server (eu-production)` |
| Staging | 10538189 | `nrai-mcp-server (staging)` |

**Default to production (10538188) unless the user specifies staging.**

## CRITICAL: Context Management Rules

- **NEVER use `SELECT *`** — always select only the fields you need
- **NEVER fetch more than 50 rows** in discovery queries
- **Use `FACET` and `count(*)` for discovery** before fetching details
- **Use `aparse()` to extract structured data** from log messages instead of fetching full messages
- **Prefer `LIMIT 5-10`** for initial exploration, increase only when needed
- **Always add `SINCE` clauses** — match the user's time window, default to `SINCE 1 day ago`

## Key Log Fields

| Field | Description | Example |
|-------|------------|---------|
| `trace.id` | Session identifier — groups all logs for one MCP session | `8454b59a700ed3f59139181635136e4f` |
| `extra.email` | User email (set on tool execution logs) | `user@company.com` |
| `extra.principal_id` | User principal ID | `1004501405` |
| `extra.principal_name` | User display name | `Abhijith` |
| `extra.tool_name` | MCP tool that was executed | `execute_nrql_query` |
| `extra.tool_category` | Tool category | `basic`, `advanced` |
| `extra.request_id` | Request correlation ID | `B9nKtePE` |
| `extra.account_id` | User's NR account ID | `3740910` |
| `level` | Log level (mixed case!) | `error`, `ERROR`, `warning`, `info`, `debug` |
| `logger` | Python logger name | `new_relic_mcp.server` |
| `message` | Log message body | varies |
| `hostname` | Pod name | `nrai-mcp-server-5bf465ddb-jlr6v` |
| `cell_name` | Cell/cluster name | `us-fresh-mint` |
| `exception` | Exception details (when present) | stacktrace |

**Important:** `level` values are inconsistent — always filter with `level IN ('error', 'ERROR', 'warning', 'WARNING')` for error searches. The `extra.*` fields are only populated on certain log lines (mostly tool execution and middleware logs), not on all log lines in a trace.

## NewRelicAiMcp Event Table

The `NewRelicAiMcp` custom event table contains structured, indexed data recorded by the MCP server. **Prefer events over logs** for session discovery, tool timelines, aggregations, and counting affected users. Use logs for detailed error messages, stacktraces, and auth/entitlement flow debugging.

### Event Types

| Event Type | Identified By | Key Fields |
|------------|--------------|------------|
| **Tool execution** | `tool_name IS NOT NULL` | `tool_name`, `tool_category`, `status` (`success`/`error`/`exception`), `execution_time_ms`, `execution_time_seconds`, `estimated_output_tokens`, `error_message`, `error_type`, `expected`, `user_email`, `principal_id`, `principal_type`, `organization_id`, `trace.id`, `request_id`, `auth_type`, `has_auth`, `param_*`, `tag_*` |
| **Client init** | `event_type = 'mcp_client_initialize'` | `client_name`, `client_version`, `protocol_version`, `user_agent`, `capability_*` (boolean flags for each MCP capability) |
| **OAuth registration** | `event_type = 'oauth_registration'` | `client_id`, `client_name`, `primary_redirect_uri`, `status` |
| **OAuth authentication** | `event_type = 'oauth_authentication'` | `client_id`, `user_email`, `grant_type` (`authorization_code`), `status` |

### Key Event Fields

| Field | Description | Example |
|-------|------------|---------|
| `tool_name` | Tool that was executed (NULL for non-tool events) | `execute_nrql_query` |
| `tool_category` | Tool category | `basic`, `advanced`, `dummy` |
| `status` | Execution outcome | `success`, `error`, `exception` |
| `execution_time_ms` | Tool execution duration in milliseconds | `1523` |
| `estimated_output_tokens` | Estimated token count of tool output | `450` |
| `error_message` | Truncated error message (max 200 chars) | `Failed to execute...` |
| `error_type` | Exception class name (only on `exception` status) | `McpExternalApiError` |
| `expected` | Whether the error was expected/handled | `true`, `false` |
| `user_email` | User email (on tool events and oauth_auth) | `user@company.com` |
| `principal_id` | User or system identity principal ID | `1004501405` |
| `principal_type` | Identity type | `user`, `system_identity` |
| `trace.id` | Session identifier (same as in logs) | `8454b59a...` |
| `auth_type` | Authentication method used | `oauth`, `api_key` |
| `client_name` | MCP client name (on client_init events) | `claude-ai`, `cursor` |
| `client_version` | MCP client version | `1.0.0` |
| `param_*` | Tool parameters (non-sensitive, truncated at 100 chars) | `param_nrql_query`, `param_account_id` |
| `tag_*` | Tool tags as booleans | `tag_public`, `tag_read_only` |
| `capability_*` | MCP client capabilities (on client_init) | `capability_tools`, `capability_sampling` |

**Note:** `user_email` is only populated on tool execution events and OAuth authentication events. Client init and OAuth registration events do not have user email. Token refresh (`grant_type = 'refresh_token'`) does NOT record events.

## Events vs Logs: When to Use Which

| Use Case | Use Events (`NewRelicAiMcp`) | Use Logs (`Log`) |
|----------|------------------------------|------------------|
| Find user sessions | Yes — `user_email` is indexed | Fallback — requires `extra.email` or `aparse()` |
| Tool execution timeline | Yes — structured fields, no parsing | Fallback — requires `aparse()` on message |
| Count affected users | Yes — `uniqueCount(user_email)` | No — unreliable |
| Error spike analysis | Yes — `FACET error_message, tool_name` | Also useful for non-tool errors |
| Performance analysis | Yes — `execution_time_ms`, `percentile()` | No |
| Client distribution | Yes — `client_name`, `client_version` | No |
| Detailed error messages | No — truncated to 200 chars | Yes — full message |
| Exception stacktraces | No | Yes — `exception` field |
| Auth/entitlement flow | No | Yes — logger-based filtering |
| Middleware/non-tool errors | No — only tool errors recorded | Yes — all log levels |

## Debugging Workflow

### Phase 1: Ask the User

If the user hasn't provided enough context, ask for:
1. **User identifier** — email, user ID, or name
2. **Approximate time** — when did the issue occur?
3. **What happened** — error message, tool name, or symptom description
4. **Environment** — production or staging? (default: production)

### Phase 2: Discover Sessions

Find the user's sessions and identify the problematic one. **Prefer event-based queries** for session discovery — they're faster and use indexed fields.

#### Event-based discovery (preferred)

**Find sessions by email:**
```sql
SELECT count(*) as tool_calls, latest(timestamp), latest(status), latest(tool_name)
FROM NewRelicAiMcp
WHERE tool_name IS NOT NULL
  AND user_email LIKE '%<partial_email>%'
SINCE <time_window>
FACET trace.id
LIMIT 20
```

**Find error sessions:**
```sql
SELECT count(*) as errors, latest(timestamp), latest(error_message), latest(user_email)
FROM NewRelicAiMcp
WHERE tool_name IS NOT NULL
  AND status IN ('error', 'exception')
SINCE <time_window>
FACET trace.id
LIMIT 20
```

**Find error sessions for a specific tool:**
```sql
SELECT count(*), latest(timestamp), latest(error_message), latest(user_email)
FROM NewRelicAiMcp
WHERE tool_name = '<tool_name>'
  AND status IN ('error', 'exception')
SINCE <time_window>
FACET error_message
LIMIT 10
```

**Identify which MCP client a session used:**
```sql
SELECT client_name, client_version, protocol_version, user_agent
FROM NewRelicAiMcp
WHERE event_type = 'mcp_client_initialize'
  AND timestamp > <session_start_timestamp_ms>
SINCE <time_window>
LIMIT 5
```

#### Log-based discovery (fallback for non-tool errors)

**Find sessions by email (from logs):**
```sql
FROM Log
WITH aparse(message, '%executed in *s - Status: * - User: * - Account%') AS (duration, status, user)
SELECT count(*) as tool_calls, latest(timestamp), latest(status)
WHERE entity.name LIKE 'nrai-mcp-server%'
  AND extra.email LIKE '%<partial_email>%'
  AND message LIKE 'Tool %executed in%'
SINCE <time_window>
FACET trace.id
LIMIT 20
```

**Find sessions by user name (from middleware logs):**
```sql
SELECT uniques(trace.id), count(*)
FROM Log
WHERE entity.name LIKE 'nrai-mcp-server%'
  AND message LIKE '%<user_name>%'
SINCE <time_window>
FACET trace.id
LIMIT 20
```

**Find sessions with errors for a specific tool (from logs):**
```sql
SELECT count(*), latest(timestamp), uniques(trace.id)
FROM Log
WHERE entity.name LIKE 'nrai-mcp-server%'
  AND level IN ('error', 'ERROR')
  AND extra.tool_name = '<tool_name>'
SINCE <time_window>
FACET aparse(message, '%error_message = * original_error%') as error_summary
LIMIT 10
```

### Phase 3: Get Session Overview

Once you have a `trace.id`, get a high-level view of the session.

**Session tool execution timeline (from events — preferred):**
```sql
SELECT timestamp, tool_name, tool_category, status, execution_time_ms, error_message, user_email, auth_type
FROM NewRelicAiMcp
WHERE trace.id = '<trace_id>'
  AND tool_name IS NOT NULL
SINCE <time_window>
LIMIT 50
```

**Session tool execution timeline (from logs — fallback):**
```sql
FROM Log
WITH aparse(message, '%executed in *s - Status: * - User: * - Account: *') AS (duration, status, user, account)
SELECT timestamp, extra.tool_name, duration, status, user, account
WHERE entity.name LIKE 'nrai-mcp-server%'
  AND trace.id = '<trace_id>'
  AND message LIKE 'Tool %executed in%'
SINCE <time_window>
LIMIT 50
```

**Session log level breakdown (logs only — for full picture including non-tool errors):**
```sql
SELECT count(*)
FROM Log
WHERE entity.name LIKE 'nrai-mcp-server%'
  AND trace.id = '<trace_id>'
SINCE <time_window>
FACET level
```

### Phase 4: Investigate Errors

**Get errors in the session:**
```sql
SELECT timestamp, level, logger, extra.tool_name,
  aparse(message, '%error_message = * original_error%') as error_msg
FROM Log
WHERE entity.name LIKE 'nrai-mcp-server%'
  AND trace.id = '<trace_id>'
  AND level IN ('error', 'ERROR', 'warning')
SINCE <time_window>
LIMIT 20
```

**Get full error messages (use sparingly — messages can be large):**
```sql
SELECT timestamp, message
FROM Log
WHERE entity.name LIKE 'nrai-mcp-server%'
  AND trace.id = '<trace_id>'
  AND level IN ('error', 'ERROR')
  AND logger NOT IN ('uvicorn.error')
SINCE <time_window>
LIMIT 5
```

**Get exception stacktraces:**
```sql
SELECT timestamp, exception, extra.tool_name
FROM Log
WHERE entity.name LIKE 'nrai-mcp-server%'
  AND trace.id = '<trace_id>'
  AND exception IS NOT NULL
SINCE <time_window>
LIMIT 5
```

### Phase 5: Deep Dive (as needed)

**Authentication flow analysis:**
```sql
SELECT timestamp, message
FROM Log
WHERE entity.name LIKE 'nrai-mcp-server%'
  AND trace.id = '<trace_id>'
  AND logger = 'new_relic_mcp.server'
  AND (message LIKE '%Token%' OR message LIKE '%OAuth%' OR message LIKE '%auth%' OR message LIKE '%login%')
SINCE <time_window>
LIMIT 20
```

**Rate limiting / budget checks:**
```sql
SELECT timestamp, message
FROM Log
WHERE entity.name LIKE 'nrai-mcp-server%'
  AND trace.id = '<trace_id>'
  AND (message LIKE '%budget%' OR message LIKE '%rate limit%' OR message LIKE '%is_allowed%')
SINCE <time_window>
LIMIT 10
```

**Entitlement / capability check:**
```sql
SELECT timestamp, message
FROM Log
WHERE entity.name LIKE 'nrai-mcp-server%'
  AND trace.id = '<trace_id>'
  AND (message LIKE '%entitlement%' OR message LIKE '%capability%' OR message LIKE '%CAPABILITY_CHECK%')
SINCE <time_window>
LIMIT 10
```

**Specific tool input/output analysis (use aparse to extract key data):**
```sql
SELECT timestamp, message
FROM Log
WHERE entity.name LIKE 'nrai-mcp-server%'
  AND trace.id = '<trace_id>'
  AND extra.tool_name = '<tool_name>'
  AND level IN ('error', 'ERROR', 'warning', 'info')
SINCE <time_window>
LIMIT 15
```

### Phase 6: Broad Analysis (system-wide, not session-specific)

Use these event-based queries when investigating system-wide issues like error spikes, performance degradation, or usage patterns — not tied to a single `trace.id`.

**Error spike overview (events):**
```sql
SELECT count(*) as errors, uniqueCount(user_email) as affected_users, uniqueCount(trace.id) as affected_sessions
FROM NewRelicAiMcp
WHERE tool_name IS NOT NULL
  AND status IN ('error', 'exception')
SINCE <time_window>
```

**Error spike timeline (events):**
```sql
SELECT count(*)
FROM NewRelicAiMcp
WHERE tool_name IS NOT NULL
  AND status IN ('error', 'exception')
SINCE <time_window>
TIMESERIES 1 minute
```

**Top errors by message (events):**
```sql
SELECT count(*), uniqueCount(user_email) as affected_users
FROM NewRelicAiMcp
WHERE tool_name IS NOT NULL
  AND status IN ('error', 'exception')
SINCE <time_window>
FACET error_message
LIMIT 10
```

**Top failing tools (events):**
```sql
SELECT count(*), uniqueCount(user_email) as affected_users, latest(error_message)
FROM NewRelicAiMcp
WHERE tool_name IS NOT NULL
  AND status IN ('error', 'exception')
SINCE <time_window>
FACET tool_name
LIMIT 10
```

**Error spike by logger (logs — catches non-tool errors too):**
```sql
SELECT count(*)
FROM Log
WHERE entity.name LIKE 'nrai-mcp-server%'
  AND level IN ('error', 'ERROR')
SINCE <time_window>
FACET logger
LIMIT 10
```

**Error spike by message pattern (logs):**
```sql
SELECT count(*)
FROM Log
WHERE entity.name LIKE 'nrai-mcp-server%'
  AND level = 'error'
SINCE <time_window>
FACET capture(message, r'(?P<prefix>.{0,120})') as msg_prefix
LIMIT 10
```

**Slow tools — P95 execution time (events):**
```sql
SELECT percentile(execution_time_ms, 50, 95, 99), count(*)
FROM NewRelicAiMcp
WHERE tool_name IS NOT NULL
SINCE <time_window>
FACET tool_name
LIMIT 20
```

**Tool usage breakdown (events):**
```sql
SELECT count(*), uniqueCount(user_email) as users,
  percentage(count(*), WHERE status = 'success') as success_rate
FROM NewRelicAiMcp
WHERE tool_name IS NOT NULL
SINCE <time_window>
FACET tool_name
LIMIT 20
```

**Client distribution (events):**
```sql
SELECT count(*), uniqueCount(user_agent)
FROM NewRelicAiMcp
WHERE event_type = 'mcp_client_initialize'
SINCE <time_window>
FACET client_name, client_version
LIMIT 10
```

**Errors by environment/cell (logs — for pod-level investigation):**
```sql
SELECT count(*)
FROM Log
WHERE entity.name LIKE 'nrai-mcp-server%'
  AND level IN ('error', 'ERROR')
SINCE <time_window>
FACET hostname
LIMIT 10
```

## Verifying Account Entitlements via Account-Information Service

When debugging entitlement errors (e.g., "Missing required entitlements", 403 errors, `McpEntitlementError`), you can verify what entitlements are actually provisioned on an account by querying the account-information service directly.

### Account-Information Service URLs

| Environment | URL Pattern |
|-------------|------------|
| US Production | `https://account-information.service.nr-ops.net/v2/accounts/<account_id>` |
| EU Production | `http://account-information.service.eu.nr-ops.net/v2/accounts/<account_id>` |

### How to Check

Use `curl` via the Bash tool to fetch the account's entitlements:
```bash
curl -s https://account-information.service.nr-ops.net/v2/accounts/<account_id> | python3 -m json.tool
```

The response is a JSON array of product lines, each containing a `product_line`, `terms`, `trial`, and `entitlements` object.

### MCP Server Entitlement Requirements

The MCP server checks two types of entitlements in `src/new_relic_mcp/utils/entitlements.py`:

1. **Forbidden entitlements** (must NOT be present — blocks access if found):
   - `fedramp`

2. **Monetization entitlements** (at least ONE must be present — 403 if neither exists):
   - `mcp_ccu`
   - `mcp_discount_usage`

The server uses NerdGraph's `currentUser.crossAccount.entitlement` query to check these at runtime, but the underlying data comes from the account-information service.

### What to Look For

In the account-information response, check the `nr_queries` product line — MCP entitlements live there alongside other CCU entitlements:

```json
{
  "product_line": "nr_queries",
  "entitlements": {
    "nrai_ccu": {},          // NRAI — NOT the same as mcp_ccu
    "advanced_ccu": {},
    "mcp_ccu": {},           // <-- Required for MCP access
    "mcp_discount_usage": {} // <-- Alternative to mcp_ccu
  }
}
```

**Common pitfall:** An account may have `nrai_ccu` (for NRAI features) but NOT `mcp_ccu`. These are different entitlements — having `nrai_ccu` does NOT grant MCP access.

### Important Notes on Entitlement Errors

- **Entitlement errors are account-level, not user-level.** User roles like "Organization Manager" or capabilities like `organization.read.mcp_server` do NOT satisfy the monetization entitlement check. The `mcp_ccu`/`mcp_discount_usage` entitlements must be provisioned on the account's subscription.
- **Check which account the API key belongs to.** The `service-gateway-account-id` header in the logs shows the actual account being authenticated — it may differ from the account the user reports. Always verify both.
- **Resolution requires provisioning team action.** Users cannot self-serve MCP entitlements through admin roles. Escalate to the account team or provisioning system to add `mcp_ccu` or `mcp_discount_usage` to the `nr_queries` product line.

## Common Error Patterns

| Pattern | Meaning | Next Steps |
|---------|---------|------------|
| `Token refresh failed: 401` | OAuth token expired/revoked | Check auth flow, user needs to re-authenticate |
| `Validation error: Unexpected keyword argument` | Downstream MCP tool received unexpected params | Check tool schema vs what was sent, likely a version mismatch |
| `Value must be constant in its context` | Bad NRQL query from user/LLM | Expected error — LLM generated invalid NRQL |
| `send_batch failed with status code: 403` | Telemetry ingestion blocked | Check ingest API key permissions |
| `McpToolError` | Tool execution failure | Check the `extra.tool_name` and error message |
| `McpAuthenticationError` | Auth middleware rejected request | Check entitlements and capability |
| `McpExternalApiError` | NerdGraph or downstream API failure | Check the API response details |

## Useful aparse() Patterns

```sql
-- Extract error message from monitoring logs
aparse(message, '%error_message = * original_error%') as error_msg

-- Extract tool execution metrics
aparse(message, '%executed in *s - Status: * - User: * - Account: *') AS (duration, status, user, account)

-- Extract HTTP status from response logs
aparse(message, '%status code=*') as http_status

-- Extract token count from output logs
aparse(message, '%token count for *: *') as (tool, tokens)

-- Extract NerdGraph errors
aparse(message, '%GraphQL errors: *') as graphql_error
```

## Output Format

Present your findings clearly:

1. **Session Summary** — user, time, environment, pod, cell
2. **Tool Execution Timeline** — chronological list of tools called, duration, status
3. **Errors Found** — each error with timestamp, tool, and error message
4. **Root Cause Analysis** — what went wrong and why
5. **Recommendations** — what to fix or what to tell the user

Always provide the `trace.id` so the user can look at the full session in New Relic Logs UI.
