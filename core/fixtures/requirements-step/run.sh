#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# requirements-step — assert the `requirements` step replaced discovery +
# research-requirements in the `carry-over` and `feature` pipeline rows, and that
# every join release 3 (0.531.0) touches actually moved.
#
# Ships to consumers: the subject (installed step files under
# `.claude/skills/ai-dlc/steps/`) is present there. TWO LAYOUTS, BOTH ROOTED AT
# THIS FILE, AND NO VERSION-MARKER WALK: this fixture SHIPS, and an installed
# consumer has no VERSION file at its root (its stamp is
# `.claude/.ai-dlc-version`), so a walk up for one resolves to nothing there and
# the fixture would exit 2 on every consumer push. Three levels up from this file
# is the project root in BOTH layouts (I106). If `requirements.md` is absent in
# the resolved steps dir this prints `SKIP requirements-step: subject not
# installed` and exits 0 — but only after every arm's self-probe has run against
# a mktemp tree, so the SKIP is never printed by a fixture that could not fire.
#
# Arms, each proven against a seeded mktemp offender (fires) and a seeded
# near-miss (stays quiet) BEFORE the corpus is read:
#   (a) route.md: carry-over/feature name `requirements`, not the old sequence;
#       the other four variants still name the old sequence (the partition).
#   (b) requirements.md: loaded token, nextStepFile, both adversarial-dispatch
#       substrings.
#   (c) carry-over-evaluation.md: nextStepFile + READ AND FOLLOW name
#       requirements.md.
#   (d) gate-validation.md: Check 24's "Those steps are:" names `requirements`;
#       Check 1c names the requirements gate and carries the skip-record regex.
#   (e) requirements.md names architecture-impact.md and architecture_impact:.
#   (f) SKILL.md Rule 8 lightweight row names `requirements`.
#   (g) validate-draft-stamps.sh DRAFTS= contains requirements-context.
#   (h) every step file carrying the prior-decision disposition vocabulary (derived,
#       at least two) agrees on the four members and states the deferred-unfiled
#       filing mandate; two committed mutants on a copy of the steps dir.
#   (i) requirements.md section 5 names partition-subject.sh and no longer says Rule 28
#       has no axis for a multi-artifact subject; 4(c) carries the `###` subheading
#       mandate. Two committed mutants (restore-sentence, drop-mandate) on a copy.
#   (j) gate-validation.md names `s<N>/requirements-adversarial-p` at BOTH Check 24 sites
#       (the invocation paragraph and the post-planning sweep), each read as its own
#       region; requirements.md's series-naming bullet carries the B4 refusal sentence
#       for a --document merge of a subject file.
#   (k) gate-validation.md teaches arm H's three repair-record labels (`disposition:`, `edit:`,
#       `derivation:`), against a same-file arm-H control (moved from check-24 H-BIND).
#   (l) every J3_SUCCESSORS row of validate-adversarial-convergence.sh agrees with the step
#       files' nextStepFile: and the successor's s<N>/<ctx> digest; self-probed (J3-MAP, BL-814,
#       moved from check-24 unit j3).
#   (m) BL-723: Check 24's test-strategy prefix runs stories-test-strategy.md §5's series through
#       the shipping validator; §5 names no bmad-review (control: bug-investigation.md does) and
#       names its dispatches and step 3's precondition. Four committed mutants plus an unmutated
#       control, each row scored whole (moved from check-24 unit tstrat).
#
# THE MUTANT MATRIX. A CELL is one corpus predicate: h (the disposition vocabulary agrees across a steps dir),
# i-axis and i-mandate (requirements.md section 5 and 4(c)), j-check and j-sweep (the two Check 24 sites of
# gate-validation.md) and j-refuse (the B4 refusal bullet of requirements.md). PER PUSH a mutant is scored on
# its DECIDING cell, which must fail on it, and its named TWIN, a different cell it could plausibly co-trip but
# must leave GREEN. `run.sh --matrix` scores each mutant against all six cells and prints one MATRIX line per
# mutant. The matrix is re-measured whenever an arm or a mutant is added or changed, by the REMEASURE command
# below, run from the repo root. The (i) and (j) mutants carry an i- or j- prefix because the bare names are
# prefixes of drop-from-one and drop-from-all.
# MUTANT-MATRIX drop-from-one decides=h twins=i-axis
# MUTANT-MATRIX drop-from-all decides=h twins=i-axis
# MUTANT-MATRIX i-restore decides=i-axis twins=i-mandate
# MUTANT-MATRIX i-drop decides=i-mandate twins=i-axis
# MUTANT-MATRIX j-check decides=j-check twins=j-sweep
# MUTANT-MATRIX j-sweep decides=j-sweep twins=j-check
# MUTANT-MATRIX j-refuse decides=j-refuse twins=i-axis
# Each of the three mutant loops passes its mutant name to mutant_killed as a variable, via one helper:
# The (m) rows: each is three cells (bind absent names), its deciding cell plus its twins ARE the row, and the whole
# row runs on every push, so the per-push match IS the matrix measurement.
# MUTANT-MATRIX MUTATION-ts-bmad-restored decides=MUTATION-ts-bmad-restored.cell2 twins=MUTATION-ts-bmad-restored.cell1,MUTATION-ts-bmad-restored.cell3
# MUTANT-MATRIX MUTATION-ts-bmad-restored-new decides=MUTATION-ts-bmad-restored-new.cell2 twins=MUTATION-ts-bmad-restored-new.cell1,MUTATION-ts-bmad-restored-new.cell3
# MUTANT-MATRIX MUTATION-ts-gate-prefix-dropped decides=MUTATION-ts-gate-prefix-dropped.cell1 twins=MUTATION-ts-gate-prefix-dropped.cell2,MUTATION-ts-gate-prefix-dropped.cell3
# MUTANT-MATRIX MUTATION-ts-precondition-deleted decides=MUTATION-ts-precondition-deleted.cell3 twins=MUTATION-ts-precondition-deleted.cell1,MUTATION-ts-precondition-deleted.cell2
# MUTANT-MATRIX-CONTROL CONTROL-ts-unmutated why=the shipped documents must score ok on all three test-strategy cells
# MUTANT-MATRIX-CONTROL MUTATION-ts-anchor why=the test-strategy step-2 anchor is unique against an impossible-anchor control
# MUTANT-MATRIX-DYNAMIC rs_score why=reads every mutant name of the (h), (i) and (j) loops as a variable and every name keeps its own row
# MUTANT-MATRIX-REMEASURE bash core/fixtures/requirements-step/run.sh --matrix
#
# Usage: run.sh [--matrix]
# Exit:  0 = every assertion holds (or subject not installed), 1 = a regression,
#        2 = fixture broken (a probe could not be proven in either direction).
set -uo pipefail

MODE=plain
case "${1:-}" in
  "") ;;
  --matrix) MODE=matrix ;;
  *) echo "requirements-step: usage: run.sh [--matrix]" >&2; exit 2 ;;
esac

HERE="$(cd "$(dirname "$0")" && pwd)"

# --- resolve the project root: three levels up from this file in BOTH layouts,
# never a VERSION-marker walk (I106) ---
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
[ -n "$ROOT" ] || { echo "FIXTURE ERROR: could not resolve project root three levels above $HERE" >&2; exit 2; }

# --- resolve the steps dir in both layouts, relative to ROOT ---
STEPS=""
for cand in "$ROOT/core/skills/ai-dlc/steps" "$ROOT/.claude/skills/ai-dlc/steps"; do
  [ -d "$cand" ] && { STEPS="$cand"; break; }
done
[ -n "$STEPS" ] || {
  echo "FIXTURE ERROR: ai-dlc steps dir not found in either layout under $ROOT" >&2
  exit 2
}
SKILLDIR="$(dirname "$STEPS")"

fails=0
probes=0
report() { printf '  %-4s %s\n' "$1" "$2"; [ "$1" = FAIL ] && fails=$((fails + 1)); }

# =====================================================================
# SELF-PROBES. Each arm's grammar is proven against a mktemp tree BEFORE
# it is ever pointed at the real corpus: a seeded offender must fire, a
# seeded near-miss must stay quiet. Both directions, printed.
# =====================================================================
PROBE="$(mktemp -d)"
trap 'rm -rf "$PROBE"' EXIT

probe_ok()  { probes=$((probes + 1)); report ok "PROBE: $1"; }
probe_bad() { probes=$((probes + 1)); report FAIL "PROBE: $1 -- $2"; }

# --- arm (a) probe: route.md partition grammar ---
# offender: a carry-over row that still names the old sequence and no `requirements`
# near-miss: a carry-over row that names `requirements` and not the old sequence
route_row_is_old_seq() { # <file> <variant-label>
  grep -E "^\| ${2} \|.*discovery.*research-requirements" "$1" >/dev/null 2>&1
}
# "requirements" alone, never as a substring of "research-requirements". Strip the
# compound token first, then look for the bare word in what remains.
route_row_names_requirements() { # <file> <variant-label>
  local row stripped
  row="$(grep -E "^\| ${2} \|" "$1")" || return 1
  stripped="$(sed -E 's/research-requirements//g' <<<"$row")"
  grep -qE '(^|[^A-Za-z-])requirements([^A-Za-z-]|$)' <<<"$stripped"
}
cat > "$PROBE/route-offender.md" <<'EOF'
| feature | discovery → research-requirements → architecture | `discovery.md` |
EOF
cat > "$PROBE/route-nearmiss.md" <<'EOF'
| feature | requirements → architecture | `requirements.md` |
EOF
if route_row_is_old_seq "$PROBE/route-offender.md" feature && ! route_row_names_requirements "$PROBE/route-offender.md" feature; then
  probe_ok "(a) route.md offender detected as old-sequence, not requirements"
else
  probe_bad "(a)" "offender probe did not classify as expected"
fi
if ! route_row_is_old_seq "$PROBE/route-nearmiss.md" feature && route_row_names_requirements "$PROBE/route-nearmiss.md" feature; then
  probe_ok "(a) route.md near-miss (already-fixed row) stays quiet on old-sequence check"
else
  probe_bad "(a)" "near-miss probe did not classify as expected"
fi
# Also prove the OTHER direction of the partition: a variant that MUST still carry
# the old sequence (e.g. greenfield) must not be flagged as missing it.
cat > "$PROBE/route-greenfield-ok.md" <<'EOF'
| greenfield | discovery → research-requirements → architecture | `discovery.md` |
EOF
cat > "$PROBE/route-greenfield-bad.md" <<'EOF'
| greenfield | requirements → architecture | `requirements.md` |
EOF
if route_row_is_old_seq "$PROBE/route-greenfield-ok.md" greenfield; then
  probe_ok "(a) greenfield near-miss: retains old sequence, correctly not flagged"
else
  probe_bad "(a)" "greenfield-ok probe did not detect old sequence"
fi
if ! route_row_is_old_seq "$PROBE/route-greenfield-bad.md" greenfield; then
  probe_ok "(a) greenfield offender: a greenfield row that lost the old sequence is caught"
else
  probe_bad "(a)" "greenfield-bad probe failed to detect the missing old sequence"
fi

# --- arm (b) probe: requirements.md token grammar ---
cat > "$PROBE/req-offender.md" <<'EOF'
---
name: requirements
---
Some text with no loaded token and no nextStepFile.
EOF
cat > "$PROBE/req-nearmiss.md" <<'EOF'
---
name: requirements
nextStepFile: ./architecture.md
---
<!-- STEP_LOADED_TOKEN: requirements -->
**Adversarial review dispatch** and **Adversarial repair dispatch** subroutines.
EOF
if ! grep -qF '<!-- STEP_LOADED_TOKEN: requirements -->' "$PROBE/req-offender.md"; then
  probe_ok "(b) offender missing loaded token, correctly flagged"
else
  probe_bad "(b)" "offender probe unexpectedly matched the loaded token"
fi
if grep -qF '<!-- STEP_LOADED_TOKEN: requirements -->' "$PROBE/req-nearmiss.md" \
  && grep -qF 'nextStepFile: ./architecture.md' "$PROBE/req-nearmiss.md" \
  && grep -qF 'Adversarial review dispatch' "$PROBE/req-nearmiss.md" \
  && grep -qF 'Adversarial repair dispatch' "$PROBE/req-nearmiss.md"; then
  probe_ok "(b) near-miss (well-formed file) passes all four checks"
else
  probe_bad "(b)" "near-miss probe failed to pass a well-formed file"
fi

# --- arm (c) probe: carry-over-evaluation.md grammar ---
cat > "$PROBE/coe-offender.md" <<'EOF'
---
nextStepFile: ./discovery.md
---
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/discovery.md`
EOF
cat > "$PROBE/coe-nearmiss.md" <<'EOF'
---
nextStepFile: ./requirements.md
---
**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/requirements.md`
EOF
if ! grep -qF 'nextStepFile: ./requirements.md' "$PROBE/coe-offender.md" \
  && ! grep -qF 'steps/requirements.md' "$PROBE/coe-offender.md"; then
  probe_ok "(c) offender (still points at discovery.md) correctly flagged"
else
  probe_bad "(c)" "offender probe unexpectedly matched requirements.md"
fi
if grep -qF 'nextStepFile: ./requirements.md' "$PROBE/coe-nearmiss.md" \
  && grep -qF 'steps/requirements.md' "$PROBE/coe-nearmiss.md"; then
  probe_ok "(c) near-miss (already-fixed file) passes"
else
  probe_bad "(c)" "near-miss probe failed to pass a well-formed file"
fi

# --- arm (d) probe: gate-validation.md grammar ---
cat > "$PROBE/gv-offender.md" <<'EOF'
### 24. The adversarial cycle CONVERGED (Rule 8).
Those steps are:
`carry-over-evaluation`, `discovery`, `architecture`, `research-requirements`,
`stories-test-strategy`.

### 1c. Research-invocation enforcement (research-requirements gate only).
Scope: fires only at the research-requirements gate.
EOF
cat > "$PROBE/gv-nearmiss.md" <<'EOF'
### 24. The adversarial cycle CONVERGED (Rule 8).
Those steps are:
`carry-over-evaluation`, `discovery`, `architecture`, `research-requirements`,
`requirements`, `stories-test-strategy`.

### 1c. Research-invocation enforcement (research-requirements gate, and the requirements gate on the variants that replace it).
Scope: fires at the research-requirements gate and at the requirements gate.
Arm (b) additionally accepted by a skip record matching regex
`^(- )?\*{0,2}Research skipped\*{0,2}:[[:space:]]+\S`.
EOF
# The list can wrap across several lines (it does in the real corpus, where
# `requirements` sits alone on its own line before a parenthetical). Join every
# line from the header up to the terminating sentence (one ending in a period).
those_steps_line() {
  awk '
    /^Those steps are:/ { grab = 1; next }
    grab { buf = buf " " $0; if ($0 ~ /\.$/) { print buf; exit } }
  ' "$1"
}
# The `requirements` backtick token, never the tail of `research-requirements`.
those_steps_names_requirements() { grep -qF '`requirements`' <<<"$(those_steps_line "$1")"; }
# "the requirements gate", never the tail of "the research-requirements gate".
names_requirements_gate() { grep -qF 'the requirements gate' "$1"; }
if ! those_steps_names_requirements "$PROBE/gv-offender.md" \
  && ! names_requirements_gate "$PROBE/gv-offender.md"; then
  probe_ok "(d) offender missing 'requirements' in Check 24 list and Check 1c scope, flagged"
else
  probe_bad "(d)" "offender probe unexpectedly matched"
fi
if those_steps_names_requirements "$PROBE/gv-nearmiss.md" \
  && names_requirements_gate "$PROBE/gv-nearmiss.md" \
  && grep -qE 'Research skipped\\\*\{0,2\}:\[\[:space:\]\]\+\\S' "$PROBE/gv-nearmiss.md"; then
  probe_ok "(d) near-miss (well-formed file) passes"
else
  probe_bad "(d)" "near-miss probe failed to pass a well-formed file"
fi

# --- arm (e) probe ---
cat > "$PROBE/req-e-offender.md" <<'EOF'
No mention of the architecture impact record here.
EOF
cat > "$PROBE/req-e-nearmiss.md" <<'EOF'
Write `architecture-impact.md`. Each line: `architecture_impact: none` or a
one-line naming.
EOF
if ! grep -qF 'architecture-impact.md' "$PROBE/req-e-offender.md" \
  && ! grep -qF 'architecture_impact:' "$PROBE/req-e-offender.md"; then
  probe_ok "(e) offender missing both tokens, flagged"
else
  probe_bad "(e)" "offender probe unexpectedly matched"
fi
if grep -qF 'architecture-impact.md' "$PROBE/req-e-nearmiss.md" \
  && grep -qF 'architecture_impact:' "$PROBE/req-e-nearmiss.md"; then
  probe_ok "(e) near-miss passes"
else
  probe_bad "(e)" "near-miss probe failed to pass a well-formed file"
fi

# --- arm (f) probe ---
cat > "$PROBE/skill-offender.md" <<'EOF'
| `lightweight` | All stories touch only pipeline-infra paths | Adversarial Review at discovery + stories-test-strategy only |
EOF
cat > "$PROBE/skill-nearmiss.md" <<'EOF'
| `lightweight` | All stories touch only pipeline-infra paths | Adversarial Review at discovery + requirements + stories-test-strategy only |
EOF
_row="$(grep -E '^\| `lightweight`' "$PROBE/skill-offender.md")"
if grep -qF 'requirements' <<<"$_row"; then
  probe_bad "(f)" "offender probe unexpectedly matched 'requirements' in lightweight row"
else
  probe_ok "(f) offender lightweight row missing 'requirements', flagged"
fi
_row="$(grep -E '^\| `lightweight`' "$PROBE/skill-nearmiss.md")"
if grep -qF 'requirements' <<<"$_row"; then
  probe_ok "(f) near-miss (well-formed row) passes"
else
  probe_bad "(f)" "near-miss probe failed to pass a well-formed row"
fi

# --- arm (g) probe ---
cat > "$PROBE/draft-offender.sh" <<'EOF'
DRAFTS="carry-over-evaluation discovery-context research-notes architecture-context test-strategy"
EOF
cat > "$PROBE/draft-nearmiss.sh" <<'EOF'
DRAFTS="carry-over-evaluation discovery-context research-notes architecture-context test-strategy requirements-context"
EOF
_line="$(grep -E '^DRAFTS=' "$PROBE/draft-offender.sh")"
if ! grep -qF 'requirements-context' <<<"$_line"; then
  probe_ok "(g) offender DRAFTS= missing requirements-context, flagged"
else
  probe_bad "(g)" "offender probe unexpectedly matched"
fi
_line="$(grep -E '^DRAFTS=' "$PROBE/draft-nearmiss.sh")"
if grep -qF 'requirements-context' <<<"$_line"; then
  probe_ok "(g) near-miss (well-formed line) passes"
else
  probe_bad "(g)" "near-miss probe failed to pass a well-formed line"
fi

# --- arm (h): the prior-decision disposition vocabulary ---
# The CARRIER set is derived, never hand-listed: every step file whose text, with
# its lines joined, carries the anchor `one-line disposition per hit (`. Members are
# the backtick tokens inside THAT parenthetical only -- discovery.md names two of
# them again in its cost paragraph, and a whole-file grammar would count those.
# Joining lines first is what makes a reflow a non-event: the two carriers wrap at
# different widths. Three conjuncts, because agreement alone cannot fail on a tree
# where EVERY carrier dropped the member: >=2 carriers, identical sets, and the set
# is exactly the four members with `deferred-unfiled` among them. A fourth conjunct
# keys the member's mandate (file it before the gate passes) in every carrier.
DISPO_ANCHOR='one-line disposition per hit ('
DISPO_WANT='deferred-unfiled
not relevant
still binding
superseded'
DISPO_MANDATE='MUST be filed as a carry-over backlog item in `carry-over-backlog.md` before the gate passes'
flat_text() { tr '\n' ' ' < "$1" | tr -s ' '; }
disposition_set() { # <file> -> sorted members, one per line; nothing if no anchor
  local flat after
  flat="$(flat_text "$1")"
  case "$flat" in *"$DISPO_ANCHOR"*) ;; *) return 0 ;; esac
  after="${flat#*"$DISPO_ANCHOR"}"
  { grep -oE '`[^`]+`' <<<"${after%%)*}" || true; } | tr -d '`' | LC_ALL=C sort
}
DISPO_WHY=""
dispositions_agree() { # <steps-dir> -> 0 when every conjunct holds; DISPO_WHY says which failed
  local f s first="" n=0 have
  DISPO_WHY=""
  for f in "$1"/*.md; do
    [ -f "$f" ] || continue
    s="$(disposition_set "$f")"
    [ -n "$s" ] || continue
    n=$((n + 1))
    if [ "$n" -eq 1 ]; then first="$s"; have="$(basename "$f")"
    elif [ "$s" != "$first" ]; then
      DISPO_WHY="carriers disagree: $have has [$(tr '\n' ',' <<<"$first")] but $(basename "$f") has [$(tr '\n' ',' <<<"$s")]"
      return 1
    fi
    case "$(flat_text "$f")" in *"$DISPO_MANDATE"*) ;; *)
      DISPO_WHY="$(basename "$f") carries the vocabulary but not the deferred-unfiled filing mandate"
      return 1 ;;
    esac
  done
  [ "$n" -ge 2 ] || { DISPO_WHY="only $n carrier(s) of the anchor found; agreement over fewer than two is vacuous"; return 1; }
  [ "$first" = "$DISPO_WANT" ] || { DISPO_WHY="carriers agree on [$(tr '\n' ',' <<<"$first")], not the four-member set"; return 1; }
  return 0
}
mk_carrier() { # <file> <parenthetical-members> <wrap: one|two> [extra prose]
  if [ "$3" = one ]; then
    printf 'Cite the hit count, and a one-line disposition per hit (%s). %s\nA hit dispositioned `deferred-unfiled` %s, and the item is cited.\n' "$2" "${4:-}" "$DISPO_MANDATE" > "$1"
  else
    printf 'Cite the hit count, and a one-line disposition per\nhit (%s).\n%s A hit dispositioned\n`deferred-unfiled` %s, and\nthe item is cited.\n' "$2" "${4:-}" "$DISPO_MANDATE" > "$1"
  fi
}
M4='`superseded` / `still binding` / `not relevant` / `deferred-unfiled`'
M3='`superseded` / `still binding` / `not relevant`'
dprobe() { # <label> <expect: fire|quiet> <dir>
  if dispositions_agree "$3"; then got=quiet; else got=fire; fi
  if [ "$got" = "$2" ]; then probe_ok "(h) $1 -> $got${DISPO_WHY:+ ($DISPO_WHY)}"
  else probe_bad "(h) $1" "expected $2, got $got${DISPO_WHY:+ ($DISPO_WHY)}"; fi
}
for w in nm-reflow off-one off-all off-prose off-single off-mandate; do mkdir -p "$PROBE/h-$w"; done
mk_carrier "$PROBE/h-nm-reflow/a.md" "$M4" one
mk_carrier "$PROBE/h-nm-reflow/b.md" "$M4" two 'Other prose names `superseded` again.'
printf 'No anchor here, only `superseded`.\n' > "$PROBE/h-nm-reflow/c.md"
mk_carrier "$PROBE/h-off-one/a.md" "$M4" one
mk_carrier "$PROBE/h-off-one/b.md" "$M3" two
mk_carrier "$PROBE/h-off-all/a.md" "$M3" one
mk_carrier "$PROBE/h-off-all/b.md" "$M3" two
mk_carrier "$PROBE/h-off-prose/a.md" "$M4" one
mk_carrier "$PROBE/h-off-prose/b.md" "$M3" two 'Elsewhere `deferred-unfiled` is named in prose.'
mk_carrier "$PROBE/h-off-single/a.md" "$M4" one
mk_carrier "$PROBE/h-off-mandate/a.md" "$M4" one
printf 'Cite the hit count, and a one-line disposition per hit (%s).\n' "$M4" > "$PROBE/h-off-mandate/b.md"
dprobe "near-miss: same four members, different wrap, extra prose tokens, a non-carrier" quiet "$PROBE/h-nm-reflow"
dprobe "offender: one carrier dropped deferred-unfiled" fire "$PROBE/h-off-one"
dprobe "offender: every carrier dropped deferred-unfiled (agreement alone would pass)" fire "$PROBE/h-off-all"
dprobe "offender: deferred-unfiled in prose but not in the parenthetical" fire "$PROBE/h-off-prose"
dprobe "offender: a single carrier" fire "$PROBE/h-off-single"
dprobe "offender: a carrier without the filing mandate" fire "$PROBE/h-off-mandate"

# --- arm (i): the subject axis in section 5, and the `###` mandate in 4(c) ---
# Each predicate reads ONE region of requirements.md, never the whole file: section 5 is
# from its `### 5.` heading to the next `### `, 4(c) from its `**(c) Update the PRD.**`
# opener to `**PRD validation.**`. The mandate key is its sentence, not the bare `###`
# token, which every step file carries as headings.
SUBJ_TOOL='partition-subject.sh'
OLD_SENT='has no axis for a multi-artifact subject'
MANDATE='The sprint'"'"'s PRD content MUST carry `###` subheadings'
region() { # <file> <start-literal> <stop-literal> -> the joined text between them
  awk -v a="$2" -v b="$3" '
    !on && index($0, a) { on = 1; print; next }
    on && index($0, b) { exit }
    on { print }' "$1" | tr '\n' ' ' | tr -s ' '
}
sec5() { region "$1" '### 5. ' '### 6. '; }
sec4c() { region "$1" '**(c) Update the PRD.**' '**PRD validation.**'; }
I_WHY=""
subject_axis_ok() { # <requirements.md> -> 0 when section 5 names the tool and lacks the old sentence
  local s; s="$(sec5 "$1")"; I_WHY=""
  [ -n "$s" ] || { I_WHY="section 5 not found"; return 1; }
  case "$s" in *"$SUBJ_TOOL"*) ;; *) I_WHY="section 5 does not name $SUBJ_TOOL"; return 1 ;; esac
  case "$s" in *"$OLD_SENT"*) I_WHY="section 5 still says it '$OLD_SENT'"; return 1 ;; esac
  return 0
}
mandate_ok() { # <requirements.md> -> 0 when 4(c) carries the mandate sentence
  local s; s="$(sec4c "$1")"; I_WHY=""
  [ -n "$s" ] || { I_WHY="4(c) not found"; return 1; }
  case "$s" in *"$MANDATE"*) return 0 ;; esac
  I_WHY="4(c) does not carry the \`###\` subheading mandate"; return 1
}
iprobe() { # <label> <expect: ok|fire> <predicate> <file>
  if "$3" "$4"; then got=ok; else got=fire; fi
  if [ "$got" = "$2" ]; then probe_ok "(i) $1 -> $got${I_WHY:+ ($I_WHY)}"
  else probe_bad "(i) $1" "expected $2, got $got${I_WHY:+ ($I_WHY)}"; fi
}
mk_req() { # <file> <section-5 body> <4(c) body>
  printf '### 4. Authoring\n**(c) Update the PRD.** Integrate.\n%s\n**PRD validation.** Run it.\n### 5. Validation Cycle\n%s\n### 6. Gate\nThe tail names %s and says it %s, outside section 5.\n' \
    "$3" "$2" "$SUBJ_TOOL" "$OLD_SENT" > "$1"
}
GOOD5="Map with \`scripts/ai-dlc/$SUBJ_TOOL --map <N>\`."
mk_req "$PROBE/i-nm.md"      "$GOOD5" "$MANDATE — every section."
mk_req "$PROBE/i-old.md"     "$GOOD5 Rule 28 $OLD_SENT, so one agent." "$MANDATE — every section."
mk_req "$PROBE/i-notool.md"  "Run the cycle over one subject." "$MANDATE — every section."
mk_req "$PROBE/i-nomand.md"  "$GOOD5" "Quote the source; headings like ### Scope appear here."
# Mandate sentence present in the file but OUTSIDE 4(c): a whole-file grep would pass it.
mk_req "$PROBE/i-mandout.md" "$GOOD5 $MANDATE." "Quote the source."
iprobe "near-miss: tool in section 5, old sentence only outside it" ok subject_axis_ok "$PROBE/i-nm.md"
iprobe "offender: old sentence restored inside section 5" fire subject_axis_ok "$PROBE/i-old.md"
iprobe "offender: section 5 does not name the tool (named only outside it)" fire subject_axis_ok "$PROBE/i-notool.md"
iprobe "near-miss: mandate in 4(c)" ok mandate_ok "$PROBE/i-nm.md"
iprobe "offender: 4(c) carries bare ### tokens but no mandate" fire mandate_ok "$PROBE/i-nomand.md"
iprobe "offender: mandate sentence present only outside 4(c)" fire mandate_ok "$PROBE/i-mandout.md"

# --- arm (j) probe: the requirements series is NAMED at both Check 24 sites, and requirements.md
# says B4 refuses a --document merge of a subject file (BL-461). Each predicate reads ONE region, so a
# whole-file count cannot be satisfied by two mentions in one paragraph.
J_TOK='s<N>/requirements-adversarial-p'
J_CHECK_A='**Check.** Invoke `scripts/ai-dlc/validate-adversarial-convergence.sh'
J_SWEEP_A='**At every gate after the first planning gate'
J_SWEEP_Z='Each arm emits its own named failure'
J_REQ_A='**The adversarial series is named'
J_REQ_Z='**party-mode seats'
J_REFUSE_1='No `--document` merge of a subject file'
J_REFUSE_2='refuses one (its B4)'
J_WHY=""
j_check_ok() { local s; s="$(region "$1" "$J_CHECK_A" "$J_SWEEP_A")"; J_WHY=""
  [ -n "$s" ] || { J_WHY="the Check 24 invocation paragraph not found"; return 1; }
  case "$s" in *"$J_TOK"*) return 0 ;; esac; J_WHY="the Check 24 invocation paragraph does not name $J_TOK"; return 1; }
j_sweep_ok() { local s; s="$(region "$1" "$J_SWEEP_A" "$J_SWEEP_Z")"; J_WHY=""
  [ -n "$s" ] || { J_WHY="the post-planning sweep paragraph not found"; return 1; }
  case "$s" in *"$J_TOK"*) return 0 ;; esac; J_WHY="the post-planning sweep paragraph does not name $J_TOK"; return 1; }
j_refuse_ok() { local s; s="$(region "$1" "$J_REQ_A" "$J_REQ_Z")"; J_WHY=""
  [ -n "$s" ] || { J_WHY="the series-naming bullet not found"; return 1; }
  case "$s" in *"$J_REFUSE_1"*"$J_REFUSE_2"*) return 0 ;; esac
  J_WHY="the series-naming bullet does not say a --document merge of a subject file is refused by B4"; return 1; }
jprobe() { # <label> <expect: ok|fire> <predicate> <file>
  if "$3" "$4"; then got=ok; else got=fire; fi
  if [ "$got" = "$2" ]; then probe_ok "(j) $1 -> $got${J_WHY:+ ($J_WHY)}"
  else probe_bad "(j) $1" "expected $2, got $got${J_WHY:+ ($J_WHY)}"; fi
}
mk_gv() { # <file> <check-paragraph extra> <sweep-paragraph extra>
  printf '%s --series\n<prefix>`; exit 0 required. %s\n\n%s sprint.** Run it. %s\n%s here.\n' \
    "$J_CHECK_A" "$2" "$J_SWEEP_A" "$3" "$J_SWEEP_Z" > "$1"
}
mk_gv "$PROBE/j-gv-nm.md" "Prefix \`_bmad-output/planning-artifacts/$J_TOK\`." "The series \`_bmad-output/planning-artifacts/$J_TOK\` is one."
# Both offenders carry the token TWICE in the file, in the other paragraph: a whole-file count of 2 passes them.
mk_gv "$PROBE/j-gv-nocheck.md" "Prefix of the step." "The series \`$J_TOK\` is one, and so is \`$J_TOK\`."
mk_gv "$PROBE/j-gv-nosweep.md" "Prefix \`$J_TOK\`, or \`$J_TOK\`." "Each series."
printf '%s `s<N>/requirements-adversarial-p<M>`.** %s\n  while the manifest exists, and `merge-adversarial-shards.sh` %s.\n%s / subject:** x\n' \
  "$J_REQ_A" "$J_REFUSE_1" "$J_REFUSE_2" "$J_REQ_Z" > "$PROBE/j-req-nm.md"
# Offender: the sentence sits in the file, but OUTSIDE the series-naming bullet.
printf '%s `s<N>/requirements-adversarial-p<M>`.** Merged by --subject.\n%s / subject:** x\n%s, and it %s.\n' \
  "$J_REQ_A" "$J_REQ_Z" "$J_REFUSE_1" "$J_REFUSE_2" > "$PROBE/j-req-out.md"
jprobe "near-miss: both paragraphs name the series" ok j_check_ok "$PROBE/j-gv-nm.md"
jprobe "near-miss: both paragraphs name the series (sweep)" ok j_sweep_ok "$PROBE/j-gv-nm.md"
jprobe "offender: invocation paragraph silent, token twice in the sweep" fire j_check_ok "$PROBE/j-gv-nocheck.md"
jprobe "offender: sweep paragraph silent, token twice in the invocation" fire j_sweep_ok "$PROBE/j-gv-nosweep.md"
jprobe "near-miss: the refusal sentence in the bullet" ok j_refuse_ok "$PROBE/j-req-nm.md"
jprobe "offender: the refusal sentence only outside the bullet" fire j_refuse_ok "$PROBE/j-req-out.md"

echo "requirements-step: $probes self-probe assertion(s), $fails failed"
if [ "$fails" -gt 0 ]; then
  echo "FIXTURE ERROR: a self-probe could not discriminate offender from near-miss; corpus arms below would not be trustworthy." >&2
  exit 2
fi
echo

# =====================================================================
# CORPUS. If requirements.md is not installed, print SKIP and exit 0 —
# but only now, after every probe above has proven it can fire.
# =====================================================================
REQMD="$STEPS/requirements.md"
if [ ! -f "$REQMD" ]; then
  echo "SKIP requirements-step: subject not installed"
  exit 0
fi
for _hc in steps/route.md steps/requirements.md steps/carry-over-evaluation.md steps/gate-validation.md SKILL.md; do
  echo "HERMETIC-CONSUMED core/skills/ai-dlc/$_hc"
done

ROUTEMD="$STEPS/route.md"
COEMD="$STEPS/carry-over-evaluation.md"
GVMD="$STEPS/gate-validation.md"
SKILLMD="$SKILLDIR/SKILL.md"
DRAFTSTAMPS=""
for cand in "$ROOT/core/scripts/validate-draft-stamps.sh" "$ROOT/scripts/ai-dlc/validate-draft-stamps.sh"; do
  [ -f "$cand" ] && { DRAFTSTAMPS="$cand"; break; }
done

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

echo "requirements-step: running arms against the corpus"
echo

# --- (a) route.md partition ---
if [ -f "$ROUTEMD" ]; then
  for v in carry-over feature; do
    if ! route_row_is_old_seq "$ROUTEMD" "$v" && route_row_names_requirements "$ROUTEMD" "$v"; then
      ok "(a) route.md '$v' row names requirements, not the old sequence"
    else
      bad "(a) route.md '$v' row does not carry the expected requirements sequence"
    fi
  done
  for v in greenfield brownfield-a brownfield-b brownfield-c; do
    if route_row_is_old_seq "$ROUTEMD" "$v"; then
      ok "(a) route.md '$v' row still carries discovery -> research-requirements (unchanged)"
    else
      bad "(a) route.md '$v' row lost the discovery -> research-requirements sequence"
    fi
  done
else
  bad "(a) route.md not found at $ROUTEMD"
fi

# --- (b) requirements.md tokens ---
if grep -qF '<!-- STEP_LOADED_TOKEN: requirements -->' "$REQMD"; then
  ok "(b) requirements.md carries the loaded token"
else
  bad "(b) requirements.md missing the loaded token"
fi
if grep -qF 'nextStepFile: ./architecture.md' "$REQMD"; then
  ok "(b) requirements.md nextStepFile: ./architecture.md"
else
  bad "(b) requirements.md missing nextStepFile: ./architecture.md"
fi
if grep -qF 'Adversarial review dispatch' "$REQMD"; then
  ok "(b) requirements.md carries 'Adversarial review dispatch'"
else
  bad "(b) requirements.md missing 'Adversarial review dispatch'"
fi
if grep -qF 'Adversarial repair dispatch' "$REQMD"; then
  ok "(b) requirements.md carries 'Adversarial repair dispatch'"
else
  bad "(b) requirements.md missing 'Adversarial repair dispatch'"
fi

# --- (c) carry-over-evaluation.md ---
if [ -f "$COEMD" ]; then
  if grep -qF 'nextStepFile: ./requirements.md' "$COEMD"; then
    ok "(c) carry-over-evaluation.md nextStepFile: ./requirements.md"
  else
    bad "(c) carry-over-evaluation.md missing nextStepFile: ./requirements.md"
  fi
  if grep -qF 'steps/requirements.md' "$COEMD"; then
    ok "(c) carry-over-evaluation.md READ AND FOLLOW line names requirements.md"
  else
    bad "(c) carry-over-evaluation.md does not name steps/requirements.md"
  fi
else
  bad "(c) carry-over-evaluation.md not found at $COEMD"
fi

# --- (d) gate-validation.md ---
if [ -f "$GVMD" ]; then
  if those_steps_names_requirements "$GVMD"; then
    ok "(d) gate-validation.md Check 24 'Those steps are:' names requirements"
  else
    bad "(d) gate-validation.md Check 24 'Those steps are:' does not name requirements"
  fi
  if names_requirements_gate "$GVMD"; then
    ok "(d) gate-validation.md Check 1c body names the requirements gate"
  else
    bad "(d) gate-validation.md Check 1c body does not name the requirements gate"
  fi
  if grep -qE 'Research skipped\\\*\{0,2\}:\[\[:space:\]\]\+\\S' "$GVMD"; then
    ok "(d) gate-validation.md Check 1c carries the skip-record regex"
  else
    bad "(d) gate-validation.md Check 1c does not carry the skip-record regex"
  fi
else
  bad "(d) gate-validation.md not found at $GVMD"
fi

# --- (e) requirements.md architecture-impact ---
if grep -qF 'architecture-impact.md' "$REQMD"; then
  ok "(e) requirements.md names architecture-impact.md"
else
  bad "(e) requirements.md does not name architecture-impact.md"
fi
if grep -qF 'architecture_impact:' "$REQMD"; then
  ok "(e) requirements.md carries the token architecture_impact:"
else
  bad "(e) requirements.md does not carry the token architecture_impact:"
fi

# --- (f) SKILL.md lightweight row ---
if [ -f "$SKILLMD" ]; then
  LIGHTWEIGHT_ROW="$(grep -E '^\| `lightweight`' "$SKILLMD" | head -1)"
  if grep -qF 'requirements' <<<"$LIGHTWEIGHT_ROW"; then
    ok "(f) SKILL.md Rule 8 lightweight row names requirements"
  else
    bad "(f) SKILL.md Rule 8 lightweight row does not name requirements"
  fi
else
  bad "(f) SKILL.md not found at $SKILLMD"
fi

# --- (g) validate-draft-stamps.sh DRAFTS= ---
if [ -n "$DRAFTSTAMPS" ] && [ -f "$DRAFTSTAMPS" ]; then
  echo "HERMETIC-CONSUMED core/scripts/validate-draft-stamps.sh"
  DRAFTS_LINE="$(grep -E '^DRAFTS=' "$DRAFTSTAMPS" | head -1)"
  if grep -qF 'requirements-context' <<<"$DRAFTS_LINE"; then
    ok "(g) validate-draft-stamps.sh DRAFTS= contains requirements-context"
  else
    bad "(g) validate-draft-stamps.sh DRAFTS= does not contain requirements-context"
  fi
else
  bad "(g) validate-draft-stamps.sh not found"
fi

# --- (h) the disposition vocabulary agrees across every derived carrier ---
if dispositions_agree "$STEPS"; then
  ok "(h) every step file carrying the prior-decision disposition vocabulary agrees on the four members, and carries the deferred-unfiled filing mandate"; B_h=1
else
  bad "(h) prior-decision disposition vocabulary: $DISPO_WHY"
fi
# ---- matrix plumbing. The header rows are the only source of a mutant's deciding cell and twin. ----
MXL="$(mktemp)"; : > "$MXL"
RS_CELLS="h i-axis i-mandate j-check j-sweep j-refuse"
mx_row() { # <mutant> <decides|twins> -> that field of the mutant's single header row
  local n="$1" f="$2" l w c=0 v=""
  while IFS= read -r l; do
    case "$l" in
      "# MUTANT-MATRIX $n "*)
        c=$((c + 1))
        for w in ${l#"# MUTANT-MATRIX $n "}; do case "$w" in "$f="*) v="${w#"$f="}" ;; esac; done ;;
    esac
  done < "$HERE/run.sh"
  [ "$c" -eq 1 ] && printf '%s' "$v"
}
mx_count() { local k="$1" l n=0; while IFS= read -r l; do case "$l" in "$k "*) n=$((n + 1)) ;; esac; done < "$MXL"; printf '%s' "$n"; }
# rs_red <cell> <requirements.md> <gate-validation.md> <steps dir> -> 0 when the predicate FAILS (RED), 1 when it holds (GREEN).
rs_red() {
  case "$1" in
    h) ! dispositions_agree "$4" ;;
    i-axis) ! subject_axis_ok "$2" ;;
    i-mandate) ! mandate_ok "$2" ;;
    j-check) ! j_check_ok "$3" ;;
    j-sweep) ! j_sweep_ok "$3" ;;
    j-refuse) ! j_refuse_ok "$2" ;;
    *) echo "MATRIX BROKEN unknown cell $1"; exit 2 ;;
  esac
}
# rs_cell <cell> <req> <gv> <steps> -> RED|GREEN; a crashed predicate is BROKEN, never GREEN.
RS_WHY=""
rs_cell() {
  local r e="$MXL.err"
  # Each predicate sets only its own reason variable, so all three are cleared first: a stale reason from the
  # previous cell must not be read as this cell's.
  DISPO_WHY=""; I_WHY=""; J_WHY=""
  { rs_red "$1" "$2" "$3" "$4"; r=$?; } 2>"$e"
  case "$1" in h) RS_WHY="$DISPO_WHY" ;; i-*) RS_WHY="$I_WHY" ;; *) RS_WHY="$J_WHY" ;; esac
  case "$(cat "$e")" in
    *"unbound variable"*|*"command not found"*|*"syntax error"*)
      if [ "$MODE" = matrix ]; then echo "MATRIX BROKEN $1"; exit 2; fi
      bad "FIXTURE BROKEN: cell $1 crashed, which reads as GREEN" ;;
  esac
  if [ "$r" -eq 0 ]; then RS_COLOR=RED; else RS_COLOR=GREEN; fi
}
# rs_score <mutant> <base-pass flag> <message> <req> <gv> <steps> -- the deciding cell and the twin per push, every cell under --matrix.
rs_score() {
  local m="$1" fl="$2" msg="$3" req="$4" gv="$5" st="$6" dec tw d t why a g=0 tot=0 u="" rd=""
  dec="$(mx_row "$m" decides)"; tw="$(mx_row "$m" twins)"
  if [ -z "$dec" ] || [ -z "$tw" ]; then bad "MUTANT $m has no single MUTANT-MATRIX row naming its deciding cell and twin"; return; fi
  printf 'dec %s %s\n' "$m" "$dec" >> "$MXL"; printf 'dec %s %s\n' "$m" "$tw" >> "$MXL"
  rs_cell "$dec" "$req" "$gv" "$st"; d="$RS_COLOR"; why="$RS_WHY"
  rs_cell "$tw" "$req" "$gv" "$st"; t="$RS_COLOR"
  if [ "$d" = RED ]; then
    mutant_killed "$fl" "$m" "$msg$why"
  else
    bad "MUTANT $m SURVIVED: the $dec predicate passed on the mutated copy"
  fi
  if [ "$t" = RED ]; then bad "MUTANT $m is entangled: its twin $tw also failed"; fi
  if [ "$MODE" = matrix ]; then # mx-all-cells
    for a in $RS_CELLS; do
      if [ "$a" = "$dec" ] || [ "$a" = "$tw" ]; then continue; fi
      printf 'mx %s %s\n' "$m" "$a" >> "$MXL"
      tot=$((tot + 1)); rs_cell "$a" "$req" "$gv" "$st"; if [ "$RS_COLOR" = GREEN ]; then g=$((g + 1)); else rd="$rd,$a"; fi
    done
    if [ "$d" = GREEN ]; then u=" UNEXPECTED=$dec:GREEN"; fi
    if [ "$t" = RED ]; then u="$u UNEXPECTED=$tw:RED"; fi
    printf 'MATRIX %s decides=%s:%s twins=%s:%s others=%d/%d%s%s\n' "$m" "$dec" "$d" "$tw" "$t" "$g" "$tot" "${rd:+ red=${rd#,}}" "$u"
  fi
}

# Mutants, each on a COPY of the steps dir, each guarded by cmp -s so a sed that
# matched nothing reads DID NOT APPLY rather than as a scored mutant.
DISPO_CARRIERS=""
for f in "$STEPS"/*.md; do [ -n "$(disposition_set "$f")" ] && DISPO_CARRIERS="$DISPO_CARRIERS $(basename "$f")"; done
set -- $DISPO_CARRIERS
if [ "$#" -lt 2 ]; then
  bad "(h) mutants: fewer than two carriers derived ($#), nothing to mutate"
else
  MUT="$(mktemp -d)"
  for which in one all; do
    mkdir "$MUT/$which"; cp -R "$STEPS" "$MUT/$which/steps"
    MS="$MUT/$which/steps"
    applied=1
    for c in "$@"; do
      [ "$which" = one ] && [ "$c" != "$1" ] && continue
      sed 's| / `deferred-unfiled`)|)|' "$STEPS/$c" > "$MS/$c"
      cmp -s "$STEPS/$c" "$MS/$c" && applied=0
    done
    if [ "$applied" -eq 0 ]; then
      bad "(h) MUTANT drop-from-$which DID NOT APPLY"
    else
      rs_score "drop-from-$which" "${B_h:-0}" "(h) MUTANT drop-from-$which scored by h: " "$REQMD" "$GVMD" "$MS"
    fi
  done
  rm -rf "$MUT"
fi

# --- (i) subject axis in section 5; `###` mandate in 4(c) ---
if subject_axis_ok "$REQMD"; then
  ok "(i) requirements.md section 5 names $SUBJ_TOOL and no longer says it '$OLD_SENT'"; B_axis=1
else
  bad "(i) requirements.md: $I_WHY"
fi
if mandate_ok "$REQMD"; then
  ok "(i) requirements.md 4(c) carries the \`###\` subheading mandate"; B_mand=1
else
  bad "(i) requirements.md: $I_WHY"
fi
# Mutants on a COPY, cmp -s guarded. Each must fail ONLY its own predicate: the other
# predicate is asserted to still hold on the same mutant.
IMUT="$(mktemp -d)"
# restore-sentence: re-insert the old sentence directly after the `### 5. ` heading.
awk -v s="  Rule 28 \"Split dispatch\" $OLD_SENT, so the round keeps one agent per seat." \
  '{ print } index($0, "### 5. ") == 1 { print s }' "$REQMD" > "$IMUT/restore.md"
# drop-mandate: delete every line carrying the mandate sentence.
awk -v m="$MANDATE" '!index($0, m)' "$REQMD" > "$IMUT/drop.md"
for m in restore drop; do
  if cmp -s "$REQMD" "$IMUT/$m.md"; then bad "(i) MUTANT i-$m DID NOT APPLY"; continue; fi
  if [ "$m" = restore ]; then
    rs_score "i-$m" "${B_axis:-0}" "(i) MUTANT i-$m scored by its own predicate alone: " "$IMUT/$m.md" "$GVMD" "$STEPS"
  else
    rs_score "i-$m" "${B_mand:-0}" "(i) MUTANT i-$m scored by its own predicate alone: " "$IMUT/$m.md" "$GVMD" "$STEPS"
  fi
done
rm -rf "$IMUT"

# --- (j) the requirements series named at both Check 24 sites; B4's refusal in requirements.md ---
if [ -f "$GVMD" ]; then
  if j_check_ok "$GVMD"; then ok "(j) gate-validation.md's Check 24 invocation paragraph names $J_TOK"; B_jcheck=1; else bad "(j) gate-validation.md: $J_WHY"; fi
  if j_sweep_ok "$GVMD"; then ok "(j) gate-validation.md's post-planning sweep paragraph names $J_TOK"; B_jsweep=1; else bad "(j) gate-validation.md: $J_WHY"; fi
else
  bad "(j) gate-validation.md not found at $GVMD"
fi
if j_refuse_ok "$REQMD"; then ok "(j) requirements.md's series bullet says B4 refuses a --document merge of a subject file"; B_jrefuse=1; else bad "(j) requirements.md: $J_WHY"; fi
# Mutants on COPIES, cmp -s guarded, each keyed on its own predicate's REGION (every occurrence of
# the token inside it removed, so a third mention a later release adds cannot leave it vacuous),
# and each must fail ONLY its own predicate.
JMUT="$(mktemp -d)"
j_strip() { # <file> <start> <stop> <literal> -> the file with <literal> removed inside the region
  awk -v a="$2" -v b="$3" -v t="$4" '
    function strip(s,  i, o) { o = ""; while ((i = index(s, t)) > 0) { o = o substr(s, 1, i - 1); s = substr(s, i + length(t)) } return o s }
    !on && !done && index($0, a) { on = 1 }
    on && index($0, b) && !index($0, a) { on = 0; done = 1 }
    { print (on ? strip($0) : $0) }' "$1"
}
j_strip "$GVMD" "$J_CHECK_A" "$J_SWEEP_A" "$J_TOK" > "$JMUT/check.md"
j_strip "$GVMD" "$J_SWEEP_A" "$J_SWEEP_Z" "$J_TOK" > "$JMUT/sweep.md"
j_strip "$REQMD" "$J_REQ_A" "$J_REQ_Z" "$J_REFUSE_2" > "$JMUT/refuse.md"
for m in check sweep refuse; do
  case "$m" in
    check)  src="$GVMD";  rq="$REQMD";         gv="$JMUT/$m.md" ;;
    sweep)  src="$GVMD";  rq="$REQMD";         gv="$JMUT/$m.md" ;;
    refuse) src="$REQMD"; rq="$JMUT/$m.md";    gv="$GVMD" ;;
  esac
  if cmp -s "$src" "$JMUT/$m.md"; then bad "(j) MUTANT j-$m DID NOT APPLY"; continue; fi
  case "$m" in
    check)  rs_score "j-$m" "${B_jcheck:-0}"  "(j) MUTANT j-$m scored by its own predicate alone: " "$rq" "$gv" "$STEPS" ;;
    sweep)  rs_score "j-$m" "${B_jsweep:-0}"  "(j) MUTANT j-$m scored by its own predicate alone: " "$rq" "$gv" "$STEPS" ;;
    refuse) rs_score "j-$m" "${B_jrefuse:-0}" "(j) MUTANT j-$m scored by its own predicate alone: " "$rq" "$gv" "$STEPS" ;;
  esac
done
rm -rf "$JMUT"

# =====================================================================
# (k) (l) (m): Check 24's prose bound to validate-adversarial-convergence.sh. Moved here from
# check-24-adversarial-convergence (shards a and b), whose every other arm drives the validator over
# seeded series and reads none of this prose: keyed there, every edit to these step files re-ran a
# 4000-line fixture whose verdicts they cannot move. This fixture already keys the whole steps dir.
# =====================================================================
broken() { printf '  FAIL  %s\n' "$1" >&2; echo "requirements-step: FIXTURE BROKEN" >&2; exit 2; }
VALIDATOR=""
for cand in "$ROOT/core/scripts/validate-adversarial-convergence.sh" "$ROOT/scripts/ai-dlc/validate-adversarial-convergence.sh"; do
  [ -f "$cand" ] && { VALIDATOR="$cand"; break; }
done
[ -n "$VALIDATOR" ] || broken "validate-adversarial-convergence.sh is not under either layout from $ROOT"
case "$VALIDATOR" in
  */core/scripts/validate-adversarial-convergence.sh)   echo "HERMETIC-CONSUMED core/scripts/validate-adversarial-convergence.sh" ;;
  */scripts/ai-dlc/validate-adversarial-convergence.sh) echo "HERMETIC-CONSUMED scripts/ai-dlc/validate-adversarial-convergence.sh" ;;
esac

# --- (k) gate-validation.md teaches arm H's three repair-record labels to the lead --------------
# The same three labels the validator's repair_field reads and remediator.md's template writes
# (check-24 H-BIND joins those two). It is prose, so this is a token join, not a grammar one --
# but a label dropped from it is a label nobody is taught.
gv_miss=""
for lbl in disposition edit derivation; do
  grep -qF "\`$lbl:\`" "$GVMD" || gv_miss="$gv_miss $lbl"
done
gv_ctl="$(grep -c 'REPAIR-RECORD\|arm H' "$GVMD")" || gv_ctl=0
if [ "$gv_ctl" -eq 0 ]; then
  broken "$GVMD names no arm H at all, so the label check below reads a file that moved"
elif [ -n "$gv_miss" ]; then
  bad "(k) H-BIND: $GVMD teaches arm H but no longer names:$gv_miss (control: $gv_ctl arm-H mentions in the same file)"
else
  ok "(k) H-BIND: gate-validation.md names all 3 labels the reader reads"
fi

# --- (l) J3-MAP (BL-814): the deferral map is bound to the step files -------------------------
# Each J3_SUCCESSORS row `<stem>:<step>:<succ>:<ctx>` of the validator names a step file whose
# `nextStepFile:` is `./<succ>.md`, and a successor step file that writes `s<N>/<ctx>`.
# Self-probe first, both directions: a seeded row whose successor is wrong is refused.
J3_STEPS="$STEPS"
j3_bind() {  # $1 one map row -> 0 when it agrees with the step files
  local step succ ctx r="$1"
  r="${r#*:}"; step="${r%%:*}"; r="${r#*:}"; succ="${r%%:*}"; ctx="${r#*:}"
  [ -f "$J3_STEPS/$step.md" ] && [ -f "$J3_STEPS/$succ.md" ] || return 1
  grep -qx "nextStepFile: ./$succ.md" "$J3_STEPS/$step.md" || return 1
  grep -qF "s<N>/$ctx" "$J3_STEPS/$succ.md"
}
if ! j3_bind "coe:carry-over-evaluation:requirements:requirements-context.md" \
   || j3_bind "coe:carry-over-evaluation:architecture:architecture-context.md" \
   || j3_bind "requirements:requirements:architecture:requirements-context.md"; then
  bad "(l) J3-MAP: the binding self-probe did not discriminate (a true row, a wrong successor, a wrong digest)"
else
  j3_rows="$(awk '/^J3_SUCCESSORS="/ { on = 1; sub(/^J3_SUCCESSORS="/, "") } on { l = $0; e = sub(/"$/, "", l); print l; if (e) exit }' "$VALIDATOR")"
  j3_n=0; j3_off=""
  while IFS= read -r j3_r; do
    [ -n "$j3_r" ] || continue
    j3_n=$((j3_n + 1))
    j3_bind "$j3_r" || j3_off="$j3_off {$j3_r}"
  done <<J3EOF
$j3_rows
J3EOF
  if [ "$j3_n" -lt 2 ] || [ -n "$j3_off" ]; then
    bad "(l) J3-MAP: $j3_n J3_SUCCESSORS row(s) read; disagreeing with the step files:${j3_off:- none (too few rows read)}"
  else
    ok "(l) J3-MAP: $j3_n J3_SUCCESSORS rows each agree with nextStepFile: and the successor digest"
  fi
fi

# --- (m) BL-723: THE TEST-STRATEGY SERIES, bound from Check 24's own text to the program ---------
# stories-test-strategy.md §5 step 2 converges `test-strategy.md` through the native cycle, and
# Check 24 runs that series. Two documents name one prefix, and nothing but this arm joins them:
#   bind    the prefix is EXTRACTED from Check 24's section (`### 24.` to `### 25.`), never typed
#           here. `s<N>` resolves to a seeded sprint, the series is seeded at the prefix §5 names,
#           and the SHIPPING validator runs with Check 24's prefix: exit 0 on a terminal MET pass at
#           0 CRITICAL and 3 derived MAJOR, exit 1 with rung A on a verdict-less pass. An empty
#           extraction is a FAIL naming the token; a prefix §5 does not write matches nothing.
#   absent  §5 (`### 5.` to `### 6.`) names no bmad-review (nor its old name), against a
#           same-invocation control that bug-investigation.md does (control zero is BROKEN).
#   names   §5 names test-strategy-adversarial-p, "Adversarial review dispatch", "Adversarial repair
#           dispatch", and step 3's precondition (the highest pass "does not stamp
#           `verdict: EXIT_CONDITION_MET`" -> return to step 2), each once-unique in §5 today.
# Arm L's silence on this series is a CHARACTERIZATION (L keys on stories-adversarial-p only), not
# a kill. THE ABSENCE ARM IS WHY THE MUTANTS ARE COMMITTED: an absence passes for a span that read
# nothing, so the unmutated docs must score `ok ok ok` (the positive control) and each mutant must
# move exactly its own cell. Each validator start is an e2e cell of cells.decl, tagged by ts_eval.
TS_GATE="$GVMD"; TS_STEP="$STEPS/stories-test-strategy.md"; TS_CTL="$STEPS/bug-investigation.md"
[ -f "$TS_STEP" ] && [ -f "$TS_CTL" ] || broken "BL-723: stories-test-strategy.md and bug-investigation.md are not beside gate-validation.md in $STEPS"
TS_TOKEN='_bmad-output/planning-artifacts/s<N>/test-strategy-adversarial-p'
TS_RE='_bmad-output/planning-artifacts/s<N>/test-strategy[A-Za-z0-9_-]*-p'
# The one-shot runs under its current name, `bmad-review` (BMAD 6.11 renamed it from
# bmad-review-adversarial-general). The current name is a SUBSTRING of the old one, so one fixed-string
# count sees both spellings: the old-name mutant below still kills, and the new-form mutant beside it
# proves the absence arm reads the current call-site spelling too.
TS_BMAD='bmad-review'
ts_span() { awk -v s="$2" -v e="$3" 'index($0, s) == 1 { f = 1; next } index($0, e) == 1 { f = 0 } f' "$1"; }
ts_prefixes() { ts_span "$1" "$2" "$3" | grep -oE -- "$TS_RE" | sort -u; }
ts_count() { local n; n="$(ts_span "$1" "$2" "$3" | grep -cF -- "$4")" || n=0; printf '%s\n' "$n"; }
TSW="$(mktemp -d "${TMPDIR:-/tmp}/rs-tstrat.XXXXXX")" || broken "cannot create the test-strategy worlds dir"
trap 'rm -rf "$PROBE" "$TSW"' EXIT
mkdir -p "$TSW/probe" || broken "cannot create $TSW/probe"
# The validator's citation arm reads a transcript; none of these passes cites one, so one operator turn suffices.
TRANSCRIPT="$TSW/operator-transcript.jsonl"
printf '%s\n' '{"type":"user","timestamp":"2026-07-12T01:00:00Z","message":{"content":"/ai-dlc Sprint 9. Converge the test strategy."}}' > "$TRANSCRIPT"

# SELF-PROBE, BEFORE THE CORPUS, BOTH DIRECTIONS. The extractor reports the in-section token and
# stays quiet on the same grammar one section either side; the span count sees a §5 offender and
# stays quiet on one in §6.
printf '%s\n' '### 23. a' 'x `_bmad-output/planning-artifacts/s<N>/test-strategy-before-p` x' '### 24. b' \
  'y `_bmad-output/planning-artifacts/s<N>/test-strategy-adversarial-p` y' '### 25. c' \
  'z `_bmad-output/planning-artifacts/s<N>/test-strategy-after-p` z' > "$TSW/probe/hit.md"
printf '%s\n' '### 23. a' 'x `_bmad-output/planning-artifacts/s<N>/test-strategy-adversarial-p` x' '### 24. b' 'y' \
  '### 25. c' 'z `_bmad-output/planning-artifacts/s<N>/test-strategy-adversarial-p` z' > "$TSW/probe/miss.md"
printf '%s\n' '### 5. a' '2. `/bmad-review-adversarial-general` x' '### 6. b' > "$TSW/probe/s5hit.md"
printf '%s\n' '### 5. a' '2. converge' '### 6. b' '`/bmad-review-adversarial-general`' > "$TSW/probe/s5miss.md"
if [ "$(ts_prefixes "$TSW/probe/hit.md" '### 24.' '### 25.')" != "$TS_TOKEN" ] \
   || [ -n "$(ts_prefixes "$TSW/probe/miss.md" '### 24.' '### 25.')" ] \
   || [ "$(ts_count "$TSW/probe/s5hit.md" '### 5.' '### 6.' "$TS_BMAD")" != 1 ] \
   || [ "$(ts_count "$TSW/probe/s5miss.md" '### 5.' '### 6.' "$TS_BMAD")" != 0 ]; then
  broken "BL-723: the section extractor's self-probe did not discriminate (in-section hit, out-of-section near-miss)"
fi
echo "  [TS0] section extractor self-probe: reports the in-section token, silent one section either side"

ts_sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1; else sha256sum "$1" | cut -d' ' -f1; fi; }
ts_pass() { # <pass file> <artifact sha> <verdict line | ""> -- one unsharded pass, the shipped block shape
  { printf '# test-strategy -- adversarial pass 1\n\n<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: ai-dlc-adversary-review\n'
    printf 'mode: subagent\nlead_role: architect\ninvoked_at: 2026-07-12T02:00:00Z\ntool_use_id: toolu_fixture_ts1\n'
    printf 'artifact: test-strategy.md\nartifact_sha: %s\nfindings_critical: 0\nfindings_critical_prior_scope: 0\n' "$2"
    printf 'findings_major: 3\nfindings_major_underived: 0\nfindings_minor: 0\n'
    if [ -n "$3" ]; then printf '%s\n' "$3"; fi
    printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'; } > "$1"
}
# ts_eval <label> <gate doc> <step doc> -> TS_BIND TS_ABS TS_NAMES (ok|FAIL), each with a _WHY, and
# TS_MET_OUT (the MET run's output). Every cell is PRESENCE-shaped toward `ok`: a cell reads ok only
# when its program ran and said the specific thing, so a harness that ran nothing cannot score `ok ok ok`.
# The two validator starts carry FXCELL=ts-<slug>-met and ts-<slug>-unk, each a cells.decl e2e row.
ts_eval() {
  local s1 w g="$2" s="$3" n gp sp ng nsp sprint f sha out rc tok
  s1="$(printf '%s' "$1" | tr -c 'A-Za-z0-9_-' '_')"; w="$TSW/$s1"
  TS_BIND=ok; TS_ABS=ok; TS_NAMES=ok; TS_BIND_WHY=""; TS_ABS_WHY=""; TS_NAMES_WHY=""; TS_MET_OUT=""
  n="$(ts_span "$s" '### 5.' '### 6.' | grep -c .)" || n=0
  if [ "$n" -eq 0 ]; then
    TS_ABS=FAIL; TS_ABS_WHY="the §5 span (### 5. to ### 6.) of $(basename "$s") is empty -- an absence over nothing"
  else
    n="$(ts_count "$s" '### 5.' '### 6.' "$TS_BMAD")"
    [ "$n" -eq 0 ] || { TS_ABS=FAIL; TS_ABS_WHY="§5 names $TS_BMAD on $n line(s); the test strategy converges through the native cycle"; }
  fi
  for tok in 'test-strategy-adversarial-p' 'Adversarial review dispatch' 'Adversarial repair dispatch' \
             'does not stamp `verdict: EXIT_CONDITION_MET`'; do
    n="$(ts_count "$s" '### 5.' '### 6.' "$tok")"
    [ "$n" -gt 0 ] || { TS_NAMES=FAIL; TS_NAMES_WHY="$TS_NAMES_WHY §5 does not name \"$tok\";"; }
  done
  gp="$(ts_prefixes "$g" '### 24.' '### 25.')"; sp="$(ts_prefixes "$s" '### 5.' '### 6.')"
  ng="$(printf '%s' "$gp" | grep -c .)" || ng=0
  nsp="$(printf '%s' "$sp" | grep -c .)" || nsp=0
  if [ "$ng" -eq 0 ]; then
    TS_BIND=FAIL; TS_BIND_WHY="Check 24's section (### 24. to ### 25.) names no \`$TS_TOKEN\` -- the gate runs no test-strategy series"; return 0
  elif [ "$ng" -ne 1 ]; then
    TS_BIND=FAIL; TS_BIND_WHY="Check 24's section names $ng distinct test-strategy prefixes: $(echo $gp)"; return 0
  elif [ "$nsp" -ne 1 ]; then
    TS_BIND=FAIL; TS_BIND_WHY="§5 names $nsp distinct test-strategy series prefixes (want 1): $(echo $sp)"; return 0
  fi
  # s9 carries the terminal MET pass; s8 the same pass with no verdict: key (rung A). Each artifact_sha
  # is the sha of the test-strategy.md beside it, so nothing but the verdict separates them.
  for sprint in s9 s8; do
    f="$w/${sp/s<N>/$sprint}"
    mkdir -p "${f%/*}" || { TS_BIND=FAIL; TS_BIND_WHY="could not seed ${f%/*}"; return 0; }
    printf '# Sprint %s test strategy\n\nEvery acceptance criterion maps to a case.\n' "${sprint#s}" > "${f%/*}/test-strategy.md"
    sha="$(ts_sha "${f%/*}/test-strategy.md")"
    [ "${#sha}" -eq 64 ] || { TS_BIND=FAIL; TS_BIND_WHY="no sha256 of the seeded test-strategy.md"; return 0; }
    if [ "$sprint" = s9 ]; then ts_pass "${f}1.md" "$sha" 'verdict: EXIT_CONDITION_MET'; else ts_pass "${f}1.md" "$sha" ''; fi
  done
  TS_MET_OUT="$(FXCELL="ts-$s1-met" bash "$VALIDATOR" --series "$w/${gp/s<N>/s9}" --transcript "$TRANSCRIPT" --transcript-dir "$TSW" 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ]; then
    TS_BIND=FAIL; TS_BIND_WHY="Check 24's prefix over a terminal MET pass (0C, 3 derived MAJOR) exits $rc, want 0: $(printf '%s' "$TS_MET_OUT" | head -3 | tr '\n' ' ')"; return 0
  fi
  out="$(FXCELL="ts-$s1-unk" bash "$VALIDATOR" --series "$w/${gp/s<N>/s8}" --transcript "$TRANSCRIPT" --transcript-dir "$TSW" 2>&1)"; rc=$?
  if [ "$rc" -ne 1 ] || ! grep -qF -- "FAIL (A -- VOCABULARY)" <<<"$out" || ! grep -qF -- "declares no 'verdict:'" <<<"$out"; then
    TS_BIND=FAIL; TS_BIND_WHY="Check 24's prefix over a verdict-less pass exits $rc without rung A (want 1, FAIL (A -- VOCABULARY))"; return 0
  fi
  return 0
}

ts_eval shipped "$TS_GATE" "$TS_STEP"
if [ "$TS_BIND" = ok ]; then
  ok "(m) ts-bind: Check 24's own prefix runs the §5 series: MET exits 0, a verdict-less pass fails rung A"
else
  bad "(m) ts-bind: $TS_BIND_WHY"
fi
ts_ctl="$(grep -cF -- "$TS_BMAD" "$TS_CTL")" || ts_ctl=0
if [ "$ts_ctl" -eq 0 ]; then
  broken "BL-723 CONTROL: bug-investigation.md names $TS_BMAD 0 times -- the absence arm below cannot tell a clean §5 from a token no file carries"
elif [ "$TS_ABS" = ok ]; then
  ok "(m) ts-absent: §5 names no $TS_BMAD (control: bug-investigation.md names it $ts_ctl times)"
else
  bad "(m) ts-absent: $TS_ABS_WHY"
fi
if [ "$TS_NAMES" = ok ]; then
  ok "(m) ts-names: §5 names test-strategy-adversarial-p, both Adversarial dispatches and step 3's MET precondition"
else
  bad "(m) ts-names: ${TS_NAMES_WHY# }"
fi
# CHARACTERIZATION, not a kill: arm L keys on stories-adversarial-p and has nothing to say here.
if [ "$TS_BIND" = ok ]; then
  if grep -qi -- 'elicitation' <<<"$TS_MET_OUT"; then
    bad "(m) ts-arm-l-silent: arm L spoke about elicitation on the test-strategy series"
  else
    ok "(m) ts-arm-l-silent: arm L says nothing about elicitation on the test-strategy series"
  fi
fi

# --- MUTATION: one per cell the subject fix carries, each built as a COPY, cmp -s guarded ----------
#                               bind  absent  names
#   shipped (control)           ok    ok      ok
#   bmad restored in §5 step 2  ok    FAIL    ok   (old name, and again in the current lenses= form)
#   Check 24 drops the prefix   FAIL  ok      ok
#   step 3 precondition deleted ok    ok      FAIL
ts_score() { # <label> <gate doc> <step doc> <expected row>
  local got
  ts_eval "$1" "$2" "$3"; got="$TS_BIND $TS_ABS $TS_NAMES"
  if [ "$got" = "$4" ]; then
    ok "(m) $1 [$got]"
  else
    bad "(m) $1 got [$got] want [$4]"
  fi
}
ts_mut() { # <label> <python re> <replacement> <source doc> <copy> -> 0 when the mutation applied and is complete
  MUT_RE="$2" MUT_NEW="$3" python3 -c 'import os,re,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(re.sub(os.environ["MUT_RE"],os.environ["MUT_NEW"],s,count=1 if os.environ["MUT_NEW"] else 0))' "$4" "$5"
  if [ ! -s "$5" ] || cmp -s "$4" "$5"; then
    bad "(m) MUTATION $1 DID NOT APPLY -- the mutation matched nothing; this assertion proves nothing"
    return 1
  fi
  return 0
}
TSM="$TSW/mut"; mkdir -p "$TSM" || broken "cannot create $TSM"
ts_score "CONTROL ts unmutated" "$TS_GATE" "$TS_STEP" "ok ok ok"
# M1: the one-shot comes back as §5 step 2. Anchored on step 2's own opening, which must be unique.
ts_a="$(grep -c '^2\. \*\*Converge the test strategy\.\*\*' "$TS_STEP")" || ts_a=0
ts_actl="$(grep -c '^2\. \*\*Converge the test strategy no-such-line' "$TS_STEP")" || ts_actl=0
if [ "$ts_a" -ne 1 ] || [ "$ts_actl" -ne 0 ]; then
  bad "(m) MUTATION ts-anchor: step 2 anchor matches $ts_a line(s) (want 1; impossible-anchor control $ts_actl, want 0)"
else
  ok "(m) MUTATION ts-anchor: step 2 anchor is unique (impossible-anchor control: 0)"
fi
if ts_mut ts-bmad-restored '(?m)^2\. \*\*Converge the test strategy\.\*\*' \
     '2. `/bmad-review-adversarial-general` — review test strategy. **Converge the test strategy.**' \
     "$TS_STEP" "$TSM/stories-test-strategy.m1.md"; then
  ts_score "MUTATION ts-bmad-restored" "$TS_GATE" "$TSM/stories-test-strategy.m1.md" "ok FAIL ok"
fi
# M1b: the same step restored in the CURRENT call-site spelling, the directive form the rulebook now
# writes everywhere else. Without this the absence arm is proven only against the old name.
if ts_mut ts-bmad-restored-new '(?m)^2\. \*\*Converge the test strategy\.\*\*' \
     '2. `/bmad-review lenses=adversarial` — review test strategy. **Converge the test strategy.**' \
     "$TS_STEP" "$TSM/stories-test-strategy.m1b.md"; then
  ts_score "MUTATION ts-bmad-restored-new" "$TS_GATE" "$TSM/stories-test-strategy.m1b.md" "ok FAIL ok"
fi
# M2: Check 24 stops naming the series. Keyed on the extractor's own grammar over the whole file, and
# the copy must carry ZERO matches against a non-zero original.
if ts_mut ts-gate-prefix-dropped "$TS_RE" '' "$TS_GATE" "$TSM/gate-validation.m2.md"; then
  ts_m2="$(grep -cE -- "$TS_RE" "$TSM/gate-validation.m2.md")" || ts_m2=0
  ts_m2o="$(grep -cE -- "$TS_RE" "$TS_GATE")" || ts_m2o=0
  if [ "$ts_m2" -ne 0 ] || [ "$ts_m2o" -eq 0 ]; then
    bad "(m) MUTATION ts-gate-prefix-dropped: the copy keeps $ts_m2 match(es) (original $ts_m2o) -- an incomplete mutation"
  else
    ts_score "MUTATION ts-gate-prefix-dropped" "$TSM/gate-validation.m2.md" "$TS_STEP" "FAIL ok ok"
  fi
fi
# M3: step 3's precondition paragraph is deleted, from its own opening line up to the bind paragraph
# that follows it. The em dash is matched by `.` so the pattern stays ASCII. The copy must carry
# ZERO precondition stamps against exactly one in the original, or the mutation is incomplete.
TS_PRE='does not stamp `verdict: EXIT_CONDITION_MET`'
if ts_mut ts-precondition-deleted \
     '(?ms)^3\. \*\*Precondition . the step-2 series has exited\.\*\*.*?(?=^   \*\*Bind every strategy case)' '' \
     "$TS_STEP" "$TSM/stories-test-strategy.m3.md"; then
  ts_m3="$(grep -cF -- "$TS_PRE" "$TSM/stories-test-strategy.m3.md")" || ts_m3=0
  ts_m3o="$(grep -cF -- "$TS_PRE" "$TS_STEP")" || ts_m3o=0
  if [ "$ts_m3" -ne 0 ] || [ "$ts_m3o" -ne 1 ]; then
    bad "(m) MUTATION ts-precondition-deleted: the copy keeps $ts_m3 precondition stamp(s) (original $ts_m3o, want 1) -- an incomplete mutation"
  else
    ts_score "MUTATION ts-precondition-deleted" "$TS_GATE" "$TSM/stories-test-strategy.m3.md" "ok ok FAIL"
  fi
fi

# RULE 9: a plain run executes NO matrix-only cell. The deciding and twin cells write the same ledger, so
# an empty matrix count cannot come from a ledger nothing writes.
mx_only="$(mx_count mx)"; mx_ctl="$(mx_count dec)"
if [ "$MODE" = plain ]; then
  if [ "$mx_ctl" -eq 0 ]; then bad "rule-9: the matrix ledger control is EMPTY, so a zero count of matrix-only cells means nothing"
  elif [ "$mx_only" -ne 0 ]; then bad "rule-9: a plain run executed $mx_only matrix-only cell(s) -- the --matrix measurement leaked into the per-push run"
  else ok "rule-9: a plain run executed no matrix-only cell, while $mx_ctl deciding or twin cell(s) wrote the same ledger"; fi
else
  echo "MATRIX-SUMMARY $mx_only matrix-only cell(s) ran"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "PASS  requirements-step: all arms hold."
  exit 0
fi
echo "FAIL  requirements-step: $fails assertion(s) violated." >&2
exit 1
