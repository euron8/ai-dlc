#!/usr/bin/env bash
# shadowed-local-validators — assert warn-shadowed-local-validators.sh flags a local
# validator fork ONLY when its ledger entry is CLOSED (ADOPTED UPSTREAM), the fork exists,
# AND it shadows a real core validator — and stays silent otherwise.
#
# THE DEFECT THIS EXISTS TO CATCH. The signal must fire on exactly one condition set. If it
# fired on OPEN entries it would nag about forks still doing real work; if it fired on a
# `.sh` token in prose with no fork it would be noise; if it fired on a fork that shadows no
# core validator it would be wrong. The mutation controls prove the CLOSED gate is what
# suppresses open entries — without them, an open fork would be flagged too.
#
# THE SUBJECT DOES NOT RUN ALONE ANY MORE, AND THAT BROKE THIS FIXTURE ONCE. It used to
# hand-copy the ledger entry-boundary rules and the close test inline; it now sources
# `lib.sh`, and `lib.sh`'s `ledger_close_awk()` LIFTS the close grammar out of
# `ledger-reverify.sh` at load time. A lone copy of the script in a temp dir therefore dies
# at `. lib.sh` with rc=2 and prints NOTHING — and "no output" is exactly what a killed
# mutant looks like here, so both mutation arms reported a red they had not earned. Every
# sandbox is built by `new_sandbox()`, which carries both files, and an UNMUTATED CONTROL
# runs through that same sandbox FIRST: if the harness is what died, the control says so
# instead of a mutant scoring a phantom kill.
set -uo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT=""
for cand in \
  "$DIR/../../skills/ai-dlc-update/reconcile/warn-shadowed-local-validators.sh" \
  "$DIR/../../../core/skills/ai-dlc-update/reconcile/warn-shadowed-local-validators.sh" \
  "$DIR/../../../.claude/skills/ai-dlc-update/reconcile/warn-shadowed-local-validators.sh"; do
  [ -f "$cand" ] && SCRIPT="$cand" && break
done
[ -n "$SCRIPT" ] || { echo "FIXTURE ERROR: warn-shadowed-local-validators.sh not found" >&2; exit 2; }

# What the subject READS at run time, resolved beside the copy it is loaded from. Missing
# either one is a FIXTURE ERROR, not an assertion failure: a sandbox that cannot be built
# has measured nothing.
SRC_DIR="$(cd "$(dirname "$SCRIPT")" && pwd)"
for dep in lib.sh ledger-reverify.sh; do
  [ -f "$SRC_DIR/$dep" ] || {
    echo "FIXTURE ERROR: $SRC_DIR/$dep not found — the subject sources lib.sh, and lib.sh lifts the close grammar out of ledger-reverify.sh; a sandbox without both cannot run the subject at all" >&2
    exit 2; }
done

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/local" "$WORK/core"

TAB="$(printf '\t')"

# The synthetic ledger: closed entries, open ones, in the heading shape the real ledger uses;
# one closed entry naming a tool with no core twin. `BOLD` and `MENTION` are the two halves
# of the close-grammar question — a line-leading `**ADOPTED UPSTREAM (v…)` annotation closes,
# a mid-sentence MENTION of the phrase inside an open entry's body does not.
cat > "$WORK/ledger.md" <<'LED'
# Push-candidate ledger (fixture)

## PC-CLOSED-FOO — validate-foo.sh: divergence
Prose about core/scripts/validate-foo.sh.
verify: theirs_lacks core/scripts/validate-foo.sh "some-marker"
ADOPTED UPSTREAM (v0.130.0, verified 2026-07-22)

## PC-OPEN-BAR — validate-bar.sh: divergence
Prose about core/scripts/validate-bar.sh — still diverging.
verify: theirs_lacks core/scripts/validate-bar.sh "other-marker"

## PC-CLOSED-NOFORK — validate-nofork.sh: divergence
Prose about core/scripts/validate-nofork.sh.
ADOPTED UPSTREAM (v0.130.0)

## PC-CLOSED-NOCORE — some-tool.sh: consumer-only tool
Prose naming some-tool.sh.
ADOPTED UPSTREAM (v0.130.0)

## PC-CLOSED-SUB — validate-sub.sh: divergence
Prose about core/scripts/validate-sub.sh.
ADOPTED UPSTREAM (v0.130.0)

## PC-CLOSED-BOLD — validate-bold.sh: divergence
Prose about core/scripts/validate-bold.sh.
**ADOPTED UPSTREAM (v0.131.0, verified 2026-07-22)**

## PC-OPEN-MENTION — validate-mention.sh: divergence
Prose about core/scripts/validate-mention.sh — still diverging, nothing upstream yet.
Once the core fix lands, annotate it ADOPTED UPSTREAM and retire the fork.

## PC-CLOSED-FENCED — validate-fenced.sh: divergence, with a derived block recording a heading-shaped line
Prose about core/scripts/validate-fenced.sh, named ABOVE the fence.
```derived
$ grep '^## ' pipeline-continuation-log.md | head -1
## 2000-01-01T00:00:00Z -- FENCED-EVENT
```
ADOPTED UPSTREAM (v0.130.0)
LED

# Forks the consumer carries.
for f in validate-foo.sh validate-bar.sh some-tool.sh validate-orphan.sh \
         validate-bold.sh validate-mention.sh validate-fenced.sh; do : > "$WORK/local/$f"; done
# A fork filed under a SUBDIRECTORY of the home. The home's internal layout is the
# consumer's — core declares the directory and claims nothing about its shape — so this is
# the ordinary way a consumer files a fork once the home holds more than a few scripts.
mkdir -p "$WORK/local/lib"
: > "$WORK/local/lib/validate-sub.sh"
# Core validators (what a fork must shadow to count).
for f in validate-foo.sh validate-bar.sh validate-nofork.sh validate-orphan.sh \
         validate-sub.sh validate-bold.sh validate-mention.sh validate-fenced.sh; do : > "$WORK/core/$f"; done

run_warn_2() { # run_warn_2 <script> <stderr-file>
  bash "$1" --root "$WORK" --ledger "$WORK/ledger.md" \
    --local-dir "$WORK/local" --core-dir "$WORK/core" 2>"$2"
}
run_warn() { run_warn_2 "$1" /dev/null; }

# A sandbox carrying what the subject reads. NOT a copy of the whole reconcile directory:
# only the two files the subject actually loads, so no mutant can silently read an
# unmutated twin of itself. One directory per mutant, so the mutants cannot see each other.
new_sandbox() { # new_sandbox <name>  -> path on stdout
  local d="$WORK/sbx-$1"
  mkdir -p "$d" && cp "$SRC_DIR/lib.sh" "$SRC_DIR/ledger-reverify.sh" "$d/" || return 1
  printf '%s\n' "$d"
}

OUT="$(run_warn "$SCRIPT")"
fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; fails=$((fails+1)); }
# The emitted path is the fork's REAL location, root-relative — here `local/…`, because
# that is where --local-dir points. Until v0.194.0 the script fabricated the string
# `scripts/ai-dlc-local/<basename>` no matter where --local-dir actually pointed or where
# under it the fork sat, so the row named a path that need not exist. Keying this fixture on
# the fabricated form is what let that ship: it asserted the constant, not the finding.
row() { grep -q "${TAB}$2${TAB}" <<<"$1"; }   # row <output> <root-relative fork path>
has() { row "$OUT" "local/$1"; }

echo "shadowed-local-validators:"

# HARNESS CONTROL, FIRST. An unmutated copy in a mutant-shaped sandbox. Every mutant below
# is scored on an ABSENCE or a presence in output produced this way, and a sandbox that
# cannot run the subject produces no output at all — which reads as a kill. This arm is the
# only thing that tells those two apart, and it is why the arms below may be trusted.
CTRL_DIR="$(new_sandbox control)" || { echo "FIXTURE ERROR: cannot build the control sandbox" >&2; exit 2; }
cp "$SCRIPT" "$CTRL_DIR/warn-shadowed-local-validators.sh"
CTRL_ERR="$WORK/control.err"
COUT="$(run_warn_2 "$CTRL_DIR/warn-shadowed-local-validators.sh" "$CTRL_ERR")"; CRC=$?
# rc IS PART OF THE CONTROL, because it is the other half of the REFUSAL arms' claim below.
# Those assert a NON-ZERO exit when the close grammar cannot be lifted; that assertion means
# nothing unless the resolving path in the SAME sandbox shape is known to exit 0.
if [ "$CRC" -eq 0 ] && row "$COUT" "local/validate-foo.sh" && ! row "$COUT" "local/validate-bar.sh"; then
  ok "CONTROL — an UNMUTATED copy in the mutant sandbox reproduces the baseline rows and exits 0 (the sandbox carries lib.sh + ledger-reverify.sh, so a mutant that emits nothing was killed rather than broken)"
else
  bad "CONTROL — the unmutated copy does not reproduce the baseline in the mutant sandbox (rc=$CRC); every MUTATION verdict below is unreadable. stderr: $(tr '\n' ' ' < "$CTRL_ERR")"
fi

# CLOSED + fork + core shadow -> flagged.
has "validate-foo.sh" && ok "closed entry + fork + core shadow -> RETIRE-CANDIDATE (foo)" \
  || bad "validate-foo.sh not flagged — the one true positive is missing"
# OPEN entry -> not flagged.
has "validate-bar.sh" && bad "validate-bar.sh flagged despite an OPEN (not ADOPTED) entry" \
  || ok "open entry -> not flagged (bar)"
# Closed but no fork -> nothing to retire.
has "validate-nofork.sh" && bad "validate-nofork.sh flagged with no fork present" \
  || ok "closed entry but no fork -> not flagged (nofork)"
# Fork exists but shadows no core validator -> filtered (prose .sh token).
has "some-tool.sh" && bad "some-tool.sh flagged though it shadows no core validator" \
  || ok "fork with no core shadow -> not flagged (some-tool)"
# Orphan fork, no ledger entry -> not flagged.
has "validate-orphan.sh" && bad "validate-orphan.sh flagged with no ledger entry" \
  || ok "fork with no ledger entry -> not flagged (orphan)"

# A fork under a SUBDIRECTORY of the home -> flagged, at its real path.
has "lib/validate-sub.sh" && ok "a fork in a subdirectory of the home -> RETIRE-CANDIDATE at its real path (sub)" \
  || bad "validate-sub.sh not flagged — a fork filed below the home's top level is invisible, which reads exactly like a home with no forks in it"

# THE CLOSE GRAMMAR, BOTH DIRECTIONS. A line-leading `**ADOPTED UPSTREAM (v…)` annotation
# closes the entry; a mid-sentence MENTION of the phrase in an open entry's body does not.
# The mention case is the whole defect the lift fixed: under the old unanchored
# `/ADOPTED UPSTREAM/` this script advised RETIRING a fork that is still needed.
has "validate-bold.sh" && ok "a line-leading **ADOPTED UPSTREAM (v…) annotation closes the entry -> flagged (bold)" \
  || bad "validate-bold.sh not flagged — the lifted close grammar does not recognise the annotation form the operator is told to write, so no real close would ever be seen"
has "validate-mention.sh" && bad "validate-mention.sh flagged — an OPEN entry whose body merely MENTIONS 'annotate it ADOPTED UPSTREAM once …' scored as closed, and the signal is advising the retirement of a fork that is still doing work" \
  || ok "a mid-sentence MENTION of ADOPTED UPSTREAM does not close an open entry -> not flagged (mention)"

# A CLOSED entry whose fence records a heading-shaped line -> flagged. The entry-boundary rule
# this script loads from lib.sh used to open a new entry on the fenced `## <ts> -- EVENT` line
# (PC-S308-LEDGER-REVERIFY-ENTRY-BOUNDARY-IGNORES-FENCED-HEADINGS), so the `.sh` named above the
# fence was flushed under an OPEN entry and the close annotation below the fence belonged to a
# pseudo-entry naming nothing: a retired fork that was never reported. The mutant at the foot
# of this file re-derives that silence.
has "validate-fenced.sh" && ok "a closed entry whose fence records a heading-shaped line -> RETIRE-CANDIDATE (fenced): the fenced line did not split the entry" \
  || bad "validate-fenced.sh not flagged — the fenced '## <ts> -- EVENT' line split the entry, so the .sh named above the fence was flushed as OPEN and the close below the fence closed a pseudo-entry naming nothing"

# Never blocks.
run_warn "$SCRIPT" >/dev/null 2>&1
[ "$?" -eq 0 ] && ok "exit 0 (signal never blocks)" || bad "exit was not 0 — a signal must not block"

# MUTATION control: drop the CLOSED gate in flush() so EVERY entry emits its basenames.
# The OPEN bar fork must then be flagged — proving the ADOPTED-UPSTREAM gate is what
# suppresses open entries. A grep-based anti-vacuity: require the mutation to change the file.
MUT_DIR="$(new_sandbox mut-closed-gate)" || { echo "FIXTURE ERROR: cannot build the mut-closed-gate sandbox" >&2; exit 2; }
MUT="$MUT_DIR/warn-shadowed-local-validators.sh"
CHG="$(python3 - "$SCRIPT" "$MUT" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()
s2 = s.replace('if (closed && names != "")', 'if (names != "")')
open(dst, "w", encoding="utf-8").write(s2)
print("CHANGED" if s2 != s else "UNCHANGED")
PY
)"
if [ "$CHG" != "CHANGED" ]; then
  bad "MUTATION matched nothing — the closed-gate in flush() was renamed"
else
  MOUT="$(run_warn "$MUT")"
  if row "$MOUT" "local/validate-bar.sh"; then
    ok "MUTATION — dropping the CLOSED gate flags the OPEN bar fork too (the gate is load-bearing)"
  else
    bad "MUTATION — bar still not flagged without the CLOSED gate; the closed-only assertions prove nothing"
  fi
fi

# MUTATION control 2: bound the home walk to its top level, the pre-v0.194.0 shape. The
# subdirectory fork must then go unreported — proving the recursive walk is what finds it,
# and that the assertion above is not passing on some other arm. Single-arm: `foo` at the
# home's root stays flagged, so this cannot be confused with the fork-existence gate.
MUT2_DIR="$(new_sandbox mut-depth)" || { echo "FIXTURE ERROR: cannot build the mut-depth sandbox" >&2; exit 2; }
MUT2="$MUT2_DIR/warn-shadowed-local-validators.sh"
CHG2="$(python3 - "$SCRIPT" "$MUT2" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()
s2 = s.replace('find "$LOCAL_DIR" -type f', 'find "$LOCAL_DIR" -maxdepth 1 -type f')
open(dst, "w", encoding="utf-8").write(s2)
print("CHANGED" if s2 != s else "UNCHANGED")
PY
)"
if [ "$CHG2" != "CHANGED" ]; then
  bad "MUTATION 2 matched nothing — the home walk is no longer a bare find over LOCAL_DIR"
else
  MOUT2="$(run_warn "$MUT2")"
  if row "$MOUT2" "local/lib/validate-sub.sh"; then
    bad "MUTATION 2 — the subdirectory fork is STILL reported with the walk bounded to depth 1; the assertion above proves nothing about recursion"
  elif row "$MOUT2" "local/validate-foo.sh"; then
    ok "MUTATION 2 — bounding the walk to the home's top level hides the subdirectory fork while the root-level one stays flagged (the recursion is load-bearing, and only it changed)"
  else
    bad "MUTATION 2 — bounding the walk silenced the ROOT-LEVEL fork too; the mutant broke more than recursion and its verdict is entangled"
  fi
fi

# MUTATION control 3: DE-ANCHOR THE CLOSE RULE IN THE SANDBOX'S ledger-reverify.sh — not in
# the subject. The subject's close test is `ledger_body_closes()`, which lib.sh LIFTS out of
# ledger-reverify.sh at load time, so this mutant asks the one question the other two cannot:
# is that lift a real runtime READ, or has the grammar quietly been re-copied into the
# subject? Both failure directions are covered. If the subject carried its own UNANCHORED
# copy, `mention` would be flagged in the baseline arm above. If it carried its own ANCHORED
# copy, mutating ledger-reverify.sh would change nothing and this arm would not see the
# mention appear. Widening is a superset, so `foo` must survive — one edit, one delta.
MUT3_DIR="$(new_sandbox mut-close-anchor)" || { echo "FIXTURE ERROR: cannot build the mut-close-anchor sandbox" >&2; exit 2; }
MUT3="$MUT3_DIR/warn-shadowed-local-validators.sh"
cp "$SCRIPT" "$MUT3"
# The replacement must still be LIFTABLE — lib.sh refuses unless exactly one line carries the
# phrase in the `{ closed=1 }` shape — so only the anchor is removed, never the phrase.
CHG3="$(python3 - "$MUT3_DIR/ledger-reverify.sh" <<'PY'
import sys
p = sys.argv[1]
lines = open(p, encoding="utf-8").read().split("\n")
hits = [i for i, l in enumerate(lines)
        if l.rstrip().endswith("{ closed=1 }") and "ADOPTED UPSTREAM" in l]
if len(hits) != 1:
    print("NOTFOUND:%d" % len(hits))
else:
    lines[hits[0]] = "  /(ADOPTED UPSTREAM|WITHDRAWN)/ { closed=1 }"
    open(p, "w", encoding="utf-8").write("\n".join(lines))
    print("CHANGED")
PY
)"
if [ "$CHG3" != "CHANGED" ]; then
  bad "MUTATION 3 matched nothing ($CHG3) — the close rule in ledger-reverify.sh is no longer a single `{ closed=1 }` line naming ADOPTED UPSTREAM; re-anchor this mutant on whatever now carries the grammar"
elif cmp -s "$SRC_DIR/ledger-reverify.sh" "$MUT3_DIR/ledger-reverify.sh"; then
  bad "MUTATION 3 — the mutated ledger-reverify.sh is byte-identical to the original; the mutation did not apply"
else
  MOUT3="$(run_warn "$MUT3")"
  if ! row "$MOUT3" "local/validate-mention.sh"; then
    bad "MUTATION 3 — de-anchoring the close rule IN ledger-reverify.sh did not change the subject's verdict, so the subject is not lifting that grammar; the mid-sentence-mention arm above is asserting a copy nobody joined"
  elif ! row "$MOUT3" "local/validate-foo.sh"; then
    bad "MUTATION 3 — widening the close rule LOST the foo row; the mutant did more than widen and its verdict is entangled"
  else
    ok "MUTATION 3 — de-anchoring the close rule in ledger-reverify.sh makes the mid-sentence MENTION close its entry (the lift is a live read, and the anchor is what keeps a still-needed fork off the retire list)"
  fi
fi

# MUTATION control 4: MAKE lib.sh's BOUNDARY RULE FENCE-BLIND IN THE SANDBOX. The fenced
# `## <ts> -- EVENT` line then opens an entry again and `validate-fenced.sh` goes unreported,
# while `foo` (no fence) stays flagged — one clause, one delta. This is the arm that binds this
# reader to the shared rule: a subject that re-copied a fence-blind boundary inline would fail
# the baseline arm above, and one that carried its own fence-aware copy would not move here.
MUT4_DIR="$(new_sandbox mut-fence-blind)" || { echo "FIXTURE ERROR: cannot build the mut-fence-blind sandbox" >&2; exit 2; }
MUT4="$MUT4_DIR/warn-shadowed-local-validators.sh"
cp "$SCRIPT" "$MUT4"
sed 's@if (__lef_in && sh != "") {@if (0) {@' "$SRC_DIR/lib.sh" > "$MUT4_DIR/lib.sh"
if cmp -s "$SRC_DIR/lib.sh" "$MUT4_DIR/lib.sh"; then
  bad "MUTATION 4 matched nothing — the in-fence branch of ledger_entry_shape() in lib.sh has moved; re-anchor this mutant"
else
  MOUT4="$(run_warn "$MUT4")"
  if row "$MOUT4" "local/validate-fenced.sh"; then
    bad "MUTATION 4 — validate-fenced.sh is STILL reported with the boundary rule fence-blind; the fenced-entry arm above proves nothing about fence tracking"
  elif row "$MOUT4" "local/validate-foo.sh"; then
    ok "MUTATION 4 — with the boundary rule fence-blind the fenced closed entry goes silent while foo stays flagged (the fence-aware boundary in lib.sh is load-bearing for this reader)"
  else
    bad "MUTATION 4 — blinding the fence silenced foo too; the mutant broke the parser and its verdict is entangled"
  fi
fi

# lib.sh's TWO REFUSAL PATHS, both reachable from here. `ledger_close_awk()` refuses rather
# than returning an empty predicate, because an empty one makes every caller decide that
# NOTHING is closed — a guard that permits everything, reading exactly like a clean tree.
#
# THREE CLAIMS, AND THE EXIT CODE IS THE ONE A CALLER CAN ACT ON. No row is fabricated; the
# refusal is AUDIBLE, naming itself on stderr; and the script EXITS NON-ZERO. Until
# `CLOSE_AWK="$(ledger_close_awk)" || exit 2` existed, the refusal was interpolated into the
# awk program as an empty string, awk died on an undefined function, and this script exited
# 0 having emitted nothing — a silent clean run, byte-indistinguishable from a consumer with
# no shadowed forks, and stderr is the one channel a pull flow may discard. The first two
# claims held even then; only the third separates the two states.
#
# The CONTROL arm above ran in an identical sandbox with both files intact, produced the foo
# row AND exited 0, so a silent non-zero here is the refusal and not the harness.
refusal_arm() { # refusal_arm <label> <sandbox-dir> <expected stderr phrase> <what it means>
  local out err rc
  err="$WORK/$1.err"
  cp "$SCRIPT" "$2/warn-shadowed-local-validators.sh"
  out="$(run_warn_2 "$2/warn-shadowed-local-validators.sh" "$err")"; rc=$?
  if grep -q "RETIRE-CANDIDATE" <<<"$out"; then
    bad "REFUSAL ($1) — rows were emitted with the close grammar unliftable; the predicate fell back to something instead of refusing"
  elif ! grep -q "ledger_close_awk.*$3" "$err"; then
    bad "REFUSAL ($1) — no ledger_close_awk refusal on stderr ($4); a silently empty close predicate makes every caller decide nothing is closed. stderr: $(tr '\n' ' ' < "$err")"
  elif [ "$rc" -eq 0 ]; then
    bad "REFUSAL ($1) — the refusal exited 0, so the ONLY channel that separates it from a clean consumer is a stderr line a caller may discard; $4 must not share an exit code with a tree that has nothing to report"
  else
    ok "REFUSAL ($1) — $4 makes ledger_close_awk refuse audibly on stderr, emit no rows, and exit non-zero (rc=$rc) so a caller can tell the refusal from a clean tree"
  fi
}
REF1_DIR="$(new_sandbox refuse-unreadable)" || { echo "FIXTURE ERROR: cannot build the refuse-unreadable sandbox" >&2; exit 2; }
rm -f "$REF1_DIR/ledger-reverify.sh"
refusal_arm unreadable "$REF1_DIR" "cannot read" "the emitter of the close grammar being absent"

REF2_DIR="$(new_sandbox refuse-not-single-homed)" || { echo "FIXTURE ERROR: cannot build the refuse-not-single-homed sandbox" >&2; exit 2; }
# Doubling the whole file makes every line appear twice — so the close rule matches 2 without
# this fixture restating one byte of lib.sh's finder grammar.
cat "$SRC_DIR/ledger-reverify.sh" "$SRC_DIR/ledger-reverify.sh" > "$REF2_DIR/ledger-reverify.sh"
refusal_arm not-single-homed "$REF2_DIR" "expected exactly 1" "two candidate close rules in the emitter"

echo
[ "$fails" -eq 0 ] && { echo "shadowed-local-validators: PASS"; exit 0; }
echo "shadowed-local-validators: $fails assertion(s) violated." >&2
exit 1
