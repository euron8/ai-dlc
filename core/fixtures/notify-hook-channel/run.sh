#!/usr/bin/env bash
# notify-hook-channel/run.sh — prove ai-dlc-notify.sh raises the right channel on each
# platform, passes the payload as an ARGUMENT rather than as script text, and says so out loud
# where it has no channel at all.
#
# THE TWO DEFECT CLASSES THIS IS AIMED AT.
#
# 1. INJECTION. The notification body is untrusted text the harness composes. Interpolated
#    into the AppleScript source, a body containing a quote breaks the script and a body
#    containing `do shell script` runs. Assertion 3 is the load-bearing one: it asserts BOTH
#    that the payload reached `argv` byte-exact AND that it is absent from the script text.
#    Either half alone can be satisfied by a broken implementation.
#
# 2. A BRANCH THAT CANNOT FIRE ON THE MACHINE RUNNING THE SUITE. The hook has a Linux branch
#    and a no-channel branch; this repo runs its suite on macOS, so both would ship untested
#    and an operator on Linux would be the first to run them. The seam is $PATH — shimmed
#    `uname`, `osascript` and `notify-send` — so every branch is driven by the SHIPPING code
#    on whatever platform the suite happens to run on.
#
# The shims RECORD instead of notifying. A fixture that popped a real desktop notification on
# every push gets turned off, and `osascript` does not exist on a Linux runner.
set -uo pipefail

# The pre-push gate inherits every AI_DLC_* tunable a consumer set in settings.json. A fixture
# that drives a hook while inheriting them tests the CONFIG, not the code (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
skips=0
ok()   { printf '  ok    %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
skip() { printf '  skip  %s\n' "$1"; skips=$((skips+1)); }

# The realistic hostile body: it closes the AppleScript string, appends a `do shell script`,
# and reopens it. Interpolated into the source this executes; passed as an argument it is a
# sentence. It also carries a backslash and a `$(...)`, the two things a shell would eat.
INJECT='he said "stop" \ " & (do shell script "touch '"$WORK"'/PWNED") & " $(id) ended'
BENIGN='an ordinary message with no metacharacters at all'

# Drive the hook exactly as the harness does: JSON on stdin, CLAUDE_PROJECT_DIR set, and the
# shimmed binaries first on PATH.
fire() { # <script> <platform> <payload-json>
  printf '%s\n' "$2" > "$PLATFORM_FILE"
  rm -f "$REC"/osascript.argv "$REC"/osascript.stdin "$REC"/notify-send.argv "$REC"/stderr
  printf '%s' "$3" \
    | PATH="$SHIMBIN:$PATH" CLAUDE_PROJECT_DIR="$PROJECT" bash "$1" 2>"$REC/stderr"
}

probe() { # <script> <platform>
  printf '%s\n' "$2" > "$PLATFORM_FILE"
  PATH="$SHIMBIN:$PATH" bash "$1" --probe 2>/dev/null
}

# ---------------------------------------------------------------------------------------
# The arms, as functions returning 0 when the property HOLDS. Each mutant below re-runs the
# arms it claims to move and asserts they now FAIL, so no arm is asserted only once.
# ---------------------------------------------------------------------------------------

# osascript's own argv[1] is the `-` that tells it to read the script from stdin, so the
# message is argv[2] and the project name argv[3]. Asserting the `-` too is what keeps this
# from silently passing if the invocation form ever changes shape.
arm_darwin_argv() {
  fire "$1" Darwin '{"message":"needs your input","cwd":"'"$PROJECT"'"}'
  [ -s "$REC/osascript.argv" ] || return 1
  [ "$(sed -n 1p "$REC/osascript.argv")" = "-" ] && [ "$(sed -n 2p "$REC/osascript.argv")" = "needs your input" ] || return 1
  [ "$(sed -n 3p "$REC/osascript.argv")" = "project" ] || return 1
  return 0
}

arm_injection_argv() { # a hostile body arrives byte-exact as an ARGUMENT
  fire "$1" Darwin "$(printf '{"message":%s,"cwd":"%s"}' "$(json_str "$INJECT")" "$PROJECT")"
  [ -s "$REC/osascript.argv" ] || return 1
  [ "$(sed -n 2p "$REC/osascript.argv")" = "$INJECT" ] || return 1
  return 0
}

arm_injection_not_in_script() { # ...and is ABSENT from the AppleScript text, which does not
                                # vary with the payload at all
  fire "$1" Darwin "$(printf '{"message":%s,"cwd":"%s"}' "$(json_str "$INJECT")" "$PROJECT")"
  [ -s "$REC/osascript.stdin" ] || return 1
  cp "$REC/osascript.stdin" "$WORK/script-hostile.txt"
  grep -qF 'do shell script' "$WORK/script-hostile.txt" && return 1
  grep -qF "$INJECT" "$WORK/script-hostile.txt" && return 1

  # The stronger form of the same claim, and the one a partial escape cannot satisfy: the
  # script text is IDENTICAL for two different payloads, so no part of the body is derived
  # from the message. A implementation that escaped only quotes would pass the greps above
  # and fail here.
  fire "$1" Darwin "$(printf '{"message":%s,"cwd":"%s"}' "$(json_str "$BENIGN")" "$PROJECT")"
  [ -s "$REC/osascript.stdin" ] || return 1
  cmp -s "$WORK/script-hostile.txt" "$REC/osascript.stdin" || return 1
  return 0
}

arm_default_message() { # a payload with no .message still notifies, with the default text
  fire "$1" Darwin '{"cwd":"'"$PROJECT"'"}'
  [ -s "$REC/osascript.argv" ] || return 1
  [ "$(sed -n 2p "$REC/osascript.argv")" = "Claude Code needs your input" ] || return 1
  return 0
}

arm_linux() { # Linux takes notify-send, and does NOT take osascript
  fire "$1" Linux '{"message":"needs your input","cwd":"'"$PROJECT"'"}'
  [ -s "$REC/notify-send.argv" ] || return 1
  [ -s "$REC/osascript.argv" ] && return 1
  grep -qxF 'needs your input' "$REC/notify-send.argv" || return 1
  grep -qF 'project' "$REC/notify-send.argv" || return 1
  return 0
}

arm_no_channel() { # an unsupported platform raises nothing, exits 0, and SAYS so
  fire "$1" FreeBSD '{"message":"needs your input","cwd":"'"$PROJECT"'"}'
  rc=$?
  [ "$rc" -eq 0 ] || return 1
  [ -s "$REC/osascript.argv" ] && return 1
  [ -s "$REC/notify-send.argv" ] && return 1
  grep -qF 'FreeBSD' "$REC/stderr" || return 1
  return 0
}

arm_probe() { # --probe reports the channel the notification path would take
  [ "$(probe "$1" Darwin  | sed -n 's/^channel=//p')" = "osascript" ] || return 1
  [ "$(probe "$1" Darwin  | sed -n 's/^platform=//p')" = "Darwin" ]   || return 1
  [ "$(probe "$1" FreeBSD | sed -n 's/^channel=//p')" = "none" ]      || return 1
  return 0
}

# jq is how the hook reads its payload, so the fixture uses it to BUILD one — a hand-escaped
# JSON string containing quotes and backslashes is how this fixture would silently start
# testing a different payload than it prints.
json_str() { printf '%s' "$1" | jq -Rs .; }

echo "notify-hook-channel:"

# --- Assertion 0: SANITY — the shims record ---------------------------------------------
# Every assertion below reads "did the hook invoke this binary" off a recording. If the
# recording mechanism did not work, "not recorded" would be indistinguishable from "not
# invoked" and the whole fixture would pass by finding nothing.
command -v jq >/dev/null 2>&1 || { echo "  FIXTURE BROKEN — jq absent; payloads cannot be built" >&2; echo "notify-hook-channel: FIXTURE BROKEN" >&2; exit 2; }
rm -f "$REC"/osascript.argv
PATH="$SHIMBIN:$PATH" osascript SANITY-ARG </dev/null >/dev/null 2>&1
if [ -s "$REC/osascript.argv" ] && grep -qxF 'SANITY-ARG' "$REC/osascript.argv"; then
  ok "seed: the osascript shim is on PATH and records its argv"
  rm -f "$REC"/osascript.argv "$REC"/osascript.stdin
else
  echo "  FIXTURE BROKEN — the osascript shim did not record; every 'not invoked' below would be vacuous" >&2
  echo "notify-hook-channel: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertions 1-7: the shipping hook ---------------------------------------------------
arm_darwin_argv "$HOOK" \
  && ok "macOS: the message reaches osascript argv[2] and the project name argv[3]" \
  || bad "macOS: osascript was not invoked with the message and project as arguments"

arm_injection_argv "$HOOK" \
  && ok "injection: a body with quotes, a backslash and \$(...) arrives byte-exact as an argument" \
  || bad "injection: the hostile body did not reach argv unchanged — it is being mangled or dropped"

arm_injection_not_in_script "$HOOK" \
  && ok "injection: that same body is ABSENT from the AppleScript text, and nothing executed" \
  || bad "INJECTION LIVE — the payload is interpolated into the AppleScript source. A body containing \`do shell script\` would run."

arm_default_message "$HOOK" \
  && ok "no .message in the payload: the default text is notified rather than an empty body" \
  || bad "a payload without .message produced no notification or an empty one"

arm_linux "$HOOK" \
  && ok "Linux: notify-send is invoked with the message, and osascript is not" \
  || bad "Linux: the notify-send branch did not fire — a Linux consumer gets nothing"

arm_no_channel "$HOOK" \
  && ok "unsupported platform: nothing raised, exit 0, and the platform is NAMED on stderr" \
  || bad "unsupported platform: the hook either raised something, failed, or went silent"

arm_probe "$HOOK" \
  && ok "--probe reports the same channel the notification path takes, per platform" \
  || bad "--probe disagrees with the notification path, or does not report a platform"

# --- Assertion 8: install.sh REPORTS the probe -------------------------------------------
# The no-channel case is invisible at runtime — its stderr is not somewhere an operator
# looks. install.sh's report is the mechanism that makes it visible, so the mechanism is
# bound rather than trusted. DISTRIBUTION-ONLY: scripts/install.sh does not ship, so on a
# consumer this declares itself SKIPPED instead of passing quietly.
if [ -n "${INSTALL_SH:-}" ] && [ -f "$INSTALL_SH" ]; then
  if grep -q 'ai-dlc-notify\.sh' "$INSTALL_SH" && grep -q '\-\-probe' "$INSTALL_SH"; then
    ok "install.sh probes the notifier and reports the resolved channel at install time"
  else
    bad "install.sh no longer probes ai-dlc-notify.sh --probe. An operator on a platform with no channel now has nowhere to find that out."
  fi
else
  skip "install.sh join (consumer layout: scripts/install.sh is distribution-only and absent here)"
fi

# --- Assertions 9-13: MUTANTS ------------------------------------------------------------
# Copies, never in-place edits, each guarded with `cmp -s` so a sed that matched nothing
# cannot pass as a mutation. Each declares its EXACT moved-set and no two share one; the
# unmutated CONTROL is what proves a copy runs at all, so "the mutant produced no output"
# cannot score as a kill.
MUTDIR="$WORK/mutants"; mkdir -p "$MUTDIR"

CONTROL="$MUTDIR/control.sh"
cp "$HOOK" "$CONTROL"
if arm_darwin_argv "$CONTROL" && arm_no_channel "$CONTROL"; then
  ok "control: an UNMUTATED copy behaves identically, so a mutant's failure is the mutation"
else
  bad "CONTROL COPY FAILED — a plain copy of the hook does not work from \$WORK, so every mutant below fails for the wrong reason"
fi

mutate() { # <name> <sed-args...> ; echoes the mutant path, or nothing on a failed mutation
  local name="$1"; shift
  local out="$MUTDIR/$name.sh"
  sed "$@" "$HOOK" > "$out" 2>/dev/null
  if cmp -s "$HOOK" "$out"; then rm -f "$out"; return 1; fi
  printf '%s\n' "$out"
}

# M1 — interpolate the message into the script text instead of passing it as an argument.
# Moved-set: assertion 3 ONLY (argv still carries the message, so assertion 2 still holds).
if M="$(mutate interpolate -e "s/<<'APPLESCRIPT'/<<APPLESCRIPT/" -e 's/(item 1 of argv)/"$MSG"/')"; then
  if ! arm_injection_not_in_script "$M" && arm_injection_argv "$M"; then
    ok "mutant interpolate: the payload appears in the AppleScript text and assertion 3 fails — it can fire"
  else
    bad "MUTANT interpolate DID NOT MOVE ASSERTION 3 ALONE — assertion 3 is vacuous or entangled with 2"
  fi
else
  bad "FIXTURE STALE: could not build the interpolate mutant — the osascript invocation was reworded"
fi

# M2 — remove the Linux branch. Moved-set: assertion 5 ONLY.
if M="$(mutate linux-disabled -e 's/^    Linux)/    LinuxDISABLED)/')"; then
  if ! arm_linux "$M" && arm_darwin_argv "$M" && arm_no_channel "$M"; then
    ok "mutant linux-disabled: assertion 5 fails and 1 and 6 do not — the Linux arm is real and isolated"
  else
    bad "MUTANT linux-disabled DID NOT MOVE ASSERTION 5 ALONE — the Linux arm proves nothing, or the arms are entangled"
  fi
else
  bad "FIXTURE STALE: could not build the linux-disabled mutant — the Linux case label moved"
fi

# M3 — the no-channel fallback resolves to osascript instead. Moved-set: assertions 6 AND 7.
# Two arms, declared: resolve_channel is deliberately ONE function so the probe and the
# notification path cannot disagree, which means a mutation to it must move both.
if M="$(mutate none-to-osascript -e "s/  printf 'none/  printf 'osascript/")"; then
  if ! arm_no_channel "$M" && ! arm_probe "$M" && arm_darwin_argv "$M" && arm_linux "$M"; then
    ok "mutant none-to-osascript: assertions 6 and 7 both fail, 1 and 5 do not — the declared moved-set"
  else
    bad "MUTANT none-to-osascript MOVED THE WRONG SET — the no-channel arm or the probe arm proves nothing"
  fi
else
  bad "FIXTURE STALE: could not build the none-to-osascript mutant — the fallback printf was reworded"
fi

# M4 — drop the default-message fallback. Moved-set: assertion 4 ONLY.
if M="$(mutate no-default-message -e '/^\[ -n "\$MSG" \] || MSG=/d')"; then
  if ! arm_default_message "$M" && arm_darwin_argv "$M"; then
    ok "mutant no-default-message: assertion 4 fails and 1 does not — the fallback is what assertion 4 tests"
  else
    bad "MUTANT no-default-message DID NOT MOVE ASSERTION 4 ALONE — the default-text arm is vacuous"
  fi
else
  bad "FIXTURE STALE: could not build the no-default-message mutant — the fallback line was reworded"
fi

echo
if [ "$fails" -eq 0 ]; then
  if [ "$skips" -gt 0 ]; then
    echo "notify-hook-channel: PASS WITH $skips SKIP(S)"
  else
    echo "notify-hook-channel: PASS"
  fi
  exit 0
fi
echo "notify-hook-channel: $fails assertion(s) FAILED" >&2
exit 1
