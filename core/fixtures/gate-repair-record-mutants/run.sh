#!/usr/bin/env bash
# Mutation battery for the repair-record arm of validate-gate-adjudication.sh --series,
# scored through the SHIPPED `gate-repair-record` fixture.
#
# WHY A BATTERY AND NOT MORE ARMS. `gate-repair-record` is a set of PRESENCE-shaped
# assertions over five, now eight, seeded cases. Three of the eight are new and two of
# those are ABSENCE-shaped in substance — they claim the arm does NOT accept a foreign
# record and does NOT accept an unstructured one. A both-directions control establishes
# that a check discriminates between two inputs; only a mutant establishes that the line
# doing the discriminating is the line anybody thinks it is. Each mutant below removes
# exactly one property and names the one case that must go red for it.
#
# THE MUTANTS ARE SCORED ON WHICH CASE DIES, NOT ON WHETHER THE FIXTURE WENT RED. A
# fixture reporting red for the wrong case is a mutant that killed nothing and reads
# identically to one that worked, which is the defect this whole directory exists to
# catch one level up.
set -u
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

DIR="$(cd "$(dirname "$0")" && pwd)"

# Resolve the repo root by walking up for a marker; never count `..` hops. The answer has
# to be the same from the repo root, from this directory and from a copied sandbox.
ROOT_DIR="$DIR"
while [ "$ROOT_DIR" != "/" ] && [ ! -f "$ROOT_DIR/VERSION" ]; do
  ROOT_DIR="$(dirname "$ROOT_DIR")"
done
SUBJECT="$ROOT_DIR/core/scripts/validate-gate-adjudication.sh"
FIXTURE="$ROOT_DIR/core/fixtures/gate-repair-record"
SIBLING="$ROOT_DIR/core/scripts/validate-adversarial-convergence.sh"
SCHEMA="$ROOT_DIR/core/schemas/gate-adjudication-verdict.json"
MAP="$ROOT_DIR/core/skills/ai-dlc/enforcement-map.yaml"

for p in "$SUBJECT" "$SIBLING" "$SCHEMA" "$MAP" "$FIXTURE/run.sh" "$FIXTURE/seed.sh"; do
  if [ ! -f "$p" ]; then
    echo "FIXTURE BROKEN: cannot locate $p from $DIR (root resolved to $ROOT_DIR)"
    exit 1
  fi
done
# Print the resolved subject. A mutant applied to a file the run never loads leaves every
# arm green, and `cmp -s` does not catch it — the mutation applied cleanly, to the wrong
# copy. The path is the only thing that says which file was actually scored.
echo "subject:  $SUBJECT"
echo "fixture:  $FIXTURE/run.sh"

FAILURES=0
SCORED=0
note_fail() { echo "FAIL: $*"; FAILURES=$((FAILURES + 1)); }

# --------------------------------------------------------------------------
# Sandbox. The fixture resolves its validator as `$DIR/../../scripts/…`, and the
# validator resolves ITS root by walking up for `core/skills/ai-dlc`, its schema under
# `core/schemas/` and arm H's reader beside itself. The sandbox reproduces exactly that
# shape so the resolution the fixture performs in the sandbox is the resolution it
# performs in the repo — a battery whose sandbox resolves differently scores a program
# nobody runs.
#
# It cannot be done with AI_DLC_* env overrides: the shipped fixture SCRUBS every
# AI_DLC_* variable before it starts, deliberately, and that scrub is what makes it
# immune to a consumer's settings.json. The tree is the only channel left.
# --------------------------------------------------------------------------
build_sandbox() {          # $1 -> prints sandbox root
  local sb; sb="$(mktemp -d)"
  mkdir -p "$sb/core/scripts" "$sb/core/schemas" "$sb/core/skills/ai-dlc" \
           "$sb/core/fixtures/gate-repair-record"
  cp "$SIBLING" "$sb/core/scripts/"
  cp "$SCHEMA"  "$sb/core/schemas/"
  cp "$MAP"     "$sb/core/skills/ai-dlc/"
  cp "$FIXTURE/run.sh" "$FIXTURE/seed.sh" "$sb/core/fixtures/gate-repair-record/"
  printf '%s\n' "$sb"
}

# Apply one literal, exact-count replacement. Python and not sed: the targets carry `(`,
# `)`, `{`, `}`, `*` and `"`, every one of which means something different in BRE than in
# ERE, and a BSD sed whose expression matched nothing exits 0. A literal replace with an
# asserted occurrence COUNT cannot half-apply and cannot silently no-op.
mutate() {                 # $1 dest  $2 old  $3 new  ($2 empty -> whole-file stub)
  local dest="$1" old="$2" new="$3"
  if [ -z "$old" ]; then
    printf '#!/usr/bin/env bash\nexit 0\n' > "$dest"
    return 0
  fi
  OLD="$old" NEW="$new" python3 - "$SUBJECT" "$dest" <<'PY'
import os, sys
src, dest = sys.argv[1], sys.argv[2]
old, new = os.environ["OLD"], os.environ["NEW"]
t = open(src, encoding="utf-8").read()
n = t.count(old)
if n != 1:
    sys.stderr.write(f"ANCHOR MATCHED {n} TIMES, EXPECTED 1\n")
    sys.exit(3)
open(dest, "w", encoding="utf-8").write(t.replace(old, new))
PY
}

# $1 label  $2 expected-dead SET, space separated ('' = control, must stay green;
#           'ANY' = at least one, used only where the mutation removes the program)
# $3 old  $4 new  $5 why
#
# THE SET IS COMPARED FOR EQUALITY, not membership, everywhere it can be. A mutant that
# also kills a case it does not own has an entangled assertion somewhere, and a mutant
# scored on membership alone hides that: it goes green whether it killed one case or all
# of them. Where an overlap is structural rather than accidental — M1 deletes the
# resolution filename outright, so EVERY case built on that filename notices — the set
# names both and the equality still holds.
score() {
  local label="$1" dead="$2" old="$3" new="$4" why="$5" sb out rc got
  SCORED=$((SCORED + 1))
  sb="$(build_sandbox)"
  if ! mutate "$sb/core/scripts/validate-gate-adjudication.sh" "$old" "$new"; then
    note_fail "$label: the mutation did not apply — its anchor is not in the subject, or is
  in it more than once. The battery cannot score a mutant it did not build, and an
  unapplied mutation produces a green run that reads exactly like a surviving arm."
    rm -rf "$sb"; return
  fi
  # A mutation that changed no bytes is the same failure wearing a different hat.
  if [ -n "$old" ] && cmp -s "$SUBJECT" "$sb/core/scripts/validate-gate-adjudication.sh"; then
    note_fail "$label: the mutated copy is byte-identical to the subject."
    rm -rf "$sb"; return
  fi
  out="$(bash "$sb/core/fixtures/gate-repair-record/run.sh" 2>&1)"; rc=$?
  rm -rf "$sb"

  if [ -z "$dead" ]; then
    # THE CONTROL, AND IT CARRIES A POSITIVE CONJUNCT. rc=0 with no output is what a
    # subject replaced by `exit 0` looks like too, so "nothing went wrong" is not the
    # assertion — the fixture's own summary row must be THERE.
    if [ "$rc" -ne 0 ] || ! grep -q '^ok: gate-repair-record' <<<"$out"; then
      note_fail "$label: the UNMUTATED control did not pass. Every kill below is therefore
  unattributable — the battery may be scoring a broken harness rather than a mutation.
  rc=$rc
  $out"
    fi
    return
  fi

  if [ "$rc" -eq 0 ]; then
    note_fail "$label SURVIVED. $why
  The fixture passed against a validator with that property removed, so no assertion in it
  is watching the line the mutation edited."
    return
  fi
  # Which cases died, derived from the fixture's own failure rows. Never piped into a
  # first-match reader: under pipefail a `grep -q` that leaves early answers with the
  # writer's EPIPE and reports NOT-FOUND on input that contains the pattern.
  got="$(sed -n 's/^FAIL: \([a-z0-9-]*\) .*/\1/p' <<<"$out" | sort -u | tr '\n' ' ')"
  got="${got% }"
  if [ "$dead" = "ANY" ]; then
    if [ -z "$got" ]; then
      note_fail "$label went red with no case-level failure row, so the fixture died for a
  reason it cannot name — most likely FIXTURE BROKEN rather than a kill. $why
  fixture said: $out"
    fi
    return
  fi
  local want; want="$(tr ' ' '\n' <<<"$dead" | sort -u | tr '\n' ' ')"; want="${want% }"
  if [ "$got" != "$want" ]; then
    note_fail "$label killed [$got], expected exactly [$want] — so either it was killed by an
  assertion other than the one that owns this property, or it reached a case it has no
  business reaching and that case's assertion is entangled. $why
  fixture said: $out"
  fi
}

# --------------------------------------------------------------------------
# M0 — the unmutated control.
# --------------------------------------------------------------------------
score "M0 control (unmutated)" "" \
  'for kind in ("repair", "resolution")' 'for kind in ("repair", "resolution")  ' \
  ""

# --------------------------------------------------------------------------
# M1 — the second suffix is gone. This is the pre-fix validator: the arm accepts only the
# remediator's filename, so a FAIL closed by a lead-authored resolution has no name it can
# be recorded under. Owned by `gate-repaired-lead-resolution`.
# --------------------------------------------------------------------------
score "M1 resolution suffix removed" \
  "gate-repaired-lead-resolution gate-repaired-resolution-off-label" \
  'for kind in ("repair", "resolution")' \
  'for kind in ("repair",)' \
  "The accepted set is back to \`gate-*-repair-p<M>.md\` alone, which is the state this
  change exists to move off. TWO cases are named because the mutation deletes the
  filename, not a property of it: with no resolution suffix the off-label case's record
  is not unstructured, it is INVISIBLE, so that case reports MISSING where it demands
  UNSTRUCTURED. That overlap is structural and is why the set is stated rather than a
  single owner. If nothing goes red, the lead-resolution case is not exercising the
  second suffix at all."

# --------------------------------------------------------------------------
# M2 — the anchor dropped on the resolution suffix ONLY, which is upstream's suggested
# direction taken literally ("also match `*-resolution-p<M>.md`"). It is mutated on the
# branch rather than on the shared template on purpose: rewriting the template drops the
# anchor for BOTH suffixes, kills two cases at once, and proves neither of them.
# Owned by `gate-repaired-adversarial-resolution-only`.
# --------------------------------------------------------------------------
score "M2 anchor dropped on resolution only" gate-repaired-adversarial-resolution-only \
  'f"gate-*-{kind}-p{M}.md"' \
  '(f"gate-*-{kind}-p{M}.md" if kind == "repair" else f"*-{kind}-p{M}.md")' \
  "The arm now adopts an ADVERSARIAL resolution record as proof of a gate repair. That is
  the hole the \`gate-*\` prefix on the repair glob was measured and narrowed to close,
  reopened one suffix over — and on the reference consumer it is 16 foreign records."

# --------------------------------------------------------------------------
# M3 — the structure check skipped for the new name. The accepted NAME widened; if the
# STANDARD widens with it, the second suffix becomes a way to close any FAIL by filing a
# differently-named file. Owned by `gate-repaired-resolution-off-label`.
# --------------------------------------------------------------------------
score "M3 structure check skipped for resolution records" gate-repaired-resolution-off-label \
  '                    if rc == 0:
                        structured = cand' \
  '                    if rc == 0 or "-resolution-p" in cand:
                        structured = cand' \
  "A resolution record is now accepted on its FILENAME. Existence plus structure is the
  arm's whole floor; drop the structure half for one name and that name is an opt-out."

# --------------------------------------------------------------------------
# M4 — the subject emits nothing. Not a property mutation: it is the question
# `.claude/rules/fixture-mutants.md` puts to every new arm — would this pass against a
# program that never ran? The three cases above are presence-shaped, so it must not.
# --------------------------------------------------------------------------
score "M4 subject replaced by 'exit 0'" ANY "" "" \
  "A validator that emits nothing and exits 0 satisfied the fixture, which means the
  fixture's red cases are asserting an ABSENCE and would certify silence."

# --------------------------------------------------------------------------
# The kill count itself. A battery whose mutants all applied and killed nothing reports
# zero failures, which is byte-identical to a battery that worked.
# --------------------------------------------------------------------------
if [ "$SCORED" -lt 5 ]; then
  note_fail "only $SCORED mutant(s) were scored; this battery declares 5. A mutant that
  never ran cannot have been survived or killed."
fi

if [ "$FAILURES" -eq 0 ]; then
  echo "ok: gate-repair-record-mutants — $SCORED mutant(s) scored; the unmutated control"
  echo "    passes, and removing the resolution suffix, its anchor, its structure check, or"
  echo "    the subject itself each kills the one case that owns that property."
  exit 0
fi
echo "FAILED: gate-repair-record-mutants — $FAILURES finding(s) across $SCORED mutant(s)"
exit 1
