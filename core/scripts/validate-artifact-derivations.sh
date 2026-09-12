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
# info-string is exactly `derived` (the fence may be indented, as inside a list item):
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
  local c="$1" seg first sub segs scan_rc=0 sed_verdict
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
        sed:-i*|sed:--in*|\
        sort:-o|sort:--output|sort:--output=*|\
        git:-O|git:-O?*|git:--open-files-in-pager|git:--open-files-in-pager=*|\
        git:--output|git:--output=*)
          printf 'BADOPT:%s %s\n' "$first" "$w"; break ;;
      esac
    done
    case "$first:$seg" in
      awk:*system\(*) printf 'BADOPT:awk system()\n'; break ;;
    esac
    # SED'S WRITING VERBS LIVE INSIDE THE SCRIPT ARGUMENT, WHERE NO OPTION-WORD SCAN CAN
    # REACH THEM. The `for w in $seg` loop above matches `${first}:${w}`, so it sees
    # `sed -i` and is structurally blind to `w file`, `W file` and the `w file` FLAG on
    # `s///` -- none of which is an option word. Measured against bash on this machine, in
    # a sandbox, each creating its canary at exit 0 through the pre-fix validator:
    #
    #     sed -n 'w canary' data.txt        sed 's/a/b/w canary' data.txt
    #     sed '/a/w canary' data.txt        sed 's/a/b/gw canary' data.txt
    #     sed -n '$w canary' data.txt       sed -n '1,3w canary' data.txt
    #     sed -n '2!w canary' data.txt      sed -n '1{w canary<NL>}' data.txt
    #     sed -n '/alpha/wp' data.txt       sed -n -f evil.sed data.txt
    #
    # GNU's `e` command and `s///e` flag are refused too and are NOT live here -- BSD sed
    # exits 1 on both -- because a consumer may run GNU sed, where they are arbitrary
    # execution. `W` is likewise refused and likewise inert on BSD.
    #
    # WHY A PARSER AND NOT A REGEX. A `w` is a write only in COMMAND position. Every other
    # position is legitimate and common: inside a regex (`/w/p`), inside a replacement
    # (`s/x/\w/`), inside a filename (`a-w-file.md`), inside an s/// pattern (`s/wow/wew/`).
    # A regex cannot tell those apart, because finding command position means consuming
    # addresses, delimiters and bracket expressions -- `s/[/]/x/w f` has a LITERAL `/`
    # inside `[...]`, and `/alpha/w/p` writes to a file named `/p` while `/w/p` prints.
    # An unanchored `s(.)...\1...\1<flags>` scan was built first and carried 5 false
    # positives over the reference corpus, all inside `/regex/=` addresses whose text
    # happened to end in a letter the scan read as a flag. So this consumes sed's grammar
    # and FAILS CLOSED: a construct it cannot parse is refused, never guessed at, because
    # guessing is the direction that fails open.
    #
    # `-f`/`--file` IS REFUSED OUTRIGHT rather than followed. `sed -n -f evil.sed data.txt`
    # carries no `w` in the segment at all -- the verb is in a file -- and it wrote its
    # canary through the pre-fix validator. Following the file would make the checker read
    # and execute a second program; refusing it costs 0 derivations in the corpus (measured
    # below) and a derivation whose script is not in the derivation is not self-contained.
    #
    # FALSE-POSITIVE SET: 0, over the population this arm actually runs on. Derived by
    # extracting every pipeline segment whose first word is `sed` from every `$ `-prefixed
    # line of the reference consumer's planning artifacts, using THIS function's own
    # quote-aware splitter, and scoring each with this predicate:
    #
    #   bash core/fixtures/artifact-derivations/fp-sweep.sh /Users/n8/git/graph/_bmad-output
    #
    #   4415 markdown files -> 9748 `$ ` lines -> 1767 sed segments (1406 distinct).
    #   1656 survive this function's metacharacter ban and so reach this arm; 111 do not.
    #   Of those 1656: 1652 ALLOWED, 4 refused. All 4 are `sed -i '' ...` -- real in-place
    #   writes the SHIPPED `sed:-i*` table above already refuses, so the INCREMENTAL false
    #   positive set of this arm is 0.
    #   POSITIVE CONTROL, same invocation: 9 seeded write/exec forms, 9 refused.
    #   NEGATIVE CONTROL, same invocation: `sed -n 'p' ZZQQ9_NEVER_SED_TOKEN.txt` ALLOWED,
    #   and that token is absent from the corpus (grep: 0) so the control cannot pass by
    #   matching real text.
    #   This repo's own `docs/**` and `core/**` hold 12 `$ ` lines and 0 sed segments;
    #   CONTROL in the same run, 7 of those 12 are `grep` lines, so the zero is a real
    #   absence of sed and not a broken extraction.
    #
    # `core/fixtures/artifact-derivations/fp-sweep.sh` IS the deriver and it EXTRACTS this
    # function's awk program from this file rather than restating it, so the figures above
    # cannot be measured against a second copy of the grammar.
    if [ "$first" = "sed" ]; then
      sed_verdict="$(printf '%s\n' "$seg" | awk '
        function shwords(line, W,   i, n, ch, c2, word, nw) {
          n = length(line); i = 1; nw = 0
          while (i <= n) {
            ch = substr(line, i, 1)
            if (ch == " " || ch == "\t") { i++; continue }
            word = ""
            while (i <= n) {
              ch = substr(line, i, 1)
              if (ch == " " || ch == "\t") break
              if (ch == BS) { i++; if (i <= n) { word = word substr(line, i, 1); i++ }; continue }
              if (ch == SQ) { i++; while (i <= n && substr(line, i, 1) != SQ) { word = word substr(line, i, 1); i++ }; i++; continue }
              if (ch == DQ) { i++
                while (i <= n && substr(line, i, 1) != DQ) {
                  c2 = substr(line, i, 1)
                  if (c2 == BS && index(DQ BS "$", substr(line, i+1, 1)) > 0) { i++; word = word substr(line, i, 1); i++ }
                  else { word = word c2; i++ }
                }
                i++; continue }
              word = word ch; i++
            }
            nw++; W[nw] = word
          }
          return nw
        }
        function consume_bracket(s, i,   ch, j, k) {
          i++
          if (substr(s, i, 1) == "^") i++
          if (substr(s, i, 1) == "]") i++
          while (i <= length(s)) {
            ch = substr(s, i, 1); k = substr(s, i+1, 1)
            if (ch == "[" && (k == ":" || k == "." || k == "=")) {
              j = index(substr(s, i+2), k "]"); if (j == 0) return 0
              i = i + 2 + j + 1; continue
            }
            if (ch == "]") return i + 1
            i++
          }
          return 0
        }
        function consume_regex(s, i, delim,   ch) {
          while (i <= length(s)) {
            ch = substr(s, i, 1)
            if (ch == BS) { i += 2; continue }
            if (ch == "[") { i = consume_bracket(s, i); if (i == 0) return 0; continue }
            if (ch == delim) return i + 1
            i++
          }
          return 0
        }
        function consume_flat(s, i, delim,   ch) {
          while (i <= length(s)) {
            ch = substr(s, i, 1)
            if (ch == BS) { i += 2; continue }
            if (ch == delim) return i + 1
            i++
          }
          return 0
        }
        function skipb(s, i) { while (substr(s, i, 1) == " " || substr(s, i, 1) == "\t") i++; return i }
        function script_verb(s,   i, n, ch, c, delim, j, flag) {
          i = 1; n = length(s)
          while (i <= n) {
            ch = substr(s, i, 1)
            if (ch == " " || ch == "\t" || ch == NL || ch == ";") { i++; continue }
            if (ch == "#") { j = index(substr(s, i), NL); if (j == 0) return ""; i = i + j; continue }
            while (1) {
              ch = substr(s, i, 1)
              if (ch ~ /[0-9]/) {
                while (i <= n && substr(s, i, 1) ~ /[0-9]/) i++
                if (substr(s, i, 1) == "~") { i++; while (i <= n && substr(s, i, 1) ~ /[0-9]/) i++ }
              }
              else if (ch == "$") i++
              else if (ch == "+" || ch == "~") { i++; while (substr(s, i, 1) ~ /[0-9]/) i++ }
              else if (ch == "/") {
                i = consume_regex(s, i+1, "/"); if (i == 0) return "?an unterminated address regex"
                while (substr(s, i, 1) == "I" || substr(s, i, 1) == "M") i++
              }
              else if (ch == BS) {
                delim = substr(s, i+1, 1); if (delim == "") return "?an unterminated address regex"
                i = consume_regex(s, i+2, delim); if (i == 0) return "?an unterminated address regex"
                while (substr(s, i, 1) == "I" || substr(s, i, 1) == "M") i++
              }
              else break
              i = skipb(s, i)
              if (substr(s, i, 1) == ",") { i = skipb(s, i+1); continue }
              break
            }
            while (substr(s, i, 1) == "!") i = skipb(s, i+1)
            i = skipb(s, i)
            c = substr(s, i, 1)
            if (c == "") return ""
            if (c == "w") return "sed script command `w`, which WRITES the named file"
            if (c == "W") return "sed script command `W`, which WRITES the named file"
            if (c == "e") return "sed script command `e`, which RUNS a shell command (GNU)"
            if (c == "s") {
              i++; delim = substr(s, i, 1); if (delim == "") return "?an s/// with no delimiter"
              i = consume_regex(s, i+1, delim); if (i == 0) return "?an unterminated s/// pattern"
              i = consume_flat(s, i, delim);    if (i == 0) return "?an unterminated s/// replacement"
              while (i <= n) {
                flag = substr(s, i, 1)
                if (flag == "w") return "the `w` FLAG on an s/// command, which WRITES the named file"
                if (flag == "e") return "the `e` FLAG on an s/// command, which RUNS the replacement (GNU)"
                if (flag ~ /[0-9gpiImM]/) { i++; continue }
                break
              }
              continue
            }
            if (c == "y") {
              i++; delim = substr(s, i, 1); if (delim == "") return "?a y/// with no delimiter"
              i = consume_flat(s, i+1, delim); if (i == 0) return "?an unterminated y/// source"
              i = consume_flat(s, i, delim);   if (i == 0) return "?an unterminated y/// target"
              continue
            }
            if (c == "a" || c == "i" || c == "c") {
              i++
              while (i <= n) { if (substr(s, i, 1) == BS) { i += 2; continue }; if (substr(s, i, 1) == NL) break; i++ }
              continue
            }
            if (c == "r" || c == "R") { j = index(substr(s, i), NL); if (j == 0) return ""; i = i + j; continue }
            if (c == "b" || c == "t" || c == "T" || c == ":") {
              i++
              while (i <= n && substr(s, i, 1) != ";" && substr(s, i, 1) != NL && substr(s, i, 1) != "}") i++
              continue
            }
            if (c == "q" || c == "Q" || c == "l" || c == "L") { i++; while (i <= n && substr(s, i, 1) ~ /[0-9 \t]/) i++; continue }
            if (c == "{" || c == "}") { i++; continue }
            if (index("pPdDgGhHnNxzF=v", c) > 0) { i++; continue }
            return "?the sed command `" c "`, which this grammar does not model"
          }
          return ""
        }
        function sed_scan(seg,   W, SCR, OPD, nw, k, wd, ns, no, p, oc, expect, endopt, v) {
          nw = shwords(seg, W)
          ns = 0; no = 0; expect = ""; endopt = 0
          for (k = 2; k <= nw; k++) {
            wd = W[k]
            if (expect == "script") { ns++; SCR[ns] = wd; expect = ""; continue }
            if (endopt) { no++; OPD[no] = wd; continue }
            if (wd == "--") { endopt = 1; continue }
            if (substr(wd, 1, 2) == "--") {
              if (wd ~ /^--expression=/) { ns++; SCR[ns] = substr(wd, 14); continue }
              if (wd == "--expression")  { expect = "script"; continue }
              if (wd ~ /^--file(=|$)/)   return "`-f`/`--file`, which reads the sed script from a FILE this checker cannot see"
              if (wd ~ /^--(quiet|silent|regexp-extended|separate|unbuffered|null-data|posix|debug|sandbox|help|version|follow-symlinks|binary|zero-terminated)$/) continue
              return "?the sed option `" wd "`, whose arity this grammar does not know"
            }
            if (substr(wd, 1, 1) == "-" && length(wd) > 1) {
              for (p = 2; p <= length(wd); p++) {
                oc = substr(wd, p, 1)
                if (oc == "e") { if (p < length(wd)) { ns++; SCR[ns] = substr(wd, p+1) } else expect = "script"; break }
                if (oc == "f") return "`-f`/`--file`, which reads the sed script from a FILE this checker cannot see"
                if (oc == "i") return "`-i`/`--in-place`, which REWRITES the input file"
                if (index("nrEsuzagb", oc) > 0) continue
                return "?the sed option `-" oc "`, whose arity this grammar does not know"
              }
              continue
            }
            no++; OPD[no] = wd
          }
          if (expect == "script") return "?a `-e` with no script after it"
          if (ns == 0 && no >= 1) { ns = 1; SCR[1] = OPD[1] }
          for (k = 1; k <= ns; k++) { v = script_verb(SCR[k]); if (v != "") return v }
          return ""
        }
        BEGIN { SQ = sprintf("%c", 39); DQ = sprintf("%c", 34); BS = sprintf("%c", 92); NL = sprintf("%c", 10) }
        { v = sed_scan($0)
          if (v == "") next
          if (substr(v, 1, 1) == "?") print "a construct this checker cannot parse -- " substr(v, 2)
          else print v
          exit }')"
      if [ -n "$sed_verdict" ]; then
        printf 'BADOPT:sed -- %s\n' "$sed_verdict"; break
      fi
    fi
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

# A FENCE MAY BE INDENTED, AND UNTIL v0.500.0 THIS READER COULD NOT SEE ONE THAT WAS. The
# opener was matched against the line as read, so a ```derived block written inside a list
# item -- `- item` then `  ```derived` -- never opened a block, its pairs were never run, and
# the file reported "0 derivation(s) in 0 block(s)" with exit 0: the one output this script
# must never produce over a fence, because an author who fenced a claim to make it
# machine-checkable got no check and no error. Measured on the reference consumer: 11 files
# carrying indented fences against 272 unindented, plus fences an author had already demoted
# to `text` because the check was not firing. Filed as
# PC-S308-VALIDATE-ARTIFACT-DERIVATIONS-INDENTED-FENCE-BLIND-SPOT.
#
# The rule is CommonMark's: the opener's leading blanks are the block's indent, and each
# content line sheds THAT prefix -- exactly it when present, whatever leading blanks it has
# when it carries fewer. Not "all leading blanks": a `wc -l` output is `       2`, and an
# unindented block must keep those seven spaces or the recorded output stops matching the
# command that produced it. Any width of indent opens a fence. CommonMark caps a fence at
# three spaces outside a list and this deliberately does not: the fence is the author's
# promise, and running a fence CommonMark would have rendered as literal text is a visible
# STALE the author can read, where skipping it is the silent zero this comment records.
# `ai-dlc-derivation-capture.sh` carries the same rule in its mask and its two cheap rejects;
# the two are one population by contract (its header says why), so a change here is a change
# there.
#
# AND THE INFO STRING IS EXACTLY `derived`, with nothing after it but blanks. The opener used
# to accept `'```derived '*` -- any trailing text -- and that arm matched no real fence: over
# the reference consumer's 2795 openers, none carries a legitimate info string beyond the
# word, and the only two lines with text after it are PROSE, a wrapped sentence whose
# continuation happens to begin with the token ("```derived blocks are machine-checked and
# plain blocks are not, ..."). Each of those opened a phantom block that ran to the next real
# opener, read that opener as its closer, and left the real block's pairs outside any fence --
# three derivations in one file, silently unchecked, and the indent rule above made the
# wrapped-in-a-list-item form reachable where the column-0 reader had met it only once. So the
# arm is closed; a fence CommonMark reads with a longer info string is not a derivation fence
# here.
#
# NOT COVERED, stated rather than left to be found. A CRLF file opens nothing: the carriage
# return after the word is not a blank, so the file reports zero derivations with exit 0, the
# same silent shape as before this rule, unchanged. A closer indented DEEPER than its opener is
# not read as a closer, where CommonMark would accept it, so the block runs to end of file and
# is reported unclosed -- loud, not silent. Zero instances of either in the reference corpus.
#
# THE INDENT AND SHED RULES ARE INLINE IN check_file, NOT HELPER FUNCTIONS, because a helper
# reached through `$( )` forks once per line of every markdown file. Measured on a 2855-line
# consumer artifact, `--list` only: 0.05s before the rules existed, 2.61s with the rules in
# forked helpers, 0.10s inline -- and `ai-dlc-derivation-capture.sh` pays this on every Write
# or Edit of a fence-carrying file, which is the shape that gets a hook turned off.
is_opener() { # $1 line with its indent already shed -> 0 when it opens a ```derived block
  local b="$1"
  b="${b%"${b##*[![:blank:]]}"}"   # drop trailing blanks
  [ "$b" = '```derived' ]
}

check_file() { # $1 artifact path
  local f="$1" in_block=0 line body indent cmd expected_started
  local blockline=0 cmdline=0
  files_seen=$((files_seen + 1))
  cmd=""; : > "$TMP_EXP"; expected_started=0; indent=""
  local lineno=0
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    if [ "$in_block" -eq 0 ]; then
      indent="${line%%[![:blank:]]*}"          # the line's leading blanks, possibly empty
      if is_opener "${line#"$indent"}"; then
        in_block=1; blockline=$lineno; blocks=$((blocks + 1)); cmd=""; : > "$TMP_EXP"
      else
        indent=""
      fi
      continue
    fi
    # inside a ```derived block -- every line below is read with the block's indent shed:
    # exactly the opener's indent when the line carries it, else whatever leading blanks it has
    case "$line" in
      "$indent"*) body="${line#"$indent"}" ;;
      *)          body="${line#"${line%%[![:blank:]]*}"}" ;;
    esac
    case "$body" in
      '```'*)
        [ -n "$cmd" ] && run_pair "$f" "$cmdline" "$cmd"
        in_block=0; cmd=""; : > "$TMP_EXP"; indent=""
        continue ;;
    esac
    case "$body" in
      '$ '*)
        [ -n "$cmd" ] && run_pair "$f" "$cmdline" "$cmd"
        cmd="${body#\$ }"; cmdline=$lineno; : > "$TMP_EXP"
        continue ;;
    esac
    [ -n "$cmd" ] && printf '%s\n' "$body" >> "$TMP_EXP"
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
