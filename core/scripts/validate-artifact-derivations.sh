#!/usr/bin/env bash
# validate-artifact-derivations.sh — re-run the derivations a planning artifact carries
#
# Usage: ./scripts/ai-dlc/validate-artifact-derivations.sh [--all] <file-or-dir> [<file-or-dir>...]
#        ./scripts/ai-dlc/validate-artifact-derivations.sh --list [--all] <file-or-dir>...
#
# A DIRECTORY target skips frozen records (under `shards/`, and a sprint slot's review/repair
# records) and prints an `EXCLUDED:` count; `--all` walks them. A FILE target
# is always checked. The walk below says what is frozen and why.
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
# from the PROJECT ROOT, so paths are written as the artifact writes them. A command names
# the file it measures as an operand: it runs on a one-line sentinel stdin, never on the
# artifact, and one that reads that stdin fails as READS-STDIN (run_pair says why).
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
# A RECORD'S LATER RE-DERIVATION SUPERSEDES ITS EARLIER FENCE. In a review or repair record --
# the walk's own record grammar below, `is_record` -- a `$ ` command is SUPERSEDED when a LATER
# `$ ` command line in the same file is byte-identical. It is not run and not counted; the LAST
# copy runs and its verdict stands, and each skip is printed on stderr beside the FAIL lines:
#
#     SUPERSEDED: <file>:<skipped-line> by <file>:<later-line>
#
# A record is append-only, so re-deriving a stale figure means writing the command again further
# down, and until this rule the earlier fence kept the record red for good. Measured on the
# reference consumer's s319 `requirements-repair-p1.md`: 9 of 105 commands stale, every one
# re-derived in a later block, and the file still failed. Under this rule all 9 are superseded,
# 13 of the 105 in all, and the 4 reproducing ones each have a later identical copy that runs.
# WHAT IT ACQUITS, measured over the reference consumer's records: 54 of 366 fence-carrying
# records repeat a command; 15 earlier copies record an output different from the later one's,
# and every one of the 15 is marked by its author as history (s319 and s317). The key is the
# command alone: a key of command plus recorded output could only supersede copies that pass.
# A live document (prd, stories, digests) supersedes nothing -- an earlier sentence there is
# still asserted -- and neither does a record-named file outside `s<digits>/`. Only a `$ ` line
# the block grammar reads as a COMMAND counts as a later copy; the same text in a `text` fence,
# in prose, or as a recorded output line indented deeper than its fence never does. `--list`
# still lists every command.
# AT WRITE TIME THE REAL FILE DECIDES. `ai-dlc-derivation-capture.sh` validates a masked copy
# under a `mktemp -d` parent, which blanks every pair the write did not touch -- including the
# later copy that supersedes a touched earlier one. So the hook passes the real file as
# AI_DLC_DERIV_SUPERSEDE_FROM, and the pre-pass takes `is_record`'s parent and basename, and every
# later copy, from THAT file: the same record test and the same later copies the gate reads. The
# argument's own commands must sit at the same lines of that file, or the run is REFUSED (exit 2)
# -- a mask that does not join the file it claims to be is no basis for skipping anything.
# check_file carries the join; the hook says how it surfaces a refusal.
#
# Exit: 0 all derivations reproduce | 1 a derivation is stale or malformed | 2 usage, a
# derivation that did not run to completion or whose output could not be COMPARED (an
# `UNRUN:` line names each; run_pair says why), or a directory target that could not be
# walked -- each a refusal and never a verdict. A caller treats 1 as a repair to make and 2
# as a run to repeat; reading 2 as either a verdict or a clean is the defect run_pair's
# comparison comment records.
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

# THE OPTION TABLE, one row per token: `cmd|sub|token|arity|note`. cmd_is_safe's header carries
# the walker rules, the review rule for a row and why a match is exact. Arity is `none`,
# `required` (the attached remainder, `=value`, or the next word), `optional` (an attached value
# only) or `num` (the `-NUM` row: a dash and digits). Read with `read -d ''` rather than `$( )`,
# because a heredoc carrying `(` and `)` inside a multi-line `$( )` is the shape bash 3.2 closes
# early.
read -r -d '' OPT_TABLE <<'OPT_TABLE_END' || true
grep||-E|none|gnu+bsd seed
grep||--extended-regexp|none|gnu+bsd seed
grep||-F|none|gnu+bsd seed
grep||--fixed-strings|none|gnu+bsd seed
grep||-G|none|gnu+bsd seed
grep||--basic-regexp|none|gnu+bsd seed
grep||-i|none|gnu+bsd seed
grep||--ignore-case|none|gnu+bsd seed
grep||-v|none|gnu+bsd seed
grep||--invert-match|none|gnu+bsd seed
grep||-w|none|gnu+bsd seed
grep||--word-regexp|none|gnu+bsd seed
grep||-x|none|gnu+bsd seed
grep||--line-regexp|none|gnu+bsd seed
grep||-c|none|gnu+bsd seed
grep||--count|none|gnu+bsd seed
grep||-L|none|gnu+bsd seed
grep||--files-without-match|none|gnu+bsd seed
grep||-l|none|gnu+bsd seed
grep||--files-with-matches|none|gnu+bsd seed
grep||-o|none|gnu+bsd seed
grep||--only-matching|none|gnu+bsd seed
grep||-q|none|gnu+bsd seed
grep||--quiet|none|gnu+bsd seed
grep||--silent|none|gnu+bsd seed
grep||-s|none|gnu+bsd seed
grep||--no-messages|none|gnu+bsd seed
grep||-b|none|gnu+bsd seed
grep||--byte-offset|none|gnu+bsd seed
grep||-H|none|gnu+bsd seed
grep||-h|none|gnu+bsd seed
grep||--no-filename|none|gnu+bsd seed
grep||-n|none|gnu+bsd seed
grep||--line-number|none|gnu+bsd seed
grep||--null|none|gnu+bsd seed
grep||-z|none|gnu+bsd seed
grep||--null-data|none|gnu+bsd seed
grep||-a|none|gnu+bsd seed
grep||--text|none|gnu+bsd seed
grep||-I|none|gnu+bsd seed
grep||-U|none|gnu+bsd seed
grep||--binary|none|gnu+bsd seed
grep||-r|none|gnu+bsd seed
grep||-R|none|gnu+bsd seed
grep||--recursive|none|gnu+bsd seed
grep||--line-buffered|none|gnu+bsd seed
grep||-V|none|gnu+bsd seed
grep||--version|none|gnu+bsd seed
grep||--help|none|gnu+bsd seed
grep||-e|required|gnu+bsd seed
grep||--regexp|required|gnu+bsd seed
grep||-m|required|gnu+bsd seed
grep||--max-count|required|gnu+bsd seed
grep||-A|required|gnu+bsd seed
grep||--after-context|required|gnu+bsd seed
grep||-B|required|gnu+bsd seed
grep||--before-context|required|gnu+bsd seed
grep||-C|required|gnu+bsd seed
grep||--binary-files|required|gnu+bsd seed
grep||-D|required|gnu+bsd seed
grep||--devices|required|gnu+bsd seed
grep||-d|required|gnu+bsd seed
grep||--directories|required|gnu+bsd seed
grep||--include|required|gnu+bsd seed
grep||--exclude|required|gnu+bsd seed
grep||--exclude-dir|required|gnu+bsd seed
grep||--color|optional|gnu+bsd seed
grep||--colour|optional|gnu+bsd seed
grep||-f|required|gnu+bsd (BSD grep page: -f file, --file=file, reads patterns); reference consumer _bmad-output/planning-artifacts/s312/gate-sprint-review-repair-p1.md:189, 6 uses
grep||-P|none|GNU grep only (Perl regex, no value); BSD grep refuses it, "invalid option -- P", exit 2; reference consumer _bmad-output/planning-artifacts/s311/consolidation-coverage-carry-over-backlog.md:102, 1 use
rg||--no-context-separator|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--auto-hybrid-regex|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-auto-hybrid-regex|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--binary|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-binary|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--block-buffered|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-block-buffered|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-b|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--byte-offset|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-s|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--case-sensitive|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--column|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-column|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-c|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--count|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--count-matches|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--crlf|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-crlf|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-encoding|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--files|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-l|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--files-with-matches|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--files-without-match|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-F|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--fixed-strings|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-fixed-strings|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-L|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--follow|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-follow|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--glob-case-insensitive|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-glob-case-insensitive|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--heading|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-heading|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-.|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--hidden|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-hidden|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-i|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--ignore-case|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--ignore-file-case-insensitive|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-ignore-file-case-insensitive|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--include-zero|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-v|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--invert-match|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--json|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-json|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--line-buffered|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-line-buffered|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-n|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--line-number|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-N|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-line-number|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-x|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--line-regexp|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--max-columns-preview|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-max-columns-preview|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--mmap|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-mmap|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-U|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--multiline|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-multiline|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--multiline-dotall|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-multiline-dotall|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-config|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-I|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-filename|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-ignore|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--ignore|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-ignore-dot|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--ignore-dot|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-ignore-exclude|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--ignore-exclude|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-ignore-files|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--ignore-files|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-ignore-global|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--ignore-global|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-ignore-messages|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--ignore-messages|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-ignore-parent|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--ignore-parent|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-ignore-vcs|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--ignore-vcs|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-messages|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--messages|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-pcre2-unicode|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--pcre2-unicode|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-require-git|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--require-git|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-unicode|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--unicode|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-0|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--null|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--null-data|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--one-file-system|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-one-file-system|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-o|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--only-matching|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--passthru|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-P|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--pcre2|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-pcre2|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-p|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--pretty|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-q|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--quiet|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-S|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--smart-case|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--stats|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-stats|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-a|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--text|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-text|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--trim|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--no-trim|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--type-list|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-u|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--unrestricted|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--vimgrep|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-H|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--with-filename|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-w|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--word-regexp|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--help|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||--version|none|gnu-only (rg not installed; built from the GNU man text) seed
rg||-A|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--after-context|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||-B|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--before-context|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||-C|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--context|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--context-separator|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--color|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--colors|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--dfa-size-limit|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||-E|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--encoding|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--engine|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--field-context-separator|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--field-match-separator|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||-g|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--glob|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--iglob|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||-M|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--max-columns|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||-m|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--max-count|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--max-depth|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--max-filesize|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--path-separator|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--regex-size-limit|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||-e|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--regexp|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||-r|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--replace|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--sort|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--sortr|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||-j|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--threads|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||-t|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--type|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||-T|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--type-not|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--type-add|required|gnu-only (rg not installed; built from the GNU man text) seed
rg||--type-clear|required|gnu-only (rg not installed; built from the GNU man text) seed
sed||-n|none|gnu+bsd seed
sed||-E|none|gnu+bsd seed
sed||-r|none|gnu+bsd seed
sed||-u|none|gnu+bsd seed
sed||-e|required|gnu+bsd seed
awk||-F|required|gnu+bsd seed
awk||-v|required|gnu+bsd seed
find||-empty|none|gnu+bsd seed
find||-d|none|gnu+bsd seed
find||-prune|none|gnu+bsd seed
find||-print|none|gnu+bsd seed
find||-print0|none|gnu+bsd seed
find||-ls|none|gnu+bsd seed
find||-quit|none|gnu+bsd seed
find||-true|none|gnu+bsd seed
find||-false|none|gnu+bsd seed
find||-nouser|none|gnu+bsd seed
find||-nogroup|none|gnu+bsd seed
find||-xdev|none|gnu+bsd seed
find||-mount|none|gnu+bsd seed
find||-follow|none|gnu+bsd seed
find||-ignore_readdir_race|none|gnu+bsd seed
find||-noignore_readdir_race|none|gnu+bsd seed
find||-noleaf|none|gnu+bsd seed
find||-H|none|gnu+bsd seed
find||-L|none|gnu+bsd seed
find||-P|none|gnu+bsd seed
find||-not|none|gnu+bsd seed
find||-o|none|gnu+bsd seed
find||-a|none|gnu+bsd seed
find||-and|none|gnu+bsd seed
find||-or|none|gnu+bsd seed
find||-name|required|gnu+bsd seed
find||-iname|required|gnu+bsd seed
find||-path|required|gnu+bsd seed
find||-ipath|required|gnu+bsd seed
find||-wholename|required|gnu+bsd seed
find||-iwholename|required|gnu+bsd seed
find||-regex|required|gnu+bsd seed
find||-iregex|required|gnu+bsd seed
find||-lname|required|gnu+bsd seed
find||-ilname|required|gnu+bsd seed
find||-type|required|gnu+bsd seed
find||-maxdepth|required|gnu+bsd seed
find||-mindepth|required|gnu+bsd seed
find||-size|required|gnu+bsd seed
find||-mtime|required|gnu+bsd seed
find||-atime|required|gnu+bsd seed
find||-ctime|required|gnu+bsd seed
find||-mmin|required|gnu+bsd seed
find||-amin|required|gnu+bsd seed
find||-cmin|required|gnu+bsd seed
find||-newer|required|gnu+bsd seed
find||-anewer|required|gnu+bsd seed
find||-cnewer|required|gnu+bsd seed
find||-perm|required|gnu+bsd seed
find||-user|required|gnu+bsd seed
find||-group|required|gnu+bsd seed
find||-uid|required|gnu+bsd seed
find||-gid|required|gnu+bsd seed
find||-links|required|gnu+bsd seed
find||-inum|required|gnu+bsd seed
find||-samefile|required|gnu+bsd seed
find||-fstype|required|gnu+bsd seed
sort||-b|none|gnu+bsd seed
sort||--ignore-leading-blanks|none|gnu+bsd seed
sort||-d|none|gnu+bsd seed
sort||--dictionary-order|none|gnu+bsd seed
sort||-f|none|gnu+bsd seed
sort||--ignore-case|none|gnu+bsd seed
sort||-g|none|gnu+bsd seed
sort||--general-numeric-sort|none|gnu+bsd seed
sort||-i|none|gnu+bsd seed
sort||--ignore-nonprinting|none|gnu+bsd seed
sort||-M|none|gnu+bsd seed
sort||--month-sort|none|gnu+bsd seed
sort||-h|none|gnu+bsd seed
sort||--human-numeric-sort|none|gnu+bsd seed
sort||-n|none|gnu+bsd seed
sort||--numeric-sort|none|gnu+bsd seed
sort||-r|none|gnu+bsd seed
sort||--reverse|none|gnu+bsd seed
sort||-V|none|gnu+bsd seed
sort||--version-sort|none|gnu+bsd seed
sort||-c|none|gnu+bsd seed
sort||-C|none|gnu+bsd seed
sort||-m|none|gnu+bsd seed
sort||--merge|none|gnu+bsd seed
sort||-s|none|gnu+bsd seed
sort||-u|none|gnu+bsd seed
sort||--unique|none|gnu+bsd seed
sort||-z|none|gnu+bsd seed
sort||--zero-terminated|none|gnu+bsd seed
sort||--help|none|gnu+bsd seed
sort||--version|none|gnu+bsd seed
sort||--sort|required|gnu+bsd seed
sort||-k|required|gnu+bsd seed
sort||--key|required|gnu+bsd seed
sort||-S|required|gnu+bsd seed
sort||--buffer-size|required|gnu+bsd seed
sort||-t|required|gnu+bsd seed
sort||--field-separator|required|gnu+bsd seed
sort||--batch-size|required|gnu+bsd seed
sort||--check|optional|gnu+bsd seed
uniq||-c|none|gnu+bsd seed
uniq||--count|none|gnu+bsd seed
uniq||-d|none|gnu+bsd seed
uniq||--repeated|none|gnu+bsd seed
uniq||-i|none|gnu+bsd seed
uniq||--ignore-case|none|gnu+bsd seed
uniq||-u|none|gnu+bsd seed
uniq||--unique|none|gnu+bsd seed
uniq||-f|required|gnu+bsd seed
uniq||--skip-fields|required|gnu+bsd seed
uniq||-s|required|gnu+bsd seed
uniq||--skip-chars|required|gnu+bsd seed
cut||-n|none|gnu+bsd seed
cut||-s|none|gnu+bsd seed
cut||-b|required|gnu+bsd seed
cut||-c|required|gnu+bsd seed
cut||-d|required|gnu+bsd seed
cut||-f|required|gnu+bsd seed
head||-c|required|gnu+bsd seed
head||--bytes|required|gnu+bsd seed
head||-n|required|gnu+bsd seed
head||--lines|required|gnu+bsd seed
head||-NUM|num|measured: BSD head and GNU ghead both run -<n> on this machine; neither man page documents it
tail||-q|none|gnu+bsd seed
tail||--quiet|none|gnu+bsd seed
tail||--silent|none|gnu+bsd seed
tail||-v|none|gnu+bsd seed
tail||--verbose|none|gnu+bsd seed
tail||-c|required|gnu+bsd seed
tail||--bytes|required|gnu+bsd seed
tail||-n|required|gnu+bsd seed
tail||--lines|required|gnu+bsd seed
tail||-NUM|num|BSD page: historic -<n> syntax supported; GNU gtail runs -<n> on this machine (measured)
nl||-p|none|gnu+bsd seed
nl||-b|required|gnu+bsd seed
nl||-d|required|gnu+bsd seed
nl||-f|required|gnu+bsd seed
nl||-h|required|gnu+bsd seed
nl||-i|required|gnu+bsd seed
nl||-l|required|gnu+bsd seed
nl||-n|required|gnu+bsd seed
nl||-s|required|gnu+bsd seed
nl||-v|required|gnu+bsd seed
nl||-w|required|gnu+bsd seed
wc||-c|none|gnu+bsd seed
wc||-l|none|gnu+bsd seed
wc||-L|none|gnu+bsd seed
wc||-m|none|gnu+bsd seed
wc||-w|none|gnu+bsd seed
comm||-1|none|gnu+bsd seed
comm||-2|none|gnu+bsd seed
comm||-3|none|gnu+bsd seed
cat||-b|none|gnu+bsd seed
cat||-e|none|gnu+bsd seed
cat||-n|none|gnu+bsd seed
cat||-s|none|gnu+bsd seed
cat||-t|none|gnu+bsd seed
cat||-u|none|gnu+bsd seed
cat||-v|none|gnu+bsd seed
ls||-1|none|gnu+bsd seed
ls||-a|none|gnu+bsd seed
ls||-A|none|gnu+bsd seed
ls||-b|none|gnu+bsd seed
ls||-C|none|gnu+bsd seed
ls||-c|none|gnu+bsd seed
ls||-d|none|gnu+bsd seed
ls||-f|none|gnu+bsd seed
ls||-F|none|gnu+bsd seed
ls||-h|none|gnu+bsd seed
ls||-H|none|gnu+bsd seed
ls||-i|none|gnu+bsd seed
ls||-k|none|gnu+bsd seed
ls||-l|none|gnu+bsd seed
ls||-L|none|gnu+bsd seed
ls||-m|none|gnu+bsd seed
ls||-n|none|gnu+bsd seed
ls||-o|none|gnu+bsd seed
ls||-p|none|gnu+bsd seed
ls||-q|none|gnu+bsd seed
ls||-r|none|gnu+bsd seed
ls||-R|none|gnu+bsd seed
ls||-s|none|gnu+bsd seed
ls||-S|none|gnu+bsd seed
ls||-t|none|gnu+bsd seed
ls||-u|none|gnu+bsd seed
ls||-x|none|gnu+bsd seed
ls||--color|optional|gnu+bsd seed
diff||--normal|none|gnu+bsd seed
diff||-q|none|gnu+bsd seed
diff||--brief|none|gnu+bsd seed
diff||-s|none|gnu+bsd seed
diff||--report-identical-files|none|gnu+bsd seed
diff||-c|none|gnu+bsd seed
diff||-u|none|gnu+bsd seed
diff||-e|none|gnu+bsd seed
diff||--ed|none|gnu+bsd seed
diff||-n|none|gnu+bsd seed
diff||--rcs|none|gnu+bsd seed
diff||-y|none|gnu+bsd seed
diff||--side-by-side|none|gnu+bsd seed
diff||--suppress-common-lines|none|gnu+bsd seed
diff||-p|none|gnu+bsd seed
diff||--show-c-function|none|gnu+bsd seed
diff||-t|none|gnu+bsd seed
diff||--expand-tabs|none|gnu+bsd seed
diff||-T|none|gnu+bsd seed
diff||--initial-tab|none|gnu+bsd seed
diff||-r|none|gnu+bsd seed
diff||--recursive|none|gnu+bsd seed
diff||--no-dereference|none|gnu+bsd seed
diff||-N|none|gnu+bsd seed
diff||--new-file|none|gnu+bsd seed
diff||--unidirectional-new-file|none|gnu+bsd seed
diff||--ignore-file-name-case|none|gnu+bsd seed
diff||--no-ignore-file-name-case|none|gnu+bsd seed
diff||-i|none|gnu+bsd seed
diff||--ignore-case|none|gnu+bsd seed
diff||-b|none|gnu+bsd seed
diff||--ignore-space-change|none|gnu+bsd seed
diff||-w|none|gnu+bsd seed
diff||--ignore-all-space|none|gnu+bsd seed
diff||-B|none|gnu+bsd seed
diff||--ignore-blank-lines|none|gnu+bsd seed
diff||-a|none|gnu+bsd seed
diff||--text|none|gnu+bsd seed
diff||--strip-trailing-cr|none|gnu+bsd seed
diff||-d|none|gnu+bsd seed
diff||--minimal|none|gnu+bsd seed
diff||--speed-large-files|none|gnu+bsd seed
diff||--help|none|gnu+bsd seed
diff||--version|none|gnu+bsd seed
diff||-C|required|gnu+bsd seed
diff||-U|required|gnu+bsd seed
diff||-W|required|gnu+bsd seed
diff||--width|required|gnu+bsd seed
diff||-F|required|gnu+bsd seed
diff||--show-function-line|required|gnu+bsd seed
diff||--label|required|gnu+bsd seed
diff||--tabsize|required|gnu+bsd seed
diff||-x|required|gnu+bsd seed
diff||--exclude|required|gnu+bsd seed
diff||-S|required|gnu+bsd seed
diff||--starting-file|required|gnu+bsd seed
diff||-I|required|gnu+bsd seed
diff||--ignore-matching-lines|required|gnu+bsd seed
diff||-D|required|gnu+bsd seed
diff||--ifdef|required|gnu+bsd seed
diff||--color|optional|gnu+bsd seed
shasum||-b|none|gnu+bsd (shasum page; the GNU sha256sum page agrees) seed
shasum||--binary|none|gnu+bsd (shasum page; the GNU sha256sum page agrees) seed
shasum||-t|none|gnu+bsd (shasum page; the GNU sha256sum page agrees) seed
shasum||--text|none|gnu+bsd (shasum page; the GNU sha256sum page agrees) seed
shasum||-c|none|gnu+bsd (shasum page; the GNU sha256sum page agrees) seed
shasum||--check|none|gnu+bsd (shasum page; the GNU sha256sum page agrees) seed
shasum||--tag|none|gnu+bsd (shasum page; the GNU sha256sum page agrees) seed
shasum||--ignore-missing|none|gnu+bsd (shasum page; the GNU sha256sum page agrees) seed
shasum||--quiet|none|gnu+bsd (shasum page; the GNU sha256sum page agrees) seed
shasum||--status|none|gnu+bsd (shasum page; the GNU sha256sum page agrees) seed
shasum||--strict|none|gnu+bsd (shasum page; the GNU sha256sum page agrees) seed
shasum||-w|none|gnu+bsd (shasum page; the GNU sha256sum page agrees) seed
shasum||--warn|none|gnu+bsd (shasum page; the GNU sha256sum page agrees) seed
shasum||--help|none|gnu+bsd (shasum page; the GNU sha256sum page agrees) seed
shasum||--version|none|gnu+bsd (shasum page; the GNU sha256sum page agrees) seed
shasum||-a|required|shasum page (-a, --algorithm 1, 224, 256 ...); reference consumer _bmad-output/gate-adjudication/s303/story6-authoring.repair.md:86, 192 uses
sha256sum||-b|none|gnu+bsd seed
sha256sum||--binary|none|gnu+bsd seed
sha256sum||-t|none|gnu+bsd seed
sha256sum||--text|none|gnu+bsd seed
sha256sum||-c|none|gnu+bsd seed
sha256sum||--check|none|gnu+bsd seed
sha256sum||--tag|none|gnu+bsd seed
sha256sum||--ignore-missing|none|gnu+bsd seed
sha256sum||--quiet|none|gnu+bsd seed
sha256sum||--status|none|gnu+bsd seed
sha256sum||--strict|none|gnu+bsd seed
sha256sum||-w|none|gnu+bsd seed
sha256sum||--warn|none|gnu+bsd seed
sha256sum||--help|none|gnu+bsd seed
sha256sum||--version|none|gnu+bsd seed
basename||-a|none|gnu+bsd seed
basename||-s|required|gnu+bsd seed
echo||-n|none|gnu+bsd (-e and -E are GNU only, so off) seed
test||-f|none|test primary, gnu+bsd seed
test||-d|none|test primary, gnu+bsd seed
test||-e|none|test primary, gnu+bsd seed
test||-s|none|test primary, gnu+bsd seed
test||-z|none|test primary, gnu+bsd seed
test||-n|none|test primary, gnu+bsd seed
test||-eq|none|test primary, gnu+bsd seed
test||-ne|none|test primary, gnu+bsd seed
test||-lt|none|test primary, gnu+bsd seed
test||-le|none|test primary, gnu+bsd seed
test||-gt|none|test primary, gnu+bsd seed
test||-ge|none|test primary, gnu+bsd seed
test||-r|none|test primary, gnu+bsd seed
test||-x|none|test primary, gnu+bsd seed
test||-L|none|test primary, gnu+bsd seed
git|log|-p|none|git man seed
git|log|-u|none|git man seed
git|log|--patch|none|git man seed
git|log|-s|none|git man seed
git|log|--no-patch|none|git man seed
git|log|--raw|none|git man seed
git|log|--patch-with-raw|none|git man seed
git|log|--patch-with-stat|none|git man seed
git|log|--compact-summary|none|git man seed
git|log|--numstat|none|git man seed
git|log|--shortstat|none|git man seed
git|log|--cumulative|none|git man seed
git|log|--summary|none|git man seed
git|log|-z|none|git man seed
git|log|--name-only|none|git man seed
git|log|--name-status|none|git man seed
git|log|--no-color|none|git man seed
git|log|--no-renames|none|git man seed
git|log|--rename-empty|none|git man seed
git|log|--no-rename-empty|none|git man seed
git|log|--check|none|git man seed
git|log|--full-index|none|git man seed
git|log|--binary|none|git man seed
git|log|-D|none|git man seed
git|log|--irreversible-delete|none|git man seed
git|log|--pickaxe-all|none|git man seed
git|log|--pickaxe-regex|none|git man seed
git|log|-R|none|git man seed
git|log|--no-relative|none|git man seed
git|log|-a|none|git man seed
git|log|--text|none|git man seed
git|log|--ignore-cr-at-eol|none|git man seed
git|log|--ignore-space-at-eol|none|git man seed
git|log|-b|none|git man seed
git|log|--ignore-space-change|none|git man seed
git|log|-w|none|git man seed
git|log|--ignore-all-space|none|git man seed
git|log|--ignore-blank-lines|none|git man seed
git|log|-W|none|git man seed
git|log|--function-context|none|git man seed
git|log|--no-ext-diff|none|git man seed
git|log|--no-textconv|none|git man seed
git|log|--minimal|none|git man seed
git|log|--patience|none|git man seed
git|log|--histogram|none|git man seed
git|log|--indent-heuristic|none|git man seed
git|log|--no-indent-heuristic|none|git man seed
git|log|--no-prefix|none|git man seed
git|log|--default-prefix|none|git man seed
git|log|--find-copies-harder|none|git man seed
git|log|--ws-error-highlight|required|git man; measured consuming a separate value on this git seed
git|log|-l|required|git man; measured consuming a separate value on this git seed
git|log|--diff-filter|required|git man; measured consuming a separate value on this git seed
git|log|-S|required|git man; measured consuming a separate value on this git seed
git|log|-G|required|git man; measured consuming a separate value on this git seed
git|log|--find-object|required|git man; measured consuming a separate value on this git seed
git|log|-I|required|git man; measured consuming a separate value on this git seed
git|log|--ignore-matching-lines|required|git man; measured consuming a separate value on this git seed
git|log|--inter-hunk-context|required|git man; measured consuming a separate value on this git seed
git|log|--diff-algorithm|required|git man; measured consuming a separate value on this git seed
git|log|--src-prefix|required|git man; measured consuming a separate value on this git seed
git|log|--dst-prefix|required|git man; measured consuming a separate value on this git seed
git|log|--line-prefix|required|git man; measured consuming a separate value on this git seed
git|log|--max-depth|required|git man; measured consuming a separate value on this git seed
git|log|-U|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--unified|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--stat|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|-X|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--dirstat|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--dirstat-by-file|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--submodule|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--color|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--word-diff|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--color-words|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--abbrev|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|-B|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--break-rewrites|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|-M|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--find-renames|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|-C|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--find-copies|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--relative|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--ignore-submodules|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|show|-p|none|git man seed
git|show|-u|none|git man seed
git|show|--patch|none|git man seed
git|show|-s|none|git man seed
git|show|--no-patch|none|git man seed
git|show|--raw|none|git man seed
git|show|--patch-with-raw|none|git man seed
git|show|--patch-with-stat|none|git man seed
git|show|--compact-summary|none|git man seed
git|show|--numstat|none|git man seed
git|show|--shortstat|none|git man seed
git|show|--cumulative|none|git man seed
git|show|--summary|none|git man seed
git|show|-z|none|git man seed
git|show|--name-only|none|git man seed
git|show|--name-status|none|git man seed
git|show|--no-color|none|git man seed
git|show|--no-renames|none|git man seed
git|show|--rename-empty|none|git man seed
git|show|--no-rename-empty|none|git man seed
git|show|--check|none|git man seed
git|show|--full-index|none|git man seed
git|show|--binary|none|git man seed
git|show|-D|none|git man seed
git|show|--irreversible-delete|none|git man seed
git|show|--pickaxe-all|none|git man seed
git|show|--pickaxe-regex|none|git man seed
git|show|-R|none|git man seed
git|show|--no-relative|none|git man seed
git|show|-a|none|git man seed
git|show|--text|none|git man seed
git|show|--ignore-cr-at-eol|none|git man seed
git|show|--ignore-space-at-eol|none|git man seed
git|show|-b|none|git man seed
git|show|--ignore-space-change|none|git man seed
git|show|-w|none|git man seed
git|show|--ignore-all-space|none|git man seed
git|show|--ignore-blank-lines|none|git man seed
git|show|-W|none|git man seed
git|show|--function-context|none|git man seed
git|show|--no-ext-diff|none|git man seed
git|show|--no-textconv|none|git man seed
git|show|--minimal|none|git man seed
git|show|--patience|none|git man seed
git|show|--histogram|none|git man seed
git|show|--indent-heuristic|none|git man seed
git|show|--no-indent-heuristic|none|git man seed
git|show|--no-prefix|none|git man seed
git|show|--default-prefix|none|git man seed
git|show|--find-copies-harder|none|git man seed
git|show|--ws-error-highlight|required|git man; measured consuming a separate value on this git seed
git|show|-l|required|git man; measured consuming a separate value on this git seed
git|show|--diff-filter|required|git man; measured consuming a separate value on this git seed
git|show|-S|required|git man; measured consuming a separate value on this git seed
git|show|-G|required|git man; measured consuming a separate value on this git seed
git|show|--find-object|required|git man; measured consuming a separate value on this git seed
git|show|-I|required|git man; measured consuming a separate value on this git seed
git|show|--ignore-matching-lines|required|git man; measured consuming a separate value on this git seed
git|show|--inter-hunk-context|required|git man; measured consuming a separate value on this git seed
git|show|--diff-algorithm|required|git man; measured consuming a separate value on this git seed
git|show|--src-prefix|required|git man; measured consuming a separate value on this git seed
git|show|--dst-prefix|required|git man; measured consuming a separate value on this git seed
git|show|--line-prefix|required|git man; measured consuming a separate value on this git seed
git|show|--max-depth|required|git man; measured consuming a separate value on this git seed
git|show|-U|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|show|--unified|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|show|--stat|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|show|-X|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|show|--dirstat|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|show|--dirstat-by-file|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|show|--submodule|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|show|--color|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|show|--word-diff|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|show|--color-words|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|show|--abbrev|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|show|-B|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|show|--break-rewrites|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|show|-M|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|show|--find-renames|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|show|-C|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|show|--find-copies|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|show|--relative|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|show|--ignore-submodules|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|diff|-p|none|git man seed
git|diff|-u|none|git man seed
git|diff|--patch|none|git man seed
git|diff|-s|none|git man seed
git|diff|--no-patch|none|git man seed
git|diff|--raw|none|git man seed
git|diff|--patch-with-raw|none|git man seed
git|diff|--patch-with-stat|none|git man seed
git|diff|--compact-summary|none|git man seed
git|diff|--numstat|none|git man seed
git|diff|--shortstat|none|git man seed
git|diff|--cumulative|none|git man seed
git|diff|--summary|none|git man seed
git|diff|-z|none|git man seed
git|diff|--name-only|none|git man seed
git|diff|--name-status|none|git man seed
git|diff|--no-color|none|git man seed
git|diff|--no-renames|none|git man seed
git|diff|--rename-empty|none|git man seed
git|diff|--no-rename-empty|none|git man seed
git|diff|--check|none|git man seed
git|diff|--full-index|none|git man seed
git|diff|--binary|none|git man seed
git|diff|-D|none|git man seed
git|diff|--irreversible-delete|none|git man seed
git|diff|--pickaxe-all|none|git man seed
git|diff|--pickaxe-regex|none|git man seed
git|diff|-R|none|git man seed
git|diff|--no-relative|none|git man seed
git|diff|-a|none|git man seed
git|diff|--text|none|git man seed
git|diff|--ignore-cr-at-eol|none|git man seed
git|diff|--ignore-space-at-eol|none|git man seed
git|diff|-b|none|git man seed
git|diff|--ignore-space-change|none|git man seed
git|diff|-w|none|git man seed
git|diff|--ignore-all-space|none|git man seed
git|diff|--ignore-blank-lines|none|git man seed
git|diff|-W|none|git man seed
git|diff|--function-context|none|git man seed
git|diff|--no-ext-diff|none|git man seed
git|diff|--no-textconv|none|git man seed
git|diff|--minimal|none|git man seed
git|diff|--patience|none|git man seed
git|diff|--histogram|none|git man seed
git|diff|--indent-heuristic|none|git man seed
git|diff|--no-indent-heuristic|none|git man seed
git|diff|--no-prefix|none|git man seed
git|diff|--default-prefix|none|git man seed
git|diff|--find-copies-harder|none|git man seed
git|diff|--ws-error-highlight|required|git man; measured consuming a separate value on this git seed
git|diff|-l|required|git man; measured consuming a separate value on this git seed
git|diff|--diff-filter|required|git man; measured consuming a separate value on this git seed
git|diff|-S|required|git man; measured consuming a separate value on this git seed
git|diff|-G|required|git man; measured consuming a separate value on this git seed
git|diff|--find-object|required|git man; measured consuming a separate value on this git seed
git|diff|-I|required|git man; measured consuming a separate value on this git seed
git|diff|--ignore-matching-lines|required|git man; measured consuming a separate value on this git seed
git|diff|--inter-hunk-context|required|git man; measured consuming a separate value on this git seed
git|diff|--diff-algorithm|required|git man; measured consuming a separate value on this git seed
git|diff|--src-prefix|required|git man; measured consuming a separate value on this git seed
git|diff|--dst-prefix|required|git man; measured consuming a separate value on this git seed
git|diff|--line-prefix|required|git man; measured consuming a separate value on this git seed
git|diff|--max-depth|required|git man; measured consuming a separate value on this git seed
git|diff|-U|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|diff|--unified|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|diff|--stat|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|diff|-X|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|diff|--dirstat|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|diff|--dirstat-by-file|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|diff|--submodule|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|diff|--color|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|diff|--word-diff|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|diff|--color-words|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|diff|--abbrev|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|diff|-B|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|diff|--break-rewrites|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|diff|-M|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|diff|--find-renames|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|diff|-C|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|diff|--find-copies|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|diff|--relative|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|diff|--ignore-submodules|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|diff|--cached|none|git man seed
git|diff|--staged|none|git man seed
git|diff|--merge-base|none|git man seed
git|diff|--exit-code|none|git man seed
git|diff|--quiet|none|git man seed
git|diff|--ita-invisible-in-index|none|git man seed
git|log|--abbrev-commit|none|git man seed
git|log|--no-abbrev-commit|none|git man seed
git|log|--oneline|none|git man seed
git|log|--no-expand-tabs|none|git man seed
git|log|--no-notes|none|git man seed
git|log|-m|none|git man seed
git|log|-c|none|git man seed
git|log|--cc|none|git man seed
git|log|--dd|none|git man seed
git|log|--no-diff-merges|none|git man seed
git|log|-t|none|git man seed
git|log|--encoding|required|git man; measured consuming a separate value on this git seed
git|log|--diff-merges|required|git man; measured consuming a separate value on this git seed
git|log|--pretty|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--format|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--expand-tabs|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--notes|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|show|--abbrev-commit|none|git man seed
git|show|--no-abbrev-commit|none|git man seed
git|show|--oneline|none|git man seed
git|show|--no-expand-tabs|none|git man seed
git|show|--no-notes|none|git man seed
git|show|-m|none|git man seed
git|show|-c|none|git man seed
git|show|--cc|none|git man seed
git|show|--dd|none|git man seed
git|show|--no-diff-merges|none|git man seed
git|show|-t|none|git man seed
git|show|--encoding|required|git man; measured consuming a separate value on this git seed
git|show|--diff-merges|required|git man; measured consuming a separate value on this git seed
git|show|--pretty|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|show|--format|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|show|--expand-tabs|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|show|--notes|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--all-match|none|git man seed
git|log|--invert-grep|none|git man seed
git|log|-i|none|git man seed
git|log|--regexp-ignore-case|none|git man seed
git|log|--basic-regexp|none|git man seed
git|log|-E|none|git man seed
git|log|--extended-regexp|none|git man seed
git|log|-F|none|git man seed
git|log|--fixed-strings|none|git man seed
git|log|-P|none|git man seed
git|log|--perl-regexp|none|git man seed
git|log|--merges|none|git man seed
git|log|--no-merges|none|git man seed
git|log|--no-min-parents|none|git man seed
git|log|--no-max-parents|none|git man seed
git|log|--first-parent|none|git man seed
git|log|--exclude-first-parent-only|none|git man seed
git|log|--remove-empty|none|git man seed
git|log|--not|none|git man seed
git|log|--all|none|git man seed
git|log|--ignore-missing|none|git man seed
git|log|--single-worktree|none|git man seed
git|log|--cherry|none|git man seed
git|log|--cherry-pick|none|git man seed
git|log|--cherry-mark|none|git man seed
git|log|--left-only|none|git man seed
git|log|--right-only|none|git man seed
git|log|--left-right|none|git man seed
git|log|--boundary|none|git man seed
git|log|--follow|none|git man seed
git|log|--simplify-by-decoration|none|git man seed
git|log|--show-pulls|none|git man seed
git|log|--full-history|none|git man seed
git|log|--dense|none|git man seed
git|log|--sparse|none|git man seed
git|log|--simplify-merges|none|git man seed
git|log|--date-order|none|git man seed
git|log|--author-date-order|none|git man seed
git|log|--topo-order|none|git man seed
git|log|--reverse|none|git man seed
git|log|--do-walk|none|git man seed
git|log|--relative-date|none|git man seed
git|log|--parents|none|git man seed
git|log|--children|none|git man seed
git|log|--graph|none|git man seed
git|log|--no-decorate|none|git man seed
git|log|--clear-decorations|none|git man seed
git|log|--source|none|git man seed
git|log|--mailmap|none|git man seed
git|log|--no-mailmap|none|git man seed
git|log|--use-mailmap|none|git man seed
git|log|--no-use-mailmap|none|git man seed
git|log|--full-diff|none|git man seed
git|log|--log-size|none|git man seed
git|log|-g|none|git man seed
git|log|--walk-reflogs|none|git man seed
git|log|--reflog|none|git man seed
git|log|--no-abbrev|none|git man seed
git|log|-n|required|git man; measured consuming a separate value on this git seed
git|log|--max-count|required|git man; measured consuming a separate value on this git seed
git|log|--skip|required|git man; measured consuming a separate value on this git seed
git|log|--since|required|git man; measured consuming a separate value on this git seed
git|log|--after|required|git man; measured consuming a separate value on this git seed
git|log|--since-as-filter|required|git man; measured consuming a separate value on this git seed
git|log|--until|required|git man; measured consuming a separate value on this git seed
git|log|--before|required|git man; measured consuming a separate value on this git seed
git|log|--author|required|git man; measured consuming a separate value on this git seed
git|log|--committer|required|git man; measured consuming a separate value on this git seed
git|log|--grep|required|git man; measured consuming a separate value on this git seed
git|log|--grep-reflog|required|git man; measured consuming a separate value on this git seed
git|log|--glob|required|git man; measured consuming a separate value on this git seed
git|log|--exclude|required|git man; measured consuming a separate value on this git seed
git|log|--date|required|git man; measured consuming a separate value on this git seed
git|log|--decorate-refs|required|git man; measured consuming a separate value on this git seed
git|log|--decorate-refs-exclude|required|git man; measured consuming a separate value on this git seed
git|log|-L|required|git man; measured consuming a separate value on this git seed
git|log|--min-parents|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--max-parents|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--branches|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--tags|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--remotes|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--ancestry-path|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--no-walk|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--show-linear-break|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|--decorate|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|log|-NUM|num|git man: -<number> limits the commits shown seed
git|grep|-a|none|git man seed
git|grep|--text|none|git man seed
git|grep|-I|none|git man seed
git|grep|--no-textconv|none|git man seed
git|grep|-i|none|git man seed
git|grep|--ignore-case|none|git man seed
git|grep|-w|none|git man seed
git|grep|--word-regexp|none|git man seed
git|grep|-v|none|git man seed
git|grep|--invert-match|none|git man seed
git|grep|-h|none|git man seed
git|grep|-H|none|git man seed
git|grep|--full-name|none|git man seed
git|grep|-E|none|git man seed
git|grep|--extended-regexp|none|git man seed
git|grep|-G|none|git man seed
git|grep|--basic-regexp|none|git man seed
git|grep|-P|none|git man seed
git|grep|--perl-regexp|none|git man seed
git|grep|-F|none|git man seed
git|grep|--fixed-strings|none|git man seed
git|grep|-n|none|git man seed
git|grep|--line-number|none|git man seed
git|grep|--column|none|git man seed
git|grep|-l|none|git man seed
git|grep|--files-with-matches|none|git man seed
git|grep|--name-only|none|git man seed
git|grep|-L|none|git man seed
git|grep|--files-without-match|none|git man seed
git|grep|-z|none|git man seed
git|grep|--null|none|git man seed
git|grep|-o|none|git man seed
git|grep|--only-matching|none|git man seed
git|grep|-c|none|git man seed
git|grep|--count|none|git man seed
git|grep|-q|none|git man seed
git|grep|--quiet|none|git man seed
git|grep|--all-match|none|git man seed
git|grep|--and|none|git man seed
git|grep|--or|none|git man seed
git|grep|--not|none|git man seed
git|grep|-r|none|git man seed
git|grep|--recursive|none|git man seed
git|grep|--no-recursive|none|git man seed
git|grep|--no-color|none|git man seed
git|grep|--break|none|git man seed
git|grep|--heading|none|git man seed
git|grep|-p|none|git man seed
git|grep|--show-function|none|git man seed
git|grep|-W|none|git man seed
git|grep|--function-context|none|git man seed
git|grep|--cached|none|git man seed
git|grep|--untracked|none|git man seed
git|grep|--exclude-standard|none|git man seed
git|grep|--no-exclude-standard|none|git man seed
git|grep|--recurse-submodules|none|git man seed
git|grep|--max-depth|required|git man; measured consuming a separate value on this git seed
git|grep|-A|required|git man; measured consuming a separate value on this git seed
git|grep|--after-context|required|git man; measured consuming a separate value on this git seed
git|grep|-B|required|git man; measured consuming a separate value on this git seed
git|grep|--before-context|required|git man; measured consuming a separate value on this git seed
git|grep|-C|required|git man; measured consuming a separate value on this git seed
git|grep|--context|required|git man; measured consuming a separate value on this git seed
git|grep|-m|required|git man; measured consuming a separate value on this git seed
git|grep|--max-count|required|git man; measured consuming a separate value on this git seed
git|grep|--threads|required|git man; measured consuming a separate value on this git seed
git|grep|-e|required|git man; measured consuming a separate value on this git seed
git|grep|--color|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|ls-files|-c|none|git man seed
git|ls-files|--cached|none|git man seed
git|ls-files|-d|none|git man seed
git|ls-files|--deleted|none|git man seed
git|ls-files|-m|none|git man seed
git|ls-files|--modified|none|git man seed
git|ls-files|-o|none|git man seed
git|ls-files|--others|none|git man seed
git|ls-files|-i|none|git man seed
git|ls-files|--ignored|none|git man seed
git|ls-files|-s|none|git man seed
git|ls-files|--stage|none|git man seed
git|ls-files|-u|none|git man seed
git|ls-files|--unmerged|none|git man seed
git|ls-files|-k|none|git man seed
git|ls-files|--killed|none|git man seed
git|ls-files|--resolve-undo|none|git man seed
git|ls-files|-z|none|git man seed
git|ls-files|-t|none|git man seed
git|ls-files|-v|none|git man seed
git|ls-files|-f|none|git man seed
git|ls-files|--directory|none|git man seed
git|ls-files|--no-empty-directory|none|git man seed
git|ls-files|--eol|none|git man seed
git|ls-files|--deduplicate|none|git man seed
git|ls-files|--exclude-standard|none|git man seed
git|ls-files|--error-unmatch|none|git man seed
git|ls-files|--full-name|none|git man seed
git|ls-files|--recurse-submodules|none|git man seed
git|ls-files|--debug|none|git man seed
git|ls-files|--sparse|none|git man seed
git|ls-files|-x|required|git man; measured consuming a separate value on this git seed
git|ls-files|--exclude|required|git man; measured consuming a separate value on this git seed
git|ls-files|--with-tree|required|git man; measured consuming a separate value on this git seed
git|ls-files|--format|required|git man; measured consuming a separate value on this git seed
git|ls-files|--abbrev|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|rev-parse|--verify|none|git man seed
git|rev-parse|-q|none|git man seed
git|rev-parse|--quiet|none|git man seed
git|rev-parse|--sq|none|git man seed
git|rev-parse|--not|none|git man seed
git|rev-parse|--symbolic|none|git man seed
git|rev-parse|--symbolic-full-name|none|git man seed
git|rev-parse|--all|none|git man seed
git|rev-parse|--git-dir|none|git man seed
git|rev-parse|--git-common-dir|none|git man seed
git|rev-parse|--absolute-git-dir|none|git man seed
git|rev-parse|--show-toplevel|none|git man seed
git|rev-parse|--show-superproject-working-tree|none|git man seed
git|rev-parse|--shared-index-path|none|git man seed
git|rev-parse|--is-inside-git-dir|none|git man seed
git|rev-parse|--is-inside-work-tree|none|git man seed
git|rev-parse|--is-bare-repository|none|git man seed
git|rev-parse|--is-shallow-repository|none|git man seed
git|rev-parse|--show-cdup|none|git man seed
git|rev-parse|--show-prefix|none|git man seed
git|rev-parse|--show-ref-format|none|git man seed
git|rev-parse|--local-env-vars|none|git man seed
git|rev-parse|--revs-only|none|git man seed
git|rev-parse|--no-revs|none|git man seed
git|rev-parse|--flags|none|git man seed
git|rev-parse|--no-flags|none|git man seed
git|rev-parse|--end-of-options|none|git man seed
git|rev-parse|--default|required|git man; measured consuming a separate value on this git seed
git|rev-parse|--prefix|required|git man; measured consuming a separate value on this git seed
git|rev-parse|--git-path|required|git man; measured consuming a separate value on this git seed
git|rev-parse|--resolve-git-dir|required|git man; measured consuming a separate value on this git seed
git|rev-parse|--short|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|rev-parse|--abbrev-ref|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|rev-parse|--branches|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|rev-parse|--tags|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|rev-parse|--remotes|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|rev-parse|--show-object-format|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|rev-parse|--output-object-format|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|rev-parse|--glob|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|rev-parse|--exclude|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|rev-parse|--exclude-hidden|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|rev-parse|--disambiguate|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|rev-parse|--path-format|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|rev-parse|--since|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|rev-parse|--after|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|rev-parse|--until|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|rev-parse|--before|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|cat-file|-t|none|git man seed
git|cat-file|-s|none|git man seed
git|cat-file|-e|none|git man seed
git|cat-file|-p|none|git man seed
git|cat-file|--mailmap|none|git man seed
git|cat-file|--no-mailmap|none|git man seed
git|cat-file|--use-mailmap|none|git man seed
git|cat-file|--no-use-mailmap|none|git man seed
git|cat-file|--batch-all-objects|none|git man seed
git|cat-file|--buffer|none|git man seed
git|cat-file|--unordered|none|git man seed
git|cat-file|--follow-symlinks|none|git man seed
git|cat-file|--no-filter|none|git man seed
git|cat-file|-Z|none|git man seed
git|cat-file|-z|none|git man seed
git|cat-file|--batch|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|cat-file|--batch-check|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|cat-file|--batch-command|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|cat-file|--filter|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|describe|--all|none|git man seed
git|describe|--tags|none|git man seed
git|describe|--contains|none|git man seed
git|describe|--exact-match|none|git man seed
git|describe|--long|none|git man seed
git|describe|--no-match|none|git man seed
git|describe|--no-exclude|none|git man seed
git|describe|--always|none|git man seed
git|describe|--first-parent|none|git man seed
git|describe|--debug|none|git man seed
git|describe|--match|required|git man; measured consuming a separate value on this git seed
git|describe|--exclude|required|git man; measured consuming a separate value on this git seed
git|describe|--dirty|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|describe|--broken|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|describe|--abbrev|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|describe|--candidates|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|status|-s|none|git man seed
git|status|--short|none|git man seed
git|status|-b|none|git man seed
git|status|--branch|none|git man seed
git|status|--show-stash|none|git man seed
git|status|--long|none|git man seed
git|status|-v|none|git man seed
git|status|--verbose|none|git man seed
git|status|-z|none|git man seed
git|status|--no-column|none|git man seed
git|status|--ahead-behind|none|git man seed
git|status|--no-ahead-behind|none|git man seed
git|status|--renames|none|git man seed
git|status|--no-renames|none|git man seed
git|status|--porcelain|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|status|-u|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|status|--untracked-files|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|status|--ignore-submodules|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|status|--ignored|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|status|--column|optional|git man; a separate value is NOT consumed on this git, so attached only seed
git|status|--find-renames|optional|git man; a separate value is NOT consumed on this git, so attached only seed
find||!|none|gnu+bsd seed
find||(|none|gnu+bsd seed
find||)|none|gnu+bsd seed
OPT_TABLE_END
OPT_TABLE=$'\n'"$OPT_TABLE"$'\n'
# THE END-OF-OPTIONS LIST, `cmd|sub|citation`: the per-command property `endopts`. It is a list of
# its own, not `--` rows in OPT_TABLE, because the corpus sweep counts every OPT_TABLE row against
# option words and a `--` row would read FLAGGED forever. A command listed here treats EVERY word
# after a standalone `--` as an operand: it counts toward the operand count (so uniq's second
# operand is still refused) and fills awk's program or sed's script operand exactly as an ordinary
# operand does. A command NOT listed keeps the refusal of a dash word after `--`. A row is entered
# only for a parser that is getopt-style and ends option parsing at `--`, with the man-page line
# that says so on this machine. getopt(3) line 38: "the option '--' (double dash) ... causes getopt()
# to signal the end of argument processing"; a STANDARDS line citing POSIX binds a utility to the
# utility syntax guidelines, whose Guideline 10 is that same rule. Left OFF, each for want of a
# citable line or because `--` does not end its options: find (find(1) BUGS: its expression
# follows `--`), test (no options, a grammar), echo (prints `--` as text), awk, head and sha256sum
# (no man line on this machine), rg (not installed), and git show, rev-parse, cat-file, describe
# (no `[--] <pathspec>` form in their synopsis; rev-parse echoes `--`).
read -r -d '' OPT_ENDOPTS <<'OPT_ENDOPTS_END' || true
grep||man grep STANDARDS (POSIX.1-2008); getopt(3) line 38
sort||man sort STANDARDS (POSIX.1-2008); getopt(3) line 38
uniq||man uniq STANDARDS (POSIX.1-2001); getopt(3) line 38
cut||man cut STANDARDS (POSIX.2); getopt(3) line 38
wc||man wc STANDARDS (POSIX.1-2001); getopt(3) line 38
comm||man comm STANDARDS (POSIX.2); getopt(3) line 38
nl||man nl STANDARDS (POSIX.1-2001); getopt(3) line 38
cat||man cat STANDARDS (POSIX.2); getopt(3) line 38
diff||man diff STANDARDS (POSIX.1-2008); getopt(3) line 38
tail||man tail STANDARDS (POSIX.2 superset); getopt(3) line 38
ls||man ls STANDARDS (POSIX.1-2001, POSIX.1-2008); getopt(3) line 38
sed||man sed STANDARDS (POSIX.2 superset); getopt(3) line 38
basename||man basename STANDARDS (POSIX.2); getopt(3) line 38
dirname||man dirname STANDARDS (POSIX.2, the basename page); getopt(3) line 38
printf||man printf: "-- must be used before format" when the format begins with a dash
shasum||shasum parses with Perl Getopt::Long (/usr/bin/shasum line 23); man Getopt::Long: insert a double dash "--" to stop option processing
git|grep|git help grep: SYNOPSIS "[--] [<pathspec>...]"; OPTIONS "--  Signals the end of options; the rest of the parameters are <pathspec> limiters."
git|log|git help log: SYNOPSIS "git log [<options>] [<revision-range>] [[--] <path>...]"
git|diff|git help diff: SYNOPSIS "git diff [<options>] [<commit>] [--] [<path>...]"
git|ls-files|git help ls-files: SYNOPSIS "[--] [<file>...]"; OPTIONS "--  Do not interpret any more arguments as options."
git|status|git help status: SYNOPSIS "git status [<options>] [--] [<pathspec>...]"
OPT_ENDOPTS_END
OPT_ENDOPTS=$'\n'"$OPT_ENDOPTS"$'\n'
# THE NEVER SET, `cmd|sub|token|why`: options that write a file, run a program, or never return.
# It grants nothing. A NEVER token is refused with the write/exec message, and at startup any
# NEVER token that is ALSO a table row stops the validator with exit 2, so a row cannot widen the
# table onto a known exec vector without every run failing.
read -r -d '' OPT_NEVER <<'OPT_NEVER_END' || true
find||-exec|runs a command
find||-execdir|runs a command
find||-ok|runs a command
find||-okdir|runs a command
find||-delete|deletes files
find||-fprint|writes a file
find||-fprint0|writes a file
find||-fprintf|writes a file
find||-fls|writes a file
sort||-o|writes a file
sort||--output|writes a file
sort||--compress-program|runs a program
sort||-T|writes temporary files to a named directory
sort||--temporary-directory|writes temporary files to a named directory
sed||-i|rewrites the input file
sed||-I|rewrites the input file
sed||--in-place|rewrites the input file
sed||-f|reads the script from a file this checker cannot see
sed||--file|reads the script from a file this checker cannot see
awk||-f|reads the program from a file this checker cannot see
awk||--file|reads the program from a file this checker cannot see
awk||-E|reads the program from a file this checker cannot see
awk||--exec|reads the program from a file this checker cannot see
awk||-i|loads a source file
awk||--include|loads a source file
awk||-l|loads a shared library
awk||--load|loads a shared library
rg||--pre|runs a program for every file searched
rg||--pre-glob|selects files for --pre
rg||-z|runs external decompression programs
rg||--search-zip|runs external decompression programs
diff||-l|pipes output through pr
diff||--paginate|pipes output through pr
tail||-f|never returns
tail||-F|never returns
tail||--follow|never returns
git|grep|-O|opens the matches in a pager program
git|grep|--open-files-in-pager|opens the matches in a pager program
git|grep|--textconv|runs a textconv filter program
git|diff|--ext-diff|runs an external diff program
git|diff|--textconv|runs a textconv filter program
git|diff|--output|writes a file
git|diff|--no-index|compares paths outside the repository
git|show|--ext-diff|runs an external diff program
git|show|--textconv|runs a textconv filter program
git|show|--output|writes a file
git|show|--show-signature|runs gpg
git|log|--ext-diff|runs an external diff program
git|log|--textconv|runs a textconv filter program
git|log|--output|writes a file
git|log|--show-signature|runs gpg
git|cat-file|--textconv|runs a textconv filter program
git|cat-file|--filters|runs external filter programs
OPT_NEVER_END
OPT_NEVER=$'\n'"$OPT_NEVER"$'\n'
never_hits=""
while IFS='|' read -r nv_c nv_s nv_t _; do
  [ -n "$nv_c" ] || continue
  case "$OPT_TABLE" in *$'\n'"$nv_c|$nv_s|$nv_t|"*) never_hits="$never_hits $nv_c${nv_s:+ $nv_s} $nv_t;" ;; esac
done <<< "$OPT_NEVER"
if [ -n "$never_hits" ]; then
  printf 'REFUSED: the option table admits a NEVER-set option (%s ), which writes a file or runs a program; no verdict until the row is removed.\n' "$never_hits" >&2
  exit 2
fi

LIST_ONLY=0; WALK_ALL=0; EXPLAIN=0
USAGE="usage: $0 [--list] [--all] <file-or-dir>...
       $0 --explain-cmd '<command>' | --explain-cmd -   (stdin: one '<id><TAB><command>' per line)"
EXPLAIN_ARG=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --list) LIST_ONLY=1; shift ;;
    --all)  WALK_ALL=1; shift ;;
    --explain-cmd) [ "$#" -ge 2 ] || { echo "$USAGE" >&2; exit 2; }
                   EXPLAIN=1; EXPLAIN_ARG="$2"; shift 2 ;;
    -h|--help) echo "$USAGE" >&2; exit 2 ;;
    *) break ;;
  esac
done
[ "$EXPLAIN" = 1 ] || [ "$#" -ge 1 ] || { echo "$USAGE" >&2; exit 2; }
# AI_DLC_DERIV_SUPERSEDE_FROM names the ONE real file a single masked argument stands for (the
# header's write-time rule). With two arguments, or a directory, which argument it stands for is
# not stated, so it is refused rather than applied to all of them.
SUP_FROM="${AI_DLC_DERIV_SUPERSEDE_FROM:-}"
if [ -n "$SUP_FROM" ]; then
  if [ "$#" -ne 1 ] || [ ! -f "$1" ] || [ ! -r "$SUP_FROM" ] || [ ! -f "$SUP_FROM" ]; then
    printf 'REFUSED: AI_DLC_DERIV_SUPERSEDE_FROM=%s needs exactly one file argument and a readable file to read supersession from; no verdict.\n' "$SUP_FROM" >&2
    exit 2
  fi
fi

fails=0; checked=0; blocks=0; files_seen=0; unrun=0

fail() { printf 'FAIL (%s): %s\n' "$1" "$2" >&2; fails=$((fails + 1)); }

# A command is refused if it can chain, redirect, substitute or background. Pipes are
# permitted because a count is routinely `grep ... | wc -l`, and every element of the
# pipe is checked against the allowlist independently.
#
# THE OPTION BOUNDARY IS AN ALLOWLIST OF EXACT TOKENS, AND ITS INPUT IS THE ARGV BASH BUILDS.
# Until BL-728 this function DENIED a hand-kept list of known writers (`find -delete`, `sed -i`,
# `sort -o`, `git grep -O` ...) and admitted every other option, reading the words with
# `for w in $seg`. Both halves of that failed open:
#
#   - THE WORDS WERE TEXT, NOT ARGV (B1, measured against bash). `for w in $seg` keeps quote
#     characters and performs no brace or glob expansion, so `sort -S 1 '--compress-program=x'
#     d.txt` and `sort -S 1 {--compress-program=x,} d.txt` reached sort as `--compress-program=x`
#     while the scan saw a quoted word and a brace word; and a bare `$2` expanded, under the eval
#     inside run_pair, to run_pair's own positional. So argv now comes from BASH: per segment, in
#     a subshell under `cd "$AI_DLC_ROOT"` with the eval's own shell options, `set --`, then
#     `eval "set -- $seg"` and `printf '%s\0' "$#" "$@"`. Every reader below -- the option
#     walker, the sed grammar, the awk program check, and the corpus sweep through
#     `--explain-cmd` -- reads that NUL argv and nothing else, so none of them can disagree with
#     bash about where a word starts or ends. Running that eval is safe because every test that
#     refuses a substitution runs BEFORE it: the metacharacter ban, the backtick, `$'`, and the
#     expansion test in the quote scan. What is left for bash to do is quote removal, brace and
#     glob expansion and a tilde, and none of those runs anything.
#   - A DENYLIST CANNOT BE COMPLETE. `sort --compress-program` was on no list, and it RUNS the
#     program it names. So each allowlisted command now carries the list of options it may use,
#     and anything not on that list is refused.
#
# EXACT MATCH, NEVER PREFIX. GNU getopt_long and git's parse-options both accept any unique
# abbreviation of a long option -- measured on this machine: `sort --rev`, `grep --cou` and
# `git log --onel` all run as the full option. Accepting abbreviations would mean knowing every
# option the TOOL knows, including the ones this table leaves out on purpose, to know what an
# abbreviation resolves to. So a token is accepted only when it is byte-identical to a row, and
# `sort --compress` is refused as unlisted although GNU sort runs it as `--compress-program`.
#
# THE WALKER. Short options are read letter by letter; the first letter whose row takes a value
# takes the rest of the word, or the next word when nothing is left. A long option takes its value
# after `=`, or -- arity `required` only -- the next word. Arity `optional` takes ONLY an attached
# value and never the next word. A standalone `--` ends the options. A dash word after it is an
# OPERAND for a command on the end-of-options list (OPT_ENDOPTS, with the man-page line for each),
# and is REFUSED for every other command. Every other dash word anywhere in argv is an option:
# GNU tools permute, so `grep x f -c` counts. sed and uniq do not: on this machine both stop at
# their first operand, so a dash word after it is refused, and sed's script is that operand
# whenever it precedes any `-e`. `-<digits>` is accepted only where the command has a
# `-NUM` row. `find` and `test` take whole-word primaries, never clusters. `uniq` takes ONE
# operand, because it WRITES its second.
#
# ARITY IS THE FAIL-OPEN SURFACE, SO AN UNSURE ARITY IS ENTERED AS `optional`. A walker that
# consumes the next word as a VALUE where the tool reads it as an OPTION has acquitted an option it
# never checked: `git log --format --output=x`, with `--format` read as taking a value, admits
# `--output`. `optional` costs nothing in that direction, because the next word is then checked as
# an option in its own right. Every git row marked `required` was measured to consume a separate
# value on this machine's git; `--format`, `--pretty`, `-U`, `--unified`, `--min-parents`,
# `--max-parents`, describe's `--abbrev`/`--candidates`, cat-file's `--filter` and rev-parse's
# `=value` options did not, so they are `optional`.
#
# THE TABLE (OPT_TABLE, below) IS DATA: one row per token, `cmd|sub|token|arity|note`, `sub` empty
# except for git. THE REVIEW RULE FOR A ROW: it carries the arity BOTH man pages give, GNU and BSD;
# an option one page lacks, or whose arity the two disagree on, stays off; its note names the
# source. `seed` marks a row the corpus sweep (`core/fixtures/artifact-derivations/fp-sweep.sh`,
# driving `--explain-cmd`) has not yet counted. A row whose count is 0 needs a reason in its note,
# and a row whose count falls to 0 is FLAGGED by the sweep, never removed by it. `rg` is not
# installed on the machine the table was built on, so its rows come from the GNU (Debian) man page
# text alone, and each says so.
#
# THE NEVER SET (OPT_NEVER, below) is the hand-written list of options that write a file or run a
# program. It grants nothing -- the table alone does that -- and it has two jobs: a NEVER token is
# refused with the "writes a file or runs a command" message rather than as merely unlisted, and AT
# STARTUP the validator exits 2 when any NEVER token is also a table row, so a row that widens the
# table onto a known exec vector fails every run instead of shipping.
cmd_is_safe() { # $1 command -> 0 safe, 1 refused (reason in REFUSED)
  local c="$1" seg segs scan_rc=0 first_kind="" first_why=""
  REFUSED=""
  # THE BACKTICK IS NOT IN THIS SUBSTRING BAN; IT IS TESTED IN THE QUOTE SCAN BELOW. Inside
  # single quotes bash reads a backtick as a literal, so banning the character anywhere
  # refused `grep -c -F 'a`b' d.txt`, a correct derivation bash runs with no substitution.
  # Unquoted or inside double quotes it IS command substitution, and only the scan knows
  # which of those it is.
  case "$c" in
    *';'*|*'&'*|*'>'*|*'<'*|*'$('*|*'${'*|*'||'*)
      REFUSED="it can chain, redirect or substitute (one of ; & > < \$( \${ ||)"
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
  # A `$` THAT BASH EXPANDS IS REFUSED HERE, AND ONLY ONE THAT BASH EXPANDS. Outside single quotes
  # and unescaped, a `$` expands when the next character is a name character, a digit, one of the
  # special parameters `@ * # ? $ ! -`, or `[` (`$[ ]` arithmetic); outside double quotes `$"`
  # is a locale string too. Each class was measured against bash with a benign `printf`; every
  # other `$` -- at the end of a word, before a closing `"`, before `.` `/` `:` `=` `%` `^` `,` `+`
  # `]` `}` `)` `~` or a blank -- printed literally, so `grep -c "^x$" f`, the regex end-anchor the
  # reference corpus carries, is admitted. The test exists because the argv below is built by an
  # eval, and an expansion is the one thing that eval would do that the derivation text does not
  # say. `${` and `$(` are NOT in the class, deliberately: the substring ban above refuses both
  # before this scan runs, so a branch here could never decide a verdict, and a dead branch in a
  # security check is a trap for whoever later loosens that ban.
  #
  # The quote characters are built with `sprintf` rather than written literally, because a
  # literal `'` inside a single-quoted awk program needs `'"'"'` and that escaping is
  # itself a place this has to be got right.
  segs="$(printf '%s' "$c" | awk '
    BEGIN { SQ = sprintf("%c", 39); DQ = sprintf("%c", 34); BS = sprintf("%c", 92); HASH = sprintf("%c", 35); BT = sprintf("%c", 96)
            DX = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789@*#?$!-[" }
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
        # A DOLLAR THAT EXPANDS: the class above, plus a double quote outside double quotes.
        if (ch == "$" && sq == 0 && i < n && (index(DX, substr($0, i+1, 1)) > 0 || (dq == 0 && substr($0, i+1, 1) == DQ))) exit 6
        # Inside single quotes a backslash is literal; everywhere else it escapes the
        # next character, so that character can never open, close or be a delimiter.
        if (ch == BS && sq == 0) { out = out ch; i++; if (i <= n) out = out substr($0, i, 1); prev = "x"; continue }
        # A BACKTICK OUTSIDE SINGLE QUOTES IS COMMAND SUBSTITUTION, unquoted and inside
        # double quotes alike, so it is refused here, where the quote state is known. It
        # sits after the backslash branch because an escaped backtick is a literal, and
        # before the toggles because its own quote state is the one that decides.
        if (ch == BT && sq == 0) exit 5
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
    5) REFUSED="it carries a backtick outside single quotes, which bash runs as command substitution"
       return 1 ;;
    6) REFUSED="it carries a \$ that bash expands -- a parameter (\$NAME, \$1, \$@, \$? ...),
      \$[...] arithmetic or a \$\"...\" string -- outside single quotes, so what it runs depends
      on the shell's state and not on its text; a \$ bash leaves literal, such as the end-anchor
      in \"^x\$\", is admitted"
       return 1 ;;
    *) REFUSED="it carries an unbalanced quote, so it cannot be run or safely parsed"
       return 1 ;;
  esac
  # Every segment of the pipeline must itself pass. Under --explain-cmd every segment is walked
  # whatever an earlier one decided, so the sweep sees every option the corpus uses.
  while IFS= read -r seg; do
    if ! seg_check "$seg"; then
      [ -n "$first_kind" ] || { first_kind="$SEG_KIND"; first_why="$SEG_WHY"; }
      [ "$EXPLAIN" = 1 ] || break
    fi
  done <<< "$segs"
  [ -n "$first_kind" ] || return 0
  refusal_text "$first_kind" "$first_why"
  return 1
}

refusal_text() { # $1 kind  $2 what -> REFUSED
  case "$1" in
    BAD) REFUSED="'$2' is not on the read-only allowlist
      ($ALLOWED_CMDS)" ;;
    BADGIT) REFUSED="'git $2' is not a read-only git subcommand
      ($ALLOWED_GIT_SUB)" ;;
    BADOPT) REFUSED="'$2' writes a file or runs a command
      -- the allowlist admits read-only PROGRAMS, not every option they carry, and this
      block is re-run automatically at write time" ;;
    UNLISTED) REFUSED="'$2' is not an option this checker admits -- each allowed command
      carries an exact list of the options it may use, read from both man pages, and a form
      not on that list is refused rather than guessed at" ;;
    *) REFUSED="bash could not split it into words (\`set -- <segment>\` failed), so what it
      would run is unknown" ;;
  esac
}

# SEG_KIND/SEG_WHY hold a segment's FIRST refusal. seg_refuse returns 1 (stop) except under
# --explain-cmd, where the walk goes on so every word is classified.
EXPLAIN_ID="-"
seg_refuse() { # $1 kind  $2 what
  [ -n "$SEG_KIND" ] || { SEG_KIND="$1"; SEG_WHY="$2"; }
  [ "$EXPLAIN" = 1 ]
}
explain_word() { # $1 class  $2 token  $3 the argv word -- reads seg_check's first/sub
  if [ "$EXPLAIN" = 1 ]; then
    printf '%s\tWORD\t%s\t%s\t%s\t%s\t%q\n' "$EXPLAIN_ID" "$first" "$sub" "$1" "$2" "$3"
  fi
}
explain_argv() { # prints seg_check's argv, each word shell-quoted
  if [ "$EXPLAIN" = 1 ]; then
    local k=0 q s=""
    while [ "$k" -lt "$n" ]; do printf -v q '%q' "${SA[k]}"; s="$s $q"; k=$((k + 1)); done
    printf '%s\tARGV\t%s\n' "$EXPLAIN_ID" "${s# }"
  fi
}

opt_arity() { # $1 cmd  $2 sub  $3 token -> OPT_AR: none|required|optional|num, or "" (unlisted)
  local k="$1|$2|$3"
  case "$OPT_TABLE" in
    *$'\n'"$k|none|"*) OPT_AR=none ;;
    *$'\n'"$k|required|"*) OPT_AR=required ;;
    *$'\n'"$k|optional|"*) OPT_AR=optional ;;
    *$'\n'"$k|num|"*) OPT_AR=num ;;
    *) OPT_AR="" ;;
  esac
}
opt_never() { # $1 cmd  $2 sub  $3 token -> OPT_NV: why it is never allowed, or ""
  local k="$1|$2|$3"
  case "$OPT_NEVER" in
    *$'\n'"$k|"*) OPT_NV="${OPT_NEVER#*$'\n'"$k|"}"; OPT_NV="${OPT_NV%%$'\n'*}" ;;
    *) OPT_NV="" ;;
  esac
}
opt_endopts() { # $1 cmd  $2 sub -> OPT_EO: 1 when a word after a standalone `--` is an operand
  case "$OPT_ENDOPTS" in *$'\n'"$1|$2|"*) OPT_EO=1 ;; *) OPT_EO=0 ;; esac
}
opt_check() { # $1 cmd  $2 sub  $3 token  $4 argv word -> OPT_AR; 1 = refused
  OPT_AR=""
  opt_never "$1" "$2" "$3"
  if [ -n "$OPT_NV" ]; then
    explain_word never "$3" "$4"
    seg_refuse BADOPT "$1${2:+ $2} $3" || return 1
    return 0
  fi
  opt_arity "$1" "$2" "$3"
  if [ -z "$OPT_AR" ]; then
    explain_word unlisted "$3" "$4"
    seg_refuse UNLISTED "$1${2:+ $2} $3" || return 1
    return 0
  fi
  explain_word opt "$3" "$4"
  return 0
}
opt_take() { # $1 option token  $2 its value -- a sed `-e` value is a script the grammar reads
  explain_word val "$1" "$2"
  if [ "$first" = "sed" ]; then
    case "$1" in -e) SCR[NSCR]="$2"; NSCR=$((NSCR + 1)) ;; esac
  fi
}

# AWK TAKES A PROGRAM AS ITS FIRST OPERAND, read here from argv. `system` with any whitespace
# before its parenthesis runs a shell; a gawk indirect call `@name(...)` can reach a function by a
# name held in a variable, so a program carrying one is refused too. `-f` is in the NEVER set,
# because a program in a file is a program this check cannot see.
AWK_SYS_RE='system[[:space:]]*\('
AWK_AT_RE='@[A-Za-z_][A-Za-z_0-9]*[[:space:]]*\('

seg_check() { # $1 one pipeline segment -> 0 allowed | 1 refused (SEG_KIND, SEG_WHY)
  local seg="$1" w n=0 i=1 first="" sub="" gdir groot gres gcom_root gcom_dir pend="" endop=0 nops=0
  local mode=cluster nm j ch rest sed_why isop OPT_EO=0
  SEG_KIND=""; SEG_WHY=""; SN=""; SA=(); SCR=(); NSCR=0; PROG=""; PROG_SET=0; SEDOP=""; SEDOP_SET=0
  # THE ARGV, FROM BASH (the header says why). `set --` first, so no positional of this function
  # can reach the segment; a segment bash cannot parse is refused, never guessed at.
  ( cd "$AI_DLC_ROOT" && set -- && eval "set -- $seg" && printf '%s\0' "$#" "$@" ) > "$TMP_ARGV" 2>/dev/null \
    || { SEG_KIND=PARSE; SEG_WHY="$seg"; return 1; }
  while IFS= read -r -d '' w; do
    if [ -z "$SN" ]; then SN="$w"; else SA[n]="$w"; n=$((n + 1)); fi
  done < "$TMP_ARGV"
  # The count bash printed must equal the words read, or the record was cut short.
  case "$SN" in ''|*[!0-9]*) SEG_KIND=PARSE; SEG_WHY="$seg"; return 1 ;; esac
  [ "$n" -eq "$SN" ] || { SEG_KIND=PARSE; SEG_WHY="$seg"; return 1; }
  [ "$n" -gt 0 ] || return 0
  explain_argv
  first="${SA[0]}"
  case "$first" in ''|*[[:space:]]*) SEG_KIND=BAD; SEG_WHY="$first"; return 1 ;; esac
  case " $ALLOWED_CMDS " in
    *" $first "*) ;;
    *) SEG_KIND=BAD; SEG_WHY="$first"; return 1 ;;
  esac
  set -- "${SA[@]}"
  if [ "$first" = "git" ]; then
    # EXACTLY ONE LEADING `-C <dir>` IS SKIPPED, AND ONLY TO A DIRECTORY OF THIS SAME
    # REPOSITORY. Reading the subcommand as word 2 refused `git -C sub rev-parse ...`,
    # a correct read-only derivation. The skip carries three conditions, all required:
    #   (i)   <dir> is a plain relative path, `^[A-Za-z0-9_.][A-Za-z0-9_./-]*$` -- no
    #         quote, glob, `~` or leading `/` or `-`;
    #   (ii)  it canonicalises (`pwd -P`) to the physical root or below it;
    #   (iii) git there reports the SAME common dir as the root, which excludes a nested
    #         repo, a foreign repo and a bare one.
    # Two measurements are why each is there. A SECOND `-C` resolves relative to the
    # first, so a chain walked out of the root through a committed symlink: one `-C` is
    # what was asked for, and the second is refused. And a committed BARE clone carries
    # its `config` as ordinary files, so it travels by pull, and `git -C evil diff` ran
    # that config's `diff.external`. The common-dir probe itself runs with
    # safe.bareRepository=explicit, and so does the eval below, so no allowed git
    # command ever discovers an implicit bare repository.
    # `-C=dir`, a bare `-C`, `-c`, `--git-dir` and `--work-tree` are never skipped; they
    # land in the subcommand slot and fail the list there.
    sub="${2:-}"; i=2
      if [ "$sub" = "-C" ]; then
        gdir="${3:-}"; sub="${4:-}"; i=4
        [ "$sub" = "-C" ] && { SEG_KIND=BADGIT; SEG_WHY="-C $gdir -C"; return 1; }
        case "$gdir" in
          ''|[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.]*|*[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_./-]*)
            SEG_KIND=BADGIT; SEG_WHY="-C $gdir"; return 1 ;;
        esac
        groot="$(cd "$AI_DLC_ROOT" 2>/dev/null && pwd -P)" || groot=""
        gres="$(cd "$AI_DLC_ROOT/$gdir" 2>/dev/null && pwd -P)" || gres=""
        case "$gres" in
          "$groot"|"$groot"/*) [ -n "$groot" ] || gres="" ;;
          *) gres="" ;;
        esac
        [ -n "$gres" ] || { SEG_KIND=BADGIT; SEG_WHY="-C $gdir"; return 1; }
        gcom_root="$(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=explicit \
          git -C "$groot" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || gcom_root=""
        gcom_dir="$(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=explicit \
          git -C "$gres" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || gcom_dir=""
        if [ -z "$gcom_root" ] || [ "$gcom_root" != "$gcom_dir" ]; then
          SEG_KIND=BADGIT; SEG_WHY="-C $gdir"; return 1
        fi
      fi
    case "$sub" in ''|*[[:space:]]*) SEG_KIND=BADGIT; SEG_WHY="$sub"; return 1 ;; esac
    case " $ALLOWED_GIT_SUB " in
      *" $sub "*) ;;
      *) SEG_KIND=BADGIT; SEG_WHY="$sub"; return 1 ;;
    esac
  fi
  case "$first" in find|test) mode=word ;; esac
  opt_endopts "$first" "$sub"
  # THE OPTION WALK (the header's rules).
  while [ "$i" -lt "$n" ]; do
    w="${SA[i]}"; i=$((i + 1))
    if [ -n "$pend" ]; then
      opt_take "$pend" "$w"; pend=""; continue
    fi
    # SED AND UNIQ STOP READING OPTIONS AT THEIR FIRST OPERAND (BSD getopt, no permutation), so a
    # dash word after it -- a `-e`, a `-c`, a `--` -- is an operand to the tool and an option to a
    # permuting walker. The two readings disagree on what runs, so the word is refused.
    if [ "$nops" -gt 0 ] && [ "$endop" -eq 0 ] && { [ "$first" = sed ] || [ "$first" = uniq ]; }; then
      case "$w" in
        -?*) explain_word unlisted "$w" "$w"
             seg_refuse UNLISTED "$first $w after its first operand (sed and uniq stop reading options at their first operand, so the tool reads this word as an operand)" || return 1
             continue ;;
      esac
    fi
    if [ "$w" = "--" ] && [ "$endop" -eq 0 ]; then
      endop=1; explain_word end -- "$w"; continue
    fi
    # A dash word after `--` is an operand only on an end-of-options command; the next branch
    # refuses it everywhere else.
    isop=0
    case "$w" in -?*) ;; *) isop=1 ;; esac
    if [ "$endop" -eq 1 ] && [ "$OPT_EO" -eq 1 ]; then isop=1; fi
    case "$isop" in
      0) ;;
      *) nops=$((nops + 1)); explain_word operand "" "$w"
         if [ "$first" = "awk" ] && [ "$PROG_SET" -eq 0 ]; then PROG="$w"; PROG_SET=1
         elif [ "$first" = "sed" ] && [ "$SEDOP_SET" -eq 0 ]; then SEDOP="$w"; SEDOP_SET=1
         fi
         if [ "$first" = "uniq" ] && [ "$nops" -gt 1 ]; then
           seg_refuse BADOPT "uniq $w, a second operand, which uniq WRITES as its output file" || return 1
         fi
         continue ;;
    esac
    if [ "$endop" -eq 1 ]; then
      explain_word unlisted "$w" "$w"
      seg_refuse UNLISTED "$first${sub:+ $sub} -- $w (a dash word after a standalone --)" || return 1
      continue
    fi
    if [ "$mode" = word ] || [ "${w:0:2}" = "--" ]; then
      if [ "$mode" = word ]; then nm="$w"; else nm="${w%%=*}"; fi
      opt_check "$first" "$sub" "$nm" "$w" || return 1
      case "$OPT_AR" in
        required) if [ "$nm" != "$w" ]; then opt_take "$nm" "${w#*=}"; else pend="$nm"; fi ;;
        optional) [ "$nm" = "$w" ] || opt_take "$nm" "${w#*=}" ;;
        none|num) if [ "$nm" != "$w" ]; then seg_refuse UNLISTED "$first${sub:+ $sub} $w (it takes no value)" || return 1; fi ;;
      esac
      continue
    fi
    case "$w" in
      -*[!0-9]*) ;;
      *) opt_arity "$first" "$sub" "-NUM"
         if [ "$OPT_AR" = num ]; then explain_word num -NUM "$w"; continue; fi ;;
    esac
    j=1
    while [ "$j" -lt "${#w}" ]; do
      ch="${w:j:1}"
      opt_check "$first" "$sub" "-$ch" "$w" || return 1
      rest="${w:j+1}"
      case "$OPT_AR" in
        required) if [ -n "$rest" ]; then opt_take "-$ch" "$rest"; else pend="-$ch"; fi; break ;;
        optional) [ -z "$rest" ] || opt_take "-$ch" "$rest"; break ;;
      esac
      j=$((j + 1))  # the next letter of the cluster
    done
  done
  if [ -n "$pend" ]; then
    seg_refuse UNLISTED "$first${sub:+ $sub} $pend (it takes a value and none follows)" || return 1
  fi
  if [ "$first" = "awk" ] && [ "$PROG_SET" -eq 1 ]; then
    if [[ "$PROG" =~ $AWK_SYS_RE ]]; then seg_refuse BADOPT "awk system()" || return 1; fi
    if [[ "$PROG" =~ $AWK_AT_RE ]]; then seg_refuse BADOPT "awk @name() indirect call" || return 1; fi
  fi
  # AWK TAKES A PROGRAM AS ITS ARGUMENT, AND A BAR INSIDE THAT PROGRAM IS AN EXEC
  # VECTOR THIS CHECKER CANNOT TELL FROM AN ALTERNATION. `print ... | "cmd"` and
  # `"cmd" | getline` are awk's pipes to a shell -- arbitrary execution, needing no
  # shell metacharacter, so the ban above never sees them. Separating them from
  # `/alpha|beta/` needs a scan of awk's OWN string and regex grammar, so any bar in an
  # awk SEGMENT is refused -- which also covers the program word, so the program check
  # above carries no bar test of its own. It costs `awk -F'|' ...`, which is refused today.
  case "$first" in
    awk) case "$seg" in *'|'*) seg_refuse BADOPT "awk program containing a pipe" || return 1 ;; esac ;;
  esac
  # SED'S WRITING VERBS LIVE INSIDE THE SCRIPT ARGUMENT, WHERE NO OPTION-WORD SCAN CAN
  # REACH THEM: `w file`, `W file` and the `w file` FLAG on `s///`. Measured against bash on
  # this machine, in a sandbox, each creating its canary at exit 0 through the pre-fix validator:
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
  # Finding command position means consuming addresses, delimiters and bracket expressions --
  # `s/[/]/x/w f` has a LITERAL `/` inside `[...]`, and `/alpha/w/p` writes to a file named `/p`
  # while `/w/p` prints. So this consumes sed's grammar and FAILS CLOSED: a construct it cannot
  # parse is refused, never guessed at.
  #
  # THE SCRIPTS COME FROM THE WALKER, not from a tokeniser of this grammar's own: every `-e`
  # value, or, with no `-e`, the first operand. `-f`/`--file` and `-i` are in the NEVER set. `-e`
  # is not refused as a family: a `-e` CAN carry the verb (`sed -n -e 'w canary' -e 'p'`, and
  # `sed -n -e '1{w canary' -e '}'`, where a `-e` pair splits a brace block), but the reference
  # corpus carries 33 legitimate `-e` sed derivations against 0 `-f` ones, so EVERY `-e` value is
  # scanned, and `{`/`}` RESET command position rather than consuming a character.
  #
  # FALSE-POSITIVE SET: 0 incremental over 1656 sed segments of the reference consumer when this
  # grammar shipped (`fp-sweep.sh`); the sweep now measures the whole boundary through
  # `--explain-cmd` rather than this predicate alone.
  if [ "$first" = "sed" ]; then
    if [ "$NSCR" -eq 0 ] && [ "$SEDOP_SET" -eq 1 ]; then SCR[0]="$SEDOP"; NSCR=1; fi
    sed_why="$(sed_scripts_verdict)"
    if [ -n "$sed_why" ]; then
      seg_refuse BADOPT "sed -- $sed_why" || return 1
    fi
  fi
  [ -z "$SEG_KIND" ]
}

# The sed script grammar, as awk functions. Scripts reach it through the ENVIRONMENT, one
# variable each, so no byte of a script is re-tokenised or escape-processed on the way in.
SED_AWK='
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
}'
sed_scripts_verdict() { # SCR[0..NSCR) -> the first refusal reason on stdout, or nothing
  local k=0 a=()
  [ "$NSCR" -gt 0 ] || return 0
  while [ "$k" -lt "$NSCR" ]; do a[k]="AI_DLC_SEDSCR_$k=${SCR[k]}"; k=$((k + 1)); done
  env "${a[@]}" AI_DLC_SEDSCR_N="$NSCR" awk "$SED_AWK"'
    BEGIN { SQ = sprintf("%c", 39); DQ = sprintf("%c", 34); BS = sprintf("%c", 92); NL = sprintf("%c", 10)
      for (k = 0; k < ENVIRON["AI_DLC_SEDSCR_N"] + 0; k++) {
        v = script_verb(ENVIRON["AI_DLC_SEDSCR_" k])
        if (v == "") continue
        if (substr(v, 1, 1) == "?") print "a construct this checker cannot parse -- " substr(v, 2)
        else print v
        exit
      } }'
}

TMP_ARGV="$(mktemp)"; TMP_OUT="$(mktemp)"; TMP_EXP="$(mktemp)"; TMP_SENT="$(mktemp)"; TMP_RAN="$(mktemp)"
TMP_NEXP="$(mktemp)"; TMP_NOUT="$(mktemp)"; TMP_LIST="$(mktemp)"; TMP_EV="$(mktemp)"; TMP_SF="$(mktemp)"
trap 'rm -f "$TMP_ARGV" "$TMP_OUT" "$TMP_EXP" "$TMP_SENT" "$TMP_RAN" "$TMP_NEXP" "$TMP_NOUT" "$TMP_LIST" "$TMP_LIST.keep" "$TMP_EV" "$TMP_EV.sup" "$TMP_SF"' EXIT

# THE RECORD GRAMMAR, ONCE. The directory walk skips a record and check_file lets a record's
# later copy supersede an earlier one; both call this one awk function, so the two cannot
# disagree about what a record is. A record is a file whose parent directory is `s<digits>` and
# whose basename is one core writes as a review or repair record -- the walk's comment says why
# the grammar is exactly these names.
REC_AWK='
function is_record(parent, base) {
  if (parent !~ /^s[0-9]+$/) return 0
  return (base ~ /-adversarial-p[0-9]+\.md$/ || base ~ /-repair-p[0-9]+\.md$/ ||
          base == "requirements-party-repair.md" || base == "requirements-elicitation-repair.md" ||
          base == "requirements-elicitation.md")
}'
# The one-line stdin every derivation runs on -- run_pair's READS-STDIN arm says why.
STDIN_SENTINEL="AI-DLC-DERIVATION-STDIN-SENTINEL"
printf '%s\n' "$STDIN_SENTINEL" > "$TMP_SENT"

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
# THE INDENT AND SHED RULES ARE INLINE IN walk_blocks, NOT HELPER FUNCTIONS, because a helper
# reached through `$( )` forks once per line of every markdown file. Measured on a 2855-line
# consumer artifact, `--list` only: 0.05s before the rules existed, 2.61s with the rules in
# forked helpers, 0.10s inline -- and `ai-dlc-derivation-capture.sh` pays this on every Write
# or Edit of a fence-carrying file, which is the shape that gets a hook turned off.
is_opener() { # $1 line with its indent already shed -> 0 when it opens a ```derived block
  local b="$1"
  b="${b%"${b##*[![:blank:]]}"}"   # drop trailing blanks
  [ "$b" = '```derived' ]
}

# THE BLOCK GRAMMAR IS WALKED ONCE, AND EVERYTHING ELSE READS THE WALK. walk_blocks turns a file
# into one event per line it means something to:
#   O <line>               a ```derived opener          X <line>   its closer
#   C <line> - <command>   a `$ ` command line          E <line> <body>   a line of recorded output
#   U <line>               the opener of a block that is never closed (end of file)
# check_file collects the walk first and runs second, so the supersession pre-pass and the run
# read ONE parse: a `$ ` line is a "later copy" only when this walk calls it a command. A raw `$ `
# scan would also count one in a `text` fence, in prose, or as an output line indented deeper
# than its fence, and acquit a stale fence on a copy that never runs.
walk_blocks() { # $1 artifact path -> events on stdout; sets NCMD to the number of C events
  local f="$1" in_block=0 line body indent="" lineno=0 blockline=0
  NCMD=0
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    if [ "$in_block" -eq 0 ]; then
      indent="${line%%[![:blank:]]*}"          # the line's leading blanks, possibly empty
      if is_opener "${line#"$indent"}"; then
        in_block=1; blockline=$lineno; printf 'O %s \n' "$lineno"
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
      '```'*) printf 'X %s \n' "$lineno"; in_block=0; indent=""; continue ;;
    esac
    case "$body" in
      '$ '*) printf 'C %s - %s\n' "$lineno" "${body#\$ }"; NCMD=$((NCMD + 1)); continue ;;
    esac
    printf 'E %s %s\n' "$lineno" "$body"
  done < "$f"
  [ "$in_block" -eq 0 ] || printf 'U %s \n' "$blockline"
  return 0
}

check_file() { # $1 artifact path
  local f="$1" ev kind rest ln text cmd="" cmdline=0 csup="" d sf="$1" sev="$TMP_EV"
  files_seen=$((files_seen + 1))
  : > "$TMP_EXP"
  walk_blocks "$f" > "$TMP_EV"
  # UNDER AI_DLC_DERIV_SUPERSEDE_FROM the record identity and the later copies come from the real
  # file (the header's write-time rule). walk_blocks resets NCMD, so the gate below counts the
  # REAL file: a mask whose later copy was blanked carries one command and would skip the pass.
  # THE JOIN GUARD: every command event of the argument must be a command event of the real file,
  # same line, same bytes -- awk exits 3 on the first one that is not. The first input is told
  # apart by FILENAME, not FNR == NR, which an EMPTY first input turns true for the second.
  if [ -n "$SUP_FROM" ]; then
    sf="$SUP_FROM"; sev="$TMP_SF"
    walk_blocks "$sf" > "$TMP_SF"
    LC_ALL=C awk 'FILENAME == ARGV[1] { if (substr($0, 1, 2) == "C ") have[$0] = 1; next }
      substr($0, 1, 2) == "C " && !($0 in have) { bad = 1; exit 3 }
      END { if (bad) exit 3 }' "$TMP_SF" "$TMP_EV" \
      || { printf 'REFUSED: AI_DLC_DERIV_SUPERSEDE_FROM=%s does not carry the commands of %s at the same lines, so which of them a later copy supersedes is unknown; no verdict.\n' "$sf" "$f" >&2; exit 2; }
  fi
  # THE SUPERSESSION PRE-PASS (the header's rule). Only a file with two commands can hold a
  # repeat, so a one-command file costs no fork; `is_record` decides inside the awk, so a live
  # document passes through unchanged. A record's command whose LAST copy is a later line is
  # rewritten `C <line> <that later line> <command>`, and run_pair skips it.
  if [ "$NCMD" -ge 2 ]; then
    d="${sf%/*}"; [ "$d" = "$sf" ] && d="."
    case "$d" in .|'') d="$PWD" ;; esac
    # LC_ALL=C: the key is the command's BYTES, and a record carrying a byte its locale cannot
    # decode must not abort the pre-pass.
    LC_ALL=C awk -v par="${d##*/}" -v bn="${sf##*/}" "$REC_AWK"'
      BEGIN { rec = is_record(par, bn) }
      FNR == NR { if (substr($0, 1, 2) == "C ") { r = substr($0, 3); i = index(r, " "); ln = substr(r, 1, i - 1); c = substr(r, i + 3); last[c] = ln }; next }
      rec && substr($0, 1, 2) == "C " {
        r = substr($0, 3); i = index(r, " "); ln = substr(r, 1, i - 1); c = substr(r, i + 3)
        if (last[c] != ln) { print "C " ln " " last[c] " " c; next }
      }
      { print }' "$sev" "$TMP_EV" > "$TMP_EV.sup" && mv "$TMP_EV.sup" "$TMP_EV" \
      || { printf 'REFUSED: could not read which commands in %s are re-derived later, so its derivations were never run; no verdict. Re-run once the fault is gone.\n' "$f" >&2; exit 2; }
  fi
  while IFS= read -r ev; do
    kind="${ev%% *}"; rest="${ev#* }"; ln="${rest%% *}"; text="${rest#* }"
    case "$kind" in
      O) blocks=$((blocks + 1)); cmd=""; : > "$TMP_EXP" ;;
      C) [ -n "$cmd" ] && run_pair "$f" "$cmdline" "$cmd" "$csup"
         csup="${text%% *}"; [ "$csup" = "-" ] && csup=""
         cmd="${text#* }"; cmdline=$ln; : > "$TMP_EXP" ;;
      E) [ -n "$cmd" ] && printf '%s\n' "$text" >> "$TMP_EXP" ;;
      X) [ -n "$cmd" ] && run_pair "$f" "$cmdline" "$cmd" "$csup"
         cmd=""; : > "$TMP_EXP" ;;
      U) fail "GRAMMAR" "$f:$ln opens a \`\`\`derived block that is never closed." ;;
    esac
  done < "$TMP_EV"
}

run_pair() { # $1 file  $2 line  $3 command  $4 the later line that supersedes it, or empty
  #            (expected output is in $TMP_EXP)
  local f="$1" ln="$2" c="$3" sup="${4:-}" rc
  if [ "$LIST_ONLY" -eq 1 ]; then
    checked=$((checked + 1))
    printf '  %s:%s  %s\n' "$f" "$ln" "$c"
    return
  fi
  # A SUPERSEDED command is neither run nor counted: the OK line's count is of commands that ran.
  if [ -n "$sup" ]; then
    printf 'SUPERSEDED: %s:%s by %s:%s\n' "$f" "$ln" "$f" "$sup" >&2
    return
  fi
  checked=$((checked + 1))
  if ! cmd_is_safe "$c"; then
    fail "ALLOWLIST" "$f:$ln runs a command this checker refuses to execute:
      \$ $c
      $REFUSED
      A derivation is fenced \`\`\`derived to promise it is MACHINE-CHECKABLE. Rewrite it
      with the read-only tools above, or unfence it and accept that the adversarial pass
      must run it by hand -- which is the cost this block exists to avoid."
    return
  fi
  # A DERIVATION NEVER RUNS ON THIS SCRIPT'S STDIN, AND ONE THAT READS STDIN IS REFUSED.
  #
  # run_pair is called from inside check_file's `while read … done < "$TMP_EV"`, so an inherited
  # stdin is THE REST OF THE ARTIFACT'S PARSE (it was the artifact itself until check_file
  # collected first and ran second). Measured: a first derivation `grep -c WRONG` (no file
  # operand, recorded `1`) read the remaining text, matched its own recorded output, and
  # every later block went unchecked -- a file with a stale second derivation exited 0 with
  # `OK: 1 derivation(s)`, where `echo 1` in the same position gave exit 1, 1 stale of 2.
  #
  # Closing stdin alone is not enough: `grep -c X` over EOF prints 0, so a derivation that
  # derives from NOTHING would pass whenever its author recorded 0 -- a new false clean. So
  # the eval gets a SENTINEL on its stdin instead: fd 3 is opened on a one-line file, handed
  # to the command as fd 0 and closed as fd 3 inside it, and after the eval the PARENT reads
  # fd 3. The open file description -- and so its offset -- is shared with the child, so the
  # sentinel line reads back whole only when nothing consumed it. Anything else, EOF or a
  # partial line from a reader that took a few bytes, is READS-STDIN. This DETECTS BY
  # EXECUTION: no operand parser decides which command reads stdin (a static one was
  # measured at 2343 false flags in 6020 on the reference consumer's corpus), so a command
  # that does not read stdin is unaffected by construction, and a pipeline whose first stage
  # names a file -- `grep x f | wc -l` -- is not flagged, because the later stages read the
  # pipe and never the sentinel.
  #
  # FALSE-POSITIVE / FALSE-NEGATIVE SET, measured by the contract adversary over 22 stdin
  # and non-stdin shapes: 21 correct. The one known MISS is `diff f.txt -`, which reads its
  # `-` operand without moving the shared offset, so it is NOT caught; it is listed here
  # rather than claimed. A miss here is the pre-fix behaviour minus the swallowing -- later
  # blocks are still checked, because the sentinel file, never the artifact, is its stdin.
  #
  # A DERIVATION THE SUBSHELL NEVER RAN IS UNRUN, NEVER STALE. The output file is empty both
  # when the command printed nothing and when the command never executed -- a fork failure
  # (bash 3.2 abandons the subshell with 128) or a SIGKILL of the subshell (137) -- and an
  # empty actual against a recorded value reads as STALE. Measured on the base side of
  # `derivation-differential.sh`: a real break scored STALE-BOTH and the helper exited 0, a
  # silent false clear. The EXIT STATUS cannot separate the two: real derivations exit 128 on
  # a genuine git fatal (2 of the reference consumer's 303 on 5 files), and a SIGKILL leaves no
  # stderr to read. So the subshell writes eval's status to a MARKER after eval returns, with a
  # builtin that forks nothing, and the parent empties it first:
  #   - marker EMPTY: the subshell died before eval returned -- fork failure, the subshell
  #     killed, the `cd` failing, or a shell error in the derivation text that aborts the
  #     subshell outright (an arithmetic error, `$[1/0]`). Nothing was measured, so each
  #     stays UNRUN.
  # NO `set +u` BRACKET, because cmd_is_safe now refuses every `$` bash expands, so no name can
  # reach this eval: measured under `set -u` with real bash, `~`, `~nosuchuser`, brace and glob
  # words, `a[X]` and argument-position `((X))`/`[[ X ]]` all run with no unbound error (control,
  # same run: `printf "%s" "$X"` aborts); a backtick is refused by the quote scan, and awk and sed
  # program text is not bash's to expand. Should the scan's name class ever miss a name, the
  # walker's own `eval "set -- $seg"` in `seg_check` runs under the validator's `set -u` and
  # refuses the unset name ("bash could not split it into words"), a second line of defence
  # that mutant m-m7 in core/fixtures/artifact-derivations/run.sh proves.
  #   - marker 137 or 143 (SIGKILL, SIGTERM): the COMMAND was killed and the subshell survived.
  #     Both are delivered from outside the process; no allowlisted read-only tool raises either
  #     on itself. Other signal statuses stay verdicts: SIGPIPE (141) is what a pipeline whose
  #     reader stops early produces naturally under the inherited `pipefail`, and a tool that
  #     crashes (SIGSEGV, SIGABRT) did run, and its output is a fact about it.
  #     FALSE-POSITIVE SET of that arm: 0. Every derivation in the reference consumer's
  #     `_bmad-output/` (4645 markdown files, 5784 executed) exited 0, 1, 2, 128 (16 of them)
  #     or 141 (2); none exited 137 or 143.
  # Either shape makes the whole run exit 2 with the derivation named: no verdict, never a
  # STALE. The status used below is the MARKER's, because the subshell now ends on the marker
  # write and its own status is that write's.
  # THE WIDTH IS PINNED, so the verdict is a function of the tree and not of the invoker's
  # terminal: `git diff/log/show --stat` and `--compact-summary` scale their +/- graph to
  # COLUMNS even with no tty, so a block recorded at one width read STALE at another (measured:
  # a 200-line change recorded at COLUMNS=120 was STALE with COLUMNS unset). 80 is git's own
  # width when COLUMNS is unset, so a block recorded in a plain non-tty shell still matches. An
  # author recording at another width writes `--stat=<n>` or `--numstat`, which ignore COLUMNS.
  # SAFE.BAREREPOSITORY=EXPLICIT IS EXPORTED HERE, as it is on cmd_is_safe's `-C` common-dir
  # probe: a committed bare repository's `config` travels by pull, and an allowed git command
  # that discovered one implicitly ran its `diff.external`. With the setting, git refuses an
  # implicit bare repository rather than reading its config.
  # FOUR VARIABLES THAT ADD OPTIONS OR PROGRAMS NO DERIVATION SPELLS ARE UNSET HERE: GREP_OPTIONS
  # (old GNU grep prepends it), RIPGREP_CONFIG_PATH (rg reads flags from that file, `--pre`
  # included), GIT_EXTERNAL_DIFF and GIT_PAGER. The option allowlist judges the text; these would
  # change what the text runs.
  exec 3< "$TMP_SENT"
  : > "$TMP_RAN"
  ( cd "$AI_DLC_ROOT" && unset GREP_OPTIONS RIPGREP_CONFIG_PATH GIT_EXTERNAL_DIFF GIT_PAGER \
      && export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository \
      GIT_CONFIG_VALUE_0=explicit && export COLUMNS=80 && { eval "$c" <&3 3<&-; printf '%s\n' "$?" > "$TMP_RAN"; } ) > "$TMP_OUT" 2>/dev/null
  rc=""
  IFS= read -r rc < "$TMP_RAN" || rc=""
  case "$rc" in
    ''|*[!0-9]*|137|143)
      exec 3<&-
      printf 'UNRUN: %s:%s did not run to completion (%s), so it has no verdict:\n      $ %s\n' \
        "$f" "$ln" "$( [ -n "$rc" ] && printf 'the command exited %s, a signal it cannot raise on itself' "$rc" || printf 'no exit status was recorded -- the subshell died before the command returned')" "$c" >&2
      unrun=$((unrun + 1))
      return ;;
  esac
  local sent_back=""
  IFS= read -r sent_back <&3 || sent_back=""
  exec 3<&-
  if [ "$sent_back" != "$STDIN_SENTINEL" ]; then
    fail "READS-STDIN" "$f:$ln runs a command that reads its STANDARD INPUT:
      \$ $c
      A derivation runs with no input of its own, so a command that reads stdin derives
      from nothing -- \`grep -c X\` with no file prints a count of an empty stream, which
      matches a recorded 0 whatever the tree holds. Name the file it measures as an
      operand (\`grep -c X path/to/file\`) so the recorded output is a fact about the tree."
    return
  fi
  # A non-zero rc is only a failure when the block recorded output. `grep` exiting 1 on
  # NO HITS is a legitimate derivation of a negative, and the artifact records it as such.
  if [ "$rc" -ne 0 ] && [ ! -s "$TMP_OUT" ] && [ ! -s "$TMP_EXP" ]; then
    return
  fi
  # THE COMPARISON HAS THREE OUTCOMES, AND ONLY ONE OF THEM IS STALE. `diff` exits 0 on equal
  # inputs, 1 on different ones, and 2 or more when it could not compare at all. This line
  # used to be `if ! diff -q <(norm ...) <(norm ...)`, which folded the third outcome into the
  # second, and discarded the status of both `norm` producers besides. Three shapes, each
  # measured by forcing it with a PATH stub rather than by sampling:
  #
  #   - `diff` exiting 2 on a derivation that REPRODUCES scored FAIL (STALE), exit 1. The
  #     live cause is bash 3.2's `/dev/fd` process substitution: under concurrent workers
  #     `diff` intermittently reports `/dev/fd/63: Bad file descriptor` and exits 2, at
  #     roughly 0.15-0.4% of comparisons, measured on `diff <(printf ...) file`. At the
  #     derivation gate that is a remediator dispatched to repair a claim that is true.
  #   - `sed` failing inside `norm`, on a STALE derivation, scored OK, exit 0: both
  #     substitutions were empty, so they compared equal. A silent false clear.
  #   - `find` failing on a directory target (the walk below) scored "OK: 0 derivation(s)",
  #     exit 0, for the same reason. It is refused there.
  #
  # So both normalised sides are STAGED to files with each producer's status checked, `diff`
  # compares the two files -- `diff`, not `cmp`, because receipts stub `diff` on PATH -- and
  # its own status decides: 0 clean, 1 STALE with the message exactly as before, anything
  # else UNRUN. A failed `norm` is UNRUN too. UNRUN, not a new counter, because the capture
  # hook surfaces an exit 2 only through an `UNRUN:` or `REFUSED:` line, and
  # `derivation-differential.sh` refuses any status but 0 and 1: neither caller can read
  # this outcome as a verdict.
  local cmp_why="" drc=0
  if ! norm < "$TMP_EXP" > "$TMP_NEXP"; then
    cmp_why="normalising the recorded output failed"
  elif ! norm < "$TMP_OUT" > "$TMP_NOUT"; then
    cmp_why="normalising the actual output failed"
  else
    diff -q "$TMP_NEXP" "$TMP_NOUT" >/dev/null 2>&1 || drc=$?
    case "$drc" in
      0|1) ;;
      *) cmp_why="diff exited ${drc}, which is neither equal nor different" ;;
    esac
  fi
  if [ -n "$cmp_why" ]; then
    printf 'UNRUN: %s:%s ran, but its output could not be compared (%s), so it has no verdict:\n      $ %s\n' \
      "$f" "$ln" "$cmp_why" "$c" >&2
    unrun=$((unrun + 1))
    return
  fi
  if [ "$drc" -eq 1 ]; then
    fail "STALE" "$f:$ln records an output its own command no longer produces.
      \$ $c
      recorded: $(tr '\n' '/' < "$TMP_NEXP" | sed 's:/$::' | cut -c1-160)
      actual:   $(tr '\n' '/' < "$TMP_NOUT" | sed 's:/$::' | cut -c1-160)
      The claim this derivation supports is asserting a fact about the tree that is no
      longer true. Re-derive it and rewrite the sentence it supports -- a derivation is
      true about the tree at the moment it ran, and the usual way one goes stale is a
      later edit that moved what it was counting. A \`--stat\` graph is re-run at COLUMNS=80;
      record it at that width, or use a width-stable form: \`--stat=100\` or \`--numstat\`."
  fi
}

# --explain-cmd PRINTS WHAT THE BOUNDARY SEES AND RUNS NOTHING. For each command: one ARGV line per
# segment (bash's words, each `%q`-quoted), one WORD line per word with its class -- opt, val,
# operand, end, num, unlisted, never -- and a VERDICT line, OK or REFUSED with the refusal's first
# line. Every segment is walked whatever an earlier one decided, so the corpus sweep
# (`core/fixtures/artifact-derivations/fp-sweep.sh`) counts every option the corpus uses through
# this one grammar and has none of its own. `-` reads `<id><TAB><command>` lines from stdin and
# prefixes each output line with the id, so a corpus is one process.
explain_one() { # $1 id  $2 command
  EXPLAIN_ID="$1"
  if cmd_is_safe "$2"; then
    printf '%s\tVERDICT\tOK\n' "$1"
  else
    printf '%s\tVERDICT\tREFUSED\t%s\n' "$1" "$(printf '%s\n' "$REFUSED" | head -1)"
  fi
}
if [ "$EXPLAIN" = 1 ]; then
  if [ "$EXPLAIN_ARG" = "-" ]; then
    while IFS= read -r ex_line || [ -n "$ex_line" ]; do
      case "$ex_line" in *$'\t'*) ;; *) continue ;; esac
      explain_one "${ex_line%%$'\t'*}" "${ex_line#*$'\t'}"
    done
  else
    explain_one - "$EXPLAIN_ARG"
  fi
  exit 0
fi

for target in "$@"; do
  if [ -d "$target" ]; then
    # STAGED, WITH THE WALK'S STATUS READ. A `< <(find ...)` loop discards find's status, so a
    # walk that failed read as an empty directory and the run reported "OK: 0 derivation(s)",
    # exit 0 -- measured with a failing `find` stub. `pipefail` makes a failed `find` fail
    # this pipeline even though `sort` succeeds on the empty stream.
    find "$target" -type f -name '*.md' | sort > "$TMP_LIST"
    walk_rc=$?
    if [ "$walk_rc" -ne 0 ]; then
      printf 'REFUSED: could not list the markdown files under %s (the walk exited %s), so its derivations were never read; no verdict. Re-run once the fault is gone.\n' \
        "$target" "$walk_rc" >&2
      exit 2
    fi
    # A DIRECTORY TARGET WALKS THE DOCUMENTS A REPAIR CAN EDIT, NOT THE RECORDS NO REPAIR MAY.
    # `_gate-procedures.md` runs this over `s<N>/` after every repair join and sends exit 1
    # back to the remediator. The slot also holds records that are frozen once written: every
    # part, seat and section copy under `shards/`, every review and repair record, and the
    # earlier rounds' review and repair records. A command in one of those that a LATER edit moved stays stale
    # for the rest of the sprint, and no remediator may touch it, so the required run could
    # never pass. Measured on the reference consumer's s319 at the elicitation repair join:
    # 12 stale in 27 files, every one in a seat or part record, while the joined record and
    # the document were clean -- a check that always fails and is always waived.
    #
    # So the default walk skips, by PATH and never by content:
    #   - anything under a `shards/` directory BELOW the target (`s<N>/shards/<dir>/...`:
    #     adversarial and elicitation seats, repair parts and their section copies);
    #   - in a sprint slot (a directory named `s<digits>`), the record grammar core writes:
    #     `<artifact>-adversarial-p<M>.md`, `<artifact>-repair-p<M>.md` (which spells the
    #     gate, party and elicitation repair records too), `requirements-party-repair.md`,
    #     `requirements-elicitation-repair.md` and `requirements-elicitation.md`.
    # Everything else -- the documents, stories, epics, `carry-over-evaluation.md`, the Rule 24
    # input digests -- is walked. The digests are NOT frozen: measured on the reference
    # consumer, repair records in four sprints carry `edit:` lines into `discovery-context.md`,
    # `requirements-context.md` and `architecture-context.md`, two of them repairs of the
    # digest's own stale derivations.
    # A target that is itself under `shards/` is walked whole: the component is matched only
    # BELOW the target, so naming a shard dir never reads as "OK: 0". `--all` walks everything.
    # A FILE target is never excluded: `derivation-differential.sh` and the capture hook pass
    # files, and an excluded file there would empty the universe they count.
    #
    # THIS REDUCES THE SLOT RUN; IT DOES NOT MAKE IT PASS. Measured on the reference consumer's
    # s316/s317/s318 with this walk: 297 of 650, 598 of 1224 and 207 of 418 still stale, in two
    # places -- live documents (`carry-over-evaluation.md`, `architecture-context.md`, stories),
    # and record names outside the grammar above.
    #
    # THE GRAMMAR IS NOT WIDENED TO THOSE NAMES, and each was decided from core's step files, not
    # from the consumer's listing. A name is skipped only when core itself writes it as a review
    # or repair record AND no repair edits it. `requirements-repair-el.md`,
    # `requirements-repair-adv-p<M>.md`, `-cross-repair`, `-authoring`, `-repair-readiness-p<M>`
    # and the rest are written by no core step file (they appear in core only as quotations of
    # the consumer), so nothing establishes them as records. `changelog-<artifact>.md` IS core's
    # -- `_gate-procedures.md` "Where a changelog is written" -- but it is APPENDED to on every
    # pass, so it is live. `<artifact>-elicitation.md` (`stories-elicitation.md`,
    # `architecture-elicitation.md`) is not core's: core writes elicitation outside the
    # requirements subject to `shards/<artifact>-elicitation/`, and the consumer's repair parts
    # carry `edit:` lines INTO `stories-elicitation.md`, `stories-cross-repair.md` and
    # `architecture-authoring.md`, so those are documents a repair edits. Skipping them would
    # hide exactly what a repair is required to fix.
    #
    # NOT COVERED: frozenness is a property of WHEN the run happens, and a path cannot say it.
    # The record a repair has just joined is excluded with the rest; its fences were re-run by
    # the capture hook as they were written, and `--all` or a file target re-runs them here.
    # Worse, an excluded record CAN be a repair's subject: the consumer's s316
    # `shards/stories-fences-p<M>/` parts edit `stories-adversarial-p1.md`/`-p2.md`, and its
    # derivation-staleness repairs edit `gate-planning-repair-p<M>.md`. A slot run does not see
    # whether such a repair fixed them. The owed closure is a FILE-target run, after each join,
    # over the joined record plus every file its `edit:` lines name -- a `_gate-procedures.md`
    # step, not a change to this walk.
    # A legacy record name outside the grammar (`coe-adversarial-pass1.md`) is walked.
    if [ "$WALK_ALL" -eq 0 ]; then
      t_abs="$(cd "$target" && pwd)" || t_abs="$target"
      : > "$TMP_LIST.keep"
      split_counts="$(awk -v pre="${target%/}/" -v tbase="$(basename "$t_abs")" -v keep="$TMP_LIST.keep" "$REC_AWK"'
        { rel = (index($0, pre) == 1) ? substr($0, length(pre) + 1) : $0
          n = split(rel, C, "/"); base = C[n]
          parent = (n > 1) ? C[n - 1] : tbase
          why = ""
          for (i = 1; i < n; i++) if (C[i] == "shards") { why = "shards" }
          if (why == "" && is_record(parent, base)) why = "record"
          if (why == "") print > keep; else D[why]++
        }
        END { printf "%d %d\n", D["shards"], D["record"] }' "$TMP_LIST")" \
        || { printf 'REFUSED: could not split the walk of %s, so its derivations were never read; no verdict.\n' "$target" >&2; exit 2; }
      n_sh="${split_counts%% *}"; n_rec="${split_counts##* }"
      if [ "$((n_sh + n_rec))" -gt 0 ]; then
        printf 'EXCLUDED: %s frozen file(s) under %s not walked (%s under shards/, %s review/repair record(s)); pass --all to walk them.\n' \
          "$((n_sh + n_rec))" "$target" "$n_sh" "$n_rec"
      fi
      mv "$TMP_LIST.keep" "$TMP_LIST"
    fi
    while IFS= read -r f; do check_file "$f"; done < "$TMP_LIST"
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

# UNRUN OUTRANKS EVERY VERDICT. A run in which any derivation did not execute has not measured
# the corpus, so neither its OK nor its FAIL count is a statement about the tree; exit 1 would
# be read as "the tree moved", and `derivation-differential.sh` accepts only 0 and 1 as verdicts.
if [ "$unrun" -gt 0 ]; then
  printf 'REFUSED: %s derivation(s) did not run to completion (each named in an UNRUN line above); no verdict. %s stale or unrunnable finding(s) among the %s checked are not a verdict either. Re-run once the fault is gone.\n' \
    "$unrun" "$fails" "$checked" >&2
  exit 2
fi
if [ "$fails" -gt 0 ]; then
  printf 'FAIL: %s stale or unrunnable derivation(s) of %s checked in %s file(s).\n' \
    "$fails" "$checked" "$files_seen" >&2
  exit 1
fi
printf 'OK: %s derivation(s) in %s block(s) across %s file(s) reproduce at HEAD.\n' \
  "$checked" "$blocks" "$files_seen"
exit 0
