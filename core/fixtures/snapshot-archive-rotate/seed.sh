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
  echo "- story 4.2, the login flow, gate G3 pending review by the lead"
  echo
  echo "## Open Items"
  echo "- OPEN-ITEM-A: retry the flaky deploy check before the next gate"
  echo "- OPEN-ITEM-B: confirm the rollback window with operations"
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

# --- the absorb worlds: pristine templates, copied fresh for every drive ---------------------
# Each is a whole consumer state on its own: a git repo holding `_bmad-output/`, with exactly
# the files named and nothing else. run.sh never drives a template; it copies one first, so a
# mutant or an earlier arm can never leave a file behind for the next reader.
#
#   nohist  — stale snapshot, NO history file (a fresh consumer: the only path it ever takes)
#   floor   — stale snapshot, history with exactly 10 cut points = the default --keep-entries,
#             so the history does not rotate (the shape measured live on the reference consumer)
#   above   — stale snapshot, history with 14 cut points, so the history rotates (the control)
#   nosnap  — history, NO snapshot at all: a tree where no pipeline is active
#   ignored — stale snapshot, no history, and the archive directory git-ignored
TMPL="$WORK/tmpl"
mk_world() {  # <name> <history cut points, or 0 for no history> <snapshot yes|no> <ignore yes|no>
  local w="$TMPL/$1" i=0
  mkdir -p "$w/_bmad-output" || exit 2
  if [ "$2" -gt 0 ]; then
    {
      echo "# Pipeline Snapshot — History (write-only; never whole-read)"
      echo
      while [ "$i" -lt "$2" ]; do
        i=$((i + 1))
        printf '## [MOVED 2026-09-01T10:00:%02dZ from pipeline-snapshot.md — gate]\n\n' "$i"
        printf 'HISTLINE-%s-%s: a substantive history body line for this entry.\n\n' "$1" "$i"
      done
    } > "$w/_bmad-output/pipeline-snapshot-history.md"
  fi
  # Several DISTINCT lines, only ONE of which carries the marker: an absorb that copies the
  # marker line and drops the rest (measured: `grep STALE` in place of `cat`) must be
  # distinguishable from a whole-file copy, and the arms compare the archive's tail to this
  # template byte for byte.
  if [ "$3" = yes ]; then
    {
      echo "# Pipeline Snapshot"
      echo
      echo "## Pipeline Position"
      echo "STALESNAP-$1: a substantive line from the stale snapshot absorbed at fresh start."
      echo "- story 4.2, the login flow, gate G3 pending review by the lead ($1)"
      echo
      echo "## Open Items"
      echo "- OPEN-ITEM-A-$1: retry the flaky deploy check before the next gate"
      echo "- OPEN-ITEM-B-$1: confirm the rollback window with operations"
      echo
    } > "$w/_bmad-output/pipeline-snapshot.md"
  fi
  [ "$4" = yes ] && printf '_bmad-output/pipeline-history/\n' > "$w/.gitignore"
  ( cd "$w" && git init -q . && git add -A \
    && git -c user.email=fixture@ai-dlc -c user.name=fixture commit -qm "seed $1" ) >/dev/null 2>&1 || exit 2
}
mk_world nohist  0  yes no
mk_world floor   10 yes no
mk_world above   14 yes no
mk_world nosnap  14 no  no
mk_world ignored 0  yes yes

# bigtail — for the history-REWRITE failure arm. Sized so that under `ulimit -f 8` (8192 bytes)
# every file the rotator writes before the rewrite fits, and the rewritten history does not:
# the preamble alone and the kept tail alone are each under 8192 (the rotator's own temp copies
# of them must be written whole, or the line-accounting refusal fires first and the rewrite is
# never reached), the archive (header + 4 moved entries + the absorbed snapshot) is well under,
# and preamble + tail is over. run.sh asserts all four sizes before it reads the arm's verdict.
mk_world bigtail 0 yes no
{
  echo "# Pipeline Snapshot — History (write-only; never whole-read)"
  echo
  i=0; while [ "$i" -lt 22 ]; do i=$((i + 1))
    printf 'PREAMBLE-%02d: a long preamble line that stays in the live history across every rotation.\n' "$i"
  done
  echo
  i=0; while [ "$i" -lt 14 ]; do i=$((i + 1))
    printf '## [MOVED 2026-09-02T10:00:%02dZ from pipeline-snapshot.md — gate]\n\n' "$i"
    j=0; while [ "$j" -lt 7 ]; do j=$((j + 1))
      printf 'BIGLINE-%02d-%02d: a substantive history body line, long enough to give the tail weight.\n' "$i" "$j"
    done
    echo
  done
} > "$TMPL/bigtail/_bmad-output/pipeline-snapshot-history.md"
( cd "$TMPL/bigtail" && git add -A \
  && git -c user.email=fixture@ai-dlc -c user.name=fixture commit -qm "bigtail history" ) >/dev/null 2>&1 || exit 2

cat > "$WORK/env.sh" <<EOF
PROJ="$PROJ"
HIST="$HIST"
STALE="$STALE"
NOBOUND="$NOBOUND"
ARCHIVE="$PROJ/_bmad-output/pipeline-history/pipeline-snapshot-archive.md"
TMPL="$TMPL"
EOF

echo "$WORK"
