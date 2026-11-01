#!/usr/bin/env bash
# enforcement-map-yaml-plain — enforcement-map.yaml stays loadable by a real YAML parser: no
# PLAIN mapping value may carry a mapping indicator (`: `, or a `:` that ends a line).
#
# Usage: run.sh [path-to-enforcement-map.yaml]
#        With no argument the map is resolved from the tree this fixture sits in, in either
#        layout (below). The argument exists so the check can be pointed at any copy of the map,
#        e.g. a historical one saved to a temp file, to prove the arm fires. It is POSITIONAL, not
#        an environment variable, because the hermetic scrub below unsets every AI_DLC_* name.
# Exit:  0 = every plain value is clean, 1 = an offending value (each named by line and key), or
#        the map is absent in both layouts, 2 = fixture broken (self-probe or mutant failed).
#
# WHY THIS FIXTURE EXISTS. The map is read by about forty-five tracked files, and every one of
# them parses it with a LINE grammar (awk, sed, a Python regex block-parser, a JS line loop) —
# none loads it as YAML. So the file drifted out of YAML without any reader noticing: seven
# multi-line plain scalars (`posture:`, `why:`, `asserts:`) carried a `: ` or a line-final `:`,
# and `yaml.safe_load` and Ruby Psych both refused the file at the first of them
# ("mapping values are not allowed here", line 129 column 66 at e91b4d86). Every in-repo reader
# stayed green, which is exactly why a reader-side check cannot catch this: the defect is
# invisible to the grammar every reader uses. The repair double-quoted the seven values, which
# keeps every token on its original line, and this fixture keeps them that way.
#
# WHY IT SHIPS. Its subject is the map, and the map ships: install.sh copies it into the
# consumer's `.claude/skills/ai-dlc/` and the update pull maps the whole skill directory. A
# consumer tool that loads the map as YAML is the reader this protects, and that reader lives on
# the consumer side.
#
# WHY PURE AWK. A consumer box is not guaranteed PyYAML or Ruby, and a check that SKIPs when its
# parser is missing reads as green on exactly the trees it never examined. The grammar below is
# the subset of YAML plain-scalar scanning that produces this error, measured against both real
# parsers when it was written:
#
#   - a mapping value is PLAIN when it does not open with `"`, a single quote, `|`, `>`, `[` or
#     `{`. Only a plain value can carry the defect; a quoted or flow value terminates on its own
#     delimiter and a block scalar's body is literal text.
#   - a plain value OFFENDS when its key line, or any continuation line of it (more indented
#     than the key column), contains `:` followed by a space, a tab, or the end of the line.
#     The END-OF-LINE case is not optional: one of the seven (the Check 22 posture, `...and never
#     judged:`) offended ONLY that way, and PyYAML and Psych both reject it. A more-indented
#     `name: value` line under a plain value is NOT a nested mapping to YAML — it is the same
#     defect, and the parser says so — so continuation lines are not exempted by shape.
#   - a block scalar (`key: >-`, `key: |`, any chomping or indentation indicator) is TRACKED and
#     its body skipped. Without that, a colon-space inside a `why: >-` body is a false positive:
#     the first naive scan of the map flagged exactly one (the Step 6 roll `why`), which both
#     parsers accept.
#   - a ` #` tail is a comment and not part of the value, and a whole-line comment is skipped.
#
# HOW THE FALSE-POSITIVE SET REACHED ZERO. Against the e91b4d86 map this grammar reports exactly
# the seven values the two parsers reject, in the order they reject them when fixed one at a time
# (129, 139, 165, 228, 440, 751, 1376 by value start), and nothing else — the block-scalar
# tracking is the narrowing that removed the one false positive. Against the repaired map it
# reports zero and both parsers load the file.
set -uo pipefail

# HERMETIC -- scrub the operator's tuning before reading anything (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"

# BOTH LAYOUTS, by walking UP for a project-root marker and then naming each layout's map path
# outright — never by counting `..` hops (I33). The walk STOPS at the first root it finds: a
# worktree nested inside another checkout must not fall through to the outer checkout's map and
# pass on a file this tree does not carry.
#   distribution: <root>/core/skills/ai-dlc/enforcement-map.yaml
#   consumer:     <root>/.claude/skills/ai-dlc/enforcement-map.yaml   (scripts/install.sh)
resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
MAP="${1:-}"
if [ -z "$MAP" ]; then
  ROOT="$(resolve_root "$HERE" || true)"
  for c in "$ROOT/core/skills/ai-dlc/enforcement-map.yaml" "$ROOT/.claude/skills/ai-dlc/enforcement-map.yaml"; do
    [ -n "$ROOT" ] && [ -f "$c" ] && { MAP="$c"; break; }
  done
fi

echo "enforcement-map-yaml-plain:"

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
# shellcheck source=/dev/null
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: lib/mutant.sh not found" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
# B_FOLD=1 only beside the unmutated grammar's own ok on the folded near-miss: the mutant is scored only if that base arm passed.
B_FOLD=0

# =============================================================================
# THE GRAMMAR — one program, used by the self-probe, the mutant and the real map.
# =============================================================================
# Output: one `HIT<TAB>value-start-line<TAB>key<TAB>offending-line` per offending value (a value
# is reported ONCE, at its first offending line), then `SCANNED<TAB>plain<TAB>block` — the count
# of plain and block-scalar values it classified. A program that read nothing prints zeros there,
# and the real-map arm refuses that rather than reading it as clean.
# This text is a single-quoted shell string: it must carry no apostrophe, so the single-quote
# opener is passed in as `q`.
SCAN='
function strip_c(s,   p) {
  if (s ~ /^#/) return ""
  p = match(s, /[ \t]#/)
  if (p) s = substr(s, 1, p - 1)
  sub(/[ \t]+$/, "", s)
  return s
}
function has_ind(s) { return (s ~ /:([ \t]|$)/) }
function report(at) { printf "HIT\t%d\t%s\t%d\n", start, skey, at; hit = 1 }
{
  line = $0
  if (line ~ /^[ \t]*$/) next
  match(line, /^ */); ind = RLENGTH
  body = substr(line, ind + 1)
  # Inside a value opened above: a line indented past its key column belongs to it.
  if (mode != "" && ind > kcol) {
    if (mode == "plain" && !hit && body !~ /^#/ && has_ind(strip_c(body))) report(NR)
    next
  }
  mode = ""; hit = 0
  if (body ~ /^#/) next
  rest = body; col = ind
  while (rest ~ /^-( |$)/) { match(rest, /^-[ ]*/); col += RLENGTH; rest = substr(rest, RLENGTH + 1) }
  key = ""
  if (rest ~ /^[^ #:"][^:]*:([ \t]|$)/ && substr(rest, 1, 1) != q) {
    key = rest; sub(/:.*/, "", key)
    v = substr(rest, length(key) + 2)
  } else {
    v = rest
  }
  v = strip_c(v); sub(/^[ \t]+/, "", v)
  if (v == "") next
  c1 = substr(v, 1, 1)
  if (c1 == "|" || c1 == ">") { mode = "skip"; nblock++; kcol = (key == "" ? ind : col); next }
  if (key == "") next
  kcol = col
  if (c1 == "\"" || c1 == q || c1 == "[" || c1 == "{") { mode = "skip"; next }
  mode = "plain"; start = NR; skey = key; nplain++
  if (has_ind(v)) report(NR)
}
END { printf "SCANNED\t%d\t%d\n", nplain, nblock }
'
printf '%s\n' "$SCAN" > "$WORK/scan.awk"
scan() { awk -v q="'" -f "$1" "$2"; }   # scan <program> <yaml> -> HIT/SCANNED lines
hits() { local o; o="$(scan "$1" "$2")" || return 2; awk -F'\t' '$1=="HIT"{print $2}' <<<"$o"; }

# =============================================================================
# 1. SELF-PROBE, before the real map: seeded offenders are REPORTED, near-misses stay QUIET.
# =============================================================================
# Every near-miss carries the offender text verbatim, so a quiet near-miss is a statement about
# the SPELLING the grammar reads (quoting, block scalar, nesting), never about the words.
P="$WORK/probe"; mkdir -p "$P"
TXT1='FAILS the gate (exit 0 required; exit 0 with `OK: EXAMINED NOTHING` is'
TXT2='a pass) and so on'
hdr() { printf 'checks:\n  - id: "1"\n    call_sites:\n      - site: x.md Check 1\n'; }
{ hdr; printf '        posture: start of a value\n          %s\n          %s\n' "$TXT1" "$TXT2"; } > "$P/off-cont.yaml"
{ hdr; printf '        posture: %s\n          %s\n' "$TXT1" "$TXT2"; } > "$P/off-key.yaml"
{ hdr; printf '        posture: rows the guard did not write are never judged:\n          the ledger is append-only\n'; } > "$P/off-eol.yaml"
{ hdr; printf '        posture: "start of a value\n          %s\n          %s"\n' "$TXT1" "$TXT2"; } > "$P/nm-dquote.yaml"
{ hdr; printf "        posture: 'start of a value\n          %s\n          %s'\n" "$TXT1" "$TXT2"; } > "$P/nm-squote.yaml"
{ hdr; printf '        posture: >-\n          start of a value\n          %s\n          %s\n' "$TXT1" "$TXT2"; } > "$P/nm-folded.yaml"
{ hdr; printf '        posture: |2\n          start of a value\n          %s\n' "$TXT1"; } > "$P/nm-literal.yaml"
{ hdr; printf '        nested:\n          key: value\n          other: [a, b]\n        posture: plain words only\n'; } > "$P/nm-nested.yaml"
{ hdr; printf '        posture: see http://x and https://y/z for the rule\n          continued without one\n'; } > "$P/nm-url.yaml"
{ hdr; printf '        posture: plain words only # a comment: with a colon\n'; } > "$P/nm-comment.yaml"

# OFFENDERS: each must report exactly ONE value, at the line its value starts (5).
for f in off-cont off-key off-eol; do
  h="$(hits "$WORK/scan.awk" "$P/$f.yaml")"
  if [ "$h" = "5" ]; then
    ok "PROBE offender $f is REPORTED, once, at the line its value starts"
  else
    bad "PROBE offender $f read '$(tr '\n' ' ' <<<"$h")', wanted '5' -- the grammar cannot see this shape, so a clean real map would mean nothing"
  fi
done
# NEAR-MISSES: the same text, spelled legally. Each must be quiet AND must have been classified
# (a SCANNED total above zero), so silence from a program that read nothing cannot pass.
for f in nm-dquote nm-squote nm-folded nm-literal nm-nested nm-url nm-comment; do
  o="$(scan "$WORK/scan.awk" "$P/$f.yaml")"
  h="$(awk -F'\t' '$1=="HIT"{print $2}' <<<"$o")"
  seen="$(awk -F'\t' '$1=="SCANNED"{print $2+$3}' <<<"$o")"
  if [ -z "$h" ] && [ "${seen:-0}" -gt 0 ]; then
    ok "PROBE near-miss $f is quiet (and $seen value(s) were classified)"
  else
    bad "PROBE near-miss $f read hits='$(tr '\n' ' ' <<<"$h")' classified='${seen:-none}' -- the grammar flags a legal spelling, or read nothing"
  fi
done

# =============================================================================
# 2. MUTANT: block-scalar tracking disabled must turn the folded near-miss red.
# =============================================================================
# The tracking is the narrowing that removed the measured false positive (a colon-space inside a
# `why: >-` body). A grammar without it would still report all seven real offenders, so only a
# mutant shows the line is load-bearing. Anchor: the one line that opens a block scalar.
ANCHOR='if (c1 == "|" || c1 == ">") {'
n_anchor="$(grep -cF -- "$ANCHOR" "$WORK/scan.awk")" || n_anchor=0
if [ "$n_anchor" -ne 1 ]; then
  bad "MUTANT: the block-scalar anchor matches $n_anchor line(s), not 1 -- re-anchor it, never relax the arm"
else
  awk -v a="$ANCHOR" '{ p = index($0, a); if (p) $0 = substr($0, 1, p - 1) "if (0) {" substr($0, p + length(a)); print }' \
    "$WORK/scan.awk" > "$WORK/scan-mut.awk"
  if cmp -s "$WORK/scan.awk" "$WORK/scan-mut.awk"; then
    bad "MUTANT DID NOT APPLY: disabling block-scalar tracking changed no bytes"
  else
    h_base="$(hits "$WORK/scan.awk" "$P/nm-folded.yaml")"
    if [ -z "$h_base" ]; then ok "BASE: the unmutated grammar keeps the folded near-miss quiet"; B_FOLD=1
    else bad "BASE: the unmutated grammar reported the folded near-miss '$(tr '\n' ' ' <<<"$h_base")' -- the mutant below would be scored against a grammar that already fails"; fi
    h_mut="$(hits "$WORK/scan-mut.awk" "$P/nm-folded.yaml")"
    h_off="$(hits "$WORK/scan-mut.awk" "$P/off-cont.yaml")"
    # Positive control on the SAME mutant: it still runs and still reports the offender, so a
    # kill below is the folded body being misread, not a program that died.
    if [ "$h_off" = "5" ] && [ "$h_mut" = "5" ]; then
      mutant_killed "$B_FOLD" "block-scalar-tracking" "MUTANT killed: without block-scalar tracking the folded near-miss is REPORTED at line 5 (and the mutant still reports the real offender)"
    else
      bad "MUTANT survived or broke: folded near-miss read '$(tr '\n' ' ' <<<"$h_mut")', offender read '$(tr '\n' ' ' <<<"$h_off")' -- wanted 5 and 5"
    fi
  fi
fi

if [ "$fails" -ne 0 ]; then
  echo; echo "enforcement-map-yaml-plain: FIXTURE BROKEN -- the self-probe or the mutant failed, so the real map is not read" >&2
  exit 2
fi

# =============================================================================
# 3. THE REAL MAP.
# =============================================================================
if [ -z "$MAP" ] || [ ! -f "$MAP" ]; then
  echo "  FAIL  enforcement-map.yaml not found${MAP:+ at $MAP} -- looked for core/skills/ai-dlc/ and .claude/skills/ai-dlc/ under the project root walked up from $HERE. The map ships in both layouts; its absence is a broken install, not a pass."
  echo; echo "enforcement-map-yaml-plain: FAIL" >&2
  exit 1
fi
echo "HERMETIC-CONSUMED $(cd "$(dirname "$MAP")" && pwd)/${MAP##*/}"
out="$(scan "$WORK/scan.awk" "$MAP")" || { echo "FIXTURE ERROR: awk failed on $MAP" >&2; exit 2; }
np="$(awk -F'\t' '$1=="SCANNED"{print $2}' <<<"$out")"
nb="$(awk -F'\t' '$1=="SCANNED"{print $3}' <<<"$out")"
# Plain values only: a map with no block scalars is legal YAML, and the mutant above already
# proves the block-scalar branch runs.
if [ "${np:-0}" -gt 0 ]; then
  ok "CONTROL: the map was read -- ${np} plain and ${nb:-0} block-scalar value(s) classified"
else
  bad "CONTROL: the map classified plain=${np:-none} block=${nb:-none} -- a scan that read nothing cannot report clean"
fi
found="$(awk -F'\t' '$1=="HIT"{print "line " $2 " (" $3 ":, mapping indicator at line " $4 ")"}' <<<"$out")"
if [ -z "$found" ]; then
  ok "no plain value in the map carries a mapping indicator -- the file stays loadable as YAML"
else
  while IFS= read -r f; do
    bad "PLAIN VALUE CARRIES A MAPPING INDICATOR (':' before whitespace or end of line) -- $f. A YAML parser rejects the whole file here. Double-quote the value (escape any \" or \\ inside) so every token stays on its line."
  done <<<"$found"
fi

echo
if [ "$fails" -eq 0 ]; then echo "enforcement-map-yaml-plain: PASS"; exit 0; fi
echo "enforcement-map-yaml-plain: $fails assertion(s) FAILED" >&2
exit 1
