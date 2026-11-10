#!/usr/bin/env bash
# BL-514 subagent-poll classifier.
#
# Buckets every Bash call in subagent transcripts that the foreground-budget hook
# would call a POLL, using the hook's OWN regex defs (lifted at run time, never
# retyped), and joins each call to its tool_result to find which polls the hook
# actually denied.
#
# Usage: classify.sh [--hook PATH] [--budget S] [--from ISO] [--to ISO]
#                    [--absent TOKEN] [FILE.jsonl | DIR ...]
# No FILE/DIR argument means probe-only. Exit 0 clean, 1 integrity finding,
# 2 refusal (could not run, or a control or the self-probe failed).
#
# Hazards this script guards, each one a measured way for a zero to lie:
#   - the hook's is_poll reads .tool_input.command; a transcript carries
#     .input.command, so is_poll is NOT lifted and loopsleep/longsleep are applied
#     to the transcript field directly (a verbatim lift would score every call 0).
#   - each def is lifted exactly once or the run refuses (a renamed def, or a
#     duplicated one, must not silently change the rule).
#   - the deny reason is lifted from the hook, never retyped, so an edited hook
#     fails the DENIED probe instead of agreeing with a stale copy.
#   - the self-probe runs BEFORE any corpus is read, in both directions: seeded
#     polls are counted and the near-misses are not.
#   - jq is run once per listed file and its status checked, so a listed file that
#     was never read cannot pass as an empty one.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)" || exit 2
PROBE="$HERE/probe/probe.jsonl"

HOOK=""
BUDGET=120
FROM=""
TO=""
# Built from two literals so the full token is in no file of this repo.
ABSENT="ZQX-BL514-NEVER-""7c1e5a"

die2() { echo "classify: $*" >&2; exit 2; }

TARGETS="$(mktemp)" || exit 2
while [ $# -gt 0 ]; do
  case "$1" in
    --hook)   [ $# -ge 2 ] || die2 "--hook needs a value"; HOOK="$2"; shift 2 ;;
    --budget) [ $# -ge 2 ] || die2 "--budget needs a value"; BUDGET="$2"; shift 2 ;;
    --from)   [ $# -ge 2 ] || die2 "--from needs a value"; FROM="$2"; shift 2 ;;
    --to)     [ $# -ge 2 ] || die2 "--to needs a value"; TO="$2"; shift 2 ;;
    --absent) [ $# -ge 2 ] || die2 "--absent needs a value"; ABSENT="$2"; shift 2 ;;
    -*)       die2 "unknown option $1" ;;
    *)        printf '%s\n' "$1" >> "$TARGETS"; shift ;;
  esac
done
case "$BUDGET" in ''|*[!0-9]*) die2 "--budget must be a whole number of seconds" ;; esac
command -v jq >/dev/null 2>&1 || die2 "jq not found"

# Resolve the repo root by walking up for a marker, never by counting hops.
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
if [ -z "$HOOK" ]; then
  ROOT="$(ai_dlc_resolve_root "$HERE")" || die2 "no repo root above $HERE"
  HOOK="$ROOT/core/hooks/ai-dlc-foreground-budget.sh"
fi
[ -f "$HOOK" ] && [ -r "$HOOK" ] || die2 "hook not readable: $HOOK"
[ -f "$PROBE" ] && [ -r "$PROBE" ] || die2 "probe not readable: $PROBE"

WORK="$(mktemp -d)" || die2 "mktemp failed"
trap 'rm -f "$WORK"/* "$TARGETS"; rmdir "$WORK" 2>/dev/null' EXIT

# ---- lift the four defs, each exactly once -------------------------------
: > "$WORK/prelude.jq"
for name in cmdpos loopend loopsleep longsleep; do
  c="$(awk -v p="  def ${name}:" 'index($0, p) == 1 { c++ } END { print c + 0 }' "$HOOK")" || die2 "awk failed on $HOOK"
  [ "$c" = "1" ] || die2 "def ${name} matched ${c} time(s) in $HOOK, need exactly 1"
  awk -v p="  def ${name}:" 'index($0, p) == 1 { print }' "$HOOK" >> "$WORK/prelude.jq"
done

# ---- lift the deny reason substring, from the one REASON line ------------
c="$(awk 'index($0, "FOREGROUND Bash call is a poll") > 0 { c++ } END { print c + 0 }' "$HOOK")" || die2 "awk failed on $HOOK"
[ "$c" = "1" ] || die2 "deny reason line matched ${c} time(s) in $HOOK, need exactly 1"
REASON="$(awk 'index($0, "FOREGROUND Bash call is a poll") > 0 {
  s = index($0, "this subagent"); e = index($0, "is a poll")
  if (s > 0 && e > s) print substr($0, s, e + 9 - s)
}' "$HOOK")" || die2 "awk failed lifting the reason"
[ -n "$REASON" ] || die2 "could not lift the reason substring from $HOOK"
case "$REASON" in *'${'*) die2 "lifted reason carries a shell expansion" ;; esac

# ---- the two jq programs --------------------------------------------------
{
  cat "$WORK/prelude.jq"
  cat <<'EOF'
def txt: if type == "string" then .
         elif type == "array" then map(select(type == "object") | (.text // "") | tostring) | join("\n")
         else "" end;
. as $r
| (if (($r.message // {}) | type) == "object" and (($r.message.content // null) | type) == "array"
   then $r.message.content else [] end) as $cs
| [ $cs[] | select(type == "object") ] as $els
| (
    ( if $r.type == "assistant" then
        $els[] | select(.type == "tool_use" and .name == "Bash")
        | (if (.input | type) == "object" then .input else {} end) as $in
        | ($in.command // "") as $cmd
        | {k: "use", id: (.id | tostring), ts: $r.timestamp,
           nocmd: (($in.command // null) == null),
           nonobj: ((.input | type) != "object"),
           cmd_str: (($cmd | type) == "string"),
           timeout: $in.timeout,
           bg: ($in.run_in_background == true),
           poll: (($cmd | tostring) | (loopsleep or longsleep)),
           sleep: (($cmd | tostring) | contains("sleep"))}
      else empty end ),
    ( if $r.type == "user" then
        $els[] | select(.type == "tool_result")
        | (.content | txt | (index($reason) != null)) as $den
        | ((.content | txt | sub("^\\s+"; "")) | startswith("<tool_use_error>Blocked:")) as $blk
        | {k: "res", id: (.tool_use_id | tostring), ts: $r.timestamp, den: $den, hb: ((.is_error == true) and $blk)}
      else empty end ),
    ( [ $els[] | select(.type == "tool_result") | (.content | txt | (index($reason) != null)) | select(.) ] as $dens
      | if ($dens | length) == 0 and (($r | tojson) | contains($reason))
        then {k: "car-other", rtype: ($r.type // "none")} else empty end )
  )
EOF
} > "$WORK/extract.jq"

cat > "$WORK/summarize.jq" <<'EOF'
def ep: try (tostring | capture("^(?<b>[0-9T:-]+)(?<f>\\.[0-9]+)?Z$") | ((.b + "Z") | fromdateiso8601) + ((.f // "") | if . == "" then 0 else ("0" + . | tonumber) end)) catch null;
def tmo: if . == null then null else (try tonumber catch "bad") end;
[ .[] | select(.k == "use") ] as $U0raw
| (reduce $U0raw[] as $u ({seen: {}, l: []}; if .seen[$u.id] then . else {seen: (.seen + {($u.id): 1}), l: (.l + [$u])} end) | .l) as $U0
| (($U0raw | length) - ($U0 | length)) as $dup
| (reduce (.[] | select(.k == "res")) as $r ({}; if has($r.id) then . else . + {($r.id): $r} end)) as $R
| (reduce $U0[] as $u ({}; . + {($u.id): $u.poll})) as $P
| (if $from == "" then null else ($from | ep) end) as $F
| (if $to == "" then null else ($to | ep) end) as $T
| (if ($from != "" and $F == null) or ($to != "" and $T == null) then error("--from/--to must be an ISO-8601 UTC timestamp ending in Z") else . end) as $chk
| ($U0 | map(select(($F == null or ((.ts | ep) != null and (.ts | ep) >= $F)) and ($T == null or ((.ts | ep) != null and (.ts | ep) <= $T))))) as $U
| ($U | map(
    . as $u
    | ($R[$u.id]) as $r
    | ($u.timeout | tmo) as $t
    | { poll: $u.poll, sleep: $u.sleep, joined: ($r != null), hb: ($r != null and $r.hb),
        b: (if ($u.poll | not) then null
            elif ($r != null and $r.den) then "DENIED"
            elif ($r != null and $r.hb) then "HARNESS-BLOCKED"
            elif $u.bg then "RAN-bg"
            elif ($t == null or $t == "bad") then "RAN-notimeout"
            elif $t <= ($budget * 1000) then "RAN-le-budget"
            else "RAN-fg-over-budget" end),
        rawwall: (if $r != null and ($u.ts | ep) != null and ($r.ts | ep) != null
               then (($r.ts | ep) - ($u.ts | ep)) else 0 end) }
    | .neg = (.rawwall < 0) | .wall = (if .neg then 0 else .rawwall end))) as $rows
| ["DENIED", "HARNESS-BLOCKED", "RAN-bg", "RAN-notimeout", "RAN-le-budget", "RAN-fg-over-budget"] as $names
| ( [ .[] | select(.k == "res" and .den) ] ) as $dr
| {
    calls: ($U | length),
    dup: $dup,
    negwall: ($rows | map(select(.neg)) | length),
    polls: ($rows | map(select(.poll)) | length),
    unjoined_polls: ($rows | map(select(.poll and (.joined | not))) | length),
    buckets: ($names | map(. as $n | {key: $n, value: {n: ($rows | map(select(.b == $n)) | length),
                                                       s: ($rows | map(select(.b == $n) | .wall) | add // 0)}}) | from_entries),
    nonpoll_sleep_blocked: {n: ($rows | map(select((.poll | not) and .sleep and .hb)) | length),
                            s: ($rows | map(select((.poll | not) and .sleep and .hb) | .wall) | add // 0)},
    nonpoll_sleep_ran: {n: ($rows | map(select((.poll | not) and .sleep and (.hb | not))) | length),
                        s: ($rows | map(select((.poll | not) and .sleep and (.hb | not)) | .wall) | add // 0)},
    malformed: {nocmd: ($U | map(select(.nocmd)) | length),
                nonobj: ($U | map(select(.nonobj)) | length),
                badtimeout: ($U | map(select((.timeout | tmo) == "bad")) | length)},
    carriers: {poll: ($dr | map(select($P[.id] == true)) | length),
               nonpoll: ($dr | map(select($P[.id] == false)) | length),
               other: (($dr | map(select($P[.id] == null)) | length) + ([ .[] | select(.k == "car-other") ] | length))},
    nonpoll_ids: ($dr | map(select($P[.id] == false) | .id)),
    other_kinds: ([ .[] | select(.k == "car-other") | .rtype ] + ($dr | map(select($P[.id] == null) | "unjoined-result")))
  }
| .bucket_sum = ([.buckets[].n] | add)
EOF

# A DIR is searched for *.jsonl, symlinks included.
list_dir() { /usr/bin/find "$1" \( -type f -o -type l \) -name '*.jsonl'; }

# ---- run the two stages over a newline list of files ----------------------
# Sets: OPENED, SUMMARY (path of a json summary file). Exit 2 on any read error.
run_files() {
  local list="$1" ev="$WORK/events.jsonl" f
  OPENED=0
  : > "$ev"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ -f "$f" ] && [ -r "$f" ] || die2 "listed file not readable: $f"
    jq -c --arg reason "$REASON" -f "$WORK/extract.jq" "$f" >> "$ev" || die2 "jq failed reading $f"
    OPENED=$((OPENED + 1))
  done < "$list"
  SUMMARY="$WORK/summary.json"
  jq -s --argjson budget "$BUDGET" --arg from "$FROM" --arg to "$TO" -f "$WORK/summarize.jq" "$ev" > "$SUMMARY" || die2 "summary stage failed"
}

# ---- self-probe, before any corpus ----------------------------------------
EXPECT='{"b":{"DENIED":[2,3],"HARNESS-BLOCKED":[2,3],"RAN-bg":[2,15],"RAN-notimeout":[1,60],"RAN-le-budget":[15,144],"RAN-fg-over-budget":[3,293]},"calls":31,"dup":1,"neg":1,"car":{"poll":2,"nonpoll":0,"other":0},"npb":[1,1],"npr":[4,46],"polls":25,"unj":1}'
shape='{dup: .dup, neg: .negwall, b: (.buckets | map_values([.n, .s])), calls, polls, unj: .unjoined_polls, npb: [.nonpoll_sleep_blocked.n, .nonpoll_sleep_blocked.s], npr: [.nonpoll_sleep_ran.n, .nonpoll_sleep_ran.s], car: .carriers}'

SAVE_FROM="$FROM"; SAVE_TO="$TO"; FROM=""; TO=""
SAVE_BUDGET="$BUDGET"; BUDGET=120
printf '%s\n' "$PROBE" > "$WORK/probe.list"
run_files "$WORK/probe.list"
got="$(jq -cS "$shape" "$SUMMARY")"
want="$(printf '%s' "$EXPECT" | jq -cS .)"
if [ "$got" != "$want" ]; then
  echo "self-probe FAILED" >&2
  echo "  expected $want" >&2
  echo "  got      $got" >&2
  exit 2
fi
# Carrier arm, both directions: a non-poll's result and a stray record carrying the reason must be seen.
{
  cat "$PROBE"
  jq -cn --arg r "$REASON" '{type:"assistant",timestamp:"2026-01-01T01:00:00Z",message:{content:[{type:"tool_use",id:"toolu_x1",name:"Bash",input:{command:"ls"}}]}}'
  jq -cn --arg r "$REASON" '{type:"user",timestamp:"2026-01-01T01:00:01Z",message:{content:[{type:"tool_result",tool_use_id:"toolu_x1",content:$r}]}}'
  jq -cn --arg r "$REASON" '{type:"system",timestamp:"2026-01-01T01:00:02Z",note:$r}'
} > "$WORK/probe-carriers.jsonl"
printf '%s\n' "$WORK/probe-carriers.jsonl" > "$WORK/probe2.list"
run_files "$WORK/probe2.list"
gotc="$(jq -c '.carriers' "$SUMMARY")"
if [ "$gotc" != '{"poll":2,"nonpoll":1,"other":1}' ]; then
  echo "self-probe (carrier arm) FAILED: got $gotc" >&2
  exit 2
fi
# Window arm: fractional timestamps at both edges, from and to both INCLUSIVE.
WPROBE="$HERE/probe/probe-window.jsonl"
[ -f "$WPROBE" ] && [ -r "$WPROBE" ] || die2 "window probe not readable: $WPROBE"
FROM="2026-02-01T00:00:10Z"; TO="2026-02-01T00:00:20Z"
printf '%s\n' "$WPROBE" > "$WORK/probe3.list"
run_files "$WORK/probe3.list"
gotw="$(jq -c '[.calls, .polls, .buckets["RAN-le-budget"].n, .buckets["RAN-le-budget"].s]' "$SUMMARY")"
if [ "$gotw" != '[3,3,3,3]' ]; then
  echo "self-probe (window arm) FAILED: got [calls,polls,n,secs] $gotw, want [3,3,3,3]" >&2
  exit 2
fi
# Symlink arm: a DIR holding a real .jsonl and a symlinked one must list both.
mkdir "$WORK/lnk" && cp "$PROBE" "$WORK/lnk/real.jsonl" && ln -s "$PROBE" "$WORK/lnk/link.jsonl" || die2 "symlink arm setup failed"
nl="$(list_dir "$WORK/lnk" | awk 'END { print NR }')"
rm -f "$WORK/lnk/real.jsonl" "$WORK/lnk/link.jsonl"; rmdir "$WORK/lnk"
if [ "$nl" != "2" ]; then
  echo "self-probe (symlink arm) FAILED: DIR listing found $nl of 2 .jsonl entries" >&2
  exit 2
fi
FROM="$SAVE_FROM"; TO="$SAVE_TO"; BUDGET="$SAVE_BUDGET"
echo "self-probe: PASS (bucket counts and seconds exact; lifted-rule shapes pinned; window arm inclusive at both edges with fractional seconds; symlink arm; carrier arm sees nonpoll=1 other=1)"

# ---- the corpus -----------------------------------------------------------
if [ -s "$TARGETS" ]; then
  : > "$WORK/corpus.list"
  while IFS= read -r t; do
    if [ -d "$t" ]; then
      list_dir "$t" >> "$WORK/corpus.list" || die2 "find failed on $t"
    elif [ -f "$t" ]; then
      printf '%s\n' "$t" >> "$WORK/corpus.list"
    else
      die2 "no such file or directory: $t"
    fi
  done < "$TARGETS"
  LISTED="$(awk 'END { print NR }' "$WORK/corpus.list")"
  [ "$LISTED" -gt 0 ] || die2 "corpus lists 0 files"
  MODE=corpus
else
  cp "$WORK/probe.list" "$WORK/corpus.list"
  LISTED=1
  MODE=probe-only
fi

run_files "$WORK/corpus.list"
[ "$OPENED" = "$LISTED" ] || die2 "listed $LISTED files, opened $OPENED"

# controls, same run
CALLS="$(jq -r '.calls' "$SUMMARY")"
[ "$CALLS" -gt 0 ] 2>/dev/null || die2 "known-present control failed: 0 Bash calls in the $MODE input"
ABS_N=0
while IFS= read -r f; do
  n="$(grep -cF -- "$ABSENT" "$f")" || n=0
  ABS_N=$((ABS_N + n))
done < "$WORK/corpus.list"
[ "$ABS_N" = "0" ] || die2 "absent-token control failed: '$ABSENT' occurs $ABS_N time(s) in the input"

echo "mode: $MODE   hook: $HOOK   budget: ${BUDGET}s   window: ${FROM:-open}..${TO:-open}"
echo "reason lifted: $REASON"
echo "files listed: $LISTED   opened: $OPENED"
jq -r '
  def h: (. / 3600 * 100 | round / 100);
  "Bash calls: \(.calls)   polls: \(.polls)   bucket sum: \(.bucket_sum)   unjoined polls (no result): \(.unjoined_polls)",
  "bucket\tcount\thours",
  (.buckets | to_entries[] | "\(.key)\t\(.value.n)\t\(.value.s | h)"),
  "NONPOLL-SLEEP-BLOCKED\t\(.nonpoll_sleep_blocked.n)\t\(.nonpoll_sleep_blocked.s | h)",
  "NONPOLL-SLEEP-RAN\t\(.nonpoll_sleep_ran.n)\t\(.nonpoll_sleep_ran.s | h)",
  "duplicate tool_use ids: \(.dup)   negative-wall: \(.negwall)",
  "malformed: no-command \(.malformed.nocmd), input-not-object \(.malformed.nonobj), bad-timeout \(.malformed.badtimeout)",
  "reason carriers: poll-result \(.carriers.poll), non-poll-result \(.carriers.nonpoll), other \(.carriers.other)"
' "$SUMMARY"
echo "controls: Bash calls > 0 (${CALLS}); absent token '${ABSENT}' count ${ABS_N}"

RC=0
PSUM="$(jq -r '.polls' "$SUMMARY")"; BSUM="$(jq -r '.bucket_sum' "$SUMMARY")"
if [ "$PSUM" != "$BSUM" ]; then
  echo "INTEGRITY: bucket sum $BSUM != polls $PSUM" >&2; RC=1
fi
NP="$(jq -r '.carriers.nonpoll' "$SUMMARY")"; OT="$(jq -r '.carriers.other' "$SUMMARY")"
if [ "$NP" != "0" ]; then
  echo "INTEGRITY: reason carried by $NP non-poll result(s): $(jq -r '.nonpoll_ids | join(" ")' "$SUMMARY")" >&2; RC=1
fi
if [ "$OT" != "0" ]; then
  echo "INTEGRITY: reason carried by $OT record(s) that are not a poll's result: $(jq -r '.other_kinds | join(" ")' "$SUMMARY")" >&2; RC=1
fi
exit "$RC"
