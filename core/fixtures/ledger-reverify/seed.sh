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

# A SUBJECT FOR THE CWD ARM, and it exists because every other `sh` receipt in this seed names
# an ABSOLUTE path (`/nonexistent/...`) or interpolates `$CONSUMER`. Both resolve the same from
# any directory, so none of them could ever have detected a receipt being evaluated at the
# caller's cwd instead of the consumer root -- which is how that defect shipped. The real
# ledger's receipts are written the other way: a BARE consumer-relative path.
mkdir -p "$CONS/.claude/skills/ai-dlc-update/reconcile"
printf 'MARKER_RELATIVE_SUBJECT\n' > "$CONS/.claude/skills/ai-dlc-update/reconcile/ledger-rotate.sh"

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

# --- pre-base: THE MIDDLE-COMMIT CASE, AND THE TWO NEAR-MISSES THAT SIT BESIDE IT ---
#
# `named_absorbed()` reported the NEWEST and the OLDEST commit whose message names the id and
# nothing between them. The two ends are the worst pair to elect: the oldest mention is the commit
# that FILED the entry, or a plan, and the newest is the withdrawal or the docs commit written
# after the fix landed. The absorbing commit sits in the MIDDLE and was never shown.
#
#   PC-S904  THREE naming commits, the ABSORBING one in the MIDDLE. Newest is a WITHDRAWAL,
#            oldest is a docs handoff, and NEITHER touches a subject. This is the motivating
#            shape, and the arm that reads it fires here or the population is not what it looks.
#   PC-S906  TWO naming commits, so the two ends ARE the whole set and nothing can be hidden.
#            THE NEAR-MISS, and it is in the SAME ledger and the SAME run as PC-S904 carrying a
#            byte-identical receipt, so both entries emit the same two rows and the run is the
#            same size whichever is being read. An implementation that keys on the COUNT
#            (`n > 1`) and reads no sha classifies the two identically and cannot pass. In a
#            SEPARATE run it could only ever ask whether the arm fires at all, never whether it
#            fires on the right commits.
#   PC-S905  ONE naming commit -- the single-commit branch, which the list must leave alone.
#
# ALL OF THEM SIT BEFORE base, for the same reason the commit above does: the bounded-search
# mutant must lose every named row together, and a naming commit inside `BASE..THEIRS` would
# survive it and make that arm report a partial revert.
#
# EACH ABSORBING COMMIT TOUCHES A FILE OF ITS OWN. "Which commit did the work" is then derivable
# from the repo, so the fixture's precondition arm does not have to read it off the row it is
# about to test.
mkdir -p "$DIST/docs"

printf 'a handoff that files the entry\n' > "$DIST/docs/s904-handoff.md"
git -C "$DIST" add -A
git -C "$DIST" commit -q -m 'docs(plan): file PC-S904-ABSORBED-IN-THE-MIDDLE-COMMIT as a handoff' \
  -m 'Lands no fix. OLDEST of the three commits naming this id.'

printf '#!/bin/sh\necho s904 fixed\n' > "$DIST/core/scripts/s904-subject.sh"
git -C "$DIST" add -A
git -C "$DIST" commit -q -m 'fix: absorb PC-S904-ABSORBED-IN-THE-MIDDLE-COMMIT' \
  -m 'THE ABSORBING COMMIT, and it is neither end of the range.'

printf 'a handoff that files the entry\nwithdrawn\n' > "$DIST/docs/s904-handoff.md"
git -C "$DIST" add -A
git -C "$DIST" commit -q -m 'docs(ledger): withdraw PC-S904-ABSORBED-IN-THE-MIDDLE-COMMIT, premise was false' \
  -m 'Lands no fix. NEWEST of the three commits naming this id.'

printf '#!/bin/sh\necho s905 fixed\n' > "$DIST/core/scripts/s905-subject.sh"
git -C "$DIST" add -A
git -C "$DIST" commit -q -m 'fix: absorb PC-S905-ONE-NAMING-COMMIT-ONLY'

printf '#!/bin/sh\necho s906 fixed\n' > "$DIST/core/scripts/s906-subject.sh"
git -C "$DIST" add -A
git -C "$DIST" commit -q -m 'fix: absorb PC-S906-TWO-NAMING-COMMITS-NOTHING-HIDDEN'

printf 'landed\n' > "$DIST/docs/s906-note.md"
git -C "$DIST" add -A
git -C "$DIST" commit -q -m 'docs(ledger): record PC-S906-TWO-NAMING-COMMITS-NOTHING-HIDDEN as landed'

# --- base: neither marker present ---
printf '# SKILL\nrule one\nrule two\n' > "$SK"
printf '0.100.0\n' > "$DIST/VERSION"
# THE BACKSLASH SUBJECT, and the three shapes the reference consumer's own ledger has carried.
# Line 2 is prose with BARE backticks, present here and gone at theirs: a receipt quoting it
# with markdown-escaped backticks is the filed defect, and the same receipt written bare is the
# near-miss control. Line 3 carries a LITERAL backslash-backtick pair, the shell-printf shape an
# earlier consumer entry anchored on where the backslashes WERE the defect text; theirs drops
# them. Line 4 is the text a regex-shaped anchor is aimed at, kept identical at both refs.
# printf's `\\` yields one backslash and `%%` one percent sign, so the file holds exactly
# `_base_ \`%s\`` on line 3 -- asserted by the seed rather than trusted.
RT="$DIST/core/skills/ai-dlc/steps/route.md"
mkdir -p "$(dirname "$RT")"
printf '# route\nReply `trim` to have me trim it to its budget.\n_base_ \\`%%s\\`\nversion: 9.9.9\n' > "$RT"
grep -qF -- '_base_ \`%s\`' "$RT" || { echo 'seed: route.md line 3 is not the literal backslash-backtick pair' >&2; exit 1; }
# THE PATH-FIELD SUBJECT: a file whose name carries an underscore, so a markdown author may
# write it `route\_notes.md`. Its token is present here and gone at theirs; a correctly spelled
# receipt on it closes, an escaped one must be refused rather than resolved by basename.
RN="$DIST/core/skills/ai-dlc/steps/route_notes.md"
printf '# notes\nTHE_DEFECT_TOKEN lives here at base\n' > "$RN"
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

# --- mid2: MARKER_C added HERE, and VERSION IS NOT BUMPED (the FIX-THEN-RELEASE shape) ---
# The two shapes are both real and a fix for one is the mirror defect for the other, so the seed
# carries BOTH. `mid` above is FIX-IS-RELEASE: the commit that introduced MARKER_B bumped VERSION
# in the same commit, so the release IS that commit. This one is the other shape: the change
# lands while VERSION still reads 0.101.0 and the bump arrives separately, below. Reading the
# VERSION blob AT this commit reports 0.101.0 -- one release early, and permanently, because the
# operator copies it into `ADOPTED UPSTREAM (v…)`.
printf '# SKILL\nrule one\nrule two\nMARKER_B a rule upstream just absorbed\nMARKER_C absorbed one commit before its release\n' > "$SK"
git -C "$DIST" add -A
git -C "$DIST" commit -qm 'fix: absorb MARKER_C, no version bump in this commit'

# --- rel: the release that CARRIES MARKER_C. VERSION -> 0.102.0, nothing else changes ---
# Deliberately NOT the tip. If it were, "the release containing the fix" and "VERSION at theirs"
# would be the same string and the arm could not tell a correct forward walk from the old
# fall-back-to-theirs behaviour.
printf '0.102.0\n' > "$DIST/VERSION"
git -C "$DIST" add -A
git -C "$DIST" commit -qm 'release: v0.102.0'

# --- theirs: an unrelated change, VERSION moves on to 0.103.0 ---
printf '#!/bin/sh\necho thing\necho more\n' > "$DIST/core/skills/ai-dlc/validate-thing.sh"
# route.md at theirs: the bare-backtick prose is GONE (the fix the escaped receipt should have
# closed on), the backslashes on line 3 are gone (the shell-printf fix), the version line stays.
printf '# route\nStep 0a trims the snapshot itself.\n_base_ %%s\nversion: 9.9.9\n' > "$RT"
printf '# notes\nfixed at theirs\n' > "$RN"
printf '0.103.0\n' > "$DIST/VERSION"
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

- **Entry V was absorbed one commit BEFORE its release.** The forward-walk case: `MARKER_C`
  arrived while VERSION still read 0.101.0 and shipped in 0.102.0, and theirs is 0.103.0 — so
  the correct answer, the blob-at-the-commit answer and the tip answer are three different
  strings.
  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_C"

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

- **PC-S904-ABSORBED-IN-THE-MIDDLE-COMMIT** — THREE commits name this id and the one that
  absorbed it is the MIDDLE. Its two ends are a docs handoff and a withdrawal, so the pair the
  two-ends form advertised is exactly the pair that did not land the fix.
  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

- **PC-S905-ONE-NAMING-COMMIT-ONLY** — one naming commit, so there is no list to get wrong. The
  single-commit branch has to stay unchanged, or the fix rewrites every row it was not about.
  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

- **PC-S906-TWO-NAMING-COMMITS-NOTHING-HIDDEN** — TWO naming commits, so the two ends ARE the
  whole set and nothing is hidden. The near-miss for the entry three above, deliberately in the
  same ledger and carrying the same receipt: both emit a STILL-LIVE and a NAMED-UPSTREAM row,
  both take the `n > 1` branch, and only the SHA SET tells them apart.
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

- **Entry SH-DIST-PATH runs an `sh` receipt naming a DISTRIBUTION path in a rev-spec.** The
  receipt reads a file out of the distribution at theirs; it names nothing on the consumer's own
  disk. `receipt_absent_subjects` must not see a consumer path inside it. It used to: an
  unanchored regex found `scripts/validate-x.sh` INSIDE `core/scripts/validate-x.sh`, that
  spelling exists on no consumer (the installed one is `scripts/ai-dlc/<x>`), and a working
  receipt was reported unresolved with an instruction to re-anchor it. SH-SUBJECT-GONE above is
  the paired control: a genuinely absent CONSUMER path in the same position must still be flagged,
  or this arm is satisfied by an extractor that sees nothing at all.
  verify: sh git -C "$DIST" show "$THEIRS:core/scripts/validate-artifact-derivations.sh" >/dev/null 2>&1; exit 1

---

- **Entry SH-LIVE runs an `sh` receipt that still reproduces.** Exit 0. Pins the third
  outcome so the two above cannot both be satisfied by a verb that always reports one
  thing.
  verify: sh true

---

- **Entry SH-RELATIVE-SUBJECT names its subject the way the real ledger does: a BARE
  consumer-relative path.** Every other `sh` entry here writes an absolute path or interpolates
  `$CONSUMER`, and both resolve identically from any directory — so before this entry existed,
  no assertion in this fixture could see a receipt being evaluated at the CALLER's cwd instead
  of the consumer root. It reproduces (exit 0, STILL-LIVE) only when the receipt runs at the
  consumer root; from anywhere else `grep` exits 2 on a missing file and the entry reads as
  absorbed, which is the false close that direction produces.
  verify: sh grep -q MARKER_RELATIVE_SUBJECT .claude/skills/ai-dlc-update/reconcile/ledger-rotate.sh

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

---

## PC-FIXTURE-NO-COLON-SWALLOWED — the entry a NO-COLON annotation truncates

BL-013's SUBJECT, and the colon signal is structurally blind to it. This entry carries no
receipt of its own above the annotation and no close, so it emits NO row at all; the bullet
below opens a new entry and CAPTURES the receipt that was written for this one. The bold span
below ends in no colon, which is the only thing separating this from the case above it.

- **False CLOSE-CANDIDATE** this bold span ends in no colon at all, which is how an operator
  writes a lead-in when the next word is a noun rather than an explanation.

  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

---

## PC-FIXTURE-RECEIPT-ABOVE-ANNOTATION — the BENIGN direction, which must stay SILENT

THE FALSE-NEGATIVE CONTROL, and it is deliberate. This entry's own receipt sits ABOVE the
annotation, so it still emits its row and NOTHING is lost. The harm the conjunction reports is
the LOSS of a row, never the presence of an annotation — an arm that fires here is watching
shape rather than damage.

verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

- **Second no-colon prose bullet** which captures a second copy of the same receipt

  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

---

## PC-FIXTURE-CLOSED-BEFORE-PROSE — a CLOSED entry, and a REAL entry follows it

THE `!prev_id_closed` SUBJECT. A closed entry emits no row BY DESIGN — the classifier skips
it — so "the entry above emitted no row of its own" is satisfied by every single entry that
follows a close. Without that clause every real prose-titled entry in this position is
falsely reported, and this adjacency is ordinary in a pre-rotation ledger.

<br>**ADOPTED UPSTREAM (v0.099.0, verified 2026-01-01).** Upstream took it.

- **`legacy-entry.sh` → repoint the dormant-gate scan at the installed tree**

  A REAL entry in the older id-less format the reference consumer still carries, sitting
  directly below a closed one and carrying its own receipt legitimately.

  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

---

## PC-FIXTURE-NO-ROW-ABOVE — emits no row of its own, so the conjunction's first half holds

THE CHARACTER-CLASS SUBJECT SITS BELOW THIS ONE. No receipt, no close: this entry emits
nothing, which is exactly the state the capture arm looks for. The bullet below is a REAL
entry whose id carries `_` and `.`, so the ONLY thing keeping it out of the report is the id
rule recognising those two characters.

- **PC-FIXTURE-ID_WITH.PUNCT-AT-0.242.0** — a real entry whose id carries an underscore and a dot

  `idshape()` used to require `^[A-Z0-9-]+$`, which admits neither. Measured on the reference
  consumer, `PC-S330-PREPUSH-LEAKS-GIT_DIR-INTO-EVERY-FIXTURE-SANDBOX` and
  `PC-S300-SEVEN-VALIDATORS-SHIPPED-NON-EXECUTABLE-AT-0.242.0` each failed it — one real entry
  in the live ledger and one in the archive, scored as annotations.

  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

---

## PC-FIXTURE-UESCAPE-NEAR-MISS — a receipt substring that only LOOKS like a unicode escape

THE NEAR-MISS CONTROL for the detail-field escape arm in run.sh. The real producer echoes this
substring verbatim into the emitted detail, and it carries the three shapes ADJACENT to a unicode
escape without being one: the bare word u2026 with no backslash, a lone backslash before a
non-u character, and a backslash-u with only THREE hex digits. An arm keyed on a backslash alone,
on the token u2026, or on backslash-u without counting the digits, reports this entry and is wrong.

verify: theirs_lacks core/skills/ai-dlc/SKILL.md "NEARMISS-u2026-and-\x-and-\u202-END"

---

## PC-FIXTURE-FENCED-NON-ID-HEADING — a derived block whose recorded output carries `## <ts> -- EVENT` lines

THE SUBJECT OF PC-S308-LEDGER-REVERIFY-ENTRY-BOUNDARY-IGNORES-FENCED-HEADINGS. The consumer's
`pipeline-continuation-log.md` is a file of `## <timestamp> -- <event>` headings, so a derived
block that greps it records heading-shaped lines at column 0. A fence-blind boundary rule opened
a new entry on the first of them, labelled it with the timestamp, and attributed this entry's
receipt to that label — this entry then emitted no row under its own id, and the receipt was
reported under a label nobody could find.

```derived
$ grep '^## ' pipeline-continuation-log.md | head -2
## 2000-01-01T00:00:00Z -- FENCED-TS-EVENT-A
## 2000-01-01T00:00:01Z -- FENCED-TS-EVENT-B
```

verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

---

## PC-FIXTURE-TILDE-FENCE — a tilde fence at column 0

The tilde branch of the opener grammar had no subject on any real corpus: zero `~~~` lines on
the consumer's live ledger, its archive and both distribution backlog files. The heading inside
sits at column 0, because an indented heading is never entry-shaped and would prove nothing.

~~~
## 2000-01-01T00:00:03Z -- TILDE-TS-EVENT
~~~

verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

---

## PC-FIXTURE-INDENTED-FENCE — a fence indented two spaces, the consumer's second-commonest delimiter shape

The consumer's live ledger carries 10 two-space-indented delimiters against 51 at column 0, and
its archive 82 against 194. The rule tolerates indentation on the DELIMITER while still reading
the heading line unstripped, so a column-0 heading inside an indented fence is fenced.

  ```derived
## 2000-01-01T00:00:04Z -- INDENTED-TS-EVENT
  ```

verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

---

## PC-FIXTURE-INLINE-SPAN-LINE — a line that OPENS with an inline code span is not a fence
```derived``` is an inline span here, not a fence opener: its info string carries a backtick, which
CommonMark forbids. The reference consumer's live ledger carries exactly one such line, and a
naive "three backticks open a fence" rule read it as an opener, inverted parity for the rest of
the file, and hid six live ids. The prose-titled entry below is what that rule hides.

verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

- **`inline-span-control.sh` → a prose-titled entry right after an inline-span line**

  NOT id-keyed, deliberately: an id-keyed line survives any fence state by the reset rule, so
  only a prose-titled entry can show whether the inline-span line above opened a fence.

  verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

---

## PC-FIXTURE-QUOTING-ENTRY — an entry whose fence QUOTES an id-keyed entry heading

An id-keyed line inside a fence is the case the boundary rule cannot resolve: the fence is
either unterminated or is quoting a heading, and hiding an id-keyed entry is the worse
failure. So the rule opens an entry there anyway and reverify REPORTS it, under
ENTRY-SWALLOWED with the fence signal, naming this entry as the one truncated.

```
## PC-FIXTURE-QUOTED-INSIDE-FENCE — quoted, and it still opens an entry
```

verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

---

## PC-FIXTURE-AFTER-QUOTE — the entry after a quoted heading, and it must NOT be reported

THE STRAY-CLOSER CONTROL. The closing fence of the quotation above sits after the reset, so a
rule that read it as a new OPENER would place this whole entry inside a fence and report it as
fenced too — one quotation, two accusations. It must report STILL-LIVE and carry no
ENTRY-SWALLOWED row.

verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

---

## PC-FIXTURE-QUOTING-TWICE — a fence that quotes TWO id-keyed headings

THE BATCH-50 ADVERSARIAL HAND'S CASE, AND THE STATED COST OF THE STRAY-CLOSER RULE. The first
quoted heading resets the fence and is reported; the second clears the stray flag, so the closer
below is read as a new opener and the entry after this one is reported as fenced too — one
false row beside a true one about the same fence. The alternative, letting the flag survive
entry-shaped lines, was measured on the reference consumer's archive: it turned two true resets
into nine. Nothing is HIDDEN in this shape; the receipt after the fence still reports.

```
## PC-FIXTURE-QUOTED-TWICE-A — the first quoted heading
## PC-FIXTURE-QUOTED-TWICE-B — the second, which clears the stray flag
```

verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

---

## PC-FIXTURE-AFTER-TWO-QUOTES — the entry after a two-quotation fence: reported, never hidden

verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

---

## PC-FIXTURE-UNTERMINATED-FENCE — a fence that never closes

The reference consumer's archive carries two of these, left by rotations that split entries
mid-fence — counted by driving the shipping rule and taking the openers that reach a reset or
the end of the file. Everything after this opener is inside the fence until an id-keyed boundary resets it.

```
this fence is never closed
## 2000-01-01T00:00:02Z -- FENCED-TS-EVENT-C

## PC-FIXTURE-AFTER-UNTERMINATED — id-keyed, so it opens an entry through the unterminated fence

A rule that let an unterminated fence swallow id-keyed lines would hide this entry and every
one after it — the 47-entry desync `scripts/backlog-rotate.sh` measured on the reference
consumer. It must report STILL-LIVE, and the reset is reported as ENTRY-SWALLOWED naming the
entry above.

verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"

---

## PC-FIXTURE-ESCAPED-BACKTICK — a receipt whose backticks are markdown-escaped

THE FILED DEFECT. Read with bare backticks the substring is present at base and gone at
theirs, a textbook close; written with a backslash before each backtick it is found at
neither ref. The reader must refuse the anchor and say why, not report the predicate vacuous.

verify: theirs_has core/skills/ai-dlc/steps/route.md "Reply \`trim\` to have me trim it to its"

---

## PC-FIXTURE-BARE-BACKTICK — the same receipt with its backticks bare, the near-miss control

Backticks themselves are not the problem. This one closes, which is also the proof that the
seed's base and theirs discriminate on this text.

verify: theirs_has core/skills/ai-dlc/steps/route.md "Reply `trim` to have me trim it to its"

---

## PC-FIXTURE-LITERAL-BACKSLASH — the anchor's backslashes ARE the source text, the stated limit

The shell-printf shape: route.md line 3 carries this literally at base and loses the backslashes
at theirs, so a literal reading would close it correctly. It is refused anyway, because the
reader cannot tell this spelling from the escaped one above, and the row tells the author to
re-anchor or write `sh`. If this arm ever fails because an escape mechanism was built, update
the arm deliberately; do not restore the literal search.

verify: theirs_has core/skills/ai-dlc/steps/route.md "_base_ \`%s\`"

---

## PC-FIXTURE-REGEX-ANCHOR — a regex written into a fixed-string grammar

The reference consumer's archive carries one of these. The text it aims at is at both refs;
searched literally the anchor matches nothing anywhere, so `theirs_lacks` would read still-live
forever. A backslash is a backslash whatever it precedes: this one is refused like the others.

verify: theirs_lacks core/skills/ai-dlc/steps/route.md "^version: 9\.9\.9$"

---

## PC-FIXTURE-SECOND-SUBSTRING — two anchors, and only the SECOND carries the backslash

THE BATCH-56 ADVERSARIAL HAND'S CASE. A guard that tests only the first substring passes every
single-anchor seed and then manufactures a CLOSE-CANDIDATE here: the first anchor is at both
refs, the second is the literal pair that theirs drops, so a first-only guard lets the run
reach the close. The whole quoted run is what the rule covers.

verify: theirs_has core/skills/ai-dlc/steps/route.md "version: 9.9.9" "_base_ \`%s\`"

---

## PC-FIXTURE-ESCAPED-QUOTE — a backslash before a double quote, the other escape a markdown author writes

Not a backtick and not a dot, so a guard narrowed to the escapes the other seeds happen to use
lets this one through and it reads vacuous again.

verify: theirs_has core/skills/ai-dlc/steps/route.md "to have me \"trim\" it"

---

## PC-FIXTURE-ESCAPED-PATH — the PATH field markdown-escaped, which the basename fallback would guess right

`route\_notes.md` resolves at neither ref, so it falls to the basename fallback, whose `awk -v`
strips the backslash and finds the real file — a verdict byte-identical to the correctly
spelled receipt below, on a path the author never wrote. Refused instead.

verify: theirs_has core/skills/ai-dlc/steps/route\_notes.md "THE_DEFECT_TOKEN"

---

## PC-FIXTURE-CLEAN-PATH — the same receipt with its path spelled bare, the control

The underscore is not what is refused. This one closes.

verify: theirs_has core/skills/ai-dlc/steps/route_notes.md "THE_DEFECT_TOKEN"

---

## PC-FIXTURE-ESCAPED-ON-MISSING-PATH — an escaped anchor on a path that resolves nowhere

The guard sits BEFORE path resolution. Sited after it, the unresolvable path would pre-empt the
backslash reason and the author would fix the path, re-run, and only then learn about the
anchor. The near-miss is the no-such-file entry above, whose anchor is clean and whose row
must still say the path does not resolve.

verify: theirs_has core/skills/ai-dlc/steps/no-such-step.md "Reply \`trim\` to have me"

---

## PC-FIXTURE-SH-WITH-BACKSLASH — the escape hatch the refusal row offers, pinned

The refusal tells the author to write text that genuinely contains a backslash as `sh`. A guard
that refused every verb carrying a backslash would silence that remedy and, measured on the
reference consumer, fifteen of its thirty-six live `sh` receipts with it. This one exits 0 and
must read STILL-LIVE.

verify: sh case 'a\b' in *\\*) exit 0 ;; *) exit 1 ;; esac

---

## PC-FIXTURE-EOF-FENCE — a fence still open at the end of the ledger

THE LAST ENTRY, and its fence never closes. No id-keyed line follows, so no reset can report
it; reverify's END rule does, under ENTRY-SWALLOWED with the unterminated signal. The receipt
below sits inside the open fence and still parses, because a verify: line is not a boundary.

```
verify: theirs_lacks core/skills/ai-dlc/SKILL.md "MARKER_A"
LEDGER

printf '%s %s %s %s\n' "$DIST" "$BASE" "$CONS" "$THEIRS"
