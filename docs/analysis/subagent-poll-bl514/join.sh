#!/usr/bin/env bash
# BL-514 (c) denied-to-backgrounded join and (b) idling.
#
# (c) For each DENIED poll (the hook refused a subagent's foreground poll), did the
#     same agent (same transcript file) issue a backgrounded Bash (run_in_background
#     true) or a Monitor call within SPAN seconds (default 120) AFTER the denied
#     result, and is that call poll-shaped (a Monitor, or a backgrounded Bash whose
#     command the hook's own loopsleep or longsleep accepts)? The control is the
#     same join over the RAN-fg-over-budget polls (foreground polls that ran with a
#     declared timeout over the budget), which is what the pre-mechanism window holds.
# (b) For each backgrounded launch (a RAN-bg poll, and each backgrounded call the
#     join found after a denied or control poll), did the agent issue any tool_use
#     other than waiting on or reading that launch's own output between the launch
#     and its completion? See the README for the exact definitions and buckets.
#
# Usage: join.sh [--hook PATH] [--budget S] [--span S] [--classify PATH]
#                --window LABEL=FROM..TO [--window ...] [--absent TOKEN]
#                [--detail PATH] DIR|FILE.jsonl ...
# No DIR/FILE means self-probe only. Exit 0 clean, 1 integrity finding, 2 refusal.
#
# The poll rule and the deny reason come from lift.sh, the same file classify.sh
# sources, so neither script owns a copy. Same-invocation control: classify.sh is
# run over the same targets and window and its DENIED (id, file) set must equal the
# join's, else exit 2. The self-probe runs BEFORE the corpus, both directions.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)" || exit 2
HOOK=""
BUDGET=120
SPAN=120
CLASSIFY="$HERE/classify.sh"
DETAIL=""
ABSENT="ZQX-BL514-JOIN-NEVER-""4e9a27"
WINDOWS=()

die2() { echo "join: $*" >&2; exit 2; }

TARGETS="$(mktemp)" || exit 2
while [ $# -gt 0 ]; do
  case "$1" in
    --hook)     [ $# -ge 2 ] || die2 "--hook needs a value"; HOOK="$2"; shift 2 ;;
    --budget)   [ $# -ge 2 ] || die2 "--budget needs a value"; BUDGET="$2"; shift 2 ;;
    --span)     [ $# -ge 2 ] || die2 "--span needs a value"; SPAN="$2"; shift 2 ;;
    --classify) [ $# -ge 2 ] || die2 "--classify needs a value"; CLASSIFY="$2"; shift 2 ;;
    --window)   [ $# -ge 2 ] || die2 "--window needs a value"; WINDOWS+=("$2"); shift 2 ;;
    --absent)   [ $# -ge 2 ] || die2 "--absent needs a value"; ABSENT="$2"; shift 2 ;;
    --detail)   [ $# -ge 2 ] || die2 "--detail needs a value"; DETAIL="$2"; shift 2 ;;
    -*)         die2 "unknown option $1" ;;
    *)          printf '%s\n' "$1" >> "$TARGETS"; shift ;;
  esac
done
case "$BUDGET" in ''|*[!0-9]*) die2 "--budget must be a whole number of seconds" ;; esac
case "$SPAN" in ''|*[!0-9]*) die2 "--span must be a whole number of seconds" ;; esac
command -v jq >/dev/null 2>&1 || die2 "jq not found"

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

WORK="$(mktemp -d)" || die2 "mktemp failed"
trap '/usr/bin/find "$WORK" -type f -delete 2>/dev/null; rm -f "$TARGETS"; rmdir "$WORK/probe" "$WORK" 2>/dev/null' EXIT

# shellcheck source=lift.sh
. "$HERE/lift.sh" || die2 "cannot source $HERE/lift.sh"
bl514_lift "$HOOK" "$WORK"

# ---- extract: every tool_use, tool_result and task-notification, one pass per file
{
  cat "$WORK/prelude.jq"
  cat <<'EOF'
def txt: if type == "string" then .
         elif type == "array" then map(select(type == "object") | (.text // "") | tostring) | join("\n")
         else "" end;
def first1(s): ([s] | first);
. as $r
| (if (($r.message // {}) | type) == "object" and (($r.message.content // null) | type) == "array"
   then $r.message.content else [] end) as $cs
| [ $cs[] | select(type == "object") ] as $els
| (
    ( if $r.type == "assistant" then
        $els[] | select(.type == "tool_use")
        | (if (.input | type) == "object" then .input else {} end) as $in
        | (($in.command // "") | tostring) as $cmd
        | (.name | tostring) as $nm
        | {k: "tu", id: (.id | tostring), name: $nm, ts: $r.timestamp, file: input_filename,
           timeout: $in.timeout, bg: ($in.run_in_background == true),
           poll: (if $nm == "Bash" then ($cmd | (loopsleep or longsleep)) else false end),
           ref: (if $nm == "Bash" or $nm == "Monitor" then ($cmd | .[0:4000])
                 elif $nm == "Read" then (($in.file_path // "") | tostring)
                 elif $nm == "TaskStop" then (($in.task_id // "") | tostring)
                 else "" end)}
      else empty end ),
    ( if $r.type == "user" then
        $els[] | select(.type == "tool_result")
        | (.content | txt) as $t
        | ($t | sub("^\\s+"; "") | startswith("<tool_use_error>Blocked:")) as $blk
        | {k: "res", id: (.tool_use_id | tostring), ts: $r.timestamp, file: input_filename,
           den: ($t | index($reason) != null), hb: ((.is_error == true) and $blk),
           bgid: (first1($t | capture("(?:with ID: |Monitor started \\(task )(?<x>[A-Za-z0-9_-]+)") | .x) // null)}
      else empty end ),
    ( if $r.type == "attachment" and (($r.attachment | type) == "object") and $r.attachment.type == "queued_command" then
        (($r.attachment.prompt // "") | tostring) as $p
        | select($p | contains("<task-notification>"))
        | ($p | split("<task-notification>")[1:][]) as $c
        | {k: "note", ts: $r.timestamp, file: input_filename,
           taskid: (first1($c | capture("<task-id>(?<x>[^<]*)</task-id>") | .x) // null),
           tuid: (first1($c | capture("<tool-use-id>(?<x>[^<]*)</tool-use-id>") | .x) // null),
           status: (first1($c | capture("<status>(?<x>[^<]*)</status>") | .x) // null)}
      else empty end )
  )
EOF
} > "$WORK/extract.jq"

# ---- summarize: one window per call
cat > "$WORK/summarize.jq" <<'EOF'
def ep: try (tostring | capture("^(?<b>[0-9T:-]+)(?<f>\\.[0-9]+)?Z$") | ((.b + "Z") | fromdateiso8601) + ((.f // "") | if . == "" then 0 else ("0" + . | tonumber) end)) catch null;
def tmo: if . == null then null else (try tonumber catch "bad") end;
def inwin($F; $T): select(($F == null or ((.ts | ep) != null and (.ts | ep) >= $F)) and ($T == null or ((.ts | ep) != null and (.ts | ep) <= $T)));
[ .[] | select(.k == "tu") ] as $TU
| [ .[] | select(.k == "note") ] as $NOTES
| ($TU | map(select(.name == "Bash"))) as $B0raw
| ($B0raw | unique_by(.id)) as $B0
| (($B0raw | length) - ($B0 | length)) as $dup
| (reduce ([ .[] | select(.k == "res") ] | reverse[]) as $r ({}; . + {($r.id): $r})) as $R
| (if $from == "" then null else ($from | ep) end) as $F
| (if $to == "" then null else ($to | ep) end) as $T
| ($B0 | map(inwin($F; $T))) as $U
| ($TU | group_by(.file) | map({key: .[0].file, value: (unique_by(.id) | sort_by(.ts | ep))}) | from_entries) as $BYF
| ($NOTES | group_by(.file) | map({key: .[0].file, value: .}) | from_entries) as $NBF
| ($U | map(
    . as $u | ($R[$u.id]) as $r | ($u.timeout | tmo) as $t
    | select($u.poll)
    | { id: $u.id, file: $u.file, ts: $u.ts, rts: ($r.ts // null), wall: (if $r != null and ($u.ts | ep) != null and ($r.ts | ep) != null then (($r.ts | ep) - ($u.ts | ep)) else 0 end),
        b: (if ($r != null and $r.den) then "DENIED"
            elif ($r != null and $r.hb) then "HARNESS-BLOCKED"
            elif $u.bg then "RAN-bg"
            elif ($t == null or $t == "bad") then "RAN-notimeout"
            elif $t <= ($budget * 1000) then "RAN-le-budget"
            else "RAN-fg-over-budget" end) })) as $rows
# the follow-up join: same file, bg Bash or Monitor, result ts <= call ts <= result ts + span
| def follow($row):
    (($row.rts | ep)) as $rt
    | if $rt == null then []
      else ($BYF[$row.file] // [])
           | map(select(((.name == "Bash" and .bg) or .name == "Monitor") and .id != $row.id
                        and (.ts | ep) != null and (.ts | ep) >= $rt and ((.ts | ep) - $rt) <= $span)) end;
  def joinset($name):
    ($rows | map(select(.b == $name))) as $S
    | ($S | map(. + {cand: follow(.)})) as $J
    | { n: ($S | length),
        any_bg: ($J | map(select(.cand | length > 0)) | length),
        poll_shaped: ($J | map(select(.cand | any(.name == "Monitor" or .poll))) | length),
        unjoined: ($S | map(select(.rts == null)) | length),
        ids: ($S | map({id, file})), launches: ($J | map(.cand[] | . + {origin: ("follow-" + $name)})) };
  joinset("DENIED") as $D
| joinset("RAN-fg-over-budget") as $C
| ($rows | map(select(.b == "RAN-bg")) | map({id, file, ts} + {origin: "RAN-bg", name: "Bash", ref: ""})) as $RB
# ---- idling
| def tid($id): ($R[$id].bgid // null);
  def completion($L; $tid):
    ($NBF[$L.file] // [])
    | map(select(.tuid == $L.id or ($tid != null and .taskid == $tid)))
    | map(.ts | ep) | map(select(. != null)) | (if length == 0 then null else min end);
  def idle($L):
    tid($L.id) as $t
    | ($L.ts | ep) as $s
    | (if $t == null then {bucket: "unjoined", why: "no-bgid-in-result"}
       else
         (completion($L; $t)) as $e0
         | (if $L.name == "Bash"
            then ($BYF[$L.file] // [] | map(select(.name == "Monitor" and (.ts | ep) >= $s and (.ref | contains($t)))))
            else [] end) as $ms
         | ($ms | map(. as $m | completion($m; tid($m.id)))) as $mends
         | (($ms | length) > 0) as $chain
         | (if $chain
            then (if ($mends | any(. == null)) then null else ([$e0] + $mends | map(select(. != null)) | max) end)
            else $e0 end) as $e
         | if $e == null then {bucket: "unjoined", why: (if $chain then "chain-monitor-no-completion" else "no-completion-notification" end), chain: $chain}
           else
             ($BYF[$L.file] // []
              | map(select((.ts | ep) != null and (.ts | ep) >= $s and (.ts | ep) < $e and .id != $L.id))) as $mid
             | ($mid | map(select((.ref | contains($t)) | not))) as $other
             | ($other | map(select((.name == "Monitor" or .poll) | not))) as $otherwide
             | {bucket: (if $chain then "chain" else (if ($other | length) == 0 then "idle" else "not-idle" end) end),
                idle: (($other | length) == 0), idle_wide: (($otherwide | length) == 0),
                chain: $chain, secs: ($e - $s), n_other: ($other | length)}
           end
       end);
  def launchset($ls):
    ($ls | unique_by([.file, .id]) | map(. + {r: idle(.)})) as $x
    | { n: ($x | length),
        idle: ($x | map(select(.r.bucket == "idle")) | length),
        not_idle: ($x | map(select(.r.bucket == "not-idle")) | length),
        unjoined: ($x | map(select(.r.bucket == "unjoined")) | length),
        unjoined_why: ($x | map(select(.r.bucket == "unjoined") | .r.why) | group_by(.) | map({(.[0]): length}) | add // {}),
        chain: ($x | map(select(.r.bucket == "chain")) | length),
        chain_idle: ($x | map(select(.r.bucket == "chain" and .r.idle)) | length),
        chain_not_idle: ($x | map(select(.r.bucket == "chain" and (.r.idle | not))) | length),
        idle_wide_all: ($x | map(select(.r.bucket != "unjoined" and .r.idle_wide)) | length),
        idle_secs: ($x | map(select(.r.bucket == "idle") | .r.secs) | add // 0),
        not_idle_secs: ($x | map(select(.r.bucket == "not-idle") | .r.secs) | add // 0),
        by_kind: ($x | group_by(.name) | map({(.[0].name): length}) | add // {}) };
{ bash_polls: ($rows | length), dup: $dup,
  buckets: ($rows | group_by(.b) | map({(.[0].b): length}) | add // {}),
  denied: ($D | del(.launches)), control: ($C | del(.launches)),
  idling: { ran_bg: launchset($RB),
            post_denied: launchset($D.launches),
            post_control: launchset($C.launches),
            all_bg: launchset($RB + $D.launches + $C.launches) },
  detail: ($D.launches | map({id, file, name})) }
EOF

# ---- listing and extraction ---------------------------------------------------
list_dir() { /usr/bin/find "$1" \( -type f -o -type l \) -name '*.jsonl'; }

# extract_files LIST EVENTS
extract_files() {
  bl514_extract "$1" "$2"
}

# summarize_events EVENTS FROM TO OUT
summarize_events() {
  jq -s --argjson budget "$BUDGET" --argjson span "$SPAN" --arg from "$2" --arg to "$3" \
    -f "$WORK/summarize.jq" "$1" > "$4" || die2 "summary stage failed"
}

# ---- self-probe, synthetic jsonl under mktemp, BEFORE the corpus ----------------
PD="$WORK/probe"; mkdir "$PD" || die2 "mkdir probe failed"
mk_use()  { jq -cn --arg ts "$2" --arg id "$3" --arg nm "$4" --argjson in "$5" '{type:"assistant",timestamp:$ts,message:{content:[{type:"tool_use",id:$id,name:$nm,input:$in}]}}' >> "$1"; }
mk_res()  { jq -cn --arg ts "$2" --arg id "$3" --arg c "$4" '{type:"user",timestamp:$ts,message:{content:[{type:"tool_result",tool_use_id:$id,content:$c}]}}' >> "$1"; }
mk_note() { jq -cn --arg ts "$2" --arg tid "$3" --arg tu "$4" '{type:"attachment",timestamp:$ts,attachment:{type:"queued_command",prompt:("<task-notification>\n<task-id>"+$tid+"</task-id>\n<tool-use-id>"+$tu+"</tool-use-id>\n<status>completed</status>\n</task-notification>")}}' >> "$1"; }
PROBE_WIN_FROM="2026-03-01T00:00:00Z"; PROBE_WIN_TO="2026-03-01T23:59:59Z"
POLLCMD='{"command":"sleep 200"}'
POLLFG='{"command":"sleep 200","timeout":300000}'
DEN="$REASON"
BGPOLL='{"command":"sleep 200","run_in_background":true}'
BGPLAIN='{"command":"ls","run_in_background":true}'
# A: denied; bg poll-shaped Bash at +60 -> joins, any-bg and poll-shaped
a="$PD/A.jsonl"
mk_use "$a" 2026-03-01T10:00:00Z dA Bash "$POLLCMD"; mk_res "$a" 2026-03-01T10:00:01Z dA "$DEN"
mk_use "$a" 2026-03-01T10:01:01Z bA Bash "$BGPOLL"
# B: denied; bg call only at +200 -> does not join
b="$PD/B.jsonl"
mk_use "$b" 2026-03-01T11:00:00Z dB Bash "$POLLCMD"; mk_res "$b" 2026-03-01T11:00:01Z dB "$DEN"
mk_use "$b" 2026-03-01T11:03:21Z bB Bash "$BGPOLL"
# C: denied in one agent, bg call (poll-shaped) in a DIFFERENT agent at +30 -> does not join
c1="$PD/C1.jsonl"; c2="$PD/C2.jsonl"
mk_use "$c1" 2026-03-01T12:00:00Z dC Bash "$POLLCMD"; mk_res "$c1" 2026-03-01T12:00:01Z dC "$DEN"
mk_use "$c2" 2026-03-01T12:00:31Z bC Bash "$BGPOLL"
# D: denied; bg plain Bash at +30 -> any-bg, NOT poll-shaped
d="$PD/D.jsonl"
mk_use "$d" 2026-03-01T13:00:00Z dD Bash "$POLLCMD"; mk_res "$d" 2026-03-01T13:00:01Z dD "$DEN"
mk_use "$d" 2026-03-01T13:00:31Z bD Bash "$BGPLAIN"
# E: denied; Monitor at exactly +120 -> joins (poll-shaped); a second denied with Monitor at +121 -> does not
e="$PD/E.jsonl"
mk_use "$e" 2026-03-01T14:00:00Z dE1 Bash "$POLLCMD"; mk_res "$e" 2026-03-01T14:00:00Z dE1 "$DEN"
mk_use "$e" 2026-03-01T14:02:00Z mE1 Monitor '{"command":"until false; do sleep 5; done"}'
mk_use "$e" 2026-03-01T15:00:00Z dE2 Bash "$POLLCMD"; mk_res "$e" 2026-03-01T15:00:00Z dE2 "$DEN"
mk_use "$e" 2026-03-01T15:02:01Z mE2 Monitor '{"command":"until false; do sleep 5; done"}'
# F: control: a foreground poll that RAN over budget, bg poll at +10 -> control joins
f1="$PD/F.jsonl"
mk_use "$f1" 2026-03-01T16:00:00Z cF Bash "$POLLFG"; mk_res "$f1" 2026-03-01T16:03:20Z cF "done"
mk_use "$f1" 2026-03-01T16:03:30Z bF Bash "$BGPOLL"
# G: a bg call BEFORE the denied result must not join (look-back is not a follow-up)
g="$PD/G.jsonl"
mk_use "$g" 2026-03-01T17:00:00Z bG Bash "$BGPOLL"
mk_use "$g" 2026-03-01T17:00:10Z dG Bash "$POLLCMD"; mk_res "$g" 2026-03-01T17:00:11Z dG "$DEN"
# Idling. RAN-bg polls (foreground-timeout absent, bg true, poll-shaped command)
# H1: launch, notification 100 s later, nothing between -> idle
h="$PD/H.jsonl"
mk_use "$h" 2026-03-01T18:00:00Z h1 Bash "$BGPOLL"; mk_res "$h" 2026-03-01T18:00:01Z h1 "Command running in background with ID: bh1. Output is being written to: /x/tasks/bh1.output."
mk_note "$h" 2026-03-01T18:01:40Z bh1 h1
# H2: launch, an Edit between, notification -> not-idle; a Read of ITS OWN output is not work
mk_use "$h" 2026-03-01T19:00:00Z h2 Bash "$BGPOLL"; mk_res "$h" 2026-03-01T19:00:01Z h2 "Command running in background with ID: bh2. Output is being written to: /x/tasks/bh2.output."
mk_use "$h" 2026-03-01T19:00:20Z r2 Read '{"file_path":"/x/tasks/bh2.output"}'
mk_use "$h" 2026-03-01T19:00:40Z e2 Edit '{"file_path":"/y"}'
mk_note "$h" 2026-03-01T19:01:40Z bh2 h2
# H3: launch, only a Read of its own output between -> idle (reading that output is not work)
mk_use "$h" 2026-03-01T20:00:00Z h3 Bash "$BGPOLL"; mk_res "$h" 2026-03-01T20:00:01Z h3 "Command running in background with ID: bh3. Output is being written to: /x/tasks/bh3.output."
mk_use "$h" 2026-03-01T20:00:20Z r3 Read '{"file_path":"/x/tasks/bh3.output"}'
mk_note "$h" 2026-03-01T20:01:40Z bh3 h3
# H4: launch, no notification anywhere -> unjoined
mk_use "$h" 2026-03-01T21:00:00Z h4 Bash "$BGPOLL"; mk_res "$h" 2026-03-01T21:00:01Z h4 "Command running in background with ID: bh4. Output is being written to: /x/tasks/bh4.output."
# H5: chain: launcher bg exits; a Monitor on its output; the Monitor ends later; an Edit sits inside the chain -> chain, not idle
mk_use "$h" 2026-03-01T22:00:00Z h5 Bash "$BGPOLL"; mk_res "$h" 2026-03-01T22:00:01Z h5 "Command running in background with ID: bh5. Output is being written to: /x/tasks/bh5.output."
mk_note "$h" 2026-03-01T22:00:05Z bh5 h5
mk_use "$h" 2026-03-01T22:00:10Z m5 Monitor '{"command":"until grep -q done /x/tasks/bh5.output; do sleep 5; done"}'
mk_res "$h" 2026-03-01T22:00:11Z m5 "Monitor started (task mon5, expires in 10m unless the source ends first)."
mk_use "$h" 2026-03-01T22:00:30Z e5 Edit '{"file_path":"/y"}'
mk_note "$h" 2026-03-01T22:05:00Z mon5 m5
# H6: the notification sits EARLIER in the file than the launch result (line order lies); timestamps decide
mk_note "$h" 2026-03-01T23:01:40Z bh6 h6
mk_use "$h" 2026-03-01T23:00:00Z h6 Bash "$BGPOLL"; mk_res "$h" 2026-03-01T23:00:01Z h6 "Command running in background with ID: bh6. Output is being written to: /x/tasks/bh6.output."

PROBE_LIST="$WORK/probe.list"
/usr/bin/find "$PD" -name '*.jsonl' | LC_ALL=C sort > "$PROBE_LIST"
extract_files "$PROBE_LIST" "$WORK/probe.events"
summarize_events "$WORK/probe.events" "$PROBE_WIN_FROM" "$PROBE_WIN_TO" "$WORK/probe.summary"
# expected: DENIED polls dA dB dC dD dE1 dE2 dG = 7; any-bg: A D E1 G? (G's bg is BEFORE) -> A, D, E1 = 3; poll-shaped: A, E1 = 2.
# control: RAN-fg-over-budget cF = 1, any-bg 1, poll-shaped 1.
got="$(jq -c '[.denied.n, .denied.any_bg, .denied.poll_shaped, .control.n, .control.any_bg, .control.poll_shaped]' "$WORK/probe.summary")"
if [ "$got" != '[7,3,2,1,1,1]' ]; then
  echo "self-probe FAILED (join arm): got [den,any,poll,ctl,ctlany,ctlpoll] $got, want [7,3,2,1,1,1]" >&2
  exit 2
fi
# idling on the RAN-bg launches alone: probe polls bA..bG and h1..h6 are all RAN-bg polls, so restrict to H.jsonl's by id
got="$(jq -c '.idling.ran_bg | [.n]' "$WORK/probe.summary")"
# RAN-bg polls: bA bB bC bF bG (no result -> not DENIED, bg true -> RAN-bg), bD is not a poll; h1..h6 -> 6 more; mE* are Monitors
# bA,bB,bC,bF,bG,h1,h2,h3,h4,h5,h6 = 11
if [ "$got" != '[11]' ]; then
  echo "self-probe FAILED (idling arm, population): got $got, want [11]" >&2
  exit 2
fi
# per-launch verdicts for the H file only
extract_h="$WORK/probe.H.events"
/usr/bin/grep -F "\"file\":\"$PD/H.jsonl\"" "$WORK/probe.events" > "$extract_h" || die2 "probe H events empty"
summarize_events "$extract_h" "$PROBE_WIN_FROM" "$PROBE_WIN_TO" "$WORK/probe.H.summary"
got="$(jq -c '.idling.ran_bg | [.n, .idle, .not_idle, .unjoined, .chain, .chain_idle, .chain_not_idle]' "$WORK/probe.H.summary")"
# h1 idle, h2 not-idle (Edit), h3 idle (own-output Read only), h4 unjoined, h5 chain (Edit inside -> chain_not_idle), h6 idle (notification earlier in file order)
if [ "$got" != '[6,3,1,1,1,0,1]' ]; then
  echo "self-probe FAILED (idling arm): got [n,idle,not_idle,unjoined,chain,chain_idle,chain_not_idle] $got, want [6,3,1,1,1,0,1]" >&2
  exit 2
fi
echo "self-probe: PASS (join: 7 denied -> 3 any-bg, 2 poll-shaped, control 1/1/1; a +60 s same-agent bg call joins, +121 s, a different agent, and a call before the result do not, +120 s does; idling: idle 3, not-idle 1, unjoined 1, chain 1 not-idle)"

# ---- the corpus -------------------------------------------------------------------
if [ ! -s "$TARGETS" ]; then
  echo "no corpus given: self-probe only"
  rm -f "$TARGETS"
  exit 0
fi
[ "${#WINDOWS[@]}" -gt 0 ] || die2 "at least one --window LABEL=FROM..TO is required with a corpus"
: > "$WORK/corpus.list"
while IFS= read -r t; do
  if [ -d "$t" ]; then list_dir "$t" >> "$WORK/corpus.list" || die2 "find failed on $t"
  elif [ -f "$t" ]; then printf '%s\n' "$t" >> "$WORK/corpus.list"
  else die2 "no such file or directory: $t"; fi
done < "$TARGETS"
LISTED="$(awk 'END { print NR }' "$WORK/corpus.list")"
[ "$LISTED" -gt 0 ] || die2 "corpus lists 0 files"
extract_files "$WORK/corpus.list" "$WORK/events.jsonl"
[ "$OPENED" = "$LISTED" ] || die2 "listed $LISTED files, opened $OPENED"

# controls: a known-present token must count > 0 and the absent token 0, over the same files
PRESENT_N=0; ABS_N=0
while IFS= read -r f; do
  n="$(grep -cF -- '"tool_use"' "$f")" || n=0; PRESENT_N=$((PRESENT_N + n))
  n="$(grep -cF -- "$ABSENT" "$f")" || n=0; ABS_N=$((ABS_N + n))
done < "$WORK/corpus.list"
[ "$PRESENT_N" -gt 0 ] || die2 "known-present control failed: 0 tool_use records in the input"
[ "$ABS_N" = "0" ] || die2 "absent-token control failed: '$ABSENT' occurs $ABS_N time(s) in the input"

# corpus state
FIRST_TS="$(jq -rs 'map(select(.ts != null) | .ts) | min' "$WORK/events.jsonl")"
LAST_TS="$(jq -rs 'map(select(.ts != null) | .ts) | max' "$WORK/events.jsonl")"
echo "mode: corpus   hook: $HOOK   budget: ${BUDGET}s   span: ${SPAN}s"
echo "reason lifted: $REASON"
echo "files listed: $LISTED   opened: $OPENED   earliest record (tu/res/note): $FIRST_TS   latest: $LAST_TS"
echo "controls: tool_use records ${PRESENT_N} > 0; absent token '${ABSENT}' count ${ABS_N}"

RC=0
for w in "${WINDOWS[@]}"; do
  label="${w%%=*}"; rng="${w#*=}"; from="${rng%%..*}"; to="${rng#*..}"
  [ -n "$label" ] && [ -n "$from" ] && [ -n "$to" ] && [ "$label" != "$w" ] || die2 "bad --window '$w', want LABEL=FROM..TO"
  out="$WORK/sum.$label.json"
  summarize_events "$WORK/events.jsonl" "$from" "$to" "$out"
  # same-invocation control: classify.sh over the same targets and window
  tg=(); while IFS= read -r t; do tg+=("$t"); done < "$TARGETS"
  bash "$CLASSIFY" --hook "$HOOK" --budget "$BUDGET" --from "$from" --to "$to" --absent "$ABSENT" --denied-ids "$WORK/cls.$label.ids" "${tg[@]}" > "$WORK/cls.$label.out" 2> "$WORK/cls.$label.err"
  crc=$?
  [ "$crc" = "0" ] || { echo "join: classify.sh exited $crc for window $label (stderr: $(head -c 400 "$WORK/cls.$label.err"))" >&2; RC=1; }
  jq -r '.denied.ids[] | "\(.id)\t\(.file)"' "$out" | LC_ALL=C sort > "$WORK/join.$label.ids"
  nj="$(awk 'END { print NR }' "$WORK/join.$label.ids")"; nc="$(awk 'END { print NR }' "$WORK/cls.$label.ids")"
  if cmp -s "$WORK/join.$label.ids" "$WORK/cls.$label.ids"; then
    ctl="EQUAL (join $nj, classify.sh $nc, same tool_use ids and files)"
  else
    ctl="MISMATCH (join $nj, classify.sh $nc)"; RC=2
  fi
  clsden="$(awk -F'\t' '$1 == "DENIED" { print $2 }' "$WORK/cls.$label.out")"
  clsfg="$(awk -F'\t' '$1 == "RAN-fg-over-budget" { print $2 }' "$WORK/cls.$label.out")"
  echo "== window $label  $from .. $to"
  echo "DENIED ids control: $ctl; classify.sh bucket line DENIED=${clsden:-?}"
  jq -r --arg fg "${clsfg:-?}" '
    "Bash polls in window: \(.bash_polls)   duplicate Bash tool_use ids: \(.dup)   buckets: \(.buckets | tojson)   (classify.sh RAN-fg-over-budget=\($fg))",
    "(c) DENIED \(.denied.n) -> any-bg-or-Monitor within span \(.denied.any_bg), poll-shaped \(.denied.poll_shaped)   (unjoined results \(.denied.unjoined))",
    "(c) control RAN-fg-over-budget \(.control.n) -> any-bg-or-Monitor \(.control.any_bg), poll-shaped \(.control.poll_shaped)   (unjoined results \(.control.unjoined))",
    "(b) idling, per backgrounded launch (idle = no tool_use other than on the launch own output between launch and completion):",
    (.idling | to_entries[] | "    \(.key): launches \(.value.n)  idle \(.value.idle)  not-idle \(.value.not_idle)  unjoined \(.value.unjoined) \(.value.unjoined_why | tojson)  chain \(.value.chain) (idle \(.value.chain_idle), not-idle \(.value.chain_not_idle))  idle-wide(all joined) \(.value.idle_wide_all)  idle-secs \(.value.idle_secs)  not-idle-secs \(.value.not_idle_secs)  kinds \(.value.by_kind | tojson)")' "$out"
  if [ "$crc" = "0" ]; then
    din="$(awk -F'\t' '$1 == "DENIED" { print $2 }' "$WORK/cls.$label.out")"
    jn="$(jq -r '.denied.n' "$out")"
    [ "$din" = "$jn" ] || { echo "INTEGRITY: classify.sh bucket DENIED $din != join DENIED $jn" >&2; RC=2; }
  fi
  if [ -n "$DETAIL" ]; then jq -c --arg l "$label" '. + {window: $l}' "$out" >> "$DETAIL"; fi
done
rm -f "$TARGETS"
exit "$RC"
