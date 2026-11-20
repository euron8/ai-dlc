#!/usr/bin/env bash
# reconcile/pull-key.sh — the pull fingerprint F and the raw-detector store (BL-1190 D-7).
#
# F names the ONE pre-write input state a pull's detectors read. A detector output recorded under
# one F may stand in for a fresh run only while F is unchanged and the call's argv is exactly the
# recorded argv. emit-report.sh (`--keep-raw`, `--reuse`), apply.sh (under AI_DLC_PULL_RUN) and
# pull.sh source this file; nothing else computes F or reads the store.
#
# F covers, in this order:
#   base and theirs, each resolved to a commit in <dist>
#   the hash of <dist>'s `for-each-ref` listing and its HEAD
#   the consumer's working tree as a temp-index tree, with EXACTLY two paths excluded:
#     _bmad-output/ai-dlc-update/reconcile-report.md  (the driver writes the region there)
#     .claude/.ai-dlc-applying                         (apply.sh writes it between the gate and ud)
#   the hash of the consumer's real `git ls-files -s` (a staged-only change moves F)
#   the stamp's bytes (.claude/.ai-dlc-version)
#   every file beside this one in reconcile/, by blob (data files are read too)
#   the tools a detector resolves on PATH, PATH itself, the bash version and the locale variables
# Anything that cannot be computed makes F `UNAVAILABLE <why>`, and an UNAVAILABLE F never matches.
#
# Usage, as a program:  pull-key.sh <dist> <base> <consumer> <theirs>
#   prints `pull-key 1 <sha256>` or `pull-key UNAVAILABLE <why>`; exit 0 either way, 2 = usage.
#
# THE RAW STORE (`<raw>/`): `F` holds the line above; `det/<key>/` holds one detector call as
# `argv` (its canonical argv), `out`, `err` and `rc`, captured BEFORE any caller post-processing.
# The key is the git blob id of the canonical argv. The canonical argv is every argument printed
# with `%q`, one per line, except the operand after `--bucket-rows`, `--ld-rows` or `--ud-rows`,
# which is replaced by `content:<blob id of that file>` (its path is a temp name; its bytes are the
# input).

PK_SELF_DIR="${BASH_SOURCE[0]%/*}"
[ "$PK_SELF_DIR" = "${BASH_SOURCE[0]}" ] && PK_SELF_DIR=.
PK_SELF_DIR="$(cd "$PK_SELF_DIR" 2>/dev/null && pwd)"
PK_REPORT_REL="_bmad-output/ai-dlc-update/reconcile-report.md"
PK_MARKER_REL=".claude/.ai-dlc-applying"

# pk_sha256 -- sha256 of stdin as 64 hex; empty output and status 1 when no working tool exists.
pk_sha256() {
  local d
  if command -v shasum >/dev/null 2>&1; then d="$(shasum -a 256 2>/dev/null)" || return 1
  elif command -v sha256sum >/dev/null 2>&1; then d="$(sha256sum 2>/dev/null)" || return 1
  else cat >/dev/null; return 1
  fi
  d="${d%% *}"
  case "$d" in *[!0-9a-f]*|'') return 1 ;; esac
  [ "${#d}" -eq 64 ] || return 1
  printf '%s\n' "$d"
}

# pk_components <dist> <base> <consumer> <theirs> -- the F input, one labelled block per component.
# A subshell body: it turns pathname expansion back on for the reconcile/ listing, and its temp
# index is removed by its own trap whatever exits.
pk_components() (
  set +f
  dist="$1"; base="$2"; cons="$3"; theirs="$4"
  b="$(git -C "$dist" rev-parse -q --verify "${base}^{commit}" 2>/dev/null)" || { echo "UNAVAILABLE base-unresolved"; exit 1; }
  t="$(git -C "$dist" rev-parse -q --verify "${theirs}^{commit}" 2>/dev/null)" || { echo "UNAVAILABLE theirs-unresolved"; exit 1; }
  printf 'base %s\ntheirs %s\n' "$b" "$t"
  refs="$( { git -C "$dist" for-each-ref --format='%(objectname) %(refname)' && git -C "$dist" rev-parse -q --verify HEAD; } 2>/dev/null | git hash-object --stdin 2>/dev/null)" \
    || { echo "UNAVAILABLE dist-refs"; exit 1; }
  printf 'dist-refs %s\n' "$refs"
  top="$(git -C "$cons" rev-parse --show-toplevel 2>/dev/null)" || { echo "UNAVAILABLE consumer-not-a-repository"; exit 1; }
  [ "$(cd "$top" 2>/dev/null && pwd -P)" = "$(cd "$cons" 2>/dev/null && pwd -P)" ] || { echo "UNAVAILABLE consumer-not-a-top-level"; exit 1; }
  idx="$(git -C "$cons" rev-parse --git-path index 2>/dev/null)" || { echo "UNAVAILABLE index-path"; exit 1; }
  case "$idx" in /*) ;; *) idx="$cons/$idx" ;; esac
  tmpi="$(mktemp "${TMPDIR:-/tmp}/pull-key-index.XXXXXX" 2>/dev/null)" || { echo "UNAVAILABLE mktemp"; exit 1; }
  trap 'rm -f "$tmpi"' EXIT
  if [ -f "$idx" ]; then cp "$idx" "$tmpi" 2>/dev/null || { echo "UNAVAILABLE index-copy"; exit 1; }
  else rm -f "$tmpi"; fi
  GIT_INDEX_FILE="$tmpi" git -C "$cons" add -A -- . ":(exclude)$PK_REPORT_REL" ":(exclude)$PK_MARKER_REL" >/dev/null 2>&1 \
    || { echo "UNAVAILABLE worktree-index"; exit 1; }
  GIT_INDEX_FILE="$tmpi" git -C "$cons" rm -q --cached --ignore-unmatch -- "$PK_REPORT_REL" "$PK_MARKER_REL" >/dev/null 2>&1 \
    || { echo "UNAVAILABLE worktree-index-exclude"; exit 1; }
  tree="$(GIT_INDEX_FILE="$tmpi" git -C "$cons" write-tree 2>/dev/null)" || { echo "UNAVAILABLE worktree-tree"; exit 1; }
  printf 'consumer-tree %s\n' "$tree"
  ls="$(git -C "$cons" ls-files -s 2>/dev/null | git hash-object --stdin 2>/dev/null)" || { echo "UNAVAILABLE ls-files"; exit 1; }
  printf 'index %s\n' "$ls"
  if [ -f "$cons/.claude/.ai-dlc-version" ]; then
    printf 'stamp %s\n' "$(git hash-object --no-filters -- "$cons/.claude/.ai-dlc-version" 2>/dev/null || echo unreadable)"
  else
    printf 'stamp ABSENT\n'
  fi
  for f in "$PK_SELF_DIR"/*; do
    [ -f "$f" ] || continue
    printf 'reconcile %s %s\n' "${f##*/}" "$(git hash-object --no-filters -- "$f" 2>/dev/null || echo unreadable)"
  done
  for x in bash git awk sed grep sort comm diff cmp cat tr cut paste head find mktemp shasum sha256sum jq python3; do
    printf 'tool %s %s\n' "$x" "$(command -v "$x" 2>/dev/null || echo ABSENT)"
  done
  printf 'path %s\nbash %s\n' "${PATH:-}" "${BASH_VERSION:-}"
  printf 'locale LC_ALL=%s LANG=%s LC_COLLATE=%s LC_CTYPE=%s\n' "${LC_ALL:-}" "${LANG:-}" "${LC_COLLATE:-}" "${LC_CTYPE:-}"
)

# pk_fingerprint <dist> <base> <consumer> <theirs> -- prints `pull-key 1 <sha256>` or
# `pull-key UNAVAILABLE <why>`. Always returns 0.
pk_fingerprint() {
  local c d
  if ! c="$(pk_components "$@")"; then
    printf 'pull-key UNAVAILABLE %s\n' "${c#UNAVAILABLE }"; return 0
  fi
  if d="$(printf '%s\n' "$c" | pk_sha256)"; then printf 'pull-key 1 %s\n' "$d"
  else printf 'pull-key UNAVAILABLE no-sha256-tool\n'; fi
  return 0
}

# pk_canon <args...> -- the canonical argv (see the header).
pk_canon() {
  local a prev="" h
  for a in "$@"; do
    if [ "$prev" = --bucket-rows ] || [ "$prev" = --ld-rows ] || [ "$prev" = --ud-rows ]; then
      h="$(git hash-object --no-filters -- "$a" 2>/dev/null)" || h="unreadable:$a"
      printf 'content:%q\n' "$h"
    else
      printf '%q\n' "$a"
    fi
    prev="$a"
  done
}

# pk_store <raw-dir> <out> <err> <rc> <args...> -- records one call under <raw-dir>/det/<key>/.
pk_store() {
  local raw="$1" o="$2" e="$3" rc="$4" canon key d
  shift 4
  canon="$(pk_canon "$@")" || return 1
  key="$(printf '%s\n' "$canon" | git hash-object --stdin 2>/dev/null)" || return 1
  d="$raw/det/$key"
  mkdir -p "$d" 2>/dev/null || return 1
  printf '%s\n' "$canon" > "$d/argv" && cp "$o" "$d/out" && cp "$e" "$d/err" && printf '%s\n' "$rc" > "$d/rc"
}

# pk_fetch <raw-dir> <out> <err> <args...> -- 0 and PK_RC set when <raw-dir> holds a call whose
# recorded argv EQUALS this canonical argv: its stdout and stderr are copied to <out> and <err>.
# 1 otherwise (the caller runs the detector). The argv file is compared whole, not trusted by key.
PK_RC=""
pk_fetch() {
  local raw="$1" o="$2" e="$3" canon key d rc
  shift 3
  PK_RC=""
  [ -n "$raw" ] && [ -d "$raw/det" ] || return 1
  canon="$(pk_canon "$@")" || return 1
  key="$(printf '%s\n' "$canon" | git hash-object --stdin 2>/dev/null)" || return 1
  d="$raw/det/$key"
  [ -f "$d/argv" ] && [ -f "$d/out" ] && [ -f "$d/err" ] && [ -f "$d/rc" ] || return 1
  [ "$(cat "$d/argv")" = "$canon" ] || return 1
  rc="$(cat "$d/rc")"
  case "$rc" in ''|*[!0-9]*) return 1 ;; esac
  cp "$d/out" "$o" 2>/dev/null && cp "$d/err" "$e" 2>/dev/null || return 1
  [ -n "${PK_HITLOG:-}" ] && printf 'HIT %s\n' "$key" >> "$PK_HITLOG" 2>/dev/null
  PK_RC="$rc"
  return 0
}

# pk_reuse_ok <raw-dir> <dist> <base> <consumer> <theirs> -- 0 when <raw-dir>/F is a computed F
# equal to F now.
pk_reuse_ok() {
  local raw="$1" now rec
  shift
  [ -f "$raw/F" ] || return 1
  rec="$(cat "$raw/F" 2>/dev/null)"
  case "$rec" in "pull-key 1 "*) ;; *) return 1 ;; esac
  now="$(pk_fingerprint "$@")"
  [ "$now" = "$rec" ]
}

# pk_ask_ctx <dist> <theirs> <consumer> <path> -- the pull a digest belongs to: `theirs <commit>` and
# `blob <the consumer's COMMITTED blob of path, or ->`. Every ask digest carries it, so an answer given
# for one theirs or one committed copy never answers the same row once either moves. The committed
# blob is the pre-merge state: a pull's writes stay uncommitted until deliver.
pk_ask_ctx() {
  local t b
  t="$(git -C "$1" rev-parse -q --verify "${2}^{commit}" 2>/dev/null)" || t="unresolved:$2"
  b="$(git -C "$3" rev-parse -q --verify "HEAD:$4" 2>/dev/null)" || b="-"
  printf 'theirs %s\nblob %s\n' "$t" "$b"
}

# pk_region_asks <region-file> <ask-families.tsv> <dist> <theirs> <consumer> -- one
# `family<TAB>path<TAB>digest<TAB>row` line per region row that belongs to an ASK family whose source is
# `bucket`. Rows are whitespace-normalised as emit-report.sh's norm_rows does and made unique; the path
# is the row's last field; the digest is the sha256 of the normalised row, a newline and the row's
# pk_ask_ctx. Status 1 when either file cannot be read or no sha256 tool works, so a caller never reads
# "no ask row" off a failure.
pk_region_asks() {
  local reg="$1" fam="$2" dist="$3" th="$4" cons="$5" rows row f d
  [ -r "$reg" ] && [ -r "$fam" ] || return 1
  rows="$(awk -F'\t' 'NR == FNR { if ($0 !~ /^#/ && NF >= 4 && $2 == "bucket") { n++; nm[n] = $1; re[n] = $3 } next }
           { r = $0; gsub(/[[:space:]]+/, " ", r); for (i = 1; i <= n; i++) if (r ~ re[i]) { print nm[i] "\t" r; break } }' \
           "$fam" "$reg" | LC_ALL=C sort -u)" || return 1
  [ -n "$rows" ] || return 0
  local stg rc=0
  stg="$(mktemp "${TMPDIR:-/tmp}/pull-key-asks.XXXXXX" 2>/dev/null)" || return 1
  printf '%s\n' "$rows" | cat > "$stg" || { rm -f "$stg"; return 1; }
  while IFS="$(printf '\t')" read -r f row; do
    [ -n "$row" ] || continue
    d="$( { printf '%s\n' "$row"; pk_ask_ctx "$dist" "$th" "$cons" "${row##* }"; } | pk_sha256)" || { rc=1; break; }
    printf '%s\t%s\t%s\t%s\n' "$f" "${row##* }" "$d" "$row"
  done < "$stg"
  rm -f "$stg"
  return "$rc"
}

# pk_conflict_ledger <consumer> <override> -- the ONE writer of a `conflict-hunk` ask-ledger row. For
# an override whose body carries merge markers it appends `conflict-hunk<TAB><rel><TAB><digest><TAB>markers`
# to <consumer git-dir>/ai-dlc-pull/asks.tsv, first-wins per digest, and prints the digest. The digest
# is the sha256 of `conflict-hunk<TAB><rel>` and every line from each `<<<<<<< ` to its `>>>>>>> `.
# readopt-override.sh --merge calls it on every CONFLICT, whoever invoked it, so apply.sh's CONFLICT
# GUARD and `pull.sh finish` see a hunk resolved by hand. Status 1, nothing written, when no git-dir
# resolves, the body carries no marker, or no sha256 tool works.
pk_conflict_ledger() {
  local c="$1" o="$2" ca oa rel gd d
  ca="$(cd "$c" 2>/dev/null && pwd -P)" || return 1
  case "$o" in /*) ;; *) o="$c/$o" ;; esac
  oa="$(cd "${o%/*}" 2>/dev/null && pwd -P)/${o##*/}" || return 1
  rel="${oa#"$ca"/}"
  [ "$rel" != "$oa" ] || return 1
  gd="$(git -C "$ca" rev-parse --absolute-git-dir 2>/dev/null)" || return 1
  [ -n "$gd" ] && [ -d "$gd" ] || return 1
  grep -q '^<<<<<<< ' "$oa" 2>/dev/null || return 1
  d="$( { printf 'conflict-hunk\t%s\n' "$rel"; awk '/^<<<<<<< /{f=1} f{print} /^>>>>>>> /{f=0}' "$oa"; } | pk_sha256)" || return 1
  mkdir -p "$gd/ai-dlc-pull" 2>/dev/null || return 1
  if ! grep -q "	${d}	" "$gd/ai-dlc-pull/asks.tsv" 2>/dev/null; then
    printf 'conflict-hunk\t%s\t%s\tmarkers\n' "$rel" "$d" >> "$gd/ai-dlc-pull/asks.tsv" 2>/dev/null || return 1
  fi
  printf '%s\n' "$d"
}

[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
[ $# -eq 4 ] || { echo "usage: pull-key.sh <dist> <base> <consumer> <theirs>" >&2; exit 2; }
pk_fingerprint "$@"
