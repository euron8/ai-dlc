#!/usr/bin/env bash
# Render docs/reviews/graph-ledger-adjudication-brief.md.
#
# RENDERED, NOT TYPED. Where a tool's output has to reach an operator intact,
# render it into a generated region and byte-compare with --check. A process that
# ends in a manual transcription step ends in a place where the transcription
# silently stops happening -- 39 of 115 ids in this program's own register were
# abbreviations of the real label before that was caught.
#
# Usage: render-brief.sh [--check]
set -u
cd /Users/n8/git/ai-dlc || exit 1

VER=$(cat VERSION)
DATE=2026-08-17
DD=docs/reviews/graph-ledger-adjudication-data
FD="$DD/final-disposition.tsv"
OUT="${AI_DLC_BRIEF_OUT:-docs/reviews/graph-ledger-adjudication-brief.md}"
RECEIPTS="$DD/replacement-receipts.tsv"
# THE STEP-12 FILING POPULATION, FROM THE REPO AND NOT FROM A SESSION SCRATCHPAD.
# This read used to be `"$SP"/step12/batch-*.tsv` against the authoring session's scratchpad --
# session-scoped by construction and unreachable from any later session. Nothing would have
# errored: this script sets `-u` but not `-e`, so a glob matching nothing feeds `awk` no files,
# the population derives to ZERO pins, and sections B, C and D all mis-partition while the
# arithmetic line at the end still prints a sum. The promoted file carries the same 59 pins --
# verified symmetric-difference EMPTY against the scratchpad copy while it still existed, with
# fields 1 and 3 differing by 67 and 118 as the control that the comparison discriminates.
POP="${AI_DLC_BRIEF_POP:-$DD/filing-population.tsv}"
TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT

ANN="**ADOPTED UPSTREAM (v${VER}, verified ${DATE})**"

# --- ARM 1: the rendered annotation must satisfy BOTH enforcers ---------------
printf '%s\n' "$ANN" | LC_ALL=C awk '/\*\*ADOPTED UPSTREAM \(v[0-9]/ {ok=1} END {exit !ok}' \
  || { echo "REFUSING: annotation fails ledger-rotate.sh's strict archive form" >&2; exit 2; }
printf '%s\n' "$ANN" | LC_ALL=C awk '/ADOPTED UPSTREAM/ {ok=1} END {exit !ok}' \
  || { echo "REFUSING: annotation fails ledger-reverify.sh's skip form" >&2; exit 3; }
# CONTROL: the versionless near-miss a human would write must FAIL the strict form
printf '%s\n' "**ADOPTED UPSTREAM (verified ${DATE})**" \
  | LC_ALL=C awk '/\*\*ADOPTED UPSTREAM \(v[0-9]/ {ok=1} END {exit !ok}' \
  && { echo "REFUSING: near-miss control PASSED the strict form; the arm does not discriminate" >&2; exit 4; }

# --- ARM 2: refuse to emit a brief that promises a section it lacks -----------
[ -e "$RECEIPTS" ] || { echo "REFUSING: $RECEIPTS absent. Section E would be promised and missing." >&2; exit 5; }

# --- ARM 3: refuse rather than partition 115 rows against an empty population --
[ -s "$POP" ] || { echo "REFUSING: $POP absent or empty. Sections B, C and D would all mis-partition and the arithmetic line would still print a sum." >&2; exit 6; }

# --- the annotation version is PER ROW, and this used to be ONE STRING FOR ALL --
#
# THE DEFECT THIS REPLACES. `ANN` above was rendered once, from $VER, and the brief instructed it
# be pasted into every entry in sections A and B -- 57 of them. But 34 section-A rows are
# adjudicated `ALREADY-FIXED-v<X>` across 29 distinct versions from v0.21.0 to v0.372.0, and NOT
# ONE is adjudicated at $VER (control: `grep -c 'ALREADY-FIXED-v0.373.0'` over the brief returned
# 0 while `ALREADY-FIXED-v` returned 34 in the same invocation). A literal application therefore
# stamped v0.373.0 as permanent provenance onto an entry this same brief adjudicates as fixed in
# v0.21.0.
#
# `absorbed_at()`'s own header states the cost and was written about exactly this failure: "that
# annotation is permanent: the ledger entry is the provenance of an upstreamed change, and retro
# and the §8.1 fan-in read it." This renderer re-introduced at the HUMAN layer the bug that
# function fixed at the machine layer.
#
# AND ARM 1 COULD NOT SEE IT. Arm 1 tests the generated string against both enforcers and against
# the versionless near-miss. Both enforcers check only the FORM -- bold, a digit immediately after
# the `v`. Neither can check whether the version is TRUE for the entry it lands on. Arm 1 proved
# the string well-formed; nothing proved it correct. ARM 4 below is the missing half, and it reads
# the RENDERED OUTPUT rather than this map, because a check over the map would be a tautology --
# the map is derived from the verdict, so it cannot disagree with it.
#
# THE MAPPING, and every case is present in the corpus today:
#   ALREADY-FIXED-v<X>  -> <X>            the release that shipped the fix. 34 rows in A, 6 in B.
#   ALREADY-FIXED-<sha> -> resolve FORWARD to the earliest commit at or after <sha> that CHANGES
#                          VERSION, and read VERSION there. One row: pin 1125 at `93e05d3`, whose
#                          own VERSION blob reads 0.102.0 because a fix lands while VERSION still
#                          holds the previous number -- the bump arrives later, in the release
#                          commit. Forward-walking resolves it to v0.103.0. Control, in the same
#                          invocation: the same walk from `e939a92~1` lands on `e939a92` itself,
#                          so a commit that IS its own release resolves to itself.
#   anything else       -> $VER. FALSIFIED and DUPLICATE-OF close no absorption, so no absorbing
#                          release exists; $VER is the release that RECORDED the refutation or
#                          cited the dropped id. Section B's HOLDS-family rows are withdrawals on
#                          the same footing.
LC_ALL=C awk -F'\t' -v V="$VER" '
  { v = V
    if      ($3 ~ /^ALREADY-FIXED-v[0-9]/) v = substr($3, 16)
    else if ($3 ~ /^ALREADY-FIXED-.+/)     v = "@" substr($3, 15)
    printf "%s\t%s\n", $1, v }
' "$FD" > "$TMP/annot_raw"

: > "$TMP/annot"
while IFS="$(printf '\t')" read -r _pin _v; do
  case "$_v" in
    @*) _sha="${_v#@}"
        _rc="$(git log --reverse --format=%H "${_sha}..HEAD" -- VERSION 2>/dev/null | head -1)"
        _v="$(git show "${_rc}:VERSION" 2>/dev/null | tr -d '[:space:]')"
        ;;
  esac
  case "$_v" in
    ''|@*) echo "REFUSING: pin $_pin has no resolvable annotation version. A row with no version renders an annotation the rotator cannot archive." >&2; exit 7 ;;
  esac
  printf '%s\t%s\n' "$_pin" "$_v" >> "$TMP/annot"
done < "$TMP/annot_raw"

[ "$(wc -l < "$TMP/annot" | tr -d ' ')" = "$(wc -l < "$FD" | tr -d ' ')" ] \
  || { echo "REFUSING: the annotation map does not cover every disposition row." >&2; exit 7; }

# --- data prep ----------------------------------------------------------------
LC_ALL=C awk -F'\t' '{print $2}' "$POP" | sort -u > "$TMP/pop"
[ -s "$TMP/pop" ] || { echo "REFUSING: the step-12 population derived to zero pins from $POP" >&2; exit 6; }

# every pin each new backlog entry cites -> pin<TAB>BL
LC_ALL=C awk '
  /^## BL-[0-9]+/ { if (id!="") emit(); id=$2; n=id; gsub(/BL-0*/,"",n); keep=(n+0>=21); body=""; next }
  id!="" { body = body " " $0 }
  END { if (id!="") emit() }
  function emit(   b,s) {
    if (!keep) return
    b=body; gsub(/[ \t]+/," ",b)
    while (match(b, /pinned ledger line[s]? [0-9]+/)) {
      s=substr(b,RSTART,RLENGTH); gsub(/[^0-9]/,"",s)
      printf "%s\t%s\n", s, id
      b=substr(b,RSTART+RLENGTH)
    }
  }
' docs/backlog.md | sort -u > "$TMP/pin2bl_all"
LC_ALL=C awk -F'\t' 'NR==FNR{p[$1];next} ($1 in p)' "$TMP/pop" "$TMP/pin2bl_all" > "$TMP/pin2bl"
LC_ALL=C awk -F'\t' '{print $1}' "$TMP/pin2bl" | sort -u > "$TMP/filed_pins"

n_close=$(LC_ALL=C awk -F'\t' '$5 ~ /^CLOSE/' "$FD" | wc -l | tr -d ' ')
n_filed=$(wc -l < "$TMP/filed_pins" | tr -d ' ')
n_entries=$(LC_ALL=C awk -F'\t' '{print $2}' "$TMP/pin2bl" | sort -u | wc -l | tr -d ' ')
n_withdrawn=$(( $(wc -l < "$TMP/pop" | tr -d ' ') - n_filed ))
n_notup=$(LC_ALL=C awk -F'\t' 'NR==FNR{p[$1];next} $5 ~ /LIVE/ && !($1 in p)' "$TMP/pop" "$FD" | wc -l | tr -d ' ')
n_rcpt=$(LC_ALL=C awk -F'\t' 'NR>1' "$RECEIPTS" | wc -l | tr -d ' ')

# --- section F: the entries graph filed AFTER the corpus pin -----------------------------------
# They are deliberately NOT in final-disposition.tsv. Step 12's population was derived from the
# pin -- the ledger's first 4356 lines -- so every derivation downstream inherited that boundary,
# and the coverage proof confirming all 59 population rows were accounted for was CORRECT and
# structurally blind to these three. WHEN A POPULATION IS DERIVED FROM A PINNED SNAPSHOT, ASK
# SEPARATELY WHAT THE PIN EXCLUDED; a complete-looking coverage proof over the population cannot
# see outside it. Rendering them here keeps them out of the 115-row partition and still in the
# brief.
POSTPIN="$DD/post-pin-verdicts.tsv"
[ -s "$POSTPIN" ] || { echo "REFUSING: $POSTPIN absent or empty; the post-pin entries would be silently dropped from the brief." >&2; exit 7; }
LC_ALL=C awk -F'\t' '{print $1}' "$POSTPIN" | sort -un > "$TMP/pp_pins"
n_pp=$(wc -l < "$TMP/pp_pins" | tr -d ' ')
# Join each post-pin line to the BL- entry citing it. THE BODY IS FLATTENED FIRST: `line 4357,
# past the 4356-line pin` wraps across lines in this hard-wrapped file, and a single-line match
# reports every one of them missing -- measured, on this exact corpus, as an 18-of-42 finding that
# was entirely an artefact of the instrument's shape.
LC_ALL=C awk '
  NR==FNR { want[$1]=1; next }
  /^## BL-[0-9]+/ { if (id!="") emit(); id=$2; body=""; next }
  id!="" { body = body " " $0 }
  END { if (id!="") emit() }
  function emit(   b,p) {
    b=body; gsub(/[ \t]+/, " ", b)
    for (p in want) if (b ~ ("(^|[^0-9])" p "([^0-9]|$)")) printf "%s\t%s\n", p, id
  }
' "$TMP/pp_pins" docs/backlog.md | sort -un > "$TMP/pp2bl"
n_pp_joined=$(LC_ALL=C awk -F'\t' '{print $1}' "$TMP/pp2bl" | sort -u | wc -l | tr -d ' ')
if [ "$n_pp_joined" != "$n_pp" ] || [ "$(wc -l < "$TMP/pp2bl" | tr -d ' ')" != "$n_pp" ]; then
  echo "REFUSING: $n_pp post-pin entry(ies) but $n_pp_joined resolved to exactly one BL- entry each:" >&2
  cat "$TMP/pp2bl" >&2; exit 7
fi
# CONTROL, same invocation: an impossible pin must join to nothing. Captured into a variable
# rather than piped into `grep -q` -- that reader exits at its first match while the writer is
# still pushing, and the writer's EPIPE then reports NOT-FOUND on input that did match.
ctl=$(LC_ALL=C awk '
  /^## BL-[0-9]+/ { if (id!="") emit(); id=$2; body=""; next }
  id!="" { body = body " " $0 }
  END { if (id!="") emit() }
  function emit(   b) { b=body; gsub(/[ \t]+/," ",b); if (b ~ /(^|[^0-9])9999109([^0-9]|$)/) print id }
' docs/backlog.md)
if [ -n "$ctl" ]; then
  echo "REFUSING: the post-pin join control matched an impossible line number, so the join does not discriminate" >&2
  exit 7
fi

{
cat <<HDR
# Consumer brief — the graph push-candidate ledger, fully adjudicated

**THIS FILE IS RENDERED. Do not hand-edit it.** Change the data under
\`graph-ledger-adjudication-data/\` and re-run the renderer; the annotation strings below are
generated and were tested against the two enforcers that read them, not transcribed.

## What this is, and who applies it

Upstream (\`ai-dlc\`) adjudicated all **115** open entries in
\`_bmad-output/ai-dlc-update/push-candidate-ledger.md\`, plus the 3 filed after the corpus pin,
against the working tree — entry by entry, with a control in the same invocation for every
absence-shaped claim. This brief is the result.

**graph applies it. The ai-dlc session that produced it did not write here and must not.**

Nothing below asks you to take upstream's word for it; every row names its evidence and where
it lives. Where upstream was wrong, that is stated in the row rather than quietly corrected.

## The annotation, rendered PER ENTRY

**There is no single string to paste, and an earlier revision of this brief said there was.**
That revision rendered one annotation from the version being pulled and instructed it into all
${n_close} + ${n_withdrawn} entries of sections A and B. But most of those entries were absorbed
YEARS of releases earlier, and the version in this annotation is permanent provenance: it is what
retro and the §8.1 fan-in read back. Stamping the pulled version onto an entry fixed in v0.21.0
records an absorption that never happened at a release that never made it.

**So each row in sections A and B carries its OWN paste-ready string, in its own column.** Paste
that row's string, byte for byte. Do not compose one from the version column, and do not reuse a
neighbouring row's.

**The form is load-bearing in two directions and a sloppy paste breaks both.**
\`ledger-reverify.sh\` treats *any* occurrence of \`ADOPTED UPSTREAM\` in an entry as closed and
SKIPS it. But \`ledger-rotate.sh:143\` archives only on the strict \`/\*\*ADOPTED UPSTREAM \(v[0-9]/\`
— bold, with a digit immediately after the \`v\`. So an entry annotated
\`**ADOPTED UPSTREAM (verified ${DATE})**\`, carrying no version, becomes **invisible AND
unarchivable**: it stops being reported and never leaves the live file.

That exact near-miss is the control this renderer runs against itself. It refuses to emit if the
string it generated fails the strict form, and equally if the versionless near-miss PASSES —
an arm that accepts both is not discriminating between them.

## The five sections, and the arithmetic that closes over them

| section | what | rows |
|---|---|---|
| A | CLOSE — absorbed, falsified or duplicate | ${n_close} |
| B | WITHDRAW — filed by graph, premise dead on re-derivation | ${n_withdrawn} |
| C | LIVE, now tracked upstream as a \`BL-\` entry | ${n_filed} |
| D | LIVE, consumer-local — no upstream grain fits | ${n_notup} |
| E | replacement \`verify:\` receipts for undecidable and absent directives | ${n_rcpt} |
| F | filed after the corpus pin — LIVE, tracked upstream | ${n_pp} |

Sections A–D partition the 115 exactly: ${n_close} + ${n_withdrawn} + ${n_filed} + ${n_notup}.
Section E cuts across C and D — those entries stay open AND get a working receipt.

**Section F sits OUTSIDE that partition, and the reason matters more than the three rows.** The
115 came from a corpus pinned at this ledger's first 4356 lines, so every derivation downstream
inherited that boundary — including the coverage proof that confirmed all 59 filing rows were
accounted for. That proof was correct and could not see these three, because they were filed above
the pin. A complete-looking coverage proof over a derived population cannot see outside it; the
question that found them was a different one — *do any upstream entries cite a pin above 4356?*

**Section C is ${n_filed} consumer rows but ${n_entries} upstream entries**, because one row
drew two. Do not read the counts as interchangeable; that conflation produced a wrong
withdrawal figure in this program once already, and it was caught only because 59 minus 42 did
not equal the number of rows actually left uncovered.

HDR

# ---------- A ----------
printf '## A — CLOSE (%s)\n\n' "$n_close"
cat <<'AH'
Adjudicated absorbed, falsified, or duplicate. Annotate each, and the rotator will archive them.

**Half the proposed closes did not survive refutation.** 48 were proposed; 24 confirmed, 15
narrowed to a headline plus a live sub-claim no other entry owns, and 9 refuted outright and
returned to the live set — they are in sections C and D, not here. A false close retires a live
defect and is indistinguishable from an ordinary absorption, which is why no close here rests on
a single reading.

Every one of the 15 narrowed closes was GATED: its surviving sub-claim had to be filed upstream
BEFORE the parent could close, so that closing it could not delete the only written record of a
live defect.

`changelog-cite` rows also appear verbatim in a release commit MESSAGE, so `named_absorbed()`
resolves them and your next reconcile emits a `NAMED-UPSTREAM` row independently of this brief.
`brief-annotation` rows CANNOT — `flush()` gates on `has_verify &&` and they carry no receipt —
so for those **this annotation is the only closing channel**.

| pin | entry | verdict | channel | paste this, byte for byte |
|---|---|---|---|---|
AH
LC_ALL=C awk -F'\t' -v A="$TMP/annot" -v D="$DATE" '
  BEGIN { while ((getline l < A) > 0) { split(l, t, "\t"); av[t[1]] = t[2] } }
  $5 ~ /^CLOSE/ {
    lbl=$2; if (length(lbl)>62) lbl=substr(lbl,1,59) "..."
    printf "| %s | `%s` | %s | %s | `**ADOPTED UPSTREAM (v%s, verified %s)**` |\n", \
      $1, lbl, $3, $7, av[$1], D
  }' "$FD" | sort -t'|' -k2 -n

# ---------- B ----------
printf '\n## B — WITHDRAW (%s)\n\n' "$n_withdrawn"
cat <<'BH'
These were filed by graph and re-derived upstream against the working tree. Each is either
already fixed, or its premise is false, or its subject is a settled decision rather than a
defect. **Annotate them by the same rule as section A — each row's OWN string, from its own
column.** Not section A's strings, and not one string across the section; that conflation is the
defect the previous revision of this brief shipped.

**Most rows here are annotated at the pulled version and that is correct, not a relapse.** A
`HOLDS`-family, `FALSIFIED` or `DUPLICATE-OF` verdict names no absorbing release because nothing
was absorbed — the premise died on re-derivation — so the version records the release that
ADJUDICATED the withdrawal. The rows verdicted `ALREADY-FIXED-v<X>` carry `<X>` instead, and the
renderer refuses if any of them disagrees.

The measured base rate of expired premises in this corpus is roughly one in two; this pass came
in lower. A filing that cannot be substantiated is worse than none, so these are a normal
outcome, not a failure of the original filings.

**The evidence is in `graph-ledger-adjudication-data/step12-withdrawals.md`**, in each
adjudicator's own words, with the controls each ran. Read it before retiring any row you disagree
with — one entry here was independently confirmed dead by a hand that did not know the operator
had already ruled it retired.

| pin | entry | verdict | paste this, byte for byte |
|---|---|---|---|
BH
LC_ALL=C awk -F'\t' -v F="$TMP/filed_pins" -v P="$TMP/pop" -v A="$TMP/annot" -v D="$DATE" '
  BEGIN { while ((getline l < F) > 0) f[l]=1; while ((getline l < P) > 0) pop[l]=1
          while ((getline l < A) > 0) { split(l, t, "\t"); av[t[1]] = t[2] } }
  $5 ~ /LIVE/ && ($1 in pop) && !($1 in f) {
    lbl=$2; if (length(lbl)>62) lbl=substr(lbl,1,59) "..."
    printf "| %s | `%s` | %s | `**ADOPTED UPSTREAM (v%s, verified %s)**` |\n", \
      $1, lbl, $3, av[$1], D
  }
' "$FD" | sort -t'|' -k2 -n

# ---------- C ----------
printf '\n## C — LIVE, tracked upstream (%s rows, %s entries)\n\n' "$n_filed" "$n_entries"
cat <<'CH'
These reproduced against the working tree. Upstream filed each as a `BL-` entry in its own
`docs/backlog.md`, carrying the re-derived measurement, the correction where the original filing
was wrong about its own mechanism, and a `verify:` receipt that was RUN and exits non-zero today.

**Leave these open in your ledger.** They close when upstream ships the fix and cites the id.

51 of these carried no promoted evidence, so each was a fresh derivation rather than a
transcription — and the filings were frequently wrong about their own mechanism in a way that
changed the remediation's SCOPE, not merely its wording.

| pin | entry | verdict | upstream |
|---|---|---|---|
CH
LC_ALL=C awk -F'\t' -v P="$TMP/pin2bl" '
  BEGIN { while ((getline l < P) > 0) { split(l,a,"\t"); bl[a[1]] = (bl[a[1]]=="" ? a[2] : bl[a[1]] ", " a[2]) } }
  $5 ~ /LIVE/ && ($1 in bl) {
    lbl=$2; if (length(lbl)>56) lbl=substr(lbl,1,53) "..."
    printf "| %s | `%s` | %s | `%s` |\n", $1, lbl, $3, bl[$1]
  }
' "$FD" | sort -t'|' -k2 -n

# ---------- D ----------
printf '\n## D — LIVE, consumer-local (%s)\n\n' "$n_notup"
cat <<'DH'
No upstream grain fits these: the subject is graph's own forked `scripts/`, or a retirement probe
over machinery core has never shipped. **There is no upstream work and none is coming.** Keep or
retire them on your own judgement — but they should not sit in a queue labelled "upstream owes
this", because upstream does not.

One entry here is a standing operator RULING rather than an adjudication:
`PC-S297-LOCKED-ANCHOR-VALIDATOR-VACUOUS` is retired because the exemption is correct by design.
`validate-locked-anchor.sh:16-18` scopes the byte-match to a `full_text_source:` full-text claim,
and `:20-26` records that a `requires_context:` load pointer IS resolved for existence.
Byte-matching a load pointer would fail honest cite-by-reference.

| pin | entry | verdict |
|---|---|---|
DH
LC_ALL=C awk -F'\t' -v P="$TMP/pop" '
  BEGIN { while ((getline l < P) > 0) pop[l]=1 }
  $5 ~ /LIVE/ && !($1 in pop) {
    lbl=$2; if (length(lbl)>62) lbl=substr(lbl,1,59) "..."
    printf "| %s | `%s` | %s |\n", $1, lbl, $3
  }
' "$FD" | sort -t'|' -k2 -n

# ---------- E ----------
printf '\n## E — replacement `verify:` receipts (%s)\n\n' "$n_rcpt"
cat <<'EH'
**Two classes of entry are in here, and neither can ever be closed by the directive it carries
today.** Most carry a `verify: theirs_has <substring>` whose substring is present at BASE as well
as at theirs, so the reverifier reports:

> `RECEIPTS-UNDECIDED … reported STILL-LIVE on a substring present at BASE as well as at theirs`

A predicate that matches in both states distinguishes nothing. It will report "still open"
forever, whether or not the defect is ever fixed — and `ledger-reverify-unfalsifiable/README.md`
measures 13 such entries on this consumer already.

The rest carry **no directive at all**, which is worse and much quieter: `flush()` gates on
`has_verify &&`, so those entries produce no row in any reverify report. They are not reported as
open, or as closed, or as needing review. They are simply invisible to the closer, and a zero
CLOSE-CANDIDATE count over a corpus containing them means nothing.

Each replacement below is anchored on a token the fix MUST add or remove — a flag, a path, a
function name, an emitted string, an observable behaviour — never on prose describing the fix.

**Every one was RUN, and every `sh` receipt exits 0 today. Zero is the requirement, not the
failure.** Your engine's `sh` dispatch reads `rc=0` as **STILL-LIVE** and a non-zero as
**CLOSE-CANDIDATE** — read it at the emitter in `ledger-reverify.sh`, because its own file header
reads the other way and this program briefed four authors from the header before catching it.
So a receipt here that exits non-zero is proposing to retire a live defect. If you carry a habit
from a `docs/backlog.md`-shaped tool, note that those read the OPPOSITE sense.

**Every `sh` receipt below guards its own subject to exit 127** when a path, span or extraction
cannot be resolved, which your engine reports as NEEDS-REVIEW rather than as a close. That guard
is not decoration: measured on this consumer, ONE relocation commit moved five receipt subjects
and all five flipped to CLOSE-CANDIDATE in a single run, every one still reproducing at its new
path. Where a row's note says the guard is absent, treat any future non-zero from it as
unverified until you have confirmed the subject still resolves.

Three anchor failures this program measured, all of which recur, and which each replacement was
checked against: an anchor on text the FIX QUOTES BACK (fixes here document what they removed, so
the anchor survives in the comment recording the change); an anchor on a phrasing the FILING
INVENTED rather than one the code uses; and an anchor on a word the fix's own closing clause also
contains, which returns rc=0 against the defect itself.

**Replace the whole `verify:` line.** Paste each `new` verbatim — they were tested as written,
and the engine runs them through `eval`, so quoting is part of the predicate.

EH
LC_ALL=C awk -F'\t' 'NR>1 {
  printf "### pin %s — `%s`\n\n", $1, $2
  if ($3 ~ /^verify: \(absent/)
    printf "OLD — **none**. No directive, so the closer emits no row for this entry at all:\n\n```\n%s\n```\n\n", $3
  else
    printf "OLD (undecidable — the substring matches at BASE too):\n\n```\n%s\n```\n\n", $3
  if ($5 == "n/a")
    printf "NEW (no mechanical predicate exists — reported as HAND-REVIEW):\n\n```\n%s\n```\n\n", $4
  else
    printf "NEW (measured `rc=%s` today, which is STILL-LIVE):\n\n```\n%s\n```\n\n", $5, $4
  if ($6 != "") printf "%s\n\n", $6
}' "$RECEIPTS"

# ---------- F ----------
printf '\n## F — filed after the corpus pin (%s)\n\n' "$n_pp"
cat <<'FH'
These three were filed into this ledger AFTER upstream pinned the corpus, so they are not part of
the 115 and appear in no table above. All three were adjudicated against the working tree on the
same terms as the rest, all three are `HOLDS`-family — **3 for 3 on the base rate that a filing
understates or misstates its own mechanism** — and all three are now tracked upstream.

**Leave these open in your ledger.** They close when upstream ships the fix and cites the id.

Two of the three carried no `verify:` directive at all, so your closer emits no row for them; their
replacement receipts are in section E. One thing to note about the upstream receipts backing them:
they exit NON-zero while the defect is live, which is the opposite of the receipts in section E.
That is not an inconsistency — `docs/backlog.md` is read by a different engine
(`scripts/backlog-reverify.sh`) whose `sh` polarity is inverted relative to yours. Do not carry a
receipt across the boundary without re-reading its engine's dispatch.

| live line | entry | verdict | upstream |
|---|---|---|---|
FH
LC_ALL=C awk -F'\t' -v P="$TMP/pp2bl" '
  BEGIN { while ((getline l < P) > 0) { split(l, a, "\t"); bl[a[1]] = a[2] } }
  {
    lbl=$2; if (length(lbl)>56) lbl=substr(lbl,1,53) "..."
    printf "| %s | `%s` | %s | `%s` |\n", $1, lbl, $3, bl[$1]
  }
' "$POSTPIN" | sort -t'|' -k2 -n

printf '\n'
cat <<'TAIL'
## Evidence, and where to check any of it

- `graph-ledger-full-adjudication.md` — the register: method, controls, cross-cutting findings,
  and the 115-row verdict table.
- `graph-ledger-adjudication-data/phase1-verdicts.tsv` — 115 rows, one per open entry.
- `.../refutation-verdicts.tsv` — 48 rows, one per attacked close, with why it survived or fell.
- `.../final-disposition.tsv` — the merge. Sections A–D render from it.
- `.../step12-withdrawals.md` — section B's evidence, in each adjudicator's own words.
- `.../replacement-receipts.tsv` — section E's data.
- `CHANGELOG.md` — one `###` section per closed id.

## One thing upstream got wrong, stated plainly

The plan driving this work asserted for its entire life that citing a closed id in `CHANGELOG.md`
would produce a `NAMED-UPSTREAM` row. **It does not.** `named_absorbed()` resolves that signal
with `git log -F --grep`, which reads COMMIT MESSAGES; a CHANGELOG section is in the commit's
DIFF and never its message. Measured over the 29 citable ids, both channels in one invocation: 4
appeared in a message, 8 in the CHANGELOG blob, 16 in neither — and the four sitting in the
CHANGELOG and not in a message were cited exactly as prescribed and resolved to nothing.

Every id closed in this release is therefore in the release commit MESSAGE as well. Measured
before and after: 9 of 29 resolved before, 29 of 29 after, with an impossible-id control at 0
throughout.
TAIL
} > "$OUT.tmp"

# --- ARM 4: no rendered annotation may contradict its own row's verdict --------
#
# READS THE EMITTED ARTIFACT, NOT THE MAP. A check over $TMP/annot would be a tautology: the map
# is derived from the verdict column, so it cannot disagree with it. This reads the rendered table
# rows, where the two values arrive by different paths -- the verdict is printed straight from
# field 3 and the annotation is printed from a joined lookup -- so a mis-joined key, a shifted
# column or a revert to one shared string all show up here as a disagreement.
#
# SCOPE. It fires only on rows whose verdict NAMES a version (`ALREADY-FIXED-v<X>`). A FALSIFIED,
# DUPLICATE-OF or HOLDS row names none, so there is nothing to contradict and the arm is silent on
# them by construction rather than by exemption.
#
# PROVEN TO FIRE, BOTH DIRECTIONS, before it shipped: seeding one row's annotation with the pulled
# version instead of its adjudicated one -- which is exactly what the previous revision emitted for
# all 57 -- makes this refuse and name the pin; the unmutated render passes. A control that only
# ever passes is the shape this whole arm exists to replace.
_bad="$(LC_ALL=C awk '
  /^\| [0-9]+ \|/ && /ALREADY-FIXED-v/ {
    v = ""; a = ""
    if (match($0, /ALREADY-FIXED-v[0-9][0-9.]*/))     v = substr($0, RSTART+15, RLENGTH-15)
    if (match($0, /ADOPTED UPSTREAM \(v[0-9][0-9.]*/)) a = substr($0, RSTART+19, RLENGTH-19)
    if (v != "" && a != "" && v != a) { split($0, c, "|"); printf "  pin %s: verdict says v%s, annotation says v%s\n", c[2], v, a }
  }' "$OUT.tmp")"
if [ -n "$_bad" ]; then
  printf 'REFUSING: a rendered annotation contradicts its own row.\n%s\n' "$_bad" >&2
  rm -f "$OUT.tmp"; exit 8
fi
# CONTROL: the arm must have had rows to inspect. A zero over an empty scan is not a pass.
_seen="$(LC_ALL=C grep -cE '^\| [0-9]+ \|.*ALREADY-FIXED-v' "$OUT.tmp" || true)"
[ "${_seen:-0}" -gt 0 ] \
  || { echo "REFUSING: ARM 4 inspected NO version-bearing rows, so its silence establishes nothing." >&2; rm -f "$OUT.tmp"; exit 8; }

if [ "${1:-}" = "--check" ]; then
  if cmp -s "$OUT.tmp" "$OUT"; then echo "ok: brief matches the data"; rm -f "$OUT.tmp"; exit 0
  else echo "DRIFT: $OUT does not match a fresh render" >&2; rm -f "$OUT.tmp"; exit 1; fi
fi
mv "$OUT.tmp" "$OUT"
echo "rendered $OUT ($(wc -l < "$OUT") lines)"
printf '  A=%s  B=%s  C=%s rows/%s entries  D=%s  E=%s\n' "$n_close" "$n_withdrawn" "$n_filed" "$n_entries" "$n_notup" "$n_rcpt"
printf '  partition check: %s + %s + %s + %s = %s (must be 115)\n' \
  "$n_close" "$n_withdrawn" "$n_filed" "$n_notup" "$((n_close+n_withdrawn+n_filed+n_notup))"
