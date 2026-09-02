#!/usr/bin/env bash
# validate-artifact-derivations.sh — re-run the derivations a planning artifact carries
#
# Usage: ./scripts/ai-dlc/validate-artifact-derivations.sh <file-or-dir> [<file-or-dir>...]
#        ./scripts/ai-dlc/validate-artifact-derivations.sh --list <file-or-dir>...
#
# WHAT IT GUARDS, AND WHY IT IS NOT A LINT.
#
# The adversarial convergence loop's dominant cost is not disagreement about design.
# Measured over the reference consumer's four most recent sprints, across the 79 MAJOR
# findings raised at pass 2 and later: 46 (58%) are a count, an enumeration, a wrong
# `file:line` or a quoted snippet — a fact about the tree that one command settles. 78%
# of those 79 were introduced by a PRIOR REPAIR. And of the 46 mechanical ones, 22 had
# the answer already sitting in the package; the dominant sub-shape, 12 of them, is
#
#     derive -> write -> edit -> never re-derive
#
# the command existed, would have caught it, and was simply not re-run after the edit
# that falsified it. Each of those costs a full adversary dispatch to discover and a full
# remediator dispatch to fix — two Opus-`high` agents to recover a number a `grep -c`
# would have produced.
#
# So this is not a style check. It is the loop's dominant finding class, moved from
# "found by an LLM one pass later" to "failed by a script before the pass is dispatched."
#
# THE GRAMMAR. A claim is checkable when the author says it is, in a fenced block whose
# info-string is `derived`:
#
#     ```derived
#     $ grep -c 'save_state_fn' rebalancer/execution.py
#     19
#     ```
#
# One `$ ` command line, then the output it produced, verbatim, up to the next `$ ` line
# or the closing fence. Several command/output pairs may share one block. Commands run
# from the PROJECT ROOT, so paths are written as the artifact writes them.
#
# THIS IS OPT-IN BY GRAMMAR, AND THAT IS NOT AN OPT-OUT — the incentive points the other
# way, which is the only reason it is allowed to be opt-in. An unfenced factual claim is
# still a MAJOR under `team-roles/adversary.md`'s underived-claim rung, and the adjacent
# rung now also requires the reviewing pass to EXECUTE any recipe it reads rather than
# judge it plausible. So not fencing a claim does not avoid the work; it moves the work
# to two Opus agents and a round trip. Fencing it spends one exit code.
#
# WHAT IT CANNOT DO, stated so a pass is not over-read: it proves the recorded output is
# what the recorded command produces at HEAD. It does not prove the command MEASURES the
# claim beside it. A grep that is blind to an alias is a true derivation of the wrong
# thing, and five of the reference consumer's findings were exactly that. That judgment
# stays with the adversary; this removes the ones that are simply stale.
#
# THE ALLOWLIST IS A SAFETY BOUNDARY, NOT A CONVENIENCE. This script executes text out of
# a markdown file. Only read-only commands run, no shell metacharacters that could chain
# or redirect, and anything outside the allowlist FAILS rather than being skipped — a
# skip would let an author move a claim out of reach of the checker by writing it in a
# language the checker does not run.
#
# Exit: 0 all derivations reproduce | 1 a derivation is stale or malformed | 2 usage.
set -uo pipefail

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of
# `..` hops. This script runs from three layouts:
#   <root>/core/scripts/X      distribution
#   <root>/scripts/ai-dlc/X    consumer, v0.126.0+
#   <root>/scripts/X           consumer, pre-v0.126.0
# and no fixed hop count fits all three. v0.126.0 moved the validators one level
# deeper, which silently turned every `dirname $0/..` root into <root>/scripts:
# this script then found no docs/retro/, printed "Scanned 0 retros, 0 gates
# declared, 0 dormant" and exited 0 — a check that could no longer fire, reading
# exactly like one that passed.
# Inline on purpose, in every script that needs it: a shared lib cannot fix this,
# because locating the lib is the same unsolved problem. Duplication is correct
# here. core/fixtures/validator-path-resolution asserts both layouts agree.
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
  echo "ERROR: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------

# The read-only allowlist. A command whose FIRST WORD is not here does not run.
# `git` is admitted only for its read-only subcommands, checked separately below.
ALLOWED_CMDS="grep rg awk sed wc comm sort uniq cut head tail nl find ls cat diff shasum sha256sum basename dirname printf echo test git"
ALLOWED_GIT_SUB="grep log show diff ls-files rev-parse cat-file describe status"

LIST_ONLY=0
case "${1:-}" in
  --list) LIST_ONLY=1; shift ;;
  -h|--help|"") echo "usage: $0 [--list] <file-or-dir>..." >&2; exit 2 ;;
esac
[ "$#" -ge 1 ] || { echo "usage: $0 [--list] <file-or-dir>..." >&2; exit 2; }

fails=0; checked=0; blocks=0; files_seen=0

fail() { printf 'FAIL (%s): %s\n' "$1" "$2" >&2; fails=$((fails + 1)); }

# A command is refused if it can chain, redirect, substitute or background. Pipes are
# permitted because a count is routinely `grep ... | wc -l`, and every element of the
# pipe is checked against the allowlist independently.
cmd_is_safe() { # $1 command -> 0 safe, 1 refused (reason in REFUSED)
  local c="$1" seg first sub segs scan_rc=0
  REFUSED=""
  case "$c" in
    *';'*|*'&'*|*'>'*|*'<'*|*'`'*|*'$('*|*'${'*|*'||'*)
      REFUSED="it can chain, redirect or substitute (one of ; & > < \` \$( \${ ||)"
      return 1 ;;
  esac
  # SPLIT ON A TOP-LEVEL `|` ONLY, THE WAY THE SHELL DOES. `tr '|' '\n'` was quote-blind,
  # so a read-only command carrying a quoted ERE alternation was torn in two and the
  # fragment after the bar was refused as an unknown command:
  #
  #     $ grep -cE 'alpha|beta' data.txt   ->  FAIL (ALLOWLIST), refused token `'beta'`
  #     $ grep -cE 'alpha' data.txt        ->  exit 0, the near-miss that names the cause
  #
  # That is a false refusal on correct data, and this boundary now runs with no human in
  # the loop -- `ai-dlc-derivation-capture.sh` re-runs a block inside the tool call that
  # wrote it -- so an author who cannot save a file gets the hook turned off.
  #
  # AN UNRESOLVED QUOTE IS REFUSED RATHER THAN SPLIT, and that cannot be a false refusal:
  # a command with an unbalanced quote does not run under `bash -c` either, so no correct
  # derivation is in that population. Guessing where its segments end is the one way this
  # scan could fail OPEN, which is the direction the allowlist exists to prevent.
  #
  # A `#` AT A WORD BOUNDARY ENDS THE COMMAND, because it does for the shell too, and
  # skipping that made the scan disagree with `bash -n` on real input: `grep -c x f #
  # test_safeguards.py's regex` is a command bash runs and this scan called unbalanced,
  # on an apostrophe the shell never reads. That would have been a NEW false refusal on
  # correct data, which is the thing this change exists to remove.
  #
  # The quote characters are built with `sprintf` rather than written literally, because a
  # literal `'` inside a single-quoted awk program needs `'"'"'` and that escaping is
  # itself a place this has to be got right.
  segs="$(printf '%s' "$c" | awk '
    BEGIN { SQ = sprintf("%c", 39); DQ = sprintf("%c", 34); BS = sprintf("%c", 92); HASH = sprintf("%c", 35) }
    { sq = 0; dq = 0; out = ""; n = length($0); prev = " "
      for (i = 1; i <= n; i++) {
        ch = substr($0, i, 1)
        # Unquoted `#` opening a word is a comment: the shell reads no further and
        # neither do we, so nothing after it can open a quote or be a pipe.
        if (ch == HASH && sq == 0 && dq == 0 && (prev == " " || prev == "\t")) break
        # ANSI-C QUOTING IS REFUSED, AND THE TEST BELONGS HERE RATHER THAN IN THE
        # METACHARACTER BAN ABOVE. A dollar sign opening a quote makes bash read an
        # escaped quote inside it as a LITERAL where this scan reads a toggle, so the two
        # disagree about where the quotes are and a bar can land in the window between
        # them. Measured: a command this scan called one segment, whose second stage bash
        # ran. Banning the two characters as a SUBSTRING instead refuses 21 correct
        # commands in the reference corpus, every one a regex end-anchor before a closing
        # quote. Only the quote STATE separates those two populations, and only this loop
        # has it.
        if (ch == "$" && sq == 0 && dq == 0 && i < n && substr($0, i+1, 1) == SQ) exit 4
        # Inside single quotes a backslash is literal; everywhere else it escapes the
        # next character, so that character can never open, close or be a delimiter.
        if (ch == BS && sq == 0) { out = out ch; i++; if (i <= n) out = out substr($0, i, 1); prev = "x"; continue }
        if (ch == SQ && dq == 0) { sq = !sq; out = out ch; prev = ch; continue }
        if (ch == DQ && sq == 0) { dq = !dq; out = out ch; prev = ch; continue }
        if (ch == "|" && sq == 0 && dq == 0) { print out; out = ""; prev = " "; continue }
        out = out ch; prev = ch
      }
      if (sq || dq) exit 3
      print out
    }')" || scan_rc=$?
  case "${scan_rc:-0}" in
    0) ;;
    4) REFUSED="it uses \$'...' ANSI-C quoting, which this checker does not model -- bash and
      this scan disagree about where such a quote ends, and a pipe hidden in that gap would
      run unchecked"
       return 1 ;;
    *) REFUSED="it carries an unbalanced quote, so it cannot be run or safely parsed"
       return 1 ;;
  esac
  # Every segment of the pipeline must itself be allowlisted.
  printf '%s\n' "$segs" | while IFS= read -r seg; do
    first="$(printf '%s' "$seg" | sed 's/^[[:space:]]*//' | awk '{print $1}')"
    [ -n "$first" ] || continue
    # HERE-STRING, NOT `printf | grep -q`. Under `pipefail` the pipeline reports the
    # WRITER's status, so once the value crosses the pipe buffer grep's early exit makes
    # the test answer "not found" on input that contains the pattern -- and here a
    # "not found" means ALLOWED, which is the direction that fails open. I54/I54b.
    grep -qF " $first " <<< " $ALLOWED_CMDS " || { printf 'BAD:%s\n' "$first"; break; }
    if [ "$first" = "git" ]; then
      sub="$(printf '%s' "$seg" | sed 's/^[[:space:]]*//' | awk '{print $2}')"
      grep -qF " $sub " <<< " $ALLOWED_GIT_SUB " || { printf 'BADGIT:%s\n' "$sub"; break; }
    fi
    # THE WRITE AND EXEC PREDICATES OF THE ALLOWED TOOLS. The first-word allowlist admits
    # read-only PROGRAMS, and several of them carry one option that writes a file or runs a
    # command: `find -delete`, `sed -i`, `sort -o`, `awk 'system(...)'`, `git grep -O`. None
    # of those needs a shell metacharacter, so the chain/redirect refusal above never sees
    # them. Until v0.385.0 they ran only when an operator invoked the gate;
    # `ai-dlc-derivation-capture.sh` now re-runs a block inside the tool call that wrote it,
    # so this boundary has to hold with no human in the loop.
    #
    # FALSE-POSITIVE SET, measured before shipping and as a DIFFERENTIAL against the copy
    # this replaces: both validators over the reference consumer's planning artifacts,
    # 1529 derivations in 2320 files, produce the SAME 87 allowlist refusals and the same
    # 497 stale findings -- 0 refusals are new. (The token scan behind it covers the wider
    # population of 4470 `$ `-prefixed lines in those files, fenced or not.) The
    # conditioning on the command NAME is what makes that hold: `grep -i` and `grep -o` are
    # two of the most common flags in that corpus and neither is a write.
    #
    # NOT COVERED, stated rather than left to be found: `uniq in out` writes its second
    # positional operand. Every detector for that also refuses `uniq -f 1 file`, whose `1`
    # is an option ARGUMENT and not an operand, and a false refusal here wedges a gate. The
    # claim this list makes is "the read-only tools cannot be turned into writers by one
    # obvious flag", not "no author can ever write a file".
    for w in $seg; do
      case "${first}:${w}" in
        find:-delete|find:-exec|find:-execdir|find:-ok|find:-okdir|\
        find:-fls|find:-fprint|find:-fprint0|find:-fprintf|\
        sed:-i|sed:-i.*|sed:--in-place|sed:--in-place=*|\
        sort:-o|sort:--output|sort:--output=*|\
        git:-O|git:-O?*|git:--open-files-in-pager|git:--open-files-in-pager=*|\
        git:--output|git:--output=*)
          printf 'BADOPT:%s %s\n' "$first" "$w"; break ;;
      esac
    done
    case "$first:$seg" in
      awk:*system\(*) printf 'BADOPT:awk system()\n'; break ;;
    esac
    # AWK TAKES A PROGRAM AS ITS ARGUMENT, AND A BAR INSIDE THAT PROGRAM IS AN EXEC
    # VECTOR THIS CHECKER CANNOT TELL FROM AN ALTERNATION. `print ... | "cmd"` and
    # `"cmd" | getline` are awk's pipes to a shell -- arbitrary execution, needing no
    # shell metacharacter, so the ban above never sees them. Until the quote-aware split
    # landed, `tr '|' '\n'` tore the awk program apart and the fragment failed the
    # allowlist; that ACCIDENT was the only thing refusing them, and removing it acquitted
    # a true positive. Measured: both vectors ran and created a file.
    #
    # Separating them from `/alpha|beta/` needs a scan of awk's OWN string and regex
    # grammar -- a second parser, a second divergence surface. The crude test (a bar
    # adjacent to a double quote) false-refuses `awk -F'|' '{print $2,"|",$3}'`, which is
    # real and in the reference corpus. So awk keeps its PRE-SPLIT behaviour: any bar in
    # an awk segment is refused. That is not a new refusal -- those commands are refused
    # today for the accidental reason -- and it costs the 3 awk alternations in the 3408,
    # which stay exactly as they are rather than being newly broken.
    case "$first" in
      awk) case "$seg" in *'|'*) printf 'BADOPT:awk program containing a pipe\n'; break ;; esac ;;
    esac
  done > "$TMP_SAFE"
  if grep -q '^BAD:' "$TMP_SAFE" 2>/dev/null; then
    REFUSED="'$(sed -n 's/^BAD://p' "$TMP_SAFE" | head -1)' is not on the read-only allowlist
      ($ALLOWED_CMDS)"
    return 1
  fi
  if grep -q '^BADOPT:' "$TMP_SAFE" 2>/dev/null; then
    REFUSED="'$(sed -n 's/^BADOPT://p' "$TMP_SAFE" | head -1)' writes a file or runs a command
      -- the allowlist admits read-only PROGRAMS, not every option they carry, and this
      block is re-run automatically at write time"
    return 1
  fi
  if grep -q '^BADGIT:' "$TMP_SAFE" 2>/dev/null; then
    REFUSED="'git $(sed -n 's/^BADGIT://p' "$TMP_SAFE" | head -1)' is not a read-only git subcommand
      ($ALLOWED_GIT_SUB)"
    return 1
  fi
  return 0
}

TMP_SAFE="$(mktemp)"; TMP_OUT="$(mktemp)"; TMP_EXP="$(mktemp)"
trap 'rm -f "$TMP_SAFE" "$TMP_OUT" "$TMP_EXP"' EXIT

# Compare on TRIMMED lines: trailing whitespace in a fenced block is invisible to the
# author and is never the defect being hunted. Everything else compares byte-for-byte.
norm() { sed 's/[[:space:]]*$//' | sed '/^$/d'; }

check_file() { # $1 artifact path
  local f="$1" in_block=0 line cmd expected_started
  local blockline=0 cmdline=0
  files_seen=$((files_seen + 1))
  cmd=""; : > "$TMP_EXP"; expected_started=0
  local lineno=0
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    if [ "$in_block" -eq 0 ]; then
      case "$line" in
        '```derived'|'```derived '*) in_block=1; blockline=$lineno; blocks=$((blocks + 1)); cmd=""; : > "$TMP_EXP" ;;
      esac
      continue
    fi
    # inside a ```derived block
    case "$line" in
      '```'*)
        [ -n "$cmd" ] && run_pair "$f" "$cmdline" "$cmd"
        in_block=0; cmd=""; : > "$TMP_EXP"
        continue ;;
    esac
    case "$line" in
      '$ '*)
        [ -n "$cmd" ] && run_pair "$f" "$cmdline" "$cmd"
        cmd="${line#\$ }"; cmdline=$lineno; : > "$TMP_EXP"
        continue ;;
    esac
    [ -n "$cmd" ] && printf '%s\n' "$line" >> "$TMP_EXP"
  done < "$f"
  if [ "$in_block" -eq 1 ]; then
    fail "GRAMMAR" "$f:$blockline opens a \`\`\`derived block that is never closed."
  fi
}

run_pair() { # $1 file  $2 line  $3 command   (expected output is in $TMP_EXP)
  local f="$1" ln="$2" c="$3" rc
  checked=$((checked + 1))
  if [ "$LIST_ONLY" -eq 1 ]; then
    printf '  %s:%s  %s\n' "$f" "$ln" "$c"
    return
  fi
  if ! cmd_is_safe "$c"; then
    fail "ALLOWLIST" "$f:$ln runs a command this checker refuses to execute:
      \$ $c
      $REFUSED
      A derivation is fenced \`\`\`derived to promise it is MACHINE-CHECKABLE. Rewrite it
      with the read-only tools above, or unfence it and accept that the adversarial pass
      must run it by hand -- which is the cost this block exists to avoid."
    return
  fi
  ( cd "$AI_DLC_ROOT" && eval "$c" ) > "$TMP_OUT" 2>/dev/null
  rc=$?
  # A non-zero rc is only a failure when the block recorded output. `grep` exiting 1 on
  # NO HITS is a legitimate derivation of a negative, and the artifact records it as such.
  if [ "$rc" -ne 0 ] && [ ! -s "$TMP_OUT" ] && [ ! -s "$TMP_EXP" ]; then
    return
  fi
  if ! diff -q <(norm < "$TMP_EXP") <(norm < "$TMP_OUT") >/dev/null 2>&1; then
    fail "STALE" "$f:$ln records an output its own command no longer produces.
      \$ $c
      recorded: $(norm < "$TMP_EXP" | tr '\n' '/' | sed 's:/$::' | cut -c1-160)
      actual:   $(norm < "$TMP_OUT" | tr '\n' '/' | sed 's:/$::' | cut -c1-160)
      The claim this derivation supports is asserting a fact about the tree that is no
      longer true. Re-derive it and rewrite the sentence it supports -- a derivation is
      true about the tree at the moment it ran, and the usual way one goes stale is a
      later edit that moved what it was counting."
  fi
}

for target in "$@"; do
  if [ -d "$target" ]; then
    while IFS= read -r f; do check_file "$f"; done < <(find "$target" -type f -name '*.md' | sort)
  elif [ -f "$target" ]; then
    check_file "$target"
  else
    echo "ERROR: no such file or directory: $target" >&2
    exit 2
  fi
done

if [ "$LIST_ONLY" -eq 1 ]; then
  printf '%s derivation(s) in %s block(s) across %s file(s).\n' "$checked" "$blocks" "$files_seen"
  exit 0
fi

if [ "$fails" -gt 0 ]; then
  printf 'FAIL: %s stale or unrunnable derivation(s) of %s checked in %s file(s).\n' \
    "$fails" "$checked" "$files_seen" >&2
  exit 1
fi
printf 'OK: %s derivation(s) in %s block(s) across %s file(s) reproduce at HEAD.\n' \
  "$checked" "$blocks" "$files_seen"
exit 0
