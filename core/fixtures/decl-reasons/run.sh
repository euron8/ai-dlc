#!/usr/bin/env bash
# decl-reasons -- assert scripts/validate-decl-reasons.sh fires on a whole core/ or core/scripts/
# declaration with no `# reason:` line, in BOTH spellings (plain and REQUIRED `!`), stays quiet on a
# near-miss naming one file, refuses an empty corpus, and that each of its three load-bearing parts
# (the self-probe, the `!?` prefix, the anchored whole-line match) is killed by a mutant.
#
# Every corpus is seeded under mktemp; the real tree is never the corpus here. The validator takes
# its tree root as an argument, so a lone mutated copy runs exactly as the original does.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = an assertion failed, 2 = the fixture could not run.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
V="$HERE/../../../scripts/validate-decl-reasons.sh"
[ -f "$V" ] || { echo "decl-reasons: SKIP -- scripts/validate-decl-reasons.sh is distribution-only and is not installed in a consumer tree."; exit 0; }
echo "HERMETIC-CONSUMED scripts/validate-decl-reasons.sh"

T="$(mktemp -d "${TMPDIR:-/tmp}/decl-reasons.XXXXXX")" || exit 2
trap 'rm -rf "$T"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "decl-reasons:"

# world <name> <decl body>... -- one tree per world, each fixture dir holding one inputs.decl.
# The discriminating member is seeded SECOND, behind a reasoned declaration, so a scan that read
# only the first file would miss it.
world() {
  local w="$T/w-$1"; shift
  mkdir -p "$w/core/fixtures/aa-reasoned"
  printf '# reason: seeded\ncore/\n' > "$w/core/fixtures/aa-reasoned/inputs.decl"
  if [ $# -gt 0 ]; then
    mkdir -p "$w/core/fixtures/zz-subject"
    printf '%b' "$1" > "$w/core/fixtures/zz-subject/inputs.decl"
  fi
  printf '%s' "$w"
}
W_PLAIN="$(world plain 'core/scripts/\ncore/schemas/\n')"
W_CORE="$(world core '# a comment that is not a reason\ncore/\n')"
W_REQ="$(world req '!core/scripts/\n')"
W_NEAR="$(world near 'core/scripts/x.sh\n!core/scripts/y.sh\n')"
W_CLEAN="$(world clean)"
W_EMPTY="$T/w-empty"; mkdir -p "$W_EMPTY/core/fixtures"

RC=0; OUT=""
drive() { OUT="$(bash "$1" "$2" 2>&1)"; RC=$?; }
has() { grep -qF -- "$1" <<<"$OUT"; }
SUBJ='core/fixtures/zz-subject/inputs.decl'

# --- the unmutated validator, world by world ----------------------------------------------------
drive "$V" "$W_PLAIN"
[ "$RC" -eq 1 ] && has "$SUBJ" && ok "a whole core/scripts/ line with no reason -> exit 1, offender named" \
  || bad "plain core/scripts/ with no reason: rc=$RC, want 1 naming $SUBJ: $OUT"
drive "$V" "$W_CORE"
[ "$RC" -eq 1 ] && has "$SUBJ" && ok "a whole core/ line under a non-reason comment -> exit 1, offender named" \
  || bad "plain core/ with no reason: rc=$RC, want 1 naming $SUBJ: $OUT"
drive "$V" "$W_REQ"
[ "$RC" -eq 1 ] && has "$SUBJ" && ok "a REQUIRED !core/scripts/ line with no reason -> exit 1, offender named" \
  || bad "!core/scripts/ with no reason: rc=$RC, want 1 naming $SUBJ: $OUT"
drive "$V" "$W_NEAR"
[ "$RC" -eq 0 ] && has "PASS -- 2 inputs.decl scanned" && ok "a near-miss naming one file under core/scripts/ -> exit 0, 2 scanned" \
  || bad "near-miss core/scripts/x.sh: rc=$RC, want 0 with 2 scanned: $OUT"
drive "$V" "$W_CLEAN"
[ "$RC" -eq 0 ] && has "PASS -- 1 inputs.decl scanned" && has "self-probe ok" \
  && ok "CONTROL: a reasoned whole-directory line -> exit 0, the self-probe ran and 1 file was scanned" \
  || bad "control: rc=$RC, want 0 with the self-probe line and 1 scanned: $OUT"
drive "$V" "$W_EMPTY"
[ "$RC" -eq 2 ] && has "EXAMINED NOTHING" && ok "an empty corpus -> exit 2 EXAMINED NOTHING, never a PASS" \
  || bad "empty corpus: rc=$RC, want 2 'EXAMINED NOTHING': $OUT"

# --- mutants: copies, each guarded by cmp -s so a sed that matched nothing cannot score ---------
# mut <name> <sed program> -> path of the mutated copy, or empty with a DID NOT APPLY failure.
mut() {
  local m="$T/mut-$1.sh"
  if ! sed "$2" "$V" > "$m"; then bad "mutant $1: DID NOT APPLY (sed failed)"; return 1; fi
  if cmp -s "$V" "$m"; then bad "mutant $1: DID NOT APPLY (no bytes changed)"; return 1; fi
  printf '%s' "$m"
}

# M1: the self-probe never runs. Corpus answers are unchanged, so the kill is PRESENCE-shaped:
# the probe's own line must appear, and a run that skipped it cannot print it.
if M="$(mut no-probe 's/^self_probe || exit 2$/: self-probe dropped/')"; then
  drive "$M" "$W_CLEAN"
  if [ "$RC" -eq 0 ] && has "PASS -- 1 inputs.decl scanned"; then
    has "self-probe ok" && bad "M1 (self-probe dropped) SURVIVED: the run still printed the probe line" \
      || ok "M1 (self-probe dropped) killed: the copy ran (PASS, 1 scanned) and printed no self-probe line"
  else
    bad "M1: the mutated copy did not run to PASS on the clean world (rc=$RC), so its kill is unproven: $OUT"
  fi
fi

# M2 and M3 edit the PATTERN, which the self-probe and the corpus scan both read. Two guards on one
# subject read exactly like two that do not work, so each gets its own: the single mutant must die
# IN THE SELF-PROBE by name (rc 2), and the same edit with the probe also dropped must move the
# CORPUS verdict on the world built for it. The double mutant is the single one plus M1's edit.
NOPROBE='s/^self_probe || exit 2$/: self-probe dropped/'
BANG='s#/^!?core\\/(scripts\\/)?\$/#/^core\\/(scripts\\/)?$/#'
WIDEN='s#/^!?core\\/(scripts\\/)?\$/#/^!?core\\/(scripts\\/)?/#'

# M2: the `!?` prefix dropped, so a REQUIRED !core/scripts/ line is invisible.
if M="$(mut no-bang "$BANG")"; then
  drive "$M" "$W_REQ"
  [ "$RC" -eq 2 ] && has "SELF-PROBE FAILED" && ok "M2 (!? dropped) killed by the self-probe (rc 2, SELF-PROBE FAILED)" \
    || bad "M2 (!? dropped) was not refused by the self-probe: rc=$RC: $OUT"
fi
if M="$(mut no-bang-no-probe "$BANG; $NOPROBE")"; then
  drive "$M" "$W_REQ"
  [ "$RC" -eq 0 ] && has "PASS -- 2 inputs.decl scanned" \
    && ok "M2b (!? dropped, probe dropped) acquits the !core/scripts/ world the original flags -- the corpus arm keys on the prefix" \
    || bad "M2b: with the probe gone the !core/scripts/ world should read PASS under the mutant; rc=$RC: $OUT"
fi

# M3: the whole-line anchor widened, so core/scripts/x.sh reads as a whole directory.
if M="$(mut widen "$WIDEN")"; then
  drive "$M" "$W_NEAR"
  [ "$RC" -eq 2 ] && has "SELF-PROBE FAILED" && ok "M3 (anchor widened) killed by the self-probe (rc 2, SELF-PROBE FAILED)" \
    || bad "M3 (anchor widened) was not refused by the self-probe: rc=$RC: $OUT"
fi
if M="$(mut widen-no-probe "$WIDEN; $NOPROBE")"; then
  drive "$M" "$W_NEAR"
  [ "$RC" -eq 1 ] && has "$SUBJ" \
    && ok "M3b (anchor widened, probe dropped) flags the near-miss the original passes -- the corpus arm keys on the anchor" \
    || bad "M3b: with the probe gone the near-miss should be flagged under the mutant; rc=$RC: $OUT"
fi

if [ "$fails" -eq 0 ]; then echo "decl-reasons: PASS"; exit 0; fi
echo "decl-reasons: $fails assertion(s) FAILED"; exit 1
