#!/usr/bin/env bash
# snapshot-archive-rotate/seed.sh — build a throwaway git repo holding a snapshot history
# shaped like the real one, and print the work directory on the last line.
#
# THE SEED'S SHAPE IS THE POINT, and it is copied from a measurement rather than invented.
# On the reference consumer the live history matches `^## ` 163 times and those are NOT 163
# entries: an archived snapshot is pasted in verbatim and brings its own seven section
# headings with it, and one line is a sentence that merely begins `## Deploy Baseline`. A
# seed made of N tidy one-heading entries would let a rotator that treats every `^## ` as a
# separate entry pass, which is exactly the rotator that shreds a real file.
#
# So this seeds all three shapes: plain entries, one entry carrying a nested verbatim
# snapshot with its own `## ` sections, and one prose line starting with `## `.
set -uo pipefail

WORK="$(mktemp -d "${TMPDIR:-/tmp}/aidlc-snaprotate-fx.XXXXXX")" || exit 2
PROJ="$WORK/proj"
mkdir -p "$PROJ/_bmad-output" || exit 2

HIST="$PROJ/_bmad-output/pipeline-snapshot-history.md"

# --- preamble: the four lines that must never move -------------------------------------
{
  echo "# Pipeline Snapshot — History (write-only; never whole-read)"
  echo
  echo "Superseded narrative cut verbatim from \`pipeline-snapshot.md\` at gate passages."
  echo
} > "$HIST"

# --- 12 plain entries ------------------------------------------------------------------
i=1
while [ "$i" -le 12 ]; do
  {
    echo "## MOVED 2026-08-0${i} — superseded narrative block ${i}"
    echo
    echo "PLAINLINE-${i}: a substantive line of at least twenty characters, entry ${i}."
    echo "PLAINTAIL-${i}: a second substantive line so the entry spans more than one."
    echo
  } >> "$HIST"
  i=$((i + 1))
done

# --- one entry carrying a nested verbatim snapshot ---------------------------------------
# Seven section headings inside ONE entry. A rotator that counts these as seven entries
# will report the wrong move count and split them apart.
{
  echo "## Archived 2026-08-20T09:00:00Z — pre-trim snapshot, verbatim"
  echo
  echo "NESTEDLEAD: the line that introduces the pasted snapshot below, substantive."
  echo
  for s in "Pipeline Position" "Sprint Context" "Recent Activity" "Open Items" \
           "Locked Decisions" "In-Flight Teammates" "Context Reminders"; do
    echo "## ${s}"
    echo
    echo "NESTED-${s// /-}: a substantive body line belonging to the archived snapshot."
    echo
  done
} >> "$HIST"

# --- one prose line that merely starts with '## ' ----------------------------------------
{
  echo "## MOVED 2026-08-21 — the entry that quotes a heading in prose"
  echo
  echo "QUOTELEAD: the remedy text names the out-of-schema section, quoted below verbatim."
  echo "## Deploy Baseline\` via a hardcoded shell \`case\` — this is a sentence, not a heading."
  echo
} >> "$HIST"

# --- 6 more plain entries, the newest ------------------------------------------------------
i=13
while [ "$i" -le 18 ]; do
  {
    echo "## MOVED 2026-08-2${i} — superseded narrative block ${i}"
    echo
    echo "PLAINLINE-${i}: a substantive line of at least twenty characters, entry ${i}."
    echo
  } >> "$HIST"
  i=$((i + 1))
done

# --- a stale snapshot for the --absorb arm ------------------------------------------------
STALE="$PROJ/_bmad-output/pipeline-snapshot.md"
{
  echo "# Pipeline Snapshot"
  echo
  echo "## Pipeline Position"
  echo "STALESNAP: a substantive line from the stale snapshot absorbed at fresh start."
  echo
} > "$STALE"

# --- a second, boundary-free history for the refusal arm ------------------------------------
NOBOUND="$PROJ/_bmad-output/no-boundaries-history.md"
{
  echo "# Pipeline Snapshot — History"
  echo
  echo "NOBOUNDLINE: a substantive line in a file that carries no heading at all."
  echo "NOBOUNDTAIL: a second substantive line, still no heading anywhere in the file."
} > "$NOBOUND"

( cd "$PROJ" \
  && git init -q . \
  && git add -A \
  && git -c user.email=fixture@ai-dlc -c user.name=fixture commit -qm "seed" ) || exit 2

cat > "$WORK/env.sh" <<EOF
PROJ="$PROJ"
HIST="$HIST"
STALE="$STALE"
NOBOUND="$NOBOUND"
ARCHIVE="$PROJ/_bmad-output/pipeline-history/pipeline-snapshot-archive.md"
EOF

echo "$WORK"
