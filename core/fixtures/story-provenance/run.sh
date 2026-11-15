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
#
# The arms run the unmodified writer and reader in six families: the convergence and one-shot
# stamps, the mixed sprint (bind and project-root base), F13 (the alias is read-only), the
# install's schema (consumer layout), the BL-302 distribution layout, and BL-729 (--series
# prefix spellings).
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
echo "HERMETIC-CONSUMED $(cd "$(dirname "$WRITER")" && pwd)/$(basename "$WRITER")"

ROOT="$(bash "$DIR/seed.sh" | tail -1)"
NM_EXTRA=""
trap 'rm -rf "$ROOT" ${NM_EXTRA:+"$NM_EXTRA"}' EXIT

REAL_TID="toolu_FIXTUREaaaaaaaa"
# shellcheck source=/dev/null
. "$DIR/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }

# $1 label  $2 want-exit  $3 want-substring (or "")  then command...
expect() {
  local label="$1" want="$2" needle="$3"; shift 3
  local out got _m
  out="$("$@" 2>&1)"; got=$?
  local ok=1
  [ "$got" -eq "$want" ] || ok=0
  if [ -n "$needle" ] && ! grep -qF "$needle" <<<"$out"; then ok=0; fi
  if [ "$ok" -eq 1 ]; then
    printf -v _m '%-46s exit=%s' "$label" "$got"; ok "$_m"
  else
    printf -v _m '%-46s exit=%s want=%s needle=%q' "$label" "$got" "$want" "$needle"; bad "$_m"
    printf '        out: %s\n' "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)"
  fi
  [ "$ok" -eq 1 ]
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

# 5. TAMPER: a field in a stamped block -> --check MUST fail. Proves the check is not vacuous.
sed -i.bak 's/^findings_minor: 2/findings_minor: 9/' "$C/stories/story-1.md"
expect "converged: tampered block = DRIFT" 1 "DRIFT" \
  bash "$WRITER" --series "$C/s1-stories-adversarial" --check "$C/stories/story-1.md"
mv "$C/stories/story-1.md.bak" "$C/stories/story-1.md"

# 6. TAMPER: the story BODY after stamping -> artifact_sha goes stale -> --check MUST fail.
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

# 10. A garbage override is refused, not accepted.
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
if grep -q '^skill: bmad-review$' "$O/stories/story-bug-1.md" \
   && grep -q '^lens: adversarial$' "$O/stories/story-bug-1.md" \
   && ! grep -q '^verdict:' "$O/stories/story-bug-1.md"; then
  ok "oneshot: block cites the bmad skill, no verdict"
else
  bad "oneshot: block cites the bmad skill, no verdict"
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

# ASK THE WRITER where its schema is; never walk up from it. The install mapping SPLITS the
# two — core/scripts/<x> lands at <root>/scripts/ai-dlc/<x> while core/schemas/ lands at
# <root>/.claude/schemas/ — so "../schemas" and "../../schemas" are both right in the
# distribution and both wrong on every consumer. This fixture already resolves the WRITER
# through a chain that names the consumer path; the schema lookup was a private second copy of
# a derivation the writer owns, and it made the fixture red on every consumer while staying
# green here. Step 2 requires the derived fixtures green BEFORE the push, so that red was a
# permanent stop on the self-update, not a nuisance.
SCHEMA_SRC="$(bash "$WRITER" --print-schema 2>/dev/null)"
if [ ! -f "$SCHEMA_SRC" ]; then
  bad "FIXTURE BROKEN: writer --print-schema resolved nothing (got: ${SCHEMA_SRC:-<empty>})"
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
  bad "FIXTURE BROKEN: seed.sh --mixed-into built no world"
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
  #     reported against some OTHER file cannot satisfy it. The allow case is the arm above.
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
  bad "FIXTURE BROKEN: seed.sh --mixed-into built no world (R)"
else
  expect "mixed: bind resolves artifact via project root" 0 "stamped 1 of 1" \
    env AI_DLC_PROJECT_ROOT="$RW" bash -c 'cd "$1/s1" && bash "$2" --terminal "$3" --profile "$4" "$5"' _ \
      "$RW" "$WRITER" "${ONESHOT#s1/}" "$BUGP" "${S1B#s1/}"
fi

# --- F13: THE ALIAS IS READ-ONLY. A one-shot citing the pre-rename name is stamped onto its story
# under the CURRENT name with the lens the old name implied, and the old name is never written. These
# cells read the BYTES the writer put in the story file, never --check's verdict: --check accepts a
# verbatim pre-rename stamp by design (the historical-read arm below), so it cannot see a writer that
# re-emits the old name. Each cell stamps a FRESH story from a fresh copy of a seeded one-shot whose
# artifact: names that story, so the bind is satisfied and only the written block is under test.
#   N0  a current-name one-shot -> the story carries `skill: bmad-review` and `lens: adversarial`
#   N1  an old-name one-shot    -> the story carries `skill: bmad-review` and 0 bytes of the old name
#   N2  an old-name one-shot    -> the story carries `lens: adversarial`
# f13_stamp <cell dir> <one-shot template> <writer> <project root> -> MX_OUT = story bytes + WRITER-RC
f13_stamp() {
  local d="$1" rc
  mkdir -p "$d" || return 2
  cp "$O/stories/story-bug-old.md" "$d/story.md" || return 2
  sed "s#^artifact:.*#artifact: $d/story.md#" "$2" > "$d/oneshot.md" || return 2
  # An empty root would leave the writer walking up for a marker the sandbox does not carry. The cell
  # dir holds no schemas/, so the writer falls to its script-relative copy: the shipped schema.
  AI_DLC_PROJECT_ROOT="${4:-$d}" bash "$3" --terminal "$d/oneshot.md" --profile "$BUGP" "$d/story.md" > "$d/out" 2>&1; rc=$?
  MX_OUT="$(cat "$d/story.md"; printf 'WRITER-RC=%s\n' "$rc"; [ "$rc" -eq 0 ] || sed 's/^/WRITER-OUT: /' "$d/out" | head -3)"
  [ "$rc" -eq 0 ] || return 1
  return 0
}
F13_NEW="$O/s1-bug-fix-oneshot.md"; F13_OLD="$O/s1-bug-fix-oneshot-oldname.md"
# f13_pred <cell> -> 0 when the bytes in MX_OUT hold the cell's property
f13_pred() {
  local nold
  nold="$(grep -c 'bmad-review-adversarial-general' <<<"$MX_OUT")" || nold=0
  case "$1" in
    N0) grep -qx 'skill: bmad-review' <<<"$MX_OUT" && grep -qx 'lens: adversarial' <<<"$MX_OUT" ;;
    N1) grep -qx 'skill: bmad-review' <<<"$MX_OUT" && [ "$nold" -eq 0 ] ;;
    N2) grep -qx 'lens: adversarial' <<<"$MX_OUT" ;;
    *) return 2 ;;
  esac
}
# Every cell must hold and the stamp must succeed.
f13ok=1; f13why=""
for c in N0 N1 N2; do
  tpl="$F13_OLD"; [ "$c" = N0 ] && tpl="$F13_NEW"
  if f13_stamp "$(mktemp -d "$ROOT/f13base.XXXXXX")" "$tpl" "$WRITER" "" && f13_pred "$c"; then
    ok "F13-$c: stamped bytes hold (current name, lens, no old name)"
  else
    f13ok=0; f13why="$f13why $c"; bad "F13-$c: the written story block $(printf '%s' "$MX_OUT" | grep -E '^(skill|lens):|WRITER-RC|WRITER-OUT' | tr '\n' ' ' | cut -c1-400)"
  fi
done
# Seed control: the old-name template really carries the old name, so N1's zero is about the WRITER.
if [ "$f13ok" = 1 ] && grep -qx 'skill: bmad-review-adversarial-general' "$F13_OLD" && ! grep -q '^lens:' "$F13_OLD"; then
  ok "F13: an old-name one-shot (no lens line) is stamped as skill: bmad-review + lens: adversarial"
else
  bad "F13: base cells failed ($f13why) or the old-name seed does not carry the old name without a lens"
fi
# HISTORICAL READ. A story stamped BEFORE the rename carries the old name verbatim and no lens line.
# That stamp is the shipped writer's stamp with its block rewritten to the pre-rename form: the skill
# line put back to the old name and the lens line dropped. The shipped writer's --check and the
# reader's pin both accept it.
READER="$(dirname "$WRITER")/validate-provenance-block.sh"
HD="$(mktemp -d "$ROOT/f13hist.XXXXXX")"
if f13_stamp "$HD" "$F13_OLD" "$WRITER" "" \
   && sed 's/^skill: bmad-review$/skill: bmad-review-adversarial-general/' "$HD/story.md" | grep -v '^lens: adversarial$' > "$HD/story.hist" \
   && mv "$HD/story.hist" "$HD/story.md" \
   && grep -qx 'skill: bmad-review-adversarial-general' "$HD/story.md" \
   && ! grep -q '^lens:' "$HD/story.md" \
   && bash "$WRITER" --terminal "$HD/oneshot.md" --profile "$BUGP" --check "$HD/story.md" > "$HD/chk" 2>&1 \
   && grep -qF 'OK (1 story file(s) current)' "$HD/chk" \
   && bash "$READER" "$HD/story.md" --require-skill bmad-review > "$HD/rd" 2>&1; then
  ok "F13 historical read: a pre-rename stamp (old name, no lens) passes --check and --require-skill bmad-review"
else
  bad "F13 historical read: a pre-rename stamp was refused on read ($(tail -1 "$HD/chk" 2>/dev/null) / $(tail -1 "$HD/rd" 2>/dev/null))"
fi

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
echo "HERMETIC-CONSUMED $(cd "$(dirname "$READER")" && pwd)/$(basename "$READER")"
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
# The stamp is always the REAL writer beside the pair.
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

if [ ! -f "$READER" ] || [ ! -f "$SCHEMA_SRC" ]; then
  bad "FIXTURE BROKEN: no reader beside the writer, or no source schema"
  BASEV="broken"
else
  BASEV="$(cons_vector stamp-story-provenance.sh validate-provenance-block.sh "")"
  pw="$(cons_world near "")"
  if [ -z "$pw" ] || cmp -s "$SCHEMA_SRC" "$pw/t/.claude/schemas/$SCH" \
     || cmp -s "$SCHEMA_SRC" "$pw/f/.claude/schemas/$SCH" \
     || cmp -s "$pw/t/.claude/schemas/$SCH" "$pw/f/.claude/schemas/$SCH"; then
    bad "FIXTURE BROKEN: sandbox schemas do not differ in bytes"
  else
    ok "install schema: sandbox schemas differ in bytes"
  fi
fi
i=0
for lbl in "consumer: writer resolves the install schema (CI)" \
           "consumer: reader passes the writer's stamp (CR)" \
           "near-miss: writer resolves foreign schema (NI)" \
           "near-miss: reader resolves foreign schema (NR)"; do
  i=$((i + 1))
  c="$(printf '%s' "$BASEV" | cut -c"$i")"
  if [ "$c" = 0 ]; then
    ok "$lbl"
  else printf -v _m '%-46s result=%s' "$lbl" "${c:-none}"; bad "$_m"; fi
done

# --- THE EMPTY-WALK GUARD. Without it an install walk that finds no marker makes the candidate
# /.claude/schemas/provenance-block.json, at the filesystem root. No sandbox can plant a file
# there, so no exit code or resolved path can separate the guard from its absence: both fail to
# find a schema, identically. The one observable is the path the program TESTS, so arm G reads
# the script's own execution trace: the guarded script never stats the filesystem-root path.
# It runs from a directory with no root marker above it — asserted first,
# by the writer's own refusal to resolve a root there — because anywhere else the walk succeeds
# and the guard has no subject.
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
  bad "FIXTURE BROKEN: no marker-free directory for arm G"
else
  ok "arm G: sandbox has no root marker above it"
fi
ROOTSTAT=" -f /.claude/schemas/$SCH"
trace_of() { # $1 script basename in $NM/scripts/ai-dlc  then its args -> the xtrace
  local s="$1"; shift
  ( cd "$NM" && AI_DLC_PROJECT_ROOT="$NM/f" PS4='+ ' bash -x "$NM/scripts/ai-dlc/$s" "$@" 2>&1 )
}
[ -z "$NM" ] || printf '# probe\n' > "$NM/probe.md"
# The two guarded scripts: the trace names the override candidate and never stats the filesystem root.
g_ctl() { # <label> <script> args...
  local lbl="$1" sc="$2" tr; shift 2
  if [ -z "$NM" ]; then bad "FIXTURE BROKEN: no sandbox ($lbl)"; return 1; fi
  tr="$(trace_of "$sc" "$@")"
  if ! grep -qF " -f $NM/f/.claude/schemas/$SCH" <<<"$tr" || ! grep -qF "$SCH not found" <<<"$tr"; then
    bad "$lbl: FIXTURE BROKEN: control trace lacks the override candidate"; return 1
  elif grep -qF -- "$ROOTSTAT" <<<"$tr"; then
    bad "$lbl: the guarded script stats /.claude/schemas/ at the filesystem root"; return 1
  else ok "$lbl"; return 0; fi
}
g_ctl "arm G: the guarded writer never stats the filesystem-root schema" stamp-story-provenance.sh --print-schema
g_ctl "arm G: the guarded reader never stats the filesystem-root schema" validate-provenance-block.sh "$NM/probe.md" --allow-missing

# --- BL-302: THE WRITER AND THE READER LOAD ONE SCHEMA IN THE DISTRIBUTION LAYOUT TOO. The arms
# above run in the consumer layout, where the script-relative candidate (`scripts/schemas/`) never
# exists, so the writer's candidate ORDER cannot show there. In the distribution it always exists:
# a writer that tried `$SCRIPT_DIR/../schemas/` first loaded core/schemas/ while the reader, which
# tries the override root first, loaded the root's own copy — and refused what the writer stamped.
# So this world is built in the distribution's shape wherever the fixture runs:
#   <d>/core/scripts/{writer,reader}   <d>/core/schemas/provenance-block.json (the source schema)
#   <g>/.claude/schemas/provenance-block.json — MODIFIED: the placeholder prefix is no longer
#       forbidden on tool_use_id, so a pass carrying `toolu_placeholder…` stamps under <g>'s schema
#       and is refused under the source one. The modification is what separates the two schemas.
#   DP  the writer's --print-schema under AI_DLC_PROJECT_ROOT=<g> IS <g>'s copy (identity)
#   DS  the writer stamps that pass under <g>, and the reader under <g> accepts the stamp
#   DC  CONTROL: with no override the same writer REFUSES the pass as a placeholder, so DS passes
#       because of <g>'s schema and for no other reason
B302="$(mktemp -d "$ROOT/b302.XXXXXX")"
B302_TID="toolu_placeholderBL302zzzz"
b302_world() { # $1 writer to install -> world dir
  local w; w="$(mktemp -d "$B302/w.XXXXXX")" || return 1
  mkdir -p "$w/d/core/scripts" "$w/d/core/schemas" "$w/d/core/skills/ai-dlc" "$w/g/.claude/schemas" "$w/g/stories" || return 1
  cp "$1" "$w/d/core/scripts/stamp-story-provenance.sh" || return 1
  cp "$READER" "$w/d/core/scripts/validate-provenance-block.sh" || return 1
  cp "$SCHEMA_SRC" "$w/d/core/schemas/$SCH" || return 1
  python3 -c '
import json, sys
s = json.load(open(sys.argv[1]))
f = [x for x in s["fields"] if x.get("name") == "tool_use_id" and x.get("forbidden_match") == "prefix_ci"]
assert len(f) == 1, "tool_use_id carries no prefix_ci forbidden list"
before = len(f[0]["forbidden"])
f[0]["forbidden"] = [v for v in f[0]["forbidden"] if not v.lower().startswith("toolu_placeholder")]
assert len(f[0]["forbidden"]) < before, "no placeholder prefix to lift"
json.dump(s, open(sys.argv[2], "w"), indent=2)
' "$SCHEMA_SRC" "$w/g/.claude/schemas/$SCH" || return 1
  sed "s/^tool_use_id:.*/tool_use_id: $B302_TID/" "$ROOT/converged/s1-stories-adversarial-p2.md" > "$w/g/pass-p2.md" || return 1
  printf '# Story b302\n\n## Acceptance Criteria\n- AC(a): thing.\n' > "$w/g/stories/story-b302.md"
  printf '%s\n' "$w"
}
# -> "<DP><DS><DC>" for writer $1, each 0 held / 1 failed / 2 broken
b302_vector() { local w out st rd rc v=""
  w="$(b302_world "$1")" || { echo 222; return; }
  out="$(cd "$w/g" && AI_DLC_PROJECT_ROOT="$w/g" bash "$w/d/core/scripts/stamp-story-provenance.sh" --print-schema 2>&1)"
  if [ -n "$out" ] && [ "$out" -ef "$w/g/.claude/schemas/$SCH" ]; then v="${v}0"; else v="${v}1"; fi
  st="$(cd "$w/g" && AI_DLC_PROJECT_ROOT="$w/g" bash "$w/d/core/scripts/stamp-story-provenance.sh" \
        --terminal pass-p2.md stories/story-b302.md 2>&1)"
  rd="$(cd "$w/g" && AI_DLC_PROJECT_ROOT="$w/g" bash "$w/d/core/scripts/validate-provenance-block.sh" \
        stories/story-b302.md --require-skill ai-dlc-adversary-review 2>&1)"; rc=$?
  if grep -qF "stamped 1 of 1" <<<"$st" && grep -qF "$B302_TID" "$w/g/stories/story-b302.md" \
     && [ "$rc" -eq 0 ] && grep -qF "PASS (stories/story-b302.md, 1 block(s)" <<<"$rd"; then v="${v}0"; else v="${v}1"; fi
  # The control drives a FRESH copy of the pass and story, with the override unset: the walk from
  # the world's cwd finds <d> through nothing, so the root comes from the writer's own install.
  cp "$w/g/pass-p2.md" "$w/d/pass-p2.md"; printf '# Story c\n' > "$w/d/story-c.md"
  st="$(cd "$w/d" && env -u AI_DLC_PROJECT_ROOT -u CLAUDE_PROJECT_DIR bash "$w/d/core/scripts/stamp-story-provenance.sh" \
        --terminal pass-p2.md story-c.md 2>&1)"
  if grep -qF "placeholder literal the schema forbids" <<<"$st" && ! grep -qF "$B302_TID" "$w/d/story-c.md"; then v="${v}0"; else v="${v}1"; fi
  printf '%s\n' "$v"
}
B302V="$(b302_vector "$WRITER")"
i=0
for lbl in "BL-302 dist: writer resolves the root's schema (DP)" \
           "BL-302 dist: reader accepts the writer's stamp (DS)" \
           "BL-302 dist: control refuses without it (DC)"; do
  i=$((i + 1))
  c="$(printf '%s' "$B302V" | cut -c"$i")"
  if [ "$c" = 0 ]; then ok "$lbl"
  else printf -v _m '%-46s result=%s' "$lbl" "${c:-none}"; bad "$_m"; fi
done

# --- BL-729: --series resolves every spelling of the prefix to the highest REAL pass.
# Check 24 takes `<stem>-adversarial-p` and excludes repair/resolution files by name; the writer
# resolves the same way. The series holds p1-p3 plus a repair pass (p7) and a resolution pass (p9)
# that outrank p3 numerically, so only a resolver that excludes them reaches p3. p3 is proved by a
# real --check exit 0: the story is stamped from p3 by --terminal, and a writer that resolves any
# other pass derives a different block and exits 1.
B729="$(mktemp -d "$ROOT/b729.XXXXXX")"
eval "$(sed -n '/^mk_pass()/,/^}/p' "$DIR/seed.sh")"
for i in 1 2 3 4 5 6 7 8 9; do mk_pass "$B729/s-adversarial-p$i.md" EXIT_CONDITION_NOT_MET "$REAL_TID"; done
mk_pass "$B729/s-adversarial-p10.md" EXIT_CONDITION_MET "toolu_FIXTUREdddddddd"
mk_pass "$B729/s-adversarial-p2-repair-p7.md" EXIT_CONDITION_MET "toolu_FIXTUREbbbbbbbb"
mk_pass "$B729/s-adversarial-resolution-p11.md" EXIT_CONDITION_MET "toolu_FIXTUREcccccccc"
printf '# Story b729\n' > "$B729/story.md"
( cd "$B729" && AI_DLC_PROJECT_ROOT="$B729" bash "$WRITER" --terminal s-adversarial-p10.md story.md >/dev/null 2>&1 )
# vector for writer $1: one digit per spelling (<stem>-adversarial, -adversarial-, -adversarial-p);
# 0 = --check exit 0 (p3 resolved), 1 = anything else
b729_vector() { local v="" pre
  for pre in s-adversarial s-adversarial- s-adversarial-p; do
    if ( cd "$B729" && AI_DLC_PROJECT_ROOT="$B729" bash "$1" --series "$pre" --check story.md >/dev/null 2>&1 ); then v="${v}0"; else v="${v}1"; fi
  done
  printf '%s\n' "$v"
}
B729_CTL="$(b729_vector "$WRITER")"
# Positive conjunct: the seeded story really carries p10 tool_use_id (every other pass carries another), and all three spellings pass.
# p10 sorts BETWEEN p1 and p2 in glob order and p9 sorts last of the real passes; the resolution decoy is p11, above p10, so a resolver that keeps the last
# file in glob order resolves p9 and fails; only a numeric compare reaches p10.
if [ "$B729_CTL" = 000 ] && grep -qF "tool_use_id: toolu_FIXTUREdddddddd" "$B729/story.md"; then
  ok "BL-729: three prefix spellings resolve p10 (--check 0)"
else
  printf -v _m '%-46s vector %s, want 000' "BL-729: three prefix spellings resolve p10" "$B729_CTL"; bad "$_m"
fi

echo
report_end story-provenance
