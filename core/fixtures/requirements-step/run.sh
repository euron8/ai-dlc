#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
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
