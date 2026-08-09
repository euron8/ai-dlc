#!/usr/bin/env bash
# Seed for the push-candidate ledger closer (reconcile/ledger-reverify.sh).
#
# Builds a throwaway DISTRIBUTION git repo with a `base` and a `theirs` commit, and a
# consumer root whose ledger has three OPEN-looking entries that differ ONLY in what
# `theirs` contains:
#
#   Entry A  verify: theirs_lacks … "MARKER_A"  — theirs STILL lacks it  -> STILL-LIVE
#   Entry B  verify: theirs_lacks … "MARKER_B"  — theirs ADDED it        -> CLOSE-CANDIDATE
#   Entry C  same verify as B, but annotated ADOPTED UPSTREAM            -> skipped (closed)
#
# A and B carry IDENTICAL verify directives except the substring; the only reason they
# classify differently is what `theirs` holds. A closer that reads `base` (not `theirs`)
# sees neither marker and calls BOTH still-live — which is the mutation the fixture catches.
#
# Usage: seed.sh   -> prints "<dist> <base> <consumer> <theirs>" on one line.
set -eu

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ledger-reverify-XXXXXX")"
DIST="$TMP/dist"
CONS="$TMP/consumer"
mkdir -p "$DIST" "$CONS"

git -C "$DIST" init -q
git -C "$DIST" config user.email seed@fixture
git -C "$DIST" config user.name seed

mkdir -p "$DIST/core/skills/ai-dlc" "$DIST/core/scripts"
SK="$DIST/core/skills/ai-dlc/SKILL.md"

# `SKILL.md` is UNIQUE in this tree — that is what lets a consumer-namespace path resolve by
# basename. `validate-thing.sh` is DELIBERATELY duplicated across two directories so the
# ambiguous case has something to be ambiguous about: the fallback must refuse to guess when
# a basename matches more than one file, not pick the first.
printf '#!/bin/sh\necho thing\n' > "$DIST/core/scripts/validate-thing.sh"
printf '#!/bin/sh\necho thing\n' > "$DIST/core/skills/ai-dlc/validate-thing.sh"

# --- pre-base: THE ABSORPTION COMMIT, DELIBERATELY BEFORE base ---
#
# `named_absorbed()` searches history reachable from THEIRS, not `BASE..THEIRS`, and this commit
# is what makes that difference testable. On the reference consumer every measured absorption
# predated the pull's own base, so a bounded search fires on exactly one pull and then goes
# silent forever if the operator missed it. Placing the naming commit before base means a
# mutant that re-bounds the search loses the row, and nothing else changes.
#
# The message also names Entry A's PROSE label verbatim. That is the id-shape guard's control:
# a label is whatever precedes the first em dash, and for a bullet with no em dash that is its
# whole bold title. Feeding prose to `git log --grep` matches by common words, so the guard must
# refuse a label that is not id-shaped even when the history genuinely contains those words.
printf '# SKILL\nrule one\n' > "$SK"
printf '0.099.0\n' > "$DIST/VERSION"
git -C "$DIST" add -A
git -C "$DIST" commit -q -m 'feat(v0.099.0): land two consumer-filed entries' \
  -m 'Absorbs PC-FIXTURE-NAMED-BUT-RECEIPT-STUCK and PC-FIXTURE-NAMED-MANUAL.' \
  -m 'Prose-guard control: this line says Entry A still lacked upstream. verbatim.' \
  -m 'PC-S901 and PC-S902 also land here.'

# THE SHORT-ID COMMITS. Upstream cites `PC-S<n>`, never the full slug -- measured against it at
# 0.328.0, the slug search found 20 of 128 ledger entries while 20 of 29 prefixes appeared. The
# message above therefore names PC-S901 and PC-S902 and NOT their slugs, which is the shape the
# join was blind to. PC-S901 is carried by exactly ONE ledger entry (attributable); PC-S902 is
# carried by TWO (ambiguous), and naming both would tell the operator to close an entry upstream
# never touched.

# --- base: neither marker present ---
printf '# SKILL\nrule one\nrule two\n' > "$SK"
printf '0.100.0\n' > "$DIST/VERSION"
git -C "$DIST" add -A
git -C "$DIST" commit -qm base
BASE="$(git -C "$DIST" rev-parse HEAD)"

# --- mid: MARKER_B added HERE, at 0.101.0 (Entry B absorbed) ---
# The absorption is deliberately NOT at the tip. A close row names the version where the
# substring actually appeared, and with base->theirs adjacent that claim is indistinguishable
# from naming theirs' VERSION — which is what the code used to do, wrongly, for every
# absorption that predated the pull.
printf '# SKILL\nrule one\nrule two\nMARKER_B a rule upstream just absorbed\n' > "$SK"
printf '0.101.0\n' > "$DIST/VERSION"
git -C "$DIST" add -A
git -C "$DIST" commit -qm mid

# --- theirs: an unrelated change, VERSION moves on to 0.102.0 ---
printf '#!/bin/sh\necho thing\necho more\n' > "$DIST/core/skills/ai-dlc/validate-thing.sh"
printf '0.102.0\n' > "$DIST/VERSION"
git -C "$DIST" add -A
git -C "$DIST" commit -qm theirs
THEIRS="$(git -C "$DIST" rev-parse HEAD)"

# --- consumer ledger ---
LED="$CONS/_bmad-output/ai-dlc-update/push-candidate-ledger.md"
mkdir -p "$(dirname "$LED")"
cat > "$LED" <<'LEDGER'
# AI/DLC Push-Candidate Ledger

## Open — filed for the fixture

- **Entry A still lacked upstream.** A generalizable improvement core does not carry.
  <br>Some prose. More prose describing the receipt.
  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

- **Entry B was live, now absorbed.** Another improvement, since taken upstream.
  <br>Receipt prose here.
  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_B"

- **Entry C already closed.** This one was adopted last pull.
  <br>ADOPTED UPSTREAM (v0.99.0, verified 2026-07-19). Closed.
  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_B"

- **Entry D has no verify line.** A legacy prose entry, hand-review as today.
  <br>No machine-runnable receipt; the closer must not emit a row for it.

- **Entry E declares manual.** No mechanical predicate exists for this claim.
  <br>Hand-review is the DECLARATION, not a malformed line — it must not share a verdict
  with a typo.
  verify: manual

- **Entry F declares manual with a stray backtick.** Prose formatting leaked into the verb.
  <br>A formatting slip must not change the verdict.
  verify: manual`

- **Entry G is Entry B filed in the consumer's install namespace.** Same claim, same
  substring; only the path layout differs (`core/.claude/skills/…` instead of
  `core/skills/…`). It MUST classify identically to Entry B — a closer that cannot resolve
  the path never compares the substring and silently reports nothing about the claim.
  verify: theirs_lacks core/.claude/skills/ai-dlc/SKILL.md "MARKER_B"

- **PC-S901-SHORT-ID-UNIQUE-PREFIX** — upstream cites the short id, this ledger carries one
  entry under it, so the attribution is unambiguous. The full slug appears NOWHERE in the
  distribution's history, which is the normal case and is what the slug-only join was blind to.
  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

- **PC-S902-SHARED-PREFIX-FIRST** — upstream cites `PC-S902`, and TWO entries here carry it.
  Attributing the commit to either would tell the operator to close one upstream never touched.
  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

- **PC-S902-SHARED-PREFIX-SECOND** — the other half of the ambiguous pair. Exactly ONE
  `NAMED-UPSTREAM-AMBIGUOUS` row may be emitted across both, keyed on the prefix rather than on
  either entry: the same fact repeated per entry is a report an operator scrolls past.
  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

- **PC-S903-NEVER-CITED-AT-ALL** — the control for both arms. Id-shaped, unique prefix, and
  upstream names neither its slug nor `PC-S903`. It must stay silent, or the prefix arm is
  matching on shape rather than on evidence.
  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

- **Entry H names an ambiguous basename.** Two files at theirs are called
  `validate-thing.sh`, so the fallback has no unique answer and must refuse to guess.
  verify: theirs_lacks core/scripts/ai-dlc/validate-thing.sh "MARKER_B"

- **Entry I names a basename that exists nowhere at theirs.** Nothing to fall back to.
  verify: theirs_has core/scripts/ai-dlc/no-such-file.sh "MARKER_B"

- **Entry J has an inverted verb.** MARKER_A names the FIX the entry wants, so the author
  reached for `theirs_has` when the claim needs `theirs_lacks`.
  <br>MARKER_A is absent at base AND at theirs, so this predicate could never have reported
  STILL-LIVE — it was born closed and no upstream change produced the verdict.
  verify: theirs_has core/skills/ai-dlc/SKILL.md "MARKER_A"

- **Entry K is the same vacuity in the other direction.** `rule one` is present at base AND
  at theirs, so `theirs_lacks` could never have reported STILL-LIVE either.
  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "rule one"

- **Entry L names TWO substrings.** Both are absent at theirs, so the entry is genuinely
  still live — but only if each is matched separately.
  <br>Joined into one literal (quotes and all) it matches nothing, which reports
  "still lacks" for the right verdict by accident.
  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A" "MARKER_C"

- **Entry M names two substrings that theirs BOTH carries.** `rule one` and `MARKER_B` are
  each present at theirs, so upstream holds everything the entry asked for.
  <br>This is the case the joined literal gets WRONG: it matches nothing, reports
  "still lacks", and the entry stays open forever against an upstream that already has it.
  Base carries `rule one` but NOT `MARKER_B`, so the close is real, not vacuous.
  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "rule one" "MARKER_B"

---

- **Entry SH-MOVED runs an `sh` receipt whose subject no longer exists.** A RENAMED subject
  exits 127 (command not found), which the `sh` verb read as "no longer reproduces" and
  closed. That is an absorption that never happened, and closing is the direction that
  loses information permanently — measured on a reference consumer where ONE relocation
  commit flipped five entries to CLOSE-CANDIDATE in a single run, every one still
  reproducing at its new path.
  <br>The `theirs_*` verbs have always emitted NEEDS-REVIEW for an unresolvable path; `sh`
  is the verb that runs arbitrary commands, where paths are most volatile, and it was the
  one without the guard.
  verify: sh bash /nonexistent/path/that/was/renamed.sh

---

- **Entry SH-REAL runs an `sh` receipt that genuinely stops reproducing.** The OVER-FIRE
  CONTROL for the entry above: a plain non-zero exit that is NOT 126/127 must still close,
  or the guard would pin every `sh` entry open forever and be worse than the defect.
  verify: sh test -e /nonexistent-so-this-exits-1

---

- **Entry SH-SUBJECT-GONE runs an `sh` receipt whose subject MOVED, inside an `&&` chain.**
  The chain short-circuits on the missing file and the whole receipt exits 1 — the same status
  a genuine fix produces, which is why the 126/127 guard above cannot see this one. Measured on
  the reference consumer: an artifact-path migration moved one subject and the entry proposed
  closing a defect that still reproduced at its new path.
  verify: sh test -e "$CONSUMER/docs/retro/sprint-249.md" && grep -q x "$CONSUMER/docs/retro/sprint-249.md"

---

- **Entry SH-LIVE runs an `sh` receipt that still reproduces.** Exit 0. Pins the third
  outcome so the two above cannot both be satisfied by a verb that always reports one
  thing.
  verify: sh true

---

- **Entry SH-CWD is a receipt whose own CLAIM is about absolute-path handling.** `$CONSUMER`
  is the only one of the four exported values a receipt can read as a path — `$DIST` goes to
  `git -C` and the two refs are shas — and callers routinely pass `.`, which is a valid
  consumer root. An entry about absolute-path handling is verified by a two-arm predicate in
  which the ABSOLUTE arm must behave differently from the relative one, so handing it a root
  in the wrong form inverts the `&&` chain and the entry reads CLOSE-CANDIDATE while it is
  still live. Measured on a reference consumer: 74 rows either way, ONE differing, and that
  one a FALSE CLOSE — the direction this tool's header names as the one that loses
  information permanently.
  <br>Exit 0 (STILL-LIVE) when the root arrives absolute, non-zero (a false close) when it
  arrives as `.`. This entry is what makes the relative-versus-absolute differential in
  run.sh able to fail at all.
  verify: sh case "$CONSUMER" in /*) exit 0 ;; *) exit 1 ;; esac

---

- **Entry TH-UNDECIDED anchors `theirs_has` on text that is present at BASE as well.** Nothing
  in `base..theirs` moved either side of this predicate, so its STILL-LIVE is a restatement of
  the previous run, not a new measurement. `rule two` is in SKILL.md at both refs.
  <br>This is the shape SKILL.md step 3f warns about and has no guard for — an anchor on text
  a fix would KEEP survives the fix, so the entry can never close. Measured on the reference
  consumer at 0.301.0: three of five hand-checked STILL-LIVE verdicts were false, every one of
  them this shape, and 24 of 24 `theirs_has` receipts there sit in this bucket.
  verify: theirs_has core/skills/ai-dlc/SKILL.md "rule two"

---

- **Entry TH-DECIDED is the CONTROL, and without it the tally counts everything.** Same verb,
  same file, also STILL-LIVE — but `MARKER_B` arrived at 0.101.0, INSIDE `base..theirs`, so this
  predicate demonstrably moved in range and its verdict IS a measurement this pull made. It must
  NOT be counted. A tally that cannot tell these two apart is a row-count wearing a finding's
  name.
  verify: theirs_has core/skills/ai-dlc/SKILL.md "MARKER_B"

---

## PC-FIXTURE-HEADING-ABSORBED — the heading entry shape (filed for the fixture)

verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_B"

Entries grow into this shape once the receipt outgrows a bullet. Identical directive to
Entry B, so it must classify identically — a parser that treats a heading as a pure
terminator drops it silently and reports nothing to close.

---

## PC-FIXTURE-HEADING-CLOSED — heading shape, already adopted

verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_B"

ADOPTED UPSTREAM (v0.101.0, verified for the fixture). Closed — must not be re-emitted.

---

## PC-FIXTURE-HEADING-NO-VERIFY — heading shape, no directive

Prose only. Must NOT inherit the directive of the heading entry above it: a heading opens
an entry, so it also ends the one before it.

---

- **PC-FIXTURE-BULLET-DASH — a bullet whose title is long enough past the em dash that the old
  seventy-character clip would have eaten the id itself and left prose behind**
  <br>The bullet arm never split on the em dash the way the heading arm did, so this entry's
  label used to be its whole prose title, clipped mid-sentence. It must label as the bare id.
  <br>verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

## PC-FIXTURE-HEADING-LONG-BEFORE-DASH (a parenthetical this long pushes the pre-dash text past seventy characters on its own) — the clip landed inside the parenthetical

A heading whose em dash comes AFTER a parenthetical: the split leaves more than seventy
characters, so the clip fired on text that was already correct and truncated it mid-word.
The label must be the complete pre-dash text.

verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

---

## PC-FIXTURE-WITHDRAWN — the premise was false, so there is no defect to re-verify

**WITHDRAWN for the fixture.** The entry's load-bearing claim was wrong when written. Its
receipt would report STILL-LIVE forever, because no upstream change can make a defect that
never existed stop existing. A finished entry must not ask for a verdict on the next pull.

verify: manual

---

## PC-FIXTURE-PROSE-MENTIONS-THE-VOCABULARY — an OPEN entry that has to name the close markers

This entry is OPEN. Its body explains the convention, which means quoting it: close only once
the grep is non-zero, and annotate `ADOPTED UPSTREAM (vX.Y.Z, verified <date>)` then. It also
quotes the tool's own output, the way a defect report against the tool must:

> `theirs:$path now CONTAINS "$sub" — upstream absorbed this at $TV. … annotate 'ADOPTED UPSTREAM
> (v$TV, verified <date>)'`

and notes in passing that the sentinel was ADOPTED UPSTREAM in v0.135.0 as narrative prose.
None of that is an annotation. An unanchored close predicate read all three as one and deleted
this entry from the report — no row at all, which is worse than a wrong row.

verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

---

## PC-FIXTURE-BOLD-ANNOTATION-WITH-A-PREFIX — a real close whose bold span opens with words

**BOTH ADOPTED UPSTREAM (verified for the fixture) — this section is now empty.** The marker is
not the first thing on the line, but the bold span that carries it is, which is what an
annotation looks like and a mention does not.

verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

---

## PC-FIXTURE-WITHDRAWN (original text, retained for the record) — the copy a withdrawal supersedes

Retaining the original text of a withdrawn entry is the honest thing to do: the withdrawal is
only legible beside what it withdraws. But this copy carries no close marker of its own — the
withdrawal lives in the superseding entry's heading — so it re-reported forever, asking an
operator to adjudicate a defect that was already retracted as false.

verify: manual

---

## PC-FIXTURE-TWO-RECEIPTS — one entry, two line-leading receipts that DISAGREE

The strongest form of the last-match-wins defect: receipt one is genuinely still live (MARKER_A is
absent at theirs) and receipt two is a real close (MARKER_B was absorbed). A scalar `directive`
keeps only the LAST, so the entry reported CLOSE-CANDIDATE and the still-live half vanished with no
row at all — a close hiding a live claim, which is the direction that drains an open entry.

Both rows must appear, each tagged with its ordinal. An entry closes only when EVERY receipt closes,
and printing them all is what makes that enforceable by a human rather than assumed.

verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"
verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_B"

---

## PC-FIXTURE-NAMED-BUT-RECEIPT-STUCK — upstream landed it; the receipt cannot ever say so

The pre-base commit NAMES this id, so upstream absorbed the entry. The receipt below is
anchored on MARKER_A, which is absent at base AND at theirs, so it reports STILL-LIVE on
every pull and will keep doing so after the absorption — the receipt is testing the wrong
token, and no amount of re-running it will reveal that.

Both rows must appear: STILL-LIVE from the receipt, NAMED-UPSTREAM from the history. The pair
IS the finding — one half says the entry is absorbed, the other says its receipt is wrong.

verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

---

## PC-FIXTURE-NAMED-MANUAL — a manual entry upstream has already landed

`verify: manual` declares that no mechanical predicate exists, so HAND-REVIEW is correct and
permanent: the receipt can never close this entry, by design. The id in upstream's history is
therefore the ONLY mechanical signal available for this shape, which is the case that left five
entries reporting HAND-REVIEW two pulls after upstream absorbed them.

verify: manual

---

## PC-FIXTURE-SWALLOWED-BY-ANNOTATION — an entry an annotation truncates

THE DEFECT. The entry-boundary rule opens a new entry on ANY line-leading `- **`, which is
correct for a ledger whose entries are bullets and is what makes an ANNOTATION in the same
shape indistinguishable from one. The lead-in below therefore ends THIS entry, and the
receipt after it is attributed to the annotation instead. This entry goes silent.

- **The derivation:** an annotation lead-in written the way an operator naturally writes one.
  Its bold span ends in a colon, which is what separates a lead-in from an entry title.

verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

---

## PC-FIXTURE-COLON-CONTROL — a real entry whose receipt is NOT captured

THE CONTROL. Same section, same receipt shape, no annotation. It must report normally and must
NOT be named as swallowed, or the assertion above passes for a detector that flags every entry.

verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

---

- **`a-real-entry.sh` → a prose-titled entry that legitimately carries a receipt**

  THE SECOND CONTROL, and the measured false-positive class. A ledger may key an entry by prose
  rather than by an id — 49 of the reference consumer's 52 bullets do — and such an entry carries
  a receipt legitimately. An earlier predicate keyed on "receipt under a non-id label" and scored
  SEVEN rows there, SIX of them entries of exactly this shape. Its bold span does not end in a
  colon. It must stay SILENT.

verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"
LEDGER

printf '%s %s %s %s\n' "$DIST" "$BASE" "$CONS" "$THEIRS"
