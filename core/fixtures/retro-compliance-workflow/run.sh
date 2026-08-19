#!/usr/bin/env bash
# retro-compliance-workflow — drive the shipped retro-compliance CI workflow's own shell
# against seeded trees and assert what it DOES, not what it says.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# core/ci-templates/validate-retro-compliance.yml is copied by install.sh into a consumer's
# .github/workflows/. It carries five sites keyed on the PRE-MIGRATION retro path shape
# `docs/retro/sprint-<n>.md`, after migrate-artifact-paths.sh moved every retro to
# `docs/retro/s<n>/retro.md`:
#
#   1. the header comment                    (not armed here — see below)
#   2. the `on.pull_request.paths` trigger    -> A1
#   3. the `git diff -- 'docs/retro/sprint-*.md'` changed-set filter  -> A2
#   4. the `basename "$f" .md | sed 's/^sprint-//'` sprint EXTRACTION -> A2
#   5. the `docs/retro/sprint-${sprint}.md` invocation argument       -> A3/A4/A6
#
# Site 4 was not filed with the others and is the one that makes the workflow read GREEN.
# Under the migrated shape the sprint number lives in a DIRECTORY component, so `basename`
# yields `retro`, the `^[0-9]+$` test fails, `sprint` stays empty, and every later step is
# skipped by its own `if: steps.sprint.outputs.sprint != ''`. A workflow that triggers,
# filters, and then silently skips everything is indistinguishable from a workflow that ran
# and found nothing wrong. That is why site 4 must be DRIVEN and cannot be grepped: its
# failure mode is a silently empty variable, and no string is present or absent for a grep
# to key on.
#
# WHY THE ARGUMENT PATH MATTERS AT ALL. validate-provenance-block.sh classifies a document
# as a retro with RETRO_PATH_RE = docs/retro/s\d+/retro\.md$. At the legacy path is_retro is
# false and THREE requirements are silently exempted: the party-mode block floor, the
# transcript_path requirement, and the no-block rejection. Measured, same bytes, both paths:
#
#                                        legacy  legacy+flag  migrated  migrated+flag
#   blockless retro doc                    0         1           1           1
#   party-mode block, transcript stripped  0         0           1           1
#
# SITE 1 IS DELIBERATELY NOT ARMED. It is a comment. An arm on it would be a text arm on a
# text site, satisfied by a rename and satisfying nothing; and `mechanism-design.md` calls a
# guard whose removal changes no outcome a loaded gun. If the header is stale after the fix
# that is a review finding, not a gate finding, and this file says so rather than pretending.
#
# WHAT THE FOUR REMEDY STATES DO TO THE ARMS (this is the fixture's whole claim):
#
#   (a) unfixed                A1 A2 A3 A4 A5 all FAIL
#   (b) flag added only        A1 A2 A4 FAIL   (A3 passes: the flag reaches the no-block
#                                               rung at the legacy path, and only that one)
#   (c) all five paths, no flag           A5 FAILS
#   (d) paths + flag           all pass
#
# A5 IS THE ONLY ARM THAT SEPARATES (c) FROM (d), AND IT NEEDS A MUTANT TO DO IT. On the real
# validator every rung the flag reaches is ALSO reached by is_retro once the argument path is
# migrated, so no seeded document can tell a path-only fix from the full fix. The flag's whole
# value is that the CALLER declares its own requirement instead of depending on a regex in
# another file — so the arm that tests it must remove that regex. A5 disarms is_retro in a
# COPY of the validator and requires the workflow to still reject a blockless retro.
# Without A5 this fixture would certify a path-only fix as complete.
#
# TWO SEEDED REPOS, AND THEY MUST STAY TWO.
#   repo_extract  holds the retro at the MIGRATED path ONLY. If it also held the legacy copy,
#                 the legacy `git diff` pathspec would match it, the legacy `basename` would
#                 extract 302 from it, and A2 would go green against the unfixed template.
#   repo_invoke   holds byte-IDENTICAL copies at BOTH paths. Holding the content constant and
#                 varying only the path is what makes the argument site observable; a tree with
#                 only one of them would answer "file not found" (rc 2) rather than answering
#                 the question, and rc 2 is not a kill.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# --- tree root: WALK UP for a marker, never count `..` hops -------------------
# A hop count answers differently from the repo root, from this directory, and from a
# sandbox that copied the tree — and the sandbox answer is the silent one.
#
# THE MARKER IS NOT `VERSION`, AND THAT COST A FULL CONSUMER RUN TO FIND. `VERSION` is a
# DISTRIBUTION file: install.sh does not copy it, so a consumer tree has none at any depth
# (measured: `find <consumer> -name VERSION -maxdepth 3` returns nothing). A VERSION walk
# resolves this repo perfectly and dies with "cannot resolve its own tree" on every consumer
# — the exact shape the consumer boundary exists to catch, invisible to a green push here.
#
# The marker is the fixture's OWN home, which names the layout it is running in:
# `<root>/core/fixtures/<name>` here, `<root>/tests/fixtures/<name>` on a consumer. It is
# self-anchoring, it cannot stop early on an unrelated ancestor, and if neither is found
# the fixture refuses loudly rather than guessing.
FNAME="$(basename "$HERE")"
LAYOUT=""
find_root() {
    local d
    d="$(dirname "$HERE")"
    while [ "$d" != "/" ] && [ -n "$d" ]; do
        if [ "$d/core/fixtures/$FNAME" = "$HERE" ]; then echo "dist $d"; return 0; fi
        if [ "$d/tests/fixtures/$FNAME" = "$HERE" ]; then echo "consumer $d"; return 0; fi
        d="$(dirname "$d")"
    done
    return 1
}
_fr="$(find_root || true)"
LAYOUT="${_fr%% *}"
ROOT="${_fr#* }"
[ -n "$_fr" ] || { LAYOUT=""; ROOT=""; }

# Arm Z re-execs this script for a root reading. Handled first so nothing below can recurse.
if [ "${1:-}" = "--print-root" ]; then echo "${ROOT:-NONE}"; exit 0; fi

fails=0
ok()   { printf '  ok    %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1" >&2; fails=$((fails+1)); }
skip() { printf '  SKIP  %s\n' "$1"; }
echo "retro-compliance-workflow:"

if [ -z "$ROOT" ]; then
    echo "  FAIL  $HERE sits under neither core/fixtures/ nor tests/fixtures/ — the fixture cannot resolve its own tree, and guessing a root is how a fixture reports green over a tree it never read" >&2
    exit 2
fi

# --- subjects, in BOTH install layouts ----------------------------------------
# install.sh maps core/ci-templates/<x> -> .github/workflows/<x> and
# core/scripts/<x> -> scripts/ai-dlc/<x>, core/schemas/ -> .claude/schemas/.
WF=""
for cand in "$ROOT/core/ci-templates/validate-retro-compliance.yml" \
            "$ROOT/.github/workflows/validate-retro-compliance.yml"; do
    [ -f "$cand" ] && { WF="$cand"; break; }
done
VP=""
for cand in "$ROOT/core/scripts/validate-provenance-block.sh" \
            "$ROOT/scripts/ai-dlc/validate-provenance-block.sh"; do
    [ -f "$cand" ] && { VP="$cand"; break; }
done
SCHEMA=""
for cand in "$ROOT/core/schemas/provenance-block.json" \
            "$ROOT/.claude/schemas/provenance-block.json"; do
    [ -f "$cand" ] && { SCHEMA="$cand"; break; }
done

# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. install.sh copies the workflow only when the
# consumer already has .github/workflows/, so a consumer may legitimately not have it. Report
# every arm by NAME as SKIP — a silent exit 0 here would read exactly like a clean run.
if [ -z "$WF" ] || [ -z "$VP" ] || [ -z "$SCHEMA" ]; then
    miss=""
    [ -z "$WF" ]     && miss="$miss validate-retro-compliance.yml"
    [ -z "$VP" ]     && miss="$miss validate-provenance-block.sh"
    [ -z "$SCHEMA" ] && miss="$miss provenance-block.json"
    for a in "A1 trigger paths" "A2 changed-set filter + sprint extraction" \
             "A3 blockless retro rejected" "A4 transcript_path required" \
             "A5 caller declares its own requirement" "A6 compliant retro accepted"; do
        skip "$a — subject absent in both layouts:$miss"
    done
    exit 0
fi

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

SEED="$WORK/seed"
mkdir -p "$SEED"
if ! bash "$HERE/seed.sh" "$SEED" >/dev/null 2>"$WORK/seed.err"; then
    for a in "A1" "A2" "A3" "A4" "A5" "A6"; do
        skip "$a — seed unavailable: $(tr -d '\n' < "$WORK/seed.err")"
    done
    exit 0
fi

PY="$HERE/extract.py"

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

# subst <file> <needle> <replacement> — literal, in place, and LOUD when it matched
# nothing. A substitution that silently no-ops leaves `${{ ... }}` in the body, bash
# expands it to nothing, and the step runs against an empty argument.
subst() {
    python3 - "$1" "$2" "$3" <<'PY'
import sys
p, a, b = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p, encoding="utf-8").read()
if a not in s:
    print("MISSING", end="")
    sys.exit(0)
open(p, "w", encoding="utf-8").write(s.replace(a, b))
print("OK", end="")
PY
}

# build_repo <dir> <doc-source> <both|migrated-only> [validator-override]
# Emits "<base_sha> <head_sha>" on stdout.
build_repo() {
    local dir="$1" doc="$2" layout="$3" vsrc="${4:-$VP}"
    mkdir -p "$dir/scripts/ai-dlc" "$dir/.claude/schemas" "$dir/docs/retro"
    cp "$vsrc" "$dir/scripts/ai-dlc/validate-provenance-block.sh"
    chmod +x "$dir/scripts/ai-dlc/validate-provenance-block.sh"
    cp "$SCHEMA" "$dir/.claude/schemas/provenance-block.json"
    (
        cd "$dir" || exit 1
        git init -q .
        git config user.email fixture@example.invalid
        git config user.name  fixture
        git config commit.gpgsign false
        printf 'seed\n' > README.md
        git add -A && git commit -qm base
        git rev-parse HEAD > .base
    ) >/dev/null 2>&1 || return 1
    if [ "$layout" = both ]; then
        cp "$doc" "$dir/docs/retro/sprint-302.md"
    fi
    mkdir -p "$dir/docs/retro/s302"
    cp "$doc" "$dir/docs/retro/s302/retro.md"
    (
        cd "$dir" || exit 1
        git add -A && git commit -qm head
        git rev-parse HEAD > .head
    ) >/dev/null 2>&1 || return 1
    echo "$(cat "$dir/.base") $(cat "$dir/.head")"
}

# drive_sprint <workflow> <repo> — runs the "Determine sprint number" step body against the
# repo and prints the value the step wrote to GITHUB_OUTPUT (empty if it wrote none).
drive_sprint() {
    local wf="$1" repo="$2" body="$WORK/body.sprint.$$" shas base head
    python3 "$PY" "$wf" run "Determine sprint number" > "$body" 2>"$WORK/x.err" || { echo "__NOSTEP__"; return; }
    shas="$(cat "$repo/.base") $(cat "$repo/.head")"
    base="${shas%% *}"; head="${shas##* }"
    subst "$body" '${{ github.event.pull_request.base.sha }}' "$base" >/dev/null
    subst "$body" '${{ github.event.pull_request.head.sha }}' "$head" >/dev/null
    : > "$WORK/gh_out"
    ( cd "$repo" && GITHUB_OUTPUT="$WORK/gh_out" bash "$body" ) >/dev/null 2>&1
    sed -n 's/^sprint=//p' "$WORK/gh_out" | tail -n 1
}

# drive_provenance <workflow> <repo> <sprint> — runs the provenance step body with the
# sprint injected and prints its exit code.
drive_provenance() {
    local wf="$1" repo="$2" sprint="$3" body="$WORK/body.prov.$$" rc
    python3 "$PY" "$wf" run "validate-provenance-block" > "$body" 2>"$WORK/x.err" || { echo 99; return; }
    if [ "$(subst "$body" '${{ steps.sprint.outputs.sprint }}' "$sprint")" != OK ]; then
        echo 98; return
    fi
    ( cd "$repo" && bash "$body" ) >"$WORK/prov.out" 2>&1
    rc=$?
    echo "$rc"
}

# ---------------------------------------------------------------------------
# THE ARMS, as one function so the self-probe exercises the SAME code as the corpus.
# Prints one token per arm: "<id>:pass" or "<id>:fail:<detail>".
# ---------------------------------------------------------------------------
arms() {
    local wf="$1" tag="$2" VPUSE="${3:-$VP}" r

    # --- A1 trigger paths -----------------------------------------------------
    local plist hit p
    if ! plist="$(python3 "$PY" "$wf" paths 2>/dev/null)"; then
        echo "A1:fail:on.pull_request.paths absent or unreadable"
    else
        hit=0
        while IFS= read -r p; do
            [ -z "$p" ] && continue
            [ "$(python3 "$PY" "$wf" match "$p" "docs/retro/s302/retro.md")" = 1 ] && hit=1
        done <<< "$plist"
        if [ "$hit" = 1 ]; then echo "A1:pass"
        else echo "A1:fail:no paths: pattern matches docs/retro/s302/retro.md — the PR never triggers the workflow"; fi
    fi

    # --- A2 changed-set filter + sprint extraction -----------------------------
    # repo_extract holds the retro at the MIGRATED path ONLY.
    local re="$WORK/${tag}.extract" s
    rm -rf "$re"
    if ! build_repo "$re" "$SEED/docs/blockless.md" migrated-only "$VPUSE" >/dev/null; then
        echo "A2:fail:could not build the extraction repo (fixture broken, not a finding)"
    else
        s="$(drive_sprint "$wf" "$re")"
        if [ "$s" = "302" ]; then echo "A2:pass"
        elif [ "$s" = "__NOSTEP__" ]; then echo "A2:fail:no 'Determine sprint number' step with a run: body"
        elif [ -z "$s" ]; then echo "A2:fail:sprint resolved EMPTY — every later step is skipped by its own if:, and the workflow reports green having validated nothing"
        else echo "A2:fail:sprint resolved to '$s', expected 302"; fi
    fi

    # --- A3/A4/A6 the invocation argument -------------------------------------
    # repo_invoke holds byte-identical copies at BOTH paths, so the ONLY variable is which
    # one the step names. sprint is injected as 302 rather than taken from A2: entangling
    # them would make one mutant fail two arms and hide which is vacuous.
    local ri
    local doc rest id want
    for v in blockless:A3:1 notranscript:A4:1 compliant:A6:0; do
        # SEPARATE assignments, deliberately. `local a=$x b=${a%%:*}` expands every word
        # BEFORE the builtin runs, so `b` reads the PREVIOUS `a`. Written as one `local` this
        # loop silently shifted every arm id by one iteration and reported A6 as having
        # produced no verdict — which reads as a broken harness, not as an authoring bug.
        doc="${v%%:*}"; rest="${v#*:}"; id="${rest%%:*}"; want="${rest##*:}"
        ri="$WORK/${tag}.${doc}"
        rm -rf "$ri"
        if ! build_repo "$ri" "$SEED/docs/${doc}.md" both "$VPUSE" >/dev/null; then
            echo "$id:fail:could not build the invocation repo (fixture broken, not a finding)"
            continue
        fi
        r="$(drive_provenance "$wf" "$ri" 302)"
        case "$r" in
            99) echo "$id:fail:no provenance step with a run: body" ;;
            98) echo "$id:fail:the provenance step does not consume steps.sprint.outputs.sprint" ;;
            2)  echo "$id:fail:validator exited 2 — it was pointed at a path that does not exist; that is a tool failure, NOT a rejection" ;;
            "$want") echo "$id:pass" ;;
            *)  if [ "$want" = 1 ]; then
                    echo "$id:fail:$doc.md ACCEPTED (rc=$r) — the step named the legacy path, where is_retro is false and the requirement is silently exempt"
                else
                    echo "$id:fail:$doc.md REJECTED (rc=$r) — a compliant retro must pass"
                fi ;;
        esac
    done

    # --- A5 the caller declares its own requirement ----------------------------
    # MUTANT: is_retro forced false in a COPY of the validator. Everything the flag would
    # reach via RETRO_PATH_RE is now gone, so only an explicit --require-skill can reject.
    local mut="$WORK/${tag}.mutant.sh"
    # Anchored on the ASSIGNMENT, not on its right-hand side. An anchor quoting the
    # RETRO_PATH_RE call is defeated by any change to how the path is normalised — measured:
    # the first draft of this arm quoted `RETRO_PATH_RE.search(artifact_path)` and the real
    # line wraps it in os.path.normpath(), so the disarm matched nothing and the arm was
    # vacuous. Note also that RETRO_PATH_RE itself must NOT be disarmed: the validator
    # self-tests the pattern and exits 2 if it stops matching, which is not a rejection.
    python3 - "$VPUSE" "$mut" <<'PY' >/dev/null
import re, sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()
s2 = re.sub(r'(?m)^is_retro = .*$', 'is_retro = False', s)
open(dst, "w", encoding="utf-8").write(s2)
PY
    if cmp -s "$VPUSE" "$mut"; then
        echo "A5:fail:the is_retro disarm matched nothing — validate-provenance-block.sh no longer computes is_retro that way, so this arm is vacuous and must be re-anchored"
    else
        local rd="$WORK/${tag}.disarm"
        rm -rf "$rd"
        if ! build_repo "$rd" "$SEED/docs/blockless.md" both "$mut" >/dev/null; then
            echo "A5:fail:could not build the disarm repo (fixture broken, not a finding)"
        else
            # REACHABILITY CONTROL: the disarmed validator, called DIRECTLY with no flag, must
            # ACCEPT the blockless retro. If it still rejects, the disarm did not take and A5
            # would pass for a reason that has nothing to do with the flag.
            ( cd "$rd" && bash scripts/ai-dlc/validate-provenance-block.sh docs/retro/s302/retro.md ) >/dev/null 2>&1
            if [ $? -ne 0 ]; then
                echo "A5:fail:CONTROL — the disarmed validator still rejects a blockless retro, so the mutant is not reached and this arm proves nothing"
            else
                r="$(drive_provenance "$wf" "$rd" 302)"
                if [ "$r" = 1 ]; then echo "A5:pass"
                else echo "A5:fail:with is_retro disarmed the workflow ACCEPTED a blockless retro (rc=$r) — the step depends entirely on RETRO_PATH_RE in another file and declares no requirement of its own"; fi
            fi
        fi
    fi
}

# ---------------------------------------------------------------------------
# SELF-PROBE — runs BEFORE the corpus, on synthetic trees under mktemp, and fires in BOTH
# directions. An arm reporting zero findings without first proving it can produce one has
# established that it ran, not that the subject is clean.
# ---------------------------------------------------------------------------
probe_legacy="$(arms "$SEED/probe-legacy.yml" plegacy)"
probe_fixed="$(arms "$SEED/probe-fixed.yml"  pfixed)"

n_leg_fail="$(grep -c ':fail:' <<<"$probe_legacy")"
n_fix_fail="$(grep -c ':fail:' <<<"$probe_fixed")"

# Offender direction: the synthetic legacy workflow must trip A1 A2 A3 A4 A5 — each named,
# because "five findings" would also be satisfied by five copies of one finding.
p_missing=""
for id in A1 A2 A3 A4 A5; do
    grep -q "^${id}:fail:" <<<"$probe_legacy" || p_missing="$p_missing $id"
done
if [ -z "$p_missing" ]; then
    ok "P1 self-probe: the synthetic LEGACY workflow trips A1 A2 A3 A4 A5 by name"
else
    bad "P1 self-probe: the synthetic LEGACY workflow did NOT trip$p_missing — those arms cannot fire, and a clean corpus run would mean nothing"
    sed 's/^/        /' <<<"$probe_legacy" >&2
fi
# Near-miss direction. THE POSITIVE CONJUNCT IS NOT DECORATION: "zero findings" is exactly
# what a run that emitted nothing looks like, so the arm also requires all six verdict
# tokens to be PRESENT. Measured twice elsewhere in this repo, a control asserting only
# rc=0-and-no-findings passes against a subject replaced by `exit 0`.
n_fix_tok="$(grep -c '^A[1-6]:' <<<"$probe_fixed")"
if [ "$n_fix_fail" = 0 ] && [ "$n_fix_tok" = 6 ]; then
    ok "P2 self-probe: the synthetic FIXED workflow trips nothing, and all 6 arms reported"
elif [ "$n_fix_tok" != 6 ]; then
    bad "P2 self-probe: only $n_fix_tok of 6 arms produced a verdict — arms went silent, which is not the same as passing"
else
    bad "P2 self-probe: the synthetic FIXED workflow tripped $n_fix_fail arm(s); the arms are over-broad"
    grep ':fail:' <<<"$probe_fixed" | sed 's/^/        /' >&2
fi
# A probe whose two sides agree establishes nothing about either.
if [ "$n_leg_fail" -gt "$n_fix_fail" ]; then
    ok "P3 self-probe: the two probe sides DIFFER ($n_leg_fail findings vs $n_fix_fail)"
else
    bad "P3 self-probe: the two probe sides did not differ ($n_leg_fail vs $n_fix_fail) — both runs read the same tree"
fi

# ---------------------------------------------------------------------------
# MUTANTS — the question a both-directions probe cannot answer.
#
# P1/P2 establish that the arms discriminate between two workflows. They do NOT establish
# what happens when a SUBJECT EMITS NOTHING, and that is the state an absence-shaped arm
# passes silently. Both subjects get one: the workflow and the validator it calls.
# ---------------------------------------------------------------------------
: > "$WORK/empty.yml"
m1="$(arms "$WORK/empty.yml" m1)"
m1_missing=""
for id in A1 A2 A3 A4 A5 A6; do
    grep -q "^${id}:fail:" <<<"$m1" || m1_missing="$m1_missing $id"
done
if [ -z "$m1_missing" ]; then
    ok "M1 mutant: an EMPTY workflow file trips all six arms — no arm treats a subject that says nothing as a subject that is clean"
else
    bad "M1 mutant: an EMPTY workflow file left$m1_missing quiet — those arms would report ok for a workflow that does not exist"
fi

# M2 — the validator replaced by `exit 0`. The three REJECT arms must all still fire; if any
# passes, it is asserting "the pipeline ran", not "the document was rejected".
printf '#!/usr/bin/env bash\nexit 0\n' > "$WORK/vp-yes.sh"; chmod +x "$WORK/vp-yes.sh"
m2="$(arms "$WF" m2 "$WORK/vp-yes.sh")"
m2_missing=""
for id in A3 A4 A5; do
    grep -q "^${id}:fail:" <<<"$m2" || m2_missing="$m2_missing $id"
done
if [ -z "$m2_missing" ]; then
    ok "M2 mutant: a validator replaced by \`exit 0\` trips A3 A4 A5"
else
    bad "M2 mutant: a validator that accepts everything left$m2_missing quiet"
fi

# M3 — the validator replaced by `exit 1`. A6 owns this case and must be the one that fires;
# a fixture whose every arm is a reject arm certifies a validator that rejects everything.
printf '#!/usr/bin/env bash\nexit 1\n' > "$WORK/vp-no.sh"; chmod +x "$WORK/vp-no.sh"
m3="$(arms "$WF" m3 "$WORK/vp-no.sh")"
if grep -q '^A6:fail:' <<<"$m3"; then
    ok "M3 mutant: a validator replaced by \`exit 1\` trips A6 — the accept direction is load-bearing"
else
    bad "M3 mutant: a validator that rejects everything did NOT trip A6"
fi

# ---------------------------------------------------------------------------
# CWD INVARIANCE — asserted in its own arms, not inherited from how the suite is driven.
# ---------------------------------------------------------------------------
r_here="$( ( cd "$HERE" && bash "$HERE/run.sh" --print-root ) )"
r_root="$( ( cd "$ROOT" && bash "$HERE/run.sh" --print-root ) )"
r_alien="$( ( cd "$WORK" && bash "$HERE/run.sh" --print-root ) )"
if [ "$r_here" = "$ROOT" ] && [ "$r_root" = "$ROOT" ] && [ "$r_alien" = "$ROOT" ]; then
    ok "Z1 root resolution is identical from this dir, the repo root, and a tmpdir outside the tree"
else
    bad "Z1 root resolution is cwd-dependent (here=$r_here root=$r_root alien=$r_alien expected=$ROOT)"
fi
# And the driver itself, not only the resolver: one corpus arm re-run from an alien cwd.
z_here="$(arms "$SEED/probe-legacy.yml" zhere | grep '^A2:')"
z_alien="$( ( cd "$WORK" && arms "$SEED/probe-legacy.yml" zalien | grep '^A2:' ) )"
if [ "$z_here" = "$z_alien" ] && [ -n "$z_here" ]; then
    ok "Z2 the driver answers identically from an alien cwd (A2 verdict held constant)"
else
    bad "Z2 the driver is cwd-dependent (here='$z_here' alien='$z_alien')"
fi

# ---------------------------------------------------------------------------
# THE CORPUS — the shipped workflow.
# ---------------------------------------------------------------------------
echo "  -- layout: $LAYOUT   subject: ${WF#$ROOT/}"
real="$(arms "$WF" real)"
name_of() {
    case "$1" in
        A1) echo "A1 on.pull_request.paths triggers on a migrated retro path" ;;
        A2) echo "A2 the changed-set filter and the sprint extraction resolve a sprint number" ;;
        A3) echo "A3 a blockless retro is REJECTED" ;;
        A4) echo "A4 a party-mode block with no transcript_path is REJECTED" ;;
        A5) echo "A5 the step declares its own requirement (is_retro disarmed)" ;;
        A6) echo "A6 a compliant retro is ACCEPTED" ;;
    esac
}
for id in A1 A2 A3 A4 A5 A6; do
    line="$(grep "^${id}:" <<<"$real" | head -n 1)"
    if [ -z "$line" ]; then
        bad "$(name_of "$id") — the arm produced no verdict at all"
    elif [ "$line" = "${id}:pass" ]; then
        ok "$(name_of "$id")"
    else
        bad "$(name_of "$id") -- ${line#*:fail:}"
    fi
done

if [ "$fails" -ne 0 ]; then
    echo "retro-compliance-workflow: $fails FAILED" >&2
    exit 1
fi
echo "retro-compliance-workflow: all arms passed"
