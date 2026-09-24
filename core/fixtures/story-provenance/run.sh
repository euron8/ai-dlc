#!/usr/bin/env bash
# Exercise stamp-story-provenance.sh (writer + --check) against the story-provenance fixture.
#
# Exit 0 iff every seeded case behaves correctly. This fixture is the teeth of Check 17's
# story-provenance cross-check: the story-file terminal residue used to be hand-transcribed "per
# precedent" and drifted (one sprint with artifact_sha, one without, free-text comments the parser
# ignores). The writer makes the write side mechanical; this fixture proves the check FIRES on the
# drift, PASSES on a mechanical stamp, is idempotent, refuses a placeholder tool_use_id, and
# refuses to stamp an unconverged cycle.
#
# WHERE EXIT CODES COINCIDE, ASSERT ON THE MESSAGE (this repo's own rule — a check that cannot
# fire reads exactly like one that passed). The refuse-placeholder and refuse-unconverged cases
# both exit 1, as does the drift case; each asserts the DISTINGUISHING message.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

WRITER=""
for cand in \
  "$DIR/../../scripts/stamp-story-provenance.sh" \
  "$DIR/../../../scripts/ai-dlc/stamp-story-provenance.sh" \
  "$DIR/../../core/scripts/stamp-story-provenance.sh"; do
  [ -f "$cand" ] && WRITER="$cand" && break
done
if [ -z "$WRITER" ]; then
  echo "FAIL: cannot locate stamp-story-provenance.sh from $DIR"
  exit 1
fi

ROOT="$(bash "$DIR/seed.sh" | tail -1)"
NM_EXTRA=""
trap 'rm -rf "$ROOT" ${NM_EXTRA:+"$NM_EXTRA"}' EXIT

REAL_TID="toolu_FIXTUREaaaaaaaa"
FAILURES=0
ASSERTIONS=0

# $1 label  $2 want-exit  $3 want-substring (or "")  then command...
expect() {
  local label="$1" want="$2" needle="$3"; shift 3
  local out got
  ASSERTIONS=$((ASSERTIONS + 1))
  out="$("$@" 2>&1)"; got=$?
  local ok=1
  [ "$got" -eq "$want" ] || ok=0
  if [ -n "$needle" ] && ! grep -qF "$needle" <<<"$out"; then ok=0; fi
  if [ "$ok" -eq 1 ]; then
    printf '  ok    %-46s exit=%s\n' "$label" "$got"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-46s exit=%s want=%s needle=%q\n' "$label" "$got" "$want" "$needle"
    printf '        out: %s\n' "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)"
  fi
}

C="$ROOT/converged"

# 1. --check on the pre-stamp stories (one missing block, one drifted) MUST report DRIFT.
expect "converged: --check pre-stamp = DRIFT" 1 "DRIFT" \
  bash "$WRITER" --series "$C/s1-stories-adversarial" --check "$C/stories/story-1.md" "$C/stories/story-2.md"

# 2. Stamp for real.
expect "converged: stamp" 0 "stamped 2 of 2" \
  bash "$WRITER" --series "$C/s1-stories-adversarial" "$C/stories/story-1.md" "$C/stories/story-2.md"

# 3. --check now passes (mechanical block matches; idempotent).
expect "converged: --check post-stamp = OK" 0 "OK" \
  bash "$WRITER" --series "$C/s1-stories-adversarial" --check "$C/stories/story-1.md" "$C/stories/story-2.md"

# 4. Re-stamp writes nothing (idempotent).
expect "converged: re-stamp idempotent" 0 "stamped 0 of 2" \
  bash "$WRITER" --series "$C/s1-stories-adversarial" "$C/stories/story-1.md" "$C/stories/story-2.md"

# 5. MUTANT: tamper a field in a stamped block -> --check MUST fail. Proves the check is not vacuous.
sed -i.bak 's/^findings_minor: 2/findings_minor: 9/' "$C/stories/story-1.md"
expect "converged: tampered block = DRIFT" 1 "DRIFT" \
  bash "$WRITER" --series "$C/s1-stories-adversarial" --check "$C/stories/story-1.md"
mv "$C/stories/story-1.md.bak" "$C/stories/story-1.md"

# 6. MUTANT: tamper the story BODY after stamping -> artifact_sha goes stale -> --check MUST fail.
printf '\nedited after stamping.\n' >> "$C/stories/story-2.md"
expect "converged: stale artifact_sha = DRIFT" 1 "DRIFT" \
  bash "$WRITER" --series "$C/s1-stories-adversarial" --check "$C/stories/story-2.md"

P="$ROOT/placeholder"

# 7. Placeholder terminal tool_use_id, NO override -> REFUSE (not a valid toolu_ id).
expect "placeholder: refuse without override" 1 "not a valid toolu_ id" \
  bash "$WRITER" --series "$P/s1-stories-adversarial" "$P/stories/story-1.md"

# 8. Placeholder terminal + --tool-use-id -> stamps AND backfills the SoR.
expect "placeholder: stamp+backfill with override" 0 "backfilled tool_use_id" \
  bash "$WRITER" --series "$P/s1-stories-adversarial" --tool-use-id "$REAL_TID" "$P/stories/story-1.md"

# 9. After backfill, --check runs override-free (SoR now holds the real id).
expect "placeholder: --check override-free post-backfill = OK" 0 "OK" \
  bash "$WRITER" --series "$P/s1-stories-adversarial" --check "$P/stories/story-1.md"

# 10. MUTANT: a garbage override is refused, not accepted.
expect "placeholder: garbage override refused" 1 "not a valid toolu_ id" \
  bash "$WRITER" --series "$P/s1-stories-adversarial" --tool-use-id "nope" "$P/stories/story-1.md"

# 10a/10b. THE WRITER REFUSES WHAT THE READER REFUSES. Arm 10's `nope` is a CHARSET miss, so it
# could never tell the pattern check from the forbidden check — and under the pattern alone the
# stamper wrote onto every story a placeholder that validate-provenance-block.sh then rejected.
# Both of these CLEAR the charset pattern, so only the schema's `forbidden` list can refuse them,
# and the decorated one is refused only under `forbidden_match: prefix_ci`. The two together are
# what separates a writer that reads the field from one that restates a literal.
expect "placeholder: bare forbidden literal refused" 1 "placeholder literal the schema forbids" \
  bash "$WRITER" --series "$P/s1-stories-adversarial" --tool-use-id "toolu_PLACEHOLDER" "$P/stories/story-1.md"
expect "placeholder: DECORATED forbidden literal refused" 1 "placeholder literal the schema forbids" \
  bash "$WRITER" --series "$P/s1-stories-adversarial" --tool-use-id "toolu_PLACEHOLDER_LEAD_TO_FILL" "$P/stories/story-1.md"

U="$ROOT/unconverged"

# 11. SAFETY: terminal verdict is not EXIT_CONDITION_MET -> refuse to stamp.
expect "unconverged: refuse to stamp" 1 "not EXIT_CONDITION_MET" \
  bash "$WRITER" --series "$U/s1-stories-adversarial" "$U/stories/story-1.md"

O="$ROOT/oneshot"

# --- The bug variant. A ONE-SHOT stamps no verdict and cites the bmad skill, so the default
# profile refuses it by construction and nothing else writes a block onto a bug story. Two
# consecutive bug-variant stories shipped with none. Assertions 12-17 are the two doors and the
# proof that neither opens the other.

# 12. THE DEFECT: the default profile cannot stamp a bug story at all.
expect "oneshot: default profile refuses the bmad skill" 1 "expected 'ai-dlc-adversary-review'" \
  bash "$WRITER" --terminal "$O/s1-bug-fix-oneshot.md" "$O/stories/story-bug-1.md"

# 13. --check before the stamp is DRIFT (a bug story with no block is not silently fine).
expect "oneshot: --check pre-stamp = DRIFT" 1 "DRIFT" \
  bash "$WRITER" --terminal "$O/s1-bug-fix-oneshot.md" --profile bug-story-provenance --check \
    "$O/stories/story-bug-1.md"

# 14. Stamp with the bug profile. The summary must NOT print a bare `None` where the verdict
#     would be: a field the producer is forbidden to write reads as a parse failure otherwise.
expect "oneshot: stamp under the bug profile" 0 "one-shot, no verdict" \
  bash "$WRITER" --terminal "$O/s1-bug-fix-oneshot.md" --profile bug-story-provenance \
    "$O/stories/story-bug-1.md"

# 15. --check now passes, and the block cites the skill Check 17's bug arm requires.
expect "oneshot: --check post-stamp = OK" 0 "OK" \
  bash "$WRITER" --terminal "$O/s1-bug-fix-oneshot.md" --profile bug-story-provenance --check \
    "$O/stories/story-bug-1.md"
ASSERTIONS=$((ASSERTIONS + 1))
if grep -q '^skill: bmad-review-adversarial-general$' "$O/stories/story-bug-1.md" \
   && ! grep -q '^verdict:' "$O/stories/story-bug-1.md"; then
  printf '  ok    %-46s\n' "oneshot: block cites the bmad skill, no verdict"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-46s\n' "oneshot: block cites the bmad skill, no verdict"
fi

# 16. THE REVERSE DOOR. A convergence pass carrying the one-shot's skill name must still be
#     refused by the one-shot profile — on the VERDICT rule, not the skill pin. Without this the
#     bug profile would be a hole through which an unconverged cycle reaches a story with its
#     verdict silently dropped.
expect "oneshot: verdict-bearing pass refused" 1 "must carry no verdict" \
  bash "$WRITER" --terminal "$O/s1-bug-fix-oneshot-with-verdict.md" --profile bug-story-provenance \
    "$O/stories/story-bug-1.md"

# 17. An unknown profile is a usage error, not a silent fall-back to the default.
expect "unknown profile is refused (exit 2)" 2 "is not a profile in the schema" \
  bash "$WRITER" --terminal "$O/s1-bug-fix-oneshot.md" --profile no-such-profile \
    "$O/stories/story-bug-1.md"

# 18. MUTATION — the verdict rule is DERIVED from the profile, so deleting `verdict` from the
#     CONVERGENCE profile's batch_invariant must turn assertion 11 (refuse-unconverged) into a
#     pass-through. Mutating the SCHEMA rather than the script is the point: it proves the guard
#     reads the profile and is not a constant the script happens to agree with.
# ASK THE WRITER where its schema is; never walk up from it. The install mapping SPLITS the
# two — core/scripts/<x> lands at <root>/scripts/ai-dlc/<x> while core/schemas/ lands at
# <root>/.claude/schemas/ — so "../schemas" and "../../schemas" are both right in the
# distribution and both wrong on every consumer. This fixture already resolves the WRITER
# through a chain that names the consumer path; the schema lookup was a private second copy of
# a derivation the writer owns, and it made the fixture red on every consumer while staying
# green here. Step 2 requires the derived fixtures green BEFORE the push, so that red was a
# permanent stop on the self-update, not a nuisance.
SCHEMA_SRC="$(bash "$WRITER" --print-schema 2>/dev/null)"
MUTROOT="$ROOT/mut"; mkdir -p "$MUTROOT/scripts" "$MUTROOT/schemas"
cp "$WRITER" "$MUTROOT/scripts/stamp-story-provenance.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if [ ! -f "$SCHEMA_SRC" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-46s\n' "FIXTURE BROKEN: writer --print-schema resolved nothing (got: ${SCHEMA_SRC:-<empty>})"
else
  # The subject: a CONVERGENCE pass (right skill) carrying NO verdict at all, and a fresh story.
  # Under the real schema `verdict` is batch-invariant, so its absence is not EXIT_CONDITION_MET
  # and the writer refuses. Under the mutant the profile has become a one-shot profile, no verdict
  # is present to object to, and the stamp goes through — which is the derived behaviour under test.
  # Under the mutant the profile IS a one-shot profile, and a one-shot binds only the story its
  # `artifact:` names — so the pass names the story it is stamped onto, or the mutant is refused
  # by the artifact bind and never reaches the verdict rule this arm is about. The control is
  # unaffected: the unmutated profile refuses on the verdict before the bind is read.
  grep -v '^verdict:' "$C/s1-stories-adversarial-p2.md" \
    | sed "s#^artifact:.*#artifact: $MUTROOT/story-mut.md#" > "$MUTROOT/noverdict-p1.md"
  mk_mut_story() { printf '# Story mut\n\n## Acceptance Criteria\n- AC(a): thing.\n' > "$MUTROOT/story-mut.md"; }
  mut_run() { # -> the writer's output, resolving the schema from $MUTROOT/schemas/
    mk_mut_story
    bash "$MUTROOT/scripts/stamp-story-provenance.sh" \
      --terminal "$MUTROOT/noverdict-p1.md" "$MUTROOT/story-mut.md" 2>&1
  }
  # CONTROL — the same writer, the same tree, the UNMUTATED schema. It must still refuse, or the
  # harness itself is what kills the guard and the mutant below proves nothing.
  cp "$SCHEMA_SRC" "$MUTROOT/schemas/provenance-block.json"
  ctl="$(mut_run)"
  # MUTANT — drop `verdict` from the CONVERGENCE profile's batch_invariant and nothing else.
  python3 - "$SCHEMA_SRC" "$MUTROOT/schemas/provenance-block.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
p = s["profiles"]["story-provenance"]
p["batch_invariant"] = [f for f in p["batch_invariant"] if f != "verdict"]
json.dump(s, open(sys.argv[2], "w"), indent=2)
PY
  mut="$(mut_run)"

  if ! grep -qF "not EXIT_CONDITION_MET" <<<"$ctl"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-46s\n' "FIXTURE BROKEN: control run does not refuse"
    printf '        out: %s\n' "$(printf '%s' "$ctl" | tr '\n' ' ' | cut -c1-160)"
  elif grep -qF "not EXIT_CONDITION_MET" <<<"$mut"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-46s\n' "mutation: schema mutant had no effect"
  elif ! grep -qF "stamped 1 of 1" <<<"$mut"; then
    # Absence of the refusal is not a kill on its own — the run could have died for an unrelated
    # reason. The kill is the guard letting an UNCONVERGED pass through to a real stamp.
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-46s\n' "mutation: mutant neither refused nor stamped"
    printf '        out: %s\n' "$(printf '%s' "$mut" | tr '\n' ' ' | cut -c1-160)"
  else
    printf '  ok    %-46s\n' "mutation: dropping verdict from the profile disarms the guard"
  fi
fi

# --- MIXED SPRINT. One planning slot holding a convergence-validated story and a FOLDED bug-fix
# story, as stories-test-strategy §3a produces. Check 17 sends the story a per-bug one-shot's
# `artifact:` names to the bug arm and every other story to the convergence arm; these arms prove
# each story passes ONLY its own arm, in both directions, and that the one-shot's `artifact:` is
# a binding and not a label. Paths inside the blocks are root-relative as the producer writes
# them, so every drive runs with the world as its working directory. seed.sh --mixed-into lists
# the world's members.
SEED="$DIR/seed.sh"
mixed_world() { # -> a fresh world directory; each caller gets its own, never a stamped one
  local w
  w="$(mktemp -d "$ROOT/mixed.XXXXXX")" || return 1
  bash "$SEED" --mixed-into "$w" || return 1
  printf '%s\n' "$w"
}
# $1 world  $2 writer  then writer args. The writer is run from INSIDE the world.
in_world() { local w="$1" wr="$2"; shift 2; ( cd "$w" && bash "$wr" "$@" ); }
# Stamp the world the way the two procedures do: the convergence stories through the series, the
# folded story through ITS OWN per-bug one-shot. This stamp is itself arm M1/M2 on the real writer.
S1C="s1/stories/story-1-feature.md"; S1U="s1/stories/story-3-unfolded.md"
S1B="s1/stories/story-2-fix-thing.md"; ONESHOT="s1/bug-fix-oneshot-story-2-fix-thing.md"
BUGP="bug-story-provenance"
# story-3 carries a WELL-FORMED bug block, stamped through a one-shot that really named it and is
# otherwise byte-identical to story-2's. That is the discriminating input for the bind: its block
# equals what story-2's one-shot derives (artifact is per-story, not batch-invariant), so only the
# bind separates "reviewed this story" from "reviewed another story".
forge_unfolded_bug_block() { # $1 world  $2 writer
  sed "s#^artifact:.*#artifact: $S1U#" "$1/$ONESHOT" > "$1/s1/scratch-oneshot-for-3.md"
  in_world "$1" "$2" --terminal s1/scratch-oneshot-for-3.md --profile "$BUGP" "$S1U" >/dev/null 2>&1
}

MW="$(mixed_world)"
if [ -z "$MW" ] || [ ! -f "$MW/$ONESHOT" ]; then
  ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-46s\n' "FIXTURE BROKEN: seed.sh --mixed-into built no world"
else
  # M1/M2 — the two stamps. M2 is the per-bug one-shot name ACCEPTED by --terminal.
  expect "mixed: convergence stories stamp via --series" 0 "stamped 2 of 2" \
    in_world "$MW" "$WRITER" --series s1/stories-adversarial "$S1C" "$S1U"
  expect "mixed: per-bug one-shot accepted by --terminal" 0 "stamped 1 of 1 story file(s) from $ONESHOT" \
    in_world "$MW" "$WRITER" --terminal "$ONESHOT" --profile "$BUGP" "$S1B"
  # A — each story passes its OWN arm.
  expect "mixed: convergence story passes --series arm" 0 "OK (2 story file(s) current)" \
    in_world "$MW" "$WRITER" --series s1/stories-adversarial --check "$S1C" "$S1U"
  expect "mixed: folded bug story passes bug arm" 0 "OK (1 story file(s) current)" \
    in_world "$MW" "$WRITER" --terminal "$ONESHOT" --profile "$BUGP" --check "$S1B"
  # C — the bug story FAILS the convergence arm. The needle names the story, so a DRIFT
  #     reported against some OTHER file cannot satisfy it. Its ALLOW twin is the arm above.
  expect "mixed: bug story FAILS --series arm" 1 "$S1B: block does not match" \
    in_world "$MW" "$WRITER" --series s1/stories-adversarial --check "$S1B"
  # D — the convergence story FAILS the bug arm, on its BLOCK and not on the bind: the legacy
  #     one-shot names story-1, so the bind is satisfied and only the profile can refuse it.
  #     This is also the legacy near-miss: Check 17 reads no declaration from the legacy name at
  #     the stories gate, story-1 stays on its arm and passes there (arm A), and this arm is
  #     what would happen to it if the legacy name DID route it.
  expect "mixed: convergence story FAILS bug arm (legacy)" 1 "$S1C: block does not match" \
    in_world "$MW" "$WRITER" --terminal s1/bug-fix-oneshot.md --profile "$BUGP" --check "$S1C"
  expect "mixed: legacy one-shot leaves story-1 on its arm" 0 "OK (1 story file(s) current)" \
    in_world "$MW" "$WRITER" --series s1/stories-adversarial --check "$S1C"
  # E — THE BIND. An unfolded story carrying a well-formed bug block, checked through a one-shot
  #     that reviewed a DIFFERENT story, is refused; so is stamping it that way; so is a one-shot
  #     whose artifact names a story path that no longer exists.
  forge_unfolded_bug_block "$MW" "$WRITER"
  expect "mixed: bind control — story-3 block is well-formed" 0 "OK (1 story file(s) current)" \
    in_world "$MW" "$WRITER" --terminal s1/scratch-oneshot-for-3.md --profile "$BUGP" --check "$S1U"
  expect "mixed: bind refuses --check of an unnamed story" 1 "which is not the story being checked: $S1U" \
    in_world "$MW" "$WRITER" --terminal "$ONESHOT" --profile "$BUGP" --check "$S1U"
  expect "mixed: bind refuses stamping an unnamed story" 1 "which is not the story being stamped: $S1U" \
    in_world "$MW" "$WRITER" --terminal "$ONESHOT" --profile "$BUGP" "$S1U"
  expect "mixed: bind refuses an artifact naming no file" 1 "which is not the story being checked: $S1B" \
    in_world "$MW" "$WRITER" --terminal s1/bug-fix-oneshot-story-9-moved.md --profile "$BUGP" --check "$S1B"
  # The bind does not reach the CONVERGENCE door: its pass names the stories DIRECTORY, which is
  # no story, and arm A passed through it. Asserted by arm A itself.
fi

# R — THE PROJECT-ROOT BASE. `artifact:` is root-relative, and the gate need not run from the
# root. Run from the sprint slot, the working-directory base cannot resolve the field (it would
# read s1/s1/...), so only the project-root base binds it. A fresh world, because MW's bug story
# is already stamped and would print "stamped 0 of 1".
RW="$(mixed_world)"
if [ -z "$RW" ] || [ ! -f "$RW/$ONESHOT" ]; then
  ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-46s\n' "FIXTURE BROKEN: seed.sh --mixed-into built no world (R)"
else
  expect "mixed: bind resolves artifact via project root" 0 "stamped 1 of 1" \
    env AI_DLC_PROJECT_ROOT="$RW" bash -c 'cd "$1/s1" && bash "$2" --terminal "$3" --profile "$4" "$5"' _ \
      "$RW" "$WRITER" "${ONESHOT#s1/}" "$BUGP" "${S1B#s1/}"
fi

# --- MUTANTS OF THE MIXED ARMS. Each is a copy of the writer in a scripts/ + schemas/ layout
# (its schema sibling is asserted present), driven over a FRESH mixed world, beside an
# UNMUTATED copy in the identical layout that must produce the arm's PRESENCE row. A mutant
# scores only if it applied (cmp differs), the control printed the refusal, and the mutant
# printed the OPPOSITE positive row — never merely the absence of the refusal.
MUTX="$(mktemp -d "$ROOT/mutx.XXXXXX")"
mkdir -p "$MUTX/scripts" "$MUTX/schemas"
cp "$WRITER" "$MUTX/scripts/ctl.sh"
if [ -f "$SCHEMA_SRC" ]; then cp "$SCHEMA_SRC" "$MUTX/schemas/provenance-block.json"; fi
# $1 name  $2 python mutation program (reads $1 path of source, writes $2 path of mutant)
mk_mutx() {
  local out="$MUTX/scripts/$1.sh"
  if ! python3 -c "$2" "$WRITER" "$out" 2>"$MUTX/$1.err"; then
    echo "DID NOT APPLY: $(head -1 "$MUTX/$1.err")"; return 1
  fi
  if cmp -s "$WRITER" "$out"; then echo "DID NOT APPLY: identical to the writer"; return 1; fi
  printf '%s\n' "$out"
}
# The anchor for each mutation is a STATEMENT THE SUBJECT EXECUTES, located structurally and
# required to occur exactly once; the program refuses (non-zero) on zero or several.
#
# MB — the bind: the predicate the one-shot guard calls answers "bound" for every story.
MB_PROG='
import re, sys
src = open(sys.argv[1]).read()
defs = re.findall(r"(?m)^def (\w+)\(story_path\):\n", src)
guard = re.findall(r"(?m)^    unbound = \[sp for sp in story_paths if not (\w+)\(sp\)\]$", src)
if len(guard) != 1 or guard[0] not in defs:
    sys.exit("anchor: one-shot guard predicate not found exactly once")
name = guard[0]
hdr = "def %s(story_path):\n" % name
if src.count(hdr) != 1:
    sys.exit("anchor: predicate definition not unique")
open(sys.argv[2], "w").write(src.replace(hdr, hdr + "    return True\n"))
'
# MC — the check compares nothing: any story that carries SOME block reads as current. This is
# the property arms C and D stand on (a block from the other door is refused by content).
MC_PROG='
import re, sys
src = open(sys.argv[1]).read()
pat = r"(?m)^(    if check_only:\n        # [^\n]*\n        if )new_content != content(:)"
if len(re.findall(pat, src)) != 1:
    sys.exit("anchor: check-mode comparison not found exactly once")
open(sys.argv[2], "w").write(re.sub(pat, r"\1not BLOCK_RE.findall(content)\2", src))
'
# Control for the anchors themselves: an impossible anchor must be refused, or a program that
# "applies" to anything is what is being scored.
ASSERTIONS=$((ASSERTIONS + 1))
if python3 -c 'import sys; src=open(sys.argv[1]).read(); sys.exit(0 if src.count("def zz_never_a_def_here(") == 0 else 1)' "$WRITER" \
   && [ -f "$MUTX/schemas/provenance-block.json" ] \
   && [ "$(AI_DLC_PROJECT_ROOT="$MUTX" bash "$MUTX/scripts/ctl.sh" --print-schema 2>/dev/null)" -ef "$MUTX/schemas/provenance-block.json" ]; then
  printf '  ok    %-46s\n' "mutants: layout control (schema sibling resolved)"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-46s\n' "FIXTURE BROKEN: mutant copy does not resolve its schema sibling"
fi

# $1 label  $2 mutant path-or-DID-NOT-APPLY  $3 ctl-needle  $4 mut-needle  then writer args
score_mutant() {
  local label="$1" mp="$2" cn="$3" mn="$4"; shift 4
  local w1 w2 ctl mut
  ASSERTIONS=$((ASSERTIONS + 1))
  case "$mp" in "DID NOT APPLY"*)
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-46s %s\n' "$label" "$mp"; return ;;
  esac
  w1="$(mixed_world)"; w2="$(mixed_world)"
  for wx in "$w1" "$w2"; do
    in_world "$wx" "$WRITER" --series s1/stories-adversarial "$S1C" "$S1U" >/dev/null 2>&1
    in_world "$wx" "$WRITER" --terminal "$ONESHOT" --profile "$BUGP" "$S1B" >/dev/null 2>&1
    forge_unfolded_bug_block "$wx" "$WRITER"
  done
  ctl="$(cd "$w1" && AI_DLC_PROJECT_ROOT="$w1" bash "$MUTX/scripts/ctl.sh" "$@" 2>&1)"
  mut="$(cd "$w2" && AI_DLC_PROJECT_ROOT="$w2" bash "$mp" "$@" 2>&1)"
  if ! grep -qF -- "$cn" <<<"$ctl"; then
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-46s %s\n' "$label" "FIXTURE BROKEN: control lacks its row"
    printf '        ctl: %s\n' "$(printf '%s' "$ctl" | tr '\n' ' ' | cut -c1-200)"
  elif [ "$ctl" = "$mut" ]; then
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-46s %s\n' "$label" "SURVIVED: mutant output identical to control"
  elif ! grep -qF -- "$mn" <<<"$mut"; then
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-46s %s\n' "$label" "SURVIVED: mutant lacks the opposite row"
    printf '        mut: %s\n' "$(printf '%s' "$mut" | tr '\n' ' ' | cut -c1-200)"
  else
    printf '  ok    %-46s\n' "$label"
  fi
}

MB="$(mk_mutx mb "$MB_PROG")"
score_mutant "mutant MB (bind deleted) killed by bind arm" "$MB" \
  "which is not the story being checked: $S1U" "OK (1 story file(s) current)" \
  --terminal "$ONESHOT" --profile "$BUGP" --check "$S1U"
MC="$(mk_mutx mc "$MC_PROG")"
score_mutant "mutant MC (content blind) killed by arm C" "$MC" \
  "$S1B: block does not match" "OK (1 story file(s) current)" \
  --series s1/stories-adversarial --check "$S1B"
score_mutant "mutant MC (content blind) killed by arm D" "$MC" \
  "$S1C: block does not match" "OK (1 story file(s) current)" \
  --terminal s1/bug-fix-oneshot.md --profile "$BUGP" --check "$S1C"

# MR — the bind loses its project-root base: inside the predicate the one-shot guard calls, the
# one statement appending the root to the candidate bases becomes a no-op. Arm R owns it: run
# from the sprint slot, the control stamps and the mutant refuses on the bind. Scored on two
# fresh UNSTAMPED worlds, so the control's row is a real stamp and not "stamped 0 of 1".
MR_PROG='
import re, sys
src = open(sys.argv[1]).read()
guard = re.findall(r"(?m)^    unbound = \[sp for sp in story_paths if not (\w+)\(sp\)\]$", src)
if len(guard) != 1:
    sys.exit("anchor: one-shot guard predicate not found exactly once")
m = re.search(r"(?ms)^def %s\(story_path\):\n(.*?)(?=^\S)" % guard[0], src)
if not m:
    sys.exit("anchor: predicate body not found")
body = m.group(1)
hits = re.findall(r"(?m)^( +)bases\.append\([^\n]*\)\n", body)
if len(hits) != 1:
    sys.exit("anchor: root-base append not found exactly once in the predicate")
new_body = re.sub(r"(?m)^( +)bases\.append\([^\n]*\)\n", r"\1pass\n", body, count=1)
open(sys.argv[2], "w").write(src[:m.start(1)] + new_body + src[m.end(1):])
'
MR="$(mk_mutx mr "$MR_PROG")"
ASSERTIONS=$((ASSERTIONS + 1))
case "$MR" in
  "DID NOT APPLY"*)
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-46s %s\n' "mutant MR (root base dropped) killed by arm R" "$MR" ;;
  *)
    r1="$(mixed_world)"; r2="$(mixed_world)"
    run_r() { # $1 world  $2 writer
      ( cd "$1/s1" && AI_DLC_PROJECT_ROOT="$1" bash "$2" --terminal "${ONESHOT#s1/}" \
          --profile "$BUGP" "${S1B#s1/}" 2>&1 )
    }
    ctl="$(run_r "$r1" "$MUTX/scripts/ctl.sh")"; mut="$(run_r "$r2" "$MR")"
    if ! grep -qF "stamped 1 of 1" <<<"$ctl"; then
      FAILURES=$((FAILURES + 1)); printf '  FAIL  %-46s %s\n' "mutant MR (root base dropped) killed by arm R" "FIXTURE BROKEN: control did not stamp"
      printf '        ctl: %s\n' "$(printf '%s' "$ctl" | tr '\n' ' ' | cut -c1-200)"
    elif [ "$ctl" = "$mut" ]; then
      FAILURES=$((FAILURES + 1)); printf '  FAIL  %-46s %s\n' "mutant MR (root base dropped) killed by arm R" "SURVIVED: mutant output identical to control"
    elif ! grep -qF "which is not the story being stamped: ${S1B#s1/}" <<<"$mut"; then
      FAILURES=$((FAILURES + 1)); printf '  FAIL  %-46s %s\n' "mutant MR (root base dropped) killed by arm R" "SURVIVED: mutant did not refuse on the bind"
      printf '        mut: %s\n' "$(printf '%s' "$mut" | tr '\n' ' ' | cut -c1-200)"
    else
      printf '  ok    %-46s\n' "mutant MR (root base dropped) killed by arm R"
    fi ;;
esac

# --- THE INSTALL'S SCHEMA. In a consumer the writer and reader sit at <root>/scripts/ai-dlc/ and
# the schema at <root>/.claude/schemas/, so an AI_DLC_PROJECT_ROOT naming a root with no schema of
# its own used to leave both with nothing to load: arm R was red on every consumer. Both now fall
# back to the install root, walked up from the script's own directory, as their LAST candidate —
# last in BOTH, so an override root that carries its own schema still wins in both and the pair
# never loads two different schemas. Four arms, each on a fresh sandbox <t>:
#   CI  consumer: the writer's --print-schema IS <t>'s schema (identity, not an exit code)
#   CR  consumer: the reader passes a story the writer just stamped under the same override
#   NI  near-miss: the foreign root carries its OWN schema, and the writer resolves THAT one
#   NR  near-miss: the reader resolves it too — the story carries a second block citing a skill
#       ONLY the foreign schema knows, so a reader that loaded <t>'s schema refuses it
# <t> carries .claude/ so the resolver's walk stops there and cannot find a host schema above the
# sandbox; the foreign root carries .claude/ too. The two schemas and the source differ in BYTES,
# so identity cannot be satisfied by a coincidence of content.
READER="$(dirname "$WRITER")/validate-provenance-block.sh"
CONS="$(mktemp -d "$ROOT/cons.XXXXXX")"
NEAR_SKILL="fixture-nearmiss-foreign-skill"
SCH="provenance-block.json"
cons_world() { # $1 "plain"|"near"  $2 extra script to place beside the pair (or "")  -> world dir
  local w; w="$(mktemp -d "$CONS/w.XXXXXX")" || return 1
  mkdir -p "$w/t/.claude/schemas" "$w/t/scripts/ai-dlc" "$w/f/.claude" "$w/f/stories" || return 1
  cp "$WRITER" "$w/t/scripts/ai-dlc/stamp-story-provenance.sh" || return 1
  cp "$READER" "$w/t/scripts/ai-dlc/validate-provenance-block.sh" || return 1
  [ -z "$2" ] || cp "$2" "$w/t/scripts/ai-dlc/$(basename "$2")" || return 1
  python3 -c 'import json,sys; json.dump(json.load(open(sys.argv[1])), open(sys.argv[2], "w"), indent=3)' \
    "$SCHEMA_SRC" "$w/t/.claude/schemas/$SCH" || return 1
  if [ "$1" = near ]; then
    mkdir -p "$w/f/.claude/schemas" || return 1
    python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); s["known_skills"]=list(s["known_skills"])+[sys.argv[3]]; json.dump(s, open(sys.argv[2], "w"), indent=5)' \
      "$SCHEMA_SRC" "$w/f/.claude/schemas/$SCH" "$NEAR_SKILL" || return 1
  fi
  cp "$ROOT/converged/s1-stories-adversarial-p2.md" "$w/f/pass-p2.md" || return 1
  printf '# Story cons\n\n## Acceptance Criteria\n- AC(a): thing.\n' > "$w/f/stories/story-cons.md"
  printf '%s\n' "$w"
}
# Each arm: $1 the script under test, by basename, placed beside the real pair (so it shares the
# pair's install root). Answers 0 held, 1 failed, 2 FIXTURE BROKEN; prints its evidence to stderr.
arm_ci() { local w out; w="$(cons_world plain "$2")" || return 2
  out="$(cd "$w/f" && AI_DLC_PROJECT_ROOT="$w/f" bash "$w/t/scripts/ai-dlc/$1" --print-schema 2>&1)"
  [ -n "$out" ] && [ "$out" -ef "$w/t/.claude/schemas/$SCH" ] && return 0
  echo "        CI resolved: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)" >&2; return 1; }
arm_ni() { local w out; w="$(cons_world near "$2")" || return 2
  out="$(cd "$w/f" && AI_DLC_PROJECT_ROOT="$w/f" bash "$w/t/scripts/ai-dlc/$1" --print-schema 2>&1)"
  [ -n "$out" ] && [ "$out" -ef "$w/f/.claude/schemas/$SCH" ] && return 0
  echo "        NI resolved: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)" >&2; return 1; }
# The stamp is always the REAL writer beside the pair, so a reader mutant cannot fail an arm by
# way of the writer and a writer mutant cannot fail a reader arm.
stamp_cons() { # $1 world
  ( cd "$1/f" && AI_DLC_PROJECT_ROOT="$1/f" bash "$1/t/scripts/ai-dlc/stamp-story-provenance.sh" \
      --terminal pass-p2.md stories/story-cons.md 2>&1 )
}
arm_cr() { local w st out rc; w="$(cons_world plain "$2")" || return 2
  st="$(stamp_cons "$w")"
  grep -qF "stamped 1 of 1" <<<"$st" || { echo "        CR stamp: $(printf '%s' "$st" | tr '\n' ' ' | cut -c1-200)" >&2; return 2; }
  out="$(cd "$w/f" && AI_DLC_PROJECT_ROOT="$w/f" bash "$w/t/scripts/ai-dlc/$1" stories/story-cons.md \
      --require-skill ai-dlc-adversary-review 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && grep -qF "PASS (stories/story-cons.md, 1 block(s)" <<<"$out" && return 0
  echo "        CR reader rc=$rc: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)" >&2; return 1; }
arm_nr() { local w st out rc; w="$(cons_world near "$2")" || return 2
  st="$(stamp_cons "$w")"
  grep -qF "stamped 1 of 1" <<<"$st" || { echo "        NR stamp: $(printf '%s' "$st" | tr '\n' ' ' | cut -c1-200)" >&2; return 2; }
  printf '\n<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: %s\ninvoked_at: 2026-01-02T03:04:05Z\ntool_use_id: %s\nmode: subagent\nlead_role: x.md\nartifact: stories/story-cons.md\nfindings_critical: 0\nfindings_major: 0\nfindings_minor: 0\nSKILL_INVOCATION_PROVENANCE_END -->\n' \
    "$NEAR_SKILL" "$REAL_TID" >> "$w/f/stories/story-cons.md"
  out="$(cd "$w/f" && AI_DLC_PROJECT_ROOT="$w/f" bash "$w/t/scripts/ai-dlc/$1" stories/story-cons.md \
      --require-skill ai-dlc-adversary-review 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && grep -qF "PASS (stories/story-cons.md, 2 block(s)" <<<"$out" && return 0
  echo "        NR reader rc=$rc: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)" >&2; return 1; }
# -> "<CI><CR><NI><NR>" for a writer $1 and a reader $2 (basenames beside the pair), $3 the extra file
cons_vector() { local v="" r
  arm_ci "$1" "$3"; r=$?; v="$v$r"
  arm_cr "$2" "$3"; r=$?; v="$v$r"
  arm_ni "$1" "$3"; r=$?; v="$v$r"
  arm_nr "$2" "$3"; r=$?; v="$v$r"
  printf '%s\n' "$v"
}

ASSERTIONS=$((ASSERTIONS + 1))
if [ ! -f "$READER" ] || [ ! -f "$SCHEMA_SRC" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-46s\n' "FIXTURE BROKEN: no reader beside the writer, or no source schema"
  BASEV="broken"
else
  BASEV="$(cons_vector stamp-story-provenance.sh validate-provenance-block.sh "")"
  pw="$(cons_world near "")"
  if [ -z "$pw" ] || cmp -s "$SCHEMA_SRC" "$pw/t/.claude/schemas/$SCH" \
     || cmp -s "$SCHEMA_SRC" "$pw/f/.claude/schemas/$SCH" \
     || cmp -s "$pw/t/.claude/schemas/$SCH" "$pw/f/.claude/schemas/$SCH"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-46s\n' "FIXTURE BROKEN: sandbox schemas do not differ in bytes"
  else
    printf '  ok    %-46s\n' "install schema: sandbox schemas differ in bytes"
  fi
fi
i=0
for lbl in "consumer: writer resolves the install schema (CI)" \
           "consumer: reader passes the writer's stamp (CR)" \
           "near-miss: writer resolves foreign schema (NI)" \
           "near-miss: reader resolves foreign schema (NR)"; do
  i=$((i + 1)); ASSERTIONS=$((ASSERTIONS + 1))
  c="$(printf '%s' "$BASEV" | cut -c"$i")"
  if [ "$c" = 0 ]; then printf '  ok    %-46s\n' "$lbl"
  else FAILURES=$((FAILURES + 1)); printf '  FAIL  %-46s result=%s\n' "$lbl" "${c:-none}"; fi
done

# --- MUTANTS OF THE INSTALL CANDIDATE. Each is built from the script the fixture RESOLVED, anchored
# on the install-root walk the candidate is built from (exactly once), and refused unless it
# APPLIED (cmp differs). A mutant is killed only when its WHOLE vector matches: its own arm fails
# and every other arm still holds, so no kill is borrowed from an entangled arm.
MUTI="$(mktemp -d "$CONS/mut.XXXXXX")"
INSTALL_LOC='
import re, sys
src = open(sys.argv[1]).read()
def one(pat, what):
    m = re.findall(pat, src, re.M)
    if len(m) != 1:
        sys.exit("anchor: %s found %d times" % (what, len(m)))
    return m[0]
root = one(r"^(\w+)=\x22\$\(ai_dlc_resolve_root \x22\$\w+_SCRIPT_DIR\x22 \|\| true\)\x22$", "install-root walk")
sch = one(r"^\[ -n \x22\$" + root + r"\x22 \] && (\w+)=\x22\$" + root + r"/\.claude/schemas/provenance-block\.json\x22$", "guarded install schema")
Q = chr(34)
last = "    " + Q + "$" + sch + Q + "; do\n"
tail = " \\\n" + last
if src.count(tail) != 1:
    sys.exit("anchor: install candidate is not the last candidate exactly once")
def dropped():
    return src.replace(tail, "; do\n")
'
# IA/IC — the install candidate removed (writer / reader). With it goes all the fix does.
DROP_PROG="$INSTALL_LOC"'
open(sys.argv[2], "w").write(dropped())
'
# IB/IB2 — the install candidate moved FIRST in its own loop (writer / reader).
FIRST_PROG="$INSTALL_LOC"'
out = dropped()
i = src.index(tail)
j = out.rfind("for cand in \\\n", 0, i)
if j < 0:
    sys.exit("anchor: no loop head before the install candidate")
j += len("for cand in \\\n")
open(sys.argv[2], "w").write(out[:j] + "    " + Q + "$" + sch + Q + " \\\n" + out[j:])
'
# ID/ID2 — the empty-walk guard removed: the install schema is built even from an empty root.
UNGUARD_PROG="$INSTALL_LOC"'
g = "[ -n " + Q + "$" + root + Q + " ] && " + sch + "="
if src.count(g) != 1:
    sys.exit("anchor: empty-walk guard not found exactly once")
open(sys.argv[2], "w").write(src.replace(g, sch + "="))
'
mk_imut() { # $1 source  $2 mutant basename  $3 program -> mutant path, or DID NOT APPLY
  local out="$MUTI/$2"
  if ! python3 -c "$3" "$1" "$out" 2>"$MUTI/$2.err"; then
    echo "DID NOT APPLY: $(head -1 "$MUTI/$2.err")"; return 1
  fi
  if cmp -s "$1" "$out"; then echo "DID NOT APPLY: identical to $(basename "$1")"; return 1; fi
  printf '%s\n' "$out"
}
# Anchor control: the locator refuses a file carrying no install candidate at all.
ASSERTIONS=$((ASSERTIONS + 1))
printf '#!/usr/bin/env bash\necho no candidate here\n' > "$MUTI/decoy.sh"
if python3 -c "$DROP_PROG" "$MUTI/decoy.sh" "$MUTI/decoy.out" 2>/dev/null; then
  FAILURES=$((FAILURES + 1)); printf '  FAIL  %-46s\n' "FIXTURE BROKEN: install anchor matched a decoy"
else
  printf '  ok    %-46s\n' "install mutants: anchor refuses a decoy"
fi
# $1 label  $2 mutant path-or-DID-NOT-APPLY  $3 "writer"|"reader"  $4 expected vector
score_imut() {
  local label="$1" mp="$2" role="$3" want="$4" got
  ASSERTIONS=$((ASSERTIONS + 1))
  case "$mp" in "DID NOT APPLY"*)
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-46s %s\n' "$label" "$mp"; return ;;
  esac
  if [ "$BASEV" != 0000 ]; then
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-46s %s\n' "$label" "FIXTURE BROKEN: unmutated vector is $BASEV"; return
  fi
  if [ "$role" = writer ]; then
    got="$(cons_vector "$(basename "$mp")" validate-provenance-block.sh "$mp" 2>/dev/null)"
  else
    got="$(cons_vector stamp-story-provenance.sh "$(basename "$mp")" "$mp" 2>/dev/null)"
  fi
  if [ "$got" = "$want" ]; then printf '  ok    %-46s\n' "$label"
  else FAILURES=$((FAILURES + 1)); printf '  FAIL  %-46s %s\n' "$label" "vector $got, want $want (CI CR NI NR)"; fi
}
score_imut "mutant IA (writer: install cand removed) by CI" \
  "$(mk_imut "$WRITER" ma-writer.sh "$DROP_PROG")" writer 1000
score_imut "mutant IB (writer: install cand first) by NI" \
  "$(mk_imut "$WRITER" mb-writer.sh "$FIRST_PROG")" writer 0010
score_imut "mutant IC (reader: install cand removed) by CR" \
  "$(mk_imut "$READER" mc-reader.sh "$DROP_PROG")" reader 0100
score_imut "mutant IB2 (reader: install cand first) by NR" \
  "$(mk_imut "$READER" mb2-reader.sh "$FIRST_PROG")" reader 0001

# ID — THE EMPTY-WALK GUARD. Without it an install walk that finds no marker makes the candidate
# /.claude/schemas/provenance-block.json, at the filesystem root. No sandbox can plant a file
# there, so no exit code or resolved path can separate the mutant from the guard: both fail to
# find a schema, identically. The one observable is the path the program TESTS, so arm G reads
# the script's own execution trace: the unguarded copy stats the filesystem-root path and the
# guarded one never does. It runs from a directory with no root marker above it — asserted first,
# by the writer's own refusal to resolve a root there — because anywhere else the walk succeeds
# and the guard has no subject.
ASSERTIONS=$((ASSERTIONS + 1))
NM=""
for base in "$ROOT" /tmp; do
  cand_nm="$(mktemp -d "$base/nomark.XXXXXX" 2>/dev/null)" || continue
  [ "$base" = "$ROOT" ] || NM_EXTRA="$cand_nm"
  mkdir -p "$cand_nm/scripts/ai-dlc" "$cand_nm/f/.claude"
  cp "$WRITER" "$cand_nm/scripts/ai-dlc/stamp-story-provenance.sh"
  cp "$READER" "$cand_nm/scripts/ai-dlc/validate-provenance-block.sh"
  pre="$(cd "$cand_nm" && env -u AI_DLC_PROJECT_ROOT -u CLAUDE_PROJECT_DIR \
      bash "$cand_nm/scripts/ai-dlc/stamp-story-provenance.sh" --print-schema 2>&1)"; prc=$?
  if [ "$prc" -eq 2 ] && grep -qF "cannot resolve the project root" <<<"$pre"; then NM="$cand_nm"; break; fi
done
if [ -z "$NM" ]; then
  FAILURES=$((FAILURES + 1)); printf '  FAIL  %-46s\n' "FIXTURE BROKEN: no marker-free directory for arm G"
else
  printf '  ok    %-46s\n' "arm G: sandbox has no root marker above it"
fi
ROOTSTAT=" -f /.claude/schemas/$SCH"
trace_of() { # $1 script basename in $NM/scripts/ai-dlc  then its args -> the xtrace
  local s="$1"; shift
  ( cd "$NM" && AI_DLC_PROJECT_ROOT="$NM/f" PS4='+ ' bash -x "$NM/scripts/ai-dlc/$s" "$@" 2>&1 )
}
# $1 label  $2 guarded script  $3 mutant path-or-DID-NOT-APPLY  then script args
score_guard() {
  local label="$1" real="$2" mp="$3" ctl mut; shift 3
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ -z "$NM" ]; then FAILURES=$((FAILURES + 1)); printf '  FAIL  %-46s %s\n' "$label" "FIXTURE BROKEN: no sandbox"; return; fi
  case "$mp" in "DID NOT APPLY"*)
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-46s %s\n' "$label" "$mp"; return ;;
  esac
  cp "$mp" "$NM/scripts/ai-dlc/$(basename "$mp")"
  ctl="$(trace_of "$real" "$@")"; mut="$(trace_of "$(basename "$mp")" "$@")"
  if ! grep -qF " -f $NM/f/.claude/schemas/$SCH" <<<"$ctl" || ! grep -qF "$SCH not found" <<<"$ctl"; then
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-46s %s\n' "$label" "FIXTURE BROKEN: control trace lacks the override candidate"
  elif grep -qF -- "$ROOTSTAT" <<<"$ctl"; then
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-46s %s\n' "$label" "guarded script stats /.claude/schemas/ at the filesystem root"
  elif ! grep -qF -- "$ROOTSTAT" <<<"$mut"; then
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-46s %s\n' "$label" "SURVIVED: unguarded copy never stats the filesystem root"
  else
    printf '  ok    %-46s\n' "$label"
  fi
}
[ -z "$NM" ] || printf '# probe\n' > "$NM/probe.md"
score_guard "mutant ID (writer: walk guard removed) by G" stamp-story-provenance.sh \
  "$(mk_imut "$WRITER" md-writer.sh "$UNGUARD_PROG")" --print-schema
score_guard "mutant ID2 (reader: walk guard removed) by G" validate-provenance-block.sh \
  "$(mk_imut "$READER" md2-reader.sh "$UNGUARD_PROG")" "$NM/probe.md" --allow-missing

echo "  ---- $ASSERTIONS assertions, $FAILURES failing ----"
[ "$FAILURES" -eq 0 ]
