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
trap 'rm -rf "$ROOT"' EXIT

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

echo "  ---- $ASSERTIONS assertions, $FAILURES failing ----"
[ "$FAILURES" -eq 0 ]
