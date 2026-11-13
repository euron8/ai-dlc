#!/usr/bin/env bash
# reconcile-region: exempt — a sourced library of two functions with no output of its own; apply.sh turns its state into WORKLIST rows on the pull, after the report is approved.
# scaffold-ignore.sh -- whether a create-once scaffolded path is hidden by the consumer's ignore rules,
# and the remedy row text. SOURCED, never run: it holds only function definitions and comments, so a
# caller under `set -eu` can load it without a side effect, and CALL it too: no command whose non-zero
# exit is an answer runs bare (the `-q` exit is captured with `|| rc=$?`). apply.sh loads it from its own directory;
# install.sh can load the same file to make the same decision, so the decision and the remedy live in
# exactly one place.
#
# scaffold_ignore_state <root> <rel>
#   Prints exactly one line, `<state><TAB><prov>`, and returns 0. <prov> is `<src>:<line>:<pattern>`
#   as `git check-ignore -v` prints it before its TAB, or empty. <state> is one of:
#     untracked-ok   <root> is not a git checkout, or `check-ignore -q` exits 1 (not ignored, or tracked)
#     exact          ignored, and the deciding pattern is the exact path: the deliberate exit
#     ignored        ignored by any other pattern
#     unchecked:<rc> an exit other than 0 or 1 inside a checkout
#
# THE REV-PARSE GATE COMES FIRST: a directory that is not a git checkout has no ignore rules to report,
# and `check-ignore` answers 128 there, which would otherwise read as "could not check" on every non-git
# consumer. Inside a checkout an exit other than 0 or 1 is `unchecked:<rc>` -- measured: a parent
# directory that is a symlink ("beyond a symbolic link"), and an exclude file that is a directory
# (`core.excludesFile` naming one, or `.git/info/exclude` being one), each exit 128.
#
# THE DECISION IS `check-ignore -q`, NEVER `-v`. `-v` answers 0 on a NEGATION match too, so a consumer
# holding `*.txt` and `!docs/smoke-surface.txt` would be told to force-add a path git already adds.
# `-v` is asked only after `-q` said ignored, for the provenance and the exact-path test.
#
# A TRACKED PATH IS NEVER REPORTED: without `--no-index`, `check-ignore` answers 1 for a path the index
# holds, whatever the rules say, and a tracked path is one every checkout already receives.
#
# THE WORKING-TREE CHECK IS DELIBERATE. It asks the consumer's own checkout, where the operator runs the
# `git add` the remedy names, so `.git/info/exclude` and `core.excludesFile` count: a path ignored only
# on this machine is still a path this operator's `git add` refuses.
#
# THE EXACT-PATH EXIT. A consumer that keeps the file untracked ON PURPOSE says so by ignoring it by its
# exact path. The pattern is the third `:`-field of the provenance, and it must STRING-EQUAL `<rel>` or
# `/<rel>`; nothing else counts. A glob (`*.txt`, `docs/smoke-surface.*`, `**/smoke-surface.txt`) or a
# parent directory (`docs/`) is not a decision about this file, so it stays `ignored`. `-v` names the
# LAST matching pattern, so an exact line followed by a later glob reads as the glob. An exact line
# followed by `!<rel>` is not ignored at all (`-q` exits 1), so it reads `untracked-ok`.
#
# KNOWN LIMIT: a path git prints with `\` escapes (a pattern carrying a literal `*`, `?`, `[`, `!` or a
# leading `#`) never string-equals the raw path, so its row persists and `git add -f` is the only exit.
# A provenance source path that itself contains `:` would also mis-split; the ignore files git reads
# here (`.gitignore`, `.git/info/exclude`, `core.excludesFile`) are not expected to.
scaffold_ignore_state() { # <root> <rel>
  local root="$1" rel="$2" rc v prov pat
  if ! git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
    printf 'untracked-ok\t\n'; return 0
  fi
  rc=0; git -C "$root" check-ignore -q -- "$rel" 2>/dev/null || rc=$?
  case "$rc" in
    0) : ;;
    1) printf 'untracked-ok\t\n'; return 0 ;;
    *) printf 'unchecked:%s\t\n' "$rc"; return 0 ;;
  esac
  v="$(git -C "$root" check-ignore -v -- "$rel" 2>/dev/null)" || v=""
  prov="${v%%$'\t'*}"
  pat="${prov#*:}"; pat="${pat#*:}"
  if [ -n "$prov" ] && { [ "$pat" = "$rel" ] || [ "$pat" = "/$rel" ]; }; then
    printf 'exact\t%s\n' "$prov"; return 0
  fi
  printf 'ignored\t%s\n' "$prov"
  return 0
}

# scaffold_ignore_remedy <rel> <prov>
#   Prints the remedy for an ignored scaffolded path. This is the only copy of the text in the tree.
scaffold_ignore_remedy() { # <rel> <prov>
  printf '%s\n' "IGNORED HERE ($2): 'git add -A' skips this path and 'git add $1' refuses it, so no other checkout will have it. Commit it with 'git add -f $1', or, to keep it untracked on purpose, ignore it by its exact path (a line '$1' in .gitignore), which ends this row."
}
