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
#
# Usage: run.sh
# Exit:  0 = every assertion holds (or subject not installed), 1 = a regression,
#        2 = fixture broken (a probe could not be proven in either direction).
set -uo pipefail

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
  DRAFTS_LINE="$(grep -E '^DRAFTS=' "$DRAFTSTAMPS" | head -1)"
  if grep -qF 'requirements-context' <<<"$DRAFTS_LINE"; then
    ok "(g) validate-draft-stamps.sh DRAFTS= contains requirements-context"
  else
    bad "(g) validate-draft-stamps.sh DRAFTS= does not contain requirements-context"
  fi
else
  bad "(g) validate-draft-stamps.sh not found"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "PASS  requirements-step: all arms hold."
  exit 0
fi
echo "FAIL  requirements-step: $fails assertion(s) violated." >&2
exit 1
