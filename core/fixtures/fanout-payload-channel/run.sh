#!/usr/bin/env bash
# fanout-payload-channel — report-propagation-fanout.sh's three unbounded payloads travel
# by FILE, and the channel they must never travel on is the environment.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# `execve` charges its combined argv+envp size limit on the environment block the CHILD
# INHERITS. The subject reads its python program from a heredoc on stdin, which carries no
# argv payload at all — and that bought nothing, because the DATA that program parses was
# exported first. Past the ceiling the exec fails before python3's first line runs:
#
#     scripts/ai-dlc/report-propagation-fanout.sh: line 262: /opt/homebrew/bin/python3:
#         Argument list too long
#
# exit 126, which is not one of the {0,2,3} the subject's own header declares. Filed twice
# by the reference consumer against this one script, from two different sprint steps —
# `PC-S303-FANOUT-SCRIPT-ARGV-OVERFLOW-ON-LARGE-DIFF` (2026-08-15) and
# `PC-S303-FANOUT-SCRIPT-ARG-MAX-VIA-EXPORTED-DIFF-ENV-VAR` (2026-08-18) — on a real
# 274-file, +64,540-line range. The step that mandates running this script after every
# repair could not discharge its mandate at all: not an empty worklist, but no execution.
#
# WHY THE SIZE ARM EXISTS BESIDE THE SIGNATURE ARM, AND WHY IT STANDS DOWN.
#
# Both filings name the diff. THE CORPUS IS THE FIXED COST AND THE DIFF ONLY TIPS IT OVER:
# on the reference consumer `git ls-files` alone is 607945 bytes across 10146 paths against
# an ARG_MAX of 1048576, so 58% of the ceiling is spent before a byte of diff exists. The
# first filing's own prescribed remedy — "pass the diff via a temp file instead of an
# exported env var" — was built as a mutant and scored: it leaves that 58% in place. A
# remedy taken at face value would have closed the filing and not the defect.
#
# So assertion 2 names each channel that leaked, and assertion 3 asks the question no
# named channel can answer: does the child's environment GROW WITH THE TREE. Three known
# payloads today; assertion 3 is what sees the fourth one somebody exports next year under
# a name nothing here greps for.
#
# THEY OVERLAP, AND ASSERTION 3 STANDS DOWN FOR ASSERTION 2 RATHER THAN FIRING BESIDE IT.
# Putting any of the three payloads back on the environment breaks both, and a mutant that
# fails two arms means one of them is vacuous. Assertion 3 therefore asserts only when all
# three signatures are absent — which makes its subject exactly the UNNAMED channel, the
# one thing assertion 2 structurally cannot see, and gives it a mutant of its own (m4)
# that carries no known signature.
#
# WHY THE UNREADABLE-PAYLOAD ARM IS DRIVEN THROUGH A python3 SHIM THAT RE-EXECS.
#
# Moving a payload off the environment creates a read that can FAIL, and the permissive
# spelling of that read is the dangerous one: an empty diff and an empty corpus are both
# legal inputs that print a clean, plausible zero. A `return ""` on a missing file would
# delete every finding and still exit 0 — the subject's own header calls that shape its
# signature defect. The arm has to drive the SHIPPED python bytes with a broken payload
# path, so the shim re-execs the real python3 with one variable overridden, rather than
# extracting the heredoc into a second implementation whose bugs nobody finds.
set -uo pipefail

# HERMETIC — scrub the operator's tuning before invoking anything (I10). AI_DLC_PROJECT_ROOT
# is set explicitly per invocation below, and a leaked one would pin every run to the same
# tree and make every comparison here vacuous.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

# Both install layouts, derived from install.sh's mapping: core/scripts/<x> lands at
# scripts/ai-dlc/<x> on a consumer. A fixture that only knew the distribution path would
# ship inert to the one tree it is written to defend.
SUBJ=""
for cand in "$ROOT/core/scripts/report-propagation-fanout.sh" \
            "$ROOT/scripts/ai-dlc/report-propagation-fanout.sh"; do
  [ -f "$cand" ] && { SUBJ="$cand"; break; }
done
[ -n "$SUBJ" ] || {
  echo "FIXTURE ERROR: report-propagation-fanout.sh not found in either layout" >&2
  echo "  looked in: $ROOT/core/scripts (distribution), $ROOT/scripts/ai-dlc (consumer)" >&2
  exit 2
}
# Printed because a mutant applied to a copy the run never loads leaves every arm green,
# and that reads exactly like an arm that cannot fire.
echo "  subject resolved: $SUBJ"

command -v python3 >/dev/null 2>&1 || {
  echo "FIXTURE ERROR: python3 not on PATH; the subject's scanner is a python3 heredoc" >&2
  exit 2
}
REAL_PY="$(command -v python3)" || { echo "FIXTURE ERROR: python3 not on PATH" >&2; exit 2; }
REAL_GIT="$(command -v git)"    || { echo "FIXTURE ERROR: git not on PATH" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/fanout-payload.XXXXXX")" \
  || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()     { printf '  ok    %s\n' "$1"; }
bad()    { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
broken() { printf '  FIXTURE BROKEN  %s\n' "$1" >&2; exit 2; }

# ============================================================================
# THE SIGNATURES
# ============================================================================
# One per payload channel, each a string that can only have arrived in the child's
# environment by way of that channel. They are distinct tokens rather than one shared
# one so a leak NAMES its channel: a status-only arm would say a payload leaked and
# leave which one to the next reader, and the three are fixed by different edits.
SIG_CORPUS='PAYLOAD-CORPUS-SIGNATURE'
SIG_UNTRACKED='PAYLOAD-UNTRACKED-SIGNATURE'
# The diff signature is a hunk header, which is structural: it is what a unified diff is
# made of, so no rename of the subject's variables can hide it.
SIG_DIFF='^@@ '

# ============================================================================
# THE TREES
# ============================================================================
# A consumer mid-sprint, in two sizes. They differ ONLY in how many tracked corpus files
# they carry — same diff, same untracked set — so the size arm is reading corpus growth
# and nothing else.
#
# `docs/architecture.md` is the SHIFT TARGET: tracked, then given a two-line insertion in
# the WORKING TREE, which is the uncommitted state a remediator is actually in.
mktree() { # mktree <dir> <extra-corpus-files>
  local d="$1" extra="$2" i=1
  mkdir -p "$d/docs" "$d/_bmad-output/planning-artifacts/s306" || return 2
  ( cd "$d" && "$REAL_GIT" init -q . ) || return 2
  printf 'sprint: 306\n' > "$d/_bmad-output/planning-artifacts/sprint-status.yaml" || return 2
  while [ "$i" -le 20 ]; do printf 'line %d\n' "$i" >> "$d/docs/architecture.md"; i=$((i+1)); done
  # Backticks are written via printf \140: a citation is backtick-delimited by the
  # subject's own grammar, and a literal backtick inside a double-quoted string here
  # would be command substitution against a hole.
  printf 'cites \140docs/architecture.md:15\140 from a tracked file\n' \
    > "$d/docs/${SIG_CORPUS}.md" || return 2
  # The size ballast. Long path names, because the corpus payload is a list of PATHS and
  # its size is what this fixture is about. They carry no citation, so they change the
  # corpus COUNT and never the worklist.
  i=1
  while [ "$i" -le "$extra" ]; do
    printf 'ballast\n' \
      > "$d/docs/ballast-file-with-a-deliberately-long-name-$(printf '%04d' "$i").md" || return 2
    i=$((i+1))
  done
  ( cd "$d" && "$REAL_GIT" -c user.email=f@f -c user.name=fixture add -A \
      && "$REAL_GIT" -c user.email=f@f -c user.name=fixture commit -q -m base ) || return 2
  # The working-tree insertion. Two lines added at the top, so the first shifted OLD line
  # is 1 and every citation in the file is at or below it.
  { printf 'INSERTED\nINSERTED\n'; cat "$d/docs/architecture.md"; } > "$d/.tmp" || return 2
  mv -f "$d/.tmp" "$d/docs/architecture.md" || return 2
  # Untracked, not ignored, under the current sprint: the third payload channel's subject.
  printf 'cites \140docs/architecture.md:16\140 from an UNTRACKED sprint artifact\n' \
    > "$d/_bmad-output/planning-artifacts/s306/${SIG_UNTRACKED}.md" || return 2
  return 0
}

SMALL="$WORK/small"; LARGE="$WORK/large"
mktree "$SMALL" 0    || broken "could not build the small tree"
mktree "$LARGE" 800  || broken "could not build the large tree"
SBASE="$( cd "$SMALL" && "$REAL_GIT" rev-parse HEAD )" || broken "no base rev in the small tree"
LBASE="$( cd "$LARGE" && "$REAL_GIT" rev-parse HEAD )" || broken "no base rev in the large tree"

# THE SEED MUST BE ABLE TO EXPRESS THE DEFECT, and the two sides of the size arm must
# actually differ. A differential whose sides are the same tree returns a perfect null
# that reads exactly like a pass.
s_files=$( cd "$SMALL" && "$REAL_GIT" ls-files | wc -c | tr -d ' ' )
l_files=$( cd "$LARGE" && "$REAL_GIT" ls-files | wc -c | tr -d ' ' )
[ "$(( l_files - s_files ))" -ge 40000 ] \
  || broken "the two trees' file lists differ by only $(( l_files - s_files )) bytes; the size arm cannot resolve a payload that small"
[ -f "$SMALL/_bmad-output/planning-artifacts/s306/${SIG_UNTRACKED}.md" ] \
  || broken "the untracked signature file is missing from the small tree"
u_listed=$( cd "$SMALL" && "$REAL_GIT" ls-files --others --exclude-standard \
              | grep -c "${SIG_UNTRACKED}" )
[ "$u_listed" = 1 ] \
  || broken "the untracked signature file is not in git's untracked-not-ignored set ($u_listed); the untracked channel cannot leak and its arm would pass vacuously"

# ============================================================================
# THE HARNESS
# ============================================================================
# `run <subject> <tree> <base>` -> the subject's output with a trailing `rc=<n>` line. The
# rc is appended INSIDE the substitution because zsh has no PIPESTATUS and a caller
# reading $? after a pipe would read the wrong program's status.
run() {
  local subj="$1" tree="$2" base="$3" out rc
  out="$( AI_DLC_PROJECT_ROOT="$tree" bash "$subj" "$base" 2>&1 )"; rc=$?
  printf '%s\nrc=%d\n' "$out" "$rc"
}

# `capture <subject> <tree> <base> <envfile>` -> runs the subject with a python3 that
# records the environment it was EXEC'D WITH and consumes the program on stdin. This is
# the child's own inherited environment block, which is the thing `execve` measures.
capture() {
  local subj="$1" tree="$2" base="$3" dest="$4" shimdir
  shimdir="$(mktemp -d "$WORK/shim.XXXXXX")" || return 2
  printf '#!/bin/sh\ncat >/dev/null\nenv > "%s"\n' "$dest" > "$shimdir/python3" || return 2
  chmod +x "$shimdir/python3" || return 2
  ( cd "$tree" && PATH="$shimdir:$PATH" AI_DLC_PROJECT_ROOT="$tree" \
      bash "$subj" "$base" ) >/dev/null 2>&1
  [ -s "$dest" ]
}

has()  { grep -qF -- "$2" <<<"$1"; }
# Every predicate reads a captured string with a here-string, never a pipe: `grep -q`
# leaves at its first match, and under pipefail a pipeline then answers with the writer's
# EPIPE and reports NOT-FOUND on input that contains the pattern.
rows() { grep -cE '^  [^ ].*  ->  ' <<<"$1"; }

echo "  --- assertions ---"

# ----------------------------------------------------------------------------
# 1. THE BASELINE. Presence-shaped, and it is what stops a subject that emits nothing
#    from scoring green on the absence arms below.
# ----------------------------------------------------------------------------
S_OUT="$(run "$SUBJ" "$SMALL" "$SBASE")"
s_rc="$(sed -n 's/^rc=//p' <<<"$S_OUT")"
s_rows="$(rows "$S_OUT")"
if [ "$s_rc" = 0 ] && [ "$s_rows" -ge 1 ]; then
  ok "1. the subject resolves its scope and emits a worklist (rc=0, $s_rows rows)"
else
  bad "1. the subject did not produce a usable baseline: rc=$s_rc rows=$s_rows — every arm below is about a run that did not happen"
  printf '%s\n' "$S_OUT" | sed 's/^/        /' >&2
fi
# The move must not change the ANSWER. A payload that arrives by a different road and is
# then parsed differently is a second corpus wearing the first one's name.
if has "$S_OUT" "${SIG_UNTRACKED}.md"; then
  ok "1b. the worklist still names the untracked sprint artifact, so the corpus survived the move intact"
else
  bad "1b. the worklist no longer names ${SIG_UNTRACKED}.md — the payload reached python3 in a different shape than it left the shell"
fi

# ----------------------------------------------------------------------------
# 2. NO PAYLOAD SIGNATURE IN THE CHILD'S ENVIRONMENT, named per channel.
# ----------------------------------------------------------------------------
S_ENV="$WORK/small.env"
capture "$SUBJ" "$SMALL" "$SBASE" "$S_ENV" \
  || broken "the python3 shim never ran, so nothing was captured; the exec did not reach it"
# Reach control, positive and in the same invocation: an env dump that is merely non-empty
# proves the file was created, not that a real environment block was recorded.
grep -q '^PATH=' "$S_ENV" \
  || broken "the captured environment carries no PATH=; it is not a process environment and every absence read from it is meaningless"

leaked=""
grep -qF "$SIG_CORPUS"    "$S_ENV" && leaked="$leaked corpus"
grep -qF "$SIG_UNTRACKED" "$S_ENV" && leaked="$leaked untracked"
grep -qE "$SIG_DIFF"      "$S_ENV" && leaked="$leaked diff"
if [ -z "$leaked" ]; then
  ok "2. none of the three payloads (corpus, untracked, diff) is in the child's environment"
else
  bad "2. payload channel(s) still on the environment:$leaked — that is argv+envp budget, and past ARG_MAX the exec fails with 126 before python3 runs"
fi

# ----------------------------------------------------------------------------
# 3. THE ENVIRONMENT DOES NOT GROW WITH THE TREE — the arm for the channel nobody
#    named. It STANDS DOWN when assertion 2 has already fired, because a payload that
#    leaked by a known channel would fail both and one of two failures is vacuous.
# ----------------------------------------------------------------------------
L_ENV="$WORK/large.env"
capture "$SUBJ" "$LARGE" "$LBASE" "$L_ENV" \
  || broken "the python3 shim never ran against the large tree"
s_env_sz=$(wc -c < "$S_ENV" | tr -d ' ')
l_env_sz=$(wc -c < "$L_ENV" | tr -d ' ')
growth=$(( l_env_sz - s_env_sz ))
# 4096 is a ceiling on incidental variation (temp-directory names, a longer PWD), chosen
# against a measured separation of two orders of magnitude: the ballast adds ~48000 bytes
# of path text, and the seed guard above refuses to run this arm below 40000.
if [ -n "$leaked" ]; then
  ok "3. SKIPPED — assertion 2 already named the leak;$leaked would fail this arm too and a second failure would report one defect twice"
elif [ "$growth" -lt 4096 ]; then
  ok "3. a 20x larger tree grows the child environment by $growth bytes (small $s_env_sz, large $l_env_sz), so no payload scales with the corpus"
else
  bad "3. the child environment grew $growth bytes across the two trees (small $s_env_sz, large $l_env_sz) — something tree-sized is still exported under a name no signature above greps for"
fi

# ----------------------------------------------------------------------------
# 4. AN UNREADABLE PAYLOAD IS A SCOPING FAILURE, NEVER AN EMPTY WORKLIST.
# ----------------------------------------------------------------------------
# The shim re-execs the REAL python3 so the program under test is the subject's shipped
# heredoc, not a restatement of it. `$OVERRIDE` is applied by the shim so the subject's own
# export is what gets overridden, at the only moment it can be.
mkshim() { # mkshim <dir> <env-assignment-or-empty>
  local d="$1" assign="$2"
  mkdir -p "$d" || return 2
  { printf '#!/bin/sh\n'
    [ -n "$assign" ] && printf 'export %s\n' "$assign"
    printf 'exec "%s" "$@"\n' "$REAL_PY"
  } > "$d/python3" || return 2
  chmod +x "$d/python3"
}
runshim() { # runshim <shimdir> <tree> <base>
  local out rc
  out="$( cd "$2" && PATH="$1:$PATH" AI_DLC_PROJECT_ROOT="$2" bash "$SUBJ" "$3" 2>&1 )"; rc=$?
  printf '%s\nrc=%d\n' "$out" "$rc"
}
mkshim "$WORK/passthru" ""                                          || broken "could not build the pass-through shim"
mkshim "$WORK/broken"   "FANOUT_DIFF_FILE=$WORK/does-not-exist"     || broken "could not build the broken-payload shim"

P_OUT="$(runshim "$WORK/passthru" "$SMALL" "$SBASE")"
p_rc="$(sed -n 's/^rc=//p' <<<"$P_OUT")"
# The control for arm 4, and it is the one that makes the arm readable: a shim that broke
# the run by EXISTING would produce the same non-zero as a shim that broke the payload.
if [ "$p_rc" = 0 ] && [ "$(rows "$P_OUT")" -ge 1 ]; then
  ok "4a. control: re-exec'ing the real python3 through a shim changes nothing (rc=0, worklist intact)"
else
  broken "the pass-through shim itself broke the run (rc=$p_rc); arm 4b cannot distinguish a broken payload from a broken shim"
fi

B_OUT="$(runshim "$WORK/broken" "$SMALL" "$SBASE")"
b_rc="$(sed -n 's/^rc=//p' <<<"$B_OUT")"
b_rows="$(rows "$B_OUT")"
if [ "$b_rc" = 3 ] && has "$B_OUT" "SCOPING FAILURE"; then
  ok "4b. an unreadable payload exits 3 and says SCOPING FAILURE"
else
  bad "4b. an unreadable payload gave rc=$b_rc with $b_rows worklist rows — a permissive read here turns a broken payload into a clean empty worklist, which is this subject's own signature defect"
fi
if [ "$b_rows" = 0 ]; then
  ok "4c. and it emits no worklist rows, so nothing downstream can read the failure as a clean result"
else
  bad "4c. an unreadable payload still emitted $b_rows worklist rows — the run reported findings over a payload it could not read"
fi

# ----------------------------------------------------------------------------
# 5. THE PAYLOAD DIRECTORY IS REMOVED. Moving data to files creates litter, and a
#    caller run per repair in a gate loop creates it repeatedly.
# ----------------------------------------------------------------------------
before=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'fanout.*' -type d 2>/dev/null | wc -l | tr -d ' ')
run "$SUBJ" "$SMALL" "$SBASE" >/dev/null 2>&1
after=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'fanout.*' -type d 2>/dev/null | wc -l | tr -d ' ')
if [ "$after" -le "$before" ]; then
  ok "5. the payload directory does not survive the run (fanout.* dirs before $before, after $after)"
else
  bad "5. the run left $(( after - before )) fanout.* directories behind — the cleanup trap is gone and every gate-loop invocation leaks a copy of the corpus"
fi

# ============================================================================
# MUTANTS
# ============================================================================
# Every arm above except 1 and 4 is ABSENCE-shaped, which is exactly the shape that passes
# for a program that never ran. Each mutant is a COPY with one edit; `cmp -s` guards
# against a `sed` that matched nothing and scored a kill it never earned.
echo "  --- mutants ---"
kills=0

# `mutate <name> <sed-args...>` — builds the copy and sets $MUT to its path. It reports
# through the GLOBAL `fails` rather than through a command substitution: a `bad` call
# inside `$( )` writes its finding to the caller's variable instead of the log, and its
# increment of `fails` dies with the subshell — a battery that could not report.
MUT=""
mutate() {
  local name="$1"; shift
  local out="$WORK/m-$name.sh"
  MUT=""
  sed "$@" "$SUBJ" > "$out" || return 1
  if cmp -s "$SUBJ" "$out"; then
    bad "MUTANT [$name] IS A NO-OP: the edit matched nothing, so any kill below is unearned and any pass is meaningless"
    return 1
  fi
  bash -n "$out" 2>/dev/null || {
    bad "MUTANT [$name] does not parse — a kill would be a syntax error rather than a disarmed guard"
    return 1
  }
  MUT="$out"
}

# `expect_leak <name> <mutant> <channel-word>` — the mutant must put a payload back on the
# environment, AND must still produce the baseline worklist, so "no output" cannot score.
expect_leak() {
  # Declared on separate lines on purpose: `local a=$1 b=$WORK/$a` expands every word
  # BEFORE any assignment lands, so the second one reads an unset `a` and `set -u` kills
  # the run inside the function.
  local name="$1" m="$2" want="$3"
  local e="$WORK/m-$name.env" out
  out="$(run "$m" "$SMALL" "$SBASE")"
  if [ "$(sed -n 's/^rc=//p' <<<"$out")" != 0 ] || [ "$(rows "$out")" -lt 1 ]; then
    bad "MUTANT HARNESS BROKEN [$name]: the copy no longer produces a worklist, so it is not running and the kill below is unreadable"
    return
  fi
  capture "$m" "$SMALL" "$SBASE" "$e" || {
    bad "MUTANT HARNESS BROKEN [$name]: the shim captured nothing from the copy"; return; }
  if grep -qE -- "$want" "$e"; then
    ok "  mutant [$name] KILLED by assertion 2: the $name payload is back on the environment"
    kills=$((kills+1))
  else
    bad "MUTANT SURVIVED [$name]: assertion 2 did not see the payload it re-exported, so it does not depend on the code it claims to guard"
  fi
}

# m1 — THE FIRST FILING'S OWN PRESCRIBED REMEDY, INVERTED: the diff back on the
# environment. Assertion 2 must name the diff channel by itself.
if mutate m1-diff \
    -e 's|^export FANOUT_DIFF_FILE=|export FANOUT_DIFF="$DIFF" FANOUT_DIFF_FILE=|'; then
  expect_leak m1-diff "$MUT" "$SIG_DIFF"
fi

# m2 — the corpus back on the environment. This is the 58% the filed remedy would have
# left in place, and it is the reason assertion 2 names three channels and not one.
if mutate m2-corpus \
    -e 's|^export FANOUT_DIFF_FILE=|export FANOUT_FILES="$CORPUS_FILES" FANOUT_DIFF_FILE=|'; then
  expect_leak m2-corpus "$MUT" "$SIG_CORPUS"
fi

# m3 — the untracked half back on the environment. It is a separate variable from the
# corpus and a fix that moves two of three reads exactly like one that moved all three.
if mutate m3-untracked \
    -e 's|^export FANOUT_DIFF_FILE=|export FANOUT_UNTRACKED="$CORPUS_UNTRACKED" FANOUT_DIFF_FILE=|'; then
  expect_leak m3-untracked "$MUT" "$SIG_UNTRACKED"
fi

# m4 — THE ARM-3 MUTANT, and the reason arm 3 is not redundant with arm 2. A tree-sized
# payload under a name nothing above greps for, whose CONTENT carries none of the three
# signatures: commit shas, one per tracked file. Assertion 2 is structurally blind to it.
if mutate m4-unnamed \
    -e 's|^export FANOUT_DIFF_FILE=|FANOUT_PAD="$(git ls-files \| sed "s/.*/0123456789abcdef0123456789abcdef01234567/")"\nexport FANOUT_PAD FANOUT_DIFF_FILE=|'; then
  m="$MUT"
  m4e="$WORK/m4-small.env"; m4l="$WORK/m4-large.env"
  if capture "$m" "$SMALL" "$SBASE" "$m4e" && capture "$m" "$LARGE" "$LBASE" "$m4l"; then
    m4_leak=""
    grep -qF "$SIG_CORPUS" "$m4e" && m4_leak=1
    grep -qF "$SIG_UNTRACKED" "$m4e" && m4_leak=1
    grep -qE "$SIG_DIFF" "$m4e" && m4_leak=1
    m4g=$(( $(wc -c < "$m4l" | tr -d ' ') - $(wc -c < "$m4e" | tr -d ' ') ))
    if [ -n "$m4_leak" ]; then
      bad "MUTANT [m4-unnamed] IS ENTANGLED: its padding carries one of assertion 2's signatures, so it cannot show that assertion 3 fires on its own"
    elif [ "$m4g" -ge 4096 ]; then
      ok "  mutant [m4-unnamed] KILLED by assertion 3 alone: +$m4g bytes with every named signature still absent"
      kills=$((kills+1))
    else
      bad "MUTANT SURVIVED [m4-unnamed]: an unnamed tree-sized export grew the environment by only $m4g bytes, so assertion 3 cannot resolve the channel it exists for"
    fi
  else
    bad "MUTANT HARNESS BROKEN [m4-unnamed]: the shim captured nothing"
  fi
fi

# m5 — THE PERMISSIVE READ. This is the spelling that turns a broken payload into a clean
# empty worklist, and only arm 4 can see it: every other arm is about where the data
# travelled, not about what happens when it is not there.
if mutate m5-permissive \
    -e 's|^    except OSError as exc:|    except OSError:\n        return ""\n    except RuntimeError as exc:|'; then
  m="$MUT"
  mk="$WORK/m5shim"
  mkshim "$mk" "FANOUT_DIFF_FILE=$WORK/does-not-exist"
  mout="$( cd "$SMALL" && PATH="$mk:$PATH" AI_DLC_PROJECT_ROOT="$SMALL" bash "$m" "$SBASE" 2>&1 )"
  mrc=$?
  # Positive conjunct: the copy must still work on a GOOD payload, or the kill is silence.
  gout="$(run "$m" "$SMALL" "$SBASE")"
  if [ "$(sed -n 's/^rc=//p' <<<"$gout")" != 0 ] || [ "$(rows "$gout")" -lt 1 ]; then
    bad "MUTANT HARNESS BROKEN [m5-permissive]: the copy fails on a good payload too, so arm 4b would fire for the wrong reason"
  elif [ "$mrc" != 3 ]; then
    ok "  mutant [m5-permissive] KILLED by assertion 4b: a missing payload now exits $mrc instead of 3"
    kills=$((kills+1))
  else
    bad "MUTANT SURVIVED [m5-permissive]: a permissive read still exited 3, so assertion 4b is not reading the payload guard"
  fi
fi

# m6 — the cleanup trap removed. Arm 5 owns this and nothing else can see it.
if mutate m6-trap -e 's|^trap .rm -rf "\$FANOUT_TMP". EXIT|: # trap removed|'; then
  m="$MUT"
  b=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'fanout.*' -type d 2>/dev/null | wc -l | tr -d ' ')
  gout="$(run "$m" "$SMALL" "$SBASE")"
  a=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'fanout.*' -type d 2>/dev/null | wc -l | tr -d ' ')
  if [ "$(sed -n 's/^rc=//p' <<<"$gout")" != 0 ] || [ "$(rows "$gout")" -lt 1 ]; then
    bad "MUTANT HARNESS BROKEN [m6-trap]: the copy no longer produces a worklist"
  elif [ "$a" -gt "$b" ]; then
    ok "  mutant [m6-trap] KILLED by assertion 5: the copy left $(( a - b )) payload directories behind"
    kills=$((kills+1))
    find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'fanout.*' -type d -exec rm -rf {} + 2>/dev/null
  else
    bad "MUTANT SURVIVED [m6-trap]: removing the cleanup trap left nothing behind, so assertion 5 is watching a directory the subject does not create"
  fi
fi

# The battery's own floor. A run where every mutant silently failed to apply reports the
# same six `ok` lines as a run where the arms are inert.
if [ "$kills" -ge 6 ]; then
  ok "mutant battery: $kills of 6 killed"
else
  bad "mutant battery: only $kills of 6 killed — the arms above cannot be read as evidence"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "PASS  fanout-payload-channel"
  exit 0
fi
echo "FAIL  fanout-payload-channel ($fails)"
exit 1
