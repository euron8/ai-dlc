#!/usr/bin/env bash
# BL-975 measuring script: dispatched-agent deaths in a window, and how long the lead took to hear.
#
# usage: scan.sh --project DIR --from ISO --to ISO [--wfd PATH]
#   DIR   a Claude Code project directory: <sid>.jsonl lead transcripts, <sid>/subagents/agent-*.jsonl
#   ISO   YYYY-MM-DDTHH:MM:SSZ; a death counts when its time t is from <= t < to
#   PATH  the wait-for-deliverable.sh whose two DISPATCH FAILED arms are lifted (default: this tree's
#         core/scripts/wait-for-deliverable.sh)
#
# The two arms are LIFTED from df_scan at run time, never retyped:
#   arm B  the per-agent awk (newest api-request after the last assistant or user line). Run on the
#          whole agent transcript: it sees a death that was never resumed.
#   arm A  the lead-transcript awk (the last task-notification per agent id with status failed). Run on
#          the lead transcript CUT at each failed-notice line, so it answers what a beat at that moment
#          saw: it sees a death that was later resumed.
# A lift that matches other than once, or comes back empty, refuses (exit 2). The self-probe runs
# both lifts on synthetic transcripts in both directions before the corpus is read.
#
# Output, one tab-separated line per death:
#   DEATH|CANDIDATE <sid> <agent id> <arms: A, B, R> <last send|-> <notice|-> <reported|-> <report s|->
#         <resumed|-> <resume s|-> <lead s>
#   R          channel R: a lead line inside the window carrying the lifted report token and the agent
#              id. It sees a death the lead's beat reported and then resumed with no harness notice,
#              which neither arm sees afterwards (the resume closes the request).
#   last send: the open api-request (arm B on the whole transcript; with none open at the end, arm B on
#              the transcript cut at the earlier of the notice and the first report). notice: arm A's
#              failed notice, inside the window. The death is the last send when there is one, else
#              that cut; both latencies count from it.
#   reported: the first lead-transcript line at or after the death carrying the token
#             say_dispatch_failed echoes (lifted, count of one) followed by the agent id.
#   resumed:  the first user or assistant record of the agent's own transcript newer than the death.
#   lead s:   seconds from the death to the lead transcript's newest record. An arm-B-only row whose
#             lead ran on for less than OPEN_REQUEST_SECS (lifted) is a CANDIDATE: no beat of that
#             session could have named it, and it may be a lead that ended mid-request.
# Then SUMMARY and CONTROL lines. Exit 0, or 2 on a refusal.
#
# Limits: arm B on a historical corpus cannot tell a dead agent from one whose lead session ended
# mid-request; both end in an open request (see CANDIDATE). A death later resumed with neither a
# failed notice nor a report line in the lead transcript is seen by no channel.
set -u
die2() { echo "REFUSED: $*" >&2; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="$HERE"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/core/scripts/wait-for-deliverable.sh" ]; do ROOT="$(dirname "$ROOT")"; done
WFD="$ROOT/core/scripts/wait-for-deliverable.sh"
PROJ=""; FROM=""; TO=""
while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJ="${2:-}"; shift 2 ;;
    --from) FROM="${2:-}"; shift 2 ;;
    --to) TO="${2:-}"; shift 2 ;;
    --wfd) WFD="${2:-}"; shift 2 ;;
    *) die2 "unknown argument: $1" ;;
  esac
done
[ -f "$WFD" ] || die2 "no wait-for-deliverable.sh at $WFD"
for v in "$FROM" "$TO"; do
  case "$v" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) ;; *) die2 "--from/--to must be YYYY-MM-DDTHH:MM:SSZ, got '$v'" ;; esac
done
[ -d "$PROJ" ] || die2 "--project is not a directory: '$PROJ'"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/bl975-scan.XXXXXX")" || die2 "mktemp failed"
trap 'rm -rf "$WORK"' EXIT

# ---- the lift ---------------------------------------------------------------------------------
# lift OPEN CLOSE TRAILER OUT: the lines strictly after the one line carrying OPEN (after
# leading blanks) through the one line holding CLOSE, with TRAILER cut off that last line.
lift() {
  local open="$1" close="$2" trailer="$3" out="$4" c
  c="$(awk -v p="$open" '{ s = $0; sub(/^[ \t]+/, "", s) } index(s, p) > 0 { c++ } END { print c + 0 }' "$WFD")"
  [ "$c" = 1 ] || die2 "lift opener matched $c time(s) in $WFD, need exactly 1: $open"
  awk -v p="$open" -v q="$close" -v t="$trailer" '
    { s = $0; sub(/^[ \t]+/, "", s) }
    f && index($0, q) { k = index($0, t); if (k == 0) { bad = 1; exit } print substr($0, 1, k - 1); done = 1; exit }
    f { print }
    index(s, p) > 0 { f = 1 }
    END { if (bad || !done) exit 3 }' "$WFD" > "$out" || die2 "lift did not find its closing line: $close"
  [ -s "$out" ] || die2 "lift came back empty: $open"
}
lift 'ds_r_="$(LC_ALL=C awk '"'" 'END { print (open == ""' "' \"\$ds_f_\"" "$WORK/armB.awk"
lift 'ds_notes_="$(DF_IDS="$DP_ROW_AGENTS_" LC_ALL=C awk '"'" 'END { for (i = 1; i <= n; i++) if (S[i] == "failed")' "' \"\$ds_lead_\"" "$WORK/armA.awk"
grep -q 'open = ""' "$WORK/armB.awk" || die2 "lifted arm B has no request-closing reset"
grep -q 'S\[i\] == "failed"' "$WORK/armA.awk" || die2 "lifted arm A has no failed-status test"
# the report token: the literal say_dispatch_failed echoes before the agent id
c="$(awk 'index($0, "echo \"DISPATCH FAILED agent-${sf_a_}") { c++ } END { print c + 0 }' "$WFD")"
[ "$c" = 1 ] || die2 "the DISPATCH FAILED emitter matched $c time(s) in $WFD, need exactly 1"
TOK="$(awk 'index($0, "echo \"DISPATCH FAILED agent-${sf_a_}") { s = substr($0, index($0, "echo \"") + 6); print substr(s, 1, index(s, "${sf_a_}") - 1) }' "$WFD")"
[ "$TOK" = "DISPATCH FAILED agent-" ] || die2 "lifted report token is '$TOK'"
# arm B's bound, lifted from its one default
c="$(awk 'index($0, "OPEN_REQUEST_SECS=\"${AI_DLC_OPEN_REQUEST_SECS:-") == 1 { c++ } END { print c + 0 }' "$WFD")"
[ "$c" = 1 ] || die2 "the OPEN_REQUEST_SECS default matched $c time(s) in $WFD, need exactly 1"
OPEN_REQUEST_SECS="$(awk 'index($0, "OPEN_REQUEST_SECS=\"${AI_DLC_OPEN_REQUEST_SECS:-") == 1 { s = substr($0, index($0, ":-") + 2); print substr(s, 1, index(s, "}") - 1) }' "$WFD")"
case "$OPEN_REQUEST_SECS" in ''|*[!0-9]*) die2 "lifted OPEN_REQUEST_SECS is '$OPEN_REQUEST_SECS'" ;; esac

to_epoch() { TZ=UTC date -j -f '%Y-%m-%dT%H:%M:%S' "${1:0:19}" +%s 2>/dev/null; }
# first_ts_at_or_after FILE FIXED_TOKEN TS: the first line carrying TOKEN whose own timestamp >= TS
first_ts_at_or_after() {
  LC_ALL=C awk -v k="$2" -v t="$3" 'index($0, k) {
    if (match($0, /"timestamp":"[^"]*"/)) { ts = substr($0, RSTART + 13, RLENGTH - 14); if (ts >= t) { print ts; exit } } }' "$1"
}
# first user or assistant record of FILE newer than TS (attachments and requests are not a resume)
first_newer() {
  LC_ALL=C awk -v t="$2" 'index($0, "{\"type\":\"api-request") == 1 { next }
    !(index($0, "\"type\":\"assistant\"") || index($0, "\"type\":\"user\"")) { next }
    match($0, /"timestamp":"[^"]*"/) { ts = substr($0, RSTART + 13, RLENGTH - 14); if (ts > t) { print ts; exit } }' "$1"
}
secs() { local a b; a="$(to_epoch "$1")" && b="$(to_epoch "$2")" && echo $(( b - a )); }

# scan_project DIR FROM TO -> DEATH lines on stdout; sets FILES, OPENB
scan_project() {
  local dir="$1" from="$2" to="$3" lead sid sd f id ids r open ln ts out k
  FILES=0; OPENB=0; LINKS=0
  : > "$WORK/deaths"
  for lead in "$dir"/*.jsonl; do
    [ -f "$lead" ] || continue
    sid="$(basename "$lead" .jsonl)"; sd="$dir/$sid/subagents"
    [ -d "$sd" ] || continue
    ids=""
    for f in "$sd"/agent-*.jsonl; do
      # a symlinked transcript is another session's file: counting it would count that agent twice
      if [ -L "$f" ]; then LINKS=$((LINKS + 1)); continue; fi
      [ -f "$f" ] || continue
      FILES=$((FILES + 1))
      id="$(basename "$f" .jsonl)"; id="${id#agent-}"
      case "$id" in *[!A-Za-z0-9_-]*) continue ;; esac
      ids="$ids${ids:+ }$id"
      r="$(LC_ALL=C awk -f "$WORK/armB.awk" "$f")" || die2 "arm B awk failed on $f"
      open="${r%% *}"
      [ "$open" = "-" ] && continue
      OPENB=$((OPENB + 1))
      [[ "$open" < "$from" ]] && continue
      [[ "$open" < "$to" ]] || continue
      printf '%s\t%s\tB\t%s\n' "$sid" "$id" "$open" >> "$WORK/deaths"
    done
    [ -n "$ids" ] || continue
    # arm A, point in time: cut the lead transcript at each failed-notice line inside the window that
    # names one of this session's agents (a superset of what the lifted awk can flag at that cut;
    # failed background shell tasks carry no agent id and cost no cut)
    DF_IDS="$ids" LC_ALL=C awk -v a="$from" -v b="$to" 'BEGIN { n = split(ENVIRON["DF_IDS"], ids, " ") }
      index($0, "<status>failed</status>") && index($0, "<task-id>") {
      hit = 0; for (i = 1; i <= n; i++) if (index($0, "<task-id>" ids[i] "</task-id>")) { hit = 1; break }
      if (hit && match($0, /"timestamp":"[^"]*"/)) { ts = substr($0, RSTART + 13, RLENGTH - 14); if (ts >= a && ts < b) print NR } }' "$lead" > "$WORK/cuts"
    while IFS= read -r ln; do
      # the lifted awk prints every agent whose LAST notice at this cut is failed, an agent that
      # failed before --from included: keep only notices inside the window
      head -n "$ln" "$lead" | DF_IDS="$ids" LC_ALL=C awk -f "$WORK/armA.awk" | while IFS=$'\t' read -r id ts _; do
        [ -n "$id" ] || continue
        [[ "$ts" < "$from" ]] && continue
        [[ "$ts" < "$to" ]] || continue
        printf '%s\t%s\tA\t%s\n' "$sid" "$id" "$ts"
      done >> "$WORK/deaths"
    done < "$WORK/cuts"
    # channel R: a lead line inside the window carrying the lifted report token and one of this
    # session's agent ids. It sees a death the lead's own beat reported and then resumed with no
    # harness notice: the resume closes the request (arm B quiet) and arm A has nothing to read.
    DF_IDS="$ids" LC_ALL=C awk -v a="$from" -v b="$to" -v k="$TOK" 'BEGIN { n = split(ENVIRON["DF_IDS"], ids, " ") }
      index($0, k) && match($0, /"timestamp":"[^"]*"/) {
      ts = substr($0, RSTART + 13, RLENGTH - 14); if (ts < a || ts >= b) next
      for (i = 1; i <= n; i++) { p = index($0, k ids[i]); if (!p) continue
        c = substr($0, p + length(k ids[i]), 1); if (c ~ /[A-Za-z0-9_-]/) continue
        if (!(ids[i] in T) || ts < T[ids[i]]) T[ids[i]] = ts } }
      END { for (x in T) print x "\t" T[x] }' "$lead" | while IFS=$'\t' read -r id ts; do
      printf '%s\t%s\tR\t%s\n' "$sid" "$id" "$ts"
    done >> "$WORK/deaths"
  done
  # one line per (sid, id): <arms> <arm A's earliest notice|-> <arm B's open request|-> <cut|->
  # where cut is the earliest of the notice and the first report line (channel R)
  sort -t $'\t' -k1,1 -k2,2 -k4,4 "$WORK/deaths" | LC_ALL=C awk -F '\t' '
    { k = $1 "\t" $2 } !(k in seen) { seen[k] = 1; o[++n] = k }
    $3 == "A" { if (!(k in TA) || $4 < TA[k]) TA[k] = $4 }
    $3 == "B" { TB[k] = $4 }
    $3 == "R" { if (!(k in TR) || $4 < TR[k]) TR[k] = $4 }
    END { for (i = 1; i <= n; i++) { k = o[i]
      c = (k in TA) ? TA[k] : "-"; if ((k in TR) && (c == "-" || TR[k] < c)) c = TR[k]
      print k "\t" ((k in TA) ? "A" : "") ((k in TB) ? "B" : "") ((k in TR) ? "R" : "") "\t" ((k in TA) ? TA[k] : "-") "\t" ((k in TB) ? TB[k] : "-") "\t" c } }' > "$WORK/joined"
  while IFS=$'\t' read -r sid id k note open cut; do
    f="$dir/$sid/subagents/agent-$id.jsonl"
    if [ "$open" = "-" ]; then
      # no open request at the end: the open request as of the notice or the first report,
      # whichever came first, by arm B's lift on the transcript cut there
      r="$(LC_ALL=C awk -v t="$cut" 'match($0, /"timestamp":"[^"]*"/) { if (substr($0, RSTART + 13, RLENGTH - 14) > t) exit } { print }' "$f" \
        | LC_ALL=C awk -f "$WORK/armB.awk")" || die2 "arm B awk failed on the cut of $f"
      open="${r%% *}"
    fi
    # the death is the last send when one is open, else the cut
    ts="$open"; [ "$ts" = "-" ] && ts="$cut"
    out="$(first_ts_at_or_after "$dir/$sid.jsonl" "${TOK}$id" "$ts")"
    r="$(first_newer "$f" "$ts")"
    # how long the lead session ran on after the death: under the bound, no beat of that session
    # could have named it, and an arm-B-only row is then a lead that ended mid-request (CANDIDATE)
    ll="$(LC_ALL=C awk 'match($0, /"timestamp":"[^"]*"/) { t = substr($0, RSTART + 13, RLENGTH - 14); if (t > m) m = t } END { print m }' "$dir/$sid.jsonl")"
    la="-"; [ -n "$ll" ] && la="$(secs "$ts" "$ll")"
    kind="DEATH"
    case "$k" in B) case "$la" in -|-*) kind="CANDIDATE" ;; *) [ "$la" -lt "$OPEN_REQUEST_SECS" ] && kind="CANDIDATE" ;; esac ;; esac
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$kind" "$sid" "$id" "$k" "$open" "$note" \
      "${out:--}" "$( [ -n "$out" ] && secs "$ts" "$out" || echo -)" \
      "${r:--}" "$( [ -n "$r" ] && secs "$ts" "$r" || echo -)" "$la"
  done < "$WORK/joined"
}

# ---- self-probe, both directions, before the corpus -------------------------------------------
PR="$WORK/probe"; mkdir -p "$PR/s1/subagents"
L='{"type":"queue-operation","operation":"enqueue","timestamp":"2026-01-01T00:05:00.000Z","content":"<task-notification><task-id>aDEAD</task-id><status>failed</status><summary>Agent failed: API Error</summary></task-notification>"}'
{ echo '{"type":"user","message":{"role":"user","content":"go"},"timestamp":"2026-01-01T00:00:00.000Z"}'
  echo '{"type":"queue-operation","operation":"enqueue","timestamp":"2025-12-31T23:00:00.000Z","content":"<task-notification><task-id>aOLD</task-id><status>failed</status><summary>Agent failed before the window</summary></task-notification>"}'
  echo "$L"
  echo '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"'"${TOK}"'aOPEN (x) -- its last request"}]},"timestamp":"2026-01-01T00:30:00.000Z"}'
  echo '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"'"${TOK}"'aREP (y) -- its last request; '"${TOK}"'aREPx is another id"}]},"timestamp":"2026-01-01T00:40:00.000Z"}'
  echo '{"type":"queue-operation","operation":"enqueue","timestamp":"2026-01-01T00:06:00.000Z","content":"<task-notification><task-id>bgtask1</task-id><status>failed</status><summary>Background command failed</summary></task-notification>"}'
} > "$PR/s1.jsonl"
{ echo '{"type":"assistant","message":{"role":"assistant"},"timestamp":"2026-01-01T00:01:00.000Z"}'
  echo '{"type":"api-request","timestamp":"2026-01-01T00:02:00.000Z"}'
  echo '{"type":"user","message":{"role":"user","content":"resume"},"timestamp":"2026-01-01T01:00:00.000Z"}'
  echo '{"type":"assistant","message":{"role":"assistant"},"timestamp":"2026-01-01T01:00:05.000Z"}'
} > "$PR/s1/subagents/agent-aDEAD.jsonl"
{ echo '{"type":"assistant","message":{"role":"assistant"},"timestamp":"2026-01-01T00:01:00.000Z"}'
  echo '{"type":"api-request","timestamp":"2026-01-01T00:03:00.000Z"}'
  echo '{"type":"attachment","timestamp":"2026-01-01T00:03:04.000Z"}'
} > "$PR/s1/subagents/agent-aOPEN.jsonl"
{ echo '{"type":"api-request","timestamp":"2026-01-01T00:02:00.000Z"}'
  echo '{"type":"assistant","message":{"role":"assistant"},"timestamp":"2026-01-01T00:02:09.000Z"}'
} > "$PR/s1/subagents/agent-aLIVE.jsonl"
{ echo '{"type":"api-request","timestamp":"2026-01-01T00:02:00.000Z"}'
  echo '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"x"}]},"timestamp":"2026-01-01T00:02:30.000Z"}'
} > "$PR/s1/subagents/agent-aUSER.jsonl"
echo '{"type":"assistant","message":{"role":"assistant"},"timestamp":"2025-12-31T22:59:00.000Z"}' > "$PR/s1/subagents/agent-aOLD.jsonl"
echo '{"type":"api-request","timestamp":"2026-01-01T00:29:00.000Z"}' > "$PR/s1/subagents/agent-aEND.jsonl"
{ echo '{"type":"assistant","message":{"role":"assistant"},"timestamp":"2026-01-01T00:09:00.000Z"}'
  echo '{"type":"api-request","timestamp":"2026-01-01T00:10:00.000Z"}'
  echo '{"type":"user","message":{"role":"user","content":"resume"},"timestamp":"2026-01-01T01:10:00.000Z"}'
  echo '{"type":"assistant","message":{"role":"assistant"},"timestamp":"2026-01-01T01:10:05.000Z"}'
} > "$PR/s1/subagents/agent-aREP.jsonl"
cp "$PR/s1/subagents/agent-aOPEN.jsonl" "$PR/s1/subagents/agent-aLATE.jsonl"
ln -s "$PR/s1/subagents/agent-aOPEN.jsonl" "$PR/s1/subagents/agent-aLINK.jsonl"
sed -i '' -e 's/2026-01-01T00:03/2026-01-02T00:03/' "$PR/s1/subagents/agent-aLATE.jsonl"
scan_project "$PR" 2026-01-01T00:00:00Z 2026-01-02T00:00:00Z > "$WORK/probe.out"
got="$(cat "$WORK/probe.out")"
want="$(printf 'DEATH\ts1\taDEAD\tA\t2026-01-01T00:02:00.000Z\t2026-01-01T00:05:00.000Z\t-\t-\t2026-01-01T01:00:00.000Z\t3480\t2280\nCANDIDATE\ts1\taEND\tB\t2026-01-01T00:29:00.000Z\t-\t-\t-\t-\t-\t660\nDEATH\ts1\taOPEN\tBR\t2026-01-01T00:03:00.000Z\t-\t2026-01-01T00:30:00.000Z\t1620\t-\t-\t2220\nDEATH\ts1\taREP\tR\t2026-01-01T00:10:00.000Z\t-\t2026-01-01T00:40:00.000Z\t1800\t2026-01-01T01:10:00.000Z\t3600\t1800')"
if [ "$got" != "$want" ]; then
  printf 'self-probe got:\n%s\nwant:\n%s\n' "$got" "$want" >&2
  die2 "self-probe FAILED: the lifted arms or the join no longer bucket the synthetic transcripts"
fi
[ "$FILES" = 8 ] && [ "$LINKS" = 1 ] || die2 "self-probe read $FILES agent files and skipped $LINKS symlink(s), need 8 and 1"
echo "self-probe: PASS (aDEAD by arm A with its open request as of the notice, resumed; aOLD failed before the window, at an in-window cut, stays out; aOPEN by arm B and channel R; aREP, reported then resumed with no notice, by channel R alone, with aREPx not matching it; aEND, open 60 s before the lead ends, is a CANDIDATE; aLIVE answered by an assistant line, aUSER by a user line, and aLATE out of window stay quiet; the symlinked aLINK is skipped; a non-agent failed task ignored)"

# ---- the corpus -------------------------------------------------------------------------------
listed="$(/usr/bin/find "$PROJ" -path '*/subagents/agent-*.jsonl' -type f | wc -l | tr -d ' ')"
scan_project "$PROJ" "$FROM" "$TO" > "$WORK/out"
cat "$WORK/out"
nd="$(grep -c '^DEATH' "$WORK/out")" || nd=0
nc="$(grep -c '^CANDIDATE' "$WORK/out")" || nc=0
na="$(awk -F '\t' '$1 == "DEATH" && $4 ~ /A/' "$WORK/out" | wc -l | tr -d ' ')"
nb="$(awk -F '\t' '$1 == "DEATH" && $4 ~ /B/' "$WORK/out" | wc -l | tr -d ' ')"
nr="$(awk -F '\t' '$1 == "DEATH" && $7 != "-"' "$WORK/out" | wc -l | tr -d ' ')"
nR="$(awk -F '\t' '$1 == "DEATH" && $4 ~ /R/' "$WORK/out" | wc -l | tr -d ' ')"
printf 'SUMMARY\twindow %s..%s\tdeaths %s\tarm A %s\tarm B %s\tchannel R %s\treported %s\tcandidates %s (bound %s s)\n' "$FROM" "$TO" "$nd" "$na" "$nb" "$nR" "$nr" "$nc" "$OPEN_REQUEST_SECS"
[ "$FILES" = "$listed" ] || die2 "scanned $FILES agent files but find lists $listed"
[ "$FILES" -gt 0 ] || die2 "no agent transcript under $PROJ/<sid>/subagents/"
printf 'CONTROL\tagent files scanned %s = listed %s (symlinked transcripts skipped: %s)\tfiles ending in an open request (any time) %s\n' "$FILES" "$listed" "$LINKS" "$OPENB"
tok="ZQX-BL975-NEVER-$(printf '%s' "$WORK" | md5 -q | cut -c1-8)"
neg="$(/usr/bin/grep -rlF -e "$tok" "$PROJ" | wc -l | tr -d ' ')"
pos="$(/usr/bin/grep -rlF -e '{"type":"api-request"' "$PROJ" | wc -l | tr -d ' ')"
printf 'CONTROL\tabsent token %s: %s file(s)\tknown-present api-request: %s file(s)\n' "$tok" "$neg" "$pos"
[ "$neg" = 0 ] || die2 "the absent token is present"
[ "$pos" -gt 0 ] || die2 "no api-request line anywhere: the corpus is not a transcript directory"
exit 0
