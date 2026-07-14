#!/usr/bin/env bash
# seed.sh — write REAL transcript files (JSONL) and a REAL project dir to disk.
# Prints the sandbox root on stdout.
set -euo pipefail

ROOT="$(mktemp -d)"
mkdir -p "$ROOT/_bmad-output"

# One transcript = one JSONL file of {message:{role,content}} lines, which is the
# shape ai-dlc-continue.sh's jq actually reads.
mk() { # mk <name> <user-text> <assistant-text>
  local f="$ROOT/$1.jsonl"
  jq -nc --arg u "$2" '{message:{role:"user",content:$u}}'      >  "$f"
  jq -nc --arg a "$3" '{message:{role:"assistant",content:$a}}' >> "$f"
  printf '%s' "$f"
}

# (1) handoff REQUESTED, no resume block at all -> must BLOCK
mk miss "hand off the sprint" \
  "Done. I've committed everything and updated the snapshot. Ready when you are." > "$ROOT/.p_miss"

# (2) handoff REQUESTED, resume block in CORE's mandated format (four hyphens)
#     -> must PASS. The reference consumer's copy demanded exactly six and would
#     have BLOCKED this — a check firing on compliance with the rulebook.
mk core4 "hand off the sprint" \
  "Snapshot finalized.

\`\`\`
----
/ai-dlc resume
----
\`\`\`
" > "$ROOT/.p_core4"

# (3) same, six hyphens (what the reference consumer emitted) -> must ALSO pass.
mk six "hand off the sprint" \
  "Snapshot finalized.

\`\`\`
------
/ai-dlc resume
------
\`\`\`
" > "$ROOT/.p_six"

# (4) /ai-dlc resume present but NOT delimited (blockquote prose) -> must BLOCK.
#     Presence is not format; this is the case a substring grep false-greens.
mk undelimited "hand off the sprint" \
  "All set. When you're ready, just run > /ai-dlc resume in a fresh session." > "$ROOT/.p_undelim"

# (5) incidental NOUN mention, NOT a request -> must NOT fire at all.
mk noun "what does the handoff guard actually check?" \
  "It checks that the resume prompt is delimited." > "$ROOT/.p_noun"

printf '%s\n' "$ROOT"
