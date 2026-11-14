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
# worlds, each offender one property away from a clean world that carries the near-misses,
# with a mutant per arm and per near-miss.
#
# WHY THE DEV AND QA ARMS SHADOW BEFORE THEY READ. The reference consumer shadows
# `team-roles/dev.md#Workflow Per Task` and `team-roles/qa.md#Validation Checklist` with
# override bodies of its own, so text placed in either section never reaches that consumer's
# dev or QA. Each arm therefore replaces those two sections with a stub first, the way the
# loader does, and only then looks. The mutants that MOVE the text into a shadowed section
# still leave it in the file, which a whole-file grep would accept; these arms must not.
#
# IN PROCESS. validate-handoff-evidence.sh, record-only-diff.sh and sprint-status.sh are loadable (each ends in a
# BASH_SOURCE guard before its one main call), and every cell asks them through he-inproc.sh's he_run: the
# validator's he_main in a subshell, its record-only-diff.sh and sprint-status.sh calls answered by THOSE FILES'
# own ro_main / ss_main in further subshells, so no bash is started per verdict. A mutant is a copy of the
# subject sourced the same way. The receipts in this directory (receipt-bl809/815/843/845.sh) are NOT driven
# here: their full control calls and BL-979's RAN SET run in story-evidence-receipts (shipped), their mutants
# in story-evidence-receipts-mutants (dist-only), so the pool runs them beside this fixture. They stay in this
# directory because their verify: lines name these paths. EQUIV is the one
# end-to-end run per distinct CLI outcome (fixture-mutants.md clauses 5-6) and holds the in-process answer
# byte-identical to `bash <subject>`; INPROC asserts no subject call fell back to a process.
#
# Exit 0 iff every arm holds; 1 on a finding; 2 (FIXTURE BROKEN) when a subject file cannot
# be located. An absent subject is never green.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/world.sh"

STS="$(locate skills/ai-dlc/steps/stories-test-strategy.md)" || STS=""
GV="$(locate skills/ai-dlc/steps/gate-validation.md)" || GV=""
DEV="$(locate team-roles/dev.md)" || DEV=""
QA="$(locate team-roles/qa.md)" || QA=""
CR="$(locate team-roles/code-reviewer.md)" || CR=""
IMP="$(locate skills/ai-dlc/steps/implementation.md)" || IMP=""
SR="$(locate skills/ai-dlc/steps/sprint-review.md)" || SR=""
# HE, SCHEMA and SSH are located by world.sh, which the mutation battery shares.
for v in STS GV DEV QA CR IMP SR HE SCHEMA SSH; do
  eval "p=\${$v}"
  if [ -z "$p" ]; then
    echo "story-evidence-scaffold: FIXTURE BROKEN -- could not locate subject $v in either layout (core/ or .claude/). An absent subject is not a passing one." >&2
    exit 2
  fi
done

for p in skills/ai-dlc/steps/stories-test-strategy.md skills/ai-dlc/steps/gate-validation.md team-roles/dev.md team-roles/qa.md team-roles/code-reviewer.md skills/ai-dlc/steps/implementation.md skills/ai-dlc/steps/sprint-review.md schemas/sprint-status.json scripts/validate-handoff-evidence.sh scripts/sprint-status.sh; do
  echo "HERMETIC-CONSUMED core/$p"
done
# BL-768: the validator's run-record arms read record-only-diff.sh beside it (absent: exit 2, UNEVALUABLE),
# and the run-record mutants copy and edit it, so it is a subject the fixture cannot pass without.
if [ -f "$(dirname "$HE")/record-only-diff.sh" ]; then echo "HERMETIC-CONSUMED core/scripts/record-only-diff.sh"
else echo "story-evidence-scaffold: FIXTURE BROKEN -- record-only-diff.sh is not beside $HE" >&2; exit 2; fi

# CAPGUARD-BEGIN
# THE HOST CAPABILITY, decided by LAYOUT (BL-942). Mutant rp-no-lcc needs an awk that ABORTS on a non-UTF-8
# byte under a UTF-8 locale (world.sh's UTF8_LOCALE probe; BSD awk does, gawk and mawk do not). On a consumer
# the host is not ours to assume, so it SKIPs naming the mutant. In the distribution that SKIP would move the
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
  printf 'story-evidence-scaffold: FIXTURE BROKEN -- capability absent: no UTF-8 locale makes this awk abort on a non-UTF-8 byte (%s). Either that awk does not abort on a Latin-1 byte under en_US.UTF-8 or C.UTF-8 (gawk and mawk do not; BSD awk does), or neither locale exists. In the distribution a missing capability is a broken fixture, not a skip: mutant rp-no-lcc would not run, and the counted start total would move with the box. Remedy: put an awk that aborts on an invalid byte under a UTF-8 locale (the macOS /usr/bin/awk) first on the tool path, and install or enable en_US.UTF-8 so `locale -a` lists it.\n' "$(cap_awk_where)"
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
rc=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; rc=1; }
MUT_LIB="$(cd "$DIR/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $DIR" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

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
cap_mut() { # <span> <from> <to> -> the span with <from> replaced; exit 1 unless <from> occurs exactly once
  F="$2" T="$3" awk 'BEGIN { f = ENVIRON["F"]; t = ENVIRON["T"] }
    { s = $0; while ((i = index(s, f)) > 0) { n++; s = substr(s, i + length(f)) }
      if (!done && (i = index($0, f)) > 0) { $0 = substr($0, 1, i - 1) t substr($0, i + length(f)); done = 1 }
      print }
    END { exit (n == 1 ? 0 : 1) }' <<<"$1"
}
CAP_SPAN="$(cap_span)"
case "$CAP_SPAN" in *"cap_guard()"*"derive_layout()"*|*"derive_layout()"*"cap_guard()"*) ;;
  *) echo "story-evidence-scaffold: FIXTURE BROKEN -- the CAPGUARD span is empty or lost cap_guard/derive_layout" >&2; exit 2 ;; esac
r="$(capcell "$CAP_SPAN" dist "")"
if [ "${r%%|*}" = 2 ] && grep -qF 'capability absent: no UTF-8 locale makes this awk abort on a non-UTF-8 byte (PROBE-AWK)' <<<"$r" \
   && grep -qF 'or neither locale exists' <<<"$r"; then
  ok "cap_dist_awk -- in the distribution, an awk that never aborts refuses (exit 2) naming both causes, the awk and the remedy"; B_capd=1
else bad "cap_dist_awk -- in the distribution, a non-aborting awk did not refuse with the named causes (got ${r%%|*}: ${r#*|})"; fi
r="$(capcell "$CAP_SPAN" consumer "")"
if [ "$r" = "0|" ]; then ok "cap_consumer -- on a consumer, a non-aborting awk passes the guard silently (rp-no-lcc SKIPs instead)"; B_capc=1
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
# callmut <file text> <kind> -> the file with its guard call mutated (del, iffalse, heredoc, override, moved); exit 1
# unless the call line occurs exactly once
callmut() {
  K="$2" awk 'BEGIN { c = "cap_guard >&2 || exit 2"; k = ENVIRON["K"] }
    $0 == c { n++
      if (k == "del") next
      if (k == "iffalse") { print "if false; then"; print; print "fi"; next }
      if (k == "heredoc") { print ": <<'"'"'DEAD'"'"'"; print; print "DEAD"; next }
      if (k == "override") { print "cap_guard() { return 0; }"; print; next }
      if (k == "moved") { held = 1; next } }
    k == "moved" && held == 1 && /^h3\(\) \{/ { print c; held = 2 }
    { print }
    END { exit (n == 1 && (k != "moved" || held == 2)) ? 0 : 1 }' <<<"$1"
}
CC_SELF="$(cat "$DIR/run.sh")"
B_call=0; B_callp=0
r="$(callcell "$CC_SELF" "")"
if [ "${r%%|*}" = 2 ] && grep -qF 'capability absent: no UTF-8 locale makes this awk abort on a non-UTF-8 byte (PROBE-AWK)' <<<"$r" && grep -qF 'layout: dist' <<<"$r"; then
  ok "cap_called -- the shipped call region, evaluated with a non-aborting awk in the distribution, refuses (exit 2) naming it"; B_call=1
else bad "cap_called -- the shipped call region did not refuse a non-aborting awk in the distribution (got ${r%%|*}: ${r#*|})"; fi
r="$(callcell "$CC_SELF" en_US.UTF-8)"
if [ "$r" = "0|layout: dist (position form)" ]; then ok "cap_called_present -- the shipped call region with an aborting awk runs through (exit 0)"; B_callp=1
else bad "cap_called_present -- the shipped call region refused an aborting awk (got ${r%%|*}: ${r#*|})"; fi
for _k in del iffalse heredoc override moved; do
  if ! _m="$(callmut "$CC_SELF" "$_k")" || [ "$_m" = "$CC_SELF" ]; then bad "FIXTURE BROKEN: mutant cap-call-$_k DID NOT APPLY"; continue; fi
  r="$(callcell "$_m" "")"; r2="$(callcell "$_m" en_US.UTF-8)"
  if [ "${r%%|*}" != 2 ] && [ "$r2" = "0|layout: dist (position form)" ]; then
    case "$_k" in
      del) mutant_killed "$(( ${B_call:-0} && ${B_callp:-0} ))" cap-call-deleted "MUTANT cap-call-deleted (the call removed) is killed by cap_called; twin cap_called_present still holds" ;;
      iffalse) mutant_killed "$(( ${B_call:-0} && ${B_callp:-0} ))" cap-call-iffalse "MUTANT cap-call-iffalse (the call inside if false) is killed by cap_called; twin cap_called_present still holds" ;;
      heredoc) mutant_killed "$(( ${B_call:-0} && ${B_callp:-0} ))" cap-call-heredoc "MUTANT cap-call-heredoc (the call inside a dead heredoc) is killed by cap_called; twin cap_called_present still holds" ;;
      override) mutant_killed "$(( ${B_call:-0} && ${B_callp:-0} ))" cap-call-override "MUTANT cap-call-override (cap_guard redefined as return 0 before the call) is killed by cap_called; twin cap_called_present still holds" ;;
      moved) mutant_killed "$(( ${B_call:-0} && ${B_callp:-0} ))" cap-call-moved "MUTANT cap-call-moved (the call moved below the subject arms' first helper) is killed by cap_called; twin cap_called_present still holds" ;;
    esac
  else bad "MUTANT cap-call-$_k: want cap_called not 2 and cap_called_present 0|layout, got [${r%%|*}] [$r2]"; fi
done
if [ "$(laycell "$CAP_SPAN" /x/r/core/fixtures/story-evidence-scaffold)" = dist ]; then ok "lay_dist -- <root>/core/fixtures/<name> derives dist"; B_layd=1
else bad "lay_dist -- <root>/core/fixtures/<name> did not derive dist"; fi
if [ "$(laycell "$CAP_SPAN" /x/r/tests/fixtures/story-evidence-scaffold)" = consumer ]; then ok "lay_consumer -- <root>/tests/fixtures/<name> derives consumer"; B_layc=1
else bad "lay_consumer -- <root>/tests/fixtures/<name> did not derive consumer"; fi
if [ "$(laycell "$CAP_SPAN" /x/r/fixtures/story-evidence-scaffold)" = NEITHER ]; then ok "lay_neither -- a path in neither layout derives NEITHER, never a default"
else bad "lay_neither -- a path in neither layout did not derive NEITHER"; fi
if m="$(cap_mut "$CAP_SPAN" '[ "$LAYOUT" = dist ] || return 0' 'return 0')"; then
  r="$(capcell "$m" dist "")"; r2="$(capcell "$m" consumer "")"
  if [ "${r%%|*}" = 0 ] && [ "$r2" = "0|" ]; then mutant_killed "$(( ${B_capd:-0} && ${B_capc:-0} ))" cap-skip-dist "MUTANT cap-skip-dist (the guard SKIPs in the distribution) is killed by cap_dist_awk; twin cap_consumer still holds"
  else bad "MUTANT cap-skip-dist: want cap_dist_awk 0 and cap_consumer 0|, got [${r%%|*}] [$r2]"; fi
else bad "FIXTURE BROKEN: mutant cap-skip-dist DID NOT APPLY (its anchor does not occur exactly once in the CAPGUARD span)"; fi
if m="$(cap_mut "$CAP_SPAN" 'LAYOUT=dist; return 0' 'LAYOUT=consumer; return 0')"; then
  r="$(laycell "$m" /x/r/core/fixtures/story-evidence-scaffold)"; r2="$(laycell "$m" /x/r/tests/fixtures/story-evidence-scaffold)"
  if [ "$r" = consumer ] && [ "$r2" = consumer ]; then mutant_killed "$(( ${B_layd:-0} && ${B_layc:-0} ))" lay-dist-as-consumer "MUTANT lay-dist-as-consumer (the distribution derived as consumer) is killed by lay_dist; twin lay_consumer still holds"
  else bad "MUTANT lay-dist-as-consumer: want lay_dist consumer and lay_consumer consumer, got [$r] [$r2]"; fi
else bad "FIXTURE BROKEN: mutant lay-dist-as-consumer DID NOT APPLY (its anchor does not occur exactly once in the CAPGUARD span)"; fi

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
  b="$(h2 "$cr" '## Field Verification (API-Consuming Stories)')"
  fl="$(flat <<<"$b")"
  has "$fl" "Baseline-fixture sweep when a diff changes a handler's result shape" \
    || echo "CR: code-reviewer Field Verification has no baseline-fixture sweep"
}

# --- the subject -------------------------------------------------------------
out="$(check "$STS" "$GV" "$DEV" "$QA" "$CR" "$IMP" "$SR")"
if [ -z "$out" ]; then
  ok "scaffold, table vocabulary, Step 5 binding, Check 21 citation set / letter / SKIP, dev and qa handoff evidence past the consumer shadows, code-reviewer sweep, rename re-bind, capture header, pre-gate and sprint-review wiring"
else
  while IFS= read -r l; do bad "$l"; done <<<"$out"
fi

[ "${1:-}" = "--probe-only" ] && exit "$rc"
if ( cd / && bash "$DIR/run.sh" --probe-only ) >/dev/null 2>&1; then
  ok "CWD: the fixture resolves its subjects from / as well as from the repo root"
else
  bad "CWD: run from / the fixture could not resolve or pass its subjects"
fi

# --- mutants -----------------------------------------------------------------
for v in STS GV DEV QA CR IMP SR; do eval "cp \"\${$v}\" \"$WORK/ctl-$v.md\""; done
cout="$(check "$WORK/ctl-STS.md" "$WORK/ctl-GV.md" "$WORK/ctl-DEV.md" "$WORK/ctl-QA.md" "$WORK/ctl-CR.md" "$WORK/ctl-IMP.md" "$WORK/ctl-SR.md")"
if [ -z "$cout" ] && [ -n "$(h2 "$WORK/ctl-DEV.md" '## QA Handoff Evidence')" ] \
   && [ -n "$(h3 "$WORK/ctl-GV.md" '^### 21\. ')" ]; then
  ok "CONTROL: unmutated copies pass and the keyed sections are non-empty, so a mutant's finding below is the mutation"; B_ctl=1
else
  bad "CONTROL: unmutated copies fail -- every mutant verdict below is uninterpretable ($cout)"
fi

mutant() { # <name> <subject var> <awk-program> <expected-finding-prefix> <label> [<text still in file>]
  local name="$1" var="$2" prog="$3" want="$4" label="$5" still="${6:-}" src m res others
  eval "src=\${$var}"
  m="$WORK/$name.md"
  awk "$prog" "$src" > "$m"
  if cmp -s "$src" "$m"; then bad "FIXTURE ERROR: mutation '$name' matched nothing"; return; fi
  if [ -n "$still" ] && ! has "$(flat < "$m")" "$still"; then
    bad "FIXTURE ERROR: mutation '$name' should leave '$still' in the file (it is a MOVE) and did not"
    return
  fi
  local a="$STS" b="$GV" c="$DEV" d="$QA" e="$CR" f="$IMP" g="$SR"
  case "$var" in STS) a="$m" ;; GV) b="$m" ;; DEV) c="$m" ;; QA) d="$m" ;; CR) e="$m" ;; IMP) f="$m" ;; SR) g="$m" ;; esac
  res="$(check "$a" "$b" "$c" "$d" "$e" "$f" "$g")"
  if ! grep -qF -- "$want" <<<"$res"; then bad "MUTATION '$name' SURVIVED -- $label"; return; fi
  others="$(grep -vF -- "$want" <<<"$res")"
  if [ -n "$others" ]; then
    bad "MUTATION '$name' fired other arms too ($others) -- the arms are entangled"
  else
    mutant_killed "${B_ctl:-0}" "$name" "MUTATION '$name' killed by its own arm only: $label"
  fi
}

mutant drop-strategy-heading STS '/^- `## Strategy Test IDs` /{next} {print}' \
  "SCAFFOLD:" "dropping the Strategy Test IDs heading from the scaffold is caught"
mutant move-strategy-heading STS \
  '/^- `## Strategy Test IDs` /{held=$0; next} /^### 2\. Epics and Stories$/{print; print held; next} {print}' \
  "SCAFFOLD:" "moving the Strategy Test IDs heading out of the Pre-Flight Checklist is caught" \
  '`## Strategy Test IDs` — the table below'
mutant open-kind STS '{ gsub(/`Kind` is exactly one of/, "`Kind` is usually one of"); print }' \
  "SCAFFOLD:" "opening the Kind vocabulary is caught"
mutant no-letter-binding STS '{ gsub(/one row per lettered case/, "rows as needed"); print }' \
  "BIND:" "Step 5 no longer writing a row per case letter is caught"
mutant dar-prose-citation GV \
  '{ gsub(/A Dev Agent Record.s prose mention of a test is not a citation\./, "A Dev Agent Record naming a test is a citation."); print }' \
  "C21SET:" "Check 21 accepting a DAR prose mention as a citation is caught"
mutant letter-unchecked GV '/^### 21\. /{s=1} s && /^### 22\. /{s=0} s{ gsub(/A case letter with no row,/, "A test id with no row,") } {print}' \
  "C21LETTER:" "Check 21 no longer failing an unrowed case letter is caught"
mutant skip-as-pass GV '/^### 21\. /{s=1} s && /^### 22\. /{s=0} s{ gsub(/it is$/, "it counts as"); gsub(/^never a PASS\.$/, "a PASS.") } {print}' \
  "C21SKIP:" "Check 21 scoring a table-less strategy as PASS is caught"
mutant dev-into-workflow DEV '/^## QA Handoff Evidence$/{next} {print}' \
  "DEV:" "dev handoff text folded into the shadowed Workflow Per Task section is caught" \
  'before the handoff message'
mutant dev-no-counts DEV '{ gsub(/deselected \//, "/"); print }' \
  "DEV:" "dropping the deselected count from the dev handoff run is caught"
mutant qa-into-checklist QA \
  '/^## Handoff Evidence Precondition$/{h=1; next} h && /^## Validation Checklist$/{h=0; print; printf "%s", buf; next} h{buf=buf $0 "\n"; next} {print}' \
  "QA:" "qa precondition moved into the shadowed Validation Checklist section is caught" \
  'REJECT without validating further'
# The dependency-setup row. Its section precedes neither shadowed section in the same way:
# dev.md's Workflow Per Task sits ABOVE QA Handoff Evidence, so that move buffers the file and
# re-emits the bullet before the heading; qa.md's Validation Checklist sits BELOW the
# precondition, so that move streams. Each MOVE leaves the row in the file (asserted), which a
# whole-file grep would accept. The drops remove one side only, so the dev list and the QA
# list each hold the row on their own.
mutant dev-setup-into-workflow DEV \
  '{a[NR]=$0} END{for(i=1;i<=NR;i++) if(a[i] ~ /^- \*\*The dependency setup that run needs/){s=i; for(e=i+1; e<=NR && a[e] !~ /^- /; e++); break}
    for(i=1;i<=NR;i++){ if(s && i>=s && i<e) continue; if(s && a[i]=="## QA Handoff Evidence"){for(j=s;j<e;j++) print a[j]; print ""} print a[i] }}' \
  "DEV: setup --" "the dev setup row moved into the shadowed Workflow Per Task section is caught" \
  "$SETUP_DEV"
mutant qa-setup-into-checklist QA \
  '/^- the dev.s dependency setup for that run/{h=1; buf=$0 "\n"; next} h && /^- /{h=0} h{buf=buf $0 "\n"; next} /^## Validation Checklist$/{print; printf "%s", buf; next} {print}' \
  "QA: setup --" "the qa setup row moved into the shadowed Validation Checklist section is caught" \
  "$SETUP_QA"
mutant dev-no-setup DEV '/^- \*\*The dependency setup that run needs/{s=1; next} s && /^- /{s=0} !s{print}' \
  "DEV: setup --" "dropping the setup row from dev.md alone is caught"
mutant qa-no-setup QA '/^- the dev.s dependency setup for that run/{s=1; next} s && /^- /{s=0} !s{print}' \
  "QA: setup --" "dropping the setup row from qa.md alone is caught"
mutant cr-no-sweep CR '/Baseline-fixture sweep when a diff changes a handler/{next} {print}' \
  "CR:" "dropping the code-reviewer baseline-fixture sweep is caught"
mutant no-check-21 GV '/^### 21\. /{print "### Test-strategy deliverable presence"; next} {print}' \
  "SECTION check 21" "an unisolatable Check 21 is a finding, not an empty pass"
mutant sts-no-rebind STS '{ gsub(/re-binds every `## Strategy Test IDs` cell naming the old node,/, "updates its own cell,"); print }' \
  "REBIND-STS:" "dropping the cross-story re-bind from Rename Verification is caught"
mutant dev-no-rebind DEV '/^## QA Handoff Evidence$/{s=1} s && /^## Communication$/{s=0} s{ gsub(/re-binds every `## Strategy Test IDs` cell naming the old node,/, "updates the cell,") } {print}' \
  "DEV: rebind --" "dropping the re-bind from dev.md's handoff evidence is caught"
mutant dev-no-label DEV '{ gsub(/a column-0 `Full-collection run:` line/, "a full-collection line"); print }' \
  "DEV: label --" "dropping the column-0 label the validator's LEGACY gate keys on is caught"
mutant dev-no-capture-header DEV '{ gsub(/opens with `\$ <the exact command>` on its first line/, "opens with the output"); print }' \
  "DEV: capture --" "dropping the capture header from dev.md's handoff evidence is caught"
mutant imp-unwired IMP '/^\*\*Pre-gate commit-presence check\.\*\*/{s=1} s && /^$/{s=0} s{ gsub(/and its `--strategy` arm/, "and its strategy arm") } {print}' \
  "WIRE-IMP:" "the pre-gate check not running the strategy mode is caught"
# A MOVE: the bookkeeping kinds pushed past the paragraph's first blank line, which every reader of
# that block (this check, the shipped probes) stops at. They stay in the file.
mutant imp-bk-moved IMP '/^Test IDs cell, `status-not-review`/{print ""} {print}' \
  "WIRE-BK:" "the bookkeeping kinds moved out of the pre-gate paragraph's first block is caught" \
  '`status-yaml-mismatch`'
mutant imp-no-dar-missing IMP '/^\*\*Pre-gate commit-presence check\.\*\*/{s=1} s && /^$/{s=0} s{ gsub(/`dar-missing` for a story/, "`dar-gone` for a story") } {print}' \
  "WIRE-BK:" "the pre-gate paragraph no longer naming the dar-missing refusal is caught"
mutant c11-no-surface GV '{ gsub(/^\*\*Smoke surface\.\*\* /, "Smoke surface. "); print }' \
  "C11SURF:" "the smoke-surface definition losing its bold opening is caught"
mutant c11-no-mech GV '{ gsub(/are enforced by$/, "are read by"); print }' \
  "C11MECH:" "Check 11 no longer naming the mechanical enforcement is caught"
mutant imp-no-smoke IMP '{ gsub(/runs the `--smoke` arm of/, "runs the arm of"); print }' \
  "WIRE-SMOKE:" "the gate-2 dispatch not running --smoke is caught"
mutant sr-unwired SR '{ gsub(/validate-handoff-evidence\.sh --strategy HEAD/, "a re-read of"); print }' \
  "WIRE-SR:" "sprint-review §4 not running the strategy mode is caught"

# --- validate-handoff-evidence.sh, driven ---------------------------------------
# The worlds, the case table, the verdict function and the vector live in world.sh. The MUTATION
# BATTERY over this validator has been retired; this fixture keeps the control vector, the IN PLACE arm, the range and sibling-exit arms.
WORLDS_OK=1
se_build_worlds "hks" || WORLDS_OK=0
if [ "$WORLDS_OK" -eq 1 ] && ! HECTL="$(mk_tree control)"; then
  WORLDS_OK=0; bad "FIXTURE BROKEN: could not build the control tree (scripts dir + schema), or sprint-status.sh is not beside the validator in it"
fi
if [ "$WORLDS_OK" -eq 1 ]; then
  got="$(vector "$HECTL")"
  if [ "$got" = "$WANT" ]; then
    ok "HANDOFF/STRATEGY: each offender refused by its own arm only (no-command, red-untracked, glob-cited, empty-cell, node-missing, status-not-review, status-yaml-mismatch, heading-demoted twice); the rename fails then passes after the re-bind; every near-miss quiet, the no-yaml world prints SKIP STATUS; the head WARN exits 0"
  else
    bad "HANDOFF/STRATEGY: verdict vector differs -- want [$WANT] got [$got] for [$CASES]"
  fi
  # EQUIV: every cell below asks the subjects IN PROCESS (he-inproc.sh). This arm is the seam's proof and the
  # fixture's one END-TO-END run per distinct CLI outcome (fixture-mutants.md clauses 5-6): each row runs
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
  EQWANT='h-refuse 1 h-pass 0 h-uneval 2 s-refuse 1 s-pass 0 g2 0 lc 0 rd 0 rdc-refuse 1 sm 0 ro-paths-refuse 1 ro-paths-pass 0 ro-none-reason 0 ro-none-bare 1 ro-none-not 2 ss-mismatch 0 ss-untracked 0'
  got="$(tr '\n' ' ' < "$WORK/eq.rows")"; got="${got% }"
  if [ "$got" = "$EQWANT" ] && ! cmp -s "$WORK/eq.h-refuse.c" "$WORK/eq.h-pass.c" && ! cmp -s "$WORK/eq.s-refuse.c" "$WORK/eq.s-pass.c" \
     && ! cmp -s "$WORK/eq.ro-paths-refuse.c" "$WORK/eq.ro-paths-pass.c" && ! cmp -s "$WORK/eq.ss-mismatch.c" "$WORK/eq.ss-untracked.c" \
     && grep -q '^REFUSED no-command ' "$WORK/eq.h-refuse.c" && grep -q '^row	ready-for-dev	' "$WORK/eq.ss-mismatch.c"; then
    ok "EQUIV: in process and by CLI, byte-identical output and exit on every row, each refusal differing from its pass (handoff 1/0/2, strategy 1/0, --gate2, --list-captures, --render-dar and its --check refusal, --smoke; record-only-diff.sh paths 1/0 and none-reason 0/1/2; sprint-status.sh story-status twice)"; B_eq=1
  else
    bad "EQUIV: want [$EQWANT] with each refusal differing from its pass, got [$got]"
  fi
  # The SHIPPED validator, in place, beside its real sibling: the control tree above is a copy.
  got="$(verdict "$HE" "$WORK/world-yamlmis" h) $(verdict "$HE" "$WORK/world-noyaml" h)"
  if [ "$got" = "1:status-yaml-mismatch,:W 0::W:S" ]; then
    ok "IN PLACE: the shipped validator reaches its own sprint-status.sh (a row mismatch refuses, a missing yaml prints SKIP STATUS)"
  else
    bad "IN PLACE: the shipped validator did not reach its sibling -- want [1:status-yaml-mismatch,:W 0::W:S] got [$got]"
  fi
  # --gate2 (arm h skipped at a gate-2 go-signal sha). The seeded offender is world-yamlmis, which arm (h)
  # refuses. g2_vec prints, for a script: the flagged run's "<rc>:<refusals>:<SKIP STATUS (--gate2 line seen y/n)>"
  # then the unflagged control's. A mutant that ignores the flag leaves the flagged run refused.
  g2_vec() { # <script> [unflagged] -> the flagged run's "<rc>:<refusals>:<SKIP STATUS (--gate2 line seen y/n)>"; with a 2nd arg, the unflagged control's
    local s="$1" w="$WORK/world-yamlmis" o rc
    if [ -n "${2:-}" ]; then o="$(he_run "$s" -C "$w" "$STORY" "$(cat "$w/.B")" "$(cat "$w/.T")" 2>/dev/null)"; rc=$?
    else o="$(he_run "$s" -C "$w" --gate2 "$STORY" "$(cat "$w/.B")" "$(cat "$w/.T")" 2>/dev/null)"; rc=$?; fi
    printf '%s:%s:%s' "$rc" "$(awk '/^REFUSED /{print $2}' <<<"$o" | tr '\n' ',')" "$(grep -qF 'SKIP STATUS (--gate2' <<<"$o" && echo y || echo n)"
  }
  # The unflagged control is read once, on the control validator: the gate2-ignored mutant edits only the flagged branch.
  G2WANT='0::y'; G2CTL='1:status-yaml-mismatch,:n'
  got="$(g2_vec "$HECTL") $(g2_vec "$HECTL" unflagged)"
  if [ "$got" = "$G2WANT $G2CTL" ]; then ok "GATE2: with --gate2 the row-mismatch story prints SKIP STATUS (--gate2 ...) and is not refused for (h); without it the same story is still refused status-yaml-mismatch"; B_g2=1
  else bad "GATE2: want [$G2WANT $G2CTL] got [$got]"; fi
  if m="$(mkmut gate2-ignored he 'if [ "$GATE2" -eq 1 ]; then' 'if [ "$GATE2" -eq 99 ]; then')" && [ -n "$m" ]; then
    got="$(g2_vec "$m")"
    if [ "$got" = "$G2WANT" ]; then bad "MUTATION 'gate2-ignored' SURVIVED -- a validator ignoring --gate2 still skips arm (h)"
    else mutant_killed "${B_g2:-0}" gate2-ignored "MUTATION 'gate2-ignored' killed: a validator ignoring --gate2 refuses the story for (h) with the flag set [$got]"; fi
  else bad "FIXTURE ERROR: gate2 mutation 'gate2-ignored' matched nothing"; fi
  # (p) DAR-MISSING, a REFUSAL (exit 1). dar_vec reads, per world, "<rc>:<R|W>:<absent|empty>" off the
  # `REFUSED dar-missing` / `WARN dar-missing` line, or "<rc>:-" when neither prints. Refused: daroff
  # (heading deleted) and darfence (heading only inside a fence) absent; darph (graph's placeholder,
  # comment and blank-table template) empty. Passing twins, exit 0: darphok (the same plus one real
  # line), darself (the same plus ONLY the lead's one-line `lead (self-executed` DAR, the remedy the
  # refusal names) and clean (a filled DAR). Each mutant runs only the three refused worlds; the three
  # passing twins are read from the control (an emit edit cannot move a world that never reaches it).
  DAR_WORLDS='daroff darfence darph darphok darself clean'
  DARWANT='1:R:absent 1:R:absent 1:R:empty 0:- 0:- 0:-'
  dar_vec() { # <script> [firing-only]
    local s="$1" v o="" k
    for v in $DAR_WORLDS; do
      if [ -n "${2:-}" ] && { [ "$v" = darphok ] || [ "$v" = darself ] || [ "$v" = clean ]; }; then o="$o 0:-"; continue; fi
      verdict "$s" "$WORK/world-$v" h > /dev/null
      k="$(awk '/^(REFUSED|WARN) dar-missing / { t = (/^REFUSED/) ? "R" : "W"; if (/ is absent at /) print t ":absent"; else if (/ is empty at /) print t ":empty"; else print t ":?" }' <<<"$VERDICT_OUT" | tr '\n' ',')"
      k="${k%,}"
      o="$o $VERDICT_RC:${k:--}"
    done
    printf '%s' "${o# }"
  }
  if build_world "$WORK/world-daroff" daroff && build_world "$WORK/world-darfence" darfence \
     && build_world "$WORK/world-darph" darph && build_world "$WORK/world-darphok" darphok \
     && build_world "$WORK/world-darself" darself; then
    got="$(dar_vec "$HECTL")"
    if [ "$got" = "$DARWANT" ]; then ok "DAR-MISSING: a deleted and a fenced-only Dev Agent Record heading are REFUSED absent and a section of template placeholders REFUSED empty, all exit 1; the same section with one real line, with only the lead's one-line 'lead (self-executed' DAR, and the filled DAR pass with exit 0"; B_dar=1
    else bad "DAR-MISSING: want [$DARWANT] got [$got] for [$DAR_WORLDS]"; fi
    if m="$(mkmut dar-unwired he '        dar) refuse "dar-missing' '        dar-NEVER) refuse "dar-missing')" && [ -n "$m" ]; then
      got="$(dar_vec "$m" firing)"
      if [ "$got" = '0:- 0:- 0:- 0:- 0:- 0:-' ]; then mutant_killed "${B_dar:-0}" dar-unwired "MUTATION 'dar-unwired' killed: a validator whose dar-missing emit never matches passes the three refused worlds with exit 0 and no dar-missing line"
      elif [ "$got" = "$DARWANT" ]; then bad "MUTATION 'dar-unwired' SURVIVED -- the dar-missing refusal still prints with its emit disabled"
      else bad "MUTATION 'dar-unwired' moved [$got], want [0:- 0:- 0:- 0:- 0:- 0:-]"; fi
    else bad "FIXTURE ERROR: dar mutation 'dar-unwired' matched nothing"; fi
    # dar-warn: the tier reverted to the U1b WARN. Killed on the WARN line PRESENT with exit 0, a
    # positive observable, not on the refusal's absence.
    if m="$(mkmut dar-warn he '        dar) refuse "dar-missing' '        dar) warn "dar-missing')" && [ -n "$m" ]; then
      got="$(dar_vec "$m" firing)"
      if [ "$got" = '0:W:absent 0:W:absent 0:W:empty 0:- 0:- 0:-' ]; then mutant_killed "${B_dar:-0}" dar-warn "MUTATION 'dar-warn' killed: a validator whose dar-missing arm is a WARN prints the WARN line and exits 0 on the three refused worlds"
      elif [ "$got" = "$DARWANT" ]; then bad "MUTATION 'dar-warn' SURVIVED -- the dar-missing arm still refuses with its tier reverted to WARN"
      else bad "MUTATION 'dar-warn' moved [$got], want [0:W:absent 0:W:absent 0:W:empty 0:- 0:- 0:-]"; fi
    else bad "FIXTURE ERROR: dar mutation 'dar-warn' matched nothing"; fi
  else
    bad "FIXTURE BROKEN: could not seed the dar-missing worlds"
  fi
  # (p) the fence and skeleton grammar. darfill (a DAR filled only inside a fence) passes; darsub, darmus, dartbd,
  # dartodo, dartodob and darlbl (a section holding only subheadings, a {{...}} token, TBD, TODO, [TODO], or labels
  # with nothing after the colon) are REFUSED empty. Each mutant runs every one of these worlds, since each moves
  # a world the control passes or refuses: dar-fence-stripped (a fenced line skipped again) refuses darfill
  # empty; dar-skeleton-content (the skeleton shapes content again) passes the six.
  DARG_WORLDS='darfill darsub darmus dartbd dartodo dartodob darlbl'
  DARGWANT='0:- 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty'
  if build_world "$WORK/world-darfill" darfill && build_world "$WORK/world-darsub" darsub \
     && build_world "$WORK/world-darmus" darmus && build_world "$WORK/world-dartbd" dartbd \
     && build_world "$WORK/world-dartodo" dartodo && build_world "$WORK/world-dartodob" dartodob \
     && build_world "$WORK/world-darlbl" darlbl; then
    got="$(DAR_WORLDS="$DARG_WORLDS" dar_vec "$HECTL")"
    if [ "$got" = "$DARGWANT" ]; then ok "DAR-GRAMMAR: a Dev Agent Record filled only inside a code fence passes with exit 0; one holding only subheadings, a {{...}} token, TBD, TODO, [TODO] or labels with no value is REFUSED empty, exit 1"; B_darg=1
    else bad "DAR-GRAMMAR: want [$DARGWANT] got [$got] for [$DARG_WORLDS]"; fi
    # Re-anchored inside the BL-510 N3 buffer: the fence-close branch that now flushes fb is the one edited, and
    # mkmut returning a path is the proof it applied (no match is the FIXTURE ERROR below, never a pass).
    if m="$(mkmut dar-fence-stripped he 'if (m == fence) { fence = ""; darn += fb; fb = 0; next } fl = 1 }' 'if (m == fence) fence = ""; next }')" && [ -n "$m" ]; then
      got="$(DAR_WORLDS="$DARG_WORLDS" dar_vec "$m")"
      if [ "$got" = '1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty' ]; then mutant_killed "${B_darg:-0}" dar-fence-stripped "MUTATION 'dar-fence-stripped' killed: a validator that skips fenced lines again refuses darfill empty"
      elif [ "$got" = "$DARGWANT" ]; then bad "MUTATION 'dar-fence-stripped' SURVIVED -- darfill still passes with fenced lines skipped"
      else bad "MUTATION 'dar-fence-stripped' moved [$got], want [1:R:empty and six more]"; fi
    else bad "FIXTURE ERROR: dar mutation 'dar-fence-stripped' matched nothing"; fi
    if m="$(mkmut dar-skeleton-content he '      if (dar_tmpl(t, p)) return 1' '      if (0) return 1')" && [ -n "$m" ]; then
      got="$(DAR_WORLDS="$DARG_WORLDS" dar_vec "$m")"
      if [ "$got" = '0:- 0:- 0:- 0:- 0:- 0:- 0:-' ]; then mutant_killed "${B_darg:-0}" dar-skeleton-content "MUTATION 'dar-skeleton-content' killed: a validator counting subheadings, {{...}}, TBD, TODO, [TODO] and empty labels as content passes all six skeleton worlds"
      elif [ "$got" = "$DARGWANT" ]; then bad "MUTATION 'dar-skeleton-content' SURVIVED -- the skeleton worlds still refuse with the widening reverted"
      else bad "MUTATION 'dar-skeleton-content' moved [$got], want [0:- x7]"; fi
    else bad "FIXTURE ERROR: dar mutation 'dar-skeleton-content' matched nothing"; fi
  else
    bad "FIXTURE BROKEN: could not seed the dar grammar worlds"
  fi
  # (p) BL-510 N1-N3. N1: darn1c / darn1d (a `###` line valued after a colon / a spaced dash) pass; darn1ph /
  # darn1tbd (valued with a {{...}} token / TBD) stay REFUSED empty. N2: darn2b `- TBD`, darn2k `- {{...}}`,
  # darn2n `1. TODO` and darn2s `* {{...}}` REFUSED empty; darn2r `- Model: <value>` passes. N3: daropen (```) and
  # dartopen (~~~) over a token with the rest of the story inside the open fence, and daropenr (a real line in a
  # fence open to EOF) REFUSED empty; darclosed (a real line in a closed fence) passes. N4, `###` values only:
  # darn4dash `: -`, darn4em `: —`, darn4see `- see above`, darn4below `- see below`, darn4hnone `- none`,
  # darn4en `– none`, darn4dot `: None.` and darn4pfx `: – N/A`, darn4enbare `: –`, darn4emnone `: — none` and darn4hynone `: - none` REFUSED empty, one per branch of the rule;
  # darn4nm (`- none of ...`) and darn4seenm (`- wired X; see above`, the `^` anchor) pass, and so do the two
  # base-behaviour regressions darn4pl (a plain `- none` line) and darn4fence (`none` in a closed fence).
  # One mutant per fix; each runs only these worlds and must move only its
  # own: dar-n1-bare (every `###` line skeleton again, the base rule) refuses darn1c and darn1d; dar-n2-no-strip
  # (the list-marker strip deleted outright -- NOT base, which stripped `-`/`+`/`1.` from p only) passes darn2b,
  # darn2k, darn2n and darn2s; dar-n2-no-star (`*` dropped from the strip class) passes darn2s alone;
  # dar-n3-unbuffered (fenced lines counted as read) passes the three open fences; dar-n4-heading-value-content
  # (the N4 test on a `###` value deleted) passes the eleven N4 skeleton worlds.
  # DAR_FULL=1 also drives each mutant over all of DARN_WORLDS (a push runs its deciding worlds and one twin) and over
  # DAR_WORLDS and DARG_WORLDS, and requires its own want there and the control vectors in the other two,
  # the authoring check that each is killed by this arm alone (run once, not per push). hermetic-run.sh runs the
  # fixture under env -i, so the check is run directly: `DAR_FULL=1 bash core/fixtures/story-evidence-scaffold/run.sh`
  # from the repo root.
  DARN_WORLDS='darn1c darn1d darn1ph darn1tbd darn2b darn2k darn2n darn2r darn2s darn4dash darn4em darn4see darn4below darn4hnone darn4en darn4dot darn4pfx darn4enbare darn4emnone darn4hynone darn4nm darn4seenm darn4pl darn4fence daropen dartopen daropenr darclosed'
  DARNWANT='0:- 0:- 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 0:- 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 0:- 0:- 0:- 0:- 1:R:empty 1:R:empty 1:R:empty 0:-'
  darn_ok=1
  for v in $DARN_WORLDS; do build_world "$WORK/world-$v" "$v" || darn_ok=0; done
  if [ "$darn_ok" -eq 1 ]; then
    got="$(DAR_WORLDS="$DARN_WORLDS" dar_vec "$HECTL")"
    if [ "$got" = "$DARNWANT" ]; then ok "DAR-N: a ### line valued after a colon or a spaced dash, a ### value opening none or carrying see above later, a bulleted real value, a plain - none line, none in a closed fence and a real line in a closed fence pass; a ### value that is a {{...}} token, TBD, a bare dash, N/A, none or see above / below, a bulleted - TBD / - {{...}} / * {{...}} / 1. TODO, and a fence left open (backtick or tilde, mid-file or to EOF) are REFUSED empty"; B_darn=1
    else bad "DAR-N: want [$DARNWANT] got [$got] for [$DARN_WORLDS]"; fi
    darn_full() { # <mutant script> <name> <its DARN_WORLDS want>: the authoring check, DAR_FULL=1 only
      [ -n "${DAR_FULL:-}" ] || return 0
      local a g n
      a="$(DAR_WORLDS="$DARG_WORLDS" dar_vec "$1")"; g="$(dar_vec "$1")"; n="$(DAR_WORLDS="$DARN_WORLDS" dar_vec "$1")"
      if [ "$a" = "$DARGWANT" ] && [ "$g" = "$DARWANT" ] && [ "$n" = "$3" ]; then ok "DAR-N FULL: mutant '$2' moves no DAR or DAR-GRAMMAR world, and every DAR-N world reads its want"
      else bad "DAR-N FULL: mutant '$2' moved DAR [$g] DAR-GRAMMAR [$a] DAR-N [$n]"; fi
    }
    # fixture-mutants.md clause 2: a push runs each N mutant over its DECIDING worlds (every world where its want
    # differs from DARNWANT) and ONE twin (the first world where they agree), both derived from the want below, so
    # the kill condition is the want restricted to those worlds. The whole 28-world vector is darn_full's.
    darn_sel() { # <a mutant's DARN_WORLDS want> -> DARN_SEL="<deciding worlds> <twin>", DARN_TWIN
      local -a mw cw nm; mw=($1); cw=($DARNWANT); nm=($DARN_WORLDS)
      local i d="" t=""
      for ((i = 0; i < ${#nm[@]}; i++)); do
        if [ "${mw[i]}" != "${cw[i]}" ]; then d="$d ${nm[i]}"; elif [ -z "$t" ]; then t="${nm[i]}"; fi
      done
      DARN_TWIN="$t"; DARN_SEL="${d# } $t"
    }
    darn_pick() { # <a DARN_WORLDS vector> <world names> -> the vector's words at those worlds
      local -a v nm; v=($1); nm=($DARN_WORLDS)
      local w i o=""
      for w in $2; do for ((i = 0; i < ${#nm[@]}; i++)); do [ "${nm[i]}" = "$w" ] && o="$o ${v[i]}"; done; done
      printf '%s' "${o# }"
    }
    darn_mut() { # <mutant script> <its DARN_WORLDS want> <survived message> <moved message> -> 0 when its kill holds
      local got ctl
      darn_sel "$2"
      got="$(DAR_WORLDS="$DARN_SEL" dar_vec "$1")"; ctl="$(darn_pick "$DARNWANT" "$DARN_SEL")"
      # A kill must MOVE a selected world: a selection holding no deciding world reads the control and is no kill.
      [ "$got" = "$(darn_pick "$2" "$DARN_SEL")" ] && [ "$got" != "$ctl" ] && return 0
      if [ "$got" = "$ctl" ]; then bad "$3"
      else bad "$4; got [$got] over [$DARN_SEL]"; fi
      return 1
    }
    if m="$(mkmut dar-n1-bare he 'if (t ~ /^###/) { h = t;' 'if (t ~ /^###/) return 1; if (0) { h = t;')" && [ -n "$m" ]; then
      want='1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 0:- 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 0:- 0:- 1:R:empty 1:R:empty 1:R:empty 0:-'
      if darn_mut "$m" "$want" "MUTATION 'dar-n1-bare' SURVIVED -- the valued ### worlds still pass with the N1 rule reverted" "MUTATION 'dar-n1-bare' moved: want darn1c darn1d darn4nm darn4seenm at 1:R:empty"; then mutant_killed "${B_darn:-0}" dar-n1-bare "MUTATION 'dar-n1-bare' killed: a validator reading every ### line as skeleton refuses darn1c, darn1d, darn4nm and darn4seenm empty (twin $DARN_TWIN holds)"; fi
      darn_full "$m" dar-n1-bare "$want"
    else bad "FIXTURE ERROR: dar mutation 'dar-n1-bare' matched nothing"; fi
    if m="$(mkmut dar-n2-no-strip he 'sub(/^([-+*]|[0-9]+\.)[ \t]+/, "", t); sub(/^([-+*]|[0-9]+\.)[ \t]+/, "", p)' '')" && [ -n "$m" ]; then
      want='0:- 0:- 1:R:empty 1:R:empty 0:- 0:- 0:- 0:- 0:- 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 0:- 0:- 0:- 0:- 1:R:empty 1:R:empty 1:R:empty 0:-'
      if darn_mut "$m" "$want" "MUTATION 'dar-n2-no-strip' SURVIVED -- the bulleted skeleton worlds still refuse with the strip removed" "MUTATION 'dar-n2-no-strip' moved: want darn2b darn2k darn2n darn2s at 0:-"; then mutant_killed "${B_darn:-0}" dar-n2-no-strip "MUTATION 'dar-n2-no-strip' killed: a validator that strips no list marker before the token tests passes darn2b, darn2k, darn2n and darn2s (twin $DARN_TWIN holds)"; fi
      darn_full "$m" dar-n2-no-strip "$want"
    else bad "FIXTURE ERROR: dar mutation 'dar-n2-no-strip' matched nothing"; fi
    if m="$(mkmut dar-n2-no-star he 'sub(/^([-+*]|[0-9]+\.)[ \t]+/, "", t); sub(/^([-+*]|[0-9]+\.)[ \t]+/, "", p)' 'sub(/^([-+]|[0-9]+\.)[ \t]+/, "", t); sub(/^([-+]|[0-9]+\.)[ \t]+/, "", p)')" && [ -n "$m" ]; then
      want='0:- 0:- 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 0:- 0:- 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 0:- 0:- 0:- 0:- 1:R:empty 1:R:empty 1:R:empty 0:-'
      if darn_mut "$m" "$want" "MUTATION 'dar-n2-no-star' SURVIVED -- the star-bulleted token world still refuses with the star dropped from the strip" "MUTATION 'dar-n2-no-star' moved: want darn2s alone at 0:-"; then mutant_killed "${B_darn:-0}" dar-n2-no-star "MUTATION 'dar-n2-no-star' killed: a validator whose list-marker strip omits the star passes darn2s (twin $DARN_TWIN holds)"; fi
      darn_full "$m" dar-n2-no-star "$want"
    else bad "FIXTURE ERROR: dar mutation 'dar-n2-no-star' matched nothing"; fi
    if m="$(mkmut dar-n3-unbuffered he 'if (ind && !dar_ph(t)) fb++; next }' 'if (ind && !dar_ph(t)) darn++; next }')" && [ -n "$m" ]; then
      # daropen and dartopen read 1:- (no dar-missing line; exit 1 from the arms that refuse the later sections the
      # open fence swallows), daropenr 0:- (the DAR is the last section, so nothing else refuses).
      want='0:- 0:- 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 0:- 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 0:- 0:- 0:- 0:- 1:- 1:- 0:- 0:-'
      if darn_mut "$m" "$want" "MUTATION 'dar-n3-unbuffered' SURVIVED -- the open-fence worlds still refuse with the buffer removed" "MUTATION 'dar-n3-unbuffered' moved: want daropen dartopen at 1:-, daropenr at 0:-"; then mutant_killed "${B_darn:-0}" dar-n3-unbuffered "MUTATION 'dar-n3-unbuffered' killed: a validator counting fenced lines as it reads them drops the dar-missing refusal on daropen, dartopen and daropenr (twin $DARN_TWIN holds)"; fi
      darn_full "$m" dar-n3-unbuffered "$want"
    else bad "FIXTURE ERROR: dar mutation 'dar-n3-unbuffered' matched nothing"; fi
    if m="$(mkmut dar-n4-heading-value-content he 'q = tolower(h); gsub(/^[ \t]+|[ \t]+$/, "", q); if (q ~ /^(—|–|-)$/) return 1; sub(/^(—|–|-)[ \t]*/, "", q); if (q ~ /^(n\/a|none|see (above|below))\.?$/) return 1' '')" && [ -n "$m" ]; then
      want='0:- 0:- 1:R:empty 1:R:empty 1:R:empty 1:R:empty 1:R:empty 0:- 1:R:empty 0:- 0:- 0:- 0:- 0:- 0:- 0:- 0:- 0:- 0:- 0:- 0:- 0:- 0:- 0:- 1:R:empty 1:R:empty 1:R:empty 0:-'
      if darn_mut "$m" "$want" "MUTATION 'dar-n4-heading-value-content' SURVIVED -- the N4 worlds still refuse with the heading-value test removed" "MUTATION 'dar-n4-heading-value-content' moved: want the eleven N4 ### worlds at 0:-"; then mutant_killed "${B_darn:-0}" dar-n4-heading-value-content "MUTATION 'dar-n4-heading-value-content' killed: a validator reading a ### value of a bare dash, N/A, none or see above / below as content passes the eleven N4 worlds (twin $DARN_TWIN holds)"; fi
      darn_full "$m" dar-n4-heading-value-content "$want"
    else bad "FIXTURE ERROR: dar mutation 'dar-n4-heading-value-content' matched nothing"; fi
  else
    bad "FIXTURE BROKEN: could not seed the BL-510 dar worlds"
  fi
  # The range warning: base == frozen and a base that is not an ancestor of frozen each WARN
  # (exit 0, never a refusal); the normal range carries neither. Each mutant silences one.
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
  if [ "$got" = "$RWANT" ]; then ok "RANGE: base == frozen and a non-ancestor base each WARN and exit 0; the story's own range warns nothing"; B_range=1
  else bad "RANGE: want [$RWANT] got [$got]"; fi
  range_mutant() { # <name> <from> <to> <want vector> <label>
    local m got
    if ! m="$(mkmut "$1" he "$2" "$3")" || [ -z "$m" ]; then bad "FIXTURE ERROR: range mutation '$1' matched nothing"; return; fi
    got="$(range_vec "$m")"
    if [ "$got" = "$4" ]; then mutant_killed "${B_range:-0}" "$1" "MUTATION '$1' killed, moving its own range cell only: $5"
    elif [ "$got" = "$RWANT" ]; then bad "MUTATION '$1' SURVIVED -- $5"
    else bad "MUTATION '$1' moved [$got], want [$4] -- the cells are entangled"; fi
  }
  range_mutant no-range-empty 'warn "range-empty' ': "range-empty' '0: 0:range-base:, n:' "base == frozen no longer warns"
  range_mutant no-range-base 'warn "range-base' ': "range-base' '0:range-empty:, 0: n:' "a non-ancestor base no longer warns"

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
  if [ "$got" = "$RPWANT" ]; then ok "REPLAY-PREAMBLE: a hand '\$ ' above the script's own refuses (with and without a second '\$ '), a replay at line 1 and the script's '\$ ' right above the replay are accepted, and head: is read from the replay block, falling back to the first head: when the block has none"; B_rp=1
  else bad "REPLAY-PREAMBLE: want [$RPWANT] got [$got]"; fi
  rp_mutant() { # <name> <from> <to> <want> <label>
    local m got
    if ! m="$(mkmut "$1" he "$2" "$3")" || [ -z "$m" ]; then bad "FIXTURE ERROR: replay mutation '$1' matched nothing"; return; fi
    got="$(rp_vec "$m")"
    if [ "$got" = "$4" ]; then mutant_killed "${B_rp:-0}" "$1" "MUTATION '$1' killed, moving its own cell only: $5"
    elif [ "$got" = "$RPWANT" ]; then bad "MUTATION '$1' SURVIVED -- $5"
    else bad "MUTATION '$1' moved [$got], want [$4] -- the cells are entangled"; fi
  }
  # ANY `$ ` right above the replay, not the FIRST: the last `$ ` before the replay is read.
  rp_mutant rp-any-dollar '!fd && /^\$ /{fd=NR}' '/^\$ /{fd=NR}' \
    '0::W 1:replay-preamble,:W 0::W 0::W head=head-tree fallback=head-tree u8=1:replay-preamble,:W' "a hand '\$ ' above the script's own '\$ ' line is accepted"
  rp_mutant rp-first-head 'tail -n +"$rl" <<<"$hdr"' 'tail -n +1 <<<"$hdr"' \
    '1:replay-preamble,:W 1:replay-preamble,:W 0::W 0::W head= fallback=head-tree u8=1:replay-preamble,:W' "the first head: in the capture is read, not the replay block's"
  # U8: the pre-fix capture shape (rpu8) under a UTF-8 locale. Reverting `LC_ALL=C awk` makes the awk
  # abort on the non-UTF-8 line, `rp` empty, and the refusal stand down (0 here instead of 1).
  if [ -n "$UTF8_LOCALE" ]; then
    rp_mutant rp-no-lcc 'rp="$(LC_ALL=C awk' 'rp="$(awk' \
      '1:replay-preamble,:W 1:replay-preamble,:W 0::W 0::W head=head-tree fallback=head-tree u8=0::W:E' "the replay-preamble awk in the caller's locale (no LC_ALL=C): a non-UTF-8 capture stands the refusal down"
  else
    printf '  SKIP  no UTF-8 locale aborts this awk — rp-no-lcc did NOT run\n'
  fi

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
    if [ "$got" = "$ABSWANT" ]; then ok "ABSOLUTE STORY: an absolute story path, physical or through a symlinked alias, reads as the relative one; a relative climb and a lnk/.. hop out of the tree exit 2 (UNEVALUABLE, no read); strategy mode reads the ref, not the working tree"; B_abs=1
    else bad "ABSOLUTE STORY: want [$ABSWANT] got [$got]"; fi
    # Mutant: the raw path in both modes. Every layer is reverted: both norm_story calls go, and the
    # disk fallback reads an absolute story as given and a relative one under -C, as 0.910.0 did.
    m="$(dirname "$HECTL")/he-mut-raw-story.sh"
    FROM1='STORY="$(norm_story "$1")" || exit 2' TO1='STORY="$1"' FROM2='s="$(norm_story "$s")" || exit 2' TO2=':' \
      FROM3='[ -f "$TOP/$2" ] && { cat "$TOP/$2"; return 0; }' \
      TO3='case "$2" in /*) [ -f "$2" ] && { cat "$2"; return 0; } ;; *) [ -f "$REPO/$2" ] && { cat "$REPO/$2"; return 0; } ;; esac' \
      awk 'BEGIN{for (i=1; i<=3; i++) {f[i]=ENVIRON["FROM" i]; t[i]=ENVIRON["TO" i]}}
        {for (i=1; i<=3; i++) if (p=index($0,f[i])) {$0=substr($0,1,p-1) t[i] substr($0,p+length(f[i])); n++}}
        {print} END{exit (n==3) ? 0 : 1}' "$HE" > "$m"
    if [ $? -ne 0 ] || cmp -s "$HE" "$m"; then bad "FIXTURE ERROR: mutation 'raw-story' did not apply at all three sites"
    else
      RAWWANT='1:story-untracked, 1:story-untracked, 1:story-untracked, 1:story-untracked, climb=1 lnk=1 sdirty=1 scommit=1'
      got="$(abs_vec "$m")"
      if [ "$got" = "$RAWWANT" ]; then mutant_killed "${B_abs:-0}" raw-story "MUTATION 'raw-story' killed: the raw path refuses an absolute story as story-untracked, reads both escapes, and reads strategy mode's working tree"
      elif [ "$got" = "$ABSWANT" ]; then bad "MUTATION 'raw-story' SURVIVED -- the story path used raw in both modes"
      else bad "MUTATION 'raw-story' moved [$got], want [$RAWWANT]"; fi
    fi
    # STORY SYMLINK (BL-770). norm_story contains the story's DIRECTORY and keeps the link name, so
    # an untracked story that is itself a symlink is held to the same containment by story_text.
    # Cells, strategy mode at HEAD: an untracked symlink to a file OUTSIDE the tree whose bytes
    # carry an empty cell (2, never read; the read would give 1); an untracked symlink to an
    # in-tree clean copy (0, still readable); a TRACKED symlink blob to that same outside file (0:
    # `git show` emits the link string, nothing outside is read). Mutant 'no-story-symlink' drops
    # the -L check and moves the outside cell only, to 1 (the outside file was read).
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
      if [ "$got" = "$SYMWANT" ]; then ok "STORY SYMLINK: an untracked story symlinked out of the tree exits 2 (relative and absolute), one symlinked to an in-tree file is read, and a tracked symlink blob reads as its link string"; B_sym=1
      else bad "STORY SYMLINK: want [$SYMWANT] got [$got]"; fi
      if ! m="$(mkmut no-story-symlink he 'if [ -L "$TOP/$2" ]; then' 'if false; then')" || [ -z "$m" ]; then
        bad "FIXTURE ERROR: mutation 'no-story-symlink' matched nothing"
      else
        got="$(sym_vec "$m")"
        if [ "$got" = 'out=1 outabs=1 in=0 tracked=0' ]; then mutant_killed "${B_sym:-0}" no-story-symlink "MUTATION 'no-story-symlink' killed: without the -L check the outside file is read (empty-cell)"
        elif [ "$got" = "$SYMWANT" ]; then bad "MUTATION 'no-story-symlink' SURVIVED -- an untracked story symlink out of the tree is read"
        else bad "MUTATION 'no-story-symlink' moved [$got], want [out=1 outabs=1 in=0 tracked=0]"; fi
      fi
    else
      bad "FIXTURE BROKEN: could not seed the story-symlink cells"
    fi
  else
    bad "FIXTURE BROKEN: could not seed the absolute-story world"
  fi
  # (k)/(l) BL-768, the run-record arms. fc_vec reads the sixteen run-record worlds; each mutant is
  # written into the control tree (so record-only-diff.sh is its sibling) and must move only its own
  # cells. The partition and grammar mutants edit the HELPER copy, in a tree of their own.
  FCWANT='0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0::W'
  # fc_vec <script> [<want>]: with a <want> vector (a mutant's), only the worlds whose cell it MOVES are run, and
  # every other cell is reported as FCWANT's value -- a mutant runs the worlds its arm decides (fixture-mutants.md
  # clause 2). Without one, every world runs (the control). "Only its own cells" is established at authoring by
  # the full run the MUTANT-MATRIX-REMEASURE line names (FC_FULL=1).
  FC_WORLDS='fcrec fccode fcbare fcgone dsgone dsbare devold devnew fcevil fcna fctbd fcempty fcnext dsna diskold disknew fcfence fcinvoc fcbold fcnonebt fcmake dsvenv'
  fc_vec() { # <script> [<want>]
    local s="$1" w="${2:-}" o="" v i=0 a b
    for v in $FC_WORLDS; do
      i=$((i + 1))
      if [ -n "$w" ] && [ -z "${FC_FULL:-}" ]; then
        a="$(awk -v n="$i" '{print $n}' <<<"$FCWANT")"; b="$(awk -v n="$i" '{print $n}' <<<"$w")"
        if [ "$a" = "$b" ]; then o="$o $a"; continue; fi
      fi
      o="$o $(verdict "$s" "$WORK/world-$v" h)"
    done
    printf '%s' "${o# }"
  }
  got="$(fc_vec "$HECTL")"
  if [ "$got" = "$FCWANT" ]; then ok "RUN-RECORD: a reasoned none over a story+yamls+docs/reviews+test-results diff accepted, over a diff touching a test refused full-collection-none, a bare none refused, a missing line refused, a dependency-setup none with no reason refused, dev.md without the label prescription is LEGACY and with it refuses both missing lines; a .py under test-results/ and a conftest.py under docs/reviews/ make a record diff non-record; N/A, TBD and an empty value over a code diff each refused, an empty value continued by the invocation accepted, a dependency-setup N/A refused; dev.md untracked at <frozen> but on disk keys LEGACY both ways; an empty value over a fenced run and over \`- Invocation:\` accepted, over a bold label refused; a none carrying a runner span and a two-word span naming no runner refused; a venv interpreter with its packages accepted as a setup"; B_fc=1
  else bad "RUN-RECORD: want [$FCWANT] got [$got]"; fi
  fc_mutant() { # <name> <he|ro> <from> <to> <want> <label>
    local m got t
    if [ "$2" = ro ]; then
      t="$(mk_tree "$1")" || { bad "FIXTURE ERROR: run-record mutation '$1' could not build its tree"; return; }
      FROM="$3" TO="$4" awk 'BEGIN{f=ENVIRON["FROM"]; t=ENVIRON["TO"]} !done && (p=index($0,f)) {$0=substr($0,1,p-1) t substr($0,p+length(f)); done=1} {print}' \
        "$(dirname "$HE")/record-only-diff.sh" > "$(dirname "$t")/record-only-diff.sh.tmp"
      if cmp -s "$(dirname "$HE")/record-only-diff.sh" "$(dirname "$t")/record-only-diff.sh.tmp"; then bad "FIXTURE ERROR: run-record mutation '$1' matched nothing"; return; fi
      mv "$(dirname "$t")/record-only-diff.sh.tmp" "$(dirname "$t")/record-only-diff.sh"; m="$t"
    elif ! m="$(mkmut "$1" he "$3" "$4")" || [ -z "$m" ]; then bad "FIXTURE ERROR: run-record mutation '$1' matched nothing"; return; fi
    got="$(fc_vec "$m" "$5")"
    if [ "$got" = "$5" ]; then mutant_killed "${B_fc:-0}" "$1" "MUTATION '$1' killed, moving its own cells only: $6"
    elif [ "$got" = "$FCWANT" ]; then bad "MUTATION '$1' SURVIVED -- $6"
    else bad "MUTATION '$1' moved [$got], want [$5] -- the cells are entangled"; fi
  }
  # The partition's record directories dropped: the record world (docs/reviews, test-results) refuses.
  fc_mutant ro-no-record-dirs ro '        docs/reviews/*|test-results/*|docs/escalations/*)' '        NEVER-A-RECORD-PATH)' \
    '1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0::W' \
    "the record directories dropped from the record-only partition"
  # The code-suffix exclusion inside the record directories dropped: fcevil's test module is a record.
  fc_mutant ro-no-suffix ro '            *.py|*.sh|*.toml|*.cfg|conftest.py|pytest.ini) first="$p" ;;' '            NEVER-A-SUFFIX) first="$p" ;;' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0::W' \
    "a collectable .py / conftest.py under a record directory classed record-only"
  # The exemption check dropped: any reasoned none passes, so the code-touching none is accepted.
  fc_mutant fc-no-diff he "    || refuse \"\$3 \$STORY: '\$1 \${2:-<empty>}' records no run" "    || : \"\$3 \$STORY: '\$1 \${2:-<empty>}' records no run" \
    '0: 0: 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 0: 0: 0: 0: 0::W 0: 1:dependency-setup-missing,full-collection-missing, 0: 0: 0: 0: 0: 0::W' \
    "a reasoned none accepted whatever the diff"
  # The none grammar's reason requirement dropped: a bare `none` reads as reasoned.
  fc_mutant ro-bare-none ro '        "$w") rest=""; exit 1 ;;' '        "$w") exit 0 ;;' \
    '0: 1:full-collection-none, 0: 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0::W' \
    "a none with no reason accepted"
  fc_mutant ds-no-missing he '    refuse "dependency-setup-missing' '    : "dependency-setup-missing' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 0::W 1:dependency-setup-none,:W 0: 1:full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 0: 1:full-collection-missing, 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0::W' \
    "a missing dependency-setup line accepted"
  # The LEGACY gate dropped: dev.md at <frozen> is never read, so the old installed dev.md refuses.
  fc_mutant fc-no-legacy he 'if [ "$ev_rd" = 1 ] && ! grep' 'if false && ! grep' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 1:dependency-setup-missing,full-collection-missing, 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 1:dependency-setup-missing,full-collection-missing, 1:dependency-setup-missing,full-collection-missing, 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0::W' \
    "the installed-dev.md LEGACY gate dropped"
  # The on-disk fallback dropped: a dev.md untracked at <frozen> is unreadable, so diskold is held.
  fc_mutant fc-no-disk he 'if [ "$ev_rd" = 0 ]; then' 'if false; then' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 1:dependency-setup-missing,full-collection-missing, 1:dependency-setup-missing,full-collection-missing, 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0::W' \
    "the on-disk dev.md is not read when none is tracked at <frozen>"
  # The inversion reverted: only a none form is a no-run claim, so N/A, TBD and an empty value pass.
  fc_mutant fc-no-invert he '  elif ! bash "$RO" run-shape "$fc" ${ev_conv:+"$ev_conv"}; then' '  elif bash "$RO" none-reason "$fc" 2>/dev/null; [ $? -ne 2 ]; then' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 0: 0: 0: 0: 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 0: 0: 1:full-collection-none, 0: 0::W' \
    "a no-run claim spelled other than none accepted over a code diff"
  # The label's next-line continuation dropped: an empty value followed by the invocation refuses.
  fc_mutant ro-no-continue ro '        cont = 1; next }' '        print v; done = 1; exit }' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0::W' \
    "an empty label value continued by the invocation on the next line refused"
  # The fenced continuation dropped: an empty label over a fenced run reads as empty (fcfence refuses).
  fc_mutant ro-no-fence ro '{ f = !f; if (cont && f && !post) inf = 1;' '{ f = !f; if (0) inf = 1;' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0::W' "an empty label value over a fenced run refused"
  # The bold label refusal dropped: a bold label line under an empty value is taken as the value.
  fc_mutant ro-no-bold ro ' || t ~ /^\*\*[A-Za-z][A-Za-z0-9 _-]*(:\*\*|\*\*:)/ }' ' }' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 0: 0: 1:full-collection-none, 1:full-collection-none, 0::W' "a bold label line taken as the continued value"
  # The Invocation continuation dropped: `- Invocation: <cmd>` under an empty value reads as a new label.
  fc_mutant ro-no-invocation ro '             else if (s ~ /^Invocation:[ \t]/)' '             else if (0)' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0::W' "an Invocation: line under an empty value read as a new label"
  # The no-run reading not decided first: a none whose reason holds a runner span reads as a run.
  fc_mutant ro-shape-none-last ro '    (ro_none_reason none-reason "$2") >/dev/null 2>&1; [ $? -eq 2 ] || exit 1' '    :' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 0: 1:full-collection-none, 0: 1:full-collection-none, 0::W' "a none form carrying a runner span read as a run"
  # The runner requirement dropped: any backticked span is a run, so `make docs` acquits.
  fc_mutant ro-shape-any-span ro '    grep -qE "(^|[[:space:]/\`])($rs_rn)([[:space:]\`]|\$)" <<<"$rs_sp" && exit 0' '    [ -n "$rs_sp" ] && exit 0' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 0: 1:full-collection-none, 1:full-collection-none, 0: 0::W' "a backticked span naming no runner read as a run"
  # The interpreter-path setup dropped: a venv interpreter with its packages reads as no setup.
  fc_mutant ro-setup-no-venv ro "      grep -qE '/bin/python|venv' <<<\"\$rs_sp\" \\" '      false \' \
    '0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-missing, 1:dependency-setup-missing,:W 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:dependency-setup-none,:W 0: 1:dependency-setup-missing,full-collection-missing, 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:dependency-setup-none,:W' "a dependency setup naming a venv interpreter and its packages refused"

  # BL-768: the dev gate passes the project's conventions file to run-shape as the QA side does.
  # fcconv (tox -e all declared canonical) is accepted, fcconv-none (same value, no file) is refused,
  # and a validator that drops the conventions argument refuses fcconv.
  if build_world "$WORK/world-fcconv" fcconv && build_world "$WORK/world-fcconv-none" fcconv-none; then
    cv_c="$(verdict "$HECTL" "$WORK/world-fcconv" h)"; cv_n="$(verdict "$HECTL" "$WORK/world-fcconv-none" h)"
    if [ "$cv_c" = '0:' ] && [ "$cv_n" = '1:full-collection-none,' ]; then
      ok "CONVENTIONS: a runner the conventions declare canonical (tox -e all) is accepted at the dev gate, and the same value with no conventions file is refused full-collection-none"; B_conv=1
    else bad "CONVENTIONS: want [0:] and [1:full-collection-none,] got [$cv_c] and [$cv_n]"; fi
    if cv_m="$(mkmut fc-no-conv he 'run-shape "$fc" ${ev_conv:+"$ev_conv"}; then' 'run-shape "$fc"; then')" && [ -n "$cv_m" ]; then
      cv_mv="$(verdict "$cv_m" "$WORK/world-fcconv" h)"
      if [ "$cv_mv" = '1:full-collection-none,' ]; then mutant_killed "${B_conv:-0}" fc-no-conv "MUTATION 'fc-no-conv' killed: the dev gate dropping the conventions argument refuses fcconv"
      elif [ "$cv_mv" = "$cv_c" ]; then bad "MUTATION 'fc-no-conv' SURVIVED -- the dev gate drops the conventions argument"
      else bad "MUTATION 'fc-no-conv' moved [$cv_mv], want [1:full-collection-none,]"; fi
    else bad "FIXTURE ERROR: mutation 'fc-no-conv' matched nothing"; fi
  else bad "FIXTURE BROKEN: could not seed the conventions worlds"; fi

  # POINTER: run-shape's pointer-word refusal, in a world only it decides (fcsee: `see` opens a value that carries a
  # runner span and a count and is no none form), with its near-miss (fcseenm: the same span and count, `see` not
  # opening). Mutant ro-no-pointer drops the pointer rule from record-only-diff.sh in a tree of its own and moves
  # fcsee only, to accepted.
  if build_world "$WORK/world-fcsee" fcsee && build_world "$WORK/world-fcseenm" fcseenm; then
    pt_vec() { printf '%s %s' "$(verdict "$1" "$WORK/world-fcsee" h)" "$(verdict "$1" "$WORK/world-fcseenm" h)"; }
    PTWANT='1:full-collection-none, 0:'
    got="$(pt_vec "$HECTL")"
    if [ "$got" = "$PTWANT" ]; then ok "POINTER: a value opening with see, carrying a runner span and a count, is refused full-collection-none over a code diff; the same span and count with see later in the value is a run"; B_pt=1
    else bad "POINTER: want [$PTWANT] got [$got]"; fi
    if pt_t="$(mk_tree ro-no-pointer)"; then
      FROM="    grep -qE '^(see|refer|n/a|na|tbd|todo|deferred|pending)([^a-z0-9]|\$)' <<<\"\$rs_lc\" && exit 1" TO='    :' \
        awk 'BEGIN{f=ENVIRON["FROM"]; t=ENVIRON["TO"]} !done && (p=index($0,f)) {$0=substr($0,1,p-1) t substr($0,p+length(f)); done=1} {print}' \
        "$(dirname "$HE")/record-only-diff.sh" > "$(dirname "$pt_t")/record-only-diff.sh.tmp"
      if cmp -s "$(dirname "$HE")/record-only-diff.sh" "$(dirname "$pt_t")/record-only-diff.sh.tmp"; then bad "FIXTURE ERROR: mutation 'ro-no-pointer' matched nothing"
      else
        mv "$(dirname "$pt_t")/record-only-diff.sh.tmp" "$(dirname "$pt_t")/record-only-diff.sh"
        got="$(verdict "$pt_t" "$WORK/world-fcsee" h)"
        if [ "$got" = '0:' ]; then mutant_killed "${B_pt:-0}" ro-no-pointer "MUTATION 'ro-no-pointer' killed by cell fcsee: without the pointer rule a see-opened value is read as a run"
        elif [ "$got" = '1:full-collection-none,' ]; then bad "MUTATION 'ro-no-pointer' SURVIVED -- the pointer-word rule dropped"
        else bad "MUTATION 'ro-no-pointer' moved fcsee to [$got], want [0:]"; fi
      fi
    else bad "FIXTURE ERROR: run-record mutation 'ro-no-pointer' could not build its tree"; fi
  else bad "FIXTURE BROKEN: could not seed the pointer worlds"; fi

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
      ok "SIBLING EXIT: a sprint-status.sh exiting 3 after its story line still lets (g) refuse status-not-review, and the row half prints one SKIP STATUS naming the exit; the same wrapper at exit 0 prints none"; B_rc3=1
    else
      bad "SIBLING EXIT: want [$RCWANT] and one SKIP STATUS naming exit 3, got [$got] and $skip_line"
    fi
    # M1: arm (g) gated on the sibling's exit. Written beside each wrapper so it calls that one.
    m1_kill="" m1_ctl=""
    for t in "$RC3" "$RC0"; do
      m="$(dirname "$t")/he-mut-skip-on-exit.sh"
      FROM='if [ -z "$st_line" ]; then' TO='if [ -z "$st_line" ] || [ "$ss_rc" -ne 0 ]; then' \
        awk 'BEGIN{f=ENVIRON["FROM"]; t=ENVIRON["TO"]} !done && (p=index($0,f)) {$0=substr($0,1,p-1) t substr($0,p+length(f)); done=1} {print}' "$HE" > "$m"
      if cmp -s "$HE" "$m"; then bad "FIXTURE ERROR: mutation 'skip-on-exit' matched nothing"; m1_kill=x; break; fi
      if [ "$t" = "$RC3" ]; then m1_kill="$(verdict "$m" "$WORK/world-notreview" k)"; else m1_ctl="$(verdict "$m" "$WORK/world-notreview" k)"; fi
    done
    if [ "$m1_kill" = x ]; then :
    elif [ "$m1_kill" = '0::W:S' ] && [ "$m1_ctl" = '1:status-not-review,:W' ]; then
      mutant_killed "${B_rc3:-0}" skip-on-exit "MUTATION 'skip-on-exit' killed: arm (g) gated on the sibling's exit reads the story line as a SKIP at exit 3 (identity control at exit 0 still refuses)"
    elif [ "$m1_kill" = '1:status-not-review,:W:S' ]; then
      bad "MUTATION 'skip-on-exit' SURVIVED -- arm (g) gated on the sibling's exit"
    else
      bad "MUTATION 'skip-on-exit' moved [$m1_kill / $m1_ctl], want [0::W:S / 1:status-not-review,:W]"
    fi
  else
    bad "FIXTURE BROKEN: could not build the wrapped sprint-status.sh trees"
  fi

  # --- BL-833 RED LINE (rv_*) -----------------------------------------------------------------------
  # One world, one validator call per program, read per cell by token: rv_block in world.sh, whose header
  # carries the cells, the mutants and the BL-834 invocation count.
  rv_block
  # --- end BL-833 RED LINE --------------------------------------------------------------------------

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
  # accepted); wv957-co-alias (`--collectonly`, pytest's third spelling: refused). wv_vec, as fc_vec, runs only the
  # worlds a mutant's want vector moves; WV_FULL=1 runs all of them for a mutant (the authoring measurement).
  WV_WORLDS='wv957cobt wv957cobare wv957codollar wv957codar wv957cov wv957color wv957wvbase wv957wvrange wv957wvtree wv957codir wv957codollardir wv957codollarmid wv957cospan wv957rundir wv957cocomma wv957cosemi wv957covcomma wv957coalias'
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
    WVWANT='1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none,:W 0: 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:full-collection-none, 1:full-collection-none, 0: 1:full-collection-none,'
    wv_vec() { # <script> [<want>]
      local s="$1" w="${2:-}" o="" v i=0 a b
      for v in $WV_WORLDS; do
        i=$((i + 1))
        if [ -n "$w" ] && [ -z "${WV_FULL:-}" ]; then
          a="$(awk -v n="$i" '{print $n}' <<<"$WVWANT")"; b="$(awk -v n="$i" '{print $n}' <<<"$w")"
          if [ "$a" = "$b" ]; then o="$o $a"; continue; fi
        fi
        o="$o $(verdict "$s" "$WORK/world-$v" h)"
      done
      printf '%s' "${o# }"
    }
    got="$(wv_vec "$HECTL")"
    if [ "$got" = "$WVWANT" ]; then ok "WAIVER (BL-957): a collect-only invocation, backticked, bare or after \$, is refused full-collection-none, also when its first backticked span is a working directory, and so is one citing a fresh capture-heads count; a bare real run with a backticked directory stays a run; --cov and --color stay runs; none, AC3 waives it is accepted with the entry at the base, refused with the entry only in the range, and refused when the story is a tree at the base"; B_wv=1
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
    if [ "$(wv_rmd "$HECTL")" = 1:1 ]; then ok "WAIVER (BL-957): the full-collection refusal names the canonical-run waiver as a further option, and the dependency-setup refusal does not"; B_wvr=1
    else bad "WAIVER (BL-957): want the remedy on the full-collection refusal only [1:1], got [$(wv_rmd "$HECTL")]"; fi
    # The waiver test itself, asked directly (fixture-mutants.md clause 6) over wv957wvbase's story at its base,
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
    wv_mutant() { # <name> <he|ro> <from> <to> <want> <label>
      local m got t
      if [ "$2" = ro ]; then
        t="$(mk_tree "$1")" || { bad "FIXTURE ERROR: waiver mutation '$1' could not build its tree"; return; }
        FROM="$3" TO="$4" awk 'BEGIN{f=ENVIRON["FROM"]; t=ENVIRON["TO"]} !done && (p=index($0,f)) {$0=substr($0,1,p-1) t substr($0,p+length(f)); done=1} {print}' \
          "$(dirname "$HE")/record-only-diff.sh" > "$(dirname "$t")/record-only-diff.sh.tmp"
        if cmp -s "$(dirname "$HE")/record-only-diff.sh" "$(dirname "$t")/record-only-diff.sh.tmp"; then bad "FIXTURE ERROR: waiver mutation '$1' matched nothing"; return; fi
        mv "$(dirname "$t")/record-only-diff.sh.tmp" "$(dirname "$t")/record-only-diff.sh"; m="$t"
      elif ! m="$(mkmut "$1" he "$3" "$4")" || [ -z "$m" ]; then bad "FIXTURE ERROR: waiver mutation '$1' matched nothing"; return; fi
      got="$(wv_vec "$m" "$5")"
      if [ "$got" = "$5" ]; then mutant_killed "${B_wv:-0}" "$1" "MUTATION '$1' killed, moving its own cells only: $6"
      elif [ "$got" = "$WVWANT" ]; then bad "MUTATION '$1' SURVIVED -- $6"
      else bad "MUTATION '$1' moved [$got], want [$5] -- the cells are entangled"; fi
    }
    # The waiver read at <frozen>: the entry added inside the range waives (wv957-wv-range accepted).
    wv_mutant wv957-at-frozen he '"$STORY" "$BASE" "$1" 2>&1)"; wv_rc=$?' '"$STORY" "$FROZEN" "$1" 2>&1)"; wv_rc=$?' \
      '1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none,:W 0: 0: 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:full-collection-none, 1:full-collection-none, 0: 1:full-collection-none,' \
      "the waiver read at the frozen sha, written by the party being judged"
    # The no-test token test dropped: every collect-only value is a run again (the count route included).
    wv_mutant wv957-no-token ro '    case " $nt_s " in *" --collect-only "*|*" --collectonly "*|*" --co "*) return 0 ;; esac' '    :' \
      '0: 0: 0: 0::W 0: 0: 0: 1:full-collection-none, 1:full-collection-none, 0: 0: 0: 0: 0: 0: 0: 0: 0:' \
      "a collect-only invocation read as a run"
    # The token test on the backticked spans only: the bare and `$ ` forms are runs again, and so is every form
    # whose only collect-only text is outside a span.
    wv_mutant wv957-token-bt-only ro "    nt_s=\"\$(LC_ALL=C tr -c 'A-Za-z0-9_-' ' ' <<<\"\$nt_s\")\"" "    nt_s=\"\$(grep -oE '\`[^\`]*\`' <<<\"\$1\" | LC_ALL=C tr -c 'A-Za-z0-9_-' ' ')\"" \
      '1:full-collection-none, 0: 0: 1:full-collection-none,:W 0: 0: 0: 1:full-collection-none, 1:full-collection-none, 0: 0: 0: 1:full-collection-none, 0: 0: 0: 0: 1:full-collection-none,' \
      "the no-test token read in a backticked span only"
    # The token test on rf_span's span only (the pre-fix reading): a collect-only invocation whose first backticked
    # span is its working directory is a run again, bare, after a `$ ` opening it or after a `$ ` mid-value.
    wv_mutant wv957-token-span-only ro "    nt_s=\"\$(LC_ALL=C tr -c 'A-Za-z0-9_-' ' ' <<<\"\$nt_s\")\"" "    nt_s=\"\$(rf_span \"\$1\" | LC_ALL=C tr -c 'A-Za-z0-9_-' ' ')\"" \
      '1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none,:W 0: 0: 0: 1:full-collection-none, 1:full-collection-none, 0: 0: 0: 1:full-collection-none, 0: 0: 0: 0: 1:full-collection-none,' \
      "the no-test token read in rf_span's span only, so another run arm's text makes a collect-only value a run"
    # Each of ro_no_test's three texts dropped alone moves only the world that text alone catches.
    wv_mutant wv957-no-span-text ro '    nt_s="$(rf_span "$1")"' '    nt_s=""' \
      '1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none,:W 0: 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 0: 1:full-collection-none, 1:full-collection-none, 0: 1:full-collection-none,' \
      "the no-test token not read in rf_span's span (a backticked invocation after a non-runner span is a run)"
    wv_mutant wv957-no-dollar-text ro "    nt_s=\"\$nt_s\"\$'\\n'\"\$(grep -oE" '    : "$(grep -oE' \
      '1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none,:W 0: 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:full-collection-none, 0: 1:full-collection-none, 1:full-collection-none, 0: 1:full-collection-none,' \
      "the no-test token not read in a \$ command (a \$ command after a non-runner span is a run)"
    wv_mutant wv957-no-opening-text ro "    nt_s=\"\$nt_s\"\$'\\n'\"\$(awk" '    : "$(awk' \
      '1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none,:W 0: 0: 0: 1:full-collection-none, 1:full-collection-none, 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 0: 0: 0: 1:full-collection-none,' \
      "the no-test token not read in the value's opening (a bare invocation with a backticked directory is a run)"
    # The token boundary restored to whitespace, a backtick or the end: `--collect-only,` and `--co;` are runs again.
    wv_mutant wv957-old-boundary ro "    nt_s=\"\$(LC_ALL=C tr -c 'A-Za-z0-9_-' ' ' <<<\"\$nt_s\")\"" "    nt_s=\"\$(tr '\\t\\n\\r\`' '    ' <<<\"\$nt_s\")\"" \
      '1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none,:W 0: 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 0: 0: 0: 1:full-collection-none,' \
      "the no-test token bounded by whitespace, a backtick or the end only, so punctuation after it hides it"
    # The `--collectonly` spelling dropped from the token: that spelling alone is a run again.
    wv_mutant wv957-no-alias ro '|*" --collectonly "*' '' \
      '1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none,:W 0: 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:full-collection-none, 1:full-collection-none, 0: 0:' \
      "pytest's --collectonly spelling of the collect-only option read as a run"
    # D4 placed after the count route: a collect-only value borrows the block's count (wv957-co-dar accepted).
    wv_mutant wv957-d4-after-dar he '  bash "$RO" no-test-run "$1" && return 1' '  :' \
      '1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0::W 0: 0: 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:full-collection-none, 1:full-collection-none, 0: 1:full-collection-none,' \
      "the capture-heads count route asked before the no-test test"
    # The waiver's exit 2 read as acceptance: a story that is a tree at the base is waived.
    wv_mutant wv957-exit2-accept he "    *) refuse \"full-collection-none \$STORY: 'Full-collection run: \$1' names a canonical-run waiver" "    *) : \"full-collection-none \$STORY: 'Full-collection run: \$1' names a canonical-run waiver" \
      '1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none,:W 0: 0: 0: 1:full-collection-none, 0: 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 1:full-collection-none, 0: 1:full-collection-none, 1:full-collection-none, 0: 1:full-collection-none,' \
      "a waiver that cannot be read at the base accepted"
    # The waiver wired into ev_none's SHARED text: Dependency setup's refusal names a waiver it has no site for.
    # (The call alone moved into ev_none is behaviourally equivalent: every waiver spelling is a `none, <reason>`
    # that Dependency setup accepts before ev_none is reached, measured at authoring; its remedy text is not.)
    if m="$(mkmut wv957-ev-none-remedy he 'run it and record the invocation and counts${4:-}"' "run it and record the invocation and counts; or, when the story at the base carries a '## Canonical-run waivers' entry, write '\$1 none, <AC-id> waives it'\"")" && [ -n "$m" ]; then
      got="$(wv_rmd "$m")"
      if [ "$got" = 1:0 ]; then mutant_killed "${B_wvr:-0}" wv957-ev-none-remedy "MUTATION 'wv957-ev-none-remedy' killed by dsna: the waiver remedy in ev_none's shared text reaches the dependency-setup refusal"
      elif [ "$got" = 1:1 ]; then bad "MUTATION 'wv957-ev-none-remedy' SURVIVED -- the waiver remedy in ev_none's shared text"
      else bad "MUTATION 'wv957-ev-none-remedy' moved [$got], want [1:0]"; fi
    else bad "FIXTURE ERROR: waiver mutation 'wv957-ev-none-remedy' matched nothing"; fi
  fi
  # --- end BL-957 ---------------------------------------------------------------------------------------
fi

# --- B3: the gate-2 handoff preflight is wired -----------------------------------------------------
# implementation.md must carry, on some line, the EXACT go-signal invocation of handoff mode, which
# Rule A's GATE1-SKIP sentence and the preflight before every gate-2 dispatch run. Substring match on
# the line (the prose backticks it). The gate-1 line `... <base> <frozen-sha>` is a near-miss that must
# NOT satisfy it: asserted present and distinct. Absent, this arm FAILS (never green on absence).
B3_LINE='the program runs the `--gate2` arm of the'
B3_NEAR='program also runs the handoff-evidence validator and its `--strategy` arm'
b3_has() { grep -qF -- "$B3_LINE" "$1"; }
if ! grep -qF -- "$B3_NEAR" "$IMP"; then
  bad "B3: FIXTURE BROKEN -- the gate-1 near-miss line is absent from implementation.md, so the arm cannot show it discriminates"
elif b3_has "$IMP"; then
  ok "B3: implementation.md runs handoff mode at the go-signal sha before gate 2 ($B3_LINE); the gate-1 <frozen-sha> line alone does not satisfy it"; B_b3=1
else
  bad "B3: implementation.md carries no line naming '$B3_LINE' (the GATE1-SKIP and gate-2 preflight handoff call); the gate-1 <frozen-sha> line does not count"
fi
if [ "${B_b3:-0}" = 1 ]; then
  awk -v s="$B3_LINE" '{ while ((p = index($0, s))) $0 = substr($0, 1, p - 1) "the program runs the arm of the" substr($0, p + length(s)); print }' "$IMP" > "$WORK/imp-no-b3.md"
  if cmp -s "$IMP" "$WORK/imp-no-b3.md"; then bad "FIXTURE ERROR: mutation 'b3-unwired' matched nothing"
  elif b3_has "$WORK/imp-no-b3.md"; then bad "MUTATION 'b3-unwired' SURVIVED -- implementation.md without the go-signal handoff line"
  else mutant_killed "${B_b3:-0}" b3-unwired "MUTATION 'b3-unwired' killed: implementation.md without the go-signal handoff line fails B3"; fi
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
# The vector is every cell's exact output; each mutant must move exactly its own lines.
if [ "$WORLDS_OK" -eq 1 ]; then
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
      ok "LIST-CAPTURES: the story read AT the ref prints cap1 once (RED and plain citations), cap2 from './', the bare cap3.txt from its capture dir; '../', an outside absolute, glob, elided, untracked and the bare y.txt outside a capture dir print nothing; x/y.txt prints once cited by full path; cap5 cited on disk only is not printed at L2 and is at L3"; B_lc=1
    else
      bad "LIST-CAPTURES: want [$LCWANT] got [$got]"
    fi
    lc_mutant() { # <name> <from> <to> <want> <label>
      local m got
      if ! m="$(mkmut "$1" he "$2" "$3")" || [ -z "$m" ]; then bad "FIXTURE ERROR: list-captures mutation '$1' matched nothing"; return; fi
      got="$(lc_vec "$m")"
      if [ "$got" = "$4" ]; then mutant_killed "${B_lc:-0}" "$1" "MUTATION '$1' killed, moving its own lines only: $5"
      elif [ "$got" = "$LCWANT" ]; then bad "MUTATION '$1' SURVIVED -- $5"
      else bad "MUTATION '$1' moved [$got], want [$4] -- the cells are entangled"; fi
    }
    U="${E}untracked.txt,"
    lc_mutant lc-no-tracked 'tracked "$FROZEN" "$p" && printf' 'printf' \
      "0:${E}cap1.txt,${E}cap2.txt,${E}cap3.txt,$U | 0:${E}cap1.txt,${E}cap2.txt,${E}cap3.txt,${U}x/y.txt, | 0:${E}cap1.txt,${E}cap2.txt,${E}cap3.txt,${E}cap5.txt,${U}x/y.txt," \
      "--list-captures skips the cat-file -e filter, so the untracked citation prints"
    lc_mutant lc-no-bare 'if [ -n "$lc_bare" ] && [ -n "$lc_full" ]; then' 'if false; then' \
      "0:${E}cap1.txt,${E}cap2.txt, | 0:${E}cap1.txt,${E}cap2.txt,x/y.txt, | 0:${E}cap1.txt,${E}cap2.txt,${E}cap5.txt,x/y.txt," \
      "--list-captures drops the bare-basename resolution, so cap3.txt is lost"
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
if [ "$rc" -eq 0 ]; then
  echo "story-evidence-scaffold: PASS"
else
  echo "story-evidence-scaffold: FAILED" >&2
fi
exit $rc
