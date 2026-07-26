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
printf '# PRD\n\n## FR Coverage Map\n\n- FR1 (CAP-1): Epic 1\n- FR2 (CAP-2): Epic 1\n' > "$ROOT/prd-ok.md"

# break (1): LR-S300-2 present in the memlog but no (capability) entry cites it
mk_spec "$ROOT/orphan-lr" '- (capability) CAP-1 realises LR-S300-1
- (capability) CAP-2 realises nothing in particular
- (note) LR-S300-2 was discussed and then not carried
'

# break (2): coverage map omits CAP-2
printf '# PRD\n\n## FR Coverage Map\n\n- FR1 (CAP-1): Epic 1\n' > "$ROOT/prd-missing-cap.md"

# break (2b): no coverage map heading at all -> DISARM, not skip
printf '# PRD\n\n## Functional Requirements\n\n- FR1: something\n' > "$ROOT/prd-no-map.md"

# zero-capability kernel -> DISARM
mkdir -p "$ROOT/no-caps"
printf '# SPEC\n\n## Capabilities\n\n- (none yet)\n' > "$ROOT/no-caps/SPEC.md"
printf -- '- (capability) LR-S300-1 noted, no CAP assigned yet\n' > "$ROOT/no-caps/.memlog.md"

# stories
printf -- '---\ncapabilities: [CAP-1, CAP-2]\n---\n# ok\n'  > "$ROOT/story-ok.md"
printf -- '---\ncapabilities: [CAP-9]\n---\n# dangling\n'   > "$ROOT/story-dangling.md"
printf -- '---\nstory_id: s1\n---\n# no capabilities field\n' > "$ROOT/story-nofield.md"

# borrowed verdicts
printf '{"findings":[{"class":"ad_fields","line":12}]}\n' > "$ROOT/spine-bad.json"
printf '{"findings":[]}\n'                                > "$ROOT/spine-ok.json"
printf 'Gate decision: FAIL\n'                            > "$ROOT/trace-fail.txt"
printf 'Gate decision: CONCERNS\n'                        > "$ROOT/trace-concerns.txt"
printf 'Gate decision: PASS\n'                            > "$ROOT/trace-pass.txt"
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
printf '# PRD\n\n## FR Coverage Map\n\n- FR1 (CAP-1): Epic 1\n- FR2 (CAP-2): Epic 1\n' > "$ROOT/prd-real.md"

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

printf '%s\n' "$ROOT"
