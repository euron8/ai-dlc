#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
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
# LAST candidate. Each property of that sentence is an arm, and each arm has a mutant:
#   A  NO-SCHEMA ROOT   a foreign root holding only `.claude/` gives the SAME exit and output as
#                       the no-override control. Killed by deleting the install fallback (DEL).
#   B  ROOT WINS        a foreign root carrying an UNPARSEABLE schema makes the run non-zero, and
#                       its ALLOW twin — the same root carrying a VALID copy — exits 0, so the
#                       non-zero is the schema's doing. Killed by putting the install FIRST (IF).
#   C  LEGACY LAYOUT    a copy at `scripts/X` (the pre-relocation path) answers exactly as the
#                       `scripts/ai-dlc/X` copy under the same foreign root. Killed by a fallback
#                       that counts hops (`$SCRIPT_DIR/../..`) instead of walking up (HOP): right
#                       from `scripts/ai-dlc/`, one level too high from `scripts/`.
#   D  R1, write-format-steering only: under the foreign root it judges the SAME number of
#                       declaration rows as the control, not zero. The schema came from the install,
#                       so its `declared_in` paths are resolved against the install. Killed by
#                       handing the reader the override root instead (R1).
#   E  R2, sync-taught-schema only: WRITE mode under a foreign root that carries a stale generated
#                       region modifies neither that root's file nor the install's docs. The
#                       schemas install as a set, so the fallback branch renders the INSTALL's docs.
#                       Killed by leaving ROOT at the override (R2), which rewrites the foreign file.
#   M  R3, gate-adjudication only: a foreign root carrying its own enforcement-map.yaml is the map
#                       the escalated set is derived from. Killed by putting the install map first.
#   N  BL-326, gate-adjudication only: adjudicate mode reads `docs/escalations/pending.md` from the
#                       tree its enforcement map came from. Under a foreign root with no map (F) that
#                       is the INSTALL's docs, and — the near-miss — under a root carrying its own map
#                       (GE) it is GE's. Killed by reading the escalations from the override root
#                       again (ESC) and by always reading the install's (ESCI). IFMAP also fails N,
#                       legitimately: a root whose map is not chosen does not own the escalations.
#   P  BL-330, write-format-steering only: a foreign root carrying the steering schema but NOT the
#                       population schema (FP) owns the PAIR, so its missing half is the honest
#                       `SKIP — EXAMINED NOTHING` (rc 0), never the install's population joined to the
#                       root's steering and judged under the root (rc 1). B's Ggood, the root carrying
#                       the whole set, is the near-miss. Killed by falling back per FILE again
#                       (PERFILE). IF also fails P, legitimately: install-first never lets a root own it.
#   Q  BL-331, write-format-steering only, a standalone arm after E2: under the install fallback a
#                       root carrying its OWN declared file without the anchor exits 1 naming the
#                       root's copy, and the same root with the anchor passes at the control's row
#                       count. Killed by dropping the root resolution (NOROOT) and by failing any root
#                       that carries the file (ANCHORLESS); each leaves A-P at its base value.
#
# THE KILL IS THE WHOLE VECTOR. A mutant is killed only when every arm of the script it edits
# answers exactly as declared — its own arm(s) fail and the rest hold — so no kill is borrowed
# from an entangled arm. Two mutants legitimately fail two arms, and the vector says so: DEL on
# write-format-steering also leaves D with no count to compare, and R2 also moves A, because an
# override root whose docs are rendered answers --check about the wrong tree.
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
# Walk up for VERSION, never count hops. ROOT_DIR, not ROOT: this fixture reads no path the
# suite's content key excludes, and VERSION is only the marker the walk stops at.
ROOT_DIR="$HERE"
while [ "$ROOT_DIR" != "/" ] && [ ! -f "$ROOT_DIR/VERSION" ]; do ROOT_DIR="$(dirname "$ROOT_DIR")"; done
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

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

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
# The unmutated answer per script, over arms A B C D E M N P ('-' = the arm is not this script's).
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
mkdir -p "$BASE/t/_bmad" || exit 2
git init -q "$BASE/t" || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }
if ! bash "$INSTALL" "$BASE/t" </dev/null >"$WORK/install.log" 2>&1; then
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
for f in "$BASE/t/scripts/ai-dlc/"*.sh; do
  [ -f "$f" ] || continue
  cp "$f" "$BASE/t/scripts/" || exit 2
  n_legacy=$((n_legacy + 1))
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
# script's; or "BROKEN: <why>" when the unmutated control itself did not run.
vector() {
  local w="$1" s="$2" ctl fo lg gb gg a b c d="-" e="-" m="-" n="-" p="-" nc nf d0 i0 d1 i1 gm fp
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
  gb="$(drive "$w" ai "$s" "$w/Gbad-$s")"; gg="$(drive "$w" ai "$s" "$w/Ggood-$s")"
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

# --- the mutants ------------------------------------------------------------------------------
# Each edits a COPY of an installed script inside a copy of the WHOLE install tree, anchored on
# the fix's own lines, refused unless every anchor matched exactly once, and cmp-guarded.
MUTPY="$WORK/mut.py"
cat > "$MUTPY" <<'PY'
import re, sys
mode, src_path, dst_path = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(src_path).read()
def die(msg):
    sys.stderr.write("anchor: " + msg + "\n"); sys.exit(3)
def once(pat, flags=re.M):
    m = list(re.finditer(pat, src, flags))
    if len(m) != 1:
        die("%s matched %d times" % (pat[:60], len(m)))
    return m[0]
def lit(old, new, text):
    if text.count(old) != 1:
        die("literal %r found %d times" % (old[:60], text.count(old)))
    return text.replace(old, new)
if mode in ("DEL", "HOP"):
    # The install-root walk the candidate is built from. DEL empties it, so no candidate is added.
    # HOP replaces the walk with a fixed two-hop climb from the script's own directory.
    m = once(r'^(\w*INSTALL_ROOT)="\$\(ai_dlc_resolve_root "\$(\w+)" \|\| true\)"$')
    rep = m.group(1) + '=""' if mode == "DEL" else m.group(1) + '="$(cd "$' + m.group(2) + '/../.." && pwd)"'
    out = src[:m.start()] + rep + src[m.end():]
elif mode == "IF":
    if 'SCHEMA_DIR=""' in src:
        # write-format-steering resolves its schema pair by DIRECTORY; the install's goes first.
        out = lit(' \\\n          "${AI_DLC_INSTALL_ROOT:+$AI_DLC_INSTALL_ROOT/.claude/schemas}"; do', '; do', src)
        out = lit('for _d in "$AI_DLC_SELF_DIR/../schemas"',
                  'for _d in "${AI_DLC_INSTALL_ROOT:+$AI_DLC_INSTALL_ROOT/.claude/schemas}" "$AI_DLC_SELF_DIR/../schemas"', out)
    elif "GA_INSTALL_SCHEMA" in src:
        out = lit('schemas/gate-adjudication-verdict.json" \\\n        "$GA_INSTALL_SCHEMA"; do',
                  'schemas/gate-adjudication-verdict.json"; do', src)
        out = lit('        "$GA_ROOT/core/schemas/gate-adjudication-verdict.json" \\\n',
                  '        "$GA_INSTALL_SCHEMA" \\\n        "$GA_ROOT/core/schemas/gate-adjudication-verdict.json" \\\n', out)
    else:
        blk = once(r'^elif \[ -n "\$AI_DLC_INSTALL_ROOT" \] .*?(?=^(?:elif|else))', re.M | re.S)
        rest = src[:blk.start()] + src[blk.end():]
        first = list(re.finditer(r'^(if|elif) (\[ -f "\$SCRIPT_DIR/\.\./schemas/)', rest, re.M))
        if len(first) != 1:
            die("script-relative head matched %d times" % len(first))
        f = first[0]; b = blk.group(0)
        ins = ("if" + b[len("elif"):] if f.group(1) == "if" else b) + "elif " + f.group(2)
        out = rest[:f.start()] + ins + rest[f.end():]
elif mode == "IFMAP":
    out = lit('skills/ai-dlc/enforcement-map.yaml" \\\n        "$GA_INSTALL_MAP"; do', 'skills/ai-dlc/enforcement-map.yaml"; do', src)
    out = lit('        "$GA_ROOT/core/skills/ai-dlc/enforcement-map.yaml" \\\n',
              '        "$GA_INSTALL_MAP" \\\n        "$GA_ROOT/core/skills/ai-dlc/enforcement-map.yaml" \\\n', out)
elif mode == "R1":
    out = lit('  READER_ROOT="$AI_DLC_INSTALL_ROOT"\n', '  READER_ROOT="$AI_DLC_ROOT"\n', src)
elif mode == "R2":
    out = lit('    ROOT="$AI_DLC_INSTALL_ROOT"\n', '    ROOT="$AI_DLC_ROOT"\n', src)
elif mode == "ESC":
    # BL-326 reverted: the escalations are read from the override root whatever tree the map is from.
    out = lit('ESC="${AI_DLC_ESCALATIONS:-$GA_MAP_ROOT/', 'ESC="${AI_DLC_ESCALATIONS:-$GA_ROOT/', src)
elif mode == "PERFILE":
    # BL-330 reverted: the population schema falls back on its own, through every candidate
    # directory, whatever directory the steering schema came from.
    out = lit('[ -f "$SCHEMA_DIR/$POP_NAME" ] && POP="$SCHEMA_DIR/$POP_NAME"\n',
              'for _pd in "$AI_DLC_SELF_DIR/../schemas" "$AI_DLC_ROOT/core/schemas" "$AI_DLC_ROOT/.claude/schemas" '
              '"${AI_DLC_INSTALL_ROOT:+$AI_DLC_INSTALL_ROOT/.claude/schemas}"; do '
              '[ -n "$_pd" ] && [ -f "$_pd/$POP_NAME" ] && { POP="$_pd/$POP_NAME"; break; }; done\n', src)
elif mode == "ESCI":
    # Over-reach: the escalations always come from the install, even when the root's own map won.
    out = lit('GA_MAP_ROOT="$GA_ROOT"\n', 'GA_MAP_ROOT="$GA_INSTALL_ROOT"\n', src)
else:
    die("unknown mode " + mode)
open(dst_path, "w").write(out)
PY

# script:MODE:want — want over A B C D E M N P, exactly. DEL on gate-adjudication also fails N: with
# no install fallback the no-map root F finds no map at all, so there is no escalations path to read.
MUTANTS="
sprint-status:DEL:100----- sprint-status:IF:010----- sprint-status:HOP:001-----
validate-audit-anchors:DEL:100----- validate-audit-anchors:IF:010----- validate-audit-anchors:HOP:001-----
validate-write-format-steering:DEL:1001---0 validate-write-format-steering:IF:0100---1
validate-write-format-steering:HOP:0010---0 validate-write-format-steering:R1:0001---0
validate-write-format-steering:PERFILE:0000---1
sync-taught-schema:DEL:100-0--- sync-taught-schema:IF:010-0--- sync-taught-schema:HOP:001-0---
sync-taught-schema:R2:100-1---
validate-gate-adjudication:DEL:100--01- validate-gate-adjudication:IF:010--00-
validate-gate-adjudication:HOP:001--00- validate-gate-adjudication:IFMAP:000--11-
validate-gate-adjudication:ESC:000--01- validate-gate-adjudication:ESCI:000--01-
"

# world <name> <script or ""> <mode or COPY> -> writes the world; its .status says APPLIED or why not
build_world() {
  local w="$WORK/$1" s="$2" mode="$3" src dst
  mkdir -p "$w" && cp -R "$BASE/t" "$w/t" || { echo "DID NOT APPLY: copy of the install failed" > "$w/.status"; return 1; }
  if [ "$mode" != COPY ]; then
    src="$BASE/t/scripts/ai-dlc/$s.sh"; dst="$w/t/scripts/ai-dlc/$s.sh"
    if ! python3 "$MUTPY" "$mode" "$src" "$dst" 2>"$w/.err"; then
      echo "DID NOT APPLY: $(sed -n 1p "$w/.err")" > "$w/.status"; return 1
    fi
    if cmp -s "$src" "$dst"; then echo "DID NOT APPLY: identical to the installed $s.sh" > "$w/.status"; return 1; fi
    # The legacy copy is the same program, so it carries the same mutation.
    cp "$dst" "$w/t/scripts/$s.sh" || { echo "DID NOT APPLY: legacy copy failed" > "$w/.status"; return 1; }
  fi
  mk_roots "$w" || { echo "DID NOT APPLY: foreign roots not built" > "$w/.status"; return 1; }
  echo APPLIED > "$w/.status"
}

echo "schema-install-fallback"
echo "  install: $BASE/t (scripts/ai-dlc/ + $n_legacy legacy copies in scripts/)"
echo ""

# --- anchor control: every mutation refuses a file that carries none of the fix -------------
printf '#!/usr/bin/env bash\necho no fix here\n' > "$WORK/decoy.sh"
n_decoy=0; n_modes=0
for mode in DEL HOP IF IFMAP R1 R2 ESC ESCI PERFILE; do
  n_modes=$((n_modes + 1))
  python3 "$MUTPY" "$mode" "$WORK/decoy.sh" "$WORK/decoy.out" 2>/dev/null && n_decoy=$((n_decoy + 1))
done
[ "$n_decoy" -eq 0 ] && ok "mutants: all $n_modes mutation programs refuse a decoy carrying no anchor" \
                     || bad "mutants: $n_decoy mutation program(s) applied to a decoy — an anchor matches text that is not the fix"

# --- the unmutated install ------------------------------------------------------------------
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
base_ok=1
for s in $SCRIPTS; do
  got="$(vector "$BASE" "$s")"; want="$(want_base "$s")"
  if [ "$got" = "$want" ]; then
    ok "$s: A no-schema root = control, B root schema wins, C legacy layout agrees$(extra_arms "$s") ($got)"
  else
    bad "$s: vector $got, want $want (A B C D E M N P)"; base_ok=0
  fi
done

# --- mutants, in whole-tree copies, six at a time -------------------------------------------
echo ""
i=0; running=0
for spec in COPY $MUTANTS; do
  i=$((i + 1))
  (
    w="$WORK/m$i"
    if [ "$spec" = COPY ]; then
      build_world "m$i" "" COPY || exit 0
      for s in $SCRIPTS; do printf '%s %s\n' "$s" "$(vector "$w" "$s")"; done > "$w/.vec"
    else
      s="${spec%%:*}"; rest="${spec#*:}"; mode="${rest%%:*}"
      build_world "m$i" "$s" "$mode" || exit 0
      vector "$w" "$s" > "$w/.vec"
    fi
  ) &
  running=$((running + 1))
  if [ "$running" -ge 6 ]; then wait; running=0; fi
done
wait

# The unmutated COPY: the copy harness reproduces the base vectors, so a mutant verdict below is
# evidence about a subject that ran, not about a copy that broke.
if [ "$(cat "$WORK/m1/.status" 2>/dev/null)" != APPLIED ]; then
  bad "CONTROL: the unmutated whole-tree copy was not built — $(cat "$WORK/m1/.status" 2>/dev/null)"
else
  copy_bad=0
  for s in $SCRIPTS; do
    got="$(sed -n "s/^$s //p" "$WORK/m1/.vec")"
    [ "$got" = "$(want_base "$s")" ] || { copy_bad=1; bad "CONTROL: unmutated copy, $s vector ${got:-<none>}, want $(want_base "$s")"; }
  done
  [ "$copy_bad" -eq 0 ] && ok "CONTROL: an unmutated whole-tree copy reproduces every base vector"
fi

i=1; n_killed=0
for spec in $MUTANTS; do
  i=$((i + 1))
  s="${spec%%:*}"; rest="${spec#*:}"; mode="${rest%%:*}"; want="${rest#*:}"
  st="$(cat "$WORK/m$i/.status" 2>/dev/null)"
  label="MUTANT $mode on $s"
  if [ "$st" != APPLIED ]; then bad "$label: ${st:-no status written}"; continue; fi
  if [ "$base_ok" -ne 1 ]; then bad "$label: FIXTURE BROKEN — the unmutated vectors are wrong, so no kill is readable"; continue; fi
  got="$(cat "$WORK/m$i/.vec" 2>/dev/null)"
  if [ "$got" = "$want" ]; then ok "$label killed by its own arm(s) only ($got)"; n_killed=$((n_killed + 1))
  else bad "$label: vector ${got:-<none>}, want $want (A B C D E M N P)"; fi
done
[ "$n_killed" -gt 0 ] || bad "no mutant was killed — the arms were never shown to fire"

# --- E2 (BL-332): write mode under a foreign root REWRITES a stale region in the INSTALL ------
# Arm E seeds its stale region in the FOREIGN root only, and the install's docs are already in
# sync, so "the install's docs are unchanged" holds whether the fallback branch renders them or
# skips them — and E never reads the exit. Under R2 the fallback branch takes ROOT and DOC_DIRS
# from the install, so write mode over a stale install region must do exactly what a run with no
# override does: exit 0, rewrite the install's retro.md, leave the foreign decoy alone.
#   1. The seed is live: --check under the foreign root exits 1 naming steps/retro.md.
#   2. EXPECTED is DERIVED, not the shipped bytes: a no-override write of the same seed (that run
#      resolves the install's .claude/schemas/ branch, never the fallback, so no mutant here can
#      move it), asserted to differ from the seed so the comparison is not two no-ops.
#   3. Re-seeded, the foreign-root write exits 0, reports 1 file updated, produces EXPECTED byte
#      for byte, leaves the decoy's cksum alone, and --check then passes.
# Two mutants, both gated on write mode inside the fallback branch so A (check mode) cannot move:
#   SKIP  the install's doc dirs are dropped — exit 0, nothing written. An rc-only arm passes it.
#   R2W   the 0.645.0 answer — exit 1, nothing written.
# Each is shown to leave the whole A-E vector at its base value (E green) and to fail E2 alone.
bl332_mut() { # $1 SKIP|R2W|DECOY-CHECK  $2 src  $3 dst
  python3 - "$1" "$2" "$3" <<'PY'
import sys
mode, src_path, dst_path = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(src_path).read()
# Anchored on the fallback branch's own ROOT line, which the branch above it does not carry;
# its DOC_DIRS line is byte-identical to that branch's, so it is never the anchor on its own.
old = '    ROOT="$AI_DLC_INSTALL_ROOT"\n    DOC_DIRS=("$ROOT/.claude/skills" "$ROOT/.claude/team-roles")\n'
if src.count(old) != 1:
    sys.stderr.write("anchor: fallback ROOT/DOC_DIRS pair found %d times\n" % src.count(old)); sys.exit(3)
if mode == "SKIP":
    new = old + '    [ "$MODE" = sync ] && DOC_DIRS=("$ROOT/.sif-bl332-no-such-dir")\n'
elif mode == "R2W":
    new = old + '    [ "$MODE" = sync ] && { echo "sync-taught-schema: FAIL — BL-332 mutant" >&2; exit 1; }\n'
else:
    sys.stderr.write("anchor: unknown mode %s\n" % mode); sys.exit(3)
open(dst_path, "w").write(src.replace(old, new))
PY
}

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
  local m w st v e n_dec=0
  printf '#!/usr/bin/env bash\necho no fix here\n' > "$WORK/bl332-decoy.sh"
  for m in SKIP R2W; do bl332_mut "$m" "$WORK/bl332-decoy.sh" "$WORK/bl332-decoy.out" 2>/dev/null && n_dec=$((n_dec + 1)); done
  [ "$n_dec" -eq 0 ] && ok "E2 mutants: both BL-332 mutation programs refuse a decoy carrying no anchor" \
                     || bad "E2 mutants: $n_dec BL-332 mutation program(s) applied to a decoy"
  for m in NONE SKIP R2W; do
    (
      w="$WORK/e2-$m"
      mkdir -p "$w" && cp -R "$BASE/t" "$w/t" || { echo "DID NOT APPLY: copy of the install failed" > "$w/.status"; exit 0; }
      if [ "$m" != NONE ]; then
        bl332_mut "$m" "$BASE/t/scripts/ai-dlc/sync-taught-schema.sh" "$w/t/scripts/ai-dlc/sync-taught-schema.sh" 2>"$w/.err" \
          || { echo "DID NOT APPLY: $(sed -n 1p "$w/.err")" > "$w/.status"; exit 0; }
        cmp -s "$BASE/t/scripts/ai-dlc/sync-taught-schema.sh" "$w/t/scripts/ai-dlc/sync-taught-schema.sh" \
          && { echo "DID NOT APPLY: identical to the installed sync-taught-schema.sh" > "$w/.status"; exit 0; }
        cp "$w/t/scripts/ai-dlc/sync-taught-schema.sh" "$w/t/scripts/sync-taught-schema.sh" \
          || { echo "DID NOT APPLY: legacy copy failed" > "$w/.status"; exit 0; }
      fi
      mk_roots "$w" || { echo "DID NOT APPLY: foreign roots not built" > "$w/.status"; exit 0; }
      echo APPLIED > "$w/.status"
      # The vector first: once the install region is seeded, E's install checksum moves under a
      # CORRECT write too, so the order is part of the arm.
      vector "$w" sync-taught-schema > "$w/.vec"
      bl332_e2 "$w" > "$w/.e2"
    ) &
  done
  wait
  for m in NONE SKIP R2W; do
    w="$WORK/e2-$m"; st="$(cat "$w/.status" 2>/dev/null)"
    if [ "$st" != APPLIED ]; then bad "E2 $m: ${st:-no status written}"; continue; fi
    v="$(cat "$w/.vec" 2>/dev/null)"; e="$(cat "$w/.e2" 2>/dev/null)"
    case "$e" in "1 BROKEN"*) bad "E2 $m: FIXTURE BROKEN — ${e#1 }"; continue ;; esac
    if [ "$v" != "$(want_base sync-taught-schema)" ]; then
      bad "E2 $m: vector $v, want $(want_base sync-taught-schema) — a mutant moving A-E is entangled, not an E2 kill"; continue
    fi
    if [ "$m" = NONE ]; then
      [ "$e" = 0 ] && ok "E2 write mode under a foreign root rewrites a stale INSTALL retro.md region to the no-override render, decoy untouched" \
                   || bad "E2 write mode under a foreign root over a stale install region: ${e#1 }"
    else
      [ "${e%% *}" = 1 ] && ok "MUTANT $m on sync-taught-schema leaves A-E at $v and is killed by E2 alone (${e#1 })" \
                         || bad "MUTANT $m on sync-taught-schema: E2 held — the arm cannot see a skipped install region"
    fi
  done
}
bl332_stale_install_arm

# --- Q (BL-331): under the install fallback, the ROOT's copy of a declared file is judged too ---
# Arm D resolves every `declared_in` against the install once the schema pair came from there, so a
# root carrying its OWN copy of a declared file with the anchor gone was acquitted: the install's
# intact copy was judged and the root's stale one never read (measured: rc 0 `PASS — 5 of 20`,
# byte-for-byte the no-override answer, where the distribution layout exits 1 on the same root).
# The root holds no .claude/schemas, so the fallback branch is the one taken, in the consumer layout.
#   STALE root  its reconcile/lib.sh lacks `function ledger_entry_shape(` -> rc 1 and a STALE finding
#               naming the ROOT's lib.sh. Killed by dropping the root resolution (NOROOT).
#   INTACT root the same file WITH its anchor -> rc 0, `PASS —`, and the control's declaration-row
#               count, so the root side adds findings only, never a row. Killed by failing any root
#               that merely CARRIES the file (ANCHORLESS). F, the bare root, is arm A and holds.
# Each mutant must leave the A-P vector at its base value, so the kill is Q's alone.
bl331_mut() { # $1 NOROOT|ANCHORLESS  $2 src  $3 dst
  python3 - "$1" "$2" "$3" <<'PY'
import sys
mode, src_path, dst_path = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(src_path).read()
if mode == "NOROOT":
    old, new = 'ALSO_ROOT="$AI_DLC_ROOT"', 'ALSO_ROOT=""'
elif mode == "ANCHORLESS":
    old, new = 'if anchor not in rbody:', 'if True:'
else:
    sys.stderr.write("anchor: unknown mode %s\n" % mode); sys.exit(3)
if src.count(old) != 1:
    sys.stderr.write("anchor: %r found %d times\n" % (old, src.count(old))); sys.exit(3)
open(dst_path, "w").write(src.replace(old, new))
PY
}

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
  local m w st v q n_dec=0
  printf '#!/usr/bin/env bash\necho no fix here\n' > "$WORK/bl331-decoy.sh"
  for m in NOROOT ANCHORLESS; do bl331_mut "$m" "$WORK/bl331-decoy.sh" "$WORK/bl331-decoy.out" 2>/dev/null && n_dec=$((n_dec + 1)); done
  [ "$n_dec" -eq 0 ] && ok "Q mutants: both BL-331 mutation programs refuse a decoy carrying no anchor" \
                     || bad "Q mutants: $n_dec BL-331 mutation program(s) applied to a decoy"
  for m in NONE NOROOT ANCHORLESS; do
    (
      w="$WORK/q-$m"
      mkdir -p "$w" && cp -R "$BASE/t" "$w/t" || { echo "DID NOT APPLY: copy of the install failed" > "$w/.status"; exit 0; }
      if [ "$m" != NONE ]; then
        bl331_mut "$m" "$BASE/t/scripts/ai-dlc/validate-write-format-steering.sh" "$w/t/scripts/ai-dlc/validate-write-format-steering.sh" 2>"$w/.err" \
          || { echo "DID NOT APPLY: $(sed -n 1p "$w/.err")" > "$w/.status"; exit 0; }
        cmp -s "$BASE/t/scripts/ai-dlc/validate-write-format-steering.sh" "$w/t/scripts/ai-dlc/validate-write-format-steering.sh" \
          && { echo "DID NOT APPLY: identical to the installed validate-write-format-steering.sh" > "$w/.status"; exit 0; }
        cp "$w/t/scripts/ai-dlc/validate-write-format-steering.sh" "$w/t/scripts/validate-write-format-steering.sh" \
          || { echo "DID NOT APPLY: legacy copy failed" > "$w/.status"; exit 0; }
      fi
      mk_roots "$w" || { echo "DID NOT APPLY: foreign roots not built" > "$w/.status"; exit 0; }
      echo APPLIED > "$w/.status"
      vector "$w" validate-write-format-steering > "$w/.vec"
      bl331_q "$w" > "$w/.q"
    ) &
  done
  wait
  for m in NONE NOROOT ANCHORLESS; do
    w="$WORK/q-$m"; st="$(cat "$w/.status" 2>/dev/null)"
    if [ "$st" != APPLIED ]; then bad "Q $m: ${st:-no status written}"; continue; fi
    v="$(cat "$w/.vec" 2>/dev/null)"; q="$(cat "$w/.q" 2>/dev/null)"
    case "$q" in BROKEN*) bad "Q $m: FIXTURE BROKEN — ${q#BROKEN: }"; continue ;; esac
    if [ "$v" != "$(want_base validate-write-format-steering)" ]; then
      bad "Q $m: vector $v, want $(want_base validate-write-format-steering) — a mutant moving A-P is entangled, not a Q kill"; continue
    fi
    case "$m:$q" in
      NONE:00)       ok "Q a stale root lib.sh under the install fallback exits 1 naming the root's copy; the intact root passes with the control's row count" ;;
      NONE:*)        bad "Q stale/intact root under the install fallback: $q, want 00 (a stale root is acquitted, or an intact one fails)" ;;
      NOROOT:10)     ok "MUTANT NOROOT on validate-write-format-steering leaves A-P at $v and is killed by Q's stale arm alone" ;;
      ANCHORLESS:01) ok "MUTANT ANCHORLESS on validate-write-format-steering leaves A-P at $v and is killed by Q's intact arm alone" ;;
      *)             bad "MUTANT $m on validate-write-format-steering: Q $q, want $( [ "$m" = NOROOT ] && echo 10 || echo 01)" ;;
    esac
  done
}
bl331_arm

echo ""
if [ "$fails" -eq 0 ]; then
  echo "schema-install-fallback: PASS ($n_killed mutant(s) killed)"
  exit 0
fi
echo "schema-install-fallback: FAIL ($fails assertion(s))"
exit 1
