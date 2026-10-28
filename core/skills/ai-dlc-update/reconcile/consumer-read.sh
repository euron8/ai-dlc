#!/usr/bin/env bash
# consumer-read.sh — the ONE door every reconcile detector reads a consumer path through.
#
# NOT MARKED region-exempt, deliberately. I105 (validate-enforcement-map.sh) counts a file as
# INVOKED by the driver when emit-report.sh names `"$SELF/<file>"`, and emit-report.sh sources this
# file under exactly that spelling: its own render reads the consumer through these functions. So
# the driver does run it, in its own process, on every render, and a marker saying otherwise would
# be the stale half of I105's BOTH finding. It emits no rows of its own; the rows its reads feed
# are each detector's.
#
# Sourced (never executed) by emit-report.sh and by every script it runs, transitively. Each
# function takes the CONSUMER ROOT and a ROOT-RELATIVE path, and does exactly what the raw
# test, read, hash, walk or `git -C` it replaces did, plus the path refusal below. The read log
# these functions once wrote fed emit-report.sh's recorded `--verify` PASS, which is retired, and
# the log went with it. The refusal is what remains: a detector that resolved a path on its own (a
# `hooks:` value with `..`, an unquoted glob, a lexically collapsed receipt label, a bare
# `scripts/`) reads only what the OS resolves for the spelling it asked for.
#
#   cr_test  <root> <op> <rel>        `[ <op> <root>/<rel> ]`; op is one of -e -f -d -x -s -r -w -L -h
#   cr_read  <root> <rel>             the file's bytes on stdout (cat's status)
#   cr_hash  <root> <rel>             `git hash-object --no-filters` of the file
#   cr_walk  <root> <rel> [find-args] `find <rel> [find-args]` run FROM <root>, so every name it
#                                     prints is root-relative (`<rel>/...`); -print0 passes through
#   cr_git   <root> <git-args...>     `git -C <root> <git-args...>`
#   cr_run   <root> <cmd...>          <cmd> with its working directory at <root>, for a program that
#                                     resolves consumer-relative paths against its cwd
#
# THE PATH IS REFUSED, NEVER NORMALISED. A <rel> with a `..` component or a leading `/` returns 2
# and names itself on stderr, from every function (cr_walk also refuses a leading
# `-`, which find would read as a predicate). `a/../b` is not
# rewritten to `b`: a lexical collapse is a second path resolver, and it disagrees with the OS
# exactly where it matters (a symlinked `a`, or no `a` at all). Each call site maps 2 to the way it
# already reports an unresolvable input; 2 is never "absent".
#
# GLOBBING IS OFF. Every closure script sets `-f` in its preamble and this file never turns it on.
# Every internal helper starts with `cr_` and every function's closing brace sits in column 0.

case $- in *f*) ;; *) set -f ;; esac

# cr__guard <rel> -- 0 when <rel> may name a consumer path, 2 (named on stderr) when it may not.
cr__guard() {
  case "/$1/" in
    */../*) ;;
    *) case "$1" in /*) ;; *) return 0 ;; esac ;;
  esac
  printf 'consumer-read: refused the consumer path %s: it must be relative to the consumer root, with no ".." component and no leading "/"\n' "'$1'" >&2
  return 2
}

# ROOT FIRST, like every other function here: `cr_test <op> <root>` would put `test -d "$ROOT"` in
# the source text, which reads as a raw rooted test to the closure's own read-site scanner.
# cr_path <root> <rel> -- the consumer path "<root>/<rel>" on stdout, for a reader that must take it as
# an OPERAND (a `diff` a caller's shim shadows, a program that resolves it itself). The path is
# guarded. It forks nothing and writes nothing: a staged copy or a link in its place was a new write
# or a new tool ahead of the reader. 1 when the file is absent, 2 when refused.
cr_path() {
  cr__guard "$2" || return 2
  [ -f "$1/$2" ] || return 1
  printf '%s/%s\n' "$1" "$2"
}

cr_test() {
  cr__guard "$3" || return 2
  case "$2" in -e|-f|-d|-x|-s|-r|-w|-L|-h) ;; *) printf 'consumer-read: cr_test does not take %s\n' "'$2'" >&2; return 2 ;; esac
  [ "$2" "$1/$3" ]
}

cr_read() {
  cr__guard "$2" || return 2
  cat -- "$1/$2"
}

cr_hash() {
  cr__guard "$2" || return 2
  git hash-object --no-filters -- "$1/$2"
}

# cr__strip <prefix> <nul:0|1> -- each name on stdin with <prefix> removed, in pure bash: no tool
# beyond the shell, so a hermetic tool farm that declares `find` needs nothing else for a walk.
cr__strip() {
  local p="$1" l
  if [ "$2" = 1 ]; then
    while IFS= read -r -d '' l; do printf '%s\0' "${l#"$p"}"; done
  else
    while IFS= read -r l; do printf '%s\n' "${l#"$p"}"; done
  fi
}

# FIND IS HANDED THE ABSOLUTE PATH, `<root>/<rel>`, the argv every detector passed it before this
# file existed, and the root prefix is stripped from each name afterwards, so the names stay
# root-relative. Run from inside the root with a relative operand, find's argv no longer carried
# the consumer path, and a probe keyed on it (a stubbed find that must fail one layer walk) never
# fired. A `-path` predicate therefore matches the ABSOLUTE spelling (`<root>/<rel>/...`). find's
# own status is the walk's status: the strip cannot mask a failed walk.
cr_walk() {
  local root="$1" rel="$2" a nul=0
  cr__guard "$rel" || return 2
  # find reads a leading `-` as a predicate, not a path.
  case "$rel" in -*) printf 'consumer-read: cr_walk cannot walk %s: a leading "-" is a find predicate\n' "'$rel'" >&2; return 2 ;; esac
  shift 2
  for a in "$@"; do [ "$a" != -print0 ] || nul=1; done
  # NO bash PROCESS OF THIS SHELL'S LINEAGE MAY EXIT THROUGH bash HERE. After a failed write, bash
  # still holds the unflushed bytes in its stdout buffer; a `( … )` subshell or a builtin pipeline
  # stage is a fork that flushes them when it exits, so the leaked fragment landed in the walk's
  # output and a caller iterated junk entries (measured: layer-drift's extensions loop under XFSZ,
  # three junk entries; the old `find | sort` leaked none). So the pipeline runs in THIS shell, its
  # status is read from PIPESTATUS, and every stage EXECs a program, which discards the inherited
  # buffer: awk strips a line walk (the prefix through ENVIRON, which keeps a backslash `-v` would
  # eat), and an exec'd "$BASH" strips a NUL walk, which BSD awk cannot split.
  local _cr_st
  if [ "$nul" = 1 ]; then
    find "$root/$rel" "$@" | CR__P="$root/" "$BASH" -c 'p="$CR__P"; while IFS= read -r -d "" l; do printf "%s\0" "${l#"$p"}"; done'
  else
    find "$root/$rel" "$@" | CR__P="$root/" awk 'BEGIN { p = ENVIRON["CR__P"]; n = length(p) } { if (substr($0, 1, n) == p) $0 = substr($0, n + 1); print }'
  fi
  _cr_st="${PIPESTATUS[0]}:${PIPESTATUS[1]}"
  [ "${_cr_st%%:*}" -eq 0 ] || return "${_cr_st%%:*}"
  return "${_cr_st##*:}"
}

# cr_list <root> <rel> -- the immediate non-dot subdirectories of <rel> (a link to a directory
# included), one root-relative name per line, in the order the shell's `<dir>/*/` glob expands:
# exactly the set and order such a glob gave, with no `find` or `sort` forked.
# 1 when <rel> is not a directory. The glob runs in a subshell, so the caller's -f stands.
cr_list() {
  local root="$1" rel="$2"
  cr__guard "$rel" || return 2
  [ -d "$root/$rel" ] || return 1
  (
    set +f
    for e in "$root/$rel"/*/; do
      [ -d "$e" ] || continue
      e="${e%/}"
      printf '%s\n' "$rel/${e##*/}"
    done
    set -f
  )
}

cr_git() {
  local root="$1"
  shift
  git -C "$root" "$@"
}

# cr_run <root> <cmd...> -- for a program that reads consumer paths ITSELF (a predicate validator, an
# `sh` receipt), run with its working directory at <root>. A failed `cd` is a non-zero exit, never a
# run at the caller's cwd.
cr_run() {
  local root="$1"
  shift
  ( cd "$root" && "$@" )
}
