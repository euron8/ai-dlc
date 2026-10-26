#!/usr/bin/env bash
# ai-dlc-foreground-budget.sh -- refuses a FOREGROUND Bash call whose declared timeout exceeds
# the steering budget, and tells the caller to re-issue it with `run_in_background: true`.
#
# WHAT IT ENFORCES. `validate-steering-budget.sh` Check A counts foreground tool calls that
# blocked longer than `AI_DLC_STEERING_BUDGET` seconds (default 120), and it counts them AFTER
# the fact, from the transcript. Filed by the reference consumer as
# PC-S315-STEERING-BUDGET-COUNTS-BUT-DOES-NOT-PREVENT: the same lead-conduct failure recurred
# across sprints because recording the count was its only consequence. This hook is the
# preventing half; the validator stays the detector.
#
# WHY A DENY AND NOT A WARNING. A PreToolUse `additionalContext` reaches the model together with
# the tool RESULT, which is after the foreground block it was warning about. A warning therefore
# cannot prevent the one thing it exists for. Only `permissionDecision: "deny"` acts before the
# call runs.
#
# WHY THE DECLARED TIMEOUT AND NOT A REGISTRY OF KNOWN-LONG COMMANDS. Runtime is unknowable
# before the call; the declared `timeout` is the caller's own statement of how long it is
# prepared to block. Measured on the consumer's 15 sprint transcripts: `timeout > 120000` flags
# 183 calls and catches 29 of the 41 overruns, where a command-name registry flags 425 and
# catches 9. What it cannot see: the 12 overruns that declared no timeout at all. Those run
# under the harness default and stay the detector's to count.
#
# TWO EXEMPTIONS, EACH ALLOWED SILENTLY.
#   A `git push`. The pipeline REQUIRES it in the foreground at `timeout: 600000`:
#   `_gate-procedures.md` ("Auto-handoff evaluation", step 3), `steps/handoff.md` step 3,
#   `steps/retro.md` 6b and the handoff guard in `ai-dlc-continue.sh` all say so, because the
#   push runs the pre-push fixture suite and a backgrounded push loses the exit code the
#   handoff reads. Both remedies a deny offers break that call, so a deny there is a wedge. The
#   match is a command whose first word is `git` and whose subcommand is `push`, optionally
#   after one leading `cd <path> &&` and `VAR=x` assignments, with nothing chained or piped
#   after it (`;`, `&&`, `||`, `|`, a single `&`, a newline). A push WITH something after it is denied with a
#   push-specific reason whose one remedy is to drop the rest (PUSHCHAIN, below).
#   The exemption is the HOOK's only: validate-steering-budget.sh Check A still counts a
#   foreground push that ran past the budget.
#   A call carrying a non-empty `agent_id` -- a dispatched teammate or subagent -- UNLESS it is
#   a poll (POLL, below). A subagent's ordinary long call, a build or a suite run, is its job and
#   stays exempt. A subagent's foreground POLL is not: it holds the agent idle on a wait the job
#   could have announced. Check A reads the lead's transcript and filters `!r.isSidechain`, so it
#   drops every subagent call and can never count one; that blindness is exactly why this hook
#   must act on a subagent poll itself, because nothing downstream will. The convention is the
#   one `ai-dlc-acknowledge.sh` states: `agent_id`, never `agent_type`.
#
# WHY IT CANNOT WEDGE. Every deny is satisfiable on the next call, by an action that is always
# available. A budget deny: the same call with `run_in_background: true`, or with a timeout at
# or under the budget; the poll reason names the first, and backgrounding the job itself rather
# than the wait. A WAITER deny (DENY A, below): the same command without the `&`, with
# `run_in_background: true`. A SNAPSHOT deny (DENY B, below): the same change made with the Edit
# or Write tool. Apart from those two command shapes, a call with no timeout, a timeout within
# budget, `run_in_background: true`, a `git push`, or a teammate's non-poll call is never
# touched; the two shapes are refused whatever the call's timeout, caller or backgrounding. Every
# state this hook cannot read -- no `jq`, unparseable input, an unreadable budget, no detector to
# take the default from -- ALLOWS a budget-scoped call and says so on stderr; no `jq` and
# unparseable input allow the two shapes too. A guard that cannot read its input must not deny.
#
# DENY A, A BACKGROUNDED WAITER. A command that runs `wait-for-deliverable.sh` as a command word
# (any path prefix; at the start or after `;` `&&` `||` `|` `(` a newline `then` `do` `else`,
# optionally behind `nohup`/`env`/`exec`/`bash`/`sh` and `VAR=x`) whose SEGMENT ends in a lone
# `&` -- an `&` that is not `&&`, `&>`, `|&`, nor the `&` of `2>&1`/`>&2`/`<&0`. The segment may
# carry quoted words, a `$(...)` and a `|` before that `&`, so `wfd ... 2>&1 | head -3 &` and
# `wfd --since "$(date ...)" ... & disown` are both seen. The harness's completion notification
# belongs to the CALL: a waiter put behind `&` inside it detaches from the call, the call
# returns, and the beat it was armed for is never delivered. One waiter per call, backgrounded by
# `run_in_background: true`, is the convention, and that remedy is always available -- which is
# why the `&` is refused under `run_in_background: true` too, and why `wfd a & wfd b & wait` is
# refused. It runs before the timeout and `agent_id` gates because those gates exempt exactly the
# calls that carried this shape (no timeout, a subagent). A mention inside a quoted argument
# (`grep 'wait-for-deliverable.sh x &' f`, `echo "... &"`) is not a command word and is allowed.
# Known misses: `bash -c 'wfd x &'` (the `&` is inside a quoted string) and a waiter called
# through a variable (`w=.../wait-for-deliverable.sh; $w x &`).
# Measured on graph's transcripts (5,236 files, 253,881 Bash calls; 7,280 naming the script, 5,913
# distinct): 23 distinct commands denied, and every one backgrounds the waiter with a lone `&`
# (`>/dev/null 2>&1 &`, `... & echo armed`, `... & sleep 0; echo`, `... & disown`, `( ... & )`,
# `... 2>&1 | head -3 &`). An independent scan for a lone `&` on a line naming the script, with
# quoted strings and redirection `&`s removed, found 25: the 23, plus the two documented misses
# (one via `$wait`, one inside `bash -c '...'`). FP set: empty. The first grammar ended the
# segment at any quote or `$(`/`|`, which missed 4 of the 25; the quoted-word, `$(...)` and pipe
# alternatives in the segment class are that narrowing. `wfd ...; sleep 5 & y` and
# `T=$(wfd --dispatch-ts a) && sleep 1 &` stay allowed: the `&` closes another segment.
#
# DENY B, A SHELL WRITE OF THE SNAPSHOT. A command naming `pipeline-snapshot.md` (as a path ending
# there: `pipeline-snapshot.md.bak` and `pipeline-snapshot-history.md` are other files) that
# WRITES it: `sed`/`perl` with `-i`/`--in-place` (BSD `-i ''`, GNU `-i`, `-i.bak`), a `>`/`>>`
# redirect onto it, `tee [-a]` naming it, `cp|mv|install|ln` with it as the LAST operand, `git
# checkout|restore` of it, or an interpreter write -- `open(<it>, 'w'|'a'|'x'|'+')`,
# `.write_text(`, `.write_bytes(`, `.open('w')`, `writeFileSync`/`appendFile*` -- on the literal
# path or on a variable assigned that path earlier in the same command (`p='...snapshot.md'` then
# `open(p,'w')`, `S=...; sed -i '' ... "$S"`). A shell write reaches no PostToolUse hook, so
# `ai-dlc-derivation-capture.sh` (which judges `*/pipeline-snapshot.md` writes made by Edit or
# Write) never sees the stamps it wrote; the remedy routes the same change through that judge.
# Reads stay allowed: `cat`, `grep`, `sed -n`, `<`, a `python3` `open(p)` or `open(p,'r')`, a
# redirect whose TARGET is another file, `git add/commit/show/diff`, `cp` FROM it, and a
# `bash <core script> ... pipeline-snapshot.md` call -- no core script takes the snapshot
# path as an argument and writes it (`rotate-snapshot-archive.sh` writes the ARCHIVE).
# Measured on graph's transcripts: 4,617 Bash calls name the snapshot (4,346 distinct). The
# shipped hook denies 1,912 (1,873 distinct); an independent second reading, keyed on the
# variable's LAST binding before each interpreter write site plus a tokenised shell-write scan,
# calls 1,856 of the 1,873 a write of the snapshot, and the other 17 were read one by one: all 17
# are `sed -i ''` writes of it whose expression spans quotes the scan could not tokenise. FP set:
# empty. Misses: 5 commands carry `sed -i` naming `pipeline-snapshot.md` only INSIDE the
# substitution text while the file written is another one (`gate-log.md`, `carry-over-backlog.md`)
# -- allowed, correctly. Narrowing: a variable binding counts only when the path is its whole
# value (`p=Path('...snapshot.md')`, not `x=f(p)` on a line that merely mentions it), and the
# variable must not be followed by `.`/`/` (so `p.with_suffix(...)` and `$p/...` are other files)
# except `.write_text(`/`.write_bytes(`/`.open(`. The fail-closed alternative -- deny a command
# naming the snapshot unless every segment naming it starts with a whitelisted read verb -- was
# measured on the same corpus and denied 1,465 commands the second reading calls no write
# (`scripts/ai-dlc/verdict.sh validate-artifact-budget --only pipeline-snapshot.md`, `ls`,
# `python3 - <<EOF` that only reads); a deny that refuses a read wedges every resume, so the
# write-shape list ships. Over every line under core/ and templates/ (core/fixtures excluded)
# naming either subject -- 222 files, 148 lines naming the waiter, 146 naming the snapshot, 517
# payloads (each line and each backtick span on it) -- the hook denies one: the self-probe
# redirect `} > "$LPROBE_D/state/pipeline-snapshot.md"` inside validate-artifact-budget.sh, which
# is script body, never a Bash call an agent issues.
# Known over-refusals, both refused and neither instructed by core: `git restore --staged <snapshot>`
# (index-only, the file is untouched) and `tee -a log < <snapshot>` (reads the snapshot). A grep of
# core/ and templates/ (core/fixtures excluded) finds 0 lines carrying either shape against a
# control of 153 lines naming the snapshot.
# Cost: the variable-binding regex is superlinear in the number of bindings. The adversary measured
# 1000 bindings at 3.1 s, with ordinary calls at about 0.08 s against base's 0.04 s; re-measured
# here, 1000 `pN=<snapshot>;` bindings cost 1.6 s per call and a short command naming neither
# subject 0.02 s, the same at base and here.
#
# A REGEX THAT RUNS OUT OF RETRIES IS "NOT THIS SHAPE", NEVER A jq ERROR. Onigmo aborts a match
# with `retry-limit-in-match` on a long run of characters a nested quantifier can split many ways,
# and an uncaught error turned the whole call into "not readable JSON" -- allowed, losing the
# budget deny with the shape deny. Measured: a waiter followed by 50 or more `>` did that. Three
# changes, each with its own REGEXLIMIT seed and mutant: the redirect run is an atomic group
# `(?>[<>]+)`; the blank run before the lone `&` may start only after a non-blank `(?<![ \t])`, so a
# 30000-blank run no longer rescans quadratically and drops a LATER waiter; and every shape test
# goes through `safetest`, so any remaining exhaustion degrades to "not this shape" and the budget scope
# still applies. ONLY a retry-limit exhaustion does: `safetest` catches an error whose text contains
# `retry-limit` (the message is `Regex failure: retry-limit-in-match over`) and rethrows any other, so a
# compile error in `wfdbg` or a Deny B regex fails the jq pass, prints the "not readable JSON" fail-open
# message on every call and is loud, instead of silently never denying. Degrading to "not this shape"
# (the budget check still applies) rather than denying is deliberate: denying a command the regex
# cannot evaluate would wedge correct work. No known input reaches the residue: the 4 REGEXLIMIT seeds
# are the only inputs measured to exhaust it, and 0 of 12,414 real graph payloads raised a jq parse
# failure or changed a verdict. Measured: `sed` with 3000 repeated `-i `
# ahead of a target that is NOT the snapshot (`...snapshot.md.bak`) exhausts the Deny B test; caught,
# it is the correct allow, where before it failed the call open. The same run ahead of the
# snapshot itself is denied.
#
# THE BUDGET IS THE DETECTOR'S, NOT A SECOND COPY OF IT. `AI_DLC_STEERING_BUDGET` is read first,
# exactly as the detector reads it. When it is unset the default is taken from the detector's
# own `BUDGET="${AI_DLC_STEERING_BUDGET:-N}"` line, so the number that decides a deny and the
# number that counts a violation cannot drift apart. The line is read with a bash loop that
# stops at the first match: no fork, and it runs only for a foreground Bash call that declared
# a timeout. If the detector's line is ever respelled this read finds nothing and the hook
# fails OPEN, loudly on stderr; the `foreground-budget-deny` fixture drives the hook against a
# copy of the REAL detector so that respelling fails the suite instead.
#
# THE TWO SHAPES RIDE THE ONE jq PASS. Each regex runs only after a plain `contains` on the
# command finds its subject, so a Bash call naming neither pays two substring tests and nothing
# else. The jq program answers `DENY A` or `DENY B` FIRST, before the tool_name/background/
# timeout/push scope it applies to every other verdict, and the shell acts on that answer before
# the empty-scope exit and before the budget and detector reads.
#
# PROTOCOL. PreToolUse hook, matcher `Bash`: reads the tool call as JSON on stdin, emits a JSON
# decision on stdout. Deny is `permissionDecision: "deny"`, never exit code 2, the contract
# `ai-dlc-protect.sh` established. It emits no `additionalContext`. Silence (exit 0, no output)
# leaves the call to the harness's normal permission flow. It always exits 0.
#
# Compatible with bash 3.2.

set -uo pipefail

say() { printf 'ai-dlc-foreground-budget: %s\n' "$1" >&2; }

command -v jq >/dev/null 2>&1 || { say "jq not found, so the tool call cannot be read; allowing it (fail-open)"; exit 0; }

# ONE jq pass decides whether this call is in scope at all, and prints its declared timeout in
# whole milliseconds, rounded UP, when it is. Out of scope prints nothing. The clamp at 1e9 is
# load-bearing: jq renders 1e12 as `1E+12`, which the digit test below would read as unreadable
# and ALLOW -- the largest timeouts escaping the check. 1e9 ms is above every budget the
# six-digit cap further down admits, so clamping loses no verdict.
#
# The push test anchors on the command START, after at most one leading `cd <path> &&` and any
# `VAR=x` assignments, and requires `push` as a whole word. So `echo git push`,
# `git log --grep=push` and `git pushx` stay in scope. After that prefix is stripped, a command
# carrying `;`, `&&`, `||`, `|`, a single `&` or a newline is not a bare push either, so a long command chained
# behind a push cannot ride the exemption.
#
# PUSHCHAIN, the second field. A command whose FIRST segment is a push but which fails the bare
# test because something is chained or piped after it is still in scope -- measured on graph, a
# lead's `git push ... > f 2>&1; echo "push_rc=$?"; tail -3 f` was denied here with a reason
# whose two remedies both break the push. Such a call gets the push-specific reason instead:
# drop what follows the push. A single `|` counts as a chain, because `git push ... | tail -5`
# replaces the push's exit status with tail's, which is how a push lost its result on graph. A
# single `&` counts too: `git push ... & sleep 900` backgrounds the push and blocks on the sleep.
# The `&` of a redirection (`2>&1`, `>&2`, `&>`) is not a chain, so a bare push with `2>&1` stays exempt.
#
# POLL, the third field. A call carrying an `agent_id` is in scope only when it is a POLL: its
# command runs an `until`/`while`/`for` loop whose body runs `sleep`, or a `sleep N` with N of 30
# or more, either one at any command position -- the start, or after `;` `&&` `||` `|` `(` a
# newline `then` `do` or `else` -- so `S=/x; for ...` and `cd /x && sleep 200` are polls too, not
# only a command whose first word is the loop. The loop body ends at the `done` TERMINATOR (loopend:
# a `done` after a separator, followed by a blank, separator, `)`, a redirect or the end), never at
# a word `done` inside the condition, so `grep -q '^done' f` and `[ -f $S/chain.done ]` loops are
# seen. Known miss: a sleep in an OUTER loop placed after a nested inner loop's `done`. `{` is not a
# command position: graph's replay holds no `{`-prefixed poll, so adding it could not be shown to
# catch anything. The other gates are the lead's. The cheap jq ones -- Bash, an object input, not
# backgrounded, a numeric timeout, not a push -- run FIRST, so the poll regex is evaluated only for
# a subagent call that passed them; the comparison against the budget follows in the shell,
# because the detector read is deferred to in-scope calls. Measured by replaying graph's 3,227
# transcript files (104,914 sidechain Bash calls; 1,599 foreground over 120 s) through this hook
# with agent_id set and the real detector's 120 s default: 198 denied, 152 sleeping loops and 46
# sleeps of 30 s or more with no loop; 17.0 h of wall clock, measured per call as the tool_use to
# tool_result timestamp delta (0 unpaired; the declared timeouts sum to 27.7 h). Every denied
# loop carries a completion test on the agent's own job or an artifact (condition shapes: 64
# counted `for` with an inner test, 62 `grep -q`, 23 `kill -0`/`ps`/`pgrep`, 3 `[ -f ]`). No retry
# loop is in scope: by a looser loop-then-sleep regex over all calls, the 26 sleeping loops that
# declare no timeout, the 10 at or under budget and the 54 backgrounded ones never reach the test.
T="$(jq -r '
  def cmdtext: (if (.tool_input | type) == "object" then .tool_input.command else "" end) // "" | tostring;
  def wfdbg: "(?:^|[;&|\n(]|(?:^|[ \t;\n])(?:then|do|else)[ \t\n])[ \t\n]*(?:(?:nohup|env|exec|bash|sh)[ \t]+|[A-Za-z_][A-Za-z0-9_]*=[^ \t;&|\n]*[ \t]+)*[\"\u0027]?[^ \t\n;&|()<>\"\u0027]*wait-for-deliverable\\.sh[\"\u0027]?(?=[ \t\n;&|)<>]|$)(?:\"[^\"\n]*\"|\u0027[^\u0027\n]*\u0027|\\$\\([^()\n]*\\)|[^;&|\n()<>\"\u0027]|[|](?![|&])|(?>[<>]+)(?:&[0-9-]*|(?!&))|&>>?)*?(?<![ \t])[ \t]*(?:\\)[ \t]*)*&(?![&>])";
  def ps: "pipeline-snapshot\\.md(?![A-Za-z0-9_.-])";
  def seg: "(?:\u0027[^\u0027\n]*\u0027|\"[^\"\n]*\"|[^;&|\n\u0027\"])*";
  def bw: "(?:^|[^A-Za-z0-9_./-])";
  def inplaceverb: "(?:g?sed|perl)";
  def shwrite($tg): bw + inplaceverb + "[ \t](?:" + seg + "[ \t])?(?:-[A-Za-z]*i|--in-place)" + seg + $tg
    + "|(?:^|[^0-9&>=-])[0-9]*>>?[|]?[ \t]*" + $tg
    + "|" + bw + "tee[ \t]" + seg + $tg
    + "|" + bw + "(?:cp|mv|install|ln)[ \t]" + seg + $tg + "[\"\u0027]?[ \t]*(?:$|[;&|\n)])"
    + "|" + bw + "git[ \t]" + seg + "(?:checkout|restore)[ \t]" + seg + $tg;
  def pywrite($tg): "open\\([ \t]*(?:Path\\([ \t]*)?" + $tg + "[ \t]*\\)?[ \t]*,[ \t]*(?:mode[ \t]*=[ \t]*)?[\"\u0027][rbt]*[wax+]"
    + "|(?:Path\\([ \t]*)?" + $tg + "[ \t]*\\)?\\.(?:write_text|write_bytes)\\("
    + "|(?:Path\\([ \t]*)?" + $tg + "[ \t]*\\)?\\.open\\([ \t]*(?:mode[ \t]*=[ \t]*)?[\"\u0027][rbt]*[wax+]"
    + "|(?:writeFileSync|appendFileSync|writeFile|appendFile)\\([ \t]*" + $tg;
  def lit: "[\"\u0027]?[^ \t\n;&|()<>\"\u0027]*" + ps + "[\"\u0027]?";
  def bind: "(?:^|[^A-Za-z0-9_])([A-Za-z_][A-Za-z0-9_]*)[ \t]*=[ \t]*(?:Path\\([ \t]*)?[\"\u0027]?[^ \t\n;&|()<>\"\u0027]*" + ps + "[\\s\\S]*?(?:";
  def var: "[\"\u0027]?(?:\\$\\{?)?(?<![A-Za-z0-9_.])\\1\\}?(?![A-Za-z0-9_/-])(?!\\.(?!write_|open\\())[\"\u0027]?";
  def safetest($re): try test($re) catch (if (tostring | test("retry-limit")) then false else error end);
  def snapwrite: safetest(shwrite(lit) + "|" + pywrite(lit)) or safetest(bind + shwrite(var) + "|" + pywrite(var) + ")");
  def cmdpos: "(^|[;&|\n(]|(^|[ \t;\n])(then|do|else)[ \t\n])[ \t\n]*";
  def loopend: "[;&|\n][ \t]*done([ \t;&|)<>\n]|$)";
  def loopsleep: test(cmdpos + "(until|while|for)[ \t](?:(?!" + loopend + ")[\\s\\S])*" + cmdpos + "sleep([ \t]|$)");
  def longsleep: [match(cmdpos + "sleep[ \t]+([0-9]+)"; "g") | .captures[-1].string | tonumber] | any(. >= 30);
  def is_poll: ((if (.tool_input | type) == "object" then .tool_input.command else "" end) // "") | tostring | (loopsleep or longsleep);
  def pushfirst: test("^[ \t]*(cd[ \t]+[^;&|\n]+&&[ \t]*)?([A-Za-z_][A-Za-z0-9_]*=[^ \t;&|\n]*[ \t]+)*git[ \t]+push([ \t]|$)");
  def chained: sub("^[ \t]*cd[ \t]+[^;&|\n]+&&"; "") | test("[;\n|]|&&|(^|[^>&])&($|[^&>])");
  def is_push: ((.tool_input.command // "") | tostring) as $c
    | ($c | test("^[ \t]*(cd[ \t]+[^;&|\n]+&&[ \t]*)?([A-Za-z_][A-Za-z0-9_]*=[^ \t;&|\n]*[ \t]+)*git[ \t]+push([ \t]|$)"))
      and ($c | chained | not);
  def pushchain: ((if (.tool_input | type) == "object" then .tool_input.command else "" end) // "") | tostring | pushfirst and chained;
  (if .tool_name == "Bash" then cmdtext else "" end) as $cmd
  | if ($cmd | contains("wait-for-deliverable.sh")) and ($cmd | safetest(wfdbg)) then "DENY A"
  elif ($cmd | contains("pipeline-snapshot.md")) and ($cmd | snapwrite) then "DENY B"
  else
  pushchain as $pc
  | if .tool_name == "Bash"
     and (.tool_input | type) == "object"
     and .tool_input.run_in_background != true
     and (.tool_input.timeout | type) == "number"
     and (is_push | not)
  then ((.agent_id // "") | tostring) as $agent
    | (if $agent == "" then false else is_poll end) as $poll
    | select($agent == "" or $poll)
    | .tool_input.timeout | if . < 0 then 0 elif . > 1e9 then 1e9 else . end | -((-.) | floor) | tostring | . + " " + (if $pc then "1" else "0" end) + " " + (if $poll then "1" else "0" end)
  else empty end end' 2>/dev/null)"
PARSE_RC=$?
if [ "$PARSE_RC" -ne 0 ]; then
  say "the tool call is not readable JSON, so its timeout cannot be checked; allowing it (fail-open)"
  exit 0
fi

deny() {
  jq -n --arg reason "$1" \
    '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      }
    }'
  exit 0
}

# The two command-shape denies are decided HERE, before the empty-scope exit and before every
# budget and detector fail-open below, so no timeout, agent_id, run_in_background or missing
# detector can exempt them.
case "$T" in
  'DENY A') deny "AI/DLC: this Bash call backgrounds wait-for-deliverable.sh with a shell \`&\`. The waiter's completion notification then never reaches you: the call returns at once and the beat is orphaned. Re-issue the same command WITHOUT the trailing \`&\` and with run_in_background: true, one waiter per call, and act on its completion notification." ;;
  'DENY B') deny "AI/DLC: this Bash call writes pipeline-snapshot.md by shell (sed -i, perl -i, a > or >> redirect, tee, cp/mv/install/ln onto it, git checkout/restore of it, or an interpreter open/write_text on it). A shell write reaches no PostToolUse hook, so the stamps it writes are never judged. Make the change with the Edit tool (or Write) so ai-dlc-derivation-capture.sh judges the written stamps. Reading the snapshot by shell is not refused." ;;
esac

[ -n "$T" ] || exit 0
POLL="${T##* }"
T="${T% *}"
PUSHCHAIN="${T##* }"
T="${T%% *}"
case "$T" in
  *[!0-9]*) say "unreadable timeout value '$T'; allowing the call (fail-open)"; exit 0 ;;
esac

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
B="${AI_DLC_STEERING_BUDGET:-}"
SRC="AI_DLC_STEERING_BUDGET"
if [ -z "$B" ]; then
  # The consumer spelling only: install.sh lands core/scripts/ at scripts/ai-dlc/, and this hook
  # is registered only in a consumer's settings.json.
  SRC="$PROJECT_DIR/scripts/ai-dlc/validate-steering-budget.sh"
  if [ ! -f "$SRC" ]; then
    say "no scripts/ai-dlc/validate-steering-budget.sh under $PROJECT_DIR and AI_DLC_STEERING_BUDGET is unset, so there is no budget to hold this call to; allowing it (fail-open)"; exit 0
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      'BUDGET="${AI_DLC_STEERING_BUDGET:-'*) B="${line#*:-}"; B="${B%%\}*}"; break ;;
    esac
  done < "$SRC"
fi

case "$B" in
  ''|*[!0-9]*) say "steering budget '$B' (from ${SRC}) is not a whole number of seconds; allowing the call (fail-open)"; exit 0 ;;
esac
# A budget past six digits (about eleven days) holds no realistic call, and it keeps the limit
# below the 1e9 clamp on the timeout above.
[ "${#B}" -le 6 ] || exit 0
B=$((10#$B))
LIMIT=$((B * 1000))

[ "$T" -gt "$LIMIT" ] || exit 0

case "$SRC" in
  AI_DLC_STEERING_BUDGET) WHERE="AI_DLC_STEERING_BUDGET" ;;
  *) WHERE="the default in validate-steering-budget.sh; AI_DLC_STEERING_BUDGET overrides it" ;;
esac

REASON="AI/DLC steering budget: this FOREGROUND Bash call declares timeout ${T} ms, over the ${B}s steering budget (${WHERE}). A foreground call blocks the operator from steering until it returns, and validate-steering-budget.sh Check A counts every one that runs past the budget. Re-issue the same call with run_in_background: true and collect its result when it completes, or declare a timeout of at most ${LIMIT} ms."
# The push reason carries neither general remedy: a backgrounded push loses the exit code the
# step reads, and a push held under the budget is SIGKILLed while the pre-push suite runs.
if [ "$PUSHCHAIN" = 1 ]; then
  REASON="AI/DLC steering budget: this FOREGROUND Bash call starts with a git push and chains or pipes more commands after it, so it is not the bare push the pipeline exempts at timeout ${T} ms. Drop the chained commands: the push is the whole command, \`git push -u origin HEAD\` and nothing after it, at the same timeout and in the foreground. Read the push's exit code from the tool result; a \`; echo \$?\`, a \`| tail\` or a redirect-then-read is not needed, and a pipe replaces the push's exit code with the last command's."
# A subagent's poll gets neither general remedy alone: a shorter timeout keeps the poll and only
# cuts it off, and the wait it is spending belongs to a job that can notify on completion.
elif [ "$POLL" = 1 ]; then
  REASON="AI/DLC steering budget: this subagent's FOREGROUND Bash call is a poll (a loop that sleeps, or a sleep of 30 s or more) declaring timeout ${T} ms, over the ${B}s steering budget (${WHERE}). A foreground poll holds the agent idle, and the lead's steering-budget count never sees a subagent's call. Instead, re-issue the job itself with \`run_in_background: true\` and act on its completion notification; do not poll it. To wait on ANOTHER agent's paths use \`wait-for-deliverable.sh --complete\`, backgrounded."
fi

jq -n --arg reason "$REASON" \
  '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
exit 0
