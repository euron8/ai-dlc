#!/usr/bin/env bash
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# Pin the story evidence scaffold, the Strategy Test IDs table, and Check 21's reading of it.
#
# SUBJECT. Five shipped files, one contract:
#   - stories-test-strategy.md, Story-Authoring Pre-Flight Checklist item (c): every story
#     file carries four evidence headings, one of them the `## Strategy Test IDs` table with
#     a closed `Kind` vocabulary; Step 5 item 3 writes one row per lettered strategy case.
#   - gate-validation.md Check 21: the citation set IS that table; a case letter with no row
#     fails; a strategy with no id table is a SKIP that says so, never a PASS.
#   - dev.md `## QA Handoff Evidence`: the full-collection run WITH its counts before the
#     handoff message, the dependency setup that makes that run reproducible from a fresh
#     detached worktree recorded beside it, the four sections filled, every table row resolved.
#   - qa.md `## Handoff Evidence Precondition`: QA rejects before validating when that
#     evidence, the dependency setup included, is absent.
#   - code-reviewer.md Field Verification: the baseline-fixture sweep when a diff changes a
#     handler's result shape.
#   - implementation.md's pre-gate commit-presence paragraph and sprint-review.md §4: both
#     run validate-handoff-evidence.sh (handoff mode before gate 1, --strategy before the
#     sprint-review gate's Seam B).
# Most of this is prose the executing agents read, so the prose is the mechanism and this
# fixture pins it on the section that carries it. The mechanical part —
# validate-handoff-evidence.sh, which refuses a capture with no command line, an
# uncommitted mutation-RED capture, a glob cited as a capture, an empty Strategy Test IDs
# cell and a `test` cell whose node does not resolve — is driven below against seeded git
# worlds, each offender one property away from a clean world that carries the near-misses.
#
# WHY THE DEV AND QA ARMS SHADOW BEFORE THEY READ. The reference consumer shadows
# `team-roles/dev.md#Workflow Per Task` and `team-roles/qa.md#Validation Checklist` with
# override bodies of its own, so text placed in either section never reaches that consumer's
# dev or QA. Each arm therefore replaces those two sections with a stub first, the way the
# loader does, and only then looks. Text moved into a shadowed section still sits in the
# file, which a whole-file grep would accept; these arms must not.
#
# IN PROCESS. validate-handoff-evidence.sh, record-only-diff.sh and sprint-status.sh are loadable (each ends in a
# BASH_SOURCE guard before its one main call), and every cell asks them through he-inproc.sh's he_run: the
# validator's he_main in a subshell, its record-only-diff.sh and sprint-status.sh calls answered by THOSE FILES'
# own ro_main / ss_main in further subshells, so no bash is started per verdict. The receipts in this directory
# (receipt-bl809/815/843/845.sh) are NOT driven here: their control calls and BL-979's RAN SET run in
# story-evidence-receipts (shipped), so the pool runs them beside this fixture. They stay in this
# directory because their verify: lines name these paths. EQUIV is the one
# end-to-end run per distinct CLI outcome and holds the in-process answer
# byte-identical to `bash <subject>`; INPROC asserts no subject call fell back to a process.
#
# Exit 0 iff every arm holds; 1 on a finding; 2 (FIXTURE BROKEN) when a subject file cannot
# be located. An absent subject is never green.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/world.sh"

# THE GROUP DEAL. One fixture family, one table. The shipped run (no argument, group a) drives the arms whose verdict
# can depend on PLACEMENT: the located subjects, the capability guard, the prose sections as installed, the installed
# validator in place and the --list-captures read through it. Every other arm drives a COPY of the validator
# (world.sh's mk_tree), whose bytes are the same in both layouts, so it runs once, in the distribution, in the dist-only
# siblings story-evidence-scaffold-<g>, each of which execs this file with --group <g>. `--group all` runs every block
# (the authoring run). GDEAL is the one table, `<block> <group>`, one row per block. A row and its gsel call site
# must pair, and a group and its driver directory must pair:
# gjoin, run below in every dist-only group, fails on a block nobody runs, on one dealt twice and on a group
# with no driver.
GROUP=a
if [ "${1:-}" = "--group" ]; then
  [ "$#" -ge 2 ] || { echo "story-evidence-scaffold: --group needs a value" >&2; exit 2; }
  GROUP="$2"; shift 2
fi
GDEAL='
cap a
prose a
inplace a
listcaps a
b3 a
gjoin-probe a
handoff b
equiv b
gate2 b
dar-missing b
dar-grammar b
dar-n g
range c
replay c
abs-sym c
run-record c
conventions c
pointer c
receipts c
sibling c
redline c
waiver g
run-filter d
'
gsel() { # <block> -> 0 when this run drives it
  case "$GROUP" in all) return 0 ;; esac
  case "$GDEAL" in *"
$1 $GROUP
"*) return 0 ;; esac
  return 1
}
# gjoin <deal text> <run.sh> <fixtures dir>: one finding per line; exit 0 when there is none.
gjoin() {
  local deal="$1" runsh="$2" fxd="$3" g d n=0 f gw
  gw="$(mktemp -d "${TMPDIR:-/tmp}/gjoin.XXXXXX")" || { echo "gjoin: could not make a work directory"; return 1; }
  awk '/^[[:space:]]*#/ { next }
    $1 == "if" && $2 == "gsel" { s = $3; sub(/;$/, "", s); print s; next }
    $1 == "gsel" && $2 ~ /^[a-z]/ { print $2 }' "$runsh" | sort -u > "$gw/sites"
  awk 'NF == 2 { print $1 }' <<<"$deal" | sort > "$gw/names"
  uniq "$gw/names" > "$gw/namesu"
  if [ ! -s "$gw/sites" ] || [ ! -s "$gw/names" ]; then echo "gjoin: no call sites or no deal rows were read"; rm -rf "$gw"; return 1; fi
  for f in $(awk 'NR == FNR { k[$0] = 1; next } !($0 in k)' "$gw/namesu" "$gw/sites"); do echo "undealt: block $f has a call site and no row in GDEAL"; n=$((n + 1)); done
  for f in $(awk 'NR == FNR { k[$0] = 1; next } !($0 in k)' "$gw/sites" "$gw/namesu"); do echo "dangling: GDEAL row $f has no call site"; n=$((n + 1)); done
  for f in $(uniq -d "$gw/names"); do echo "dealt twice: block $f has more than one row"; n=$((n + 1)); done
  for g in $(awk 'NF == 2 && $2 != "a" { print $2 }' <<<"$deal" | sort -u); do
    d="$fxd/story-evidence-scaffold-$g"
    if ! grep -q -- "--group $g" "$d/run.sh" 2>/dev/null; then echo "no driver: group $g has no $d/run.sh running --group $g"; n=$((n + 1))
    elif [ ! -s "$d/.dist-only" ]; then echo "no marker: group $g's $d/.dist-only is absent or empty"; n=$((n + 1)); fi
  done
  for d in "$fxd"/story-evidence-scaffold-*; do
    [ -d "$d" ] || continue
    g="${d##*-}"
    awk -v g="$g" 'NF == 2 && $2 == g { f = 1 } END { exit f ? 0 : 1 }' <<<"$deal" || { echo "orphan: $d is dealt no block"; n=$((n + 1)); }
  done
  rm -rf "$gw"
  [ "$n" -eq 0 ]
}

STS="$(locate skills/ai-dlc/steps/stories-test-strategy.md)" || STS=""
GV="$(locate skills/ai-dlc/steps/gate-validation.md)" || GV=""
DEV="$(locate team-roles/dev.md)" || DEV=""
QA="$(locate team-roles/qa.md)" || QA=""
CR="$(locate team-roles/code-reviewer.md)" || CR=""
IMP="$(locate skills/ai-dlc/steps/implementation.md)" || IMP=""
SR="$(locate skills/ai-dlc/steps/sprint-review.md)" || SR=""
# HE, SCHEMA and SSH are located by world.sh.
# The prose subjects are read by the prose arms (and B3) only; a group without them neither requires nor reports them.
SUBJ="HE SCHEMA SSH"; gsel prose && SUBJ="STS GV DEV QA CR IMP SR HE SCHEMA SSH"
for v in $SUBJ; do
  eval "p=\${$v}"
  if [ -z "$p" ]; then
    echo "story-evidence-scaffold: FIXTURE BROKEN -- could not locate subject $v in either layout (core/ or .claude/). An absent subject is not a passing one." >&2
    exit 2
  fi
done

SUBJP="schemas/sprint-status.json scripts/validate-handoff-evidence.sh scripts/sprint-status.sh"
gsel prose && SUBJP="skills/ai-dlc/steps/stories-test-strategy.md skills/ai-dlc/steps/gate-validation.md team-roles/dev.md team-roles/qa.md team-roles/code-reviewer.md team-roles/appendix/code-reviewer-api-fields.md skills/ai-dlc/steps/implementation.md skills/ai-dlc/steps/sprint-review.md $SUBJP"
for p in $SUBJP; do
  echo "HERMETIC-CONSUMED core/$p"
done
# BL-768: the validator's run-record arms read record-only-diff.sh beside it (absent: exit 2, UNEVALUABLE),
# so it is a subject the fixture cannot pass without.
if [ -f "$(dirname "$HE")/record-only-diff.sh" ]; then echo "HERMETIC-CONSUMED core/scripts/record-only-diff.sh"
else echo "story-evidence-scaffold: FIXTURE BROKEN -- record-only-diff.sh is not beside $HE" >&2; exit 2; fi

# CAPGUARD-BEGIN
# THE HOST CAPABILITY, decided by LAYOUT (BL-942). The distribution needs an awk that ABORTS on a non-UTF-8
# byte under a UTF-8 locale (world.sh's UTF8_LOCALE probe; BSD awk does, gawk and mawk do not). On a consumer
# the host is not ours to assume, so it stands down. In the distribution that stand-down would move the
# counted start total with the box, so the distribution refuses, FIXTURE BROKEN, exit 2, before the first arm
# (a refused run carries 1 counted row, run.sh itself; hermetic-run.sh applies no J3 to an rc-2 run).
# The layout is this directory's POSITION, never a walk-up for marker directories.
# derive_layout <fixture dir> -> sets LAYOUT to dist, consumer or NEITHER
derive_layout() {
  local fname="${1##*/}" d
  LAYOUT=NEITHER
  d="$(dirname "$1")"
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    if [ "$d/core/fixtures/$fname" = "$1" ]; then LAYOUT=dist; return 0; fi
    if [ "$d/tests/fixtures/$fname" = "$1" ]; then LAYOUT=consumer; return 0; fi
    d="$(dirname "$d")"
  done
  return 0
}
# cap_awk_where -> the awk this run resolves, with the file a farm symlink points at
cap_awk_where() {
  local a; a="$(command -v awk)" || { printf 'no awk on PATH'; return 0; }
  if [ -L "$a" ]; then printf '%s -> %s' "$a" "$(readlink "$a")"; else printf '%s' "$a"; fi
}
# cap_guard -> 0, or the refusal on stdout and 2. Reads LAYOUT and UTF8_LOCALE.
cap_guard() {
  [ "$LAYOUT" = dist ] || return 0
  [ -n "$UTF8_LOCALE" ] && return 0
  printf 'story-evidence-scaffold: FIXTURE BROKEN -- capability absent: no UTF-8 locale makes this awk abort on a non-UTF-8 byte (%s). Either that awk does not abort on a Latin-1 byte under en_US.UTF-8 or C.UTF-8 (gawk and mawk do not; BSD awk does), or neither locale exists. In the distribution a missing capability is a broken fixture, not a skip: its arms would not run, and the counted start total would move with the box. Remedy: put an awk that aborts on an invalid byte under a UTF-8 locale (the macOS /usr/bin/awk) first on the tool path, and install or enable en_US.UTF-8 so `locale -a` lists it.\n' "$(cap_awk_where)"
  return 2
}
# CAPGUARD-END
# THE CALL REGION, from the line after CAPGUARD-END through CAPCALL-END. The cap_call cells below evaluate exactly
# these lines, so a call that is deleted, disabled, hidden in a heredoc, preceded by an override or moved past the
# marker is seen by its BEHAVIOUR, not its text. UTF8_LOCALE is world.sh's probe, set before this region.
derive_layout "$DIR"
if [ "$LAYOUT" = NEITHER ]; then
  echo "story-evidence-scaffold: FIXTURE BROKEN -- layout: $DIR is neither <root>/core/fixtures/story-evidence-scaffold (distribution) nor <root>/tests/fixtures/story-evidence-scaffold (consumer), so whether a missing capability refuses or skips is undecidable" >&2
  exit 2
fi
echo "layout: $LAYOUT (position form)"
cap_guard >&2 || exit 2
# CAPCALL-END

WORK="$(mktemp -d "${TMPDIR:-/tmp}/story-evidence.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
# he-inproc.sh appends every subject call it could NOT answer in process here; the INPROC arm reads it.
export UT_FALLBACK_LOG="$WORK/.fallback"; : > "$UT_FALLBACK_LOG"
# shellcheck source=/dev/null
. "$DIR/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }

# THE GROUP JOIN, in every dist-only group (b-g, and `all`), whose inputs.decl declares the sibling drivers. Group a
# ships, and a consumer carries no sibling directory, so a declares none and does not run it.
if [ "$GROUP" != a ]; then
  if gj="$(gjoin "$GDEAL" "$DIR/run.sh" "$DIR/..")"; then
    ok "GROUP JOIN: every block has one GDEAL row and one call site, and every group but a has its dist-only driver directory"
  else
    while IFS= read -r l; do bad "GROUP JOIN: $l"; done <<<"$gj"
  fi
fi
# The join's own probe: a clean seed reads no finding and each offender, one property away, reads exactly its own
# (a gjoin that prints nothing fails every offender cell). A commented call site must not count.
if gsel gjoin-probe; then
  GJ="$WORK/gj"; gjn=0
  mkdir -p "$GJ/fx/story-evidence-scaffold-b" "$GJ/fx2/story-evidence-scaffold-b" || { echo "FIXTURE ERROR: gjoin probe could not build its tree" >&2; exit 2; }
  printf 'if gsel aa; then\nfi\nif gsel bb; then\nfi\nif gsel cc; then\nfi\n# if gsel commented; then\n' > "$GJ/run.sh"
  for gd in fx fx2; do printf '#!/bin/bash\nexec bash "$IMPL" --group b "$@"\n' > "$GJ/$gd/story-evidence-scaffold-b/run.sh"; done
  printf 'a reason\n' > "$GJ/fx/story-evidence-scaffold-b/.dist-only"; : > "$GJ/fx2/story-evidence-scaffold-b/.dist-only"
  GJD='
aa a
bb b
cc b
'
  gj_ctl="$(gjoin "$GJD" "$GJ/run.sh" "$GJ/fx")"; gj_rc=$?
  gj_want() { # <label> <deal> <fixtures dir> <token>
    local o r
    o="$(gjoin "$2" "$GJ/run.sh" "$3")"; r=$?
    if [ "$r" = 1 ] && [ "$(grep -c . <<<"$o")" = 1 ] && grep -qF -- "$4" <<<"$o"; then gjn=$((gjn + 1))
    else bad "GROUP JOIN PROBE $1: want exactly one finding naming [$4], got rc $r [$o]"; fi
  }
  gj_want undealt "$(grep -v '^bb ' <<<"$GJD")" "$GJ/fx" 'undealt: block bb'
  gj_want dangling "$GJD
dd b" "$GJ/fx" 'dangling: GDEAL row dd'
  gj_want twice "$GJD
aa b" "$GJ/fx" 'dealt twice: block aa'
  gj_want nodriver "$(sed 's/^bb b$/bb c/' <<<"$GJD")" "$GJ/fx" 'no driver: group c'
  gj_want nomarker "$GJD" "$GJ/fx2" "no marker: group b's"
  gj_want orphan "$(sed 's/ b$/ a/' <<<"$GJD")" "$GJ/fx" 'orphan:'
  if [ "$gj_rc" = 0 ] && [ -z "$gj_ctl" ] && [ "$gjn" = 6 ]; then
    ok "GROUP JOIN PROBE: a clean seed reads no finding; an undealt block, a dangling row, a block dealt twice, a group with no driver, a driver with no marker and a driver dealt nothing each read exactly their own; a commented call site is not read"
  else bad "GROUP JOIN PROBE: the clean seed read rc $gj_rc [$gj_ctl] and $gjn of 6 offenders fired"; fi
fi

if gsel cap; then
# THE GUARD'S OWN CELLS. The CAPGUARD span is extracted and evaluated in a subshell with the probe overridden,
# so the refusal is seen to fire on a box whose awk DOES abort; no cell starts a counted process.
cap_span() { awk '/^# CAPGUARD-BEGIN$/ { f = 1; next } /^# CAPGUARD-END$/ { f = 0 } f' "$DIR/run.sh"; }
capcell() { # <span> <layout> <utf8 locale> -> "<rc>|<output>"
  ( eval "$1" || exit 9
    cap_awk_where() { printf 'PROBE-AWK'; }
    LAYOUT="$2"; UTF8_LOCALE="$3"
    o="$(cap_guard 2>&1)"; printf '%s|%s' "$?" "$o" )
}
laycell() { ( eval "$1" || exit 9; derive_layout "$2"; printf '%s' "$LAYOUT" ); }
CAP_SPAN="$(cap_span)"
case "$CAP_SPAN" in *"cap_guard()"*"derive_layout()"*|*"derive_layout()"*"cap_guard()"*) ;;
  *) echo "story-evidence-scaffold: FIXTURE BROKEN -- the CAPGUARD span is empty or lost cap_guard/derive_layout" >&2; exit 2 ;; esac
r="$(capcell "$CAP_SPAN" dist "")"
if [ "${r%%|*}" = 2 ] && grep -qF 'capability absent: no UTF-8 locale makes this awk abort on a non-UTF-8 byte (PROBE-AWK)' <<<"$r" \
   && grep -qF 'or neither locale exists' <<<"$r"; then
  ok "cap_dist_awk -- in the distribution, an awk that never aborts refuses (exit 2) naming both causes, the awk and the remedy"
else bad "cap_dist_awk -- in the distribution, a non-aborting awk did not refuse with the named causes (got ${r%%|*}: ${r#*|})"; fi
r="$(capcell "$CAP_SPAN" consumer "")"
if [ "$r" = "0|" ]; then ok "cap_consumer -- on a consumer, a non-aborting awk passes the guard silently (the guard stands down)"
else bad "cap_consumer -- on a consumer the guard did not stand down (got ${r%%|*}: ${r#*|})"; fi
r="$(capcell "$CAP_SPAN" dist en_US.UTF-8)"
if [ "$r" = "0|" ]; then ok "cap_dist_present -- in the distribution, an aborting awk passes the guard"
else bad "cap_dist_present -- the guard refused an awk that aborts (got ${r%%|*}: ${r#*|})"; fi
# THE CALL SITE, BY BEHAVIOUR. cap_region <file text> prints the lines after CAPGUARD-END through CAPCALL-END. callcell
# evaluates the span and then that region in a subshell, with the awk report overridden, UTF8_LOCALE forced and DIR
# set to a distribution path, so the region's own derive_layout derives dist. No bash is started.
# callcell <file text> <utf8 locale> -> "<rc>|<output>"
cap_region() { awk '/^# CAPGUARD-END$/ { f = 1; next } f { print } f && /^# CAPCALL-END$/ { exit }' <<<"$1"; }
callcell() {
  ( local_span="$(awk '/^# CAPGUARD-BEGIN$/ { f = 1; next } /^# CAPGUARD-END$/ { f = 0 } f' <<<"$1")"
    local_reg="$(cap_region "$1")"
    case "$local_reg" in *"# CAPCALL-END") ;; *) printf '9|no CAPCALL-END after CAPGUARD-END'; exit 0 ;; esac
    eval "$local_span" || { printf '9|span did not evaluate'; exit 0; }
    cap_awk_where() { printf 'PROBE-AWK'; }
    UTF8_LOCALE="$2"; DIR=/x/r/core/fixtures/story-evidence-scaffold
    o="$(eval "$local_reg" 2>&1)"; printf '%s|%s' "$?" "$o" )
}
CC_SELF="$(cat "$DIR/run.sh")"
r="$(callcell "$CC_SELF" "")"
if [ "${r%%|*}" = 2 ] && grep -qF 'capability absent: no UTF-8 locale makes this awk abort on a non-UTF-8 byte (PROBE-AWK)' <<<"$r" && grep -qF 'layout: dist' <<<"$r"; then
  ok "cap_called -- the shipped call region, evaluated with a non-aborting awk in the distribution, refuses (exit 2) naming it"
else bad "cap_called -- the shipped call region did not refuse a non-aborting awk in the distribution (got ${r%%|*}: ${r#*|})"; fi
r="$(callcell "$CC_SELF" en_US.UTF-8)"
if [ "$r" = "0|layout: dist (position form)" ]; then ok "cap_called_present -- the shipped call region with an aborting awk runs through (exit 0)"
else bad "cap_called_present -- the shipped call region refused an aborting awk (got ${r%%|*}: ${r#*|})"; fi
if [ "$(laycell "$CAP_SPAN" /x/r/core/fixtures/story-evidence-scaffold)" = dist ]; then ok "lay_dist -- <root>/core/fixtures/<name> derives dist"
else bad "lay_dist -- <root>/core/fixtures/<name> did not derive dist"; fi
if [ "$(laycell "$CAP_SPAN" /x/r/tests/fixtures/story-evidence-scaffold)" = consumer ]; then ok "lay_consumer -- <root>/tests/fixtures/<name> derives consumer"
else bad "lay_consumer -- <root>/tests/fixtures/<name> did not derive consumer"; fi
if [ "$(laycell "$CAP_SPAN" /x/r/fixtures/story-evidence-scaffold)" = NEITHER ]; then ok "lay_neither -- a path in neither layout derives NEITHER, never a default"
else bad "lay_neither -- a path in neither layout did not derive NEITHER"; fi
fi

echo "story-evidence-scaffold: subjects $STS $GV $DEV $QA $CR $IMP $SR"

h3() { # <file> <heading regex> -> body of that ### section, heading excluded
  awk -v h="$2" '$0 ~ h {on=1; next} on && /^### /{exit} on{print}' "$1"
}
h2() { # <file> <exact ## heading text> -> body of that ## section, heading excluded
  awk -v h="$2" '$0 == h {on=1; next} on && /^## /{exit} on{print}' "$1"
}
shadow() { # <file> <exact ## heading text> -> the file with that section body replaced
  awk -v h="$2" '$0 == h {print; print "(shadowed by a consumer override)"; on=1; next}
                 on && /^## /{on=0} !on{print}' "$1"
}
flat() { tr '\n' ' ' | sed -e 's/\*\*//g' -e 's/[[:space:]][[:space:]]*/ /g'; }
has() { case "$1" in *"$2"*) return 0 ;; esac; return 1; }

COUNTS='collected / passed / failed / deselected / skipped / xfailed counts'
# The dependency-setup row: the dev records it, the QA precondition REJECTs without it. A part
# QA's own worktree runs "the setup the dev's QA Handoff Evidence records" (qa.md `## As a
# Shard`, implementation.md Gate-2 dispatch), so a dev list without this row leaves that reader
# with nothing to run. Each phrase is the row's own wording in its own section.
SETUP_DEV='the canonical dependency setup that makes that run reproducible from a fresh detached worktree: the exact invocation and its working directory, or `none` with the reason'
SETUP_QA='the canonical dependency setup that makes it reproducible from a fresh detached worktree, as the exact invocation and its working directory, or `none` with the reason'

REBIND='re-binds every `## Strategy Test IDs` cell naming the old node, across all story files'
EVS="$(sed -n "s/^EV_SENTINEL='\(.*\)'\$/\1/p" "$HE")"
CAPHDR='opens with `$ <the exact command>` on its first line and a line carrying `head: <full sha>`'

# check <sts> <gv> <dev> <qa> <cr> <imp> <sr> -> one line per failing arm; nothing when every
# arm holds. Presence-shaped throughout: every arm demands a string APPEAR in its own section.
check() {
  local sts="$1" gv="$2" dev="$3" qa="$4" cr="$5" imp="$6" sr="$7" b fl hd
  b="$(h3 "$sts" '^### Story-Authoring Pre-Flight Checklist$')"
  if [ -z "$b" ]; then echo "SECTION pre-flight: could not be isolated"; else
    fl="$(flat <<<"$b")"
    for hd in 'Production Integrity Tests' 'Smoke Test Updates' 'Rename Verification' 'Strategy Test IDs'; do
      grep -qF -- "- \`## $hd\`" <<<"$b" || echo "SCAFFOLD: '## $hd' is not a required heading in the Pre-Flight Checklist"
    done
    has "$fl" '`Kind` is exactly one of `test`, `predicate`, `deploy-time`' \
      || echo "SCAFFOLD: the closed Kind vocabulary is absent from the Pre-Flight Checklist"
    has "$fl" "$REBIND" \
      || echo "REBIND-STS: the Pre-Flight Rename Verification item does not re-bind every cell naming a renamed node"
  fi
  b="$(h3 "$sts" '^### 5\. Test Strategy$')"
  if [ -z "$b" ]; then echo "SECTION step 5: could not be isolated"; else
    fl="$(flat <<<"$b")"
    has "$fl" 'one row per lettered case' || echo "BIND: Step 5 does not write one table row per lettered strategy case"
  fi
  b="$(h3 "$gv" '^### 21\. ')"
  if [ -z "$b" ]; then echo "SECTION check 21: could not be isolated"; else
    fl="$(flat <<<"$b")"
    { has "$fl" 'The citation set is each story file'"'"'s `## Strategy Test IDs` table' \
      && has "$fl" "A Dev Agent Record's prose mention of a test is not a citation"; } \
      || echo "C21SET: Check 21 does not name the Strategy Test IDs table as its citation set"
    has "$fl" 'A case letter with no row' || echo "C21LETTER: Check 21 does not fail a case letter with no row"
    { has "$fl" 'SKIP, saying so:' && has "$fl" 'it is never a PASS'; } \
      || echo "C21SKIP: Check 21 lets a strategy with no id table read as other than a stated SKIP"
  fi
  shadow "$dev" '## Workflow Per Task' > "$WORK/.dev.shadowed"
  b="$(h2 "$WORK/.dev.shadowed" '## QA Handoff Evidence')"
  fl="$(flat <<<"$b")"
  { has "$fl" "$COUNTS" && has "$fl" 'before the handoff message' && has "$fl" '`## Strategy Test IDs`'; } \
    || echo "DEV: after the consumer's Workflow Per Task shadow, dev.md carries no full-collection-with-counts handoff requirement"
  has "$fl" "$SETUP_DEV" \
    || echo "DEV: setup -- after the consumer's Workflow Per Task shadow, dev.md's handoff evidence records no dependency setup beside the full-collection run"
  has "$fl" "$REBIND" \
    || echo "DEV: rebind -- dev.md's handoff evidence does not re-bind every Strategy Test IDs cell a rename touches"
  { has "$fl" "$CAPHDR" && has "$fl" 'Every mutation-RED capture you cite is committed'; } \
    || echo "DEV: capture -- dev.md's handoff evidence prescribes no capture header or no committed RED capture"
  # BL-768: the validator's LEGACY gate keys on this phrase in the INSTALLED dev.md, so a dev.md that
  # loses it switches the run-record arms off on every consumer. The phrase is read off the validator.
  { [ -n "$EVS" ] && has "$fl" "$EVS" && has "$fl" '`Full-collection run: none, <reason>` is allowed ONLY when every path'; } \
    || echo "DEV: label -- dev.md's handoff evidence does not prescribe the column-0 run-record labels the validator keys on"
  b="$(awk '/^\*\*Pre-gate commit-presence check\.\*\*/{on=1} on && /^$/{exit} on{print}' "$imp")"
  fl="$(flat <<<"$b")"
  { has "$fl" 'program also runs the handoff-evidence validator and its `--strategy` arm'; } \
    || echo "WIRE-IMP: implementation.md's pre-gate check does not run validate-handoff-evidence.sh in both modes"
  { has "$fl" '`status-not-review`' && has "$fl" '`status-yaml-mismatch`' && has "$fl" '`heading-demoted`' \
    && has "$fl" 'A `SKIP STATUS (<reason>)` line' \
    && has "$fl" '`dar-missing` for a story whose `## Dev Agent Record` is absent' \
    && has "$fl" 'a one-line DAR carrying `lead (self-executed`'; } \
    || echo "WIRE-BK: implementation.md's pre-gate paragraph does not name the status, row, heading and dar-missing refusals, the dar-missing remedy and the SKIP STATUS line"
  # BL-845: the smoke surface is defined once, in Check 11's bold paragraph, and the gate-2 go-signal
  # runs --smoke before QA is dispatched.
  b="$(h3 "$gv" '^### 11\. ')"
  fl="$(flat <<<"$b")"
  { grep -q '^\*\*Smoke surface\.\*\* ' <<<"$b" && has "$fl" 'tracked `docs/smoke-surface.txt`, one git pathspec per line' \
    && has "$fl" 'a lone `none` declaring' && has "$fl" "It is read at the story's base"; } \
    || echo "C11SURF: Check 11 does not define the smoke surface in its **Smoke surface.** paragraph"
  has "$fl" 'are enforced by `validate-handoff-evidence.sh` at every gate-1 handoff and at the gate-2 go-signal (`--smoke`)' \
    || echo "C11MECH: Check 11 does not say its two mechanical sub-clauses are enforced by validate-handoff-evidence.sh"
  b="$(awk '/^\*\*Gate-2 dispatch: the validation partitions/{on=1} on && /^$/{exit} on{print}' "$imp")"
  fl="$(flat <<<"$b")"
  { has "$fl" 'before any QA is dispatched, `gate-transition.sh <story> 2 <flags>` runs the `--smoke` arm of the handoff-evidence validator' \
    && has "$fl" 'Exit 1 refuses the go-signal'; } \
    || echo "WIRE-SMOKE: implementation.md's gate-2 dispatch does not run --smoke before QA is dispatched"
  b="$(h3 "$sr" '^### 4\. Gate Validation and Proceed$')"
  fl="$(flat <<<"$b")"
  has "$fl" 'validate-handoff-evidence.sh --strategy HEAD <every story file of this sprint>' \
    || echo "WIRE-SR: sprint-review §4 does not run validate-handoff-evidence.sh --strategy before the gate"
  shadow "$qa" '## Validation Checklist' > "$WORK/.qa.shadowed"
  b="$(h2 "$WORK/.qa.shadowed" '## Handoff Evidence Precondition')"
  fl="$(flat <<<"$b")"
  { has "$fl" "$COUNTS" && has "$fl" 'REJECT without validating further'; } \
    || echo "QA: after the consumer's Validation Checklist shadow, qa.md carries no handoff-evidence precondition"
  has "$fl" "$SETUP_QA" \
    || echo "QA: setup -- after the consumer's Validation Checklist shadow, qa.md does not REJECT a handoff missing the dev's dependency setup"
  # The section points at appendix/code-reviewer-api-fields.md, which holds the sweep paragraph whole: read both.
  b="$(h2 "$cr" '## Field Verification (API-Consuming Stories)'
       [ ! -f "$(dirname "$cr")/appendix/code-reviewer-api-fields.md" ] || cat "$(dirname "$cr")/appendix/code-reviewer-api-fields.md")"
  fl="$(flat <<<"$b")"
  has "$fl" "Baseline-fixture sweep when a diff changes a handler's result shape" \
    || echo "CR: code-reviewer Field Verification has no baseline-fixture sweep"
}

if gsel prose; then
# --- the subject -------------------------------------------------------------
out="$(check "$STS" "$GV" "$DEV" "$QA" "$CR" "$IMP" "$SR")"
if [ -z "$out" ]; then
  ok "scaffold, table vocabulary, Step 5 binding, Check 21 citation set / letter / SKIP, dev and qa handoff evidence past the consumer shadows, code-reviewer sweep, rename re-bind, capture header, pre-gate and sprint-review wiring"
else
  while IFS= read -r l; do bad "$l"; done <<<"$out"
fi

[ "${1:-}" = "--probe-only" ] && { [ "$fails" -eq 0 ] && exit 0; exit 1; }
if ( cd / && bash "$DIR/run.sh" --probe-only ) >/dev/null 2>&1; then
  ok "CWD: the fixture resolves its subjects from / as well as from the repo root"
else
  bad "CWD: run from / the fixture could not resolve or pass its subjects"
fi

fi

# --- validate-handoff-evidence.sh, driven ---------------------------------------
# The worlds, the case table, the verdict function and the vector live in world.sh. The
# BATTERY over this validator has been retired; this fixture keeps the control vector, the IN PLACE arm, the range and sibling-exit arms.
WORLDS_OK=1
if [ "$WORLDS_OK" -eq 1 ] && ! HECTL="$(mk_tree control)"; then
  WORLDS_OK=0; bad "FIXTURE BROKEN: could not build the control tree (scripts dir + schema), or sprint-status.sh is not beside the validator in it"
fi
if [ "$WORLDS_OK" -eq 1 ]; then
. "$DIR/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
# PRE-WRAP CONSUMER GATE (BL-878): the validator is sourced below (he_ro_label) and a pre-wrap file would run its body.
# Neither half is SKIP (FIXTURE BROKEN in the distribution, exit 0 on a consumer); exactly one half FAILS.
grep -qxF 'he_main() {' "$HECTL"; _wg1=$?
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$HECTL"; _wg2=$?
[ "$_wg1" -le 1 ] && [ "$_wg2" -le 1 ] || { echo "FIXTURE ERROR: cannot read $HECTL (grep exit $_wg1/$_wg2)" >&2; exit 2; }
case "$_wg1$_wg2" in
  00) : ;;
  11) echo "SKIP: story-evidence-scaffold: $HECTL predates the in-process wrap"; fx_skip_exit "$DIR" ;;
  *) bad "$HECTL carries one half of the in-process wrap (he_main line: rc $_wg1, column-0 source guard: rc $_wg2) -- a respelled subject this fixture cannot drive"
     report_end story-evidence-scaffold ;;
esac
fi
if [ "$WORLDS_OK" -eq 1 ]; then
if gsel handoff; then
  se_need $(for c in $CASES; do printf '%s ' "${c%%:*}"; done)
  got="$(vector "$HECTL")"
  if [ "$got" = "$WANT" ]; then
    ok "HANDOFF/STRATEGY: each offender refused by its own arm only (no-command, red-untracked, glob-cited, empty-cell, node-missing, status-not-review, status-yaml-mismatch, heading-demoted twice); the rename fails then passes after the re-bind; every near-miss quiet, the no-yaml world prints SKIP STATUS; the head WARN exits 0"
  else
    bad "HANDOFF/STRATEGY: verdict vector differs -- want [$WANT] got [$got] for [$CASES]"
  fi
fi
if gsel equiv; then
  se_need clean nocmd yamlmis empty fccode untracked
  # EQUIV: every cell below asks the subjects IN PROCESS (he-inproc.sh). This arm is the seam's proof and the
  # fixture's one END-TO-END run per distinct CLI outcome: each row runs
  # `bash <subject> <args>` and he_run/ro_run/ss_run on the SAME input, and stdout+stderr and the exit code
  # must be byte-identical. Rows: the validator's handoff refusal (1), pass (0) and UNEVALUABLE (2), strategy
  # 1/0, --gate2, --list-captures, --render-dar and its --check refusal, --smoke; record-only-diff.sh's paths
  # 1/0 and none-reason 0/1/2; sprint-status.sh's story-status over a mismatching and an untracked story.
  # Each refusing row's output must differ from its passing twin's, so the comparison cannot pass on two
  # identical answers.
  RO_SH="$(dirname "$HECTL")/record-only-diff.sh"; SS_SH="$(dirname "$HECTL")/sprint-status.sh"
  eq_row() { # <label> <fn> <subject> <args...>  -> appends "<label> <rc>" or "<label> DIFF" to $WORK/eq.rows
    local l="$1" fn="$2" urc crc
    shift 2
    "$fn" "$@" > "$WORK/eq.$l.u" 2>&1; urc=$?
    FXCELL="cli-$l" bash "$@" > "$WORK/eq.$l.c" 2>&1; crc=$?
    if cmp -s "$WORK/eq.$l.u" "$WORK/eq.$l.c" && [ "$urc" = "$crc" ]; then echo "$l $urc" >> "$WORK/eq.rows"
    else echo "$l DIFF($urc/$crc)" >> "$WORK/eq.rows"; fi
  }
  : > "$WORK/eq.rows"
  wc_="$WORK/world-clean"; wn_="$WORK/world-nocmd"; wy_="$WORK/world-yamlmis"; we_="$WORK/world-empty"; wf_="$WORK/world-fccode"
  eq_row h-refuse he_run "$HECTL" -C "$wn_" "$STORY" "$(cat "$wn_/.B")" "$(cat "$wn_/.T")"
  eq_row h-pass he_run "$HECTL" -C "$wc_" "$STORY" "$(cat "$wc_/.B")" "$(cat "$wc_/.T")"
  eq_row h-uneval he_run "$HECTL" -C "$wc_" "$STORY" "$(cat "$wc_/.B")" no-such-ref
  eq_row s-refuse he_run "$HECTL" -C "$we_" --strategy "$(cat "$we_/.T")" "$STORY"
  eq_row s-pass he_run "$HECTL" -C "$wc_" --strategy "$(cat "$wc_/.T")" "$STORY"
  eq_row g2 he_run "$HECTL" -C "$wy_" --gate2 "$STORY" "$(cat "$wy_/.B")" "$(cat "$wy_/.T")"
  eq_row lc he_run "$HECTL" -C "$wc_" --list-captures "$STORY" "$(cat "$wc_/.T")"
  eq_row rd he_run "$HECTL" -C "$wc_" --render-dar "$STORY" "$(cat "$wc_/.T")"
  eq_row rdc-refuse he_run "$HECTL" -C "$wc_" --render-dar "$STORY" "$(cat "$wc_/.T")" --check
  eq_row sm he_run "$HECTL" -C "$wc_" --smoke "$STORY" "$(cat "$wc_/.B")" "$(cat "$wc_/.T")"
  eq_row ro-paths-refuse ro_run "$RO_SH" paths -C "$wf_" "$STORY" "$(cat "$wf_/.B")" "$(cat "$wf_/.T")"
  eq_row ro-paths-pass ro_run "$RO_SH" paths -C "$wf_" "$STORY" "$(cat "$wf_/.T")" "$(cat "$wf_/.T")"
  eq_row ro-none-reason ro_run "$RO_SH" none-reason 'none, a record-only rework'
  eq_row ro-none-bare ro_run "$RO_SH" none-reason 'none'
  eq_row ro-none-not ro_run "$RO_SH" none-reason 'see dev report'
  eq_row ss-mismatch ss_run "$SS_SH" story-status --ref "$(cat "$wy_/.T")" --root "$wy_" "$STORY"
  eq_row ss-untracked ss_run "$SS_SH" story-status --ref "$(cat "$WORK/world-untracked/.T")" --root "$WORK/world-untracked" "$STORY"
  # rl-hit / rl-miss: render_dar's Full-collection label read is he_ro_label (the validator sources
  # record-only-diff.sh and calls ro_main, no bash start); it must answer as `bash record-only-diff.sh label` does on
  # a document whose label matches and on one where it does not (one cli cell per input).
  printf '%s\n' '## QA Handoff Evidence' '' '- Full-collection run: `pytest -q` (12 passed)' > "$WORK/rl.hit"
  printf '%s\n' '## QA Handoff Evidence' '' '- Smoke run: none, no runnable surface' > "$WORK/rl.miss"
  for rl_k in hit miss; do
    ( _UT_HE="$HECTL"; _UT_RO="$RO_SH"; _ut_fresh; fx_inproc "$_UT_HE" && . "$_UT_HE" || exit 2
      he_ro_label "$_UT_RO" 'Full-collection run:' ) < "$WORK/rl.$rl_k" > "$WORK/eq.rl-$rl_k.u" 2>&1; urc=$?
    FXCELL="cli-ro-label-$rl_k" bash "$RO_SH" label 'Full-collection run:' < "$WORK/rl.$rl_k" > "$WORK/eq.rl-$rl_k.c" 2>&1; crc=$?
    if cmp -s "$WORK/eq.rl-$rl_k.u" "$WORK/eq.rl-$rl_k.c" && [ "$urc" = "$crc" ]; then echo "rl-$rl_k $urc" >> "$WORK/eq.rows"
    else echo "rl-$rl_k DIFF($urc/$crc)" >> "$WORK/eq.rows"; fi
  done
  EQWANT='h-refuse 1 h-pass 0 h-uneval 2 s-refuse 1 s-pass 0 g2 0 lc 0 rd 0 rdc-refuse 1 sm 0 ro-paths-refuse 1 ro-paths-pass 0 ro-none-reason 0 ro-none-bare 1 ro-none-not 2 ss-mismatch 0 ss-untracked 0 rl-hit 0 rl-miss 1'
  got="$(tr '\n' ' ' < "$WORK/eq.rows")"; got="${got% }"
  if [ "$got" = "$EQWANT" ] && ! cmp -s "$WORK/eq.h-refuse.c" "$WORK/eq.h-pass.c" && ! cmp -s "$WORK/eq.s-refuse.c" "$WORK/eq.s-pass.c" \
     && ! cmp -s "$WORK/eq.ro-paths-refuse.c" "$WORK/eq.ro-paths-pass.c" && ! cmp -s "$WORK/eq.ss-mismatch.c" "$WORK/eq.ss-untracked.c" \
     && grep -qxF '`pytest -q` (12 passed)' "$WORK/eq.rl-hit.c" \
     && grep -q '^REFUSED no-command ' "$WORK/eq.h-refuse.c" && grep -q '^row	ready-for-dev	' "$WORK/eq.ss-mismatch.c"; then
    ok "EQUIV: in process and by CLI, byte-identical output and exit on every row, each refusal differing from its pass (handoff 1/0/2, strategy 1/0, --gate2, --list-captures, --render-dar and its --check refusal, --smoke; record-only-diff.sh paths 1/0 and none-reason 0/1/2; sprint-status.sh story-status twice; the validator's in-process record-only-diff.sh label read 0/1)"
  else
    bad "EQUIV: want [$EQWANT] with each refusal differing from its pass, got [$got]"
  fi
fi
if gsel inplace; then
  se_need yamlmis noyaml
  # The SHIPPED validator, in place, beside its real sibling: the control tree above is a copy.
  got="$(verdict "$HE" "$WORK/world-yamlmis" h) $(verdict "$HE" "$WORK/world-noyaml" h)"
  if [ "$got" = "1:status-yaml-mismatch,:W 0::W:S" ]; then
    ok "IN PLACE: the shipped validator reaches its own sprint-status.sh (a row mismatch refuses, a missing yaml prints SKIP STATUS)"
  else
    bad "IN PLACE: the shipped validator did not reach its sibling -- want [1:status-yaml-mismatch,:W 0::W:S] got [$got]"
  fi
fi
if gsel gate2; then
  se_need yamlmis
  # --gate2 (arm h skipped at a gate-2 go-signal sha). The seeded offender is world-yamlmis, which arm (h)
  # refuses. g2_vec prints, for a script: the flagged run's "<rc>:<refusals>:<SKIP STATUS (--gate2 line seen y/n)>"
  # then the unflagged control's.
  g2_vec() { # <script> [unflagged] -> the flagged run's "<rc>:<refusals>:<SKIP STATUS (--gate2 line seen y/n)>"; with a 2nd arg, the unflagged control's
    local s="$1" w="$WORK/world-yamlmis" o rc
    if [ -n "${2:-}" ]; then o="$(he_run "$s" -C "$w" "$STORY" "$(cat "$w/.B")" "$(cat "$w/.T")" 2>/dev/null)"; rc=$?
    else o="$(he_run "$s" -C "$w" --gate2 "$STORY" "$(cat "$w/.B")" "$(cat "$w/.T")" 2>/dev/null)"; rc=$?; fi
    printf '%s:%s:%s' "$rc" "$(awk '/^REFUSED /{print $2}' <<<"$o" | tr '\n' ',')" "$(grep -qF 'SKIP STATUS (--gate2' <<<"$o" && echo y || echo n)"
  }
  # The unflagged control is read once, on the control validator.
  G2WANT='0::y'; G2CTL='1:status-yaml-mismatch,:n'
  got="$(g2_vec "$HECTL") $(g2_vec "$HECTL" unflagged)"
  if [ "$got" = "$G2WANT $G2CTL" ]; then ok "GATE2: with --gate2 the row-mismatch story prints SKIP STATUS (--gate2 ...) and is not refused for (h); without it the same story is still refused status-yaml-mismatch"
  else bad "GATE2: want [$G2WANT $G2CTL] got [$got]"; fi
fi
# The DAR arms share one vector reader and its wants (DAR-GRAMMAR and DAR-N read them in whichever group drives them).
DAR_WORLDS='daroff darfence darph darphok darself clean'
DARWANT='1:R:absent 1:R:absent 1:R:empty 0:- 0:- 0:-'
dar_vec() { # <script>
  local s="$1" v o="" k
  for v in $DAR_WORLDS; do
    verdict "$s" "$WORK/world-$v" h > /dev/null
    k="$(awk '/^(REFUSED|WARN) dar-missing / { t = (/^REFUSED/) ? "R" : "W"; if (/ is absent at /) print t ":absent"; else if (/ is empty at /) print t ":empty"; else print t ":?" }' <<<"$VERDICT_OUT" | tr '\n' ',')"
    k="${k%,}"
    o="$o $VERDICT_RC:${k:--}"
  done
  printf '%s' "${o# }"
}
DARG_WORLDS='darfill darsub darmus dartbd dartodo dartodob darlbl'
DARGWANT='0:- 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty'
if gsel dar-missing; then
  se_need clean
  # (p) DAR-MISSING, a REFUSAL (exit 1). dar_vec reads, per world, "<rc>:<R|W>:<absent|empty>" off the
  # `REFUSED dar-missing` / `WARN dar-missing` line, or "<rc>:-" when neither prints. Refused: daroff
  # (heading deleted) and darfence (heading only inside a fence) absent; darph (graph's placeholder,
  # comment and blank-table template) empty. Passing twins, exit 0: darphok (the same plus one real
  # line), darself (the same plus ONLY the lead's one-line `lead (self-executed` DAR, the remedy the
  # refusal names) and clean (a filled DAR).
  if build_world "$WORK/world-daroff" daroff && build_world "$WORK/world-darfence" darfence \
     && build_world "$WORK/world-darph" darph && build_world "$WORK/world-darphok" darphok \
     && build_world "$WORK/world-darself" darself; then
    got="$(dar_vec "$HECTL")"
    if [ "$got" = "$DARWANT" ]; then ok "DAR-MISSING: a deleted and a fenced-only Dev Agent Record heading are REFUSED absent and a section of template placeholders REFUSED empty, all exit 1; the same section with one real line, with only the lead's one-line 'lead (self-executed' DAR, and the filled DAR pass with exit 0"
    else bad "DAR-MISSING: want [$DARWANT] got [$got] for [$DAR_WORLDS]"; fi
  else
    bad "FIXTURE BROKEN: could not seed the dar-missing worlds"
  fi
fi
if gsel dar-grammar; then
  # (p) the fence and skeleton grammar. darfill (a DAR filled only inside a fence) passes; darsub, darmus, dartbd,
  # dartodo, dartodob and darlbl (a section holding only subheadings, a {{...}} token, TBD, TODO, [TODO], or labels
  # with nothing after the colon) are REFUSED empty.
  if build_world "$WORK/world-darfill" darfill && build_world "$WORK/world-darsub" darsub \
     && build_world "$WORK/world-darmus" darmus && build_world "$WORK/world-dartbd" dartbd \
     && build_world "$WORK/world-dartodo" dartodo && build_world "$WORK/world-dartodob" dartodob \
     && build_world "$WORK/world-darlbl" darlbl; then
    got="$(DAR_WORLDS="$DARG_WORLDS" dar_vec "$HECTL")"
    if [ "$got" = "$DARGWANT" ]; then ok "DAR-GRAMMAR: a Dev Agent Record filled only inside a code fence passes with exit 0; one holding only subheadings, a {{...}} token, TBD, TODO, [TODO] or labels with no value is REFUSED empty, exit 1"
    else bad "DAR-GRAMMAR: want [$DARGWANT] got [$got] for [$DARG_WORLDS]"; fi
  else
    bad "FIXTURE BROKEN: could not seed the dar grammar worlds"
  fi
fi
if gsel dar-n; then
  # (p) BL-510 N1-N3. N1: darn1c / darn1d (a `###` line valued after a colon / a spaced dash) pass; darn1ph /
  # darn1tbd (valued with a {{...}} token / TBD) stay REFUSED empty. N2: darn2b `- TBD`, darn2k `- {{...}}`,
  # darn2n `1. TODO` and darn2s `* {{...}}` REFUSED empty; darn2r `- Model: <value>` passes. N3: daropen (```) and
  # dartopen (~~~) over a token with the rest of the story inside the open fence, and daropenr (a real line in a
  # fence open to EOF) REFUSED empty; darclosed (a real line in a closed fence) passes. N4, `###` values only:
  # darn4dash `: -`, darn4em `: —`, darn4see `- see above`, darn4below `- see below`, darn4hnone `- none`,
  # darn4en `– none`, darn4dot `: None.` and darn4pfx `: – N/A`, darn4enbare `: –`, darn4emnone `: — none` and darn4hynone `: - none` REFUSED empty, one per branch of the rule;
  # darn4nm (`- none of ...`) and darn4seenm (`- wired X; see above`, the `^` anchor) pass, and so do the two
  # base-behaviour regressions darn4pl (a plain `- none` line) and darn4fence (`none` in a closed fence).
  DARN_WORLDS='darn1c darn1d darn1ph darn1tbd darn2b darn2k darn2n darn2r darn2s darn4dash darn4em darn4see darn4below darn4hnone darn4en darn4dot darn4pfx darn4enbare darn4emnone darn4hynone darn4nm darn4seenm darn4pl darn4fence daropen dartopen daropenr darclosed'
  DARNWANT='0:- 0:- 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 0:- 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 0:- 0:- 0:- 0:- 1:R:empty 1:R:empty 1:R:empty 0:-'
  darn_ok=1
  for v in $DARN_WORLDS; do build_world "$WORK/world-$v" "$v" || darn_ok=0; done
  if [ "$darn_ok" -eq 1 ]; then
    got="$(DAR_WORLDS="$DARN_WORLDS" dar_vec "$HECTL")"
    if [ "$got" = "$DARNWANT" ]; then ok "DAR-N: a ### line valued after a colon or a spaced dash, a ### value opening none or carrying see above later, a bulleted real value, a plain - none line, none in a closed fence and a real line in a closed fence pass; a ### value that is a {{...}} token, TBD, a bare dash, N/A, none or see above / below, a bulleted - TBD / - {{...}} / * {{...}} / 1. TODO, and a fence left open (backtick or tilde, mid-file or to EOF) are REFUSED empty"
    else bad "DAR-N: want [$DARNWANT] got [$got] for [$DARN_WORLDS]"; fi
  else
    bad "FIXTURE BROKEN: could not seed the BL-510 dar worlds"
  fi
fi
if gsel range; then
  se_need clean
  # The range warning: base == frozen and a base that is not an ancestor of frozen each WARN
  # (exit 0, never a refusal); the normal range carries neither.
  range_vec() { # <script> -> "<eq rc>:<eq kinds> <rev rc>:<rev kinds> <normal kinds>"
    local s="$1" w="$WORK/world-clean" o rc a b n
    o="$(he_run "$s" -C "$w" "$STORY" "$(cat "$w/.T")" "$(cat "$w/.T")" 2>/dev/null)"; rc=$?
    a="$rc:$(awk '/^WARN range-/{print $2}' <<<"$o" | tr '\n' ',')"
    o="$(he_run "$s" -C "$w" "$STORY" "$(cat "$w/.T")" "$(cat "$w/.B")" 2>/dev/null)"; rc=$?
    b="$rc:$(awk '/^WARN range-/{print $2}' <<<"$o" | tr '\n' ',')"
    o="$(he_run "$s" -C "$w" "$STORY" "$(cat "$w/.B")" "$(cat "$w/.T")" 2>/dev/null)"
    n="n:$(awk '/^WARN range-/{print $2}' <<<"$o" | tr '\n' ',')"
    printf '%s %s %s' "$a" "$b" "$n"
  }
  RWANT='0:range-empty:, 0:range-base:, n:'
  got="$(range_vec "$HECTL")"
  if [ "$got" = "$RWANT" ]; then ok "RANGE: base == frozen and a non-ancestor base each WARN and exit 0; the story's own range warns nothing"
  else bad "RANGE: want [$RWANT] got [$got]"; fi
fi

if gsel replay; then
  se_need rpfirst rps319 rpok rphead rpu8
  # (j) replay-preamble and the replay block's head:. rp_vec reads the four (j) worlds and, from
  # rphead, which head WARN each capture gets: rp-red-head's first `head:` (above the block) is the
  # commit frozen only adds captures to, so a reader of THAT sha warns nothing, and the block's own
  # `head:` is the base, which warns head-tree. rp-red-fallback's block carries no `head:`, so the
  # one above it is read (head-tree), never head-missing.
  rp_vec() { # <script>
    local s="$1" o w="$WORK/world-rphead" hh hf
    o="$(he_run "$s" -C "$w" "$STORY" "$(cat "$w/.B")" "$(cat "$w/.T")" 2>/dev/null)"
    hh="$(awk '$1=="WARN" && $3=="test-results/rp-red-head.txt:"{print $2}' <<<"$o" | tr '\n' ',')"
    hf="$(awk '$1=="WARN" && $3=="test-results/rp-red-fallback.txt:"{print $2}' <<<"$o" | tr '\n' ',')"
    printf '%s %s %s %s head=%s fallback=%s u8=%s' "$(verdict "$s" "$WORK/world-rpfirst" h)" "$(verdict "$s" "$WORK/world-rps319" h)" \
      "$(verdict "$s" "$WORK/world-rpok" h)" "$(verdict "$s" "$WORK/world-rphead" h)" "${hh%,}" "${hf%,}" "$(verdict "$s" "$WORK/world-rpu8" h)"
  }
  RPWANT='1:replay-preamble,:W 1:replay-preamble,:W 0::W 0::W head=head-tree fallback=head-tree u8=1:replay-preamble,:W'
  got="$(rp_vec "$HECTL")"
  if [ "$got" = "$RPWANT" ]; then ok "REPLAY-PREAMBLE: a hand '\$ ' above the script's own refuses (with and without a second '\$ '), a replay at line 1 and the script's '\$ ' right above the replay are accepted, and head: is read from the replay block, falling back to the first head: when the block has none"
  else bad "REPLAY-PREAMBLE: want [$RPWANT] got [$got]"; fi
fi

if gsel abs-sym; then
  se_need clean empty
  # ABSOLUTE STORY PATH (BL-770). norm_story turns every story argument into one toplevel-relative
  # path in both modes. Cells, in order: handoff on the clean world with the story absolute and
  # physical; the same through a symlinked alias of the world (a second spelling of one directory,
  # which a textual `${STORY#$REPO/}` strip leaves absolute); a linked worktree of that world given
  # its own absolute story path (0); the same worktree given the MAIN world's absolute path, which
  # is outside its toplevel (2, where a textual strip reads it); a relative path climbing out of the
  # tree; `<world>/lnk/../x.md` with `lnk` an untracked symlink out of the tree, whose PHYSICAL
  # parent holds a readable x.md (0.909.0's escape: it must exit 2, never read that file); strategy
  # mode, absolute, with an empty cell only in the WORKING TREE (the committed story is clean, so
  # 0); strategy mode, absolute, with the empty cell committed (world-empty, 1). Before the fix the
  # first two refused story-untracked, the two escapes ran, and the working-tree cell read 1.
  ABSW="$WORK/world-absdirty"
  if build_world "$ABSW" clean && mkdir -p "$WORK/abs-out" && ln -s "$WORK/abs-out" "$ABSW/lnk" \
     && ln -s "$WORK/world-clean" "$WORK/alias-clean" && cp "$WORK/world-clean/$STORY" "$WORK/x.md" \
     && printf '| TX | z | test |  |\n' >> "$ABSW/$STORY" \
     && gitw "$WORK/world-clean" worktree add -q --detach "$WORK/wt-clean" "$(cat "$WORK/world-clean/.T")"; then
    abs_vec() { # <script>
      local s="$1" c="$WORK/world-clean" pc pe pw a o rc out=""
      pc="$(cd -P "$c" && pwd -P)"; pe="$(cd -P "$WORK/world-empty" && pwd -P)"
      pw="$(cd -P "$WORK/wt-clean" && pwd -P)"
      # <repo> <story>: the main world physical and aliased, the linked worktree's own absolute path,
      # and the main world's absolute path handed to the linked worktree (outside its toplevel).
      for a in "$c|$pc/$STORY" "$c|$WORK/alias-clean/$STORY" "$WORK/wt-clean|$pw/$STORY" "$WORK/wt-clean|$pc/$STORY"; do
        o="$(he_run "$s" -C "${a%%|*}" "${a#*|}" "$(cat "$c/.B")" "$(cat "$c/.T")" 2>/dev/null)"; rc=$?
        out="$out $rc:$(awk '/^REFUSED /{print $2}' <<<"$o" | tr '\n' ',')"
      done
      he_run "$s" -C "$c" "stories/../../x.md" "$(cat "$c/.B")" "$(cat "$c/.T")" >/dev/null 2>&1; out="$out climb=$?"
      he_run "$s" -C "$ABSW" "$ABSW/lnk/../x.md" "$(cat "$ABSW/.B")" "$(cat "$ABSW/.T")" >/dev/null 2>&1; out="$out lnk=$?"
      he_run "$s" -C "$ABSW" --strategy "$(cat "$ABSW/.T")" "$(cd -P "$ABSW" && pwd -P)/$STORY" >/dev/null 2>&1; out="$out sdirty=$?"
      he_run "$s" -C "$WORK/world-empty" --strategy "$(cat "$WORK/world-empty/.T")" "$pe/$STORY" >/dev/null 2>&1; out="$out scommit=$?"
      printf '%s' "${out# }"
    }
    ABSWANT='0: 0: 0: 2: climb=2 lnk=2 sdirty=0 scommit=1'
    got="$(abs_vec "$HECTL")"
    if [ "$got" = "$ABSWANT" ]; then ok "ABSOLUTE STORY: an absolute story path, physical or through a symlinked alias, reads as the relative one; a relative climb and a lnk/.. hop out of the tree exit 2 (UNEVALUABLE, no read); strategy mode reads the ref, not the working tree"
    else bad "ABSOLUTE STORY: want [$ABSWANT] got [$got]"; fi
    # STORY SYMLINK (BL-770). norm_story contains the story's DIRECTORY and keeps the link name, so
    # an untracked story that is itself a symlink is held to the same containment by story_text.
    # Cells, strategy mode at HEAD: an untracked symlink to a file OUTSIDE the tree whose bytes
    # carry an empty cell (2, never read; the read would give 1); an untracked symlink to an
    # in-tree clean copy (0, still readable); a TRACKED symlink blob to that same outside file (0:
    # `git show` emits the link string, nothing outside is read).
    if cp "$ABSW/$STORY" "$WORK/abs-out/evil.md" && cp "$WORK/world-clean/$STORY" "$ABSW/stories/clean-copy.md" \
       && ln -s "$WORK/abs-out/evil.md" "$ABSW/stories/untrk.md" && ln -s clean-copy.md "$ABSW/stories/inlink.md" \
       && ln -s "$WORK/abs-out/evil.md" "$ABSW/stories/tlink.md" && gitw "$ABSW" add stories/tlink.md \
       && gitw "$ABSW" commit -qm tlink; then
      sym_vec() { # <script>
        local s="$1" pa out=""
        pa="$(cd -P "$ABSW" && pwd -P)"
        he_run "$s" -C "$ABSW" --strategy HEAD stories/untrk.md >/dev/null 2>&1; out="$out out=$?"
        he_run "$s" -C "$ABSW" --strategy HEAD "$pa/stories/untrk.md" >/dev/null 2>&1; out="$out outabs=$?"
        he_run "$s" -C "$ABSW" --strategy HEAD stories/inlink.md >/dev/null 2>&1; out="$out in=$?"
        he_run "$s" -C "$ABSW" --strategy HEAD stories/tlink.md >/dev/null 2>&1; out="$out tracked=$?"
        printf '%s' "${out# }"
      }
      SYMWANT='out=2 outabs=2 in=0 tracked=0'
      got="$(sym_vec "$HECTL")"
      if [ "$got" = "$SYMWANT" ]; then ok "STORY SYMLINK: an untracked story symlinked out of the tree exits 2 (relative and absolute), one symlinked to an in-tree file is read, and a tracked symlink blob reads as its link string"
      else bad "STORY SYMLINK: want [$SYMWANT] got [$got]"; fi
    else
      bad "FIXTURE BROKEN: could not seed the story-symlink cells"
    fi
  else
    bad "FIXTURE BROKEN: could not seed the absolute-story world"
  fi
fi
if gsel run-record; then
  # (k)/(l) BL-768, the run-record arms. fc_vec reads the run-record worlds through the control tree.
  FCWANT='0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0::W'
  FC_WORLDS='fcrec fccode fcbare fcgone dsgone dsbare devold devnew fcevil fcna fctbd fcempty fcnext dsna diskold disknew fcfence fcinvoc fcbold fcnonebt fcmake dsvenv'
  se_need $FC_WORLDS
  fc_vec() { # <script>
    local s="$1" o="" v
    for v in $FC_WORLDS; do
      o="$o $(verdict "$s" "$WORK/world-$v" h)"
    done
    printf '%s' "${o# }"
  }
  got="$(fc_vec "$HECTL")"
  if [ "$got" = "$FCWANT" ]; then ok "RUN-RECORD: a reasoned none over a story+yamls+docs/reviews+test-results diff accepted, over a diff touching a test refused full-collection-none, a bare none refused, a missing line refused, a dependency-setup none with no reason refused, dev.md without the label prescription is LEGACY and with it refuses both missing lines; a .py under test-results/ and a conftest.py under docs/reviews/ make a record diff non-record; N/A, TBD and an empty value over a code diff each refused, an empty value continued by the invocation accepted, a dependency-setup N/A refused; dev.md untracked at <frozen> but on disk keys LEGACY both ways; an empty value over a fenced run and over \`- Invocation:\` accepted, over a bold label refused; a none carrying a runner span and a two-word span naming no runner refused; a venv interpreter with its packages accepted as a setup"
  else bad "RUN-RECORD: want [$FCWANT] got [$got]"; fi
fi

if gsel conventions; then
  # BL-768: the dev gate passes the project's conventions file to run-shape as the QA side does.
  # fcconv (tox -e all declared canonical) is accepted, fcconv-none (same value, no file) is refused.
  if build_world "$WORK/world-fcconv" fcconv && build_world "$WORK/world-fcconv-none" fcconv-none; then
    cv_c="$(verdict "$HECTL" "$WORK/world-fcconv" h)"; cv_n="$(verdict "$HECTL" "$WORK/world-fcconv-none" h)"
    if [ "$cv_c" = '0:' ] && [ "$cv_n" = '1:full-collection-none,' ]; then
      ok "CONVENTIONS: a runner the conventions declare canonical (tox -e all) is accepted at the dev gate, and the same value with no conventions file is refused full-collection-none"
    else bad "CONVENTIONS: want [0:] and [1:full-collection-none,] got [$cv_c] and [$cv_n]"; fi
  else bad "FIXTURE BROKEN: could not seed the conventions worlds"; fi
fi

if gsel pointer; then
  # POINTER: run-shape's pointer-word refusal, in a world only it decides (fcsee: `see` opens a value that carries a
  # runner span and a count and is no none form), with its near-miss (fcseenm: the same span and count, `see` not
  # opening).
  if build_world "$WORK/world-fcsee" fcsee && build_world "$WORK/world-fcseenm" fcseenm; then
    pt_vec() { printf '%s %s' "$(verdict "$1" "$WORK/world-fcsee" h)" "$(verdict "$1" "$WORK/world-fcseenm" h)"; }
    PTWANT='1:full-collection-none, 0:'
    got="$(pt_vec "$HECTL")"
    if [ "$got" = "$PTWANT" ]; then ok "POINTER: a value opening with see, carrying a runner span and a count, is refused full-collection-none over a code diff; the same span and count with see later in the value is a run"
    else bad "POINTER: want [$PTWANT] got [$got]"; fi
  else bad "FIXTURE BROKEN: could not seed the pointer worlds"; fi
fi

if gsel run-filter; then
  # --- BL-1016 RUN-FILTER AT THE DEV GATE (rf1016-*) ---------------------------------------------------------------
  # Arm (k) reads every Full-collection value it ACCEPTS AS A RUN (by run-shape, or by the capture-heads count route)
  # through record-only-diff.sh RUN-FILTER with the toplevel conventions file, and refuses what narrows the collection
  # `full-collection-filtered`. Its OWN positional list, RF_WORLDS (world.sh rf_world says where each value comes
  # from); FC_WORLDS does not grow, and fcfence (a fenced `$ pytest -q` read through the `$ ` prompt and its counts)
  # stays asserted accepted in FCWANT. Cells in order: rf1016-s1 (graph s322 1.3's record, three files and
  # `-m "not integration"`: refused); rf1016-s2 (graph s322 1.8's record, a watchdog run whose span precedes a later
  # `version ok: pytest 9.1.1` span, under graph's ed61de745 wrapper declaration with `--docker` declared: accepted);
  # rf1016-s2n (the same record under the declaration as graph wrote it, `--docker` undeclared: refused);
  # rf1016-s3 (a repo-root `-m unit` run, the conventions declaring `<venv>/bin/python -m pytest -m unit`: accepted);
  # rf1016-s4 (the same run, a conventions file present that declares no marker: refused); rf1016-s5
  # (`-n 8 server/tests`, those conventions declaring `pytest -n 8 server/tests`: accepted); rf1016-s6 (the capture
  # route, a fresh capture-heads block pasted, its cited invocation handing a test file after `--`: refused);
  # rf1016-s7 (the plain capture cite over the same block: accepted); rf1016-s8 (a collect-only run of the declared
  # watchdog wrapper behind leading prose and before a later `version ok: pytest` span, citing the capture with a
  # fresh block, under the declaration carrying `--docker`: refused full-collection-none, the no-run route, because
  # NO-TEST-RUN picks its span WITH the conventions file); rf1016-ph (a `<repo>` placeholder before
  # `-k foo`: refused) and rf1016-ph-nm (the placeholder, no filter: accepted); rf1016-ch (`pytest -q > out.txt;
  # pytest -k foo`: refused) and rf1016-ch-nm / rf1016-ch-nm2 (`> out.txt` alone, and `pytest -q; pytest -q`, a
  # chain of which no command narrows: accepted). Every cell is a whole story driven through the shipped validator
  # and read as <exit>:<REFUSED tokens>, never a count. Appended: rf1016-s2nw (graph s322 1.8's record with NO
  # conventions file: refused, and its cell carries the refusal's reason class, which must name neither the later
  # `version ok: pytest 9.1.1` span's `9.1.1` nor the payload's xdist count `8` as a path, and names the undeclared
  # wrapper: +wrapper);
  # rf1016-d1 (an unbackticked `pytest -q -k foo` beside a backticked working directory: refused) and rf1016-d1-nm
  # (wv957rundir's value, no filter: accepted); rf1016-rd (`pytest -q 1>out.txt -k foo`, a redirection mid-command:
  # refused; rf1016-ch-nm is its near-miss); rf1016-a1 (`--junitxml "a; b.xml"`, a quoted `;`: accepted; rf1016-ch is
  # its real-chain pair); rf1016-a2 (`--reruns 1`, an option's value: accepted) and rf1016-a2-nm (the same plus
  # `tests/test_x.py`: refused); rf1016-a3 (`uv pip install pytest pytest-xdist && pytest -n 8`, a pytest word inside
  # a non-pytest chain command: accepted) and rf1016-a3-nm (`uv pip install pytest && pytest -k foo`: refused);
  # rf1016-sp (`cd /repo` then `pytest -k foo`, a pytest span AFTER a non-pytest span: refused) and rf1016-sp-nm (the
  # same with `pytest -q`: accepted); rf1016-bl (`bash -lc "cd . && pytest -k x"`: refused) and rf1016-bl-nm
  # (`... pytest -q"`: accepted); rf1016-ao (`pytest -o "addopts=-k foo"`: refused) and rf1016-ao-nm
  # (`-o "addopts=-q; x"`: accepted); rf1016-qk (`pytest -q -v' -k foo`, an unbalanced quote: refused); rf1016-to
  # (`timeout 600 pytest -k foo`, then `pytest -q`: refused) and rf1016-to-nm (`timeout 600 pytest -q`: accepted);
  # rf1016-npm (`npm test -- -n 8 -q`: accepted); rf1016-ch2 (`pytest -q && cd . && pytest -k foo`, a narrowing
  # command after a non-pytest one: refused) and rf1016-ch2-nm (the same ending `pytest -q`: accepted); rf1016-be
  # (`bash -lc "cd . && pytest -k \"not slow\" -q"`, an escaped quote inside the quoted command: refused; its
  # pair is rf1016-bl-nm); rf1016-su (`sudo -u app pytest -k foo` then `pytest -q`, a prefix carrying its own option:
  # refused) and rf1016-su-nm (`sudo -u app pytest -q`: accepted); rf1016-to2 (`timeout -s KILL 600 pytest -k foo`
  # then `pytest -q`, a prefix's own option skipped: refused) and rf1016-to2-nm (`timeout -s KILL 600 pytest -q`:
  # accepted); rf1016-jx (`bash -lc "... pytest -q --junitxml \"a b.xml\""`, an escaped quote kept inside one argument:
  # accepted); rf1016-ss (the capture route citing `bash -c "ssh h 'pytest -k x'"`, a quoted command nested in a quoted
  # command, over a fresh block: refused) and rf1016-ss-nm (citing `bash -c "pytest -q"`: accepted); rf1016-de
  # (`ssh host "cd . && direnv exec . pytest -k x"`, an unrecognised program before pytest inside a quoted command:
  # refused) and rf1016-de-nm (the same with `pytest -q`: accepted); rf1016-dc (`pytest -q && direnv exec . pytest
  # -k x`, the same in a chain step: refused) and rf1016-dc-nm (`... direnv exec . pytest -q`: accepted); rf1016-dx
  # (`direnv exec . pytest -k x` then `pytest -q`, the same as an earlier span: refused) and rf1016-dx-nm (accepted);
  # rf1016-gr (`pytest -q; grep pytest out.txt -c`, a pytest word in a non-runner command: accepted); rf1016-bt
  # (`pytest -q --basetemp <tmp> tests/test_x.py`, a placeholder option value before a file: refused) and rf1016-bt-nm
  # (`pytest -q --basetemp <tmp>`: accepted); rf1016-s9 (rf1016-s8's collect-only wrapper run followed by a
  # `pytest -q` span, on the capture route with a fresh block: refused full-collection-none) and rf1016-s9-nm (the
  # same wrapper run with `-- -q`: accepted). A chained or quoted `cd` in these worlds is `cd .`, so each refused cell
  # and its near-miss stay one property apart: a `cd` into a subdirectory narrows on its own (RUN-FILTER, WORKING
  # DIRECTORY; receipt-bl1036.sh). For the same reason rf1016-d1 and rf1016-d1-nm record the working directory `./`:
  # a recorded relative subdirectory narrows on its own (validate-handoff-evidence.sh, RECORDED WORKING DIRECTORY).
  RF_WORLDS='rfs1 rfs2 rfs2n rfs3 rfs4 rfs5 rfs6 rfs7 rfs8 rfph rfphnm rfch rfchnm rfchnm2 rfs2nw rfd1 rfd1nm rfrd rfa1 rfa2 rfa2n rfa3 rfa3n rfsp rfspnm rfbl rfblnm rfao rfaonm rfqk rfto rftonm rfnpm rfch2 rfch2nm rfbe rfsu rfsunm rfto2 rfto2nm rfjx rfss rfssnm rfde rfdenm rfdc rfdcnm rfdx rfdxnm rfgr rfbt rfbtnm rfs9 rfs9nm'
  rf_ok=1
  for v in $RF_WORLDS; do build_world "$WORK/world-$v" "$v" || { rf_ok=0; bad "FIXTURE BROKEN: could not seed git world '$v'"; }; done
  # Seed control: each world's COMMITTED Full-collection line is rf_value's text byte for byte, so an accepted cell
  # cannot be a mangled value read for some other reason.
  if [ "$rf_ok" = 1 ]; then
    for v in $RF_WORLDS; do
      rf_l="$(gitw "$WORK/world-$v" show "$(cat "$WORK/world-$v/.T"):$STORY" | awk 'index($0, "Full-collection run: ") == 1 { print substr($0, 22) }')"
      [ "$rf_l" = "$(rf_value "$v")" ] || { rf_ok=0; bad "FIXTURE BROKEN: world '$v' committed a Full-collection value other than rf_value's"; }
    done
  fi
  # The capture-route worlds' block: rendered at the frozen sha and pasted, as the dev pastes it (wv957codar's shape).
  if [ "$rf_ok" = 1 ]; then
    for v in rfs6 rfs7 rfs8 rfss rfssnm rfs9 rfs9nm; do
      rf_w="$WORK/world-$v"
      rf_b="$(he_run "$HECTL" -C "$rf_w" --render-dar "$STORY" "$(cat "$rf_w/.T")" 2>/dev/null)" && [ -n "$rf_b" ] \
        && printf '\n%s\n' "$rf_b" >> "$rf_w/$STORY" && gitw "$rf_w" add -A && gitw "$rf_w" commit -qm block \
        && gitw "$rf_w" rev-parse HEAD > "$rf_w/.T" \
        || { rf_ok=0; bad "FIXTURE BROKEN: could not render and paste $v's capture-heads block"; }
      # The block carries the capture's count, so the count route WOULD accept the value: only the filter refuses rfs6.
      grep -qF '1 passed' <<<"$rf_b" || { rf_ok=0; bad "FIXTURE BROKEN: $v's block renders no count, so the count route could not acquit it either way"; }
    done
  fi
  if [ "$rf_ok" = 1 ]; then
    RFWANT='1:full-collection-filtered, 0: 1:full-collection-filtered, 0: 1:full-collection-filtered, 0: 1:full-collection-filtered,:W 0::W 1:full-collection-none,:W 1:full-collection-filtered, 0: 1:full-collection-filtered, 0: 0: 1:full-collection-filtered,+wrapper 1:full-collection-filtered, 0: 1:full-collection-filtered, 0: 0: 1:full-collection-filtered, 0: 1:full-collection-filtered, 1:full-collection-filtered, 0: 1:full-collection-filtered, 0: 1:full-collection-filtered, 0: 1:full-collection-filtered, 1:full-collection-filtered, 0: 0: 1:full-collection-filtered, 0: 1:full-collection-filtered, 1:full-collection-filtered, 0: 1:full-collection-filtered, 0: 0: 1:full-collection-filtered,:W 0::W 1:full-collection-filtered, 0: 1:full-collection-filtered, 0: 1:full-collection-filtered, 0: 0: 1:full-collection-filtered, 0: 1:full-collection-none,:W 0::W'
    # rf_cell <script> <world>: the verdict; rfs2nw's also names its refusal's reason class (below), since its token
    # alone cannot say WHICH span was read or whether the wrapper's `-n 8` was read as a path.
    rf_cell() {
      local c
      # verdict in THIS shell (never inside `$( )`), so VERDICT_OUT is the run just made.
      verdict "$1" "$WORK/world-$2" h > "$WORK/.rfv"; c="$(cat "$WORK/.rfv")"
      if [ "$2" = rfs2nw ]; then
        # The REASON alone: the refusal line after the quoted value (which itself carries `9.1.1`) and before the
        # run-gate parenthesis. +version-path: it names 9.1.1; +eight-path: it names the xdist count 8 as a path;
        # +wrapper: neither of those, and it reads `runs scripts/pytest-footprint-watchdog.py, a wrapper the conventions do
        # not declare` (the refusal BY NAME);
        # +other: any other refusal. An accepted cell carries no class.
        rf_r="$(awk '/^REFUSED full-collection-/ { sub(/^.*'"'"' /, ""); sub(/ \(record-only-diff\.sh run-gate.*$/, ""); print; exit }' <<<"$VERDICT_OUT")"
        if [ -n "$rf_r" ]; then
          case "$rf_r" in
            *9.1.1*) c="$c+version-path" ;;
            *) if grep -qE '(^|[^0-9.])8([^0-9.]|$)' <<<"$rf_r"; then c="$c+eight-path"
               elif grep -qF 'runs scripts/pytest-footprint-watchdog.py, a wrapper the conventions do not declare' <<<"$rf_r"; then c="$c+wrapper"
               else c="$c+other"; fi ;;
          esac
        fi
      fi
      printf '%s' "$c"
    }
    rf_vec() { # <script> -> every world's cell, in RF_WORLDS order
      local s="$1" o="" v
      for v in $RF_WORLDS; do
        rf_cell "$s" "$v" > "$WORK/.rfc"; o="$o $(cat "$WORK/.rfc")"
      done
      printf '%s' "${o# }"
    }
    got="$(rf_vec "$HECTL")"
    if [ "$got" = "$RFWANT" ]; then ok "RUN-FILTER (BL-1016): graph s322 1.3's file-and-marker run refused full-collection-filtered; 1.8's watchdog record accepted under a declaration carrying --docker and refused under graph's own; a declared -m unit run accepted, the same run refused under conventions declaring no marker, a declared server/tests path accepted; a capture-heads cite whose invocation hands a test file after -- refused, the plain cite accepted; a collect-only declared-wrapper run behind prose refused full-collection-none; a <placeholder> before -k and a ; chain ending in -k refused, their near-misses accepted"
    else bad "RUN-FILTER (BL-1016): want [$RFWANT] got [$got] for [$RF_WORLDS]"; fi
  fi
fi

if gsel receipts; then
  # OPEN-ENTRY RECEIPTS (BL-1036, BL-1037, BL-1040), each the runner of its entry's verify: line. Sourced in a fresh subshell
  # (rcpt_run), asking the control tree's validator in process. Each carries its own two controls (a plain run accepted,
  # a `-k` run refused full-collection-filtered) and exits 9 when either fails; 0 means the entry's fix is present, 1
  # that the defect still reproduces. This arm holds the receipt MEASURABLE (0 or 1, with its verdict line), never its
  # polarity: the entry turns by its own exit, and an unmeasurable receipt (9, or any other exit) fails here.
  # Each receipt named LITERALLY (validate-fixture-hygiene E1 reads a computed receipt name as inert).
  for rc_f in "$DIR/receipt-bl1036.sh" "$DIR/receipt-bl1037.sh" "$DIR/receipt-bl1040.sh"; do
    rc_n="${rc_f##*/receipt-bl}"; rc_n="${rc_n%.sh}"
    rc_o="$(rcpt_run - "$rc_f" "$HECTL" 2>&1)"; rc_x=$?
    case "$rc_x:$rc_o" in
      0:*FIXED:*|1:*LIVE:*) ok "RECEIPT BL-$rc_n measurable (exit $rc_x): $(grep -E '^(FIXED|LIVE):' <<<"$rc_o")" ;;
      *) bad "RECEIPT BL-$rc_n could not measure its subject (exit $rc_x): $(tr '\n' ' ' <<<"$rc_o")" ;;
    esac
  done
fi

if gsel sibling; then
  se_need notreview
  # The story line is parsed WHATEVER sprint-status.sh exits. No yaml makes the shipped
  # story-status exit non-zero portably after its story line, so the sibling's exit is
  # synthesised: two trees whose sprint-status.sh is a wrapper that runs the real one, writes one
  # stderr line, and exits 3 in one tree and 0 in the other. Only the exit differs, so a SKIP in
  # the rc-3 tree is the exit's and not the wrapper's. Driven over notreview (story and row
  # in-progress): (g) must refuse in both, and the rc-3 tree adds a SKIP STATUS for the row.
  rc_tree() { # <name> <exit> -> path of the validator in a tree whose sibling exits <exit>
    local v d
    v="$(mk_tree "$1")" || return 1
    d="$(dirname "$v")"
    mv "$d/sprint-status.sh" "$d/sprint-status.real.sh" || return 1
    # The wrapper is LOADABLE as the real one is (an ss_main, then the source guard), so the validator's
    # `bash <dir>/sprint-status.sh` reaches it in process (he-inproc.sh); run by bash it answers the same.
    printf '#!/usr/bin/env bash\nss_main() {\n  ( . "${BASH_SOURCE[0]%%/*}/sprint-status.real.sh" || exit 2; ss_main "$@" )\n  echo "sprint-status: synthetic failure after the story line" >&2\n  exit %s\n}\n%s\nss_main "$@"\n' \
      "$2" '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' > "$d/sprint-status.sh" || return 1
    printf '%s\n' "$v"
  }
  if RC3="$(rc_tree ssrc3 3)" && RC0="$(rc_tree ssrc0 0)"; then
    RCWANT='1:status-not-review,:W:S 1:status-not-review,:W'
    rc_vec() { printf '%s %s' "$(verdict "$1" "$WORK/world-notreview" k)" "$(verdict "$2" "$WORK/world-notreview" k)"; }
    got="$(rc_vec "$RC3" "$RC0")"
    skip_line="$(he_run "$RC3" -C "$WORK/world-notreview" "$STORY" "$(cat "$WORK/world-notreview/.B")" "$(cat "$WORK/world-notreview/.T")" 2>/dev/null | grep -c '^SKIP STATUS (implementation-view row .*exited 3: sprint-status: synthetic failure')" || skip_line=0
    if [ "$got" = "$RCWANT" ] && [ "$skip_line" -eq 1 ]; then
      ok "SIBLING EXIT: a sprint-status.sh exiting 3 after its story line still lets (g) refuse status-not-review, and the row half prints one SKIP STATUS naming the exit; the same wrapper at exit 0 prints none"
    else
      bad "SIBLING EXIT: want [$RCWANT] and one SKIP STATUS naming exit 3, got [$got] and $skip_line"
    fi
  else
    bad "FIXTURE BROKEN: could not build the wrapped sprint-status.sh trees"
  fi
fi

if gsel redline; then
  # --- BL-833 RED LINE (rv_*) -----------------------------------------------------------------------
  # One world, one validator call per program, read per cell by token: rv_block in world.sh, whose header
  # carries the cells and the BL-834 invocation count.
  rv_block
  # --- end BL-833 RED LINE --------------------------------------------------------------------------
fi

if gsel waiver; then
  se_need dsna
  # --- BL-957 NO-TEST RUNS AND THE CANONICAL-RUN WAIVER (wv957-*) -----------------------------------------
  # Arm (k)'s two BL-957 rules, over world.sh's wv957* worlds (every range touches tests/test_x.py, so the
  # record-only exemption refuses whatever reaches it). Its OWN positional list, WV_WORLDS; FC_WORLDS does not
  # grow. Cells in order: wv957-co-bt, wv957-co-bare, wv957-co-dollar (a collect-only invocation, backticked,
  # bare and after `$ `, refused full-collection-none); wv957-co-dar (collect-only citing the capture with
  # `counts: capture-heads block` over a fresh block whose count is `1 passed`: refused, the count route is
  # closed to it); wv957-cov, wv957-color (`--cov=`, `--color=`: runs, accepted); wv957-wv-base (`none, AC3
  # waives it`, the entry at the base: accepted); wv957-wv-range (the entry only inside the range: refused);
  # wv957-wv-tree (the story a tree at the base: waiver exit 2, refused); wv957-co-dir, wv957-co-dollar-dir,
  # wv957-co-dollar-mid, wv957-co-span (collect-only where the first backticked span is a working directory, each
  # caught by one of ro_no_test's three texts alone: refused full-collection-none); wv957-run-dir (a bare real run
  # with a backticked directory and no count: accepted); wv957-co-comma, wv957-co-semi (the token followed by `,`
  # and `;`: refused, the boundary is any character outside [A-Za-z0-9_-]); wv957-cov-comma (`--cov,`: a run,
  # accepted); wv957-co-alias (`--collectonly`, pytest's third spelling: refused); wv957-co-open-run and
  # wv957-co-dollar-run (a collect-only invocation in the value's opening, and in a `$ ` command after a backticked
  # directory, each followed by a backticked `pytest -q` that rf_span reads: refused; since the prose-run reading these
  # are the worlds where the opening-command text and the `$ ` text alone carry the token).
  WV_WORLDS='wv957cobt wv957cobare wv957codollar wv957codar wv957cov wv957color wv957wvbase wv957wvrange wv957wvtree wv957codir wv957codollardir wv957codollarmid wv957cospan wv957rundir wv957cocomma wv957cosemi wv957covcomma wv957coalias wv957coopenrun wv957codollarrun'
  wv_ok=1
  for v in $WV_WORLDS; do build_world "$WORK/world-$v" "$v" || { wv_ok=0; bad "FIXTURE BROKEN: could not seed git world '$v'"; }; done
  # wv957codar's block: rendered at its frozen sha and pasted, as the dev pastes it (receipt-bl843's r1 shape).
  if [ "$wv_ok" = 1 ]; then
    wv_w="$WORK/world-wv957codar"
    wv_b="$(he_run "$HECTL" -C "$wv_w" --render-dar "$STORY" "$(cat "$wv_w/.T")" 2>/dev/null)" && [ -n "$wv_b" ] \
      && printf '\n%s\n' "$wv_b" >> "$wv_w/$STORY" && gitw "$wv_w" add -A && gitw "$wv_w" commit -qm block \
      && gitw "$wv_w" rev-parse HEAD > "$wv_w/.T" \
      || { wv_ok=0; bad "FIXTURE BROKEN: could not render and paste wv957codar's capture-heads block"; }
    # Seed control: the pasted block carries the capture's count, so the count route WOULD accept this value.
    grep -qF '1 passed' <<<"$wv_b" || { wv_ok=0; bad "FIXTURE BROKEN: wv957codar's block renders no count, so the count route could not acquit it either way"; }
  fi
  if [ "$wv_ok" = 1 ]; then
    WVWANT='1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none,:W 0: 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:full-collection-none, 1:full-collection-none, 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none,'
    wv_vec() { # <script>
      local s="$1" o="" v
      for v in $WV_WORLDS; do
        o="$o $(verdict "$s" "$WORK/world-$v" h)"
      done
      printf '%s' "${o# }"
    }
    got="$(wv_vec "$HECTL")"
    if [ "$got" = "$WVWANT" ]; then ok "WAIVER (BL-957): a collect-only invocation, backticked, bare or after \$, is refused full-collection-none, also when its first backticked span is a working directory, and so is one citing a fresh capture-heads count; a bare real run with a backticked directory stays a run; --cov and --color stay runs; none, AC3 waives it is accepted with the entry at the base, refused with the entry only in the range, and refused when the story is a tree at the base"
    else bad "WAIVER (BL-957): want [$WVWANT] got [$got]"; fi
    # The remedy names the waiver at the full-collection site ONLY: wv957-wv-range's refusal names it, and the
    # Dependency setup refusal (dsna, ev_none's other caller) does not. wv_rmd <script> -> "<fc>:<ds>" counts.
    wv_rmd() {
      local a=0 d=0
      verdict "$1" "$WORK/world-wv957wvrange" h > /dev/null
      grep -q "^REFUSED full-collection-none .*Canonical-run waivers.*waives it" <<<"$VERDICT_OUT" && a=1
      verdict "$1" "$WORK/world-dsna" h > /dev/null
      grep -q '^REFUSED dependency-setup-none ' <<<"$VERDICT_OUT" && ! grep -q '^REFUSED dependency-setup-none .*waives it' <<<"$VERDICT_OUT" && d=1
      printf '%s:%s' "$a" "$d"
    }
    if [ "$(wv_rmd "$HECTL")" = 1:1 ]; then ok "WAIVER (BL-957): the full-collection refusal names the canonical-run waiver as a further option, and the dependency-setup refusal does not"
    else bad "WAIVER (BL-957): want the remedy on the full-collection refusal only [1:1], got [$(wv_rmd "$HECTL")]"; fi
    # The waiver test itself, asked directly over wv957wvbase's story at its base,
    # which carries AC3 and AC1x2: AC3 waived, AC4 not (an id mismatch), AC1.2 not (a regex would match AC1x2),
    # AC1x2 waived (the fixed-string twin), and a value that is not the spelling.
    wv_dir() { # <script dir> -> "<rc>[<first stdout line>]" per cell, space-separated
      local wb out="" val o rc w="$WORK/world-wv957wvbase"
      wb="$(cat "$w/.B")"
      for val in 'none, AC3 waives it' 'none, AC4 waives it' 'none, AC1.2 waives it' 'none, AC1x2 waives it; the signer' 'none, the diff is record-only'; do
        o="$(ro_run "$1/record-only-diff.sh" waiver -C "$w" "$STORY" "$wb" "$val" 2>/dev/null)"; rc=$?
        out="$out $rc[${o%%:*}]"
      done
      printf '%s' "${out# }"
    }
    WVDWANT='0[WAIVED] 1[NOT-WAIVED] 1[NOT-WAIVED] 0[WAIVED] 1[NOT-WAIVED]'
    got="$(wv_dir "$(dirname "$HE")")"
    if [ "$got" = "$WVDWANT" ]; then ok "WAIVER (BL-957): record-only-diff.sh waiver matches the entry's AC id as a fixed string (AC3 and AC1x2 waived; AC4 and AC1.2 not), and a value that is not the spelling is NOT-WAIVED"
    else bad "WAIVER (BL-957): record-only-diff.sh waiver want [$WVDWANT] got [$got]"; fi
  fi
  # --- end BL-957 ---------------------------------------------------------------------------------------
fi
fi

# --- B3: the gate-2 handoff preflight is wired -----------------------------------------------------
# implementation.md must carry, on some line, the EXACT go-signal invocation of handoff mode, which
# Rule A's GATE1-SKIP sentence and the preflight before every gate-2 dispatch run. Substring match on
# the line (the prose backticks it). The gate-1 line `... <base> <frozen-sha>` is a near-miss that must
# NOT satisfy it: asserted present and distinct. Absent, this arm FAILS (never green on absence).
if gsel b3; then
B3_LINE='the program runs the `--gate2` arm of the'
B3_NEAR='program also runs the handoff-evidence validator and its `--strategy` arm'
b3_has() { grep -qF -- "$B3_LINE" "$1"; }
if ! grep -qF -- "$B3_NEAR" "$IMP"; then
  bad "B3: FIXTURE BROKEN -- the gate-1 near-miss line is absent from implementation.md, so the arm cannot show it discriminates"
elif b3_has "$IMP"; then
  ok "B3: implementation.md runs handoff mode at the go-signal sha before gate 2 ($B3_LINE); the gate-1 <frozen-sha> line alone does not satisfy it"
else
  bad "B3: implementation.md carries no line naming '$B3_LINE' (the GATE1-SKIP and gate-2 preflight handoff call); the gate-1 <frozen-sha> line does not count"
fi
fi

# --- BL-808: --list-captures ------------------------------------------------------
# One world, three commits. L1's story cites: cap1 on a RED line AND on a plain line (one row),
# cap2 as `./`, the bare basename cap3.txt (a capture dir's file), and -- each of which must print
# NOTHING although its target is TRACKED -- `../x/y.txt` (a leading `../` climbs above the toplevel), an
# absolute x/y.txt under a directory OUTSIDE the world (an absolute path under the toplevel is BL-815's
# and lists its toplevel spelling, receipt-bl815.sh cell lc), a glob over
# cap4, an elided path to cap6, the bare y.txt (tracked, but x/ is not a capture dir at L1), and the
# untracked evidence/s1/untracked.txt (on disk only). L2 adds a full-path x/y.txt citation (the
# control that x/y.txt is printable at all); the working tree then cites cap5 on disk only, so the
# read at L2 must not print it, and L3 commits that line (the control that cap5 is printable).
# The vector is every cell's exact output.
if gsel listcaps && [ "$WORLDS_OK" -eq 1 ]; then
  LC_W="$WORK/world-listcaps"
  lc_ok=1
  mkdir -p "$LC_W/evidence/s1" "$LC_W/x" "$LC_W/docs/stories" && gitw "$LC_W" init -q || lc_ok=0
  if [ "$lc_ok" -eq 1 ]; then
    for i in 1 2 3 4 5 6; do printf '$ pytest\nline %s\n' "$i" > "$LC_W/evidence/s1/cap$i.txt"; done
    printf 'y\n' > "$LC_W/x/y.txt"
    {
      printf '# Story\n'
      printf 'Evidence: `evidence/s1/cap1.txt` is the RED capture, and ./evidence/s1/cap2.txt the green one.\n'
      printf 'Again, for the record: evidence/s1/cap1.txt\n'
      printf 'Relative: ../x/y.txt\n'
      printf 'Absolute: %s/x/y.txt and /etc/hosts.txt\n' "$WORK/world-listcaps-outside"
      printf 'Bare: cap3.txt and y.txt and nosuch.txt\n'
      printf 'Glob: evidence/s1/cap*.txt\n'
      printf 'Elided: evidence/.../cap6.txt\n'
      printf 'Untracked: evidence/s1/untracked.txt\n'
    } > "$LC_W/docs/stories/s.md"
    gitw "$LC_W" add -A && gitw "$LC_W" commit -qm l1 || lc_ok=0
    printf 'untracked\n' > "$LC_W/evidence/s1/untracked.txt"
    printf 'Tracked: x/y.txt\n' >> "$LC_W/docs/stories/s.md"
    gitw "$LC_W" add docs/stories/s.md && gitw "$LC_W" commit -qm l2 || lc_ok=0
    printf 'Later: evidence/s1/cap5.txt\n' >> "$LC_W/docs/stories/s.md"
    LC1="$(gitw "$LC_W" rev-parse HEAD~1)"; LC2="$(gitw "$LC_W" rev-parse HEAD)"
  fi
  # Seed controls: every must-not-print target is tracked at L1, and untracked.txt is not.
  lc_seed=""
  for p in x/y.txt evidence/s1/cap4.txt evidence/s1/cap5.txt evidence/s1/cap6.txt; do
    gitw "$LC_W" cat-file -e "${LC1:-x}:$p" 2>/dev/null || lc_seed="$lc_seed $p"
  done
  gitw "$LC_W" cat-file -e "${LC1:-x}:evidence/s1/untracked.txt" 2>/dev/null && lc_seed="$lc_seed untracked-is-tracked"
  [ -f "$LC_W/evidence/s1/untracked.txt" ] || lc_seed="$lc_seed untracked-absent"
  if [ "$lc_ok" -ne 1 ] || [ -n "$lc_seed" ]; then
    bad "LIST-CAPTURES: FIXTURE BROKEN -- the world could not be built or cannot express its cases [${lc_seed# }]"
  else
    lc_cell() { # <script> <frozen> -> "rc:<line>,<line>,..."
      local o rc
      o="$(he_run "$1" -C "$LC_W" --list-captures docs/stories/s.md "$2" 2>/dev/null)"; rc=$?
      printf '%s:%s' "$rc" "$(printf '%s\n' "$o" | grep . | tr '\n' ',')"
    }
    lc_vec() { # <script> -> L1 | L2 (disk carries cap5) | L3 (cap5 committed)
      local a b c
      a="$(lc_cell "$1" "$LC1")"; b="$(lc_cell "$1" "$LC2")"
      c="$(lc_cell "$1" "$LC3")"
      printf '%s | %s | %s' "$a" "$b" "$c"
    }
    gitw "$LC_W" add docs/stories/s.md && gitw "$LC_W" commit -qm l3 && LC3="$(gitw "$LC_W" rev-parse HEAD)"
    # After L3 the on-disk story still cites cap5, so the L2 cell reads a disk that names it: only a
    # read AT the ref keeps cap5 out of that cell.
    E='evidence/s1/'
    LCWANT="0:${E}cap1.txt,${E}cap2.txt,${E}cap3.txt, | 0:${E}cap1.txt,${E}cap2.txt,${E}cap3.txt,x/y.txt, | 0:${E}cap1.txt,${E}cap2.txt,${E}cap3.txt,${E}cap5.txt,x/y.txt,"
    got="$(lc_vec "$HE")"
    if [ "$got" = "$LCWANT" ]; then
      ok "LIST-CAPTURES: the story read AT the ref prints cap1 once (RED and plain citations), cap2 from './', the bare cap3.txt from its capture dir; '../', an outside absolute, glob, elided, untracked and the bare y.txt outside a capture dir print nothing; x/y.txt prints once cited by full path; cap5 cited on disk only is not printed at L2 and is at L3"
    else
      bad "LIST-CAPTURES: want [$LCWANT] got [$got]"
    fi
  fi
fi

# INPROC: every subject call the cells above made through he-inproc.sh was answered in process. A subject file the
# runner had to hand to the real bash (no source guard) is logged; only the EQUIV arm's CLI rows run bash by design,
# and they do not pass through the runner. Positive conjunct: the log exists, so an unset variable cannot pass.
if [ -f "$UT_FALLBACK_LOG" ] && [ ! -s "$UT_FALLBACK_LOG" ]; then
  ok "INPROC: every validator, record-only-diff.sh and sprint-status.sh call the cells made was answered in process"
else
  bad "INPROC: subject calls ran as processes: $(sort "$UT_FALLBACK_LOG" 2>/dev/null | uniq -c | tr '\n' ' ')"
fi

echo
report_end story-evidence-scaffold
