#!/usr/bin/env bash
# Validates a single skill directory against the EPD publishing checklist.
# Usage: validate_skill.sh <skill_dir>
# Exit code: number of errors found (0 = clean).

set -euo pipefail

SKILL_DIR="${1:?Usage: validate_skill.sh <skill_dir>}"
SKILL_MD="${SKILL_DIR}/SKILL.md"

ERRORS=0
WARNINGS=0

fail()    { echo "::error file=${SKILL_MD}::$1";   ERRORS=$((ERRORS + 1)); }
warn()    { echo "::warning file=${SKILL_MD}::$1"; WARNINGS=$((WARNINGS + 1)); }
pass()    { echo "  ✓  $1"; }
section() { echo; echo "── $1 ──"; }

echo "Validating: $SKILL_DIR"

# ── 1. SKILL.md frontmatter ───────────────────────────────────────────────
section "SKILL.md frontmatter"

if ! grep -q "^name:" "$SKILL_MD"; then
  fail "Missing required 'name:' field in SKILL.md frontmatter"
else
  SKILL_NAME=$(grep "^name:" "$SKILL_MD" | head -1 | sed 's/^name:[[:space:]]*//')
  pass "name: ${SKILL_NAME}"
fi

if ! grep -q "^description:" "$SKILL_MD"; then
  fail "Missing required 'description:' field in SKILL.md frontmatter"
else
  pass "description field present"
fi

# argument-hint is strongly recommended but not blocking
if ! grep -q "^argument-hint:" "$SKILL_MD"; then
  warn "Missing 'argument-hint:' field — recommended for discoverability"
else
  pass "argument-hint field present"
fi

# ── 2. OAuth scope documentation ─────────────────────────────────────────
section "OAuth scope documentation"

# Acceptable locations: SKILL.md itself, or skill-manifest.md alongside it.
# skill-manifest.md is the preferred home since SKILL.md runs in the agent's
# context window on every invocation and shouldn't carry metadata the agent can't act on.
SCOPE_FOUND=0
grep -qiE '(oauth|scope|permission)' "$SKILL_MD" && SCOPE_FOUND=1
[ -f "${SKILL_DIR}/skill-manifest.md" ] && grep -qiE '(oauth|scope|permission)' "${SKILL_DIR}/skill-manifest.md" && SCOPE_FOUND=1

if [ $SCOPE_FOUND -eq 0 ]; then
  fail "No OAuth scope documentation found in SKILL.md or skill-manifest.md. Every published skill must list the minimum required OAuth 2.0 scopes."
else
  pass "OAuth/scope reference found"
fi

# ── 3. LICENSE file ───────────────────────────────────────────────────────
section "License"

# Accept a LICENSE in the skill directory or at the repository root.
# A root LICENSE is standard practice for Apache 2.0 and covers all skills in the repo.
# Walk up from SKILL_DIR to find the closest LICENSE file.
LICENSE=""
[ -f "${SKILL_DIR}/LICENSE" ] && LICENSE="${SKILL_DIR}/LICENSE"
if [ -z "$LICENSE" ]; then
  _d=$(realpath "$SKILL_DIR")
  while [ "$_d" != "/" ]; do
    _d=$(dirname "$_d")
    if [ -f "${_d}/LICENSE" ]; then
      LICENSE="${_d}/LICENSE"
      break
    fi
  done
fi

if [ -z "$LICENSE" ]; then
  fail "No LICENSE file found in skill directory or repository root. Publish under Apache 2.0."
else
  if ! grep -qi "apache license" "$LICENSE"; then
    fail "LICENSE does not appear to be Apache License. Found: $(head -1 "$LICENSE")"
  elif ! grep -qi "version 2.0" "$LICENSE"; then
    fail "LICENSE is not Apache 2.0 (Version 2.0 not found)."
  else
    [ "$LICENSE" = "LICENSE" ] \
      && pass "Apache 2.0 LICENSE present (root)" \
      || pass "Apache 2.0 LICENSE present (skill directory)"
  fi
fi

# ── 4. Eval suite ─────────────────────────────────────────────────────────
section "Eval suite"

if [ ! -d "${SKILL_DIR}/evals" ]; then
  fail "Missing evals/ directory. Add evals/test_cases.json with trigger, negative-control, and edge-case entries."
else
  pass "evals/ directory exists"

  TEST_CASES="${SKILL_DIR}/evals/test_cases.json"
  if [ ! -f "$TEST_CASES" ]; then
    fail "Missing evals/test_cases.json"
  else
    if ! jq empty "$TEST_CASES" 2>/dev/null; then
      fail "evals/test_cases.json is not valid JSON"
    else
      pass "evals/test_cases.json is valid JSON"

      # Two valid schemas are accepted:
      #
      # Schema A — top-level arrays (original):
      #   { "trigger_cases": [...], "negative_controls": [...], "edge_cases": [...] }
      #
      # Schema B — flat cases array with a "category" field per entry (branch convention):
      #   { "cases": [{ "category": "trigger", ... }, { "category": "negative_control", ... }] }
      #
      # Both must include at least one trigger case and one negative control.

      HAS_TRIGGER=0
      HAS_NEGATIVE=0

      # Schema A
      jq -e '.trigger_cases | arrays | length > 0'   "$TEST_CASES" > /dev/null 2>&1 && HAS_TRIGGER=1
      jq -e '.negative_controls | arrays | length > 0' "$TEST_CASES" > /dev/null 2>&1 && HAS_NEGATIVE=1

      # Schema B
      jq -e '[.cases[]? | select(.category == "trigger")] | length > 0' \
        "$TEST_CASES" > /dev/null 2>&1 && HAS_TRIGGER=1
      jq -e '[.cases[]? | select(.category == "negative_control")] | length > 0' \
        "$TEST_CASES" > /dev/null 2>&1 && HAS_NEGATIVE=1

      [ $HAS_TRIGGER -eq 1 ]  && pass "trigger cases present" \
        || fail "evals/test_cases.json missing trigger cases. Add at least one entry with category 'trigger' (or a top-level 'trigger_cases' array)."
      [ $HAS_NEGATIVE -eq 1 ] && pass "negative_control cases present" \
        || fail "evals/test_cases.json missing negative controls. Add at least one entry with category 'negative_control' (or a top-level 'negative_controls' array)."

      # Model tracking: accept metadata.model (Schema A) or skill_version + schema_version (Schema B).
      # The branch records model info in eval_results.md, which is the better location anyway.
      MODEL_TRACKED=0
      jq -e '.metadata.model' "$TEST_CASES" > /dev/null 2>&1 && MODEL_TRACKED=1
      jq -e '.schema_version' "$TEST_CASES" > /dev/null 2>&1 && MODEL_TRACKED=1  # Schema B carries version metadata
      [ $MODEL_TRACKED -eq 0 ] && \
        warn "evals/test_cases.json missing version metadata — add metadata.model or schema_version for regression tracking"
    fi
  fi

  if [ ! -f "${SKILL_DIR}/evals/eval_results.md" ]; then
    warn "Missing evals/eval_results.md. Document test results with model name, version, and date run."
  else
    pass "eval_results.md present"
  fi
fi

# ── 5. Internal references ────────────────────────────────────────────────
section "Internal reference check"

INTERNAL_PATTERNS=(
  'source\.datanerd\.us'
  'newrelic\.slack\.com'
  '\.nr-internal\.'
  'internal\.newrelic\.com'
  'nr-internal\.net'
)

FOUND_INTERNAL=0
for pattern in "${INTERNAL_PATTERNS[@]}"; do
  if grep -qiE "$pattern" "$SKILL_MD"; then
    fail "Internal reference matching '$pattern' found. Remove all internal URLs before publishing."
    FOUND_INTERNAL=1
  fi
done
[ $FOUND_INTERNAL -eq 0 ] && pass "No internal references detected"

# ── 6. Dangerous execution patterns ──────────────────────────────────────
section "Dangerous execution patterns"

FOUND_DANGEROUS=0

# curl | bash / wget | sh
if grep -niE '(curl|wget)[^`\n]*\|[[:space:]]*(ba)?sh' "$SKILL_MD"; then
  fail "Dangerous pipe-to-shell pattern (curl/wget | bash/sh) detected. SKILL.md must never instruct arbitrary remote execution."
  FOUND_DANGEROUS=1
fi

# Binary installs from arbitrary URLs
if grep -niE '(pip|npm|yarn)[[:space:]]+(install|add)[[:space:]]+https?://' "$SKILL_MD"; then
  fail "Package install from external URL detected. Pin dependencies to official registries only (PyPI, npmjs.com)."
  FOUND_DANGEROUS=1
fi

[ $FOUND_DANGEROUS -eq 0 ] && pass "No dangerous execution patterns"

# ── 7. Prompt injection resilience hint ───────────────────────────────────
section "Prompt injection resilience"

if ! grep -qi "untrusted\|injection\|treat.*data\|tool output" "$SKILL_MD"; then
  warn "No prompt injection guidance found. Consider adding a note instructing the model to treat MCP tool output as untrusted user data."
else
  pass "Prompt injection guidance present"
fi

# ── Summary ───────────────────────────────────────────────────────────────
echo
echo "═══════════════════════════════════════════"
echo "  Result for ${SKILL_DIR}"
echo "  Errors:   ${ERRORS}"
echo "  Warnings: ${WARNINGS}"
echo "═══════════════════════════════════════════"

exit "$ERRORS"
