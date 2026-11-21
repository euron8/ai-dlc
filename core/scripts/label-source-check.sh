#!/usr/bin/env bash
# label-source-check.sh -- does a held, deferred or operator-labelled backlog item carry a resolvable operator source?
#
#   label-source-check.sh --items ID[,ID...] [--sprint N] [--backlog FILE] [--history-dir DIR]
#   label-source-check.sh --all              [--sprint N] [--backlog FILE] [--history-dir DIR]   (measurement; reads every item)
#
# Called at two sites with one program: carry-over evaluation (items a sprint takes into scope, whatever
# sprint wrote the label) and implementation exit (items whose label this sprint wrote). It never blocks:
# exit 0 whatever it finds (2 only for a usage error). An unresolved label is printed as ONE operator
# decision with the recommendation "keep it as labelled", for the lead to put as a pending decision
# (SKILL.md Rule 11(a), "proceed on the recommendation").
#
# ITEM    a markdown heading (## or ###) whose first CO-<token> (else first word) is its id, and the first
#         `**Status:**` line after it. A file with no such item, or an absent file, is SKIPPED (exit 0).
# LABEL   the Status line contains held, hold, deferred, operator-held, operator directive or
#         operator-labelled (case-insensitive). Any other item is not checked.
# SOURCE  on the Status line: `operator-requests-history.md:<N>` or `operator-answers-history.md:<N>` beside
#         a double-quoted quote of 12 or more characters, or `operator-answers-history.md SHA256 <64 hex>`.
#         A line locator resolves when a quote on the Status line is found, whitespace collapsed, in line N
#         of that file in the history dir (when line N is a `## ` heading: in that entry, up to the next
#         `## `). The SHA locator resolves when the file holds `- SHA256: <hex>`.
# SNAPSHOT  pass the item token `pipeline-snapshot` to also check every line of the pipeline snapshot that names an
#         operator-held, operator-deferred, operator-labelled or operator directive label (id pipeline-snapshot:<line>).
# BACKED  at least one operator locator and every one resolves.   STALE  a locator does not resolve.
# UNBACKED  a label with no operator locator.
#
# A `DP-<s>-<n>` token on the Status line resolves when a `**Veto window:** closed — DP-<s>-<n> — <history>:<line>` line in
# docs/escalations/*.md names a history line that exists (SKILL.md Rule 11(a)); it needs no quote.
#
# A snapshot row (id pipeline-snapshot:<line>) is closed by ONE `operator source: for "<text of the row>" <locator> "<quote>"`
# line under Recent Activity (snapshot-update.sh --activity); that line is a record, never itself a row.
#
# RECORDING THE ANSWER: the lead writes `operator source: <history file>:<line of the reply's entry>
# "<verbatim quote>"` onto the item's Status line; this program resolves it, so the item is never asked again.
set -u

# --- AI_DLC_ROOT ------------------------------------------------------------
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
[ -n "$AI_DLC_ROOT" ] || { echo "label-source-check: cannot resolve the project root; set AI_DLC_PROJECT_ROOT" >&2; exit 2; }
# --- end AI_DLC_ROOT --------------------------------------------------------

ITEMS=""; ALL=0; SPRINT="<sprint>"; VERBOSE=0
BACKLOG="$AI_DLC_ROOT/_bmad-output/planning-artifacts/carry-over-backlog.md"
HDIR="$AI_DLC_ROOT/_bmad-output"
SNAP="$AI_DLC_ROOT/_bmad-output/pipeline-snapshot.md"
EDIR="$AI_DLC_ROOT/docs/escalations"
while [ $# -gt 0 ]; do
  case "$1" in
    --items)       [ $# -ge 2 ] || { echo "label-source-check: --items needs a value" >&2; exit 2; }; ITEMS="$2"; shift 2 ;;
    --all)         ALL=1; shift ;;
    --sprint)      [ $# -ge 2 ] || { echo "label-source-check: --sprint needs a value" >&2; exit 2; }; SPRINT="$2"; shift 2 ;;
    --backlog)     [ $# -ge 2 ] || { echo "label-source-check: --backlog needs a value" >&2; exit 2; }; BACKLOG="$2"; shift 2 ;;
    --history-dir) [ $# -ge 2 ] || { echo "label-source-check: --history-dir needs a value" >&2; exit 2; }; HDIR="$2"; shift 2 ;;
    --snapshot)    [ $# -ge 2 ] || { echo "label-source-check: --snapshot needs a value" >&2; exit 2; }; SNAP="$2"; shift 2 ;;
    -v)            VERBOSE=1; shift ;;
    *) echo "label-source-check: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
if [ "$ALL" -eq 0 ] && [ -z "$ITEMS" ]; then
  echo "usage: label-source-check.sh (--items ID[,ID...] | --all) [--sprint N] [--backlog FILE] [--snapshot FILE] [--history-dir DIR] [-v]" >&2
  exit 2
fi
[ -f "$BACKLOG" ] || [ -f "$SNAP" ] || { echo "LABEL-SOURCE: SKIPPED -- no backlog at $BACKLOG and no snapshot at $SNAP"; exit 0; }

# id <TAB> collapsed Status line, one row per item that has a Status line
rows="$(awk '
  /^##+ / { h = $0; sub(/^##+ +/, "", h); id = ""
            if (match(h, /CO-[A-Za-z0-9_.-]+/)) id = substr(h, RSTART, RLENGTH); else { split(h, w, " "); id = w[1] }
            have = 0; next }
  id != "" && !have && /^\*\*Status:\*\*/ { s = $0; gsub(/[ \t]+/, " ", s); print id "\t" s; have = 1 }
' "$BACKLOG" 2>/dev/null)"
# The pipeline snapshot carries sprint-state labels in prose (id pipeline-snapshot:<line>; selected by the
# item token `pipeline-snapshot`): a line naming an operator hold, deferral or directive is one labelled row.
if [ -f "$SNAP" ]; then
  srows="$(awk 'tolower($0) !~ /operator source:/ && tolower($0) ~ /operator[- ](held|hold|deferred|labelled|labeled|directive)|held by operator/ { s = $0; gsub(/[ \t]+/, " ", s); print "pipeline-snapshot:" NR "\t" s }' "$SNAP")"
  [ -z "$srows" ] || rows="$rows${rows:+
}$srows"
fi
nrows=0
[ -n "$rows" ] && nrows="$(printf '%s\n' "$rows" | grep -c .)"
if [ "$nrows" -eq 0 ]; then echo "LABEL-SOURCE: SKIPPED -- no item with a Status line in $BACKLOG and no labelled snapshot line in $SNAP"; exit 0; fi

# hist_text <file> <line> -> the collapsed text a locator points at
hist_text() {
  awk -v n="$2" 'NR == n { if ($0 ~ /^## /) { h = 1; t = $0; next } else { print $0; exit } }
                 h && /^## / { print t; exit } h { t = t " " $0 } END { if (h) print t }' "$1" | tr -s '[:space:]' ' '
}

checked=0; labelled=0; backed=0; stale=0; unbacked=0; unlabelled=0; bad_ids=""; found_ids=" "
report=""
LABEL_RE='(^|[^[:alnum:]])(held|hold|deferred|operator-held|operator directive|operator-labelled|operator-labeled)([^[:alnum:]]|$)'
while IFS="$(printf '\t')" read -r id st; do
  [ -n "$id" ] || continue
  key="$id"; case "$id" in pipeline-snapshot:*) key="pipeline-snapshot" ;; esac
  if [ "$ALL" -eq 0 ]; then
    case ",$ITEMS," in *",$key,"*) ;; *) continue ;; esac
  fi
  found_ids="$found_ids$key "
  checked=$((checked + 1))
  if ! printf '%s\n' "$st" | tr '[:upper:]' '[:lower:]' | grep -Eq "$LABEL_RE"; then unlabelled=$((unlabelled + 1)); continue; fi
  labelled=$((labelled + 1))
  case "$id" in pipeline-snapshot:*)
    # A snapshot row has no Status line. Its record is a line the lead writes ONCE under Recent Activity,
    # `operator source: for "<verbatim text of the row>" <locator> "<quote>"`; the row takes its locators.
    while IFS= read -r rec; do
      fx="$(printf '%s\n' "$rec" | grep -oE 'for "[^"]{12,}"' | head -1 | sed 's/^for "//; s/"$//' || true)"
      [ -n "$fx" ] || continue
      case "$st" in *"$fx"*) st="$st $rec" ;; esac
    done < <(grep -i 'operator source:' "$SNAP" | tr -s ' \t' ' ')
    ;;
  esac
  locs="$(printf '%s\n' "$st" | grep -oE 'operator-(requests|answers)-history\.md(:[0-9]+| SHA256 [0-9a-f]{64})|DP-[0-9]+-[0-9]+' || true)"
  if [ -z "$locs" ]; then
    unbacked=$((unbacked + 1)); report="${report}  unbacked  ${id}  (no operator locator on the Status line)
"; continue
  fi
  quotes="$(printf '%s\n' "$st" | grep -oE '"[^"]{12,}"' | sed 's/^"//; s/"$//' | tr -s ' \t' ' ' || true)"
  bad=""; nloc=0
  while IFS= read -r loc; do
    [ -n "$loc" ] || continue
    nloc=$((nloc + 1)); f="${loc%%.md*}.md"; ok=0
    case "$loc" in DP-*) ;; *) if [ ! -f "$HDIR/$f" ]; then bad="$bad $loc(no such file)"; continue; fi ;; esac
    case "$loc" in
      DP-*) w="$(cat "$EDIR"/*.md 2>/dev/null | grep -F '**Veto window:**' | grep -F "closed — $loc — " | head -1 | grep -oE 'operator-(requests|answers)-history\.md:[0-9]+' | head -1 || true)"
            if [ -n "$w" ] && [ -f "$HDIR/${w%%:*}" ] && [ -n "$(hist_text "$HDIR/${w%%:*}" "${w##*:}" | tr -d ' ')" ]; then ok=1; fi ;;
      *" SHA256 "*) h="${loc##* }"; grep -qxF -- "- SHA256: $h" "$HDIR/$f" && ok=1 ;;
      *) n="${loc##*:}"; txt="$(hist_text "$HDIR/$f" "$n")"
         while IFS= read -r q; do
           q="${q# }"; q="${q% }"
           [ "${#q}" -ge 12 ] || continue
           case "$txt" in *"$q"*) ok=1; break ;; esac
         done < <(printf '%s\n' "$quotes" | tr -d '\r') ;;
    esac
    [ "$ok" -eq 1 ] || bad="$bad $loc"
  done <<EOF
$locs
EOF
  if [ -n "$bad" ]; then
    stale=$((stale + 1)); report="${report}  stale     ${id}  (does not resolve:${bad})
"
  else
    backed=$((backed + 1)); [ "$VERBOSE" -eq 1 ] && report="${report}  backed    ${id}
"
  fi
done <<EOF
$rows
EOF

if [ "$ALL" -eq 0 ]; then
  [ -f "$SNAP" ] && found_ids="${found_ids}pipeline-snapshot "
  oldifs="$IFS"; IFS=','
  for i in $ITEMS; do case "$found_ids" in *" $i "*) ;; *) bad_ids="$bad_ids $i" ;; esac; done
  IFS="$oldifs"
fi
echo "LABEL-SOURCE: checked=$checked labelled=$labelled backed=$backed stale=$stale unbacked=$unbacked unlabelled=$unlabelled notfound=$(printf '%s' "$bad_ids" | wc -w | tr -d ' ')${bad_ids:+ ($bad_ids )}"
[ -n "$report" ] && printf '%s' "$report"
if [ $((stale + unbacked)) -gt 0 ]; then
  cat <<EOF
LABEL-SOURCE: DECISION to surface -- ${stale} stale and ${unbacked} unbacked label(s) listed above. This never blocks.
  1. Put them as ONE operator decision with the recommendation "keep it as labelled" (SKILL.md Rule 11(a): a
     DP-${SPRINT}-<n> pending decision, work dispatched under the recommendation; work under a kept hold is nothing).
     Header: "Operator source for held/deferred labels".
  2. When the operator answers and the window closes, write onto each listed backlog item's Status line its
     DP-${SPRINT}-<n> id, or: operator source: <history file>:<line of the reply's entry> "<verbatim quote>"
     (or its SHA256 locator). A listed pipeline-snapshot:<line> row has no Status line: write ONE record once,
     snapshot-update.sh --activity 'operator source: for "<verbatim text of the row, 12+ chars>" <history file>:<line> "<verbatim quote>"'
     (or its DP-${SPRINT}-<n> id in place of the locator and quote); the row then reads backed. This program then
     reports the item backed, and it is never asked again.
  3. A label the operator corrects or drops is edited on the item before the work is planned.
EOF
fi
exit 0
