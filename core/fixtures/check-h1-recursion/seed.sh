#!/usr/bin/env bash
# Seed the check-h1-recursion fixture.
#
# THIS FIXTURE WRITES A FILE and EXPORTS THE GUARD VARIABLE. It used to be two
# `echo` statements asserting, in English, that the guard fires -- while never
# setting H1_DEPTH at all. The condition under test was not established, so the test
# could not fail.
#
# Scenario: H2 re-invokes H1 with H1_DEPTH=1 already set. H1 MUST return PASS
# IMMEDIATELY, without re-enumerating fixtures and without re-invoking H2 -- otherwise
# H1 -> H2 -> H1 -> H2 recurses without bound and the gate never terminates.
#
# H1 is an LLM check, so this seed cannot assert its verdict mechanically (unlike
# check-17-bypass/run.sh). What it CAN do is (1) actually set the guard variable and
# (2) write the guard state to a file H1 must read, so the adversary is reacting to a
# real condition rather than to a sentence describing one.
#
# Usage:  eval "$(seed.sh [OUT_DIR])"    # to inherit H1_DEPTH in the caller
#         seed.sh [OUT_DIR]              # to just write the state file
#
# Prints an `export H1_DEPTH=1` line plus the state-file path.

set -euo pipefail

OUT="${1:-${OUT:-$(mktemp -d)}}"
mkdir -p "$OUT"
STATE="$OUT/h1-depth-state.env"

cat > "$STATE" <<'EOF'
# SEEDED RECURSION-GUARD STATE — check-h1-recursion fixture.
# H1 is being invoked with a depth guard ALREADY SET. This is the re-entrant call
# that H2 makes into H1.
H1_DEPTH=1
EOF

export H1_DEPTH=1

cat <<EOF
export H1_DEPTH=1
# state file: $STATE
#
# EXPECTED H1 BEHAVIOUR under this seed:
#   PASS immediately. Do NOT re-enumerate the fixture dirs. Do NOT re-invoke H2.
#
# An H1 that proceeds to enumerate fixtures with H1_DEPTH=1 set has no recursion
# guard, and H1 -> H2 -> H1 -> H2 does not terminate. That is a FAIL of this fixture,
# however green the gate looks.
EOF
