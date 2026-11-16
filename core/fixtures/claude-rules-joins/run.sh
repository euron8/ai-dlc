#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# Exercise scripts/validate-claude-rules.sh -- the join between CLAUDE.md and the
# path-scoped authoring rules under `.claude/rules/`.
#
# Behavioural arms over throwaway repos under a temp dir: the control tree passes, the cli cells
# (pass, finding, usage) agree byte for byte with the in-process call, the no-VERSION refusal names
# the running copy, and the corpus read holds under an inherited git environment (m13).
set -u
# Clear every inherited AI_DLC_* tunable and CLAUDE_PROJECT_DIR so a bare run judges the code, not the caller environment.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR

# SCRUB THE REPOSITORY ENVIRONMENT BEFORE THIS FIXTURE BUILDS ANYTHING, and note that this
# fixture's own subject is the defect that makes it necessary. Every seed below runs
# `git init` + `git add -A` in a `mktemp` tree and relies on git's upward DISCOVERY to find
# it. Git exports GIT_DIR, ABSOLUTE, to any hook running from a linked worktree, so a suite
# dispatched by an unscrubbed caller -- or an operator running this file by hand, which is
# what the repo's own rules tell people to do when debugging a fixture -- has the seeds
# writing the CALLER's index. MEASURED before this line existed: an outer repo of 17 tracked
# files went to 7, holding the seed's own paths, while the fixture printed PASS.
#
# The sibling prepush-worktree-env-scrub/run.sh scrubs at its top for this same stated
# reason. It was the only fixture of the 27 building scratch repos that did.
#
# m13 below sets GIT_DIR explicitly at its own call, which is the state it exists to measure, and that
# assignment is scoped to the command rather than exported here.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY

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
printf 'HERMETIC-CONSUMED %s\n' "$(cd "$(dirname "$VALIDATOR")" && pwd)/$(basename "$VALIDATOR")"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
note() { printf '%s\n' "$*"; }
# shellcheck source=/dev/null
. "$DIR/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }
# shellcheck source=/dev/null
. "$DIR/../lib/mutant.sh" || { echo "FIXTURE ERROR: lib/mutant.sh not found" >&2; exit 2; }
seed() {
  local d="$1"
  mkdir -p "$d/.claude/rules" "$d/scripts" "$d/core/fixtures/demo" "$d/docs/plans"
  echo "0.0.0" > "$d/VERSION"
  cp "$VALIDATOR" "$d/scripts/validate-claude-rules.sh"
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
  # A5 reads the DERIVED index rather than re-deriving the live set, so the seed needs one.
  # Two rows is enough: a citation the corpus makes, and a second so a one-row grammar
  # accident cannot pass for a working parse.
  printf '| ID | What it binds |\n|----|---------------|\n| I1 | a live invariant |\n| I74 | a second live invariant |\n' \
    > "$d/docs/invariant-index.md"
  cat > "$d/CLAUDE.md" <<'EOF'
# Authoring rules
Read `.claude/rules/scoped.md` before touching fixtures.
The three hand-written lists are joined to the derived set by **I74**, in both directions.
EOF
  ( cd "$d" && git init -q . && git add -A >/dev/null 2>&1 )
}

# IN PROCESS (BL-878). Each seeded tree's validator copy is SOURCED ONCE into this shell by src_vcr (its guard
# returns after defining vcr_main; one fx_inproc pass per copy, and the copy sourced last is not sourced again), and
# run_v / run_v_env call vcr_main inside a `( )` subshell after a `cd` into that tree, so the subject's `exit`, its
# `cd "$ROOT"`, its EXIT trap and its unset of the repository environment stay there. An env word a drive carries
# is EXPORTED in that subshell, which is what `env VAR=x bash` gave the program, and the subject's own top-of-main
# unset then meets it exactly as it did. Inside vcr_main BASH_SOURCE[0] is the tree's copy, so its VERSION walk-up
# finds the tree. Every src_vcr runs in THIS shell, never inside a `$( )`. The copies sit at <tree>/scripts/<name>,
# the subject's relative path, so each pass is counted under the inproc: row.
VCR_SOURCED=""
src_vcr() { # src_vcr <tree>
  local c="$1/scripts/validate-claude-rules.sh"
  [ "$c" = "$VCR_SOURCED" ] && return 0
  unset -f vcr_main
  fx_inproc "$c"
  . "$c" || { echo "FIXTURE BROKEN: sourcing $c failed" >&2; exit 2; }
  declare -F vcr_main > /dev/null || { echo "FIXTURE BROKEN: sourcing $c defined no vcr_main" >&2; exit 2; }
  VCR_SOURCED="$c"
}
vcr_ready() { [ "$1/scripts/validate-claude-rules.sh" = "$VCR_SOURCED" ] || { echo "FIXTURE BROKEN: driving $1 while ${VCR_SOURCED:-nothing} is sourced" >&2; return 97; }; }
run_v() { vcr_ready "$1" || return 97; ( cd "$1" && fx_inproc "$VCR_SOURCED" && vcr_main 2>&1 ); }
run_v_env() { vcr_ready "$2" || return 97; ( cd "$2" && export "$1" && fx_inproc "$VCR_SOURCED" && vcr_main 2>&1 ); }

# --- the cli cells (cells.decl): the validator run as a PROGRAM once per distinct CLI outcome -----------------
# Outcomes, by exit: 0 every arm passes (cli-pass, over the control tree), 1 a finding (cli-finding, over m1's tree),
# 2 a usage refusal (cli-usage, an unknown argument). One `FXCELL=<id> bash scripts/validate-claude-rules.sh` start
# each from inside the tree, compared byte for byte (stdout, stderr, exit) with vcr_main of the same copy, sourced
# last, called in process from the same directory. Each also asserts its own outcome.
EQ="$TMP/eq"; mkdir -p "$EQ"
eqv() { # eqv <cell-id> <tree> <args...>
  local id="$1" t="$2"; shift 2
  vcr_ready "$t" || exit 2
  ( cd "$t" && fx_inproc "$VCR_SOURCED" && vcr_main "$@" ) > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  ( cd "$t" && FXCELL="$id" bash scripts/validate-claude-rules.sh "$@" ) > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_rc() { cat "$EQ/$1.cl.rc"; }
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(tail -c 300 "$EQ/$1.ip.out")" "$(tail -c 300 "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(tail -c 300 "$EQ/$1.cl.out")" "$(tail -c 300 "$EQ/$1.cl.err")"; }

# --- control ------------------------------------------------------
seed "$TMP/control"
src_vcr "$TMP/control"
if out="$(run_v "$TMP/control")" && [ -n "$out" ]; then
  ok "control -- clean tree passes, harness is live"
else
  note "FIXTURE BROKEN: the control did NOT pass. Every verdict below is meaningless."
  printf '%s\n' "$out" | sed 's/^/      /'
  exit 1
fi
if eqv cli-pass "$TMP/control" && [ "$(eq_rc cli-pass)" = 0 ] && grep -q '^OK: validate-claude-rules' "$EQ/cli-pass.cl.out"; then
  ok "cli-pass: the program passes the control tree exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-pass: the program and the in-process call differ, or the outcome is not exit 0 with its OK line ($(eq_twin cli-pass))"; fi
if eqv cli-usage "$TMP/control" --no-such-flag && [ "$(eq_rc cli-usage)" = 2 ] && [ ! -s "$EQ/cli-usage.cl.out" ] \
   && [ "$(cat "$EQ/cli-usage.cl.err")" = "usage: validate-claude-rules.sh [--quiet]" ]; then
  ok "cli-usage: the program refuses an unknown argument exactly as the in-process call does (stderr, exit 2)"
else bad "cli-usage: the program and the in-process call differ, or the outcome is not exit 2 with the usage line ($(eq_twin cli-usage))"; fi

# --- bad-input arms ----------------------------------------------------------
# rejects <name> <dir> <expected-substring>: the unmodified validator must exit non-zero on the seeded bad tree, print
# the expected substring, and print exactly one FAIL line (its own arm's), so two arms speaking means they are entangled.
rejects() {
  local n="$1" d="$2" pat="$3" out rc_v nfail
  src_vcr "$d"
  out="$(run_v "$d")"; rc_v=$?
  nfail="$(printf '%s\n' "$out" | grep -c '^FAIL:')"
  if [ "$rc_v" -eq 0 ]; then
    bad "$n -- validator exited 0 on a bad tree"; return
  fi
  if ! grep -qF "$pat" <<<"$out"; then
    bad "$n -- validator failed, but not on its own assertion (wanted: $pat)"
    printf '%s\n' "$out" | sed 's/^/      /' | head -4; return
  fi
  if [ "$nfail" -ne 1 ]; then
    bad "$n -- $nfail FAIL lines; a bad tree must fail ONLY its own assertion, so the arms are entangled"; return
  fi
  ok "$n -- rejected by its own arm, and only its own"
}

edit_seed() { # edit_seed <file> <sed-expr> ; seeds a bad input; guarded so a no-op sed cannot pass as an edit
  local f="$1" expr="$2"
  cp "$f" "$f.orig"
  sed "$expr" "$f.orig" > "$f"
  if cmp -s "$f" "$f.orig"; then rm -f "$f.orig"; return 1; fi
  rm -f "$f.orig"; return 0
}

# m1 -- A1 tracked non-rule path, also the finding tree for cli-finding
seed "$TMP/m1"; printf '{}\n' > "$TMP/m1/.claude/settings.json"
( cd "$TMP/m1" && git add -f .claude/settings.json >/dev/null 2>&1 )
rejects "m1 A1 tracked non-rule path" "$TMP/m1" "A1: tracked path(s) under .claude/"
if eqv cli-finding "$TMP/m1" && [ "$(eq_rc cli-finding)" = 1 ] && grep -qF 'A1: tracked path(s) under .claude/' "$EQ/cli-finding.cl.err"; then
  ok "cli-finding: the program convicts m1's tracked non-rule path exactly as the in-process call does (exit 1)"
else bad "cli-finding: the program and the in-process call differ, or the outcome is not exit 1 naming A1 ($(eq_twin cli-finding))"; fi
# The no-VERSION refusal names the program through BASH_SOURCE[0]. Run in process, `$0` names this fixture, so a
# validator reading `$0` would name run.sh; the message must name the copy that is running.
seed "$TMP/nover"; rm -f "$TMP/nover/VERSION"
src_vcr "$TMP/nover"
nv_out="$(run_v "$TMP/nover")"; nv_rc=$?
if [ "$nv_rc" -eq 2 ] && grep -qF "(no VERSION marker above $TMP/nover/scripts/validate-claude-rules.sh)" <<<"$nv_out"; then
  ok "no VERSION above the copy: exit 2, and the refusal names the copy that is running, not its caller"
else bad "no VERSION above the copy: want exit 2 naming $TMP/nover/scripts/validate-claude-rules.sh; got exit $nv_rc: $(printf '%s' "$nv_out" | head -1)"; fi
if ! cmp -s "$EQ/cli-pass.cl.rc" "$EQ/cli-finding.cl.rc" && ! cmp -s "$EQ/cli-finding.cl.rc" "$EQ/cli-usage.cl.rc" \
   && ! cmp -s "$EQ/cli-pass.cl.err" "$EQ/cli-finding.cl.err"; then
  ok "cli cells discriminate: pass, finding and usage exit 0, 1 and 2, and only the finding prints an A1 conviction"
else bad "cli cells do not discriminate: two of cli-pass, cli-finding, cli-usage share an exit, or pass and finding share stderr"; fi

# m2 -- A2 orphan glob
seed "$TMP/m2"
if edit_seed "$TMP/m2/.claude/rules/scoped.md" 's|core/fixtures/\*\*|core/fixture/**|'; then
  ( cd "$TMP/m2" && git add -A >/dev/null 2>&1 )
  rejects "m2 A2 orphan glob" "$TMP/m2" "matches NO tracked path"
else bad "m2 -- sed matched nothing; no edit occurred"; fi

# m3 -- A3 Cursor frontmatter
seed "$TMP/m3"
if edit_seed "$TMP/m3/.claude/rules/scoped.md" 's|^paths:|globs:|'; then
  ( cd "$TMP/m3" && git add -A >/dev/null 2>&1 )
  rejects "m3 A3 Cursor globs: key" "$TMP/m3" "silently UNCONDITIONAL"
else bad "m3 -- sed matched nothing; no edit occurred"; fi

# m4 -- A4 dangling pointer
seed "$TMP/m4"
if edit_seed "$TMP/m4/CLAUDE.md" 's|scoped\.md|ghost.md|'; then
  ( cd "$TMP/m4" && git add -A >/dev/null 2>&1 )
  rejects "m4 A4 dangling pointer" "$TMP/m4" "which does not exist"
else bad "m4 -- sed matched nothing; no edit occurred"; fi

# m5 -- A4 unreachable rule
seed "$TMP/m5"
printf -- '---\npaths:\n  - "docs/plans/**"\n---\n# Orphan\nNo pointer, no marker.\n' \
  > "$TMP/m5/.claude/rules/orphan.md"
( cd "$TMP/m5" && git add -A >/dev/null 2>&1 )
rejects "m5 A4 unreachable rule" "$TMP/m5" "no CLAUDE.md pointer and no"

# m6 -- A4 empty no-stub reason
seed "$TMP/m6"
printf -- '---\npaths:\n  - "docs/plans/**"\n---\n<!-- no-stub: -->\n# Orphan\n' \
  > "$TMP/m6/.claude/rules/orphan.md"
( cd "$TMP/m6" && git add -A >/dev/null 2>&1 )
rejects "m6 A4 empty no-stub reason" "$TMP/m6" "EMPTY"

# m7 -- A3b a rule declaring NEITHER scope. It carries a CLAUDE.md pointer so A4 stays
# quiet: a tree that trips two arms proves neither of them.
seed "$TMP/m7"
printf -- '# Unscoped\nNo frontmatter at all.\n' > "$TMP/m7/.claude/rules/noscope.md"
printf 'Also read `.claude/rules/noscope.md`.\n' >> "$TMP/m7/CLAUDE.md"
( cd "$TMP/m7" && git add -A >/dev/null 2>&1 )
rejects "m7 A3b no scope declared" "$TMP/m7" "declares no scope"

# m8 -- A3b BOTH declarations. Added to the file that already carries a no-stub marker,
# so A4 is satisfied and only the scope arm can speak.
seed "$TMP/m8"
if edit_seed "$TMP/m8/.claude/rules/scoped.md" 's|^# Scoped|<!-- unconditional: also claimed resident -->\n# Scoped|'; then
  ( cd "$TMP/m8" && git add -A >/dev/null 2>&1 )
  rejects "m8 A3b both declarations" "$TMP/m8" "carries BOTH"
else bad "m8 -- sed matched nothing; no edit occurred"; fi

# m9 -- A3b an unconditional marker with no reason. Carries a no-stub so A4 is quiet.
seed "$TMP/m9"
printf -- '<!-- no-stub: pointed at from nowhere on purpose -->\n<!-- unconditional: -->\n# Empty reason\n' \
  > "$TMP/m9/.claude/rules/uncond.md"
( cd "$TMP/m9" && git add -A >/dev/null 2>&1 )
rejects "m9 A3b empty unconditional reason" "$TMP/m9" "EMPTY \`unconditional:\` marker"

# m10 -- A5 a bold citation naming an id the index does not list.
seed "$TMP/m10"
if edit_seed "$TMP/m10/CLAUDE.md" 's|\*\*I74\*\*|**I999**|'; then
  ( cd "$TMP/m10" && git add -A >/dev/null 2>&1 )
  rejects "m10 A5 dead invariant citation" "$TMP/m10" "as a live mechanism, and no arm declares it"
else bad "m10 -- sed matched nothing; no edit occurred"; fi


# m11 -- A6 over the ceiling. Driven by the documented override rather than by writing a
# 32 KB file, so the arm is tested at its real comparison and not at its file arithmetic.
seed "$TMP/m11"
src_vcr "$TMP/m11"
out="$(run_v_env AI_DLC_DURABLE_BYTES=10 "$TMP/m11")"
if [ -z "$out" ] || ! grep -qF "against a ceiling of 10" <<<"$out"; then
  bad "m11 A6 over ceiling -- validator accepted the tree or failed on another arm"
  printf '%s\n' "$out" | sed 's/^/      /' | head -4
elif [ "$(printf '%s\n' "$out" | grep -c '^FAIL:')" -ne 1 ]; then
  bad "m11 A6 over ceiling -- more than one FAIL line; the arms are entangled"
else
  ok "m11 A6 over ceiling -- rejected by its own arm, and only its own"
fi

# m13 -- THE CORPUS READ IS REDIRECTED BY AN INHERITED GIT ENVIRONMENT, AND IT IS THE SILENT FAILURE.
#
# `a1_offenders()` and `glob_matches()` enumerate the corpus with bare `git ls-files`; redirected by an
# inherited environment they answer about the caller's repo, and A1 then reports `ok` over a corpus it
# never opened.
#
# WHY A REAL OFFENDER: an inherited environment that leaves the corpus read redirected prints a
# silent false green on a clean-looking victim, so the arm needs a real offender and a clean victim.
#
# THE SEED IS A REAL OFFENDER, not a near-miss: a tracked `.claude/settings.json` in the corpus,
# against a victim repo that is CLEAN under `.claude/`. So the arm reads a CONVICTION and not an
# absence -- if the corpus read is redirected, A1 finds nothing to report and prints ok, which is
# exactly the acquittal being guarded. An arm asserting "no findings" could not tell the two apart.
seed "$TMP/m13"
printf '{}\n' > "$TMP/m13/.claude/settings.json"
( cd "$TMP/m13" && git add -f .claude/settings.json >/dev/null 2>&1 )
m13victim="$TMP/m13victim"
mkdir -p "$m13victim"
( cd "$m13victim" && git init -q . \
  && for i in 1 2 3 4 5 6 7 8 9 10 11; do printf 'x\n' > "g$i.txt"; done \
  && git add -A >/dev/null 2>&1 )
m13_vclaude="$( ( cd "$m13victim" && git ls-files -- '.claude' | wc -l ) | tr -d ' ' )"
m13_corpus="$( ( cd "$TMP/m13" && git ls-files -- '.claude' | grep -c 'settings.json' ) || true )"
if [ "$m13_vclaude" -ne 0 ] || [ "$m13_corpus" -ne 1 ]; then
  bad "FIXTURE BROKEN: m13 needs a corpus tracking .claude/settings.json (got $m13_corpus) and a victim clean under .claude/ (got $m13_vclaude tracked). The arm cannot discriminate."
else
  # BOTH DIRECTIONS, in the same run. Scrubbed: A1 must convict. Inherited: A1 must convict
  # the SAME offender. A build that reads the victim prints `A1  ok` on the second only.
  src_vcr "$TMP/m13"
  m13_clean="$(run_v_env "AI_DLC_UNUSED=1" "$TMP/m13")"
  m13_armed="$(run_v_env "GIT_DIR=$m13victim/.git" "$TMP/m13")"
  if ! grep -qF "A1: tracked path(s) under .claude/" <<<"$m13_clean"; then
    bad "FIXTURE BROKEN: m13's offender was NOT convicted in a clean environment, so the armed arm below proves nothing."
  elif grep -qF "A1  ok" <<<"$m13_armed"; then
    bad "m13 corpus read redirected -- A1 reported ok under an inherited GIT_DIR while the corpus tracks a real offender. The scrub does not cover the arms' READ; the arm's own subject is acquitted with nothing to give it away."
  elif ! grep -qF "A1: tracked path(s) under .claude/" <<<"$m13_armed"; then
    bad "m13 -- A1 neither convicted nor acquitted under an inherited GIT_DIR; the run is unreadable."
    printf '%s\n' "$m13_armed" | sed 's/^/      /' | head -4
  else
    ok "m13 -- corpus read survives an inherited GIT_DIR; A1 convicts the same offender scrubbed and armed"
  fi
fi

report_end claude-rules-joins
