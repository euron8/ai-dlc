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
OUT=docs/reviews/graph-ledger-adjudication-brief.md
SP=/private/tmp/claude-501/-Users-n8-git-ai-dlc/bf4b7a9b-7e21-4470-bb51-dcacf2a4f138/scratchpad
RECEIPTS="$DD/replacement-receipts.tsv"
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

# --- data prep ----------------------------------------------------------------
LC_ALL=C awk -F'\t' '{print $2}' "$SP"/step12/batch-*.tsv | sort -u > "$TMP/pop"

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

## The annotation, rendered once

Paste this string, **byte for byte**, into each entry in sections A and B:

\`\`\`
${ANN}
\`\`\`

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
| E | replacement \`verify:\` receipts for undecidable directives | ${n_rcpt} |

Sections A–D partition the 115 exactly: ${n_close} + ${n_withdrawn} + ${n_filed} + ${n_notup}.
Section E cuts across C and D — those entries stay open AND get a working receipt.

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

| pin | entry | verdict | channel |
|---|---|---|---|
AH
LC_ALL=C awk -F'\t' '$5 ~ /^CLOSE/ {
  lbl=$2; if (length(lbl)>62) lbl=substr(lbl,1,59) "..."
  printf "| %s | `%s` | %s | %s |\n", $1, lbl, $3, $7
}' "$FD" | sort -t'|' -k2 -n

# ---------- B ----------
printf '\n## B — WITHDRAW (%s)\n\n' "$n_withdrawn"
cat <<'BH'
These were filed by graph and re-derived upstream against the working tree. Each is either
already fixed, or its premise is false, or its subject is a settled decision rather than a
defect. **Annotate them exactly as section A.**

The measured base rate of expired premises in this corpus is roughly one in two; this pass came
in lower. A filing that cannot be substantiated is worse than none, so these are a normal
outcome, not a failure of the original filings.

**The evidence is in `graph-ledger-adjudication-data/step12-withdrawals.md`**, in each
adjudicator's own words, with the controls each ran. Read it before retiring any row you disagree
with — one entry here was independently confirmed dead by a hand that did not know the operator
had already ruled it retired.

| pin | entry | verdict |
|---|---|---|
BH
LC_ALL=C awk -F'\t' -v F="$TMP/filed_pins" -v P="$TMP/pop" '
  BEGIN { while ((getline l < F) > 0) f[l]=1; while ((getline l < P) > 0) pop[l]=1 }
  $5 ~ /LIVE/ && ($1 in pop) && !($1 in f) {
    lbl=$2; if (length(lbl)>62) lbl=substr(lbl,1,59) "..."
    printf "| %s | `%s` | %s |\n", $1, lbl, $3
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
**These receipts can never go green, and your own tool says so.** Each entry below carries a
`verify: theirs_has <substring>` whose substring is present at BASE as well as at theirs, so the
reverifier reports:

> `RECEIPTS-UNDECIDED … reported STILL-LIVE on a substring present at BASE as well as at theirs`

A predicate that matches in both states distinguishes nothing. It will report "still open"
forever, whether or not the defect is ever fixed — and `ledger-reverify-unfalsifiable/README.md`
measures 13 such entries on this consumer already.

Each replacement below is anchored on a token the fix MUST add or remove — a flag, a path, a
function name — never on prose describing the fix. **Every one was RUN and exits non-zero today**,
which is the requirement: the defect is live, so a receipt exiting 0 now is already broken.

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
  printf "OLD (undecidable):\n\n```\n%s\n```\n\n", $3
  printf "NEW (exits %s today):\n\n```\n%s\n```\n\n", $5, $4
  if ($6 != "") printf "%s\n\n", $6
}' "$RECEIPTS"

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

if [ "${1:-}" = "--check" ]; then
  if cmp -s "$OUT.tmp" "$OUT"; then echo "ok: brief matches the data"; rm -f "$OUT.tmp"; exit 0
  else echo "DRIFT: $OUT does not match a fresh render" >&2; rm -f "$OUT.tmp"; exit 1; fi
fi
mv "$OUT.tmp" "$OUT"
echo "rendered $OUT ($(wc -l < "$OUT") lines)"
printf '  A=%s  B=%s  C=%s rows/%s entries  D=%s  E=%s\n' "$n_close" "$n_withdrawn" "$n_filed" "$n_entries" "$n_notup" "$n_rcpt"
printf '  partition check: %s + %s + %s + %s = %s (must be 115)\n' \
  "$n_close" "$n_withdrawn" "$n_filed" "$n_notup" "$((n_close+n_withdrawn+n_filed+n_notup))"
