#!/bin/bash
# BL-706 receipt. usage: receipt-bl706.sh [<reconcile dir> [<reader> [<cell groups>]]]; any cwd.
#   Drives the SHIPPING reconcile/apply.sh (and the helper beside it) over seeded pulls, then the reader
#   (check-owed-derivations.sh) over the record each leaves. One line per cell:  CELL <id> ok|FAIL <what>
#   exit 0   every cell run holds
#   exit 1   a cell failed
#   exit 9   the receipt cannot measure: a subject is missing, or a world could not be built
#   <cell groups> is a space-separated subset of: a bd c e f g h i j k   (default: all). A mutant battery passes
#   only the groups where its mutant decides, plus its twins.
#   Cells: a  core paths changed, no fence names them -> record present with 0 OWED rows (the reader prints it)
#          b  a derivation reading a changed file its command line never names -> NEWLY-FAILING, recorded
#          c  no fence in scope -> record created
#          d  the same range run twice -> the row is recorded exactly once
#          e  a refusal (no resolvable base root) -> record ABSENT and apply.sh emits the DECISION row
#          f  the tree did not move -> record created, no validator run, both core shas named
#          g  a write AFTER the old call site changes a verdict -> still found (the call sits after the writes)
#          h  an exported VD_ALL changes neither apply.sh's WORKLIST join nor the helper's non-record join
#          i  an apply that writes ONLY an ignored file a derivation reads: the short-circuit (stamp walk) records exactly what
#             the full differential (--base-root, a worktree that holds no ignored file) records; both ignored-file shapes
#          j  a fence naming a moved path whose derivation newly fails draws ONE WORKLIST row (artifact-derivations), no -owed row
#          k  a scope-classifier failure draws ONE artifact-derivations DECISION row (-unscoped), no -differential refusal row
#          l  (inside bd) the record's field 7 is the name of the NOTE reconcile-log-name row apply.sh printed, and has the
#             reconcile-log-<UTC stamp>.md shape the reader classes as HISTORY
#          e2 (inside e) the refusal row's hand remedy carries --base-root where the refusal is base-root
#   The negative for cell a (the code before this change leaves NO record on the same world) is the mutant that
#   deletes the call; run.sh scores it. This script never names a git ref of the distribution.
set -uo pipefail
H="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -e "$c" ] && { printf '%s' "$c"; return; }; done; }
RECON="$(pick "${1:-}" "$H/../../skills/ai-dlc-update/reconcile" "$H/../../../.claude/skills/ai-dlc-update/reconcile")"
RD="$(pick "${2:-}" "$H/../../scripts/check-owed-derivations.sh" "$H/../../../scripts/ai-dlc/check-owed-derivations.sh")"
VAL="$(pick "$H/../../scripts/validate-artifact-derivations.sh" "$H/../../../scripts/ai-dlc/validate-artifact-derivations.sh")"
GROUPS_RUN="${3:-a bd c e f g h i j k}"
[ -n "$RECON" ] && [ -f "$RECON/apply.sh" ] && [ -f "$RECON/derivation-differential.sh" ] && [ -n "$RD" ] && [ -n "$VAL" ] || exit 9
RECON="$(cd "$RECON" && pwd)"; RD="$(cd "$(dirname "$RD")" && pwd)/$(basename "$RD")"; VAL="$(cd "$(dirname "$VAL")" && pwd)/$(basename "$VAL")"
D="$(mktemp -d "${TMPDIR:-/tmp}/bl706rcpt.XXXXXX")" || exit 9
[ -d "$D" ] || exit 9
g() { local d="$1"; shift; git -C "$d" -c user.name=r -c user.email=r@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
stub() { printf '#!/usr/bin/env bash\n[ "${1:-}" = sprint-id ] || exit 2\nshift; r=""; [ "${1:-}" = --root ] && r="${2:-}"\n[ -f "$r/.sprint-id" ] || exit 1\ncat "$r/.sprint-id"\n' > "$1/sprint-status.sh"; }
REC=_bmad-output/ai-dlc-update/owed-derivations.tsv
fails=0
cell() { # <id> <0|1 holds> <what>
  if [ "$2" = 0 ]; then printf 'CELL %s ok %s\n' "$1" "$3"; else printf 'CELL %s FAIL %s\n' "$1" "$3"; fails=$((fails + 1)); fi
}
rows() { awk -F'\t' -v a="$2" -v b="$3" '$1 == a && ($2 == b || b == "") { n++ } END { print n + 0 }' <<<"$1"; }

# ---- the distribution: toy.sh changes in the range (qqalpha -> qqgamma); stable.sh and relo.sh do not --------------
DIST="$D/dist"; mkdir -p "$DIST/core/scripts" || exit 9; g "$DIST" init -q || exit 9
printf '1.0.0\n' > "$DIST/VERSION"
printf 'qqalpha\n' > "$DIST/core/scripts/toy.sh"; printf 'qqx\n' > "$DIST/core/scripts/stable.sh"
printf 'qqold\n' > "$DIST/core/scripts/relo.sh"; printf '#!/usr/bin/env bash\necho v\n' > "$DIST/core/scripts/validate-synthetic.sh"
g "$DIST" add -A; g "$DIST" commit -qm base
BASE="$(g "$DIST" rev-parse HEAD)"
printf '2.0.0\n' > "$DIST/VERSION"; printf 'qqgamma\n' > "$DIST/core/scripts/toy.sh"
g "$DIST" add -A; g "$DIST" commit -qm theirs
THEIRS="$(g "$DIST" rev-parse HEAD)"
[ -n "$BASE" ] && [ -n "$THEIRS" ] && [ "$BASE" != "$THEIRS" ] || exit 9
# DIST2: the same range plus a new core file the consumer's .gitignore ignores, so an apply writes ONLY an ignored path.
DIST2="$D/dist2"; mkdir -p "$DIST2/core/scripts" || exit 9; g "$DIST2" init -q || exit 9
printf '1.0.0\n' > "$DIST2/VERSION"
printf 'qqalpha\n' > "$DIST2/core/scripts/toy.sh"; printf 'qqx\n' > "$DIST2/core/scripts/stable.sh"
printf 'qqold\n' > "$DIST2/core/scripts/relo.sh"; printf '#!/usr/bin/env bash\necho v\n' > "$DIST2/core/scripts/validate-synthetic.sh"
g "$DIST2" add -A; g "$DIST2" commit -qm base
BASE2="$(g "$DIST2" rev-parse HEAD)"
printf '2.0.0\n' > "$DIST2/VERSION"; printf 'qqgamma\n' > "$DIST2/core/scripts/toy.sh"; printf 'qqx\n' > "$DIST2/core/scripts/ignnew.sh"
g "$DIST2" add -A; g "$DIST2" commit -qm theirs
THEIRS2="$(g "$DIST2" rev-parse HEAD)"
[ -n "$BASE2" ] && [ -n "$THEIRS2" ] && [ "$BASE2" != "$THEIRS2" ] || exit 9

# mkc <dir> <variant> [<stamp commit>] -> a consumer committed at the pre-pull tree, stamped at BASE
#   clean (fence on stable.sh) | hidden (fence greps scripts/ai-dlc/ without naming toy.sh) | nofence
#   | relo (fence on the legacy path scripts/relo.sh, which the apply deletes) | atheirs (the apply writes no tracked path)
mkc() {
  local c="$1" v="$2" stamp="${3:-$BASE}"
  mkdir -p "$c/scripts/ai-dlc" "$c/.claude" "$c/_bmad-output" || return 1; g "$c" init -q || return 1
  cp "$RD" "$c/scripts/ai-dlc/check-owed-derivations.sh" && stub "$c/scripts/ai-dlc" || return 1
  printf '#!/usr/bin/env bash\nexit 0\n' > "$c/scripts/ai-dlc/validate-hook-registration.sh"; chmod +x "$c/scripts/ai-dlc/validate-hook-registration.sh"
  # the installed validator is a wrapper that logs each start beside the world, then runs the real one
  printf '#!/usr/bin/env bash\necho run >> "%s/validator.ran"\nexec bash "%s" "$@"\n' "$(dirname "$c")" "$VAL" > "$c/scripts/ai-dlc/validate-artifact-derivations.sh"
  printf '1\n' > "$c/.sprint-id"
  printf 'qqalpha\n' > "$c/scripts/ai-dlc/toy.sh"; printf 'qqx\n' > "$c/scripts/ai-dlc/stable.sh"
  printf '#!/usr/bin/env bash\necho v\n' > "$c/scripts/ai-dlc/validate-synthetic.sh"
  printf 'version: 1.0.0\ncommit: %s\n' "$stamp" > "$c/.claude/.ai-dlc-version"
  case "$v" in
    clean)  printf '# Story\n\n```derived\n$ grep -c qqx scripts/ai-dlc/stable.sh\n1\n```\n' > "$c/_bmad-output/story.md" ;;
    hidden) printf '# Story\n\n```derived\n$ grep -rl qqalpha scripts/ai-dlc\nscripts/ai-dlc/toy.sh\n```\n' > "$c/_bmad-output/story.md" ;;
    nofence) printf '# Story\n\nno derivation here\n' > "$c/_bmad-output/story.md" ;;
    relo)   printf 'qqold\n' > "$c/scripts/relo.sh"; printf '# Story\n\n```derived\n$ grep -c qqold scripts/relo.sh\n1\n```\n' > "$c/_bmad-output/story.md" ;;
    named)  printf '# Story\n\n```derived\n$ grep -c qqalpha scripts/ai-dlc/toy.sh\n1\n```\n' > "$c/_bmad-output/story.md" ;;
    ign)    printf 'qqgamma\n' > "$c/scripts/ai-dlc/toy.sh"; printf 'qqold\n' > "$c/scripts/ai-dlc/relo.sh"
            printf 'scripts/ai-dlc/ignnew.sh\nscripts/ai-dlc/ignop.txt\n' > "$c/.gitignore"; printf 'qqz\n' > "$c/scripts/ai-dlc/ignop.txt"
            printf '# Story\n\n```derived\n$ grep -rl qqx scripts/ai-dlc\nscripts/ai-dlc/stable.sh\n```\n\n```derived\n$ grep -c qqz scripts/ai-dlc/ignop.txt\n1\n```\n' > "$c/_bmad-output/story.md" ;;
    atheirs) printf 'qqgamma\n' > "$c/scripts/ai-dlc/toy.sh"; printf 'qqold\n' > "$c/scripts/ai-dlc/relo.sh"
             printf '# Story\n\n```derived\n$ grep -c qqx scripts/ai-dlc/stable.sh\n1\n```\n' > "$c/_bmad-output/story.md" ;;
  esac
  g "$c" add -A; g "$c" commit -qm "pull"
}
apply() { APPLY_OUT="$(cd / && TMPDIR="$D" bash "$RECON/apply.sh" "$DIST" "$BASE" "$1" "$THEIRS" 2>/dev/null)"; APPLY_RC=$?; }
rd() { ( cd / && AI_DLC_PROJECT_ROOT="$1" bash "$1/scripts/ai-dlc/check-owed-derivations.sh" 2>&1 ); }
owed_rows() { awk -F'\t' '$1 == "OWED" { n++ } END { print n + 0 }' "$1/$REC" 2>/dev/null || echo 0; }
sent() { awk 'END { print NR + 0 }' "$1/validator.ran" 2>/dev/null || echo 0; }
apply2() { APPLY_OUT="$(cd / && TMPDIR="$D" bash "$RECON/apply.sh" "$DIST2" "$BASE2" "$1" "$THEIRS2" 2>/dev/null)"; APPLY_RC=$?; }
dd2() { ( cd / && TMPDIR="$D" bash "$RECON/derivation-differential.sh" "$DIST2" "$BASE2" "$@" 2>&1 ); }
okeys() { awk -F'\t' '$1 == "OWED" { print $2 }' "$1" 2>/dev/null | sort | paste -sd, - ; }
dd_direct() { ( cd / && TMPDIR="$D" bash "$RECON/derivation-differential.sh" "$DIST" "$BASE" "$@" 2>&1 ); }

cell_a() {
  local w="$D/wa" out n
  mkdir -p "$w"; mkc "$w/c" clean || exit 9
  apply "$w/c"; out="$(rd "$w/c")"; n="$(sent "$w")"
  local ok=1
  [ -f "$w/c/$REC" ] && [ "$(owed_rows "$w/c")" = 0 ] && case "$out" in UNMEASURED:*"present with 0 OWED rows"*) ok=0 ;; esac
  cell a "$ok" "record present with 0 OWED rows after an apply whose fence names no changed path (reader: ${out:-<empty>})"
  cell a2 "$([ "$n" -ge 2 ] && echo 0 || echo 1)" "a full differential ran the validator on both sides (starts $n >= 2), so cell f's 0 is a measurement"
  cell a3 "$([ "$(rows "$APPLY_OUT" WORKLIST artifact-derivations)" = 0 ] && [ "$(rows "$APPLY_OUT" DECISION artifact-derivations-differential)" = 0 ] && echo 0 || echo 1)" "a measured-clean pull draws no artifact-derivations row"
}
cell_bd() {
  local w="$D/wb" b_n b_w d_n
  mkdir -p "$w"; mkc "$w/c" hidden || exit 9
  apply "$w/c"
  b_n="$(owed_rows "$w/c")"; b_w="$(rows "$APPLY_OUT" WORKLIST artifact-derivations-owed)"
  cell b "$([ "$b_n" = 1 ] && [ "$b_w" = 1 ] && echo 0 || echo 1)" "the NEWLY-FAILING derivation is recorded ($b_n OWED row(s), want 1) and apply.sh draws the WORKLIST row ($b_w, want 1)"
  local nm fld shape=1
  nm="$(awk -F'\t' '$1 == "NOTE" && $2 == "reconcile-log-name" { n = $3; sub(/.*\//, "", n); print n; exit }' <<<"$APPLY_OUT")"
  fld="$(awk -F'\t' '$1 == "OWED" { print $7; exit }' "$w/c/$REC" 2>/dev/null)"
  case "$nm" in reconcile-log-[0-9]*T[0-9]*Z.md) shape=0 ;; esac
  cell l "$([ -n "$nm" ] && [ "$nm" = "$fld" ] && [ "$shape" = 0 ] && echo 0 || echo 1)" "the record's field 7 ('${fld:-<none>}') is the name on the NOTE reconcile-log-name row ('${nm:-<none>}'), shaped reconcile-log-<UTC stamp>.md ($shape, want 0)"
  dd_direct "$w/c" "$THEIRS" --record-owed "$w/c/$REC" --log-name reconcile-log-again.md >/dev/null
  d_n="$(owed_rows "$w/c")"
  cell d "$([ "$d_n" = 1 ] && echo 0 || echo 1)" "a second run of the same range leaves $d_n OWED row(s) (want 1)"
}
cell_c() {
  local w="$D/wc" out
  mkdir -p "$w"; mkc "$w/c" nofence || exit 9
  apply "$w/c"; out="$(rd "$w/c")"
  cell c "$([ -f "$w/c/$REC" ] && [ "$(owed_rows "$w/c")" = 0 ] && echo 0 || echo 1)" "no fence in scope: record created with 0 OWED rows (reader: ${out:-<empty>})"
}
cell_e() {
  local w="$D/we" ref t
  mkdir -p "$w"; mkc "$w/c" clean 0000000000000000000000000000000000000000 || exit 9
  apply "$w/c"
  ref="$(awk -F'\t' '$1 == "DECISION" && $2 == "artifact-derivations-differential" { print $4; exit }' <<<"$APPLY_OUT")"
  case "$ref" in *"REFUSED"*"base-root"*) t=0 ;; *) t=1 ;; esac
  local hand=1; case "$(awk -F'\t' '$1 == "DECISION" && $2 == "artifact-derivations-differential" { print $4; exit }' <<<"$APPLY_OUT")" in *'`'*"--base-root <a checkout"*'`'*) hand=0 ;; esac
  cell e2 "$hand" "the base-root refusal's hand remedy names --base-root ($hand, want 0)"
  cell e "$([ ! -e "$w/c/$REC" ] && [ "$(rows "$APPLY_OUT" DECISION artifact-derivations-differential)" = 1 ] && [ "$t" = 0 ] && echo 0 || echo 1)" "a refused measurement leaves the record absent ($([ -e "$w/c/$REC" ] && echo present || echo absent)) and apply.sh emits the DECISION row quoting the REFUSED line ($(rows "$APPLY_OUT" DECISION artifact-derivations-differential), quoted: $t)"
}
cell_f() {
  local w="$D/wf" n info names
  mkdir -p "$w"; mkc "$w/c" atheirs || exit 9
  apply "$w/c"; n="$(sent "$w")"
  # the helper alone on a fresh copy of the world: the apply above re-stamps, which is a movement the helper sees afterwards
  mkdir -p "$D/wf2"; mkc "$D/wf2/c" atheirs || exit 9
  info="$(dd_direct "$D/wf2/c" "$THEIRS" --record-owed "$D/wf2/c/$REC" | awk -F'\t' '$1 == "INFO" && $2 == "unmoved"')"
  names=1; case "$info" in *"$BASE"*"$THEIRS"*) names=0 ;; esac
  cell f "$([ -f "$w/c/$REC" ] && [ "$n" = 0 ] && [ "$names" = 0 ] && [ -f "$D/wf2/c/$REC" ] && echo 0 || echo 1)" "tree did not move: record created, $n validator start(s) from apply.sh (want 0), INFO row names both core shas ($names)"
}
cell_g() {
  local w="$D/wg"
  mkdir -p "$w"; mkc "$w/c" relo || exit 9
  apply "$w/c"
  cell g "$([ "$(owed_rows "$w/c")" = 1 ] && [ ! -e "$w/c/scripts/relo.sh" ] && echo 0 || echo 1)" "the relocation that deletes scripts/relo.sh runs, and the derivation it breaks is recorded ($(owed_rows "$w/c") OWED row(s), want 1; old path $([ -e "$w/c/scripts/relo.sh" ] && echo still-present || echo removed))"
}
cell_h() {
  local w="$D/wh" wl dd
  mkdir -p "$w"; mkc "$w/c" clean || exit 9
  APPLY_OUT="$(cd / && VD_ALL=1 TMPDIR="$D" bash "$RECON/apply.sh" "$DIST" "$BASE" "$w/c" "$THEIRS" 2>/dev/null)"
  wl="$(rows "$APPLY_OUT" WORKLIST artifact-derivations)"
  mkdir -p "$D/wh2"; mkc "$D/wh2/c" clean || exit 9
  dd="$(VD_ALL=1 dd_direct "$D/wh2/c" "$THEIRS")"
  local ref=1; case "$dd" in *$'REFUSED\tjoin\tno fenced derivation names a path this range changed'*) ref=0 ;; esac
  cell h "$([ "$wl" = 0 ] && [ "$ref" = 0 ] && echo 0 || echo 1)" "with VD_ALL=1 exported apply.sh draws $wl artifact-derivations WORKLIST row(s) (want 0) and the non-record helper still refuses on the join ($ref)"
}

cell_i() {
  local w="$D/wi" c wk fl
  # X: an ignored OPERAND only (ignop.txt, absent from the base worktree): the base run fails it, the consumer run passes it.
  # Y: X plus the ignored file the apply writes (ignnew.sh), which a directory-walking derivation reads: the base run passes
  #    it (no such file there), the consumer run fails it, so the full differential scores it NEWLY-FAILING.
  # Each world is run twice by the helper itself: the stamp walk (the short-circuit applies) and --base-root a worktree of the
  # pre-pull commit (always the full run). The two records must be equal.
  local xk yk xw yw xf yf
  for t in x y; do
    mkdir -p "$w/$t"; mkc "$w/$t/c" ign "$BASE2" || exit 9
  done
  printf 'qqx\n' > "$w/y/c/scripts/ai-dlc/ignnew.sh"
  for t in x y; do
    c="$w/$t/c"
    g "$c" worktree add -q --detach "$w/$t/base" HEAD >/dev/null 2>&1 || exit 9
    # the oracle's base root is the PRE-pull tree: toy.sh as core had it at BASE2, so the full run's two-sides-differ control holds
    printf 'qqalpha\n' > "$w/$t/base/scripts/ai-dlc/toy.sh"
    dd2 "$c" "$THEIRS2" --record-owed "$w/$t/walk.tsv" >/dev/null
    dd2 "$c" "$THEIRS2" --base-root "$w/$t/base" --record-owed "$w/$t/full.tsv" >/dev/null
  done
  xw="$(okeys "$w/x/walk.tsv")"; xf="$(okeys "$w/x/full.tsv")"; yw="$(okeys "$w/y/walk.tsv")"; yf="$(okeys "$w/y/full.tsv")"
  cell i "$([ -f "$w/x/walk.tsv" ] && [ -f "$w/y/walk.tsv" ] && [ -f "$w/x/full.tsv" ] && [ -f "$w/y/full.tsv" ] && [ "$xw" = "$xf" ] && [ "$yw" = "$yf" ] && [ -z "$xf" ] && [ -n "$yf" ] && echo 0 || echo 1)" "short-circuit and full differential record the same rows over an ignored operand (walk '$xw' / full '$xf', want both empty) and over an ignored file a directory walk reads (walk '$yw' / full '$yf', want equal and non-empty)"
  # the apply-driven leg: the shipping apply.sh writes ONLY the ignored file, and the derivation it breaks is recorded
  mkdir -p "$w/z"; mkc "$w/z/c" ign "$BASE2" || exit 9
  apply2 "$w/z/c"
  local prem=1; [ -f "$w/z/c/scripts/ai-dlc/ignnew.sh" ] && grep -q qqx "$w/z/c/scripts/ai-dlc/ignnew.sh" && prem=0
  cell i2 "$([ "$prem" = 0 ] && [ "$(owed_rows "$w/z/c")" = 1 ] && echo 0 || echo 1)" "apply.sh wrote the ignored file (premise $prem, want 0) and recorded the derivation it broke ($(owed_rows "$w/z/c") OWED row(s), want 1)"
}
cell_j() {
  local w="$D/wj" wl ow n
  mkdir -p "$w"; mkc "$w/c" named || exit 9
  apply "$w/c"
  wl="$(rows "$APPLY_OUT" WORKLIST artifact-derivations)"; ow="$(rows "$APPLY_OUT" WORKLIST artifact-derivations-owed)"; n="$(owed_rows "$w/c")"
  local named=1; case "$(awk -F'\t' '$1 == "WORKLIST" && $2 == "artifact-derivations" { print $4; exit }' <<<"$APPLY_OUT")" in *"story.md:"*) named=0 ;; esac
  cell j "$([ "$wl" = 1 ] && [ "$ow" = 0 ] && [ "$n" = 1 ] && [ "$named" = 0 ] && echo 0 || echo 1)" "a fence naming a moved path that newly fails draws $wl WORKLIST artifact-derivations row (want 1) naming the key ($named, want 0), $ow -owed row(s) (want 0), and records $n OWED row(s) (want 1)"
}
cell_k() {
  local w="$D/wk" un df
  mkdir -p "$w"; mkc "$w/c" named || exit 9
  rm -f "$w/c/.sprint-id"
  apply "$w/c"
  un="$(rows "$APPLY_OUT" DECISION artifact-derivations-unscoped)"; df="$(rows "$APPLY_OUT" DECISION artifact-derivations-differential)"
  cell k "$([ "$un" = 1 ] && [ "$df" = 0 ] && [ ! -e "$w/c/$REC" ] && echo 0 || echo 1)" "a scope-classifier failure draws $un artifact-derivations-unscoped DECISION row (want 1) and $df -differential refusal row(s) (want 0); the record stays $([ -e "$w/c/$REC" ] && echo present || echo absent) (want absent)"
}

for grp in $GROUPS_RUN; do
  case "$grp" in
    a) cell_a ;; bd) cell_bd ;; c) cell_c ;; e) cell_e ;; f) cell_f ;; g) cell_g ;; h) cell_h ;; i) cell_i ;; j) cell_j ;; k) cell_k ;;
    *) printf 'receipt-bl706: unknown cell group %s\n' "$grp" >&2; exit 9 ;;
  esac
done
printf 'WORLDS %s\n' "$D"
[ "$fails" = 0 ]
