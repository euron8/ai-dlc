#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# Exercise reconcile/ledger-reverify.sh against the ledger-reverify fixture.
#
# THE DIFFERENTIAL. Entry A and Entry B carry identical verify directives except the
# substring; they classify differently ONLY because `theirs` contains MARKER_B and not
# MARKER_A. A closer that probes `base` instead of `theirs` sees neither marker and calls
# both STILL-LIVE — so Entry B's CLOSE-CANDIDATE assertion below goes red. That is the
# mutation proof baked into the pair: the fixture cannot pass a closer that ignores theirs.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

# --- THE SHARD SPLIT (BL-406), AND IT IS A MEASUREMENT RATHER THAN A PREFERENCE ------------------
# The pre-push suite is POLE-BOUND: its makespan tracks its single longest DIRECTORY, because
# `core/fixtures/*/run.sh` is what the outer pool globs. Unsharded, this file was that pole: one
# serial unit of roughly 480s summed over its sections, which no pool width can get under.
#
# THE UNIT IS A `lr_unit_<slug>` FUNCTION, AND THE SET IS DERIVED FROM THIS FILE. Every section
# below the shared control is wrapped in one, closed by `} # end lr_unit_<slug>`. Sections that
# share state -- a helper one defines and the next one calls, a directory one builds and the next
# one reads -- are ONE unit, so no deal can separate them; helpers more than one unit calls are
# hoisted above the shared control, so any shard can call them. The receipt-suffix cluster
# (~108s, its mutants sharing the wreckage probe's shipped copy) stays atomic: a four-way deal
# already balances around it.
#
# FOUR SHARDS, DEALT BY MEASURED COST (longest-first onto the lightest shard), listed in file
# order within a shard. Every shard pays the seed, the baseline run and the six-row shared
# control, because a shard that skipped them could report green against a harness that never ran.
#
# THE SHARD ARRIVES AS AN ARGUMENT (`--group b`), never from the environment: the pre-push runner
# scrubs AI_DLC_*, and a fallback-to-'a' design would run shard 'a' four times and report four
# green fixtures. `--plan <x>` runs the coverage join and prints shard x's units, one per line,
# without seeding anything. The sibling directories `-b`, `-c` and `-d` are drivers that run this
# file with their shard and exit 2 unless its verdict line names that shard -- so an argument
# parser that stopped honouring `--group` cannot run shard 'a' four times and read green.
#
# THE COVERAGE JOIN (J0) runs in every shard before anything is seeded: the declared unit set is
# derived from this file's own `lr_unit_<slug>() {` lines, every one must have its end marker,
# the lists dealt across the words of SHARDS must be disjoint, non-empty and union to it exactly,
# and every declared shard but 'a' must have a driver directory that names it. The join proves it
# can fire, on a seeded duplicate and a seeded omission, before it is trusted.
#
# A MISSING DRIVER EXITS 2 IN EVERY LAYOUT, CONSUMER INCLUDED. All four directories sit under the
# same manifest globs and arrive in the same pull, so there is no ordering in which this file
# lands without its drivers; a shard 'a' that went green over absent drivers would be three
# quarters of this fixture silently gone. There is no consumer SKIP here to sit behind.
#
# THESE ARMS REPORT THROUGH FAILURES OR EXIT 2, NEVER THROUGH ASSERTIONS. The shards' assertion
# counts must sum, less three repeats of the shared six, to the unsharded total.
SHARDS="a b c d"
UNITS_a="close_anchor unicode_escape receipt_suffix"
UNITS_b="nonid_manual caller_error sh_base_control every_receipt name_signal short_id off_subject named_commits no_colon_swallow backslash_anchor dist_checkout bootstrap_window receiptless_named"
UNITS_c="cwd_invariance sh_missing_subject receipts_undecided naming_set unreadable_path nonid_wrong_fixes bare_bold_record"
UNITS_d="consumer_root entry_swallowed midline_receipt fenced_entries two_line_sh memo_lifecycle cited_only"

GROUP=a; LR_PLAN=0
case "${1:-}" in
  --group|--plan)
    [ "$1" = --plan ] && LR_PLAN=1
    GROUP="${2:-}"
    [ -n "$GROUP" ] || { echo "FIXTURE ERROR: $1 needs a shard name" >&2; exit 2; } ;;
  "") ;;
  *) echo "FIXTURE ERROR: unknown argument '$1' (want --group <x> or --plan <x>)" >&2; exit 2 ;;
esac
case " $SHARDS " in
  *" $GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;;
esac

# lr_partition_ok <declared file> <dealt file> -> 0 when dealt is disjoint and covers declared
# exactly; prints the offending names otherwise.
lr_partition_ok() {
  local dup miss extra
  dup="$(sort "$2" | uniq -d | tr '\n' ' ')"
  miss="$(sort -u "$2" | comm -23 <(sort -u "$1") - | tr '\n' ' ')"
  extra="$(sort -u "$2" | comm -13 <(sort -u "$1") - | tr '\n' ' ')"
  [ -z "$dup$miss$extra" ] && return 0
  echo "dealt twice: {${dup% }} dealt to no shard: {${miss% }} dealt but not declared: {${extra% }}"
  return 1
}
LR_SELF="$DIR/run.sh"
[ -f "$LR_SELF" ] || { echo "FIXTURE ERROR: cannot read $LR_SELF for the coverage join" >&2; exit 2; }
LR_JW="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed for the coverage join" >&2; exit 2; }
printf '%s\n' u1 u2 u3 > "$LR_JW/pd"
printf '%s\n' u1 u2 u2 u3 > "$LR_JW/pdup"
printf '%s\n' u1 u3 > "$LR_JW/pmiss"
printf '%s\n' u3 u1 u2 > "$LR_JW/pok"
if lr_partition_ok "$LR_JW/pd" "$LR_JW/pdup" >/dev/null || lr_partition_ok "$LR_JW/pd" "$LR_JW/pmiss" >/dev/null \
   || ! lr_partition_ok "$LR_JW/pd" "$LR_JW/pok" >/dev/null; then
  echo "FIXTURE BROKEN: [J0] the coverage join's self-probe did not discriminate (duplicate, omission, exact)" >&2
  rm -rf "$LR_JW"; exit 2
fi
sed -n 's/^lr_unit_\([a-z0-9_]*\)() {$/\1/p' "$LR_SELF" > "$LR_JW/declared"
sed -n 's/^} # end lr_unit_\([a-z0-9_]*\)$/\1/p' "$LR_SELF" > "$LR_JW/ended"
for _s in $SHARDS; do eval "printf '%s\n' \${UNITS_$_s:-}"; done | grep . > "$LR_JW/dealt"
lr_ndecl="$(grep -c . "$LR_JW/declared")" || lr_ndecl=0
lr_ndup="$(sort "$LR_JW/declared" | uniq -d | grep -c .)" || lr_ndup=0
if [ "$lr_ndecl" -eq 0 ] || [ "$lr_ndup" -ne 0 ] || ! cmp -s "$LR_JW/declared" "$LR_JW/ended"; then
  echo "FIXTURE BROKEN: [J0] $lr_ndecl lr_unit_ definitions derived from $LR_SELF ($lr_ndup declared twice), or their end markers do not pair with them one for one" >&2
  rm -rf "$LR_JW"; exit 2
fi
if ! lr_why="$(lr_partition_ok "$LR_JW/declared" "$LR_JW/dealt")"; then
  echo "FIXTURE BROKEN: [J0] the shard deal does not cover the declared units exactly -- $lr_why" >&2
  rm -rf "$LR_JW"; exit 2
fi
for _s in $SHARDS; do
  eval "_l=\"\${UNITS_$_s:-}\""
  [ -n "$_l" ] || { echo "FIXTURE BROKEN: [J0] shard '$_s' is declared and dealt no units; an empty shard passes everything it never checked" >&2; rm -rf "$LR_JW"; exit 2; }
  [ "$_s" = a ] && continue
  _drv="$DIR/../ledger-reverify-$_s/run.sh"
  # The driver must INVOKE this file with its shard as the argument. Comments are stripped whole-
  # line AND trailing, so `--group a # --group b` names shard a and nothing else.
  if [ ! -f "$_drv" ] || ! sed -e '/^[[:blank:]]*#/d' -e 's/[[:blank:]]#.*$//' "$_drv" \
       | grep -qE -- "^[[:blank:]]*(exec[[:blank:]]+)?bash[[:blank:]]+\"\\\$IMPL\"[[:blank:]]+--group[[:blank:]]+$_s([[:blank:]]|\$)"; then
    echo "FIXTURE BROKEN: [J0] shard '$_s' is declared but $_drv does not drive it" >&2; rm -rf "$LR_JW"; exit 2
  fi
done
rm -rf "$LR_JW"
eval "LR_MINE=\"\${UNITS_$GROUP}\""
if [ "$LR_PLAN" = 1 ]; then
  printf '%s\n' $LR_MINE
  exit 0
fi
LR_JOIN_LINE="[J0] coverage join: $lr_ndecl units derived from lr_unit_ lines, dealt disjointly across {$SHARDS}, union exact; shard '$GROUP' runs {$LR_MINE}"

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

# fd 3 is the run's own stderr, saved before any unit redirects it. The single EXIT trap
# replays a unit's captured stderr there: a unit that exits from inside its body (`exit 2` on
# a FIXTURE ERROR) runs this trap with the unit's `2>` still in force, so a replay to fd 2
# would write the file into itself and the message would reach nobody.
# LR_DONE is set only just before the final verdict. Any exit before it -- an `exit 0` inside a
# unit included, which would otherwise end the shard green with no verdict and skip every later
# unit, J1 and the floor -- is exit 2 after the unit's own stderr has been replayed once.
LR_DONE=""
exec 3>&2
read -r DIST BASE CONS THEIRS < <(bash "$DIR/seed.sh")
trap '[ -n "${LR_UNIT_ERR:-}" ] && [ -s "$LR_UNIT_ERR" ] && cat "$LR_UNIT_ERR" >&3; rm -rf "$(dirname "$DIST")"; [ "${LR_DONE:-}" = 1 ] || { echo "FIXTURE BROKEN: shard exited before dispatch completed" >&3; exit 2; }' EXIT

OUT="$(bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"

FAILURES=0
ASSERTIONS=0

# --- HOISTED HELPERS: every unit may call these, whichever shard it is dealt to ----------------
# $1 label-substring  $2 expected STATUS (or "ABSENT")  $3 why
row_is() {
  local label="$1" want="$2" why="$3" got
  ASSERTIONS=$((ASSERTIONS + 1))
  got="$(printf '%s\n' "$OUT" | awk -F'\t' -v l="$label" '$2 ~ l {print $1; exit}')"
  if [ "$want" = "ABSENT" ]; then
    if [ -z "$got" ]; then
      printf '  ok    %-22s no row  (%s)\n' "$label" "$why"
    else
      FAILURES=$((FAILURES + 1))
      printf '  FAIL  %-22s got=%s want=no-row  (%s)\n' "$label" "$got" "$why"
    fi
  elif [ "$got" = "$want" ]; then
    printf '  ok    %-22s %s  (%s)\n' "$label" "$got" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s got=%s want=%s  (%s)\n' "$label" "${got:-<none>}" "$want" "$why"
    printf '%s\n' "$OUT" | sed 's/^/          | /'
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
  if printf '%s\n' "$OUT" | awk -F'\t' -v l="$label" -v s="$want" '$2 ~ l && $1 == s {f=1} END{exit !f}'; then
    printf '  ok    %-22s %s present  (%s)\n' "$label" "$want" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s %s MISSING  (%s)\n' "$label" "$want" "$why"
    printf '%s\n' "$OUT" | sed 's/^/          | /'
  fi
}
row_lacks() {
  local label="$1" bad="$2" why="$3"
  ASSERTIONS=$((ASSERTIONS + 1))
  if printf '%s\n' "$OUT" | awk -F'\t' -v l="$label" -v s="$bad" '$2 ~ l && $1 == s {f=1} END{exit !f}'; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s %s present but must not be  (%s)\n' "$label" "$bad" "$why"
    printf '%s\n' "$OUT" | sed 's/^/          | /'
  else
    printf '  ok    %-22s no %s  (%s)\n' "$label" "$bad" "$why"
  fi
}

# $1 label-substring  $2 fixed string the DETAIL must contain  $3 why
detail_has() {
  local label="$1" want="$2" why="$3"
  ASSERTIONS=$((ASSERTIONS + 1))
  if printf '%s\n' "$OUT" | awk -F'\t' -v l="$label" -v s="$want" '$2 ~ l && index($3, s) > 0 {f=1} END{exit !f}'; then
    printf '  ok    %-22s detail names "%s"  (%s)\n' "$label" "$want" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s no row for this label carries "%s" in its detail  (%s)\n' "$label" "$want" "$why"
    printf '%s\n' "$OUT" | awk -F'\t' -v l="$label" '$2 ~ l' | sed 's/^/          | /'
  fi
}
detail_lacks() {
  local label="$1" bad="$2" why="$3"
  ASSERTIONS=$((ASSERTIONS + 1))
  if printf '%s\n' "$OUT" | awk -F'\t' -v l="$label" -v s="$bad" '$2 ~ l && index($3, s) > 0 {f=1} END{exit !f}'; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s a row for this label still carries "%s"  (%s)\n' "$label" "$bad" "$why"
    printf '%s\n' "$OUT" | awk -F'\t' -v l="$label" '$2 ~ l' | sed 's/^/          | /'
  else
    printf '  ok    %-22s no row carries "%s"  (%s)\n' "$label" "$bad" "$why"
  fi
}

# THE MUTATION IS A LINE REPLACEMENT READ FROM STDIN, NOT AN INLINE awk OR sed PROGRAM.
#
# Every anchor in this battery carries `$`, `"`, `'` and `\` together. Passed through the shell
# into `awk '…'` each one costs a level of escaping in each direction, and MEASURED on this
# battery's first cut THREE of six mutations died with `awk: illegal statement` and were reported
# as DID NOT APPLY — which reads exactly like an anchor that moved, on a change that was correct.
# `sed` is no better: the target lines contain `|`, `&` and `/`, so every delimiter is taken and
# an `&` in a replacement re-inserts the whole match.
#
# So the mutation is DATA: the exact OLD line and the exact NEW line as SINGLE-QUOTED ARGUMENTS,
# matched and substituted by a fixed-string compare in awk with both sides passed through ENVIRON,
# which no layer reprocesses. The anchor is a literal, so it is what the uniqueness assertion
# above checked, byte for byte.
#
# ARGUMENTS AND NOT A HEREDOC. A `<<'MUT'` body inside a `$( )` is NOT protected by its quoted
# delimiter here — MEASURED while writing this: the assignment
# `x="$(f <<'MUT' … $THEIRS … MUT )"` died with `THEIRS: unbound variable` under `set -u`, so the
# body was expanded despite the quoting. A single-quoted argument cannot be.
dp_mutant() { # <name> <OLD-line> [NEW-line] -> dir on stdout, empty if nothing changed
  local n="$1" old="$2" new="${3:-}" d
  d="$(dirname "$DIST")/mut-$n"; rm -rf "$d"; mkdir -p "$d"
  cp "$(dirname "$CLOSER")"/*.sh "$d/" 2>/dev/null
  [ -f "$d/lib.sh" ] || return 1
  DP_OLD="$old" DP_NEW="$new" awk '
    $0 == ENVIRON["DP_OLD"] { if (ENVIRON["DP_NEW"] != "") print ENVIRON["DP_NEW"]; next }
    { print }
  ' "$CLOSER" > "$d/ledger-reverify.sh" || return 1
  if cmp -s "$CLOSER" "$d/ledger-reverify.sh"; then return 1; fi
  # A MUTATION THAT APPLIED MUST STILL PARSE. A mutant with a syntax error emits nothing on every
  # input, and "no rows" scores as a kill against every presence-shaped arm while the control arm
  # fails for the same reason — which reads as entanglement rather than as a broken mutant.
  bash -n "$d/ledger-reverify.sh" 2>/dev/null || return 1
  printf '%s' "$d"
}
dp_kill() { # <name> <dir-or-empty> <kill-awk> <control-awk> <kill-msg> <ctl-msg>
  local n="$1" d="$2" kill="$3" ctl="$4" kmsg="$5" cmsg="$6" out
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ -z "$d" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutation DID NOT APPLY (matched nothing, awk died, or the sibling copy is incomplete), so the arm it targets is unproven\n' "$n"
    return
  fi
  out="$(bash "$d/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  if ! printf '%s\n' "$out" | awk -F'\t' "$ctl"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the control row is gone too (%s) — the mutant broke the closer rather than the guard, so its verdict is wreckage\n' "$n" "$cmsg"
    printf '%s\n' "$out" | grep -E 'SH-DIST|SH-THEIRS-TREE' | sed 's/^/          | /'
  elif printf '%s\n' "$out" | awk -F'\t' "$kill"; then
    printf '  ok    %-22s %s\n' "$n" "$kmsg"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutation applied and the arm it targets did NOT change verdict — that arm cannot fire\n' "$n"
    printf '%s\n' "$out" | grep -E 'SH-DIST|SH-THEIRS-TREE' | sed 's/^/          | /'
  fi
}

# THE B2 ARMS SHIP AHEAD OF THEIR SUBJECT. This fixture reaches a consumer a pull before the
# engine it tests, so every arm below that reads a B2 behaviour (the rev-spec strip, the reach
# kind, the full citing-commit list, the unreadable refusal) SKIPs on an installed engine that
# predates it. Keyed on a token only the fixed engine carries, and decided on the RESOLVED engine
# directory: in the distribution the arms always run, so a pre-fix engine there goes red.
B2_ISDIST=0
[ "$(cd "$(dirname "$CLOSER")" && pwd)" = "$(cd "$DIR/../../skills/ai-dlc-update/reconcile" 2>/dev/null && pwd)" ] && B2_ISDIST=1
B2_RUN=1
if ! grep -qF 'NAMED-UPSTREAM-DOCS-ONLY' "$CLOSER" && [ "$B2_ISDIST" = 0 ]; then B2_RUN=0; fi

# THE CONTROL ROW FOR ALL FIVE is the bare-bold near-miss reporting HAND-REVIEW. It is a
# legitimate entry that every correct engine emits, so a mutant that lost it broke the tool.
nid_ctl='$2 ~ /PC-FIXTURE-BARE-BOLD-MANUAL-STILL-SEEN/ && $1=="HAND-REVIEW" {f=1} END{exit !f}'
nid_ctlmsg='PC-FIXTURE-BARE-BOLD-MANUAL-STILL-SEEN HAND-REVIEW'


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
# missing from BOTH, so the mutant produced the same wrong answer twice and the byte-comparison
# passed. One side is now the CONSUMER ROOT itself -- the only directory where a
# consumer-relative path resolves -- which is what makes the two sides able to disagree.
cwd_probe="$(cd / && bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
cwd_atcons="$(cd "$CONS" && bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$cwd_probe" = "$cwd_atcons" ]; then
  printf '  ok    %-22s byte-identical from `/` and from the CONSUMER root — a receipt is evaluated at the consumer root, not wherever the caller stands
' "cwd-invariance"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the verdicts CHANGED with the working directory. A `verify: sh` receipt names consumer-relative paths; run from elsewhere its grep exits non-zero on a missing file and the entry reads as absorbed. That direction closes live entries.
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
row_is "A narrative closure record written as a bullet" NEEDS-REVIEW \
  "a manual receipt under a prose label names no entry an operator can find — entry-shape defect, not hand-review"
row_is "validate-fixture-prereq.sh" NEEDS-REVIEW \
  "the SECOND spelling: code span and arrow rather than a capitalised sentence, so a surface-form fix misses it"

# The row must say WHICH defect, or it joins three other NEEDS-REVIEW causes in one bucket.
ASSERTIONS=$((ASSERTIONS + 1))
nm_det="$(printf '%s\n' "$OUT" | awk -F'\t' '$2 ~ /A narrative closure record/ && $1=="NEEDS-REVIEW"{print $3; exit}')"
if [ -z "$nm_det" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s no NEEDS-REVIEW row for the prose-titled manual record at all\n' "nonid-manual-detail"
elif ! grep -q '^unresolved: ' <<<"$nm_det"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the detail does not OPEN with a cause token, so this cause cannot be told from the other three: %s\n' "nonid-manual-detail" "$(printf '%s' "$nm_det" | cut -c1-90)"
elif ! grep -q 'not an entry id' <<<"$nm_det"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the detail never says the LABEL is the defect, so the operator is told to fix the receipt: %s\n' "nonid-manual-detail" "$(printf '%s' "$nm_det" | cut -c1-110)"
elif ! grep -q 'BULLET GRAMMAR IS NOT THE THING TO CHANGE' <<<"$nm_det"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the detail does not warn off narrowing the bullet grammar, which is the remedy PC-S305 is filed against\n' "nonid-manual-detail"
else
  printf '  ok    %-22s opens with the cause token, names the LABEL as the defect, and warns off narrowing the grammar\n' "nonid-manual-detail"
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
row_is "PC-FIXTURE-DOTTED-0.242.0-AND-UNDER_SCORE-MANUAL" HAND-REVIEW \
  "an id carrying . and _ is still an id — a locally-restated id test loses both characters"
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
row_is "Entry G" CLOSE-CANDIDATE "consumer-namespace path resolves by basename -> same verdict as Entry B"

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
row_is "Entry J" NEEDS-REVIEW    "theirs_has on a substring absent at base too -> vacuous, not absorbed"
row_is "Entry K" NEEDS-REVIEW    "theirs_lacks on a substring present at base too -> vacuous, not absorbed"

# THE SIXTH DIFFERENTIAL — more than one substring in a directive. Joined into a single
# literal (quotes included) the pattern matches nothing, so BOTH L and M report "still
# lacks" and only L is right. M is the damage: theirs carries both markers, and the entry
# would sit open forever against an upstream that had already absorbed it. Matching each
# substring separately is what makes the pair disagree, which is what makes the test real.
row_is "Entry L" STILL-LIVE      "two substrings, neither at theirs -> genuinely still live"
} # end lr_unit_nonid_manual
lr_unit_sh_missing_subject() {
# --- the `sh` verb: a MISSING SUBJECT is not a fix -----------------------------
# Three outcomes, because two would let a verb that always reports one thing pass.
row_is "Entry SH-MOVED" NEEDS-REVIEW "exit 127 = subject renamed/deleted, NOT absorbed. A close here records an absorption that never happened, and closing is the direction that loses information permanently"
row_is "Entry SH-REAL"  CLOSE-CANDIDATE "OVER-FIRE CONTROL: a plain non-zero exit still closes, or the guard pins every sh entry open forever"

# THE POSITIVE OUTCOME, asserted rather than the absence of the old failure. A receipt naming a
# BARE consumer-relative subject that is PRESENT must read STILL-LIVE from this fixture's cwd,
# which is not the consumer root. The equality above cannot make that claim on its own.
row_is "Entry SH-RELATIVE-SUBJECT" STILL-LIVE "a BARE consumer-relative subject that EXISTS reproduces whatever directory the caller stands in; evaluated elsewhere its grep exits 2 and the entry reads as absorbed"
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
row_is "Entry SH-DIST-PATH" CLOSE-CANDIDATE "a \`core/scripts/<x>\` rev-spec names no consumer subject; reading one out of it withholds the close on a receipt that works"
row_is "Entry SH-DIST-BARE-CORE" CLOSE-CANDIDATE "a bare \`core/scripts/<x>\` pathspec is a distribution path; the whitelist's first-character test is what keeps it out"
# A `docs/` PATH AT A REF IS A DISTRIBUTION PATH TOO, AND `docs/` IS A CONSUMER PREFIX. Splitting
# the rev-spec at its colon left `docs/zz-dist-only-a.md` standing, the whitelist admitted it, it is
# absent on the consumer, and a receipt that works read as naming a missing subject. Five spellings
# of the ref in one receipt, so a strip that handles only one leaves the row NEEDS-REVIEW.
if [ "$B2_RUN" = 1 ]; then
row_is "Entry SH-REVPATH-DOCS" CLOSE-CANDIDATE "every <ref>:<path> token is a distribution read, whatever prefix its right-hand side carries"
else
  printf '  SKIP  SH-REVPATH-DOCS -- the installed ledger-reverify.sh predates the rev-spec strip; it lands with the pull that carries this fixture\n'
fi
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
# CLOSE. Both must still close, or the fix is the wider one this entry exists to refuse.
row_is "Entry SH-GIT-BARE-TOKEN" CLOSE-CANDIDATE "the bare token \`.git\` is not a subject — a path segment after \`.git/\` is required, or a directory every consumer has becomes an accusation"
row_is "Entry SH-GLOB-BARE-EXT" CLOSE-CANDIDATE "\`core/hooks/*.sh\` tokenizes to the bare \`.sh\`, which carries no glob character for the glob guard to refuse — admitting it files every \`*.ext\` receipt as unresolved"
row_is "Entry SH-LIVE"  STILL-LIVE "exit 0 still means it reproduces"

row_is "Entry M" CLOSE-CANDIDATE "two substrings, BOTH at theirs -> absorbed, must not stay open"

# THE SECOND DIFFERENTIAL — entry SHAPE. These three carry the same directives as B/C/D but
# in the `## SECTION-ID — title` shape instead of a `- **bullet**`. A parser that treats every
# heading as a pure terminator clears the label, so the directive is parsed and then dropped:
# no row, exit 0, indistinguishable from "nothing to close". Measured on the reference
# consumer, where every entry filed after 2026-07-20 used this shape and the one entry that
# had adopted the verify: convention at all was invisible while upstream had already fixed it.
row_is "PC-FIXTURE-HEADING-ABSORBED"  CLOSE-CANDIDATE "heading entry, theirs has MARKER_B -> same verdict as Entry B"
row_is "PC-FIXTURE-HEADING-CLOSED"    ABSENT          "heading entry annotated ADOPTED UPSTREAM -> closed"
row_is "PC-FIXTURE-HEADING-NO-VERIFY" ABSENT          "heading opens an entry, so it ends the one above -> no inherited directive"

# TWO WAYS TO BE DONE. `ADOPTED UPSTREAM` was the only closure token, so an entry WITHDRAWN
# because its premise was false went on asking for a verdict on every pull — and its receipt
# cannot settle it, since no upstream change can make a defect that never existed stop existing.
# Measured on the reference consumer: two of nine HAND-REVIEW rows were one withdrawn entry,
# counted twice. Matched as loosely as its sibling token, and for the same reason.
row_is "PC-FIXTURE-WITHDRAWN"        ABSENT          "premise was false -> finished, exactly like ADOPTED UPSTREAM"

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
  printf '  ok    %-22s names 0.101.0  (the version that absorbed it, not theirs 0.103.0)\n' "absorbing-version"
elif grep -q 'absorbed this at 0\.103\.0' <<<"$brow"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s names theirs 0.103.0 — the tip, not the absorbing release; this string is copied into a permanent ledger annotation\n' "absorbing-version"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s no recognisable version in the close row: %s\n' "absorbing-version" "$brow"
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
    printf '  ok    %-22s names 0.102.0  (the release CONTAINING the fix, not the blob at it)\n' "release-containing" ;;
  *'absorbed this at 0.101.0'*)
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s names 0.101.0 — the VERSION blob AT the absorbing commit, one release early\n' "release-containing" ;;
  *'absorbed this at 0.103.0'*)
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s names 0.103.0 — theirs, so the walk found nothing and fell back\n' "release-containing" ;;
  *)
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s no recognisable version in Entry V row: %s\n' "release-containing" "$vrow" ;;
esac

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
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s no NAMED-UPSTREAM row at all — the arms below cannot discriminate\n' "named-no-version"
elif grep -qE 'at v[0-9]+\.[0-9]+\.[0-9]+|\(v[0-9]+\.[0-9]+\.[0-9]+,' <<<"$nrow"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the row still renders a version: %s\n' "named-no-version" "$(printf '%s' "$nrow" | cut -c1-140)"
elif grep -q 'NAMES this entry.s id in ' <<<"$nrow"; then
  printf '  ok    %-22s no version, and it still says where upstream names the id\n' "named-no-version"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s no version, but the row no longer says WHERE: %s\n' "named-no-version" "$(printf '%s' "$nrow" | cut -c1-140)"
fi

# MUTATION — put the VERSION blob read back into absorbed_at. Entry V must regress to 0.101.0 and
# Entry B must NOT move: the two shapes are what make this a fix rather than a swap, and a mutant
# that moved both would mean the seed only carries one of them.
MUTV="$(dirname "$DIST")/mut-version"
rm -rf "$MUTV"; mkdir -p "$MUTV"
cp "$(dirname "$CLOSER")"/*.sh "$MUTV/" 2>/dev/null
sed 's@_v="$(release_containing "$_c")"@_v="$(git -C "$DIST" show "${_c}:VERSION" 2>/dev/null | tr -d "[:space:]")"@' \
  "$CLOSER" > "$MUTV/ledger-reverify.sh"

ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTV/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the forward walk is unproven\n' "mutation-version"
else
  mv_out="$(bash "$MUTV/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>/dev/null)"
  mv_v="$(printf '%s\n' "$mv_out" | awk -F'\t' '$2 ~ /Entry V/ {print $3; exit}')"
  mv_b="$(printf '%s\n' "$mv_out" | awk -F'\t' '$2 ~ /Entry B/ {print $3; exit}')"
  if [ -z "$mv_out" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant produced NO rows — a dead copy scores every absence as a kill\n' "mutation-version"
  elif ! grep -q 'absorbed this at 0\.101\.0' <<<"$mv_v"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s with the blob read restored Entry V still reads %s — the arm above is not watching the walk\n' "mutation-version" "$(printf '%s' "$mv_v" | sed -n 's/.*absorbed this at \([0-9.]*\).*/\1/p')"
  elif ! grep -q 'absorbed this at 0\.101\.0' <<<"$mv_b"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant also moved Entry B — the fix-is-release shape is not being held fixed\n' "mutation-version"
  else
    printf '  ok    %-22s the blob read regresses Entry V to 0.101.0 and leaves Entry B at 0.101.0\n' "mutation-version"
  fi
fi

# An unresolvable substring must fall back to theirs' VERSION, not print an empty version.
# A close row with no version at all is worse than one carrying the tip's.
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | awk -F'\t' '$1=="CLOSE-CANDIDATE"' | grep -q 'at \.\|at $\|at  '; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s a close row rendered an EMPTY version\n' "version-fallback"
else
  printf '  ok    %-22s no close row rendered an empty version\n' "version-fallback"
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
bt_out="$(bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$btick" 2>&1)"
for probe in "Entry BT:whole receipt in one code span (trailing backtick on the directive)" \
             "Entry BV:only the verb backticked (a backtick on each end of the verb)"; do
  ASSERTIONS=$((ASSERTIONS + 1))
  plabel="${probe%%:*}"; pwhy="${probe#*:}"
  pstatus="$(printf '%s\n' "$bt_out" | awk -F'\t' -v l="$plabel" '$2 ~ l {print $1; exit}')"
  if [ "$pstatus" = "CLOSE-CANDIDATE" ]; then
    printf '  ok    %-22s %s\n' "backtick:${plabel##* }" "$pwhy"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s got=%s want=CLOSE-CANDIDATE — %s; a formatting habit must not change the verdict\n' "backtick:${plabel##* }" "${pstatus:-<none>}" "$pwhy"
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
an_out="$(bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$anch" 2>&1)"
pm="$(printf '%s\n' "$an_out" | awk -F'\t' '$2 ~ /Entry PM/ {print $1; exit}')"
br="$(printf '%s\n' "$an_out" | awk -F'\t' '$2 ~ /Entry BR/ {print $1; exit}')"
if [ "$pm" = "CLOSE-CANDIDATE" ]; then
  printf '  ok    %-22s prose after the receipt does not overwrite it\n' "anchor:prose"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s got=%s want=CLOSE-CANDIDATE — a mid-sentence mention replaced the real receipt (last-match-wins)\n' "anchor:prose" "${pm:-<none>}"
fi
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$br" = "CLOSE-CANDIDATE" ]; then
  printf '  ok    %-22s a <br>-prefixed receipt still registers\n' "anchor:br"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s got=%s want=CLOSE-CANDIDATE — the anchor dropped a real receipt written after an HTML break\n' "anchor:br" "${br:-<none>}"
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
    printf '  ok    %-22s label is the whole id  (%s)\n' "$pat" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s got=[%s] want=[%s]  (%s)\n' "$pat" "${got:-<none>}" "$want" "$why"
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
  printf '  ok    %-22s no label lands on the old seventy-character cap\n' "label-width"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s %s label(s) are exactly 70 bytes — the clip is back\n' "label-width" "$clipped"
fi

# The closer must NEVER exit nonzero — it is a classifier and a close never blocks apply.
ASSERTIONS=$((ASSERTIONS + 1))
bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  printf '  ok    %-22s exit 0  (classifier never blocks)\n' "exit-code"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s exit=%s want=0  (a close must never block apply)\n' "exit-code" "$rc"
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
empty="$(bash "$CLOSER" "$DIST" "$BASE" "$NOLED" "$THEIRS" 2>&1)"; empty_rc=$?
if [ -z "$empty" ] && [ "$empty_rc" -eq 0 ]; then
  printf '  ok    %-22s silent, exit 0  (real consumer root, default ledger absent -> genuinely nothing to re-verify)\n' "no-ledger"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s rc=%s output=[%s] — a consumer that never filed a candidate must stay silent\n' "no-ledger" "$empty_rc" "$empty"
fi

# ARM 1 — an explicitly-supplied arg-5 path that is not readable. Nothing was re-verified, and
# that used to be spelled as zero rows and rc=0, which is how a clean corpus is spelled.
# Measured at 0.300.0 on the reference consumer: bogus arg 5 gave 0 rows, rc=0 and ZERO bytes of
# stderr, against 74 rows for the correct invocation.
ASSERTIONS=$((ASSERTIONS + 1))
bad5="$(bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$DIST/nonexistent-ledger.md" 2>/dev/null)"
bad5_n="$(printf '%s\n' "$bad5" | awk -F'\t' '$1=="INPUT-UNRESOLVED"{c++} END{print c+0}')"
if [ "$bad5_n" -eq 1 ] && grep -qF 'nonexistent-ledger.md' <<<"$bad5"; then
  printf '  ok    %-22s one INPUT-UNRESOLVED row naming the arg-5 path\n' "bad-arg5"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s got %s INPUT-UNRESOLVED row(s); an unreadable arg-5 path must not read as a clean corpus\n' "bad-arg5" "$bad5_n"
  printf '%s\n' "$bad5" | sed 's/^/          | /'
fi

# ARM 2 — THE MISTAKE THAT WAS ACTUALLY MADE, and the reason arm 1 alone is not the fix. This
# tool takes consumer THIRD and theirs FOURTH; every sibling in reconcile/ takes
# `<dist> <base> <theirs> <consumer>`, and layer-drift.sh's own usage line is the opposite
# order. Swapping them puts a SHA in the consumer slot, so `$LEDGER` is the DEFAULT path under a
# root that does not exist and an arg-5-only check never fires. The consumer root is therefore
# checked on its own.
ASSERTIONS=$((ASSERTIONS + 1))
swapped="$(bash "$CLOSER" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null)"
sw_n="$(printf '%s\n' "$swapped" | awk -F'\t' '$1=="INPUT-UNRESOLVED"{c++} END{print c+0}')"
if [ "$sw_n" -eq 1 ]; then
  printf '  ok    %-22s swapped args report, though the ledger path is the DEFAULT one\n' "swapped-args"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s got %s INPUT-UNRESOLVED row(s) — an arg-5-only check cannot see this case\n' "swapped-args" "$sw_n"
  printf '%s\n' "$swapped" | sed 's/^/          | /'
fi

# BOTH ARMS STILL EXIT 0. This is a classifier and its callers depend on that; the ROW is the
# signal, not the status code. An arm that reported by exiting non-zero would block `apply`.
ASSERTIONS=$((ASSERTIONS + 1))
bash "$CLOSER" "$DIST" "$BASE" "$THEIRS" "$CONS" >/dev/null 2>&1; sw_rc=$?
bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$DIST/nonexistent-ledger.md" >/dev/null 2>&1; b5_rc=$?
if [ "$sw_rc" -eq 0 ] && [ "$b5_rc" -eq 0 ]; then
  printf '  ok    %-22s both caller-error arms exit 0  (classifier never blocks)\n' "input-exit-code"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s swapped=%s bad-arg5=%s want 0/0 — reporting by exit code blocks apply\n' "input-exit-code" "$sw_rc" "$b5_rc"
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
rel_out="$(cd "$CONS" && bash "$CLOSER" "$DIST" "$BASE" . "$THEIRS" 2>/dev/null | sort)"
abs_out="$(printf '%s\n' "$OUT" | sort)"
rel_n="$(printf '%s\n' "$rel_out" | grep -c . )"
abs_n="$(printf '%s\n' "$abs_out" | grep -c . )"
if [ "$rel_n" -eq 0 ] || [ "$abs_n" -eq 0 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s one side produced NO rows (rel=%s abs=%s) — two empty sets agree, which proves nothing\n' "consumer-form" "$rel_n" "$abs_n"
elif [ "$rel_out" = "$abs_out" ]; then
  printf '  ok    %-22s %s rows, byte-identical whether the root arrives as "." or absolute\n' "consumer-form" "$rel_n"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the ROOT ARGUMENT decided a verdict:\n' "consumer-form"
  diff <(printf '%s\n' "$rel_out") <(printf '%s\n' "$abs_out") | sed 's/^/          | /'
fi

# SH-CWD must be STILL-LIVE in the normal run, or the differential above could be satisfied by
# a closer that drops the entry on both sides.
row_is "Entry SH-CWD" STILL-LIVE "an absolute root makes the absolute arm behave as the entry claims -> stays open"

# MUTATION — remove the normalization. The relative run must then diverge, and SH-CWD must flip
# to the FALSE CLOSE. Both halves are asserted: a mutant that merely changes the output proves
# nothing about which direction the defect ran in.
MUTN="$(dirname "$DIST")/mut-norm"
rm -rf "$MUTN"; mkdir -p "$MUTN"
cp "$(dirname "$CLOSER")"/*.sh "$MUTN/" 2>/dev/null
sed '/^\[ -n "\$_abs_consumer" \] && CONSUMER="\$_abs_consumer"$/d' "$CLOSER" > "$MUTN/ledger-reverify.sh"

ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTN/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the normalization assertions are unproven\n' "mutation-normalize"
else
  mn_rel="$(cd "$CONS" && bash "$MUTN/ledger-reverify.sh" "$DIST" "$BASE" . "$THEIRS" 2>/dev/null | sort)"
  mn_abs="$(bash "$MUTN/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>/dev/null | sort)"
  mn_cwd="$(printf '%s\n' "$mn_rel" | awk -F'\t' '$2 ~ /Entry SH-CWD/ {print $1; exit}')"
  # THE "NOTHING ELSE MOVED" ARM COMPARES VERDICTS, NOT RENDERED TEXT, AND THE REASON IS
  # MEASURED. `$CONSUMER` is printed verbatim into the reachability DETAIL, and this seed's own
  # root arrives as `$TMPDIR/…` where TMPDIR ends in a slash — a DOUBLED slash, which is one of
  # the four spellings this closer's header already names as breaking its containment test.
  # Normalizing collapses it, so ten DETAIL strings change while not one verdict does. Comparing
  # raw output here would score a correct fix as an unclean mutation; comparing (status, label)
  # asserts the property the arm is actually about.
  # RECEIPTS-UNDECIDED IS EXCLUDED HERE, AND IT IS THE ONE ROW THAT MUST BE. Its ENTRY column is
  # the LEDGER PATH, which is derived from the consumer root — so normalization rewrites it by
  # design, and comparing it would score the fix as an unclean mutation for doing exactly what
  # it exists to do. That the mutant still emits the row at all is asserted on its own below,
  # so excluding it here cannot hide the row going missing.
  mn_abs_v="$(printf '%s\n' "$mn_abs" | awk -F'\t' '$1!="RECEIPTS-UNDECIDED"{print $1"\t"$2}')"
  abs_out_v="$(printf '%s\n' "$abs_out" | awk -F'\t' '$1!="RECEIPTS-UNDECIDED"{print $1"\t"$2}')"
  mn_und="$(printf '%s\n' "$mn_abs" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{c++} END{print c+0}')"
  if [ "$mn_rel" = "$mn_abs" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s without normalization the two forms still agreed — the differential above is vacuous\n' "mutation-normalize"
  elif [ "$mn_cwd" != "CLOSE-CANDIDATE" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the unnormalized run moved SH-CWD to %s, not the FALSE CLOSE the defect produces\n' "mutation-normalize" "${mn_cwd:-<none>}"
  elif [ "$mn_und" -ne 1 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant emitted %s RECEIPTS-UNDECIDED row(s), want 1 — the row excluded from the comparison below must still be there\n' "mutation-normalize" "$mn_und"
  elif [ "$mn_abs_v" != "$abs_out_v" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant also moved the ABSOLUTE run, so it is not a clean mutation of the normalization alone\n' "mutation-normalize"
  else
    printf '  ok    %-22s without normalization "." produces a FALSE CLOSE on SH-CWD, and nothing else moves\n' "mutation-normalize"
  fi
fi

# MUTATION — widen receipt_absent_subjects' prefix test to a substring test, which is the shape
# the defect had. SH-DIST-BARE-CORE must flip to NEEDS-REVIEW and SH-SUBJECT-GONE must stay
# NEEDS-REVIEW: a mutant that reddens both is telling you the extractor went blind rather than
# that it stopped anchoring.
#
# THE TOKENIZER IS NOT THE SIGNAL, AND THE MUTANT IS HOW THAT WAS SETTLED. The obvious mutation
# was the `tr` keep-set — put `:` back in it so a rev-spec stays one token — and it SURVIVES,
# measured: the token is then `$THEIRS:core/scripts/<x>`, which fails the prefix test anyway.
# What carries the fix is that a candidate is a WHOLE TOKEN judged by its first characters, so
# that is what this mutation removes.
MUTP="$(dirname "$DIST")/mut-prefix"
rm -rf "$MUTP"; mkdir -p "$MUTP"
cp "$(dirname "$CLOSER")"/*.sh "$MUTP/" 2>/dev/null
#
# THE ANCHOR CARRIES EVERY ALTERNATION THE WHITELIST HAS, `.git/?*` INCLUDED. A mutation keyed on
# a subset of the line matches nothing the day an alternation is added, `cmp -s` reports DID NOT
# APPLY, and the arm below fails on the commit that fixes a defect — which reads exactly like the
# fix being wrong. The widened form keeps `.git/?*` widened too, so SH-GITHOOK-GONE stays
# NEEDS-REVIEW under this mutant and only SH-DIST-BARE-CORE moves.
sed 's@      docs/\*|_bmad-output/\*|scripts/\*|\.claude/\*|\.git/?\*) ;;@      *docs/*|*_bmad-output/*|*scripts/*|*.claude/*|*.git/?*) ;;@' \
  "$CLOSER" > "$MUTP/ledger-reverify.sh"

ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTP/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the anchoring assertion is unproven\n' "mutation-prefix"
else
  mp_out="$(bash "$MUTP/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>/dev/null)"
  mp_dist="$(printf '%s\n' "$mp_out" | awk -F'\t' '$2 ~ /Entry SH-DIST-BARE-CORE/ {print $1; exit}')"
  mp_gone="$(printf '%s\n' "$mp_out" | awk -F'\t' '$2 ~ /Entry SH-SUBJECT-GONE/ {print $1; exit}')"
  mp_hook="$(printf '%s\n' "$mp_out" | awk -F'\t' '$2 ~ /Entry SH-GITHOOK-GONE/ {print $1; exit}')"
  if [ -z "$mp_out" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant produced NO rows — a dead copy scores every absence as a kill\n' "mutation-prefix"
  elif [ "$mp_dist" != "NEEDS-REVIEW" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s SH-DIST-BARE-CORE read %s under the substring test, so the arm above is not watching the anchoring\n' "mutation-prefix" "${mp_dist:-<none>}"
  elif [ "$mp_gone" != "NEEDS-REVIEW" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant also moved SH-SUBJECT-GONE to %s — it blinded the extractor instead of widening it\n' "mutation-prefix" "${mp_gone:-<none>}"
  elif [ "$mp_hook" != "NEEDS-REVIEW" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant moved SH-GITHOOK-GONE to %s — it did not widen the `.git/` alternation with the others, so this mutation is a PARTIAL one and its kill is not the anchoring\n' "mutation-prefix" "${mp_hook:-<none>}"
  else
    printf '  ok    %-22s a substring prefix test reads a consumer subject out of a bare distribution pathspec, and only SH-DIST-BARE-CORE moves\n' "mutation-prefix"
  fi
fi

# MUTATION — NARROW the whitelist back to the four prefixes it carried before `.git/`, which is
# the TIP form this entry exists to fix. SH-GITHOOK-GONE must fall back to the FALSE CLOSE, and
# SH-SUBJECT-GONE must stay NEEDS-REVIEW: a mutant that reddens both blinded the extractor rather
# than removing the one prefix. This is the ABSENCE-shaped arm's mutant — without it the
# `row_is "Entry SH-GITHOOK-GONE" NEEDS-REVIEW` assertion above passes identically against an
# extractor that flags everything.
MUTG="$(dirname "$DIST")/mut-nogit"
rm -rf "$MUTG"; mkdir -p "$MUTG"
cp "$(dirname "$CLOSER")"/*.sh "$MUTG/" 2>/dev/null
sed 's@      docs/\*|_bmad-output/\*|scripts/\*|\.claude/\*|\.git/?\*) ;;@      docs/*|_bmad-output/*|scripts/*|.claude/*) ;;@' \
  "$CLOSER" > "$MUTG/ledger-reverify.sh"

ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTG/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the `.git/` prefix assertion is unproven\n' "mutation-nogit"
else
  mg2_out="$(bash "$MUTG/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>/dev/null)"
  mg2_hook="$(printf '%s\n' "$mg2_out" | awk -F'\t' '$2 ~ /Entry SH-GITHOOK-GONE/ {print $1; exit}')"
  mg2_gone="$(printf '%s\n' "$mg2_out" | awk -F'\t' '$2 ~ /Entry SH-SUBJECT-GONE/ {print $1; exit}')"
  if [ -z "$mg2_out" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant produced NO rows — a dead copy scores every absence as a kill\n' "mutation-nogit"
  elif [ "$mg2_hook" != "CLOSE-CANDIDATE" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s without the `.git/` prefix SH-GITHOOK-GONE read %s, not the FALSE CLOSE the defect produces — the arm above is not watching this prefix\n' "mutation-nogit" "${mg2_hook:-<none>}"
  elif [ "$mg2_gone" != "NEEDS-REVIEW" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant also moved SH-SUBJECT-GONE to %s — it blinded the extractor instead of removing one prefix\n' "mutation-nogit" "${mg2_gone:-<none>}"
  else
    printf '  ok    %-22s without the `.git/` prefix an absent hook subject reads CLOSE-CANDIDATE — the measured false close, reproduced — while SH-SUBJECT-GONE is unmoved\n' "mutation-nogit"
  fi
fi

# MUTATION — THE OVER-WIDE DIRECTION, and it is the one this entry's own filed remedy proposed.
# Adding a bare-root-dotfile arm beside `.git/` admits the bare token `.sh` that the tokenizer
# manufactures from `core/hooks/*.sh`, and the bare `.git` directory token besides. Both of this
# battery's over-fire controls must FLIP to NEEDS-REVIEW under it, which is the suppression
# failure — a spurious review withholding a legitimate close, with every `*.ext` receipt in it.
# WITHOUT THIS MUTANT THE BATTERY ACCEPTS THE WIDER FIX: every arm above passes under it.
MUTD="$(dirname "$DIST")/mut-dotfile"
rm -rf "$MUTD"; mkdir -p "$MUTD"
cp "$(dirname "$CLOSER")"/*.sh "$MUTD/" 2>/dev/null
sed 's@      docs/\*|_bmad-output/\*|scripts/\*|\.claude/\*|\.git/?\*) ;;@      docs/*|_bmad-output/*|scripts/*|.claude/*|.git/?*) ;;\
      .*) ;;@' \
  "$CLOSER" > "$MUTD/ledger-reverify.sh"

ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTD/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the over-fire controls are unproven\n' "mutation-dotfile"
else
  md_out="$(bash "$MUTD/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>/dev/null)"
  md_ext="$(printf '%s\n' "$md_out" | awk -F'\t' '$2 ~ /Entry SH-GLOB-BARE-EXT/ {print $1; exit}')"
  md_bare="$(printf '%s\n' "$md_out" | awk -F'\t' '$2 ~ /Entry SH-GIT-BARE-TOKEN/ {print $1; exit}')"
  md_hook="$(printf '%s\n' "$md_out" | awk -F'\t' '$2 ~ /Entry SH-GITHOOK-GONE/ {print $1; exit}')"
  if [ -z "$md_out" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant produced NO rows — a dead copy scores every absence as a kill\n' "mutation-dotfile"
  elif [ "$md_ext" != "NEEDS-REVIEW" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s a bare-dotfile arm left SH-GLOB-BARE-EXT at %s — the `.sh` token the tokenizer makes from a glob is not reaching the whitelist, so that control is asserting nothing\n' "mutation-dotfile" "${md_ext:-<none>}"
  elif [ "$md_bare" != "NEEDS-REVIEW" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s a bare-dotfile arm left SH-GIT-BARE-TOKEN at %s — the bare `.git` token is not reaching the whitelist, so the required path segment is asserting nothing\n' "mutation-dotfile" "${md_bare:-<none>}"
  elif [ "$md_hook" != "NEEDS-REVIEW" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the wider mutant ALSO lost SH-GITHOOK-GONE (%s) — it broke the whitelist rather than widening it, so its two kills above are not about the dotfile arm\n' "mutation-dotfile" "${md_hook:-<none>}"
  else
    printf '  ok    %-22s a bare-root-dotfile arm flips BOTH over-fire controls to NEEDS-REVIEW — every `*.ext` receipt filed as unresolved, suppressing real closes — while the motivating hook case is unmoved\n' "mutation-dotfile"
  fi
fi

# MUTATION — restore the unconditional bail. Both caller-error arms must go silent, and the
# genuine no-ledger arm must be unaffected: the defect was that ONE line answered three
# questions, so a mutant that also silenced the real case would be mutating the wrong thing.
MUTL="$(dirname "$DIST")/mut-bail"
rm -rf "$MUTL"; mkdir -p "$MUTL"
cp "$(dirname "$CLOSER")"/*.sh "$MUTL/" 2>/dev/null
awk '
  /^if \[ ! -d "\$CONSUMER" \]; then$/ { skip=1 }
  skip && /^fi$/ && !done_d { done_d=1; skip=0; next }
  /^if \[ ! -f "\$LEDGER" \]; then$/ { skipl=1; print "[ -f \"$LEDGER\" ] || exit 0"; next }
  skipl && /^fi$/ { skipl=0; next }
  skip || skipl { next }
  { print }
' "$CLOSER" > "$MUTL/ledger-reverify.sh"

ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTL/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the caller-error arms are unproven\n' "mutation-bail"
else
  ml_sw="$(bash "$MUTL/ledger-reverify.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null | grep -c . )"
  ml_b5="$(bash "$MUTL/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" "$DIST/nonexistent-ledger.md" 2>/dev/null | grep -c . )"
  ml_ok="$(bash "$MUTL/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>/dev/null | grep -c . )"
  if [ "$ml_sw" -ne 0 ] || [ "$ml_b5" -ne 0 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the unconditional bail still reported (swapped=%s arg5=%s) — the arms above are vacuous\n' "mutation-bail" "$ml_sw" "$ml_b5"
  elif [ "$ml_ok" -eq 0 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant produced no rows on a GOOD invocation either, so it is not a clean mutation of the bail alone\n' "mutation-bail"
  else
    printf '  ok    %-22s the unconditional bail silences both caller errors and nothing else (%s rows on a good run)\n' "mutation-bail" "$ml_ok"
  fi
fi

} # end lr_unit_consumer_root
lr_unit_receipts_undecided() {
# --- RECEIPTS-UNDECIDED: how much of the STILL-LIVE column this pull actually measured ----
# Both entries are STILL-LIVE, so the status alone cannot separate them. TH-UNDECIDED's
# substring is at BOTH refs (this pull moved neither side of the predicate); TH-DECIDED's
# arrived inside base..theirs. The pair is what makes the tally a finding rather than a count
# of still-live rows.
row_is "Entry TH-UNDECIDED" STILL-LIVE "present at theirs -> stays open, exactly like the control below"
row_is "Entry TH-DECIDED"   STILL-LIVE "also STILL-LIVE, so the STATUS cannot be what distinguishes them"

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
  printf '  ok    %-22s 1 of 5 — the control is excluded, the vacuous entry still counts in the total, and the refused anchors do not\n' "undecided-tally"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s want "1 of 5", got: %s\n' "undecided-tally" "${und:-<no row>}"
fi

# It must reach the operator, which means NOT being STILL-LIVE: emit-report.sh filters that one
# status out, and that filter is exactly why this confidence has been invisible.
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{n++} END{exit !(n==1)}'; then
  printf '  ok    %-22s exactly one run-scoped row, and its status is not STILL-LIVE\n' "undecided-once"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s want exactly one RECEIPTS-UNDECIDED row\n' "undecided-once"
fi

# SILENT AT ZERO. A ledger whose receipts are all well-anchored must say nothing, or the row is
# decoration on every pull and the operator learns to skip it.
ASSERTIONS=$((ASSERTIONS + 1))
zled="$CONS/_bmad-output/ai-dlc-update/well-anchored-ledger.md"
mkdir -p "$(dirname "$zled")"
printf -- '- **Entry ZA** — anchored on a token that arrived inside base..theirs.\n  verify: theirs_has core/skills/ai-dlc/SKILL.md "MARKER_B"\n' > "$zled"
z_out="$(bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$zled" 2>/dev/null)"
z_n="$(printf '%s\n' "$z_out" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{c++} END{print c+0}')"
z_live="$(printf '%s\n' "$z_out" | awk -F'\t' '$1=="STILL-LIVE"{c++} END{print c+0}')"
if [ "$z_n" -eq 0 ] && [ "$z_live" -eq 1 ]; then
  printf '  ok    %-22s no row when every receipt moved in range (control: the run still emitted its STILL-LIVE)\n' "undecided-silent"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s got %s undecided row(s) and %s still-live on a well-anchored ledger; want 0 and 1\n' "undecided-silent" "$z_n" "$z_live"
fi
rm -f "$zled"

# MUTATION — drop the base-side test, so the tally counts every still-live theirs_has receipt.
# The control entry is then swept in and the row reads "2 of 5": a number that still looks like
# a finding, which is what makes this mutant worth having.
MUTU="$(dirname "$DIST")/mut-undecided"
rm -rf "$MUTU"; mkdir -p "$MUTU"
cp "$(dirname "$CLOSER")"/*.sh "$MUTU/" 2>/dev/null
sed 's@^          base_holds "\$path" "\$subs" && th_undecided=@          th_undecided=@' \
  "$CLOSER" > "$MUTU/ledger-reverify.sh"

ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTU/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the tally assertions are unproven\n' "mutation-undecided"
else
  mu_out="$(bash "$MUTU/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>/dev/null)"
  mu_det="$(printf '%s\n' "$mu_out" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{print $3; exit}')"
  mu_rest="$(printf '%s\n' "$mu_out" | awk -F'\t' '$1!="RECEIPTS-UNDECIDED"' | sort)"
  ok_rest="$(printf '%s\n' "$OUT" | awk -F'\t' '$1!="RECEIPTS-UNDECIDED"' | sort)"
  if ! grep -q "^2 of 5 'theirs_has' receipt" <<<"$mu_det"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s without the base test the tally read: %s — want "2 of 5", so the control above is vacuous\n' "mutation-undecided" "${mu_det:-<no row>}"
  elif [ "$mu_rest" != "$ok_rest" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant also moved a non-tally row, so it is not a clean mutation of the base test alone\n' "mutation-undecided"
  else
    printf '  ok    %-22s without the base test the control is swept in ("2 of 5") and nothing else moves\n' "mutation-undecided"
  fi
fi

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
# THE REFUSAL SEED EXISTS IN BOTH DIRECTIONS, AND THE SECOND ONE IS THE ONLY ONE THAT CAN KILL
# THE TWO-WAY MUTANT. Measured while building this battery: with the refusal arm made
# unmatchable, a 127 base control reaches `[ "$_brc" -eq 0 ]` on the STILL-LIVE side and 127 is
# not 0, so it enters no numerator and the numerator does not move -- the STILL-LIVE refusal seed
# alone scores the fails-open mutant as SURVIVED. On the CLOSE side the test is
# `[ "$_brc" -ne 0 ]`, which 127 SATISFIES, so the row is scored *decided* on an evaluation that
# never happened. That is the exact failure C3 of the contract names, it is reachable from one
# direction only, and a battery seeded in the other direction cannot see it.
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
  printf '  ok    %-22s all seven probe receipts carry the rc pair their arm depends on, measured through the engine own wrapper (control: a trivial receipt answers 0 and an exit-3 receipt answers 3, so the runner is not returning a constant)\n' "sbc-preconditions"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s a probe receipt does not carry the rc pair its arm assumes%s (runner control: %s/%s, want 0/3) -- a receipt that matches at NEITHER ref reads exactly like one the pull did not move, so every count below would be unreadable\n' "sbc-preconditions" "${sbc_bad:- none}" "$sbc_ctl_t" "$sbc_ctl_f"
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

sbc_out="$(bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$SBC_LED" 2>/dev/null)"
sbc_det="$(printf '%s\n' "$sbc_out" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{print $3; exit}')"
sbc_row() { # <label> <want-status>
  ASSERTIONS=$((ASSERTIONS + 1))
  if printf '%s\n' "$sbc_out" | awk -F'\t' -v l="$1" -v s="$2" '$2 ~ l && $1 == s {f=1} END{exit !f}'; then
    printf '  ok    %-22s %s\n' "$1" "$2"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s want %s, got: %s\n' "$1" "$2" "$(printf '%s\n' "$sbc_out" | awk -F'\t' -v l="$1" '$2 ~ l {print $1; exit}')"
    printf '%s\n' "$sbc_out" | sed 's/^/          | /'
  fi
}
sbc_det_has() { # <name> <substring> <why>
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ -n "$sbc_det" ] && [ "${sbc_det#*"$2"}" != "$sbc_det" ]; then
    printf '  ok    %-22s %s\n' "$1" "$3"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the undecided detail does not carry "%s" (%s). Detail: %s\n' "$1" "$2" "$3" "${sbc_det:-<no row>}"
  fi
}
sbc_det_lacks() { # <name> <substring> <why>
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ -z "$sbc_det" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s there is no undecided row at all, so this absence is not a measurement (%s)\n' "$1" "$3"
  elif [ "${sbc_det#*"$2"}" = "$sbc_det" ]; then
    printf '  ok    %-22s %s\n' "$1" "$3"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the undecided detail carries "%s" and must not (%s)\n' "$1" "$2" "$3"
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
sbc_mv="$(bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$SBC_MOV_LED" 2>/dev/null)"
sbc_mv_u="$(printf '%s\n' "$sbc_mv" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{c++} END{print c+0}')"
sbc_mv_r="$(printf '%s\n' "$sbc_mv" | awk -F'\t' '$1=="STILL-LIVE" || $1=="CLOSE-CANDIDATE"{c++} END{print c+0}')"
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$sbc_mv_r" -lt 2 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the movers-only ledger produced %s verdict row(s), not 2 -- the run did not happen, so its silence establishes nothing\n' "sbc-silent-movers" "$sbc_mv_r"
elif [ "$sbc_mv_u" -eq 0 ]; then
  printf '  ok    %-22s a ledger whose receipts ALL moved in range emits no undecided row (control: both verdict rows still reported)\n' "sbc-silent-movers"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s %s undecided row(s) on a ledger where every receipt moved -- the count is a constant, not a finding\n' "sbc-silent-movers" "$sbc_mv_u"
fi

# SILENCE, ARM TWO: THE NULL DIFFERENTIAL. Driven with base == theirs, every receipt answers the
# same at both sides BY CONSTRUCTION and a 100% count would be a fact about the invocation. The
# same probe ledger is used, so the two silences differ in the REFS and in nothing else.
sbc_nl="$(bash "$CLOSER" "$DIST" "$THEIRS" "$CONS" "$THEIRS" "$SBC_LED" 2>/dev/null)"
sbc_nl_u="$(printf '%s\n' "$sbc_nl" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{c++} END{print c+0}')"
sbc_nl_r="$(printf '%s\n' "$sbc_nl" | awk -F'\t' '$1!="RECEIPTS-UNDECIDED"{c++} END{print c+0}')"
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$sbc_nl_r" -eq 0 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the null-differential run emitted no rows at all, so its silence is an engine that did not run\n' "sbc-silent-null"
elif [ "$sbc_nl_u" -eq 0 ]; then
  printf '  ok    %-22s base == theirs emits no undecided row (control: %s other rows still reported) -- a pull that moved nothing is a different claim, made by saying nothing\n' "sbc-silent-null" "$sbc_nl_r"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s %s undecided row(s) on a NULL differential -- every receipt reads one tree twice, so the count measures the invocation\n' "sbc-silent-null" "$sbc_nl_u"
fi

# --- SEVEN MUTANTS, KEYED ON LOCATION AND SCORED ON BEHAVIOUR ---------------------------------
#
# Each anchors on a line that DECIDES something, never on a spelling of the message: every arm
# above reads a count or a class name, so a mutant that only reworded the row would score no kill
# and a fix that rewords it breaks no arm. The anchors are asserted UNIQUE first, with an
# impossible anchor as the control -- a grep that had silently stopped matching reads as "all
# anchors unique", which is the same zero a clean file produces.
#
# COUNTED AS WHOLE LINES, WHICH IS WHAT THE MUTANT HELPER COMPARES, AND `grep -cF` IS THE WRONG
# ORACLE FOR IT. Two of these eight are the same text at two indents -- the `126|127)` arm exists
# in the base-control resolve and again in the verb dispatch, and the two call sites sit 14 and 12
# spaces in -- so a substring count reads 2 for four of them and the whole battery would be
# refused as non-unique while every mutation in fact applies to exactly one line. Measured while
# building this arm: `grep -cF` said 2/2 where whole-line equality says 1/1.
sbc_anch_bad=""
for a in \
  '  refs_differ || return 0' \
  '    126|127)' \
  "    *'\$BASE'*|*'\${BASE}'*)" \
  "    *'\$THEIRS_TREE'*|*'\${THEIRS_TREE}'*)" \
  '    [ "$_brc" -eq 0 ] && sh_live_undecided=$(( ${sh_live_undecided:-0} + 1 ))' \
  '    *) sh_close_total=$(( ${sh_close_total:-0} + 1 )) ;;' \
  '              sh_base_control "$rest" "$sh_prog" "$sh_rc"' \
  '            sh_base_control "$rest" "$sh_prog" "$sh_rc"' ; do
  n="$(SBC_A="$a" awk '$0 == ENVIRON["SBC_A"] {c++} END{print c+0}' "$CLOSER")" || n=0
  [ "$n" -eq 1 ] || sbc_anch_bad="$sbc_anch_bad [$a -> $n]"
done
sbc_anch_ctl="$(SBC_A='ZZ-NO-SUCH-BASE-CONTROL-ANCHOR' awk '$0 == ENVIRON["SBC_A"] {c++} END{print c+0}' "$CLOSER")" || sbc_anch_ctl=0
ASSERTIONS=$((ASSERTIONS + 1))
if [ -z "$sbc_anch_bad" ] && [ "$sbc_anch_ctl" -eq 0 ]; then
  printf '  ok    %-22s all eight base-control mutation anchors are unique in the engine (control: an impossible anchor returns %s)\n' "sbc-anchors" "$sbc_anch_ctl"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s an anchor is not unique (%s) or the impossible control matched (%s) -- a mutation that edits two sites, or none, scores a kill it did not earn\n' "sbc-anchors" "${sbc_anch_bad:-none}" "$sbc_anch_ctl"
fi

# THE MUTANT IS A WHOLE-DIRECTORY COPY so the engine finds `lib.sh` and `preclassify.sh` beside
# it: a lone copy dies sourcing lib.sh, emits nothing, and "no output" otherwise scores as a kill.
# The replacement line travels through ENVIRON, never through a shell quoting layer, and the
# result is refused unless it (a) differs from the shipped engine and (b) PARSES -- a mutant that
# fails `bash -n` emits nothing on every input and is not a mutant.
sbc_mutant() { # <name> <old-line> <new-line> -> dir on stdout, empty on failure
  local n="$1" d
  d="$SBC/mut-$n"; rm -rf "$d"; mkdir -p "$d"
  cp "$(dirname "$CLOSER")"/*.sh "$d/" 2>/dev/null
  SBC_OLD="$2" SBC_NEW="$3" awk '{ if ($0 == ENVIRON["SBC_OLD"]) print ENVIRON["SBC_NEW"]; else print }' \
    "$CLOSER" > "$d/ledger-reverify.sh" || return 1
  cmp -s "$CLOSER" "$d/ledger-reverify.sh" && return 1
  bash -n "$d/ledger-reverify.sh" 2>/dev/null || return 1
  printf '%s' "$d"
}
# THE KILL IS SCORED ON THE UNDECIDED DETAIL, AND A CONTROL ROW MUST SURVIVE. A mutant that broke
# the engine produces no detail at all, which would otherwise satisfy any arm phrased as an
# absence -- so every kill below demands a specific STRING to be PRESENT or a named verdict row
# to still be there.
sbc_kill() { # <name> <dir> <ledger> <want-substring-in-detail> <must-be-absent-or-empty> <why>
  local n="$1" d="$2" led="$3" want="$4" bad="$5" why="$6" out det ctl
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ -z "$d" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutation DID NOT APPLY (matched nothing, changed nothing, or did not parse) -- the arm it targets is unproven\n' "$n"
    return
  fi
  out="$(bash "$d/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" "$led" 2>/dev/null)"
  ctl="$(printf '%s\n' "$out" | awk -F'\t' '$1=="STILL-LIVE" || $1=="CLOSE-CANDIDATE"{c++} END{print c+0}')"
  det="$(printf '%s\n' "$out" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{print $3; exit}')"
  if [ "$ctl" -eq 0 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant emitted no verdict row at all -- it broke the engine rather than the guard, so its reading is wreckage\n' "$n"
    return
  fi
  if [ -n "$want" ] && { [ -z "$det" ] || [ "${det#*"$want"}" = "$det" ]; }; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the guard was removed and the row does NOT carry "%s" -- that arm cannot fire. Detail: %s\n' "$n" "$want" "${det:-<no row>}"
    return
  fi
  if [ -n "$bad" ] && [ -n "$det" ] && [ "${det#*"$bad"}" != "$det" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant still carries "%s", so the mutation changed nothing the arm reads\n' "$n" "$bad"
    return
  fi
  printf '  ok    %-22s %s\n' "$n" "$why"
}

# M1 -- DROP THE `refs_differ` GUARD. Scored on the NULL-differential ledger, which is the only
# input where the guard decides anything: with it gone, base == theirs produces a row saying
# every receipt is undecided, which is a fact about the invocation wearing the shape of a finding.
sbc_m1="$(sbc_mutant no-refs-guard '  refs_differ || return 0' '  :')"
ASSERTIONS=$((ASSERTIONS + 1))
if [ -z "$sbc_m1" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation DID NOT APPLY, so the null-differential silence is unproven\n' "sbc-mut-refs-guard"
else
  m1_out="$(bash "$sbc_m1/ledger-reverify.sh" "$DIST" "$THEIRS" "$CONS" "$THEIRS" "$SBC_LED" 2>/dev/null)"
  m1_u="$(printf '%s\n' "$m1_out" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{c++} END{print c+0}')"
  m1_r="$(printf '%s\n' "$m1_out" | awk -F'\t' '$1!="RECEIPTS-UNDECIDED"{c++} END{print c+0}')"
  if [ "$m1_r" -eq 0 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant emitted no other rows -- it broke the engine, not the guard\n' "sbc-mut-refs-guard"
  elif [ "$m1_u" -gt 0 ]; then
    printf '  ok    %-22s without refs_differ a NULL differential emits an undecided row (%s) where the shipped engine emits none -- the guard is load-bearing\n' "sbc-mut-refs-guard" "$m1_u"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the guard was removed and base == theirs STILL emitted no row -- the silence arm above cannot fire\n' "sbc-mut-refs-guard"
  fi
fi

# M2 -- COLLAPSE THE THREE-WAY RESOLVE TO TWO, WHICH IS THE FAILS-OPEN CASE. The refusal arm's
# pattern is made unmatchable, so a base control that exited 127 -- one that NEVER RAN -- falls
# through to the decided test and is scored as a measurement.
#
# SCORED ON THE CLOSE CLAUSE, AND THAT IS A MEASUREMENT RATHER THAN A CHOICE. This mutant is
# reachable from ONE direction only. Past the unmatchable arm a 127 reaches
# `[ "$_brc" -eq 0 ]` on the still-live side -- false, so it enters no numerator and that clause
# does not move -- and `[ "$_brc" -ne 0 ]` on the CLOSE side, which 127 satisfies. Built and
# driven both ways on this seed set: keyed on the still-live clause the mutant scores SURVIVED
# (1 of 3, unchanged) and reads exactly like an arm that cannot fire; keyed on the close clause
# it dies, 1 of 3 -> 2 of 3, with the separately-reported refused count gone. The first cut of
# this battery carried only the STILL-LIVE refusal seed and could never have killed it.
sbc_kill sbc-mut-two-way "$(sbc_mutant two-way '    126|127)' '    zz-no-such-status)')" "$SBC_LED" \
  "2 of 3 'verify: sh' CLOSE-CANDIDATE(s) ALSO exited non-zero at BASE" \
  "base control(s) REFUSED" \
  "with the refusal arm unmatchable a control that exited 127 is scored as a measurement on the CLOSE path: 1 of 3 becomes 2 of 3 and the refused count vanishes -- a close attributed to a pull on an evaluation that never happened"

# M3 -- REMOVE THE `\$BASE` EXCLUSION. The rebinding then has a \$BASE-naming receipt compare base
# against base, and it enters the denominator: 1 of 3 becomes 2 of 4, and the row stops naming the
# class it silently swept in.
sbc_kill sbc-mut-no-ex-base "$(sbc_mutant no-ex-base "    *'\$BASE'*|*'\${BASE}'*)" '    zz-no-such-pattern)')" "$SBC_LED" \
  "2 of 4 'verify: sh' receipt(s) reported STILL-LIVE" \
  "naming \$BASE themselves" \
  "without the exclusion the \$BASE-naming receipt enters the denominator AND the numerator (1 of 3 -> 2 of 4) and its exclusion clause is gone"

# M4 -- REMOVE THE \$THEIRS_TREE EXCLUSION. The tree is materialized AT THEIRS and the rebinding
# does not move it, so such a receipt answers SAME by construction and inflates the count with a
# reading that could never have differed.
sbc_kill sbc-mut-no-ex-tree "$(sbc_mutant no-ex-tree "    *'\$THEIRS_TREE'*|*'\${THEIRS_TREE}'*)" '    zz-no-such-pattern)')" "$SBC_LED" \
  "2 of 4 'verify: sh' receipt(s) reported STILL-LIVE" \
  "reading \$THEIRS_TREE" \
  "without the exclusion a receipt reading the theirs-materialized tree answers SAME by construction and inflates the count (1 of 3 -> 2 of 4)"

# M5 -- DROP THE BASE TEST ON THE STILL-LIVE SIDE, so the numerator counts every eligible
# still-live receipt including the one the pull MOVED. The number still looks like a finding,
# which is what makes this mutant worth having.
sbc_kill sbc-mut-no-base-test "$(sbc_mutant no-base-test \
  '    [ "$_brc" -eq 0 ] && sh_live_undecided=$(( ${sh_live_undecided:-0} + 1 ))' \
  '    sh_live_undecided=$(( ${sh_live_undecided:-0} + 1 ))')" "$SBC_LED" \
  "2 of 3 'verify: sh' receipt(s) reported STILL-LIVE" \
  "" \
  "without the base test the MOVER is swept into the numerator (1 of 3 -> 2 of 3) -- a number that still reads like a finding"

# M6 -- REMOVE THE CALL ON THE CLOSE PATH, which is the acquittal the contract names. Everything
# above that line tests the RECEIPT; only this call tests whether the PULL is what changed its
# answer, and the close is the verdict that cannot be taken back. The close clause disappears
# while the still-live clause is byte-unchanged, so the kill is not a general loss of the row.
sbc_kill sbc-mut-no-close-call "$(sbc_mutant no-close-call \
  '            sh_base_control "$rest" "$sh_prog" "$sh_rc"' '            :')" "$SBC_LED" \
  "1 of 3 'verify: sh' receipt(s) reported STILL-LIVE" \
  "CLOSE-CANDIDATE(s) ALSO exited non-zero at BASE" \
  "with the close-path call gone the close clause vanishes while the still-live clause is unchanged -- the direction this file own header calls permanently information-losing"

# M7 -- COUNT EVERY ELIGIBLE RECEIPT AS A STILL-LIVE ONE, so the two denominators stop being
# per-direction populations and become one running total. The still-live denominator reads 5
# instead of 3 and the close clause loses its subject: a denominator whose population is not the
# one the numerator was taken over is a count an operator cannot check.
sbc_kill sbc-mut-one-total "$(sbc_mutant one-total \
  '    *) sh_close_total=$(( ${sh_close_total:-0} + 1 )) ;;' \
  '    *) sh_live_total=$(( ${sh_live_total:-0} + 1 )) ;;')" "$SBC_LED" \
  "1 of 6 'verify: sh' receipt(s) reported STILL-LIVE" \
  "" \
  "folding both directions into one total reads 1 of 6 against a still-live population of 3 -- a denominator taken over a different set than its numerator"

# --- A RECEIPT THAT READS STDIN MUST NOT EAT THE ENTRIES AFTER IT ------------------------------
#
# THE DEFECT. The entry loop is `while … read …; done <<< "$ENTRIES"`, and both `bash -c` sites
# inside it -- the evaluation and `sh_base_rc` -- ran the receipt with fd 0 INHERITED, positioned at
# the next entry. A receipt that reads stdin consumed every entry after its own: those entries
# emitted NO ROW, rc stayed 0 and stderr stayed empty, so a shorter report read as a clean one.
#
# TWO LEDGERS, ONE PER SITE, AND EACH FIRST RECEIPT READS STDIN AT ONE SITE ONLY, so a mutant of
# one redirect cannot be killed by the other site's arm:
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
  o="$(bash "$1" "$DIST" "$BASE" "$CONS" "$THEIRS" "$2" 2>/dev/null)"
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
    printf '  ok    %-22s all three entries report, with their own verdicts, after a receipt that reads stdin at the %s site\n' "stdin-$si" "$si"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s got "%s", want "%s" -- a receipt that reads stdin ate the entries after it, and the report is shorter with rc 0\n' "stdin-$si" "$got" "$SI_WANT"
  fi
done

# THE MUTANTS REMOVE ONE REDIRECT EACH and are scored on BOTH ledgers: the owning ledger must lose
# its later entries while the reader's own row survives (the engine ran), and the OTHER ledger must
# stay whole (the mutant is a mutation of that one site).
si_mut_line_eval='        bash -c "$sh_prog" </dev/null >/dev/null 2>&1'
si_mut_line_base='    bash -c "$1" </dev/null >/dev/null 2>&1'
for si in eval base; do
  case "$si" in
    eval) old="$si_mut_line_eval"; new='        bash -c "$sh_prog" >/dev/null 2>&1'; own="$SI_EVAL_LED"; other="$SI_BASE_LED" ;;
    *)    old="$si_mut_line_base"; new='    bash -c "$1" >/dev/null 2>&1';       own="$SI_BASE_LED"; other="$SI_EVAL_LED" ;;
  esac
  ASSERTIONS=$((ASSERTIONS + 1))
  n="$(SBC_A="$old" awk '$0 == ENVIRON["SBC_A"] {c++} END{print c+0}' "$CLOSER")" || n=0
  d=""; [ "$n" -eq 1 ] && d="$(sbc_mutant "stdin-$si" "$old" "$new")"
  if [ -z "$d" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutation DID NOT APPLY (anchor matched %s lines, want 1) -- the stdin-%s arm is unproven\n' "stdin-mut-$si" "$n" "$si"
    continue
  fi
  m_own="$(si_verdicts "$d/ledger-reverify.sh" "$own")"
  m_other="$(si_verdicts "$d/ledger-reverify.sh" "$other")"
  if [ "${m_own%% *}" != "STILL-LIVE" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant lost the READER row too (%s) -- it broke the engine, so its reading is wreckage\n' "stdin-mut-$si" "$m_own"
  elif [ "$m_own" = "$SI_WANT" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the %s redirect was removed and all three entries still reported -- the stdin-%s arm cannot fire\n' "stdin-mut-$si" "$si" "$si"
  elif [ "$m_other" != "$SI_WANT" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant also moved the OTHER site ledger (%s) -- the two arms are entangled\n' "stdin-mut-$si" "$m_other"
  else
    printf '  ok    %-22s without the %s-site redirect the entries after the reader vanish (%s) while the other ledger is whole\n' "stdin-mut-$si" "$si" "$m_own"
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
row_is "BOLD-ANNOTATION-WITH-A-PREFIX" ABSENT \
  "a real annotation whose bold span opens with words before the marker still closes"
row_is "retained for the record" ABSENT \
  "the copy a withdrawal supersedes carries no marker of its own and must not re-report forever"

# MUTATION — restore the unanchored predicate. The prose entry must vanish, and it must be the
# ONLY thing that changes: an anchor that also drops a real close is a different bug.
#
# RE-ANCHORED ON STRUCTURE, AND IT IS TOKEN-SET-AGNOSTIC BY CONSTRUCTION. This sed used to spell
# the alternation it was editing -- `(ADOPTED UPSTREAM|WITHDRAWN)` -- so the release that added
# `CLOSED AS REJECTED` to this rule took the sed from matching one line to matching zero, and
# `cmp -s` correctly refused to let the no-op pass. A mutation keyed on a SPELLING is worth
# nothing here: the subject is the line-leading ANCHOR and the `<br>`/bold-span structure around
# the token term, not which tokens that term holds. So the token term is captured with `(.*)`
# and written back untouched, and only the anchor and the structure are stripped. The
# post-mutation shape is asserted below rather than assumed, because a capture that matched the
# wrong span would still change the file and still satisfy `cmp -s`.
MUTD="$(dirname "$DIST")/mut-closer"
rm -rf "$MUTD"; mkdir -p "$MUTD"
cp "$(dirname "$CLOSER")"/*.sh "$MUTD/" 2>/dev/null
sed -E 's@^  /\^\[ \\t\]\*\(<br\[ \\t\]\*\\/\?\[ \\t\]\*>\)\?\[ \\t\]\*\(\\\*\\\*\[\^`\]\*\)\?(\(.*\))/ \{ closed=1 \}$@  /\1/ { closed=1 }@' \
  "$CLOSER" > "$MUTD/ledger-reverify.sh"

# THE UNANCHORED FORM IS READ BACK, NOT ASSUMED. `cmp -s` says the file changed; it does not say
# the change is the one this arm needs. A sed whose capture swallowed the wrong span produces a
# different, still-different file, and every verdict below would then be attributed to a mutation
# nobody built. The post-mutation rule must carry the token alternation and must NOT carry the
# `^[ \t]*` anchor that is the subject.
ASSERTIONS=$((ASSERTIONS + 1))
mut_rule="$(grep -E '^  /.*ADOPTED UPSTREAM.*\{ closed=1 \}$' "$MUTD/ledger-reverify.sh")" || mut_rule=""
case "$mut_rule" in
  '  /^'*)  mut_shape="still-anchored" ;;
  '  /('*) mut_shape="ok" ;;
  *)        mut_shape="unrecognised" ;;
esac
if [ "$mut_shape" != ok ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation produced a rule this arm does not recognise (%s): %s\n' "mutation" "$mut_shape" "${mut_rule:-<no close rule at all>}"
elif cmp -s "$CLOSER" "$MUTD/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the anchor assertions above are unproven\n' "mutation"
else
  mut_out="$(bash "$MUTD/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  mut_prose="$(printf '%s\n' "$mut_out" | awk -F'\t' '$2 ~ /PROSE-MENTIONS-THE-VOCABULARY/ {print $1; exit}')"
  mut_bold="$(printf '%s\n' "$mut_out" | awk -F'\t' '$2 ~ /BOLD-ANNOTATION-WITH-A-PREFIX/ {print $1; exit}')"
  if [ -n "$mut_prose" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the unanchored predicate did NOT swallow the prose entry — the assertion above is vacuous\n' "mutation"
  elif [ -n "$mut_bold" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant also un-closed a REAL annotation, so it is not a clean mutation of the anchor alone\n' "mutation"
  else
    printf '  ok    %-22s unanchoring swallows the prose entry and nothing else\n' "mutation"
  fi
fi

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
row_has "PC-FIXTURE-TWO-RECEIPTS" CLOSE-CANDIDATE \
  "receipt 2 of 2 is a real close and must still report"

# The ordinal has to be on the row, or two rows for one entry are unattributable.
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | grep -F 'PC-FIXTURE-TWO-RECEIPTS' | grep -q '\[receipt 1/2\]'; then
  printf '  ok    %-22s rows carry their receipt ordinal\n' "receipt-ordinal"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s two rows for one entry with no ordinal to tell them apart\n' "receipt-ordinal"
fi

# A SINGLE-receipt entry must be byte-unchanged — no ordinal suffix. Otherwise the fix rewrites
# every row in every consumer report to buy a two-entry improvement.
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | grep -F 'Entry A' | grep -q '\[receipt '; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s a single-receipt entry grew an ordinal suffix\n' "single-unchanged"
else
  printf '  ok    %-22s single-receipt rows unchanged (no suffix)\n' "single-unchanged"
fi

# MUTATION — restore the scalar handoff. The still-live half must vanish, and ONLY that.
MUTS="$(dirname "$DIST")/mut-scalar"
rm -rf "$MUTS"; mkdir -p "$MUTS"
cp "$(dirname "$CLOSER")"/*.sh "$MUTS/" 2>/dev/null
awk '
  /^    dn\+\+; dv\[dn\]=directive$/ { next }
  /^      for \(di = 1; di <= dn; di\+\+\)$/ { skip=1; next }
  skip { print "      printf \"%s\\t%s\\t%s\\n\", label, \"1/1\", directive"; skip=0; next }
  { print }
' "$CLOSER" > "$MUTS/ledger-reverify.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTS/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the accumulation assertions are unproven\n' "mutation-scalar"
else
  ms="$(bash "$MUTS/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  ms_live="$(printf '%s\n' "$ms" | awk -F'\t' '$2 ~ /TWO-RECEIPTS/ && $1 == "STILL-LIVE" {c++} END{print c+0}')"
  ms_close="$(printf '%s\n' "$ms" | awk -F'\t' '$2 ~ /TWO-RECEIPTS/ && $1 == "CLOSE-CANDIDATE" {c++} END{print c+0}')"
  if [ "$ms_live" -eq 0 ] && [ "$ms_close" -gt 0 ]; then
    printf '  ok    %-22s the scalar handoff swallows the live receipt and keeps the close\n' "mutation-scalar"
  elif [ "$ms_live" -ne 0 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant still emitted the live receipt, so the assertions above are vacuous\n' "mutation-scalar"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant lost BOTH rows, so it is not a clean mutation of the handoff alone\n' "mutation-scalar"
  fi
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
row_has "PC-FIXTURE-NAMED-BUT-RECEIPT-STUCK" NAMED-UPSTREAM \
  "upstream's history names the id -> the absorption is visible even though the receipt cannot see it"
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
row_has "PC-S901-SHORT-ID-UNIQUE-PREFIX" NAMED-UPSTREAM \
  "upstream cites the SHORT id and one entry carries that prefix -> attributed, though the full slug appears nowhere"

# AND THE NAIVE VERSION OF THAT FIX IS WRONG, WHICH IS WHY BOTH HALVES ARE ASSERTED. Of the 20
# cited prefixes on the reference consumer, 11 were shared by two or more entries. Matching the
# prefix regardless would name every entry the sprint filed.
row_lacks "PC-S902-SHARED-PREFIX-FIRST" NAMED-UPSTREAM \
  "a prefix carried by two entries is NOT attributed to either — a wrong close is worse than the silence it replaces"
row_lacks "PC-S902-SHARED-PREFIX-SECOND" NAMED-UPSTREAM \
  "and not to the other one either — the refusal is symmetric, not first-wins"
row_has "PC-S902" NAMED-UPSTREAM-AMBIGUOUS \
  "the shared prefix is reported ONCE, keyed on the prefix itself, because the prefix is the subject"

# ONE ROW, NOT ONE PER ENTRY. Per-entry emission produced 45 rows from 11 prefixes on the
# reference consumer, all saying the same unresolvable thing — noise added by the fix for a
# signal that was missing, which is the trade the naive prefix-match makes one level along.
# COUNTED PER PREFIX. The seed carries a second shared prefix (PC-S953) for the reach arms below,
# so a count over every AMBIGUOUS row would read 2 and say nothing about repetition.
ambig_n="$(printf '%s\n' "$OUT" | awk -F'\t' '$1=="NAMED-UPSTREAM-AMBIGUOUS" && $2=="PC-S902"{n++} END{print n+0}')"
ASSERTIONS=$((ASSERTIONS+1))
if [ "$ambig_n" = "1" ]; then
  printf '  ok    %-22s exactly one ambiguous row for the two entries sharing PC-S902\n' "ambiguous-collapse"
else
  printf '  FAIL  %-22s %s ambiguous row(s) — the prefix fact is being repeated per entry\n' "ambiguous-collapse" "$ambig_n"
  FAILURES=$((FAILURES+1))
fi

# THE CONTROL, and without it the two arms above only prove the code runs. An id-shaped label
# with a unique prefix that upstream names in NEITHER form must stay silent.
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
row_has   "PC-S950-DOCS-ONLY-NAMING" NAMED-UPSTREAM-DOCS-ONLY \
  "the one naming commit is a docs(plan): commit -> the row stays, under the kind that says it is no absorption"
row_lacks "PC-S950-DOCS-ONLY-NAMING" NAMED-UPSTREAM \
  "and it is never reported as the plain kind a pull session reads as 'upstream took it'"
row_has   "PC-S951-TEMPLATES-ONLY-NAMING" NAMED-UPSTREAM \
  "templates/ is installed on a consumer -> a templates-only commit can be the absorption (a core/-only predicate demotes it)"
row_has   "PC-S952-MERGE-NAMING" NAMED-UPSTREAM \
  "a MERGE whose side branch changed core/ -> listed with -m, so the merge is not scored as touching nothing"
row_has   "PC-S954-RELEASE-COMMIT-NAMING" NAMED-UPSTREAM \
  "the only naming commit is a RELEASE (VERSION + CHANGELOG.md, fix in its parent) -> the plain kind, because that release is what a consumer pulls"
row_lacks "PC-S954-RELEASE-COMMIT-NAMING" NAMED-UPSTREAM-DOCS-ONLY \
  "and never the docs-only kind, whose row would send the operator away from a real absorption"
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
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s FIXTURE BROKEN — PC-S902 is cited by %s commit(s) in the seed, want 2; the list arm has nothing to get wrong\n' "ambiguous-lists-all" "$s902_n"
else
  _miss=0; for _s in $s902_set; do case "$s902_row" in *"$_s"*) ;; *) _miss=$((_miss + 1)) ;; esac; done
  case "$s902_row" in
    *"in 2 commits, ALL of them:"*"and 2 entries in this ledger carry it"*)
      if [ "$_miss" -eq 0 ]; then
        printf '  ok    %-22s PC-S902 names BOTH citing commits and the commit count, and keeps the entry-count phrase ledger-rotate parses\n' "ambiguous-lists-all"
      else
        FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s PC-S902 says two commits but lacks %s of their shas\n' "ambiguous-lists-all" "$_miss"
      fi ;;
    *) FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s PC-S902 row does not name its 2 citing commits and the 2 entries: %s\n' "ambiguous-lists-all" "${s902_row:-<no row>}" ;;
  esac
fi
ASSERTIONS=$((ASSERTIONS + 1))
case "$s953_row|$s902_row" in
  *"NONE of them changes a path under core/ or templates/"*"|"*"NONE of them changes"*)
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s PC-S902 (cited by a core commit) also reads docs-only — the reach is not discriminating\n' "ambiguous-reach" ;;
  *"NONE of them changes a path under core/ or templates/"*"|"*)
    printf '  ok    %-22s PC-S953 (one docs-only citation) says no citing commit changes core/ or templates/; PC-S902 does not\n' "ambiguous-reach" ;;
  *) FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s PC-S953 row does not carry the docs-only reach: %s\n' "ambiguous-reach" "${s953_row:-<no row>}" ;;
esac

# THE MUTANTS, run over a ledger holding only the entries they read, so each costs a fraction of
# a full run. Built in a copy of the whole reconcile directory, guarded with cmp -s, and preceded
# by an UNMUTATED control over the same small ledger that must reproduce every observable.
RCH="$(dirname "$DIST")/reach"; mkdir -p "$RCH"
awk '/^- \*\*PC-S9(02|05|5[0-4])-/ {p=1} /^- \*\*/ && !/^- \*\*PC-S9(02|05|5[0-4])-/ {p=0} p' \
  "$CONS/_bmad-output/ai-dlc-update/push-candidate-ledger.md" > "$RCH/ledger.md"
reach_mut() { # <tag> <awk-anchor-line> <replacement-line> -> path of the mutant, or empty
  local _d="$RCH/$1"; rm -rf "$_d"; mkdir -p "$_d"
  cp "$(dirname "$CLOSER")"/*.sh "$_d/" 2>/dev/null
  A="$2" B="$3" awk '$0 == ENVIRON["A"] { print ENVIRON["B"]; n++; next } { print } END { exit (n == 1) ? 0 : 3 }' \
    "$CLOSER" > "$_d/ledger-reverify.sh" || return 0
  cmp -s "$CLOSER" "$_d/ledger-reverify.sh" || printf '%s' "$_d/ledger-reverify.sh"
}
reach_rows() { bash "$1" "$DIST" "$BASE" "$CONS" "$THEIRS" "$RCH/ledger.md" 2>/dev/null; }
reach_kind() { printf '%s\n' "$1" | awk -F'\t' -v l="$2" '$2 == l && $1 ~ /^NAMED-UPSTREAM(-DOCS-ONLY|-OFF-SUBJECT)?$/ {print $1; exit}'; }
rc_ctl="$(reach_rows "$CLOSER")"
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$(reach_kind "$rc_ctl" PC-S950-DOCS-ONLY-NAMING)" = NAMED-UPSTREAM-DOCS-ONLY ] \
   && [ "$(reach_kind "$rc_ctl" PC-S951-TEMPLATES-ONLY-NAMING)" = NAMED-UPSTREAM ] \
   && [ "$(reach_kind "$rc_ctl" PC-S952-MERGE-NAMING)" = NAMED-UPSTREAM ] \
   && [ "$(reach_kind "$rc_ctl" PC-S954-RELEASE-COMMIT-NAMING)" = NAMED-UPSTREAM ] \
   && grep -q "in 2 commits, ALL of them:" <<<"$rc_ctl"; then
  printf '  ok    %-22s the UNMUTATED engine over the small ledger reproduces S950/S951/S952/S954 and the two-commit S902 row\n' "reach-control"
  # <tag> <anchor> <replacement> <entry> <kind it must take under the mutant> <what it proves>
  reach_case() {
    local _m _r _k
    ASSERTIONS=$((ASSERTIONS + 1))
    _m="$(reach_mut "$1" "$2" "$3")"
    if [ -z "$_m" ]; then FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s the mutation DID NOT APPLY (anchor matched nothing or twice)\n' "mutation-$1"; return; fi
    _r="$(reach_rows "$_m")"; _k="$(reach_kind "$_r" "$4")"
    if [ "$_k" = "$5" ]; then printf '  ok    %-22s %s\n' "mutation-$1" "$6"
    else FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s %s read %s under the mutant, want %s — the arm cannot see it\n' "mutation-$1" "$4" "${_k:-<no row>}" "$5"; fi
  }
  reach_case reach-off "    *) printf 'docs' ;;" "    *) printf 'code' ;;" PC-S950-DOCS-ONLY-NAMING NAMED-UPSTREAM \
    "with no reach predicate the docs-only naming reads NAMED-UPSTREAM again — the defect, reproduced"
  reach_case reach-core-only "templates/\"*) printf 'code' ;;" "zz-never-a-prefix/\"*) printf 'code' ;;" PC-S951-TEMPLATES-ONLY-NAMING NAMED-UPSTREAM-DOCS-ONLY \
    "a core/-only predicate demotes the templates-only absorption, and S951 is what sees it"
  reach_case reach-no-m \
    "  _files=\"\$(printf '%s\\n' \"\$1\" | git -C \"\$DIST\" -c core.quotePath=false log --no-walk --stdin -m --no-renames --name-only --format= 2>/dev/null)\" \\" \
    "  _files=\"\$(printf '%s\\n' \"\$1\" | git -C \"\$DIST\" -c core.quotePath=false log --no-walk --stdin --no-renames --name-only --format= 2>/dev/null)\" \\" \
    PC-S952-MERGE-NAMING NAMED-UPSTREAM-DOCS-ONLY \
    "without -m a merge lists no files and its core/ side branch reads docs-only, and S952 is what sees it"
  # THE VERSION CONJUNCT, and ONLY S954 may see it go. The mutant renames the matched line to one
  # no listing carries, so a release commit falls through to the core/templates test. The same run
  # is then read for S950 and S951: if either moved, the mutant broke more than the conjunct and
  # S954 is not the cell that isolates it.
  ASSERTIONS=$((ASSERTIONS + 1))
  _vm="$(reach_mut reach-no-version 'VERSION' 'zz-never-a-listed-path')"
  if [ -z "$_vm" ]; then
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s the mutation DID NOT APPLY (anchor matched nothing or twice)\n' "mutation-reach-no-version"
  else
    _vr="$(reach_rows "$_vm")"
    _v4="$(reach_kind "$_vr" PC-S954-RELEASE-COMMIT-NAMING)"
    _v0="$(reach_kind "$_vr" PC-S950-DOCS-ONLY-NAMING)"
    _v1="$(reach_kind "$_vr" PC-S951-TEMPLATES-ONLY-NAMING)"
    _v2="$(reach_kind "$_vr" PC-S952-MERGE-NAMING)"
    if [ "$_v4" = NAMED-UPSTREAM-DOCS-ONLY ] && [ "$_v0" = NAMED-UPSTREAM-DOCS-ONLY ] \
       && [ "$_v1" = NAMED-UPSTREAM ] && [ "$_v2" = NAMED-UPSTREAM ]; then
      printf '  ok    %-22s %s\n' "mutation-reach-no-version" "without the VERSION conjunct the release-only naming reads docs-only, S954 is what sees it, and S950/S951/S952 keep their kinds"
    else
      FAILURES=$((FAILURES + 1))
      printf '  FAIL  %-22s want S954 docs-only and S950/S951/S952 unchanged; read S954=%s S950=%s S951=%s S952=%s\n' "mutation-reach-no-version" "${_v4:-<no row>}" "${_v0:-<no row>}" "${_v1:-<no row>}" "${_v2:-<no row>}"
    fi
  fi
  # BL-066's mutant: the newest citing commit only, the shape this row shipped with.
  ASSERTIONS=$((ASSERTIONS + 1))
  _al="  _hits=\"\$(git -C \"\$DIST\" log -E --grep=\"\${_pfx}([^0-9A-Za-z-]|\\\$)\" --format=%h \"\$THEIRS\" 2>/dev/null)\""
  _am="$(reach_mut ambig-newest "$_al" "${_al%)\"} | head -1)\"")"
  if [ -z "$_am" ]; then
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s the mutation DID NOT APPLY, so ambiguous-lists-all is unproven\n' "mutation-ambig-newest"
  else
    _ar="$(reach_rows "$_am" | awk -F'\t' '$1=="NAMED-UPSTREAM-AMBIGUOUS" && $2=="PC-S902" {print $3; exit}')"
    case "$_ar" in
      *"in one commit,"*"and 2 entries in this ledger carry it"*) printf '  ok    %-22s newest-only names one of PC-S902'"'"'s two citing commits, and ambiguous-lists-all is what sees it\n' "mutation-ambig-newest" ;;
      *) FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s the newest-only mutant did not read as one commit: %s\n' "mutation-ambig-newest" "${_ar:-<no row>}" ;;
    esac
  fi
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s FIXTURE BROKEN — the unmutated engine over the small ledger does not reproduce the reach rows, so no mutant below is attributable\n' "reach-control"
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
row_has   "PC-S955-FORM-ONLY-CITATION" NAMED-UPSTREAM-CITED-ONLY \
  "named ONLY on a Not-discharged: line of a core commit -> the citation kind, which is no absorption claim"
row_lacks "PC-S955-FORM-ONLY-CITATION" NAMED-UPSTREAM \
  "and never the plain kind a pull session reads as 'upstream took it' -- the third class this closes"
row_has   "PC-S956-BOTH-FORMS-CITATION" NAMED-UPSTREAM \
  "named in the subject AND on a form line -> the ordinary mention still counts"
row_has   "PC-S957-ORDINARY-X" NAMED-UPSTREAM \
  "discharged in a subject whose commit cites ANOTHER id in the form -> this one is untouched"
row_has   "PC-S957-FORM-Y" NAMED-UPSTREAM-CITED-ONLY \
  "the other id on that same commit, cited only in the form -> the citation kind"
row_has   "PC-S958-FORM-CORE-ORDINARY-DOCS" NAMED-UPSTREAM-DOCS-ONLY \
  "form on a core commit plus an ordinary docs mention -> reach is read over the residue, which is docs-only"
row_has   "PC-S959-INLINE-FORM-CITATION" NAMED-UPSTREAM \
  "the form appears mid-line, not at column 0 -> not a citation, the plain kind"

# THE MUTANTS, over a ledger holding only the six entries, each a copy of the whole reconcile
# directory, each line-anchored (exactly one match, `cmp -s` refuses a no-op), and preceded by an
# UNMUTATED control over the same ledger that must reproduce every kind first.
COD="$(dirname "$DIST")/cited-only"; mkdir -p "$COD"
awk '/^- \*\*PC-S95[5-9]-/ {p=1} /^- \*\*/ && !/^- \*\*PC-S95[5-9]-/ {p=0} p' \
  "$CONS/_bmad-output/ai-dlc-update/push-candidate-ledger.md" > "$COD/ledger.md"
co_mut() { # <tag> <exact line> <replacement line> -> path of the mutant, or empty
  local _d="$COD/$1"; rm -rf "$_d"; mkdir -p "$_d"
  cp "$(dirname "$CLOSER")"/*.sh "$_d/" 2>/dev/null
  A="$2" B="$3" awk '$0 == ENVIRON["A"] { print ENVIRON["B"]; n++; next } { print } END { exit (n == 1) ? 0 : 3 }' \
    "$CLOSER" > "$_d/ledger-reverify.sh" || return 0
  bash -n "$_d/ledger-reverify.sh" 2>/dev/null || return 0
  cmp -s "$CLOSER" "$_d/ledger-reverify.sh" || printf '%s' "$_d/ledger-reverify.sh"
}
co_rows() { bash "$1" "$DIST" "$BASE" "$CONS" "$THEIRS" "$COD/ledger.md" 2>/dev/null; }
co_kind() { printf '%s\n' "$1" | awk -F'\t' -v l="$2" '$2 == l && $1 ~ /^NAMED-UPSTREAM(-DOCS-ONLY|-CITED-ONLY|-OFF-SUBJECT)?$/ {print $1; exit}'; }
CO_IDS="PC-S955-FORM-ONLY-CITATION PC-S956-BOTH-FORMS-CITATION PC-S957-ORDINARY-X PC-S957-FORM-Y PC-S958-FORM-CORE-ORDINARY-DOCS PC-S959-INLINE-FORM-CITATION"
CO_WANT="NAMED-UPSTREAM-CITED-ONLY NAMED-UPSTREAM NAMED-UPSTREAM NAMED-UPSTREAM-CITED-ONLY NAMED-UPSTREAM-DOCS-ONLY NAMED-UPSTREAM"
co_read() { # <rows> -> "id=kind ..." for the six ids
  local _i _s=""
  for _i in $CO_IDS; do _s="$_s $_i=$(co_kind "$1" "$_i")"; done
  printf '%s' "${_s# }"
}
co_expect() { # <id> -> the kind the UNMUTATED engine must give it
  local _i _k _w="$CO_WANT"
  for _i in $CO_IDS; do _k="${_w%% *}"; _w="${_w#* }"; [ "$_i" = "$1" ] && { printf '%s' "$_k"; return; }; done
}
co_ctl="$(co_rows "$CLOSER")"
co_ctl_read="$(co_read "$co_ctl")"
co_ctl_want=""; for _i in $CO_IDS; do co_ctl_want="$co_ctl_want $_i=$(co_expect "$_i")"; done; co_ctl_want="${co_ctl_want# }"
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$co_ctl_read" = "$co_ctl_want" ]; then
  printf '  ok    %-22s the UNMUTATED engine over the six-entry ledger reproduces every S955-S959 kind\n' "cited-control"
  # <tag> <anchor> <replacement> <cell that must move> <kind it must take> <cells that must hold> <why>
  co_case() {
    local _m _r _k _h _bad=""
    ASSERTIONS=$((ASSERTIONS + 1))
    _m="$(co_mut "$1" "$2" "$3")"
    if [ -z "$_m" ]; then FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s the mutation DID NOT APPLY (anchor matched nothing or twice, or the mutant does not parse)\n' "mutation-$1"; return; fi
    _r="$(co_rows "$_m")"; _k="$(co_kind "$_r" "$4")"
    for _h in $6; do [ "$(co_kind "$_r" "$_h")" = "$(co_expect "$_h")" ] || _bad="$_bad $_h=$(co_kind "$_r" "$_h")"; done
    if [ "$_k" = "$5" ] && [ -z "$_bad" ]; then printf '  ok    %-22s %s\n' "mutation-$1" "$7"
    else FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s %s read %s under the mutant (want %s); cells that should hold but moved:%s\n' "mutation-$1" "$4" "${_k:-<no row>}" "$5" "${_bad:- none}"; fi
  }
  co_case filter-off \
    '  [ -n "$1" ] || return 0' \
    '  printf '"'"'%s\n'"'"' "$1"; return 0' \
    PC-S955-FORM-ONLY-CITATION NAMED-UPSTREAM "PC-S956-BOTH-FORMS-CITATION PC-S957-ORDINARY-X PC-S959-INLINE-FORM-CITATION" \
    "with no filter the form-only citation reads NAMED-UPSTREAM again -- the third class, reproduced, and S955 is what sees it"
  co_case filter-any-form-line \
    '    $0 ~ /^Not-discharged: PC-S[0-9]+(-[A-Z0-9]+)*$/ { next }' \
    '    $0 ~ /^Not-discharged: PC-S[0-9]+(-[A-Z0-9]+)*$/ && ((p == "" && index($0, n)) || (p != "" && $0 ~ re)) { h = ""; next }' \
    PC-S956-BOTH-FORMS-CITATION NAMED-UPSTREAM-CITED-ONLY "PC-S955-FORM-ONLY-CITATION PC-S957-ORDINARY-X PC-S957-FORM-Y PC-S958-FORM-CORE-ORDINARY-DOCS PC-S959-INLINE-FORM-CITATION" \
    "dropping any commit that carries a form line for the id demotes a commit that ALSO names it ordinarily, and S956 is what sees it"
  co_case filter-unanchored \
    '    $0 ~ /^Not-discharged: PC-S[0-9]+(-[A-Z0-9]+)*$/ { next }' \
    '    $0 ~ /Not-discharged: PC-S[0-9]+(-[A-Z0-9]+)*/ { next }' \
    PC-S959-INLINE-FORM-CITATION NAMED-UPSTREAM-CITED-ONLY "PC-S955-FORM-ONLY-CITATION PC-S956-BOTH-FORMS-CITATION PC-S957-ORDINARY-X PC-S957-FORM-Y PC-S958-FORM-CORE-ORDINARY-DOCS" \
    "an unanchored strip eats a mid-line mention and demotes it to a citation, and S959 is what sees it"
  co_case reach-unfiltered \
    '  printf '"'"'%s %s %s %s'"'"' "$_how" "${_n:-1}" "$_list" "$(named_reach "$_hits")"' \
    '  printf '"'"'%s %s %s %s'"'"' "$_how" "${_n:-1}" "$_list" "$(named_reach "$_all")"' \
    PC-S958-FORM-CORE-ORDINARY-DOCS NAMED-UPSTREAM "PC-S955-FORM-ONLY-CITATION PC-S956-BOTH-FORMS-CITATION PC-S957-ORDINARY-X PC-S957-FORM-Y PC-S959-INLINE-FORM-CITATION" \
    "reach read over the whole set lets the form-only core commit lift a docs-only naming to the plain kind, and S958 is what sees it"
  co_case cited-only-no-row \
    '    printf '"'"'%s %s %s cited'"'"' "$_how" "${_n:-1}" "$(printf '"'"'%s\n'"'"' "$_all" | tr '"'"'\n'"'"' '"'"','"'"' | sed '"'"'s/,$//'"'"')"; return 0' \
    '    return 0' \
    PC-S955-FORM-ONLY-CITATION "" "PC-S956-BOTH-FORMS-CITATION PC-S957-ORDINARY-X PC-S958-FORM-CORE-ORDINARY-DOCS PC-S959-INLINE-FORM-CITATION" \
    "a filter that deletes the row instead of qualifying it loses the citation, and S955 is what sees it (want no row)"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s FIXTURE BROKEN — the unmutated engine over the six-entry ledger read {%s}, want {%s}; no mutant below is attributable\n' "cited-control" "$co_ctl_read" "$co_ctl_want"
fi

# --- THE FAIL-OPEN PATH. When the filter's own git call fails, the naming set must come back
# UNFILTERED -- the row this engine produced before the form existed -- never empty, which would
# turn a tool error into a CITED-ONLY row. Forced with a `git` shim on PATH that refuses only the
# filter's `--no-walk=unsorted` call and leaves a sentinel, so the cell can prove the failure
# happened. Under the shim S955 must read the PRE-FILTER kind, NAMED-UPSTREAM.
CO_SHIM="$COD/shim"; rm -rf "$CO_SHIM"; mkdir -p "$CO_SHIM"
CO_REALGIT="$(command -v git)"
printf '#!/bin/sh\nfor a in "$@"; do case "$a" in --no-walk=unsorted) : > "%s/fired"; exit 128 ;; esac; done\nexec "%s" "$@"\n' \
  "$CO_SHIM" "$CO_REALGIT" > "$CO_SHIM/git"
chmod +x "$CO_SHIM/git"
co_failopen() { # <engine> -> S955's kind with the filter's git call failing, or BROKEN
  rm -f "$CO_SHIM/fired"
  local _r
  _r="$(PATH="$CO_SHIM:$PATH" bash "$1" "$DIST" "$BASE" "$CONS" "$THEIRS" "$COD/ledger.md" 2>/dev/null)"
  [ -f "$CO_SHIM/fired" ] || { printf 'BROKEN'; return; }
  co_kind "$_r" PC-S955-FORM-ONLY-CITATION
}
ASSERTIONS=$((ASSERTIONS + 1))
co_fo="$(co_failopen "$CLOSER")"
if [ "$co_fo" = NAMED-UPSTREAM ]; then
  printf '  ok    %-22s with the filter'"'"'s git call failing, S955 reads the pre-filter NAMED-UPSTREAM -- a tool error is never a CITED-ONLY row\n' "cited-fail-open"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s with the filter'"'"'s git call failing S955 read %s, want NAMED-UPSTREAM (BROKEN = the shim never fired)\n' "cited-fail-open" "${co_fo:-<no row>}"
fi
ASSERTIONS=$((ASSERTIONS + 1))
co_fom="$(co_mut fail-closed \
  '    END { flush() }'"'"')" || { printf '"'"'%s\n'"'"' "$1"; return 0; }' \
  '    END { flush() }'"'"')" || { return 0; }')"
if [ -z "$co_fom" ]; then
  FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s the mutation DID NOT APPLY, so cited-fail-open is unproven\n' "mutation-fail-closed"
else
  co_fok="$(co_failopen "$co_fom")"
  if [ "$co_fok" = NAMED-UPSTREAM-CITED-ONLY ]; then
    printf '  ok    %-22s a fallback returning EMPTY turns the git failure into a CITED-ONLY row, and cited-fail-open is what sees it\n' "mutation-fail-closed"
  else
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s under the fail-closed mutant S955 read %s, want NAMED-UPSTREAM-CITED-ONLY\n' "mutation-fail-closed" "${co_fok:-<no row>}"
  fi
fi

# --- THE BOOTSTRAPPING CELL. `ledger-reverify.sh` is read by the ENGINE THE CONSUMER LAST INSTALLED:
# `lib.sh`'s `ledger_close_awk_pattern` lifts the close rule out of this file by structure, and the
# pull that delivers this file runs the previous release's lib.sh against it. That extractor must
# still find EXACTLY ONE rule here and lift a non-empty pattern that awk compiles, or apply and
# rotation refuse on the pull that carries the fix. Driven through the shipped lib.sh, sourced in a
# subshell with SELF pointed at a copy of this directory.
ASSERTIONS=$((ASSERTIONS + 1))
CO_BOOT="$COD/boot"; rm -rf "$CO_BOOT"; mkdir -p "$CO_BOOT"
cp "$(dirname "$CLOSER")"/*.sh "$CO_BOOT/" 2>/dev/null
co_pat="$( SELF="$CO_BOOT"; . "$CO_BOOT/lib.sh" >/dev/null 2>&1; ledger_close_awk_pattern 2>/dev/null )"; co_prc=$?
co_fn="$( SELF="$CO_BOOT"; . "$CO_BOOT/lib.sh" >/dev/null 2>&1; ledger_close_awk 2>/dev/null )" || co_fn=""
co_np="$(printf '%s\n' "$co_pat" | grep -c .)" || co_np=0
if [ "$co_prc" = 0 ] && [ "$co_np" = 1 ] && [ -n "$co_fn" ] \
   && printf '**ADOPTED UPSTREAM (v1.0.0, verified x)**\nplain\n' | awk "$co_fn"' { if (ledger_body_closes($0)) c++ } END { exit (c == 1) ? 0 : 1 }'; then
  printf '  ok    %-22s the shipped lib.sh extractor lifts exactly one close rule from this ledger-reverify.sh, and it compiles and closes one of two probe lines\n' "boot-close-extract"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s ledger_close_awk_pattern over this ledger-reverify.sh: rc=%s lines=%s fn=%s -- the previous engine would refuse the pull that delivers it\n' "boot-close-extract" "$co_prc" "$co_np" "${co_fn:+present}"
fi
} # end lr_unit_cited_only
lr_unit_off_subject() {
# --- THE OFF-SUBJECT KIND (BL-145's third class, cells S960-S970) ------------------------------
# A naming set that reaches code (core/, templates/, or a release) but changes NONE of the entry's
# own `theirs_has|theirs_lacks` receipt paths reads NAMED-UPSTREAM-OFF-SUBJECT; a naming commit
# that changes VERSION is judged over its RELEASE SPAN (previous VERSION change, exclusive, up to
# the commit). Every other shape keeps the kind it had before `named_subject` existed.
#
# ITS OWN WORLD, NOT THE SHARED SEED. Every shard pays the shared seed, its sub-ledgers are cut by
# PC-S9 prefix regexes and PC-S902's commit count is asserted, so these cells live in a dist this
# unit builds under the run's temp root and a ledger holding only them. Each mutant then costs one
# run over eleven entries. The cells, each the subject of one mutant:
#
#   S960  third class: a core commit names it and changes another file   -> OFF-SUBJECT  (subject-off)
#   S961  squash release: one commit changes the subject AND VERSION     -> NAMED-UPSTREAM (subject-inverted)
#   S962  branch release: an unnamed parent fixes the subject, the naming
#         child changes only CHANGELOG.md and VERSION                     -> NAMED-UPSTREAM (span-off)
#   S963  merge-shaped release: the fix arrives on the second parent and
#         the merge commit itself changes VERSION                          -> NAMED-UPSTREAM (hold)
#   S964  over-expansion: a release, then an unnamed commit touching the
#         subject, then a NON-release naming commit touching other core   -> OFF-SUBJECT  (span-expand-all)
#   S965  two receipt paths, only the SECOND touched                       -> NAMED-UPSTREAM (first-path-only)
#   S966  consumer-layout receipt path whose dist file is touched          -> NAMED-UPSTREAM
#   S967  consumer-layout receipt path whose dist file is untouched        -> OFF-SUBJECT, and the row
#         names BOTH the written path and the dist path it resolved to
#   S968  an ambiguous-basename path beside a resolvable untouched one     -> old kind (unresolvable-dropped)
#   S969  untouched subject, the subject listing FAILS under a git shim   -> old kind (listing-fail-new-kind)
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
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s FIXTURE BROKEN -- the off-subject world could not be built\n' "off-subject-seed"
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
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s FIXTURE BROKEN -- the release shapes are wrong (S962 branch release, S963 merge release)\n' "off-subject-seed"
  return 0
fi
printf '  ok    %-22s the world carries a branch-shaped release (S962) and a merge that changes VERSION (S963)\n' "off-subject-seed"
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
os_rows() { bash "$1" "$OSD" "$OSB" "$CONS" "$OST" "$OSW/ledger.md" 2>/dev/null; }
os_kind() { printf '%s\n' "$1" | awk -F'\t' -v l="$2" '$2 == l && $1 ~ /^NAMED-UPSTREAM(-DOCS-ONLY|-CITED-ONLY|-OFF-SUBJECT)?$/ {print $1; exit}'; }
OS_IDS="PC-S960-THIRD-CLASS PC-S961-SQUASH-RELEASE PC-S962-BRANCH-RELEASE PC-S963-MERGE-RELEASE PC-S964-OVER-EXPANSION PC-S965-TWO-PATHS-SECOND-TOUCHED PC-S966-CONSUMER-PATH-TOUCHED PC-S967-CONSUMER-PATH-UNTOUCHED PC-S968-AMBIGUOUS-BASENAME PC-S969-LISTING-FAILURE PC-S970-MANUAL-RECEIPT"
OS_WANT="NAMED-UPSTREAM-OFF-SUBJECT NAMED-UPSTREAM NAMED-UPSTREAM NAMED-UPSTREAM NAMED-UPSTREAM-OFF-SUBJECT NAMED-UPSTREAM NAMED-UPSTREAM NAMED-UPSTREAM-OFF-SUBJECT NAMED-UPSTREAM NAMED-UPSTREAM-OFF-SUBJECT NAMED-UPSTREAM"
os_expect() { # <id> -> the kind the UNMUTATED engine must give it
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
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the shipped engine over the S960-S970 world read {%s}, want {%s}; no mutant below is attributable\n' "off-subject-control" "$os_ctl_read" "$os_ctl_want"
  return 0
fi
printf '  ok    %-22s the shipped engine reproduces every S960-S970 kind: third class, over-expansion, untouched consumer path and listing cell OFF-SUBJECT; squash, branch and merge releases, second-path, touched consumer path, ambiguous basename and manual NAMED-UPSTREAM\n' "off-subject-control"
# THE ROW TEXT NAMES THE SUBJECT, and a basename-resolved one by BOTH spellings.
os_det() { printf '%s\n' "$os_ctl" | awk -F'\t' -v l="$1" '$1 == "NAMED-UPSTREAM-OFF-SUBJECT" && $2 == l {print $3; exit}'; }
ASSERTIONS=$((ASSERTIONS + 1))
case "$(os_det PC-S967-CONSUMER-PATH-UNTOUCHED)" in
  *"scripts/ai-dlc/os-cl2.sh resolved by basename to core/scripts/os-cl2.sh"*)
    printf '  ok    %-22s S967 names the receipt'"'"'s consumer-layout spelling AND the dist path it resolved to\n' "off-subject-basename" ;;
  *) FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s S967 does not name both scripts/ai-dlc/os-cl2.sh and core/scripts/os-cl2.sh: %s\n' "off-subject-basename" "$(os_det PC-S967-CONSUMER-PATH-UNTOUCHED | cut -c1-200)" ;;
esac
ASSERTIONS=$((ASSERTIONS + 1))
case "$(os_det PC-S960-THIRD-CLASS)" in
  *"resolved by basename"*) FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s S960 says its path was basename-resolved, but it is present at theirs as written\n' "off-subject-path" ;;
  *"core/scripts/os-third.sh"*) printf '  ok    %-22s S960 names its receipt path as written and claims no basename resolution\n' "off-subject-path" ;;
  *) FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s S960 does not name core/scripts/os-third.sh: %s\n' "off-subject-path" "$(os_det PC-S960-THIRD-CLASS | cut -c1-200)" ;;
esac
# THE LISTING FAILURE CELL: a git shim refuses ONLY the per-commit subject listing (`--no-walk`
# with `-m` and without `--stdin`; `named_reach` passes `--stdin`, so reach stays `code`) and leaves
# a sentinel. No sentinel is BROKEN, never a verdict.
OS_SHIM="$OSW/shim"; mkdir -p "$OS_SHIM"
printf '#!/bin/sh\nnw=0; m=0; st=0\nfor a in "$@"; do case "$a" in --no-walk) nw=1 ;; -m) m=1 ;; --stdin) st=1 ;; esac; done\nif [ "$nw" = 1 ] && [ "$m" = 1 ] && [ "$st" = 0 ]; then : > "%s/fired"; exit 128; fi\nexec "%s" "$@"\n' \
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
  printf '  ok    %-22s with the subject listing failing, S969 keeps the old kind NAMED-UPSTREAM -- a git error is never an OFF-SUBJECT row\n' "off-subject-listfail"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s with the subject listing failing S969 read %s, want NAMED-UPSTREAM (BROKEN = the shim never fired)\n' "off-subject-listfail" "${os_lfk:-<no row>}"
fi
# THE MUTANTS: a copy of the whole reconcile directory, each anchor matched EXACTLY once (two
# anchors for a two-line swap), `bash -n` clean and byte-different, or the arm is FIXTURE BROKEN.
os_mut() { # <tag> <old> <new> [<old2> <new2>] -> path of the mutant, or empty
  local _d="$OSW/$1"; rm -rf "$_d"; mkdir -p "$_d"
  cp "$(dirname "$CLOSER")"/*.sh "$_d/" 2>/dev/null
  [ -f "$_d/lib.sh" ] || return 0
  A1="$2" B1="$3" A2="${4:-}" B2="${5:-}" awk '
    $0 == ENVIRON["A1"] { print ENVIRON["B1"]; n1++; next }
    ENVIRON["A2"] != "" && $0 == ENVIRON["A2"] { print ENVIRON["B2"]; n2++; next }
    { print }
    END { exit (n1 == 1 && (ENVIRON["A2"] == "" || n2 == 1)) ? 0 : 3 }' "$CLOSER" > "$_d/ledger-reverify.sh" || return 0
  bash -n "$_d/ledger-reverify.sh" 2>/dev/null || return 0
  cmp -s "$CLOSER" "$_d/ledger-reverify.sh" || printf '%s' "$_d/ledger-reverify.sh"
}
# <tag> <killing cell> <kind under the mutant> <cells that must hold> <why> <old> <new> [<old2> <new2>]
os_case() {
  local _m _r _k _h _bad=""
  ASSERTIONS=$((ASSERTIONS + 1))
  _m="$(os_mut "$1" "$6" "$7" "${8:-}" "${9:-}")"
  if [ -z "$_m" ]; then FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s FIXTURE BROKEN -- the mutation DID NOT APPLY (anchor matched nothing or twice, or the mutant does not parse)\n' "mutation-$1"; return; fi
  _r="$(os_rows "$_m")"; _k="$(os_kind "$_r" "$2")"
  for _h in $4; do [ "$(os_kind "$_r" "$_h")" = "$(os_expect "$_h")" ] || _bad="$_bad $_h=$(os_kind "$_r" "$_h")"; done
  if [ "$_k" = "$3" ] && [ -z "$_bad" ]; then printf '  ok    %-22s %s\n' "mutation-$1" "$5"
  else FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s %s read %s under the mutant (want %s); cells that should hold but moved:%s\n' "mutation-$1" "$2" "${_k:-<no row>}" "$3" "${_bad:- none}"; fi
}
os_case subject-off PC-S960-THIRD-CLASS NAMED-UPSTREAM \
  "PC-S961-SQUASH-RELEASE PC-S962-BRANCH-RELEASE PC-S963-MERGE-RELEASE PC-S965-TWO-PATHS-SECOND-TOUCHED PC-S966-CONSUMER-PATH-TOUCHED PC-S968-AMBIGUOUS-BASENAME PC-S970-MANUAL-RECEIPT" \
  "with no off state the third class reads NAMED-UPSTREAM again -- the defect, reproduced, and S960 is what sees it" \
  '  NS_STATE=off' '  NS_STATE=old'
os_case subject-inverted PC-S961-SQUASH-RELEASE NAMED-UPSTREAM-OFF-SUBJECT \
  "PC-S968-AMBIGUOUS-BASENAME PC-S970-MANUAL-RECEIPT" \
  "with the touched test inverted the genuine squash release reads OFF-SUBJECT, and S961 is what sees it" \
  '      0) NS_STATE=touched; return 0 ;;' '      0) : ;;' \
  '      1) : ;;' '      1) NS_STATE=touched; return 0 ;;'
os_case span-off PC-S962-BRANCH-RELEASE NAMED-UPSTREAM-OFF-SUBJECT \
  "PC-S960-THIRD-CLASS PC-S961-SQUASH-RELEASE PC-S963-MERGE-RELEASE PC-S964-OVER-EXPANSION PC-S965-TWO-PATHS-SECOND-TOUCHED PC-S966-CONSUMER-PATH-TOUCHED PC-S967-CONSUMER-PATH-UNTOUCHED PC-S968-AMBIGUOUS-BASENAME PC-S969-LISTING-FAILURE PC-S970-MANUAL-RECEIPT" \
  "without the release span the branch-shaped release (fix in an unnamed parent) reads OFF-SUBJECT, S962 is what sees it, and the squash and merge releases hold" \
  '    if [ "$_st" -eq 0 ]; then' '    if false; then'
os_case span-expand-all PC-S964-OVER-EXPANSION NAMED-UPSTREAM \
  "PC-S960-THIRD-CLASS PC-S961-SQUASH-RELEASE PC-S962-BRANCH-RELEASE PC-S963-MERGE-RELEASE PC-S965-TWO-PATHS-SECOND-TOUCHED PC-S966-CONSUMER-PATH-TOUCHED PC-S967-CONSUMER-PATH-UNTOUCHED PC-S968-AMBIGUOUS-BASENAME PC-S969-LISTING-FAILURE PC-S970-MANUAL-RECEIPT" \
  "expanding a NON-release naming commit over the span credits it with an unnamed neighbour's change, and S964 is what sees it" \
  '    if [ "$_st" -eq 0 ]; then' '    if true; then'
os_case first-path-only PC-S965-TWO-PATHS-SECOND-TOUCHED NAMED-UPSTREAM-OFF-SUBJECT \
  "PC-S960-THIRD-CLASS PC-S961-SQUASH-RELEASE PC-S962-BRANCH-RELEASE PC-S963-MERGE-RELEASE PC-S964-OVER-EXPANSION PC-S966-CONSUMER-PATH-TOUCHED PC-S967-CONSUMER-PATH-UNTOUCHED PC-S969-LISTING-FAILURE PC-S970-MANUAL-RECEIPT" \
  "a subject set holding only the first receipt path misses the touched second one, and S965 is what sees it" \
  "  LR_L=\"\$_label\" LC_ALL=C awk -F'\\t' '\$1 == ENVIRON[\"LR_L\"] { printf \"\\001%s\\n\", \$2 }' \\" \
  "  LR_L=\"\$_label\" LC_ALL=C awk -F'\\t' '\$1 == ENVIRON[\"LR_L\"] { printf \"\\001%s\\n\", \$2; exit }' \\"
os_case unresolvable-dropped PC-S968-AMBIGUOUS-BASENAME NAMED-UPSTREAM-OFF-SUBJECT \
  "PC-S960-THIRD-CLASS PC-S961-SQUASH-RELEASE PC-S962-BRANCH-RELEASE PC-S963-MERGE-RELEASE PC-S964-OVER-EXPANSION PC-S965-TWO-PATHS-SECOND-TOUCHED PC-S966-CONSUMER-PATH-TOUCHED PC-S967-CONSUMER-PATH-UNTOUCHED PC-S969-LISTING-FAILURE PC-S970-MANUAL-RECEIPT" \
  "dropping the unresolvable path and testing the rest demotes the entry on the path that happened to resolve, and S968 is what sees it" \
  '      [ "$_nm" -eq 1 ] || return 0' '      [ "$_nm" -eq 1 ] || continue'
# listing-fail-new-kind is scored under the shim, on S969 alone.
ASSERTIONS=$((ASSERTIONS + 1))
os_lfm="$(os_mut listing-fail-new-kind \
  '      > "$LR_STAGE/ns-files" 2>/dev/null || { NS_STATE=old; return 0; }' \
  '      > "$LR_STAGE/ns-files" 2>/dev/null || { NS_STATE=off; return 0; }')"
if [ -z "$os_lfm" ]; then
  FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s FIXTURE BROKEN -- the mutation DID NOT APPLY, so off-subject-listfail is unproven\n' "mutation-listing-fail-new-kind"
else
  os_lfmk="$(os_lf "$os_lfm")"
  if [ "$os_lfmk" = NAMED-UPSTREAM-OFF-SUBJECT ]; then
    printf '  ok    %-22s a listing failure answered with the new kind turns a git error into an OFF-SUBJECT row, and off-subject-listfail is what sees it\n' "mutation-listing-fail-new-kind"
  else
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s under the mutant and the shim S969 read %s, want NAMED-UPSTREAM-OFF-SUBJECT (BROKEN = the shim never fired)\n' "mutation-listing-fail-new-kind" "${os_lfmk:-<no row>}"
  fi
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
    o="$(AI_DLC_RECONCILE_MEMO="$m" bash "$1" "$w/d" "$(cat "$w/B")" "$w/c" "$(cat "$w/T")" "$w/c/ledger.md" 2>"$w/err")"; rc=$?
    printf '%s\n%s' "$rc" "$o"
  }
  u_row() { printf '%s\n' "$1" | awk -F'\t' -v l="$2" 'NR > 1 && $2 == l {print $1 "|" $3; exit}'; }
  u_unread() { case "$(u_row "$1" "$2")" in NEEDS-REVIEW\|unreadable:*) return 0 ;; esac; return 1; }
  for _w in blob tree cached base ver; do u_world "$_w"; done
  # Healthy control on an untouched world: every entry decides as before, nothing reads unreadable.
  u_world healthy; U_H="$(u_run "$CLOSER" healthy)"
  ASSERTIONS=$((ASSERTIONS + 1))
  case "$(u_row "$U_H" "Entry U-HAS")|$(u_row "$U_H" "Entry U-KEEP")|$(u_row "$U_H" "Entry U-NEW")|$(u_row "$U_H" "Entry U-NOWHERE")" in
    STILL-LIVE*"|NEEDS-REVIEW|vacuous predicate:"*"|STILL-LIVE"*"|NEEDS-REVIEW|unresolved:"*)
      if grep -q 'unreadable' <<<"$U_H"; then FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s the HEALTHY world reads unreadable somewhere — the refusal fires on readable objects\n' "unreadable-control"
      else printf '  ok    %-22s healthy world: has STILL-LIVE, keep vacuous, new-at-theirs STILL-LIVE, nowhere unresolved, no unreadable row\n' "unreadable-control"; fi ;;
    *) FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s FIXTURE BROKEN — the healthy world does not decide as seeded: %s\n' "unreadable-control" "$(printf '%s\n' "$U_H" | cut -f1,2 | tr '\n' ' ')" ;;
  esac
  # Break each world, ONCE, and keep it broken: the mutants below re-read the same worlds.
  mv "$(u_obj blob T top.txt)" "$UW/blob/moved" \
    && mv "$(u_obj tree T a/b)" "$UW/tree/moved" \
    && { U_MEMO="$UW/cached/m/primed"; mkdir -p "$U_MEMO"
         AI_DLC_RECONCILE_MEMO="$U_MEMO" bash -c '. "$1/lib.sh" >/dev/null 2>&1 && memo_has_path "$2" "$3" top.txt' _ \
           "$(dirname "$CLOSER")" "$UW/cached/d" "$(cat "$UW/cached/T")"; } \
    && mv "$(u_obj cached T top.txt)" "$UW/cached/moved" \
    && mv "$(u_obj base B keep.txt)" "$UW/base/moved" \
    && mv "$(u_obj ver T VERSION)" "$UW/ver/moved" \
    || { FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s FIXTURE BROKEN — an object could not be moved aside, so no unreadable world exists\n' "unreadable-worlds"; }
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
    printf '  ok    %-22s missing blob, missing subtree, unread blob behind a cached has, unread base blob, unread VERSION: all refused (%s)\n' "unreadable-refused" "$U_S"
  else
    FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s want R R R R R (blob tree cached base ver), got %s\n' "unreadable-refused" "$U_S"
  fi
  # Near-miss in a BROKEN world: the new-at-theirs path and the path that resolves nowhere still
  # decide as in the healthy world, so the refusal is keyed on unreadability, not on any failure.
  _bw="$(u_run "$CLOSER" base)"
  ASSERTIONS=$((ASSERTIONS + 1))
  case "$(u_row "$_bw" "Entry U-NEW")|$(u_row "$_bw" "Entry U-NOWHERE")" in
    STILL-LIVE*"|NEEDS-REVIEW|unresolved:"*) printf '  ok    %-22s beside an unreadable base blob, a path new at theirs and a path that resolves nowhere decide as before\n' "unreadable-near-miss" ;;
    *) FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s the near-misses moved in the broken world: %s\n' "unreadable-near-miss" "$(u_row "$_bw" "Entry U-NEW") / $(u_row "$_bw" "Entry U-NOWHERE")" ;;
  esac
  # ONE MUTANT PER LAYER. Each must move ITS world's letter and no other.
  # <tag> <anchor> <replacement> <expected score>
  u_mut() {
    local _d="$UW/mut-$1" _s
    ASSERTIONS=$((ASSERTIONS + 1))
    rm -rf "$_d"; mkdir -p "$_d"; cp "$(dirname "$CLOSER")"/*.sh "$_d/" 2>/dev/null
    A="$2" B="$3" awk '$0 == ENVIRON["A"] { print ENVIRON["B"]; n++; next } { print } END { exit (n == 1) ? 0 : 3 }' \
      "$CLOSER" > "$_d/ledger-reverify.sh"
    if [ "$?" -ne 0 ] || cmp -s "$CLOSER" "$_d/ledger-reverify.sh"; then
      FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s the mutation DID NOT APPLY, so its layer is unproven\n' "mutation-$1"; return
    fi
    _s="$(u_score "$_d/ledger-reverify.sh")"
    if [ "$_s" = "$4" ]; then printf '  ok    %-22s %s (%s)\n' "mutation-$1" "$5" "$_s"
    else FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s want %s, got %s — the layer is not what its world sees\n' "mutation-$1" "$4" "$_s"; fi
  }
  u_mut unread-has '      if [ "$_hp" -eq 125 ]; then' '      if [ "$_hp" -eq 9999 ]; then' "R NEEDS-REVIEW R R R" \
    "with the has-layer refusal gone a missing subtree is a path that does not resolve"
  u_mut unread-show '      if [ "$_ts" -ne 0 ]; then' '      if false; then' "R R CLOSE-CANDIDATE R R" \
    "with the theirs show status discarded an unread blob is empty content and theirs_has reads a CLOSE"
  u_mut unread-base '        if [ "$_bh" -ne 128 ]; then' '        if false; then' "R R R CLOSE-CANDIDATE R" \
    "with the base refusal gone an unread base blob is 'absent at base' and a vacuous theirs_lacks reads a CLOSE"
  u_mut unread-version '  if [ "$_tv_h" -ne 128 ] && git -C "$DIST" rev-parse -q --verify "${THEIRS}^{commit}" >/dev/null 2>&1; then' '  if false; then' "R R R R rc0" \
    "with the VERSION refusal gone the run reports versions read off nothing, exit 0"
fi

# MUTATION 2 — drop the id-shape guard. Entry A's prose label then matches the pre-base commit
# that quotes it, and a wall of word-matched rows is exactly the lint an operator switches off.
#
# BOTH LAYERS GO. The guard is two conditions — the label contains only [A-Z0-9-], and it
# contains at least one hyphen — and stripping either alone leaves the other still rejecting a
# prose label. The first draft of this mutant removed only the charset arm, came out green, and
# was therefore proving the layer it had left in place rather than the guard.
MUTG="$(dirname "$DIST")/mut-guard"
rm -rf "$MUTG"; mkdir -p "$MUTG"
cp "$(dirname "$CLOSER")"/*.sh "$MUTG/" 2>/dev/null
sed -e '/not id-shaped: prose label/d' -e '/a single word is not an id/d' \
  "$CLOSER" > "$MUTG/ledger-reverify.sh"

ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTG/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the id-shape guard assertion is unproven\n' "mutation-guard"
else
  mg_out="$(bash "$MUTG/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  if printf '%s\n' "$mg_out" | awk -F'\t' '$2 ~ /Entry A/ && $1 == "NAMED-UPSTREAM" {f=1} END{exit !f}'; then
    printf '  ok    %-22s without the guard a prose label word-matches — the guard is load-bearing\n' "mutation-guard"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s guardless closer did NOT match the prose label, so row_lacks above is vacuous\n' "mutation-guard"
  fi
fi

# MUTATION 3 — re-bound the search to BASE..THEIRS. The naming commit is before base, so the
# row disappears: the unbounded search is the whole reason the signal survives past its pull.
MUTB="$(dirname "$DIST")/mut-bound"
rm -rf "$MUTB"; mkdir -p "$MUTB"
cp "$(dirname "$CLOSER")"/*.sh "$MUTB/" 2>/dev/null
# EVERY SEARCH, and KEYED ON THE THING BEING BOUNDED rather than on the grep expression.
# `named_absorbed` falls back to the SHORT id when the full slug finds nothing, `named_ambiguous`
# asks the same two questions again, and each is its own `git log`. Bounding only some of them is a
# PARTIAL revert, which proves the layer left in place and comes out looking like a surviving
# mutant — the failure mode this arm's predecessor actually hit.
#
# THE EARLIER FORM MATCHED ON `--grep="$_pfx"` AND A FIX TO THE GREP EXPRESSION SILENTLY DODGED IT.
# When the prefix searches were anchored (`-E --grep="${_pfx}([^0-9A-Za-z-]|\$)"`), the sed pattern
# stopped matching, the prefix arms stayed unbounded in the mutant, and this arm reported a
# surviving named row. It failed LOUDLY, which is why the mutant is keyed on the REF ARGUMENT of
# a `--format=` search — the ref IS what bounding changes, it is identical at every search site,
# and it does not move when a grep expression is rewritten. `git log -S` at :269 is already
# range-bounded and carries no bare `"$THEIRS"`, so it is untouched.
#
# AND THE FORMAT LETTER IS NOT PART OF THE ANCHOR, WHICH IS A SECOND INSTANCE OF THE SAME LESSON.
# The pattern was `--format=%H "$THEIRS"` spelled out. When `named_absorbed`'s two searches moved
# to `--format=%h` — because the function now emits abbreviated shas directly instead of walking
# them through `rev-parse --short` — the sed stopped matching THOSE TWO lines while still matching
# `named_ambiguous`'s. `MUTB_LEFT` counted the same spelling, so it read 0 and the guard passed:
# a HALF-bounded mutant, reported by this arm as six surviving named rows. The class is the one
# the paragraph above already names, caught a second time by its own leftover-count guard. `%[hH]`
# is what the site means — a `git log` asking for shas at the tip — and the leftover count is now
# keyed the same way, so the two cannot drift apart.
sed -E -e 's@(--format=%[hH]) "\$THEIRS"@\1 "\$\{BASE\}\.\.\$\{THEIRS\}"@g' \
  "$CLOSER" > "$MUTB/ledger-reverify.sh"
# The mutation must have hit EVERY search, or a partial revert reads as a surviving mutant again.
MUTB_HITS="$(LC_ALL=C grep -c -E -- '--format=%[hH] "\$\{BASE\}\.\.\$\{THEIRS\}"' "$MUTB/ledger-reverify.sh" || true)"
MUTB_LEFT="$(LC_ALL=C grep -c -E -- '--format=%[hH] "\$THEIRS"' "$MUTB/ledger-reverify.sh" || true)"

ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTB/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the unbounded-search assertion is unproven\n' "mutation-bound"
elif [ "${MUTB_LEFT:-1}" -ne 0 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s %s search(es) left UNBOUNDED by the mutation (%s bounded) — a partial revert proves the layer left in place\n' \
    "mutation-bound" "$MUTB_LEFT" "${MUTB_HITS:-0}"
else
  mb_out="$(bash "$MUTB/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  mb_named="$(printf '%s\n' "$mb_out" | awk -F'\t' '$1 == "NAMED-UPSTREAM" {c++} END{print c+0}')"
  mb_still="$(printf '%s\n' "$mb_out" | awk -F'\t' '$2 ~ /PC-FIXTURE-NAMED-BUT-RECEIPT-STUCK/ && $1 == "STILL-LIVE" {f=1} END{print f+0}')"
  if [ "$mb_named" -ne 0 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s bounding to base..theirs still found %s named row(s) — the assertions above are vacuous\n' "mutation-bound" "$mb_named"
  elif [ "$mb_still" -ne 1 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant also lost the receipt verdict, so it is not a clean mutation of the search bound alone\n' "mutation-bound"
  else
    printf '  ok    %-22s bounding the search loses the pre-base absorption and nothing else\n' "mutation-bound"
  fi
fi

# THE UNMUTATED CONTROL. Both mutants are copies into a fresh directory; if a copy cannot even
# source lib.sh it emits nothing, and "no rows" would otherwise score as a kill for BOTH of the
# assertions above. This copy is byte-identical to the detector, so it must behave identically.
ASSERTIONS=$((ASSERTIONS + 1))
CTLD="$(dirname "$DIST")/ctl-closer"
rm -rf "$CTLD"; mkdir -p "$CTLD"
cp "$(dirname "$CLOSER")"/*.sh "$CTLD/" 2>/dev/null
cp "$CLOSER" "$CTLD/ledger-reverify.sh"
ctl_named="$(bash "$CTLD/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1 | awk -F'\t' '$1 == "NAMED-UPSTREAM" {c++} END{print c+0}')"
# COMPARED TO THE IN-PLACE RUN, NOT TO A LITERAL, and with a FLOOR beside it. The literal was 3
# and it went stale the moment the seed grew the PC-S904/905/906 trio below; a hand-written total
# in a control is a number that decays silently and then reads as a real kill. Equality is the
# property being asserted — a byte-identical copy must agree with the detector in place — and the
# floor is what stops two silences agreeing.
own_named="$(printf '%s\n' "$OUT" | awk -F'\t' '$1 == "NAMED-UPSTREAM" {c++} END{print c+0}')"
if [ "$ctl_named" -eq "$own_named" ] && [ "$own_named" -ge 3 ]; then
  printf '  ok    %-22s unmutated copy in the same directory emits the same %s named rows (harness is sound)\n' "mutation-control" "$own_named"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s unmutated copy emitted %s named rows against %s in place (want equal, and >= 3) — a copy that cannot run scores as a kill\n' "mutation-control" "$ctl_named" "$own_named"
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
# BOTH NAMING KINDS CARRY THE SHA LIST, so both are read. Once a naming set that changes nothing
# under core/ or templates/ became `NAMED-UPSTREAM-DOCS-ONLY`, an election mutant that keeps only a
# docs commit flips the KIND as well as the list; reading NAMED-UPSTREAM alone then scored that
# mutant NOROW and lost the sha it kept, which is the observable these arms grade.
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
# Does this id's row carry this sha? Used to say WHICH sha a mutant kept, so two mutants that
# both drop one sha are scored on different observables instead of on the same one.
named_has_sha() { case "$(named_detail "$1" "$2")" in *"$3"*) return 0 ;; *) return 1 ;; esac; }

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
s906_new="$(printf '%s\n' "$s906_shas" | sed -n '1p')"
s906_old="$(printf '%s\n' "$s906_shas" | sed -n '2p')"
# NO PIPE INTO `grep -q`. `git show --name-only` is fed into a command substitution and matched
# with `case`, per this repo's standing rule about a reader that leaves before the writer has
# finished; the output is small here, and the point is that the shape is correct anywhere.
s904_touched() { case "$(git -C "$DIST" show --format= --name-only "$1" 2>/dev/null)" in
    *core/scripts/s904-subject.sh*) return 0 ;; *) return 1 ;; esac; }
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$s904_n" -ne 3 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s %s commit(s) name %s, want 3 — below three there is no middle commit, and the two forms are the same string\n' "named-seed-shape" "$s904_n" "$s904_id"
elif s904_touched "$s904_new" || s904_touched "$s904_old"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s an END of the range is the absorbing commit, so electing the two ends would have been RIGHT here and the arm below tests nothing\n' "named-seed-shape"
elif ! s904_touched "$s904_mid"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the MIDDLE commit %s did not touch core/scripts/s904-subject.sh, so no commit in this range absorbed the entry\n' "named-seed-shape" "${s904_mid:-<none>}"
else
  printf '  ok    %-22s 3 commits name PC-S904; the MIDDLE one (%s) absorbed it and NEITHER end (%s newest, %s oldest) did\n' "named-seed-shape" "$s904_mid" "$s904_new" "$s904_old"
fi

# THE ARM. Every sha that names an id must appear in that id's row. The offender and BOTH
# near-misses are read out of the SAME `$OUT`: PC-S904 at n=3 with one commit the two ends cannot
# reach, PC-S906 at n=2 where the two ends ARE the whole set, and PC-S905 at n=1. The three carry
# byte-identical receipts and emit two rows each, so the run is the same size whichever is being
# read — an implementation that branches on `n > 1` and never reads a sha treats PC-S904 and
# PC-S906 identically and cannot pass this. Held in one arm on purpose: each mutant below is then
# a single failure rather than three entangled ones.
ASSERTIONS=$((ASSERTIONS + 1))
m904="$(named_missing "$OUT" "$s904_id")"
m905="$(named_missing "$OUT" "$s905_id")"
m906="$(named_missing "$OUT" "$s906_id")"
if [ "$m904" = NOROW ] || [ "$m905" = NOROW ] || [ "$m906" = NOROW ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s a NAMED-UPSTREAM row is MISSING (904=%s 905=%s 906=%s) — a row that never appeared hides nothing and reports nothing, so this arm cannot discriminate\n' "named-lists-all" "$m904" "$m905" "$m906"
elif [ "$m904" -eq 0 ] && [ "$m905" -eq 0 ] && [ "$m906" -eq 0 ]; then
  printf '  ok    %-22s every naming sha is on its row — 3 for PC-S904 (the middle one included), 2 for PC-S906, 1 for PC-S905\n' "named-lists-all"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s naming shas ABSENT from their rows: PC-S904 %s of 3, PC-S906 %s of 2, PC-S905 %s of 1. A commit the row does not name is a commit the operator never reads\n' "named-lists-all" "$m904" "$m906" "$m905"
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
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s a row states no commit count at all (904=[%s] 905=[%s] 906=[%s]) — without one the operator cannot tell a complete list from a truncated one\n' "named-count-agrees" "$c904" "$c905" "$c906"
elif [ "$c904" = "3" ] && [ "$c906" = "2" ] && [ "$c905" = "1" ]; then
  printf '  ok    %-22s the stated counts are 3 / 2 / 1 and each matches the number of shas the row carries\n' "named-count-agrees"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s stated counts 904=%s 906=%s 905=%s against derived 3 / 2 / 1 — the row is telling the operator to read a different number of commits than it names\n' "named-count-agrees" "$c904" "$c906" "$c905"
fi

# --- FOUR MUTANTS, ALL ANCHORED ON THE SLUG SEARCH --------------------------------------------
# KEYED ON LOCATION, NOT ON A SPELLING, and on the ONE line that decides which commits exist as
# far as this row is concerned. Everything downstream — the count, the list, the branch, the
# sentence — is a rendering of that line's output, so a mutant here cannot be dodged by rewording
# the row, and it survives the row being reworded. Each is a PIPELINE spliced into that line, so
# each states its election as a behaviour rather than as a form of words.
#
# THE ANCHOR IS RESOLVED OUT OF THE FILE, NOT SPELLED OUT HERE, and that is a measurement rather
# than a preference. The first draft of this block spelled the line
# `--format=%H "$THEIRS"`; the detector then moved its two `named_absorbed` searches to
# `--format=%h` — same query, abbreviated shas asked of git instead of walked through
# `rev-parse --short` — and all three mutants below stopped applying in the same run. `cmp -s`
# caught it, which is the guard working, but a mutant that stops mutating on a REWORDING is a
# mutant keyed on a spelling, and this file's own `mutation-bound` arm was carrying the identical
# defect twenty lines up. So the line is located by what it IS — the assignment of `_hits` from a
# fixed-string `git log --grep` on the entry's own id — and whatever bytes that line currently
# holds are the anchor.
#
# THE PATTERN SEPARATES THREE NEARLY IDENTICAL LINES. `named_ambiguous` runs the same query and
# assigns it to `_slug_hit`; the prefix fallback in this same function assigns `_hits` from an
# `-E` search on the SHORT id. The assignment target and `-F --grep="$_id"` together pick exactly
# one, and the arm below asserts that it picked exactly one before any mutant is built.
NAMED_ANCHOR="$(LC_ALL=C awk '/^  _hits="\$\(git .*log -F --grep="\$_id"/' "$CLOSER")"
anchor_n="$(printf '%s\n' "$NAMED_ANCHOR" | grep -c . )"
ASSERTIONS=$((ASSERTIONS + 1))
# AND IT MUST END IN `)"`, because the three mutants below splice a pipeline in just before that
# close. Asserted rather than assumed: a line ending some other way would be truncated by two
# characters and every mutant would be a syntax error, which emits nothing — and "no rows" is
# what a kill looks like.
case "$NAMED_ANCHOR" in *')"') anchor_tail=ok ;; *) anchor_tail=no ;; esac
if [ "$anchor_n" -eq 1 ] && [ "$anchor_tail" = ok ]; then
  printf '  ok    %-22s the slug search resolves to exactly one line, ending in )" as the mutants require: %s\n' "named-anchor-unique" "$(printf '%s' "$NAMED_ANCHOR" | sed 's/^  //')"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the slug search resolved to %s line(s) (want 1) with a spliceable tail=%s — the three mutants below would edit the wrong site, or nothing at all\n' "named-anchor-unique" "$anchor_n" "$anchor_tail"
fi

# $1 tag, $2 a pipeline spliced into the resolved line just inside its closing `)"` -> prints the
# mutant's output on stdout, or nothing if the mutation did not apply. The caller checks the empty
# case, and `cmp -s` is what makes a substitution that matched nothing fail rather than pass.
named_mutant() {
  local _tag="$1" _pipe="$2" _d
  _d="$(dirname "$DIST")/mut-named-$_tag"
  rm -rf "$_d"; mkdir -p "$_d"
  cp "$(dirname "$CLOSER")"/*.sh "$_d/" 2>/dev/null
  awk -v anchor="$NAMED_ANCHOR" -v pipe="$_pipe" '
    $0 == anchor { print substr($0, 1, length($0) - 2) " " pipe ")\""; next }
    { print }' "$CLOSER" > "$_d/ledger-reverify.sh"
  cmp -s "$CLOSER" "$_d/ledger-reverify.sh" && return 1
  bash "$_d/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1
}

# MUTANT A — `| head -1`, the newest-only election. PC-S906 must lose its OLDER sha and KEEP its
# newest; PC-S905 must be untouched, or the mutant blinded the search rather than truncating it.
ASSERTIONS=$((ASSERTIONS + 1))
ma_out="$(named_mutant head '| head -1')" || ma_out=""
if [ -z "$ma_out" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation did not apply, or the mutant emitted nothing — either way the list assertion is unproven\n' "mutation-named-head"
elif [ "$(named_missing "$ma_out" "$s905_id")" != "0" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutant also dropped the single-commit id PC-S905, so it broke the search instead of truncating it\n' "mutation-named-head"
elif [ "$(named_missing "$ma_out" "$s906_id")" = "1" ] && named_has_sha "$ma_out" "$s906_id" "$s906_new" ; then
  printf '  ok    %-22s newest-only: PC-S906 keeps %s and loses %s, PC-S905 unmoved — the arm sees a dropped sha\n' "mutation-named-head" "$s906_new" "$s906_old"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s newest-only left PC-S906 missing %s sha(s) and newest-present=%s (want 1 and yes) — named-lists-all cannot see an election\n' \
    "mutation-named-head" "$(named_missing "$ma_out" "$s906_id")" "$(named_has_sha "$ma_out" "$s906_id" "$s906_new" && echo yes || echo no)"
fi

# MUTANT B — `| tail -1`, the OLDEST-only election, which is the shape this code actually shipped.
# Scored on the OPPOSITE observable to mutant A: the sha PC-S906 keeps must be its OLDEST. Without
# that half the two mutants would be graded on one fact and one of them would be proving nothing.
ASSERTIONS=$((ASSERTIONS + 1))
mb2_out="$(named_mutant tail '| tail -1')" || mb2_out=""
if [ -z "$mb2_out" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation did not apply, or the mutant emitted nothing — the oldest-only election is unproven\n' "mutation-named-tail"
elif [ "$(named_missing "$mb2_out" "$s905_id")" != "0" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutant also dropped the single-commit id PC-S905, so it broke the search instead of truncating it\n' "mutation-named-tail"
elif [ "$(named_missing "$mb2_out" "$s906_id")" = "1" ] && named_has_sha "$mb2_out" "$s906_id" "$s906_old" ; then
  printf '  ok    %-22s oldest-only (the shipped defect): PC-S906 keeps %s and loses %s, PC-S905 unmoved\n' "mutation-named-tail" "$s906_old" "$s906_new"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s oldest-only left PC-S906 missing %s sha(s) and oldest-present=%s (want 1 and yes)\n' \
    "mutation-named-tail" "$(named_missing "$mb2_out" "$s906_id")" "$(named_has_sha "$mb2_out" "$s906_id" "$s906_old" && echo yes || echo no)"
fi

# MUTANT C — `| head -2`, which is THE TWO-ENDS DEFECT ITSELF wearing a different hat: it reports
# two commits for an id that has three and says nothing about the third. It is the only one of the
# three the NEAR-MISS cannot see — PC-S906 has exactly two naming commits, so its row is
# byte-unchanged — and that asymmetry is the point. An arm satisfiable by the n=2 case alone would
# score this mutant green, and the whole reason PC-S904 is in the seed is that at n=3 a truncation
# to two becomes visible at all.
ASSERTIONS=$((ASSERTIONS + 1))
mc2_out="$(named_mutant maxcount '| head -2')" || mc2_out=""
if [ -z "$mc2_out" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation did not apply, or the mutant emitted nothing — the n>2 case is unproven\n' "mutation-named-maxcount"
elif [ "$(named_missing "$mc2_out" "$s906_id")" != "0" ] || [ "$(named_missing "$mc2_out" "$s905_id")" != "0" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s truncating at two also moved PC-S906 (%s missing) or PC-S905 (%s missing) — it is not a clean mutation of the n>2 case alone\n' \
    "mutation-named-maxcount" "$(named_missing "$mc2_out" "$s906_id")" "$(named_missing "$mc2_out" "$s905_id")"
elif [ "$(named_missing "$mc2_out" "$s904_id")" = "1" ] && ! named_has_sha "$mc2_out" "$s904_id" "$s904_old" ; then
  printf '  ok    %-22s truncating at two loses PC-S904'"'"'s oldest naming commit %s while PC-S906 and PC-S905 do not move — only n>2 can see this\n' "mutation-named-maxcount" "$s904_old"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s PC-S904 lost %s sha(s) under a two-commit truncation (want 1, and it must be the oldest %s) — the n>2 half of the arm is vacuous\n' \
    "mutation-named-maxcount" "$(named_missing "$mc2_out" "$s904_id")" "$s904_old"
fi

# MUTANT D — `| sed -n '1p;$p'`, WHICH IS THE DEFECT ITSELF. Keeping only the first and last line
# of the match set is exactly what "newest X and oldest Y" reported, expressed as a behaviour on
# the search rather than as a form of words in the row, so this mutant survives every future
# rewording of the sentence. It is the case the whole block exists for: the sha it hides is the
# MIDDLE one, which is the commit that actually absorbed the entry, and PC-S906 and PC-S905 are
# byte-unchanged because at n <= 2 the two ends ARE the whole set.
#
# THIS IS THE ONE MUTANT THE NEAR-MISS ALONE COULD NEVER KILL. Run against PC-S906 by itself it
# changes nothing at all — which is what makes PC-S904's presence in the same ledger, at the same
# receipt and in the same run, the thing being tested rather than a decoration.
ASSERTIONS=$((ASSERTIONS + 1))
md2_out="$(named_mutant twoends "| sed -n '1p;\$p'")" || md2_out=""
if [ -z "$md2_out" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation did not apply, or the mutant emitted nothing — the two-ends election is unproven and this arm has never been shown to fire\n' "mutation-named-twoends"
elif [ "$(named_missing "$md2_out" "$s906_id")" != "0" ] || [ "$(named_missing "$md2_out" "$s905_id")" != "0" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s electing the two ends also moved PC-S906 (%s missing) or PC-S905 (%s missing), where the ends ARE the whole set — the mutant broke the search rather than electing\n' \
    "mutation-named-twoends" "$(named_missing "$md2_out" "$s906_id")" "$(named_missing "$md2_out" "$s905_id")"
elif [ "$(named_missing "$md2_out" "$s904_id")" = "1" ] && ! named_has_sha "$md2_out" "$s904_id" "$s904_mid" \
     && named_has_sha "$md2_out" "$s904_id" "$s904_new" && named_has_sha "$md2_out" "$s904_id" "$s904_old" ; then
  printf '  ok    %-22s the two-ends election hides exactly the ABSORBING commit %s while advertising the withdrawal %s and the handoff %s — PC-S906 and PC-S905 do not move\n' "mutation-named-twoends" "$s904_mid" "$s904_new" "$s904_old"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s PC-S904 lost %s sha(s) under the two-ends election and middle-present=%s (want 1 missing, and it must be the middle %s) — the arm is not watching the commit that did the work\n' \
    "mutation-named-twoends" "$(named_missing "$md2_out" "$s904_id")" "$(named_has_sha "$md2_out" "$s904_id" "$s904_mid" && echo yes || echo no)" "$s904_mid"
fi

# NO TWO OF THE FOUR MUTANTS MAY PRODUCE THE SAME OUTPUT. Two mutants with byte-identical output
# are one mutant counted twice, and the second one proves nothing while reading as extra coverage.
# `| head -2` and `| sed -n '1p;$p'` differ ONLY at n > 2 and would have collapsed into one here if
# PC-S904 were not in the seed; `| head -1` and `| tail -1` differ only in WHICH sha survives. The
# unmutated control is compared too: a mutant that agrees with it did not mutate anything
# observable.
# THE UNMUTATED SIDE IS `$OUT` ITSELF, not a fourth invocation. The three mutants are copies of
# the detector run against this same seed with the same four arguments, so `$OUT` is exactly what
# each of them would have printed had its `sed` matched nothing — which is the comparison being
# made, and it costs no extra run of the subject.
ASSERTIONS=$((ASSERTIONS + 1))
mdist_ctl="$OUT"
mdist_dupe=""
[ "$ma_out"  = "$mb2_out"   ] && mdist_dupe="${mdist_dupe} head=tail"
[ "$ma_out"  = "$mc2_out"   ] && mdist_dupe="${mdist_dupe} head=head2"
[ "$ma_out"  = "$md2_out"   ] && mdist_dupe="${mdist_dupe} head=twoends"
[ "$mb2_out" = "$mc2_out"   ] && mdist_dupe="${mdist_dupe} tail=head2"
[ "$mb2_out" = "$md2_out"   ] && mdist_dupe="${mdist_dupe} tail=twoends"
[ "$mc2_out" = "$md2_out"   ] && mdist_dupe="${mdist_dupe} head2=twoends"
[ "$ma_out"  = "$mdist_ctl" ] && mdist_dupe="${mdist_dupe} head=unmutated"
[ "$mb2_out" = "$mdist_ctl" ] && mdist_dupe="${mdist_dupe} tail=unmutated"
[ "$mc2_out" = "$mdist_ctl" ] && mdist_dupe="${mdist_dupe} head2=unmutated"
[ "$md2_out" = "$mdist_ctl" ] && mdist_dupe="${mdist_dupe} twoends=unmutated"
if [ -z "$mdist_ctl" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the unmutated control emitted nothing, so "every mutant differs from it" is satisfied by wreckage\n' "named-mutants-distinct"
elif [ -z "$mdist_dupe" ]; then
  printf '  ok    %-22s the four mutants and the unmutated control produce five different outputs\n' "named-mutants-distinct"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s byte-identical output between:%s — a duplicated mutant reads as coverage and is not\n' "named-mutants-distinct" "$mdist_dupe"
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
  printf '  ok    %-22s names the entry it truncated, and that it captured the receipt\n' "swallowed-names-entry"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s reported a swallow without naming the entry that went silent\n' "swallowed-names-entry"
fi

# THE CONTROL SET, and both must be able to fail. Without them the assertion above is satisfied
# by a detector that flags every entry, or every entry carrying a colon anywhere.
row_lacks "PC-FIXTURE-COLON-CONTROL" ENTRY-SWALLOWED \
  "a normal entry in the same section stays silent"
row_lacks "a-real-entry.sh" ENTRY-SWALLOWED \
  "a PROSE-titled entry legitimately carrying a receipt stays silent — the measured 6-of-7 false-positive class"

# MUTATION — drop the colon discriminator. The prose-titled control must then be reported,
# which is the exact false-positive set that killed the earlier predicate. Nothing else changes.
#
# RE-ANCHORED, AND THE OLD ANCHOR'S DEATH IS THE POINT. The arm used to key on
# `label ~ /:$/ && !idshape(label)`, one conjunction inside a single `if`. The colon test is
# now a BRANCH SELECTOR — `if (label ~ /:$/)` picks the colon row and `else if (…)` picks the
# capture row — so the old anchor matched nothing and this arm went red rather than quiet.
# That is the `cmp -s` guard working exactly as designed and it is deliberately kept: the
# alternative reading of a vanished anchor is a mutation that silently stops mutating, which
# reads identically to a discriminator that is load-bearing.
MUTC="$(dirname "$DIST")/mut-colon"
rm -rf "$MUTC"; mkdir -p "$MUTC"
cp "$(dirname "$CLOSER")"/*.sh "$MUTC/" 2>/dev/null
sed 's@if (label ~ /:\$/)@if (1)@' "$CLOSER" > "$MUTC/ledger-reverify.sh"

ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTC/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the colon discriminator is unproven\n' "mutation-colon"
else
  mc_out="$(bash "$MUTC/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  # BOTH HALVES. Without the second the arm scores a kill for a mutant that broke the whole
  # ENTRY-SWALLOWED block — an emitter that died prints no prose row either, and "no row for
  # a-real-entry" would then read as the colon test doing its job.
  mc_fp="$(printf '%s\n' "$mc_out" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $2 ~ /a-real-entry/{f=1} END{print f+0}')"
  mc_tp="$(printf '%s\n' "$mc_out" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $2 ~ /The derivation/{f=1} END{print f+0}')"
  if [ "$mc_fp" = 1 ] && [ "$mc_tp" = 1 ]; then
    printf '  ok    %-22s without the colon test a prose-titled entry is falsely reported — it is load-bearing\n' "mutation-colon"
  elif [ "$mc_tp" != 1 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant lost the genuine colon row too, so it is not a clean mutation of the colon test alone\n' "mutation-colon"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s dropping the colon test did NOT re-fire the prose entry, so the control above is vacuous\n' "mutation-colon"
  fi
fi

} # end lr_unit_entry_swallowed
lr_unit_no_colon_swallow() {
# --- BL-013: THE NO-COLON SWALLOW, WHICH THE COLON SIGNAL CANNOT SEE ----------------------
# The colon gate fires ZERO times on every corpus available — the reference consumer's live
# ledger and archive, and both distribution backlog files — while those same corpora carry
# annotation bullets that really are swallowing entries. An annotation whose bold span does
# NOT end in a colon truncates the entry above it exactly as a colon one does, captures its
# receipt, and produced no row anywhere until the second signal existed.
row_has "False CLOSE-CANDIDATE" ENTRY-SWALLOWED \
  "a NO-COLON annotation that captured a receipt is REPORTED — the colon signal is blind to this one"

ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $2 ~ /False CLOSE-CANDIDATE/ && $3 ~ /PC-FIXTURE-NO-COLON-SWALLOWED/{f=1} END{exit !f}'; then
  printf '  ok    %-22s names the entry that went dark, so the operator has a subject and not just a complaint\n' "no-colon-names-entry"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s reported the no-colon swallow without naming PC-FIXTURE-NO-COLON-SWALLOWED\n' "no-colon-names-entry"
  printf '%s\n' "$OUT" | awk -F'\t' '$1=="ENTRY-SWALLOWED"' | sed 's/^/          | /'
fi

# AND IT MUST DISCRIMINATE, or the arm above is satisfied by a detector that reports every
# non-id bullet carrying a receipt. Predicate (2) ALONE — a receipt under a non-id label —
# reports 11 rows on the reference consumer's live ledger; the conjunction reports 1. These
# three are the classes the conjunction subtracts, and each is a REAL entry.
row_lacks "Second no-colon prose bullet" ENTRY-SWALLOWED \
  "the entry above emitted its OWN row (its receipt sits ABOVE the annotation) — nothing was lost, so nothing is reported"
row_lacks "legacy-entry.sh" ENTRY-SWALLOWED \
  "a real id-less entry below a CLOSED one stays silent: a closed entry emits no row BY DESIGN, so 'no row above' is true of every entry that follows a close"
row_lacks "PC-FIXTURE-ID_WITH.PUNCT-AT-0.242.0" ENTRY-SWALLOWED \
  "an id carrying '_' and '.' is an ID, not an annotation — the two shapes the reference consumer really files"

# ...and that last one is a REAL entry, so it must still report its own verdict. A silence
# bought by the entry disappearing from the classifier is not the silence being asserted.
row_is "PC-FIXTURE-ID_WITH.PUNCT-AT-0.242.0" STILL-LIVE \
  "and it is classified normally — the id rule keeps it visible rather than merely unreported"

# MUTATION — the ID RULE'S ANCHOR. `idshape()` required `^[A-Z0-9-]+$`: a FULL-STRING match
# that admits neither `_` nor `.`. Restoring it makes a real entry read as an annotation and
# the capture arm fires on it.
#
# THE MUTATION IS ON THE ANCHOR, NOT ON THE CHARACTER CLASS, AND THAT IS A MEASUREMENT AND NOT
# A PREFERENCE. `ledger_entry_id()` is a PREFIX match, so narrowing its class back to
# `[A-Z0-9-]` still matches `PC-S330-PREPUSH-LEAKS-GIT` and still returns non-empty — the id
# verdict does not move. Measured over 349 boundary lines in the reference consumer's live
# ledger and archive, its degradation ledger and both distribution backlog files: reverting
# the class alone changes ZERO verdicts, while reverting to the anchored old rule changes 3.
# A class-only mutant would have survived, and a surviving mutant reads exactly like an arm
# that cannot fire.
MUTI="$(dirname "$DIST")/mut-idrule"
rm -rf "$MUTI"; mkdir -p "$MUTI"
cp "$(dirname "$CLOSER")"/*.sh "$MUTI/" 2>/dev/null
sed 's@if (match(label, /\^`?(PC|BL)-\[A-Za-z0-9_\.-\]+/))@if (match(label, /^[A-Z0-9-]+$/))@' \
  "$(dirname "$CLOSER")/lib.sh" > "$MUTI/lib.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$(dirname "$CLOSER")/lib.sh" "$MUTI/lib.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing in lib.sh, so the id rule is unproven\n' "mutation-idrule"
else
  mi_out="$(bash "$MUTI/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  mi_hit="$(printf '%s\n' "$mi_out" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $2 ~ /PC-FIXTURE-ID_WITH.PUNCT/{f=1} END{print f+0}')"
  mi_ctl="$(printf '%s\n' "$mi_out" | awk -F'\t' '$2 ~ /Entry B/ && $1=="CLOSE-CANDIDATE"{f=1} END{print f+0}')"
  if [ "$mi_ctl" != 1 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutated lib.sh broke the classifier outright (Entry B lost its verdict), so its silence is not attributable\n' "mutation-idrule"
  elif [ "$mi_hit" = 1 ]; then
    printf '  ok    %-22s the anchored id rule reads a real _-bearing entry as an annotation — the fix is load-bearing\n' "mutation-idrule"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s restoring the anchored id rule did NOT misread the _-bearing entry, so the id assertion is vacuous\n' "mutation-idrule"
  fi
fi

# MUTATION — drop `!prev_id_closed` from the conjunction, and ONLY that clause. A closed entry
# is skipped by the classifier, so it emits no row by design; without this clause every real
# entry that follows a close is reported as an annotation that ate its neighbour's receipt.
# This is a REVERT OF ONE LAYER of a layered change, which is why it is its own mutant rather
# than a second assertion on the one above.
MUTP="$(dirname "$DIST")/mut-prevclosed"
rm -rf "$MUTP"; mkdir -p "$MUTP"
cp "$(dirname "$CLOSER")"/*.sh "$MUTP/" 2>/dev/null
sed 's@ && !prev_id_closed)@)@' "$CLOSER" > "$MUTP/ledger-reverify.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTP/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the !prev_id_closed clause is unproven\n' "mutation-prevclosed"
else
  mp_out="$(bash "$MUTP/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  mp_hit="$(printf '%s\n' "$mp_out" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $2 ~ /legacy-entry/{f=1} END{print f+0}')"
  mp_tp="$(printf '%s\n' "$mp_out" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $2 ~ /False CLOSE-CANDIDATE/{f=1} END{print f+0}')"
  if [ "$mp_tp" != 1 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant lost the genuine no-colon row too, so it is not a clean revert of the clause alone\n' "mutation-prevclosed"
  elif [ "$mp_hit" = 1 ]; then
    printf '  ok    %-22s without !prev_id_closed a real entry below a close is falsely reported — the clause is load-bearing\n' "mutation-prevclosed"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s dropping !prev_id_closed did NOT re-fire the entry below the close, so that control is vacuous\n' "mutation-prevclosed"
  fi
fi

# MUTATION — drop `!prev_id_hadv`, the clause that keeps the BENIGN direction quiet. Without it
# an entry whose own receipt sits ABOVE an annotation — which loses nothing — is reported.
MUTH="$(dirname "$DIST")/mut-prevhadv"
rm -rf "$MUTH"; mkdir -p "$MUTH"
cp "$(dirname "$CLOSER")"/*.sh "$MUTH/" 2>/dev/null
sed 's@ && !prev_id_hadv@@' "$CLOSER" > "$MUTH/ledger-reverify.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTH/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the !prev_id_hadv clause is unproven\n' "mutation-prevhadv"
else
  mh_out="$(bash "$MUTH/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  mh_hit="$(printf '%s\n' "$mh_out" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $2 ~ /Second no-colon prose bullet/{f=1} END{print f+0}')"
  mh_tp="$(printf '%s\n' "$mh_out" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $2 ~ /False CLOSE-CANDIDATE/{f=1} END{print f+0}')"
  if [ "$mh_tp" != 1 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant lost the genuine no-colon row too, so it is not a clean revert of the clause alone\n' "mutation-prevhadv"
  elif [ "$mh_hit" = 1 ]; then
    printf '  ok    %-22s without !prev_id_hadv the benign direction is falsely reported — the clause is load-bearing\n' "mutation-prevhadv"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s dropping !prev_id_hadv did NOT re-fire the benign case, so that control is vacuous\n' "mutation-prevhadv"
  fi
fi

# THE UNMUTATED CONTROL FOR THIS BATTERY. Four mutant directories above are COPIES; a copy that
# cannot source lib.sh emits nothing at all, and "no ENTRY-SWALLOWED row" would score as a kill
# for every false-positive assertion here. This copy is byte-identical, so it must agree with
# $OUT exactly.
ASSERTIONS=$((ASSERTIONS + 1))
CTLS="$(dirname "$DIST")/ctl-swallow"
rm -rf "$CTLS"; mkdir -p "$CTLS"
cp "$(dirname "$CLOSER")"/*.sh "$CTLS/" 2>/dev/null
ctl_sw="$(bash "$CTLS/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1 | awk -F'\t' '$1=="ENTRY-SWALLOWED"{c++} END{print c+0}')"
own_sw="$(printf '%s\n' "$OUT" | awk -F'\t' '$1=="ENTRY-SWALLOWED"{c++} END{print c+0}')"
if [ "$ctl_sw" = "$own_sw" ] && [ "$own_sw" -ge 2 ]; then
  printf '  ok    %-22s unmutated copy emits the same %s ENTRY-SWALLOWED rows (the four mutants above ran a working harness)\n' "swallow-control" "$own_sw"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s unmutated copy emitted %s rows against %s in place (want equal, and >= 2) — a copy that cannot run scores as a kill\n' "swallow-control" "$ctl_sw" "$own_sw"
fi

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
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s no NEEDS-REVIEW row for the subject at all — the detail arms below cannot discriminate\n' "midline-detail"
elif ! grep -q '^mid-line receipt: ' <<<"$ml_det"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the detail does not OPEN with the cause token, so this cause cannot be told from the other three: %s\n' "midline-detail" "$(printf '%s' "$ml_det" | cut -c1-100)"
elif ! grep -qE 'line [0-9]+ of its body' <<<"$ml_det"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the detail names no line number: %s\n' "midline-detail" "$(printf '%s' "$ml_det" | cut -c1-120)"
elif ! grep -q 'verify: theirs_has' <<<"$ml_det"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the detail names no verb, so the operator cannot tell which receipt went unrun: %s\n' "midline-detail" "$(printf '%s' "$ml_det" | cut -c1-120)"
else
  printf '  ok    %-22s the row opens with the cause token and names the line and the verb\n' "midline-detail"
fi

# AND THE LINE NUMBER IS THE OFFENDING LINE, not merely a number. Derived from the seeded ledger
# rather than hardcoded: a literal would go stale the release somebody edits the seed above it,
# and would still read as a passing assertion.
ASSERTIONS=$((ASSERTIONS + 1))
LED_ML="$CONS/_bmad-output/ai-dlc-update/push-candidate-ledger.md"
ml_want="$(awk '/^  <br>A session resuming from that snapshot reads a fully-shipped sprint as pending work\. verify: theirs_has/{print NR; exit}' "$LED_ML")"
ml_got="$(printf '%s' "$ml_det" | sed -n 's/.*line \([0-9][0-9]*\) of its body.*/\1/p')"
if [ -n "$ml_want" ] && [ "$ml_want" = "$ml_got" ]; then
  printf '  ok    %-22s the reported line %s IS the offending body line in the seeded ledger\n' "midline-line" "$ml_got"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s reported line %s, offending line in the ledger is %s (empty = the seed line moved and this arm lost its subject)\n' "midline-line" "${ml_got:-<none>}" "${ml_want:-<none>}"
fi

# THE EIGHT SILENT CLASSES. Each is a REAL shape in the corpora and each would be reported by a
# predicate one conjunct short of this one.
row_lacks "Entry ONLY-IN-TICKS" NEEDS-REVIEW \
  "a mention inside an inline code span is a body QUOTING the convention — the ledger is full of those"
row_lacks "Entry ONLY-IN-TICKS" STILL-LIVE \
  "and it emits nothing at all, exactly like Entry D: the backtick strip must not turn a quotation into a receipt either"
row_lacks "Entry ROW-ANCHORED-PLUS-MENTION" NEEDS-REVIEW \
  "an entry with a REAL anchored receipt is not silent, whatever its summary line says — reporting it would say move a receipt that already ran"
row_is "Entry ROW-ANCHORED-PLUS-MENTION" STILL-LIVE \
  "...and its anchored receipt still produces its own verdict, so the silence is not bought by the entry disappearing"
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
  printf '  ok    %-22s two offending lines in one entry emit ONE row, naming the FIRST (theirs_has, not the theirs_lacks below it)\n' "midline-one-row"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s %s row(s) for the two-offence entry, naming: %s (want 1 row naming theirs_has)\n' "midline-one-row" "$ml_two_n" "$(printf '%s' "$ml_two_v" | sed -n 's/.*carries .verify: \([a-z_]*\).*/\1/p')"
fi

# --- THE MID-LINE MUTANTS ---------------------------------------------------------------------
# NINE MUTANTS ON A TINY LEDGER, cut from the seeded one by bullet range so no receipt is restated
# here. A full-ledger run is ~6s and this fixture is already one of the suite's longer units; the
# tiny corpus runs in ~1s, which is the difference between nine mutants costing a minute and
# costing ten seconds. Entry A rides along in the cut as the DEAD-COPY CONTROL: every kill below
# requires its STILL-LIVE row to SURVIVE, so a copy that could not source lib.sh — which emits
# nothing and would otherwise score as a kill of every absence arm — is caught instead.
ML_TINY="$(dirname "$DIST")/tiny-midline-ledger.md"
awk '/^- \*\*Entry A still lacked/{p=1} p; p && /verify: theirs_lacks/{exit}' "$LED_ML" > "$ML_TINY"
printf '\n' >> "$ML_TINY"
awk '/^- \*\*Entry ONLY-IN-TICKS/{p=1} /^- \*\*Entry SH-MOVED/{p=0} p' "$LED_ML" >> "$ML_TINY"
ASSERTIONS=$((ASSERTIONS + 1))
ml_tiny_n="$(grep -c '^- \*\*Entry ' "$ML_TINY")" || ml_tiny_n=0
if [ "$ml_tiny_n" -eq 10 ]; then
  printf '  ok    %-22s the tiny ledger carries Entry A plus the nine mid-line entries\n' "midline-tiny-ledger"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the tiny ledger carries %s bullets, not 10 — the mutants below would run over the wrong corpus\n' "midline-tiny-ledger" "$ml_tiny_n"
fi

# EVERY MUTATION ANCHOR ASSERTED UNIQUE FIRST, with an IMPOSSIBLE anchor beside them as the
# control: a counter that reports 1 for a string no file carries is a broken counter, and its
# nine agreeing answers above would be meaningless. A mutation matching two sites edits a line
# this fixture never reads and scores a kill it did not earn.
ml_anchor_n() { grep -cF "$1" "$CLOSER" 2>/dev/null || true; }
ASSERTIONS=$((ASSERTIONS + 1))
ml_bad="$(ml_anchor_n 'ZZQQ_NO_SUCH_ANCHOR_IN_THIS_FILE')"
ml_uniq=1; ml_why=""
for a in \
  '"$(ledger_entry_awk)${CLOSE_AWK}${ELC_AWK}"' \
  'if (label != "" && !anchored && !closed && midnr > 0)' \
  '    if (__lef_in) next' \
  '    if (ledger_entry_line_closes($0)) closed = 1' \
  '    if (ledger_body_closes($0)) closed = 1' \
  '    if ($0 ~ /^[ \t]*>/) next' \
  '    gsub(/<!--([^-]|-[^-])*-->/, "", t)' \
  '    if (midnr == 0 && match(t, '; do
  n="$(ml_anchor_n "$a")"
  [ "$n" = 1 ] || { ml_uniq=0; ml_why="$ml_why [$n x '$a']"; }
done
# The backtick strip is counted separately: a backtick inside a double-quoted assertion string
# would run as a command, so its literal is built from its own character code.
ml_bt="$(awk -v BT='`' 'index($0, "gsub(/" BT "[^" BT "]*" BT "/, \"\", t)"){c++} END{print c+0}' "$CLOSER")"
[ "$ml_bt" = 1 ] || { ml_uniq=0; ml_why="$ml_why [$ml_bt x backtick-strip]"; }
if [ "$ml_uniq" = 1 ] && [ "$ml_bad" = 0 ]; then
  printf '  ok    %-22s all nine mutation anchors are unique in the closer, and an impossible anchor returns 0\n' "midline-anchors"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s anchor counts wrong:%s ; impossible-anchor control returned %s (want 0)\n' "midline-anchors" "${ml_why:- none}" "$ml_bad"
fi

# THE UNMUTATED CONTROL, WITH A POSITIVE CONJUNCT. A copy that cannot source lib.sh emits nothing,
# and "no mid-line row" is what eight of the nine arms below assert — so silence would score as a
# kill for every one of them. This copy must reproduce BOTH baseline observables on the tiny
# corpus: the subject reported, and Entry A still classified.
ML_CTL="$(dirname "$DIST")/ctl-midline"
rm -rf "$ML_CTL"; mkdir -p "$ML_CTL"
cp "$(dirname "$CLOSER")"/*.sh "$ML_CTL/" 2>/dev/null
ml_ctl_out="$(bash "$ML_CTL/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" "$ML_TINY" 2>&1)"
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$ml_ctl_out" | awk -F'\t' '$2=="Entry ORPHAN-RECEIPT-MIDLINE" && $1=="NEEDS-REVIEW" && $3 ~ /^mid-line receipt/{a=1} $2 ~ /Entry A still lacked/ && $1=="STILL-LIVE"{b=1} END{exit !(a && b)}'; then
  # TWO expected rows on this corpus, and they are ENUMERATED rather than counted: the subject,
  # and the two-offence entry the last-match-wins mutant needs. A count alone would be satisfied
  # by two rows against the wrong entries, which is the state seven of the arms below assert is
  # impossible.
  ml_ctl_mid="$(printf '%s\n' "$ml_ctl_out" | awk -F'\t' '$3 ~ /^mid-line receipt/{c++} END{print c+0}')"
  ml_ctl_lbl="$(printf '%s\n' "$ml_ctl_out" | awk -F'\t' '$3 ~ /^mid-line receipt/{print $2}' | LC_ALL=C sort | tr '\n' '|')"
  if [ "$ml_ctl_mid" = 2 ] && [ "$ml_ctl_lbl" = "Entry ORPHAN-RECEIPT-MIDLINE|Entry TWO-MIDLINE-RECEIPTS|" ]; then
    printf '  ok    %-22s unmutated copy on the tiny ledger: exactly the 2 expected mid-line rows and Entry A STILL-LIVE\n' "midline-control"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s unmutated copy emitted %s mid-line rows on the tiny ledger (%s), want exactly the 2 expected — the silence arms below are unreadable\n' "midline-control" "$ml_ctl_mid" "${ml_ctl_lbl:-<none>}"
    printf '%s\n' "$ml_ctl_out" | sed 's/^/          | /'
  fi
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the unmutated copy does not reproduce the subject row AND Entry A on the tiny ledger — every kill below would be scored against wreckage\n' "midline-control"
  printf '%s\n' "$ml_ctl_out" | sed 's/^/          | /'
fi

ml_mutant() { # <name> <awk-program>  -> dir on stdout, empty if the program changed nothing
  local n="$1" prog="$2" d
  d="$(dirname "$DIST")/mut-$n"; rm -rf "$d"; mkdir -p "$d"
  cp "$(dirname "$CLOSER")"/*.sh "$d/" 2>/dev/null
  awk "$prog" "$CLOSER" > "$d/ledger-reverify.sh" || return 1
  if cmp -s "$CLOSER" "$d/ledger-reverify.sh"; then return 1; fi
  printf '%s' "$d"
}
ml_kill() { # <name> <dir-or-empty> <kill-awk> <kill-msg>
  local n="$1" d="$2" kill="$3" kmsg="$4" out
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ -z "$d" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutation DID NOT APPLY (matched nothing, or awk died), so the arm it targets is unproven\n' "$n"
    return
  fi
  out="$(bash "$d/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" "$ML_TINY" 2>&1)"
  # THE DEAD-COPY CONTROL, IN THE SAME RUN. Entry A is unrelated to this pass, so a mutant that
  # broke the closer rather than the guard loses it and its verdict is wreckage rather than a kill.
  if ! printf '%s\n' "$out" | awk -F'\t' '$2 ~ /Entry A still lacked/ && $1=="STILL-LIVE"{f=1} END{exit !f}'; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s Entry A lost its STILL-LIVE row too — the mutant broke the closer, not the guard\n' "$n"
    printf '%s\n' "$out" | sed 's/^/          | /'
  elif printf '%s\n' "$out" | awk -F'\t' "$kill"; then
    printf '  ok    %-22s %s\n' "$n" "$kmsg"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the guard was changed and the arm it protects did NOT change verdict — that arm cannot fire\n' "$n"
    printf '%s\n' "$out" | awk -F'\t' '$1=="NEEDS-REVIEW"' | sed 's/^/          | /'
  fi
}

# 1. THE PASS ITSELF UNREACHABLE. The absence-shaped arms all pass against a subject that emits
#    nothing, so the one PRESENCE-shaped arm needs a mutant that proves the pass runs at all.
ml_kill mutation-midline-off \
  "$(ml_mutant midline-off 'index($0, "$(ledger_entry_awk)${CLOSE_AWK}${ELC_AWK}") { print "exit 0   # MUTANT: the mid-line pass is unreachable" } { print }')" \
  '$3 ~ /^mid-line receipt/{f=1} END{exit f}' \
  "with the pass unreachable the subject emits NO row — the reporting arm is watching a program that runs"
# 2. THE BACKTICK STRIP REMOVED. A body that QUOTES the convention becomes a receipt, which is the
#    class the anchoring exists to exclude arriving through the back door.
ml_kill mutation-midline-backtick \
  "$(ml_mutant midline-backtick 'BEGIN { BT = sprintf("%c", 96) } index($0, "gsub(/" BT "[^" BT "]*" BT "/, \"\", t)") { next } { print }')" \
  '$2=="Entry ONLY-IN-TICKS" && $1=="NEEDS-REVIEW" && $3 ~ /^mid-line receipt/{f=1} END{exit !f}' \
  "without the span strip a body quoting the convention is reported as an unrun receipt — the strip is load-bearing"
# 3. THE no-anchored-receipt CONJUNCT DROPPED. An entry whose receipt RAN is then told to move it.
ml_kill mutation-midline-anchored \
  "$(ml_mutant midline-anchored 'index($0, "if (label != \"\" && !anchored && !closed && midnr > 0)") { sub(/!anchored && /, "") } { print }')" \
  '$2=="Entry ROW-ANCHORED-PLUS-MENTION" && $1=="NEEDS-REVIEW" && $3 ~ /^mid-line receipt/{f=1} END{exit !f}' \
  "without the anchored conjunct an entry whose receipt already ran is told to move it — the conjunct is load-bearing"
# 4. THE FENCE SKIP DROPPED. Recorded OUTPUT inside a fence becomes a directive.
ml_kill mutation-midline-fence \
  "$(ml_mutant midline-fence '$0 == "    if (__lef_in) next" { next } { print }')" \
  '$2=="Entry PENNED-IN-A-FENCE" && $1=="NEEDS-REVIEW" && $3 ~ /^mid-line receipt/{f=1} END{exit !f}' \
  "without the fence skip a worked example inside a fence is reported as an unrun receipt"
# 5. THE ENTRY-LINE CLOSE RULE DROPPED, and it is its OWN mutant rather than a second assertion on
#    the body rule below: the two are different predicates with different anchors, and lib.sh
#    records that testing a BOUNDARY line with the body rule is not merely wrong but INERT. If one
#    mutant killed both cells they would be one guard; they are two, and each has a subject the
#    other cannot see.
ml_kill mutation-midline-elc \
  "$(ml_mutant midline-elc '$0 == "      if (ledger_entry_line_closes($0)) closed = 1" { next } { print }')" \
  '$2 ~ /Entry ZAPPED-CLOSED-MIDLINE/ && $1=="NEEDS-REVIEW" && $3 ~ /^mid-line receipt/{f=1} $2=="Entry WALLED-BY-BODY-ANNOTATION" && $3 ~ /^mid-line receipt/{g=1} END{exit !(f && !g)}' \
  "without the ENTRY-LINE close rule an entry closed on its own bullet is reported, and the body-closed one is NOT — two rules, two subjects"
# 6. THE BODY CLOSE RULE DROPPED. The mirror, and the entry closed by a `<br>**ADOPTED UPSTREAM`
#    body annotation is the one it owns.
ml_kill mutation-midline-body \
  "$(ml_mutant midline-body '$0 == "    if (ledger_body_closes($0)) closed = 1" { next } { print }')" \
  '$2=="Entry WALLED-BY-BODY-ANNOTATION" && $1=="NEEDS-REVIEW" && $3 ~ /^mid-line receipt/{f=1} $2 ~ /Entry ZAPPED-CLOSED-MIDLINE/ && $3 ~ /^mid-line receipt/{g=1} END{exit !(f && !g)}' \
  "without the BODY close rule an entry closed by a body annotation is reported, and the entry-line-closed one is NOT"
# 7. THE BLOCKQUOTE SKIP DROPPED. A quotation of somebody else's receipt becomes a directive.
ml_kill mutation-midline-blockquote \
  "$(ml_mutant midline-blockquote '$0 == "    if ($0 ~ /^[ \\t]*>/) next" { next } { print }')" \
  '$2=="Entry QUOTED-IN-A-BLOCKQUOTE" && $1=="NEEDS-REVIEW" && $3 ~ /^mid-line receipt/{f=1} END{exit !f}' \
  "without the blockquote skip a quoted receipt is reported and the operator is told to move it"
# 8. THE HTML-COMMENT STRIP DROPPED. Text the rendered document does not show becomes a directive.
ml_kill mutation-midline-comment \
  "$(ml_mutant midline-comment 'index($0, "gsub(/<!--([^-]|-[^-])*-->/, \"\", t)") { next } { print }')" \
  '$2=="Entry NOTED-IN-AN-HTML-COMMENT" && $1=="NEEDS-REVIEW" && $3 ~ /^mid-line receipt/{f=1} END{exit !f}' \
  "without the comment strip a commented-out receipt is reported as an unrun one"
# 9. THE FIRST-MATCH GUARD DROPPED, so the scalar is last-match-wins. The ROW COUNT does not move —
#    which is exactly why this needs its own arm: the observable is the VERB the row names, and an
#    arm keyed on the count alone would pass against a reader pointing at the wrong line.
ml_kill mutation-midline-lastwins \
  "$(ml_mutant midline-lastwins 'index($0, "if (midnr == 0 && match(t, ") { sub(/midnr == 0 && /, "") } { print }')" \
  '$2=="Entry TWO-MIDLINE-RECEIPTS" && $3 ~ /carries .verify: theirs_lacks/{f=1} END{exit !f}' \
  "a last-match-wins reader emits the same ONE row and names the SECOND receipt — the count cannot see this, the verb can"


# MUTATION — remove the moved-subject guard. Entry SH-SUBJECT-GONE must fall back to
# CLOSE-CANDIDATE, and Entry SH-REAL must stay CLOSE-CANDIDATE either way: without the second
# half, a mutant that broke the sh branch outright would score as a kill of the first.
MUTG="$(dirname "$DIST")/mut-subject-guard"
rm -rf "$MUTG"; mkdir -p "$MUTG"
cp "$(dirname "$CLOSER")"/*.sh "$MUTG/" 2>/dev/null
sed 's/^          _gone="$(receipt_absent_subjects "$rest")"$/          _gone=""/' "$CLOSER" > "$MUTG/ledger-reverify.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTG/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the moved-subject assertion is unproven\n' "mutation-subject"
else
  mg="$(bash "$MUTG/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  mg_gone="$(printf '%s\n' "$mg" | awk -F'\t' '$2 ~ /SH-SUBJECT-GONE/ {print $1; exit}')"
  mg_real="$(printf '%s\n' "$mg" | awk -F'\t' '$2 ~ /SH-REAL/ {print $1; exit}')"
  if [ "$mg_gone" = "CLOSE-CANDIDATE" ] && [ "$mg_real" = "CLOSE-CANDIDATE" ]; then
    printf '  ok    %-22s guard removed: the moved subject proposes a close again, and only it moved\n' "mutation-subject"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s guard removed but SH-SUBJECT-GONE=%s SH-REAL=%s (want CLOSE-CANDIDATE/CLOSE-CANDIDATE) — the assertion is vacuous or the mutant broke the whole branch\n' "mutation-subject" "${mg_gone:-none}" "${mg_real:-none}"
  fi
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
      # THE NEAR-MISS COUNT EXCLUDES OFFENDERS, and it did not until a probe forced it to. A row
      # carrying a REAL escape also carries a backslash and the token u2026, so counting both
      # shapes independently let an offending row satisfy the near-miss precondition — measured
      # on a hoisted-message mutant, where nm went 1 -> 3 as the escape came back. The mutant
      # arm below requires the near-miss row to SURVIVE the mutation; that requirement is only
      # a requirement if the offending rows cannot supply it.
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
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s scanned %s row(s), %s of them ENTRY-SWALLOWED — a zero over an empty corpus is not a finding, and this arm would have passed against a subject that printed nothing\n' "detail-no-uescape" "$ue_rows" "$ue_sw"
elif [ "$ue_nm" -eq 0 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the PC-FIXTURE-UESCAPE-NEAR-MISS detail is not among the %s scanned rows, so a zero here does not establish that the pattern separates a real escape from an adjacent one\n' "detail-no-uescape" "$ue_rows"
elif [ "$ue_off" -eq 0 ]; then
  printf '  ok    %-22s no detail in %s rows (%s ENTRY-SWALLOWED) carries backslash-u-HHHH, and the near-miss row carrying a lone backslash, the token u2026 and a 3-hex backslash-u did NOT trip it\n' "detail-no-uescape" "$ue_rows" "$ue_sw"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s %s detail field(s) carry a literal backslash-u-HHHH escape. emit() prints a detail through a %%s conversion, which does not interpret escapes, so those six characters reach the operator and the byte-compared report verbatim. Write the character itself\n' "detail-no-uescape" "$ue_off"
  printf '%s\n' "$OUT" | uescape_offenders | sed 's/^/          | /'
fi

# MUTATION — put the escape back on the emitting line of a COPY. The mutant rewrites the bold
# span inside the ENTRY-SWALLOWED detail from the literal ellipsis to the six characters, by
# index and substr rather than by sub(): a backslash in a sub() REPLACEMENT is reprocessed, and
# backslash-u there is undefined across awk implementations, which would make the mutation the
# one thing in this file whose bytes are not knowable.
#
# BOTH HALVES ARE ASSERTED. The kill is "the arm reports an offender"; on its own that is also
# what a mutant which broke the emitter into garbage would produce, so the second half requires
# the mutant to still emit its ENTRY-SWALLOWED rows and to still carry the near-miss row.
MUTE="$(dirname "$DIST")/mut-uescape"
rm -rf "$MUTE"; mkdir -p "$MUTE"
cp "$(dirname "$CLOSER")"/*.sh "$MUTE/" 2>/dev/null
awk '
  BEGIN { BS = sprintf("%c", 92) }
  /emit ENTRY-SWALLOWED/ {
    p = index($0, "**")
    if (p > 0) {
      q = index(substr($0, p + 2), "**")
      if (q > 0) $0 = substr($0, 1, p + 1) BS "u2026" substr($0, p + 2 + q - 1)
    }
  }
  { print }
' "$CLOSER" > "$MUTE/ledger-reverify.sh"

ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$MUTE/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the mutation matched nothing, so the escape arm is unproven — it has never been shown to fire\n' "mutation-uescape"
else
  mu_out="$(bash "$MUTE/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  read -r mu_off mu_rows mu_sw mu_nm < <(printf '%s\n' "$mu_out" | uescape_scan)
  if [ "$mu_off" -gt 0 ] && [ "$mu_sw" -gt 0 ] && [ "$mu_nm" -gt 0 ]; then
    printf '  ok    %-22s the escape restored on the emitting line is REPORTED (%s offending detail(s)), while the mutant still emits %s ENTRY-SWALLOWED row(s) and the near-miss row — the arm fires, and it fired on the mutation rather than on wreckage\n' "mutation-uescape" "$mu_off" "$mu_sw"
  elif [ "$mu_sw" -eq 0 ] || [ "$mu_nm" -eq 0 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant emitted %s ENTRY-SWALLOWED row(s) and %s near-miss row(s) over %s rows — it broke the emitter rather than restoring the escape, so any verdict from it is about wreckage\n' "mutation-uescape" "$mu_sw" "$mu_nm" "$mu_rows"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the escape is back on the emitting line and the arm reported ZERO offenders over %s rows — the arm above cannot fire and its clean run means nothing\n' "mutation-uescape" "$mu_rows"
  fi
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
# rather than read as a new opener. Each of those four clauses has its own seed, its own arm and
# its own mutant, because a battery that seeds only the filed shape proves the rule accepts the
# filed shape and nothing else.
row_is "PC-FIXTURE-FENCED-NON-ID-HEADING" STILL-LIVE \
  "the entry reports under its OWN id — the fenced timestamp headings did not open an entry"
row_is "FENCED-TS-EVENT" ABSENT \
  "no row is labelled with a fenced timestamp heading (any of the three seeded)"
row_is "PC-FIXTURE-INLINE-SPAN-LINE" STILL-LIVE \
  "an entry whose body opens a line with an inline code span still reports"
row_is "inline-span-control.sh" STILL-LIVE \
  "the PROSE-titled entry after that inline-span line still reports — the span did not open a fence"
row_has "PC-FIXTURE-QUOTED-INSIDE-FENCE" ENTRY-SWALLOWED \
  "an id-keyed heading QUOTED inside a fence is REPORTED — it still opens an entry, and the operator is told"
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $2 ~ /PC-FIXTURE-QUOTED-INSIDE-FENCE/ && $3 ~ /PC-FIXTURE-QUOTING-ENTRY/ && $3 ~ /fenced code block/{f=1} END{exit !f}'; then
  printf '  ok    %-22s the fence row names the entry it truncated and says the line sits inside a fence\n' "fence-names-entry"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the fence row does not name PC-FIXTURE-QUOTING-ENTRY as the truncated entry, or does not say the line is fenced\n' "fence-names-entry"
  printf '%s\n' "$OUT" | awk -F'\t' '$1=="ENTRY-SWALLOWED"' | sed 's/^/          | /'
fi
row_lacks "PC-FIXTURE-AFTER-QUOTE" ENTRY-SWALLOWED \
  "the entry AFTER a quoted heading is NOT reported — the quotation's closing fence was consumed as a stray closer, not read as a new opener"
# THE TWO-QUOTATION FENCE, PINNED AS THE STATED COST rather than dodged by seed ordering. If
# `after-two-quotes-cost` ever FAILS because the false row disappeared while every other arm
# holds, that is an improvement: update this arm, do not restore the row.
row_has "PC-FIXTURE-QUOTED-TWICE-A" ENTRY-SWALLOWED \
  "the first of two quoted headings is reported"
row_has "PC-FIXTURE-AFTER-TWO-QUOTES" STILL-LIVE \
  "the entry after a two-quotation fence is never HIDDEN — its receipt reports (row_has: two rows)"
row_has "PC-FIXTURE-AFTER-TWO-QUOTES" ENTRY-SWALLOWED \
  "after-two-quotes-cost: and it carries the ONE false fence row the stray rule costs on this shape (the measured alternative cost seven false resets on the consumer archive)"
row_has "PC-FIXTURE-EOF-FENCE" STILL-LIVE \
  "an entry whose fence is still open at end of file still reports its receipt (row_has: two rows)"
row_has "PC-FIXTURE-EOF-FENCE" ENTRY-SWALLOWED \
  "and the fence left open at end of file is REPORTED by the END rule — the shape a rotation split leaves behind"
row_is "PC-FIXTURE-AFTER-QUOTE" STILL-LIVE \
  "and it is classified normally"
row_has "PC-FIXTURE-AFTER-UNTERMINATED" STILL-LIVE \
  "an id-keyed entry after an UNTERMINATED fence still reports — the fence cannot hide it (row_has: this entry emits two rows)"
row_is "PC-FIXTURE-TILDE-FENCE" STILL-LIVE \
  "a ~~~ fence is a fence too: the heading-shaped line inside it did not open an entry"
row_is "PC-FIXTURE-INDENTED-FENCE" STILL-LIVE \
  "a fence indented two spaces (the consumer's second-commonest delimiter shape) is a fence: the column-0 heading inside it did not open an entry"
row_is "INDENTED-TS-EVENT" ABSENT \
  "no row is labelled with the heading inside the indented fence"
row_has "PC-FIXTURE-AFTER-UNTERMINATED" ENTRY-SWALLOWED \
  "and the reset through the unterminated fence is REPORTED, naming the entry whose fence never closed"

# FIVE MUTANTS, ONE CLAUSE EACH, ALL ON lib.sh COPIES. Every mutant copies the reconcile
# directory and rewrites ONE clause of the shape rule; the `cmp -s` guard refuses a sed that
# matched nothing, and each kill requires a control row to SURVIVE so a mutant that broke the
# parser outright cannot score as a clean kill.
#
# THE ARMS OVERLAP, AND THAT IS DECLARED RATHER THAN DISCOVERED. Measured by the batch-50 fixture
# hand over every row_* assertion against each mutant's real output: fence-blind flips four arms,
# no-reset and naive-opener three each, no-stray one. Every extra flip is a TRUE finding about
# the same broken clause, so the overlap is in the arms and not in the mutants; each kill below
# names the ONE arm it owns. Two arms are controls with no mutant of their own -- the id-keyed
# entry after the inline-span line, and the STILL-LIVE half of the entry after a quotation --
# and they are kept as controls, not counted as proven.
fence_mutant() { # <name> <sed-expr>  -> dir on stdout, empty if the sed matched nothing
  local n="$1" expr="$2" d
  d="$(dirname "$DIST")/mut-$n"; rm -rf "$d"; mkdir -p "$d"
  cp "$(dirname "$CLOSER")"/*.sh "$d/" 2>/dev/null
  sed "$expr" "$(dirname "$CLOSER")/lib.sh" > "$d/lib.sh"
  if cmp -s "$(dirname "$CLOSER")/lib.sh" "$d/lib.sh"; then return 1; fi
  printf '%s' "$d"
}
fence_kill() { # <name> <dir-or-empty> <kill-awk> <control-awk> <kill-msg> <ctl-msg>
  local n="$1" d="$2" kill="$3" ctl="$4" kmsg="$5" cmsg="$6" out
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ -z "$d" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutation matched nothing in lib.sh, so the arm it targets is unproven\n' "$n"
    return
  fi
  out="$(bash "$d/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  if ! printf '%s\n' "$out" | awk -F'\t' "$ctl"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the control row is gone too (%s) — the mutant broke the parser rather than the clause, so its verdict is wreckage\n' "$n" "$cmsg"
  elif printf '%s\n' "$out" | awk -F'\t' "$kill"; then
    printf '  ok    %-22s %s\n' "$n" "$kmsg"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the clause was removed and the arm it guards did NOT change verdict — that arm cannot fire\n' "$n"
    printf '%s\n' "$out" | awk -F'\t' '$2 ~ /FENCED|QUOTE|UNTERMINATED|inline-span/' | sed 's/^/          | /'
  fi
}
# m-fence-blind: the in-fence branch removed. The fenced timestamp heading opens an entry again
# and captures the receipt: a row appears under a FENCED-TS-EVENT label.
fence_kill mutation-fence-blind "$(fence_mutant fence-blind 's@if (__lef_in && sh != "") {@if (0) {@')" \
  '$2 ~ /FENCED-TS-EVENT/ {f=1} END{exit !f}' \
  '$2 ~ /PC-FIXTURE-COLON-CONTROL/ && $1=="STILL-LIVE" {f=1} END{exit !f}' \
  "fence-blind, a receipt is reported under a fenced timestamp label again — fence tracking is load-bearing" \
  "PC-FIXTURE-COLON-CONTROL STILL-LIVE"
# m-naive-opener: the backtick-in-info-string clause removed, so the inline-span line opens a
# fence. The prose-titled entry after it goes silent while the id-keyed one survives by reset.
fence_kill mutation-naive-opener "$(fence_mutant naive-opener 's@if (substr(t, 1, 1) == "~" || index(rest, "`") == 0) {@if (1) {@')" \
  '$2 ~ /inline-span-control/ {f=1} END{exit f}' \
  '$2 ~ /PC-FIXTURE-INLINE-SPAN-LINE/ && $1=="STILL-LIVE" {f=1} END{exit !f}' \
  "with three bare backticks treated as an opener, the prose-titled entry after the inline-span line vanishes — the CommonMark info-string clause is load-bearing" \
  "PC-FIXTURE-INLINE-SPAN-LINE STILL-LIVE"
# m-no-stray: the stray-closer rule removed. The quotation's closing fence becomes an opener and
# the NEXT entry is falsely reported as fenced.
fence_kill mutation-no-stray "$(fence_mutant no-stray 's@if (__lef_stray && rest ~ @if (0 \&\& rest ~ @')" \
  '$1=="ENTRY-SWALLOWED" && $2 ~ /PC-FIXTURE-AFTER-QUOTE/ {f=1} END{exit !f}' \
  '$1=="ENTRY-SWALLOWED" && $2 ~ /PC-FIXTURE-QUOTED-INSIDE-FENCE/ {f=1} END{exit !f}' \
  "without the stray-closer rule the entry AFTER a quoted heading is accused of being fenced too — one quotation, two rows" \
  "the QUOTED-INSIDE-FENCE fence row"
# m-no-tilde: the tilde arm of the opener grammar removed. A ~~~ fence then opens nothing and
# the heading-shaped line inside it opens an entry that captures the receipt. Without this the
# tilde branch had no subject anywhere: zero ~~~ lines on all four real corpora.
fence_kill mutation-no-tilde "$(fence_mutant no-tilde 's@if (match(t, /^```+/) || match(t, /^~~~+/)) {@if (match(t, /^```+/)) {@')" \
  '$2 ~ /TILDE-TS-EVENT/ {f=1} END{exit !f}' \
  '$2 ~ /PC-FIXTURE-FENCED-NON-ID-HEADING/ && $1=="STILL-LIVE" {f=1} END{exit !f}' \
  "with the tilde arm removed a ~~~ fence is not a fence and its heading-shaped line captures the receipt — the tilde clause is load-bearing" \
  "PC-FIXTURE-FENCED-NON-ID-HEADING STILL-LIVE"
# m-no-reset: the id-keyed escape removed, so an unterminated fence swallows id-keyed lines. The
# entry after the unterminated fence vanishes; the entry after the properly closed quotation
# survives, which is what makes this a clean mutation of the reset alone.
fence_kill mutation-no-reset "$(fence_mutant no-reset 's@if (ledger_entry_id(line) != "") {@if (0) {@')" \
  '$2 ~ /PC-FIXTURE-AFTER-UNTERMINATED/ {f=1} END{exit f}' \
  '$2 ~ /PC-FIXTURE-AFTER-QUOTE/ && $1=="STILL-LIVE" {f=1} END{exit !f}' \
  "without the id-keyed reset an unterminated fence hides the id-keyed entry after it — the 47-entry desync, reproduced" \
  "PC-FIXTURE-AFTER-QUOTE STILL-LIVE"

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
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s no ENTRY-SWALLOWED or RECEIPTS-UNDECIDED row was emitted at all, so this arm has no population\n' "suffix-shape-a"
elif [ "$sfxA_ctl" -eq 0 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s no row OUTSIDE the post-loop statuses carries an ordinal — suffixes are not being emitted at all, so a clean post-loop reading proves nothing\n' "suffix-shape-a"
elif [ "$sfxA_leak" -eq 0 ]; then
  printf '  ok    %-22s all %s post-loop rows carry no receipt suffix, while %s receipt-scoped rows still carry theirs\n' "suffix-shape-a" "$sfxA_post" "$sfxA_ctl"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s %s of %s post-loop rows wear the last entry ordinal — a run-scoped or annotation row attributed to a receipt that did not produce it\n' "suffix-shape-a" "$sfxA_leak" "$sfxA_post"
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
LED_NOUND="$CONS/_bmad-output/ai-dlc-update/no-undecided-ledger.md"
grep -vE 'verify: (theirs_has|sh)' "$CONS/_bmad-output/ai-dlc-update/push-candidate-ledger.md" > "$LED_NOUND"
nou_out="$(bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$LED_NOUND" 2>/dev/null)"
nou_und="$(printf '%s\n' "$nou_out" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{c++} END{print c+0}')"
nou_sw="$(printf '%s\n' "$nou_out" | awk -F'\t' '$1=="ENTRY-SWALLOWED"{c++} END{print c+0}')"
nou_leak="$(printf '%s\n' "$nou_out" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $3 ~ /\[receipt [0-9]+\/[0-9]+\]$/ {c++} END{print c+0}')"
nou_ctl="$(printf '%s\n' "$nou_out" | awk -F'\t' '$1!="ENTRY-SWALLOWED" && $3 ~ /\[receipt [0-9]+\/[0-9]+\]$/ {c++} END{print c+0}')"
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$nou_und" -ne 0 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the stripped ledger still emitted %s RECEIPTS-UNDECIDED row(s), so this shape never reached the empty-bucket state it exists to test\n' "suffix-shape-b" "$nou_und"
elif [ "$nou_sw" -eq 0 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the stripped ledger produced no ENTRY-SWALLOWED row, so this arm has no population\n' "suffix-shape-b"
elif [ "$nou_ctl" -eq 0 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s no receipt-scoped row on the stripped ledger carries an ordinal — suffixes are absent entirely, so the absence below proves nothing\n' "suffix-shape-b"
elif [ "$nou_leak" -eq 0 ]; then
  printf '  ok    %-22s with the undecided bucket EMPTY, all %s ENTRY-SWALLOWED rows are still suffix-free (a reset sited inside that block never runs here)\n' "suffix-shape-b" "$nou_sw"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s %s of %s ENTRY-SWALLOWED rows wear an ordinal when no RECEIPTS-UNDECIDED row is emitted — the reset is sited inside a block this ledger never enters\n' "suffix-shape-b" "$nou_leak" "$nou_sw"
fi
rm -f "$LED_NOUND"

# SHAPE C — a multi-receipt entry whose rows are NOT all receipt verdicts. PC-FIXTURE-NAMED-MANUAL
# emits NAMED-UPSTREAM plus one HAND-REVIEW per receipt, and EVERY one of those rows is attributable
# to the receipt whose iteration produced it. A reset inside emit() satisfies both shapes above and
# breaks exactly this: the first row consumes the suffix and the second reads empty.
ASSERTIONS=$((ASSERTIONS + 1))
nm_tot="$(printf '%s\n' "$OUT" | awk -F'\t' '$2 ~ /PC-FIXTURE-NAMED-MANUAL/{c++} END{print c+0}')"
nm_sfx="$(printf '%s\n' "$OUT" | awk -F'\t' '$2 ~ /PC-FIXTURE-NAMED-MANUAL/ && $3 ~ /\[receipt [0-9]+\/[0-9]+\]$/{c++} END{print c+0}')"
if [ "$nm_tot" -lt 3 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s PC-FIXTURE-NAMED-MANUAL emitted %s row(s), want at least 3 (one NAMED-UPSTREAM and one HAND-REVIEW per receipt) — the seed lost this arm subject\n' "suffix-shape-c" "$nm_tot"
elif [ "$nm_sfx" -eq "$nm_tot" ]; then
  printf '  ok    %-22s every one of PC-FIXTURE-NAMED-MANUAL %s rows carries its own receipt ordinal, NAMED-UPSTREAM included\n' "suffix-shape-c" "$nm_tot"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s only %s of PC-FIXTURE-NAMED-MANUAL %s rows carry an ordinal — a legitimate row lost its attribution, which is a reset consuming the suffix rather than scoping it\n' "suffix-shape-c" "$nm_sfx" "$nm_tot"
  printf '%s\n' "$OUT" | grep -F 'PC-FIXTURE-NAMED-MANUAL' | sed 's/^/          | /'
fi

# --- THE MUTANTS: seven wrong fixes, every one of which passed at least one shape --------------
# WHOLE-DIRECTORY copies, because ledger-reverify.sh sources lib.sh beside itself and a lone copy
# is silent for a reason that has nothing to do with the clause.
#
# THE DELETE MUTATION IS ANCHORED ON THE COMMENT, NOT ON THE ASSIGNMENT. `^RSFX=""$` matches TWO
# lines in the fixed file — the definition above the argument bail, and the post-loop reset — and
# a mutation eating the first makes the tool die `RSFX: unbound variable` at its first emit under
# `set -u`. That crash emits nothing, which reads as a kill while proving only that a broken copy
# is quiet. So the strip is keyed on the reset's own comment block, its match count is asserted to
# be exactly one, and every kill below requires a CONTROL row to survive in the mutant's output.
sfx_strip='/^# RESET, BECAUSE THE LOOP LEAVES/ {skip=1} skip && /^RSFX=""$/ {skip=0; next} skip && (/^#/ || /^$/) {next}'
ASSERTIONS=$((ASSERTIONS + 1))
sfx_anchor_n="$(grep -c '^# RESET, BECAUSE THE LOOP LEAVES' "$CLOSER")" || sfx_anchor_n=0
sfx_impossible_n="$(grep -c '^# RESET, BECAUSE THE LOOP NEVER LEAVES' "$CLOSER")" || sfx_impossible_n=0
if [ "$sfx_anchor_n" -eq 1 ] && [ "$sfx_impossible_n" -eq 0 ]; then
  printf '  ok    %-22s the reset comment anchor is unique in the closer (control: an impossible anchor matches 0)\n' "suffix-anchor"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the reset anchor matched %s lines (want 1) and the impossible control matched %s (want 0) — the mutations below would cut the wrong line or none\n' "suffix-anchor" "$sfx_anchor_n" "$sfx_impossible_n"
fi

sfx_mutant() { # <name> <awk-body-appended-after-the-strip>  -> dir on stdout, empty if unchanged
  local n="$1" body="$2" d
  d="$(dirname "$DIST")/mut-sfx-$n"; rm -rf "$d"; mkdir -p "$d"
  cp "$(dirname "$CLOSER")"/*.sh "$d/" 2>/dev/null
  awk "$sfx_strip $body {print}" "$CLOSER" > "$d/ledger-reverify.sh"
  if cmp -s "$CLOSER" "$d/ledger-reverify.sh"; then return 1; fi
  [ -f "$d/lib.sh" ] || return 1
  printf '%s' "$d"
}

# THE WRECKAGE PREDICATE, LIFTED OUT OF `sfx_kill` SO IT CAN BE PROBED. Inline it had no
# reachable subject: every mutant below preserves the row count exactly, so the branch fired
# zero times on a clean run and its removal would have changed no verdict. A condition that
# changes no outcome today changes one when the surrounding row counts move, with nobody
# looking. Extracted, the probe two blocks down drives it in both directions on a copy built
# for that purpose, and the guard reading `sfx_wrecked` is the SAME program the probe scored.
sfx_wrecked() { # <mutant-output> -> 0 when the row count differs from the baseline $OUT
  [ "$(printf '%s\n' "$1" | grep -c .)" -ne "$(printf '%s\n' "$OUT" | grep -c .)" ]
}
sfx_rowcount() { printf '%s\n' "$1" | grep -c .; }

# A mutant is KILLED when at least one of the three shapes goes red on it. Each shape's control is
# re-evaluated against the MUTANT's own output, so a copy that died — emitting nothing, or emitting
# rows with no ordinals anywhere — is reported as wreckage rather than scored as a kill.
sfx_kill() { # <name> <dir-or-empty> <why-this-fix-is-wrong>
  local n="$1" d="$2" why="$3" ma mb mc a_leak a_ctl b_leak b_und b_sw c_tot c_sfx red
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ -z "$d" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutation did not apply (or its copy has no lib.sh), so this wrong fix was never scored\n' "$n"
    return
  fi
  ma="$(bash "$d/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>/dev/null)"
  grep -vE 'verify: (theirs_has|sh)' "$CONS/_bmad-output/ai-dlc-update/push-candidate-ledger.md" > "$LED_NOUND"
  mb="$(bash "$d/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" "$LED_NOUND" 2>/dev/null)"
  rm -f "$LED_NOUND"
  # WRECKAGE GUARD, and it is the control the anchor note above demands: the mutant must still
  # produce the baseline's row COUNT on shape A. A crash under set -u prints nothing at all.
  if sfx_wrecked "$ma"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutant emitted %s rows against the baseline %s — it broke the tool rather than moving the reset, so its verdict is wreckage\n' \
      "$n" "$(sfx_rowcount "$ma")" "$(sfx_rowcount "$OUT")"
    return
  fi
  a_leak="$(printf '%s\n' "$ma" | awk -F'\t' '($1=="ENTRY-SWALLOWED"||$1=="RECEIPTS-UNDECIDED") && $3 ~ /\[receipt [0-9]+\/[0-9]+\]$/{c++} END{print c+0}')"
  a_ctl="$(printf '%s\n' "$ma" | awk -F'\t' '$1!="ENTRY-SWALLOWED" && $1!="RECEIPTS-UNDECIDED" && $3 ~ /\[receipt [0-9]+\/[0-9]+\]$/{c++} END{print c+0}')"
  b_und="$(printf '%s\n' "$mb" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{c++} END{print c+0}')"
  b_sw="$(printf '%s\n' "$mb" | awk -F'\t' '$1=="ENTRY-SWALLOWED"{c++} END{print c+0}')"
  b_leak="$(printf '%s\n' "$mb" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $3 ~ /\[receipt [0-9]+\/[0-9]+\]$/{c++} END{print c+0}')"
  c_tot="$(printf '%s\n' "$ma" | awk -F'\t' '$2 ~ /PC-FIXTURE-NAMED-MANUAL/{c++} END{print c+0}')"
  c_sfx="$(printf '%s\n' "$ma" | awk -F'\t' '$2 ~ /PC-FIXTURE-NAMED-MANUAL/ && $3 ~ /\[receipt [0-9]+\/[0-9]+\]$/{c++} END{print c+0}')"
  red=""
  [ "$a_ctl" -eq 0 ] && red="$red A(control: no ordinal survives anywhere)"
  [ "$a_leak" -gt 0 ] && red="$red A(leak=$a_leak)"
  [ "$b_und" -ne 0 ] && red="$red B(shape not reached)"
  [ "$b_leak" -gt 0 ] && red="$red B(leak=$b_leak of $b_sw)"
  [ "$c_tot" -lt 3 ] && red="$red C(population lost)"
  [ "$c_tot" -ge 3 ] && [ "$c_sfx" -ne "$c_tot" ] && red="$red C($c_sfx of $c_tot attributed)"
  if [ -n "$red" ]; then
    printf '  ok    %-22s %s — caught by:%s\n' "$n" "$why" "$red"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s %s, and all three shapes read GREEN on it — the arms above do not discriminate this wrong fix\n' "$n" "$why"
  fi
}

# --- THE WRECKAGE GUARD'S OWN PROBE, AND IT RUNS BEFORE THE FIRST KILL ------------------------
# `sfx_wrecked` is an ABSENCE-shaped guard: on every mutant below it says nothing, because every
# one of them preserves the row count. That silence is indistinguishable from a guard that cannot
# fire, and it WAS one — the guard was written for the crash that deleting both `RSFX=""` lines
# produced under `set -u`, and re-anchoring the delete mutation on the reset's comment block
# removed its only subject. So a copy is built here whose sole purpose is to emit a DIFFERENT row
# count, and the guard is driven on it in both directions in the same block.
#
# IT IS NOT A KILL AND IT IS NOT SCORED AS ONE. A dropped RECEIPTS-UNDECIDED row is not a wrong
# placement of the reset; it is a tool emitting less. The wrecked copy is never handed to
# `sfx_kill`, and FAILURES moves only when the guard is SILENT on the wrecked copy (it cannot
# fire) or FIRES on the shipped copy (it refuses everything).
#
# IT DOES NOT GO THROUGH `sfx_mutant`, AND BOTH REASONS ARE MEASURED. That helper prepends
# `$sfx_strip`, so a copy built with it also loses the reset — ten changed lines where one
# property is under test. And the obvious mutation, DELETING the `emit RECEIPTS-UNDECIDED` line,
# leaves `if [ "${th_undecided:-0}" -gt 0 ]; then … fi` with an empty body: `bash -n` exits 2 and
# the copy dies, which is a row-count difference produced by a syntax error rather than by an
# emitter. Measured, same seed, against a baseline of 90 rows: deletion `bash -n` 2 / run exit 2;
# the CONDITION rewritten to `if false; then` `bash -n` 0 / run exit 0 / 89 rows. So the mutation
# is sited on the condition, the copy's parseability is ASSERTED before it is scored, and a dead
# copy can never satisfy this arm.
wr_mutant() { # <name> <awk-body> -> dir on stdout, empty if unchanged. NO strip.
  local n="$1" body="$2" d
  d="$(dirname "$DIST")/wreck-$n"; rm -rf "$d"; mkdir -p "$d"
  cp "$(dirname "$CLOSER")"/*.sh "$d/" 2>/dev/null
  awk "$body {print}" "$CLOSER" > "$d/ledger-reverify.sh"
  if cmp -s "$CLOSER" "$d/ledger-reverify.sh"; then return 1; fi
  [ -f "$d/lib.sh" ] || return 1
  printf '%s' "$d"
}

ASSERTIONS=$((ASSERTIONS + 1))
wr_anchor_n="$(grep -c '^if \[ "${th_undecided:-0}" -gt 0 \]; then$' "$CLOSER")" || wr_anchor_n=0
wr_impossible_n="$(grep -c '^if \[ "${th_neverdecided:-0}" -gt 0 \]; then$' "$CLOSER")" || wr_impossible_n=0
if [ "$wr_anchor_n" -eq 1 ] && [ "$wr_impossible_n" -eq 0 ]; then
  printf '  ok    %-22s the undecided-condition anchor is unique in the closer (control: an impossible anchor matches 0)\n' "wreck-anchor"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the condition anchor matched %s lines (want 1) and the impossible control matched %s (want 0) — the wreckage probe below would cut the wrong line or none\n' "wreck-anchor" "$wr_anchor_n" "$wr_impossible_n"
fi

# The shipped tree, copied whole so the guard's NEGATIVE direction is scored on a copy driven
# through the identical invocation rather than on `$OUT` itself. Built here rather than beside
# the acquittals below because this probe is the first thing that needs it; `sfx_pass
# acquit-shipped` reuses it.
SFX_SHIPPED="$(dirname "$DIST")/acquit-shipped"
rm -rf "$SFX_SHIPPED"; mkdir -p "$SFX_SHIPPED"
cp "$(dirname "$CLOSER")"/*.sh "$SFX_SHIPPED/" 2>/dev/null
[ -f "$SFX_SHIPPED/ledger-reverify.sh" ] || SFX_SHIPPED=""

ASSERTIONS=$((ASSERTIONS + 1))
wr_dir="$(wr_mutant drop-undecided '/^if \[ "\$\{th_undecided:-0\}" -gt 0 \]; then$/{ print "if false; then"; next }')"
# EXACTLY THE INTENDED LINES, not merely "something changed". `cmp -s` inside the builder sees a
# mutation that matched nothing; it cannot see one that matched more than it meant to, and a copy
# differing by nine lines would score this arm for a property nobody chose.
wr_difflines=0
[ -n "$wr_dir" ] && { wr_difflines="$(diff "$CLOSER" "$wr_dir/ledger-reverify.sh" | grep -c '^[<>]')" || wr_difflines=0; }
if [ -z "$wr_dir" ] || [ -z "$SFX_SHIPPED" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the wreckage copy did not build (or the shipped copy has no lib.sh), so the guard was never driven in either direction\n' "wreckage-subject"
elif [ "$wr_difflines" -ne 2 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the wreckage mutation changed %s line(s) (want 2: one condition out, one in) — it is testing more than the emitter and its verdict is not attributable\n' "wreckage-subject" "$wr_difflines"
elif ! bash -n "$wr_dir/ledger-reverify.sh" 2>/dev/null; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the wreckage copy does not PARSE, so a row-count difference below would be a syntax error rather than a dropped row — the guard would be scored on the wrong property\n' "wreckage-subject"
else
  wr_out="$(bash "$wr_dir/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>/dev/null)"
  wr_ship="$(bash "$SFX_SHIPPED/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>/dev/null)"
  wr_fired=1; sfx_wrecked "$wr_out"  && wr_fired=0
  wr_quiet=1;  sfx_wrecked "$wr_ship" && wr_quiet=0
  # POSITIVE CONJUNCT ON THE CONTROL. A shipped copy that died is "not wrecked" only if it emitted
  # nothing and $OUT did too — so the control asserts the rows are THERE, not merely that the
  # guard stayed quiet. Two inert runs compare equal.
  wr_ship_rows="$(sfx_rowcount "$wr_ship")"
  if [ "$wr_fired" -ne 0 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the guard stayed SILENT on a parseable copy emitting %s rows against the baseline %s — it cannot fire, so every quiet verdict it gives below is unreadable\n' \
      "wreckage-subject" "$(sfx_rowcount "$wr_out")" "$(sfx_rowcount "$OUT")"
  elif [ "$wr_ship_rows" -lt 3 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s CONTROL: the shipped copy emitted only %s row(s), so its quiet reading is a copy that never ran rather than a guard that discriminates\n' \
      "wreckage-subject" "$wr_ship_rows"
  elif [ "$wr_quiet" -ne 1 ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s CONTROL: the guard FIRED on the unmutated shipped copy (%s rows against the baseline %s) — it reports wreckage on any copy, which is not discrimination\n' \
      "wreckage-subject" "$wr_ship_rows" "$(sfx_rowcount "$OUT")"
  else
    printf '  ok    %-22s the guard FIRES on a parseable copy one row short (%s vs baseline %s) and stays QUIET on the shipped copy (%s rows) — it has a subject and it discriminates\n' \
      "wreckage-subject" "$(sfx_rowcount "$wr_out")" "$(sfx_rowcount "$OUT")" "$wr_ship_rows"
  fi
fi

sfx_kill mut-delete-reset "$(sfx_mutant delete-reset '')" \
  "the reset deleted outright"
sfx_kill mut-topreset "$(sfx_mutant topreset '/^  \[ -n "\$directive" \] \|\| continue$/ { print "  RSFX=\"\""; print; next }')" \
  "reset at the TOP of the loop body, which the last iteration still overwrites"
# CONDITIONAL ON THE LEFTOVER ORDINAL, and it is scored as a CORRECT fix rather than a mutant.
# `case "${ord:-}" in 1/1|"") RSFX="" ;; esac` after the loop READS as a wrong fix — a reset that
# fires only in the case that already left the suffix empty — and was built as one. It is not:
# `read` clears its variables when it hits EOF, so `$ord` is EMPTY after `done` on every input and
# the guard fires unconditionally. Measured directly; both arms of the case were driven. Keeping
# it in the kill list would assert a fixture failure against an implementation that works, so it
# sits with the correct fixes below and the wrong-fix family it was meant to represent is covered
# by mut-inblock, whose condition genuinely does not always hold.
sfx_kill mut-inblock "$(sfx_mutant inblock '/^if \[ "\$\{th_undecided:-0\}" -gt 0 \]; then$/ { print; print "  RSFX=\"\""; next }')" \
  "reset INSIDE the undecided block, so it never runs on a ledger with no undecided receipts"
sfx_kill mut-emitreset "$(sfx_mutant emitreset '/^emit\(\) \{ printf / { print "emit() { printf '"'"'%s\\t%s\\t%s\\n'"'"' \"$1\" \"$2\" \"$3$RSFX\"; RSFX=\"\"; }"; next }')" \
  "reset inside emit(), which clears the leak by stripping legitimate rows of their ordinal"
sfx_kill mut-swallowedonly "$(sfx_mutant swallowedonly '/^      emit ENTRY-SWALLOWED "\$sw_label" "this entry opens a fenced/ { print "      RSFX=\"\""; print; next }')" \
  "reset beside one ENTRY-SWALLOWED emit only, leaving every sibling row leaking"
sfx_kill mut-comment-only "$(sfx_mutant comment-only '/^done < "\$LR_STAGE\/entries"$/ { print; print ""; print "# RSFX still holds the last entry receipt suffix here."; next }')" \
  "a COMMENT naming RSFX beside the loop and no code change"

# THE ACQUITTALS, AND THEY ARE WHAT STOPS THE SEVEN KILLS ABOVE READING AS A GUARD THAT REFUSES
# EVERYTHING. Seven mutants all going red is the same observation whether the shapes discriminate
# or whether they reject any tree that is not byte-identical to this one. Two DIFFERENT correct
# implementations are therefore driven through the identical scorer and must come back clean: the
# reset where it ships (immediately after `done`), and the reset moved down to just above the
# undecided `if`. Both are outside the loop and before the first post-loop emit, which is the
# actual property; the shapes must not care where between those two points it sits.
sfx_pass() { # <name> <dir-or-empty> <what-this-fix-is>
  local n="$1" d="$2" what="$3" pa pb a_leak a_ctl b_leak b_und c_tot c_sfx bad
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ -z "$d" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the variant did not build, so this acquittal was never scored\n' "$n"
    return
  fi
  pa="$(bash "$d/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>/dev/null)"
  grep -vE 'verify: (theirs_has|sh)' "$CONS/_bmad-output/ai-dlc-update/push-candidate-ledger.md" > "$LED_NOUND"
  pb="$(bash "$d/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" "$LED_NOUND" 2>/dev/null)"
  rm -f "$LED_NOUND"
  a_leak="$(printf '%s\n' "$pa" | awk -F'\t' '($1=="ENTRY-SWALLOWED"||$1=="RECEIPTS-UNDECIDED") && $3 ~ /\[receipt [0-9]+\/[0-9]+\]$/{c++} END{print c+0}')"
  a_ctl="$(printf '%s\n' "$pa" | awk -F'\t' '$1!="ENTRY-SWALLOWED" && $1!="RECEIPTS-UNDECIDED" && $3 ~ /\[receipt [0-9]+\/[0-9]+\]$/{c++} END{print c+0}')"
  b_und="$(printf '%s\n' "$pb" | awk -F'\t' '$1=="RECEIPTS-UNDECIDED"{c++} END{print c+0}')"
  b_leak="$(printf '%s\n' "$pb" | awk -F'\t' '$1=="ENTRY-SWALLOWED" && $3 ~ /\[receipt [0-9]+\/[0-9]+\]$/{c++} END{print c+0}')"
  c_tot="$(printf '%s\n' "$pa" | awk -F'\t' '$2 ~ /PC-FIXTURE-NAMED-MANUAL/{c++} END{print c+0}')"
  c_sfx="$(printf '%s\n' "$pa" | awk -F'\t' '$2 ~ /PC-FIXTURE-NAMED-MANUAL/ && $3 ~ /\[receipt [0-9]+\/[0-9]+\]$/{c++} END{print c+0}')"
  bad=""
  [ "$a_leak" -gt 0 ] && bad="$bad A(leak=$a_leak)"
  [ "$a_ctl" -eq 0 ] && bad="$bad A(no ordinal survives)"
  [ "$b_und" -ne 0 ] && bad="$bad B(shape not reached)"
  [ "$b_leak" -gt 0 ] && bad="$bad B(leak=$b_leak)"
  [ "$c_tot" -lt 3 ] && bad="$bad C(population lost)"
  [ "$c_tot" -ge 3 ] && [ "$c_sfx" -ne "$c_tot" ] && bad="$bad C($c_sfx of $c_tot)"
  if [ -z "$bad" ]; then
    printf '  ok    %-22s %s reads clean on all three shapes — the arms discriminate rather than refusing every edit\n' "$n" "$what"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s %s is a CORRECT fix and the shapes rejected it:%s — the arms are keyed on the placement, not on the property\n' "$n" "$what" "$bad"
  fi
}
# The shipped tree, copied whole so it is driven through the SAME scorer as every mutant. Not
# read off $OUT: a scorer applied to one input and a verdict read from another are two programs.
# $SFX_SHIPPED is built above, where the wreckage probe needs it as its negative direction.
sfx_pass acquit-shipped "$SFX_SHIPPED" \
  "the reset immediately after the loop (as shipped)"
sfx_pass acquit-before-if "$(sfx_mutant before-if '/^if \[ "\$\{th_undecided:-0\}" -gt 0 \]; then$/ { print "RSFX=\"\""; print; next }')" \
  "the reset moved down to just above the undecided if"
sfx_pass acquit-cond-ord "$(sfx_mutant cond-ord '/^done < "\$LR_STAGE\/entries"$/ { print; print "case \"${ord:-}\" in 1\/1|\"\") RSFX=\"\" ;; esac"; next }')" \
  "a reset guarded on the leftover ordinal, which read fires unconditionally clears at EOF"

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
row_is "PC-FIXTURE-LITERAL-BACKSLASH" NEEDS-REVIEW \
  "an anchor whose backslashes are the source text is refused too — the stated limit, pinned"
detail_has "PC-FIXTURE-LITERAL-BACKSLASH" "contains a backslash" \
  "and it is refused for the backslash, with the re-anchor remedy"
row_is "PC-FIXTURE-REGEX-ANCHOR" NEEDS-REVIEW \
  "a regex escape is a backslash like any other — theirs_lacks is refused on the same rule"
detail_has "PC-FIXTURE-REGEX-ANCHOR" "contains a backslash" \
  "and says so"
# THE THREE SHAPES THE ADVERSARIAL HAND ADDED, each the seed that separates the shipped guard
# from a narrower one that passed every single-anchor arm above.
row_is "PC-FIXTURE-SECOND-SUBSTRING" NEEDS-REVIEW \
  "a backslash in the SECOND of two anchors is refused — the whole quoted run is covered, not its first member"
detail_has "PC-FIXTURE-SECOND-SUBSTRING" "contains a backslash" \
  "and for the backslash, not for the multi-anchor shape"
row_is "PC-FIXTURE-ESCAPED-QUOTE" NEEDS-REVIEW \
  "a backslash before a double quote is refused — the rule is any backslash, not the two escapes the other seeds use"
detail_has "PC-FIXTURE-ESCAPED-QUOTE" "contains a backslash" \
  "and says so"
row_is "PC-FIXTURE-ESCAPED-PATH" NEEDS-REVIEW \
  "a markdown-escaped PATH is refused before the basename fallback can guess it right"
detail_has "PC-FIXTURE-ESCAPED-PATH" "the path" \
  "and the row names the PATH as the field at fault"
row_is "PC-FIXTURE-CLEAN-PATH" CLOSE-CANDIDATE \
  "the same receipt with the path bare closes: the underscore is not what is refused, and the token discriminates"
row_is "PC-FIXTURE-ESCAPED-ON-MISSING-PATH" NEEDS-REVIEW \
  "an escaped anchor on an unresolvable path is still a refusal"
detail_has "PC-FIXTURE-ESCAPED-ON-MISSING-PATH" "contains a backslash" \
  "and it is refused for the BACKSLASH — the guard sits before path resolution, so the missing path does not pre-empt it"
detail_has "Entry I" "does not resolve" \
  "the near-miss: a clean anchor on a missing path still reads as an unresolvable path"
# THE REMEDY IS PART OF THE ROW. A refusal that names the fault and not the fix sends the author
# to guess, and the adversarial hand's one-clause variant passed every arm above.
detail_has "PC-FIXTURE-ESCAPED-BACKTICK" "Write backticks and quotes bare" \
  "the anchor row carries its remedy"
detail_has "PC-FIXTURE-ESCAPED-BACKTICK" "verify: sh" \
  "and names the escape hatch for text that genuinely contains a backslash"
detail_has "PC-FIXTURE-ESCAPED-PATH" "Write the path bare" \
  "the path row carries its remedy"
# THE ESCAPE HATCH IS PINNED. The scope hand built a guard refusing a backslash for EVERY verb;
# the receipt as first written accepted it, and it would silence fifteen of the reference
# consumer's thirty-six live `sh` receipts. An `sh` receipt is a program and its backslashes
# are its own.
row_is "PC-FIXTURE-SH-WITH-BACKSLASH" STILL-LIVE \
  "an sh receipt carrying a backslash is EVALUATED, not refused — the remedy the refusal row offers exists"

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
row_is "PC-FIXTURE-SH-TWO-LINE" NEEDS-REVIEW \
  "a receipt cut inside its quote is refused, not evaluated"
detail_has "PC-FIXTURE-SH-TWO-LINE" "MALFORMED sh receipt" \
  "and the refusal names the cause"
detail_has "PC-FIXTURE-SH-TWO-LINE" "Rewrite the receipt on one line" \
  "and carries its remedy"
row_lacks "PC-FIXTURE-SH-TWO-LINE" CLOSE-CANDIDATE \
  "the syntax error's exit 2 must never read as an absorption"
row_is "PC-FIXTURE-SH-TRAILING-COMMENT" STILL-LIVE \
  "a valid receipt ending in a comment is evaluated under the wrapper — the guard parses the string that RUNS, and the wrapper closes on its own line"
# THE TWO SHAPES A BARE PARSE ACQUITS. A trailing backslash and an open heredoc both parse clean
# as one-line fragments on bash 3.2; the second wrapper line is what turns each into a syntax
# error. The backslash fragment EXITS 0, so without the wrap it read STILL-LIVE here and a CLOSE
# on the distribution engine — a verdict from half a receipt either way.
row_is "PC-FIXTURE-SH-TRAILING-BACKSLASH" NEEDS-REVIEW \
  "a receipt cut after a trailing backslash is refused — the closer line becomes the continuation"
detail_has "PC-FIXTURE-SH-TRAILING-BACKSLASH" "MALFORMED sh receipt" \
  "and the refusal names the cause"
row_is "PC-FIXTURE-SH-OPEN-HEREDOC" NEEDS-REVIEW \
  "a receipt cut after a heredoc opener is refused — the closer line becomes heredoc body"

# THREE MUTANTS, each on a whole-directory copy so the closer finds its siblings, each scored
# on the full seeded ledger because the two subjects sit outside the tiny backslash ledger.
# The kill is a status FLIP on the two-line entry; the control is the trailing-comment entry
# still reading STILL-LIVE (or, for the wrapper mutant, the two-line entry still refused), so a
# mutant that broke the parser rather than the guard cannot score.
tl_mutant() { # <name> <awk-program> -> dir on stdout, empty if the program changed nothing
  local n="$1" prog="$2" d
  d="$(dirname "$DIST")/mut-$n"; rm -rf "$d"; mkdir -p "$d"
  cp "$(dirname "$CLOSER")"/*.sh "$d/" 2>/dev/null
  awk "$prog" "$CLOSER" > "$d/ledger-reverify.sh" || return 1
  if cmp -s "$CLOSER" "$d/ledger-reverify.sh"; then return 1; fi
  printf '%s' "$d"
}
tl_kill() { # <name> <dir-or-empty> <kill-awk> <control-awk> <kill-msg> <ctl-msg>
  local n="$1" d="$2" kill="$3" ctl="$4" kmsg="$5" cmsg="$6" out
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ -z "$d" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutation DID NOT APPLY (matched nothing, or awk died), so the arm it targets is unproven\n' "$n"
    return
  fi
  out="$(bash "$d/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  if ! printf '%s\n' "$out" | awk -F'\t' "$ctl"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the control row is gone too (%s) — the mutant broke the closer rather than the guard, so its verdict is wreckage\n' "$n" "$cmsg"
    printf '%s\n' "$out" | grep -E 'PC-FIXTURE-SH-' | sed 's/^/          | /'
  elif printf '%s\n' "$out" | awk -F'\t' "$kill"; then
    printf '  ok    %-22s %s\n' "$n" "$kmsg"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the guard was changed and the arm it protects did NOT change verdict — that arm cannot fire\n' "$n"
    printf '%s\n' "$out" | grep -E 'PC-FIXTURE-SH-' | sed 's/^/          | /'
  fi
}
# The three anchors are asserted UNIQUE first: a mutation that matched two sites would edit a
# line this fixture never reads and score a kill it did not earn.
ASSERTIONS=$((ASSERTIONS + 1))
tl_g="$(grep -c '^ *if ! bash -n -c "\$sh_prog" >/dev/null 2>&1; then$' "$CLOSER")" || tl_g=0
tl_p="$(grep -c '^ *sh_prog="cd \\"\$CONSUMER\\" && { \$rest$' "$CLOSER")" || tl_p=0
tl_r="$(grep -c '^ *bash -c "\$sh_prog" </dev/null >/dev/null 2>&1$' "$CLOSER")" || tl_r=0
if [ "$tl_g" -eq 1 ] && [ "$tl_p" -eq 1 ] && [ "$tl_r" -eq 1 ]; then
  printf '  ok    %-22s the parse guard, the wrapper assignment and the run line are each unique in the closer\n' "sh-parse-anchors"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s guard=%s wrapper=%s run=%s — the mutations below anchor on these and need exactly one each\n' "sh-parse-anchors" "$tl_g" "$tl_p" "$tl_r"
fi
# 1. THE GUARD DISARMED: `bash -n` replaced by `true`, so every receipt is evaluated. The two-line
#    entry regresses to the filed CLOSE-CANDIDATE — the false close this guard exists to stop.
tl_kill mutation-sh-no-parse \
  "$(tl_mutant sh-no-parse '/^ *if ! bash -n -c "\$sh_prog" >\/dev\/null 2>&1; then$/ { sub(/bash -n -c "\$sh_prog"/, "true") } { print }')" \
  '$2 ~ /PC-FIXTURE-SH-TWO-LINE/ && $1=="CLOSE-CANDIDATE" {f=1} END{exit !f}' \
  '$2 ~ /PC-FIXTURE-SH-TRAILING-COMMENT/ && $1=="STILL-LIVE" {f=1} END{exit !f}' \
  "with the parse guard disarmed the two-line receipt CLOSES again — the guard is what stops the false close" \
  "PC-FIXTURE-SH-TRAILING-COMMENT STILL-LIVE"
# 2. THE WRONG STRING PARSED: the guard checks the BARE receipt rather than the wrapped program.
#    The trailing-comment receipt then passes the guard, the wrapper is rebuilt on one line with
#    `; }` glued to the comment, and the entry regresses to CLOSE-CANDIDATE through exit 2.
tl_kill mutation-sh-parse-bare \
  "$(tl_mutant sh-parse-bare '/^ *if ! bash -n -c "\$sh_prog" >\/dev\/null 2>&1; then$/ { sub(/"\$sh_prog"/, "\"$rest\"") } /^ *sh_prog="cd \\"\$CONSUMER\\" && { \$rest$/ { print "      sh_prog=\"cd \\\"$CONSUMER\\\" && { $rest; }\""; skip = 1; next } skip == 1 { skip = 0; if ($0 == "}\"") next } { print }')" \
  '$2 ~ /PC-FIXTURE-SH-TRAILING-COMMENT/ && $1=="CLOSE-CANDIDATE" {f=1} END{exit !f}' \
  '$2 ~ /PC-FIXTURE-SH-TWO-LINE/ && $1=="NEEDS-REVIEW" && index($3,"MALFORMED")>0 {f=1} END{exit !f}' \
  "parsing the bare receipt instead of the wrapped program lets the comment break the one-line wrapper and the entry CLOSES — the guard must parse the string that runs" \
  "PC-FIXTURE-SH-TWO-LINE refused MALFORMED"
# 3. THE GUARD INVERTED: a receipt that PARSES is refused and one that does not is run. Both
#    seeds flip — the control here is that the run still produced rows for both, so a dead
#    closer cannot score this as a kill.
tl_kill mutation-sh-parse-inverted \
  "$(tl_mutant sh-parse-inverted '/^ *if ! bash -n -c "\$sh_prog" >\/dev\/null 2>&1; then$/ { sub(/if ! bash/, "if bash") } { print }')" \
  '$2 ~ /PC-FIXTURE-SH-TRAILING-COMMENT/ && $1=="NEEDS-REVIEW" {f=1} END{exit !f}' \
  '$2 ~ /PC-FIXTURE-SH-TWO-LINE/ {f=1} $2 ~ /PC-FIXTURE-SH-TRAILING-COMMENT/ {g=1} END{exit !(f && g)}' \
  "with the guard inverted the valid receipt is refused — the arm reads the guard's polarity, not merely its presence" \
  "both sh seeds still produce a row"

# SIX MUTANTS ON A TINY LEDGER. Each runs the closer over ONLY the eight backslash entries, cut
# from the seeded ledger by heading so the receipts are not restated here, because a full-ledger
# run is what makes this fixture the suite's third-longest unit. Each mutation is anchored on
# one of the two `case` SUBJECT lines (`case "$path" in`, `case "$sub" in`), asserted UNIQUE
# below so a second copy cannot be edited by accident — the pattern line beneath them is shared
# by both guards and is reached by state, never matched on its own. `cmp -s` refuses a program
# that changed nothing; and each kill requires a control row to SURVIVE, so a mutant that broke
# the parser cannot score as a kill.
LED_SEEDED="$CONS/_bmad-output/ai-dlc-update/push-candidate-ledger.md"
TINY="$(dirname "$DIST")/tiny-backslash-ledger.md"
awk '/^## PC-FIXTURE-ESCAPED-BACKTICK/{p=1} /^## PC-FIXTURE-EOF-FENCE/{p=0} p' "$LED_SEEDED" > "$TINY"
ASSERTIONS=$((ASSERTIONS + 1))
tiny_n="$(grep -c '^## PC-FIXTURE-' "$TINY")" || tiny_n=0
if [ "$tiny_n" -eq 10 ]; then
  printf '  ok    %-22s the tiny ledger carries exactly the ten backslash entries\n' "tiny-ledger"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the tiny ledger carries %s entries, not 10 — the mutants below would run over the wrong corpus\n' "tiny-ledger" "$tiny_n"
fi
ASSERTIONS=$((ASSERTIONS + 1))
sub_n="$(grep -c '^ *case "\$sub" in$' "$CLOSER")" || sub_n=0
path_n="$(grep -c '^ *case "\$path" in$' "$CLOSER")" || path_n=0
if [ "$sub_n" -eq 1 ] && [ "$path_n" -eq 1 ]; then
  printf '  ok    %-22s the two guard case-subject lines are each unique in the closer (the mutation anchors)\n' "guard-anchor"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s %s `case "$sub" in` and %s `case "$path" in` lines; the mutations below anchor on them and need exactly one each\n' "guard-anchor" "$sub_n" "$path_n"
fi
# THE UNMUTATED CONTROL, with a positive conjunct: the same tiny ledger through the shipped closer
# must produce the refusal row AND the close, or every kill below is scored against wreckage.
tiny_out="$(bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$TINY" 2>&1)"
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$tiny_out" | awk -F'\t' '$2 ~ /PC-FIXTURE-ESCAPED-BACKTICK/ && $1=="NEEDS-REVIEW" && index($3,"contains a backslash")>0 {a=1} $2 ~ /PC-FIXTURE-BARE-BACKTICK/ && $1=="CLOSE-CANDIDATE" {b=1} END{exit !(a && b)}'; then
  printf '  ok    %-22s unmutated closer on the tiny ledger: escaped refused with the backslash reason, bare closes\n' "tiny-control"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the unmutated closer does not reproduce the two baseline rows on the tiny ledger — the mutant kills below are unreadable\n' "tiny-control"
  printf '%s\n' "$tiny_out" | sed 's/^/          | /'
fi
bs_mutant() { # <name> <awk-program>  -> dir on stdout, empty if the program changed nothing
  local n="$1" prog="$2" d
  d="$(dirname "$DIST")/mut-$n"; rm -rf "$d"; mkdir -p "$d"
  cp "$(dirname "$CLOSER")"/*.sh "$d/" 2>/dev/null
  awk "$prog" "$CLOSER" > "$d/ledger-reverify.sh" || return 1
  if cmp -s "$CLOSER" "$d/ledger-reverify.sh"; then return 1; fi
  printf '%s' "$d"
}
bs_kill() { # <name> <dir-or-empty> <kill-awk> <control-awk> <kill-msg> <ctl-msg>
  local n="$1" d="$2" kill="$3" ctl="$4" kmsg="$5" cmsg="$6" out
  ASSERTIONS=$((ASSERTIONS + 1))
  if [ -z "$d" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the mutation DID NOT APPLY (matched nothing, or awk died), so the arm it targets is unproven\n' "$n"
    return
  fi
  out="$(bash "$d/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" "$TINY" 2>&1)"
  if ! printf '%s\n' "$out" | awk -F'\t' "$ctl"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the control row is gone too (%s) — the mutant broke the closer rather than the guard, so its verdict is wreckage\n' "$n" "$cmsg"
    printf '%s\n' "$out" | sed 's/^/          | /'
  elif printf '%s\n' "$out" | awk -F'\t' "$kill"; then
    printf '  ok    %-22s %s\n' "$n" "$kmsg"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the guard was changed and the arm it protects did NOT change verdict — that arm cannot fire\n' "$n"
    printf '%s\n' "$out" | sed 's/^/          | /'
  fi
}
# THE ARM'S OWN MUTANT: the anchor guard's subject emptied, so its pattern can never match. The
# escaped receipt is searched for literally again and the filed wrong reason comes back.
bs_kill mutation-bs-no-guard \
  "$(bs_mutant bs-no-guard '/^ *case "\$sub" in$/ { $0 = "      case \"\" in" } { print }')" \
  '$2 ~ /PC-FIXTURE-ESCAPED-BACKTICK/ && index($3,"vacuous predicate")>0 {f=1} END{exit !f}' \
  '$2 ~ /PC-FIXTURE-BARE-BACKTICK/ && $1=="CLOSE-CANDIDATE" {f=1} END{exit !f}' \
  "with the anchor guard disarmed the escaped receipt reads \"vacuous predicate\" again — the refusal is load-bearing" \
  "PC-FIXTURE-BARE-BACKTICK CLOSE-CANDIDATE"
# THE FIRST WRONG FIX: unescape backslash-backtick and drop the guard. The escaped receipt then
# CLOSES, which is the filing's reading (b) -- and the shape the literal-backslash entry shows to
# be a guess. The inserted line is passed through ENVIRON so no layer reprocesses its backslash.
UNESC_LINE='      sub="$(printf '"'"'%s'"'"' "$sub" | sed '"'"'s/\\`/`/g'"'"')"'
export UNESC_LINE
bs_kill mutation-bs-unescape \
  "$(bs_mutant bs-unescape '/^ *case "\$sub" in$/ { $0 = "      case \"\" in" } /^      subs="\$\(printf/ { print ENVIRON["UNESC_LINE"] } { print }')" \
  '$2 ~ /PC-FIXTURE-ESCAPED-BACKTICK/ && $1=="CLOSE-CANDIDATE" {f=1} END{exit !f}' \
  '$2 ~ /PC-FIXTURE-BARE-BACKTICK/ && $1=="CLOSE-CANDIDATE" {f=1} END{exit !f}' \
  "an unescaping reader closes the escaped receipt — the arm sees the guess the fix refuses to make" \
  "PC-FIXTURE-BARE-BACKTICK CLOSE-CANDIDATE"
# THE SECOND WRONG FIX: refuse only backslash-BACKTICK. The pattern line is reached by state from
# the anchor guard's subject line, so the path guard's identical pattern is left alone. The regex
# anchor is then searched for literally, matches nothing at either ref, and theirs_lacks reads
# STILL-LIVE with reachability unchecked (this consumer root has no tracked-file list) — a
# positive verdict, not an absence.
bs_kill mutation-bs-backtick-only \
  "$(bs_mutant bs-backtick-only 'BEGIN { BS = sprintf("%c", 92); BT = sprintf("%c", 96) } /^ *case "\$sub" in$/ { f = 1 } f && $0 ~ /^ *\*\\\\\*\)$/ { $0 = "        *" BS BS BS BT "*)"; f = 0 } { print }')" \
  '$2 ~ /PC-FIXTURE-REGEX-ANCHOR/ && $1=="STILL-LIVE" {f=1} END{exit !f}' \
  '$2 ~ /PC-FIXTURE-ESCAPED-BACKTICK/ && $1=="NEEDS-REVIEW" && index($3,"contains a backslash")>0 {f=1} END{exit !f}' \
  "a backtick-only guard lets the regex anchor through and it reads STILL-LIVE forever — any backslash is the rule" \
  "PC-FIXTURE-ESCAPED-BACKTICK refused with the backslash reason"
# THE THIRD WRONG FIX, the adversarial hand's BLOCKER: a guard that tests only the FIRST quoted
# substring. It passed every single-anchor arm and the receipt as first shipped, and on the
# two-anchor seed it manufactures a CLOSE-CANDIDATE on an anchor the rule says cannot be decided.
bs_kill mutation-bs-first-only \
  "$(bs_mutant bs-first-only 'BEGIN { BS = sprintf("%c", 92) } /^ *case "\$sub" in$/ { $0 = "      case \"${sub%%" BS "\"*}\" in" } { print }')" \
  '$2 ~ /PC-FIXTURE-SECOND-SUBSTRING/ && $1=="CLOSE-CANDIDATE" {f=1} END{exit !f}' \
  '$2 ~ /PC-FIXTURE-BARE-BACKTICK/ && $1=="CLOSE-CANDIDATE" {f=1} END{exit !f}' \
  "a first-substring-only guard CLOSES the two-anchor entry whose second anchor carries the backslash — the whole run is what the guard reads" \
  "PC-FIXTURE-BARE-BACKTICK CLOSE-CANDIDATE"
# THE FOURTH WRONG FIX: refuse only the two escapes the first four seeds happen to use (backtick
# and dot). The escaped-quote receipt is searched for literally and reads vacuous.
bs_kill mutation-bs-two-escapes \
  "$(bs_mutant bs-two-escapes 'BEGIN { BS = sprintf("%c", 92); BT = sprintf("%c", 96) } /^ *case "\$sub" in$/ { f = 1 } f && $0 ~ /^ *\*\\\\\*\)$/ { $0 = "        *" BS BS BS BT "*|*" BS BS ".*)"; f = 0 } { print }')" \
  '$2 ~ /PC-FIXTURE-ESCAPED-QUOTE/ && index($3,"vacuous predicate")>0 {f=1} END{exit !f}' \
  '$2 ~ /PC-FIXTURE-REGEX-ANCHOR/ && $1=="NEEDS-REVIEW" && index($3,"contains a backslash")>0 {f=1} END{exit !f}' \
  "a backtick-or-dot guard lets the escaped quote through and it reads vacuous — the rule is any backslash" \
  "PC-FIXTURE-REGEX-ANCHOR still refused"
# THE PATH GUARD'S OWN MUTANT: its subject emptied. The escaped path falls to the basename
# fallback, whose awk -v strips the backslash, and the entry CLOSES on a path nobody wrote.
bs_kill mutation-bs-no-path-guard \
  "$(bs_mutant bs-no-path-guard '/^ *case "\$path" in$/ { $0 = "      case \"\" in" } { print }')" \
  '$2 ~ /PC-FIXTURE-ESCAPED-PATH/ && $1=="CLOSE-CANDIDATE" {f=1} END{exit !f}' \
  '$2 ~ /PC-FIXTURE-CLEAN-PATH/ && $1=="CLOSE-CANDIDATE" {f=1} END{exit !f}' \
  "without the path guard the escaped path is guessed right by basename and the entry CLOSES — the guard is what stops the guess" \
  "PC-FIXTURE-CLEAN-PATH CLOSE-CANDIDATE"
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
  printf '  ok    %-22s the checkout reads %s and theirs reads %s — a $DIST path read and a rev-spec read return DIFFERENT bytes, so the arms below can discriminate\n' \
    "checkout-past-theirs" "$dist_head_v" "$dist_theirs_v"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the checkout (%s) and theirs (%s) read the same VERSION, so every $DIST-as-path arm below passes for the wrong reason and proves nothing\n' \
    "checkout-past-theirs" "${dist_head_v:-<none>}" "${dist_theirs_v:-<none>}"
fi

# A. $THEIRS_TREE IS A TREE AT THEIRS. A positive outcome, not the absence of a failure: the
# receipt demands the tree read 0.103.0, so a mutant binding THEIRS_TREE to $DIST reads 0.104.0
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
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s no receipt recorded a $THEIRS_TREE path, so the materializer never ran and this arm has no subject\n' "theirs-tree-cleanup"
elif [ -d "$tt_path" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the materialized tree %s SURVIVED the run — the EXIT trap did not remove it, and a pool twelve-wide leaks one per invocation with no symptom\n' "theirs-tree-cleanup" "$tt_path"
else
  printf '  ok    %-22s the materialized tree was removed on EXIT (recorded path is gone, and the receipt asserted it existed while running)\n' "theirs-tree-cleanup"
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
row_is "Entry SH-THEIRS-TREE-BRACED" STILL-LIVE \
  "\${THEIRS_TREE} braced reaches the upstream-consulting partition; without its own alternation it falls into the falsifiability branch"
row_lacks "Entry SH-THEIRS-TREE-BRACED" NEEDS-REVIEW \
  "and is never filed as an unfalsifiable receipt — it consults theirs"
# THE STATUS CANNOT SEE THIS ONE. Both partitions emit STILL-LIVE for a receipt naming no
# path-shaped subject, so the arm reads the DETAIL, which is where they diverge: the upstream
# partition says only "still reproduces", the falsifiability branch appends "falsifiability NOT
# checked". A status-only assertion here passes against the very mutant written to kill it.
detail_lacks "Entry SH-THEIRS-TREE-BRACED" "falsifiability NOT checked" \
  "and it is decided by the UPSTREAM partition, not by the consumer-only branch that cannot settle it"
# ...and the braced receipt that ALSO names an upstream-shipped subject diverges by STATUS, not
# merely by detail. The entry above names no path-shaped subject, so both partitions reach
# STILL-LIVE and only the wording separates them; this one resolves through the derived
# consumer->core table, so the falsifiability branch ACCUSES it. Two observables for one
# property, and the status-keyed one is the half a detail-only arm cannot supply.
row_is "Entry SH-THEIRS-TREE-BRACED-SUBJECT" STILL-LIVE \
  "a braced \$THEIRS_TREE receipt naming an upstream-shipped subject is decided by the upstream partition"
row_lacks "Entry SH-THEIRS-TREE-BRACED-SUBJECT" NEEDS-REVIEW \
  "and is never accused of being unfalsifiable — it reads theirs through the materialized tree"

# B. $DIST READ AS A PATH IS REFUSED — both consumer shapes, and both exit directions.
row_is "Entry SH-DIST-AS-PATH " NEEDS-REVIEW \
  "the slash shape (\$DIST/VERSION) is refused, not scored"
detail_has "Entry SH-DIST-AS-PATH " "reads \$DIST as a filesystem path" \
  "and the refusal names the cause"
detail_has "Entry SH-DIST-AS-PATH " "THEIRS_TREE" \
  "and its remedy names the value that IS path-readable"
row_is "Entry SH-DIST-AS-ENV" NEEDS-REVIEW \
  "the no-slash shape (AI_DLC_PROJECT_ROOT=\"\$DIST\") is refused — this is the shape BOTH live consumer offenders were written in"
row_is "Entry SH-DIST-AS-PATH-ZERO" NEEDS-REVIEW \
  "a \$DIST path read that EXITS 0 is refused too — a refusal sited after the run leaves this one as a healthy-looking STILL-LIVE"
# C. A CONFORMING RECEIPT IS BYTE-UNCHANGED. 26 of the reference consumer's 28 `$DIST`-naming
# receipts are the `git -C` form, so a grammar that flagged every mention of `$DIST` would file 26
# healthy receipts as broken. Both spellings, because `$DIST` is not a substring of `${DIST}`.
row_is "Entry SH-DIST-REVSPEC " STILL-LIVE \
  "git -C \"\$DIST\" show \"\${THEIRS}:...\" is the conforming form and is untouched"
row_is "Entry SH-DIST-REVSPEC-BRACED" STILL-LIVE \
  "git -C \"\${DIST}\" is the spelling this distribution's rev-path rule REQUIRES and is untouched"
# ...and the `cd "$DIST" && git` form, which the reference consumer's ARCHIVE carries six of.
# Its NEAR-MISS sits one property apart — same `cd "$DIST"`, no `git` after it — so an exemption
# that acquits the good form without requiring the `git ` acquits its own arm's subject too.
row_is "Entry SH-DIST-CD-GIT" STILL-LIVE \
  "cd \"\$DIST\" && git show \"\${THEIRS}:...\" reads the same blob as git -C and is accepted"
row_is "Entry SH-DIST-CD-BARE" NEEDS-REVIEW \
  "a bare cd \"\$DIST\" NOT followed by git reads the CHECKOUT and is refused — the exemption requires the git that follows"

# THE `NAMED-UPSTREAM` ROW SURVIVES A REFUSAL. That row is emitted above the verb dispatch and is
# a signal about the ENTRY; a refusal that took it with it would silence the highest-value pair
# this tool prints. Both halves asserted on one entry: the receipt is refused AND the name stands.
row_has "PC-S907-NAMED-UPSTREAM-SURVIVES" NEEDS-REVIEW \
  "the entry's \$DIST-path receipt is refused"
row_has "PC-S907-NAMED-UPSTREAM-SURVIVES" NAMED-UPSTREAM \
  "and its NAMED-UPSTREAM row still stands — the refusal continues past the verb dispatch, it does not abandon the entry"

# THE BASE READING, and it is what proves the refusal discriminates rather than being the only
# behaviour ever measured. The two exit-1 offenders are scored by a closer without the guard, and
# both come back CLOSE-CANDIDATE — the false close, reproduced here on demand.
dp_base="$(dirname "$DIST")/mut-dist-base"
rm -rf "$dp_base"; mkdir -p "$dp_base"
cp "$(dirname "$CLOSER")"/*.sh "$dp_base/" 2>/dev/null
awk '/^      if receipt_reads_dist_as_path "\$rest"; then$/ { $0 = "      if false; then" } { print }' \
  "$CLOSER" > "$dp_base/ledger-reverify.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$dp_base/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the base build DID NOT APPLY (the refusal call site did not match), so the base reading below is the tip reading\n' "dist-base-build"
  dp_base=""
else
  printf '  ok    %-22s base build differs from the tip (cmp -s), so the two sides of this differential are two programs\n' "dist-base-build"
fi
if [ -n "$dp_base" ]; then
  dp_out="$(bash "$dp_base/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  ASSERTIONS=$((ASSERTIONS + 1))
  if printf '%s\n' "$dp_out" | awk -F'\t' '$2 ~ /SH-DIST-AS-PATH / && $1=="CLOSE-CANDIDATE" {a=1} $2 ~ /SH-DIST-AS-ENV/ && $1=="CLOSE-CANDIDATE" {b=1} $2 ~ /SH-DIST-REVSPEC / && $1=="STILL-LIVE" {c=1} END{exit !(a && b && c)}'; then
    printf '  ok    %-22s without the refusal BOTH $DIST-path receipts read CLOSE-CANDIDATE — the measured false close, reproduced — while the git -C control stays STILL-LIVE\n' "dist-base-reading"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the base reading is not the false close this fix exists for, so the tip verdicts above are not evidence the refusal changed anything\n' "dist-base-reading"
    printf '%s\n' "$dp_out" | grep -E 'SH-DIST-AS|SH-DIST-REVSPEC' | sed 's/^/          | /'
  fi
fi

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
# THE ARM IS A FUNCTION OF THE CLOSER so the committed leak mutant below drives this exact logic,
# not a restatement of it. Prints the verdict line; returns 1 on FAIL.
lz_verdict() { # <closer>
  local c="$1" before after delta out
  before="$(tt_count)"
  out="$(TMPDIR="$LZ_TMP" bash "$c" "$DIST" "$BASE" "$CONS" "$THEIRS" "$LED_NOTREE" 2>&1)"
  after="$(tt_count)"
  delta=$((after - before))
  if ! printf '%s\n' "$out" | awk -F'\t' '$2 ~ /NOTREE-B/ && $1=="STILL-LIVE" {f=1} END{exit !f}'; then
    printf '  FAIL  %-22s the tree-free ledger produced no control row, so this run establishes nothing about laziness\n' "theirs-tree-lazy"
    printf '%s\n' "$out" | sed 's/^/          | /'
    return 1
  elif grep -q THEIRS_TREE <<<"$out"; then
    printf '  FAIL  %-22s a ledger naming no $THEIRS_TREE receipt still produced a row mentioning the materializer\n' "theirs-tree-lazy"
    printf '%s\n' "$out" | sed 's/^/          | /'
    return 1
  elif [ "$delta" -ne 0 ]; then
    printf '  FAIL  %-22s this engine left %+d of its own theirs-trees behind across a ledger with no $THEIRS_TREE receipt — something was materialized and not cleaned\n' "theirs-tree-lazy" "$delta"
    return 1
  fi
  printf '  ok    %-22s a ledger with no $THEIRS_TREE receipt materializes nothing (no materializer row, this engine'"'"'s own theirs-tree count delta %+d) while its control row still reports\n' "theirs-tree-lazy" "$delta"
}
ASSERTIONS=$((ASSERTIONS + 1))
lz_verdict "$CLOSER" || FAILURES=$((FAILURES + 1))
# THE OTHER DIRECTION, AND WITHOUT IT THE ARM ABOVE IS SATISFIED BY A PREFIX NOTHING EVER USES.
# A count that is always zero reads exactly like a count that is correctly zero, so the same
# counter must be shown to RISE while a $THEIRS_TREE receipt is being evaluated. The receipt
# itself is the observer: it records the tree's path while the tree is live, so the presence of
# a directory carrying this engine's prefix at that moment is what the count would have seen.
ASSERTIONS=$((ASSERTIONS + 1))
tt_live="$(cat "$CONS/theirs-tree-path.txt" 2>/dev/null)"
case "$tt_live" in
  */ledger-reverify-theirs.*)
    printf '  ok    %-22s a run WITH a $THEIRS_TREE receipt builds a tree carrying this engine'"'"'s own prefix (%s), so the zero above is a measured zero and not an unused counter\n' \
      "theirs-tree-prefix" "$(basename "$tt_live")" ;;
  *)
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the materialized tree does not carry this engine'"'"'s prefix (%s), so the laziness counter above can never rise and its zero establishes nothing\n' \
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
TMPDIR="$LZ_TMP" bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$THEIRS" "$LED_INTREE" >/dev/null 2>&1
lz_live="$(cat "$CONS/lz-tree-path.txt" 2>/dev/null)"
rm -f "$CONS/lz-tree-path.txt"
ASSERTIONS=$((ASSERTIONS + 1))
case "$lz_live" in
  "$LZ_TMP"/ledger-reverify-theirs.*)
    printf '  ok    %-22s under TMPDIR=<private dir> the tree is materialized INSIDE it (%s), so the laziness count reads the directory the engine actually writes\n' \
      "theirs-tree-prefix" "$(basename "$lz_live")" ;;
  *)
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s under TMPDIR=%s the tree was recorded at %s — a TMPDIR the engine ignores would leave the laziness counter reading 0 forever, so its zero establishes nothing\n' \
      "theirs-tree-prefix" "$LZ_TMP" "${lz_live:-<none recorded>}" ;;
esac

# --- SIX MUTANTS, EACH KILLED BY THE ARM THAT OWNS IT -----------------------------------------
#
# Each is a whole-DIRECTORY copy so the closer finds `lib.sh` and `preclassify.sh` beside it — a
# lone copy dies sourcing lib.sh, emits nothing, and "no output" otherwise scores as a kill. Each
# carries a `cmp -s` control proving the mutation applied, and each kill REQUIRES a control row to
# survive, so a mutant that broke the closer rather than the guard cannot score. The anchors are
# asserted unique first: a mutation matching two sites edits a line no arm reads.
dp_anchors_bad=""
for a in \
  'if receipt_reads_dist_as_path "$rest"; then' \
  '_RD_GITC3='"'"'git -C "$DIST"'"'"'' \
  '_RD_CD3='"'"'cd "$DIST" && git '"'"'' \
  '  THEIRS_TREE="$_d"' \
  '  [ -n "${THEIRS_TREE_OWNED:-}" ] && rm -rf "$THEIRS_TREE_OWNED"' \
  '        *THEIRS_TREE*)' ; do
  n="$(grep -cF "$a" "$CLOSER")" || n=0
  [ "$n" -eq 1 ] || dp_anchors_bad="$dp_anchors_bad [$a -> $n]"
done
# THE CONTROL: a token no closer carries. Without it a grep that had silently stopped matching
# everything would read as "all anchors unique" — the same zero a clean corpus produces.
dp_ctl_n="$(grep -cF 'ZZ-NO-SUCH-ANCHOR-EVER-IN-THIS-FILE' "$CLOSER")" || dp_ctl_n=0
ASSERTIONS=$((ASSERTIONS + 1))
if [ -z "$dp_anchors_bad" ] && [ "$dp_ctl_n" -eq 0 ]; then
  printf '  ok    %-22s all six mutation anchors are UNIQUE in the closer (control: an impossible anchor returns %s)\n' "dist-anchors" "$dp_ctl_n"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s a mutation anchor is not unique (%s) or the impossible control matched (%s); the mutants below would edit a line no arm reads and score kills they did not earn\n' "dist-anchors" "${dp_anchors_bad:-none}" "$dp_ctl_n"
fi
# m1 — THEIRS_TREE bound to $DIST. Killed by arm A: the tree then reads the checkout (0.104.0),
# the receipt's equality against 0.103.0 fails, and the entry closes on a ref nobody pulled.
#
# THIS MUTANT IS ALSO WHY THE EXIT HANDLER REMOVES `$THEIRS_TREE_OWNED` AND NOT `$THEIRS_TREE`.
# Written against a handler keyed on `$THEIRS_TREE`, it made the closer `rm -rf` the fixture's own
# DISTRIBUTION REPOSITORY on exit, and six arms downstream failed with symptoms that pointed at
# the guard rather than at the `rm`. The mutation is unchanged; the subject was fixed.
dp_m1="$(dp_mutant tt-is-dist '  THEIRS_TREE="$_d"' '  THEIRS_TREE="$DIST"')"
dp_kill mutation-tt-is-dist "$dp_m1" \
  '$2 ~ /SH-THEIRS-TREE / && $1=="CLOSE-CANDIDATE" {f=1} END{exit !f}' \
  '$2 ~ /SH-DIST-REVSPEC / && $1=="STILL-LIVE" {f=1} END{exit !f}' \
  'THEIRS_TREE bound to $DIST reads the CHECKOUT and the entry closes on a ref nobody pulled — arm A reads the tree'"'"'s CONTENT, not its existence' \
  'SH-DIST-REVSPEC STILL-LIVE'
# m2 — the refusal keyed on `$DIST/` only. Killed by arm B's no-slash entry, which is the shape
# BOTH live consumer offenders were written in; the slash entry alone would score this green.
dp_m2="$(dp_mutant refuse-slash-only '    *'"'"'$DIST'"'"'*|*'"'"'${DIST}'"'"'*) return 0 ;;' '    *'"'"'$DIST/'"'"'*|*'"'"'${DIST}/'"'"'*) return 0 ;;')"
dp_kill mutation-refuse-slash-only "$dp_m2" \
  '$2 ~ /SH-DIST-AS-ENV/ && $1!="NEEDS-REVIEW" {f=1} END{exit !f}' \
  '$2 ~ /SH-DIST-AS-PATH / && $1=="NEEDS-REVIEW" {f=1} END{exit !f}' \
  'a refusal keyed on $DIST/ misses the AI_DLC_PROJECT_ROOT="$DIST" shape — the shape BOTH live offenders used — while still catching the slash one' \
  'SH-DIST-AS-PATH still refused'
# m3 — the refusal ALSO refuses `git -C "$DIST"`, by pointing the quoted-form strip pattern at a
# path no receipt carries. THIS IS THE SHAPE AN INLINE UNQUOTED PATTERN PRODUCES BY ACCIDENT:
# written `${t//git -C "$DIST"/}` the pattern EXPANDS, becomes the operator's real checkout path,
# matches nothing, and refuses all 28. Killed by arm C: the conforming control moves, which is the
# 26-of-28 false-positive direction.
dp_m3="$(dp_mutant refuse-git-c '_RD_GITC3='"'"'git -C "$DIST"'"'"'' '_RD_GITC3='"'"'git -C "/no/such/expanded/checkout"'"'"'')"
dp_kill mutation-refuse-git-c "$dp_m3" \
  '$2 ~ /SH-DIST-REVSPEC / && $1=="NEEDS-REVIEW" {f=1} END{exit !f}' \
  '$2 ~ /SH-DIST-AS-ENV/ && $1=="NEEDS-REVIEW" {f=1} END{exit !f}' \
  'a strip pattern that does not match the quoted git -C form refuses the CONFORMING receipt too — 26 of the reference consumer'"'"'s 28 are written that way, and arm C is what sees it' \
  'SH-DIST-AS-ENV still refused'
# m7 — the `cd "$DIST" && git` exemption WIDENED to a bare `cd "$DIST"`, which is how an
# exemption comes to acquit its own arm's subject. Killed by the near-miss entry, which the
# good-form entry alone cannot see.
dp_m7="$(dp_mutant cd-exempt-bare '_RD_CD3='"'"'cd "$DIST" && git '"'"'' '_RD_CD3='"'"'cd "$DIST"'"'"'')"
dp_kill mutation-cd-exempt-bare "$dp_m7" \
  '$2 ~ /SH-DIST-CD-BARE/ && $1!="NEEDS-REVIEW" {f=1} END{exit !f}' \
  '$2 ~ /SH-DIST-AS-ENV/ && $1=="NEEDS-REVIEW" {f=1} END{exit !f}' \
  'an exemption for a bare cd "$DIST" acquits the checkout read it was written beside — the near-miss is what separates the two' \
  'SH-DIST-AS-ENV still refused'
# m8 — the rc=0 partition WITHOUT the two $THEIRS_TREE alternations. Killed by the braced entry
# alone: the unbraced spelling matches `*$THEIRS*` by accident and cannot see this.
dp_m8="$(dp_mutant partition-no-tt '            *'"'"'$THEIRS'"'"'*|*'"'"'${THEIRS}'"'"'*|*'"'"'$DIST'"'"'*|*'"'"'${DIST}'"'"'*|*'"'"'$THEIRS_TREE'"'"'*|*'"'"'${THEIRS_TREE}'"'"'*)' '            *'"'"'$THEIRS'"'"'*|*'"'"'${THEIRS}'"'"'*|*'"'"'$DIST'"'"'*|*'"'"'${DIST}'"'"'*)')"
# THE KILL IS ON THE DETAIL, NOT ON THE STATUS, AND THAT IS THE FINDING THIS MUTANT PRODUCED.
# Both partitions emit STILL-LIVE for this entry, so a status-only arm scores the mutant green:
# the falsifiability branch reaches its own STILL-LIVE with a "falsifiability NOT checked" detail
# because the receipt names no path-shaped subject it can see. The DEFECT is real and one seed
# away — an entry whose $THEIRS_TREE receipt DOES name such a subject lands on the NEEDS-REVIEW
# "unfalsifiable predicate" row — and the observable that separates the two partitions on every
# such receipt is the DETAIL. Measured: status identical, detail divergent.
dp_kill mutation-partition-no-tt "$dp_m8" \
  '$2 ~ /SH-THEIRS-TREE-BRACED / && index($3,"falsifiability NOT checked")>0 {f=1} END{exit !f}' \
  '$2 ~ /SH-THEIRS-TREE / && $1=="STILL-LIVE" && index($3,"falsifiability NOT checked")==0 {f=1} END{exit !f}' \
  'without its own alternation the BRACED $THEIRS_TREE receipt falls OUT of the upstream-consulting partition and into the falsifiability branch — same status, different DETAIL' \
  'the unbraced SH-THEIRS-TREE still in the upstream partition'
# ...AND THE SAME MUTANT, KILLED BY A STATUS. The kill above reads a DETAIL because its subject
# names no path-shaped subject and both partitions reach STILL-LIVE for it. The seed one entry
# along DOES name an upstream-shipped subject, so the falsifiability branch accuses it outright —
# a verdict flip, which is the observable that survives a rewording of the detail text.
dp_kill mutation-partition-no-tt-status "$dp_m8" \
  '$2 ~ /SH-THEIRS-TREE-BRACED-SUBJECT/ && $1=="NEEDS-REVIEW" && index($3,"unfalsifiable")>0 {f=1} END{exit !f}' \
  '$2 ~ /SH-THEIRS-TREE / && $1=="STILL-LIVE" {f=1} END{exit !f}' \
  'the same partition mutant ACCUSES the braced receipt that names an upstream-shipped subject — a STATUS flip to NEEDS-REVIEW unfalsifiable, not merely a reworded detail' \
  'the unbraced SH-THEIRS-TREE still STILL-LIVE'
# m4 — no EXIT cleanup for the materialized tree. Killed by arm A's cleanup half, which is the
# only observable: the ROW SET is byte-identical whether the tree survives or not. The NEW line is
# empty, which this helper reads as "delete the line".
dp_mut_leak="$(dp_mutant tt-no-cleanup '  [ -n "${THEIRS_TREE_OWNED:-}" ] && rm -rf "$THEIRS_TREE_OWNED"')"
ASSERTIONS=$((ASSERTIONS + 1))
if [ -z "$dp_mut_leak" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the no-cleanup mutation DID NOT APPLY, so the cleanup arm is unproven\n' "mutation-tt-no-cleanup"
else
  rm -f "$CONS/theirs-tree-path.txt"
  leak_out="$(bash "$dp_mut_leak/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
  leak_path="$(cat "$CONS/theirs-tree-path.txt" 2>/dev/null)"
  if ! printf '%s\n' "$leak_out" | awk -F'\t' '$2 ~ /SH-DIST-REVSPEC / && $1=="STILL-LIVE" {f=1} END{exit !f}'; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the control row is gone too — the mutant broke the closer rather than the trap\n' "mutation-tt-no-cleanup"
  elif [ -n "$leak_path" ] && [ -d "$leak_path" ]; then
    printf '  ok    %-22s without the extended trap the tree SURVIVES (%s) — the cleanup arm reads the directory, which no row can\n' "mutation-tt-no-cleanup" "$leak_path"
    rm -rf "$leak_path"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the trap was removed and the tree was cleaned anyway — the cleanup arm cannot fire\n' "mutation-tt-no-cleanup"
  fi
fi
# ...and the closer installs exactly ONE EXIT trap. bash traps REPLACE each other, so a second
# `trap … EXIT` added for the tree would silently delete the consumer->core table's cleanup and
# leak that file on every run — a regression with no row and no symptom. Asserted on the SHIPPED
# closer rather than on a mutant, because the failure is a future edit, not a current behaviour.
ASSERTIONS=$((ASSERTIONS + 1))
trap_n="$(grep -cE '^trap .* EXIT$' "$CLOSER")" || trap_n=0
if [ "$trap_n" -eq 1 ]; then
  printf '  ok    %-22s the closer installs exactly ONE EXIT trap, and its handler removes BOTH temporaries — a second trap would silently replace the first\n' "one-exit-trap"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the closer installs %s EXIT traps; bash traps REPLACE each other, so all but the last are dead and their temporaries leak with no symptom\n' "one-exit-trap" "$trap_n"
fi
# m5 — EAGER materialization: the `case $rest in *THEIRS_TREE*` gate widened to everything, so a
# tree is built for every sh receipt.
#
# DRIVEN AGAINST A REF THAT DOES NOT RESOLVE, WHICH IS THE ONLY OBSERVABLE THE TRAP CANNOT ERASE.
# A count of live trees cannot see this: the mutant materializes AND cleans up, so the delta is
# zero either way and the arm's first cut passed down BOTH its branches — a check that could not
# fire, reading exactly like one that discriminates. Against an unresolvable theirs the
# materializer FAILS, and the two engines then differ in a VERDICT: the lazy one never attempts a
# tree for a ledger naming none and reports normally, the eager one attempts one for every `sh`
# receipt and refuses each with the materializer's own reason.
dp_mut_eager="$(dp_mutant tt-eager '        *THEIRS_TREE*)' '        *)')"
ASSERTIONS=$((ASSERTIONS + 1))
if [ -z "$dp_mut_eager" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the eager mutation DID NOT APPLY, so the laziness arm is unproven\n' "mutation-tt-eager"
else
  eg_badref=0000000000000000000000000000000000000000
  eg_out="$(bash "$dp_mut_eager/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$eg_badref" "$LED_NOTREE" 2>&1)"
  eg_ctl="$(bash "$CLOSER" "$DIST" "$BASE" "$CONS" "$eg_badref" "$LED_NOTREE" 2>&1)"
  if grep -q 'could not be materialized' <<<"$eg_ctl"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the SHIPPED closer also reports a materialization failure on a ledger naming no $THEIRS_TREE receipt — it is not lazy, so this arm cannot attribute the mutant'"'"'s row to the mutation\n' "mutation-tt-eager"
    printf '%s\n' "$eg_ctl" | sed 's/^/          | /'
  elif grep -q 'could not be materialized' <<<"$eg_out"; then
    printf '  ok    %-22s eager materialization attempts a tree for a ledger that names none and refuses on the unresolvable ref, where the shipped closer attempts nothing — a verdict the cleanup trap cannot erase\n' "mutation-tt-eager"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the gate was widened to every receipt and no materialization was attempted anyway — the laziness arm cannot fire\n' "mutation-tt-eager"
    printf '%s\n' "$eg_out" | sed 's/^/          | /'
  fi
fi
# m9 — EAGER AND LEAKING, driven through the laziness arm's OWN logic on a VALID ref. The eager
# mutant above is killed by a verdict on an unresolvable ref, which the laziness COUNT never sees;
# this one is what proves the count can fire. Both layers go: the `*THEIRS_TREE*)` gate widens to
# `*)` so every `sh` receipt materializes, AND the EXIT cleanup line is deleted so the trees
# survive — either layer alone leaves the count at 0 (lazy, or cleaned). The count runs in the
# private TMPDIR, so a positive `left +N` here is this mutant's trees and nobody else's.
lzm_dir="$(dirname "$DIST")/mut-tt-eager-leak"
rm -rf "$lzm_dir"; mkdir -p "$lzm_dir"
cp "$(dirname "$CLOSER")"/*.sh "$lzm_dir/" 2>/dev/null
lzm_ok=1
[ -f "$lzm_dir/lib.sh" ] || lzm_ok=0
LZM_OLD1='        *THEIRS_TREE*)' LZM_NEW1='        *)' \
LZM_OLD2='  [ -n "${THEIRS_TREE_OWNED:-}" ] && rm -rf "$THEIRS_TREE_OWNED"' \
  awk '$0 == ENVIRON["LZM_OLD1"] { print ENVIRON["LZM_NEW1"]; a++; next }
       $0 == ENVIRON["LZM_OLD2"] { b++; next }
       { print }
       END { exit !(a == 1 && b == 1) }' "$CLOSER" > "$lzm_dir/ledger-reverify.sh" || lzm_ok=0
cmp -s "$CLOSER" "$lzm_dir/ledger-reverify.sh" && lzm_ok=0
bash -n "$lzm_dir/ledger-reverify.sh" 2>/dev/null || lzm_ok=0
ASSERTIONS=$((ASSERTIONS + 1))
if [ "$lzm_ok" -ne 1 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the eager+leak mutation DID NOT APPLY (an anchor matched nothing or twice, the copy lacks lib.sh, or the result does not parse), so the laziness count is unproven\n' "mutation-tt-eager-leak"
else
  # THE UNMUTATED CONTROL, SAME RUN, SAME TMPDIR: the shipped closer must still read ok, or the
  # mutant's FAIL below could be the harness failing rather than the count firing.
  lzm_ctl="$(lz_verdict "$CLOSER")"
  lzm_out="$(lz_verdict "$lzm_dir/ledger-reverify.sh")"
  if ! grep -q '^  ok    theirs-tree-lazy ' <<<"$lzm_ctl"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the UNMUTATED control did not read ok, so the mutant verdict below is not attributable to the mutation\n' "mutation-tt-eager-leak"
    printf '%s\n' "$lzm_ctl" | sed 's/^/          | /'
  elif grep -qE '^  FAIL  theirs-tree-lazy .*left \+[1-9]' <<<"$lzm_out"; then
    printf '  ok    %-22s an engine that materializes eagerly and never cleans makes the laziness count RISE in the private TMPDIR (%s) while the unmutated control reads ok\n' \
      "mutation-tt-eager-leak" "$(grep -oE 'left \+[0-9]+' <<<"$lzm_out" | head -1)"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the engine was made eager AND leaking and the laziness arm did not report a positive left +N — its count cannot fire\n' "mutation-tt-eager-leak"
    printf '%s\n' "$lzm_out" | sed 's/^/          | /'
  fi
fi
# m6 — THE REFUSAL SITED AFTER THE RUN, on the rc=0 path. The residue is a STILL-LIVE that reads
# as healthy, which is exactly why SH-DIST-AS-PATH-ZERO exists: it exits 0 at the checkout, so a
# late refusal leaves it unrefused while the two exit-1 offenders are still caught by their own
# non-zero status. Killed by arm B's zero-exit entry alone.
dp_m6="$(dp_mutant refuse-after-run '      if receipt_reads_dist_as_path "$rest"; then' '      if receipt_reads_dist_as_path "$rest" && ! DIST="$DIST" BASE="$BASE" THEIRS="$THEIRS" CONSUMER="$CONSUMER" bash -c "$sh_prog" >/dev/null 2>&1; then')"
dp_kill mutation-refuse-after-run "$dp_m6" \
  '$2 ~ /SH-DIST-AS-PATH-ZERO/ && $1!="NEEDS-REVIEW" {f=1} END{exit !f}' \
  '$2 ~ /SH-DIST-REVSPEC / && $1=="STILL-LIVE" {f=1} END{exit !f}' \
  'a refusal that also requires a non-zero exit leaves the zero-exit $DIST reader as a healthy-looking STILL-LIVE — the residue an exit-1-only seed cannot see' \
  'SH-DIST-REVSPEC STILL-LIVE'

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
# THE CONVENTION THAT CLOSES IT, AND THIS ARM IS WHAT PROVES IT WORKS: every `$THEIRS_TREE`
# receipt opens `[ -n "${THEIRS_TREE:-}" ] || exit 127;`. 127 is the "subject renamed or deleted"
# status the `126|127)` arm has turned into NEEDS-REVIEW since that arm was written, so a guarded
# receipt degrades to a review on an OLD engine instead of a close.
#
# DRIVEN AGAINST A REAL OLD ENGINE, not against a description of one: the blob at HEAD of the
# distribution repo this fixture runs in. `git show` of that blob is the pre-fix engine whenever
# this fixture runs before the fix commits, and after it the arm SKIPS rather than asserting
# against a copy of itself — an arm comparing the tip to the tip proves nothing and must say so.
BOOT_DIR="$(dirname "$DIST")/boot-engine"
rm -rf "$BOOT_DIR"; mkdir -p "$BOOT_DIR"
cp "$(dirname "$CLOSER")"/*.sh "$BOOT_DIR/" 2>/dev/null
# The OLD engine is built by DELETING THE EXPORT from the shipped one. That single edit is the
# whole of what a pre-fix engine looks like FROM A RECEIPT'S SIDE — the value is simply not in its
# environment — and it is available whatever this repo's HEAD happens to be, unlike a git blob of
# the pre-fix file, which stops existing as an old engine the moment the fix is committed.
printf '%s\n' 's| THEIRS_TREE="$THEIRS_TREE"||' > "$BOOT_DIR/.boot.sed"
sed -f "$BOOT_DIR/.boot.sed" "$CLOSER" > "$BOOT_DIR/ledger-reverify.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if cmp -s "$CLOSER" "$BOOT_DIR/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the old-engine build DID NOT APPLY, so the bootstrapping arm below would compare the tip against itself\n' "boot-engine-build"
  BOOT_DIR=""
elif grep -qF 'THEIRS_TREE="$THEIRS_TREE"' "$BOOT_DIR/ledger-reverify.sh"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the old-engine build still EXPORTS $THEIRS_TREE, so it is not an old engine and the arm cannot fire\n' "boot-engine-build"
  BOOT_DIR=""
elif ! bash -n "$BOOT_DIR/ledger-reverify.sh" 2>/dev/null; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the old-engine build does not PARSE, so it emits nothing on every input and both halves of the pair below would fail for that reason\n' "boot-engine-build"
  BOOT_DIR=""
else
  printf '  ok    %-22s the old-engine build parses, differs from the tip (cmp -s) and exports no $THEIRS_TREE — the two sides of this differential are two programs\n' "boot-engine-build"
fi
if [ -n "$BOOT_DIR" ]; then
  # Two receipts, one property apart: the GUARD. Both read the tree; only one opens with 127.
  LED_BOOT="$(dirname "$DIST")/boot-ledger.md"
  {
    printf '# probe\n\n'
    printf '## PC-FIXTURE-BOOT-GUARDED — the guarded form, which an old engine must REVIEW\n\n'
    printf 'verify: sh [ -n "${THEIRS_TREE:-}" ] || exit 127; [ "$(cat "$THEIRS_TREE/VERSION")" = "0.103.0" ]\n\n---\n\n'
    printf '## PC-FIXTURE-BOOT-UNGUARDED — the same read WITHOUT the guard: the false close\n\n'
    printf 'verify: sh [ "$(cat "$THEIRS_TREE/VERSION")" = "0.103.0" ]\n'
  } > "$LED_BOOT"
  boot_out="$(bash "$BOOT_DIR/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" "$LED_BOOT" 2>&1)"
  ASSERTIONS=$((ASSERTIONS + 1))
  if printf '%s\n' "$boot_out" | awk -F'\t' '$2 ~ /BOOT-GUARDED/ && $1=="NEEDS-REVIEW" {a=1} $2 ~ /BOOT-UNGUARDED/ && $1=="CLOSE-CANDIDATE" {b=1} END{exit !(a && b)}'; then
    printf '  ok    %-22s on an engine that does not export $THEIRS_TREE the GUARDED receipt reads NEEDS-REVIEW while the UNGUARDED one reads CLOSE-CANDIDATE — the guard is what stops the bootstrapping false close\n' "boot-guard"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s the guarded/unguarded pair does not split on an old engine, so the exit-127 convention is unproven and every $THEIRS_TREE receipt written before a consumer pulls is at risk of a false close\n' "boot-guard"
    printf '%s\n' "$boot_out" | sed 's/^/          | /'
  fi
  # ...and the NEW engine refuses a $THEIRS_TREE receipt it could not materialize a tree for,
  # rather than scoring its non-zero exit. Driven by pointing the closer at a ref that does not
  # resolve in this dist, which is the only reachable materialization failure.
  ASSERTIONS=$((ASSERTIONS + 1))
  badref_out="$(bash "$CLOSER" "$DIST" "$BASE" "$CONS" "0000000000000000000000000000000000000000" "$LED_BOOT" 2>&1)"
  if printf '%s\n' "$badref_out" | awk -F'\t' '$2 ~ /BOOT-GUARDED/ && $1=="NEEDS-REVIEW" {a=1} $2 ~ /BOOT-GUARDED/ && $1=="CLOSE-CANDIDATE" {b=1} END{exit !(a && !b)}'; then
    printf '  ok    %-22s with the tree unmaterializable the receipt is NEEDS-REVIEW, never CLOSE — a tool failure must not manufacture the verdict that loses data\n' "theirs-tree-unavailable"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s a $THEIRS_TREE receipt whose tree could not be materialized did not read NEEDS-REVIEW; every read inside an absent tree fails, so this is a close manufactured from a tool failure\n' "theirs-tree-unavailable"
    printf '%s\n' "$badref_out" | sed 's/^/          | /'
  fi
fi

} # end lr_unit_bootstrap_window
lr_unit_nonid_wrong_fixes() {
# --- FIVE WRONG FIXES FOR THE NON-ID `manual` DEFECT ------------------------------------------
# Each is a fix a reader would plausibly write, and each is scored on BEHAVIOUR through the same
# `dp_mutant`/`dp_kill` harness the $DIST battery uses: the mutation is a copy, `cmp -s` refuses
# one that matched nothing, `bash -n` refuses one that does not parse, and every kill carries a
# CONTROL row re-read from the mutant's own output so a copy that died is reported as wreckage
# rather than scored.
#
# THE ANCHORS ARE ASSERTED UNIQUE FIRST, with an impossible anchor as the control in the same
# block. A mutation keyed on a line that has moved matches nothing, `dp_mutant` returns empty,
# and `dp_kill` reports DID NOT APPLY — but only the anchor probe says WHY, and a re-anchored
# mutation is the shape this repo has shipped green twice.
nid_anchor='           { if (ledger_entry_id($0) != "") ok=1 } END { exit !ok }'"'"'; then'
ASSERTIONS=$((ASSERTIONS + 1))
nid_n="$(grep -cF -- "$nid_anchor" "$CLOSER")" || nid_n=0
nid_imp="$(grep -cF -- '{ if (ledger_entry_id($0) == "") ok=1 } END { exit ok }' "$CLOSER")" || nid_imp=0
if [ "$nid_n" -eq 1 ] && [ "$nid_imp" -eq 0 ]; then
  printf '  ok    %-22s the id-test anchor is UNIQUE in the closer (control: an impossible anchor matches 0)\n' "nonid-anchor"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the id-test anchor matched %s lines (want 1) and the impossible control matched %s (want 0) — the mutations below would cut the wrong line or none\n' "nonid-anchor" "$nid_n" "$nid_imp"
fi


# m1 — NO FIX AT ALL. The pre-change engine: `manual` always emits HAND-REVIEW. This is the
# baseline mutant and it is what proves the whole arm set can fail — without it, every arm below
# passes against an engine that never changed.
nid_m1="$(dp_mutant nonid-no-fix "$nid_anchor" '           { ok=1 } END { exit !ok }'"'"'; then')"
dp_kill mutation-nonid-no-fix "$nid_m1" \
  '$2 ~ /A narrative closure record/ && $1=="HAND-REVIEW" {f=1} END{exit !f}' \
  "$nid_ctl" \
  'the unfixed engine reports the prose-titled narrative record as HAND-REVIEW again — the defect, reproduced' \
  "$nid_ctlmsg"

# m2 — NARROW THE BULLET GRAMMAR INSTEAD. The remedy this fix exists to refuse, and the one a
# reader reaches for first: make `- **` stop opening an entry unless what follows is an id. It
# silences the offender, and it ALSO deletes every prose-titled entry from the report — nine of
# which carry `sh` receipts that run. The kill is that `a-real-entry.sh` stops reporting at all.
#
# ITS SUBJECT IS IN `lib.sh`, NOT IN THE CLOSER, so it cannot go through `dp_mutant` — which
# copies the siblings unmutated and edits only `ledger-reverify.sh`. Mutating the wrong file is
# how three mutants in a row once read green against a change that was correct, so this one
# builds the copy itself, edits the sibling the closer RESOLVES, and carries the same three
# guards: `cmp -s` on the file it actually changed, `bash -n`, and dp_kill's control row.
nid_m2=""
nid_m2d="$(dirname "$DIST")/mut-nonid-narrow-grammar"
rm -rf "$nid_m2d"; mkdir -p "$nid_m2d"
cp "$(dirname "$CLOSER")"/*.sh "$nid_m2d/" 2>/dev/null
if [ -f "$nid_m2d/lib.sh" ]; then
  NG_OLD='  if (l ~ /^- \*\*/)           sh = "bullet"'
  NG_NEW='  if (l ~ /^- \*\*(PC|BL)-/)   sh = "bullet"'
  NG_OLD="$NG_OLD" NG_NEW="$NG_NEW" awk '
    $0 == ENVIRON["NG_OLD"] { print ENVIRON["NG_NEW"]; next }
    { print }
  ' "$(dirname "$CLOSER")/lib.sh" > "$nid_m2d/lib.sh.new" \
    && mv "$nid_m2d/lib.sh.new" "$nid_m2d/lib.sh"
  if ! cmp -s "$(dirname "$CLOSER")/lib.sh" "$nid_m2d/lib.sh" \
     && bash -n "$nid_m2d/lib.sh" 2>/dev/null; then
    nid_m2="$nid_m2d"
  fi
fi
dp_kill mutation-nonid-narrow-grammar "$nid_m2" \
  '$2 ~ /a-real-entry\.sh/ {f=1} END{exit f}' \
  "$nid_ctl" \
  'narrowing the bullet grammar to id-only deletes a-real-entry.sh from the report entirely — it takes real prose-titled entries with it, which is the remedy PC-S305 is filed against' \
  "$nid_ctlmsg"

# m3 — RESTATE THE ID TEST LOCALLY WITH THE OLD CHARACTER CLASS. The drift `lib.sh`'s header
# records happening inside one release, in its measured form: `^[A-Z0-9-]+$` excludes `_` and
# `.`, and it scored two real consumer entries as annotations. The offender is still caught, so
# every arm about the offender stays green and only the dotted near-miss says anything.
nid_m3="$(dp_mutant nonid-local-idshape "$nid_anchor" '           { if ($0 ~ /^(PC|BL)-[A-Z0-9-]+$/) ok=1 } END { exit !ok }'"'"'; then')"
dp_kill mutation-nonid-local-idshape "$nid_m3" \
  '$2 ~ /PC-FIXTURE-DOTTED/ && $1=="NEEDS-REVIEW" {f=1} END{exit !f}' \
  "$nid_ctl" \
  'a locally-restated ^[A-Z0-9-]+$ id test reports the dotted/underscored id as a shape defect — the exact false negative the shared rule was widened to close' \
  "$nid_ctlmsg"

# m4 — KEY ON THE SURFACE FORM RATHER THAN THE ID RULE. The shape a reader writes after reading
# only the first offender: narrative records end in a sentence period, so refuse those. It
# catches both offenders here and is wrong for a reason the SECOND spelling exposes — measured
# across the five real corpora, 19 of 27 prose bullets in this distribution's own backlog end in
# a period and most are annotations, while the arrow-form retirement record does not.
# The kill is the dotted near-miss: its label ends in no period, so this mutant ACQUITS nothing
# it should and CONVICTS nothing it should not -- except that it also convicts the bare-bold
# near-miss, whose bold span carries a period-free id but whose LABEL is the whole line.
nid_m4="$(dp_mutant nonid-period-form "$nid_anchor" '           { if ($0 !~ /\.$/) ok=1 } END { exit !ok }'"'"'; then')"
dp_kill mutation-nonid-period-form "$nid_m4" \
  '$2 ~ /validate-fixture-prereq\.sh/ && $1=="HAND-REVIEW" {f=1} END{exit !f}' \
  "$nid_ctl" \
  'a period-keyed surface-form test ACQUITS the arrow-spelled retirement record (its label ends in a code-span period the label transform strips) — a fix keyed on surface form, not on the id rule, misses the second spelling' \
  "$nid_ctlmsg"

# m5 — WIDEN TO EVERY VERB. The predicate this fix deliberately did not ship: report ANY receipt
# under a non-id label, not only `manual`. Measured over the tool's own population across five
# corpora it reports 43, including nine `extensions/*-push.md` bullets whose `sh` receipts run
# and produce real verdicts. The kill is `a-real-entry.sh` flipping to NEEDS-REVIEW: a mechanical
# verb stands on its receipt's own evidence whatever the label says.
#
# ANCHORED ON THE `case` HEAD, NOT ON THE `manual)` ARM, AND THE FIRST SPELLING WAS UNREACHABLE.
# Widening that arm to `manual|sh|theirs_lacks|theirs_has)` applies cleanly, parses, and changes
# NOTHING: `theirs_lacks|theirs_has)` and `sh)` are earlier arms of the same `case`, so a shell
# takes the first match and the widened arm is dead code. The mutant scored identical to the
# shipped engine for a reason that has nothing to do with the predicate under test, which reads
# exactly like a guard that is not load-bearing. A gate INSIDE the case head reaches every verb.
nid_m5="$(dp_mutant nonid-all-verbs '  case "$verb_norm" in' '  if [ -n "$verb_norm" ] && ! printf '"'"'%s\n'"'"' "$label" | LC_ALL=C awk "$(ledger_entry_awk)$(ledger_entry_id_awk)"'"'"'{ if (ledger_entry_id($0) != "") ok=1 } END { exit !ok }'"'"'; then emit NEEDS-REVIEW "$label" "unresolved: receipt under a label that is not an entry id"; continue; fi
  case "$verb_norm" in')"
dp_kill mutation-nonid-all-verbs "$nid_m5" \
  '$2 ~ /a-real-entry\.sh/ && $1=="NEEDS-REVIEW" {f=1} END{exit !f}' \
  "$nid_ctl" \
  'widening past `manual` reports a prose-titled entry whose mechanical receipt RUNS — 43 rows across the real corpora, nine of them live extension entries' \
  "$nid_ctlmsg"

} # end lr_unit_nonid_wrong_fixes
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
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the receipt-less named entry emitted %s rows, want exactly 1 — a 0/0 row that reaches the verb dispatch invents a receipt verdict\n' "receiptless-one-row" "$rl_n"
elif ! grep -q 'carries NO verify: receipt' <<<"$rl_det"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the row does not say the entry carries no receipt: %s\n' "receiptless-one-row" "$(printf '%s' "$rl_det" | cut -c1-110)"
elif grep -q 'no receipt in this entry can see\|re-anchor or drop the stale receipt' <<<"$rl_det"; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the row tells the operator to fix a receipt the entry does not have\n' "receiptless-one-row"
else
  printf '  ok    %-22s exactly one row, and its detail says the entry carries no receipt and closes by annotation\n' "receiptless-one-row"
fi
row_is "PC-FIXTURE-NORECEIPT-NEVER-CITED" ABSENT \
  "receipt-less and id-keyed but never named upstream -> no row of any kind"
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
row_is "PC-FIXTURE-BARE-BOLD-EOL" STILL-LIVE \
  "the second spelling, the bold id alone on its line, opens its own entry too"
bb_above='$2 ~ /PC-FIXTURE-DASHED-ABOVE-BARE-BOLD/ {n++} END{print n+0}'
ASSERTIONS=$((ASSERTIONS + 1))
bb_n="$(printf '%s\n' "$OUT" | awk -F'\t' "$bb_above")"
if [ "$bb_n" = 1 ]; then
  printf '  ok    %-22s the dashed entry above the record emits exactly one row — the record receipt is not attributed to it\n' "bare-bold-neighbour"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s the dashed entry above the record emitted %s rows, want 1 — the record was swallowed into it\n' "bare-bold-neighbour" "$bb_n"
fi
# THE NEAR-MISS. A body line OPENING with a bold id that closes before a comma is a MENTION. The
# looser `^-? ?\*\*PC-` rule matches it, splits the host, and moves the host receipt onto the
# mentioned id -- measured on the reference consumer archive, where such a line sits mid-body.
row_is "PC-FIXTURE-BARE-BOLD-MENTION-HOST" STILL-LIVE \
  "a bolded id opening a body line and closing before a comma is a mention -> the host keeps its row"
row_is "PC-FIXTURE-MENTIONED-IN-A-BODY" ABSENT \
  "...and the mentioned id does not become an entry of its own"

# THE MUTANTS. rl_mutant copies the whole reconcile directory, replaces a LITERAL string in one
# named file with an exact expected count, and refuses the copy if the count is wrong, the file
# did not change, or it does not parse. It can be called twice on one directory, for a layer that
# spans two files. The control row for every one is nid_ctl, which no mutant here touches.
rl_mutant() { # <dir> <file> <old> <new> <want-count> -> 0 iff applied exactly want-count times
  local d="$1" f="$2" n
  [ -f "$d/$f" ] || return 1
  n="$(RL_O="$3" RL_N="$4" awk '
    BEGIN { o = ENVIRON["RL_O"]; nw = ENVIRON["RL_N"]; c = 0 }
    { s = $0; out = ""
      while ((i = index(s, o)) > 0) { out = out substr(s, 1, i - 1) nw; s = substr(s, i + length(o)); c++ }
      print out s > (FILENAME ".mut") }
    END { print c }
  ' "$d/$f")" || return 1
  [ "$n" = "$5" ] || return 1
  cmp -s "$d/$f" "$d/$f.mut" && return 1
  mv "$d/$f.mut" "$d/$f"
  bash -n "$d/$f" 2>/dev/null
}
rl_dir() { # <name> -> fresh copy of the reconcile directory on stdout
  local d
  d="$(dirname "$DIST")/mut-$1"; rm -rf "$d"; mkdir -p "$d"
  cp "$(dirname "$CLOSER")"/*.sh "$(dirname "$CLOSER")"/*.md "$d/" 2>/dev/null
  [ -f "$d/lib.sh" ] && [ -f "$d/ledger-reverify.sh" ] || return 1
  printf '%s' "$d"
}
RL_GATE='    if (!has_verify && !closed && label != "" && ledger_entry_id(label) != "")'
BB_SHAPE='  if (l ~ /^\*\*`?(PC|BL)-[A-Za-z0-9_.-]+`?\*\*([ \t]+—|[ \t]*$)/) sh = "bullet"'

# m-gate — the has_verify gate restored: no receipt-less entry reaches the naming query.
rl_m1="$(rl_dir rl-gate)" && rl_mutant "$rl_m1" ledger-reverify.sh "$RL_GATE" '    if (0)' 1 || rl_m1=""
dp_kill mutation-receiptless-gate "$rl_m1" \
  '$2 ~ /^PC-FIXTURE-NORECEIPT-NAMED-UPSTREAM$/ {f=1} END{exit f}' \
  "$nid_ctl" \
  'with the has_verify gate restored the named receipt-less entry emits nothing — the 0/0 row is what carries it to the naming query' \
  "$nid_ctlmsg"
# m-guard — the extraction filter swapped for named_absorbed()'s local case guard (charset plus
# a hyphen). The all-caps non-id heading then reaches the naming query and matches its commit.
rl_m2="$(rl_dir rl-local-guard)" && rl_mutant "$rl_m2" ledger-reverify.sh 'ledger_entry_id(label) != "")' 'label ~ /^[A-Z0-9-]+$/ && label ~ /-/)' 1 || rl_m2=""
dp_kill mutation-receiptless-local-guard "$rl_m2" \
  '$2 ~ /^FIXTURE-CAPS-HEADING-NOT-AN-ID$/ && $1=="NAMED-UPSTREAM" {f=1} END{exit !f}' \
  "$nid_ctl" \
  'filtering on the local charset guard instead of ledger_entry_id() reports an all-caps heading that is not an id — the shared id rule is what keeps it silent' \
  "$nid_ctlmsg"
# m-skip — the 0/0 skip before the verb dispatch removed. The `-` placeholder dispatches as a
# verb, so the never-cited receipt-less entry acquires a row it has no receipt to earn.
rl_m3="$(rl_dir rl-no-skip)" && rl_mutant "$rl_m3" ledger-reverify.sh '  [ "$ord" = "0/0" ] && continue' '  :' 1 || rl_m3=""
dp_kill mutation-receiptless-no-skip "$rl_m3" \
  '$2 ~ /^PC-FIXTURE-NORECEIPT-NEVER-CITED$/ {f=1} END{exit !f}' \
  "$nid_ctl" \
  'without the 0/0 skip a receipt-less entry reaches the verb dispatch and gets a verdict no receipt produced' \
  "$nid_ctlmsg"
# m-shape — the bare-bold shape arm removed from lib.sh. The record is body text again: its row
# is gone and its receipt lands on the dashed entry above as a second one.
bb_m1="$(rl_dir bb-no-shape)" && rl_mutant "$bb_m1" lib.sh "$BB_SHAPE" '  sh = sh' 1 || bb_m1=""
dp_kill mutation-bare-bold-no-shape "$bb_m1" \
  '$2 ~ /PC-FIXTURE-BARE-BOLD-RECORD/ {g=1} $2 ~ /PC-FIXTURE-DASHED-ABOVE-BARE-BOLD/ {n++} END{exit !(!g && n == 2)}' \
  "$nid_ctl" \
  'without the shape arm the record row is gone and the dashed entry above carries two receipts — the swallow, reproduced' \
  "$nid_ctlmsg"
# m-strip — every widened label strip put back to `^- \*\*`, in BOTH files that carry one. The
# shape still opens the entry, so the neighbour keeps one row, but the label is "" and the entry
# and its receipt vanish together — the half of the fix a shape-only change leaves broken.
bb_m2="$(rl_dir bb-narrow-strip)" \
  && rl_mutant "$bb_m2" ledger-reverify.sh 'sub(/^(- )?\*\*/' 'sub(/^- \*\*/' 4 \
  && rl_mutant "$bb_m2" lib.sh 'sub(/^(- )?\*\*/' 'sub(/^- \*\*/' 2 || bb_m2=""
dp_kill mutation-bare-bold-narrow-strip "$bb_m2" \
  '$2 ~ /PC-FIXTURE-BARE-BOLD-RECORD/ {g=1} $2 ~ /PC-FIXTURE-DASHED-ABOVE-BARE-BOLD/ {n++} END{exit !(!g && n == 1)}' \
  "$nid_ctl" \
  'with the label strip left narrow the record opens an entry labelled "" — its row AND its receipt vanish, and the neighbour keeps exactly one row' \
  "$nid_ctlmsg"
# m-loose — the shape widened to the looser `^-? ?\*\*(PC|BL)-`. The body mention then opens an
# entry and takes the host receipt with it.
bb_m3="$(rl_dir bb-loose)" && rl_mutant "$bb_m3" lib.sh "$BB_SHAPE" '  if (l ~ /^-? ?\*\*(PC|BL)-/) sh = "bullet"' 1 || bb_m3=""
dp_kill mutation-bare-bold-loose "$bb_m3" \
  '$2 ~ /^PC-FIXTURE-MENTIONED-IN-A-BODY/ {f=1} END{exit !f}' \
  "$nid_ctl" \
  'the looser grammar splits the host at a body line opening with a bolded id — the strict id-only span and em dash are load-bearing' \
  "$nid_ctlmsg"

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
# Each arm is a function of the RECONCILE DIRECTORY, so its committed mutant drives the same
# logic. Each mutant edits lib.sh in a copy of the whole directory (the closer resolves lib.sh
# beside itself), is refused if the edit matched nothing or does not parse, and each is killed by
# its OWN arm only: the ownership mutant leaves the composition intact, and the handler-first
# mutant leaves ownership intact and only loses the cleanup behind a handler that calls `exit`.
ms_mutant() { # <name> <OLD1> <NEW1> [<OLD2> <NEW2>] -> dir on stdout, empty if it did not apply
  local d
  d="$(dirname "$DIST")/mut-$1"; rm -rf "$d"; mkdir -p "$d"
  cp "$(dirname "$CLOSER")"/*.sh "$(dirname "$CLOSER")"/*.md "$d/" 2>/dev/null
  [ -f "$d/lib.sh" ] && [ -f "$d/ledger-reverify.sh" ] || return 1
  MS_O1="$2" MS_N1="$3" MS_O2="${4:-}" MS_N2="${5:-}" awk '
    $0 == ENVIRON["MS_O1"] { if (ENVIRON["MS_N1"] != "") print ENVIRON["MS_N1"]; a++; next }
    ENVIRON["MS_O2"] != "" && $0 == ENVIRON["MS_O2"] { print ENVIRON["MS_N2"]; b++; next }
    { print }
    END { exit !(a == 1 && (ENVIRON["MS_O2"] == "" || b == 1)) }
  ' "$(dirname "$CLOSER")/lib.sh" > "$d/lib.sh" || return 1
  cmp -s "$(dirname "$CLOSER")/lib.sh" "$d/lib.sh" && return 1
  bash -n "$d/lib.sh" 2>/dev/null || return 1
  printf '%s' "$d"
}
# memo_standalone <reconcile-dir> -> "ok ..." or "FAIL ..." on one line
memo_standalone() {
  local r="$1" t out left
  t="$(mktemp -d "$(dirname "$DIST")/memo-tmp.XXXXXX")" || { echo "FAIL could not create a private TMPDIR"; return; }
  out="$(unset AI_DLC_RECONCILE_MEMO; TMPDIR="$t" bash "$r/ledger-reverify.sh" "$DIST" "$BASE" "$CONS" "$THEIRS" 2>&1)"
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
  ok*) printf '  ok    %-22s a standalone run with AI_DLC_RECONCILE_MEMO unset leaves 0 reconcile-memo.* in its private TMPDIR, while its control row still reports\n' "memo-standalone-clean" ;;
  *)   FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s %s — the memo directory outlives the run, and nothing in the row set can show it\n' "memo-standalone-clean" "$ms_v" ;;
esac
ASSERTIONS=$((ASSERTIONS + 1))
mc_v="$(memo_composed "$MS_R")"
case "$mc_v" in
  ok*) printf '  ok    %-22s a sourcer that arms its own trap … EXIT after lib.sh, with a handler that calls exit 3, still removes the memo (%s)\n' "memo-trap-composed" "$mc_v" ;;
  *)   FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s %s — a later trap X EXIT in a sourcer dropped lib.sh'"'"'s cleanup\n' "memo-trap-composed" "$mc_v" ;;
esac
# m-own — ownership NOT recorded at source time. The directory is built and exported, the
# composition is untouched, and nobody owns what was made: the standalone arm must see the leak.
ms_m1="$(ms_mutant memo-unowned '      AI_DLC_MEMO_OWNED="$_ai_dlc_m"' '')"
ASSERTIONS=$((ASSERTIONS + 1))
if [ -z "$ms_m1" ]; then
  FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s the ownership mutation DID NOT APPLY (matched nothing, or the copy does not parse), so memo-standalone-clean is unproven\n' "mutation-memo-unowned"
else
  ms_k="$(memo_standalone "$ms_m1")"; ms_o="$(memo_composed "$ms_m1")"
  case "$ms_k" in
    FAIL\ left=*)
      case "$ms_o" in
        ok*) printf '  ok    %-22s dropping the source-time ownership record leaks (%s) and ONLY memo-standalone-clean moves\n' "mutation-memo-unowned" "$ms_k" ;;
        *)   FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s the mutant also moved memo-trap-composed (%s), so the two arms are entangled\n' "mutation-memo-unowned" "$ms_o" ;;
      esac ;;
    *) FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s ownership was not recorded and memo-standalone-clean still read "%s" — the arm cannot fire\n' "mutation-memo-unowned" "$ms_k" ;;
  esac
fi
# m-order — the composition runs the caller's handler FIRST and the cleanup after it. A handler
# that calls `exit` ends the handler there, so the cleanup never runs; the closer's own handler
# does not exit, so memo-standalone-clean must NOT move.
ms_m2="$(ms_mutant memo-handler-first '    *)    builtin trap "_ai_dlc_lib_exit && :' '    *)    builtin trap "$_h' '$_h" EXIT ;;' '_ai_dlc_lib_exit" EXIT ;;')"
ASSERTIONS=$((ASSERTIONS + 1))
if [ -z "$ms_m2" ]; then
  FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s the handler-first mutation DID NOT APPLY (an anchor matched nothing or twice, or the copy does not parse), so memo-trap-composed is unproven\n' "mutation-memo-handler-first"
else
  ms_k="$(memo_composed "$ms_m2")"; ms_o="$(memo_standalone "$ms_m2")"
  case "$ms_k" in
    FAIL\ left=*)
      case "$ms_o" in
        ok*) printf '  ok    %-22s composing the caller'"'"'s exiting handler BEFORE the cleanup leaks (%s) and ONLY memo-trap-composed moves\n' "mutation-memo-handler-first" "$ms_k" ;;
        *)   FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s the mutant also moved memo-standalone-clean (%s), so the two arms are entangled\n' "mutation-memo-handler-first" "$ms_o" ;;
      esac ;;
    *) FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s the handler ran before the cleanup and memo-trap-composed still read "%s" — the arm cannot fire\n' "mutation-memo-handler-first" "$ms_k" ;;
  esac
fi

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
  ok*) printf '  ok    %-22s x=$(trap : EXIT; :) in a sourcer leaves the main shell'"'"'s memo directory in place\n' "memo-subshell-trap" ;;
  *)   FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s %s\n' "memo-subshell-trap" "$st_v" ;;
esac
ASSERTIONS=$((ASSERTIONS + 1))
ee_v="$(memo_errexit "$MS_R")"
case "$ee_v" in
  ok*) printf '  ok    %-22s under set -e a failing sourcer still runs its own EXIT handler with the original status (%s)\n' "memo-errexit-handler" "$ee_v" ;;
  *)   FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s %s\n' "memo-errexit-handler" "$ee_v" ;;
esac
# m-setguard — the set-time level guard removed. Only memo-subshell-trap may move.
ms_m3="$(ms_mutant memo-no-setguard '  [ "${BASH_SUBSHELL:-0}" -eq "${_AI_DLC_LIB_LEVEL:-0}" ] || { builtin trap "$@"; return; }' '')"
ASSERTIONS=$((ASSERTIONS + 1))
if [ -z "$ms_m3" ]; then
  FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s the set-time guard mutation DID NOT APPLY, so memo-subshell-trap is unproven\n' "mutation-memo-no-setguard"
else
  ms_k="$(memo_subshell_trap "$ms_m3")"; ms_o="$(memo_errexit "$ms_m3")"
  case "$ms_k" in
    FAIL*)
      case "$ms_o" in
        ok*) printf '  ok    %-22s without the set-time guard a subshell trap deletes the parent memo (%s) and ONLY memo-subshell-trap moves\n' "mutation-memo-no-setguard" "$ms_k" ;;
        *)   FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s the mutant also moved memo-errexit-handler (%s), so the two arms are entangled\n' "mutation-memo-no-setguard" "$ms_o" ;;
      esac ;;
    *) FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s the guard was removed and memo-subshell-trap still read "%s" — the arm cannot fire\n' "mutation-memo-no-setguard" "$ms_k" ;;
  esac
fi
# m-errexit — the composition's `&& :` removed. Only memo-errexit-handler may move.
ms_m4="$(ms_mutant memo-errexit-bare '    *)    builtin trap "_ai_dlc_lib_exit && :' '    *)    builtin trap "_ai_dlc_lib_exit')"
ASSERTIONS=$((ASSERTIONS + 1))
if [ -z "$ms_m4" ]; then
  FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s the errexit mutation DID NOT APPLY, so memo-errexit-handler is unproven\n' "mutation-memo-errexit-bare"
else
  ms_k="$(memo_errexit "$ms_m4")"; ms_o="$(memo_subshell_trap "$ms_m4")"
  case "$ms_k" in
    FAIL*)
      case "$ms_o" in
        ok*) printf '  ok    %-22s a bare cleanup call ends the handler under set -e (%s) and ONLY memo-errexit-handler moves\n' "mutation-memo-errexit-bare" "$ms_k" ;;
        *)   FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s the mutant also moved memo-subshell-trap (%s), so the two arms are entangled\n' "mutation-memo-errexit-bare" "$ms_o" ;;
      esac ;;
    *) FAILURES=$((FAILURES + 1)); printf '  FAIL  %-22s the && : was removed and memo-errexit-handler still read "%s" — the arm cannot fire\n' "mutation-memo-errexit-bare" "$ms_k" ;;
  esac
fi

} # end lr_unit_memo_lifecycle

# --- DISPATCH: this shard's units, then the joins that say they all ran -------------------------
printf '  ok    %s\n' "$LR_JOIN_LINE"
# THE SHARED CONTROL IS EXACTLY SIX, CHECKED HERE AND NOT BESIDE IT. Everything between the
# shared control and this line is a function DEFINITION, so a unit body left at top level, or a
# helper call outside any unit, executes before this point and moves the count.
if [ "$ASSERTIONS" -ne 6 ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s %s assertions ran before dispatch, want the shared control'"'"'s 6 -- something outside every lr_unit_ ran, in every shard\n' "[shared]" "$ASSERTIONS"
fi
# A unit's stderr is captured to a FILE with `2>`, never with `$( )`, which would run the unit in
# a subshell and lose every ASSERTIONS and FAILURES it moved. It is replayed to stderr after the
# unit, and by the EXIT trap if the unit exits from inside its body.
LR_ENTERED=""
for _u in $LR_MINE; do
  LR_ENTERED="$LR_ENTERED $_u"
  LR_UNIT_ERR="$(dirname "$DIST")/lr-unit-$_u.err"
  _before="$ASSERTIONS"; LR_SKIPPED=""
  "lr_unit_$_u" 2>"$LR_UNIT_ERR"
  cat "$LR_UNIT_ERR" >&2
  # J2: a call to a helper this shard does not define, or a variable another unit used to set,
  # prints to stderr and the unit runs on with fewer assertions -- which otherwise reads PASS.
  if grep -qE 'run\.sh: line [0-9]+: .*(command not found|unbound variable)$' "$LR_UNIT_ERR"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s unit %s hit: %s\n' "[J2]" "$_u" \
      "$(grep -E 'run\.sh: line [0-9]+: .*(command not found|unbound variable)$' "$LR_UNIT_ERR" | head -1)"
  fi
  LR_UNIT_ERR=""
  # THE FLOOR: every unit asserts something. An emptied or early-returning unit otherwise passes.
  # The one exemption is DECLARED by the unit (LR_SKIPPED=1, on a consumer whose installed engine
  # predates the arms it would run); an early return declares nothing and is still caught.
  if [ "$ASSERTIONS" -le "$_before" ] && [ -z "$LR_SKIPPED" ]; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-22s unit %s made no assertion -- an emptied or early-returning unit reads exactly like a passing one\n' "[floor]" "$_u"
  fi
done
# J1: the SET of units entered equals this shard's list AS DECLARED IN THIS FILE'S TEXT, and no
# unit dealt to another shard was entered. A count off the loop variable cannot see a shard whose
# list was widened to every unit: it would run all of them and agree with itself.
lr_declared_for() { sed -n "s/^UNITS_$1=\"\\([a-z0-9_ ]*\\)\"\$/\\1/p" "$LR_SELF" | tr ' ' '\n' | grep . | sort; }
lr_got="$(printf '%s\n' $LR_ENTERED | grep . | sort)"
lr_want="$(lr_declared_for "$GROUP")"
lr_foreign=""
for _s in $SHARDS; do
  [ "$_s" = "$GROUP" ] && continue
  for _u in $LR_ENTERED; do
    lr_declared_for "$_s" | grep -qxF -- "$_u" && lr_foreign="$lr_foreign $_u"
  done
done
if [ -z "$lr_want" ] || [ "$lr_got" != "$lr_want" ] || [ -n "$lr_foreign" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-22s shard %s entered {%s}, its declared list is {%s}; entered from other shards: {%s}\n' "[J1]" "$GROUP" \
    "$(printf '%s' "$lr_got" | tr '\n' ' ')" "$(printf '%s' "$lr_want" | tr '\n' ' ')" "${lr_foreign# }"
fi
LR_DONE=1
echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of $ASSERTIONS assertions wrong in shard '$GROUP' of '$SHARDS'."
  exit 1
fi
echo "PASS: all $ASSERTIONS assertions correct in shard '$GROUP' of '$SHARDS'."
exit 0
