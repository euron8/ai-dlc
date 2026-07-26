#!/usr/bin/env bash
# Build a synthetic spec set: one healthy, plus one isolated break per join.
# Prints the root on stdout. Caller owns cleanup.
set -eu
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/spec-join-integrity.XXXXXX")"

mk_spec() { # <dir> <memlog-body>
  mkdir -p "$1"
  printf '# SPEC\n\n## Capabilities\n\n- **CAP-1** intent: resolve the venue. success: WHEN a rebalance leg executes, THE router SHALL be the venue.\n- **CAP-2** intent: bound the sweep. success: WHILE a position is immature, THE sweeper SHALL NOT act.\n' > "$1/SPEC.md"
  printf '%s' "$2" > "$1/.memlog.md"
}

# Memlog entries use bmad-spec's REAL typed form, `- (<type>) <text>`. An invented
# shape here is worse than no fixture: the first version of this seed used a
# `capability | ...` pipe format that exists nowhere, which is exactly why it could
# not expose the self-report defect the `real-severed` payload below pins.

# healthy: both LRs cited by a (capability) entry, both CAPs in the coverage map
mk_spec "$ROOT/ok" '- (decision) pinned units to BLOCKS
- (capability) CAP-1 realises LR-S300-1: venue == router, verified live
- (capability) CAP-2 realises LR-S300-2: maturity floor in blocks
- (event) pass 1 coherence PASS
- (event) pass 2 preservation PASS
'
cat > "$ROOT/prd-ok.md" <<'PRDOK'
# PRD

## Functional Requirements

- **FR-S300-1 (CAP-1) (<- LR-S300-1) - router venue.** body
- **FR-S300-2 (CAP-2) (<- LR-S300-2) - sweep floor.** body

### FR Coverage Map

FR1: Epic 1 - router venue
FR2: Epic 1 - sweep floor
PRDOK

# break (1): LR-S300-2 present in the memlog but no (capability) entry cites it
mk_spec "$ROOT/orphan-lr" '- (capability) CAP-1 realises LR-S300-1
- (capability) CAP-2 realises nothing in particular
- (note) LR-S300-2 was discussed and then not carried
'

# break (2): no FR entry cites CAP-2
cat > "$ROOT/prd-missing-cap.md" <<'PRDMISS'
# PRD

## Functional Requirements

- **FR-S300-1 (CAP-1) (<- LR-S300-1) - router venue.** body
- **FR-S300-2 (<- LR-S300-2) - sweep floor, no capability cited.** body

### FR Coverage Map

FR1: Epic 1 - router venue
FR2: Epic 1 - sweep floor
PRDMISS

# OVER-FIRE PIN: a PRD whose coverage map is BMAD's literal template output --
# `FR1: Epic 1 - <desc>`, no capability token anywhere -- must still PASS, because
# the CAP citation lives on the FR ENTRY. Requiring it in the map failed every
# capability against a correct map.
cat > "$ROOT/prd-real-map.md" <<'PRDREAL'
# PRD

## Functional Requirements

- **FR-S300-1 (CAP-1) (<- LR-S300-1) - router venue.** body
- **FR-S300-2 (CAP-2) (<- LR-S300-2) - sweep floor.** body

### FR Coverage Map

FR1: Epic 1 - [Brief description]
FR2: Epic 1 - [Brief description]
PRDREAL

# no FR identifiers at all -> DISARM, not skip
printf '# PRD\n\n## Scope\n\n- some prose, no requirement ids\n' > "$ROOT/prd-no-fr.md"

# zero-capability kernel -> DISARM
mkdir -p "$ROOT/no-caps"
printf '# SPEC\n\n## Capabilities\n\n- (none yet)\n' > "$ROOT/no-caps/SPEC.md"
printf -- '- (capability) LR-S300-1 noted, no CAP assigned yet\n' > "$ROOT/no-caps/.memlog.md"

# stories
printf -- '---\ncapabilities: [CAP-1, CAP-2]\n---\n# ok\n'  > "$ROOT/story-ok.md"
printf -- '---\ncapabilities: [CAP-9]\n---\n# dangling\n'   > "$ROOT/story-dangling.md"
printf -- '---\nstory_id: s1\n---\n# no capabilities field\n' > "$ROOT/story-nofield.md"

# borrowed verdicts.
# The lint payloads are REAL `lint_spine.py` output, captured by running it. Its
# envelope is {"ok","spine","total_findings","by_severity","findings":[{"category",
# "severity","detail","location"}]} -- the key is "category", and there are FOUR
# values: placeholder, ad_fields, ad_id, version_pin. An earlier version of this
# fixture invented {"class": ...} with no envelope at all, so a check that reads the
# envelope could only DISARM on it. An invented shape pins nothing.
cat > "$ROOT/spine-ok.json" <<'LINTOK'
{
  "ok": true,
  "spine": "ARCHITECTURE-SPINE.md",
  "total_findings": 0,
  "by_severity": {},
  "findings": []
}
LINTOK
cat > "$ROOT/spine-bad.json" <<'LINTBAD'
{
  "ok": false,
  "spine": "ARCHITECTURE-SPINE.md",
  "total_findings": 4,
  "by_severity": {
    "high": 4
  },
  "findings": [
    {
      "category": "placeholder",
      "severity": "high",
      "detail": "placeholder marker: 'TBD'",
      "location": "ARCHITECTURE-SPINE.md (line 5)"
    },
    {
      "category": "ad_fields",
      "severity": "high",
      "detail": "AD-1 missing required field(s): prevents, rule",
      "location": "ARCHITECTURE-SPINE.md AD-1 (line 7)"
    },
    {
      "category": "ad_id",
      "severity": "high",
      "detail": "AD-1 id reused (also at line 7)",
      "location": "ARCHITECTURE-SPINE.md AD-1 (line 9)"
    },
    {
      "category": "ad_id",
      "severity": "high",
      "detail": "AD-1 is non-monotonic (follows AD-1); ids must ascend and never renumber",
      "location": "ARCHITECTURE-SPINE.md AD-1 (line 9)"
    }
  ]
}
LINTBAD
cat > "$ROOT/spine-low.json" <<'LINTLOW'
{
  "ok": false,
  "spine": "ARCHITECTURE-SPINE.md",
  "total_findings": 1,
  "by_severity": {
    "low": 1
  },
  "findings": [
    {
      "category": "placeholder",
      "severity": "low",
      "detail": "possible unfilled template token (verify): '{{maybe_token}}'",
      "location": "ARCHITECTURE-SPINE.md (line 3)"
    }
  ]
}
LINTLOW
# Trace payloads are bmad-testarch-trace's real `gate-decision.json` shape: the
# decision lives in `gate_status`, and the same file carries p0/p1/overall statuses
# plus a prose rationale. `trace-concerns.json` below is the false-positive pin --
# gate_status CONCERNS while p1_status is FAIL. A whole-file grep for FAIL fails a
# gate the tool passed.
mk_trace() { # <file> <gate_status> <p1_status> <rationale>
  cat > "$1" <<TRACEJSON
{
  "schema_version": "0.1.0",
  "collection_status": "complete",
  "gate_basis": "requirements",
  "gate_status": "$2",
  "rationale": "$4",
  "p0_status": "PASS",
  "p1_status": "$3",
  "overall_status": "$2"
}
TRACEJSON
}
mk_trace "$ROOT/trace-fail.json"     FAIL     FAIL "P0 coverage is 74% (minimum 100%)."
mk_trace "$ROOT/trace-concerns.json" CONCERNS FAIL "P0 is 100% but P1 coverage is 82% (target 90%)."
mk_trace "$ROOT/trace-pass.json"     PASS     PASS "P0 coverage is 100% and overall is 94%."
# NOT_EVALUATED is deliberately EXCLUDED from gate-decision.json by the tool, so the
# realistic shape of that state is a file with no gate_status at all -> DISARM.
printf '{"schema_version":"0.1.0","collection_status":"partial"}\n' > "$ROOT/trace-notevaluated.json"
# --- REAL bmad-spec SHAPE, captured from an actual headless run ----------------
# The payloads above are hand-authored and minimal. This one reproduces what
# bmad-spec really writes, and it exists for one reason: its Self-Validate appends
# an `(event)` verdict that ENUMERATES the LR -> CAP mapping this join checks. A
# predicate that scans every memlog line mentioning an LR is satisfied by that
# summary, so it reports PASS on a spec whose capability entry was severed. That is
# a self-declared verdict being read as evidence, and it is invisible to a
# hand-authored memlog that contains only capability lines.
mkdir -p "$ROOT/real"
cat > "$ROOT/real/SPEC.md" <<'REALSPEC'
---
id: SPEC-s300-pilot
companions: [locked-requirements.md]
sources: []
---

# S300 pilot

## Capabilities

- **CAP-1**
  - **intent:** the gated-path leg reaches its counterparty through the router
  - **success:** WHEN a rebalance leg executes on the gated path, THE system SHALL report the swap router as the venue that executed that leg.
- **CAP-2**
  - **intent:** a position survives sweep consideration until it has earned its lifetime
  - **success:** IF a gated-pool position has been held for fewer than 43200 blocks, THEN THE sweeper SHALL leave that position unswept.
REALSPEC
cat > "$ROOT/real/.memlog.md" <<'REALLOG'
---
topic: S300 pilot
---

- (note) input is an in-chat operator scope carrying a verbatim LOCKED_REQUIREMENTS block
- (decision) headless mode: express distill, no elicitation
- (capability) CAP-1 realises LR-S300-1: the gated-path leg routes through the router
- (constraint) neither routing knob is read on the gated path
- (capability) CAP-2 realises LR-S300-2: a position below MIN_PASSIVE_LIFETIME is left unswept
- (constraint) MIN_PASSIVE_LIFETIME is 43200 and its unit is BLOCKS
- (event) pass 1 coherence PASS: rules 1-6 and 8 hold
- (event) pass 2 preservation PASS: LR-S300-1 -> CAP-1 + routing-knob constraint, LR-S300-2 -> CAP-2 + BLOCKS constraint
- (event) spec finalized
REALLOG
cat > "$ROOT/prd-real.md" <<'PRDR'
# PRD

## Functional Requirements

- **FR-S300-1 (CAP-1) (<- LR-S300-1) - router venue.** body
- **FR-S300-2 (CAP-2) (<- LR-S300-2) - sweep floor.** body

### FR Coverage Map

FR1: Epic 1 - [Brief description]
FR2: Epic 1 - [Brief description]
PRDR

# Same spec with CAP-2's capability entry SEVERED. The (event) verdict line is left
# intact, still naming "LR-S300-2 -> CAP-2". A correct join FAILS here; the naive
# one passes on the strength of that summary alone.
cp -R "$ROOT/real" "$ROOT/real-severed"
sed -i.bak 's/^- (capability) CAP-2 realises LR-S300-2/- (note) LR-S300-2 was discussed and not carried/' \
  "$ROOT/real-severed/.memlog.md" 2>/dev/null \
  || sed -i '' 's/^- (capability) CAP-2 realises LR-S300-2/- (note) LR-S300-2 was discussed and not carried/' \
       "$ROOT/real-severed/.memlog.md"
rm -f "$ROOT/real-severed/.memlog.md.bak"

# All capability entries retyped: the join has no entries to read -> DISARM.
cp -R "$ROOT/real" "$ROOT/real-untyped"
sed -i.bak 's/^- (capability)/- (note)/' "$ROOT/real-untyped/.memlog.md" 2>/dev/null \
  || sed -i '' 's/^- (capability)/- (note)/' "$ROOT/real-untyped/.memlog.md"
rm -f "$ROOT/real-untyped/.memlog.md.bak"

printf -- '---\ncapabilities: [CAP-1, CAP-2]\n---\n# real story\n' > "$ROOT/story-real.md"


# --- REAL bmad-architecture spine shape ----------------------------------------
# `### AD-<n> — <title>` then `- **Binds:** <what>` / `- **Prevents:**` / `- **Rule:**`.
# Binds names CAPABILITIES (a real generated spine reads `- **Binds:** CAP-1`), and
# `all` binds every capability. The chain this check documents asserted the CAP -> AD
# leg without checking it; a leg claimed and unenforced is a rule with no mechanism.
cat > "$ROOT/spine-all.md" <<'SPINEALL'
# Spine
## Decisions
### AD-1 — Dependency direction is inward
- **Binds:** all
- **Prevents:** a policy decision leaking into an adapter
- **Rule:** the core imports nothing from an adapter
SPINEALL
cat > "$ROOT/spine-cap1only.md" <<'SPINE1'
# Spine
## Decisions
### AD-1 — router resolver owns venue choice
- **Binds:** CAP-1
- **Prevents:** two paths resolving a venue from different inputs
- **Rule:** one core resolver maps routing config to a venue decision
SPINE1

printf '%s\n' "$ROOT"
