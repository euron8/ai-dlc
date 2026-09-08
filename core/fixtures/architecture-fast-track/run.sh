#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# architecture-fast-track — assert the architecture step's declared-no-impact
# fast-track (release 0.532.0) is wired end to end: the intensity bullet names
# the predicate and the impact file at ANY intensity (not lightweight-only),
# the predicate is EXTRACTED from architecture.md and EXECUTED against seeds
# rather than paraphrased, gate-validation.md Check 20 names the same file and
# gate-log token, requirements.md still writes what the predicate reads, and
# the token is byte-identical between the two files.
#
# Ships to consumers: the subject (installed step files under
# `.claude/skills/ai-dlc/steps/`) is present there. TWO LAYOUTS, BOTH ROOTED AT
# THIS FILE, AND NO VERSION-MARKER WALK: this fixture SHIPS, and an installed
# consumer has no VERSION file at its root, so a walk up for one resolves to
# nothing there and the fixture would exit 2 on every consumer push (I106).
# Three levels up from this file is the project root in BOTH layouts. If
# `architecture.md` is absent in the resolved steps dir this prints
# `SKIP architecture-fast-track: subject not installed` and exits 0 — but only
# after every arm's self-probe has run against a mktemp tree, so the SKIP is
# never printed by a fixture that could not fire.
#
# Arms, each proven against a seeded mktemp offender (fires) and a seeded
# near-miss (stays quiet) BEFORE the corpus is read:
#   (a) architecture.md intensity bullet names architecture-impact.md and
#       architecture_impact: none, and does not read as the old
#       lightweight-only form.
#   (b) the FAST_TRACK_PREDICATE awk line is extracted and EXECUTED against a
#       seed table, including a probe that a deliberately loose predicate
#       (bare grep -q) fails the none-for-now seed the plan names by name.
#   (c) gate-validation.md Check 20 body names architecture-impact.md, the
#       token fast_track: architecture-impact-none, and architecture.md.
#   (d) requirements.md §4 still writes architecture-impact.md and the
#       literal architecture_impact: none (producer/consumer bind).
#   (e) the fast_track: token is byte-identical between architecture.md and
#       gate-validation.md Check 20.
#
# Usage: run.sh
# Exit:  0 = every assertion holds (or subject not installed), 1 = a
#        regression, 2 = fixture broken (a probe could not be proven in
#        either direction).
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# --- resolve the project root: three levels up from this file in BOTH
# layouts, never a VERSION-marker walk (I106) ---
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

# --- arm (a) probe: intensity bullet grammar ---
# Extract from the line matching ^- \*\*intensity:\*\* through the line
# immediately before the next ^- \*\* bullet.
intensity_bullet() { # <file>
  awk '
    /^- \*\*intensity:\*\*/ { grab = 1; print; next }
    grab && /^- \*\*/ { exit }
    grab { print }
  ' "$1"
}
bullet_is_widened() { # <file>
  local body
  body="$(intensity_bullet "$1")" || return 1
  [ -n "$body" ] || return 1
  grep -qF 'architecture-impact.md' <<<"$body" || return 1
  grep -qF 'architecture_impact: none' <<<"$body" || return 1
  return 0
}
# The offender text is the exact pre-fix bullet, embedded verbatim (never
# read from git in the shipped fixture — a consumer has no such ref).
cat > "$PROBE/arch-offender.md" <<'EOF'
- **adversarial focus:** security, scalability, coupling, single points of
  failure, backward compatibility, migration risk, integration seams, and
  over-engineering (Rule 26: mechanism beyond requirements, parallel paths,
  unjustified guards — propose removals as findings).
- **intensity:** on `validation_intensity == lightweight` AND the Step 2
  assessment is NO CHANGES NEEDED, skip this cycle entirely (Rule 5 fast-track)
  and proceed to Step 5; otherwise run the full cycle.
- **`Seam D` label:** `architecture adversarial pass <N>`.
EOF
cat > "$PROBE/arch-nearmiss.md" <<'EOF'
- **adversarial focus:** security, scalability, coupling, single points of
  failure, backward compatibility, migration risk, integration seams, and
  over-engineering (Rule 26: mechanism beyond requirements, parallel paths,
  unjustified guards — propose removals as findings).
- **intensity:** when the Step 2 assessment is NO CHANGES NEEDED AND EITHER
  `validation_intensity == lightweight` OR the declared-no-impact predicate below
  holds, skip this cycle entirely (Rule 5 fast-track) and proceed to Step 5;
  otherwise run the full cycle. The declared-no-impact arm applies at EVERY
  intensity: it keys on this sprint's
  `_bmad-output/planning-artifacts/s<N>/architecture-impact.md`. The predicate is
  line-exact — every `architecture_impact:` line reads exactly
  `architecture_impact: none`.
- **`Seam D` label:** `architecture adversarial pass <N>`.
EOF
if ! bullet_is_widened "$PROBE/arch-offender.md"; then
  probe_ok "(a) architecture.md offender (pre-fix lightweight-only bullet) flagged as not widened"
else
  probe_bad "(a)" "offender probe unexpectedly read as widened"
fi
if bullet_is_widened "$PROBE/arch-nearmiss.md"; then
  probe_ok "(a) architecture.md near-miss (widened bullet) passes"
else
  probe_bad "(a)" "near-miss probe failed to pass a well-formed bullet"
fi

# --- arm (b) probe: predicate extraction + execution grammar ---
extract_predicate() { # <file>
  awk '
    /<!-- FAST_TRACK_PREDICATE -->/ { m = NR; next }
    m && NR == m + 2 { print; exit }
  ' "$1"
}
cat > "$PROBE/pred-src.md" <<'EOF'
  the predicate holds when this exits 0 (a fixture extracts and runs this line, so
  it is the predicate, not a paraphrase of it):
  <!-- FAST_TRACK_PREDICATE -->
  ```
  awk '/architecture_impact:/{n++; if ($0 !~ /architecture_impact: none$/) b++} END{exit !(n>=1 && b==0)}' "$f"
  ```
  When the fast-track is taken on this arm, the Step 5 gate log entry records
EOF
P_PROBE="$(extract_predicate "$PROBE/pred-src.md")"
if [ -n "$P_PROBE" ] && grep -qF 'architecture_impact' <<<"$P_PROBE"; then
  probe_ok "(b) predicate extraction grammar returns a non-empty awk line naming architecture_impact"
else
  probe_bad "(b)" "extraction returned empty or missing architecture_impact"
fi
# Seed table: build files and assert the extracted predicate's exit code.
mkdir -p "$PROBE/seeds"
printf -- '- FR-S1-1: architecture_impact: none\n- FR-S1-2: architecture_impact: none\n' > "$PROBE/seeds/both-none"
printf -- '- FR-S1-1: architecture_impact: none\n- FR-S1-2: architecture_impact: none-for-now\n' > "$PROBE/seeds/none-for-now"
printf -- 'architecture_impact: None\n' > "$PROBE/seeds/capitalized"
printf -- 'architecture_impact: none \n' > "$PROBE/seeds/trailing-space"
printf -- 'architecture_impact: adds a queue\n' > "$PROBE/seeds/adds-a-queue"
: > "$PROBE/seeds/empty"
printf -- 'no relevant line here\n' > "$PROBE/seeds/no-line"
run_predicate_seed() { # <predicate-awk-src> <seed-file-or-nonexistent-path>
  local prog="$1" seed="$2"
  f="$seed" bash -c "$prog" 2>/dev/null
}
probe_predicate_table() { # <label> <predicate-awk-src>
  local label="$1" prog="$2" ok=1
  run_predicate_seed "$prog" "$PROBE/seeds/both-none";       [ $? -eq 0 ] || ok=0
  run_predicate_seed "$prog" "$PROBE/seeds/none-for-now";    [ $? -ne 0 ] || ok=0
  run_predicate_seed "$prog" "$PROBE/seeds/capitalized";     [ $? -ne 0 ] || ok=0
  run_predicate_seed "$prog" "$PROBE/seeds/trailing-space";  [ $? -ne 0 ] || ok=0
  run_predicate_seed "$prog" "$PROBE/seeds/adds-a-queue";    [ $? -ne 0 ] || ok=0
  run_predicate_seed "$prog" "$PROBE/seeds/empty";           [ $? -ne 0 ] || ok=0
  run_predicate_seed "$prog" "$PROBE/seeds/no-line";         [ $? -ne 0 ] || ok=0
  run_predicate_seed "$prog" "$PROBE/seeds/does-not-exist";  [ $? -ne 0 ] || ok=0
  [ "$ok" -eq 1 ]
}
if probe_predicate_table "correct" "$P_PROBE"; then
  probe_ok "(b) extracted predicate scores the full seed table correctly on a probe fixture"
else
  probe_bad "(b)" "extracted predicate did not score the probe seed table as expected"
fi
# Prove the harness can actually SEE a wrong predicate: a deliberately loose
# grep-based predicate must FAIL the none-for-now seed (a substring match
# would wrongly pass it). This is what stops arm (b) from being a check that
# cannot fire.
LOOSE_PREDICATE='grep -q "architecture_impact: none" "$f"'
if run_predicate_seed "$LOOSE_PREDICATE" "$PROBE/seeds/none-for-now"; then
  probe_ok "(b) loose grep-based predicate (deliberately wrong) WRONGLY passes none-for-now, proving the table can catch a bad predicate"
else
  probe_bad "(b)" "loose predicate unexpectedly also failed none-for-now -- the seed table cannot discriminate a bad predicate"
fi

# --- arm (c) probe: Check 20 body grammar ---
check20_body() { # <file>
  awk '
    /^### 20\./ { grab = 1; print; next }
    grab && /^### / { exit }
    grab { print }
  ' "$1"
}
check20_is_widened() { # <file>
  local body
  body="$(check20_body "$1")" || return 1
  [ -n "$body" ] || return 1
  grep -qF 'architecture-impact.md' <<<"$body" || return 1
  grep -qF 'fast_track: architecture-impact-none' <<<"$body" || return 1
  grep -qF 'architecture.md' <<<"$body" || return 1
  return 0
}
cat > "$PROBE/gv-offender.md" <<'EOF'
### 20. Validation-intensity compliance (all planning gates).
<!-- CHECK_LOADED: 20 -->

**Scope.** Fires at every planning-phase gate. Skips for implementation,
deploy-validate, and retro gates.

An architecture gate that reaches a NO-CHANGES-NEEDED assessment MAY
skip the validation cycle (fast-track). The gate log entry MUST record
`validation_intensity: <level>` and `minimum_met: true|false`. The check
FAILS if the declared minimum was not met.

### 21. Test-strategy deliverable presence (sprint-review gate).
Runs at the sprint-review gate.
EOF
cat > "$PROBE/gv-nearmiss.md" <<'EOF'
### 20. Validation-intensity compliance (all planning gates).
<!-- CHECK_LOADED: 20 -->

**Scope.** Fires at every planning-phase gate. Skips for implementation,
deploy-validate, and retro gates.

An architecture gate that reaches a NO-CHANGES-NEEDED assessment MAY
skip the validation cycle (fast-track) under `lightweight`, or at ANY
intensity when every `architecture_impact:` line of this sprint's
`_bmad-output/planning-artifacts/s<N>/architecture-impact.md` reads
exactly `architecture_impact: none` — `architecture.md` §4 carries the
predicate, and this check RUNS it against that file. The gate log entry
MUST record `validation_intensity: <level>` and `minimum_met: true|false`,
and when the fast-track was taken on declared no-impact,
`fast_track: architecture-impact-none` plus the impact file's path.

### 21. Test-strategy deliverable presence (sprint-review gate).
Runs at the sprint-review gate.
EOF
if ! check20_is_widened "$PROBE/gv-offender.md"; then
  probe_ok "(c) gate-validation.md offender (pre-fix Check 20) flagged as not widened"
else
  probe_bad "(c)" "offender probe unexpectedly read as widened"
fi
if check20_is_widened "$PROBE/gv-nearmiss.md"; then
  probe_ok "(c) gate-validation.md near-miss (widened Check 20) passes"
else
  probe_bad "(c)" "near-miss probe failed to pass a well-formed Check 20"
fi
# Section-range trap: a getline-once reader would miss a body spanning many
# lines before the terminator. Prove the range grammar reaches a token placed
# deep in the body, just before the ### 21 boundary.
cat > "$PROBE/gv-deep.md" <<'EOF'
### 20. Validation-intensity compliance (all planning gates).
line 1
line 2
line 3
line 4
DEEP_TOKEN_NEAR_BOUNDARY architecture-impact.md fast_track: architecture-impact-none architecture.md
### 21. Test-strategy deliverable presence (sprint-review gate).
EOF
if check20_is_widened "$PROBE/gv-deep.md"; then
  probe_ok "(c) section-range grammar reaches a token placed just before the ### 21 boundary"
else
  probe_bad "(c)" "section-range grammar missed a token near the boundary (getline-once trap)"
fi

# --- arm (d) probe: requirements.md producer/consumer bind ---
cat > "$PROBE/req-offender.md" <<'EOF'
Some unrelated §4 text with no mention of any impact record.
EOF
cat > "$PROBE/req-nearmiss.md" <<'EOF'
Write `architecture-impact.md`. Each FR line: `architecture_impact: none` or a
one-line naming of the impact.
EOF
if ! grep -qF 'architecture-impact.md' "$PROBE/req-offender.md" \
  && ! grep -qF 'architecture_impact: none' "$PROBE/req-offender.md"; then
  probe_ok "(d) requirements.md offender missing both tokens, flagged"
else
  probe_bad "(d)" "offender probe unexpectedly matched"
fi
if grep -qF 'architecture-impact.md' "$PROBE/req-nearmiss.md" \
  && grep -qF 'architecture_impact: none' "$PROBE/req-nearmiss.md"; then
  probe_ok "(d) requirements.md near-miss passes"
else
  probe_bad "(d)" "near-miss probe failed to pass a well-formed file"
fi

# --- arm (e) probe: matching fast_track token grammar ---
extract_token() { # <file>
  local line
  line="$(grep -oE 'fast_track: [a-z-]+' "$1" | head -1)" || return 1
  [ -n "$line" ] || return 1
  printf '%s\n' "$line"
}
cat > "$PROBE/tok-a-match.md" <<'EOF'
records `fast_track: architecture-impact-none` beside the level.
EOF
cat > "$PROBE/tok-b-match.md" <<'EOF'
and `fast_track: architecture-impact-none` plus the impact file's path.
EOF
cat > "$PROBE/tok-a-mismatch.md" <<'EOF'
records `fast_track: architecture-impact-none` beside the level.
EOF
cat > "$PROBE/tok-b-mismatch.md" <<'EOF'
and `fast_track: no-impact-declared` plus the impact file's path.
EOF
TA="$(extract_token "$PROBE/tok-a-match.md")"
TB="$(extract_token "$PROBE/tok-b-match.md")"
if [ -n "$TA" ] && [ -n "$TB" ] && [ "$TA" = "$TB" ]; then
  probe_ok "(e) near-miss: identical tokens across two files compare equal"
else
  probe_bad "(e)" "near-miss probe: identical tokens did not compare equal"
fi
TA="$(extract_token "$PROBE/tok-a-mismatch.md")"
TB="$(extract_token "$PROBE/tok-b-mismatch.md")"
if [ -n "$TA" ] && [ -n "$TB" ] && [ "$TA" != "$TB" ]; then
  probe_ok "(e) offender: differing tokens across two files correctly flagged as unequal"
else
  probe_bad "(e)" "offender probe: differing tokens did not flag as unequal"
fi

echo "architecture-fast-track: $probes self-probe assertion(s), $fails failed"
if [ "$fails" -gt 0 ]; then
  echo "FIXTURE ERROR: a self-probe could not discriminate offender from near-miss; corpus arms below would not be trustworthy." >&2
  exit 2
fi
echo

# =====================================================================
# CORPUS. If architecture.md is not installed, print SKIP and exit 0 —
# but only now, after every probe above has proven it can fire.
# =====================================================================
ARCHMD="$STEPS/architecture.md"
if [ ! -f "$ARCHMD" ]; then
  echo "SKIP architecture-fast-track: subject not installed"
  exit 0
fi

GVMD="$STEPS/gate-validation.md"
REQMD="$STEPS/requirements.md"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }

echo "architecture-fast-track: running arms against the corpus"
echo

# --- (a) architecture.md intensity bullet ---
if bullet_is_widened "$ARCHMD"; then
  ok "(a) architecture.md intensity bullet names architecture-impact.md and architecture_impact: none"
else
  bad "(a) architecture.md intensity bullet is not widened (missing impact-file token or literal)"
fi

# --- (b) extract and execute the real predicate ---
P="$(extract_predicate "$ARCHMD")"
if [ -n "$P" ] && grep -qF 'architecture_impact' <<<"$P"; then
  ok "(b) extracted a non-empty predicate line naming architecture_impact from architecture.md"
  if probe_predicate_table "shipped" "$P"; then
    ok "(b) the shipped predicate scores the full seed table (none/none-for-now/None/trailing-space/other/empty/no-line/missing-file) correctly"
  else
    bad "(b) the shipped predicate does not score the seed table correctly"
  fi
else
  bad "(b) could not extract a non-empty architecture_impact predicate line from architecture.md"
fi

# --- (c) gate-validation.md Check 20 body ---
if [ -f "$GVMD" ]; then
  if check20_is_widened "$GVMD"; then
    ok "(c) gate-validation.md Check 20 names architecture-impact.md, the fast_track token, and architecture.md"
  else
    bad "(c) gate-validation.md Check 20 is missing one of: architecture-impact.md, the fast_track token, architecture.md"
  fi
else
  bad "(c) gate-validation.md not found at $GVMD"
fi

# --- (d) requirements.md still writes what the predicate reads ---
if [ -f "$REQMD" ]; then
  if grep -qF 'architecture-impact.md' "$REQMD"; then
    ok "(d) requirements.md names architecture-impact.md"
  else
    bad "(d) requirements.md does not name architecture-impact.md"
  fi
  if grep -qF 'architecture_impact: none' "$REQMD"; then
    ok "(d) requirements.md carries the literal architecture_impact: none"
  else
    bad "(d) requirements.md does not carry the literal architecture_impact: none"
  fi
else
  bad "(d) requirements.md not found at $REQMD"
fi

# --- (e) the fast_track token matches between architecture.md and Check 20 ---
if [ -f "$GVMD" ]; then
  TOK_ARCH="$(extract_token "$ARCHMD")" || TOK_ARCH=""
  TOK_GV_BODY="$(check20_body "$GVMD" | grep -oE 'fast_track: [a-z-]+' | head -1)" || TOK_GV_BODY=""
  if [ -n "$TOK_ARCH" ] && [ -n "$TOK_GV_BODY" ] && [ "$TOK_ARCH" = "$TOK_GV_BODY" ]; then
    ok "(e) fast_track token is byte-identical between architecture.md and gate-validation.md Check 20 ($TOK_ARCH)"
  else
    bad "(e) fast_track token differs or is missing between architecture.md ('$TOK_ARCH') and Check 20 ('$TOK_GV_BODY')"
  fi
else
  bad "(e) gate-validation.md not found at $GVMD"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "PASS  architecture-fast-track: all arms hold."
  exit 0
fi
echo "FAIL  architecture-fast-track: $fails assertion(s) violated." >&2
exit 1
