#!/usr/bin/env bash
# backlog-rotate-fence-guard — assert that scripts/backlog-rotate.sh REFUSES a ledger whose
# closed entry fences an entry-shaped line, writes nothing when it refuses, and stays quiet on
# the near-misses a backlog full of quoted markdown carries constantly.
#
# THE DEFECT, REPRODUCED BEFORE THIS FIXTURE WAS WRITTEN AND AGAIN BY ITS OWN MUTANT.
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
# A MISSING SUBJECT IS NOT A PASS. Several arms below read a tool's output, and a run that
# cannot invoke the tool produces empty output that would score green on anything phrased as an
# absence.
for f in "$RT" "$RV" "$LIB"; do
  [ -f "$f" ] || { echo "FIXTURE ERROR: cannot locate $f" >&2; exit 2; }
done

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

FAIL=0
KILLS=0
echo "backlog-rotate-fence-guard fixture"
echo "  subject: $RT"
echo

ok()  { printf '  ok    %-21s %s\n' "$1" "$2"; }
bad() { printf '  FAIL  %-21s %s\n' "$1" "$2"; FAIL=1; }

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
fences() { local n; n="$(grep -c '^[ 	]*\(```\|~~~\)' "$1" 2>/dev/null)" || n=0; printf '%s' "${n:-0}"; }
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
if ! has " $EXP_H " " $GOT "; then
  bad "names-all" "the fenced heading at line $EXP_H is not named as an offender; got: [$GOT]"
elif ! has " $EXP_B " " $GOT "; then
  bad "names-all" "the SECOND fenced heading at line $EXP_B is not named; only the first is reported, so a fence holding several offenders sends the operator back for a second run — got: [$GOT]"
elif has " $GOOD " " $GOT "; then
  bad "names-all" "the real entry heading at line $GOOD is named as an offender; got: [$GOT]"
else
  ok "names-all" "both fenced offenders named ($EXP_H, $EXP_B); the entry heading at $GOOD is not"
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
# MUTANTS. Every arm above is shaped as "the guard fired" or "the guard stayed quiet", and both
# shapes pass against a subject that emits nothing. Each mutant below is a COPY — never an
# in-place edit — guarded by `cmp -s` so a sed that matched nothing cannot score a kill, and each
# targets ONE arm.
#
# The mutants live in sandbox ROOTS, not in /tmp beside nothing: the rotator walks up for a
# VERSION marker and sources core/skills/.../reconcile/lib.sh through it, so a bare copy in a
# temp directory exits 2 having parsed nothing — which reads exactly like a guard that fired.
# The `control` root below is the unmutated copy that separates those two outcomes.
# ---------------------------------------------------------------------------------------
mkroot() { # mkroot <name> -> echoes the root path
  local r="$WORK/roots/$1"
  mkdir -p "$r/core/skills/ai-dlc-update/reconcile" "$r/scripts" || return 1
  # A SYNTHETIC MARKER, NOT A COPY OF THE REAL VERSION. The rotator only tests that the file
  # EXISTS to find its root, and `VERSION` is excluded from the suite content key, so reading it
  # would make this fixture's input changeable without the suite re-running — I55 fails the push
  # on exactly that. The sandbox root's version is irrelevant to every arm here.
  printf '0.0.0-fixture-sandbox\n' > "$r/VERSION"
  cp "$LIB" "$r/core/skills/ai-dlc-update/reconcile/lib.sh"
  cp "$RV" "$r/scripts/backlog-reverify.sh"
  printf '%s' "$r"
}
# THE BUILT COUNT IS A FILE, NOT A VARIABLE, AND THE FIRST VERSION OF THIS FIXTURE GOT IT WRONG.
# `mutate` is called inside `$( )`, so every assignment it makes is lost to a subshell: the
# counter read 0 while five mutants had in fact been built and killed. Caught by this section's
# own accounting arm, which is the only reason it was not shipped as `0 of 5 built`.
# MUTATE WHICHEVER FILE ACTUALLY OWNS THE LINE, AND FAIL LOUDLY IF NEITHER DOES.
# The entry-boundary and label rules moved OUT of the rotator and into reconcile/lib.sh while
# this fixture was being repaired. A sed aimed at the rotator then matched nothing, `mutate`
# correctly refused to score a kill, and m3 stopped being BUILT at all -- the accounting arm
# reported "5 of 6 built" and that is the only reason it was not read as a fixture that simply
# had fewer mutants. This variant tries the rotator, falls back to the library, and treats
# "neither" as a finding, so a third relocation turns this file red instead of quietly
# shrinking the battery.
mutate_either() { # mutate_either <name> <sed-args...> -> echoes the rotator path in a mutated root
  local n="$1"; shift
  local r m l; r="$(mkroot "$n")" || return 1
  m="$r/scripts/backlog-rotate.sh"; l="$r/core/skills/ai-dlc-update/reconcile/lib.sh"
  LC_ALL=C sed "$@" "$RT" > "$m" || return 1
  if ! cmp -s "$m" "$RT"; then
    : > "$r/.mutant-built"; printf '%s' "$m"; return 0
  fi
  LC_ALL=C sed "$@" "$LIB" > "$l.new" || return 1
  if cmp -s "$l.new" "$LIB"; then
    rm -f "$l.new"
    bad "$n" "the sed matched nothing in EITHER the rotator or reconcile/lib.sh — the line it targets has moved again, so this mutant would test nothing"
    return 1
  fi
  mv "$l.new" "$l"
  : > "$r/.mutant-built"
  printf '%s' "$m"
}

mutate() { # mutate <name> <sed-args...> -> echoes the mutated script path, empty on failure
  local n="$1"; shift
  local r m; r="$(mkroot "$n")" || return 1
  m="$r/scripts/backlog-rotate.sh"
  LC_ALL=C sed "$@" "$RT" > "$m" || return 1
  if cmp -s "$m" "$RT"; then
    bad "$n" "the sed matched nothing, so this mutant is the original — no kill is scored"
    return 1
  fi
  : > "$r/.mutant-built"
  printf '%s' "$m"
}
killed() { KILLS=$((KILLS + 1)); ok "$1" "$2"; }

# CONTROL, UNMUTATED, FIRST. A sandbox root that cannot source lib.sh emits an error and exits 2,
# and "exit 2 with a complaint" is indistinguishable from a guard firing. If this arm fails,

# ---------------------------------------------------------------------------------------
# WHICH ARM REFUSED. `REFUSING` IS NO LONGER A DISCRIMINATOR AND KEYING ON IT SCORES A
# MUTANT AS SURVIVED WHEN IT WAS KILLED BY THE WRONG ARM.
#
# The rotator now refuses for THREE independent reasons and every message carries the word
# `REFUSING`. Measured while this section was rewritten: with the fence guard mutated off, a
# bullet-shaped entry is no longer recognised, so the moved partition holds a fragment the
# receipt engine cannot produce a verdict for -- and the ENGINE arm refuses at exit 2. The
# old predicate, `[ "$LAST_RC" -eq 0 ] && ! has "REFUSING" "$LAST_OUT"`, then reads FALSE and
# reports the mutant as surviving. Both m3-heading-only and m5-drop-a-line failed exactly
# this way, and both were killed by the same sentence:
#   "the receipt engine did not return a verdict for every entry being moved"
#
# THERE IS NO ORDERING OF THE GUARDS THAT AVOIDS THIS. The evidence arms exist precisely to
# refuse inputs the fence arm lets through, so any mutant that blinds the fence arm hands its
# input to them. The exit code cannot say which arm spoke and neither can the shared word.
#
# So each mutant keys on the sentence ITS OWN arm emits. The three are disjoint:
FENCE_SAYS="the entry-boundary rule cannot parse it safely"
CONSERVE_SAYS="the partition does not conserve the file"
ENGINE_SAYS="the receipt engine did not return a verdict for every entry being moved"
EVIDENCE_SAYS="an entry is annotated LANDED but its evidence does not hold"

# AND THE DISCRIMINATOR IS ITSELF CHECKED, BEFORE ANY MUTANT RUNS. A sentence that stopped
# appearing in the subject makes `! has` vacuously true and every kill below unearned -- the
# same failure one level down from the one this section exists to fix. A sentence that is a
# substring of another stops discriminating the moment both arms can fire.
#
# THE EVIDENCE ARMS ARE REQUIRED ONLY IF THE SUBJECT HAS THEM, AND THAT IS NOT A SOFTENING.
# This fixture is versioned beside a rotator that gains arms over time, and a subject that
# predates the evidence guard emits neither of its two sentences. Demanding them
# unconditionally made this file RED against the pre-guard rotator -- measured -- which would
# have wedged any push that landed the fixture and the guard in separate commits. The
# distinction is drawn on a LOCATION, the `--closed-receipts` call the guard is built on, and
# the mode is PRINTED: "the subject has no evidence guard" and "the evidence guard is silent"
# are otherwise the same absence. The two arms every version has are still unconditional.
if grep -qF -- '--closed-receipts' "$RT"; then
  HAS_EVIDENCE_GUARD=1; SENTS_REQUIRED="$FENCE_SAYS
$CONSERVE_SAYS
$ENGINE_SAYS
$EVIDENCE_SAYS"
else
  HAS_EVIDENCE_GUARD=0; SENTS_REQUIRED="$FENCE_SAYS
$CONSERVE_SAYS"
fi
sent_ok=1
while IFS= read -r _s; do
  [ -n "$_s" ] || continue
  if [ "$(grep -cF "$_s" "$RT")" -ne 1 ]; then
    bad "arm-sentences" "the subject does not emit exactly one copy of: $_s"
    sent_ok=0
  fi
done <<<"$SENTS_REQUIRED"
while IFS= read -r _a; do
  [ -n "$_a" ] || continue
  while IFS= read -r _b; do
    [ -n "$_b" ] || continue
    if [ "$_a" != "$_b" ] && case "$_a" in *"$_b"*) true ;; *) false ;; esac; then
      bad "arm-sentences" "one arm's sentence contains another's, so it cannot discriminate: [$_a] vs [$_b]"
      sent_ok=0
    fi
  done <<<"$SENTS_REQUIRED"
done <<<"$SENTS_REQUIRED"
if [ "$sent_ok" -eq 1 ]; then
  if [ "$HAS_EVIDENCE_GUARD" -eq 1 ]; then
    ok "arm-sentences" "four refusal reasons, four disjoint sentences, each emitted exactly once"
  else
    ok "arm-sentences" "two refusal reasons, disjoint, each emitted once — this subject predates the evidence guard, so its two sentences are not required"
  fi
fi

# every kill below is unearned.
CTRL="$(mkroot control)"; cp "$RT" "$CTRL/scripts/backlog-rotate.sh"
reseed "$A"
run_rt "$CTRL/scripts/backlog-rotate.sh" "$A" --apply
if [ "$LAST_RC" -ne 0 ] && has "REFUSING" "$LAST_OUT"; then
  ok "mutant-control" "the unmutated copy in a sandbox root refuses exactly as the real one does"
else
  echo "FIXTURE BROKEN: the UNMUTATED copy in a sandbox root did not behave like the real" >&2
  echo "script (exit $LAST_RC). Every kill below would be scored against a broken harness." >&2
  printf '%s\n' "$LAST_OUT" >&2
  exit 2
fi

# M1 — the guard switched OFF entirely. Targets `fires-heading`, and re-derives the corruption
# this fixture exists for: the mutant must both exit 0 and leave an odd fence count behind.
M1="$(mutate m1-guard-off -e 's/^if \[ -n "\$FENCE_FINDINGS" \]; then$/if false; then/')"
if [ -n "$M1" ]; then
  reseed "$A"
  run_rt "$M1" "$A" --apply
  M1_LIVE="$(fences "$A/backlog.md")"; M1_ARCH="$(fences "$A/backlog.archive.md")"
  if [ "$LAST_RC" -eq 0 ] && ! has "$FENCE_SAYS" "$LAST_OUT" \
     && { [ $((M1_LIVE % 2)) -ne 0 ] || [ $((M1_ARCH % 2)) -ne 0 ]; }; then
    killed m1-guard-off "fires-heading would FAIL: exit 0, and the split left live=$M1_LIVE archive=$M1_ARCH fence delimiters"
  else
    bad "mutant:m1-guard-off" "guard removed and the arm still passed — fires-heading cannot fire (exit $LAST_RC, live=$M1_LIVE archive=$M1_ARCH)"
  fi
fi

# M2 — LAYERED, AND BOTH LAYERS MUST GO. The guard keyed on `ledger_entry_shape()` alone
# instead of the BL- label the split actually keys on. Targets `near-miss`: this is the
# WIDENING mutant, and a widened guard still refuses the offenders, so only the quiet direction
# can catch it. Since lib.sh's shape rule became fence-aware, a fenced `## Some prose heading`
# is not entry-shaped to lib.sh either, so widening the guard ALONE no longer changes the
# near-miss verdict: the property is carried by two layers now, and the mutant reverts both --
# the guard widened AND lib.sh's in-fence branch removed. The single-layer twin below is the
# other half of that proof.
M2="$(mutate m2-shape-only -e 's/if (depth == 1 && backlog_entry_label(\$0) != "")/if (depth == 1 \&\& ledger_entry_shape($0) != "")/')"
if [ -n "$M2" ]; then
  M2_LIB="$(dirname "$M2")/../core/skills/ai-dlc-update/reconcile/lib.sh"
  LC_ALL=C sed 's@if (__lef_in && sh != "") {@if (0) {@' "$LIB" > "$M2_LIB.new"
  if cmp -s "$M2_LIB.new" "$LIB"; then
    rm -f "$M2_LIB.new"
    bad "mutant:m2-shape-only" "the lib.sh layer's sed matched nothing — the in-fence branch of ledger_entry_shape() has moved, so this mutant would revert one layer of two"
  else
    mv "$M2_LIB.new" "$M2_LIB"
    cp "$NM/pristine.ledger" "$NM/backlog.md"
    printf '# pre-existing archive\nSENTINEL-ARCHIVE-LINE\n' > "$NM/backlog.archive.md"
    run_rt "$M2" "$NM" --apply
    if [ "$LAST_RC" -ne 0 ] && has "$FENCE_SAYS" "$LAST_OUT"; then
      killed m2-shape-only "near-miss would FAIL: guard widened to any heading AND lib.sh fence-blind, the FENCE arm refuses a fenced '## Some prose heading' (exit $LAST_RC)"
    else
      bad "mutant:m2-shape-only" "the guard widened to any heading with lib.sh fence-blind and near-miss still passed — it cannot discriminate (exit $LAST_RC)"
    fi
  fi
fi
# M2A — THE SINGLE-LAYER TWIN: guard widened, lib.sh intact. Must stay QUIET on near-miss,
# which is what says the fence-aware shape rule in lib.sh now carries the property on its own.
# A twin that fired here would mean the layered mutant's kill was earned by the guard alone.
M2A="$(mutate m2a-shape-only-lib-intact -e 's/if (depth == 1 && backlog_entry_label(\$0) != "")/if (depth == 1 \&\& ledger_entry_shape($0) != "")/')"
if [ -n "$M2A" ]; then
  cp "$NM/pristine.ledger" "$NM/backlog.md"
  printf '# pre-existing archive\nSENTINEL-ARCHIVE-LINE\n' > "$NM/backlog.archive.md"
  run_rt "$M2A" "$NM" --apply
  if [ "$LAST_RC" -eq 0 ] && ! has "$FENCE_SAYS" "$LAST_OUT"; then
    ok "mutant-twin:m2a" "guard widened with lib.sh intact stays QUIET on near-miss — lib.sh's fence-aware shape rule carries the property, so m2's kill needed both layers"
  else
    bad "mutant-twin:m2a" "guard widened with lib.sh INTACT still refused the near-miss (exit $LAST_RC) — lib.sh is not ignoring the fenced prose heading, so m2's kill is attributable to the guard alone"
  fi
fi

# M3 — the label reader blinded to the BULLET shape. Targets `fires-bullet` and must leave
# `fires-heading` alone; a mutant that fails two arms means one of them is vacuous.
M3="$(mutate_either m3-heading-only -e 's/^  if (shape == "") return ""$/  if (shape != "heading") return ""/')"
if [ -n "$M3" ]; then
  reseed "$B"; run_rt "$M3" "$B" --apply; M3_B_OUT="$LAST_OUT"
  reseed "$C"; run_rt "$M3" "$C" --apply; M3_C_OUT="$LAST_OUT"
  # NOT the exit code. Blinding the label reader to the bullet shape also makes the moved
  # partition unverifiable, so the ENGINE arm refuses at exit 2 and a rc-based predicate reads
  # this mutant as surviving. What the mutant actually did is silence the FENCE arm on the
  # bullet offender, and the tilde offender is the control that says the silence is specific.
  if ! has "$FENCE_SAYS" "$M3_B_OUT" && has "$FENCE_SAYS" "$M3_C_OUT"; then
    killed m3-heading-only "fires-bullet would FAIL: the FENCE arm went silent on the bullet offender while still firing on the tilde one"
  else
    bad "mutant:m3-heading-only" "bullet blinding did not silence the FENCE arm on the bullet offender alone (bullet fence-arm=$(has "$FENCE_SAYS" "$M3_B_OUT" && echo fired || echo silent), tilde fence-arm=$(has "$FENCE_SAYS" "$M3_C_OUT" && echo fired || echo silent))"
  fi
fi

# M4 — the fence opener narrowed to backticks. Targets `fires-tilde`, same non-entanglement
# check against the backtick offender.
M4="$(mutate m4-backtick-only -e 's/(```|~~~)/(```)/')"
if [ -n "$M4" ]; then
  reseed "$C"; run_rt "$M4" "$C" --apply; M4_C_OUT="$LAST_OUT"
  reseed "$B"; run_rt "$M4" "$B" --apply; M4_B_OUT="$LAST_OUT"
  if ! has "$FENCE_SAYS" "$M4_C_OUT" && has "$FENCE_SAYS" "$M4_B_OUT"; then
    killed m4-backtick-only "fires-tilde would FAIL: the FENCE arm went silent on the tilde offender while still firing on the bullet one"
  else
    bad "mutant:m4-backtick-only" "dropping '~~~' did not silence the FENCE arm on the tilde offender alone (tilde fence-arm=$(has "$FENCE_SAYS" "$M4_C_OUT" && echo fired || echo silent), bullet fence-arm=$(has "$FENCE_SAYS" "$M4_B_OUT" && echo fired || echo silent))"
  fi
fi

# M5 — LAYERED, AND BOTH LAYERS MUST GO. Dropping a line from a moved entry is already caught by
# the rotator's own line-count check, so a single-layer mutant proves that check and not this
# fixture's arm. Reverting only one layer produces a green mutant that looks like a kill.
M5="$(mutate m5-drop-a-line \
  -e 's/for (i = 1; i <= n; i++) print buf\[i\] > MOVED/for (i = 2; i <= n; i++) print buf[i] > MOVED/' \
  -e 's/^if \[ "\$((LIVE_LINES + MOVE_LINES))" -ne "\$ORIG_LINES" \]; then$/if false; then/')"
# ITS TWIN IS THE OTHER HALF OF THE PROOF. The dropped line is buf[1] -- the entry's own
# heading -- so the archived fragment has no id and the receipt ENGINE refuses at exit 2
# before anything is written. Nothing reaches disk, so `! conserved` is FALSE and the old
# predicate scored this as a survivor. The observable that belongs to the targeted arm is its
# SENTENCE: absent when both layers are mutated, present when only the line-drop is. Absence
# alone would also hold if the partition genuinely conserved, which is why the twin is not
# optional.
M5A="$(mutate m5a-drop-a-line-conservation-intact \
  -e 's/for (i = 1; i <= n; i++) print buf\[i\] > MOVED/for (i = 2; i <= n; i++) print buf[i] > MOVED/')"
if [ -n "$M5" ] && [ -n "$M5A" ]; then
  reseed "$H"; run_rt "$M5"  "$H" --apply; M5_OUT="$LAST_OUT"
  reseed "$H"; run_rt "$M5A" "$H" --apply; M5A_OUT="$LAST_OUT"
  if ! has "$CONSERVE_SAYS" "$M5_OUT" && has "$CONSERVE_SAYS" "$M5A_OUT"; then
    killed m5-drop-a-line "conservation would FAIL: with the arm disabled the dropped line goes unreported, while the same drop with the arm intact IS reported"
  else
    bad "mutant:m5-drop-a-line" "disabling the conservation arm did not silence it on a dropped line (both-layers=$(has "$CONSERVE_SAYS" "$M5_OUT" && echo fired || echo silent), drop-only=$(has "$CONSERVE_SAYS" "$M5A_OUT" && echo fired || echo silent))"
  fi
fi

# THE KILL COUNT ITSELF. A mutant that killed nothing reads exactly like an arm that cannot
# fire, and a battery whose seds all silently missed reads as five clean passes.
MUT_ATTEMPTED="$(find "$WORK/roots" -name '.mutant-built' -type f 2>/dev/null | wc -l | tr -d ' ')"
# SEVEN BUILT, FIVE KILLS. `m2a` and `m5a` are single-layer TWINS, not targets: each exists to
# show the arm still speaks (m5a) or stays quiet (m2a) when only one layer is applied, which is
# what makes the layered mutant's verdict a measurement instead of an absence. Counting a twin
# as a kill would be counting the control as a result.
if [ "${MUT_ATTEMPTED:-0}" -eq 7 ] && [ "$KILLS" -eq 5 ]; then
  ok "mutants" "7 mutants built (5 targets + m2's and m5's single-layer twins) and all 5 targets killed the arm they name"
else
  bad "mutants" "$MUT_ATTEMPTED of 7 mutants built, $KILLS of 5 killed — an unkilled mutant means an arm cannot fire"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "PASS: every assertion holds."
  exit 0
fi
echo "FAIL: an assertion regressed." >&2
exit 1
