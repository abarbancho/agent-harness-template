#!/usr/bin/env sh
# Applies a profile and optional modules to this template, then fills in placeholders.
# Behavior is specified in modules/README.md. Keep scripts/init.ps1 in sync with this file.
#
# Usage: sh scripts/init.sh --name NAME [--profile lite|full] [--modules a,b]
#                           [--install-cmd CMD] [--run-cmd CMD] [--check-cmd CMD]
#                           [--dry-run] [--keep]
#   --dry-run  print what would change, touch nothing
#   --keep     do not delete modules/, the init scripts, TEMPLATE.md and the CI workflow afterwards
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
MODS="$ROOT/modules"

die() { echo "init: $*" >&2; exit 1; }
need() { [ $# -ge 2 ] || die "$1 needs a value"; }

NAME= PROFILE=lite EXTRA= INSTALL= RUN= CHECK= DRY=0 KEEP=0
while [ $# -gt 0 ]; do
  case $1 in
    --name) need "$@"; NAME=$2; shift 2 ;;
    --profile) need "$@"; PROFILE=$2; shift 2 ;;
    --modules) need "$@"; EXTRA=$2; shift 2 ;;
    --install-cmd) need "$@"; INSTALL=$2; shift 2 ;;
    --run-cmd) need "$@"; RUN=$2; shift 2 ;;
    --check-cmd) need "$@"; CHECK=$2; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --keep) KEEP=1; shift ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$NAME" ] || die "--name is required"
[ -d "$MODS" ] || die "modules/ not found: this repo is already initialized"

# One-line JSON array values only (see modules/README.md): prints the items space-separated.
json_list() {
  sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\[\(.*\)\].*/\1/p" "$1" | tr -d '"' | tr ',' ' '
}

grep -q "\"$PROFILE\"[[:space:]]*:" "$MODS/profiles.json" || die "unknown profile: $PROFILE"

RESOLVED=
VISITING=
add_module() {
  [ -f "$MODS/$1/module.json" ] || die "unknown module: $1"
  case " $RESOLVED " in *" $1 "*) return 0 ;; esac
  case " $VISITING " in *" $1 "*) die "dependency cycle at module: $1" ;; esac
  VISITING="$VISITING $1"
  for dep in $(json_list "$MODS/$1/module.json" requires); do add_module "$dep"; done
  RESOLVED="$RESOLVED $1"
}

for m in $(json_list "$MODS/profiles.json" "$PROFILE") $(echo "$EXTRA" | tr ',' ' '); do
  add_module "$m"
done

echo "Project: $NAME"
echo "Profile: $PROFILE"
echo "Modules:${RESOLVED:- (none)}"
[ "$DRY" = 1 ] && echo "(dry run: nothing is changed)"

for m in $RESOLVED; do
  src="$MODS/$m/files"
  [ -d "$src" ] || continue
  echo "[$m]"
  (cd "$src" && find . -type f | sort) | while IFS= read -r f; do
    f=${f#./}
    if [ -e "$ROOT/$f" ]; then
      echo "  skip (exists): $f"
    else
      echo "  add: $f"
      if [ "$DRY" = 0 ]; then
        mkdir -p "$(dirname "$ROOT/$f")"
        cp "$src/$f" "$ROOT/$f"
      fi
    fi
  done
done

# Insert module snippets at the markers in AGENTS.md and remove the markers.
if [ "$DRY" = 0 ] && [ -f "$ROOT/AGENTS.md" ]; then
  MAP=$(mktemp)
  RULES=$(mktemp)
  for m in $RESOLVED; do
    if [ -s "$MODS/$m/AGENTS.map.md" ]; then cat "$MODS/$m/AGENTS.map.md" >> "$MAP"; fi
    if [ -s "$MODS/$m/AGENTS.rules.md" ]; then cat "$MODS/$m/AGENTS.rules.md" >> "$RULES"; fi
  done
  awk -v map="$MAP" -v rules="$RULES" '
    { l = $0; sub(/\r$/, "", l) }
    l == "<!-- modules:map -->" { while ((getline line < map) > 0) print line; close(map); next }
    l == "<!-- modules:rules -->" { while ((getline line < rules) > 0) print line; close(rules); next }
    { print }' "$ROOT/AGENTS.md" > "$ROOT/AGENTS.md.tmp"
  mv "$ROOT/AGENTS.md.tmp" "$ROOT/AGENTS.md"
  rm -f "$MAP" "$RULES"
fi

# Strip the template-only blocks from README.md and AGENTS.md.
for doc in README.md AGENTS.md; do
  if [ "$DRY" = 0 ] && [ -f "$ROOT/$doc" ]; then
    awk '
      { l = $0; sub(/\r$/, "", l) }
      l == "<!-- template:start -->" { skip = 1; next }
      l == "<!-- template:end -->" { skip = 0; next }
      !skip { print }' "$ROOT/$doc" > "$ROOT/$doc.tmp"
    mv "$ROOT/$doc.tmp" "$ROOT/$doc"
  fi
done

# Fill in placeholders. Unset commands keep their placeholder and are reported below.
replace() {
  [ -n "$2" ] || return 0
  v=$(printf '%s' "$2" | sed -e 's/[\\&|]/\\&/g')
  grep -rlF "{{$1}}" "$ROOT" --exclude-dir=.git --exclude-dir=modules --exclude-dir=scripts 2>/dev/null |
  while IFS= read -r f; do
    echo "  fill {{$1}}: ${f#"$ROOT"/}"
    if [ "$DRY" = 0 ]; then
      sed "s|{{$1}}|$v|g" "$f" > "$f.tmp"
      mv "$f.tmp" "$f"
    fi
  done
}
echo "[placeholders]"
replace PROJECT_NAME "$NAME"
replace INSTALL_CMD "$INSTALL"
replace RUN_CMD "$RUN"
replace CHECK_CMD "$CHECK"

if [ "$DRY" = 0 ] && [ "$KEEP" = 0 ]; then
  rm -rf "$MODS"
  rm -f "$ROOT/scripts/init.sh" "$ROOT/scripts/init.ps1" "$ROOT/TEMPLATE.md" "$ROOT/.github/workflows/template-ci.yml"
  rmdir "$ROOT/.github/workflows" 2>/dev/null || true
  echo "Removed modules/, scripts/init.*, TEMPLATE.md and the template CI workflow"
fi

if [ "$DRY" = 0 ]; then
  left=$(grep -rhoE "\{\{[A-Z_]+\}\}" "$ROOT" --exclude-dir=.git --exclude-dir=modules --exclude-dir=scripts 2>/dev/null | sort -u | tr '\n' ' ')
  [ -z "$left" ] || echo "Still to fill in by hand: $left"
fi
echo "Done."
