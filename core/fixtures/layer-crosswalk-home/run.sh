#!/usr/bin/env bash
# layer-crosswalk-home — LC-N7 / W8: crosswalk rows live in a file the CONSUMER owns.
#
# THE ASSERTION. LC-N6 is an ERROR, and through contract version 10 the only way to satisfy
# it was to write a row into `extensions/README.md` — a file the distribution ships, that
# `install.sh` scaffolds, and that every pull compares a consumer's copy against. The
# reference consumer's migration wrote nineteen rows there and earned a permanent
# `HARD-UNREGISTERED-CORE-DRIFT` whose two printed remedies respectively DELETE the rows and
# file them where no reader looks. An enforcement model and an ownership model disagreed and
# nothing joined them. The table now lives at the path `layer-contract.yaml` declares as
# `consumer_crosswalk_file:`, which the installer creates once and nothing overwrites.
#
# WHAT MAKES THIS MORE THAN A PATH CHANGE, and it is the bar the spec set: an unmigrated
# consumer and a migrated one MUST NOT produce identical output. Rows in the retired location
# still RESOLVE — a clause that wedged every consumer carrying them would re-create, at the
# instant of the fix, the state the fix exists to clear — so the difference has to be carried
# by something other than an error. W8 is that something, and assertion 6 compares the two
# runs rather than trusting that it fired.
#
# AND ONE DEFECT THIS RELEASE FOUND RATHER THAN INTRODUCED. The reader harvests column 1 of
# every pipe table in the file it is given and did not skip fenced blocks, so core's OWN
# shipped `extensions/README.md` contributed three ids to every consumer's crosswalk set —
# `24` arrived pre-resolved in a tree whose operator had never written a row, and E16 could
# never fire on it. A worked example that satisfies the clause it illustrates is a check that
# cannot fire, and assertion 9 is what keeps core's files at zero.
#
# Usage: run.sh [path-to-validate-layer-entries.sh]
# Exit:  0 = every assertion holds, 1 = something regressed, 2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# TWO LAYOUTS. install.sh splits what shares a parent here: core/fixtures/ becomes
# tests/fixtures/ and core/scripts/ becomes scripts/ai-dlc/. Every candidate is rooted at
# this file's own location — I33 fails the build on a fixture that reaches a core subtree by
# walking up from a path some other resolver produced.
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
LINTER="$(pick "${1:-}" "$HERE/../../scripts/validate-layer-entries.sh" \
                        "$HERE/../../../scripts/ai-dlc/validate-layer-entries.sh" \
                        "$HERE/../../../core/scripts/validate-layer-entries.sh")"
[ -n "$LINTER" ] || { echo "FIXTURE ERROR: cannot locate validate-layer-entries.sh from $HERE" >&2; exit 2; }

# Core's own shipped extensions README — assertion 9's subject. Same two-layout resolution.
CORE_EXT_README="$(pick "$HERE/../../skills/ai-dlc/extensions/README.md" \
                        "$HERE/../../../core/skills/ai-dlc/extensions/README.md" \
                        "$HERE/../../../.claude/skills/ai-dlc/extensions/README.md")"
[ -n "$CORE_EXT_README" ] || { echo "FIXTURE ERROR: cannot locate the shipped extensions/README.md from $HERE" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/layer-crosswalk-home-work.XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT

fails=0
made=0
ok()  { printf '  ok    %s\n' "$1"; made=$((made+1)); }
bad() { printf '  FAIL  %s\n' "$1"; made=$((made+1)); fails=$((fails+1)); }

# EXPECTED_ASSERTIONS is not bookkeeping. A sibling fixture lost an entire mutant to a missing
# space in a helper call: `set -u` killed the `$( )` subshell, `if m="$( … )"` read that as a
# false branch, and the arm silently did not run — green lines, a PASS, and the mutant proving
# the load-bearing branch gone. Counting what actually ran is what closes it.
# 2 premises + 2 state vectors + 1 message content + 1 difference + 1 declaration-is-read + 1 refusal
# + 2 core-yields-zero (claim + control) + 2 installer (scaffold + preserve)
# + 1 unmutated control + 4 mutants.
EXPECTED_ASSERTIONS=17

echo "layer-crosswalk-home:"

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

# A fresh seeded consumer. Every state below starts from one, because the arms under test
# read git history and a state that mutated a previous state's tree would carry its commits.
fresh() { # fresh -> <root>
  local r
  r="$(bash "$HERE/seed.sh" "$(mktemp -d "$WORK/root.XXXXXX")")" || return 1
  printf '%s' "$r"
}

CW_REL="$(sed -n 's/^consumer_crosswalk_file:[ \t]*//p' \
  "$(pick "$HERE/../../skills/ai-dlc/layer-contract.yaml" \
          "$HERE/../../../core/skills/ai-dlc/layer-contract.yaml" \
          "$HERE/../../../.claude/skills/ai-dlc/layer-contract.yaml")" | head -1 | sed 's/[ \t]*$//')"

# The row that resolves the seed's retired id, in the shape the message asks for.
ROW='| 33 | `[ext:domain]` | Cross-story test-strategy deliverable presence | pre-migration gate logs | became 934 |'
TABLE_HEAD='| your id | label | title | resolves a bare citation written before | notes |
|---|---|---|---|---|'

write_new_home() { # write_new_home <root>
  local d="$1/consumer/$CW_REL"
  mkdir -p "$(dirname "$d")"
  printf '# Catalog crosswalk\n\n%s\n%s\n' "$TABLE_HEAD" "$ROW" > "$d"
}

write_legacy() { # write_legacy <root>
  printf '\n## Rows written into the retired location\n\n%s\n%s\n' "$TABLE_HEAD" "$ROW" \
    >> "$1/consumer/.claude/skills/ai-dlc/extensions/README.md"
}

# vector <linter> <root> -> "e16=<n> w8=<n> rc=<n>"
#
# Counts rather than booleans: a mutant that makes an arm fire TWICE is a different defect
# from one that silences it, and a boolean would score both as the same cell.
vector() { # vector <linter> <root>
  local out rc
  out="$(bash "$1" "$2/consumer" 2>&1)"; rc=$?
  printf 'e16=%s w8=%s rc=%s' \
    "$(printf '%s\n' "$out" | grep -c '^ERROR  E16')" \
    "$(printf '%s\n' "$out" | grep -c '^WARN   W8')" \
    "$rc"
}

# ---------------------------------------------------------------------------
# premises — the seed is the zero every assertion moves
# ---------------------------------------------------------------------------
R0="$(fresh)" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }

V0="$(vector "$LINTER" "$R0")"
[ "$V0" = "e16=1 w8=0 rc=1" ] \
  && ok "premise: a consumer with a retired id and NO row anywhere reports E16 and is silent on W8 ($V0)" \
  || bad "premise: expected 'e16=1 w8=0 rc=1' on the pristine seed, got '$V0'"

# The seed's retired id must really be retired, or every cell below is measuring nothing.
if git -C "$R0/consumer" log -p --format='' -- .claude/skills/ai-dlc/extensions/checks/domain.md \
     | grep -q '^+### 33\.' \
   && ! grep -q '^### 33\.' "$R0/consumer/.claude/skills/ai-dlc/extensions/checks/domain.md"; then
  ok "premise: '33' is defined in the history and gone at HEAD (there is a retirement to find)"
else
  bad "premise: '33' is not actually retired in the seed — the vectors below are vacuous"
fi

# ---------------------------------------------------------------------------
# the four states
# ---------------------------------------------------------------------------
R1="$(fresh)"; write_new_home "$R1"
V1="$(vector "$LINTER" "$R1")"
[ "$V1" = "e16=0 w8=0 rc=0" ] \
  && ok "the row in the DECLARED crosswalk file clears E16, says nothing about the retired location, exits 0" \
  || bad "row in the declared crosswalk file: expected 'e16=0 w8=0 rc=0', got '$V1'"

R2="$(fresh)"; write_legacy "$R2"
V2="$(vector "$LINTER" "$R2")"
[ "$V2" = "e16=0 w8=1 rc=0" ] \
  && ok "the SAME row in the retired location still RESOLVES — no wedge — and is reported once by W8" \
  || bad "row in the retired location: expected 'e16=0 w8=1 rc=0', got '$V2'"

# W8 must name what it found, or an operator cannot act on it without diffing two files.
W8LINE="$(bash "$LINTER" "$R2/consumer" 2>&1 | grep '^WARN   W8' || true)"
if grep -q '33' <<<"$W8LINE" && grep -qF "$CW_REL" <<<"$W8LINE"; then
  ok "W8 names the row it found and the path to move it to"
else
  bad "W8 fired without naming the id and the destination: '$W8LINE'"
fi

# THE SPEC'S EXPLICIT BAR. A dual-read that produced the same output for both states would be
# the silent kind, which the spec rules out by name. This compares the runs rather than
# inferring the difference from the fact that a warn exists.
O1="$(bash "$LINTER" "$R1/consumer" 2>&1)"
O2="$(bash "$LINTER" "$R2/consumer" 2>&1)"
[ "$O1" != "$O2" ] \
  && ok "a MIGRATED consumer and an UNMIGRATED one do not produce identical output" \
  || bad "migrated and unmigrated consumers produced byte-identical output — this is the silent dual-read the spec forbids"

# ---------------------------------------------------------------------------
# the declaration is READ, not restated
# ---------------------------------------------------------------------------
# Move the declared path to a filename nothing in the tree hard-codes, put the row there, and
# it must still clear. A reader carrying the literal passes assertion 3 and fails this one.
R3="$(fresh)"
ALT='.claude/skills/ai-dlc/crosswalk-elsewhere.md'
sed "s#^consumer_crosswalk_file:.*#consumer_crosswalk_file: $ALT#" \
  "$R3/consumer/.claude/skills/ai-dlc/layer-contract.yaml" > "$R3/lc.new" \
  && mv "$R3/lc.new" "$R3/consumer/.claude/skills/ai-dlc/layer-contract.yaml"
printf '# Catalog crosswalk\n\n%s\n%s\n' "$TABLE_HEAD" "$ROW" > "$R3/consumer/$ALT"
V3="$(vector "$LINTER" "$R3")"
[ "$V3" = "e16=0 w8=0 rc=0" ] \
  && ok "the crosswalk path is READ from the declaration — moving it moves what the reader reads" \
  || bad "declared path moved to '$ALT' and the row there did not clear E16: got '$V3'"

# ---------------------------------------------------------------------------
# it REFUSES rather than guessing
# ---------------------------------------------------------------------------
# An unreadable declaration and a consumer with no rows are the same empty set otherwise, and
# that set is what E16 and W7 clear themselves against — so a missing key that fell back to
# anything would turn two clauses into unconditional passes.
R4="$(fresh)"; write_new_home "$R4"
grep -v '^consumer_crosswalk_file:' "$R4/consumer/.claude/skills/ai-dlc/layer-contract.yaml" > "$R4/lc.new" \
  && mv "$R4/lc.new" "$R4/consumer/.claude/skills/ai-dlc/layer-contract.yaml"
O4="$(bash "$LINTER" "$R4/consumer" 2>&1)"
if grep -q "could not read 'consumer_crosswalk_file:'" <<<"$O4"; then
  ok "an UNDECLARED crosswalk path is REFUSED by name, not silently treated as an empty table"
else
  bad "removing the declaration did not produce a refusal — E16 and W7 would clear against a set nothing read"
fi

# ---------------------------------------------------------------------------
# core's OWN files contribute nothing
# ---------------------------------------------------------------------------
# The claim, and the control that proves the reader can see a row at all. Without the control
# a broken extractor reads zero and scores as core being clean — this repo's named class, and
# the one this arm exists because of.
harvest() { # harvest <file> -> count
  awk -F'|' '
    /^[[:space:]]*```/ { fence = !fence; next }
    fence { next }
    /^[[:space:]]*\|/ {
      v=$2; gsub(/^[ \t`*]+|[ \t`*]+$/,"",v)
      if (v == "" || v ~ /^-+$/) next
      if (tolower(v) ~ /^your (number|id)$/) next
      print v
    }' "$1" | sort -u | grep -c . || true
}
N_CORE="$(harvest "$CORE_EXT_README")"
[ "$N_CORE" -eq 0 ] \
  && ok "core's shipped extensions/README.md yields ZERO crosswalk ids — no consumer inherits a free resolution" \
  || bad "core's shipped extensions/README.md yields $N_CORE crosswalk id(s); every consumer inherits them and E16 cannot fire on those ids"

cp "$CORE_EXT_README" "$WORK/core-readme-plus-row.md"
printf '\n%s\n%s\n' "$TABLE_HEAD" '| 24 | x | y | z | w |' >> "$WORK/core-readme-plus-row.md"
N_CTRL="$(harvest "$WORK/core-readme-plus-row.md")"
[ "$N_CTRL" -eq 1 ] \
  && ok "CONTROL: the same reader over that file plus ONE unfenced row yields 1 — the zero above is a reading, not a broken extractor" \
  || bad "CONTROL: expected 1 id from the shipped README plus one unfenced row, got $N_CTRL"

# ---------------------------------------------------------------------------
# the installer scaffolds it ONCE
# ---------------------------------------------------------------------------
# The whole ownership claim rests on this. A file the installer re-copies is core's however
# the contract describes it, and the consumer's rows would vanish at the next install.
#
# TWO ARMS THAT EXIST ONLY UPSTREAM, AND THE SKIP IS ASSERTED RATHER THAN ASSUMED.
# `install.sh` is not shipped to consumers, so these arms cannot run in the installed layout.
# A silent skip there would be this repo's named class — an arm that never ran reads exactly
# like one that passed — so the skip states its reason AND proves it: install.sh genuinely
# absent, with a control that a script core DOES ship is present in the same tree. If both
# come back absent the tree is wrong, not consumer-shaped, and that is a FAIL.
INSTALL="$(pick "$HERE/../../../scripts/install.sh")"
if [ -z "$INSTALL" ]; then
  if [ -n "$(pick "$HERE/../../scripts/validate-layer-entries.sh" \
                  "$HERE/../../../scripts/ai-dlc/validate-layer-entries.sh")" ]; then
    ok "install.sh is absent and a shipped script is present: this is a CONSUMER tree, so the two installer arms are distribution-side and do not run here"
    ok "  (the create-once and preserve-on-reinstall claims are proven upstream, where install.sh lives)"
  else
    bad "neither install.sh nor any shipped validator resolves from $HERE — this is not a distribution tree and not a consumer tree, so the installer arms were skipped for an unknown reason"
    bad "  the create-once and preserve-on-reinstall claims are unverified and the skip above is not attributable"
  fi
else
  # `_bmad/` is install.sh's own precondition — it exits 1 without one, and a fixture that
  # skipped this would report "did not scaffold" for a reason that has nothing to do with the
  # scaffold. Creating the marker is what makes the two `bad` branches below mean what they say.
  INST="$WORK/installed"
  mkdir -p "$INST/_bmad" && git init -q "$INST"
  bash "$INSTALL" "$INST" >"$WORK/install.log" 2>&1
  if [ -f "$INST/$CW_REL" ]; then
    ok "install.sh scaffolds the declared crosswalk file into a fresh tree"
    printf '\n%s\n' "$ROW" >> "$INST/$CW_REL"
    SUM_BEFORE="$(cksum < "$INST/$CW_REL")"
    bash "$INSTALL" "$INST" >/dev/null 2>&1
    [ "$(cksum < "$INST/$CW_REL")" = "$SUM_BEFORE" ] \
      && ok "a re-install PRESERVES a populated crosswalk file — the rows are the consumer's" \
      || bad "a re-install overwrote the populated crosswalk file, which is the defect this release exists to end"
  else
    bad "install.sh did not scaffold '$CW_REL' into a fresh tree"
    bad "preserve-on-reinstall not reached: nothing was scaffolded"
  fi
fi

# ---------------------------------------------------------------------------
# mutants — each a COPY, each guarded by cmp -s, each red on exactly one cell
# ---------------------------------------------------------------------------
# Scored by exact VECTOR rather than per-row. Two cells of one branch scored separately report
# entanglement on every mutant in that shape; the vector states the whole expected outcome
# positively and distinctly for each.
MUT="$WORK/mut"; mkdir -p "$MUT"

# full_vector <linter> -> the four states as one string
full_vector() { # full_vector <linter>
  local a b c d ra rb rc rd
  ra="$(fresh)"
  rb="$(fresh)"; write_new_home "$rb"
  rc="$(fresh)"; write_legacy "$rc"
  rd="$(fresh)"; write_new_home "$rd"
  grep -v '^consumer_crosswalk_file:' "$rd/consumer/.claude/skills/ai-dlc/layer-contract.yaml" > "$rd/lc.new" \
    && mv "$rd/lc.new" "$rd/consumer/.claude/skills/ai-dlc/layer-contract.yaml"
  a="$(vector "$1" "$ra")"; b="$(vector "$1" "$rb")"; c="$(vector "$1" "$rc")"
  d="$(bash "$1" "$rd/consumer" 2>&1 | grep -c "could not read 'consumer_crosswalk_file:'")"
  printf 'S0[%s] S1[%s] S2[%s] REFUSE[%s]' "$a" "$b" "$c" "$d"
}

# THE UNMUTATED CONTROL, FIRST AND SERIAL. A lone copy that dies for an unrelated reason emits
# nothing, and "no output" otherwise scores as a kill on every mutant below it.
cp "$LINTER" "$MUT/control.sh"
BASE_VECTOR="$(full_vector "$MUT/control.sh")"
EXPECT='S0[e16=1 w8=0 rc=1] S1[e16=0 w8=0 rc=0] S2[e16=0 w8=1 rc=0] REFUSE[1]'
[ "$BASE_VECTOR" = "$EXPECT" ] \
  && ok "CONTROL: an unmutated copy reproduces the shipped vector (the mutants below run against a live linter)" \
  || bad "CONTROL: unmutated copy gave '$BASE_VECTOR', expected '$EXPECT' — every mutant verdict below is meaningless"

mutant() { # mutant <name> <sed-expr> <expected-vector> <description>
  local n="$1" e="$2" want="$3" desc="$4" got
  sed "$e" "$LINTER" > "$MUT/$n.sh"
  if cmp -s "$LINTER" "$MUT/$n.sh"; then
    bad "MUTANT $n did not apply (sed matched nothing) — a mutation that changes nothing scores a kill it has not earned"
    return
  fi
  got="$(full_vector "$MUT/$n.sh")"
  [ "$got" = "$want" ] \
    && ok "MUTANT killed: $desc" \
    || bad "MUTANT $n: expected '$want', got '$got' — $desc"
}

# M1 — the fence skip. Without it the seed's FENCED worked example contributes its id, so an
# unmigrated tree reports rows it does not have, which is exactly how core shipped `24`
# pre-resolved to every consumer.
mutant fence '/fence = !fence/d' \
  'S0[e16=1 w8=1 rc=1] S1[e16=0 w8=1 rc=0] S2[e16=0 w8=1 rc=0] REFUSE[1]' \
  'dropping the fenced-block skip makes a WORKED EXAMPLE count as a crosswalk row'

# M2 — W8 itself. The rows still resolve, so nothing errors; the only thing lost is the
# consumer ever being told, which is the silent dual-read the spec forbids.
mutant warn '/^  warn W8 /d' \
  'S0[e16=1 w8=0 rc=1] S1[e16=0 w8=0 rc=0] S2[e16=0 w8=0 rc=0] REFUSE[1]' \
  'deleting W8 makes a migrated and an unmigrated consumer print the same thing'

# M3 — the refusal. A missing declaration falling through to an empty set is two ERROR/WARN
# clauses becoming unconditional passes with nothing to say so.
mutant refuse "/could not read 'consumer_crosswalk_file:'/d" \
  'S0[e16=1 w8=0 rc=1] S1[e16=0 w8=0 rc=0] S2[e16=0 w8=1 rc=0] REFUSE[0]' \
  'deleting the refusal lets an UNDECLARED path read as an empty table'

# M4 — the legacy union. Dropping it wedges every consumer that has not migrated yet, which is
# the state this release found the reference consumer in.
mutant union 's#"\$CROSSWALK_IDS" "\$CROSSWALK_LEGACY_IDS"#"$CROSSWALK_IDS" ""#' \
  'S0[e16=1 w8=0 rc=1] S1[e16=0 w8=0 rc=0] S2[e16=1 w8=1 rc=1] REFUSE[1]' \
  'dropping the retired location from the resolvable set WEDGES an unmigrated consumer'

# ---------------------------------------------------------------------------
if [ "$made" -ne "$EXPECTED_ASSERTIONS" ]; then
  echo "  FAIL  assertion count: ran $made, expected $EXPECTED_ASSERTIONS — an arm did not execute, and one that never ran is silent, not green"
  fails=$((fails+1))
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "layer-crosswalk-home: PASS ($made assertions)"; exit 0
else
  echo "layer-crosswalk-home: FAIL ($fails of $made)"; exit 1
fi
