#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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
# MUTANTS. Each is a copy of the subject, scored per push on its DECIDING arm (which must FAIL under it)
# and its TWIN arm(s) (which must HOLD); the live pass over the shipped subject keeps every world. The
# four linter arms are the four worlds S0 (no row anywhere), S1 (row in the declared file), S2 (row in
# the retired location) and REFUSE (declaration removed); PSCAF and PPRES are the pull-side scaffold and
# preserve arms. `bash core/fixtures/layer-crosswalk-home/run.sh --matrix` measures every mutant against
# every arm of its subject and prints one MATRIX line per cell. A twin is an arm the matrix shows green
# under the mutant. The matrix is re-measured as .claude/rules/fixture-mutants.md clause 2 ("One run
# per distinct state") requires.
# MUTANT-MATRIX fence decides=S0 twins=S2
# MUTANT-MATRIX warn decides=S2 twins=S0
# MUTANT-MATRIX refuse decides=REFUSE twins=S0
# MUTANT-MATRIX union decides=S2 twins=S1
# MUTANT-MATRIX apply-scaffold decides=PSCAF twins=PPRES
# MUTANT-MATRIX ss-overwrite decides=SSPRES twins=SSCAF
# The BL-978 worlds (G0 non-git, G1 no rule, GX `*.md`, GY `*.txt`, GN negated, GU symlinked parent, GX2/GY2
# the second pull, NB the next pull with an exact-path line, LM the reconcile copy without scaffold-ignore.sh)
# score the scaffold-ignore mutants: each runs ONE apply, in the world its decides cell names before the `.`, and
# reads two cells there. A SIXI.<world> twin is (i)'s property, all six RESOLVED rows printed, read in that run.
# MUTANT-MATRIX drop-call-crosswalk decides=GX.crosswalk twins=SIXI.GX
# MUTANT-MATRIX drop-call-machinery decides=GX.machinery twins=SIXI.GX
# MUTANT-MATRIX drop-call-pr-class decides=GX.pr-class twins=SIXI.GX
# MUTANT-MATRIX drop-call-story-fields decides=GX.story-fields twins=SIXI.GX
# MUTANT-MATRIX drop-call-artifact-paths decides=GX.artifact-paths twins=SIXI.GX
# MUTANT-MATRIX drop-call-smoke-surface decides=GY.smoke-surface twins=SIXI.GY
# MUTANT-MATRIX ignore-verbose decides=GN.ignored twins=SIXI.GN
# MUTANT-MATRIX ignore-ungated decides=G0.unchecked twins=SIXI.G0
# MUTANT-MATRIX drop-preserved-crosswalk decides=GX2.crosswalk twins=GX2.rows
# MUTANT-MATRIX drop-preserved-machinery decides=GX2.machinery twins=GX2.rows
# MUTANT-MATRIX drop-preserved-pr-class decides=GX2.pr-class twins=GX2.rows
# MUTANT-MATRIX drop-preserved-story-fields decides=GX2.story-fields twins=GX2.rows
# MUTANT-MATRIX drop-preserved-artifact-paths decides=GX2.artifact-paths twins=GX2.rows
# MUTANT-MATRIX drop-preserved-smoke-surface decides=GY2.smoke-surface twins=GY2.rows
# MUTANT-MATRIX preserved-to-note decides=GX2.worklist twins=GX2.notes
# MUTANT-MATRIX unchecked-to-note decides=GU.worklist twins=GU.notes
# MUTANT-MATRIX drop-exact-exit decides=NB.exact twins=NB.ended
# MUTANT-MATRIX lib-missing-silent decides=LM.decision twins=LM.ended
# MUTANT-MATRIX drop-default-arm decides=ST.unchecked twins=ST.resolved
# MUTANT-MATRIX finish-rederives decides=FIN.restamp twins=FIN.rows
# MUTANT-MATRIX-DYNAMIC mscore why=every mutant is passed to mutant_killed by name from the one mscore() driver, and each name keeps its own row above
# MUTANT-MATRIX-DYNAMIC sixmut why=the BL-978 mutants reach mutant_killed through a loop variable, and each name keeps its own row above
# MUTANT-MATRIX-REMEASURE bash core/fixtures/layer-crosswalk-home/run.sh --matrix
#
# Usage: run.sh [--matrix] [path-to-validate-layer-entries.sh]
# Exit:  0 = every assertion holds, 1 = something regressed, 2 = fixture broken.
set -uo pipefail

RAW_ARGV=" $* "
MATRIX=0
if [ "${1:-}" = --matrix ]; then MATRIX=1; shift; echo "MATRIX-MODE on"; fi
MATRIX_CELLS=0

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
B_S0=0; B_S1=0; B_S2=0; B_REFUSE=0; B_PSCAF=0; B_PPRES=0; B_SSCAF=0; B_SSPRES=0; MUT_APPLY_READY=0
ok()  { printf '  ok    %s\n' "$1"; made=$((made+1)); }
bad() { printf '  FAIL  %s\n' "$1"; made=$((made+1)); fails=$((fails+1)); }

# EXPECTED_ASSERTIONS is not bookkeeping. A sibling fixture lost an entire mutant to a missing
# space in a helper call: `set -u` killed the `$( )` subshell, `if m="$( … )"` read that as a
# false branch, and the arm silently did not run — green lines, a PASS, and the mutant proving
# the load-bearing branch gone. Counting what actually ran is what closes it.
# 2 premises + 2 state vectors + 1 message content + 1 difference + 1 declaration-is-read + 1 refusal
# + 2 core-yields-zero (claim + control)
# + 3 pull-side (scaffold, preserve, refusal)
# + 3 smoke-surface pull-side (scaffold, preserve, undeclared) + 1 smoke-surface mutant (overwrite)
# + 1 unmutated control + 5 mutants (4 linter + the pull scaffold) + 1 plain-run arm   = 24
# + BL-978's scaffold-ignore block, SIX_ASSERTIONS = 40: 20 arms (the G0 premise, (i)-(v), the GU
#   unchecked control, (vi) second-pull WORKLIST, (vii) G1 second pull, (viii) tracked path, (F1)
#   the ordinary pull and (F2) --finish over undisposed rows, the next-pull cells (a) (b) (c), the
#   near-misses, exact-plus-negation, LM lib-missing reached, LN lib-missing unreached, ST an
#   undocumented state) and 20 mutants (6 drop-call, ignore-verbose, ignore-ungated,
#   6 drop-preserved, preserved-to-note, unchecked-to-note, drop-exact-exit, lib-missing-silent,
#   drop-default-arm, finish-rederives)                                                         = 64
# The 2 installer arms (scaffold + preserve) moved to schema-install-fallback, which declares
# scripts/install.sh; this fixture ships and cannot.
EXPECTED_ASSERTIONS=64

MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found at $MUT_LIB" >&2; exit 2; }

# shellcheck disable=SC1090
. "$MUT_LIB"
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

CW_REL="$(sed -n 's/^consumer_crosswalk_file:[[:space:]]*//p' \
  "$(pick "$HERE/../../skills/ai-dlc/layer-contract.yaml" \
          "$HERE/../../../core/skills/ai-dlc/layer-contract.yaml" \
          "$HERE/../../../.claude/skills/ai-dlc/layer-contract.yaml")" | head -1 | sed 's/[[:space:]]*$//')"
# The smoke surface (BL-845): its declared path out of the same shipped contract, and the REAL template
# the pull scaffolds it from, so the scaffold arm compares against the bytes a consumer receives.
SS_REL="$(sed -n 's/^consumer_smoke_surface_file:[[:space:]]*//p' \
  "$(pick "$HERE/../../skills/ai-dlc/layer-contract.yaml" \
          "$HERE/../../../core/skills/ai-dlc/layer-contract.yaml" \
          "$HERE/../../../.claude/skills/ai-dlc/layer-contract.yaml")" | head -1 | sed 's/[[:space:]]*$//')"
SS_TPL="$(pick "$HERE/../../skills/ai-dlc/templates/smoke-surface.txt" \
               "$HERE/../../../core/skills/ai-dlc/templates/smoke-surface.txt" \
               "$HERE/../../../.claude/skills/ai-dlc/templates/smoke-surface.txt")"
[ -n "$SS_REL" ] && [ -n "$SS_TPL" ] \
  || { echo "FIXTURE ERROR: the shipped contract declares no consumer_smoke_surface_file:, or templates/smoke-surface.txt is absent" >&2; exit 2; }
# The other four create-once paths (BL-978's six-arm worlds), read out of the same shipped contract.
LC_SHIPPED="$(pick "$HERE/../../skills/ai-dlc/layer-contract.yaml" \
                   "$HERE/../../../core/skills/ai-dlc/layer-contract.yaml" \
                   "$HERE/../../../.claude/skills/ai-dlc/layer-contract.yaml")"
lc_key() { sed -n "s/^$1:[[:space:]]*//p" "$LC_SHIPPED" | head -1 | sed 's/[[:space:]]*$//'; }
MC_REL="$(lc_key consumer_machinery_file)"; PC_REL="$(lc_key consumer_pr_class_file)"
SF_REL="$(lc_key consumer_story_fields_file)"; AP_REL="$(lc_key consumer_artifact_paths_file)"
[ -n "$MC_REL" ] && [ -n "$PC_REL" ] && [ -n "$SF_REL" ] && [ -n "$AP_REL" ] \
  || { echo "FIXTURE ERROR: the shipped contract lacks one of consumer_machinery_file:, consumer_pr_class_file:, consumer_story_fields_file:, consumer_artifact_paths_file:" >&2; exit 2; }

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

echo "HERMETIC-CONSUMED core/scripts/validate-layer-entries.sh"
V0="$(vector "$LINTER" "$R0")"
[ "$V0" = "e16=1 w8=0 rc=1" ] \
  && { B_S0=1; ok "premise: a consumer with a retired id and NO row anywhere reports E16 and is silent on W8 ($V0)"; } \
  || bad "premise: expected 'e16=1 w8=0 rc=1' on the pristine seed, got '$V0'"

# The seed's retired id must really be retired, or every cell below is measuring nothing.
if grep -q '^+### 33\.' \
     <<<"$(git -C "$R0/consumer" log -p --format='' -- .claude/skills/ai-dlc/extensions/checks/domain.md)" \
   && ! grep -q '^### 33\.' "$R0/consumer/.claude/skills/ai-dlc/extensions/checks/domain.md"; then
  ok "premise: '33' is defined in the history and gone at HEAD (there is a retirement to find)"
else
  bad "premise: '33' is not actually retired in the seed — the vectors below are vacuous"
fi

# ---------------------------------------------------------------------------
# the four states
# ---------------------------------------------------------------------------
R1="$WORK/w1"; cp -R "$R0" "$R1"; write_new_home "$R1"
V1="$(vector "$LINTER" "$R1")"
[ "$V1" = "e16=0 w8=0 rc=0" ] \
  && { B_S1=1; ok "the row in the DECLARED crosswalk file clears E16, says nothing about the retired location, exits 0"; } \
  || bad "row in the declared crosswalk file: expected 'e16=0 w8=0 rc=0', got '$V1'"

R2="$WORK/w2"; cp -R "$R0" "$R2"; write_legacy "$R2"
V2="$(vector "$LINTER" "$R2")"
[ "$V2" = "e16=0 w8=1 rc=0" ] \
  && { B_S2=1; ok "the SAME row in the retired location still RESOLVES — no wedge — and is reported once by W8"; } \
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
R3="$WORK/w3"; cp -R "$R0" "$R3"
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
R4="$WORK/w4"; cp -R "$R0" "$R4"; write_new_home "$R4"
grep -v '^consumer_crosswalk_file:' "$R4/consumer/.claude/skills/ai-dlc/layer-contract.yaml" > "$R4/lc.new" \
  && mv "$R4/lc.new" "$R4/consumer/.claude/skills/ai-dlc/layer-contract.yaml"
O4="$(bash "$LINTER" "$R4/consumer" 2>&1)"
if grep -q "could not read 'consumer_crosswalk_file:'" <<<"$O4"; then
  B_REFUSE=1; ok "an UNDECLARED crosswalk path is REFUSED by name, not silently treated as an empty table"
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
# the installer scaffolds it ONCE — asserted in schema-install-fallback, not here
# ---------------------------------------------------------------------------
# The whole ownership claim rests on this. A file the installer re-copies is core's however
# the contract describes it, and the consumer's rows would vanish at the next install.
#
# THE TWO INSTALLER ARMS LIVE IN `schema-install-fallback`, WHICH IS `.dist-only` AND DECLARES
# `scripts/install.sh` REQUIRED. They used to sit here behind a layout test, and that test was
# the defect: this fixture SHIPS, so it cannot declare install.sh (a declared path absent on a
# consumer is exit 2), so its sandbox read as a consumer tree and the two arms stood down on
# every gated run while printing ok. They never ran where the gate could see them. The line
# below is not an assertion and does not count toward EXPECTED_ASSERTIONS: there is nothing
# left here that can skip, so there is no skip to attribute.
echo "  --    the create-once and preserve-on-reinstall installer arms run in schema-install-fallback (.dist-only, declares scripts/install.sh)"

# ---------------------------------------------------------------------------
# THE PULL scaffolds it too, and this is the arm whose absence shipped
# ---------------------------------------------------------------------------
# MEASURED ON THE REFERENCE CONSUMER, one release after the installer arm went green.
# `install.sh` is not something a consumer ever runs again — a pull is how an existing tree
# receives everything — so a create-once file introduced after that tree was installed
# arrives through `apply.sh` or it does not arrive. It did not. The contract landed
# declaring `consumer_crosswalk_file:`, the template landed under `templates/`, W8 told the
# operator to move their rows to a path that did not exist, and no probe anywhere reported
# an absence. The two installer assertions were green throughout: `install.sh` and
# `apply.sh` are different programs and only one of them was being asked.
#
# These arms run in BOTH layouts, unlike the installer's, because `apply.sh` IS shipped.
APPLY="$(pick "$HERE/../../skills/ai-dlc-update/reconcile/apply.sh" \
              "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/apply.sh")"
if [ -z "$APPLY" ]; then
  bad "cannot locate ai-dlc-update/reconcile/apply.sh from $HERE — the pull-side scaffold arms did not run, and an arm that never ran is silent rather than green"
  bad "  (scaffold-on-pull, preserve-on-pull, refusal and the mutant are all unverified)"
  bad "  "
  bad "  "
else
  # A synthetic distribution: two commits, and a consumer stamped at the first. It ships a
  # core validator because a DIST that ships none makes `manifest_dests` empty, which apply
  # correctly reports as manifest-unreadable — the run would then fail for a reason that has
  # nothing to do with the crosswalk.
  synth() { # synth <declare-key: yes|no> -> "<dist> <base> <consumer> <theirs>"
    local d c
    d="$(mktemp -d "$WORK/dist.XXXXXX")"; c="$(mktemp -d "$WORK/cons.XXXXXX")"
    mkdir -p "$d/core/scripts" "$d/core/skills/ai-dlc/templates" "$c/.claude/skills/ai-dlc"
    git -C "$d" init -q 2>/dev/null || return 1
    printf '1.0.0\n' > "$d/VERSION"
    printf '#!/usr/bin/env bash\necho v1\n' > "$d/core/scripts/validate-synthetic.sh"
    # The yes world declares the smoke surface too, so one pull exercises both scaffolds; the no world
    # ships the SAME smoke template undeclared, so "nothing written" there is about the declaration.
    if [ "$1" = yes ]; then
      printf 'contract_version: 1\nconsumer_crosswalk_file: %s\nconsumer_smoke_surface_file: %s\n' "$CW_REL" "$SS_REL" > "$d/core/skills/ai-dlc/layer-contract.yaml"
    elif [ "$1" = six ]; then
      # The six world declares every create-once key, so one pull reaches all six scaffold arms; the four
      # templates the other worlds do not ship are written here, the crosswalk and smoke ones below as ever.
      printf 'contract_version: 1\nconsumer_crosswalk_file: %s\nconsumer_machinery_file: %s\nconsumer_pr_class_file: %s\nconsumer_story_fields_file: %s\nconsumer_artifact_paths_file: %s\nconsumer_smoke_surface_file: %s\n' \
        "$CW_REL" "$MC_REL" "$PC_REL" "$SF_REL" "$AP_REL" "$SS_REL" > "$d/core/skills/ai-dlc/layer-contract.yaml"
      local t; for t in "$MC_REL" "$PC_REL" "$SF_REL" "$AP_REL"; do
        printf '# scaffold template for %s\nnone\n' "$t" > "$d/core/skills/ai-dlc/templates/$(basename "$t")"
      done
    elif [ "$1" = none ]; then
      : # The none world ships NO layer contract, so every scaffold arm is silent (THEIRS predates it).
    else
      printf 'contract_version: 1\n' > "$d/core/skills/ai-dlc/layer-contract.yaml"
    fi
    printf '# Catalog crosswalk\n\n%s\n' "$TABLE_HEAD" > "$d/core/skills/ai-dlc/templates/$(basename "$CW_REL")"
    cp "$SS_TPL" "$d/core/skills/ai-dlc/templates/$(basename "$SS_REL")" || return 1
    git -C "$d" -c user.email=f@f -c user.name=fixture add -A >/dev/null 2>&1
    git -C "$d" -c user.email=f@f -c user.name=fixture commit -qm base >/dev/null 2>&1
    local b; b="$(git -C "$d" rev-parse HEAD)"
    printf '2.0.0\n' > "$d/VERSION"
    printf '#!/usr/bin/env bash\necho v2\n' > "$d/core/scripts/validate-synthetic.sh"
    git -C "$d" -c user.email=f@f -c user.name=fixture add -A >/dev/null 2>&1
    git -C "$d" -c user.email=f@f -c user.name=fixture commit -qm theirs >/dev/null 2>&1
    printf 'version: 1.0.0\ncommit: %s\n' "$b" > "$c/.claude/.ai-dlc-version"
    [ "$1" = none ] || cp "$d/core/skills/ai-dlc/layer-contract.yaml" "$c/.claude/skills/ai-dlc/layer-contract.yaml"
    # The none world's consumer already holds BASE's validator at its installed path, so its pull is a
    # clean apply that re-stamps: LN's two runs then differ only in whether the sibling loaded.
    if [ "$1" = none ]; then
      mkdir -p "$c/scripts/ai-dlc" && printf '#!/usr/bin/env bash\necho v1\n' > "$c/scripts/ai-dlc/validate-synthetic.sh" || return 1
    fi
    printf '%s %s %s %s' "$d" "$b" "$c" "$(git -C "$d" rev-parse HEAD)"
  }

  # --- the file arrives, and it arrives as THEIRS' template rather than as anything ------
  read -r SD SB SC ST <<<"$(synth yes)"
  echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/apply.sh"
  bash "$APPLY" "$SD" "$SB" "$SC" "$ST" > "$WORK/apply1.out" 2>&1
  if [ -f "$SC/$CW_REL" ] \
     && cmp -s "$SC/$CW_REL" "$SD/core/skills/ai-dlc/templates/$(basename "$CW_REL")"; then
    B_PSCAF=1; ok "the PULL scaffolds the declared crosswalk file, byte-identical to the template THEIRS ships"
  else
    bad "apply left '$CW_REL' absent or unlike the template — this is the defect the 0.227.0 pull shipped: a declared path nothing creates"
  fi

  # The smoke surface (BL-845), scaffolded by the same pull: bytes are the shipped template's, and the
  # pull says so with its RESOLVED row.
  if [ -f "$SC/$SS_REL" ] && cmp -s "$SC/$SS_REL" "$SS_TPL" \
     && [ "$(awk -F'\t' -v p="$SS_REL" '$1=="RESOLVED" && $2=="smoke-surface-scaffold" && $3==p' "$WORK/apply1.out" | grep -c .)" = 1 ]; then
    B_SSCAF=1; ok "the PULL scaffolds the declared smoke surface ($SS_REL), byte-identical to the shipped template, with RESOLVED smoke-surface-scaffold"
  else
    bad "apply left the declared smoke surface '$SS_REL' absent, unlike the template, or unreported: $(grep 'smoke-surface' "$WORK/apply1.out" | tr '\n' ' ' | cut -c1-200)"
  fi

  # --- and it is the consumer's from there ----------------------------------------------
  printf '%s\n' "$ROW" >> "$SC/$CW_REL"
  SUM="$(cksum < "$SC/$CW_REL")"
  printf 'web/src/**\n' >> "$SC/$SS_REL"; cp "$SC/$SS_REL" "$WORK/ss.kept"
  bash "$APPLY" "$SD" "$SB" "$SC" "$ST" > "$WORK/apply1b.out" 2>&1
  [ "$(cksum < "$SC/$CW_REL")" = "$SUM" ] \
    && { B_PPRES=1; ok "a SECOND pull preserves a populated crosswalk file — the rows are the consumer's"; } \
    || bad "a second pull overwrote the populated crosswalk file, which is the whole ownership claim"
  if cmp -s "$SC/$SS_REL" "$WORK/ss.kept" && ! grep -q 'smoke-surface-scaffold' "$WORK/apply1b.out"; then
    B_SSPRES=1; ok "a SECOND pull leaves a smoke surface the consumer wrote byte-for-byte unchanged, and reports no scaffold"
  else
    bad "a second pull rewrote the consumer's smoke surface '$SS_REL' or reported scaffolding it again"
  fi

  # --- an undeclared path is REFUSED, and the refusal withholds the stamp ----------------
  # A pull that quietly declares a path it did not create hands the next migration a
  # destination that is not there, and the failure surfaces as rows written into a file
  # nothing reads — the state this mechanism replaced.
  read -r ND NB NC NT <<<"$(synth no)"
  bash "$APPLY" "$ND" "$NB" "$NC" "$NT" > "$WORK/apply2.out" 2>&1
  if grep -q '^DECISION	crosswalk-undeclared' "$WORK/apply2.out" \
     && grep -q '^DECISION	restamp-withheld' "$WORK/apply2.out" \
     && [ ! -f "$NC/$CW_REL" ]; then
    ok "THEIRS declaring no crosswalk file is REFUSED by name and withholds the re-stamp, rather than guessing a path"
  else
    bad "an undeclared crosswalk file did not produce 'DECISION crosswalk-undeclared' plus a withheld re-stamp: $(tr '\n' ' ' < "$WORK/apply2.out" | cut -c1-200)"
  fi
  # The same undeclaring THEIRS ships the smoke template: with no declaration nothing is written and no
  # smoke-surface row of any kind is printed (the smoke arms fall back to their default and SKIP).
  if [ ! -e "$NC/$SS_REL" ] && ! grep -q 'smoke-surface' "$WORK/apply2.out" \
     && git -C "$ND" cat-file -e "${NT}:core/skills/ai-dlc/templates/$(basename "$SS_REL")" 2>/dev/null; then
    ok "THEIRS shipping the smoke template WITHOUT the declaration writes no smoke surface and prints no smoke-surface row"
  else
    bad "an undeclared smoke surface was written, reported, or the world did not ship the template it must ignore"
  fi

  # --- MUTANT: the write itself. Without it every reading above still looks like a pull ---
  # The whole reconcile directory is copied, not the one script: apply.sh reads its sibling
  # setup-sites.md for the manifest, and a lone copy would fail for that reason instead.
  MUTDIR="$WORK/apply-mut"
  cp -R "$(dirname "$APPLY")" "$MUTDIR" 2>/dev/null
  # THE BRANCH CONDITION, not the write and not the line: making the guard unreachable
  # reproduces exactly the state v0.227.0 shipped — a pull that completes, re-stamps, and
  # leaves the declared path empty.
  #
  # THREE GUARDS, because this arm has already passed twice for the wrong reason. The first
  # cut mutated the wrong line and the file appeared anyway; the second's expression was
  # malformed, the tool died mid-write, and the "mutant" was a truncated script that could
  # not create anything — `cmp -s` calls a truncated file different, so it scored a kill it
  # had not earned. DELETING the line has the same defect in a subtler form: it leaves an
  # `if` with a dangling body, and a mutant that does not parse proves only that bash
  # refused it. So the copy must differ, still parse, and still carry the rest of the block.
  sed 's|^elif \[ ! -f .* \]; then$|elif false; then|' "$APPLY" > "$MUTDIR/apply.sh"
  if cmp -s "$APPLY" "$MUTDIR/apply.sh"; then
    bad "MUTANT apply-scaffold did not apply (the branch condition was not found) — a mutation that changes nothing scores a kill it has not earned"
  elif ! bash -n "$MUTDIR/apply.sh" 2>/dev/null || ! grep -q 'crosswalk-scaffold' "$MUTDIR/apply.sh"; then
    bad "MUTANT apply-scaffold produced a script that does not parse or lost the block it was meant to reach — the copy is damaged rather than mutated, so anything it fails to do is unattributable"
  else
    MUT_APPLY_READY=1
  fi
fi

# ---------------------------------------------------------------------------
# mutants — each a COPY, each guarded by cmp -s, each red on exactly one cell
# ---------------------------------------------------------------------------
# Scored by exact VECTOR rather than per-row. Two cells of one branch scored separately report
# entanglement on every mutant in that shape; the vector states the whole expected outcome
# positively and distinctly for each.
MUT="$WORK/mut"; mkdir -p "$MUT"

# One arm = one world, built ONCE above and only read by the linter. armv <arm> <linter> prints 1
# when the arm's expected outcome holds under that linter copy.
armv() { # armv <arm> <linter>
  case "$1" in
    S0)     [ "$(vector "$2" "$R0")" = "e16=1 w8=0 rc=1" ] && echo 1 || echo 0 ;;
    S1)     [ "$(vector "$2" "$R1")" = "e16=0 w8=0 rc=0" ] && echo 1 || echo 0 ;;
    S2)     [ "$(vector "$2" "$R2")" = "e16=0 w8=1 rc=0" ] && echo 1 || echo 0 ;;
    REFUSE) [ "$(bash "$2" "$R4/consumer" 2>&1 | grep -c "could not read 'consumer_crosswalk_file:'")" = 1 ] && echo 1 || echo 0 ;;
  esac
}
armb() { eval "printf '%s' \"\$B_$1\""; } # armb <arm> -> the live base-pass flag of that arm

# mscore <mutant> <description> <linter-copy> <deciding-arm> <twin>... : the deciding arm must FAIL under
# the copy and every twin must HOLD. --matrix runs every linter arm and prints one MATRIX line per cell.
ARMS_LINTER="S0 S1 S2 REFUSE"
armsall() { local t; for t in "$@"; do [ "$(armb "$t")" = 1 ] || { echo 0; return; }; done; echo 1; } # 1 iff every named arm's base flag is live
mscore() {
  local m="$1" desc="$2" lin="$3" dec="$4" t a v dv held=1 flag=0; shift 4
  if [ "$(armsall "$dec" "$@")" = 1 ]; then flag=1; else bad "MUTANT $m: an arm it drives ($dec $*) did not pass unmutated in this run, so its kill cannot score"; fi
  if [ "$MATRIX" = 1 ]; then
    for a in $ARMS_LINTER; do
      v="$(armv "$a" "$lin")"; eval "CELL_$a=\$v"
      printf 'MATRIX\t%s\t%s\t%s\n' "$m" "$a" "$([ "$v" = 1 ] && echo ok || echo FAIL)"
      MATRIX_CELLS=$((MATRIX_CELLS + 1))
    done
  else
    for a in "$dec" "$@"; do v="$(armv "$a" "$lin")"; eval "CELL_$a=\$v"; done
  fi
  eval "dv=\$CELL_$dec"
  for t in "$@"; do eval "v=\$CELL_$t"; [ "$v" = 1 ] || held=0; done
  if [ "$dv" != 1 ] && [ "$held" = 1 ]; then
    mutant_killed "$flag" "$m" "MUTANT killed: $desc"
  else
    bad "MUTANT $m: deciding arm $dec failed=$([ "$dv" != 1 ] && echo yes || echo no), twins held=$held — $desc"
  fi
}

# THE UNMUTATED CONTROL, FIRST AND SERIAL. A lone copy that dies for an unrelated reason emits
# nothing, and "no output" otherwise scores as a kill on every mutant below it.
cp "$LINTER" "$MUT/control.sh"
CTRL=""; for a in $ARMS_LINTER; do CTRL="$CTRL $a=$(armv "$a" "$MUT/control.sh")"; done
[ "$CTRL" = " S0=1 S1=1 S2=1 REFUSE=1" ] \
  && ok "CONTROL: an unmutated copy holds all four linter arms (the mutants below run against a live linter)" \
  || bad "CONTROL: unmutated copy gave '$CTRL', expected all four arms to hold — every mutant verdict below is meaningless"

mkmut() { # mkmut <name> <sed-expr> -> 0 when the copy differs
  sed "$2" "$LINTER" > "$MUT/$1.sh"
  if cmp -s "$LINTER" "$MUT/$1.sh"; then
    bad "MUTANT $1 did not apply (sed matched nothing) — a mutation that changes nothing scores a kill it has not earned"
    return 1
  fi
}

# M1 — the fence skip. Without it the seed's FENCED worked example contributes its id, so an
# unmigrated tree reports rows it does not have, which is exactly how core shipped `24`
# pre-resolved to every consumer. Other cells it trips: S1.
mkmut fence '/fence = !fence/d' && mscore fence \
  'dropping the fenced-block skip makes a WORKED EXAMPLE count as a crosswalk row' "$MUT/fence.sh" S0 S2

# M2 — W8 itself. The rows still resolve, so nothing errors; the only thing lost is the
# consumer ever being told, which is the silent dual-read the spec forbids.
mkmut warn '/^  warn W8 /d' && mscore warn \
  'deleting W8 makes a migrated and an unmigrated consumer print the same thing' "$MUT/warn.sh" S2 S0

# M3 — the refusal. A missing declaration falling through to an empty set is two ERROR/WARN
# clauses becoming unconditional passes with nothing to say so.
mkmut refuse "/could not read 'consumer_crosswalk_file:'/d" && mscore refuse \
  'deleting the refusal lets an UNDECLARED path read as an empty table' "$MUT/refuse.sh" REFUSE S0

# M4 — the legacy union. Dropping it wedges every consumer that has not migrated yet, which is
# the state this release found the reference consumer in.
mkmut union 's#"\$CROSSWALK_IDS" "\$CROSSWALK_LEGACY_IDS"#"$CROSSWALK_IDS" ""#' && mscore union \
  'dropping the retired location from the resolvable set WEDGES an unmigrated consumer' "$MUT/union.sh" S2 S1

# M5 — the pull scaffold: one synthetic world; the mutated apply runs once for the scaffold arm and a
# second time for the preserve arm, whose twin holds because the consumer's appended row survives.
if [ "$MUT_APPLY_READY" = 1 ]; then
  read -r MD MB MC MT <<<"$(synth yes)"
  bash "$MUTDIR/apply.sh" "$MD" "$MB" "$MC" "$MT" >/dev/null 2>&1
  m_sc=0; if [ -f "$MC/$CW_REL" ] && cmp -s "$MC/$CW_REL" "$MD/core/skills/ai-dlc/templates/$(basename "$CW_REL")"; then m_sc=1; fi
  mkdir -p "$(dirname "$MC/$CW_REL")"; printf '%s\n' "$ROW" >> "$MC/$CW_REL"; MSUM="$(cksum < "$MC/$CW_REL")"
  bash "$MUTDIR/apply.sh" "$MD" "$MB" "$MC" "$MT" >/dev/null 2>&1
  m_pp=0; [ "$(cksum < "$MC/$CW_REL")" = "$MSUM" ] && m_pp=1
  if [ "$MATRIX" = 1 ]; then
    printf 'MATRIX\tapply-scaffold\tPSCAF\t%s\nMATRIX\tapply-scaffold\tPPRES\t%s\n' \
      "$([ "$m_sc" = 1 ] && echo ok || echo FAIL)" "$([ "$m_pp" = 1 ] && echo ok || echo FAIL)"
    MATRIX_CELLS=$((MATRIX_CELLS + 2))
  fi
  if [ "$m_sc" = 0 ] && [ "$m_pp" = 1 ]; then
    mutant_killed "$(( ${B_PSCAF:-0} && ${B_PPRES:-0} ))" apply-scaffold "MUTANT killed: with the scaffold removed the pull completes and the declared path stays EMPTY — which is exactly what shipped"
  else
    bad "MUTANT apply-scaffold: scaffold arm failed=$([ "$m_sc" = 0 ] && echo yes || echo no), preserve twin held=$m_pp — the file appeared anyway or the arms are entangled"
  fi
fi

# M6 — the smoke-surface scaffold overwrites a present file: its own guard (the one `$SS_REL` line;
# M5's sed reaches every `elif [ ! -f ... ]` and so cannot isolate it) made always-true. The scaffold
# twin still holds on the first pull; the preserve arm must fail on the second.
SSMUT="$WORK/ss-mut"
if [ -n "$APPLY" ]; then
  cp -R "$(dirname "$APPLY")" "$SSMUT" 2>/dev/null
  SS_A='elif [ ! -f "$CONSUMER/$SS_REL" ]; then'
  if [ "$(grep -cF -- "$SS_A" "$APPLY")" = 1 ] \
     && SS_A="$SS_A" awk '{ i = index($0, ENVIRON["SS_A"]); if (i) $0 = "elif true; then"; print }' "$APPLY" > "$SSMUT/apply.sh" \
     && ! cmp -s "$APPLY" "$SSMUT/apply.sh" && bash -n "$SSMUT/apply.sh" 2>/dev/null && [ -f "$SSMUT/preclassify.sh" ]; then
    read -r MD MB MC MT <<<"$(synth yes)"
    bash "$SSMUT/apply.sh" "$MD" "$MB" "$MC" "$MT" >/dev/null 2>&1
    m_sc=0; [ -f "$MC/$SS_REL" ] && cmp -s "$MC/$SS_REL" "$SS_TPL" && m_sc=1
    printf 'web/src/**\n' >> "$MC/$SS_REL"; cp "$MC/$SS_REL" "$WORK/ss.mkept"
    bash "$SSMUT/apply.sh" "$MD" "$MB" "$MC" "$MT" >/dev/null 2>&1
    m_pp=0; cmp -s "$MC/$SS_REL" "$WORK/ss.mkept" && m_pp=1
    if [ "$MATRIX" = 1 ]; then
      printf 'MATRIX\tss-overwrite\tSSCAF\t%s\nMATRIX\tss-overwrite\tSSPRES\t%s\n' \
        "$([ "$m_sc" = 1 ] && echo ok || echo FAIL)" "$([ "$m_pp" = 1 ] && echo ok || echo FAIL)"
      MATRIX_CELLS=$((MATRIX_CELLS + 2))
    fi
    if [ "$m_pp" = 0 ] && [ "$m_sc" = 1 ]; then
      mutant_killed "$(( ${B_SSCAF:-0} && ${B_SSPRES:-0} ))" ss-overwrite "MUTANT killed: a smoke-surface scaffold that ignores a present file overwrites the consumer's surface on the second pull"
    else
      bad "MUTANT ss-overwrite: preserve arm failed=$([ "$m_pp" = 0 ] && echo yes || echo no), scaffold twin held=$m_sc"
    fi
  else
    bad "MUTANT ss-overwrite did not apply (the smoke-surface guard is not in apply.sh exactly once, or the copy does not parse)"
  fi
fi

# ---------------------------------------------------------------------------
# A SCAFFOLDED PATH THE CONSUMER IGNORES (BL-978): all six create-once arms, one `synth six` world each
# ---------------------------------------------------------------------------
# The RESOLVED rows must not move at all; an ignored scaffolded path adds a SEPARATE
# `WORKLIST scaffold-ignored` row that hands the stamp back. Seven worlds, one apply each:
#   G0 not a git checkout (its precondition asserted here, with the ceiling passed to its apply run),
#   G1 a checkout with no rule, GX `*.md`, GY `*.txt`, GN both rules plus a negation of every path,
#   GU a checkout where the smoke surface's parent directory is a symlink, which makes
#   `check-ignore` exit 128 INSIDE a repository: the WORKLIST scaffold-ignore-unchecked control,
#   GT `*.md` with the crosswalk file already committed by `git add -f` (tracked, so never reported).
# G1, GX and GY then take a SECOND pull over the consumer their first one left (GX2, GY2): every path
# is present, each arm takes its `else`, and an ignored one is again a WORKLIST scaffold-ignored.
# The NEXT-PULL cells start from GY's first-pull consumer and change one thing each: (a) the smoke
# surface committed with `git add -f`, (b) an exact-path line beside the glob (NB, both the `<rel>` and
# the `/<rel>` form), (c) the glob alone; the near-misses `docs/smoke-surface.*`, `**/smoke-surface.txt`
# and `docs/` must still print the row, and an exact line followed by `!<rel>` is not ignored at all.
# LM runs a copy of the reconcile directory WITHOUT scaffold-ignore.sh: one DECISION, no crash. LN runs
# that copy and the real apply.sh over a THEIRS with no layer contract: no arm is reached, both re-stamp.
# ST runs a copy whose scaffold-ignore.sh is a stub answering the undocumented state `bogus`: it must ask.
# The FINISH cells run `apply.sh --finish` over GX's and G1's first-pull consumers, rows undisposed, and over
# GX's with an exact-path line per hidden path: each re-stamps with no scaffold row.
# Every consumer is `git init -q --template=` with `core.excludesFile /dev/null`, and every apply runs
# under GIT_CONFIG_NOSYSTEM=1, so no machine's own ignore rules reach a verdict.
#
# A SHIPPED FIXTURE CAN ARRIVE A PULL AHEAD OF ITS SUBJECT, as apply-restamp-worklist's IS_DIST probe
# states: a pull whose step 2 DEFERs the machinery slice lands this file beside an apply.sh with no
# scaffold_ignore_check, or one that predates scaffold-ignore.sh. "Subject not installed" is not
# "subject regressed", so on a CONSUMER layout this block prints one named SKIP and its SIX_ASSERTIONS
# leave the expected count. In the DISTRIBUTION the subject is always present, so its absence is a
# `bad` and the arms run anyway.
SIX_ASSERTIONS=40 # this block's own: 20 arms and 20 mutants -- the ledger above
IS_DIST=0; [ -d "$HERE/../../../core/skills/ai-dlc" ] && IS_DIST=1
SIX_SKIP=0
if [ -n "$APPLY" ] && { ! grep -q '^scaffold_ignore_check() {' "$APPLY" || ! grep -q 'scaffold-ignore\.sh' "$APPLY"; }; then
  if [ "$IS_DIST" = 1 ]; then
    bad "BL-978: the resolved apply.sh ($APPLY) defines no scaffold_ignore_check, or does not load scaffold-ignore.sh. HARD in the distribution; the arms below run anyway"
  else
    SIX_SKIP=1
    printf '  SKIP  %s\n' "SUBJECT-ABSENT: apply.sh predates scaffold_ignore_check or scaffold-ignore.sh; BL-978 arms not evaluated ($SIX_ASSERTIONS assertions: 20 arms and 20 mutants). They land with the pull that carries the machinery slice."
  fi
fi
if [ -n "$APPLY" ] && [ "$SIX_SKIP" = 0 ]; then
  B_GX2=0; B_GY2=0; B_GU=0; B_NB=0; B_LM=0; B_ST=0; B_FIN=0
  SIX_RELS="$CW_REL $MC_REL $PC_REL $SF_REL $AP_REL $SS_REL"
  # The partition by real extension: GX's rule must hide exactly the .md paths, GY's the .txt ones.
  SIX_MD=""; SIX_TXT=""; six_other=""
  for p in $SIX_RELS; do
    case "$p" in *.md) SIX_MD="$SIX_MD $p" ;; *.txt) SIX_TXT="$SIX_TXT $p" ;; *) six_other="$six_other $p" ;; esac
  done
  six_sorted() { local x; for x in "$@"; do printf '%s\n' "$x"; done | LC_ALL=C sort; } # words -> sorted lines
  SIX_EXP_MD="$(six_sorted $SIX_MD)"; SIX_EXP_TXT="$(six_sorted $SIX_TXT)"; SIX_EXP_ALL="$(six_sorted $SIX_RELS)"
  SIX_KINDS="$(printf 'crosswalk-scaffold\t%s\nmachinery-scaffold\t%s\npr-class-scaffold\t%s\nstory-fields-scaffold\t%s\nartifact-paths-scaffold\t%s\nsmoke-surface-scaffold\t%s\n' \
    "$CW_REL" "$MC_REL" "$PC_REL" "$SF_REL" "$AP_REL" "$SS_REL" | LC_ALL=C sort)"
  SS_DIR="$(dirname "$SS_REL")"

  six_build() { # six_build <W> <git: 0|1> <gitignore text, or ""> ; records "<dist> <base> <consumer> <theirs>" in the world
    local w="$WORK/six-$1" D B C T
    mkdir -p "$w"
    read -r D B C T <<<"$(synth six)"
    [ -n "${T:-}" ] || return 1
    if [ "$2" = 1 ]; then
      git init -q --template= "$C" >/dev/null 2>&1 && git -C "$C" config core.excludesFile /dev/null || return 1
    fi
    [ -z "$3" ] || printf '%s' "$3" > "$C/.gitignore"
    printf '%s %s %s %s\n' "$D" "$B" "$C" "$T" > "$w/.refs"
  }
  six_run() { # six_run <W> <apply.sh> <tag> [<src tag>] : a fresh copy of the world's consumer (or of the consumer
    # an earlier run <src tag> left behind), one apply, output at $WORK/six-<W>/<tag>.out
    local w="$WORK/six-$1" D B C T c
    read -r D B C T < "$w/.refs"
    [ -z "${4:-}" ] || C="$w/cons-$4"
    c="$w/cons-$3"; cp -R "$C" "$c" || return 1
    if [ "$1" = G0 ]; then
      GIT_CEILING_DIRECTORIES="$w" GIT_CONFIG_NOSYSTEM=1 bash "$2" "$D" "$B" "$c" "$T" > "$w/$3.out" 2>&1
    else
      GIT_CONFIG_NOSYSTEM=1 bash "$2" "$D" "$B" "$c" "$T" > "$w/$3.out" 2>&1
    fi
    return 0
  }
  six_res()  { awk -F'\t' '$1=="RESOLVED" && $2 ~ /-scaffold$/' "$1" | LC_ALL=C sort; }                           # the RESOLVED scaffold rows
  six_ign()  { awk -F'\t' '$1=="WORKLIST" && $2=="scaffold-ignored" { print $3 }' "$1" | LC_ALL=C sort; }           # the ignored paths
  six_unc()  { awk -F'\t' '$1=="WORKLIST" && $2=="scaffold-ignore-unchecked" { print $3 }' "$1" | LC_ALL=C sort; }  # the unchecked paths
  six_notes() { awk -F'\t' '$1=="NOTE" && $2 ~ /^scaffold-ignore/ { print $2 "\t" $3 }' "$1" | LC_ALL=C sort; }   # any BL-978 NOTE row: none is owed
  six_any()  { awk -F'\t' '$2 == "scaffold-ignored" || $2 == "scaffold-ignore-unchecked" { print $1 "\t" $2 "\t" $3 }' "$1" | LC_ALL=C sort; } # every BL-978 check row, any tier
  six_fig()  { sed -n 's/.*could not be placed mechanically and \([0-9][0-9]*\) WORKLIST\/DECISION row(s).*/\1/p' "$1" | head -1; }
  six_withheld() { grep -q '^DECISION	restamp-withheld	' "$1"; }                                                   # <out>
  six_ended() { grep -q '^RESOLVED	restamp	' "$1" || six_withheld "$1"; }                                         # <out>: the run reached its stamp decision
  six_stamped() { # six_stamped <W> <tag> -> 0 when the run re-stamped its consumer at theirs
    local D B C T; read -r D B C T < "$WORK/six-$1/.refs"
    grep -qxF "commit: $T" "$WORK/six-$1/cons-$2/.claude/.ai-dlc-version" 2>/dev/null
  }

  six_ok=1
  { [ -z "$six_other" ] && [ -n "$SIX_MD" ] && [ -n "$SIX_TXT" ] \
    && six_build G0 0 "" && six_build G1 1 "" \
    && six_build GX 1 $'*.md\n' && six_build GY 1 $'*.txt\n' \
    && six_build GN 1 "$(printf '*.md\n*.txt\n'; for p in $SIX_RELS; do printf '!%s\n' "$p"; done)"$'\n' \
    && six_build GU 1 "" && six_build GT 1 $'*.md\n' && [ "$SS_DIR" != . ]; } || six_ok=0
  if [ "$six_ok" = 1 ]; then
    read -r _d _b GU_C _t < "$WORK/six-GU/.refs"
    mkdir -p "$WORK/six-GU-elsewhere" && ln -s "$WORK/six-GU-elsewhere" "$GU_C/$SS_DIR" || six_ok=0
    # GT: the crosswalk path is ignored by `*.md` AND committed with `git add -f`, so it is present and tracked.
    read -r _d _b GT_C _t < "$WORK/six-GT/.refs"
    { mkdir -p "$(dirname "$GT_C/$CW_REL")" && printf '# tracked on purpose\n' > "$GT_C/$CW_REL" \
      && git -C "$GT_C" add -f -- "$CW_REL" \
      && git -C "$GT_C" -c user.email=f@f -c user.name=fixture commit -qm tracked >/dev/null 2>&1; } || six_ok=0
  fi
  if [ "$six_ok" = 0 ]; then
    bad "BL-978 six-arm worlds could not be built (partition md='$SIX_MD' txt='$SIX_TXT' other='$six_other', smoke dir '$SS_DIR') — every assertion and mutant below is unverified"
  else
    six_made0="$made" # SIX_ASSERTIONS is bound below to what this block actually emits
    for W in G0 G1 GX GY GN GU GT; do six_run "$W" "$APPLY" base; done
    # The SECOND pull, on the consumer the first one left: every path is now present, so every arm takes
    # its `else` and asks the preserved question.
    for W in G1 GX GY; do six_run "$W" "$APPLY" again base; done
    # The NEXT-PULL cells, each GY's first-pull consumer with one change, then one apply.
    SS_STEM="${SS_REL%.*}"; SS_BASE="$(basename "$SS_REL")"
    six_cell_run() { # six_cell_run <tag> <apply.sh> <prep: a|b|b2|n1|n2|n3|ng>
      local c="$WORK/six-GY/cons-$1"
      cp -R "$WORK/six-GY/cons-base" "$c" || return 1
      case "$3" in
        a)  git -C "$c" add -f -- "$SS_REL" && git -C "$c" -c user.email=f@f -c user.name=fixture commit -qm surface >/dev/null 2>&1 || return 1 ;;
        b)  printf '%s\n' "$SS_REL" >> "$c/.gitignore" ;;
        b2) printf '/%s\n' "$SS_REL" >> "$c/.gitignore" ;;
        n1) printf '%s.*\n' "$SS_STEM" > "$c/.gitignore" ;;
        n2) printf '**/%s\n' "$SS_BASE" > "$c/.gitignore" ;;
        n3) printf '%s/\n' "$SS_DIR" > "$c/.gitignore" ;;
        ng) printf '%s\n!%s\n' "$SS_REL" "$SS_REL" > "$c/.gitignore" ;;
      esac
      local D B C T; read -r D B C T < "$WORK/six-GY/.refs"
      GIT_CONFIG_NOSYSTEM=1 bash "$2" "$D" "$B" "$c" "$T" > "$WORK/six-GY/$1.out" 2>&1
      return 0
    }
    for t in a b b2 n1 n2 n3 ng; do six_cell_run "next-$t" "$APPLY" "$t"; done
    # THE FINISH CELLS: `apply.sh --finish` with the same four arguments over the consumer a first pull left,
    # the scaffold rows NOT disposed: GX's (five WORKLIST scaffold-ignored), G1's (none, the control), and FE,
    # GX's with an exact-path line for each hidden path added first.
    six_finish() { # six_finish <W> <apply.sh> <tag> <src tag> [<prep: exact>]
      local w="$WORK/six-$1" D B C T c p
      read -r D B C T < "$w/.refs"
      c="$w/cons-$3"; cp -R "$w/cons-$4" "$c" || return 1
      if [ "${5:-}" = exact ]; then for p in $SIX_MD; do printf '%s\n' "$p" >> "$c/.gitignore"; done; fi
      GIT_CONFIG_NOSYSTEM=1 bash "$2" --finish "$D" "$B" "$c" "$T" > "$w/$3.out" 2>&1
      return 0
    }
    six_finish GX "$APPLY" finish base; six_finish G1 "$APPLY" finish base; six_finish GX "$APPLY" finish-exact base exact
    # LM: a copy of the reconcile directory WITHOUT scaffold-ignore.sh, one first pull over GX's world.
    LMDIR="$WORK/lm-reconcile"; cp -R "$(dirname "$APPLY")" "$LMDIR" 2>/dev/null; rm -f "$LMDIR/scaffold-ignore.sh"
    lm_pre=0; [ -f "$LMDIR/apply.sh" ] && [ -f "$LMDIR/preclassify.sh" ] && [ ! -e "$LMDIR/scaffold-ignore.sh" ] \
      && [ -f "$(dirname "$APPLY")/scaffold-ignore.sh" ] && lm_pre=1
    six_run GX "$LMDIR/apply.sh" lm
    # LN: THEIRS ships NO layer contract, so no scaffold arm is reached. One run with the lib (the
    # control) and one with LM's sibling-less copy, over copies of the same consumer.
    mkdir -p "$WORK/six-LN"; ln_ok=0
    read -r _ld _lb _lc _lt <<<"$(synth none)"
    if [ -n "${_lt:-}" ]; then
      printf '%s %s %s %s\n' "$_ld" "$_lb" "$_lc" "$_lt" > "$WORK/six-LN/.refs"
      six_run LN "$APPLY" with && six_run LN "$LMDIR/apply.sh" without && ln_ok=1
    fi
    # ST: a copy of the reconcile directory whose scaffold-ignore.sh is a STUB answering the undocumented
    # state `bogus` for every path, one first pull over G1's world (a checkout with no rule).
    STDIR="$WORK/st-reconcile"; cp -R "$(dirname "$APPLY")" "$STDIR" 2>/dev/null
    printf '%s\n' "scaffold_ignore_state() { printf 'bogus\\t\\n'; }" "scaffold_ignore_remedy() { printf 'stub\\n'; }" > "$STDIR/scaffold-ignore.sh"
    st_pre=0; [ -f "$STDIR/apply.sh" ] && [ -f "$STDIR/preclassify.sh" ] && /usr/bin/grep -q "printf 'bogus" "$STDIR/scaffold-ignore.sh" && st_pre=1
    six_run G1 "$STDIR/apply.sh" st

    # G0's premise: with the ceiling at its parent, the consumer is not inside ANY repository, so its
    # zero rows are about a non-git consumer and not about an enclosing checkout's rules.
    if ! GIT_CEILING_DIRECTORIES="$WORK/six-G0" git -C "$WORK/six-G0/cons-base" rev-parse --git-dir >/dev/null 2>&1; then
      g0_pre=1; B_SIXPRE=1; ok "premise: the G0 consumer is in no git repository (rev-parse refuses under a ceiling at its parent)"
    else
      g0_pre=0; bad "premise: the G0 consumer resolves a git directory under its ceiling — an enclosing repository would be read, so G0 proves nothing"
    fi

    # (i) the six RESOLVED rows, byte-identical in every world, and every world has all six
    six_res "$WORK/six-G0/base.out" > "$WORK/six-G0.res"
    i_ok=1; i_why=""
    for W in G0 G1 GX GY GN; do
      six_res "$WORK/six-$W/base.out" > "$WORK/six-$W.res"
      cmp -s "$WORK/six-G0.res" "$WORK/six-$W.res" || { i_ok=0; i_why="$i_why $W:differs-from-G0"; }
      [ "$(cut -f2,3 "$WORK/six-$W.res")" = "$SIX_KINDS" ] || { i_ok=0; i_why="$i_why $W:not-all-six"; }
    done
    [ "$i_ok" = 1 ] \
      && { B_SIXI=1; ok "(i) the six *-scaffold RESOLVED rows are byte-identical across G0, G1, GX, GY and GN, and each world prints all six"; } \
      || bad "(i) the scaffold RESOLVED rows moved or are incomplete:$i_why"

    # (ii) the scaffold-ignored set is EXACTLY the hidden paths, and empty where nothing hides one
    ii_ok=1; ii_why=""
    for W in G0 G1 GX GY GN; do
      case "$W" in GX) e="$SIX_EXP_MD" ;; GY) e="$SIX_EXP_TXT" ;; *) e="" ;; esac
      g="$(six_ign "$WORK/six-$W/base.out")"
      [ "$g" = "$e" ] || { ii_ok=0; ii_why="$ii_why $W:[$(printf '%s' "$g" | tr '\n' ' ')]"; }
    done
    [ "$ii_ok" = 1 ] \
      && { B_SIXII=1; ok "(ii) scaffold-ignored names exactly the .md paths in GX and the .txt path in GY, and nothing in G0, G1 or GN"; } \
      || bad "(ii) the scaffold-ignored row set is wrong:$ii_why"

    # (iii) every such row: four tab fields, the literal force-add of its own path, the matching provenance,
    # and the exact-path exit named with that path
    iii_ok=1; iii_n=0; iii_why=""
    for W in GX GY; do
      case "$W" in GX) pat='*.md' ;; *) pat='*.txt' ;; esac
      while IFS= read -r line; do
        iii_n=$((iii_n+1))
        rel="$(printf '%s' "$line" | cut -f3)"; det="$(printf '%s' "$line" | cut -f4)"
        [ "$(printf '%s\n' "$line" | awk -F'\t' '{ print NF }')" = 4 ] || { iii_ok=0; iii_why="$iii_why $W:$rel:fields"; }
        case "$det" in *"git add -f ${rel}"*) : ;; *) iii_ok=0; iii_why="$iii_why $W:$rel:no-force-add" ;; esac
        case "$det" in *"(.gitignore:1:${pat})"*) : ;; *) iii_ok=0; iii_why="$iii_why $W:$rel:provenance" ;; esac
        case "$det" in *"ignore it by its exact path (a line '${rel}' in .gitignore)"*) : ;; *) iii_ok=0; iii_why="$iii_why $W:$rel:no-exact-exit" ;; esac
      done <<<"$(awk -F'\t' '$1=="WORKLIST" && $2=="scaffold-ignored"' "$WORK/six-$W/base.out")"
    done
    [ "$iii_ok" = 1 ] && [ "$iii_n" = 6 ] \
      && { B_SIXIII=1; ok "(iii) all 6 scaffold-ignored rows carry 4 tab fields, 'git add -f <their path>', the .gitignore:1:<pattern> that hides it and the exact-path exit"; } \
      || bad "(iii) scaffold-ignored rows malformed or missing (read $iii_n of 6):$iii_why"

    # (iv) the rows hand the stamp back: the withheld row's count moves by exactly the hidden paths
    f1="$(six_fig "$WORK/six-G1/base.out")"; fx="$(six_fig "$WORK/six-GX/base.out")"; fy="$(six_fig "$WORK/six-GY/base.out")"
    if six_stamped G1 base && [ -z "$f1" ]; then f1=0; f1_how="G1 re-stamped"; else f1_how="G1 withheld at ${f1:-?}"; fi
    nmd="$(printf '%s\n' "$SIX_EXP_MD" | grep -c .)"; ntxt="$(printf '%s\n' "$SIX_EXP_TXT" | grep -c .)"
    if [ -n "$f1" ] && [ -n "$fx" ] && [ -n "$fy" ] && [ $((fx - f1)) = "$nmd" ] && [ $((fy - f1)) = "$ntxt" ]; then
      ok "(iv) the withheld stamp's WORKLIST/DECISION figure is $fx in GX and $fy in GY against $f1 ($f1_how): it moved by the $nmd and $ntxt hidden paths"
    else
      bad "(iv) the hand-back count did not move by the hidden paths: G1='${f1:-}' ($f1_how) GX='${fx:-}' GY='${fy:-}', expected +$nmd and +$ntxt"
    fi

    # (v) no unchecked row and no NOTE row of BL-978's in the five worlds; GU is the positive control
    v_bad=""
    for W in G0 G1 GX GY GN; do
      [ -z "$(six_unc "$WORK/six-$W/base.out")" ] && [ -z "$(six_notes "$WORK/six-$W/base.out")" ] || v_bad="$v_bad $W"
    done
    [ -z "$v_bad" ] \
      && { B_SIXV=1; ok "(v) no scaffold-ignore-unchecked row and no BL-978 NOTE row in G0, G1, GX, GY or GN"; } \
      || bad "(v) scaffold-ignore-unchecked or a NOTE row printed in:$v_bad"

    o="$WORK/six-GU/base.out"
    six_res "$o" > "$WORK/six-GU.res"
    if [ "$(six_unc "$o")" = "$SS_REL" ] && [ -z "$(six_ign "$o")" ] && [ -z "$(six_notes "$o")" ] \
       && cmp -s "$WORK/six-G0.res" "$WORK/six-GU.res"; then
      B_GU=1; ok "GU: a symlinked '$SS_DIR' makes check-ignore exit outside 0/1 inside a checkout, and the arm prints ONE WORKLIST scaffold-ignore-unchecked for '$SS_REL', no NOTE, the six RESOLVED rows unchanged"
    else
      bad "GU: expected one WORKLIST scaffold-ignore-unchecked for '$SS_REL' and nothing else: unchecked=[$(six_unc "$o" | tr '\n' ' ')] notes=[$(six_notes "$o" | tr '\n' ' ')] ignored=[$(six_ign "$o" | tr '\n' ' ')]"
    fi

    # (vi) THE PRESERVED CASE: the second pull over GX and GY. Every path is on disk, untracked and still
    # ignored by a glob, so each arm reports it AGAIN as a WORKLIST (the row has an exit, so it never wedges
    # a consumer that decided), no NOTE prints, the stamp is withheld, and no scaffold row prints.
    vi_ok=1; vi_why=""
    for W in GX GY; do
      case "$W" in GX) e="$SIX_EXP_MD" ;; *) e="$SIX_EXP_TXT" ;; esac
      o="$WORK/six-$W/again.out"
      [ "$(six_ign "$o")" = "$e" ] || { vi_ok=0; vi_why="$vi_why $W:worklist=[$(six_ign "$o" | tr '\n' ' ')]"; }
      [ -z "$(six_notes "$o")" ] || { vi_ok=0; vi_why="$vi_why $W:notes=[$(six_notes "$o" | tr '\n' ' ')]"; }
      [ -z "$(six_res "$o")" ] && six_withheld "$o" || { vi_ok=0; vi_why="$vi_why $W:not-a-withheld-preserving-run"; }
    done
    if [ "$vi_ok" = 1 ]; then
      B_GX2=1; B_GY2=1; ok "(vi) a second pull over present, untracked, glob-ignored files prints WORKLIST scaffold-ignored for exactly GX's and GY's hidden paths, no NOTE, and withholds the stamp"
    else
      bad "(vi) the preserved case is wrong on the second pull:$vi_why"
    fi

    # (vii) the second pull over G1, which has no rule, reports nothing and re-stamps
    o="$WORK/six-G1/again.out"
    [ -z "$(six_any "$o")" ] && [ -z "$(six_res "$o")" ] && grep -q '^RESOLVED	restamp	' "$o" && ! six_withheld "$o" \
      && ok "(vii) a second pull over G1's present, unignored files prints no BL-978 row and re-stamps" \
      || bad "(vii) G1's second pull: rows=[$(six_any "$o" | tr '\n' ' ')] withheld=$(six_withheld "$o" && echo yes || echo no)"

    # (viii) a TRACKED path is never reported, though `*.md` matches it: GT's crosswalk file is committed
    # with `git add -f`. The other .md paths are scaffolded fresh in the same run and still reported, and
    # `--no-index` confirms the rule does match the tracked path, so the silence is about the index.
    o="$WORK/six-GT/base.out"
    gt_e="$(printf '%s\n' "$SIX_EXP_MD" | grep -vxF -- "$CW_REL")"
    if ! grep -qF -- "	$CW_REL" <<<"$(six_any "$o")" \
       && [ "$(six_ign "$o")" = "$gt_e" ] \
       && git -C "$WORK/six-GT/cons-base" ls-files --error-unmatch -- "$CW_REL" >/dev/null 2>&1 \
       && git -C "$WORK/six-GT/cons-base" check-ignore -q --no-index -- "$CW_REL" 2>/dev/null; then
      ok "(viii) a tracked path its rule matches gets no BL-978 row, while the run still reports the $(printf '%s\n' "$gt_e" | grep -c .) untracked .md paths it scaffolded"
    else
      bad "(viii) GT: the tracked '$CW_REL' was reported, or the control failed: rows=[$(six_any "$o" | tr '\n' ' ')]"
    fi

    # (F1) the ordinary pull the finish follows: GX holds its five WORKLIST scaffold-ignored rows and withholds;
    # G1, the control, holds none and withholds for its other rows.
    o="$WORK/six-GX/base.out"; o1="$WORK/six-G1/base.out"
    [ "$(six_ign "$o")" = "$SIX_EXP_MD" ] && six_withheld "$o" && [ -z "$(six_any "$o1")" ] && six_withheld "$o1" \
      && ok "(F1) the ordinary pull leaves GX's $(printf '%s\n' "$SIX_EXP_MD" | grep -c .) WORKLIST scaffold-ignored rows and a withheld stamp, and G1 none of them" \
      || bad "(F1) ordinary pulls: GX=[$(six_any "$o" | tr '\n' ' ')] withheld=$(six_withheld "$o" && echo y || echo n); G1=[$(six_any "$o1" | tr '\n' ' ')]"
    # (F2) --finish, the rows undisposed: it re-stamps with no scaffold row, in GX, in G1, and with the exact lines
    f2_ok=1; f2_why=""
    for wt in GX:finish G1:finish GX:finish-exact; do
      o="$WORK/six-${wt%%:*}/${wt#*:}.out"
      grep -q '^RESOLVED	restamp	' "$o" && ! six_withheld "$o" && [ -z "$(awk -F'\t' '$2 ~ /scaffold/' "$o")" ] \
        || { f2_ok=0; f2_why="$f2_why $wt:[$(grep 'restamp\|scaffold' "$o" | cut -f1,2 | tr '\n' ' ')]"; }
    done
    [ "$f2_ok" = 1 ] \
      && { B_FIN=1; ok "(F2) apply.sh --finish over the undisposed rows re-stamps with 0 scaffold rows: GX, the G1 control, and GX with exact-path lines"; } \
      || bad "(F2) --finish did not re-stamp cleanly:$f2_why"

    # THE NEXT-PULL CELLS, over GY's first-pull consumer (the smoke surface present and hidden by `*.txt`).
    # (a) committed with `git add -f`: tracked, so no row
    o="$WORK/six-GY/next-a.out"
    [ -z "$(six_any "$o")" ] && six_ended "$o" && git -C "$WORK/six-GY/cons-next-a" ls-files --error-unmatch -- "$SS_REL" >/dev/null 2>&1 \
      && ok "(a) after 'git add -f $SS_REL' and a commit, the next pull prints no BL-978 row" \
      || bad "(a) the committed smoke surface still printed: rows=[$(six_any "$o" | tr '\n' ' ')]"
    # (b) an exact-path line beside the glob, in both forms: still ignored (-q exits 0), and no row
    b_ok=1; b_why=""
    for t in b b2; do
      o="$WORK/six-GY/next-$t.out"
      [ -z "$(six_any "$o")" ] && six_ended "$o" || { b_ok=0; b_why="$b_why $t:rows=[$(six_any "$o" | tr '\n' ' ')]"; }
      git -C "$WORK/six-GY/cons-next-$t" check-ignore -q -- "$SS_REL" 2>/dev/null || { b_ok=0; b_why="$b_why $t:not-ignored"; }
    done
    [ "$b_ok" = 1 ] \
      && { B_NB=1; ok "(b) an exact-path line ('$SS_REL' or '/$SS_REL') beside the glob keeps the file ignored and ends the row: no BL-978 row"; } \
      || bad "(b) the exact-path exit did not end the row:$b_why"
    # (c) the glob alone: the row persists
    o="$WORK/six-GY/again.out"
    [ "$(six_ign "$o")" = "$SS_REL" ] && grep -qF "(a line '$SS_REL' in .gitignore)" <<<"$(awk -F'\t' '$2=="scaffold-ignored" { print $4 }' "$o")" \
      && ok "(c) with the glob alone the next pull prints WORKLIST scaffold-ignored '$SS_REL' again, naming the exact-path line" \
      || bad "(c) the glob-only next pull did not print the row: rows=[$(six_any "$o" | tr '\n' ' ')]"
    # the near-misses: a pattern that matches without naming the exact path is not a decision
    nm_ok=1; nm_why=""
    for t in n1 n2 n3; do
      o="$WORK/six-GY/next-$t.out"
      case "$t" in n1) p="$SS_STEM.*" ;; n2) p="**/$SS_BASE" ;; *) p="$SS_DIR/" ;; esac
      [ "$(six_ign "$o")" = "$SS_REL" ] && grep -qF "(.gitignore:1:$p)" <<<"$(awk -F'\t' '$2=="scaffold-ignored" { print $4 }' "$o")" \
        || { nm_ok=0; nm_why="$nm_why $p:[$(six_any "$o" | tr '\n' ' ')]"; }
    done
    [ "$nm_ok" = 1 ] \
      && ok "near-misses: '$SS_STEM.*', '**/$SS_BASE' and '$SS_DIR/' each still print WORKLIST scaffold-ignored, with their own provenance" \
      || bad "near-misses did not each print the row:$nm_why"
    # an exact line followed by `!<rel>`: not ignored at all (-q exits 1), so no row
    o="$WORK/six-GY/next-ng.out"
    git -C "$WORK/six-GY/cons-next-ng" check-ignore -q -- "$SS_REL" 2>/dev/null; ng_rc=$?
    [ -z "$(six_any "$o")" ] && six_ended "$o" && [ "$ng_rc" = 1 ] \
      && ok "exact line then '!$SS_REL': check-ignore -q exits 1 and the next pull prints no BL-978 row" \
      || bad "exact-plus-negation: -q exit $ng_rc, rows=[$(six_any "$o" | tr '\n' ' ')]"

    # LM: the sibling missing is ONE DECISION, a counted mechanical failure, no check, and no crash
    o="$WORK/six-GX/lm.out"
    if [ "$lm_pre" = 1 ] && [ "$(awk -F'\t' '$1=="DECISION" && $2=="scaffold-ignore-lib-missing"' "$o" | grep -c .)" = 1 ] \
       && [ "$(six_res "$o" | cut -f2,3)" = "$SIX_KINDS" ] && [ -z "$(six_any "$o")" ] && six_withheld "$o" \
       && ! grep -q '^RESOLVED	restamp	' "$o"; then
      B_LM=1; ok "LM: apply.sh copied without scaffold-ignore.sh, on a run that reaches the scaffold arms, prints ONE DECISION scaffold-ignore-lib-missing, all six RESOLVED rows, no check row, DECISION restamp-withheld and no RESOLVED restamp"
    else
      bad "LM: precondition=$lm_pre, expected one DECISION scaffold-ignore-lib-missing and a withheld stamp: $(grep 'scaffold-ignore\|restamp' "$o" | cut -f1,2 | tr '\n' ' ' | cut -c1-200)"
    fi
    # LN: the same sibling-less copy on a run that reaches NO scaffold arm stamps exactly as the lib-present
    # control does: both re-stamp, neither says lib-missing, and the two runs print the same row kinds.
    ow="$WORK/six-LN/with.out"; on="$WORK/six-LN/without.out"
    if [ "$ln_ok" = 1 ] && [ "$lm_pre" = 1 ] \
       && grep -q '^RESOLVED	restamp	' "$ow" && grep -q '^RESOLVED	restamp	' "$on" && ! six_withheld "$on" \
       && ! grep -q 'scaffold-ignore-lib-missing' "$ow" && ! grep -q 'scaffold-ignore-lib-missing' "$on" \
       && [ "$(cut -f1,2 "$ow" | LC_ALL=C sort)" = "$(cut -f1,2 "$on" | LC_ALL=C sort)" ]; then
      ok "LN: with no layer contract in THEIRS no scaffold arm runs, and the sibling-less copy re-stamps with no lib-missing row, the same row kinds as the lib-present control"
    else
      bad "LN: built=$ln_ok; with=[$(grep 'restamp\|scaffold-ignore' "$ow" | cut -f1,2 | tr '\n' ' ')] without=[$(grep 'restamp\|scaffold-ignore' "$on" | cut -f1,2 | tr '\n' ' ')]"
    fi

    # ST: a state word the library does not document ASKS -- every arm prints WORKLIST scaffold-ignore-unchecked
    o="$WORK/six-G1/st.out"
    if [ "$st_pre" = 1 ] && [ "$(six_unc "$o")" = "$SIX_EXP_ALL" ] && [ -z "$(six_ign "$o")" ] && [ -z "$(six_notes "$o")" ] \
       && [ "$(awk -F'\t' '$2=="scaffold-ignore-unchecked" && index($4, "answered the state '"'"'bogus'"'"'")' "$o" | grep -c .)" = 6 ] \
       && [ "$(six_res "$o" | cut -f2,3)" = "$SIX_KINDS" ]; then
      B_ST=1; ok "ST: a library answering the undocumented state 'bogus' makes all six arms print WORKLIST scaffold-ignore-unchecked naming it, never an acquittal"
    else
      bad "ST: precondition=$st_pre, unchecked=[$(six_unc "$o" | tr '\n' ' ')] ignored=[$(six_ign "$o" | tr '\n' ' ')]"
    fi

    # --- MUTANTS: each a copy of the whole reconcile directory with ONE line of ONE file replaced, run once
    # in the world where its arm decides. The anchor is the exact line, asserted to occur once; the copy
    # must differ, parse, and carry its siblings, or the mutant is a `bad` and never a kill.
    six_mut() { # six_mut <name> <file in the reconcile dir> <exact line> <replacement> [<source dir>]
      local d="$WORK/sixmut-$1" src="${5:-$(dirname "$APPLY")}"
      if [ "$(grep -cxF -- "$3" "$src/$2")" != 1 ]; then bad "MUTANT $1 did not apply (its anchor is not exactly one line of $2)"; return 1; fi
      cp -R "$src" "$d" 2>/dev/null
      A_LINE="$3" R_LINE="$4" awk '$0 == ENVIRON["A_LINE"] { print ENVIRON["R_LINE"]; next } { print }' "$src/$2" > "$d/$2"
      if cmp -s "$src/$2" "$d/$2" || ! bash -n "$d/$2" 2>/dev/null || [ ! -f "$d/preclassify.sh" ]; then
        bad "MUTANT $1 did not apply (the copy is unchanged, does not parse, or lost its siblings)"; return 1
      fi
    }
    six_cell() { # six_cell <mutant> <cell> <1|0 holds>
      [ "$MATRIX" = 1 ] || return 0
      printf 'MATRIX\t%s\t%s\t%s\n' "$1" "$2" "$([ "$3" = 1 ] && echo ok || echo FAIL)"; MATRIX_CELLS=$((MATRIX_CELLS + 1))
    }
    six_score() { # six_score <mutant> <dec 0|1> <twin 0|1> <flag> <kill text> <bad text>
      if [ "$2" = 0 ] && [ "$3" = 1 ]; then mutant_killed "$4" "$1" "MUTANT killed: $5"
      else bad "MUTANT $1: deciding cell failed=$([ "$2" = 0 ] && echo yes || echo no), twins held=$3 -- $6"; fi
    }
    # The six drop-the-call mutants. Each kind's world is the one whose rule hides its path; under the
    # mutant that kind's RESOLVED row must still print (the copy ran through the arm) and the world's
    # ignored set must lose exactly that path (the other kinds' rows are the twin).
    for kv in "crosswalk CW_REL" "machinery MC_REL" "pr-class PC_REL" "story-fields SF_REL" "artifact-paths AP_REL" "smoke-surface SS_REL"; do
      k="${kv%% *}"; var="${kv#* }"; eval "rel=\$$var"; m="drop-call-$k"
      case "$rel" in *.md) W=GX; e="$SIX_EXP_MD" ;; *) W=GY; e="$SIX_EXP_TXT" ;; esac
      if six_mut "$m" apply.sh "    scaffold_ignore_check \"\$$var\" scaffolded" "    :"; then
        six_run "$W" "$WORK/sixmut-$m/apply.sh" "$m"
        e_less="$(printf '%s\n' "$e" | grep -vxF -- "$rel")"
        got="$(six_ign "$WORK/six-$W/$m.out")"
        r_in=0; [ "$(six_res "$WORK/six-$W/$m.out" | cut -f2,3)" = "$SIX_KINDS" ] && r_in=1
        dec=1; grep -qxF -- "$rel" <<<"$got" || dec=0
        twin=0; [ "$got" = "$e_less" ] && [ "$r_in" = 1 ] && twin=1
        six_cell "$m" "$W.$k" "$dec"; six_cell "$m" "SIXI.$W" "$twin"
        six_score "$m" "$dec" "$twin" "$(( ${B_SIXI:-0} && ${B_SIXII:-0} && ${B_SIXIII:-0} ))" \
          "without the $k arm's check-ignore call its RESOLVED row prints and '$rel' gets no scaffold-ignored row in $W, the other rows unchanged" \
          "$W.$k (ignored=[$(printf '%s' "$got" | tr '\n' ' ')])"
      fi
    done

    # -q to -v: -v answers 0 on a negation match, so GN's six negated paths all read as ignored.
    m=ignore-verbose
    if six_mut "$m" scaffold-ignore.sh '  rc=0; git -C "$root" check-ignore -q -- "$rel" 2>/dev/null || rc=$?' '  rc=0; git -C "$root" check-ignore -v -- "$rel" >/dev/null 2>&1 || rc=$?'; then
      six_run GN "$WORK/sixmut-$m/apply.sh" "$m"
      dec=1; [ "$(six_ign "$WORK/six-GN/$m.out")" = "$SIX_EXP_ALL" ] && dec=0
      twin=0; [ "$(six_res "$WORK/six-GN/$m.out" | cut -f2,3)" = "$SIX_KINDS" ] && twin=1
      six_cell "$m" GN.ignored "$dec"; six_cell "$m" SIXI.GN "$twin"
      six_score "$m" "$dec" "$twin" "$(( ${B_SIXI:-0} && ${B_SIXII:-0} ))" \
        "deciding on check-ignore -v tells GN to force-add all six paths its negations already admit" "GN.ignored"
    fi

    # The rev-parse gate dropped: G0's 128 then reads as "could not check" on every arm.
    m=ignore-ungated
    if six_mut "$m" scaffold-ignore.sh '  if ! git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then' '  if false; then'; then
      six_run G0 "$WORK/sixmut-$m/apply.sh" "$m"
      dec=1; [ "$(six_unc "$WORK/six-G0/$m.out")" = "$SIX_EXP_ALL" ] && dec=0
      twin=0; [ "$(six_res "$WORK/six-G0/$m.out" | cut -f2,3)" = "$SIX_KINDS" ] && twin=1
      six_cell "$m" G0.unchecked "$dec"; six_cell "$m" SIXI.G0 "$twin"
      six_score "$m" "$dec" "$twin" "$(( ${B_SIXPRE:-0} && ${B_SIXI:-0} && ${B_SIXV:-0} ))" \
        "without the rev-parse gate a non-git consumer prints WORKLIST scaffold-ignore-unchecked on all six arms" "G0.unchecked"
    fi

    # The six drop-the-PRESERVED-call mutants, each run once as the second pull over its kind's world:
    # that path loses its WORKLIST, the other kinds' rows are the twin, and the stamp decision proves the
    # copy ran to its end (a dead copy prints none, so a short row set alone could not score).
    for kv in "crosswalk CW_REL" "machinery MC_REL" "pr-class PC_REL" "story-fields SF_REL" "artifact-paths AP_REL" "smoke-surface SS_REL"; do
      k="${kv%% *}"; var="${kv#* }"; eval "rel=\$$var"; m="drop-preserved-$k"
      case "$rel" in *.md) W=GX; e="$SIX_EXP_MD" ;; *) W=GY; e="$SIX_EXP_TXT" ;; esac
      if six_mut "$m" apply.sh "  scaffold_ignore_check \"\$$var\" preserved" "  :"; then
        six_run "$W" "$WORK/sixmut-$m/apply.sh" "$m" base
        o="$WORK/six-$W/$m.out"
        e_less="$(printf '%s\n' "$e" | grep -vxF -- "$rel")"
        got="$(six_ign "$o")"
        dec=1; grep -qxF -- "$rel" <<<"$got" || dec=0
        twin=0; [ "$got" = "$e_less" ] && [ -z "$(six_notes "$o")" ] && six_ended "$o" && twin=1
        six_cell "$m" "${W}2.$k" "$dec"; six_cell "$m" "${W}2.rows" "$twin"
        six_score "$m" "$dec" "$twin" "$(( ${B_GX2:-0} && ${B_GY2:-0} ))" \
          "without the $k arm's preserved call a present, ignored '$rel' gets no WORKLIST scaffold-ignored on the second pull in $W, the other rows unchanged" \
          "${W}2.$k (worklist=[$(printf '%s' "$got" | tr '\n' ' ')])"
      fi
    done

    # The preserved tier sent to NOTE: a consumer with a glob-hidden surface would then be told nothing that
    # holds the stamp, every pull. Killed by (vi)'s WORKLIST half, in GX's second pull.
    m=preserved-to-note
    if six_mut "$m" apply.sh '      say WORKLIST scaffold-ignored "$rel" "$(scaffold_ignore_remedy "$rel" "$prov")" ;;' \
         '      if [ "$tier" = preserved ]; then say NOTE scaffold-ignored "$rel" "$(scaffold_ignore_remedy "$rel" "$prov")"; else say WORKLIST scaffold-ignored "$rel" "$(scaffold_ignore_remedy "$rel" "$prov")"; fi ;;'; then
      six_run GX "$WORK/sixmut-$m/apply.sh" "$m" base
      o="$WORK/six-GX/$m.out"
      dec=1; [ "$(six_ign "$o")" = "$SIX_EXP_MD" ] || dec=0
      twin=0; [ "$(six_notes "$o" | cut -f2)" = "$SIX_EXP_MD" ] && six_ended "$o" && twin=1
      six_cell "$m" GX2.worklist "$dec"; six_cell "$m" GX2.notes "$twin"
      six_score "$m" "$dec" "$twin" "$B_GX2" \
        "a preserved, glob-ignored path demoted to NOTE leaves GX's second pull with no WORKLIST scaffold-ignored row" "GX2.worklist"
    fi

    # The unchecked tier sent to NOTE: GU's symlinked parent would then hand nothing back. Killed by GU.
    m=unchecked-to-note
    if six_mut "$m" apply.sh '      say WORKLIST scaffold-ignore-unchecked "$rel" \' '      say NOTE scaffold-ignore-unchecked "$rel" \'; then
      six_run GU "$WORK/sixmut-$m/apply.sh" "$m"
      o="$WORK/six-GU/$m.out"
      dec=1; [ "$(six_unc "$o")" = "$SS_REL" ] || dec=0
      twin=0; [ "$(six_notes "$o")" = "$(printf 'scaffold-ignore-unchecked\t%s' "$SS_REL")" ] && twin=1
      six_cell "$m" GU.worklist "$dec"; six_cell "$m" GU.notes "$twin"
      six_score "$m" "$dec" "$twin" "$B_GU" \
        "an unchecked path demoted to NOTE leaves GU with no WORKLIST scaffold-ignore-unchecked row" "GU.worklist"
    fi

    # The exact-path exit dropped: (b)'s deliberate disposition would print the row forever. Killed by (b).
    m=drop-exact-exit
    if six_mut "$m" scaffold-ignore.sh '  if [ -n "$prov" ] && { [ "$pat" = "$rel" ] || [ "$pat" = "/$rel" ]; }; then' '  if false; then'; then
      six_cell_run "$m" "$WORK/sixmut-$m/apply.sh" b
      o="$WORK/six-GY/$m.out"
      dec=1; [ "$(six_ign "$o")" = "$SS_REL" ] && dec=0
      twin=0; six_ended "$o" && twin=1
      six_cell "$m" NB.exact "$dec"; six_cell "$m" NB.ended "$twin"
      six_score "$m" "$dec" "$twin" "$B_NB" \
        "without the exact-path exit an exact '$SS_REL' line beside the glob still prints WORKLIST scaffold-ignored" "NB.exact"
    fi

    # The missing-sibling DECISION silenced: a pull without scaffold-ignore.sh would skip every check
    # unannounced. Built from LM's directory, so the sibling is absent as it is there. Killed by LM.
    m=lib-missing-silent
    if [ -f "$LMDIR/apply.sh" ] && six_mut "$m" apply.sh '      say DECISION scaffold-ignore-lib-missing "$SCAFFOLD_IGNORE_LIB" \' '      : \' "$LMDIR"; then
      six_run GX "$WORK/sixmut-$m/apply.sh" "$m"
      o="$WORK/six-GX/$m.out"
      dec=1; [ "$(awk -F'\t' '$2=="scaffold-ignore-lib-missing"' "$o" | grep -c .)" = 1 ] || dec=0
      twin=0; [ "$(six_res "$o" | cut -f2,3)" = "$SIX_KINDS" ] && six_ended "$o" && twin=1
      six_cell "$m" LM.decision "$dec"; six_cell "$m" LM.ended "$twin"
      six_score "$m" "$dec" "$twin" "$B_LM" \
        "with the missing-sibling DECISION silenced the run skips every check and says nothing" "LM.decision"
    elif [ ! -f "$LMDIR/apply.sh" ]; then
      bad "MUTANT $m did not apply (LM's reconcile copy is absent)"
    fi

    # The default arm dropped: an undocumented state would then be an acquittal. Built from ST's directory,
    # so its stub answers `bogus` as it does there. Killed by ST.
    m=drop-default-arm
    if [ -f "$STDIR/apply.sh" ] && six_mut "$m" apply.sh "    *) say WORKLIST scaffold-ignore-unchecked \"\$rel\" \"scaffold-ignore.sh answered the state '\${st}' for this \${tier} path, which is none it documents, so whether it is ignored was not decided. Run 'git check-ignore -v -- \${rel}'; if it names a rule, commit the file with 'git add -f \${rel}', or ignore it by its exact path.\" ;;" '    *) : ;;' "$STDIR"; then
      six_run G1 "$WORK/sixmut-$m/apply.sh" "$m"
      o="$WORK/six-G1/$m.out"
      dec=1; [ "$(six_unc "$o")" = "$SIX_EXP_ALL" ] || dec=0
      twin=0; [ "$(six_res "$o" | cut -f2,3)" = "$SIX_KINDS" ] && six_ended "$o" && twin=1
      six_cell "$m" ST.unchecked "$dec"; six_cell "$m" ST.resolved "$twin"
      six_score "$m" "$dec" "$twin" "$B_ST" \
        "without the default arm a library answering 'bogus' acquits all six paths with no row" "ST.unchecked"
    elif [ ! -f "$STDIR/apply.sh" ]; then
      bad "MUTANT $m did not apply (ST's reconcile copy is absent)"
    fi

    # --finish re-derives the scaffold rows through the library and withholds again. Killed by (F2).
    m=finish-rederives
    if six_mut "$m" apply.sh 'if [ "$FINISH" = 1 ]; then outstanding="$worklist_n"; else outstanding="$handback"; fi' \
         'if [ "$FINISH" = 1 ] && [ "$scaffold_ignore_loaded" = 1 ]; then for _r in $(sed -n "s/^consumer_[a-z_]*_file:[[:space:]]*//p" "$CONSUMER/.claude/skills/ai-dlc/layer-contract.yaml"); do case "$(scaffold_ignore_state "$CONSUMER" "$_r")" in ignored*) say WORKLIST scaffold-ignored "$_r" "re-derived on --finish" ;; esac; done; fi; if [ "$FINISH" = 1 ]; then outstanding="$worklist_n"; else outstanding="$handback"; fi'; then
      six_finish GX "$WORK/sixmut-$m/apply.sh" "$m" base
      o="$WORK/six-GX/$m.out"
      dec=1; grep -q '^RESOLVED	restamp	' "$o" && ! six_withheld "$o" || dec=0
      twin=0; [ "$(six_ign "$o")" = "$SIX_EXP_MD" ] && six_withheld "$o" && twin=1
      six_cell "$m" FIN.restamp "$dec"; six_cell "$m" FIN.rows "$twin"
      six_score "$m" "$dec" "$twin" "$B_FIN" \
        "a --finish that re-derives the scaffold rows withholds the stamp over GX's undisposed rows" "FIN.restamp"
    fi

    # THE SKIP'S DEDUCTION IS BOUND HERE. Only a consumer on the skip path subtracts SIX_ASSERTIONS, so a
    # wrong value would be seen nowhere else: every run that evaluates the block compares the number of
    # ok/bad lines it actually emitted against it. A match emits nothing, so the ledger is unchanged.
    six_n=$((made - six_made0))
    [ "$six_n" = "$SIX_ASSERTIONS" ] \
      || bad "SIX_ASSERTIONS is $SIX_ASSERTIONS but the BL-978 block emitted $six_n assertion(s): a consumer that SKIPs it would deduct the wrong count"
  fi
fi

# THE PLAIN-RUN ARM: keyed on the RAW argument vector, not on the parsed flag, so a guard broken open
# (MATRIX forced on) cannot hide itself. A plain run must have executed no matrix-only cell.
case "$RAW_ARGV" in
  *" --matrix "*)
    if [ "$MATRIX_CELLS" -gt 0 ]; then ok "matrix mode measured $MATRIX_CELLS cells"; else bad "matrix mode measured no cell"; fi ;;
  *)
    if [ "$MATRIX_CELLS" -eq 0 ]; then ok "a plain run executed no matrix-only cell"; else bad "a plain run executed $MATRIX_CELLS matrix-only cells — the matrix guard is open"; fi ;;
esac
[ "$MATRIX" = 1 ] && echo "MATRIX cells=$MATRIX_CELLS"

# ---------------------------------------------------------------------------
# A consumer whose apply.sh predates scaffold_ignore_check SKIPs the BL-978 block by name, and its
# assertions leave the expected count rather than reading as ran.
[ "${SIX_SKIP:-0}" = 1 ] && EXPECTED_ASSERTIONS=$((EXPECTED_ASSERTIONS - SIX_ASSERTIONS))
if [ "$made" -ne "$EXPECTED_ASSERTIONS" ]; then
  echo "  FAIL  assertion count: ran $made, expected $EXPECTED_ASSERTIONS — an arm did not execute, and one that never ran is silent, not green"
  fails=$((fails+1))
fi

echo
if [ "$fails" -eq 0 ]; then
  [ "${SIX_SKIP:-0}" = 1 ] && { echo "layer-crosswalk-home: PASS ($made assertions; the BL-978 subject is not installed on this consumer yet)"; exit 0; }
  echo "layer-crosswalk-home: PASS ($made assertions)"; exit 0
else
  echo "layer-crosswalk-home: FAIL ($fails of $made)"; exit 1
fi
