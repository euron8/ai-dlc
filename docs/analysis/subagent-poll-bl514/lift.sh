#!/usr/bin/env bash
# BL-514 rule lift, sourced by classify.sh and join.sh so the two read ONE copy.
#
# bl514_lift HOOK WORK
#   Writes WORK/prelude.jq (the hook's four jq defs cmdpos, loopend, loopsleep,
#   longsleep, each lifted exactly once, verbatim) and sets REASON (the deny
#   reason substring, lifted from the hook's one REASON line).
#   Calls die2 (defined by the sourcing script) on any failure.
# The lift is never retyped: an edited or renamed def, or a second copy, refuses.

bl514_lift() {
  local HOOK="$1" WORK="$2" name c
  : > "$WORK/prelude.jq"
  for name in cmdpos loopend loopsleep longsleep; do
    c="$(awk -v p="  def ${name}:" 'index($0, p) == 1 { c++ } END { print c + 0 }' "$HOOK")" || die2 "awk failed on $HOOK"
    [ "$c" = "1" ] || die2 "def ${name} matched ${c} time(s) in $HOOK, need exactly 1"
    awk -v p="  def ${name}:" 'index($0, p) == 1 { print }' "$HOOK" >> "$WORK/prelude.jq"
  done

  c="$(awk 'index($0, "FOREGROUND Bash call is a poll") > 0 { c++ } END { print c + 0 }' "$HOOK")" || die2 "awk failed on $HOOK"
  [ "$c" = "1" ] || die2 "deny reason line matched ${c} time(s) in $HOOK, need exactly 1"
  REASON="$(awk 'index($0, "FOREGROUND Bash call is a poll") > 0 {
    s = index($0, "this subagent"); e = index($0, "is a poll")
    if (s > 0 && e > s) print substr($0, s, e + 9 - s)
  }' "$HOOK")" || die2 "awk failed lifting the reason"
  [ -n "$REASON" ] || die2 "could not lift the reason substring from $HOOK"
  case "$REASON" in *'${'*) die2 "lifted reason carries a shell expansion" ;; esac
}

# bl514_extract LIST EVENTS
#   Runs $WORK/extract.jq over every file named in LIST (one path per line), appending
#   one row stream to EVENTS. The programs stamp each row with input_filename, so one
#   jq reads BL514_BATCH (default 500) files; batches run serially, in list order, so the
#   rows are byte-equal to a one-jq-per-file loop. Sets OPENED to the number of files read.
#   A file that cannot be read, or that jq fails on, makes its batch fall back to one jq
#   per file, which names the file and calls die2 (exit 2). Needs REASON and WORK set.
bl514_extract() {
  local list="$1" ev="$2" f n=0 batch="${BL514_BATCH:-500}" tmp="$WORK/batch.out"
  local -a files
  OPENED=0
  : > "$ev"
  files=()
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ -f "$f" ] && [ -r "$f" ] || die2 "listed file not readable: $f"
    files[${#files[@]}]="$f"
    n=$((n + 1))
    if [ "$n" -ge "$batch" ]; then
      _bl514_run_batch "$ev" "$tmp" "${files[@]}"
      files=(); n=0
    fi
  done < "$list"
  if [ "$n" -gt 0 ]; then _bl514_run_batch "$ev" "$tmp" "${files[@]}"; fi
}

_bl514_run_batch() {
  local ev="$1" tmp="$2" f
  shift 2
  if jq -c --arg reason "$REASON" -f "$WORK/extract.jq" "$@" > "$tmp" 2>/dev/null; then
    cat "$tmp" >> "$ev"
    OPENED=$((OPENED + $#))
  else
    for f in "$@"; do
      jq -c --arg reason "$REASON" -f "$WORK/extract.jq" "$f" > /dev/null || die2 "jq failed reading $f"
    done
    die2 "a batch failed as a whole but each of its files read alone; refusing"
  fi
}
