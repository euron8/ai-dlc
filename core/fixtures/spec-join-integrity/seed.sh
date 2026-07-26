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

# healthy: both LRs cited beside a CAP, both CAPs in the coverage map
mk_spec "$ROOT/ok" 'decision | pinned units to BLOCKS
capability | CAP-1 realises LR-S300-1 (venue == router, verified live)
capability | CAP-2 realises LR-S300-2 (maturity floor in blocks)
event | self-validate pass 1 and 2 clean
'
printf '# PRD\n\n## FR Coverage Map\n\n- FR1 (CAP-1): Epic 1\n- FR2 (CAP-2): Epic 1\n' > "$ROOT/prd-ok.md"

# break (1): LR-S300-2 present in the memlog but no capability line cites it
mk_spec "$ROOT/orphan-lr" 'capability | CAP-1 realises LR-S300-1
capability | CAP-2 realises nothing in particular
note | LR-S300-2 was discussed and then not carried
'

# break (2): coverage map omits CAP-2
printf '# PRD\n\n## FR Coverage Map\n\n- FR1 (CAP-1): Epic 1\n' > "$ROOT/prd-missing-cap.md"

# break (2b): no coverage map heading at all -> DISARM, not skip
printf '# PRD\n\n## Functional Requirements\n\n- FR1: something\n' > "$ROOT/prd-no-map.md"

# zero-capability kernel -> DISARM
mkdir -p "$ROOT/no-caps"
printf '# SPEC\n\n## Capabilities\n\n- (none yet)\n' > "$ROOT/no-caps/SPEC.md"
printf 'capability | LR-S300-1 noted\n' > "$ROOT/no-caps/.memlog.md"

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
printf '%s\n' "$ROOT"
