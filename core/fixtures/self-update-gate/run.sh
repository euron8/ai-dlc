#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# Exercise reconcile/self-update-gate.sh.
#
# THE DIFFERENTIAL IS THE WHOLE MECHANISM. `gate-defer`, `gate-broken` and `gate-agree` all exit
# non-zero on the incoming side. A gate reading the incoming exit code alone calls them the same
# thing — and calling a pre-existing failure a "defer" strands the machinery slice for a reason
# unrelated to the pull. Only comparing against the consumer's CURRENT copy separates a new finding
# from an old one, and the mutation below removes exactly that comparison.
#
# The three then split by what the comparison SAYS: 0 -> 1 is a new finding (DEFER), 1 -> 1 is
# agreement and therefore no signal at all (OK, v0.297.0), 1 -> 2 is a real change nobody can
# attribute (UNDECIDED).
set -u
# HERMETIC (I10): the gate reads AI_DLC_* tunables (e.g. AI_DLC_GATE_IN_SAFE_STOP in
# gate_record_open), so an operator's exported value would change what every cell measures.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
DIR="$(cd "$(dirname "$0")" && pwd)"

GATE=""; LOOKED=""
for cand in \
  "$DIR/../../skills/ai-dlc-update/reconcile/self-update-gate.sh" \
  "$DIR/../../../core/skills/ai-dlc-update/reconcile/self-update-gate.sh" \
  "$DIR/../../../.claude/skills/ai-dlc-update/reconcile/self-update-gate.sh"; do
  LOOKED="$LOOKED  $cand
"
  [ -f "$cand" ] && GATE="$cand" && break
done
[ -n "$GATE" ] || { printf 'FAIL: cannot locate self-update-gate.sh from %s. Looked in:\n%s' "$DIR" "$LOOKED"; exit 1; }
# Reached only once the gate resolved; its whole directory is the input, because the gate sources
# preclassify.sh and setup-sites.md beside itself and the arms below read two more siblings.
echo "HERMETIC-CONSUMED $(cd "$(dirname "$GATE")" && pwd -P)/"

# ---------------------------------------------------------------------------- shards ----
# THIS FILE IS FOUR SHARDS OF ONE FIXTURE, AND THE SPLIT IS A SCHEDULING BOUNDARY, NOT A SUBJECT
# BOUNDARY. Every section below is a UNIT guarded by `if sg <unit>; then ... fi`; `--group <x>` runs
# the units dealt to shard <x>. The three siblings `self-update-gate-{b,c,d}/run.sh` are one-line
# drivers that `exec bash` this file with their group (the check-24 shape), so the pre-push pool can
# start each on its own and the suite's makespan stops tracking one 4700-line directory. No `--group`
# runs shard 'a', so `bash core/fixtures/self-update-gate/run.sh` is shard a.
#
# THE SEED, THE GATE LOOKUP, THE SAFE-STOP WORLD AND THE HELPERS MORE THAN ONE UNIT CALLS ARE NOT
# UNITS: every shard pays them, because a shard that skipped them would score its cases against a
# harness that never ran. `hu` is two units (hu1, hu2) over ONE set of worlds, built under a compound
# guard that the coverage join deliberately does not read as a unit.
#
# THE COVERAGE JOIN runs in EVERY shard before anything else: the declared units are DERIVED from this
# file's own `if sg <unit>; then` lines, the dealt lists must be disjoint and their union must equal the
# declared set exactly, so no unit can fall out of every shard, and every declared shard must have a
# driver directory. The join proves it can fire first, on a seeded duplicate and a seeded omission.
#   a  base ss sc ac su pp stg  the seed rows and the differential mutant, --safe-stop and its stamp and marker
#                         arms, arm C's carry refusal and its mutants, arm C, arm D's preclassify, the push-hook layouts, the staging-write refusal
#   b  vr pl hu1 sh       the verdict record, the pre-written miniature, the unchanged-script hook
#                         worlds and the first half of their mutants, the hook shapes the scan must not misread
#   c  pu hu2             the push wrapper (self-update-push.sh), the second half of the hook-world
#                         mutants and the real-hook depth probe
#   d  qw mp hk av        the quoting cells, the failed-producer worlds, the hook-the-push-runs worlds,
#                         the hook's own argv and the remedy
SHARDS="a b c d"
UNITS_a="base ss sc ac su pp stg"
UNITS_b="vr pl hu1 sh"
UNITS_c="pu hu2"
UNITS_d="qw mp hk av"
GROUP=a
if [ "${1:-}" = "--group" ]; then
  GROUP="${2:-}"
  [ -n "$GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; }
fi
case " $SHARDS " in
  *" $GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;;
esac
eval "MINE=\"\${UNITS_$GROUP:-}\""
NAME="self-update-gate"; [ "$GROUP" = a ] || NAME="self-update-gate-$GROUP"
broken() { printf '  FAIL  %s\n' "$1" >&2; echo "$NAME: FIXTURE BROKEN" >&2; exit 2; }
[ -n "$MINE" ] || broken "shard '$GROUP' has no UNITS_$GROUP list; a shard dealt nothing passes everything it never checked"
sg() { case " $MINE " in *" $1 "*) return 0 ;; esac; return 1; }
SELF="$0"
[ -f "$SELF" ] || broken "cannot read $SELF for the coverage join"
partition_ok() { # <declared ids file> <dealt ids file> -> 0 when dealt is disjoint and covers declared exactly
  local dup miss extra
  dup="$(sort "$2" | uniq -d | tr '\n' ' ')"
  miss="$(sort -u "$2" | comm -23 <(sort -u "$1") - | tr '\n' ' ')"
  extra="$(sort -u "$2" | comm -13 <(sort -u "$1") - | tr '\n' ' ')"
  [ -z "$dup$miss$extra" ] && return 0
  echo "dealt twice: {${dup% }} dealt to no shard: {${miss% }} dealt but not declared: {${extra% }}"
  return 1
}
JW="$(mktemp -d "${TMPDIR:-/tmp}/sug-join.XXXXXX")" || broken "mktemp failed"
printf '%s\n' u1 u2 u3 > "$JW/pd"; printf '%s\n' u1 u2 u2 u3 > "$JW/pdup"; printf '%s\n' u1 u3 > "$JW/pmiss"; printf '%s\n' u3 u1 u2 > "$JW/pok"
if partition_ok "$JW/pd" "$JW/pdup" >/dev/null || partition_ok "$JW/pd" "$JW/pmiss" >/dev/null \
   || ! partition_ok "$JW/pd" "$JW/pok" >/dev/null; then
  rm -rf "$JW"; broken "the coverage join's self-probe did not discriminate (duplicate, omission, exact)"
fi
sed -n 's/^[[:space:]]*if sg \([a-z0-9_][a-z0-9_]*\); then$/\1/p' "$SELF" > "$JW/declared"
for _s in $SHARDS; do eval "printf '%s\n' \${UNITS_$_s}" | tr ' ' '\n'; done | grep . > "$JW/dealt"
ndecl="$(grep -c . "$JW/declared")" || ndecl=0
ndupdecl="$(sort "$JW/declared" | uniq -d | grep -c .)" || ndupdecl=0
if [ "$ndecl" -eq 0 ] || [ "$ndupdecl" -ne 0 ]; then
  rm -rf "$JW"; broken "$ndecl unit guards derived from $SELF ($ndupdecl declared twice)"
fi
if ! _why="$(partition_ok "$JW/declared" "$JW/dealt")"; then
  rm -rf "$JW"; broken "the shard partition does not cover the guarded units exactly -- $_why"
fi
for _s in $SHARDS; do
  [ "$_s" = a ] && continue
  _drv="$DIR/../self-update-gate-$_s/run.sh"
  if [ ! -f "$_drv" ] || ! grep -qF -- "--group $_s" "$_drv"; then
    rm -rf "$JW"; broken "shard '$_s' is declared but $_drv does not drive it"
  fi
done
rm -rf "$JW"
echo "  [J0] coverage join: $ndecl units derived from the sg guards, dealt disjointly across {$SHARDS}, union exact; this shard runs {$MINE}"

read -r DIST BASE THEIRS CONS < <(bash "$DIR/seed.sh")
trap 'rm -rf "$(dirname "$DIST")"' EXIT
FAILURES=0
ASSERTIONS=0
echo "self-update-gate fixture"
echo

SS="$(dirname "$DIST")/ss"; rm -rf "$SS"
mkdir -p "$SS/dist/core/skills/ai-dlc/steps" "$SS/cons/.claude/skills/ai-dlc/steps" "$SS/dist/core/rules"
gvv() { printf '# gate\n'; for a in "$@"; do printf '<!-- CHECK_LOADED: %s -->\n' "$a"; done; }
gvv 1 2 > "$SS/cons/.claude/skills/ai-dlc/steps/gate-validation.md"
# The consumer's hook is the authority on what can block ITS push, and its ABSENCE is
# UNDECIDED, not OK — correctly, since a gate that cannot see the hook cannot say what the
# self-update would install. Without this the whole section ran on UNDECIDED and two arms
# passed for a reason unrelated to what they assert; the precondition arms below exist
# because that is exactly what happened.
mkdir -p "$SS/cons/.githooks"
printf '#!/usr/bin/env bash\n# invokes no scripts/ai-dlc/ validator, so the gating set is empty\nexit 0\n' > "$SS/cons/.githooks/pre-push"
git -C "$SS/dist" init -q
printf '1.0.0\n' > "$SS/dist/VERSION"; gvv 1 2 > "$SS/dist/core/skills/ai-dlc/steps/gate-validation.md"
# ONE MACHINERY PATH, NEVER TOUCHED AGAIN, AND IT IS A PRECONDITION RATHER THAN DECORATION. Arm C
# now resolves its population by `eval`ing `machinery_paths()` out of preclassify.sh, and reports
# SELF-UPDATE-UNDECIDED when that set comes back EMPTY -- correctly, since a membership test over
# an empty set rejects every path and its silence is byte-identical to a clean pull. A dist tree
# holding only VERSION and a rulebook file resolves to nothing, so without this file every arm
# below runs against an UNDECIDED verdict it never asked for. Unchanged across all five commits,
# so it enters no base..theirs diff and produces no bucket and no CARRY row of its own.
printf 'ss machinery\n' > "$SS/dist/core/rules/ss.md"
git -C "$SS/dist" add -A >/dev/null 2>&1; git -C "$SS/dist" -c user.email=f@x -c user.name=f commit -qm base >/dev/null 2>&1
SS_BASE="$(git -C "$SS/dist" rev-parse HEAD)"
# r1 — a release that moves VERSION and nothing the consumer's rulebook is joined against.
printf '1.1.0\n' > "$SS/dist/VERSION"
git -C "$SS/dist" add -A >/dev/null 2>&1; git -C "$SS/dist" -c user.email=f@x -c user.name=f commit -qm r1 >/dev/null 2>&1
SS_R1="$(git -C "$SS/dist" rev-parse HEAD)"
# r2 — a release that declares a check anchor the consumer's rulebook does not carry (ARM R1).
printf '1.2.0\n' > "$SS/dist/VERSION"; gvv 1 2 3 > "$SS/dist/core/skills/ai-dlc/steps/gate-validation.md"
git -C "$SS/dist" add -A >/dev/null 2>&1; git -C "$SS/dist" -c user.email=f@x -c user.name=f commit -qm r2 >/dev/null 2>&1
SS_R2="$(git -C "$SS/dist" rev-parse HEAD)"
# r3 — the coupling is gone again, so base→r3 is a CLEAN single hop even though base→r2 is not.
# This is the shape that proves the walk evaluates every candidate instead of stopping at the
# first defer: r3 lands strictly more than r1 and an early-stopping walk can never name it.
printf '1.3.0\n' > "$SS/dist/VERSION"; gvv 1 2 > "$SS/dist/core/skills/ai-dlc/steps/gate-validation.md"
git -C "$SS/dist" add -A >/dev/null 2>&1; git -C "$SS/dist" -c user.email=f@x -c user.name=f commit -qm r3 >/dev/null 2>&1
SS_R3="$(git -C "$SS/dist" rev-parse HEAD)"
# d3 — a NON-release commit after the last clean release, and the only reason it exists.
# The candidate set is release commits because the stamp records a VERSION, so a mid-release
# stop is not a state a consumer can hold. Without a commit that is clean, later than r3 and
# NOT a release, "candidates are releases" and "candidates are all commits" pick the same ref
# and the property is untestable — a mutation widening the candidate set came back green until
# this commit existed.
printf 'docs only, no VERSION change\n' > "$SS/dist/NOTES.md"
git -C "$SS/dist" add -A >/dev/null 2>&1; git -C "$SS/dist" -c user.email=f@x -c user.name=f commit -qm d3 >/dev/null 2>&1
# r4 — THEIRS. Needed so r3 is an INTERMEDIATE candidate rather than the target itself.
printf '1.4.0\n' > "$SS/dist/VERSION"; gvv 1 2 3 4 > "$SS/dist/core/skills/ai-dlc/steps/gate-validation.md"
git -C "$SS/dist" add -A >/dev/null 2>&1; git -C "$SS/dist" -c user.email=f@x -c user.name=f commit -qm r4 >/dev/null 2>&1
SS_R4="$(git -C "$SS/dist" rev-parse HEAD)"

ss_assert() { # ss_assert <label> <got> <want> <why>
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ "$2" = "$3" ]; then printf '  ok    %-16s %s\n' "$1" "$4"
  else FAILURES=$((FAILURES + 1)); printf '  FAIL  %-16s got=[%s] want=[%s]  %s\n' "$1" "$2" "$3" "$4"; fi
}
ss_stamp() { # ss_stamp <skill_commit|-> ; `-` removes the stamp
  if [ "$1" = "-" ]; then rm -f "$SS/cons/.claude/.ai-dlc-version"
  else printf 'version: 1.0.0\ncommit: %s\nskill_version: 1.1.0\nskill_commit: %s\n' "$SS_BASE" "$1" \
         > "$SS/cons/.claude/.ai-dlc-version"; fi
}
ss_marker() { # ss_marker on|off -- the interrupted-apply marker on the seeded consumer
  if [ "$1" = on ]; then : > "$SS/cons/.claude/.ai-dlc-applying"
  else rm -f "$SS/cons/.claude/.ai-dlc-applying"; fi
}
# ss_ack <gate> <theirs> -> "row=<0|1> acq=<n> wh=<n> pf=<n>" off the SAFE-STOP row's DETAIL.
#
# `pf` KEYS ON "its slice self-updates cleanly", NOT ON "pull to ... FIRST". The withheld wording
# opens with that same phrase on purpose -- it is still telling the operator to pull first -- so
# the shorter token cannot separate the withheld row from the untouched one and arm C, whose
# whole job is that separation, would have passed against a guard sited anywhere.
ss_ack() {
  local d
  d="$(bash "$1" "$SS/dist" "$SS_BASE" "$2" "$SS/cons" 2>&1 |
         awk -F'\t' '$1=="SELF-UPDATE-SAFE-STOP" {print $3; exit}')"
  printf 'row=%s acq=%s wh=%s pf=%s\n' \
    "$([ -n "$d" ] && printf 1 || printf 0)" \
    "$(printf '%s' "$d" | grep -c 'SPLIT BUYS NOTHING')" \
    "$(printf '%s' "$d" | grep -c 'ACQUITTAL IS WITHHELD')" \
    "$(printf '%s' "$d" | grep -c 'its slice self-updates cleanly')"
}
SU_PC="$(dirname "$GATE")/preclassify.sh"
su_carry() { printf '%s\n' "$1" | awk -F'\t' '$1 == "SELF-UPDATE-CARRY" {print $2}' | sort | tr '\n' ','; }
VR="$(dirname "$DIST")/vr"
rm -rf "$VR"; mkdir -p "$VR"
vr_cons() { # vr_cons <name> -> a fresh consumer copy with an EMPTY record directory
  rm -rf "$VR/$1"
  cp -R "$CONS" "$VR/$1"
  rm -rf "$VR/$1/_bmad-output"
  printf '%s\n' "$VR/$1"
}
vr_dir() { printf '%s\n' "$1/_bmad-output/ai-dlc-update"; }
vr_n() { # vr_n <consumer> -> how many record files exist
  local n
  n="$(ls "$(vr_dir "$1")"/self-update-gate-*.md 2>/dev/null | grep -c .)" || n=0
  printf '%s\n' "$n"
}
vr_newest() { ls -t "$(vr_dir "$1")"/self-update-gate-*.md 2>/dev/null | head -1; }
# TRAILERS, NOT FILES, IS THE COUNT THAT SURVIVES THE FILENAME COLLISION. The record's name
# carries a whole-second timestamp, so a nested invocation firing inside the same second reuses
# the name and TRUNCATES the top-level's record instead of adding a file -- one file, two
# `# verdict:` lines, and a file count of 1 that reads exactly like the guard working. This is
# the observable the nested-write mutant below is scored on for that reason.
vr_trailers() {
  local n
  n="$(cat "$(vr_dir "$1")"/self-update-gate-*.md 2>/dev/null | grep -c '^# verdict:')" || n=0
  printf '%s\n' "$n"
}
vr_in() { sed -n 's/^# input: //p' "${1:-/dev/null}"; }
vr_in_h() { vr_in "$1" | awk -F'\t' -v p="$2" '$1 == p {print $2; exit}'; }
vr_in_c() { vr_in "$1" | awk -F'\t' -v p="$2" '$1 == p {print $3; exit}'; }
vr_mut() { # vr_mut <name> <awk-program> -> path to the mutated gate, siblings beside it
  local d="$VR/m-$1"
  rm -rf "$d"; mkdir -p "$d"
  cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$d"/ 2>/dev/null
  awk "$2" "$GATE" > "$d/self-update-gate.sh" 2>/dev/null
  printf '%s\n' "$d/self-update-gate.sh"
}
mp_killed() { # mp_killed <label> <got> <want> <why> -- a mutant whose engine could not be built is a FAIL
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ "$2" = "$3" ]; then printf '  ok    %-16s KILLED (%s)\n' "$1" "$4"
  else FAILURES=$((FAILURES + 1)); printf '  FAIL  %-16s SURVIVED or DID NOT APPLY: got [%s], want [%s]\n' "$1" "$2" "$3"; fi
}
AV="$(mktemp -d "${TMPDIR:-/tmp}/su-gate-av.XXXXXX")"
av_git() { git -C "$1" -c user.email=f@x -c user.name=f -c commit.gpgsign=false "${@:2}"; }
# av_render <file> <body> <comment> -- a renderer-shaped stub: bare exits 2, --root writes the body,
# --check --root compares it.
av_render() {
  { printf '#!/usr/bin/env bash\n# %s\n' "$3"
    printf 'm=w; r=""\nwhile [ $# -gt 0 ]; do\n  case "$1" in --check) m=c ;; --root) shift; r="${1:-}" ;; *) exit 2 ;; esac\n  shift\ndone\n'
    printf '[ -n "$r" ] || exit 2\nb=%s\n' "'$2'"
    printf 'if [ "$m" = w ]; then mkdir -p "$r/.claude/agents" && printf "%%s\\n" "$b" > "$r/.claude/agents/dev.md"; exit; fi\n'
    printf '[ "$(cat "$r/.claude/agents/dev.md" 2>/dev/null)" = "$b" ] || exit 1\n'; } > "$1"
}
# av_scripts <dir> <side:base|theirs> <kind:A|B>
av_scripts() {
  local d="$1"
  mkdir -p "$d"
  if [ "$2" = theirs ] && [ "$3" = A ]; then
    av_render "$d/render-agent-definitions.sh" 'FIRST action, before any other work.' 'renderer stub'
  elif [ "$2" = theirs ]; then
    av_render "$d/render-agent-definitions.sh" 'FIRST action before any other work.' 'renderer stub; reworded'
  else
    av_render "$d/render-agent-definitions.sh" 'FIRST action before any other work.' 'renderer stub'
  fi
  if [ "$2" = theirs ] && [ "$3" = A ]; then
    printf '#!/bin/sh\ncase "${1:-}" in --fail-on=deterministic) exit 1 ;; *) exit 1 ;; esac\n' > "$d/audit-rule-files.sh"
    printf '#!/bin/sh\nexit 1\n' > "$d/derive-fixture-readsets.sh"
    printf '#!/bin/sh\n[ "${1:-}" = --trunk-push ] || exit 2\ngrep -q refs/heads/ && exit 1\nexit 0\n' > "$d/validate-audit-anchors.sh"
    printf '#!/bin/sh\n# reworded\n. "$(dirname "$0")/artifact-path-config.sh" || exit 2\nexit "$APC_RC"\n' > "$d/validate-artifact-paths.sh"
    printf 'APC_RC=1\n' > "$d/artifact-path-config.sh"
    printf '#!/bin/sh\n# reworded\nexit 0\n' > "$d/validate-rooted.sh"
    printf '#!/bin/sh\n# reworded\n[ "${1:-}" = --strays ] || exit 2\nexit 0\n' > "$d/validate-quiet.sh"
  else
    printf '#!/bin/sh\ncase "${1:-}" in --fail-on=deterministic) exit 0 ;; *) exit 1 ;; esac\n' > "$d/audit-rule-files.sh"
    printf '#!/bin/sh\nexit 0\n' > "$d/derive-fixture-readsets.sh"
    printf '#!/bin/sh\n[ "${1:-}" = --trunk-push ] || exit 2\ncat > /dev/null\nexit 0\n' > "$d/validate-audit-anchors.sh"
    printf '#!/bin/sh\n. "$(dirname "$0")/artifact-path-config.sh" || exit 2\nexit "$APC_RC"\n' > "$d/validate-artifact-paths.sh"
    printf 'APC_RC=0\n' > "$d/artifact-path-config.sh"
    printf '#!/bin/sh\nexit 0\n' > "$d/validate-rooted.sh"
    printf '#!/bin/sh\n[ "${1:-}" = --strays ] || exit 2\nexit 0\n' > "$d/validate-quiet.sh"
  fi
}
# av_world <dir> <kind:A|B> <consumer:clean|drift> -> <dir>/{dist,cons,B,T}
av_world() {
  local w="$1"
  mkdir -p "$w/dist/core/rules" "$w/cons/.githooks"
  git -C "$w/dist" init -q
  printf '1.0.0\n' > "$w/dist/VERSION"
  printf 'av machinery\n' > "$w/dist/core/rules/av.md"
  av_scripts "$w/dist/core/scripts" base "$2"
  av_git "$w/dist" add -A >/dev/null 2>&1; av_git "$w/dist" commit -qm base >/dev/null 2>&1
  git -C "$w/dist" rev-parse HEAD > "$w/B"
  printf '1.1.0\n' > "$w/dist/VERSION"
  av_scripts "$w/dist/core/scripts" theirs "$2"
  av_git "$w/dist" add -A >/dev/null 2>&1; av_git "$w/dist" commit -qm theirs >/dev/null 2>&1
  git -C "$w/dist" rev-parse HEAD > "$w/T"
  av_scripts "$w/cons/scripts/ai-dlc" base "$2"
  { printf '#!/usr/bin/env bash\nset -uo pipefail\nPUSH_REFS=""\n[ -t 0 ] || PUSH_REFS="$(cat)"\n'
    printf 'trunk_push() { printf '"'%%s'"' "$PUSH_REFS" | bash scripts/ai-dlc/validate-audit-anchors.sh --trunk-push; }\n'
    printf 'if [ -f scripts/ai-dlc/validate-audit-anchors.sh ]; then trunk_push; fi\n'
    printf 'if [ -f scripts/ai-dlc/audit-rule-files.sh ]; then\n  bash scripts/ai-dlc/audit-rule-files.sh --fail-on=deterministic\nfi\n'
    printf 'if [ -f scripts/ai-dlc/validate-artifact-paths.sh ]; then\n  bash scripts/ai-dlc/validate-artifact-paths.sh\nfi\n'
    printf 'bash scripts/ai-dlc/validate-rooted.sh --root "$ROOT"\n'
    printf 'bash scripts/ai-dlc/validate-quiet.sh --strays 2>"$LOG"\n'
    printf 'if [ -f scripts/ai-dlc/render-agent-definitions.sh ]; then\n  agent_definitions() {\n    local out rc\n'
    printf '    if [ ! -d .claude/agents ]; then\n      out="$(bash scripts/ai-dlc/render-agent-definitions.sh --root . 2>&1)"\n    fi\n'
    printf '    out="$(bash scripts/ai-dlc/render-agent-definitions.sh --check --root . 2>&1)"; rc=$?\n'
    printf '    case "$rc" in 0|3) return 0 ;; *) return 1 ;; esac\n  }\n  agent_definitions\nfi\n'
    printf 'readset_deriver_path() {\n  local c\n'
    printf '  for c in scripts/ai-dlc/derive-fixture-readsets.sh core/scripts/derive-fixture-readsets.sh; do\n'
    printf '    [ -f "$c" ] && { printf '"'%%s'"' "$c"; return 0; }\n  done\n}\n'; } > "$w/cons/.githooks/pre-push"
  chmod +x "$w/cons/.githooks/pre-push"
  bash "$w/cons/scripts/ai-dlc/render-agent-definitions.sh" --root "$w/cons" >/dev/null 2>&1
  [ "$3" = drift ] && printf 'a hand edit\n' > "$w/cons/.claude/agents/dev.md"
  # A COMMITTED BRANCH, NO REMOTE: the ref line can be formed, and arm P is skipped -- the state in
  # which the differential must still build its own stdin.
  git -C "$w/cons" init -q
  av_git "$w/cons" add -A >/dev/null 2>&1; av_git "$w/cons" commit -qm consumer >/dev/null 2>&1
}
# av_run <gate> <world> -> the gate's rows, against a FRESH copy of the world's consumer, then an
# `AGENTS same|moved` row for that copy's .claude/agents across the run. FRESH BY `mktemp -d`, never
# by a counter: av_run is called inside `$( )`, where a counter's increment is lost, and a reused
# copy hands one mutant's writes to the next run -- measured, a write-mode mutant's rendered
# definitions turned four later kills into the same wrong row.
av_run() {
  local c a0
  c="$(mktemp -d "$AV/run.XXXXXX")" || return 1
  c="$c/cons"
  cp -R "$2/cons" "$c" || return 1
  a0="$(cat "$c/.claude/agents/"* | cksum)"
  bash "$1" "$2/dist" "$(cat "$2/B")" "$(cat "$2/T")" "$c" 2>/dev/null
  if [ "$a0" = "$(cat "$c/.claude/agents/"* | cksum)" ]; then printf 'AGENTS\tsame\n'; else printf 'AGENTS\tmoved\n'; fi
}
av_st() { printf '%s\n' "$1" | awk -F'\t' -v s="$2" '$2 == s {print $1; exit}'; }
av_has() { printf '%s\n' "$1" | awk -F'\t' -v s="$2" -v re="$3" '$2 == s && $3 ~ re {f=1} END{print (f ? "yes" : "no")}'; }
av_ag() { printf '%s\n' "$1" | awk -F'\t' '$1 == "AGENTS" {print $2}'; }
av_ref() { printf '%s\n' "$1" | awk -F'\t' '$1 ~ /^SELF-UPDATE-(DEFER|UNDECIDED)$/' | grep -c .; }
# av_sig <rows> -> the whole world-A signature, one token per script
av_sig() {
  printf 'render=%s audit=%s derive=%s anchors=%s paths=%s rooted=%s quiet=%s agents=%s\n' \
    "$(av_st "$1" render-agent-definitions.sh)" "$(av_st "$1" audit-rule-files.sh)" \
    "$(av_st "$1" derive-fixture-readsets.sh)" "$(av_st "$1" validate-audit-anchors.sh)" \
    "$(av_st "$1" validate-artifact-paths.sh)" "$(av_st "$1" validate-rooted.sh)" \
    "$(av_st "$1" validate-quiet.sh)" "$(av_ag "$1")"
}
av_rc() { ( cd "$1" && bash "$2" ${3:+$3} >/dev/null 2>&1 < /dev/null ); printf '%s' "$?"; }
# av_mut <name> <old> <new> [<old> <new>]... -> the mutated gate's path, or nothing when an anchor
# is not unique, the copy is unchanged, or it is not a program.
av_mut() {
  local e="$AV/m-$1" mrc=0
  shift
  rm -rf "$e"; mkdir -p "$e"
  cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$e"/ 2>/dev/null
  [ "$#" -gt 0 ] || { printf '%s' "$e/self-update-gate.sh"; return 0; }
  python3 -c 'import sys
s = open(sys.argv[1]).read(); p = sys.argv[3:]
for i in range(0, len(p), 2):
    if s.count(p[i]) != 1: sys.exit(3)
    s = s.replace(p[i], p[i + 1], 1)
open(sys.argv[2], "w").write(s)' "$GATE" "$e/self-update-gate.sh" "$@" 2>/dev/null || mrc=$?
  if [ "$mrc" -ne 0 ] || cmp -s "$GATE" "$e/self-update-gate.sh" || ! bash -n "$e/self-update-gate.sh" 2>/dev/null; then return 1; fi
  printf '%s' "$e/self-update-gate.sh"
}
if sg base; then
OUT="$(bash "$GATE" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>&1)"
RC=$?
# $1 script  $2 expected STATUS (or ABSENT)  $3 why
row() {
  local s="$1" want="$2" why="$3" got
  ASSERTIONS=$((ASSERTIONS + 1))
  got="$(printf '%s\n' "$OUT" | awk -F'\t' -v s="$s" '$2 == s {print $1; exit}')"
  if [ "$want" = ABSENT ]; then
    if [ -z "$got" ]; then
      printf '  ok    %-16s no row  (%s)\n' "$s" "$why"
    else
      FAILURES=$((FAILURES + 1))
      printf '  FAIL  %-16s got=%s want=no-row  (%s)\n' "$s" "$got" "$why"
    fi
  elif [ "$got" = "$want" ]; then
    printf '  ok    %-16s %s  (%s)\n' "$s" "$got" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s got=%s want=%s  (%s)\n' "$s" "${got:-<none>}" "$want" "$why"
    printf '%s\n' "$OUT" | sed 's/^/          | /'
  fi
}

row gate-pass.sh   SELF-UPDATE-OK        "incoming passes against the consumer tree, so installing it cannot block the push"
row gate-defer.sh  SELF-UPDATE-DEFER     "current 0, incoming 1 — a genuinely new finding on pre-existing state"
# v0.297.0: agreement is not a differential signal, whatever the code. Both sides exit 1 here, so
# the incoming version fails nowhere the current one passes. Falsified by MUTANT C in
# self-update-join-gate, which narrows the arm back to 2-and-2 and watches 1,1 defer again.
row gate-broken.sh SELF-UPDATE-OK        "both exit 1 — equal codes carry no differential, and this bare probe cannot pass what the pre-push passes"
# ...and DISAGREEING non-zero codes are the only remaining route to UNDECIDED. Without this row
# that verdict would have no subject at all.
row gate-agree.sh  SELF-UPDATE-UNDECIDED "current 1, incoming 2 — two non-zero codes that DISAGREE, so the change is real but unattributable"

# The gating set comes from the HOOK, not from the changed-path list. not-invoked.sh changed AND its
# incoming version exits 1, so a gate deriving the set from the diff would emit a spurious defer.
row not-invoked.sh ABSENT "changed but the pre-push never invokes it, so it cannot block a push"
# ...and a script the hook DOES invoke but which this pull does not change is equally out of scope.
row unchanged.sh   ABSENT "invoked but unchanged base->theirs, so the self-update does not replace it"

# UNDECIDED must be treated as a defer, or the caller proceeds autonomously on a failure nobody
# could attribute — the one thing this gate exists to prevent.
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | awk -F'\t' '$1 == "SELF-UPDATE-DEFER" && $2 == "-" {f=1} END{exit !f}'; then
  printf '  ok    %-16s a summary DEFER row is emitted, so the caller cannot read past a per-script verdict\n' "summary-defer"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s no summary DEFER row — a caller scanning only the last line would proceed\n' "summary-defer"
fi

# Classifier, not a gate: the CALLER decides. (layer-drift.sh shares the classifier posture but
# exits 2 when a row could not be written; this script has no such exit.)
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$RC" -eq 0 ]; then
  printf '  ok    %-16s exit 0  (classifier never blocks; the caller decides)\n' "exit-code"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s exit=%s want=0\n' "exit-code" "$RC"
fi

# --- MUTATION: drop the differential, read the incoming exit code alone --------------
# gate-agree then reads as a DEFER, which is the false positive that strands a machinery slice for
# a failure nobody can attribute. It must ALSO leave gate-defer's real verdict intact, or the mutant
# is entangled and proves nothing about which half did the work.
#
# THE SUBJECT MOVED IN v0.297.0, from gate-broken to gate-agree, and the reason is that gate-broken
# is no longer reachable by this mutation: 1-and-1 now settles on the equality arm ABOVE the
# differential, so dropping the differential cannot move it. Aiming a mutant at a case the mutation
# can no longer reach is how a kill becomes a coincidence.
MUT="$(dirname "$DIST")/mut-nodiff"
rm -rf "$MUT"; mkdir -p "$MUT"
sed 's/^      if \[ "$rc_cur" -eq 0 \]; then sc_v=DEFER$/      if true; then sc_v=DEFER/' "$GATE" > "$MUT/gate.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$GATE" "$MUT/gate.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s the mutation matched nothing, so the UNDECIDED assertion is unproven\n' "mutation"
else
  m="$(bash "$MUT/gate.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>&1)"
  m_broken="$(printf '%s\n' "$m" | awk -F'\t' '$2 == "gate-agree.sh" {print $1; exit}')"
  m_defer="$(printf '%s\n' "$m"  | awk -F'\t' '$2 == "gate-defer.sh"  {print $1; exit}')"
  if [ "$m_broken" = SELF-UPDATE-DEFER ] && [ "$m_defer" = SELF-UPDATE-DEFER ]; then
    printf '  ok    %-16s without the differential a pre-existing failure reads as a defer\n' "mutation"
  elif [ "$m_broken" != SELF-UPDATE-DEFER ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s mutant still classified gate-agree as %s, so the differential assertion is vacuous\n' "mutation" "${m_broken:-<none>}"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s mutant also changed gate-defer to %s, so it is entangled\n' "mutation" "${m_defer:-<none>}"
  fi
fi

# THE UNMUTATED CONTROL. The mutant is a copy; a copy that cannot run emits nothing, and nothing
# would score as a kill above.
CTL="$(dirname "$DIST")/ctl"; rm -rf "$CTL"; mkdir -p "$CTL"; cp "$GATE" "$CTL/gate.sh"
ASSERTIONS=$((ASSERTIONS + 1))
c_broken="$(bash "$CTL/gate.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>&1 | awk -F'\t' '$2 == "gate-agree.sh" {print $1; exit}')"
if [ "$c_broken" = SELF-UPDATE-UNDECIDED ]; then
  printf '  ok    %-16s unmutated copy reproduces UNDECIDED (harness is sound)\n' "mutation-control"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s unmutated copy gave %s — a copy that cannot run scores as a kill\n' "mutation-control" "${c_broken:-<none>}"
fi
fi
if sg ss; then

# --- --safe-stop: a DEFER must name the ref that ends it -------------------------------
#
# A DEFER is correct and it is a dead end. The deferred slice lands at step 7, AFTER step 3's
# classify, so a classifier improvement anywhere in the range cannot classify the pull that
# delivers it — the operator gets a report written by the engine they were replacing. The way
# out is to stop at a release whose slice IS machinery-only, and that ref is derivable only by
# running this gate per release. These arms assert it is derived, and derived CORRECTLY.
#
# Own miniature distribution: the seeded one has no release history, and `--safe-stop`'s
# candidate set IS the release history.

# PRECONDITION FOR THE PRECONDITIONS. An empty machinery set makes every classify run here answer
# UNDECIDED, which the two arms below read as "defer" — they would then fail, or worse pass, for a
# reason that has nothing to do with the walk they exist to underwrite.
ss_assert "ss-machinery-set" \
  "$(bash "$GATE" "$SS/dist" "$SS_BASE" "$SS_R2" "$SS/cons" 2>&1 | grep -c 'SELF-UPDATE-UNDECIDED')" \
  "0" "the seeded tree resolves a NON-empty machinery set, so no arm below runs against a set-empty UNDECIDED"

# PRECONDITION, or every arm below is vacuous: r2 must actually defer and r1 must not.
ss_assert "safe-stop-pre" \
  "$(bash "$GATE" "$SS/dist" "$SS_BASE" "$SS_R2" "$SS/cons" 2>&1 | awk -F'\t' '$1 ~ /DEFER/ {print "defer"; exit}')" \
  "defer" "the seeded r2 really does defer (without this the walk has nothing to stop at)"
ss_assert "safe-stop-pre2" \
  "$(bash "$GATE" "$SS/dist" "$SS_BASE" "$SS_R1" "$SS/cons" 2>&1 | awk -F'\t' '$1 ~ /DEFER|UNDECIDED/ {print "defer"; exit}')" \
  "" "and the seeded r1 does not — so a walk that returns r1 returned the CLEAN one"

ss_assert "safe-stop" "$(bash "$GATE" --safe-stop "$SS/dist" "$SS_BASE" "$SS_R2" "$SS/cons" 2>/dev/null)" \
  "$SS_R1" "the furthest cleanly-self-updating release in base..r2 is r1"

# CONTROL: it is not simply echoing the newest release, nor THEIRS itself. With r1 as the
# target there is no INTERMEDIATE release, so the honest answer is nothing.
ss_out="$(bash "$GATE" --safe-stop "$SS/dist" "$SS_BASE" "$SS_R1" "$SS/cons" 2>/dev/null)"; ss_rc=$?
ss_assert "safe-stop-none" "${ss_out}|${ss_rc}" "|1" \
  "with no intermediate release the walk returns nothing and rc 1, rather than naming THEIRS"

# The advisory reaches the caller on a DEFER, and names the ref rather than restating the problem.
ss_assert "safe-stop-row" \
  "$(bash "$GATE" "$SS/dist" "$SS_BASE" "$SS_R2" "$SS/cons" 2>&1 | awk -F'\t' '$1=="SELF-UPDATE-SAFE-STOP" {print $2; exit}')" \
  "$SS_R1" "a DEFER carries a SELF-UPDATE-SAFE-STOP row naming the ref"

# CONTROL: a clean verdict must NOT carry one. Advice attached to every run is noise, and it
# would also mean the arm above fires regardless of the verdict it claims to accompany.
ss_assert "safe-stop-quiet" \
  "$(bash "$GATE" "$SS/dist" "$SS_BASE" "$SS_R1" "$SS/cons" 2>&1 | grep -c 'SELF-UPDATE-SAFE-STOP')" \
  "0" "a SELF-UPDATE-OK verdict carries no advisory"

# THE LATEST CLEAN CANDIDATE WINS, NOT THE ONE BEFORE THE FIRST DEFER. base..r4 contains a
# clean r1, a deferring r2 and a clean r3. Each verdict is computed BASE→candidate, so r3 is a
# single clean hop that lands strictly more than r1 — a walk that stopped at the first defer
# would answer r1 and quietly cost the operator two releases of progress.
ss_assert "safe-stop-latest" "$(bash "$GATE" --safe-stop "$SS/dist" "$SS_BASE" "$SS_R4" "$SS/cons" 2>/dev/null)" \
  "$SS_R3" "the LATEST clean release wins, even with a deferring release before it"
ss_assert "safe-stop-latest-pre" \
  "$(bash "$GATE" "$SS/dist" "$SS_BASE" "$SS_R3" "$SS/cons" 2>&1 | awk -F'\t' '$1 ~ /DEFER|UNDECIDED/ {print "defer"; exit}')" \
  "" "and r3 really is clean from base — without this the arm above proves nothing"

# --safe-stop's stdout is a REF AND NOTHING ELSE, because the caller substitutes it into a
# command. A leaked TSV row — the advisory re-entering through a nested classify, say — would
# be pasted straight into `ai-dlc-update <ref>`.
#
# This replaced an assertion that compared "reached" to "reached", which passed whenever the
# fixture got that far and therefore asserted nothing. It was written to cover the advisory's
# re-entry guard; a mutant removing that guard came back GREEN, which is how the tautology was
# found. The guard is a COST measure — a nested walk covers a strictly shorter range, so the
# recursion terminates either way — and it is deliberately NOT covered by an assertion here,
# because no observable output distinguishes the two.
ss_assert "safe-stop-clean-stdout" \
  "$(bash "$GATE" --safe-stop "$SS/dist" "$SS_BASE" "$SS_R2" "$SS/cons" 2>/dev/null | grep -c 'SELF-UPDATE-')" \
  "0" "stdout carries the ref alone, with no status row that could be pasted into a command"

# --- THE ROW IS DERIVED FROM THE RANGE, AND THE CONSUMER'S MACHINERY IS THE OTHER HALF -------
# `PC-S331-SAFE-STOP-IGNORES-THE-CONSUMERS-OWN-SKILL-COMMIT`. The row urges a split so the engine
# lands before it is used. On a consumer whose `skill_commit` is already at or past the named ref,
# the engine HAS landed and the split advances only the rulebook pair. Every arm above ran without
# a stamp at all, which is why none of them could see this.
ss_detail() { # ss_detail <theirs> -> the SAFE-STOP row's DETAIL field
  bash "$GATE" "$SS/dist" "$SS_BASE" "$1" "$SS/cons" 2>&1 |
    awk -F'\t' '$1=="SELF-UPDATE-SAFE-STOP" {print $3; exit}'
}

# BASELINE, and it is the control that makes the next three readable: with no stamp the wording is
# unchanged from before this guard existed.
ss_stamp -
ss_assert "ss-nostamp" "$(ss_detail "$SS_R2" | grep -c 'SPLIT BUYS NOTHING')" "0" \
  "no stamp: the row keeps its original 'pull FIRST' wording"

# AT the named ref. `--is-ancestor` is true for equality, which is the "at" in "at or past".
ss_stamp "$SS_R1"
ss_assert "ss-at" "$(ss_detail "$SS_R2" | grep -c 'SPLIT BUYS NOTHING')" "1" \
  "skill_commit AT the named ref: the row says the split buys nothing"
ss_assert "ss-at-ref" \
  "$(bash "$GATE" "$SS/dist" "$SS_BASE" "$SS_R2" "$SS/cons" 2>&1 | awk -F'\t' '$1=="SELF-UPDATE-SAFE-STOP"{print $2; exit}')" \
  "$SS_R1" "and it still NAMES the ref — annotated, never suppressed, so the DEFER keeps a next step"

# PAST it — the reference consumer's actual shape: `skill_commit` was one commit beyond the
# release the row named, so an equality test alone would have missed the case that was filed.
ss_stamp "$SS_R3"
ss_assert "ss-past" "$(ss_detail "$SS_R2" | grep -c 'SPLIT BUYS NOTHING')" "1" \
  "skill_commit PAST the named ref: still annotated (equality alone would miss the filed case)"

# CONTROL: BEHIND it. This is the case the row was written for and it must be untouched.
ss_stamp "$SS_R1"
ss_assert "ss-behind" "$(ss_detail "$SS_R4" | grep -c 'SPLIT BUYS NOTHING')" "0" \
  "skill_commit BEHIND the ref the walk names (r3): the original advice stands"

# CONTROL: a ref this distribution cannot resolve tells us nothing, and must not be read as
# "at or past" — that would silence the advice on every consumer with a foreign stamp.
ss_stamp "0000000000000000000000000000000000000000"
ss_assert "ss-unresolvable" "$(ss_detail "$SS_R2" | grep -c 'SPLIT BUYS NOTHING')" "0" \
  "an unresolvable skill_commit falls back to the original advice"

# CONTROL: `skill_commit` == `commit` means no self-update hop has run, so there is no
# intermediate machinery ref and the guard must not fire off the rulebook sha.
ss_stamp "$SS_BASE"
ss_assert "ss-equals-base" "$(ss_detail "$SS_R2" | grep -c 'SPLIT BUYS NOTHING')" "0" \
  "skill_commit == commit (no self-update hop) falls back to the original advice"

# --- THE STAMP IS AHEAD AND THE TREE IS PARTIAL, SO THE ACQUITTAL IS WITHHELD -----------------
# Every arm above scores the acquittal on the stamp FIELD alone, which is all
# `machinery_at_or_past` reads -- a `merge-base --is-ancestor` against `skill_commit`. A FIELD
# THAT IS AHEAD IS NOT EVIDENCE THAT THE TREE MATCHING IT IS COMPLETE. `apply.sh` writes
# `.claude/.ai-dlc-applying` at the start of every apply and removes it only on the success path;
# a run that WITHHOLDS the re-stamp writes no stamp at all, leaves that marker deliberately in
# place, and calls the tree partial in as many words. Because such a run writes nothing, a
# `skill_commit` an earlier step 2 advanced survives beside a `commit` still at base -- split
# stamp plus marker on disk -- and in that state the acquittal FIRED on a partial tree.
#
# SCORED BY EFFECT, NOT BY ROW COUNT, AND THE `row=` CONJUNCT IS THE REASON. A gate replaced by
# `exit 0` scores acq=0 wh=0 pf=0, which is most of what the offender arm below wants to see;
# requiring the SAFE-STOP row to EXIST in the same tuple is what stops silence passing for
# discrimination. Measured, by running this fixture against such a gate: with the conjunct the
# three arms below fail, and every other cell of the tuple agrees with a clean run.

# A -- OFFENDER. `skill_commit` at r1, which is at-or-past the ref the walk names, and the
# interrupted-apply marker on disk.
ss_stamp "$SS_R1"; ss_marker on
ss_assert "ss-partial-A" "$(ss_ack "$GATE" "$SS_R2")" "row=1 acq=0 wh=1 pf=0" \
  "stamp ahead + .ai-dlc-applying on disk: the acquittal is replaced by the withheld row"

# B -- NEAR-MISS, IN THE SAME RUN AND ONE PROPERTY APART. Same stamp, marker removed. Without
# this the guard could be refusing blanket and A would read identically.
ss_marker off
ss_assert "ss-partial-B" "$(ss_ack "$GATE" "$SS_R2")" "row=1 acq=1 wh=0 pf=0" \
  "stamp ahead with no marker: the acquittal is untouched, so the guard reads the marker"

# C -- THE NEAR-MISS THAT SITES THE GUARD. Marker on disk, but `skill_commit` BEHIND the ref the
# walk names for r4, so `machinery_at_or_past` is false and the acquittal branch is never
# entered. A guard sited ABOVE that branch -- refusing on the marker alone -- would replace this
# pull-first row too, and A and B together cannot tell the two sitings apart.
ss_stamp "$SS_R1"; ss_marker on
ss_assert "ss-partial-C" "$(ss_ack "$GATE" "$SS_R4")" "row=1 acq=0 wh=0 pf=1" \
  "marker on disk but stamp BEHIND: the original pull-first advice stands, so the guard is INSIDE the acquittal branch"

# --- MUTANT: REMOVE THE MARKER GUARD -----------------------------------------------------
# ss-partial-A is ABSENCE-shaped on the acquittal token, and that is the shape that survives a
# subject which never ran. The `row=` conjunct blocks the silent case; only a mutant establishes
# that the arm discriminates at all.
#
# THE COPY NEEDS ITS SIBLINGS. `machinery_paths()` resolves `$(dirname "$0")/setup-sites.md`, so
# a lone gate in a bare directory gets an EMPTY machinery set, answers UNDECIDED with no
# SAFE-STOP row, and every mutant would score as killed off a harness failure rather than a
# mutation.
SSM="$(dirname "$DIST")/ssmut"
rm -rf "$SSM"; mkdir -p "$SSM/mut" "$SSM/ctl"
cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$SSM/mut"/ 2>/dev/null
cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$SSM/ctl"/ 2>/dev/null

# ONE STRING SERVES THE GREP AND THE SED, so the uniqueness proved below is a property of the
# expression that actually mutates. Written apart they drift, and the arm then proves that some
# OTHER expression is unique.
SS_ANCHOR='^      if \[ -f "\$CONSUMER/\.claude/\.ai-dlc-applying" \]; then$'
ss_assert "ss-partial-anchor" "$(grep -c "$SS_ANCHOR" "$GATE")" "1" \
  "the mutation's anchor matches exactly ONE line, so the sed below cannot move a second cell"
# CONTROL, and it is what makes the 1 above mean something: a grammar that cannot spell its own
# subject returns 0 on the real anchor too, and a 1 with no 0 beside it does not separate the two.
ss_assert "ss-partial-anchor-ctl" \
  "$(grep -c '^      if \[ -f "\$CONSUMER/\.claude/\.ai-dlc-NOT-A-MARKER" \]; then$' "$GATE")" "0" \
  "an impossible anchor of the SAME shape returns 0, so the match above is a match and not a grammar artefact"

# THE UNMUTATED CONTROL, PRESENCE-SHAPED ON PURPOSE. It runs before the mutant and demands the
# withheld row from a plain copy: a copy that dies sourcing its siblings emits nothing, and
# "nothing" is what the mutant is expected to stop producing. An rc-and-no-error control would
# pass against `exit 0` here.
ss_stamp "$SS_R1"; ss_marker on
ss_assert "ss-partial-control" "$(ss_ack "$SSM/ctl/self-update-gate.sh" "$SS_R2")" \
  "row=1 acq=0 wh=1 pf=0" \
  "an UNMUTATED copy beside its siblings reproduces the withheld row, so a mutant's shift is the mutation"

sed "s@${SS_ANCHOR}@      if false; then@" "$GATE" > "$SSM/mut/self-update-gate.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$GATE" "$SSM/mut/self-update-gate.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s mutation matched nothing, so the arm it scores is unproven\n' "ss-partial-mut"
else
  ss_stamp "$SS_R1"; ss_marker on
  ssm_got="$(ss_ack "$SSM/mut/self-update-gate.sh" "$SS_R2")"
  if [ "$ssm_got" = "row=1 acq=1 wh=0 pf=0" ]; then
    printf '  ok    %-16s KILLED (%s)\n' "ss-partial-mut" \
      "with the marker guard gone the acquittal returns on the partial tree and the withheld row disappears"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: got=[%s] want=[%s]\n' "ss-partial-mut" "$ssm_got" "row=1 acq=1 wh=0 pf=0"
  fi
fi

# THE MUTANT MOVES ONE CELL AND NO OTHER, which is how ss-partial-A is shown to OWN the case
# rather than sharing it. Two arms moving under one mutation means one of them is vacuous.
ss_marker off
ss_assert "ss-partial-mut-B" "$(ss_ack "$SSM/mut/self-update-gate.sh" "$SS_R2")" \
  "row=1 acq=1 wh=0 pf=0" "the mutant leaves B where it was -- B never entered the guard"
ss_stamp "$SS_R1"; ss_marker on
ss_assert "ss-partial-mut-C" "$(ss_ack "$SSM/mut/self-update-gate.sh" "$SS_R4")" \
  "row=1 acq=0 wh=0 pf=1" "and C where it was -- C never reaches the acquittal branch at all"

ss_marker off
ss_stamp -

fi
if sg sc; then
# --- THE STAMP IS AHEAD BECAUSE A PATH WAS CARRIED, SO THE ACQUITTAL IS WITHHELD -------------
# The sibling of the partial-tree guard above, and the two are decided on different facts. That
# one reads a MARKER `apply.sh` leaves on disk. This one reads a row THIS RUN emitted.
#
# Step 2 advances `skill_version`/`skill_commit` to `theirs` on every cycle it completes,
# INCLUDING one where arm C carried a machinery path out of the slice -- and a carried path is
# precisely the one the cycle deliberately did not write. No program corrects the stamp for it:
# `apply.sh`'s re-stamp and `install.sh` are the only writers of those fields, both at step 7 or
# install. So `machinery_at_or_past()`'s ancestry test comes back TRUE on a tree where a machinery
# path is still the consumer's own, and the acquittal it gates tells the operator "its machinery
# has already landed" about exactly the path that did not.
#
# ITS OWN MINIATURE DISTRIBUTION, AND THE REASON IS THE SEED AND NOT TIDINESS. The `$SS` tree
# above holds ONE machinery path (`core/rules/ss.md`) that is never touched again, so no
# base..theirs diff can reach it and no consumer edit to it can produce a bucket -- a CARRY row is
# unconstructible there, which is the state every arm above was written under. These arms need a
# CARRY row and a SAFE-STOP row in ONE output.
#
# THREE WORLDS, ONE STAMP. All three carry `skill_commit` at r1, which is at-or-past the ref the
# walk names, so every one of them ENTERS the acquittal branch on the unfixed gate and the only
# thing separating them is whether a path was carried.
SC="$(dirname "$DIST")/sc"; rm -rf "$SC"
mkdir -p "$SC/dist/core/skills/ai-dlc/steps" "$SC/dist/core/rules" \
         "$SC/dist/core/skills/ai-dlc-update/reconcile"
git -C "$SC/dist" init -q
sc_commit() { git -C "$SC/dist" add -A >/dev/null 2>&1
              git -C "$SC/dist" -c user.email=f@x -c user.name=f commit -qm "$1" >/dev/null 2>&1
              git -C "$SC/dist" rev-parse HEAD; }

printf '1.0.0\n'      > "$SC/dist/VERSION"
gvv 1 2               > "$SC/dist/core/skills/ai-dlc/steps/gate-validation.md"
printf 'carry base\n' > "$SC/dist/core/rules/sc-carry.md"
# THE LANDED PATH IS NOT DECORATION. Without a machinery path the consumer really is at, world B
# would be "no machinery moved" rather than "machinery moved and landed", and its acquittal would
# be right for a reason that has nothing to do with the guard under test.
printf 'landed base\n' > "$SC/dist/core/rules/sc-landed.md"
# `preclassify.sh` AS A CARRIED PATH IS ITS OWN WORLD, world C below. It is machinery by the
# `core/skills/ai-dlc-update/**` entry, and it is the case where the acquittal's sentence is at
# its most false: the row would be telling the operator that the classifier engine has landed
# while the consumer's copy of the classifier is the very path this run refused to write. The
# GATE resolves preclassify.sh beside ITSELF, in the distribution, so a consumer-side edit to it
# changes no derivation here -- only the bucket that edit produces.
printf 'preclassify base\n' > "$SC/dist/core/skills/ai-dlc-update/reconcile/preclassify.sh"
SC_BASE="$(sc_commit base)"

# r1 -- a release moving all three machinery paths. This is the ref the walk names, and the ref
# every consumer's `skill_commit` claims to be at.
printf '1.1.0\n'             > "$SC/dist/VERSION"
printf 'carry r1\n'          > "$SC/dist/core/rules/sc-carry.md"
printf 'landed r1\n'         > "$SC/dist/core/rules/sc-landed.md"
printf 'preclassify r1\n'    > "$SC/dist/core/skills/ai-dlc-update/reconcile/preclassify.sh"
SC_R1="$(sc_commit r1)"

# r2 -- THEIRS. Declares a CHECK_LOADED anchor the consumer's rulebook does not carry, so
# base..r2 DEFERS and the advisory runs at all. Without a DEFER there is no SAFE-STOP row and
# every arm below is an absence over an empty output.
printf '1.2.0\n' > "$SC/dist/VERSION"; gvv 1 2 3 > "$SC/dist/core/skills/ai-dlc/steps/gate-validation.md"
SC_R2="$(sc_commit r2)"

sc_cons() { # sc_cons <clean|carry|preclassify> -> a consumer at r1 with that path diverged
  local C="$SC/cons" mode="$1"
  rm -rf "$C"
  mkdir -p "$C/.claude/rules" "$C/.claude/skills/ai-dlc/steps" "$C/.githooks" \
           "$C/.claude/skills/ai-dlc-update/reconcile"
  gvv 1 2 > "$C/.claude/skills/ai-dlc/steps/gate-validation.md"
  printf '#!/usr/bin/env bash\n# invokes no scripts/ai-dlc/ validator, so the gating set is empty\nexit 0\n' \
    > "$C/.githooks/pre-push"
  # THE WHOLE CONSUMER STATE IS REWRITTEN EVERY TIME, never patched: a helper that only writes
  # what its mode changes leaves the previous world's files behind, and the next arm then reads a
  # shape nobody seeded.
  printf 'carry r1\n'       > "$C/.claude/rules/sc-carry.md"
  printf 'landed r1\n'      > "$C/.claude/rules/sc-landed.md"
  printf 'preclassify r1\n' > "$C/.claude/skills/ai-dlc-update/reconcile/preclassify.sh"
  case "$mode" in
    carry)       printf 'carry r1\nCONSUMER-OWNED LINE\n'       > "$C/.claude/rules/sc-carry.md" ;;
    preclassify) printf 'preclassify r1\nCONSUMER-OWNED LINE\n' > "$C/.claude/skills/ai-dlc-update/reconcile/preclassify.sh" ;;
  esac
  # THE STAMP IS ADVANCED IN ALL THREE, which is the point: step 2 advances it whether or not a
  # path was carried, so the stamp cannot be what separates these worlds.
  printf 'version: 1.0.0\ncommit: %s\nskill_version: 1.1.0\nskill_commit: %s\n' "$SC_BASE" "$SC_R1" \
    > "$C/.claude/.ai-dlc-version"
}

# sc_ack <gate> -> "row=<0|1> acq=<n> pf=<n> carry=<n>" off one run's rows.
#
# SCORED AS A TUPLE, AND `row=` AND `pf=` ARE BOTH POSITIVE CONJUNCTS. The property under test is
# an ABSENCE (`acq=0`), which is the shape a gate replaced by `exit 0` satisfies for free. So the
# same tuple demands the SAFE-STOP row EXIST and demands the honest pull-first wording be the
# thing that replaced the acquittal -- a subject that emits nothing fails on both.
#
# `pf` KEYS ON "its slice self-updates cleanly" for the reason `ss_ack` does: the acquittal's own
# text also tells the operator to pull, so the short token cannot separate the two rows.
sc_ack() {
  local o d
  o="$(bash "$1" "$SC/dist" "$SC_BASE" "$SC_R2" "$SC/cons" 2>/dev/null)"
  d="$(printf '%s\n' "$o" | awk -F'\t' '$1=="SELF-UPDATE-SAFE-STOP" {print $3; exit}')"
  printf 'row=%s acq=%s pf=%s carry=%s\n' \
    "$([ -n "$d" ] && printf 1 || printf 0)" \
    "$(printf '%s' "$d" | grep -c 'SPLIT BUYS NOTHING')" \
    "$(printf '%s' "$d" | grep -c 'its slice self-updates cleanly')" \
    "$(printf '%s\n' "$o" | awk -F'\t' '$1=="SELF-UPDATE-CARRY"' | grep -c .)"
}

# PRECONDITION, and without it every arm below is vacuous in a way that reads as discrimination:
# the walk must NAME r1, since the acquittal compares `skill_commit` against the named ref and a
# walk answering anything else takes all three worlds out of the branch under test.
sc_cons clean
ss_assert "sc-walk-names-r1" \
  "$(bash "$GATE" --safe-stop "$SC/dist" "$SC_BASE" "$SC_R2" "$SC/cons" 2>/dev/null)" "$SC_R1" \
  "the walk names r1, which is the ref all three worlds' skill_commit sits at"

# B -- THE CONTROL, AND IT RUNS FIRST. No path carried, stamp at r1: the acquittal FIRES. Without
# this the withheld arms below are claims about a sentence that might never appear on this tree.
ss_assert "sc-nocarry" "$(sc_ack "$GATE")" "row=1 acq=1 pf=0 carry=0" \
  "no carry row and a stamp at or past the named ref: the acquittal fires, unchanged"

# A -- OFFENDER. One machinery path carried, same stamp, same range. The acquittal is withheld and
# the original pull-first advice stands in its place.
sc_cons carry
ss_assert "sc-carried" "$(sc_ack "$GATE")" "row=1 acq=0 pf=1 carry=1" \
  "a carried machinery path withholds the acquittal: the stamp is ahead of a path that did not land"

# C -- THE SAME GUARD ON THE SEED WHERE THE ROW'S RATIONALE IS MOST FALSE. `preclassify.sh` IS the
# classifier engine the acquittal claims has landed. Kept as its own world rather than folded into
# A because a fix keyed on the path's DIRECTORY -- `core/rules/` say -- passes A and fails here.
sc_cons preclassify
ss_assert "sc-carried-preclassify" "$(sc_ack "$GATE")" "row=1 acq=0 pf=1 carry=1" \
  "the carried path being preclassify.sh itself is withheld too -- the engine the row says landed"

# THE WALK IS UNAFFECTED, and this is the arm that would catch the refusal leaking into the nested
# classify runs. Arm C is suppressed under AI_DLC_GATE_IN_SAFE_STOP, so GATE_CARRY_STATE stays
# `cold` inside a walk and no candidate's verdict can move -- a refusal sited where the walk could
# see it would change which ref the operator is handed, which is a verdict and not advisory wording.
ss_assert "sc-walk-unmoved" \
  "$(bash "$GATE" --safe-stop "$SC/dist" "$SC_BASE" "$SC_R2" "$SC/cons" 2>/dev/null)" "$SC_R1" \
  "the walk still names r1 on the carried consumer -- the refusal is advisory-only"

# --- ARM C CANNOT DECIDE, AND UNKNOWN IS NOT CLEAN --------------------------------------------
# The arms above all run against an arm C that DECIDED. Arm C has two UNDECIDED terminals of its
# own, and on both of them it emits no CARRY row while a carried path may be sitting in the tree.
# A refusal keyed on the CARRY row alone therefore acquits exactly where the gate has just said it
# does not know -- the acquittal and the UNDECIDED row printed in the SAME output, contradicting
# each other. Measured before the three-state was built: with a carried path and an advanced
# stamp, an intact engine withheld and both UNDECIDED engines acquitted.
#
# ARM C FAILS CLOSED ON ITS OWN ROW AND THAT CLOSURE IS NOT INHERITED. The UNDECIDED rows are
# arm C being careful; a downstream reader keyed on the absence of a CARRY row converts that care
# into silence. So the state carries `undecided` as a value of its own and only `clean` acquits.
#
# THE ENGINE IS SABOTAGED, NEVER THE CONSUMER, and that is what makes these worlds the UNDECIDED
# ones rather than merely quiet: the consumer is byte-identical to the carried world above -- the
# same diverged path, the same advanced stamp -- so the ONLY difference is arm C's ability to see
# it. A seed that instead removed the divergence would test nothing, because a tree with nothing
# to carry has nothing to withhold.
sc_engine() { # sc_engine <name> <nomanifest|norows|nopre> -> a gate copy whose arm C cannot decide
  local E="$SC/eng-$1" mode="$2"
  rm -rf "$E"; mkdir -p "$E"
  cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$E"/ 2>/dev/null
  case "$mode" in
    # `machinery:` emptied -> machinery_paths() resolves EMPTY -> the setup-sites.md terminal.
    nomanifest) awk '/^machinery:/{print; skip=1; next} skip && /^[a-z_]+:/{skip=0} !skip' \
                  "$E/setup-sites.md" > "$E/.t" && mv "$E/.t" "$E/setup-sites.md" ;;
    # preclassify prints no rows while the range moves core/ -> the preclassify.sh terminal. Its
    # two eval'd functions are KEPT, or the machinery set resolves empty and this world collapses
    # into the one above -- two seeds reaching one terminal, which is one seed.
    norows)     printf '#!/usr/bin/env bash\n%s\n%s\nexit 0\n' \
                  "$(awk '/^machinery_paths\(\) \{/,/^\}/' "$E/preclassify.sh")" \
                  "$(awk '/^map_consumer\(\) \{/,/^\}/' "$E/preclassify.sh")" > "$E/preclassify.sh" ;;
    # the engine is absent outright -- the shape a partial install leaves.
    nopre)      rm -f "$E/preclassify.sh" ;;
  esac
  printf '%s\n' "$E/self-update-gate.sh"
}

# sc_und <gate> -> "row=<0|1> acq=<n> pf=<n> und=<n>" on the CARRIED consumer.
#
# PRESENCE-SHAPED ON BOTH HALVES. `und=1` demands arm C's UNDECIDED row be in the same output as
# the withheld advisory -- without it a gate that simply printed nothing would satisfy `acq=0`,
# and `pf=1` demands the honest pull-first wording actually replaced the acquittal.
sc_und() {
  local o d
  o="$(bash "$1" "$SC/dist" "$SC_BASE" "$SC_R2" "$SC/cons" 2>/dev/null)"
  d="$(printf '%s\n' "$o" | awk -F'\t' '$1=="SELF-UPDATE-SAFE-STOP" {print $3; exit}')"
  printf 'row=%s acq=%s pf=%s und=%s\n' \
    "$([ -n "$d" ] && printf 1 || printf 0)" \
    "$(printf '%s' "$d" | grep -c 'SPLIT BUYS NOTHING')" \
    "$(printf '%s' "$d" | grep -c 'its slice self-updates cleanly')" \
    "$(printf '%s\n' "$o" | awk -F'\t' '$1=="SELF-UPDATE-UNDECIDED"' | grep -c .)"
}

SC_E_NOMAN="$(sc_engine noman nomanifest)"
SC_E_NOROW="$(sc_engine norow norows)"
SC_E_NOPRE="$(sc_engine nopre nopre)"

# SELF-PROBE FIRST: each sabotaged engine must actually reach an UNDECIDED terminal AND stop
# emitting the CARRY row. Without this the three arms below are absences over engines that might
# simply be working, and they would pass against a gate that never looked.
sc_cons carry
for sc_p in "noman=$SC_E_NOMAN" "norow=$SC_E_NOROW" "nopre=$SC_E_NOPRE"; do
  ss_assert "sc-und-probe-${sc_p%%=*}" \
    "$(bash "${sc_p#*=}" "$SC/dist" "$SC_BASE" "$SC_R2" "$SC/cons" 2>/dev/null |
         awk -F'\t' '$1=="SELF-UPDATE-UNDECIDED"{u++} $1=="SELF-UPDATE-CARRY"{c++}
                     END {printf "und=%d carry=%d", u+0, c+0}')" \
    "und=1 carry=0" "the sabotaged engine really cannot decide, and really emits no CARRY row"
done

# THE THREE OFFENDERS. Same consumer, same range, same advanced stamp -- only arm C's sight differs.
ss_assert "sc-und-nomanifest" "$(sc_und "$SC_E_NOMAN")" "row=1 acq=0 pf=1 und=1" \
  "machinery set EMPTY: the acquittal is withheld beside the UNDECIDED row, not printed against it"
ss_assert "sc-und-norows" "$(sc_und "$SC_E_NOROW")" "row=1 acq=0 pf=1 und=1" \
  "bucket derivation returns no rows over a moving range: withheld for the same reason"
ss_assert "sc-und-nopre" "$(sc_und "$SC_E_NOPRE")" "row=1 acq=0 pf=1 und=1" \
  "preclassify.sh absent entirely: withheld -- a partial install must not read as a landed one"

# THE CONTROL THAT SITES THE STATE RATHER THAN A BLANKET REFUSAL, and it is the one that would
# catch `machinery_at_or_past` simply returning 1. Intact engine, CLEAN consumer, same stamp: the
# acquittal must still FIRE. `sc-nocarry` above asserts this on the shipped gate; this re-asserts
# it in the same block as the three withholdings, where a blanket refusal would be visible.
sc_cons clean
ss_assert "sc-und-clean-control" "$(sc_und "$GATE")" "row=1 acq=1 pf=0 und=0" \
  "an intact engine on a clean consumer still acquits -- the refusal is keyed on the state, not blanket"

# --- MUTANTS on the carry refusal -------------------------------------------------------
#
# THE COPY IS THE WHOLE DIRECTORY. The gate resolves setup-sites.md and preclassify.sh by
# `dirname "$0"`; a lone copy resolves an EMPTY machinery set, emits no CARRY row for want of a
# subject, and every mutant scores a kill it did not earn.
SCM="$(dirname "$DIST")/scmut"
rm -rf "$SCM"; mkdir -p "$SCM/ctl"
cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$SCM/ctl"/ 2>/dev/null

# THE UNMUTATED CONTROL, PRESENCE-SHAPED, AND IT RUNS BEFORE ANY MUTANT. It asserts the carried
# world's full tuple off a plain copy: a copy that died sourcing its siblings prints nothing, and
# "nothing" is what two of the three mutants below are expected to stop producing.
sc_cons carry
ss_assert "sc-mut-control" "$(sc_ack "$SCM/ctl/self-update-gate.sh")" "row=1 acq=0 pf=1 carry=1" \
  "an UNMUTATED copy beside its siblings reproduces the withheld row, so a mutant's shift is the mutation"

# ONE STRING SERVES THE GREP AND THE SED for each anchor, so the uniqueness proved below is a
# property of the expression that actually mutates.
SC_A1='^  \[ "\${GATE_CARRY_STATE:-cold}" = clean \] || return 1$'
SC_A2='^        GATE_CARRY_STATE=carried$'
SC_A3='^    if machinery_at_or_past "\$_ss"; then$'
# m4's anchor is the pair of UNDECIDED sites, keyed on the SUBJECT'S OWN predicate -- both are
# `GATE_CARRY_STATE=undecided` and nothing else in the file is. A hand-named site list goes
# vacuous the release somebody adds a third terminal, and nothing announces it.
SC_A4='^\([[:blank:]]*\)GATE_CARRY_STATE=undecided$'
ss_assert "sc-anchor-1" "$(grep -c "$SC_A1" "$GATE")" "1" "the refusal is exactly one line"
ss_assert "sc-anchor-2" "$(grep -c "$SC_A2" "$GATE")" "1" "the carried SET site is exactly one line, distinct from the cold initializer"
ss_assert "sc-anchor-3" "$(grep -c "$SC_A3" "$GATE")" "1" "the acquittal branch is exactly one line"
# CONTROLS: a grammar that cannot spell its own subject returns 0 on the real anchor too, so each
# 1 above needs a 0 of the SAME shape beside it.
ss_assert "sc-anchor-1-ctl" "$(grep -c '^  \[ "\${GATE_NOT_A_STATE:-cold}" = clean \] || return 1$' "$GATE")" "0" \
  "an impossible anchor of the same shape returns 0"
ss_assert "sc-anchor-2-ctl" "$(grep -c '^        GATE_CARRY_STATE=hauled$' "$GATE")" "0" \
  "and a same-shaped impossible SET site returns 0"
ss_assert "sc-anchor-3-ctl" "$(grep -c '^    if machinery_never_at_or_past "\$_ss"; then$' "$GATE")" "0" \
  "and a same-shaped impossible branch returns 0"
# m4's anchor is a SET, not a line, so it is asserted as a count with a floor -- and the count is
# derived rather than written, so a third UNDECIDED terminal joins the mutation silently instead
# of leaving it partial. The post-mutation count is asserted 0 inside sc_kill's `cmp -s`.
ss_assert "sc-anchor-4" \
  "$(grep -c "$SC_A4" "$GATE" | awk '{print ($1 >= 2) ? "two-or-more" : "under"}')" "two-or-more" \
  "both of arm C's UNDECIDED terminals set the state, so the mutation cannot strip only one"
ss_assert "sc-anchor-4-ctl" "$(grep -c '^\([[:blank:]]*\)GATE_CARRY_STATE=unknowable$' "$GATE")" "0" \
  "and a same-shaped impossible state value returns 0"

# sc_kill <label> <sed-expr> <clean-want> <carry-want> <pre-want> <why>
#
# EVERY MUTANT IS SCORED ON ALL THREE WORLDS, and the mutant is killed only when the whole
# 3-tuple matches. A mutant that moved a cell nobody expected reads as a kill under a
# single-world score; here it reads as the entanglement it is.
#
# THE CARRIED-PRECLASSIFY WORLD IS A SEED, NOT A SECOND GUARD, so m1 and m2 move it in lockstep
# with the carried world by construction and that is not entanglement. What would be entanglement
# is either of them moving the CLEAN world, which is why that cell is in the tuple.
sc_kill() {
  local label="$1" expr="$2" wc="$3" wa="$4" wp="$5" why="$6" d="$SCM/$1" got want
  rm -rf "$d"; mkdir -p "$d"
  cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$d"/ 2>/dev/null
  if ! sed "$expr" "$GATE" > "$d/self-update-gate.sh"; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s sed DID NOT APPLY -- the mutant never existed and its arm is unproven\n' "$label"
    return
  fi
  if cmp -s "$GATE" "$d/self-update-gate.sh"; then
    ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s mutation matched nothing, so the arm it scores is unproven\n' "$label"
    return
  fi
  sc_cons clean;       got="clean[$(sc_ack "$d/self-update-gate.sh")]"
  sc_cons carry;       got="$got carry[$(sc_ack "$d/self-update-gate.sh")]"
  sc_cons preclassify; got="$got pre[$(sc_ack "$d/self-update-gate.sh")]"
  want="clean[$wc] carry[$wa] pre[$wp]"
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ "$got" = "$want" ]; then
    printf '  ok    %-16s KILLED (%s)\n' "$label" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: got=[%s] want=[%s]  %s\n' "$label" "$got" "$want" "$why"
  fi
}

# m1 -- the refusal itself is gone. The flag is still set; nothing reads it.
sc_kill "sc-mut-return" "s@${SC_A1}@  :@" \
  "row=1 acq=1 pf=0 carry=0" "row=1 acq=1 pf=0 carry=1" "row=1 acq=1 pf=0 carry=1" \
  "without the return the acquittal comes back on both carried worlds and the clean world is untouched"

# m2 -- the state is never raised to `carried`. The reader survives and reads a `clean` the emit
# can no longer downgrade, which is the shape a refusal sited on a value nobody writes takes.
# `clean` keeps the mutation inside arm C rather than deleting a line `set -u` would report.
sc_kill "sc-mut-noset" "s@${SC_A2}@        GATE_CARRY_STATE=clean@" \
  "row=1 acq=1 pf=0 carry=0" "row=1 acq=1 pf=0 carry=1" "row=1 acq=1 pf=0 carry=1" \
  "a state the emit never raises leaves the acquittal firing beside a CARRY row"

# m3 -- the acquittal branch is dead everywhere. This is the fix-by-deletion that satisfies every
# withheld arm above for free, and only the CLEAN world can tell it from the shipped guard.
sc_kill "sc-mut-iffalse" "s@${SC_A3}@    if false; then@" \
  "row=1 acq=0 pf=1 carry=0" "row=1 acq=0 pf=1 carry=1" "row=1 acq=0 pf=1 carry=1" \
  "killing the acquittal everywhere moves the CLEAN world, which the shipped guard leaves alone"

# m4 -- THE UNDECIDED TERMINALS STOP RECORDING THEMSELVES, which is precisely the first cut of
# this fix: a state raised only at the CARRY emit, leaving `clean` standing on the runs where arm
# C said it could not tell. Scored on a DIFFERENT axis from m1-m3 -- the three sabotaged engines
# rather than the three consumer worlds -- because that is the axis it moves, and it must leave
# the consumer-world axis alone.
#
# `clean` IS THE MUTATION AND NOT A DELETION. Removing the lines would leave `cold` standing at
# both terminals, which withholds for the WRONG reason and scores a kill the arm did not earn --
# a mutant that fails closed proves nothing about a guard whose job is failing closed. Writing
# `clean` reproduces the shipped defect exactly.
SCM4="$SCM/sc-mut-undec"
rm -rf "$SCM4"; mkdir -p "$SCM4"
cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$SCM4"/ 2>/dev/null
sed "s@${SC_A4}@\1GATE_CARRY_STATE=clean@" "$GATE" > "$SCM4/self-update-gate.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$GATE" "$SCM4/self-update-gate.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s mutation matched nothing, so the arm it scores is unproven\n' "sc-mut-undec"
elif [ "$(grep -c "$SC_A4" "$SCM4/self-update-gate.sh")" != 0 ]; then
  # A MUTATION THAT APPLIES CAN STILL BE PARTIAL, and `cmp -s` cannot see it: one terminal
  # stripped and one left leaves half the defect and reads as a kill.
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s mutation was PARTIAL -- %s undecided site(s) survive, so the defect was only half reproduced\n' \
    "sc-mut-undec" "$(grep -c "$SC_A4" "$SCM4/self-update-gate.sh")"
else
  # The three sabotaged engines are rebuilt around the MUTATED gate: sc_engine copies the shipped
  # one, so the mutant has to be dropped in on top of each.
  sc_m4_got=""
  for sc_m4 in noman:nomanifest norow:norows nopre:nopre; do
    sc_m4_e="$(sc_engine "m4-${sc_m4%%:*}" "${sc_m4#*:}")"
    cp "$SCM4/self-update-gate.sh" "$sc_m4_e"
    sc_cons carry
    sc_m4_got="$sc_m4_got ${sc_m4%%:*}[$(sc_und "$sc_m4_e")]"
  done
  # ...and the consumer-world axis must be UNMOVED, which is what makes this m4's own assertion
  # rather than a second copy of m1's.
  sc_cons carry;  sc_m4_got="$sc_m4_got carried[$(sc_ack "$SCM4/self-update-gate.sh")]"
  sc_cons clean;  sc_m4_got="$sc_m4_got clean[$(sc_ack "$SCM4/self-update-gate.sh")]"
  sc_m4_want=" noman[row=1 acq=1 pf=0 und=1] norow[row=1 acq=1 pf=0 und=1] nopre[row=1 acq=1 pf=0 und=1]"
  sc_m4_want="$sc_m4_want carried[row=1 acq=0 pf=1 carry=1] clean[row=1 acq=1 pf=0 carry=0]"
  if [ "$sc_m4_got" = "$sc_m4_want" ]; then
    printf '  ok    %-16s KILLED (%s)\n' "sc-mut-undec" \
      "with the UNDECIDED terminals recording clean, the acquittal returns on all three -- printed beside the row saying the gate cannot tell"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: got=[%s] want=[%s]\n' "sc-mut-undec" "$sc_m4_got" "$sc_m4_want"
  fi
fi

fi
if sg ac; then
# --- ARM C: SELF-UPDATE-CARRY, one row per machinery path the consumer diverged on ----
#
# Step 2 justifies its autonomy -- no operator gate, auto-merged PR -- on the claim that the
# skill's own files are overwrite-safe, and then writes the WHOLE machinery set from
# `theirs`. For a machinery path the consumer has edited that destroys the edit with nothing
# anywhere reporting it. Filed on the reference consumer as
# PC-S330-STEP-2-HAS-NO-DISPOSITION-FOR-A-CONSUMER-MODIFIED-MACHINERY-PATH after that tree's
# own `.githooks/pre-push` came back BOTH-CHANGED on a live pull.
#
# ITS OWN MINIATURE DISTRIBUTION, for the same reason --safe-stop needed one: the seeded tree
# above DEFERS, and an advisory that has only ever been seen beside a DEFER cannot show that
# it leaves the verdict alone. These arms need a CARRY row and a SELF-UPDATE-OK in one output.
#
# THE POPULATION IS THE SUBJECT, NOT THE STRING `BOTH-CHANGED`. Four buckets record a consumer
# divergence on a machinery path, and a fix keyed on the modified-both-sides one catches a
# quarter of them while reading as complete. All four are seeded, and one of them carries no
# `->CLASSIFY` marker at all:
#
#   core/git-hooks/pre-push   M  BOTH-CHANGED->CLASSIFY                        literal entry
#   core/rules/edited.md      M  BOTH-CHANGED->CLASSIFY                        GLOBBED entry
#   core/rules/doomed.md      D  UPSTREAM-DELETED+consumer-modified->CLASSIFY  absent at THEIRS
#   core/schemas/fresh.json   A  BOTH-ADDED->CLASSIFY                          absent at BASE
#   core/scripts/reloc.sh     R  RELOCATE-MOVE+consumer-edited                 no marker
#
# ...and TWO NEAR-MISSES, which are the arms that a check emitting unconditionally fails.
# Each differs from a real offender in exactly one respect, so neither can be excluded by an
# accident of the tree:
#
#   core/rules/steady.md            machinery and in the pull, but the consumer is UNTOUCHED
#   .../steps/gate-validation.md    diverged, same BOTH-CHANGED bucket, but NOT machinery
AC="$(dirname "$DIST")/armc"
rm -rf "$AC"
mkdir -p "$AC/dist/core/rules" "$AC/dist/core/git-hooks" "$AC/dist/core/schemas" \
         "$AC/dist/core/scripts" "$AC/dist/core/skills/ai-dlc/steps" \
         "$AC/cons/.claude/rules" "$AC/cons/.claude/schemas" "$AC/cons/scripts" \
         "$AC/cons/.claude/skills/ai-dlc/steps" "$AC/cons/.githooks" \
         "$AC/clean/.claude/rules" "$AC/clean/.claude/skills/ai-dlc/steps" "$AC/clean/.githooks" \
         "$AC/cwd/core/rules" "$AC/cwd/core/schemas" "$AC/cwd/core/scripts/ai-dlc"

# A DECOY WORKING DIRECTORY, AND IT IS LOAD-BEARING FOR THE `set -f` MUTANT BELOW. The
# manifest entries are git PATHSPECS; without `set -f` the shell expands them against
# whatever CWD the caller happened to be in, BEFORE git sees them. That defect is therefore
# invisible from a CWD with no `core/` in it -- the globs stay literal and reach git intact --
# so a mutant run from an arbitrary directory would come back green against a real defect.
# These three files guarantee the expansion has something to bite on, which makes the kill a
# property of the mutation rather than of where the suite was launched from.
printf 'decoy\n' > "$AC/cwd/core/rules/decoy.md"
printf '{}\n'    > "$AC/cwd/core/schemas/decoy.json"
printf 'decoy\n' > "$AC/cwd/core/scripts/ai-dlc/decoy.sh"

git -C "$AC/dist" init -q
printf '0.1.0\n'          > "$AC/dist/VERSION"
printf 'hook base\n'      > "$AC/dist/core/git-hooks/pre-push"
printf 'doomed base\n'    > "$AC/dist/core/rules/doomed.md"
printf 'edited base\n'    > "$AC/dist/core/rules/edited.md"
printf 'steady base\n'    > "$AC/dist/core/rules/steady.md"
printf 'reloc base\n'     > "$AC/dist/core/scripts/reloc.sh"
gvv 1                     > "$AC/dist/core/skills/ai-dlc/steps/gate-validation.md"
git -C "$AC/dist" add -A >/dev/null 2>&1
git -C "$AC/dist" -c user.email=f@x -c user.name=f commit -qm base >/dev/null 2>&1
AC_BASE="$(git -C "$AC/dist" rev-parse HEAD)"

printf '0.2.0\n'          > "$AC/dist/VERSION"
printf 'hook theirs\n'    > "$AC/dist/core/git-hooks/pre-push"
rm -f                       "$AC/dist/core/rules/doomed.md"
printf 'edited theirs\n'  > "$AC/dist/core/rules/edited.md"
printf 'steady theirs\n'  > "$AC/dist/core/rules/steady.md"
printf '{"v":"theirs"}\n' > "$AC/dist/core/schemas/fresh.json"
{ gvv 1; printf 'theirs prose\n'; } > "$AC/dist/core/skills/ai-dlc/steps/gate-validation.md"
git -C "$AC/dist" add -A >/dev/null 2>&1
git -C "$AC/dist" -c user.email=f@x -c user.name=f commit -qm theirs >/dev/null 2>&1
AC_THEIRS="$(git -C "$AC/dist" rev-parse HEAD)"

# The diverged consumer. `core/scripts/reloc.sh` is UNCHANGED base->theirs on purpose: its
# bucket is level-triggered off the consumer's un-migrated copy, and leaving it out of the
# range also keeps the gating set empty so the verdict below is a clean OK.
printf 'hook LOCAL EDIT\n'            > "$AC/cons/.githooks/pre-push"
printf 'doomed LOCAL EDIT\n'          > "$AC/cons/.claude/rules/doomed.md"
printf 'edited LOCAL EDIT\n'          > "$AC/cons/.claude/rules/edited.md"
printf 'steady base\n'                > "$AC/cons/.claude/rules/steady.md"
printf '{"v":"LOCAL"}\n'              > "$AC/cons/.claude/schemas/fresh.json"
printf 'reloc LOCAL EDIT\n'           > "$AC/cons/scripts/reloc.sh"
{ gvv 1; printf 'consumer prose\n'; } > "$AC/cons/.claude/skills/ai-dlc/steps/gate-validation.md"

# The undiverged consumer: every copy is BASE, so every bucket is a plain apply. It holds no
# `scripts/` and no `schemas/` at all, which is the ordinary state -- the relocation pass and
# the added-file arm both have nothing to say about it.
printf 'hook base\n'   > "$AC/clean/.githooks/pre-push"
printf 'doomed base\n' > "$AC/clean/.claude/rules/doomed.md"
printf 'edited base\n' > "$AC/clean/.claude/rules/edited.md"
printf 'steady base\n' > "$AC/clean/.claude/rules/steady.md"
gvv 1                  > "$AC/clean/.claude/skills/ai-dlc/steps/gate-validation.md"

ac_carry() { # ac_carry <gate> <consumer> <cwd> -> CARRY paths, sorted, comma-terminated
  ( cd "$3" && bash "$1" "$AC/dist" "$AC_BASE" "$AC_THEIRS" "$2" 2>/dev/null ) |
    awk -F'\t' '$1 == "SELF-UPDATE-CARRY" {print $2}' | sort | tr '\n' ','
}
AC_ALL='core/git-hooks/pre-push,core/rules/doomed.md,core/rules/edited.md,core/schemas/fresh.json,core/scripts/reloc.sh,'

# SELF-PROBE, AND IT RUNS BEFORE THE ARMS IT UNDERWRITES. Both absence arms below are claims
# about a path the bucket derivation DID see and did NOT carry. If preclassify never bucketed
# them at all, those arms are absences over an empty set: they pass, they read exactly like a
# discriminating check, and they would go on passing against a gate that emits nothing.
AC_PRE="$(bash "$(dirname "$GATE")/preclassify.sh" \
             "$AC/dist" "$AC_BASE" "$AC_THEIRS" "$AC/cons" 2>/dev/null)"
ac_bucket() { printf '%s\n' "$AC_PRE" | awk -F'\t' -v p="$1" '$2 == p {print $4; exit}'; }

ss_assert "carry-probe-untouched" "$(ac_bucket core/rules/steady.md)" "UPSTREAM-ONLY" \
  "the untouched machinery near-miss IS in the bucket set, so its missing CARRY row is a decision"
ss_assert "carry-probe-nonmach" "$(ac_bucket core/skills/ai-dlc/steps/gate-validation.md)" \
  "BOTH-CHANGED->CLASSIFY" \
  "the non-machinery near-miss carries a REAL offender's bucket, so only membership can separate them"

AC_OUT="$(bash "$GATE" "$AC/dist" "$AC_BASE" "$AC_THEIRS" "$AC/cons" 2>&1)"

# The row names the CORE path and its detail names the CONSUMER path -- an advisory the
# operator cannot act on without both is a dead end of the kind advise_safe_stop exists to
# remove.
ss_assert "carry-names-path" \
  "$(printf '%s\n' "$AC_OUT" | awk -F'\t' \
      '$1 == "SELF-UPDATE-CARRY" && $2 == "core/git-hooks/pre-push" && $3 ~ /\.githooks\/pre-push/ {print "named"; exit}')" \
  "named" "a consumer-modified machinery path produces a CARRY row naming that path and the consumer's copy"

# THE ARM THAT SEPARATES THE SHIPPED FIX FROM THE PLAUSIBLE WRONG ONE. Exact set, not a
# count: a check keyed on `BOTH-CHANGED` alone reaches one of these five and every other
# assertion here still passes.
ss_assert "carry-population" "$(printf '%s\n' "$AC_OUT" | awk -F'\t' \
      '$1 == "SELF-UPDATE-CARRY" {print $2}' | sort | tr '\n' ',')" "$AC_ALL" \
  "every divergence bucket carries -- deleted-upstream, added-both-sides and the relocation row that has no ->CLASSIFY marker"

ss_assert "carry-quiet-untouched" \
  "$(printf '%s\n' "$AC_OUT" | awk -F'\t' '$1 == "SELF-UPDATE-CARRY" && $2 == "core/rules/steady.md"' | grep -c .)" \
  "0" "a machinery path in the pull the consumer has NOT touched carries no row"

ss_assert "carry-not-machinery" \
  "$(printf '%s\n' "$AC_OUT" | awk -F'\t' '$1 == "SELF-UPDATE-CARRY" && $2 ~ /steps\/gate-validation/' | grep -c .)" \
  "0" "a diverged NON-machinery path carries no row; this gate decides the machinery self-update only"

# ADVISORY, NOT VERDICT. Asserted as the exact verdict set: OK present AND no DEFER or
# UNDECIDED anywhere. A CARRY row that moved the verdict would stop a cycle that the rest of
# the slice can complete perfectly well.
ss_assert "carry-verdict-ok" \
  "$(printf '%s\n' "$AC_OUT" | awk -F'\t' \
      '$1 == "SELF-UPDATE-OK" || $1 == "SELF-UPDATE-DEFER" || $1 == "SELF-UPDATE-UNDECIDED" {print $1}' \
      | sort -u | tr '\n' ',')" \
  "SELF-UPDATE-OK," "the CARRY rows sit beside an unchanged SELF-UPDATE-OK -- the advisory does not move the verdict"

# THE ZERO CARRIES ITS CONTROL IN THE SAME BREATH. An undiverged consumer must produce no row,
# and a gate that produced no rows for any other reason would satisfy that identically -- so
# the bucket count on the SAME tree is asserted non-zero beside it.
ss_assert "carry-clean-consumer" "$(ac_carry "$GATE" "$AC/clean" "$DIR")" "" \
  "a consumer that has diverged on nothing gets no CARRY row at all"
ss_assert "carry-clean-control" \
  "$(bash "$(dirname "$GATE")/preclassify.sh" "$AC/dist" "$AC_BASE" "$AC_THEIRS" "$AC/clean" 2>/dev/null \
     | grep -c . | awk '{print ($1 > 0) ? "buckets" : "none"}')" \
  "buckets" "...and that zero is a decision, not a derivation that never ran"

# COST GUARD WITH AN OBSERVABLE. --safe-stop reads only DEFER and UNDECIDED, so a CARRY row
# cannot change any answer it computes, and emitting one per release candidate in the range
# buys nothing. Unlike advise_safe_stop's re-entry guard this one IS observable, so it gets an
# assertion rather than a comment.
ss_assert "carry-safe-stop" \
  "$(AI_DLC_GATE_IN_SAFE_STOP=1 bash "$GATE" "$AC/dist" "$AC_BASE" "$AC_THEIRS" "$AC/cons" 2>/dev/null \
     | grep -c 'SELF-UPDATE-CARRY')" \
  "0" "the advisory is suppressed inside a --safe-stop walk, where it could change nothing"

# CWD-INVARIANCE, ASSERTED RATHER THAN INHERITED. The pre-push runner drives this fixture from
# the repo root; the arms above therefore only ever see one CWD, and the pathspec-expansion
# defect the `set -f` mutant models is CWD-dependent by nature. Same gate, same tree, a
# directory built to make the expansion bite.
ss_assert "carry-cwd-invariant" "$(ac_carry "$GATE" "$AC/cons" "$AC/cwd")" "$AC_ALL" \
  "the shipped gate answers identically from a CWD whose own core/ would swallow every globbed entry"

# --- MUTANTS on arm C -----------------------------------------------------------------
#
# THE COPY NEEDS ITS SIBLINGS. Arm C resolves setup-sites.md and preclassify.sh by
# `dirname "$0"`, so a lone gate.sh in a bare directory has no machinery manifest and no
# bucket derivation. It would emit no CARRY row for want of a subject, every mutant would
# come back "killed", and the battery would be certifying silence.
#
# EACH MUTANT IS SCORED ON ITS EXACT CARRY SET, and the five sets are all distinct. Two
# mutants that produce the same output are one mutant: the first cut of this battery narrowed
# the bucket key and removed `set -f` and both collapsed to the same single row, so one of
# them was proving nothing. `core/rules/edited.md` is the seed that separates them -- a
# BOTH-CHANGED path reached through a GLOB, which survives the narrowed key and dies with the
# pathname expansion.
ac_mut() { # ac_mut <name> <sed-expr> -> path to the mutated gate, siblings beside it
  local d="$AC/m-$1"
  rm -rf "$d"; mkdir -p "$d"
  cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$d"/ 2>/dev/null
  sed "$2" "$GATE" > "$d/self-update-gate.sh"
  printf '%s\n' "$d/self-update-gate.sh"
}
ac_kill() { # ac_kill <label> <sed-expr> <want-carry-set> <why>
  local g got
  g="$(ac_mut "$1" "$2")"
  ASSERTIONS=$((ASSERTIONS + 1))
  if cmp -s "$GATE" "$g"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s mutation matched nothing, so the arm it scores is unproven\n' "$1"
    return
  fi
  got="$(ac_carry "$g" "$AC/cons" "$AC/cwd")"
  if [ "$got" = "$3" ]; then
    printf '  ok    %-16s KILLED (%s)\n' "$1" "$4"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: got=[%s] want=[%s]  %s\n' "$1" "$got" "$3" "$4"
  fi
}

# THE UNMUTATED CONTROL, and it is doing three jobs: the copy resolves its siblings, the decoy
# CWD does not change the answer, and the harness can still produce the FULL set -- so a
# mutant's shortfall below is attributable to the mutation. It is PRESENCE-shaped on purpose:
# a gate replaced by `exit 0` produces the empty set and fails it, where an arm asserting
# "nothing went wrong" would pass.
#
# It does NOT go through ac_kill: that helper refuses a sed matching nothing, which is the
# right refusal for a mutant and the wrong one for a control that must not be mutated at all.
# A control faked with a no-op substitution would trip exactly that guard.
rm -rf "$AC/m-control"; mkdir -p "$AC/m-control"
cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$AC/m-control"/ 2>/dev/null
ss_assert "armc-control" "$(ac_carry "$AC/m-control/self-update-gate.sh" "$AC/cons" "$AC/cwd")" \
  "$AC_ALL" \
  "an unmutated copy reproduces the FULL carry set from the decoy CWD, so a mutant's shortfall is the mutation"

ac_kill "armc-mut-bucket" \
  "s@^          \\*'->CLASSIFY'\\*|\\*consumer-edited\\*) ;;\$@          *'BOTH-CHANGED'*) ;;@" \
  'core/git-hooks/pre-push,core/rules/edited.md,' \
  "keying on the modified-both-sides bucket alone drops the deleted, the added and the relocated path"

# THE NEXT TWO MUTATE preclassify.sh, NOT THE GATE, AND THAT IS WHERE THEIR SUBJECT MOVED. This
# arm's population used to be resolved inline here; it is now `machinery_paths()`, eval'd out of
# preclassify.sh so that one derivation serves both the CARRY population and the `skill_commit`
# suppression scope. A mutant aimed at the gate's old inline copy matches nothing today, which
# reads as a broken fixture rather than as the relocation it is — and mutating the file the run
# actually RESOLVES is the whole point.
ac_mut_pre() { # ac_mut_pre <name> <sed-expr on preclassify.sh> -> path to a GATE beside it
  local d="$AC/mp-$1"
  rm -rf "$d"; mkdir -p "$d"
  cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$d"/ 2>/dev/null
  sed "$2" "$(dirname "$GATE")/preclassify.sh" > "$d/preclassify.sh"
  printf '%s\n' "$d"
}
ac_kill_pre() { # ac_kill_pre <label> <sed-expr> <want-carry-set> <why>
  local d got
  d="$(ac_mut_pre "$1" "$2")"
  ASSERTIONS=$((ASSERTIONS + 1))
  if cmp -s "$(dirname "$GATE")/preclassify.sh" "$d/preclassify.sh"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s mutation matched nothing in preclassify.sh, so the arm it scores is unproven\n' "$1"
    return
  fi
  # AND THE MUTANT MUST PARSE. `cmp -s` above proves the sed CHANGED something; it cannot tell a
  # mutation that alters the predicate from one that produces a file bash will not run. A
  # non-parsing mutant emits an EMPTY carry set, which this arm scores as SURVIVED -- so a
  # refactor that moves an anchored line into a multi-line command substitution reads as a
  # regression in the change under test, not as a broken mutant. MEASURED at 0.600.0: the first
  # batched form of `machinery_paths()` put `--with-tree="$BASE"` on the OPENING line of a
  # multi-line assignment, `armc-mut-base`'s line-delete then removed that opener, and the mutant
  # died with `syntax error: unexpected end of file` while this arm reported SURVIVED with no
  # tell. The check is one line and it names the state it found.
  if ! bash -n "$d/preclassify.sh" 2>/dev/null; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s the mutated preclassify.sh does NOT PARSE, so its empty carry set is a syntax error rather than the property this arm claims to score\n' "$1"
    return
  fi
  got="$(ac_carry "$d/self-update-gate.sh" "$AC/cons" "$AC/cwd")"
  if [ "$got" = "$3" ]; then
    printf '  ok    %-16s KILLED (%s)\n' "$1" "$4"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: got=[%s] want=[%s]  %s\n' "$1" "$got" "$3" "$4"
  fi
}

ac_kill_pre "armc-mut-setf" 's@^  set -f$@  : set -f removed@' \
  'core/git-hooks/pre-push,' \
  "without set -f the pathspecs expand against the CWD and the machinery set collapses to the entries carrying no glob character"

ac_kill_pre "armc-mut-base" '/--with-tree="\$BASE"/d' \
  'core/git-hooks/pre-push,core/rules/edited.md,core/schemas/fresh.json,core/scripts/reloc.sh,' \
  "resolving the globs at THEIRS alone loses the path deleted upstream, where the consumer's copy is the only copy left"

ac_kill "armc-mut-uncond" 's@^          \*) continue ;;$@          *) ;;@' \
  'core/git-hooks/pre-push,core/rules/doomed.md,core/rules/edited.md,core/rules/steady.md,core/schemas/fresh.json,core/scripts/reloc.sh,' \
  "dropping the bucket filter carries a machinery path the consumer never touched"

# THE REMAINING TWO ARE FOR ARMS THAT PASS AGAINST A SUBJECT THAT EMITS NOTHING. Measured, by
# running this fixture against a gate replaced with `exit 0`: carry-quiet-untouched,
# carry-not-machinery, carry-clean-consumer and carry-safe-stop all reported ok. They are
# absence-shaped, so only a mutant on their OWN guard establishes that they discriminate --
# and arm C has THREE independent guards, not one. The bucket filter above reaches the first;
# these reach the other two, and neither is covered by any mutant already here: dropping the
# bucket filter does NOT carry the non-machinery path, and dropping the membership test does
# NOT carry the untouched one.
ac_kill "armc-mut-member" \
  's@^        gate_has_line "\$C_PATHS" "\$c_path" || continue$@        true || continue@' \
  'core/git-hooks/pre-push,core/rules/doomed.md,core/rules/edited.md,core/schemas/fresh.json,core/scripts/reloc.sh,core/skills/ai-dlc/steps/gate-validation.md,' \
  "dropping the machinery-membership test carries a diverged path this gate does not decide"

# Scored under the env var rather than without it, because that IS the guard's subject: the
# arm it backs asserts an absence that only exists inside a --safe-stop walk.
AC_M6="$(ac_mut safestop 's@^if \[ -z "\${AI_DLC_GATE_IN_SAFE_STOP:-}" \]; then$@if true; then@')"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$GATE" "$AC_M6"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s mutation matched nothing, so the arm it scores is unproven\n' "armc-mut-safestop"
else
  ac_got6="$( AI_DLC_GATE_IN_SAFE_STOP=1; export AI_DLC_GATE_IN_SAFE_STOP
              ac_carry "$AC_M6" "$AC/cons" "$AC/cwd" )"
  if [ "$ac_got6" = "$AC_ALL" ]; then
    printf '  ok    %-16s KILLED (%s)\n' "armc-mut-safestop" \
      "removing the re-entry guard emits the whole advisory inside a --safe-stop walk"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: got=[%s] want=[%s]  %s\n' "armc-mut-safestop" "$ac_got6" "$AC_ALL" \
      "removing the re-entry guard must emit the whole advisory inside a --safe-stop walk"
  fi
fi

fi
if sg su; then
# --- ARM D: THE THIRD SHA. A SPLIT PULL LEAVES THE CONSUMER AT A REF NEITHER ENDPOINT KNOWS --
#
# Arm C above reads preclassify's buckets and carries every machinery path that shows a consumer
# divergence. That is correct only if the bucket derivation can TELL a divergence from a carry.
# It could not. Every `ours_h` comparison in preclassify's M and A branches measured the consumer
# against `base` and `theirs` alone, and on a SPLIT pull step 2's autonomous self-update has
# already rewritten the machinery set from an INTERMEDIATE ref -- so the consumer's copy is
# byte-identical to the distribution at a THIRD sha, the stamp's `skill_commit`, and against that
# pair it reads as a consumer edit. The path fell to a `->CLASSIFY` bucket, arm C carried it, and
# `apply.sh`'s own `*CLASSIFY*` arm -- which never invokes this gate -- turned it into a
# `WORKLIST semantic-merge` row that WITHHELD the re-stamp. Filed by the reference consumer as
# `PC-S307-SELF-UPDATE-CARRY-ARM-HAS-NO-CORE-AT-SELF-UPDATE-SUPPRESSION`.
#
# THE SUBJECT IS preclassify.sh AND ARM C IS THE READER, which is why these arms live here rather
# than in a new directory: this fixture is the only one that drives both halves of that join in
# one run, and the assertion that matters is that arm C goes QUIET without a line of its own
# changing behaviour.
#
# THE PREDICATE IS `at_self_update`, NOT AN `elif`, and the mutants below are keyed on the
# function for that reason. It has THREE conjuncts and each is a separate way to be wrong:
# a self-update ref exists, the consumer's bytes match the distribution AT that ref, and the path
# is machinery or sits under `core/fixtures/` -- where a copy at upstream's own bytes for a ref
# neither endpoint names holds nothing consumer-authored. Two branch arms call it.
#
# ITS OWN MINIATURE DISTRIBUTION, WITH THREE REFS. Every tree above has exactly two, and a two-ref
# tree cannot express the defect at all -- the third sha IS the bug.
#
#   core/rules/carried.md    M  ours == dist@MID, differs at BASE and THEIRS  -> UPSTREAM-ONLY
#   core/rules/added.md      A  absent at BASE, ours == dist@MID              -> UPSTREAM-ONLY-ADD
#   core/rules/edited.md     M  ours matches NOTHING -- a real consumer edit   -> ->CLASSIFY
#   core/rules/steady.md     M  ours == BASE                                  -> UPSTREAM-ONLY
#   core/rules/indexed.md    M  ours == the dist repo INDEX and no ref         -> ->CLASSIFY
#   core/rules/doomed.md     D  deleted at THEIRS, ours == dist@MID           -> ->CLASSIFY
#   core/skills/ai-dlc/artifact-path-grammar.md
#                            M  ours == dist@MID but NOT machinery            -> ->CLASSIFY
#   core/session-driver/modeflip.sh  content fixed, 644->755, consumer HAS the bit -> ALREADY-AT-THEIRS
#   core/session-driver/modeneed.sh  same, consumer LACKS the bit                  -> UPSTREAM-ONLY
#   core/fixtures/fx-mod/run.sh   M  ours == dist@MID, NOT machinery            -> UPSTREAM-ONLY
#   core/fixtures/fx-add/run.sh   A  born at MID, changed at THEIRS, ours == MID -> UPSTREAM-ONLY-ADD
#   core/fixtures/fx-edit/run.sh  M  ours matches NOTHING -- a local fixture edit -> ->CLASSIFY
#
# THE NEGATIVES SIT IN THE SAME TREE AND THE SAME RUN AS THE POSITIVES, and there are three of
# them, each differing from a real carry in exactly ONE respect. `edited.md` differs in the BYTES.
# `artifact-path-grammar.md` differs only in MEMBERSHIP -- same status, same three-way hash
# relation, byte-identical to the distribution at the same ref, and not machinery. `doomed.md`
# differs only in STATUS. A near-miss run separately is an ADJACENT input: it can only ask whether
# the arm fires, never whether it fires on the RIGHT paths, and this repo has shipped that mistake
# and paid three rounds for it. Every arm scores one EXACT bucket set, so a mutant that widens the
# predicate cannot pass by satisfying the positives alone.
#
# `artifact-path-grammar.md` IS THE SCOPING SUBJECT AND NOTHING ELSE REACHES IT. Unscoped, a
# non-machinery core file at an intermediate ref is reclassified to UPSTREAM-ONLY and `apply.sh`
# writes theirs over it with no operator review -- an exemption with no reason attached, since
# only step 2's two terms have a story for how a file got to that ref. It is the ONLY seeded path
# that is neither machinery nor a fixture file, so dropping the `is_machinery` conjunct moves this
# cell and no other.
#
# THE THREE `core/fixtures/` SEEDS ARE THE FIXTURE DISJUNCT'S SUBJECT, and none of them is
# machinery (asserted below), so only that disjunct can carry `fx-mod` and `fx-add` out of
# ->CLASSIFY. `fx-edit` is the bytes near-miss inside the same scope: the disjunct must not
# exempt a fixture the consumer actually edited. `fx-add` changes again at THEIRS, or the
# `ours_h = theirs_h` arm would claim it before the predicate is reached. Filed by the reference
# consumer, where five fixture files held at the skill_commit blob read BOTH-CHANGED->CLASSIFY.
#
# `doomed.md` CARRIES THE DELIBERATE ABSENCE. There is no `D`-branch arm, measured rather than
# forgotten, and its verdict must stay `UPSTREAM-DELETED+consumer-modified->CLASSIFY`. Asserting
# it here means a D-branch arm added later cannot land silently.
#
# `indexed.md` IS THE INDEX HAZARD'S SUBJECT AND IT EXISTS FOR NOTHING ELSE. `self_update_hash`
# returns a sentinel rather than calling `blob_hash ""` because an empty rev makes the underlying
# `git rev-parse -q --verify ":<path>"` read the dist repo's INDEX, which resolves for every
# tracked path. The seed stages a content for that path that is committed at NO ref and gives the
# consumer the same bytes -- so a build that drops the sentinel matches on it and NOTHING ELSE
# does. Without that staged blob the hazard is unreachable: a clean index answers with THEIRS,
# which an earlier arm has already claimed.
#
# `modeflip.sh` IS THE ORDERING SUBJECT. All three content hashes are equal there, so the
# predicate holds -- and `ALREADY-AT-THEIRS`, which carries the `mode_at_theirs` conjunct, is the
# only arm that can tell a consumer holding the exec bit from one that still needs it. Moving the
# new arm above it answers UPSTREAM-ONLY for both, which is the regression the shipped comment
# warns about and which no other seeded path can see.
SU="$(dirname "$DIST")/su"
rm -rf "$SU"
mkdir -p "$SU/dist/core/rules" "$SU/dist/core/session-driver" "$SU/dist/core/skills/ai-dlc" \
         "$SU/dist/core/fixtures/fx-mod" "$SU/dist/core/fixtures/fx-add" "$SU/dist/core/fixtures/fx-edit" \
         "$SU/cons/.claude/rules" "$SU/cons/.claude/session-driver" "$SU/cons/.claude/skills/ai-dlc" "$SU/cons/.githooks" \
         "$SU/cons/tests/fixtures/fx-mod" "$SU/cons/tests/fixtures/fx-add" "$SU/cons/tests/fixtures/fx-edit" \
         "$SU/nostamp/.claude/rules" "$SU/nostamp/.claude/session-driver" "$SU/nostamp/.claude/skills/ai-dlc" "$SU/nostamp/.githooks" \
         "$SU/nostamp/tests/fixtures/fx-mod" "$SU/nostamp/tests/fixtures/fx-add" "$SU/nostamp/tests/fixtures/fx-edit"

# A probe repo is only a probe if git agrees. `GIT_DIR` outranks `git -C`, so an exported one
# would send every write below into whatever repository the caller was standing in.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
git -C "$SU/dist" init -q
# Compared PHYSICALLY on both sides. `$TMPDIR` carries a trailing slash and macOS resolves it
# through /private, so a textual compare here fails on a probe that is perfectly isolated -- which
# would be an arm that fires on the state it exists to bless.
ss_assert "su-probe-isolated" "$(git -C "$SU/dist" rev-parse --absolute-git-dir 2>/dev/null)" \
  "$( cd "$SU/dist" && pwd -P )/.git" \
  "the probe repo is its own, so nothing below can reach the caller's repository"

su_commit() { git -C "$SU/dist" add -A >/dev/null 2>&1
              git -C "$SU/dist" -c user.email=f@x -c user.name=f commit -qm "$1" >/dev/null 2>&1
              git -C "$SU/dist" rev-parse HEAD; }

printf '0.1.0\n'        > "$SU/dist/VERSION"
printf 'carried base\n' > "$SU/dist/core/rules/carried.md"
printf 'edited base\n'  > "$SU/dist/core/rules/edited.md"
printf 'steady base\n'  > "$SU/dist/core/rules/steady.md"
printf 'indexed base\n' > "$SU/dist/core/rules/indexed.md"
printf 'doomed base\n'  > "$SU/dist/core/rules/doomed.md"
printf 'grammar base\n' > "$SU/dist/core/skills/ai-dlc/artifact-path-grammar.md"
printf 'driver body\n'  > "$SU/dist/core/session-driver/modeflip.sh"
printf 'driver body\n'  > "$SU/dist/core/session-driver/modeneed.sh"
printf 'fx-mod base\n'  > "$SU/dist/core/fixtures/fx-mod/run.sh"
printf 'fx-edit base\n' > "$SU/dist/core/fixtures/fx-edit/run.sh"
chmod 644 "$SU/dist/core/session-driver/modeflip.sh" "$SU/dist/core/session-driver/modeneed.sh"
SU_BASE="$(su_commit base)"

# MID -- the ref step 2's autonomous self-update wrote the machinery set from. A release commit,
# because a VERSION is the only state a stamp can record. `added.md` is born here, which is what
# puts it in the `A` branch with no `base_h` arm able to catch it.
printf '0.2.0\n'        > "$SU/dist/VERSION"
printf 'carried mid\n'  > "$SU/dist/core/rules/carried.md"
printf 'edited mid\n'   > "$SU/dist/core/rules/edited.md"
printf 'steady mid\n'   > "$SU/dist/core/rules/steady.md"
printf 'indexed mid\n'  > "$SU/dist/core/rules/indexed.md"
printf 'doomed mid\n'   > "$SU/dist/core/rules/doomed.md"
printf 'added mid\n'    > "$SU/dist/core/rules/added.md"
printf 'grammar mid\n'  > "$SU/dist/core/skills/ai-dlc/artifact-path-grammar.md"
printf 'fx-mod mid\n'   > "$SU/dist/core/fixtures/fx-mod/run.sh"
printf 'fx-add mid\n'   > "$SU/dist/core/fixtures/fx-add/run.sh"
printf 'fx-edit mid\n'  > "$SU/dist/core/fixtures/fx-edit/run.sh"
chmod 755 "$SU/dist/core/session-driver/modeflip.sh" "$SU/dist/core/session-driver/modeneed.sh"
SU_MID="$(su_commit mid)"

printf '0.3.0\n'          > "$SU/dist/VERSION"
printf 'carried theirs\n' > "$SU/dist/core/rules/carried.md"
printf 'edited theirs\n'  > "$SU/dist/core/rules/edited.md"
printf 'steady theirs\n'  > "$SU/dist/core/rules/steady.md"
printf 'indexed theirs\n' > "$SU/dist/core/rules/indexed.md"
printf 'added theirs\n'   > "$SU/dist/core/rules/added.md"
printf 'grammar theirs\n' > "$SU/dist/core/skills/ai-dlc/artifact-path-grammar.md"
printf 'fx-mod theirs\n'  > "$SU/dist/core/fixtures/fx-mod/run.sh"
printf 'fx-add theirs\n'  > "$SU/dist/core/fixtures/fx-add/run.sh"
printf 'fx-edit theirs\n' > "$SU/dist/core/fixtures/fx-edit/run.sh"
rm -f "$SU/dist/core/rules/doomed.md"
SU_THEIRS="$(su_commit theirs)"

# Committed at no ref, present only in the index. See `indexed.md` above.
printf 'indexed STAGED\n' > "$SU/dist/core/rules/indexed.md"
git -C "$SU/dist" add core/rules/indexed.md >/dev/null 2>&1

# A TREE sha resolves as an OBJECT and not as a COMMIT, and `<tree>:<path>` resolves a blob
# perfectly well -- so it is the input that separates the shipped `^{commit}` guard from its
# absence. An all-zeros sha cannot do that job: `blob_hash` answers MISSING for it either way.
SU_TREE="$(git -C "$SU/dist" rev-parse "${SU_MID}^{tree}")"

# Writes NO stamp. `$SU/nostamp` is this tree with nothing else done to it, and `$SU/cons` gets
# whichever stamp the arm under test needs; the two are byte-identical apart from that one file,
# so the gate differential below is the stamp read and nothing else.
su_seed_cons() {
  printf 'carried mid\n'       > "$1/.claude/rules/carried.md"
  printf 'edited LOCAL EDIT\n' > "$1/.claude/rules/edited.md"
  printf 'steady base\n'       > "$1/.claude/rules/steady.md"
  printf 'indexed STAGED\n'    > "$1/.claude/rules/indexed.md"
  printf 'added mid\n'         > "$1/.claude/rules/added.md"
  printf 'doomed mid\n'        > "$1/.claude/rules/doomed.md"
  printf 'grammar mid\n'       > "$1/.claude/skills/ai-dlc/artifact-path-grammar.md"
  printf 'fx-mod mid\n'        > "$1/tests/fixtures/fx-mod/run.sh"
  printf 'fx-add mid\n'        > "$1/tests/fixtures/fx-add/run.sh"
  printf 'fx-edit LOCAL EDIT\n' > "$1/tests/fixtures/fx-edit/run.sh"
  printf 'driver body\n' > "$1/.claude/session-driver/modeflip.sh"; chmod 755 "$1/.claude/session-driver/modeflip.sh"
  printf 'driver body\n' > "$1/.claude/session-driver/modeneed.sh"; chmod 644 "$1/.claude/session-driver/modeneed.sh"
  printf '#!/usr/bin/env bash\n# invokes no scripts/ai-dlc/ validator, so the gating set is empty\nexit 0\n' \
    > "$1/.githooks/pre-push"; chmod 755 "$1/.githooks/pre-push"
}
su_seed_cons "$SU/cons"
su_seed_cons "$SU/nostamp"

su_stamp() { # su_stamp <skill_commit> ; `-` removes the stamp, `+` writes one with no such field
  case "$1" in
    -) rm -f "$SU/cons/.claude/.ai-dlc-version" ;;
    +) printf 'version: 0.1.0\ncommit: %s\nskill_version: 0.2.0\n' "$SU_BASE" \
         > "$SU/cons/.claude/.ai-dlc-version" ;;
    *) printf 'version: 0.1.0\ncommit: %s\nskill_version: 0.2.0\nskill_commit: %s\n' "$SU_BASE" "$1" \
         > "$SU/cons/.claude/.ai-dlc-version" ;;
  esac
}

su_buckets() { # su_buckets <preclassify> <consumer> -> "<core-path>=<bucket>," sorted
  bash "$1" "$SU/dist" "$SU_BASE" "$SU_THEIRS" "$2" 2>/dev/null |
    awk -F'\t' '$2 ~ /^core\// {print $2 "=" $4}' | sort | tr '\n' ','
}

# Composed cell by cell rather than written out eight times: every expectation below differs from
# SU_LIVE in one or two cells, and spelling each set in full hides which cell a mutant moved.
SU_A_ADD='core/rules/added.md=UPSTREAM-ONLY-ADD,'
SU_A_CL='core/rules/added.md=BOTH-ADDED->CLASSIFY,'
SU_CA_UO='core/rules/carried.md=UPSTREAM-ONLY,'
SU_CA_CL='core/rules/carried.md=BOTH-CHANGED->CLASSIFY,'
SU_DO='core/rules/doomed.md=UPSTREAM-DELETED+consumer-modified->CLASSIFY,'
SU_ED_CL='core/rules/edited.md=BOTH-CHANGED->CLASSIFY,'
SU_ED_UO='core/rules/edited.md=UPSTREAM-ONLY,'
SU_IX_CL='core/rules/indexed.md=BOTH-CHANGED->CLASSIFY,'
SU_IX_UO='core/rules/indexed.md=UPSTREAM-ONLY,'
SU_ST='core/rules/steady.md=UPSTREAM-ONLY,'
SU_MF_OK='core/session-driver/modeflip.sh=ALREADY-AT-THEIRS,'
SU_MF_UO='core/session-driver/modeflip.sh=UPSTREAM-ONLY,'
SU_MN='core/session-driver/modeneed.sh=UPSTREAM-ONLY,'
SU_GR_CL='core/skills/ai-dlc/artifact-path-grammar.md=BOTH-CHANGED->CLASSIFY,'
SU_GR_UO='core/skills/ai-dlc/artifact-path-grammar.md=UPSTREAM-ONLY,'
# The fixture cells sort FIRST (`core/fixtures/` < `core/rules/`), so each set opens with them.
SU_FA_ADD='core/fixtures/fx-add/run.sh=UPSTREAM-ONLY-ADD,'
SU_FA_CL='core/fixtures/fx-add/run.sh=BOTH-ADDED->CLASSIFY,'
SU_FE_CL='core/fixtures/fx-edit/run.sh=BOTH-CHANGED->CLASSIFY,'
SU_FE_UO='core/fixtures/fx-edit/run.sh=UPSTREAM-ONLY,'
SU_FM_UO='core/fixtures/fx-mod/run.sh=UPSTREAM-ONLY,'
SU_FM_CL='core/fixtures/fx-mod/run.sh=BOTH-CHANGED->CLASSIFY,'
SU_FX_LIVE="${SU_FA_ADD}${SU_FE_CL}${SU_FM_UO}"                  # the disjunct reaches both fixture positives
SU_FX_INERT="${SU_FA_CL}${SU_FE_CL}${SU_FM_CL}"                  # no fixture is exempted
SU_TAIL="${SU_DO}${SU_ED_CL}${SU_IX_CL}${SU_ST}${SU_MF_OK}${SU_MN}${SU_GR_CL}"
SU_LIVE="${SU_FX_LIVE}${SU_A_ADD}${SU_CA_UO}${SU_TAIL}"          # both branch arms reach their subject
SU_INERT="${SU_FX_INERT}${SU_A_CL}${SU_CA_CL}${SU_TAIL}"         # the predicate is unreachable
SU_NO_M="${SU_FA_ADD}${SU_FE_CL}${SU_FM_CL}${SU_A_ADD}${SU_CA_CL}${SU_TAIL}"   # the M-branch arm is gone
SU_NO_A="${SU_FA_CL}${SU_FE_CL}${SU_FM_UO}${SU_A_CL}${SU_CA_UO}${SU_TAIL}"     # the A-branch arm is gone
SU_WIDE="${SU_FA_ADD}${SU_FE_UO}${SU_FM_UO}${SU_A_ADD}${SU_CA_UO}${SU_DO}${SU_ED_UO}${SU_IX_UO}${SU_ST}${SU_MF_OK}${SU_MN}${SU_GR_CL}"
SU_UNSCOPED="${SU_FX_LIVE}${SU_A_ADD}${SU_CA_UO}${SU_DO}${SU_ED_CL}${SU_IX_CL}${SU_ST}${SU_MF_OK}${SU_MN}${SU_GR_UO}"
SU_ORDER="${SU_FX_LIVE}${SU_A_ADD}${SU_CA_UO}${SU_DO}${SU_ED_CL}${SU_IX_CL}${SU_ST}${SU_MF_UO}${SU_MN}${SU_GR_CL}"
SU_IDXH="${SU_FX_INERT}${SU_A_CL}${SU_CA_CL}${SU_DO}${SU_ED_CL}${SU_IX_UO}${SU_ST}${SU_MF_OK}${SU_MN}${SU_GR_CL}"
SU_NOFX="${SU_FX_INERT}${SU_A_ADD}${SU_CA_UO}${SU_TAIL}"         # the fixture disjunct is gone, machinery untouched

# PRECONDITION. The mode seed is the whole subject of the ordering mutant, and git records a mode
# only if the filesystem carried one -- a tree where both refs read 100644 makes that mutant
# unkillable and reads exactly like a mutant that was scored.
ss_assert "su-seed-mode" \
  "$(git -C "$SU/dist" ls-tree "$SU_BASE" -- core/session-driver/modeflip.sh | cut -d' ' -f1)->$(git -C "$SU/dist" ls-tree "$SU_THEIRS" -- core/session-driver/modeflip.sh | cut -d' ' -f1)" \
  "100644->100755" "the seeded mode really flips base->theirs, so ALREADY-AT-THEIRS has a subject"

# PRECONDITION. The staged blob is the index hazard's only subject, and a `git add` that silently
# did nothing would leave the index answering THEIRS -- a value an earlier arm already claims.
ss_assert "su-seed-index" \
  "$(git -C "$SU/dist" rev-parse -q --verify ':core/rules/indexed.md')" \
  "$(git -C "$SU/dist" hash-object "$SU/cons/.claude/rules/indexed.md")" \
  "the dist INDEX holds the consumer's bytes for indexed.md at no ref at all"
ss_assert "su-seed-index-control" \
  "$(git -C "$SU/dist" rev-parse -q --verify ":core/rules/indexed.md" 2>/dev/null | grep -cx "$(git -C "$SU/dist" rev-parse "${SU_THEIRS}:core/rules/indexed.md")")" \
  "0" "...and it is NOT the blob at theirs, so a match on it can only have come from the index"

# PRECONDITION FOR THE SCOPING NEGATIVE. `artifact-path-grammar.md` separates the shipped arm from
# an unscoped one ONLY if it is genuinely outside the machinery set while every other seeded path
# is inside it. Both halves are derived from the shipped function rather than read off the
# manifest by eye, and both are asserted, because an arm that named a machinery path by mistake
# would score the unscoped mutant as surviving and read as a coverage gap.
#
# LOADED THE WAY THE GATE LOADS IT, out of a directory holding preclassify's siblings, and NOT by
# eval-ing into this shell. `machinery_paths()` resolves its manifest as `$(dirname "$0")/…`, and
# `$0` is not assignable — an eval here reads THIS fixture's directory, finds no setup-sites.md,
# returns EMPTY, and both arms below then score a zero that means nothing. Measured: the first cut
# did exactly that, and only the control arm caught it.
mkdir -p "$SU/mach"
cp "$(dirname "$SU_PC")"/*.sh "$(dirname "$SU_PC")"/*.md "$SU/mach"/ 2>/dev/null
cat > "$SU/mach/list-machinery.sh" <<'MACHEOF'
DIST="$1"; BASE="$2"; THEIRS="$3"
eval "$(awk '/^machinery_paths\(\) \{/,/^\}/' "$(dirname "$0")/preclassify.sh")"
machinery_paths
MACHEOF
SU_MACH="$(bash "$SU/mach/list-machinery.sh" "$SU/dist" "$SU_BASE" "$SU_THEIRS" 2>/dev/null)"
ss_assert "su-seed-scope" \
  "$(printf '%s\n' "$SU_MACH" | grep -cx 'core/skills/ai-dlc/artifact-path-grammar.md')" "0" \
  "the scoping near-miss is NOT machinery, so only the is_machinery conjunct can separate it"
ss_assert "su-seed-scope-control" \
  "$(printf '%s\n' "$SU_MACH" | grep -cx 'core/rules/carried.md')" "1" \
  "...and the carried path IS, so that zero is a membership decision rather than an empty set"
ss_assert "su-seed-fx-scope" \
  "$(printf '%s\n' "$SU_MACH" | grep -c '^core/fixtures/')" "0" \
  "no seeded fixture file is machinery, so only the core/fixtures disjunct can exempt one"

# THE POSITIVES AND THEIR THREE NEGATIVES, ONE EXACT SET, ONE RUN. Both branch arms, the D-branch
# deliberate absence, the bytes near-miss and the membership near-miss are all in this one cell
# comparison.
su_stamp "$SU_MID"
ss_assert "su-carried" "$(su_buckets "$SU_PC" "$SU/cons")" "$SU_LIVE" \
  "M and A both suppress a copy identical to the distribution at the stamp's skill_commit, while a real edit, a non-machinery path and a deleted path in the same tree all still reach ->CLASSIFY"

# THE THREE GUARDS ON THE STAMP READ, EACH WITH ITS OWN SUBJECT. In every one of them the arms must
# be unreachable and every OTHER bucket unchanged -- which is why the whole set is asserted rather
# than the two cells. A guard that also moved `steady.md` or `modeflip.sh` would be a regression
# wearing the shape of a fix.
ss_assert "su-guard-nostamp" "$(su_buckets "$SU_PC" "$SU/nostamp")" "$SU_INERT" \
  "no stamp at all: nothing to read, so both arms are inert and every other bucket is untouched"
su_stamp +
ss_assert "su-guard-nofield" "$(su_buckets "$SU_PC" "$SU/cons")" "$SU_INERT" \
  "a stamp with no skill_commit field -- the ordinary pre-split shape -- is inert too"
su_stamp "$SU_BASE"
ss_assert "su-guard-eqbase" "$(su_buckets "$SU_PC" "$SU/cons")" "$SU_INERT" \
  "skill_commit == commit: no self-update hop ran, so the question collapses into the base_h arm"
su_stamp "$SU_TREE"
ss_assert "su-guard-unresolvable" "$(su_buckets "$SU_PC" "$SU/cons")" "$SU_INERT" \
  "a skill_commit this distribution cannot resolve to a COMMIT compares against nothing"

# --- MUTANTS on the preclassify predicate ---------------------------------------------
#
# THE COPY NEEDS ITS SIBLINGS, for the same reason arm C's battery does: preclassify resolves
# setup-sites.md by `dirname "$0"` in TWO places -- the setup-substitution list and
# `machinery_paths()` -- and a lone copy in a bare directory derives an empty machinery set, which
# makes every arm inert and scores every mutant as killed. Mutated with awk rather than sed
# because two of these REORDER or REWRITE a block, which sed cannot express portably, and a
# battery whose mutants are written two ways is a battery with two things to review.
#
# EACH IS SCORED ON ITS EXACT BUCKET SET AND THE SEVEN SETS ARE DISTINCT. Two mutants producing
# the same output are one mutant, and every seed above earns its place by separating one pair.
su_mut() { # su_mut <name> <awk-program> -> path to the mutated preclassify, siblings beside it
  local d="$SU/m-$1"
  rm -rf "$d"; mkdir -p "$d"
  cp "$(dirname "$SU_PC")"/*.sh "$(dirname "$SU_PC")"/*.md "$d"/ 2>/dev/null
  awk "$2" "$SU_PC" > "$d/preclassify.sh" 2>/dev/null
  printf '%s\n' "$d/preclassify.sh"
}
su_kill() { # su_kill <label> <awk> <stamp> <want-set> <why>
  local g got
  g="$(su_mut "$1" "$2")"
  ASSERTIONS=$((ASSERTIONS + 1))
  if cmp -s "$SU_PC" "$g"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s mutation matched nothing, so the arm it scores is unproven\n' "$1"
    return
  fi
  su_stamp "$3"
  got="$(su_buckets "$g" "$SU/cons")"
  if [ "$got" = "$4" ]; then
    printf '  ok    %-16s KILLED (%s)\n' "$1" "$5"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: got=[%s] want=[%s]  %s\n' "$1" "$got" "$4" "$5"
  fi
}

# The two branch call sites open with byte-identical text and differ only in the bucket they
# assign, so each mutation is anchored on the BUCKET, never on the shared condition. Anchoring on
# `at_self_update` alone edits both, moves two cells, and scores a kill neither arm earned.
SU_M_NOARM_M='index($0,"at_self_update \"$path\" \"$ours_h\"") && index($0,"bucket=\"UPSTREAM-ONLY\"") { next } { print }'
SU_M_NOARM_A='index($0,"at_self_update \"$path\" \"$ours_h\"") && index($0,"bucket=\"UPSTREAM-ONLY-ADD\"") { next } { print }'
SU_M_WIDE='index($0,"[ \"$2\" = \"$(self_update_hash \"$1\")\" ] || return 1") { next } { print }'
SU_M_UNSCOPED='{ if (index($0,"at_self_update() {")) inf=1
  if (inf && index($0,"  is_machinery \"$1\"")) { print "  return 0"; inf=0; next } print }'
# Anchored on the disjunct's own `case` line, which appears once in the file; the mutant keeps
# the machinery conjunct and the content match, so only the fixture cells can move.
SU_M_NOFX='index($0,"  case \"$1\" in core/fixtures/*/*) return 0 ;; esac") { next } { print }'
SU_M_ORDER='{ L[NR]=$0
  if (index($0,"at_self_update \"$path\" \"$ours_h\"") && index($0,"bucket=\"UPSTREAM-ONLY\"")) A=NR
  if (index($0,"ALREADY-AT-THEIRS") && index($0,"mode_at_theirs")) B=NR }
END { if (!A || !B) exit 1
  for (i=1;i<=NR;i++) { if (i==A) continue; if (i==B) print L[A]; print L[i] } }'
SU_M_UNRES='{ if (index($0,"if [ -n \"$SELF_UPDATE_REF\" ] \\")) d=4; if (d>0) { d--; next } print }'
SU_M_EQBASE='index($0,"= \"$BASE\" ] && SELF_UPDATE_REF=") { next } { print }'
# THE SENTINEL IS THE THIRD LAYER, so a mutant that removes it ALONE changes nothing and would
# score as a survivor. Two guards above it already refuse an empty ref -- `at_self_update`'s own
# first conjunct, and the fact that MACHINERY_PATHS is only populated when a ref exists, which
# makes `is_machinery` reject everything. Both layers are stripped in the pair below; the first
# keeps the sentinel and the second does not, so the difference between them is the sentinel and
# nothing else.
SU_M_LAYERS='index($0,"[ -n \"$SELF_UPDATE_REF\" ] && MACHINERY_PATHS=") { print "MACHINERY_PATHS=\"$(machinery_paths)\""; next }
index($0,"at_self_update() {") { print; getline; next }
{ print }'
SU_M_INDEX='index($0,"[ -n \"$SELF_UPDATE_REF\" ] && MACHINERY_PATHS=") { print "MACHINERY_PATHS=\"$(machinery_paths)\""; next }
index($0,"at_self_update() {") { print; getline; next }
index($0,"NO-SELF-UPDATE-REF") { next }
{ print }'
# THE SECOND SPELLING OF THE CORRECT PREDICATE, and it must PASS every arm above. A fixture that
# rejects a competent author's other phrasing is as broken as one that accepts a regression: it
# turns the next repair into a fixture edit and the author into someone who edits fixtures to go
# green. This one streams the blob and hashes stdin instead of comparing two recorded blob shas,
# and it orders its conjuncts the other way round.
SU_M_SPELL='index($0,"at_self_update() {") {
  print "at_self_update() { # <core-rel-path> <ours-hash>"
  print "  [ -n \"$SELF_UPDATE_REF\" ] || return 1"
  print "  case \"$1\" in core/fixtures/?*/?*) ;; *) is_machinery \"$1\" || return 1 ;; esac"
  print "  git -C \"$DIST\" show \"${SELF_UPDATE_REF}:$1\" 2>/dev/null | git -C \"$DIST\" hash-object --stdin | grep -qxF \"$2\""
  print "}"
  s=6; next }
s>0 { s--; next }
{ print }'

# THE UNMUTATED CONTROL, and it is PRESENCE-shaped: a copy that cannot resolve its siblings, or
# one replaced by `exit 0`, emits the EMPTY set and fails this outright. An arm asserting "nothing
# went wrong" would pass for both.
rm -rf "$SU/m-control"; mkdir -p "$SU/m-control"
cp "$(dirname "$SU_PC")"/*.sh "$(dirname "$SU_PC")"/*.md "$SU/m-control"/ 2>/dev/null
su_stamp "$SU_MID"
ss_assert "su-mut-control" "$(su_buckets "$SU/m-control/preclassify.sh" "$SU/cons")" "$SU_LIVE" \
  "an unmutated copy beside its siblings reproduces the FULL live set, so a mutant's shift is the mutation"

su_kill "su-mut-noarm-m" "$SU_M_NOARM_M" "$SU_MID" "$SU_NO_M" \
  "deleting the M-branch arm sends the carried path back to the semantic-merge obligation that was filed, and touches the added path not at all"
su_kill "su-mut-noarm-a" "$SU_M_NOARM_A" "$SU_MID" "$SU_NO_A" \
  "and deleting the A-branch arm reaches the file BORN at the intermediate ref, which no base_h arm can catch"
su_kill "su-mut-wide" "$SU_M_WIDE" "$SU_MID" "$SU_WIDE" \
  "a predicate that stops comparing BYTES swallows the genuine consumer edit beside it -- the negative is what catches this"
su_kill "su-mut-unscoped" "$SU_M_UNSCOPED" "$SU_MID" "$SU_UNSCOPED" \
  "dropping the is_machinery conjunct suppresses a NON-machinery path, which apply.sh then overwrites with no operator review"
su_kill "su-mut-nofixture" "$SU_M_NOFX" "$SU_MID" "$SU_NOFX" \
  "dropping the core/fixtures disjunct sends a fixture file step 2 wrote at the skill_commit back to a semantic-merge obligation, and moves no machinery cell"
su_kill "su-mut-order" "$SU_M_ORDER" "$SU_MID" "$SU_ORDER" \
  "moved above ALREADY-AT-THEIRS the arm pre-empts the mode conjunct and calls a consumer that HAS the bit indistinguishable from one that needs it"
su_kill "su-mut-unresolvable" "$SU_M_UNRES" "$SU_TREE" "$SU_LIVE" \
  "without the ^{commit} guard a stamp naming a TREE resolves blobs and BOTH arms fire on a ref that means nothing"
su_kill "su-mut-index" "$SU_M_INDEX" "-" "$SU_IDXH" \
  "with its two upper layers stripped, dropping the sentinel makes an empty rev read the dist repo INDEX, which resolves for every tracked path"

# THE OTHER HALF OF THAT PAIR, AND IT IS WHAT MAKES THE KILL ABOVE ATTRIBUTABLE. Same two layers
# stripped, sentinel INTACT: the index is not read and nothing moves. Without this arm the kill
# above could be crediting the sentinel for a change either of the other two guards produced.
SU_G_LAYERS="$(su_mut su-layers "$SU_M_LAYERS")"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$SU_PC" "$SU_G_LAYERS"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s mutation matched nothing, so the sentinel kill above is unattributed\n' "su-mut-layers"
else
  su_stamp -
  su_layers_got="$(su_buckets "$SU_G_LAYERS" "$SU/nostamp")"
  if [ "$su_layers_got" = "$SU_INERT" ]; then
    printf '  ok    %-16s HELD (the sentinel alone stops the index read once both layers above it are gone)\n' "su-mut-layers"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s got=[%s] want=[%s] -- the layers mutant moved a bucket on its own, so su-mut-index credits the sentinel for something else\n' \
      "su-mut-layers" "$su_layers_got" "$SU_INERT"
  fi
fi

# NOT A KILL, AND SAYING SO IS THE POINT. `skill_commit == commit` clears the ref, and with it left
# in place `self_update_hash` returns `base_h` -- which the `ours_h = base_h` arm ABOVE has already
# claimed, so no bucket can move. Measured across all four stamp states rather than reasoned: the
# guard is a COST and a clarity guard with no behavioural subject, and an arm claiming to kill it
# would be scoring the states either side of it. What IS asserted is su-guard-eqbase above.
SU_G_EQBASE="$(su_mut su-eqbase "$SU_M_EQBASE")"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$SU_PC" "$SU_G_EQBASE"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s mutation matched nothing, so the inertness below is unproven\n' "su-mut-eqbase"
else
  su_stamp "$SU_BASE"
  su_eq_got="$(su_buckets "$SU_G_EQBASE" "$SU/cons")"
  if [ "$su_eq_got" = "$SU_INERT" ]; then
    printf '  ok    %-16s INERT BY CONSTRUCTION (the base_h arm above already claims every state it could reach)\n' "su-mut-eqbase"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s got=[%s] want=[%s] -- removing the equality guard MOVED a bucket, so it has a subject after all and needs an arm\n' \
      "su-mut-eqbase" "$su_eq_got" "$SU_INERT"
  fi
fi

# NOT SCORED THROUGH su_kill, because it is not a kill: this build must AGREE with the shipped one
# everywhere, and a helper that prints KILLED on agreement would read as its opposite.
SU_G_SPELL="$(su_mut su-spelling "$SU_M_SPELL")"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$SU_PC" "$SU_G_SPELL"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s the re-spelling matched nothing, so the two arms below compare the shipped file with itself\n' "su-spelling"
else
  printf '  ok    %-16s the alternative spelling really is a different file\n' "su-spelling"
fi
su_stamp "$SU_MID"
ss_assert "su-spelling-live" "$(su_buckets "$SU_G_SPELL" "$SU/cons")" "$SU_LIVE" \
  "a predicate written with git show piped into hash-object answers identically, so these arms bind the BEHAVIOUR and not one phrasing"
ss_assert "su-spelling-inert" "$(su_buckets "$SU_G_SPELL" "$SU/nostamp")" "$SU_INERT" \
  "...and it is inert on an unstamped consumer too, so it satisfies the guards and not only the happy path"

# --- THE GATE GOES QUIET WITH NO CHANGE TO ITS OWN ARM --------------------------------
# The filing named arm C, and arm C's filter is not what was wrong. These two runs are the same
# gate over the same tree, differing only in whether the consumer's stamp records the ref.
su_stamp "$SU_MID"
SU_GATE_MID="$(bash "$GATE" "$SU/dist" "$SU_BASE" "$SU_THEIRS" "$SU/cons" 2>&1)"
SU_GATE_NO="$(bash "$GATE" "$SU/dist" "$SU_BASE" "$SU_THEIRS" "$SU/nostamp" 2>&1)"

ss_assert "su-gate-quiet" "$(su_carry "$SU_GATE_MID")" \
  'core/rules/doomed.md,core/rules/edited.md,core/rules/indexed.md,' \
  "both carried paths drop out of the advisory while the edited one, the deleted one and the non-machinery one behave exactly as before"
ss_assert "su-gate-differential" "$(su_carry "$SU_GATE_NO")" \
  'core/rules/added.md,core/rules/carried.md,core/rules/doomed.md,core/rules/edited.md,core/rules/indexed.md,' \
  "...and the SAME gate on a consumer with no stamp still carries both, so the quiet above is the stamp read and not a gate that went silent"

# THE ZERO CARRIES ITS CONTROL. A gate emitting nothing satisfies the absence above identically.
ss_assert "su-gate-verdict" \
  "$(printf '%s\n' "$SU_GATE_MID" | awk -F'\t' \
      '$1 == "SELF-UPDATE-OK" || $1 == "SELF-UPDATE-DEFER" || $1 == "SELF-UPDATE-UNDECIDED" {print $1}' \
      | sort -u | tr '\n' ',')" \
  "SELF-UPDATE-OK," "...and it still emits its own verdict, so the missing CARRY rows are a decision rather than a dead gate"

# --- THE JOIN ITSELF: arm C now EVALS machinery_paths() out of preclassify.sh ----------
# The population and the suppression scope are one derivation with one owner, loaded across a file
# boundary by an `awk` range on the function's own text. That join has a failure mode no other arm
# here can see: rename the function, or move it off column 0, and the extraction yields nothing,
# `C_PATHS` is EMPTY, the membership test rejects every path, and the arm reports no divergence
# having compared nothing -- output byte-identical to a clean pull. Scored on the GATE, not on the
# buckets, because the row it must emit is the gate's.
SU_G_MACHFN="$(su_mut su-machfn 'index($0,"machinery_paths() {") { print " machinery_paths() {"; next } { print }')"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$SU_PC" "$SU_G_MACHFN"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s mutation matched nothing, so the set-empty row is unproven\n' "su-mut-machfn"
else
  su_machfn_out="$(bash "$(dirname "$SU_G_MACHFN")/self-update-gate.sh" \
                     "$SU/dist" "$SU_BASE" "$SU_THEIRS" "$SU/cons" 2>&1)"
  su_machfn_row="$(printf '%s\n' "$su_machfn_out" | awk -F'\t' '$1=="SELF-UPDATE-UNDECIDED" {print $2; exit}')"
  su_machfn_carry="$(su_carry "$su_machfn_out")"
  if [ "$su_machfn_row" = "setup-sites.md" ] && [ -z "$su_machfn_carry" ]; then
    printf '  ok    %-16s KILLED (a function the extraction cannot find yields an EMPTY population, and the gate says so instead of going quiet)\n' "su-mut-machfn"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: row=[%s] carry=[%s] -- an unreadable machinery set must report UNDECIDED, never an empty advisory\n' \
      "su-mut-machfn" "${su_machfn_row:-<none>}" "$su_machfn_carry"
  fi
fi
# CONTROL: the SHIPPED gate over the same tree carries rows and emits no such verdict, so the row
# above is the mutation and not a property of this probe.
ss_assert "su-machfn-control" \
  "$(printf '%s\n' "$SU_GATE_MID" | grep -c 'SELF-UPDATE-UNDECIDED')" "0" \
  "the unmutated gate resolves a non-empty machinery set on this tree, so the UNDECIDED above is the mutation"

fi
if sg vr; then
# --- THE VERDICT RECORD: an autonomous decision that leaves an artifact ------------------
#
# Step 2 cuts a branch, writes the machinery slice, pushes and auto-merges with no operator.
# Until the record existed the only trace of the DECISION was the model's own PR-body prose, and
# `self-update-fixtures.sh` now REFUSES to run a fixture without a matching `# verdict: OK`
# record for its own range -- so a gate that silently stops recording turns every self-update
# into a refusal, and one that records the WRONG rows turns the runner's join into a rubber stamp.
#
# ITS OWN CONSUMER COPY PER WORLD, and that is a counting requirement rather than tidiness. Every
# gate invocation above has already written a record into whichever consumer it was handed, so
# `$CONS` holds an unknown number of them by the time this section runs; an arm asserting "exactly
# one" against that directory would be asserting about the whole fixture's history.


VR_C1="$(vr_cons c1)"
bash "$GATE" "$DIST" "$BASE" "$THEIRS" "$VR_C1" > "$VR/c1.out" 2> "$VR/c1.err"
VR_REC1="$(vr_newest "$VR_C1")"

ss_assert "rec-written" "$(vr_n "$VR_C1")" "1" \
  "one classify run leaves exactly one record under the consumer's _bmad-output/ai-dlc-update"

# THE ROWS ARE THE STDOUT ROWS, BYTE FOR BYTE, and `cmp -s` is the arm rather than a row count.
# A second `printf` spelling the record's copy is a second grammar with nothing comparing the two:
# it agrees on the day it is written and drifts the first time a field gains a tab or a verdict
# gains a name. PRESENCE-shaped -- a record that was never written extracts to nothing and fails
# this outright, so a gate that stopped recording cannot pass it.
if [ -n "$VR_REC1" ]; then grep '^SELF-UPDATE-' "$VR_REC1" > "$VR/c1.rows" 2>/dev/null || : > "$VR/c1.rows"
else : > "$VR/c1.rows"; fi
ss_assert "rec-rows-identical" \
  "$(cmp -s "$VR/c1.rows" "$VR/c1.out" && printf identical || printf differ)|$(grep -c . "$VR/c1.out" || true)" \
  "identical|6" \
  "the recorded rows are byte-identical to stdout, and the run really did emit rows -- a gate emitting nothing satisfies an equality of two empty files"

# THE TRAILER IS DERIVED FROM THE ROWS. This seed DEFERS (asserted at the top of this fixture by
# the gate-defer.sh row), and the row count is taken from stdout at run time rather than written
# out here, so a gate that emits a different number of rows moves this cell instead of hiding
# behind a literal that happened to stay true.
ss_assert "rec-trailer" \
  "$(sed -n 's/^# verdict: *//p' "${VR_REC1:-/dev/null}" | head -1)|$(sed -n 's/^# rows: *//p' "${VR_REC1:-/dev/null}" | head -1)" \
  "DEFER|$(grep -c . "$VR/c1.out" || true)" \
  "the trailer's verdict is the rows' verdict (any DEFER wins) and its count is the number of rows emitted"

# THE RANGE ALONE DOES NOT IDENTIFY THE ANSWER, WHICH IS WHY THE RECORD NAMES ITS INPUTS.
# Measured: the same gate command flips DEFER to OK once step 2 has written the slice, because
# the differential runs the consumer's CURRENT copy of each gating script against the incoming
# one and the write replaces the current copy. A record keyed on base/theirs alone therefore
# accepts a post-write re-run as an approval of the pre-write question -- a record of INTENT
# rather than of the decision.
#
# THE DIGESTS ARE ASSERTED AGAINST `git hash-object` OF THE FILES THEMSELVES, not against a list
# spelled here: a hand-written expectation would go vacuous the release the seed gains a script,
# and the property is that the record agrees with the TREE.

# THE EXACT PATH SET, DERIVED FROM THE SEEDED TREE rather than spelled here: a literal list goes
# vacuous the release the seed gains a script, and the property is that the record covers the
# consumer files this verdict could read. The seed's machinery set over this miniature
# distribution is its `core/scripts/`, which `map_consumer` sends to `scripts/ai-dlc/`, so the
# union with the hook's named set is exactly the consumer's own script directory.
ss_assert "rec-inputs-set" "$(vr_in "$VR_REC1" | awk -F'\t' '{print $1}' | sort | tr '\n' ',')" \
  "$( { printf '.claude/.ai-dlc-applying\n.githooks/pre-push\n'
        ls "$VR_C1/scripts/ai-dlc" | sed 's|^|scripts/ai-dlc/|'; } | sort | tr '\n' ',')" \
  "one input line per consumer file the verdict could read: the hook, the interrupted-apply marker, and every script the hook names or the machinery set covers"

# THE STAMP IS NOT AN INPUT, AND ITS ABSENCE IS A DECISION RATHER THAN AN OVERSIGHT. Step 2
# rewrites `.claude/.ai-dlc-version` between this gate and the runner by design, so a row for it
# could never match at read time and would refuse every legitimate self-update. It also has no
# core origin, so the theirs-blob acceptance the other rows rely on cannot reach it.
ss_assert "rec-input-no-stamp" "$(vr_in "$VR_REC1" | awk -F'\t' '$1 == ".claude/.ai-dlc-version"' | grep -c .)" \
  "0" "the stamp step 2 rewrites mid-cycle is deliberately NOT recorded"
# ...AND THAT ZERO IS ABOUT THE STAMP, NOT ABOUT THE GATE READING THE `.claude/` DIRECTORY AT
# ALL: its sibling marker in the same directory IS recorded, in the same run.
ss_assert "rec-input-no-stamp-control" \
  "$(vr_in "$VR_REC1" | awk -F'\t' '$1 == ".claude/.ai-dlc-applying"' | grep -c .)" \
  "1" "...while the marker beside it in the same directory IS, so the zero above is that file and not the directory"

# COLUMN 3 IS THE CORE PATH, AND IT IS WHAT LETS THE RECORD SURVIVE STEP 2'S OWN WRITE. The
# digests are taken at gate time and the reader hashes at runner time, with the slice written in
# between; without a core path the reader has no theirs blob to accept the moved file against and
# refuses every legitimate self-update.
ss_assert "rec-input-core-col" \
  "$(vr_in_c "$VR_REC1" '.githooks/pre-push')|$(vr_in_c "$VR_REC1" 'scripts/ai-dlc/gate-defer.sh')|$(vr_in_c "$VR_REC1" '.claude/.ai-dlc-applying')" \
  "core/git-hooks/pre-push|core/scripts/gate-defer.sh|-" \
  "each row names the CORE path its consumer path maps from, and a file with no core origin carries a literal -"

# THE FALLBACK HOOK IS THE ONLY `-` IN COLUMN 1, and its column 3 is fixed. A consumer with no
# hook of its own is judged against the distribution's copy, which is not under the consumer root
# at all — so the reader is told where to look rather than left to resolve a consumer path that
# does not exist. Its own consumer, because $VR_C1 has a hook.
VR_NH="$(vr_cons nohook)"; rm -rf "$VR_NH/.githooks"
bash "$GATE" "$DIST" "$BASE" "$THEIRS" "$VR_NH" >/dev/null 2>&1
VR_NHR="$(vr_newest "$VR_NH")"
ss_assert "rec-input-fallback-hook" \
  "$(vr_in "$VR_NHR" | awk -F'\t' '$1 == "-" {print $3}' | tr '\n' ',')" \
  "core/git-hooks/pre-push," \
  "a consumer with no hook records the distribution's fallback as a - row whose core path is the hook, and nothing else takes a - column 1"
# CONTROL: the consumer that HAS a hook produces no `-` row at all, so the row above is the
# fallback and not a shape every record carries.
ss_assert "rec-input-fallback-control" \
  "$(vr_in "$VR_REC1" | awk -F'\t' '$1 == "-"' | grep -c .)" "0" \
  "...and a consumer with its own hook has no - row, so column 1 marks the distribution read and only that"

# THE HOOK IS THE INPUT THE WHOLE GATING SET IS DERIVED FROM. Measured by the adversary: writing
# the hook alone flips OK to DEFER, and writing the scripts alone flips DEFER to OK.
ss_assert "rec-input-hook" "$(vr_in_h "$VR_REC1" '.githooks/pre-push')" \
  "$(git hash-object "$VR_C1/.githooks/pre-push")" \
  "the pre-push hook the gating set was derived from is recorded at its exact content digest"

# EVERY SCRIPT THE DIFFERENTIAL RAN AS THE CURRENT SIDE, and the one it did NOT run is here too:
# which scripts get rows is derived from the hook, so a record holding only the row-producing
# subset could not tell a hook that stopped naming a script from a script that stopped changing.
ss_assert "rec-input-current-side" \
  "$(vr_in_h "$VR_REC1" 'scripts/ai-dlc/gate-defer.sh')|$(vr_in_h "$VR_REC1" 'scripts/ai-dlc/unchanged.sh')" \
  "$(git hash-object "$VR_C1/scripts/ai-dlc/gate-defer.sh")|$(git hash-object "$VR_C1/scripts/ai-dlc/unchanged.sh")" \
  "a script that produced a DEFER row and one the pull never changed are both recorded -- the hook's membership is itself an input"

# AN ABSENT INPUT IS RECORDED AS ABSENT, NOT OMITTED. `.ai-dlc-applying` decides whether the
# SAFE-STOP acquittal is withheld, so its ARRIVAL changes the answer; an omitted line cannot
# express "this file was not there when the verdict was taken".
ss_assert "rec-input-absent" "$(vr_in_h "$VR_REC1" '.claude/.ai-dlc-applying')" "ABSENT" \
  "a file whose absence the verdict depended on is recorded as ABSENT rather than left out"

# THE DIGEST MOVES WITH THE FILE, which is the whole property. Editing a recorded input after the
# run makes the record disagree with the tree -- and the runner refuses on that disagreement.
printf '#!/usr/bin/env bash\n# edited after the verdict was taken\nexit 0\n' > "$VR_C1/.githooks/pre-push"
ss_assert "rec-input-detects-edit" \
  "$([ "$(vr_in_h "$VR_REC1" '.githooks/pre-push')" = "$(git hash-object "$VR_C1/.githooks/pre-push")" ] && printf still-matches || printf diverged)" \
  "diverged" \
  "editing a recorded input after the run makes the record disagree with the tree, which is the state the runner must refuse"
# CONTROL, IN THE SAME BREATH: an input NOT edited still matches, so the arm above reads the file
# rather than reporting divergence for everything.
ss_assert "rec-input-detects-edit-control" \
  "$([ "$(vr_in_h "$VR_REC1" 'scripts/ai-dlc/gate-defer.sh')" = "$(git hash-object "$VR_C1/scripts/ai-dlc/gate-defer.sh")" ] && printf still-matches || printf diverged)" \
  "still-matches" \
  "...while an untouched input still matches, so the divergence above is that one file and not the whole record"

# THE JOIN KEYS THE RUNNER READS. `self-update-fixtures.sh` compares FULL resolved shas, so a
# header carrying the caller's argument strings would let a short sha and its long form read as
# two different ranges. Derived here from the same rev-parse the runner uses.
ss_assert "rec-shas" \
  "$(sed -n 's/^# base-sha: *//p' "${VR_REC1:-/dev/null}" | head -1)|$(sed -n 's/^# theirs-sha: *//p' "${VR_REC1:-/dev/null}" | head -1)" \
  "$(git -C "$DIST" rev-parse "${BASE}^{commit}")|$(git -C "$DIST" rev-parse "${THEIRS}^{commit}")" \
  "the header carries the FULL resolved shas of both endpoints, which is what the runner joins on"

# THE STAMP AS THIS GATE SAW IT. Step 2 advances `skill_commit` to `theirs` before it invokes
# the runner, so the runner cannot learn the value from the stamp and the record is its only
# carrier; `self-update-fixtures.sh`'s PRE-WRITTEN arm reads this field to tell a legitimate
# split stamp from a gate re-run on an already-written tree.
#
# BOTH DIRECTIONS ARE SEEDED, AND THE PAIR IS THE ARM. The base consumer this fixture builds
# carries NO stamp, so a single arm here would only ever exercise the `-` path -- which is the
# value a gate that never learned to read the stamp also produces, and the two would be
# indistinguishable. The stamped world is constructed for that reason.
VR_SK_C1="$(vr_cons skc)"
mkdir -p "$VR_SK_C1/.claude"
printf 'version: 1.0.0\ncommit: %s\nskill_version: 1.1.0\nskill_commit: %s\n' \
  "$BASE" "$BASE" > "$VR_SK_C1/.claude/.ai-dlc-version"
bash "$GATE" "$DIST" "$BASE" "$THEIRS" "$VR_SK_C1" > "$VR/skc.out" 2> "$VR/skc.err"
VR_SK_REC="$(vr_newest "$VR_SK_C1")"
# THE VALUE, PEELED, not the line count. An arm counting the line passes on a gate writing `-`
# forever -- the acquittal-free direction, which reads exactly like this working.
ss_assert "rec-skill-commit" \
  "$(sed -n 's/^# skill-commit: *//p' "${VR_SK_REC:-/dev/null}" | head -1)" \
  "$(git -C "$DIST" rev-parse "${BASE}^{commit}")" \
  "the header carries the consumer's skill_commit, PEELED, as the gate saw it -- the runner's only honest source for it"

# AND `-` WHERE THERE IS NO STAMP TO READ, rather than an omitted line. A reader keyed on a
# prefix cannot tell an absent line from an unparseable one, and `-` is a value that matches no
# blob, so an unreadable stamp yields the STRICT comparison rather than a lenient one. `$VR_C1`
# is the unstamped world -- the seed writes no stamp into it, which is asserted here rather than
# assumed, because a seed that GAINS one would make this arm silently test the other case.
ss_assert "rec-skill-commit-absent" \
  "$([ -f "$VR_C1/.claude/.ai-dlc-version" ] && printf 'stamped|' || printf 'no-stamp|')$(sed -n 's/^# skill-commit: *//p' "${VR_REC1:-/dev/null}" | head -1)" \
  "no-stamp|-" \
  "a consumer with no stamp records '-', so the field is always present and always comparable"

# THE MUTANT FOR THE ARM ABOVE. Both arms are value-shaped rather than presence-shaped, so a gate
# that stopped emitting the line fails them by construction -- but a gate that emits a CONSTANT
# would satisfy neither, and a gate that reads the WRONG FIELD would satisfy the `-` arm on an
# unstamped consumer while being silently wrong everywhere else. The mutation makes the reader
# key on `commit:` instead of `skill_commit:`, which is the single most plausible wrong
# implementation and the one no absence-shaped arm could see.
#
# THE WHOLE DIRECTORY IS COPIED, because this gate resolves `preclassify.sh` beside itself and a
# lone copy reads an empty machinery set and goes quiet -- silence that would score as a kill.
VR_MUT_D="$VR/m-skc"
rm -rf "$VR_MUT_D"; mkdir -p "$VR_MUT_D"
cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$VR_MUT_D"/ 2>/dev/null
awk '{ if (index($0, "s/^skill_commit:[[:space:]]*\\([^[:space:]]*\\).*/\\1/p") && index($0, "_grsc_v=")) { sub(/\^skill_commit:/, "^commit:"); } print }' \
  "$GATE" > "$VR_MUT_D/self-update-gate.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$GATE" "$VR_MUT_D/self-update-gate.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s mutation matched nothing, so rec-skill-commit is unproven\n' "rec-skc-mutant"
else
  VR_MUT_C="$(vr_cons skcmut)"
  mkdir -p "$VR_MUT_C/.claude"
  # `commit` and `skill_commit` DELIBERATELY DIFFER in this stamp, which is what makes the two
  # readers separable. Seeded equal -- the shape the base fixture uses -- the mutant and the
  # shipped gate emit the same value and the mutant survives for a reason that is not the
  # predicate's fault.
  printf 'version: 1.0.0\ncommit: %s\nskill_version: 1.1.0\nskill_commit: %s\n' \
    "$THEIRS" "$BASE" > "$VR_MUT_C/.claude/.ai-dlc-version"
  bash "$VR_MUT_D/self-update-gate.sh" "$DIST" "$BASE" "$THEIRS" "$VR_MUT_C" \
    > "$VR/skcmut.out" 2> "$VR/skcmut.err"
  vr_mut_rec="$(vr_newest "$VR_MUT_C")"
  vr_mut_got="$(sed -n 's/^# skill-commit: *//p' "${vr_mut_rec:-/dev/null}" | head -1)"
  if [ "$vr_mut_got" = "$(git -C "$DIST" rev-parse "${THEIRS}^{commit}")" ]; then
    printf '  ok    %-16s KILLED (a reader keyed on commit: records the wrong field, and the arm says so)\n' "rec-skc-mutant"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: mutant recorded [%s] -- the arm cannot tell skill_commit from commit\n' \
      "rec-skc-mutant" "${vr_mut_got:-<none>}"
  fi
  # THE UNMUTATED CONTROL, ON THE SAME SPLIT-STAMP WORLD, and it carries a POSITIVE conjunct: the
  # shipped gate must record the `skill_commit` VALUE here, not merely something-that-is-not-the
  # -mutant's. A control asserting only inequality passes against a gate that records nothing.
  VR_CTL_C="$(vr_cons skcctl)"
  mkdir -p "$VR_CTL_C/.claude"
  printf 'version: 1.0.0\ncommit: %s\nskill_version: 1.1.0\nskill_commit: %s\n' \
    "$THEIRS" "$BASE" > "$VR_CTL_C/.claude/.ai-dlc-version"
  bash "$GATE" "$DIST" "$BASE" "$THEIRS" "$VR_CTL_C" > "$VR/skcctl.out" 2> "$VR/skcctl.err"
  vr_ctl_rec="$(vr_newest "$VR_CTL_C")"
  ss_assert "rec-skc-mutant-control" \
    "$(sed -n 's/^# skill-commit: *//p' "${vr_ctl_rec:-/dev/null}" | head -1)" \
    "$(git -C "$DIST" rev-parse "${BASE}^{commit}")" \
    "the SHIPPED gate on that same split-stamp world records skill_commit, so the kill above is the mutation and not the world"
fi

# THE PATH REACHES THE CALLER ON STDERR, because stdout is the TSV contract and every caller of
# this gate parses it by field. A record nobody can name is a record nobody commits.
ss_assert "rec-stderr-path" "$(sed -n 's/^record: *//p' "$VR/c1.err" | head -1)" "$VR_REC1" \
  "the record's path is announced on stderr, so step 2 can commit the file it just produced"
ss_assert "rec-stdout-tsv-only" \
  "$(awk '!/^SELF-UPDATE-/ {n++} END{print n+0}' "$VR/c1.out")" "0" \
  "...and NOTHING non-TSV reached stdout, so the announcement cannot be parsed as a row"

# NO RECORD UNDER --safe-stop. That mode prints a REF for the caller to substitute into a
# command; a record written there would name a candidate the operator never asked about.
VR_C2="$(vr_cons c2)"
bash "$GATE" --safe-stop "$DIST" "$BASE" "$THEIRS" "$VR_C2" >/dev/null 2>&1
ss_assert "rec-safestop-quiet" "$(vr_n "$VR_C2")" "0" \
  "--safe-stop writes no record at all"
# ...AND THAT ZERO IS A DECISION, NOT A CONSUMER THAT CANNOT BE WRITTEN TO. Same tree, same
# directory, one classify: a permissions problem would produce the same zero above.
bash "$GATE" "$DIST" "$BASE" "$THEIRS" "$VR_C2" >/dev/null 2>&1
ss_assert "rec-safestop-control" "$(vr_n "$VR_C2")" "1" \
  "...and a classify against the SAME consumer records normally, so the zero above is the mode and not the tree"

# EXACTLY ONE RECORD PER TOP-LEVEL CLASSIFY, EVEN WHEN THE VERDICT SPAWNS A WALK. The seed above
# cannot see this: its range holds no INTERMEDIATE release, so `advise_safe_stop` classifies
# nothing. The $SS world does -- base..r2 carries r1 -- so a DEFER there really does spawn a
# nested classify, and without the guard that child writes a record of its OWN range which then
# becomes the newest one the runner reads.
#
# WHAT CARRIES THE PROPERTY IS THE `export` BEFORE THE WALK'S LOOP, not the write site. The child
# is a separate `bash` process; a guard the parent evaluates says nothing about what the child
# does, and only an EXPORTED variable reaches it. The mutant below is keyed on that export for
# that reason, and it is what proves this arm has a subject at all.
ss_stamp -; ss_marker off
VR_SS="$VR/sscons"; rm -rf "$VR_SS"; cp -R "$SS/cons" "$VR_SS"; rm -rf "$VR_SS/_bmad-output"
# PRECONDITION: the walk must actually have a candidate to classify, or the arm below counts one
# record because nothing nested ran and the guard was never exercised.
ss_assert "rec-nested-pre" "$(bash "$GATE" --safe-stop "$SS/dist" "$SS_BASE" "$SS_R2" "$SS/cons" 2>/dev/null)" \
  "$SS_R1" "the walk this DEFER spawns really does classify an intermediate candidate"
bash "$GATE" "$SS/dist" "$SS_BASE" "$SS_R2" "$VR_SS" >/dev/null 2>&1
ss_assert "rec-nested-one" "$(vr_trailers "$VR_SS")" "1" \
  "a DEFER that spawns a --safe-stop walk still leaves exactly ONE recorded verdict, the top-level one"

# AN UNRECORDABLE VERDICT IS UNDECIDED. The runner's doctrine for a join it could not run is a
# refusal; the classifier's half of that answer is a row, not a silent OK.
VR_C3="$(vr_cons c3)"
mkdir -p "$VR_C3/_bmad-output"; chmod 500 "$VR_C3/_bmad-output"
ss_assert "rec-unwritable-pre" "$([ -w "$VR_C3/_bmad-output" ] && printf writable || printf refused)" "refused" \
  "the seeded consumer's _bmad-output really does refuse a write, so the row below is the gate reading a failure"
VR_U="$(bash "$GATE" "$DIST" "$BASE" "$THEIRS" "$VR_C3" 2>/dev/null)"
ss_assert "rec-unwritable-row" \
  "$(printf '%s\n' "$VR_U" | awk -F'\t' '$1=="SELF-UPDATE-UNDECIDED" && $3 ~ /could not be RECORDED/ {print $2; exit}')" \
  "$VR_C3/_bmad-output/ai-dlc-update" \
  "an unwritable record directory produces an UNDECIDED row naming it, rather than a verdict with no artifact"
chmod 700 "$VR_C3/_bmad-output"
# CONTROL, ONE PROPERTY APART: the same consumer with the mode restored emits no such row.
ss_assert "rec-unwritable-control" \
  "$(bash "$GATE" "$DIST" "$BASE" "$THEIRS" "$VR_C3" 2>/dev/null | awk -F'\t' '$3 ~ /could not be RECORDED/' | grep -c .)" \
  "0" "...and with the directory writable that row is gone, so it reads the failure and not every run"

# --- MUTANTS on the record ---------------------------------------------------------------
# THE COPY NEEDS ITS SIBLINGS, for the reason every battery in this file states: the gate resolves
# preclassify.sh and setup-sites.md by `dirname "$0"`, and a lone copy answers UNDECIDED off an
# empty machinery set with no record arm ever reached.
# vr_score <gate> <consumer-name> -> "n=<records> rows=<identical|differ> v=<verdict>"
vr_score() {
  local c out rec rows v
  c="$(vr_cons "$2")"
  bash "$1" "$DIST" "$BASE" "$THEIRS" "$c" > "$VR/$2.out" 2>/dev/null
  rec="$(vr_newest "$c")"
  if [ -n "$rec" ]; then grep '^SELF-UPDATE-' "$rec" > "$VR/$2.rows" 2>/dev/null || : > "$VR/$2.rows"
  else : > "$VR/$2.rows"; fi
  rows=differ; cmp -s "$VR/$2.rows" "$VR/$2.out" && rows=identical
  v="$(sed -n 's/^# verdict: *//p' "${rec:-/dev/null}" | head -1)"
  printf 'n=%s rows=%s v=%s\n' "$(vr_n "$c")" "$rows" "${v:-<none>}"
}

# THE UNMUTATED CONTROL, PRESENCE-SHAPED. A copy that dies resolving its siblings, or one replaced
# by `exit 0`, scores n=0 rows=identical (two empty files compare equal) v=<none> and fails this.
rm -rf "$VR/m-control"; mkdir -p "$VR/m-control"
cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$VR/m-control"/ 2>/dev/null
ss_assert "rec-mut-control" "$(vr_score "$VR/m-control/self-update-gate.sh" ctl)" \
  "n=1 rows=identical v=DEFER" \
  "an unmutated copy beside its siblings records normally, so a mutant's shift is the mutation"

vr_kill() { # vr_kill <label> <awk> <consumer-name> <want> <why>
  local g got
  g="$(vr_mut "$1" "$2")"
  ASSERTIONS=$((ASSERTIONS + 1))
  if cmp -s "$GATE" "$g"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s mutation matched nothing, so the arm it scores is unproven\n' "$1"
    return
  fi
  got="$(vr_score "$g" "$3")"
  if [ "$got" = "$4" ]; then
    printf '  ok    %-16s KILLED (%s)\n' "$1" "$5"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: got=[%s] want=[%s]  %s\n' "$1" "$got" "$4" "$5"
  fi
}

# THE CALL, NOT THE DEFINITION. `gate_record_open` appears twice; the bare call is the one line
# whose removal leaves a gate that still classifies and records nothing -- which is the state the
# runner reads as a refusal on every self-update.
vr_kill "rec-mut-norecord" 'index($0,"gate_record_open") && $0 == "gate_record_open" { next } { print }' \
  m1 "n=0 rows=differ v=<none>" \
  "a gate that never opens the record still prints its verdict, and step 2 pushes on a decision with no artifact"

# THE SECOND SPELLING. The record's copy of the row is written by its own printf instead of the
# one string emit() already rendered. The divergence seeded here is ONE TRAILING SPACE, which is
# the shape a second grammar actually drifts into -- and it is deliberately NOT a change of
# separator, because a space-separated row would also move the trailer (the derivation splits on
# tabs, so field 1 would stop being a verdict token) and a mutant moving two cells proves neither.
# `v=DEFER` in the expectation is the conjunct that holds it to one cell.
vr_kill "rec-mut-2printf" \
  'index($0,"[ -n \"$GATE_REC\" ] && printf") { print "  [ -n \"$GATE_REC\" ] && printf \"%s\\t%s\\t%s \\n\" \"$1\" \"$2\" \"$3\" >> \"$GATE_REC\""; next } { print }' \
  m2 "n=1 rows=differ v=DEFER" \
  "rows spelled a second time diverge from stdout, and the record stops being evidence about what the operator was shown"

# THE TRAILER STOPS BEING DERIVED. The whole if/elif that reads the rows is dropped, leaving the
# `_rec_v=OK` initialiser -- so a DEFER record advertises itself to the runner as an approval.
vr_kill "rec-mut-trailer-ok" \
  '{ if (index($0,"    _rec_v=OK")) { print; blk=1; next }
     if (blk && index($0,"    fi")) { blk=0; next }
     if (blk) next
     print }' \
  m3 "n=1 rows=identical v=OK" \
  "a hard-coded trailer says OK over DEFER rows, which is the one value the runner reads before it will run a fixture"

# THE DIGESTS ARE READ FROM THE FILES. A constant in their place leaves the record structurally
# perfect -- right count, right paths, right sort order -- and joins on nothing, which is the
# shape `rec-input-detects-edit` exists to catch and the only mutation that can move that cell.
VR_M7="$(vr_mut m7 'index($0,"_gi_h=\"$(git hash-object \"$_gi_abs\" 2>/dev/null)\"") { print "    _gi_h=CONSTANT"; next } { print }')"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$GATE" "$VR_M7"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s mutation matched nothing, so the arm it scores is unproven\n' "rec-mut-digest"
else
  VR_C7="$(vr_cons m7c)"
  bash "$VR_M7" "$DIST" "$BASE" "$THEIRS" "$VR_C7" >/dev/null 2>&1
  VR_R7="$(vr_newest "$VR_C7")"
  vr_m7_got="$(vr_in_h "$VR_R7" '.githooks/pre-push')|$(vr_in "$VR_R7" | grep -c .)"
  vr_m7_want="CONSTANT|$(vr_in "$VR_REC1" | grep -c .)"
  if [ "$vr_m7_got" = "$vr_m7_want" ]; then
    printf '  ok    %-16s KILLED (%s)\n' "rec-mut-digest" \
      "a constant digest leaves the record structurally identical -- same paths, same count -- and joins on nothing"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: got=[%s] want=[%s]\n' "rec-mut-digest" "$vr_m7_got" "$vr_m7_want"
  fi
fi

# THE NESTED-WRITE GUARD, scored on the $SS world because it is the only one whose DEFER spawns a
# walk, and on the TRAILER count because a child firing in the same whole second reuses the
# record's name and truncates rather than adding a file. KEYED ON THE `export`: the child is a
# separate process, so an un-exported variable is what actually lets it record.
VR_M4="$(vr_mut m4 'index($0,"  export AI_DLC_GATE_IN_SAFE_STOP=1") { print "  AI_DLC_GATE_IN_SAFE_STOP=1"; next } { print }')"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$GATE" "$VR_M4"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s mutation matched nothing, so the arm it scores is unproven\n' "rec-mut-nested"
else
  VR_SS4="$VR/sscons4"; rm -rf "$VR_SS4"; cp -R "$SS/cons" "$VR_SS4"; rm -rf "$VR_SS4/_bmad-output"
  bash "$VR_M4" "$SS/dist" "$SS_BASE" "$SS_R2" "$VR_SS4" >/dev/null 2>&1
  vr_m4_got="$(vr_trailers "$VR_SS4")"
  if [ "$vr_m4_got" -gt 1 ] 2>/dev/null; then
    printf '  ok    %-16s KILLED (%s recorded verdicts; %s)\n' "rec-mut-nested" "$vr_m4_got" \
      "without the EXPORT the nested classify records its OWN range, and the newest record the runner reads is a candidate's verdict"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: got=[%s] want=[>1]\n' "rec-mut-nested" "$vr_m4_got"
  fi
fi

# --- A GATE THAT CANNOT READ ITS OWN RANGE MUST NOT RETURN OK ----------------------------
#
# Measured against this seed before the guard existed: `self-update-gate.sh <dist> <base>
# deadbeefcafe <cons>` printed `SELF-UPDATE-OK - this pull changes no core/scripts/ path`, and so
# did a bogus BASE. `git diff --name-only bad..X` fails, `CHANGED` reads EMPTY, and the empty-diff
# terminal acquits; arms R1, R2 and the CARRY arm are silent for the same reason, so the output is
# byte-indistinguishable from a genuinely clean pull. The gate's own header already said a gate
# that cannot read its own subject must not return OK.
#
# EACH RUN IS SCORED AS A TUPLE, not as a presence. `und=` alone cannot tell a guard that reads
# the ref from one that reports UNDECIDED unconditionally, and `ok=` alone cannot tell a refusal
# from a gate that emits nothing.
#
# ITS OWN CONSUMER, BUILT HERE. `$VR_C1` has had its hook REWRITTEN by the input-digest arm above
# — deliberately, since that arm's whole subject is a recorded input moving — and the hook decides
# the gating set. Reusing it makes `range-control` read one OK row where the seed produces two,
# which is a false red that looks exactly like the guard over-reaching.
VR_RC="$(vr_cons rangecons)"
vr_range() { # vr_range <gate> <base> <theirs> <dist> -> "und=<n> f2=<first-undecided-subject> ok=<n>"
  local o
  o="$(bash "$1" "$4" "$2" "$3" "$VR_RC" 2>/dev/null)"
  printf 'und=%s f2=%s ok=%s\n' \
    "$(printf '%s\n' "$o" | awk -F'\t' '$1=="SELF-UPDATE-UNDECIDED" {n++} END{print n+0}')" \
    "$(printf '%s\n' "$o" | awk -F'\t' '$1=="SELF-UPDATE-UNDECIDED" {print $2; exit}')" \
    "$(printf '%s\n' "$o" | awk -F'\t' '$1=="SELF-UPDATE-OK" {n++} END{print n+0}')"
}

ss_assert "range-bogus-theirs" "$(vr_range "$GATE" "$BASE" deadbeefcafe "$DIST")" \
  "und=1 f2=deadbeefcafe ok=0" \
  "an unresolvable THEIRS yields one UNDECIDED row NAMING that ref and no OK row at all"
ss_assert "range-bogus-base" "$(vr_range "$GATE" deadbeefcafe "$THEIRS" "$DIST")" \
  "und=1 f2=deadbeefcafe ok=0" \
  "and an unresolvable BASE likewise -- a guard on THEIRS alone leaves this one acquitting"
ss_assert "range-both-bogus" "$(vr_range "$GATE" nope-base nope-theirs "$DIST")" \
  "und=2 f2=nope-base ok=0" \
  "both endpoints are checked in one run, so a caller with two bad refs is told about both"

# A TREE OBJECT IS THE INPUT THAT SEPARATES `^{commit}` FROM A BARE EXISTENCE TEST, and it is the
# one a syntactically-valid-but-wrong sha actually looks like. A tree RESOLVES: `<tree>:<path>`
# reads blobs perfectly well, so before the peel this ref produced the full correct verdict set
# off a range endpoint that is not a commit at all. `deadbeefcafe` cannot make that distinction --
# it fails every test, so a guard written as `rev-parse -q --verify "$REF"` would pass on it and
# still admit the tree.
VR_TREE="$(git -C "$DIST" rev-parse "${THEIRS}^{tree}")"
ss_assert "range-tree-theirs" "$(vr_range "$GATE" "$BASE" "$VR_TREE" "$DIST")" \
  "und=1 f2=$VR_TREE ok=0" \
  "a THEIRS naming a TREE is refused: it resolves as an object, so only the ^{commit} peel can tell it from a range endpoint"

# THE CONTROL, AND IT IS THE ARM THAT SEPARATES A REFUSAL FROM A GATE THAT REFUSES EVERYTHING.
# The real range is the input the guard must NOT touch: it carries OK rows and exactly one
# UNDECIDED, gate-agree.sh's, which the differential arms at the top of this fixture already own.
ss_assert "range-control" "$(vr_range "$GATE" "$BASE" "$THEIRS" "$DIST")" \
  "und=1 f2=gate-agree.sh ok=2" \
  "the real range is untouched: two OK rows and the one UNDECIDED the differential produces"

# DIST IS NOT A REPOSITORY. Its own arm rather than a case of the ref check, because the two have
# different SUBJECTS: naming two perfectly good refs as unresolvable sends the operator after the
# range when the argument that is wrong is the path.
VR_NR="$VR/notarepo"; rm -rf "$VR_NR"; mkdir -p "$VR_NR"
ss_assert "range-not-a-repo" "$(vr_range "$GATE" "$BASE" "$THEIRS" "$VR_NR")" \
  "und=1 f2=$VR_NR ok=0" \
  "a DIST that is not a git repository is reported as ITSELF, once, with no OK row"

# THE REFUSAL IS STILL RECORDED. An UNDECIDED with no artifact is the same hole for the runner as
# an OK with no artifact, and the header must say which endpoint failed to resolve.
VR_C4="$(vr_cons c4)"
bash "$GATE" "$DIST" "$BASE" deadbeefcafe "$VR_C4" >/dev/null 2>&1
VR_REC4="$(vr_newest "$VR_C4")"
ss_assert "range-recorded" \
  "$(sed -n 's/^# theirs-sha: *//p' "${VR_REC4:-/dev/null}" | head -1)|$(sed -n 's/^# verdict: *//p' "${VR_REC4:-/dev/null}" | head -1)" \
  "unresolved|UNDECIDED" \
  "a refused range is recorded too, with the unresolvable endpoint marked rather than the line omitted"

# A RECORD WITH NO `# input:` LINE IS MALFORMED AND THE RUNNER REFUSES IT, so the earliest
# terminal must carry the inputs it could read. This is the refusal above -- it exits before any
# arm -- and it still names the hook and the marker.
ss_assert "range-recorded-inputs" \
  "$(vr_in "$VR_REC4" | awk -F'\t' '$1 == ".githooks/pre-push" {n++} END{print n+0}')|$(vr_in "$VR_REC4" | grep -c .)" \
  "1|2" \
  "the earliest terminal records the inputs it could read, so no record reaches the runner with an empty input set"

# --- MUTANTS on the range guard -----------------------------------------------------------
# The unmutated control for these two is `range-control` above, which is PRESENCE-shaped on the OK
# rows: a gate that emits nothing scores ok=0 there and fails.
VR_M5="$(vr_mut m5 'index($0,"  gate_bad_ref=1") { next } { print }')"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$GATE" "$VR_M5"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s mutation matched nothing, so the arm it scores is unproven\n' "range-mut-refs"
else
  # SCORED ON THE TREE, NOT ON `deadbeefcafe`, BECAUSE A LATER GUARD NOW COVERS THE BOGUS REF.
  # The changed-script `git diff` is staged with its status read, and a diff over an unresolvable
  # endpoint fails, so with this guard defeated a bogus THEIRS no longer falls through to OK: the
  # diff guard answers UNDECIDED "-" instead (measured: und=2 f2=deadbeefcafe ok=0, where this arm
  # used to read ok=1). Two guards covering one subject read exactly like a guard that does not
  # work. The TREE is the subject only this guard can see -- `git diff <commit> <tree>` succeeds --
  # so with the refusal defeated the whole verdict set, OK rows included, is computed off a range
  # endpoint that is not a commit.
  vr_m5_got="$(vr_range "$VR_M5" "$BASE" "$VR_TREE" "$DIST")"
  case "$vr_m5_got" in
    "und="*" f2=$VR_TREE ok="[1-9]*)
      printf '  ok    %-16s KILLED (%s)\n' "range-mut-refs" \
        "with the refusal defeated a TREE endpoint draws OK rows beside the row ($vr_m5_got) -- and a caller reading the verdict, as step 2 does, proceeds" ;;
    *)
      FAILURES=$((FAILURES + 1))
      printf '  FAIL  %-16s SURVIVED: got=[%s] want=[und=* f2=%s ok>=1]\n' "range-mut-refs" "$vr_m5_got" "$VR_TREE" ;;
  esac
fi

# THE SECOND GUARD HAS ITS OWN MUTANT BECAUSE ITS SUBJECT IS THE ONE THE FIRST CANNOT NAME. With
# the repository arm gone the ref loop still refuses -- correctly, since neither ref resolves --
# so the verdict does not change and only the SUBJECT does: two rows blaming two good refs instead
# of one naming the path. That is the whole outcome this arm owns, and stating it here stops the
# next reader scoring the guard as vacuous because the verdict held.
VR_M6="$(vr_mut m6 'index($0,"if ! git -C \"$DIST\" rev-parse --git-dir") { print "if false; then"; next } { print }')"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$GATE" "$VR_M6"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s mutation matched nothing, so the arm it scores is unproven\n' "range-mut-repo"
else
  vr_m6_got="$(vr_range "$VR_M6" "$BASE" "$THEIRS" "$VR_NR")"
  if [ "$vr_m6_got" = "und=2 f2=$BASE ok=0" ]; then
    printf '  ok    %-16s KILLED (%s)\n' "range-mut-repo" \
      "without its own arm the missing REPOSITORY is reported as two unresolvable refs, sending the operator after the range instead of the path"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: got=[%s] want=[und=2 f2=%s ok=0]\n' "range-mut-repo" "$vr_m6_got" "$BASE"
  fi
fi

# --- A VERDICT TAKEN ON AN ALREADY-WRITTEN TREE ANSWERS A DIFFERENT QUESTION --------------
#
# Step 2's real order is: gate, WRITE the machinery slice (every gating script at theirs), run the
# derived fixtures, push. A gate run AFTER that write compares each script with ITSELF -- cur and
# new are the same bytes -- so every differential agrees and the equality arm reports OK. Measured
# on this seed: 2 DEFER rows before the write, 4 OK after, 2 DEFER again on revert. Nothing but
# the ORDER a human ran two commands in separated an honest verdict from that one.
#
# THE WRITE IS SIMULATED WITH THE DISTRIBUTION'S OWN BLOBS, not with invented content, because the
# property under test is byte-equality with theirs. Content of my own choosing would exercise a
# state step 2 never produces.
VR_PW="$(vr_cons prewritten)"
vr_write_slice() { # vr_write_slice <consumer> -- what step 2 writes: every CHANGED gating script at theirs
  local n
  for n in gate-pass gate-defer gate-broken gate-agree; do
    git -C "$DIST" show "${THEIRS}:core/scripts/${n}.sh" > "$1/scripts/ai-dlc/${n}.sh" 2>/dev/null
  done
}
# PRECONDITION. The simulation is only a simulation of step 2 if the bytes really land at theirs;
# a `git show` that silently wrote nothing would leave the tree at base and the arm below would
# pass for the reason it exists to refuse.
vr_write_slice "$VR_PW"
ss_assert "prewritten-pre" \
  "$(git hash-object "$VR_PW/scripts/ai-dlc/gate-defer.sh")" \
  "$(git -C "$DIST" rev-parse "${THEIRS}:core/scripts/gate-defer.sh")" \
  "the simulated write really put the consumer's copy at theirs, so the arm below has its subject"

vr_pw_scan() { # vr_pw_scan <gate> <consumer> -> "und=<n> ok=<n> pw=<n>"
  local o
  o="$(bash "$1" "$DIST" "$BASE" "$THEIRS" "$2" 2>/dev/null)"
  printf 'und=%s ok=%s pw=%s\n' \
    "$(printf '%s\n' "$o" | awk -F'\t' '$1=="SELF-UPDATE-UNDECIDED" {n++} END{print n+0}')" \
    "$(printf '%s\n' "$o" | awk -F'\t' '$1=="SELF-UPDATE-OK" {n++} END{print n+0}')" \
    "$(printf '%s\n' "$o" | awk -F'\t' '$3 ~ /ALREADY at theirs/ {n++} END{print n+0}')"
}

# FOUR GATING SCRIPTS, ALL AT THEIRS, ALL CHANGED IN THE RANGE: four UNDECIDED rows naming them
# and ZERO OK rows. The `pw=` cell is what separates this arm from a gate that went UNDECIDED for
# some other reason -- the range guard, an unreadable script, an empty machinery set all produce
# UNDECIDED too, and only this row's own wording says WHICH question could not be asked.
ss_assert "prewritten-refused" "$(vr_pw_scan "$GATE" "$VR_PW")" "und=4 ok=0 pw=4" \
  "a gate run after the slice was written refuses every gating script: cur and new are one file, so their agreement answers nothing"

# THE CONTROL, ONE PROPERTY APART AND IN THE SAME RUN. The same gate, the same range, a consumer
# whose copies are still at BASE: the ordinary verdicts return untouched. Without this the arm
# above is satisfied by a gate that refuses everything.
ss_assert "prewritten-control" "$(vr_pw_scan "$GATE" "$VR_RC")" "und=1 ok=2 pw=0" \
  "...while the un-written consumer keeps its two OK rows and its one differential UNDECIDED, so the refusal reads the tree"

# --- THE NEAR-MISS THAT SITES THE SECOND CONJUNCT, IN ITS OWN MINIATURE DISTRIBUTION -----
#
# The second conjunct is `base blob != theirs blob`, and its subject is a script that IS in the
# gating set and whose content did NOT move. The main seed cannot express that, measured rather
# than assumed: `GATING` is `INVOKED` intersected with `git diff --name-only base..theirs --
# core/scripts/`, and `unchanged.sh` -- the obvious candidate -- is byte-identical at both refs,
# so the diff never lists it and the loop never reaches it. An arm aimed at it scores 0 whether
# the conjunct is there or not, which is how the first cut of this battery read a green mutant.
#
# A MODE-ONLY CHANGE IS THE INPUT THAT DISCRIMINATES. `git diff --name-only` lists a path whose
# mode moved 100644 -> 100755 while `rev-parse base:<p>` and `rev-parse theirs:<p>` return the
# SAME blob -- verified in this world below, because the whole arm rests on it. Such a script is
# in the gating set, its consumer copy equals theirs by construction, and only `base != theirs`
# separates it from a genuinely pre-written one.
PW="$(dirname "$DIST")/pw"
rm -rf "$PW"; mkdir -p "$PW/dist/core/scripts" "$PW/dist/core/rules" \
                       "$PW/cons/scripts/ai-dlc" "$PW/cons/.githooks"
git -C "$PW/dist" init -q
printf '0.1.0\n'            > "$PW/dist/VERSION"
printf 'pw machinery\n'     > "$PW/dist/core/rules/pw.md"
printf '#!/bin/sh\nexit 0\n' > "$PW/dist/core/scripts/moved.sh"
printf '#!/bin/sh\nexit 0\n' > "$PW/dist/core/scripts/modeonly.sh"
chmod 644 "$PW/dist/core/scripts/modeonly.sh"
git -C "$PW/dist" add -A >/dev/null 2>&1
git -C "$PW/dist" -c user.email=f@x -c user.name=f commit -qm base >/dev/null 2>&1
PW_BASE="$(git -C "$PW/dist" rev-parse HEAD)"
printf '0.2.0\n'                          > "$PW/dist/VERSION"
printf '#!/bin/sh\n# reworded\nexit 0\n'   > "$PW/dist/core/scripts/moved.sh"
chmod 755 "$PW/dist/core/scripts/modeonly.sh"
git -C "$PW/dist" add -A >/dev/null 2>&1
git -C "$PW/dist" -c user.email=f@x -c user.name=f commit -qm theirs >/dev/null 2>&1
PW_THEIRS="$(git -C "$PW/dist" rev-parse HEAD)"
# The consumer holds BOTH at theirs' content: the offender because step 2 wrote it, the near-miss
# because its content never moved. That is the whole point -- one property apart.
git -C "$PW/dist" show "${PW_THEIRS}:core/scripts/moved.sh"    > "$PW/cons/scripts/ai-dlc/moved.sh"
git -C "$PW/dist" show "${PW_THEIRS}:core/scripts/modeonly.sh" > "$PW/cons/scripts/ai-dlc/modeonly.sh"
printf '#!/usr/bin/env bash\nbash scripts/ai-dlc/moved.sh\nbash scripts/ai-dlc/modeonly.sh\n' \
  > "$PW/cons/.githooks/pre-push"
chmod +x "$PW/cons/.githooks/pre-push" "$PW/cons/scripts/ai-dlc"/*.sh

# PRECONDITION, AND THE ARM BELOW IS VACUOUS WITHOUT IT. A mode flip git did not record leaves
# the near-miss out of the gating set entirely, and its silence would then mean nothing.
ss_assert "prewritten-nm-seed" \
  "$(git -C "$PW/dist" diff --name-only "${PW_BASE}..${PW_THEIRS}" -- core/scripts/ | sort | tr '\n' ',')|$([ "$(git -C "$PW/dist" rev-parse "${PW_BASE}:core/scripts/modeonly.sh")" = "$(git -C "$PW/dist" rev-parse "${PW_THEIRS}:core/scripts/modeonly.sh")" ] && printf same-blob || printf moved)" \
  "core/scripts/modeonly.sh,core/scripts/moved.sh,|same-blob" \
  "the mode-only script IS in the range's changed set while its blob never moved, so it reaches the loop and only the second conjunct can excuse it"

pw_rows() { # pw_rows <gate> <script> -> "<status>|<pw-marker>"
  local o
  o="$(bash "$1" "$PW/dist" "$PW_BASE" "$PW_THEIRS" "$PW/cons" 2>/dev/null)"
  printf '%s|%s\n' \
    "$(printf '%s\n' "$o" | awk -F'\t' -v s="$2" '$2 == s {print $1; exit}')" \
    "$(printf '%s\n' "$o" | awk -F'\t' -v s="$2" '$2 == s && $3 ~ /ALREADY at theirs/ {print "pw"; exit}')"
}

ss_assert "prewritten-nm-offender" "$(pw_rows "$GATE" moved.sh)" "SELF-UPDATE-UNDECIDED|pw" \
  "the script the range genuinely changed, held at theirs by the consumer, is refused"
ss_assert "prewritten-nearmiss" "$(pw_rows "$GATE" modeonly.sh)" "SELF-UPDATE-OK|" \
  "...while the mode-only script beside it, at theirs for a reason the pull did not create, keeps its ordinary verdict"

# --- MUTANTS on the pre-written arm ----------------------------------------------------
# `prewritten-control` above is the unmutated control and it is PRESENCE-shaped on ok=2, so a
# gate replaced by `exit 0` fails it rather than scoring these as kills.
VR_M8="$(vr_mut m8 'index($0,"  if [ -n \"$gi_cur_h\" ] && [ -n \"$gi_th_h\" ]") { print "  if false; then"; next } { print }')"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$GATE" "$VR_M8"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s mutation matched nothing, so the arm it scores is unproven\n' "prewritten-mut"
else
  vr_m8_got="$(vr_pw_scan "$VR_M8" "$VR_PW")"
  if [ "$vr_m8_got" = "und=0 ok=4 pw=0" ]; then
    printf '  ok    %-16s KILLED (%s)\n' "prewritten-mut" \
      "with the arm gone the post-write tree reports OK for every gating script -- the verdict that was DEFER before the write"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: got=[%s] want=[und=0 ok=4 pw=0]\n' "prewritten-mut" "$vr_m8_got"
  fi
fi

# THE SECOND CONJUNCT HAS ITS OWN MUTANT, because dropping it changes no cell on the OFFENDER and
# `prewritten-mut` would score identically. Its subject is the near-miss world above: without
# `base != theirs` the guard refuses the mode-only script too, on a consumer that is merely
# current. Scored as a PAIR -- the near-miss moves and the offender does NOT -- so a mutation that
# broke the arm outright cannot pass as this kill.
VR_M9="$(vr_mut m9 'index($0,"[ \"$gi_ba_h\" != \"$gi_th_h\" ]") { sub(/\[ "\$gi_ba_h" != "\$gi_th_h" \]/, "true") } { print }')"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$GATE" "$VR_M9"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s mutation matched nothing, so the arm it scores is unproven\n' "prewritten-mut-conj"
else
  vr_m9_got="$(pw_rows "$VR_M9" modeonly.sh)|$(pw_rows "$VR_M9" moved.sh)"
  if [ "$vr_m9_got" = "SELF-UPDATE-UNDECIDED|pw|SELF-UPDATE-UNDECIDED|pw" ]; then
    printf '  ok    %-16s KILLED (%s)\n' "prewritten-mut-conj" \
      "without the base != theirs conjunct the mode-only script is refused too, on a consumer that is merely current"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: got=[%s] want=[SELF-UPDATE-UNDECIDED|pw|SELF-UPDATE-UNDECIDED|pw]\n' \
      "prewritten-mut-conj" "$vr_m9_got"
  fi
fi


# ONE ROW PER CONSUMER PATH, AND THE DEDUP IS LOAD-BEARING RATHER THAN COSMETIC. Two sites record
# a gating script: the hook-named loop and the machinery loop, which `map_consumer` sends to the
# same consumer path. Unmutated they emit BYTE-IDENTICAL rows -- same path, same digest, same core
# path -- and `sort -u` collapses them to one. A reader iterating rows would otherwise check the
# same file twice, and worse, two rows for one path that DISAGREED in any column would give it two
# answers with no rule for choosing. Measured on this seed: 8 lines, one per consumer file.
ss_assert "rec-inputs-unique" \
  "$(vr_in "$VR_REC1" | awk -F'\t' '{print $1}' | sort | uniq -d | grep -c .)" "0" \
  "no consumer path appears twice, so the two recording sites agree in every column and collapse"
# CONTROL: the dedup has a subject -- the machinery loop really does reach the same paths, so the
# zero above is agreement rather than a set the second site never touched.
# READ OFF `$CONS`, THE SEED'S OWN CONSUMER, AND NOT OFF `$VR_C1`. The edit-detection arm below
# REWRITES `$VR_C1`'s hook to a script naming nothing -- deliberately, that is its whole subject --
# and a hook naming no scripts intersects the machinery set in zero members, so this control would
# read `none` and fail while describing a tree nobody was asserting about.
# THE HOOK-NAME CLASS IS READ OUT OF THE GATE, never retyped here. An ASCII copy of it could not
# spell a hook-named `café.sh`, so the intersection below would come out short for exactly the
# names the gate's widened class records, and the two counts would disagree for a reason that is
# the fixture's. Extracted from the gate's own INVOKED line; an extraction that finds nothing is a
# broken fixture, not an empty hook.
VR_HOOK_CLASS="$(awk -v q="'" 'index($0,"INVOKED=\"$(grep -oE " q) == 1 { s = substr($0, length("INVOKED=\"$(grep -oE " q) + 1); e = index(s, q " \"$HOOK\""); if (e) print substr(s, 1, e - 1); exit }' "$GATE")"
VR_Q="'"; VR_QQ="'\"'\"'"
VR_HOOK_CLASS="${VR_HOOK_CLASS//$VR_QQ/$VR_Q}"
# PROBED BY WHAT IT CAPTURES, not by its spelling: the extracted class must take a non-ASCII hook
# name whole and stop at `;`. An extraction that found nothing reads the impossible default and
# captures 0; an ASCII class captures 0 too, which is the narrowing this replaced.
vr_cls_n="$(printf 'bash scripts/ai-dlc/caf\303\251.sh;\n' | grep -oE "${VR_HOOK_CLASS:-NO-CLASS-WAS-READ}" | grep -cx "scripts/ai-dlc/caf$(printf '\303\251').sh")" || vr_cls_n=0
ss_assert "rec-hook-class-read" "$vr_cls_n" "1" \
  "the hook-name class both intersections below use is the gate's own, extracted rather than retyped, and it spells a non-ASCII name"
ss_assert "rec-inputs-unique-control" \
  "$(bash "$SU/mach/list-machinery.sh" "$DIST" "$BASE" "$THEIRS" 2>/dev/null \
     | sed -n 's|^core/scripts/||p' | sort -u \
     | grep -Fxf <(grep -oE "$VR_HOOK_CLASS" "$CONS/.githooks/pre-push" | sed 's|.*/||' | sort -u) \
     | grep -c . | awk '{print ($1 > 0) ? "overlap" : "none"}')" \
  "overlap" "...and the two recording sites really do overlap on some script, so the collapse is agreement rather than a set the second site never touched"

# THE CORE-PATH COLUMN HAS ITS OWN MUTANT. Written as `-` for a script, the record keeps every
# path and every digest and the reader loses the theirs blob it needs to accept a file the slice
# legitimately moved -- so every self-update whose range changes a gating script is refused.
#
# IT MOVES A SECOND CELL, AND THAT IS THE MUTATION RATHER THAN AN ENTANGLEMENT. With column 3
# differing between the two recording sites their rows stop being identical, `sort -u` no longer
# collapses them, and the same consumer path appears TWICE with contradictory core paths. Both
# outcomes are the one defect and both are asserted, because a mutant scored on the column alone
# would read identically to one that also made the record self-contradictory.
VR_M10="$(vr_mut m10 'index($0,"  gate_input \"scripts/ai-dlc/$gi_name\" \"core/scripts/$gi_name\"") { print "  gate_input \"scripts/ai-dlc/$gi_name\" \"-\""; next } { print }')"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$GATE" "$VR_M10"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s mutation matched nothing, so the arm it scores is unproven\n' "rec-mut-corepath"
else
  VR_C10="$(vr_cons m10c)"
  bash "$VR_M10" "$DIST" "$BASE" "$THEIRS" "$VR_C10" >/dev/null 2>&1
  VR_R10="$(vr_newest "$VR_C10")"
  vr_m10_got="$(vr_in_c "$VR_R10" 'scripts/ai-dlc/gate-defer.sh')|$(vr_in_c "$VR_R10" '.githooks/pre-push')|dup=$(vr_in "$VR_R10" | awk -F'\t' '{print $1}' | sort | uniq -d | grep -c .)"
  # THE DUPLICATE COUNT IS DERIVED, NOT SPELLED: it is the INTERSECTION of the two recording
  # sites -- the scripts the hook names AND the machinery set covers. `not-invoked.sh` is in the
  # machinery set and not in the hook, so it is recorded once and cannot duplicate; a literal here
  # would go vacuous the day the seed's hook gains a line.
  vr_m10_dup="$(grep -oE "$VR_HOOK_CLASS" "$CONS/.githooks/pre-push" | sed 's|.*/||' | sort -u \
                | grep -Fxf <(bash "$SU/mach/list-machinery.sh" "$DIST" "$BASE" "$THEIRS" 2>/dev/null \
                              | sed -n 's|^core/scripts/||p' | sort -u) | grep -c .)" || vr_m10_dup=0
  vr_m10_want="-|core/git-hooks/pre-push|dup=$vr_m10_dup"
  if [ "$vr_m10_got" = "$vr_m10_want" ] && [ "$vr_m10_dup" -gt 0 ] 2>/dev/null; then
    printf '  ok    %-16s KILLED (%s)\n' "rec-mut-corepath" \
      "a script row whose core path is - leaves the reader no theirs blob for the write, and breaks the dedup so every doubly-recorded path carries two contradictory rows"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: got=[%s] want=[%s]\n' "rec-mut-corepath" "$vr_m10_got" "$vr_m10_want"
  fi
fi
fi
if sg pl; then
# --- A SCRIPT A PRIOR SELF-UPDATE LANDED IS NOT ONE THIS CYCLE PRE-WROTE: THE `PL` MINIATURE ----
#
# The pre-written arm above refuses a consumer copy already at theirs, and its remedy is "re-run with
# the range the stamp names". A consumer whose PREVIOUS self-update wrote the script already did:
# step 2 passes the stamp's `commit`, which advances only at the gated apply, so base..theirs still
# spans the release that self-update took, and the copy is at theirs because that cycle wrote it.
# The gate acquits such a script (`landed by the prior self-update`) only when ALL six conjuncts
# hold: A1 the stamp's skill_commit peels to SK; A2 SK != theirs; A3 blob(SK) == the copy; A4 base
# <= SK <= theirs by ancestry; A5 no `.ai-dlc-applying`; A6 the copy is COMMITTED at HEAD. Every
# world below fails EXACTLY ONE conjunct, or none, and each conjunct has its own mutant.
#
# THE PW MINIATURE ABOVE CANNOT EXPRESS THIS, measured rather than assumed: it has no middle commit
# for a skill_commit to name and its consumer is not a git repository, so A6 fails on every world
# it can build and the acquittal is unreachable there. Hence a second distribution:
#   pre    moved.sh ALREADY at its final content        (behind base: a skill_commit there is off the range)
#   base   moved.sh rewritten, late.sh at its first content
#   mid   moved.sh reaches its FINAL content           (the prior self-update's skill_commit)
#   theirs VERSION bumped, late.sh changed               (moved.sh untouched: mid blob == theirs blob)
#   side   mid's TREE on a commit whose parent is base   (same blob, NOT an ancestor of theirs)
#
# EACH WORLD CARRIES ITS OWN REFS in `.B`/`.T` beside its consumer, and every drive reads those,
# never the globals. EACH DRIVE COPIES THE WORLD into a fresh directory, because the gate writes a
# record under the consumer's `_bmad-output/` on every run and a world re-driven by seven mutants
# would otherwise read a tree the previous drive changed.
PL="$(dirname "$DIST")/pl"
mkdir -p "$PL/dist/core/scripts" "$PL/dist/core/rules"
git -C "$PL/dist" init -q
pl_commit() { # pl_commit <msg> -> sha
  git -C "$PL/dist" add -A >/dev/null 2>&1
  git -C "$PL/dist" -c user.email=f@x -c user.name=f commit -qm "$1" >/dev/null 2>&1
  git -C "$PL/dist" rev-parse HEAD
}
printf '0.1.0\n'                > "$PL/dist/VERSION"
printf 'pl machinery\n'         > "$PL/dist/core/rules/pl.md"
printf '#!/bin/sh\n# landed by the prior cycle\nexit 0\n' > "$PL/dist/core/scripts/moved.sh"
printf '#!/bin/sh\n# late\nexit 0\n' > "$PL/dist/core/scripts/late.sh"
PL_PRE="$(pl_commit pre)"
printf '#!/bin/sh\nexit 0\n'    > "$PL/dist/core/scripts/moved.sh"
PL_BASE="$(pl_commit base)"
printf '#!/bin/sh\n# landed by the prior cycle\nexit 0\n' > "$PL/dist/core/scripts/moved.sh"
PL_MID="$(pl_commit mid)"
printf '0.2.0\n'                > "$PL/dist/VERSION"
printf '#!/bin/sh\n# late, reworded in mid..theirs\nexit 0\n' > "$PL/dist/core/scripts/late.sh"
PL_THEIRS="$(pl_commit theirs)"
# The side commit is built with `commit-tree`, so the dist's working tree and HEAD never move.
PL_SIDE="$(git -C "$PL/dist" -c user.email=f@x -c user.name=f commit-tree "${PL_MID}^{tree}" -p "$PL_BASE" -m side 2>/dev/null)"
git -C "$PL/dist" update-ref refs/heads/pl-side "$PL_SIDE" >/dev/null 2>&1

PL_HOOK_RUN='#!/usr/bin/env bash
bash scripts/ai-dlc/moved.sh || exit 1
bash scripts/ai-dlc/late.sh || exit 1
'
PL_HOOK_MENTION='#!/usr/bin/env bash
# scripts/ai-dlc/moved.sh is named here and never run, so its exit status gates nothing
bash scripts/ai-dlc/late.sh || exit 1
'
pl_world() { # pl_world <name> <moved-ref> <late-ref> <hook-text> -> world dir (consumer COMMITTED)
  local w="$PL/w-$1"
  mkdir -p "$w/cons/scripts/ai-dlc" "$w/cons/.githooks" "$w/cons/.claude"
  printf '%s\n' "$PL_BASE"   > "$w/.B"
  printf '%s\n' "$PL_THEIRS" > "$w/.T"
  git -C "$PL/dist" show "${2}:core/scripts/moved.sh" > "$w/cons/scripts/ai-dlc/moved.sh"
  git -C "$PL/dist" show "${3}:core/scripts/late.sh"  > "$w/cons/scripts/ai-dlc/late.sh"
  printf '%s' "$4" > "$w/cons/.githooks/pre-push"
  chmod +x "$w/cons/.githooks/pre-push" "$w/cons/scripts/ai-dlc"/*.sh
  git -C "$w/cons" init -q
  git -C "$w/cons" add -A >/dev/null 2>&1
  git -C "$w/cons" -c user.email=f@x -c user.name=f commit -qm seed >/dev/null 2>&1
  printf '%s\n' "$w"
}
pl_stamp() { # pl_stamp <world> <skill_commit> -- abbreviated to 8 chars, as the reference consumer writes it
  printf 'version: 0.1.0\ncommit: %s\nskill_version: 0.2.0\nskill_commit: %s\n' \
    "$(cat "$1/.B")" "$(printf '%s' "$2" | cut -c1-8)" > "$1/cons/.claude/.ai-dlc-version"
}
pl_drive() { # pl_drive <gate> <world> -> path of the gate's stdout, from a fresh copy of the consumer
  local d
  d="$(mktemp -d "$PL/drive.XXXXXX")"
  cp -R "$2/cons/." "$d/"
  bash "$1" "$PL/dist" "$(cat "$2/.B")" "$(cat "$2/.T")" "$d" > "$d.out" 2>/dev/null
  printf '%s\n' "$d.out"
}
# "<status>|<tags>", tags a `+`-joined subset of {landed, pw, ng}. Compared by EXACT equality, so a
# row carrying the acquittal marker AND the refusal marker cannot pass for either.
pl_row() { # pl_row <gate> <world> <script>
  awk -F'\t' -v s="$3" '$2 == s {
      t = ""
      if ($3 ~ /landed by the prior self-update/) t = t (t == "" ? "" : "+") "landed"
      if ($3 ~ /ALREADY at theirs/)              t = t (t == "" ? "" : "+") "pw"
      if ($3 ~ /^not gating/)                    t = t (t == "" ? "" : "+") "ng"
      print $1 "|" t; exit }' "$(pl_drive "$1" "$2")"
}

PL_W1="$(pl_world w1 "$PL_MID" "$PL_BASE" "$PL_HOOK_RUN")"; pl_stamp "$PL_W1" "$PL_MID"
PL_W2="$(pl_world w2 "$PL_MID" "$PL_BASE" "$PL_HOOK_RUN")"; pl_stamp "$PL_W2" "$PL_THEIRS"
# W3 is POST-WRITE, COMMITTED, PRE-STAMP: late.sh at theirs and committed, the stamp still at mid.
# Committed ON PURPOSE -- uncommitted, A6 would fail beside A3 and the A3 mutant could not kill.
PL_W3="$(pl_world w3 "$PL_MID" "$PL_THEIRS" "$PL_HOOK_RUN")"; pl_stamp "$PL_W3" "$PL_MID"
PL_W4="$(pl_world w4 "$PL_MID" "$PL_BASE" "$PL_HOOK_RUN")"; pl_stamp "$PL_W4" "$PL_MID"
: > "$PL_W4/cons/.claude/.ai-dlc-applying"
PL_W5="$(pl_world w5 "$PL_MID" "$PL_BASE" "$PL_HOOK_RUN")"; pl_stamp "$PL_W5" "$PL_SIDE"
PL_W6="$(pl_world w6 "$PL_MID" "$PL_BASE" "$PL_HOOK_RUN")"
# W7, THE HOLE: HEAD holds moved.sh at BASE, the working copy was overwritten with theirs' bytes
# after that commit and never committed, the stamp still at mid. A1-A5 all hold; only A6 sees it.
PL_W7="$(pl_world w7 "$PL_BASE" "$PL_BASE" "$PL_HOOK_RUN")"; pl_stamp "$PL_W7" "$PL_MID"
git -C "$PL/dist" show "${PL_THEIRS}:core/scripts/moved.sh" > "$PL_W7/cons/scripts/ai-dlc/moved.sh"
PL_W8="$(pl_world w8 "$PL_MID" "$PL_BASE" "$PL_HOOK_MENTION")"
# W9 is W1 with the stamp BEHIND base: pre carries theirs' bytes, and A2, A3, A5 and A6 all hold,
# as does SK <= theirs. Only A4's base <= SK half refuses it.
PL_W9="$(pl_world w9 "$PL_MID" "$PL_BASE" "$PL_HOOK_RUN")"; pl_stamp "$PL_W9" "$PL_PRE"

# PRECONDITIONS, AND EVERY WORLD BELOW IS VACUOUS WITHOUT THEM: both scripts are in the range's
# changed set; moved.sh moved in base..mid and NOT in mid..theirs (so mid's blob IS theirs'); the
# side commit holds that same blob and is not an ancestor of theirs; the run-hook READS both exit
# statuses; W7's HEAD really is at base while its working copy is at theirs.
pl_blob() { git -C "$PL/dist" rev-parse "${1}:core/scripts/${2}" 2>/dev/null; }
ss_assert "pl-seed" \
  "$(git -C "$PL/dist" diff --name-only "${PL_BASE}..${PL_THEIRS}" -- core/scripts/ | sort | tr '\n' ',')|$([ "$(pl_blob "$PL_BASE" moved.sh)" != "$(pl_blob "$PL_MID" moved.sh)" ] && printf moved || printf same)|$([ "$(pl_blob "$PL_MID" moved.sh)" = "$(pl_blob "$PL_THEIRS" moved.sh)" ] && printf mid=theirs || printf mid!=theirs)|$([ "$(pl_blob "$PL_SIDE" moved.sh)" = "$(pl_blob "$PL_MID" moved.sh)" ] && printf side=mid || printf side!=mid)|$(git -C "$PL/dist" merge-base --is-ancestor "$PL_SIDE" "$PL_THEIRS" 2>/dev/null && printf onrange || printf offrange)|runs=$(grep -c ' || exit 1$' "$PL_W1/cons/.githooks/pre-push" || :)|w7=$([ "$(git -C "$PL_W7/cons" rev-parse HEAD:scripts/ai-dlc/moved.sh 2>/dev/null)" = "$(pl_blob "$PL_BASE" moved.sh)" ] && [ "$(git hash-object "$PL_W7/cons/scripts/ai-dlc/moved.sh")" = "$(pl_blob "$PL_THEIRS" moved.sh)" ] && printf head-base,wc-theirs || printf other)|$(git -C "$PL/dist" merge-base --is-ancestor "$PL_PRE" "$PL_BASE" 2>/dev/null && printf pre-behind-base || printf pre-other)|$([ "$(pl_blob "$PL_PRE" moved.sh)" = "$(pl_blob "$PL_THEIRS" moved.sh)" ] && printf pre=theirs || printf pre!=theirs)" \
  "core/scripts/late.sh,core/scripts/moved.sh,|moved|mid=theirs|side=mid|offrange|runs=2|w7=head-base,wc-theirs|pre-behind-base|pre=theirs" \
  "both scripts are in the gating set, moved.sh's final bytes landed at mid, the side commit carries them off the range, W7's HEAD and working copy disagree, and pre sits behind base holding theirs' bytes"

# W1 CARRIES ITS OWN CONTROL ROW: late.sh, at base and gating, gets the ordinary OK with NO marker,
# so the two rows prove both scripts reached the differential side of the not-gating terminal.
ss_assert "pl-w1-landed" "$(pl_row "$GATE" "$PL_W1" moved.sh);$(pl_row "$GATE" "$PL_W1" late.sh)" \
  "SELF-UPDATE-OK|landed;SELF-UPDATE-OK|" \
  "a gating script the prior self-update at mid wrote, committed, stamp still at mid, is acquitted as landed -- while its unwritten sibling keeps the ordinary verdict"
ss_assert "pl-w2-poststamp" "$(pl_row "$GATE" "$PL_W2" moved.sh)" "SELF-UPDATE-UNDECIDED|pw" \
  "...the same tree with the stamp rewritten to theirs is a post-write re-run, and is refused (A2)"
ss_assert "pl-w3-prestamp" "$(pl_row "$GATE" "$PL_W3" late.sh);$(pl_row "$GATE" "$PL_W3" moved.sh)" \
  "SELF-UPDATE-UNDECIDED|pw;SELF-UPDATE-OK|landed" \
  "written and committed but not yet re-stamped: late.sh, which mid..theirs changes, is refused (A3) while moved.sh in the same run is acquitted"
ss_assert "pl-w4-applying" "$(pl_row "$GATE" "$PL_W4" moved.sh)" "SELF-UPDATE-UNDECIDED|pw" \
  "W1's tree with .ai-dlc-applying on disk is a partial apply, and the stamp does not vouch for it (A5)"
ss_assert "pl-w5-offrange" "$(pl_row "$GATE" "$PL_W5" moved.sh)" "SELF-UPDATE-UNDECIDED|pw" \
  "a skill_commit on a side branch holding the identical blob is not a self-update inside base..theirs (A4)"
ss_assert "pl-w6-nostamp" "$(pl_row "$GATE" "$PL_W6" moved.sh)" "SELF-UPDATE-UNDECIDED|pw" \
  "no stamp, no skill_commit, no acquittal (A1)"
ss_assert "pl-w7-dirty" "$(pl_row "$GATE" "$PL_W7" moved.sh)" "SELF-UPDATE-UNDECIDED|pw" \
  "the copy at theirs is UNCOMMITTED over a HEAD at base -- this cycle's write, not the prior one's -- and is refused (A6)"
ss_assert "pl-w8-notgating" "$(pl_row "$GATE" "$PL_W8" moved.sh)" "SELF-UPDATE-OK|ng" \
  "a pre-written script the hook only MENTIONS has no differential to refuse: OK, not gating, with no pre-written marker"
ss_assert "pl-w9-behindbase" "$(pl_row "$GATE" "$PL_W9" moved.sh)" "SELF-UPDATE-UNDECIDED|pw" \
  "a skill_commit BEHIND base carrying theirs' bytes is not a self-update inside base..theirs (A4, base <= SK)"

# --- MUTANTS on the acquittal and on the arm's position ----------------------------------
# ANCHORS ARE COUNTED IN THE GATE, by `index`, never by an interactive grep: each must occur exactly
# once, so a mutation edits one site; an anchor nothing carries must count 0, so a count of 1 is a
# reading and not a constant. None of them is an m8/m9 anchor.
pl_anchor_n() { PL_AN="$1" awk 'index($0, ENVIRON["PL_AN"]) {n++} END {print n+0}' "$GATE"; }
ss_assert "pl-anchors" \
  "$(pl_anchor_n '&& [ "$pl_sk" != "$pl_th" ]')$(pl_anchor_n '[ "$pl_skb" = "$gi_cur_h" ]')$(pl_anchor_n 'git -C "$DIST" merge-base --is-ancestor "$BASE" "$pl_sk" 2>/dev/null')$(pl_anchor_n 'git -C "$DIST" merge-base --is-ancestor "$pl_sk" "$pl_th" 2>/dev/null')$(pl_anchor_n '[ ! -e "$CONSUMER/.claude/.ai-dlc-applying" ]')$(pl_anchor_n '[ -n "$pl_hd" ] && [ "$pl_hd" = "$gi_cur_h" ]')$(pl_anchor_n 'if [ "$pl_sk" != "-" ] && [ -n "$pl_th" ]')$(pl_anchor_n '  # ---- HOW THE HOOK RUNS IT')$(pl_anchor_n '  cur_absent=0')$(pl_anchor_n '> "$TMP/argvs"')|$(pl_anchor_n 'pl_NEVER_IN_THE_GATE_q7Zx')" \
  "1111111111|0" \
  "every mutation below edits exactly one site of the gate, and an anchor the gate lacks counts 0"

# A literal-substring replacement, up to two sites, built through `vr_mut` (siblings beside it).
pl_lit_mut() { # pl_lit_mut <name> <anchor> <repl> [<anchor2> <repl2>] -> mutated gate path
  PL_A1="$2" PL_R1="$3" PL_A2="${4:-}" PL_R2="${5:-}"
  export PL_A1 PL_R1 PL_A2 PL_R2
  vr_mut "$1" 'BEGIN { A1 = ENVIRON["PL_A1"]; R1 = ENVIRON["PL_R1"]; A2 = ENVIRON["PL_A2"]; R2 = ENVIRON["PL_R2"] }
    { i = index($0, A1); if (i) $0 = substr($0, 1, i - 1) R1 substr($0, i + length(A1))
      if (A2 != "") { i = index($0, A2); if (i) $0 = substr($0, 1, i - 1) R2 substr($0, i + length(A2)) }
      print }'
  unset PL_A1 PL_R1 PL_A2 PL_R2
}
# A mutant is scored on THREE drives in one cell: its own world (which must flip), and two worlds it
# must NOT move -- the unmutated W1 acquittal or its refusal twin, and a sibling. A copy that died
# emits nothing and fails the control conjuncts, so silence cannot score as a kill. A copy identical
# to the gate, or of a different length (every mutation here preserves the line count), DID NOT APPLY.
pl_kill() { # pl_kill <label> <gate> <want> <why> <world> <script> <world> <script> <world> <script>
  local got
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ ! -s "$2" ] || cmp -s "$GATE" "$2"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s DID NOT APPLY: the mutation matched nothing, so the conjunct it scores is unproven\n' "$1"
    return
  fi
  if [ "$(wc -l < "$GATE")" != "$(wc -l < "$2")" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s DID NOT APPLY: the mutant has %s lines against %s\n' "$1" "$(wc -l < "$2" | tr -d ' ')" "$(wc -l < "$GATE" | tr -d ' ')"
    return
  fi
  got="$(pl_row "$2" "$5" "$6");$(pl_row "$2" "$7" "$8");$(pl_row "$2" "$9" "${10}")"
  if [ "$got" = "$3" ]; then
    printf '  ok    %-16s KILLED (%s)\n' "$1" "$4"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: got=[%s] want=[%s]  %s\n' "$1" "$got" "$3" "$4"
  fi
}

pl_kill "pl-mut-a2" \
  "$(pl_lit_mut pl-a2 '&& [ "$pl_sk" != "$pl_th" ]' '')" \
  "SELF-UPDATE-OK|landed;SELF-UPDATE-OK|landed;SELF-UPDATE-UNDECIDED|pw" \
  "without SK != theirs the post-stamp re-run is acquitted; W1 and the off-range W5 do not move" \
  "$PL_W2" moved.sh "$PL_W1" moved.sh "$PL_W5" moved.sh
pl_kill "pl-mut-a3" \
  "$(pl_lit_mut pl-a3 '[ "$pl_skb" = "$gi_cur_h" ]' 'true')" \
  "SELF-UPDATE-OK|landed;SELF-UPDATE-OK|landed;SELF-UPDATE-UNDECIDED|pw" \
  "without blob(SK) == the copy, late.sh -- written THIS cycle -- is acquitted; W1 and the post-stamp W2 do not move" \
  "$PL_W3" late.sh "$PL_W1" moved.sh "$PL_W2" moved.sh
# BOTH ANCESTRY HALVES ARE DROPPED, the honest revert of A4, scored on W5 (SK -> theirs: the side
# commit descends from base). The base -> SK half is scored alone by pl-mut-a4-base on W9.
pl_kill "pl-mut-a4" \
  "$(pl_lit_mut pl-a4 'git -C "$DIST" merge-base --is-ancestor "$BASE" "$pl_sk" 2>/dev/null' 'true' 'git -C "$DIST" merge-base --is-ancestor "$pl_sk" "$pl_th" 2>/dev/null' 'true')" \
  "SELF-UPDATE-OK|landed;SELF-UPDATE-OK|landed;SELF-UPDATE-UNDECIDED|pw" \
  "without the ancestry test a side-branch skill_commit carrying the same blob acquits; W1 and W2 do not move" \
  "$PL_W5" moved.sh "$PL_W1" moved.sh "$PL_W2" moved.sh
# ONLY the base -> SK half dropped: W9's stamp behind base acquits, while W1 and the side-branch W5
# (which the SK -> theirs half still refuses) do not move.
pl_kill "pl-mut-a4-base" \
  "$(pl_lit_mut pl-a4b 'git -C "$DIST" merge-base --is-ancestor "$BASE" "$pl_sk" 2>/dev/null' 'true')" \
  "SELF-UPDATE-OK|landed;SELF-UPDATE-OK|landed;SELF-UPDATE-UNDECIDED|pw" \
  "without base <= SK a skill_commit behind base carrying theirs' bytes acquits; W1 and the off-range W5 do not move" \
  "$PL_W9" moved.sh "$PL_W1" moved.sh "$PL_W5" moved.sh
pl_kill "pl-mut-a5" \
  "$(pl_lit_mut pl-a5 '[ ! -e "$CONSUMER/.claude/.ai-dlc-applying" ]' 'true')" \
  "SELF-UPDATE-OK|landed;SELF-UPDATE-OK|landed;SELF-UPDATE-UNDECIDED|pw" \
  "without the applying guard a partial apply's tree is acquitted; W1 and the dirty W7 do not move" \
  "$PL_W4" moved.sh "$PL_W1" moved.sh "$PL_W7" moved.sh
pl_kill "pl-mut-a6" \
  "$(pl_lit_mut pl-a6 '[ -n "$pl_hd" ] && [ "$pl_hd" = "$gi_cur_h" ]' 'true')" \
  "SELF-UPDATE-OK|landed;SELF-UPDATE-OK|landed;SELF-UPDATE-UNDECIDED|pw" \
  "without the committed check this cycle's uncommitted write over a base HEAD is acquitted; W1 and the applying W4 do not move" \
  "$PL_W7" moved.sh "$PL_W1" moved.sh "$PL_W4" moved.sh
# THE WHOLE ACQUITTAL, scored on W1 -- the fix is load-bearing -- with the refusal twin W2 and the
# not-gating W8 as the cells it must not move.
pl_kill "pl-mut-all" \
  "$(pl_lit_mut pl-all 'if [ "$pl_sk" != "-" ] && [ -n "$pl_th" ]' 'if false && [ -n "$pl_th" ]')" \
  "SELF-UPDATE-UNDECIDED|pw;SELF-UPDATE-UNDECIDED|pw;SELF-UPDATE-OK|ng" \
  "with the acquittal unreachable the prior-landed script is refused again; W2 and W8 do not move" \
  "$PL_W1" moved.sh "$PL_W2" moved.sh "$PL_W8" moved.sh
# THE REORDER, REVERTED AS A WHOLE: the pre-written block (`cur_absent=0` up to the `argvs` line)
# moved back above the hook scan. The awk prints the file UNCHANGED unless all three boundaries are
# found in order, so a lost anchor reads DID NOT APPLY rather than as a mutant.
pl_kill "pl-mut-order" \
  "$(vr_mut pl-order '{ L[NR] = $0 }
    !h && index($0, "  # ---- HOW THE HOOK RUNS IT") == 1 { h = NR }
    !c && $0 == "  cur_absent=0" { c = NR }
    !a && index($0, "> \"$TMP/argvs\"") { a = NR }
    END { if (h && c && a && h < c && c < a) {
            for (i = 1; i < h; i++) print L[i]; for (i = c; i < a; i++) print L[i]
            for (i = h; i < c; i++) print L[i]; for (i = a; i <= NR; i++) print L[i] }
          else for (i = 1; i <= NR; i++) print L[i] }')" \
  "SELF-UPDATE-UNDECIDED|pw;SELF-UPDATE-OK|landed;SELF-UPDATE-UNDECIDED|pw" \
  "with the arm back above the not-gating terminal a mention-only pre-written script defers the run; W1 and W6 do not move" \
  "$PL_W8" moved.sh "$PL_W1" moved.sh "$PL_W6" moved.sh

fi
if sg pp; then

# --- THE GATE NEVER RUNS THE PUSH HOOK; THE ENCLOSED LAYOUT IS STILL UNDECIDED -------------
#
# A push refusal that PREDATES the pull is outside every differential by construction. The gate
# used to answer it by running the consumer's whole pre-push hook on the UNWRITTEN tree, and step
# 2's bare `git push` then ran it again on the WRITTEN tree with the incoming hook: two whole-suite
# runs per self-update, the first measuring the wrong hook on the wrong tree. That question now
# belongs to `self-update-push.sh` (its battery is the next section), which runs the hook once, as
# the push. What stays here is (a) the gate runs NO hook -- an executable hook that writes a
# sentinel leaves none behind, with a control proving the hook can write it and a mutant that
# restores a hook call -- and (b) a consumer that is a SUBDIRECTORY of an enclosing repository is
# UNDECIDED on pre-push, because its push would run that repository's hook.
#
# THE WORLDS ARE REPOSITORIES, BECAUSE THE SEED'S CONSUMER IS NOT ONE. Every world above hands the
# gate a bare directory; the enclosed-layout arm keys on git's own answer, so it needs a real work
# tree, given a remote and armed through `core.hooksPath` -- the spelling install.sh documents.
#
# EACH WORLD'S HOOK IS THE SEED'S HOOK PLUS A TAIL. The seed's `.githooks/pre-push` names the
# gating scripts the DIFFERENTIAL reads its set from, so replacing it would empty the
# differential's subject and every summary row would vanish; the tail is appended instead.
PP="$(dirname "$DIST")/pp"
rm -rf "$PP"; mkdir -p "$PP"
PP_SEED_HOOK="$(cat "$CONS/.githooks/pre-push")"

# pp_world <name> <tail|""> <arm:hooksPath|dotgit|none> <remote:yes|no> -> consumer path
# A consumer copied from the seed's, made a repository with one commit, and given a remote unless
# told not to. The hook (seed + tail) lands at `.githooks/pre-push` (armed via core.hooksPath), at
# `.git/hooks/pre-push` (the shim spelling the reference consumer uses; the tracked hook stays the
# seed's), or nowhere.
pp_world() {
  local c="$PP/$1" tail="$2" arm="$3" remote="$4"
  rm -rf "$c"; cp -R "$CONS" "$c"; rm -rf "$c/_bmad-output"
  if [ -n "$tail" ] && [ "$arm" = "hooksPath" ]; then
    printf '%s\n%s\n' "$PP_SEED_HOOK" "$tail" > "$c/.githooks/pre-push"; chmod +x "$c/.githooks/pre-push"
  fi
  ( cd "$c" && git init -q . && git config user.email f@x && git config user.name f \
      && git config commit.gpgsign false && git add -A >/dev/null 2>&1 \
      && git commit -qm seed >/dev/null 2>&1 ) || { printf 'FIXTURE ERROR: pp_world %s init failed\n' "$1" >&2; return 1; }
  [ "$remote" = yes ] && git -C "$c" remote add origin "$PP/nowhere-$1.git"
  case "$arm" in
    hooksPath) git -C "$c" config core.hooksPath .githooks ;;
    dotgit)    mkdir -p "$c/.git/hooks"; printf '%s\n%s\n' "$PP_SEED_HOOK" "$tail" > "$c/.git/hooks/pre-push"; chmod +x "$c/.git/hooks/pre-push" ;;
    none)      ;;
  esac
  printf '%s\n' "$c"
}
# pp_mk <VAR> <pp_world args...> -- build a world and bind its path to VAR, or abort the fixture.
# THE BARE `VAR="$(pp_world ...)"` THIS REPLACES WAS THE RECURSION'S ROOT. pp_world prints its path
# only on success, so a failed build bound an EMPTY string, and `cd ""` in bash is a no-op that exits
# 0 -- the drive below then ran `.githooks/pre-push` from the fixture's own cwd, the repo root, which is
# the DISTRIBUTION hook over the real fixture tree, which runs this fixture again. A failed world is
# therefore fatal here, and no drive trusts a path it has not checked (pp_enter).
pp_mk() {
  local _v="$1" _p; shift
  _p="$(pp_world "$@")" && [ -n "$_p" ] && [ -d "$_p" ] \
    || { printf 'FIXTURE ERROR: pp_world %s produced no world; refusing to drive a hook from %s\n' "$1" "$(pwd -P)" >&2; exit 1; }
  printf -v "$_v" '%s' "$_p"
}
# pp_enter <world> -- cd into a world, REFUSING unless it is non-empty, a directory, and its own git
# toplevel. A world that is a plain subdirectory of an enclosing repository resolves that repository's
# toplevel instead, which is the same escape by a second route (the hook's own `cd "$(git rev-parse
# --show-toplevel)"`). Returns non-zero with a FIXTURE ERROR line; callers join it with `&&`.
pp_enter() {
  local w="$1" pfx
  [ -n "$w" ] && [ -d "$w" ] || { printf 'FIXTURE ERROR: pp_enter: world path [%s] is empty or not a directory\n' "$w" >&2; return 97; }
  # git's own prefix, not two `pwd -P` strings: those disagree in case on case-insensitive APFS.
  pfx="$(git -C "$w" rev-parse --show-prefix 2>/dev/null)" && [ -z "$pfx" ] \
    || { printf 'FIXTURE ERROR: pp_enter: world [%s] is not its own git toplevel (prefix [%s])\n' "$w" "$pfx" >&2; return 98; }
  cd "$w" || return 99
}
# THE ESCAPE, CONSTRUCTED. A stub "distribution" repo whose hook only records that it ran, and a
# drive standing in it -- the fixture's own cwd. Three worlds: an EMPTY path (what a failed pp_world
# binds), a plain subdirectory of that repo (git resolves the ENCLOSING toplevel), and a real world.
# The OLD drive shape `( cd "$w" && .githooks/pre-push )` is run as the control and MUST reach the
# stub in the first two -- that is what proves the escape is constructible and the arm can fire; the
# pp_enter shape must not reach it, and must still reach it in the real world (the ALLOW twin).
PP_ESC="$PP/escape"; rm -rf "$PP_ESC"; mkdir -p "$PP_ESC/repo/.githooks" "$PP_ESC/repo/sub/.githooks" "$PP_ESC/real/.githooks"
printf '#!/usr/bin/env bash\necho ran >> "%s/ran"\nexit 0\n' "$PP_ESC" > "$PP_ESC/repo/.githooks/pre-push"
cp "$PP_ESC/repo/.githooks/pre-push" "$PP_ESC/real/.githooks/pre-push"
# the subdirectory world carries a hook that resolves its toplevel the way the shipped hook does (line 31)
printf '#!/usr/bin/env bash
cd "$(git rev-parse --show-toplevel)" && exec .githooks/pre-push "$@"
' > "$PP_ESC/repo/sub/.githooks/pre-push"
chmod +x "$PP_ESC/repo/sub/.githooks/pre-push"
chmod +x "$PP_ESC/repo/.githooks/pre-push" "$PP_ESC/real/.githooks/pre-push"
( cd "$PP_ESC/repo" && git init -q . ) && ( cd "$PP_ESC/real" && git init -q . ) \
  || { printf 'FIXTURE ERROR: escape worlds did not init\n' >&2; exit 1; }
pp_esc_drive() { # pp_esc_drive <old|new> <world> -> number of times the stub hook ran
  rm -f "$PP_ESC/ran"
  if [ "$1" = old ]; then ( cd "$PP_ESC/repo" && cd "$2" && .githooks/pre-push origin x </dev/null >/dev/null 2>&1 )
  else ( cd "$PP_ESC/repo" && pp_enter "$2" && .githooks/pre-push origin x </dev/null >/dev/null 2>&1 ) 2>/dev/null; fi
  if [ -f "$PP_ESC/ran" ]; then grep -c ran "$PP_ESC/ran"; else echo 0; fi
}
ss_assert "pp-escape-old-empty"  "$(pp_esc_drive old "")"               "1" "control: the old drive shape with an EMPTY world path runs the hook standing in the cwd"
ss_assert "pp-escape-old-subdir" "$(pp_esc_drive old "$PP_ESC/repo/sub")" "1" "control: a subdirectory world is entered, and its hook resolves the ENCLOSING toplevel and runs that repository hook"
ss_assert "pp-escape-new-empty"  "$(pp_esc_drive new "")"               "0" "the guarded drive refuses an EMPTY world path and runs nothing"
ss_assert "pp-escape-new-subdir" "$(pp_esc_drive new "$PP_ESC/repo/sub")" "0" "the guarded drive refuses a world that is a subdirectory of an enclosing repository"
ss_assert "pp-escape-new-real"   "$(pp_esc_drive new "$PP_ESC/real")"    "1" "ALLOW twin: a real world that is its own repository is driven normally, once"

# pp_scan <gate> <consumer> -> "pp=<status|none> sum=<n summary DEFER rows> ss=<n SAFE-STOP rows> und=<n>"
pp_scan() {
  local o
  o="$(bash "$1" "$DIST" "$BASE" "$THEIRS" "$2" 2>/dev/null)"
  printf 'pp=%s sum=%s ss=%s und=%s\n' \
    "$(printf '%s\n' "$o" | awk -F'\t' '$2 == "pre-push" {print $1; exit} END{if (!NR) print "none"}' | { read -r x; printf '%s' "${x:-none}"; })" \
    "$(printf '%s\n' "$o" | awk -F'\t' '$1 == "SELF-UPDATE-DEFER" && $2 == "-" {n++} END{print n+0}')" \
    "$(printf '%s\n' "$o" | awk -F'\t' '$1 == "SELF-UPDATE-SAFE-STOP" {n++} END{print n+0}')" \
    "$(printf '%s\n' "$o" | awk -F'\t' '$1 == "SELF-UPDATE-UNDECIDED" {n++} END{print n+0}')"
}
# The tail appended to the seed's hook, whose own last line exits 0.
PP_HOOK_GREEN='exit 0'

# 1. NO pre-push ROW ON A NON-REPOSITORY OR A HEALTHY REPOSITORY. The gate judges no push on either;
#    the differential's own DEFER/SAFE-STOP pair is what remains, so the scan is not reading a dead gate.
ss_assert "pp-nonrepo-silent" "$(pp_scan "$GATE" "$(vr_cons ppnonrepo)")" \
  "pp=none sum=1 ss=1 und=1" \
  "the seed's consumer is a bare directory: no pre-push row, and the differential's DEFER/SAFE-STOP pair is what remains"
pp_mk PP_GREEN green "$PP_HOOK_GREEN" hooksPath yes
ss_assert "pp-green" "$(pp_scan "$GATE" "$PP_GREEN")" \
  "pp=none sum=1 ss=1 und=1" \
  "a repository that is its own toplevel, with a remote and an armed hook: the gate emits no pre-push row (the push wrapper owns that question) and the differential's verdicts are untouched"

# ENCLOSED CONSUMER (PP-ENC BEGIN). A consumer that is a plain SUBDIRECTORY of an enclosing repository
# passes `--is-inside-work-tree`, and git's hook path then resolves the ENCLOSING repository's hook.
# The enclosing world has an executable hook that writes a sentinel, a hooksPath and a remote; the
# consumer is a copy of the seed's inside it. The gate must answer UNDECIDED on pre-push, naming
# the unsupported layout -- never the non-repository's silence, which would acquit a push that runs
# the enclosing hook unprobed -- and the sentinel must be ABSENT. The control, one property apart, is a real repository
# with the same hook: the sentinel IS written, so an absent sentinel is the guard and not a hook that
# cannot write.
PP_SENT_HOOK="$(printf 'touch "%s/sentinel"' "$PP/sent")"
rm -rf "$PP/sent"; mkdir -p "$PP/sent"
pp_mk PP_ENC enc "$PP_SENT_HOOK" hooksPath yes
rm -rf "$PP_ENC/sub"; cp -R "$CONS" "$PP_ENC/sub"; rm -rf "$PP_ENC/sub/.git" "$PP_ENC/sub/_bmad-output"
# pp_layout <gate> <consumer> -> count of pre-push UNDECIDED rows whose text NAMES the layout. Presence-
# shaped on the message, because a status count alone passes against any other UNDECIDED (an unborn
# HEAD, a detached one).
pp_layout() {
  bash "$1" "$DIST" "$BASE" "$THEIRS" "$2" 2>/dev/null \
    | awk -F'\t' '$1 == "SELF-UPDATE-UNDECIDED" && $2 == "pre-push" && $3 ~ /UNSUPPORTED LAYOUT/ && $3 ~ /subdirectory of the enclosing repository/ {n++} END{print n+0}'
}
pp_enc_row="$(pp_scan "$GATE" "$PP_ENC/sub")"; pp_enc_hit="$([ -e "$PP/sent/sentinel" ] && echo written || echo absent)"
ss_assert "pp-enclosed-undecided" "$pp_enc_row|$pp_enc_hit" "pp=SELF-UPDATE-UNDECIDED sum=0 ss=0 und=1|absent" \
  "a consumer that is a subdirectory of an enclosing repository is UNDECIDED on pre-push, which SKILL.md step 2 stops on, and the enclosing repository's hook is never run"
rm -f "$PP/sent/sentinel"
ss_assert "pp-enclosed-names-layout" "$(pp_layout "$GATE" "$PP_ENC/sub")" "1" \
  "...and the row names the unsupported layout, so the operator reads the remedy and not just a status"
rm -f "$PP/sent/sentinel"
# MUTANT: the UNDECIDED block's guard made false restores round 2's silence. Built beside the gate's
# siblings (machinery_paths reads setup-sites.md beside $0) with an unmutated control that must
# reproduce the layout row first, so a copy that cannot run does not score as a kill. Under the mutant
# the gate falls through to the differential, which runs no hook, so the enclosing hook must STILL not run.
PPE_ANCHOR='^if \[ -n "\$pp_enclosed" \]; then$'
ss_assert "pp-enclosed-anchor" "$(grep -c "$PPE_ANCHOR" "$GATE")" "1" \
  "the enclosed-layout mutation's anchor matches exactly one line"
ss_assert "pp-enclosed-anchor-ctl" \
  "$(grep -c '^if \[ -n "\$pp_enclosed_NOT_A_VAR" \]; then$' "$GATE")" "0" \
  "an impossible anchor of the same shape returns 0, so the 1 above is a match and not a grammar artefact"
PPE_MUT="$(dirname "$DIST")/ppemut"
rm -rf "$PPE_MUT"; mkdir -p "$PPE_MUT/mut" "$PPE_MUT/ctl"
cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$PPE_MUT/mut"/ 2>/dev/null
cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$PPE_MUT/ctl"/ 2>/dev/null
ss_assert "pp-enclosed-mut-control" "$(pp_layout "$PPE_MUT/ctl/self-update-gate.sh" "$PP_ENC/sub")" "1" \
  "an UNMUTATED copy beside its siblings reproduces the layout row, so a mutant's silence is the mutation"
rm -f "$PP/sent/sentinel"
sed "s@${PPE_ANCHOR}@if false; then@" "$GATE" > "$PPE_MUT/mut/self-update-gate.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$GATE" "$PPE_MUT/mut/self-update-gate.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-16s mutation matched nothing, so the enclosed-layout arm is unproven\n' "pp-enclosed-mut"
else
  ppe_got="$(pp_scan "$PPE_MUT/mut/self-update-gate.sh" "$PP_ENC/sub")|$([ -e "$PP/sent/sentinel" ] && echo written || echo absent)"
  if [ "$ppe_got" = "pp=none sum=1 ss=1 und=1|absent" ]; then
    printf '  ok    %-16s KILLED (%s)\n' "pp-enclosed-mut" \
      "with the layout block disabled the enclosed consumer reads round 2's silence again, and the enclosing hook still does not run"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED or moved elsewhere: got=[%s] want=[%s]\n' "pp-enclosed-mut" "$ppe_got" "pp=none sum=1 ss=1 und=1|absent"
  fi
fi
rm -f "$PP/sent/sentinel"
# ...and the mutant leaves a real repository's answer where it was: the block never fires there.
ss_assert "pp-enclosed-mut-green" "$(pp_scan "$PPE_MUT/mut/self-update-gate.sh" "$PP_GREEN")" \
  "pp=none sum=1 ss=1 und=1" "the mutant does not move the green world, so it owns only the enclosed case"
rm -f "$PP/sent/sentinel"
# A HEALTHY CONSUMER REACHED BY A MISCASED PATH IS NOT ENCLOSED. On case-insensitive APFS bash's
# `pwd -P` keeps the case the caller typed while git answers the on-disk case, so a layout decided by
# comparing those two strings called this consumer enclosed and stopped its pull. The green world is
# re-spelled with its LAST path component -- the world directory itself -- uppercased. NOT the first:
# measured, the first component of a macOS TMPDIR is `/var`, a SYMLINK, and `pwd -P` resolves it to
# `/private/var` in the on-disk case, so the miscased input never reached the comparison and the mutant
# survived. The arm is DISCRIMINATING only where the miscased path resolves AND its `pwd -P` differs
# from git's toplevel; both are asserted before any verdict is read, and a case-sensitive filesystem
# SKIPs the arm with its reason rather than passing.
PP_GREEN_MIS="$(dirname "$PP_GREEN")/$(basename "$PP_GREEN" | tr '[:lower:]' '[:upper:]')"
if [ "$PP_GREEN_MIS" = "$PP_GREEN" ] || [ ! -d "$PP_GREEN_MIS" ]; then
  printf '  SKIP  %-16s the miscased spelling [%s] does not resolve here (case-sensitive filesystem, or no letter to re-case), so the case arm cannot be built\n' "pp-case" "$PP_GREEN_MIS"
else
  pp_case_typed="$(cd "$PP_GREEN_MIS" && pwd -P)"; pp_case_git="$(git -C "$PP_GREEN_MIS" rev-parse --show-toplevel 2>/dev/null)"
  ss_assert "pp-case-discriminates" "$([ "$pp_case_typed" != "$pp_case_git" ] && echo differ || echo same)" "differ" \
    "the miscased path's pwd -P [$pp_case_typed] differs from git's toplevel [$pp_case_git], so a string comparison WOULD misread it -- the input separates the two rules"
  ss_assert "pp-case-ok" "$(pp_scan "$GATE" "$PP_GREEN_MIS")" "pp=none sum=1 ss=1 und=1" \
    "the green consumer reached by a miscased path is its own toplevel: no pre-push row, not UNSUPPORTED LAYOUT"
  # MUTANT: the decision restored to the string comparison of two `pwd -P` results. The `&`s are
  # escaped because sed reads a bare `&` in a replacement as the whole match.
  PPC_MUT="$(dirname "$DIST")/ppcmut"
  rm -rf "$PPC_MUT"; mkdir -p "$PPC_MUT"
  cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$PPC_MUT"/ 2>/dev/null
  PPC_ANCHOR='^  \[ -n "\$pp_prefix" \] && pp_enclosed=1$'
  ss_assert "pp-case-anchor" "$(grep -c "$PPC_ANCHOR" "$GATE")|$(grep -c '^  \[ -n "\$pp_prefix_NOT_A_VAR" \] && pp_enclosed=1$' "$GATE")" "1|0" \
    "the string-comparison mutation's anchor matches one line, and an impossible anchor of the same shape matches none"
  sed "s@${PPC_ANCHOR}@  [ \"\$(cd \"\$(git -C \"\$CONSUMER\" rev-parse --show-toplevel)\" \&\& pwd -P)\" != \"\$(cd \"\$CONSUMER\" \&\& pwd -P)\" ] \&\& pp_enclosed=1@" \
    "$GATE" > "$PPC_MUT/self-update-gate.sh"
  ASSERTIONS=$((ASSERTIONS + 1))
  if cmp -s "$GATE" "$PPC_MUT/self-update-gate.sh"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s mutation matched nothing, so the case arm is unproven\n' "pp-case-mut"
  else
    ppc_got="$(pp_scan "$PPC_MUT/self-update-gate.sh" "$PP_GREEN_MIS")"
    if [ "$ppc_got" = "pp=SELF-UPDATE-UNDECIDED sum=0 ss=0 und=1" ] && [ "$(pp_layout "$PPC_MUT/self-update-gate.sh" "$PP_GREEN_MIS")" = 1 ]; then
      printf '  ok    %-16s KILLED (%s)\n' "pp-case-mut" \
        "with the pwd -P string comparison restored the miscased healthy consumer reads UNSUPPORTED LAYOUT"
    else
      FAILURES=$((FAILURES + 1))
      printf '  FAIL  %-16s SURVIVED: got=[%s] want=[%s]\n' "pp-case-mut" "$ppc_got" "pp=SELF-UPDATE-UNDECIDED sum=0 ss=0 und=1"
    fi
    # the mutant still answers the canonical spelling OK, so it owns only the miscased case
    ss_assert "pp-case-mut-canonical" "$(pp_scan "$PPC_MUT/self-update-gate.sh" "$PP_GREEN")" "pp=none sum=1 ss=1 und=1" \
      "the string-comparison mutant still reads the canonically spelled green world as its own toplevel, so its kill above is the case and not a broken copy"
  fi
fi
rm -f "$PP/sent/sentinel"
# THE GATE RUNS NO HOOK. The same sentinel hook in a consumer that IS its own repository, with a
# remote and an armed core.hooksPath -- every precondition the removed push arm needed to run it.
# The scan must still carry the differential's rows (so the gate ran to its end) and the sentinel
# must be absent. The control is that hook run by hand: it writes the sentinel, so its absence is
# the gate, not a hook that cannot write.
pp_mk PP_ENC_REAL encreal "$PP_SENT_HOOK" hooksPath yes
ss_assert "pp-gate-runs-no-hook" \
  "$(pp_scan "$GATE" "$PP_ENC_REAL")|$([ -e "$PP/sent/sentinel" ] && echo written || echo absent)" \
  "pp=none sum=1 ss=1 und=1|absent" \
  "a consumer that is its own repository, with a remote and an executable armed hook: the gate runs to its verdict and the hook never runs"
rm -f "$PP/sent/sentinel"
ss_assert "pp-enclosed-control" \
  "$( ( pp_enter "$PP_ENC_REAL" && .githooks/pre-push origin x </dev/null >/dev/null 2>&1 ); [ -e "$PP/sent/sentinel" ] && echo written || echo absent )" \
  "written" "...and the same hook run by hand writes the sentinel, so every absent sentinel in this section is the gate and not the hook"
rm -f "$PP/sent/sentinel"
# MUTANT: a hook call restored to the gate, after the enclosed-layout block, as the removed arm sat.
# The rows must survive (the copy ran to its verdict) AND the sentinel must appear.
PP_MH="$(vr_mut pphook 'index($0, "# Core scripts this pull changes, by basename.") == 1 && !d { print "( cd \"$CONSUMER\" && h=\"$(git rev-parse --git-path hooks/pre-push)\" && [ -x \"$h\" ] && \"$h\" origin x </dev/null >/dev/null 2>&1 ) || :"; d = 1 } { print }')"
PP_MC="$(vr_mut pphookctl '{ print }')"
ss_assert "pp-hook-mut-control" \
  "$(cmp -s "$GATE" "$PP_MC" && echo identical || echo differ)|$(pp_scan "$PP_MC" "$PP_ENC_REAL")|$([ -e "$PP/sent/sentinel" ] && echo written || echo absent)" \
  "identical|pp=none sum=1 ss=1 und=1|absent" \
  "an unmutated copy beside its siblings reaches the verdict and runs no hook, so the kill below is the inserted call"
rm -f "$PP/sent/sentinel"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$GATE" "$PP_MH"; then
  FAILURES=$((FAILURES + 1)); printf '  FAIL  %-16s mutation matched nothing\n' "pp-mut-gatehook"
else
  pp_mh_got="$(pp_scan "$PP_MH" "$PP_ENC_REAL")|$([ -e "$PP/sent/sentinel" ] && echo written || echo absent)"
  if [ "$pp_mh_got" = "pp=none sum=1 ss=1 und=1|written" ]; then
    printf '  ok    %-16s KILLED (a gate that calls the hook again writes the sentinel, and pp-gate-runs-no-hook reads it)\n' "pp-mut-gatehook"
  else
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-16s SURVIVED: got=[%s]\n' "pp-mut-gatehook" "$pp_mh_got"
  fi
fi
rm -f "$PP/sent/sentinel"
# PP-ENC END
# pp_mk ITSELF REFUSES. Driven in a subshell with pp_world replaced: a failing one, and one that
# succeeds while printing nothing -- the two ways a bind goes empty. Each must exit 1 with the
# variable unbound, and a working one must bind it (ALLOW twin).
ss_assert "pp-mk-refuses-failed" "$( ( pp_world() { return 1; }; pp_mk PP_T x ) 2>/dev/null; echo "rc=$?")" "rc=1" \
  "pp_mk aborts the fixture when the world build fails, instead of binding an empty path"
ss_assert "pp-mk-refuses-empty" "$( ( pp_world() { :; }; pp_mk PP_T x ) 2>/dev/null; echo "rc=$?")" "rc=1" \
  "pp_mk aborts when the world build succeeds but prints no path"
ss_assert "pp-mk-binds" "$( ( pp_world() { printf '%s\n' "$PP"; }; pp_mk PP_T x; [ "$PP_T" = "$PP" ] && echo bound ) 2>/dev/null )" "bound" \
  "...and pp_mk binds the path a working build prints"

# 2. THE RECORD IS NOT IN THE TREE WHILE THE GATE RUNS. An earlier cut opened the verdict record
#    under `_bmad-output/` at the start of the run, and a consumer process running mid-gate then saw
#    an untracked path no fixture reads -- for a pre-push hook that defeats its read-set skip
#    (measured: 257s where the settled tree took 30s). The gate no longer runs a hook, but it still
#    runs the consumer's GATING SCRIPTS from the consumer root, and the record is still assembled
#    under `$TMP` and moved in at exit. The observer is the consumer's current copy of a gating
#    script the differential runs: it logs how many record files it can see, from the consumer root.
#    It must see none, have run at least once, and exactly one complete record must be in the tree
#    afterwards.
PP_LSREC="$(vr_cons pplsrec)"
PP_LSREC_LOG="$VR/pplsrec.log"
pp_lsrec_obs() { # pp_lsrec_obs <consumer> <log> -- install the observing gating script
  printf '#!/bin/sh\nn=$(ls _bmad-output/ai-dlc-update/self-update-gate-*.md 2>/dev/null | wc -l | tr -d " ")\necho "$n" >> "%s"\nexit 0\n' "$2" \
    > "$1/scripts/ai-dlc/gate-pass.sh"
  chmod +x "$1/scripts/ai-dlc/gate-pass.sh"
}
pp_lsrec_obs "$PP_LSREC" "$PP_LSREC_LOG"; : > "$PP_LSREC_LOG"
bash "$GATE" "$DIST" "$BASE" "$THEIRS" "$PP_LSREC" >/dev/null 2>&1
ss_assert "pp-record-out-of-tree" \
  "seen=$(sort -u "$PP_LSREC_LOG" | tr '\n' ',')|n=$(vr_n "$PP_LSREC")|$(sed -n 's/^# verdict: *//p' "$(vr_newest "$PP_LSREC")" | head -1)" \
  "seen=0,|n=1|DEFER" \
  "a gating script the gate runs from the consumer root sees no record file while it runs, and exactly one complete record is in the tree afterwards"
# CONTROL: the same script, run by hand from the consumer root with a record-shaped file present,
# logs 1 -- so the 0 above is the record's absence and not a script that cannot see the directory.
: > "$PP_LSREC_LOG.ctl"
pp_lsrec_obs "$PP_LSREC" "$PP_LSREC_LOG.ctl"
( cd "$PP_LSREC" && sh scripts/ai-dlc/gate-pass.sh )
ss_assert "pp-record-control" "$(cat "$PP_LSREC_LOG.ctl")" "1" \
  "...and the same script with a record-shaped file present logs 1, so it really can see that directory"
# MUTANT: the record assembled IN PLACE from the start of the run, as the earlier cut did.
PP_MR="$(vr_mut pprecinplace 'index($0, "    GATE_REC=\"$TMP/record.md\"") == 1 { print "    GATE_REC=\"$_rec_p\""; next } { print }')"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$GATE" "$PP_MR"; then
  FAILURES=$((FAILURES + 1)); printf '  FAIL  %-16s mutation matched nothing\n' "pp-mut-recinplace"
else
  PP_LSREC_M="$(vr_cons pplsrecm)"; pp_lsrec_obs "$PP_LSREC_M" "$PP_LSREC_LOG.m"; : > "$PP_LSREC_LOG.m"
  bash "$PP_MR" "$DIST" "$BASE" "$THEIRS" "$PP_LSREC_M" >/dev/null 2>&1
  pp_mr_got="seen=$(sort -u "$PP_LSREC_LOG.m" | tr '\n' ',')"
  if [ "$pp_mr_got" = "seen=1," ]; then
    printf '  ok    %-16s KILLED (a record assembled in place is visible to every consumer process the gate runs)\n' "pp-mut-recinplace"
  else
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-16s SURVIVED: got=[%s] want=[seen=1,]\n' "pp-mut-recinplace" "$pp_mr_got"
  fi
fi

fi
if sg pu; then
# --- reconcile/self-update-push.sh: THE ONE HOOK RUN, AS THE PUSH ---------------------------
#
# Step 2 pushes through this wrapper. It runs the consumer's pre-push hook EXACTLY ONCE, as git
# would run it, and pushes with `--no-verify` only after that run exited 0. Every world is a work
# tree `W` with `main` pushed to a bare `R1` (a second bare `R2` beside it), on a branch `su` one
# commit ahead. The hook is installed at `.git/hooks/pre-push` -- the hook git resolves -- and
# appends a line to a COUNTER file on every run, then writes its argv and stdin to `run-<n>`. Its
# answer is chosen by marker files: refuse always, refuse when stdin carries a token, fail iff
# `yes | head -1` died of SIGPIPE, or commit before passing.
#
# REAL `git push` IS THE ORACLE wherever the wrapper claims to do what git does: the same world
# is pushed for real with a hook that refuses (so nothing moves), and the two `run-<n>` files are
# byte-compared. Every comparison carries a control that must DIFFER, so a comparison of two
# identical nothings cannot pass.
#
# HERMETIC GIT: the operator's global and system config are kept out, so a `push.followTags`, a
# `core.hooksPath` or a signing key there cannot decide a cell. Unset again at the section's end.
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
PU_SRC="$(dirname "$GATE")/self-update-push.sh"
PU_D="$(dirname "$DIST")/pu"; mkdir -p "$PU_D"
ss_assert "pu-located" "$([ -f "$PU_SRC" ] && echo present || echo absent)" "present" \
  "self-update-push.sh sits beside the gate, in the layout this fixture resolved the gate from"
PU_HOOK_BODY='echo run >> "$D/count"
n=$(grep -c . "$D/count")
f="$D/run-$n"
{ printf "ARGV:%s|%s\n" "$1" "$2"; cat; } > "$f"
if [ -f "$D/sigpipe" ]; then
  yes | head -1 >/dev/null
  [ "${PIPESTATUS[0]}" -eq 141 ] && { echo "hook: SIGPIPE killed yes"; exit 1; }
fi
[ -f "$D/refuse-all" ] && { printf "\n── artifact paths\n   FAIL\n\npre-push: BLOCKED.\n"; exit 1; }
if [ -f "$D/refuse-stdin" ] && grep -qF "$(cat "$D/refuse-stdin")" "$f"; then echo "hook: refuse stdin"; exit 1; fi
[ -f "$D/mutate" ] && git commit -q --allow-empty -m hook-made
exit 0'
# pu_world <name> [nohook] -> world dir. Aborts the fixture on a failed build: an empty path here
# would push from the caller's cwd.
pu_world() {
  local d="$PU_D/$1"
  mkdir "$d" 2>/dev/null \
    && git init -q --bare "$d/R1" && git init -q --bare "$d/R2" && git -c init.defaultBranch=main init -q "$d/W" \
    && ( cd "$d/W" && echo a > a && git add a && git commit -q -m base \
         && git remote add origin "$d/R1" && git push -q --no-verify origin main >/dev/null 2>&1 \
         && git checkout -q -b su && echo b > b && git add b && git commit -q -m su ) \
    && : > "$d/count" \
    || { printf 'FIXTURE ERROR: pu_world %s did not build\n' "$1" >&2; exit 1; }
  if [ "${2:-}" != nohook ]; then
    printf '#!/usr/bin/env bash\nD="%s"\n%s\n' "$d" "$PU_HOOK_BODY" > "$d/W/.git/hooks/pre-push"
    chmod +x "$d/W/.git/hooks/pre-push"
  fi
  printf '%s\n' "$d"
}
# pu_run <wrapper> <world> [prefix-cmd...] -> exit status; stdout/stderr kept in the world. Driven
# from `/`, so the wrapper cannot lean on its caller's cwd. A fresh <out> path each call.
# pu_run is called inside `$( )`, so a counter it bumps is lost; the <out> name it chose is written
# into the world instead, and pu_out reads it back.
pu_run() {
  local w="$1" d="$2" o; shift 2
  o="_bmad-output/ai-dlc-update/self-update-push-$(grep -c . "$d/count" 2>/dev/null)-$$-$RANDOM.md"
  printf '%s\n' "$o" > "$d/outname"
  ( cd / && "$@" bash "$w" "$d/W" origin su "$o" ) > "$d/stdout" 2> "$d/stderr"
  printf '%s' "$?"
}
pu_out() { printf '%s\n' "$1/W/$(cat "$1/outname" 2>/dev/null)"; }
pu_n() { local n; n="$(grep -c . "$1/count" 2>/dev/null)" || n=0; printf '%s' "$n"; }
pu_at() { git --git-dir="$1/$2" rev-parse -q --verify "$3" 2>/dev/null || printf 'absent'; }
pu_landed() { # pu_landed <world> <R> -> landed | absent | other
  local r; r="$(pu_at "$1" "$2" refs/heads/su)"
  if [ "$r" = absent ]; then printf absent
  elif [ "$r" = "$(git -C "$1/W" rev-parse refs/heads/su)" ]; then printf landed
  else printf other; fi
}
pu_real() { ( cd "$1/W" && git push -u origin su ) >/dev/null 2>&1; printf '%s' "$?"; }
pu_kill() { # pu_kill <label> <mutant> <got> <want> <why>
  ASSERTIONS=$((ASSERTIONS + 1))
  if cmp -s "$PU_SRC" "$2"; then
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-16s mutation matched nothing\n' "$1"
  elif [ "$3" = "$4" ]; then
    printf '  ok    %-16s KILLED (%s)\n' "$1" "$5"
  else
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-16s SURVIVED: got=[%s] want=[%s]\n' "$1" "$3" "$4"
  fi
}
pu_mut() { # pu_mut <name> <awk-program> -> a mutated copy of the wrapper
  mkdir -p "$PU_D/m-$1"
  awk "$2" "$PU_SRC" > "$PU_D/m-$1/self-update-push.sh" 2>/dev/null
  printf '%s\n' "$PU_D/m-$1/self-update-push.sh"
}

# pu-absent: no hook at all. git runs none, and neither does the wrapper; the push lands.
PU_W="$(pu_world absent nohook)"
ss_assert "pu-hook-absent" "rc=$(pu_run "$PU_SRC" "$PU_W")|$(pu_landed "$PU_W" R1)|stdout=$(wc -c < "$PU_W/stdout" | tr -d ' ')" \
  "rc=0|landed|stdout=0" "no pre-push hook: exit 0, the branch lands at the local sha, and stdout carries nothing"

# THE SCENARIOS EVERY MUTANT IS SCORED ON. Each builds a fresh world and prints one summary line.
pu_sc_pass() { local d; d="$(pu_world "pass-$2")"
  printf 'rc=%s ref=%s n=%s' "$(pu_run "$1" "$d")" "$(pu_landed "$d" R1)" "$(pu_n "$d")"; }
pu_sc_refuse() { local d; d="$(pu_world "refuse-$2")"; : > "$d/refuse-all"
  printf 'rc=%s ref=%s n=%s' "$(pu_run "$1" "$d")" "$(pu_landed "$d" R1)" "$(pu_n "$d")"; }

PU_PASS="$(pu_sc_pass "$PU_SRC" shipped)"
ss_assert "pu-hook-passes" "$PU_PASS|stdout=$(wc -c < "$PU_D/pass-shipped/stdout" | tr -d ' ')|up=$(git -C "$PU_D/pass-shipped/W" rev-parse --abbrev-ref 'su@{upstream}' 2>/dev/null)" \
  "rc=0 ref=landed n=1|stdout=0|up=origin/su" \
  "a passing hook: the remote ref is created at the local sha, the hook ran EXACTLY once, stdout is empty, and the upstream is origin/su"
PU_REF="$(pu_sc_refuse "$PU_SRC" shipped)"
PU_REF_OUT="$(pu_out "$PU_D/refuse-shipped")"
ss_assert "pu-hook-refuses" \
  "$PU_REF|probe=$(grep -c '^# probe: ' "$PU_REF_OUT" 2>/dev/null)|blocked=$(grep -c '^# probe: pre-push: BLOCKED' "$PU_REF_OUT" 2>/dev/null)|stdout=$(grep -c . "$PU_D/refuse-shipped/stdout")/$(grep -c '^HOOK-REFUSED 1 artifact paths$' "$PU_D/refuse-shipped/stdout")|tracked=$(git -C "$PU_D/refuse-shipped/W" ls-files -- _bmad-output | grep -c .)" \
  "rc=3 ref=absent n=1|probe=6|blocked=1|stdout=1/1|tracked=0" \
  "a refusing hook: exit 3, nothing pushed, the hook ran once, the record holds the header plus the hook's 5 output lines as '# probe:', stdout is the one HOOK-REFUSED line naming the FAIL phase, and the record is untracked"

PU_W="$(pu_world prerecv)"
printf '#!/bin/sh\necho "remote: refused by pre-receive" >&2\nexit 1\n' > "$PU_W/R1/hooks/pre-receive"; chmod +x "$PU_W/R1/hooks/pre-receive"
ss_assert "pu-remote-refuses" "rc=$(pu_run "$PU_SRC" "$PU_W")|$(pu_landed "$PU_W" R1)|n=$(pu_n "$PU_W")|$(cat "$PU_W/stdout")" \
  "rc=4|absent|n=1|TRANSPORT 1" \
  "the hook passes and the remote's pre-receive refuses: exit 4, TRANSPORT on stdout, the hook ran once, nothing landed"

PU_W="$(pu_world notout)"; git -C "$PU_W/W" checkout -q main
ss_assert "pu-not-checked-out" "rc=$(pu_run "$PU_SRC" "$PU_W")|n=$(pu_n "$PU_W")|$(pu_landed "$PU_W" R1)" \
  "rc=2|n=0|absent" "the self-update branch is not checked out: exit 2 before the hook runs, nothing pushed"

# A DIVERGED REMOTE. R1 holds su at a commit that is not an ancestor of the local one.
pu_diverge() { local c
  c="$(git -C "$1/W" commit-tree -p main -m other "$(git -C "$1/W" rev-parse 'main^{tree}')")" \
    && git -C "$1/W" push -q --no-verify origin "$c:refs/heads/su" >/dev/null 2>&1; }
PU_W="$(pu_world divpass)"; pu_diverge "$PU_W"
ss_assert "pu-diverged-pass" "rc=$(pu_run "$PU_SRC" "$PU_W")|n=$(pu_n "$PU_W")|$(pu_landed "$PU_W" R1)" \
  "rc=4|n=1|other" "a remote that diverged, hook passing: the non-fast-forward push fails as TRANSPORT (exit 4) and the remote keeps its commit"
PU_W="$(pu_world divref)"; pu_diverge "$PU_W"; : > "$PU_W/refuse-all"
ss_assert "pu-diverged-refuse" "rc=$(pu_run "$PU_SRC" "$PU_W")|n=$(pu_n "$PU_W")|$(pu_landed "$PU_W" R1)" \
  "rc=3|n=1|other" "a remote that diverged, hook refusing: HOOK-REFUSED (exit 3) and nothing pushed"

# THE HOOK'S ARGV AND STDIN ARE THE REAL PUSH'S, with `remote.origin.pushurl` set to R2 while the
# fetch url stays R1. The hook refuses, so the real push moves nothing and the wrapper then sees the
# same world. CONTROL: the real push with the pushurl removed feeds a DIFFERENT argv, so the
# comparison can tell two pushes apart.
PU_BE="$(pu_world byteeq)"; : > "$PU_BE/refuse-all"
git -C "$PU_BE/W" config remote.origin.pushurl "$PU_BE/R2"
pu_real "$PU_BE" >/dev/null
PU_BE_REAL="$PU_BE/run-$(pu_n "$PU_BE")"
pu_be_rc="$(pu_run "$PU_SRC" "$PU_BE")"
PU_BE_WRAP="$PU_BE/run-$(pu_n "$PU_BE")"
ss_assert "pu-argv-stdin-as-git" \
  "rc=$pu_be_rc|n=$(pu_n "$PU_BE")|$(cmp -s "$PU_BE_REAL" "$PU_BE_WRAP" && echo byte-equal || echo differ)|$(grep -c "^ARGV:origin|$PU_BE/R2\$" "$PU_BE_WRAP")|$(grep -vc '^ARGV:' "$PU_BE_WRAP")" \
  "rc=3|n=2|byte-equal|1|1" \
  "the wrapper's hook argv (remote name, PUSH url) and its one stdin ref line are byte-equal to a real git push's to the same bare remote"
# MUTANTS scored on this world (the refusing hook keeps it unchanged between runs).
pu_be_mut() { # pu_be_mut <mutant> -> byte-equal | differ
  local f; pu_run "$1" "$PU_BE" >/dev/null; f="$PU_BE/run-$(pu_n "$PU_BE")"
  cmp -s "$PU_BE_REAL" "$f" && printf byte-equal || printf differ
}
PU_M="$(pu_mut probe 'BEGIN { a = "refs/heads/%s %s refs/heads/%s %s" } index($0, a) { i = index($0, a); $0 = substr($0, 1, i - 1) "refs/heads/%s %s refs/heads/ai-dlc-update/self-update-%s-probe %s" substr($0, i + length(a)) } { print }')"
pu_kill "pu-mut-probename" "$PU_M" "$(pu_be_mut "$PU_M")" "differ" \
  "a ref line built from the gate's old -probe stand-in name is not the line git sends"
PU_M="$(pu_mut fetchargv 'index($0, "remote get-url --push --all") { sub(/remote get-url --push --all/, "remote get-url --all") } { print }')"
pu_kill "pu-mut-fetchargv" "$PU_M" "$(pu_be_mut "$PU_M")" "differ" \
  "the fetch url in \$2 is not the url git passes when remote.origin.pushurl is set"
git -C "$PU_BE/W" config --unset remote.origin.pushurl
pu_real "$PU_BE" >/dev/null
ss_assert "pu-argv-control" "$(cmp -s "$PU_BE_REAL" "$PU_BE/run-$(pu_n "$PU_BE")" && echo byte-equal || echo differ)" "differ" \
  "control: a real push with the pushurl removed feeds a different argv, so byte-equality above is a comparison that can fail"

# PUSH URL, NOT FETCH URL, FOR THE REMOTE SIDE OF THE REF LINE. (1) The fetch remote R1 already
# holds the local sha while the push url R2 lacks it: git feeds the hook a ref line with a zero
# remote sha. Real push first, refusing, then the wrapper.
pu_sc_pushurl() { local d; d="$(pu_world "pushurl-$2")"
  git -C "$d/W" push -q --no-verify origin su >/dev/null 2>&1
  git -C "$d/W" config remote.origin.pushurl "$d/R2"; : > "$d/refuse-all"
  pu_real "$d" >/dev/null; local real="$d/run-$(pu_n "$d")" rc
  rc="$(pu_run "$1" "$d")"
  printf 'rc=%s R2=%s n=%s %s' "$rc" "$(pu_landed "$d" R2)" "$(( $(pu_n "$d") - 1 ))" \
    "$(cmp -s "$real" "$d/run-$(pu_n "$d")" && echo byte-equal || echo differ)"
}
ss_assert "pu-pushurl-side" "$(pu_sc_pushurl "$PU_SRC" shipped)|$(grep -c ' 0000000000000000000000000000000000000000$' "$PU_D/pushurl-shipped/run-2")" \
  "rc=3 R2=absent n=1 byte-equal|1" \
  "fetch url already at the local sha, push url lacking it, hook refusing: exit 3, nothing on the push url, the hook ran once, fed the zero-sha line a real push feeds"
# (2) The remote is already at the local sha: git still runs the hook, on EMPTY stdin.
pu_sc_current() { local d; d="$(pu_world "current-$2")"
  git -C "$d/W" push -q --no-verify origin su >/dev/null 2>&1; : > "$d/refuse-all"
  pu_real "$d" >/dev/null; local before; before="$(pu_n "$d")"; local real="$d/run-$before" rc
  rc="$(pu_run "$1" "$d")"
  if [ "$(pu_n "$d")" -gt "$before" ]; then
    printf 'rc=%s real=%s n=%s stdin=%s %s' "$rc" "$before" "$(( $(pu_n "$d") - before ))" \
      "$(grep -vc '^ARGV:' "$d/run-$(pu_n "$d")")" \
      "$(cmp -s "$real" "$d/run-$(pu_n "$d")" && echo byte-equal || echo differ)"
  else
    printf 'rc=%s real=%s n=0 stdin=none norun' "$rc" "$before"
  fi
}
ss_assert "pu-remote-current" "$(pu_sc_current "$PU_SRC" shipped)" \
  "rc=3 real=1 n=1 stdin=0 byte-equal" \
  "the remote already at the local sha: a real push runs the hook on empty stdin (real=1), and so does the wrapper -- exit 3 on a refusing hook, once, byte-equal"
# (3) The fetch url does not exist, the push url does: the push is decided on the push url alone.
pu_sc_nofetch() { local d; d="$(pu_world "nofetch-$2")"
  git -C "$d/W" config remote.origin.pushurl "$d/R2"
  git -C "$d/W" config remote.origin.url "$d/nonexistent.git"
  printf 'rc=%s R2=%s n=%s' "$(pu_run "$1" "$d")" "$(pu_landed "$d" R2)" "$(pu_n "$d")"
}
ss_assert "pu-fetch-url-missing" "$(pu_sc_nofetch "$PU_SRC" shipped)" "rc=0 R2=landed n=1" \
  "a fetch url that does not exist and a valid push url: exit 0, the branch lands on the push url, the hook ran once"
PU_M="$(pu_mut lsfetch 'index($0, "ls-remote \"$URL\"") { sub(/ls-remote "\$URL"/, "ls-remote \"$REMOTE\"") } { print }')"
pu_kill "pu-mut-lsfetch" "$PU_M" "$(pu_sc_pushurl "$PU_M" lsfetch)" "rc=3 R2=absent n=1 differ" \
  "ls-remote against the fetch url reads R1's sha, feeds the hook an empty stdin, and differs from the real push"
ss_assert "pu-mut-lsfetch-b" "$(pu_sc_nofetch "$PU_M" lsfetch)" "rc=4 R2=absent n=0" \
  "...and the same mutant cannot read a missing fetch url, so it reports TRANSPORT where the real push lands"
PU_M="$(pu_mut shortcut 'index($0, "if [ \"$REMOTE_SHA\" = \"$LOCAL_SHA\" ]; then") == 1 { print; print "  pinned_push"; next } { print }')"
pu_kill "pu-mut-shortcut" "$PU_M" "$(pu_sc_current "$PU_M" shortcut)" "rc=0 real=1 n=0 stdin=none norun" \
  "the up-to-date shortcut skips the hook git would run, and pushes past a refusal"

# SIGPIPE. `git push` runs hooks with SIGPIPE ignored, so a hook's `yes | head -1` sees EPIPE and
# not a 141. The wrapper ignores it the same way. Each drive RESETS the disposition to default
# first with perl, because this fixture may itself run under a `git push` hook with SIGPIPE
# already ignored, which would hide a wrapper that forgot to ignore it.
if ! command -v perl >/dev/null 2>&1; then
  printf '  SKIP  %-16s perl is not on PATH, so SIGPIPE cannot be reset to default and the arm cannot discriminate\n' "pu-sigpipe"
else
  pu_dfl() { perl -e '$SIG{PIPE} = "DEFAULT"; exec @ARGV or exit 127' "$@"; }
  pu_sc_sigpipe() { local d; d="$(pu_world "sigpipe-$2")"; : > "$d/sigpipe"
    printf 'rc=%s ref=%s n=%s' "$(pu_run "$1" "$d" pu_dfl)" "$(pu_landed "$d" R1)" "$(pu_n "$d")"; }
  ss_assert "pu-sigpipe" "$(pu_sc_sigpipe "$PU_SRC" shipped)" "rc=0 ref=landed n=1" \
    "a hook that fails iff yes|head -1 died of SIGPIPE passes under the wrapper, driven with SIGPIPE at its default"
  PU_SP="$PU_D/sigpipe-shipped"
  ss_assert "pu-sigpipe-control" \
    "$( ( cd "$PU_SP/W" && pu_dfl .git/hooks/pre-push origin x </dev/null >/dev/null 2>&1 ); echo $? )|$( ( cd "$PU_SP/W" && perl -e '$SIG{PIPE} = "IGNORE"; exec @ARGV or exit 127' .git/hooks/pre-push origin x </dev/null >/dev/null 2>&1 ); echo $? )" \
    "1|0" "control: the same hook run by hand fails with SIGPIPE at default and passes with it ignored, so the cell above is the wrapper's trap"
  PU_M="$(pu_mut notrap 'BEGIN { a = "trap \047\047 PIPE; " } index($0, a) { i = index($0, a); $0 = substr($0, 1, i - 1) substr($0, i + length(a)) } { print }')"
  pu_kill "pu-mut-notrap" "$PU_M" "$(pu_sc_sigpipe "$PU_M" notrap)" "rc=3 ref=absent n=1" \
    "without the trap the hook sees a 141 and refuses a push git would make"
fi

# MUTANTS ON THE ONE-RUN CONTRACT. An unmutated copy in a directory of its own passes first, so a
# copy that cannot run does not score as a kill.
PU_M="$(pu_mut control '{ print }')"
ss_assert "pu-mut-control" "$(cmp -s "$PU_SRC" "$PU_M" && echo identical || echo differ)|$(pu_sc_pass "$PU_M" control)" \
  "identical|rc=0 ref=landed n=1" "an unmutated copy of the wrapper, alone in its own directory, pushes and runs the hook once"
PU_M="$(pu_mut noverify 'index($0, "push --no-verify --no-follow-tags") { sub(/push --no-verify --no-follow-tags/, "push --no-follow-tags") } { print }')"
pu_kill "pu-mut-noverify" "$PU_M" "$(pu_sc_pass "$PU_M" noverify)" "rc=0 ref=landed n=2" \
  "a push without --no-verify after the hook ran runs the hook a second time"
PU_M="$(pu_mut pushonrefuse '$0 == "  exit 3" { print "  pinned_push"; next } { print }')"
pu_kill "pu-mut-pushonrefuse" "$PU_M" "$(pu_sc_refuse "$PU_M" pushonrefuse)" "rc=0 ref=landed n=1" \
  "a wrapper that pushes on a refusal lands a branch the consumer's own gate refused"
PU_M="$(pu_mut refuse4 '$0 == "  exit 3" { print "  exit 4"; next } { print }')"
pu_kill "pu-mut-refuse4" "$PU_M" "$(pu_sc_refuse "$PU_M" refuse4)" "rc=4 ref=absent n=1" \
  "a refusal mapped to exit 4 reads as TRANSPORT and gets the UN-SYNCED disposition"

# X1. A CONFIGURED REFSPEC MAPS su ONTO main. A real push feeds the hook refs/heads/main (control)
#     and the hook refuses it; the wrapper pushes only the one ref its hook judged, so main does
#     not move.
pu_sc_x1() { local d m; d="$(pu_world "x1-$2")"
  git -C "$d/W" config remote.origin.push 'refs/heads/su:refs/heads/main'; printf 'refs/heads/main' > "$d/refuse-stdin"
  m="$(pu_at "$d" R1 refs/heads/main)"
  printf 'rc=%s main=%s su=%s n=%s up=%s' "$(pu_run "$1" "$d")" \
    "$([ "$(pu_at "$d" R1 refs/heads/main)" = "$m" ] && echo kept || echo moved)" "$(pu_landed "$d" R1)" "$(pu_n "$d")" \
    "$(git -C "$d/W" rev-parse --abbrev-ref 'su@{upstream}' 2>/dev/null || echo none)"
}
ss_assert "pu-x1-refspec" "$(pu_sc_x1 "$PU_SRC" shipped)" "rc=0 main=kept su=landed n=1 up=origin/su" \
  "remote.origin.push maps su onto main: the wrapper pushes refs/heads/su only, main is not moved, the upstream is origin/su"
PU_X="$(pu_world x1real)"; git -C "$PU_X/W" config remote.origin.push 'refs/heads/su:refs/heads/main'; printf 'refs/heads/main' > "$PU_X/refuse-stdin"
pu_x1_m="$(pu_at "$PU_X" R1 refs/heads/main)"; pu_x1_rc="$(pu_real "$PU_X")"
ss_assert "pu-x1-control" "rc=$pu_x1_rc|$(grep -c ' refs/heads/main ' "$PU_X/run-1")|$([ "$(pu_at "$PU_X" R1 refs/heads/main)" = "$pu_x1_m" ] && echo kept || echo moved)" \
  "rc=1|1|kept" "control: a real git push in the same world feeds the hook refs/heads/main, so the mapping is live and the hook can refuse it"
PU_M="$(pu_mut unpinned 'index($0, "\"$LOCAL_SHA:refs/heads/$BRANCH\"") { sub(/"\$LOCAL_SHA:refs\/heads\/\$BRANCH"/, "\"$BRANCH\"") } { print }')"
pu_kill "pu-mut-unpinned" "$PU_M" "$(pu_sc_x1 "$PU_M" unpinned | awk '{print $1, $2}')" "rc=0 main=moved" \
  "a push of the bare branch name follows the configured refspec and moves main, which the hook never judged"

# X2. push.followTags WITH AN ANNOTATED TAG. A real push feeds the hook the tag (control); the
#     wrapper pushes no tag.
pu_sc_x2() { local d; d="$(pu_world "x2-$2")"
  git -C "$d/W" tag -a -m t v1 && git -C "$d/W" config push.followTags true; printf 'refs/tags/' > "$d/refuse-stdin"
  printf 'rc=%s tag=%s su=%s n=%s' "$(pu_run "$1" "$d")" "$([ "$(pu_at "$d" R1 refs/tags/v1)" = absent ] && echo absent || echo present)" \
    "$(pu_landed "$d" R1)" "$(pu_n "$d")"
}
ss_assert "pu-x2-followtags" "$(pu_sc_x2 "$PU_SRC" shipped)" "rc=0 tag=absent su=landed n=1" \
  "push.followTags and an annotated tag on the pushed commit: the branch lands and the tag does not"
PU_X="$(pu_world x2real)"; git -C "$PU_X/W" tag -a -m t v1; git -C "$PU_X/W" config push.followTags true; printf 'refs/tags/' > "$PU_X/refuse-stdin"
pu_x2_rc="$(pu_real "$PU_X")"
ss_assert "pu-x2-control" "rc=$pu_x2_rc|$(grep -c '^refs/tags/v1 ' "$PU_X/run-1")" "rc=1|1" \
  "control: a real git push in the same world feeds the hook refs/tags/v1, so the tag would have been pushed"
PU_M="$(pu_mut followtags 'index($0, "push --no-verify --no-follow-tags") { sub(/ --no-follow-tags/, "") } { print }')"
pu_kill "pu-mut-followtags" "$PU_M" "$(pu_sc_x2 "$PU_M" followtags)" "rc=0 tag=present su=landed n=1" \
  "without --no-follow-tags the configured followTags pushes a tag the hook never judged"

# X3. TWO PUSH URLS. git runs the hook once per url; the wrapper refuses before running it.
pu_sc_x3() { local d; d="$(pu_world "x3-$2")"
  git -C "$d/W" remote set-url --add --push origin "$d/R1"; git -C "$d/W" remote set-url --add --push origin "$d/R2"
  printf 'rc=%s n=%s R1=%s R2=%s' "$(pu_run "$1" "$d")" "$(pu_n "$d")" "$(pu_landed "$d" R1)" "$(pu_landed "$d" R2)"
}
ss_assert "pu-x3-multiurl" "$(pu_sc_x3 "$PU_SRC" shipped)" "rc=2 n=0 R1=absent R2=absent" \
  "a remote with two push urls: exit 2, the hook never ran, nothing pushed to either url"
pu_real "$PU_D/x3-shipped" >/dev/null
ss_assert "pu-x3-control" "$(pu_n "$PU_D/x3-shipped")" "2" \
  "control: a real git push in the same world runs the hook twice, once per push url"
PU_M="$(pu_mut multiurl 'index($0, "[ \"$su_n\" -eq 1 ] \\") == 1 { print "true || " $0; next } { print }')"
pu_kill "pu-mut-multiurl" "$PU_M" "$(pu_sc_x3 "$PU_M" multiurl)|$(cat "$PU_D/x3-multiurl/stdout")" "rc=4 n=0 R1=absent R2=absent|TRANSPORT 128" \
  "without the refusal the two urls reach ls-remote as one newline-joined url, which is misreported as TRANSPORT instead of refused as a usage error"

# X4. A HOOK THAT MOVES THE BRANCH. It judged one sha and committed another; nothing is pushed.
pu_sc_x4() { local d; d="$(pu_world "x4-$2")"; : > "$d/mutate"
  printf 'rc=%s n=%s su=%s' "$(pu_run "$1" "$d")" "$(pu_n "$d")" "$(pu_at "$d" R1 refs/heads/su | sed 's/^[0-9a-f]\{40\}$/present/')"
}
ss_assert "pu-x4-moved" "$(pu_sc_x4 "$PU_SRC" shipped)" "rc=2 n=1 su=absent" \
  "a hook that commits on the branch and passes: exit 2, the hook ran once, nothing pushed"
PU_M="$(pu_mut moved 'index($0, "[ \"$su_after\" = \"$LOCAL_SHA\" ] \\") == 1 { print "true || " $0; next } { print }')"
pu_kill "pu-mut-moved" "$PU_M" "$(pu_sc_x4 "$PU_M" moved)" "rc=0 n=1 su=present" \
  "without the check the wrapper pushes after a hook that moved the branch"

# A1. THE HOOK-REFUSED DISCARD SEQUENCE, END TO END, as SKILL.md step 2 spells it. The
#     self-update branch commits the slice, the gate record and the fixture log; the wrapper
#     refuses; then: checkout the original branch, `git show` both records back, the name-only
#     check against the written set, `branch -D`. Afterwards HEAD is the original branch, the
#     self-update branch is gone, and all three records are on disk and uncommitted.
PU_A="$(pu_world a1)"; : > "$PU_A/refuse-all"
PU_A_GATE=_bmad-output/ai-dlc-update/self-update-gate-20990101T000000Z.md
PU_A_LOG=_bmad-output/ai-dlc-update/self-update-fixtures-20990101T000000Z.md
PU_A_SLICE=scripts/ai-dlc/slice.sh
mkdir -p "$PU_A/W/_bmad-output/ai-dlc-update" "$PU_A/W/scripts/ai-dlc"
printf '# gate record\n# verdict: OK\n' > "$PU_A/W/$PU_A_GATE"
printf '# fixture log\n' > "$PU_A/W/$PU_A_LOG"
printf '#!/bin/sh\nexit 0\n' > "$PU_A/W/$PU_A_SLICE"
# The ORIGINAL branch is the commit the self-update branch was cut from, as in step 2.
git -C "$PU_A/W" branch -q orig
git -C "$PU_A/W" add -- "$PU_A_GATE" "$PU_A_LOG" "$PU_A_SLICE" && git -C "$PU_A/W" commit -q -m self-update
pu_a_gate_blob="$(git -C "$PU_A/W" rev-parse "su:$PU_A_GATE")"; pu_a_log_blob="$(git -C "$PU_A/W" rev-parse "su:$PU_A_LOG")"
# A record the branch does NOT hold: a fixture log written after the commit, as step 2's sentence
# order allows. The restore must leave it byte-identical; a bare `git show ... > <path>` truncates it
# before git fails, which is the defect this world exists for.
PU_A_UNC=_bmad-output/ai-dlc-update/self-update-fixtures-20990101T000001Z.md
printf '# fixture log, written after the commit\n' > "$PU_A/W/$PU_A_UNC"
pu_a_unc_blob="$(git -C "$PU_A/W" hash-object "$PU_A_UNC")"
pu_a_rc="$(pu_run "$PU_SRC" "$PU_A")"
PU_A_PUSHREC="$(cat "$PU_A/outname")"
# THE RESTORE, AS SKILL.md SPELLS IT: through a temporary file, moved into place only on success.
pu_a_restore() { git -C "$PU_A/W" show "su:$1" > "$PU_A/W/$1.restore" 2>/dev/null && mv "$PU_A/W/$1.restore" "$PU_A/W/$1"; rm -f "$PU_A/W/$1.restore"; return 0; }
git -C "$PU_A/W" checkout -q orig \
  && pu_a_restore "$PU_A_GATE" && pu_a_restore "$PU_A_LOG" && pu_a_restore "$PU_A_UNC"
pu_a_names="$(git -C "$PU_A/W" diff --name-only orig su | grep -c .)" || pu_a_names=0
pu_a_extra="$(git -C "$PU_A/W" diff --name-only orig su | grep -vxF -e "$PU_A_GATE" -e "$PU_A_LOG" -e "$PU_A_SLICE" | grep -c .)" || pu_a_extra=0
[ "$pu_a_extra" -eq 0 ] && git -C "$PU_A/W" branch -q -D su
pu_a_file() { # pu_a_file <path> -> untracked | tracked | missing
  if [ ! -f "$PU_A/W/$1" ]; then printf missing
  elif git -C "$PU_A/W" ls-files --error-unmatch -- "$1" >/dev/null 2>&1; then printf tracked
  else printf untracked; fi
}
ss_assert "pu-a1-discard" \
  "rc=$pu_a_rc|names=$pu_a_names|extra=$pu_a_extra|head=$(git -C "$PU_A/W" symbolic-ref -q HEAD)|su=$(git -C "$PU_A/W" rev-parse -q --verify refs/heads/su >/dev/null && echo present || echo gone)|R1=$(pu_landed "$PU_A" R1)|gate=$(pu_a_file "$PU_A_GATE"),$([ "$(git -C "$PU_A/W" hash-object "$PU_A_GATE")" = "$pu_a_gate_blob" ] && echo same || echo changed)|log=$(pu_a_file "$PU_A_LOG"),$([ "$(git -C "$PU_A/W" hash-object "$PU_A_LOG")" = "$pu_a_log_blob" ] && echo same || echo changed)|push=$(pu_a_file "$PU_A_PUSHREC"),$(grep -c '^# probe: ' "$PU_A/W/$PU_A_PUSHREC" 2>/dev/null)|slice=$(pu_a_file "$PU_A_SLICE")|unc=$(pu_a_file "$PU_A_UNC"),$([ "$(git -C "$PU_A/W" hash-object "$PU_A_UNC")" = "$pu_a_unc_blob" ] && echo same || echo changed)|tmp=$(find "$PU_A/W/_bmad-output" -name '*.restore' | grep -c .)" \
  "rc=3|names=3|extra=0|head=refs/heads/orig|su=gone|R1=absent|gate=untracked,same|log=untracked,same|push=untracked,6|slice=missing|unc=untracked,same|tmp=0" \
  "after HOOK-REFUSED and the step-2 discard: HEAD is the original branch, the self-update branch is gone, nothing was pushed, the gate record and fixture log are restored byte-for-byte and the push record carries its '# probe:' lines -- all three uncommitted -- the slice left with the branch, and a record the branch never held is left byte-for-byte with no temporary file behind"
# CONTROL, ONE PROPERTY APART: the bare redirect the restore replaced empties that same record.
printf '# fixture log, written after the commit\n' > "$PU_A/W/$PU_A_UNC.ctl"
git -C "$PU_A/W" show "orig:$PU_A_UNC.ctl" > "$PU_A/W/$PU_A_UNC.ctl" 2>/dev/null
ss_assert "pu-a1-restore-control" "bytes=$(wc -c < "$PU_A/W/$PU_A_UNC.ctl" | tr -d ' ')" "bytes=0" \
  "control: a bare redirect of git show straight onto a record the branch does not hold truncates it -- the hazard the temporary-file restore exists for is live here"

# --- THE READ-SET SKIP DECIDES THE SAME WHOEVER STARTS THE HOOK ------------------------------
# `git push` prepends git's exec-path to its hook's PATH and sets GIT_EXEC_PATH; this wrapper
# `exec`s the hook with neither. The pre-push hook's tool keys used to resolve on that PATH, so the
# same tree decided differently under the two, and each push reset the other's key records. The
# world's hook sources the RESOLVED hook's FIXTURE_POOL block and records `apply_readset_skip`'s
# decision; it runs once through the wrapper, under a plain PATH with no GIT_EXEC_PATH, and once
# through a real `git push`. The two `.kdec` and `.ftools` must be byte-equal, with the fixture
# skipped and its `git` row present. CONTROL, one property apart: the same drive with the block's
# tool dirs replaced by the inherited PATH must DIFFER, so the equality is one that can fail. The
# hook exits 0 so the wrapper writes no record into the tree it is judging.
# The hook is located the way the two later arms locate it (both layouts from this file's own
# directory), never through the enclosing repository: `git rev-parse --show-toplevel` answers
# about whatever repository ENCLOSES the fixture, which in a sandbox is none, or a stranger's.
PU_TK_HOOK=""
for _c in "$DIR/../../git-hooks/pre-push" "$DIR/../../../.githooks/pre-push"; do
  [ -f "$_c" ] && { PU_TK_HOOK="$(cd "$(dirname "$_c")" && pwd -P)/pre-push"; break; }
done
[ -n "$PU_TK_HOOK" ] && echo "HERMETIC-CONSUMED $PU_TK_HOOK"
if [ -z "$PU_TK_HOOK" ] || ! grep -q '^readset_tools() ' "$PU_TK_HOOK"; then
  printf '  SKIP  pu-readset-*   no pre-push hook with readset_tools in either layout yet\n'
else
  PU_TK_P="$PU_D/tk.pool.sh"
  sed -n '/# FIXTURE_POOL_BEGIN/,/# FIXTURE_POOL_END/p' "$PU_TK_HOOK" > "$PU_TK_P"
  PU_TK_X="$(sed -n 's|^FXROOT="\([A-Za-z0-9_./-]*\)/"$|\1|p' "$PU_TK_P" | sort -u)"
  PU_TK_PLAIN="/usr/bin:/bin:/usr/sbin:/sbin"
  # pu_tk_world <name> <pool>: a pu world whose su commit adds fixture fa reading src/t.sh, a script
  # that names git; its key record is written once by the pool under the plain PATH.
  pu_tk_world() {
    local d; d="$(pu_world "$1")"
    mkdir -p "$d/W/$PU_TK_X/fa" "$d/W/src" \
      && printf 'exit 0\n' > "$d/W/$PU_TK_X/fa/run.sh" && printf 'git status\n' > "$d/W/src/t.sh" \
      && printf 'fa\tsrc/t.sh\n' > "$d/W/.ai-dlc-fixture-readsets.tsv" \
      && git -C "$d/W" add -A && git -C "$d/W" commit -q -m fixtures \
      || { printf 'FIXTURE ERROR: pu_tk_world %s did not build\n' "$1" >&2; exit 1; }
    ( cd "$d/W" && env -u GIT_EXEC_PATH PATH="$PU_TK_PLAIN" AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_JOBS=1 \
        bash -c '. "$1" 2>/dev/null; run_fixtures' _ "$2" ) >/dev/null 2>&1
    { printf '#!/usr/bin/env bash\nD="%s"; P="%s"\n' "$d" "$2"
      printf '%s\n' 'o="$D/tk.$(cat "$D/tag")"; mkdir -p "$o" || exit 1' 'printf "%s\n" "${PATH%%:*}" > "$o/path1"' \
        'cd "$(git rev-parse --show-toplevel)" || exit 1' '. "$P" 2>/dev/null' \
        'for f in "$FXROOT"*/; do [ -f "$f/run.sh" ] && printf "%s\n" "$f"; done > "$o/list"' \
        'apply_readset_skip "$o/list" "$o" > "$o/ann" 2>&1' 'exit 0'; } > "$d/W/.git/hooks/pre-push"
    chmod +x "$d/W/.git/hooks/pre-push"
    printf '%s\n' "$d"
  }
  # pu_tk_drive <world>: the wrapper, then a real push; prints both runs' summary.
  pu_tk_drive() {
    local d="$1" w r
    printf 'wrap\n' > "$d/tag"; w="$(pu_run "$PU_SRC" "$d" env -u GIT_EXEC_PATH PATH="$PU_TK_PLAIN")"
    printf 'real\n' > "$d/tag"; r="$(pu_real "$d")"
    printf 'rc=%s/%s first=%s kdec=%s ftools=%s fa=%s git=%s' "$w" "$r" \
      "$([ "$(cat "$d/tk.wrap/path1" 2>/dev/null)" != "$(cat "$d/tk.real/path1" 2>/dev/null)" ] && echo differ || echo same)" \
      "$(cmp -s "$d/tk.wrap/.kdec" "$d/tk.real/.kdec" && echo equal || echo differ)" \
      "$(cmp -s "$d/tk.wrap/.ftools" "$d/tk.real/.ftools" && echo equal || echo differ)" \
      "$(awk -F'\t' '$1 == "fa" { print $2 }' "$d/tk.real/.kdec" 2>/dev/null)" \
      "$(cut -f2 "$d/tk.real/.ftools" 2>/dev/null | grep -c '/git$')"
  }
  PU_TK_W="$(pu_tk_world tkfix "$PU_TK_P")"
  ss_assert "pu-readset-same" "$(pu_tk_drive "$PU_TK_W")" "rc=0/0 first=differ kdec=equal ftools=equal fa=skip git=1" \
    "the hook run through the wrapper (plain PATH) and through git push (exec-path first) decides the same skip set from the same tool keys, and the fixture whose script names git skips"
  PU_TK_M="$PU_D/tk.inherited.sh"
  awk 'BEGIN { a = "for p in $xp:$READSET_TOOL_DIRS; do" }
       { i = index($0, a); if (i) { $0 = substr($0, 1, i - 1) "for p in $PATH; do" substr($0, i + length(a)); n++ } print }
       END { if (n != 1) exit 3 }' "$PU_TK_P" > "$PU_TK_M"
  pu_tk_mrc=$?
  PU_TK_C=""
  [ "$pu_tk_mrc" = 0 ] && ! cmp -s "$PU_TK_P" "$PU_TK_M" && PU_TK_C="$(pu_tk_drive "$(pu_tk_world tkinh "$PU_TK_M")")"
  ss_assert "pu-readset-ctl" "${PU_TK_C:-DID-NOT-APPLY}" "rc=0/0 first=differ kdec=differ ftools=differ fa=run git=1" \
    "control: with the tool dirs replaced by the inherited PATH the two invocations key git differently and the git push reruns the fixture -- the equality above can fail"
fi
unset GIT_CONFIG_NOSYSTEM GIT_CONFIG_GLOBAL GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL

fi
if sg stg; then
# --- A STAGING WRITE THAT FAILS IS UNDECIDED (BL-360) -------------------------------------
# Every loop in the gate reads a file `gate_stage` wrote into `$TMP`. The heredocs these replaced
# ran their loop ZERO times when bash 3.2 could not write the body's temp file, and at the
# differential loop zero iterations is `deferred=0` — no DEFER row, the OK this gate exists to
# withhold. FORCED, NEVER SAMPLED: a `mktemp` stub on PATH creates the gate's own `$TMP` and puts
# a DIRECTORY where `$TMP/gating` will be written, so exactly that one staging write fails
# (EISDIR) while the record and every other stage land. It claims only the gate's
# `self-update-gate-XXXXXX` call and logs each claim; the cell asserts it fired.
SG="$(mktemp -d "${TMPDIR:-/tmp}/su-gate-stage.XXXXXX")"
SG_REAL_MKTEMP="$(command -v mktemp)"
printf '#!/bin/sh\ncase "$*" in\n  *self-update-gate-XXXXXX*) d="$(%s "$@")" || exit $?; mkdir "$d/gating"; echo fired >> %s/fired; printf "%%s\\n" "$d" ;;\n  *) exec %s "$@" ;;\nesac\n' \
  "$SG_REAL_MKTEMP" "$SG" "$SG_REAL_MKTEMP" > "$SG/mktemp"
chmod +x "$SG/mktemp"
# sg_scan <gate> <stubbed:yes|no> -> "und=<n> defer=<n> fired=<n>" on the base seed
#   und   UNDECIDED rows naming the gating-script set's staging
#   defer gate-defer.sh's own DEFER row, which only the differential loop can emit
sg_scan() {
  local o
  rm -f "$SG/fired"
  if [ "$2" = yes ]; then o="$(PATH="$SG:$PATH" bash "$1" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null)"
  else o="$(bash "$1" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null)"; fi
  printf 'und=%s defer=%s fired=%s\n' \
    "$(printf '%s\n' "$o" | awk -F'\t' '$1 == "SELF-UPDATE-UNDECIDED" && $3 ~ /^the gating-script set could not be staged/' | grep -c .)" \
    "$(printf '%s\n' "$o" | awk -F'\t' '$1 == "SELF-UPDATE-DEFER" && $2 == "gate-defer.sh"' | grep -c .)" \
    "$(grep -c . "$SG/fired" 2>/dev/null || echo 0)"
}
ss_assert "stage-gating-refused" "$(sg_scan "$GATE" yes)" "und=1 defer=0 fired=1" \
  "a gating-script set that cannot be staged is UNDECIDED, and the stub that broke it is shown to fire"
ss_assert "stage-gating-healthy" "$(sg_scan "$GATE" no)" "und=0 defer=1 fired=0" \
  "the same seed unstubbed reaches the differential and defers on gate-defer.sh, so the refusal is the staging write"
rm -rf "$SG/m"; mkdir -p "$SG/m"
cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$SG/m"/ 2>/dev/null
ss_assert "stage-mut-control" "$(sg_scan "$SG/m/self-update-gate.sh" yes)" "und=1 defer=0 fired=1" \
  "an unmutated copy beside its siblings refuses the same way, so the kill below is the mutation"
awk 'index($0,"  [ \"$_rc\" = 0 ] && return 0") == 1 { print "  return 0"; next } { print }' \
  "$GATE" > "$SG/m/self-update-gate.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$GATE" "$SG/m/self-update-gate.sh"; then
  FAILURES=$((FAILURES + 1)); printf '  FAIL  %-16s mutation matched nothing\n' "stage-mut-status"
else
  sg_m="$(sg_scan "$SG/m/self-update-gate.sh" yes)"
  if [ "$sg_m" = "und=0 defer=0 fired=1" ]; then
    printf '  ok    %-16s KILLED (with the staging status unread the loop reads nothing, and gate-defer.sh'\''s DEFER silently vanishes: %s)\n' "stage-mut-status" "$sg_m"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-16s SURVIVED: got [%s], want [und=0 defer=0 fired=1]\n' "stage-mut-status" "$sg_m"
  fi
fi
rm -rf "$SG"

fi
if sg qw; then
# --- A NON-ASCII PATH IS LISTED RAW AND READ BY ITS RAW NAME (BL-364) ---------------------------
# Under git's default `core.quotePath` a name carrying a byte above 0x7f is listed C-quoted —
# `"core/scripts/caf\303\251.sh"` — and every reader below compares that line against a raw name.
# Three listing sites and one hook-text derivation decide what this gate sees, and each loses the
# accented path in a different direction:
#   INVOKED  (the hook's script list)  an ASCII-only name class captured no `café.sh` at all;
#   CHANGED  (the core/scripts/ diff)  the quoted basename `caf\303\251.sh"` joins no hook name;
#   R2_CAND  (the rulebook candidates) `${r2p#core/}` strips nothing off a quoted line, so a
#            consumer that ALREADY holds theirs' `café.md` reads as missing it — a false DEFER.
# The first two fail in the ACQUITTING direction: a changed gating script the consumer's hook runs
# drops out of GATING and the gate says SELF-UPDATE-OK for the pull that replaces it.
#
# BOTH LOCALES, because the class fix is a claim about bytes: a bracket class behaves differently
# under UTF-8 and under C, and a cell run in one locale cannot speak for the other.
#
# The range-emptiness test at the bucket derivation (`[ -n "$(git … diff --name-only …)" ]`) carries
# the flag too but owes no cell: quoting changes a non-empty listing's bytes, never its emptiness.
QU="$(printf 'caf\303\251')"
QW="$(mktemp -d "${TMPDIR:-/tmp}/su-gate-quote.XXXXXX")"
qw_git() { git -C "$1" -c user.email=f@x -c user.name=f -c commit.gpgsign=false "${@:2}"; }
# qw_world <dir> <kind:script|rulebook> -> writes <dir>/{dist,cons} and <dir>/{B,T}
qw_world() {
  local w="$1"
  mkdir -p "$w/dist/core/rules" "$w/dist/core/scripts" "$w/cons/.githooks" "$w/cons/scripts/ai-dlc"
  git -C "$w/dist" init -q
  printf '1.0.0\n' > "$w/dist/VERSION"
  # One machinery path, never touched again: arm C resolves its population from it, and an
  # empty machinery set is UNDECIDED for every run (see the ss world above).
  printf 'qw machinery\n' > "$w/dist/core/rules/qw.md"
  if [ "$2" = script ]; then
    printf '#!/bin/sh\nexit 0\n' > "$w/dist/core/scripts/plain.sh"
    printf '#!/bin/sh\nexit 0\n' > "$w/dist/core/scripts/$QU.sh"
    printf '#!/bin/sh\nexit 0\n' > "$w/cons/scripts/ai-dlc/plain.sh"
    printf '#!/bin/sh\nexit 0\n' > "$w/cons/scripts/ai-dlc/$QU.sh"
    chmod +x "$w/cons/scripts/ai-dlc"/*.sh
    # NEAR-MISSES for the widened name class: a path ended by `;`, one inside double quotes, one
    # inside single quotes, and two on one line joined by `&&`. Each must yield exactly its own
    # name — an over-capture would emit one joined row, or a row carrying the delimiter.
    for nm in semi dq sq a1 a2 ca cb ka kb ea eb ha hb; do
      printf '#!/bin/sh\nexit 0\n' > "$w/dist/core/scripts/$nm.sh"
      printf '#!/bin/sh\nexit 0\n' > "$w/cons/scripts/ai-dlc/$nm.sh"
    done
    chmod +x "$w/cons/scripts/ai-dlc"/*.sh
    { printf '#!/usr/bin/env bash\nbash scripts/ai-dlc/plain.sh\nbash scripts/ai-dlc/%s.sh\n' "$QU"
      printf 'bash scripts/ai-dlc/semi.sh;\nbash "scripts/ai-dlc/dq.sh"\n'
      printf "bash 'scripts/ai-dlc/sq.sh'\n"
      printf 'bash scripts/ai-dlc/a1.sh && bash scripts/ai-dlc/a2.sh\n'
      # SEPARATOR near-misses: a name followed by `,` `:` `=` `#` must stop there. The second
      # member is a BARE name, because that is the shape that joins: before a `/` the old class
      # backtracks and splits correctly, so a full-path second member cannot discriminate.
      printf 'L=scripts/ai-dlc/ca.sh,cb.sh\n'
      printf 'P=scripts/ai-dlc/ka.sh:kb.sh\n'
      printf 'bash scripts/ai-dlc/ea.sh=eb.sh\n'
      printf 'bash scripts/ai-dlc/ha.sh#hb.sh\n'; } > "$w/cons/.githooks/pre-push"
  else
    printf '#!/usr/bin/env bash\n# invokes no scripts/ai-dlc/ validator\nexit 0\n' > "$w/cons/.githooks/pre-push"
    # A fixture whose non-comment code resolves a rulebook file in the live tree: both of R2's
    # patterns match it, so the arm's only remaining question is whether the rulebook changes.
    mkdir -p "$w/dist/core/fixtures/qw-coupled"
    printf '#!/usr/bin/env bash\ncat "$D_ROOT/core/skills/ai-dlc/steps/%s.md"\n' "$QU" > "$w/dist/core/fixtures/qw-coupled/run.sh"
    mkdir -p "$w/dist/core/skills/ai-dlc/steps"
    printf '# step at base\n' > "$w/dist/core/skills/ai-dlc/steps/$QU.md"
    # A rulebook path carrying a SPACE, changed in the range and already held at theirs by the
    # consumer. A `for` over the candidate list split it into `steps/a` and `b.md`, neither of
    # which is a consumer file, and the arm deferred a pull whose rulebook was already current.
    printf '# spaced step at base\n' > "$w/dist/core/skills/ai-dlc/steps/a b.md"
  fi
  chmod +x "$w/cons/.githooks/pre-push"
  qw_git "$w/dist" add -A >/dev/null 2>&1; qw_git "$w/dist" commit -qm base >/dev/null 2>&1
  git -C "$w/dist" rev-parse HEAD > "$w/B"
  printf '1.1.0\n' > "$w/dist/VERSION"
  if [ "$2" = script ]; then
    printf '#!/bin/sh\n# reworded, still passes\nexit 0\n' > "$w/dist/core/scripts/plain.sh"
    printf '#!/bin/sh\n# the new check finds something\nexit 1\n' > "$w/dist/core/scripts/$QU.sh"
    for nm in semi dq sq a1 a2 ca cb ka kb ea eb ha hb; do printf '#!/bin/sh\n# reworded\nexit 0\n' > "$w/dist/core/scripts/$nm.sh"; done
  else
    printf '# step at theirs\n' > "$w/dist/core/skills/ai-dlc/steps/$QU.md"
    # The consumer ALREADY holds theirs' copy, so the rulebook is NOT about to change for it.
    mkdir -p "$w/cons/.claude/skills/ai-dlc/steps"
    printf '# step at theirs\n' > "$w/cons/.claude/skills/ai-dlc/steps/$QU.md"
    printf '# spaced step at theirs\n' > "$w/dist/core/skills/ai-dlc/steps/a b.md"
    printf '# spaced step at theirs\n' > "$w/cons/.claude/skills/ai-dlc/steps/a b.md"
  fi
  qw_git "$w/dist" add -A >/dev/null 2>&1; qw_git "$w/dist" commit -qm theirs >/dev/null 2>&1
  git -C "$w/dist" rev-parse HEAD > "$w/T"
}
qw_world "$QW/s" script
qw_world "$QW/r" rulebook
# qw_run <gate> <world> <locale:utf8|c> -> the gate's stdout rows
qw_run() {
  if [ "$3" = c ]; then
    env -i PATH="$PATH" HOME="${HOME:-/}" LC_ALL=C bash "$1" "$2/dist" "$(cat "$2/B")" "$(cat "$2/T")" "$2/cons" 2>/dev/null
  else
    LC_ALL=en_US.UTF-8 bash "$1" "$2/dist" "$(cat "$2/B")" "$(cat "$2/T")" "$2/cons" 2>/dev/null
  fi
}
# qs_scan <gate> <locale> -> "plain=<status> cafe=<status|none>" for the script world
qs_scan() {
  local o
  o="$(qw_run "$1" "$QW/s" "$2")"
  printf 'plain=%s cafe=%s\n' \
    "$(printf '%s\n' "$o" | awk -F'\t' '$2 == "plain.sh" {print $1; exit}')" \
    "$(printf '%s\n' "$o" | awk -F'\t' -v n="$QU.sh" '$2 == n {f=$1; exit} END {print (f == "" ? "none" : f)}')"
}
# qn_scan <gate> <locale> -> the sorted set of per-script row subjects for the script world
qn_scan() {
  qw_run "$1" "$QW/s" "$2" | awk -F'\t' '$1 ~ /^SELF-UPDATE-(OK|DEFER|UNDECIDED)$/ && $2 != "-" && $2 !~ /[.]md$/ {print $2}' \
    | LC_ALL=C sort -u | tr '\n' ','
}
# qr_scan <gate> <locale> -> "r2=<n> ok=<n>" for the rulebook world
qr_scan() {
  local o
  o="$(qw_run "$1" "$QW/r" "$2")"
  printf 'r2=%s ok=%s\n' \
    "$(printf '%s\n' "$o" | awk -F'\t' '$1 == "SELF-UPDATE-DEFER" && $2 == "rulebook-coupled-fixtures"' | grep -c .)" \
    "$(printf '%s\n' "$o" | awk -F'\t' '$1 == "SELF-UPDATE-OK" && $2 == "-"' | grep -c .)"
}
for qloc in utf8 c; do
  ss_assert "quote-script-$qloc" "$(qs_scan "$GATE" "$qloc")" "plain=SELF-UPDATE-OK cafe=SELF-UPDATE-DEFER" \
    "($qloc) a changed gating script named café.sh is invoked, changed and deferred on, beside a plain one that passes"
  ss_assert "quote-names-$qloc" "$(qn_scan "$GATE" "$qloc")" "a1.sh,a2.sh,ca.sh,$QU.sh,dq.sh,ea.sh,ha.sh,ka.sh,plain.sh,semi.sh,sq.sh," \
    "($qloc) every delimited hook name yields exactly its own row, two on one line yield two, and , : = # end a name"
  ss_assert "quote-r2-$qloc" "$(qr_scan "$GATE" "$qloc")" "r2=0 ok=1" \
    "($qloc) a consumer already holding theirs' café.md is not about to change it, so no rulebook DEFER"
done
# THE CONTROL THAT SAYS THE R2 CELL CAN FIRE: the same world with the consumer's copy removed IS
# about to change, and must defer on the raw name.
mv "$QW/r/cons/.claude/skills/ai-dlc/steps/$QU.md" "$QW/r/held.md"
ss_assert "quote-r2-control" "$(qr_scan "$GATE" utf8)" "r2=1 ok=0" \
  "with the consumer's café.md absent the rulebook IS about to change, so the arm defers"
mv "$QW/r/held.md" "$QW/r/cons/.claude/skills/ai-dlc/steps/$QU.md"

# --- MUTANTS on the quoting cells: each restores ONE site to its pre-fix spelling --------------
mkdir -p "$QW/m"
cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$QW/m"/ 2>/dev/null
ss_assert "quote-mut-control" "$(qs_scan "$QW/m/self-update-gate.sh" utf8)" \
  "plain=SELF-UPDATE-OK cafe=SELF-UPDATE-DEFER" "an unmutated copy beside its siblings defers on café.sh, so a kill below is the mutation"
# qw_mut <label> <line-prefix> <replacement-line> <scanner> <want> <why>
# Replaces the ONE line opening with <line-prefix> (leading blanks ignored) by <replacement-line>;
# a prefix matching zero or several lines is refused as an anchor that moved.
qw_mut() {
  local mrc=0 got
  QW_PFX="$2" QW_NEW="$3" python3 -c 'import os,sys
p, n = os.environ["QW_PFX"], os.environ["QW_NEW"]
ls = open(sys.argv[1]).read().split("\n")
hit = [i for i, l in enumerate(ls) if l.lstrip().startswith(p)]
if len(hit) != 1: sys.exit(3)
i = hit[0]; ls[i] = ls[i][:len(ls[i]) - len(ls[i].lstrip())] + n
open(sys.argv[2], "w").write("\n".join(ls))' "$GATE" "$QW/m/self-update-gate.sh" 2>/dev/null || mrc=$?
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ "$mrc" -ne 0 ] || cmp -s "$GATE" "$QW/m/self-update-gate.sh"; then
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-16s mutation matched nothing (anchor moved)\n' "$1"
  else
    got="$("$4" "$QW/m/self-update-gate.sh" utf8)"
    if [ "$got" = "$5" ]; then printf '  ok    %-16s KILLED (%s: %s)\n' "$1" "$6" "$got"
    else FAILURES=$((FAILURES + 1)); printf '  FAIL  %-16s SURVIVED: got [%s], want [%s]\n' "$1" "$got" "$5"; fi
  fi
  cp "$GATE" "$QW/m/self-update-gate.sh"
}
qw_mut "quote-mut-invoked" 'INVOKED="$(grep -oE ' \
  "INVOKED=\"\$(grep -oE 'scripts/ai-dlc/[A-Za-z0-9._-]+\\.sh' \"\$HOOK\" | sed 's|.*/||' | sort -u)\"" \
  qs_scan "plain=SELF-UPDATE-OK cafe=none" "an ASCII-only hook class drops café.sh from INVOKED and the gate is silent on it"
qw_mut "quote-mut-changed" 'git -C "$DIST" -c core.quotePath=false diff --name-only "${BASE}..${THEIRS}" -- core/scripts/ >' \
  'git -C "$DIST" diff --name-only "${BASE}..${THEIRS}" -- core/scripts/ > "$TMP/changed-raw" 2>/dev/null' \
  qs_scan "plain=SELF-UPDATE-OK cafe=none" "a C-quoted changed-script listing joins no hook name and café.sh drops out of GATING"
qw_mut "quote-mut-r2" 'R2_CAND="$(git -C "$DIST" -c core.quotePath=false diff --name-only' \
  'R2_CAND="$(git -C "$DIST" diff --name-only "${BASE}..${THEIRS}" -- \' \
  qr_scan "r2=1 ok=0" "a C-quoted rulebook candidate maps to no consumer path and reads as about to change"
# The class BEFORE the separators joined it: `, : = # ! @ % + ~` continued a token, so each
# separator line read as ONE joined row and its first name dropped out of INVOKED.
qw_mut_names() {
  local mrc=0 got
  QW_OLDC="$1" QW_NEWC="$2" python3 -c 'import os,sys
o, n = os.environ["QW_OLDC"], os.environ["QW_NEWC"]
s = open(sys.argv[1]).read()
if s.count(o) != 1: sys.exit(3)
open(sys.argv[2], "w").write(s.replace(o, n, 1))' "$GATE" "$QW/m/self-update-gate.sh" 2>/dev/null || mrc=$?
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ "$mrc" -ne 0 ] || cmp -s "$GATE" "$QW/m/self-update-gate.sh"; then
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-16s mutation matched nothing (anchor moved)\n' "quote-mut-sep"
  else
    got="$(qn_scan "$QW/m/self-update-gate.sh" c)"
    case "$got" in
      *,ca.sh,*|*,ka.sh,*|*,ea.sh,*|*,ha.sh,*) FAILURES=$((FAILURES + 1)); printf '  FAIL  %-16s SURVIVED: the old class still split a separator pair [%s]\n' "quote-mut-sep" "$got" ;;
      *) printf '  ok    %-16s KILLED (with , : = # inside the class the pairs read as joined tokens: %s)\n' "quote-mut-sep" "$got" ;;
    esac
  fi
  cp "$GATE" "$QW/m/self-update-gate.sh"
}
qw_mut_names '/,:=#!@%+~]+' '/]+'

# --- THE RULEBOOK CANDIDATE LOOP READS A STAGED FILE, AND A FAILED LISTING REFUSES (BL-420) -----
# `steps/a b.md` is changed in the range and the consumer already holds theirs' copy, so the
# quote-r2-* cells above demand r2=0 ok=1 WITH it present. A `for` over the candidate list split it
# into `steps/a` and `b.md`, which name no consumer file, and the arm deferred a pull whose
# rulebook was already current. Each mutant below restores one of the base's two defects.
# qw_mut_pairs <label> <scanner> <want> <why> <old> <new> [<old> <new>]... -- each <old> must
# occur EXACTLY once in the gate, or the anchor moved and the mutant is refused.
qw_mut_pairs() {
  local label="$1" scan="$2" want="$3" why="$4" mrc=0 got
  shift 4
  python3 -c 'import sys
s = open(sys.argv[1]).read(); p = sys.argv[3:]
for i in range(0, len(p), 2):
    if s.count(p[i]) != 1: sys.exit(3)
    s = s.replace(p[i], p[i + 1], 1)
open(sys.argv[2], "w").write(s)' "$GATE" "$QW/m/self-update-gate.sh" "$@" 2>/dev/null || mrc=$?
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ "$mrc" -ne 0 ] || cmp -s "$GATE" "$QW/m/self-update-gate.sh"; then
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-16s mutation matched nothing (anchor moved)\n' "$label"
  else
    got="$("$scan" "$QW/m/self-update-gate.sh" utf8)"
    if [ "$got" = "$want" ]; then printf '  ok    %-16s KILLED (%s: %s)\n' "$label" "$why" "$got"
    else FAILURES=$((FAILURES + 1)); printf '  FAIL  %-16s SURVIVED: got [%s], want [%s]\n' "$label" "$got" "$want"; fi
  fi
  cp "$GATE" "$QW/m/self-update-gate.sh"
}
qw_mut_pairs "quote-mut-r2split" qr_scan "r2=1 ok=0" \
  "a for over the candidate list splits steps/a b.md into halves that name no consumer file" \
  'while IFS= read -r r2p; do' 'for r2p in $R2_CAND; do' \
  'done < "$TMP/r2-cand"' 'done'
# A FAILED CANDIDATE LISTING IS UNDECIDED, NEVER "NO RULEBOOK CHANGE". The consumer's café.md is held
# out, so the rulebook IS about to change and the healthy answer is the DEFER `quote-r2-control`
# asserts; a listing that failed printed nothing, and nothing read as a pull that changes no rulebook.
# The shim fails ONLY the R2 listing (the one `diff --name-only` naming rule-authoring.md) and drops
# a marker, so the cell cannot pass on a shim that never ran.
QR_SH="$QW/r2shim"; mkdir -p "$QR_SH"
printf '#!/bin/sh\ncase "$*" in *" diff --name-only "*"rule-authoring.md"*) : > "%s/fired"; exit 128 ;; esac\nexec "%s" "$@"\n' \
  "$QR_SH" "$(command -v git)" > "$QR_SH/git"
chmod +x "$QR_SH/git"
qr_fail() { # qr_fail <gate> [locale] -> "und=<n> defer=<n> ok=<n> fired=<0|1>"
  local o
  rm -f "$QR_SH/fired"
  mv "$QW/r/cons/.claude/skills/ai-dlc/steps/$QU.md" "$QW/r/held.md"
  o="$(PATH="$QR_SH:$PATH" LC_ALL=en_US.UTF-8 bash "$1" "$QW/r/dist" "$(cat "$QW/r/B")" "$(cat "$QW/r/T")" "$QW/r/cons" 2>/dev/null)"
  mv "$QW/r/held.md" "$QW/r/cons/.claude/skills/ai-dlc/steps/$QU.md"
  printf 'und=%s defer=%s ok=%s fired=%s\n' \
    "$(printf '%s\n' "$o" | awk -F'\t' '$1 == "SELF-UPDATE-UNDECIDED" && $3 ~ /^the rulebook candidate listing/' | grep -c .)" \
    "$(printf '%s\n' "$o" | awk -F'\t' '$1 == "SELF-UPDATE-DEFER" && $2 == "rulebook-coupled-fixtures"' | grep -c .)" \
    "$(printf '%s\n' "$o" | awk -F'\t' '$1 == "SELF-UPDATE-OK" && $2 == "-"' | grep -c .)" \
    "$([ -f "$QR_SH/fired" ] && echo 1 || echo 0)"
}
ss_assert "quote-r2-diff-failed" "$(qr_fail "$GATE")" "und=1 defer=0 ok=0 fired=1" \
  "a rulebook candidate listing that failed is UNDECIDED, and the shim that failed it is shown to fire"
qw_mut_pairs "quote-mut-r2rc" qr_fail "und=0 defer=0 ok=1 fired=1" \
  "with the listing's status unread a failed diff reads as no rulebook change and the gate says OK" \
  'core/team-roles/ 2>/dev/null)" || R2_RC=$?' 'core/team-roles/ 2>/dev/null)"'
rm -rf "$QW"

fi
if sg mp; then
# --- A FAILED MACHINERY PRODUCER IS NOT A NARROWER SET (BL-418) ---------------------------------
# `machinery_paths()` ran both `ls-files --with-tree` listings with their status unread, so a listing
# that failed at ONE ref returned the other ref's paths at rc 0 -- a NARROWER set, and non-empty, so
# the EMPTY guard never saw it. The discriminating input is a machinery path present at BASE and
# DELETED at theirs, consumer-modified: only the BASE listing carries it, so a shim failing only that
# listing drops its CARRY row and the gate says OK over a pull that deletes a consumer edit. Each
# caller is driven through the same shape of shim, and each shim leaves a marker it fired.
MP="$(mktemp -d "${TMPDIR:-/tmp}/su-gate-mp.XXXXXX")"
mp_git() { git -C "$1" -c user.email=f@x -c user.name=f -c commit.gpgsign=false "${@:2}"; }
mp_shim() { # mp_shim <dir> <ref> -- a git that fails only `ls-files --with-tree=<ref>`
  mkdir -p "$1"
  printf '#!/bin/sh\ncase "$*" in *"ls-files --with-tree=%s "*) : > "%s/fired"; exit 128 ;; esac\nexec "%s" "$@"\n' \
    "$2" "$1" "$(command -v git)" > "$1/git"
  chmod +x "$1/git"
}
# mp_engine <name> -> a whole copy of the reconcile dir, so a mutant resolves its siblings
mp_engine() { rm -rf "$MP/e-$1"; mkdir -p "$MP/e-$1"; cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$MP/e-$1"/ 2>/dev/null; printf '%s' "$MP/e-$1"; }
# mp_mut <name> <file> <old> <new> [<old> <new>]... -> an engine with <file> mutated; refuses a moved anchor
mp_mut() {
  local e f="$2" n="$1" mrc=0
  e="$(mp_engine "$n")"; shift 2
  python3 -c 'import sys
s = open(sys.argv[1]).read(); p = sys.argv[3:]
for i in range(0, len(p), 2):
    if s.count(p[i]) != 1: sys.exit(3)
    s = s.replace(p[i], p[i + 1], 1)
open(sys.argv[2], "w").write(s)' "$(dirname "$GATE")/$f" "$e/$f" "$@" 2>/dev/null || mrc=$?
  if [ "$mrc" -ne 0 ] || cmp -s "$(dirname "$GATE")/$f" "$e/$f" || ! bash -n "$e/$f" 2>/dev/null; then printf ''; return 1; fi
  printf '%s' "$e"
}

# The gate world: kappa diverged-and-untouched, omega deleted at theirs and consumer-modified.
GD="$MP/gd"; GC="$MP/gc"; mkdir -p "$GD/core/rules" "$GC/.claude/rules" "$GC/.githooks"
git -C "$GD" init -q
printf 'omega base\n' > "$GD/core/rules/omega.md"; printf 'kappa base\n' > "$GD/core/rules/kappa.md"; printf '0.1.0\n' > "$GD/VERSION"
mp_git "$GD" add -A; mp_git "$GD" commit -qm base; MP_GB="$(git -C "$GD" rev-parse HEAD)"
rm -f "$GD/core/rules/omega.md"; printf 'kappa theirs\n' > "$GD/core/rules/kappa.md"; printf '0.2.0\n' > "$GD/VERSION"
mp_git "$GD" add -A; mp_git "$GD" commit -qm theirs; MP_GT="$(git -C "$GD" rev-parse HEAD)"
printf 'omega LOCAL EDIT\n' > "$GC/.claude/rules/omega.md"; printf 'kappa base\n' > "$GC/.claude/rules/kappa.md"
printf '#!/usr/bin/env bash\n# invokes no scripts/ai-dlc/ validator\nexit 0\n' > "$GC/.githooks/pre-push"; chmod +x "$GC/.githooks/pre-push"
mp_shim "$MP/gs" "$MP_GB"
mp_gate() { # mp_gate <gate> <shim-dir|-> -> "resolved=<n> empty=<n> carry=<paths> ok=<n> fired=<0|1>"
  local o p="$PATH"
  rm -f "$MP/gs/fired"; [ "$2" = - ] || p="$2:$PATH"
  o="$(PATH="$p" bash "$1" "$GD" "$MP_GB" "$MP_GT" "$GC" 2>/dev/null)"
  printf 'resolved=%s empty=%s carry=%s ok=%s fired=%s\n' \
    "$(printf '%s\n' "$o" | awk -F'\t' '$1 == "SELF-UPDATE-UNDECIDED" && $3 ~ /could not be RESOLVED/' | grep -c .)" \
    "$(printf '%s\n' "$o" | awk -F'\t' '$1 == "SELF-UPDATE-UNDECIDED" && $3 ~ /resolved EMPTY/' | grep -c .)" \
    "$(su_carry "$o")" \
    "$(printf '%s\n' "$o" | awk -F'\t' '$1 == "SELF-UPDATE-OK" && $2 == "-"' | grep -c .)" \
    "$([ -f "$MP/gs/fired" ] && echo 1 || echo 0)"
}
ss_assert "mp-gate-healthy" "$(mp_gate "$GATE" -)" "resolved=0 empty=0 carry=core/rules/omega.md, ok=1 fired=0" \
  "unshimmed, the path deleted upstream over a consumer edit is CARRIED and the gate goes on to OK"
ss_assert "mp-gate-basefail" "$(mp_gate "$GATE" "$MP/gs")" "resolved=1 empty=0 carry= ok=0 fired=1" \
  "the BASE listing failing is UNDECIDED with its own wording, not an OK over a set missing the carried path"
# THE HEALTHY-EMPTY CONTROL, under the gate's own `pipefail`: a manifest whose `machinery:` block is
# empty is an ANSWER, rc 0, and reaches the EMPTY row -- never the producer-failure row.
MP_EE="$(mp_engine empty)"
awk '/^machinery:/{print; skip=1; next} skip && /^[a-z_]+:/{skip=0} !skip' "$MP_EE/setup-sites.md" > "$MP_EE/.t" && mv "$MP_EE/.t" "$MP_EE/setup-sites.md"
ss_assert "mp-gate-empty" "$(mp_gate "$MP_EE/self-update-gate.sh" -)" "resolved=0 empty=1 carry= ok=1 fired=0" \
  "an empty machinery set from a readable manifest returns 0 under pipefail and reads as EMPTY, not as a failed producer"
e="$(mp_mut basestatus preclassify.sh \
  '--with-tree="$BASE" -- $_mgnorm 2>/dev/null)" || _mrc=4' '--with-tree="$BASE" -- $_mgnorm 2>/dev/null)"')" \
  && got="$(mp_gate "$e/self-update-gate.sh" "$MP/gs")" || got="DID-NOT-APPLY"
mp_killed "mp-mut-basestat" "$got" "resolved=0 empty=0 carry= ok=1 fired=1" \
  "the BASE listing's status unread: the narrower set drops omega's CARRY row and the gate says OK"
e="$(mp_mut gaterc self-update-gate.sh \
  'c_mrc=0; C_PATHS="$(machinery_paths)" || c_mrc=$?' 'c_mrc=0; C_PATHS="$(machinery_paths)"')" \
  && got="$(mp_gate "$e/self-update-gate.sh" "$MP/gs")" || got="DID-NOT-APPLY"
mp_killed "mp-mut-gaterc" "$got" "resolved=0 empty=1 carry= ok=1 fired=1" \
  "the gate reading no status: a failed producer is reported as an EMPTY set, which is a different fault"
e="$(mp_mut oldtail preclassify.sh \
  "  printf '%s\\n' \"\$_mout\" | awk 'length' | sort -u || return 4
  return 0" \
  "  printf '%s\\n' \"\$_mout\" | grep -v '^\$' | sort -u")" \
  && { awk '/^machinery:/{print; skip=1; next} skip && /^[a-z_]+:/{skip=0} !skip' "$e/setup-sites.md" > "$e/.t" && mv "$e/.t" "$e/setup-sites.md"; } \
  && got="$(mp_gate "$e/self-update-gate.sh" -)" || got="DID-NOT-APPLY"
mp_killed "mp-mut-oldtail" "$got" "resolved=1 empty=0 carry= ok=0 fired=0" \
  "the base's tail exits 1 under pipefail on a healthy EMPTY set, which then reads as a failed producer"

# The preclassify world: `added.md` is born at the stamp's `skill_commit`, the consumer holds that
# copy, and the dist checkout has moved PAST theirs and dropped it -- so only the THEIRS listing puts
# it in the machinery set. Unshimmed it buckets UPSTREAM-ONLY-ADD; with that listing failing, the base
# scoped the arm to a set without it and bucketed BOTH-ADDED->CLASSIFY at rc 0.
PD="$MP/pd"; PCN="$MP/pc"; mkdir -p "$PD/core/rules" "$PCN/.claude/rules"
git -C "$PD" init -q
printf 'steady base\n' > "$PD/core/rules/steady.md"; printf '0.1.0\n' > "$PD/VERSION"
mp_git "$PD" add -A; mp_git "$PD" commit -qm base; MP_PB="$(git -C "$PD" rev-parse HEAD)"
printf 'added mid\n' > "$PD/core/rules/added.md"; printf '0.2.0\n' > "$PD/VERSION"
mp_git "$PD" add -A; mp_git "$PD" commit -qm mid; MP_PM="$(git -C "$PD" rev-parse HEAD)"
printf 'added theirs\n' > "$PD/core/rules/added.md"; printf '0.3.0\n' > "$PD/VERSION"
mp_git "$PD" add -A; mp_git "$PD" commit -qm theirs; MP_PT="$(git -C "$PD" rev-parse HEAD)"
rm -f "$PD/core/rules/added.md"; printf '0.4.0\n' > "$PD/VERSION"; mp_git "$PD" add -A; mp_git "$PD" commit -qm ahead
printf 'steady base\n' > "$PCN/.claude/rules/steady.md"; printf 'added mid\n' > "$PCN/.claude/rules/added.md"
printf 'version: 0.1.0\ncommit: %s\nskill_commit: %s\n' "$MP_PB" "$MP_PM" > "$PCN/.claude/.ai-dlc-version"
mp_shim "$MP/ps" "$MP_PT"
mp_pc() { # mp_pc <preclassify> <shim-dir|-> [consumer] -> "rc=<n> rows=<path=bucket,...> refused=<what> fired=<0|1>"
  local p="$PATH" rows rc
  rm -f "$MP/ps/fired"; [ "$2" = - ] || p="$2:$PATH"
  rows="$(PATH="$p" bash "$1" "$PD" "$MP_PB" "$MP_PT" "${3:-$PCN}" 2> "$MP/pc.err")"; rc=$?
  printf 'rc=%s rows=%s refused=%s fired=%s\n' "$rc" \
    "$(printf '%s\n' "$rows" | awk -F'\t' '$2 ~ /^core\// {print $2 "=" $4}' | sort | tr '\n' ',')" \
    "$(awk '/refusing to classify: the machinery path set/ {m=1} /refusing to classify: the setup-sited path set/ {s=1} END {print (m ? "machinery" : (s ? "sited" : "-"))}' "$MP/pc.err")" \
    "$([ -f "$MP/ps/fired" ] && echo 1 || echo 0)"
}
ss_assert "mp-pc-healthy" "$(mp_pc "$SU_PC" -)" "rc=0 rows=core/rules/added.md=UPSTREAM-ONLY-ADD, refused=- fired=0" \
  "unshimmed, the path born at skill_commit is suppressed by the machinery-scoped arm"
ss_assert "mp-pc-theirsfail" "$(mp_pc "$SU_PC" "$MP/ps")" "rc=2 rows= refused=machinery fired=1" \
  "the THEIRS listing failing refuses the run, never scopes the arm to a set without the added path"
MP_PE="$(mp_engine pcempty)"
awk '/^machinery:/{print; skip=1; next} skip && /^[a-z_]+:/{skip=0} !skip' "$MP_PE/setup-sites.md" > "$MP_PE/.t" && mv "$MP_PE/.t" "$MP_PE/setup-sites.md"
ss_assert "mp-pc-empty" "$(mp_pc "$MP_PE/preclassify.sh" -)" "rc=0 rows=core/rules/added.md=BOTH-ADDED->CLASSIFY, refused=- fired=0" \
  "an empty machinery set is an answer: rc 0, and the unscoped path classifies"
e="$(mp_mut theirsstat preclassify.sh \
  '--with-tree="$THEIRS" -- $_mgnorm 2>/dev/null)" || _mrc=4' '--with-tree="$THEIRS" -- $_mgnorm 2>/dev/null)"')" \
  && got="$(mp_pc "$e/preclassify.sh" "$MP/ps")" || got="DID-NOT-APPLY"
mp_killed "mp-mut-thrstat" "$got" "rc=0 rows=core/rules/added.md=BOTH-ADDED->CLASSIFY, refused=- fired=1" \
  "the THEIRS listing's status unread: the narrower set re-buckets the self-updated path as a consumer edit"
e="$(mp_mut pcrefuse preclassify.sh \
  '[ -z "$SELF_UPDATE_REF" ] || [ "$_pc_mrc" -eq 0 ] \' '[ -z "$SELF_UPDATE_REF" ] || [ "$_pc_mrc" -ge 0 ] \')" \
  && got="$(mp_pc "$e/preclassify.sh" "$MP/ps")" || got="DID-NOT-APPLY"
mp_killed "mp-mut-pcrefuse" "$got" "rc=0 rows=core/rules/added.md=BOTH-ADDED->CLASSIFY, refused=- fired=1" \
  "preclassify reading 4 and not refusing: an empty scope classifies a file nobody edited"
# THE SETUP-SITED SET, the other producer this file owns. No stamp, so the machinery set is never
# asked for and the sited read is the only thing that can refuse. A MISSING manifest refuses (it
# ships beside preclassify in both layouts, so its absence is a broken install); a manifest
# declaring no sited file is an answer. Removed rather than `chmod 000`: root reads a mode-000
# file, and a consumer suite run as root would score this cell red for a reason it does not own.
PCS="$MP/pcs"; mkdir -p "$PCS/.claude/rules"; cp "$PCN/.claude/rules/"* "$PCS/.claude/rules/"
MP_SU="$(mp_engine sitedgone)"; rm -f "$MP_SU/setup-sites.md"
ss_assert "mp-sited-missing" "$(mp_pc "$MP_SU/preclassify.sh" - "$PCS")" "rc=2 rows= refused=sited fired=0" \
  "a missing setup-sites.md refuses, never reads as a tree with no setup-sited file"
MP_SN="$(mp_engine sitednone)"
awk '!/^[ \t]*file:[ \t]*core\//' "$MP_SN/setup-sites.md" > "$MP_SN/.t" && mv "$MP_SN/.t" "$MP_SN/setup-sites.md"
ss_assert "mp-sited-none" "$(mp_pc "$MP_SN/preclassify.sh" - "$PCS" | cut -d' ' -f1,3)" "rc=0 refused=-" \
  "a manifest declaring no setup-sited file is an empty answer, rc 0"
e="$(mp_mut sitedrc preclassify.sh \
  'if _pc_ssp="$(setup_sited_paths)"; then' 'if _pc_ssp="$(setup_sited_paths)" || :; then')" \
  && { rm -f "$e/setup-sites.md"; got="$(mp_pc "$e/preclassify.sh" - "$PCS" | cut -d' ' -f1,3)"; } || got="DID-NOT-APPLY"
mp_killed "mp-mut-sitedrc" "$got" "rc=0 refused=-" \
  "the sited set's status unread: a missing manifest classifies the whole tree as unsited at rc 0"

# unregistered-drift: the same partial failure, and the carry derivation run ONCE (BL-425). Three
# machinery hooks the consumer edited, all in the range: omega deleted at theirs, kappa and sigma
# changed. Each reaches the carried test, so each row used to re-run the whole derivation inside
# `$( )` -- `bash preclassify.sh` included -- and leave an `ud-carry.*` directory behind. Counted
# through a `mktemp` shim in a private TMPDIR: every preclassify run makes one `preclassify-stage`
# directory and every derivation one `ud-carry`, so one log answers both counts.
UD="$MP/ud"; UDD="$UD/dist"; UDC="$UD/cons"; mkdir -p "$UDD/core/hooks" "$UDC/.claude/hooks" "$UD/tmp" "$UD/mk"
git -C "$UDD" init -q
for h in omega kappa sigma; do
  printf '#!/usr/bin/env bash\n# the %s hook records each dispatched beat exactly once in the sprint.\n' "$h" > "$UDD/core/hooks/ai-dlc-$h.sh"
done
printf '0.1.0\n' > "$UDD/VERSION"
mp_git "$UDD" add -A; mp_git "$UDD" commit -qm base; MP_UB="$(git -C "$UDD" rev-parse HEAD)"
rm -f "$UDD/core/hooks/ai-dlc-omega.sh"
for h in kappa sigma; do printf '# upstream added a line of its own to %s at theirs, long enough.\n' "$h" >> "$UDD/core/hooks/ai-dlc-$h.sh"; done
printf '0.2.0\n' > "$UDD/VERSION"
mp_git "$UDD" add -A; mp_git "$UDD" commit -qm theirs; MP_UT="$(git -C "$UDD" rev-parse HEAD)"
for h in omega kappa sigma; do
  git -C "$UDD" show "$MP_UB:core/hooks/ai-dlc-$h.sh" > "$UDC/.claude/hooks/ai-dlc-$h.sh"
  printf '# CONSUMER HARDENING on %s: a line the distribution never carried here.\n' "$h" >> "$UDC/.claude/hooks/ai-dlc-$h.sh"
done
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/log"\nexec "%s" "$@"\n' "$UD/mk" "$(command -v mktemp)" > "$UD/mk/mktemp"
chmod +x "$UD/mk/mktemp"
mp_shim "$MP/us" "$MP_UB"
mp_ud() { # mp_ud <unregistered-drift> <shim-dir|-> -> "rc=<n> rows=<status:path,...> refused=<0|1> fired=<0|1>"
  local p="$PATH" o rc
  rm -f "$MP/us/fired"; [ "$2" = - ] || p="$2:$PATH"
  o="$(PATH="$p" bash "$1" "$UDD" "$MP_UB" "$UDC" "$MP_UT" 2> "$MP/ud.err")"; rc=$?
  printf 'rc=%s rows=%s refused=%s fired=%s\n' "$rc" \
    "$(printf '%s\n' "$o" | awk -F'\t' 'NF >= 2 {print $1 ":" $2}' | sort | tr '\n' ',')" \
    "$(grep -c 'REFUSED.*the machinery path set (machinery_paths' "$MP/ud.err")" \
    "$([ -f "$MP/us/fired" ] && echo 1 || echo 0)"
}
mp_leak() { # mp_leak <unregistered-drift> -> "preclassify=<n> derived=<n> left=<n> carried=<n>"
  local o
  rm -rf "$UD/tmp"; mkdir -p "$UD/tmp"; : > "$UD/mk/log"
  o="$(PATH="$UD/mk:$PATH" TMPDIR="$UD/tmp/" bash "$1" "$UDD" "$MP_UB" "$UDC" "$MP_UT" 2>/dev/null)"
  printf 'preclassify=%s derived=%s left=%s carried=%s\n' \
    "$(grep -c 'preclassify-stage' "$UD/mk/log")" "$(grep -c 'ud-carry' "$UD/mk/log")" \
    "$(ls "$UD/tmp" | grep -c '^ud-carry')" \
    "$(printf '%s\n' "$o" | awk -F'\t' '$1 == "CORE-MACHINERY-CARRIED"' | grep -c .)"
}
MP_UD_CARRIED="rows=CORE-MACHINERY-CARRIED:hooks/ai-dlc-kappa.sh,CORE-MACHINERY-CARRIED:hooks/ai-dlc-omega.sh,CORE-MACHINERY-CARRIED:hooks/ai-dlc-sigma.sh,"
MP_UD_BASEFAIL="rows=CORE-MACHINERY-CARRIED:hooks/ai-dlc-kappa.sh,CORE-MACHINERY-CARRIED:hooks/ai-dlc-sigma.sh,HARD-UNREGISTERED-CORE-DRIFT:hooks/ai-dlc-omega.sh,"
ss_assert "mp-ud-healthy" "$(mp_ud "$(dirname "$GATE")/unregistered-drift.sh" -)" "rc=0 $MP_UD_CARRIED refused=0 fired=0" \
  "unshimmed, all three edited machinery hooks in the range are CARRIED"
ss_assert "mp-ud-basefail" "$(mp_ud "$(dirname "$GATE")/unregistered-drift.sh" "$MP/us")" "rc=2 rows= refused=1 fired=1" \
  "the BASE listing failing refuses the scan, never drops omega back to a HARD row whose remedy contradicts the worklist"
ss_assert "mp-ud-once" "$(mp_leak "$(dirname "$GATE")/unregistered-drift.sh")" "preclassify=1 derived=1 left=0 carried=3" \
  "three rows reach the carried test, and preclassify runs ONCE and its directory is removed by the trap"
e="$(mp_mut udrc unregistered-drift.sh \
  'machinery_paths > "$CARRY_TMP/mach" 2>/dev/null || return 4' 'machinery_paths > "$CARRY_TMP/mach" 2>/dev/null || : > "$CARRY_TMP/mach"')" \
  && got="$(mp_ud "$e/unregistered-drift.sh" "$MP/us")" || got="DID-NOT-APPLY"
mp_killed "mp-mut-udrc" "$got" "rc=0 rows=HARD-UNREGISTERED-CORE-DRIFT:hooks/ai-dlc-kappa.sh,HARD-UNREGISTERED-CORE-DRIFT:hooks/ai-dlc-omega.sh,HARD-UNREGISTERED-CORE-DRIFT:hooks/ai-dlc-sigma.sh, refused=0 fired=1" \
  "a failed machinery producer read as an empty set: every carried hook falls back to HARD at rc 0"
e="$(mp_mut udperrow unregistered-drift.sh \
  '_cd=0; ud_carry_derive || _cd=$?' '_cd=0' \
  "  _cb_p=\"\$1\"
  [ \"\$CARRY_STATE\" = \"ready\" ]" \
  "  _cb_p=\"\$1\"
  ud_carry_derive || return 1
  [ \"\$CARRY_STATE\" = \"ready\" ]")" \
  && got="$(mp_leak "$e/unregistered-drift.sh")" || got="DID-NOT-APPLY"
mp_killed "mp-mut-perrow" "$got" "preclassify=3 derived=3 left=3 carried=3" \
  "the derivation back inside \$( ): preclassify re-runs per row and every ud-carry directory leaks"
chmod -R u+rwX "$MP" 2>/dev/null
rm -rf "$MP"

fi
if sg av; then
# --- EACH GATING SCRIPT RUNS WITH THE HOOK'S OWN ARGV (BL-456) --------------------------------
# The differential ran every hook-named script BARE. A script that needs arguments exits the same
# usage code on both sides, so an incoming renderer whose rendered BODY changed -- `--check --root .`
# going 0 to 1 on every consumer with pinned roles -- read SELF-UPDATE-OK, step 2 pushed into its own
# refusal, and the printed remedy re-ran the OLD renderer. The gate now derives the argv from the
# hook line whose exit status the hook reads, stages each side beside its own siblings, feeds both
# the ref line the push sends, and refuses an argv span it cannot resolve.
#
# STUBS, NOT THE SHIPPED SCRIPTS, so this section reads nothing outside its own world and behaves
# the same in both layouts. Each stub carries exactly the property its arm keys on; the real
# renderer and the real provenance validator are driven by the BL-456 receipt. The hook is a copy
# of the shipped hook's SHAPES (the agent-definitions function, the trunk-push pipe, the readset
# `for` list), and it is only ever SCANNED here: the consumer has no remote, so arm P never runs it.
#
#   world A (one pull, seven changed gating scripts, a clean consumer)
#     render-agent-definitions.sh  rendered body changes: bare 2,2; hook argv 0,1        -> DEFER
#     audit-rule-files.sh          second argv-dependent script: bare 1,1; hook 0,1      -> DEFER
#     derive-fixture-readsets.sh   incoming exits 1, but the hook only LISTS it          -> OK, not gating
#     validate-audit-anchors.sh    incoming fails on the pushed ref read from STDIN      -> DEFER
#     validate-artifact-paths.sh   its SIBLING artifact-path-config.sh fails at theirs   -> DEFER
#     validate-rooted.sh           hook argv span holds `$ROOT`                          -> UNDECIDED
#     validate-quiet.sh            near-miss: its `$` is after `2>`, outside the span    -> OK
#   world B (one pull, the renderer's change is a COMMENT), consumer clean and consumer drifted
#     render-agent-definitions.sh  hook argv 0,0 clean and 1,1 drifted                   -> OK both
# The drifted consumer is the discriminating input for equal-non-zero: its renderer already fails
# under the hook's argv on both sides, which is a pre-existing failure and not this pull's.
av_world "$AV/a" A clean
av_world "$AV/b" B clean
av_world "$AV/d" B drift

# PRECONDITIONS, or every arm below asserts about a world that cannot express the defect: under
# the hook's argv the renderer and the audit stub really go 0 to 1 in world A while their BARE
# runs agree, and the drifted world's renderer really fails on both sides.
AVA="$AV/a"
git -C "$AVA/dist" show "$(cat "$AVA/T"):core/scripts/render-agent-definitions.sh" > "$AV/new-render.sh"
git -C "$AVA/dist" show "$(cat "$AVA/T"):core/scripts/audit-rule-files.sh" > "$AV/new-audit.sh"
ss_assert "av-pre" \
  "render hook $(av_rc "$AVA/cons" scripts/ai-dlc/render-agent-definitions.sh '--check --root .')$(av_rc "$AVA/cons" "$AV/new-render.sh" '--check --root .') bare $(av_rc "$AVA/cons" scripts/ai-dlc/render-agent-definitions.sh)$(av_rc "$AVA/cons" "$AV/new-render.sh"); audit hook $(av_rc "$AVA/cons" scripts/ai-dlc/audit-rule-files.sh --fail-on=deterministic)$(av_rc "$AVA/cons" "$AV/new-audit.sh" --fail-on=deterministic) bare $(av_rc "$AVA/cons" scripts/ai-dlc/audit-rule-files.sh)$(av_rc "$AVA/cons" "$AV/new-audit.sh"); drift hook $(av_rc "$AV/d/cons" scripts/ai-dlc/render-agent-definitions.sh '--check --root .')" \
  "render hook 01 bare 22; audit hook 01 bare 11; drift hook 1" \
  "the worlds express the defect: the hook's argv sees each change, a bare run cannot, and the drifted renderer already fails"

AV_A="$(av_run "$GATE" "$AV/a")"
AV_B="$(av_run "$GATE" "$AV/b")"
AV_D="$(av_run "$GATE" "$AV/d")"
AV_SIG_FIX="render=SELF-UPDATE-DEFER audit=SELF-UPDATE-DEFER derive=SELF-UPDATE-OK anchors=SELF-UPDATE-DEFER paths=SELF-UPDATE-DEFER rooted=SELF-UPDATE-UNDECIDED quiet=SELF-UPDATE-OK agents=same"
ss_assert "av-signature" "$(av_sig "$AV_A")" "$AV_SIG_FIX" "world A, every arm below in one row"
ss_assert "av-render-body" "$(av_st "$AV_A" render-agent-definitions.sh)" SELF-UPDATE-DEFER \
  "a renderer whose rendered body changes is refused: under --check --root . it goes 0 to 1, though a bare run exits 2 on both sides"
ss_assert "av-render-comment" "$(av_st "$AV_B" render-agent-definitions.sh) refusals=$(av_ref "$AV_B")" "SELF-UPDATE-OK refusals=0" \
  "a renderer whose only change is a comment is OK and the pull carries no refusal at all"
ss_assert "av-render-drift" "$(av_st "$AV_D" render-agent-definitions.sh) refusals=$(av_ref "$AV_D")" "SELF-UPDATE-OK refusals=0" \
  "the same comment-only pull on a consumer whose definitions already drifted is OK: 1,1 under the hook's argv predates the pull"
ss_assert "av-second-argv" "$(av_st "$AV_A" audit-rule-files.sh)" SELF-UPDATE-DEFER \
  "a SECOND argv-dependent script: --fail-on=deterministic goes 0 to 1 where its bare default exits 1 on both sides"
ss_assert "av-not-gating" "$(av_st "$AV_A" derive-fixture-readsets.sh) $(av_has "$AV_A" derive-fixture-readsets.sh '^not gating')" "SELF-UPDATE-OK yes" \
  "a script the hook only lists in a \`for\` loop is not gating, and says so, though its incoming copy exits 1"
ss_assert "av-agents-digest" "$(av_ag "$AV_A")" same \
  "the consumer's .claude/agents is byte-identical across the gate run: the hook's write-mode line is never run"
ss_assert "av-siblings" "$(av_st "$AV_A" validate-artifact-paths.sh)" SELF-UPDATE-DEFER \
  "the incoming script runs beside its OWN siblings at theirs, where artifact-path-config.sh now fails"
ss_assert "av-stdin" "$(av_st "$AV_A" validate-audit-anchors.sh)" SELF-UPDATE-DEFER \
  "both runs are fed the ref line the push sends, built though arm P is skipped, and the incoming check fires on it"
ss_assert "av-dollar" "$(av_st "$AV_A" validate-rooted.sh) $(av_has "$AV_A" validate-rooted.sh 'cannot resolve')" "SELF-UPDATE-UNDECIDED yes" \
  "an argv span holding \$ROOT cannot be derived, so the script is UNDECIDED rather than run with a guessed argv"
ss_assert "av-dollar-nearmiss" "$(av_st "$AV_A" validate-quiet.sh)" SELF-UPDATE-OK \
  "a \$ after 2> is outside the span, so that line is derived and run, not refused"

# --- MUTANTS, each a copy of the WHOLE reconcile directory so the gate finds its siblings --------
# THE CONTROL: an unmutated copy beside its siblings reproduces world A's whole signature and the
# drifted world's OK, so every kill below is its mutation and not a copy that could not run.
AV_CTL="$(av_mut control)"
ss_assert "av-mut-control" "$(av_sig "$(av_run "$AV_CTL" "$AV/a")") drift=$(av_st "$(av_run "$AV_CTL" "$AV/d")" render-agent-definitions.sh)" \
  "$AV_SIG_FIX drift=SELF-UPDATE-OK" "an unmutated copy reproduces every verdict, so a kill below is the mutation"
# av_kill <label> <gate|""> <world> <want-signature> <why> -- the mutant's whole world signature
av_kill() {
  local got
  if [ -z "$2" ]; then got="DID-NOT-APPLY"; else got="$(av_sig "$(av_run "$2" "$3")")"; fi
  mp_killed "$1" "$got" "$4" "$5"
}
av_kill "av-mut-bare" "$(av_mut bare '  set -- $_a
' '  set --
')" "$AV/a" \
  "render=SELF-UPDATE-OK audit=SELF-UPDATE-OK derive=SELF-UPDATE-OK anchors=SELF-UPDATE-OK paths=SELF-UPDATE-DEFER rooted=SELF-UPDATE-UNDECIDED quiet=SELF-UPDATE-OK agents=same" \
  "the bare probe: every argv-dependent change reads OK again, the renderer's first among them"
av_kill "av-mut-hand" "$(av_mut hand '  set -- $_a
' '  if [ "${_s##*/}" = render-agent-definitions.sh ]; then set -- $_a; else set --; fi
')" "$AV/a" \
  "render=SELF-UPDATE-DEFER audit=SELF-UPDATE-OK derive=SELF-UPDATE-OK anchors=SELF-UPDATE-OK paths=SELF-UPDATE-DEFER rooted=SELF-UPDATE-UNDECIDED quiet=SELF-UPDATE-OK agents=same" \
  "a hand-listed renderer argv: the renderer is refused and the second argv-dependent script reads OK"
av_kill "av-mut-firstline" "$(av_mut firstline \
  "awk -F'\\t' '\$1 == \"R\" && !seen[\$3]++ {print \$3}' \"\$TMP/scan\" > \"\$TMP/argvs\"" \
  "awk -F'\\t' '\$1 == \"R\" || \$1 == \"D\" {print \$3; exit}' \"\$TMP/scan\" > \"\$TMP/argvs\"")" "$AV/a" \
  "render=SELF-UPDATE-OK audit=SELF-UPDATE-DEFER derive=SELF-UPDATE-OK anchors=SELF-UPDATE-DEFER paths=SELF-UPDATE-DEFER rooted=SELF-UPDATE-UNDECIDED quiet=SELF-UPDATE-OK agents=moved" \
  "the hook's FIRST renderer line (--root ., write mode): 0,0 reads OK and the consumer's .claude/agents is rewritten"
av_kill "av-mut-listed" "$(av_mut listed 'printf "M\t%d\tlist\n", r' 'printf "X\t%d\tlist\n", r')" "$AV/a" \
  "render=SELF-UPDATE-DEFER audit=SELF-UPDATE-DEFER derive=SELF-UPDATE-UNDECIDED anchors=SELF-UPDATE-DEFER paths=SELF-UPDATE-DEFER rooted=SELF-UPDATE-UNDECIDED quiet=SELF-UPDATE-OK agents=same" \
  "a list mention read as an underivable run: the non-gating deriver refuses the pull"
av_kill "av-mut-sibling" "$(av_mut sibling \
  'gate_run_side "$TMP/new/scripts/ai-dlc/$name" "$sc_a"; rc_new=$?' \
  'cp "$TMP/new/scripts/ai-dlc/$name" "$TMP/cur/scripts/ai-dlc/zz-$name"; gate_run_side "$TMP/cur/scripts/ai-dlc/zz-$name" "$sc_a"; rc_new=$?')" "$AV/a" \
  "render=SELF-UPDATE-DEFER audit=SELF-UPDATE-DEFER derive=SELF-UPDATE-OK anchors=SELF-UPDATE-DEFER paths=SELF-UPDATE-OK rooted=SELF-UPDATE-UNDECIDED quiet=SELF-UPDATE-OK agents=same" \
  "the incoming script staged beside the CONSUMER's siblings: theirs' failing config is never read"
av_kill "av-mut-stdin" "$(av_mut stdin '< "$TMP/refline" > /dev/null 2>&1 )' '< /dev/null > /dev/null 2>&1 )')" "$AV/a" \
  "render=SELF-UPDATE-DEFER audit=SELF-UPDATE-DEFER derive=SELF-UPDATE-OK anchors=SELF-UPDATE-OK paths=SELF-UPDATE-DEFER rooted=SELF-UPDATE-UNDECIDED quiet=SELF-UPDATE-OK agents=same" \
  "no stdin: the incoming trunk-push check never sees the pushed ref and reads OK"
av_kill "av-mut-dollar" "$(av_mut dollar '} else if (span ~ /[$`"\\*?~[]/ || span ~ /\047/) {' '} else if (span ~ /[`\\*?~[]/ || span ~ /\047/) {')" "$AV/a" \
  "render=SELF-UPDATE-DEFER audit=SELF-UPDATE-DEFER derive=SELF-UPDATE-OK anchors=SELF-UPDATE-DEFER paths=SELF-UPDATE-DEFER rooted=SELF-UPDATE-OK quiet=SELF-UPDATE-OK agents=same" \
  "an argv span holding \$ROOT run with the literal text: the underivable invocation reads OK"
# EQUAL NON-ZERO READ AS UNDECIDED: scored on the drifted world, the only one where it differs.
e="$(av_mut eqund '    if [ "$rc_cur" -ne "$rc_new" ] && [ "$rc_new" -ne 0 ]; then' '    if [ "$rc_new" -ne 0 ]; then')" \
  && got="$(av_st "$(av_run "$e" "$AV/d")" render-agent-definitions.sh)" || got="DID-NOT-APPLY"
mp_killed "av-mut-eqund" "$got" SELF-UPDATE-UNDECIDED \
  "equal non-zero under the hook's argv read as UNDECIDED: a comment-only pull is refused on a consumer whose definitions already drifted"

# --- THE REMEDY RUNS THE RENDERER THE CYCLE LEAVES INSTALLED (BL-456 claim 3) -------------------
# The filing's third claim: the hook's printed remedy re-renders with the consumer's OLD renderer, so
# the next cycle is refused again. That holds only on the OK path -- step 2 pushes, the hook refuses,
# the cycle is DISCARDED and the old renderer stays installed, so re-rendering writes the old text
# and the incoming --check fails exactly as before. On a DEFER the slice folds into the gated apply,
# which WRITES the incoming renderer before its push, so the same remedy re-renders with the incoming
# one and its --check clears. Claim 3 is therefore a consequence of claim 1's OK, not a defect of its
# own, and this arm pins that by DRIVING THE REAL APPLY: on a refusal it runs the shipped
# `apply.sh --carried-machinery-slice`, which is what step 7 runs for a deferred slice, and reads
# what apply itself reports and writes -- the renderer's RESOLVED pure-apply row, its WORKLIST
# agent-definitions row, the renderer it left installed -- then the remedy and the hook's --check
# before and after it. Nothing here writes the renderer; only apply does. The stub spells the
# remedy `--root .` where the real renderer walks up to the same root bare.
# c3_cycle <gate> <apply> <world> -> verdict, apply's rows, installed renderer, remedy, check before->after
c3_cycle() {
  local c rows v b t rc0 rc1 rr inst pa wl
  c="$(mktemp -d "$AV/c3.XXXXXX")" || return 1
  c="$c/cons"; cp -R "$3/cons" "$c" || return 1
  b="$(cat "$3/B")"; t="$(cat "$3/T")"
  rows="$(bash "$1" "$3/dist" "$b" "$t" "$c" 2>/dev/null)"
  v="$(av_st "$rows" render-agent-definitions.sh)"
  case "$v" in
    SELF-UPDATE-DEFER|SELF-UPDATE-UNDECIDED)
      printf 'version: 1.0.0\ncommit: %s\nskill_version: 1.0.0\nskill_commit: %s\ninstalled_at: 2026-01-01T00:00:00Z\nupstream: https://example.invalid/x\n' "$b" "$b" > "$c/.claude/.ai-dlc-version"
      av_git "$c" add -A >/dev/null 2>&1; av_git "$c" commit -qm stamp >/dev/null 2>&1
      rows="$(bash "$2" --carried-machinery-slice "$3/dist" "$b" "$c" "$t" 2>/dev/null)" ;;
    SELF-UPDATE-OK) rows="" ;;
    *) printf 'no-render-row'; return 0 ;;
  esac
  pa="$(printf '%s\n' "$rows" | awk -F'\t' '$1 == "RESOLVED" && $2 == "pure-apply" && $3 == "scripts/render-agent-definitions.sh" {f=1} END {print (f ? "yes" : "no")}')"
  wl="$(printf '%s\n' "$rows" | awk -F'\t' '$1 == "WORKLIST" && $2 == "agent-definitions" {f=1} END {print (f ? "yes" : "no")}')"
  if cmp -s "$AV/new-render.sh" "$c/scripts/ai-dlc/render-agent-definitions.sh"; then inst=theirs; else inst=current; fi
  ( cd "$c" && bash scripts/ai-dlc/render-agent-definitions.sh --check --root . >/dev/null 2>&1 < /dev/null ); rc0=$?
  ( cd "$c" && bash scripts/ai-dlc/render-agent-definitions.sh --root . >/dev/null 2>&1 < /dev/null ); rr=$?
  ( cd "$c" && bash scripts/ai-dlc/render-agent-definitions.sh --check --root . >/dev/null 2>&1 < /dev/null ); rc1=$?
  printf '%s pure-apply=%s worklist=%s installed=%s remedy=%s check=%s->%s' "${v#SELF-UPDATE-}" "$pa" "$wl" "$inst" "$rr" "$rc0" "$rc1"
}
C3_APPLY="$(dirname "$GATE")/apply.sh"
# PRECONDITION: world A expresses the loop. The remedy run with the OLD renderer leaves the incoming
# --check at 1; run with the incoming renderer it clears to 0. Without both, the arm below cannot
# separate a gate that leads to the loop from one that does not.
C3P="$(mktemp -d "$AV/c3p.XXXXXX")"; cp -R "$AV/a/cons" "$C3P/old"; cp -R "$AV/a/cons" "$C3P/new"
cp "$AV/new-render.sh" "$C3P/new/scripts/ai-dlc/render-agent-definitions.sh"
for c3s in old new; do ( cd "$C3P/$c3s" && bash scripts/ai-dlc/render-agent-definitions.sh --root . >/dev/null 2>&1 < /dev/null ); done
ss_assert "c3-pre" "old $(av_rc "$C3P/old" "$AV/new-render.sh" '--check --root .') new $(av_rc "$C3P/new" "$AV/new-render.sh" '--check --root .')" "old 1 new 0" \
  "the remedy clears the incoming check only when the incoming renderer is the one installed"
C3_WANT="DEFER pure-apply=yes worklist=yes installed=theirs remedy=0 check=1->0"
ss_assert "c3-remedy-after-defer" "$(c3_cycle "$GATE" "$C3_APPLY" "$AV/a")" "$C3_WANT" \
  "the gate defers; the real carried-slice apply installs theirs' renderer and reports it, names the re-render, and the remedy takes the hook's check from 1 to 0"
# THE MUTANT BREAKS THE APPLY-INSTALLS-THEIRS LEG, in a copy of the whole reconcile directory: the
# pure-apply row is still printed but the write is skipped, which is exactly a cycle whose remedy
# runs the renderer the consumer already had. The control is the same copy unmutated.
c3_apply_mut() {
  local e="$AV/c3a-$1"
  mkdir -p "$e"; cp "$(dirname "$GATE")"/*.sh "$(dirname "$GATE")"/*.md "$(dirname "$GATE")"/*.tsv "$e"/ 2>/dev/null
  [ -n "$2" ] || { printf '%s' "$e/apply.sh"; return 0; }
  python3 -c 'import sys
s = open(sys.argv[1]).read(); o, n = sys.argv[3], sys.argv[4]
if s.count(o) != 1: sys.exit(3)
open(sys.argv[2], "w").write(s.replace(o, n, 1))' "$C3_APPLY" "$e/apply.sh" "$2" "$3" 2>/dev/null || return 1
  cmp -s "$C3_APPLY" "$e/apply.sh" && return 1
  bash -n "$e/apply.sh" 2>/dev/null || return 1
  printf '%s' "$e/apply.sh"
}
c3_kill() { local got; if [ -z "$2" ]; then got="DID-NOT-APPLY"; else got="$(c3_cycle "$GATE" "$2" "$AV/a")"; fi; mp_killed "$1" "$got" "$3" "$4"; }
c3_kill "c3-mut-control" "$(c3_apply_mut control '')" "$C3_WANT" \
  "an unmutated apply.sh copy beside its siblings reaches the same cycle, so the kill below is its mutation"
c3_kill "c3-mut-nowrite" "$(c3_apply_mut nowrite 'overwrite_from_theirs "$rel" && say RESOLVED pure-apply "$rel"' 'say RESOLVED pure-apply "$rel"')" \
  "DEFER pure-apply=yes worklist=no installed=current remedy=0 check=0->0" \
  "the apply reports pure-apply but never writes theirs' renderer: the current one stays installed, no re-render is owed, and the push carries the old text"

fi
if sg hk; then
# --- THE HOOK THE PUSH RUNS IS THEIRS' WHEN THE SLICE WRITES IT (BL-456, round 2) ----------------
# The gate scanned only the consumer's CURRENT hook, and its gating set was changed scripts that hook
# invokes. When theirs' hook adds the renderer's --check step, turns a discarded `--check || true`
# into a read one, or the consumer has no renderer at all ("ADDS it"), the render row read OK; step 2
# wrote theirs' hook, git ran it on the push, the push was refused and discarded, and the next run
# read OK again. Each world is one pull whose renderer's rendered body changes; only the hook pair and
# the consumer's renderer differ.
#   hk-adds    current hook has no renderer step, theirs' runs --check            -> DEFER (was OK)
#   hk-reads   current `--check --root . || true`, theirs' reads it                -> DEFER (was OK)
#   hk-absent  both hooks run --check, the pull ADDS the renderer (absent at base
#              and on the consumer)                                                 -> DEFER (was OK)
#   hk-same    both hooks run --check identically; the change is a renderer COMMENT -> OK (near-miss:
#              the hook moved elsewhere, so theirs' hook is in force and must not refuse on its own)
hk_hook() { # hk_hook <file> <none|discard|read> <extra comment>
  { printf '#!/usr/bin/env bash\nset -uo pipefail\n# %s\n' "$3"
    case "$2" in
      discard) printf 'bash scripts/ai-dlc/render-agent-definitions.sh --check --root . || true\n' ;;
      read) printf 'agent_definitions() {\n  local out rc\n  out="$(bash scripts/ai-dlc/render-agent-definitions.sh --check --root . 2>&1)"; rc=$?\n  return "$rc"\n}\nstep "agent definitions" agent_definitions\n' ;;
    esac; } > "$1"
  chmod +x "$1"
}
hk_world() { # hk_world <dir> <base-hook> <theirs-hook> <consumer-renderer:yes|no> <theirs-renderer:body|comment>
  local w="$1"
  mkdir -p "$w/dist/core/rules" "$w/dist/core/scripts" "$w/dist/core/git-hooks" "$w/cons/.githooks" "$w/cons/scripts/ai-dlc"
  git -C "$w/dist" init -q
  printf '1.0.0\n' > "$w/dist/VERSION"; printf 'hk machinery\n' > "$w/dist/core/rules/hk.md"
  # A consumer WITHOUT a renderer is seeded against a base that has none either: the pull ADDS it.
  # Absent at base and present at the consumer's base would be a consumer DELETION, which arm C
  # carries and step 2 never writes -- a different world, with no loop in it.
  [ "$4" = yes ] && av_render "$w/dist/core/scripts/render-agent-definitions.sh" 'FIRST action before any other work.' 'renderer stub'
  hk_hook "$w/dist/core/git-hooks/pre-push" "$2" base
  av_git "$w/dist" add -A >/dev/null 2>&1; av_git "$w/dist" commit -qm base >/dev/null 2>&1
  git -C "$w/dist" rev-parse HEAD > "$w/B"
  printf '1.1.0\n' > "$w/dist/VERSION"
  if [ "$5" = body ]; then av_render "$w/dist/core/scripts/render-agent-definitions.sh" 'FIRST action, before any other work.' 'renderer stub'
  else av_render "$w/dist/core/scripts/render-agent-definitions.sh" 'FIRST action before any other work.' 'renderer stub; reworded'; fi
  hk_hook "$w/dist/core/git-hooks/pre-push" "$3" theirs
  av_git "$w/dist" add -A >/dev/null 2>&1; av_git "$w/dist" commit -qm theirs >/dev/null 2>&1
  git -C "$w/dist" rev-parse HEAD > "$w/T"
  git -C "$w/dist" show "$(cat "$w/B"):core/git-hooks/pre-push" > "$w/cons/.githooks/pre-push"; chmod +x "$w/cons/.githooks/pre-push"
  if [ "$4" = yes ]; then
    git -C "$w/dist" show "$(cat "$w/B"):core/scripts/render-agent-definitions.sh" > "$w/cons/scripts/ai-dlc/render-agent-definitions.sh"
    bash "$w/cons/scripts/ai-dlc/render-agent-definitions.sh" --root "$w/cons" >/dev/null 2>&1
  else
    printf 'keep\n' > "$w/cons/scripts/ai-dlc/.keep"
  fi
  git -C "$w/cons" init -q
  av_git "$w/cons" add -A >/dev/null 2>&1; av_git "$w/cons" commit -qm consumer >/dev/null 2>&1
}
hk_world "$AV/hk-adds" none read yes body
hk_world "$AV/hk-reads" discard read yes body
hk_world "$AV/hk-absent" read read no body
hk_world "$AV/hk-same" read read yes comment
# hk-deleted: the renderer is present at base and the consumer DELETED it. Arm C carries it, step 2
# never writes it, and the push runs no renderer -- OK, "carried". The near-miss for hk-absent: one
# property apart (present at base), and the reason the absent-copy rule is scoped to an ADDED path.
hk_world "$AV/hk-deleted" read read yes body
git -C "$AV/hk-deleted/cons" rm -q scripts/ai-dlc/render-agent-definitions.sh
av_git "$AV/hk-deleted/cons" commit -qm "consumer deleted the renderer" >/dev/null 2>&1
# PRECONDITION: in every refusing world the push that theirs' hook gates would be refused -- theirs'
# renderer installed over the consumer's tree fails its own --check -- while the hook the consumer
# runs today does not run a status-read --check that fails.
hk_pre() { # hk_pre <world> -> <theirs-renderer --check rc on the consumer tree>
  git -C "$1/dist" show "$(cat "$1/T"):core/scripts/render-agent-definitions.sh" > "$1/new-render.sh"
  av_rc "$1/cons" "$1/new-render.sh" '--check --root .'
}
ss_assert "hk-pre" "adds $(hk_pre "$AV/hk-adds") reads $(hk_pre "$AV/hk-reads") absent $(hk_pre "$AV/hk-absent") same $(hk_pre "$AV/hk-same") cur-adds $(grep -c 'render-agent-definitions' "$AV/hk-adds/cons/.githooks/pre-push")" \
  "adds 1 reads 1 absent 1 same 0 cur-adds 0" \
  "theirs' renderer fails its own --check in the three refusing worlds and passes in the near-miss; today's hook in hk-adds runs no renderer at all"
hk_sig() { # hk_sig <gate> -> one token per world
  local n out=""
  local r
  for n in adds reads absent same deleted; do
    r="$(av_run "$1" "$AV/hk-$n")"
    out="$out${out:+ }$n=$(av_st "$r" render-agent-definitions.sh | sed 's/^SELF-UPDATE-//')"
    [ "$(av_has "$r" render-agent-definitions.sh '^carried')" = yes ] && out="$out+carried"
  done
  printf '%s\n' "$out"
}
HK_SIG_FIX="adds=DEFER reads=DEFER absent=DEFER same=OK deleted=OK+carried"
ss_assert "hk-signature" "$(hk_sig "$GATE")" "$HK_SIG_FIX" \
  "the render row is judged against the hook the push will run, and an absent current copy is today's push passing"
HK_CTL="$(av_mut hk-control)"
mp_killed "hk-mut-control" "$(hk_sig "$HK_CTL")" "$HK_SIG_FIX" "an unmutated copy reproduces every hook-world verdict, so a kill below is the mutation"
hk_kill() { local got; if [ -z "$2" ]; then got="DID-NOT-APPLY"; else got="$(hk_sig "$2")"; fi; mp_killed "$1" "$got" "$3" "$4"; }
hk_kill "hk-mut-curhook" "$(av_mut hk-curhook '    HOOK="$TMP/hook-theirs"
' '    :
')" "adds= reads=OK absent=DEFER same=OK deleted=OK+carried" \
  "the gate scans only the consumer's current hook: a --check step theirs' hook adds is not gating, and one it starts reading reads as discarded"
hk_kill "hk-mut-adds" "$(av_mut hk-adds '  [ -f "$cur" ] || cur_absent=1
' '  [ -f "$cur" ] || { emit SELF-UPDATE-OK "$name" "the consumer has no current copy, so this pull ADDS it."; continue; }
')" "adds=DEFER reads=DEFER absent=OK same=OK deleted=OK+carried" \
  "an absent current copy read as \"this pull ADDS it\": a consumer with pinned roles and no renderer pushes into the renderer it was just given"
hk_kill "hk-mut-carried" "$(av_mut hk-carried '  if [ ! -f "$cur" ] && gate_has_line "${GATE_CARRIED:-}" "core/scripts/$name"; then' '  if false; then')" \
  "adds=DEFER reads=DEFER absent=DEFER same=OK deleted=DEFER" \
  "a carried script judged as though written: a consumer that deleted the renderer is refused over a copy step 2 never installs"

fi
if sg hu1 || sg hu2; then
# --- AN UNCHANGED SCRIPT THE NEW HOOK ASKS IS JUDGED BY THE COPY THE PUSH RUNS (BL-456, round 3) ---
# Theirs' hook adds a step for validate-y.sh, which the RANGE DOES NOT CHANGE. Step 2 writes only
# the range diff, so after the write the push runs the CONSUMER'S copy of it, or nothing. Judging
# it by theirs' copy read a false OK where the consumer's copy fails the new step, and a false DEFER
# where the consumer's passes or the step is guarded away. Each world's expected verdict is the
# post-write hook's own exit, asserted first as a precondition.
#   hu-lfail     consumer's y exits 1, theirs' 0, unguarded step   post-write rc 1 -> DEFER (was OK)
#   hu-lpass     consumer's y exits 0, theirs' 1                   post-write rc 0 -> OK    (was DEFER)
#   hu-gdel      consumer deleted y, step under `if [ -f … ]`      post-write rc 0 -> OK    (was DEFER)
#   hu-udel      consumer deleted y, unguarded step                post-write rc 1 -> DEFER, the row
#                says ABSENT rather than blaming theirs' copy
hu_world() { # hu_world <dir> <consumer-y:fail|pass|none> <theirs-y-rc> <guarded|bare>
  local w="$1" step
  mkdir -p "$w/dist/core/rules" "$w/dist/core/scripts" "$w/dist/core/git-hooks" "$w/cons/.githooks" "$w/cons/scripts/ai-dlc"
  git -C "$w/dist" init -q
  printf '1.0.0\n' > "$w/dist/VERSION"; printf 'hu machinery\n' > "$w/dist/core/rules/hu.md"
  printf '#!/bin/sh\nexit 0\n' > "$w/dist/core/scripts/validate-x.sh"
  printf '#!/bin/sh\n[ "${1:-}" = --strict ] || exit 2\nexit %s\n' "$3" > "$w/dist/core/scripts/validate-y.sh"
  # keeptest: today's hook already guards the run with a block, so only the GUARD moves in theirs'
  local basestep=""
  [ "$4" = keeptest ] && basestep='if [ -f scripts/ai-dlc/validate-y.sh ]; then
  bash scripts/ai-dlc/validate-y.sh --strict || fail=1
fi'
  printf '#!/usr/bin/env bash\nfail=0\nbash scripts/ai-dlc/validate-x.sh || fail=1\n%s\nexit "$fail"\n' "$basestep" > "$w/dist/core/git-hooks/pre-push"
  av_git "$w/dist" add -A >/dev/null 2>&1; av_git "$w/dist" commit -qm base >/dev/null 2>&1
  git -C "$w/dist" rev-parse HEAD > "$w/B"
  cp "$w/dist/core/git-hooks/pre-push" "$w/cons/.githooks/pre-push"; chmod +x "$w/cons/.githooks/pre-push"
  cp "$w/dist/core/scripts/validate-x.sh" "$w/cons/scripts/ai-dlc/"
  case "$2" in
    fail) printf '#!/bin/sh\n# consumer edit\nexit 1\n' > "$w/cons/scripts/ai-dlc/validate-y.sh" ;;
    pass) printf '#!/bin/sh\n# consumer edit\nexit 0\n' > "$w/cons/scripts/ai-dlc/validate-y.sh" ;;
  esac
  printf '1.1.0\n' > "$w/dist/VERSION"
  printf '#!/bin/sh\n# reworded\nexit 0\n' > "$w/dist/core/scripts/validate-x.sh"
  step='bash scripts/ai-dlc/validate-y.sh --strict || fail=1'
  case "$4" in
    guarded) step="if [ -f scripts/ai-dlc/validate-y.sh ]; then $step; fi" ;;
    andand)  step="[ -f scripts/ai-dlc/validate-y.sh ] && { $step; }" ;;
    andor)   step="[ -f scripts/ai-dlc/validate-y.sh ] && $step" ;;
    orecho)  step="[ -f scripts/ai-dlc/validate-y.sh ] || echo missing
$step" ;;
    block)   step="if [ -f scripts/ai-dlc/validate-y.sh ]; then
  $step
fi" ;;
    else)    step="if [ -f scripts/ai-dlc/validate-y.sh ]; then
  :
else
  $step
fi" ;;
    keeptest) step="[ -f scripts/ai-dlc/validate-y.sh ] || echo missing
$step" ;;
    awkif)   step="if [ -f scripts/ai-dlc/validate-y.sh ]; then
  awk '
    if (NR > 0) print
  ' /dev/null
fi
$step" ;;
  esac
  printf '#!/usr/bin/env bash\nfail=0\nbash scripts/ai-dlc/validate-x.sh || fail=1\n%s\nexit "$fail"\n' "$step" > "$w/dist/core/git-hooks/pre-push"
  av_git "$w/dist" add -A >/dev/null 2>&1; av_git "$w/dist" commit -qm theirs >/dev/null 2>&1
  git -C "$w/dist" rev-parse HEAD > "$w/T"
  git -C "$w/cons" init -q
  av_git "$w/cons" add -A >/dev/null 2>&1; av_git "$w/cons" commit -qm consumer >/dev/null 2>&1
}
hu_world "$AV/hu-lfail" fail 0 bare
hu_world "$AV/hu-lpass" pass 1 bare
hu_world "$AV/hu-gdel" none 1 guarded
hu_world "$AV/hu-udel" none 1 bare
# THE GUARD IS TIED TO THE RUN (round 4). A test of the path elsewhere in the hook guards nothing:
#   hu-orecho  `[ -f y ] || echo missing`, then an unguarded run       post-write rc 1 -> DEFER+absent
#   hu-andand  `[ -f y ] && { bash y … || fail=1; }` on one line       post-write rc 0 -> OK
#   hu-andor   `[ -f y ] && bash y … || fail=1` -- the `||` also catches
#              the TEST failing, so an absent y fails the push          post-write rc 1 -> DEFER+absent
#   hu-block   a multi-line `if [ -f y ]; then` … `fi` block            post-write rc 0 -> OK
#   hu-else    the run sits in the ELSE branch of that test             post-write rc 1 -> DEFER+absent
# hu-gdel above is the one-line `if [ -f y ]; then …; fi`, still OK.
hu_world "$AV/hu-orecho" none 1 orecho
hu_world "$AV/hu-andand" none 1 andand
hu_world "$AV/hu-andor" none 1 andor
hu_world "$AV/hu-block" none 1 block
hu_world "$AV/hu-else" none 1 else
# ROUND 5. hu-keeptest: today's hook runs y inside `if [ -f y ]`, theirs' keeps a test of y but runs
# it bare -- kind and argv unchanged, only the guard column moves, so the hook-change key must carry
# it. hu-awkif: an awk `if (` inside a guard block must not open a shell frame, or the bare run after
# the block's `fi` reads as still guarded.                              post-write rc 1 -> DEFER+absent
hu_world "$AV/hu-keeptest" none 1 keeptest
hu_world "$AV/hu-awkif" none 1 awkif
HU_WORLDS="lfail lpass gdel udel orecho andand andor block else keeptest awkif"
# PRECONDITION: the truth each world asserts. A copy of the consumer gets step 2's write -- the range
# diff and nothing else -- and theirs' hook is run on it, as git runs it on the push.
hu_post() { # hu_post <world> -> the post-write hook's exit
  local c p
  c="$(mktemp -d "$AV/hup.XXXXXX")/cons"; cp -R "$1/cons" "$c"
  git -C "$1/dist" diff --name-only "$(cat "$1/B")" "$(cat "$1/T")" > "$c.slice"
  while IFS= read -r p; do
    case "$p" in
      core/git-hooks/*) git -C "$1/dist" show "$(cat "$1/T"):$p" > "$c/.githooks/${p#core/git-hooks/}" ;;
      core/scripts/*) git -C "$1/dist" show "$(cat "$1/T"):$p" > "$c/scripts/ai-dlc/${p#core/scripts/}" ;;
    esac
  done < "$c.slice"
  ( cd "$c" && bash .githooks/pre-push origin x < /dev/null > /dev/null 2>&1 ); printf '%s' "$?"
}
hu_sig() { # hu_sig <gate> -> one token per world, `+absent` when the row names the absence
  local n r out=""
  for n in $HU_WORLDS; do
    r="$(av_run "$1" "$AV/hu-$n")"
    out="$out${out:+ }$n=$(av_st "$r" validate-y.sh | sed 's/^SELF-UPDATE-//')"
    [ "$(av_has "$r" validate-y.sh '^ABSENT')" = yes ] && out="$out+absent"
  done
  printf '%s\n' "$out"
}
HU_SIG_FIX="lfail=DEFER lpass=OK gdel=OK udel=DEFER+absent orecho=DEFER+absent andand=OK andor=DEFER+absent block=OK else=DEFER+absent keeptest=DEFER+absent awkif=DEFER+absent"
hu_kill() { local got; if [ -z "$2" ]; then got="DID-NOT-APPLY"; else got="$(hu_sig "$2")"; fi; mp_killed "$1" "$got" "$3" "$4"; }
fi
if sg hu1; then
ss_assert "hu-pre" "$(for n in $HU_WORLDS; do printf '%s=%s ' "$n" "$(hu_post "$AV/hu-$n")"; done)y-in-range=$(git -C "$AV/hu-lfail/dist" diff --name-only "$(cat "$AV/hu-lfail/B")" "$(cat "$AV/hu-lfail/T")" -- core/scripts/validate-y.sh | grep -c .)" \
  "lfail=1 lpass=0 gdel=0 udel=1 orecho=1 andand=0 andor=1 block=0 else=1 keeptest=1 awkif=1 y-in-range=0" \
  "the push theirs' hook gates fails exactly where the consumer's own copy fails or is missing unguarded, and the range never touches validate-y.sh"
ss_assert "hu-signature" "$(hu_sig "$GATE")" "$HU_SIG_FIX" \
  "an unchanged script the new hook asks is judged by the copy the push runs: the consumer's, or the hook's own guard over its absence"
mp_killed "hu-mut-control" "$(hu_sig "$(av_mut hu-control)")" "$HU_SIG_FIX" \
  "an unmutated copy reproduces all four verdicts, so a kill below is the mutation"
# KEYED ON THE LINE THAT DECIDES WHICH COPY RUNS: without it every script is judged by theirs' copy.
hu_kill "hu-mut-theirs" "$(av_mut hu-theirs '  gate_has_line "$CHANGED" "$name" || sc_written=0
' '  :
')" "lfail=OK lpass=DEFER gdel=DEFER udel=DEFER orecho=DEFER andand=DEFER andor=DEFER block=DEFER else=DEFER keeptest=DEFER awkif=DEFER" \
  "an unchanged script judged by theirs' copy: every world takes the verdict of a copy step 2 never writes"
# Each guard mutant is keyed on the one line that owns its leg, and moves only its own worlds.
HU_GUARD_LINE='  [ "$(awk -F'"'"'\t'"'"' '"'"'$1 == "R" && $4 != "guarded"'"'"' "$TMP/scan" | grep -c .)" -eq 0 ] && sc_guarded=1
'
hu_kill "hu-mut-anytest" "$(av_mut hu-anytest "$HU_GUARD_LINE" '  [ "$(awk -F'"'"'\t'"'"' '"'"'$1 == "M" && $3 == "test"'"'"' "$TMP/scan" | grep -c .)" -gt 0 ] && sc_guarded=1
')" "lfail=DEFER lpass=OK gdel=OK udel=DEFER+absent orecho=OK andand=OK andor=OK block=OK else=OK keeptest=OK awkif=OK" \
  "any existence test anywhere in the hook read as the run's guard: three pushes that fail on a missing script read OK"
hu_kill "hu-mut-noguard" "$(av_mut hu-noguard "$HU_GUARD_LINE" '  :
')" "lfail=DEFER lpass=OK gdel=DEFER+absent udel=DEFER+absent orecho=DEFER+absent andand=DEFER+absent andor=DEFER+absent block=DEFER+absent else=DEFER+absent keeptest=DEFER+absent awkif=DEFER+absent" \
  "no guard read at all: every step the post-write hook skips is refused as a missing script"
hu_kill "hu-mut-brace" "$(av_mut hu-brace '      if (pre ~ (GT "[[:space:]]*&&[[:space:]]*\\{' '      if (0 && pre ~ (GT "[[:space:]]*&&[[:space:]]*\\{')" \
  "lfail=DEFER lpass=OK gdel=OK udel=DEFER+absent orecho=DEFER+absent andand=DEFER+absent andor=DEFER+absent block=OK else=DEFER+absent keeptest=DEFER+absent awkif=DEFER+absent" \
  "the && { … } arm dropped: a step the hook skips on a missing script is refused"
fi
if sg hu2; then
hu_kill "hu-mut-andor" "$(av_mut hu-andor ' && index(tail, "||") == 0) return 1' ') return 1')" \
  "lfail=DEFER lpass=OK gdel=OK udel=DEFER+absent orecho=DEFER+absent andand=OK andor=OK block=OK else=DEFER+absent keeptest=DEFER+absent awkif=DEFER+absent" \
  "the trailing || not read: [ -f y ] && bash y || fail=1 reads guarded while the push fails on the missing script"
hu_kill "hu-mut-oneline" "$(av_mut hu-oneline '      if (match(pre, ("(^|[;[:space:]])if' '      if (0 && match(pre, ("(^|[;[:space:]])if')" \
  "lfail=DEFER lpass=OK gdel=DEFER+absent udel=DEFER+absent orecho=DEFER+absent andand=OK andor=DEFER+absent block=OK else=DEFER+absent keeptest=DEFER+absent awkif=DEFER+absent" \
  "the one-line if [ -f y ]; then …; fi arm dropped: round 3's guarded world is refused again"
hu_kill "hu-mut-block" "$(av_mut hu-block '      if (o && !f) { NIF++; IF[NIF] = (t ~' '      if (o && !f) { NIF++; IF[NIF] = 0 && (t ~')" \
  "lfail=DEFER lpass=OK gdel=OK udel=DEFER+absent orecho=DEFER+absent andand=OK andor=DEFER+absent block=DEFER+absent else=DEFER+absent keeptest= awkif=DEFER+absent" \
  "the enclosing if-block frame never guards: a multi-line guarded step is refused"
hu_kill "hu-mut-else" "$(av_mut hu-else '      if (NIF > 0 && t ~ /^[[:space:]]*(else|elif)([;[:space:]]|$)/) IF[NIF] = 0' '      if (0) IF[NIF] = 0')" \
  "lfail=DEFER lpass=OK gdel=OK udel=DEFER+absent orecho=DEFER+absent andand=OK andor=DEFER+absent block=OK else=OK keeptest=DEFER+absent awkif=DEFER+absent" \
  "else not read: a run in the branch taken when the script is MISSING reads guarded, a false OK"
# ROUND 5 MUTANTS. Each keyed on the line it reverts.
HU_KEY_NEW="    ha_new=\"\$(gate_argv_scan \"\$HOOK\" \"\$ha_n\" | awk -F'\\t' '{print \$1 \"\\t\" \$3 \"\\t\" \$4}' | sort -u)\""
HU_KEY_CUR="    [ -f \"\$HOOK_CUR\" ] && ha_cur=\"\$(gate_argv_scan \"\$HOOK_CUR\" \"\$ha_n\" | awk -F'\\t' '{print \$1 \"\\t\" \$3 \"\\t\" \$4}' | sort -u)\""
HU_KEY_NEW_OLD="    ha_new=\"\$(gate_argv_scan \"\$HOOK\" \"\$ha_n\" | awk -F'\\t' '{print \$1 \"\\t\" \$3}' | sort -u)\""
HU_KEY_CUR_OLD="    [ -f \"\$HOOK_CUR\" ] && ha_cur=\"\$(gate_argv_scan \"\$HOOK_CUR\" \"\$ha_n\" | awk -F'\\t' '{print \$1 \"\\t\" \$3}' | sort -u)\""
hu_kill "hu-mut-dropguard" "$(av_mut hu-dropguard "$HU_KEY_NEW" "$HU_KEY_NEW_OLD" "$HU_KEY_CUR" "$HU_KEY_CUR_OLD")" \
  "lfail=DEFER lpass=OK gdel=OK udel=DEFER+absent orecho=DEFER+absent andand=OK andor=DEFER+absent block=OK else=DEFER+absent keeptest= awkif=DEFER+absent" \
  "the guard column dropped from the hook-change key: a hook that keeps the test but unties it from the run asks nothing new, and y gets no row"
HU_OPEN_NEW='      o = (t ~ /^[[:space:]]*if[[:space:]]+(\[|!|[A-Za-z_.\/])/)'
hu_kill "hu-mut-awkopen" "$(av_mut hu-awkopen "$HU_OPEN_NEW" '      o = (t ~ /^[[:space:]]*if[[:space:]]/)')" \
  "lfail=DEFER lpass=OK gdel=OK udel=DEFER+absent orecho=DEFER+absent andand=OK andor=DEFER+absent block=OK else=DEFER+absent keeptest=DEFER+absent awkif=OK" \
  "an awk if ( read as a shell opener: the guard frame outlives its fi and the bare run after it reads guarded, a false OK"
# THE STACK BALANCES ON THE SHIPPED HOOK. The scan's END is re-emitted with the frame depth appended,
# once with the shipped opener and once with the old one, so the assertion proves it can see the
# imbalance it rules out.
HU_REAL=""
for cand in "$DIR/../../git-hooks/pre-push" "$DIR/../../../.githooks/pre-push"; do
  [ -f "$cand" ] && { HU_REAL="$cand"; break; }
done
[ -n "$HU_REAL" ] && echo "HERMETIC-CONSUMED $(cd "$(dirname "$HU_REAL")" && pwd -P)/pre-push"
hu_depth() { # hu_depth <gate-file> -> the if-frame depth after scanning the shipped hook
  ( eval "$(awk '/^gate_argv_scan\(\) \{/,/^\}/' "$1" | sed 's/ifpost(r) } }$/ifpost(r) }; printf "DEPTH\\t%d\\n", NIF }/')"
    gate_argv_scan "$HU_REAL" render-agent-definitions.sh ) 2>/dev/null | awk -F'\t' '$1 == "DEPTH" {print $2}'
}
HU_OLD="$AV/hu-depth-old.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read(); o, n = sys.argv[3], sys.argv[4]
if s.count(o) != 1: sys.exit(3)
open(sys.argv[2], "w").write(s.replace(o, n, 1))' "$GATE" "$HU_OLD" "$HU_OPEN_NEW" '      o = (t ~ /^[[:space:]]*if[[:space:]]/)' 2>/dev/null || : > "$HU_OLD"
HU_OLD_D="$(hu_depth "$HU_OLD")"
case "$HU_OLD_D" in ''|0|*[!0-9]*) HU_OLD_UNBAL=no ;; *) HU_OLD_UNBAL=yes ;; esac
ss_assert "hu-stack-depth" "${HU_REAL:+found} shipped=$(hu_depth "$GATE") old-opener-unbalanced=$HU_OLD_UNBAL" "found shipped=0 old-opener-unbalanced=yes" \
  "scanning the shipped pre-push ends at if-frame depth 0; the old opener test leaves it above 0 (read $HU_OLD_D), so this assertion can see the imbalance"

fi
if sg sh; then
# --- HOOK SHAPES THE SCAN MUST NOT READ AS "NOT GATING" (BL-456, tip round) ----------------------
# Each shape below is one reformat away from the real hook, and before this round the first three
# scanned as a mention or a discarded capture, so a script whose incoming copy fails read
# SELF-UPDATE-OK "not gating" -- a false OK on the bootstrapping gate. World S is one pull in which
# EVERY stub exits 0 at base and 1 at theirs under any argv, so a script the scan reads as run with
# its status read DEFERs, and one it reads as not gating says so. Only the scan separates them.
#
#   sa-assign    V=scripts/ai-dlc/sa-assign.sh; bash "$V" --k             -> UNDECIDED (was OK)
#   sa-next      capture, then `rc=$?` on the next line                   -> DEFER     (was OK)
#   sa-fnlast    f() { out="$(bash …)"; } called through step             -> DEFER     (was OK)
#   sa-fnlast2   the same with `}` opening the next line                  -> DEFER     (was OK)
#   sa-w229      the real hook's write-mode lines 229-233, verbatim       -> OK, not gating (near-miss
#                for both arms above: its next line opens with `[` and only a FIRST-token `&&` counts)
#   sa-true      bash … || true                                           -> OK, not gating (was DEFER)
#   sa-exit      bash … || exit 1   (near-miss: one word apart)           -> DEFER
#   sa-step      step "x" bash scripts/ai-dlc/…   on one line             -> DEFER     (was UNDECIDED)
#   sa-steptrue  step "x" bash … || true   (step's own `if` read it)      -> DEFER     (was UNDECIDED)
SH_SCRIPTS="sa-assign sa-next sa-fnlast sa-fnlast2 sa-w229 sa-true sa-exit sa-step sa-steptrue"
sh_world() {
  local w="$1" n
  mkdir -p "$w/dist/core/rules" "$w/dist/core/scripts" "$w/cons/.githooks" "$w/cons/scripts/ai-dlc" "$w/cons/.claude/agents"
  git -C "$w/dist" init -q
  printf '1.0.0\n' > "$w/dist/VERSION"
  printf 'sh machinery\n' > "$w/dist/core/rules/sh.md"
  for n in $SH_SCRIPTS; do
    printf '#!/bin/sh\n# %s\nexit 0\n' "$n" > "$w/dist/core/scripts/$n.sh"
    cp "$w/dist/core/scripts/$n.sh" "$w/cons/scripts/ai-dlc/$n.sh"
  done
  av_git "$w/dist" add -A >/dev/null 2>&1; av_git "$w/dist" commit -qm base >/dev/null 2>&1
  git -C "$w/dist" rev-parse HEAD > "$w/B"
  printf '1.1.0\n' > "$w/dist/VERSION"
  for n in $SH_SCRIPTS; do printf '#!/bin/sh\n# %s, incoming\nexit 1\n' "$n" > "$w/dist/core/scripts/$n.sh"; done
  av_git "$w/dist" add -A >/dev/null 2>&1; av_git "$w/dist" commit -qm theirs >/dev/null 2>&1
  git -C "$w/dist" rev-parse HEAD > "$w/T"
  printf 'definitions\n' > "$w/cons/.claude/agents/dev.md"
  printf '%s\n' '#!/usr/bin/env bash' 'set -uo pipefail' \
    'V=scripts/ai-dlc/sa-assign.sh; bash "$V" --k' \
    'nxt() {' '  out="$(bash scripts/ai-dlc/sa-next.sh --check 2>&1)"' '  rc=$?' '  return $rc' '}' \
    'step "next" nxt' \
    'fnl() { out="$(bash scripts/ai-dlc/sa-fnlast.sh --q)"; }' 'step "fnlast" fnl' \
    'fnl2() {' '  out="$(bash scripts/ai-dlc/sa-fnlast2.sh --q 2>&1)"' '}' 'step "fnlast2" fnl2' \
    'w229() {' '  local out' '  if [ ! -d .claude/agents ]; then' \
    '      out="$(bash scripts/ai-dlc/sa-w229.sh --root . 2>&1)"' \
    '      [ -d .claude/agents ] \' \
    "        && printf '   .claude/agents/ was absent (a gitignored, derived directory), so it was rendered:\\n'" \
    "      printf '%s\\n' \"\$out\"" '  fi' '  return 0' '}' 'step "w229" w229' \
    'bash scripts/ai-dlc/sa-true.sh --t || true' \
    'bash scripts/ai-dlc/sa-exit.sh --t || exit 1' \
    'step "step" bash scripts/ai-dlc/sa-step.sh --s' \
    'step "steptrue" bash scripts/ai-dlc/sa-steptrue.sh --s || true' > "$w/cons/.githooks/pre-push"
  chmod +x "$w/cons/.githooks/pre-push"
  git -C "$w/cons" init -q
  av_git "$w/cons" add -A >/dev/null 2>&1; av_git "$w/cons" commit -qm consumer >/dev/null 2>&1
}
sh_world "$AV/s"
# sh_sig <rows> -> one token per script: its status, `+ng` when an OK row says "not gating"
sh_sig() {
  local n out=""
  for n in $SH_SCRIPTS; do
    out="$out${out:+ }${n#sa-}=$(av_st "$1" "$n.sh" | sed 's/^SELF-UPDATE-//')"
    [ "$(av_has "$1" "$n.sh" '^not gating')" = yes ] && out="$out+ng"
  done
  printf '%s\n' "$out"
}
# PRECONDITIONS: the hook carries the real write-mode lines byte-for-byte, and every stub really
# goes 0 to 1, so a scan reading a line as run-and-read would DEFER it.
# THE REAL HOOK TOO, in whichever layout this runs: the distribution's core/git-hooks/pre-push, or
# a consumer's installed .githooks/pre-push. Its write-mode renderer line must scan D and its
# --check line R, so the real-hook shape the near-miss copies is the one the scan actually sees.
SH_HOOK=""
for cand in "$DIR/../../git-hooks/pre-push" "$DIR/../../../.githooks/pre-push"; do
  [ -f "$cand" ] && { SH_HOOK="$cand"; break; }
done
[ -n "$SH_HOOK" ] && echo "HERMETIC-CONSUMED $(cd "$(dirname "$SH_HOOK")" && pwd -P)/pre-push"
SH_RH="$( (eval "$(awk '/^gate_argv_scan\(\) \{/,/^\}/' "$GATE")"; gate_argv_scan "$SH_HOOK" render-agent-definitions.sh) 2>/dev/null \
  | awk -F'\t' '$1 == "D" || $1 == "R" {printf "%s%s[%s]", (n++ ? " " : ""), $1, $3}')"
ss_assert "sh-real-229" "${SH_HOOK:+found} $SH_RH" "found D[--root .] R[--check --root .]" \
  "the real hook's write-mode renderer capture stays D and its --check capture stays R"
SH_229='      out="$(bash scripts/ai-dlc/render-agent-definitions.sh --root . 2>&1)"'
SH_W="$(grep -n -A2 -F -- "$SH_229" "$SH_HOOK" 2>/dev/null | sed 's/^[0-9]*[:-]//' | sed 's/render-agent-definitions/sa-w229/')"
SH_S3="$(grep -n -A2 -F -- 'sa-w229.sh --root' "$AV/s/cons/.githooks/pre-push" | sed 's/^[0-9]*[:-]//')"
ss_assert "sh-pre-229" "$([ -n "$SH_W" ] && [ "$SH_W" = "$SH_S3" ] && echo same)" "same" \
  "world S carries the real hook's write-mode capture and the two lines after it verbatim, only the script name differs"
ss_assert "sh-pre-rc" \
  "$(av_rc "$AV/s/cons" scripts/ai-dlc/sa-next.sh)$(git -C "$AV/s/dist" show "$(cat "$AV/s/T"):core/scripts/sa-next.sh" | sh; printf '%s' "$?")" \
  "01" "every stub exits 0 at base and 1 at theirs"
SH_SIG_FIX="assign=UNDECIDED next=DEFER fnlast=DEFER fnlast2=DEFER w229=OK+ng true=OK+ng exit=DEFER step=DEFER steptrue=DEFER"
SH_S="$(av_run "$GATE" "$AV/s")"
ss_assert "sh-signature" "$(sh_sig "$SH_S")" "$SH_SIG_FIX" "world S, every shape arm below in one row"
ss_assert "sh-assign" "$(av_st "$SH_S" sa-assign.sh) $(av_has "$SH_S" sa-assign.sh 'through a variable')" "SELF-UPDATE-UNDECIDED yes" \
  "a path assigned to a variable and run through it is UNDECIDED, never a mention read as not gating"
ss_assert "sh-next-line" "$(av_st "$SH_S" sa-next.sh)" SELF-UPDATE-DEFER \
  "a capture whose status the NEXT line reads (rc=\$?) is run, and its incoming failure defers"
ss_assert "sh-fn-last" "$(av_st "$SH_S" sa-fnlast.sh) $(av_st "$SH_S" sa-fnlast2.sh)" "SELF-UPDATE-DEFER SELF-UPDATE-DEFER" \
  "a capture that is a function body's last statement is returned by the function, in both brace layouts"
ss_assert "sh-229-stays-D" "$(av_st "$SH_S" sa-w229.sh) $(av_has "$SH_S" sa-w229.sh 'line [0-9]* run with its status discarded')" "SELF-UPDATE-OK yes" \
  "the real write-mode line stays discarded: the line after it opens with [ and reads the test's status, not the capture's"
ss_assert "sh-true-tail" "$(av_st "$SH_S" sa-true.sh) $(av_has "$SH_S" sa-true.sh '^not gating') $(av_st "$SH_S" sa-exit.sh)" "SELF-UPDATE-OK yes SELF-UPDATE-DEFER" \
  "a trailing || true discards the status; || exit 1, one word apart, reads it"
ss_assert "sh-step" "$(av_st "$SH_S" sa-step.sh) $(av_st "$SH_S" sa-steptrue.sh)" "SELF-UPDATE-DEFER SELF-UPDATE-DEFER" \
  "a single-line step \"x\" bash … is a run step reads, with or without a trailing || true"
# THE CONTROL: an unmutated copy reproduces world S's whole signature.
SH_CTL="$(av_mut sh-control)"
ss_assert "sh-mut-control" "$(sh_sig "$(av_run "$SH_CTL" "$AV/s")")" "$SH_SIG_FIX" \
  "an unmutated copy reproduces every world-S verdict, so a kill below is the mutation"
# sh_kill <label> <gate|""> <want-signature> <why>
sh_kill() {
  local got
  if [ -z "$2" ]; then got="DID-NOT-APPLY"; else got="$(sh_sig "$(av_run "$2" "$AV/s")")"; fi
  mp_killed "$1" "$got" "$3" "$4"
}
sh_kill "sh-mut-assign" "$(av_mut sh-assign '{ printf "X\t%d\tthe path is assigned' '{ printf "M\t%d\tthe path is assigned')" \
  "assign=OK+ng next=DEFER fnlast=DEFER fnlast2=DEFER w229=OK+ng true=OK+ng exit=DEFER step=DEFER steptrue=DEFER" \
  "an assignment read as a mention: the script run through \$V is not gating and reads OK"
sh_kill "sh-mut-nextline" "$(av_mut sh-nextline 'readnext = (index(nx, "$?") > 0 || nx ~ /^[[:space:]]*(&&|\|\|)/)' 'readnext = 0')" \
  "assign=UNDECIDED next=OK+ng fnlast=DEFER fnlast2=DEFER w229=OK+ng true=OK+ng exit=DEFER step=DEFER steptrue=DEFER" \
  "the next line is not read: a capture checked by rc=\$? reads as discarded and OK"
sh_kill "sh-mut-fnlast" "$(av_mut sh-fnlast 'lastinfn = (capture && (ct ~ /^}/ || (ct == "" && nx ~ /^[[:space:]]*}/)))' 'lastinfn = 0')" \
  "assign=UNDECIDED next=DEFER fnlast=OK+ng fnlast2=OK+ng w229=OK+ng true=OK+ng exit=DEFER step=DEFER steptrue=DEFER" \
  "a function's last-statement capture read as discarded: both brace layouts read OK"
sh_kill "sh-mut-true" "$(av_mut sh-true 'truetail = (index(tt, "||") == 0 && index(tt, "&&") == 0 && index(tt, "$?") == 0)' 'truetail = 0')" \
  "assign=UNDECIDED next=DEFER fnlast=DEFER fnlast2=DEFER w229=OK+ng true=DEFER exit=DEFER step=DEFER steptrue=DEFER" \
  "|| true read as a status reader: a script whose failure the hook ignores refuses the pull"
sh_kill "sh-mut-step" "$(av_mut sh-step 'stepped = (pre ~' 'stepped = 0 && (pre ~')" \
  "assign=UNDECIDED next=DEFER fnlast=DEFER fnlast2=DEFER w229=OK+ng true=OK+ng exit=DEFER step=UNDECIDED steptrue=UNDECIDED" \
  "no step prefix: a single-line step run is an unknown shape and UNDECIDED"
sh_kill "sh-mut-steptrue" "$(av_mut sh-steptrue 'if (!stepped && match(tt,' 'if (match(tt,')" \
  "assign=UNDECIDED next=DEFER fnlast=DEFER fnlast2=DEFER w229=OK+ng true=OK+ng exit=DEFER step=DEFER steptrue=OK+ng" \
  "|| true after step read as discarding: the status step already read is lost and the script reads OK"
fi
rm -rf "$AV"

echo "$NAME: shard $GROUP ran $ASSERTIONS assertions"
echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of $ASSERTIONS assertions wrong."
  exit 1
fi
echo "PASS: all $ASSERTIONS assertions correct."
exit 0
