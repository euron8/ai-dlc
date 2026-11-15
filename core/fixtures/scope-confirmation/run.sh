#!/usr/bin/env bash
# scope-confirmation/run.sh — prove Check 34 can tell a sprint whose scope an operator
# actually saw from one that merely says so.
#
# THE DEFECT. Rule 3's pause points were all downstream of implementation, so a sprint
# that never reached implementation had structurally nowhere to ask. One ran seven days,
# produced zero lines of product code, planned three stories sharing not one identifier
# with the ask, passed four consecutive gates green, and filed all three of its blocking
# questions on day 7 — while breaking no rule at all. Rule 3(d) adds the seam. This check
# is what makes it a requirement rather than a suggestion.
#
# THE ASSERTIONS THAT MATTER MOST are 2 and 5. Both are places where the honest-looking
# reading fails OPEN:
#   2. "no scope_confirmed field" must NOT be read as "this consumer predates the
#      release". That reading is indistinguishable from a lead skipping the pause point,
#      and it excuses precisely the conduct the check exists to catch.
#   5. `scope_confirmed_cite: none` must not pass while the capture file holds entries.
#      Otherwise the cheapest way past the check is to write `none`.
set -uo pipefail

# The deferred-items arms below build scratch git repositories. Git exports GIT_DIR to a
# hook run from a linked worktree, and an inherited one turns `git init` into a silent
# no-op that redirects every later commit onto the caller's index.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR

# The pre-push gate inherits every AI_DLC_* tunable a consumer set in settings.json. A
# fixture that drives a validator while inheriting them tests the CONFIG, not the code.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }

sha_of() { printf '%s' "$1" | { shasum -a 256 2>/dev/null || sha256sum; } | cut -d' ' -f1; }

# Run a validator against a snapshot/answers pair. Echoes the exit code; stashes output.
LAST_OUT=""
rc_of() {
  LAST_OUT="$(bash "$1" --snapshot "$2" --answers "$3" 2>&1)"
  printf '%s' "$?"
}

echo "scope-confirmation:"
printf 'HERMETIC-CONSUMED %s\n' "$VALIDATOR"
printf 'HERMETIC-CONSUMED %s\n' "$HOOK"
[ -f "$(dirname "$HOOK")/ai-dlc-context-provenance.sh" ] && printf 'HERMETIC-CONSUMED %s\n' "$(dirname "$HOOK")/ai-dlc-context-provenance.sh"
_PRS=""; for _c in "$HERE/../../schemas/pause-routing.json" "$HERE/../../../.claude/schemas/pause-routing.json"; do [ -f "$_c" ] && { _PRS="$(cd "$(dirname "$_c")" && pwd -P)/pause-routing.json"; break; }; done
[ -n "$_PRS" ] && printf 'HERMETIC-CONSUMED %s\n' "$_PRS"

if [ -z "${SHA:-}" ]; then
  bad "SEED BROKEN: the capture hook recorded no SHA256, so every assertion below would be comparing against an empty string"
  echo; echo "scope-confirmation: $fails assertion(s) FAILED" >&2; exit 1
fi

# --- Assertion 1: a well-formed confirmation passes ---------------------------
r=$(rc_of "$VALIDATOR" "$WORK/snap-good.md" "$ANSWERS")
if [ "$r" = "0" ]; then
  ok "a routing record whose cite resolves to a hook-written answer passes"
else
  bad "the healthy case did not pass (rc=$r) — a check that cannot go green wedges every sprint: $LAST_OUT"
fi

# --- Assertion 2: a MISSING field fails, it does not excuse itself as legacy ---
r=$(rc_of "$VALIDATOR" "$WORK/snap-nofield.md" "$ANSWERS")
if [ "$r" = "1" ]; then
  ok "a missing scope_confirmed FAILS when the capture hook is installed — it is a skipped pause point, not a legacy consumer"
else
  bad "a missing scope_confirmed returned rc=$r instead of 1 — the check reads a skipped pause point as a consumer that predates the release, which is the fail-open direction and excuses the exact conduct it exists to catch"
fi

# --- Assertion 3: there is no third value -------------------------------------
r=$(rc_of "$VALIDATOR" "$WORK/snap-badvalue.md" "$ANSWERS")
if [ "$r" = "1" ]; then
  ok "scope_confirmed: n-a is rejected — the pause point is unconditional, so 'not applicable' is a claim it did not happen"
else
  bad "scope_confirmed: n-a returned rc=$r instead of 1 — an n-a escape makes the mandate optional in one word"
fi

# --- Assertion 4: the boolean alone is not enough ------------------------------
r=$(rc_of "$VALIDATOR" "$WORK/snap-nocite.md" "$ANSWERS")
if [ "$r" = "1" ]; then
  ok "scope_confirmed without a cite FAILS — the field alone is the lead's account of its own conversation"
else
  bad "an uncited scope_confirmed returned rc=$r instead of 1 — the self-declaration hole is open"
fi

# --- Assertion 5: `none` cannot paper over a capture file that has entries -----
r=$(rc_of "$VALIDATOR" "$WORK/snap-citenone.md" "$ANSWERS")
if [ "$r" = "1" ]; then
  ok "cite 'none' FAILS while the capture file holds entries — 'none' is not a way past the check"
else
  bad "cite 'none' returned rc=$r against a NON-empty capture file — the cheapest route past this check is now to write 'none', and every fabrication takes it"
fi

# --- Assertion 6: ...but `none` is honest against an empty capture file --------
r=$(rc_of "$VALIDATOR" "$WORK/snap-citenone.md" "$ANSWERS_EMPTY")
if [ "$r" = "0" ]; then
  ok "cite 'none' PASSES against an empty capture file — a dismissed prompt reported honestly is not a failure"
else
  bad "cite 'none' against an empty capture file returned rc=$r instead of 0 — an operator who dismissed the prompt now wedges the gate, and the remedy is to fabricate a hash"
fi

# --- Assertion 7: a fabricated hash resolves to nothing and is caught ----------
r=$(rc_of "$VALIDATOR" "$WORK/snap-fabricated.md" "$ANSWERS")
if [ "$r" = "1" ]; then
  ok "a well-formed hash that resolves to no entry FAILS — the cite must resolve, not merely look like a hash"
else
  bad "a fabricated hash returned rc=$r instead of 1 — the cite is decorative and the check is a spell-checker for hex"
fi

# --- Assertion 8: a snapshot with no routing record is PENDING, not FAIL -------
r=$(rc_of "$VALIDATOR" "$WORK/snap-premigration.md" "$ANSWERS")
if [ "$r" = "3" ]; then
  ok "a snapshot carrying no routing record reports PENDING — it predates the record, and blaming it would wedge an in-flight sprint"
else
  bad "a pre-migration snapshot returned rc=$r instead of 3 — this is the fourth unreachable hard block the plan warns about"
fi

# --- Assertion 9: no capture hook is PENDING, not FAIL -------------------------
r=$(rc_of "$VALIDATOR" "$WORK/snap-good.md" "$WORK/no-such-answers.md")
if [ "$r" = "3" ]; then
  ok "a consumer with no capture file reports PENDING — nothing could have recorded the answer, so a FAIL would blame the lead for a missing hook"
else
  bad "an absent capture file returned rc=$r instead of 3 — a consumer mid-upgrade is failed for the installer's state"
fi

# --- Assertion 10: an absent snapshot is a FAIL, never a clean pass ------------
r=$(rc_of "$VALIDATOR" "$WORK/no-such-snapshot.md" "$ANSWERS")
if [ "$r" = "2" ]; then
  ok "an absent snapshot exits 2 — a verdict computed against a file that is not there is a verdict about nothing"
else
  bad "an absent snapshot returned rc=$r instead of 2 — an unreadable input renders as no problem"
fi

# --- Assertion 11: the zero-control prints on EVERY path ----------------------
# A regex that matched nothing must not print the same clean line as full coverage.
missing=""
for pair in "snap-good.md:$ANSWERS" "snap-nofield.md:$ANSWERS" "snap-citenone.md:$ANSWERS_EMPTY" \
            "snap-premigration.md:$ANSWERS" "snap-good.md:$WORK/no-such-answers.md"; do
  s="${pair%%:*}"; a="${pair#*:}"
  rc_of "$VALIDATOR" "$WORK/$s" "$a" >/dev/null
  grep -q 'answers_entries_scanned:' <<<"$LAST_OUT" || missing="$missing $s"
done
if [ -z "$missing" ]; then
  ok "answers_entries_scanned: prints on every path — PASS, FAIL and PENDING alike"
else
  bad "answers_entries_scanned: is missing on:$missing — a run that scanned an empty capture file reads exactly like one that scanned forty healthy entries"
fi

# --- Assertion 12: the recorded SHA resolves to the ANSWER bytes ---------------
# This is what makes the cite a citation grade rather than a checksum. Recomputed here
# independently of the hook.
if [ "$SHA" = "$(sha_of "$ANSWER")" ]; then
  ok "the hook's recorded SHA256 is the hash of the operator's answer, recomputed independently"
else
  bad "the recorded SHA256 does not match a hash of the answer it labels — every cite built on it resolves to nothing"
fi

# --- Assertion 13: the hash covers the ANSWER ONLY ----------------------------
# The question is text the LEAD authored. A hash spanning it would let a lead cite words
# it wrote itself and pass a provenance check by talking to itself — the S290
# fabrication, reintroduced through the fix for its mirror image.
Q='Is this the scope you asked for?'
if [ "$SHA" != "$(sha_of "$Q")" ] && [ "$SHA" != "$(sha_of "$Q$ANSWER")" ] \
   && ! grep -q "^- SHA256: $(sha_of "$Q")\$" "$ANSWERS"; then
  ok "the hash covers the answer alone — neither the lead-authored question nor question+answer hashes to it"
else
  bad "the recorded hash spans the lead-authored question — a lead can now cite its own words as operator provenance"
fi

# --- Assertion 17: the grammar the real consumer writes ------------------------
# The first version of this check parsed only the line-anchored `- field: value` form
# that the synthetic snapshots above use, and reported "no routing record" against the
# reference consumer's live snapshot, which writes the fields inline and backticked in a
# prose bullet. That is the fail-OPEN direction — PENDING instead of a verdict — and no
# assertion written against this fixture's own synthetic grammar could have caught it.
r=$(rc_of "$VALIDATOR" "$WORK/snap-inline.md" "$ANSWERS")
if [ "$r" = "0" ]; then
  ok "the inline backticked grammar the reference consumer actually writes is parsed, cite and value both"
else
  bad "the consumer's real inline grammar returned rc=$r instead of 0 — the check is anchored to a grammar only this fixture uses, and reads every real snapshot as having no routing record: $LAST_OUT"
fi

# =============================================================================
# THE PRODUCER'S GRAMMAR (assertions 19-26).
# =============================================================================
# WHY THESE EXIST. Assertions 1-18 seed exactly the two grammars `field_of` was written to
# accept -- re-derived here rather than taken on trust: 0 bold-form `scope_confirmed` lines
# in seed.sh against a control of 5 total mentions, 0 in run.sh against a control of 9. A
# reader proved against its own accept-set is proved against nothing, and this one was
# misparsing SIX further forms while every arm above stayed green.
#
# WHAT THE SIX ARE, driven over the PRE-FIX function in one invocation rather than restated
# from the filing, which named two:
#     - **scope_confirmed:** confirmed              -> `**`           (malformed-value FAIL)
#     - **scope_confirmed**: confirmed              -> empty          (ACCUSATION)
#     - scope_confirmed: `confirmed`                -> empty          (ACCUSATION)
#     - **scope_confirmed: confirmed**              -> `confirmed**`  (malformed-value FAIL)
#     - __scope_confirmed__: confirmed              -> empty          (ACCUSATION)
#     - **scope_confirmed:** confirmed — prose      -> `**`           (malformed-value FAIL)
# The accusation is the harsher half: a well-formed snapshot carrying a correct value is
# reported as evidence the lead skipped a MANDATORY operator pause point.
#
# EVERY ARM BELOW DRIVES THE SHIPPING VALIDATOR END TO END, not a lifted copy of the
# function. A lift is a second implementation whose bugs nobody finds, and the harm this
# defect does is an exit code and a message reaching an operator -- so that is what is read.

# Assert on the message as well as the code. rc alone cannot separate the pre-fix from the
# fix on a malformed value: both exit 1.
#
# `rc_of` CANNOT BE USED FOR A MESSAGE ARM AND THAT IS NOT OBVIOUS. It is called as
# `r=$(rc_of ...)`, so it runs in a SUBSHELL and the `LAST_OUT` it sets is discarded; the
# variable the caller then reads still holds whatever the last non-substituted call left
# there. Measured while writing these arms: seven of them read the PENDING text from
# assertion 11's final loop iteration and reported a failure the validator had not
# produced — a stale instrument, reading exactly like a real finding. `run_v` sets both
# the code and the output in the CURRENT shell.
LAST_RC=0
run_v() { LAST_OUT="$(bash "$1" --snapshot "$2" --answers "$3" 2>&1)"; LAST_RC=$?; }
out_has() { grep -qF "$1" <<<"$LAST_OUT"; }

# --- Assertion 19: the producer's dominant form -------------------------------
run_v "$VALIDATOR" "$WORK/snap-prod-bold.md" "$ANSWERS"; r=$LAST_RC
if [ "$r" = "0" ] && out_has "scope_confirmed: confirmed"; then
  ok "the producer's own grammar passes — bold name, colon inside the span, prose after the value, and a bold+backticked cite that resolves"
else
  bad "the producer's dominant grammar returned rc=$r — this is the form the reference consumer writes on every routing-record field, so the check now reports a malformed value on a well-formed snapshot: $LAST_OUT"
fi

# --- Assertion 20: colon OUTSIDE the span, and the value is `corrected` --------
# THE VALUE-FIDELITY ARM. Its expected value is `corrected`, so it cannot pass against a
# parser that answers `confirmed` unconditionally — which is the hole in BL-065's own
# receipt.
run_v "$VALIDATOR" "$WORK/snap-prod-boldout.md" "$ANSWERS"; r=$LAST_RC
if [ "$r" = "0" ] && out_has "scope_confirmed: corrected"; then
  ok "colon-outside bold passes and reports 'corrected' — the value is read, not assumed, and the cite written before it is not mistaken for it"
else
  bad "colon-outside bold returned rc=$r without reporting 'corrected' — the pre-fix returned EMPTY here and accused the lead of a Rule 3(d) pause point that did not happen: $LAST_OUT"
fi

# --- Assertion 21: a BACKTICKED value -----------------------------------------
run_v "$VALIDATOR" "$WORK/snap-prod-btval.md" "$ANSWERS"; r=$LAST_RC
if [ "$r" = "0" ] && out_has "scope_confirmed: confirmed"; then
  ok "a backticked value parses — the value class no longer excludes the character the producer wraps hashes and enums in"
else
  bad "a backticked value returned rc=$r — the pre-fix value class excluded a backtick, so this returned empty and became the same accusation: $LAST_OUT"
fi

# --- Assertion 22: `__underscore bold__` --------------------------------------
run_v "$VALIDATOR" "$WORK/snap-prod-uscore.md" "$ANSWERS"; r=$LAST_RC
if [ "$r" = "0" ] && out_has "scope_confirmed: confirmed"; then
  ok "doubled-underscore emphasis parses — the doubled form CAN be normalized even though the single one cannot, and the validator names that boundary"
else
  bad "__scope_confirmed__ returned rc=$r — a second established bold spelling reads as a skipped pause point: $LAST_OUT"
fi

# --- Assertion 23: a bold span wrapping the whole pair ------------------------
run_v "$VALIDATOR" "$WORK/snap-prod-boldpair.md" "$ANSWERS"; r=$LAST_RC
if [ "$r" = "0" ] && out_has "scope_confirmed: confirmed"; then
  ok "a bold span wrapping name and value together parses — the pre-fix read the value as 'confirmed**' and called it malformed"
else
  bad "a whole-pair bold span returned rc=$r: $LAST_OUT"
fi

# --- Assertion 24: THE NEGATIVE ARM -------------------------------------------
# A bold routing record with NO scope_confirmed must still be the accusation. Without this,
# every arm above passes against `field_of() { echo confirmed; }` — and the rc is NOT the
# discriminator, because that stub also exits 1 here (the cite comes back 'confirmed', which
# is not hex and not 'none'). The MESSAGE is what separates a missing field from a broken
# parser, so the message is what this reads.
run_v "$VALIDATOR" "$WORK/snap-prod-nofield.md" "$ANSWERS"; r=$LAST_RC
if [ "$r" = "1" ] && out_has "carries no 'scope_confirmed' field"; then
  ok "a bold routing record with no scope_confirmed FAILS with the missing-field accusation — normalizing wrappers does not manufacture a field that is not there"
else
  bad "a bold record missing scope_confirmed returned rc=$r without the missing-field accusation — either the normalizer invented a value or the FAIL is arriving for the wrong reason, and both read identically from the exit code: $LAST_OUT"
fi

# --- Assertion 25: a malformed value is reported AS ITSELF --------------------
# Pre-fix and fixed both exit 1 on this snapshot. The pre-fix says the value is '**'; the
# fix says it is 'n-a'. An arm reading only the exit code cannot tell a check that read the
# field from one that read the markdown around it.
run_v "$VALIDATOR" "$WORK/snap-prod-badvalue.md" "$ANSWERS"; r=$LAST_RC
if [ "$r" = "1" ] && out_has "scope_confirmed is 'n-a'" && ! out_has "scope_confirmed is '**'"; then
  ok "a bold field carrying a value outside the closed set is reported as 'n-a', not as '**' — the operator is told what the record actually says"
else
  bad "a bold out-of-set value returned rc=$r and did not name 'n-a' — reporting the markup as the value sends an operator to look for a field that reads correctly: $LAST_OUT"
fi

# --- Assertion 26: both install layouts were NAMED, and one resolved ----------
# I33: install.sh lands core/scripts/<x> at scripts/ai-dlc/<x>. seed.sh names both
# candidates and resolves by walking UP for the hook itself rather than counting `..` hops —
# the hop count is 3 in both layouts today by coincidence, and a coincidence resolves
# nothing the moment either tree moves a level.
if [ -n "${CAND_DIST:-}" ] && [ -n "${CAND_CONS:-}" ] && [ "$VALIDATOR" = "$CAND_DIST" -o "$VALIDATOR" = "$CAND_CONS" ]; then
  ok "both layout candidates named and one resolved: $VALIDATOR"
else
  bad "the resolved validator '$VALIDATOR' is neither named candidate ('${CAND_DIST:-}' | '${CAND_CONS:-}') — a fixture that resolves somewhere it did not name is asserting against a file nobody chose"
fi

# =============================================================================
# ASSERTIONS 33-36: CORPUS IDENTITY.
# =============================================================================
# THE DEFECT. Both inputs are caller-supplied (`--snapshot`, `--answers`) and default to
# paths under a root this script resolves for itself, so a run pointed at the wrong tree
# is a real state. Before the identity lines, `answers_entries_scanned: 3` plus
# `PASS  scope_confirmed: confirmed` was the WHOLE of a passing run's output — no path
# anywhere — so two runs over two different trees holding identical bytes were
# BYTE-IDENTICAL. Nothing on screen separated a verdict about this sprint from a verdict
# about a copy of it.
#
# THE ARM IS KEYED ON DISCRIMINATION, NOT ON A SPELLING. The pair is driven twice over two
# mktemp corpora seeded with the same bytes; the outputs must DIFFER **and** each must
# carry ITS OWN two paths. Those are separate requirements and the second is the load-
# bearing one: a nonce, a PID or a timestamp makes two runs differ while naming nothing,
# and that is the fix a differ-only check would accept. No label text is grepped, so re-wording
# `snapshot:` leaves this working; what is demanded is the resolved path, and the roots
# are mktemp names, so no implementation can hardcode the literal.
#
# THE ARM IS PRESENCE-SHAPED. It requires two specific paths to APPEAR in a run that
# reached the PASS emitter, so a validator replaced by `exit 0` fails it by construction.
SC_IDENT_WHY=""
sc_ident_corpus() {   # -> prints a fresh corpus root holding a copy of the healthy pair
  local d
  d="$(mktemp -d "$WORK/ident.XXXXXX")" || return 1
  cp "$WORK/snap-good.md" "$d/snapshot.md" || return 1
  cp "$ANSWERS"           "$d/answers.md"  || return 1
  printf '%s\n' "$d"
}
# sc_ident_holds <validator> — 0 iff the run reached PASS, the two runs are
# distinguishable, and each names the snapshot and the answers file it actually read.
sc_ident_holds() {
  local v="$1" a b oa ob ra rb
  SC_IDENT_WHY=""
  a="$(sc_ident_corpus)" || { SC_IDENT_WHY="could not build corpus A"; return 1; }
  b="$(sc_ident_corpus)" || { SC_IDENT_WHY="could not build corpus B"; return 1; }
  oa="$(bash "$v" --snapshot "$a/snapshot.md" --answers "$a/answers.md" 2>&1)"; ra=$?
  ob="$(bash "$v" --snapshot "$b/snapshot.md" --answers "$b/answers.md" 2>&1)"; rb=$?
  if [ "$ra" != "0" ] || [ "$rb" != "0" ]; then
    SC_IDENT_WHY="rc=$ra/$rb, expected 0/0 — the run never reached the PASS emitter"; return 1
  fi
  if ! grep -qF 'PASS  scope_confirmed:' <<<"$oa"; then
    SC_IDENT_WHY="no PASS line — this arm did not reach the emitter it claims to guard"; return 1
  fi
  if [ "$oa" = "$ob" ]; then
    SC_IDENT_WHY="two different trees holding identical bytes produced byte-identical output"
    return 1
  fi
  if ! grep -qF "$a/snapshot.md" <<<"$oa" || ! grep -qF "$a/answers.md" <<<"$oa"; then
    SC_IDENT_WHY="run A names neither the snapshot it read nor the capture file it counted"
    return 1
  fi
  if ! grep -qF "$b/snapshot.md" <<<"$ob" || ! grep -qF "$b/answers.md" <<<"$ob"; then
    SC_IDENT_WHY="run B names neither the snapshot it read nor the capture file it counted"
    return 1
  fi
  if grep -qF "$b" <<<"$oa"; then
    SC_IDENT_WHY="run A's output carries run B's root — the paths are not the ones it resolved"
    return 1
  fi
  return 0
}

# --- Assertion 33: the passing run names both corpora --------------------------
if sc_ident_holds "$VALIDATOR"; then
  ok "a passing run names the snapshot it read and the capture file it counted, and two identical corpora in different trees are distinguishable"
else
  bad "a passing run carries no corpus identity — $SC_IDENT_WHY. Two sprints' worth of identical content produce one verdict, and the operator cannot tell which tree it is about"
fi

# --- Assertion 34: the DEFAULT-RESOLVED paths are named, not the arguments -----
# THE ATTACK THIS CLOSES. Assertion 33 drives both corpora through `--snapshot`/`--answers`,
# so a "fix" that echoed the argument vector — `echo "$@"` on the way out — satisfies it
# while proving nothing about what the script RESOLVED. The interesting case is the one
# with no arguments at all: both inputs default to paths under a root this script walks up
# for, and that root is exactly where a run can silently be about the wrong tree. Nothing
# is passed here, so an argument echo names nothing and this arm fires.
SC_D="$(mktemp -d "$WORK/dflt.XXXXXX")"
mkdir -p "$SC_D/_bmad-output"
cp "$WORK/snap-good.md" "$SC_D/_bmad-output/pipeline-snapshot.md"
cp "$ANSWERS"           "$SC_D/_bmad-output/operator-answers-history.md"
SC_DOUT="$(AI_DLC_PROJECT_ROOT="$SC_D" bash "$VALIDATOR" 2>&1)"; SC_DRC=$?
if [ "$SC_DRC" = "0" ] \
   && grep -qF "$SC_D/_bmad-output/pipeline-snapshot.md" <<<"$SC_DOUT" \
   && grep -qF "$SC_D/_bmad-output/operator-answers-history.md" <<<"$SC_DOUT"; then
  ok "a run with NO path arguments names the two files it resolved for itself — the identity is the resolved value, not an echo of argv"
else
  bad "a defaulted run (rc=$SC_DRC) did not name the snapshot and capture file it resolved — the identity lines could be satisfied by echoing the argument vector, which says nothing about a run that was given no arguments: $SC_DOUT"
fi

# =============================================================================
# ASSERTIONS 38-: scope_deferred_items -- the part of the ask Step 6 deferred is a
# FILED carry-over item, and an absent field is legacy only by a date no agent writes.
# =============================================================================
# THE DEFECT. A sprint's scope confirmation ratified a phase split, and the deferred phase
# was recorded only in the lead-authored question -- no hash covers it and no later step
# reads it. The arm resolves every listed id to a not-CLOSED `### <id>` item in the live
# carry-over backlog or its archive, and decides an ABSENT field by comparing the hook's
# answer timestamp against the commit that first stamped the introducing release.
#
# THE BACKLOG IS SEEDED IN THE CONSUMER'S OWN SHAPES, not the reader's accept-set: both
# status spellings the reference consumer writes (`**Status:** X` 37 times and
# `**Status: X` 52 times in its live backlog), an item whose CURRENT status sits above a
# superseded one, a heading carrying trailing prose, and headings that are a string
# PREFIX of another id.
SD="$WORK/sdi"; mkdir -p "$SD/pa"
cat > "$SD/pa/carry-over-backlog.md" <<'BL'
# Carry-over Backlog

## Open items

### CO-S315-PHASE-2-BACKFILL — the historical backfill phase the operator deferred [P2]
**Status:** OPEN
Filed at route.md Step 6.

### CO-S315-PHASE-3-CUTOVER
**Status: OPEN.** The second status spelling the consumer writes.

### CO-S312-IN-SPRINT-ITEM
**Status:** IN SPRINT (S315, carry-over-evaluation)

### CO-S310-DEFERRAL-ITEM
**Status:** DEFERRAL_REQUESTED

### CO-S309-CLOSED-ITEM
**Status:** CLOSED - delivered in sprint 314 via story-S314-2

### CO-S308-REOPENED-ITEM
**Status:** OPEN — reopened at S315 triage
**Status:** CLOSED (superseded, retained for history)

### CO-S315-bad_id
**Status:** OPEN

### CO-S315-PARTIAL-X
**Status:** OPEN

### CO-S307-NO-STATUS-ITEM
A body with no status line at all.
BL
cat > "$SD/pa/carry-over-backlog-archive.md" <<'AR'
# Carry-over Backlog Archive

### CO-S290-ARCHIVED-OPEN
**Status:** DEFERRAL_REQUESTED

### CO-S290-ARCHIVED-CLOSED
**Status: CLOSED - delivered in sprint 291.**
AR
SD_BL="$SD/pa/carry-over-backlog.md"

# One routing record per value. `-` omits the field entirely (the ABSENT case).
sd_snap() {   # $1 name, $2 value or '-', $3 cite (default $SHA)
  local f="$SD/snap-$1.md"
  {
    echo "# Pipeline Snapshot"; echo; echo "## Pipeline Position"
    echo "- user_request_verbatim: Sprint 315: TELv3 upgrade, phased."
    echo "- scope_confirmed: confirmed"
    echo "- scope_confirmed_cite: ${3:-$SHA}"
    [ "$2" = "-" ] || printf -- '- scope_deferred_items: %s\n' "$2"
  } > "$f"
}
sd_snap none      "none"
sd_snap one       "[CO-S315-PHASE-2-BACKFILL]"
sd_snap spell2    "[CO-S315-PHASE-3-CUTOVER]"
sd_snap two       "[CO-S315-PHASE-2-BACKFILL, CO-S315-PHASE-3-CUTOVER]"
sd_snap second    "[CO-S315-PHASE-2-BACKFILL, CO-S315-NEVER-FILED]"
sd_snap malformed "[CO-S315-bad_id]"
sd_snap closed    "[CO-S309-CLOSED-ITEM]"
sd_snap live      "[CO-S312-IN-SPRINT-ITEM, CO-S310-DEFERRAL-ITEM]"
sd_snap reopened  "[CO-S308-REOPENED-ITEM]"
sd_snap archived  "[CO-S290-ARCHIVED-OPEN]"
sd_snap archclosed "[CO-S290-ARCHIVED-CLOSED]"
sd_snap prefix    "[CO-S315-PARTIAL]"
sd_snap nostatus  "[CO-S307-NO-STATUS-ITEM]"
sd_snap emptylist "[]"
sd_snap unclosed  "[CO-S315-PHASE-2-BACKFILL,"
sd_snap absent    "-"
sd_snap absentnone "-" none
# The producer's bold grammar, a backticked list, and a block list (refused, never empty).
{ echo "# Pipeline Snapshot"; echo "## Pipeline Position"
  echo "- **user_request_verbatim:** Sprint 315."
  echo "- **scope_confirmed:** confirmed — the operator took the phased split."
  echo "- **scope_confirmed_cite:** \`$SHA\`"
  echo "- **scope_deferred_items:** \`[CO-S315-PHASE-2-BACKFILL, CO-S315-PHASE-3-CUTOVER]\` — both filed at Step 6."
} > "$SD/snap-bold.md"
{ echo "# Pipeline Snapshot"; echo "## Pipeline Position"
  echo "- user_request_verbatim: Sprint 315."
  echo "- scope_confirmed: confirmed"
  echo "- scope_confirmed_cite: $SHA"
  echo "- scope_deferred_items:"
  echo "  - CO-S315-PHASE-2-BACKFILL"
} > "$SD/snap-block.md"

# --- the dated worlds: answers and repositories -------------------------------
# The answer heading is the hook's; only its timestamp is varied, and the entry the cite
# resolves to is otherwise the hook's own bytes.
sd_answers() {   # $1 name, $2 ISO-Z timestamp
  sed "s/^## [0-9][0-9T:Z-]* -- AskUserQuestion/## $2 -- AskUserQuestion/" "$ANSWERS" > "$SD/answers-$1.md"
}
sd_answers early   2026-09-26T07:29:05Z
sd_answers late    2026-09-29T00:00:00Z
sd_answers tzgap   2026-09-28T17:00:00Z
sd_answers between 2026-10-02T00:00:00Z
# The hash covers the answer body alone, so a short answer recurs. The reference consumer's
# live cite resolves to three entries whose body is `Confirmed`. Here the same entry appears
# twice: first before the release stamp, then after it. The NEWEST entry dates the answer.
{ cat "$SD/answers-early.md"; echo; sed -n '/^## /,$p' "$SD/answers-late.md"; } > "$SD/answers-dup.md"

# sd_repo <name> <version@committer-date> ... -- one commit per stamp, oldest first.
sd_repo() {
  local d="$SD/repo-$1" s v t; shift
  mkdir -p "$d/.claude"
  git -C "$d" init -q 2>/dev/null || return 1
  for s in "$@"; do
    v="${s%%@*}"; t="${s#*@}"
    printf 'version: %s\ncommit: 0000000\ninstalled_at: 2026-06-13T13:56:26Z\n' "$v" > "$d/.claude/.ai-dlc-version"
    git -C "$d" add .claude/.ai-dlc-version
    GIT_AUTHOR_DATE="$t" GIT_COMMITTER_DATE="$t" \
      git -C "$d" -c user.name=f -c user.email=f@f -c commit.gpgsign=false commit -q -m "stamp $v" || return 1
  done
}
# The release lands at 15:54:22-04:00 = 19:54:22Z, spelled with an explicit offset.
sd_repo std  "0.658.0@2026-09-20T10:00:00-04:00" "0.659.0@2026-09-28T15:54:22-04:00"
sd_repo old  "0.657.0@2026-09-10T10:00:00Z" "0.658.0@2026-09-20T10:00:00Z"
# 0.7.0 is OLDER than 0.659.0 and string-compares as NEWER.
sd_repo lex  "0.7.0@2026-01-05T10:00:00Z" "0.658.0@2026-09-20T10:00:00Z" "0.659.0@2026-09-28T19:54:22Z"
# Two qualifying stamps: the FIRST one decides.
sd_repo two  "0.659.0@2026-09-28T19:54:22Z" "0.660.0@2026-10-05T10:00:00Z"
mkdir -p "$SD/nogit"

SD_REPO_OK=1
for r in std old lex two; do
  n="$(git -C "$SD/repo-$r" rev-list --count HEAD 2>/dev/null)" || n=0
  [ "${n:-0}" -ge 2 ] || SD_REPO_OK=0
done
if [ "$SD_REPO_OK" = "1" ] && ! git -C "$SD/nogit" rev-parse --git-dir >/dev/null 2>&1; then
  ok "SEED: four dated repositories built with their commits, and the no-git directory is not inside one"
else
  bad "SEED BROKEN: a dated repository has fewer than two commits, or the no-git directory resolves to a repository — every legacy verdict below would be about the wrong history"
fi

SD_OUT=""; SD_RC=0
sd_run() {   # $1 validator, $2 snapshot name, $3 answers path, $4 repo path, [$5 TZ]
  SD_OUT="$(TZ="${5:-UTC}" bash "$1" --snapshot "$SD/snap-$2.md" --answers "$3" \
            --backlog "$SD_BL" --repo "$4" 2>&1)"; SD_RC=$?
}
sd_has() { grep -qF -- "$1" <<<"$SD_OUT"; }
REPO_STD="$SD/repo-std"

# sd_verdicts <validator> -> one token per arm, in a fixed order. Every arm below reads its
# own position.
SD_CELLS="none one spell2 two second malformed closed live reopened archived archclosed prefix nostatus emptylist unclosed bold block absent-early absent-late nogit nostamp tzgap lex first absentnone duphash"
sd_verdicts() {
  local v="$1" out=""
  sd_cell() { out="$out $1=$SD_RC"; }
  sd_run "$v" none "$ANSWERS" "$REPO_STD"
  sd_has "scope_deferred_items: none" || SD_RC="${SD_RC}x"; sd_cell none
  sd_run "$v" one "$ANSWERS" "$REPO_STD"
  sd_has "deferred_items_checked: 1" || SD_RC="${SD_RC}x"; sd_cell one
  sd_run "$v" spell2 "$ANSWERS" "$REPO_STD"; sd_cell spell2
  sd_run "$v" two "$ANSWERS" "$REPO_STD"
  sd_has "deferred_items_checked: 2" || SD_RC="${SD_RC}x"; sd_cell two
  sd_run "$v" second "$ANSWERS" "$REPO_STD"
  sd_has "CO-S315-NEVER-FILED" || SD_RC="${SD_RC}x"; sd_cell second
  sd_run "$v" malformed "$ANSWERS" "$REPO_STD"
  sd_has "malformed" || SD_RC="${SD_RC}x"; sd_cell malformed
  sd_run "$v" closed "$ANSWERS" "$REPO_STD"; sd_cell closed
  sd_run "$v" live "$ANSWERS" "$REPO_STD"; sd_cell live
  sd_run "$v" reopened "$ANSWERS" "$REPO_STD"; sd_cell reopened
  sd_run "$v" archived "$ANSWERS" "$REPO_STD"; sd_cell archived
  sd_run "$v" archclosed "$ANSWERS" "$REPO_STD"; sd_cell archclosed
  sd_run "$v" prefix "$ANSWERS" "$REPO_STD"; sd_cell prefix
  sd_run "$v" nostatus "$ANSWERS" "$REPO_STD"; sd_cell nostatus
  sd_run "$v" emptylist "$ANSWERS" "$REPO_STD"; sd_cell emptylist
  sd_run "$v" unclosed "$ANSWERS" "$REPO_STD"; sd_cell unclosed
  sd_run "$v" bold "$ANSWERS" "$REPO_STD"
  sd_has "deferred_items_checked: 2" || SD_RC="${SD_RC}x"; sd_cell bold
  sd_run "$v" block "$ANSWERS" "$REPO_STD"; sd_cell block
  sd_run "$v" absent "$SD/answers-early.md" "$REPO_STD"; sd_cell absent-early
  sd_run "$v" absent "$SD/answers-late.md" "$REPO_STD"
  sd_has "no 'scope_deferred_items' field" || SD_RC="${SD_RC}x"; sd_cell absent-late
  sd_run "$v" absent "$SD/answers-late.md" "$SD/nogit"; sd_cell nogit
  sd_run "$v" absent "$SD/answers-late.md" "$SD/repo-old"; sd_cell nostamp
  sd_run "$v" absent "$SD/answers-tzgap.md" "$REPO_STD" America/New_York; sd_cell tzgap
  sd_run "$v" absent "$SD/answers-early.md" "$SD/repo-lex"; sd_cell lex
  sd_run "$v" absent "$SD/answers-between.md" "$SD/repo-two"; sd_cell first
  sd_run "$v" absentnone "$ANSWERS_EMPTY" "$REPO_STD"; sd_cell absentnone
  sd_run "$v" absent "$SD/answers-dup.md" "$REPO_STD"; sd_cell duphash
  printf '%s\n' "${out# }"
}
# The expected vector. An `x` suffix means the rc was right but the owning message was not.
SD_EXPECT="none=0 one=0 spell2=0 two=0 second=1 malformed=1 closed=1 live=0 reopened=0 archived=0 archclosed=1 prefix=1 nostatus=1 emptylist=1 unclosed=1 bold=0 block=1 absent-early=3 absent-late=1 nogit=3 nostamp=3 tzgap=3 lex=3 first=1 absentnone=3 duphash=1"
sd_cell_of() { tr ' ' '\n' <<<"$1" | awk -F= -v k="$2" '$1==k{print $2}'; }

sd_why() {
  case "$1" in
    none)        echo "'none' is the honest empty value; refusing it wedges every sprint that deferred nothing" ;;
    one|spell2)  echo "a filed OPEN item must resolve in either status spelling the consumer writes" ;;
    two|bold)    echo "every id of a multi-id list must be read, in the plain and the producer's bold+backticked grammar" ;;
    second)      echo "a SECOND id that was never filed passed — the extractor reads only the first token" ;;
    malformed)   echo "a token outside CO-S<N>-<DESCRIPTOR> passed because a heading happened to carry it" ;;
    closed|archclosed) echo "a CLOSED item cannot be the part of the ask this sprint just deferred" ;;
    live)        echo "IN SPRINT and DEFERRAL_REQUESTED are live statuses and must resolve" ;;
    reopened)    echo "the CURRENT status is the first one in the item; a superseded line below it must not decide" ;;
    archived)    echo "retro moves items to carry-over-backlog-archive.md; an id resolvable only there must resolve" ;;
    prefix)      echo "an id that is only a string PREFIX of a filed heading resolved to it" ;;
    nostatus)    echo "an item with no status line is not a filed OPEN item" ;;
    emptylist|unclosed|block) echo "a list that reads as nothing must be refused, never read as empty" ;;
    absent-early) echo "an absent field on an answer that predates the release stamp must be PENDING, not FAIL" ;;
    absent-late) echo "an absent field on an answer given after the release stamp is the skipped write and must FAIL" ;;
    nogit|nostamp) echo "no git, or no commit stamping the release, leaves the date undecidable: PENDING" ;;
    tzgap)       echo "the hook timestamp is UTC; read in the caller's zone it lands after the stamp and FAILS a legacy record" ;;
    lex)         echo "0.7.0 is older than 0.659.0; a string compare dates the release to the wrong commit" ;;
    first)       echo "the FIRST commit stamping the release decides; a later one reads a post-release answer as legacy" ;;
    absentnone)  echo "a 'none' cite carries no answer timestamp, so an absent field beside it is PENDING" ;;
    duphash)     echo "a recurring answer hash was dated by its OLDEST entry, reading a post-release skipped write as legacy" ;;
  esac
}

# --- Assertions 38-62: every cell against the shipping validator ---------------
SD_GOT="$(sd_verdicts "$VALIDATOR")"
for c in $SD_CELLS; do
  want="$(sd_cell_of "$SD_EXPECT" "$c")"; got="$(sd_cell_of "$SD_GOT" "$c")"
  if [ "$want" = "$got" ]; then
    ok "deferred-items cell '$c': rc=$got as required"
  else
    bad "deferred-items cell '$c': got '$got', expected '$want' — $(sd_why "$c")"
  fi
done

# --- Assertion 63: the two consumer layouts do not change the answer ------------
# The arm reads `carry-over-backlog-archive.md` BESIDE the backlog it was given, never from
# the root, so a backlog passed by path finds its own archive from any working directory.
SD_CWD_OUT="$( cd / && bash "$VALIDATOR" --snapshot "$SD/snap-archived.md" --answers "$ANSWERS" \
                 --backlog "$SD_BL" --repo "$REPO_STD" 2>&1 )"; SD_CWD_RC=$?
if [ "$SD_CWD_RC" = "0" ] && grep -qF "deferred_items_checked: 1" <<<"$SD_CWD_OUT"; then
  ok "run from / the archive beside the given backlog still resolves — the arm is cwd-invariant"
else
  bad "run from / the archived id returned rc=$SD_CWD_RC — the archive is located relative to the working directory: $SD_CWD_OUT"
fi


# =============================================================================
# THE UNREADABLE CORPUS -- a backlog or archive that exists and cannot be read REFUSES (exit 2).
# =============================================================================
# THE DEFECT. status_of is awk over the file. Against a file awk cannot open it prints nothing and
# exits before END, so `st` came back EMPTY, and the verdict case's catch-all arm acquitted the
# empty string as "found, not CLOSED": a CLOSED id and an id never filed both passed at exit 0
# against a mode-000 backlog. The fix is three layers, and each cell below is the subject of ONE
# of them:
#   precheck  -- an existing, unreadable (or non-regular) backlog/archive refuses before any
#                lookup. Its own subjects: the archive unreadable while the id resolves in the
#                backlog (never looked up), and a backlog path that is a DIRECTORY (root-proof).
#   lookuprc  -- the lookup's exit status. Subject: a stub awk that prints `S OPEN` and exits 2.
#   verdict   -- only `S <status>` is FOUND. Subject: a stub awk that exits 0 printing nothing.
# The mode-000 cells cannot express unreadable under root (or any host that reads a mode-000
# file). They are then INCONCLUSIVE -- `S` in the vector, never `ok`.
UR="$SD/ur"; mkdir -p "$UR/ok" "$UR/b0" "$UR/a0" "$UR/dir" "$UR/stub"
SD_ARCH="$SD/pa/carry-over-backlog-archive.md"
for w in ok b0 a0; do cp "$SD_BL" "$UR/$w/carry-over-backlog.md"; cp "$SD_ARCH" "$UR/$w/carry-over-backlog-archive.md"; done
mkdir -p "$UR/dir/carry-over-backlog.md"; cp "$SD_ARCH" "$UR/dir/carry-over-backlog-archive.md"
chmod 000 "$UR/b0/carry-over-backlog.md" "$UR/a0/carry-over-backlog-archive.md"
sd_snap unfiled "[CO-S315-NEVER-FILED]"
UR_SKIP=""
if [ "$(id -u)" -eq 0 ]; then UR_SKIP="running as root, which reads a mode-000 file"
elif cat "$UR/b0/carry-over-backlog.md" >/dev/null 2>&1 || cat "$UR/a0/carry-over-backlog-archive.md" >/dev/null 2>&1; then
  UR_SKIP="this host reads a mode-000 file, so the seed cannot express unreadable"
fi
[ -n "$UR_SKIP" ] && printf '  INCONCLUSIVE  unreadable-corpus mode-000 cells -- %s\n' "$UR_SKIP"
UR_MODE000="bl-closed bl-unfiled bl-none ar-only ar-unreached"

# The stub claims ONLY status_of (its argv carries `-v id=`), logs the claim, and execs the real
# awk for everything else.
UR_REALAWK="$(command -v awk)" || { echo "FIXTURE ERROR: awk is not on PATH" >&2; exit 2; }
{
  printf '#!/bin/bash\ncase " $* " in\n'
  printf '  *" id="*) printf "x\\n" >> "%s/LOG"\n' "$UR/stub"
  printf '    case "$UR_AWK_MODE" in failok) echo "S OPEN"; exit 2 ;; silent) exit 0 ;; esac ;;\n'
  printf 'esac\nexec "%s" "$@"\n' "$UR_REALAWK"
} > "$UR/stub/awk"
chmod +x "$UR/stub/awk"

UR_OUT=""; UR_RC=0
ur_run() {   # $1 validator, $2 world, $3 snapshot name, [$4 stub mode]
  : > "$UR/stub/LOG"
  if [ -n "${4:-}" ]; then
    UR_OUT="$(PATH="$UR/stub:$PATH" UR_AWK_MODE="$4" TZ=UTC bash "$1" --snapshot "$SD/snap-$3.md" \
              --answers "$ANSWERS" --backlog "$UR/$2/carry-over-backlog.md" --repo "$REPO_STD" 2>&1)"; UR_RC=$?
  else
    UR_OUT="$(TZ=UTC bash "$1" --snapshot "$SD/snap-$3.md" --answers "$ANSWERS" \
              --backlog "$UR/$2/carry-over-backlog.md" --repo "$REPO_STD" 2>&1)"; UR_RC=$?
  fi
}
ur_refused() {   # $1 the file the refusal must name
  grep -qF "cannot read the carry-over corpus" <<<"$UR_OUT" && grep -qF -- "$1" <<<"$UR_OUT"
}
UR_CELLS="ctl-closed ctl-archclosed bl-closed bl-unfiled bl-none ar-only ar-unreached dir stub-failok stub-silent"
ur_verdicts() {
  local v="$1" out="" c
  ur_cell() { out="$out $1=$UR_RC"; }
  ur_skip() { case " $UR_MODE000 " in *" $1 "*) [ -n "$UR_SKIP" ] && { out="$out $1=S"; return 0; } ;; esac; return 1; }
  # Readable twins, same invocation: the SAME ids against the SAME bytes read CLOSED -> 1.
  ur_run "$v" ok closed; ur_cell ctl-closed
  ur_run "$v" ok archclosed; ur_cell ctl-archclosed
  ur_skip bl-closed || { ur_run "$v" b0 closed; ur_refused "$UR/b0/carry-over-backlog.md" || UR_RC="${UR_RC}x"; ur_cell bl-closed; }
  ur_skip bl-unfiled || { ur_run "$v" b0 unfiled; ur_refused "$UR/b0/carry-over-backlog.md" || UR_RC="${UR_RC}x"; ur_cell bl-unfiled; }
  # Near-miss: `none` consults no corpus, so an unreadable one does not wedge it.
  ur_skip bl-none || { ur_run "$v" b0 none; ur_cell bl-none; }
  ur_skip ar-only || { ur_run "$v" a0 archclosed; ur_refused "$UR/a0/carry-over-backlog-archive.md" || UR_RC="${UR_RC}x"; ur_cell ar-only; }
  ur_skip ar-unreached || { ur_run "$v" a0 one; ur_refused "$UR/a0/carry-over-backlog-archive.md" || UR_RC="${UR_RC}x"; ur_cell ar-unreached; }
  ur_run "$v" dir one; ur_refused "$UR/dir/carry-over-backlog.md" || UR_RC="${UR_RC}x"; ur_cell dir
  for c in failok silent; do
    ur_run "$v" ok closed "$c"
    [ -s "$UR/stub/LOG" ] || UR_RC="${UR_RC}n"     # the stub never ran: this cell observed nothing
    ur_refused "$UR/ok/carry-over-backlog.md" || UR_RC="${UR_RC}x"; ur_cell "stub-$c"
  done
  printf '%s\n' "${out# }"
}
UR_EXPECT="ctl-closed=1 ctl-archclosed=1 bl-closed=2 bl-unfiled=2 bl-none=0 ar-only=2 ar-unreached=2 dir=2 stub-failok=2 stub-silent=2"
if [ -n "$UR_SKIP" ]; then
  for c in $UR_MODE000; do UR_EXPECT="$(sed "s/ $c=[0-9]*/ $c=S/" <<<" $UR_EXPECT")"; UR_EXPECT="${UR_EXPECT# }"; done
fi

UR_GOT="$(ur_verdicts "$VALIDATOR")"
for c in $UR_CELLS; do
  want="$(sd_cell_of "$UR_EXPECT" "$c")"; got="$(sd_cell_of "$UR_GOT" "$c")"
  if [ "$want" = "S" ] && [ "$got" = "S" ]; then continue; fi
  if [ "$want" = "$got" ]; then
    ok "unreadable-corpus cell '$c': rc=$got as required"
  else
    bad "unreadable-corpus cell '$c': got '$got', expected '$want' — an id looked up in a corpus nobody could read was given a verdict (x: the refusal did not name the file; n: the stub awk never ran)"
  fi
done

chmod 644 "$UR/b0/carry-over-backlog.md" "$UR/a0/carry-over-backlog-archive.md" 2>/dev/null

# --- A non-UTF-8 byte in a READABLE item is not an unreadable corpus ---------------------------
# Once the lookup's awk exit is read, a UTF-8 locale makes BSD awk abort (`towc: multibyte
# conversion failure`) on one Latin-1 byte inside the item's section, and that abort refused a
# healthy OPEN item as "cannot read the carry-over corpus". The CLOSED twin is the same bytes one
# status apart, so a subject that refuses or acquits everything fails one of the pair. The cells
# run under a UTF-8 locale; a host without one cannot express the defect and says so.
LB="$SD/latin1"; mkdir -p "$LB/open" "$LB/closed"
printf '# Carry-over Backlog\n\n### CO-S315-LATIN1-ITEM\ncaf\351 note carried from a pasted email\n**Status:** OPEN\n' \
  > "$LB/open/carry-over-backlog.md"
printf '# Carry-over Backlog\n\n### CO-S315-LATIN1-ITEM\ncaf\351 note carried from a pasted email\n**Status:** CLOSED - delivered\n' \
  > "$LB/closed/carry-over-backlog.md"
sd_snap latin1 "[CO-S315-LATIN1-ITEM]"
LB_LOC=""
for l in en_US.UTF-8 C.UTF-8; do
  if [ "$(LC_ALL="$l" locale charmap 2>/dev/null)" = "UTF-8" ]; then LB_LOC="$l"; break; fi
done
lb_run() {   # $1 validator, $2 world -> echoes rc
  LC_ALL="$LB_LOC" LANG="$LB_LOC" TZ=UTC bash "$1" --snapshot "$SD/snap-latin1.md" --answers "$ANSWERS" \
    --backlog "$LB/$2/carry-over-backlog.md" --repo "$REPO_STD" >/dev/null 2>&1
  echo $?
}
if [ -z "$LB_LOC" ]; then
  printf '  INCONCLUSIVE  latin1 cells -- this host has no UTF-8 locale, so it cannot express the abort\n'
else
  r_open="$(lb_run "$VALIDATOR" open)"; r_closed="$(lb_run "$VALIDATOR" closed)"
  if [ "$r_open" = "0" ] && [ "$r_closed" = "1" ]; then
    ok "a Latin-1 byte in a readable item under $LB_LOC: OPEN passes (0), its CLOSED twin fails (1)"
  else
    bad "a Latin-1 byte in a readable item under $LB_LOC: OPEN rc=$r_open (want 0), CLOSED rc=$r_closed (want 1) — an encoding read as an unreadable corpus, or a CLOSED item acquitted"
  fi
fi

# =============================================================================
# THE LABELLED CITE -- `scope_confirmed_cite: SHA256:<hex>` resolves as the bare hex does.
# =============================================================================
# THE DEFECT. route.md Step 6 named the cite as "the `SHA256:` value" of the hook's
# `- SHA256: <hex>` line, and a lead copied the label in. The hex arm then refused a cite whose
# bare hex resolves. The fix strips exactly ONE literal `SHA256:` at the assignment, before the
# `-z` arm, so the resolve grep AND the deferred-items timestamp join both read the bare hex.
#
# Each cell names the ARM that must decide it, as a message conjunct (`x` suffix when absent),
# so an rc reached through the wrong arm does not score as the right one. `SHA256:` alone
# reaches the validator as `SHA256` -- field_of strips trailing punctuation -- so the hex arm
# refuses it, not the empty-cite arm. `pc-bare-absent` is the bare-hex twin of `pc-absent`.
#
sd_snap pc-real   none "SHA256:$SHA"
sd_snap pc-fab    none "SHA256:$(printf 'd%.0s' $(seq 1 64))"
sd_snap pc-foo    none "foo:$SHA"
sd_snap pc-dbl    none "SHA256:SHA256:$SHA"
sd_snap pc-empty  none "SHA256:"
sd_snap pc-absent "-"  "SHA256:$SHA"
PC_CELLS="pc-real pc-fab pc-foo pc-dbl pc-empty pc-absent pc-bare-absent"
pc_verdicts() {
  local v="$1" out=""
  pc_cell() { out="$out $1=$SD_RC"; }
  sd_run "$v" pc-real "$ANSWERS" "$REPO_STD"
  sd_has "cite resolves to a hook-written answer record" || SD_RC="${SD_RC}x"; pc_cell pc-real
  sd_run "$v" pc-fab "$ANSWERS" "$REPO_STD"
  sd_has "resolves to no entry" || SD_RC="${SD_RC}x"; pc_cell pc-fab
  sd_run "$v" pc-foo "$ANSWERS" "$REPO_STD"
  sd_has "is not a hex SHA256" || SD_RC="${SD_RC}x"; pc_cell pc-foo
  sd_run "$v" pc-dbl "$ANSWERS" "$REPO_STD"
  sd_has "is not a hex SHA256" || SD_RC="${SD_RC}x"; pc_cell pc-dbl
  sd_run "$v" pc-empty "$ANSWERS" "$REPO_STD"
  sd_has "is not a hex SHA256" || SD_RC="${SD_RC}x"; pc_cell pc-empty
  sd_run "$v" pc-absent "$SD/answers-late.md" "$REPO_STD"
  sd_has "no 'scope_deferred_items' field" || SD_RC="${SD_RC}x"; pc_cell pc-absent
  sd_run "$v" absent "$SD/answers-late.md" "$REPO_STD"
  sd_has "no 'scope_deferred_items' field" || SD_RC="${SD_RC}x"; pc_cell pc-bare-absent
  printf '%s\n' "${out# }"
}
PC_EXPECT="pc-real=0 pc-fab=1 pc-foo=1 pc-dbl=1 pc-empty=1 pc-absent=1 pc-bare-absent=1"
pc_why() {
  case "$1" in
    pc-real)   echo "a cite copied with its SHA256: label must resolve as its bare hex does" ;;
    pc-fab)    echo "a labelled fabricated hash must still resolve to nothing and FAIL" ;;
    pc-foo)    echo "only the literal SHA256: label is stripped; any other label stays refused" ;;
    pc-dbl)    echo "the label is stripped ONCE; a doubled label stays refused" ;;
    pc-empty)  echo "a label with no digest is refused by the hex arm" ;;
    pc-absent) echo "a labelled cite beside an absent deferred-items field is dated like the bare cite (FAIL, not PENDING)" ;;
    pc-bare-absent) echo "control: the bare-hex twin of pc-absent" ;;
  esac
}

# --- Assertions 64-70: every labelled-cite cell against the shipping validator ---
PC_GOT="$(pc_verdicts "$VALIDATOR")"
for c in $PC_CELLS; do
  want="$(sd_cell_of "$PC_EXPECT" "$c")"; got="$(sd_cell_of "$PC_GOT" "$c")"
  if [ "$want" = "$got" ]; then
    ok "labelled-cite cell '$c': rc=$got as required"
  else
    bad "labelled-cite cell '$c': got '$got', expected '$want' — $(pc_why "$c")"
  fi
done


# =============================================================================
# LOCKED-SCOPE DEFERRAL ARM: a live DEFERRAL_REQUEST may not name a confirmed item.
# =============================================================================
# The worlds are shaped on the reference consumer's sprint 319 (the motivating case: a
# `CO-S319-` item the evaluation filed and deferred 3h after the scope answer) and sprint 316
# (the measured false positive: the operator deferred the stretch tier at Step 6, the lead
# listed CARRIER ids in scope_deferred_items, and each entry named its carrier AND the
# original id the ask named). Escalation entries use that consumer's header grammar
# `## [ID] lead - <ISO>Z`; the request entry uses the capture hook's `- SHA256:` grammar.
LS="$WORK/lsd"; mkdir -p "$LS"
LS_RQ="$(printf 'e%.0s' $(seq 1 64))"
sd_answers lsans 2026-10-15T18:55:29Z
LS_ANS="$SD/answers-lsans.md"
# The recurring-answer world: the same answer body (so the same hash) given once long before
# and again at this sprint's Step 6. The reference consumer's `Confirmed` recurs exactly so.
sd_answers lsold 2026-08-01T00:00:00Z
{ cat "$SD/answers-lsold.md"; echo; sed -n '/^## /,$p' "$LS_ANS"; } > "$SD/answers-lsdup.md"
{ printf '# Operator Requests\n\n## 2026-10-15T18:49:36Z -- (typed)\n- Session: s1\n- Bytes: 99\n'
  printf -- '- SHA256: %s\n\n```text\n' "$LS_RQ"
  printf '1. CO-S318-ASKED-ITEM: take it.\n5. Add a Collect Rewards button.\n```\n'
  printf '\n## 2026-10-15T19:00:00Z -- (typed)\n- SHA256: %s\n\n```text\nCO-S300-UNRELATED later\n```\n' "$(printf 'f%.0s' $(seq 1 64))"
} > "$LS/requests.md"
{ printf '# Carry-over Backlog\n\n### CO-S319-RATIFIED-DEFER\n**Status:** OPEN\n'; } > "$LS/backlog.md"
ls_snap() {   # $1 name, $2 user_request_cite
  { echo "# Pipeline Snapshot"; echo; echo "## Pipeline Position"
    echo "- user_request_verbatim: see operator-requests-history.md"
    echo "- user_request_cite: $2"
    echo "- scope_confirmed: confirmed"
    echo "- scope_confirmed_cite: $SHA"
    echo "- scope_deferred_items: [CO-S319-RATIFIED-DEFER]"
    echo; echo "## Sprint Context"; echo "- sprint_id: 319"
  } > "$LS/snap-$1.md"
}
ls_snap cited "$LS_RQ"
ls_snap noask none
# A cite that is a hash but matches no entry in the requests file: the ask leg did not run.
ls_snap badhash "$(printf 'a%.0s' $(seq 1 64))"
ls_esc() {    # $1 world, $2 header timestamp, $3 status, $4 body line naming the ids
  { printf '# Escalations\n\n## [S319-EARLIER-NOTE] lead - 2026-10-15T20:00:00Z\n'
    printf '**Status:** DECIDED_AUTONOMOUSLY\n**Context:** names CO-S319-OTHER-ITEM in an informational entry.\n\n'
    printf '## [S319-THE-DEFERRAL] lead - %s\n**Status:** %s\n**Blocker type:** deferral\n' "$2" "$3"
    printf '**Context:** %s\n' "$4"
    printf '**Resolution note:** this entry was filed as `DEFERRAL_REQUEST` (prose, not a status).\n'
  } > "$LS/esc-$1.md"
}
ls_esc fire     2026-10-15T21:42:08Z DEFERRAL_REQUEST "defer CO-S319-COLLECT-REWARDS-X to a later sprint."
ls_esc fireask  2026-10-15T21:42:08Z DEFERRAL_REQUEST "defer CO-S318-ASKED-ITEM to a later sprint."
ls_esc resolved 2026-10-15T21:42:08Z RESOLVED         "defer CO-S319-COLLECT-REWARDS-X to a later sprint."
ls_esc before   2026-10-15T18:00:00Z DEFERRAL_REQUEST "defer CO-S319-COLLECT-REWARDS-X to a later sprint."
ls_esc recur    2026-09-01T00:00:00Z DEFERRAL_REQUEST "defer CO-S319-COLLECT-REWARDS-X to a later sprint."
ls_esc ratified 2026-10-15T21:42:08Z DEFERRAL_REQUEST "carrier CO-S319-RATIFIED-DEFER; the item CO-S318-ASKED-ITEM is the operator-deferred stretch."
ls_esc outside  2026-10-15T21:42:08Z DEFERRAL_REQUEST "defer CO-S300-UNRELATED to a later sprint."
ls_esc noask    2026-10-15T21:42:08Z DEFERRAL_REQUEST "defer CO-S318-ASKED-ITEM to a later sprint."
LS_OUT=""; LS_RC=0
ls_run() {    # $1 validator, $2 snapshot, $3 escalations world, [$4 answers path]
  LS_OUT="$(TZ=UTC bash "$1" --snapshot "$LS/snap-$2.md" --answers "${4:-$LS_ANS}" --backlog "$LS/backlog.md" \
            --repo "$REPO_STD" --requests "$LS/requests.md" --escalations "$LS/esc-$3.md" 2>&1)"; LS_RC=$?
}
ls_has() { grep -qF -- "$1" <<<"$LS_OUT"; }
# Every cell is PRESENCE-shaped: a refusal must name its id, and a quiet cell must print its
# scanned count (and the SKIP line where one is owed), so a subject that emits nothing fails.
LS_CELLS="fire fireask resolved before recur ratified outside noask badhash"
ls_verdicts() {
  local v="$1" out=""
  ls_cell() { out="$out $1=$LS_RC"; }
  ls_run "$v" cited fire;     ls_has "locked id(s): CO-S319-COLLECT-REWARDS-X" || LS_RC="${LS_RC}x"; ls_cell fire
  ls_run "$v" cited fireask;  ls_has "locked id(s): CO-S318-ASKED-ITEM" || LS_RC="${LS_RC}x"; ls_cell fireask
  ls_run "$v" cited resolved; ls_has "locked_scope_deferrals_scanned: 0 " || LS_RC="${LS_RC}x"; ls_cell resolved
  ls_run "$v" cited before;   ls_has "locked_scope_deferrals_scanned: 0 " || LS_RC="${LS_RC}x"; ls_cell before
  ls_run "$v" cited recur "$SD/answers-lsdup.md"
  ls_has "locked_scope_deferrals_scanned: 0 " || LS_RC="${LS_RC}x"; ls_cell recur
  ls_run "$v" cited ratified; ls_has "locked_scope_deferrals_scanned: 1 " || LS_RC="${LS_RC}x"; ls_cell ratified
  ls_run "$v" cited outside;  ls_has "locked_scope_deferrals_scanned: 1 " || LS_RC="${LS_RC}x"; ls_cell outside
  ls_run "$v" noask noask
  # The closing line must name the leg that ran and must NOT claim the whole property.
  { ls_has "SKIP  locked-scope ask leg" && ls_has "locked_scope_deferrals_scanned: 1 " \
    && ls_has "PARTIAL  locked-scope arm: only the sprint leg ran (CO-S319- ids)" \
    && ! ls_has "PASS  no live DEFERRAL_REQUEST"; } || LS_RC="${LS_RC}x"; ls_cell noask
  ls_run "$v" badhash noask
  { ls_has "SKIP  locked-scope ask leg" && ls_has "PARTIAL  locked-scope arm: only the sprint leg ran" \
    && ! ls_has "PASS  no live DEFERRAL_REQUEST"; } || LS_RC="${LS_RC}x"; ls_cell badhash
  printf '%s\n' "${out# }"
}
LS_EXPECT="fire=1 fireask=1 resolved=0 before=0 recur=0 ratified=0 outside=0 noask=0 badhash=0"
ls_why() {
  case "$1" in
    fire)     echo "a live DEFERRAL_REQUEST naming a CO-S<sprint>- item filed after the scope answer must be refused (the s319 shape)" ;;
    fireask)  echo "a live DEFERRAL_REQUEST naming an id the operator's ask named must be refused" ;;
    resolved) echo "a RESOLVED deferral (prose still quoting DEFERRAL_REQUEST) was put to the operator and must be silent" ;;
    before)   echo "a deferral filed BEFORE the scope answer predates the confirmation and must be silent" ;;
    recur)    echo "a recurring answer body dates the window by its NEWEST copy; an older deferral must be silent" ;;
    ratified) echo "an entry naming an id scope_deferred_items lists was ratified at Step 6 and must be silent (the s316 shape)" ;;
    outside)  echo "a deferral of an id outside the locked set must be silent" ;;
    noask)    echo "no ask cite must print a VISIBLE SKIP for the ask leg and a PARTIAL line naming the sprint leg, never the full PASS claim" ;;
    badhash)  echo "an ask cite matching no requests entry is a SKIPPED ask leg, never one that ran and found nothing" ;;
  esac
}
LS_GOT="$(ls_verdicts "$VALIDATOR")"
for c in $LS_CELLS; do
  want="$(sd_cell_of "$LS_EXPECT" "$c")"; got="$(sd_cell_of "$LS_GOT" "$c")"
  if [ "$want" = "$got" ]; then ok "locked-scope cell '$c': rc=$got as required"
  else bad "locked-scope cell '$c': got '$got', expected '$want' — $(ls_why "$c")"; fi
done

echo
report_end scope-confirmation
