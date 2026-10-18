# ai-dlc-usage-tokens.sh -- the ONE reading of how much context an assistant turn occupied.
#
# SOURCED, NEVER EXECUTED. No shebang, no `set`, no top-level work beyond one assignment: a
# library that changes shell options changes them for whichever caller sourced it.
#
# WHAT IT PROVIDES. One shell variable, `CTX_TOKENS_DEF`, holding a jq `def ctx_tokens:`. A
# caller PREPENDS it to its own jq program and applies `ctx_tokens` to a `usage` object:
#
#     jq "${CTX_TOKENS_DEF}"' .message.usage | ctx_tokens'
#
# It is a jq definition in a shell string, not a shell function, because both readers already
# compute the figure INSIDE a jq program -- the subagent probe takes a max over every turn of a
# transcript in one pass -- and a shell function would cost them a fork per turn.
#
# WHY THIS EXISTS. Two hooks read the same quantity off the same record shape and their answers
# must not drift: ai-dlc-context-sensor.sh (the lead's current context, banded against the
# compaction threshold) and ai-dlc-subagent-probe.sh (a teammate's PEAK context, read against
# the same threshold). The sensor learned that an advisor turn's top-level usage is not a
# context size; the probe kept its own copy of the old sum and went on recording advisor turns
# at roughly DOUBLE. Measured over real subagent transcripts: 692 of the 699 that carried an
# advisor turn in this repo recorded an inflated peak, and 1244 of 1254 on the graph consumer;
# the largest read 873695 against a true peak of 441012. Two copies of one expression is the
# drift this file exists to remove, so NEITHER hook carries a fallback copy: a hook that cannot
# source this file exits 0 silently, the way it already does on an unparseable reading, and
# I13's "a hook sources a sibling that does not exist" arm is the build-time guard.
#
# AN ADVISOR TURN'S TOP-LEVEL USAGE IS A SUM OVER ITS API ITERATIONS, NOT A CONTEXT SIZE. A turn
# that calls the advisor carries `usage.iterations`: the main `message` call, the advisor's
# `advisor_message`, then the main `message` again. The top level adds both `message` reads, so
# one advisor call roughly doubles the figure. Measured on the graph consumer's s319 lead: top
# level 554953, iterations 276904 / 277772 / 278049, and the next turn 279085. The context is
# the LAST `message`-type iteration -- not the first (the context grew between them), not the
# advisor's own (that is the advisor's window, not this agent's), and not the max over all of
# them. A usage with no iterations, or with none of type `message`, keeps its top-level reading.
#
# THE FIRST LINE OF THE BODY IS A BARE `.` ON PURPOSE. The two lines after it are the whole
# iteration rule, and a fixture mutant deletes exactly those two to restore the top-level sum;
# the bare `.` keeps the remaining program well-formed when it does. Keep the two lines as they
# are and keep their variable name out of every comment here, because that mutant also counts
# the name to prove both lines went.
CTX_TOKENS_DEF='def ctx_tokens:
  .
  | ([ .iterations[]? | select(.type == "message") ] | last) as $lastmsg
  | ($lastmsg // .)
  | (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0);
'
