#!/usr/bin/env bash
# validator-path-resolution — assert every core validator behaves IDENTICALLY when it
# lives in scripts/ai-dlc/ and when it lives in scripts/.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# v0.126.0 moved the ~25 core validators from scripts/ to scripts/ai-dlc/ so the core
# boundary could enumerate them. Four of them derived the project root as
# `dirname($0)/..` — correct at scripts/X, and one level short at scripts/ai-dlc/X,
# where it resolves to <root>/scripts. Same tree, same script, same commit:
#
#   from scripts/         DORMANT: gate 'build' ...  Scanned 1 retros   rc=1
#   from scripts/ai-dlc/  Scanned 0 retros, 0 gates declared, 0 dormant  rc=0
#
# That is the check-that-cannot-fire class in its purest form: the relocated copy
# scanned an empty tree, found nothing wrong, and exited 0. Nothing on screen
# distinguished it from a clean repo.
#
# Not one of the 51 fixtures caught it, and the reason is structural: they all invoke
# validators from the DISTRIBUTION layout (core/scripts/X) with an explicit --root.
# Passing --root is exactly what makes self-location irrelevant, so the entire suite
# was blind to where a validator thinks it is. This fixture is the only one that runs
# them the way a consumer does — from their installed path, with no --root.
#
# WHY THE MUTANT IS AN ENV VAR AND NOT A SED.
#
# Asserting "the two locations agree" proves nothing about a script that never
# consults its own location — it would agree trivially, and pass forever. So every
# script is also run with AI_DLC_PROJECT_ROOT pointed at <root>/scripts, which is the
# precise wrong answer the old two-hop code computed. If that run is indistinguishable
# from the correct one, the script is not path-sensitive under this invocation and the
# agreement above is vacuous — the fixture says so, by name, and requires the four
# known-affected scripts to be sensitive.

set -uo pipefail

# The validators inherit every AI_DLC_* tunable a consumer set in settings.json, and
# this fixture's whole subject is which root they resolve. A leaked AI_DLC_PROJECT_ROOT
# or AI_DLC_CI_SURFACE would pin every run to the same answer and turn the comparison
# green against a script that is broken.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# CLAUDE_CODE_* too, and for the same reason one level over. These outrank the
# settings.json a validator reads OUT OF THE ROOT, so a set one makes the root
# irrelevant: validate-compact-window.sh printed byte-identical output from the
# right root and a nonexistent one while CLAUDE_CODE_AUTO_COMPACT_WINDOW was live,
# and scored inert. Anything that can make a root-dependent read root-independent
# belongs in this loop.
for _v in $(env | sed -n 's/^\(CLAUDE_CODE_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

# Where the core validators live, in each layout this fixture can run from. The first
# draft listed `core/scripts` and `.claude/scripts` — and `.claude/scripts` does not
# exist in ANY layout. An installed consumer keeps them at `scripts/ai-dlc/`, so this
# fixture shipped inert there: exit 2 FIXTURE ERROR, on the one tree whose layout it
# was written to defend. Nothing would have reported that, because a consumer's
# fixture directory is checked against a MANIFEST, not executed.
#
# Bare `scripts/` is deliberately NOT a candidate. Pre-relocation it holds the core
# validators, but it also holds ~78 consumer-authored scripts that carry no
# location-agnosticism obligation, and this fixture cannot tell them apart. A
# consumer that has not yet pulled the relocation has nothing here to test.
resolve_src() { # resolve_src <root> -> prints the core-validator dir, or fails
  local root="$1" cand
  for cand in "$root/core/scripts" "$root/scripts/ai-dlc"; do
    [ -d "$cand" ] && { printf '%s\n' "$cand"; return 0; }
  done
  return 1
}
SRC="$(resolve_src "$ROOT" || true)"
[ -n "$SRC" ] || {
  echo "FIXTURE ERROR: core validators not found under $ROOT" >&2
  echo "  looked in: $ROOT/core/scripts (distribution), $ROOT/scripts/ai-dlc (consumer)" >&2
  exit 2
}
for cand in "$ROOT/core/schemas" "$ROOT/.claude/schemas"; do
  [ -d "$cand" ] && SCHEMAS="$cand" && break
done
[ -n "${SCHEMAS:-}" ] || { echo "FIXTURE ERROR: schemas directory not found" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# --- a minimal installed consumer ----------------------------------------------
# .git is the walk-up marker. .claude/ carries the schemas and agent-read docs a
# consumer install lays down; docs/retro and .github/workflows give the gate
# validators something real to disagree about.
mkdir -p "$WORK/.git" \
         "$WORK/.claude/schemas" "$WORK/.claude/skills/ai-dlc" "$WORK/.claude/team-roles" \
         "$WORK/docs/retro" "$WORK/.github/workflows" \
         "$WORK/scripts/ai-dlc" || exit 2
cp "$SCHEMAS"/*.json "$WORK/.claude/schemas/" 2>/dev/null || {
  echo "FIXTURE ERROR: no schemas to copy from $SCHEMAS" >&2; exit 2; }

# A declared-but-dormant gate: docs/retro names it, no workflow references it. A
# validator that reads the right tree MUST report it; one reading <root>/scripts
# sees an empty world and says "0 dormant".
printf 'CI gate `build-and-test`\n' > "$WORK/docs/retro/sprint-1.md"
printf 'name: unrelated\non: push\n' > "$WORK/.github/workflows/unrelated.yml"

# Install every core validator into BOTH layouts: the pre-v0.126.0 consumer path and
# the current one. Derived from the directory, never hand-listed — a validator added
# later is covered the day it ships, which is the property a hand-list cannot have.
n_installed=0
for f in "$SRC"/*.sh; do
  [ -f "$f" ] || continue
  cp "$f" "$WORK/scripts/" && cp "$f" "$WORK/scripts/ai-dlc/" || exit 2
  n_installed=$((n_installed + 1))
done
[ "$n_installed" -ge 10 ] || {
  echo "FIXTURE ERROR: only $n_installed core scripts found in $SRC" >&2; exit 2; }

# --- invocation table ----------------------------------------------------------
# Default is a bare run. Overrides exist for two reasons only:
#   - sync-taught-schema.sh defaults to WRITE mode, and a writer's second run
#     legitimately differs from its first, so it is pinned to --check;
#   - several validators parse arguments BEFORE they resolve a schema, so a bare run
#     exits at the usage line and never reaches the code under test. That is not a
#     pass, it is a question never asked — the mutant check below names it as such.
mkdir -p "$WORK/docs/stories" || exit 2
printf '# artifact\n' > "$WORK/docs/artifact.md"
# A ```derived block whose command RESOLVES AGAINST THE ROOT. A subject with no such
# block makes validate-artifact-derivations.sh answer "0 derivation(s)" identically from
# any root, which scores INERT and takes its agreement assertion with it.
{ printf '```derived\n'
  printf '$ ls docs | wc -l\n'
  printf '%s\n' "$(ls "$WORK/docs" | wc -l)"
  printf '```\n'; } > "$WORK/docs/derived.md"
printf '# terminal pass\n' > "$WORK/docs/pass-p1.md"
printf '# story\n' > "$WORK/docs/stories/story-1.md"

# Root-dependent inputs for the four validators whose bare run stops at a usage
# line. Each is placed ONLY under the correct root, never under $WORK/scripts, so a
# script reading the wrong root finds nothing and the mutant separates. Without
# these the four reach no root-dependent code and score inert — "a question never
# asked", which the mutant arm below is no longer allowed to accept.
mkdir -p "$WORK/.claude/skills/ai-dlc/steps" || exit 2
printf '{"autoCompactWindow":"400k"}\n' > "$WORK/.claude/settings.json"
printf '# escalations\n\n**Terminal statuses**: `RESOLVED | OVERRIDDEN`\n' \
  > "$WORK/.claude/skills/ai-dlc/escalations.md"
printf '# stories-test-strategy\n\nfalsifiable acceptance criteria\n' \
  > "$WORK/.claude/skills/ai-dlc/steps/stories-test-strategy.md"
printf '# pending\n\n## [x] [lead] - 2026-01-01T00:00:00Z\n**Status:** RESOLVED\n' \
  > "$WORK/docs/pending.md"
for d in check-h1-recursion check-17-bypass check-manifest-bypass; do
  mkdir -p "$WORK/tests/fixtures/$d" || exit 2
  printf 'seed\n' > "$WORK/tests/fixtures/$d/README.md"
done

argv_for() {
  case "$1" in
    sync-taught-schema.sh)          printf '%s' "--check" ;;
    validate-audit-anchors.sh)      printf '%s' "--render" ;;
    validate-gate-adjudication.sh)  printf '%s' "--expected implementation" ;;
    validate-provenance-block.sh)   printf '%s' "$WORK/docs/artifact.md" ;;
    validate-artifact-derivations.sh) printf '%s' "$WORK/docs/derived.md" ;;
    stamp-story-provenance.sh)      printf '%s' "--terminal $WORK/docs/pass-p1.md --check $WORK/docs/stories/story-1.md" ;;
    validate-ac-falsifiability.sh)  printf '%s' "$WORK/docs/stories/story-1.md" ;;
    validate-escalation-status-vocabulary.sh) printf '%s' "$WORK/docs/pending.md" ;;
    validate-suppression-lifetime.sh) printf '%s' "--escalations $WORK/docs/pending.md" ;;
    validate-h2-attestation.sh)     printf '%s' "--digest" ;;
    # A bare run stops at "no mode given", which is byte-identical from every root and
    # scores the resolver INERT — the agreement assertion above then holds for a script
    # nobody asked a root-dependent question of. `--scan-roots` is the cheapest mode that
    # reads a file out of the resolved tree, so the answer names the root either way.
    artifact-path-config.sh)        printf '%s' "--scan-roots" ;;
    # A base ref is a REQUIRED positional for this one, so a bare run stops at its
    # usage line — byte-identical from any root, which scored it inert and took its
    # agreement assertion down with it. The ref need not resolve: with one present the
    # script reaches its project-root code and reports which root it landed on, which
    # is the only thing the mutant arm below is asking.
    #
    # AND THAT IS THE HONEST FLOOR FOR THIS ONE, STATED SO A GREEN ARM IS NOT OVER-READ.
    # $WORK carries a `.git` DIRECTORY, not a repository — `git rev-parse --git-dir`
    # returns 128 there. This script derives its entire scope from a diff, so it
    # declines at that point and never reaches its corpus code. The arm therefore
    # proves the root is CONSULTED (the two roots produce different errors, each
    # naming the root it resolved to); it does NOT prove the scope it would then
    # build is correct. Making $WORK a real repository would close that gap and was
    # deliberately not done: it changes the world all ~45 scripts here run against,
    # to strengthen one arm, and nobody has measured what it does to the other 71
    # assertions. The scope-correctness question is answered elsewhere — the script's
    # own rc=3 scoping-failure contract — not here.
    report-propagation-fanout.sh)   printf '%s' "HEAD~1" ;;
    *)                              printf '%s' "" ;;
  esac
}

# Which scripts MUST prove path-sensitive. DERIVED FROM THE SOURCE, not listed: a
# script owes path-sensitivity iff it consults a project root at all. If one stops
# being sensitive its agreement assertion has gone vacuous, and this fixture would
# otherwise keep reporting a pass it no longer earns.
#
# THIS WAS A HAND-LIST OF SEVEN AND THAT IS WHY IT MISSED. The list named the seven a
# hand investigation had found; five more scripts consulted a root through a bare
# `${CLAUDE_PROJECT_DIR:-.}` and were never required to be sensitive, so they sat in
# the printed `inert_list` — which this fixture reported and did not fail on — for
# their whole existence. Two of them answered rc=0 about the WRONG REPOSITORY. The
# fixture's own header already argued for this: "three of the seven were invisible to
# reading; that is the argument for deriving the subject list from the directory
# rather than from what an investigation happened to notice." The argument was made
# and then not applied to this line.
#
# Scripts that take the root as an ARGUMENT (`${1:-$(pwd)}`, `ROOT="$PWD"`) match none
# of the three tokens and are correctly out of scope — a different and legitimate
# contract. That exemption is stated so it is a decision rather than an accident.
SENSITIVE_REQUIRED="$(grep -lE 'AI_DLC_PROJECT_ROOT|CLAUDE_PROJECT_DIR|ai_dlc_resolve_root' "$SRC"/*.sh 2>/dev/null \
  | while IFS= read -r p; do basename "$p"; done | sort | tr '\n' ' ')"
[ -n "${SENSITIVE_REQUIRED// /}" ] || {
  echo "FIXTURE ERROR: derived an EMPTY required-sensitive set from $SRC — every" >&2
  echo "  mutant assertion below would pass vacuously. A zero here is not a finding." >&2
  exit 2
}

# Normalize the one difference that is legitimate: the script's own path, which several
# validators echo in their usage text. Longest prefix first.
norm() {
  sed -e "s@$WORK/scripts/ai-dlc@SCRIPTDIR@g" \
      -e "s@$WORK/scripts@SCRIPTDIR@g" \
      -e "s@$WORK@PROJECT@g"
}

run_one() { # run_one <layout-dir> <script-name> <wrong-root|""> -> "rc=<n>\n<output>"
  # THE POISON GOES INTO EVERY ROOT CHANNEL, NOT ONE. Setting only
  # AI_DLC_PROJECT_ROOT probed a variable that five scripts never read: they fell
  # through to `${CLAUDE_PROJECT_DIR:-.}` = cwd = $WORK, the correct root under both
  # layouts, agreed trivially, and scored inert. A mutant that leaves a channel open
  # tests the channel it closed, not the script.
  local dir="$1" name="$2" out rc
  out="$(cd "$WORK" && AI_DLC_PROJECT_ROOT="${3:-}" CLAUDE_PROJECT_DIR="${3:-}" \
         bash "$WORK/$dir/$name" $(argv_for "$name") 2>&1)"
  rc=$?
  printf '%s\n' "rc=$rc"
  printf '%s\n' "$out" | norm
}

echo "validator-path-resolution"
echo "  subject dir: ${SRC#"$ROOT/"} (of $ROOT)"
echo "  installed $n_installed core script(s) into scripts/ and scripts/ai-dlc/"
echo ""

# --- the resolver's own control ------------------------------------------------
# resolve_src decides whether this fixture runs at all, and its failure mode is a
# silent no-op: a fixture that exits 2 in a consumer tree is indistinguishable from
# one that was never installed. So it is exercised against synthetic roots of each
# shape, including the negative. The v0.126.4 draft would fail the consumer case.
LAY="$WORK/.layouts"
mkdir -p "$LAY/dist/core/scripts" "$LAY/cons/scripts/ai-dlc" "$LAY/cons/scripts" \
         "$LAY/legacy/scripts" "$LAY/none" || exit 2
got="$(resolve_src "$LAY/dist" || echo "")"
[ "$got" = "$LAY/dist/core/scripts" ] && ok "resolve_src finds the distribution layout (core/scripts)" \
                                      || bad "resolve_src missed the distribution layout — got '${got:-<none>}'"
got="$(resolve_src "$LAY/cons" || echo "")"
[ "$got" = "$LAY/cons/scripts/ai-dlc" ] && ok "resolve_src finds the consumer layout (scripts/ai-dlc) — the case v0.126.4 shipped broken" \
                                        || bad "resolve_src missed the consumer layout — got '${got:-<none>}'"
# A consumer that has not pulled the relocation must NOT resolve: scripts/ there is
# 100+ files this fixture has no standing to hold to a location contract.
got="$(resolve_src "$LAY/legacy" || echo "")"
[ -z "$got" ] && ok "resolve_src declines a pre-relocation consumer (bare scripts/ is not a candidate)" \
              || bad "resolve_src accepted bare scripts/ — it would test consumer-authored scripts"
got="$(resolve_src "$LAY/none" || echo "")"
[ -z "$got" ] && ok "resolve_src fails closed on a tree with neither layout" \
              || bad "resolve_src invented a subject dir — got '$got'"
echo ""

sensitive_list=""
inert_list=""

for f in "$SRC"/*.sh; do
  name="$(basename "$f")"

  legacy="$(run_one "scripts"        "$name")"
  current="$(run_one "scripts/ai-dlc" "$name")"

  # THE ASSERTION. Same tree, same argv, same cwd — only the install path differs.
  if [ "$legacy" = "$current" ]; then
    ok "$name agrees from scripts/ and scripts/ai-dlc/"
  else
    bad "$name DIVERGES between layouts"
    printf '        scripts/       : %s\n' "$(printf '%s' "$legacy"  | tr '\n' '|' | cut -c1-160)"
    printf '        scripts/ai-dlc/: %s\n' "$(printf '%s' "$current" | tr '\n' '|' | cut -c1-160)"
  fi

  # THE MUTANT. <root>/scripts is exactly what `dirname($0)/..` computed from the new
  # location. A script that answers the same either way did not consult the root.
  mutant="$(run_one "scripts/ai-dlc" "$name" "$WORK/scripts")"
  if [ "$mutant" != "$current" ]; then
    sensitive_list="$sensitive_list $name"
  else
    inert_list="$inert_list $name"
  fi
done

echo ""
# --- non-vacuity ---------------------------------------------------------------
for want in $SENSITIVE_REQUIRED; do
  case " $sensitive_list " in
    *" $want "*) ok "MUTANT: $want changes behaviour when the root is wrong (its agreement is real)" ;;
    *) bad "MUTANT: $want ignored a wrong project root — its agreement assertion proves nothing" ;;
  esac
done

# --- WRONG REPO: CLAUDE_PROJECT_DIR must not outrank the script's own location ---
# The mutant arm above proves a script CONSULTS a root. This proves it consults the
# RIGHT one. They are different questions and only this one catches the shipped
# defect: five validators assigned `${CLAUDE_PROJECT_DIR:-.}` directly, so a stale
# value inherited from another repo won over their own install path. Measured in a
# real pair of trees, two of them then answered rc=0 about a repository they were
# not run against — a pass reachable by two structurally different roads.
#
# CLAUDE_PROJECT_DIR is deliberately the ONLY channel poisoned here.
# AI_DLC_PROJECT_ROOT is an operator override and outranking the walk is its job;
# poisoning it too would assert the opposite of the contract.
WORK2="$WORK/.otherrepo"
mkdir -p "$WORK2/.git" "$WORK2/.claude/skills/ai-dlc/steps" "$WORK2/docs/retro" \
         "$WORK2/tests/fixtures" "$WORK2/.github/workflows" || exit 2
# Populated differently ON PURPOSE: if both roots looked alike, a script that read
# the wrong one would agree and the assertion would pass without looking.
printf 'CI gate `other-gate-never-declared-here`\n' > "$WORK2/docs/retro/sprint-99.md"
printf '{"autoCompactWindow":"1m"}\n' > "$WORK2/.claude/settings.json"

wrong_repo_checked=0
wrong_repo_bad=0
for name in $SENSITIVE_REQUIRED; do
  [ -f "$WORK/scripts/ai-dlc/$name" ] || continue
  clean="$(run_one "scripts/ai-dlc" "$name")"
  poisoned="$(cd "$WORK" && CLAUDE_PROJECT_DIR="$WORK2" \
              bash "$WORK/scripts/ai-dlc/$name" $(argv_for "$name") 2>&1 | norm; )"
  poisoned="rc=?
$poisoned"
  # Compare OUTPUT only: rc is captured differently above, and the output is what
  # names the tree. A script that read $WORK2 mentions it or reports its contents.
  if [ "$(printf '%s\n' "$clean" | tail -n +2)" = "$(printf '%s\n' "$poisoned" | tail -n +2)" ]; then
    wrong_repo_checked=$((wrong_repo_checked+1))
  else
    bad "WRONG REPO: $name changed its answer when CLAUDE_PROJECT_DIR pointed at another tree — it outranked the script's own install path"
    wrong_repo_bad=$((wrong_repo_bad+1))
  fi
done
[ "$wrong_repo_checked" -gt 0 ] \
  && ok "WRONG REPO: $wrong_repo_checked script(s) ignored a CLAUDE_PROJECT_DIR pointing at a different consumer" \
  || bad "WRONG REPO: the probe checked ZERO scripts — a zero here is not a finding"

# Non-vacuity control for the loop above. The probe must still be able to SEE a
# script that reads CLAUDE_PROJECT_DIR: a copy with the walk removed has to be
# caught, or the run of oks above is the probe failing to look.
PROBE="$WORK/scripts/ai-dlc/.wrongrepo-probe.sh"
printf '#!/usr/bin/env bash\nR="${CLAUDE_PROJECT_DIR:-$(pwd)}"\necho "root: $R"\n' > "$PROBE"
p_clean="$(cd "$WORK" && bash "$PROBE" 2>&1 | norm)"
p_pois="$(cd "$WORK" && CLAUDE_PROJECT_DIR="$WORK2" bash "$PROBE" 2>&1 | norm)"
[ "$p_clean" != "$p_pois" ] \
  && ok "CONTROL: the probe still detects a script that DOES let CLAUDE_PROJECT_DIR win" \
  || bad "CONTROL: the probe could not detect a deliberately-broken script — every WRONG REPO ok above is silence"
rm -f "$PROBE"

# --- DECOY CWD: the two scripts that resolve a CORE FILE, not a project artifact ---
#
# The two arms above ask which ROOT a script resolves. These ask what it then OPENS,
# and they are a different question with a different failure: a script that resolves no
# root at all and names its candidates relative to the cwd never touches a root channel,
# so the mutant arm scores it inert and the WRONG REPO arm has nothing to poison. Both
# of these read a CORE file — gate-validation.md, and the artifact-path grammar plus the
# layer contract — and both used to name it relative to wherever the process was
# standing. Every cwd but one is then a refusal, and the one that is not is another
# ai-dlc tree: it reads that tree's file, reports about it by name, and exits 0.
#
# THE DECOY IS PLACED IN $WORK2, WHICH IS A TREE. That is deliberate and it is what
# makes the arm honest: the canonical chain's last step is a walk up from the cwd, so a
# cwd carrying a decoy at a candidate path is a legitimately resolvable root and the
# only thing separating right from wrong is that the script's OWN LOCATION outranks it.
# Seeding the decoy somewhere unresolvable would test nothing, because the decoy's own
# parent directory (`.claude/`, `core/skills/ai-dlc/`) is itself a root marker.
#
# EACH ARM CARRIES ITS POSITIVE CONTROL IN THE SAME RUN. "Did not name the decoy" is
# satisfied by a script that died, by a decoy that was never written, and by a $WORK2
# this fixture spelled wrong; the control drives the same copy at the same decoy through
# the argument or the flag that IS supposed to reach it, and requires the decoy back.
printf '# decoy — the gate-validation.md of ANOTHER tree\n' \
  > "$WORK2/.claude/skills/ai-dlc/steps/gate-validation.md"
printf 'consumer_artifact_paths_file: DECOY-PATHS-FILE\n' \
  > "$WORK2/.claude/skills/ai-dlc/layer-contract.yaml"
{ printf '```scan-roots\n'; printf 'DECOY-SCAN-ROOT\n'; printf '```\n'
  printf 'areas:\n'; printf '  DECOY-AREA\n'; } \
  > "$WORK2/.claude/skills/ai-dlc/artifact-path-grammar.md"

DEC_GV="$WORK2/.claude/skills/ai-dlc/steps/gate-validation.md"
MUTD="$WORK/.decoy-mut"
mkdir -p "$MUTD" || exit 2

# mut_copy <script> <sed program> <token whose count must drop to 0> -> path, or ""
# The mutation is keyed on the subject's OWN predicate — the text that consumes the
# resolved root — and scored by that text's count going from non-zero to zero, so a
# hand-named site list cannot go vacuous the release somebody adds a site.
mut_copy() {
  local src="$1" prog="$2" tok="$3" dst="$MUTD/$(basename "$1")" before after
  before="$(grep -cF "$tok" "$src")" || before=0
  [ "$before" -gt 0 ] || { printf ''; return 1; }
  sed -e "$prog" "$src" > "$dst" 2>/dev/null || { printf ''; return 1; }
  cmp -s "$src" "$dst" && { printf ''; return 1; }
  after="$(grep -cF "$tok" "$dst")" || after=0
  [ "$after" -eq 0 ] || { printf ''; return 1; }
  printf '%s\n' "$dst"
}

GM_S="$WORK/scripts/ai-dlc/validate-gate-manifest.sh"
if [ ! -f "$GM_S" ]; then
  bad "DECOY CWD: validate-gate-manifest.sh is not among the installed scripts — the arm did not run"
else
  # KEYED ON THE CANDIDATE PATH, NOT ON THE DECOY'S ABSOLUTE ONE, and that is a
  # measurement: a cwd-relative reader names the file `.claude/skills/…` with no
  # prefix at all, so an arm looking for "$WORK2/.claude/…" scored the mutant SURVIVED
  # while the mutant was reading the decoy and saying so. The suffix appears in both
  # spellings; the root assertion beside it is what makes the silent-refusal case fail
  # rather than pass, since a script that died also fails to name the decoy.
  gm_dec="$( cd "$WORK2" && bash "$GM_S" 2>&1 )"
  case "$gm_dec" in
    *".claude/skills/ai-dlc/steps/gate-validation.md"*)
      bad "DECOY CWD: validate-gate-manifest.sh with no argument read ANOTHER tree's gate-validation.md — it resolved its candidates against the cwd, not the root" ;;
    *"under $WORK"*)
      ok  "DECOY CWD: validate-gate-manifest.sh with no argument ignores another tree's gate-validation.md at the cwd, and names the root it did search" ;;
    *)
      bad "DECOY CWD: validate-gate-manifest.sh named neither the decoy nor its own root — it cannot be told from a run that died" ;;
  esac
  gm_ctl="$( cd "$WORK2" && bash "$GM_S" "$DEC_GV" 2>&1 )"
  case "$gm_ctl" in
    *".claude/skills/ai-dlc/steps/gate-validation.md"*)
      ok  "CONTROL: an explicit \$1 still reaches that same decoy, so the arm above is a discrimination and not a dead run" ;;
    *)
      bad "CONTROL: an explicit \$1 did not reach the decoy — the decoy is unreadable or the \$1 contract broke, and the arm above proves nothing" ;;
  esac
  gm_mut="$(mut_copy "$GM_S" 's@"\$AI_DLC_ROOT/@"@g' '"$AI_DLC_ROOT/')"
  if [ -z "$gm_mut" ]; then
    bad "MUTANT: the root prefix on validate-gate-manifest.sh's candidates could not be removed — the anchor moved and the DECOY CWD arm above is unproven"
  else
    gm_mout="$( cd "$WORK2" && bash "$gm_mut" 2>&1 )"
    case "$gm_mout" in
      *".claude/skills/ai-dlc/steps/gate-validation.md"*)
        ok  "MUTANT: candidates back to cwd-relative -> validate-gate-manifest.sh reads the decoy; the arm kills it" ;;
      *)
        bad "MUTANT: candidates back to cwd-relative and validate-gate-manifest.sh STILL did not read the decoy — the arm cannot fire" ;;
    esac
  fi
fi

APC_S="$WORK/scripts/ai-dlc/artifact-path-config.sh"
if [ ! -f "$APC_S" ]; then
  bad "DECOY CWD: artifact-path-config.sh is not among the installed scripts — the arm did not run"
else
  apc_dec="$( cd "$WORK2" && bash "$APC_S" --scan-roots 2>&1 )"
  case "$apc_dec" in
    *DECOY-SCAN-ROOT*) bad "DECOY CWD: artifact-path-config.sh --scan-roots read ANOTHER tree's artifact-path-grammar.md — its root defaulted to the cwd" ;;
    *)                 ok  "DECOY CWD: artifact-path-config.sh --scan-roots ignores another tree's grammar at the cwd" ;;
  esac
  apc_cf="$( cd "$WORK2" && bash "$APC_S" --consumer-file 2>&1 )"
  case "$apc_cf" in
    *DECOY-PATHS-FILE*) bad "DECOY CWD: artifact-path-config.sh --consumer-file read ANOTHER tree's layer-contract.yaml" ;;
    *)                  ok  "DECOY CWD: artifact-path-config.sh --consumer-file ignores another tree's layer contract at the cwd" ;;
  esac
  apc_ctl="$( cd "$WORK2" && bash "$APC_S" --scan-roots --root "$WORK2" 2>&1 )"
  case "$apc_ctl" in
    *DECOY-SCAN-ROOT*) ok  "CONTROL: --root still reaches that same decoy grammar, so the two arms above are discriminations and the documented flag survived the fix" ;;
    *)                 bad "CONTROL: --root did not reach the decoy grammar — either the flag stopped winning or the decoy is unreadable, and both arms above prove nothing" ;;
  esac
  apc_mut="$(mut_copy "$APC_S" 's@^  ROOT="\$AI_DLC_ROOT"$@  ROOT="."@' '  ROOT="$AI_DLC_ROOT"')"
  if [ -z "$apc_mut" ]; then
    bad "MUTANT: artifact-path-config.sh's resolved-root assignment could not be reverted to the cwd — the anchor moved and the two DECOY CWD arms above are unproven"
  else
    apc_mout="$( cd "$WORK2" && bash "$apc_mut" --scan-roots 2>&1 )"
    case "$apc_mout" in
      *DECOY-SCAN-ROOT*) ok  "MUTANT: default root back to \".\" -> artifact-path-config.sh reads the decoy grammar; the arm kills it" ;;
      *)                 bad "MUTANT: default root back to \".\" and artifact-path-config.sh STILL did not read the decoy — the arm cannot fire" ;;
    esac
  fi
fi
rm -rf "$MUTD"

echo ""
n_sensitive=$(printf '%s' "$sensitive_list" | wc -w | tr -d ' ')
n_inert=$(printf '%s' "$inert_list" | wc -w | tr -d ' ')
echo ""
echo "  path-sensitive under this invocation: $n_sensitive"
echo "  not path-sensitive (agreement is trivially true for these): $n_inert"
echo "   ${inert_list# }"

echo ""
if [ "$fails" -eq 0 ]; then
  echo "validator-path-resolution: PASS"
  exit 0
fi
echo "validator-path-resolution: FAIL ($fails assertion(s))"
exit 1
