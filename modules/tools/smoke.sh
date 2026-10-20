#!/usr/bin/env sh
# Template maintenance tool. Not copied to projects: init deletes modules/.
# Smoke test of the template on the current OS. CI runs it on Linux, macOS and Windows.
#
# What it does:
#   1. Runs the harness check and the schema examples validation on the template itself.
#   2. For each case below, runs init.sh and init.ps1 on separate copies of the repo, runs
#      the harness check in each, and fails if the two variants differ in files or content.
#
# Usage: AJV_DIR=<dir with ajv@8> sh modules/tools/smoke.sh
#   PS_BINS="pwsh powershell"   PowerShell executables to test (default: those found)
set -u

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

FAILS=0
ok() { echo "[ OK ] $*"; }
bad() { FAILS=$((FAILS + 1)); echo "[FAIL] $*"; }
show() { sed 's/^/       | /' "$1"; }

if [ -z "${PS_BINS:-}" ]; then
  PS_BINS=
  for b in pwsh powershell; do
    if command -v "$b" >/dev/null 2>&1; then PS_BINS="$PS_BINS $b"; fi
  done
fi
if [ -z "${PS_BINS# }" ]; then echo "[FAIL] no PowerShell found (pwsh or powershell)"; exit 1; fi

EP=
case ${OS:-} in Windows_NT) EP="-ExecutionPolicy Bypass" ;; esac

# run_ps <exe> <script> [args...]: run a PowerShell script of the current directory.
run_ps() {
  exe=$1; script=$2; shift 2
  # shellcheck disable=SC2086
  "$exe" -NoProfile -NonInteractive $EP -File "$script" "$@"
}

echo "== OS: $(uname -s); sh: $(readlink "$(command -v sh)" 2>/dev/null || command -v sh)"
echo "== PowerShell:$PS_BINS"
echo "== node: $(node --version)"

# 1. The template itself.
cd "$ROOT" || exit 2
echo "== template"
if sh scripts/check.sh >"$WORK/log" 2>&1; then ok "template: check.sh"; else bad "template: check.sh"; show "$WORK/log"; fi
for ps in $PS_BINS; do
  if run_ps "$ps" scripts/check.ps1 >"$WORK/log" 2>&1; then ok "template: check.ps1 ($ps)"; else bad "template: check.ps1 ($ps)"; show "$WORK/log"; fi
done
if [ -z "${AJV_DIR:-}" ]; then
  bad "template: AJV_DIR is not set, schema examples were not validated"
elif node modules/tools/validate-examples.cjs >"$WORK/log" 2>&1; then
  ok "template: validate-examples.cjs"
else
  bad "template: validate-examples.cjs"; show "$WORK/log"
fi

# 2. init and check on copies, sh against PowerShell.
copy_repo() {
  mkdir -p "$1"
  tar --exclude=.git -cf - . | (cd "$1" && tar -xf -)
}
files_of() { (cd "$1" && find . -type f | sort); }

# case = "<profile>" or "<profile>:<modules>"
for c in lite full lite:memory lite:roles; do
  profile=${c%%:*}
  mods=
  case $c in *:*) mods=${c#*:} ;; esac
  echo "== init $c"

  SH_DIR="$WORK/sh-$(echo "$c" | tr ':' '-')"
  copy_repo "$SH_DIR"
  (
    cd "$SH_DIR" || exit 2
    if [ -n "$mods" ]; then set -- --modules "$mods"; else set --; fi
    sh scripts/init.sh --name smoke --profile "$profile" "$@" \
      --install-cmd "echo install" --run-cmd "echo run" --check-cmd "echo test"
  ) >"$WORK/log" 2>&1 || { bad "$c: init.sh"; show "$WORK/log"; continue; }
  ok "$c: init.sh"

  for gone in modules TEMPLATE.md scripts/init.sh scripts/init.ps1 .github/workflows; do
    if [ -e "$SH_DIR/$gone" ]; then bad "$c: init.sh left $gone behind"; fi
  done
  (cd "$SH_DIR" && sh scripts/check.sh) >"$WORK/sh-check" 2>&1 && ok "$c: check.sh after init.sh" || { bad "$c: check.sh after init.sh"; show "$WORK/sh-check"; }
  if [ "$profile" = full ] && grep -q '^\[SKIP\]' "$WORK/sh-check"; then bad "$c: full profile has a SKIP"; show "$WORK/sh-check"; fi

  for ps in $PS_BINS; do
    PS_DIR="$WORK/ps-$ps-$(echo "$c" | tr ':' '-')"
    copy_repo "$PS_DIR"
    (
      cd "$PS_DIR" || exit 2
      if [ -n "$mods" ]; then set -- -Modules "$mods"; else set --; fi
      run_ps "$ps" scripts/init.ps1 -Name smoke -Profile "$profile" "$@" \
        -InstallCmd "echo install" -RunCmd "echo run" -CheckCmd "echo test"
    ) >"$WORK/log" 2>&1 || { bad "$c: init.ps1 ($ps)"; show "$WORK/log"; continue; }
    ok "$c: init.ps1 ($ps)"

    (cd "$PS_DIR" && run_ps "$ps" scripts/check.ps1) >"$WORK/ps-check" 2>&1 && ok "$c: check.ps1 after init.ps1 ($ps)" || { bad "$c: check.ps1 after init.ps1 ($ps)"; show "$WORK/ps-check"; }

    files_of "$SH_DIR" >"$WORK/a.list"
    files_of "$PS_DIR" >"$WORK/b.list"
    if cmp -s "$WORK/a.list" "$WORK/b.list"; then
      ok "$c: same files in sh and $ps ($(wc -l <"$WORK/a.list" | tr -d ' '))"
    else
      bad "$c: files differ between sh and $ps"; diff "$WORK/a.list" "$WORK/b.list" | head -20
      continue
    fi
    differ=0
    while IFS= read -r f; do
      tr -d '\r' <"$SH_DIR/$f" >"$WORK/a.txt"
      tr -d '\r' <"$PS_DIR/$f" >"$WORK/b.txt"
      if ! cmp -s "$WORK/a.txt" "$WORK/b.txt"; then differ=1; bad "$c: $f differs between sh and $ps"; diff "$WORK/a.txt" "$WORK/b.txt" | head -10; fi
    done <"$WORK/a.list"
    if [ "$differ" = 0 ]; then ok "$c: same content in sh and $ps"; fi

    # Same verdict and same lines from both check variants (ignoring line endings).
    tr -d '\r' <"$WORK/ps-check" >"$WORK/b.txt"
    if cmp -s "$WORK/sh-check" "$WORK/b.txt"; then ok "$c: check.sh and check.ps1 print the same"; else bad "$c: check output differs"; diff "$WORK/sh-check" "$WORK/b.txt" | head -10; fi
  done
done

echo
if [ "$FAILS" -eq 0 ]; then echo "smoke: all passed"; else echo "smoke: $FAILS failed"; fi
[ "$FAILS" -eq 0 ]
