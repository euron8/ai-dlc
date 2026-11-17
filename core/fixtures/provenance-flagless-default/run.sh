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
# HERMETICITY. The hooks honour a set of AI_DLC_* tunables and a consumer that sets one in
# settings.json exports it into every session, so the fixture would be adjudicating the
# operator's configuration rather than the code.
#
# IT ALSO BLINDS THIS FIXTURE TO AN AI_DLC_-NAMED BACK DOOR INTO THE ACQUITTAL, which is the
# reason (a4) sets its variable in the INVOCATION rather than exporting one here. The scrub is
# correct and stays; the arm works around it, and `drive_env` below is how.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }

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
           "h  a block that VIOLATES a rule under --allow-missing, DENIED"; do
    printf '  SKIP  %s — subject absent in both layouts:%s\n' "$a" "$miss"
  done
  fx_skip_exit "$HERE"
fi

command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 not on PATH" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/validate-provenance-block.sh"
echo "HERMETIC-CONSUMED core/schemas/provenance-block.json"

# IN PROCESS (BL-878). The validator is SOURCED ONCE (inproc_load: its guard returns after defining pb_main) and every
# cell asks pb_main in a subshell made to look like a fresh `bash validate-provenance-block.sh` (lib/inproc.sh). Its
# root walk starts from the function's own `${BASH_SOURCE[0]}`, the file it was defined in -- the same path the
# program run gets -- so the two resolve one schema. The three cli cells (cells.decl) run it as a program once per
# distinct CLI outcome and compare stdout, stderr and exit byte for byte with the in-process call. A CORE FIXTURE
# SHIPS AHEAD OF ITS SUBJECT: a subject with neither its `pb_main() {` line nor the column-0 source guard predates the
# wrap and reads SKIP (exit 0, never an ok); exactly one half is a respelled subject and FAILs; a subject grep cannot
# READ (exit 2) is FIXTURE ERROR.
wrap_gate() { # wrap_gate <file> <entry> -> 0 wrapped, 3 predates the wrap, 1 one half only (FAIL printed), 2 unreadable
  local d g
  grep -q "^$2() {\$" "$1"; d=$?
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$1"; g=$?
  if [ "$d" -gt 1 ] || [ "$g" -gt 1 ]; then
    echo "FIXTURE ERROR: cannot read $1 (grep exit $d/$g), so the in-process wrap cannot be judged; nothing was asserted" >&2
    return 2
  fi
  [ "$d$g" = 00 ] && return 0
  [ "$d$g" = 11 ] && return 3
  if [ "$d" = 1 ]; then echo "  FAIL  $1 carries the column-0 source guard but no \`$2() {\` line -- a respelled subject this fixture cannot drive"
  else echo "  FAIL  $1 defines \`$2() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run $2 in this shell"; fi
  return 1
}
wrap_gate "$VALIDATOR" pb_main; g_pb=$?
if [ "$g_pb" = 2 ]; then exit 2; fi
if [ "$g_pb" = 1 ]; then echo "provenance-flagless-default: 1 FAILED"; exit 1; fi
if [ "$g_pb" = 3 ]; then echo "SKIP: subject predates the in-process wrap"; exit 0; fi

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }
# shellcheck source=/dev/null
. "$HERE/../lib/inproc.sh" 2>/dev/null || { echo "FIXTURE BROKEN: core/fixtures/lib/inproc.sh absent beside $HERE" >&2; exit 2; }
inproc_load "$VALIDATOR" || { echo "FIXTURE BROKEN: sourcing $VALIDATOR defined nothing" >&2; exit 2; }
declare -F pb_main >/dev/null || { echo "FIXTURE BROKEN: $VALIDATOR defined no pb_main when sourced" >&2; exit 2; }

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
# Asked IN PROCESS (BL-878): `inproc_run` calls pb_main in a subshell made to look like a fresh
# `bash <validator>`, so an executable bit plays no part, as it played none under `bash "$v"`.
# The cli cells at the end run the program and hold it to the in-process answer.
drive() {  # drive <validator> <args...> -> prints rc, leaves combined output in $OUTF
  local v="$1"; shift
  inproc_run "$v" pb_main "$@" >"$OUTF" 2>&1
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
  ( cd "$d" || exit 9; inproc_run "$v" pb_main "$@" ) >"$OUTF" 2>&1
  printf '%s\n' "$?"
}

# THE VARIABLE IS SET IN THE INVOCATION, AND THAT IS THE WHOLE POINT OF THIS HELPER.
# The hermeticity scrub above unsets every AI_DLC_* name in this process before any arm runs, so
# an `export` here would be undone for the driven child exactly as it is for every other arm —
# which is what makes an AI_DLC_-prefixed environment back door STRUCTURALLY invisible to this
# fixture: the scrub is a correct defence against adjudicating the operator's configuration, and
# it doubles as a blindfold over the one acquittal shaped like the configuration it removes. A
# non-prefixed twin is already caught by (a)/(g), which is the asymmetry that hides the prefixed
# one. `export VAR=…` inside the call's own subshell sets it for that call only, after the scrub (inproc_run keeps
# exported variables, as a child bash would inherit them), so the rest of the file keeps its hermeticity and this
# arm gets its subject.
drive_env() {  # drive_env <VAR=VAL> <validator> <args...> -> prints rc, output in $OUTF
  local e
  local v
  e="$1"
  v="$2"
  shift 2
  ( export "${e?}"; inproc_run "$v" pb_main "$@" ) >"$OUTF" 2>&1
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
  ok "a  an ordinary .md with no block and no flag is DENIED (rc=1), naming --allow-missing and NOT as MALFORMED (control: that grammar matches on the fenced file in this same run)"; B_a=1
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
# spelling alone cannot tell them apart.
# ---------------------------------------------------------------------------
rc_a2="$(drive_rel "$ART" "$VALIDATOR" docs/prd.md)"
a2_out="$(cat "$OUTF")"
if why="$(absent_verdict "$rc_a2" "$a2_out")"; then
  ok "a2 the same block-less .md named RELATIVELY (docs/prd.md, from a cd'd cwd) is DENIED (rc=1) with the ABSENT verdict — the rung is keyed on the DECLARATION, not on how the caller spelled the path"; B_a2=1
else
  bad "a2 the block-less .md named relatively as docs/prd.md $why — the deny is keyed on an ABSOLUTE path, and the consumer's only flagless call site (ci-local.sh's retro-compliance check) passes a relative one"
  sed 's/^/        /' <<<"$a2_out" >&2
fi

rc_a3="$(drive_rel "$ART" "$VALIDATOR" ./docs/prd.md)"
a3_out="$(cat "$OUTF")"
if why="$(absent_verdict "$rc_a3" "$a3_out")"; then
  ok "a3 the same file named ./docs/prd.md is DENIED (rc=1) with the ABSENT verdict — the two relative spellings agree, so the arm cannot be satisfied by a guard that only special-cases one of them"; B_a3=1
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
# So the variable is set IN THE INVOCATION, exported inside the call's own subshell (drive_env), which
# runs after the scrub and touches only that call. (a5) drives the two unprefixed spellings for the same
# property under names the scrub never reached, so the arm covers the whole class rather than the
# one name.
# ---------------------------------------------------------------------------
rc_a4="$(drive_env AI_DLC_PROVENANCE_ALLOW_MISSING=1 "$VALIDATOR" "$ART/docs/prd.md")"
a4_out="$(cat "$OUTF")"
if why="$(absent_verdict "$rc_a4" "$a4_out")"; then
  ok "a4 a block-less .md with AI_DLC_PROVENANCE_ALLOW_MISSING=1 in the invocation's environment is still DENIED (rc=1) with the ABSENT verdict — the acquittal is an ARGUMENT, and no exported name waives it"; B_a4=1
else
  bad "a4 AI_DLC_PROVENANCE_ALLOW_MISSING=1 in the environment $why — the acquittal has an environment back door, and a consumer that exports the name in settings.json waives this rung for every artifact in every session"
  sed 's/^/        /' <<<"$a4_out" >&2
fi

for _e in PROVENANCE_ALLOW_MISSING=1 ALLOW_MISSING=1; do
  rc_a5="$(drive_env "$_e" "$VALIDATOR" "$ART/docs/prd.md")"
  a5_out="$(cat "$OUTF")"
  if why="$(absent_verdict "$rc_a5" "$a5_out")"; then
    ok "a5 a block-less .md with $_e in the invocation's environment is still DENIED (rc=1) with the ABSENT verdict"
    # A flag set inside a per-case loop is bound per case, through literal names.
    case "$_e" in
      PROVENANCE_ALLOW_MISSING=1) B_a5_1=1 ;;
      ALLOW_MISSING=1) B_a5_2=1 ;;
    esac
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
  ok "c  a RETRO with no block is still DENIED under --allow-missing (rc=1) — the flag does not reach the retro rung"; B_c=1
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
  ok "d  a MALFORMED marker under --allow-missing is still DENIED as MALFORMED (rc=1) — absent and unparseable stay two verdicts"; B_d=1
fi

rc_h="$(drive "$VALIDATOR" "$ART/docs/solo.md" --allow-missing)"
if [ "$rc_h" = 1 ]; then
  ok "h  a block PRESENT and violating a rule (mode: solo) is still DENIED under --allow-missing (rc=1) — the flag acquits an absence, never a violation"; B_h=1
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
  ok "g  an artifact with NO .md extension and no block is DENIED flagless (rc=1), naming --allow-missing — the rung is keyed on the declaration, not on the filename"; B_g=1
fi

# ---------------------------------------------------------------------------
# THE CLI CELLS (cells.decl): the validator run as a PROGRAM once per distinct CLI outcome --
# exit 0 the seed control, exit 1 the flagless deny, exit 2 the contradictory flag pair. Each
# is compared with the in-process answer on the same argv: stdout, stderr and exit separately,
# byte for byte, and each asserts its own exit, so two runs that both printed nothing cannot
# read as equivalent.
# ---------------------------------------------------------------------------
EQ="$WORK/eq"; mkdir -p "$EQ" || exit 2
eqv() { # eqv <cell-id> <args...> -> $EQ/<id>.{ip,cl}.{out,err,rc}; 0 when the two answers are identical
  local id="$1"; shift
  inproc_run "$VALIDATOR" pb_main "$@" > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  FXCELL="$id" bash "$VALIDATOR" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_rc() { cat "$EQ/$1.cl.rc"; }
if eqv cli-pass "$ART/docs/valid.md" && [ "$(eq_rc cli-pass)" = 0 ] && grep -q '^VALIDATE-PROVENANCE-BLOCK: PASS' "$EQ/cli-pass.cl.out"; then
  ok "cli-pass: the program accepts the seed control exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-pass: the program and the in-process call differ, or the outcome is not exit 0 with a PASS line (program rc=$(eq_rc cli-pass), in-process rc=$(cat "$EQ/cli-pass.ip.rc"))"; fi
if eqv cli-deny "$ART/docs/prd.md" && [ "$(eq_rc cli-deny)" = 1 ] && grep -q -- '--allow-missing' "$EQ/cli-deny.cl.out" "$EQ/cli-deny.cl.err"; then
  ok "cli-deny: the program denies the flagless blockless artifact exactly as the in-process call does (stdout, stderr, exit 1)"
else bad "cli-deny: the program and the in-process call differ, or the outcome is not exit 1 naming --allow-missing (program rc=$(eq_rc cli-deny), in-process rc=$(cat "$EQ/cli-deny.ip.rc"))"; fi
if eqv cli-usage "$ART/docs/prd.md" --allow-missing --require-skill bmad-prd && [ "$(eq_rc cli-usage)" = 2 ] \
   && grep -q 'contradicts --require-skill' "$EQ/cli-usage.cl.err"; then
  ok "cli-usage: the program refuses the contradictory flag pair exactly as the in-process call does (stdout, stderr, exit 2)"
else bad "cli-usage: the program and the in-process call differ, or the outcome is not exit 2 naming the contradiction (program rc=$(eq_rc cli-usage), in-process rc=$(cat "$EQ/cli-usage.ip.rc"))"; fi
if [ "$(eq_rc cli-pass)$(eq_rc cli-deny)$(eq_rc cli-usage)" = 012 ] && ! cmp -s "$EQ/cli-pass.cl.out" "$EQ/cli-deny.cl.out"; then
  ok "cli cells discriminate: the three argv give three different exits and the pass and the deny different stdout"
else bad "cli cells do not discriminate: exits $(eq_rc cli-pass)/$(eq_rc cli-deny)/$(eq_rc cli-usage), or cli-pass and cli-deny gave the same stdout"; fi

echo
echo "provenance-flagless-default: layout $LAYOUT, subject ${VALIDATOR#$ROOT/}"
report_end provenance-flagless-default
