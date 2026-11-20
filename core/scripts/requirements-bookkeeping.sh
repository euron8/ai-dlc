#!/usr/bin/env bash
# requirements-bookkeeping.sh -- the requirements step's mechanical passes, run by the lead as one
# command each instead of a remediator dispatch per pass.
#
#   requirements-bookkeeping.sh --precheck <N>        read-only; exit 0 clean, 1 findings, 2 usage/missing input.
#        One line per finding, `PRECHECK <class> <file>:<line> <text>`. Classes:
#          FENCE    a `derived` fence in the PRD, SPEC or locked slot that the artifact-derivation validator finds stale
#          MIRROR   a slot bullet `- LR-S<N>-<m> ...` absent from, or different in, the PRD's LOCKED_REQUIREMENTS block
#          CAP      a PRD functional requirement with no `(CAP-m)` citation, or one citing a CAP the SPEC does not carry
#          LOCATOR  a `<existing .md file>:<line>` cite in the PRD whose line number exceeds the file's length
#        A cite to a file that does not exist is not reported (it may name a tree this checkout lacks).
#   requirements-bookkeeping.sh --rederive <file>...  rewrite each stale `derived` fence's recorded output with its
#        command's current output, then re-validate the file. The command is run only when the validator's own
#        `--explain-cmd` allowlist answers OK, from the project root, COLUMNS=80. Prints `REDERIVED <file>:<line>`
#        per rewrite; exit 0 when the file validates afterwards, 1 when a derivation is still stale (the file is
#        then restored byte-for-byte), 2 usage.
#   requirements-bookkeeping.sh --mirror-lr <N>       copy the slot's `- LR-S<N>-<m>` bullets into the PRD's
#        LOCKED_REQUIREMENTS block: a differing bullet is replaced in place, a missing one is inserted before the
#        END marker of the block that already carries a bullet of this sprint (else the last block). Prints
#        `MIRRORED <id>` per change or `UNCHANGED`. Exit 1 when the PRD has no block.
#   requirements-bookkeeping.sh --seal <file>...      record a content-seal program row for each file, so the
#        join readers compare a bookkeeping rewrite of a sealed file against these bytes
#        (`content-seal.sh --record`, program:requirements-bookkeeping).
#
# It never renders the SPEC (one bmad-spec dispatch, after the serial tail).
# Project root: AI_DLC_PROJECT_ROOT, else the git toplevel. State dir: AI_DLC_STATE_DIR (default _bmad-output).
set -uo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of
# `..` hops -- the same block every sibling validator carries, inline on purpose:
# a shared lib cannot fix this because locating the lib is the same unsolved
# problem. core/fixtures/validator-path-resolution asserts the layouts agree.
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
# FAIL CLOSED: an unresolved root becomes a path that cannot exist and is refused below.
AI_DLC_ROOT="${AI_DLC_ROOT:-/nonexistent}"
# --- end AI_DLC_ROOT --------------------------------------------------------
ROOT="$AI_DLC_ROOT"
[ -d "$ROOT" ] || { echo "requirements-bookkeeping: no project root" >&2; exit 2; }
STATE="${AI_DLC_STATE_DIR:-_bmad-output}"
VAD="$SELF_DIR/validate-artifact-derivations.sh"
SEAL="$SELF_DIR/content-seal.sh"
USAGE="usage: $0 --precheck <N> | --rederive <file>... | --mirror-lr <N> | --seal <file>..."

sprint_files() { # N -> sets PRD SPEC SLOT
  PRD="$ROOT/$STATE/planning-artifacts/prd.md"
  SLOT="$ROOT/$STATE/planning-artifacts/s$1/locked-requirements.md"
  SPEC=""
  for s in "$ROOT/$STATE/specs/s$1"/*/SPEC.md; do [ -f "$s" ] && SPEC="$s"; done
}
need_n() { case "${1:-}" in ''|*[!0-9]*) echo "$USAGE" >&2; exit 2 ;; esac; }

# stale line numbers of one file, one per line, from the validator's own FAIL (STALE) lines
stale_lines() {
  ( cd "$ROOT" && bash "$VAD" "$1" 2>&1 >/dev/null ) | sed -n 's/^FAIL (STALE): .*:\([0-9][0-9]*\) records an output.*/\1/p'
}

cmd_precheck() {
  need_n "${1:-}"; n="$1"; sprint_files "$n"
  [ -f "$PRD" ] && [ -f "$SLOT" ] || { echo "requirements-bookkeeping: missing $PRD or $SLOT" >&2; exit 2; }
  found=0
  emit() { printf 'PRECHECK %s %s:%s %s\n' "$1" "$2" "$3" "$4"; found=1; }
  for f in "$PRD" "$SPEC" "$SLOT"; do
    [ -n "$f" ] && [ -f "$f" ] || continue
    for ln in $(stale_lines "$f"); do emit FENCE "${f#"$ROOT"/}" "$ln" "derived fence records an output its command no longer produces"; done
  done
  # MIRROR: id -> exact line, slot against the PRD's blocks. A PRD with no bullet of this sprint
  # (a series authored before this slot, or another sprint's PRD) is SKIP, never a finding.
  mirror_in="$SLOT"
  if ! grep -qE "^- LR-S$n-[0-9]+" "$PRD"; then
    echo "PRECHECK SKIP MIRROR the PRD carries no LR-S$n bullet"; mirror_in=/dev/null
  fi
  while IFS= read -r line; do
    id="$(printf '%s\n' "$line" | sed -n "s/^- \(LR-S$n-[0-9][0-9]*\)[^0-9].*/\1/p; s/^- \(LR-S$n-[0-9][0-9]*\)\$/\1/p" | head -1)"
    [ -n "$id" ] || continue
    if ! grep -qxF -- "$line" "$PRD"; then
      if grep -qE "^- $id([^0-9]|\$)" "$PRD"; then emit MIRROR "${PRD#"$ROOT"/}" 1 "$id differs from the slot's bullet"
      else emit MIRROR "${PRD#"$ROOT"/}" 1 "$id is absent from the PRD block"; fi
    fi
  done < "$mirror_in"
  # CAP
  if [ -n "$SPEC" ]; then
    awk -v n="$n" -v spec="$SPEC" -v prd="${PRD#"$ROOT"/}" '
      BEGIN { while ((getline l < spec) > 0) while (match(l, /CAP-[0-9]+/)) { cap[substr(l, RSTART, RLENGTH)] = 1; l = substr(l, RSTART + RLENGTH) } }
      $0 ~ ("^- \\*\\*FR-S" n "-[0-9]+") {
        head = $0; sub(/\*\*[^*]*$/, "", head); h = $0
        if (h !~ /\(CAP-[0-9]+\)/) { printf "PRECHECK CAP %s:%d FR carries no (CAP-m) citation\n", prd, NR; next }
        t = h
        while (match(t, /CAP-[0-9]+/)) { c = substr(t, RSTART, RLENGTH); if (!(c in cap)) printf "PRECHECK CAP %s:%d cites %s, which the SPEC does not carry\n", prd, NR, c; t = substr(t, RSTART + RLENGTH) }
      }' "$PRD" > "${TMPDIR:-/tmp}/rb.cap.$$"
    [ -s "${TMPDIR:-/tmp}/rb.cap.$$" ] && { cat "${TMPDIR:-/tmp}/rb.cap.$$"; found=1; }
    rm -f "${TMPDIR:-/tmp}/rb.cap.$$"
  fi
  # LOCATOR
  cites="$(grep -noE '[A-Za-z0-9_./-]+\.md:[0-9]+' "$PRD")" || cites=""
  while IFS=: read -r pl rest; do
    [ -n "$pl" ] || continue
    p="${rest%:*}"; cl="${rest##*:}"
    for cand in "$ROOT/$p" "$ROOT/$STATE/$p"; do
      if [ -f "$cand" ]; then
        len="$(wc -l < "$cand" | tr -d ' ')"
        [ "$cl" -gt "$len" ] && printf 'PRECHECK LOCATOR %s:%s %s:%s exceeds the file (%s lines)\n' "${PRD#"$ROOT"/}" "$pl" "$p" "$cl" "$len"
        break
      fi
    done
  done > "${TMPDIR:-/tmp}/rb.loc.$$" <<EOF
$cites
EOF
  [ -s "${TMPDIR:-/tmp}/rb.loc.$$" ] && { cat "${TMPDIR:-/tmp}/rb.loc.$$"; found=1; }
  rm -f "${TMPDIR:-/tmp}/rb.loc.$$"
  [ "$found" -eq 0 ] && echo "PRECHECK clean"
  exit "$found"
}

rederive_one() { # file -> 0 validates after, 1 still stale
  f="$1"; bak="$(mktemp)"; cp "$f" "$bak"
  lns="$(stale_lines "$f" | sort -rn)"
  for ln in $lns; do
    cmdline="$(sed -n "${ln}p" "$f")"
    indent="${cmdline%%\$ *}"; cmd="${cmdline#*\$ }"
    verdict="$(bash "$VAD" --explain-cmd "$cmd" 2>&1 | awk -F'\t' '$2 == "VERDICT" { print $3; exit }')"
    [ "$verdict" = OK ] || { echo "SKIPPED $f:$ln command is not on the validator's allowlist" >&2; continue; }
    out="$(mktemp)"
    ( cd "$ROOT" && COLUMNS=80 bash -c "$cmd" < /dev/null > "$out" 2>/dev/null )
    new="$(mktemp)"
    awk -v ln="$ln" -v ind="$indent" -v outf="$out" '
      NR < ln { print; next }
      NR == ln { print; while ((getline l < outf) > 0) print (l == "" ? "" : ind l); skipping = 1; next }
      skipping && ($0 ~ /^[[:space:]]*```[[:space:]]*$/ || $0 ~ /^[[:space:]]*\$ /) { skipping = 0 }
      skipping { next }
      { print }' "$f" > "$new"
    cat "$new" > "$f"; rm -f "$new" "$out"
    echo "REDERIVED $f:$ln"
  done
  if [ -n "$(stale_lines "$f")" ]; then cat "$bak" > "$f"; rm -f "$bak"; return 1; fi
  rm -f "$bak"; return 0
}

cmd_mirror() {
  need_n "${1:-}"; n="$1"; sprint_files "$n"
  [ -f "$PRD" ] && [ -f "$SLOT" ] || { echo "requirements-bookkeeping: missing $PRD or $SLOT" >&2; exit 2; }
  grep -qE "^- LR-S$n-[0-9]+" "$PRD" || { echo "requirements-bookkeeping: the PRD carries no LR-S$n bullet to anchor on; author the block first" >&2; exit 1; }
  new="$(mktemp)"
  awk -v n="$n" -v slot="$SLOT" '
    function idof(l) { if (match(l, "^- LR-S" n "-[0-9]+") && substr(l, RLENGTH + 1, 1) !~ /[0-9]/) return substr(l, 3, RLENGTH - 2); return "" }
    BEGIN { while ((getline l < slot) > 0) { i = idof(l); if (i != "") { want[i] = l; order[++cnt] = i } } }
    { lines[++nl] = $0; i = idof($0); if (i != "" && !(i in lineof)) lineof[i] = nl }
    END {
      first = 0; for (j = 1; j <= cnt; j++) if (order[j] in lineof) { first = lineof[order[j]]; break }
      if (!first) { print "no slot bullet is present in the PRD" > "/dev/stderr"; exit 3 }
      prev = first - 1
      for (j = 1; j <= cnt; j++) {
        if (order[j] in lineof) prev = lineof[order[j]]
        else { add[prev] = add[prev] want[order[j]] "\n"; print "MIRRORED " order[j] > "/dev/stderr" }
      }
      if (0 in add) printf "%s", add[0]
      for (k = 1; k <= nl; k++) {
        i = idof(lines[k])
        if (i != "" && (i in want) && lineof[i] == k && lines[k] != want[i]) { print want[i]; print "MIRRORED " i > "/dev/stderr" }
        else print lines[k]
        if (k in add) printf "%s", add[k]
      }
    }' "$PRD" > "$new" 2> "${new}.msg"
  rc=$?
  if [ "$rc" -ne 0 ]; then cat "${new}.msg" >&2; rm -f "$new" "${new}.msg"; exit 1; fi
  if cmp -s "$new" "$PRD"; then echo UNCHANGED; else cat "$new" > "$PRD"; cat "${new}.msg"; fi
  rm -f "$new" "${new}.msg"
}

case "${1:-}" in
  --precheck) shift; cmd_precheck "$@" ;;
  --mirror-lr) shift; cmd_mirror "$@" ;;
  --rederive) shift; [ "$#" -ge 1 ] || { echo "$USAGE" >&2; exit 2; }
    rc=0; for f in "$@"; do [ -f "$f" ] || { echo "requirements-bookkeeping: no file $f" >&2; exit 2; }; rederive_one "$f" || { echo "STILL-STALE $f (restored)" >&2; rc=1; }; done; exit "$rc" ;;
  --seal) shift; [ "$#" -ge 1 ] || { echo "$USAGE" >&2; exit 2; }
    bash "$SEAL" --record "$ROOT/$STATE" program:requirements-bookkeeping "$@" ;;
  *) echo "$USAGE" >&2; exit 2 ;;
esac
