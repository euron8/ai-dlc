#!/usr/bin/env bash
# backlog-rotate-fence-guard — assert that scripts/backlog-rotate.sh REFUSES a ledger whose
# closed entry fences an entry-shaped line, writes nothing when it refuses, and stays quiet on
# the near-misses a backlog full of quoted markdown carries constantly.
#
# THE DEFECT, REPRODUCED BEFORE THIS FIXTURE WAS WRITTEN.
# `ledger_entry_shape()` in core/skills/ai-dlc-update/reconcile/lib.sh is fence-BLIND: any
# `^#{2,6}[ \t]` or `^- \*\*` line is an entry boundary, including one inside a fenced block. A
# closed entry whose body fences such a line is SPLIT MID-FENCE. Measured against a rotator with
# the guard neutralised, on seed OFFENDER-A below: input carried 2 fence delimiters, the archive
# came out with 1 and the live file with 1 — two unterminated fences, corrupt markdown on both
# sides — and the live file kept an orphaned tail plus a phantom `## BL-901` entry promoted out
# of the fence. The rotator reported success and exited 0 while doing it.
#
# THE SEEDS COME FROM THE CORRUPTION, NOT FROM THE GUARD'S ACCEPT-SET. Every OFFENDER seed here
# was run against a sed-mutated rotator with the guard switched off, and each one produced an
# odd fence count in at least one output file. That measurement is what admitted it as a seed;
# none was chosen by reading the guard's regex. This matters because
# core/fixtures/scope-confirmation/seed.sh seeded only the grammars its parser accepted and was
# therefore blind to the defect that shipped.
#
# WHAT LINE-CONSERVATION CANNOT SEE, MEASURED. The split prints every input line to exactly one
# of the two output files, so a boundary MISCLASSIFICATION cannot lose a line: against the
# guard-off mutant on OFFENDER-A, the sorted line multiset of (live + archive delta) was
# byte-identical to the input. Conservation is asserted below anyway — it is the property a
# future change to flush() would break — but the property THIS defect violates is FENCE BALANCE,
# which has its own arm. An arm that cannot fire on the defect it is named for is the repo's
# recurring hazard, so the two are separated rather than conflated.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = one regressed, 2 = fixture broken.
#
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# WALK UP FOR THE VERSION MARKER, NEVER COUNT `..` HOPS. A hop count answers differently from
# the repo root, from a subdirectory, and from a sandbox that copied this file.
REPO_ROOT=""
d="$HERE"
while [ "$d" != "/" ]; do
  if [ -f "$d/VERSION" ]; then REPO_ROOT="$d"; break; fi
  d="$(dirname "$d")"
done
[ -n "$REPO_ROOT" ] || { echo "FIXTURE ERROR: no VERSION marker above $HERE" >&2; exit 2; }

RT="$REPO_ROOT/scripts/backlog-rotate.sh"
RV="$REPO_ROOT/scripts/backlog-reverify.sh"
LIB="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"
# The reverifier sources its could-not-measure rule from beside itself, so each root carries it.
RLIB="$REPO_ROOT/scripts/backlog-receipt-lib.sh"
# A MISSING SUBJECT IS NOT A PASS. Several arms below read a tool's output, and a run that
# cannot invoke the tool produces empty output that would score green on anything phrased as an
# absence.
for f in "$RT" "$RV" "$LIB" "$RLIB"; do
  [ -f "$f" ] || { echo "FIXTURE ERROR: cannot locate $f" >&2; exit 2; }
done
echo "HERMETIC-CONSUMED scripts/backlog-rotate.sh"

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

FAIL=0
echo "backlog-rotate-fence-guard fixture"
echo "  subject: $RT"
echo

ok()  { printf '  ok    %-21s %s\n' "$1" "${2-}"; }
bad() { printf '  FAIL  %-21s %s\n' "$1" "${2-}"; FAIL=1; }

# ---------------------------------------------------------------------------------------
# Case construction. Every case gets a PRE-EXISTING archive carrying a sentinel, so the
# "wrote nothing" arm can byte-compare an archive that already had content — an archive the
# refusal merely failed to create is a weaker claim than one it failed to append to.
# ---------------------------------------------------------------------------------------
# NOT `d="$(mkcase x <<'EOM' ... EOM)"`, WHICH IS WHAT THIS FILE WAS WRITTEN AS FIRST. bash is
# 3.2 and its `$( ... )` parser counts parens across heredoc bodies it should not be reading; the
# seeds below carry `(v0.372.0, ...)` and fenced markdown, and the shell swallowed the rest of the
# file and reported `unexpected EOF` 380 lines later. The rotator's own header records the same
# trap. So: the caller names the directory, and mkcase echoes nothing.
mkcase() { # mkcase <dir>  <seed on stdin>
  local d="$1"
  mkdir -p "$d" || return 1
  cat > "$d/backlog.md"
  printf '# pre-existing archive\nSENTINEL-ARCHIVE-LINE\n' > "$d/backlog.archive.md"
  cp "$d/backlog.md" "$d/pristine.ledger"
  cp "$d/backlog.archive.md" "$d/pristine.archive"
}

# run_rt <script> <case-dir> [args...] -> writes combined output to $LAST_OUT, rc to $LAST_RC
LAST_OUT=""; LAST_RC=0
run_rt() {
  local s="$1" d="$2"; shift 2
  LAST_OUT="$(bash "$s" "$d/backlog.md" "$@" 2>&1)"
  LAST_RC=$?
}

# The guard reports each offender as a finding opening with `line <N>:`. Extract that set.
# Anchored on the position-bearing form on purpose: the message also carries `entry starting
# line <N>` and `fence opened at line <N>`, and a bare number match would accept the guard
# naming the WRONG line.
offender_lines() { LC_ALL=C sed -n 's/^[[:space:]]*line \([0-9][0-9]*\):.*/\1/p' <<<"$1" | tr '\n' ' '; }

has() { # has <needle> <haystack>   — here-string, never a pipe: `grep -q` exits at first match
  grep -qF -- "$1" <<<"$2"        # and pipefail turns the writer's EPIPE into a false NOT-FOUND
}

# THE UNTERMINATED-FENCE FINDING, ANCHORED ON THE FINDING AND NEVER ON THE WORDS. The remedy
# paragraph printed by EVERY refusal carries "unterminated fence in the archive", so a test for
# the bare phrase is true on every refusal this fixture can produce and could never fail. Measured
# while this arm was written: the BL-161 receipt was filed with that test and was unsatisfiable
# for that reason -- it demanded a refusal naming a line AND the absence of a phrase the refusal
# always prints. The finding form carries "opened at line"; the remedy sentence does not.
unterm_finding() { grep -q 'unterminated fence opened at line' <<<"$1"; }

# ---------------------------------------------------------------------------------------
# Seeds.
# ---------------------------------------------------------------------------------------
# OFFENDER-A — a closed entry whose ``` fence holds TWO offenders, so the "names them all" arm has
# something to count. Both are HEADINGS, deliberately: the first version fenced one heading and one
# bullet, and the bullet-blinding mutant then failed `names-all` AND `fires-bullet` together, which
# means one of the two was vacuous. `fires-bullet` owns the bullet shape; this seed owns "every
# offender in a fence is reported, and the entry heading is not", and is now shape-independent.
A="$WORK/offender-a"
mkcase "$A" <<'EOM'
# Probe backlog

Preamble that must never move.

## BL-401 — open

verify: has VERSION "."

## BL-402 — closed, and its body fences two entry-shaped lines

<br>**LANDED (v0.372.0, verified 0cadda4).** Done.

verify: has VERSION "."

The fix rewrote the example, which read:

```markdown
## BL-901 — FENCED-OFFENDER-HEADING
### BL-903 — FENCED-OFFENDER-SECOND
```

verify: has VERSION "."

## BL-403 — open, after the fenced entry

verify: lacks VERSION "."
EOM

# OFFENDER-B — the bullet shape ALONE. Separated from A so a guard that handles headings and
# not bullets fails one named arm instead of hiding inside A's pass.
B="$WORK/offender-b"
mkcase "$B" <<'EOM'
# Probe backlog

## BL-402 — closed

<br>**LANDED (v0.372.0, verified 0cadda4).** Done.

verify: has VERSION "."

```markdown
- **BL-902 — FENCED-OFFENDER-BULLET**
```

tail of BL-402.
EOM

# OFFENDER-C — a `~~~` fence. The splitter knows nothing about fences, so every fence syntax
# corrupts identically; measured on the guard-off mutant, this one too.
C="$WORK/offender-c"
mkcase "$C" <<'EOM'
# Probe backlog

## BL-402 — closed

<br>**LANDED (v0.372.0, verified 0cadda4).** Done.

verify: has VERSION "."

~~~markdown
## BL-901 — FENCED-OFFENDER-TILDE
~~~

tail of BL-402.
EOM

# OFFENDER-D — the fence sits in an OPEN entry, and holds a column-0 annotation after the
# entry-shaped line. The phantom entry promoted out of the fence is then CLOSED by an
# annotation that was only ever example text, and the open entry it came from is split. Measured
# on the guard-off mutant: the moved-entry name was `## BL-901`, i.e. the phantom.
D="$WORK/offender-d"
mkcase "$D" <<'EOM'
# Probe backlog

## BL-401 — open, and its fence holds a heading and a column-0 annotation

```markdown
## BL-901 — FENCED-OFFENDER-PHANTOM
**LANDED (v0.372.0, verified 0cadda4).** Done.

verify: has VERSION "."
```

tail of BL-401.
EOM

# OFFENDER-E — an unterminated fence, with no entry-shaped line inside it. Damage in its own
# right: the guard pairs delimiters within the span the fence-blind rule produces, and an
# unpaired one means the span boundaries are not where the file's fences are.
E="$WORK/offender-e"
mkcase "$E" <<'EOM'
# Probe backlog

## BL-402 — closed

<br>**LANDED (v0.372.0, verified 0cadda4).** Done.

verify: has VERSION "."

```markdown
this fence never closes
EOM

# OFFENDER-Q — THE TWO-QUOTATION SHAPE, and the one seed whose verdict separates a guard that
# reads the fence from one that toggles on delimiters. The fence quotes two `## BL-` headings with
# an INFO-STRING delimiter between them: CommonMark reads ` ```sh ` inside a fence as content, a
# parity toggle reads it as the closer and inverts. Under the toggle the guard named the fenced
# heading (true), then named the REAL entry after the fence (false) and an unterminated fence that
# does not exist (false) -- and its remedy told the author to strip a live entry's marker. The
# exact-set arm below is what holds all three, and every line number is derived from the seed.
Q="$WORK/quotes-two"
mkcase "$Q" <<'EOM'
# Probe backlog

## BL-401 — open

verify: lacks VERSION "."

## BL-402 — closed, and its fence quotes TWO entry headings

<br>**LANDED (v0.372.0, verified 0cadda4).** Done.

verify: has VERSION "."

```text
## BL-905 — QUOTED-FIRST
```sh
## BL-906 — QUOTED-SECOND
```

## BL-403 — REAL-ENTRY-AFTER-TWO-QUOTATIONS

verify: lacks VERSION "."
EOM

# PROSE-FENCE — the ALLOW twin of OFFENDER-Q, one property apart: the fenced heading carries no
# id, so the split never cuts there and the rotation must SUCCEED with a real entry sitting after
# the fence. A DENY arm alone cannot tell a guard that reads the label from one that refuses every
# fence holding a heading, and the header records that narrowing as the one whose false-positive
# set was non-empty before it. Asserted as the ROTATION OUTCOME, never as the absence of the
# refusal message: a refusal writes nothing, so an empty archive fails this arm by construction.
PF="$WORK/prose-fence"
mkcase "$PF" <<'EOM'
# Probe backlog

## BL-402 — closed, and its fence quotes an id-less heading

<br>**LANDED (v0.372.0, verified 0cadda4).** Done.

verify: has VERSION "."

```markdown
## Some prose heading, not a BL- label
```

PROSE-FENCE-TAIL — this line must move with the entry.

## BL-403 — open, and it must stay a live entry after the fence

verify: lacks VERSION "."
EOM

# UNTERM-QUOTES — an unterminated fence that quotes an entry heading, with a real entry after it.
# Per CommonMark the fence swallows both, so a whole-file pairing that emitted a per-line finding
# for everything it holds would name the real entry -- the same wrong remedy one shape along. The
# guard reports the unterminated fence ONCE and emits no per-line finding for a fence it never saw
# close; the file is still refused, by that line.
UQ="$WORK/unterm-quotes"
mkcase "$UQ" <<'EOM'
# Probe backlog

## BL-402 — closed, and its unterminated fence quotes an entry heading

<br>**LANDED (v0.372.0, verified 0cadda4).** Done.

verify: has VERSION "."

```markdown
## BL-907 — QUOTED-IN-AN-UNTERMINATED-FENCE

## BL-403 — REAL-ENTRY-AFTER-THE-UNTERMINATED-FENCE
EOM

# ---------------------------------------------------------------------------------------
# THE COLUMN AXIS. Every delimiter in the seeds above sits at column 0, so none of them can
# separate a guard that reads a delimiter's POSITION from one that strips the indent and looks at
# what is left. These five add that axis: past column three, a tab, behind a blockquote marker, a
# carriage return, and the three-space near-miss CommonMark still honours.
# ---------------------------------------------------------------------------------------
# DELIM-INDENT — THE ATTACK LEDGER, and it is an OFFENDER seed by the same admission rule as the
# others: run against a rotator with the position finding removed it APPLIES, exit 0, leaving the
# archive inside an unclosed ```text fence and `## BL-500` promoted into the live file. Two bare
# delimiters at eight columns close and reopen a fence the boundary rule believes in and
# CommonMark does not, so the parity comes back even and the guard sees no fence at all.
DI="$WORK/delim-indent"
mkcase "$DI" <<'EOM'
# Probe backlog

## BL-402 — closed, and its fence quotes an indented delimiter

<br>**LANDED (v0.372.0, verified 0cadda4).** Done.

verify: has VERSION "."

```text
        ```
## BL-500 — INSIDE the fence in CommonMark, outside it to a stripping reader
        ```
```

DELIM-INDENT-TAIL — the line the corrupting split strands.
EOM

# DELIM-TAB — the same class spelled with a TAB, which is four columns to CommonMark and one
# character to anything counting characters. A guard measuring length rather than columns passes
# this and fails only the eight-space twin.
DT="$WORK/delim-tab"; mkdir -p "$DT"
printf '%s\n' \
  '# Probe backlog' \
  '' \
  '## BL-402 — closed, and its fence quotes a tab-indented delimiter' \
  '' \
  '<br>**LANDED (v0.372.0, verified 0cadda4).** Done.' \
  '' \
  'verify: has VERSION "."' \
  '' \
  '```text' \
  $'\t```' \
  '## BL-500 — INSIDE the fence in CommonMark' \
  $'\t```' \
  '```' \
  '' \
  'DELIM-TAB-TAIL — the line the corrupting split strands.' \
  > "$DT/backlog.md"

# DELIM-BQ — a delimiter behind a blockquote marker. The divergence runs the other way here: the
# boundary rule cannot see it at all and CommonMark can, so the fence the reader believes in and
# the fence the file declares are different fences.
DB="$WORK/delim-blockquote"
mkcase "$DB" <<'EOM'
# Probe backlog

## BL-402 — closed, and its body quotes a blockquoted fence

<br>**LANDED (v0.372.0, verified 0cadda4).** Done.

verify: has VERSION "."

> ```text
> a fence the boundary rule cannot see
> ```

DELIM-BQ-TAIL — this line must not move under a refusal.
EOM

# DELIM-CRLF — CRLF endings. The closer test matches a delimiter followed by BLANKS to end of
# line, and a carriage return is not blank, so a fence that does close is reported unterminated at
# its OPENER while the real finding sits a line below. The file is refused either way; the
# position finding is what names the cause the operator can act on.
DC="$WORK/delim-crlf"; mkdir -p "$DC"
printf '# Probe backlog\r\n\r\n## BL-402 — closed, with CRLF endings\r\n\r\n<br>**LANDED (v0.372.0, verified 0cadda4).** Done.\r\n\r\nverify: has VERSION "."\r\n\r\n```text\r\n## BL-500 — quoted\r\n```\r\n\r\nDELIM-CRLF-TAIL — the line the corrupting split strands.\r\n' > "$DC/backlog.md"

# DELIM-3SP — THE NEAR-MISS, one column short of the offender. CommonMark honours a delimiter up
# to three columns of indentation, so this ledger is well-formed and must ROTATE. Without it the
# position finding could be `any indent at all` and every arm above would still pass.
D3="$WORK/delim-three-space"
mkcase "$D3" <<'EOM'
# Probe backlog

## BL-402 — closed, and its fence is indented three columns

<br>**LANDED (v0.372.0, verified 0cadda4).** Done.

verify: has VERSION "."

   ```text
   three columns, which CommonMark still honours
   ```

DELIM-3SP-TAIL — this line must move with the entry.
EOM

# The two printf-built seeds need the same pre-existing archive and pristine copies `mkcase`
# makes, or `reseed` and the wrote-nothing byte-comparison have nothing to compare against.
for _d in "$DT" "$DC"; do
  printf '# pre-existing archive\nSENTINEL-ARCHIVE-LINE\n' > "$_d/backlog.archive.md"
  cp "$_d/backlog.md" "$_d/pristine.ledger"
  cp "$_d/backlog.archive.md" "$_d/pristine.archive"
done

# NEAR-MISS — every line here is inside a fence in a CLOSED entry and every one of them merely
# RESEMBLES an entry boundary. A backlog quoting markdown carries these constantly, so a guard
# that refuses this file is one the operator switches off. Rotation must SUCCEED.
NM="$WORK/near-miss"; mkdir -p "$NM"
printf '%s\n' \
  '# Probe backlog' \
  '' \
  '## BL-402 — closed, and its fence holds only near-misses' \
  '' \
  '<br>**LANDED (v0.372.0, verified 0cadda4).** Done.' \
  '' \
  'verify: has VERSION "."' \
  '' \
  '```markdown' \
  '#BL-9 — one hash, no space' \
  '  ## BL-9 — indented two spaces' \
  "$(printf '\t## BL-9 — indented with a tab')" \
  '## Some prose heading, not a BL- label' \
  '- **not a BL bullet at all**' \
  '####### BL-9 — seven hashes' \
  'see ## BL-9 mid-line' \
  '- **BL: no digits after the dash**' \
  '```' \
  '' \
  'NEAR-MISS-TAIL — this line must move with the entry.' \
  > "$NM/backlog.md"
printf '# pre-existing archive\nSENTINEL-ARCHIVE-LINE\n' > "$NM/backlog.archive.md"
cp "$NM/backlog.md" "$NM/pristine.ledger"

# NESTED — a four-backtick fence displaying a three-backtick fence. Legal CommonMark, and the
# delimiter pairing must not read the inner pair as an unbalanced outer one.
N="$WORK/nested"
mkcase "$N" <<'EOM'
# Probe backlog

## BL-402 — closed

<br>**LANDED (v0.372.0, verified 0cadda4).** Done.

verify: has VERSION "."

````markdown
```sh
echo "an inner fence, displayed"
```
````

NESTED-TAIL — this line must move with the entry.
EOM

# HEALTHY — a balanced fence with nothing entry-shaped in it, plus a tail AFTER the fence. The
# tail is the byte the defect strands: it is what stays behind in the live file when the archive
# stops at the opening delimiter.
H="$WORK/healthy"
mkcase "$H" <<'EOM'
# Probe backlog

Preamble that must never move.

## BL-401 — open

verify: lacks VERSION "."

## BL-402 — closed, balanced fence, nothing entry-shaped inside

<br>**LANDED (v0.372.0, verified 0cadda4).** Done.

verify: has VERSION "."

```sh
grep -n 'nothing entry-shaped here' "$f"
```

HEALTHY-TAIL — the line after the fence, which the defect strands.

verify: has VERSION "."
EOM

reseed() { cp "$1/pristine.ledger" "$1/backlog.md"; cp "$1/pristine.archive" "$1/backlog.archive.md"; }
# COUNT THE DELIMITERS CommonMark HONOURS, WHICH IS NOT EVERY LINE THAT LOOKS LIKE ONE. This read
# `^[ \t]*\(```\|~~~\)` -- the same unbounded strip the subject used to have, and therefore blind
# to the class it is now asked to guard: on the eight-space attack ledger it counted live=2
# archive=2 and called a genuinely corrupt pair balanced. A delimiter is honoured up to three
# columns of indentation, tab counting as four.
fences() {
  local n
  n="$(LC_ALL=C awk '
    function cols(s,   i, c, ch) {
      c = 0
      for (i = 1; i <= length(s); i++) {
        ch = substr(s, i, 1)
        if (ch == " ") c += 1
        else if (ch == "\t") c += 4
        else break
      }
      return c
    }
    {
      lead = $0; sub(/[^ \t].*$/, "", lead)
      t = $0; sub(/^[ \t]+/, "", t)
      if ((t ~ /^```+/ || t ~ /^~~~+/) && cols(lead) <= 3) n++
    }
    END { print n+0 }' "$1" 2>/dev/null)" || n=0
  printf '%s' "${n:-0}"
}
conserved() { # every input line in exactly one output file, as a MULTISET not a count
  local d="$1"
  LC_ALL=C sort "$d/pristine.ledger" > "$d/exp.sorted"
  { cat "$d/backlog.md"; tail -n +3 "$d/backlog.archive.md"; } | LC_ALL=C sort > "$d/got.sorted"
  cmp -s "$d/exp.sorted" "$d/got.sorted"
}
expect_refusal() { # expect_refusal <arm> <dir> [args to rotate]
  local arm="$1" dd="$2"; shift 2
  run_rt "$RT" "$dd" "$@"
  if [ "$LAST_RC" -eq 0 ]; then
    bad "$arm" "exited 0 on a ledger measured to corrupt: $(printf '%s' "$LAST_OUT" | head -2 | tr '\n' '|')"
    return 1
  fi
  if ! has "REFUSING" "$LAST_OUT"; then
    bad "$arm" "exit $LAST_RC but the operator was told nothing: $LAST_OUT"
    return 1
  fi
  ok "$arm" "refused with exit $LAST_RC"
  return 0
}

# ---------------------------------------------------------------------------------------
# The guard FIRES.
# ---------------------------------------------------------------------------------------
run_rt "$RT" "$A" --apply
if [ -z "$LAST_OUT" ]; then
  echo "FIXTURE BROKEN: backlog-rotate.sh emitted nothing at all on the offender seed. Every" >&2
  echo "assertion below reads that output, so this is a dead harness, not a regression." >&2
  exit 2
fi
ok "harness" "the rotator emitted output on the offender seed (exit $LAST_RC)"

A_OUT="$LAST_OUT"; A_RC="$LAST_RC"
if [ "$A_RC" -eq 0 ]; then
  bad "fires-heading" "exited 0 on the measured-corrupting seed: $(printf '%s' "$A_OUT" | head -2 | tr '\n' '|')"
elif ! has "REFUSING" "$A_OUT"; then
  bad "fires-heading" "exit $A_RC but no refusal reached the operator: $A_OUT"
else
  ok "fires-heading" "refused with exit $A_RC"
fi

# NAMES THEM ALL, AND NAMES THE RIGHT ONES. Both fenced lines must be reported, and the real
# entry heading must NOT be reported as an offender — a guard that flags the entry start instead
# of the fenced line refuses the same files and tells the operator to edit the wrong one.
EXP_H="$(LC_ALL=C grep -n 'FENCED-OFFENDER-HEADING' "$A/pristine.ledger" | cut -d: -f1)"
EXP_B="$(LC_ALL=C grep -n 'FENCED-OFFENDER-SECOND'  "$A/pristine.ledger" | cut -d: -f1)"
GOOD="$(LC_ALL=C grep -n '^## BL-402' "$A/pristine.ledger" | cut -d: -f1)"
GOT="$(offender_lines "$A_OUT")"
if [ -z "$EXP_H" ] || [ -z "$EXP_B" ] || [ -z "$GOOD" ]; then
  echo "FIXTURE BROKEN: could not derive the seeded line numbers from $A/pristine.ledger" >&2
  exit 2
fi
AFTER_A="$(LC_ALL=C grep -n '^## BL-403' "$A/pristine.ledger" | cut -d: -f1)"
if [ -z "$AFTER_A" ]; then
  echo "FIXTURE BROKEN: could not derive the post-fence entry line from $A/pristine.ledger" >&2
  exit 2
fi
# AN EXACT SET, NOT TWO PRESENCES AND ONE ABSENCE. This seed's two quotations are ADJACENT, which
# is the arrangement that desynchronises a tracker keyed on the delimiter line rather than on the
# fence: the closer then reads as an opener and every line after it, `## BL-403` included, reads
# as fenced. Naming an extra line is the failure, so the assertion has to be able to see one.
if [ "$GOT" = "$EXP_H $EXP_B " ]; then
  ok "names-all" "exactly the two fenced offenders are named ($EXP_H, $EXP_B); neither the entry heading at $GOOD nor the entry after the fence at $AFTER_A is"
elif has " $AFTER_A " " $GOT "; then
  bad "names-all" "the real entry AFTER the fence, at line $AFTER_A, is named as fenced — the fence state carried past its own closer; got: [$GOT]"
elif has " $GOOD " " $GOT "; then
  bad "names-all" "the real entry heading at line $GOOD is named as an offender; got: [$GOT]"
elif ! has " $EXP_H " " $GOT "; then
  bad "names-all" "the fenced heading at line $EXP_H is not named as an offender; got: [$GOT]"
elif ! has " $EXP_B " " $GOT "; then
  bad "names-all" "the SECOND fenced heading at line $EXP_B is not named; only the first is reported, so a fence holding several offenders sends the operator back for a second run — got: [$GOT]"
else
  bad "names-all" "expected exactly [$EXP_H $EXP_B]; got: [$GOT]"
fi

# WROTE NOTHING, BYTE-COMPARED. Not eyeballed, and against an archive that ALREADY had content:
# an archive the refusal merely failed to create is a weaker claim than one it failed to append
# to, and appending is what --apply does.
if ! cmp -s "$A/backlog.md" "$A/pristine.ledger"; then
  bad "no-write" "the refused --apply modified the ledger"
elif ! cmp -s "$A/backlog.archive.md" "$A/pristine.archive"; then
  bad "no-write" "the refused --apply modified the pre-existing archive"
else
  ok "no-write" "ledger and pre-existing archive byte-identical after the refused --apply"
fi

expect_refusal "fires-bullet" "$B" --apply
expect_refusal "fires-tilde"  "$C" --apply
expect_refusal "fires-phantom" "$D" --apply
expect_refusal "fires-unterm" "$E" --apply

# THE TWO-QUOTATION SHAPE, AS AN EXACT SET. Not "the offenders are named" — the SET of named
# lines, because the defect this seed exists for is an EXTRA name, not a missing one. Every
# number is derived from the seed by content, so a line inserted above shifts expectation and
# observation together.
EXP_Q1="$(LC_ALL=C grep -n 'QUOTED-FIRST'  "$Q/pristine.ledger" | cut -d: -f1)"
EXP_Q2="$(LC_ALL=C grep -n 'QUOTED-SECOND' "$Q/pristine.ledger" | cut -d: -f1)"
REAL_Q="$(LC_ALL=C grep -n 'REAL-ENTRY-AFTER-TWO-QUOTATIONS' "$Q/pristine.ledger" | cut -d: -f1)"
if [ -z "$EXP_Q1" ] || [ -z "$EXP_Q2" ] || [ -z "$REAL_Q" ]; then
  echo "FIXTURE BROKEN: could not derive the seeded line numbers from $Q/pristine.ledger" >&2
  exit 2
fi
expect_refusal "quotes-two" "$Q" --apply
Q_OUT="$LAST_OUT"
Q_GOT="$(offender_lines "$Q_OUT")"
if [ "$Q_GOT" = "$EXP_Q1 $EXP_Q2 " ]; then
  ok "quotes-two-names" "exactly the two quoted headings ($EXP_Q1, $EXP_Q2) are named; the real entry at $REAL_Q is not"
elif has " $REAL_Q " " $Q_GOT "; then
  bad "quotes-two-names" "the REAL entry at line $REAL_Q is named as fenced, so the remedy tells the author to strip a live entry's marker; got [$Q_GOT], expected [$EXP_Q1 $EXP_Q2]"
else
  bad "quotes-two-names" "expected exactly the two quoted headings [$EXP_Q1 $EXP_Q2]; got [$Q_GOT]"
fi
if unterm_finding "$Q_OUT"; then
  bad "quotes-two-unterm" "an unterminated fence was reported on a ledger whose every fence closes — the delimiter between the two quotations was read as a closer"
else
  ok "quotes-two-unterm" "no unterminated-fence finding: the info-string delimiter inside the fence is content, not a closer"
fi

# AN UNTERMINATED FENCE IS REPORTED ONCE, AND NAMES NO LINE. Whole-file pairing makes every line
# after an unterminated opener fenced, real entries included; emitting a per-line finding for each
# would be the wrong remedy at scale.
expect_refusal "unterm-quotes" "$UQ" --apply
UQ_OUT="$LAST_OUT"
UQ_GOT="$(offender_lines "$UQ_OUT")"
if ! unterm_finding "$UQ_OUT"; then
  bad "unterm-quotes-once" "a fence that never closes was not reported as unterminated: $UQ_OUT"
elif [ -n "$UQ_GOT" ]; then
  bad "unterm-quotes-once" "a fence that never closes produced per-line findings [$UQ_GOT]; the entry after it is a real entry and the remedy names it"
else
  ok "unterm-quotes-once" "the unterminated fence is reported once, and no line it swallows is named"
fi

# ---------------------------------------------------------------------------------------
# THE POSITION FINDING. Each arm derives the lines it expects from the seed's own signature, so
# the expectation and the observation are two derivations of one fact rather than a number typed
# twice, and each asserts the refused --apply wrote NOTHING -- byte-compared against an archive
# that already had content.
# ---------------------------------------------------------------------------------------
DELIM_SAYS="cannot agree about what is fenced"
expect_delim_refusal() { # <arm> <dir> <regex matching the seed's own delimiter lines>
  local arm="$1" dd="$2" sig="$3" exp got
  exp="$(LC_ALL=C grep -n -- "$sig" "$dd/pristine.ledger" | cut -d: -f1 | tr '\n' ' ')"
  if [ -z "$exp" ]; then
    echo "FIXTURE BROKEN: the seed signature [$sig] matches no line in $dd/pristine.ledger" >&2
    exit 2
  fi
  run_rt "$RT" "$dd" --apply
  got="$(offender_lines "$LAST_OUT")"
  if [ "$LAST_RC" -eq 0 ]; then
    bad "$arm" "exited 0 on a ledger whose delimiter positions the two readers disagree about"; return 1
  elif ! has "$DELIM_SAYS" "$LAST_OUT"; then
    bad "$arm" "refused, but not by the position finding — the operator is handed the wrong remedy: $LAST_OUT"; return 1
  elif [ "$got" != "$exp" ]; then
    bad "$arm" "expected exactly the seeded delimiter lines [$exp]; got [$got]"; return 1
  elif ! cmp -s "$dd/backlog.md" "$dd/pristine.ledger" || ! cmp -s "$dd/backlog.archive.md" "$dd/pristine.archive"; then
    bad "$arm" "the refused --apply wrote to disk"; return 1
  else
    ok "$arm" "refused by position, naming exactly [$got], and wrote nothing"; return 0
  fi
}
expect_delim_refusal "delim-indent"     "$DI" '^        ```'
expect_delim_refusal "delim-tab"        "$DT" "$(printf '^\t```')"
expect_delim_refusal "delim-blockquote" "$DB" '^> ```'
expect_delim_refusal "delim-crlf"       "$DC" '^```'

# REPORT MODE MUST REFUSE TOO. A report that says "1 closed entry would move" and exits 0 is an
# instruction to the operator to run --apply, which is the corrupting call.
reseed "$A"
expect_refusal "fires-report" "$A"

# ---------------------------------------------------------------------------------------
# The guard STAYS QUIET. One direction alone leaves a scan that flags everything looking
# identical to a scan that discriminates.
# ---------------------------------------------------------------------------------------
run_rt "$RT" "$NM" --apply
if [ "$LAST_RC" -ne 0 ] || has "REFUSING" "$LAST_OUT"; then
  bad "near-miss" "refused a ledger whose fence holds only near-misses: $LAST_OUT"
elif ! has "SENTINEL-ARCHIVE-LINE" "$(cat "$NM/backlog.archive.md")"; then
  bad "near-miss" "the pre-existing archive content was lost"
elif ! has "NEAR-MISS-TAIL" "$(cat "$NM/backlog.archive.md")"; then
  bad "near-miss" "rotation succeeded but the entry's tail did not reach the archive"
else
  ok "near-miss" "eight near-miss shapes in a fence do not block a normal rotation"
fi

# THE ALLOW TWIN OF THE TWO-QUOTATION SEED, ONE PROPERTY APART: the fenced heading carries no id.
# Asserted as the OUTCOME of the rotation, never as the absence of the refusal message — a refusal
# writes nothing, so an archive without the moved tail fails this by construction, and a subject
# that emits nothing fails it too.
run_rt "$RT" "$PF" --apply
PF_ARCH="$(cat "$PF/backlog.archive.md")"
PF_LIVE="$(cat "$PF/backlog.md")"
if ! has "PROSE-FENCE-TAIL" "$PF_ARCH"; then
  bad "prose-fence" "the closed entry whose fence quotes an id-less heading did not reach the archive (exit $LAST_RC): $LAST_OUT"
elif has "BL-402" "$PF_LIVE"; then
  bad "prose-fence" "the closed entry is still in the live ledger"
elif ! has "BL-403" "$PF_LIVE"; then
  bad "prose-fence" "the real entry AFTER the fence did not stay live"
elif has "BL-403" "$PF_ARCH"; then
  bad "prose-fence" "the real entry AFTER the fence was swept into the archive with the closed one — the fence swallowed the boundary between them"
else
  ok "prose-fence" "a fence quoting an id-less heading rotates, tail included, and the entry after it stays live"
fi

# THE NEAR-MISS OF THE POSITION FINDING, ONE COLUMN SHORT. CommonMark honours a delimiter up to
# three columns, so this ledger is well-formed and must rotate. Asserted as the OUTCOME: a
# refusal writes nothing, so an archive without the tail fails this by construction.
run_rt "$RT" "$D3" --apply
D3_ARCH="$(cat "$D3/backlog.archive.md")"
if ! has "DELIM-3SP-TAIL" "$D3_ARCH"; then
  bad "delim-three-space" "a fence indented three columns, which CommonMark honours, did not rotate (exit $LAST_RC): $LAST_OUT"
elif has "BL-402" "$(cat "$D3/backlog.md")"; then
  bad "delim-three-space" "the closed entry is still in the live ledger"
else
  ok "delim-three-space" "a delimiter at three columns is honoured, not refused — the finding starts at four"
fi

run_rt "$RT" "$N" --apply
if [ "$LAST_RC" -ne 0 ] || has "REFUSING" "$LAST_OUT"; then
  bad "nested-fence" "refused a legal four-backtick fence displaying a three-backtick one: $LAST_OUT"
elif ! has "NESTED-TAIL" "$(cat "$N/backlog.archive.md")"; then
  bad "nested-fence" "rotation succeeded but the entry's tail did not reach the archive"
else
  ok "nested-fence" "a nested fence pairs evenly and does not block rotation"
fi

# ---------------------------------------------------------------------------------------
# A healthy ledger still rotates, in FULL.
# ---------------------------------------------------------------------------------------
run_rt "$RT" "$H" --apply
H_ARCH="$(cat "$H/backlog.archive.md")"
H_LIVE="$(cat "$H/backlog.md")"
if [ "$LAST_RC" -ne 0 ]; then
  bad "healthy" "a balanced fence with nothing entry-shaped inside was refused: $LAST_OUT"
elif ! has "HEALTHY-TAIL" "$H_ARCH"; then
  bad "healthy" "the line AFTER the fence was stranded — this is the defect's signature"
elif has "BL-402" "$H_LIVE"; then
  bad "healthy" "the closed entry is still in the live ledger"
elif ! has "BL-401" "$H_LIVE" || ! has "must never move" "$H_LIVE"; then
  bad "healthy" "an open entry or the preamble was swept"
else
  ok "healthy" "the closed entry moved in full, tail included"
fi

# FENCE BALANCE — the property the defect actually violates, measured. Under the guard-off
# mutant on OFFENDER-A this comes out 1 and 1; here both sides must be even and must sum to the
# input's count.
HF_IN="$(fences "$H/pristine.ledger")"
HF_LIVE="$(fences "$H/backlog.md")"
HF_ARCH="$(fences "$H/backlog.archive.md")"
if [ $((HF_LIVE % 2)) -ne 0 ] || [ $((HF_ARCH % 2)) -ne 0 ]; then
  bad "fence-balance" "an output file carries an unterminated fence: live=$HF_LIVE archive=$HF_ARCH"
elif [ "$((HF_LIVE + HF_ARCH))" -ne "$HF_IN" ]; then
  bad "fence-balance" "fence delimiters were gained or lost: $HF_IN in, $HF_LIVE + $HF_ARCH out"
else
  ok "fence-balance" "both outputs carry an even fence count summing to the input's $HF_IN"
fi

# CONSERVATION. A multiset, not a count — a count is satisfied by two lines swapping files.
if conserved "$H"; then
  ok "conservation" "every input line is in exactly one output file"
else
  bad "conservation" "$(diff "$H/exp.sorted" "$H/got.sorted" | head -6 | tr '\n' '|')"
fi

# ---------------------------------------------------------------------------------------
# THE LIVE-CORPUS ARM IS DELIBERATELY ABSENT, AND THIS IS THE REASON RATHER THAN AN OVERSIGHT.
# It was written first: copy docs/backlog.md out of the tree, run the guard on the copy in report
# mode, assert it is classified rather than refused. `I55` in validate-enforcement-map.sh failed
# the push on it, and correctly — `docs/` is excluded from the suite content key, so a fixture
# reading it is one whose input can change without the suite ever re-running, and its clean line
# would then be a stale reading of a corpus nobody re-scanned.
#
# WHAT WAS MEASURED, AND IT IS NOT RE-MEASURED HERE. Run by hand while authoring this fixture:
# the repository's own docs/backlog.md is classified, not refused (`nothing to move`), so the
# false-positive set over the live corpus was EMPTY. That is a measurement, not a check; the
# standing false-positive battery is the `near-miss` and `nested-fence` arms above, which is
# where a new shape should be added when one is found.
# ---------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------
# PHANTOM — a prose lead-in bullet inside a CLOSED entry is body text, not an entry (BL-820).
# BL-402 is closed and carries `- **BL-632 is LANDED** prose` BEFORE its receipt; BL-404 below it
# is an OPEN entry in the legitimate list form `- **BL-404** — t`. The fix moves BL-402 whole
# (the bullet with it) and leaves BL-404 live. Measured on each mutant before these arms were
# written: m-loose splits BL-402, its receipt travels to the phantom, and the EVIDENCE arm refuses
# (BL-402 NEEDS-REVIEW, no receipt); m-heading-only stops labelling BL-404, so the closed entry
# swallows it and the open entry is ARCHIVED at exit 0.
# ---------------------------------------------------------------------------------------
PH="$WORK/phantom"
mkcase "$PH" <<'EOM'
# Probe backlog

## BL-402 — closed host, whose body opens a bold lead-in bullet

<br>**LANDED (v0.372.0, verified 0cadda4).** Done.

- **BL-632 is LANDED** prose about another entry

verify: has VERSION "."

- **BL-404** — open list entry

verify: lacks VERSION "."

## BL-403 — open heading entry

verify: lacks VERSION "."
EOM
ph_split_ok() { # the phantom moved with its host, the open list entry stayed live
  grep -qxF -- '- **BL-632 is LANDED** prose about another entry' "$PH/backlog.archive.md" \
    && grep -q '^## BL-402 ' "$PH/backlog.archive.md" \
    && grep -qxF -- '- **BL-404** — open list entry' "$PH/backlog.md" \
    && ! grep -qF 'BL-404' "$PH/backlog.archive.md"
}
reseed "$PH"; run_rt "$RT" "$PH" --apply
if [ "$LAST_RC" -eq 0 ] && ph_split_ok && conserved "$PH"; then
  ok "phantom-bullet" "a closed entry carrying a '- **BL-632 is LANDED**' lead-in moves whole, and the open list entry BL-404 stays live"
else
  bad "phantom-bullet" "exit $LAST_RC; the host, its lead-in and the open list entry did not split as one closed entry and one live: $(printf '%s' "$LAST_OUT" | grep -E 'REFUSING|BL-' | head -3 | tr '\n' '|')"
fi

# SECTION SPAN (BL-824). A `##` heading carrying no BL- label is a ledger SECTION at the entries'
# own level, so it ends the span of the closed entry above it: the heading and its prose stay live.
# Three worlds, every one asserted as the rotation OUTCOME (what landed in which file), never as the
# absence of a message:
#   SEC-MID   closed entry, then a section, then a live entry   -> section live, closed archived
#   SEC-EOF   live entry, closed entry, then a section at EOF   -> section live (no next entry to stop it)
#   SUB-IN    a `###` subheading INSIDE a closed entry          -> moves WITH its entry (the near-miss:
#             a span that ended at ANY heading would strand it, so this world kills an over-wide fix)
# The prose-fence world above is the other near-miss: a FENCED `## prose` line stays in its entry.
SM="$WORK/sec-mid"
mkcase "$SM" <<'EOM'
# Probe backlog

## BL-501 — closed

<br>**LANDED (v0.372.0, verified 0cadda4).** Done.

verify: has VERSION "."

## Efficiency regression after the ranked set

SECTION-MID-SENTINEL — this prose belongs to the section and must stay live.

## BL-502 — open

verify: lacks VERSION "."
EOM
SE="$WORK/sec-eof"
mkcase "$SE" <<'EOM'
# Probe backlog

## BL-503 — open

verify: lacks VERSION "."

## BL-504 — closed

<br>**LANDED (v0.372.0, verified 0cadda4).** Done.

verify: has VERSION "."

## A trailing section

SECTION-EOF-SENTINEL — the last lines of the file, with no entry after them.
EOM
SI="$WORK/sub-in"
mkcase "$SI" <<'EOM'
# Probe backlog

## BL-505 — closed, with a subheading in its body

<br>**LANDED (v0.372.0, verified 0cadda4).** Done.

### A subheading inside the entry

SUBHEAD-SENTINEL — body text under the subheading, part of the closed entry.

verify: has VERSION "."

## BL-506 — open

verify: lacks VERSION "."
EOM
SR="$WORK/sec-reopened"
mkcase "$SR" <<'EOM'
# Probe backlog

## BL-507 — closed

<br>**LANDED (v0.372.0, verified 0cadda4).** Done.

verify: has VERSION "."

## Reopened by BL-817's re-audit (batch 243)

SECTION-REOPENED-SENTINEL — a section whose heading names a BL- id later in the prose; it stays live.

## BL-508 — open

verify: lacks VERSION "."
EOM
sec_reopened_ok() {
  grep -qxF "## Reopened by BL-817's re-audit (batch 243)" "$SR/backlog.md" && grep -q 'SECTION-REOPENED-SENTINEL' "$SR/backlog.md" \
    && ! grep -q 'SECTION-REOPENED-SENTINEL' "$SR/backlog.archive.md" && ! grep -qF 'Reopened by BL-817' "$SR/backlog.archive.md" \
    && grep -q '^## BL-507 ' "$SR/backlog.archive.md" && grep -q '^## BL-508 ' "$SR/backlog.md"
}
sec_mid_ok() {
  grep -qx '## Efficiency regression after the ranked set' "$SM/backlog.md" && grep -q 'SECTION-MID-SENTINEL' "$SM/backlog.md" \
    && ! grep -q 'SECTION-MID-SENTINEL' "$SM/backlog.archive.md" && grep -q '^## BL-501 ' "$SM/backlog.archive.md" \
    && grep -q '^## BL-502 ' "$SM/backlog.md"
}
sec_eof_ok() {
  grep -qx '## A trailing section' "$SE/backlog.md" && grep -q 'SECTION-EOF-SENTINEL' "$SE/backlog.md" \
    && ! grep -q 'SECTION-EOF-SENTINEL' "$SE/backlog.archive.md" && grep -q '^## BL-504 ' "$SE/backlog.archive.md"
}
sub_in_ok() {
  grep -q 'SUBHEAD-SENTINEL' "$SI/backlog.archive.md" && grep -qx '### A subheading inside the entry' "$SI/backlog.archive.md" \
    && ! grep -q 'SUBHEAD-SENTINEL' "$SI/backlog.md" && grep -q '^## BL-506 ' "$SI/backlog.md"
}
reseed "$SM"; run_rt "$RT" "$SM" --apply
if [ "$LAST_RC" -eq 0 ] && sec_mid_ok && conserved "$SM"; then
  ok "section-mid" "a section between a closed and a live entry stays live; the closed entry alone is archived"
else
  bad "section-mid" "exit $LAST_RC; the section between BL-501 and BL-502 did not stay live: $(printf '%s' "$LAST_OUT" | head -2 | tr '\n' '|')"
fi
reseed "$SE"; run_rt "$RT" "$SE" --apply
if [ "$LAST_RC" -eq 0 ] && sec_eof_ok && conserved "$SE"; then
  ok "section-eof" "a section after the last closed entry, at EOF, stays live"
else
  bad "section-eof" "exit $LAST_RC; the trailing section was archived with BL-504: $(printf '%s' "$LAST_OUT" | head -2 | tr '\n' '|')"
fi
reseed "$SR"; run_rt "$RT" "$SR" --apply
if [ "$LAST_RC" -eq 0 ] && sec_reopened_ok && conserved "$SR"; then
  ok "section-reopened" "a section whose heading names a BL- id after its first token stays live"
else
  bad "section-reopened" "exit $LAST_RC; the Reopened-by-BL-817 section did not stay live: $(printf '%s' "$LAST_OUT" | head -2 | tr '\n' '|')"
fi
reseed "$SI"; run_rt "$RT" "$SI" --apply
if [ "$LAST_RC" -eq 0 ] && sub_in_ok && conserved "$SI"; then
  ok "subhead-in-entry" "a ### subheading inside a closed entry moves with it"
else
  bad "subhead-in-entry" "exit $LAST_RC; the ### subheading did not move with BL-505"
fi

# OUTCOME GUARD (BL-817). A closed entry tagged `**DEFECT (efficiency).**` with no line opening
# `Outcome measured:` is refused and nothing is written; the same entry with the line rotates.
# One property apart, so a guard refusing every tagged close fails the second world.
OUTCOME_SAYS="an efficiency close carries no outcome line"
EO="$WORK/eff-no-outcome"
mkcase "$EO" <<'EOM'
# Probe backlog

## BL-601 — closed efficiency entry with no outcome

**DEFECT (efficiency).** A step costs too much.

<br>**LANDED (v0.372.0, verified 0cadda4).** Done.

verify: has VERSION "."

## BL-602 — open

verify: lacks VERSION "."
EOM
EY="$WORK/eff-outcome"
mkcase "$EY" <<'EOM'
# Probe backlog

## BL-601 — closed efficiency entry with its outcome

**DEFECT (efficiency).** A step costs too much.

<br>**LANDED (v0.372.0, verified 0cadda4).** Done.

Outcome measured: graph s321, per story 1.0 h to 0.5 h gap-inclusive; fell.

verify: has VERSION "."

## BL-602 — open

verify: lacks VERSION "."
EOM
reseed "$EO"; run_rt "$RT" "$EO" --apply
if [ "$LAST_RC" -eq 2 ] && has "$OUTCOME_SAYS" "$LAST_OUT" && has "BL-601" "$LAST_OUT" \
   && cmp -s "$EO/backlog.md" "$EO/pristine.ledger" && cmp -s "$EO/backlog.archive.md" "$EO/pristine.archive"; then
  ok "outcome-refused" "a tagged efficiency close with no Outcome measured: line is refused by name and nothing is written"
else
  bad "outcome-refused" "exit $LAST_RC; the tagged close without an outcome line was not refused by the outcome arm"
fi
reseed "$EY"; run_rt "$RT" "$EY" --apply
if [ "$LAST_RC" -eq 0 ] && grep -q '^## BL-601 ' "$EY/backlog.archive.md" && ! has "$OUTCOME_SAYS" "$LAST_OUT"; then
  ok "outcome-carried" "the same close carrying its Outcome measured: line rotates"
else
  bad "outcome-carried" "exit $LAST_RC; a tagged close WITH its outcome line did not rotate"
fi

# OUTCOME GUARD, EVERY TAG SPELLING (BL-835). The guard keyed on `**DEFECT (efficiency).**` alone
# while the ledgers carry three more forms; each is its own world so one form refusing cannot
# carry another. The near-miss world closes two untagged entries whose bold spans carry the word
# `efficiency` (prose bold, and a DEFECT tier with the word after it) and must rotate.
eff_form_world() { # eff_form_world <dir> <tag line>
  mkcase "$1" <<EOM
# Probe backlog

## BL-603 — closed efficiency entry, other spelling, no outcome

$2 A step costs too much.

<br>**LANDED (v0.372.0, verified 0cadda4).** Done.

verify: has VERSION "."

## BL-604 — open

verify: lacks VERSION "."
EOM
}
EF1="$WORK/eff-form-comma";  eff_form_world "$EF1" '**DEFECT, efficiency.**'
EF2="$WORK/eff-form-note";   eff_form_world "$EF2" '**NOTE (efficiency).**'
EF3="$WORK/eff-form-rank";   eff_form_world "$EF3" '**DEFECT. [efficiency rank 3] $12, 40 agent-minutes.**'
for EFW in "$EF1" "$EF2" "$EF3"; do
  reseed "$EFW"; run_rt "$RT" "$EFW" --apply
  if [ "$LAST_RC" -eq 2 ] && has "$OUTCOME_SAYS" "$LAST_OUT" && has "BL-603" "$LAST_OUT" \
     && cmp -s "$EFW/backlog.md" "$EFW/pristine.ledger" && cmp -s "$EFW/backlog.archive.md" "$EFW/pristine.archive"; then
    ok "outcome-${EFW##*/}" "that tag spelling, closed with no outcome line, is refused and nothing is written"
  else
    bad "outcome-${EFW##*/}" "exit $LAST_RC; a close in that tag spelling with no outcome line was not refused"
  fi
done
EFN="$WORK/eff-form-nearmiss"
mkcase "$EFN" <<'EOM'
# Probe backlog

## BL-605 — closed, prose bold carrying the word

**Lead hours and lead tokens join every efficiency outcome.** Prose, not a tag.

<br>**LANDED (v0.372.0, verified 0cadda4).** Done.

verify: has VERSION "."

## BL-606 — closed, a DEFECT tier with the word after it

**DEFECT.** The efficiency of this step is poor.

<br>**LANDED (v0.372.0, verified 0cadda4).** Done.

verify: has VERSION "."

## BL-607 — open

verify: lacks VERSION "."
EOM
reseed "$EFN"; run_rt "$RT" "$EFN" --apply
if [ "$LAST_RC" -eq 0 ] && grep -q '^## BL-605 ' "$EFN/backlog.archive.md" && grep -q '^## BL-606 ' "$EFN/backlog.archive.md" \
   && ! has "$OUTCOME_SAYS" "$LAST_OUT"; then
  ok "outcome-nearmiss" "untagged closes whose bold spans carry the word efficiency rotate without an outcome line"
else
  bad "outcome-nearmiss" "exit $LAST_RC; an untagged close carrying the word efficiency in bold was refused or not archived"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "PASS: every assertion holds."
  exit 0
fi
echo "FAIL: an assertion regressed." >&2
exit 1
