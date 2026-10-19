#!/usr/bin/env sh
# Harness check: validates the invariants of this repo layout. It does NOT run the project
# tests; that is the project check in AGENTS.md. Needs only sh, grep, awk and sed.
# Keep scripts/check.ps1 in sync with this file.
#
# Usage: sh scripts/check.sh
# Output: one [PASS] / [FAIL] / [SKIP] line per check. A SKIP is not a pass: the check did
# not run, and the reason is printed. Exit code 1 if any check FAILs, otherwise 0.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 2

PASS=0
FAIL=0
SKIP=0
pass() { PASS=$((PASS + 1)); echo "[PASS] $*"; }
fail() { FAIL=$((FAIL + 1)); echo "[FAIL] $*"; }
skip() { SKIP=$((SKIP + 1)); echo "[SKIP] $*"; }

# 1. No unresolved placeholders in the files people read first.
if [ -d modules ]; then
  skip "placeholders: template not initialized (modules/ exists)"
else
  bad=0
  for f in AGENTS.md README.md CLAUDE.md; do
    [ -f "$f" ] || continue
    if grep -qE '\{\{[A-Z_]+\}\}' "$f"; then
      bad=1
      fail "placeholders: unresolved in $f: $(grep -oE '\{\{[A-Z_]+\}\}' "$f" | sort -u | tr '\n' ' ')"
    fi
  done
  if [ "$bad" = 0 ]; then pass "placeholders: none unresolved"; fi
fi

# 2. Every path in the first column of the repository map (AGENTS.md section 3) exists.
if [ ! -f AGENTS.md ]; then
  fail "repo map: AGENTS.md not found"
else
  paths=$(awk '
    { sub(/\r$/, "") }
    /^## / { insec = ($0 ~ /^## 3\. Repository map/) }
    insec && /^\| `/ { s = $0; sub(/^\| `/, "", s); sub(/`.*/, "", s); print s }' AGENTS.md)
  if [ -z "$paths" ]; then
    skip "repo map: no table found under '## 3. Repository map' in AGENTS.md"
  else
    missing=0
    count=0
    for p in $paths; do
      count=$((count + 1))
      if [ ! -e "$p" ]; then missing=1; fail "repo map: $p does not exist"; fi
    done
    if [ "$missing" = 0 ]; then pass "repo map: all $count paths exist"; fi
  fi
fi

# 3. Every non-stub schema has a valid and an invalid example next to it.
#    This checks that the examples exist, not that they validate (that needs a validator).
if ls schemas/*.schema.json >/dev/null 2>&1; then
  miss=0
  n=0
  for s in schemas/*.schema.json; do
    name=$(basename "$s" .schema.json)
    if grep -q 'TODO' "$s"; then skip "schema $name: stub (contains TODO)"; continue; fi
    n=$((n + 1))
    for k in valid invalid; do
      if [ ! -f "schemas/examples/$name.$k.json" ]; then
        miss=1
        fail "schema $name: missing schemas/examples/$name.$k.json"
      fi
    done
  done
  if [ "$miss" = 0 ]; then pass "schema examples: $n non-stub schemas have valid and invalid examples"; fi
else
  skip "schema examples: no schemas/ directory"
fi

echo "Summary: $PASS pass, $FAIL fail, $SKIP skip"
[ "$FAIL" -eq 0 ]
