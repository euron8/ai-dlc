#!/usr/bin/env bash
# Seed the check-manifest-bypass fixture.
#
# THIS FIXTURE WRITES A FILE. It used to be nine `echo` statements describing a
# sliced gate context in English, which H1 then "scanned". H1's manifest-completeness
# pass is an LLM check, so a seed cannot assert its verdict the way check-17-bypass's
# run.sh can -- but it CAN hand H1 a real artifact to scan instead of a paragraph
# about one. An adversarial seed the adversary reads as prose is not adversarial.
#
# Scenario: a gate declares type `implementation` but loads only the PLANNING slice
# of gate-validation.md -- universal core plus the planning row -- omitting every
# implementation-required check. Their CHECK_LOADED anchors are therefore absent from
# the loaded context.
#
# Expected: H1 reads GATE_MANIFEST, resolves the declared type (`implementation`),
# and FAILS the gate naming at least one missing required anchor (e.g. CHECK_LOADED:
# 6). An H1 that PASSES this seed means the v0.24.0 slicing re-expression silently
# dropped a required check -- the exact failure the scar tissue exists to prevent.
#
# Usage: seed.sh [OUT_DIR]   (prints the seeded context file path on stdout)

set -euo pipefail

OUT="${1:-${OUT:-$(mktemp -d)}}"
mkdir -p "$OUT"
CTX="$OUT/gate-context-implementation-sliced.md"

cat > "$CTX" <<'EOF'
<!-- SEEDED GATE CONTEXT — check-manifest-bypass fixture.
     This file simulates what a lead ACTUALLY loaded into context before calling a
     gate. H1's manifest-completeness pass must scan it, resolve the declared gate
     type against GATE_MANIFEST, and prove that every required CHECK_LOADED anchor
     is present. It is not. -->

# Gate Context (as loaded)

    GATE_TYPE: implementation

## Loaded slice of gate-validation.md

The lead loaded the universal core plus the **planning** row. These are the anchors
actually present in context:

<!-- CHECK_LOADED: 1 -->
<!-- CHECK_LOADED: 2 -->
<!-- CHECK_LOADED: 2a -->
<!-- CHECK_LOADED: 3 -->
<!-- CHECK_LOADED: 4 -->
<!-- CHECK_LOADED: 7 -->
<!-- CHECK_LOADED: 12 -->
<!-- CHECK_LOADED: 13 -->
<!-- CHECK_LOADED: 14 -->
<!-- CHECK_LOADED: 15 -->
<!-- CHECK_LOADED: 16 -->
<!-- CHECK_LOADED: 25 -->
<!-- CHECK_LOADED: 26 -->
<!-- CHECK_LOADED: H1 -->
<!-- CHECK_LOADED: H2 -->
<!-- CHECK_LOADED: failure -->
<!-- CHECK_LOADED: 1c -->
<!-- CHECK_LOADED: 17 -->
<!-- CHECK_LOADED: 20 -->
<!-- CHECK_LOADED: 23 -->
<!-- CHECK_LOADED: 24 -->
<!-- CHECK_LOADED: 27 -->
<!-- CHECK_LOADED: 28 -->
<!-- CHECK_LOADED: 29 -->
<!-- CHECK_LOADED: 32 -->
<!-- CHECK_LOADED: 33 -->
<!-- CHECK_LOADED: 34 -->

## What is missing

The declared type is `implementation`, whose GATE_MANIFEST row additionally requires
checks 5, 6, 8, 9, 10, 11, 11a, 19 and 22. Not one of their CHECK_LOADED anchors
appears above. A gate run against this context would silently skip all nine.

H1 must FAIL this seed, naming at least one missing anchor.
EOF

echo "$CTX"
