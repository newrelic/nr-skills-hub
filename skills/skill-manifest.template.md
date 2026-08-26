# skill-manifest.template

> **TEMPLATE** — copy to `skill-manifest.md` at the root of your skill bundle and fill in every field. Delete guidance text (like this note and the italic descriptions below) before publishing.

**Legend**

- **[REQUIRED]** — must be present to pass review
- `<...>` — replace with your value
- Enums are shown as: `value_a | value_b | value_c`

- **manifest_version**: `"1.0"`

## Identity

>| Field | Required | Description |
|---|---|---|
| `skill.name` | **[REQUIRED]** | `<namespaced-skill-id>` |
| `skill.version` | **[REQUIRED]** | `<semver>`, e.g. `"1.0.0"` (immutable once published) |
| `skill.description` | | One line: what it does |
| `author.verified_identity` | **[REQUIRED]** | `<did / verified publisher id>` |

- **skill**
  - **name**: `<namespaced-skill-id>`
  - **version**: `<semver>`
  - **description**: `<one line: what it does>`
- **author**
  - **verified_identity**: `<did / verified publisher id>`

## Security disclosures — the core of this template

>Answer every field **HONESTLY**. These drive the customer's trust decision and the reviewer's risk rating.

### Input trust & prompt injection

>| Field | Required | Description |
|---|---|---|
| `processes_untrusted_input` | **[REQUIRED]** | `<true \| false>` — Does the skill ingest content it did not author? (web pages, emails, PDFs, user files, API responses, etc.) |
| `untrusted_input_sources` | **[REQUIRED if above true]** | List each source |

- **processes_untrusted_input**: `<true | false>`
- **untrusted_input_sources**:
  - `<e.g. user-supplied documents>`
  - `<e.g. fetched web page content>`
  - `<e.g. fetched data using tool1>`

### Data handling

>| Field | Required | Description |
|---|---|---|
| `handles_sensitive_data` | **[REQUIRED]** | `<true \| false>` — Could it touch PII, credentials, financial, health, or confidential data? |
| `data_categories` | **[REQUIRED if above true]** | One or more of `pii \| financial \| health \| credentials \| confidential \| other` |
| `data_egress` | **[REQUIRED]** | `<none \| list of destinations>` — Where does data leave to? `"none"` = fully local. Otherwise name every host / API / third party that receives data. |
| `third_party_subprocessors` | **[REQUIRED if `data_egress` != none]** | Vendor name + what they receive |
| `data_retention` | **[REQUIRED]** | `<none \| describe what is stored, where, how long>` |
| `data_logging` | **[REQUIRED]** | `<none \| describe what is written to logs>` — Confirm secrets/sensitive content are NOT logged. |

- **handles_sensitive_data**: `<true | false>`
- **data_categories**:
  - `<pii | financial | health | credentials | confidential | other>`
- **data_egress**: `<none | list of destinations>`
- **third_party_subprocessors**:
  - `<vendor name + what they receive>`
- **data_retention**: `<none | describe what is stored, where, how long>`
- **data_logging**: `<none | describe what is written to logs>`

### Privilege & actions

>| Field | Required | Description |
|---|---|---|
| `oauth_scopes` | **[REQUIRED]** | `<scope>` list — minimum OAuth 2.0 scopes required on our MCP server for the skill to function. Least privilege: list only what it needs. |
| `network_access` | **[REQUIRED]** | `<true \| false>` — Any outbound/inbound network? |
| `network_endpoints` | **[REQUIRED if above true]** | Explicit allow-list: `host`, `port`, `justification` |
| `filesystem_access` | **[REQUIRED]** | `<true \| false>` — Any filesystem access? |
| `filesystem_paths` | **[REQUIRED if above true]** | Explicit allow-list: `path`, `justification` |
| `shell_or_code_execution` | **[REQUIRED]** | `<true \| false>` — Runs shell/OS commands or eval? |
| `code_execution_details` | **[REQUIRED if above true]** | What runs, and why |
| `accesses_secrets` | **[REQUIRED]** | `<true \| false>` — Reads env vars, tokens, key stores? |
| `secrets_accessed` | **[REQUIRED if above true]** | Name + purpose, e.g. `GITHUB_TOKEN` to open PRs |
| `performs_sensitive_actions` | **[REQUIRED]** | `<true \| false>` — Deletes, overwrites, sends, or makes irreversible/state-changing calls? |
| `requires_human_confirmation` | **[REQUIRED]** | `<true \| false>` — Are high-consequence actions gated behind explicit user approval? |
| `actions_requiring_confirmation` | **[REQUIRED if above true]** | e.g. sending email, deleting data, financial transactions |

- **oauth_scopes**:
  - `<e.g. observability:read>`
- **network_access**: `<true | false>`
- **network_endpoints**:
  - **host**: `<hostname>`
    **port**: `<port>`
    **justification**: `<why needed>`
- **filesystem_access**: `<true | false>`
- **filesystem_paths**:
  - **path**: `<path>`
    **justification**: `<why needed>`
- **shell_or_code_execution**: `<true | false>`
- **code_execution_details**: `<what runs, and why>`
- **accesses_secrets**: `<true | false>`
- **secrets_accessed**:
  - `<name + purpose, e.g. GITHUB_TOKEN to open PRs>`
- **performs_sensitive_actions**: `<true | false>`
- **requires_human_confirmation**: `<true | false>`
- **actions_requiring_confirmation**:
  - `<e.g. sending email, deleting data, financial transactions>`

### Transparency

>| Field | Required | Description |
|---|---|---|
| `telemetry` | **[REQUIRED]** | `<none \| describe what usage data is collected and sent where>` |

- **telemetry**: `<none | describe what usage data is collected and sent where>`
