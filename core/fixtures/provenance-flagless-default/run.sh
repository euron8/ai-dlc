#!/usr/bin/env bash
# provenance-flagless-default — assert that validate-provenance-block.sh DENIES an artifact
# with no SKILL_INVOCATION_PROVENANCE block when no flag was passed, that `--allow-missing`
# is the only thing that acquits it, and that `--allow-missing` acquits EXACTLY that one rung.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH. Handed an ordinary artifact carrying no block and no flag,
# the reader printed `OK: no provenance block required or present` and exited 0. The flagless
# caller had already decided the artifact was IN SCOPE, so that answer put the burden of
# remembering a flag on every gate: a call site that forgot one got a pass over a file nothing
# had examined, and a pass over an unexamined file is indistinguishable from a pass over a
# clean one.
#
# WHY A SINGLE ARM CANNOT CARRY THIS. The obvious fix — deny when the block is absent — has
# three wrong neighbours, and each of them satisfies a fixture that only asserts the deny:
#
#   1. an `--allow-missing` that short-circuits EVERYTHING, so the retro rung, the MALFORMED
#      rung and every rule violation are acquitted along with the absent case;
#   2. a deny keyed on the `.md` extension, so `report.txt` keeps its old exit 0;
#   3. the deny reported with the MALFORMED wording, which sends the caller to re-wrap a
#      block that is not there.
#
# So the arms come in pairs. (a)/(g) fix the extension-independence, (b) fixes the acquittal,
# (c)(d)(h) fix its SCOPE, and (a) reads the stderr in BOTH directions — it must name
# `--allow-missing` and must NOT carry the MALFORMED wording, with a same-run control on a
# genuinely malformed file proving that second grammar can fire at all.
#
# TWO MORE WRONG NEIGHBOURS ARE INVISIBLE TO THE SHAPE OF THE DRIVER RATHER THAN TO THE ARMS,
# and they are why (a2)(a3) and (a4)(a5) exist. The seeds live under `mktemp`, so every arm above
# names its artifact ABSOLUTELY — a deny keyed on `os.path.isabs` therefore holds every one of
# them at 1 while acquitting the consumer's only flagless call site, which passes a path relative
# to the consumer root. And the hermeticity scrub below unsets every AI_DLC_* name in this
# process, so a reader honouring an AI_DLC_-prefixed environment variable as a second spelling of
# `--allow-missing` is unobservable by construction, while a reader honouring an UNPREFIXED name
# is already caught by (a)/(g). Neither gap is closed by another assertion about the same
# invocation; both are closed by a different INVOCATION SHAPE, which is what (a2)–(a5) supply.
#
# (f-ctl) RUNS FIRST AND IS THE SEED CONTROL. Every arm below it is a statement about a
# validator that works; a seed the validator rejects for an unrelated reason would make the
# whole file read as agreement. The block it uses is the one check-17-bypass's seed emits,
# extended with tool_use_id and the three findings_* counts, so it is not derived from this
# fixture's own idea of the format.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# --- subject: WALK UP for a marker, never count `..` hops ---------------------
# The marker is this fixture's OWN home, which names the layout it is running in:
# `<root>/core/fixtures/<name>` in the distribution, `<root>/tests/fixtures/<name>` on a
# consumer. It is self-anchoring, it cannot stop early on an unrelated ancestor, and every
# candidate below is rooted at that answer rather than hung off a path some other resolver
# produced — which is what I33 fails the build on.
FNAME="$(basename "$HERE")"
LAYOUT=""
ROOT=""
_d="$(dirname "$HERE")"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  if [ "$_d/core/fixtures/$FNAME" = "$HERE" ]; then LAYOUT=dist;     ROOT="$_d"; break; fi
  if [ "$_d/tests/fixtures/$FNAME" = "$HERE" ]; then LAYOUT=consumer; ROOT="$_d"; break; fi
  _d="$(dirname "$_d")"
done

echo "provenance-flagless-default:"

if [ -z "$ROOT" ]; then
  echo "  FAIL  $HERE sits under neither core/fixtures/ nor tests/fixtures/ — the fixture cannot resolve its own tree, and guessing a root is how a fixture reports green over a tree it never read" >&2
  exit 2
fi

VALIDATOR=""
for cand in "$ROOT/core/scripts/validate-provenance-block.sh" \
            "$ROOT/scripts/ai-dlc/validate-provenance-block.sh" \
            "$ROOT/scripts/validate-provenance-block.sh"; do
  [ -f "$cand" ] && { VALIDATOR="$cand"; break; }
done
SCHEMA=""
for cand in "$ROOT/core/schemas/provenance-block.json" \
            "$ROOT/.claude/schemas/provenance-block.json"; do
  [ -f "$cand" ] && { SCHEMA="$cand"; break; }
done

# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. Report every arm by NAME as SKIP rather than
# exiting 0 in silence — a silent exit 0 here reads exactly like a clean run.
if [ -z "$VALIDATOR" ] || [ -z "$SCHEMA" ]; then
  miss=""
  [ -z "$VALIDATOR" ] && miss="$miss validate-provenance-block.sh"
  [ -z "$SCHEMA" ]    && miss="$miss provenance-block.json"
  for a in "f-ctl schema-valid block, flagless, ACCEPTED" \
           "a  ordinary .md, no block, no flag, DENIED naming --allow-missing" \
           "a2 the same file named RELATIVELY from a cd'd cwd, no flag, DENIED" \
           "a3 the same file named ./-relatively from a cd'd cwd, no flag, DENIED" \
           "a4 flagless, no block, with AI_DLC_PROVENANCE_ALLOW_MISSING=1 in the env, DENIED" \
           "a5 flagless, no block, with PROVENANCE_ALLOW_MISSING=1 and ALLOW_MISSING=1, DENIED" \
           "b  the same file under --allow-missing, ACCEPTED" \
           "c  a retro with no block under --allow-missing, DENIED" \
           "d  a MALFORMED marker under --allow-missing, DENIED as malformed" \
           "e  --allow-missing with --require-skill is a usage error, both orders" \
           "f  a schema-valid block under --allow-missing, ACCEPTED" \
           "g  an artifact with no .md extension, no block, no flag, DENIED" \
           "h  a block that VIOLATES a rule under --allow-missing, DENIED" \
           "M0/M1/M2/M3/M4/M5 mutants"; do
    printf '  SKIP  %s — subject absent in both layouts:%s\n' "$a" "$miss"
  done
  exit 0
fi

command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 not on PATH" >&2; exit 2; }

# HERMETICITY. The hooks honour a set of AI_DLC_* tunables and a consumer that sets one in
# settings.json exports it into every session, so the fixture would be adjudicating the
# operator's configuration rather than the code.
#
# IT ALSO BLINDS THIS FIXTURE TO AN AI_DLC_-NAMED BACK DOOR INTO THE ACQUITTAL, which is the
# reason (a4) sets its variable in the INVOCATION rather than exporting one here. The scrub is
# correct and stays; the arm works around it, and `drive_env` below is how.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; fails=$((fails+1)); }

# ---------------------------------------------------------------------------
# SEEDS
# ---------------------------------------------------------------------------
ART="$WORK/art"
mkdir -p "$ART/docs/retro/s301"

printf '# Product Requirements\n\nNo provenance block anywhere in this document.\n' \
  > "$ART/docs/prd.md"
printf 'Adversarial pass, plain text.\n\nNo provenance block anywhere in this file.\n' \
  > "$ART/docs/report.txt"
printf '# Sprint 301 Retrospective\n\nParty mode was convened. No block was written.\n' \
  > "$ART/docs/retro/s301/retro.md"

# The sprint-290 shape: the marker is THERE and the parser cannot read it, because the
# author was taught a bare ``` fence with no terminator.
cat > "$ART/docs/fenced.md" <<'EOF'
# Adversarial Review, Pass 1

```
SKILL_INVOCATION_PROVENANCE v1
skill: ai-dlc-adversary-review
mode: subagent
verdict: EXIT_CONDITION_NOT_MET
```
EOF

# THE SEED CONTROL'S BLOCK IS LIFTED AT RUNTIME, NOT TYPED HERE.
#
# It comes from check-17-bypass/seed.sh's V2 variant — this repo's maintained corpus of what
# the real producer emits, already joined to schemas/provenance-block.json — extended with
# the `tool_use_id` that variant deliberately strips and the three `findings_*` counts. A
# TYPED copy of that block would be a second author encoding one understanding twice: it
# stays green through a change to the schema AND the reader, and a seed derived from the
# reader's own accept-set proves only that the reader accepts its own grammar. Lifted, a
# schema change that breaks V2 breaks this fixture too, which is the point.
#
# check-17-bypass ships, so the sibling is present in both layouts. Named in full from this
# fixture's own home — a sideways walk, not the forbidden walk up from one core file to
# another (I33).
C17=""
for cand in "$HERE/../check-17-bypass/seed.sh"; do
  [ -f "$cand" ] && { C17="$cand"; break; }
done
if [ -z "$C17" ]; then
  echo "FIXTURE BROKEN: check-17-bypass/seed.sh not found beside this fixture — the f-ctl seed has no source, and typing one here would seed from this reader's own accept-set" >&2
  exit 2
fi
C17OUT="$WORK/.c17"
mkdir -p "$C17OUT"
bash "$C17" "$C17OUT" >/dev/null 2>&1 || {
  echo "FIXTURE BROKEN: check-17-bypass/seed.sh failed; the f-ctl seed is unavailable" >&2; exit 2; }
V2="$C17OUT/docs/retro/s902/retro.md"
[ -f "$V2" ] || {
  echo "FIXTURE BROKEN: check-17-bypass's V2 variant is not at docs/retro/s902/retro.md — the lift has lost its source and must be re-anchored, not retyped here" >&2; exit 2; }

# EXTEND IT, and refuse loudly if the extension matched nothing. A no-op insert would hand
# f-ctl the tool_use_id-stripped variant, which fails for a reason this fixture is not about.
python3 - "$V2" "$ART/docs/valid.md" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()
close = "SKILL_INVOCATION_PROVENANCE_END -->"
add = ("tool_use_id: toolu_01ABCDEFGHIJKLMNOPQRSTUV\n"
       "findings_critical: 0\n"
       "findings_major: 0\n"
       "findings_minor: 1\n")
if "tool_use_id:" in s or s.count(close) != 1:
    sys.exit(3)
open(dst, "w", encoding="utf-8").write(s.replace(close, add + close, 1))
PY
case $? in
  0) ;;
  3) echo "FIXTURE BROKEN: check-17-bypass's V2 no longer has exactly one block terminator, or already carries a tool_use_id — the lift's assumption about that variant expired and the extension would be a no-op" >&2; exit 2 ;;
  *) echo "FIXTURE BROKEN: extending the lifted V2 block failed" >&2; exit 2 ;;
esac
if cmp -s "$V2" "$ART/docs/valid.md"; then
  echo "FIXTURE BROKEN: the extension of the lifted block changed nothing — f-ctl would be driving the tool_use_id-stripped variant, which fails for a reason this fixture is not about" >&2
  exit 2
fi

# The same block with the one field Rule 20 refuses. A present block that VIOLATES a rule is
# the third thing `--allow-missing` must not acquit.
sed 's/^mode: subagent/mode: solo/' "$ART/docs/valid.md" > "$ART/docs/solo.md"
if cmp -s "$ART/docs/valid.md" "$ART/docs/solo.md"; then
  echo "FIXTURE BROKEN: the mode: solo seed edit matched nothing — arm (h) would be driving the accepted block" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# DRIVER. The exit code is read DIRECTLY off the invocation, never after a pipe: under
# pipefail a reader that leaves early answers with the writer's EPIPE.
# ---------------------------------------------------------------------------
OUTF="$WORK/out.txt"
#
# Invoked through `bash` rather than by path. A shipped file that reaches a consumer without
# its executable bit answers rc 126, which is a permission denial and not a verdict — and
# 126 is not one of the codes any arm below expects, so it would read as a regression in the
# subject rather than as a packaging fault.
drive() {  # drive <validator> <args...> -> prints rc, leaves combined output in $OUTF
  local v="$1"; shift
  bash "$v" "$@" >"$OUTF" 2>&1
  printf '%s\n' "$?"
}

# EVERY OTHER ARM NAMES ITS ARTIFACT ABSOLUTELY, because the seeds live under `mktemp`. That is
# a property of the DRIVER, not of the subject, and it made an entire acquittal class invisible:
# a guard reading `if not os.path.isabs(artifact_path)` above the absent emitter passes every
# absolute arm here while acquitting the only flagless call site a consumer has — `ci-local.sh`'s
# retro-compliance check, which hands this reader `docs/retro/sprint-<N>.md` relative to the
# consumer's own root. The `cd` is subshelled and guarded: an unguarded one that fails leaves the
# body running against the CALLER's working directory, and `exit 9` keeps a failed `cd` from
# arriving at an arm as the rc=1 that arm expects.
drive_rel() {  # drive_rel <cwd> <validator> <relative-args...> -> prints rc, output in $OUTF
  local d
  local v
  d="$1"
  v="$2"
  shift 2
  ( cd "$d" || exit 9; bash "$v" "$@" ) >"$OUTF" 2>&1
  printf '%s\n' "$?"
}

# THE VARIABLE IS SET IN THE INVOCATION, AND THAT IS THE WHOLE POINT OF THIS HELPER.
# The hermeticity scrub above unsets every AI_DLC_* name in this process before any arm runs, so
# an `export` here would be undone for the driven child exactly as it is for every other arm —
# which is what makes an AI_DLC_-prefixed environment back door STRUCTURALLY invisible to this
# fixture: the scrub is a correct defence against adjudicating the operator's configuration, and
# it doubles as a blindfold over the one acquittal shaped like the configuration it removes. A
# non-prefixed twin is already caught by (a)/(g), which is the asymmetry that hides the prefixed
# one. `env VAR=… bash …` sets it for the child only, after the scrub, so the rest of the file
# keeps its hermeticity and this arm gets its subject.
drive_env() {  # drive_env <VAR=VAL> <validator> <args...> -> prints rc, output in $OUTF
  local e
  local v
  e="$1"
  v="$2"
  shift 2
  env "$e" bash "$v" "$@" >"$OUTF" 2>&1
  printf '%s\n' "$?"
}

# ---------------------------------------------------------------------------
# (f-ctl) THE SEED CONTROL, FIRST. A bad seed cannot be allowed to read as agreement.
# ---------------------------------------------------------------------------
rc="$(drive "$VALIDATOR" "$ART/docs/valid.md")"
if [ "$rc" = 0 ]; then
  ok "f-ctl a schema-valid block passes FLAGLESS (rc=0) — the seed is good and every arm below is about the rung, not the block"
else
  bad "f-ctl the schema-valid seed was REJECTED flagless (rc=$rc) — the seed is wrong, and every arm below would be measuring it rather than the subject"
  sed 's/^/        /' "$OUTF" >&2
  echo >&2
  echo "provenance-flagless-default: FIXTURE BROKEN (the seed control failed)" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# (a) the flagless default DENIES, and the DIAGNOSIS is the absent one, not the malformed one
# ---------------------------------------------------------------------------
rc_a="$(drive "$VALIDATOR" "$ART/docs/prd.md")"
a_out="$(cat "$OUTF")"
# BOTH DIRECTIONS, and the second one needs a control. "does not carry MALFORMED" is
# satisfied by a validator that emits nothing at all, so the same grammar is fired against a
# genuinely malformed file in the same run: if it does not match THERE, the absence here is a
# grammar that cannot spell its subject and says nothing.
rc_mal_ctl="$(drive "$VALIDATOR" "$ART/docs/fenced.md")"
mal_ctl_out="$(cat "$OUTF")"
if [ "$rc_a" != 1 ]; then
  bad "a  an ordinary .md with no block and no flag exited $rc_a, expected 1 — the flagless default is back to passing an artifact nothing examined"
  sed 's/^/        /' <<<"$a_out" >&2
elif ! grep -q -- '--allow-missing' <<<"$a_out"; then
  bad "a  the deny fired but its message never names --allow-missing, so the caller is told it failed and not what to do about it"
  sed 's/^/        /' <<<"$a_out" >&2
elif ! grep -qE 'MALFORMED|CANNOT PARSE' <<<"$mal_ctl_out"; then
  bad "a  CONTROL — the MALFORMED grammar did not match on a genuinely fenced block either, so the 'not malformed' half of this arm is a scan that cannot spell its own subject"
  sed 's/^/        /' <<<"$mal_ctl_out" >&2
elif grep -qE 'MALFORMED|CANNOT PARSE' <<<"$a_out"; then
  bad "a  the deny reports the ABSENT case with the MALFORMED wording — the caller is sent to re-wrap a block that is not there"
  sed 's/^/        /' <<<"$a_out" >&2
else
  ok "a  an ordinary .md with no block and no flag is DENIED (rc=1), naming --allow-missing and NOT as MALFORMED (control: that grammar matches on the fenced file in this same run)"
fi

# The ABSENT verdict, in one place, so (a2)–(a5) score the same three properties (a) does: the
# deny fired, it named the remedy, and it is not the MALFORMED verdict. The malformed half keeps
# the same control (a) established one arm above — the grammar matched on docs/fenced.md in this
# same run — so an empty message here cannot satisfy it by silence.
absent_verdict() {  # absent_verdict <rc> <output> -> 0 if the ABSENT deny, else prints why
  if [ "$1" != 1 ]; then printf 'exited %s, expected 1' "$1"; return 1; fi
  if ! grep -q -- '--allow-missing' <<<"$2"; then printf 'denied without naming --allow-missing'; return 1; fi
  if grep -qE 'MALFORMED|CANNOT PARSE' <<<"$2"; then printf 'reported the ABSENT case with the MALFORMED wording'; return 1; fi
  return 0
}

# ---------------------------------------------------------------------------
# (a2)(a3) THE SAME BLOCK-LESS SEED, NAMED RELATIVELY. Every other arm in this file hands the
# reader an absolute `$ART/...` path because the seeds live under `mktemp`, and that is a
# property of this fixture rather than of any caller: the consumer's ONLY flagless call site,
# `scripts/ci-local.sh`'s retro-compliance check, passes `docs/retro/sprint-<N>.md` relative to
# its own root. A guard reading `if not os.path.isabs(artifact_path): print("OK: ..."); exit(0)`
# above the absent emitter therefore acquits exactly the calls that reach this reader in
# production while every absolute arm here holds at 1. Two spellings, because a path grammar
# that special-cases `./` is a different program from one keyed on absoluteness, and one
# spelling alone cannot tell them apart. M4 below is that guard.
# ---------------------------------------------------------------------------
rc_a2="$(drive_rel "$ART" "$VALIDATOR" docs/prd.md)"
a2_out="$(cat "$OUTF")"
if why="$(absent_verdict "$rc_a2" "$a2_out")"; then
  ok "a2 the same block-less .md named RELATIVELY (docs/prd.md, from a cd'd cwd) is DENIED (rc=1) with the ABSENT verdict — the rung is keyed on the DECLARATION, not on how the caller spelled the path"
else
  bad "a2 the block-less .md named relatively as docs/prd.md $why — the deny is keyed on an ABSOLUTE path, and the consumer's only flagless call site (ci-local.sh's retro-compliance check) passes a relative one"
  sed 's/^/        /' <<<"$a2_out" >&2
fi

rc_a3="$(drive_rel "$ART" "$VALIDATOR" ./docs/prd.md)"
a3_out="$(cat "$OUTF")"
if why="$(absent_verdict "$rc_a3" "$a3_out")"; then
  ok "a3 the same file named ./docs/prd.md is DENIED (rc=1) with the ABSENT verdict — the two relative spellings agree, so the arm cannot be satisfied by a guard that only special-cases one of them"
else
  bad "a3 the block-less .md named relatively as ./docs/prd.md $why — a path grammar that handles one relative spelling and not the other is denying by accident"
  sed 's/^/        /' <<<"$a3_out" >&2
fi

# ---------------------------------------------------------------------------
# (a4)(a5) NO ENVIRONMENT VARIABLE IS A DECLARATION. `--allow-missing` is an argument because a
# declaration has to be made per call site by the caller that decided the artifact is in scope;
# an env var is made once, invisibly, by whoever exported it, and it reaches every artifact in
# the session.
#
# THE HERMETICITY SCRUB AT THE TOP OF THIS FILE IS WHY THESE ARMS EXIST AND WHY THEY ARE SPELLED
# THIS WAY. That loop unsets every AI_DLC_* name in the fixture's own process — correctly, so the
# fixture adjudicates the code and not the operator's settings.json — and in doing so it makes an
# AI_DLC_-PREFIXED back door structurally invisible: the variable is gone before any arm runs, so
# a reader honouring `AI_DLC_PROVENANCE_ALLOW_MISSING` scores identically to one that ignores it.
# A non-prefixed twin is not invisible at all — arms (a) and (g) would already catch a reader
# honouring a variable nobody set — and that asymmetry is exactly what hides the prefixed case.
# So the variable is set IN THE INVOCATION, `env VAR=1 bash "$VALIDATOR" …`, which runs after the
# scrub and touches only the child. (a5) drives the two unprefixed spellings for the same
# property under names the scrub never reached, so the arm covers the whole class rather than the
# one name a mutant happens to pick.
# ---------------------------------------------------------------------------
rc_a4="$(drive_env AI_DLC_PROVENANCE_ALLOW_MISSING=1 "$VALIDATOR" "$ART/docs/prd.md")"
a4_out="$(cat "$OUTF")"
if why="$(absent_verdict "$rc_a4" "$a4_out")"; then
  ok "a4 a block-less .md with AI_DLC_PROVENANCE_ALLOW_MISSING=1 in the invocation's environment is still DENIED (rc=1) with the ABSENT verdict — the acquittal is an ARGUMENT, and no exported name waives it"
else
  bad "a4 AI_DLC_PROVENANCE_ALLOW_MISSING=1 in the environment $why — the acquittal has an environment back door, and a consumer that exports the name in settings.json waives this rung for every artifact in every session"
  sed 's/^/        /' <<<"$a4_out" >&2
fi

for _e in PROVENANCE_ALLOW_MISSING=1 ALLOW_MISSING=1; do
  rc_a5="$(drive_env "$_e" "$VALIDATOR" "$ART/docs/prd.md")"
  a5_out="$(cat "$OUTF")"
  if why="$(absent_verdict "$rc_a5" "$a5_out")"; then
    ok "a5 a block-less .md with $_e in the invocation's environment is still DENIED (rc=1) with the ABSENT verdict"
  else
    bad "a5 $_e in the environment $why — the acquittal reads an environment name, and the caller that made no declaration gets a pass over a file nothing examined"
    sed 's/^/        /' <<<"$a5_out" >&2
  fi
done

# ---------------------------------------------------------------------------
# (b) --allow-missing is the declaration that acquits it
# ---------------------------------------------------------------------------
rc_b="$(drive "$VALIDATOR" "$ART/docs/prd.md" --allow-missing)"
if [ "$rc_b" = 0 ]; then
  ok "b  the same file under --allow-missing is ACCEPTED (rc=0) — the deny is keyed on the ABSENT DECLARATION, not on the file"
else
  bad "b  --allow-missing did not acquit the very case it exists for (rc=$rc_b) — the flag is unreachable, and every call site that has legitimately decided its artifact carries no block is now blocked"
  sed 's/^/        /' "$OUTF" >&2
fi

# ---------------------------------------------------------------------------
# (c)(d)(h) WHAT --allow-missing MUST NOT ACQUIT. Three separate rungs, three arms: an
# acquittal that short-circuits the whole reader passes any one of them read alone.
# ---------------------------------------------------------------------------
rc_c="$(drive "$VALIDATOR" "$ART/docs/retro/s301/retro.md" --allow-missing)"
if [ "$rc_c" = 1 ]; then
  ok "c  a RETRO with no block is still DENIED under --allow-missing (rc=1) — the flag does not reach the retro rung"
else
  bad "c  --allow-missing acquitted a blockless RETRO (rc=$rc_c) — the flag is a blanket pass, and Rule 20's party-mode floor is waivable by any caller that types it"
  sed 's/^/        /' "$OUTF" >&2
fi

rc_d="$(drive "$VALIDATOR" "$ART/docs/fenced.md" --allow-missing)"
d_out="$(cat "$OUTF")"
if [ "$rc_d" != 1 ]; then
  bad "d  --allow-missing acquitted a MALFORMED marker (rc=$rc_d) — the sprint-290 defect is back, reachable by any caller that waives absence"
  sed 's/^/        /' <<<"$d_out" >&2
elif ! grep -qE 'MALFORMED|CANNOT PARSE' <<<"$d_out"; then
  bad "d  a malformed marker under --allow-missing failed, but not AS malformed — the two verdicts have different fixes and this one is reporting the wrong one: $(head -n 1 <<<"$d_out")"
else
  ok "d  a MALFORMED marker under --allow-missing is still DENIED as MALFORMED (rc=1) — absent and unparseable stay two verdicts"
fi

rc_h="$(drive "$VALIDATOR" "$ART/docs/solo.md" --allow-missing)"
if [ "$rc_h" = 1 ]; then
  ok "h  a block PRESENT and violating a rule (mode: solo) is still DENIED under --allow-missing (rc=1) — the flag acquits an absence, never a violation"
else
  bad "h  --allow-missing acquitted a mode: solo block (rc=$rc_h) — v0.58.0's only teeth are waivable by a flag about absence"
  sed 's/^/        /' "$OUTF" >&2
fi

# ---------------------------------------------------------------------------
# (e) the two flags are contradictory declarations, in BOTH orders. One order alone cannot
#     tell a real contradiction check from an arg parser that happens to stop early.
# ---------------------------------------------------------------------------
rc_e1="$(drive "$VALIDATOR" "$ART/docs/prd.md" --allow-missing --require-skill bmad-prd)"
rc_e2="$(drive "$VALIDATOR" "$ART/docs/prd.md" --require-skill bmad-prd --allow-missing)"
if [ "$rc_e1" = 2 ] && [ "$rc_e2" = 2 ]; then
  ok "e  --allow-missing with --require-skill is a usage error (rc=2) in BOTH orders — the reader refuses to resolve the contradiction on the caller's behalf"
else
  bad "e  the contradictory flag pair did not read as a usage error in both orders (allow-first=$rc_e1 require-first=$rc_e2, expected 2 and 2) — one of the two declarations is being silently discarded"
  sed 's/^/        /' "$OUTF" >&2
fi

# ---------------------------------------------------------------------------
# (f) and (g)
# ---------------------------------------------------------------------------
rc_f="$(drive "$VALIDATOR" "$ART/docs/valid.md" --allow-missing)"
if [ "$rc_f" = 0 ]; then
  ok "f  a schema-valid block under --allow-missing is ACCEPTED (rc=0) — the flag does not turn a present block into a finding"
else
  bad "f  --allow-missing REJECTED an artifact whose block is well-formed (rc=$rc_f) — the flag changed the verdict on a file it has no business reaching"
  sed 's/^/        /' "$OUTF" >&2
fi

rc_g="$(drive "$VALIDATOR" "$ART/docs/report.txt")"
g_out="$(cat "$OUTF")"
if [ "$rc_g" != 1 ]; then
  bad "g  an artifact with no .md extension and no block exited $rc_g flagless, expected 1 — the deny is keyed on the EXTENSION, so every report.txt, every extensionless artifact and every .yml handed to this reader keeps the old silent pass"
  sed 's/^/        /' <<<"$g_out" >&2
elif ! grep -q -- '--allow-missing' <<<"$g_out"; then
  bad "g  the no-extension file was denied but the message never names --allow-missing, so the two file classes are being denied by two different rungs"
  sed 's/^/        /' <<<"$g_out" >&2
else
  ok "g  an artifact with NO .md extension and no block is DENIED flagless (rc=1), naming --allow-missing — the rung is keyed on the declaration, not on the filename"
fi

# ---------------------------------------------------------------------------
# MUTANTS. The arms above establish that the shipped validator behaves; they do NOT establish
# that any one of them would notice the behaviour going away, and an arm whose subject emits
# nothing passes an absence-shaped assertion silently.
#
# Each mutant is a COPY, in its own tree, with `cmp -s` proving the edit applied — a `sed` or
# a regex that matched nothing is a mutant that never existed, and `if mut ...` then skips its
# arms with no verdict at all. A mutation that does not apply is FIXTURE BROKEN, not a kill.
#
# THE COPY GETS A TREE, NOT A LONE FILE. validate-provenance-block.sh resolves its schema by
# walking up from its own location for a marker; a bare copy under mktemp finds none, fails
# closed on "schema not found", and is silent for a reason that has nothing to do with the
# mutation. M0 below drives the UNMUTATED copy through that tree and refuses before any
# mutant verdict is read.
# ---------------------------------------------------------------------------
mut_tree() {  # mut_tree <name> -> prints the path of the validator copy inside a fresh tree
  # SEPARATE assignments, deliberately. `local a="$1" b="$WORK/$a"` expands every word BEFORE
  # the builtin runs, so `b` reads the PREVIOUS `a` — under `set -u` that is an unbound
  # variable and the function returns EMPTY, which the driver then reports as rc 127.
  local name
  local dir
  name="$1"
  dir="$WORK/mut/$name"
  mkdir -p "$dir/scripts/ai-dlc" "$dir/.claude/schemas"
  cp "$SCHEMA" "$dir/.claude/schemas/provenance-block.json"
  cp "$VALIDATOR" "$dir/scripts/ai-dlc/validate-provenance-block.sh"
  chmod +x "$dir/scripts/ai-dlc/validate-provenance-block.sh"
  printf '%s\n' "$dir/scripts/ai-dlc/validate-provenance-block.sh"
}

# --- M0: the UNMUTATED copy, in the mutant tree, must reproduce the baseline -------------
# Two inert runs compare equal: a tree where the driven subject bails at its own startup
# check makes every mutant "survive" AND the control "pass". The conjunct is POSITIVE — the
# deny message must be THERE — because rc=1 with nothing printed is what a copy that never
# ran looks like.
M0="$(mut_tree m0)"
rc_m0a="$(drive "$M0" "$ART/docs/prd.md")"
m0_out="$(cat "$OUTF")"
rc_m0f="$(drive "$M0" "$ART/docs/valid.md")"
if [ "$rc_m0a" != 1 ] || ! grep -q -- '--allow-missing' <<<"$m0_out" || [ "$rc_m0f" != 0 ]; then
  echo "FIXTURE BROKEN: the UNMUTATED copy in the mutant tree does not reproduce the baseline" >&2
  echo "  (a) expected rc=1 with the --allow-missing remedy, got rc=$rc_m0a; (f-ctl) expected rc=0, got rc=$rc_m0f" >&2
  sed 's/^/        /' <<<"$m0_out" >&2
  echo "  Every mutant verdict below would be evidence about a subject that never ran." >&2
  exit 2
fi
ok "M0 control: the UNMUTATED copy in the mutant tree reproduces the baseline (a=1 with the remedy text, f-ctl=0) — the mutants below run a subject that loaded its schema"

killed_by=""
mutant_fails=0
mut_bad() { printf '  FAIL  %s\n' "$1" >&2; fails=$((fails+1)); mutant_fails=$((mutant_fails+1)); }

# --- M1: revert the flagless-absent rung to the old `sys.exit(0)` ------------------------
# Anchored on the rung's OWN emitted text, not on a line number and not on a hand-listed
# site: the property being removed is "the absent case is a FAIL", and the message is what
# that property emits.
M1="$(mut_tree m1)"
python3 - "$M1" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s2, n = re.subn(
    r'\n    print\(\n        f"FAIL: \{artifact_path\} carries no .*?\n    \)\n    sys\.exit\(1\)\n',
    '\n    print(f"OK: no provenance block required or present in {artifact_path}.")\n'
    '    sys.exit(0)\n',
    s, flags=re.S)
if n == 1:
    open(p, "w", encoding="utf-8").write(s2)
PY
if cmp -s "$VALIDATOR" "$M1"; then
  echo "FIXTURE BROKEN: M1 matched nothing — the flagless-absent rung no longer emits the message this mutation anchors on, so the mutant does not exist and its arms would score a kill nobody earned" >&2
  echo "  Re-anchor M1 on whatever the rung emits now; do not relax the assertions." >&2
  exit 2
fi
rc_m1a="$(drive "$M1" "$ART/docs/prd.md")"
rc_m1g="$(drive "$M1" "$ART/docs/report.txt")"
if [ "$rc_m1a" = 0 ] && [ "$rc_m1g" = 0 ]; then
  ok "M1 mutant KILLED by (a) and (g): reverting the absent rung to sys.exit(0) flips both to 0"
  killed_by="${killed_by}
    M1 absent rung -> sys.exit(0)          killed by (a) and (g)"
else
  mut_bad "M1 mutant SURVIVED: with the absent rung reverted to sys.exit(0), (a) read $rc_m1a and (g) read $rc_m1g — expected both 0. Whichever is still 1 is being denied by some other rung, and the arm that claims to own this behaviour is watching something else"
fi

# --- M2: the blanket acquittal ------------------------------------------------------------
# The wrong fix that passes an (a)/(b) pair read alone: `--allow-missing` short-circuits
# before the retro rung, the MALFORMED rung and every verdict rule. Inserted ABOVE the
# malformed check, which is the first rung a real short-circuit would jump.
M2="$(mut_tree m2)"
python3 - "$M2" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
anchor = "if not blocks and MARKER_RE.search(content):"
if s.count(anchor) == 1:
    ins = ('if allow_missing:\n'
           '    print(f"OK: {artifact_path} — --allow-missing")\n'
           '    sys.exit(0)\n\n')
    open(p, "w", encoding="utf-8").write(s.replace(anchor, ins + anchor))
PY
if cmp -s "$VALIDATOR" "$M2"; then
  echo "FIXTURE BROKEN: M2 matched nothing — the malformed rung this mutation inserts above was renamed, so the blanket-acquittal mutant does not exist" >&2
  exit 2
fi
rc_m2c="$(drive "$M2" "$ART/docs/retro/s301/retro.md" --allow-missing)"
rc_m2d="$(drive "$M2" "$ART/docs/fenced.md" --allow-missing)"
rc_m2h="$(drive "$M2" "$ART/docs/solo.md" --allow-missing)"
# NEAR-MISS CONJUNCT. M2 does not touch the absent rung, so (a) and (g) must hold their
# verdicts. A mutant that moved every cell would mean the arms are entangled and the kill
# below says nothing about the flag's SCOPE.
rc_m2a="$(drive "$M2" "$ART/docs/prd.md")"
rc_m2g="$(drive "$M2" "$ART/docs/report.txt")"
if [ "$rc_m2c" = 0 ] && [ "$rc_m2d" = 0 ] && [ "$rc_m2h" = 0 ] && [ "$rc_m2a" = 1 ] && [ "$rc_m2g" = 1 ]; then
  ok "M2 mutant KILLED by (c), (d) and (h): a blanket --allow-missing flips all three to 0 while (a) and (g) hold at 1"
  killed_by="${killed_by}
    M2 --allow-missing short-circuits all   killed by (c), (d) and (h)"
else
  mut_bad "M2 mutant SURVIVED or is entangled: blanket acquittal gave (c)=$rc_m2c (d)=$rc_m2d (h)=$rc_m2h (expected 0 0 0) with (a)=$rc_m2a (g)=$rc_m2g (expected 1 1). An arm reading non-zero for (c)(d)(h) cannot tell a scoped acquittal from a blanket one"
fi

# --- M3: deny only when the path ends `.md` -----------------------------------------------
# The extension-keyed non-fix. (g) owns it, and the arm is scored WITH (a) holding: a mutant
# that flipped both would be M1 again, and this one has to be killed by the extension
# property specifically.
M3="$(mut_tree m3)"
python3 - "$M3" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s2, n = re.subn(
    r'\n    print\(\n        f"FAIL: \{artifact_path\} carries no ',
    '\n    if not artifact_path.endswith(".md"):\n'
    '        print(f"OK: no provenance block required or present in {artifact_path}.")\n'
    '        sys.exit(0)\n'
    '    print(\n        f"FAIL: {artifact_path} carries no ',
    s, count=1)
if n == 1:
    open(p, "w", encoding="utf-8").write(s2)
PY
if cmp -s "$VALIDATOR" "$M3"; then
  echo "FIXTURE BROKEN: M3 matched nothing — the flagless-absent rung's emitter moved, so the extension-keyed mutant does not exist" >&2
  exit 2
fi
rc_m3g="$(drive "$M3" "$ART/docs/report.txt")"
rc_m3a="$(drive "$M3" "$ART/docs/prd.md")"
if [ "$rc_m3g" = 0 ] && [ "$rc_m3a" = 1 ]; then
  ok "M3 mutant KILLED by (g): keying the deny on a .md extension flips report.txt to 0 while the .md file holds at 1 — (g) is what makes the rung extension-independent"
  killed_by="${killed_by}
    M3 deny only when path ends .md         killed by (g)"
else
  mut_bad "M3 mutant SURVIVED or is not discriminating: with the deny keyed on .md, (g) read $rc_m3g and (a) read $rc_m3a — expected 0 and 1. If (a) also moved this is M1 over again and (g) owns nothing"
fi

# --- M4: acquit any artifact named by a RELATIVE path --------------------------------------
# The path-shape non-fix. It passes every arm this fixture had before (a2)/(a3) existed, because
# every one of those drives `$ART/...` off `mktemp` and is therefore absolute by construction —
# and it acquits the consumer's only flagless call site, which names its artifact relative to the
# consumer root. Anchored on the absent rung's own emitted text, the same anchor M1 and M3 use,
# with `count=1` and the `cmp -s` guard: a mutation that matched nothing is a mutant that never
# existed. Scored WITH (a), (g) and (a4) holding at 1 — a mutant that moved those would be M1
# again and (a2)/(a3) would own nothing.
M4="$(mut_tree m4)"
python3 - "$M4" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s2, n = re.subn(
    r'\n    print\(\n        f"FAIL: \{artifact_path\} carries no ',
    '\n    if not os.path.isabs(artifact_path):\n'
    '        print(f"OK: no provenance block required or present in {artifact_path}.")\n'
    '        sys.exit(0)\n'
    '    print(\n        f"FAIL: {artifact_path} carries no ',
    s, count=1)
if n == 1:
    open(p, "w", encoding="utf-8").write(s2)
PY
if cmp -s "$VALIDATOR" "$M4"; then
  echo "FIXTURE BROKEN: M4 matched nothing — the flagless-absent rung's emitter moved, so the relative-path-acquittal mutant does not exist and (a2)/(a3) would score a kill nobody earned" >&2
  exit 2
fi
rc_m4a2="$(drive_rel "$ART" "$M4" docs/prd.md)"
rc_m4a3="$(drive_rel "$ART" "$M4" ./docs/prd.md)"
rc_m4a="$(drive "$M4" "$ART/docs/prd.md")"
rc_m4g="$(drive "$M4" "$ART/docs/report.txt")"
rc_m4a4="$(drive_env AI_DLC_PROVENANCE_ALLOW_MISSING=1 "$M4" "$ART/docs/prd.md")"
if [ "$rc_m4a2" = 0 ] && [ "$rc_m4a3" = 0 ] && [ "$rc_m4a" = 1 ] && [ "$rc_m4g" = 1 ] && [ "$rc_m4a4" = 1 ]; then
  ok "M4 mutant KILLED by (a2) and (a3): acquitting a relative artifact path flips both to 0 while (a), (g) and (a4) hold at 1 — the absolute-path arms structurally cannot see this one"
  killed_by="${killed_by}
    M4 acquit a RELATIVE artifact path       killed by (a2) and (a3)"
else
  mut_bad "M4 mutant SURVIVED or is entangled: the relative-path acquittal gave (a2)=$rc_m4a2 (a3)=$rc_m4a3 (expected 0 0) with (a)=$rc_m4a (g)=$rc_m4g (a4)=$rc_m4a4 (expected 1 1 1). If (a2)/(a3) held at 1 they are driving an absolute path after all; if (a) moved, this is M1 again and the relative arms own nothing"
fi

# --- M5: an environment back door into the acquittal ---------------------------------------
# `--allow-missing` is an argument because a declaration is made per call site by the caller that
# decided the artifact was in scope. This mutant makes an exported name make it instead, and it
# is invisible to every arm that does not set the variable IN ITS OWN INVOCATION: the hermeticity
# scrub above unsets every AI_DLC_* name in this process, so the fixture's own environment can
# never carry it to a child. That scrub is correct and stays; (a4) works around it rather than
# relaxing it. Scored with the two UNPREFIXED names holding at 1 — a mutant reading any variable
# named *ALLOW_MISSING would be a different program, and (a5) is what tells the two apart.
M5="$(mut_tree m5)"
python3 - "$M5" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
anchor = 'allow_missing = len(sys.argv) > 5 and sys.argv[5] == "1"\n'
if s.count(anchor) == 1:
    ins = ('allow_missing = (len(sys.argv) > 5 and sys.argv[5] == "1") or bool(\n'
           '    os.environ.get("AI_DLC_PROVENANCE_ALLOW_MISSING"))\n')
    open(p, "w", encoding="utf-8").write(s.replace(anchor, ins, 1))
PY
if cmp -s "$VALIDATOR" "$M5"; then
  echo "FIXTURE BROKEN: M5 matched nothing — the line that reads the --allow-missing argument in the artifact-mode python block moved or was respelled, so the environment-back-door mutant does not exist and (a4) would score a kill nobody earned" >&2
  exit 2
fi
rc_m5a4="$(drive_env AI_DLC_PROVENANCE_ALLOW_MISSING=1 "$M5" "$ART/docs/prd.md")"
rc_m5a="$(drive "$M5" "$ART/docs/prd.md")"
rc_m5a2="$(drive_rel "$ART" "$M5" docs/prd.md)"
rc_m5n1="$(drive_env PROVENANCE_ALLOW_MISSING=1 "$M5" "$ART/docs/prd.md")"
rc_m5n2="$(drive_env ALLOW_MISSING=1 "$M5" "$ART/docs/prd.md")"
if [ "$rc_m5a4" = 0 ] && [ "$rc_m5a" = 1 ] && [ "$rc_m5a2" = 1 ] && [ "$rc_m5n1" = 1 ] && [ "$rc_m5n2" = 1 ]; then
  ok "M5 mutant KILLED by (a4): honouring AI_DLC_PROVENANCE_ALLOW_MISSING flips it to 0 while (a), (a2) and both unprefixed names in (a5) hold at 1 — the scrub makes this invisible to every arm that does not set the name in its own invocation"
  killed_by="${killed_by}
    M5 env back door into --allow-missing    killed by (a4)"
else
  mut_bad "M5 mutant SURVIVED or is entangled: the environment back door gave (a4)=$rc_m5a4 (expected 0) with (a)=$rc_m5a (a2)=$rc_m5a2 (a5:PROVENANCE_ALLOW_MISSING)=$rc_m5n1 (a5:ALLOW_MISSING)=$rc_m5n2 (expected 1 1 1 1). (a4) reading 1 means the variable never reached the child — the scrub runs in THIS process, so the name must be set in the invocation, not exported here"
fi

echo
if [ "$mutant_fails" -eq 0 ]; then
  echo "  mutants and the arms that kill them:${killed_by}"
  echo
fi
if [ "$fails" -eq 0 ]; then
  echo "provenance-flagless-default: PASS (layout: $LAYOUT, subject: ${VALIDATOR#$ROOT/})"
  exit 0
fi
echo "provenance-flagless-default: FAIL ($fails assertion(s))" >&2
exit 1
