#!/usr/bin/env bash
# BL-886 receipt: apply.sh hands back the template-derived files and `--finish` re-checks them.
# Usage:
#   bash receipt-bl886.sh [<reconcile dir> [<cells> [<world cache>]]]
# <reconcile dir> is the directory holding the apply.sh under test and its siblings; without it the
# receipt resolves this tree's own by walking up from itself for either install layout. With <cells>
# (space-separated names) only those cells run, each with the ordinary run its world needs: a mutant
# run names its deciding cell and one twin. Without it, or with it empty, every cell runs.
# <world cache> builds the distribution and the four consumer worlds ONCE across invocations: a path
# that does not exist yet is filled by this run's build (taken before any cell touches a world, with
# B and T recorded inside it), and a filled one is copied instead of rebuilt. The worlds depend on no
# reconcile file except settings-merge.sh (the N world's pre-merge), so the cache records that file's
# blob hash and a reuse from a reconcile dir whose settings-merge.sh differs is refused (9), never
# silently served. A cache that exists without its completion sentinel is refused (9), never rebuilt.
#
# ONE DISTRIBUTION, FOUR CONSUMER WORLDS. Between base (1.0.0) and theirs (2.0.0) the distribution
# changes a core script and BOTH QUICKSTART.md.template and settings.json.template, so
# `preclassify.sh --templates` buckets QUICKSTART.md TEMPLATE-PROSE-MERGE and .claude/settings.json
# TEMPLATE-JSON-MERGE wherever the consumer carries them. Each world isolates one claim: a world that
# carried both would withhold the stamp on the prose row alone, and a json regression would then still
# read "stamp at base".
#   P  QUICKSTART.md at base boilerplate, no settings.json                 (the prose claim)
#   J  settings.json the merge WOULD change, no QUICKSTART.md              (the json claim)
#   N  settings.json the merge would NOT change, QUICKSTART.md at base     (json near-miss; the prose
#      row keeps the marker on disk, so "no json record" is read off a marker that exists)
#   C  the J world plus a hook-registration validator naming an unregistered hook (C3)
# A cell prints a vector; the stamp is the `version:` the run left in .claude/.ai-dlc-version.
#   pa  P ordinary                       -> stamp|template-prose-merge rows|sentinel|recorded blob == file   1.0.0|1|1|1
#   pb  pa, --finish, file untouched     -> stamp|finish-template-unmerged rows                            1.0.0|1
#   pc  pa, file changed, --finish       -> the same                                                       2.0.0|0
#   pd  pa, its template: line deleted, --finish (the documented exit)                                     2.0.0|0
#   pf  pa, file merged, ordinary re-run from the SAME base, --finish
#                                        -> recorded blob still the pre-merge one|stamp                    1|2.0.0
#   pg  pa, marker rewritten as an older engine's (classify-hashes, no template-hashes), --finish
#                                        -> stamp|NOTE finish-template-unrecorded rows                     2.0.0|1
#   pe  P ordinary with template-sites.md absent beside apply.sh (`--templates` refuses)
#                                        -> stamp|DECISION template-prose-refused rows|`template-hashes: refused`  1.0.0|1|1
#   pe2 pe, then an ordinary run with the full reconcile dir from the SAME base, then --finish
#                                        -> stamp|template: line recorded                                  1.0.0|1
#   pe3 pe, then an immediate --finish   -> stamp|finish-template-unscanned rows|withheld row routes to a fresh run   1.0.0|1|1
#   pe4 pe, pe's ordinary run again, then --finish (a kept `refused` keeps nothing)
#                                        -> stamp|finish-template-unscanned rows                           1.0.0|1
#   pu  pa, marker made unreadable (chmod 000), --finish -> stamp|finish-template-unverified rows on the marker   1.0.0|1
#   pv  the same run as pu               -> stamp|finish-classify-unverified rows on the marker             1.0.0|1
#   ja  J ordinary                       -> stamp|template-json-merge rows|json template: lines             1.0.0|1|1
#   jb  ja, --finish, file untouched     -> stamp|finish-template-json-unmerged rows                       1.0.0|1
#   jb2 ja, file EDITED but not merged (a blob compare would clear it), --finish                          1.0.0|1
#   jc  ja, settings-merge.sh applied to the live file, --finish                                          2.0.0|0
#   jd  ja, its template: line deleted, --finish                                                          2.0.0|0
#   jn  N ordinary                       -> stamp|template-json-merge rows|json lines|prose lines           1.0.0|0|0|1
#   c3a C ordinary                       -> template-json-merge rows|settings-merge rows                    1|0
#   c3b c3a, --finish                    -> finish-template-json-unmerged rows|settings-merge rows|stamp     1|0|1.0.0
#   c3c c3a, json template: line deleted, --finish -> settings-merge rows|stamp                           1|1.0.0
#   c3d C ordinary with settings-merge.sh absent beside apply.sh (the json test refuses)
#                                        -> template-json-refused rows|settings-merge rows|stamp            1|0|1.0.0
#   c3e c3a, --finish with settings-merge.sh absent beside apply.sh (the recorded json test refuses)
#                                        -> finish-template-json-unmerged rows|settings-merge rows|stamp     1|0|1.0.0
# 0 = every cell answered as above. 1 = a cell did not (one `FAIL <cell>` line each). 9 = the receipt
# could not run (no reconcile dir, or a world could not be built).
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -le 3 ] || { echo "REFUSED: usage: bash receipt-bl886.sh [<reconcile dir> [<cells> [<world cache>]]]" >&2; exit 9; }
REC="${1:-}"; CELLS="${2:-}"; WCACHE="${3:-}"
if [ -z "$REC" ]; then
  # Walk up for the reconcile dir in either layout; never count hops.
  d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ -n "$d" ] && [ "$d" != / ]; do
    for c in "$d/core/skills/ai-dlc-update/reconcile" "$d/.claude/skills/ai-dlc-update/reconcile"; do
      [ -f "$c/apply.sh" ] && { REC="$c"; break 2; }
    done
    d="$(dirname "$d")"
  done
fi
[ -n "$REC" ] && [ -f "$REC/apply.sh" ] && [ -f "$REC/preclassify.sh" ] && [ -f "$REC/settings-merge.sh" ] \
  || { echo "REFUSED: no reconcile dir with apply.sh, preclassify.sh and settings-merge.sh (${REC:-unresolved})" >&2; exit 9; }
command -v jq >/dev/null 2>&1 || { echo "REFUSED: jq is not on PATH; settings-merge.sh needs it" >&2; exit 9; }
want() { [ -z "$CELLS" ] && return 0; case " $CELLS " in *" $1 "*) return 0 ;; esac; return 1; }
R="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl886.XXXXXX")" || exit 9
trap 'rm -rf "$R"' EXIT
gd() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$R/dist" -c user.name=r -c user.email=r@example.invalid \
  -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
TJSON='{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/ai-dlc-x.sh"}]}]}}'
QOLD='# Quickstart

Project: acme

OLD-BOILERPLATE line'
QNEW='# Quickstart

Project: acme

NEW-BOILERPLATE line'
merge_live() { bash "$REC/settings-merge.sh" --consumer "$1/.claude/settings.json" --template "$R/t.json" >/dev/null 2>&1; }
# The world set: what the cells read from $R, and nothing a cell writes. B and T travel with it.
WSET="dist t.json w-P w-J w-N w-C w-P0"
if [ -n "$WCACHE" ] && [ -e "$WCACHE" ]; then
  [ -f "$WCACHE/.complete" ] || { echo "REFUSED: world cache $WCACHE exists without its completion sentinel" >&2; exit 9; }
  _sm="$(git hash-object "$REC/settings-merge.sh" 2>/dev/null)" && [ -n "$_sm" ] && [ "$_sm" = "$(cat "$WCACHE/SM" 2>/dev/null)" ] \
    || { echo "REFUSED: world cache $WCACHE was built with a different settings-merge.sh than $REC/settings-merge.sh" >&2; exit 9; }
  for _w in $WSET; do cp -R "$WCACHE/$_w" "$R/$_w" || { echo "REFUSED: could not copy $_w out of the world cache" >&2; exit 9; }; done
  B="$(cat "$WCACHE/B")" && T="$(cat "$WCACHE/T")" && [ -n "$B" ] && [ -n "$T" ] \
    && [ "$(gd rev-parse -q --verify "${T}^{commit}")" = "$T" ] \
    || { echo "REFUSED: the world cache's B/T do not resolve in its own distribution" >&2; exit 9; }
else
mkdir -p "$R/dist/core/scripts" "$R/dist/templates" && gd init -q || exit 9
printf '1.0.0\n' > "$R/dist/VERSION"
printf '#!/usr/bin/env bash\necho v1\n' > "$R/dist/core/scripts/validate-synthetic.sh"
printf '# Quickstart\n\nProject: {project_name}\n\nOLD-BOILERPLATE line\n' > "$R/dist/templates/QUICKSTART.md.template"
printf '{"hooks":{}}\n' > "$R/dist/templates/settings.json.template"
gd add -A && gd commit -qm base || exit 9
B="$(gd rev-parse HEAD)" || exit 9
printf '2.0.0\n' > "$R/dist/VERSION"
printf '#!/usr/bin/env bash\necho v2\n' > "$R/dist/core/scripts/validate-synthetic.sh"
printf '# Quickstart\n\nProject: {project_name}\n\nNEW-BOILERPLATE line\n' > "$R/dist/templates/QUICKSTART.md.template"
printf '%s\n' "$TJSON" > "$R/dist/templates/settings.json.template"
gd add -A && gd commit -qm theirs || exit 9
T="$(gd rev-parse HEAD)" || exit 9
gd show "${T}:templates/settings.json.template" > "$R/t.json" || exit 9
# mk <world> <quickstart: old|-> <settings: unmerged|merged|-> <validator: ok|unreg>
mk() {
  local c="$R/w-$1"
  mkdir -p "$c/.claude/hooks" "$c/scripts/ai-dlc" || return 1
  printf '#!/usr/bin/env bash\necho v1\n' > "$c/scripts/ai-dlc/validate-synthetic.sh"
  if [ "$4" = ok ]; then printf '#!/usr/bin/env bash\nexit 0\n' > "$c/scripts/ai-dlc/validate-hook-registration.sh"
  else printf '#!/usr/bin/env bash\necho "  UNREGISTERED hooks:"\necho "    .claude/hooks/ai-dlc-x.sh"\nexit 1\n' > "$c/scripts/ai-dlc/validate-hook-registration.sh"; fi
  chmod +x "$c/scripts/ai-dlc/validate-hook-registration.sh" || return 1
  printf '#!/usr/bin/env bash\nexit 0\n' > "$c/.claude/hooks/ai-dlc-x.sh"
  [ "$2" = old ] && printf '%s\n' "$QOLD" > "$c/QUICKSTART.md"
  case "$3" in
    unmerged) printf '{"hooks":{}}\n' > "$c/.claude/settings.json" ;;
    # merged: the merge must have MOVED the file, or the N world could not tell "already merged"
    # from "nothing to merge".
    merged) printf '{"hooks":{}}\n' > "$c/.claude/settings.json" && merge_live "$c" || return 1
            printf '{"hooks":{}}\n' | cmp -s - "$c/.claude/settings.json" && return 1 ;;
  esac
  printf 'version: 1.0.0\ncommit: %s\n' "$B" > "$c/.claude/.ai-dlc-version"
}
mk P old - ok && mk J - unmerged ok && mk N old merged ok && mk C - unmerged unreg \
  && cp -R "$R/w-P" "$R/w-P0" \
  || { echo "REFUSED: a consumer world could not be built" >&2; exit 9; }
# Snapshot BEFORE any cell runs: the sentinel is written last, so a cache it does not carry is half-built.
if [ -n "$WCACHE" ]; then
  mkdir "$WCACHE" || { echo "REFUSED: could not create the world cache $WCACHE" >&2; exit 9; }
  for _w in $WSET; do cp -R "$R/$_w" "$WCACHE/$_w" || { echo "REFUSED: could not fill the world cache" >&2; exit 9; }; done
  _sm="$(git hash-object "$REC/settings-merge.sh")" && [ -n "$_sm" ] && printf '%s\n' "$_sm" > "$WCACHE/SM" \
    && printf '%s\n' "$B" > "$WCACHE/B" && printf '%s\n' "$T" > "$WCACHE/T" && : > "$WCACHE/.complete" \
    || { echo "REFUSED: could not fill the world cache" >&2; exit 9; }
fi
fi
# The reconcile copy for pe: everything beside apply.sh except template-sites.md.
mkdir -p "$R/rec-notpl" && cp "$REC"/* "$R/rec-notpl/" 2>/dev/null && rm -f "$R/rec-notpl/template-sites.md" \
  && [ -f "$R/rec-notpl/apply.sh" ] && [ -f "$R/rec-notpl/preclassify.sh" ] && [ ! -e "$R/rec-notpl/template-sites.md" ] \
  || { echo "REFUSED: could not build the reconcile copy without template-sites.md" >&2; exit 9; }
[ -f "$REC/template-sites.md" ] || { echo "REFUSED: $REC carries no template-sites.md, so no world can bucket a template" >&2; exit 9; }
# The reconcile copy for c3d: everything beside apply.sh except settings-merge.sh.
mkdir -p "$R/rec-nosm" && cp "$REC"/* "$R/rec-nosm/" 2>/dev/null && rm -f "$R/rec-nosm/settings-merge.sh" \
  && [ -f "$R/rec-nosm/apply.sh" ] && [ -f "$R/rec-nosm/template-sites.md" ] && [ ! -e "$R/rec-nosm/settings-merge.sh" ] \
  || { echo "REFUSED: could not build the reconcile copy without settings-merge.sh" >&2; exit 9; }

stampv() { sed -n 's/^version: //p' "$1/.claude/.ai-dlc-version"; }
rows() { awk -F'\t' -v k="$2" -v n="$3" -v p="$4" '$1==k && $2==n && $3==p {c++} END {print c+0}' "$1"; }
mline() { grep -c "^template: .*	$2\$" "$1/.claude/.ai-dlc-applying" 2>/dev/null || true; }
dropline() { # <world dir> <path>: delete that file's own template: line, keep the rest
  [ -f "$1/.claude/.ai-dlc-applying" ] || return 0
  grep -v "^template: .*	$2\$" "$1/.claude/.ai-dlc-applying" > "$R/m.tmp"; cat "$R/m.tmp" > "$1/.claude/.ai-dlc-applying"; }
ord() { bash "${3:-$REC}/apply.sh" "$R/dist" "$B" "$1" "$T" > "$2" 2>/dev/null; }
fin() { bash "${3:-$REC}/apply.sh" --finish "$R/dist" "$B" "$1" "$T" > "$2" 2>/dev/null; }
cp_from() { rm -rf "$R/x-$2"; cp -R "$1" "$R/x-$2" && printf '%s' "$R/x-$2"; }
fails=0
check() { # <cell> <want> <got>
  [ "$3" = "$2" ] || { echo "FAIL $1: want [$2] got [$3]"; fails=$((fails + 1)); }
}
QS=QUICKSTART.md; SJ=.claude/settings.json
# --- the prose world -----------------------------------------------------------------------------
if want pa || want pb || want pc || want pd || want pf || want pg || want pu || want pv; then
  P="$R/w-P"; ord "$P" "$R/pa.out"
  PH="$(git hash-object "$P/$QS")"
  if want pa; then
    ln=0; grep -qxF "template: $PH 644	$QS" "$P/.claude/.ai-dlc-applying" 2>/dev/null && ln=1
    hs=0; grep -qx 'template-hashes: 1' "$P/.claude/.ai-dlc-applying" 2>/dev/null && hs=1
    check pa '1.0.0|1|1|1' "$(stampv "$P")|$(rows "$R/pa.out" WORKLIST template-prose-merge "$QS")|$hs|$ln"
  fi
  if want pb; then x="$(cp_from "$P" pb)"; fin "$x" "$R/pb.out"
    check pb '1.0.0|1' "$(stampv "$x")|$(rows "$R/pb.out" WORKLIST finish-template-unmerged "$QS")"; fi
  if want pc; then x="$(cp_from "$P" pc)"; printf '%s\n' "$QNEW" > "$x/$QS"; fin "$x" "$R/pc.out"
    check pc '2.0.0|0' "$(stampv "$x")|$(rows "$R/pc.out" WORKLIST finish-template-unmerged "$QS")"; fi
  if want pd; then x="$(cp_from "$P" pd)"; dropline "$x" "$QS"; fin "$x" "$R/pd.out"
    check pd '2.0.0|0' "$(stampv "$x")|$(rows "$R/pd.out" WORKLIST finish-template-unmerged "$QS")"; fi
  if want pf; then x="$(cp_from "$P" pf)"; printf '%s\n' "$QNEW" > "$x/$QS"; ord "$x" "$R/pf1.out"
    k=0; grep -qxF "template: $PH 644	$QS" "$x/.claude/.ai-dlc-applying" 2>/dev/null && k=1
    fin "$x" "$R/pf.out"
    check pf '1|2.0.0' "$k|$(stampv "$x")"; fi
  if want pg; then x="$(cp_from "$P" pg)"
    # The older engine's marker is WRITTEN here, not derived from pa's: base, theirs and an empty
    # classify record, the shape every pre-template engine wrote.
    printf 'base: %s\ntheirs: %s\nclassify-hashes: 0\n' "$B" "$T" > "$x/.claude/.ai-dlc-applying"
    fin "$x" "$R/pg.out"
    check pg '2.0.0|1' "$(stampv "$x")|$(rows "$R/pg.out" NOTE finish-template-unrecorded .claude/.ai-dlc-applying)"; fi
  if want pu || want pv; then x="$(cp_from "$P" pu)"
    # No marker after pa is pa's own regression (a mutant that stamped there), scored as these cells
    # failing on the stamp, never as a receipt that could not run. A reader that can still open a
    # mode-000 file (root) would make both cells assert nothing, which is a refusal.
    if [ -f "$x/.claude/.ai-dlc-applying" ]; then chmod 000 "$x/.claude/.ai-dlc-applying"
      [ ! -r "$x/.claude/.ai-dlc-applying" ] || { echo "REFUSED: the pu world's marker is still readable after chmod 000" >&2; exit 9; }
    fi
    fin "$x" "$R/pu.out"; chmod 644 "$x/.claude/.ai-dlc-applying" 2>/dev/null
    want pu && check pu '1.0.0|1' "$(stampv "$x")|$(rows "$R/pu.out" WORKLIST finish-template-unverified .claude/.ai-dlc-applying)"
    want pv && check pv '1.0.0|1' "$(stampv "$x")|$(rows "$R/pu.out" WORKLIST finish-classify-unverified .claude/.ai-dlc-applying)"
  fi
fi
if want pe; then x="$(cp_from "$R/w-P0" pe)"; [ ! -e "$x/.claude/.ai-dlc-applying" ] || { echo "REFUSED: the pe world is not pristine" >&2; exit 9; }; ord "$x" "$R/pe.out" "$R/rec-notpl"
  hs=0; grep -qx 'template-hashes: refused' "$x/.claude/.ai-dlc-applying" 2>/dev/null && hs=1
  check pe '1.0.0|1|1' "$(stampv "$x")|$(rows "$R/pe.out" DECISION template-prose-refused -)|$hs"; fi
if want pe2; then x="$(cp_from "$R/w-P0" pe2)"; ord "$x" "$R/pe2a.out" "$R/rec-notpl"; ord "$x" "$R/pe2b.out"
  ln=0; grep -qxF "template: $(git hash-object "$x/$QS") 644	$QS" "$x/.claude/.ai-dlc-applying" 2>/dev/null && ln=1
  fin "$x" "$R/pe2.out"
  check pe2 '1.0.0|1' "$(stampv "$x")|$ln"; fi
if want pe3; then x="$(cp_from "$R/w-P0" pe3)"; ord "$x" "$R/pe3a.out" "$R/rec-notpl"; fin "$x" "$R/pe3.out"
  # The withheld row must route to a fresh ordinary run, never to --finish: the restamp-withheld
  # wording taken when a row carries the fresh-run remedy (counted in apply.sh's `say`).
  rt=0; awk -F'\t' '$1=="DECISION" && $2=="restamp-withheld" && index($4, "a step only a fresh ordinary run performs") {f=1} END {exit !f}' "$R/pe3.out" && rt=1
  check pe3 '1.0.0|1|1' "$(stampv "$x")|$(rows "$R/pe3.out" WORKLIST finish-template-unscanned .claude/.ai-dlc-applying)|$rt"; fi
if want pe4; then x="$(cp_from "$R/w-P0" pe4)"; ord "$x" "$R/pe4a.out" "$R/rec-notpl"; ord "$x" "$R/pe4b.out" "$R/rec-notpl"; fin "$x" "$R/pe4.out"
  check pe4 '1.0.0|1' "$(stampv "$x")|$(rows "$R/pe4.out" WORKLIST finish-template-unscanned .claude/.ai-dlc-applying)"; fi
# --- the json world ------------------------------------------------------------------------------
if want ja || want jb || want jb2 || want jc || want jd; then
  J="$R/w-J"; ord "$J" "$R/ja.out"
  want ja && check ja '1.0.0|1|1' "$(stampv "$J")|$(rows "$R/ja.out" WORKLIST template-json-merge "$SJ")|$(mline "$J" "$SJ")"
  if want jb; then x="$(cp_from "$J" jb)"; fin "$x" "$R/jb.out"
    check jb '1.0.0|1' "$(stampv "$x")|$(rows "$R/jb.out" WORKLIST finish-template-json-unmerged "$SJ")"; fi
  if want jb2; then x="$(cp_from "$J" jb2)"; printf '{"hooks":{},"unrelated":1}\n' > "$x/$SJ"; fin "$x" "$R/jb2.out"
    check jb2 '1.0.0|1' "$(stampv "$x")|$(rows "$R/jb2.out" WORKLIST finish-template-json-unmerged "$SJ")"; fi
  if want jc; then x="$(cp_from "$J" jc)"; merge_live "$x" || { echo "REFUSED: settings-merge.sh failed on the jc world" >&2; exit 9; }
    fin "$x" "$R/jc.out"
    check jc '2.0.0|0' "$(stampv "$x")|$(rows "$R/jc.out" WORKLIST finish-template-json-unmerged "$SJ")"; fi
  if want jd; then x="$(cp_from "$J" jd)"; dropline "$x" "$SJ"; fin "$x" "$R/jd.out"
    check jd '2.0.0|0' "$(stampv "$x")|$(rows "$R/jd.out" WORKLIST finish-template-json-unmerged "$SJ")"; fi
fi
if want jn; then N="$R/w-N"; ord "$N" "$R/jn.out"
  check jn '1.0.0|0|0|1' "$(stampv "$N")|$(rows "$R/jn.out" WORKLIST template-json-merge "$SJ")|$(mline "$N" "$SJ")|$(mline "$N" "$QS")"; fi
# --- C3: one row per remedy ------------------------------------------------------------------------
# c3d first: it needs the C world before c3a's ordinary run writes into it.
if want c3d; then x="$(cp_from "$R/w-C" c3d)"; ord "$x" "$R/c3d.out" "$R/rec-nosm"
  check c3d '1|0|1.0.0' "$(rows "$R/c3d.out" DECISION template-json-refused "$SJ")|$(rows "$R/c3d.out" WORKLIST settings-merge "$SJ")|$(stampv "$x")"; fi
if want c3a || want c3b || want c3c || want c3e; then
  C="$R/w-C"; ord "$C" "$R/c3a.out"
  want c3a && check c3a '1|0' "$(rows "$R/c3a.out" WORKLIST template-json-merge "$SJ")|$(rows "$R/c3a.out" WORKLIST settings-merge "$SJ")"
  if want c3b; then x="$(cp_from "$C" c3b)"; fin "$x" "$R/c3b.out"
    check c3b '1|0|1.0.0' "$(rows "$R/c3b.out" WORKLIST finish-template-json-unmerged "$SJ")|$(rows "$R/c3b.out" WORKLIST settings-merge "$SJ")|$(stampv "$x")"; fi
  if want c3c; then x="$(cp_from "$C" c3c)"; dropline "$x" "$SJ"; fin "$x" "$R/c3c.out"
    check c3c '1|1.0.0' "$(rows "$R/c3c.out" WORKLIST settings-merge "$SJ")|$(stampv "$x")"; fi
  if want c3e; then x="$(cp_from "$C" c3e)"; fin "$x" "$R/c3e.out" "$R/rec-nosm"
    check c3e '1|0|1.0.0' "$(rows "$R/c3e.out" WORKLIST finish-template-json-unmerged "$SJ")|$(rows "$R/c3e.out" WORKLIST settings-merge "$SJ")|$(stampv "$x")"; fi
fi
[ "$fails" -eq 0 ] || exit 1
exit 0
