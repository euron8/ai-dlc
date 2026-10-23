#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# reconcile-emit-report/run.sh — prove the reconcile report's mechanical sections are driver-owned:
# emit-report.sh renders them, and --verify fails a report whose region is missing OR hand-edited.
#
# THE DEFECT THIS EXISTS TO CATCH. The report was LLM-authored; a mechanical HARD finding was silently
# dropped from it, twice. Rendering the region is only half — the LLM could still omit it or edit it.
# --verify byte-compares the report's region against a fresh render, so neither omission nor a
# dropped-blocker edit survives.
#
# DISTINCT INPUT SHAPES IN THE STEP-3b BATTERY: FOUR. Arms and mutants are not shapes — channels
# written by different hands converge on the obvious way to build the input and then agree for that
# reason. These four differ in what the CLASSIFIER is handed:
#   S1  the well-formed pair (four templates at base, two moved at theirs, three of the four
#       generated files on the consumer)
#   S2  the template manifest ABSENT
#   S3  the manifest present with its `template_manifest:` block unparseable
#   S4  a manifest row naming a template absent at BOTH refs
# M3's transposed-argument refusal renders at rc=2, which is S2's shape, so it is counted there and
# not as a fifth. The per-shape roster is beside the battery, at the "STEP 3b" banner below.
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
# directories `-b`, `-c` and `-d` are drivers that run this file with their shard and exit 2 unless
# its verdict line names that shard.
#
# THE COVERAGE JOIN (J0) runs in every shard before anything is seeded: the declared phase set is
# derived from this file's own `if rer_phase` lines, every one must have its end marker, the lists
# dealt across SHARDS must be disjoint, non-empty and union to it exactly, and every declared shard
# but 'a' must have a driver directory that names it. The join proves it can fire, on a seeded
# duplicate and a seeded omission, before it is trusted. J1, at the foot, proves the shard ENTERED
# exactly the phases its list names. The mutants live inside the phases, so they inherit the join.
#
# A PHASE'S HELPERS LIVE INSIDE THE PHASE, and nothing is shared between phases except what is
# defined above them: the world guards, `ok`/`bad`, the seed variables, the shadowed-validator
# consumer seed, and the cache arms' helpers (the "CACHE-ARM HELPERS" block above phase pcache),
# which phases pcache and pcvlat both read. That was checked by listing every name each phase
# defines and every line outside it that reads one.
SHARDS="a b c d"
PHASES_a="seeded b230 moved shadow b1b2 wg pcache"
PHASES_b="vworlds1 vworlds2"
PHASES_c="step3b sb"
PHASES_d="pcvlat"
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
# The world-guard battery re-runs copies of this file in probe-only mode from a tree that carries no
# sibling drivers; those copies exit before any phase, so the join has nothing to bind there.
if [ -z "${AI_DLC_RER_PROBE_ONLY:-}" ]; then
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
# PHASES_*= lines are read off this file, PHASES_d is emptied in that copy, and rer_deal run over the
# copy must refuse naming exactly PHASES_d's phases as dealt to no shard, while the unedited copy
# passes. A shard whose list was emptied would otherwise run nothing and print PASS for it.
rer_decl="$(sed -n -e '/^SHARDS="[a-z ]*"$/p' -e '/^PHASES_[a-z]="[a-z0-9_ ]*"$/p' "$RER_SELF")"
rer_dslug="$(sed -n 's/^PHASES_d="\([a-z0-9_ ]*\)"$/\1/p' "$RER_SELF" | tr ' ' '\n' | grep . | sort | tr '\n' ' ')"
rer_dmut="$(printf '%s\n' "$rer_decl" | sed 's/^PHASES_d=".*"$/PHASES_d=""/')"
rer_pmsg="$(eval "$rer_dmut"; rer_deal "$RER_JW/declared")" && rer_prc=0 || rer_prc=$?
rer_cmsg="$(eval "$rer_decl"; rer_deal "$RER_JW/declared")" && rer_crc=0 || rer_crc=$?
if [ -z "$rer_dslug" ] || [ "$rer_dmut" = "$rer_decl" ] || [ "$rer_crc" -ne 0 ] || [ "$rer_prc" -eq 0 ] \
   || [ "$rer_pmsg" != "the phase deal does not cover the declared phases exactly -- dealt twice: {} dealt to no shard: {${rer_dslug% }} dealt but not declared: {}" ]; then
  echo "FIXTURE BROKEN: [J0] the deal check's declaration-text probe did not discriminate: PHASES_d {${rer_dslug% }} emptied gave rc=$rer_prc [$rer_pmsg], the unedited text rc=$rer_crc [$rer_cmsg]" >&2
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
fi
RER_ENTERED=""
rer_phase() { # rer_phase <slug> -> 0 when this shard owns the phase, and records it as entered
  eval "case \" \${PHASES_$GROUP} \" in *\" \$1 \"*) RER_ENTERED=\"\$RER_ENTERED \$1\"; return 0 ;; esac"
  return 1
}


# PROBE-ONLY MODE SKIPS THE SEED, AND THAT IS A COST DECISION WITH A NUMBER BEHIND IT.
# The world-guard battery at the foot of this file re-runs this whole script once per mutant,
# because the helpers it probes (`DGW`, `world_moved`, `world_at`, `broken`) are defined HERE.
# Measured: one probe-only run WITH the seed costs 34s, so seven of them add ~238s to a unit
# the durations file records at 184s LOADED -- more than doubling a pole-adjacent fixture, on
# a suite whose wall clock tracks its single longest directory. The guards under test build
# their own throwaway repository and never read the seeded world, so the seed is pure cost in
# this mode. Skipped, the battery is a rounding error instead of a pole change.
#
# THE FLAG IS NEVER SET BY THE PRE-PUSH RUNNER -- the battery sets it on the COPIES it drives
# -- so an ordinary invocation seeds and runs everything exactly as before.
if [ -n "${AI_DLC_RER_PROBE_ONLY:-}" ]; then
  WORK="$(mktemp -d "${TMPDIR:-/tmp}/rer-probe.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
  trap 'rm -rf "$WORK"' EXIT
else
  WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
  trap 'rm -rf "$WORK"' EXIT
  # shellcheck source=/dev/null
  . "$WORK/env.sh"
fi

fails=0; oks=0
ok()  { printf '  ok    %s\n' "$1"; oks=$((oks+1)); }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# STDERR IS KEPT, in `$VERIFY_ERR`, overwritten by each call. It is read only by render_diag()
# below, on a failing render arm -- discarded, a pool red printed the verdict and nothing else.
VERIFY_ERR="$WORK/verify.stderr"
verify() { bash "$EMIT" --verify "$1" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>"$VERIFY_ERR"; RC=$?; }

# render_diag <tag> <rc> [<extra-stderr-file> <label>] -- WHY a render arm went red. Every pool
# red this fixture had in batch 151 was a RENDER arm (assertion 1, the orientation pair, the
# docs-only near-miss), and each printed its verdict and nothing else, so nobody could say whether
# a detector had refused under load or the renderer was wrong. Printed ONLY on failure, bounded
# to 40 lines per stream as v_diag's diff is, and every line carries `DIAG` so a log grep finds it.
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
#
# `${REGION:-/dev/null}` BECAUSE PROBE-ONLY MODE NEVER SEEDS. That mode exists for the
# world-guard battery, whose subjects (`DGW`, `world_moved`, `world_at`, `broken`) build
# their own throwaway repository and read nothing the seed produces. Under `set -u` the bare
# `$REGION` aborted the run before the probe was reached, and an aborted copy prints no
# verdict at all -- which every "expected at least N failures" arm reads as MUTANT SURVIVED.
# The default keeps this line inert there and unchanged everywhere else; the probe's own
# `FIXTURE ERROR` guard is what catches a copy that really did fail to start.
ORIENT="$(awk '/Semantic worklist orientation/,/^\*\*Deletions/' "${REGION:-/dev/null}")"
# Which side is the line attributed to? Prints THEIRS or OURS, or nothing.
side_of() { printf '%s\n' "$ORIENT" | awk -v pat="$1" '
  /ONLY IN THEIRS/{s="THEIRS"} /ONLY IN OURS/{s="OURS"} $0 ~ pat {print s; exit}'; }

echo "reconcile-emit-report:"
echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/emit-report.sh"

# EVERY ASSERTION FROM HERE TO THE WORLD-GUARD SECTION READS THE SEEDED WORLD, and probe-only
# mode never builds one. The guards under test construct their own throwaway repository, so
# the whole corpus half is skipped rather than made conditional line by line -- one branch
# whose scope is visible, instead of a `${...:-}` default on each of forty readers.
if [ -z "${AI_DLC_RER_PROBE_ONLY:-}" ]; then

# --- Assertion 0: SANITY — the rendered region carries the HARD blocker -------
if grep -q "reconcile-mechanical" "$REGION" && grep -q "HARD-UNREGISTERED-CORE-DRIFT" "$REGION" && grep -q "thing.json" "$REGION"; then
  ok "the driver renders a mechanical region carrying the HARD schema blocker"
else
  bad "FIXTURE BROKEN — the rendered region lacks the HARD blocker; negatives below are meaningless"
  echo; echo "reconcile-emit-report: FIXTURE BROKEN" >&2; exit 2
fi

if rer_phase seeded; then
# --- Assertion 1: --verify PASSES a report carrying the region verbatim -------
verify "$REPORT_GOOD"
if [ "$RC" -eq 0 ]; then ok "--verify PASSES a report whose region matches the driver (exit 0)"
else bad "--verify failed a correct report (rc=$RC) — false positive"; render_diag "assertion-1" "$RC" "$VERIFY_ERR" verify; fi

# --- Assertion 2: --verify FAILS a report with NO region (the narrated bug) ---
verify "$REPORT_MISSING"
[ "$RC" -eq 1 ] && ok "--verify FAILS a report with no rendered region (exit 1)" \
  || bad "--verify did NOT fail a report missing the region (rc=$RC) — a narrated report could drop everything"

# --- Assertion 3: --verify FAILS a region hand-edited to DROP the blocker ------
verify "$REPORT_STALE"
[ "$RC" -eq 1 ] && ok "--verify FAILS a region hand-edited to drop the HARD blocker (exit 1) — an edited render cannot hide a finding" \
  || bad "--verify did NOT catch a dropped-blocker edit (rc=$RC) — the region could still be doctored"

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

# --- Assertion 8: MUTANT — orientation lives INSIDE the verified region --------
# If the block sat outside the GENERATED markers, the LLM could edit or drop it and --verify
# would still pass, which is exactly how the narrated report dropped findings before.
MUT="$WORK/report-orient-doctored.md"
{ echo "# Reconcile report (fixture)"; echo; grep -v 'SENTINEL-OURS-ONLY' "$REGION"; } > "$MUT"
verify "$MUT"
[ "$RC" -eq 1 ] && ok "mutant: deleting an orientation line FAILS --verify — the block is inside the verified region" \
  || bad "MUTANT DID NOT FAIL (rc=$RC) — orientation can be doctored without --verify noticing, so it is decoration"

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
  bash "$EMIT" --verify "$REPORT_GOOD" "$ALIAS" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>&1
  if [ "$?" -eq 0 ]; then
    ok "--verify PASSES a sound report from a DIFFERENT dist checkout (path-independent)"
  else
    bad "--verify FAILED a sound report merely because the dist checkout is at another path — the operator is told a good report is STALE or HAND-EDITED, and can only verify reports generated at their own path"
  fi

  # And normalization must not have blunted it: a real edit still fails from the other path.
  MUT2="$WORK/report-dropped-line.md"
  { echo "# Reconcile report (fixture)"; echo; grep -v 'HARD-UNREGISTERED-CORE-DRIFT' "$REGION"; } > "$MUT2"
  bash "$EMIT" --verify "$MUT2" "$ALIAS" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>&1
  if [ "$?" -eq 1 ]; then
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

# --- Assertion: MUTATION — restore the escapes inside the single quotes --------
# Rendered from a COPY of the whole reconcile dir, so the mutant's helper lookups resolve
# exactly as the real script's do and a missing helper cannot masquerade as a kill.
MUTR="$WORK/mut-reconcile"
rm -rf "$MUTR"; cp -R "$(dirname "$EMIT")" "$MUTR"
sha_line_of() { bash "$1" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null | grep -m1 '^_base_ '; }
sed 's@_base_ `%s` → _theirs_ `%s`.@_base_ \\`%s\\` → _theirs_ \\`%s\\`.@' "$EMIT" > "$MUTR/mutant-emit.sh"

if grep -q '\\`' <<<"$(sha_line_of "$MUTR/emit-report.sh")"; then
  bad "FIXTURE BROKEN — an UNMUTATED copy in the mutant directory already emits backslashes, so the mutation below would score a false kill"
elif cmp -s "$EMIT" "$MUTR/mutant-emit.sh"; then
  bad "FIXTURE BROKEN — the mutation matched nothing, so the assertion above is unproven"
elif grep -q '\\`' <<<"$(sha_line_of "$MUTR/mutant-emit.sh")"; then
  ok "mutation: re-escaping inside the single quotes puts literal backslashes back (the assertion above is load-bearing)"
else
  bad "the mutant emitted no backslashes — the assertion above cannot fail and is vacuous"
fi
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
fi   # end of the seed-dependent corpus half; see the probe-only branch above
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
#
# THE DEFAULT IS FOR PROBE-ONLY MODE, WHERE THERE IS NO SEEDED `$DIST` TO SAVE. Under `set -u`
# a bare `$DIST` aborts the run here, and an aborted copy prints no verdict — which every
# "expected at least N failures" arm reads as MUTANT SURVIVED rather than as a copy that died.
_WP_REAL_DIST="${DIST:-}"
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

# PROBE-ONLY MODE, and it exists for the mutant battery at the foot of this file. Those
# mutants edit THIS SCRIPT's own helpers, so each one has to be re-run as a whole program;
# without an early exit each would pay the unit's full cost and the battery would multiply a
# pole-bound fixture by five. The flag is read from the environment rather than from `$1`
# because `$1` is already this fixture's optional subject path.
#
# THE EXIT IS NOT AN ESCAPE HATCH FOR THE UNIT. It is never set by the pre-push runner — the
# battery sets it on the COPIES it drives — so a normal invocation runs everything below.
if [ -n "${AI_DLC_RER_PROBE_ONLY:-}" ]; then
  if [ "$fails" -eq 0 ]; then exit 0; fi
  exit 1
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
# FOUR ARMS, scored against the shipping copy and then against one mutant per layer of the fix:
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
# b230_score <recon-dir> <tag> -> the failing arm letters among a b e n. Every file it renders
# stays under $WORK/bl230-<tag>/ so a red arm can print its own evidence.
b230_score() {
  local _d="$1" _o="$WORK/bl230-$2" _r="" _m _e1 _e2
  mkdir -p "$_o"
  FX_B230_PC=rc2 bash "$_d/emit-report.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$_o/a.md" 2>"$_o/a.err"
  if [ "$2" = tip ]; then { echo "# Reconcile report (fixture)"; echo; cat "$_o/a.md"; } > "$B230_REFUSED"; fi
  _m="$(b230_five "$_o/a.md" "$B230_WANT_A")"
  [ -z "$_m" ] || { _r="${_r}a"; printf '%s\n' "$_m" > "$_o/a.why"; }
  FX_B230_PC=empty bash "$_d/emit-report.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$_o/b.md" 2>"$_o/b.err"
  _m="$(b230_five "$_o/b.md" "$B230_WANT_B")"
  [ -z "$_m" ] || { _r="${_r}b"; printf '%s\n' "$_m" > "$_o/b.why"; }
  if grep -qF "DETECTOR-REFUSED  preclassify.sh $B230_WANT_A" "$_o/a.md"; then
    FX_B230_PC=rc2 bash "$_d/emit-report.sh" --verify "$REPORT_GOOD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>"$_o/e1.err"; _e1=$?
    FX_B230_PC=rc2 bash "$_d/emit-report.sh" --verify "$B230_REFUSED" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>"$_o/e2.err"; _e2=$?
    if ! { [ "$_e1" -ne 0 ] && grep -qF "$B230_CAUSE" "$_o/e1.err" && [ "$_e2" -ne 0 ] && grep -qF "$B230_CAUSE" "$_o/e2.err"; }; then
      _r="${_r}e"; printf 'sound approved report rc=%s, refusal-carrying approved report rc=%s, cause named: %s/%s\n' \
        "$_e1" "$_e2" "$(grep -cF "$B230_CAUSE" "$_o/e1.err")" "$(grep -cF "$B230_CAUSE" "$_o/e2.err")" > "$_o/e.why"
    fi
  else
    : > "$_o/e.stood-down"
  fi
  bash "$_d/emit-report.sh" "$NM_DIST" "$NM_BASE" "$NM_CONS" "$NM_THEIRS" > "$_o/n.md" 2>"$_o/n.err"
  _m="$(b230_none "$_o/n.md")"
  [ -z "$_m" ] || { _r="${_r}n"; printf '%s\n' "$_m" > "$_o/n.why"; }
  printf '%s' "$_r"
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

  # THE UNMUTATED CONTROL, positive: the hooked copy, unforced, must classify this world exactly
  # as the seed render did. A copy that died, or a hook that fires unasked, fails here and not as
  # a verdict on emit-report.sh.
  if [ "$B230_BUILT" = 1 ]; then
    bash "$B230/emit-report.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$WORK/bl230-ctl.md" 2>"$WORK/bl230-ctl.err"
    if grep -qF "UPSTREAM-ONLY  $MOVED_PROBE_PATH" "$WORK/bl230-ctl.md" \
       && grep -qF 'BOTH-ADDED->CLASSIFY  core/skills/ai-dlc/templates/classes.md' "$WORK/bl230-ctl.md" \
       && ! grep -qF 'DETECTOR-REFUSED  preclassify.sh' "$WORK/bl230-ctl.md"; then
      ok "BL-230 control: the hooked copy, unforced, renders both seeded bucket rows and no preclassify refusal"
    else
      broken "BL-230: the hooked copy of the reconcile dir, UNFORCED, does not classify the seeded world, so the arms below would measure the copy"
      render_diag "bl230-control" 0 "$WORK/bl230-ctl.err" control-render
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
    b230_got="$(b230_score "$B230" tip)"
    B230_O="$WORK/bl230-tip"
    b230_arm() { # <letter> <ok-text> <bad-text>
      case "$b230_got" in
        *"$1"*) bad "BL-230 arm $1: $3 -- $(tr '\n' ' ' < "$B230_O/$1.why" 2>/dev/null)"
                [ "$1" = e ] && render_diag "bl230-e" "see-why" "$B230_O/e1.err" verify-sound "$B230_O/e2.err" verify-refused
                [ "$1" = e ] || render_diag "bl230-$1" "print-mode" "$B230_O/$1.err" "$1-render" ;;
        *) ok "BL-230 arm $1: $2" ;;
      esac
    }
    b230_arm a "preclassify exiting 2 renders the refusal in all five pc sections, no 'none', and its partial row nowhere" \
      "a preclassify that exited 2 did not render as a refusal in every pc-derived section"
    b230_arm b "preclassify returning NO rows over a range that moves core/ renders the same refusal, naming that cause" \
      "an empty classification over a range that moves core/ rendered as a clean pull"
    if [ -f "$B230_O/e.stood-down" ]; then
      printf '  --    (BL-230 arm e STANDS DOWN: the forced render carries no refusal line, which is arm a'"'"'s finding)\n'
    else
      b230_arm e "--verify refuses a fresh render carrying the refusal, naming PRECLASSIFY-REFUSED, for a sound report and for one that carries the refusal itself" \
        "--verify did not refuse, by name, a render whose classifier did not classify"
    fi
    b230_arm n "near-miss: an EMPTY classification over a range that leaves core/ untouched renders 'none' and no refusal" \
      "near-miss: a range that leaves core/ untouched was refused, or rendered no 'none'"

    # THE MUTANTS, one per layer, each a copy of the whole hooked dir, each expected to fail
    # EXACTLY its own arm. Scored in parallel -- each is five invocations of the renderer, and
    # this unit sits beside the suite pole.
    b230_mut() { # <name> <file> <anchor> <replacement> -> prints the mutant dir, or nothing
      local _md="$WORK/bl230-m-$1"
      cp -R "$B230" "$_md" 2>/dev/null || return 1
      b230_line "$_md/$2" "$3" "$4" || return 1
      if cmp -s "$B230/$2" "$_md/$2"; then return 1; fi
      bash -n "$_md/$2" 2>/dev/null || return 1
      printf '%s' "$_md"
    }
    B230_PIDS=""; B230_LIST=""
    b230_launch() { # <name> <expect> <file> <anchor> <replacement>
      local _md
      _md="$(b230_mut "$1" "$3" "$4" "$5")"
      if [ -z "$_md" ]; then
        bad "FIXTURE STALE [BL-230 $1]: the mutation did not apply -- its anchor is not exactly one line of $3. Re-anchor on the same observable, never relax the arm"
        return 0
      fi
      ( b230_score "$_md" "$1" > "$WORK/bl230-$1.score" ) &
      B230_PIDS="$B230_PIDS $!"
      B230_LIST="$B230_LIST $1:$2"
    }
    # M1, owned by a: the rc is discarded again. b survives it through the empty guard, which is
    # the layer M2 removes; the partial row arm a forces is what separates this from an empty run.
    b230_launch m1-rc-discarded a emit-report.sh \
      '  pc="$(bash "$SELF/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null)"' \
      '  pc="$(bash "$SELF/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null || true)"'
    # M2, owned by b: no guard on an empty row set over a range that moves core/.
    b230_launch m2-empty-guard-dropped b emit-report.sh '  elif [ -z "$pc" ]; then' '  elif false; then'
    # M4, owned by e: --verify no longer refuses a render carrying the preclassify refusal. The
    # opposite direction -- the guard widened to every DETECTOR-REFUSED -- is owned by assertion 1,
    # whose approved region carries a retired-layer-token refusal on every run.
    # Anchored on the line that DECIDES the refusal: since BL-360 the render is staged and one grep's
    # status `_pc_rc` decides it, where this used to be the `grep -Eq … <<<"$want"` line itself.
    b230_launch m4-verify-refusal-dropped e emit-report.sh \
      'if [ "$_pc_rc" = 0 ]; then' \
      'if false; then'
    # M5, owned by n: an empty classification is refused whatever the range -- the `[ -z "$pc" ]` fix.
    b230_launch m5-range-ignored n emit-report.sh '    elif [ -n "$pc_rng" ]; then' '    elif true; then'
    for _p in $B230_PIDS; do wait "$_p" 2>/dev/null; done
    B230_SCORED=0
    for _s in $B230_LIST; do
      _n="${_s%%:*}"; _x="${_s#*:}"
      _g="$(cat "$WORK/bl230-$_n.score" 2>/dev/null)"
      if ! grep -qF 'BEGIN GENERATED: reconcile-mechanical' "$WORK/bl230-$_n/n.md" 2>/dev/null; then
        bad "MUTANT HARNESS BROKEN [BL-230 $_n]: the copy rendered no region at all, so its score is a copy that did not run"
      elif [ "$_g" = "$_x" ]; then
        ok "mutant BL-230 $_n fails exactly arm [$_x]"
        B230_SCORED=$((B230_SCORED+1))
      elif [ -z "$_g" ]; then
        bad "MUTANT SURVIVED [BL-230 $_n]: every arm passed with the layer removed, so arm $_x cannot see it"
      else
        bad "MUTANT [BL-230 $_n] failed arms [$_g], expected exactly [$_x] -- the arms are entangled or one is vacuous"
      fi
    done
    if [ "$B230_SCORED" -ne 4 ]; then
      bad "only $B230_SCORED of 4 BL-230 mutants were built, applied and killed by their own arm alone"
    fi
  fi
fi
fi # end rer_phase b230

if rer_phase moved; then
# The APPROVED render — theirs spelled symbolically, ref sitting where the operator approved it.
REGION_SYM="$WORK/region-symbolic.md"
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

verify_ref "$REPORT_SYM" "$MOVEREF"
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

verify_ref "$REPORT_SYM" "$MOVEREF"
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

# --- Assertion: MUTANT — delete the tree line and the core move goes invisible --
# Rendered from a COPY of the whole reconcile dir so the mutant's sibling lookups (preclassify,
# retired-tokens, ledger-reverify) resolve exactly as the real script's do; a copy that died
# sourcing a helper emits nothing, and nothing would otherwise score as a kill.
DGW "resetting to $THEIRS before the mutant battery" reset --hard "$THEIRS" || true
world_at "the mutant battery's reset" "$THEIRS" || true
MUTT="$WORK/mut-reconcile-tree"
rm -rf "$MUTT"; cp -R "$(dirname "$EMIT")" "$MUTT"
# Anchored on the rendered text, which is unique in the file — the prose above it says
# "`core/` TREE" in caps and does not match. The impossible anchor is the control.
anchor_hits="$(grep -c '_theirs_ `core/` tree ' "$EMIT")"
control_hits="$(grep -c 'ZZ-NO-SUCH-ANCHOR-IN-THIS-FILE-ZZ' "$EMIT")"
sed '/_theirs_ `core\/` tree /d' "$EMIT" > "$MUTT/mutant-emit.sh"

CTL_REGION="$WORK/mut-ctl-region.md"; MUT_REGION="$WORK/mut-region.md"
bash "$MUTT/emit-report.sh"  "$DIST" "$BASE" "$CONSUMER" "$MOVEREF" > "$CTL_REGION" 2>/dev/null
bash "$MUTT/mutant-emit.sh"  "$DIST" "$BASE" "$CONSUMER" "$MOVEREF" > "$MUT_REGION" 2>/dev/null
CTL_REPORT="$WORK/mut-ctl-report.md"; MUT_REPORT="$WORK/mut-report.md"
{ echo "# Reconcile report (fixture)"; echo; cat "$CTL_REGION"; } > "$CTL_REPORT"
{ echo "# Reconcile report (fixture)"; echo; cat "$MUT_REGION"; } > "$MUT_REPORT"

# Now move theirs across the same core change both renderers were pointed at.
_pre_mut="$(git -C "$DIST" rev-parse "$MOVEREF" 2>/dev/null)"
DGW "checking out $MOVEREF for the mutant-battery world" checkout -q "$MOVEREF" || true
printf '#!/usr/bin/env bash\necho MOVED-REF-PROBE moved-under-the-mutant\n' > "$DIST/$MOVED_PROBE_PATH"
DGW "staging the mutant-battery world" add -A || true
DGW "committing the mutant-battery world" commit -m "upstream core content moves under the mutant battery" || true
world_moved "the mutant-battery world" "$MOVEREF" "$_pre_mut" || true
bash "$MUTT/emit-report.sh" --verify "$CTL_REPORT" "$DIST" "$BASE" "$CONSUMER" "$MOVEREF" >/dev/null 2>&1
ctl_rc=$?
bash "$MUTT/mutant-emit.sh" --verify "$MUT_REPORT" "$DIST" "$BASE" "$CONSUMER" "$MOVEREF" >/dev/null 2>&1
mut_rc=$?

# The UNMUTATED control, with a positive conjunct: a baseline row must be THERE. rc=1 and an
# empty region is what a copy that failed to start also looks like.
if [ "$anchor_hits" -ne 1 ]; then
  bad "FIXTURE BROKEN — the mutation anchor matches $anchor_hits lines in emit-report.sh, not 1; a multi-line edit moves cells this battery does not own"
elif [ "$control_hits" -ne 0 ]; then
  bad "FIXTURE BROKEN — the impossible-anchor control matched $control_hits lines, so the uniqueness count above means nothing"
elif cmp -s "$EMIT" "$MUTT/mutant-emit.sh"; then
  bad "FIXTURE BROKEN — the mutation matched nothing, so the arms above are unproven"
elif ! grep -qF "UPSTREAM-ONLY  $MOVED_PROBE_PATH" "$CTL_REGION"; then
  bad "FIXTURE BROKEN — the UNMUTATED copy rendered no baseline row, so the copied directory is what failed, not the mutation"
elif [ "$ctl_rc" -ne 1 ]; then
  bad "FIXTURE BROKEN — the unmutated copy did NOT reject the moved ref (rc=$ctl_rc); the mutant's silence below would prove nothing"
else
  ok "control: the UNMUTATED copy renders the baseline row and still rejects the moved ref (rc=$ctl_rc)"
fi

# THE MUTANT. Positive conjunct again: it must render a real region that carries the baseline
# row and LACKS the tree line. A renderer replaced by `exit 0` also exits 0 on --verify.
#
# THE NO-OP GUARD IS REPEATED HERE ON PURPOSE, not left to the control's chain above. If the
# tree line is already gone from emit-report.sh — someone reverted the fix — the `sed` matches
# nothing, the "mutant" is a byte-identical copy, and it is blind for the reason the SUBJECT is
# blind rather than for the reason the mutation intends. Measured: without this conjunct that
# state printed `ok` here, a mutation that mutated nothing scoring a kill beside the very
# assertions it had just stopped proving.
if [ "$anchor_hits" -eq 1 ] && ! cmp -s "$EMIT" "$MUTT/mutant-emit.sh" \
   && grep -qF "UPSTREAM-ONLY  $MOVED_PROBE_PATH" "$MUT_REGION" \
   && ! grep -q '^_theirs_ `core/` tree ' "$MUT_REGION" \
   && [ "$mut_rc" -eq 0 ]; then
  ok "mutant: with the tree line deleted the region still renders every bucket, and the core move becomes INVISIBLE to --verify (rc=$mut_rc) — the arms above are load-bearing"
else
  bad "MUTANT DID NOT SURVIVE ITS OWN DELETION (region rows present? / tree line gone? / rc=$mut_rc) — something OTHER than the tree line is carrying the moved-ref arms, so those arms do not test what they claim"
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
mkdir -p "$CONSUMER/_bmad-output/ai-dlc-update" "$CONSUMER/scripts/ai-dlc-local" "$CONSUMER/scripts/ai-dlc"
cat > "$CONSUMER/_bmad-output/ai-dlc-update/push-candidate-ledger.md" <<'SHADLED'
# Push-candidate ledger (fixture)

## PC-CLOSED-SHADOW — validate-shadowprobe.sh: divergence
Prose about core/scripts/validate-shadowprobe.sh.
ADOPTED UPSTREAM (v0.130.0, verified 2026-07-22)

## PC-OPEN-KEEP — validate-keepprobe.sh: divergence
Prose about core/scripts/validate-keepprobe.sh — still diverging.
SHADLED
printf '#!/bin/sh\nexit 0\n' > "$CONSUMER/scripts/ai-dlc-local/validate-shadowprobe.sh"
printf '#!/bin/sh\nexit 0\n' > "$CONSUMER/scripts/ai-dlc/validate-shadowprobe.sh"
printf '#!/bin/sh\nexit 0\n' > "$CONSUMER/scripts/ai-dlc-local/validate-keepprobe.sh"
printf '#!/bin/sh\nexit 0\n' > "$CONSUMER/scripts/ai-dlc/validate-keepprobe.sh"

if rer_phase shadow; then
SHAD_REGION="$WORK/shadow-region.txt"
bash "$EMIT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$SHAD_REGION" 2>/dev/null

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
# a copy picks up the stubbed detector, and no shipped file is touched. An UNMUTATED control
# runs through the same sandbox first — a sandbox that simply died also prints no
# RETIRE-CANDIDATE row, and that is indistinguishable from the refusal branch working.
SHADMUT="$WORK/shadow-mutant"
mkdir -p "$SHADMUT"
cp "$(dirname "$EMIT")"/*.sh "$SHADMUT/" 2>/dev/null
cp "$(dirname "$EMIT")"/*.md "$SHADMUT/" 2>/dev/null

ctl_region="$WORK/shadow-ctl-region.txt"
bash "$SHADMUT/emit-report.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$ctl_region" 2>/dev/null
if grep -q 'scripts/ai-dlc-local/validate-shadowprobe.sh' "$ctl_region"; then
  ok "control: the UNMUTATED sandbox copy renders the RETIRE-CANDIDATE row, so the refusal arm below measures the stub and not a broken sandbox"
else
  bad "FIXTURE BROKEN — the unmutated sandbox copy renders no RETIRE-CANDIDATE row; the refusal arm below would pass for the wrong reason"
fi

printf '#!/usr/bin/env bash\nexit 2\n' > "$SHADMUT/warn-shadowed-local-validators.sh"
mut_region="$WORK/shadow-mut-region.txt"
bash "$SHADMUT/emit-report.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$mut_region" 2>/dev/null
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
# THE FOUR INPUT SHAPES THIS BATTERY DRIVES, and they are four rather than seven because the
# mutants share worlds with the arms:
#   S1  the WELL-FORMED pair          — four templates at base, two moved at theirs, three of
#                                       the four generated files on the consumer (the fixture's
#                                       own seeded world). Arms A1, A2, A4, A5; mutants M1, M2, M5.
#   S2  the manifest ABSENT           — a copy of reconcile/ with template-sites.md removed.
#                                       Arm A3; mutants M4, M6.
#   S3  the manifest PRESENT but its  — the same copy with the `template_manifest:` key renamed,
#       `template_manifest:` block      so `-r` passes and the awk parses to nothing. Arm A3's
#       unparseable                     second shape. This is the one no `-r` test can see.
#   S4  a manifest row naming a        — a phantom entry whose template exists at NEITHER ref.
#       template absent at BOTH refs    Arm A2b. base_h == theirs_h == empty, so it buckets
#                                       TEMPLATE-UNCHANGED-NOOP and is indistinguishable in the
#                                       rendered row from a real unchanged template.
# M3 (args transposed) renders an rc=2 refusal, which is S2's shape and is counted there rather
# than as a fifth; the contract says the same.
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
T_REGION="$WORK/tpl-region.txt"
bash "$EMIT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$T_REGION" 2>/dev/null
T_SEC="$(T_SECT "$T_REGION")"

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
t_missing=""
for t_row in "TEMPLATE-PROSE-MERGE  CLAUDE.md  <- templates/CLAUDE.md.template" \
             "TEMPLATE-JSON-MERGE  .claude/settings.json  <- templates/settings.json.template" \
             "TEMPLATE-UNCHANGED-NOOP  docs/coding-conventions.md  <- templates/coding-conventions.md.template" \
             "CONSUMER-MISSING-NOOP  QUICKSTART.md  <- templates/QUICKSTART.md.template"; do
  grep -qF "$t_row" <<<"$T_SEC" || t_missing="$t_missing | $t_row"
done
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
# to a `-r` test. Each gets an UNMUTATED CONTROL through the same sandbox first: a sandbox copy
# that simply died renders no rows either, and that is indistinguishable from the refusal branch
# working.
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
t_refuse_check() { # t_refuse_check <label> <shape> <what-the-shape-is>
  local d="$WORK/tpl-refuse-$2" ctl mut s_rc
  t_refuse_world "$WORK/tpl-refuse-ctl-$2" none || { bad "$1 could not build the control sandbox"; return; }
  s_rc=0; t_stage "$WORK/tpl-refuse-ctl-$2.region" "$WORK/tpl-refuse-ctl-$2/emit-report.sh" || s_rc=$?
  if [ "$s_rc" -ne 0 ]; then
    bad "FIXTURE BROKEN — $1 CONTROL's unmutated render $(t_stage_why "$WORK/tpl-refuse-ctl-$2.region" "$s_rc"), so neither the control nor the refusal assertion below was read"
    return
  fi
  ctl="$(T_SECT "$WORK/tpl-refuse-ctl-$2.region")" || { bad "FIXTURE BROKEN — $1 could not read its staged CONTROL region"; return; }
  if ! grep -q 'TEMPLATE-PROSE-MERGE' <<<"$ctl"; then
    bad "$1 CONTROL the UNMUTATED sandbox copy rendered no TEMPLATE-PROSE-MERGE row, so the refusal assertion below would pass for a sandbox that simply died"
    return
  fi
  t_refuse_world "$d" "$2" || { bad "$1 could not build the $2 sandbox"; return; }
  s_rc=0; t_stage "$d.region" "$d/emit-report.sh" || s_rc=$?
  if [ "$s_rc" -ne 0 ]; then
    bad "FIXTURE BROKEN — $1 the $2 sandbox's render $(t_stage_why "$d.region" "$s_rc"), so whether it renders DETECTOR-REFUSED was not read"
    return
  fi
  mut="$(T_SECT "$d.region")" || { bad "FIXTURE BROKEN — $1 could not read the $2 sandbox's staged region"; return; }
  if grep -q 'DETECTOR-REFUSED' <<<"$mut" && ! grep -qx 'none' <<<"$mut" && ! grep -q 'TEMPLATE-' <<<"$mut"; then
    ok "$1 $3 renders DETECTOR-REFUSED and NOT 'none' (control: the unmutated copy beside it renders the real rows)"
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
  verify "$T_RPT_GOOD"; t_v_good="$RC"
  verify "$T_RPT_CUT";  t_v_cut="$RC"
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

# --- MUTANTS M1-M6 ------------------------------------------------------------
# Each is a copy of the WHOLE reconcile directory: emit-report.sh resolves $SELF beside itself and
# shells to preclassify.sh, so a lone script copy reads zero rows on every input and its silence
# would score as a kill on every arm at once.
#
# M4 and M6 are scored on the ABSENT-MANIFEST world (S2), not on the well-formed pair. MEASURED:
# with the manifest present M6 renders the same four rows as the shipped program — the guard it
# reverts only fires when there is nothing to parse — so scored on S1 it survives for a reason
# that has nothing to do with the predicate.
TMD="$WORK/tpl-mutants"; mkdir -p "$TMD"
T_APPLIED=""
t_mk() { # t_mk <name> <victim: emit|preclassify> <expected-anchor-hits> <anchor-regex> <world> <sed-args...>
  local n="$1" victim="$2" want="$3" anch="$4" world="$5"; shift 5
  local d="$TMD/$n" src hits ctl out
  case "$victim" in
    emit)        src="$EMIT" ;;
    preclassify) src="$(dirname "$EMIT")/preclassify.sh" ;;
  esac
  rm -rf "$d"; cp -R "$(dirname "$EMIT")" "$d" || { bad "$n could not copy the reconcile directory"; return 1; }
  [ -f "$d/preclassify.sh" ] && [ -f "$d/template-sites.md" ] || {
    bad "$n did not stage its siblings — a copy missing preclassify.sh or template-sites.md emits nothing and its silence would score as a kill"; return 1; }
  case "$world" in absent) rm -f "$d/template-sites.md" ;; esac
  hits="$(grep -c -e "$anch" "$src")" || hits=0
  ctl="$(grep -c -e 'ZZ-NO-SUCH-TEMPLATE-ANCHOR-ZZ' "$src")" || ctl=0
  if [ "$ctl" -ne 0 ]; then
    bad "$n the impossible-anchor control matched $ctl line(s) in $(basename "$src"), so the uniqueness count below means nothing"; return 1
  fi
  if [ "$hits" -ne "$want" ]; then
    bad "$n's anchor matches $hits line(s) in $(basename "$src"), not $want — the subject was respelled and this mutant edits something other than what it names. Re-anchor it; do NOT relax the assertion."; return 1
  fi
  case "$victim" in
    emit)        out="$d/mutant-emit.sh" ;;
    preclassify) out="$d/preclassify.sh" ;;
  esac
  if ! sed "$@" "$src" > "$out.tmp"; then
    bad "$n DID NOT APPLY — sed failed, so no mutant exists and the arm it guards is unproven"; return 1
  fi
  if cmp -s "$src" "$out.tmp"; then
    bad "$n DID NOT APPLY — the sed matched nothing, so the arm it guards is unproven"; return 1
  fi
  mv "$out.tmp" "$out"
  T_APPLIED="$T_APPLIED $n"
  return 0
}
t_mut_emit()  { local d="$TMD/$1"; [ -f "$d/mutant-emit.sh" ] && printf '%s\n' "$d/mutant-emit.sh" || printf '%s\n' "$d/emit-report.sh"; }
t_mut_sect()  { # t_mut_sect <name> — the step-3b section as that mutant renders it
  local d="$TMD/$1"
  bash "$(t_mut_emit "$1")" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$d/region.txt" 2>/dev/null
  T_SECT "$d/region.txt"
}
t_applied() { case " $T_APPLIED " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# M1 the whole section deleted. Range-delete keyed on the section's own `sub` line and the `fi`
# that closes its refusal branch, so it removes the block and nothing else.
t_mk M1 emit 1 '^  sub "Template pre-classification' none \
  -e '/^  sub "Template pre-classification/,/^  fi$/d'
# M2 header KEPT, the classifier call dropped — `none` rendered for a detector never invoked.
# This is the shape A1 alone cannot catch, and the reason A2 demands rows rather than a heading.
t_mk M2 emit 1 '^  tpl="\$(bash "\$SELF/preclassify.sh"' none \
  -e 's@^  tpl="\$(bash "\$SELF/preclassify.sh".*@  tpl=""@'
# M3 args transposed to emit-report's own order. preclassify refuses at its consumer-root guard
# with a sha as the path, rc=2, and the refusal arm renders REFUSED where four rows belong.
t_mk M3 emit 1 '"\$DIST" "\$BASE" "\$THEIRS" "\$CONSUMER" --templates' none \
  -e 's@"\$DIST" "\$BASE" "\$THEIRS" "\$CONSUMER" --templates@"$DIST" "$BASE" "$CONSUMER" "$THEIRS" --templates@'
# M4 the refusal arm collapsed — rc ignored, `none` rendered on a refusal. Scored on S2.
t_mk M4 emit 1 '^  if \[ "\$tpl_rc" -eq 0 \]; then none_or "\$tpl"; else$' absent \
  -e 's@^  if \[ "\$tpl_rc" -eq 0 \]; then none_or "\$tpl"; else$@  if true; then none_or "$tpl"; else@'
# M6 BOTH of preclassify's manifest guards reverted — the layered fix undone in full, because a
# partial revert leaves the layer still in place and comes out green. Scored on S2: with the
# manifest present this mutant renders the identical four rows.
t_mk M6 preclassify 1 '^  \[ -r "\$MANIFEST" \] ||' absent \
  -e '/^  \[ -r "\$MANIFEST" \] ||/d' -e '/^  \[ -n "\$TEMPLATE_ROWS" \] ||/d'

# M5 is a MOVE, not a substitution, so it is built with awk rather than through t_mk — and it is
# checked the same three ways: the anchor is unique, the mutation applied, and the observable is
# the right one for the right reason.
T_M5="$TMD/M5"
rm -rf "$T_M5"; cp -R "$(dirname "$EMIT")" "$T_M5"
t_m5_a="$(grep -c '^  sub "Deletions (apply would git rm' "$EMIT")" || t_m5_a=0
t_m5_b="$(grep -c '^  sub "Template pre-classification' "$EMIT")" || t_m5_b=0
if [ "$t_m5_a" -ne 1 ] || [ "$t_m5_b" -ne 1 ]; then
  bad "M5's anchors match $t_m5_a and $t_m5_b lines (want 1 and 1) — the section headers were respelled and this mutant would move something other than what it names"
else
  awk '
    /^  sub "Deletions \(apply would git rm/ {hold=3}
    hold>0 {buf[n++]=$0; hold--; next}
    /^  sub "Template pre-classification/ {intpl=1}
    {print}
    intpl==1 && /^  fi$/ {for(i=0;i<n;i++) print buf[i]; n=0; intpl=0}
  ' "$EMIT" > "$T_M5/mutant-emit.sh"
  if cmp -s "$EMIT" "$T_M5/mutant-emit.sh"; then
    bad "M5 DID NOT APPLY — the awk produced a byte-identical file, so A5 is unproven"
  elif [ "$(grep -c . "$EMIT")" -ne "$(grep -c . "$T_M5/mutant-emit.sh")" ]; then
    bad "M5 DID NOT APPLY CLEANLY — the move changed the non-blank line count ($(grep -c . "$EMIT") -> $(grep -c . "$T_M5/mutant-emit.sh")), so it deleted or duplicated something and its kill would be unattributed"
  else
    T_APPLIED="$T_APPLIED M5"
  fi
fi

# CONTROL FIRST: an UNMUTATED copy in a fresh directory renders the four rows. Two inert runs
# compare equal, so without this every kill below could be a battery comparing nothing to nothing.
T_CTL="$TMD/ctl"; rm -rf "$T_CTL"; cp -R "$(dirname "$EMIT")" "$T_CTL"
t_ctl_rc=0; t_stage "$T_CTL.region" "$T_CTL/emit-report.sh" || t_ctl_rc=$?
t_ctl_sec=""; t_ctl_rows=0
if [ "$t_ctl_rc" -eq 0 ] && t_ctl_sec="$(T_SECT "$T_CTL.region")"; then
  t_ctl_rows="$(grep -c 'TEMPLATE-PROSE-MERGE\|TEMPLATE-JSON-MERGE\|TEMPLATE-UNCHANGED-NOOP\|CONSUMER-MISSING-NOOP' <<<"$t_ctl_sec")" || t_ctl_rows=0
fi
if [ "$t_ctl_rc" -ne 0 ]; then
  bad "FIXTURE BROKEN — CONTROL(T)'s unmutated render $(t_stage_why "$T_CTL.region" "$t_ctl_rc"), so its row count was not read and every mutant verdict below is unreadable"
elif [ "$t_ctl_rows" -eq 4 ]; then
  ok "CONTROL(T) an unmutated copy of reconcile/ in a fresh directory renders all four step-3b rows, so a mutant's changed section is the mutation and not the copy"
else
  bad "CONTROL(T) the unmutated copy rendered $t_ctl_rows step-3b row(s), not 4 — every mutant verdict below is unreadable, because a copy that never ran renders nothing and that is what a kill looks like"
fi

# M1 -> A1. The section gone entirely. Its OWN arm is the header; the second conjunct is what
# stops this scoring as a kill of a subject that emits nothing at all.
if t_applied M1; then
  t_m1="$(t_mut_sect M1)"
  if ! grep -q 'Template pre-classification' "$TMD/M1/region.txt" \
     && grep -q 'HARD-UNREGISTERED-CORE-DRIFT' "$TMD/M1/region.txt" \
     && grep -q 'Scripts relocation' "$TMD/M1/region.txt"; then
    ok "M1 KILLED by A1: the section deleted renders no step-3b header, while the rest of the region (the HARD blocker, Scripts relocation) still renders — so the mutant removed the section and not the program"
  else
    bad "M1 SURVIVED A1 — either the header renders with the section deleted (impossible, so the mutation missed), or the mutant emits nothing at all and its silence is being read as a kill"
  fi
fi

# M2 -> A2. Header kept, no call. The exact shape A1 cannot see.
if t_applied M2; then
  t_m2="$(t_mut_sect M2)"
  if grep -q 'Template pre-classification' "$TMD/M2/region.txt" \
     && grep -qx 'none' <<<"$t_m2" \
     && ! grep -q 'TEMPLATE-PROSE-MERGE' <<<"$t_m2"; then
    ok "M2 KILLED by A2: the header still renders and the section reads 'none' — a heading plus 'none' is exactly what an uninvoked detector looks like, and only the row assertion separates it from four templates with nothing to sync"
  else
    bad "M2 SURVIVED A2 — the dropped classifier call did not empty the section (got: $(printf '%s' "$t_m2" | tr '\n' ' ' | head -c 120))"
  fi
fi

# M3 -> A2, via the refusal. Same input shape as A3 (an rc=2 refusal), counted there.
if t_applied M3; then
  t_m3="$(t_mut_sect M3)"
  if grep -q 'DETECTOR-REFUSED' <<<"$t_m3" && ! grep -q 'TEMPLATE-PROSE-MERGE' <<<"$t_m3"; then
    ok "M3 KILLED by A2: transposing the args to emit-report's own order makes preclassify refuse on a sha as its consumer root, and the section renders DETECTOR-REFUSED where the four rows belong — the argument-order quirk is load-bearing and not a comment"
  else
    bad "M3 SURVIVED A2 — the transposed call still produced rows, so the section is not reading preclassify's answer at all (got: $(printf '%s' "$t_m3" | tr '\n' ' ' | head -c 120))"
  fi
fi

# M4 -> A3, on the ABSENT-MANIFEST world.
if t_applied M4; then
  t_m4="$(t_mut_sect M4)"
  if grep -qx 'none' <<<"$t_m4" && ! grep -q 'DETECTOR-REFUSED' <<<"$t_m4"; then
    ok "M4 KILLED by A3: with the rc ignored, a refusing classifier renders 'none' — the operator reads a clean line for a detector that classified nothing, over two buckets that rewrite live consumer files"
  else
    bad "M4 SURVIVED A3 — collapsing the refusal arm did not produce 'none' on the absent-manifest world (got: $(printf '%s' "$t_m4" | tr '\n' ' ' | head -c 120)), so A3 is carried by something other than the rc read"
  fi
fi

# M5 -> A5. The ONLY arm that can see a re-sited section; every other arm greps the region.
if t_applied M5; then
  bash "$T_M5/mutant-emit.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$T_M5/region.txt" 2>/dev/null
  t_m5_o="$(awk '/Semantic worklist orientation/,/^\*\*Deletions/' "$T_M5/region.txt")"
  t_m5_hdr="$(grep -c 'Template pre-classification' <<<"$t_m5_o")" || t_m5_hdr=0
  t_m5_rows="$(grep -c 'TEMPLATE-PROSE-MERGE' "$T_M5/region.txt")" || t_m5_rows=0
  if [ "$t_m5_hdr" -ge 1 ] && [ "$t_m5_rows" -ge 1 ]; then
    ok "M5 KILLED by A5: sited between Semantic worklist and Deletions the section falls INSIDE the ORIENT range ($t_m5_hdr header hit), while the rows still render ($t_m5_rows) — so every other arm here stays green and A5 is the only one that moves"
  else
    bad "M5 SURVIVED A5 — the re-sited section did not land inside the ORIENT range (header hits $t_m5_hdr, rows $t_m5_rows). If the rows are 0 the mutant broke the program rather than moving the section, and its kill would be unattributed."
  fi
fi

# M6 -> A3's first shape. The preclassify guard is the LOAD-BEARING half of the layered fix: with
# it reverted the classifier exits 0 having classified nothing, and emit-report's rc read — still
# in place — correctly renders `none`. Both layers or neither.
if t_applied M6; then
  t_m6="$(t_mut_sect M6)"
  if grep -qx 'none' <<<"$t_m6" && ! grep -q 'DETECTOR-REFUSED' <<<"$t_m6"; then
    ok "M6 KILLED by A3: with preclassify's manifest guards reverted the classifier exits 0 on an absent manifest, emit-report's intact rc read sees success, and 'none' renders — the guard is load-bearing, and the driver's rc read alone cannot carry A3"
  else
    bad "M6 SURVIVED A3 — reverting both preclassify guards did not produce 'none' on the absent-manifest world (got: $(printf '%s' "$t_m6" | tr '\n' ' ' | head -c 120)), so A3's first shape is proven by something other than the guard it names"
  fi
fi

# Every mutant staged must have been scored. A mutation that never applied skips its arms with no
# verdict, and a battery that printed PASS over a mutant nobody scored is the shape this catches.
t_want="M1 M2 M3 M4 M5 M6"
t_got="$(printf '%s\n' $T_APPLIED | sort | tr '\n' ' ')"
if [ "$t_got" = "$(printf '%s\n' $t_want | sort | tr '\n' ' ')" ]; then
  ok "all six step-3b mutants applied and were scored (M1 M2 M3 M4 M5 M6)"
else
  bad "the step-3b mutants that applied were [${t_got:-none}] and had to be [$t_want] — a mutant that did not apply guards an arm nobody proved, and its absence reads exactly like a kill"
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
# V-DR is scored under the shipped program only, as a CONTROL on V-D rather than a mutant target:
# its claim is that the refusal blocks the resolved cause whether or not the operator resolved
# anything, which is a statement about the shipped classifier, not about any mutation.
V_CONTROL_WORLD="V-DR"
V_HARD='HARD-UNREGISTERED-CORE-DRIFT'
V_BASELINE='BOTH-ADDED->CLASSIFY  core/skills/ai-dlc/templates/classes.md'
VMD="$WORK/v-mutants"; mkdir -p "$VMD"

v_copy()    { local d="$VW/$1"; rm -rf "$d"; mkdir -p "$d" && cp -R "$CONSUMER" "$d/consumer"; }

# R6 — A WORLD BUILT OR SCORED UNDER A TRANSIENT REFUSAL IS RE-BUILT, NOT READ AS A VERDICT.
#
# THE FLAKE THIS CLOSES. Batch 160's pool put E3 on V-N at `3|BLOCKERS-RESOLVED|1|1|4|4`: the
# orientation `diff` failed once at APPROVE time and the engine rendered `ONLY IN …: none`, so
# the approval recorded a sample that never ran. The engine now NAMES that failure (a column-0
# `DETECTOR-REFUSED  orientation …` line), which makes the render honest and does NOT stop the
# kill arms going red: an approval carrying the refusal still scores `…|4|4` under E3, and one
# forced refusal while --verify scores E1 on V-HC moves that cell to `1|UNDECIDED|0|0|1|0` and
# reports `[V-R V-U V-HC]` — every kill set becomes a flake arm. Measured unforced too: this unit
# run ALONE went red with CONTROL(V), E4 and E7 each moved by one spontaneous
# `orientation diff exited 2` in a verify render, and an approve-time `ONLY IN …: none` appeared
# on its own under ~5 concurrent copies; `diff <(…) file` under four concurrent workers fails
# `/dev/fd/63: Bad file descriptor` on roughly 0.4% of calls, where a temp file fails none.
#
# SO BOTH SIDES RETRY, BOUNDED AT THREE, AND ONLY ON A REFUSAL THE HEALTHY WORLD DOES NOT CARRY.
# A retry is legitimate here only because the engine now NAMES the failure; before it, this
# would have retried straight into a silent `none`. Three refusals in a row are not transient.
# When the last one names a detector that is a file beside the engine under test and the seed
# world does not refuse it, the guard reports ENGINE REGRESSION naming the world and the
# detector: a shipped detector refusing on this world and not on the seed is a defect in that
# detector, and reporting it as FIXTURE BROKEN sent the reader to the wrong file (BL-338).
# Anything else — `orientation`, which is no file, or a name the seed itself refuses — stays
# FIXTURE BROKEN, and `emit-report-refusal` holds both of those shapes to that prefix. R6-VN
# below drives the ENGINE REGRESSION branch.
#
# THE BASELINE IS DERIVED, NEVER LISTED. The seed world carries one legitimate refusal on every
# clean run (`retired-layer-token.sh`), so keying on `^DETECTOR-REFUSED` at large would retry
# every approval three times and fail the unit. `V_REFUSE_OK` is the set of detector NAMES the
# seed region refuses; a scoring program built by `v_stub` adds the one sibling it killed, read
# from the `.stubbed` file `v_stub` writes beside it.
V_TRIES=3
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
  local d="$VW/$1" a=0 x="" n=""
  printf '%s\n' "$2" > "$d/ref"
  # `until`, where v_score's loop is `while`: the two retries are mutated separately by
  # `emit-report-refusal`, whose battery extracts these helpers from this file and drives them.
  until [ "$a" -ge "$V_TRIES" ]; do
    a=$((a+1))
    bash "$EMIT" "$DIST" "$BASE" "$d/consumer" "$2" > "$d/region.md" 2>/dev/null
    x="$(v_foreign "$d/region.md" "")"
    [ -z "$x" ] && break
  done
  if [ -n "$x" ]; then
    n="$(printf '%s\n' "$x" | awk '{ print $2; exit }')"
    # The seed test reads `$REGION` itself, never `V_REFUSE_OK`: a baseline that failed to
    # derive must not turn the seed's own refusal into an accusation against the engine.
    if [ -f "$(dirname "$EMIT")/$n" ] \
      && ! awk -v n="$n" 'index($0, "DETECTOR-REFUSED  " n " ") == 1 { f = 1 } END { exit !f }' "$REGION"; then
      bad "ENGINE REGRESSION — $1 approval: $n refused on $V_TRIES attempts and the seed world does not refuse it: $x — a detector emit-report.sh ships refusing deterministically on this world is a defect in $n, not in this fixture"
    else
      bad "FIXTURE BROKEN — $1 approval rendered DETECTOR-REFUSED on $V_TRIES attempts: $x — it names no detector emit-report.sh ships, or one the seed world itself refuses, so the retry or the baseline is what failed"
    fi
  fi
  { echo "# Reconcile report (fixture)"; echo; cat "$d/region.md"; } > "$d/approved.md"
  [ -s "$d/region.md" ]
}
# THE RESOLUTION, and it is the shipping producer's own bytes rather than a hand-written
# near-miss: the consumer's copy is put back to exactly what `git show "${base}:<path>"` holds, as
# a real adjudication does.
v_resolve() { git -C "$DIST" show "${BASE}:core/schemas/thing.json" > "$VW/$1/consumer/.claude/schemas/thing.json"; }
v_render()  { local d="$VW/$1"; bash "${2:-$EMIT}" "$DIST" "$BASE" "$d/consumer" "$(cat "$d/ref")" 2>/dev/null; }

# A COPY OF THE COPY, with one sibling replaced by a refusal. The refusing-detector worlds have to
# be verified by the program UNDER TEST, or E7/E10 would be scored against the shipped classifier
# and could not fail. Derived from whichever directory the emit under test lives in, so every
# mutant gets its own pair.
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
# and every score then reads clean. The derivation stays (it is what keeps the retries off the
# seed's legitimate refusal); this arm is the independent side of the join, a FIXED name.
# THE MUTANT is an engine copy whose `ledger-reverify.sh` refuses everywhere, rendered once over
# the seed world and put through the SAME derivation line — extracted from this file, so a change
# to how `V_REFUSE_OK` is derived is a change to what the mutant measures. Its positive control
# is the retired-layer-token refusal still being there, so a copy that never ran cannot score.
R6_FIXED_OK='retired-layer-token.sh'
r6_set() { printf '%s\n' $1 | awk 'NF' | sort -u | tr '\n' ' ' | sed 's/ $//'; }
_r6_have="$(r6_set "$V_REFUSE_OK")"
if [ "$_r6_have" = "$R6_FIXED_OK" ]; then
  ok "R6-BASE the derived refusal baseline is exactly {$R6_FIXED_OK}, the one refusal the seed world is known to carry — an engine refusal on every world cannot hide inside it"
else
  bad "R6-BASE the seed render's refusal set is [${_r6_have:-empty}], not exactly {$R6_FIXED_OK}: R6 would absorb that refusal on every world, so a detector the engine ships refusing everywhere reads as a clean baseline"
fi
_r6_line="$(grep -c '^V_REFUSE_OK="\$(awk .* "\$REGION")"$' "$HERE/run.sh")" || _r6_line=0
_r6m="$WORK/r6-base-mutant"
if [ "$_r6_line" -ne 1 ]; then
  bad "FIXTURE STALE [R6-BASE mutant]: the V_REFUSE_OK derivation line matched $_r6_line times in run.sh, not 1 — re-anchor on the same derivation"
elif ! _r6e="$(v_stub "$EMIT" "$_r6m" ledger-reverify.sh)"; then
  bad "FIXTURE BROKEN [R6-BASE mutant]: could not copy the engine directory"
else
  bash "$_r6e" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$WORK/r6-base-mutant.region" 2>/dev/null
  _r6m_ok="$(REGION="$WORK/r6-base-mutant.region"; eval "$(grep '^V_REFUSE_OK="\$(awk .* "\$REGION")"$' "$HERE/run.sh")"; printf '%s' "$V_REFUSE_OK")"
  _r6m_set="$(r6_set "$_r6m_ok")"
  # Membership is tested one name at a time: the set is sorted and space-joined, so two names
  # adjacent in it share ONE space, and a single glob naming both with a space on each side
  # cannot match them.
  _r6m_both=0
  case " $_r6m_set " in *" retired-layer-token.sh "*) _r6m_both=$((_r6m_both+1)) ;; esac
  case " $_r6m_set " in *" ledger-reverify.sh "*) _r6m_both=$((_r6m_both+1)) ;; esac
  case "$_r6m_both" in
    2)
      if [ "$_r6m_set" != "$R6_FIXED_OK" ]; then
        ok "R6-BASE mutant [ledger-reverify.sh refuses on every world] KILLED: the derived baseline becomes [$_r6m_set], which the fixed-name arm refuses"
      else
        bad "R6-BASE mutant SURVIVED: an engine refusing ledger-reverify.sh everywhere still derived exactly {$R6_FIXED_OK}"
      fi ;;
    *) bad "FIXTURE BROKEN [R6-BASE mutant]: the stubbed engine's derived set is [${_r6m_set:-empty}] — it must carry BOTH the seed's retired-layer-token refusal (the copy ran) and ledger-reverify.sh (the stub fired)" ;;
  esac
fi

# --- R6-VN begin ---
# R6-VN — A SHIPPED DETECTOR REFUSING ON ONE WORLD IS REPORTED AS AN ENGINE REGRESSION (BL-338).
# R6-BASE owns the global case. This is the other half: an engine copy whose `ledger-reverify.sh`
# refuses only when the consumer it is handed is a V-N world, so the seed render — and therefore
# `V_REFUSE_OK` — stays exactly as healthy as the real one, and nothing but v_approve's own
# message can say what went wrong. The shipped v_approve is driven, not restated, against two
# worlds built from the seed consumer through that ONE engine:
#   V-N  the refusing world   -> exactly one `ENGINE REGRESSION — V-N approval: ledger-reverify.sh`
#                                line, no FIXTURE BROKEN, and the stub fired exactly V_TRIES times
#   V-R  the near-miss        -> no line at all, and its Push-candidate ledger section is non-empty,
#                                carries no refusal, and is byte-identical to the SHIPPED engine's
#                                section for the same world, so the stub is keyed on the world and
#                                not refusing everywhere (which is R6-BASE's case). Compared against a
#                                live render, never a row count: the shared consumer's ledger is
#                                rewritten earlier in this file, so a count seeded from the seed
#                                ledger reads 0 here and 2 in isolation.
# Both run as background jobs; `bad` cannot count there, so each job writes its lines to a file
# read below. PRESENCE-SHAPED on the refusing side: a v_approve that reports nothing fails it.
_r6v="$WORK/r6-vn"; rm -rf "$_r6v"; mkdir -p "$_r6v/vw/V-N" "$_r6v/vw/V-R"
cp -R "$(dirname "$EMIT")" "$_r6v/eng"
awk -v fired="$_r6v/stub.fired" 'NR == 1 { print; print "case \"${3:-}\" in */V-N/consumer) echo x >> \"" fired "\"; exit 2 ;; esac"; next } { print }' \
  "$(dirname "$EMIT")/ledger-reverify.sh" > "$_r6v/eng/ledger-reverify.sh"
cp -R "$CONSUMER" "$_r6v/vw/V-N/consumer"; cp -R "$CONSUMER" "$_r6v/vw/V-R/consumer"
if cmp -s "$(dirname "$EMIT")/ledger-reverify.sh" "$_r6v/eng/ledger-reverify.sh"; then
  bad "FIXTURE BROKEN [R6-VN]: the V-N-only ledger-reverify.sh stub did not apply"
else
  for _w in V-N V-R; do
    ( EMIT="$_r6v/eng/emit-report.sh"; VW="$_r6v/vw"
      bad() { printf '%s\n' "$1" >> "$_r6v/$_w.bad"; }
      : > "$_r6v/$_w.bad"; v_approve "$_w" "$THEIRS"; : > "$_r6v/$_w.done" ) &
  done
  ( bash "$EMIT" "$DIST" "$BASE" "$_r6v/vw/V-R/consumer" "$THEIRS" > "$_r6v/V-R.shipped.md" 2>/dev/null ) &
  wait
  _r6v_fired="$(grep -c . "$_r6v/stub.fired" 2>/dev/null)" || _r6v_fired=0
  _r6v_lines="$(grep -c . "$_r6v/V-N.bad" 2>/dev/null)" || _r6v_lines=0
  _r6v_rt="$(grep -c '^DETECTOR-REFUSED  retired-layer-token\.sh ' "$_r6v/vw/V-N/region.md" 2>/dev/null)" || _r6v_rt=0
  if [ ! -f "$_r6v/V-N.done" ] || [ ! -f "$_r6v/V-R.done" ] || [ "$_r6v_rt" != 1 ]; then
    bad "FIXTURE BROKEN [R6-VN]: an approval job did not finish, or the stubbed engine's V-N render lacks the seed's retired-layer-token refusal ($_r6v_rt) — the copy never ran"
  elif [ "$_r6v_lines" = 1 ] && [ "$_r6v_fired" = "$V_TRIES" ] \
    && grep -q '^ENGINE REGRESSION — V-N approval: ledger-reverify\.sh refused on 3 attempts and the seed world does not refuse it: DETECTOR-REFUSED  ledger-reverify\.sh exited 2 ' "$_r6v/V-N.bad"; then
    ok "R6-VN a shipped detector (ledger-reverify.sh) refusing on the V-N approval only is reported as ENGINE REGRESSION naming the world and the detector, after $_r6v_fired attempts, and not as FIXTURE BROKEN"
  else
    bad "R6-VN the V-N-only ledger-reverify.sh refusal was reported as [$(head -1 "$_r6v/V-N.bad" | cut -c1-160)] ($_r6v_lines line(s), stub fired $_r6v_fired times), want one ENGINE REGRESSION line naming V-N and ledger-reverify.sh after $V_TRIES attempts — a deterministic engine refusal must not read as a fixture fault"
  fi
  _r6v_sec() { awk 'f && /^$/ { exit } f { print } index($0, "**Push-candidate ledger") == 1 { f = 1 }' "$1" 2>/dev/null; }
  _r6v_got="$(_r6v_sec "$_r6v/vw/V-R/region.md")"; _r6v_want="$(_r6v_sec "$_r6v/V-R.shipped.md")"
  if [ -f "$_r6v/V-R.done" ] && [ ! -s "$_r6v/V-R.bad" ] && [ -n "$_r6v_got" ] \
    && [ "$_r6v_got" = "$_r6v_want" ] && ! grep -q 'DETECTOR-REFUSED' <<< "$_r6v_got"; then
    ok "R6-VN near-miss: the same stubbed engine approves V-R clean, its Push-candidate ledger section byte-identical to the shipped engine's — the refusal is the V-N world's, not the engine's everywhere"
  else
    bad "R6-VN near-miss: V-R through the V-N-only stub reported [$(head -1 "$_r6v/V-R.bad" 2>/dev/null | cut -c1-160)], ledger section [$(printf '%s' "$_r6v_got" | head -1 | cut -c1-100)] vs shipped [$(printf '%s' "$_r6v_want" | head -1 | cut -c1-100)], want nothing and an identical non-refused section"
  fi
fi
# --- R6-VN end ---

# v_score <emit> <world> <tag> -> "<rc>|<cause>|<resolved-lines>|<n1>|<n2>|<unseen-lines>"
#
# PRESENCE-SHAPED IN EVERY FIELD. `rc` alone is what a subject replaced by `exit 1` also produces,
# so the cause word, the two counts the cause line prints IN ORDER (BLOCKERS-RESOLVED: blockers
# gone, unseen rows; UNDECIDED: new HARD rows, new DETECTOR-REFUSED lines) and the number of
# `resolved:`/`unseen:` lines are all part of the cell. A classifier that decides nothing scores
# `1|NONE|0|NA|NA|0` and matches no expected value here.
#
# AND THE COUNTS ARE IN THE CELL BECAUSE TWO OF THE MUTANTS BELOW MOVE NOTHING ELSE. E9 and E10
# cover each other on the VERDICT — measured, and the symptom of that is zero failures, not two —
# so each is killed on the diagnosis fields, and E11 is what shows the pair is load-bearing.
#
# R6 ON THE SCORING SIDE. A refusal in the FRESH render (the `< ` side of the forwarded diff) that
# the healthy world does not carry is re-scored, up to V_TRIES. Scoring runs in background jobs
# where `bad` cannot count, so three refusals in a row leave `broken.<tag>` beside the score and
# the foreground reports it (`v_broken_scan`).
v_score() {
  local e="$1" d="$VW/$2" f="$VW/$2/stderr.$3" rc cause nres nuns c1 c2 a=0 x="" sok=""
  [ -f "${e%/*}/.stubbed" ] && read -r sok < "${e%/*}/.stubbed"
  while [ "$a" -lt "$V_TRIES" ]; do
    a=$((a+1))
    bash "$e" --verify "$d/approved.md" "$DIST" "$BASE" "$d/consumer" "$(cat "$d/ref")" >/dev/null 2>"$f"
    rc=$?
    x="$(v_foreign "$f" "< " "$sok")"
    [ -z "$x" ] && break
  done
  rm -f "$d/broken.$3"
  [ -n "$x" ] && printf '%s\n' "$x" > "$d/broken.$3"
  cause="$(awk '/^  cause: /{print $2; exit}' "$f")"
  nres="$(grep -c '^    resolved: ' "$f")" || nres=0
  nuns="$(grep -c '^    unseen: ' "$f")" || nuns=0
  c1="$(awk '/^  cause: /{n=0; for(i=3;i<=NF;i++) if ($i ~ /^[0-9]+$/) { n++; if (n==1) { print $i; exit } } exit}' "$f")"
  c2="$(awk '/^  cause: /{n=0; for(i=3;i<=NF;i++) if ($i ~ /^[0-9]+$/) { n++; if (n==2) { print $i; exit } } exit}' "$f")"
  printf '%s|%s|%s|%s|%s|%s\n' "$rc" "${cause:-NONE}" "$nres" "${c1:-NA}" "${c2:-NA}" "$nuns"
}
v_emit_of() { # v_emit_of <tag>
  case "$1" in
    ship) printf '%s\n' "$EMIT" ;;
    ctl)  printf '%s\n' "$VMD/ctl/emit-report.sh" ;;
    *)    printf '%s\n' "$VMD/$1/mutant-emit.sh" ;;
  esac
}
v_sig() { # v_sig <tag> — scores every world under that tag's program, writing each score beside
  local t="$1" e n dd dh
  e="$(v_emit_of "$t")"
  dd="$(v_stub "$e" "$VMD/dead-drift-$t" unregistered-drift.sh)" || return 1
  dh="$(v_stub "$e" "$VMD/dead-hb-$t"    hard-blockers.sh)"      || return 1
  for n in $V_WORLDS; do
    case "$n" in
      V-D)  v_score "$dd" "$n" "$t" > "$VW/$n/score.$t" ;;
      V-HB) v_score "$dh" "$n" "$t" > "$VW/$n/score.$t" ;;
      *)    v_score "$e"  "$n" "$t" > "$VW/$n/score.$t" ;;
    esac
  done
}
# THE SIGNATURES ARE COMPUTED IN PARALLEL AND NOTHING IS ASSERTED INSIDE A BACKGROUND JOB.
# Thirteen programs times eleven worlds is 143 full re-renders, and serially that put this unit
# past the budget it was given. Each job writes ONLY paths suffixed with its own tag, so no two
# jobs touch a byte in common; every verdict below is read from those files in the foreground,
# where `bad` still counts. `wait` reaps each wave, so nothing is left running — a bare kill on a
# backgrounded subject leaks its grandchild, and this never kills one.
v_par() { # v_par <tag>...
  local t n=0
  for t in "$@"; do
    ( v_sig "$t" ) &
    n=$((n+1))
    if [ "$n" -ge 4 ]; then wait; n=0; fi
  done
  wait
}
v_sigstr()  { local t="$1" n out=""; for n in $V_WORLDS; do out="$out$n=$(cat "$VW/$n/score.$t" 2>/dev/null) "; done; printf '%s\n' "$out"; }
v_diffset() { # v_diffset <tag-a> <tag-b> — names of the worlds whose score differs
  local n out=""
  for n in $V_WORLDS; do
    cmp -s "$VW/$n/score.$1" "$VW/$n/score.$2" || out="$out$n "
  done
  printf '%s' "${out% }"
}
v_of() { cat "$VW/$1/score.$2" 2>/dev/null; }
# v_diag <world> <tag> — WHY a world's cell moved, printed only on a failing kill arm. A red run
# under the pre-push pool leaves nothing behind but this unit's captured output, which both
# runners copy WHOLE into .git/ai-dlc-fixture-failures; the scratch worlds are gone. A FAIL line
# naming one extra world cannot say whether that world took a real verdict or a sibling detector
# died under load (exit 128 renders DETECTOR-REFUSED and moves the cell), so the two cells and
# the difference between the two stderr captures are written here, bounded to 40 diff lines.
v_diag() {
  local w="$1" t="$2" a="$VW/$1/stderr.ship" b="$VW/$1/stderr.$2"
  printf '  DIAG  %s %s: ship=[%s] %s=[%s]\n' "$t" "$w" "$(v_of "$w" ship)" "$t" "$(v_of "$w" "$t")"
  if [ ! -f "$a" ] || [ ! -f "$b" ]; then
    printf '  DIAG  %s %s: stderr capture missing (ship:%s %s:%s)\n' "$t" "$w" \
      "$([ -f "$a" ] && echo present || echo ABSENT)" "$t" "$([ -f "$b" ] && echo present || echo ABSENT)"
  elif cmp -s "$a" "$b"; then
    printf '  DIAG  %s %s: stderr.ship and stderr.%s are byte-identical\n' "$t" "$w" "$t"
  else
    diff -u "$a" "$b" | awk -v p="  DIAG  $t $w | " 'NR <= 40 { print p $0 } END { if (NR > 40) print p "... (" NR - 40 " more diff lines cut)" }'
  fi
}

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

v_copy V-R && v_approve V-R "$THEIRS" || bad "FIXTURE BROKEN — could not build world V-R"
v_resolve V-R

# V-N: the same resolution PLUS an override whose base_sha resolves in neither repo, which
# layer-drift.sh renders as HARD-OVERRIDE-BASE-UNRESOLVABLE. A row the approval never saw is
# the state that must NEVER read as "the operator's own work", and it is the one property V-R
# lacks.
v_copy V-N && v_approve V-N "$THEIRS" || bad "FIXTURE BROKEN — could not build world V-N"
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

v_copy V-H && v_approve V-H "$THEIRS" || bad "FIXTURE BROKEN — could not build world V-H"
{ echo "# Reconcile report (fixture)"; echo; grep -v "$V_HARD" "$VW/V-H/region.md"; } > "$VW/V-H/approved.md"

v_copy V-HA && v_approve V-HA "$THEIRS" || bad "FIXTURE BROKEN — could not build world V-HA"
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
v_copy V-U && v_approve V-U "$THEIRS" || bad "FIXTURE BROKEN — could not build world V-U"
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
v_copy V-D && v_approve V-D "$THEIRS" || bad "FIXTURE BROKEN — could not build world V-D"
v_copy V-DR && v_approve V-DR "$THEIRS" || bad "FIXTURE BROKEN — could not build world V-DR"
v_resolve V-DR

# V-HC: THE HALF COPY. One blocker renders twice with different padding — `%-32s %s` in the
# blocking list and `STATUS  path` in its detector's section — and a difference taken over RAW
# lines reports the blocker GONE when only the padded copy is missing while the other still
# renders. The first HARD line in the region is the padded one, and only it is deleted here.
v_copy V-HC && v_approve V-HC "$THEIRS" || bad "FIXTURE BROKEN — could not build world V-HC"
awk -v p="^$V_HARD" '$0 ~ p && !d { d=1; next } { print }' "$VW/V-HC/region.md" > "$VW/V-HC/region-half.md"
{ echo "# Reconcile report (fixture)"; echo; cat "$VW/V-HC/region-half.md"; } > "$VW/V-HC/approved.md"

# V-HB: hard-blockers.sh REFUSES, so the blocking list renders DETECTOR-REFUSED instead of the
# padded copies. It is the wrapper the whole HARD- contract keys on, and its call was the one
# detector pipeline with no exit-code check.
v_copy V-HB && v_approve V-HB "$THEIRS" || bad "FIXTURE BROKEN — could not build world V-HB"

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

V_R_AFTER="$WORK/vp-vr-after.md"; v_render V-R > "$V_R_AFTER"
if ! grep -q "$V_HARD" "$VW/V-R/region.md"; then
  bad "FIXTURE BROKEN — V-R's APPROVED region carries no $V_HARD row, so there is no blocker for the resolution to remove"
elif ! grep -qF "$V_BASELINE" "$V_R_AFTER"; then
  bad "FIXTURE BROKEN — the render AFTER the resolution carries no baseline bucket row, so it is an empty or dead render and its missing HARD row proves nothing"
elif grep -q "$V_HARD" "$V_R_AFTER"; then
  bad "FIXTURE BROKEN — the resolution did NOT remove the $V_HARD row from a fresh render, so V-R is not the state it claims to be"
else
  ok "SP2 V-R's two sides differ in the way the arm needs: the approved region carries $V_HARD, the post-resolution render still carries the baseline bucket row and no longer carries the blocker"
fi

V_N_AFTER="$WORK/vp-vn-after.md"; v_render V-N > "$V_N_AFTER"
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

V_B_AFTER="$WORK/vp-vb-after.md"; v_render V-B > "$V_B_AFTER"
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
  V_S_AFTER="$WORK/vp-vs-after.md"; v_render V-S > "$V_S_AFTER"
  if ! grep -q '^_stamp_ ' "$V_S_AFTER"; then
    bad "FIXTURE BROKEN — moving the consumer's stamp rendered no _stamp_ line, so V-S's two sides do not differ on the stamp at all"
  elif grep -q "$V_HARD" "$V_S_AFTER"; then
    bad "FIXTURE BROKEN — V-S's post-move render still carries $V_HARD, so it is not testing 'resolved AND the stamp moved'"
  else
    ok "SP6 V-S's stamp move adds a _stamp_ line the approved region lacks AND its blocker is resolved — both, which is what makes the stamp's exclusion from the refs comparison observable"
  fi
fi

V_U_AFTER="$WORK/vp-vu-after.md"; v_render V-U > "$V_U_AFTER"
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

V_DEAD_DRIFT="$(v_stub "$EMIT" "$VMD/probe-dead-drift" unregistered-drift.sh)"
V_DEAD_HB="$(v_stub "$EMIT" "$VMD/probe-dead-hb" hard-blockers.sh)"
V_D_AFTER="$WORK/vp-vd-after.md"; v_render V-D "$V_DEAD_DRIFT" > "$V_D_AFTER"
V_D_ALIVE="$WORK/vp-vd-alive.md"; v_render V-D > "$V_D_ALIVE"
if cmp -s "$V_BASE_BYTES" "$VW/V-D/consumer/.claude/schemas/thing.json"; then
  bad "FIXTURE BROKEN — V-D's drift was resolved on disk, so its missing HARD row is a resolution and not a refusal, and it cannot discriminate the DETECTOR-REFUSED conjunct"
elif ! grep -qF 'DETECTOR-REFUSED  unregistered-drift.sh' "$V_D_AFTER"; then
  bad "FIXTURE BROKEN — the stubbed detector rendered no 'DETECTOR-REFUSED  unregistered-drift.sh' line, so V-D's fresh render is not the state it claims and the arm below cannot fire"
elif grep -qF 'DETECTOR-REFUSED  unregistered-drift.sh' "$V_D_ALIVE"; then
  bad "FIXTURE BROKEN — the UNMUTATED copy also renders DETECTOR-REFUSED for that detector, so the two sides do not differ and the stub is not what produced the line"
elif ! grep -q "$V_HARD" "$V_D_ALIVE"; then
  bad "FIXTURE BROKEN — the unmutated render of V-D's consumer carries no $V_HARD row, so the drift the refusal hides was never rendered and there is nothing for the refusal to conceal"
else
  ok "SP8 V-D's drift is STILL ON DISK and still renders as $V_HARD under a live detector, while the stubbed copy renders DETECTOR-REFUSED and no HARD row — the two sides differ, and they differ by the stub"
fi

# SP9: the half copy. The row must be REMOVED from the report, the SURVIVING copy must still be
# there, and the two must be the same row once whitespace is collapsed — otherwise V-HC is not a
# padding difference at all and E9 would be scored against something else.
v_hc_appr="$(grep -c "^$V_HARD" "$VW/V-HC/region-half.md")" || v_hc_appr=0
v_hc_full="$(grep -c "^$V_HARD" "$VW/V-HC/region.md")" || v_hc_full=0
v_hc_a="$(grep -m1 "^$V_HARD" "$VW/V-HC/region-half.md" | sed -E 's/[[:space:]]+/ /g')"
v_hc_b="$(grep -m1 "^$V_HARD" "$VW/V-HC/region.md" | sed -E 's/[[:space:]]+/ /g')"
if [ "$v_hc_full" -ne 2 ]; then
  bad "FIXTURE BROKEN — the region renders $v_hc_full copies of $V_HARD, not 2, so 'delete one copy' is not the state V-HC claims to build"
elif [ "$v_hc_appr" -ne 1 ]; then
  bad "FIXTURE BROKEN — V-HC's report carries $v_hc_appr copies of $V_HARD after the cut, not 1: either nothing was deleted or both copies were"
elif [ "$v_hc_a" != "$v_hc_b" ]; then
  bad "FIXTURE BROKEN — the deleted copy and the surviving copy are DIFFERENT rows once whitespace is collapsed ('$v_hc_b' vs '$v_hc_a'), so V-HC is not a padding difference and E9 would be scored against a real row"
else
  ok "SP9 V-HC deletes one of the region's two copies of the blocker and leaves the other, and the two are the same row once whitespace is collapsed — a padding difference and nothing else"
fi

# SP10: the refusing WRAPPER. The blocking list must go, the detector-section copy must stay —
# that surviving copy is precisely why normalisation alone already prevents the misread, and it
# is what makes E9 and E10 cover each other.
V_HB_AFTER="$WORK/vp-vhb-after.md"; v_render V-HB "$V_DEAD_HB" > "$V_HB_AFTER"
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

# --- STAGE THE MUTANTS, THEN SCORE EVERY PROGRAM ---------------------------------------------
# Each is a copy of the WHOLE reconcile directory: emit-report.sh resolves $SELF beside itself
# and shells to preclassify.sh, layer-drift.sh, ledger-reverify.sh and more, so a lone script
# copy dies before printing anything and "no cause" would score as a kill on every arm at once.
#
# KILL SETS ARE ASSERTED EXACTLY AND SOME OF THEM HAVE THREE MEMBERS. That is the arms
# OVERLAPPING rather than the mutants being wrong, and it is measured rather than assumed: V-R
# and V-U read exit 3, so every mutation of the resolved-cause BRANCH moves both.
# What separates those mutants is what they move BEYOND that set — E5 reaches V-HA, E1 does not —
# and the specific wrong verdict each world takes, asserted per world below.
V_APPLIED=""
v_mk() { # v_mk <name> <expected-anchor-hits> <anchor-regex> <sed-arg...>
  local n="$1" want="$2" anch="$3"; shift 3
  local d="$VMD/$n" hits ctl
  rm -rf "$d"; cp -R "$(dirname "$EMIT")" "$d" || return 1
  [ -f "$d/preclassify.sh" ] || { bad "$n did not stage its siblings — a copy missing preclassify.sh emits nothing and its silence would score as a kill"; return 1; }
  hits="$(grep -c -e "$anch" "$EMIT")" || hits=0
  ctl="$(grep -c -e 'ZZ-NO-SUCH-ANCHOR-IN-EMIT-REPORT-ZZ' "$EMIT")" || ctl=0
  if [ "$ctl" -ne 0 ]; then
    bad "$n the impossible-anchor control matched $ctl lines in emit-report.sh, so the uniqueness count below means nothing"; return 1
  fi
  if [ "$hits" -ne "$want" ]; then
    bad "$n's anchor matches $hits line(s) in emit-report.sh, not $want — the subject was respelled and this mutant edits something other than what it names. Re-anchor it; do NOT relax the assertion."; return 1
  fi
  if ! sed "$@" "$EMIT" > "$d/mutant-emit.sh"; then
    bad "$n DID NOT APPLY — sed failed, so no mutant exists and the arm it guards is unproven"; return 1
  fi
  if cmp -s "$EMIT" "$d/mutant-emit.sh"; then
    bad "$n DID NOT APPLY — the sed matched nothing, so the arm it guards is unproven"; return 1
  fi
  V_APPLIED="$V_APPLIED $n"
  return 0
}
V_ELIF='^elif \[ "$hard_gone" -gt 0 \] && \[ "$hard_new" -eq 0 \] && \[ "$refused_new" -eq 0 \]; then$'
# E9 swaps the whitespace-normalising, de-duplicating `norm_rows` for a bare sort on BOTH staged
# sides (the two `elif ! norm_rows < …` lines); it was anchored on `| norm_rows)` while the sides
# were `<( )` substitutions.
V_E9SED='s/^elif ! norm_rows < /elif ! LC_ALL=C sort < /'
V_E10SED='s/^  if \[ "$hb_rc" -eq 0 \]; then /  if true; then /'

v_mk E1 1 '^\[ "$cause" = BLOCKERS-RESOLVED \] && exit 3$' -e '/^\[ "$cause" = BLOCKERS-RESOLVED \] && exit 3$/d'
v_mk E2 1 '^if \[ "$refs_render" != "$refs_report" \]; then$' \
  -e 's/^if \[ "$refs_render" != "$refs_report" \]; then$/if [ 1 -eq 0 ]; then/'
v_mk E3 1 "$V_ELIF" \
  -e 's/^elif \[ "$hard_gone" -gt 0 \] && \[ "$hard_new" -eq 0 \] && \[ "$refused_new" -eq 0 \]; then$/elif [ "$hard_gone" -gt 0 ] \&\& [ "$refused_new" -eq 0 ]; then/'
v_mk E4 1 "$V_ELIF" \
  -e 's/^elif \[ "$hard_gone" -gt 0 \] && \[ "$hard_new" -eq 0 \] && \[ "$refused_new" -eq 0 \]; then$/elif [ -n "$only_report" ] \&\& [ "$hard_new" -eq 0 ] \&\& [ "$refused_new" -eq 0 ]; then/'
# E5 asks `find`, never a shell glob: the engine runs under `set -f`, so a glob stays a literal word,
# `ls` of it fails in every world, and V-HA (the one world that HAS such a file) never gains the
# diagnosis -- the mutant then moves only [V-R V-U] and the arm reads entangled for the wrong reason.
v_mk E5 1 "$V_ELIF" \
  -e 's|^elif \[ "$hard_gone" -gt 0 \] && \[ "$hard_new" -eq 0 \] && \[ "$refused_new" -eq 0 \]; then$|elif [ -n "$(find "$CONSUMER/_bmad-output/ai-dlc-update" -name '"'"'blocker-adjudication-*.md'"'"' 2>/dev/null)" ]; then|'
v_mk E6 1 '^elif \[ "$stamp_render" != "$stamp_report" \]; then$' \
  -e 's/^elif \[ "$stamp_render" != "$stamp_report" \]; then$/elif [ 1 -eq 0 ]; then/'
v_mk E7 1 "$V_ELIF" \
  -e 's/^elif \[ "$hard_gone" -gt 0 \] && \[ "$hard_new" -eq 0 \] && \[ "$refused_new" -eq 0 \]; then$/elif [ "$hard_gone" -gt 0 ] \&\& [ "$hard_new" -eq 0 ]; then/'
v_mk E8 1 "^unseen_rows() { grep -Ev '" -e "s|^unseen_rows() { grep -Ev '.*\$|unseen_rows() { grep -Ev '^HARD-\|^\$'; }|"
v_mk E9  2 '^elif ! norm_rows < ' -e "$V_E9SED"
v_mk E10 1 '^  if \[ "$hb_rc" -eq 0 \]; then ' -e "$V_E10SED"
v_mk E11 2 '^elif ! norm_rows < ' -e "$V_E9SED" -e "$V_E10SED"

rm -rf "$VMD/ctl"; cp -R "$(dirname "$EMIT")" "$VMD/ctl"
v_par ship ctl $V_APPLIED
v_score "$V_DEAD_DRIFT" "$V_CONTROL_WORLD" ship > "$VW/$V_CONTROL_WORLD/score.ship"
# The foreground half of R6's scoring guard: a cell whose fresh render refused on every attempt.
v_broken_scan() {
  local n t b
  for n in $V_WORLDS $V_CONTROL_WORLD; do
    for t in ship ctl $V_APPLIED; do
      b="$VW/$n/broken.$t"
      [ -f "$b" ] && bad "FIXTURE BROKEN — $n scoring under $t rendered DETECTOR-REFUSED on $V_TRIES attempts: $(cat "$b")"
    done
  done
  return 0
}
v_broken_scan
V_SHIP="$(v_sigstr ship)"
V_CTL="$(v_sigstr ctl)"

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
#   case      stamp            BASE     want   the wrong fix it alone (or first) separates
#   SHORT     short(b)         b        none   W6 (case fold on raw strings)
#   FULL-SB   b                short(b) none   W1 (prefix match), W2 (stamp resolved, BASE not)
#   UPPER     SHORT(B) upper   b        none   W8 (BASE resolved, stamp prefix-matched)
#   TAG       short(b)         sb-vb    none   W4 (no ^{commit} peel)
#   DOCS      t                dc       row    W7 (core/ trees compared)
#   DIRTY     short(b)-dirty   b        row    W3 (an unresolvable stamp renders nothing)
#   OTHER     short(t)         b        row    CONTROL: the row renders at all (W5 deletes it)
#   EQUAL     b                b        none   CONTROL: string-equal is settled without git
#   NOBASE    short(b)         nb       row    W9 (an unresolvable BASE acquits the stamp)
#
# nb is a 40-hex sha no object in the SB dist carries, asserted absent before any cell is read.
#
# EVERY CELL MUST PROVE IT RENDERED. A program that emits nothing reads `none` on five of the
# nine cases, so a cell whose reconcile-mechanical region is absent or TRUNCATED -- BEGIN with no
# END -- is BROKEN, never `none`. Cells are
# computed in background jobs that write files; every verdict is read in the foreground.
if rer_phase sb; then
SB="$WORK/stamp-base"; mkdir -p "$SB/d/core" "$SB/mut" "$SB/c"
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
sb_emit_of() { case "$1" in ship) printf '%s\n' "$EMIT" ;; *) printf '%s\n' "$SB/mut/$1/mutant-emit.sh" ;; esac; }
sb_sig() { local t="$1" e c; e="$(sb_emit_of "$t")"; for c in $SB_CASES; do sb_cell "$e" "$c" "$t" > "$SB/cell.$t.$c"; done; }
sb_of() { cat "$SB/cell.$2.$1" 2>/dev/null; }
sb_sigstr() { local c out=""; for c in $SB_CASES; do out="$out$c=$(sb_of "$c" "$1") "; done; printf '%s' "${out% }"; }

# THE MUTANTS. Each is a copy of the WHOLE reconcile directory (emit-report.sh shells to siblings
# beside itself) with mutant-emit.sh beside them. Anchored on an EXACT line of the fix — the line
# must occur exactly once, and an impossible line must occur zero times — and replaced through
# awk's ENVIRON, so the `&&`, `|` and `/` the replacements carry are never re-read as syntax.
# Every mutant that swaps the decision rewrites the line that RENDERS, and its replacement reads
# nothing the fix computed: a partial revert would prove the layer it left in.
SB_APPLIED=""
sb_count() { SB_O="$2" awk '$0 == ENVIRON["SB_O"] { n++ } END { print n+0 }' "$1"; }
sb_mk() { # sb_mk <name> <exact-old-line> <new-line> [<exact-old-line> <new-line>]...
  local n="$1" d="$SB/mut/$1" hits; shift
  cp -R "$(dirname "$EMIT")" "$d" && cp "$EMIT" "$d/mutant-emit.sh" || { bad "FIXTURE BROKEN — $n could not copy the reconcile directory"; return 1; }
  [ -f "$d/preclassify.sh" ] || { bad "$n did not stage its siblings — a copy missing preclassify.sh emits nothing and its silence would score as a kill"; return 1; }
  hits="$(sb_count "$EMIT" 'ZZ-NO-SUCH-LINE-IN-EMIT-REPORT-ZZ')"
  [ "$hits" = 0 ] || { bad "$n the impossible-line control matched $hits lines in emit-report.sh, so the anchor count below means nothing"; return 1; }
  while [ "$#" -ge 2 ]; do
    hits="$(sb_count "$d/mutant-emit.sh" "$1")"
    if [ "$hits" != 1 ]; then
      bad "$n's anchor matches $hits line(s) in emit-report.sh, not 1 — the fix was respelled and this mutant edits something other than what it names. Re-anchor it; do NOT relax the assertion. Anchor: $1"; return 1
    fi
    SB_O="$1" SB_N="$2" awk '$0 == ENVIRON["SB_O"] { print ENVIRON["SB_N"]; next } { print }' "$d/mutant-emit.sh" > "$d/mutant-emit.next" \
      && mv "$d/mutant-emit.next" "$d/mutant-emit.sh" || { bad "$n DID NOT APPLY — awk failed, so no mutant exists and the arm it guards is unproven"; return 1; }
    shift 2
  done
  [ "$#" -eq 0 ] || { bad "FIXTURE BROKEN — $n was given an odd number of line arguments"; return 1; }
  if cmp -s "$EMIT" "$d/mutant-emit.sh"; then bad "$n DID NOT APPLY — the edit changed nothing, so the arm it guards is unproven"; return 1; fi
  SB_APPLIED="$SB_APPLIED $n"
}
SB_L_RENDER='    if [ "$_stamp_moved" -eq 1 ]; then'
SB_L_STAMPRP='      _stamp_obj="$(git -C "$DIST" rev-parse -q --verify "${_rendered_base}^{commit}" 2>/dev/null)" || _stamp_obj=""'
SB_L_BASERP='        _base_obj="$(git -C "$DIST" rev-parse -q --verify "${BASE}^{commit}" 2>/dev/null)" || _base_obj=""'
SB_L_CMP='        [ "$_stamp_obj" = "$_base_obj" ] || _stamp_moved=1'
SB_L_UNRES='        _stamp_moved=1'
mkdir -p "$SB/mut/ctl" && cp -R "$(dirname "$EMIT")/." "$SB/mut/ctl/" && cp "$EMIT" "$SB/mut/ctl/mutant-emit.sh" || bad "FIXTURE BROKEN — could not stage the SB control copy"
sb_mk W1 "$SB_L_RENDER" '    if [ -n "$_rendered_base" ] && case "$BASE" in "$_rendered_base"*) false ;; *) true ;; esac; then'
sb_mk W2 "$SB_L_CMP" '        [ "$_stamp_obj" = "$BASE" ] || _stamp_moved=1'
sb_mk W3 "$SB_L_UNRES" '        _stamp_moved=0'
sb_mk W4 "$SB_L_STAMPRP" '      _stamp_obj="$(git -C "$DIST" rev-parse -q --verify "${_rendered_base}" 2>/dev/null)" || _stamp_obj=""' \
         "$SB_L_BASERP"  '        _base_obj="$(git -C "$DIST" rev-parse -q --verify "${BASE}" 2>/dev/null)" || _base_obj=""'
sb_mk W5 "$SB_L_RENDER" '    if false; then'
sb_mk W6 "$SB_L_RENDER" '    if [ -n "$_rendered_base" ] && [ "$(printf %s "$_rendered_base" | tr ABCDEF abcdef)" != "$(printf %s "$BASE" | tr ABCDEF abcdef)" ]; then'
sb_mk W7 "$SB_L_RENDER" '    _rb_t="$(git -C "$DIST" rev-parse -q --verify "${_rendered_base}^{commit}:core" 2>/dev/null)" || _rb_t=""; _b_t="$(git -C "$DIST" rev-parse -q --verify "${BASE}^{commit}:core" 2>/dev/null)" || _b_t=""; if [ -n "$_rendered_base" ] && { [ -z "$_rb_t" ] || [ "$_rb_t" != "$_b_t" ]; }; then'
sb_mk W8 "$SB_L_RENDER" '    _b_c="$(git -C "$DIST" rev-parse -q --verify "${BASE}^{commit}" 2>/dev/null)" || _b_c=""; if [ -n "$_rendered_base" ] && case "$_b_c" in "$_rendered_base"*) false ;; *) true ;; esac; then'
sb_mk W9 "$SB_L_CMP" '        [ -z "$_base_obj" ] || [ "$_stamp_obj" = "$_base_obj" ] || _stamp_moved=1'

if [ -z "$SB_PRE" ]; then
  _sb_n=0
  for _sb_t in ship ctl $SB_APPLIED; do
    ( sb_sig "$_sb_t" ) &
    _sb_n=$((_sb_n+1)); if [ "$_sb_n" -ge 5 ]; then wait; _sb_n=0; fi
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
  SB_SHIP="$(sb_sigstr ship)"; SB_CTL="$(sb_sigstr ctl)"
  if [ "$SB_CTL" = "$SB_SHIP" ] && [ "$(sb_of OTHER ctl)" = row ] && [ "$(sb_of SHORT ctl)" = none ]; then
    ok "SB-CONTROL an unmutated copy of the reconcile directory reproduces every SB cell, including OTHER's row and SHORT's none, so a mutant's moved cell is the mutation and not the copy"
  else
    bad "SB-CONTROL the unmutated copy did not reproduce the shipped SB cells — every SB mutant verdict is unreadable. shipped: $SB_SHIP / copy: $SB_CTL"
  fi
  # sb_kill <name> <exact set of cases it must move> <what that set means>
  sb_kill() {
    local n="$1" want="$2" why="$3" c got="" brk=""
    case " $SB_APPLIED " in *" $n "*) : ;; *) return 0 ;; esac
    for c in $SB_CASES; do
      [ "$(sb_of "$c" "$n")" = BROKEN ] && brk="$brk$c "
      [ "$(sb_of "$c" "$n")" = "$(sb_of "$c" ship)" ] || got="$got$c "
    done
    got="${got% }"
    if [ -n "$brk" ]; then
      bad "FIXTURE BROKEN — $n rendered no region on [${brk% }], so its moved cells are a copy that died and not a verdict"
    elif [ "$got" = "$want" ]; then
      ok "$n KILLED by SB-$(printf '%s' "$want" | sed 's/ /, SB-/g'): $why"
    else
      bad "$n moved the SB cells [${got:-none}] and had to move exactly [$want] — $([ -z "$got" ] && echo 'MUTANT SURVIVED: no SB arm depends on the code it changed' || echo 'the arms are entangled, or the case meant to own this mutant does not')"
    fi
  }
  sb_kill W1 "FULL-SB UPPER TAG" "a prefix match acquits only a stamp that is a literal prefix of the BASE string, so a full stamp against a short BASE, an upper-case stamp and a tag BASE all render a false row"
  sb_kill W2 "FULL-SB TAG" "resolving the stamp and comparing it to the BASE STRING fails whenever BASE is not already a full sha — a short BASE or a tag"
  sb_kill W3 "DIRTY" "an unresolvable stamp rendering nothing hides a -dirty stamp, which records no base this render can confirm"
  sb_kill W4 "TAG" "without the ^{commit} peel an annotated-tag BASE resolves to the TAG object, which is never the stamp's commit"
  sb_kill W5 "DOCS DIRTY OTHER NOBASE" "the row deleted: every case that must render it goes quiet, including the plain different-commit control"
  sb_kill W6 "SHORT FULL-SB UPPER TAG" "a case fold on the raw strings still compares an abbreviation to a full sha as text — SHORT is the case the defect was filed on"
  sb_kill W7 "DOCS" "comparing core/ trees acquits a docs-only commit, which shares t's core/ tree and is still a different base"
  sb_kill W8 "UPPER" "resolving BASE and prefix-matching the stamp is case-sensitive against a lower-case sha, so an upper-case abbreviation of the base renders a false row"
  sb_kill W9 "NOBASE" "an unresolvable BASE acquitting the stamp hides a range rendered from a base nothing in DIST names, so no commit is the stamp's commit and the row must still render"
  _sb_n=0; for _sb_t in $SB_APPLIED; do _sb_n=$((_sb_n+1)); done
  if [ "$_sb_n" -eq 9 ]; then
    ok "SB all 9 stamp-comparison mutants (W1-W9) were built and applied (cmp -s) and scored"
  else
    bad "SB only $_sb_n of 9 stamp-comparison mutants applied ([${SB_APPLIED# }]) — each missing one leaves a wrong fix nothing here can reject"
  fi
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

# --- THE KILL SETS --------------------------------------------------------------------------
# v_kill <name> <expected-kill-set> <world:expected-score> ...
v_kill() {
  local n="$1" want="$2"; shift 2
  local got spec w exp act allok=1
  case " $V_APPLIED " in *" $n "*) : ;; *) return 1 ;; esac
  got="$(v_diffset ship "$n")"
  if [ "$got" != "$want" ]; then
    bad "$n moved the worlds [${got:-none}] and had to move exactly [$want] — a mutant that fails more than its own arms means two of them are entangled, and one that fails fewer means the arm it guards is carried by something else"
    for w in $got; do case " $want " in *" $w "*) : ;; *) v_diag "$w" "$n" ;; esac; done
    for w in $want; do case " $got " in *" $w "*) : ;; *) v_diag "$w" "$n" ;; esac; done
    allok=0
  fi
  for spec in "$@"; do
    w="${spec%%:*}"; exp="${spec#*:}"; act="$(v_of "$w" "$n")"
    if [ "$act" != "$exp" ]; then
      bad "$n on $w scored $act, not the specific wrong verdict $exp — the cell moved for some reason other than the one this mutation names, so the kill is unattributed"
      v_diag "$w" "$n"
      allok=0
    fi
  done
  [ "$allok" = 1 ]
}

if [ "$V_CTL" = "$V_SHIP" ] && [ "$(v_of V-R ctl)" = "3|BLOCKERS-RESOLVED|1|1|0|0" ]; then
  ok "CONTROL(V) an unmutated copy in a fresh directory reproduces every verdict INCLUDING the positive one (V-R exits 3 and names its row), so a mutant's changed cell is the mutation and not the copy — and the two were computed in different parallel slots, so it is also the arm that would catch the scoring racing with itself"
else
  bad "CONTROL(V) the unmutated copy did not reproduce the shipped verdicts — every mutant below is unreadable. shipped: $V_SHIP / copy: $V_CTL"
fi

# E1: the classification deleted — the program as it stood before this change, which reported the
# mismatch and exited 1 for every cause. Moves every world that reads 3 and nothing else.
v_kill E1 "V-R V-U" "V-R:1|BLOCKERS-RESOLVED|1|1|0|0" \
  && ok "E1 (exit 3 deleted): the two worlds that read 3 go red and no other — the resolved-blocker case falls back to the undifferentiated refusal and apply.sh cannot tell it from a hand-edit"

# E2: the refs comparison disarmed. A moved upstream must be decided FIRST, because it makes every
# other line incomparable. Now that `_stamp_` has left the comparison, V-M is the only world whose
# refs lines differ — which is what E6 exists to keep honest in the other direction.
v_kill E2 "V-M" \
  && ok "E2 (refs check disarmed): V-M alone goes red — a MOVED upstream is diagnosed from HARD rows that describe another tree"

# E3: the `hard_new` conjunct dropped — the count-based wrong fix, "resolved whenever HARD rows
# vanished". V-N is the only seed that carries the property it drops.
v_kill E3 "V-N" "V-N:3|BLOCKERS-RESOLVED|1|1|0|0" \
  && ok "E3 (hard_new conjunct dropped): V-N alone goes red — a blocker resolved beside a NEW one is acquitted as the operator's own work"

# E4: the HARD- keying dropped while the rest of the shape is kept — exit 3 whenever the region
# carries rows the render lacks. V-B is the only seed whose resolution is not a blocker.
v_kill E4 "V-B" \
  && ok "E4 (HARD- keying dropped): V-B alone goes red — a non-HARD row that stopped rendering is reported as a resolved blocker"

# E5: the cause decided from a FILE the consumer can create rather than from the two regions.
# Killed in BOTH directions deliberately: the worlds with no such file lose their diagnosis and
# V-HA, which has one, gains it. A one-directional arm cannot tell a correctly-keyed decision from
# one that reads the wrong input.
v_kill E5 "V-R V-HA V-U" "V-R:1|UNDECIDED|0|0|0|0" \
  && ok "E5 (cause read off a consumer file): BOTH directions go red — every world with no such file loses its diagnosis and the hand-dropped one that has a file gains it, which a single-direction arm could not separate"

# E6: the STAMP-MOVED branch removed, so the stamp falls through to the resolved cause. V-S is
# the only world whose stamp moved; V-M must stay put, or the mutant is moving the refs arm
# generally rather than the stamp branch that sits between the other two.
v_kill E6 "V-S" "V-S:3|BLOCKERS-RESOLVED|1|1|0|0" \
  && ok "E6 (the STAMP-MOVED branch removed): V-S alone goes red and V-M does not — a tree whose recorded position moved under the report is diagnosed as blockers the operator resolved, and the remedy offered is to re-approve and apply a range the stamp says is already applied"

# E7: the `refused_new` conjunct dropped. A detector that refused leaves exactly the row absence
# (c) keys on.
v_kill E7 "V-D" "V-D:3|BLOCKERS-RESOLVED|1|1|0|0" \
  && ok "E7 (DETECTOR-REFUSED conjunct dropped): V-D alone goes red — a refusing detector is reported as a blocker the operator resolved, by name, over a drift still on disk"

# E8: `unseen_rows()` reduced to "everything that is not HARD and not blank". The count is what
# separates a plain resolution from one carrying a row the approval never saw, and boilerplate is
# what destroys it: a resolution replaces a HARD row with `none` or `0 HARD blockers.`, so the
# plain case counts those and reads exactly like the carrying one.
v_kill E8 "V-R V-U" \
  && ok "E8 (unseen_rows reduced to non-HARD): the plain resolution's unseen count stops being zero — the count no longer separates a resolution that hid nothing from one that hid a finding, and the VERDICT does not move at all"

# E9/E10/E11: TWO GUARDS THAT COVER EACH OTHER, AND THE ARM THAT SAYS SO.
#
# MEASURED, not reasoned: with the normalisation in place a dead wrapper leaves the blocker's
# detector-section copy rendering, so nothing is gone and the refusal never has to block anything;
# with the refusal in place a raw difference is blocked before it can misread the padded copy.
# Each alone therefore changes NO verdict, which is the silent shape — zero failures rather than
# two — and each is given a subject the other cannot see: E9 makes V-HC count a HARD row as new
# when both sides carry it, E10 makes V-HB stop counting the refusal. E11 applies both and is the
# only one that reaches the defect itself, on V-HB: a wrapper that did not run, reported as a
# blocker the operator resolved, over a drift still on disk.
# E9's KILL SET IS SEVEN WORLDS AND THAT IS THE MUTATION'S REACH, NOT AN ENTANGLEMENT. The
# normalisation is a property of the COMPARISON, so removing it perturbs the counts of every world
# whose two sides differ by padding anywhere — measured, seven of eleven. What E9 OWNS is V-HC,
# the only world built so that a blocker's two copies differ by padding alone, and the arm asserts
# that cell exactly. The second conjunct is the load-bearing half: no VERDICT moves anywhere, so
# without the counts in the cell this mutant would come back green.
if v_kill E9 "V-R V-N V-H V-HA V-S V-U V-HC" "V-HC:1|UNDECIDED|0|1|0|0"; then
  case "$(v_of V-R E9)" in
    "3|BLOCKERS-RESOLVED|"*) ok "E9 (normalised AFTER the difference): V-HC counts a HARD row as new when both sides carry it, and no verdict moves anywhere — V-R still reads 3 — so the counts are the only record that the guard is gone" ;;
    *) bad "E9 flipped V-R's verdict as well as the counts ($(v_of V-R E9)) — the mutation is not confined to the counting and its attribution to V-HC is unearned" ;;
  esac
fi

v_kill E10 "V-HB" "V-HB:1|UNDECIDED|0|0|0|0" \
  && ok "E10 (the wrapper's REFUSED arm removed): V-HB alone goes red — the refusal stops being counted, and with the normalisation still in place the verdict does not move, so nothing but this cell records that the guard is gone"

# E11 reaches what neither alone can: V-HB's VERDICT, not its counts.
if v_kill E11 "V-R V-N V-H V-HA V-S V-U V-HC V-HB" "V-HB:3|BLOCKERS-RESOLVED|1|1|0|0" "V-HC:1|UNDECIDED|0|1|0|0"; then
  ok "E11 (both guards removed together): V-HB reads BLOCKERS-RESOLVED — a wrapper that did not run is named as the operator's own resolution over a drift still on disk, which is the defect the pair exists to prevent and which neither mutant alone can reach"
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
# =========================================================================================
# MUTANTS FOR THE WORLD GUARDS
#
# W1-W7 are guard-shaped, and three of the six probe arms are ABSENCE-shaped — they assert
# that a guard did NOT fire. Those pass against a `broken` that can never be reached, so the
# probe alone establishes that the guards discriminate between two inputs and only a mutant
# establishes that they discriminate at all.
#
# THE SUBJECT IS THIS FILE, which is what makes these different from every other battery
# here: `DGW`, `world_moved` and `broken` are defined in `run.sh` itself. So each mutant is a
# copy of THIS SCRIPT with one helper edited, re-run end to end, and scored on whether its
# own W-arms went red. A copy is re-run with `--world-guard-probe-only` so the mutants cost
# the probe rather than the whole unit; the flag is handled at the top of the file.
#
# KEYED ON THE HELPERS' BODIES, never on a message string. The verdict text is what an
# operator reads and it will be reworded; the `if` that decides is the property under test.
# =========================================================================================
if rer_phase wg; then
echo ""
echo "  --- world-guard mutants ---"

WG_SELF="$HERE/run.sh"
WGN=0
WG_MUT=""
# SETS A GLOBAL AND PRINTS NOTHING, for the reason `bad` writes to stdout: a builder called
# inside `$( )` folds its own refusal into the captured value, the caller reads a non-empty
# string as a built mutant, and running it produces nothing — which an absence-shaped arm
# scores as MUTANT SURVIVED. FIXTURE STALE and MUTANT SURVIVED prescribe opposite repairs.
#
# THE COPY IS A TREE, NOT A FILE, AND A PARTIAL ONE MAKES EVERY MUTANT SURVIVE. This script's
# line 2 sources `../lib/preamble.sh`; a copy without it dies before its first assertion,
# reports nothing, and every "expected at least 1 failure" arm reads that silence as MUTANT
# SURVIVED. MEASURED exactly that way on the first cut: all six scored SURVIVED against an
# untouched subject, which reads precisely like a change that does not work. The usual
# control could not see it, because the control runs the REAL file in the REAL tree and passed.
#
# So the copy is rooted at `<d>/core/fixtures/<name>/` with `lib/preamble.sh` beside it, and
# that copy is guarded. NOTHING ELSE IS NEEDED, BECAUSE PROBE-ONLY MODE NEVER RUNS `seed.sh` --
# the only reader of the distribution's `core/skills` -- and exits at the probe's own verdict.
# MEASURED: an unmutated copy with `core/skills` linked and one with no `core/skills` at all
# print byte-identical probe output (rc 0, 13 ok lines, 0 verdict failures). `skills/` was
# linked here once, and on an installed consumer (this file at `tests/fixtures/<name>/`) its
# `cd "$HERE/../../skills"` failed once per mutant, `ln -s ""` exited 0, and the refusal
# beside it could never fire -- a guard with no subject, over a link nothing read. Do not
# re-add it. If probe mode ever starts seeding, a skills-less copy prints `FIXTURE ERROR:
# emit-report.sh not found in either layout` (measured, rc 2), and `wg_score` below refuses
# that as MUTANT HARNESS BROKEN before any mutant verdict is read.
# `seed.sh` and `README.md` are copied only so the copy tree matches the fixture's shape.
wgmut() { # wgmut <name> <sed-arg>... -> sets WG_MUT
  local name="$1"; shift
  local r="$WORK/wg-$name" d
  d="$r/core/fixtures/reconcile-emit-report"
  WG_MUT=""
  rm -rf "$r"; mkdir -p "$d" "$r/core/fixtures/lib"
  cp "$HERE/../lib/preamble.sh" "$r/core/fixtures/lib/" 2>/dev/null \
    || { bad "MUTANT HARNESS BROKEN [$name]: could not copy the fixture preamble; the copy would die on line 2 and its silence would score as a kill"; return 1; }
  cp "$HERE/seed.sh" "$d/seed.sh" 2>/dev/null || true
  cp "$HERE/README.md" "$d/README.md" 2>/dev/null || true
  sed "$@" "$WG_SELF" > "$d/run.sh" || { bad "MUTANT DID NOT APPLY [$name]: sed exited non-zero"; return 1; }
  if cmp -s "$WG_SELF" "$d/run.sh"; then
    bad "FIXTURE STALE [$name]: the mutation matched nothing in this file's own world guards. The helper was reworded — re-anchor on the same observable, never relax the assertion"
    return 1
  fi
  if ! bash -n "$d/run.sh" 2>/dev/null; then
    bad "FIXTURE STALE [$name]: the mutant does not parse, so a kill would be a syntax error rather than a disarmed guard"
    return 1
  fi
  WG_MUT="$d/run.sh"
  return 0
}
# Each mutant is scored on the PROBE's own output. `wg_probe` runs the copy in probe-only
# mode and prints the count of failed W-arms.
#
# A COPY THAT REFUSED AT STARTUP IS NOT A MUTANT VERDICT, AND THE ARM SAYS SO SEPARATELY.
# `FIXTURE ERROR` / `FIXTURE BROKEN` before the first assertion produces zero `FAIL` lines,
# which every "expected at least N" arm below would read as MUTANT SURVIVED. The output is
# captured once and inspected for that state before any count is taken.
wg_out() { AI_DLC_RER_PROBE_ONLY=1 bash "$1" 2>&1; }
# THE METRIC IS THE PROBE'S OWN VERDICT ARMS, NOT EVERY `FAIL` LINE, and the difference is
# not cosmetic. W1-W7 work by PROVOKING refusals: each seeds a broken world, lets `broken`
# fire, and then asserts the refusal happened. So a correct run prints five `FAIL  FIXTURE
# BROKEN` lines by design, and counting them scored the UNMUTATED control at 5 -- reported as
# "measured against a broken baseline" when the baseline was right and the ruler was wrong.
# `wp_want` is the only thing that speaks for a probe arm, and it prints `  FAIL  ` followed
# by a message ending in the `(refusals=N want=M, rc=X want=Y)` suffix it alone emits.
wg_verdict_fails() { grep -c '^  FAIL  .*(refusals=' <<<"$1"; }
wg_score() { # wg_score <name> <min-expected-fails> <killmsg>
  local o n; o="$(wg_out "$WG_MUT")"
  if grep -q 'FIXTURE ERROR' <<<"$o"; then
    bad "MUTANT HARNESS BROKEN [$1]: the copy refused at startup (FIXTURE ERROR) and never reached an assertion. Its zero failures are a copy that did not run, not a mutation that survived — check the copy tree carries lib/preamble.sh"
    return
  fi
  n="$(wg_verdict_fails "$o")" || n=0
  if [ "${n:-0}" -ge "$2" ]; then
    ok "  mutant [$1] KILLED ($n W-arm failure(s)) by $3"
  else
    bad "MUTANT SURVIVED [$1]: the world-guard probe reported ${n:-0} failure(s), expected at least $2 — $3 does not depend on the mutated code, so those arms prove nothing"
  fi
}
# THE UNMUTATED CONTROL, run through the SAME probe-only path. Without it every count above
# is read against an assumption; a copy that dies at startup reports 0 failures and every
# "expected at least N" arm would correctly fail, but a copy that dies AFTER the probe would
# not — and the control is what separates the two.
# COUNTED THE SAME WAY THE MUTANTS ARE, which is the whole point of a baseline. Counting
# every `FAIL` line scored this control at 5 on a correct tree: the probe arms WORK by
# provoking `broken`, so five `FAIL  FIXTURE BROKEN` lines are what a passing run looks like.
# The control then reported "measured against a broken baseline" while the baseline was fine
# and the ruler was wrong -- a control that disagrees with the thing it controls for.
_wg_ctl="$(wg_verdict_fails "$(wg_out "$WG_SELF")")" || _wg_ctl=0
if [ "${_wg_ctl:-1}" -eq 0 ]; then
  ok "  control [unmutated]: this file's own world-guard probe reports 0 failures in probe-only mode"
else
  bad "MUTANT HARNESS BROKEN: the UNMUTATED copy reports ${_wg_ctl} world-guard failure(s) in probe-only mode. Every mutant count below is measured against a broken baseline, and two inert runs compare equal"
fi

# WM1 — DGW STOPS REFUSING: the failure branch returns 0 without reporting, so the helper is
#       a rename of DG. Killed by W1 and W3a.
# THE DELIMITER IS `|`, NEVER `@`, AND THAT IS A MEASURED REPAIR RATHER THAN A PREFERENCE.
# Every anchor in this battery runs through `DGW`'s own condition line, which carries the
# fixture's git identity `user.email=f@f` — so an `s@...@...@` expression terminates inside
# its own pattern. The `sed` then matched nothing, `cmp -s` correctly refused the no-op, and
# three of six mutants reported FIXTURE STALE on a subject that had not moved at all.
if wgmut wm1-dgw-never-refuses \
     -e 's|^    broken "\$_what failed in the scratch dist|    return 0 # refusal removed: "$_what failed in the scratch dist|'; then
  wg_score wm1 1 "W1/W3a: a git mutation that ERRORED is no longer refused, so every world below is built by a helper that swallows its own failures"
  WGN=$((WGN+1))
fi

# WM2 — DGW REFUSES UNCONDITIONALLY. The mirror, and the direction that looks finished: a
#       guard that fires on everything is indistinguishable from one that discriminates
#       unless something asserts the quiet case. Killed by W2 and W3b.
# The negation is dropped, so DGW refuses exactly the mutations that SUCCEEDED — the
# inversion, which is the sharpest form of "fires unconditionally" that still parses.
if wgmut wm2-dgw-always-refuses \
     -e 's|^  if ! git -C "\$DIST" -c user\.email|  if git -C "$DIST" -c user.email|'; then
  wg_score wm2 1 "W2/W3b: DGW now refuses a mutation that SUCCEEDED, so its refusals carry no information"
  WGN=$((WGN+1))
fi

# WM3 — world_moved STOPS COMPARING: the did-not-move branch is dead, so the helper answers
#       only "does this ref resolve". Killed by W4 — which is the case DGW is blind to, so
#       with this mutant alive a no-op checkout passes BOTH guards.
if wgmut wm3-world-moved-never-compares \
     -e 's@^  if \[ "\$_got" = "\$3" \]; then@  if false; then@'; then
  wg_score wm3 1 "W4: a ref still at the sha captured before the mutation is accepted, so the world under test is the world before it"
  WGN=$((WGN+1))
fi

# WM4 — THE `-z` BRANCH IS DISABLED, so a ref resolving to NOTHING compares unequal to any
#       sha and reads as a world that MOVED — the guard passing precisely where the
#       construction failed hardest. Killed by W6b.
#
#       W6b RATHER THAN W6, AND THE DIFFERENCE IS MEASURED. `rev-parse` of a ref that does
#       not EXIST prints the name back rather than empty, so that input never reaches this
#       branch; W6 asserts that measured behaviour and names it as the known gap. The branch
#       does have a subject — an empty ref argument — and W6b is it. Keyed here the mutant
#       dies; keyed on the missing-ref input it would survive, and the survival would read as
#       "the -z branch is not load-bearing, delete it", which is the direction that removes a
#       correct guard.
if wgmut wm4-empty-reads-as-moved \
     -e 's@^  if \[ -z "\$_got" \]; then@  if false; then@'; then
  wg_score wm4 1 "W6b: a ref resolving to nothing compares unequal to any sha and is read as a world that moved"
  WGN=$((WGN+1))
fi

# WM6 — world_at STOPS COMPARING: it answers only "do both refs resolve", never "is HEAD
#       there". Killed by W7. This is the helper the tip added for the two `reset --hard`
#       sites, and no other mutant reaches it — WM1/WM2 are DGW's, WM3/WM4 are world_moved's.
if wgmut wm6-world-at-never-compares \
     -e 's@^  if \[ "\$_head" != "\$_want" \]; then@  if false; then@'; then
  wg_score wm6 1 "W7: a reset that left HEAD somewhere else is accepted, so the two reset sites have nothing but exit status — which cannot answer a no-op reset"
  WGN=$((WGN+1))
fi

# WM5 — `broken` STOPS FAILING THE UNIT: it prints and leaves `fails` alone. This is the
#       quietest regression of the four and the one a reader would not see: every world
#       refusal still appears in the log and the unit goes green over it. Killed by every
#       positive W-arm at once, because the probe counts refusals by watching `fails`.
#       ANCHORED ON THE TALLY INCREMENT ALONE, not on the whole definition: the message text
#       is what an operator reads and it will be reworded, while `fails=$((fails+1))` is the
#       property under test.
if wgmut wm5-broken-does-not-fail \
     -e 's|^broken() \(.*\)fails=\$((fails+1)); }$|broken() \1: ; }|'; then
  wg_score wm5 1 "the positive W-arms: a world refusal prints and no longer fails the unit, so the log says FIXTURE BROKEN and the cell reads green"
  WGN=$((WGN+1))
fi

if [ "$WGN" -eq 6 ]; then
  ok "  all 6 world-guard mutants were built, applied (cmp -s) and scored"
else
  bad "only $WGN of 6 world-guard mutants were scored — a mutation that never became a mutant leaves its arm unproven and this fixture would report PASS over it"
fi
fi # end rer_phase wg

# --- BL-679: --verify ACCEPTS A RECORDED PASS, AND EVERY INPUT THE RENDER READS STILL MISSES IT ---
# A pull ran `--verify` three or four times on one tree, each a full detector re-render. The engine
# now records an exit-0 `--verify` in the consumer's GIT-DIR (`ai-dlc-verify-pass`) keyed on every
# render input, and a matching record is accepted without rendering. The cache is a SAFETY GATE's
# cache: apply.sh writes on its 0. So every arm here is a MISS the cache must take, each one property
# away from a HIT its own control establishes in the same world immediately before.
#
# HIT vs FRESH is decided by the pinned prefix `emit-report: accepted a recorded PASS (` AND by a PATH
# shim: a `bash` first on PATH counts every detector the render launches (the key computation launches
# none through PATH: its one subprocess, ledger-reverify.sh --receipt-tokens for the receipts field,
# runs as "$BASH"),
# into a file named by PCV_COUNT -- never an AI_DLC_* name, which the runner scrubs, and never a
# file under the engine directory, which the engine key hashes. A hit is the exact two-line stdout,
# exit 0 and ZERO launches; a miss is NO hit line, the fresh render's exit code, and at least one.
#
# EACH WORLD IS A GIT TOP LEVEL OF ITS OWN (the cache refuses a consumer nested in another repo,
# which V15 holds), built by copying the seed and `git init`, so nothing here touches the seeded
# CONSUMER the other phases read, and the dist is a copy too (V6 adds an object, V16 moves HEAD).
#
# THE SUITE RUNS FOUR TIMES, in parallel: once against the shipping engine, whose verdicts are this
# phase's ok/FAIL lines, and once per mutant against a COPY of the reconcile directory with one line
# of emit-report.sh edited. Each mutant's expected kill set is written beside it and must be met
# EXACTLY. PC-V0 is the seed sanity arm and is in no kill set: a copy that died fails it, which is
# reported as a harness failure, never as a kill.
#
# AN ENGINE WITHOUT THE CACHE (a consumer whose fixture arrived before its engine) prints SKIP and
# no ok line: it is never green.
#
# V17..V25 are NOT in this phase: they run in phase pcvlat (shard d), below it, through the helpers
# hoisted into the block that follows.

# ---- CACHE-ARM HELPERS: DEFINITIONS ONLY, read by phases pcache and pcvlat ----
# Hoisted out of phase pcache so phase pcvlat (shard d) can call the same helpers: nothing here RUNS
# at definition time. The run-time setup is pcv_setup, called at the top of each of the two phases.
# Below the probe-only exit, so the world-guard battery's copies never reach this block.
PCV_HITP='emit-report: accepted a recorded PASS ('
PCV_OKLINE="emit-report: the report's mechanical region is present, current, and complete."
# pcv_setup -- the suite root, the bash the shim execs, the adjudication seed, and the cache never
# opted out of by the caller's environment. Run at the top of each phase that runs cache arms.
pcv_setup() {
  PCV_ROOT="$WORK/pcache"; mkdir -p "$PCV_ROOT"
  PCV_BASH="$(command -v bash)"
  PCV_LAT_SEED="$HERE/../layer-adjudication-tier/seed.sh"
  unset AI_DLC_VERIFY_NO_CACHE
}
# pcv_cache_engine <ids> -- 0 when $EMIT carries the recorded-PASS cache; otherwise prints the SKIP
# line naming <ids> and returns 1. AN ENGINE WITHOUT THE CACHE (a consumer whose fixture arrived
# before its engine) prints SKIP and no ok line: it is never green.
pcv_cache_engine() {
  grep -qF "$PCV_HITP" "$EMIT" && return 0
  printf '  SKIP  %s: %s carries no recorded-PASS cache, so this engine predates BL-679 and no cache arm can be checked against it\n' "$1" "$EMIT"
  return 1
}
# pcv_shim -- the PATH shim at $PS_SHIM/bash that counts every detector launch into $PCV_COUNT.
pcv_shim() {
  mkdir -p "$PS_SHIM" || return 1
  { printf '#!%s\n' "$PCV_BASH"; printf '%s\n' 'printf "x\n" >> "$PCV_COUNT"'; printf 'exec "%s" "$@"\n' "$PCV_BASH"; } > "$PS_SHIM/bash" \
    && chmod +x "$PS_SHIM/bash"
}
# pcv_unexpected <verdicts> <ids> -- every id carrying a verdict line (`ok <id> ` or `FAIL <id> ` at
# line start) that <ids> does not name, once each. An arm left in a phase whose list does not read it
# writes a verdict nobody reads; this is what makes that state visible.
pcv_unexpected() {
  local id out=""
  for id in $(sed -n -E 's/^(ok|FAIL) (PC-V[0-9]+)( .*)?$/\2/p' "$1" 2>/dev/null | sort -u); do
    case " $2 " in *" $id "*) ;; *) out="$out $id" ;; esac
  done
  printf '%s\n' "${out# }"
}
# pcv_unexpected_probe <dir> -- 0 when pcv_unexpected names a seeded stray id (ok PC-V17 against a
# list naming PC-V1, so a prefix match would acquit it) and stays quiet on the near-misses: the same
# id indented or behind a DIAG prefix, and the same line against a list that names it.
pcv_unexpected_probe() {
  mkdir -p "$1" || return 1
  printf 'ok PC-V1 a\nok PC-V17 stray\nFAIL PC-V2 b\n' > "$1/offender"
  printf 'ok PC-V1 a\n  ok    PC-V17 indented\n  DIAG  pcache ship.log | ok PC-V17 diag\nFAIL PC-V2 b\n' > "$1/nearmiss"
  [ "$(pcv_unexpected "$1/offender" "PC-V1 PC-V2")" = "PC-V17" ] \
    && [ -z "$(pcv_unexpected "$1/nearmiss" "PC-V1 PC-V2")" ] \
    && [ -z "$(pcv_unexpected "$1/offender" "PC-V1 PC-V2 PC-V17")" ]
}
# pcv_read_ids <verdicts> <ids> <phase> -- one ok/bad per id in <ids> (ok line -> ok, FAIL line -> bad,
# no line -> bad), then a bad for every verdict id <ids> does not name. The stray check proves it
# can fire before it reads the corpus.
pcv_read_ids() {
  local _id _l _u
  for _id in $2; do
    _l="$(grep -m1 -E "^(ok|FAIL) $_id " "$1" 2>/dev/null)"
    case "$_l" in
      "ok $_id "*)   ok "${_l#ok }" ;;
      "FAIL $_id "*) bad "${_l#FAIL }" ;;
      *)             bad "$_id produced no verdict -- the suite stopped before reaching it" ;;
    esac
  done
  if ! pcv_unexpected_probe "$(dirname "$1")/unexpected-probe"; then
    bad "FIXTURE BROKEN: [$3] the stray-verdict check did not name a seeded stray id, or named a near-miss, so its silence below would prove nothing"
  fi
  for _u in $(pcv_unexpected "$1" "$2"); do
    bad "$_u wrote a verdict in phase $3, whose id list does not read it -- an arm runs in a phase that never scores it"
  done
}
pcv_v() { printf 'ok %s %s\n' "$1" "$2" >> "$PS_D/verdicts"; }
pcv_x() { printf 'FAIL %s %s\n' "$1" "$2" >> "$PS_D/verdicts"; }
pcv_why() { printf 'rc=%s hit=%s detector-launches=%s' "$PRC" "$PHIT" "$PN"; }
# pcv_run <tag> <consumer> <report> <dist> <base> <theirs> [nocache] -- one --verify through the shim.
# Sets PRC (exit), PHIT (1 when the hit prefix is on stdout), PN (detector launches counted).
pcv_run() {
  local eng="${PCV_ENG:-$PS_E}"
  : > "$PS_D/count"
  # PCV_ENVPRE: extra `env` operands for one arm (V24's locale), word-split on purpose; empty elsewhere.
  # PCV_ARM: the cache OPT-IN. The cache ships OFF, so every acceptance arm arms it, and a miss is a
  # miss of an ARMED cache; V26 alone replaces it with `-u EMIT_REPORT_VERIFY_CACHE`.
  if [ -n "${7:-}" ]; then
    env ${PCV_ENVPRE:-} ${PCV_ARM:-EMIT_REPORT_VERIFY_CACHE=1} AI_DLC_VERIFY_NO_CACHE=1 PCV_COUNT="$PS_D/count" PATH="$PS_SHIM:$PATH" \
      "$PCV_BASH" "$eng" --verify "$3" "$4" "$5" "$2" "$6" > "$PS_D/$1.out" 2> "$PS_D/$1.err"; PRC=$?
  else
    env ${PCV_ENVPRE:-} ${PCV_ARM:-EMIT_REPORT_VERIFY_CACHE=1} PCV_COUNT="$PS_D/count" PATH="$PS_SHIM:$PATH" \
      "$PCV_BASH" "$eng" --verify "$3" "$4" "$5" "$2" "$6" > "$PS_D/$1.out" 2> "$PS_D/$1.err"; PRC=$?
  fi
  PN="$(grep -c . "$PS_D/count")" || PN=0
  PHIT=0; grep -qF "$PCV_HITP" "$PS_D/$1.out" && PHIT=1
  return 0
}
pcm() { pcv_run "$1" "$PC_C" "$PC_R" "$PC_D" "$BASE" "$THEIRS" "${2:-}"; }
# pcv_is_hit <tag> <record path> -- exit 0, the pinned two lines byte for byte, and no detector launched.
pcv_is_hit() {
  [ "$PRC" -eq 0 ] && [ "$PHIT" -eq 1 ] && [ "$PN" -eq 0 ] || return 1
  printf '%s\n%s\n' "$PCV_OKLINE" \
    "emit-report: accepted a recorded PASS ($2); nothing was re-rendered. Set AI_DLC_VERIFY_NO_CACHE=1 to re-render." > "$PS_D/$1.want"
  cmp -s "$PS_D/$1.want" "$PS_D/$1.out"
}
# pcv_is_miss <rc> -- no hit line, the fresh render's exit code, and the render really ran.
pcv_is_miss() { [ "$PHIT" -eq 0 ] && [ "$PRC" -eq "$1" ] && [ "$PN" -gt 0 ]; }
# pcv_ctl <tag> -- the unchanged world HITS (the allow twin of the miss that follows), and the record
# is kept so an arm whose fresh render exits non-zero can put it back for the next control.
pcv_ctl() { pcm "$1.ctl"; pcv_is_hit "$1.ctl" "$PC_REC" || return 1; cp "$PC_REC" "$PS_D/rec.keep"; }
pcv_back() { cp "$PS_D/rec.keep" "$PC_REC"; }
pcv_noctl() { pcv_x "$1" "control: the unchanged world did not HIT before the change ($(pcv_why)), so a miss after it would prove nothing"; }

# pcv_lat <tag> -- a fresh layer-adjudication-tier world under <suite dir>/<tag>; sets L_D L_C L_B L_T L_R L_REC.
# THE DIST IS A BARE MIRROR of the seed's work-tree dist: the cache refuses a non-bare dist (R1), so
# every hit arm reads $L_D, and L_DW (the seed's own non-bare repo) is kept for the arms that commit
# in a work tree (V34) or test the non-bare refusal and the detectors' attributes (V42).
pcv_lat() {
  mkdir -p "$PS_D/$1" || return 1
  L_ROOT="$(TMPDIR="$PS_D/$1" bash "$PCV_LAT_SEED" 2>/dev/null)" && [ -d "$L_ROOT/consumer/.git" ] || return 1
  L_DW="$L_ROOT/dist"; L_D="$L_ROOT/dist-bare.git"; L_C="$L_ROOT/consumer"
  git clone -q --mirror "$L_DW" "$L_D" >/dev/null 2>&1 || return 1
  [ "$(git -C "$L_D" rev-parse --is-bare-repository 2>/dev/null)" = true ] || return 1
  L_B="$(git -C "$L_D" rev-parse HEAD~1)" && L_T="$(git -C "$L_D" rev-parse HEAD)" || return 1
  L_R="$L_C/_bmad-output/ai-dlc-update/reconcile-report.md"
  L_REC="$(git -C "$L_C" rev-parse --absolute-git-dir 2>/dev/null)/ai-dlc-verify-pass"
}
pcv_lat_approve() { # pcv_lat_approve <tag> -- render at the full base sha and write the report
  env ${PCV_ENVPRE:-} "$PCV_BASH" "$PS_E" "$L_D" "$L_B" "$L_C" "$L_T" > "$PS_D/region-$1.md" 2>/dev/null
  { echo "# Reconcile report (fixture)"; echo; cat "$PS_D/region-$1.md"; } > "$L_R"
  grep -q 'reconcile-mechanical' "$PS_D/region-$1.md"
}
PCV_HOOKREG='scripts/ai-dlc/validate-hook-registration.sh'
PCV_QEXT='.claude/skills/ai-dlc/extensions/q"x.md'
# ---- V55: a TRACKED file in the report's OWN directory, read only by a cr_run program ----
# The one input only the work-tree git fields key. The consumer's validate-hook-registration.sh runs
# through cr_run (emit-report.sh, the consumer-copy branch), which logs `x` and none of the program's
# reads; the file is tracked, so consignored (ignored files only) does not cover it; so conswork's
# `ls-files -m`, which excludes exactly the report FILE, is the only field that sees it change. This is
# M-direxcl's subject: widening that exclusion to the report's DIRECTORY hides it, and the change rides
# the record. Directions: the world records and HITS; the change MISSES with the opt-out's exit, which
# is non-zero because the region prints the program's output (a world where it is 0 is BROKEN).
pcv_v55world() {
  local f="_bmad-output/ai-dlc-update/r8-hookreg.txt" rc hit n nc
  PCV_ENVPRE=""
  pcv_lat v55 || { pcv_x PC-V55 "FIXTURE BROKEN: layer-adjudication-tier/seed.sh did not build its world"; return 0; }
  if git -C "$L_D" cat-file -e "${L_T}:core/scripts/validate-hook-registration.sh" 2>/dev/null; then
    pcv_x PC-V55 "FIXTURE BROKEN: theirs ships validate-hook-registration.sh, so the consumer's copy (the cr_run carrier) never runs"; return 0
  fi
  mkdir -p "$L_C/scripts/ai-dlc" "$L_C/_bmad-output/ai-dlc-update" \
    && printf '#!/bin/bash\n# reads through its --root argument, never its cwd: engines differ in where they run it from\nr=.; while [ "$#" -gt 0 ]; do case "$1" in --root) r="${2:-.}"; shift 2 ;; *) shift ;; esac; done\ncat "$r/%s"\n' "$f" > "$L_C/$PCV_HOOKREG" && chmod 755 "$L_C/$PCV_HOOKREG" \
    && printf 'HOOKREG-R8-one\n' > "$L_C/$f" \
    && { git -C "$L_C" add -- "$PCV_HOOKREG" "$f" && git -C "$L_C" -c user.email=f@f -c user.name=fixture commit -qm v55; } >/dev/null 2>&1 \
    || { pcv_x PC-V55 "FIXTURE BROKEN: could not commit the carrier and the tracked file"; return 0; }
  if [ "$(dirname "$L_R")" != "$L_C/$(dirname "$f")" ] || ! git -C "$L_C" ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then
    pcv_x PC-V55 "FIXTURE BROKEN: $f is not a tracked file in the report's own directory"; return 0
  fi
  # THE CARRIER IS CWD-INDEPENDENT: run once from a directory that is NOT the consumer root (the
  # pre-fix engine runs it from the caller's cwd, the fixed one from the root), it still prints the
  # tracked file's bytes through --root.
  mkdir -p "$PS_D/v55-elsewhere" && [ "$(cd "$PS_D/v55-elsewhere" && pwd -P)" != "$(cd "$L_C" && pwd -P)" ] \
    && grep -q 'HOOKREG-R8-one' <<< "$( cd "$PS_D/v55-elsewhere" && "$PCV_BASH" "$L_C/$PCV_HOOKREG" --root "$L_C" 2>&1 )" \
    || { pcv_x PC-V55 "FIXTURE BROKEN: the carrier run from a cwd other than the consumer root, with --root, did not print the tracked file's bytes"; return 0; }
  if ! pcv_lat_approve v55 || ! grep -q 'HOOKREG-R8-one' "$PS_D/region-v55.md"; then
    pcv_x PC-V55 "FIXTURE BROKEN: the approval does not carry the tracked file's bytes, so the cr_run carrier did not run"; return 0
  fi
  pcv_run v55r "$L_C" "$L_R" "$L_D" "$L_B" "$L_T"
  if ! { pcv_is_miss 0 && [ -f "$L_REC" ]; }; then pcv_x PC-V55 "control: the carrier world did not record ($(pcv_why))"; return 0; fi
  pcv_run v55c "$L_C" "$L_R" "$L_D" "$L_B" "$L_T"
  if ! pcv_is_hit v55c "$L_REC"; then pcv_x PC-V55 "control: the unchanged carrier world did not HIT ($(pcv_why))"; return 0; fi
  printf 'HOOKREG-R8-two\n' > "$L_C/$f"
  pcv_run v55 "$L_C" "$L_R" "$L_D" "$L_B" "$L_T"; rc="$PRC"; hit="$PHIT"; n="$PN"
  pcv_run v55.n "$L_C" "$L_R" "$L_D" "$L_B" "$L_T" nocache; nc="$PRC"; PRC="$rc"; PHIT="$hit"; PN="$n"
  if [ "$nc" -eq 0 ]; then
    pcv_x PC-V55 "FIXTURE BROKEN: the opt-out exits 0 after the tracked file changed, so the region does not print the carrier's output"
  elif pcv_is_miss "$nc"; then
    pcv_v PC-V55 "a TRACKED file in the report's own directory, read only by the consumer's hook validator through cr_run, records and HITS, and a change to it MISSES with the opt-out's exit $nc"
  else
    pcv_x PC-V55 "a change to a TRACKED file in the report's directory, read only through cr_run, did not force a fresh render: [$(pcv_why), opt-out $nc] -- the work-tree fields exclude more than the report file"
  fi
  return 0
}
# pcv_latarm <id> <tag> <description> -- seed, approve, record, HIT control, change, then a MISS whose exit
# equals an opt-out render of the same tree and is non-zero (so the change is one the render sees).
pcv_latarm() {
  local id="$1" t="$2" b2 rec ctl n0 ovr dang="" wt
  PCV_ENVPRE=""
  pcv_lat "$t" || { pcv_x "$id" "FIXTURE BROKEN: layer-adjudication-tier/seed.sh did not build its world"; return 0; }
  b2="$L_B"; ovr="$L_C/.claude/skills/ai-dlc/overrides"
  case "$t" in
    # V21/V22: an override whose base_sha names a DANGLING commit, in the consumer or in the dist. A
    # prune after the recording run removes the object and the row the render prints changes.
    v21) dang="$(git -C "$L_C" -c user.email=f@f -c user.name=fixture commit-tree -m dangling "$(git -C "$L_C" write-tree)" 2>/dev/null)" ;;
    v22) dang="$(git -C "$L_D" -c user.email=f@f -c user.name=fixture commit-tree -m dangling -p "$L_B" "${L_B}^{tree}" 2>/dev/null)" ;;
    # V23: a fixture core DELETED on a side branch, which the render names by an ABBREVIATED sha, so
    # core.abbrev changes the bytes of the RETIRED-FIXTURE-ORPHAN row and nothing else.
    v23) wt="$PS_D/$t/wt"
         { git -C "$L_D" worktree add -q --detach "$wt" "$L_B" \
           && mkdir -p "$wt/core/fixtures/oldfx" && printf 'exit 0\n' > "$wt/core/fixtures/oldfx/run.sh" \
           && git -C "$wt" add -A && git -C "$wt" -c user.email=f@f -c user.name=fixture commit -qm oldfx \
           && git -C "$wt" branch -q hist && git -C "$L_D" worktree remove --force "$wt"; } >/dev/null 2>&1 \
           || { pcv_x "$id" "FIXTURE BROKEN: could not build the deleted-fixture history in the dist"; return 0; }
         mkdir -p "$L_C/tests/fixtures/oldfx"; printf 'exit 0\n' > "$L_C/tests/fixtures/oldfx/run.sh" ;;
    # V24: approved and recorded under a UTF-8 collation, verified under LC_ALL=C, where the render's
    # sorted lists come out in another order.
    v24) PCV_ENVPRE="-u LC_ALL LANG=en_US.UTF-8" ;;
  esac
  if [ "$t" = v21 ] || [ "$t" = v22 ]; then
    [ -n "$dang" ] || { pcv_x "$id" "FIXTURE BROKEN: could not create the dangling commit"; return 0; }
    mkdir -p "$ovr" && printf -- '---\nshadows: steps/demo.md\nbase_sha: %s\n---\n\nbody\n' "$dang" > "$ovr/demo.md"
  fi
  case "$t" in
    v17) printf -- '---\nkind: check\nhooks: steps/demo.md\nreason: q\n---\n\n### 902. [ext:q] Q.\n\nBody.\n' > "$L_C/$PCV_QEXT" ;;
    v18|v19) mkdir -p "$L_C/scripts/ai-dlc"
         printf '#!/bin/bash\necho "HOOKREG-SHIM-RAN"\n' > "$L_C/$PCV_HOOKREG"; chmod 644 "$L_C/$PCV_HOOKREG" ;;
  esac
  if [ "$t" = v19 ]; then
    git -C "$L_C" config core.filemode false
    { git -C "$L_C" add -A && git -C "$L_C" -c user.email=f@f -c user.name=fixture commit -qm v19; } >/dev/null 2>&1 \
      || { pcv_x "$id" "FIXTURE BROKEN: could not commit the tracked hook-registration file"; return 0; }
  fi
  pcv_lat_approve "$t" || { pcv_x "$id" "FIXTURE BROKEN: the world rendered no region"; return 0; }
  pcv_run "$t.r" "$L_C" "$L_R" "$L_D" "$L_B" "$L_T"; rec="$(pcv_why)"; n0=0
  pcv_is_miss 0 && [ -f "$L_REC" ] && n0=1
  pcv_run "$t.c" "$L_C" "$L_R" "$L_D" "$L_B" "$L_T"; ctl="$(pcv_why)"
  if [ "$n0" -ne 1 ] || ! pcv_is_hit "$t.c" "$L_REC"; then
    pcv_x "$id" "control: the unchanged world did not record [$rec] and then hit [$ctl], so a miss after the change would prove nothing"; return 0
  fi
  case "$t" in
    v17) printf -- '---\nkind: check\nreason: q\n---\n\n### 902. [ext:q] Q.\n\nBody.\n' > "$L_C/$PCV_QEXT" ;;
    v18|v19) chmod 755 "$L_C/$PCV_HOOKREG" ;;
    v20) b2="$(git -C "$L_D" rev-parse --short "$L_B" 2>/dev/null)"
         [ -n "$b2" ] && [ "$b2" != "$L_B" ] || { pcv_x "$id" "FIXTURE BROKEN: no short spelling distinct from the full base sha"; return 0; } ;;
    v21) git -C "$L_C" prune --expire=now >/dev/null 2>&1
         ! git -C "$L_C" cat-file -e "$dang" 2>/dev/null || { pcv_x "$id" "FIXTURE BROKEN: the prune left the dangling consumer commit in place"; return 0; } ;;
    v22) git -C "$L_D" prune --expire=now >/dev/null 2>&1
         ! git -C "$L_D" cat-file -e "$dang" 2>/dev/null || { pcv_x "$id" "FIXTURE BROKEN: the prune left the dangling dist commit in place"; return 0; } ;;
    v23) git -C "$L_D" config core.abbrev 20 ;;
    v24) PCV_ENVPRE="LC_ALL=C" ;;
    v25) chmod 000 "$L_C/.claude/skills/ai-dlc/extensions" ;;
  esac
  # The cached run goes FIRST: an opt-out run before it would, under M-exit3, record the changed tree
  # and turn this arm's miss into a hit, putting V17..V20 into a kill set that is not theirs.
  pcv_run "$t" "$L_C" "$L_R" "$L_D" "$b2" "$L_T"; local c_rc="$PRC" c_hit="$PHIT" c_n="$PN"
  pcv_run "$t.n" "$L_C" "$L_R" "$L_D" "$b2" "$L_T" nocache; n0="$PRC"
  PRC="$c_rc"; PHIT="$c_hit"; PN="$c_n"
  # V25's directory is put back at once, by its own path, or the EXIT trap's rm cannot descend into it.
  [ "$t" = v25 ] && chmod 755 "$L_C/.claude/skills/ai-dlc/extensions"
  PCV_ENVPRE=""
  if [ "$n0" -eq 0 ]; then
    pcv_x "$id" "FIXTURE BROKEN: the opt-out render after the change still exits 0, so the change is not one the render sees and a hit would be correct"
  elif pcv_is_miss "$n0"; then
    pcv_v "$id" "$3 MISSES: no hit line, and the fresh render exits $n0 exactly as the opt-out render of the same tree"
  else
    pcv_x "$id" "$3 did not force a fresh render: [$(pcv_why)], opt-out render exits $n0 -- a recorded PASS answered for a tree it never rendered"
  fi
  return 0
}
if rer_phase pcache; then
PCV_IDS="PC-V0 PC-V1 PC-V14 PC-V2 PC-V3 PC-V9 PC-V4 PC-V11 PC-V12 PC-V13 PC-V5 PC-V6 PC-V7 PC-V8 PC-V15 PC-V16 PC-V27 PC-V28 PC-V29 PC-V30 PC-V31 PC-V35 PC-V36 PC-V33 PC-V34 PC-V37 PC-V26 PC-V10 PC-V55"
# THE ROUND-6 PARTITION ARMS (R1..R4 refusals, the B2 detector arm, and V32 rewritten to assert the
# tracked-symlink refusal) need an engine that carries the named refusal line. An engine without it
# (a consumer whose fixture arrived before its engine) prints SKIP for them and no ok line.
PCV_R6MARK='emit-report: recorded PASS refused, re-rendering: '
PCV_R6=0
if grep -qF "$PCV_R6MARK" "$EMIT"; then
  PCV_R6=1
  PCV_IDS="$PCV_IDS PC-V32 PC-V38 PC-V39 PC-V40 PC-V42"
else
  printf '  SKIP  PC-V32 PC-V38..PC-V40 PC-V42: %s carries no named recorded-PASS refusal, so the round-6 partition cannot be checked against it\n' "$EMIT"
fi
# THE ROUND-7 ARMS (the receipts field that replaced R4, V41 rewritten to assert it; the dist's linked
# worktrees; the named directory refusal) need an engine that prints the directory refusal's cause.
# V46 (an escaping `fixtures:` value) needs layer-drift.sh's own escape row as well, read from the
# engine directory beside emit-report.sh. An engine without either prints SKIP and no ok line.
PCV_R7MARK='a listed path is a directory (a nested work tree or an unignored worktree): '
PCV_R7LDMARK='which escapes tests/fixtures/ (a .. component or a leading /)'
PCV_TAB="$(printf '\t')"
PCV_R7=0; PCV_R7LD=0; PCV_R7F=0; PCV_CI=0
# THE ROUND-8 GATE (V48..V54). These arms need the read-log engine: emit-report.sh writes a version-2
# record (`ai-dlc-verify-pass 2`) carrying consumer-read.sh's read log. The fixture and that engine CAN
# arrive in different pulls (a fixture rides step 2 when it names a changed machinery path, while a
# DEFERred or CARRYd engine slice lands in the gated apply), so the gate stays. It NEVER SKIPS: a
# missing marker is a FAIL line per id, "round-8 gate marker absent", because a skipped round-8 arm is
# the defect class itself. PCV_R8_FORCE=1 runs the arms against an engine without the marker; that is
# how a red run on a pre-fix engine exercises them, and it is the only way the gate is bypassed.
PCV_R8MARK='ai-dlc-verify-pass 2'
PCV_R8IDS="PC-V48 PC-V49 PC-V50 PC-V51 PC-V53 PC-V54"
# pcv_installed <emit> -- 0 in the INSTALLED layout. The layout is seed.sh's own decision (seed.sh:12
# picks the dist path, :14 the installed one), read back off the EMIT it chose; never a walk for VERSION.
# An installed tree whose engine predates a pin is a pre-migration state: PENDING, never a failure.
pcv_installed() { case "$1" in */.claude/skills/ai-dlc-update/reconcile/emit-report.sh) return 0 ;; esac; return 1; }
pcv_r8gate() { # pcv_r8gate <emit> -- sets PCV_R7F and adds the round-8 ids; a FAIL line per id when absent
  local i
  if grep -qF "$PCV_R8MARK" "$1" || [ "${PCV_R8_FORCE:-}" = 1 ]; then
    PCV_R7F=1; PCV_IDS="$PCV_IDS $PCV_R8IDS"
    grep -qF "$PCV_R8MARK" "$1" || printf '  NOTE  PC-V48..PC-V54: PCV_R8_FORCE=1 runs the round-8 arms against %s, which carries no read-log record\n' "$1"
  elif pcv_installed "$1"; then
    printf 'PENDING: round-8 arms not run, engine lacks ai-dlc-verify-pass 2\n'
  else
    for i in $PCV_R8IDS; do bad "$i round-8 gate marker absent: $1 carries no '$PCV_R8MARK' record, so the round-8 arms cannot run against it (set PCV_R8_FORCE=1 to run them anyway)"; done
  fi
}
# V42's TWO CALL-SITE MUTANTS pin the fixed engine's `cr_hash` lines in preclassify.sh and layer-drift.sh.
# An engine without them is a pre-migration state on a consumer (PENDING, V42 not run, no FAIL) and a
# broken pin in the distribution (V42 runs and FAILs naming the anchor). Never a fallback anchor: a mutant
# scored against the old code scores a different subject.
PCV_V42=1
if [ "$PCV_R6" -eq 1 ] && pcv_installed "$EMIT" \
   && { [ "$(grep -cF 'cr_hash "$CONS" "$1"' "$(dirname "$EMIT")/preclassify.sh")" != 1 ] \
        || [ "$(grep -cF 'cr_hash "$CONSUMER" "$1"' "$(dirname "$EMIT")/layer-drift.sh")" != 1 ]; }; then
  PCV_V42=0; PCV_IDS="$(printf '%s\n' $PCV_IDS | grep -vxF PC-V42 | tr '\n' ' ')"
  printf 'PENDING: PC-V42 not run, engine lacks the cr_hash call sites its mutants pin\n'
fi
if [ "$PCV_R6" -eq 1 ] && grep -qF "$PCV_R7MARK" "$EMIT"; then
  PCV_R7=1
  PCV_IDS="$PCV_IDS PC-V41 PC-V44 PC-V45 PC-V47"
  if grep -qF "$PCV_R7LDMARK" "$(dirname "$EMIT")/layer-drift.sh"; then
    PCV_R7LD=1; PCV_IDS="$PCV_IDS PC-V46"
  else
    printf '  SKIP  PC-V46: %s carries no escape refusal for a fixtures: value, so the round-7 B4 arm cannot be checked against it\n' "$(dirname "$EMIT")/layer-drift.sh"
  fi
else
  printf '  SKIP  PC-V41 PC-V44..PC-V47: %s carries no named directory refusal, so the round-7 partition cannot be checked against it\n' "$EMIT"
fi
# The round-8 gate sits OUTSIDE the round-7 one, so an engine without the round-7 marker cannot carry the
# round-8 ids into a SKIP: they FAIL by name, or run.
pcv_r8gate "$EMIT"
# V56/V57 (BL-777): the key's OWN tools absent, each refused BY NAME. The causes are the engine's words,
# pinned here on purpose (a fixture may pin its own engine). An installed engine that predates them is a
# pre-migration state (PENDING, not run); in the distribution the arms always run, so an engine without
# the refusals FAILS them by name rather than skipping.
PCV_R9CK='cksum is not on PATH, so the env field cannot checksum the awk, sed and sort binaries it keys'
PCV_R9SHA='neither shasum nor sha256sum is on PATH, so no field can be hashed'
PCV_R9=0
if [ "$PCV_R6" -eq 1 ]; then
  if grep -qF "$PCV_R9CK" "$EMIT" || ! pcv_installed "$EMIT"; then
    PCV_R9=1; PCV_IDS="$PCV_IDS PC-V56 PC-V57"
  else
    printf 'PENDING: PC-V56 PC-V57 not run, engine lacks the named cksum refusal\n'
  fi
fi
if [ "$PCV_R7F" -eq 1 ]; then
  # PC-V52 (round-8 B4) needs a CASE-INSENSITIVE filesystem where the worlds are built: measured here,
  # beside the suite root. A case-sensitive one prints SKIP and no ok line, never a pass.
  _pci="$WORK/pcv-case-probe"
  if mkdir -p "$_pci" && : > "$_pci/CaseR8" && [ -e "$_pci/caser8" ]; then
    PCV_CI=1; PCV_IDS="$PCV_IDS PC-V52"
  else
    printf '  SKIP  PC-V52: the filesystem under %s is case-sensitive, so the round-8 B4 case-variant receipt cannot be built\n' "$WORK"
  fi
fi
# THE PRE-CACHE ENGINE for V26, extracted from this checkout's history into a scratch dir, every file of
# reconcile/ at 2875c7ad. The root is found by walking up for `.git` beside the engine; a tree with no
# such history (a consumer, a hermetic sandbox) leaves PCV_OLD_ENG empty and V26 says which comparison it made.
PCV_OLD_SHA=2875c7adfc82324c204f66e651fcd166f6e33655
PCV_OLD_ENG=""
_pr="$HERE"
while [ -n "$_pr" ] && [ "$_pr" != / ]; do
  if [ -e "$_pr/.git" ] && [ -f "$_pr/core/skills/ai-dlc-update/reconcile/emit-report.sh" ]; then break; fi
  _pr="$(dirname "$_pr")"
done
if [ -n "$_pr" ] && [ "$_pr" != / ] && git -C "$_pr" cat-file -e "${PCV_OLD_SHA}^{commit}" 2>/dev/null; then
  _po="$WORK/pcache-old-engine"; mkdir -p "$_po"
  git -C "$_pr" ls-tree --name-only "${PCV_OLD_SHA}:core/skills/ai-dlc-update/reconcile/" > "$_po.list" 2>/dev/null
  _pn=0; _pt="$(grep -c . "$_po.list")" || _pt=0
  while IFS= read -r _pf; do
    git -C "$_pr" show "${PCV_OLD_SHA}:core/skills/ai-dlc-update/reconcile/${_pf}" > "$_po/$_pf" 2>/dev/null && _pn=$((_pn+1))
  done < "$_po.list"
  if [ "$_pt" -gt 0 ] && [ "$_pn" -eq "$_pt" ] && [ -f "$_po/emit-report.sh" ] && ! grep -qF "$PCV_HITP" "$_po/emit-report.sh"; then
    PCV_OLD_ENG="$_po/emit-report.sh"
  fi
fi
pcv_setup

# ---- V27..V31: ONE shared adjudication world, the arms in sequence, each undone before the next ----
# One seed for five arms (each a seed of its own would multiply this phase's cost). Every arm opens
# with a HIT control on the restored world, so a failed undo shows as that arm's control failing
# rather than as a miss it did not earn, and the record is put back after every arm. Each change is
# one the old key could not see. A refusal arm has two steps. First the refused condition ALONE: a
# fresh exit-0 render must leave the record BYTE-IDENTICAL, because a key that does not refuse
# re-records there. Then a render-visible edit, whose cached run must be a fresh render with the
# opt-out's non-zero exit, because a key that does not refuse would hit it.
# pcv_kstep <tag> -- the cached run, then the opt-out run on the same tree; sets K_RC K_HIT K_N K_NC.
pcv_kstep() {
  pcv_run "$1" "$L_C" "$L_R" "$L_D" "$L_B" "$L_T"; K_RC="$PRC"; K_HIT="$PHIT"; K_N="$PN"
  pcv_run "$1.n" "$L_C" "$L_R" "$L_D" "$L_B" "$L_T" nocache; K_NC="$PRC"
  PRC="$K_RC"; PHIT="$K_HIT"; PN="$K_N"
}
# pcv_kctl <id> -- the restored world HITS; keeps the record. Non-zero, with the arm's verdict, if not.
pcv_kctl() {
  pcv_run "$1.c" "$L_C" "$L_R" "$L_D" "$L_B" "$L_T"
  if pcv_is_hit "$1.c" "$L_REC"; then cp "$L_REC" "$PS_D/krec.keep"; return 0; fi
  pcv_x "$1" "control: the shared world did not HIT before the change ($(pcv_why)), so a miss after it would prove nothing"
  return 1
}
pcv_kback() { cp "$PS_D/krec.keep" "$L_REC"; }
# pcv_krefuse <id> <tag> <description> -- step one of a refusal arm, run with the condition in place.
# 0 when the run is a fresh exit-0 render that left the record byte-identical.
pcv_krefuse() {
  pcv_kstep "$2.only"
  if pcv_is_miss 0 && [ "$K_NC" -eq 0 ] && cmp -s "$L_REC" "$PS_D/krec.keep"; then return 0; fi
  pcv_x "$1" "$3 alone: [$(pcv_why)], opt-out exits $K_NC, record $(cmp -s "$L_REC" "$PS_D/krec.keep" && echo unchanged || echo REWRITTEN) (want a fresh exit-0 render that records nothing)"
  return 1
}
# pcv_kedit <id> <tag> <description> -- the render-visible step: cached must miss with the opt-out's
# non-zero exit.
pcv_kedit() {
  pcv_kstep "$2"
  if [ "$K_NC" -eq 0 ]; then
    pcv_x "$1" "FIXTURE BROKEN: the opt-out render after $3 still exits 0, so the edit is not one the render sees"
  elif pcv_is_miss "$K_NC"; then
    pcv_v "$1" "$3 MISSES: the condition alone recorded nothing, and after a render-visible edit the fresh render exits $K_NC exactly as the opt-out render"
  else
    pcv_x "$1" "$3 did not force a fresh render: [$(pcv_why)], opt-out exits $K_NC -- a recorded PASS answered for a tree it never rendered"
  fi
}
# pcv_read_ev <entry> -- the `read` object a register row on the current L world needs to clear that
# entry's LC-E4 (EXTENSION-HOOK-DRIFT) row: since BL-620 layer-drift.sh's adj_records clears a verdict
# only when read.entry_line is a line of the entry's BODY and read.core_line an added or removed line
# of the range diff of the core file its hooks: names, each trimmed, at least 20 characters with 10
# letters or digits, and not a heading. Both are the FIRST qualifying line of the world's own files,
# never a literal, so the pair moves with the seed. The diff carries the engine's pinned options.
# This is a second spelling of that rule, so it proves nothing alone: pcv_read_clears is its check.
pcv_read_ev() {
  local hk cpath q
  q='{ l = $0; gsub(/\t/, " ", l); sub(/^[[:space:]]+/, "", l); sub(/[[:space:]]+$/, "", l)
       a = l; n = gsub(/[A-Za-z0-9]/, "", a)
       if (length(l) >= 20 && n >= 10 && l !~ /^#+ /) { print l; exit } }'
  hk="$(awk 'NR==1 && $0=="---" { f=1; next } f && $0=="---" { exit } f && index($0, "hooks:")==1 { sub(/^hooks:[[:space:]]*/, ""); print; exit }' "$L_C/$1")"
  [ -n "$hk" ] || return 1
  case "$hk" in team-roles/*) cpath="core/$hk" ;; *) cpath="core/skills/ai-dlc/$hk" ;; esac
  awk 'NR==1 && $0=="---" { fm=1; next } fm && $0=="---" { fm=0; next } !fm' "$L_C/$1" > "$PS_D/read-ev.body" || return 1
  git -C "$L_D" -c diff.algorithm=myers diff --no-ext-diff --no-textconv --no-color -U0 "$L_B" "$L_T" -- "$cpath" > "$PS_D/read-ev.diff" 2>/dev/null || return 1
  awk '/^@@/ { h = 1; next } /^diff --git / { h = 0; next } h && /^[-+]/ { print substr($0, 2) }' "$PS_D/read-ev.diff" > "$PS_D/read-ev.core" || return 1
  awk "$q" "$PS_D/read-ev.body" > "$PS_D/read-ev.el" && awk "$q" "$PS_D/read-ev.core" > "$PS_D/read-ev.cl" || return 1
  [ -s "$PS_D/read-ev.el" ] && [ -s "$PS_D/read-ev.cl" ] || return 1
  jq -cn --rawfile e "$PS_D/read-ev.el" --rawfile c "$PS_D/read-ev.cl" '{entry_line: ($e | rtrimstr("\n")), core_line: ($c | rtrimstr("\n"))}'
}
# pcv_read_clears <out> -- 0 when layer-drift.sh exits 0 on the current L world and prints NO
# HARD-LAYER-ADJUDICATION-MISSING row. Its control is the plain world's run, whose HARD row is where
# the caller read the 40-hex digest: a row that fails to resolve then reads FIXTURE BROKEN, not a cache FAIL.
pcv_read_clears() {
  local rc=0
  bash "$(dirname "$PS_E")/layer-drift.sh" "$L_D" "$L_B" "$L_T" "$L_C" > "$1" 2>/dev/null || rc=$?
  [ "$rc" -eq 0 ] && ! grep -q '^HARD-LAYER-ADJUDICATION-MISSING' "$1"
}
pcv_kworld() {
  local ext reg dig ev p ent=".claude/skills/ai-dlc/extensions/adjudicable.md"
  pcv_lat k || { for p in PC-V27 PC-V28 PC-V29 PC-V30 PC-V31; do pcv_x "$p" "FIXTURE BROKEN: layer-adjudication-tier/seed.sh did not build its world"; done; return 0; }
  ext="$L_C/.claude/skills/ai-dlc/extensions"
  # V30's subject: a consumer extension line equal to a rulebook line base..theirs DELETES, so
  # retired-layer-passage.sh renders a row only while its content diff prints `-` lines.
  printf -- '---\nkind: check\nhooks: steps/other.md\nreason: p\n---\n\n### 906. [ext:p] P.\n\nGamma'"'"'s body at BASE.\n' > "$ext/passage.md"
  { git -C "$L_C" add -A && git -C "$L_C" -c user.email=f@f -c user.name=fixture commit -qm passage; } >/dev/null 2>&1
  pcv_lat_approve k || { for p in PC-V27 PC-V28 PC-V29 PC-V30 PC-V31; do pcv_x "$p" "FIXTURE BROKEN: the shared world rendered no region"; done; return 0; }
  pcv_run k.r "$L_C" "$L_R" "$L_D" "$L_B" "$L_T"
  if ! { pcv_is_miss 0 && [ -f "$L_REC" ]; }; then
    for p in PC-V27 PC-V28 PC-V29 PC-V30 PC-V31; do pcv_x "$p" "control: the shared world's first --verify did not render and record ($(pcv_why))"; done; return 0
  fi

  # V27 (assume-unchanged) and V28 (skip-worktree): status hides the edit to the flagged file.
  for p in "PC-V27 k27 --assume-unchanged" "PC-V28 k28 --skip-worktree"; do
    set -- $p
    if pcv_kctl "$1"; then
      git -C "$L_C" update-index "$3" ".claude/skills/ai-dlc/extensions/adjudicable.md"
      if pcv_krefuse "$1" "$2" "update-index $3"; then
        sed 's#^hooks: steps/demo.md#hooks: steps/none.md#' "$L_C/.claude/skills/ai-dlc/extensions/adjudicable.md" > "$PS_D/$2.edit" \
          && cp "$PS_D/$2.edit" "$L_C/.claude/skills/ai-dlc/extensions/adjudicable.md"
        pcv_kedit "$1" "$2" "update-index $3 on an extension, then its hooks: line rewritten,"
      fi
      git -C "$L_C" update-index "--no-${3#--}" ".claude/skills/ai-dlc/extensions/adjudicable.md"
      git -C "$L_C" show "HEAD:.claude/skills/ai-dlc/extensions/adjudicable.md" > "$L_C/.claude/skills/ai-dlc/extensions/adjudicable.md"
      pcv_kback
    fi
  done

  # V29: an untracked NESTED REPOSITORY under extensions/, whose files git lists nowhere. Step one's
  # repository holds only a README.txt: layer-drift.sh walks extensions/ with `find -name '*.md'`, so
  # a .txt is a nested repo the render does not see, and the old key (a new `? …/vendored/` status
  # line) would MISS and re-record it. Step two adds v.md, an extension whose hooks: names a step the
  # dist lacks, which the walk renders as EXTENSION-HOOK-MISSING. The old key skipped the bytes under
  # a `dir/` entry and its status line is unchanged, so it would HIT the stale record.
  if pcv_kctl PC-V29; then
    mkdir -p "$ext/vendored" && git -C "$ext/vendored" init -q
    printf 'vendored payload\n' > "$ext/vendored/README.txt"
    if pcv_krefuse PC-V29 k29 "an untracked nested repository under extensions/"; then
      printf -- '---\nkind: check\nhooks: steps/other.md\nreason: v\n---\n\n### 905. [ext:v] V.\n\nBody.\n' > "$ext/vendored/v.md"
      pcv_kedit PC-V29 k29 "a nested repository under extensions/ that gains an extension v.md"
    fi
    mv "$ext/vendored" "$PS_D/k29-vendored-aside"
    pcv_kback
  fi

  # V30: a `-diff` attribute in the dist's info/attributes, then GIT_EXTERNAL_DIFF=true. Both used to
  # empty the content diff retired-layer-passage.sh parses with the key unmoved. Now the key moves
  # (a miss), and the hardened diff renders what it rendered before, so the fresh exit is 0 and equal
  # to the opt-out's.
  if pcv_kctl PC-V30; then
    mkdir -p "$L_D/info" && printf '*.md -diff\n' > "$L_D/info/attributes"
    pcv_kstep k30a; local a_ok=0 a_why
    a_why="$(pcv_why), opt-out $K_NC"
    pcv_is_miss "$K_NC" && [ "$K_NC" -eq 0 ] && a_ok=1
    mv "$L_D/info/attributes" "$PS_D/k30-attributes-aside"
    pcv_kback
    PCV_ENVPRE="GIT_EXTERNAL_DIFF=true"; pcv_kstep k30e; PCV_ENVPRE=""
    pcv_kback
    if [ "$a_ok" -eq 1 ] && pcv_is_miss "$K_NC" && [ "$K_NC" -eq 0 ]; then
      pcv_v PC-V30 "a -diff attribute in the dist's info/attributes, and GIT_EXTERNAL_DIFF=true, each MISS, and each fresh render exits 0 exactly as the opt-out render (the content diff ignores both)"
    else
      pcv_x PC-V30 "diff attributes: info/attributes [$a_why], GIT_EXTERNAL_DIFF [$(pcv_why), opt-out $K_NC] (want two misses whose fresh render exits 0 like the opt-out)"
    fi
  fi

  # V31, LAST because it commits: the adjudication register as a TRACKED symlink to a file outside
  # the consumer. The key hashed the link, the detectors read the target.
  if ! command -v jq >/dev/null 2>&1; then pcv_x PC-V31 "jq is not on PATH; layer-drift.sh cannot read the register, so no resolution can be seeded"
  elif pcv_kctl PC-V31; then
    reg="$L_C/_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl"
    bash "$(dirname "$PS_E")/layer-drift.sh" "$L_D" "$L_B" "$L_T" "$L_C" > "$PS_D/ld31.out" 2>/dev/null
    dig="$(awk -F'\t' '$1 == "HARD-LAYER-ADJUDICATION-MISSING"' "$PS_D/ld31.out" | grep -o 'subject_digest [0-9a-f]\{40\}' | awk '{ print $2; exit }')"
    if [ "${#dig}" -ne 40 ] || [ -e "$reg" ]; then
      pcv_x PC-V31 "FIXTURE BROKEN: no 40-hex subject_digest to resolve, or the register already exists"
    else
      : > "$PS_D/k31-outside-register.jsonl"
      ln -s "$PS_D/k31-outside-register.jsonl" "$reg"
      { git -C "$L_C" add -A && git -C "$L_C" -c user.email=f@f -c user.name=fixture commit -qm regsym; } >/dev/null 2>&1
      if pcv_krefuse PC-V31 k31 "a tracked register symlink to a file outside the consumer"; then
        if ! ev="$(pcv_read_ev "$ent")"; then
          pcv_x PC-V31 "FIXTURE BROKEN: no read evidence could be derived from the world's entry body and LC-E4 range diff, so no row can resolve (needs jq >= 1.6 for --rawfile)"
        else
          jq -cn --arg e "$ent" --arg d "$dig" --argjson r "$ev" \
            '{clause:"LC-E4",entry:$e,subject_digest:$d,verdict:"still-additive",recorded_utc:"2026-01-01T00:00:00Z",reason:"seeded",read:$r}' > "$PS_D/k31-outside-register.jsonl"
          if ! pcv_read_clears "$PS_D/ld31r.out"; then
            pcv_x PC-V31 "FIXTURE BROKEN: layer-drift.sh still prints HARD-LAYER-ADJUDICATION-MISSING (or did not exit 0) with the read-evidence row in the outside target (ld31r.out), where the plain world printed it (ld31.out, the digest's source) -- the row does not resolve, so a cached FAIL below would be the seed's"
          else
            pcv_kedit PC-V31 k31 "a tracked register symlink whose outside target gains a resolving row"
          fi
        fi
      fi
    fi
  fi
  return 0
}

# ---- V32..V36: a fifth review's inputs the key could not see, each with a near miss that must HIT ----
# Every arm: a HIT control, the hole, a cached run that must MISS with the opt-out render's non-zero
# exit, the hole undone, the record put back (under M-exit3 the missing run records the hole's key,
# and a near miss read against that record would miss for a reason that is not its own), then the
# near miss, which must HIT the restored record.
# pcv_k2miss <id> <tag> <description> -- 0 when the cached run is a fresh render with the opt-out's
# non-zero exit; otherwise the arm's FAIL verdict, and non-zero.
pcv_k2miss() {
  pcv_kstep "$2"
  if [ "$K_NC" -eq 0 ]; then
    pcv_x "$1" "FIXTURE BROKEN: the opt-out render after $3 still exits 0, so the change is not one the render sees"; return 1
  elif pcv_is_miss "$K_NC"; then return 0; fi
  pcv_x "$1" "$3 did not force a fresh render: [$(pcv_why)], opt-out exits $K_NC -- a recorded PASS answered for a tree it never rendered"
  return 1
}
# pcv_k2near <id> <tag> <hole> <near miss> -- the near miss HITS: the arm's ok verdict, or its FAIL.
pcv_k2near() {
  pcv_run "$2.nm" "$L_C" "$L_R" "$L_D" "$L_B" "$L_T"
  if pcv_is_hit "$2.nm" "$L_REC"; then
    pcv_v "$1" "$3 MISSES with the opt-out render's exit $K_NC, and the near miss ($4) HITS"
  else
    pcv_x "$1" "near miss ($4) did not HIT: [$(pcv_why)] -- the fix over-refuses"
  fi
}
# One world for V32 (F1), V35 (F5) and V36 (F6), all seeded before the one record: local/ IGNORED,
# and an extension bound to `fixtures: myfx` with an EMPTY tests/fixtures/myfx. NO SYMLINK IS SEEDED:
# the cache refuses any tracked symlink (R2), so a linked seed could never record and every arm here
# would fail its control. V32 adds its link after the control and removes it before its near miss.
# Each arm is undone before the next.
pcv_k2world() {
  local p ids="PC-V35 PC-V36" stp=".claude/skills/ai-dlc/steps/demo.md" ent k32_nmhit=0
  [ "$PCV_R6" -eq 1 ] && ids="PC-V32 $ids"
  pcv_lat k2 || { for p in $ids; do pcv_x "$p" "FIXTURE BROKEN: layer-adjudication-tier/seed.sh did not build its world"; done; return 0; }
  ent="$L_C/.claude/skills/ai-dlc/extensions/adjudicable.md"
  mkdir -p "$L_C/tests/fixtures/myfx" \
    && printf 'local/\n' >> "$L_C/.gitignore" \
    && awk 'NR==2{print "fixtures: myfx"} {print}' "$ent" > "$PS_D/k2-ent" && cp "$PS_D/k2-ent" "$ent" \
    && { git -C "$L_C" add -A && git -C "$L_C" -c user.email=f@f -c user.name=fixture commit -qm k2seed; } >/dev/null 2>&1 \
    || { for p in $ids; do pcv_x "$p" "FIXTURE BROKEN: could not seed the link and the fixture binding"; done; return 0; }
  pcv_lat_approve k2 || { for p in $ids; do pcv_x "$p" "FIXTURE BROKEN: the shared world rendered no region"; done; return 0; }
  pcv_run k2.r "$L_C" "$L_R" "$L_D" "$L_B" "$L_T"
  if ! { pcv_is_miss 0 && [ -f "$L_REC" ]; }; then
    for p in $ids; do pcv_x "$p" "control: the shared world's first --verify did not render and record ($(pcv_why))"; done; return 0
  fi

  # V32 (F1, rewritten for the round-6 partition): steps/demo.md becomes a TRACKED symlink to the
  # IGNORED local/demo.md, staged by path (index only, so no ref moves). Round 5 keyed the target's
  # bytes and its near miss was "the unchanged link HITS"; round 6 REFUSES every tracked symlink (R2),
  # because the target's exec bit was still unkeyed. So: the link ALONE renders exit 0 and leaves the
  # record untouched, naming R2; an edit to the ignored target then misses with the opt-out's exit;
  # near miss: the same tree with steps/demo.md a regular file again HITS.
  if [ "$PCV_R6" -eq 1 ] && pcv_kctl PC-V32; then
    cp "$L_C/$stp" "$PS_D/k32-file.keep"
    mkdir -p "$L_C/local" && cp "$PS_D/k32-file.keep" "$L_C/local/demo.md" && rm -f "$L_C/$stp" \
      && ln -s ../../../../local/demo.md "$L_C/$stp" && git -C "$L_C" add -- "$stp" >/dev/null 2>&1
    k32_ls="$(git -C "$L_C" ls-files -s -- "$stp" 2>/dev/null)" || k32_ls=""
    if [ ! -L "$L_C/$stp" ] || ! grep -q '^120000 ' <<< "$k32_ls"; then
      pcv_x PC-V32 "FIXTURE BROKEN: steps/demo.md did not become a tracked symlink (mode 120000)"
    elif pcv_krefuse PC-V32 k32 "a tracked symlink steps/demo.md -> the ignored local/demo.md"; then
      if ! grep -qF "${PCV_R6MARK}R2" "$PS_D/k32.only.err"; then
        pcv_x PC-V32 "the tracked symlink rendered fresh but stderr names no R2 refusal, so the miss is not the partition's"
      else
        printf '\n## Local rule\n\nconsumer-only text\n' >> "$L_C/local/demo.md"
        if pcv_k2miss PC-V32 k32 "an edit to the IGNORED target of a tracked symlink"; then
          rm -f "$L_C/$stp"; cp "$PS_D/k32-file.keep" "$L_C/$stp"; git -C "$L_C" add -- "$stp" >/dev/null 2>&1
          rm -f "$L_C/local/demo.md"; rmdir "$L_C/local" 2>/dev/null; pcv_kback
          pcv_k2near PC-V32 k32 "a tracked symlink (alone: a fresh exit-0 render, record untouched, R2 named) whose ignored target is then edited" "steps/demo.md a regular file again"
          pcv_is_hit k32.nm "$L_REC" && k32_nmhit=1
        fi
      fi
    fi
    if [ -L "$L_C/$stp" ]; then rm -f "$L_C/$stp"; cp "$PS_D/k32-file.keep" "$L_C/$stp"; git -C "$L_C" add -- "$stp" >/dev/null 2>&1; fi
    rm -f "$L_C/local/demo.md"; rmdir "$L_C/local" 2>/dev/null; pcv_kback
  fi

  # V35 (F5): the EMPTY directory a bound fixture names is removed; git lists neither state. Near
  # miss: an empty directory outside every read root (tmp/scratch). V32's near miss, when it HIT, is
  # this arm's control: the same restored tree and record (the undo after it moves nothing, and a hit
  # writes no record), so the record is kept as pcv_kctl keeps it and pcv_kctl runs only otherwise.
  if { [ "$k32_nmhit" -eq 1 ] && cp "$L_REC" "$PS_D/krec.keep"; } || pcv_kctl PC-V35; then
    rmdir "$L_C/tests/fixtures/myfx"
    if pcv_k2miss PC-V35 k35 "removing the EMPTY tests/fixtures/myfx a bound extension names"; then
      mkdir -p "$L_C/tests/fixtures/myfx"; pcv_kback
      mkdir -p "$L_C/tmp/scratch"
      pcv_k2near PC-V35 k35 "removing the EMPTY tests/fixtures/myfx a bound extension names" "an empty tmp/scratch outside every read root"
      rmdir "$L_C/tmp/scratch" "$L_C/tmp"
    fi
    mkdir -p "$L_C/tests/fixtures/myfx"; pcv_kback
  fi

  # V36 (F6): a non-repository directory named `.git` under overrides/. A refusal arm: the empty
  # directory ALONE must record nothing, then an override beneath it must miss. The near miss is the
  # consumer's own top-level `.git`, present in every HIT control above and in the one after the undo.
  if pcv_kctl PC-V36; then
    mkdir -p "$L_C/.claude/skills/ai-dlc/overrides/.git"
    if pcv_krefuse PC-V36 k36 "a non-repository overrides/.git directory"; then
      printf -- '---\nshadows: steps/demo.md#gamma\n---\n\n## Gamma\n\nlocal\n' > "$L_C/.claude/skills/ai-dlc/overrides/.git/o.md"
      if pcv_k2miss PC-V36 k36 "an override under a non-repository overrides/.git"; then
        mv "$L_C/.claude/skills/ai-dlc/overrides/.git" "$PS_D/k36-dotgit-aside"; pcv_kback
        pcv_k2near PC-V36 k36 "an empty overrides/.git recorded nothing, and an override under it" "only the top-level .git, after the undo"
      fi
    fi
    [ -d "$L_C/.claude/skills/ai-dlc/overrides/.git" ] && mv "$L_C/.claude/skills/ai-dlc/overrides/.git" "$PS_D/k36-dotgit-aside2"
    pcv_kback
  fi
  return 0
}
# V33 (F2), its own world: `* text=auto` committed. A CRLF save of the installed steps/demo.md, once
# staged, is the same LF blob, so index and status are clean while the detectors cmp the CRLF bytes.
# Near miss: the LF file staged again after the record, the common consumer state. Staged by path,
# never `add -A`, which would stage the report file too.
pcv_k3world() {
  local stp=".claude/skills/ai-dlc/steps/demo.md"
  pcv_lat k3 || { pcv_x PC-V33 "FIXTURE BROKEN: layer-adjudication-tier/seed.sh did not build its world"; return 0; }
  printf '* text=auto\n' >> "$L_C/.gitattributes" \
    && { git -C "$L_C" add .gitattributes && git -C "$L_C" -c user.email=f@f -c user.name=fixture commit -qm k3seed; } >/dev/null 2>&1 \
    || { pcv_x PC-V33 "FIXTURE BROKEN: could not commit * text=auto"; return 0; }
  pcv_lat_approve k3 || { pcv_x PC-V33 "FIXTURE BROKEN: the world rendered no region"; return 0; }
  pcv_run k3.r "$L_C" "$L_R" "$L_D" "$L_B" "$L_T"
  if ! { pcv_is_miss 0 && [ -f "$L_REC" ]; }; then
    pcv_x PC-V33 "control: the world's first --verify did not render and record ($(pcv_why))"; return 0
  fi
  pcv_kctl PC-V33 || return 0
  cp "$L_C/$stp" "$PS_D/k33-lf.keep"
  awk '{ printf "%s\r\n", $0 }' "$PS_D/k33-lf.keep" > "$L_C/$stp"
  git -C "$L_C" add -- "$stp" >/dev/null 2>&1
  if pcv_k2miss PC-V33 k33 "a CRLF save of steps/demo.md, staged under * text=auto (index and status clean)"; then
    cp "$PS_D/k33-lf.keep" "$L_C/$stp"; git -C "$L_C" add -- "$stp" >/dev/null 2>&1; pcv_kback
    pcv_k2near PC-V33 k33 "a CRLF save of steps/demo.md, staged under * text=auto (index and status clean)" "the LF file staged again under * text=auto"
  fi
  return 0
}
# V37 (F3), its own world: the consumer sets core.checkStat=minimal and core.trustctime=false before the
# record, then rewrites steps/demo.md in place at the same size and puts its mtime back. Plain status
# trusts the stat entry; the key's forced options do not. Near miss: the same config, no file touched,
# which is the HIT control itself.
pcv_k5world() {
  local stp=".claude/skills/ai-dlc/steps/demo.md"
  pcv_lat k5 || { pcv_x PC-V37 "FIXTURE BROKEN: layer-adjudication-tier/seed.sh did not build its world"; return 0; }
  git -C "$L_C" config core.checkStat minimal && git -C "$L_C" config core.trustctime false \
    || { pcv_x PC-V37 "FIXTURE BROKEN: could not set core.checkStat and core.trustctime"; return 0; }
  pcv_lat_approve k5 || { pcv_x PC-V37 "FIXTURE BROKEN: the world rendered no region"; return 0; }
  pcv_run k5.r "$L_C" "$L_R" "$L_D" "$L_B" "$L_T"
  if ! { pcv_is_miss 0 && [ -f "$L_REC" ]; }; then
    pcv_x PC-V37 "control: the world's first --verify did not render and record ($(pcv_why))"; return 0
  fi
  pcv_kctl PC-V37 || return 0
  touch -r "$L_C/$stp" "$PS_D/k37-stamp"
  sed 's/Alpha/Alphx/' "$L_C/$stp" > "$PS_D/k37-edit"
  if cmp -s "$PS_D/k37-edit" "$L_C/$stp" || [ "$(wc -c < "$PS_D/k37-edit")" -ne "$(wc -c < "$L_C/$stp")" ]; then
    pcv_x PC-V37 "FIXTURE BROKEN: the in-place rewrite changed nothing, or changed the size"; return 0
  fi
  cat "$PS_D/k37-edit" > "$L_C/$stp" && touch -r "$PS_D/k37-stamp" "$L_C/$stp"
  if pcv_k2miss PC-V37 k37 "a same-size, mtime-kept rewrite of steps/demo.md under core.checkStat=minimal and core.trustctime=false"; then
    pcv_v PC-V37 "a same-size, mtime-kept rewrite under core.checkStat=minimal and core.trustctime=false MISSES with the opt-out render's exit $K_NC, and the near miss (the same config, no file touched) HIT as the control"
  fi
  return 0
}
# V34 (F4), its own world: two dist commits move core/git-hooks/pre-push, which map_consumer sends to
# .githooks/, and the consumer IGNORES .githooks/ and build/. The ignored hook is edited after the
# record. Near miss: an ignored build/x, under no read root.
pcv_k4world() {
  pcv_lat k4 || { pcv_x PC-V34 "FIXTURE BROKEN: layer-adjudication-tier/seed.sh did not build its world"; return 0; }
  mkdir -p "$L_DW/core/git-hooks" "$L_C/.githooks" \
    && printf '#!/bin/sh\necho v1\n' > "$L_DW/core/git-hooks/pre-push" \
    && { git -C "$L_DW" add -A && git -C "$L_DW" -c user.email=f@f -c user.name=fixture commit -qm hookv1; } >/dev/null 2>&1 \
    && printf '#!/bin/sh\necho v2\n' > "$L_DW/core/git-hooks/pre-push" \
    && { git -C "$L_DW" add -A && git -C "$L_DW" -c user.email=f@f -c user.name=fixture commit -qm hookv2; } >/dev/null 2>&1 \
    && git -C "$L_D" fetch -q "$L_DW" '+refs/heads/*:refs/heads/*' >/dev/null 2>&1 \
    && L_B="$(git -C "$L_D" rev-parse HEAD~1)" && L_T="$(git -C "$L_D" rev-parse HEAD)" \
    && printf '#!/bin/sh\necho v1\n' > "$L_C/.githooks/pre-push" \
    && printf '.githooks/\nbuild/\n' >> "$L_C/.gitignore" \
    && { git -C "$L_C" add .gitignore && git -C "$L_C" -c user.email=f@f -c user.name=fixture commit -qm k4seed; } >/dev/null 2>&1 \
    || { pcv_x PC-V34 "FIXTURE BROKEN: could not seed the hook commits and the ignored .githooks/"; return 0; }
  pcv_lat_approve k4 || { pcv_x PC-V34 "FIXTURE BROKEN: the world rendered no region"; return 0; }
  pcv_run k4.r "$L_C" "$L_R" "$L_D" "$L_B" "$L_T"
  if ! { pcv_is_miss 0 && [ -f "$L_REC" ]; }; then
    pcv_x PC-V34 "control: the world's first --verify did not render and record ($(pcv_why))"; return 0
  fi
  pcv_kctl PC-V34 || return 0
  cp "$L_C/.githooks/pre-push" "$PS_D/k34-hook.keep"
  printf '#!/bin/sh\necho v1\necho local guard\n' > "$L_C/.githooks/pre-push"
  if pcv_k2miss PC-V34 k34 "an edit to an IGNORED .githooks/pre-push, a map_consumer destination"; then
    cp "$PS_D/k34-hook.keep" "$L_C/.githooks/pre-push"; pcv_kback
    mkdir -p "$L_C/build" && printf 'artifact\n' > "$L_C/build/x"
    pcv_k2near PC-V34 k34 "an edit to an IGNORED .githooks/pre-push, a map_consumer destination" "an ignored build/x under no read root"
  fi
  return 0
}

# ---- V38 (R1) and V39 (R2), in the MAIN world after every other main-world arm ----
# pcv_r6refuse <tag> <Rn> -- the cached run with the condition in place must be a FRESH exit-0 render
# (the opt-out's exit, which must be 0 so the record would be rewritten by a key that did not refuse),
# leave the record byte-identical to the control's copy, and name the refusal on stderr. Sets R6_WHY.
pcv_r6refuse() {
  pcm "$1"; R6_WHY="$(pcv_why)"; local rc="$PRC" hit="$PHIT" n="$PN" rec=REWRITTEN nc
  cmp -s "$PC_REC" "$PS_D/rec.keep" && rec=unchanged
  pcm "$1.n" nocache; nc="$PRC"; PRC="$rc"; PHIT="$hit"; PN="$n"
  R6_WHY="$R6_WHY, opt-out $nc, record $rec"
  pcv_is_miss 0 && [ "$nc" -eq 0 ] && [ "$rec" = unchanged ] && grep -qF "${PCV_R6MARK}$2" "$PS_D/$1.err"
}
pcv_r6world() {
  # V38 R1: the same dist as a NON-BARE work-tree repo (the copy the mirror was cloned from), run
  # TWICE. A key without R1 records on the first run and HITS on the second; with R1 both render
  # fresh and the record stays byte-identical. Near miss: the bare mirror HITS (the control).
  if ! pcv_ctl v38; then pcv_noctl PC-V38; else
    pcv_run v38a "$PC_C" "$PC_R" "$PC_DW" "$BASE" "$THEIRS"; v38a="$(pcv_why)"; v38a_ok=0
    pcv_is_miss 0 && cmp -s "$PC_REC" "$PS_D/rec.keep" && grep -qF "${PCV_R6MARK}R1" "$PS_D/v38a.err" && v38a_ok=1
    pcv_run v38b "$PC_C" "$PC_R" "$PC_DW" "$BASE" "$THEIRS"; v38b="$(pcv_why)"
    v38_rec=REWRITTEN; cmp -s "$PC_REC" "$PS_D/rec.keep" && v38_rec=unchanged
    if [ "$v38a_ok" -eq 1 ] && pcv_is_miss 0 && [ "$v38_rec" = unchanged ]; then
      pcv_v PC-V38 "a NON-BARE dist renders fresh on two runs in a row (exit 0, R1 named, record untouched), and the bare mirror of the same repository HITS"
    else
      pcv_x PC-V38 "non-bare dist: first [$v38a], second [$v38b], record $v38_rec (want two fresh exit-0 renders naming R1, record untouched)"
    fi
    pcv_back
  fi

  # V39 R2: four shapes, each a refusal with the link in place and a HIT once it is gone. Every link
  # is one a key without R2 would have followed silently or keyed by its target's bytes: the two
  # root links are IGNORED (info/exclude), so `ls-files -o -i -- <root>` lists nothing through them.
  local ex="$PC_C/.git/info/exclude" fails="" why=""
  mkdir -p "$PC_C/.git/info" && touch "$ex" && cp "$ex" "$PS_D/exclude.keep"
  mkdir -p "$PS_D/r6-out/ai-dlc/extensions"
  # (a) a read root that IS a symlink: skills/ai-dlc/extensions -> an empty outside dir.
  if ! pcv_ctl v39a; then fails="$fails a:control"; else
    mkdir -p "$PC_C/skills/ai-dlc" && ln -s "$PS_D/r6-out/ai-dlc/extensions" "$PC_C/skills/ai-dlc/extensions" \
      && printf '/skills/\n' >> "$ex"
    pcv_r6refuse v39a R2 || { fails="$fails a"; why="$why a[$R6_WHY]"; }
    rm -f "$PC_C/skills/ai-dlc/extensions"; rmdir "$PC_C/skills/ai-dlc" "$PC_C/skills"; cp "$PS_D/exclude.keep" "$ex"; pcv_back
  fi
  # (b) a symlinked PARENT of a read root: skills -> an outside dir holding ai-dlc/extensions.
  if ! pcv_ctl v39b; then fails="$fails b:control"; else
    ln -s "$PS_D/r6-out" "$PC_C/skills" && printf '/skills\n' >> "$ex"
    pcv_r6refuse v39b R2 || { fails="$fails b"; why="$why b[$R6_WHY]"; }
    rm -f "$PC_C/skills"; cp "$PS_D/exclude.keep" "$ex"; pcv_back
  fi
  # (c) an IGNORED symlink under a read root: .claude/r6-link -> notes/pc-v4.txt.
  if ! pcv_ctl v39c; then fails="$fails c:control"; else
    ln -s ../notes/pc-v4.txt "$PC_C/.claude/r6-link" && printf '/.claude/r6-link\n' >> "$ex"
    pcv_r6refuse v39c R2 || { fails="$fails c"; why="$why c[$R6_WHY]"; }
    rm -f "$PC_C/.claude/r6-link"; cp "$PS_D/exclude.keep" "$ex"; pcv_back
  fi
  # (d) a TRACKED symlink outside every read root: notes/r6-tracked -> pc-v4.txt, staged by path.
  if ! pcv_ctl v39d; then fails="$fails d:control"; else
    ln -s pc-v4.txt "$PC_C/notes/r6-tracked" && git -C "$PC_C" add -- notes/r6-tracked >/dev/null 2>&1
    pcv_r6refuse v39d R2 || { fails="$fails d"; why="$why d[$R6_WHY]"; }
    git -C "$PC_C" rm -q --cached -- notes/r6-tracked >/dev/null 2>&1; rm -f "$PC_C/notes/r6-tracked"; pcv_back
  fi
  # The near miss for (d), and the undo of every shape: the tree without any link HITS.
  pcm v39h
  if [ -z "$fails" ] && pcv_is_hit v39h "$PC_REC"; then
    pcv_v PC-V39 "a symlinked read root, a symlinked parent of one, an ignored symlink under one and a tracked symlink each MISS by refusal (fresh exit-0 render, record untouched, R2 named), and the same tree without the link HITS"
  else
    pcv_x PC-V39 "symlink refusals failed [${fails# }]${why}; after every undo [$(pcv_why)] (want four R2 refusals and then a hit)"
  fi
}

# ---- V56 (cksum) and V57 (the sha256 tool): the KEY's own tools absent (BL-777) ----
# Each PATH REPLACES the fixture's own: pcv_run only PREPENDS $PS_SHIM, and on macOS every tool sits in
# /usr/bin beside cksum, so no PATH entry can be dropped. The arm sets PATH to a FARM -- a directory of
# symlinks to every tool the current PATH resolves (first wins, as PATH resolves), minus the dropped
# names -- so every run reads exactly `$PS_SHIM:<farm>`, and the discrimination check runs under that
# same composed PATH: the dropped tools must not resolve and awk, sed, sort and git must, else FIXTURE
# BROKEN, never PASS.
# THE WORLD CARRIES NO layer-adjudication-register. With one, layer-drift.sh pipes its digest cache key
# through cksum (layer-drift.sh:1227), so a cksum-less PATH would change the RENDER and not only the key.
# The main world has none (seed.sh writes none); checked below rather than assumed.
# pcv_farm <dir> <name>... -- <dir> resolves every tool PATH does except <name>...
pcv_farm() {
  local t="$1" d n
  shift
  mkdir -p "$t" || return 1
  local IFS=:
  for d in $PATH; do
    [ -d "$d" ] && [ "$d" != "$t" ] && [ "$d" != "$PS_SHIM" ] && ln -s "$d"/* "$t"/ 2>/dev/null
  done
  for n in "$@"; do rm -f "$t/$n"; done
  return 0
}
# pcv_resolves <path> <tool>... -- 0 when every tool resolves under exactly <path>
pcv_resolves() {
  local p="$1" t
  shift
  for t in "$@"; do ( PATH="$p"; command -v "$t" >/dev/null 2>&1 ) || return 1; done
}
# pcv_resolvesnone <path> <tool>... -- 0 when no tool resolves under exactly <path>
pcv_resolvesnone() {
  local p="$1" t
  shift
  for t in "$@"; do ( PATH="$p"; command -v "$t" >/dev/null 2>&1 ) && return 1; done
  return 0
}
# pcv_markcause <err> <cause> -- 0 when <err> carries the refusal line WHOLE: the mark, then the cause,
# then nothing, and at least one character follows the mark (so an empty cause can never pass).
pcv_markcause() {
  grep -qxF "${PCV_R6MARK}$2" "$1" \
    && awk -v m="$PCV_R6MARK" 'index($0, m) == 1 && length($0) > length(m) { f = 1 } END { exit !f }' "$1"
}
pcv_r9world() {
  local reg="$PC_C/_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl"
  local fa="$PS_D/r9-nocksum" fb="$PS_D/r9-nosha" ck op a why nm nmok hok u0 u1 uok
  if [ -e "$reg" ]; then
    pcv_x PC-V56 "FIXTURE BROKEN: the main world carries $reg, so layer-drift.sh calls cksum in the render and a cksum-less PATH is not a key-only change"
    pcv_x PC-V57 "FIXTURE BROKEN: the main world carries $reg (see PC-V56)"
    return 0
  fi
  ck="$(command -v cksum 2>/dev/null)"
  # V56: no cksum. The refusal names it (a fresh exit-0 render, record untouched); the near miss is the
  # SAME farm plus a cksum link, which keys: no mark, the record rewritten, and the next run HITS. Then
  # the UNARMED run is byte-identical (stdout, stderr, exit) with and without the link.
  if [ -z "$ck" ] || ! pcv_farm "$fa" cksum || ! pcv_resolvesnone "$PS_SHIM:$fa" cksum \
     || ! pcv_resolves "$PS_SHIM:$fa" awk sed sort git; then
    pcv_x PC-V56 "FIXTURE BROKEN: the farm $fa does not lack cksum while resolving awk, sed, sort and git under PATH=\$PS_SHIM:$fa (or cksum is not on the fixture's own PATH)"
  elif ! pcv_ctl v56; then pcv_noctl PC-V56
  else
    op="$PATH"; PATH="$fa"
    a=0; pcv_r6refuse v56 "$PCV_R9CK" && pcv_markcause "$PS_D/v56.err" "$PCV_R9CK" && a=1; why="$R6_WHY"
    ln -s "$ck" "$fa/cksum"
    pcm v56n; nm="$(pcv_why)"; nmok=0
    pcv_is_miss 0 && ! cmp -s "$PC_REC" "$PS_D/rec.keep" && ! grep -qF "$PCV_R6MARK" "$PS_D/v56n.err" && nmok=1
    pcm v56h; hok=0; pcv_is_hit v56h "$PC_REC" && hok=1
    rm -f "$fa/cksum"
    PCV_ARM="-u EMIT_REPORT_VERIFY_CACHE"
    pcm v56u0; u0="$PRC"
    ln -s "$ck" "$fa/cksum"
    pcm v56u1; u1="$PRC"
    PCV_ARM=""; PATH="$op"; rm -f "$fa/cksum"
    uok=0
    [ "$u0" -eq 0 ] && [ "$u0" = "$u1" ] && [ "$(cat "$PS_D/v56u0.out")" = "$PCV_OKLINE" ] \
      && cmp -s "$PS_D/v56u0.out" "$PS_D/v56u1.out" && cmp -s "$PS_D/v56u0.err" "$PS_D/v56u1.err" && uok=1
    if [ "$a" -eq 1 ] && [ "$nmok" -eq 1 ] && [ "$hok" -eq 1 ] && [ "$uok" -eq 1 ]; then
      pcv_v PC-V56 "no cksum on PATH renders fresh (exit 0, record untouched) naming cksum as the cause; the same farm with a cksum link keys (no refusal, record rewritten, then a hit); the unarmed run is byte-identical with and without it"
    else
      pcv_x PC-V56 "cksum absent [$why, refusal $a, stderr: $(sed -n 1p "$PS_D/v56.err")]; near miss with cksum [$nm, ok $nmok, then hit $hok]; unarmed identity $uok (exits $u0/$u1) (want a named cksum refusal, a keyed near miss, and identical unarmed runs)"
    fi
    pcv_back
  fi
  # V57: neither shasum nor sha256sum. The per-field refusal's sha256-tool site names the absent tool.
  if ! pcv_farm "$fb" shasum sha256sum || ! pcv_resolvesnone "$PS_SHIM:$fb" shasum sha256sum \
     || ! pcv_resolves "$PS_SHIM:$fb" cksum awk sed sort git; then
    pcv_x PC-V57 "FIXTURE BROKEN: the farm $fb does not lack shasum and sha256sum while resolving cksum, awk, sed, sort and git under PATH=\$PS_SHIM:$fb"
  elif ! pcv_ctl v57; then pcv_noctl PC-V57
  else
    op="$PATH"; PATH="$fb"
    a=0; pcv_r6refuse v57 "$PCV_R9SHA" && pcv_markcause "$PS_D/v57.err" "$PCV_R9SHA" && a=1
    PATH="$op"
    if [ "$a" -eq 1 ]; then
      pcv_v PC-V57 "no sha256 tool on PATH renders fresh (exit 0, record untouched) naming the absent shasum/sha256sum as the cause"
    else
      pcv_x PC-V57 "sha256 tool absent [$R6_WHY, stderr: $(sed -n 1p "$PS_D/v57.err")] (want a fresh exit-0 render, record untouched, the absent tool named)"
    fi
    pcv_back
  fi
  return 0
}

# ---- V42 (B2): the DETECTORS hash a consumer file with --no-filters, run directly ----
# A CRLF consumer file, and `* text` in a NON-BARE dist's work-tree .gitattributes. preclassify.sh
# (file_hash) and layer-drift.sh (adj_digest) hash the consumer file through `git -C "$DIST"`; with
# --no-filters their output is the same with and without the attribute. The control is a copy of the
# reconcile directory with --no-filters removed from those two lines (the pre-fix spelling), whose
# output must DIFFER with the attribute -- proving the input discriminates.
pcv_b2world() {
  local b="$PS_D/b2" pe="$PS_D/b2eng" rec ok=1 why="" f
  mkdir -p "$b" && cp -R "$(dirname "$PS_E")" "$pe" || { pcv_x PC-V42 "FIXTURE BROKEN: could not copy the engine"; return 0; }
  # THE PRE-FIX SPELLING IS RESTORED AT EACH DETECTOR'S OWN CALL SITE, one line per detector. Both now
  # hash through consumer-read.sh's cr_hash, which hashes with --no-filters from the CALLER's cwd and
  # never through the dist; before that each hashed through `git -C "$DIST"` WITHOUT --no-filters,
  # where the dist work tree's attributes applied. Two distinct lines, so each half of this arm (the
  # preclassify half and the layer-drift half below) discriminates its own detector, and an edit to
  # cr_hash itself is not counted twice.
  for f in preclassify.sh:'cr_hash "$CONS" "$1"':'git -C "$DIST" hash-object "$CONS/$1"' \
           layer-drift.sh:'cr_hash "$CONSUMER" "$1"':'git -C "$DIST" hash-object "$CONSUMER/$1"'; do
    A="${f#*:}"; A="${A%%:*}"
    [ "$(grep -cF -- "$A" "$pe/${f%%:*}")" = 1 ] || { pcv_x PC-V42 "FIXTURE BROKEN: the call-site anchor of ${f%%:*} does not occur exactly once, so its pre-fix spelling would be ambiguous or absent"; return 0; }
    A="${f#*:}"; A="${A%%:*}" B="${f##*:}" awk '{ i = index($0, ENVIRON["A"]); if (i) $0 = substr($0, 1, i - 1) ENVIRON["B"] substr($0, i + length(ENVIRON["A"])); print }' \
      "$pe/${f%%:*}" > "$b/mut" && cat "$b/mut" > "$pe/${f%%:*}"
    cmp -s "$pe/${f%%:*}" "$(dirname "$PS_E")/${f%%:*}" && { pcv_x PC-V42 "FIXTURE BROKEN: the pre-fix spelling of ${f%%:*} did not apply"; return 0; }
  done
  # preclassify: the main seed's world, a work-tree dist copy, the consumer's moved-ref-probe.sh CRLF.
  cp -R "$DIST" "$b/dist" && cp -R "$CONSUMER" "$b/cons" || { pcv_x PC-V42 "FIXTURE BROKEN: could not copy the seeded world"; return 0; }
  f="$b/cons/scripts/ai-dlc/moved-ref-probe.sh"
  awk '{ printf "%s\r\n", $0 }' "$f" > "$b/crlf" && cat "$b/crlf" > "$f"
  pcv_b2pc() { "$PCV_BASH" "$1/preclassify.sh" "$b/dist" "$BASE" "$THEIRS" "$b/cons" > "$b/$2" 2>/dev/null; echo "$?" >> "$b/$2"; }
  pcv_b2pc "$(dirname "$PS_E")" pc-fix-plain; pcv_b2pc "$pe" pc-old-plain
  printf '* text\n' > "$b/dist/.gitattributes"
  [ "$(git -C "$b/dist" check-attr text -- scripts/x.sh 2>/dev/null)" = "scripts/x.sh: text: set" ] \
    || { pcv_x PC-V42 "FIXTURE BROKEN: the dist's work-tree * text attribute does not apply"; return 0; }
  pcv_b2pc "$(dirname "$PS_E")" pc-fix-attr; pcv_b2pc "$pe" pc-old-attr
  if ! grep -q 'moved-ref-probe' "$b/pc-fix-plain"; then ok=0; why="$why preclassify printed no moved-ref-probe row (FIXTURE BROKEN);"
  elif ! cmp -s "$b/pc-fix-plain" "$b/pc-fix-attr"; then ok=0; why="$why preclassify output moved with the dist attribute;"
  elif cmp -s "$b/pc-old-plain" "$b/pc-old-attr"; then ok=0; why="$why the pre-fix preclassify did not move either, so the input does not discriminate;"
  fi
  # layer-drift: an adjudication world, its work-tree dist, the entry's BODY in CRLF (the frontmatter
  # stays LF: its `---` lines are matched exactly).
  if ! pcv_lat b2l; then ok=0; why="$why layer-adjudication-tier/seed.sh did not build its world;"
  else
    f="$L_C/.claude/skills/ai-dlc/extensions/adjudicable.md"
    awk 'NR == 1 && $0 == "---" { fm = 1; print; next } fm && $0 == "---" { fm = 0; print; next } fm { print; next } { printf "%s\r\n", $0 }' "$f" > "$b/ent" && cat "$b/ent" > "$f"
    pcv_b2ld() { "$PCV_BASH" "$1/layer-drift.sh" "$L_DW" "$L_B" "$L_T" "$L_C" > "$b/$2" 2>/dev/null; echo "$?" >> "$b/$2"; }
    pcv_b2ld "$(dirname "$PS_E")" ld-fix-plain; pcv_b2ld "$pe" ld-old-plain
    printf '* text\n' > "$L_DW/.gitattributes"
    pcv_b2ld "$(dirname "$PS_E")" ld-fix-attr; pcv_b2ld "$pe" ld-old-attr
    if ! grep -q 'subject_digest [0-9a-f]\{40\}' "$b/ld-fix-plain"; then ok=0; why="$why layer-drift printed no subject_digest (FIXTURE BROKEN);"
    elif ! cmp -s "$b/ld-fix-plain" "$b/ld-fix-attr"; then ok=0; why="$why layer-drift output moved with the dist attribute;"
    elif cmp -s "$b/ld-old-plain" "$b/ld-old-attr"; then ok=0; why="$why the pre-fix layer-drift did not move either, so the input does not discriminate;"
    fi
  fi
  if [ "$ok" -eq 1 ]; then
    pcv_v PC-V42 "preclassify.sh and layer-drift.sh print the same output for a CRLF consumer file with and without * text in a non-bare dist's work-tree .gitattributes, and the pre-fix spelling (no --no-filters) prints a different one"
  else
    pcv_x PC-V42 "the detectors' --no-filters:${why}"
  fi
  return 0
}

# ---- V43 RETIRED (round 8). Its subject was er_receipt_rows, the receipts field's LEXICAL normaliser,
# which the round-8 fix deleted on purpose: collapsing `x/..` into one label WAS the B3 defect. Its
# property -- two receipt spellings that differ only through `..` segments never let a recorded PASS
# answer for the wrong path -- is held by PC-V51, whose hole world seeds exactly
# `docs/r8a/../r8d docs/r8b/../r8d` and asserts no stale HIT when the prefix directory moves, on either
# engine (the fixed one refuses every `..` token by name in consumer-read.sh's guard).

# ---- V44..V47: the round-7 partition in the MAIN world, each arm re-approved and recorded alone ----
# pcv_r7rec <tag> -- re-render the region into the report, run once (exit 0, a record exists) and
# again (a HIT); keeps the record as <tag>.rec. Non-zero when either step fails.
pcv_r7rec() {
  "$PCV_BASH" "$PS_E" "$PC_D" "$BASE" "$PC_C" "$THEIRS" > "$PS_D/region-$1.md" 2>/dev/null
  { echo "# Reconcile report (fixture)"; echo; cat "$PS_D/region-$1.md"; } > "$PC_R"
  grep -q 'reconcile-mechanical' "$PS_D/region-$1.md" || return 1
  pcm "$1.r"; pcv_is_miss 0 && [ -f "$PC_REC" ] || return 1
  pcm "$1.c"; pcv_is_hit "$1.c" "$PC_REC" || return 1
  cp "$PC_REC" "$PS_D/$1.rec"
}
# pcv_r7miss <tag> -- the cached run, then the opt-out on the same tree. 0 when the opt-out exits
# non-zero and the cached run is a fresh render with that exit. Sets R7_WHY.
pcv_r7miss() {
  local rc hit n nc
  pcm "$1"; rc="$PRC"; hit="$PHIT"; n="$PN"; R7_WHY="$(pcv_why)"
  pcm "$1.n" nocache; nc="$PRC"; PRC="$rc"; PHIT="$hit"; PN="$n"
  R7_WHY="$R7_WHY, opt-out $nc"
  [ "$nc" -ne 0 ] && pcv_is_miss "$nc"
}
pcv_r7world() {
  local ex="$PC_C/.git/info/exclude" lg="$PC_C/_bmad-output/ai-dlc-update/push-candidate-ledger.md"
  local fails why s ext="$PC_C/.claude/skills/ai-dlc/extensions" wtl
  mkdir -p "$PC_C/.git/info" && touch "$ex" && cp "$ex" "$PS_D/r7-exclude.keep" \
    && cp "$lg" "$PS_D/r7-ledger.keep" && cp "$PC_R" "$PS_D/r7-report.keep" && cp "$PC_REC" "$PS_D/r7-rec.keep" \
    || { for s in PC-V44 PC-V45 PC-V46 PC-V47; do pcv_x "$s" "FIXTURE BROKEN: could not keep the main world's exclude, ledger, report and record"; done; return 0; }

  # V44 (B2): one live receipt names three subjects no other field reads -- an untracked EMPTY
  # directory (docs/r7-empty), an IGNORED file outside every read root (docs/r7-ign.local), and a path
  # under an IGNORED .claude/worktrees/ (every field prunes it). All present at the record; each
  # removed in turn MISSES with the opt-out's exit, and put back HITS the same record.
  if pcv_in PC-V44; then
    fails=""; why=""
    printf '/docs/r7-ign.local\n/.claude/worktrees/\n' >> "$ex"
    mkdir -p "$PC_C/docs/r7-empty" "$PC_C/.claude/worktrees/r7wt" && : > "$PC_C/docs/r7-ign.local" && : > "$PC_C/.claude/worktrees/r7wt/f"
    { cat "$PS_D/r7-ledger.keep"; printf '\n## PC-FIXTURE-R7-SUBJECTS — a receipt naming three unkeyed subjects\n\nverify: sh exit 1; : docs/r7-empty docs/r7-ign.local .claude/worktrees/r7wt\n'; } > "$lg"
    if ! git -C "$PC_C" check-ignore -q docs/r7-ign.local || ! git -C "$PC_C" check-ignore -q .claude/worktrees/r7wt/f; then
      pcv_x PC-V44 "FIXTURE BROKEN: docs/r7-ign.local or .claude/worktrees/r7wt/f is not ignored, so another field keys it"
    elif ! pcv_r7rec v44; then
      pcv_x PC-V44 "control: the world with all three subjects present did not record and then HIT ($(pcv_why))"
    else
      for s in emptydir ignored worktree; do
        case "$s" in
          emptydir) rmdir "$PC_C/docs/r7-empty" ;;
          ignored)  rm -f "$PC_C/docs/r7-ign.local" ;;
          worktree) rm -f "$PC_C/.claude/worktrees/r7wt/f"; rmdir "$PC_C/.claude/worktrees/r7wt" ;;
        esac
        pcv_r7miss "v44$s" || { fails="$fails $s"; why="$why $s[$R7_WHY]"; }
        case "$s" in
          emptydir) mkdir -p "$PC_C/docs/r7-empty" ;;
          ignored)  : > "$PC_C/docs/r7-ign.local" ;;
          worktree) mkdir -p "$PC_C/.claude/worktrees/r7wt" && : > "$PC_C/.claude/worktrees/r7wt/f" ;;
        esac
        cp "$PS_D/v44.rec" "$PC_REC"
        pcm "v44${s}h"; pcv_is_hit "v44${s}h" "$PC_REC" || { fails="$fails $s:back"; why="$why $s:back[$(pcv_why)]"; }
      done
      if [ -z "$fails" ]; then
        pcv_v PC-V44 "a receipt subject that is an empty directory, an ignored file outside the read roots, or a path under an ignored .claude/worktrees/ MISSES when removed (fresh render, the opt-out's exit), and put back HITS"
      else
        pcv_x PC-V44 "receipt subjects failed [${fails# }]${why} (want a miss with the opt-out's non-zero exit, then a hit once restored)"
      fi
    fi
    rm -f "$PC_C/docs/r7-ign.local" "$PC_C/.claude/worktrees/r7wt/f"; rmdir "$PC_C/docs/r7-empty" "$PC_C/.claude/worktrees/r7wt" "$PC_C/.claude/worktrees" 2>/dev/null
    cat "$PS_D/r7-ledger.keep" > "$lg"; cp "$PS_D/r7-exclude.keep" "$ex"
  fi

  # V45 (B3): a LINKED WORKTREE of the bare dist, detached at an unreferenced commit. X adds
  # core/fixtures/r7zz on top of theirs and Y removes it; both are made by commit-tree BEFORE the
  # record (the object count moves the keyed abbrev length). The consumer carries tests/fixtures/r7zz.
  # With the worktree at Y, retired-fixtures.sh's `log --all` finds the fixture's history and renders
  # RETIRED-FIXTURE-ORPHAN; no ref and not the main HEAD moved. Near miss: the worktree removed and
  # pruned, the same tree, HITS.
  if pcv_in PC-V45; then
    local ix="$PS_D/r7-idx" bl tr x y
    mkdir -p "$PC_C/tests/fixtures/r7zz" && printf 'echo zz\n' > "$PC_C/tests/fixtures/r7zz/run.sh"
    x=""; y=""
    if GIT_INDEX_FILE="$ix" git -C "$PC_D" read-tree "$THEIRS" >/dev/null 2>&1 \
       && bl="$(printf 'echo zz\n' | git -C "$PC_D" hash-object -w --stdin)" \
       && GIT_INDEX_FILE="$ix" git -C "$PC_D" update-index --add --cacheinfo 100644 "$bl" core/fixtures/r7zz/run.sh >/dev/null 2>&1 \
       && tr="$(GIT_INDEX_FILE="$ix" git -C "$PC_D" write-tree)" \
       && x="$(git -C "$PC_D" -c user.email=f@f -c user.name=fixture commit-tree "$tr" -p "$THEIRS" -m r7zz-added)" \
       && y="$(git -C "$PC_D" -c user.email=f@f -c user.name=fixture commit-tree "${THEIRS}^{tree}" -p "$x" -m r7zz-removed)"; then :; fi
    git -C "$PC_D" for-each-ref > "$PS_D/r7-refs0" 2>&1
    if [ -z "$y" ]; then
      pcv_x PC-V45 "FIXTURE BROKEN: could not build the unreferenced commits that add and remove core/fixtures/r7zz"
    elif ! pcv_r7rec v45; then
      pcv_x PC-V45 "control: the world with the unreferenced commits and no worktree did not record and then HIT ($(pcv_why))"
    elif ! git -C "$PC_D" worktree add -q --detach "$PS_D/r7-dwt" "$y" >/dev/null 2>&1; then
      pcv_x PC-V45 "FIXTURE BROKEN: git worktree add on the bare dist failed"
    else
      git -C "$PC_D" for-each-ref > "$PS_D/r7-refs1" 2>&1
      wtl="$(git -C "$PC_D" worktree list --porcelain 2>/dev/null)" || wtl=""
      if ! cmp -s "$PS_D/r7-refs0" "$PS_D/r7-refs1" || ! grep -qF "HEAD $y" <<< "$wtl"; then
        pcv_x PC-V45 "FIXTURE BROKEN: the worktree moved a ref, or git worktree list does not show its HEAD at Y"
      elif ! pcv_r7miss v45; then
        pcv_x PC-V45 "a linked dist worktree detached at an unreferenced commit did not force a fresh render: [$R7_WHY] -- a recorded PASS answered for a history it never keyed"
      else
        git -C "$PC_D" worktree remove --force "$PS_D/r7-dwt" >/dev/null 2>&1; git -C "$PC_D" worktree prune >/dev/null 2>&1
        cp "$PS_D/v45.rec" "$PC_REC"
        pcm v45h
        if pcv_is_hit v45h "$PC_REC"; then
          pcv_v PC-V45 "a linked worktree of the bare dist at an unreferenced commit MISSES (fresh render, the opt-out's exit), and the same tree with the worktree removed HITS"
        else
          pcv_x PC-V45 "near miss (the worktree removed and pruned) did not HIT: [$(pcv_why)]"
        fi
      fi
    fi
    git -C "$PC_D" worktree remove --force "$PS_D/r7-dwt" >/dev/null 2>&1; git -C "$PC_D" worktree prune >/dev/null 2>&1
    rm -f "$PC_C/tests/fixtures/r7zz/run.sh"; rmdir "$PC_C/tests/fixtures/r7zz" 2>/dev/null
  fi

  # V46 (B4): an extension's `fixtures: ../../docs/r7fx` escapes tests/fixtures/. layer-drift.sh, the
  # one reader of the value, now renders EXTENSION-FIXTURE-UNBOUND naming the escape and never tests
  # the path, so the render cannot depend on it: recorded, it HITS, and after creating docs/r7fx the
  # cached run still HITS while the opt-out render exits 0 (the read is gone; the pre-fix reader would
  # exit 1 here). Near miss: `fixtures: r7fx` inside tests/fixtures/, its EMPTY directory present, records
  # and HITS, and removing that directory MISSES with the opt-out's exit.
  # WHY A ROW AND NOT A REFUSAL: layer-drift's only refusal form, `layer-drift: REFUSED` with exit 1,
  # makes apply.sh withhold the re-stamp, so a typo in `fixtures:` would block the whole pull.
  # Removing the read beats refusing around it: the render no longer depends on the escaping path,
  # so the key needs nothing for it.
  if [ "$PCV_R7LD" -eq 1 ] && pcv_in PC-V46; then
    local e46="$ext/r7fx.md" nc46
    # tests/fixtures/ MUST EXIST for this arm to discriminate: without it the pre-fix reader's
    # `[ -d tests/fixtures/../../docs/r7fx ]` cannot resolve in the OS, both readers render UNBOUND,
    # and creating docs/r7fx moves nothing (adv7's p4a, against p5a which seeded tests/fixtures/keep).
    mkdir -p "$PC_C/tests/fixtures"
    mkdir -p "$ext" && printf -- '---\nhooks: templates/classes.md\nfixtures: ../../docs/r7fx\n---\n\nbody\n' > "$e46"
    if ! pcv_r7rec v46; then
      pcv_x PC-V46 "control: the world with an escaping fixtures: value did not record and then HIT ($(pcv_why))"
    elif ! grep -q '^EXTENSION-FIXTURE-UNBOUND' "$PS_D/region-v46.md"; then
      pcv_x PC-V46 "the approval carries no EXTENSION-FIXTURE-UNBOUND row for the escaping value"
    else
      mkdir -p "$PC_C/docs/r7fx"
      pcm v46t; v46t="$(pcv_why)"; v46t_ok=0; pcv_is_hit v46t "$PC_REC" && v46t_ok=1
      pcm v46t.n nocache; nc46="$PRC"
      rmdir "$PC_C/docs/r7fx"
      if [ "$v46t_ok" -ne 1 ] || [ "$nc46" -ne 0 ]; then
        pcv_x PC-V46 "creating docs/r7fx under an escaping fixtures: value: cached [$v46t], opt-out $nc46 (want a HIT and an opt-out exit 0: the escaping path must not be read)"
      else
        mkdir -p "$PC_C/tests/fixtures/r7fx"
        printf -- '---\nhooks: templates/classes.md\nfixtures: r7fx\n---\n\nbody\n' > "$e46"
        if ! pcv_r7rec v46n; then
          pcv_x PC-V46 "near miss (fixtures: r7fx inside, its directory present) did not record and then HIT ($(pcv_why))"
        else
          rmdir "$PC_C/tests/fixtures/r7fx"
          if pcv_r7miss v46m; then
            pcv_v PC-V46 "an escaping fixtures: ../../docs/r7fx renders UNBOUND without a read (creating docs/r7fx HITS, opt-out exit 0), and fixtures: r7fx inside records, HITS, and MISSES with the opt-out's exit when its directory goes"
          else
            pcv_x PC-V46 "near miss: removing the EMPTY tests/fixtures/r7fx a bound extension names did not force a fresh render: [$R7_WHY]"
          fi
        fi
      fi
    fi
    rm -f "$e46"; rmdir "$PC_C/tests/fixtures/r7fx" "$PC_C/docs/r7fx" 2>/dev/null
  fi

  # V47 (D3): a NON-IGNORED .claude/worktrees/agent-r7/ holding its own `.git`. conswork's
  # `ls-files -o` lists it with a trailing `/`, and er_hash_list now refuses it by name: a fresh render
  # whose exit equals the opt-out's, the record byte-identical, stderr naming the cause. Near miss: the
  # same directory IGNORED through info/exclude (which no field keys) HITS the record taken before it.
  # That HIT needs consignored's prefix filter: `ls-files -o -i -- .claude` lists the ignored nested
  # repo as `.claude/worktrees/agent-r7/` despite its `:(exclude)` pathspec, and without the filter
  # er_hash_list refused it there, on every run. With it, the entry is dropped before hashing, conswork
  # no longer lists it (ignored), and every find guard prunes the path, so no field sees it.
  if pcv_in PC-V47; then
    local nl47 c47
    if ! pcv_r7rec v47; then
      pcv_x PC-V47 "control: the world before the worktree directory did not record and then HIT ($(pcv_why))"
    else
      mkdir -p "$PC_C/.claude/worktrees/agent-r7" && git init -q "$PC_C/.claude/worktrees/agent-r7" >/dev/null 2>&1 \
        && : > "$PC_C/.claude/worktrees/agent-r7/f"
      nl47="$(git -C "$PC_C" ls-files -o --exclude-standard -- .claude/worktrees 2>/dev/null)" || nl47=""
      if ! grep -qxF '.claude/worktrees/agent-r7/' <<< "$nl47"; then
        pcv_x PC-V47 "FIXTURE BROKEN: ls-files -o does not list .claude/worktrees/agent-r7/ with a trailing /, so the refusal cannot be reached"
      else
        pcm v47; v47="$(pcv_why)"; c47="$PRC"; v47_hit="$PHIT"; v47_n="$PN"
        v47_rec=REWRITTEN; cmp -s "$PC_REC" "$PS_D/v47.rec" && v47_rec=unchanged
        pcm v47.n nocache; v47_nc="$PRC"; PRC="$c47"; PHIT="$v47_hit"; PN="$v47_n"
        if ! { pcv_is_miss "$v47_nc" && [ "$v47_rec" = unchanged ] && grep -qF "${PCV_R6MARK}${PCV_R7MARK}.claude/worktrees/agent-r7/" "$PS_D/v47.err"; }; then
          pcv_x PC-V47 "a non-ignored .claude/worktrees/agent-r7/: [$v47], opt-out $v47_nc, record $v47_rec (want a fresh render with the opt-out's exit, record untouched, stderr naming the directory refusal)"
        else
          cp "$PS_D/v47.rec" "$PC_REC"
          printf '/.claude/worktrees/\n' >> "$ex"
          pcm v47h
          if ! pcv_is_hit v47h "$PC_REC"; then
            pcv_x PC-V47 "near miss (the same directory ignored through info/exclude) did not HIT: [$(pcv_why)]"
          else
            # THE PREFIX IS ANCHORED: consignored drops `.claude/worktrees/` and nothing that merely
            # shares its letters. Two IGNORED near misses, `.claude/worktreesX/f` and
            # `.claude/notworktrees/f`, are seeded beside the still-ignored agent-r7 and recorded; editing
            # either must be a fresh render whose exit equals the opt-out's (a key that dropped it would
            # HIT), and putting it back HITS. The render does not read either file, so its exit may be 0.
            local s47 f47 n47 r47 v47k=""
            printf '/.claude/worktreesX/\n/.claude/notworktrees/\n' >> "$ex"
            mkdir -p "$PC_C/.claude/worktreesX" "$PC_C/.claude/notworktrees"
            printf 'one\n' > "$PC_C/.claude/worktreesX/f"; printf 'one\n' > "$PC_C/.claude/notworktrees/f"
            if ! git -C "$PC_C" check-ignore -q .claude/worktreesX/f || ! git -C "$PC_C" check-ignore -q .claude/notworktrees/f; then
              v47k=" FIXTURE BROKEN: a near-miss file is not ignored"
            elif ! pcv_r7rec v47k; then
              v47k=" control: the world with the ignored worktree and both near misses did not record and then HIT ($(pcv_why))"
            else
              for s47 in worktreesX notworktrees; do
                f47="$PC_C/.claude/$s47/f"
                printf 'two\n' > "$f47"
                pcm "v47$s47"; r47="$(pcv_why)"; c47="$PRC"; v47_hit="$PHIT"; v47_n="$PN"
                pcm "v47$s47.n" nocache; n47="$PRC"; PRC="$c47"; PHIT="$v47_hit"; PN="$v47_n"
                pcv_is_miss "$n47" || v47k="$v47k $s47[$r47, opt-out $n47]"
                printf 'one\n' > "$f47"; cp "$PS_D/v47k.rec" "$PC_REC"
                pcm "v47${s47}h"; pcv_is_hit "v47${s47}h" "$PC_REC" || v47k="$v47k $s47:back[$(pcv_why)]"
              done
            fi
            rm -f "$PC_C/.claude/worktreesX/f" "$PC_C/.claude/notworktrees/f"
            rmdir "$PC_C/.claude/worktreesX" "$PC_C/.claude/notworktrees" 2>/dev/null
            if [ -z "$v47k" ]; then
              pcv_v PC-V47 "a non-ignored .claude/worktrees/agent-r7/ MISSES by a named refusal (fresh render, exit $v47_nc as the opt-out, record untouched), the same directory ignored HITS, and ignored .claude/worktreesX/f and .claude/notworktrees/f stay keyed (each edit MISSES with the opt-out's exit, put back HITS)"
            else
              pcv_x PC-V47 "the .claude/worktrees/ prefix is not anchored:${v47k} (want each near-miss edit to be a fresh render with the opt-out's exit, then a hit)"
            fi
          fi
        fi
      fi
    fi
    [ -d "$PC_C/.claude/worktrees/agent-r7" ] && mv "$PC_C/.claude/worktrees/agent-r7" "$PS_D/v47-agent-r7-aside"
    rmdir "$PC_C/.claude/worktrees" 2>/dev/null
    cp "$PS_D/r7-exclude.keep" "$ex"
  fi
  cat "$PS_D/r7-ledger.keep" > "$lg"; cat "$PS_D/r7-report.keep" > "$PC_R"; cp "$PS_D/r7-rec.keep" "$PC_REC"
  return 0
}

# ---- V48: a receipt subject OUTSIDE every read root that is a regular file has its BYTES keyed ----
# A receipt that READS a .git/ file (`grep -q keep .git/r7-v48.txt`) moves with its content, which a
# presence bit cannot see. Directions: the receipt records and HITS; touching only the file's mtime
# still HITS; changing its BYTES MISSES with the opt-out's non-zero exit (the receipt's exit flips).
# RE-POINTED AT THE READ LOG (round 8): the receipts field is gone; ledger-reverify.sh tests every
# receipt subject through cr_test, whose log entry carries the file's blob id, and the record stores
# that entry. A FIFO at a subject path is logged as `o`, so creating one is a MISS whose exit equals the
# opt-out's and which leaves the record untouched (no record is written on a non-zero exit). That
# receipt only tests the FIFO (`test -p`), never reads it, so neither run can block on it.
pcv_r7content() {
  local lg="$PC_C/_bmad-output/ai-dlc-update/push-candidate-ledger.md" sf="$PC_C/.git/r7-v48.txt" ff="$PC_C/.git/r7-v48.fifo"
  local why="" nc
  if [ -e "$sf" ] || [ -e "$ff" ]; then pcv_x PC-V48 "FIXTURE BROKEN: a .git/r7-v48 subject already exists"; return 0; fi
  cp "$lg" "$PS_D/v48-ledger.keep" && cp "$PC_R" "$PS_D/v48-report.keep" && cp "$PC_REC" "$PS_D/v48-rec.keep" \
    || { pcv_x PC-V48 "FIXTURE BROKEN: could not keep the main world's ledger, report and record"; return 0; }
  printf 'keep\n' > "$sf"
  { cat "$PS_D/v48-ledger.keep"; printf '\n## PC-FIXTURE-R7-CONTENT — a receipt that reads a .git/ file\n\nverify: sh grep -q keep .git/r7-v48.txt\n'; } > "$lg"
  if ! pcv_r7rec v48; then
    pcv_x PC-V48 "control: a receipt reading an existing .git/r7-v48.txt did not record and then HIT ($(pcv_why))"
  else
    touch -t 200001010000 "$sf"
    pcm v48t; v48t="$(pcv_why)"; v48t_ok=0; pcv_is_hit v48t "$PC_REC" && v48t_ok=1
    printf 'gone\n' > "$sf"
    if [ "$v48t_ok" -ne 1 ]; then
      pcv_x PC-V48 "an mtime-only touch of .git/r7-v48.txt did not HIT: [$v48t] -- the field keys something other than the bytes"
    elif ! pcv_r7miss v48m; then
      pcv_x PC-V48 "changing the BYTES of the .git/r7-v48.txt a receipt reads did not force a fresh render: [$R7_WHY] -- a recorded PASS answered for content it never keyed"
    else
      rm -f "$sf"
      { cat "$PS_D/v48-ledger.keep"; printf '\n## PC-FIXTURE-R7-FIFO — a receipt naming a FIFO\n\nverify: sh test -p .git/r7-v48.fifo\n'; } > "$lg"
      if ! pcv_r7rec v48f; then
        pcv_x PC-V48 "control: the FIFO receipt with no FIFO present did not record and then HIT ($(pcv_why))"
      elif ! mkfifo "$ff" 2>/dev/null; then
        pcv_x PC-V48 "FIXTURE BROKEN: mkfifo failed, so the refusal direction cannot be built"
      else
        pcm v48r; why="$(pcv_why)"; v48_rc="$PRC"; v48_hit="$PHIT"; v48_n="$PN"
        v48_rec=REWRITTEN; cmp -s "$PC_REC" "$PS_D/v48f.rec" && v48_rec=unchanged
        pcm v48r.n nocache; nc="$PRC"; PRC="$v48_rc"; PHIT="$v48_hit"; PN="$v48_n"
        if pcv_is_miss "$nc" && [ "$nc" -ne 0 ] && [ "$v48_rec" = unchanged ] && grep -qxF "read	t	.git/r7-v48.fifo	-" "$PS_D/v48f.rec"; then
          pcv_v PC-V48 "a receipt reading a .git/ file records and HITS, an mtime-only touch HITS, a byte change MISSES with the opt-out's exit, and a FIFO created at a subject path the record logged absent MISSES (fresh render, exit $nc as the opt-out, record untouched)"
        else
          pcv_x PC-V48 "FIFO subject: [$why], opt-out $nc, record $v48_rec, logged-absent entry $(grep -cxF "read	t	.git/r7-v48.fifo	-" "$PS_D/v48f.rec") (want a fresh render with the opt-out's non-zero exit, record untouched, and the record's read log carrying the subject as absent)"
        fi
      fi
    fi
  fi
  rm -f "$sf" "$ff"
  cat "$PS_D/v48-ledger.keep" > "$lg"; cat "$PS_D/v48-report.keep" > "$PC_R"; cp "$PS_D/v48-rec.keep" "$PC_REC"
  return 0
}

# ---- V49..V54: the round-8 partition, in the MAIN world after V48 ----
# Every round-8 BLOCKER was a STALE PASS: the cached run HIT with exit 0 where an opt-out render of the
# same tree exited 1. So each hole direction asserts NOT STALE, which two engines satisfy differently:
# the pre-fix shape (the render reads the input and the key keys it) is a fresh render whose exit
# equals the opt-out's; the fixed shape that stops READING the input (the escape refused, the glob not
# expanded) HITS while the opt-out exits 0 as well. Both pass; a HIT beside a non-zero opt-out fails,
# and the failure line names the round-8 id. A third shape, a NAMED REFUSAL at the recording run
# (pcv_r8rec returns 2: R6 prefix, opt-out's exit, record untouched), records nothing and also passes.
# Each sub-case re-records first (pcv_r7rec, or pcv_r8rec in a hole world), so its own
# HIT control precedes its change, and each near miss is the twin the adversary's probe logged.
# pcv_r8nostale <tag> -- the cached run, then the opt-out on the same tree. 0 unless it is a stale HIT.
pcv_r8nostale() {
  local rc hit n nc
  pcm "$1"; rc="$PRC"; hit="$PHIT"; n="$PN"
  pcm "$1.n" nocache; nc="$PRC"; PRC="$rc"; PHIT="$hit"; PN="$n"
  R8_WHY="$(pcv_why), opt-out $nc"; R8_NC="$nc"
  if [ "$PHIT" -eq 1 ]; then pcv_is_hit "$1" "$PC_REC" && [ "$nc" -eq 0 ]; else pcv_is_miss "$nc"; fi
}
# pcv_r8trig <tag> <B-id> <hit: 0|1> [<witness-fn>] -- THE HOLE WORLD MUST STILL TRIGGER, on either
# engine, so no hole direction can pass on a world that stopped expressing the defect. R8_NC is the
# opt-out's exit on the changed tree (pcv_r8nostale sets it; with no record, run it here). Passes when
# the opt-out exits 1 (the input is READ: the pre-fix engine), or, only where a witness fn is given,
# when the opt-out exits 0, the witness names THIS input as not read, and the cached run HIT (the
# fixed engine stopped reading it). Anything else, an exit 0 with no witness included, appends
# "[B-id] world no longer triggers" to the arm's why and returns 1.
pcv_r8trig() {
  local w=""
  [ -n "${R8_NC:-}" ] || { pcm "$1.t" nocache; R8_NC="$PRC"; }
  [ "$R8_NC" -eq 1 ] && return 0
  if [ -n "${4:-}" ] && [ "$R8_NC" -eq 0 ]; then
    if "$4" "$1"; then [ "$3" -eq 1 ] && return 0; w=", witnessed but the cached run did not HIT"
    else w=", witness absent [$R8_WIT]"; fi
  fi
  why="$why [$2] world no longer triggers [$1: opt-out $R8_NC$w]"
  return 1
}
# pcv_r8w49 <tag> -- B1's non-read witness on the hole world: the region carries the relabel refusal row,
# and relabel-extension-checks.sh run alone exits 2 naming r8b1.md's own hooks: value ($hk).
pcv_r8w49() {
  local rc
  "$PCV_BASH" "$PS_E" "$PC_D" "$BASE" "$PC_C" "$THEIRS" > "$PS_D/$1.wreg" 2>/dev/null
  "$PCV_BASH" "$(dirname "$PS_E")/relabel-extension-checks.sh" "$PC_C" --dist "$PC_D" --theirs "$THEIRS" > "$PS_D/$1.wout" 2> "$PS_D/$1.werr"; rc=$?
  R8_WIT="relabel rc $rc"
  [ "$rc" -eq 2 ] && grep -q '^DETECTOR-REFUSED  relabel-extension-checks\.sh' "$PS_D/$1.wreg" \
    && grep -qF "r8b1.md's hooks: value '$hk'" "$PS_D/$1.werr"
}
# pcv_r8w50 <tag> -- B2's non-read witness, from the arm's cwd: the region carries r8b2's UNBOUND row, and
# layer-drift.sh run alone prints that row naming the LITERAL tests/fixtures/zz* (never a glob match).
pcv_r8w50() {
  "$PCV_BASH" "$PS_E" "$PC_D" "$BASE" "$PC_C" "$THEIRS" > "$PS_D/$1.wreg" 2>/dev/null
  "$PCV_BASH" "$(dirname "$PS_E")/layer-drift.sh" "$PC_D" "$BASE" "$THEIRS" "$PC_C" > "$PS_D/$1.wout" 2>/dev/null
  R8_WIT="literal zz* row $(awk 'index($0, "EXTENSION-FIXTURE-UNBOUND") == 1 && index($0, "r8b2.md") && index($0, "declares fixtures: tests/fixtures/zz*,")' "$PS_D/$1.wout" | grep -c .)"
  grep -q '^EXTENSION-FIXTURE-UNBOUND.*r8b2' "$PS_D/$1.wreg" && [ "${R8_WIT##* }" -ge 1 ]
}
# pcv_r8hit <tag> -- a near miss the render cannot see: the cached run HITS and the opt-out exits 0.
pcv_r8hit() {
  local rc hit n nc
  pcm "$1"; rc="$PRC"; hit="$PHIT"; n="$PN"
  pcm "$1.n" nocache; nc="$PRC"; PRC="$rc"; PHIT="$hit"; PN="$n"
  R8_WHY="$(pcv_why), opt-out $nc"
  pcv_is_hit "$1" "$PC_REC" && [ "$nc" -eq 0 ]
}
# pcv_r8rec <tag> -- pcv_r7rec for a HOLE world, where the fixed engine REFUSES TO RECORD instead of
# keying the input. The record is REMOVED first, so "no record formed" is observable rather than
# inferred from an old record surviving. 0: recorded and HIT (the pre-fix engine). 2: NO RECORD FORMED
# -- two armed runs on the unchanged tree, neither a HIT, both exiting as the opt-out does, and no
# record file after either -- which is the fixed engine's record-time refusal (er_cache_record is
# silent by design, so the caller proves the refusal is about THIS input through its own witness).
# 1: anything else. Sets R8_WHY.
pcv_r8rec() {
  local rc1 rc2 h2
  rm -f "$PC_REC"
  "$PCV_BASH" "$PS_E" "$PC_D" "$BASE" "$PC_C" "$THEIRS" > "$PS_D/region-$1.md" 2>/dev/null
  { echo "# Reconcile report (fixture)"; echo; cat "$PS_D/region-$1.md"; } > "$PC_R"
  grep -q 'reconcile-mechanical' "$PS_D/region-$1.md" || { R8_WHY="no region rendered"; return 1; }
  pcm "$1.r"; R8_WHY="$(pcv_why)"; rc1="$PRC"
  if [ "$PHIT" -eq 0 ] && [ "$PN" -gt 0 ] && [ ! -e "$PC_REC" ]; then
    pcm "$1.r2"; rc2="$PRC"; h2="$PHIT"
    pcm "$1.rn" nocache
    R8_WHY="no record: rc $rc1 then $rc2 (hit $h2), opt-out $PRC, record $([ -e "$PC_REC" ] && echo WRITTEN || echo absent)"
    [ "$h2" -eq 0 ] && [ "$rc1" -eq "$PRC" ] && [ "$rc2" -eq "$PRC" ] && [ ! -e "$PC_REC" ] && return 2
    return 1
  fi
  pcv_is_miss 0 && [ -f "$PC_REC" ] || return 1
  pcm "$1.c"; R8_WHY="$(pcv_why)"; pcv_is_hit "$1.c" "$PC_REC" || return 1
  cp "$PC_REC" "$PS_D/$1.rec"
}
# pcv_r8w51 <tag> -- B3's refusal witness, naming THIS world's input: the record-time render's region
# carries the receipt row naming docs/r8a/../r8d (ledger-reverify.sh keeps a token consumer-read.sh
# refuses as a subject, rc 2 being "could not read", never "exists"), and consumer-read.sh itself
# refuses that exact token with rc 2 naming it.
pcv_r8w51() {
  local rc
  rc="$( ( set -f; CR_LOG=""; . "$(dirname "$PS_E")/consumer-read.sh" && cr_test "$PC_C" -e 'docs/r8a/../r8d' ) 2> "$PS_D/$1.werr"; echo $?)"
  R8_WIT="region names it $(grep -cF 'docs/r8a/../r8d' "$PS_D/region-$1.md"), cr_test rc $rc"
  grep -qF 'docs/r8a/../r8d' "$PS_D/region-$1.md" && [ "$rc" = 2 ] && grep -qF "'docs/r8a/../r8d'" "$PS_D/$1.werr"
}
# pcv_r8home -- back to the cwd pcv_r8world entered from ($here). NOT OPTIONAL: every later command
# resolves relative to it. On failure every round-8 id gets a FIXTURE BROKEN FAIL line (an id that
# already holds an ok line then holds two lines, which pcv_failset reads as failed), and the caller
# returns from pcv_r8world, so nothing runs in the wrong directory.
pcv_r8home() {
  local s
  cd "$here" 2>/dev/null && return 0
  for s in PC-V49 PC-V50 PC-V51 PC-V52 PC-V53 PC-V54; do
    pcv_x "$s" "FIXTURE BROKEN: could not cd back to $here after the V50 cwd worlds, so the round-8 arms stopped rather than run in the wrong directory"
  done
  return 1
}
pcv_r8world() {
  local ex="$PC_C/.git/info/exclude" lg="$PC_C/_bmad-output/ai-dlc-update/push-candidate-ledger.md"
  local ext="$PC_C/.claude/skills/ai-dlc/extensions" here s tag rest hk tgt why g cwd mf out r8
  here="$(pwd)"
  case "$PS_D" in /*) ;; *) for s in PC-V49 PC-V50 PC-V51 PC-V52 PC-V53 PC-V54; do pcv_x "$s" "FIXTURE BROKEN: the suite dir $PS_D is relative, so the cwd-moving arms would lose it"; done; return 0 ;; esac
  mkdir -p "$PC_C/.git/info" && touch "$ex" && cp "$ex" "$PS_D/r8-exclude.keep" \
    && cp "$lg" "$PS_D/r8-ledger.keep" && cp "$PC_R" "$PS_D/r8-report.keep" && cp "$PC_REC" "$PS_D/r8-rec.keep" \
    || { for s in PC-V49 PC-V50 PC-V51 PC-V52 PC-V53 PC-V54; do pcv_x "$s" "FIXTURE BROKEN: could not keep the main world's exclude, ledger, report and record"; done; return 0; }
  if [ -e "$PC_C/.claude/worktrees" ] || [ -L "$PC_C/.claude/worktrees" ]; then
    for s in PC-V49 PC-V50 PC-V51 PC-V52 PC-V53 PC-V54; do pcv_x "$s" "FIXTURE BROKEN: .claude/worktrees already exists before the round-8 arms"; done; return 0
  fi

  # V49 (B1): relabel-extension-checks.sh reads `$SKILL_DIR/$hooks` with no .. guard. An extension
  # whose hooks: climbs to .git/r8-core.md, or to an IGNORED .claude/worktrees/r8wt/core.md, collides
  # there; renumbering the target moves the relabel row. HOLE, per engine: the pre-fix engine records
  # and, renumbered, must not go STALE (it does, with [B1]); the fixed engine forms NO record (its
  # read log carries the guard's `!` entry) with the opt-out's exit, and pcv_r8w49 names this world's
  # hooks: value. NEAR MISS (no `..`): hooks: templates/r8-core.md, the hooked file inside the skill
  # tree; it records and HITS unchanged, and renumbering its anchor MISSES with the opt-out's non-zero
  # exit, on both engines (the pre-fix one keys .claude/ as a read root, the fixed one logs the read).
  if pcv_in PC-V49; then
    why=""
    printf '/.claude/worktrees/\n' >> "$ex"; mkdir -p "$ext"
    for s in gitdir:../../../.git/r8-core.md:.git/r8-core.md worktree:../../worktrees/r8wt/core.md:.claude/worktrees/r8wt/core.md near:templates/r8-core.md:.claude/skills/ai-dlc/templates/r8-core.md; do
      tag="${s%%:*}"; rest="${s#*:}"; hk="${rest%%:*}"; tgt="${rest#*:}"
      printf -- '---\nkind: check\nid: r8b1\nhooks: %s\n---\n### 7. Probe heading\nbody\n' "$hk" > "$ext/r8b1.md"
      mkdir -p "$(dirname "$PC_C/$tgt")" && printf '### 7. Core heading\n' > "$PC_C/$tgt"
      if [ "$tag" = worktree ] && ! git -C "$PC_C" check-ignore -q "$tgt"; then why="$why $tag:FIXTURE-BROKEN[$tgt is not ignored]"
      elif [ "$tag" = near ] && ! { cp "$PS_D/r8-rec.keep" "$PC_REC" && pcv_r7rec "v49$tag"; }; then why="$why near:control[$(pcv_why)]"
      elif [ "$tag" = near ] && ! grep -q 'ext:r8b1' "$PS_D/region-v49$tag.md"; then why="$why near:FIXTURE-BROKEN[no relabel row for ext:r8b1, so the world never reaches the reader]"
      elif [ "$tag" != near ] && { r8=0; pcv_r8rec "v49$tag" || r8=$?; [ "$r8" -eq 1 ]; }; then
        why="$why $tag:[B1] world no longer triggers[$R8_WHY]"
      elif [ "$tag" != near ] && [ "$r8" -eq 2 ]; then
        pcv_r8w49 "v49$tag" || why="$why $tag:[B1] world no longer triggers[no record formed, but the refusal does not name hooks: $hk; $R8_WIT]"
      else
        printf '### 8. Core heading\n' > "$PC_C/$tgt"
        if [ "$tag" = near ]; then pcv_r7miss "v49${tag}m" || why="$why near[$R7_WHY]"
        else
          R8_NC=""
          pcv_r8nostale "v49${tag}h" || why="$why $tag:STALE[$R8_WHY]"
          pcv_r8trig "v49$tag" B1 0 || :
        fi
      fi
      rm -f "$PC_C/$tgt"
    done
    rm -f "$ext/r8b1.md"; rmdir "$PC_C/.claude/worktrees/r8wt" "$PC_C/.claude/worktrees" 2>/dev/null
    cp "$PS_D/r8-exclude.keep" "$ex"; cp "$PS_D/r8-rec.keep" "$PC_REC"
    if [ -z "$why" ]; then
      pcv_v PC-V49 "[B1] an extension hooks: escaping to .git/r8-core.md or an ignored .claude/worktrees/r8wt/core.md forms no record (opt-out's exit, the refusal naming the hooks: value), and a hooks: value inside the skill tree records, HITS, and MISSES with the opt-out's exit when its anchor is renumbered"
    else
      pcv_x PC-V49 "[B1] relabel hooks: escape:${why} (want no record formed with the refusal naming the hooks: value, or no stale HIT; near miss a fresh render with the opt-out's exit)"
    fi
  fi

  # V50 (B2): layer-drift.sh's `for fx in $(fm "$f" fixtures ...)` globs `zz*` against the CALLER's
  # cwd, which no field keys. Hole 1: an outside cwd gains zzR8. Hole 2: the cwd is the consumer root and
  # gains an EMPTY top-level zzR8 (no field sees an empty directory). Either binds tests/fixtures/zzR8
  # and drops the UNBOUND row. Near misses: the same cwd gains `unrelated` / `qqR8`, which HIT, opt-out 0.
  if pcv_in PC-V50; then
    why=""
    for g in "$PC_C"/zz* "$PS_D"/r8cwd; do [ -e "$g" ] && why="$why FIXTURE-BROKEN[$g already exists]"; done
    if [ -z "$why" ]; then
      mkdir -p "$ext" "$PC_C/tests/fixtures/zzR8" "$PS_D/r8cwd" && printf 'echo\n' > "$PC_C/tests/fixtures/zzR8/run.sh"
      printf -- '---\nhooks: templates/classes.md\nfixtures: zz*\n---\nbody\n' > "$ext/r8b2.md"
      for s in outside consumer; do
        case "$s" in outside) cwd="$PS_D/r8cwd"; g=unrelated ;; consumer) cwd="$PC_C"; g=qqR8 ;; esac
        cd "$cwd" || { why="$why $s:FIXTURE-BROKEN[cd]"; continue; }
        # The key holds no cwd, so the second cwd's tree equals the first's: put back a record that
        # does not match, or its recording run would HIT the first one's record.
        cp "$PS_D/r8-rec.keep" "$PC_REC"
        if ! pcv_r7rec "v50$s"; then why="$why $s:control[$(pcv_why)]"
        elif ! grep -q '^EXTENSION-FIXTURE-UNBOUND.*r8b2' "$PS_D/region-v50$s.md"; then why="$why $s:FIXTURE-BROKEN[the approval carries no UNBOUND row for zz*, so the glob reader was not reached]"
        else
          mkdir "$cwd/$g"; pcv_r8hit "v50${s}n" || why="$why $s:near[$R8_WHY]"; rmdir "$cwd/$g"; cp "$PS_D/v50$s.rec" "$PC_REC"
          mkdir "$cwd/zzR8"; R8_NC=""; pcv_r8nostale "v50${s}h" || why="$why $s:STALE[$R8_WHY]"
          pcv_r8trig "v50$s" B2 "$PHIT" pcv_r8w50 || :
          rmdir "$cwd/zzR8"
        fi
        pcv_r8home || return 0
      done
      rm -f "$ext/r8b2.md" "$PC_C/tests/fixtures/zzR8/run.sh"; rmdir "$PC_C/tests/fixtures/zzR8" "$PS_D/r8cwd" 2>/dev/null
    fi
    pcv_r8home || return 0
    cp "$PS_D/r8-rec.keep" "$PC_REC"
    if [ -z "$why" ]; then
      pcv_v PC-V50 "[B2] fixtures: zz* gives no stale HIT when zzR8 appears in an outside cwd or as an empty top-level directory of the consumer cwd, and unrelated / qqR8 there HIT with the opt-out exiting 0"
    else
      pcv_x PC-V50 "[B2] fixtures: glob against the cwd:${why} (want no HIT beside a non-zero opt-out; near misses a HIT with opt-out 0)"
    fi
  fi

  # V51 (B3): two receipt tokens docs/r8a/../r8d and docs/r8b/../r8d collapse to one lexical label.
  # docs/r8a is an EMPTY directory at the record; renamed to docs/r8b, the row names the other token and
  # the key read the same label set. HOLE, per engine: the pre-fix engine records and, renamed, must not
  # go STALE (it does, with [B3]); the fixed engine forms NO record with the opt-out's exit, and
  # pcv_r8w51 names docs/r8a/../r8d. NEAR MISS (no `..`): two labels, docs/r8d docs/r8e, both present;
  # it records and HITS unchanged, and removing docs/r8e MISSES with the opt-out's non-zero exit, on
  # both engines (the receipts field keyed presence before the fix, the read log keys it after).
  if pcv_in PC-V51; then
    why=""
    if [ -e "$PC_C/docs/r8a" ] || [ -e "$PC_C/docs/r8b" ] || [ -e "$PC_C/docs/r8d" ] || [ -e "$PC_C/docs/r8e" ]; then why=" FIXTURE-BROKEN[a docs/r8* path already exists]"
    else
      mkdir -p "$PC_C/docs/r8d" "$PC_C/docs/r8e" && printf 'x\n' > "$PC_C/docs/r8d/keep.md" && printf 'x\n' > "$PC_C/docs/r8e/keep.md"
      for s in hole near; do
        case "$s" in hole) rest='docs/r8a/../r8d docs/r8b/../r8d' ;; near) rest='docs/r8d docs/r8e' ;; esac
        { cat "$PS_D/r8-ledger.keep"; printf '\n## PC-FIXTURE-R8-LABEL — two receipt tokens\n\nverify: sh exit 1; : %s\n' "$rest"; } > "$lg"
        rmdir "$PC_C/docs/r8b" 2>/dev/null; [ "$s" = hole ] && mkdir -p "$PC_C/docs/r8a"
        if [ "$s" = near ] && ! { cp "$PS_D/r8-rec.keep" "$PC_REC" && pcv_r7rec "v51$s"; }; then why="$why near:control[$(pcv_why)]"
        elif [ "$s" = hole ] && { r8=0; pcv_r8rec "v51$s" || r8=$?; [ "$r8" -eq 1 ]; }; then
          why="$why hole:[B3] world no longer triggers[$R8_WHY]"
        elif [ "$s" = hole ] && [ "$r8" -eq 2 ]; then
          pcv_r8w51 "v51$s" || why="$why hole:[B3] world no longer triggers[no record formed, but the refusal does not name docs/r8a/../r8d; $R8_WIT]"
        elif [ "$s" = near ]; then
          rm -f "$PC_C/docs/r8e/keep.md"; rmdir "$PC_C/docs/r8e"
          pcv_r7miss "v51${s}m" || why="$why near[$R7_WHY]"
          mkdir -p "$PC_C/docs/r8e" && printf 'x\n' > "$PC_C/docs/r8e/keep.md"
        else
          mv "$PC_C/docs/r8a" "$PC_C/docs/r8b"
          R8_NC=""
          pcv_r8nostale "v51${s}h" || why="$why hole:STALE[$R8_WHY]"
          pcv_r8trig "v51$s" B3 0 || :
        fi
      done
      rm -f "$PC_C/docs/r8d/keep.md" "$PC_C/docs/r8e/keep.md"; rmdir "$PC_C/docs/r8a" "$PC_C/docs/r8b" "$PC_C/docs/r8d" "$PC_C/docs/r8e" 2>/dev/null
    fi
    cat "$PS_D/r8-ledger.keep" > "$lg"; cp "$PS_D/r8-rec.keep" "$PC_REC"
    if [ -z "$why" ]; then
      pcv_v PC-V51 "[B3] receipt tokens docs/r8a/../r8d docs/r8b/../r8d form no record (opt-out's exit, the token named), and two plain labels record, HIT, and MISS with the opt-out's exit when one subject goes"
    else
      pcv_x PC-V51 "[B3] receipts label collapse:${why} (want no record formed with docs/r8a/../r8d named, or no stale HIT; near miss a fresh render with the opt-out's exit)"
    fi
  fi

  # V52 (B4): a receipt reads .claude/WORKTREES/r8wt/f with .claude/worktrees/ ignored. On a
  # case-insensitive filesystem that is the ignored file every field prunes, so a content change rode the
  # record. Near miss: the lowercase spelling, which the receipts field keys, MISSES. Gated on PCV_CI
  # (measured once, where the suite builds its worlds): a case-sensitive filesystem prints SKIP, no ok.
  if [ "$PCV_CI" -eq 1 ] && pcv_in PC-V52; then
    why=""
    printf '/.claude/worktrees/\n' >> "$ex"
    mkdir -p "$PC_C/.claude/worktrees/r8wt" && printf 'keep\n' > "$PC_C/.claude/worktrees/r8wt/f"
    if ! git -C "$PC_C" check-ignore -q .claude/worktrees/r8wt/f || [ ! -f "$PC_C/.claude/WORKTREES/r8wt/f" ]; then
      why=" FIXTURE-BROKEN[.claude/worktrees/r8wt/f is not ignored, or the upper-case spelling does not resolve]"
    else
      for s in upper lower; do
        case "$s" in upper) rest='.claude/WORKTREES/r8wt/f' ;; lower) rest='.claude/worktrees/r8wt/f' ;; esac
        { cat "$PS_D/r8-ledger.keep"; printf '\n## PC-FIXTURE-R8-CASE — a receipt reading under the ignored worktrees dir\n\nverify: sh grep -q keep %s\n' "$rest"; } > "$lg"
        printf 'keep\n' > "$PC_C/.claude/worktrees/r8wt/f"
        if [ "$s" = lower ] && ! pcv_r7rec "v52$s"; then why="$why lower:control[$(pcv_why)]"
        elif [ "$s" = upper ] && { r8=0; pcv_r8rec "v52$s" || r8=$?; [ "$r8" -eq 1 ]; }; then
          why="$why upper:control[$R8_WHY]"
        else
          printf 'gone\n' > "$PC_C/.claude/worktrees/r8wt/f"
          if [ "$s" = lower ]; then pcv_r7miss "v52${s}m" || why="$why lower[$R7_WHY]"
          else
            R8_NC=""
            [ "$r8" -eq 0 ] && { pcv_r8nostale "v52${s}h" || why="$why upper:STALE[$R8_WHY]"; }
            pcv_r8trig "v52$s" B4 0 || :
          fi
        fi
      done
    fi
    rm -f "$PC_C/.claude/worktrees/r8wt/f"; rmdir "$PC_C/.claude/worktrees/r8wt" "$PC_C/.claude/worktrees" 2>/dev/null
    cat "$PS_D/r8-ledger.keep" > "$lg"; cp "$PS_D/r8-exclude.keep" "$ex"; cp "$PS_D/r8-rec.keep" "$PC_REC"
    if [ -z "$why" ]; then
      pcv_v PC-V52 "[B4] a receipt reading .claude/WORKTREES/r8wt/f (ignored .claude/worktrees/, case-insensitive filesystem) gives no stale HIT on a content change, and the lowercase spelling MISSES with the opt-out's exit"
    else
      pcv_x PC-V52 "[B4] case-variant receipt under an ignored worktrees dir:${why} (want no HIT beside a non-zero opt-out; near miss a fresh render with the opt-out's exit)"
    fi
  fi

  # V53 (B5): preclassify.sh tests `[ -f "$CONS/scripts/<basename>" ]` for a core/scripts/* path the
  # consumer deleted at its new home. With scripts/ outside every read root and the file IGNORED, its
  # creation flips the row to PRE-RELOCATION-NOOP unkeyed. Near miss: an ignored scripts/other-r8.sh HITS.
  if pcv_in PC-V53; then
    why=""; mf="$PC_C/scripts/ai-dlc/moved-ref-probe.sh"
    if [ ! -f "$mf" ] || [ -e "$PC_C/scripts/moved-ref-probe.sh" ] || [ -e "$PC_C/scripts/other-r8.sh" ]; then
      why=" FIXTURE-BROKEN[scripts/ai-dlc/moved-ref-probe.sh is absent, or a scripts/ probe file already exists]"
    else
      cp -p "$mf" "$PS_D/r8-moved.keep" && rm -f "$mf"
      printf '/scripts/moved-ref-probe.sh\n/scripts/other-r8.sh\n' >> "$ex"
      if ! pcv_r7rec v53; then why=" control[$(pcv_why)]"
      elif ! grep -q 'core/scripts/moved-ref-probe.sh' "$PS_D/region-v53.md"; then why=" FIXTURE-BROKEN[the approval names no core/scripts/moved-ref-probe.sh row, so the relocation branch is not reached]"
      else
        : > "$PC_C/scripts/other-r8.sh"
        git -C "$PC_C" check-ignore -q scripts/other-r8.sh || why="$why FIXTURE-BROKEN[scripts/other-r8.sh not ignored]"
        pcv_r8hit v53n || why="$why near[$R8_WHY]"; rm -f "$PC_C/scripts/other-r8.sh"; cp "$PS_D/v53.rec" "$PC_REC"
        printf '#!/bin/sh\n' > "$PC_C/scripts/moved-ref-probe.sh"
        git -C "$PC_C" check-ignore -q scripts/moved-ref-probe.sh || why="$why FIXTURE-BROKEN[scripts/moved-ref-probe.sh not ignored]"
        R8_NC=""; pcv_r8nostale v53h || why="$why hole:STALE[$R8_WHY]"
        pcv_r8trig v53h B5 0 || :
        rm -f "$PC_C/scripts/moved-ref-probe.sh"
      fi
      cp -p "$PS_D/r8-moved.keep" "$mf"
    fi
    cp "$PS_D/r8-exclude.keep" "$ex"; cp "$PS_D/r8-rec.keep" "$PC_REC"
    if [ -z "$why" ]; then
      pcv_v PC-V53 "[B5] an ignored scripts/moved-ref-probe.sh created beside a consumer-deleted scripts/ai-dlc copy gives no stale HIT, and an ignored scripts/other-r8.sh HITS with the opt-out exiting 0"
    else
      pcv_x PC-V53 "[B5] preclassify relocation test of an unkeyed scripts/ path:${why} (want no HIT beside a non-zero opt-out; near miss a HIT with opt-out 0)"
    fi
  fi

  # V54 (N1): .claude/worktrees ITSELF a symlink to a directory outside the consumer, ignored. A receipt
  # reading .claude/worktrees/f through it records and HITS unchanged (the near miss, as logged), and a
  # content change through the link gives no stale HIT. Expected to pass on the 44825dfc9 engine as well
  # (the receipts field hashes through the link); it holds that position for every later engine.
  # AN ENGINE THAT REFUSES THE LINK BY NAME also passes: the first armed run is then a fresh render
  # whose exit equals the opt-out's, the record untouched and the refusal prefix on stderr, and nothing
  # recorded can go stale. What fails is a HIT beside a non-zero opt-out, or an unnamed non-record.
  if pcv_in PC-V54; then
    why=""; out="$PS_D/r8-n1-outside"
    printf '/.claude/worktrees\n' >> "$ex"
    mkdir -p "$out" && printf 'keep\n' > "$out/f" && ln -s "$out" "$PC_C/.claude/worktrees"
    { cat "$PS_D/r8-ledger.keep"; printf '\n## PC-FIXTURE-R8-LINK — a receipt reading through a symlinked worktrees dir\n\nverify: sh grep -q keep .claude/worktrees/f\n'; } > "$lg"
    "$PCV_BASH" "$PS_E" "$PC_D" "$BASE" "$PC_C" "$THEIRS" > "$PS_D/region-v54.md" 2>/dev/null
    { echo "# Reconcile report (fixture)"; echo; cat "$PS_D/region-v54.md"; } > "$PC_R"
    cp "$PC_REC" "$PS_D/v54-pre.rec"
    if [ ! -L "$PC_C/.claude/worktrees" ] || ! git -C "$PC_C" check-ignore -q .claude/worktrees; then why=" FIXTURE-BROKEN[.claude/worktrees is not an ignored symlink]"
    elif ! grep -q 'reconcile-mechanical' "$PS_D/region-v54.md"; then why=" FIXTURE-BROKEN[the approval rendered no region]"
    elif pcm v54q && [ "$PHIT" -eq 0 ] && grep -qF "$PCV_R6MARK" "$PS_D/v54q.err"; then
      v54_rc="$PRC"; pcm v54q.n nocache
      { [ "$v54_rc" -eq "$PRC" ] && cmp -s "$PC_REC" "$PS_D/v54-pre.rec"; } \
        || why=" refused[rc $v54_rc, opt-out $PRC, record $(cmp -s "$PC_REC" "$PS_D/v54-pre.rec" && echo unchanged || echo REWRITTEN)] (a refusal must exit as the opt-out and leave the record)"
    elif ! { cp "$PS_D/v54-pre.rec" "$PC_REC" && pcv_r7rec v54; }; then why=" control[$(pcv_why)]"
    else
      pcv_r8hit v54n || why="$why near[$R8_WHY]"
      cp "$PS_D/v54.rec" "$PC_REC"; printf 'gone\n' > "$out/f"
      pcv_r8nostale v54h || why="$why STALE[$R8_WHY]"
    fi
    rm -f "$PC_C/.claude/worktrees"
    cat "$PS_D/r8-ledger.keep" > "$lg"; cp "$PS_D/r8-exclude.keep" "$ex"; cp "$PS_D/r8-rec.keep" "$PC_REC"
    if [ -z "$why" ]; then
      pcv_v PC-V54 "[N1] a receipt reading through an ignored symlinked .claude/worktrees records and HITS unchanged with the opt-out exiting 0, and a content change through the link gives no stale HIT"
    else
      pcv_x PC-V54 "[N1] symlinked .claude/worktrees:${why} (want an unchanged HIT with opt-out 0, then no HIT beside a non-zero opt-out)"
    fi
  fi
  pcv_r8home || return 0
  cat "$PS_D/r8-ledger.keep" > "$lg"; cat "$PS_D/r8-report.keep" > "$PC_R"; cp "$PS_D/r8-rec.keep" "$PC_REC"; cp "$PS_D/r8-exclude.keep" "$ex"
  return 0
}

# pcv_suite <emit> <dir> [scope] -- the PC-V arms against that engine; one verdict line per id in
# <dir>/verdicts. With no scope every arm runs (the shipping control). With a scope, a group of arms
# runs only when pcv_in names one of its ids, and the main world through V2 always runs: it is V0's
# harness check and V1/V14's record-then-hit, the path every mutant edits.
pcv_in() { # pcv_in <id>... -- 0 when the suite has no scope, or its scope names one of the ids
  local i; [ -z "$PS_S" ] && return 0
  for i in "$@"; do case " $PS_S " in *" $i "*) return 0 ;; esac; done
  return 1
}
pcv_suite() {
  PS_E="$1"; PS_D="$2"; PS_SHIM="$2/shim"; PCV_ENG=""; PS_S="${3:-}"
  mkdir -p "$PS_SHIM" && : > "$PS_D/verdicts" || return 1
  pcv_shim || { pcv_x PC-V0 "FIXTURE BROKEN: could not write the PATH shim"; return 1; }

  # ---- the main world ----
  # The dist is a BARE MIRROR of a copy of the seeded dist (the cache refuses a non-bare dist, R1);
  # PC_DW, the non-bare copy it mirrors, is read only by V38, R1's own arm.
  PC_C="$PS_D/consumer"; PC_DW="$PS_D/dist-work"; PC_D="$PS_D/dist.git"
  { cp -R "$CONSUMER" "$PC_C" && cp -R "$DIST" "$PC_DW" && git clone -q --mirror "$PC_DW" "$PC_D"; } >/dev/null 2>&1 \
    || { pcv_x PC-V0 "FIXTURE BROKEN: could not copy the seeded world and mirror its dist"; return 1; }
  mkdir -p "$PC_C/notes" "$PC_C/_bmad-output/ai-dlc-update"
  printf 'v4 original\n' > "$PC_C/notes/pc-v4.txt"
  printf '#!/usr/bin/env bash\necho v11\n' > "$PC_C/notes/pc-v11.sh"; chmod -x "$PC_C/notes/pc-v11.sh"
  printf '.claude/settings.local.json\n' > "$PC_C/.gitignore"
  printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$PC_C/.claude/.ai-dlc-version"
  { git -C "$PC_C" init -q && git -C "$PC_C" add -A \
    && git -C "$PC_C" -c user.email=f@f -c user.name=fixture commit -q -m consumer; } >/dev/null 2>&1 \
    || { pcv_x PC-V0 "FIXTURE BROKEN: could not make the consumer copy a git work tree"; return 1; }
  printf '{"local": 1}\n' > "$PC_C/.claude/settings.local.json"
  printf 'v13 bytes\n' > "$PC_C/notes/pc-v13.txt"
  PC_T2="$(git -C "$PC_D" -c user.email=f@f -c user.name=fixture commit-tree "${THEIRS}^{tree}" -p "$THEIRS" -m pc-v6 2>/dev/null)" || PC_T2=""
  PC_REC="$(git -C "$PC_C" rev-parse --absolute-git-dir 2>/dev/null)/ai-dlc-verify-pass"
  PC_R="$PC_C/_bmad-output/ai-dlc-update/reconcile-report.md"
  "$PCV_BASH" "$PS_E" "$PC_D" "$BASE" "$PC_C" "$THEIRS" > "$PS_D/region.md" 2> "$PS_D/region.err"
  { echo "# Reconcile report (fixture)"; echo; cat "$PS_D/region.md"; } > "$PC_R"
  pc_top="$(git -C "$PC_C" rev-parse --show-toplevel 2>/dev/null)"
  if ! grep -q 'reconcile-mechanical' "$PS_D/region.md" || ! grep -q '^HARD-UNREGISTERED-CORE-DRIFT' "$PS_D/region.md"; then
    pcv_x PC-V0 "FIXTURE BROKEN: the main world's approval rendered no region carrying HARD-UNREGISTERED-CORE-DRIFT"; return 1
  elif grep -q '^_stamp_ ' "$PS_D/region.md"; then
    pcv_x PC-V0 "FIXTURE BROKEN: the approval already carries a _stamp_ line, so V5's stamp move is not one property"; return 1
  elif [ -z "$PC_T2" ] || [ "$PC_T2" = "$THEIRS" ] \
       || [ "$(git -C "$PC_D" rev-parse "${PC_T2}:core" 2>/dev/null)" != "$(git -C "$PC_D" rev-parse "${THEIRS}:core" 2>/dev/null)" ]; then
    pcv_x PC-V0 "FIXTURE BROKEN: V6's second theirs commit is missing, equal to theirs, or carries another core/ tree"; return 1
  elif [ -e "$PC_REC" ] || [ "$(cd "$pc_top" 2>/dev/null && pwd -P)" != "$(cd "$PC_C" && pwd -P)" ]; then
    pcv_x PC-V0 "FIXTURE BROKEN: a record exists before any run, or the consumer is not its own git top level ($pc_top)"; return 1
  elif [ "$(git -C "$PC_D" rev-parse --is-bare-repository 2>/dev/null)" != true ] \
       || [ "$(git -C "$PC_DW" rev-parse --is-bare-repository 2>/dev/null)" != false ]; then
    pcv_x PC-V0 "FIXTURE BROKEN: the mirrored dist is not bare, or its work-tree source is not non-bare, so R1 cannot be told apart"; return 1
  fi
  pcv_v PC-V0 "the main world is its own git top level, its dist a bare mirror, its approval carries the HARD blocker and no _stamp_ line, and no record exists yet"

  # ---- V1 / V14: the recording run, then the hit ----
  git -C "$PC_C" status --porcelain > "$PS_D/st0" 2>&1
  pcm r0; r0="$(pcv_why)"
  r0ok=0
  if pcv_is_miss 0 && [ -f "$PC_REC" ] && [ "$(cat "$PS_D/r0.out")" = "$PCV_OKLINE" ]; then r0ok=1; fi
  git -C "$PC_C" status --porcelain > "$PS_D/st1" 2>&1
  pcm v1
  if [ "$r0ok" -eq 1 ] && pcv_is_hit v1 "$PC_REC"; then
    pcv_v PC-V1 "the second --verify on an unchanged world HITS: the pinned two lines, exit 0, and no detector launched, after a first run that rendered and recorded"
  else
    pcv_x PC-V1 "no hit on an unchanged world: first run [$r0, record $( [ -f "$PC_REC" ] && echo present || echo absent)], second run [$(pcv_why)]"
  fi
  pc_wt="$(find "$PC_C" -name 'ai-dlc-verify-pass*' ! -path "$PC_C/.git/*" | grep -c .)" || pc_wt=0
  pc_gd="$(find "$PC_C/.git" -maxdepth 1 -name 'ai-dlc-verify-pass' | grep -c .)" || pc_gd=0
  if [ "$pc_gd" -eq 1 ] && [ "$pc_wt" -eq 0 ] && cmp -s "$PS_D/st0" "$PS_D/st1"; then
    pcv_v PC-V14 "the record lives in the consumer's git-dir and git status --porcelain is byte-identical across the recording run"
  else
    pcv_x PC-V14 "the record is not confined to the git-dir: $pc_gd in .git, $pc_wt in the work tree, status $(cmp -s "$PS_D/st0" "$PS_D/st1" && echo unchanged || echo CHANGED)"
  fi

  # ---- V2: an edit OUTSIDE the region still hits ----
  printf '\n## Semantic notes\nedited outside the region after the PASS was recorded\n' >> "$PC_R"
  pcm v2
  if pcv_is_hit v2 "$PC_REC"; then pcv_v PC-V2 "an edit to the report OUTSIDE the region still HITS (the region, not the file, is keyed)"
  else pcv_x PC-V2 "an edit outside the region did not hit ($(pcv_why))"; fi

  # ---- V3 / V9: an edit INSIDE the region misses, exits 1, and writes no record ----
  if pcv_in PC-V3 PC-V9; then
  cp "$PC_R" "$PS_D/report.keep"; cp "$PC_REC" "$PS_D/rec.keep" 2>/dev/null
  awk -v p='^HARD-UNREGISTERED-CORE-DRIFT' '$0 ~ p && !d { d=1; next } { print }' "$PS_D/report.keep" > "$PS_D/report.v3"
  if cmp -s "$PS_D/report.keep" "$PS_D/report.v3" || [ ! -f "$PS_D/rec.keep" ]; then
    pcv_x PC-V3 "FIXTURE BROKEN: the in-region edit changed nothing, or there is no record to be wrongly accepted"
    pcv_x PC-V9 "FIXTURE BROKEN: V3's exit-1 run could not be built"
  else
    cat "$PS_D/report.v3" > "$PC_R"
    pcm v3
    if pcv_is_miss 1; then pcv_v PC-V3 "an edit INSIDE the region (a HARD row dropped) MISSES with a record present, and the fresh render fails it exit 1"
    else pcv_x PC-V3 "an edit inside the region was not a fresh exit-1 render ($(pcv_why)) -- a doctored region could ride a recorded PASS"; fi
    if [ -f "$PC_REC" ] && cmp -s "$PC_REC" "$PS_D/rec.keep"; then pcv_v PC-V9 "the exit-1 verify wrote no record: the record is byte-identical across it"
    else pcv_x PC-V9 "the exit-1 verify rewrote or removed the record"; fi
    cat "$PS_D/report.keep" > "$PC_R"; pcv_back
  fi
  fi # end pcv_in PC-V3 PC-V9

  # ---- V4..V16 and V26..V31, with V40/V41: one group, because each arm opens on the state the arm before it left ----
  # V17..V25 are not here: each seeds its own world (pcv_latarm), so they run in phase pcvlat, shard d.
  if pcv_in PC-V4 PC-V11 PC-V12 PC-V13 PC-V5 PC-V6 PC-V7 PC-V8 PC-V26 PC-V40 PC-V41 PC-V15 PC-V16 PC-V27 PC-V28 PC-V29 PC-V30 PC-V31; then
  # ---- V4 / V11 / V12 / V13: consumer changes the region does not see, each a miss at exit 0 ----
  if ! pcv_ctl v4; then pcv_noctl PC-V4; else
    printf 'v4 changed\n' > "$PC_C/notes/pc-v4.txt"; pcm v4
    if pcv_is_miss 0; then pcv_v PC-V4 "a tracked consumer file's content change MISSES and re-renders (exit 0)"
    else pcv_x PC-V4 "a tracked content change did not force a fresh render ($(pcv_why))"; fi
  fi
  if ! pcv_ctl v11; then pcv_noctl PC-V11; else
    chmod +x "$PC_C/notes/pc-v11.sh"
    if [ -z "$(git -C "$PC_C" status --porcelain -- notes/pc-v11.sh 2>/dev/null)" ]; then
      pcv_x PC-V11 "FIXTURE BROKEN: git does not see the chmod (core.fileMode off?), so the arm cannot discriminate"
    else
      pcm v11
      if pcv_is_miss 0; then pcv_v PC-V11 "chmod +x on a tracked file, bytes unchanged, MISSES and re-renders"
      else pcv_x PC-V11 "an exec-bit change did not force a fresh render ($(pcv_why))"; fi
    fi
  fi
  if ! pcv_ctl v12; then pcv_noctl PC-V12; else
    if ! git -C "$PC_C" check-ignore -q .claude/settings.local.json; then
      pcv_x PC-V12 "FIXTURE BROKEN: .claude/settings.local.json is not ignored, so the arm tests a tracked-file change"
    else
      printf '{"local": 2}\n' > "$PC_C/.claude/settings.local.json"; pcm v12
      if pcv_is_miss 0; then pcv_v PC-V12 "a change to the IGNORED .claude/settings.local.json MISSES and re-renders"
      else pcv_x PC-V12 "an ignored file under .claude/ changed without a fresh render ($(pcv_why))"; fi
    fi
  fi
  if ! pcv_ctl v13; then pcv_noctl PC-V13; else
    git -C "$PC_C" add notes/pc-v13.txt >/dev/null 2>&1
    if ! git -C "$PC_C" ls-files --error-unmatch notes/pc-v13.txt >/dev/null 2>&1; then
      pcv_x PC-V13 "FIXTURE BROKEN: git add did not track notes/pc-v13.txt"
    else
      pcm v13
      if pcv_is_miss 0; then pcv_v PC-V13 "git add of an untracked file, bytes unchanged, MISSES and re-renders"
      else pcv_x PC-V13 "an index-only change did not force a fresh render ($(pcv_why))"; fi
    fi
  fi

  # ---- V5: the stamp moved -- a miss, and STAMP-MOVED exactly as before the cache ----
  if ! pcv_ctl v5; then pcv_noctl PC-V5; else
    cp "$PC_C/.claude/.ai-dlc-version" "$PS_D/stamp.keep"
    printf 'version: 2.0.0\ncommit: %s\n' "$THEIRS" > "$PC_C/.claude/.ai-dlc-version"; pcm v5
    if pcv_is_miss 1 && grep -qF 'cause: STAMP-MOVED' "$PS_D/v5.err"; then
      pcv_v PC-V5 "a moved consumer stamp MISSES and the fresh render exits 1 naming STAMP-MOVED"
    else pcv_x PC-V5 "a stamp move was not a fresh STAMP-MOVED render ($(pcv_why))"; fi
    cat "$PS_D/stamp.keep" > "$PC_C/.claude/.ai-dlc-version"; pcv_back
  fi

  # ---- V6: another theirs COMMIT carrying the same core/ tree, refs untouched (an unreferenced object) ----
  if ! pcv_ctl v6; then pcv_noctl PC-V6; else
    pcv_run v6 "$PC_C" "$PC_R" "$PC_D" "$BASE" "$PC_T2"
    if pcv_is_miss 1; then pcv_v PC-V6 "a different theirs commit with the SAME core/ tree MISSES; the fresh render reads the moved theirs and exits 1"
    else pcv_x PC-V6 "a different theirs commit was not a fresh render ($(pcv_why)) -- the key holds the core tree but not the commit"; fi
    pcv_back
  fi

  # ---- V7: an engine one byte apart ----
  # No pcv_ctl here: v7c below, a byte-identical engine copy run on the same tree and record, is the
  # HIT the miss is read against, and the arm requires it. The record is kept for pcv_back as pcv_ctl did.
  if ! cp "$PC_REC" "$PS_D/rec.keep" 2>/dev/null; then pcv_x PC-V7 "control: no record exists before the engine change, so the identical copy cannot hit and a miss after it would prove nothing"; else
    if ! cp -R "$(dirname "$PS_E")" "$PS_D/eng7"; then pcv_x PC-V7 "FIXTURE BROKEN: could not copy the engine"
    else
      PCV_ENG="$PS_D/eng7/emit-report.sh"; pcm v7c; v7c="$(pcv_why)"; v7c_hit=0
      pcv_is_hit v7c "$PC_REC" && v7c_hit=1
      printf '\n' >> "$PS_D/eng7/emit-report.sh"
      if cmp -s "$PS_E" "$PS_D/eng7/emit-report.sh"; then pcv_x PC-V7 "FIXTURE BROKEN: the one-byte engine change did not apply"
      else
        pcm v7
        if [ "$v7c_hit" -eq 1 ] && pcv_is_miss 0; then
          pcv_v PC-V7 "a byte-identical engine copy elsewhere HITS, and the same copy one byte apart MISSES and re-renders"
        else pcv_x PC-V7 "engine: identical copy [$v7c], one byte apart [$(pcv_why)] (want hit, then a fresh exit-0 render)"; fi
      fi
      PCV_ENG=""
    fi
    pcv_back
  fi

  # ---- V8: the opt-out re-renders over a matching record ----
  if ! pcv_ctl v8; then pcv_noctl PC-V8; else
    pcm v8 nocache
    if pcv_is_miss 0; then pcv_v PC-V8 "AI_DLC_VERIFY_NO_CACHE=1 re-renders over a record that would hit"
    else pcv_x PC-V8 "the opt-out did not force a fresh render ($(pcv_why))"; fi
  fi

  # ---- V26: the cache ships OFF -- unarmed, a valid matching record is NOT accepted ----
  # Run right after an armed HIT on the same tree, so the record is valid and would hit if read. The
  # unarmed run must render, write or keep the record, and print exactly what the pre-cache engine
  # (2875c7ad) prints on the same world: stdout, stderr and exit code, byte for byte.
  if ! pcv_ctl v26; then pcv_noctl PC-V26; else
    PCV_ARM="-u EMIT_REPORT_VERIFY_CACHE"; pcm v26; PCV_ARM=""
    v26_why="$(pcv_why)"; v26_rec=absent; [ -f "$PC_REC" ] && v26_rec=present
    if [ "$PHIT" -ne 0 ] || [ "$PN" -eq 0 ] || [ "$PRC" -ne 0 ] || [ "$v26_rec" != present ]; then
      pcv_x PC-V26 "unarmed --verify over a valid record: [$v26_why], record $v26_rec (want a fresh exit-0 render, no hit line, the record still there)"
    elif [ -z "$PCV_OLD_ENG" ]; then
      # The pre-cache engine is not in this tree's history (a consumer, or a sandbox without the pin):
      # the byte comparison falls back to the pinned exit-0 line the amendment fixes, and says so.
      if [ "$(cat "$PS_D/v26.out")" = "$PCV_OKLINE" ] && [ ! -s "$PS_D/v26.err" ]; then
        pcv_v PC-V26 "unarmed, a valid record is NOT accepted: a fresh render, the record kept, stdout exactly the pinned exit-0 line and stderr empty -- THE ENGINE COMPARISON DID NOT RUN: 2875c7ad is not in this tree's history (a consumer), so the off path was checked against a constant, not against the pre-cache engine"
      else
        pcv_x PC-V26 "unarmed --verify printed something other than the pre-cache exit-0 line alone [$v26_why]"
      fi
    else
      env -u EMIT_REPORT_VERIFY_CACHE "$PCV_BASH" "$PCV_OLD_ENG" --verify "$PC_R" "$PC_D" "$BASE" "$PC_C" "$THEIRS" \
        > "$PS_D/v26.old.out" 2> "$PS_D/v26.old.err"; v26_orc=$?
      if [ "$v26_orc" -eq "$PRC" ] && cmp -s "$PS_D/v26.old.out" "$PS_D/v26.out" && cmp -s "$PS_D/v26.old.err" "$PS_D/v26.err"; then
        pcv_v PC-V26 "unarmed, a valid record is NOT accepted: a fresh render, the record kept, and stdout, stderr and exit byte-equal to the 2875c7ad engine on the same world"
      else
        pcv_x PC-V26 "unarmed --verify differs from the 2875c7ad engine: exit $PRC vs $v26_orc, stdout $(cmp -s "$PS_D/v26.old.out" "$PS_D/v26.out" && echo same || echo DIFFERS), stderr $(cmp -s "$PS_D/v26.old.err" "$PS_D/v26.err" && echo same || echo DIFFERS)"
      fi
    fi
  fi

  # ---- V40 (R3): an engine carrying a symlink refuses; the same engine copy without it HITS ----
  # A link inside the engine directory is skipped by the engine field's `find -type f`, so without R3
  # the linked copy computes the plain copy's key and HITS. The refusal must instead render fresh,
  # exit as the opt-out does, leave the record byte-identical and name R3.
  # No pcv_ctl here either: v40c, the plain engine copy on the same tree and record, is the HIT.
  if [ "$PCV_R6" -eq 1 ]; then
    if ! cp "$PC_REC" "$PS_D/rec.keep" 2>/dev/null; then pcv_x PC-V40 "control: no record exists before the engine symlink, so the plain copy cannot hit and a refusal after it would prove nothing"; else
      if ! cp -R "$(dirname "$PS_E")" "$PS_D/eng40"; then pcv_x PC-V40 "FIXTURE BROKEN: could not copy the engine"
      else
        PCV_ENG="$PS_D/eng40/emit-report.sh"; pcm v40c; v40c="$(pcv_why)"; v40c_hit=0
        pcv_is_hit v40c "$PC_REC" && v40c_hit=1
        ln -s emit-report.sh "$PS_D/eng40/zz-r6-link.sh"
        cp "$PC_REC" "$PS_D/rec40.keep"
        pcm v40.n nocache; v40_nc="$PRC"
        pcm v40; v40="$(pcv_why)"
        v40_rec=REWRITTEN; cmp -s "$PC_REC" "$PS_D/rec40.keep" && v40_rec=unchanged
        if [ ! -L "$PS_D/eng40/zz-r6-link.sh" ]; then pcv_x PC-V40 "FIXTURE BROKEN: the engine symlink was not created"
        elif [ "$v40c_hit" -eq 1 ] && pcv_is_miss "$v40_nc" && [ "$v40_rec" = unchanged ] \
             && grep -qF "${PCV_R6MARK}R3" "$PS_D/v40.err"; then
          pcv_v PC-V40 "an engine copy carrying a symlink MISSES by refusal (fresh render, exit $v40_nc as the opt-out, record untouched, R3 named), and the same copy without the link HITS"
        else
          pcv_x PC-V40 "engine symlink: plain copy [$v40c], linked copy [$v40], opt-out $v40_nc, record $v40_rec (want a hit, then a refusal naming R3 that leaves the record untouched)"
        fi
        PCV_ENG=""
      fi
      pcv_back
    fi
  fi

  # ---- V41 (rewritten for round 7): a live sh receipt naming a .git/ path is KEYED, not refused ----
  # Round 6 refused any receipt naming a `.git/` path (R4); round 7 keys every receipt subject's
  # presence in the receipts field instead. The receipt is RE-APPROVED (the region re-rendered into
  # the report) with .git/hooks/pre-push ABSENT, so the condition alone renders exit 0: it must now
  # RECORD (record rewritten, no refusal named) and then HIT. Creating the hook then moves the row the
  # render prints, and the cached run must MISS with the opt-out's non-zero exit -- the case round 6
  # refused and round 5 accepted stale. Near miss kept: a receipt naming docs/r6-nearmiss.md records
  # and then HITS.
  if [ "$PCV_R7" -eq 1 ]; then
    if ! pcv_ctl v41; then pcv_noctl PC-V41; else
      v41_lg="$PC_C/_bmad-output/ai-dlc-update/push-candidate-ledger.md"
      v41_hk="$PC_C/.git/hooks/pre-push"
      cp "$v41_lg" "$PS_D/ledger41.keep"; cp "$PC_R" "$PS_D/report41.keep"
      pcv_r41() { # <path the receipt names> -- append the entry and re-approve
        { cat "$PS_D/ledger41.keep"; printf '\n## PC-FIXTURE-R6-RECEIPT — a receipt naming %s\n\nverify: sh false # %s\n' "$1" "$1"; } > "$v41_lg"
        "$PCV_BASH" "$PS_E" "$PC_D" "$BASE" "$PC_C" "$THEIRS" > "$PS_D/region41.md" 2>/dev/null
        { echo "# Reconcile report (fixture)"; echo; cat "$PS_D/region41.md"; } > "$PC_R"
        grep -q 'reconcile-mechanical' "$PS_D/region41.md"
      }
      if [ -e "$v41_hk" ]; then pcv_x PC-V41 "FIXTURE BROKEN: .git/hooks/pre-push already exists, so its creation is not one property"
      elif ! pcv_r41 .git/hooks/pre-push; then pcv_x PC-V41 "FIXTURE BROKEN: the re-approval with the .git receipt rendered no region"
      else
        pcm v41; v41="$(pcv_why)"; v41a_ok=0
        pcv_is_miss 0 && ! cmp -s "$PC_REC" "$PS_D/rec.keep" && ! grep -qF "$PCV_R6MARK" "$PS_D/v41.err" && v41a_ok=1
        pcm v41h1; v41h1="$(pcv_why)"; v41h1_ok=0; pcv_is_hit v41h1 "$PC_REC" && v41h1_ok=1
        mkdir -p "$(dirname "$v41_hk")"; printf '#!/bin/sh\nexit 0\n' > "$v41_hk"
        pcm v41m; v41m="$(pcv_why)"; v41_rc="$PRC"; v41_hit="$PHIT"; v41_n="$PN"
        pcm v41m.n nocache; v41_nc="$PRC"; PRC="$v41_rc"; PHIT="$v41_hit"; PN="$v41_n"
        rm -f "$v41_hk"
        if [ "$v41a_ok" -ne 1 ] || [ "$v41h1_ok" -ne 1 ]; then
          pcv_x PC-V41 "a re-approved receipt naming an absent .git/hooks/pre-push: first [$v41], second [$v41h1] (want a fresh exit-0 render that records with no refusal named, then a hit)"
        elif [ "$v41_nc" -eq 0 ]; then
          pcv_x PC-V41 "FIXTURE BROKEN: the opt-out render after creating .git/hooks/pre-push still exits 0, so the receipt subject is not one the render sees"
        elif ! pcv_is_miss "$v41_nc"; then
          pcv_x PC-V41 "creating the .git/hooks/pre-push a receipt names did not force a fresh render: [$v41m], opt-out exits $v41_nc -- a recorded PASS answered for a subject it never keyed"
        elif ! pcv_r41 docs/r6-nearmiss.md; then pcv_x PC-V41 "FIXTURE BROKEN: the re-approval with the near-miss receipt rendered no region"
        else
          pcm v41b; v41b="$(pcv_why)"; v41b_ok=0; pcv_is_miss 0 && ! cmp -s "$PC_REC" "$PS_D/rec.keep" && v41b_ok=1
          pcm v41h
          if [ "$v41b_ok" -eq 1 ] && pcv_is_hit v41h "$PC_REC"; then
            pcv_v PC-V41 "a re-approved receipt naming an absent .git/hooks/pre-push records and HITS (keyed, not refused), creating the hook MISSES with the opt-out's exit $v41_nc, and one naming docs/r6-nearmiss.md records and then HITS"
          else
            pcv_x PC-V41 "near miss (a receipt naming docs/r6-nearmiss.md): first [$v41b], second [$(pcv_why)] (want a fresh exit-0 render that records, then a hit)"
          fi
        fi
      fi
      rm -f "$v41_hk"
      cat "$PS_D/ledger41.keep" > "$v41_lg"; cat "$PS_D/report41.keep" > "$PC_R"; pcv_back
    fi
  fi

  # ---- V15: a consumer that is NOT its own git top level never records ----
  PO="$PS_D/outer"; mkdir -p "$PO"
  if ! { cp -R "$CONSUMER" "$PO/consumer" && git -C "$PO" init -q && git -C "$PO" add -A \
         && git -C "$PO" -c user.email=f@f -c user.name=fixture commit -q -m outer; } >/dev/null 2>&1; then
    pcv_x PC-V15 "FIXTURE BROKEN: could not build the nested consumer"
  else
    PO_R="$PO/consumer/_bmad-output/ai-dlc-update/reconcile-report.md"; mkdir -p "${PO_R%/*}"
    "$PCV_BASH" "$PS_E" "$PC_D" "$BASE" "$PO/consumer" "$THEIRS" > "$PS_D/region15.md" 2>/dev/null
    { echo "# Reconcile report (fixture)"; echo; cat "$PS_D/region15.md"; } > "$PO_R"
    pcv_run v15a "$PO/consumer" "$PO_R" "$PC_D" "$BASE" "$THEIRS"; v15a="$(pcv_why)"; v15a_ok=0
    pcv_is_miss 0 && [ "$(cat "$PS_D/v15a.out")" = "$PCV_OKLINE" ] && v15a_ok=1
    pcv_run v15b "$PO/consumer" "$PO_R" "$PC_D" "$BASE" "$THEIRS"
    po_rec="$(find "$PO" -name 'ai-dlc-verify-pass*' | grep -c .)" || po_rec=0
    po_ctl="$(find "$PO/.git" -maxdepth 1 -name HEAD | grep -c .)" || po_ctl=0
    if ! grep -q 'reconcile-mechanical' "$PS_D/region15.md" || [ "$po_ctl" -ne 1 ]; then
      pcv_x PC-V15 "FIXTURE BROKEN: the nested world rendered no region, or its find control read $po_ctl"
    elif [ "$v15a_ok" -eq 1 ] && pcv_is_miss 0 && [ "$(cat "$PS_D/v15b.out")" = "$PCV_OKLINE" ] && [ "$po_rec" -eq 0 ]; then
      pcv_v PC-V15 "a consumer nested in another repository renders on both runs, prints only the pre-cache exit-0 line, and no record appears anywhere"
    else
      pcv_x PC-V15 "nested consumer: first [$v15a], second [$(pcv_why)], records found $po_rec (want two plain exit-0 renders and none)"
    fi
  fi

  # ---- V16: the dist's HEAD moves (detached, unreferenced commit), every ref unchanged ----
  if ! pcv_ctl v16; then pcv_noctl PC-V16; else
    git -C "$PC_D" for-each-ref > "$PS_D/refs0" 2>&1
    pc_n="$(git -C "$PC_D" -c user.email=f@f -c user.name=fixture commit-tree 'HEAD^{tree}' -p HEAD -m pc-v16 2>/dev/null)" || pc_n=""
    [ -n "$pc_n" ] && git -C "$PC_D" update-ref --no-deref HEAD "$pc_n" >/dev/null 2>&1
    git -C "$PC_D" for-each-ref > "$PS_D/refs1" 2>&1
    if [ -z "$pc_n" ] || [ "$(git -C "$PC_D" rev-parse HEAD 2>/dev/null)" != "$pc_n" ] || ! cmp -s "$PS_D/refs0" "$PS_D/refs1"; then
      pcv_x PC-V16 "FIXTURE BROKEN: HEAD did not move to a new unreferenced commit with every ref unchanged"
    else
      pcm v16
      if pcv_is_miss 0; then pcv_v PC-V16 "the dist's HEAD moved to an unreferenced commit with every ref unchanged, and the next --verify MISSES and re-renders"
      else pcv_x PC-V16 "a moved dist HEAD did not force a fresh render ($(pcv_why))"; fi
    fi
  fi

  # ---- V27..V31: inputs the key REFUSES or keys after a fourth review, in ONE shared world ----
  pcv_kworld
  fi # end pcv_in V4..V16 and V26..V31, with V40/V41

  # ---- V32..V36: a fifth review's key gaps, two worlds of their own ----
  # Each world is seeded fresh by its own pcv_lat, so each is its own group.
  if pcv_in PC-V32 PC-V35 PC-V36; then pcv_k2world; fi
  if pcv_in PC-V33; then pcv_k3world; fi
  if pcv_in PC-V34; then pcv_k4world; fi
  if pcv_in PC-V37; then pcv_k5world; fi
  if pcv_in PC-V55; then pcv_v55world; fi

  # ---- V38, V39, V42: the round-6 partition (R1, R2) and the detectors' --no-filters (B2) ----
  if [ "$PCV_R6" -eq 1 ]; then
    if pcv_in PC-V38 PC-V39; then pcv_r6world; fi
    if [ "$PCV_V42" -eq 1 ] && pcv_in PC-V42; then pcv_b2world; fi
    # ---- V56, V57: the key's own tools (cksum, the sha256 tool) absent, in the MAIN world (BL-777) ----
    if [ "$PCV_R9" -eq 1 ] && pcv_in PC-V56 PC-V57; then pcv_r9world; fi
  fi
  # ---- V44..V47: the round-7 partition, in the MAIN world after the round-6 arms ----
  if [ "$PCV_R7" -eq 1 ]; then
    if pcv_in PC-V44 PC-V45 PC-V46 PC-V47; then pcv_r7world; fi
  fi
  # ---- V48..V54: the round-8 partition, gated by pcv_r8gate alone (a FAIL by name, never a SKIP) ----
  if [ "$PCV_R7F" -eq 1 ]; then
    if pcv_in PC-V48; then pcv_r7content; fi
    if pcv_in PC-V49 PC-V50 PC-V51 PC-V52 PC-V53 PC-V54; then pcv_r8world; fi
  fi

  # ---- V10: a REGISTER ROW resolves HARD-LAYER-ADJUDICATION-MISSING: a miss reaching exit 3 ----
  # The world is layer-adjudication-tier's seed (its own git top level, one adjudicable row). The
  # register lives in _bmad-output/ai-dlc-update/, the directory the report lives in, so a key that
  # excluded the whole directory would hit here. After the exit-3 run the record must be unchanged
  # and a second run must reach exit 3 again: a record written on exit 3 would turn it into a hit.
  if ! pcv_in PC-V10; then :
  elif ! command -v jq >/dev/null 2>&1; then pcv_x PC-V10 "jq is not on PATH; layer-drift.sh cannot read the register, so no resolution can be seeded"
  elif ! pcv_lat v10; then
    pcv_x PC-V10 "FIXTURE BROKEN: layer-adjudication-tier/seed.sh did not build its world"
  else
    L_REG="$L_C/_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl"
    pcv_lat_approve v10
    bash "$(dirname "$PS_E")/layer-drift.sh" "$L_D" "$L_B" "$L_T" "$L_C" > "$PS_D/ld10.out" 2>/dev/null
    L_DIG="$(awk -F'\t' '$1 == "HARD-LAYER-ADJUDICATION-MISSING"' "$PS_D/ld10.out" | grep -o 'subject_digest [0-9a-f]\{40\}' | awk '{ print $2; exit }')"
    if [ ! -s "$PS_D/region-v10.md" ] || ! grep -q '^HARD-LAYER-ADJUDICATION-MISSING' "$PS_D/region-v10.md"; then
      pcv_x PC-V10 "FIXTURE BROKEN: the adjudication world's approval (region-v10.md) is missing or carries no HARD-LAYER-ADJUDICATION-MISSING row, so there is no blocker to resolve"
    elif [ "${#L_DIG}" -ne 40 ]; then
      pcv_x PC-V10 "FIXTURE BROKEN: layer-drift.sh printed no 40-hex subject_digest on its HARD-LAYER-ADJUDICATION-MISSING row, so no register row can be recorded against it"
    else
      pcv_run v10r "$L_C" "$L_R" "$L_D" "$L_B" "$L_T"; v10r="$(pcv_why)"; v10r_ok=0
      pcv_is_miss 0 && [ -f "$L_REC" ] && v10r_ok=1
      pcv_run v10c "$L_C" "$L_R" "$L_D" "$L_B" "$L_T"; v10c="$(pcv_why)"; v10c_ok=0
      pcv_is_hit v10c "$L_REC" && v10c_ok=1
      if [ "$v10r_ok" -ne 1 ] || [ "$v10c_ok" -ne 1 ]; then
        pcv_x PC-V10 "control: the adjudication world did not record [$v10r] and then hit [$v10c], so its resolution's miss would prove nothing"
      else
        cp "$L_REC" "$PS_D/rec10.keep"
        L_ENT=".claude/skills/ai-dlc/extensions/adjudicable.md"
        if ! L_EV="$(pcv_read_ev "$L_ENT")"; then
          pcv_x PC-V10 "FIXTURE BROKEN: no read evidence could be derived from the world's entry body and LC-E4 range diff, so no row can resolve (needs jq >= 1.6 for --rawfile)"
        else
          jq -cn --arg e "$L_ENT" --arg d "$L_DIG" --argjson r "$L_EV" \
            '{clause:"LC-E4",entry:$e,subject_digest:$d,verdict:"still-additive",recorded_utc:"2026-01-01T00:00:00Z",reason:"seeded",read:$r}' >> "$L_REG"
          if ! pcv_read_clears "$PS_D/ld10r.out"; then
            pcv_x PC-V10 "FIXTURE BROKEN: layer-drift.sh still prints HARD-LAYER-ADJUDICATION-MISSING (or did not exit 0) with the read-evidence row appended (ld10r.out), where the plain world printed it (ld10.out, the digest's source) -- the row does not resolve, so a cached FAIL below would be the seed's"
          else
            pcv_run v10 "$L_C" "$L_R" "$L_D" "$L_B" "$L_T"; v10="$(pcv_why)"; v10_ok=0
            pcv_is_miss 3 && grep -qF 'cause: BLOCKERS-RESOLVED' "$PS_D/v10.err" && v10_ok=1
            v10_rec=CHANGED; cmp -s "$L_REC" "$PS_D/rec10.keep" && v10_rec=unchanged
            pcv_run v10b "$L_C" "$L_R" "$L_D" "$L_B" "$L_T"
            if [ "$v10_ok" -eq 1 ] && [ "$v10_rec" = unchanged ] && pcv_is_miss 3; then
              pcv_v PC-V10 "a register row resolving HARD-LAYER-ADJUDICATION-MISSING MISSES, exits 3 BLOCKERS-RESOLVED, leaves the record unchanged, and a second run exits 3 again"
            else
              pcv_x PC-V10 "register-row resolution: first [$v10], record $v10_rec, second [$(pcv_why)] (want two fresh exit-3 renders and the record untouched)"
            fi
          fi
        fi
      fi
    fi
  fi
  return 0
}

# pcv_failset <verdicts> [scope] -- every id that has no single ok line (a FAIL, or no verdict at all),
# in PCV_IDS order. With a scope, only the ids it names are read; with none, every id is.
pcv_failset() {
  local id o f out=""
  for id in $PCV_IDS; do
    if [ -n "${2:-}" ]; then case " $2 " in *" $id "*) ;; *) continue ;; esac; fi
    o="$(grep -c "^ok $id " "$1")" || o=0
    f="$(grep -c "^FAIL $id " "$1")" || f=0
    { [ "$o" -eq 1 ] && [ "$f" -eq 0 ]; } || out="$out $id"
  done
  printf '%s\n' "${out# }"
}

# THE MUTANTS. Each is a COPY of the reconcile directory with one line of emit-report.sh edited by
# awk on an exact whole-line anchor that must occur ONCE, guarded by cmp -s. Expected kill sets:
#   M-region   the region field dropped from the key loop: a doctored region rides the record -> PC-V3
#   M-direxcl  the work-tree exclusion widened from the report FILE to its DIRECTORY, which hides
#              layer-adjudication-register.jsonl from the key                              -> PC-V10
#   M-exit3    er_cache_record called before the mismatch tail, so exit 1 and exit 3 record -> PC-V9 PC-V10
# BL-777's four, each against the key's own tools (V56 no cksum, V57 no sha256 tool):
#   M-cksum    the `command -v cksum` refusal made a no-op: the env field then fails and the
#              per-field fallback names a DIFFERENT cause                                  -> PC-V56
#   M-base     BOTH layers reverted (true base): no cksum refusal, and the field loop's two
#              refusals back to a bare return 1, so neither tool's absence names anything  -> PC-V56 PC-V57
#   M-sha      the sha256-failure refusal dropped: a failed er_sha256 returns 1 unnamed   -> PC-V57
#   M-unarmed  the stderr print guard loses its EMIT_REPORT_VERIFY_CACHE=1 conjunct, so the
#              refusal prints unarmed and V56's unarmed-identity half sees it             -> PC-V56
# pcv_ed <dir> <mode> <anchor> <text> -- one whole-line edit of <dir>/eng/emit-report.sh, on an anchor
# that must occur ONCE in the copy as it stands; each count is appended to <dir>/anchor-count.
pcv_ed() {
  local f="$1/eng/emit-report.sh" n
  n="$(grep -cxF -- "$3" "$f")" || n=0
  printf '%s\n' "$n" >> "$1/anchor-count"
  [ "$n" -eq 1 ] || return 1
  awk -v a="$3" -v t="$4" -v m="$2" '$0 == a { print t; if (m == "replace") next } { print }' "$f" > "$f.ed" \
    && mv -f "$f.ed" "$f"
}
pcv_mk() { # pcv_mk <name> -> 0 when <root>/<name>/eng/emit-report.sh is built, parses, and differs
  local d="$PCV_ROOT/$1"
  local r9ck='    || { er_refuse "cksum is not on PATH, so the env field cannot checksum the awk, sed and sort binaries it keys"; return 1; }'
  local r9fld='      [ "$f" = region ] || [ -s "$_er_tmp/key.refused" ] || er_refuse "the $f field could not be computed"'
  local r9sha='      if command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1; then'
  mkdir -p "$d" && cp -R "$(dirname "$EMIT")" "$d/eng" && : > "$d/anchor-count" || return 1
  case "$1" in
    M-region)  pcv_ed "$d" replace \
                 '  for f in engine base theirs distrefs consroot consindex conswork consignored consobjects consresolve env region; do' \
                 '  for f in engine base theirs distrefs consroot consindex conswork consignored consobjects consresolve env; do' ;;
    M-direxcl) pcv_ed "$d" replace '    _er_ex="$_er_rel"' '    _er_ex="${_er_rel%/*}"' ;;
    M-exit3)   pcv_ed "$d" before '[ "$cause" = BLOCKERS-RESOLVED ] && exit 3' 'er_cache_record' ;;
    M-cksum)   pcv_ed "$d" replace "$r9ck" '    || :' ;;
    M-base)    pcv_ed "$d" replace "$r9ck" '    || :' && pcv_ed "$d" replace "$r9fld" '      :' \
                 && pcv_ed "$d" before "$r9sha" '      return 1' ;;
    M-sha)     pcv_ed "$d" before "$r9sha" '      return 1' ;;
    M-unarmed) pcv_ed "$d" replace '   && [ "${EMIT_REPORT_VERIFY_CACHE:-}" = 1 ] && [ -z "${AI_DLC_VERIFY_NO_CACHE:-}" ]; then' \
                 '   && [ -z "${AI_DLC_VERIFY_NO_CACHE:-}" ]; then' ;;
    *) return 1 ;;
  esac || return 1
  bash -n "$d/eng/emit-report.sh" 2>/dev/null || return 1
  ! cmp -s "$EMIT" "$d/eng/emit-report.sh"
}
pcv_want() {
  case "$1" in
    M-region) echo "PC-V3" ;; M-direxcl) echo "PC-V55" ;; M-exit3) echo "PC-V9 PC-V10" ;;
    M-cksum) echo "PC-V56" ;; M-base) echo "PC-V56 PC-V57" ;; M-sha) echo "PC-V57" ;; M-unarmed) echo "PC-V56" ;;
  esac
}
# pcv_bl <name> -- the backlog entry a mutant belongs to, for its verdict lines
pcv_bl() { case "$1" in M-cksum|M-base|M-sha|M-unarmed) echo BL-777 ;; *) echo BL-679 ;; esac; }
# THE ARMS A MUTANT RUNS, and they are the population "fails exactly [...]" is read over. A mutant used
# to run all 32 arms, three near-full copies of the shipping suite each paying ~90 --verify renders,
# which made this phase the suite pole (BL-699). Each mutant now runs the always-on prefix PC-V0 PC-V1
# PC-V14 PC-V2 and the arm groups holding its declared kill set, nothing else. The prefix is not
# decoration: V0 is the harness check below, and V1/V14 must PASS on the mutant, which is what proves
# the mutated record-then-hit path still works, so a mutant that broke the cache outright reads as
# entangled instead of scoring an unearned kill. Inside the groups the arm the mutant must NOT kill is
# the same-run control: V9 on M-region, V3 on M-exit3. WHAT THIS GIVES UP: an arm outside a mutant's
# groups can no longer show up in its kill set, so a change that would entangle such an arm (the
# V17..V20 ordering hazard noted in pcv_latarm) is not caught by the scoring; no declared kill is lost.
# V17..V25 are outside every mutant's reach entirely: they run in phase pcvlat (shard d), against the
# shipping engine only.
# The later groups (V40/V41 inside the V4..V31 group; the k2, k3, k4, k5, r6, b2 and r7 worlds) hold
# no declared kill, so no mutant runs them; the shipping suite still runs every one.
pcv_scope() {
  case "$1" in
    M-region)  echo "PC-V0 PC-V1 PC-V14 PC-V2 PC-V3 PC-V9" ;;
    M-direxcl) echo "PC-V0 PC-V1 PC-V14 PC-V2 PC-V10 PC-V55" ;;
    M-exit3)   echo "PC-V0 PC-V1 PC-V14 PC-V2 PC-V3 PC-V9 PC-V10" ;;
    # BL-777: both tool arms run for each, so the one a mutant must NOT kill is its same-run control.
    M-cksum|M-base|M-sha|M-unarmed) echo "PC-V0 PC-V1 PC-V14 PC-V2 PC-V56 PC-V57" ;;
  esac
}
# A KILL IS EVIDENCE ONLY WHEN ITS ARM RAN. pcv_failset counts an id with no verdict line as failed, so
# a declared kill id left out of the scope, or named in it while no pcv_in group runs it, would read as
# "fails exactly [...]" with the arm never run. pcv_offscope prints the declared kill ids pcv_scope
# omits (the launch refuses the mutant on any); pcv_noverdict prints the scoped ids the mutant's run
# left no ok/FAIL line for (the scoring refuses on any).
pcv_offscope() {
  local id out=""
  for id in $(pcv_want "$1"); do case " $(pcv_scope "$1") " in *" $id "*) ;; *) out="$out $id" ;; esac; done
  printf '%s\n' "${out# }"
}
pcv_noverdict() { # pcv_noverdict <verdicts> <scope>
  local id out=""
  for id in $2; do grep -qE "^(ok|FAIL) $id " "$1" 2>/dev/null || out="$out $id"; done
  printf '%s\n' "${out# }"
}
PCV_MUTS="M-region M-direxcl M-exit3"
# BL-777's mutants score only where V56/V57 run (PCV_R9); where they are PENDING no kill can be read.
[ "${PCV_R9:-0}" -eq 1 ] && PCV_MUTS="$PCV_MUTS M-cksum M-base M-sha M-unarmed"

if ! pcv_cache_engine "PC-V0..PC-V55 but PC-V17..PC-V25"; then :
else
  mkdir -p "$PCV_ROOT/ship"
  ( pcv_suite "$EMIT" "$PCV_ROOT/ship" ) > "$PCV_ROOT/ship.log" 2>&1 &
  PCV_BUILT=""
  # MUTANT SCORING IS A DISTRIBUTION ACTIVITY. In the installed layout a mutant whose anchor the engine
  # does not carry (a pre-migration engine) is PENDING, one line, not built and not a failure. In the
  # distribution the same miss is MUTANT NOT BUILT below, a FAIL.
  if pcv_installed "$EMIT"; then
    _pm=""; _pr0="$PCV_ROOT"; PCV_ROOT="$_pr0/anchor-precheck"
    for _m in $PCV_MUTS; do pcv_mk "$_m" || _pm="$_pm $_m"; done
    PCV_ROOT="$_pr0"
    if [ -n "$_pm" ]; then
      printf 'PENDING: mutants%s not scored, engine lacks their anchors\n' "$_pm"
      _keep=""; for _m in $PCV_MUTS; do case " $_pm " in *" $_m "*) ;; *) _keep="$_keep $_m" ;; esac; done
      PCV_MUTS="${_keep# }"
    fi
  fi
  for _m in $PCV_MUTS; do
    if [ -z "$(pcv_scope "$_m")" ]; then
      bad "MUTANT NOT SCOPED [$(pcv_bl "$_m") $_m]: pcv_scope names no arms for it, so it would run none and score nothing"
    elif [ -n "$(pcv_offscope "$_m")" ]; then
      bad "FIXTURE BROKEN [$(pcv_bl "$_m") $_m]: its declared kill set names [$(pcv_offscope "$_m")], which pcv_scope does not run, so that kill would be read off an arm that never ran"
    elif pcv_mk "$_m"; then
      PCV_BUILT="$PCV_BUILT $_m"
      ( pcv_suite "$PCV_ROOT/$_m/eng/emit-report.sh" "$PCV_ROOT/$_m" "$(pcv_scope "$_m")" ) > "$PCV_ROOT/$_m.log" 2>&1 &
    else
      bad "MUTANT NOT BUILT [$(pcv_bl "$_m") $_m]: its anchor(s) occur [$(tr '\n' ' ' < "$PCV_ROOT/$_m/anchor-count" 2>/dev/null || echo '?')] time(s) in emit-report.sh (want 1), or the edit changed nothing -- re-anchor it on the engine's line"
    fi
  done
  wait
  pcv_read_ids "$PCV_ROOT/ship/verdicts" "$PCV_IDS" pcache
  if grep -q '^FAIL ' "$PCV_ROOT/ship/verdicts" 2>/dev/null || [ -s "$PCV_ROOT/ship.log" ]; then
    awk 'NR <= 20 { print "  DIAG  pcache ship.log | " $0 }' "$PCV_ROOT/ship.log"
  fi
  # THE CONTROL GATES THE SCORE. A mutant's kill set is a difference from the shipping engine, so an id
  # the shipping run did not pass would sit in every kill set and score kills nobody earned (measured:
  # a control-red PC-V10 made M-direxcl read "fails exactly [PC-V10]"). Any control id not ok means no
  # mutant is scored, and each is reported as UNSCORED naming the control's failing ids.
  PCV_CTLFAIL="$(pcv_failset "$PCV_ROOT/ship/verdicts")"
  for _m in $PCV_BUILT; do
    _got="$(pcv_failset "$PCV_ROOT/$_m/verdicts" "$(pcv_scope "$_m")")"; _want="$(pcv_want "$_m")"
    if [ -n "$PCV_CTLFAIL" ]; then
      bad "MUTANT UNSCORED [$(pcv_bl "$_m") $_m]: the unmutated control did not pass [$PCV_CTLFAIL], so a kill set read against it would credit the control's failures as kills"
      continue
    fi
    case " $_got " in
      *" PC-V0 "*) bad "MUTANT HARNESS BROKEN [$(pcv_bl "$_m") $_m]: the copy failed the seed sanity arm, so its score is a copy that did not run" ;;
      *)
        _nv="$(pcv_noverdict "$PCV_ROOT/$_m/verdicts" "$(pcv_scope "$_m")")"
        if [ -n "$_nv" ]; then
          bad "FIXTURE BROKEN [$(pcv_bl "$_m") $_m]: scoped arms [$_nv] left no verdict, so no pcv_in group ran them and a kill there would be unearned"
          continue
        fi
        if [ "$_got" = "$_want" ]; then ok "mutant $(pcv_bl "$_m") $_m fails exactly [$_want] within its scope"
        elif [ -z "$_got" ]; then bad "MUTANT SURVIVED [$(pcv_bl "$_m") $_m]: every arm passed with the edit in place, so [$_want] cannot see it"
        else bad "MUTANT [$(pcv_bl "$_m") $_m] failed [$_got], expected exactly [$_want] -- the arms are entangled or one is vacuous"; fi ;;
    esac
  done
fi
fi # end rer_phase pcache

# --- V17..V25: inputs the render reads that a key can miss, each in its own adjudication world ---
# Phase pcvlat, shard d. Each world is layer-adjudication-tier's seed (a git top level whose render
# carries an adjudicable extension), built FRESH by pcv_latarm's own pcv_lat, so no arm reads the main
# world or the state another arm left: that is why they could leave pcache's ordered group. The
# change is chosen so the FRESH render really differs: each arm asserts the cached run is a fresh
# render with a NON-ZERO exit equal to an AI_DLC_VERIFY_NO_CACHE=1 run on the same tree, so an arm
# whose change the render cannot see fails here rather than passing vacuously. They run against the
# shipping engine only; no mutant's kill set names them. Verdicts are read by pcv_read_ids, the
# same rule as pcache's, over exactly PCV_LAT_IDS, and a verdict for any other id is a FAIL.
if rer_phase pcvlat; then
pcv_setup
PCV_LAT_IDS="PC-V17 PC-V18 PC-V19 PC-V20 PC-V21 PC-V22 PC-V23 PC-V24 PC-V25"
if pcv_cache_engine "PC-V17..PC-V25"; then
  PS_E="$EMIT"; PS_D="$PCV_ROOT/lat"; PS_SHIM="$PS_D/shim"; PCV_ENG=""
  if mkdir -p "$PS_D" && : > "$PS_D/verdicts" && pcv_shim; then
    (
      pcv_latarm PC-V17 v17 "an UNTRACKED extension whose name carries a double quote, rewritten between the calls (its hooks: line dropped),"
      pcv_latarm PC-V18 v18 "an UNTRACKED scripts/ai-dlc/validate-hook-registration.sh going 644 to 755, a bit the render reads,"
      pcv_latarm PC-V19 v19 "a TRACKED file's chmod under core.filemode=false, which git status cannot see,"
      pcv_latarm PC-V20 v20 "a --verify recorded with the FULL base sha and re-run with the SHORT spelling of the same commit"
      pcv_latarm PC-V21 v21 "a prune of the dangling CONSUMER commit an override's base_sha names"
      pcv_latarm PC-V22 v22 "a prune of the dangling DIST commit an override's base_sha names"
      pcv_latarm PC-V23 v23 "git config core.abbrev 20 in the dist, which re-spells an abbreviated sha the region prints,"
      pcv_latarm PC-V24 v24 "a verify under LC_ALL=C of a PASS recorded under en_US.UTF-8, where the render's sort order differs,"
      pcv_latarm PC-V25 v25 "chmod 000 on .claude/skills/ai-dlc/extensions, a directory the render reads,"
    ) > "$PCV_ROOT/lat.log" 2>&1
    pcv_read_ids "$PS_D/verdicts" "$PCV_LAT_IDS" pcvlat
    if grep -q '^FAIL ' "$PS_D/verdicts" 2>/dev/null || [ -s "$PCV_ROOT/lat.log" ]; then
      awk 'NR <= 20 { print "  DIAG  pcvlat lat.log | " $0 }' "$PCV_ROOT/lat.log"
    fi
  else
    bad "FIXTURE BROKEN: [pcvlat] could not create $PS_D, its verdicts file, or the PATH shim, so V17..V25 cannot run"
  fi
fi
fi # end rer_phase pcvlat

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
if [ "$fails" -eq 0 ]; then
  echo "reconcile-emit-report: PASS"
  echo "PASS: all $oks assertions correct in shard '$GROUP' of '$SHARDS'."
  exit 0
fi
echo "reconcile-emit-report: $fails assertion(s) FAILED" >&2
echo "FAIL: $fails of $((oks + fails)) assertions wrong in shard '$GROUP' of '$SHARDS'."
exit 1
