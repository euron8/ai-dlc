#!/usr/bin/env bash
# validate-held-stories.sh -- every ready-for-dev story of the sprint is either dispatched or held,
# and every hold names its unblock action, is not stale, and is not old.
#
# THE DEFECT (BL-839). A story the lead decides to hold (a wave-2 story waiting on its predecessor,
# a story waiting on an amendment) lived only in the lead's context. A compaction dropped it, and
# nothing at a wave join or at implementation's exit noticed a story that was neither in flight nor
# held: it stayed `ready-for-dev` and the sprint moved on without it.
#
# THE GRAMMAR (this header is its one home; every prose carrier cites it). A hold is ONE line under
# `## Open Items` in pipeline-snapshot.md:
#
#   - held: <story-id> until <unblock action> since <epoch>
#
#   <story-id>       one word: the sprint-status yaml key (`story-320-4`), the `<epic>.<index>` form
#                    (`2.1`) or the `story-<epic>-<index>` stem (`story-2-1`), the last two derived
#                    from the entry's `file:` basename
#   <unblock action> free text, non-empty, with no ` since ` inside it
#   <epoch>          integer seconds (`date +%s`) at which the hold was written or last re-confirmed
#
# The lead writes it with `snapshot-update.sh --open-item 'held: <id> until <action> since <epoch>'`
# when it holds a story, and removes it with `snapshot-update.sh --close-item 'held: <id> '` when it
# dispatches the story. The TRAILING SPACE in the close-item substring is required: it is what
# keeps `held: story-320-1 ` from also matching `held: story-320-10 ...`.
#
# ACCOUNTED. A story is accounted when its implementation-view status is not `ready-for-dev`, or it
# has a hold line, or an In-Flight Teammates row of ANY status names it in its role or deliverable
# cell. A cell names a story when it carries the yaml key, `story <epic>.<index>` or
# `story-<epic>-<index>` (the file stem carries the last), bounded so `1.3` is not `1.30` and
# `story-320-1` is not `story-320-10`. A dispatched story stays ready-for-dev until gate 1, which is
# why a row is evidence and the status alone is not. The spawn ledger is NEVER read: its dev and ops
# rows carry no story token (14 of 14 on the reference consumer's s320).
#
# FINDINGS (stdout, one per line; the second form in parentheses is `-` when the file is not a
# `story-<e>-<i>-*.md`):
#   UNACCOUNTED <key> (<e>.<i>)          ready-for-dev, no hold, no row
#   STALE-HOLD <key> (<e>.<i>)           a hold on a story already past ready-for-dev: close it
#   AGED-HOLD <key> (<e>.<i>) <hours>h   now - since exceeds AI_DLC_HOLD_MAX_HOURS (default 4):
#                                        take the unblock action, or re-confirm and re-stamp `since`
#   MALFORMED-HOLD <line>                an Open Items line opening `- held:` that does not parse
#
# usage: validate-held-stories.sh [--root <dir>] [--snapshot <path>]
#   --root defaults to the project root found by walking up for a marker (never by counting `..`);
#   --snapshot defaults to <root>/${AI_DLC_STATE_DIR:-_bmad-output}/pipeline-snapshot.md.
#   The stories come from the sibling `sprint-status.sh list-stories --root <root>`; this program
#   never parses the yaml itself. AI_DLC_NOW (integer seconds) overrides the clock.
#
# exit: 0 clean; 1 any finding; 2 unevaluable -- no snapshot, no `## Open Items` section, the sibling
#   absent or exiting non-zero or printing a line that is not three tab-separated fields, a bad
#   AI_DLC_NOW / AI_DLC_HOLD_MAX_HOURS, or the self-probe failing. Never a silent pass on an absent
#   input. An EMPTY list-stories answer (exit 0) is a sprint with no stories, accounted trivially.
#
# SELF-PROBE. Before the real read the evaluator runs over a mktemp world of two ready-for-dev
# stories, one held by its yaml key: the unheld one must be reported UNACCOUNTED and the held one
# must not be. Either direction failing is exit 2, so an evaluator that cannot fire, or fires on
# everything, never reads as clean.
set -u

# --- AI_DLC_ROOT ------------------------------------------------------------
# Walk UP for a marker, never a fixed number of `..` hops: this runs from <root>/core/scripts/ and
# from a consumer's <root>/scripts/ai-dlc/. Inline on purpose, as in every script that needs it.
ai_dlc_resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "held-stories: UNEVALUABLE -- cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root, or pass --root." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------

unevaluable() { printf 'held-stories: UNEVALUABLE -- %s\n' "$1" >&2; exit 2; }

ROOT=""; SNAP=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root)     [ $# -ge 2 ] && [ -n "$2" ] || unevaluable "--root needs a directory"; ROOT="$2"; shift 2 ;;
    --snapshot) [ $# -ge 2 ] && [ -n "$2" ] || unevaluable "--snapshot needs a path"; SNAP="$2"; shift 2 ;;
    -h|--help)  sed -n '2,58p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)          unevaluable "unknown argument '$1'" ;;
  esac
done
[ -n "$ROOT" ] || ROOT="$AI_DLC_ROOT"
[ -d "$ROOT" ] || unevaluable "the project root $ROOT is not a directory"
ROOT="$(cd "$ROOT" && pwd)"
[ -n "$SNAP" ] || SNAP="$ROOT/${AI_DLC_STATE_DIR:-_bmad-output}/pipeline-snapshot.md"

NOW="${AI_DLC_NOW:-$(date +%s)}"
case "$NOW" in ''|*[!0-9]*) unevaluable "AI_DLC_NOW '$NOW' is not integer seconds" ;; esac
MAXH="${AI_DLC_HOLD_MAX_HOURS:-4}"
case "$MAXH" in ''|*[!0-9]*) unevaluable "AI_DLC_HOLD_MAX_HOURS '$MAXH' is not a whole number of hours" ;; esac

# evaluate <stories.tsv> <snapshot> -> findings on stdout; awk exit 0 clean, 1 findings, 3 no Open Items
evaluate() {
  awk -F '\t' -v now="$NOW" -v maxs="$((MAXH * 3600))" '
    function has_lit(t, needle,    s, p, off, a, pre, post) {
      if (needle == "") return 0
      s = t; off = 0
      while ((p = index(s, needle)) > 0) {
        a = off + p
        pre = (a == 1) ? "" : substr(t, a - 1, 1)
        post = substr(t, a + length(needle), 1)
        if (pre !~ /[a-z0-9]/ && post !~ /[0-9]/) return 1
        off = a; s = substr(t, off + 1)
      }
      return 0
    }
    function row_names(t, k) {
      return has_lit(t, tolower(key[k])) || has_lit(t, stem[k]) || (ei[k] != "" && has_lit(t, "story " ei[k]))
    }
    function hold_story(id,    k) {
      for (k = 1; k <= n; k++)
        if (id == key[k] || id == ei[k] || id == stem[k]) return k
      return 0
    }
    function label(k) { return key[k] " (" (ei[k] == "" ? "-" : ei[k]) ")" }
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    # Keyed on the file NAME, never `FNR == NR`: an EMPTY stories answer (a sprint with no
    # entries) would otherwise make the snapshot read as the stories file.
    FILENAME == ARGV[1] {
      n++; key[n] = $1; st[n] = $2; b = $3; sub(/.*\//, "", b)
      ei[n] = ""; stem[n] = ""
      if (match(b, /^story-[0-9]+-[0-9]+/)) {
        stem[n] = substr(b, 1, RLENGTH); x = substr(b, 7, RLENGTH - 6); split(x, q, "-"); ei[n] = q[1] "." q[2]
      }
      next
    }
    { sub(/\r$/, "") }
    /^## / { sec = trim(substr($0, 4)); if (sec == "Open Items") oi = 1; hdr = 0; next }
    sec == "Open Items" && /^-[ \t]*held:/ {
      L = $0; sub(/[ \t]+$/, "", L)
      ok = (L ~ /^- held: [^ ]+ until [^ ].* since [0-9]+$/)
      if (ok) {
        split(L, w, " "); id = w[3]
        match(L, / since [0-9]+$/); since = substr(L, RSTART + 7)
        act = substr(L, length("- held: " id " until ") + 1); act = substr(act, 1, length(act) - (length(L) - RSTART + 1))
        if (index(act, " since ") > 0 || trim(act) == "") ok = 0
      }
      if (!ok) { print "MALFORMED-HOLD " L; f++; next }
      nh++; hid[nh] = id; hs[nh] = since + 0
      next
    }
    sec == "In-Flight Teammates" && /\|/ {
      line = $0; sub(/^[ \t]*\|/, "", line); sub(/\|[ \t]*$/, "", line)
      nc = split(line, c, "|")
      if (trim(c[1]) ~ /^-+$/) next
      if (!hdr) {
        hdr = 1; ri = 2; di = 3
        for (j = 1; j <= nc; j++) { h = tolower(trim(c[j])); if (h == "role") ri = j; if (h == "deliverable") di = j }
        next
      }
      rows = rows " | " tolower(c[ri]) " | " tolower(c[di])
      next
    }
    END {
      if (!oi) exit 3
      for (h = 1; h <= nh; h++) {
        k = hold_story(hid[h]); if (!k) continue
        held[k] = 1
        if (st[k] != "ready-for-dev") { print "STALE-HOLD " label(k); f++; continue }
        if (now - hs[h] > maxs) { printf "AGED-HOLD %s %dh\n", label(k), int((now - hs[h]) / 3600); f++ }
      }
      for (k = 1; k <= n; k++) {
        if (st[k] != "ready-for-dev" || held[k]) continue
        if (row_names(rows, k)) continue
        print "UNACCOUNTED " label(k); f++
      }
      exit (f > 0) ? 1 : 0
    }
  ' "$1" "$2"
}

TSV="$(mktemp "${TMPDIR:-/tmp}/held-stories-tsv.XXXXXX")" || unevaluable "no temp file"
PS="$(mktemp "${TMPDIR:-/tmp}/held-stories-probe-snap.XXXXXX")" || { rm -f "$TSV"; unevaluable "no temp file"; }
PT="$(mktemp "${TMPDIR:-/tmp}/held-stories-probe-tsv.XXXXXX")" || { rm -f "$TSV" "$PS"; unevaluable "no temp file"; }
trap 'rm -f "$TSV" "$PS" "$PT"' EXIT

# --- self-probe: both directions, before the real read ----------------------
printf 'story-9-1\tready-for-dev\tx/story-9-1-held.md\nstory-9-2\tready-for-dev\tx/story-9-2-unheld.md\n' > "$PT"
printf '# probe\n\n## Open Items\n- held: story-9-1 until the probe ends since %s\n\n## In-Flight Teammates\nagent | role | deliverable | dispatched-at | status\n--- | --- | --- | --- | ---\n' "$NOW" > "$PS"
probe="$(evaluate "$PT" "$PS")"; prc=$?
case "$prc:$probe" in
  "1:UNACCOUNTED story-9-2 (9.2)") ;;
  *) unevaluable "self-probe failed (rc $prc, output '$probe'): the evaluator must report the unheld probe story and only it" ;;
esac

# --- the real read ----------------------------------------------------------
[ -f "$SNAP" ] || unevaluable "no snapshot at $SNAP"
LS="$AI_DLC_SELF_DIR/sprint-status.sh"
[ -f "$LS" ] || unevaluable "sprint-status.sh is not beside this program ($AI_DLC_SELF_DIR)"
AI_DLC_PROJECT_ROOT="$ROOT" bash "$LS" list-stories --root "$ROOT" > "$TSV"; lrc=$?
[ "$lrc" -eq 0 ] || unevaluable "sprint-status.sh list-stories exited $lrc"
bad="$(awk -F '\t' 'NF != 3 { print NR; exit }' "$TSV")"
[ -z "$bad" ] || unevaluable "sprint-status.sh list-stories line $bad is not <key>TAB<status>TAB<file>"

evaluate "$TSV" "$SNAP"; rc=$?
nst="$(awk 'END { print NR }' "$TSV")"
case "$rc" in
  0) printf 'held-stories: OK -- %s stories, every ready-for-dev story held or in flight\n' "$nst" ;;
  1) printf 'held-stories: FAIL -- see the findings above; dispatch or hold each UNACCOUNTED story, close each STALE-HOLD, act on or re-stamp each AGED-HOLD, rewrite each MALFORMED-HOLD to the grammar in this script header\n'
     exit 1 ;;
  3) unevaluable "no '## Open Items' section in $SNAP" ;;
  *) unevaluable "the evaluator exited $rc" ;;
esac
exit 0
