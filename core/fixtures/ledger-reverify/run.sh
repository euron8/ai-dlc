#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# Exercise reconcile/ledger-reverify.sh against the ledger-reverify fixture.
#
# THE DIFFERENTIAL. Entry A and Entry B carry identical verify directives except the
# substring; they classify differently ONLY because `theirs` contains MARKER_B and not
# MARKER_A. A closer that probes `base` instead of `theirs` sees neither marker and calls
# both STILL-LIVE — so Entry B's CLOSE-CANDIDATE assertion below goes red. That is the
# differential baked into the pair: the fixture cannot pass a closer that ignores theirs.
set -u
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
DIR="$(cd "$(dirname "$0")" && pwd)"

# --- THREE SHARDS, ONE SEED AND ONE BASELINE PER SHARD (BL-850, BL-1096) ---------------------------
# The file is dealt across shards a, b and c (`-b`, `-c` re-enter it with `--group`; see SHARDS below), so the
# pre-push pool starts each on its own; the unsharded file was the suite pole again. Each shard pays one seed,
# one baseline render and the six-row shared control. Arms that need only a few entries run against a
# SUB-LEDGER cut from the seeded ledger (`lr_subledger`, below), so the subject's per-entry naming queries
# are paid for the entries a question needs, not for the whole ledger.
#
# THE UNIT IS A `lr_unit_<slug>` FUNCTION, AND THE SET IS DERIVED FROM THIS FILE. Every section
# below the shared control is wrapped in one, closed by `} # end lr_unit_<slug>`. Every unit runs,
# in file order.
#
# THE COVERAGE JOIN (J0) runs before anything is seeded: the declared unit set is derived from this
# file's own `lr_unit_<slug>() {` lines, every one must have its end marker, none is declared twice,
# and the set is non-empty. J1 (at the end) asserts the units ENTERED equal the units DECLARED, so a
# dispatch loop that skipped one cannot read green.
#
# THESE ARMS REPORT THROUGH bad OR EXIT 2, NEVER THROUGH ASSERTIONS.
# THE SHARDS. This file is dealt across SHARDS as a SCHEDULING BOUNDARY, not a subject boundary: the pre-push
# pool is POLE-BOUND, so each shard is a directory it can start on its own. `-b` and `-c` are one-line
# drivers that run this file with `--group`; no `--group` runs shard 'a'. Every shard pays the one seed,
# the baseline and the shared control; the units (lr_unit_<slug>) are dealt below.
SHARDS="a b c"
# Shard a ships and holds every unit whose verdict can depend on placement (a B2_ISDIST branch, or
# an in-place receipt over the installed reconcile directory); b and c are DIST_SHARDS and hold only units over
# synthetic worlds and copies of the located engine.
UNITS_a="off_subject named_commits unreadable_path memo_lifecycle unicode_escape receipts_undecided nonid_manual bl890 every_receipt cwd_invariance label_prefix name_signal cited_only bare_bold_record bl932 id_class naming_set"
UNITS_b="sh_base_control sh_missing_subject midline_receipt consumer_root fenced_entries bootstrap_window caller_error short_id inproc_seam"
UNITS_c="dist_checkout receipt_suffix two_line_sh no_colon_swallow entry_swallowed idl_relabel close_anchor backslash_anchor receiptless_named"
DIST_SHARDS="b c"
# The units whose verdict can depend on placement; the join fails if one is undeclared or dealt to a DIST_SHARDS
# shard: off_subject, unreadable_path and bl890 run a receipt over the in-place reconcile directory; cited_only,
# bare_bold_record, bl932, id_class and naming_set branch on B2_ISDIST.
PLACED_UNITS="off_subject unreadable_path bl890 cited_only bare_bold_record bl932 id_class naming_set"
LR_GROUP=a
while [ "$#" -gt 0 ]; do
  case "$1" in
    --group) LR_GROUP="${2:-}"; [ -n "$LR_GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; }; shift 2 ;;
    *) echo "FIXTURE ERROR: unknown argument '$1' (want --group <shard>)" >&2; exit 2 ;;
  esac
done
case " $SHARDS " in
  *" $LR_GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$LR_GROUP' (known: $SHARDS)" >&2; exit 2 ;;
esac
eval "LR_DEALT=\"\${UNITS_$LR_GROUP:-}\""
[ -n "$LR_DEALT" ] || { echo "FIXTURE BROKEN: shard '$LR_GROUP' has no UNITS_$LR_GROUP list; a shard dealt nothing passes everything it never checked" >&2; exit 2; }

LR_SELF="$DIR/run.sh"
[ -f "$LR_SELF" ] || { echo "FIXTURE ERROR: cannot read $LR_SELF for the coverage join" >&2; exit 2; }
LR_JW="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed for the coverage join" >&2; exit 2; }
sed -n 's/^lr_unit_\([a-z0-9_]*\)() {$/\1/p' "$LR_SELF" > "$LR_JW/declared"
sed -n 's/^} # end lr_unit_\([a-z0-9_]*\)$/\1/p' "$LR_SELF" > "$LR_JW/ended"
lr_ndecl="$(grep -c . "$LR_JW/declared")" || lr_ndecl=0
lr_ndup="$(sort "$LR_JW/declared" | uniq -d | grep -c .)" || lr_ndup=0
if [ "$lr_ndecl" -eq 0 ] || [ "$lr_ndup" -ne 0 ] || ! cmp -s "$LR_JW/declared" "$LR_JW/ended"; then
  echo "FIXTURE BROKEN: [J0] $lr_ndecl lr_unit_ definitions derived from $LR_SELF ($lr_ndup declared twice), or their end markers do not pair with them one for one" >&2
  rm -rf "$LR_JW"; exit 2
fi
# The deal: dealt lists disjoint, their union EXACTLY the declared set, every declared shard has a driver
# directory that drives it. The partition check proves it can fire first, on a seeded duplicate and omission.
lr_partition_ok() { # <declared file> <dealt file> -> 0 when dealt is disjoint and covers declared exactly
  local d m x
  d="$(sort "$2" | uniq -d | tr '\n' ' ')"
  m="$(sort -u "$2" | comm -23 <(sort -u "$1") - | tr '\n' ' ')"
  x="$(sort -u "$2" | comm -13 <(sort -u "$1") - | tr '\n' ' ')"
  [ -z "$d$m$x" ] && return 0
  echo "dealt twice: {${d% }} dealt to no shard: {${m% }} dealt but not declared: {${x% }}"
  return 1
}
printf '%s\n' u1 u2 u3 > "$LR_JW/pd"; printf '%s\n' u1 u2 u2 u3 > "$LR_JW/pdup"; printf '%s\n' u1 u3 > "$LR_JW/pmiss"; printf '%s\n' u3 u1 u2 > "$LR_JW/pok"
if lr_partition_ok "$LR_JW/pd" "$LR_JW/pdup" >/dev/null || lr_partition_ok "$LR_JW/pd" "$LR_JW/pmiss" >/dev/null \
   || ! lr_partition_ok "$LR_JW/pd" "$LR_JW/pok" >/dev/null; then
  echo "FIXTURE BROKEN: [J0] the shard partition self-probe did not discriminate (duplicate, omission, exact)" >&2
  rm -rf "$LR_JW"; exit 2
fi
for _s in $SHARDS; do eval "printf '%s\n' \${UNITS_$_s}" | tr ' ' '\n'; done | grep . > "$LR_JW/dealt"
if ! _why="$(lr_partition_ok "$LR_JW/declared" "$LR_JW/dealt")"; then
  echo "FIXTURE BROKEN: [J0] the shard partition does not cover the declared units exactly -- $_why" >&2
  rm -rf "$LR_JW"; exit 2
fi
_decl=" "; while IFS= read -r _l; do _decl="$_decl$_l "; done < "$LR_JW/declared"
for _u in $PLACED_UNITS; do
  case "$_decl" in *" $_u "*) ;; *) echo "FIXTURE BROKEN: [J0] PLACED_UNITS names '$_u', which no lr_unit_ declares" >&2; rm -rf "$LR_JW"; exit 2 ;; esac
  for _s in $DIST_SHARDS; do
    eval "_l=\" \${UNITS_$_s} \""
    case "$_l" in *" $_u "*) echo "FIXTURE BROKEN: [J0] unit '$_u' is in PLACED_UNITS but is dealt to dist-only shard '$_s'; it must stay in a shipped shard" >&2; rm -rf "$LR_JW"; exit 2 ;; esac
  done
done
# THE DIST-ONLY SHARDS: DIST_SHARDS reach no consumer. Each carries a non-empty .dist-only and no other shard does,
# and a consumer holds none of their directories, so only a DIST_SHARDS shard, whose inputs.decl declares its
# dist-only siblings, checks their drivers and markers; a shipped shard declares none and skips them.
case " $DIST_SHARDS " in *" $LR_GROUP "*) _me=dist ;; *) _me=ship ;; esac
if [ -e "$DIR/.dist-only" ]; then
  echo "FIXTURE BROKEN: [J0] shard 'a' carries $DIR/.dist-only, but shard a ships" >&2
  rm -rf "$LR_JW"; exit 2
fi
for _s in $SHARDS; do
  [ "$_s" = a ] && continue
  case " $DIST_SHARDS " in *" $_s "*) _do=1 ;; *) _do=0 ;; esac
  [ "$_do" = 1 ] && [ "$_me" = ship ] && continue
  _drv="$DIR/../ledger-reverify-$_s/run.sh"
  if [ ! -f "$_drv" ] || ! grep -qF -- "--group $_s" "$_drv"; then
    echo "FIXTURE BROKEN: [J0] shard '$_s' is declared but $_drv does not drive it" >&2
    rm -rf "$LR_JW"; exit 2
  fi
  if [ "$_do" = 1 ] && [ ! -s "${_drv%/run.sh}/.dist-only" ]; then
    echo "FIXTURE BROKEN: [J0] shard '$_s' is in DIST_SHARDS but ${_drv%/run.sh}/.dist-only is absent or empty" >&2
    rm -rf "$LR_JW"; exit 2
  fi
  if [ "$_do" = 0 ] && [ -e "${_drv%/run.sh}/.dist-only" ]; then
    echo "FIXTURE BROKEN: [J0] shard '$_s' carries ${_drv%/run.sh}/.dist-only but is not in DIST_SHARDS" >&2
    rm -rf "$LR_JW"; exit 2
  fi
done
# A shard's units run in FILE order, never the order of its list: units hand each other state (the R_* and
# B_* result variables), and a reader that ran before its setter reads it unbound. A unit that reads another
# unit's variable is dealt to the same shard, after it in the file; the J2 arm below catches an unbound read.
LR_WANT="$LR_DEALT"
LR_MINE="$(grep -xF -f <(printf '%s\n' $LR_WANT) "$LR_JW/declared" | tr '\n' ' ')"
rm -rf "$LR_JW"
LR_JOIN_LINE="[J0] coverage join: $lr_ndecl units derived from lr_unit_ lines, each with its end marker, none declared twice, dealt disjointly across {$SHARDS}, union exact; this shard runs {$LR_MINE}"

# Locate the detector in BOTH layouts. Distribution: fixtures at core/fixtures/<name>/,
# detector at core/skills/…. Consumer: install.sh relocates fixtures to tests/fixtures/<name>/
# and the detector to .claude/skills/… — three levels up from the fixture, NOT two. The
# consumer candidate was `../../.claude` (two up → tests/.claude/, which does not exist), so
# every relocated-fixture consumer aborted `cannot locate` and blocked its pre-push suite,
# while the distribution stayed green on the first candidate. Test it as a CONSUMER, not only
# where core/ sits two up.
CLOSER=""
LOOKED=""
for cand in \
  "$DIR/../../skills/ai-dlc-update/reconcile/ledger-reverify.sh" \
  "$DIR/../../../core/skills/ai-dlc-update/reconcile/ledger-reverify.sh" \
  "$DIR/../../../.claude/skills/ai-dlc-update/reconcile/ledger-reverify.sh"; do
  LOOKED="$LOOKED  $cand
"
  [ -f "$cand" ] && CLOSER="$cand" && break
done
[ -n "$CLOSER" ] || { printf 'FAIL: cannot locate ledger-reverify.sh from %s. Looked in:\n%s' "$DIR" "$LOOKED"; exit 1; }
echo "HERMETIC-CONSUMED $(cd "$(dirname "$CLOSER")" && pwd)/$(basename "$CLOSER")"

# lib/report.sh defines ok and bad, which lib/mutant.sh needs first; lr_okf and lr_badf take a printf format and its
# arguments and report the formatted line (one trailing newline dropped) through them. mutant.sh defines fx_inproc,
# which inproc_run calls. Sourced here, before inproc.sh, which then finds fx_inproc defined and sources nothing;
# inproc_run strips ok, bad and the library helpers from the subject's subshell like every other fixture function.
# row_is, row_has and row_lacks return 1 on a FAIL, so a caller capturing $? holds that arm's own verdict.
. "$DIR/../lib/report.sh" || { echo "FIXTURE BROKEN: lib/report.sh not found beside $DIR" >&2; exit 2; }
lr_okf()  { local _l; printf -v _l "$@"; ok "${_l%$'\n'}"; }
lr_badf() { local _l; printf -v _l "$@"; bad "${_l%$'\n'}"; }
[ -f "$DIR/../lib/mutant.sh" ] || { echo "FIXTURE BROKEN: lib/mutant.sh not found beside $DIR" >&2; exit 2; }
# shellcheck source=/dev/null
. "$DIR/../lib/mutant.sh"

# --- THE SUBJECT IS ASKED IN PROCESS ---------------------------------------------------------------
# ledger-reverify.sh is loadable: sourcing it defines functions and runs nothing (its source guard stops
# before `lr_main`). It is sourced ONCE here, and `lr_eng <engine> <args>` answers what `bash <engine>
# <args>` prints, in a subshell made to look like a fresh bash (core/fixtures/lib/inproc.sh). <engine> is
# $CLOSER, whose loaded definitions are used, or another copy of the reconcile/ directory, which is sourced
# inside that run's own subshell, so it is the only engine present in its run. Prefix
# assignments (`TMPDIR=… lr_eng`, `PATH=<shim>:$PATH lr_eng`) reach the run as they reached the child.
#
# THE BLOB MEMO. A CLI run sources lib.sh at the top of its own process and so builds a private memo for
# that one run; in a subshell lib.sh does not (it keys on `$BASH_SUBSHELL` 0). So `lr_eng` hands each run a
# FRESH memo, exactly as private to that run as the CLI's, unless the caller exported one (as `u_run`
# does). A memo shared across runs would let one run read another engine's cache.
#
# KEPT END TO END, and why: the baseline `OUT` is in process (the `cli-seeded` cell of `inproc-seam` is byte-compared with it), the cells of `inproc-seam` (the
# CLI against the in-process answer on every distinct CLI outcome), and `memo_standalone`, whose property
# -- a run with no memo handed to it builds one and removes it -- is decided by lib.sh at `$BASH_SUBSHELL`
# 0, the top of a process, which no subshell is.
# shellcheck source=/dev/null
. "$DIR/../lib/inproc.sh" 2>/dev/null || { echo "FIXTURE BROKEN: core/fixtures/lib/inproc.sh absent beside $DIR" >&2; exit 2; }
. "$DIR/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
# PRE-WRAP CONSUMER GATE (BL-878): a consumer one pull behind carries this fixture with a subject that predates the
# in-process wrap, and loading it would run its whole body. Neither half is SKIP (FIXTURE BROKEN in the distribution,
# exit 0 on a consumer); exactly one half FAILS; an unreadable subject is FIXTURE ERROR.
grep -qxF 'lr_main() {' "$CLOSER"; _wg1=$?
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$CLOSER"; _wg2=$?
[ "$_wg1" -le 1 ] && [ "$_wg2" -le 1 ] || { echo "FIXTURE ERROR: cannot read $CLOSER (grep exit $_wg1/$_wg2)" >&2; exit 2; }
case "$_wg1$_wg2" in
  00) : ;;
  11) echo "SKIP: ledger-reverify: $CLOSER predates the in-process wrap"; fx_skip_exit "$DIR" ;;
  *) bad "$CLOSER carries one half of the in-process wrap (lr_main line: rc $_wg1, column-0 source guard: rc $_wg2) -- a respelled subject this fixture cannot drive"
     report_end "ledger-reverify shard '$LR_GROUP' of '$SHARDS'" ;;
esac
inproc_load "$CLOSER" || { echo "FIXTURE BROKEN: sourcing $CLOSER defined nothing" >&2; exit 2; }
declare -F lr_main >/dev/null || { echo "FIXTURE BROKEN: $CLOSER defined no lr_main when sourced" >&2; exit 2; }
lr_eng() { # <engine> [args...] -> what `bash <engine> [args...]` prints and exits with
  local _m _rc
  case "$(declare -p AI_DLC_RECONCILE_MEMO 2>/dev/null)" in
    "declare -x"*) inproc_run "$1" lr_main "${@:2}"; return ;;
  esac
  _m="$(mktemp -d "${TMPDIR:-/tmp}/reconcile-memo.XXXXXX")" || return 125
  AI_DLC_RECONCILE_MEMO="$_m" inproc_run "$1" lr_main "${@:2}"; _rc=$?
  rm -rf "$_m"
  return "$_rc"
}

# fd 3 is the run's own stderr, saved before any unit redirects it. The single EXIT trap
# replays a unit's captured stderr there: a unit that exits from inside its body (`exit 2` on
# a FIXTURE ERROR) runs this trap with the unit's `2>` still in force, so a replay to fd 2
# would write the file into itself and the message would reach nobody.
# LR_DONE is set only just before the final verdict. Any exit before it -- an `exit 0` inside a
# unit included, which would otherwise end the run green with no verdict and skip every later
# unit, J1 and the floor -- is exit 2 after the unit's own stderr has been replayed once.
LR_DONE=""
exec 3>&2
# The seed's exit status is its only failure signal and a process substitution discards it, so a
# failed seed used to arrive as four empty variables and `rm -rf "$(dirname "")"` in the trap below.
# Capture it, and check the four fields and the mktemp prefix BEFORE that trap is armed.
# LR_SEED overrides the seed path for the seed-fails arm below; unset, it is the shipped seed.
seed_out="$(bash "${LR_SEED:-$DIR/seed.sh}")" || { echo "FIXTURE BROKEN: seed exited $?" >&2; exit 2; }
read -r DIST BASE CONS THEIRS <<< "$seed_out"
for _f in DIST BASE CONS THEIRS; do
  [ -n "${!_f}" ] || { echo "FIXTURE BROKEN: seed printed no value for $_f" >&2; exit 2; }
done
case "$DIST" in
  "${TMPDIR:-/tmp}"/ledger-reverify-*/dist) [ -d "$DIST" ] || { echo "FIXTURE BROKEN: seed's DIST is not a directory: $DIST" >&2; exit 2; } ;;
  *) echo "FIXTURE BROKEN: seed's DIST is not under ${TMPDIR:-/tmp}/ledger-reverify-*: $DIST" >&2; exit 2 ;;
esac
trap '[ -n "${LR_UNIT_ERR:-}" ] && [ -s "$LR_UNIT_ERR" ] && cat "$LR_UNIT_ERR" >&3; rm -rf "$(dirname "$DIST")"; [ "${LR_DONE:-}" = 1 ] || { echo "FIXTURE BROKEN: the run exited before dispatch completed" >&3; exit 2; }' EXIT

# THE BASELINE RUNS FROM `/`, a directory where no consumer-relative path resolves, and its exit
# status is kept. cwd-invariance compares it byte-for-byte against a run from the consumer root, and
# exit-code reads OUT_RC, so neither re-renders the whole ledger to ask its question.
OUT="$(cd / && lr_eng "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"; OUT_RC=$?

ASSERTIONS=0

# LR_LM is the label matcher the row helpers share, prepended to their awk programs. A label is a
# FIXED STRING, not a regex, and it matches a row when it occurs in the row's label field followed by
# a non-identifier character (anything but a letter, digit, `_` or `-`), by the end of the field, or
# when the label itself ends in a space (the space is the boundary), or ends in `-` (an open prefix:
# `FENCED-TS-EVENT-` is a claim about the whole FAMILY of rows starting with it). So `Entry X` reads the row for
# `Entry X` and never the row for `Entry X-SUBJECT`, and a partial label still reaches the sentence
# the engine appends after the id. A label meant to reach a longer id must spell that id in full.
LR_LM='function lm(s, l,   o, i, p, c) {
  o = 0
  while ((i = index(substr(s, o + 1), l)) > 0) {
    p = o + i + length(l); c = substr(s, p, 1)
    if (c == "" || c !~ /[A-Za-z0-9_-]/ || substr(l, length(l)) == " " || substr(l, length(l)) == "-") return 1
    o = o + i
  }
  return 0
}
'

# --- HOISTED HELPERS: every unit may call these ------------------------------------------------
# $1 label-substring  $2 expected STATUS (or "ABSENT")  $3 why
row_is() {
  local label="$1" want="$2" why="$3" got
  ASSERTIONS=$((ASSERTIONS + 1))
  got="$(printf '%s\n' "$OUT" | awk -F'\t' -v l="$label" "$LR_LM"'lm($2, l) {print $1; exit}')"
  if [ "$want" = "ABSENT" ]; then
    if [ -z "$got" ]; then
      lr_okf '%-22s no row  (%s)\n' "$label" "$why"
    else
      lr_badf '%-22s got=%s want=no-row  (%s)\n' "$label" "$got" "$why"
      return 1
    fi
  elif [ "$got" = "$want" ]; then
    lr_okf '%-22s %s  (%s)\n' "$label" "$got" "$why"
  else
    lr_badf '%-22s got=%s want=%s  (%s)\n' "$label" "${got:-<none>}" "$want" "$why"
    printf '%s\n' "$OUT" | sed 's/^/          | /'
    return 1
  fi
}

# NAMED-UPSTREAM is an ADDITIONAL row, so an entry can now carry two. row_is() reports the
# FIRST row for a label and is therefore the wrong instrument for a pair — it would silently
# assert on whichever happened to print first. These two ask whether a specific (label, status)
# pair is present or absent, independently of any other row the entry has.
# $1 label-substring  $2 STATUS  $3 why
row_has() {
  local label="$1" want="$2" why="$3"
  ASSERTIONS=$((ASSERTIONS + 1))
  if printf '%s\n' "$OUT" | awk -F'\t' -v l="$label" -v s="$want" "$LR_LM"'lm($2, l) && $1 == s {f=1} END{exit !f}'; then
    lr_okf '%-22s %s present  (%s)\n' "$label" "$want" "$why"
  else
    lr_badf '%-22s %s MISSING  (%s)\n' "$label" "$want" "$why"
    printf '%s\n' "$OUT" | sed 's/^/          | /'
    return 1
  fi
}
row_lacks() {
  local label="$1" bad="$2" why="$3"
  ASSERTIONS=$((ASSERTIONS + 1))
  if printf '%s\n' "$OUT" | awk -F'\t' -v l="$label" -v s="$bad" "$LR_LM"'lm($2, l) && $1 == s {f=1} END{exit !f}'; then
    lr_badf '%-22s %s present but must not be  (%s)\n' "$label" "$bad" "$why"
    printf '%s\n' "$OUT" | sed 's/^/          | /'
    return 1
  else
    lr_okf '%-22s no %s  (%s)\n' "$label" "$bad" "$why"
  fi
}

# $1 label-substring  $2 fixed string the DETAIL must contain  $3 why
detail_has() {
  local label="$1" want="$2" why="$3"
  ASSERTIONS=$((ASSERTIONS + 1))
  if printf '%s\n' "$OUT" | awk -F'\t' -v l="$label" -v s="$want" "$LR_LM"'lm($2, l) && index($3, s) > 0 {f=1} END{exit !f}'; then
    lr_okf '%-22s detail names "%s"  (%s)\n' "$label" "$want" "$why"
  else
    lr_badf '%-22s no row for this label carries "%s" in its detail  (%s)\n' "$label" "$want" "$why"
    printf '%s\n' "$OUT" | awk -F'\t' -v l="$label" "$LR_LM"'lm($2, l)' | sed 's/^/          | /'
  fi
}
detail_lacks() {
  local label="$1" bad="$2" why="$3"
  ASSERTIONS=$((ASSERTIONS + 1))
  if printf '%s\n' "$OUT" | awk -F'\t' -v l="$label" -v s="$bad" "$LR_LM"'lm($2, l) && index($3, s) > 0 {f=1} END{exit !f}'; then
    lr_badf '%-22s a row for this label still carries "%s"  (%s)\n' "$label" "$bad" "$why"
    printf '%s\n' "$OUT" | awk -F'\t' -v l="$label" "$LR_LM"'lm($2, l)' | sed 's/^/          | /'
  else
    lr_okf '%-22s no row carries "%s"  (%s)\n' "$label" "$bad" "$why"
  fi
}

# --- THE SUB-LEDGER: what a run actually needs to read ---------------------------------
# One engine run costs a fixed handful of git calls plus several per ledger ENTRY (measured on
# this seed with a git shim: 396 calls over the whole seeded ledger, 7 over a one-entry ledger,
# 208 of the 396 being per-entry naming queries). An arm reads one to three rows, so running it over
# the whole ledger paid for a hundred-odd entries no arm looked at.
#
# lr_subledger CUTS, IT NEVER WRITES. It copies WHOLE entries out of the SEEDED ledger, verbatim,
# split by the producer's own entry boundary (`ledger_entry_shape()` from the engine's lib.sh,
# loaded from the same reconcile directory the engine runs from, never restated here), into a file
# BESIDE the seeded ledger, so every path the engine derives from the ledger's directory is the
# same one. An entry is kept when its ENTRY LINE carries one of the given fixed strings, and every
# string must select at least one entry or the cut is refused with nothing on stdout -- a sub-ledger
# that silently lost the discriminating entry would make its arms read nothing.
LR_LED="$CONS/_bmad-output/ai-dlc-update/push-candidate-ledger.md"
LR_ENTRY_AWK="$(bash -c '. "$1/lib.sh" >/dev/null 2>&1 || exit 2; ledger_entry_awk' _ "$(dirname "$CLOSER")")" || LR_ENTRY_AWK=""
lr_subledger() { # <name> <entry-line fixed string>... -> path on stdout; return 1 and say why if any string selects nothing
  local n="$1" out pats
  shift
  out="$(dirname "$LR_LED")/sub-$n.md"
  [ -n "$LR_ENTRY_AWK" ] && [ -f "$LR_LED" ] && [ "$#" -gt 0 ] || { echo "lr_subledger: no entry rule, no seeded ledger, or no string given" >&2; return 1; }
  pats="$(printf '%s\n' "$@")"
  LR_PATS="$pats" awk "$LR_ENTRY_AWK"'
    BEGIN { np = split(ENVIRON["LR_PATS"], P, "\n") }
    { s = ledger_entry_shape($0) }
    s != "" { seen = 1; keep = 0; for (i = 1; i <= np; i++) if (index($0, P[i]) > 0) { keep = 1; hit[i] = 1 } }
    !seen || keep { print }
    END { for (i = 1; i <= np; i++) if (!hit[i]) { print "lr_subledger: no entry line carries: " P[i] > "/dev/stderr"; bad = 1 }; exit bad }
  ' "$LR_LED" > "$out" || { rm -f "$out"; return 1; }
  printf '%s' "$out"
}
# THE HELPER'S OWN PROBE, BEFORE ANY UNIT TRUSTS IT, in both directions. A string that is in no
# entry line must be REFUSED (verified absent from the seeded ledger first, so the refusal is about
# the helper and not about a token that happens to be there). A real label must come back as its
# whole entry -- its receipt line present -- and NOT as the entry after it, which is what a cut
# that ignored the boundary would also return. Reports through exit 2, never through ASSERTIONS.
lr_sl_bad=""
grep -qF 'ZZ-NO-SUCH-LABEL-IN-THIS-LEDGER' "$LR_LED" && lr_sl_bad="the impossible label is present in the seeded ledger"
lr_sl_out="$(lr_subledger probe-absent 'ZZ-NO-SUCH-LABEL-IN-THIS-LEDGER' 2>/dev/null)" && lr_sl_bad="$lr_sl_bad; an absent label was not refused"
[ -z "$lr_sl_out" ] || lr_sl_bad="$lr_sl_bad; an absent label printed a path"
lr_sl_a="$(lr_subledger probe-a 'Entry A still lacked' 2>/dev/null)" || lr_sl_bad="$lr_sl_bad; a present label was refused"
if [ -n "$lr_sl_a" ]; then
  grep -qF 'verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"' "$lr_sl_a" || lr_sl_bad="$lr_sl_bad; the cut lost the entry's own receipt"
  grep -qF 'Entry B was live' "$lr_sl_a" && lr_sl_bad="$lr_sl_bad; the cut ran on into the next entry"
  rm -f "$lr_sl_a"
fi
if [ -n "$lr_sl_bad" ]; then
  echo "FIXTURE BROKEN: lr_subledger self-probe: ${lr_sl_bad#; }" >&2
  exit 2
fi

# THE B2 ARMS SHIP AHEAD OF THEIR SUBJECT. This fixture reaches a consumer a pull before the
# engine it tests, so every arm below that reads a B2 behaviour (the rev-spec strip, the reach
# kind, the full citing-commit list, the unreadable refusal) SKIPs on an installed engine that
# predates it. Keyed on a token only the fixed engine carries, and decided on the RESOLVED engine
# directory: in the distribution the arms always run, so a pre-fix engine there goes red.
B2_ISDIST=0
[ "$(cd "$(dirname "$CLOSER")" && pwd)" = "$(cd "$DIR/../../skills/ai-dlc-update/reconcile" 2>/dev/null && pwd)" ] && B2_ISDIST=1
B2_RUN=1
if ! grep -qF 'NAMED-UPSTREAM-DOCS-ONLY' "$CLOSER" && [ "$B2_ISDIST" = 0 ]; then B2_RUN=0; fi


echo "ledger-reverify fixture"
echo

row_is "Entry A" STILL-LIVE      "theirs still lacks MARKER_A -> entry stays open"
row_is "Entry B" CLOSE-CANDIDATE "theirs now has MARKER_B -> upstream absorbed it"
row_is "Entry C" ABSENT          "already ADOPTED UPSTREAM -> closed, not re-emitted"
row_is "Entry D" ABSENT          "no verify: line AND a prose label, not an entry id -> no row; only an id-keyed receipt-less entry reaches the naming query"

# THE THIRD DIFFERENTIAL — a declared manual entry vs a malformed one. Both used to land on
# NEEDS-REVIEW, so a deliberate "no mechanical predicate exists" declaration was reported in
# the same breath as a typo, and draining the bucket meant re-reading entries that had already
# said they need no machine check.
row_is "PC-FIXTURE-ENTRY-E-DECLARES-MANUAL" HAND-REVIEW     "verify: manual is a declaration, not a malformed line"
row_is "PC-FIXTURE-ENTRY-F-MANUAL-BACKTICK" HAND-REVIEW     "trailing backtick on the verb is a formatting slip, not a different verb"

lr_unit_inproc_seam() {
# THE IN-PROCESS ANSWER IS THE CLI'S, on every distinct CLI outcome: the seeded ledger (rc 0, rows), the
# swapped-argument caller error (rc 0, one INPUT-UNRESOLVED row), the absent default ledger (rc 0, silent)
# and a refusal (no writable TMPDIR, rc 2). stdout+stderr and the exit status are compared byte for byte,
# and the four outcomes must be pairwise distinct, or one of them proves nothing about another.
local _w="$(dirname "$DIST")/inproc-seam" _k _ok=1 _seen=""
mkdir -p "$_w/noled"
for _k in seeded swapped noledger refusal; do
  case "$_k" in
    seeded)   (cd / && FXCELL=cli-seeded bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS") > "$_w/$_k.cli" 2>&1; echo $? >> "$_w/$_k.cli"
              (cd / && lr_eng "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS") > "$_w/$_k.in" 2>&1; echo $? >> "$_w/$_k.in" ;;
    swapped)  FXCELL=cli-swapped bash "$CLOSER" "$DIST" "$BASE" "$THEIRS" "$CONS" > "$_w/$_k.cli" 2>&1; echo $? >> "$_w/$_k.cli"
              lr_eng "$CLOSER" "$DIST" "$BASE" "$THEIRS" "$CONS" > "$_w/$_k.in" 2>&1; echo $? >> "$_w/$_k.in" ;;
    noledger) FXCELL=cli-noledger bash "$CLOSER" "$DIST" "$BASE" "$_w/noled" "$THEIRS" > "$_w/$_k.cli" 2>&1; echo $? >> "$_w/$_k.cli"
              lr_eng "$CLOSER" "$DIST" "$BASE" "$_w/noled" "$THEIRS" > "$_w/$_k.in" 2>&1; echo $? >> "$_w/$_k.in" ;;
    refusal)  TMPDIR="$_w/no-such-dir" FXCELL=cli-refusal bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" > "$_w/$_k.cli" 2>&1; echo $? >> "$_w/$_k.cli"
              TMPDIR="$_w/no-such-dir" AI_DLC_RECONCILE_MEMO="$_w" lr_eng "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" > "$_w/$_k.in" 2>&1; echo $? >> "$_w/$_k.in" ;;
  esac
  cmp -s "$_w/$_k.cli" "$_w/$_k.in" || { _ok=0; printf '          | %s differs\n' "$_k"; }
  case " $_seen " in *" $(cksum < "$_w/$_k.cli" | tr ' ' _) "*) _ok=0; printf '          | %s is not a distinct outcome\n' "$_k" ;; esac
  _seen="$_seen $(cksum < "$_w/$_k.cli" | tr ' ' _)"
done
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$_ok" = 1 ] && [ "$(tail -1 "$_w/seeded.cli")" = 0 ] && [ "$(tail -1 "$_w/refusal.cli")" = 2 ] \
   && [ "$(grep -c . "$_w/noledger.cli")" = 1 ] && grep -q '^INPUT-UNRESOLVED' "$_w/swapped.cli" && [ "$(cmp -s "$_w/seeded.cli" <(printf '%s\n%s\n' "$OUT" "$OUT_RC") && echo same)" = same ]; then
  lr_okf '%-22s in process equals the CLI byte for byte, rc included, on the seeded ledger (rc 0), swapped arguments (INPUT-UNRESOLVED), an absent ledger (silent) and a refusal (rc 2)\n' "inproc-seam"
else
  lr_badf '%-22s the in-process run differs from the CLI on an outcome above, or the outcomes are not distinct\n' "inproc-seam"
fi
} # end lr_unit_inproc_seam

lr_unit_cwd_invariance() {
# --- CWD INVARIANCE, and it is asserted here because it is not free -------------------------
# A `verify: sh` receipt names CONSUMER-RELATIVE paths and used to be run with `bash -c` from
# whatever directory the caller happened to be standing in. The same receipt, the same ledger and
# the same four arguments then produced DIFFERENT verdicts per cwd. Measured on the reference
# consumer's ledger, one row apart:
#
#   from the CONSUMER root       PC-S331  STILL-LIVE       the receipt found its file
#   from the DISTRIBUTION root   PC-S331  CLOSE-CANDIDATE  grep exited 2, no such file
#
# The wrong-cwd direction is the one that loses data -- it proposes closing a live entry -- and
# the path-existence guard could not see it, because that guard resolves against $CONSUMER and
# correctly reported every path present while the predicate read another tree entirely.
#
# EVERY OTHER ASSERTION IN THIS FILE IS BLIND TO IT: they all read one $OUT, taken from one cwd,
# so they agree with each other no matter which tree the receipts were evaluated against. This
# arm is the only one that can see it, which is why the comparison is byte-for-byte rather than
# per-row.
# THE COMPARISON NEEDS A CWD WHERE THE RECEIPT RESOLVES, and the first draft of this arm did
# not have one: it compared `/` against the fixture's own cwd, and a bare relative subject is
# missing from BOTH, so a wrong engine gave the same wrong answer twice and the byte-comparison
# passed. One side is now the CONSUMER ROOT itself -- the only directory where a
# consumer-relative path resolves -- which is what makes the two sides able to disagree.
cwd_probe="$OUT"   # the baseline, taken from `/`
cwd_atcons="$(cd "$CONS" && lr_eng "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$cwd_probe" = "$cwd_atcons" ]; then
  lr_okf '%-22s byte-identical from `/` and from the CONSUMER root — a receipt is evaluated at the consumer root, not wherever the caller stands
' "cwd-invariance"
else
  lr_badf '%-22s the verdicts CHANGED with the working directory. A `verify: sh` receipt names consumer-relative paths; run from elsewhere its grep exits non-zero on a missing file and the entry reads as absorbed. That direction closes live entries.
' "cwd-invariance"
  diff <(printf '%s\n' "$cwd_atcons") <(printf '%s\n' "$cwd_probe") | sed 's/^/          | /' | head -12
fi

} # end lr_unit_cwd_invariance
lr_unit_nonid_manual() {
# --- A NON-ID `verify: manual` IS AN ENTRY-SHAPE DEFECT, NOT A HAND-REVIEW DECLARATION -----
# THE DEFECT. `manual` declared under a label the shared id rule cannot spell produced
# HAND-REVIEW, whose step-8 disposition is "adjudicate the entry body against theirs". The
# ENTRY column is the key an operator greps back into the ledger with, and this file's own
# label rule truncates at the first em-dash and strips backticks — an id survives that, a
# prose sentence does not. Measured on the reference consumer at the state the defect was
# filed against, 102 emitted rows: 3 labels do not grep back into the file they came from,
# all three prose-titled, against 99 that do. And `emit-report.sh` DROPS HAND-REVIEW's detail
# (`$1=="HAND-REVIEW" ? "" : "  "$3`), so the unusable key is the whole of what reaches the
# report.
#
# THE TWO OFFENDERS ARE TWO SPELLINGS, DELIBERATELY. One opens with a capitalised sentence,
# the other with an inline code span and an arrow. A fix keyed on either surface form rather
# than on `ledger_entry_id()` reports one and misses the other, and both spellings are real:
# both are lifted from the reference consumer's live ledger.
row_is "validate-fixture-prereq.sh" NEEDS-REVIEW \
  "the SECOND spelling: code span and arrow rather than a capitalised sentence, so a surface-form fix misses it"

# The row must say WHICH defect, or it joins three other NEEDS-REVIEW causes in one bucket.
ASSERTIONS=$((ASSERTIONS + 1))
nm_det="$(printf '%s\n' "$OUT" | awk -F'\t' '$2 ~ /A narrative closure record/ && $1=="NEEDS-REVIEW"{print $3; exit}')"
if [ -z "$nm_det" ]; then
  lr_badf '%-22s no NEEDS-REVIEW row for the prose-titled manual record at all\n' "nonid-manual-detail"
elif ! grep -q '^unresolved: ' <<<"$nm_det"; then
  lr_badf '%-22s the detail does not OPEN with a cause token, so this cause cannot be told from the other three: %s\n' "nonid-manual-detail" "$(printf '%s' "$nm_det" | cut -c1-90)"
elif ! grep -q 'not an entry id' <<<"$nm_det"; then
  lr_badf '%-22s the detail never says the LABEL is the defect, so the operator is told to fix the receipt: %s\n' "nonid-manual-detail" "$(printf '%s' "$nm_det" | cut -c1-110)"
elif ! grep -q 'BULLET GRAMMAR IS NOT THE THING TO CHANGE' <<<"$nm_det"; then
  lr_badf '%-22s the detail does not warn off narrowing the bullet grammar, which is the remedy PC-S305 is filed against\n' "nonid-manual-detail"
else
  lr_okf '%-22s opens with the cause token, names the LABEL as the defect, and warns off narrowing the grammar\n' "nonid-manual-detail"
fi

# THE TRAP, AND IT IS THE REASON THIS ARM SET EXISTS RATHER THAN A ONE-LINE GRAMMAR NARROWING.
# A bare bold span at column zero closing immediately is a LEGITIMATE entry shape — the one
# `PC-S305-BARE-BOLD-ENTRY-IS-INVISIBLE-TO-EVERY-REVERIFY` is filed about — and a trailing-space
# requirement once hid 43 of 63 bullet-form entries here. Both near-misses must keep their rows.
row_is "PC-FIXTURE-BARE-BOLD-MANUAL-STILL-SEEN" HAND-REVIEW \
  "a bullet whose bold span closes at end of line is a real entry and still reports HAND-REVIEW — a grammar narrowing kills this row"
row_lacks "PC-FIXTURE-BARE-BOLD-MANUAL-STILL-SEEN" NEEDS-REVIEW \
  "...and it is NOT reported as an entry-shape defect, which is what an id test that cannot spell a bare-bold label would do"

# THE SECOND NEAR-MISS IS THE CHARACTER CLASS, where this has already been wrong: `^[A-Z0-9-]+$`
# excludes `_` and `.` and scored two real consumer entries as annotations. A fix that restates
# the id test locally instead of asking `ledger_entry_id()` re-introduces exactly that.
row_lacks "PC-FIXTURE-DOTTED-0.242.0-AND-UNDER_SCORE-MANUAL" NEEDS-REVIEW \
  "...and is not reported as a shape defect, the exact false negative the shared rule was widened to close"

# AND THE ARM MUST DISCRIMINATE ON THE VERB, NOT ON THE LABEL ALONE. Nine prose-titled bullets
# in this ledger carry real `sh` and `theirs_lacks` receipts that RUN and produce real verdicts;
# reporting those would be the wider predicate this fix deliberately did not ship. A mechanical
# verb stands on its receipt's own evidence whatever the label says.
row_lacks "a-real-entry.sh" NEEDS-REVIEW \
  "a PROSE-titled entry carrying a MECHANICAL receipt is untouched — the wider predicate reports 43 of these across the real corpora"

# THE FOURTH DIFFERENTIAL — path namespace. G carries Entry B's claim verbatim but filed in
# the consumer install layout. Before the basename fallback it reported NEEDS-REVIEW: the
# substring was never compared, so the closer said nothing about a claim upstream had already
# absorbed. G and B must agree; that they can disagree at all is the defect.

# ...and the fallback must REFUSE to guess. H's basename matches two files at theirs, I's
# matches none. A fallback that picked the first match would classify H on the wrong file
# while reading exactly like a correct verdict.
row_is "Entry H" NEEDS-REVIEW    "ambiguous basename (2 matches) -> refuse to guess"
row_is "Entry I" NEEDS-REVIEW    "basename matches nothing at theirs -> nothing to fall back to"

# THE FIFTH DIFFERENTIAL — a close nothing upstream produced. J and K classify CLOSE-CANDIDATE
# on the theirs-side test alone, but neither predicate's STILL-LIVE side was ever reachable:
# J's substring is absent at base AND theirs, K's is present at both. A closer that tests only
# theirs emits a confident close for a claim no upstream change touched, and a drain acts on
# it. Six entries on the reference consumer had exactly this shape, every one a live defect.
row_is "Entry K" NEEDS-REVIEW    "theirs_lacks on a substring present at base too -> vacuous, not absorbed"

# THE SIXTH DIFFERENTIAL — more than one substring in a directive. Joined into a single
# literal (quotes included) the pattern matches nothing, so BOTH L and M report "still
# lacks" and only L is right. M is the damage: theirs carries both markers, and the entry
# would sit open forever against an upstream that had already absorbed it. Matching each
# substring separately is what makes the pair disagree, which is what makes the test real.
} # end lr_unit_nonid_manual
lr_unit_sh_missing_subject() {
# --- the `sh` verb: a MISSING SUBJECT is not a fix -----------------------------
# Three outcomes, because two would let a verb that always reports one thing pass.
row_is "Entry SH-REAL"  CLOSE-CANDIDATE "OVER-FIRE CONTROL: a plain non-zero exit still closes, or the guard pins every sh entry open forever"

# THE POSITIVE OUTCOME, asserted rather than the absence of the old failure. A receipt naming a
# BARE consumer-relative subject that is PRESENT must read STILL-LIVE from this fixture's cwd,
# which is not the consumer root. The equality above cannot make that claim on its own.
# A MOVED SUBJECT INSIDE AN && CHAIN IS NOT A FIX, and the exit status cannot say so: the chain
# short-circuits with 1, exactly like a genuine fix. The 126/127 guard cannot reach it, and the
# residue used to be a NOTE in the CLOSE-CANDIDATE detail telling the operator to check the paths
# themselves. SH-REAL above is the paired control: a non-zero exit whose receipt names no
# consumer-relative path at all must still CLOSE, or this guard pins every sh entry open.
row_is "Entry SH-SUBJECT-GONE" NEEDS-REVIEW "an && chain short-circuiting on a MOVED subject must not read as a fix"
# A DISTRIBUTION PATH IS NOT A CONSUMER SUBJECT. The pair with SH-SUBJECT-GONE is the whole
# assertion: that entry names a consumer path that is genuinely absent and must stay flagged,
# this one names a distribution path inside a rev-spec and must not be. An extractor that sees
# neither passes the first arm alone; one that sees both passes the second alone.
row_is "Entry SH-DIST-BARE-CORE" CLOSE-CANDIDATE "a bare \`core/scripts/<x>\` pathspec is a distribution path; the whitelist's first-character test is what keeps it out"
# A `docs/` PATH AT A REF IS A DISTRIBUTION PATH TOO, AND `docs/` IS A CONSUMER PREFIX. Splitting
# the rev-spec at its colon left `docs/zz-dist-only-a.md` standing, the whitelist admitted it, it is
# absent on the consumer, and a receipt that works read as naming a missing subject. Five spellings
# of the ref in one receipt, so a strip that handles only one leaves the row NEEDS-REVIEW.
# `.git/` IS A CONSUMER HOME THE WHITELIST DID NOT CARRY, AND IT IS THE ONE A FRESH CHECKOUT MOST
# OFTEN LACKS. `git clone` does not carry `.git/hooks/`, so the receipt exits non-zero for the
# ABSENCE and the tip read it as a fix. Measured on the reference consumer: the 0.471.0→0.479.0
# rehearsal recorded 2 CLOSE-CANDIDATE where the live run correctly reported 1.
row_is "Entry SH-GITHOOK-GONE" NEEDS-REVIEW "an absent \`.git/hooks/<x>\` subject is a missing subject like any other — the tip skipped the token and read the absence as an absorption"
# THE TWO OVER-FIRE CONTROLS FOR THE WIDENING, and they are what keep it from being the
# bare-root-dotfile form measured as broken. A bare `.git` is a DIRECTORY on any real consumer, so
# admitting it puts a token nobody wrote into the accusing population; the tokenizer strips `*`
# before any guard sees it, so `core/hooks/*.sh` arrives as the bare token `.sh` and a dotfile arm
# turns every `*.ext` in every receipt into a spurious NEEDS-REVIEW — which SUPPRESSES A REAL
# CLOSE. The surviving control, the glob-bare-extension entry below, must still close, or the fix is
# the wider one this entry exists to refuse.
row_is "Entry SH-GLOB-BARE-EXT" CLOSE-CANDIDATE "\`core/hooks/*.sh\` tokenizes to the bare \`.sh\`, which carries no glob character for the glob guard to refuse — admitting it files every \`*.ext\` receipt as unresolved"

row_is "Entry M" CLOSE-CANDIDATE "two substrings, BOTH at theirs -> absorbed, must not stay open"

# THE SECOND DIFFERENTIAL — entry SHAPE. These three carry the same directives as B/C/D but
# in the `## SECTION-ID — title` shape instead of a `- **bullet**`. A parser that treats every
# heading as a pure terminator clears the label, so the directive is parsed and then dropped:
# no row, exit 0, indistinguishable from "nothing to close". Measured on the reference
# consumer, where every entry filed after 2026-07-20 used this shape and the one entry that
# had adopted the verify: convention at all was invisible while upstream had already fixed it.
row_is "PC-FIXTURE-HEADING-NO-VERIFY" ABSENT          "heading opens an entry, so it ends the one above -> no inherited directive"

# TWO WAYS TO BE DONE. `ADOPTED UPSTREAM` was the only closure token, so an entry WITHDRAWN
# because its premise was false went on asking for a verdict on every pull — and its receipt
# cannot settle it, since no upstream change can make a defect that never existed stop existing.
# Measured on the reference consumer: two of nine HAND-REVIEW rows were one withdrawn entry,
# counted twice. Matched as loosely as its sibling token, and for the same reason.

# A close row must name the version where the substring APPEARED, not theirs' tip.
#
# The row is a permanent provenance annotation — the operator copies its version straight into
# `ADOPTED UPSTREAM (v…)`, and retro and the §8.1 fan-in read it afterwards. It used to print
# VERSION at theirs, which is the tip being pulled and has nothing to do with when the
# absorption happened. On the reference consumer that was three releases off, and a hand
# correction filed against it (derived by sampling the refs already loaded, rather than walking
# the history) was wrong in the same direction.
#
# The seed absorbs MARKER_B at 0.101.0 and moves theirs on to 0.103.0, so naming the tip and
# naming the truth are different strings here. With base->theirs adjacent they would not be.
ASSERTIONS=$((ASSERTIONS + 1))
brow="$(printf '%s\n' "$OUT" | awk -F'\t' '$2 ~ /Entry B/ {print $3; exit}')"
if grep -q 'absorbed this at 0\.101\.0' <<<"$brow"; then
  lr_okf '%-22s names 0.101.0  (the version that absorbed it, not theirs 0.103.0)\n' "absorbing-version"
elif grep -q 'absorbed this at 0\.103\.0' <<<"$brow"; then
  lr_badf '%-22s names theirs 0.103.0 — the tip, not the absorbing release; this string is copied into a permanent ledger annotation\n' "absorbing-version"
else
  lr_badf '%-22s no recognisable version in the close row: %s\n' "absorbing-version" "$brow"
fi

# THE OTHER COMMIT SHAPE, and it is the one the version used to be wrong for. `MARKER_B` above
# arrived in a commit that ALSO bumped VERSION, so reading the blob at it is correct and the arm
# above passes either way. `MARKER_C` arrived one commit BEFORE its release: blob-at-the-commit
# says 0.101.0, the tip says 0.103.0, and the release that actually carries it is 0.102.0. Three
# distinct strings, so this arm cannot be satisfied by any of the three behaviours by accident.
# Reported by the graph consumer as PC-S334-ABSORBED-AT-READS-THE-VERSION-BLOB-AT-THE-FIX-COMMIT.
ASSERTIONS=$((ASSERTIONS + 1))
vrow="$(printf '%s\n' "$OUT" | awk -F'\t' '$2 ~ /Entry V/ {print $3; exit}')"
case "$vrow" in
  *'absorbed this at 0.102.0'*)
    printf -v _m '%-22s names 0.102.0  (the release CONTAINING the fix, not the blob at it)' "release-containing"; ok "$_m" ;;
  *'absorbed this at 0.101.0'*)
    lr_badf '%-22s names 0.101.0 — the VERSION blob AT the absorbing commit, one release early\n' "release-containing" ;;
  *'absorbed this at 0.103.0'*)
    lr_badf '%-22s names 0.103.0 — theirs, so the walk found nothing and fell back\n' "release-containing" ;;
  *)
    lr_badf '%-22s no recognisable version in Entry V row: %s\n' "release-containing" "$vrow" ;;
esac

# BL-704: release_containing asks `git diff --quiet <c>^ <c> -- VERSION`, which follows a textconv
# driver. A driver mapping every VERSION blob to one text makes the bump read as no bump, so Entry B
# (absorbed in the commit that bumped to 0.101.0) walks forward to the NEXT bump and names 0.102.0.
# The driver is seeded into a COPY of dist; the liveness premise (plain diff says "same",
# --no-textconv says "differ" on the bumping commit) is measured first so the arm cannot pass on a
# dead driver.
ASSERTIONS=$((ASSERTIONS + 1))
TCD="$(dirname "$DIST")/dist-textconv"; cp -R "$DIST" "$TCD"
git -C "$TCD" config diff.same.textconv 'sh -c "echo same" --'
mkdir -p "$TCD/.git/info"; echo 'VERSION diff=same' > "$TCD/.git/info/attributes"
tc_bump="$(git -C "$TCD" log --reverse --format=%H "$BASE..$THEIRS" -- VERSION 2>/dev/null)"; tc_bump="${tc_bump%%
*}"
tc_plain=0; git -C "$TCD" diff --quiet "${tc_bump}^" "$tc_bump" -- VERSION 2>/dev/null || tc_plain=$?
tc_raw=0;   git -C "$TCD" diff --quiet --no-textconv "${tc_bump}^" "$tc_bump" -- VERSION 2>/dev/null || tc_raw=$?
# Entry B is the only row this arm reads, so the run is over a sub-ledger holding Entry B alone.
tc_led="$(lr_subledger textconv 'Entry B was live')" || tc_led="$DIST/no-such-sub-ledger"
tc_out="$(lr_eng "$CLOSER" "$TCD" "$BASE" "$CONS" "$THEIRS" "$tc_led" 2>/dev/null)"
tc_b="$(printf '%s\n' "$tc_out" | awk -F'\t' '$2 ~ /Entry B/ {print $3; exit}')"
if [ -z "$tc_bump" ] || [ "$tc_plain" -ne 0 ] || [ "$tc_raw" -ne 1 ]; then
  lr_badf '%-22s the seeded driver is not live (plain diff rc=%s, --no-textconv rc=%s; wanted 0 and 1), so the arm would pass on a driver that does nothing\n' "textconv-version" "$tc_plain" "$tc_raw"
elif grep -q 'absorbed this at 0\.101\.0' <<<"$tc_b"; then
  lr_okf '%-22s a textconv driver mapping every VERSION blob to one text still names 0.101.0 for Entry B (the bump test reads bytes)\n' "textconv-version"
else
  lr_badf '%-22s Entry B row does not name 0.101.0 under the driver -- the bump test followed textconv and read the bumping commit as unchanged: %s\n' "textconv-version" "$(printf '%s' "$tc_b" | cut -c1-120)"
fi

# A NAMED-UPSTREAM ROW CARRIES NO VERSION, DELIBERATELY. The join is on the commit MESSAGE, and a
# commit that names an id to record a rejection, a split, a plan or a ledger drain matches
# exactly like one that landed the fix — so a version read off it is a claim about the wrong
# event, and it went into a permanent annotation. Re-derived against `e939a92` and
# `docs/reviews/graph-ledger-adjudication-data/final-disposition.tsv`: 29 ids named, 25
# comparable, 23 disagreeing with the adjudicated disposition.
# PC-S334-NAMED-ABSORBED-JOINS-ON-THE-OLDEST-MESSAGE-MENTION.
#
# BOTH HALVES ASSERTED. "No version" alone is satisfied by a row that lost its content; the row
# must still say WHERE upstream names the id, or the fix deleted the signal instead of the
# false precision.
ASSERTIONS=$((ASSERTIONS + 1))
nrow="$(printf '%s\n' "$OUT" | awk -F'\t' '$1=="NAMED-UPSTREAM" {print $3; exit}')"
if [ -z "$nrow" ]; then
  lr_badf '%-22s no NAMED-UPSTREAM row at all — the arms below cannot discriminate\n' "named-no-version"
elif grep -qE 'at v[0-9]+\.[0-9]+\.[0-9]+|\(v[0-9]+\.[0-9]+\.[0-9]+,' <<<"$nrow"; then
  lr_badf '%-22s the row still renders a version: %s\n' "named-no-version" "$(printf '%s' "$nrow" | cut -c1-140)"
elif grep -q 'NAMES this entry.s id in ' <<<"$nrow"; then
  lr_okf '%-22s no version, and it still says where upstream names the id\n' "named-no-version"
else
  lr_badf '%-22s no version, but the row no longer says WHERE: %s\n' "named-no-version" "$(printf '%s' "$nrow" | cut -c1-140)"
fi

# An unresolvable substring must fall back to theirs' VERSION, not print an empty version.
# A close row with no version at all is worse than one carrying the tip's.
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | awk -F'\t' '$1=="CLOSE-CANDIDATE"' | grep -q 'at \.\|at $\|at  '; then
  lr_badf '%-22s a close row rendered an EMPTY version\n' "version-fallback"
else
  lr_okf '%-22s no close row rendered an empty version\n' "version-fallback"
fi

# A verb wrapped in backticks is a formatting slip, not a different verb — on BOTH ends.
# `theirs_lacks` with a LEADING backtick used to fall through to `unknown verify verb`, filing
# a markdown habit under the same banner as a typo. Four directives on the reference consumer
# are written that way.
#
# TWO DISTINCT FORMS, and they exercise DIFFERENT code. Wrapping the whole receipt puts the
# stray backtick on the END of the directive, where it glues to the quoted substring. Wrapping
# only the verb puts one on each END OF THE VERB. A single case cannot cover both: the
# whole-span form leaves the verb clean, so it passes even with the old trailing-only verb
# strip in place — which is exactly how the verb half nearly shipped unguarded.
btick="$CONS/_bmad-output/ai-dlc-update/backtick-ledger.md"
mkdir -p "$(dirname "$btick")"
{
  printf -- '- **Entry BT** — the whole receipt wrapped in one inline code span.\n'
  printf -- '  `verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_B"`\n'
  printf -- '- **Entry BV** — only the verb wrapped, as markdown prose invites.\n'
  printf -- '  verify: `theirs_lacks` core/skills/ai-dlc/SKILL.md "MARKER_B"\n'
} > "$btick"
bt_out="$(lr_eng "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$btick" 2>&1)"
for probe in "Entry BT:whole receipt in one code span (trailing backtick on the directive)" \
             "Entry BV:only the verb backticked (a backtick on each end of the verb)"; do
  ASSERTIONS=$((ASSERTIONS + 1))
  plabel="${probe%%:*}"; pwhy="${probe#*:}"
  pstatus="$(printf '%s\n' "$bt_out" | awk -F'\t' -v l="$plabel" '$2 ~ l {print $1; exit}')"
  if [ "$pstatus" = "CLOSE-CANDIDATE" ]; then
    lr_okf '%-22s %s\n' "backtick:${plabel##* }" "$pwhy"
  else
    lr_badf '%-22s got=%s want=CLOSE-CANDIDATE — %s; a formatting habit must not change the verdict\n' "backtick:${plabel##* }" "${pstatus:-<none>}" "$pwhy"
  fi
done
rm -f "$btick"

# A receipt is a LINE; a mention is part of one.
#
# The ledger discusses receipts as well as carrying them, and the directive is a last-match-wins
# scalar — so a prose mention physically AFTER the real receipt silently replaced it with
# whatever followed the word. That is PC-S296-LEDGER-REVERIFY-LAST-MATCH-WINS, filed by the
# consumer and still open. Measured there: 88 unanchored matches for 47 real receipts, and one
# summary section emitted a phantom row off `verify: BOTH source predicates retained`.
#
# The `<br>` case is not decoration: nine of the reference consumer's real receipts are written
# that way, and an anchor that forgets it silently DROPS them — six rows vanished on the first
# attempt here, which is the same failure shape in the other direction.
ASSERTIONS=$((ASSERTIONS + 1))
anch="$CONS/_bmad-output/ai-dlc-update/anchored-ledger.md"
mkdir -p "$(dirname "$anch")"
{
  printf -- '- **Entry PM** — its real receipt, then prose that mentions the word afterwards.\n'
  printf -- '  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_B"\n'
  printf -- '  Discussion: this entry deliberately carries NO `verify: manual` declaration, and a\n'
  printf -- '  later sentence naming `verify: theirs_has` must not become the directive.\n'
  printf -- '- **Entry BR** — a real receipt written after an HTML break, as the ledger body does.\n'
  printf -- '  <br>verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_B"\n'
} > "$anch"
an_out="$(lr_eng "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$anch" 2>&1)"
pm="$(printf '%s\n' "$an_out" | awk -F'\t' '$2 ~ /Entry PM/ {print $1; exit}')"
br="$(printf '%s\n' "$an_out" | awk -F'\t' '$2 ~ /Entry BR/ {print $1; exit}')"
if [ "$pm" = "CLOSE-CANDIDATE" ]; then
  lr_okf '%-22s prose after the receipt does not overwrite it\n' "anchor:prose"
else
  lr_badf '%-22s got=%s want=CLOSE-CANDIDATE — a mid-sentence mention replaced the real receipt (last-match-wins)\n' "anchor:prose" "${pm:-<none>}"
fi
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$br" = "CLOSE-CANDIDATE" ]; then
  lr_okf '%-22s a <br>-prefixed receipt still registers\n' "anchor:br"
else
  lr_badf '%-22s got=%s want=CLOSE-CANDIDATE — the anchor dropped a real receipt written after an HTML break\n' "anchor:br" "${br:-<none>}"
fi
rm -f "$anch"

# THE LABEL IS A JOIN KEY. Field 2 is what `emit-report.sh` renders as the entry name in the
# operator's report, and what the operator greps back into the ledger to find the entry. Both
# arms used to clip it to seventy characters, and the bullet arm never split on the em dash the
# heading arm splits on — so a real report carried a name cut mid-word inside `(original` and
# another that was a whole sentence. Measured on the reference consumer: ten of forty-one rows
# came out at exactly seventy bytes.
#
# These assert EXACT equality, not the substring match `row_is` uses. A substring assertion
# cannot see a truncation: the clipped prefix still matches.
label_is() {
  local pat="$1" want="$2" why="$3" got
  ASSERTIONS=$((ASSERTIONS + 1))
  got="$(printf '%s\n' "$OUT" | awk -F'\t' -v p="$pat" '$2 ~ p {print $2; exit}')"
  if [ "$got" = "$want" ]; then
    lr_okf '%-22s label is the whole id  (%s)\n' "$pat" "$why"
  else
    lr_badf '%-22s got=[%s] want=[%s]  (%s)\n' "$pat" "${got:-<none>}" "$want" "$why"
  fi
}

label_is "PC-FIXTURE-BULLET-DASH" "PC-FIXTURE-BULLET-DASH" \
  "bullet arm splits on the em dash, as the heading arm always did"
label_is "PC-FIXTURE-HEADING-LONG-BEFORE-DASH" \
  "PC-FIXTURE-HEADING-LONG-BEFORE-DASH (a parenthetical this long pushes the pre-dash text past seventy characters on its own)" \
  "pre-dash text over seventy characters survives whole"

# No label may come out at exactly the old cap. A single row at that width is the clip back.
ASSERTIONS=$((ASSERTIONS + 1))
clipped="$(printf '%s\n' "$OUT" | awk -F'\t' 'length($2)==70{n++} END{print n+0}')"
if [ "$clipped" -eq 0 ]; then
  lr_okf '%-22s no label lands on the old seventy-character cap\n' "label-width"
else
  lr_badf '%-22s %s label(s) are exactly 70 bytes — the clip is back\n' "label-width" "$clipped"
fi

# The closer must NEVER exit nonzero — it is a classifier and a close never blocks apply.
ASSERTIONS=$((ASSERTIONS + 1))
rc="$OUT_RC"   # the baseline's own exit status: the same invocation, not a second render
if [ "$rc" -eq 0 ]; then
  lr_okf '%-22s exit 0  (classifier never blocks)\n' "exit-code"
else
  lr_badf '%-22s exit=%s want=0  (a close must never block apply)\n' "exit-code" "$rc"
fi

} # end lr_unit_sh_missing_subject
lr_unit_caller_error() {
# --- A CALLER ERROR MUST NOT READ AS A CLEAN CORPUS --------------------------------------
# THIS ARM USED TO ASSERT THE DEFECT. It read "a consumer with NO ledger: exit 0, no output"
# and produced that case by passing an EXPLICIT arg-5 path that does not exist — which is not
# what a consumer with no ledger does. A consumer with no ledger passes no arg 5 at all. So the
# assertion pinned the silence of a caller error, and the fixture would have gone red on the
# fix rather than on the bug.
#
# The genuine case is the DEFAULT path, absent, under a real consumer root. That is the arm
# below, and it is also this change's false-positive control: it is the only shape that stays
# silent, and it must.
ASSERTIONS=$((ASSERTIONS + 1))
NOLED="$(dirname "$DIST")/consumer-with-no-ledger"
rm -rf "$NOLED"; mkdir -p "$NOLED"
empty="$(lr_eng "$CLOSER" "$DIST" "$BASE" "$NOLED" "$THEIRS" 2>&1)"; empty_rc=$?
if [ -z "$empty" ] && [ "$empty_rc" -eq 0 ]; then
  lr_okf '%-22s silent, exit 0  (real consumer root, default ledger absent -> genuinely nothing to re-verify)\n' "no-ledger"
else
  lr_badf '%-22s rc=%s output=[%s] — a consumer that never filed a candidate must stay silent\n' "no-ledger" "$empty_rc" "$empty"
fi

# ARM 1 — an explicitly-supplied arg-5 path that is not readable. Nothing was re-verified, and
# that used to be spelled as zero rows and rc=0, which is how a clean corpus is spelled.
# Measured at 0.300.0 on the reference consumer: bogus arg 5 gave 0 rows, rc=0 and ZERO bytes of
# stderr, against 74 rows for the correct invocation.
ASSERTIONS=$((ASSERTIONS + 1))
bad5="$(lr_eng "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$DIST/nonexistent-ledger.md" 2>/dev/null)"; b5_rc=$?
bad5_n="$(printf '%s\n' "$bad5" | awk -F'\t' '$1=="INPUT-UNRESOLVED"{c++} END{print c+0}')"
if [ "$bad5_n" -eq 1 ] && grep -qF 'nonexistent-ledger.md' <<<"$bad5"; then
  printf -v _m '%-22s one INPUT-UNRESOLVED row naming the arg-5 path' "bad-arg5"; ok "$_m"
else
  lr_badf '%-22s got %s INPUT-UNRESOLVED row(s); an unreadable arg-5 path must not read as a clean corpus\n' "bad-arg5" "$bad5_n"
  printf '%s\n' "$bad5" | sed 's/^/          | /'
fi

# ARM 2 — THE MISTAKE THAT WAS ACTUALLY MADE, and the reason arm 1 alone is not the fix. This
# tool takes consumer THIRD and theirs FOURTH; every sibling in reconcile/ takes
# `<dist> <base> <theirs> <consumer>`, and layer-drift.sh's own usage line is the opposite
# order. Swapping them puts a SHA in the consumer slot, so `$LEDGER` is the DEFAULT path under a
# root that does not exist and an arg-5-only check never fires. The consumer root is therefore
# checked on its own.
ASSERTIONS=$((ASSERTIONS + 1))
swapped="$(lr_eng "$CLOSER" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null)"; sw_rc=$?
sw_n="$(printf '%s\n' "$swapped" | awk -F'\t' '$1=="INPUT-UNRESOLVED"{c++} END{print c+0}')"
if [ "$sw_n" -eq 1 ]; then
  printf -v _m '%-22s swapped args report, though the ledger path is the DEFAULT one' "swapped-args"; ok "$_m"
else
  lr_badf '%-22s got %s INPUT-UNRESOLVED row(s) — an arg-5-only check cannot see this case\n' "swapped-args" "$sw_n"
  printf '%s\n' "$swapped" | sed 's/^/          | /'
fi

# BOTH ARMS STILL EXIT 0. This is a classifier and its callers depend on that; the ROW is the
# signal, not the status code. An arm that reported by exiting non-zero would block `apply`.
ASSERTIONS=$((ASSERTIONS + 1))
# The statuses are those of the two runs above, captured where they ran -- not two more runs.
if [ "$sw_rc" -eq 0 ] && [ "$b5_rc" -eq 0 ]; then
  lr_okf '%-22s both caller-error arms exit 0  (classifier never blocks)\n' "input-exit-code"
else
  lr_badf '%-22s swapped=%s bad-arg5=%s want 0/0 — reporting by exit code blocks apply\n' "input-exit-code" "$sw_rc" "$b5_rc"
fi

} # end lr_unit_caller_error
lr_unit_consumer_root() {
# --- THE CONSUMER ROOT IS NORMALIZED, AND THE FAILURE WAS A FALSE CLOSE -------------------
# `.` is a valid consumer root and callers routinely pass it. It is the only one of the four
# exported values a receipt reads AS A PATH, so a receipt whose own claim is about absolute-path
# handling has its subject handed to it in the wrong form and its `&&` chain inverts. Entry
# SH-CWD in the seed is exactly that shape; without it this differential cannot fail.
#
# THE ASSERTION IS BYTE-IDENTITY ACROSS THE TWO FORMS, not a verdict on one of them: the claim
# is that the form of the argument does not decide any row. Measured on the reference consumer
# at 0.300.0 — 74 rows either way, ONE differing, a CLOSE-CANDIDATE against a STILL-LIVE.
ASSERTIONS=$((ASSERTIONS + 1))
rel_out="$(cd "$CONS" && lr_eng "$CLOSER" "$DIST" "$BASE" . "$THEIRS" 2>/dev/null | sort)"
abs_out="$(printf '%s\n' "$OUT" | sort)"
rel_n="$(printf '%s\n' "$rel_out" | grep -c . )"
abs_n="$(printf '%s\n' "$abs_out" | grep -c . )"
if [ "$rel_n" -eq 0 ] || [ "$abs_n" -eq 0 ]; then
  lr_badf '%-22s one side produced NO rows (rel=%s abs=%s) — two empty sets agree, which proves nothing\n' "consumer-form" "$rel_n" "$abs_n"
elif [ "$rel_out" = "$abs_out" ]; then
  printf -v _m '%-22s %s rows, byte-identical whether the root arrives as "." or absolute' "consumer-form" "$rel_n"; ok "$_m"
else
  lr_badf '%-22s the ROOT ARGUMENT decided a verdict:\n' "consumer-form"
  diff <(printf '%s\n' "$rel_out") <(printf '%s\n' "$abs_out") | sed 's/^/          | /'
fi

# SH-CWD must be STILL-LIVE in the normal run, or the differential above could be satisfied by
# a closer that drops the entry on both sides.
row_is "Entry SH-CWD" STILL-LIVE "an absolute root makes the absolute arm behave as the entry claims -> stays open"

} # end lr_unit_consumer_root
lr_unit_receipts_undecided() {
# --- RECEIPTS-UNDECIDED: how much of the STILL-LIVE column this pull actually measured ----
# Both entries are STILL-LIVE, so the status alone cannot separate them. TH-UNDECIDED's
# substring is at BOTH refs (this pull moved neither side of the predicate); TH-DECIDED's
# arrived inside base..theirs. The pair is what makes the tally a finding rather than a count
# of still-live rows.

# The numerator and the denominator are both asserted. A row saying "4 of 4" would be a count of
# still-live theirs_has receipts wearing this row's name; the claim is specifically about the
# subset whose predicate did not move in range.
#
# THE DENOMINATOR IS FIVE, AND WHICH FIVE IS THE POINT. TH-UNDECIDED, TH-DECIDED, the vacuous
# MARKER_A entry, PC-FIXTURE-BARE-BACKTICK's close and PC-FIXTURE-CLEAN-PATH's close. The six
# receipts carrying a backslash (ESCAPED-BACKTICK, LITERAL-BACKSLASH, SECOND-SUBSTRING,
# ESCAPED-QUOTE, ESCAPED-PATH, and REGEX-ANCHOR's theirs_lacks) are REFUSED before the tally and
# must not be in it -- a refused receipt is not a measurement -- so a guard placed after the
# tally increment reads a larger denominator here and fails this arm (built and driven by the
# batch-56 scope hand on the four-seed version: 1 of 6 against a wanted 1 of 4).
ASSERTIONS=$((ASSERTIONS + 1))
und="$(printf '%s\n' "$OUT" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{print $3; exit}')"
if grep -q "^1 of 5 'theirs_has' receipt" <<<"$und"; then
  lr_okf '%-22s 1 of 5 — the control is excluded, the vacuous entry still counts in the total, and the refused anchors do not\n' "undecided-tally"
else
  lr_badf '%-22s want "1 of 5", got: %s\n' "undecided-tally" "${und:-<no row>}"
fi

# It must reach the operator, which means NOT being STILL-LIVE: emit-report.sh filters that one
# status out, and that filter is exactly why this confidence has been invisible.
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{n++} END{exit !(n==1)}'; then
  lr_okf '%-22s exactly one run-scoped row, and its status is not STILL-LIVE\n' "undecided-once"
else
  lr_badf '%-22s want exactly one RECEIPTS-UNDECIDED row\n' "undecided-once"
fi

# SILENT AT ZERO. A ledger whose receipts are all well-anchored must say nothing, or the row is
# decoration on every pull and the operator learns to skip it.
ASSERTIONS=$((ASSERTIONS + 1))
zled="$CONS/_bmad-output/ai-dlc-update/well-anchored-ledger.md"
mkdir -p "$(dirname "$zled")"
printf -- '- **Entry ZA** — anchored on a token that arrived inside base..theirs.\n  verify: theirs_has core/skills/ai-dlc/SKILL.md "MARKER_B"\n' > "$zled"
z_out="$(lr_eng "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$zled" 2>/dev/null)"
z_n="$(printf '%s\n' "$z_out" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{c++} END{print c+0}')"
z_live="$(printf '%s\n' "$z_out" | awk -F'\t' '$1=="STILL-LIVE"{c++} END{print c+0}')"
if [ "$z_n" -eq 0 ] && [ "$z_live" -eq 1 ]; then
  lr_okf '%-22s no row when every receipt moved in range (control: the run still emitted its STILL-LIVE)\n' "undecided-silent"
else
  lr_badf '%-22s got %s undecided row(s) and %s still-live on a well-anchored ledger; want 0 and 1\n' "undecided-silent" "$z_n" "$z_live"
fi
rm -f "$zled"

} # end lr_unit_receipts_undecided
lr_unit_sh_base_control() {
# --- THE `sh` BASE CONTROL: does a STILL-LIVE say the PULL measured anything? -----------------
#
# THE STATE UNDER TEST. `verify: sh` exported `$BASE` to every receipt and evaluated nothing at
# it, so an `sh` STILL-LIVE said "exit 0 at theirs" and nothing about whether base..theirs is
# what produced that. The engine now re-runs the receipt byte-identically with `$THEIRS` rebound
# to `$BASE` and folds the result into the EXISTING RECEIPTS-UNDECIDED row.
#
# EVERY RECEIPT HERE IS ASSERTED BY ITS rc PAIR BEFORE ANY ROW IS READ, and that ordering is the
# arm rather than a nicety. The adversary's own first positive control read SAME because its
# anchor came back truncated from a `grep -o`: a truncated anchor matches at NEITHER ref, which
# is byte-indistinguishable from a receipt the pull genuinely did not move. Without the rc pair
# a ledger of 30 SAME readings reads as a working check forever.
#
# THE SEEDS VARY IN SHAPE, NOT ONLY IN OUTCOME. `theirs_has` receipts elsewhere in this fixture
# are built one way, so a battery whose `sh` seeds were built that way too would agree with the
# reader for that reason. These are a `git show | grep`, a `cat-file -e`, a command-substitution
# string compare, an `&&` chain and a bare `false` -- five constructions across seven receipts.
SBC="$(dirname "$DIST")/sh-base-control"
mkdir -p "$SBC"

# THE RECEIPT IS RUN THROUGH THE ENGINE'S OWN WRAPPER AND ITS OWN EXPORT LIST, one binding apart.
# A precondition measured with a different environment is a second program, and its agreement
# would be about that program.
sbc_rc() { # <receipt-text> <theirs-value> -> the receipt's status
  local prog
  prog="cd \"$CONS\" && { $1
}"
  DIST="$DIST" BASE="$BASE" THEIRS="$2" CONSUMER="$CONS" THEIRS_TREE="" \
    bash -c "$prog" >/dev/null 2>&1
}
# Receipt texts, held ONCE so the precondition and the ledger cannot drift apart. A precondition
# measured on a receipt the ledger does not carry is the shape this avoids.
SBC_MOVER='git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc/SKILL.md" | LC_ALL=C grep -q MARKER_B'
SBC_SAME='git -C "$DIST" cat-file -e "${THEIRS}:VERSION"'
SBC_REFUSED='v=$(git -C "$DIST" show "${THEIRS}:VERSION"); [ "$v" = "0.103.0" ] || zznosuchcommandever'
# THE REFUSAL SEED EXISTS IN BOTH DIRECTIONS. On the STILL-LIVE side a 127 base control reaches
# `[ "$_brc" -eq 0 ]`, which 127 fails, so it enters no numerator; on the CLOSE side the test is
# `[ "$_brc" -ne 0 ]`, which 127 SATISFIES, so a refused control would be scored *decided* on an
# evaluation that never happened. Only the second direction can show that.
SBC_CREFUSED='v=$(git -C "$DIST" show "${THEIRS}:VERSION"); [ "$v" = "0.103.0" ] && exit 1; zznosuchcommandever'
SBC_CUNDEC='[ "$(git -C "$DIST" show "${THEIRS}:VERSION")" = "9.9.9" ]'
SBC_CMOVED='[ "$(git -C "$DIST" show "${THEIRS}:VERSION")" = "0.100.0" ]'
SBC_EXBASE='git -C "$DIST" cat-file -e "${BASE}:VERSION" && git -C "$DIST" cat-file -e "${THEIRS}:VERSION"'
# `test -f`, NOT `[ -f … ]`, AND THAT IS I106 RATHER THAN A PREFERENCE. This receipt reads a
# file inside the materialized theirs-tree; the bracket spelling of that read is byte-identical
# to the root-resolver walk I106 refuses in a SHIPPING fixture, and its grammar cannot tell the
# two apart. Measured: the bracket form failed the gate at this line against a control of zero
# on the revision before it. The invariant is right and the seed is what moves -- a shipping
# fixture must not carry the string at all, whatever it means locally.
SBC_EXTREE='[ -n "${THEIRS_TREE:-}" ] || exit 127; test -f "$THEIRS_TREE/VERSION"'
SBC_EXNEITHER='false'

# THE PRECONDITION. Seven receipts, fourteen statuses, every one asserted against the value the
# arms below depend on. MARKER_B arrives inside base..theirs, so the mover is 0/1; VERSION exists
# at both refs, so the same-reader is 0/0; the refused one runs a command that does not exist only
# when the version does not match, which is true at base alone.
ASSERTIONS=$((ASSERTIONS + 1))
sbc_bad=""
sbc_probe() { # <name> <text> <want-theirs> <want-base>
  local rt rb
  sbc_rc "$2" "$THEIRS"; rt=$?
  sbc_rc "$2" "$BASE";   rb=$?
  [ "$rt" = "$3" ] && [ "$rb" = "$4" ] || sbc_bad="$sbc_bad [$1 got $rt/$rb want $3/$4]"
}
sbc_probe MOVER      "$SBC_MOVER"     0 1
sbc_probe SAME       "$SBC_SAME"      0 0
sbc_probe REFUSED    "$SBC_REFUSED"   0 127
sbc_probe CLOSE-REFUSED "$SBC_CREFUSED" 1 127
sbc_probe CLOSE-UNDEC "$SBC_CUNDEC"   1 1
sbc_probe CLOSE-MOVED "$SBC_CMOVED"   1 0
sbc_probe EX-BASE    "$SBC_EXBASE"    0 0
sbc_probe EX-NEITHER "$SBC_EXNEITHER" 1 1
# THE CONTROL FOR THAT AGREEMENT: a receipt whose two sides are asserted to DIFFER from what the
# seven claim. If `sbc_rc` had stopped running the receipt at all it would answer one constant,
# every probe above would still be comparable, and this one catches that -- a receipt that reads
# 0 at theirs and 0 at base, asserted to be NOT 0/1, cannot be satisfied by a constant 0/1.
sbc_rc 'true' "$THEIRS"; sbc_ctl_t=$?
sbc_rc 'exit 3' "$THEIRS"; sbc_ctl_f=$?
if [ -z "$sbc_bad" ] && [ "$sbc_ctl_t" -eq 0 ] && [ "$sbc_ctl_f" -eq 3 ]; then
  lr_okf '%-22s all seven probe receipts carry the rc pair their arm depends on, measured through the engine own wrapper (control: a trivial receipt answers 0 and an exit-3 receipt answers 3, so the runner is not returning a constant)\n' "sbc-preconditions"
else
  lr_badf '%-22s a probe receipt does not carry the rc pair its arm assumes%s (runner control: %s/%s, want 0/3) -- a receipt that matches at NEITHER ref reads exactly like one the pull did not move, so every count below would be unreadable\n' "sbc-preconditions" "${sbc_bad:- none}" "$sbc_ctl_t" "$sbc_ctl_f"
fi

# THE LEDGER. One entry per class, so each count below has exactly one member and a number that
# moves names which class moved it. A denominator with two members in a class cannot say which.
SBC_LED="$SBC/probe-ledger.md"
{
  printf '# probe\n\n'
  printf '## PC-PROBE-MOVER - the pull MOVED it: exit 0 at theirs, non-zero at base\n\n'
  printf 'verify: sh %s\n\n---\n\n' "$SBC_MOVER"
  printf '## PC-PROBE-SAME - reads the same at both refs\n\n'
  printf 'verify: sh %s\n\n---\n\n' "$SBC_SAME"
  printf '## PC-PROBE-REFUSED - the base control exits 127, so it never ran\n\n'
  printf 'verify: sh %s\n\n---\n\n' "$SBC_REFUSED"
  printf '## PC-PROBE-CLOSE-REFUSED - closes at theirs, and its base control exits 127\n\n'
  printf 'verify: sh %s\n\n---\n\n' "$SBC_CREFUSED"
  printf '## PC-PROBE-CLOSE-UNDECIDED - closes, and was already closed at base\n\n'
  printf 'verify: sh %s\n\n---\n\n' "$SBC_CUNDEC"
  printf '## PC-PROBE-CLOSE-MOVED - closes BECAUSE the pull moved it\n\n'
  printf 'verify: sh %s\n\n---\n\n' "$SBC_CMOVED"
  printf '## PC-PROBE-EX-BASE - names $BASE itself, so the rebinding would compare base to base\n\n'
  printf 'verify: sh %s\n\n---\n\n' "$SBC_EXBASE"
  printf '## PC-PROBE-EX-TREE - reads $THEIRS_TREE, materialized at theirs with no base twin\n\n'
  printf 'verify: sh %s\n\n---\n\n' "$SBC_EXTREE"
  printf '## PC-PROBE-EX-NEITHER - names neither ref, so no rebinding can move it\n\n'
  printf 'verify: sh %s\n' "$SBC_EXNEITHER"
} > "$SBC_LED"

sbc_out="$(lr_eng "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$SBC_LED" 2>/dev/null)"
sbc_det="$(printf '%s\n' "$sbc_out" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{print $3; exit}')"
sbc_row() { # <label> <want-status>
  ASSERTIONS=$((ASSERTIONS + 1))
  if printf '%s\n' "$sbc_out" | awk -F'\t' -v l="$1" -v s="$2" "$LR_LM"'lm($2, l) && $1 == s {f=1} END{exit !f}'; then
    lr_okf '%-22s %s\n' "$1" "$2"
  else
    lr_badf '%-22s want %s, got: %s\n' "$1" "$2" "$(printf '%s\n' "$sbc_out" | awk -F'\t' -v l="$1" "$LR_LM"'lm($2, l) {print $1; exit}')"
    printf '%s\n' "$sbc_out" | sed 's/^/          | /'
  fi
}
sbc_det_has() { # <name> <substring> <why>
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ -n "$sbc_det" ] && [ "${sbc_det#*"$2"}" != "$sbc_det" ]; then
    lr_okf '%-22s %s\n' "$1" "$3"
  else
    lr_badf '%-22s the undecided detail does not carry "%s" (%s). Detail: %s\n' "$1" "$2" "$3" "${sbc_det:-<no row>}"
  fi
}
sbc_det_lacks() { # <name> <substring> <why>
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ -z "$sbc_det" ]; then
    lr_badf '%-22s there is no undecided row at all, so this absence is not a measurement (%s)\n' "$1" "$3"
  elif [ "${sbc_det#*"$2"}" = "$sbc_det" ]; then
    lr_okf '%-22s %s\n' "$1" "$3"
  else
    lr_badf '%-22s the undecided detail carries "%s" and must not (%s)\n' "$1" "$2" "$3"
  fi
}

# THE VERDICTS FIRST. The count arms below read a number; these read the rows that number is
# about, so a count that is right for the wrong reason is still caught.
sbc_row PC-PROBE-MOVER           STILL-LIVE
sbc_row PC-PROBE-SAME            STILL-LIVE
sbc_row PC-PROBE-REFUSED         STILL-LIVE
sbc_row PC-PROBE-CLOSE-REFUSED   CLOSE-CANDIDATE
sbc_row PC-PROBE-CLOSE-UNDECIDED CLOSE-CANDIDATE
sbc_row PC-PROBE-CLOSE-MOVED     CLOSE-CANDIDATE

# THE NUMERATOR AND THE DENOMINATOR, AND WHICH RECEIPTS ARE IN EACH IS THE POINT. Three eligible
# STILL-LIVE receipts reach the control: the mover, the same-reader and the refused one. Only the
# same-reader is undecided -- the mover is a measurement, and the refused one never ran.
sbc_det_has sbc-live-tally "1 of 3 'verify: sh' receipt(s) reported STILL-LIVE" \
  "1 of 3: the SAME-reader is undecided, the MOVER is not, and the REFUSED one is in no numerator"
sbc_det_has sbc-close-tally "1 of 3 'verify: sh' CLOSE-CANDIDATE(s) ALSO exited non-zero at BASE" \
  "1 of 3 on the CLOSE path: the already-closed-at-base receipt is counted, while the one the pull MOVED and the one whose control REFUSED are not"
sbc_det_has sbc-refused-counted "2 'verify: sh' base control(s) REFUSED" \
  "both 127 controls -- one from each direction -- are reported separately, beside the numerators rather than inside either"
sbc_det_has sbc-ex-base "1 naming \$BASE themselves" \
  "the \$BASE-naming receipt is excluded and its class is NAMED in the row"
sbc_det_has sbc-ex-tree "1 reading \$THEIRS_TREE" \
  "the \$THEIRS_TREE receipt is excluded and its class is NAMED in the row"
sbc_det_has sbc-ex-neither "1 naming neither \$THEIRS nor \$DIST" \
  "the consumer-only receipt is excluded and its class is NAMED in the row"
# ...AND THE OTHER DIRECTION, without which every arm above is satisfied by a row that recites
# every class on every ledger. The `theirs_has` clause must be ABSENT here: this ledger carries
# no `theirs_has` receipt, so a row opening with that verb would be reciting rather than counting.
sbc_det_lacks sbc-no-th-clause "'theirs_has' receipt(s) reported STILL-LIVE" \
  "no theirs_has clause on a ledger carrying no theirs_has receipt -- the clauses are counted, not recited"

# SILENCE, ARM ONE: A LEDGER WHOSE RECEIPTS ALL MOVED. The row must not appear, or it is
# decoration on every pull. The control is that the run still emitted its other rows -- an engine
# that died reports no undecided row either, and that silence would read identically.
SBC_MOV_LED="$SBC/movers-only.md"
{
  printf '# probe\n\n'
  printf '## PC-PROBE-MOVER-A - moved in range\n\n'
  printf 'verify: sh %s\n\n---\n\n' "$SBC_MOVER"
  printf '## PC-PROBE-MOVER-B - the close direction, also moved in range\n\n'
  printf 'verify: sh %s\n' "$SBC_CMOVED"
} > "$SBC_MOV_LED"
sbc_mv="$(lr_eng "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$SBC_MOV_LED" 2>/dev/null)"
sbc_mv_u="$(printf '%s\n' "$sbc_mv" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{c++} END{print c+0}')"
sbc_mv_r="$(printf '%s\n' "$sbc_mv" | awk -F'\t' '$1=="STILL-LIVE" || $1=="CLOSE-CANDIDATE"{c++} END{print c+0}')"
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$sbc_mv_r" -lt 2 ]; then
  lr_badf '%-22s the movers-only ledger produced %s verdict row(s), not 2 -- the run did not happen, so its silence establishes nothing\n' "sbc-silent-movers" "$sbc_mv_r"
elif [ "$sbc_mv_u" -eq 0 ]; then
  lr_okf '%-22s a ledger whose receipts ALL moved in range emits no undecided row (control: both verdict rows still reported)\n' "sbc-silent-movers"
else
  lr_badf '%-22s %s undecided row(s) on a ledger where every receipt moved -- the count is a constant, not a finding\n' "sbc-silent-movers" "$sbc_mv_u"
fi

# SILENCE, ARM TWO: THE NULL DIFFERENTIAL. Driven with base == theirs, every receipt answers the
# same at both sides BY CONSTRUCTION and a 100% count would be a fact about the invocation. The
# same probe ledger is used, so the two silences differ in the REFS and in nothing else.
sbc_nl="$(lr_eng "$CLOSER" "$DIST" "$THEIRS" "$CONS" "$THEIRS" "$SBC_LED" 2>/dev/null)"
sbc_nl_u="$(printf '%s\n' "$sbc_nl" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{c++} END{print c+0}')"
sbc_nl_r="$(printf '%s\n' "$sbc_nl" | awk -F'\t' '$1!="RECEIPTS-UNDECIDED"{c++} END{print c+0}')"
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$sbc_nl_r" -eq 0 ]; then
  lr_badf '%-22s the null-differential run emitted no rows at all, so its silence is an engine that did not run\n' "sbc-silent-null"
elif [ "$sbc_nl_u" -eq 0 ]; then
  lr_okf '%-22s base == theirs emits no undecided row (control: %s other rows still reported) -- a pull that moved nothing is a different claim, made by saying nothing\n' "sbc-silent-null" "$sbc_nl_r"
else
  lr_badf '%-22s %s undecided row(s) on a NULL differential -- every receipt reads one tree twice, so the count measures the invocation\n' "sbc-silent-null" "$sbc_nl_u"
fi

# --- A RECEIPT THAT READS STDIN MUST NOT EAT THE ENTRIES AFTER IT ------------------------------
#
# THE DEFECT. The entry loop is `while … read …; done <<< "$ENTRIES"`, and both `bash -c` sites
# inside it -- the evaluation and `sh_base_rc` -- ran the receipt with fd 0 INHERITED, positioned at
# the next entry. A receipt that reads stdin consumed every entry after its own: those entries
# emitted NO ROW, rc stayed 0 and stderr stayed empty, so a shorter report read as a clean one.
#
# TWO LEDGERS, ONE PER SITE, AND EACH FIRST RECEIPT READS STDIN AT ONE SITE ONLY, so a fault at one
# redirect cannot be hidden by the other site's arm:
#   - EVAL: `cat` then a passing check, naming neither ref -- bucket 3, so it never reaches the
#     base control and only the evaluation site can hand it the loop's stdin.
#   - BASE: the `cat` runs only when `$THEIRS` equals the LITERAL base sha, which is true inside
#     the base control's rebinding and false at the evaluation. The literal is load-bearing:
#     spelled `$BASE`, `sh_base_eligible` excludes the receipt and the base control never runs it.
# The eaten entries are a STILL-LIVE and a CLOSE-CANDIDATE, the same receipts the arms above
# already measure, so each verdict is asserted for its value and not merely for being there.
SI_EVAL_LED="$SBC/stdin-eval.md"
SI_BASE_LED="$SBC/stdin-base.md"
si_ledger() { # <file> <first-receipt>
  {
    printf '# probe\n\n'
    printf '## PC-STDIN-READER - its receipt reads stdin\n\n'
    printf 'verify: sh %s\n\n---\n\n' "$2"
    printf '## PC-STDIN-NEXT-LIVE - the entry right after it\n\n'
    printf 'verify: sh %s\n\n---\n\n' "$SBC_SAME"
    printf '## PC-STDIN-LAST-CLOSE - the entry after that\n\n'
    printf 'verify: sh %s\n' "$SBC_CMOVED"
  } > "$1"
}
si_ledger "$SI_EVAL_LED" 'cat >/dev/null; true'
si_ledger "$SI_BASE_LED" "[ \"\$THEIRS\" = \"$BASE\" ] && cat >/dev/null; git -C \"\$DIST\" cat-file -e \"\${THEIRS}:VERSION\""
si_verdicts() { # <engine> <ledger> -> "<reader> <next> <last>" statuses, "-" where no row
  local o
  o="$(lr_eng "$1" "$DIST" "$BASE" "$CONS" "$THEIRS" "$2" 2>/dev/null)"
  printf '%s\n' "$o" | awk -F'\t' '
    index($2,"PC-STDIN-READER ")==1{r=$1} index($2,"PC-STDIN-NEXT-LIVE ")==1{n=$1} index($2,"PC-STDIN-LAST-CLOSE ")==1{l=$1}
    END{printf "%s %s %s", (r?r:"-"), (n?n:"-"), (l?l:"-")}'
}
SI_WANT="STILL-LIVE STILL-LIVE CLOSE-CANDIDATE"
for si in eval base; do
  case "$si" in eval) led="$SI_EVAL_LED" ;; *) led="$SI_BASE_LED" ;; esac
  got="$(si_verdicts "$CLOSER" "$led")"
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ "$got" = "$SI_WANT" ]; then
    lr_okf '%-22s all three entries report, with their own verdicts, after a receipt that reads stdin at the %s site\n' "stdin-$si" "$si"
  else
    lr_badf '%-22s got "%s", want "%s" -- a receipt that reads stdin ate the entries after it, and the report is shorter with rc 0\n' "stdin-$si" "$got" "$SI_WANT"
  fi
done

} # end lr_unit_sh_base_control
lr_unit_close_anchor() {
# --- THE CLOSE PREDICATE IS ANCHORED, like the verify: predicate beside it -------------
# Unanchored, a PROSE MENTION of the vocabulary closed a live entry, and the failure was silent
# in the worse direction: no row at all rather than a wrong one. Measured on the reference
# consumer, four entries with live receipts were invisible. The discriminator is line-leading
# STRUCTURE — an annotation opens its line (bare, or opening a bold span, optionally behind the
# <br> the entry bodies use); a mention sits inside a sentence.
row_is "PROSE-MENTIONS-THE-VOCABULARY" STILL-LIVE \
  "an OPEN entry quoting the close markers in prose, a blockquote and a code span still reports"

} # end lr_unit_close_anchor
lr_unit_every_receipt() {
# --- EVERY RECEIPT, NOT THE LAST ONE ---------------------------------------------------
# `directive` was a scalar assigned inside a per-line awk rule, so a second line-leading `verify:`
# silently overwrote the first. Measured on the reference consumer AFTER the fix: 2 entries carry
# multiple receipts (one with two, one with four), so FOUR receipts were being discarded on every
# pull. Their surviving verdicts happened to agree there, which is precisely how the defect went
# unnoticed — the row was never wrong, the question was never asked.
#
# This pair disagrees on purpose: a close and a still-live in one entry. The scalar kept the close.
row_has "PC-FIXTURE-TWO-RECEIPTS" STILL-LIVE \
  "receipt 1 of 2 is genuinely live and must not be swallowed by the close that follows it"

# The ordinal has to be on the row, or two rows for one entry are unattributable.
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | grep -F 'PC-FIXTURE-TWO-RECEIPTS' | grep -q '\[receipt 1/2\]'; then
  lr_okf '%-22s rows carry their receipt ordinal\n' "receipt-ordinal"
else
  lr_badf '%-22s two rows for one entry with no ordinal to tell them apart\n' "receipt-ordinal"
fi

# A SINGLE-receipt entry must be byte-unchanged — no ordinal suffix. Otherwise the fix rewrites
# every row in every consumer report to buy a two-entry improvement.
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | grep -F 'Entry A' | grep -q '\[receipt '; then
  lr_badf '%-22s a single-receipt entry grew an ordinal suffix\n' "single-unchanged"
else
  lr_okf '%-22s single-receipt rows unchanged (no suffix)\n' "single-unchanged"
fi

} # end lr_unit_every_receipt
lr_unit_name_signal() {
# --- THE NAME IS THE THIRD SIGNAL ------------------------------------------------------
# Every predicate above tests the RECEIPT, which is the wrong instrument when the receipt is
# what is broken. A receipt anchored on a token present at both refs, or an inverted verb, or
# `verify: manual`, can never close its entry no matter how many pulls run it. The entry id in
# upstream's own commit message is the one signal a rewording cannot defeat.
#
# Measured on the reference consumer: 51 heading labels, 37 id-shaped, 4 named — all four true
# positives, each invisible to every other predicate in this file, and 33 id-shaped labels
# silent. That 33 is the control that this discriminates rather than rubber-stamps.
row_has "PC-FIXTURE-NAMED-BUT-RECEIPT-STUCK" STILL-LIVE \
  "the receipt's own verdict still prints — the pair IS the finding, and suppressing either half loses a fact"
row_has "PC-FIXTURE-NAMED-MANUAL" NAMED-UPSTREAM \
  "fires for verify: manual, the shape with no other mechanical signal at all"
row_has "PC-FIXTURE-NAMED-MANUAL" HAND-REVIEW \
  "manual is still a declaration, not downgraded by the extra row"

# THE CONTROLS. An id-shaped label upstream never named must stay silent, or the row means
# nothing; and a PROSE label must stay silent even though the pre-base commit quotes it verbatim.
row_lacks "PC-FIXTURE-HEADING-ABSORBED" NAMED-UPSTREAM \
  "id-shaped but never named upstream -> silent, so the signal is a discriminator"
row_lacks "Entry A" NAMED-UPSTREAM \
  "prose label quoted verbatim in the history -> the id-shape guard refuses to join on words"

} # end lr_unit_name_signal
lr_unit_short_id() {
# --- THE SHORT ID IS THE FORM UPSTREAM WRITES (PC-S328) ---------------------------------
# The join asked only for the FULL SLUG, and upstream's commits cite `PC-S<n>`. Measured on the
# reference consumer at 0.328.0: the slug search found 20 of 128 entries, while 20 of the 29
# distinct prefixes appeared in upstream's history. Among the misses were three entries that
# consumer had filed and upstream had just fixed — so on the entries where the third signal was
# most needed, it was silent.
row_lacks "PC-S901-SHORT-ID-UNIQUE-PREFIX" NAMED-UPSTREAM \
  "and the lone carrier is NOT attributed by name: a count of one says what this ledger still holds, not what the commit meant, and it would change if sprint history were deleted"

# AND THE NAIVE VERSION OF THAT FIX IS WRONG, WHICH IS WHY BOTH HALVES ARE ASSERTED. Of the 20
# cited prefixes on the reference consumer, 11 were shared by two or more entries. Matching the
# prefix regardless would name every entry the sprint filed.
row_lacks "PC-S902-SHARED-PREFIX-FIRST" NAMED-UPSTREAM \
  "a prefix carried by two entries is NOT attributed to either — a wrong close is worse than the silence it replaces"
row_lacks "PC-S902-SHARED-PREFIX-SECOND" NAMED-UPSTREAM \
  "and not to the other one either — the refusal is symmetric, not first-wins"

# ONE ROW, NOT ONE PER ENTRY. Per-entry emission produced 45 rows from 11 prefixes on the
# reference consumer, all saying the same unresolvable thing — noise added by the fix for a
# signal that was missing, which is the trade the naive prefix-match makes one level along.
# COUNTED PER PREFIX. The seed carries a second shared prefix (PC-S953) for the reach arms below,
# so a count over every AMBIGUOUS row would read 2 and say nothing about repetition.
ambig_n="$(printf '%s\n' "$OUT" | awk -F'\t' '$1=="NAMED-UPSTREAM-AMBIGUOUS" && $2=="PC-S902"{n++} END{print n+0}')"
ASSERTIONS=$((ASSERTIONS+1))
if [ "$ambig_n" = "1" ]; then
  lr_okf '%-22s exactly one ambiguous row for the two entries sharing PC-S902\n' "ambiguous-collapse"
else
  lr_badf '%-22s %s ambiguous row(s) — the prefix fact is being repeated per entry\n' "ambiguous-collapse" "$ambig_n"
fi

# THE CONTROL, and without it the arms above only prove the code runs. An id-shaped label
# whose prefix one open entry carries, and which upstream names in NEITHER form, must stay silent.
row_lacks "PC-S903-NEVER-CITED-AT-ALL" NAMED-UPSTREAM \
  "never cited in either form -> silent, so the prefix arm joins on evidence and not on shape"
row_lacks "PC-S903-NEVER-CITED-AT-ALL" NAMED-UPSTREAM-AMBIGUOUS \
  "and not reported as ambiguous either — an uncited prefix is not an unresolvable one"

} # end lr_unit_short_id
lr_unit_naming_set() {
# --- WHAT A NAMING SET CHANGED (BL-145) AND EVERY CITING COMMIT OF A PREFIX (BL-066) --------
# A naming commit that changes nothing under core/ or templates/ cannot have shipped a fix, and a
# plan that cross-references an id matched the message search exactly as the fix did. The row is
# KEPT under its own kind, with every sha: a wrong fix that deletes the row instead passes every
# arm keyed on the absence of NAMED-UPSTREAM, which is why S950 is asserted on PRESENCE.
if [ "$B2_RUN" = 0 ]; then
  LR_SKIPPED=1  # this unit's whole body is the SKIP below; the floor reads this, not silence
  printf '  SKIP  BL-145/BL-066 reach and citing-commit arms -- the installed ledger-reverify.sh predates them; they land with the pull that carries this fixture\n'
else
row_has   "PC-S951-TEMPLATES-ONLY-NAMING" NAMED-UPSTREAM \
  "templates/ is installed on a consumer -> a templates-only commit can be the absorption (a core/-only predicate demotes it)"
row_has   "PC-S952-MERGE-NAMING" NAMED-UPSTREAM \
  "a MERGE whose side branch changed core/ -> listed with -m, so the merge is not scored as touching nothing"
row_has   "PC-S954-RELEASE-COMMIT-NAMING" NAMED-UPSTREAM \
  "the only naming commit is a RELEASE (VERSION + CHANGELOG.md, fix in its parent) -> the plain kind, because that release is what a consumer pulls"
row_has   "PC-S905-ONE-NAMING-COMMIT-ONLY" NAMED-UPSTREAM \
  "the control: a core-touching single naming commit keeps the plain kind"
# THE AMBIGUOUS ROW: every citing commit, and the reach. Derived from the repo, not from the row:
# the commits whose MESSAGE carries `PC-S902` as a token (no seeded message carries a longer
# PC-S902 slug, so the fixed-string set is the token set).
s902_set="$(git -C "$DIST" log -F --grep='PC-S902' --format=%h "$THEIRS" 2>/dev/null)"
s902_n="$(printf '%s\n' "$s902_set" | grep -c . )" || s902_n=0
s902_row="$(printf '%s\n' "$OUT" | awk -F'\t' '$1=="NAMED-UPSTREAM-AMBIGUOUS" && $2=="PC-S902" {print $3; exit}')"
s953_row="$(printf '%s\n' "$OUT" | awk -F'\t' '$1=="NAMED-UPSTREAM-AMBIGUOUS" && $2=="PC-S953" {print $3; exit}')"
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$s902_n" -ne 2 ]; then
  lr_badf '%-22s FIXTURE BROKEN — PC-S902 is cited by %s commit(s) in the seed, want 2; the list arm has nothing to get wrong\n' "ambiguous-lists-all" "$s902_n"
else
  _miss=0; for _s in $s902_set; do case "$s902_row" in *"$_s"*) ;; *) _miss=$((_miss + 1)) ;; esac; done
  case "$s902_row" in
    *"in 2 commits, ALL of them:"*"and 2 entries in this ledger carry it"*)
      if [ "$_miss" -eq 0 ]; then
        printf -v _m '%-22s PC-S902 names BOTH citing commits and the commit count, and keeps the entry-count phrase ledger-rotate parses' "ambiguous-lists-all"; ok "$_m"
      else
        lr_badf '%-22s PC-S902 says two commits but lacks %s of their shas\n' "ambiguous-lists-all" "$_miss"
      fi ;;
    *) lr_badf '%-22s PC-S902 row does not name its 2 citing commits and the 2 entries: %s\n' "ambiguous-lists-all" "${s902_row:-<no row>}" ;;
  esac
fi
ASSERTIONS=$((ASSERTIONS + 1))
case "$s953_row|$s902_row" in
  *"NONE of them changes a path under core/ or templates/"*"|"*"NONE of them changes"*)
    lr_badf '%-22s PC-S902 (cited by a core commit) also reads docs-only — the reach is not discriminating\n' "ambiguous-reach" ;;
  *"NONE of them changes a path under core/ or templates/"*"|"*)
    lr_okf '%-22s PC-S953 (one docs-only citation) says no citing commit changes core/ or templates/; PC-S902 does not\n' "ambiguous-reach" ;;
  *) lr_badf '%-22s PC-S953 row does not carry the docs-only reach: %s\n' "ambiguous-reach" "${s953_row:-<no row>}" ;;
esac

# The reach rows over a ledger holding only the entries they read.
RCH="$(dirname "$DIST")/reach"; mkdir -p "$RCH"
awk '/^- \*\*PC-S9(02|05|5[0-4])-/ {p=1} /^- \*\*/ && !/^- \*\*PC-S9(02|05|5[0-4])-/ {p=0} p' \
  "$CONS/_bmad-output/ai-dlc-update/push-candidate-ledger.md" > "$RCH/ledger.md"
reach_rows() { lr_eng "$1" "$DIST" "$BASE" "$CONS" "$THEIRS" "$RCH/ledger.md" 2>/dev/null; }
reach_kind() { printf '%s\n' "$1" | awk -F'\t' -v l="$2" '$2 == l && $1 ~ /^NAMED-UPSTREAM(-DOCS-ONLY|-OFF-SUBJECT)?$/ {print $1; exit}'; }
rc_ctl="$(reach_rows "$CLOSER")"
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$(reach_kind "$rc_ctl" PC-S950-DOCS-ONLY-NAMING)" = NAMED-UPSTREAM-DOCS-ONLY ] \
   && [ "$(reach_kind "$rc_ctl" PC-S951-TEMPLATES-ONLY-NAMING)" = NAMED-UPSTREAM ] \
   && [ "$(reach_kind "$rc_ctl" PC-S952-MERGE-NAMING)" = NAMED-UPSTREAM ] \
   && [ "$(reach_kind "$rc_ctl" PC-S954-RELEASE-COMMIT-NAMING)" = NAMED-UPSTREAM ] \
   && grep -q "in 2 commits, ALL of them:" <<<"$rc_ctl"; then
  printf -v _m '%-22s the engine over the small ledger reproduces S950/S951/S952/S954 and the two-commit S902 row' "reach-control"; ok "$_m"
else
  lr_badf '%-22s the engine over the small ledger does not reproduce the reach rows\n' "reach-control"
fi
fi

} # end lr_unit_naming_set
lr_unit_cited_only() {
# --- THE NOT-DISCHARGED CITATION FORM (BL-145's producer half) --------------------------------
# A release citing an entry it did NOT discharge names it on a column-0 body line,
# `Not-discharged: PC-S<n>[-<SLUG>]`, and `named_cited_filter` drops a commit from the naming set
# when nothing but such lines names the id. Every seeded commit touches core/, so `named_reach`
# scores all of them `code`, and only the filter separates the five shapes (seed.sh, S955-S959).
#
# SHIPS AHEAD OF ITS SUBJECT like the B2 arms: a consumer whose installed engine predates the form
# SKIPs, keyed on the status only the fixed engine emits; in the distribution the arms always run.
if ! grep -qF 'NAMED-UPSTREAM-CITED-ONLY' "$CLOSER" && [ "$B2_ISDIST" = 0 ]; then
  LR_SKIPPED=1
  printf '  SKIP  BL-145 not-discharged citation arms -- the installed ledger-reverify.sh predates them; they land with the pull that carries this fixture\n'
  return 0
fi
row_has   "PC-S956-BOTH-FORMS-CITATION" NAMED-UPSTREAM \
  "named in the subject AND on a form line -> the ordinary mention still counts"
row_has   "PC-S957-FORM-Y" NAMED-UPSTREAM-CITED-ONLY \
  "the other id on that same commit, cited only in the form -> the citation kind"
row_has   "PC-S958-FORM-CORE-ORDINARY-DOCS" NAMED-UPSTREAM-DOCS-ONLY \
  "form on a core commit plus an ordinary docs mention -> reach is read over the residue, which is docs-only"
row_has   "PC-S959-INLINE-FORM-CITATION" NAMED-UPSTREAM \
  "the form appears mid-line, not at column 0 -> not a citation, the plain kind"

# The six entries the five shapes read, cut from the seeded ledger, and the engine run over them.
COD="$(dirname "$DIST")/cited-only"; mkdir -p "$COD"
awk '/^- \*\*PC-S95[5-9]-/ {p=1} /^- \*\*/ && !/^- \*\*PC-S95[5-9]-/ {p=0} p' \
  "$CONS/_bmad-output/ai-dlc-update/push-candidate-ledger.md" > "$COD/ledger.md"
co_rows() { lr_eng "$1" "$DIST" "$BASE" "$CONS" "$THEIRS" "$COD/ledger.md" 2>/dev/null; }
co_kind() { printf '%s\n' "$1" | awk -F'\t' -v l="$2" '$2 == l && $1 ~ /^NAMED-UPSTREAM(-DOCS-ONLY|-CITED-ONLY|-OFF-SUBJECT)?$/ {print $1; exit}'; }
CO_IDS="PC-S955-FORM-ONLY-CITATION PC-S956-BOTH-FORMS-CITATION PC-S957-ORDINARY-X PC-S957-FORM-Y PC-S958-FORM-CORE-ORDINARY-DOCS PC-S959-INLINE-FORM-CITATION"
CO_WANT="NAMED-UPSTREAM-CITED-ONLY NAMED-UPSTREAM NAMED-UPSTREAM NAMED-UPSTREAM-CITED-ONLY NAMED-UPSTREAM-DOCS-ONLY NAMED-UPSTREAM"
co_read() { # <rows> -> "id=kind ..." for the six ids
  local _i _s=""
  for _i in $CO_IDS; do _s="$_s $_i=$(co_kind "$1" "$_i")"; done
  printf '%s' "${_s# }"
}
co_expect() { # <id> -> the kind the engine must give it
  local _i _k _w="$CO_WANT"
  for _i in $CO_IDS; do _k="${_w%% *}"; _w="${_w#* }"; [ "$_i" = "$1" ] && { printf '%s' "$_k"; return; }; done
}
co_ctl="$(co_rows "$CLOSER")"
co_ctl_read="$(co_read "$co_ctl")"
co_ctl_want=""; for _i in $CO_IDS; do co_ctl_want="$co_ctl_want $_i=$(co_expect "$_i")"; done; co_ctl_want="${co_ctl_want# }"
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$co_ctl_read" = "$co_ctl_want" ]; then
  printf -v _m '%-22s the engine over the six-entry ledger reproduces every S955-S959 kind' "cited-control"; ok "$_m"
else
  lr_badf '%-22s the engine over the six-entry ledger read {%s}, want {%s}\n' "cited-control" "$co_ctl_read" "$co_ctl_want"
fi

# --- THE FAIL-OPEN PATH. When the filter's own git call fails, the naming set must come back
# UNFILTERED -- the row this engine produced before the form existed -- never empty, which would
# turn a tool error into a CITED-ONLY row. Forced with a `git` shim on PATH that refuses only the
# filter's `--no-walk=unsorted` call and leaves a sentinel, so the cell can prove the failure
# happened. Under the shim S955 must read the PRE-FILTER kind, NAMED-UPSTREAM.
CO_SHIM="$COD/shim"; rm -rf "$CO_SHIM"; mkdir -p "$CO_SHIM"
CO_REALGIT="$(command -v git)"
printf '#!/bin/bash\nfor a in "$@"; do case "$a" in --no-walk=unsorted) : > "%s/fired"; exit 128 ;; esac; done\nexec "%s" "$@"\n' \
  "$CO_SHIM" "$CO_REALGIT" > "$CO_SHIM/git"
chmod +x "$CO_SHIM/git"
co_failopen() { # <engine> -> S955's kind with the filter's git call failing, or BROKEN
  rm -f "$CO_SHIM/fired"
  local _r
  _r="$(PATH="$CO_SHIM:$PATH" lr_eng "$1" "$DIST" "$BASE" "$CONS" "$THEIRS" "$COD/ledger.md" 2>/dev/null)"
  [ -f "$CO_SHIM/fired" ] || { printf 'BROKEN'; return; }
  co_kind "$_r" PC-S955-FORM-ONLY-CITATION
}
ASSERTIONS=$((ASSERTIONS + 1))
co_fo="$(co_failopen "$CLOSER")"
if [ "$co_fo" = NAMED-UPSTREAM ]; then
  printf -v _m '%-22s with the filter'"'"'s git call failing, S955 reads the pre-filter NAMED-UPSTREAM -- a tool error is never a CITED-ONLY row' "cited-fail-open"; ok "$_m"
else
  lr_badf '%-22s with the filter'"'"'s git call failing S955 read %s, want NAMED-UPSTREAM (BROKEN = the shim never fired)\n' "cited-fail-open" "${co_fo:-<no row>}"
fi

# --- THE BOOTSTRAPPING CELL. `ledger-reverify.sh` is read by the ENGINE THE CONSUMER LAST INSTALLED:
# `lib.sh`'s `ledger_close_awk_pattern` lifts the close rule out of this file by structure, and the
# pull that delivers this file runs the previous release's lib.sh against it. That extractor must
# still find EXACTLY ONE rule here and lift a non-empty pattern that awk compiles, or apply and
# rotation refuse on the pull that carries the fix. Driven through the shipped lib.sh, sourced in a
# subshell with SELF pointed at a copy of this directory.
ASSERTIONS=$((ASSERTIONS + 1))
CO_BOOT="$COD/boot"; rm -rf "$CO_BOOT"; mkdir -p "$CO_BOOT"
cp "$(dirname "$CLOSER")/lib.sh" "$(dirname "$CLOSER")/ledger-reverify.sh" "$CO_BOOT/" 2>/dev/null
co_pat="$( SELF="$CO_BOOT"; . "$CO_BOOT/lib.sh" >/dev/null 2>&1; ledger_close_awk_pattern 2>/dev/null )"; co_prc=$?
co_fn="$( SELF="$CO_BOOT"; . "$CO_BOOT/lib.sh" >/dev/null 2>&1; ledger_close_awk 2>/dev/null )" || co_fn=""
co_np="$(printf '%s\n' "$co_pat" | grep -c .)" || co_np=0
if [ "$co_prc" = 0 ] && [ "$co_np" = 1 ] && [ -n "$co_fn" ] \
   && printf '**ADOPTED UPSTREAM (v1.0.0, verified x)**\nplain\n' | awk "$co_fn"' { if (ledger_body_closes($0)) c++ } END { exit (c == 1) ? 0 : 1 }'; then
  lr_okf '%-22s the shipped lib.sh extractor lifts exactly one close rule from this ledger-reverify.sh, and it compiles and closes one of two probe lines\n' "boot-close-extract"
else
  lr_badf '%-22s ledger_close_awk_pattern over this ledger-reverify.sh: rc=%s lines=%s fn=%s -- the previous engine would refuse the pull that delivers it\n' "boot-close-extract" "$co_prc" "$co_np" "${co_fn:+present}"
fi
} # end lr_unit_cited_only
lr_unit_off_subject() {
# --- THE OFF-SUBJECT KIND (BL-145's third class, cells S960-S970) ------------------------------
# A naming set that reaches code (core/, templates/, or a release) but changes NONE of the entry's
# own `theirs_has|theirs_lacks` receipt paths reads NAMED-UPSTREAM-OFF-SUBJECT; a naming commit
# that changes VERSION is judged over its RELEASE SPAN (previous VERSION change, exclusive, up to
# the commit). Every other shape keeps the kind it had before `named_subject` existed.
#
# ITS OWN WORLD, NOT THE SHARED SEED. The shared seed's sub-ledgers are cut by
# PC-S9 prefix regexes and PC-S902's commit count is asserted, so these cells live in a dist this
# unit builds under the run's temp root and a ledger holding only them. The cells:
#
#   S960  third class: a core commit names it and changes another file   -> OFF-SUBJECT
#   S961  squash release: one commit changes the subject AND VERSION     -> NAMED-UPSTREAM
#   S962  branch release: an unnamed parent fixes the subject, the naming
#         child changes only CHANGELOG.md and VERSION                     -> NAMED-UPSTREAM
#   S963  merge-shaped release: the fix arrives on the second parent and
#         the merge commit itself changes VERSION                          -> NAMED-UPSTREAM
#   S964  over-expansion: a release, then an unnamed commit touching the
#         subject, then a NON-release naming commit touching other core   -> OFF-SUBJECT
#   S965  two receipt paths, only the SECOND touched                       -> NAMED-UPSTREAM
#   S966  consumer-layout receipt path whose dist file is touched          -> NAMED-UPSTREAM
#   S967  consumer-layout receipt path whose dist file is untouched        -> OFF-SUBJECT, and the row
#         names BOTH the written path and the dist path it resolved to
#   S968  an ambiguous-basename path beside a resolvable untouched one     -> old kind
#   S969  untouched subject, the subject listing FAILS under a git shim   -> old kind
#   S970  `verify: manual`, no path receipt (the control)                  -> NAMED-UPSTREAM
#
# SHIPS AHEAD OF ITS SUBJECT like the cited-only arms: a consumer whose installed engine predates
# the kind SKIPs, keyed on the status only the fixed engine emits; in the distribution it always runs.
if ! grep -qF 'NAMED-UPSTREAM-OFF-SUBJECT' "$CLOSER" && [ "$B2_ISDIST" = 0 ]; then
  LR_SKIPPED=1
  printf '  SKIP  BL-145 off-subject arms -- the installed ledger-reverify.sh predates them; they land with the pull that carries this fixture\n'
  return 0
fi
OSW="$(dirname "$DIST")/off-subject"; rm -rf "$OSW"; mkdir -p "$OSW/dist"
OSD="$OSW/dist"
ASSERTIONS=$((ASSERTIONS + 1))
# THE WORLD, built under `set -e` in a subshell so any failed step is one refusal, not a half-seed.
# The status is captured AFTER the subshell, never tested by `if !`: bash ignores `set -e` inside
# any command whose status a condition reads, so the guarded form would build a half-seed silently.
os_rc=0
( set -e
  g() { git -C "$OSD" -c user.email=seed@fixture -c user.name=seed -c commit.gpgsign=false "$@"; }
  c() { g add -A; g commit -q -m "$1"; }
  g init -q
  mkdir -p "$OSD/core/scripts" "$OSD/core/skills/x"
  printf '0.1.0\n' > "$OSD/VERSION"
  for f in other os-third os-sq os-br os-mg os-ox os-two-a os-two-b os-lf os-cl os-cl2 os-amb os-amb-other os-man; do
    printf '#!/bin/sh\necho %s\n' "$f" > "$OSD/core/scripts/$f.sh"
  done
  # The SECOND `os-amb.sh`: a consumer-layout path naming that basename resolves to nothing.
  printf '#!/bin/sh\necho amb two\n' > "$OSD/core/skills/x/os-amb.sh"
  c 'root: every subject exists, VERSION 0.1.0'
  echo 1 >> "$OSD/core/scripts/other.sh"; c 'fix: an unrelated core change that mentions PC-S960-THIRD-CLASS'
  echo fix >> "$OSD/core/scripts/os-sq.sh"; printf '0.2.0\n' > "$OSD/VERSION"
  c '0.2.0 -- absorbs PC-S961-SQUASH-RELEASE'
  echo fix >> "$OSD/core/scripts/os-br.sh"; c 'fix(reconcile): the subject the next release discharges'
  printf '0.3.0\n' > "$OSD/VERSION"; printf '## 0.3.0\n\n- discharged\n' > "$OSD/CHANGELOG.md"
  c '0.3.0 -- discharges PC-S962-BRANCH-RELEASE'
  m="$(g symbolic-ref --short HEAD)"
  g checkout -q -b os-side
  echo fix >> "$OSD/core/scripts/os-mg.sh"; c 'side work, names no entry'
  g checkout -q "$m"
  printf 'a main-line note\n' > "$OSD/note.md"; c 'docs: a main-line note, names no entry'
  g merge -q --no-ff --no-commit os-side
  printf '0.4.0\n' > "$OSD/VERSION"; c '0.4.0 -- merge discharging PC-S963-MERGE-RELEASE'
  g branch -q -D os-side
  printf '0.5.0\n' > "$OSD/VERSION"; c '0.5.0 -- a release naming no entry'
  echo unrelated >> "$OSD/core/scripts/os-ox.sh"; c 'refactor: touches a subject and names nothing'
  echo 2 >> "$OSD/core/scripts/other.sh"; c 'fix: another core change that mentions PC-S964-OVER-EXPANSION'
  echo fix >> "$OSD/core/scripts/os-two-b.sh"; c 'fix: absorb PC-S965-TWO-PATHS-SECOND-TOUCHED'
  echo fix >> "$OSD/core/scripts/os-cl.sh"; c 'fix: absorb PC-S966-CONSUMER-PATH-TOUCHED'
  echo 3 >> "$OSD/core/scripts/other.sh"; c 'fix: a core change that mentions PC-S967-CONSUMER-PATH-UNTOUCHED'
  echo 4 >> "$OSD/core/scripts/other.sh"; c 'fix: a core change that mentions PC-S968-AMBIGUOUS-BASENAME'
  echo 5 >> "$OSD/core/scripts/other.sh"; c 'fix: a core change that mentions PC-S969-LISTING-FAILURE'
  echo 6 >> "$OSD/core/scripts/other.sh"; c 'fix: absorb PC-S970-MANUAL-RECEIPT'
) >/dev/null 2>&1 || os_rc=$?
if [ "$os_rc" -ne 0 ]; then
  lr_badf '%-22s FIXTURE BROKEN -- the off-subject world could not be built\n' "off-subject-seed"
  return 0
fi
OSB="$(git -C "$OSD" rev-list --max-parents=0 HEAD 2>/dev/null)"
OST="$(git -C "$OSD" rev-parse HEAD 2>/dev/null)"
# THE SHAPES, ASSERTED AGAINST THE REPO: S962's naming commit changes exactly CHANGELOG.md and
# VERSION and its parent names nothing; S963's naming commit is a merge that changes VERSION.
os_s962="$(git -C "$OSD" log -F --grep=PC-S962-BRANCH-RELEASE --format=%H "$OST")"
os_s963="$(git -C "$OSD" log -F --grep=PC-S963-MERGE-RELEASE --format=%H "$OST")"
os_s962_files="$(git -C "$OSD" show --name-only --format= "$os_s962" 2>/dev/null | sort | tr '\n' ' ')"
os_s962_parmsg="$(git -C "$OSD" log -1 --format=%B "${os_s962}^" 2>/dev/null)"
os_s963_np="$(git -C "$OSD" rev-list --parents -n 1 "$os_s963" 2>/dev/null | wc -w | tr -d ' ')"
os_s963_files="$(git -C "$OSD" log --no-walk -m --name-only --format= "$os_s963" 2>/dev/null)"
if [ -z "$OSB" ] || [ -z "$OST" ] || [ "$os_s962_files" != 'CHANGELOG.md VERSION ' ] || [ "$os_s963_np" != 3 ]; then
  os_shape=bad
else
  os_shape=ok
  case "$os_s962_parmsg" in *PC-S962*) os_shape=bad ;; esac
  case "
$os_s963_files
" in *"
VERSION
"*) : ;; *) os_shape=bad ;; esac
fi
if [ "$os_shape" != ok ]; then
  lr_badf '%-22s FIXTURE BROKEN -- the release shapes are wrong (S962 branch release, S963 merge release)\n' "off-subject-seed"
  return 0
fi
lr_okf '%-22s the world carries a branch-shaped release (S962) and a merge that changes VERSION (S963)\n' "off-subject-seed"
cat > "$OSW/ledger.md" <<'OSLED'
# Push-candidate ledger

- **PC-S960-THIRD-CLASS** — a core commit names it and changes none of its receipt path.
  verify: theirs_lacks core/scripts/os-third.sh "MARKER_OS"

- **PC-S961-SQUASH-RELEASE** — one release commit changes the subject and VERSION.
  verify: theirs_lacks core/scripts/os-sq.sh "MARKER_OS"

- **PC-S962-BRANCH-RELEASE** — the fix is in an unnamed parent, the naming release changes only CHANGELOG.md and VERSION.
  verify: theirs_lacks core/scripts/os-br.sh "MARKER_OS"

- **PC-S963-MERGE-RELEASE** — the fix arrives on a merge's second parent and the merge changes VERSION.
  verify: theirs_lacks core/scripts/os-mg.sh "MARKER_OS"

- **PC-S964-OVER-EXPANSION** — a non-release naming commit after an unnamed commit that touched the subject.
  verify: theirs_lacks core/scripts/os-ox.sh "MARKER_OS"

- **PC-S965-TWO-PATHS-SECOND-TOUCHED** — two receipt paths, only the second touched.
  verify: theirs_lacks core/scripts/os-two-a.sh "MARKER_OS"
  verify: theirs_lacks core/scripts/os-two-b.sh "MARKER_OS"

- **PC-S966-CONSUMER-PATH-TOUCHED** — a consumer-layout receipt path whose dist file is touched.
  verify: theirs_lacks scripts/ai-dlc/os-cl.sh "MARKER_OS"

- **PC-S967-CONSUMER-PATH-UNTOUCHED** — a consumer-layout receipt path whose dist file is untouched.
  verify: theirs_lacks scripts/ai-dlc/os-cl2.sh "MARKER_OS"

- **PC-S968-AMBIGUOUS-BASENAME** — one path resolves to two files, the other resolves and is untouched.
  verify: theirs_lacks scripts/ai-dlc/os-amb.sh "MARKER_OS"
  verify: theirs_lacks core/scripts/os-amb-other.sh "MARKER_OS"

- **PC-S969-LISTING-FAILURE** — untouched subject; the subject listing is forced to fail under a shim.
  verify: theirs_lacks core/scripts/os-lf.sh "MARKER_OS"

- **PC-S970-MANUAL-RECEIPT** — no path receipt at all.
  verify: manual
OSLED
os_rows() { lr_eng "$1" "$OSD" "$OSB" "$CONS" "$OST" "$OSW/ledger.md" 2>/dev/null; }
os_kind() { printf '%s\n' "$1" | awk -F'\t' -v l="$2" '$2 == l && $1 ~ /^NAMED-UPSTREAM(-DOCS-ONLY|-CITED-ONLY|-OFF-SUBJECT)?$/ {print $1; exit}'; }
OS_IDS="PC-S960-THIRD-CLASS PC-S961-SQUASH-RELEASE PC-S962-BRANCH-RELEASE PC-S963-MERGE-RELEASE PC-S964-OVER-EXPANSION PC-S965-TWO-PATHS-SECOND-TOUCHED PC-S966-CONSUMER-PATH-TOUCHED PC-S967-CONSUMER-PATH-UNTOUCHED PC-S968-AMBIGUOUS-BASENAME PC-S969-LISTING-FAILURE PC-S970-MANUAL-RECEIPT"
OS_WANT="NAMED-UPSTREAM-OFF-SUBJECT NAMED-UPSTREAM NAMED-UPSTREAM NAMED-UPSTREAM NAMED-UPSTREAM-OFF-SUBJECT NAMED-UPSTREAM NAMED-UPSTREAM NAMED-UPSTREAM-OFF-SUBJECT NAMED-UPSTREAM NAMED-UPSTREAM-OFF-SUBJECT NAMED-UPSTREAM"
os_expect() { # <id> -> the kind the engine must give it
  local _i _k _w="$OS_WANT"
  for _i in $OS_IDS; do _k="${_w%% *}"; _w="${_w#* }"; [ "$_i" = "$1" ] && { printf '%s' "$_k"; return; }; done
}
os_read() { local _i _s=""; for _i in $OS_IDS; do _s="$_s $_i=$(os_kind "$1" "$_i")"; done; printf '%s' "${_s# }"; }
# THE CONTROL IS PRESENCE-SHAPED: every one of the eleven ids must carry a NAMED- row of exactly
# the expected kind, so an engine that emits nothing fails it rather than matching an absence.
os_ctl="$(os_rows "$CLOSER")"
os_ctl_read="$(os_read "$os_ctl")"
os_ctl_want=""; for _i in $OS_IDS; do os_ctl_want="$os_ctl_want $_i=$(os_expect "$_i")"; done; os_ctl_want="${os_ctl_want# }"
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$os_ctl_read" != "$os_ctl_want" ]; then
  lr_badf '%-22s the shipped engine over the S960-S970 world read {%s}, want {%s}\n' "off-subject-control" "$os_ctl_read" "$os_ctl_want"
  return 0
else
  printf -v _m '%-22s the shipped engine reproduces every S960-S970 kind: third class, over-expansion, untouched consumer path and listing cell OFF-SUBJECT; squash, branch and merge releases, second-path, touched consumer path, ambiguous basename and manual NAMED-UPSTREAM' "off-subject-control"; ok "$_m"
fi
# THE ROW TEXT NAMES THE SUBJECT, and a basename-resolved one by BOTH spellings.
os_det() { printf '%s\n' "$os_ctl" | awk -F'\t' -v l="$1" '$1 == "NAMED-UPSTREAM-OFF-SUBJECT" && $2 == l {print $3; exit}'; }
ASSERTIONS=$((ASSERTIONS + 1))
case "$(os_det PC-S967-CONSUMER-PATH-UNTOUCHED)" in
  *"scripts/ai-dlc/os-cl2.sh resolved by basename to core/scripts/os-cl2.sh"*)
    lr_okf '%-22s S967 names the receipt'"'"'s consumer-layout spelling AND the dist path it resolved to\n' "off-subject-basename" ;;
  *) lr_badf '%-22s S967 does not name both scripts/ai-dlc/os-cl2.sh and core/scripts/os-cl2.sh: %s\n' "off-subject-basename" "$(os_det PC-S967-CONSUMER-PATH-UNTOUCHED | cut -c1-200)" ;;
esac
ASSERTIONS=$((ASSERTIONS + 1))
case "$(os_det PC-S960-THIRD-CLASS)" in
  *"resolved by basename"*) lr_badf '%-22s S960 says its path was basename-resolved, but it is present at theirs as written\n' "off-subject-path" ;;
  *"core/scripts/os-third.sh"*) lr_okf '%-22s S960 names its receipt path as written and claims no basename resolution\n' "off-subject-path" ;;
  *) lr_badf '%-22s S960 does not name core/scripts/os-third.sh: %s\n' "off-subject-path" "$(os_det PC-S960-THIRD-CLASS | cut -c1-200)" ;;
esac
# THE LISTING FAILURE CELL: a git shim refuses ONLY the per-commit subject listing (`--no-walk`
# with `-m` and without `--stdin`; `named_reach` passes `--stdin`, so reach stays `code`) and leaves
# a sentinel. No sentinel is BROKEN, never a verdict.
OS_SHIM="$OSW/shim"; mkdir -p "$OS_SHIM"
printf '#!/bin/bash\nnw=0; m=0; st=0\nfor a in "$@"; do case "$a" in --no-walk) nw=1 ;; -m) m=1 ;; --stdin) st=1 ;; esac; done\nif [ "$nw" = 1 ] && [ "$m" = 1 ] && [ "$st" = 0 ]; then : > "%s/fired"; exit 128; fi\nexec "%s" "$@"\n' \
  "$OS_SHIM" "$(command -v git)" > "$OS_SHIM/git"
chmod +x "$OS_SHIM/git"
os_lf() { # <engine> -> S969's kind with the subject listing failing, or BROKEN
  local _r; rm -f "$OS_SHIM/fired"
  _r="$(PATH="$OS_SHIM:$PATH" os_rows "$1")"
  [ -f "$OS_SHIM/fired" ] || { printf 'BROKEN'; return; }
  os_kind "$_r" PC-S969-LISTING-FAILURE
}
ASSERTIONS=$((ASSERTIONS + 1))
os_lfk="$(os_lf "$CLOSER")"
if [ "$os_lfk" = NAMED-UPSTREAM ]; then
  printf -v _m '%-22s with the subject listing failing, S969 keeps the old kind NAMED-UPSTREAM -- a git error is never an OFF-SUBJECT row' "off-subject-listfail"; ok "$_m"
else
  lr_badf '%-22s with the subject listing failing S969 read %s, want NAMED-UPSTREAM (BROKEN = the shim never fired)\n' "off-subject-listfail" "${os_lfk:-<no row>}"
fi

# --- SIBLING ATTRIBUTION (cells S1001-S1030, S1099) ---------------------------------------------
# A naming commit that changes the entry's receipt file X only where a SIBLING entry Y it names IN
# FULL has its anchor -- on every changed block, X's own anchor on no changed line -- reads
# NAMED-UPSTREAM-SIBLING-ATTRIBUTED. Its own world and its own ledger, beside an archive at the
# derived path. Y entries are seeded only to be named.
#
# Y IS DRAWN FROM THE OPEN LIVE ENTRIES ONLY. A closed sibling (still in the live ledger, or rotated
# to the archive) is no sibling: a row that depended on it would change at the rotate, or when the
# archive is deleted, and a reader's rows must be the same with all sprint history deleted. So
# S1001 and S1007 -- the same shape as S1041 but with a closed or archived Y -- read the plain kind.
#
#   S1041  offender: Y (OPEN, live) anchor changed in X's file, X's not     -> SIBLING
#   S1001  Y (closed, live) anchor changed in X's file, X's not             -> NAMED-UPSTREAM
#   S1003  Y's receipt and change are on a DIFFERENT file                     -> NAMED-UPSTREAM
#   S1005  in-commit control: X's anchor changed too                          -> NAMED-UPSTREAM
#   S1007  Y present ONLY in the archive, closed                              -> NAMED-UPSTREAM
#   S1009  release span: an unnamed neighbour changes X's file, no anchor    -> NAMED-UPSTREAM
#   S1011  X's anchor changed in an unnamed span parent, Y's in the release  -> NAMED-UPSTREAM
#   S1013  Y named only by its short id                                       -> NAMED-UPSTREAM
#   S1015  Y's anchor-on-X's-file written into a DIFFERENT file Q             -> NAMED-UPSTREAM
#   S1017  two naming commits; the older changes X's anchor                  -> NAMED-UPSTREAM
#   S1019  merge: Y's change visible only against the SECOND parent          -> SIBLING
#   S1021  merge, parents swapped: Y's change against the first parent      -> SIBLING
#   S1023  merge: Y's change against one parent, X's file changed elsewhere
#          against the other                                                 -> NAMED-UPSTREAM
#   S1025  Y's slug occurs only as a prefix of a longer named slug           -> NAMED-UPSTREAM
#   S1027  Y's anchor opens with `|` and carries `.` and `*`                  -> SIBLING
#   S1029  X's anchor carries a backslash                                     -> NAMED-UPSTREAM
#   S1031  X has receipts on TWO files; the commit changes Y's anchor on the
#          first and X's OWN anchor on the second                          -> NAMED-UPSTREAM
#   S1033  X has ONE receipt with two quoted substrings; the commit changes
#          Y's anchor and X's SECOND substring                              -> NAMED-UPSTREAM
#   S1035  Y's anchor is a substring of its own path; the commit edits only a
#          filler line, so the anchor occurs only in the diff headers       -> NAMED-UPSTREAM
#   S1037  Y's slug occurs only continued by `_`, a longer id               -> NAMED-UPSTREAM
#   S1039  Y's slug occurs only continued by `.3-`, a longer id             -> NAMED-UPSTREAM
#   S1099  never named (control): must have a row and no NAMED- row
#
# SHIPS AHEAD OF ITS SUBJECT, keyed on the status only the fixed engine emits.
if ! grep -qF 'NAMED-UPSTREAM-SIBLING-ATTRIBUTED' "$CLOSER" && [ "$B2_ISDIST" = 0 ]; then
  LR_SKIPPED=1
  printf '  SKIP  sibling-attribution arms -- the installed ledger-reverify.sh predates them; they land with the pull that carries this fixture\n'
  return 0
fi
SBW="$OSW/sib"; mkdir -p "$SBW/dist"
SBD="$SBW/dist"
ASSERTIONS=$((ASSERTIONS + 1))
sb_rc=0
( set -e
  g() { git -C "$SBD" -c user.email=seed@fixture -c user.name=seed -c commit.gpgsign=false "$@"; }
  c() { g add -A; g commit -q -m "$1"; }
  sw() { # <file> <old line> <new line>: replace one whole line
    F="$SBD/core/scripts/$1" O="$2" N="$3" awk 'BEGIN{f=ENVIRON["F"]} $0 == ENVIRON["O"] { print ENVIRON["N"]; n++; next } { print } END { exit n == 1 ? 0 : 3 }' "$SBD/core/scripts/$1" > "$SBW/sw.tmp"
    mv "$SBW/sw.tmp" "$SBD/core/scripts/$1"
  }
  g init -q
  mkdir -p "$SBD/core/scripts"
  printf '0.1.0\n' > "$SBD/VERSION"
  for t in A C D E F G I J K N O T U V; do
    printf '#!/bin/sh\nFILLER_TOP\nf1\nf2\nf3\nf4\nANCHX_%s_\nANCHY_%s_\n' "$t" "$t" > "$SBD/core/scripts/sb-$t.sh"
  done
  printf '#!/bin/sh\nFILLER_TOP\nANCHX_B_\n' > "$SBD/core/scripts/sb-B.sh"
  printf '#!/bin/sh\nANCHY_B_\n' > "$SBD/core/scripts/sb-B2.sh"
  printf '#!/bin/sh\nFILLER_TOP\nANCHX_H_\nANCHY_H_P_\n' > "$SBD/core/scripts/sb-H.sh"
  printf '#!/bin/sh\nANCHY_H_Q_\n' > "$SBD/core/scripts/sb-H2.sh"
  printf '#!/bin/sh\nFILLER_TOP\nf1\nf2\nf3\nf4\nANCHX_L_\nANCHY_L_\n' > "$SBD/core/scripts/sb-L.sh"
  printf '#!/bin/sh\nFILLER_TOP\nf1\nf2\nf3\nf4\nANCHX_M_\n|SIB.LIT*x\n' > "$SBD/core/scripts/sb-M.sh"
  printf '#!/bin/sh\nFILLER_TOP\nf1\nf2\nf3\nf4\nANCHX_P_\nANCHY_P_\n' > "$SBD/core/scripts/sb-P.sh"
  printf '#!/bin/sh\necho never\n' > "$SBD/core/scripts/sb-never.sh"
  printf '#!/bin/sh\nFILLER_TOP\nf1\nf2\nf3\nf4\nANCHX_Q1_\nANCHY_Q_\n' > "$SBD/core/scripts/sb-Q1.sh"
  printf '#!/bin/sh\nFILLER_TOP\nf1\nf2\nf3\nf4\nANCHX_Q2_\n' > "$SBD/core/scripts/sb-Q2.sh"
  printf '#!/bin/sh\nFILLER_TOP\nf1\nf2\nANCH_A4\nf3\nf4\nANCH_B4\nf5\nf6\nANCHY_R_\n' > "$SBD/core/scripts/sb-R.sh"
  printf '#!/bin/sh\nFILLER_TOP\nf1\nf2\nf3\nf4\nANCHX_S_\n' > "$SBD/core/scripts/yfile.sh"
  c 'root: every subject exists, VERSION 0.1.0'
  sw sb-A.sh ANCHY_A_ fixedA; c 'fix: absorb PC-S1002-SIB-CLOSED-LIVE; cross-references PC-S1001-OFFENDER'
  sw sb-B.sh FILLER_TOP 'filler B'; sw sb-B2.sh ANCHY_B_ fixedB; c 'fix: absorb PC-S1004-SIB-OTHER-FILE; cites PC-S1003-DIFFERENT-FILE'
  sw sb-C.sh ANCHX_C_ fixedXC; sw sb-C.sh ANCHY_C_ fixedYC; c 'fix: absorb PC-S1006-INCOMMIT-Y and PC-S1005-INCOMMIT-X'
  sw sb-D.sh ANCHY_D_ fixedD; c 'fix: absorb PC-S1008-SIB-ARCHIVED; cites PC-S1007-ARCHIVE-ONLY'
  printf '0.2.0\n' > "$SBD/VERSION"; c '0.2.0 -- a release naming no entry'
  sw sb-E.sh FILLER_TOP 'filler E'; c 'refactor: an unnamed neighbour'
  sw sb-E.sh ANCHY_E_ fixedE; printf '0.3.0\n' > "$SBD/VERSION"; c '0.3.0 -- absorbs PC-S1010-SPAN-Y; cites PC-S1009-SPAN-NEIGHBOUR'
  sw sb-F.sh ANCHX_F_ fixedXF; c 'refactor: unnamed, and it moves an anchor'
  sw sb-F.sh ANCHY_F_ fixedYF; printf '0.4.0\n' > "$SBD/VERSION"; c '0.4.0 -- absorbs PC-S1012-SPANOFF-Y; cites PC-S1011-SPANOFF-X'
  sw sb-G.sh ANCHY_G_ fixedG; c 'fix: absorb PC-S1014 (short id only); cites PC-S1013-SHORT-ID-X'
  sw sb-H.sh FILLER_TOP 'filler H'; printf 'ANCHY_H_P_ copied here\n' >> "$SBD/core/scripts/sb-H2.sh"; c 'fix: absorb PC-S1016-WHOLE-DIFF-Y; cites PC-S1015-WHOLE-DIFF-X'
  sw sb-I.sh ANCHX_I_ fixedXI; c 'fix: part one for PC-S1017-TWO-COMMITS-X'
  sw sb-I.sh ANCHY_I_ fixedYI; c 'fix: absorb PC-S1018-TWO-COMMITS-Y; cites PC-S1017-TWO-COMMITS-X'
  m="$(g symbolic-ref --short HEAD)"
  # S1019: the change is on the MAIN line, so the merge shows it only against its second parent.
  g checkout -q -b sb-side1; printf 'side\n' > "$SBD/side1.txt"; c 'side work, names no entry'
  g checkout -q "$m"; sw sb-J.sh ANCHY_J_ fixedJ; c 'main: unnamed, changes an anchor'
  g merge -q --no-ff -m 'merge: absorbs PC-S1020-MERGE-P2-Y; cites PC-S1019-MERGE-P2-X' sb-side1
  # S1021: parents swapped -- the change arrives on the side branch.
  g checkout -q -b sb-side2; sw sb-K.sh ANCHY_K_ fixedK; c 'side: unnamed, changes an anchor'
  g checkout -q "$m"; printf 'main\n' > "$SBD/main2.txt"; c 'main work, names no entry'
  g merge -q --no-ff -m 'merge: absorbs PC-S1022-MERGE-P1-Y; cites PC-S1021-MERGE-P1-X' sb-side2
  # S1023: each parent sees a different change to X's file.
  g checkout -q -b sb-side3; sw sb-L.sh FILLER_TOP 'filler L'; c 'side: unnamed, changes filler'
  g checkout -q "$m"; sw sb-L.sh ANCHY_L_ fixedL; c 'main: unnamed, changes an anchor'
  g merge -q --no-ff -m 'merge: absorbs PC-S1024-MERGE-CONCAT-Y; cites PC-S1023-MERGE-CONCAT-X' sb-side3
  g branch -q -D sb-side1 sb-side2 sb-side3
  sw sb-N.sh ANCHY_N_ fixedN; c 'fix: absorb PC-S1026-PRE-LONGER; cites PC-S1025-PREFIX-X'
  sw sb-M.sh '|SIB.LIT*x' fixedM; c 'fix: absorb PC-S1028-PIPE-Y; cites PC-S1027-PIPE-X'
  sw sb-O.sh ANCHY_O_ fixedO; c 'fix: absorb PC-S1030-BACKSLASH-Y; cites PC-S1029-BACKSLASH-X'
  sw sb-Q1.sh ANCHY_Q_ fixedQ; sw sb-Q2.sh ANCHX_Q2_ fixedXQ2; c 'fix: absorb PC-S1032-TWO-PATH-Y; cites PC-S1031-TWO-PATH-X'
  sw sb-R.sh ANCHY_R_ fixedR; sw sb-R.sh ANCH_B4 fixedB4; c 'fix: absorb PC-S1034-MULTI-SUB-Y; cites PC-S1033-MULTI-SUB-X'
  sw yfile.sh FILLER_TOP 'filler S'; c 'fix: absorb PC-S1036-HEADER-Y; cites PC-S1035-HEADER-X'
  # S1037/S1039: the sibling's slug is followed only by an id byte of the SHARED class (`_`, or a
  # `.` that continues the id), so the commit names a longer id and not the sibling.
  sw sb-T.sh ANCHY_T_ fixedT; c 'fix: absorb PC-S1038-CONT_LONGER; cites PC-S1037-ID-CONT-X'
  sw sb-U.sh ANCHY_U_ fixedU; c 'fix: absorb PC-S1040-DOT.3-LONGER; cites PC-S1039-DOT-CONT-X'
  # S1041: S1001's shape with an OPEN sibling. After the last release, so no release span holds it.
  sw sb-V.sh ANCHY_V_ fixedV; c 'fix: absorb PC-S1042-SIB-OPEN-LIVE; cross-references PC-S1041-OFFENDER-OPEN'
) >/dev/null 2>&1 || sb_rc=$?
if [ "$sb_rc" -ne 0 ]; then
  lr_badf '%-22s FIXTURE BROKEN -- the sibling world could not be built\n' "sibling-seed"
  return 0
fi
SBB="$(git -C "$SBD" rev-list --max-parents=0 HEAD 2>/dev/null)"
SBT="$(git -C "$SBD" rev-parse HEAD 2>/dev/null)"
# THE MERGE SHAPES, ASSERTED AGAINST THE REPO: S1019 shows sb-J.sh against its second parent only,
# S1021 against its first only, S1023 against both.
sb_par() { # <id> <parent ordinal> -> 1 when the naming merge has a diff for <file> against it
  local _m _p
  _m="$(git -C "$SBD" log -F --grep="$1" --format=%H "$SBT")"
  _p="$(git -C "$SBD" rev-parse "${_m}^$2" 2>/dev/null)" || { printf 'x'; return; }
  if git -C "$SBD" diff --quiet "$_p" "$_m" -- "core/scripts/$3" 2>/dev/null; then printf 0; else printf 1; fi
}
sb_shape="$(sb_par PC-S1019-MERGE-P2-X 1 sb-J.sh)$(sb_par PC-S1019-MERGE-P2-X 2 sb-J.sh)$(sb_par PC-S1021-MERGE-P1-X 1 sb-K.sh)$(sb_par PC-S1021-MERGE-P1-X 2 sb-K.sh)$(sb_par PC-S1023-MERGE-CONCAT-X 1 sb-L.sh)$(sb_par PC-S1023-MERGE-CONCAT-X 2 sb-L.sh)"
if [ -z "$SBB" ] || [ -z "$SBT" ] || [ "$sb_shape" != 011011 ]; then
  lr_badf '%-22s FIXTURE BROKEN -- the merge shapes are wrong (got %s, want 011011)\n' "sibling-seed" "$sb_shape"
  return 0
fi
lr_okf '%-22s the world carries a merge seen against its second parent only (S1019), one against its first only (S1021) and one against both (S1023)\n' "sibling-seed"
cat > "$SBW/ledger.md" <<'SBLED'
# Push-candidate ledger

- **PC-S1001-OFFENDER** — a sibling's release changes my file only where the sibling's anchor is.
  verify: theirs_has core/scripts/sb-A.sh "ANCHX_A_"

- **PC-S1002-SIB-CLOSED-LIVE** — the sibling, closed in the live ledger.
  verify: theirs_lacks core/scripts/sb-A.sh "ANCHY_A_"
**ADOPTED UPSTREAM (v0.1.0, verified 2026-01-01)**

- **PC-S1003-DIFFERENT-FILE** — the sibling's receipt is on another file.
  verify: theirs_has core/scripts/sb-B.sh "ANCHX_B_"

- **PC-S1004-SIB-OTHER-FILE** — sibling on sb-B2.sh.
  verify: theirs_lacks core/scripts/sb-B2.sh "ANCHY_B_"

- **PC-S1005-INCOMMIT-X** — my anchor changed in the same commit.
  verify: theirs_lacks core/scripts/sb-C.sh "ANCHX_C_"

- **PC-S1006-INCOMMIT-Y** — sibling.
  verify: theirs_lacks core/scripts/sb-C.sh "ANCHY_C_"

- **PC-S1007-ARCHIVE-ONLY** — my sibling is only in the archive.
  verify: theirs_has core/scripts/sb-D.sh "ANCHX_D_"

- **PC-S1009-SPAN-NEIGHBOUR** — an unnamed neighbour in the release span touches my file.
  verify: theirs_has core/scripts/sb-E.sh "ANCHX_E_"

- **PC-S1010-SPAN-Y** — sibling.
  verify: theirs_lacks core/scripts/sb-E.sh "ANCHY_E_"

- **PC-S1011-SPANOFF-X** — my anchor moved in an unnamed span parent.
  verify: theirs_lacks core/scripts/sb-F.sh "ANCHX_F_"

- **PC-S1012-SPANOFF-Y** — sibling.
  verify: theirs_lacks core/scripts/sb-F.sh "ANCHY_F_"

- **PC-S1013-SHORT-ID-X** — my sibling is named only by its short id.
  verify: theirs_has core/scripts/sb-G.sh "ANCHX_G_"

- **PC-S1014-SHORT-ONLY-Y** — sibling.
  verify: theirs_lacks core/scripts/sb-G.sh "ANCHY_G_"

- **PC-S1015-WHOLE-DIFF-X** — my sibling's anchor text appears in a different file.
  verify: theirs_has core/scripts/sb-H.sh "ANCHX_H_"

- **PC-S1016-WHOLE-DIFF-Y** — sibling with receipts on two files.
  verify: theirs_has core/scripts/sb-H.sh "ANCHY_H_P_"
  verify: theirs_has core/scripts/sb-H2.sh "ANCHY_H_Q_"

- **PC-S1017-TWO-COMMITS-X** — two naming commits; the older changed my anchor.
  verify: theirs_lacks core/scripts/sb-I.sh "ANCHX_I_"

- **PC-S1018-TWO-COMMITS-Y** — sibling.
  verify: theirs_lacks core/scripts/sb-I.sh "ANCHY_I_"

- **PC-S1019-MERGE-P2-X** — merge, the change against the second parent.
  verify: theirs_has core/scripts/sb-J.sh "ANCHX_J_"

- **PC-S1020-MERGE-P2-Y** — sibling.
  verify: theirs_lacks core/scripts/sb-J.sh "ANCHY_J_"

- **PC-S1021-MERGE-P1-X** — merge, the change against the first parent.
  verify: theirs_has core/scripts/sb-K.sh "ANCHX_K_"

- **PC-S1022-MERGE-P1-Y** — sibling.
  verify: theirs_lacks core/scripts/sb-K.sh "ANCHY_K_"

- **PC-S1023-MERGE-CONCAT-X** — merge, a different change against each parent.
  verify: theirs_has core/scripts/sb-L.sh "ANCHX_L_"

- **PC-S1024-MERGE-CONCAT-Y** — sibling.
  verify: theirs_lacks core/scripts/sb-L.sh "ANCHY_L_"

- **PC-S1025-PREFIX-X** — my sibling's slug occurs only inside a longer one.
  verify: theirs_has core/scripts/sb-N.sh "ANCHX_N_"

- **PC-S1026-PRE** — sibling, whose slug prefixes the named PC-S1026-PRE-LONGER.
  verify: theirs_lacks core/scripts/sb-N.sh "ANCHY_N_"

- **PC-S1027-PIPE-X** — my sibling's anchor is regex-hostile.
  verify: theirs_has core/scripts/sb-M.sh "ANCHX_M_"

- **PC-S1028-PIPE-Y** — sibling.
  verify: theirs_lacks core/scripts/sb-M.sh "|SIB.LIT*x"

- **PC-S1029-BACKSLASH-X** — my anchor carries a backslash.
  verify: theirs_has core/scripts/sb-O.sh "ANCHX\_O_"

- **PC-S1030-BACKSLASH-Y** — sibling.
  verify: theirs_lacks core/scripts/sb-O.sh "ANCHY_O_"

- **PC-S1031-TWO-PATH-X** — receipts on two files; my anchor on the second changed.
  verify: theirs_has core/scripts/sb-Q1.sh "ANCHX_Q1_"
  verify: theirs_lacks core/scripts/sb-Q2.sh "ANCHX_Q2_"

- **PC-S1032-TWO-PATH-Y** — sibling on the first file.
  verify: theirs_lacks core/scripts/sb-Q1.sh "ANCHY_Q_"

- **PC-S1033-MULTI-SUB-X** — one receipt, two substrings; the second changed.
  verify: theirs_has core/scripts/sb-R.sh "ANCH_A4" "ANCH_B4"

- **PC-S1034-MULTI-SUB-Y** — sibling.
  verify: theirs_lacks core/scripts/sb-R.sh "ANCHY_R_"

- **PC-S1035-HEADER-X** — the commit edits only a filler line of my file.
  verify: theirs_has core/scripts/yfile.sh "ANCHX_S_"

- **PC-S1036-HEADER-Y** — sibling whose anchor occurs only in the path.
  verify: theirs_has core/scripts/yfile.sh "yfile.sh"

- **PC-S1037-ID-CONT-X** — my sibling's slug occurs only continued by an underscore.
  verify: theirs_has core/scripts/sb-T.sh "ANCHX_T_"

- **PC-S1038-CONT** — sibling, whose slug is continued by `_` in the naming commit.
  verify: theirs_lacks core/scripts/sb-T.sh "ANCHY_T_"

- **PC-S1039-DOT-CONT-X** — my sibling's slug occurs only continued by an id-continuing dot.
  verify: theirs_has core/scripts/sb-U.sh "ANCHX_U_"

- **PC-S1040-DOT** — sibling, whose slug is continued by `.3-` in the naming commit.
  verify: theirs_lacks core/scripts/sb-U.sh "ANCHY_U_"

- **PC-S1041-OFFENDER-OPEN** — an OPEN sibling's release changes my file only where its anchor is.
  verify: theirs_has core/scripts/sb-V.sh "ANCHX_V_"

- **PC-S1042-SIB-OPEN-LIVE** — the sibling, open in the live ledger.
  verify: theirs_lacks core/scripts/sb-V.sh "ANCHY_V_"

- **PC-S1099-NEVER** — never named (control).
  verify: theirs_has core/scripts/sb-never.sh "never"
SBLED
cat > "$SBW/push-candidate-ledger.archive.md" <<'SBARC'
# Push-candidate ledger archive

## PC-S1008-SIB-ARCHIVED — **ADOPTED UPSTREAM (v0.1.0, verified 2026-01-01)** — the archived sibling.

verify: theirs_lacks core/scripts/sb-D.sh "ANCHY_D_"
SBARC
sb_rows() { lr_eng "$1" "$SBD" "$SBB" "$CONS" "$SBT" "$SBW/ledger.md" 2>/dev/null; }
sb_kind() { printf '%s\n' "$1" | awk -F'\t' -v l="$2" '$2 == l && $1 ~ /^NAMED-UPSTREAM(-DOCS-ONLY|-CITED-ONLY|-OFF-SUBJECT|-SIBLING-ATTRIBUTED)?$/ {print $1; exit}'; }
SB_IDS="PC-S1001-OFFENDER PC-S1003-DIFFERENT-FILE PC-S1005-INCOMMIT-X PC-S1007-ARCHIVE-ONLY PC-S1009-SPAN-NEIGHBOUR PC-S1011-SPANOFF-X PC-S1013-SHORT-ID-X PC-S1015-WHOLE-DIFF-X PC-S1017-TWO-COMMITS-X PC-S1019-MERGE-P2-X PC-S1021-MERGE-P1-X PC-S1023-MERGE-CONCAT-X PC-S1025-PREFIX-X PC-S1027-PIPE-X PC-S1029-BACKSLASH-X PC-S1031-TWO-PATH-X PC-S1033-MULTI-SUB-X PC-S1035-HEADER-X PC-S1037-ID-CONT-X PC-S1039-DOT-CONT-X PC-S1041-OFFENDER-OPEN"
SA=NAMED-UPSTREAM-SIBLING-ATTRIBUTED; NU=NAMED-UPSTREAM
SB_WANT="$NU $NU $NU $NU $NU $NU $NU $NU $NU $SA $SA $NU $NU $SA $NU $NU $NU $NU $NU $NU $SA"
sb_expect() { local _i _k _w="$SB_WANT"; for _i in $SB_IDS; do _k="${_w%% *}"; _w="${_w#* }"; [ "$_i" = "$1" ] && { printf '%s' "$_k"; return; }; done; }
sb_read() { local _i _s=""; for _i in $SB_IDS; do _s="$_s $_i=$(sb_kind "$1" "$_i")"; done; printf '%s' "${_s# }"; }
# THE CONTROL IS PRESENCE-SHAPED: every X cell must carry a NAMED- row of exactly its kind, the
# in-commit sibling S1006 must read NAMED-UPSTREAM (its own anchor changed), and the never-named
# control must have a row and no NAMED- row.
sb_ctl="$(sb_rows "$CLOSER")"
sb_ctl_read="$(sb_read "$sb_ctl")"
sb_ctl_want=""; for _i in $SB_IDS; do sb_ctl_want="$sb_ctl_want $_i=$(sb_expect "$_i")"; done; sb_ctl_want="${sb_ctl_want# }"
sb_never_rows="$(printf '%s\n' "$sb_ctl" | awk -F'\t' '$2 == "PC-S1099-NEVER" {c++} END {print c+0}')"
sb_never_named="$(printf '%s\n' "$sb_ctl" | awk -F'\t' '$2 == "PC-S1099-NEVER" && $1 ~ /^NAMED-/ {c++} END {print c+0}')"
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$sb_ctl_read" != "$sb_ctl_want" ] || [ "$(sb_kind "$sb_ctl" PC-S1006-INCOMMIT-Y)" != "$NU" ] || [ "$sb_never_rows" -lt 1 ] || [ "$sb_never_named" != 0 ]; then
  lr_badf '%-22s the shipped engine over S1001-S1041 read {%s} S1006=%s never=%s/%s, want {%s} S1006=%s never>=1/0\n' "sibling-control" "$sb_ctl_read" "$(sb_kind "$sb_ctl" PC-S1006-INCOMMIT-Y)" "$sb_never_rows" "$sb_never_named" "$sb_ctl_want" "$NU"
  return 0
else
  printf -v _m '%-22s the shipped engine reproduces every S1001-S1041 kind; closed and archived siblings attribute nothing, the in-commit sibling stays NAMED-UPSTREAM and the never-named control has a row and no NAMED- row' "sibling-control"; ok "$_m"
fi
# THE ROW NAMES ONLY THE SIBLING WHOSE ANCHOR SAT ON THE CHANGED LINE.
ASSERTIONS=$((ASSERTIONS + 1))
sb_det="$(printf '%s\n' "$sb_ctl" | awk -F'\t' '$1 == "NAMED-UPSTREAM-SIBLING-ATTRIBUTED" && $2 == "PC-S1041-OFFENDER-OPEN" {print $3; exit}')"
case "$sb_det" in
  *"receipt substring there: PC-S1042-SIB-OPEN-LIVE ("*"core/scripts/sb-V.sh"*|*"core/scripts/sb-V.sh"*"receipt substring there: PC-S1042-SIB-OPEN-LIVE ("*)
    lr_okf '%-22s S1041 names its receipt file and exactly the sibling whose anchor changed\n' "sibling-detail" ;;
  *) lr_badf '%-22s S1041 does not name sb-V.sh and exactly PC-S1042-SIB-OPEN-LIVE: %s\n' "sibling-detail" "$(printf '%s' "$sb_det" | cut -c1-240)" ;;
esac
# THE CLOSE RULE STAYS SINGLE-HOMED: the shipped lib.sh lifts exactly one body rule and one entry-line
# rule from this ledger-reverify.sh -- the lift the previous release's lib.sh performs on the pull
# that delivers this file (lib.sh is unchanged by this arm, so the shipped copy IS that one).
ASSERTIONS=$((ASSERTIONS + 1))
SB_BOOT="$SBW/boot"; mkdir -p "$SB_BOOT"; cp "$(dirname "$CLOSER")/lib.sh" "$(dirname "$CLOSER")/ledger-reverify.sh" "$SB_BOOT/" 2>/dev/null
sb_lift="$( SELF="$SB_BOOT"; . "$SB_BOOT/lib.sh" >/dev/null 2>&1; ledger_close_awk_pattern >/dev/null 2>&1 && ledger_entry_line_close_awk >/dev/null 2>&1 && echo ok )"
sb_n1="$(grep -cE '^[[:space:]]*/.*ADOPTED UPSTREAM.*closed=1 \}$' "$CLOSER")" || sb_n1=0
if [ "$sb_lift" = ok ] && [ "$sb_n1" = 1 ]; then
  lr_okf '%-22s lib.sh lifts exactly one close rule and one entry-line rule (body-rule matches: %s)\n' "sibling-close-lift" "$sb_n1"
else
  lr_badf '%-22s lift=%s body-rule matches=%s, want ok and 1 -- the close rule must stay single-homed on one line\n' "sibling-close-lift" "${sb_lift:-refused}" "$sb_n1"
fi
} # end lr_unit_off_subject
lr_unit_unreadable_path() {
# --- AN UNREADABLE PATH IS REFUSED, NEVER READ AS ABSENT OR EMPTY (BL-310) -----------------
# `memo_has_path` returns 125 when git said no and the path could not be confirmed absent; every
# read site used to fold that into "absent" (a basename guess, or "does not resolve") and every
# `memo_show` read discarded its status, so an unread blob read as EMPTY content. Five worlds, each
# a tiny dist with ONE object moved aside, each the subject of one layer:
#   W-blob    theirs blob of the entry's path missing             -> unreadable (has or show layer)
#   W-tree    theirs SUBTREE missing: ls-tree -r fails too         -> unreadable (has layer alone)
#   W-cached  `has` cached healthy, theirs blob then missing,
#             base readable and holding the anchor                 -> unreadable (show layer alone;
#             without it, theirs_has reads a CLOSE on an unread blob)
#   W-base    base blob missing, anchor at both refs               -> unreadable (base layer; without
#             it, a vacuous theirs_lacks reads CLOSE-CANDIDATE)
#   W-ver     VERSION blob missing at a resolvable theirs          -> the run refuses, exit 2
# Near-miss controls in the same worlds: a path new at theirs (confirmed ABSENT at base) and a path
# that resolves nowhere both decide as before.
#
# SHIPS AHEAD OF ITS SUBJECT: a consumer's installed engine may predate the refusal, and there the
# arms SKIP. Decided on the RESOLVED engine directory, never on a path glob.
if ! grep -qF '"unreadable: path' "$CLOSER" && [ "$B2_ISDIST" = 0 ]; then
  printf '  SKIP  BL-310 unreadable arms -- the installed ledger-reverify.sh predates the refusal; it lands with the pull that carries this fixture\n'
else
  UW="$(dirname "$DIST")/unreadable"; mkdir -p "$UW"
  # u_world <name> -> builds <UW>/<name>/{d,c}: base commit B, theirs commit T, each with
  # top.txt, a/b/f.txt, keep.txt and VERSION; theirs also adds new.txt. Prints nothing.
  u_world() {
    local w="$UW/$1"
    mkdir -p "$w/d/a/b" "$w/c" "$w/m"
    ug() { git -C "$w/d" -c user.name=u -c user.email=u@u -c commit.gpgsign=false "$@"; }
    git init -q "$w/d"
    printf 'MARK base\n' > "$w/d/top.txt"; printf 'MARK\n' > "$w/d/a/b/f.txt"
    printf 'KEEP base\n' > "$w/d/keep.txt"; printf '1.0.0\n' > "$w/d/VERSION"
    ug add -A; ug commit -qm base
    printf 'MARK theirs\n' > "$w/d/top.txt"; printf 'KEEP theirs\n' > "$w/d/keep.txt"
    printf 'NEWMARK\n' > "$w/d/new.txt"; printf '1.1.0\n' > "$w/d/VERSION"
    ug add -A; ug commit -qm theirs
    printf '%s' "$(ug rev-parse HEAD~1)" > "$w/B"; printf '%s' "$(ug rev-parse HEAD)" > "$w/T"
    printf -- '# ledger\n\n- **Entry U-HAS** -- has.\n  verify: theirs_has top.txt "MARK"\n\n- **Entry U-TREE** -- subtree.\n  verify: theirs_has a/b/f.txt "MARK"\n\n- **Entry U-KEEP** -- vacuous lacks.\n  verify: theirs_lacks keep.txt "KEEP"\n\n- **Entry U-NEW** -- new at theirs.\n  verify: theirs_has new.txt "NEWMARK"\n\n- **Entry U-NOWHERE** -- resolves nowhere.\n  verify: theirs_has no/such/zz-file.txt "X"\n' > "$w/c/ledger.md"
  }
  u_obj() { # <world> <ref-file B|T> <path> -> absolute object path
    local w="$UW/$1" s
    s="$(git -C "$w/d" rev-parse "$(cat "$w/$2"):$3")" || return 1
    printf '%s/d/.git/objects/%s/%s' "$w" "${s%"${s#??}"}" "${s#??}"
  }
  u_run() { # <engine> <world> -> "rc<TAB>rows"; a fresh memo per run unless U_MEMO is set
    local w="$UW/$2" m="${U_MEMO:-}" o rc
    [ -n "$m" ] || m="$(mktemp -d "$w/m/r.XXXX")"
    o="$(AI_DLC_RECONCILE_MEMO="$m" lr_eng "$1" "$w/d" "$(cat "$w/B")" "$w/c" "$(cat "$w/T")" "$w/c/ledger.md" 2>"$w/err")"; rc=$?
    printf '%s\n%s' "$rc" "$o"
  }
  u_row() { printf '%s\n' "$1" | awk -F'\t' -v l="$2" 'NR > 1 && $2 == l {print $1 "|" $3; exit}'; }
  u_unread() { case "$(u_row "$1" "$2")" in NEEDS-REVIEW\|unreadable:*) return 0 ;; esac; return 1; }
  # BUILD ONCE, COPY PER WORLD: the six worlds are byte-identical until each loses its own object
  # below, so one repo is built and copied whole (its B and T files with it). Each copy is its own
  # .git, so deleting an object in one cannot reach another.
  u_world healthy
  for _w in blob tree cached base ver; do cp -R "$UW/healthy" "$UW/$_w"; rm -rf "$UW/$_w/m"; mkdir -p "$UW/$_w/m"; done
  # Healthy control on an untouched world: every entry decides as before, nothing reads unreadable.
  U_H="$(u_run "$CLOSER" healthy)"
  ASSERTIONS=$((ASSERTIONS + 1))
  case "$(u_row "$U_H" "Entry U-HAS")|$(u_row "$U_H" "Entry U-KEEP")|$(u_row "$U_H" "Entry U-NEW")|$(u_row "$U_H" "Entry U-NOWHERE")" in
    STILL-LIVE*"|NEEDS-REVIEW|vacuous predicate:"*"|STILL-LIVE"*"|NEEDS-REVIEW|unresolved:"*)
      if grep -q 'unreadable' <<<"$U_H"; then lr_badf '%-22s the HEALTHY world reads unreadable somewhere — the refusal fires on readable objects\n' "unreadable-control"
      else lr_okf '%-22s healthy world: has STILL-LIVE, keep vacuous, new-at-theirs STILL-LIVE, nowhere unresolved, no unreadable row\n' "unreadable-control"; fi ;;
    *) lr_badf '%-22s FIXTURE BROKEN — the healthy world does not decide as seeded: %s\n' "unreadable-control" "$(printf '%s\n' "$U_H" | cut -f1,2 | tr '\n' ' ')" ;;
  esac
  # Break each world, ONCE, and keep it broken.
  mv "$(u_obj blob T top.txt)" "$UW/blob/moved" \
    && mv "$(u_obj tree T a/b)" "$UW/tree/moved" \
    && { U_MEMO="$UW/cached/m/primed"; mkdir -p "$U_MEMO"
         AI_DLC_RECONCILE_MEMO="$U_MEMO" bash -c '. "$1/lib.sh" >/dev/null 2>&1 && memo_has_path "$2" "$3" top.txt' _ \
           "$(dirname "$CLOSER")" "$UW/cached/d" "$(cat "$UW/cached/T")"; } \
    && mv "$(u_obj cached T top.txt)" "$UW/cached/moved" \
    && mv "$(u_obj base B keep.txt)" "$UW/base/moved" \
    && mv "$(u_obj ver T VERSION)" "$UW/ver/moved" \
    || { lr_badf '%-22s FIXTURE BROKEN — an object could not be moved aside, so no unreadable world exists\n' "unreadable-worlds"; }
  # u_score <engine> -> "blob tree cached base ver" verdict letters: R = refused as unreadable
  u_score() {
    local b t c k v
    b="$(u_run "$1" blob)";  u_unread "$b" "Entry U-HAS"  && b=R || b="$(u_row "$b" "Entry U-HAS" | cut -d'|' -f1)"
    t="$(u_run "$1" tree)";  u_unread "$t" "Entry U-TREE" && t=R || t="$(u_row "$t" "Entry U-TREE" | cut -d'|' -f1)"
    c="$(U_MEMO="$UW/cached/m/primed" u_run "$1" cached)"; u_unread "$c" "Entry U-HAS" && c=R || c="$(u_row "$c" "Entry U-HAS" | cut -d'|' -f1)"
    k="$(u_run "$1" base)";  u_unread "$k" "Entry U-KEEP" && k=R || k="$(u_row "$k" "Entry U-KEEP" | cut -d'|' -f1)"
    v="$(u_run "$1" ver)";   if [ "${v%%
*}" = 2 ] && grep -q 'VERSION at theirs' "$UW/ver/err"; then v=R; else v="rc${v%%
*}"; fi
    printf '%s %s %s %s %s' "${b:-none}" "${t:-none}" "${c:-none}" "${k:-none}" "${v:-none}"
  }
  U_S="$(u_score "$CLOSER")"
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ "$U_S" = "R R R R R" ]; then
    printf -v _m '%-22s missing blob, missing subtree, unread blob behind a cached has, unread base blob, unread VERSION: all refused (%s)' "unreadable-refused" "$U_S"; ok "$_m"
  else
    lr_badf '%-22s want R R R R R (blob tree cached base ver), got %s\n' "unreadable-refused" "$U_S"
  fi
  # Near-miss in a BROKEN world: the new-at-theirs path and the path that resolves nowhere still
  # decide as in the healthy world, so the refusal is keyed on unreadability, not on any failure.
  _bw="$(u_run "$CLOSER" base)"
  ASSERTIONS=$((ASSERTIONS + 1))
  case "$(u_row "$_bw" "Entry U-NEW")|$(u_row "$_bw" "Entry U-NOWHERE")" in
    STILL-LIVE*"|NEEDS-REVIEW|unresolved:"*) lr_okf '%-22s beside an unreadable base blob, a path new at theirs and a path that resolves nowhere decide as before\n' "unreadable-near-miss" ;;
    *) lr_badf '%-22s the near-misses moved in the broken world: %s\n' "unreadable-near-miss" "$(u_row "$_bw" "Entry U-NEW") / $(u_row "$_bw" "Entry U-NOWHERE")" ;;
  esac
fi

} # end lr_unit_unreadable_path
lr_unit_named_commits() {
# --- EVERY NAMING COMMIT IS LISTED, AND NO END IS ELECTED --------------------------------
# THE DEFECT. The row reported the NEWEST and the OLDEST commit whose message names the id and
# nothing between them, so for n > 2 the middle commits were never shown — and the two ends are
# the WORST pair to elect. The oldest mention of an id is the commit that FILED it, or a plan;
# the newest is the withdrawal or the docs commit written after the fix landed. Measured over the
# reference consumer's 65 live ledger ids against this distribution's history: 21 have at least
# one naming commit, 12 have more than one, and in 5 of those 12 NEITHER advertised end is a
# `fix`/`feat` commit. Control in the same run: an impossible id returns 0 commits.
#
# THE EXPECTED SET IS DERIVED FROM THE REPO, NEVER READ OFF THE ROW. A count taken from a
# rendering is not a derived count, and an arm that parses the row it is testing agrees with
# itself whatever the row says. `named_set` asks git the question the subject asks and
# abbreviates each sha the way the subject does, so what follows compares two independently
# computed sets.
named_set() { # <id> -> newline-separated SHORT shas, newest first
  local _h
  for _h in $(git -C "$DIST" log -F --grep="$1" --format=%H "$THEIRS" 2>/dev/null); do
    git -C "$DIST" rev-parse --short "$_h" 2>/dev/null
  done
}
# BOTH NAMING KINDS CARRY THE SHA LIST, so both are read.
named_detail() { # <rows> <id> -> field 3 of that id's NAMED-UPSTREAM(-DOCS-ONLY) row, or empty
  printf '%s\n' "$1" | awk -F'\t' -v l="^$2\$" '($1=="NAMED-UPSTREAM" || $1=="NAMED-UPSTREAM-DOCS-ONLY" || $1=="NAMED-UPSTREAM-OFF-SUBJECT") && $2 ~ l {print $3; exit}'
}
# <rows> <id> -> how many of that id's naming shas are ABSENT from its row, or NOROW.
# NOROW is distinguished from 0 deliberately: a row that never appeared hides nothing and reports
# nothing, and scoring it as "no shas missing" is how a subject emitting silence sweeps an
# absence-shaped arm clean.
named_missing() {
  local _detail _s _miss=0
  _detail="$(named_detail "$1" "$2")"
  [ -n "$_detail" ] || { printf 'NOROW'; return 0; }
  for _s in $(named_set "$2"); do
    case "$_detail" in *"$_s"*) : ;; *) _miss=$((_miss + 1)) ;; esac
  done
  printf '%s' "$_miss"
}

# PRECONDITION — THE MOTIVATING SHAPE, ASSERTED AGAINST THE REPO AND NOT AGAINST ANY ROW.
# Three commits must name PC-S904, the MIDDLE one must be the commit that touched a subject, and
# NEITHER end may have. Without that shape the arm below still prints ok while testing nothing:
# at n <= 2 there is no middle commit to hide and the two-ends form and the whole-set form are the
# same string, so a seed that drifts to n = 2 would silently retire the case it exists for.
#
# THIS IS THE ONE ARM HERE THAT READS NO OUTPUT OF THE SUBJECT, which is why it is labelled a
# precondition: it would print ok against a subject replaced by `exit 0`. What stops that from
# mattering is that every other arm in this block is PRESENCE-shaped — each requires a specific
# row and a specific sha to appear — so silence fails them by construction.
s904_id=PC-S904-ABSORBED-IN-THE-MIDDLE-COMMIT
s905_id=PC-S905-ONE-NAMING-COMMIT-ONLY
s906_id=PC-S906-TWO-NAMING-COMMITS-NOTHING-HIDDEN
s904_shas="$(named_set "$s904_id")"
s904_n="$(printf '%s\n' "$s904_shas" | grep -c . )"
s904_new="$(printf '%s\n' "$s904_shas" | sed -n '1p')"
s904_mid="$(printf '%s\n' "$s904_shas" | sed -n '2p')"
s904_old="$(printf '%s\n' "$s904_shas" | sed -n '3p')"
s906_shas="$(named_set "$s906_id")"
# NO PIPE INTO `grep -q`. `git show --name-only` is fed into a command substitution and matched
# with `case`, per this repo's standing rule about a reader that leaves before the writer has
# finished; the output is small here, and the point is that the shape is correct anywhere.
s904_touched() { case "$(git -C "$DIST" show --format= --name-only "$1" 2>/dev/null)" in
    *core/scripts/s904-subject.sh*) return 0 ;; *) return 1 ;; esac; }
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$s904_n" -ne 3 ]; then
  lr_badf '%-22s %s commit(s) name %s, want 3 — below three there is no middle commit, and the two forms are the same string\n' "named-seed-shape" "$s904_n" "$s904_id"
elif s904_touched "$s904_new" || s904_touched "$s904_old"; then
  lr_badf '%-22s an END of the range is the absorbing commit, so electing the two ends would have been RIGHT here and the arm below tests nothing\n' "named-seed-shape"
elif ! s904_touched "$s904_mid"; then
  lr_badf '%-22s the MIDDLE commit %s did not touch core/scripts/s904-subject.sh, so no commit in this range absorbed the entry\n' "named-seed-shape" "${s904_mid:-<none>}"
else
  lr_okf '%-22s 3 commits name PC-S904; the MIDDLE one (%s) absorbed it and NEITHER end (%s newest, %s oldest) did\n' "named-seed-shape" "$s904_mid" "$s904_new" "$s904_old"
fi

# THE ARM. Every sha that names an id must appear in that id's row. The offender and BOTH
# near-misses are read out of the SAME `$OUT`: PC-S904 at n=3 with one commit the two ends cannot
# reach, PC-S906 at n=2 where the two ends ARE the whole set, and PC-S905 at n=1. The three carry
# byte-identical receipts and emit two rows each, so the run is the same size whichever is being
# read — an implementation that branches on `n > 1` and never reads a sha treats PC-S904 and
# PC-S906 identically and cannot pass this.
ASSERTIONS=$((ASSERTIONS + 1))
m904="$(named_missing "$OUT" "$s904_id")"
m905="$(named_missing "$OUT" "$s905_id")"
m906="$(named_missing "$OUT" "$s906_id")"
if [ "$m904" = NOROW ] || [ "$m905" = NOROW ] || [ "$m906" = NOROW ]; then
  lr_badf '%-22s a NAMED-UPSTREAM row is MISSING (904=%s 905=%s 906=%s) — a row that never appeared hides nothing and reports nothing, so this arm cannot discriminate\n' "named-lists-all" "$m904" "$m905" "$m906"
elif [ "$m904" -eq 0 ] && [ "$m905" -eq 0 ] && [ "$m906" -eq 0 ]; then
  printf -v _m '%-22s every naming sha is on its row — 3 for PC-S904 (the middle one included), 2 for PC-S906, 1 for PC-S905' "named-lists-all"; ok "$_m"
else
  lr_badf '%-22s naming shas ABSENT from their rows: PC-S904 %s of 3, PC-S906 %s of 2, PC-S905 %s of 1. A commit the row does not name is a commit the operator never reads\n' "named-lists-all" "$m904" "$m906" "$m905"
  printf '%s\n' "$OUT" | awk -F'\t' '$1=="NAMED-UPSTREAM"{print $2"  "substr($3,1,120)}' | sed 's/^/          | /'
fi

# AND THE STATED COUNT MUST AGREE WITH THE LIST. A row saying "in 3 commits" while carrying two
# shas sends the operator looking for a commit the row does not name, which is the same injury in
# the other direction. Both spellings the row uses are accepted — the assertion is that the two
# NUMBERS agree, not that either is phrased a particular way — and a row that states no count at
# all fails, because "is this list complete" is then unanswerable from the row.
ASSERTIONS=$((ASSERTIONS + 1))
stated_count() { # <rows> <id> -> integer, or empty when the row states no count
  local _d
  _d="$(named_detail "$1" "$2")"
  case "$_d" in
    *"in one commit"*) printf '1' ;;
    *) printf '%s' "$_d" | sed -n 's/.*NAMES this entry.s id in \([0-9][0-9]*\) commits.*/\1/p' ;;
  esac
}
c904="$(stated_count "$OUT" "$s904_id")"
c905="$(stated_count "$OUT" "$s905_id")"
c906="$(stated_count "$OUT" "$s906_id")"
if [ -z "$c904" ] || [ -z "$c905" ] || [ -z "$c906" ]; then
  lr_badf '%-22s a row states no commit count at all (904=[%s] 905=[%s] 906=[%s]) — without one the operator cannot tell a complete list from a truncated one\n' "named-count-agrees" "$c904" "$c905" "$c906"
elif [ "$c904" = "3" ] && [ "$c906" = "2" ] && [ "$c905" = "1" ]; then
  lr_okf '%-22s the stated counts are 3 / 2 / 1 and each matches the number of shas the row carries\n' "named-count-agrees"
else
  lr_badf '%-22s stated counts 904=%s 906=%s 905=%s against derived 3 / 2 / 1 — the row is telling the operator to read a different number of commits than it names\n' "named-count-agrees" "$c904" "$c906" "$c905"
fi

} # end lr_unit_named_commits
lr_unit_entry_swallowed() {
# --- ENTRY-SWALLOWED: a bold-bullet annotation that became its own entry -----------------
# THE DEFECT. A line-leading `- **…**` annotation inside an entry opens a NEW entry, so it
# truncates the one it annotates and captures its receipt. The real entry then emits no row
# under its own id — a silent disappearance that reads exactly like an entry with nothing to
# report. The reference consumer hit it while annotating an entry; two runs read clean.
row_has "The derivation:" ENTRY-SWALLOWED \
  "an annotation lead-in that opened its own entry is REPORTED, not silently obeyed"

# It must name WHICH entry went dark, or the operator has a complaint and no subject.
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $3 ~ /PC-FIXTURE-SWALLOWED-BY-ANNOTATION/{f=1} END{exit !f}'; then
  lr_okf '%-22s names the entry it truncated, and that it captured the receipt\n' "swallowed-names-entry"
else
  lr_badf '%-22s reported a swallow without naming the entry that went silent\n' "swallowed-names-entry"
fi

# THE CONTROL SET, and both must be able to fail. Without them the assertion above is satisfied
# by a detector that flags every entry, or every entry carrying a colon anywhere.
row_lacks "PC-FIXTURE-COLON-CONTROL" ENTRY-SWALLOWED \
  "a normal entry in the same section stays silent"
row_lacks "a-real-entry.sh" ENTRY-SWALLOWED \
  "a PROSE-titled entry legitimately carrying a receipt stays silent — the measured 6-of-7 false-positive class"


} # end lr_unit_entry_swallowed
lr_unit_idl_relabel() {
# --- THE BACKTICKED-ID LINE RELABELS AN ENTRY UNDER AN ID-LESS HEADING ----------------------
# A column-0 `` `PC-…` `` span ending in an em dash is a RELABEL, not a boundary: an entry whose
# heading carries no id takes that id. Three passes read the label (the receipt parse, the
# ENTRY-SWALLOWED pass, the mid-line pass), one seed each, read off the baseline run.
row_is "PC-FXIDL-RELABEL-LR" HAND-REVIEW \
  "the receipt parse keys the entry on the backticked id below its id-less heading"
row_is "Idl prose heading LR" ABSENT \
  "and emits no row under the prose heading"
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $2 ~ /Idl annotation lead-in SW/ && index($3, "nearest id-shaped entry above: PC-FXIDL-RELABEL-SW)") > 0 {f=1} END{exit !f}'; then
  lr_okf '%-22s the annotation that captured the receipt names the relabelled entry it swallowed\n' "idl-swallowed-names-id"
else
  lr_badf '%-22s no ENTRY-SWALLOWED row for the annotation names PC-FXIDL-RELABEL-SW\n' "idl-swallowed-names-id"
  printf '%s\n' "$OUT" | awk -F'\t' '$1=="ENTRY-SWALLOWED"' | sed 's/^/          | /'
fi
row_has "PC-FXIDL-RELABEL-ML" NEEDS-REVIEW \
  "the mid-line pass keys its row on the backticked id"
row_is "Idl prose heading ML" ABSENT \
  "and emits no row under the prose heading"
# THE NEAR-MISSES. An id line under its own closed heading is no boundary, so the entry stays one
# closed unit; an id line with no em dash is no relabel, so the prose heading keeps the entry.
row_is "PC-FXIDL-SAME-ID" ABSENT \
  "a closed heading entry followed by its own id line is one closed entry, not split into an open one"
row_is "Idl prose heading NODASH" NEEDS-REVIEW \
  "a backticked id with no em dash relabels nothing: the manual receipt stays under the prose label"
row_is "PC-FXIDL-NO-DASH" ABSENT \
  "and no row is keyed on that id"
} # end lr_unit_idl_relabel
lr_unit_no_colon_swallow() {
# --- BL-013: THE NO-COLON SWALLOW, WHICH THE COLON SIGNAL CANNOT SEE ----------------------
# The colon gate fires ZERO times on every corpus available — the reference consumer's live
# ledger and archive, and both distribution backlog files — while those same corpora carry
# annotation bullets that really are swallowing entries. An annotation whose bold span does
# NOT end in a colon truncates the entry above it exactly as a colon one does, captures its
# receipt, and produced no row anywhere until the second signal existed.

ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $2 ~ /False CLOSE-CANDIDATE/ && $3 ~ /PC-FIXTURE-NO-COLON-SWALLOWED/{f=1} END{exit !f}'; then
  lr_okf '%-22s names the entry that went dark, so the operator has a subject and not just a complaint\n' "no-colon-names-entry"
else
  lr_badf '%-22s reported the no-colon swallow without naming PC-FIXTURE-NO-COLON-SWALLOWED\n' "no-colon-names-entry"
  printf '%s\n' "$OUT" | awk -F'\t' '$1=="ENTRY-SWALLOWED"' | sed 's/^/          | /'
fi

# AND IT MUST DISCRIMINATE, or the arm above is satisfied by a detector that reports every
# non-id bullet carrying a receipt. Predicate (2) ALONE — a receipt under a non-id label —
# reports 11 rows on the reference consumer's live ledger; the conjunction reports 1. These
# three are the classes the conjunction subtracts, and each is a REAL entry.
row_lacks "legacy-entry.sh" ENTRY-SWALLOWED \
  "a real id-less entry below a CLOSED one stays silent: a closed entry emits no row BY DESIGN, so 'no row above' is true of every entry that follows a close"

# ...and that last one is a REAL entry, so it must still report its own verdict. A silence
# bought by the entry disappearing from the classifier is not the silence being asserted.
row_is "PC-FIXTURE-ID_WITH.PUNCT-AT-0.242.0" STILL-LIVE \
  "and it is classified normally — the id rule keeps it visible rather than merely unreported"

} # end lr_unit_no_colon_swallow
lr_unit_midline_receipt() {
# --- NEEDS-REVIEW / mid-line receipt: a real receipt the anchored grammar cannot spell --------
# THE DEFECT. The receipt rule is anchored at the start of the line, deliberately — unanchored it
# reads a PROSE MENTION as a receipt, and 20 of 85 lines carrying the token on the reference
# consumer are prose. But an author who reaches the end of a body sentence and appends the receipt
# to it has written a real receipt the grammar cannot see, so the entry emits NO row of any kind:
# byte-identical to an entry that declares no receipt, and the receipt is never run. The consumer
# filed exactly that shape.
#
# NINE SEEDS AND NINE ARMS, and the eight silent ones are what make the reporting one mean
# something: predicate "an entry that emits no row" is 58 entries on the reference consumer, so
# every conjunct here subtracts a class that really exists in the corpus.
row_has "Entry ORPHAN-RECEIPT-MIDLINE" NEEDS-REVIEW \
  "a receipt appended to the end of a body sentence is REPORTED, not silently dropped"
row_lacks "Entry ORPHAN-RECEIPT-MIDLINE" STILL-LIVE \
  "and the receipt was NOT run — a mid-line receipt that produced a verdict would mean the grammar had been widened"
row_lacks "Entry ORPHAN-RECEIPT-MIDLINE" CLOSE-CANDIDATE \
  "in particular it must not CLOSE, which is the direction that loses information permanently"

# The DETAIL must carry the cause token, the LINE and the VERB, or the operator has a complaint
# and no subject. The cause token is what makes the four NEEDS-REVIEW causes greppable apart.
ASSERTIONS=$((ASSERTIONS + 1))
ml_det="$(printf '%s\n' "$OUT" | awk -F'\t' '$2=="Entry ORPHAN-RECEIPT-MIDLINE" && $1=="NEEDS-REVIEW" {print $3; exit}')"
if [ -z "$ml_det" ]; then
  lr_badf '%-22s no NEEDS-REVIEW row for the subject at all — the detail arms below cannot discriminate\n' "midline-detail"
elif ! grep -q '^mid-line receipt: ' <<<"$ml_det"; then
  lr_badf '%-22s the detail does not OPEN with the cause token, so this cause cannot be told from the other three: %s\n' "midline-detail" "$(printf '%s' "$ml_det" | cut -c1-100)"
elif ! grep -qE 'line [0-9]+ of its body' <<<"$ml_det"; then
  lr_badf '%-22s the detail names no line number: %s\n' "midline-detail" "$(printf '%s' "$ml_det" | cut -c1-120)"
elif ! grep -q 'verify: theirs_has' <<<"$ml_det"; then
  lr_badf '%-22s the detail names no verb, so the operator cannot tell which receipt went unrun: %s\n' "midline-detail" "$(printf '%s' "$ml_det" | cut -c1-120)"
else
  lr_okf '%-22s the row opens with the cause token and names the line and the verb\n' "midline-detail"
fi

# AND THE LINE NUMBER IS THE OFFENDING LINE, not merely a number. Derived from the seeded ledger
# rather than hardcoded: a literal would go stale the release somebody edits the seed above it,
# and would still read as a passing assertion.
ASSERTIONS=$((ASSERTIONS + 1))
LED_ML="$CONS/_bmad-output/ai-dlc-update/push-candidate-ledger.md"
ml_want="$(awk '/^  <br>A session resuming from that snapshot reads a fully-shipped sprint as pending work\. verify: theirs_has/{print NR; exit}' "$LED_ML")"
ml_got="$(printf '%s' "$ml_det" | sed -n 's/.*line \([0-9][0-9]*\) of its body.*/\1/p')"
if [ -n "$ml_want" ] && [ "$ml_want" = "$ml_got" ]; then
  lr_okf '%-22s the reported line %s IS the offending body line in the seeded ledger\n' "midline-line" "$ml_got"
else
  lr_badf '%-22s reported line %s, offending line in the ledger is %s (empty = the seed line moved and this arm lost its subject)\n' "midline-line" "${ml_got:-<none>}" "${ml_want:-<none>}"
fi

# THE EIGHT SILENT CLASSES. Each is a REAL shape in the corpora and each would be reported by a
# predicate one conjunct short of this one.
row_lacks "Entry ONLY-IN-TICKS" NEEDS-REVIEW \
  "a mention inside an inline code span is a body QUOTING the convention — the ledger is full of those"
row_lacks "Entry ONLY-IN-TICKS" STILL-LIVE \
  "and it emits nothing at all, exactly like Entry D: the backtick strip must not turn a quotation into a receipt either"
row_lacks "Entry ROW-ANCHORED-PLUS-MENTION" NEEDS-REVIEW \
  "an entry with a REAL anchored receipt is not silent, whatever its summary line says — reporting it would say move a receipt that already ran"
row_lacks "Entry ZAPPED-CLOSED-MIDLINE" NEEDS-REVIEW \
  "closed on its ENTRY LINE — the classifier skips it by design, so a receipt it never runs costs nothing"
row_lacks "Entry WALLED-BY-BODY-ANNOTATION" NEEDS-REVIEW \
  "closed by a BODY annotation, which is a different rule with a different anchor from the one above"
row_lacks "Entry PENNED-IN-A-FENCE" NEEDS-REVIEW \
  "inside a fence it is recorded OUTPUT, not a directive — the consumer archive carries worked examples of exactly this"
row_lacks "Entry QUOTED-IN-A-BLOCKQUOTE" NEEDS-REVIEW \
  "a blockquote is a quotation of somebody else's receipt; reporting it says move a receipt that was never one"
row_lacks "Entry NOTED-IN-AN-HTML-COMMENT" NEEDS-REVIEW \
  "an HTML comment is text the rendered document does not show, so it is not a directive either"

# ONE ROW PER ENTRY, NOT PER OFFENDING LINE. The finding is that the ENTRY is silent, which is one
# fact; a row per line repeats it. Asserted as a NUMBER, and the row must name the FIRST offence —
# a last-match-wins reader gives the same row count and points at the wrong line.
ASSERTIONS=$((ASSERTIONS + 1))
ml_two_n="$(printf '%s\n' "$OUT" | awk -F'\t' '$2=="Entry TWO-MIDLINE-RECEIPTS" && $1=="NEEDS-REVIEW" && $3 ~ /^mid-line receipt/{c++} END{print c+0}')"
ml_two_v="$(printf '%s\n' "$OUT" | awk -F'\t' '$2=="Entry TWO-MIDLINE-RECEIPTS" && $1=="NEEDS-REVIEW" {print $3; exit}')"
if [ "$ml_two_n" = 1 ] && grep -q 'verify: theirs_has' <<<"$ml_two_v"; then
  lr_okf '%-22s two offending lines in one entry emit ONE row, naming the FIRST (theirs_has, not the theirs_lacks below it)\n' "midline-one-row"
else
  lr_badf '%-22s %s row(s) for the two-offence entry, naming: %s (want 1 row naming theirs_has)\n' "midline-one-row" "$ml_two_n" "$(printf '%s' "$ml_two_v" | sed -n 's/.*carries .verify: \([a-z_]*\).*/\1/p')"
fi

} # end lr_unit_midline_receipt
lr_unit_unicode_escape() {
# --- NO UNICODE ESCAPE SURVIVES INTO A DETAIL FIELD --------------------------------------
# THE DEFECT. emit() writes its three fields with a printf whose format is three %s
# conversions, and a %s conversion does NOT interpret escapes. A six-character
# backslash-u-2026 typed into a detail string therefore reaches stdout VERBATIM and is
# rendered into the region `emit-report.sh --verify` byte-compares, so the operator reads the
# escape where the author meant an ellipsis. One emit site carried exactly that, beside a real
# em-dash in the same sentence.
#
# THE SUBJECT IS THE OUTPUT, NOT THE SOURCE. A grep of ledger-reverify.sh for the escape is a
# presence anchor on text ABOUT the program: it is satisfied by a comment, and it is blind to
# an escape that arrives from the ledger or through a variable. This arm reads field 3 of what
# the shipping program actually printed.
#
# POPULATION: field 3 of EVERY emitted row, not the ENTRY-SWALLOWED rows alone. Every detail in
# this file goes through that one printf, so the defect is available to all two dozen emit sites
# equally; scoping the arm to the site that happened to carry it would leave the rest unwatched
# and read green through the next one.
#
# THE PATTERN DISCRIMINATES ON LENGTH, not on the backslash. It is backslash-u followed by
# EXACTLY four hex digits. A lone backslash, the bare token u2026, and backslash-u with three
# hex digits are all legitimate detail content — a ledger substring is echoed into field 3
# verbatim, so a receipt may legally name any of them. PC-FIXTURE-UESCAPE-NEAR-MISS in seed.sh
# carries all three in ONE substring that the real producer copies into a detail, and this arm
# requires that row to be PRESENT in the corpus it scanned: a near-miss control that is absent
# proves nothing. Since the backslash refusal shipped, that entry's row IS the refusal row —
# its anchor carries a backslash — and it still qualifies because the refusal echoes the anchor
# into the detail. A refusal that stopped quoting the anchor would silently drop this control.
#
# THE POSITIVE CONTROL is the row and ENTRY-SWALLOWED counts. This is an absence-shaped arm, so
# a subject that emits nothing sweeps it clean — the exact failure fixture-mutants.md measures.
# Zero offenders is a finding only over a corpus that has rows in it AND still carries a row
# from the emit site the defect was on.
#
# TYPING THE ESCAPE IS ITSELF A HAZARD. The backlog entry this arm discharges reports three
# attempts to put the six characters into a probe — through a heredoc, through an editor and
# inline — each arriving as a single U+2026 character with the probe then reporting "no match".
# THAT IS THE ENTRY'S MEASUREMENT AND NOT THIS ARM'S: the design here avoided the hazard from the
# first line rather than reproducing it, so nothing in this file confirms or refutes it. Recorded
# as inherited, because a comment that says "measured while this was written" about someone
# else's measurement is the provenance defect this repo keeps finding in its own prose.
# Nothing below spells the backslash: awk builds it from its character code, so no layer between
# this file and the regex engine can fold it.
#
# WHAT THIS ARM DOES NOT COVER, stated because a coverage proof cannot see outside its own
# population. It scans the rows in `$OUT` — the main corpus this fixture drives — and nothing
# else. The caller-error probes further up capture their output in separate variables, so an
# escape typed into an emit site only THEY reach (`INPUT-UNRESOLVED` is the live example) would
# not be seen here. Widening it means hand-listing that join, which is why it was not done
# quietly; the population is named instead.
#
# stdin: emitted rows. stdout: "<offenders> <rows> <swallowed> <nearmiss>"
uescape_scan() {
  awk -F'\t' '
    BEGIN { BS = sprintf("%c", 92) }
    {
      rows++
      if ($1 == "ENTRY-SWALLOWED") sw++
      s = $3; isoff = 0
      while ((p = index(s, BS "u")) > 0) {
        t = substr(s, p + 2, 4)
        if (length(t) == 4 && t ~ /^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$/) { isoff = 1; break }
        s = substr(s, p + 2)
      }
# THE NEAR-MISS COUNT EXCLUDES OFFENDERS. A row carrying a REAL escape also carries a backslash
# and the token u2026, so counting both shapes independently would let an offending row satisfy the
# near-miss precondition.
      if (isoff) off++
      else if (index($3, "u2026") > 0 && index($3, BS) > 0) nm++
    }
    END { printf "%d %d %d %d\n", off + 0, rows + 0, sw + 0, nm + 0 }
  '
}
# The offender dump, kept beside the scanner so both read field 3 by the same rule.
uescape_offenders() {
  awk -F'\t' '
    BEGIN { BS = sprintf("%c", 92) }
    {
      s = $3
      while ((p = index(s, BS "u")) > 0) {
        t = substr(s, p + 2, 4)
        if (length(t) == 4 && t ~ /^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$/) { print $1 "  " $2; break }
        s = substr(s, p + 2)
      }
    }
  '
}

ASSERTIONS=$((ASSERTIONS + 1))
read -r ue_off ue_rows ue_sw ue_nm < <(printf '%s\n' "$OUT" | uescape_scan)
if [ "$ue_rows" -eq 0 ] || [ "$ue_sw" -eq 0 ]; then
  lr_badf '%-22s scanned %s row(s), %s of them ENTRY-SWALLOWED — a zero over an empty corpus is not a finding, and this arm would have passed against a subject that printed nothing\n' "detail-no-uescape" "$ue_rows" "$ue_sw"
elif [ "$ue_nm" -eq 0 ]; then
  lr_badf '%-22s the PC-FIXTURE-UESCAPE-NEAR-MISS detail is not among the %s scanned rows, so a zero here does not establish that the pattern separates a real escape from an adjacent one\n' "detail-no-uescape" "$ue_rows"
elif [ "$ue_off" -eq 0 ]; then
  printf -v _m '%-22s no detail in %s rows (%s ENTRY-SWALLOWED) carries backslash-u-HHHH, and the near-miss row carrying a lone backslash, the token u2026 and a 3-hex backslash-u did NOT trip it' "detail-no-uescape" "$ue_rows" "$ue_sw"; ok "$_m"
else
  lr_badf '%-22s %s detail field(s) carry a literal backslash-u-HHHH escape. emit() prints a detail through a %%s conversion, which does not interpret escapes, so those six characters reach the operator and the byte-compared report verbatim. Write the character itself\n' "detail-no-uescape" "$ue_off"
  printf '%s\n' "$OUT" | uescape_offenders | sed 's/^/          | /'
fi

} # end lr_unit_unicode_escape
lr_unit_fenced_entries() {
# --- FENCED ENTRY-SHAPED LINES — PC-S308-LEDGER-REVERIFY-ENTRY-BOUNDARY-IGNORES-FENCED-HEADINGS -
# THE DEFECT. `ledger_entry_shape()` opened an entry on every heading-shaped line and tracked no
# fence state, so a `derived` block whose recorded output carried `## <ts> -- EVENT` lines split
# the entry that carried it: the receipt was reported under a timestamp label and the real id
# emitted no row. Measured on the reference consumer, and its 0.497.0 pull then ROTATED such an
# entry in pieces, leaving two orphan fragments in its live ledger.
#
# THE RULE, AND WHY THE ARMS BELOW COME IN FOUR SHAPES. lib.sh now tracks fences by the
# CommonMark opener/closer grammar and ignores a fenced entry-shaped line whose label is NOT
# id-keyed. An id-keyed one still opens an entry and RESETS the fence -- an unterminated fence
# can hide nothing that carries an id -- and the reset is reported here as ENTRY-SWALLOWED with
# the `fence` signal. The closer of a quoted heading's fence is then consumed as a stray closer
# rather than read as a new opener. Each of those four clauses has its own seed and its own arm,
# because a battery that seeds only the filed shape proves the rule accepts the filed shape and
# nothing else.
row_is "PC-FIXTURE-INLINE-SPAN-LINE" STILL-LIVE \
  "an entry whose body opens a line with an inline code span still reports"
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $2 ~ /PC-FIXTURE-QUOTED-INSIDE-FENCE/ && $3 ~ /PC-FIXTURE-QUOTING-ENTRY/ && $3 ~ /fenced code block/{f=1} END{exit !f}'; then
  lr_okf '%-22s the fence row names the entry it truncated and says the line sits inside a fence\n' "fence-names-entry"
else
  lr_badf '%-22s the fence row does not name PC-FIXTURE-QUOTING-ENTRY as the truncated entry, or does not say the line is fenced\n' "fence-names-entry"
  printf '%s\n' "$OUT" | awk -F'\t' '$1=="ENTRY-SWALLOWED"' | sed 's/^/          | /'
fi
row_lacks "PC-FIXTURE-AFTER-QUOTE" ENTRY-SWALLOWED \
  "the entry AFTER a quoted heading is NOT reported — the quotation's closing fence was consumed as a stray closer, not read as a new opener"
# THE TWO-QUOTATION FENCE, PINNED AS THE STATED COST rather than dodged by seed ordering. If
# `after-two-quotes-cost` ever FAILS because the false row disappeared while every other arm
# holds, that is an improvement: update this arm, do not restore the row.
row_has "PC-FIXTURE-AFTER-TWO-QUOTES" STILL-LIVE \
  "the entry after a two-quotation fence is never HIDDEN — its receipt reports (row_has: two rows)"
row_has "PC-FIXTURE-EOF-FENCE" STILL-LIVE \
  "an entry whose fence is still open at end of file still reports its receipt (row_has: two rows)"
row_has "PC-FIXTURE-EOF-FENCE" ENTRY-SWALLOWED \
  "and the fence left open at end of file is REPORTED by the END rule — the shape a rotation split leaves behind"
row_is "PC-FIXTURE-AFTER-QUOTE" STILL-LIVE \
  "and it is classified normally"
row_is "PC-FIXTURE-TILDE-FENCE" STILL-LIVE \
  "a ~~~ fence is a fence too: the heading-shaped line inside it did not open an entry"

} # end lr_unit_fenced_entries
lr_unit_receipt_suffix() {
# --- THE RECEIPT SUFFIX DOES NOT OUTLIVE THE RECEIPT LOOP --------------------------------------
# THE DEFECT. `RSFX` holds the ` [receipt n/n]` suffix, is set per receipt INSIDE the receipt
# loop, and is read by `emit()` on every call in the file. So every row emitted BELOW that loop
# wears whatever the final iteration left behind: the run-scoped RECEIPTS-UNDECIDED row, which
# belongs to no entry at all, and every ENTRY-SWALLOWED row, which belongs to an annotation. The
# operator is handed an attribution naming a receipt that did not produce the row, on the two
# statuses whose whole job is to say "this is not a receipt verdict".
#
# WHY IT WAS INVISIBLE UNTIL THE SEED MOVED. A single-receipt entry sets `RSFX` to the EMPTY
# string, so a ledger ending on one leaks nothing and every arm below reads clean. The seed's
# last entry now carries two receipts for exactly this reason.
#
# THREE SHAPES, AND EACH ONE EXISTS BECAUSE A WRONG FIX SURVIVED THE OTHERS. Nine candidate
# implementations were built and scored before these arms were written; the three that a single
# shape cannot separate are named beside the shape that catches them.
#
#   A  the seeded ledger, whose `theirs_has` receipts leave the undecided bucket non-empty.
#      Catches the reset deleted, the reset moved to the TOP of the loop body (measured RED:
#      the value still survives the loop's last iteration), a reset placed only beside the
#      unterminated-fence emit, and a comment-only non-fix.
#   B  the same ledger with every `theirs_has` receipt stripped, so no RECEIPTS-UNDECIDED row is
#      emitted at all. This is the shape that refuses a reset sited INSIDE the
#      `if [ "$th_undecided" -gt 0 ]` block: on shape A that placement runs and reads clean,
#      and here it never executes while seven ENTRY-SWALLOWED rows still carry the suffix.
#   C  PC-FIXTURE-NAMED-MANUAL, a multi-receipt entry that also emits NAMED-UPSTREAM. This is
#      the shape that refuses a reset sited inside `emit()` itself, which clears the leak on
#      both ledgers above and pays for it by stripping the ordinal off a LEGITIMATE row — that
#      entry's first HAND-REVIEW loses `[receipt 1/2]` while NAMED-UPSTREAM keeps it.
#
# EVERY ARM IS PRESENCE-SHAPED IN BOTH DIRECTIONS. An arm that only asserts the post-loop rows
# carry NO suffix passes identically against a tool that stopped emitting suffixes ANYWHERE,
# including the receipt accumulation the `receipt-ordinal` arm above guards. So each shape
# carries a control that a suffix-less tool cannot satisfy, and each control is asserted BEFORE
# the absence it qualifies.

# SHAPE A — the seeded ledger, undecided bucket non-empty.
ASSERTIONS=$((ASSERTIONS + 1))
sfxA_post="$(printf '%s\n' "$OUT" | awk -F'\t' '$1=="ENTRY-SWALLOWED" || $1=="RECEIPTS-UNDECIDED" {c++} END{print c+0}')"
sfxA_leak="$(printf '%s\n' "$OUT" | awk -F'\t' '($1=="ENTRY-SWALLOWED" || $1=="RECEIPTS-UNDECIDED") && $3 ~ /\[receipt [0-9]+\/[0-9]+\]$/ {c++} END{print c+0}')"
sfxA_ctl="$(printf '%s\n' "$OUT" | awk -F'\t' '$1!="ENTRY-SWALLOWED" && $1!="RECEIPTS-UNDECIDED" && $3 ~ /\[receipt [0-9]+\/[0-9]+\]$/ {c++} END{print c+0}')"
if [ "$sfxA_post" -eq 0 ]; then
  lr_badf '%-22s no ENTRY-SWALLOWED or RECEIPTS-UNDECIDED row was emitted at all, so this arm has no population\n' "suffix-shape-a"
elif [ "$sfxA_ctl" -eq 0 ]; then
  lr_badf '%-22s no row OUTSIDE the post-loop statuses carries an ordinal — suffixes are not being emitted at all, so a clean post-loop reading proves nothing\n' "suffix-shape-a"
elif [ "$sfxA_leak" -eq 0 ]; then
  lr_okf '%-22s all %s post-loop rows carry no receipt suffix, while %s receipt-scoped rows still carry theirs\n' "suffix-shape-a" "$sfxA_post" "$sfxA_ctl"
else
  lr_badf '%-22s %s of %s post-loop rows wear the last entry ordinal — a run-scoped or annotation row attributed to a receipt that did not produce it\n' "suffix-shape-a" "$sfxA_leak" "$sfxA_post"
  printf '%s\n' "$OUT" | awk -F'\t' '($1=="ENTRY-SWALLOWED" || $1=="RECEIPTS-UNDECIDED") && $3 ~ /\[receipt [0-9]+\/[0-9]+\]$/ {print $1"\t"$2}' | sed 's/^/          | /'
fi

# SHAPE B — the same ledger with every receipt that can FEED the undecided bucket removed, so the
# bucket is EMPTY and its row is never emitted. The control is that emptiness itself: a run that
# still produced a RECEIPTS-UNDECIDED row never reached the state this shape exists to test, and
# its clean reading would be shape A's answer a second time.
#
# `sh` IS STRIPPED ALONGSIDE `theirs_has`, AND THE FIRST WORD OF THAT SENTENCE IS THE REASON. The
# bucket used to be fed by one verb, so naming that verb and naming its FEEDERS were the same
# string. They are not any more: an `sh` receipt now carries a base control of its own, so a corpus
# stripped of `theirs_has` alone still emits the row and this shape silently stops reaching the
# empty state it exists to test — which is the arm's own FAIL text, and it is what fired. The
# predicate here is "no receipt that can populate the bucket", never a list of verbs; when a third
# verb gains a base control this line moves with it.
#
# SHAPE B READS `$SFX_LB`, the stripped twin of the sub-ledger `$SFX_LA`. Shapes A and C read `$OUT`,
# which costs nothing; this run needs only the four subjects the three shapes key on, so it is cut
# to them (lr_subledger, seeded order kept):
#   Entry TH-UNDECIDED          feeds the undecided bucket, so shape A emits RECEIPTS-UNDECIDED
#   PC-FIXTURE-NAMED-MANUAL     shape C's multi-receipt entry, and A's ordinal-bearing control rows
#   the colon annotation        an ENTRY-SWALLOWED row from the annotation emit (with its host entry)
#   PC-FIXTURE-EOF-FENCE        LAST, with two receipts: the leak's source, and the END-rule emit
# `$SFX_LB` is `$SFX_LA` through the same feeder strip, so shape B's empty-bucket state is reached on
# the same population.
SFX_LA="$(lr_subledger suffix-a 'Entry TH-UNDECIDED' 'PC-FIXTURE-NAMED-MANUAL' 'PC-FIXTURE-SWALLOWED-BY-ANNOTATION' 'The derivation:' 'PC-FIXTURE-EOF-FENCE')"
SFX_LB=""
if [ -n "$SFX_LA" ]; then
  SFX_LB="$(dirname "$SFX_LA")/sub-suffix-b.md"
  grep -vE 'verify: (theirs_has|sh)' "$SFX_LA" > "$SFX_LB"
fi
nou_out=""
[ -n "$SFX_LB" ] && nou_out="$(lr_eng "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$SFX_LB" 2>/dev/null)"
nou_und="$(printf '%s\n' "$nou_out" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{c++} END{print c+0}')"
nou_sw="$(printf '%s\n' "$nou_out" | awk -F'\t' '$1=="ENTRY-SWALLOWED"{c++} END{print c+0}')"
nou_leak="$(printf '%s\n' "$nou_out" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $3 ~ /\[receipt [0-9]+\/[0-9]+\]$/ {c++} END{print c+0}')"
nou_ctl="$(printf '%s\n' "$nou_out" | awk -F'\t' '$1!="ENTRY-SWALLOWED" && $3 ~ /\[receipt [0-9]+\/[0-9]+\]$/ {c++} END{print c+0}')"
ASSERTIONS=$((ASSERTIONS + 1))
if [ -z "$SFX_LB" ]; then
  lr_badf '%-22s the suffix sub-ledger cut was refused, so this shape have no corpus\n' "suffix-shape-b"
elif [ "$nou_und" -ne 0 ]; then
  lr_badf '%-22s the stripped ledger still emitted %s RECEIPTS-UNDECIDED row(s), so this shape never reached the empty-bucket state it exists to test\n' "suffix-shape-b" "$nou_und"
elif [ "$nou_sw" -eq 0 ]; then
  lr_badf '%-22s the stripped ledger produced no ENTRY-SWALLOWED row, so this arm has no population\n' "suffix-shape-b"
elif [ "$nou_ctl" -eq 0 ]; then
  lr_badf '%-22s no receipt-scoped row on the stripped ledger carries an ordinal — suffixes are absent entirely, so the absence below proves nothing\n' "suffix-shape-b"
elif [ "$nou_leak" -eq 0 ]; then
  lr_okf '%-22s with the undecided bucket EMPTY, all %s ENTRY-SWALLOWED rows are still suffix-free (a reset sited inside that block never runs here)\n' "suffix-shape-b" "$nou_sw"
else
  lr_badf '%-22s %s of %s ENTRY-SWALLOWED rows wear an ordinal when no RECEIPTS-UNDECIDED row is emitted — the reset is sited inside a block this ledger never enters\n' "suffix-shape-b" "$nou_leak" "$nou_sw"
fi

# SHAPE C — a multi-receipt entry whose rows are NOT all receipt verdicts. PC-FIXTURE-NAMED-MANUAL
# emits NAMED-UPSTREAM plus one HAND-REVIEW per receipt, and EVERY one of those rows is attributable
# to the receipt whose iteration produced it. A reset inside emit() satisfies both shapes above and
# breaks exactly this: the first row consumes the suffix and the second reads empty.
ASSERTIONS=$((ASSERTIONS + 1))
nm_tot="$(printf '%s\n' "$OUT" | awk -F'\t' '$2 ~ /PC-FIXTURE-NAMED-MANUAL/{c++} END{print c+0}')"
nm_sfx="$(printf '%s\n' "$OUT" | awk -F'\t' '$2 ~ /PC-FIXTURE-NAMED-MANUAL/ && $3 ~ /\[receipt [0-9]+\/[0-9]+\]$/{c++} END{print c+0}')"
if [ "$nm_tot" -lt 3 ]; then
  lr_badf '%-22s PC-FIXTURE-NAMED-MANUAL emitted %s row(s), want at least 3 (one NAMED-UPSTREAM and one HAND-REVIEW per receipt) — the seed lost this arm subject\n' "suffix-shape-c" "$nm_tot"
elif [ "$nm_sfx" -eq "$nm_tot" ]; then
  lr_okf '%-22s every one of PC-FIXTURE-NAMED-MANUAL %s rows carries its own receipt ordinal, NAMED-UPSTREAM included\n' "suffix-shape-c" "$nm_tot"
else
  lr_badf '%-22s only %s of PC-FIXTURE-NAMED-MANUAL %s rows carry an ordinal — a legitimate row lost its attribution, which is a reset consuming the suffix rather than scoping it\n' "suffix-shape-c" "$nm_sfx" "$nm_tot"
  printf '%s\n' "$OUT" | grep -F 'PC-FIXTURE-NAMED-MANUAL' | sed 's/^/          | /'
fi

} # end lr_unit_receipt_suffix
lr_unit_backslash_anchor() {
# --- A BACKSLASH IN THE ANCHOR — PC-S308-LEDGER-REVERIFY-READS-ESCAPED-BACKTICKS-LITERALLY -----
# THE DEFECT. The substring grammar is literal and has no escape mechanism, and nothing said so:
# a receipt whose backticks were markdown-escaped was searched for WITH its backslashes, found at
# neither ref, and reported "vacuous predicate" on an entry upstream had just fixed. The reference
# consumer's own archive carries the SAME spelling meaning the opposite -- a shell printf whose
# backslashes were the defect text -- so the reader refuses any backslash and says why, rather
# than unescaping. Four seeds, one per shape, and the near-miss is the same text with its
# backticks bare, which must CLOSE: that is both the control that backticks are not what is
# refused and the proof the seed's refs discriminate on this text.
#
# THE DETAIL IS ASSERTED, NOT ONLY THE STATUS. The old behaviour was ALSO a NEEDS-REVIEW row, so
# a status-only arm cannot tell the fix from the defect; what separates them is whether the row
# names the backslash or calls the predicate vacuous.
row_is "PC-FIXTURE-ESCAPED-BACKTICK" NEEDS-REVIEW \
  "a markdown-escaped backtick in the anchor is refused, not searched for"
detail_has "PC-FIXTURE-ESCAPED-BACKTICK" "contains a backslash" \
  "the row names the backslash as the reason"
detail_lacks "PC-FIXTURE-ESCAPED-BACKTICK" "vacuous predicate" \
  "the filed defect's wrong reason is gone — the predicate was never vacuous, its spelling was"
row_is "PC-FIXTURE-BARE-BACKTICK" CLOSE-CANDIDATE \
  "the same text with bare backticks closes: backticks are fine, and base/theirs discriminate on this line"
# THE THREE SHAPES THE ADVERSARIAL HAND ADDED, each the seed that separates the shipped guard
# from a narrower one that passed every single-anchor arm above.
row_is "PC-FIXTURE-SECOND-SUBSTRING" NEEDS-REVIEW \
  "a backslash in the SECOND of two anchors is refused — the whole quoted run is covered, not its first member"
detail_has "PC-FIXTURE-ESCAPED-QUOTE" "contains a backslash" \
  "and says so"
row_is "PC-FIXTURE-ESCAPED-PATH" NEEDS-REVIEW \
  "a markdown-escaped PATH is refused before the basename fallback can guess it right"
detail_has "Entry I" "does not resolve" \
  "the near-miss: a clean anchor on a missing path still reads as an unresolvable path"
# THE REMEDY IS PART OF THE ROW. A refusal that names the fault and not the fix sends the author
# to guess, and the adversarial hand's one-clause variant passed every arm above.
detail_has "PC-FIXTURE-ESCAPED-BACKTICK" "Write backticks and quotes bare" \
  "the anchor row carries its remedy"
detail_has "PC-FIXTURE-ESCAPED-BACKTICK" "verify: sh" \
  "and names the escape hatch for text that genuinely contains a backslash"
# THE ESCAPE HATCH IS NAMED. The surviving arms above assert that the anchor row's remedy carries
# the two halves: write backticks and quotes bare, and name `verify: sh` for text that genuinely
# contains a backslash. An `sh` receipt is a program and its backslashes are its own.

} # end lr_unit_backslash_anchor
lr_unit_two_line_sh() {
# --- A TWO-LINE `sh` RECEIPT IS REFUSED, NEVER CLOSED (BL-113) ---------------------------------
# The extraction reads one line, so a receipt wrapped across two arrives cut inside its quote.
# Before the parse guard `bash -c` died at exit 2 on the fragment, `*)` read exit 2 as "no longer
# reproduces", `receipt_absent_subjects` found every named path present, and the entry read
# CLOSE-CANDIDATE — measured on this seed before the guard existed. Both directions: the
# truncated receipt is refused with the MALFORMED reason, and the trailing-comment near-miss —
# valid on its own line, a syntax error under a `{ …; }` wrapper — is evaluated and reads
# STILL-LIVE. The near-miss is what separates "parse the receipt" from "parse the wrapper".
# THE TWO SHAPES A BARE PARSE ACQUITS. A trailing backslash and an open heredoc both parse clean
# as one-line fragments on bash 3.2; the second wrapper line is what turns each into a syntax
# error. The backslash fragment EXITS 0, so without the wrap it read STILL-LIVE here and a CLOSE
# on the distribution engine — a verdict from half a receipt either way.
row_is "PC-FIXTURE-SH-TRAILING-BACKSLASH" NEEDS-REVIEW \
  "a receipt cut after a trailing backslash is refused — the closer line becomes the continuation"

# THE BACKSLASH ENTRIES on a tiny ledger, cut from the seeded one by heading so the receipts are not restated here.
LED_SEEDED="$CONS/_bmad-output/ai-dlc-update/push-candidate-ledger.md"
TINY="$(dirname "$DIST")/tiny-backslash-ledger.md"
awk '/^## PC-FIXTURE-ESCAPED-BACKTICK/{p=1} /^## PC-FIXTURE-EOF-FENCE/{p=0} p' "$LED_SEEDED" > "$TINY"
ASSERTIONS=$((ASSERTIONS + 1))
tiny_n="$(grep -c '^## PC-FIXTURE-' "$TINY")" || tiny_n=0
if [ "$tiny_n" -eq 10 ]; then
  lr_okf '%-22s the tiny ledger carries exactly the ten backslash entries\n' "tiny-ledger"
else
  lr_badf '%-22s the tiny ledger carries %s entries, not 10\n' "tiny-ledger" "$tiny_n"
fi
# The same tiny ledger through the shipped closer: the refusal row AND the close.
tiny_out="$(lr_eng "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$TINY" 2>&1)"
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$tiny_out" | awk -F'\t' '$2 ~ /PC-FIXTURE-ESCAPED-BACKTICK/ && $1=="NEEDS-REVIEW" && index($3,"contains a backslash")>0 {a=1} $2 ~ /PC-FIXTURE-BARE-BACKTICK/ && $1=="CLOSE-CANDIDATE" {b=1} END{exit !(a && b)}'; then
  lr_okf '%-22s the closer on the tiny ledger: escaped refused with the backslash reason, bare closes\n' "tiny-control"
else
  lr_badf '%-22s the closer does not reproduce the two baseline rows on the tiny ledger\n' "tiny-control"
  printf '%s\n' "$tiny_out" | sed 's/^/          | /'
fi
} # end lr_unit_two_line_sh
lr_unit_dist_checkout() {
# --- $DIST IS THE CHECKOUT, NOT THE REF BEING PULLED ------------------------------------------
#
# `ledger-reverify.sh` exports `$DIST` to every `sh` receipt, and its header used to say `$DIST`
# "is handed to `git -C` and is form-insensitive" — a claim about how receipts are WRITTEN, with
# nothing enforcing it. A receipt is an arbitrary `bash -c` string, so `$DIST/VERSION` and
# `AI_DLC_PROJECT_ROOT="$DIST"` are ordinary reads of the distribution's WORKING TREE, which sits
# wherever the operator last checked out. Measured on the reference consumer pulling 0.557.0 ->
# 0.564.0 with the checkout three commits past theirs: of 28 `sh` receipts naming `$DIST`, 26
# handed it only to `git -C` and 2 read it as a path — and BOTH of those flipped STILL-LIVE ->
# CLOSE-CANDIDATE in one run, on fixes that had landed a release PAST the pull.
#
# THIS FIXTURE COULD NOT SEE THE CLASS UNTIL THE SEED MOVED. The seed's dist HEAD WAS `$THEIRS`,
# so a path read and a rev-spec read returned the same bytes and every wrong engine passed. The
# seed now commits once past theirs (VERSION 0.104.0 at the checkout, 0.103.0 at theirs), which
# is the precondition asserted first below: with HEAD == THEIRS the six arms after it are
# vacuous and would read exactly as they do now.
ASSERTIONS=$((ASSERTIONS + 1))
dist_head_v="$(cat "$DIST/VERSION" 2>/dev/null)"
dist_theirs_v="$(git -C "$DIST" show "${THEIRS}:VERSION" 2>/dev/null)"
if [ -n "$dist_head_v" ] && [ -n "$dist_theirs_v" ] && [ "$dist_head_v" != "$dist_theirs_v" ]; then
  lr_okf '%-22s the checkout reads %s and theirs reads %s — a $DIST path read and a rev-spec read return DIFFERENT bytes, so the arms below can discriminate\n' \
    "checkout-past-theirs" "$dist_head_v" "$dist_theirs_v"
else
  lr_badf '%-22s the checkout (%s) and theirs (%s) read the same VERSION, so every $DIST-as-path arm below passes for the wrong reason and proves nothing\n' \
    "checkout-past-theirs" "${dist_head_v:-<none>}" "${dist_theirs_v:-<none>}"
fi

# A. $THEIRS_TREE IS A TREE AT THEIRS. A positive outcome, not the absence of a failure: the
# receipt demands the tree read 0.103.0, so a THEIRS_TREE bound to $DIST reads 0.104.0
# and the entry flips. An arm asserting only "not CLOSE-CANDIDATE" would pass against a tree that
# was never built, because the refusal above also withholds the close.
row_is "Entry SH-THEIRS-TREE " STILL-LIVE \
  "\$THEIRS_TREE reads the distribution AT THEIRS (0.103.0) while the checkout is at 0.104.0"
# ...and the tree does not outlive the run. Invisible from the row set — the run reports
# identically whether the directory survives — and under a twelve-wide pool a leak per invocation
# fills the temp filesystem with no symptom. The path comes from the receipt's own side channel.
ASSERTIONS=$((ASSERTIONS + 1))
tt_rec="$CONS/theirs-tree-path.txt"
tt_path="$(cat "$tt_rec" 2>/dev/null)"
if [ -z "$tt_path" ]; then
  lr_badf '%-22s no receipt recorded a $THEIRS_TREE path, so the materializer never ran and this arm has no subject\n' "theirs-tree-cleanup"
elif [ -d "$tt_path" ]; then
  lr_badf '%-22s the materialized tree %s SURVIVED the run — the EXIT trap did not remove it, and a pool twelve-wide leaks one per invocation with no symptom\n' "theirs-tree-cleanup" "$tt_path"
else
  printf -v _m '%-22s the materialized tree was removed on EXIT (recorded path is gone, and the receipt asserted it existed while running)' "theirs-tree-cleanup"; ok "$_m"
fi
# ...and a DISTRIBUTION path under $THEIRS_TREE is not a consumer subject. The SH-DIST-PATH
# pairing one spelling along: an extractor reading `$THEIRS_TREE/core/...` as a missing consumer
# path would downgrade a legitimate close to NEEDS-REVIEW. SH-SUBJECT-GONE is the paired control
# above — a genuinely absent CONSUMER path in the same position must still be flagged.
row_is "Entry SH-THEIRS-TREE-PATH" CLOSE-CANDIDATE \
  "a \$THEIRS_TREE/docs/... and /scripts/... token names no consumer subject; reading one out of it would withhold a close on a receipt that works"
# ...and the BRACED spelling reaches the same partition. `${THEIRS}` needs a `}` right after
# `THEIRS`, so `${THEIRS_TREE}` matches none of the rc=0 partition's original alternations while
# the UNBRACED form matches one by accident. Without its own alternation this entry is accused of
# being unfalsifiable while it reads upstream at theirs — a NEEDS-REVIEW, not a wrong status,
# which is why the arm reads the STATUS and not merely the presence of a row.
# THE STATUS CANNOT SEE THIS ONE. Both partitions emit STILL-LIVE for a receipt naming no
# path-shaped subject, so the arm reads the DETAIL, which is where they diverge: the upstream
# partition says only "still reproduces", the falsifiability branch appends "falsifiability NOT
# checked". A status-only assertion here passes against an engine that lands in the wrong partition.
# ...and the braced receipt that ALSO names an upstream-shipped subject diverges by STATUS, not
# merely by detail. The entry above names no path-shaped subject, so both partitions reach
# STILL-LIVE and only the wording separates them; this one resolves through the derived
# consumer->core table, so the falsifiability branch ACCUSES it. Two observables for one
# property, and the status-keyed one is the half a detail-only arm cannot supply.
row_lacks "Entry SH-THEIRS-TREE-BRACED-SUBJECT" NEEDS-REVIEW \
  "and is never accused of being unfalsifiable — it reads theirs through the materialized tree"

# B. $DIST READ AS A PATH IS REFUSED — the surviving arm seeds the exit-0 direction.
row_is "Entry SH-DIST-AS-PATH-ZERO" NEEDS-REVIEW \
  "a \$DIST path read that EXITS 0 is refused too — a refusal sited after the run leaves this one as a healthy-looking STILL-LIVE"
# C. A CONFORMING RECEIPT IS BYTE-UNCHANGED. 26 of the reference consumer's 28 `$DIST`-naming
# receipts are the `git -C` form, so a grammar that flagged every mention of `$DIST` would file 26
# healthy receipts as broken. Both spellings, because `$DIST` is not a substring of `${DIST}`.
row_is "Entry SH-DIST-REVSPEC " STILL-LIVE \
  "git -C \"\$DIST\" show \"\${THEIRS}:...\" is the conforming form and is untouched"
# ...and the `cd "$DIST" && git` form, which the reference consumer's ARCHIVE carries six of.
# Its NEAR-MISS sits one property apart — same `cd "$DIST"`, no `git` after it — so an exemption
# that acquits the good form without requiring the `git ` acquits its own arm's subject too.
row_is "Entry SH-DIST-CD-BARE" NEEDS-REVIEW \
  "a bare cd \"\$DIST\" NOT followed by git reads the CHECKOUT and is refused — the exemption requires the git that follows"

# THE `NAMED-UPSTREAM` ROW SURVIVES A REFUSAL. That row is emitted above the verb dispatch and is
# a signal about the ENTRY; a refusal that took it with it would silence the highest-value pair
# this tool prints. Both halves asserted on one entry: the receipt is refused AND the name stands.
row_has "PC-S907-NAMED-UPSTREAM-SURVIVES-A-REFUSED-RECEIPT" NEEDS-REVIEW \
  "the entry's \$DIST-path receipt is refused"
row_has "PC-S907-NAMED-UPSTREAM-SURVIVES-A-REFUSED-RECEIPT" NAMED-UPSTREAM \
  "and its NAMED-UPSTREAM row still stands — the refusal continues past the verb dispatch, it does not abandon the entry"


# D. LAZINESS. A ledger with no $THEIRS_TREE receipt must materialize nothing.
#
# COUNTED IN A TMPDIR THIS FIXTURE OWNS, NEVER UNDER A PREFIX THE BOX SHARES. The first cut counted
# every `${TMPDIR}/tmp.*` on the machine and went red once in three reps on a busy host. Narrowing
# the glob to the engine's own `ledger-reverify-theirs.*` prefix reduced the rate and did not change
# the kind: a shared prefix is a population ANY concurrent process on the box moves, and the
# prefix carries no per-run discriminator. Seven other fixtures in this suite drive the same engine
# through the worker pool, and the consumer's INSTALLED engine carries the byte-identical `mktemp`
# line under the same user and the same TMPDIR — each of them materializes under that prefix, and
# one `mkdir` there reads as +1, exactly the delta this arm convicts on while naming THIS engine.
#
# So the closer runs with TMPDIR pointed at a directory created here, under the fixture's own
# sandbox (the EXIT trap removes it), which no other process knows exists. The count stays
# PREFIX-scoped inside it rather than counting everything: the engine's `reconcile-memo.*` is a
# different subject with its own arm (memo-standalone-clean, below), and an unscoped count would
# let a memo leak convict this arm for a defect it does not own.
# The theirs-tree-prefix arm below proves the engine honours TMPDIR at all — a TMPDIR it ignored
# would leave this count at 0 forever. The DELTA is reported, never the raw totals.
LZ_TMP="$(mktemp -d "$(dirname "$DIST")/lazy-tmp.XXXXXX")" || LZ_TMP=""
[ -n "$LZ_TMP" ] && [ -d "$LZ_TMP" ] || { echo "FIXTURE ERROR: could not create the laziness arm's private TMPDIR under $(dirname "$DIST")" >&2; exit 2; }
tt_count() { ls -d "$LZ_TMP"/ledger-reverify-theirs.* 2>/dev/null | grep -c . || true; }
LED_NOTREE="$(dirname "$DIST")/no-theirs-tree-ledger.md"
{
  printf '# probe\n\n'
  printf '## PC-FIXTURE-NOTREE-A — a receipt naming no THEIRS_TREE\n\n'
  printf 'verify: sh true\n\n---\n\n'
  printf '## PC-FIXTURE-NOTREE-B — the git -C control in the same ledger\n\n'
  printf 'verify: sh git -C "$DIST" cat-file -e "${THEIRS}:VERSION"\n'
} > "$LED_NOTREE"
# Prints the verdict line; returns 1 on FAIL.
lz_verdict() { # <closer>
  local c="$1" before after delta out
  before="$(tt_count)"
  out="$(TMPDIR="$LZ_TMP" lr_eng "$c" "$DIST" "$BASE" "$CONS" "$THEIRS" "$LED_NOTREE" 2>&1)"
  after="$(tt_count)"
  delta=$((after - before))
  if ! printf '%s\n' "$out" | awk -F'\t' '$2 ~ /NOTREE-B/ && $1=="STILL-LIVE" {f=1} END{exit !f}'; then
    lr_badf '%-22s the tree-free ledger produced no control row, so this run establishes nothing about laziness\n' "theirs-tree-lazy"
    printf '%s\n' "$out" | sed 's/^/          | /'
    return 1
  elif grep -q THEIRS_TREE <<<"$out"; then
    lr_badf '%-22s a ledger naming no $THEIRS_TREE receipt still produced a row mentioning the materializer\n' "theirs-tree-lazy"
    printf '%s\n' "$out" | sed 's/^/          | /'
    return 1
  elif [ "$delta" -ne 0 ]; then
    lr_badf '%-22s this engine left %+d of its own theirs-trees behind across a ledger with no $THEIRS_TREE receipt — something was materialized and not cleaned\n' "theirs-tree-lazy" "$delta"
    return 1
  fi
  lr_okf '%-22s a ledger with no $THEIRS_TREE receipt materializes nothing (no materializer row, this engine'"'"'s own theirs-tree count delta %+d) while its control row still reports\n' "theirs-tree-lazy" "$delta"
}
ASSERTIONS=$((ASSERTIONS + 1))
lz_verdict "$CLOSER"; R_lazy=$?
# THE OTHER DIRECTION, AND WITHOUT IT THE ARM ABOVE IS SATISFIED BY A PREFIX NOTHING EVER USES.
# A count that is always zero reads exactly like a count that is correctly zero, so the same
# counter must be shown to RISE while a $THEIRS_TREE receipt is being evaluated. The receipt
# itself is the observer: it records the tree's path while the tree is live, so the presence of
# a directory carrying this engine's prefix at that moment is what the count would have seen.
ASSERTIONS=$((ASSERTIONS + 1))
tt_live="$(cat "$CONS/theirs-tree-path.txt" 2>/dev/null)"
case "$tt_live" in
  */ledger-reverify-theirs.*)
    lr_okf '%-22s a run WITH a $THEIRS_TREE receipt builds a tree carrying this engine'"'"'s own prefix (%s), so the zero above is a measured zero and not an unused counter\n' \
      "theirs-tree-prefix" "$(basename "$tt_live")" ;;
  *)
    lr_badf '%-22s the materialized tree does not carry this engine'"'"'s prefix (%s), so the laziness counter above can never rise and its zero establishes nothing\n' \
      "theirs-tree-prefix" "${tt_live:-<none recorded>}" ;;
esac
# ...AND IN THE PRIVATE TMPDIR THE LAZINESS ARM COUNTS. The prefix alone is not enough: the arm
# above counts `$LZ_TMP`, so an engine that ignored TMPDIR would materialize under the box's shared
# temp root, the private count would never move, and a real leak would read as delta 0. Driven under
# the SAME `TMPDIR="$LZ_TMP"` the laziness arm uses, on a one-entry ledger whose receipt records the
# live tree's path.
LED_INTREE="$(dirname "$DIST")/in-lz-tmp-ledger.md"
{
  printf '# probe\n\n'
  printf '## PC-FIXTURE-INTREE-A — a receipt that records where its THEIRS_TREE lives\n\n'
  printf 'verify: sh [ -n "${THEIRS_TREE:-}" ] || exit 127; echo "$THEIRS_TREE" > "$CONSUMER/lz-tree-path.txt"; test -d "$THEIRS_TREE"\n'
} > "$LED_INTREE"
rm -f "$CONS/lz-tree-path.txt"
TMPDIR="$LZ_TMP" lr_eng "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$LED_INTREE" >/dev/null 2>&1
lz_live="$(cat "$CONS/lz-tree-path.txt" 2>/dev/null)"
rm -f "$CONS/lz-tree-path.txt"
ASSERTIONS=$((ASSERTIONS + 1))
case "$lz_live" in
  "$LZ_TMP"/ledger-reverify-theirs.*)
    lr_okf '%-22s under TMPDIR=<private dir> the tree is materialized INSIDE it (%s), so the laziness count reads the directory the engine actually writes\n' \
      "theirs-tree-prefix" "$(basename "$lz_live")" ;;
  *)
    lr_badf '%-22s under TMPDIR=%s the tree was recorded at %s — a TMPDIR the engine ignores would leave the laziness counter reading 0 forever, so its zero establishes nothing\n' \
      "theirs-tree-prefix" "$LZ_TMP" "${lz_live:-<none recorded>}" ;;
esac

# ...and the closer installs exactly ONE EXIT trap. bash traps REPLACE each other, so a second
# `trap … EXIT` added for the tree would silently delete the consumer->core table's cleanup and
# leak that file on every run — a regression with no row and no symptom. Asserted on the SHIPPED
# closer, because the failure is a future edit, not a current behaviour.
ASSERTIONS=$((ASSERTIONS + 1))
trap_n="$(grep -cE '^trap .* EXIT$' "$CLOSER")" || trap_n=0
if [ "$trap_n" -eq 1 ]; then
  lr_okf '%-22s the closer installs exactly ONE EXIT trap, and its handler removes BOTH temporaries — a second trap would silently replace the first\n' "one-exit-trap"
else
  lr_badf '%-22s the closer installs %s EXIT traps; bash traps REPLACE each other, so all but the last are dead and their temporaries leak with no symptom\n' "one-exit-trap" "$trap_n"
fi
} # end lr_unit_dist_checkout
lr_unit_bootstrap_window() {
# --- THE BOOTSTRAPPING WINDOW: AN OLD ENGINE DOES NOT EXPORT $THEIRS_TREE ----------------------
#
# Re-verification runs on the engine the CONSUMER LAST INSTALLED, so for one pull after
# `$THEIRS_TREE` ships, the engine evaluating a `$THEIRS_TREE` receipt is one that never exports
# it. Unguarded, `$THEIRS_TREE/VERSION` expands to `/VERSION`, the read fails, the receipt exits
# non-zero, and that engine reads non-zero as "no longer reproduces" — a false CLOSE on the very
# pull that delivers the fix. Nothing in the new engine can refuse it; the engine that would is
# the one not yet installed.
#
# THE NEW ENGINE REFUSES, which is the half of the convention the shipped engine owns: a `$THEIRS_TREE`
# receipt whose tree could not be materialized is NEEDS-REVIEW, never a close scored from the tool failure.
# The convention itself is that every `$THEIRS_TREE` receipt opens `[ -n "${THEIRS_TREE:-}" ] || exit 127;`,
# 127 being the "subject renamed or deleted" status the `126|127)` arm has turned into NEEDS-REVIEW since
# that arm was written.
  # A guarded `$THEIRS_TREE` receipt, evaluated at a ref whose tree cannot be built.
  LED_BOOT="$(dirname "$DIST")/boot-ledger.md"
  {
    printf '# probe\n\n'
    printf '## PC-FIXTURE-BOOT-GUARDED — a guarded $THEIRS_TREE receipt\n\n'
    printf 'verify: sh [ -n "${THEIRS_TREE:-}" ] || exit 127; [ "$(cat "$THEIRS_TREE/VERSION")" = "0.103.0" ]\n'
  } > "$LED_BOOT"
  # ...and the NEW engine refuses a $THEIRS_TREE receipt it could not materialize a tree for,
  # rather than scoring its non-zero exit. Driven by pointing the closer at a ref that does not
  # resolve in this dist, which is the only reachable materialization failure.
  ASSERTIONS=$((ASSERTIONS + 1))
  badref_out="$(lr_eng "$CLOSER" "$DIST" "$BASE" "$CONS" "0000000000000000000000000000000000000000" "$LED_BOOT" 2>&1)"
  if printf '%s\n' "$badref_out" | awk -F'\t' '$2 ~ /BOOT-GUARDED/ && $1=="NEEDS-REVIEW" {a=1} $2 ~ /BOOT-GUARDED/ && $1=="CLOSE-CANDIDATE" {b=1} END{exit !(a && !b)}'; then
    lr_okf '%-22s with the tree unmaterializable the receipt is NEEDS-REVIEW, never CLOSE — a tool failure must not manufacture the verdict that loses data\n' "theirs-tree-unavailable"
  else
    lr_badf '%-22s a $THEIRS_TREE receipt whose tree could not be materialized did not read NEEDS-REVIEW; every read inside an absent tree fails, so this is a close manufactured from a tool failure\n' "theirs-tree-unavailable"
    printf '%s\n' "$badref_out" | sed 's/^/          | /'
  fi

} # end lr_unit_bootstrap_window
lr_unit_receiptless_named() {
# --- A RECEIPT-LESS ID-KEYED ENTRY REACHES THE NAMING QUERY ------------------------------------
# THE DEFECT. flush() printed a row only for an entry carrying a `verify:` line, so an open
# id-keyed entry with NO receipt never reached `named_absorbed()` -- and upstream naming it is the
# ONLY mechanical signal such an entry can get. Measured on the reference consumer: 14 open
# id-keyed entries carried no receipt, 12 of them were named by upstream history, 0 rows for all 14.
# The fix emits a `0/0` extraction row for those entries that reaches the naming block and is then
# skipped before the verb dispatch.
#
# THREE SEEDS, ONE PROPERTY APART. NORECEIPT-NAMED is named by a pre-base commit and must emit
# exactly one row, NAMED-UPSTREAM with the receipt-less detail. NORECEIPT-NEVER-CITED is the same
# shape with no naming commit and must emit nothing. CAPS-HEADING is all-caps, hyphenated and named
# by the same commit, but is NOT an entry id: it passes named_absorbed()'s local case guard, so the
# shared `ledger_entry_id()` filter at extraction is the only thing keeping it silent.
rl_one='$2 ~ /^PC-FIXTURE-NORECEIPT-NAMED-UPSTREAM$/ {n++} END{print n+0}'
rl_n="$(printf '%s\n' "$OUT" | awk -F'\t' "$rl_one")"
row_has "PC-FIXTURE-NORECEIPT-NAMED-UPSTREAM" NAMED-UPSTREAM \
  "an open id-keyed entry with NO receipt, named by upstream history -> NAMED-UPSTREAM, its only mechanical signal"
ASSERTIONS=$((ASSERTIONS + 1))
rl_det="$(printf '%s\n' "$OUT" | awk -F'\t' '$1=="NAMED-UPSTREAM" && $2=="PC-FIXTURE-NORECEIPT-NAMED-UPSTREAM" {print $3; exit}')"
if [ "$rl_n" != 1 ]; then
  lr_badf '%-22s the receipt-less named entry emitted %s rows, want exactly 1 — a 0/0 row that reaches the verb dispatch invents a receipt verdict\n' "receiptless-one-row" "$rl_n"
elif ! grep -q 'carries NO verify: receipt' <<<"$rl_det"; then
  lr_badf '%-22s the row does not say the entry carries no receipt: %s\n' "receiptless-one-row" "$(printf '%s' "$rl_det" | cut -c1-110)"
elif grep -q 'no receipt in this entry can see\|re-anchor or drop the stale receipt' <<<"$rl_det"; then
  lr_badf '%-22s the row tells the operator to fix a receipt the entry does not have\n' "receiptless-one-row"
else
  lr_okf '%-22s exactly one row, and its detail says the entry carries no receipt and closes by annotation\n' "receiptless-one-row"
fi
row_is "FIXTURE-CAPS-HEADING-NOT-AN-ID" ABSENT \
  "all-caps and hyphenated, named by a commit verbatim, but not an entry id -> the shared id rule keeps it silent"

} # end lr_unit_receiptless_named
lr_unit_bare_bold_record() {
# --- THE COLUMN-0 BARE-BOLD RECORD (`**PC-…** — …`) IS AN ENTRY ------------------------------
# THE DEFECT, filed as PC-S305-BARE-BOLD-ENTRY-IS-INVISIBLE-TO-EVERY-REVERIFY. `ledger_entry_shape()`
# opened an entry only on `- **` or a heading, so a record written without the leading dash was
# body text of the entry ABOVE it: its receipt became that entry's second receipt and no row ever
# named it. The strict rule is an id-only bold span followed by an em dash or end of line.
row_is "PC-FIXTURE-BARE-BOLD-RECORD" CLOSE-CANDIDATE \
  "a column-0 bold id with an em dash opens its own entry, and its own receipt reports under it"
bb_above='$2 ~ /PC-FIXTURE-DASHED-ABOVE-BARE-BOLD/ {n++} END{print n+0}'
ASSERTIONS=$((ASSERTIONS + 1))
bb_n="$(printf '%s\n' "$OUT" | awk -F'\t' "$bb_above")"
if [ "$bb_n" = 1 ]; then
  lr_okf '%-22s the dashed entry above the record emits exactly one row — the record receipt is not attributed to it\n' "bare-bold-neighbour"
else
  lr_badf '%-22s the dashed entry above the record emitted %s rows, want 1 — the record was swallowed into it\n' "bare-bold-neighbour" "$bb_n"
fi
# THE NEAR-MISS. A body line OPENING with a bold id that closes before a comma is a MENTION. The
# looser `^-? ?\*\*PC-` rule matches it, splits the host, and moves the host receipt onto the
# mentioned id -- measured on the reference consumer archive, where such a line sits mid-body.
row_is "PC-FIXTURE-MENTIONED-IN-A-BODY" ABSENT \
  "...and the mentioned id does not become an entry of its own"

} # end lr_unit_bare_bold_record
lr_unit_memo_lifecycle() {
# --- THE CROSS-PROCESS MEMO LEAVES NOTHING BEHIND --------------------------------------------
# lib.sh builds `reconcile-memo.*` at SOURCE time in the main shell and arms its removal on the
# sourcing shell's EXIT, composed into any later `trap X EXIT`. Before that, the first lookup ran
# inside `$( … | … )`, built the directory in a subshell whose ownership record died with it, and
# every standalone run of this closer left one directory in TMPDIR — invisible in the row set,
# which is byte-identical either way. So both arms read the DIRECTORY, in a TMPDIR this fixture
# owns, with AI_DLC_RECONCILE_MEMO unset so the borrowed-directory path cannot hide the leak.
#
# Each arm is a function of the RECONCILE DIRECTORY and reads the directory the run leaves behind.
# The memo is built at SOURCE time whatever the ledger holds, so the run reads one entry: its control row.
MS_LED="$(lr_subledger memo 'Entry SH-DIST-REVSPEC hands')" || MS_LED="$DIST/no-such-sub-ledger"
# memo_standalone <reconcile-dir> -> "ok ..." or "FAIL ..." on one line
memo_standalone() {
  local r="$1" t out left
  t="$(mktemp -d "$(dirname "$DIST")/memo-tmp.XXXXXX")" || { echo "FAIL could not create a private TMPDIR"; return; }
  out="$(unset AI_DLC_RECONCILE_MEMO; TMPDIR="$t" FXCELL=e2e-memo-standalone bash "$r/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" "$MS_LED" 2>&1)"
  left="$(ls -d "$t"/reconcile-memo.* 2>/dev/null | grep -c .)" || left=0
  if ! printf '%s\n' "$out" | awk -F'\t' '$2 ~ /SH-DIST-REVSPEC / && $1=="STILL-LIVE" {f=1} END{exit !f}'; then
    echo "BROKEN the run produced no SH-DIST-REVSPEC STILL-LIVE control row, so it establishes nothing about the memo"
  elif [ "$left" -ne 0 ]; then
    echo "FAIL left=$left"
  else
    echo "ok left=0"
  fi
}
# memo_composed <reconcile-dir> -> "ok ..." or "FAIL ..." on one line. A sourcer that owns a memo
# directory arms its OWN `trap … EXIT` after sourcing, and that handler calls `exit 3` — the
# shape retired-layer-token and five other sourcers have, with the exit that makes order matter.
# SEPARATED FROM THE SOURCE-TIME BUILD ON PURPOSE: lib.sh is handed a borrowed directory OUTSIDE
# the counted TMPDIR, so it builds nothing there, and the probe records ownership of its own
# directory itself. Only the EXIT composition then decides whether that directory survives.
memo_composed() {
  local r="$1" t b out rc left
  t="$(mktemp -d "$(dirname "$DIST")/memo-trap.XXXXXX")" || { echo "FAIL could not create a private TMPDIR"; return; }
  b="$(mktemp -d "$(dirname "$DIST")/memo-borrowed.XXXXXX")" || { echo "FAIL could not create the borrowed directory"; return; }
  out="$(AI_DLC_RECONCILE_MEMO="$b" TMPDIR="$t" bash -c '. "$1/lib.sh" || exit 90; d="$(mktemp -d "$TMPDIR/reconcile-memo.XXXXXX")" || exit 91; AI_DLC_MEMO_OWNED="$d"; [ -d "$d" ] && echo PRE-EXISTS; trap "echo HANDLER-RAN; exit 3" EXIT; exit 0' _ "$r" 2>&1)"; rc=$?
  left="$(ls -d "$t"/reconcile-memo.* 2>/dev/null | grep -c .)" || left=0
  if ! grep -q PRE-EXISTS <<<"$out" || ! grep -q HANDLER-RAN <<<"$out" || [ "$rc" -ne 3 ]; then
    echo "BROKEN the probe did not build its directory, run its own handler, or exit 3 (rc=$rc), so the count below is not about composition"
  elif [ "$left" -ne 0 ]; then
    echo "FAIL left=$left"
  else
    echo "ok left=0 rc=$rc"
  fi
}
MS_R="$(dirname "$CLOSER")"
ASSERTIONS=$((ASSERTIONS + 1))
ms_v="$(memo_standalone "$MS_R")"
case "$ms_v" in
  ok*) printf -v _m '%-22s a standalone run with AI_DLC_RECONCILE_MEMO unset leaves 0 reconcile-memo.* in its private TMPDIR, while its control row still reports' "memo-standalone-clean"; ok "$_m" ;;
  *)   lr_badf '%-22s %s — the memo directory outlives the run, and nothing in the row set can show it\n' "memo-standalone-clean" "$ms_v" ;;
esac
ASSERTIONS=$((ASSERTIONS + 1))
mc_v="$(memo_composed "$MS_R")"
case "$mc_v" in
  ok*) printf -v _m '%-22s a sourcer that arms its own trap … EXIT after lib.sh, with a handler that calls exit 3, still removes the memo (%s)' "memo-trap-composed" "$mc_v"; ok "$_m" ;;
  *)   lr_badf '%-22s %s — a later trap X EXIT in a sourcer dropped lib.sh'"'"'s cleanup\n' "memo-trap-composed" "$mc_v" ;;
esac

# --- A SUBSHELL'S OWN EXIT TRAP MUST NOT TAKE THE PARENT'S MEMO WITH IT ------------------------
# Inside the EXIT handler of a `$( )` subshell bash 3.2 reports $BASH_SUBSHELL as 0, so a
# cleanup that compared levels only when the handler FIRED ran in the subshell and deleted the
# directory the main shell was still using. lib.sh's shadow `trap` compares levels when the trap
# is SET instead. The arm reads the directory the sourcing shell owns, after one
# `x=$(trap : EXIT; :)`, and requires it present and still owned by the main shell.
memo_subshell_trap() { # <reconcile-dir> -> "ok ..." / "FAIL ..." / "BROKEN ..."
  local r="$1" t out
  t="$(mktemp -d "$(dirname "$DIST")/memo-sub.XXXXXX")" || { echo "FAIL could not create a private TMPDIR"; return; }
  out="$(unset AI_DLC_RECONCILE_MEMO; TMPDIR="$t" bash -c '. "$1/lib.sh" || exit 90; d="$AI_DLC_MEMO_DIR"; [ -n "$d" ] && [ -d "$d" ] && echo BUILT; x=$(trap : EXIT; :); [ -d "$d" ] && echo AFTER-PRESENT || echo AFTER-GONE' _ "$r" 2>&1)"
  if ! grep -q BUILT <<<"$out"; then
    echo "BROKEN lib.sh built no memo at source time, so the subshell trap had nothing to delete"
  elif grep -q AFTER-GONE <<<"$out"; then
    echo "FAIL the memo was deleted by a subshell's own trap"
  elif grep -q AFTER-PRESENT <<<"$out"; then
    echo "ok present"
  else
    echo "BROKEN the probe printed neither verdict: $out"
  fi
}
# --- A SOURCER'S OWN EXIT HANDLER MUST STILL RUN UNDER set -e ----------------------------------
# The composed handler opens with lib.sh's cleanup, which returns the status it was entered with.
# A script that FAILS enters the handler non-zero, so under errexit a bare cleanup call ended the
# handler before the caller's command ran. The arm requires the caller's handler to print, with
# the ORIGINAL status in `$?`, on a failing `false`, and the script's own exit status preserved.
memo_errexit() { # <reconcile-dir> -> "ok ..." / "FAIL ..."
  local r="$1" t out rc left
  t="$(mktemp -d "$(dirname "$DIST")/memo-e.XXXXXX")" || { echo "FAIL could not create a private TMPDIR"; return; }
  out="$(unset AI_DLC_RECONCILE_MEMO; TMPDIR="$t" bash -c '. "$1/lib.sh" || exit 90; set -e; trap "echo OWN rc=\$?" EXIT; false' _ "$r" 2>&1)"; rc=$?
  left="$(ls -d "$t"/reconcile-memo.* 2>/dev/null | grep -c .)" || left=0
  if [ "$rc" -ne 1 ]; then
    echo "FAIL the script exited $rc, not the failing command's 1"
  elif ! grep -qx 'OWN rc=1' <<<"$out"; then
    echo "FAIL the caller's handler did not run with the original status (output: ${out:-none})"
  elif [ "$left" -ne 0 ]; then
    echo "FAIL left=$left"
  else
    echo "ok OWN rc=1 left=0"
  fi
}
ASSERTIONS=$((ASSERTIONS + 1))
st_v="$(memo_subshell_trap "$MS_R")"
case "$st_v" in
  ok*) printf -v _m '%-22s x=$(trap : EXIT; :) in a sourcer leaves the main shell'"'"'s memo directory in place' "memo-subshell-trap"; ok "$_m" ;;
  *)   lr_badf '%-22s %s\n' "memo-subshell-trap" "$st_v" ;;
esac
ASSERTIONS=$((ASSERTIONS + 1))
ee_v="$(memo_errexit "$MS_R")"
case "$ee_v" in
  ok*) printf -v _m '%-22s under set -e a failing sourcer still runs its own EXIT handler with the original status (%s)' "memo-errexit-handler" "$ee_v"; ok "$_m" ;;
  *)   lr_badf '%-22s %s\n' "memo-errexit-handler" "$ee_v" ;;
esac

} # end lr_unit_memo_lifecycle
lr_unit_id_class() {
# --- THE NAMING GUARDS ASK THE SHARED ID RULE, AND THE PREFIX ENDS AT THE SHARED ID CLASS --------
# `named_absorbed` and `named_ambiguous` each opened with a local `[A-Z0-9-]` guard -- the narrow
# spelling `ledger_entry_id()` was widened away from -- so an id carrying `.` or `_` got no naming
# row of any kind: measured on the reference consumer, an open dotted entry named by one release
# commit was silent while its two dash-only siblings named by the same commit closed. And the
# sprint-prefix search read `_` and an id-continuing `.` as a boundary, so a commit naming only a
# LONGER id was read as citing the bare prefix. Seeds S810-S817 and the prose label, seed.sh.
#
# SHIPS AHEAD OF ITS SUBJECT, like the B2 arms. Keyed on tokens only the fixed engine carries:
# the guard's helper name, and the full-stop carve-out of the boundary class. A consumer whose
# installed engine predates either SKIPs those arms; in the distribution they always run.
idc_guard=1; idc_bound=1
grep -qF 'label_is_own_entry_id' "$CLOSER" || grep -qF 'label_entry_id' "$CLOSER" || idc_guard=0
grep -qF '[.]([^0-9A-Za-z_-]' "$CLOSER" || idc_bound=0
[ "$B2_ISDIST" = 1 ] && { idc_guard=1; idc_bound=1; }
if [ "$idc_guard" = 0 ] && [ "$idc_bound" = 0 ]; then
  LR_SKIPPED=1
  printf '  SKIP  id-class naming arms -- the installed ledger-reverify.sh predates them; they land with the pull that carries this fixture\n'
  return 0
fi
# LABELS ARE COMPARED WITH `==`, never the `~` of row_has/row_is: a dotted label read as a regex
# matches ids it does not spell. Each cell is the FIRST NAMED-UPSTREAM-family status for that exact
# label, or `none`; AMBIGUOUS cells read the prefix-keyed row.
idc_kind() { # <rows> <label> -> status or none
  printf '%s\n' "$1" | awk -F'\t' -v l="$2" '$2 == l && $1 ~ /^NAMED-UPSTREAM(-DOCS-ONLY|-CITED-ONLY|-OFF-SUBJECT)?$/ {print $1; f=1; exit} END{if (!f) print "none"}'
}
idc_amb() { # <rows> <prefix> -> AMBIGUOUS or none
  printf '%s\n' "$1" | awk -F'\t' -v l="$2" '$2 == l && $1 == "NAMED-UPSTREAM-AMBIGUOUS" {f=1} END{print (f ? "AMBIGUOUS" : "none")}'
}
# THE CELLS, each `<tag>:<kind|amb>:<label>:<want>`, and the boundary cells only where the fixed
# boundary is installed.
IDC_CELLS="s810:k:PC-S810-3.2-DOTTED_SLUG-NAMED:NAMED-UPSTREAM s811:k:PC-S811-4.1_HEADING-FORM:NAMED-UPSTREAM s812:k:PC-S812-DASH-ONLY-CONTROL:NAMED-UPSTREAM s802:a:PC-S802:AMBIGUOUS s816:k:PC-S816-5.2-DOTTED_CITED:NAMED-UPSTREAM-CITED-ONLY prose:k:validate-fixture-gates.sh:none"
[ "$idc_guard" = 1 ] || IDC_CELLS="s812:k:PC-S812-DASH-ONLY-CONTROL:NAMED-UPSTREAM prose:k:validate-fixture-gates.sh:none"
# The boundary cells read the PREFIX-KEYED row: a bare-prefix citation is never attributed to an
# entry, so whether the boundary admitted a mention shows only as an AMBIGUOUS row on the prefix.
[ "$idc_bound" = 1 ] && IDC_CELLS="$IDC_CELLS s813:a:PC-S813:none s814:a:PC-S814:none s817:a:PC-S817:none s815:a:PC-S815:AMBIGUOUS"
idc_cell() { # <rows> <cell spec> -> the cell's reading
  local _t="${2%%:*}" _r="${2#*:}" _m _l
  _m="${_r%%:*}"; _r="${_r#*:}"; _l="${_r%:*}"
  if [ "$_m" = a ]; then idc_amb "$1" "$_l"; else idc_kind "$1" "$_l"; fi
}
idc_why() {
  case "$1" in
    s810) echo "a dotted, underscored bullet id named by its full slug -> the plain kind, as any id" ;;
    s811) echo "the same id class as a heading with an em-dash subtitle, the reference consumer's real shape" ;;
    s812) echo "the dash-only control named by the same commit -> the plain kind under every engine" ;;
    s802) echo "a prefix shared ONLY by dotted entries and cited bare -> one AMBIGUOUS row keyed on the prefix" ;;
    s816) echo "a dotted id cited only on a Not-discharged: line -> the citation kind, never the plain one" ;;
    prose) echo "a RECEIPTED lowercase prose label with a dash and a dot, named verbatim -> no naming row; it is not an entry id" ;;
    s813) echo "the prefix mentioned only as <prefix>_X, a longer id -> \`_\` extends an id, so no prefix row" ;;
    s814) echo "the prefix mentioned only as <prefix>.3-X, a longer id -> an id-continuing \`.\` extends it, so no prefix row" ;;
    s817) echo "a SHARED prefix mentioned only as <prefix>_X -> no AMBIGUOUS row" ;;
    s815) echo "the prefix followed by a full stop and a space -> punctuation, so the prefix IS cited: one unattributed AMBIGUOUS row, the presence twin" ;;
  esac
}
for _c in $IDC_CELLS; do
  ASSERTIONS=$((ASSERTIONS + 1))
  _t="${_c%%:*}"; _w="${_c##*:}"; _g="$(idc_cell "$OUT" "$_c")"
  if [ "$_g" = "$_w" ]; then lr_okf '%-22s %s  (%s)\n' "id-class-$_t" "$_g" "$(idc_why "$_t")"
  else lr_badf '%-22s read %s, want %s  (%s)\n' "id-class-$_t" "$_g" "$_w" "$(idc_why "$_t")"; fi
done

# The cells below read a ledger cut to this block alone.
IDW="$(dirname "$DIST")/id-class"; mkdir -p "$IDW"
awk '/^<!-- id-class block:/ {p=1; next} /^<!-- end id-class block -->/ {p=0} p' \
  "$CONS/_bmad-output/ai-dlc-update/push-candidate-ledger.md" > "$IDW/ledger.md"
idc_rows() { lr_eng "$1" "$DIST" "$BASE" "$CONS" "$THEIRS" "$IDW/ledger.md" 2>/dev/null; }

# THE sh CLOSE-CANDIDATE DETAIL CELLS. An `sh` receipt that ALREADY exited non-zero at base was not
# absorbed by base..theirs, so its close must not hand the operator v<theirs>: it names the commits
# this run's naming row lists (s818, a dotted id named by a seeded commit), or tells the operator to
# find the release (s819, never named). The control (s820) reproduces at base and closes at theirs,
# and keeps the v<theirs> text. The three entries are appended to THIS cut only, so the main
# ledger's RECEIPTS-UNDECIDED row is unchanged; these cells read the cut's control run. Keyed on the
# per-receipt flag only the fixed engine carries.
idc_det=1
grep -qF 'SBC_CLOSE_AT_BASE' "$CLOSER" || idc_det=0
grep -qF 'NA_ENTRY_KIND' "$CLOSER" || idc_det=0
[ "$B2_ISDIST" = 1 ] && idc_det=1
IDC_DCELLS=""
if [ "$idc_det" = 1 ]; then
  cat >> "$IDW/ledger.md" <<'IDCSH'

- **PC-S818-6.1-SH_CLOSED_AT_BASE** — an sh receipt already closed at base, and a commit names the id.
  verify: sh git -C "$DIST" cat-file -e "${THEIRS}:core/scripts/s818-subject.sh" && exit 1; exit 0

- **PC-S821-SH-AFTER-EMPTY-RECEIPT** — directly after a named entry; the FIRST receipt is empty, the
  second is an sh receipt already closed at base, and no commit names this id.
  verify:
  verify: sh git -C "$DIST" cat-file -e "${THEIRS}:core/scripts/s819-subject.sh" && exit 1; exit 0

- **PC-S822-7.1-SH_CITED_ONLY** — cited only on a Not-discharged: line; receipt closed at base.
  verify: sh git -C "$DIST" cat-file -e "${THEIRS}:core/scripts/s822-other.sh" && exit 1; exit 0

- **PC-S823-7.2-SH_DOCS_ONLY** — named only by a docs-only commit; receipt closed at base.
  verify: sh git -C "$DIST" cat-file -e "${THEIRS}:docs/s823-plan.md" && exit 1; exit 0

- **PC-S819-SH-CLOSED-AT-BASE-UNNAMED** — the same shape, and no commit names the id.
  verify: sh git -C "$DIST" cat-file -e "${THEIRS}:core/scripts/s819-subject.sh" && exit 1; exit 0

- **PC-S820-SH-REPRODUCED-AT-BASE** — the control: reproduces at base, stops reproducing at theirs.
  verify: sh case "$(git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc/SKILL.md")" in *MARKER_B*) exit 1 ;; esac; exit 0

- **PC-S824-DUPLICATE-ID** — the first copy: named by a commit, receipt still live.
  verify: theirs_lacks core/scripts/s824-subject.sh "MARKER_A"

- **PC-S824-DUPLICATE-ID** — the second copy of the same id: empty first receipt, then an sh
  receipt already closed at base.
  verify:
  verify: sh git -C "$DIST" cat-file -e "${THEIRS}:core/scripts/s824-subject.sh" && exit 1; exit 0
IDCSH
  IDC_DCELLS="s818:PC-S818-6.1-SH_CLOSED_AT_BASE:names-commit s819:PC-S819-SH-CLOSED-AT-BASE-UNNAMED:find-release s820:PC-S820-SH-REPRODUCED-AT-BASE:v-theirs"
  # The two adversary cells. s821 sits directly after the named s818 and its FIRST receipt is empty,
  # so an entry-level reset keyed on the receipt ORDINAL never fires for it and s818's shas leak in.
  # s822 is cited ONLY on a Not-discharged: line, s823 only by a docs-only commit: neither naming
  # is an absorption, so neither close may route the operator to "the commits that name the id".
  IDC_DCELLS="$IDC_DCELLS s821:PC-S821-SH-AFTER-EMPTY-RECEIPT:find-release s822:PC-S822-7.1-SH_CITED_ONLY:find-release s823:PC-S823-7.2-SH_DOCS_ONLY:find-release"
  # A DUPLICATE ID: two consecutive entries share one label. The first is named (plain kind, its
  # receipt still live, so it emits no close); the second has an empty first receipt and a
  # base-closed sh second. A reset keyed on the label changing never fires between them.
  IDC_DCELLS="$IDC_DCELLS s824:PC-S824-DUPLICATE-ID:find-release"
fi
IDC_TV="$(git -C "$DIST" show "${THEIRS}:VERSION" 2>/dev/null)"
IDC_S818="$(git -C "$DIST" log -F --grep='PC-S818-6.1-SH_CLOSED_AT_BASE' --format=%h "$THEIRS" 2>/dev/null)"
IDC_S824="$(git -C "$DIST" log -F --grep='PC-S824-DUPLICATE-ID' --format=%h "$THEIRS" 2>/dev/null)"
# <rows> <label> -> the CLOSE-CANDIDATE detail's class. `names-commit` requires the derived sha AND
# the absence of the v<theirs> annotation; `v-theirs` requires that annotation text.
idc_dcls() {
  local _d
  _d="$(printf '%s\n' "$1" | awk -F'\t' -v l="$2" '$2 == l && $1 == "CLOSE-CANDIDATE" {print $3; exit}')"
  [ -n "$_d" ] || { printf 'no-close'; return; }
  case "$_d" in *"'ADOPTED UPSTREAM (v$IDC_TV, verified"*) printf 'v-theirs'; return ;; esac
  # The duplicate's second copy carrying the first copy's naming sha is a leak across the boundary.
  if [ "$2" = PC-S824-DUPLICATE-ID ] && [ -n "$IDC_S824" ]; then
    case "$_d" in *"$IDC_S824"*) printf 'leaks-first-copy'; return ;; esac
  fi
  # s818's sha on ANY other label is a leak, whatever sentence carries it.
  if [ "$2" != PC-S818-6.1-SH_CLOSED_AT_BASE ] && [ -n "$IDC_S818" ]; then
    case "$_d" in *"$IDC_S818"*) printf 'leaks-s818'; return ;; esac
  fi
  # A NAMING SHA IN THE DETAIL IS `names-commit` ONLY ON s818's OWN LABEL. Anywhere else it is a
  # leak (another entry's sha) or a naming that is no absorption (cited-only, docs-only): `cites-sha`.
  case "$_d" in *"names this entry's id in commit(s) "*)
    if [ "$2" = PC-S818-6.1-SH_CLOSED_AT_BASE ] && [ -n "$IDC_S818" ]; then
      case "$_d" in *"$IDC_S818"*) printf 'names-commit'; return ;; esac
    fi
    printf 'cites-sha'; return ;;
  esac
  case "$_d" in *"find the release at which this receipt first stops reproducing"*) printf 'find-release'; return ;; esac
  printf 'other'
}
idc_read() {
  local _c _s="" _r
  for _c in $IDC_CELLS; do _s="$_s ${_c%%:*}=$(idc_cell "$1" "$_c")"; done
  for _c in $IDC_DCELLS; do _r="${_c#*:}"; _s="$_s ${_c%%:*}=$(idc_dcls "$1" "${_r%:*}")"; done
  printf '%s' "${_s# }"
}
idc_want() { local _c _s=""; for _c in $IDC_CELLS $IDC_DCELLS; do _s="$_s ${_c%%:*}=${_c##*:}"; done; printf '%s' "${_s# }"; }
idc_ctl_rows="$(idc_rows "$CLOSER")"
for _c in $IDC_DCELLS; do
  ASSERTIONS=$((ASSERTIONS + 1))
  _t="${_c%%:*}"; _r="${_c#*:}"; _w="${_c##*:}"; _g="$(idc_dcls "$idc_ctl_rows" "${_r%:*}")"
  if [ "$_g" = "$_w" ]; then lr_okf '%-22s %s  (sh CLOSE-CANDIDATE detail)\n' "id-class-$_t" "$_g"
  else lr_badf '%-22s detail reads %s, want %s (v<theirs> is %s, the naming commit %s)\n' "id-class-$_t" "$_g" "$_w" "${IDC_TV:-?}" "${IDC_S818:-<none>}"; fi
done
ASSERTIONS=$((ASSERTIONS + 1))
idc_ctl="$(idc_read "$idc_ctl_rows")"
if [ "$idc_ctl" != "$(idc_want)" ]; then
  lr_badf '%-22s the engine over the cut read {%s}, want {%s}\n' "id-class-control" "$idc_ctl" "$(idc_want)"
else
  printf -v _m '%-22s the engine over the cut reproduces every id-class cell' "id-class-control"; ok "$_m"
fi

} # end lr_unit_id_class

lr_unit_bl890() {
# --- A LABEL WITH ONE TRAILING PARENTHETICAL IS ASKED ABOUT BY ITS ID (BL-890) ------------------------
# receipt-bl890.sh beside this file owns the world and the cells (its header lists them). The shipped
# reconcile directory must answer every cell.
#
# SHIPS AHEAD OF ITS SUBJECT: a consumer whose installed engine has no `label_entry_id` SKIPs this unit;
# in the distribution it always runs.
  local _rec _wc _o _rc _bad
  _rec="$DIR/receipt-bl890.sh"
  if [ ! -f "$_rec" ]; then
    ASSERTIONS=$((ASSERTIONS + 1))
    lr_badf '%-22s receipt-bl890.sh is not beside this fixture\n' "receipt-bl890"
    return 0
  fi
  if [ "$B2_ISDIST" = 0 ] && ! grep -qF 'label_entry_id' "$CLOSER"; then
    LR_SKIPPED=1
    printf '  SKIP  BL-890 arms -- the installed ledger-reverify.sh predates them; they land with the pull that carries this fixture\n'
    return 0
  fi
# The shipped run builds the distribution and the consumer worlds into the cache.
  _wc="$(dirname "$DIST")/bl890-worlds"
  ASSERTIONS=$((ASSERTIONS + 1))
  _o="$(bash "$_rec" "$(dirname "$CLOSER")" "" "$_wc" 2>&1)"; _rc=$?
  # SCRUB-RAN (BL-965): the receipt's AI_DLC_* scrub must have unset its probe; presence-shaped, so a
  # receipt that printed nothing fails it too.
  ASSERTIONS=$((ASSERTIONS + 1))
  if grep -q '^SCRUB-RAN ' <<< "$_o"; then lr_okf '%-22s the receipt'"'"'s AI_DLC_* scrub unset its probe variable\n' "bl890-SCRUB-RAN"
  else lr_badf '%-22s receipt-bl890.sh printed no SCRUB-RAN line -- env is unreachable and its AI_DLC_* scrub is a no-op\n' "bl890-SCRUB-RAN"; fi
  if [ "$_rc" -ne 0 ]; then
    lr_badf '%-22s the shipped engine did not answer every cell (rc=%s): %s\n' "receipt-bl890" "$_rc" "$(printf '%s\n' "$_o" | grep -v '^ok ' | head -6 | tr '\n' ' ')"
    return 0
  fi
  lr_okf '%-22s a suffixed label is asked by its bare id (s1, s2, s3; sibling join sib/sibY), its never-named twin is silent (s0), a suffixed label whose prefix is cited bare is ambiguous on the prefix (amb), and every refused shape stays silent (r1-r6); c0 is the bare-id control\n' "receipt-bl890"
} # end lr_unit_bl890
lr_unit_bl932() {
# --- A LABEL WHOSE ID IS CLOSED BY ONE PUNCTUATION MARK IS ASKED ABOUT BY ITS ID (BL-932) ---------------
# receipt-bl932.sh beside this file owns the world and the cells (its header lists them), built the way
# lr_unit_bl890 builds bl890's: the shipped reconcile directory must answer every cell.
#
# SHIPS AHEAD OF ITS SUBJECT: a consumer whose installed engine lacks either layer SKIPs this unit; in
# the distribution it always runs.
  local _rec _wc _o _rc _rd
  _rec="$DIR/receipt-bl932.sh"
  _rd="$(dirname "$CLOSER")"
  if [ ! -f "$_rec" ]; then
    ASSERTIONS=$((ASSERTIONS + 1))
    lr_badf '%-22s receipt-bl932.sh is not beside this fixture\n' "receipt-bl932"
    return 0
  fi
  if [ "$B2_ISDIST" = 0 ] && { ! grep -qF '(\.+|:|' "$CLOSER" || ! grep -qF '[A-Za-z0-9_.-]*[A-Za-z0-9_-]/))' "$_rd/lib.sh"; }; then
    LR_SKIPPED=1
    printf '  SKIP  BL-932 arms -- the installed ledger-reverify.sh or lib.sh predates them; they land with the pull that carries this fixture\n'
    return 0
  fi
  _wc="$(dirname "$DIST")/bl932-worlds"
  ASSERTIONS=$((ASSERTIONS + 1))
  _o="$(bash "$_rec" "$_rd" "" "$_wc" 2>&1)"; _rc=$?
  # SCRUB-RAN (BL-965), as in lr_unit_bl890.
  ASSERTIONS=$((ASSERTIONS + 1))
  if grep -q '^SCRUB-RAN ' <<< "$_o"; then lr_okf '%-22s the receipt'"'"'s AI_DLC_* scrub unset its probe variable\n' "bl932-SCRUB-RAN"
  else lr_badf '%-22s receipt-bl932.sh printed no SCRUB-RAN line -- env is unreachable and its AI_DLC_* scrub is a no-op\n' "bl932-SCRUB-RAN"; fi
  if [ "$_rc" -ne 0 ]; then
    lr_badf '%-22s the shipped engine did not answer every cell (rc=%s): %s\n' "receipt-bl932" "$_rc" "$(printf '%s\n' "$_o" | grep -v '^ok ' | head -6 | tr '\n' ' ')"
    return 0
  fi
  lr_okf '%-22s an id closed by one mark is asked by its bare id (d1-d5 dot, k1-k2 colon, m1 em dash; i1 inner dot), and a second mark, another mark, prose after it or a bare prefix stays silent (n1-n4); c0 is the bare-id control\n' "receipt-bl932"
} # end lr_unit_bl932
lr_unit_label_prefix() {
# --- A LABEL READS ONLY ITS OWN ROW ------------------------------------------------------------------
# The seeded OUT puts the LONGER entry FIRST with a DIFFERENT status, so a helper that matches the
# label as a prefix reads the wrong row on the first-match read (row_is) and on the any-row reads
# (row_lacks).
  local pf_out r k
  pf_out="$(printf 'NEEDS-REVIEW\tEntry PFX-ZZ-SUBJECT is the longer id.\tlonger-detail\nSTILL-LIVE\tEntry PFX-ZZ is the shorter id.\tshorter-detail\n')"
  for k in row_is row_lacks; do
    if [ "$k" = row_is ]; then
      r="$( OUT="$pf_out"; ASSERTIONS=0; fails=0; oks=0; row_is "Entry PFX-ZZ" STILL-LIVE "probe" 2>&1 | head -1 )"
    else
      r="$( OUT="$pf_out"; ASSERTIONS=0; fails=0; oks=0; row_lacks "Entry PFX-ZZ" NEEDS-REVIEW "probe" 2>&1 | head -1 )"
    fi
    ASSERTIONS=$((ASSERTIONS + 1))
    case "$r" in
      "  ok "*) lr_okf '%-22s the shipped %s reads only its own row, not the longer entry whose label it prefixes\n' "prefix-$k" "$k" ;;
      *)
         lr_badf '%-22s want the shipped helper to read only its own row, got [%s]\n' "prefix-$k" "$r" ;;
    esac
  done
} # end lr_unit_label_prefix

# --- DISPATCH: every unit, then the joins that say they all ran ---------------------------------
lr_okf '%s\n' "$LR_JOIN_LINE"
# THE SHARED CONTROL IS EXACTLY SIX, CHECKED HERE AND NOT BESIDE IT. Everything between the
# shared control and this line is a function DEFINITION, so a unit body left at top level, or a
# helper call outside any unit, executes before this point and moves the count.
if [ "$ASSERTIONS" -ne 6 ]; then
  lr_badf '%-22s %s assertions ran before dispatch, want the shared control'"'"'s 6 -- something outside every lr_unit_ ran\n' "[shared]" "$ASSERTIONS"
fi
# A seed that exits 1 must read FIXTURE BROKEN: seed exited, and exit 2, and not fall through to assertions on four
# empty variables (placed after the shared-control count, which is exactly six and would move). It drives THIS
# fixture whole, with LR_SEED pointing at a failing seed, so the run reaches the seed check past the real J0 join and
# the real sibling files; a copied run.sh alone would die at J0 before the seed was read and pass for the wrong
# reason. The control is a seed that exits 0 and prints junk: the same harness must then NOT print "seed exited",
# so the text is the failing status and not something the harness always emits.
if [ -z "${LR_SEED:-}" ] && [ "$LR_GROUP" = a ]; then
  _sm="$(mktemp -d "${TMPDIR:-/tmp}/bl827-seed-XXXXXX")"
  printf '#!/bin/sh\nexit 1\n' > "$_sm/fail.sh"
  printf '#!/bin/sh\necho garbage\n' > "$_sm/junk.sh"
  _smo="$(LR_SEED="$_sm/fail.sh" bash "$DIR/run.sh" 2>&1)"; _smr=$?
  _sco="$(LR_SEED="$_sm/junk.sh" bash "$DIR/run.sh" 2>&1)"; _scr=$?
  rm -rf "$_sm"
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ "$_smr" = 2 ] && grep -qF 'FIXTURE BROKEN: seed exited' <<< "$_smo"; then
    lr_okf '%-22s a seed that exits 1 reads FIXTURE BROKEN: seed exited, exit 2\n' "seed-fails"
  else
    lr_badf '%-22s rc=%s want 2 and the text FIXTURE BROKEN: seed exited\n' "seed-fails" "$_smr"
  fi
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ "$_scr" = 2 ] && grep -qF 'FIXTURE BROKEN' <<< "$_sco" && ! grep -qF 'seed exited' <<< "$_sco"; then
    lr_okf '%-22s a seed that exits 0 with junk reads BROKEN without seed exited (the harness discriminates)\n' "seed-fails-ctl"
  else
    lr_badf '%-22s rc=%s want 2, FIXTURE BROKEN and no seed exited\n' "seed-fails-ctl" "$_scr"
  fi
fi
# A unit's stderr is captured to a FILE with `2>`, never with `$( )`, which would run the unit in
# a subshell and lose every ASSERTIONS, oks and fails it moved. It is replayed to stderr after the
# unit, and by the EXIT trap if the unit exits from inside its body.
LR_ENTERED=""
for _u in $LR_MINE; do
  LR_ENTERED="$LR_ENTERED $_u"
  LR_UNIT_ERR="$(dirname "$DIST")/lr-unit-$_u.err"
  _before="$ASSERTIONS"; LR_SKIPPED=""
  "lr_unit_$_u" 2>"$LR_UNIT_ERR"
  cat "$LR_UNIT_ERR" >&2
  # J2: a call to a helper this file does not define, or a variable another unit used to set,
  # prints to stderr and the unit runs on with fewer assertions -- which otherwise reads PASS.
  if grep -qE 'run\.sh: line [0-9]+: .*(command not found|unbound variable)$' "$LR_UNIT_ERR"; then
    lr_badf '%-22s unit %s hit: %s\n' "[J2]" "$_u" \
      "$(grep -E 'run\.sh: line [0-9]+: .*(command not found|unbound variable)$' "$LR_UNIT_ERR" | head -1)"
  fi
  LR_UNIT_ERR=""
  # THE FLOOR: every unit asserts something. An emptied or early-returning unit otherwise passes.
  # The one exemption is DECLARED by the unit (LR_SKIPPED=1, on a consumer whose installed engine
  # predates the arms it would run); an early return declares nothing and is still caught.
  if [ "$ASSERTIONS" -le "$_before" ] && [ -z "$LR_SKIPPED" ]; then
    lr_badf '%-22s unit %s made no assertion -- an emptied or early-returning unit reads exactly like a passing one\n' "[floor]" "$_u"
  fi
done
# J1: the SET of units entered equals the set DECLARED IN THIS FILE'S TEXT, re-derived here rather
# than read back off the loop variable, which would agree with itself whatever it skipped.
lr_got="$(printf '%s\n' $LR_ENTERED | grep . | sort)"
lr_want="$(sed -n 's/^lr_unit_\([a-z0-9_]*\)() {$/\1/p' "$LR_SELF" | grep -xF -f <(printf '%s\n' $LR_MINE) | sort)"
if [ -z "$lr_want" ] || [ "$lr_got" != "$lr_want" ]; then
  lr_badf '%-22s entered {%s}, declared {%s}\n' "[J1]" \
    "$(printf '%s' "$lr_got" | tr '\n' ' ')" "$(printf '%s' "$lr_want" | tr '\n' ' ')"
fi
LR_DONE=1
echo
report_end "ledger-reverify shard '$LR_GROUP' of '$SHARDS'"
