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

# --- the capabilities: TRICHOTOMY (v0.254.0) ----------------------------------
# `story-nofield.md` above is the KEY-ABSENT arm. These are the other two. All three
# used to print the SAME sentence -- "carries no 'capabilities:' frontmatter field" --
# and for these two that sentence is factually false: the field is right there.
printf -- '---\ncapabilities: []\n---\n# empty, unexplained\n' > "$ROOT/story-empty.md"
printf -- '---\ncapabilities: []\ncapabilities_rationale: pipeline-infra only; implements no spec capability\n---\n# empty, declared\n' > "$ROOT/story-empty-declared.md"

# --- baselines (v0.254.0) -----------------------------------------------------
# LIVE: names the orphan-lr case's actual failure, so it suppresses and stays honest.
printf '# pre-existing at adoption\nlr:LR-S300-2\n' > "$ROOT/baseline-live.txt"
# STALE: a key nothing in this run produces. The failure it excused is gone, and the
# entry would silently suppress the next real instance of that id.
printf 'lr:LR-S300-2\nfr:CAP-404-GONE\n'            > "$ROOT/baseline-stale.txt"

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


# --- REAL bmad-prd FR SHAPE -----------------------------------------------------
# bmad-prd renders each requirement as an H4 HEADING, numbered globally
# `#### FR-<n>: <short capability name>` -- not a list item, not sprint-scoped -- and
# carries NO capability or locked-requirement token: `CAP-`, `LR-` and `SPEC.md` have
# ZERO occurrences anywhere in that skill, and it instructs "skip traceability
# matrices". So a PRD it authors can never satisfy join (2) on its own; the PM adds the
# citation in a second pass, and these two payloads pin both sides of that.
cat > "$ROOT/prd-bmad-raw.md" <<'PRDRAW'
# PRD

## Features and Functional Requirements

### Gated-path routing

#### FR-1: Gated-path leg routes through the swap router

The gated rebalance leg reaches its counterparty through the swap router.

#### FR-2: Executed leg reports its venue

The venue that executed a leg is readable off the leg.

#### FR-3: Young position survives the sweeper

A position held fewer than 43200 blocks is left unswept.
PRDRAW
sed -e 's/^#### FR-1:/#### FR-1 (CAP-1):/' \
    -e 's/^#### FR-2:/#### FR-2 (CAP-1):/' \
    -e 's/^#### FR-3:/#### FR-3 (CAP-2):/' \
    "$ROOT/prd-bmad-raw.md" > "$ROOT/prd-bmad-enriched.md"


# --- QUALIFIED memlog tags: the PRODUCER's optional qualifier -------------------
# memlog.py's `cmd_append` builds one tag out of two optional parts:
#   label = args.type;  if args.by: label = f"{label} by {args.by}";  tag = f"({label}) "
# so `(capability)` and `(capability by bmad-spec)` are the SAME entry type, and which
# one appears is decided PER APPEND by whether the caller passed --by. Nothing in the
# producer makes the qualifier stable across a memlog, let alone across sprints.
#
# Captured from the reference consumer's 58 real memlogs, not from the reader's
# accept-set: 57 `(capability)`, 19 `(capability by bmad-spec)`, 7
# `(capability by pm-escalated)`. Three sprints are bare throughout and one (s302) is
# qualified throughout. Every payload above this line is BARE, which is why this
# fixture was green under a predicate that required `)` immediately after the type --
# a predicate that reads ZERO capability entries out of s302 and DISARMS at exit 2,
# which sits ABOVE every join in the check.
#
# HAND-WRITTEN, NOT DERIVED BY sed FROM $ROOT/real. The two mutators above are anchored
# on the literal `(capability)`; a qualified corpus built by sed-mutating the bare one
# matches nothing, produces a copy identical to its source, and asserts nothing.

# (a) MUST PASS. Both observed qualified forms, mixed with a bare entry the way the
# corpus mixes them across sprints. Kernel, PRD and story are the `real` set's.
mkdir -p "$ROOT/real-qualified"
cp "$ROOT/real/SPEC.md" "$ROOT/real-qualified/SPEC.md"
cat > "$ROOT/real-qualified/.memlog.md" <<'QUALLOG'
---
topic: S300 pilot
---

- (note by bmad-spec) input is an in-chat operator scope carrying a verbatim LOCKED_REQUIREMENTS block
- (decision by bmad-spec) headless mode: express distill, no elicitation
- (capability by bmad-spec) CAP-1 realises LR-S300-1: the gated-path leg routes through the router
- (constraint by bmad-spec) neither routing knob is read on the gated path
- (capability by pm-escalated) CAP-2 realises LR-S300-2: a position below MIN_PASSIVE_LIFETIME is left unswept
- (event by bmad-spec) pass 2 preservation PASS: LR-S300-1 -> CAP-1, LR-S300-2 -> CAP-2
- (event by bmad-spec) spec finalized
QUALLOG

# (b) MUST FAIL AT THE JOIN, NOT DISARM. Qualified entries are present -- so the
# emptiness test is satisfied -- but LR-S300-2 is named only by a `(note ...)`. This is
# the arm that separates "the widened predicate FEEDS join (1)" from "the widened
# predicate merely stops the DISARM firing": a widening that collected the entries and
# then failed to hand them to the loop would pass (a) and exit 0 here.
mkdir -p "$ROOT/real-qualified-orphan"
cp "$ROOT/real/SPEC.md" "$ROOT/real-qualified-orphan/SPEC.md"
cat > "$ROOT/real-qualified-orphan/.memlog.md" <<'QUALORPHAN'
---
topic: S300 pilot
---

- (capability by bmad-spec) CAP-1 realises LR-S300-1: the gated-path leg routes through the router
- (capability by pm-escalated) CAP-2 was carried without a locked requirement behind it
- (note by bmad-spec) LR-S300-2 was discussed and then not carried
- (event by bmad-spec) pass 2 preservation PASS: LR-S300-1 -> CAP-1, LR-S300-2 -> CAP-2
QUALORPHAN

# (c) MUST STILL DISARM. Every tag is qualified and NONE is a capability. A widening
# that dropped the type anchor -- `\([^)]*\)` -- reads the `(event ...)` verdict line as
# a capability entry, closes join (1) on the spec's own self-report, and exits 0. This
# corpus is what makes that vacuity visible; the mutation control below fires it.
mkdir -p "$ROOT/real-qualified-noncap"
cp "$ROOT/real/SPEC.md" "$ROOT/real-qualified-noncap/SPEC.md"
cat > "$ROOT/real-qualified-noncap/.memlog.md" <<'QUALNONCAP'
---
topic: S300 pilot
---

- (note by bmad-spec) input is an in-chat operator scope carrying a verbatim LOCKED_REQUIREMENTS block
- (decision by bmad-spec) headless mode: express distill, no elicitation
- (constraint by bmad-spec) neither routing knob is read on the gated path
- (event by bmad-spec) pass 2 preservation PASS: LR-S300-1 -> CAP-1, LR-S300-2 -> CAP-2
- (event by bmad-spec) spec finalized
QUALNONCAP

# (d) MUST STILL DISARM. `(capability-review ...)` is a DIFFERENT type that shares a
# prefix with this one. The widening's optional group opens with `[[:space:]]`, and that
# character is the whole of what keeps a hyphenated neighbour out; without it the group
# is `([^)]*)?` and this corpus is read as capability entries. `--type capability-review`
# is expressible by the producer (memlog.py enforces no vocabulary -- "the host skill
# names the vocabulary; the script does not"), and no such type appears in the reference
# corpus today, so this arm pins a boundary rather than reproducing a captured shape.
mkdir -p "$ROOT/real-hyphen-type"
cp "$ROOT/real/SPEC.md" "$ROOT/real-hyphen-type/SPEC.md"
cat > "$ROOT/real-hyphen-type/.memlog.md" <<'HYPHENLOG'
---
topic: S300 pilot
---

- (capability-review by lead) CAP-1 realises LR-S300-1: the gated-path leg routes through the router
- (capability-review by lead) CAP-2 realises LR-S300-2: a position below MIN_PASSIVE_LIFETIME is left unswept
- (event by bmad-spec) spec finalized
HYPHENLOG

# (e) MUST PASS. `--by` is free text and the reference corpus proves it: one real entry
# reads `(correction by lead, CAP-10 pointer clause at 01:57:27Z)` -- commas, digits and
# a colon inside the qualifier, through the same code path that builds a capability tag.
# `[^)]*` must carry all of it.
#
# The ORDINAL form `(capability 2 by lead)` gets NO arm. It has zero occurrences in the
# 58 real memlogs, and the predicate has no `by`-specific structure, so it lands in the
# same equivalence class as (e) and would discriminate nothing.
mkdir -p "$ROOT/real-qualifier-rich"
cp "$ROOT/real/SPEC.md" "$ROOT/real-qualifier-rich/SPEC.md"
cat > "$ROOT/real-qualifier-rich/.memlog.md" <<'RICHLOG'
---
topic: S300 pilot
---

- (capability by lead, CAP-1 pointer clause at 01:57:27Z) CAP-1 realises LR-S300-1: the gated-path leg routes through the router
- (capability by remediator, adversarial pass 1 + pass 2) CAP-2 realises LR-S300-2: a position below MIN_PASSIVE_LIFETIME is left unswept
- (event by bmad-spec) spec finalized
RICHLOG


# --- ALPHABETIC CAPABILITY SUFFIXES, and what a parser that cannot spell an id does -
# CAPTURED FROM A REAL KERNEL, not from the reader's accept-set:
# `_bmad-output/specs/s304/collect-now-and-rebalance-pct/SPEC.md` in the reference
# consumer defines `CAP-1a` in full -- H3 bullet, intent, two EARS success criteria and
# a note -- and cites it in its own coverage paragraph. `bmad-spec` never renumbers, so
# a capability discovered between two existing ones is spelled with a suffix; the suffix
# IS the no-renumbering promise being kept.
#
# CAP-1a IS ALSO A GAP CLOSURE WITH NO LOCKED REQUIREMENT BEHIND IT, and that too is the
# real shape: that kernel's own prose says `CAP-1a`, `CAP-6`, `CAP-8` and `CAP-11`..`CAP-16`
# "are gap closures authored during discovery §5's validation cycle" and that two of them
# are "named or entailed by NO entry inside the LOCKED_REQUIREMENTS block". Join (1) runs
# LR -> CAP, so a capability with no LR is legal and closes nothing; seeding it that way
# is what keeps the grammar mutant below from ALSO firing join (1), which would make its
# assertion an entangled one.
mkdir -p "$ROOT/real-suffixed"
cat > "$ROOT/real-suffixed/SPEC.md" <<'SUFFIXSPEC'
---
id: SPEC-s304-collect-now-and-rebalance-pct
companions: [locked-requirements.md]
sources: []
---

# S304 collect now and rebalance pct

## Coverage

`CAP-1a`, together with the other gap closures, was authored during discovery's validation
cycle rather than lifted from the `LR-S304-*` range.

## Capabilities

- **CAP-1** — a collect skips what is not there instead of failing
  - **intent:** an operator collecting fees gets the fees from every defined position that actually exists on-chain, rather than losing the whole collect because one defined position has none.
  - **success:** `WHEN a fee collection runs across defined positions of which one or more has no resolvable on-chain position, THE rebalancer SHALL collect from every position that does resolve and SHALL complete the run rather than failing it.`

- **CAP-1a** — a collect with nothing to collect ends cleanly
  - **intent:** a collect run where NO defined layer has a resolvable on-chain position ends in a named, non-crashing state instead of inheriting an unstated one.
  - **success:** `IF a fee collection resolves no layer with an on-chain position at all, THEN THE rebalancer SHALL complete the run as a successful no-op reporting zero collected amounts and every layer skipped.`
  - **note:** the second criterion is the operator half of the first, and it is not inherited from `CAP-2`.

- **CAP-2** — a partial collect reaches a visible end state
  - **intent:** a partial outcome is legible to the operator rather than rendered as a success.
  - **success:** `WHILE a collect run is partial, THE dashboard SHALL name the layers whose collect reverted.`
SUFFIXSPEC
cat > "$ROOT/real-suffixed/.memlog.md" <<'SUFFIXLOG'
---
topic: S304 collect now and rebalance pct
---

- (note) input is an in-chat operator scope carrying a verbatim LOCKED_REQUIREMENTS block
- (capability) CAP-1 realises LR-S304-0: a collect skips what is not there instead of failing
- (capability) CAP-1a is a gap closure authored during discovery's validation cycle; it is named or entailed by no entry inside the locked block
- (capability by pm-escalated) CAP-2 realises LR-S304-9: a partial collect reaches a visible end state
- (event) pass 2 preservation PASS: LR-S304-0 -> CAP-1, LR-S304-9 -> CAP-2
SUFFIXLOG
cat > "$ROOT/prd-suffixed.md" <<'PRDSUF'
# PRD

## Functional Requirements

- **FR-S304-1 (CAP-1) (<- LR-S304-0) - skip what is not there.** body
- **FR-S304-2 (CAP-1a) (<- gap closure) - the empty collect ends cleanly.** body
- **FR-S304-3 (CAP-2) (<- LR-S304-9) - partial end state.** body
PRDSUF
# join (2) with the suffixed id UNCITED. Under the old grammar CAP-1a is not in the
# capability set at all, so this PRD reads as complete and the run is SILENT.
cat > "$ROOT/prd-suffixed-nocap1a.md" <<'PRDSUFNO'
# PRD

## Functional Requirements

- **FR-S304-1 (CAP-1) (<- LR-S304-0) - skip what is not there.** body
- **FR-S304-3 (CAP-2) (<- LR-S304-9) - partial end state.** body
PRDSUFNO
# DISTINCTNESS. `CAP-1a` is cited and `CAP-1` is not. The per-capability boundary class
# is the whole of what keeps `CAP-1` from matching inside `CAP-1a` and reporting coverage
# the PRD does not have.
cat > "$ROOT/prd-suffixed-only1a.md" <<'PRDSUFONLY'
# PRD

## Functional Requirements

- **FR-S304-2 (CAP-1a) (<- gap closure) - the empty collect ends cleanly.** body
- **FR-S304-3 (CAP-2) (<- LR-S304-9) - partial end state.** body
PRDSUFONLY
printf -- '---\ncapabilities: [CAP-1, CAP-1a, CAP-2]\n---\n# suffixed story\n'  > "$ROOT/story-suffixed.md"
printf -- '---\ncapabilities: [CAP-1, CAP-2]\n---\n# suffixed story, no CAP-1a\n' > "$ROOT/story-suffixed-no1a.md"
cat > "$ROOT/spine-suffixed.md" <<'SPINESUF'
# Architecture spine

## Invariants & Rules

### AD-1 — collect skip semantics (== ADR-S304-1)

- **Binds:** FR-S304-1, FR-S304-2; `CAP-1`, `CAP-1a`.
- **Prevents:** an unresolvable layer aborting the whole collect run
- **Rule:** the per-layer collect loop skips an unresolved layer and records the skip

### AD-2 — partial outcome rendering (== ADR-S304-2)

- **Binds:** FR-S304-3; `CAP-2`.
- **Prevents:** a partial run rendering through the complete branch
- **Rule:** the terminal state is chosen from the per-layer outcome tally
SPINESUF
cat > "$ROOT/spine-suffixed-no1a.md" <<'SPINESUFNO'
# Architecture spine

## Invariants & Rules

### AD-1 — collect skip semantics (== ADR-S304-1)

- **Binds:** FR-S304-1; `CAP-1`.
- **Prevents:** an unresolvable layer aborting the whole collect run
- **Rule:** the per-layer collect loop skips an unresolved layer and records the skip

### AD-2 — partial outcome rendering (== ADR-S304-2)

- **Binds:** FR-S304-3; `CAP-2`.
- **Prevents:** a partial run rendering through the complete branch
- **Rule:** the terminal state is chosen from the per-layer outcome tally
SPINESUFNO

# RESIDUE. A token this check cannot spell IN FULL must DISARM rather than leave the set
# in silence. `CAP-1ab` and `CAP-1A` are the two shapes one character outside the accepted
# grammar; both sit beside two ids the grammar does parse, so the zero-capability DISARM
# above cannot be what catches them.
mkdir -p "$ROOT/cap-residue" "$ROOT/cap-residue-upper" "$ROOT/cap-template"
cp "$ROOT/ok/SPEC.md" "$ROOT/cap-residue/SPEC.md";        cp "$ROOT/ok/.memlog.md" "$ROOT/cap-residue/.memlog.md"
cp "$ROOT/ok/SPEC.md" "$ROOT/cap-residue-upper/SPEC.md";  cp "$ROOT/ok/.memlog.md" "$ROOT/cap-residue-upper/.memlog.md"
cp "$ROOT/ok/SPEC.md" "$ROOT/cap-template/SPEC.md";       cp "$ROOT/ok/.memlog.md" "$ROOT/cap-template/.memlog.md"
printf -- '- **CAP-1ab** intent: an id carrying a suffix this grammar cannot spell in full.\n' >> "$ROOT/cap-residue/SPEC.md"
printf -- '- **CAP-1A** intent: an id carrying an UPPERCASE suffix, one character outside the accepted form.\n' >> "$ROOT/cap-residue-upper/SPEC.md"
# TEMPLATE TOKENS ARE NOT RESIDUE. Both spellings appear in this repo's own prose and in
# BMAD's; the residue class requires a DIGIT after the hyphen, which is the whole of what
# separates a real id from a placeholder.
printf -- '\nA capability is written CAP-<n> in the skill text and CAP-N in prose; neither is an id.\n' >> "$ROOT/cap-template/SPEC.md"

# --- join (3) citations, reachable by --baseline (v0.388.0) --------------------
# `story-dangling.md` cites CAP-9. The FINE key names the file AND the citation; the
# COARSE `story:` key names only the file and must not reach this arm -- one line
# excusing a missing field must not also excuse every dangling citation in that file.
printf 'story-cap:story-dangling.md:CAP-9\n' > "$ROOT/baseline-story-cap.txt"
printf 'story:story-dangling.md\n'           > "$ROOT/baseline-story-coarse.txt"

# --- WRAPPED `- **Binds:**` bullets, from the real spine ------------------------
# Captured from `_bmad-output/planning-artifacts/architecture/architecture-graph-2026-08-19/
# ARCHITECTURE-SPINE.md` at graph 74aff8ed2: of its five Binds bullets, three WRAP, and
# the capabilities of the widest one (AD-5) sit entirely on continuation lines while its
# marker line names only source files. One AD (AD-4) carries its capability on the marker
# line itself. Both shapes are reproduced here.
cat > "$ROOT/spine-wrapped.md" <<'SPINEWRAP'
# Architecture spine

## Invariants & Rules

### AD-1 — Pre-burn viability guard placement and post-settlement fail-safe (== ADR-S304-4)

- **Binds:** FR-S300-18; `CAP-1`.
- **Prevents:** (a) a second pre-burn value-estimation call site alongside the existing one; (b) a
  non-viable settled mint being reported as an ordinary success.
- **Rule:** the pre-burn guard extends the existing estimate call result rather than adding a new
  estimation pass.

### AD-2 — Rebalance-branch discriminator, validation, refusals, and selector reuse (== ADR-S304-5)

- **Binds:** `RebalancerPage.jsx`'s rebalance-branch selector wiring; `handle_rebalance_trigger`'s
  request parsing and arm selector (`api.py:4636`); `CAP-2`.
- **Prevents:** every percentage-selected rebalance being unconditionally 400-refused by the
  pre-existing stale-view-create detector.
- **Rule:** the reused selector's priced preview shows the fuller post-swap basis or an explicit
  not-yet-known state.
SPINEWRAP
# NEAR MISS. `CAP-2` appears ONLY inside a `- **Prevents:**` bullet's continuation, which
# is exactly where the real spine mentions `CAP-6`, `CAP-8` and six others without binding
# them. A fold that stopped at the list item keeps this unbound; a grep widened to "any
# line carrying a CAP token" closes the join on text that binds nothing.
cat > "$ROOT/spine-neighbour.md" <<'SPINENEIGH'
# Architecture spine

## Invariants & Rules

### AD-1 — router resolver owns venue choice (== ADR-S300-1)

- **Binds:** FR-S300-18; `CAP-1`.
- **Prevents:** (a) an unvalidated percentage reaching a balance read or cap computation — same
  shape as the existing create-arm check (`CAP-2`). The distinct-field construction structurally
  eliminates that cell.
- **Rule:** one core resolver maps routing config to a venue decision.
SPINENEIGH

# --- the THIRD disposition: NO-CAPABILITY -------------------------------------
# THE CASE IS REAL AND ITS SPELLING IS NOT. The reference consumer carries exactly one
# such requirement -- `LR-S304-6`, the WHAT/HOW meta-clause -- and records it as
# `- (decision) LR-S304-6 disposition: it maps to NO capability, and that is correct
# rather than a gap` (`s304/collect-now-and-rebalance-pct/.memlog.md:39`), with the FAIL
# it still produces carried in `spec-join-baseline.txt` under a paragraph of comment. The
# `(disposition)` TYPE and the literal `NO-CAPABILITY` token are this check's vocabulary,
# not a captured producer spelling: `disposition` has ZERO occurrences across the
# consumer's 58 memlogs (the observed types are constraint, event, capability, decision,
# note, question, direction, assumption, correction, resolution, change). The bullet-plus-
# parenthesised-type shape IS the producer's, from memlog.py's `cmd_append`, and the
# qualifier is optional there -- so `(disposition by lead)` is the same entry type.
#
# The three near-misses below are therefore not hypothetical: `disp-wrongtype` is the
# exact entry the reference consumer has on disk today.
mkdir -p "$ROOT/disp-ok" "$ROOT/disp-qualified" "$ROOT/disp-noreason" "$ROOT/disp-wrongtype" "$ROOT/disp-untyped"
for d in disp-ok disp-qualified disp-noreason disp-wrongtype disp-untyped; do
  cp "$ROOT/ok/SPEC.md" "$ROOT/$d/SPEC.md"
done
DISP_HEAD='- (note) input is an in-chat operator scope carrying a verbatim LOCKED_REQUIREMENTS block
- (capability) CAP-1 realises LR-S304-0: a collect skips what is not there
- (capability) CAP-2 realises LR-S304-9: a partial collect reaches a visible end state
'
DISP_TAIL='- (event) pass 2 preservation PASS: LR-S304-0 -> CAP-1, LR-S304-9 -> CAP-2
'
DISP_REASON='the WHAT/HOW meta-clause governing how the other locked entries are read; it asserts no behaviour of its own, so it carries no AC-bearing element and there is nothing for a capability success criterion to render in EARS'
printf '%s- (disposition) LR-S304-6 NO-CAPABILITY %s\n%s' \
  "$DISP_HEAD" "$DISP_REASON" "$DISP_TAIL" > "$ROOT/disp-ok/.memlog.md"
printf '%s- (disposition by lead) LR-S304-6 NO-CAPABILITY %s\n%s' \
  "$DISP_HEAD" "$DISP_REASON" "$DISP_TAIL" > "$ROOT/disp-qualified/.memlog.md"
# near miss 1: the token with nothing behind it -- an unexplained blank, which is what the
# empty `capabilities:` arm already refuses to accept from a story.
printf '%s- (disposition) LR-S304-6 NO-CAPABILITY\n%s' \
  "$DISP_HEAD" "$DISP_TAIL" > "$ROOT/disp-noreason/.memlog.md"
# near miss 2: THE SHAPE THE CONSUMER ACTUALLY HAS. Right requirement, right reason,
# wrong entry type -- and a type anchor is the only thing that can tell them apart.
printf '%s- (decision) LR-S304-6 NO-CAPABILITY %s\n%s' \
  "$DISP_HEAD" "$DISP_REASON" "$DISP_TAIL" > "$ROOT/disp-wrongtype/.memlog.md"
# near miss 3: an untyped bullet. Prose that merely mentions the id and the token is what
# the `(capability)` join already refuses to read; the hatch must refuse it too.
printf '%s- LR-S304-6 NO-CAPABILITY %s\n%s' \
  "$DISP_HEAD" "$DISP_REASON" "$DISP_TAIL" > "$ROOT/disp-untyped/.memlog.md"



# --- the THIRD disposition ONE JOIN OVER: `- **No-AD:**` -----------------------
# THE BULLET GRAMMAR IS THE SPINE'S OWN. bmad-architecture renders every AD field as
# `- **<Key>:** <value>` -- `Binds`, `Prevents`, `Rule` in the real spine at graph
# 74aff8ed2 -- and those bullets WRAP. `No-AD` is a new key in that existing grammar, so
# the wrapped payload below is not a hypothetical: three of that spine's five field
# bullets carry part of their value on a continuation line.
cat > "$ROOT/spine-noad.md" <<'SPINENOAD'
# Architecture spine

## Invariants & Rules

### AD-1 — router resolver owns venue choice (== ADR-S300-1)

- **Binds:** FR-S300-1; `CAP-1`.
- **Prevents:** two paths resolving a venue from different inputs
- **Rule:** one core resolver maps routing config to a venue decision

## Capabilities carrying no AD

- **No-AD:** `CAP-2` — REASON: the maturity floor extends the sweep ladder AD-1 already establishes and introduces no new mechanism class.
SPINENOAD
# The SAME disposition, WRAPPED, with `REASON:` on the continuation line. This is what
# makes the fold ONE fold serving two readers rather than a Binds-only convenience.
cat > "$ROOT/spine-noad-wrapped.md" <<'SPINENOADW'
# Architecture spine

## Invariants & Rules

### AD-1 — router resolver owns venue choice (== ADR-S300-1)

- **Binds:** FR-S300-1; `CAP-1`.
- **Prevents:** two paths resolving a venue from different inputs
- **Rule:** one core resolver maps routing config to a venue decision

## Capabilities carrying no AD

- **No-AD:**
  `CAP-2` — REASON: the maturity floor extends the sweep ladder AD-1 already establishes and
  introduces no new mechanism class, so there is no invariant for an AD to carry.
SPINENOADW
# NEAR MISS: the id is dispositioned and no reason is given. An unexplained blank is what
# the empty `capabilities:` arm already refuses; this must refuse it too.
cat > "$ROOT/spine-noad-noreason.md" <<'SPINENOADNR'
# Architecture spine

## Invariants & Rules

### AD-1 — router resolver owns venue choice (== ADR-S300-1)

- **Binds:** FR-S300-1; `CAP-1`.
- **Prevents:** two paths resolving a venue from different inputs
- **Rule:** one core resolver maps routing config to a venue decision

## Capabilities carrying no AD

- **No-AD:** `CAP-2`
SPINENOADNR
# NEAR MISS: the decision written as PROSE, which is the form the real consumer already
# used and which no join could read. Same words, no bullet marker.
cat > "$ROOT/spine-noad-prose.md" <<'SPINENOADP'
# Architecture spine

## Invariants & Rules

### AD-1 — router resolver owns venue choice (== ADR-S300-1)

- **Binds:** FR-S300-1; `CAP-1`.
- **Prevents:** two paths resolving a venue from different inputs
- **Rule:** one core resolver maps routing config to a venue decision

No-AD: `CAP-2` — REASON: the maturity floor extends the sweep ladder AD-1 already
establishes and introduces no new mechanism class.
SPINENOADP
# NEAR MISS: every capability dispositioned and NOT ONE AD in the file. The disposition
# reader must not be able to satisfy the DISARM that sits above the whole join.
cat > "$ROOT/spine-noad-only.md" <<'SPINENOADO'
# Architecture spine

## Capabilities carrying no AD

- **No-AD:** `CAP-1` — REASON: extends an existing pattern.
- **No-AD:** `CAP-2` — REASON: extends an existing pattern.
SPINENOADO


# --- a No-AD disposition that outlived its cause ------------------------------
# The same shape the `--baseline` ledger's second arm exists for: an excuse whose cause
# is gone still sits there exempting a capability. Three states, and the third is the one
# a spine-wide `Binds: all` reaches, where the per-capability loop never runs at all.
cat > "$ROOT/spine-noad-stale.md" <<'SPINENOADS'
# Architecture spine

## Invariants & Rules

### AD-1 — router resolver owns venue choice (== ADR-S300-1)

- **Binds:** FR-S300-1; `CAP-1`, `CAP-2`.
- **Prevents:** two paths resolving a venue from different inputs
- **Rule:** one core resolver maps routing config to a venue decision

## Capabilities carrying no AD

- **No-AD:** `CAP-2` — REASON: the maturity floor extends the sweep ladder AD-1 already establishes.
SPINENOADS
cat > "$ROOT/spine-noad-unknown.md" <<'SPINENOADU'
# Architecture spine

## Invariants & Rules

### AD-1 — router resolver owns venue choice (== ADR-S300-1)

- **Binds:** FR-S300-1; `CAP-1`, `CAP-2`.
- **Prevents:** two paths resolving a venue from different inputs
- **Rule:** one core resolver maps routing config to a venue decision

## Capabilities carrying no AD

- **No-AD:** `CAP-9` — REASON: an id this kernel does not define, so the excuse excuses nothing.
SPINENOADU
cat > "$ROOT/spine-noad-bindsall.md" <<'SPINENOADB'
# Architecture spine

## Invariants & Rules

### AD-1 — Dependency direction is inward (== ADR-S300-1)

- **Binds:** all
- **Prevents:** a policy decision leaking into an adapter
- **Rule:** the core imports nothing from an adapter

## Capabilities carrying no AD

- **No-AD:** `CAP-2` — REASON: the maturity floor extends an existing pattern.
SPINENOADB


# --- No-AD bullets that dispose NOTHING, and the id segment --------------------
# A bullet with no reason is reported AS THE MALFORMED BULLET IT IS rather than only
# through the capability's own FAIL, so this payload names a capability an AD DOES bind:
# the ad: arm cannot fire and the malformed-bullet arm is the only thing left that can.
cat > "$ROOT/spine-noad-malformed-bound.md" <<'SPINEMB'
# Architecture spine

## Invariants & Rules

### AD-1 — router resolver owns venue choice (== ADR-S300-1)

- **Binds:** FR-S300-1; `CAP-1`, `CAP-2`.
- **Prevents:** two paths resolving a venue from different inputs
- **Rule:** one core resolver maps routing config to a venue decision

## Capabilities carrying no AD

- **No-AD:** `CAP-2`
SPINEMB
# `REASON:` PRESENT AND EMPTY. The id segment parses, so the bullet is well-formed enough
# to name a capability, and the only thing standing between it and an excuse is the
# requirement that a reason carry text. Two guards read that requirement, and both must
# be reverted before this corpus can pass -- which is what makes it the mutant's subject
# rather than the no-REASON payload above.
cat > "$ROOT/spine-noad-emptyreason.md" <<'SPINEER'
# Architecture spine

## Invariants & Rules

### AD-1 — router resolver owns venue choice (== ADR-S300-1)

- **Binds:** FR-S300-1; `CAP-1`.
- **Prevents:** two paths resolving a venue from different inputs
- **Rule:** one core resolver maps routing config to a venue decision

## Capabilities carrying no AD

- **No-AD:** `CAP-2` — REASON:
SPINEER
# THE ID SEGMENT IS THE PART BEFORE `REASON:`. A reason that MENTIONS another capability
# is prose about a decision, not a disposition of that capability -- the same boundary
# the Prevents bullet gets one level up, one level down.
cat > "$ROOT/spine-noad-reasonmention.md" <<'SPINERM'
# Architecture spine

## Invariants & Rules

### AD-1 — the sweep ladder (== ADR-S300-1)

- **Binds:** FR-S300-1, FR-S300-2.
- **Prevents:** two paths resolving a venue from different inputs
- **Rule:** one core resolver maps routing config to a venue decision

## Capabilities carrying no AD

- **No-AD:** `CAP-1` — REASON: it extends the sweep ladder AD-1 already establishes, and so does `CAP-2`.
SPINERM


# --- the residue scan is KERNEL-SCOPED, and the definition bullet is its population ---
# THE SAME TOKEN, EVERYWHERE BUT THE KERNEL. A consumer reported `CAP-1ab` sitting in an
# operator-history transcript; a residue scan that read past the kernel would DISARM the
# gate on a file quoting an example id. These four inputs each carry the token and none
# of them is the kernel, so the pair (this PASSES / the same token in a kernel definition
# bullet DISARMs) is the whole of the scoping claim, in both directions.
mkdir -p "$ROOT/residue-elsewhere"
cp "$ROOT/ok/SPEC.md" "$ROOT/residue-elsewhere/SPEC.md"
cp "$ROOT/ok/.memlog.md" "$ROOT/residue-elsewhere/.memlog.md"
printf -- '- (note) the operator transcript quoted CAP-1ab as an example of an id shape we do not use\n' \
  >> "$ROOT/residue-elsewhere/.memlog.md"
cat > "$ROOT/prd-residue-token.md" <<'PRDRES'
# PRD

## Functional Requirements

- **FR-S300-1 (CAP-1) (<- LR-S300-1) - router venue.** body
- **FR-S300-2 (CAP-2) (<- LR-S300-2) - sweep floor.** body

## Notes

An earlier draft used ids like CAP-1ab; that shape was dropped before this PRD was cut.
PRDRES
cat > "$ROOT/spine-residue-token.md" <<'SPINERES'
# Architecture spine

## Invariants & Rules

### AD-1 — Dependency direction is inward (== ADR-S300-1)

- **Binds:** all
- **Prevents:** an example id like CAP-1ab leaking out of a transcript and into a gate
- **Rule:** the core imports nothing from an adapter
SPINERES
printf -- '---\ncapabilities: [CAP-1, CAP-2]\n---\n# story\n\nThe transcript for this story quotes CAP-1ab verbatim.\n' \
  > "$ROOT/story-residue-token.md"

# `_` AND `-` ARE INSIDE THE RESIDUE CLASS, and the reason is `\b`. Both are word
# characters, so `\bCAP-[0-9]+[a-z]?\b` matches NEITHER `CAP-1_a` nor `CAP-1-x` in full --
# and a residue expression narrower than the complement of `\b` extracts the well-formed
# `CAP-1` out of each and silently defines a DIFFERENT capability than the one written.
mkdir -p "$ROOT/cap-residue-underscore" "$ROOT/cap-residue-hyphen"
for d in cap-residue-underscore cap-residue-hyphen; do
  cp "$ROOT/ok/SPEC.md" "$ROOT/$d/SPEC.md"; cp "$ROOT/ok/.memlog.md" "$ROOT/$d/.memlog.md"
done
printf -- '- **CAP-1_a** intent: an id whose separator is a word character, so neither grammar matches it in full.\n' \
  >> "$ROOT/cap-residue-underscore/SPEC.md"
printf -- '- **CAP-1-x** intent: a hyphenated id, which as a DEFINITION is malformed rather than a mention.\n' \
  >> "$ROOT/cap-residue-hyphen/SPEC.md"

# A KERNEL THAT DOCUMENTS ITS OWN ID GRAMMAR. The definition shape shown inside a fence
# is an illustration; disarming on it would block the gate on a kernel for explaining
# itself, with the remedy being to delete the documentation.
mkdir -p "$ROOT/cap-fenced"
cp "$ROOT/ok/.memlog.md" "$ROOT/cap-fenced/.memlog.md"
cat > "$ROOT/cap-fenced/SPEC.md" <<'FENCEDSPEC'
# SPEC

## How capability ids are written

Every capability is declared as a definition bullet:

```
- **CAP-<n>** — <intent>
- **CAP-1ab** — an id shape this check deliberately cannot parse
```

## Capabilities

- **CAP-1** intent: resolve the venue. success: WHEN a rebalance leg executes, THE router SHALL be the venue.
- **CAP-2** intent: bound the sweep. success: WHILE a position is immature, THE sweeper SHALL NOT act.
FENCEDSPEC

# MENTIONS BUT DEFINES NONE. Not the same state as a spec with zero capabilities, and
# scoring it as one closes every join against an empty set.
mkdir -p "$ROOT/cap-mentions-none"
cp "$ROOT/ok/.memlog.md" "$ROOT/cap-mentions-none/.memlog.md"
printf '# SPEC\n\n## Capabilities\n\nCAP-1 and CAP-2 are described in the companion document; this kernel names them only.\n' \
  > "$ROOT/cap-mentions-none/SPEC.md"

# A PROSE MENTION IS NOT A DEFINITION. `CAP-3` is named and never declared, so it must not
# enter the set and must not be required of any FR or AD.
mkdir -p "$ROOT/cap-prose-mention"
cp "$ROOT/ok/.memlog.md" "$ROOT/cap-prose-mention/.memlog.md"
cp "$ROOT/ok/SPEC.md" "$ROOT/cap-prose-mention/SPEC.md"
printf -- '\nCAP-3 was considered during discovery and dropped before this kernel was cut.\n' \
  >> "$ROOT/cap-prose-mention/SPEC.md"

# --- `all` MUST BE THE WHOLE VALUE, ON THE MARKER LINE ------------------------
# Manufacturable out of ordinary prose otherwise: this continuation says the AD binds
# NOTHING, and folded onto its marker it reads `**Binds:** all routing decisions...`,
# which an `all\b` test accepts -- switching join (2a) off for every capability at once
# while the summary prints exactly like a spine that closes the join for real.
cat > "$ROOT/spine-binds-all-prose.md" <<'SPINEALLPROSE'
# Architecture spine

## Invariants & Rules

### AD-1 — router resolver owns venue choice (== ADR-S300-1)

- **Binds:**
  all routing decisions are deferred to AD-2 and this AD binds nothing yet
- **Prevents:** two paths resolving a venue from different inputs
- **Rule:** one core resolver maps routing config to a venue decision
SPINEALLPROSE

# --- a REASON that is the placeholder the FAIL message printed ----------------
# Both hatches tell the author to write `<why>` / `<reason>` into the file. Accepting
# that literal back is a predicate satisfied by the instruction that produced it.
cat > "$ROOT/spine-noad-placeholder.md" <<'SPINENOADPL'
# Architecture spine

## Invariants & Rules

### AD-1 — router resolver owns venue choice (== ADR-S300-1)

- **Binds:** FR-S300-1; `CAP-1`.
- **Prevents:** two paths resolving a venue from different inputs
- **Rule:** one core resolver maps routing config to a venue decision

## Capabilities carrying no AD

- **No-AD:** `CAP-2` — REASON: <why>
SPINENOADPL
# THE REAL DEFERRED BULLET, restated with an id and a reason but still under its own bold
# key. Captured from graph 74aff8ed2 ARCHITECTURE-SPINE.md:138-140, whose `## Deferred`
# section carries `- **Item 1 itself.** No \`AD\` — extends the existing terminal-status
# ladder ... not a new mechanism class`. It is the human-readable form of this exact
# disposition, and it is NOT the bullet the reader is anchored on.
cat > "$ROOT/spine-noad-otherbullet.md" <<'SPINENOADOB'
# Architecture spine

## Invariants & Rules

### AD-1 — router resolver owns venue choice (== ADR-S300-1)

- **Binds:** FR-S300-1; `CAP-1`.
- **Prevents:** two paths resolving a venue from different inputs
- **Rule:** one core resolver maps routing config to a venue decision

## Deferred

- **Item 1 itself.** No `AD` for `CAP-2` — REASON: it extends the existing terminal-status
  ladder to a fourth PARTIAL-family value; not a new mechanism class, so nothing here would
  let two independently-built units diverge.
SPINENOADOB

# --- the memlog hatch: the placeholder, and the LR that is not the SUBJECT ------
mkdir -p "$ROOT/disp-placeholder" "$ROOT/disp-notsubject"
cp "$ROOT/ok/SPEC.md" "$ROOT/disp-placeholder/SPEC.md"
cp "$ROOT/ok/SPEC.md" "$ROOT/disp-notsubject/SPEC.md"
printf '%s- (disposition) LR-S304-6 NO-CAPABILITY <reason>\n%s' \
  "$DISP_HEAD" "$DISP_TAIL" > "$ROOT/disp-placeholder/.memlog.md"
# TWO IDS, ONE ENTRY, NEITHER DISPOSITIONED NO-CAPABILITY. LR-S304-6 is dispositioned as
# something else and LR-S304-9 is merely named as its superseder; an unanchored pair of
# greps ("a line naming this LR" then "a line containing the token") excuses BOTH.
printf '%s- (disposition) LR-S304-6 SUPERSEDED by LR-S304-9 — see the NO-CAPABILITY convention for the other case
%s' \
  '- (note) input is an in-chat operator scope carrying a verbatim LOCKED_REQUIREMENTS block
- (capability) CAP-1 realises LR-S304-0: a collect skips what is not there
- (capability) CAP-2 realises LR-S304-1: a partial collect reaches a visible end state
' '- (event) pass 2 preservation PASS: LR-S304-0 -> CAP-1, LR-S304-1 -> CAP-2
' > "$ROOT/disp-notsubject/.memlog.md"


# --- a definition the BOLD ANCHOR cannot see ----------------------------------
# The producer emphasises ids several ways. `- _CAP-1a_` and `` - `CAP-1a` `` are
# definition ATTEMPTS that the `**CAP-<n>**` anchor does not see at all: not a definition,
# not residue either, so the id leaves the capability set in exactly the silence the
# suffix work exists to close.
mkdir -p "$ROOT/cap-emph-underscore" "$ROOT/cap-emph-code" "$ROOT/cap-prose-bullet" "$ROOT/cap-residue-nospace"
for d in cap-emph-underscore cap-emph-code cap-prose-bullet cap-residue-nospace; do
  cp "$ROOT/ok/SPEC.md" "$ROOT/$d/SPEC.md"; cp "$ROOT/ok/.memlog.md" "$ROOT/$d/.memlog.md"
done
printf -- '- _CAP-1a_ intent: emphasised with underscores rather than bold.\n'  >> "$ROOT/cap-emph-underscore/SPEC.md"
printf -- '- `CAP-1a` intent: wrapped in code markers rather than bold.\n'      >> "$ROOT/cap-emph-code/SPEC.md"
# THE FALSE-POSITIVE PIN FOR THAT ARM. A prose bullet that merely OPENS with a capability
# id carries no emphasis marker, and the five real kernels hold 18 of them; an arm without
# the delimiter requirement DISARMS four of the five.
printf -- "- CAP-10's enforcement surface is settled by the seam, not by this kernel.\n" >> "$ROOT/cap-prose-bullet/SPEC.md"
# THE ONLY SHAPE THAT REACHES THE RESIDUE ARM. Every definition bullet with whitespace
# after its list marker is claimed by the malformed-definition arm above it, so the
# residue expression is reachable only through a string CommonMark does not parse as a
# list item at all -- there is no whitespace after the `-`.
printf -- '-**CAP-1ab** intent: no whitespace after the list marker, so this is not a list item.\n' \
  >> "$ROOT/cap-residue-nospace/SPEC.md"

# --- the memlog entry TYPES the hatch reads -----------------------------------
# `(decision)` is the spelling the reference consumer has on disk. `(note)` is not in the
# accepted set, and it carries the token in the anchored position -- so this payload
# isolates the TYPE anchor from everything else the hatch requires.
mkdir -p "$ROOT/disp-notype"
cp "$ROOT/ok/SPEC.md" "$ROOT/disp-notype/SPEC.md"
printf '%s- (note) LR-S304-6 NO-CAPABILITY %s\n%s' \
  "$DISP_HEAD" "$DISP_REASON" "$DISP_TAIL" > "$ROOT/disp-notype/.memlog.md"


# --- the No-AD ID SEGMENT, and a marker eaten by a Binds bullet ----------------
# Everything before `REASON:` is DISPOSED, so a parenthetical naming a capability the
# bullet does not dispose either excuses it silently or fails the gate for a contradiction
# that is not one. The mixed segment is refused rather than guessed at.
cat > "$ROOT/spine-noad-mixedseg.md" <<'SPINEMIX'
# Architecture spine

## Invariants & Rules

### AD-1 — router resolver owns venue choice (== ADR-S300-1)

- **Binds:** FR-S300-1; `CAP-1`.
- **Prevents:** two paths resolving a venue from different inputs
- **Rule:** one core resolver maps routing config to a venue decision

## Capabilities carrying no AD

- **No-AD:** `CAP-2` (deferred pending AD-2, which `CAP-1` already anticipates) — REASON: it extends an existing pattern.
SPINEMIX
# A `**No-AD:**` MARKER THAT IS NOT AT BULLET START folds into the Binds bullet above it,
# so the capabilities it names read as BOUND: no FAIL, no note, and a sentence explicitly
# saying no AD exists produces silence.
cat > "$ROOT/spine-noad-eaten.md" <<'SPINEEAT'
# Architecture spine

## Invariants & Rules

### AD-1 — router resolver owns venue choice (== ADR-S300-1)

- **Binds:** FR-S300-1; `CAP-1`;
  see **No-AD:** below for `CAP-2` — REASON: deferred to the next sprint.
- **Prevents:** two paths resolving a venue from different inputs
- **Rule:** one core resolver maps routing config to a venue decision
SPINEEAT
# The `no-ad-form:` key IS baselineable -- the code says so and says why. This names the
# mixed-segment finding above.
printf 'no-ad-form:spine-noad-mixedseg.md\nad:CAP-2\n' > "$ROOT/baseline-noad-form.txt"


# --- declarations the definition reader cannot see ----------------------------
# Each of these is a real markdown declaration and each is a REGRESSION against reading
# the whole file: the kernel defines the capability, the set does not contain it, and the
# only trace is the count on the PASS line.
mkdir -p "$ROOT/cap-heading" "$ROOT/cap-prefix-defined"
cp "$ROOT/ok/SPEC.md" "$ROOT/cap-heading/SPEC.md"; cp "$ROOT/ok/.memlog.md" "$ROOT/cap-heading/.memlog.md"
printf -- '\n### CAP-3\n\nintent: declared as a heading rather than a definition bullet.\n' >> "$ROOT/cap-heading/SPEC.md"

# THE SHAPE THE UNPARSED JOIN STRUCTURALLY CANNOT SEE. `CAP_LOOKS_DECL` extracts with the
# well-formed grammar, so from `**CAP-1ab` it lifts the PREFIX `CAP-1a`; when that prefix
# is itself a defined capability the join cancels and the malformed definition is dropped
# in silence. A join whose two sides are derived by the SAME lenient grammar cannot see a
# malformed member -- the kernel below defines four ids and the check reports three.
cat > "$ROOT/cap-prefix-defined/SPEC.md" <<'PREFIXSPEC'
# SPEC

## Capabilities

- **CAP-1** intent: resolve the venue. success: WHEN a rebalance leg executes, THE router SHALL be the venue.
- **CAP-1a** intent: the empty case. success: IF nothing resolves, THEN THE router SHALL no-op.
- **CAP-2** intent: bound the sweep. success: WHILE a position is immature, THE sweeper SHALL NOT act.
- **CAP-1ab** intent: a malformed definition whose well-formed prefix CAP-1a is also defined.
PREFIXSPEC
printf -- '- (capability) CAP-1 realises LR-S300-1\n- (capability) CAP-2 realises LR-S300-2\n' \
  > "$ROOT/cap-prefix-defined/.memlog.md"
cat > "$ROOT/prd-prefix-defined.md" <<'PRDPFX'
# PRD

## Functional Requirements

- **FR-1 (CAP-1)** a
- **FR-2 (CAP-1a)** b
- **FR-3 (CAP-2)** c
PRDPFX


# THE NARROWING: a second `**<Key>:**` marker with NO capability id after it loses nothing
# to the truncation, and the wrapped form of that same sentence is the exact shape the fold
# exists to support. Firing here would fail a spine that is correct.
cat > "$ROOT/spine-marker-noid.md" <<'SPINEMNI'
# Architecture spine

## Invariants & Rules

### AD-1 — router resolver owns venue choice (== ADR-S300-1)

- **Binds:** FR-S300-1; `CAP-1`, `CAP-2`;
  see the **Rule:** below for how the resolver is threaded.
- **Prevents:** two paths resolving a venue from different inputs
- **Rule:** one core resolver maps routing config to a venue decision
SPINEMNI


# --- a definition bullet holding TWO IDS ---------------------------------------
# THE ONE SHAPE A JOIN OVER TWO ID SETS STRUCTURALLY CANNOT EXPRESS. The cross-check keys
# on IDS: `CAP-2` here is not preceded by an emphasis marker (it sits mid-run), so it is
# absent from the looks-declarative side and the `comm` has nothing to disagree about. The
# defect is not a bad ID, it is a definition STRING that declares two capabilities and is
# credited to one. Measured on the frozen subject: with the definition-shape assertion
# disarmed this file reports ONE capability out of two declared, exits 0, and the only
# trace is the count on the PASS line.
mkdir -p "$ROOT/cap-twoid" "$ROOT/cap-twoid-undefined"
cp "$ROOT/ok/.memlog.md" "$ROOT/cap-twoid/.memlog.md"
cp "$ROOT/ok/.memlog.md" "$ROOT/cap-twoid-undefined/.memlog.md"
cat > "$ROOT/cap-twoid/SPEC.md" <<'TWOID'
# SPEC

## Capabilities

- **CAP-1** intent: resolve the venue. success: WHEN a rebalance leg executes, THE router SHALL be the venue.
- **CAP-1 and CAP-2 together** intent: one bullet declaring two capabilities, credited to the first.
TWOID
# THE DISCRIMINATING CONTROL FOR WHICH GUARD OWNS IT. Same malformed bullet, leading id
# changed to one the kernel does not otherwise define -- now the cross-check DOES see it,
# because nothing cancels `CAP-9` on the parsed side. The two guards catch different
# populations and this pair is what shows the boundary.
cat > "$ROOT/cap-twoid-undefined/SPEC.md" <<'TWOID9'
# SPEC

## Capabilities

- **CAP-1** intent: resolve the venue. success: WHEN a rebalance leg executes, THE router SHALL be the venue.
- **CAP-9 and CAP-2 together** intent: one bullet declaring two capabilities, neither of them the leading id.
TWOID9

# --- the No-AD staleness key, and the is_reason accept/reject matrix ------------
printf 'no-ad-stale:CAP-2\n' > "$ROOT/baseline-noad-stale.txt"

# One spine per reason, written by the caller. `mk_reason_spine <file> <reason>` keeps the
# fourteen payloads to one shape so the matrix is the only thing that varies.
mk_reason_spine() { # <path> <reason-text>
  { printf '# Architecture spine\n\n### AD-1 — router resolver owns venue choice\n\n'
    printf -- '- **Binds:** FR-S300-1; `CAP-1`.\n'
    printf -- '- **Prevents:** two paths resolving a venue from different inputs\n'
    printf -- '- **Rule:** one core resolver maps routing config to a venue decision\n\n'
    printf -- '- **No-AD:** `CAP-2` — REASON: %s\n' "$2"
  } > "$1"
}
i=0
for reason in '<why>' '`<why>`' '(<why>)' '[reason]' '{why}' '(why)' 'reason' 'TODO' 'TBD' 'n/a'; do
  i=$((i+1)); mk_reason_spine "$ROOT/reason-reject-$i.md" "$reason"
done
j=0
for reason in '(it extends the ladder)' '[per AD-7] it extends the ladder' '*see AD-7*' 'the reason is that it extends the ladder'; do
  j=$((j+1)); mk_reason_spine "$ROOT/reason-accept-$j.md" "$reason"
done

# --- the eaten-marker matrix, measured on the frozen subject -------------------
# A second `**<Key>:**` marker costs the join something only when a capability id sits
# AFTER it, because that is exactly when the truncation removes one. The two no-loss rows
# were hard failures until the arm was narrowed, and one of them is ordinary writing.
mk_binds_spine() { # <path> <binds-value>
  { printf '# Architecture spine\n\n### AD-1 — router resolver owns venue choice\n\n'
    printf -- '- **Binds:** %s\n' "$2"
    printf -- '- **Prevents:** two paths resolving a venue from different inputs\n'
    printf -- '- **Rule:** one core resolver maps routing config to a venue decision\n'
  } > "$1"
}
mk_binds_spine "$ROOT/binds-loss-parenthetical.md" '`CAP-1` (see **Rule:** below), `CAP-2`'
mk_binds_spine "$ROOT/binds-loss-midlist.md"       '`CAP-1`, **also:** `CAP-2`'
mk_binds_spine "$ROOT/binds-noloss-trailing.md"    '`CAP-1`, `CAP-2` — the **Rule:** is stated in AD-2'
mk_binds_spine "$ROOT/binds-noloss-digitkey.md"    '`CAP-1`, `CAP-2` — see **AD-7:** for the ladder'


# --- the SAME malformed run, in six containers -------------------------------
# ONE CAUSE, SIX RECONSTRUCTIONS. The arm that catches a two-id declaration inherited the
# BULLET container from the reader it guards, so the identical run in a numbered item, a
# table row, a blockquote, a heading or a plain paragraph dropped its second id at rc=0 --
# the container blocker reappearing inside the arm written to close it. The predicate is
# now keyed on the emphasis RUN, so the container is not part of the question.
mk_decl_kernel() { # <dir> <second-declaration-line>
  mkdir -p "$ROOT/$1"
  { printf '# SPEC\n\n## Capabilities\n\n'
    printf -- '- **CAP-1** intent: resolve the venue. success: WHEN a rebalance leg executes, THE router SHALL be the venue.\n\n'
    printf '%s\n' "$2"
  } > "$ROOT/$1/SPEC.md"
  cp "$ROOT/ok/.memlog.md" "$ROOT/$1/.memlog.md"
}
mk_decl_kernel decl-clean     '- **CAP-2** intent: bound the sweep. success: WHILE a position is immature, THE sweeper SHALL NOT act.'
mk_decl_kernel decl-bullet    '- **CAP-1 and CAP-2 together** intent: one run, two ids, credited to the first.'
mk_decl_kernel decl-numbered  '1. **CAP-1 and CAP-2 together** intent: one run, two ids, in a numbered item.'
mk_decl_kernel decl-table     '| **CAP-1 and CAP-2 together** | intent: one run, two ids, in a table row |'
mk_decl_kernel decl-quote     '> - **CAP-1 and CAP-2 together** intent: one run, two ids, inside a blockquote.'
mk_decl_kernel decl-heading   '### CAP-1 and CAP-2 together'
mk_decl_kernel decl-para      '**CAP-1 and CAP-2 together** intent: one run, two ids, as a plain paragraph.'
mk_decl_kernel decl-innerstar '- **CAP-1 *and* CAP-2 together** intent: an inner emphasis marker inside the bold run.'

# THE NEGATIVE CONTROL, BOTH WAYS. A bolded clause that MENTIONS two ids opens with a
# backtick rather than an id, so it is not a declaration and the declaration arm is
# correctly quiet. Whether the FILE is quiet, though, depends on the surrounding kernel:
# the cross-check sees `` `CAP-6` `` as declarative, so it fires unless those ids are
# declared elsewhere. Both halves are seeded because only the pair says which guard is
# doing what. Captured from the real s304 kernel, where the ids ARE declared.
mkdir -p "$ROOT/decl-clause-defined" "$ROOT/decl-clause-undefined"
cat > "$ROOT/decl-clause-defined/SPEC.md" <<'CLAUSEDEF'
# SPEC

## Capabilities

- **CAP-1** intent: resolve the venue.
- **CAP-6** intent: an over-consuming mint reverts rather than drawing the remainder.
- **CAP-8** intent: the stale-view refusal still fires for create intent.

## Coverage

- **`CAP-6` and `CAP-8` are named or entailed by NO entry inside the LOCKED_REQUIREMENTS block** — both are gap closures.
CLAUSEDEF
cat > "$ROOT/decl-clause-undefined/SPEC.md" <<'CLAUSEUNDEF'
# SPEC

## Capabilities

- **CAP-1** intent: resolve the venue.

## Coverage

- **`CAP-6` and `CAP-8` are named or entailed by NO entry inside the LOCKED_REQUIREMENTS block** — both are gap closures.
CLAUSEUNDEF
printf -- '- (capability) CAP-1 realises LR-S300-1\n' > "$ROOT/decl-clause-defined/.memlog.md"
cp "$ROOT/decl-clause-defined/.memlog.md" "$ROOT/decl-clause-undefined/.memlog.md"
cat > "$ROOT/prd-decl-clause.md" <<'PRDCL'
# PRD

## Functional Requirements

- **FR-1 (CAP-1)** a
- **FR-6 (CAP-6)** b
- **FR-8 (CAP-8)** c
PRDCL


# --- an UNCLOSED emphasis run, and a correct kernel that TALKS about its capabilities ---
# AN UNCLOSED `**` IS AN ORDINARY HAND-EDIT TYPO, and it reconstructs the two-id defect an
# eighth way: the definition reader needs a CLOSING marker, so the run is captured by
# nothing and every id on the line leaves the set in silence. Three openers, because the
# opener is what the arm keys on.
mk_unclosed() { # <dir> <second-line>
  mkdir -p "$ROOT/$1"
  { printf '# SPEC\n\n## Capabilities\n\n'
    printf -- '- **CAP-1** intent: resolve the venue.\n'
    printf '%s\n' "$2"
  } > "$ROOT/$1/SPEC.md"
  cp "$ROOT/ok/.memlog.md" "$ROOT/$1/.memlog.md"
}
mk_unclosed unclosed-bold '- **CAP-2 and CAP-9 together intent: the bold run never closes.'
mk_unclosed unclosed-em   '- *CAP-2 and CAP-9 together intent: the emphasis run never closes.'
mk_unclosed unclosed-code '- `CAP-2 and CAP-9 together intent: the code run never closes.'
# THE DISCRIMINATING CONTROL. The SAME unclosed line, with every id it names declared
# properly elsewhere. Nothing is dropped, so nothing should fire -- an arm that flags the
# run rather than the LOSS would fail this correct kernel.
mkdir -p "$ROOT/unclosed-declared"
{ printf '# SPEC\n\n## Capabilities\n\n'
  printf -- '- **CAP-1** intent: resolve the venue.\n'
  printf -- '- **CAP-2** intent: bound the sweep.\n'
  printf -- '- **CAP-9** intent: the selector the operator already knows.\n'
  printf -- '- **CAP-2 and CAP-9 together intent: the same unclosed run, every id declared above.\n'
} > "$ROOT/unclosed-declared/SPEC.md"
cp "$ROOT/ok/.memlog.md" "$ROOT/unclosed-declared/.memlog.md"
cat > "$ROOT/prd-unclosed.md" <<'PRDUNC'
# PRD

## Functional Requirements

- **FR-1 (CAP-1)** a
- **FR-2 (CAP-2)** b
- **FR-9 (CAP-9)** c
PRDUNC

# THE POSITIVE CONTROL KERNEL. Everything declared canonically AND the kernel TALKS about
# its capabilities -- a heading per capability, a heading naming two of them, and a bolded
# sentence citing both. Nothing is dropped, so a correct kernel that documents itself must
# pass. Without this arm, an assertion that flags any non-id emphasis run reads as green
# while hard-blocking every kernel written this way.
mkdir -p "$ROOT/kernel-prose-rich"
cat > "$ROOT/kernel-prose-rich/SPEC.md" <<'PROSERICH'
# SPEC

## Capabilities

### CAP-1 — the routing capability

- **CAP-1** intent: resolve the venue. success: WHEN a rebalance leg executes, THE router SHALL be the venue.

### CAP-2 and CAP-1 interactions

- **CAP-2** intent: bound the sweep. success: WHILE a position is immature, THE sweeper SHALL NOT act.

## Notes

**`CAP-1` and `CAP-2` are both gap closures** authored during discovery's validation cycle.
PROSERICH
cp "$ROOT/ok/.memlog.md" "$ROOT/kernel-prose-rich/.memlog.md"


# --- a declaration that WRAPS, and the fold's bound ---------------------------
# BLOCKER 31. Scoped to the PHYSICAL LINE, a wrapped declaration splits the defect across
# two innocent lines: the first opens a run and drops nothing, the second carries the
# dropped id and opens no run, and the declaration that is wrong spans both. The
# byte-identical ONE-LINE form is seeded beside it because that is the half that says WHAT
# broke -- revert the fold and the one-line form keeps passing while the wrapped form goes
# silent, so an arm on the wrapped form alone reports a regression it cannot localise.
mk_kernel_body() { # <dir> <body-after-the-first-declaration>
  mkdir -p "$ROOT/$1"
  { printf '# SPEC\n\n## Capabilities\n\n'
    printf -- '- **CAP-1** intent: resolve the venue.\n'
    printf '%s\n' "$2"
  } > "$ROOT/$1/SPEC.md"
  cp "$ROOT/ok/.memlog.md" "$ROOT/$1/.memlog.md"
}
mk_kernel_body b31-wrapped '- **CAP-1 and
  CAP-2 together** intent: the declaration wraps, so no single line is wrong.'
mk_kernel_body b31-oneline '- **CAP-1 and CAP-2 together** intent: the same declaration, unwrapped.'
mk_kernel_body b31-wrapped-undef '- **CAP-9 and
  CAP-2 together** intent: the wrapped form with a leading id nothing else declares.'

# DEFECT 32 AND THE FOLD BOUND. The fold continues only while the open run OPENED WITH A
# CAP ID. Bounding it on ANY odd asterisk-pair count instead drags the next line into the
# item whenever a DESCRIPTION carries an unclosed `**`, and an ordinary cross-spec
# reference on that line then reads as a dropped id -- a hard DISARM on a correct kernel.
mk_kernel_body d32-unclosed-desc '- **CAP-2** — see **note
  CAP-99 is defined in the other spec.'
mk_kernel_body d32-closed-desc '- **CAP-2** — see **note** below
  CAP-99 is defined in the other spec.'
# THE BOUND ITSELF. A CLOSED run takes no continuation, so a definition description that
# cites another spec stays a description. Without this arm the fold can be widened to whole
# list items, every wrapped-declaration arm stays green, and correct kernels start failing.
mk_kernel_body bound-closed-desc '- **CAP-2** — routing
  CAP-99 belongs to the other spec and is not declared here.'

# A FOLD-HEAVY CORPUS FOR THE TERMINATION ARM. Many declarations, many opened and closed
# runs, and continuation lines the fold must join and stop joining.
mkdir -p "$ROOT/fold-heavy"
{ printf '# SPEC\n\n## Capabilities\n\n'
  printf -- '- **CAP-1** intent: resolve the venue.\n'
  printf -- '- **CAP-2** intent: bound the sweep.\n'
  i=0
  while [ "$i" -lt 300 ]; do
    i=$((i+1))
    printf -- '- **CAP-1** restated with **emphasis** and a `code run` in line %s\n' "$i"
    printf -- '  a continuation line for item %s, with **an opened and closed pair**\n' "$i"
  done
} > "$ROOT/fold-heavy/SPEC.md"
cp "$ROOT/ok/.memlog.md" "$ROOT/fold-heavy/.memlog.md"


# --- DEFECT 33: after the first run, an item is PROSE ---------------------------
# A capability whose intent cites a neighbouring spec was hard-DISARMING, so only an
# item FIRST emphasis run can declare, and everything after it is prose. These three
# payloads are the two sides of that rule plus the cost it is bought with.
mk_kernel_body bullet-foreign-id '- **CAP-2** — intent: the basis, unlike `CAP-99` upstream, is that layer own post-swap balance.'
mk_kernel_body note-bullet       '- **CAP-2** intent: b.
- **Note:** see `CAP-9` in the other spec for the selector.'
mk_kernel_body clause-undeclared '- **`CAP-6` and `CAP-8` are named or entailed by NO entry inside the block** — both are gap closures.'
# THE ACCEPTED COST, ONE CONTAINER OVER. A heading has no closing delimiter, so its whole
# text is the run and every id in it is declared by it — which means a heading CITING a
# foreign id DISARMs where the identical citation in an intent bullet is prose. That
# asymmetry is deliberate and is seeded on BOTH sides so it cannot drift into silence.
mk_kernel_body head-foreign-id   '### CAP-1 — see CAP-99 upstream'


# --- the CONTAINER x DECLARATION-SHAPE matrix, in the LONE-ID shape -------------
# WHY THIS EXISTS AS A SECOND FAMILY. Every container payload above seeds a TWO-ID run,
# which is non-bare and is taken by the stronger-run path without ever consulting the
# leading test. The regression that put a lone `| **CAP-9** |` and `> - **CAP-9**` back
# into silence lived in that leading test, and this battery stayed GREEN through it. When
# a guard has two acceptance paths, every seed family needs a case on EACH, or the family
# silently covers one branch.
#
# THE EXPECTATION SPLITS THREE WAYS AND THAT IS THE POINT. An arm asserting "every
# container DISARMS" would be WRONG about the two the reader correctly takes.
mk_row() { # <dir> <row-text>
  mkdir -p "$ROOT/$1"
  { printf '# SPEC\n\n## Capabilities\n\n'
    printf -- '- **CAP-1** intent: resolve the venue.\n\n'
    printf '%s\n' "$2"
  } > "$ROOT/$1/SPEC.md"
  printf -- '- (capability) CAP-1 realises LR-S300-1\n' > "$ROOT/$1/.memlog.md"
}
cat > "$ROOT/prd-matrix.md" <<'PRDMX'
# PRD

## Functional Requirements

- **FR-1 (CAP-1)** a
- **FR-9 (CAP-9)** b
PRDMX
# READ: the reader takes these, so CAP-9 joins the set and the kernel has two capabilities.
mk_row mx-read-dash     '- **CAP-9** intent: taken as a declaration.'
mk_row mx-read-indent   '  - **CAP-9** intent: an indented bullet is still a bullet.'
# FLAGGED: a declaration the reader cannot take, in a container it does not read.
mk_row mx-flag-numbered '2. **CAP-9** intent: a numbered item.'
mk_row mx-flag-plus     '+ **CAP-9** intent: a plus-marker bullet.'
mk_row mx-flag-quote    '> **CAP-9** intent: inside a blockquote.'
mk_row mx-flag-quotebul '> - **CAP-9** intent: a blockquote bullet.'
mk_row mx-flag-table    '| **CAP-9** | intent: a table cell |'
mk_row mx-flag-heading  '### CAP-9'
mk_row mx-flag-para     '**CAP-9** intent: a bare paragraph.'
mk_row mx-flag-em       '- _CAP-9_ intent: underscore emphasis.'
mk_row mx-flag-code     '- `CAP-9` intent: a code run.'
mk_row mx-flag-dunder   '- __CAP-9__ intent: double-underscore emphasis.'
# QUIET: prose. The id must NOT join the set and nothing may fire.
mk_row mx-quiet-see     '- see `CAP-9` upstream for the selector.'
mk_row mx-quiet-note    '- **Note:** see `CAP-9` upstream for the selector.'

# --- DEFECT 40: the strict membership gate has THREE states, not two ------------
# A bolded phrase LATE in an item is a foreign citation when none of its ids is declared,
# and a dropped declaration when SOME are. Only the mixed state fires. An arm holding the
# two ends and not the middle would let a widening of the gate pass in silence, and an arm
# holding only the middle would not notice the gate being deleted.
mk_mixed() { # <dir> <row>
  mkdir -p "$ROOT/$1"
  { printf '# SPEC\n\n## Capabilities\n\n'
    printf -- '- **CAP-1** intent: a.\n- **CAP-2** intent: b.\n- **CAP-3** intent: c.\n\n'
    printf '%s\n' "$2"
  } > "$ROOT/$1/SPEC.md"
  printf -- '- (capability) CAP-1 realises LR-S300-1\n' > "$ROOT/$1/.memlog.md"
}
cat > "$ROOT/prd-mixed.md" <<'PRDMIX'
# PRD

## Functional Requirements

- **FR-1 (CAP-1)** a
- **FR-2 (CAP-2)** b
- **FR-3 (CAP-3)** c
PRDMIX
mk_mixed mem-all-known   '- see `CAP-1` then **CAP-2 and CAP-3** are the pair.'
mk_mixed mem-mixed       '- see `CAP-1` then **CAP-2 and CAP-9** are the pair.'
mk_mixed mem-none-known  '- see `CAP-1` then **CAP-9 and CAP-8** upstream.'
mk_mixed mem-first-mixed '- **CAP-2 and CAP-9** together.'
mk_mixed mem-first-none  '- **CAP-9 and CAP-8** together.'

# --- the DOCUMENTED irreducible limit ------------------------------------------
# A short prefix in front of a declaration naming exactly ONE id is structurally identical
# to a citation, and the id drops in SILENCE. Measured on the five real kernels: 18 late
# bare-id runs, none holding anything but a bare id and none naming an id absent from its
# own kernel, so the ambiguous class is empty on the real corpus. This is armed as the
# behaviour it IS. An arm expecting a fix would be asserting a decision nobody took.
cat > "$ROOT/prd-limit.md" <<'PRDLIM'
# PRD

## Functional Requirements

- **FR-1 (CAP-1)** a
- **FR-2 (CAP-2)** b
- **FR-3 (CAP-3)** c
- **FR-9 (CAP-9)** d
PRDLIM
mk_mixed limit-prefixed  '- *(deprecated)* **CAP-9** intent: a prefix and exactly one id.'
mk_mixed limit-control   '- **CAP-9** intent: the same declaration with no prefix.'

printf '%s\n' "$ROOT"
