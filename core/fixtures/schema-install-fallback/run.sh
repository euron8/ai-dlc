#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# schema-install-fallback — five core scripts resolve their schema from the INSTALL when an
# override root carries none, in the layout a consumer actually has.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT (BL-300). sprint-status.sh, sync-taught-schema.sh, validate-audit-anchors.sh,
# validate-write-format-steering.sh and validate-gate-adjudication.sh looked for their schema at
# `$SCRIPT_DIR/../schemas/` and under the resolved root's `{core,.claude}/schemas/`. In a consumer
# the script sits at `scripts/ai-dlc/X`, so the script-relative candidate is `scripts/schemas/`,
# which install.sh never writes. An AI_DLC_PROJECT_ROOT naming a root with no `.claude/schemas/`
# therefore left all five with nothing to load and they failed closed. The distribution cannot
# show this: there the script-relative candidate is `core/schemas/` and always exists. So every
# arm below runs in a tree built by running `scripts/install.sh` into an empty directory.
#
# THE FIX appends the install root's copy, walked up from the script's own directory, as the
# LAST candidate. Each property of that sentence is an arm:
#   A  NO-SCHEMA ROOT   a foreign root holding only `.claude/` gives the SAME exit and output as
#                       the no-override control.
#   B  ROOT WINS        a foreign root carrying an UNPARSEABLE schema makes the run non-zero, and
#                       its ALLOW twin — the same root carrying a VALID copy — exits 0, so the
#                       non-zero is the schema's doing.
#   C  LEGACY LAYOUT    a copy at `scripts/X` (the pre-relocation path) answers exactly as the
#                       `scripts/ai-dlc/X` copy under the same foreign root.
#   D  R1, write-format-steering only: under the foreign root it judges the SAME number of
#                       declaration rows as the control, not zero. The schema came from the install,
#                       so its `declared_in` paths are resolved against the install.
#   E  R2, sync-taught-schema only: WRITE mode under a foreign root that carries a stale generated
#                       region modifies neither that root's file nor the install's docs. The
#                       schemas install as a set, so the fallback branch renders the INSTALL's docs.
#   M  R3, gate-adjudication only: a foreign root carrying its own enforcement-map.yaml is the map
#                       the escalated set is derived from.
#   N  BL-326, gate-adjudication only: adjudicate mode reads `docs/escalations/pending.md` from the
#                       tree its enforcement map came from. Under a foreign root with no map (F) that
#                       is the INSTALL's docs, and — the near-miss — under a root carrying its own map
#                       (GE) it is GE's.
#   P  BL-330, write-format-steering only: a foreign root carrying the steering schema but NOT the
#                       population schema (FP) owns the PAIR, so its missing half is the honest
#                       `SKIP — EXAMINED NOTHING` (rc 0), never the install's population joined to the
#                       root's steering and judged under the root (rc 1). B's Ggood, the root carrying
#                       the whole set, is the near-miss.
#   Q  BL-331, write-format-steering only, a standalone arm after E2: under the install fallback a
#                       root carrying its OWN declared file without the anchor exits 1 naming the
#                       root's copy, and the same root with the anchor passes at the control's row
#                       count.
#
# The full A B C D E M N P vector of each script is asserted whole: its own arm(s) hold and the rest
# are not that script's.
#
# FOLDED ARMS, at the end of the run: two SHIPPING fixtures' distribution-only checks, which
# their own sandboxes could never reach because a shipping fixture cannot declare a path a
# consumer lacks.
#   CW1/CW2  layer-crosswalk-home: install.sh scaffolds the declared crosswalk file into a fresh
#            tree (CW1), and a re-install preserves a populated one (CW2).
#   HO1/HO2  handoff-completion-assertion (e6-order): templates/settings.json.template registers
#            the recover gate on PreToolUse and the handoff entry hook on PostToolUse (HO1), with
#            an impossible-hook-name control (HO2).
#   VS       BL-1155: CW2's re-install runs from the copy after it gains a fake VERSION and a commit, and its
#            .claude/.ai-dlc-version stamp and "Version:" echo carry that version and the copy's short sha.
#
# DISTRIBUTION-ONLY (.dist-only): the subject is a tree install.sh builds, and install.sh is not
# shipped. validator-path-resolution carries the distribution-side half of the same fix.
set -uo pipefail

# The five read AI_DLC_* overrides that pin a schema or map outright (AI_DLC_SPRINT_STATUS_SCHEMA,
# AI_DLC_VERDICT_SCHEMA, AI_DLC_ENFORCEMENT_MAP, ...). One leaked into this process would make
# every root irrelevant and every arm agree for that reason.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
for _v in $(env | sed -n 's/^\(CLAUDE_CODE_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR

HERE="$(cd "$(dirname "$0")" && pwd)"
# Walk up for scripts/install.sh, never count hops. ROOT_DIR, not ROOT: scripts/install.sh is read as
# the walk-up marker, and it is keyed by its `!` row in inputs.decl.
ROOT_DIR="$HERE"
while [ "$ROOT_DIR" != "/" ] && [ ! -f "$ROOT_DIR/scripts/install.sh" ]; do ROOT_DIR="$(dirname "$ROOT_DIR")"; done
INSTALL="$ROOT_DIR/scripts/install.sh"
if [ ! -f "$INSTALL" ]; then
  echo "FIXTURE ERROR: no scripts/install.sh above $HERE (root resolved to $ROOT_DIR)" >&2
  echo "  this fixture is distribution-only; it cannot run in an installed tree" >&2
  exit 2
fi
echo "HERMETIC-CONSUMED scripts/install.sh"
for _t in git python3 jq cksum; do
  command -v "$_t" >/dev/null 2>&1 || { echo "FIXTURE ERROR: $_t not on PATH" >&2; exit 2; }
done

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

# THE COPIED DISTRIBUTION. Every install run (in process and both cli cells) and the arms that read core/ or templates/
# read $DIST. The files outside core/fixtures/ are copied once from the repo (git ls-files -z | tar); core/fixtures/ is
# stubbed: install.sh reads a fixture's NAME (its directory, its `.dist-only` marker) and the index's file list, and
# copies each file's bytes into the target's tests/fixtures/, which no arm reads, so each of those files is an empty
# file in $DIST named from the index, never read from the repo. install.sh requires a git work tree whose top level is
# its own root and takes its shipping fixtures from the index, so $DIST is a git repo with everything added, nothing
# committed.
DIST="$WORK/dist"; mkdir -p "$DIST" || { echo "FIXTURE ERROR: mkdir $DIST failed" >&2; exit 2; }
( set -o pipefail; cd "$ROOT_DIR" && git ls-files -z -- core patterns templates scripts/install.sh scripts/install-scaffold-ignore.sh ':(exclude)core/fixtures' \
    | tar -cf - --null -T - | tar -C "$DIST" -xf - ) || { echo "FIXTURE ERROR: copying the distribution into $DIST failed" >&2; exit 2; }
( set -o pipefail; cd "$ROOT_DIR" && git ls-files -z -- ':(literal)core/fixtures' \
    | python3 -I -c 'import os,sys
for p in sys.stdin.buffer.read().split(b"\0"):
    if p:
        d = os.path.join(sys.argv[1].encode(), p)
        os.makedirs(os.path.dirname(d), exist_ok=True)
        open(d, "wb").close()' "$DIST" ) || { echo "FIXTURE ERROR: stubbing core/fixtures in $DIST failed" >&2; exit 2; }
git init -q "$DIST" && git -C "$DIST" add -A -f || { echo "FIXTURE ERROR: git init/add in $DIST failed" >&2; exit 2; }
[ -f "$DIST/scripts/install-scaffold-ignore.sh" ] && [ -d "$DIST/core/schemas" ] && [ -d "$DIST/patterns" ] && [ -d "$DIST/templates" ] \
  || { echo "FIXTURE ERROR: the copied distribution in $DIST is incomplete" >&2; exit 2; }
INSTALL="$DIST/scripts/install.sh"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
# IN PROCESS (BL-878). install.sh is driven through lib/inproc.sh's inproc_run, which calls ai_dlc_install_main in a
# subshell made to look like a fresh `bash install.sh`. No call sits under if, !, && or ||: install.sh's own `set -e`
# would be suspended there, and the in-process answer would stop being the program's. The program runs only in the
# two cli cells (cells.decl). Both halves of the wrap must be present: sourcing a subject with neither would run its
# body in the subshell, and one half alone is a respelled subject this fixture cannot drive.
grep -qx 'ai_dlc_install_main() {' "$INSTALL"; _gm=$?
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$INSTALL"; _gg=$?
if [ "$_gm" -gt 1 ] || [ "$_gg" -gt 1 ]; then echo "FIXTURE ERROR: cannot read $INSTALL" >&2; exit 2; fi
if [ "$_gm" -ne 0 ] || [ "$_gg" -ne 0 ]; then
  echo "  FAIL  $INSTALL is not loadable: \`ai_dlc_install_main() {\` line $([ "$_gm" -eq 0 ] && echo present || echo MISSING), column-0 source guard $([ "$_gg" -eq 0 ] && echo present || echo MISSING)" >&2
  echo "schema-install-fallback: FAILED" >&2; exit 1
fi
unset _gm _gg
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE BROKEN: cannot source lib/inproc.sh" >&2; exit 2; }

SCRIPTS="sprint-status sync-taught-schema validate-audit-anchors validate-write-format-steering validate-gate-adjudication"
schema_of() {
  case "$1" in
    sprint-status)                  printf '%s' sprint-status.json ;;
    sync-taught-schema)             printf '%s' provenance-block.json ;;
    validate-audit-anchors)         printf '%s' audit-anchors.json ;;
    validate-write-format-steering) printf '%s' write-format-steering.json ;;
    validate-gate-adjudication)     printf '%s' gate-adjudication-verdict.json ;;
  esac
}
# Each script driven in a mode that LOADS its schema; a bare run of several stops at a usage line.
argv_for() {
  case "$1" in
    sprint-status|validate-audit-anchors) printf '%s' "--render" ;;
    sync-taught-schema)             printf '%s' "--check" ;;
    validate-gate-adjudication)     printf '%s' "--expected implementation" ;;
    *)                              printf '%s' "" ;;
  esac
}
# The control's POSITIVE conjunct: a line only a run that loaded and used its schema prints. A
# control asserting rc=0 alone passes against a subject replaced by `exit 0`.
token_of() {
  case "$1" in
    sprint-status)                  printf '%s' '^# Sprint Status$' ;;
    sync-taught-schema)             printf '%s' '^sync-taught-schema: PASS .* [1-9][0-9]* taught example' ;;
    validate-audit-anchors)         printf '%s' '^# Audit Anchors$' ;;
    validate-write-format-steering) printf '%s' '^validate-write-format-steering: PASS ' ;;
    validate-gate-adjudication)     printf '%s' '^[0-9]+[a-z]?$' ;;
  esac
}
# The expected answer per script, over arms A B C D E M N P ('-' = the arm is not this script's).
want_base() {
  case "$1" in
    validate-write-format-steering) printf '%s' '0000---0' ;;
    sync-taught-schema)             printf '%s' '000-0---' ;;
    validate-gate-adjudication)     printf '%s' '000--00-' ;;
    *)                              printf '%s' '000-----' ;;
  esac
}

# --- the install ---------------------------------------------------------------------------
# install.sh refuses a target with no _bmad/, and a .git makes the target its own root so the
# resolver's walk stops there and never finds a schema above the sandbox.
BASE="$WORK/base"
# The cli cells (cells.decl): install.sh run as a PROGRAM once per distinct CLI outcome, each compared with the
# in-process call on the same input, in the same world rebuilt at the same path: stdout, stderr, exit code and the
# target's file list. cli-install-ok IS this fixture's install: its in-process twin builds the tree every arm reads.
EQ="$WORK/eq"; mkdir -p "$EQ" || exit 2
eq_world() { rm -rf "$1"; mkdir -p "$1/_bmad" && git init -q "$1" || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }; }
eq_nobmad() { rm -rf "$1"; mkdir -p "$1" || exit 2; }
eq_tree() { ( cd "$1" && find . -path ./.git -prune -o -print | LC_ALL=C sort ); }
eq_run() { # <id> <world-builder> <target> -> $EQ/<id>.{cl,ip}.{out,err,rc,tree}
  local id="$1" mk="$2" t="$3"
  "$mk" "$t"
  FXCELL="$id" bash "$INSTALL" "$t" </dev/null > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  eq_tree "$t" > "$EQ/$id.cl.tree"
  "$mk" "$t"
  inproc_run "$INSTALL" ai_dlc_install_main "$t" </dev/null > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  eq_tree "$t" > "$EQ/$id.ip.tree"
  return 0
}
eq_same() { local x; for x in out err rc tree; do cmp -s "$EQ/$1.cl.$x" "$EQ/$1.ip.$x" || { echo "$x"; return 1; }; done; }
eq_verdict() { # <id> <want rc> <positive stdout regex> <what>
  local d s
  d="$(eq_same "$1")"; s=$?
  if [ "$s" -eq 0 ] && [ "$(cat "$EQ/$1.cl.rc")" = "$2" ] && grep -Eq "$3" "$EQ/$1.cl.out"; then
    ok "$1: the program $4 exactly as the in-process call does (stdout, stderr, exit $2, file list)"
  else
    bad "$1: the program and the in-process call differ (${d:-none}) or the outcome is not exit $2 with /$3/ (program exit $(cat "$EQ/$1.cl.rc"))"
  fi
}
eq_run cli-install-refuse eq_nobmad "$BASE/t"
eq_verdict cli-install-refuse 1 '^Warning: BMAD Method not detected' "refuses a target with no _bmad/"
eq_run cli-install-ok eq_world "$BASE/t"
eq_verdict cli-install-ok 0 '^Installation complete!$' "installs into a fresh target"
[ "$(cat "$EQ/cli-install-ok.cl.rc")" != "$(cat "$EQ/cli-install-refuse.cl.rc")" ] \
  && ok "cli cells discriminate: install.sh exits 0 and 1" \
  || bad "cli cells do not discriminate: cli-install-ok and cli-install-refuse share an exit code"
cp "$EQ/cli-install-ok.ip.out" "$WORK/install.log" || exit 2
if [ "$(cat "$EQ/cli-install-ok.ip.rc")" != 0 ]; then
  echo "FIXTURE ERROR: install.sh failed into $BASE/t" >&2; tail -5 "$WORK/install.log" >&2; exit 2
fi
for s in $SCRIPTS; do
  [ -f "$BASE/t/scripts/ai-dlc/$s.sh" ] && [ -f "$BASE/t/.claude/schemas/$(schema_of "$s")" ] || {
    echo "FIXTURE ERROR: the install lacks scripts/ai-dlc/$s.sh or .claude/schemas/$(schema_of "$s")" >&2; exit 2; }
done
[ -f "$BASE/t/.claude/skills/ai-dlc/enforcement-map.yaml" ] || {
  echo "FIXTURE ERROR: the install lacks .claude/skills/ai-dlc/enforcement-map.yaml" >&2; exit 2; }
# N's verdict: every escalated check of the install's map, the first one FAILed, so adjudicate mode
# reaches the suppression join and names the escalations file it consulted. The escalated set is
# DERIVED with --expected, never listed, and the file is named by its nonce because the validator
# refuses a verdict whose stem is not its nonce. Shared read-only across worlds.
GA_NONCE="implementation-20260715T140322Z"
GA_VERDICT="$WORK/gate-adjudication/$GA_NONCE.verdict.json"
mkdir -p "$WORK/gate-adjudication" || exit 2
GA_IDS="$(cd "$BASE/t" && bash "$BASE/t/scripts/ai-dlc/validate-gate-adjudication.sh" --expected implementation 2>/dev/null)"
[ -n "$GA_IDS" ] || { echo "FIXTURE ERROR: --expected implementation derived no escalated set from the install" >&2; exit 2; }
python3 - "$GA_VERDICT" "$GA_NONCE" $GA_IDS <<'PY' || { echo "FIXTURE ERROR: verdict not written" >&2; exit 2; }
import json, sys
out, nonce, ids = sys.argv[1], sys.argv[2], sys.argv[3:]
doc = {"schema_id": "GATE_ADJUDICATION_VERDICT v1", "gate_type": "implementation",
       "gate_series_id": nonce, "gate_nonce": nonce, "generated_at": "2026-07-15T14:05:07Z",
       "adjudicator_agent_id": "agent-fixture-0001", "catalog": "core",
       "verdicts": [{"check_id": c, "verdict": "FAIL" if i == 0 else "PASS",
                     "evidence": "fixture: check %s" % c} for i, c in enumerate(ids)]}
open(out, "w").write(json.dumps(doc, indent=2) + "\n")
PY
# The script-relative candidate must be ABSENT, or this tree cannot express the defect.
[ ! -e "$BASE/t/scripts/schemas" ] || {
  echo "FIXTURE ERROR: the install carries scripts/schemas/ — the consumer layout this fixture defends is not the one install.sh builds" >&2; exit 2; }
# The pre-relocation layout, beside the current one. Every shipped script is copied, not just the
# five: gate-adjudication shells to siblings beside itself.
n_legacy=0
# The legacy tree is a pre-0.126.0 consumer: install.sh never writes scripts/<x>.sh, it only reports a
# stale one, which is an OLD script carrying its own embedded helpers. Modelling "the same program"
# there means the .sh files AND the non-.sh modules they run beside themselves (gate_adjudication.py);
# a bare new .sh without its module is a layout no install produces.
for f in "$BASE/t/scripts/ai-dlc/"*.sh "$BASE/t/scripts/ai-dlc/"*.py; do
  [ -f "$f" ] || continue
  cp "$f" "$BASE/t/scripts/" || exit 2
  case "$f" in *.sh) n_legacy=$((n_legacy + 1));; esac
done
[ "$n_legacy" -ge 10 ] || { echo "FIXTURE ERROR: only $n_legacy script(s) under scripts/ai-dlc/" >&2; exit 2; }

# The generated-region envelope, READ from what the install ships rather than written here, so a
# change to the region grammar moves the decoy with it.
grep -rh 'BEGIN GENERATED: provenance-block/' "$BASE/t/.claude/skills" "$BASE/t/.claude/team-roles" \
  > "$WORK/begin.lines" 2>/dev/null
BEGIN_LINE="$(sed -n 1p "$WORK/begin.lines")"
[ -n "$BEGIN_LINE" ] || { echo "FIXTURE ERROR: the install carries no provenance-block generated region" >&2; exit 2; }
END_LINE="<!-- END GENERATED: provenance-block -->"
grep -rqF "$END_LINE" "$BASE/t/.claude/skills" "$BASE/t/.claude/team-roles" || {
  echo "FIXTURE ERROR: the install carries no '$END_LINE'" >&2; exit 2; }

# --- the foreign roots of one world -----------------------------------------------------------
mk_roots() { # $1 world
  local w="$1" s n g
  mkdir -p "$w/F/.claude" || return 1
  for s in $SCRIPTS; do
    n="$(schema_of "$s")"
    for g in Gbad Ggood; do
      mkdir -p "$w/$g-$s/.claude/schemas" "$w/$g-$s/.claude/skills/ai-dlc" || return 1
      printf '# probe\n' > "$w/$g-$s/.claude/skills/ai-dlc/probe.md"
      # sync-taught-schema refuses a provenance schema without the verdict schema beside it.
      [ "$s" != sync-taught-schema ] || cp "$w/t/.claude/schemas/gate-adjudication-verdict.json" "$w/$g-$s/.claude/schemas/" || return 1
      # gate-adjudication's map falls back on the same walk. The root carries the install's own
      # map so B turns on the SCHEMA alone: without it, deleting the walk fails Ggood on the map
      # and DEL scores on B, an arm it does not own.
      [ "$s" != validate-gate-adjudication ] || cp "$w/t/.claude/skills/ai-dlc/enforcement-map.yaml" "$w/$g-$s/.claude/skills/ai-dlc/" || return 1
    done
    # A steering schema read from the ROOT resolves its `declared_in` paths under that root, so
    # the ALLOW twin carries what they name — measured: a root carrying the steering schema alone
    # exits 1 on "declares its entry format in ... and no file is there", which is correct and
    # would make B pass for a reason that is not the schema.
    # Gbad carries them too, the population schema above all: without pipeline-state-paths.json
    # a run whose install fallback is deleted stops at "no population" with exit 0 before it
    # reads the steering schema, and DEL scored on B for that reason (measured).
    if [ "$s" = validate-write-format-steering ]; then
      for g in Gbad Ggood; do
        cp "$w/t/.claude/schemas/"*.json "$w/$g-$s/.claude/schemas/" || return 1
        mkdir -p "$w/$g-$s/.claude/skills" || return 1
        cp -R "$w/t/.claude/skills/ai-dlc-update" "$w/$g-$s/.claude/skills/" || return 1
      done
    fi
    printf '{ "sif_unparseable": \n' > "$w/Gbad-$s/.claude/schemas/$n"
    cp "$w/t/.claude/schemas/$n" "$w/Ggood-$s/.claude/schemas/$n" || return 1
  done
  mkdir -p "$w/FE/.claude/skills/ai-dlc" || return 1
  printf '# decoy\n\n%s\nSTALE — not what the schema renders\n%s\n' "$BEGIN_LINE" "$END_LINE" \
    > "$w/FE/.claude/skills/ai-dlc/decoy.md"
  mkdir -p "$w/GM/.claude/schemas" "$w/GM/.claude/skills/ai-dlc" || return 1
  cp "$w/t/.claude/schemas/gate-adjudication-verdict.json" "$w/GM/.claude/schemas/" || return 1
  printf 'checks:\n  - id: "SIFPROBE"\n    adjudication: llm\n    gate_types: [implementation]\n' \
    > "$w/GM/.claude/skills/ai-dlc/enforcement-map.yaml"
  # N's near-miss: a root carrying its OWN copy of the install's map, so the verdict covers its
  # escalated set exactly and the run reaches the join, and whose escalations are therefore its own.
  mkdir -p "$w/GE/.claude/skills/ai-dlc" || return 1
  cp "$w/t/.claude/skills/ai-dlc/enforcement-map.yaml" "$w/GE/.claude/skills/ai-dlc/" || return 1
  # P's subject: the install's steering schema, WITHOUT the population schema, plus the skills its
  # `declared_in` paths name, so the only thing the root lacks is the population half.
  mkdir -p "$w/FP/.claude/schemas" || return 1
  cp "$w/t/.claude/schemas/write-format-steering.json" "$w/FP/.claude/schemas/" || return 1
  cp -R "$w/t/.claude/skills" "$w/FP/.claude/" || return 1
  [ ! -e "$w/FP/.claude/schemas/pipeline-state-paths.json" ] || return 1
}

# drive <world> <ai|legacy> <script> <override root or ""> -> "rc=<n>" then the normalized output
drive() {
  local w="$1" s="$3" p out rc
  if [ "$2" = legacy ]; then p="$w/t/scripts/$s.sh"; else p="$w/t/scripts/ai-dlc/$s.sh"; fi
  if [ -n "$4" ]; then
    out="$(cd "$w/t" && AI_DLC_PROJECT_ROOT="$4" bash "$p" $(argv_for "$s") 2>&1)"; rc=$?
  else
    out="$(cd "$w/t" && bash "$p" $(argv_for "$s") 2>&1)"; rc=$?
  fi
  printf 'rc=%s\n' "$rc"
  printf '%s\n' "$out" | sed -e "s@$w/t/scripts/ai-dlc@SCRIPTDIR@g" -e "s@$w/t/scripts@SCRIPTDIR@g" -e "s@$w@WORLD@g"
}
first_line() { printf '%s' "${1%%$'\n'*}"; }
decl_rows() { sed -n 's/.*(\([0-9][0-9]*\) declaration row(s) total.*/\1/p' <<<"$1" | sed -n 1p; }
sum_docs() { find "$1/t/.claude/skills" "$1/t/.claude/team-roles" -type f -exec cksum {} + 2>/dev/null | sort | cksum; }

# adjudicate <world> <override root> -> the escalations path adjudicate mode names, WORLD-relative
adjudicate() {
  local w="$1" out
  out="$(cd "$w/t" && AI_DLC_PROJECT_ROOT="$2" bash "$w/t/scripts/ai-dlc/validate-gate-adjudication.sh" implementation "$GA_VERDICT" 2>&1)"
  printf '%s\n' "$out" | sed -e "s@$w@WORLD@g" | grep -oE '\((no-escalations-file|ok):[^)]*' | sed -n 's/^([a-z-]*://p' | sed -n 1p
}

# vector <world> <script> -> eight characters over A B C D E M N P: 0 held, 1 failed, - not this
# script's; or "BROKEN: <why>" when the control itself did not run.
vector() {
  local w="$1" s="$2" ctl fo lg gb gg a="-" b="-" c="-" d="-" e="-" m="-" n="-" p="-" nc nf d0 i0 d1 i1 gm fp
  ctl="$(drive "$w" ai "$s" "")"
  if [ "$(first_line "$ctl")" != rc=0 ] || ! grep -Eq "$(token_of "$s")" <<<"$ctl"; then
    echo "BROKEN: the no-override control of $s did not exit 0 with its baseline line: $(printf '%s' "$ctl" | tr '\n' '|' | cut -c1-160)"; return
  fi
  fo="$(drive "$w" ai "$s" "$w/F")"
  if [ "$s" = validate-write-format-steering ]; then
    # D owns the counts, so A compares the exit exactly and the text with digits masked.
    a=1; [ "$(first_line "$fo")" = "$(first_line "$ctl")" ] && [ "$(tr 0-9 N <<<"$fo")" = "$(tr 0-9 N <<<"$ctl")" ] && a=0
  else
    a=1; [ "$fo" = "$ctl" ] && a=0
  fi
  gg="$(drive "$w" ai "$s" "$w/Ggood-$s")"
  gb="$(drive "$w" ai "$s" "$w/Gbad-$s")"
  b=1; [ "$(first_line "$gb")" != rc=0 ] && [ "$(first_line "$gg")" = rc=0 ] && b=0
  lg="$(drive "$w" legacy "$s" "$w/F")"
  c=1; [ "$lg" = "$fo" ] && c=0
  if [ "$s" = validate-write-format-steering ]; then
    nc="$(decl_rows "$ctl")"; nf="$(decl_rows "$fo")"
    case "$nc" in ''|0) echo "BROKEN: the control of $s judged no declaration rows"; return ;; esac
    d=1; [ "$nf" = "$nc" ] && d=0
    fp="$(drive "$w" ai "$s" "$w/FP")"
    p=1
    if [ "$(first_line "$fp")" = rc=0 ] && grep -q 'SKIP — EXAMINED NOTHING' <<<"$fp" \
       && [ "$(first_line "$gg")" = rc=0 ] && ! grep -q 'SKIP — EXAMINED NOTHING' <<<"$gg"; then p=0; fi
  fi
  if [ "$s" = sync-taught-schema ]; then
    d0="$(cksum < "$w/FE/.claude/skills/ai-dlc/decoy.md")"; i0="$(sum_docs "$w")"
    ( cd "$w/t" && AI_DLC_PROJECT_ROOT="$w/FE" bash "$w/t/scripts/ai-dlc/sync-taught-schema.sh" >/dev/null 2>&1 )
    d1="$(cksum < "$w/FE/.claude/skills/ai-dlc/decoy.md")"; i1="$(sum_docs "$w")"
    e=1; [ "$d0" = "$d1" ] && [ "$i0" = "$i1" ] && e=0
  fi
  if [ "$s" = validate-gate-adjudication ]; then
    gm="$(drive "$w" ai "$s" "$w/GM")"
    m=1
    if [ "$(first_line "$gm")" = rc=0 ] && grep -qx SIFPROBE <<<"$gm" && ! grep -qx SIFPROBE <<<"$ctl"; then m=0; fi
    n=1
    if [ "$(adjudicate "$w" "$w/F")" = "WORLD/t/docs/escalations/pending.md" ] \
       && [ "$(adjudicate "$w" "$w/GE")" = "WORLD/GE/docs/escalations/pending.md" ]; then n=0; fi
  fi
  printf '%s%s%s%s%s%s%s%s\n' "$a" "$b" "$c" "$d" "$e" "$m" "$n" "$p"
}

# build_world <name> -> a whole copy of the install (a copy-on-write clone where the filesystem has one)
# with the foreign roots built beside it; its .status says APPLIED or why not. Write-mode drives (arm E,
# E2) modify the install's docs, so the copy is whole.
build_world() {
  local w="$WORK/$1"
  mkdir -p "$w" && { cp -Rc "$BASE/t" "$w/t" 2>"$w/.err" || cp -R "$BASE/t" "$w/t" 2>"$w/.err"; } \
    || { echo "DID NOT APPLY: copy of the install failed: $(sed -n 1p "$w/.err")" > "$w/.status"; return 1; }
  mk_roots "$w" || { echo "DID NOT APPLY: foreign roots not built" > "$w/.status"; return 1; }
  echo APPLIED > "$w/.status"
}

echo "schema-install-fallback"
echo "  install: $BASE/t (scripts/ai-dlc/ + $n_legacy legacy copies in scripts/)"
echo ""

# --- the install ------------------------------------------------------------------
mk_roots "$BASE" || { echo "FIXTURE ERROR: foreign roots not built" >&2; exit 2; }

# E's discrimination, proven first: the decoy IS a live stale region that write mode rewrites
# when the root carrying it legitimately owns the schemas. Without this, "the decoy was not
# modified" is satisfied by a decoy write mode could never have touched.
mkdir -p "$BASE/FE2/.claude/skills/ai-dlc" "$BASE/FE2/.claude/schemas" || exit 2
cp "$BASE/FE/.claude/skills/ai-dlc/decoy.md" "$BASE/FE2/.claude/skills/ai-dlc/decoy.md" || exit 2
cp "$BASE/t/.claude/schemas/provenance-block.json" "$BASE/t/.claude/schemas/gate-adjudication-verdict.json" \
   "$BASE/FE2/.claude/schemas/" || exit 2
_d0="$(cksum < "$BASE/FE2/.claude/skills/ai-dlc/decoy.md")"
( cd "$BASE/t" && AI_DLC_PROJECT_ROOT="$BASE/FE2" bash "$BASE/t/scripts/ai-dlc/sync-taught-schema.sh" >/dev/null 2>&1 )
if [ "$(cksum < "$BASE/FE2/.claude/skills/ai-dlc/decoy.md")" != "$_d0" ]; then
  ok "CONTROL (E): write mode rewrites the decoy region when its root carries the schemas — the decoy is live"
else
  bad "CONTROL (E): write mode left the decoy untouched even under a root that owns it — arm E cannot fire"
fi

extra_arms() {
  case "$1" in
    validate-write-format-steering) printf '%s' ', D same declaration rows, P schema pair resolves as a set' ;;
    sync-taught-schema)             printf '%s' ', E write mode touches nothing' ;;
    validate-gate-adjudication)     printf '%s' ', M root map wins, N escalations follow the map' ;;
  esac
}
for s in $SCRIPTS; do
  got="$(vector "$BASE" "$s")"; want="$(want_base "$s")"
  if [ "$got" = "$want" ]; then
    ok "$s: A no-schema root = control, B root schema wins, C legacy layout agrees$(extra_arms "$s") ($got)"
  else
    bad "$s: vector $got, want $want (A B C D E M N P)"
  fi
done

# --- the whole-tree copy that E2 and Q write into -------------------------------------------
echo ""
build_world m1 || { echo "FIXTURE ERROR: whole-tree copy not built: $(cat "$WORK/m1/.status" 2>/dev/null)" >&2; exit 2; }

# --- E2 (BL-332): write mode under a foreign root REWRITES a stale region in the INSTALL ------
# Arm E seeds its stale region in the FOREIGN root only, and the install's docs are already in
# sync, so "the install's docs are unchanged" holds whether the fallback branch renders them or
# skips them — and E never reads the exit. Under R2 the fallback branch takes ROOT and DOC_DIRS
# from the install, so write mode over a stale install region must do exactly what a run with no
# override does: exit 0, rewrite the install's retro.md, leave the foreign decoy alone.
#   1. The seed is live: --check under the foreign root exits 1 naming steps/retro.md.
#   2. EXPECTED is DERIVED, not the shipped bytes: a no-override write of the same seed (that run
#      resolves the install's .claude/schemas/ branch, never the fallback), asserted to differ from the seed so the comparison is not two no-ops.
#   3. Re-seeded, the foreign-root write exits 0, reports 1 file updated, produces EXPECTED byte
#      for byte, leaves the decoy's cksum alone, and --check then passes.

# e2 <world> -> "0" held, or "1 <why>"
bl332_e2() {
  local w="$1" r out rc exp seed d0 sc
  r="$w/t/.claude/skills/ai-dlc/steps/retro.md"
  [ -f "$r" ] && grep -qF "$BEGIN_LINE" "$r" || { echo "1 BROKEN: the install carries no provenance region in steps/retro.md"; return; }
  seed="$w/retro.seeded"; exp="$w/retro.expected"
  python3 - "$r" "$seed" "$BEGIN_LINE" "$END_LINE" <<'PY' || { echo "1 BROKEN: seeding failed"; return; }
import sys
p, out, b, e = sys.argv[1:5]
s = open(p).read()
i = s.index(b) + len(b); j = s.index(e, i)
open(out, "w").write(s[:i] + "\nSTALE — BL-332 seed, not what the schema renders\n" + s[j:])
PY
  cmp -s "$seed" "$r" && { echo "1 BROKEN: the seed is byte-identical to the shipped retro.md"; return; }
  cp "$seed" "$r" || { echo "1 BROKEN: seed copy failed"; return; }
  out="$(cd "$w/t" && AI_DLC_PROJECT_ROOT="$w/FE" bash "$w/t/scripts/ai-dlc/sync-taught-schema.sh" --check 2>&1)"; rc=$?
  [ "$rc" = 1 ] && grep -q 'steps/retro.md' <<<"$out" || { echo "1 BROKEN: --check under the foreign root did not flag the seeded retro.md (rc=$rc)"; return; }
  ( cd "$w/t" && bash "$w/t/scripts/ai-dlc/sync-taught-schema.sh" >/dev/null 2>&1 ) || { echo "1 BROKEN: the no-override write failed"; return; }
  cp "$r" "$exp" || { echo "1 BROKEN: expected copy failed"; return; }
  cmp -s "$exp" "$seed" && { echo "1 BROKEN: the no-override write left the seed unchanged"; return; }
  cp "$seed" "$r" || { echo "1 BROKEN: re-seed failed"; return; }
  d0="$(cksum < "$w/FE/.claude/skills/ai-dlc/decoy.md")"
  out="$(cd "$w/t" && AI_DLC_PROJECT_ROOT="$w/FE" bash "$w/t/scripts/ai-dlc/sync-taught-schema.sh" 2>&1)"; rc=$?
  [ "$rc" = 0 ] || { echo "1 foreign-root write exited $rc"; return; }
  grep -q '; 1 file(s) updated\.$' <<<"$out" || { echo "1 foreign-root write did not report 1 file updated"; return; }
  cmp -s "$r" "$exp" || { echo "1 foreign-root write left retro.md differing from the no-override render"; return; }
  [ "$(cksum < "$w/FE/.claude/skills/ai-dlc/decoy.md")" = "$d0" ] || { echo "1 foreign-root write modified the foreign decoy"; return; }
  ( cd "$w/t" && bash "$w/t/scripts/ai-dlc/sync-taught-schema.sh" --check >/dev/null 2>&1 ); sc=$?
  [ "$sc" = 0 ] || { echo "1 --check after the write exited $sc"; return; }
  echo 0
}

bl332_stale_install_arm() {
  local e
  e="$(bl332_e2 "$WORK/m1")"
  case "$e" in
    0) ok "E2 write mode under a foreign root rewrites a stale INSTALL retro.md region to the no-override render, decoy untouched" ;;
    "1 BROKEN"*) bad "E2: FIXTURE BROKEN — ${e#1 }" ;;
    *) bad "E2 write mode under a foreign root over a stale install region: ${e#1 }" ;;
  esac
}
bl332_stale_install_arm

# --- Q (BL-331): under the install fallback, the ROOT's copy of a declared file is judged too ---
# Arm D resolves every `declared_in` against the install once the schema pair came from there, so a
# root carrying its OWN copy of a declared file with the anchor gone was acquitted: the install's
# intact copy was judged and the root's stale one never read (measured: rc 0 `PASS — 5 of 20`,
# byte-for-byte the no-override answer, where the distribution layout exits 1 on the same root).
# The root holds no .claude/schemas, so the fallback branch is the one taken, in the consumer layout.
#   STALE root  its reconcile/lib.sh lacks `function ledger_entry_shape(` -> rc 1 and a STALE finding
#               naming the ROOT's lib.sh.
#   INTACT root the same file WITH its anchor -> rc 0, `PASS —`, and the control's declaration-row
#               count, so the root side adds findings only, never a row. F, the bare root, is arm A and holds.

# q <world> -> two characters, stale-arm then intact-arm, 0 held 1 failed; or "BROKEN: <why>"
bl331_q() {
  local w="$1" lib=".claude/skills/ai-dlc-update/reconcile/lib.sh" ctl st it rc_s rc_i s=1 i=1 nc
  [ -f "$w/t/$lib" ] && grep -qF 'function ledger_entry_shape(' "$w/t/$lib" \
    || { echo "BROKEN: the install's $lib does not carry the anchor"; return; }
  mkdir -p "$w/S331/$(dirname "$lib")" "$w/I331/$(dirname "$lib")" || { echo "BROKEN: mkdir"; return; }
  grep -vF 'function ledger_entry_shape(' "$w/t/$lib" > "$w/S331/$lib"
  cp "$w/t/$lib" "$w/I331/$lib" || { echo "BROKEN: copy"; return; }
  grep -qF 'function ledger_entry_shape(' "$w/S331/$lib" && { echo "BROKEN: the stale copy still carries the anchor"; return; }
  [ ! -e "$w/S331/.claude/schemas" ] && [ ! -e "$w/I331/.claude/schemas" ] || { echo "BROKEN: a Q root carries schemas"; return; }
  ctl="$(drive "$w" ai validate-write-format-steering "")"
  nc="$(decl_rows "$ctl")"
  case "$nc" in ''|0) echo "BROKEN: the control judged no declaration rows"; return ;; esac
  st="$(drive "$w" ai validate-write-format-steering "$w/S331")"; rc_s="$(first_line "$st")"
  it="$(drive "$w" ai validate-write-format-steering "$w/I331")"; rc_i="$(first_line "$it")"
  if [ "$rc_s" = rc=1 ] && grep -qF "$lib under the project root" <<<"$st" \
     && grep -qF "no longer contains 'function ledger_entry_shape('" <<<"$st"; then s=0; fi
  if [ "$rc_i" = rc=0 ] && grep -q '^validate-write-format-steering: PASS ' <<<"$it" \
     && [ "$(decl_rows "$it")" = "$nc" ]; then i=0; fi
  echo "$s$i"
}

bl331_arm() {
  local q
  q="$(bl331_q "$WORK/m1")"
  case "$q" in
    BROKEN*) bad "Q: FIXTURE BROKEN — ${q#BROKEN: }" ;;
    00)      ok "Q a stale root lib.sh under the install fallback exits 1 naming the root's copy; the intact root passes with the control's row count" ;;
    *)       bad "Q stale/intact root under the install fallback: $q, want 00 (a stale root is acquitted, or an intact one fails)" ;;
  esac
}
bl331_arm

# --- FOLDED ARMS: distribution-only checks of two SHIPPING fixtures ---------------------------
# These arms read inputs a shipping fixture cannot declare: a declared path that is absent on a
# consumer is exit 2 there. The shipping fixtures therefore could not declare them, their
# sandboxes never held them, and the arms stood down with an ok on every gated run. This fixture
# is .dist-only and declares scripts/install.sh, core/ and templates/, so here they run. Each one
# FAILS when its input is missing; a stand-down here would recreate the gap. They run after every
# background worker above has been reaped. Between the install at the top and this point nothing
# writes $BASE/t's crosswalk path: the legacy copies go to scripts/, the foreign roots sit beside
# $BASE/t, and every other world works on a copy.
echo ""

# VS (BL-1155): every install above ran from a copy with no VERSION and an unborn HEAD, so their stamp reads
# `unknown`. The copy gains a fixed fake VERSION and one commit here, before CW2's re-install, the one install
# run that follows; VS reads that run's stamp and its "Version:" echo, so install.sh's VERSION-present and
# HEAD-present branches are asserted with no added run.
. "$HERE/../lib/world.sh" || { echo "FIXTURE BROKEN: cannot source lib/world.sh" >&2; exit 2; }
VS_VER="9.8.7-vs"
printf '%s\n' "$VS_VER" > "$DIST/VERSION" && world_git -C "$DIST" add -f VERSION && world_git -C "$DIST" commit -q -m vs \
  || { echo "FIXTURE ERROR: committing the copied distribution in $DIST failed" >&2; exit 2; }
VS_SHA="$(world_git -C "$DIST" rev-parse --short HEAD)"
[ -n "$VS_SHA" ] || { echo "FIXTURE ERROR: no HEAD in $DIST after its commit" >&2; exit 2; }

# CW1/CW2, from layer-crosswalk-home (LC-N7 / W8): the installer scaffolds the consumer's
# crosswalk file ONCE and a re-install preserves it. A file the installer re-copies is core's
# however the contract describes it, and the consumer's rows would vanish at the next install.
# CW_REL is read from the contract the install shipped from, never hard-coded.
CW_REL="$(sed -n 's/^consumer_crosswalk_file:[[:space:]]*//p' "$DIST/core/skills/ai-dlc/layer-contract.yaml" 2>/dev/null \
  | head -1 | sed 's/[[:space:]]*$//')"
if [ -z "$CW_REL" ]; then
  bad "CW1 (layer-crosswalk-home): core/skills/ai-dlc/layer-contract.yaml declares no consumer_crosswalk_file:, so there is no crosswalk path to check"
  bad "CW2 (layer-crosswalk-home): preserve-on-reinstall not reached: no declared crosswalk path"
elif [ -f "$BASE/t/$CW_REL" ]; then
  ok "CW1 (layer-crosswalk-home): install.sh scaffolds the declared crosswalk file into a fresh tree"
  printf '\n%s\n' '| 33 | `[ext:domain]` | Cross-story test-strategy deliverable presence | pre-migration gate logs | became 934 |' \
    >> "$BASE/t/$CW_REL"
  _cw_sum="$(cksum < "$BASE/t/$CW_REL")"
  inproc_run "$INSTALL" ai_dlc_install_main "$BASE/t" </dev/null >"$WORK/reinstall.log" 2>&1
  [ "$(cksum < "$BASE/t/$CW_REL")" = "$_cw_sum" ] \
    && ok "CW2 (layer-crosswalk-home): a re-install PRESERVES a populated crosswalk file — the rows are the consumer's" \
    || bad "CW2 (layer-crosswalk-home): a re-install overwrote the populated crosswalk file, which is the defect LC-N7 exists to end"
else
  bad "CW1 (layer-crosswalk-home): install.sh did not scaffold '$CW_REL' into a fresh tree"
  bad "CW2 (layer-crosswalk-home): preserve-on-reinstall not reached: nothing was scaffolded"
fi
VS_STAMP="$BASE/t/.claude/.ai-dlc-version"
if [ ! -f "$WORK/reinstall.log" ]; then
  bad "VS (BL-1155): the re-install from a copy carrying VERSION and a commit did not run, so no arm reads that stamp"
elif grep -qxF "version: $VS_VER" "$VS_STAMP" && grep -qxF "commit: $VS_SHA" "$VS_STAMP" \
     && grep -qxF "skill_version: $VS_VER" "$VS_STAMP" && grep -qxF "skill_commit: $VS_SHA" "$VS_STAMP" \
     && grep -qxF "Version: $VS_VER ($VS_SHA)" "$WORK/reinstall.log"; then
  ok "VS (BL-1155): from a source carrying VERSION and a commit, the stamp and the Version: echo name $VS_VER @ $VS_SHA"
else
  bad "VS (BL-1155): want version/skill_version $VS_VER and commit/skill_commit $VS_SHA in the stamp and 'Version: $VS_VER ($VS_SHA)' echoed; stamp has [$(grep -E '^(skill_)?(version|commit):' "$VS_STAMP" 2>/dev/null | tr '\n' ' ')], echo [$(grep -E '^Version:' "$WORK/reinstall.log" | head -1)]"
fi

# HO1/HO2, from handoff-completion-assertion's (e6)-(e13): that fixture drives the recover
# gate, then the Read, then the handoff entry hook, on the strength of the REGISTRATION order.
# The registration is the settings template; if it ever put the entry hook on PreToolUse or the
# gate on PostToolUse, that section would drive a sequence no consumer runs and keep printing
# ok. jq, because the shape is nested and a grep for two filenames cannot say which EVENT each
# sits under. The control: a hook name the template does NOT carry must resolve to nothing, or
# the two readings came from a query that matches anything.
_HES_TMPL="$DIST/templates/settings.json.template"
if [ ! -f "$_HES_TMPL" ]; then
  bad "HO1 (handoff-completion-assertion e6-order): templates/settings.json.template is absent from a tree that declares templates/ — the registration order is unverified"
  bad "HO2 (handoff-completion-assertion e6-order control): not reached: no template"
else
  _HES_GATE_EV="$(jq -r '.hooks | to_entries[] | select(.value[]?.hooks[]?.command // "" | test("ai-dlc-recover-gate\\.sh")) | .key' "$_HES_TMPL" 2>/dev/null | head -1)"
  _HES_ENT_EV="$(jq -r  '.hooks | to_entries[] | select(.value[]?.hooks[]?.command // "" | test("ai-dlc-handoff-entry\\.sh")) | .key' "$_HES_TMPL" 2>/dev/null | head -1)"
  if [ "$_HES_GATE_EV" = "PreToolUse" ] && [ "$_HES_ENT_EV" = "PostToolUse" ]; then
    ok "HO1 (handoff-completion-assertion e6-order): the template registers the gate on PreToolUse and the entry hook on PostToolUse, so the shipped order on one Read is gate -> Read -> entry"
  else
    bad "HO1 (handoff-completion-assertion e6-order): the template registers the gate on '${_HES_GATE_EV:-<nothing>}' and the entry hook on '${_HES_ENT_EV:-<nothing>}', not PreToolUse/PostToolUse. handoff-completion-assertion's (e6)-(e13) drive gate-then-entry on the strength of that registration"
  fi
  _HES_CTL="$(jq -r '.hooks | to_entries[] | select(.value[]?.hooks[]?.command // "" | test("ai-dlc-no-such-hook-141\\.sh")) | .key' "$_HES_TMPL" 2>/dev/null | head -1)"
  [ -z "$_HES_CTL" ] \
    && ok "HO2 (handoff-completion-assertion e6-order control): an impossible hook name resolves to no event, so the two readings above are real" \
    || bad "HO2 (handoff-completion-assertion e6-order control): an impossible hook name resolved to '$_HES_CTL' — the query matches anything and the order reading establishes nothing"
fi

echo ""
report_end schema-install-fallback
