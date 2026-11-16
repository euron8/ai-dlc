#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# reconcile-emit-report/run.sh — prove the reconcile report's mechanical sections are driver-owned:
# emit-report.sh renders them, and --verify fails a report whose region is missing OR hand-edited.
#
# THE DEFECT THIS EXISTS TO CATCH. The report was LLM-authored; a mechanical HARD finding was silently
# dropped from it, twice. Rendering the region is only half — the LLM could still omit it or edit it.
# --verify byte-compares the report's region against a fresh render, so neither omission nor a
# dropped-blocker edit survives.
#
# DISTINCT INPUT SHAPES IN THE STEP-3b BATTERY: FOUR. Arms are not shapes — channels
# written by different hands converge on the obvious way to build the input and then agree for that
# reason. These four differ in what the CLASSIFIER is handed:
#   S1  the well-formed pair (four templates at base, two moved at theirs, three of the four
#       generated files on the consumer)
#   S2  the template manifest ABSENT
#   S3  the manifest present with its `template_manifest:` block unparseable
#   S4  a manifest row naming a template absent at BOTH refs
# The per-shape roster is beside the battery, at the "STEP 3b" banner below.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# --- THE SHARD SPLIT, AND IT IS A SCHEDULING BOUNDARY RATHER THAN A SUBJECT BOUNDARY ------------
# The pre-push suite is POLE-BOUND: its makespan tracks its single longest DIRECTORY, because
# `core/fixtures/*/run.sh` is what the outer pool globs. Unsharded this file was the fourth-longest
# unit on the suite. Everything below the world-guard probe is a PHASE -- a block opened by a line
# `if rer_phase <slug>; then` and closed by `fi # end rer_phase <slug>` -- and the phases are dealt
# across the shards named in SHARDS. Every shard pays the seed, the sanity arm and the world-guard
# probe, because a shard that skipped them could report green against a harness that never ran.
#
# THE SHARD ARRIVES AS AN ARGUMENT (`--group b`), never from the environment: the pre-push runner
# scrubs AI_DLC_*, and a fallback-to-'a' design would run shard 'a' once per shard. A run with no
# argument is shard 'a' -- which is what the pool globs for this directory -- and the sibling
# directories `-b` and `-c` are drivers that run this file with their shard and exit 2 unless
# its verdict line names that shard.
#
# THE COVERAGE JOIN (J0) runs in every shard before anything is seeded: the declared phase set is
# derived from this file's own `if rer_phase` lines, every one must have its end marker, the lists
# dealt across SHARDS must be disjoint, non-empty and union to it exactly, and every declared shard
# but 'a' must have a driver directory that names it. The join proves it can fire, on a seeded
# duplicate and a seeded omission, before it is trusted. J1, at the foot, proves the shard ENTERED
# exactly the phases its list names.
#
# A PHASE'S HELPERS LIVE INSIDE THE PHASE, and nothing is shared between phases except what is
# defined above them: the world guards, `ok`/`bad`, the seed variables, and the shadowed-validator
# consumer seed. That was checked by listing every name each phase defines and every line outside it
# that reads one.
SHARDS="a b c"
PHASES_a="seeded b230 moved shadow b1b2"
PHASES_b="vworlds1 vworlds2"
PHASES_c="step3b sb"
GROUP=a
case "${1:-}" in
  --group)
    GROUP="${2:-}"
    [ -n "$GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; } ;;
  "") ;;
  *) echo "FIXTURE ERROR: unknown argument '$1' (want --group <x>)" >&2; exit 2 ;;
esac
case " $SHARDS " in
  *" $GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;;
esac

# rer_partition_ok <declared file> <dealt file> -> 0 when dealt is disjoint and covers declared
# exactly; prints the offending names otherwise.
rer_partition_ok() {
  local dup miss extra
  dup="$(sort "$2" | uniq -d | tr '\n' ' ')"
  miss="$(sort -u "$2" | comm -23 <(sort -u "$1") - | tr '\n' ' ')"
  extra="$(sort -u "$2" | comm -13 <(sort -u "$1") - | tr '\n' ' ')"
  [ -z "$dup$miss$extra" ] && return 0
  echo "dealt twice: {${dup% }} dealt to no shard: {${miss% }} dealt but not declared: {${extra% }}"
  return 1
}
# rer_deal <declared file> -> 0 when the phases dealt across SHARDS (read from the PHASES_* shell
# variables as they stand) cover <declared> exactly and no shard is dealt nothing; prints J0's
# reason and returns 1 otherwise. One definition, read by J0 and by J0's declaration-text probe.
rer_deal() {
  local s l why
  for s in $SHARDS; do eval "printf '%s\n' \${PHASES_$s:-}"; done | grep . > "$RER_JW/dealt"
  if ! why="$(rer_partition_ok "$1" "$RER_JW/dealt")"; then
    echo "the phase deal does not cover the declared phases exactly -- $why"; return 1
  fi
  for s in $SHARDS; do
    eval "l=\"\${PHASES_$s:-}\""
    [ -n "$l" ] || { echo "shard '$s' is declared and dealt no phases; an empty shard passes everything it never checked"; return 1; }
  done
  return 0
}
RER_SELF="$HERE/run.sh"
[ -f "$RER_SELF" ] || { echo "FIXTURE ERROR: cannot read $RER_SELF for the coverage join" >&2; exit 2; }
RER_JW="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed for the coverage join" >&2; exit 2; }
printf '%s\n' u1 u2 u3 > "$RER_JW/pd"
printf '%s\n' u1 u2 u2 u3 > "$RER_JW/pdup"
printf '%s\n' u1 u3 > "$RER_JW/pmiss"
printf '%s\n' u3 u1 u2 > "$RER_JW/pok"
if rer_partition_ok "$RER_JW/pd" "$RER_JW/pdup" >/dev/null || rer_partition_ok "$RER_JW/pd" "$RER_JW/pmiss" >/dev/null \
   || ! rer_partition_ok "$RER_JW/pd" "$RER_JW/pok" >/dev/null; then
  echo "FIXTURE BROKEN: [J0] the coverage join's self-probe did not discriminate (duplicate, omission, exact)" >&2
  rm -rf "$RER_JW"; exit 2
fi
sed -n 's/^if rer_phase \([a-z0-9_]*\); then$/\1/p' "$RER_SELF" > "$RER_JW/declared"
sed -n 's/^fi # end rer_phase \([a-z0-9_]*\)$/\1/p' "$RER_SELF" > "$RER_JW/ended"
rer_ndecl="$(grep -c . "$RER_JW/declared")" || rer_ndecl=0
rer_ndup="$(sort "$RER_JW/declared" | uniq -d | grep -c .)" || rer_ndup=0
if [ "$rer_ndecl" -eq 0 ] || [ "$rer_ndup" -ne 0 ] || ! cmp -s "$RER_JW/declared" "$RER_JW/ended"; then
  echo "FIXTURE BROKEN: [J0] $rer_ndecl rer_phase blocks derived from $RER_SELF ($rer_ndup declared twice), or their end markers do not pair with them one for one" >&2
  rm -rf "$RER_JW"; exit 2
fi
# The live deal is checked FIRST, so a broken declaration is refused with its own reason rather than
# as a probe whose unedited control failed.
if ! rer_why="$(rer_deal "$RER_JW/declared")"; then
  echo "FIXTURE BROKEN: [J0] $rer_why" >&2
  rm -rf "$RER_JW"; exit 2
fi
# THE DEAL CHECK ALSO PROVES IT FIRES ON THE DECLARATION TEXT: the SHARDS= and
# PHASES_*= lines are read off this file, PHASES_c is emptied in that copy, and rer_deal run over the
# copy must refuse naming exactly PHASES_c's phases as dealt to no shard, while the unedited copy
# passes. A shard whose list was emptied would otherwise run nothing and print PASS for it.
rer_decl="$(sed -n -e '/^SHARDS="[a-z ]*"$/p' -e '/^PHASES_[a-z]="[a-z0-9_ ]*"$/p' "$RER_SELF")"
rer_dslug="$(sed -n 's/^PHASES_c="\([a-z0-9_ ]*\)"$/\1/p' "$RER_SELF" | tr ' ' '\n' | grep . | sort | tr '\n' ' ')"
rer_dmut="$(printf '%s\n' "$rer_decl" | sed 's/^PHASES_c=".*"$/PHASES_c=""/')"
rer_pmsg="$(eval "$rer_dmut"; rer_deal "$RER_JW/declared")" && rer_prc=0 || rer_prc=$?
rer_cmsg="$(eval "$rer_decl"; rer_deal "$RER_JW/declared")" && rer_crc=0 || rer_crc=$?
if [ -z "$rer_dslug" ] || [ "$rer_dmut" = "$rer_decl" ] || [ "$rer_crc" -ne 0 ] || [ "$rer_prc" -eq 0 ] \
   || [ "$rer_pmsg" != "the phase deal does not cover the declared phases exactly -- dealt twice: {} dealt to no shard: {${rer_dslug% }} dealt but not declared: {}" ]; then
  echo "FIXTURE BROKEN: [J0] the deal check's declaration-text probe did not discriminate: PHASES_c {${rer_dslug% }} emptied gave rc=$rer_prc [$rer_pmsg], the unedited text rc=$rer_crc [$rer_cmsg]" >&2
  rm -rf "$RER_JW"; exit 2
fi
for _s in $SHARDS; do
  [ "$_s" = a ] && continue
  _drv="$HERE/../reconcile-emit-report-$_s/run.sh"
  # The driver must INVOKE this file with its shard as the argument. Comments are stripped whole-
  # line AND trailing, so `--group a # --group b` names shard a and nothing else.
  # The stripped driver is STAGED in a variable and the reader fed a here-string: a pipe into a
  # first-match reader reports NOT-FOUND under pipefail once the writer outruns the pipe buffer.
  _drv_code=""; [ -f "$_drv" ] && _drv_code="$(sed -e '/^[[:blank:]]*#/d' -e 's/[[:blank:]]#.*$//' "$_drv")"
  if [ ! -f "$_drv" ] || ! grep -qE -- "^[[:blank:]]*(exec[[:blank:]]+)?bash[[:blank:]]+\"\\\$IMPL\"[[:blank:]]+--group[[:blank:]]+$_s([[:blank:]]|\$)" <<<"$_drv_code"; then
    echo "FIXTURE BROKEN: [J0] shard '$_s' is declared but $_drv does not drive it" >&2; rm -rf "$RER_JW"; exit 2
  fi
done
rm -rf "$RER_JW"
RER_ENTERED=""
rer_phase() { # rer_phase <slug> -> 0 when this shard owns the phase and records it as entered
  eval "case \" \${PHASES_$GROUP} \" in *\" \$1 \"*) RER_ENTERED=\"\$RER_ENTERED \$1\"; return 0 ;; esac"
  return 1
}


WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found beside $HERE" >&2; exit 2; }

# --- THE COMPARISON SEAM, AND WHY THIS FILE RENDERS ALMOST NOTHING TWICE ------------------------
# `emit-report.sh --verify --region-from <file>` skips the render and hands <file>'s bytes to the one
# comparison function (`er_compare`) plain `--verify` calls on its own render. So a world is RENDERED
# ONCE, in print mode, and every report variant of that world is compared through the seam against
# that one file. Exactly one plain `--verify` (assertion 1) proves render-plus-compare is wired. A
# render is kept beside a `# RENDER:` comment ONLY where the render's input differs -- a repo, consumer
# or argument the world changed, or a copy of the engine a stub changed -- and that comment says
# which. `grep -c '# RENDER:'` is the static census of render sites.
#
# seam <emit> <region-file> <report> <dist> <base> <consumer> <theirs> -> RC, with stdout in
# $WORK/seam/<SEAM_TAG>.out and stderr in .err. EVERY CALL's first stdout line is checked for the
# engine's marker and logged; the S-MK arm at the foot of the file fails the shard on any call that
# lacked it. A seam result can therefore never
# be mistaken for a gate result.
RER_SEAM_MARK='emit-report: --region-from: region supplied by caller; nothing was rendered'
mkdir -p "$WORK/seam"; : > "$WORK/seam.log"
seam() {
  local t="${SEAM_TAG:-seam}"
  bash "$1" --verify --region-from "$2" "$3" "$4" "$5" "$6" "$7" > "$WORK/seam/$t.out" 2> "$WORK/seam/$t.err"; RC=$?
  if [ "$(sed -n 1p "$WORK/seam/$t.out")" = "$RER_SEAM_MARK" ]; then echo "MARK $t" >> "$WORK/seam.log"
  else echo "NOMARK $t rc=$RC" >> "$WORK/seam.log"; fi
  return 0
}

# STDERR IS KEPT, in `$VERIFY_ERR`, overwritten by each call. It is read only by render_diag()
# below, on a failing render arm -- discarded, a pool red printed the verdict and nothing else.
VERIFY_ERR="$WORK/verify.stderr"
verify() { bash "$EMIT" --verify "$1" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>"$VERIFY_ERR"; RC=$?; }

# render_diag <tag> <rc> [<extra-stderr-file> <label>] -- WHY a render arm went red. Every pool
# red this fixture had in batch 151 was a RENDER arm (assertion 1, the orientation pair, the
# docs-only near-miss), and each printed its verdict and nothing else, so nobody could say whether
# a detector had refused under load or the renderer was wrong. Printed ONLY on failure, bounded
# to 40 lines per stream, and every line carries `DIAG` so a log grep finds it.
# Arguments after the rc are <stderr-file> <label> pairs; the seed render's stderr is always shown.
render_diag() {
  local _t="$1" _f _l
  printf '  DIAG  %s: rc=%s\n' "$_t" "$2"
  shift 2
  set -- "${SEED_ERR:-}" seed-render "$@"
  while [ "$#" -ge 2 ]; do
    _f="$1"; _l="$2"; shift 2
    [ -n "$_f" ] && [ -n "$_l" ] || continue
    if [ ! -f "$_f" ]; then printf '  DIAG  %s %s: stderr capture missing (%s)\n' "$_t" "$_l" "$_f"; continue; fi
    if [ ! -s "$_f" ]; then printf '  DIAG  %s %s: stderr empty\n' "$_t" "$_l"; continue; fi
    awk -v p="  DIAG  $_t $_l | " 'NR <= 40 { print p $0 } END { if (NR > 40) print p "... (" NR - 40 " more lines cut)" }' "$_f"
  done
  grep -F 'DETECTOR-REFUSED' "${REGION:-/dev/null}" 2>/dev/null | head -5 | sed "s/^/  DIAG  $_t seed-region refusal | /"
}

# The orientation block for the BOTH-ADDED template, as rendered.
ORIENT="$(awk '/Semantic worklist orientation/,/^\*\*Deletions/' "$REGION")"
# Which side is the line attributed to? Prints THEIRS or OURS, or nothing.
side_of() { printf '%s\n' "$ORIENT" | awk -v pat="$1" '
  /ONLY IN THEIRS/{s="THEIRS"} /ONLY IN OURS/{s="OURS"} $0 ~ pat {print s; exit}'; }

echo "reconcile-emit-report:"
echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/emit-report.sh"


# --- Assertion 0: SANITY — the rendered region carries the HARD blocker -------
if grep -q "reconcile-mechanical" "$REGION" && grep -q "HARD-UNREGISTERED-CORE-DRIFT" "$REGION" && grep -q "thing.json" "$REGION"; then
  ok "the driver renders a mechanical region carrying the HARD schema blocker"
else
  bad "FIXTURE BROKEN — the rendered region lacks the HARD blocker; negatives below are meaningless"
  echo; echo "reconcile-emit-report: FIXTURE BROKEN" >&2; exit 2
fi

if rer_phase seeded; then
# --- Assertion 1 + S-RO: THE ONE END-TO-END PLAIN --verify, AND THE SEAM IS READ-ONLY ----------
# The seed consumer is made a git top level for these two arms only -- measured: `git init` leaves its
# render byte-identical -- so the approved-region record has a git-dir to land in. A seam exit 0 must
# leave NO record (the seam's region was never rendered, and apply mode trusts the record as what the
# operator approved); the plain --verify exit 0 on the same consumer must then write one, which is the
# control that a record CAN land here. That plain call is the only place in this file where the engine
# renders and compares in one process: it proves render-plus-compare is wired.
RER_RECF="$CONSUMER/.git/ai-dlc-approved-region"
if ! git -C "$CONSUMER" init -q >/dev/null 2>&1; then
  bad "FIXTURE BROKEN — could not git-init the seed consumer, so neither the end-to-end --verify's record nor the read-only seam arm can be read"
else
  SEAM_TAG=s-ro seam "$EMIT" "$REGION" "$REPORT_GOOD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS"; s_rc=$RC
  s_rec=0; [ -f "$RER_RECF" ] && s_rec=1
  # RENDER: base-world -- the one end-to-end plain --verify, render and er_compare in one process.
  verify "$REPORT_GOOD"; p_rc=$RC
  p_rec=0; [ -f "$RER_RECF" ] && p_rec=1
  if [ "$p_rc" -eq 0 ]; then ok "--verify PASSES a report whose region matches the driver (exit 0) — the one end-to-end plain --verify, render and compare in one process"
  else bad "--verify failed a correct report (rc=$p_rc) — false positive"; render_diag "assertion-1" "$p_rc" "$VERIFY_ERR" verify; fi
  if [ "$s_rc" -eq 0 ] && [ "$s_rec" = 0 ] && [ "$p_rec" = 1 ]; then
    ok "S-RO the seam exits 0 on the sound report and writes NO approved-region record, and the plain --verify exit 0 on the same consumer then writes it"
  else
    bad "S-RO seam rc=$s_rc record-after-seam=$s_rec, plain rc=$p_rc record-after-plain=$p_rec (want 0/0, 0/1) — a seam that writes the record lets a region nobody rendered become what apply mode trusts as approved"
  fi
  rm -f "$RER_RECF"
fi

# --- THE SEAM'S OWN ARMS, all against the ONE seed render ($REGION) -----------------------------
# S-GOOD: the sound report through the seam exits 0 and says so on stdout line 2.
SEAM_TAG=s-good seam "$EMIT" "$REGION" "$REPORT_GOOD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS"
if [ "$RC" -eq 0 ] && grep -qxF "emit-report: the report's mechanical region is present, current, and complete." "$WORK/seam/s-good.out"; then
  ok "S-GOOD the sound report through the seam exits 0 with the present-current-complete line"
else bad "S-GOOD the sound report through the seam exited $RC — the seam cannot stand in for a render"; fi
# S-BYTES: THE VERDICT FOLLOWS THE SUPPLIED BYTES, in both directions. A region with the HARD row cut
# fails the sound report and passes the report cut the same way. An engine that ignored the file and
# quietly re-rendered would pass the first and fail the second, so this pair is what proves the seam
# reads its file at all.
grep -v 'HARD-UNREGISTERED-CORE-DRIFT' "$REGION" > "$WORK/region-cut.md"
SEAM_TAG=s-bytes1 seam "$EMIT" "$WORK/region-cut.md" "$REPORT_GOOD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS"; sb1=$RC
SEAM_TAG=s-bytes2 seam "$EMIT" "$WORK/region-cut.md" "$REPORT_STALE" "$DIST" "$BASE" "$CONSUMER" "$THEIRS"; sb2=$RC
if cmp -s "$WORK/region-cut.md" "$REGION"; then bad "FIXTURE BROKEN — S-BYTES' cut region equals the seed region, so the pair cannot discriminate"
elif [ "$sb1" -eq 3 ] && [ "$sb2" -eq 0 ]; then ok "S-BYTES the seam's verdict follows the supplied bytes: a region with the HARD row cut refuses the sound report (3, BLOCKERS-RESOLVED: the report carries a row the supplied region lacks) and passes the report cut the same way (0)"
else bad "S-BYTES cut region vs sound report rc=$sb1 (want 3), vs cut report rc=$sb2 (want 0) — the seam is not comparing against the file it was handed"; fi
# S-EXIT2: an unreadable region file and an absent report each exit 2, the marker still on line 1.
SEAM_TAG=s-unread seam "$EMIT" "$WORK/no-such-region.md" "$REPORT_GOOD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS"; su=$RC
SEAM_TAG=s-norep seam "$EMIT" "$REGION" "$WORK/no-such-report.md" "$DIST" "$BASE" "$CONSUMER" "$THEIRS"; sn=$RC
if [ "$su" -eq 2 ] && grep -qF 'cannot read the supplied region file' "$WORK/seam/s-unread.err" && [ "$sn" -eq 2 ]; then
  ok "S-EXIT2 an unreadable region file and an absent report each exit 2 (refusals, never a verdict)"
else bad "S-EXIT2 unreadable region rc=$su, absent report rc=$sn (want 2 and 2)"; fi

# --- Assertion 2: --verify FAILS a report with NO region (the narrated bug) ---
SEAM_TAG=a2 seam "$EMIT" "$REGION" "$REPORT_MISSING" "$DIST" "$BASE" "$CONSUMER" "$THEIRS"
[ "$RC" -eq 1 ] && ok "--verify FAILS a report with no rendered region (exit 1)" \
  || bad "--verify did NOT fail a report missing the region (rc=$RC) — a narrated report could drop everything"

# --- Assertion 3: --verify FAILS a region hand-edited to DROP the blocker ------
SEAM_TAG=a3 seam "$EMIT" "$REGION" "$REPORT_STALE" "$DIST" "$BASE" "$CONSUMER" "$THEIRS"
[ "$RC" -eq 1 ] && ok "--verify FAILS a region hand-edited to drop the HARD blocker (exit 1) — an edited render cannot hide a finding" \
  || bad "--verify did NOT catch a dropped-blocker edit (rc=$RC) — the region could still be doctored"

# --- S-AP: THE GATE NEVER TAKES THE SHORTCUT --------------------------------------------------
# apply.sh's union gate must render: no non-comment line of it passes --region-from. The control is the
# same reader finding the --for-apply --verify call itself, so a zero is not a file the reader missed.
rer_ap_hits() { sed -e '/^[[:blank:]]*#/d' "$1" | grep -c -- '--region-from'; }
rer_ap_call() { sed -e '/^[[:blank:]]*#/d' "$1" | grep -c 'emit-report\.sh" --for-apply --verify'; }
RER_APPLY="$(dirname "$EMIT")/apply.sh"
ap_h="$(rer_ap_hits "$RER_APPLY")" || ap_h=0
ap_c="$(rer_ap_call "$RER_APPLY")" || ap_c=0
if [ "$ap_c" -ge 1 ] && [ "$ap_h" -eq 0 ]; then ok "S-AP apply.sh passes no --region-from on any non-comment line (control: its --for-apply --verify call is found, $ap_c)"
else bad "S-AP apply.sh: $ap_h non-comment --region-from line(s), $ap_c --for-apply --verify call(s) found (want 0 and >=1) — the union gate could compare against a region nobody rendered"; fi

# --- Assertion 4: a CLASSIFY file gets an ORIENTATION block -------------------
# The bucket list alone names the file; it says nothing about which side holds what. That
# claim used to live only in LLM prose, and on the 0.106.1 -> 0.113.1 pull it came out
# INVERTED, taking the recommended action down with it.
if grep -q 'templates/classes.md' <<<"$ORIENT"; then
  ok "the BOTH-ADDED file gets an orientation block in the rendered region"
else
  bad "no orientation block for the CLASSIFY file — which side holds what is unstated again"
  render_diag "assertion-4" "seed-print-mode"
fi

# --- Assertion 5: THE DEFECT — each side's line is attributed to THAT side -----
t_side="$(side_of 'SENTINEL-THEIRS-ONLY')"
o_side="$(side_of 'SENTINEL-OURS-ONLY')"
if [ "$t_side" = "THEIRS" ] && [ "$o_side" = "OURS" ]; then
  ok "orientation attributes each side's exclusive line to the correct side (theirs->THEIRS, ours->OURS)"
else
  bad "ORIENTATION INVERTED: upstream's line reported under '$t_side', consumer's under '$o_side'. This is the defect the block exists to prevent, in the block itself."
  render_diag "assertion-5" "seed-print-mode"
fi

# --- Assertion 6: a truncated side never reads as complete --------------------
# The sample is capped. A cap that does not say so turns a partial list into an apparent
# full one — and the resolution is written from it.
if grep -qE 'ONLY IN (THEIRS|OURS) \([0-9]+, complete\)|suppressed' <<<"$ORIENT"; then
  ok "every sample states whether it is complete or how many lines were suppressed"
else
  bad "the orientation sample is neither marked complete nor reports a suppressed count — a truncated side reads as the whole side"
fi

# --- Assertion 7: the escape hatch is present ---------------------------------
if grep -q "full: diff " <<<"$ORIENT"; then
  ok "each file carries a full-diff command, so a truncated sample is never the only source"
else
  bad "no full-diff command emitted — a suppressed tail would be unreachable from the report"
fi

# --- Assertion 8: DOCTORED REPORT — orientation lives INSIDE the verified region --------
# If the block sat outside the GENERATED markers, the LLM could edit or drop it and --verify
# would still pass, which is exactly how the narrated report dropped findings before.
MUT="$WORK/report-orient-doctored.md"
{ echo "# Reconcile report (fixture)"; echo; grep -v 'SENTINEL-OURS-ONLY' "$REGION"; } > "$MUT"
SEAM_TAG=a8 seam "$EMIT" "$REGION" "$MUT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS"
[ "$RC" -eq 1 ] && ok "deleting an orientation line FAILS --verify — the block is inside the verified region" \
  || bad "DOCTORED REPORT DID NOT FAIL (rc=$RC) — orientation can be doctored without --verify noticing, so it is decoration"

# --- Assertion 9: --verify is PORTABLE across distribution checkouts ----------
# The region embeds the absolute dist path in each `full: diff <(git -C … show …)` command.
# The path must stay concrete — a command the operator has to edit before running is a path
# out they cannot walk — but it made the region unequal across checkouts, and --verify
# byte-compares.
#
# Measured: a consumer generated a report from a scratch clone under /private/tmp; verifying
# that same sound report from a normal checkout failed with "STALE or HAND-EDITED" on nothing
# but the path. A false accusation that sends the operator to regenerate a good report — and
# it defeats the reason --verify is offered to operators at all, since they could only trust
# reports generated at their own dist path.
#
# The alias is a symlink: same repository, different literal path, which is exactly the
# difference that used to break it.
ALIAS="$WORK/dist-alias"
ln -sf "$DIST" "$ALIAS" 2>/dev/null
if [ -e "$ALIAS" ]; then
  # RENDER: conflicting-state -- at the ALIAS dist path; the dist path is embedded in the region, so this is the one input
  # the seed render cannot stand in for. The REPORT stays the one rendered at $DIST.
  bash "$EMIT" "$ALIAS" "$BASE" "$CONSUMER" "$THEIRS" > "$WORK/region-alias.md" 2>/dev/null
  if cmp -s "$WORK/region-alias.md" "$REGION" || ! grep -qF "$ALIAS" "$WORK/region-alias.md"; then
    bad "FIXTURE BROKEN — the alias render does not carry the alias path, so the two regions do not differ by the path and assertion 9 cannot discriminate"
  fi
  SEAM_TAG=a9 seam "$EMIT" "$WORK/region-alias.md" "$REPORT_GOOD" "$ALIAS" "$BASE" "$CONSUMER" "$THEIRS"
  if [ "$RC" -eq 0 ]; then
    ok "--verify PASSES a sound report from a DIFFERENT dist checkout (path-independent)"
  else
    bad "--verify FAILED a sound report merely because the dist checkout is at another path — the operator is told a good report is STALE or HAND-EDITED, and can only verify reports generated at their own path"
  fi

  # And normalization must not have blunted it: a real edit still fails from the other path.
  MUT2="$WORK/report-dropped-line.md"
  { echo "# Reconcile report (fixture)"; echo; grep -v 'HARD-UNREGISTERED-CORE-DRIFT' "$REGION"; } > "$MUT2"
  SEAM_TAG=a9b seam "$EMIT" "$WORK/region-alias.md" "$MUT2" "$ALIAS" "$BASE" "$CONSUMER" "$THEIRS"
  if [ "$RC" -eq 1 ]; then
    ok "a dropped HARD row STILL fails from the other path (normalization did not blunt the check)"
  else
    bad "a dropped HARD blocker passed --verify from another dist path — path-independence was bought by weakening the check that stops a report hiding a finding"
  fi
else
  bad "FIXTURE STALE: could not create a symlink alias for the dist checkout"
fi

# --- The push-candidate ledger section --------------------------------------------------
#
# THIS SECTION WAS UNREACHABLE FROM THIS FIXTURE. The seed never wrote a ledger,
# `ledger-reverify.sh` short-circuits on a missing one, and the section rendered `none` — so an
# assertion of the form "no row here is truncated" passed on an empty string. Two label defects
# and a dropped DETAIL field shipped behind exactly that shape of green.
#
# The POSITIVE CONTROL comes first and hard-exits. Every assertion after it is meaningless
# against a `none` section, and a fixture that reports PASS on a section it never rendered is
# the defect it is supposed to catch, wearing the fixture's own badge.
LSEC="$(awk '/Push-candidate ledger —/{f=1;next} f&&/^\*\*/{f=0} f' "$REGION")"
if grep -q 'PC-FIXTURE-EMIT-' <<<"$LSEC"; then
  ok "the ledger section renders real rows (positive control — every ledger assertion below depends on it)"
else
  bad "FIXTURE VACUOUS — the ledger section is empty or 'none'; the assertions below would pass on nothing"
  echo; echo "reconcile-emit-report: FIXTURE VACUOUS" >&2; exit 2
fi

# The name column is a join key back into the ledger. Whole id, not a prefix.
if grep -qF 'PC-FIXTURE-EMIT-UNKNOWN-VERB (a parenthetical this long pushes the pre-dash text past seventy characters)' <<<"$LSEC"; then
  ok "a ledger row names the whole entry, not a clipped prefix"
else
  bad "the ledger row's name is clipped — a truncated name cannot be grepped back into the ledger"
fi

# THE ROW MUST SAY WHY. `NEEDS-REVIEW` alone sends the operator back to a tool they must re-run.
# Both named causes, because they are emitted from different branches.
if grep -q 'unresolved: unknown verify verb' <<<"$LSEC"; then
  ok "a NEEDS-REVIEW row carries its cause (unresolved)"
else
  bad "a NEEDS-REVIEW row reached the report naming no cause — the operator must re-run the tool to learn anything"
fi
if grep -q 'vacuous predicate:' <<<"$LSEC"; then
  ok "a NEEDS-REVIEW row carries its cause (vacuous)"
else
  bad "the vacuous-predicate cause did not reach the report"
fi

# --- Assertion: the sha line is markdown, not shell-escaped markdown ----------
# The region is specified to be pasted VERBATIM into a markdown report, so a literal
# backslash before a backtick renders as an escaped backtick — the shas show wrapped in two
# backslashes instead of as inline code, on the one line the whole report is about. And
# because --verify byte-matches the region against a fresh render, a consumer who writes
# correct markdown gets a FAIL and is pushed back to the malformed text.
base_line="$(grep -m1 '^_base_ ' "$REGION")"
if [ -z "$base_line" ]; then
  bad "FIXTURE BROKEN — the region has no '_base_' line, so the assertion below tests nothing"
elif grep -q '\\`' <<<"$base_line"; then
  bad "the region's sha line carries literal backslash-backticks: $base_line"
else
  ok "the region's _base_/_theirs_ line wraps both shas in real backticks (renders as inline code)"
fi

rm -rf "$CONSUMER/.git"
fi # end rer_phase seeded

# =============================================================================
# THE REF'S SPELLING IS NOT THE REF
# =============================================================================
#
# Every assertion above spells theirs as a SHA, which cannot move. An operator does not: they
# type `origin/main`, or a branch, or let a bare invocation resolve "upstream HEAD". `--verify`
# re-renders from the ref it is handed, and the region rendered only that SPELLING — so with a
# symbolic theirs that moved between the dry run and the apply, the region came back
# byte-identical and `--verify` exited 0. SKILL.md makes that exit the precondition for a write
# to a consumer's core, so a 0 there is an approval given without sight of the finding.
#
# Measured on a consumer built by scripts/install.sh, refs two core files and zero NEW files
# apart: the two regions differed in EXACTLY ONE line, and it was the _base_/_theirs_ line
# naming the spellings. Every other row is a bucket or a status keyed on STATUS+path and
# carries no content digest, so a file whose bucket held and whose CONTENT moved was invisible.
#
# The three arms below run against ONE seeded tree, offender beside near-miss, because a
# nonzero exit on a moved ref and a zero on an unmoved one establish nothing separately: a
# renderer that keys on the COMMIT passes the first and fails the third, and a renderer keying
# on nothing passes the third alone.
DG() { git -C "$DIST" -c user.email=f@f -c user.name=fixture "$@" >/dev/null 2>&1; }

# --- WORLD CONSTRUCTION IS CHECKED, AND A FAILED CONSTRUCTION IS `FIXTURE BROKEN` ----------
#
# WHY THIS IS NOT A STYLE POINT. Step 2 of the self-update treats a RED fixture as evidence
# that the machinery slice is broken, and on that reading it blocks a real pull. So a red cell
# here is a conviction, and the fixture owes it a true cause. Every `DG`/`git checkout` below
# builds a WORLD -- it moves a branch, writes a probe file, commits -- and every one of them
# swallowed both streams and its exit status: measured on this file, 8 world-mutation sites
# and 0 of them checking that the change they intended actually landed.
#
# A world that did not get built does not make the arm downstream of it SKIP. It makes that arm
# read a tree one commit short of the one it assumes, and the arm then reports on
# `emit-report.sh` -- in the fixture's own voice, naming a machinery defect. Two such arms were
# observed red on a tree byte-identical to `theirs`, once in three concurrent runs and not
# again in thirteen: the strip guard's FIXTURE BROKEN, and the docs-only near-miss's "a
# docs-only upstream commit made --verify reject a sound approved report". The second is the
# false conviction in full -- it names the renderer, and the renderer was never involved.
#
# THE DISTINCTION THE FIXTURE COULD NOT DRAW is between "the subject is wrong" and "the world
# I built for the subject is not the world I think it is". Those need different verdicts.
# `bad` is the first. `broken` is the second: it prints, it fails the unit, and it says in the
# line itself that this is not evidence about the machinery -- which is the one fact a step 2
# reading the log needs in order not to convict a correct slice.
#
# NOT A RETRY, AND NOT A SKIP. A retry hides a construction that is unreliable; a skip turns a
# real regression into silence, standing the arm down for a reason indistinguishable from the
# machinery being fine, which is this repo's named defect class. The unit still goes red. What
# changes is WHAT IT SAYS.
#
# EXIT STATUS IS NOT THE WHOLE ANSWER, so there are two helpers. `git commit` with nothing
# staged exits 1, and `git checkout` of a ref that is already HEAD exits 0 having changed
# nothing -- so the status answers "did the command error" while the arms need "is the tree
# now the one I require". `DGW` covers the first and `world_moved` DERIVES the second from the
# repository.
broken() { printf '  FAIL  FIXTURE BROKEN (world construction, NOT a machinery finding) — %s\n' "$1"; fails=$((fails+1)); }

DGW() { # DGW <what> <git-args...> -- run a world mutation and REFUSE if it did not take
  local _what="$1"; shift
  if ! git -C "$DIST" -c user.email=f@f -c user.name=fixture "$@" >/dev/null 2>&1; then
    broken "$_what failed in the scratch dist; every assertion downstream of it reads a tree that was never built"
    return 1
  fi
  return 0
}

world_moved() { # world_moved <what> <ref> <sha-it-must-no-longer-be>
  local _got; _got="$(git -C "$DIST" rev-parse "$2" 2>/dev/null)"
  if [ -z "$_got" ]; then
    broken "$1: '$2' does not resolve in the scratch dist"; return 1
  fi
  if [ "$_got" = "$3" ]; then
    broken "$1: '$2' did not move (still $3), so the world under test is the world before it"; return 1
  fi
  return 0
}

# world_at <what> <ref-that-HEAD-must-now-equal> -- for a `reset --hard`, whose whole job is
# to put HEAD somewhere specific.
#
# A RESET NEEDS A DIFFERENT ASSERTION FROM A COMMIT, and `world_moved` cannot supply it.
# `world_moved` asks "did this ref stop being what it was", which is the right question for a
# commit and the WRONG one for a reset: a `reset --hard` to a ref already at HEAD exits 0
# having done nothing, and the ref it is asked about did not move because it was already
# there. That is precisely the case this whole change says exit status cannot answer, and the
# two reset sites were left with nothing but exit status. So assert the POSTCONDITION the
# reset exists to establish -- HEAD is now at the named ref -- rather than a delta.
world_at() { # world_at <what> <ref>
  local _head _want
  _head="$(git -C "$DIST" rev-parse HEAD 2>/dev/null)"
  _want="$(git -C "$DIST" rev-parse "$2" 2>/dev/null)"
  if [ -z "$_head" ] || [ -z "$_want" ]; then
    broken "$1: HEAD or '$2' does not resolve in the scratch dist"; return 1
  fi
  if [ "$_head" != "$_want" ]; then
    broken "$1: HEAD is $_head but the world requires $_want ('$2'); every assertion downstream reads a tree that was never built"; return 1
  fi
  return 0
}
verify_ref() { bash "$EMIT" --verify "$1" "$DIST" "$BASE" "$CONSUMER" "$2" >/dev/null 2>"$VERIFY_ERR"; RC=$?; }
core_tree_at() { git -C "$DIST" rev-parse "${1}:core" 2>/dev/null; }

# --- THE WORLD GUARDS ARE THEMSELVES CHECKED, BEFORE ANY WORLD IS BUILT -------------------
#
# WHY THIS SECTION EXISTS AT ALL. Every arm below this point depends on `DGW` and
# `world_moved` to tell it that the world it is about to read was actually built. A guard
# that cannot fire reads exactly like one that passed, and here the failure is silent in the
# worst direction: a guard that never refuses leaves the unit reporting on emit-report.sh,
# in the fixture's own voice, about a tree that is one commit short of the one it assumes.
# Step 2 of the self-update treats a RED cell here as evidence the machinery slice is broken
# and blocks a real pull on that reading, so an unproven guard is an unproven conviction.
#
# IT RUNS BEFORE THE CORPUS. Probing after the worlds are built would ask the guards to
# report on trees they have already passed; this asks them about trees constructed for the
# question, in a throwaway repository, and leaves `$DIST` untouched.
#
# THE PAIR IN W3 IS THE WHOLE REASON THERE ARE TWO HELPERS, and neither half establishes it
# alone: `git commit` with nothing staged EXITS 1 while `git checkout` of a ref already at
# HEAD EXITS 0 having changed nothing. A fixture keyed on exit status alone catches the first
# and is blind to the second, and "the command did not error" is not "the tree is now the one
# I require".
echo ""
echo "  --- world-construction guards (probed before any world is built) ---"

# The probe counts `broken` calls by watching `fails`, and restores it afterwards. A probe
# that left its own seeded failures in the tally would fail the unit for succeeding.
_wp_before=0; _wp_fired=0
wp_start() { _wp_before="$fails"; }
wp_end()   { _wp_fired=$(( fails - _wp_before )); fails="$_wp_before"; }
wp_want()  { # wp_want <label> <want-fired> <want-rc> <got-rc> <failmsg>
  if [ "$_wp_fired" -eq "$2" ] && [ "$4" -eq "$3" ]; then ok "  $1"
  else bad "$5 (refusals=$_wp_fired want=$2, rc=$4 want=$3)"; fi
}

# A THROWAWAY REPOSITORY, NEVER `$DIST`. The guards take `$DIST` from the enclosing scope, so
# the probe rebinds it for the duration and restores it — a probe that mutated the real
# scratch dist would change the world every later arm reads.
_WP_REAL_DIST="$DIST"
WPD="$WORK/world-guard-probe"
rm -rf "$WPD"; mkdir -p "$WPD"
if ! git -C "$WPD" init -q 2>/dev/null; then
  bad "FIXTURE BROKEN — could not init the world-guard probe repo, so the guards every arm below relies on are unproven"
else
  DIST="$WPD"
  printf 'seed\n' > "$WPD/a.txt"
  git -C "$WPD" -c user.email=f@f -c user.name=fixture add -A >/dev/null 2>&1
  git -C "$WPD" -c user.email=f@f -c user.name=fixture commit -qm p0 >/dev/null 2>&1
  _WP0="$(git -C "$WPD" rev-parse HEAD 2>/dev/null)"

  # W1 — DGW REFUSES A MUTATION THAT ERRORED. Without this every `|| true` beside a DGW call
  #      is decoration and the helper is a rename of DG.
  wp_start; DGW "a probe checkout of a ref that does not exist" checkout -q no-such-ref-141; _wprc=$?; wp_end
  wp_want "DGW REFUSES a git mutation that failed (and returns non-zero)" 1 1 "$_wprc" \
    "DGW did not refuse a failing git mutation. Every world below is then built by a helper that swallows its own errors, and an arm downstream reads a tree that was never constructed — reporting on emit-report.sh in the fixture's own voice"

  # W2 — AND IT IS QUIET ON ONE THAT WORKED. The other direction: a guard that refuses
  #      everything is indistinguishable from one that discriminates, and it would turn every
  #      green run red for a reason that has nothing to do with the machinery.
  printf 'more\n' >> "$WPD/a.txt"
  wp_start; DGW "a probe stage that must succeed" add -A; _wprc=$?; wp_end
  wp_want "  and stays SILENT on a mutation that succeeded" 0 0 "$_wprc" \
    "DGW refused a git mutation that succeeded — it fires unconditionally, so its refusals carry no information and it would fail every push"

  # W3 — THE DISCRIMINATING PAIR, and requirement (5) in full. Exit status alone is not the
  #      answer, in BOTH directions.
  #  (a) `commit` with nothing staged EXITS 1 — an error that changed nothing. DGW catches it.
  git -C "$WPD" -c user.email=f@f -c user.name=fixture commit -qm p1 >/dev/null 2>&1
  _WP1="$(git -C "$WPD" rev-parse HEAD 2>/dev/null)"
  wp_start; DGW "a probe commit with nothing staged" commit -m "nothing is staged"; _wprc=$?; wp_end
  wp_want "DGW catches a commit with nothing staged (it exits 1 having changed nothing)" 1 1 "$_wprc" \
    "a commit with nothing staged was not refused. That is the world-construction failure that reads as a machinery finding: the next arm reads a tree one commit short of the one it assumes"

  #  (b) `checkout` of a ref ALREADY AT HEAD EXITS 0 having done nothing. DGW cannot see it —
  #      and asserting that it cannot is what makes `world_moved` non-redundant. A fixture
  #      carrying only (a) would read as though exit status were sufficient.
  wp_start; DGW "a probe checkout of the ref already at HEAD" checkout -q "$_WP1"; _wprc=$?; wp_end
  wp_want "  and a checkout of the ref ALREADY at HEAD exits 0, so DGW alone cannot see it" 0 0 "$_wprc" \
    "a no-op checkout was refused by DGW, which would mean exit status does see this case — then world_moved has no subject and one of the two helpers is vacuous"

  # W4 — world_moved REFUSES A REF THAT DID NOT MOVE. This is the half DGW is blind to, and
  #      it is DERIVED from the repository rather than from a value the same block wrote.
  wp_start; world_moved "the probe world" HEAD "$_WP1"; _wprc=$?; wp_end
  wp_want "world_moved REFUSES a ref that did not move (the case DGW cannot see)" 1 1 "$_wprc" \
    "world_moved accepted a ref that is still at the sha captured before the mutation. The no-op checkout above then passes both guards, and the world under test is the world before it"

  # W5 — AND ACCEPTS ONE THAT DID. The other direction.
  printf 'again\n' >> "$WPD/a.txt"
  git -C "$WPD" -c user.email=f@f -c user.name=fixture add -A >/dev/null 2>&1
  git -C "$WPD" -c user.email=f@f -c user.name=fixture commit -qm p2 >/dev/null 2>&1
  wp_start; world_moved "the probe world" HEAD "$_WP1"; _wprc=$?; wp_end
  wp_want "  and ACCEPTS a ref that moved" 0 0 "$_wprc" \
    "world_moved refused a ref that genuinely moved — it fires unconditionally and every world below would report FIXTURE BROKEN on a correct construction"

  # W6 — THE UNRESOLVABLE-REF BRANCH, AND ITS SUBJECT IS NOT WHAT IT LOOKS LIKE.
  #
  # MEASURED, because the obvious probe input reports the opposite of the truth. `git
  # rev-parse <name>` on a ref that does not exist does NOT print empty — it prints the NAME
  # BACK and exits non-zero, so with `2>/dev/null` the capture is `no-such-ref-141`, 18 bytes.
  # That is non-empty, so `[ -z "$_got" ]` is FALSE, the comparison runs, and a name compares
  # unequal to any sha — the helper reports the world as MOVED. Verified in a throwaway repo
  # on this machine, with HEAD at 40 bytes as the same-invocation control: a deleted branch
  # read back as its own name and scored MOVED, where `rev-parse --verify <ref>^{commit}`
  # returned 0 bytes and scored "does not resolve".
  #
  # SO THIS ARM ASSERTS THE MEASURED BEHAVIOUR AND NAMES THE GAP RATHER THAN PRETENDING THE
  # GUARD COVERS IT. The `-z` branch is not vacuous — `rev-parse` of an EMPTY string prints
  # nothing — but the case an operator would expect it to catch, a ref that was deleted or
  # never created, does not reach it. Both are asserted below so a future change to either
  # `world_moved` or to git's output shape moves a cell.
  _wp_rp="$(git -C "$WPD" rev-parse no-such-ref-141 2>/dev/null)"
  if [ -n "$_wp_rp" ] && [ "$_wp_rp" != "$_WP1" ]; then
    ok "  measured: rev-parse of a missing ref prints the NAME back ($_wp_rp), not empty — so world_moved's -z branch is not what catches it (control: HEAD reads $(git -C "$WPD" rev-parse HEAD 2>/dev/null | wc -c | tr -d ' ') bytes)"
    wp_start; world_moved "the probe world" no-such-ref-141 "$_WP1"; _wprc=$?; wp_end
    wp_want "  and world_moved reports such a ref as MOVED, which is the KNOWN GAP: the postcondition is carried by world_at at the reset sites, and by DGW at the checkout sites, not here" 0 0 "$_wprc" \
      "world_moved's behaviour on an unresolvable ref changed. Re-measure what rev-parse prints before adjusting this arm: if it now returns empty, the -z branch catches the case and this expectation should flip to a refusal"
  else
    bad "  rev-parse of a missing ref returned '${_wp_rp:-<empty>}' on this machine, which is neither the name nor a resolvable sha. Both W6 arms are written against a measured output shape and neither is readable until that is re-measured"
  fi
  # W6b — THE `-z` BRANCH DOES HAVE A SUBJECT, and asserting it keeps the branch from reading
  #       as dead code the next reader deletes. An EMPTY ref argument makes rev-parse print
  #       nothing at all.
  wp_start; world_moved "the probe world" "" "$_WP1"; _wprc=$?; wp_end
  wp_want "  and world_moved REFUSES an unresolvable (empty) ref, so the -z branch is load-bearing" 1 1 "$_wprc" \
    "world_moved accepted a ref that resolves to nothing. The -z branch has no subject, and a guard whose removal changes nothing is a loaded gun rather than a check"

  # W7 — world_at ASSERTS A POSTCONDITION, which is the question a `reset --hard` poses and
  #      neither other helper can answer. `world_moved` asks "did this ref stop being what it
  #      was", which is right for a commit and WRONG for a reset: a reset to a ref already at
  #      HEAD exits 0 having done nothing, and the ref did not move because it was already
  #      there. Both directions, against the same tree.
  git -C "$WPD" branch -f probe-target "$_WP1" >/dev/null 2>&1
  wp_start; world_at "the probe reset" probe-target; _wprc=$?; wp_end
  wp_want "world_at REFUSES when HEAD is not at the required ref" 1 1 "$_wprc" \
    "world_at accepted a tree whose HEAD is not where the reset was supposed to put it — the two reset sites then have nothing but exit status, which cannot answer this"
  git -C "$WPD" reset --hard "$_WP1" >/dev/null 2>&1
  wp_start; world_at "the probe reset" probe-target; _wprc=$?; wp_end
  wp_want "  and ACCEPTS once HEAD is there" 0 0 "$_wprc" \
    "world_at refused a reset that landed correctly — it fires unconditionally and both reset sites would report FIXTURE BROKEN on a correct construction"
  # W7b — AND THE NO-OP RESET, which is the case the helper exists for. `reset --hard` to a
  #       ref already at HEAD exits 0 having changed nothing, so DGW is silent; world_at must
  #       still confirm the postcondition rather than inferring it from that silence.
  wp_start; DGW "a probe reset to the ref already at HEAD" reset --hard "$_WP1"; _wprc=$?; wp_end
  wp_want "  a reset to the ref ALREADY at HEAD exits 0, so DGW alone cannot see it" 0 0 "$_wprc" \
    "a no-op reset was refused by DGW, which would mean exit status does answer this — then world_at has no subject and one of the two helpers is vacuous"

  DIST="$_WP_REAL_DIST"
fi

# W7 — THE CENSUS: NO WORLD MUTATION IS LEFT UNCHECKED. Derived from this file rather than
#      hand-listed, because a hand-written site list goes vacuous the release somebody adds a
#      site and nothing announces it. The subject is the bare `DG` verbs that BUILD a world;
#      `DG` itself stays for mutations whose failure is not a world (it is still called by
#      name below), so the census is over the world-building verbs only.
# THE GRAMMAR MATCHES ANY `*DG` WRAPPER, NOT JUST `DG`, AND THAT WIDENING IS A MEASURED
# REPAIR. The previous census keyed on `DG` with a left word boundary, so the `VDG` site --
# the V-M world's own wrapper -- was scored as a NON-INSTANCE and the scan returned a clean
# zero over it. That is this repo's named scan failure: a grammar that cannot spell the thing
# it hunts reports its own subject as absent, and the zero is a floor of unknown depth. Any
# future `XDG`-shaped wrapper is now in the population by construction rather than by someone
# remembering to add it.
_wp_raw="$(grep -nE '(^|[^A-Za-z_])[A-Z]*DG (add|commit|reset|checkout|branch)' "$0")" || _wp_raw=""
_wp_unchecked="$(printf '%s\n' "$_wp_raw" | grep -v '^[0-9]*:#' | grep -c .)" || _wp_unchecked=0
# THE CONTROL, in the same invocation: the checked form must be present in quantity, or a
# zero above means the grammar cannot spell its own subject rather than that the sites are
# gone. A scan that scores its own subject as a non-instance returns a clean zero.
_wp_checked="$(grep -cE '(^|[^A-Za-z_])DGW "' "$0")" || _wp_checked=0
# AND THE GRAMMAR IS POINTED AT ITS OWN SUBJECT BEFORE ITS ZERO IS TRUSTED. A seeded line in
# the wrapper form must match; if it does not, the scan cannot express what it hunts and the
# count beside it means nothing. Built in a temp file, never in this script.
#
# THE SEEDED LINES ARE ASSEMBLED FROM PIECES, so the literal wrapper forms never appear in
# this file. Written out plainly they are matched by the very census above — the scan scores
# its own self-test as an unchecked world mutation and reports 1. Measured exactly that way
# on the first cut: a grammar that can see its own probe cannot be pointed at the corpus.
_wp_gram="$WORK/census-selftest.txt"
_wp_v="DG"
{ printf 'V%s add -A\n' "$_wp_v"
  printf '%s commit -m x\n' "$_wp_v"
  printf 'ZZ%s reset --hard y\n' "$_wp_v"
  printf '%sW "checked" add -A\n' "$_wp_v"; } > "$_wp_gram"
_wp_self="$(grep -cE '(^|[^A-Za-z_])[A-Z]*DG (add|commit|reset|checkout|branch)' "$_wp_gram")" || _wp_self=0
_wp_selfctl="$(grep -cE '(^|[^A-Za-z_])[A-Z]*DG (qqq-no-such-verb)' "$_wp_gram")" || _wp_selfctl=0
if [ "$_wp_self" -lt 3 ] || [ "$_wp_selfctl" -ne 0 ]; then
  bad "FIXTURE BROKEN — the census grammar scored $_wp_self of 3 seeded wrapper forms (impossible-verb control: $_wp_selfctl, want 0). It cannot spell its own subject, so any zero it reports is a floor of unknown depth rather than a finding"
fi
if [ "$_wp_checked" -lt 5 ]; then
  bad "FIXTURE BROKEN — the census grammar found only $_wp_checked checked world mutations. It cannot spell its own subject, so the zero it reports beside them is a floor of unknown depth rather than a finding"
elif [ "$_wp_unchecked" -eq 0 ]; then
  ok "census: 0 unchecked world mutations remain (control, same grammar: $_wp_checked checked ones)"
else
  bad "census: $_wp_unchecked world mutation(s) still run through the unchecked helper, which swallows both streams AND the exit status. A world that did not get built does not make the arm downstream SKIP — it makes that arm read a tree one commit short of the one it assumes, and report on emit-report.sh"
fi

# =============================================================================
# BL-230 — A PRECLASSIFY THAT DID NOT CLASSIFY RENDERS A REFUSAL, NEVER `none`
# =============================================================================
#
# THE DEFECT. emit-report.sh called preclassify as `2>/dev/null || true`, so a run that exited 2,
# and a run that exited 0 printing nothing over a range that moves `core/`, rendered the same
# empty buckets, worklist, orientation, deletions and relocation as a pull with nothing to do.
# Measured under a forced git failure, preclassify exited 0 with EMPTY output in almost every
# case, so a fix that reads only the rc misses the dominant shape -- arm b exists for that one.
#
# FOUR ARMS, scored against the shipping copy:
#   a  preclassify exits 2 having printed a PARTIAL row -> the refusal line in all five
#      pc-derived sections, no `none` in any of them, and the partial row rendered nowhere
#   b  preclassify exits 0 with NO rows while base..theirs moves core/ -> the same, with the
#      `returned no rows while` cause
#   e  --verify against a fresh render carrying the refusal exits non-zero NAMING
#      PRECLASSIFY-REFUSED, for a sound approved report AND for an approved report that itself
#      carries the refusal -- the second is the case the byte-compare alone passes
#   n  THE NEAR-MISS, in its OWN world whose range leaves core/ untouched: preclassify exits 0
#      with no rows, and every section renders `none` with no refusal. The seeded world cannot
#      host it, because its range moves core/; without it a bare `[ -z "$pc" ]` fix passes a and b.
#
# e STANDS DOWN when the forced render carries no refusal line at all. Its guard keys on that
# line, so it cannot be evaluated without it -- and "no refusal line" is arm a's finding, which
# would otherwise be reported twice, by two arms, one of them vacuous.
#
# PRECLASSIFY IS FORCED BY A HOOK INJECTED INTO A COPY, not by a git shim. A shim reaches every
# detector the render drives and moves sections these arms do not own. The preclassify end of
# the failure -- a real git exiting 128 -- is proven against the real program in
# preclassify-rename-row, which also owns the memo arm.
#
# A CONSUMER'S INSTALLED ENGINE MAY PREDATE THE FIX, because this fixture ships ahead of its
# subject. There the arms SKIP. In the distribution the subject is always present, so they run
# whatever the file says -- which is how the pre-fix engine is shown to fail them.
if rer_phase b230; then
case "$EMIT" in
  */core/skills/ai-dlc-update/reconcile/emit-report.sh) B230_DIST=1 ;;
  *) B230_DIST=0 ;;
esac
B230_RUN=1
if ! grep -qF 'DETECTOR-REFUSED  preclassify.sh ${pc_refused}' "$EMIT"; then
  if [ "$B230_DIST" = 0 ]; then
    printf '  SKIP  BL-230 arms a b e n -- the installed emit-report.sh predates the preclassify refusal render; it lands with the pull that carries this fixture\n'
    B230_RUN=0
  else
    printf '  --    (BL-230: this emit-report.sh carries no preclassify refusal render; in the distribution the arms run anyway and must go red)\n'
  fi
fi

# b230_line <file> <exact-line> <replacement> -- rewrite the ONE line equal to <exact-line>.
# ENVIRON rather than -v, because awk -v strips a level of backslashes and one anchor carries
# two. Exit 3 unless exactly one line matched, so a stale anchor cannot pass as an edit.
b230_line() {
  B230_A="$2" B230_B="$3" awk '$0 == ENVIRON["B230_A"] { print ENVIRON["B230_B"]; n++; next } { print } END { exit (n == 1) ? 0 : 3 }' "$1" > "$1.b230" \
    && mv "$1.b230" "$1"
}
B230_HEADS='**Per-file buckets
**Semantic worklist — files needing
**Semantic worklist orientation
**Deletions (apply would
**Scripts relocation'
B230_WANT_A='exited 2 without classifying'
B230_WANT_B="returned no rows while \`${BASE}..${THEIRS}\` changes \`core/\`"
B230_CAUSE='cause: PRECLASSIFY-REFUSED — preclassify.sh exited 2 without classifying'
# The body of the section whose heading line starts with <prefix>, up to the next heading.
b230_sec() { awk -v h="$2" 'f && /^\*\*/ { exit } f { print } index($0, h) == 1 { f = 1 }' "$1"; }
# b230_five <render> <cause> -> empty when the refusal is rendered in all five sections and
# nothing classified leaked through; otherwise what was wrong.
b230_five() {
  local _f="$1" _w="$2" _h _b _m=""
  grep -qF "DETECTOR-REFUSED  preclassify.sh $_w, so this section is NOT a finding of 'none'." "$_f" || _m="no-refusal-line "
  while IFS= read -r _h; do
    _b="$(b230_sec "$_f" "$_h")"
    grep -qF "DETECTOR-REFUSED  preclassify.sh $_w" <<<"$_b" || _m="${_m}[${_h#\*\*}: no refusal] "
    if grep -qx 'none' <<<"$_b"; then _m="${_m}[${_h#\*\*}: none] "; fi
  done <<<"$B230_HEADS"
  if grep -qF "UPSTREAM-ONLY  $MOVED_PROBE_PATH" "$_f"; then _m="${_m}partial-row-rendered "; fi
  printf '%s' "$_m"
}
# b230_none <render> -> empty when a real region renders `none` in the four always-present
# pc sections and carries no preclassify refusal. The orientation block is absent by design there.
b230_none() {
  local _f="$1" _h _m=""
  grep -qF 'BEGIN GENERATED: reconcile-mechanical' "$_f" || _m="no-region "
  if grep -qF 'DETECTOR-REFUSED  preclassify.sh' "$_f"; then _m="${_m}refused "; fi
  while IFS= read -r _h; do
    case "$_h" in *orientation) continue ;; esac
    grep -qx 'none' <<<"$(b230_sec "$_f" "$_h")" || _m="${_m}[${_h#\*\*}: no none] "
  done <<<"$B230_HEADS"
  printf '%s' "$_m"
}
# b230_render <recon-dir> <a|b|n> -> the path of that program's render for that arm, rendered once and
# kept (a and b force preclassify through the hook's env, so each is its own render input; n is the
# near-miss world, a different dist and consumer).
b230_render() {
  local f="$1/.b230-$2.md"
  if [ ! -s "$f" ]; then
    case "$2" in
      # RENDER: conflicting-state -- preclassify forced to exit 2 -- the hook's env changes what render() reads.
      a) FX_B230_PC=rc2 bash "$1/emit-report.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$f" 2>"$f.err" ;;
      # RENDER: conflicting-state -- preclassify forced to print nothing -- a different render input again.
      b) FX_B230_PC=empty bash "$1/emit-report.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$f" 2>"$f.err" ;;
      # RENDER: conflicting-state -- the near-miss world, its own dist and consumer (core/ untouched by the range).
      n) bash "$1/emit-report.sh" "$NM_DIST" "$NM_BASE" "$NM_CONS" "$NM_THEIRS" > "$f" 2>"$f.err" ;;
    esac
  fi
  printf '%s\n' "$f"
}
# b230_cell <B230-a|B230-b|B230-e|B230-n> -> GREEN | KILL | DEAD (KILL: the arm's expectation failed), the reason in
# $WORK/bl230-tip-<arm>.why.
b230_cell() {
  local arm="${1#B230-}" f why="$WORK/bl230-tip-${1#B230-}.why" _e1 _e2
  case "$arm" in
    a|b)
      f="$(b230_render "$B230" "$arm")"
      grep -qF 'BEGIN GENERATED: reconcile-mechanical' "$f" || { echo DEAD; return; }
      if [ "$arm" = a ]; then b230_five "$f" "$B230_WANT_A" > "$why"; else b230_five "$f" "$B230_WANT_B" > "$why"; fi
      [ -s "$why" ] && echo KILL || echo GREEN ;;
    n)
      f="$(b230_render "$B230" n)"
      grep -qF 'BEGIN GENERATED: reconcile-mechanical' "$f" || { echo DEAD; return; }
      b230_none "$f" > "$why"
      [ -s "$why" ] && echo KILL || echo GREEN ;;
    e)
      # Arm e is the COMPARISON: a fresh render carrying the preclassify refusal must be refused by name,
      # for a sound report and for one carrying the refusal itself. The fresh render is the arm-a render;
      # the comparison runs through the seam, so no second render is made for it.
      f="$(b230_render "$B230" a)"
      grep -qF 'BEGIN GENERATED: reconcile-mechanical' "$f" || { echo DEAD; return; }
      # Standing down when the forced render carries no refusal line: that is arm a's finding.
      if ! grep -qF "DETECTOR-REFUSED  preclassify.sh $B230_WANT_A" "$f"; then echo "stood down" > "$why"; echo GREEN; return; fi
      SEAM_TAG="b230-tip-e1" seam "$B230/emit-report.sh" "$f" "$REPORT_GOOD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS"; _e1=$RC
      SEAM_TAG="b230-tip-e2" seam "$B230/emit-report.sh" "$f" "$B230_REFUSED" "$DIST" "$BASE" "$CONSUMER" "$THEIRS"; _e2=$RC
      if [ "$_e1" -ne 0 ] && grep -qF "$B230_CAUSE" "$WORK/seam/b230-tip-e1.err" && [ "$_e2" -ne 0 ] && grep -qF "$B230_CAUSE" "$WORK/seam/b230-tip-e2.err"; then
        echo GREEN
      else
        printf 'sound approved report rc=%s, refusal-carrying approved report rc=%s\n' "$_e1" "$_e2" > "$why"; echo KILL
      fi ;;
    *) echo DEAD ;;
  esac
}

if [ "$B230_RUN" = 1 ]; then
  B230="$WORK/bl230-recon"
  B230_REFUSED="$WORK/bl230-refused-report.md"
  B230_HOOK="$WORK/bl230-hook.txt"
  cat > "$B230_HOOK" <<'B230HOOK'
case "${FX_B230_PC:-}:$MODE" in
  rc2:) printf 'M\tcore/scripts/moved-ref-probe.sh\tscripts/ai-dlc/moved-ref-probe.sh\tUPSTREAM-ONLY\n'
        echo "preclassify: git failed, refusing to classify: forced by the reconcile-emit-report fixture" >&2
        exit 2 ;;
  empty:) exit 0 ;;
esac
B230HOOK
  B230_BUILT=0
  if cp -R "$(dirname "$EMIT")" "$B230" 2>/dev/null \
     && b230_line "$B230/preclassify.sh" 'MODE="${5:-}"' "$(printf '%s\n' 'MODE="${5:-}"'; cat "$B230_HOOK")" \
     && [ "$(grep -c 'FX_B230_PC' "$B230/preclassify.sh")" = 1 ] \
     && bash -n "$B230/preclassify.sh" 2>/dev/null; then
    B230_BUILT=1
  else
    broken "BL-230: could not inject the preclassify forcing hook into a copy of the reconcile dir -- the MODE line it anchors on moved, so every BL-230 arm would score a copy that forces nothing"
  fi

  # THE CONTROL, positive: the hooked copy, unforced, must classify this world exactly
  # as the seed render did. A copy that died, or a hook that fires unasked, fails here and not as
  # a verdict on emit-report.sh.
  if [ "$B230_BUILT" = 1 ]; then
    # NOT A RENDER: the hooked preclassify.sh, UNFORCED, is run directly on the seeded world and its rows are
    # byte-compared with the SHIPPED preclassify.sh's rows. The hook is injected only into preclassify.sh and
    # fires only when FX_B230_PC is set, so equal rows is the control that it fires only when asked; the rows
    # are asserted non-empty and to carry both seeded bucket rows first, so two empty outputs cannot compare equal.
    B230_CTL_H="$WORK/bl230-ctl-hooked.rows"; B230_CTL_S="$WORK/bl230-ctl-shipped.rows"
    bash "$B230/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" > "$B230_CTL_H" 2>"$WORK/bl230-ctl.err"
    bash "$(dirname "$EMIT")/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" > "$B230_CTL_S" 2>/dev/null
    if [ -s "$B230_CTL_S" ] && grep -qF "$MOVED_PROBE_PATH" "$B230_CTL_S" && grep -qF 'templates/classes.md' "$B230_CTL_S" \
       && cmp -s "$B230_CTL_H" "$B230_CTL_S"; then
      ok "BL-230 control: the hooked copy, unforced, renders both seeded bucket rows and no preclassify refusal"
    else
      broken "BL-230: the hooked copy of the reconcile dir, UNFORCED, does not classify the seeded world exactly as the shipped classifier does, so the arms below would measure the copy"
      render_diag "bl230-control" 0 "$WORK/bl230-ctl.err" control-rows
      B230_BUILT=0
    fi
  fi

  # THE NEAR-MISS WORLD. Its range moves docs/ and leaves core/ byte-identical, so preclassify
  # has nothing to classify and exits 0 with no rows -- the one state where an empty `pc` is TRUE.
  NM="$WORK/bl230-nearmiss"; NM_DIST="$NM/dist"; NM_CONS="$NM/consumer"
  mkdir -p "$NM_DIST/core/schemas" "$NM_CONS/.claude/schemas"
  printf '{\n  "rule": "near-miss"\n}\n' > "$NM_DIST/core/schemas/thing.json"
  cp "$NM_DIST/core/schemas/thing.json" "$NM_CONS/.claude/schemas/thing.json"
  nm_git() { git -C "$NM_DIST" -c user.email=f@f -c user.name=fixture "$@" >/dev/null 2>&1; }
  NM_OK=1
  { nm_git init -q && nm_git add -A && nm_git commit -q -m base; } || NM_OK=0
  NM_BASE="$(git -C "$NM_DIST" rev-parse HEAD 2>/dev/null)"
  mkdir -p "$NM_DIST/docs"; printf 'a docs-only commit\n' > "$NM_DIST/docs/note.md"
  { nm_git add -A && nm_git commit -q -m docs-only; } || NM_OK=0
  NM_THEIRS="$(git -C "$NM_DIST" rev-parse HEAD 2>/dev/null)"
  nm_core="$(git -C "$NM_DIST" diff --name-only "$NM_BASE" "$NM_THEIRS" -- core/ 2>/dev/null)"; nm_core_rc=$?
  nm_all="$(git -C "$NM_DIST" diff --name-only "$NM_BASE" "$NM_THEIRS" 2>/dev/null)"
  if [ "$B230_BUILT" = 1 ]; then
    nm_pc="$(bash "$B230/preclassify.sh" "$NM_DIST" "$NM_BASE" "$NM_THEIRS" "$NM_CONS" 2>/dev/null)"; nm_pc_rc=$?
  else
    nm_pc=""; nm_pc_rc=0
  fi
  if [ "$NM_OK" = 0 ] || [ -z "$NM_BASE" ] || [ "$NM_BASE" = "$NM_THEIRS" ]; then
    broken "BL-230: the near-miss world's two commits were not built, so arm n reads a range that does not exist"
  elif [ "$nm_core_rc" -ne 0 ] || [ -n "$nm_core" ] || [ -z "$nm_all" ]; then
    broken "BL-230: the near-miss range must move something and leave core/ untouched (core rows: $(printf '%s' "$nm_core" | grep -c .), all rows: $(printf '%s' "$nm_all" | grep -c .))"
  elif [ "$nm_pc_rc" -ne 0 ] || [ -n "$nm_pc" ]; then
    broken "BL-230: preclassify must exit 0 with no rows over the near-miss range (rc=$nm_pc_rc, rows=$(printf '%s' "$nm_pc" | grep -c .)), or arm n is not the empty-and-true state"
  else
    printf '  --    (BL-230 near-miss preconditions derived: the range moves docs/ only, and preclassify exits 0 with no rows over it)\n'
  fi

  if [ "$B230_BUILT" = 1 ]; then
    { echo "# Reconcile report (fixture)"; echo; cat "$(b230_render "$B230" a)"; } > "$B230_REFUSED"
    b230_arm() { # <letter> <ok-text> <bad-text>
      local c; c="$(b230_cell "B230-$1")"
      case "$c" in
        GREEN) ok "BL-230 arm $1: $2" ;;
        *) bad "BL-230 arm $1 ($c): $3 -- $(tr '\n' ' ' < "$WORK/bl230-tip-$1.why" 2>/dev/null)"
           [ "$1" = e ] && render_diag "bl230-e" "see-why" "$WORK/seam/b230-tip-e1.err" verify-sound "$WORK/seam/b230-tip-e2.err" verify-refused
           [ "$1" = e ] || render_diag "bl230-$1" "print-mode" "$B230/.b230-$1.md.err" "$1-render" ;;
      esac
    }
    b230_arm a "preclassify exiting 2 renders the refusal in all five pc sections, no 'none', and its partial row nowhere" \
      "a preclassify that exited 2 did not render as a refusal in every pc-derived section"
    b230_arm b "preclassify returning NO rows over a range that moves core/ renders the same refusal, naming that cause" \
      "an empty classification over a range that moves core/ rendered as a clean pull"
    b230_arm e "--verify refuses a fresh render carrying the refusal, naming PRECLASSIFY-REFUSED, for a sound report and for one that carries the refusal itself" \
      "--verify did not refuse, by name, a render whose classifier did not classify"
    if grep -q 'stood down' "$WORK/bl230-tip-e.why" 2>/dev/null; then
      printf '  --    (BL-230 arm e STOOD DOWN: the forced render carries no refusal line, which is arm a'"'"'s finding)\n'
    fi
    b230_arm n "near-miss: an EMPTY classification over a range that leaves core/ untouched renders 'none' and no refusal" \
      "near-miss: a range that leaves core/ untouched was refused, or rendered no 'none'"

  fi
fi
fi # end rer_phase b230

if rer_phase moved; then
# The APPROVED render — theirs spelled symbolically, ref sitting where the operator approved it.
REGION_SYM="$WORK/region-symbolic.md"
# RENDER: conflicting-state -- theirs spelled as the BRANCH $MOVEREF; the region names the spelling, so the seed render
# (theirs as a sha) is a different input.
bash "$EMIT" "$DIST" "$BASE" "$CONSUMER" "$MOVEREF" > "$REGION_SYM" 2>/dev/null
REPORT_SYM="$WORK/report-symbolic.md"
{ echo "# Reconcile report (fixture)"; echo; cat "$REGION_SYM"; } > "$REPORT_SYM"
# POSITIVE CONTROL, and it hard-exits. If the symbolic render is empty or missing the probe's
# bucket row, the ref-move arms below are comparing nothing to nothing — and "no difference"
# is exactly what they are built to reject, so a dead render would score as a pass.
if grep -qF "UPSTREAM-ONLY  $MOVED_PROBE_PATH" "$REGION_SYM"; then
  ok "the region renders with theirs spelled symbolically, carrying the moved-ref probe's bucket row (positive control)"
else
  bad "FIXTURE BROKEN — the symbolic render carries no row for $MOVED_PROBE_PATH; every moved-ref assertion below would compare empty to empty"
  echo; echo "reconcile-emit-report: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion: the region carries a CONTENT key for theirs at all ------------
# PRESENCE-shaped on purpose. "No stale-content finding was rendered" is true of a renderer
# that emits nothing, so the arm demands the line and a resolved 40-hex tree — `absent`, the
# renderer's own fallback, fails this.
if grep -qE '^_theirs_ `core/` tree `[0-9a-f]{40}`\.$' "$REGION_SYM"; then
  ok "the region names what theirs RESOLVES TO (a \`core/\` tree), not only how it was spelled"
else
  bad "the region carries no resolved content key for theirs — a moved symbolic ref renders identically and --verify cannot see it"
fi

# --- Assertion: the region also keys on VERSION, which is OUTSIDE the hashed tree -----
# PRESENCE-shaped for the same reason as the arm above. `VERSION` lives at the repository root, so
# a `core/` tree hash cannot see it move — but `write_stamp()` reads `<theirs>:VERSION` into the
# stamp's `version:` field, so an upstream move that bumps the version and touches nothing under
# `core/` changes what the stamp CLAIMS while the tree hash reports no change. Measured upstream:
# 236 of 400 commits touch no `core/` file, and 16 of those move `VERSION`. Deleting this line
# re-opens exactly those 16 and nothing else, which is why it is asserted separately from the tree.
if grep -qE '^_theirs_ `VERSION` `[^`]+`\.$' "$REGION_SYM"; then
  ok "the region keys on theirs' VERSION as well as its \`core/\` tree — the stamp's version field is written from outside the hashed subtree"
else
  bad "the region carries no VERSION key — a move that bumps VERSION without touching core/ is invisible to --verify, and the stamp then claims a version the approval never covered"
fi

# --- Assertion: a CORE move under a fixed spelling FAILS --verify -------------
# The pre-move sha is captured BEFORE the mutation, so `world_moved` compares against what the
# ref actually was rather than against a value this block also wrote.
_pre_harm="$(git -C "$DIST" rev-parse "$MOVEREF" 2>/dev/null)"
DGW "checking out $MOVEREF for the core-move world" checkout -q "$MOVEREF" || true
printf '#!/usr/bin/env bash\necho MOVED-REF-PROBE moved-after-approval\n' > "$DIST/$MOVED_PROBE_PATH"
DGW "staging the core-move world" add -A || true
DGW "committing the core-move world" commit -m "upstream core content moves after the operator approved" || true
world_moved "the core-move world" "$MOVEREF" "$_pre_harm" || true
REGION_HARM="$WORK/region-core-moved.md"
# RENDER: conflicting-state -- the core-move world: upstream's core/ content moved under the same spelling.
bash "$EMIT" "$DIST" "$BASE" "$CONSUMER" "$MOVEREF" > "$REGION_HARM" 2>/dev/null

# THE DISCRIMINATION GUARD, and it runs BEFORE the verdict is read. If the move also shifted a
# bucket, `--verify` would fail on the bucket and the arm would pass against a renderer with no
# content key whatsoever. Stripping the tree line must leave the two regions IDENTICAL — that
# is the old renderer's whole field of view, and it is blind here.
# Strips BOTH identity lines, not only the tree. `VERSION` is rendered beside the tree because it
# sits at the repo root, outside the hashed subtree, and still reaches the stamp. A strip that
# removed only the tree line would leave this guard reporting FIXTURE BROKEN the first time a seed
# moves the ref across a version bump — which is a true statement about the wrong row.
strip_tree() { grep -vE '^_theirs_ (`core/` tree|`VERSION`) ' "$1"; }
strip_tree "$REGION_SYM"  > "$WORK/stripped-approved.md"
strip_tree "$REGION_HARM" > "$WORK/stripped-moved.md"
if [ ! -s "$WORK/stripped-approved.md" ]; then
  bad "FIXTURE BROKEN — stripping the tree line emptied the approved region"
elif cmp -s "$WORK/stripped-approved.md" "$REGION_SYM"; then
  bad "FIXTURE BROKEN — the strip removed nothing, so the guard below compares the tree line against itself"
elif ! cmp -s "$WORK/stripped-approved.md" "$WORK/stripped-moved.md"; then
  bad "FIXTURE BROKEN — the core move shifted a row OTHER than the tree line, so the arm below would fire on that row and pass against a renderer carrying no content key at all"
else
  ok "the core move leaves every STATUS+path row byte-identical — only the tree line can carry it (near-miss control for the arm below)"
fi

SEAM_TAG=mv-core seam "$EMIT" "$REGION_HARM" "$REPORT_SYM" "$DIST" "$BASE" "$CONSUMER" "$MOVEREF"
if [ "$RC" -ne 0 ]; then
  ok "--verify FAILS an approved report once theirs MOVED across a core change under the same spelling (rc=$RC)"
else
  bad "--verify PASSED (rc=0) a report approved before upstream's core moved — the spelling was re-rendered, the content was not, and SKILL.md reads that 0 as authorisation to write bytes the operator never saw"
fi

# --- Assertion: a DOCS-ONLY move must NOT fail --verify -----------------------
# THIS ARM EXISTS TO STOP THE KEY BEING "SIMPLIFIED" INTO A COMMIT KEY. The line is keyed on
# the `core/` TREE deliberately. The distribution commits docs and plans between releases, and
# the live incident that surfaced all of this was exactly that shape — the ref advanced by one
# docs-only commit while `core` was untouched. Keyed on the commit, this arm goes red and the
# consumer is wedged: told to re-emit and re-approve a report that was never wrong. Keyed on
# the tree, it fires when and only when the bytes the pull would WRITE have changed.
#
# If you are here because you changed the key and this arm went red: the arm is the finding.
DGW "resetting to $THEIRS for the docs-only world" reset --hard "$THEIRS" || true
world_at "the docs-only world's reset" "$THEIRS" || true
# CAPTURED AFTER THE RESET, DELIBERATELY. `MOVEREF` is a BRANCH (seed.sh's `git branch -f`)
# and the reset above moves the checked-out branch, so a pre-reset reading of it is a sha the
# commit below is not being compared against -- the delta would be the reset's, not the
# commit's, and a commit that silently did nothing would still look like it moved.
_pre_docs="$(git -C "$DIST" rev-parse "$MOVEREF" 2>/dev/null)"
mkdir -p "$DIST/docs"; printf 'a docs-only commit between releases\n' > "$DIST/docs/note.md"
DGW "staging the docs-only world" add -A || true
DGW "committing the docs-only world" commit -m "docs-only commit — core untouched" || true
world_moved "the docs-only world" "$MOVEREF" "$_pre_docs" || true
REGION_DOCS="$WORK/region-docs-moved.md"
# RENDER: conflicting-state -- the docs-only world: the ref moved by a commit that leaves core/ untouched.
bash "$EMIT" "$DIST" "$BASE" "$CONSUMER" "$MOVEREF" > "$REGION_DOCS" 2>"$WORK/region-docs-moved.stderr"

moved_to="$(git -C "$DIST" rev-parse "$MOVEREF" 2>/dev/null)"
if [ "$moved_to" = "$THEIRS" ]; then
  bad "FIXTURE BROKEN — the docs-only commit did not move $MOVEREF, so the arm below passes on a ref that never moved"
elif [ "$(core_tree_at "$MOVEREF")" != "$(core_tree_at "$THEIRS")" ]; then
  bad "FIXTURE BROKEN — the 'docs-only' commit changed the core tree, so the arm below is not testing a docs-only move"
else
  # A NOTE, not an `ok`. This branch is derived entirely from git and says nothing about
  # emit-report.sh, so it reads TRUE against a subject replaced by `exit 0` — and an `ok` line
  # that survives a silent subject is the exact shape this fixture exists to reject. Its
  # failure branches above stay `bad`, because a seed that did not move the ref, or that moved
  # the core tree, makes the assertion below vacuous.
  printf '  --    (near-miss preconditions derived, not assumed: the docs-only commit moved %s and held the core tree)\n' "$MOVEREF"
fi

SEAM_TAG=mv-docs seam "$EMIT" "$REGION_DOCS" "$REPORT_SYM" "$DIST" "$BASE" "$CONSUMER" "$MOVEREF"
cp "$WORK/seam/mv-docs.err" "$VERIFY_ERR" 2>/dev/null
# Presence conjunct: rc=0 alone is what a renderer that emits NOTHING also produces, so a bare
# exit-code arm here would be absence-shaped and would pass against a subject replaced by
# `exit 0`. The render at the moved ref must therefore still carry the tree line and still
# equal the approved region.
#
# THE MISSING-LINE CASE STANDS DOWN rather than reporting: "the region has no tree line" is the
# presence assertion's finding, and it has already failed the fixture by the time control
# reaches here. Reported twice, one of the two arms is vacuous and the run no longer says which
# one is load-bearing — and the message this arm would print (`--verify` rejected a sound
# report) is FALSE in that state, because rc is 0. Standing down prints no `ok`, so a renderer
# emitting nothing still cannot earn a green from this arm.
if ! grep -qE '^_theirs_ `core/` tree `[0-9a-f]{40}`\.$' "$REGION_DOCS"; then
  # SINGLE-quoted, so a backslash before a backtick is a literal backslash, not an escape —
  # the same quoting bug assertion 16 above exists to catch, in this fixture's own output.
  printf '  --    (docs-only near-miss STANDS DOWN — the region renders no `core/` tree line at all, which the presence assertion above owns)\n'
elif [ "$RC" -eq 0 ] && cmp -s "$REGION_SYM" "$REGION_DOCS"; then
  ok "--verify PASSES the same report after a DOCS-ONLY move — the key is the \`core/\` tree, so a docs commit between releases cannot wedge a consumer's pull"
else
  bad "a docs-only upstream commit made --verify reject a sound approved report (rc=$RC) — keyed on the commit rather than the core tree, this sends the consumer back to re-approve a report that was never wrong"
  render_diag "docs-only" "$RC" "$VERIFY_ERR" verify "$WORK/region-docs-moved.stderr" docs-render
fi
fi # end rer_phase moved

# --- Assertions 12-14: the shadowed-local-validator signal is REACHED by the driver ---
# THE DEFECT. `warn-shadowed-local-validators.sh` shipped in reconcile/, named itself the twin
# of ledger-reverify's CLOSE-CANDIDATE and layer-drift's EXTENSION-RETIRE-CANDIDATE, and both
# of those render here — it did not. SKILL.md named it ZERO times; no step and no driver
# invoked it. `core/fixtures/shadowed-local-validators/` was green over it the whole time,
# which is the trap: a fixture proving a detector WORKS says nothing about whether the shipping
# program RUNS it.
#
# A HEADING PLUS `none` CANNOT CATCH THIS, which is why these arms seed a real row. If the
# driver never called the detector, `sv` would be empty and the section would render `none` —
# byte-identical to a detector that ran and found nothing. The only arm that discriminates is
# one where the detector MUST produce output.
#
# Seeded at the DEFAULT paths, because emit-report.sh passes only `--root`: the ledger at
# `_bmad-output/ai-dlc-update/push-candidate-ledger.md`, forks under `scripts/ai-dlc-local`,
# core twins under `scripts/ai-dlc`. The entry shape is the producer's — a `##` heading and a
# LINE-LEADING `ADOPTED UPSTREAM (…)` annotation, which is what the anchored close grammar in
# ledger-reverify.sh actually accepts.
# THE SHADOW STATE (ledger entries, four forks) IS BUILT BY seed.sh, so the seed render ($REGION) already
# carries it and there is no second render of the consumer: rer_region2 names the seed render.
# RENDER: none -- this is the base-world render, taken once in seed.sh.
rer_region2() { printf '%s\n' "$REGION"; }

if rer_phase shadow; then
SHAD_REGION="$(rer_region2)"

if grep -q 'Shadowed local validators' "$SHAD_REGION"; then
  ok "the driver renders a shadowed-local-validator section at all"
else
  bad "no shadowed-local-validator section in the region — emit-report.sh does not drive warn-shadowed-local-validators.sh, so the detector never runs on a real pull"
fi

# The discriminating arm: a row the detector alone can produce.
if grep -q 'RETIRE-CANDIDATE' "$SHAD_REGION" && grep -q 'scripts/ai-dlc-local/validate-shadowprobe.sh' "$SHAD_REGION"; then
  ok "a CLOSED entry whose fork shadows a core validator reaches the operator as a RETIRE-CANDIDATE row — the detector actually RAN"
else
  bad "the seeded shadowed fork produced no RETIRE-CANDIDATE row in the region. A heading rendering 'none' here is what an uninvoked detector looks like, so this is the arm that separates the two."
fi

# NEGATIVE: the OPEN entry's fork must NOT be flagged. Without this, a detector widened to
# report every fork would satisfy the arm above and look correct.
if grep -q 'validate-keepprobe.sh' "$SHAD_REGION"; then
  bad "the OPEN entry's fork was flagged too — the region is reporting every fork rather than the closed-entry ones, and the arm above would pass on a signal that discriminates nothing"
else
  ok "the OPEN entry's fork is NOT flagged — the rendered signal keeps the CLOSED gate"
fi

# --- Assertion 15: a REFUSING detector renders DETECTOR-REFUSED, never `none` ----------
# The detector's own header: "a caller must be able to tell 'no forks are shadowed' from
# 'this never ran', and those are the same empty output." Exit 2 is a refusal. Rendering
# `none` for it would put a clean line in front of the operator for a check that never
# classified — the failure this whole region exists to prevent, reintroduced by its newest
# section.
#
# The sandbox copies the WHOLE reconcile/ dir: emit-report.sh resolves $SELF beside itself, so
# a copy picks up the stubbed detector, and no shipped file is touched. A sandbox that simply died
# also prints no RETIRE-CANDIDATE row, so the stubbed copy's OWN region must carry the sections the
# stub cannot reach (the HARD blocker and the retired-token section): that is the control that the
# copy ran, read off the one render this world needs.
SHADSTUB="$WORK/shadow-stub"
mkdir -p "$SHADSTUB"
cp "$(dirname "$EMIT")"/*.sh "$SHADSTUB/" 2>/dev/null
cp "$(dirname "$EMIT")"/*.md "$SHADSTUB/" 2>/dev/null
printf '#!/usr/bin/env bash\nexit 2\n' > "$SHADSTUB/warn-shadowed-local-validators.sh"
mut_region="$WORK/shadow-mut-region.txt"
# RENDER: conflicting-state -- a copy whose shadowed-validator detector refuses (a different program for render()): a different program for render().
bash "$SHADSTUB/emit-report.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$mut_region" 2>/dev/null
if grep -q 'HARD-UNREGISTERED-CORE-DRIFT' "$mut_region" && grep -q 'Retired status tokens reused in a consumer layer file' "$mut_region" \
   && grep -qF 'END GENERATED: reconcile-mechanical' "$mut_region"; then
  ok "control: the stubbed sandbox copy still renders the HARD blocker and the retired-token section, so the refusal arm below measures the stub and not a broken sandbox"
else
  bad "FIXTURE BROKEN — the stubbed sandbox copy renders no complete region; the refusal arm below would pass for the wrong reason"
fi
shad_body="$(awk '/Shadowed local validators/{f=1;next} f&&/^\*\*/{exit} f' "$mut_region")"
if grep -q 'DETECTOR-REFUSED' <<<"$shad_body" && ! grep -qx 'none' <<<"$shad_body"; then
  ok "a detector exiting 2 renders DETECTOR-REFUSED and NOT 'none' — a refusal cannot read as a clean section"
else
  bad "a detector exiting 2 did not produce DETECTOR-REFUSED (got: $(printf '%s' "$shad_body" | tr '\n' ' ' | head -c 120)) — the 0/2 split the detector's contract requires is not preserved by the driver"
fi

# --- Assertion 16: the four classifiers that shipped OUTSIDE the region now render in it ------
# SKILL.md step 5 tells the operator this region carries "every mechanical finding, complete,
# from every detector". It did not: four scripts each declaring themselves "a classifier, not a
# gate" were left to be NARRATED, and `--verify` could not fail on their omission because they
# were never in the region to omit.
#
# `I105` binds the SET — every reconcile/*.sh is invoked here or declares itself exempt with a
# reason. That is a join over file contents and it stays true even if a call is wired to a
# detector that emits nothing usable. This arm is the other half: the sections actually RENDER.
i16_missing=""
for i16_h in "Predicate reclassification" \
             "Retired core fixtures the consumer still carries" \
             "Retired contract shapes in consumer layer files" \
             "Retired core passages still carried" \
             "Retired status tokens reused in a consumer layer file"; do
  grep -qF "$i16_h" "$REGION" || i16_missing="$i16_missing | $i16_h"
done
# CONTROL in the same invocation: a heading that cannot be there must not be found, or a grep
# matching everything would report all four present.
if grep -qF "Retired core passages nobody ever wrote" "$REGION"; then
  bad "FIXTURE BROKEN — the control heading matched, so assertion 16's five positives prove nothing"
elif [ -z "$i16_missing" ]; then
  ok "the five previously-narrated classifiers render as sections of the region (control: an impossible heading is absent)"
else
  bad "these classifier sections are missing from the rendered region:$i16_missing — their findings are back to being narrated, where an omission cannot be caught by --verify"
fi
fi # end rer_phase shadow

# =============================================================================
# STEP 3b — THE FOURTH MANDATED DETECTOR, AND THE ONLY ONE THE SKILL NARRATED
# =============================================================================
#
# THE DEFECT. `preclassify.sh --templates` classifies the generated files that live OUTSIDE
# `core/` — the consumer's CLAUDE.md, docs/coding-conventions.md, QUICKSTART.md and
# .claude/settings.json. SKILL.md step 3b told the LLM to run it and narrate the rows under a
# hand-written "Template-changes list"; on the reference consumer's report that section was one
# sentence. `TEMPLATE-PROSE-MERGE` and `TEMPLATE-JSON-MERGE` each carry a step-7 action that
# REWRITES a live consumer file, so a dropped row is a merge nobody performed and nobody can see
# was skipped. `--verify` could not fail on the omission because the rows were never in the
# region to omit — which is the identical shape as assertion 16's five, one release later.
#
# THE FOUR INPUT SHAPES THIS BATTERY DRIVES:
#   S1  the WELL-FORMED pair          — four templates at base, two moved at theirs, three of
#                                       the four generated files on the consumer (the fixture's
#                                       own seeded world). Arms A1, A2, A4, A5.
#   S2  the manifest ABSENT           — a copy of reconcile/ with template-sites.md removed.
#                                       Arm A3.
#   S3  the manifest PRESENT but its  — the same copy with the `template_manifest:` key renamed,
#       `template_manifest:` block      so `-r` passes and the awk parses to nothing. Arm A3's
#       unparseable                     second shape. This is the one no `-r` test can see.
#   S4  a manifest row naming a        — a phantom entry whose template exists at NEITHER ref.
#       template absent at BOTH refs    Arm A2b. base_h == theirs_h == empty, so it buckets
#                                       TEMPLATE-UNCHANGED-NOOP and is indistinguishable in the
#                                       rendered row from a real unchanged template.
#
# EVERY ARM BELOW IS PRESENCE-SHAPED — each demands a specific row or message APPEAR — so a
# subject replaced by `exit 0` fails them by construction rather than passing as a clean absence.
if rer_phase step3b; then
T_SECT() { awk '/Template pre-classification/{f=1;next} f&&/^\*\*/{exit} f' "$1"; }

# t_stage <region-file> <emit-report.sh> — render into a STAGED FILE and return the producer's own
# status, never `T_SECT <(bash …)`. A process substitution discards the producer's exit, and under
# concurrent bash 3.2 workers the reader's open of `/dev/fd/63` can fail with EBADF (BL-230: 3-8 in
# 2000 under 4 workers, 0 staged, the same race 0.647.0 removed from the engine). Either way the
# section read EMPTY, and an empty section is what a CONTROL scores as "the copy rendered no rows" —
# a verdict about emit-report.sh for a failure that was the fixture's own read. Stderr goes to
# `<region-file>.stderr` so a refusal can quote it; a healthy render exits 0 in every world these
# sites drive (the two refusal worlds included — they render DETECTOR-REFUSED at rc 0).
t_stage() { bash "$2" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$1" 2> "$1.stderr"; }
# t_stage_why <region-file> <rc> — the refusal text: the status and the producer's last stderr line.
t_stage_why() { local e; e="$(grep -v '^[[:space:]]*$' "$1.stderr" 2>/dev/null | tail -1 | cut -c1-160)"
  printf 'exited %s (%s)' "$2" "${e:-no stderr}"; }

# THE BATTERY RENDERS ITS OWN REGION, and that is not tidiness. `$REGION` was rendered by seed.sh
# before assertions 12-14 seeded a ledger and two shadowed forks into `$CONSUMER`, so a `--verify`
# against it FAILS on those sections — correctly, and for a reason A4 does not own. MEASURED: A4
# scored good=1 against `$REGION` and 0 against a region rendered here. A stale input makes the
# arm's two sides fail for a reason NEITHER of them names, and its 1-vs-1 null reads as agreement.
T_REGION="$(rer_region2)"
T_SEC="$(T_SECT "$T_REGION")"
# t_rows_missing <section> -> the A2 rows absent from it, or nothing. One reader for A2.
t_rows_missing() {
  local r m=""
  for r in "TEMPLATE-PROSE-MERGE  CLAUDE.md  <- templates/CLAUDE.md.template" \
           "TEMPLATE-JSON-MERGE  .claude/settings.json  <- templates/settings.json.template" \
           "TEMPLATE-UNCHANGED-NOOP  docs/coding-conventions.md  <- templates/coding-conventions.md.template" \
           "CONSUMER-MISSING-NOOP  QUICKSTART.md  <- templates/QUICKSTART.md.template"; do
    grep -qF "$r" <<<"$1" || m="$m | $r"
  done
  printf '%s' "$m"
}

# --- A1 POSITIVE CONTROL: the header renders INSIDE the BEGIN/END markers ------
# It hard-exits. Every arm after it reads $T_SEC, and against an absent section they would all be
# comparing empty to empty — which is the exact shape of the defect this section closes.
#
# The region is extracted by the BEGIN/END sed range FIRST. A header rendered outside the markers
# is a header `--verify` cannot byte-compare, so it is droppable again, and a grep over the whole
# stdout cannot tell the two apart.
T_REGION_ONLY="$(sed -n '/BEGIN GENERATED: reconcile-mechanical/,/END GENERATED: reconcile-mechanical/p' "$T_REGION")"
if [ -z "$T_REGION_ONLY" ]; then
  bad "FIXTURE BROKEN — the BEGIN/END marker range extracted nothing from the render; every step-3b assertion below is unreadable"
  echo; echo "reconcile-emit-report: FIXTURE BROKEN" >&2; exit 2
elif grep -qF 'Template pre-classification (generated files outside core/ — step 3b' <<<"$T_REGION_ONLY"; then
  ok "A1 step 3b renders a Template pre-classification section INSIDE the verified region (positive control — every step-3b assertion below depends on it)"
else
  bad "FIXTURE VACUOUS — no step-3b section inside the BEGIN/END markers. Either the driver does not run preclassify --templates, or the section renders outside the region where --verify cannot reach it and the LLM can drop it again."
  echo; echo "reconcile-emit-report: FIXTURE VACUOUS" >&2; exit 2
fi

# --- A2: the four rows exactly, bucket AND consumer path AND template ----------
# ALL FOUR BUCKETS IN ONE RENDER, which is what makes this an assertion about the classifier
# rather than about its first branch. Before the seed carried `templates/*.template` every row
# bucketed CONSUMER-MISSING-NOOP, because `ours_present` is tested first and the template delta
# was never consulted — four rows, one bucket, and a classifier hardcoded to that bucket would
# have passed.
#
# The TEMPLATE column is asserted too, not just the bucket and the consumer path. It is the join
# key back to `template-sites.md`, and a row naming the wrong template sends the operator to
# merge the wrong file.
t_missing="$(t_rows_missing "$T_SEC")"
# NEAR-MISS IN THE SAME RUN: a row with the right bucket and the WRONG consumer path must not
# match. Without it a grep loosened to the bucket alone reports all four present.
if grep -qF "TEMPLATE-PROSE-MERGE  docs/coding-conventions.md" <<<"$T_SEC"; then
  bad "FIXTURE BROKEN — the near-miss row (right bucket, wrong consumer path) matched, so A2's four positives prove nothing about the path column"
elif [ -z "$t_missing" ]; then
  ok "A2 all four buckets render in ONE section with their consumer path and their template (near-miss control: a right-bucket/wrong-path row is absent)"
else
  bad "A2 these step-3b rows are missing from the rendered section:$t_missing — a bucket carrying a step-7 merge action is not reaching the operator through the region, so it is narrated again and droppable"
fi

# --- A2b: the UNCHANGED-NOOP row's template EXISTS as a blob at base -----------
# MEASURED, and it is why this arm is not redundant with A2. A manifest row naming a template
# that exists at NEITHER ref gets base_h == theirs_h == empty, buckets TEMPLATE-UNCHANGED-NOOP,
# and renders a row byte-indistinguishable from a real unchanged template. So a typo in
# `template-sites.md` — or a template deleted upstream and left in the manifest — reads as
# "upstream boilerplate identical, nothing to sync" forever.
#
# Shape S4 builds that world explicitly rather than reasoning about it: a copy of reconcile/
# whose manifest carries a phantom entry, a consumer file at the phantom's path, and the
# assertion that the classifier renders the phantom as UNCHANGED-NOOP exactly like the real one.
# The arm that discriminates is the git blob test, in the same run.
t_unchanged_tpl="$(awk '/^TEMPLATE-UNCHANGED-NOOP /{print $NF; exit}' <<<"$T_SEC")"
if [ -z "$t_unchanged_tpl" ]; then
  bad "A2b no TEMPLATE-UNCHANGED-NOOP row to check — A2 above should already have failed, and this arm has no subject"
elif git -C "$DIST" cat-file -e "${BASE}:${t_unchanged_tpl}" 2>/dev/null; then
  # CONTROL, same invocation: a path that cannot be a blob at base must fail the same test, or
  # `cat-file -e` is answering yes to everything and the arm above proves nothing.
  if git -C "$DIST" cat-file -e "${BASE}:templates/ZZ-NO-SUCH-TEMPLATE-ZZ.template" 2>/dev/null; then
    bad "FIXTURE BROKEN — git cat-file -e resolved an impossible template path at base, so A2b's positive means nothing"
  else
    ok "A2b the UNCHANGED-NOOP row's template ($t_unchanged_tpl) is a real blob at base — a manifest typo naming a template absent at BOTH refs also buckets UNCHANGED-NOOP, and this is what separates the two (control: an impossible path does not resolve)"
  fi
else
  bad "A2b the UNCHANGED-NOOP row names $t_unchanged_tpl, which is NOT a blob at base — that row is a manifest typo or a template deleted upstream reading as 'boilerplate identical, nothing to sync', which is the silent direction"
fi

# The S4 world, proving the hazard A2b guards is REAL and not reasoned: the phantom row renders
# identically to the genuine one, so nothing in the SECTION can tell them apart.
T_PHANTOM="$WORK/tpl-phantom"
rm -rf "$T_PHANTOM"; cp -R "$(dirname "$EMIT")" "$T_PHANTOM"
awk '/^  # structured config/{print "  - template: templates/ZZ-NO-SUCH-TEMPLATE-ZZ.template";
                              print "    consumer: ZZ-PHANTOM.md";
                              print "    kind: token-prose"} {print}' \
  "$(dirname "$EMIT")/template-sites.md" > "$T_PHANTOM/template-sites.md"
if cmp -s "$(dirname "$EMIT")/template-sites.md" "$T_PHANTOM/template-sites.md"; then
  bad "A2b's S4 world DID NOT APPLY — the awk matched no insertion point in template-sites.md, so the hazard this arm guards is unproven"
else
  printf 'phantom consumer file\n' > "$CONSUMER/ZZ-PHANTOM.md"
  t_ph_region="$WORK/tpl-phantom-region.txt"
  # RENDER: conflicting-state -- S4: a manifest carrying a phantom entry, and a consumer carrying the phantom's file.
  bash "$T_PHANTOM/emit-report.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$t_ph_region" 2>/dev/null
  t_ph_sec="$(T_SECT "$t_ph_region")"
  rm -f "$CONSUMER/ZZ-PHANTOM.md"
  if grep -qF "TEMPLATE-UNCHANGED-NOOP  ZZ-PHANTOM.md  <- templates/ZZ-NO-SUCH-TEMPLATE-ZZ.template" <<<"$t_ph_sec" \
     && grep -qF "TEMPLATE-UNCHANGED-NOOP  docs/coding-conventions.md" <<<"$t_ph_sec"; then
    ok "A2b/S4 a manifest row whose template exists at NEITHER ref renders as TEMPLATE-UNCHANGED-NOOP beside the genuine one — the two are indistinguishable in the section, which is why A2b asserts the blob and not the row"
  else
    bad "A2b/S4 the phantom manifest entry did not render as an UNCHANGED-NOOP row beside the genuine one, so the blob assertion above is guarding a hazard this tree cannot produce. Section was: $(printf '%s' "$t_ph_sec" | tr '\n' ' ' | head -c 200)"
  fi
fi

# --- A3: BOTH refusal shapes render DETECTOR-REFUSED, never `none` -------------
# `none` and "the classifier could not classify" are the same empty output, and the whole region
# exists because those two must never look alike to an operator. MEASURED before the fix: with
# `template-sites.md` absent the awk printed to stderr, the loop read nothing, the block hit its
# own `exit 0`, and stdout was EMPTY at rc=0 — so `none` rendered for a detector that classified
# nothing, on a section whose two merge buckets rewrite live consumer files.
#
# TWO SHAPES, because they are the same absence one level apart and only one of them is visible
# to a `-r` test.
t_refuse_world() { # t_refuse_world <dir> <shape> -> builds a reconcile copy, prints nothing
  rm -rf "$1"; cp -R "$(dirname "$EMIT")" "$1" || return 1
  [ -f "$1/preclassify.sh" ] || return 1
  case "$2" in
    absent) rm -f "$1/template-sites.md" ;;
    unparseable)
      awk '/^template_manifest:/{print "template_manifest_RENAMED_BY_FIXTURE:"; next} {print}' \
        "$(dirname "$EMIT")/template-sites.md" > "$1/template-sites.md" ;;
  esac
}
# A SANDBOX THAT SIMPLY DIED renders no rows either, and that is indistinguishable from the refusal
# branch working. So the control is read off the refusing sandbox's OWN region: it must be
# complete (END marker) and still carry the HARD blocker, which no template-manifest change can reach.
t_refuse_check() { # t_refuse_check <label> <shape> <what-the-shape-is>
  local d="$WORK/tpl-refuse-$2" mut s_rc
  t_refuse_world "$d" "$2" || { bad "$1 could not build the $2 sandbox"; return; }
  # RENDER: conflicting-state -- the template manifest absent (A3a) or unparseable (A3b): two classifier inputs that cannot coexist with the well-formed manifest.
  s_rc=0; t_stage "$d.region" "$d/emit-report.sh" || s_rc=$?
  if ! grep -qF 'END GENERATED: reconcile-mechanical' "$d.region" 2>/dev/null || ! grep -q 'HARD-UNREGISTERED-CORE-DRIFT' "$d.region"; then
    bad "$1 CONTROL the $2 sandbox rendered no complete region carrying the HARD blocker, so the refusal assertion below would pass for a sandbox that simply died"
    return
  fi
  if [ "$s_rc" -ne 0 ]; then
    bad "FIXTURE BROKEN — $1 the $2 sandbox's render $(t_stage_why "$d.region" "$s_rc"), so whether it renders DETECTOR-REFUSED was not read"
    return
  fi
  mut="$(T_SECT "$d.region")" || { bad "FIXTURE BROKEN — $1 could not read the $2 sandbox's staged region"; return; }
  if grep -q 'DETECTOR-REFUSED' <<<"$mut" && ! grep -qx 'none' <<<"$mut" && ! grep -q 'TEMPLATE-' <<<"$mut"; then
    ok "$1 $3 renders DETECTOR-REFUSED and NOT 'none' (control: the same render still carries the HARD blocker)"
  else
    bad "$1 $3 did not render DETECTOR-REFUSED (got: $(printf '%s' "$mut" | tr '\n' ' ' | head -c 140)) — a classifier that could not classify is putting a clean line in front of the operator, which is the defect this whole region exists to prevent, reintroduced by its newest section"
  fi
}
t_refuse_check "A3a" absent      "the template manifest ABSENT"
t_refuse_check "A3b" unparseable "the manifest PRESENT with its template_manifest: block unparseable (the shape no -r test can see)"

# --- A4: --verify is 0 on the render and 1 with a step-3b row deleted ----------
# The section being rendered is half of it. The reason it is rendered is that `--verify`
# byte-compares it, so a row deleted by hand has to FAIL — otherwise the rows are back to being
# droppable and this section is decoration inside a verified region.
#
# Offender and near-miss in the same pair: the PROSE-MERGE row deleted (offender, must fail) and
# the untouched report (near-miss, must pass), one property apart.
T_RPT_GOOD="$WORK/tpl-report-good.md"
{ echo "# Reconcile report (fixture)"; echo; cat "$T_REGION"; } > "$T_RPT_GOOD"
T_RPT_CUT="$WORK/tpl-report-row-cut.md"
{ echo "# Reconcile report (fixture)"; echo; grep -vF 'TEMPLATE-PROSE-MERGE  CLAUDE.md' "$T_REGION"; } > "$T_RPT_CUT"
if cmp -s "$T_RPT_GOOD" "$T_RPT_CUT"; then
  bad "A4 the row-deletion produced an identical report — the PROSE-MERGE row is not in the region, so this arm has no subject"
else
  SEAM_TAG=t-a4g seam "$EMIT" "$T_REGION" "$T_RPT_GOOD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS"; t_v_good="$RC"
  SEAM_TAG=t-a4c seam "$EMIT" "$T_REGION" "$T_RPT_CUT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS"; t_v_cut="$RC"
  if [ "$t_v_good" -eq 0 ] && [ "$t_v_cut" -eq 1 ]; then
    ok "A4 --verify PASSES the rendered report (0) and FAILS it with the TEMPLATE-PROSE-MERGE row hand-deleted (1) — a step-3b row cannot be dropped from an approved report"
  else
    bad "A4 --verify scored good=$t_v_good cut=$t_v_cut (want 0 and 1) — either a sound report is falsely accused, or a hand-deleted step-7 merge row survives the byte-compare and the rows are droppable again inside a region that claims they are not"
  fi
fi

# --- A5: the section is sited OUTSIDE the ORIENT range -------------------------
# THE SILENT ONE. `$ORIENT` at the top of this file is `awk '/Semantic worklist
# orientation/,/^\*\*Deletions/'` — a range over section ORDER, not content. A step-3b section
# placed inside it widens what assertions 4-7 read while all four stay green, because each of
# them greps for something that is still there.
#
# THE RANGE MUST BE NON-EMPTY FIRST, and that is not a formality: this fixture's OTHER worlds
# produce no CLASSIFY file, the range collapses to ZERO lines there, and "no header in an empty
# range" is true of every possible siting. So this arm runs ONLY on the seeded world that
# renders an orientation block, and the control is asserted before the absence is read.
t_orient_lines="$(grep -c . <<<"$ORIENT")" || t_orient_lines=0
t_region_buckets="$(grep -c 'TEMPLATE-PROSE-MERGE\|TEMPLATE-JSON-MERGE\|TEMPLATE-UNCHANGED-NOOP\|CONSUMER-MISSING-NOOP' "$REGION")" || t_region_buckets=0
if [ "$t_orient_lines" -lt 2 ] || [ "$t_region_buckets" -eq 0 ]; then
  bad "A5 CONTROL the ORIENT range holds $t_orient_lines line(s) and the whole region holds $t_region_buckets bucket token(s) — an empty range makes the absence below true of every siting, so this arm would be vacuous. It must run on the world that produces a CLASSIFY file."
else
  t_o_hdr="$(grep -c 'Template pre-classification' <<<"$ORIENT")" || t_o_hdr=0
  t_o_bkt="$(grep -c 'TEMPLATE-PROSE-MERGE\|TEMPLATE-JSON-MERGE\|TEMPLATE-UNCHANGED-NOOP\|CONSUMER-MISSING-NOOP' <<<"$ORIENT")" || t_o_bkt=0
  if [ "$t_o_hdr" -eq 0 ] && [ "$t_o_bkt" -eq 0 ]; then
    ok "A5 the step-3b section sits OUTSIDE the ORIENT range: $t_orient_lines non-empty lines in the range, 0 header hits and 0 bucket hits inside it, against $t_region_buckets bucket hits in the whole region"
  else
    bad "A5 the step-3b section is INSIDE the range assertions 4-7 read ($t_o_hdr header hit(s), $t_o_bkt bucket hit(s) in $t_orient_lines lines) — those four arms are now reading a wider span than the orientation block and every one of them still passes, which is the silent widening this arm exists to catch"
  fi
fi

fi # end rer_phase step3b

# =============================================================================
# A MISMATCH IS DECIDED, NOT ONLY REPORTED
# =============================================================================
#
# THE DEFECT. SKILL.md step 7 requires every `HARD-*` blocker resolved BEFORE apply.sh writes,
# and every resolution REWRITES the region the operator approved — a `--stamp readopt` turns
# HARD-OVERRIDE-DRIFT-SECTION into OVERRIDE-OK, a register row removes
# HARD-LAYER-ADJUDICATION-MISSING. So on any pull that had a blocker the approved report lists
# findings that no longer exist, `--verify` fails, and the refusal named two causes that were
# both false. `--verify` now DECIDES: exit 3 with `cause: BLOCKERS-RESOLVED` when the refs are
# unchanged, the approved region carries HARD-* rows the fresh render lacks, the fresh render
# carries none the region lacks, and no detector newly REFUSED; `cause: UPSTREAM-MOVED` when the
# `_base_`/`_theirs_` lines differ; `cause: STAMP-MOVED` when the consumer's own stamp line does;
# else `cause: UNDECIDED`. Every case is still a REFUSAL — only
# the diagnosis moved, and the rows the approval has not seen are counted and listed rather than
# asserted away.
#
# THE SEEDS BELOW ARE SEPARATE WORLDS, each its own copy of the seeded consumer with its own
# approved report rendered AT THAT COPY'S PATH. The region embeds the consumer's absolute path in
# its `full: diff` commands, so a world sharing one report with another is comparing two paths and
# fails for a reason no arm owns; and a world mutated in place is decided by the previous world's
# leftovers.
#
#   V-R  the blocker RESOLVED (the consumer's in-place schema edit reverted to base bytes)
#        -> 3, BLOCKERS-RESOLVED, ONE blocker counted although it renders TWICE, and ZERO
#           unseen rows: the boilerplate a resolution moves into the diff is excluded
#   V-N  resolved AND a NEW HARD row the approval never saw          -> 1, UNDECIDED
#   V-M  resolved AND theirs moved across a core change              -> 1, UPSTREAM-MOVED
#   V-B  a NON-HARD row resolved, refs unchanged                     -> 1, UNDECIDED
#   V-H  the blocker HAND-DROPPED from the region, BOTH copies       -> 1, UNDECIDED
#   V-HA V-H plus a blocker-adjudication file in the consumer        -> 1, UNDECIDED
#   V-S  resolved AND the consumer's STAMP moved                     -> 1, STAMP-MOVED: its own
#           cause, decided between the other two, because the stamp is neither upstream moving
#           nor a finding — and dropped from the key altogether a post-apply re-run read as
#           blockers RESOLVED and was told to re-approve a range already applied
#   V-U  resolved AND a non-HARD row the approval never saw          -> 3, ONE unseen row named
#   V-D  the blocker STILL UNRESOLVED, verified by a copy whose
#        unregistered-drift.sh exits 2                               -> 1, UNDECIDED, one
#           DETECTOR-REFUSED line: an absent HARD row with nobody to vouch for it
#   V-DR the same dead-detector copy with the blocker RESOLVED       -> the same (control: the
#           refusal blocks the cause whatever the disk says)
#   V-HC ONLY the padded blocking-list copy of the HARD row deleted
#        from the report, its detector-section copy left             -> 1, UNDECIDED with BOTH
#           counts ZERO: normalised first, the two sides carry the same row
#   V-HB the blocker unresolved and hard-blockers.sh exiting 2, so
#        the blocking list renders REFUSED                           -> 1, UNDECIDED, one
#           DETECTOR-REFUSED line
#
# V-N, V-H, V-HA, V-D, V-HC and V-HB are the acquittal-side seeds and they are the reason this is
# not one arm. V-R alone is satisfied by "exit 3 whenever anything left the region", which acquits
# a finding the operator never saw; each of the six carries exactly one property V-R lacks.
# V-R and V-U are the discriminating PAIR for the unseen count — same verdict, same cause, and the
# count is 0 on one and 1 on the other, so a count that stopped excluding boilerplate is visible
# as a cell and not as a wording change.
if rer_phase vworlds1; then
VW="$WORK/vworlds"; mkdir -p "$VW"
V_WORLDS="V-R V-N V-M V-B V-H V-HA V-S V-U V-D V-HC V-HB"
# V-DR is a CONTROL on V-D: its claim is that the refusal blocks the resolved cause whether or not the operator resolved
# anything.
V_CONTROL_WORLD="V-DR"
V_HARD='HARD-UNREGISTERED-CORE-DRIFT'
V_BASELINE='BOTH-ADDED->CLASSIFY  core/skills/ai-dlc/templates/classes.md'
VMD="$WORK/v-stubs"; mkdir -p "$VMD"

v_copy()    { local d="$VW/$1"; rm -rf "$d"; mkdir -p "$d" && cp -R "$CONSUMER" "$d/consumer"; }

# R6 — A WORLD BUILT OR SCORED UNDER A REFUSAL THE HEALTHY WORLD DOES NOT CARRY IS NOT A VERDICT.
#
# Every render here is ONE render, never a bounded retry (BL-868: zero tests depend on load). The
# retry this replaced re-rendered up to three times on a spontaneous `orientation diff exited 2`,
# so how often load reached that race decided how many renders ran. The race was bash 3.2's
# `/dev/fd/63: Bad file descriptor` on the engine's old `diff <(…) file`; the engine now stages
# THEIRS in its own per-process `mktemp -d` and pipes it through `er_pdiff`, and
# `emit-report-refusal`'s A7 forces that interleaving on the engine's own text (5 of 5 survive).
# So a foreign refusal in a single render is a broken world or an engine defect, reported here,
# never retried into agreement.
#
# THE BASELINE IS DERIVED, NEVER LISTED. The seed world carries one legitimate refusal on every
# clean run (`retired-layer-token.sh`), so keying on `^DETECTOR-REFUSED` at large would fail every
# approval. `V_REFUSE_OK` is the set of detector NAMES the seed region refuses; a scoring program
# built by `v_stub` adds the one sibling it killed, read from the `.stubbed` file `v_stub` writes
# beside it.
V_REFUSE_OK="$(awk 'index($0, "DETECTOR-REFUSED  ") == 1 { split($0, f, " "); printf "%s ", f[2] }' "$REGION")"
# v_foreign <file> <line-lead> [<extra-ok-name>] -> the first column-0 refusal (after the lead,
# which is `< ` for the fresh-render side of a --verify diff) naming a detector outside the
# baseline. One awk per call: the whole cost of R6 on a healthy run.
v_foreign() {
  awk -v lead="$2" -v ok=" $V_REFUSE_OK ${3:-} " '
    index($0, lead "DETECTOR-REFUSED  ") == 1 {
      l = substr($0, length(lead) + 1); split(l, f, " ")
      if (index(ok, " " f[2] " ") == 0) { print l; exit }
    }' "$1"
}
v_approve() { # v_approve <world> <ref-to-render-at>
  local d="$VW/$1" x=""
  printf '%s\n' "$2" > "$d/ref"
  bash "$EMIT" "$DIST" "$BASE" "$d/consumer" "$2" > "$d/region.md" 2>/dev/null
  x="$(v_foreign "$d/region.md" "")"
  [ -n "$x" ] && bad "FIXTURE BROKEN — $1 approval's one render carried a refusal the seed world does not: $x — a detector refusing on this world and not on the seed is an engine defect or a broken world, never a transient to retry"
  { echo "# Reconcile report (fixture)"; echo; cat "$d/region.md"; } > "$d/approved.md"
  [ -s "$d/region.md" ]
}
# THE RESOLUTION, and it is the shipping producer's own bytes rather than a hand-written
# near-miss: the consumer's copy is put back to exactly what `git show "${base}:<path>"` holds, as
# a real adjudication does.
v_resolve() { git -C "$DIST" show "${BASE}:core/schemas/thing.json" > "$VW/$1/consumer/.claude/schemas/thing.json"; }
v_render()  { local d="$VW/$1"; bash "${2:-$EMIT}" "$DIST" "$BASE" "$d/consumer" "$(cat "$d/ref")" 2>/dev/null; }
# v_subst <region-file> <consumer-path> -> the region with the seed consumer's path replaced by <consumer-path>.
v_subst() {
  RER_F="$CONSUMER" RER_T="$2" awk 'BEGIN { f = ENVIRON["RER_F"]; t = ENVIRON["RER_T"]; n = length(f) }
    { s = $0; o = ""; while ((i = index(s, f)) > 0) { o = o substr(s, 1, i - 1) t; s = substr(s, i + n) } print o s }' "$1"
}
# v_approve_sub <world> -- COMPARE-SIDE approval: a world whose consumer is still the pristine seed consumer
# at approval time has, as its approved region, the seed render ($REGION) with the consumer path replaced
# (the only per-world input the region embeds). The substituted bytes are only an input to the comparison
# (`--region-from` and the approved report); the producer-side question is owned by V-R's real approval, which
# is byte-compared with its own substitution below, and by every world's fresh render.
v_approve_sub() {
  local d="$VW/$1"
  printf '%s\n' "$THEIRS" > "$d/ref"
  v_subst "$REGION" "$d/consumer" > "$d/region.md"
  { echo "# Reconcile report (fixture)"; echo; cat "$d/region.md"; } > "$d/approved.md"
  [ -s "$d/region.md" ]
}

# A COPY OF THE RECONCILE DIRECTORY with one sibling replaced by a refusal: the refusing-detector worlds are
# rendered and verified by the engine copy whose detector refuses.
v_stub() { # v_stub <emit-path> <dest-dir> <sibling-to-refuse> -> prints the emit path inside dest
  local e="$1" d="$2" s="$3"
  rm -rf "$d"; cp -R "$(dirname "$e")" "$d" || return 1
  printf '#!/usr/bin/env bash\nexit 2\n' > "$d/$s"
  # Read by v_score: this program's refusal of `$s` is the world's subject, not a transient.
  printf '%s\n' "$s" > "$d/.stubbed"
  printf '%s\n' "$d/$(basename "$e")"
}

# R6-BASE — THE DERIVED BASELINE IS PINNED TO THE ONE REFUSAL THE SEED IS KNOWN TO CARRY (BL-338).
# `V_REFUSE_OK` is read off the engine's own seed render, so an engine regression that refuses on
# EVERY world — the seed included — lands in the accepted set and R6 absorbs it: every approval
# and every score then reads clean. The derivation stays (it is what keeps the foreign-refusal
# check off the seed's legitimate refusal); this arm is the independent side of the join, a FIXED name.
R6_FIXED_OK='retired-layer-token.sh'
r6_set() { printf '%s\n' $1 | awk 'NF' | sort -u | tr '\n' ' ' | sed 's/ $//'; }
_r6_have="$(r6_set "$V_REFUSE_OK")"
if [ "$_r6_have" = "$R6_FIXED_OK" ]; then
  ok "R6-BASE the derived refusal baseline is exactly {$R6_FIXED_OK}, the one refusal the seed world is known to carry — an engine refusal on every world cannot hide inside it"
else
  bad "R6-BASE the seed render's refusal set is [${_r6_have:-empty}], not exactly {$R6_FIXED_OK}: R6 would absorb that refusal on every world, so a detector the engine ships refusing everywhere reads as a clean baseline"
fi

# v_score <emit> <world> <tag> <region-file> -> "<rc>|<cause>|<resolved-lines>|<n1>|<n2>|<unseen-lines>"
#
# PRESENCE-SHAPED IN EVERY FIELD. `rc` alone is what a subject replaced by `exit 1` also produces,
# so the cause word, the two counts the cause line prints IN ORDER (BLOCKERS-RESOLVED: blockers
# gone, unseen rows; UNDECIDED: new HARD rows, new DETECTOR-REFUSED lines) and the number of
# `resolved:`/`unseen:` lines are all part of the cell. A classifier that decides nothing scores
# `1|NONE|0|NA|NA|0` and matches no expected value here.
#
# AND THE COUNTS ARE IN THE CELL because some worlds differ only in the diagnosis fields and not in the verdict.
#
# R6 ON THE SCORING SIDE. A refusal in the FRESH render (the `< ` side of the forwarded diff) that
# the healthy world does not carry is not a verdict. Scoring is ONE --verify, never re-scored, and
# runs in background jobs where `bad` cannot count, so such a refusal leaves `broken.<tag>` beside
# the score and the foreground reports it (`v_broken_scan`).
v_score() {
  local e="$1" d="$VW/$2" f="$VW/$2/stderr.$3" rc cause nres nuns c1 c2 x="" sok="" rf="$4"
  [ -f "${e%/*}/.stubbed" ] && read -r sok < "${e%/*}/.stubbed"
  # THE SEAM: compare against the world's ONE render (<rf>) instead of rendering again.
  bash "$e" --verify --region-from "$rf" "$d/approved.md" "$DIST" "$BASE" "$d/consumer" "$(cat "$d/ref")" >"$d/seam.$3.out" 2>"$f"
  rc=$?
  if [ "$(sed -n 1p "$d/seam.$3.out")" = "$RER_SEAM_MARK" ]; then echo "MARK v-$2-$3" >> "$WORK/seam.log"
  else echo "NOMARK v-$2-$3 rc=$rc" >> "$WORK/seam.log"; fi
  x="$(v_foreign "$f" "< " "$sok")"
  rm -f "$d/broken.$3"
  [ -n "$x" ] && printf '%s\n' "$x" > "$d/broken.$3"
  cause="$(awk '/^  cause: /{print $2; exit}' "$f")"
  nres="$(grep -c '^    resolved: ' "$f")" || nres=0
  nuns="$(grep -c '^    unseen: ' "$f")" || nuns=0
  c1="$(awk '/^  cause: /{n=0; for(i=3;i<=NF;i++) if ($i ~ /^[0-9]+$/) { n++; if (n==1) { print $i; exit } } exit}' "$f")"
  c2="$(awk '/^  cause: /{n=0; for(i=3;i<=NF;i++) if ($i ~ /^[0-9]+$/) { n++; if (n==2) { print $i; exit } } exit}' "$f")"
  printf '%s|%s|%s|%s|%s|%s\n' "$rc" "${cause:-NONE}" "$nres" "${c1:-NA}" "${c2:-NA}" "$nuns"
}
v_sig() { # v_sig -- scores every world under the shipped program, writing each score beside the world
  local n p
  for n in $V_WORLDS; do
    case "$n" in V-D) p="$V_DEAD_DRIFT" ;; V-HB) p="$V_DEAD_HB" ;; *) p="$EMIT" ;; esac
    v_score "$p" "$n" ship "$VW/$n/fresh.ship.md" > "$VW/$n/score.ship"
  done
}
v_of() { cat "$VW/$1/score.$2" 2>/dev/null; }
VDG() { git -C "$DIST" -c user.email=f@f -c user.name=fixture "$@" >/dev/null 2>&1; }

# --- build the worlds ---------------------------------------------------------------------
# V-M FIRST, because it is the only one that commits to the dist repo, and every other world's
# approved report is rendered afterwards against a settled tree.
VMREF="fixture-vm-theirs"
git -C "$DIST" checkout -q -B "$VMREF" "$THEIRS" 2>/dev/null
v_copy V-M && v_approve V-M "$VMREF" || bad "FIXTURE BROKEN — could not build world V-M"
v_resolve V-M
printf '#!/usr/bin/env bash\necho MOVED-REF-PROBE moved-under-the-decided-cause\n' > "$DIST/$MOVED_PROBE_PATH"
# WRAPPED FOR THE SAME REASON THE `DG` SITES ARE, and it was missed because the scan that
# established "0 unchecked" keyed on `DG` with a word boundary and this site is spelled `VDG`
# -- so the grammar scored its own subject as a non-instance and returned a clean zero. The
# V-M world has an independent `SP4` check downstream, which bounds the risk; it does not
# establish the claim, and the claim was what was wrong.
_pre_vm="$(git -C "$DIST" rev-parse "$VMREF" 2>/dev/null)"
DGW "staging the V-M post-resolution world" add -A || true
DGW "committing the V-M post-resolution world" commit -m "upstream core content moves after the blocker was resolved" || true
world_moved "the V-M post-resolution world" "$VMREF" "$_pre_vm" || true

# [producer-side, base-world] V-R keeps its REAL approval render: it is also the control that v_subst is faithful.
v_copy V-R && v_approve V-R "$THEIRS" || bad "FIXTURE BROKEN — could not build world V-R"
v_subst "$REGION" "$VW/V-R/consumer" > "$VW/V-R/region.sub"
if cmp -s "$VW/V-R/region.sub" "$VW/V-R/region.md" && [ -s "$VW/V-R/region.sub" ] && ! cmp -s "$REGION" "$VW/V-R/region.sub"; then
  ok "V-SUB the seed render with the consumer path replaced is byte-identical to a real approval render of a pristine copy at that path, and differs from the seed render (the path really is embedded), so the compare-side approvals derived from it are the producer's bytes"
else
  bad "FIXTURE BROKEN — the path-substituted seed render differs from V-R's real approval render (or the path is not embedded), so the compare-side approvals derived by substitution are not the producer's bytes"
fi
v_resolve V-R

# V-N: the same resolution PLUS an override whose base_sha resolves in neither repo, which
# layer-drift.sh renders as HARD-OVERRIDE-BASE-UNRESOLVABLE. A row the approval never saw is
# the state that must NEVER read as "the operator's own work", and it is the one property V-R
# lacks.
v_copy V-N && v_approve_sub V-N || bad "FIXTURE BROKEN — could not build world V-N"
v_resolve V-N
mkdir -p "$VW/V-N/consumer/.claude/skills/ai-dlc/overrides"
cat > "$VW/V-N/consumer/.claude/skills/ai-dlc/overrides/probe.md" <<'VNOVR'
---
shadows: core/rules/nonexistent.md#Nope
base_sha: deadbeefdeadbeefdeadbeefdeadbeefdeadbeef
reason: probe
---

## Nope

probe body
VNOVR

# V-B: a NON-HARD row resolved and nothing else. The ledger is written by this world and then
# rewritten with one entry removed, so the finding it resolves is seeded here and not inherited
# from an earlier arm's edits to the shared consumer.
v_copy V-B || bad "FIXTURE BROKEN — could not build world V-B"
mkdir -p "$VW/V-B/consumer/_bmad-output/ai-dlc-update"
cat > "$VW/V-B/consumer/_bmad-output/ai-dlc-update/push-candidate-ledger.md" <<'VBLED'
# Push-candidate ledger (fixture)

## PC-VB-KEEP — the verb is not one of the four

verify: theirs_maybe core/schemas/thing.json "rule"

## PC-VB-DROPPED — the verb is not one of the four

verify: theirs_maybe core/schemas/thing.json "keep"
VBLED
v_approve V-B "$THEIRS" || bad "FIXTURE BROKEN — could not render world V-B"
cat > "$VW/V-B/consumer/_bmad-output/ai-dlc-update/push-candidate-ledger.md" <<'VBLED2'
# Push-candidate ledger (fixture)

## PC-VB-KEEP — the verb is not one of the four

verify: theirs_maybe core/schemas/thing.json "rule"
VBLED2

v_copy V-H && v_approve_sub V-H || bad "FIXTURE BROKEN — could not build world V-H"
{ echo "# Reconcile report (fixture)"; echo; grep -v "$V_HARD" "$VW/V-H/region.md"; } > "$VW/V-H/approved.md"

v_copy V-HA && v_approve_sub V-HA || bad "FIXTURE BROKEN — could not build world V-HA"
{ echo "# Reconcile report (fixture)"; echo; grep -v "$V_HARD" "$VW/V-HA/region.md"; } > "$VW/V-HA/approved.md"
mkdir -p "$VW/V-HA/consumer/_bmad-output/ai-dlc-update"
printf 'adjudicated by hand\n' > "$VW/V-HA/consumer/_bmad-output/ai-dlc-update/blocker-adjudication-probe.md"

# V-S: the stamp line renders from the CONSUMER's stamp and moves when the CONSUMER re-stamps.
# Keyed into the refs comparison it made a re-stamped consumer read as "upstream moved" — both
# disjuncts of that message false — and pre-empted the resolved cause on a pull that had one. A
# stamp agreeing with the base renders no line at all, so this world's approved region has none.
v_copy V-S || bad "FIXTURE BROKEN — could not build world V-S"
printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$VW/V-S/consumer/.claude/.ai-dlc-version"
v_approve V-S "$THEIRS" || bad "FIXTURE BROKEN — could not render world V-S"
v_resolve V-S
printf 'version: 2.0.0\ncommit: %s\n' "$THEIRS" > "$VW/V-S/consumer/.claude/.ai-dlc-version"

# V-U: the resolution leaves a NON-HARD row the approval never saw. The override's `base_sha`
# RESOLVES, so it passes the provenance check V-N fails, and its `shadows:` target is absent at
# theirs — upstream restructured and the shadow points at nothing, which layer-drift.sh renders as
# OVERRIDE-ANCHOR-UNRESOLVED [LC-O8]: a real finding, not a HARD one. (c) still fires, because the
# HARD rule is the blocking contract; what must not happen is the count reporting zero.
#
# IT DIFFERS FROM V-N BY EXACTLY ONE PROPERTY, the base_sha, and that is deliberate: the two
# overrides are otherwise the same file, so the pair separates "a new HARD row" from "a new row"
# and nothing else varies with them.
v_copy V-U && v_approve_sub V-U || bad "FIXTURE BROKEN — could not build world V-U"
v_resolve V-U
mkdir -p "$VW/V-U/consumer/.claude/skills/ai-dlc/overrides"
cat > "$VW/V-U/consumer/.claude/skills/ai-dlc/overrides/absent-anchor.md" <<VUOVR
---
shadows: core/rules/nonexistent.md#Nope
base_sha: $BASE
reason: probe
---

## Nope

probe body
VUOVR

# V-D / V-DR: the blocker's own detector REFUSES at verify time. Its rows are simply absent, which
# is exactly the shape (c) keys on — so before DETECTOR-REFUSED reached the classifier a dead
# detector was diagnosed as a blocker the operator had resolved, BY NAME, over a drift still on
# disk. V-D leaves the drift UNRESOLVED; V-DR resolves it, and both must read the same, because
# the refusal is what blocks the cause and not the state of the file.
v_copy V-D && v_approve_sub V-D || bad "FIXTURE BROKEN — could not build world V-D"
v_copy V-DR && v_approve_sub V-DR || bad "FIXTURE BROKEN — could not build world V-DR"
v_resolve V-DR

# V-HC: THE HALF COPY. One blocker renders twice with different padding — `%-32s %s` in the
# blocking list and `STATUS  path` in its detector's section — and a difference taken over RAW
# lines reports the blocker GONE when only the padded copy is missing while the other still
# renders. The first HARD line in the region is the padded one, and only it is deleted here.
v_copy V-HC && v_approve_sub V-HC || bad "FIXTURE BROKEN — could not build world V-HC"
awk -v p="^$V_HARD" '$0 ~ p && !d { d=1; next } { print }' "$VW/V-HC/region.md" > "$VW/V-HC/region-half.md"
{ echo "# Reconcile report (fixture)"; echo; cat "$VW/V-HC/region-half.md"; } > "$VW/V-HC/approved.md"

# V-HB: hard-blockers.sh REFUSES, so the blocking list renders DETECTOR-REFUSED instead of the
# padded copies. It is the wrapper the whole HARD- contract keys on, and its call was the one
# detector pipeline with no exit-code check.
v_copy V-HB && v_approve_sub V-HB || bad "FIXTURE BROKEN — could not build world V-HB"

# --- THE ONE RENDER PER WORLD ----------------------------------------------------------------
# Every world is rendered ONCE, here, after all of them are built, and every compare-side program is
# scored against that file through the seam. V-D and V-DR are rendered by the dead-unregistered-drift
# copy and V-HB by the dead-hard-blockers copy, because the refusal is the world's subject. V-H and V-HC
# reuse their approval render (region.md): nothing touches either consumer or the dist after v_approve, so
# the fresh render is the approval render by construction.
V_DEAD_DRIFT="$(v_stub "$EMIT" "$VMD/probe-dead-drift" unregistered-drift.sh)"
V_DEAD_HB="$(v_stub "$EMIT" "$VMD/probe-dead-hb" hard-blockers.sh)"
v_fresh() { # v_fresh <world> <emit> <out> — ONE render; a foreign refusal in it is recorded, never retried
  local x="" sok=""
  [ -f "${2%/*}/.stubbed" ] && read -r sok < "${2%/*}/.stubbed"
  # RENDER: producer-side -- world $1's own consumer at its final state (one per world, shared by every compare-side program).
  v_render "$1" "$2" > "$3"
  x="$(v_foreign "$3" "" "$sok")"
  [ -n "$x" ] && printf '%s\n' "$x" > "$VW/$1/fresh.broken"
  return 0
}
_vf_n=0
for _vf_w in $V_WORLDS $V_CONTROL_WORLD; do
  case "$_vf_w" in
    V-H|V-HC) cp "$VW/$_vf_w/region.md" "$VW/$_vf_w/fresh.ship.md"; continue ;;
    # [compare-side] V-HA: the pristine consumer plus a blocker-adjudication file. The question it asks is what er_compare
    # does with a consumer holding such a file, so the fresh region is the seed render at its path.
    V-HA) v_subst "$REGION" "$VW/V-HA/consumer" > "$VW/V-HA/fresh.ship.md"; continue ;;
    V-D|V-DR) _vf_p="$V_DEAD_DRIFT" ;;
    V-HB) _vf_p="$V_DEAD_HB" ;;
    *) _vf_p="$EMIT" ;;
  esac
  ( v_fresh "$_vf_w" "$_vf_p" "$VW/$_vf_w/fresh.ship.md" ) &
  _vf_n=$((_vf_n+1)); if [ "$_vf_n" -ge 4 ]; then wait; _vf_n=0; fi
done
wait
for _vf_w in $V_WORLDS $V_CONTROL_WORLD; do
  [ -f "$VW/$_vf_w/fresh.broken" ] && bad "FIXTURE BROKEN — $_vf_w's one render carried a refusal the seed world does not: $(cat "$VW/$_vf_w/fresh.broken")"
done

# --- SELF-PROBES, BEFORE ANY VERDICT IS READ ------------------------------------------------
# Every arm below is a differential between an approved region and a fresh render. Both sides
# reading the same rows establishes nothing, so each world's two sides are proved to differ
# FIRST, and each probe carries a positive conjunct so a render that emitted nothing cannot
# satisfy it.
V_BASE_BYTES="$WORK/vp-base-thing.json"
git -C "$DIST" show "${BASE}:core/schemas/thing.json" > "$V_BASE_BYTES" 2>/dev/null
if [ ! -s "$V_BASE_BYTES" ]; then
  bad "FIXTURE BROKEN — base bytes for core/schemas/thing.json did not resolve; the resolution below writes an empty file and every V-arm is meaningless"
elif cmp -s "$V_BASE_BYTES" "$CONSUMER/.claude/schemas/thing.json"; then
  bad "FIXTURE BROKEN — the seeded consumer ALREADY carries the base bytes, so the resolution changes nothing and V-R's exit 3 would be decided by something else"
else
  ok "SP1 the seeded consumer's schema and the base bytes DIFFER, so reverting one to the other is a real resolution (control for every V-arm)"
fi

V_R_AFTER="$VW/V-R/fresh.ship.md"
if ! grep -q "$V_HARD" "$VW/V-R/region.md"; then
  bad "FIXTURE BROKEN — V-R's APPROVED region carries no $V_HARD row, so there is no blocker for the resolution to remove"
elif ! grep -qF "$V_BASELINE" "$V_R_AFTER"; then
  bad "FIXTURE BROKEN — the render AFTER the resolution carries no baseline bucket row, so it is an empty or dead render and its missing HARD row proves nothing"
elif grep -q "$V_HARD" "$V_R_AFTER"; then
  bad "FIXTURE BROKEN — the resolution did NOT remove the $V_HARD row from a fresh render, so V-R is not the state it claims to be"
else
  ok "SP2 V-R's two sides differ in the way the arm needs: the approved region carries $V_HARD, the post-resolution render still carries the baseline bucket row and no longer carries the blocker"
fi

V_N_AFTER="$VW/V-N/fresh.ship.md"
if grep -q 'HARD-OVERRIDE-BASE-UNRESOLVABLE' "$VW/V-N/region.md"; then
  bad "FIXTURE BROKEN — V-N's APPROVED region already carries HARD-OVERRIDE-BASE-UNRESOLVABLE, so the row is not NEW and V-N is a copy of V-R"
elif ! grep -q 'HARD-OVERRIDE-BASE-UNRESOLVABLE' "$V_N_AFTER"; then
  bad "FIXTURE BROKEN — the probe override rendered no HARD-OVERRIDE-BASE-UNRESOLVABLE row, so V-N carries no new blocker and cannot discriminate the hard_new conjunct"
elif grep -q "$V_HARD" "$V_N_AFTER"; then
  bad "FIXTURE BROKEN — V-N's post-resolution render still carries $V_HARD, so it is not testing 'resolved AND a new row', only 'a new row'"
else
  ok "SP3 V-N's fresh render carries a HARD row the approved region LACKS (HARD-OVERRIDE-BASE-UNRESOLVABLE) while the approved region's blocker is gone — both properties, which is what makes it the discriminating seed"
fi

v_moved_to="$(git -C "$DIST" rev-parse "$VMREF" 2>/dev/null)"
v_tree_moved="$(git -C "$DIST" rev-parse "${VMREF}:core" 2>/dev/null)"
v_tree_appr="$(git -C "$DIST" rev-parse "${THEIRS}:core" 2>/dev/null)"
if [ "$v_moved_to" = "$THEIRS" ]; then
  bad "FIXTURE BROKEN — $VMREF did not move, so V-M's refs are identical and it is a second copy of V-R"
elif [ -z "$v_tree_moved" ] || [ "$v_tree_moved" = "$v_tree_appr" ]; then
  bad "FIXTURE BROKEN — $VMREF moved without changing the core/ tree, so the refs lines still agree and V-M cannot reach UPSTREAM-MOVED"
else
  ok "SP4 V-M's ref moved AND its core/ tree changed, so its refs lines genuinely differ from the approved region's (derived from git, not assumed)"
fi

V_B_AFTER="$VW/V-B/fresh.ship.md"
v_b_hard_appr="$(grep -c '^HARD-' "$VW/V-B/region.md")" || v_b_hard_appr=0
v_b_hard_after="$(grep -c '^HARD-' "$V_B_AFTER")" || v_b_hard_after=0
if ! grep -q 'PC-VB-DROPPED' "$VW/V-B/region.md"; then
  bad "FIXTURE BROKEN — V-B's approved region carries no PC-VB-DROPPED row, so the ledger entry it removes was never rendered and V-B resolves nothing"
elif grep -q 'PC-VB-DROPPED' "$V_B_AFTER"; then
  bad "FIXTURE BROKEN — removing the ledger entry did not remove its row from a fresh render, so V-B's two sides do not differ"
elif [ "$v_b_hard_appr" -eq 0 ] || [ "$v_b_hard_appr" -ne "$v_b_hard_after" ]; then
  bad "FIXTURE BROKEN — V-B moved a HARD row too ($v_b_hard_appr approved vs $v_b_hard_after rendered), so it is not a NON-HARD resolution and it cannot discriminate the HARD- keying"
else
  ok "SP5 V-B resolves a NON-HARD row only: the PC-VB-DROPPED row leaves the render while all $v_b_hard_appr HARD rows stay put"
fi

if grep -q '^_stamp_ ' "$VW/V-S/region.md"; then
  bad "FIXTURE BROKEN — V-S's APPROVED region already carries a _stamp_ line, so moving the stamp changes nothing and V-S is a second copy of V-R"
else
  V_S_AFTER="$VW/V-S/fresh.ship.md"
  if ! grep -q '^_stamp_ ' "$V_S_AFTER"; then
    bad "FIXTURE BROKEN — moving the consumer's stamp rendered no _stamp_ line, so V-S's two sides do not differ on the stamp at all"
  elif grep -q "$V_HARD" "$V_S_AFTER"; then
    bad "FIXTURE BROKEN — V-S's post-move render still carries $V_HARD, so it is not testing 'resolved AND the stamp moved'"
  else
    ok "SP6 V-S's stamp move adds a _stamp_ line the approved region lacks AND its blocker is resolved — both, which is what makes the stamp's exclusion from the refs comparison observable"
  fi
fi

V_U_AFTER="$VW/V-U/fresh.ship.md"
v_u_hard_after="$(grep -c '^HARD-' "$V_U_AFTER")" || v_u_hard_after=0
if grep -q 'OVERRIDE-ANCHOR-UNRESOLVED' "$VW/V-U/region.md"; then
  bad "FIXTURE BROKEN — V-U's APPROVED region already carries OVERRIDE-ANCHOR-UNRESOLVED, so the row is not unseen and V-U is a copy of V-R"
elif ! grep -q 'OVERRIDE-ANCHOR-UNRESOLVED' "$V_U_AFTER"; then
  bad "FIXTURE BROKEN — the absent-anchor override rendered no OVERRIDE-ANCHOR-UNRESOLVED row, so V-U carries no unseen finding and cannot discriminate the unseen count"
elif grep -q 'HARD-OVERRIDE-BASE' "$V_U_AFTER"; then
  bad "FIXTURE BROKEN — V-U's override was rejected on its base_sha before the anchor was ever resolved, so it is a second copy of V-N and proves nothing about a NON-HARD unseen row"
elif [ "$v_u_hard_after" -ne 0 ]; then
  bad "FIXTURE BROKEN — V-U's post-resolution render carries $v_u_hard_after HARD row(s), so it would be decided by the HARD conjunct rather than by the unseen count"
else
  ok "SP7 V-U's fresh render carries a NON-HARD row the approved region lacks (OVERRIDE-ANCHOR-UNRESOLVED) and no HARD row at all — the count, not the verdict, is what it discriminates"
fi

V_D_AFTER="$VW/V-D/fresh.ship.md"
V_D_ALIVE="$WORK/vp-vd-alive.md"
# [compare-side] V-D under the live detector -- the control that the stub, not the world, produced the refusal.
# V-D's consumer is the pristine seed consumer at its own path, so the live render of it is the seed render with that
# path replaced (V-SUB proves the substitution equals a real render); the stubbed render stays a real one below.
v_subst "$REGION" "$VW/V-D/consumer" > "$V_D_ALIVE"
if cmp -s "$V_BASE_BYTES" "$VW/V-D/consumer/.claude/schemas/thing.json"; then
  bad "FIXTURE BROKEN — V-D's drift was resolved on disk, so its missing HARD row is a resolution and not a refusal, and it cannot discriminate the DETECTOR-REFUSED conjunct"
elif ! grep -qF 'DETECTOR-REFUSED  unregistered-drift.sh' "$V_D_AFTER"; then
  bad "FIXTURE BROKEN — the stubbed detector rendered no 'DETECTOR-REFUSED  unregistered-drift.sh' line, so V-D's fresh render is not the state it claims and the arm below cannot fire"
elif grep -qF 'DETECTOR-REFUSED  unregistered-drift.sh' "$V_D_ALIVE"; then
  bad "FIXTURE BROKEN — the live-detector render also carries DETECTOR-REFUSED for that detector, so the two sides do not differ and the stub is not what produced the line"
elif ! grep -q "$V_HARD" "$V_D_ALIVE"; then
  bad "FIXTURE BROKEN — the live-detector render of V-D's consumer carries no $V_HARD row, so the drift the refusal hides was never rendered and there is nothing for the refusal to conceal"
else
  ok "SP8 V-D's drift is STILL ON DISK and still renders as $V_HARD under a live detector, while the stubbed copy renders DETECTOR-REFUSED and no HARD row — the two sides differ, and they differ by the stub"
fi

# SP9: the half copy. The row must be REMOVED from the report, the SURVIVING copy must still be
# there, and the two must be the same row once whitespace is collapsed — otherwise V-HC is not a
# padding difference at all and the arm would be testing something else.
v_hc_appr="$(grep -c "^$V_HARD" "$VW/V-HC/region-half.md")" || v_hc_appr=0
v_hc_full="$(grep -c "^$V_HARD" "$VW/V-HC/region.md")" || v_hc_full=0
v_hc_a="$(grep -m1 "^$V_HARD" "$VW/V-HC/region-half.md" | sed -E 's/[[:space:]]+/ /g')"
v_hc_b="$(grep -m1 "^$V_HARD" "$VW/V-HC/region.md" | sed -E 's/[[:space:]]+/ /g')"
if [ "$v_hc_full" -ne 2 ]; then
  bad "FIXTURE BROKEN — the region renders $v_hc_full copies of $V_HARD, not 2, so 'delete one copy' is not the state V-HC claims to build"
elif [ "$v_hc_appr" -ne 1 ]; then
  bad "FIXTURE BROKEN — V-HC's report carries $v_hc_appr copies of $V_HARD after the cut, not 1: either nothing was deleted or both copies were"
elif [ "$v_hc_a" != "$v_hc_b" ]; then
  bad "FIXTURE BROKEN — the deleted copy and the surviving copy are DIFFERENT rows once whitespace is collapsed ('$v_hc_b' vs '$v_hc_a'), so V-HC is not a padding difference"
else
  ok "SP9 V-HC deletes one of the region's two copies of the blocker and leaves the other, and the two are the same row once whitespace is collapsed — a padding difference and nothing else"
fi

# SP10: the refusing WRAPPER. The blocking list must go, the detector-section copy must stay —
# that surviving copy is precisely why normalisation alone already prevents the misread.
V_HB_AFTER="$VW/V-HB/fresh.ship.md"
v_hb_hard="$(grep -c "^$V_HARD" "$V_HB_AFTER")" || v_hb_hard=0
if cmp -s "$V_BASE_BYTES" "$VW/V-HB/consumer/.claude/schemas/thing.json"; then
  bad "FIXTURE BROKEN — V-HB's drift was resolved on disk, so its blocking list would be empty anyway and the refusal is not what the arm reads"
elif ! grep -qF 'DETECTOR-REFUSED  hard-blockers.sh' "$V_HB_AFTER"; then
  bad "FIXTURE BROKEN — the stubbed wrapper rendered no 'DETECTOR-REFUSED  hard-blockers.sh' line, so V-HB's fresh render is not the state it claims"
elif [ "$v_hb_hard" -ne 1 ]; then
  bad "FIXTURE BROKEN — V-HB's render carries $v_hb_hard copy(ies) of $V_HARD, not the 1 the detector's own section renders; the wrapper's refusal is not what removed the padded copy"
else
  ok "SP10 V-HB's wrapper refuses, the padded blocking-list copy of the blocker is gone and the detector section's copy remains — which is the state where the padded copy alone looked resolved"
fi

# --- SCORE EVERY WORLD UNDER THE SHIPPED PROGRAM ----------------------------------------------
v_sig
v_score "$V_DEAD_DRIFT" "$V_CONTROL_WORLD" ship "$VW/$V_CONTROL_WORLD/fresh.ship.md" > "$VW/$V_CONTROL_WORLD/score.ship"
# The foreground half of R6's scoring guard: a cell whose one fresh render carried a foreign refusal.
v_broken_scan() {
  local n t b
  for n in $V_WORLDS $V_CONTROL_WORLD; do
    for t in ship; do
      b="$VW/$n/broken.$t"
      [ -f "$b" ] && bad "FIXTURE BROKEN — $n scoring under $t rendered a refusal the seed world does not: $(cat "$b")"
    done
  done
  return 0
}
v_broken_scan

# --- THE CORPUS ARMS ------------------------------------------------------------------------
v_vr="$(v_of V-R ship)"
if [ "$v_vr" = "3|BLOCKERS-RESOLVED|1|1|0|0" ] && grep -q "resolved: $V_HARD" "$VW/V-R/stderr.ship"; then
  ok "V-R a blocker RESOLVED after the render exits 3 with cause BLOCKERS-RESOLVED, names the row it decided from, counts ONE blocker although the region renders it twice, and counts ZERO unseen rows"
else
  bad "V-R the resolved-blocker case scored $v_vr (want 3|BLOCKERS-RESOLVED|1|1|0|0) — either the cause is not decided, or the blocker count is a LINE count rather than a blocker count, or the unseen count is counting the boilerplate a plain resolution moves into the diff, which makes it useless for telling that resolution from one hiding a finding"
fi

v_vn="$(v_of V-N ship)"
case "$v_vn" in
  "1|UNDECIDED|"*) ok "V-N a NEW HARD row beside the resolved one is NOT read as the operator's own work — exit 1, cause UNDECIDED" ;;
  *) bad "V-N scored $v_vn (want 1|UNDECIDED|...) — a finding the approval never saw is being diagnosed as BLOCKERS-RESOLVED, which is the acquitting direction and the one this cause must never take" ;;
esac

v_vm="$(v_of V-M ship)"
case "$v_vm" in
  "1|UPSTREAM-MOVED|"*) ok "V-M upstream moving across a core change is decided BEFORE the resolved-blocker case — exit 1, cause UPSTREAM-MOVED" ;;
  *) bad "V-M scored $v_vm (want 1|UPSTREAM-MOVED|...) — a moved range makes every other line incomparable, so a region diffed against a different upstream must never be diagnosed from its HARD rows" ;;
esac

v_vb="$(v_of V-B ship)"
case "$v_vb" in
  "1|UNDECIDED|"*) ok "V-B a NON-HARD row that stopped rendering is not a resolved blocker — exit 1, cause UNDECIDED" ;;
  *) bad "V-B scored $v_vb (want 1|UNDECIDED|...) — the cause is keyed on 'something left the region' rather than on the HARD- prefix SKILL.md binds" ;;
esac

v_vh="$(v_of V-H ship)"
case "$v_vh" in
  "1|UNDECIDED|"*) ok "V-H a blocker HAND-DROPPED from the region still exits 1 with cause UNDECIDED — the unsafe direction cannot borrow the safe one's diagnosis" ;;
  *) bad "V-H scored $v_vh (want 1|UNDECIDED|...) — a region edited to hide a finding the detectors still render is being reported as the adjudication loop's own work" ;;
esac

v_vha="$(v_of V-HA ship)"
case "$v_vha" in
  "1|UNDECIDED|"*) ok "V-HA a blocker-adjudication file in the consumer does not turn a hand-dropped row into a resolved one — the cause is decided from the ROWS" ;;
  *) bad "V-HA scored $v_vha (want 1|UNDECIDED|...) — the diagnosis is reading a file the consumer can create rather than the two regions, so an operator writing an adjudication note acquits a dropped finding" ;;
esac

# THE STAMP IS ITS OWN CAUSE, and the arm reads all three of its outputs. Folded in with
# `_base_`/`_theirs_` it made a re-stamped consumer read as UPSTREAM-MOVED, whose two disjuncts
# are both false; dropped from the key entirely it made a post-apply re-run — stamp legitimately
# at theirs — read as blockers RESOLVED and be told to re-approve and apply a range already
# applied. So the verdict, the cause word, and the HARD counts the cause line carries beside the
# stamp are all in the cell, and the changed line must still reach the operator in the diff.
v_vs="$(v_of V-S ship)"
if [ "$v_vs" = "1|STAMP-MOVED|0|0|1|0" ] && grep -qE '^[<>] _stamp_ records ' "$VW/V-S/stderr.ship"; then
  ok "V-S a moved CONSUMER stamp is neither upstream moving nor a resolved blocker: it is decided on its own line, exit 1 with cause STAMP-MOVED, the blocker it also resolved is still counted beside it, and the changed line reaches the operator in the forwarded diff"
else
  bad "V-S scored $v_vs (want 1|STAMP-MOVED|0|0|1|0 with the _stamp_ line in the diff) — a stamp folded into the base/theirs key reads as UPSTREAM-MOVED with both disjuncts false, and a stamp left out of every key reads as BLOCKERS-RESOLVED on a post-apply re-run, which tells the operator to re-approve and apply a range this tree already carries"
fi
fi # end rer_phase vworlds1

# --- SB: THE STAMP'S `commit:` IS COMPARED TO BASE AS A COMMIT, NEVER AS A STRING -------------
#
# THE DEFECT. Both stamp writers (apply.sh's re-stamp, install.sh) record `rev-parse --short`,
# and the `_stamp_ records ... NOT the base above` line compared that field to BASE as strings,
# so every real consumer report carried a false row. V-S above stays the control on the --verify
# side: its cell must not move. These worlds own the RENDER side, and they live in their OWN
# three-commit dist, because the seeded DIST is shared by every V-world and V-M commits to it.
#
#   b ── t ── dc       b tagged `sb-vb` (ANNOTATED); dc touches docs/ only, so dc:core == t:core
#
#   case      stamp            BASE     want
#   SHORT     short(b)         b        none
#   FULL-SB   b                short(b) none
#   UPPER     SHORT(B) upper   b        none
#   TAG       short(b)         sb-vb    none
#   DOCS      t                dc       row
#   DIRTY     short(b)-dirty   b        row
#   OTHER     short(t)         b        row    CONTROL: the row renders at all
#   EQUAL     b                b        none   CONTROL: string-equal is settled without git
#   NOBASE    short(b)         nb       row
#
# nb is a 40-hex sha no object in the SB dist carries, asserted absent before any cell is read.
#
# EVERY CELL MUST PROVE IT RENDERED. A program that emits nothing reads `none` on five of the
# nine cases, so a cell whose reconcile-mechanical region is absent or TRUNCATED -- BEGIN with no
# END -- is BROKEN, never `none`. Cells are
# computed in background jobs that write files; every verdict is read in the foreground.
if rer_phase sb; then
SB="$WORK/stamp-base"; mkdir -p "$SB/d/core" "$SB/c"
sbg() { git -C "$SB/d" -c user.name=fixture -c user.email=f@f -c commit.gpgsign=false -c tag.gpgsign=false "$@"; }
SB_OK=1
{ sbg init -q && printf '1\n' > "$SB/d/core/a.md" && printf '1.0.0\n' > "$SB/d/VERSION" \
  && sbg add -A && sbg commit -q -m sb-base && sbg tag -a -m sb-tag sb-vb \
  && printf '2\n' > "$SB/d/core/a.md" && sbg add -A && sbg commit -q -m sb-theirs \
  && mkdir -p "$SB/d/docs" && printf 'n\n' > "$SB/d/docs/n.md" && sbg add -A && sbg commit -q -m sb-docs-only; } >/dev/null 2>&1 || SB_OK=0
SB_B="$(sbg rev-parse -q --verify 'HEAD~2^{commit}' 2>/dev/null)" || SB_B=""
SB_T="$(sbg rev-parse -q --verify 'HEAD~1^{commit}' 2>/dev/null)" || SB_T=""
SB_DC="$(sbg rev-parse -q --verify 'HEAD^{commit}' 2>/dev/null)" || SB_DC=""
SB_TS="$(sbg rev-parse --short "$SB_T" 2>/dev/null)" || SB_TS=""
# The upper-case case needs a hex LETTER in the abbreviation: a 7-char all-digit prefix (about
# one commit in 27) upper-cases to itself and the case collapses into SHORT. Lengthen until it has one.
SB_BS=""; _sb_n=7
while [ "$_sb_n" -le 40 ]; do
  SB_BS="$(sbg rev-parse --short="$_sb_n" "$SB_B" 2>/dev/null)" || SB_BS=""
  case "$SB_BS" in *[abcdef]*) break ;; esac
  _sb_n=$((_sb_n+1))
done
SB_BU="$(printf '%s' "$SB_BS" | tr abcdef ABCDEF)"
SB_NB=0123456789abcdef0123456789abcdef01234567
sb_rp() { sbg rev-parse -q --verify "$1" 2>/dev/null || true; }

# PRECONDITIONS: each is what makes one case discriminate, so each is asserted before a cell is read.
SB_PRE=""
[ "$SB_OK" = 1 ] && [ -n "$SB_B" ] && [ -n "$SB_T" ] && [ -n "$SB_DC" ] || SB_PRE="$SB_PRE the three-commit dist did not build;"
case "$SB_B" in "$SB_BS"?*) : ;; *) SB_PRE="$SB_PRE short(b) [$SB_BS] is not a strict prefix of b;" ;; esac
[ "$SB_BU" != "$SB_BS" ] && [ "$(sb_rp "${SB_BU}^{commit}")" = "$SB_B" ] || SB_PRE="$SB_PRE the upper-case abbreviation [$SB_BU] is not distinct from [$SB_BS] or does not resolve to b in this git;"
[ "$(sb_rp sb-vb)" != "$SB_B" ] && [ "$(sb_rp 'sb-vb^{commit}')" = "$SB_B" ] || SB_PRE="$SB_PRE sb-vb is not an annotated tag peeling to b;"
[ "$SB_DC" != "$SB_T" ] && [ -n "$(sb_rp "${SB_T}:core")" ] && [ "$(sb_rp "${SB_DC}:core")" = "$(sb_rp "${SB_T}:core")" ] || SB_PRE="$SB_PRE dc does not share t's core/ tree as a different commit;"
[ -z "$(sb_rp "${SB_BS}-dirty^{commit}")" ] && [ -n "$(sb_rp "${SB_BS}^{commit}")" ] || SB_PRE="$SB_PRE [${SB_BS}-dirty] resolves (or [$SB_BS] does not), so DIRTY is not an unresolvable stamp;"
[ -z "$(sb_rp "${SB_NB}^{commit}")" ] || SB_PRE="$SB_PRE nb [$SB_NB] resolves in the SB dist, so NOBASE is not an unresolvable BASE;"
if [ -n "$SB_PRE" ]; then
  bad "FIXTURE BROKEN — SB world:$SB_PRE no SB cell below can discriminate"
else
  ok "SBP the SB dist expresses every case: short(b) is a strict prefix of b, its upper-case form is distinct and resolves to b, sb-vb is an annotated tag peeling to b, dc and t are different commits with one core/ tree, short(b)-dirty does not resolve while short(b) does, and nb resolves to nothing"
fi

SB_CASES="SHORT FULL-SB UPPER TAG DOCS DIRTY OTHER EQUAL NOBASE"
sb_stamp() { case "$1" in SHORT|TAG|NOBASE) printf '%s' "$SB_BS" ;; FULL-SB|EQUAL) printf '%s' "$SB_B" ;; UPPER) printf '%s' "$SB_BU" ;; DOCS) printf '%s' "$SB_T" ;; DIRTY) printf '%s-dirty' "$SB_BS" ;; OTHER) printf '%s' "$SB_TS" ;; esac; }
sb_base()  { case "$1" in FULL-SB) printf '%s' "$SB_BS" ;; TAG) printf 'sb-vb' ;; DOCS) printf '%s' "$SB_DC" ;; NOBASE) printf '%s' "$SB_NB" ;; *) printf '%s' "$SB_B" ;; esac; }
sb_want()  { case "$1" in DOCS|DIRTY|OTHER|NOBASE) printf 'row' ;; *) printf 'none' ;; esac; }
sb_cell() { # sb_cell <emit> <case> <tag> -> row | none | BROKEN
  local d="$SB/c/$3.$2" o
  mkdir -p "$d/.claude" || { echo BROKEN; return 0; }
  printf 'version: 1.0.0\ncommit: %s\n' "$(sb_stamp "$2")" > "$d/.claude/.ai-dlc-version"
  o="$(bash "$1" "$SB/d" "$(sb_base "$2")" "$d" "$SB_T" 2>/dev/null)"
  case "$o" in *'BEGIN GENERATED: reconcile-mechanical'*) : ;; *) echo BROKEN; return 0 ;; esac
  case "$o" in *'END GENERATED: reconcile-mechanical'*) : ;; *) echo BROKEN; return 0 ;; esac
  case "$o" in *"_stamp_ records"*) echo row ;; *) echo none ;; esac
}
sb_of() { cat "$SB/cell.$2.$1" 2>/dev/null; }

if [ -z "$SB_PRE" ]; then
  # EVERY RENDER HERE IS A PRODUCER-SIDE CASE (the stamp and BASE are inputs to what render() emits), tagged
  # [conflicting-state]: one render per case, computed in background jobs that write files.
  sb_job() { sb_cell "$EMIT" "$1" ship > "$SB/cell.ship.$1"; } # RENDER: producer-side SB case (see the tag above)
  _sb_n=0
  for _sb_c in $SB_CASES; do
    ( sb_job "$_sb_c" ) &
    _sb_n=$((_sb_n+1)); if [ "$_sb_n" -ge 6 ]; then wait; _sb_n=0; fi
  done
  wait
  for _sb_c in $SB_CASES; do
    _sb_got="$(sb_of "$_sb_c" ship)"; _sb_w="$(sb_want "$_sb_c")"
    if [ "$_sb_got" = "$_sb_w" ]; then
      ok "SB-$_sb_c stamp [$(sb_stamp "$_sb_c")] against BASE [$(sb_base "$_sb_c")] renders $_sb_w — the stamp is compared to the base as a commit"
    else
      bad "SB-$_sb_c stamp [$(sb_stamp "$_sb_c")] against BASE [$(sb_base "$_sb_c")] rendered [${_sb_got:-nothing}], want $_sb_w — a false _stamp_ row tells the operator to re-derive a base that is right, and a missing one hides a consumer whose recorded position is not the range being rendered"
    fi
  done
fi
fi # end rer_phase sb

if rer_phase vworlds2; then
v_vu="$(v_of V-U ship)"
if [ "$v_vu" = "3|BLOCKERS-RESOLVED|1|1|1|1" ] && grep -q '^    unseen: OVERRIDE-ANCHOR-UNRESOLVED' "$VW/V-U/stderr.ship"; then
  ok "V-U a resolution that leaves a NON-HARD row the approval never saw still refuses, and the row is COUNTED and NAMED rather than asserted away — one, against V-R's zero on the same verdict"
else
  bad "V-U scored $v_vu (want 3|BLOCKERS-RESOLVED|1|1|1|1 with OVERRIDE-ANCHOR-UNRESOLVED listed as unseen) — the message tells the operator no finding is hidden from the approval while one is, and the count cannot tell a plain resolution from a resolution carrying a row"
fi

v_vd="$(v_of V-D ship)"
if [ "$v_vd" = "1|UNDECIDED|0|0|1|0" ] && grep -q '1 DETECTOR-REFUSED line(s)' "$VW/V-D/stderr.ship"; then
  ok "V-D a detector that REFUSED is not a blocker resolved: its rows are absent with nobody to vouch for them, so the cause stays UNDECIDED and the message counts the refusal"
else
  bad "V-D scored $v_vd (want 1|UNDECIDED|0|0|1|0 naming 1 DETECTOR-REFUSED line) — a dead detector is being diagnosed as the operator's own resolution, BY NAME, over a drift still on disk, and the remedy it offers is a re-render that would bake that absence into an approved report"
fi

v_vdr="$(v_of "$V_CONTROL_WORLD" ship)"
if [ "$v_vdr" = "$v_vd" ]; then
  ok "V-DR CONTROL the same dead-detector copy reaches the same verdict with the drift RESOLVED on disk — the refusal is what blocks the cause, not the state of the file, so V-D is not passing because of what its consumer happens to hold"
else
  bad "V-DR CONTROL the dead-detector verdict changed with the drift resolved (unresolved: $v_vd / resolved: $v_vdr) — V-D is being decided by its consumer's contents rather than by the refusal, so it does not test the DETECTOR-REFUSED conjunct"
fi

v_vhc="$(v_of V-HC ship)"
if [ "$v_vhc" = "1|UNDECIDED|0|0|0|0" ]; then
  ok "V-HC a blocker whose padded copy is missing from the report while its detector-section copy still renders is NOTHING gone and NOTHING new — normalised before the difference, the two sides carry the same row and both counts are zero"
else
  bad "V-HC scored $v_vhc (want 1|UNDECIDED|0|0|0|0) — the difference is being taken over RAW lines, so one blocker rendered twice with different padding is scored as a row that moved, and a still-rendered blocker cannot be told from a resolved one"
fi

v_vhb="$(v_of V-HB ship)"
if [ "$v_vhb" = "1|UNDECIDED|0|0|1|0" ] && grep -q '1 DETECTOR-REFUSED line(s)' "$VW/V-HB/stderr.ship"; then
  ok "V-HB the WRAPPER the HARD- contract keys on gets the same refusal treatment as the detectors it drives: an empty blocking list from a wrapper that did not run is not '0 HARD blockers.'"
else
  bad "V-HB scored $v_vhb (want 1|UNDECIDED|0|0|1|0 naming 1 DETECTOR-REFUSED line) — hard-blockers.sh exiting non-zero renders an empty blocking list that reads as a clean one, on the single line the whole HARD- contract is keyed to"
fi
fi # end rer_phase vworlds2

# --- B1/B2: emit-report HANDS unregistered-drift.sh the preclassify rows it already paid for ---
#
# The render computes `pc` once and then drove `unregistered-drift.sh` with no `--bucket-rows`,
# so that scan's carried-bucket arm re-derived the identical rows in a second process. Measured
# on this fixture's own seeded tree, 5 interleaved reps with the outputs byte-compared every rep:
# 789-949ms without the flag against 610-723ms with it, disjoint ranges.
#
# THE EQUIVALENCE IS ALREADY OWNED ELSEWHERE AND IS NOT RESTATED HERE.
# `apply-drift-after-write/run.sh:430` asserts the flagged and standalone scans agree row-for-row,
# and `:442` asserts an EMPTY rows file does not acquit. What NOTHING asserted is that THIS
# renderer passes the flag at all — apply.sh has passed it since the flag existed and emit-report
# never did, which is precisely the state that made this a live cost rather than a fixed one.
#
# B1 IS KEYED ON THE EMISSION SITE, NOT ON THE FILE. A whole-file `grep -qF -- --bucket-rows` is
# satisfied by the header comment above the call and by this comment block; the binding has to be
# the line that EXECUTES the scan. The control below is the same grammar against an argument no
# call site carries, and it must read 0 or the count beside it means nothing.
if rer_phase b1b2; then
B1_HIT="$(grep -cE '^[[:space:]]*bash "\$SELF/unregistered-drift\.sh" --bucket-rows ' "$EMIT")" || B1_HIT=0
B1_CTL="$(grep -cE '^[[:space:]]*bash "\$SELF/unregistered-drift\.sh" --qqq-absent-rows ' "$EMIT")" || B1_CTL=0
if [ "$B1_CTL" -ne 0 ]; then
  bad "B1 CONTROL the impossible-flag grammar matched $B1_CTL executing lines, so B1's count establishes nothing"
elif [ "$B1_HIT" -ge 1 ]; then
  ok "B1 the renderer drives unregistered-drift.sh with --bucket-rows at an EXECUTING line ($B1_HIT), not merely in prose — the rows this render already computed are handed down instead of re-derived (control: the same grammar with an impossible flag reads 0)"
else
  bad "B1 no executing line passes --bucket-rows to unregistered-drift.sh; the render re-derives preclassify in a second process, which measured 789-949ms against 610-723ms on this tree"
fi

# B2 IS THE ARM THAT MAKES B1 MEAN SOMETHING: the flag must not change the RENDERED REGION.
# B1 alone passes on a renderer that hands down the wrong rows. This re-runs the shipped scan
# both ways against the tree this fixture seeded and byte-compares, with a non-empty control —
# two empty outputs compare equal and would pass without it.
B2_PC="$WORK/b2-pc-rows"
bash "$(dirname "$EMIT")/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" > "$B2_PC" 2>/dev/null
B2_N="$(bash "$(dirname "$EMIT")/unregistered-drift.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
B2_F="$(bash "$(dirname "$EMIT")/unregistered-drift.sh" --bucket-rows "$B2_PC" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"
if [ "$(printf '%s\n' "$B2_N" | grep -c .)" -eq 0 ]; then
  bad "B2 CONTROL the standalone scan produced NO rows on this fixture's tree, so the comparison below is two empty sets and cannot discriminate"
elif [ "$B2_F" = "$B2_N" ]; then
  ok "B2 the flag changes who PAID and not what is answered: flagged and standalone scans agree row-for-row on this fixture's own tree, with the row set asserted non-empty first"
else
  # The two sides are STAGED and diff's status read: a `<( )` pair here lost diff's exit, so a diff
  # that could not compare printed an empty sample beside the verdict, reading as "no difference".
  b2_rc=0
  { printf '%s\n' "$B2_N" > "$WORK/b2-standalone.rows" && printf '%s\n' "$B2_F" > "$WORK/b2-flagged.rows"; } || b2_rc=staging-failed
  if [ "$b2_rc" = 0 ]; then
    diff "$WORK/b2-standalone.rows" "$WORK/b2-flagged.rows" > "$WORK/b2.diff" 2>&1 || b2_rc=$?
  fi
  case "$b2_rc" in
    0|1) b2_why="$(head -4 "$WORK/b2.diff" | tr '\n' '|')" ;;
    *)   b2_why="(the two row sets could not be diffed: $b2_rc — the disagreement above is decided, its lines are not shown)" ;;
  esac
  bad "B2 the flagged and standalone scans DISAGREE, so the rendered region depends on which caller ran the scan: $b2_why"
fi
fi # end rer_phase b1b2

# S-MK: EVERY --region-from CALL THIS SHARD MADE PRINTED THE ENGINE'S MARKER, so no seam result can be read as a
# gate result. The control: the log must hold at least one MARK line, or a seam() that logged nothing would pass.
_smk_n="$(grep -c '^MARK ' "$WORK/seam.log")" || _smk_n=0
_smk_bad="$(grep '^NOMARK ' "$WORK/seam.log" | head -3 | tr '\n' ' ')"
if [ "$_smk_n" -lt 1 ]; then bad "S-MK the seam log holds no MARK line, so the marker check read nothing"
elif [ -n "$_smk_bad" ]; then bad "S-MK a --region-from call printed no marker line: $_smk_bad"
else ok "S-MK all $_smk_n --region-from calls this shard made printed the marker line first"; fi

# J1: the SET of phases entered equals this shard's list AS DECLARED IN THIS FILE'S TEXT, and no
# phase dealt to another shard was entered. A count off the loop variable cannot see a shard whose
# list was widened to every phase: it would run all of them and agree with itself.
rer_declared_for() { sed -n "s/^PHASES_$1=\"\\([a-z0-9_ ]*\\)\"\$/\\1/p" "$RER_SELF" | tr ' ' '\n' | grep . | sort; }
rer_got="$(printf '%s\n' $RER_ENTERED | grep . | sort)"
rer_want="$(rer_declared_for "$GROUP")"
rer_foreign=""
for _s in $SHARDS; do
  [ "$_s" = "$GROUP" ] && continue
  for _p in $RER_ENTERED; do
    _lst="$(rer_declared_for "$_s")"
    grep -qxF -- "$_p" <<<"$_lst" && rer_foreign="$rer_foreign $_p"
  done
done
if [ -z "$rer_want" ] || [ "$rer_got" != "$rer_want" ] || [ -n "$rer_foreign" ]; then
  bad "[J1] shard $GROUP entered {$(printf '%s' "$rer_got" | tr '\n' ' ')}, its declared list is {$(printf '%s' "$rer_want" | tr '\n' ' ')}; entered from other shards: {${rer_foreign# }}"
fi

echo
report_end "reconcile-emit-report shard '$GROUP' of '$SHARDS'"
