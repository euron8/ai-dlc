#!/usr/bin/env bash
#
# AI/DLC Snapshot Edit Deny  (PreToolUse: Edit|Write|MultiEdit|NotebookEdit)
#
# `pipeline-snapshot.md` has ONE sanctioned writer, `snapshot-update.sh`, which runs
# `validate-artifact-budget.sh --stamps-only` on the lines it adds BEFORE it writes and writes
# nothing on a finding. A file tool writes the snapshot past that judge, so this hook refuses
# every Edit, Write, MultiEdit and NotebookEdit of it, from every caller, subagents included,
# and its reason names the `snapshot-update.sh` op for the change. The Bash half -- a shell write
# of the snapshot -- is Deny B in `ai-dlc-foreground-budget.sh`.
#
# CONTRACT
#
#   DENY iff the tool is Edit, Write, MultiEdit or NotebookEdit and the path it names
#   (`.tool_input.file_path`, or `.tool_input.notebook_path` for NotebookEdit) has the basename
#   `pipeline-snapshot.md`, compared case-insensitively: on a case-insensitive filesystem (the
#   macOS default) `Pipeline-Snapshot.md` IS the snapshot. Both forms are matched: a path ending
#   `/<name>` and the bare relative `<name>`. Everything else is allowed by silence.
#
#   A LITERAL BASENAME, NEVER `pipeline-snapshot*.md`: `pipeline-snapshot-history.md` (the history
#   file `--move-to-history` appends to) and `pipeline-snapshot.md.bak` are other files and pass.
#   `ai-dlc-acknowledge.sh` records why that glob is wrong.
#
#   NOT ANCHORED ON `_bmad-output/`: `AI_DLC_STATE_DIR` moves the state directory, and a deny keyed
#   on the default directory would pass every relocated snapshot.
#
#   NOT GATED ON THE SNAPSHOT EXISTING: a creating Write is refused too. `snapshot-update.sh --init`
#   renders the skeleton into an absent or empty file.
#
#   NO ERA GATE, and no section inference from `old_string`: inferring the section would cost a
#   second jq read or a read of the snapshot, so the reason names every op instead.
#
# KNOWN MISSES, stated rather than prevented:
#   - A SYMLINK. The test is on the path the tool names, not on what it resolves to, so an Edit of
#     a link whose target is the snapshot passes. Resolving it would cost a fork per call on every
#     file-tool call in the session.
#   - AN UNPARSEABLE PAYLOAD. A payload jq refuses (a lone high surrogate `\ud800` in new_string
#     is the known one) yields no path, and the call is allowed. `ai-dlc-foreground-budget.sh`
#     denies that shape for Bash because a Bash payload's command is the subject; here the subject
#     is a path field, and a deny on every unparseable file-tool call would refuse unrelated edits.
#   - No `jq`: allowed, as every hook here fails open without it.
#
# COST: one jq read (one fork). The deny is emitted by printf, a builtin, from a static string.
#
# PROTOCOL. PreToolUse hook: reads the tool call as JSON on stdin; a deny is
# `permissionDecision: "deny"` on stdout, never exit code 2, the contract `ai-dlc-protect.sh`
# established. Silence (exit 0, no output) leaves the call to the normal permission flow. It
# always exits 0.
#
# Compatible with bash 3.2.

set -u

command -v jq >/dev/null 2>&1 || exit 0

P="$(jq -r 'if (.tool_input | type) != "object" then ""
  elif .tool_name == "NotebookEdit" then (.tool_input.notebook_path // "")
  elif (.tool_name == "Edit" or .tool_name == "Write" or .tool_name == "MultiEdit") then (.tool_input.file_path // "")
  else "" end | tostring' 2>/dev/null)" || exit 0

case "$P" in
  [Pp][Ii][Pp][Ee][Ll][Ii][Nn][Ee]-[Ss][Nn][Aa][Pp][Ss][Hh][Oo][Tt].[Mm][Dd]|*/[Pp][Ii][Pp][Ee][Ll][Ii][Nn][Ee]-[Ss][Nn][Aa][Pp][Ss][Hh][Oo][Tt].[Mm][Dd]) ;;
  *) exit 0 ;;
esac

# The reason carries no double quote and no backslash, so it is valid inside the JSON string as is.
printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"AI/DLC: pipeline-snapshot.md is written only by scripts/ai-dlc/snapshot-update.sh, which judges the stamps it adds before it writes, so a file-tool write of the snapshot is refused. Make the change as ONE Bash call to that script, nothing chained after it; ops apply in order, and <section> is the heading text after ## (a prefix match). Ops: --set <key> <value> [<section>], --set-block <section> <key> <file>, --key-delete <section> <key>, --line-add <section> <text> [--bottom], --line-replace <section> <match> <text>, --line-delete <section> <match>, --move-to-history <section> <match>, --activity <text>, --open-item <text>, --open-item-file <file>, --close-item <match>, --row-add <c1 | c2 | ...>, --row-replace <agent> <row>, --row-status <agent> <status>, --row-set <agent> <col> <value>, --row-delete <agent>, --section-add <heading>, --section-move-to-history <heading>, --init <step-file> <sprint-id>. A section holding a <!-- FILL ... --> placeholder line: in Pipeline Position and Sprint Context, --line-delete <section> '\''<!-- FILL'\'' removes the placeholder, then one --set <key> <value> <section> per key writes the keys (--set refuses a key outside its create allowlist); in any other section, such as Deploy Baseline, --line-replace <section> '\''<!-- FILL'\'' <text> replaces the placeholder, then --line-add <section> <text> adds each further line. --help prints the full grammar."}}'
exit 0
