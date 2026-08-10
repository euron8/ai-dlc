#!/usr/bin/env bash
# Exercise scripts/validate-claude-rules.sh -- the join between CLAUDE.md and the
# path-scoped authoring rules under `.claude/rules/`.
#
# Six mutants plus an UNMUTATED CONTROL, each a throwaway repo under a temp dir.
# Exit 0 iff the control is green AND all six mutants are killed by their own arm.
#
#   control  clean seed tree                                    -> must PASS
#   m1  A1  a tracked `.claude/settings.json`                    -> must FAIL
#   m2  A2  a `paths:` glob typo'd to match nothing              -> must FAIL
#   m3  A3  frontmatter `globs:` instead of `paths:`             -> must FAIL
#   m4  A4  CLAUDE.md pointing at a rule file that is not there  -> must FAIL
#   m5  A4  a rule with neither pointer nor no-stub marker       -> must FAIL
#   m6  A4  a no-stub marker with an EMPTY reason                -> must FAIL
#
# WHY THE CONTROL IS NOT DECORATION. Each mutant is a fresh seed plus one edit, and the
# validator resolves its own root by walking up for VERSION. A seed that fails to build
# -- no VERSION, no git -- makes the validator exit 2 and print nothing, and "no output"
# would otherwise score as a kill on all six. The control is what separates "the arm
# fired" from "the harness died".
#
# WHY `cmp -s` GUARDS EVERY sed. A `sed` whose pattern stopped matching produces a
# byte-identical copy; the validator then correctly passes and the arm reports SURVIVED
# for a mutation that never happened. The guard turns that into an explicit SKIP.
#
# A mutant must fail ONLY its own assertion. Two FAIL lines mean the arms are entangled
# and one of them is vacuous, so the count is asserted, not just the message.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

VALIDATOR=""
for cand in \
  "$DIR/../../scripts/validate-claude-rules.sh" \
  "$DIR/../../../scripts/validate-claude-rules.sh"; do
  [ -f "$cand" ] && VALIDATOR="$cand" && break
done
if [ -z "$VALIDATOR" ]; then
  echo "run.sh: could not locate validate-claude-rules.sh" >&2
  exit 2
fi
GITIGNORE="$(dirname "$(dirname "$DIR")")/.gitignore"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
note() { printf '%s\n' "$*"; }

seed() {
  local d="$1"
  mkdir -p "$d/.claude/rules" "$d/scripts" "$d/core/fixtures/demo" "$d/docs/plans"
  echo "0.0.0" > "$d/VERSION"
  cp "$VALIDATOR" "$d/scripts/validate-claude-rules.sh"
  [ -f "$GITIGNORE" ] && cp "$GITIGNORE" "$d/.gitignore"
  printf 'run\n' > "$d/core/fixtures/demo/run.sh"
  printf 'plan\n' > "$d/docs/plans/p.md"
  cat > "$d/.claude/rules/scoped.md" <<'EOF'
---
paths:
  - "core/fixtures/**"
---
<!-- no-stub: work begins by reading a fixture file, so the trigger fires. -->
# Scoped
Body.
EOF
  cat > "$d/CLAUDE.md" <<'EOF'
# Authoring rules
Read `.claude/rules/scoped.md` before touching fixtures.
EOF
  ( cd "$d" && git init -q . && git add -A >/dev/null 2>&1 )
}

run_v() { ( cd "$1" && bash scripts/validate-claude-rules.sh 2>&1 ); }

# --- unmutated control ------------------------------------------------------
seed "$TMP/control"
if out="$(run_v "$TMP/control")" && [ -n "$out" ]; then
  note "ok    control -- clean tree passes, harness is live"
else
  note "FIXTURE BROKEN: the unmutated control did NOT pass. Every mutant verdict below is meaningless."
  printf '%s\n' "$out" | sed 's/^/      /'
  exit 1
fi

# --- mutant driver ----------------------------------------------------------
kill_check() { # kill_check <name> <dir> <expected-substring>
  local n="$1" d="$2" pat="$3" out rc_v nfail
  out="$(run_v "$d")"; rc_v=$?
  nfail="$(printf '%s\n' "$out" | grep -c '^FAIL:')"
  if [ "$rc_v" -eq 0 ]; then
    note "FAIL  $n -- mutant SURVIVED (validator exited 0)"; rc=1; return
  fi
  if ! grep -qF "$pat" <<<"$out"; then
    note "FAIL  $n -- validator failed, but not on its own assertion (wanted: $pat)"
    printf '%s\n' "$out" | sed 's/^/      /' | head -4; rc=1; return
  fi
  if [ "$nfail" -ne 1 ]; then
    note "FAIL  $n -- $nfail FAIL lines; a mutant must fail ONLY its own assertion, so the arms are entangled"
    rc=1; return
  fi
  note "ok    $n -- killed by its own arm, and only its own"
}

mutate() { # mutate <file> <sed-expr> ; guarded so a no-op sed cannot pass as a mutation
  local f="$1" expr="$2"
  cp "$f" "$f.orig"
  sed "$expr" "$f.orig" > "$f"
  if cmp -s "$f" "$f.orig"; then rm -f "$f.orig"; return 1; fi
  rm -f "$f.orig"; return 0
}

# m1 -- A1 tracked non-rule path
seed "$TMP/m1"; printf '{}\n' > "$TMP/m1/.claude/settings.json"
( cd "$TMP/m1" && git add -f .claude/settings.json >/dev/null 2>&1 )
kill_check "m1 A1 tracked non-rule path" "$TMP/m1" "A1: tracked path(s) under .claude/"

# m2 -- A2 orphan glob
seed "$TMP/m2"
if mutate "$TMP/m2/.claude/rules/scoped.md" 's|core/fixtures/\*\*|core/fixture/**|'; then
  ( cd "$TMP/m2" && git add -A >/dev/null 2>&1 )
  kill_check "m2 A2 orphan glob" "$TMP/m2" "matches NO tracked path"
else note "SKIP  m2 -- sed matched nothing; no mutation occurred"; rc=1; fi

# m3 -- A3 Cursor frontmatter
seed "$TMP/m3"
if mutate "$TMP/m3/.claude/rules/scoped.md" 's|^paths:|globs:|'; then
  ( cd "$TMP/m3" && git add -A >/dev/null 2>&1 )
  kill_check "m3 A3 Cursor globs: key" "$TMP/m3" "silently UNCONDITIONAL"
else note "SKIP  m3 -- sed matched nothing; no mutation occurred"; rc=1; fi

# m4 -- A4 dangling pointer
seed "$TMP/m4"
if mutate "$TMP/m4/CLAUDE.md" 's|scoped\.md|ghost.md|'; then
  ( cd "$TMP/m4" && git add -A >/dev/null 2>&1 )
  kill_check "m4 A4 dangling pointer" "$TMP/m4" "which does not exist"
else note "SKIP  m4 -- sed matched nothing; no mutation occurred"; rc=1; fi

# m5 -- A4 unreachable rule
seed "$TMP/m5"
printf -- '---\npaths:\n  - "docs/plans/**"\n---\n# Orphan\nNo pointer, no marker.\n' \
  > "$TMP/m5/.claude/rules/orphan.md"
( cd "$TMP/m5" && git add -A >/dev/null 2>&1 )
kill_check "m5 A4 unreachable rule" "$TMP/m5" "no CLAUDE.md pointer and no"

# m6 -- A4 empty no-stub reason
seed "$TMP/m6"
printf -- '---\npaths:\n  - "docs/plans/**"\n---\n<!-- no-stub: -->\n# Orphan\n' \
  > "$TMP/m6/.claude/rules/orphan.md"
( cd "$TMP/m6" && git add -A >/dev/null 2>&1 )
kill_check "m6 A4 empty no-stub reason" "$TMP/m6" "EMPTY"

if [ "$rc" -eq 0 ]; then note "PASS  claude-rules-joins -- control green, 6/6 mutants killed by their own arm"; fi
exit "$rc"
