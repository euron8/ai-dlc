#!/usr/bin/env bash
# Seed for validate-escalation-resolution.sh -- an operator-gated HARD_BLOCK must not be marked
# RESOLVED by an operator who never spoke (the literal S290 fabrication surface: six
# `## S290-* Lead (...)` entries flipped to RESOLVED in an operator-silent window).
set -eu
ROOT="$(mktemp -d)"

# One entry. $1 file  $2 header-id  $3 status  $4 (optional) authorization line value
entry() {
  local file="$1" id="$2" status="$3" auth="${4:-}"
  {
    printf '## %s Lead (gate [planning]) - 2026-07-12\n' "$id"
    printf '**Status:** %s\n' "$status"
    printf '**Blocker type:** trade-off\n'
    printf '**Context:** a decision was needed on the item.\n'
    printf '**Decision/Question:** which approach to take.\n'
    [ -n "$auth" ] && printf '**Operator authorization:** %s\n' "$auth"
    printf '\n'
  } >> "$file"
}

CITE_REAL='2026-07-12T03:00:00Z | "reframe the AC as a class invariant"'
CITE_FAKE='2026-07-12T03:00:00Z | "the operator authorized this disposition"'

# (b) S50 RESOLVED, NO citation -- the S290 shape (Lead-authored, no operator message).
: > "$ROOT/pending-missing.md";     entry "$ROOT/pending-missing.md"     S50-ITEM-1 RESOLVED

# (c) S50 RESOLVED, citation whose words appear in NO genuine operator message.
: > "$ROOT/pending-fabricated.md";  entry "$ROOT/pending-fabricated.md"  S50-ITEM-2 RESOLVED "$CITE_FAKE"

# (d) S50 RESOLVED, citation verbatim in a genuine operator message.
: > "$ROOT/pending-real.md";        entry "$ROOT/pending-real.md"        S50-ITEM-3 RESOLVED "$CITE_REAL"

# (e) LEGACY: a prior-sprint RESOLVED HARD_BLOCK with no citation. Checking --sprint 50 must NOT
#     flag it -- it was resolved in a session this transcript never saw.
: > "$ROOT/pending-legacy.md";      entry "$ROOT/pending-legacy.md"      S49-OLD-1 RESOLVED

# (f) DECIDED_AUTONOMOUSLY: the honest-attribution escape valve. A decision the lead openly made
#     on its own needs no operator citation.
: > "$ROOT/pending-autonomous.md";  entry "$ROOT/pending-autonomous.md"  S50-ITEM-4 DECIDED_AUTONOMOUSLY

# (a) VACUOUS: only a legacy entry and an autonomous one -- nothing in scope needs a citation.
: > "$ROOT/pending-clean.md"
entry "$ROOT/pending-clean.md" S49-OLD-2 RESOLVED
entry "$ROOT/pending-clean.md" S50-ITEM-5 DECIDED_AUTONOMOUSLY

# EMPTY, BLANK and HEADING-ONLY. The first two hold no non-whitespace byte and are the ABSENT
# state; the third holds prose and no entry, and is not. Whitespace-only is its own seed because
# a `[ -s ]` test calls it populated.
: > "$ROOT/pending-empty.md"
printf '\n \n' > "$ROOT/pending-blank.md"
printf '# Escalations\nNo escalation has been filed this sprint.\n' > "$ROOT/pending-heading.md"

# --- transcripts ---------------------------------------------------------------------------
# THE THIRD RECORD IS THREE WEEKS OLD, and it is what a lead reaching backwards would cite:
# write today's entry, quote a phrase that already exists. Every out-of-window seed this suite
# had put the record AFTER the stamp, which is the direction nobody forges.
cat > "$ROOT/real.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-06-20T10:00:00Z","message":{"content":"Use the second approach throughout."}}
{"type":"user","timestamp":"2026-07-12T01:00:00Z","message":{"content":"/ai-dlc Sprint 50."}}
{"type":"user","timestamp":"2026-07-12T03:00:00Z","message":{"content":"Reframe the AC as a class invariant, not a per-site fix."}}
JSONL

cat > "$ROOT/silent.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-07-12T01:00:00Z","message":{"content":"/ai-dlc Sprint 50."}}
{"type":"assistant","timestamp":"2026-07-12T02:30:00Z","message":{"content":[{"type":"text","text":"Two HARD_BLOCKs open; pausing for your adjudication."}]}}
JSONL

# --- the CROSS-SESSION corpus ---------------------------------------------------------------
# A sprint spans sessions. The operator adjudicates on Monday (spoke.jsonl) and the gate re-runs
# on Friday, when `transcript_path` names Friday's session (gate.jsonl) -- which by construction
# does not contain Monday's words. A single-file check calls the honest lead a forger and stops
# the gate; the corpus is where the citation actually lives.
mkdir -p "$ROOT/corpus"
cat > "$ROOT/corpus/spoke.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-07-12T03:00:00Z","message":{"content":"Cut the contested clause and proceed to stories."}}
JSONL
cat > "$ROOT/corpus/gate.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-07-15T09:00:00Z","message":{"content":"/ai-dlc resume"}}
{"type":"assistant","timestamp":"2026-07-15T09:01:00Z","message":{"content":[{"type":"text","text":"Resuming at the planning gate."}]}}
JSONL

# A corpus the RUN MOVES BETWEEN TWO INVOCATIONS, seeded empty and filled by run.sh. The
# measured phenomenon is that a transcript directory is LIVE: the same `--transcript-dir` path
# holds a different set of `.jsonl` files minutes apart while the session writing it is idle, so
# two runs over a byte-identical pending.md are two runs over two corpora. Proving a reader sees
# that needs the PATH held constant and the CONTENT changed -- two differently-named seed dirs
# cannot express it, because an output that merely echoes its own `--transcript-dir` argument
# would separate them and still be blind to the thing that moves.
mkdir -p "$ROOT/corpus-live"

CITE_CROSS='2026-07-12T03:00:00Z | "Cut the contested clause and proceed to stories."'
CITE_CROSS_FAKE='2026-07-12T03:00:00Z | "zzz no operator ever typed this phrase zzz"'

# (h) S50 RESOLVED citing a GENUINE operator message that lives in a session the gate cannot name.
: > "$ROOT/pending-crosssession.md"; entry "$ROOT/pending-crosssession.md" S50-ITEM-6 RESOLVED "$CITE_CROSS"

# (i) S50 RESOLVED citing words no operator typed ANYWHERE in the corpus. The corpus arm must not
#     widen into fail-open: scanning more sessions must never turn a fabrication into a pass.
: > "$ROOT/pending-crossfake.md";    entry "$ROOT/pending-crossfake.md"    S50-ITEM-7 RESOLVED "$CITE_CROSS_FAKE"

# --- corpora that EXIST and hold no ground truth ---------------------------------------------
# `--transcript-dir` was tested for EXISTENCE only, never for CONTENT. With nothing to search,
# the citation query returned NOMATCH and this validator reported the OPERATOR as having said
# nothing -- an accusation ("This is the S290 failure"), where the true state is that the gate
# had no corpus. The two exits are both 1, so only the MESSAGE separates them.
#
# The corpus reader selects `*.jsonl` and only those (`validate-steering-budget.sh:427`), so a
# directory of sidecar files is exactly as blind as an empty one. Both shapes are seeded
# because a narrowing keyed on "the directory has no entries" passes one and fails the other.
mkdir -p "$ROOT/dir-empty"

mkdir -p "$ROOT/dir-sidecar"
printf 'not a transcript\n'           > "$ROOT/dir-sidecar/README.md"
printf '{"note":"summary sidecar"}\n' > "$ROOT/dir-sidecar/summary.json"
printf 'session-abc123\n'             > "$ROOT/dir-sidecar/.session-id"

# --- the citation is a FIELD, and a line-oriented greedy regex read the wrong half of it ------
# Every shape below is one the reference consumer actually wrote. Measured over the 106 distinct
# `Operator authorization:` citations in the whole history of its `pending.md` and
# `pending-archive.md`: 98 carry exactly one quoted segment and are unaffected by any of this;
# 8 do not, and those 8 are the population these four entries stand in for.
#
# The two ORDER seeds are one property from each other -- same two quoted segments, swapped --
# because the pre-fix extractor took the LAST one. That made a genuine citation with anything
# after it a reported S290 fabrication, and made an INVENTED disposition pass whenever a real
# operator substring trailed it. `pending-real.md` and `pending-fabricated.md` above are the
# near-miss twins: one quoted segment each, and neither verdict may move.
CITE_ORDER_GOOD_FIRST='2026-07-12T03:00:00Z | "reframe the AC as a class invariant" / "zzz no operator ever typed this phrase zzz"'
CITE_ORDER_GOOD_LAST='2026-07-12T03:00:00Z | "zzz no operator ever typed this phrase zzz" / "reframe the AC as a class invariant"'

# An ODD quote count: the capture used to be the CONNECTIVE BETWEEN two quotes. The consumer's
# own `"1. RETIRE" and "This work was already done in` yielded ` and `, five characters, and
# failed as "too short" naming none of the operator's words.
CITE_CONNECTIVE='2026-07-12T03:00:00Z | "1. RETIRE" and "reframe the AC as a class invariant'

# A citation that continues on the NEXT line. The producing awk is line-oriented, so the closing
# quote is on a line it never reads; the old fallback then kept the opening `"` inside the
# needle, and no operator message contains that character there. This one also carries no `|`,
# which is the shape that made the fallback return the whole label line.
CITE_UNTERMINATED='2026-07-12T03:00:00Z, this session, verbatim: "reframe the AC as a class invariant'

: > "$ROOT/pending-order-good-first.md"; entry "$ROOT/pending-order-good-first.md" S50-ITEM-8  RESOLVED "$CITE_ORDER_GOOD_FIRST"
: > "$ROOT/pending-order-good-last.md";  entry "$ROOT/pending-order-good-last.md"  S50-ITEM-9  RESOLVED "$CITE_ORDER_GOOD_LAST"
: > "$ROOT/pending-connective.md";       entry "$ROOT/pending-connective.md"       S50-ITEM-10 RESOLVED "$CITE_CONNECTIVE"
: > "$ROOT/pending-unterminated.md";     entry "$ROOT/pending-unterminated.md"     S50-ITEM-11 RESOLVED "$CITE_UNTERMINATED"

# --- the citation's TIMESTAMP: what it bounds, and what a writer can do to it -----------------
# The field is `<ISO ts> | "<quote>"` and the reader passes that timestamp to the verifier as
# the centre of a window. Three shapes, and only the first is what the grammar prescribes:
#
#   BEFORE   a genuine operator turn three weeks EARLIER than the stamp. The quote is real, so
#            every arm keyed on the words alone accepts it; only the window refuses it, and only
#            if the window has a lower side. A window spliced to refuse the later side alone
#            passed this whole suite before this entry existed.
#   SPACE    a space where the grammar wants `T`. `cite_ts` yields nothing, the reader passes no
#            bound, and the citation is verified against the WHOLE corpus -- a one-character
#            edit to the field the writer controls, and the PASS it produces used to be
#            byte-identical to an honest bounded one. Not refused (a live consumer row carries
#            no parseable timestamp and cites a real turn); COUNTED and printed.
#   OFFSET   the SAME INSTANT as the canonical stamp, written `-07:00`. Truncated to its naive
#            part the window moves seven hours and this citation NOMATCHes; read whole it is the
#            same moment and verifies.
CITE_BEFORE='2026-07-12T03:00:00Z | "Use the second approach throughout."'
CITE_SPACE='2026-07-12 03:00:00Z | "reframe the AC as a class invariant"'
CITE_OFFSET='2026-07-11T20:00:00-07:00 | "reframe the AC as a class invariant"'

: > "$ROOT/pending-before.md";   entry "$ROOT/pending-before.md"   S50-ITEM-12 RESOLVED "$CITE_BEFORE"
: > "$ROOT/pending-space.md";    entry "$ROOT/pending-space.md"    S50-ITEM-13 RESOLVED "$CITE_SPACE"
: > "$ROOT/pending-offset.md";   entry "$ROOT/pending-offset.md"   S50-ITEM-14 RESOLVED "$CITE_OFFSET"

# --- the citation FLOOR is a property of the NORMALISED needle ---------------------------------
# Every caller measured the raw bash `${#quote}` against 12 while the predicate collapses
# whitespace and trims before matching. So `"          yes"` (13 raw, 3 normalised) and twelve
# spaces (12 raw, EMPTY normalised -- and `includes("")` is true of every turn) verified against
# any operator turn in the window. The corpus below holds exactly such a turn, so a reader that
# measured the raw length WOULD have matched: these entries discriminate only on the floor.
#
# THE INCIDENT, SEEDED FROM THE REAL PRODUCER. The consumer's operator answered two numbered
# questions by free-typing `1. Yes.\n2. Yes.` after an assistant text turn; the record below
# carries the keys Claude Code writes on such a turn (typed, human origin, not a sidechain, a
# millisecond stamp, STRING content with the newline). Cited whole it is 15 characters once the
# newline collapses and verifies; `1. Yes.` alone is 7 and must be refused naming its length.
#
# TWO FILES, AND THE INCIDENT IS NOT THE ONE THE READER OPENS FIRST. run.sh asks the reader's own
# `readdirSync` which member comes first and refuses to score if it is the incident file, because
# a verifier that read one member and stopped would otherwise pass the whole-quote case.
mkdir -p "$ROOT/corpus-short"
# The second turn pins the floor's VALUE, not just its presence: `go ahead ok` is eleven
# characters and must be refused although a genuine turn carries it; `go ahead ok,` is twelve
# and must MATCH that same turn.
cat > "$ROOT/corpus-short/a-monday.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-10-05T12:00:00Z","message":{"role":"user","content":"Start the planning gate for the release branch."}}
{"type":"user","timestamp":"2026-10-05T12:05:00Z","message":{"role":"user","content":"Go ahead ok, ship it."}}
JSONL
cat > "$ROOT/corpus-short/b-incident.jsonl" <<'JSONL'
{"parentUuid":"9b1f0c2e-0000-4000-8000-000000000001","isSidechain":false,"type":"assistant","timestamp":"2026-10-05T13:14:18.000Z","message":{"role":"assistant","content":[{"type":"text","text":"Two decisions need you before the gate: 1. Close the item on the organic run? 2. File the follow-up as a NOTE?"}]},"uuid":"9b1f0c2e-0000-4000-8000-000000000002","sessionId":"22e0f5c2-0000-4000-8000-000000000000"}
{"parentUuid":"9b1f0c2e-0000-4000-8000-000000000002","isSidechain":false,"promptId":"9b1f0c2e-0000-4000-8000-000000000003","type":"user","message":{"role":"user","content":"1. Yes.\n2. Yes."},"uuid":"9b1f0c2e-0000-4000-8000-000000000004","timestamp":"2026-10-05T13:25:14.171Z","permissionMode":"bypassPermissions","origin":{"kind":"human"},"promptSource":"typed","turnOrigin":"human","userType":"external","entrypoint":"cli","sessionId":"22e0f5c2-0000-4000-8000-000000000000"}
JSONL

CITE_PADDED='2026-10-05T13:25:14Z | "          yes"'
CITE_BLANKQ='2026-10-05T13:25:14Z | "            "'
CITE_WHOLE='2026-10-05T13:25:14Z | "1. Yes. 2. Yes."'
CITE_SHORT='2026-10-05T13:25:14Z | "1. Yes."'
: > "$ROOT/pending-padded.md";         entry "$ROOT/pending-padded.md"         S50-ITEM-20 RESOLVED "$CITE_PADDED"
: > "$ROOT/pending-blankq.md";         entry "$ROOT/pending-blankq.md"         S50-ITEM-21 RESOLVED "$CITE_BLANKQ"
: > "$ROOT/pending-incident-whole.md"; entry "$ROOT/pending-incident-whole.md" S50-ITEM-22 RESOLVED "$CITE_WHOLE"
: > "$ROOT/pending-incident-short.md"; entry "$ROOT/pending-incident-short.md" S50-ITEM-23 RESOLVED "$CITE_SHORT"

# The same two shapes padded with U+00A0, which the predicate's `\s` collapses and an ASCII-only
# `[[:space:]]` under LC_ALL=C does not: ten NBSP and `yes` is 13 characters to that measure and 3
# to the predicate, and twelve NBSP is 12 and EMPTY. Built from octal so the bytes are exact.
NB="$(printf '\302\240')"
CITE_NBSP_PADDED="2026-10-05T13:25:14Z | \"${NB}${NB}${NB}${NB}${NB}${NB}${NB}${NB}${NB}${NB}yes\""
CITE_NBSP_BLANK="2026-10-05T13:25:14Z | \"${NB}${NB}${NB}${NB}${NB}${NB}${NB}${NB}${NB}${NB}${NB}${NB}\""
: > "$ROOT/pending-nbsp-padded.md";    entry "$ROOT/pending-nbsp-padded.md"    S50-ITEM-24 RESOLVED "$CITE_NBSP_PADDED"
: > "$ROOT/pending-nbsp-blank.md";     entry "$ROOT/pending-nbsp-blank.md"     S50-ITEM-25 RESOLVED "$CITE_NBSP_BLANK"

# --- a LEAD-INTERPRETATION entry resolves only on an exact disposition option (BL-944) ----------
# requirements.md §3 is the producer: one AskUserQuestion per `(lead interpretation)` bullet, its
# question opening `LR-S<N>-<m> (lead interpretation): `, and the entry written with a
# Decision/Question line of `LR-S<N>-<m> (lead interpretation) -- descope, <file:line>`, `-- confirm,
# <file:line>`, or, while paused, `-- awaiting operator: Confirm, Strike or Reword "<the clause>"`.
# The transcript lines are the AskUserQuestion tool_use / tool_result pair the BL-944 receipt seeds,
# which is the shape --cite reads as a genuine operator answer. One answer per hour, so every
# citation's timestamp bound selects exactly its own answer.
mkdir -p "$ROOT/lr/t"
LR_Q='LR-S7-2 (lead interpretation): the index covers the primary pool only.'
LR_FREE='How is there still no router derived? Absolutely unacceptable that you refuse to figure this out.'
lr_ask() {  # $1 tool id  $2 answer body  $3 ts
  printf '{"type":"assistant","timestamp":"%s","message":{"content":[{"type":"tool_use","id":"%s","name":"AskUserQuestion","input":{"questions":[{"question":"%s"}]}}]}}\n{"type":"user","timestamp":"%s","message":{"content":[{"type":"tool_result","tool_use_id":"%s","content":"Your questions have been answered: \\"%s\\"=\\"%s\\". You can now continue with these answers in mind."}]}}\n' "$3" "$1" "$LR_Q" "$3" "$1" "$LR_Q" "$2" >> "$ROOT/lr/t/s.jsonl"
}
lr_ask toolu_f "$LR_FREE"                      2026-11-08T10:01:00Z
lr_ask toolu_s "Strike LR-S7-2"                2026-11-08T11:01:00Z
lr_ask toolu_r "Reword LR-S7-2"                2026-11-08T12:01:00Z
lr_ask toolu_c "Confirm LR-S7-2"               2026-11-08T13:01:00Z
lr_ask toolu_e "Strike LR-S7-2 (Recommended)"  2026-11-08T14:01:00Z
lr_ask toolu_w "Strike LR-S7-3"                2026-11-08T15:01:00Z
# One entry per file. $1 name  $2 Decision/Question value, or "-" for an entry with NO such line
# $3 the authorization timestamp  $4 the quote
lr_entry() {
  {
    printf '## S7-LR-2 Lead (requirements) - 2026-11-08\n'
    printf '**Status:** RESOLVED\n'
    printf '**Blocker type:** missing requirement\n'
    [ "$2" = "-" ] || printf '**Decision/Question:** %s\n' "$2"
    printf '**Operator authorization:** %s | "%s"\n' "$3" "$4"
    printf '\n'
  } > "$ROOT/lr/$1.md"
}
LR_D='LR-S7-2 (lead interpretation) -- descope, _bmad-output/operator-answers-history.md:4'
LR_C='LR-S7-2 (lead interpretation) -- confirm, _bmad-output/operator-answers-history.md:9'
lr_entry free       "$LR_D" 2026-11-08T10:01:00Z "$LR_FREE"
lr_entry strike     "$LR_D" 2026-11-08T11:01:00Z 'Strike LR-S7-2'
lr_entry reword     "$LR_D" 2026-11-08T12:01:00Z 'Reword LR-S7-2'
lr_entry confirm    "$LR_C" 2026-11-08T13:01:00Z 'Confirm LR-S7-2'
lr_entry recommend  "$LR_D" 2026-11-08T14:01:00Z 'Strike LR-S7-2 (Recommended)'
# The wrong id is IN the transcript, so only the label rule can refuse it.
lr_entry wrongid    "$LR_D" 2026-11-08T15:01:00Z 'Strike LR-S7-3'
# A confirm option on a descope line, also in the transcript.
lr_entry mismatch   "$LR_D" 2026-11-08T13:01:00Z 'Confirm LR-S7-2'
# The exact option for an id nobody was asked about: the label rule passes, the lookup must refuse.
lr_entry nohit      'LR-S7-5 (lead interpretation) -- descope, _bmad-output/operator-answers-history.md:4' 2026-11-08T11:01:00Z 'Strike LR-S7-5'
# The paused form, filed RESOLVED: its disposition word is neither, and it carries a quoted clause.
lr_entry neither    'LR-S7-2 (lead interpretation) -- awaiting operator: Confirm, Strike or Reword "the index covers the primary pool only"' 2026-11-08T11:01:00Z 'Strike LR-S7-2'
# The near-miss: no label, the same free text. Its Decision/Question line carries a quoted phrase
# of more than twelve characters nobody answered, so a row that lets that field bleed into the
# authorization text verifies the wrong segment.
lr_entry plain      'an operator question about "QQZX a clause no record carries"' 2026-11-08T10:01:00Z "$LR_FREE"
# No Decision/Question line at all -- the empty-field row shape.
lr_entry nodq       - 2026-11-08T11:01:00Z 'Strike LR-S7-2'
# --any-authorized: a too-short quote beside a Decision/Question line carrying a long quoted phrase.
lr_entry shortq     'an operator question about "QQZX a clause no record carries"' 2026-11-08T11:01:00Z 'Strike'
# A TAB inside the `## ` header. Unreplaced, it shifts every later record field one variable right,
# so the authorization variable reads `<Decision/Question><TAB><auth>` and the quote cited is the
# Decision/Question text. hdrtabq is shortq with a tab header: only the shift authorizes it.
# hdrtab quotes words nobody said, beside a Decision/Question line carrying a phrase the operator
# DID send at that hour: only the shift verifies it.
lr_tab_entry() {  # $1 name  $2 Decision/Question value  $3 ts  $4 quote
  {
    printf '## S7-LR-2\tLead (requirements) - 2026-11-08\n'
    printf '**Status:** RESOLVED\n'
    printf '**Decision/Question:** %s\n' "$2"
    printf '**Operator authorization:** %s | "%s"\n' "$3" "$4"
    printf '\n'
  } > "$ROOT/lr/$1.md"
}
lr_tab_entry hdrtabq    'an operator question about "QQZX a clause no record carries"' 2026-11-08T11:01:00Z 'Strike'
lr_tab_entry hdrtab     "asked \"$LR_FREE\"" 2026-11-08T10:01:00Z 'the operator authorized this disposition'

# --- SUPPRESSED citations, and the sibling archive ----------------------------------------------
# Each layout is its own directory, because the validator reads `pending-archive.md` beside the
# file it is given: one at $ROOT would be read by every gate-mode arm above.
#   bad    S50 SUPPRESSED, invented words          -> gate FAIL
#   good   S50 SUPPRESSED, the genuine turn        -> gate OK, 1 checked
#   anyonly the good entry, asked --any-authorized -> NONE: a suppression is not an operator decision
#   anyres  the same entry RESOLVED                -> AUTHORIZED (anyonly's allow twin)
#   apop   pending.md holds only a legacy entry; the archive a fabricated S50 SUPPRESSED -> FAIL
#   aabs   the same archive with NO pending.md (the early-exit layout)                 -> FAIL
#   aemp   the same archive beside an EMPTY pending.md (the other early exit)          -> FAIL
#   agood  no pending.md; the archive holds the genuine S50 SUPPRESSED                 -> OK
#   ares   the archive holds an uncited S50 RESOLVED (gated when archived)             -> out of scope
#   bound  pending.md's last entry is an uncited S50 SUPPRESSED, and the archive's preamble
#          carries an authorization line before its first header                        -> FAIL
#   adir   pending.md holds the genuine S50 SUPPRESSED; pending-archive.md is a DIRECTORY
#          -> REFUSED (rc 2); without the refusal the archive reads as absent and the run is OK
sup() { mkdir -p "$ROOT/sup/$1"; : > "$ROOT/sup/$1/$2"; }
sup bad pending.md;     entry "$ROOT/sup/bad/pending.md"     S50-WAIVE-1 SUPPRESSED "$CITE_FAKE"
sup good pending.md;    entry "$ROOT/sup/good/pending.md"    S50-WAIVE-2 SUPPRESSED "$CITE_REAL"
sup anyonly pending.md; entry "$ROOT/sup/anyonly/pending.md" S50-WAIVE-3 SUPPRESSED "$CITE_REAL"
sup anyres pending.md;  entry "$ROOT/sup/anyres/pending.md"  S50-WAIVE-3 RESOLVED   "$CITE_REAL"
sup apop pending.md;    entry "$ROOT/sup/apop/pending.md"    S49-OLD-3 RESOLVED
sup apop pending-archive.md; entry "$ROOT/sup/apop/pending-archive.md" S50-WAIVE-4 SUPPRESSED "$CITE_FAKE"
sup aabs pending-archive.md; entry "$ROOT/sup/aabs/pending-archive.md" S50-WAIVE-4 SUPPRESSED "$CITE_FAKE"
sup aemp pending.md; sup aemp pending-archive.md; entry "$ROOT/sup/aemp/pending-archive.md" S50-WAIVE-4 SUPPRESSED "$CITE_FAKE"
sup agood pending-archive.md; entry "$ROOT/sup/agood/pending-archive.md" S50-WAIVE-5 SUPPRESSED "$CITE_REAL"
sup ares pending.md;    entry "$ROOT/sup/ares/pending.md"    S49-OLD-4 RESOLVED
sup ares pending-archive.md; entry "$ROOT/sup/ares/pending-archive.md" S50-ITEM-9 RESOLVED
sup bound pending.md;   entry "$ROOT/sup/bound/pending.md"   S50-WAIVE-6 SUPPRESSED
printf '# Escalation archive\n**Operator authorization:** %s\n\n' "$CITE_REAL" > "$ROOT/sup/bound/pending-archive.md"
entry "$ROOT/sup/bound/pending-archive.md" S49-OLD-5 RESOLVED
sup adir pending.md;    entry "$ROOT/sup/adir/pending.md"    S50-WAIVE-7 SUPPRESSED "$CITE_REAL"
mkdir -p "$ROOT/sup/adir/pending-archive.md"

# --- SUPPRESSED entries IN FORCE whatever sprint their header names (BL-960 ruling (c)) -------------
# Each layout is a project ROOT of its own, because validate-suppression-lifetime.sh (the in-force
# predicate) resolves the timeline and the catalog from AI_DLC_PROJECT_ROOT, which every inf/ cell
# sets. Every root carries the same two-id catalog and the same two gates, both recorded after the
# 2026-07-12T03:00:00Z authorization the citations name, so an **Expires after:** 3 entry is in
# force (2 gates elapsed) and an **Expires after:** 1 entry has expired. The gate runs at --sprint 50.
#   ioff   pending.md: an S49 SUPPRESSED, in force, invented words        -> gate FAIL (now checked)
#   ioffg  pending.md: the same with the genuine turn                     -> gate OK, 1 checked
#   inone  pending.md: a header with no sprint token, in force, invented   -> gate FAIL
#   iarch  pending-archive.md: an S49 SUPPRESSED, in force, invented       -> gate FAIL
#   iexp   pending.md: an S49 SUPPRESSED, EXPIRED, invented                -> out of scope, gate OK
#   icur   pending.md: an S50 SUPPRESSED in force whose status line is a list item
#          (`- **Status:**`, read here as no status, by the sibling as SUPPRESSED), invented -> gate FAIL
#   icurg  the same with the genuine turn                                  -> gate OK, 1 checked
# sentry <file> <header-id> <expires> <auth> [<status-line prefix>]
sentry() {
  {
    printf '## %s Lead (gate [planning]) - 2026-07-12\n' "$2"
    printf '%s**Status:** SUPPRESSED\n' "${5:-}"
    printf '**Suppresses:** [core] 16 — the check this waiver covers\n'
    printf '**Expires after:** %s\n' "$3"
    printf '**Context:** a failing check was waived by the operator.\n'
    printf '**Decision/Question:** suppress or fix.\n'
    printf '**Operator authorization:** %s\n' "$4"
    printf '\n'
  } >> "$1"
}
inf() {
  mkdir -p "$ROOT/inf/$1/docs/escalations" "$ROOT/inf/$1/.claude/skills/ai-dlc" "$ROOT/inf/$1/_bmad-output/implementation-artifacts"
  printf 'checks:\n  - id: "16"\n  - id: "22"\n' > "$ROOT/inf/$1/.claude/skills/ai-dlc/enforcement-map.yaml"
  {
    printf '{"v": 1, "sprint": 49, "gate": "implementation", "ts": "2026-07-13T00:00:00Z", "catalog": "core", "check": "16", "verdict": "PASS"}\n'
    printf '{"v": 1, "sprint": 50, "gate": "implementation", "ts": "2026-07-14T00:00:00Z", "catalog": "core", "check": "22", "verdict": "PASS"}\n'
  } > "$ROOT/inf/$1/_bmad-output/implementation-artifacts/gate-metrics.jsonl"
  : > "$ROOT/inf/$1/docs/escalations/pending.md"
}
inf ioff;  sentry "$ROOT/inf/ioff/docs/escalations/pending.md"  S49-WAIVE-8 3 "$CITE_FAKE"
inf ioffg; sentry "$ROOT/inf/ioffg/docs/escalations/pending.md" S49-WAIVE-8 3 "$CITE_REAL"
inf inone; sentry "$ROOT/inf/inone/docs/escalations/pending.md" story-2.2 3 "$CITE_FAKE"
inf iarch; entry "$ROOT/inf/iarch/docs/escalations/pending.md" S49-OLD-6 RESOLVED
sentry "$ROOT/inf/iarch/docs/escalations/pending-archive.md" S49-WAIVE-9 3 "$CITE_FAKE"
inf iexp;  sentry "$ROOT/inf/iexp/docs/escalations/pending.md"  S49-WAIVE-10 1 "$CITE_FAKE"
inf icur;  sentry "$ROOT/inf/icur/docs/escalations/pending.md"  S50-WAIVE-11 3 "$CITE_FAKE" '- '
inf icurg; sentry "$ROOT/inf/icurg/docs/escalations/pending.md" S50-WAIVE-11 3 "$CITE_REAL" '- '

printf '%s\n' "$ROOT"
