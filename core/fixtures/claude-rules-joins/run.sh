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
#   m7  A3b a rule declaring neither paths: nor unconditional:   -> must FAIL
#   m8  A3b a rule declaring BOTH                                -> must FAIL
#   m9  A3b an `unconditional:` marker with an EMPTY reason      -> must FAIL
#   m10 A5  a bold **I<n>** citation the index does not list     -> must FAIL
#   m11 A6  durable channel over its byte ceiling                -> must FAIL
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
# m12 below is unaffected: it sets GIT_DIR explicitly at its own call, which is the state it
# exists to measure, and that assignment is scoped to the command rather than exported here.
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

run_v() { ( cd "$1" && bash scripts/validate-claude-rules.sh 2>&1 ); }
run_v_env() { ( cd "$2" && env "$1" bash scripts/validate-claude-rules.sh 2>&1 ); }

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

# m7 -- A3b a rule declaring NEITHER scope. It carries a CLAUDE.md pointer so A4 stays
# quiet: a mutant that trips two arms proves neither of them.
seed "$TMP/m7"
printf -- '# Unscoped\nNo frontmatter at all.\n' > "$TMP/m7/.claude/rules/noscope.md"
printf 'Also read `.claude/rules/noscope.md`.\n' >> "$TMP/m7/CLAUDE.md"
( cd "$TMP/m7" && git add -A >/dev/null 2>&1 )
kill_check "m7 A3b no scope declared" "$TMP/m7" "declares no scope"

# m8 -- A3b BOTH declarations. Added to the file that already carries a no-stub marker,
# so A4 is satisfied and only the scope arm can speak.
seed "$TMP/m8"
if mutate "$TMP/m8/.claude/rules/scoped.md" 's|^# Scoped|<!-- unconditional: also claimed resident -->\n# Scoped|'; then
  ( cd "$TMP/m8" && git add -A >/dev/null 2>&1 )
  kill_check "m8 A3b both declarations" "$TMP/m8" "carries BOTH"
else note "SKIP  m8 -- sed matched nothing; no mutation occurred"; rc=1; fi

# m9 -- A3b an unconditional marker with no reason. Carries a no-stub so A4 is quiet.
seed "$TMP/m9"
printf -- '<!-- no-stub: pointed at from nowhere on purpose -->\n<!-- unconditional: -->\n# Empty reason\n' \
  > "$TMP/m9/.claude/rules/uncond.md"
( cd "$TMP/m9" && git add -A >/dev/null 2>&1 )
kill_check "m9 A3b empty unconditional reason" "$TMP/m9" "EMPTY \`unconditional:\` marker"

# m10 -- A5 a bold citation naming an id the index does not list.
seed "$TMP/m10"
if mutate "$TMP/m10/CLAUDE.md" 's|\*\*I74\*\*|**I999**|'; then
  ( cd "$TMP/m10" && git add -A >/dev/null 2>&1 )
  kill_check "m10 A5 dead invariant citation" "$TMP/m10" "as a live mechanism, and no arm declares it"
else note "SKIP  m10 -- sed matched nothing; no mutation occurred"; rc=1; fi

# m11 -- A6 over the ceiling. Driven by the documented override rather than by writing a
# 32 KB file, so the arm is tested at its real comparison and not at its file arithmetic.
seed "$TMP/m11"
out="$(run_v_env AI_DLC_DURABLE_BYTES=10 "$TMP/m11")"
if [ -z "$out" ] || ! grep -qF "against a ceiling of 10" <<<"$out"; then
  note "FAIL  m11 A6 over ceiling -- mutant SURVIVED or failed on another arm"
  printf '%s\n' "$out" | sed 's/^/      /' | head -4; rc=1
elif [ "$(printf '%s\n' "$out" | grep -c '^FAIL:')" -ne 1 ]; then
  note "FAIL  m11 A6 over ceiling -- more than one FAIL line; the arms are entangled"; rc=1
else
  note "ok    m11 A6 over ceiling -- killed by its own arm, and only its own"
fi

# m12 -- THE PROBE MUST BUILD ITS OWN REPOSITORY, NOT WRITE THE CALLER'S.
#
# A1's probe builds a scratch repo under `mktemp` and relies on git's upward DISCOVERY to
# find it. Discovery is the branch git takes only when the repository environment is unset,
# and git exports GIT_DIR -- ABSOLUTE -- into any hook running from a linked worktree. So a
# validator invoked with that environment inherited writes the CALLER's index instead of the
# probe's. Measured on a clone of this repo pushed from a linked worktree before the fix:
# the index collapsed 757 entries to 3.
#
# THIS ARM IS BEHAVIOURAL AND NOT A TEXT ANCHOR, for the reason the sibling
# prepush-worktree-env-scrub fixture states about its own subject: a `grep` for the `unset`
# establishes that a line EXISTS, never that it executes, executes in the right shell, or
# executes BEFORE the `git add`. What is asserted here is the OUTCOME -- a victim repository
# whose index is untouched across the run -- so any fix that achieves it passes and any that
# does not fails, whatever it looks like.
#
# WHY THE VICTIM IS SEEDED WITH A DISTINCTIVE COUNT rather than checked for equality alone:
# the probe writes exactly its own two paths, so a victim that happened to hold two entries
# would compare equal to a clobbered one. Nine entries cannot be confused with the probe's two.
#
# THE ENV IS SET AT THE CALL, not exported here, so this arm cannot leak into the arms below.
seed "$TMP/m12"
victim="$TMP/m12victim"
mkdir -p "$victim"
( cd "$victim" && git init -q . \
  && for i in 1 2 3 4 5 6 7 8 9; do printf 'x\n' > "f$i.txt"; done \
  && git add -A >/dev/null 2>&1 )
v_before="$( ( cd "$victim" && git ls-files | wc -l ) | tr -d ' ' )"
if [ "$v_before" -ne 9 ]; then
  note "FIXTURE BROKEN: m12's victim repo seeded $v_before entries, expected 9. The arm below cannot discriminate."
  rc=1
else
  # The ARMING control: with the environment inherited, this is the exact shape git hands a
  # hook pushed from a linked worktree. If the seed cannot express that, the arm is vacuous.
  out="$(run_v_env "GIT_DIR=$victim/.git" "$TMP/m12")"
  v_after="$( ( cd "$victim" && git ls-files | wc -l ) | tr -d ' ' )"
  if [ "$v_after" -ne "$v_before" ]; then
    note "FAIL  m12 probe wrote the caller's index -- victim went $v_before -> $v_after entries."
    note "      A1's probe must build its own repository; inherited GIT_DIR redirected its \`git add\`."
    rc=1
  elif [ -z "$out" ]; then
    note "FAIL  m12 -- validator produced no output under an inherited GIT_DIR; cannot tell a pass from a dead run."
    rc=1
  elif ! grep -qF "A1  ok" <<<"$out"; then
    note "FAIL  m12 -- victim index survived, but A1 did not report ok; the probe is not firing."
    printf '%s\n' "$out" | sed 's/^/      /' | head -4
    rc=1
  else
    note "ok    m12 -- probe built its own repo under an inherited GIT_DIR; caller's index intact at $v_after, A1 still fired"
  fi

  # m12b -- THE INPUT THAT SEPARATES THE FIX FROM THE ONE-VARIABLE NEAR-MISS.
  #
  # A `GIT_DIR`-only scrub PASSES both drives above: `GIT_DIR` is the single variable they
  # set, so unsetting it is sufficient for them and the near-miss scores as fixed. It is not
  # fixed — git resolves a repository from `GIT_INDEX_FILE` and `GIT_WORK_TREE` as well, and
  # exports `GIT_INDEX_FILE` to a pre-commit hook even from a PRIMARY checkout, so that world
  # is one a real caller arrives in.
  #
  # THIS ARM EXISTS BECAUSE THE SEPARATING INPUT WAS IDENTIFIED, WRITTEN INTO THE ENTRY, AND
  # THEN NOT DRIVEN. An adversarial pass caught that: the arms above assert the right
  # OUTCOME against an input that cannot distinguish the two builds, which is a seed defect
  # and not an assertion defect. A near-miss one property short of the offender discriminates
  # against nothing that requires that property.
  #
  # `GIT_DIR` is deliberately ABSENT here. Setting it would let a `GIT_DIR`-only scrub pass
  # by handling the one variable it knows, which is exactly the build being hunted.
  m12b_victim="$TMP/m12bvictim"
  mkdir -p "$m12b_victim"
  ( cd "$m12b_victim" && git init -q . \
    && for i in 1 2 3 4 5 6 7; do printf 'x\n' > "h$i.txt"; done \
    && git add -A >/dev/null 2>&1 )
  b_before="$( ( cd "$m12b_victim" && git ls-files | wc -l ) | tr -d ' ' )"
  if [ "$b_before" -ne 7 ]; then
    note "FIXTURE BROKEN: m12b's victim seeded $b_before entries, expected 7; the arm cannot discriminate."
    rc=1
  else
    out_b="$( cd "$TMP/m12" && env "GIT_INDEX_FILE=$m12b_victim/.git/index" "GIT_WORK_TREE=$m12b_victim" \
      bash scripts/validate-claude-rules.sh 2>&1 )"
    b_after="$( ( cd "$m12b_victim" && git ls-files | wc -l ) | tr -d ' ' )"
    if [ "$b_after" -ne "$b_before" ]; then
      note "FAIL  m12b probe wrote the caller's index through GIT_INDEX_FILE -- victim went $b_before -> $b_after."
      note "      A GIT_DIR-only scrub passes m12 and m13 and fails here; the scrub must cover all five variables."
      rc=1
    elif ! grep -qF "A1  ok" <<<"$out_b"; then
      note "FAIL  m12b -- victim intact but A1 did not fire under GIT_INDEX_FILE/GIT_WORK_TREE; the probe is redirected."
      printf '%s\n' "$out_b" | sed 's/^/      /' | head -4
      rc=1
    else
      note "ok    m12b -- GIT_INDEX_FILE/GIT_WORK_TREE without GIT_DIR: victim intact at $b_after, A1 still fired"
    fi
  fi
fi

# m13 -- THE CORPUS READ IS THE OTHER HALF, AND IT IS THE SILENT ONE.
#
# m12 above asserts the probe does not WRITE the caller's repository. This asserts the arms do
# not READ it. `a1_offenders()` and `glob_matches()` enumerate the corpus with bare `git
# ls-files`; redirected by an inherited environment they answer about the caller's repo, and A1
# then reports `ok` over a corpus it never opened.
#
# WHY BOTH ARMS ARE NEEDED, and why m12 alone was not enough: a fix that scrubs only the probe
# subshell PASSES m12 -- the index is intact and A1 fires -- while the corpus read stays
# redirected. That build converts a loud clobber into a silent false green, which is strictly
# worse than the defect, and m12 scores it as fixed. The two arms are one property apart.
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
  note "FIXTURE BROKEN: m13 needs a corpus tracking .claude/settings.json (got $m13_corpus) and a victim clean under .claude/ (got $m13_vclaude tracked). The arm cannot discriminate."
  rc=1
else
  # BOTH DIRECTIONS, in the same run. Scrubbed: A1 must convict. Inherited: A1 must convict
  # the SAME offender. A build that reads the victim prints `A1  ok` on the second only, so
  # the pair separates a working scrub from one that covers the write alone.
  m13_clean="$(run_v_env "AI_DLC_UNUSED=1" "$TMP/m13")"
  m13_armed="$(run_v_env "GIT_DIR=$m13victim/.git" "$TMP/m13")"
  if ! grep -qF "A1: tracked path(s) under .claude/" <<<"$m13_clean"; then
    note "FIXTURE BROKEN: m13's offender was NOT convicted in a clean environment, so the armed arm below proves nothing."
    rc=1
  elif grep -qF "A1  ok" <<<"$m13_armed"; then
    note "FAIL  m13 corpus read redirected -- A1 reported ok under an inherited GIT_DIR while the corpus tracks a real offender."
    note "      The scrub covers the probe's WRITE and not the arms' READ; the arm's own subject is acquitted with nothing to give it away."
    rc=1
  elif ! grep -qF "A1: tracked path(s) under .claude/" <<<"$m13_armed"; then
    note "FAIL  m13 -- A1 neither convicted nor acquitted under an inherited GIT_DIR; the run is unreadable."
    printf '%s\n' "$m13_armed" | sed 's/^/      /' | head -4
    rc=1
  else
    note "ok    m13 -- corpus read survives an inherited GIT_DIR; A1 convicts the same offender scrubbed and armed"
  fi
fi

if [ "$rc" -eq 0 ]; then note "PASS  claude-rules-joins -- control green, 13/13 mutants killed by their own arm"; fi
exit "$rc"
