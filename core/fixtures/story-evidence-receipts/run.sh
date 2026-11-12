#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# story-evidence-receipts/run.sh -- the FULL CONTROL CALLS of story-evidence-scaffold's four receipts (BL-809, BL-815,
# BL-843, BL-845) on the shipped validate-handoff-evidence.sh, and BL-979's RAN SET (C3) over each. Split out of
# story-evidence-scaffold (the suite pole) so the pool runs it beside that fixture.
#
# THE RECEIPTS STAY WHERE THEIR verify: LINES NAME THEM, in core/fixtures/story-evidence-scaffold/, beside the
# he-inproc.sh they source. Each is SOURCED in a fresh subshell (he-inproc.sh's rcpt_run), and each asks the validator in
# process from a copy of the whole scripts directory plus the sprint-status schema (world.sh's mk_tree control), so no
# bash is started per verdict. A receipt seeds its git worlds ONCE, into $WORK/rw-<receipt> ($SMW for bl845).
#
# ARMS.
#   WANT-CELLS PROBE  the C3 extractor, driven on a seeded file in both directions before any receipt is read.
#   CAPTURE NORMALISATION / BL-809 ARMS / BL-845 SMOKE ARMS / CAPTURE-HEADS  each receipt's full call (no cells named)
#                     exits 0 on the shipped validator: every cell it carries holds.
#   RAN SET bl815 / bl809 / bl845 / bl843  BL-979 C3: the full call's `RAN <cell>` set EQUALS the set the receipt's own
#                     CODE gates (want_cells), so a dead or partly dead want() gate fails here, not silently.
#   INPROC            every subject call above was answered in process (UT_FALLBACK_LOG empty, and present).
#
# THE MUTATION BATTERY IS NOT HERE. Its mutants edit copies of core's own validator and of the receipts, so it is
# distribution-only and lives in story-evidence-receipts-mutants (a `.dist-only` fixture), which SOURCES this file:
# everything above the BASH_SOURCE guard below (the control tree, the receipt paths, the run functions and the C3
# extractor) is defined, and the guard returns to it before this file makes its own control calls. That fixture
# makes its OWN four control calls, so each mutant's baseline flag is set in the file that scores it.
#
# Exit: 0 every arm passed, 1 an arm failed, 2 the fixture could not run.
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/story-evidence-receipts.XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT
# he-inproc.sh appends every subject call it could NOT answer in process here; the INPROC arm reads it.
export UT_FALLBACK_LOG="$WORK/.fallback"; : > "$UT_FALLBACK_LOG"
rc=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; rc=1; }
# Each receipt by the fixture-relative path its verify: lines and BL-915 E1 name it.
R809="$DIR/../story-evidence-scaffold/receipt-bl809.sh"
R815="$DIR/../story-evidence-scaffold/receipt-bl815.sh"
R843="$DIR/../story-evidence-scaffold/receipt-bl843.sh"
R845="$DIR/../story-evidence-scaffold/receipt-bl845.sh"
SES="$DIR/../story-evidence-scaffold"
for _f in "$SES/world.sh" "$SES/he-inproc.sh" "$R809" "$R815" "$R843" "$R845"; do
  [ -f "$_f" ] || { echo "story-evidence-receipts: FIXTURE BROKEN -- $_f is absent. An absent subject is not a passing one." >&2; exit 2; }
done
# world.sh locates HE, SCHEMA and SSH in both layouts and defines mk_tree; it sources he-inproc.sh (rcpt_run).
# shellcheck source=/dev/null
. "$SES/world.sh" || { echo "story-evidence-receipts: FIXTURE BROKEN -- cannot source story-evidence-scaffold/world.sh" >&2; exit 2; }
{ [ -n "$HE" ] && [ -n "$SCHEMA" ] && [ -n "$SSH" ] && [ -f "$(dirname "$HE")/record-only-diff.sh" ]; } \
  || { echo "story-evidence-receipts: FIXTURE BROKEN -- validate-handoff-evidence.sh, its record-only-diff.sh / sprint-status.sh siblings or the sprint-status schema is absent in both layouts. An absent subject is not a passing one." >&2; exit 2; }
for p in scripts/validate-handoff-evidence.sh scripts/record-only-diff.sh scripts/sprint-status.sh schemas/sprint-status.json \
  fixtures/story-evidence-scaffold/world.sh fixtures/story-evidence-scaffold/he-inproc.sh \
  fixtures/story-evidence-scaffold/receipt-bl809.sh fixtures/story-evidence-scaffold/receipt-bl815.sh \
  fixtures/story-evidence-scaffold/receipt-bl843.sh fixtures/story-evidence-scaffold/receipt-bl845.sh; do
  echo "HERMETIC-CONSUMED core/$p"
done
# The control tree: the whole scripts directory and the schema, laid out as the shipped one is.
HECTL="$(mk_tree control)" && [ -f "$(dirname "$HECTL")/record-only-diff.sh" ] \
  || { echo "story-evidence-receipts: FIXTURE BROKEN -- the control tree (scripts dir + schema) could not be built" >&2; exit 2; }

# --- BL-979 RAN SET (C3) AND RAN-TIED KILL CREDIT (C2) ---------------------------------------------
# A receipt's want() gate decides which cells a call runs; a dead want() ran NONE of them on the full call
# and every receipt still exited 0. So each gated block prints `RAN <cell>`, and the full control call's
# RAN set must EQUAL the set the receipt's own CODE gates (want_cells: comment lines stripped, then every
# `want <cell>` behind a line start or an `if `, `! `, `|| `, `&& `, `then `, `; ` or `{ ` prefix, and every
# call site `<helper> <cell>` behind the same prefixes, where a helper is any function whose body calls
# `want "$1"`; the helper names are derived from the receipt, never listed). A mutant's kill on a gated cell
# is credited only when that cell's RAN line is in the full control call's output (kill_credit, defined in
# story-evidence-receipts-mutants beside the mutants it credits); an ungated cell (no `want` site) keeps its B_x.
want_cells() { # <receipt> -> its want-gated cell names, one per line, sorted and unique
  LC_ALL=C awk '
    /^[[:space:]]*#/ { next }
    { L[++n] = $0 }
    END {
      cur = ""
      for (i = 1; i <= n; i++) {
        s = L[i]
        if (match(s, /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[(][)][[:space:]]*[{]/)) {
          cur = substr(s, RSTART, RLENGTH); sub(/^[[:space:]]*/, "", cur); sub(/[(].*/, "", cur)
        }
        if (cur != "" && index(s, "want \"$1\"")) H[cur] = 1
        if (s ~ /^[}]/ || s ~ /[}][[:space:]]*$/ && s ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[(][)]/) cur = ""
      }
      alt = "want"; for (h in H) alt = alt "|" h
      re = "(^[[:space:]]*|if |! |[|][|] |&& |then |; |[{] )(" alt ") [a-z0-9]+"
      for (i = 1; i <= n; i++) {
        s = L[i]
        while (match(s, re)) {
          m = substr(s, RSTART, RLENGTH); sub(/.* /, "", m); C[m] = 1
          s = "\001" substr(s, RSTART + RLENGTH)
        }
      }
      for (c in C) print c
    }' "$1" | LC_ALL=C sort -u
}
ran_set() { grep -E '^RAN [a-z0-9]+$' <<<"$1" | sed 's/^RAN //' | LC_ALL=C sort -u; }
c3_check() { # <receipt> <full-call output> -> status 0 when the RAN set equals want_cells; else 1 and the message
  local w r; w="$(want_cells "$1" | tr '\n' ' ')"; r="$(ran_set "$2" | tr '\n' ' ')"
  [ -n "$w" ] && [ "$w" = "$r" ] && return 0
  printf 'RAN SET %s: the full call ran [%s] but the code gates [%s]' "${1##*/}" "$r" "$w"; return 1
}

# The four run functions: <validator> [<cells>]; a mutant run names its one deciding cell.
cn_run() { rcpt_run "$WORK/rw-bl815" "$R815" "$1" ${2:+"$2"} 2>&1; } # <validator> [<cells>]: a mutant run names its one deciding cell
b9_run() { rcpt_run "$WORK/rw-bl809" "$R809" "$1" ${2:+"$2"} 2>&1; } # <validator> [<cells>]: a mutant run names its one deciding cell
SMW="$WORK/sm-worlds"
sm_run() { rcpt_run - "$R845" "$1" "$SMW" "${2:-}" 2>&1; } # <validator> [<cells>]: a mutant run names its one deciding cell (plus clean)
b43_run() { rcpt_run "$WORK/rw-bl843" "$R843" "$1" "${2:-}" 2>&1; } # <validator> [<cells>]: a mutant run names its one deciding cell (plus ctl)

# Sourced by story-evidence-receipts-mutants: hand it the control tree, the receipts, the run functions and the C3
# extractor, and run nothing further here.
if [ "${BASH_SOURCE[0]}" != "$0" ]; then return 0; fi

echo "story-evidence-receipts:"
# Self-probe, BEFORE the corpus: a seeded `if want zz; then`, `! want yy ||`, `&& want aa`, the pair
# `want bp || want bb`, and a call `h cc` of a seeded helper whose body calls `want "$1"` are found; a
# commented-out `# if want qq; then` and a commented-out helper call `# h dd` (shapes only the comment strip
# removes) and the word want in a FAIL message string not preceded by a gate prefix are not. The grammar is
# the contract's prefix match, not a string parser: a message string holding `|| want <cell>` would be extracted.
_wp="$WORK/want-cells-probe.sh"
printf '%s\n' 'if want zz; then ran zz; fi' '! want yy || { ran yy; [ -n x ] || echo "FAIL yy: we want ww here"; }' \
  '  # if want qq; then ran qq; fi' 'echo "FAIL ab: did not want vv"' 'true && want aa && ran aa' \
  'if want bp || want bb; then ran bp; ran bb; fi' 'h() { want "$1" || return 0; ran "$1"; }' 'h cc' '  # h dd' > "$_wp"
_wg="$(want_cells "$_wp" | tr '\n' ' ')"
if [ "$_wg" = "aa bb bp cc yy zz " ]; then ok "WANT-CELLS PROBE: the extractor finds a seeded if want zz, ! want yy, && want aa, the pair want bp || want bb and a call h cc of a helper gating on want \"\$1\", and ignores a commented-out if want qq, a commented-out h dd and want in a FAIL message string"
else bad "WANT-CELLS PROBE: want [aa bb bp cc yy zz ], got [$_wg] -- the C3 extractor cannot be trusted, every RAN SET arm below is void"; fi

cn_out="$(cn_run "$HECTL")"; cn_rc=$?
if [ "$cn_rc" -eq 0 ]; then ok "CAPTURE NORMALISATION: inner ../, absolute and aliased spellings of a tracked capture are judged (no-command), a leading ../ is outside the repository (WARN, or red-untracked when RED), untracked and outside citations WARN capture-unresolved with their reasons, a frozen-.gitignore'd one prints nothing, the exit is unchanged, --list-captures lists the toplevel spellings, and both readers agree on one ./ token"
else bad "CAPTURE NORMALISATION: receipt-bl815.sh exited $cn_rc on the shipped validator: $(tr '\n' ' ' <<<"$cn_out")"; fi
CN_GATED="$(want_cells "$R815")"
if c3_msg="$(c3_check "$R815" "$cn_out")"; then ok "RAN SET bl815: the full control call ran exactly the cells the receipt's code gates ($(tr '\n' ' ' <<<"$CN_GATED"))"
else bad "$c3_msg"; fi
b9_out="$(b9_run "$HECTL")"; b9_rc=$?
if [ "$b9_rc" -eq 0 ]; then ok "BL-809 ARMS: an unquoted multi-word -k is REFUSED k-unquoted, quoted and single-word -k are quiet, a <tree> placeholder WARNs without moving the exit, <redacted> and <base-worktree> are quiet"
else bad "BL-809 ARMS: receipt-bl809.sh exited $b9_rc on the shipped validator: $(tr '\n' ' ' <<<"$b9_out")"; fi
B9_GATED="$(want_cells "$R809")"
if c3_msg="$(c3_check "$R809" "$b9_out")"; then ok "RAN SET bl809: the full control call ran exactly the cells the receipt's code gates ($(tr '\n' ' ' <<<"$B9_GATED"))"
else bad "$c3_msg"; fi
sm_out="$(sm_run "$HECTL")"; sm_rc=$?
[ -f "$SMW/.seeded" ] || { sm_rc=9; sm_out="$sm_out (the worlds were not seeded once into $SMW)"; }
if [ "$sm_rc" -eq 0 ]; then ok "BL-845 SMOKE ARMS: an untracked listed test file is REFUSED smoke-listed-absent and a removed one is not; directory, trailing-slash and extensionless tokens are ignored by m1; /api, KEY=URL and glob tokens are not paths, :line and ::node suffixes are stripped; the s320 4.2 body over a UI diff is REFUSED smoke-not-updated, an empty body over a non-UI diff is quiet, and an :(exclude) or :! surface line removes a generated file from the surface; an absent surface prints SKIP undeclared and no SMOKE OK, none prints NO-SURFACE, an empty one SKIP empty, a capitalised None NO-SURFACE, a surface line git rejects and a surface matching nothing at base (none., a backticked none, a typo) REFUSED smoke-surface-unevaluable with exit 1 while a matching glob the range misses is quiet and a surface directory the story creates is not refused, a corrupt base tree under the surface is UNEVALUABLE (exit 2) and not a rejected pathspec, an unevaluable range diff with nothing refused exits 2, a refusal outranks a later unevaluable diff (exit 1, never 2) in both modes, an :(exclude,glob) line drops a top-level test file that :(exclude) keeps, and -C <subdirectory> refuses as -C <toplevel> does; an edited surface is REFUSED and read at base; fences, CRLF and the next heading bound the section; handoff mode runs the same arms"
else bad "BL-845 SMOKE ARMS: receipt-bl845.sh exited $sm_rc on the shipped validator: $(tr '\n' ' ' <<<"$sm_out")"; fi
SM_GATED="$(want_cells "$R845")"
if c3_msg="$(c3_check "$R845" "$sm_out")"; then ok "RAN SET bl845: the full control call ran exactly the $(grep -c . <<<"$SM_GATED") cells the receipt's code gates, through want and its cell and hand_rc helpers"
else bad "$c3_msg"; fi
b43_out="$(b43_run "$HECTL")"; b43_rc=$?
if [ "$b43_rc" -eq 0 ]; then ok "CAPTURE-HEADS: --render-dar renders each capture's head (+dirty kept, the replay block's own), its (a)-arm command (a backtick in a double-backtick span) and the full-collection capture's last count only; --check accepts the pasted block, refuses one retyped head stale, a missing block (post-epoch) and two blocks; a pre-epoch or undecidable story WARNs; the block's own paths are never citations; counts: capture-heads block is a run only with a fresh counted block"
else bad "CAPTURE-HEADS: receipt-bl843.sh exited $b43_rc on the shipped validator: $(tr '\n' ' ' <<<"$b43_out")"; fi
B43_GATED="$(want_cells "$R843")"
if c3_msg="$(c3_check "$R843" "$b43_out")"; then ok "RAN SET bl843: the full control call ran exactly the $(grep -c . <<<"$B43_GATED") cells the receipt's code gates"
else bad "$c3_msg"; fi

# INPROC: every subject call the receipts made through he-inproc.sh was answered in process. Positive conjunct: the
# log exists, so an unset variable cannot pass.
if [ -f "$UT_FALLBACK_LOG" ] && [ ! -s "$UT_FALLBACK_LOG" ]; then
  ok "INPROC: every validator, record-only-diff.sh and sprint-status.sh call the receipts made was answered in process"
else
  bad "INPROC: subject calls ran as processes: $(sort "$UT_FALLBACK_LOG" 2>/dev/null | uniq -c | tr '\n' ' ')"
fi
if [ "$rc" -eq 0 ]; then echo "PASS story-evidence-receipts"; else echo "FAIL story-evidence-receipts"; fi
exit "$rc"
