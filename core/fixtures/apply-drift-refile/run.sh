#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# apply-drift-refile/run.sh — prove apply.sh AUTOMATES the known_skills drift migration: refile the
# in-place addition to extensions/known-skills.json and revert the core schema, with no manual step.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"

# ---------------------------------------------------------------------------- shards ----
# THIS FILE IS THREE SHARDS OF ONE FIXTURE, AND THE SPLIT IS A SCHEDULING BOUNDARY, NOT A SUBJECT
# BOUNDARY. Every arm below is a UNIT guarded by `if sg <unit>; then ... fi`. `--group <x>` runs the units dealt to
# shard <x>; `apply-drift-refile-{b,c}/run.sh` are one-line drivers that `exec bash` this file with their group,
# so the pre-push pool starts each on its own. No `--group` runs shard 'a'. The seed and the sanity arms are not
# units: every shard builds the seed and runs them, and every helper a unit uses is hoisted above the units.
#
# THE COVERAGE JOIN runs in EVERY shard before anything else: the declared units are DERIVED from this
# file's own `if sg <unit>; then` lines, the dealt lists must be disjoint and their union must equal the
# declared set exactly, and every declared shard must have a driver directory. The join proves it can
# fire first, on a seeded duplicate and a seeded omission.
#   a  base fh r w         Assertions 1-9b; BL-230 arms f/h; BL-336 r; BL-414 w
#   b  y t                 BL-413 arm y (the CLASSIFY record); arm t
#   c  q v u x s          BL-402 arm q; BL-413 arm v; arm u; BL-364 x; BL-360 s
SHARDS="a b c"
UNITS_a="base fh r w"
UNITS_b="y t"
UNITS_c="q v u x s"
GROUP=a
if [ "${1:-}" = "--group" ]; then
  GROUP="${2:-}"
  [ -n "$GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; }
fi
case " $SHARDS " in
  *" $GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;;
esac
eval "MINE=\"\${UNITS_$GROUP:-}\""
NAME="apply-drift-refile"; [ "$GROUP" = a ] || NAME="apply-drift-refile-$GROUP"
shard_broken() { echo "$NAME: FIXTURE BROKEN — $1" >&2; exit 2; }
[ -n "$MINE" ] || shard_broken "shard '$GROUP' has no UNITS_$GROUP list; a shard dealt nothing passes everything it never checked"
sg() { case " $MINE " in *" $1 "*) return 0 ;; esac; return 1; }
SELF="$0"
[ -f "$SELF" ] || shard_broken "cannot read $SELF for the coverage join"
partition_ok() { # <declared ids file> <dealt ids file> -> 0 when dealt is disjoint and covers declared exactly
  local dup miss extra
  dup="$(sort "$2" | uniq -d | tr '\n' ' ')"
  miss="$(sort -u "$2" | comm -23 <(sort -u "$1") - | tr '\n' ' ')"
  extra="$(sort -u "$2" | comm -13 <(sort -u "$1") - | tr '\n' ' ')"
  [ -z "$dup$miss$extra" ] && return 0
  echo "dealt twice: {${dup% }} dealt to no shard: {${miss% }} dealt but not declared: {${extra% }}"
  return 1
}
JW="$(mktemp -d "${TMPDIR:-/tmp}/apply-drift-join.XXXXXX")" || shard_broken "mktemp failed"
printf '%s\n' u1 u2 u3 > "$JW/pd"; printf '%s\n' u1 u2 u2 u3 > "$JW/pdup"; printf '%s\n' u1 u3 > "$JW/pmiss"; printf '%s\n' u3 u1 u2 > "$JW/pok"
if partition_ok "$JW/pd" "$JW/pdup" >/dev/null || partition_ok "$JW/pd" "$JW/pmiss" >/dev/null \
   || ! partition_ok "$JW/pd" "$JW/pok" >/dev/null; then
  rm -rf "$JW"; shard_broken "the coverage join's self-probe did not discriminate (duplicate, omission, exact)"
fi
sed -n 's/^[[:space:]]*if sg \([a-z0-9_][a-z0-9_]*\); then$/\1/p' "$SELF" > "$JW/declared"
for _s in $SHARDS; do eval "printf '%s\n' \${UNITS_$_s}" | tr ' ' '\n'; done | grep . > "$JW/dealt"
ndecl="$(grep -c . "$JW/declared")" || ndecl=0
ndupdecl="$(sort "$JW/declared" | uniq -d | grep -c .)" || ndupdecl=0
if [ "$ndecl" -eq 0 ] || [ "$ndupdecl" -ne 0 ]; then
  rm -rf "$JW"; shard_broken "$ndecl unit guards derived from $SELF ($ndupdecl declared twice)"
fi
if ! _why="$(partition_ok "$JW/declared" "$JW/dealt")"; then
  rm -rf "$JW"; shard_broken "the shard partition does not cover the guarded units exactly -- $_why"
fi
for _s in $SHARDS; do
  [ "$_s" = a ] && continue
  _drv="$HERE/../apply-drift-refile-$_s/run.sh"
  if [ ! -f "$_drv" ] || ! grep -qF -- "--group $_s" "$_drv"; then
    rm -rf "$JW"; shard_broken "shard '$_s' is declared but $_drv does not drive it"
  fi
done
rm -rf "$JW"
echo "  [J0] coverage join: $ndecl units derived from the sg guards, dealt disjointly across {$SHARDS}, union exact; this shard runs {$MINE}"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# EVERY WORLD IS BUILT ONCE AND COPIED seed.sh runs here and nowhere else:
# its output is kept untouched in $SEED_TPL before any arm writes to $WORK, and seed_copy hands each later
# cell a `cp -Rp` of it with env.sh's paths rewritten (seed.sh's inputs never vary, so every copy is the
# world a fresh seed.sh would build). world_once does the same for the in-file builders (h_world, t_aworld,
# u_world, x_world): the first call per builder and argument list builds the template, every call returns a copy.
SEED_TPL="$(mktemp -d "$WORK/.seed-tpl.XXXXXX")" && cp -Rp "$WORK/dist" "$WORK/consumer" "$WORK/env.sh" "$SEED_TPL/" \
  || { echo "FIXTURE ERROR: could not keep the seed template" >&2; exit 2; }
seed_copy() { # seed_copy [<parent dir, default $WORK>] -> path of a fresh copy of the seed world
  local c; c="$(mktemp -d "${1:-$WORK}/apply-drift.XXXXXX")" || return 1
  cp -Rp "$SEED_TPL/." "$c/" && sed "s|$WORK|$c|g" "$SEED_TPL/env.sh" > "$c/env.sh" || return 1
  printf '%s\n' "$c"
}
world_once() { # world_once <copy prefix> <builder> [<arg>...] -> path of a fresh copy of the world `<builder> <arg>...` builds
  # The template is keyed on the builder AND its FULL argument list, %q-quoted so no two lists share a key;
  # $WORK/.tpl.idx maps each key to its template's number. Builders run inside $( ), so the map lives on disk.
  local p="$1" k l t="" n=0 b c; shift
  printf -v k '%q ' "$@"
  if [ -f "$WORK/.tpl.idx" ]; then
    while IFS= read -r l; do n=$((n + 1)); [ "${l#*	}" = "$k" ] && t="$WORK/.tpl.${l%%	*}"; done < "$WORK/.tpl.idx"
  fi
  if [ -z "$t" ]; then
    t="$WORK/.tpl.$((n + 1))"
    b="$("$@")" && [ -n "$b" ] && [ -d "$b" ] && mv "$b" "$t" || return 1
    printf '%s\t%s\n' "$((n + 1))" "$k" >> "$WORK/.tpl.idx" || return 1
  fi
  c="$(mktemp -d "$WORK/$p.XXXXXX")" && cp -Rp "$t/." "$c/" || return 1
  printf '%s' "$c"
}
# shellcheck source=/dev/null
. "$WORK/env.sh"
echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/"

fails=0; asserts=0
ok()  { printf '  ok    %s\n' "$1"; asserts=$((asserts+1)); }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserts=$((asserts+1)); }

# Helpers hoisted above the units: units use each other's worlds, so a helper inside a unit another shard owns would be undefined there.
# THE FORCING MECHANISM (arms q, r, t). The `did not run` row (apply.sh, the ap_ks_diff failure branch) needs
# the UD read to SUCCEED and the diff to FAIL. A mode-000 schema cannot do that: the union gate re-renders
# unregistered-drift.sh first, that detector then exits 2 on the unreadable schema, the region mismatches and
# apply refuses at the union gate BEFORE the refile loop. So only the diff is starved: ks_hook adds, to a
# COPY of the reconcile dir, one statement after ap_ks_diff's diff that sets ap_drc=2 when FX_KSDIFF_FAIL=1.
# Unset, the copy is the shipped program (ks_ctl_ready runs it unforced as the near-miss).
KS_A='ap_d="$(ap_pdiff "$AP_TMP/theirs" "$2" 2>/dev/null)"; ap_drc=$?'
ks_hook() { # ks_hook <reconcile-copy-dir> -> 0 when the hook was added exactly once and the copy parses
  local d="$1" n
  n="$(grep -cF -- "$KS_A" "$d/apply.sh")" || n=0
  [ "$n" = 1 ] || return 1
  KS_A="$KS_A" awk '{ i = index($0, ENVIRON["KS_A"]); if (i) $0 = $0 "; if [ \"${FX_KSDIFF_FAIL:-}\" = 1 ]; then ap_drc=2; fi"; print }' \
    "$d/apply.sh" > "$d/apply.sh.hk" || return 1
  mv "$d/apply.sh.hk" "$d/apply.sh"
  grep -qF 'FX_KSDIFF_FAIL' "$d/apply.sh" && bash -n "$d/apply.sh"
}
HK="$WORK/ks-ctl"; KS_READY=""
ks_ctl_ready() { # builds the hooked shipped copy once and runs it UNFORCED once as the near-miss; sets KS_READY=ok|<why>
  [ -n "$KS_READY" ] && return 0
  local w nm
  if ! { cp -R "$(dirname "$APPLY")" "$HK" && ks_hook "$HK"; }; then
    KS_READY="the ap_ks_diff anchor is not in apply.sh exactly once, so the diff-failure hook cannot be added"; bad "FIXTURE BROKEN [forcing hook]: $KS_READY"; return 0
  fi
  w="$(seed_copy)" || { KS_READY="seed failed"; bad "FIXTURE BROKEN [forcing near-miss]: $KS_READY"; return 0; }
  eval "$(sed 's/^/KN_/' "$w/env.sh")"
  nm="$(bash "$HK/apply.sh" "$KN_DIST" "$KN_BASE" "$KN_CONSUMER" "$KN_THEIRS" 2>/dev/null)"
  if ! grep -q 'did not run' <<<"$nm" && grep -q 'drift-refile' <<<"$nm"; then
    KS_READY=ok
    ok "forcing near-miss: the hooked copy, UNFORCED, refiles the drift and draws no did-not-run row (the row in arms q, r, t appears only because the diff is starved)"
  else
    KS_READY="the hooked copy unforced is not the shipped program (did-not-run row present or no drift-refile row)"
    bad "FIXTURE BROKEN [forcing near-miss]: $KS_READY"
  fi
}
norow_note() { # norow_note <apply-stdout> <apply-stderr-file> -> records which gate refused, for an arm that lost its row
  { printf 'stderr: %s | decisions: ' "$(head -c 300 "$2" 2>/dev/null | tr '\n\t' '  ')"
    awk -F'\t' '$1=="DECISION" {printf "%s ", $2}' <<<"$1"; } > "$WORK/norow.why"
}
q_base() { # q_base <hooked-reconcile-dir> -> ONE forced ordinary run; sets QT (the post-run world, cloned per case), QT_OUT, QT_ERR
  local w; w="$(seed_copy)" || return 1
  eval "$(sed 's/^/QB_/' "$w/env.sh")"
  QT="$w"; QT_ERR="$w/apply.err"
  QT_OUT="$(FX_KSDIFF_FAIL=1 bash "$1/apply.sh" "$QB_DIST" "$QB_BASE" "$QB_CONSUMER" "$QB_THEIRS" 2>"$QT_ERR")"
  return 0
}
q_world() { # q_world <W|H|X> -> sets Q_* from a clone of the q_base world (env.sh paths rewritten)
  local c; c="$(mktemp -d "$WORK/qc.XXXXXX")" || return 1
  cp -R "$QT/." "$c/" || return 1
  sed "s|$QT|$c|g" "$QT/env.sh" > "$c/env.sh" || return 1
  eval "$(sed 's/^/Q_/' "$c/env.sh")"
  Q_OUT="$QT_OUT"
  if [ "$1" != W ]; then
    mkdir -p "$(dirname "$Q_EXT")" || return 1
    printf '{\n  "known_skills": [\n    "my-persona-skill"\n  ]\n}\n' > "$Q_EXT" || return 1
    git -C "$Q_DIST" show "${Q_THEIRS}:core/schemas/provenance-block.json" > "$Q_SCHEMA" || return 1
  fi
  if [ "$1" = X ]; then chmod +x "$Q_CONSUMER/scripts/ai-dlc/validate-synthetic.sh" || return 1; fi
  return 0
}
Q_WANT='-|-|OWED|STAMPED|-|EXEC'
q_score() { # q_score <hooked-reconcile-dir> [worlds] -> the six cells (`.` for a world not asked for), or NOROW / BROKEN
  local rec="$1" ws=" ${2:-qW qH qX} " c1=. c2=. c3=. c4=. c5=. c6=. fo
  q_base "$rec" || { printf 'BROKEN'; return; }
  grep -q 'did not run' <<<"$QT_OUT" || { norow_note "$QT_OUT" "$QT_ERR"; printf 'NOROW'; return; }
  case "$ws" in *" qW "*)
    q_world W || { printf 'BROKEN'; return; }
    c1="$(awk -F'\t' '$1=="DECISION" && $2=="restamp-withheld" && index($4, "--finish") {f=1} END {print (f ? "F" : "-")}' <<<"$Q_OUT")"
    fo="$(bash "$rec/apply.sh" --finish "$Q_DIST" "$Q_BASE" "$Q_CONSUMER" "$Q_THEIRS" 2>/dev/null)"
    c2="$(grep -qE '^version: 9\.9\.9$' "$Q_STAMP" && echo STAMPED || echo -)"
    c3="$(awk -F'\t' '$1=="WORKLIST" && $2=="finish-refile-owed" && index($4, "my-persona-skill") {f=1} END {print (f ? "OWED" : "-")}' <<<"$fo")" ;;
  esac
  case "$ws" in *" qH "*)
    q_world H || { printf 'BROKEN'; return; }
    bash "$rec/apply.sh" --finish "$Q_DIST" "$Q_BASE" "$Q_CONSUMER" "$Q_THEIRS" >/dev/null 2>&1
    c4="$(grep -qE '^version: 9\.9\.9$' "$Q_STAMP" && echo STAMPED || echo -)" ;;
  esac
  case "$ws" in *" qX "*)
    q_world X || { printf 'BROKEN'; return; }
    fo="$(bash "$rec/apply.sh" --finish "$Q_DIST" "$Q_BASE" "$Q_CONSUMER" "$Q_THEIRS" 2>/dev/null)"
    c5="$(grep -qE '^version: 9\.9\.9$' "$Q_STAMP" && echo STAMPED || echo -)"
    c6="$(awk -F'\t' '$1=="WORKLIST" && $2=="finish-exec-owed" && $3=="scripts/ai-dlc/validate-synthetic.sh" {f=1} END {print (f ? "EXEC" : "-")}' <<<"$fo")" ;;
  esac
  printf '%s|%s|%s|%s|%s|%s' "$c1" "$c2" "$c3" "$c4" "$c5" "$c6"
}
# h_world / h_score are hoisted: used by arm h.
# h_world -> a fresh zero-work world under $WORK, refs recorded IN it as .B/.T
h_world() { world_once zr h_world_build; }
h_world_build() {
  local _h; _h="$(mktemp -d "$WORK/zr.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
  mkdir -p "$_h/dist/core/scripts" "$_h/dist/core/rules" "$_h/cons/scripts" "$_h/cons/.claude/rules"
  printf '#!/usr/bin/env bash\necho x\n' > "$_h/dist/core/scripts/x.sh"
  printf 'rule\n' > "$_h/dist/core/rules/r.md"; printf '0.1.0\n' > "$_h/dist/VERSION"
  git -C "$_h/dist" init -q 2>/dev/null || { echo "FIXTURE ERROR: h git init failed" >&2; exit 2; }
  git -C "$_h/dist" -c user.email=f@f -c user.name=fixture add -A >/dev/null 2>&1
  git -C "$_h/dist" -c user.email=f@f -c user.name=fixture commit -q -m base >/dev/null 2>&1 \
    || { echo "FIXTURE ERROR: h base commit failed" >&2; exit 2; }
  git -C "$_h/dist" rev-parse HEAD > "$_h/.B"
  printf '0.2.0\n' > "$_h/dist/VERSION"
  git -C "$_h/dist" rm -q core/scripts/x.sh >/dev/null 2>&1
  git -C "$_h/dist" -c user.email=f@f -c user.name=fixture commit -qam theirs >/dev/null 2>&1 \
    || { echo "FIXTURE ERROR: h theirs commit failed" >&2; exit 2; }
  git -C "$_h/dist" rev-parse HEAD > "$_h/.T"
  printf '#!/usr/bin/env bash\necho x\n' > "$_h/cons/scripts/x.sh"
  printf 'rule\n' > "$_h/cons/.claude/rules/r.md"
  printf 'version: 0.1.0\ncommit: %s\n' "$(cat "$_h/.B")" > "$_h/cons/.claude/.ai-dlc-version"
  if [ "$(git -C "$_h/dist" diff --no-renames --name-status "$(cat "$_h/.B")" "$(cat "$_h/.T")" -- core/)" != "$(printf 'D\tcore/scripts/x.sh')" ]; then
    echo "FIXTURE ERROR: h world's range is not a lone core/scripts/x.sh deletion" >&2; exit 2
  fi
  printf '%s' "$_h"
}
# h_score <recon-dir> -> empty, or what failed
h_score() {
  local _h _o _rc _m=""
  _h="$(h_world)"; [ -n "$_h" ] && [ -d "$_h/cons" ] || { printf 'world-not-built'; return; }
  _o="$(bash "$1/apply.sh" "$_h/dist" "$(cat "$_h/.B")" "$_h/cons" "$(cat "$_h/.T")" 2>&1)"; _rc=$?
  printf '%s\n' "$_o" > "$_h/apply.out"
  [ "$_rc" -eq 0 ] || _m="${_m}apply-rc=$_rc "
  [ -f "$_h/cons/scripts/x.sh" ] || _m="${_m}scripts/x.sh-removed "
  if grep -q 'unhandled-bucket' <<<"$_o"; then _m="${_m}unhandled-bucket-row "; fi
  grep -qE '^(RESOLVED|DECISION|NOTE)	' <<<"$_o" || _m="${_m}no-manifest "
  printf '%s' "$_m"
}
t_aworld() { world_once t t_aworld_build "$1"; } # t_aworld <add-persona 0|1> -> path of a fresh world, refs in .B/.T
t_aworld_build() {
  local _w _d _c
  _w="$(mktemp -d "$WORK/t.XXXXXX")" || return 1
  _d="$_w/dist"; _c="$_w/cons"
  mkdir -p "$_d/core/schemas" "$_d/core/scripts" "$_c/.claude/schemas" "$_c/scripts/ai-dlc" || return 1
  printf '#!/usr/bin/env bash\necho v\n' > "$_d/core/scripts/validate-synthetic.sh"
  printf '#!/usr/bin/env bash\necho v\n' > "$_c/scripts/ai-dlc/validate-synthetic.sh"
  printf '{\n  "known_skills": [\n    "bmad-party-mode",\n    "retired-skill"\n  ]\n}\n' > "$_d/core/schemas/provenance-block.json"
  printf '9.9.9\n' > "$_d/VERSION"
  git -C "$_d" init -q && git -C "$_d" -c user.email=f@f -c user.name=fixture add -A \
    && git -C "$_d" -c user.email=f@f -c user.name=fixture commit -qm base || return 1
  git -C "$_d" rev-parse HEAD > "$_w/.B"
  printf '{\n  "known_skills": [\n    "bmad-party-mode"\n  ]\n}\n' > "$_d/core/schemas/provenance-block.json"
  git -C "$_d" -c user.email=f@f -c user.name=fixture commit -qam theirs || return 1
  git -C "$_d" rev-parse HEAD > "$_w/.T"
  if [ "$1" = 1 ]; then
    printf '{\n  "known_skills": [\n    "bmad-party-mode",\n    "retired-skill",\n    "my-persona-skill"\n  ]\n}\n' > "$_c/.claude/schemas/provenance-block.json"
  else
    git -C "$_d" show "$(cat "$_w/.B"):core/schemas/provenance-block.json" > "$_c/.claude/schemas/provenance-block.json" || return 1
  fi
  printf 'version: 0.0.1\ncommit: %s\n' "$(cat "$_w/.B")" > "$_c/.claude/.ai-dlc-version"
  printf '%s' "$_w"
}
u_world() { world_once u u_world_build; }
u_world_build() {
  local _w _d _c _ld i
  _w="$(mktemp -d "$WORK/u.XXXXXX")" || return 1
  _d="$_w/dist"; _c="$_w/cons"
  _ld="$(printf '%075d' 0 | tr 0 d)"
  mkdir -p "$_d/core/session-driver/$_ld" "$_d/core/scripts" "$_c/.claude/session-driver/$_ld" "$_c/scripts/ai-dlc" || return 1
  printf '#!/usr/bin/env bash\necho v\n' > "$_d/core/scripts/validate-synthetic.sh"
  printf '#!/usr/bin/env bash\necho v\n' > "$_c/scripts/ai-dlc/validate-synthetic.sh"
  i=0; while [ "$i" -lt 100 ]; do printf 'v1 %s\n' "$i" > "$_d/core/session-driver/$_ld/f$(printf %03d "$i")"; i=$((i+1)); done
  printf '9.9.9\n' > "$_d/VERSION"
  git -C "$_d" init -q && git -C "$_d" -c user.email=f@f -c user.name=fixture add -A \
    && git -C "$_d" -c user.email=f@f -c user.name=fixture commit -qm base || return 1
  git -C "$_d" rev-parse HEAD > "$_w/.B"
  i=0; while [ "$i" -lt 100 ]; do printf 'v2 %s\n' "$i" > "$_d/core/session-driver/$_ld/f$(printf %03d "$i")"; i=$((i+1)); done
  git -C "$_d" -c user.email=f@f -c user.name=fixture commit -qam theirs || return 1
  git -C "$_d" rev-parse HEAD > "$_w/.T"
  i=0; while [ "$i" -lt 100 ]; do printf 'v1 %s\n' "$i" > "$_c/.claude/session-driver/$_ld/f$(printf %03d "$i")"; i=$((i+1)); done
  printf '%s' "$_w"
}

echo "$NAME:"

# --- Assertion 0: SANITY — the drift is present before ------------------------
if grep -q "my-persona-skill" "$SCHEMA" && [ ! -f "$EXT" ]; then
  ok "before: skill added to core schema in place, no extension file"
else
  bad "FIXTURE BROKEN — starting state wrong"; echo; echo "apply-drift-refile: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 0b: SANITY — the driver starts at v1 and upstream has v2 -------
# Without this, "the driver was not updated" below could pass against a seed that never
# staged an update in the first place.
if grep -q 'driver v1' "$DRIVER" && grep -q 'driver v2' <<<"$(git -C "$DIST" show "$THEIRS:core/session-driver/ai-dlc-session-driver.sh")"; then
  ok "before: consumer driver at v1, upstream at v2 (a real UPSTREAM-ONLY delta to apply)"
else
  bad "FIXTURE BROKEN — no staged session-driver update"; echo; echo "apply-drift-refile: FIXTURE BROKEN" >&2; exit 2
fi

if sg base; then
# --- Run the resolution driver -----------------------------------------------
MANIFEST="$(bash "$APPLY" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null)"

# --- Assertion 1: manifest reports the refile as RESOLVED --------------------
grep -q "drift-refile" <<<"$MANIFEST" && ok "manifest: RESOLVED drift-refile (not handed to the operator)" \
  || bad "manifest did not report a drift-refile"

# --- Assertion 2: the extension now registers the skill ----------------------
if [ -f "$EXT" ] && grep -q "my-persona-skill" "$EXT"; then
  ok "extensions/known-skills.json created with the consumer's skill"
else
  bad "extension file not created / missing the skill"
fi

# --- Assertion 3: the core schema is reverted (drift gone) --------------------
if ! grep -q "my-persona-skill" "$SCHEMA"; then
  ok "core schema reverted — the in-place drift is gone"
else
  bad "core schema still carries the in-place edit — drift not cleared"
fi

# --- Assertion 4: the stamp was re-stamped -----------------------------------
# THE PATTERN IS LINE-ANCHORED AND ITS DOTS ARE ESCAPED, AND SO IS ASSERTION 8'S. Read the
# two together: this arm is the POSITIVE CONTROL for the pattern assertion 8 uses in the
# absence direction. It runs against a genuinely advanced stamp, before line 116 resets it,
# so an over-anchored pattern is caught HERE as a red rather than silently making assertion
# 8's third conjunct permanently true. Keep the two spellings byte-identical.
if grep -qE '^version: 9\.9\.9$' "$STAMP"; then
  ok "stamp re-stamped to theirs (version 9.9.9)"
else
  bad "stamp not updated"
fi

# --- Assertion 5: a core/ subtree apply.sh never hand-listed still APPLIES ----
# THE DEFECT. consumer_path() enumerated destinations by hand and omitted session-driver,
# ci-templates and git-hooks, so core/session-driver/** hit `*) return 1` and never applied
# — while the same run re-stamped, leaving a tree whose stamp claims a version it does not
# have. It escaped notice because the only upstream delta the driver had ever carried was a
# mode bit (100644 -> 100755) that install.sh had already set, so nothing observable broke.
if grep -q 'driver v2 UPSTREAM' "$DRIVER"; then
  ok "core/session-driver/ applied — apply.sh maps every core/ subtree, not a hand-listed set"
else
  bad "core/session-driver/ did NOT apply (still: $(head -2 "$DRIVER" | tail -1)) — apply.sh's mapper omits a subtree the pull classified and the installer ships"
fi

# --- Assertion 6: the manifest must not report a mapping failure --------------
if grep -q "unmapped-path" <<<"$MANIFEST"; then
  bad "apply.sh emitted DECISION unmapped-path — it cannot resolve a path preclassify mapped and install.sh writes: $(printf '%s\n' "$MANIFEST" | grep unmapped-path | head -1)"
else
  ok "no DECISION unmapped-path — the mapper is total, so nothing silently falls through"
fi

# --- Assertion 8: severed from its mapper, apply.sh must REFUSE, not guess ----
# The delegation is only safe if a failure to load map_consumer() is loud. A silent fallback
# to a private table is the defect this whole change removes: it would place some subtrees,
# skip others, and stamp as though everything landed.
#
# THE STAMP CONJUNCT IS LINE-ANCHORED AND ITS DOTS ARE ESCAPED, AND THAT IS THE WHOLE POINT
# OF THIS COMMENT. It was `grep -q "9.9.9" "$STAMP"`, and the line below writes the 40-char
# BASE SHA into that same file — so `.` as a BRE wildcard matched `9?9?9` anywhere in the
# sha and the arm reported the guard broken while the stamp sat untouched at 0.0.1.
# Measured over 2,000,000 sampled 40-char hex shas: 0.83% carry the pattern, so the arm
# false-failed on roughly one push in a hundred, passed on re-run, and passed standalone —
# which reads exactly like a parallel-dispatch flake and is not one. Reproduced serially and
# deterministically by pinning the seed's commit dates so BASE landed on
# 909c5a406e18b144d25d50e92f522989b9ebcb7a (`989b9`), with a control one second later that
# passed. apply.sh writes a SHORT sha here, and seven hex characters carry the pattern too,
# so shortening the field is not a fix. Anchor the version LINE; never match a bare version
# literal against a file that also holds a revision.
printf 'version: 0.0.1\ncommit: %s\n' "$BASE" > "$STAMP"
LONE="$WORK/lone/apply.sh"; mkdir -p "$WORK/lone"; cp "$APPLY" "$LONE"
LONE_OUT="$(bash "$LONE" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>&1)"; lone_rc=$?
if [ "$lone_rc" -ne 0 ] && grep -q "could not load map_consumer" <<<"$LONE_OUT" && ! grep -qE '^version: 9\.9\.9$' "$STAMP"; then
  ok "apply.sh with no map_consumer to load refuses loudly and leaves the stamp alone (it never guesses a path)"
else
  bad "apply.sh with no map_consumer did NOT fail closed (rc=$lone_rc) — it either guessed consumer paths or stamped anyway"
fi

# --- Assertion 9: the SECOND consumer of that mapper must also refuse ---------
# unregistered-drift.sh delegates to the same map_consumer(). It cannot fail closed the way
# apply.sh does — it never writes — so silence IS its failure mode: an unrunnable scan and a
# clean tree print the same empty output, and hard-blockers.sh reads both as 0 blockers.
UD="$(dirname "$APPLY")/unregistered-drift.sh"
LONE_UD="$WORK/lone/unregistered-drift.sh"; cp "$UD" "$LONE_UD"
# LONE OF preclassify.sh ONLY (the map_consumer source this arm removes): the detector also SOURCES
# consumer-read.sh, and a copy without it exits 2 at that line, before the arm's subject.
cp "$(dirname "$UD")/consumer-read.sh" "$WORK/lone/consumer-read.sh"
UD_OUT="$(bash "$LONE_UD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>&1)"
if grep -q '^HARD-DRIFT-SCAN-UNAVAILABLE' <<<"$UD_OUT"; then
  ok "unregistered-drift.sh with no map_consumer to load emits a HARD row (an unrunnable scan never reads as clean)"
else
  bad "unregistered-drift.sh with no map_consumer printed no HARD row: $(printf '%s' "$UD_OUT" | tr '\n' '|' | cut -c1-200)"
fi

# --- Assertion 9b: ANTI-VACUITY — the scan is alive when the sibling is there -
# Without this, 9 passes on a script that is broken for every input.
UD_OK="$(bash "$UD" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>&1)"
if [ -n "$UD_OK" ] && ! grep -q '^HARD-DRIFT-SCAN-UNAVAILABLE' <<<"$UD_OK"; then
  ok "with preclassify.sh beside it the same script scans and reports — the HARD row is the mapper, not a dead script"
else
  bad "the scan produced no usable rows with preclassify.sh present, so assertion 9 proves nothing: $(printf '%s' "$UD_OK" | tr '\n' '|' | cut -c1-200)"
fi
fi

if sg fh; then
# --- BL-230 arm f: apply STOPS, before writing, on a preclassify that did not classify ---------
# apply.sh called preclassify as `2>/dev/null || true`, so a run that exited 2, or returned no
# rows while base..theirs moves core/, handed phase 1 an empty or partial row set -- and the run
# went on to write and re-stamp as though that were the whole pull. The fix stops through `err`:
# exit 1, a message naming the cause and that nothing was written, and no write at all.
#
# PRECLASSIFY IS FORCED BY A HOOK IN A COPY of the reconcile dir, one fresh seed per case. The
# hooked copy UNFORCED is the positive control: it must apply this pull and re-stamp, or the
# stops below would be a copy that cannot apply anything.
#
# A consumer's installed apply.sh may predate the fix, because this fixture ships ahead of it.
# There the arm SKIPS; in the distribution it runs, so a pre-fix engine goes red.
case "$APPLY" in */core/skills/ai-dlc-update/reconcile/apply.sh) F_ISDIST=1 ;; *) F_ISDIST=0 ;; esac
F_RUN=1
if ! grep -qF 'without classifying, so which files this pull writes' "$APPLY"; then
  if [ "$F_ISDIST" = 0 ]; then
    printf '  SKIP  BL-230 arm f -- the installed apply.sh predates the preclassify stop; it lands with the pull that carries this fixture\n'
    F_RUN=0
  else
    printf '  --    (BL-230: this apply.sh carries no preclassify stop; in the distribution arm f runs anyway and must go red)\n'
  fi
fi
if [ "$F_RUN" = 1 ]; then
  FH="$WORK/bl230-recon"
  cp -R "$(dirname "$APPLY")" "$FH" || { echo "FIXTURE ERROR: could not copy the reconcile dir" >&2; exit 2; }
  F_HOOK="$(printf '%s\n' 'MODE="${5:-}"' \
    'case "${FX_B230_PC:-}:$MODE" in' \
    '  rc2:) printf '"'"'M\tcore/session-driver/ai-dlc-session-driver.sh\t.claude/session-driver/ai-dlc-session-driver.sh\tUPSTREAM-ONLY\n'"'"'' \
    '        echo "preclassify: git failed, refusing to classify: forced by the apply-drift-refile fixture" >&2; exit 2 ;;' \
    '  empty:) exit 0 ;;' \
    'esac')"
  F_A='MODE="${5:-}"' F_B="$F_HOOK" awk '$0 == ENVIRON["F_A"] { print ENVIRON["F_B"]; n++; next } { print } END { exit (n == 1) ? 0 : 3 }' \
    "$(dirname "$APPLY")/preclassify.sh" > "$FH/preclassify.sh"
  if [ "$?" -ne 0 ] || [ "$(grep -c 'FX_B230_PC' "$FH/preclassify.sh")" != 1 ] || ! bash -n "$FH/preclassify.sh"; then
    echo "FIXTURE ERROR: BL-230 could not inject the preclassify hook -- its MODE anchor is not exactly one line" >&2; exit 2
  fi
  # f_case <force|""> -> sets F_RC F_OUT F_STAMP_BEFORE F_STAMP_AFTER F_DRV for a fresh seed.
  # Each seed is made UNDER $WORK, so the EXIT trap above removes it with everything else.
  f_case() {
    local _w; _w="$(seed_copy)" || { echo "FIXTURE ERROR: BL-230 seed failed" >&2; exit 2; }
    eval "$(sed 's/^/F_/' "$_w/env.sh")"
    F_STAMP_BEFORE="$(cat "$F_STAMP")"
    F_OUT="$(FX_B230_PC="$1" bash "$FH/apply.sh" "$F_DIST" "$F_BASE" "$F_CONSUMER" "$F_THEIRS" 2>&1)"; F_RC=$?
    F_STAMP_AFTER="$(cat "$F_STAMP")"
    F_DRV="$(cat "$F_DRIVER")"
    F_SCHEMA_EDITED=0; grep -q 'my-persona-skill' "$F_SCHEMA" && F_SCHEMA_EDITED=1
    F_MARK="$F_CONSUMER/.claude/.ai-dlc-applying"
  }
  # f_pre <force> <marker-bytes> -> like f_case, but a fresh seed first gets an in-flight marker
  # planted as a PREVIOUS aborted run would have left it, and only then does apply run.
  f_pre() {
    local _w; _w="$(seed_copy)" || { echo "FIXTURE ERROR: BL-230 seed failed" >&2; exit 2; }
    eval "$(sed 's/^/F_/' "$_w/env.sh")"
    F_MARK="$F_CONSUMER/.claude/.ai-dlc-applying"
    printf '%s' "$2" > "$F_MARK"
    F_OUT="$(FX_B230_PC="$1" bash "$FH/apply.sh" "$F_DIST" "$F_BASE" "$F_CONSUMER" "$F_THEIRS" 2>&1)"; F_RC=$?
  }
  f_case ""
  if [ "$F_RC" -eq 0 ] && grep -qE '^version: 9\.9\.9$' <<<"$F_STAMP_AFTER" && grep -q 'driver v2' <<<"$F_DRV"; then
    ok "BL-230 control: the hooked copy, unforced, applies the pull and re-stamps"
  else
    echo "FIXTURE ERROR: BL-230 control -- the hooked copy UNFORCED did not apply (rc=$F_RC); the stops below would measure a copy that cannot write" >&2
    printf '%s\n' "$F_OUT" | head -20 | sed 's/^/  DIAG  f-control | /' >&2
    exit 2
  fi
  for F_CASE in rc2 empty; do
    case "$F_CASE" in
      rc2)   F_WANT='preclassify.sh exited 2 without classifying' ;;
      empty) F_WANT='preclassify.sh returned no rows while' ;;
    esac
    f_case "$F_CASE"
    if [ "$F_RC" -eq 1 ] && grep -qF "$F_WANT" <<<"$F_OUT" && grep -qF 'NOTHING HAS BEEN WRITTEN' <<<"$F_OUT" \
       && [ "$F_STAMP_AFTER" = "$F_STAMP_BEFORE" ] && grep -q 'driver v1' <<<"$F_DRV" && [ "$F_SCHEMA_EDITED" = 1 ]; then
      ok "BL-230 arm f ($F_CASE): apply exits 1 naming the cause, writes nothing (driver still v1, drift unrefiled) and leaves the stamp"
    else
      bad "BL-230 arm f ($F_CASE): apply did not stop before writing on a preclassify that did not classify (rc=$F_RC, stamp moved: $([ "$F_STAMP_AFTER" = "$F_STAMP_BEFORE" ] && echo no || echo yes), driver: $(grep -o 'driver v[12]' <<<"$F_DRV"), drift still in place: $F_SCHEMA_EDITED)"
      printf '%s\n' "$F_OUT" | head -20 | sed "s/^/  DIAG  f-$F_CASE | /"
    fi
    # THE MARKER HALF. The in-flight marker used to be written BEFORE the preclassify stop, so a
    # refusal left `.ai-dlc-applying` on a tree nothing had written, and the next push blocked
    # with mid-pull advice about a pull that never started. The fresh seed carries no marker, so
    # an absent one here is this run's doing. Keyed on rc 1 as well, so a run that never reached
    # the stop cannot pass this by writing nothing at all.
    if [ "$F_RC" -eq 1 ] && [ ! -e "$F_MARK" ]; then
      ok "BL-230 arm f ($F_CASE) marker: the refusing run leaves NO .ai-dlc-applying behind"
    else
      bad "BL-230 arm f ($F_CASE) marker: after a preclassify refusal (rc=$F_RC) .ai-dlc-applying is $([ -e "$F_MARK" ] && echo PRESENT || echo absent) -- the next push blocks on a tree nothing touched"
    fi
  done
  # THE ALLOW TWIN, one property apart: the same refusal over a consumer that ALREADY carries a
  # marker from an earlier aborted run. That marker is not this run's to remove, so it must be
  # there afterwards, byte-identical. Without this twin, a stop that deletes every marker passes
  # the arm above.
  F_PLANT="$(printf 'base: 0000000000000000000000000000000000000000\ntheirs: earlier-aborted-run\n')"
  f_pre rc2 "$F_PLANT"
  if [ "$F_RC" -eq 1 ] && [ -f "$F_MARK" ] && [ "$(cat "$F_MARK")" = "$F_PLANT" ]; then
    ok "BL-230 arm f marker ALLOW twin: a marker an earlier run left is kept, byte-identical, by a refusing run"
  else
    bad "BL-230 arm f marker ALLOW twin: a refusing run (rc=$F_RC) removed or rewrote a marker an earlier aborted run left ($([ -f "$F_MARK" ] && echo rewritten || echo removed))"
  fi
fi

# --- BL-230 arm h: a PRE-RELOCATION consumer pulling a lone core/scripts/ deletion is zero work ---
# The near-miss for arm f's empty-result stop. The range's only core/ change deletes
# core/scripts/x.sh, and the consumer still holds scripts/x.sh at the old path. preclassify used to
# print NO rows for that pull, and apply's empty-over-a-moving-range stop then refused a pull with
# nothing to do, forever. preclassify now emits an inert PRE-RELOCATION-NOOP row; apply must run
# through, leave scripts/x.sh alone, and file nothing as an unhandled bucket. The row itself and
# the render are relocation-preclassify arm G.
#
# PRESENCE-SHAPED: rc 0 and an untouched file are also what a subject replaced by `exit 0` gives,
# so apply must also have printed its manifest (at least one RESOLVED/DECISION/NOTE row).
case "$APPLY" in */core/skills/ai-dlc-update/reconcile/apply.sh) H_ISDIST=1 ;; *) H_ISDIST=0 ;; esac
H_RUN=1
if ! grep -qF 'PRE-RELOCATION-NOOP' "$(dirname "$APPLY")/preclassify.sh"; then
  if [ "$H_ISDIST" = 0 ]; then
    printf '  SKIP  BL-230 arm h -- the installed preclassify.sh predates PRE-RELOCATION-NOOP; it lands with the pull that carries this fixture\n'
    H_RUN=0
  else
    printf '  --    (BL-230: this preclassify.sh carries no PRE-RELOCATION-NOOP row; in the distribution arm h runs anyway and must go red)\n'
  fi
fi
if [ "$H_RUN" = 1 ]; then
  h="$(h_score "$(dirname "$APPLY")")"
  if [ -z "$h" ]; then
    ok "BL-230 arm h: apply runs a zero-work pre-relocation pull through (rc 0), leaves scripts/x.sh, and files no unhandled-bucket row"
  else
    bad "BL-230 arm h: the zero-work pre-relocation pull was not applied as zero work: $h"
  fi
fi

fi
if sg r; then
# --- BL-336 arm r: THE REFILE'S "DID NOT RUN" ROW PRESCRIBES A PROCEDURE THAT FINISHES THE WORK ---
# When the provenance refile's diff cannot run, apply raises `DECISION drift … did not run` and
# withholds the stamp. Its remedy read "re-run apply" -- and on a consumer carrying the approved
# report, a bare re-run is refused by the union gate (rc 1), because this run already wrote the tree
# that report describes. `--finish`, which the restamp-withheld row offers, stamps theirs WITHOUT
# refiling. The row now names re-render / re-approve / apply.
#
# THE STATE IS FORCED BY ks_hook (above): the report is rendered, then the run goes through the union
# gate and the drift loop with ONLY the diff starved; the remedy is followed unforced. (A mode-000
# schema cannot force it: the union gate refuses first. An unwritable TMPDIR does not reach this row
# either: preclassify refuses first and apply stops before writing.)
#
# THE ARM FOLLOWS WHATEVER THE ROW SAYS, it does not grep for the right words: re-render+apply if
# it names emit-report.sh, `--finish` if it names that, a bare re-run otherwise. It then reads the
# TREE -- the extension holds the skill, the schema equals theirs, the stamp advanced -- so a row
# naming a remedy that does not finish the work fails here however it is worded.
# A missing row is FIXTURE BROKEN naming the gate that refused, never a SKIP.
r_follow() { # r_follow <reconcile-dir> -> "<row?>|<rc2>|<ext>|<schema>|<stamp>|<remedy>"
  local rec="$1" w row rem rc2
  w="$(seed_copy)" || { printf 'BROKEN'; return; }
  eval "$(sed 's/^/R_/' "$w/env.sh")"
  mkdir -p "$R_CONSUMER/_bmad-output/ai-dlc-update"
  r_render() { { printf '# reconcile report (fixture)\n\n'; bash "$rec/emit-report.sh" "$R_DIST" "$R_BASE" "$R_CONSUMER" "$R_THEIRS" 2>/dev/null; } \
                 > "$R_CONSUMER/_bmad-output/ai-dlc-update/reconcile-report.md"; }
  r_render
  R_RAW="$(FX_KSDIFF_FAIL=1 bash "$rec/apply.sh" "$R_DIST" "$R_BASE" "$R_CONSUMER" "$R_THEIRS" 2>"$w/apply.err")"
  row="$(awk -F'\t' '$1=="DECISION" && $2=="drift" && $3=="schemas/provenance-block.json" && index($4, "did not run") {print $4; exit}' <<<"$R_RAW")"
  if [ -z "$row" ]; then norow_note "$R_RAW" "$w/apply.err"; printf 'NOROW'; return; fi
  # `--finish` FIRST: a row naming both a re-render and `--finish` sends the operator to the
  # finisher, so that is what it is scored on.
  case "$row" in
    *"--finish"*)       rem=finish; bash "$rec/apply.sh" --finish "$R_DIST" "$R_BASE" "$R_CONSUMER" "$R_THEIRS" >/dev/null 2>&1; rc2=$? ;;
    *"emit-report.sh"*) rem=rerender; r_render; bash "$rec/apply.sh" "$R_DIST" "$R_BASE" "$R_CONSUMER" "$R_THEIRS" >/dev/null 2>&1; rc2=$? ;;
    *)                  rem=bare; bash "$rec/apply.sh" "$R_DIST" "$R_BASE" "$R_CONSUMER" "$R_THEIRS" >/dev/null 2>&1; rc2=$? ;;
  esac
  printf 'ROW|%s|%s|%s|%s|%s' "$rc2" \
    "$(grep -q my-persona-skill "$R_EXT" 2>/dev/null && echo EXT || echo -)" \
    "$(git -C "$R_DIST" show "${R_THEIRS}:core/schemas/provenance-block.json" | cmp -s - "$R_SCHEMA" && echo SCHEMA || echo -)" \
    "$(grep -qE '^version: 9\.9\.9$' "$R_STAMP" && echo STAMPED || echo -)" "$rem"
}
R_RUN=1
if ! grep -qF 'reapply_remedy=' "$APPLY"; then
  case "$APPLY" in
    */core/skills/ai-dlc-update/reconcile/apply.sh) printf '  --    (BL-336: this apply.sh carries no reapply_remedy; in the distribution arm r runs anyway and must go red)\n' ;;
    *) R_RUN=0; printf '  SKIP  BL-336 arm r -- the installed apply.sh predates the re-render remedy; it lands with the pull that carries this fixture\n' ;;
  esac
fi
if [ "$R_RUN" = 1 ]; then
  ks_ctl_ready
  [ "$KS_READY" = ok ] || R_RUN=0
fi
if [ "$R_RUN" = 1 ]; then
  R_GOT="$(r_follow "$HK")"
  case "$R_GOT" in
    NOROW) bad "FIXTURE BROKEN [BL-336 arm r]: the did-not-run row never appeared; refused at: $(cat "$WORK/norow.why")" ;;
    BROKEN) bad "FIXTURE BROKEN [BL-336 arm r]: the world could not be seeded" ;;
    "ROW|0|EXT|SCHEMA|STAMPED|rerender") ok "BL-336 arm r: the did-not-run row prescribes re-render/re-approve/apply, and following it refiles my-persona-skill, reverts the schema to theirs and advances the stamp" ;;
    *) bad "BL-336 arm r: following the did-not-run row's remedy did not finish the refile ($R_GOT; want ROW|0|EXT|SCHEMA|STAMPED|rerender)" ;;
  esac
fi

fi
if sg q; then
# --- BL-402 arm q: `--finish` RE-CHECKS THE TWO REMEDIES ONLY A FRESH RUN PERFORMS ----------------
# Three worlds, each a clone of ONE ordinary apply run whose diff ks_hook starves (the did-not-run row):
#   W  nothing refiled                       -> the withheld row does NOT offer --finish, and
#                                               --finish WITHHOLDS with `finish-refile-owed`
#   H  refiled by hand, schema = theirs       -> --finish STAMPS (the ALLOW twin: a finisher that
#                                               refuses everything fails here)
#   X  as H, plus validate-synthetic.sh +x    -> --finish WITHHOLDS with `finish-exec-owed`. That
#      (100644 upstream, OUTSIDE the range, so finish_verify_tree cannot see it)
# Cell: "<W row names --finish? F|->|<W finish stamp>|<W refile-owed row>|<H stamp>|<X stamp>|<X exec row>"
if ! grep -qF 'finish_reapply_owed' "$APPLY"; then
  case "$APPLY" in
    */core/skills/ai-dlc-update/reconcile/apply.sh) Q_RUN=1; printf '  --    (BL-402: this apply.sh carries no finish_reapply_owed; in the distribution arm q runs anyway and must go red)\n' ;;
    *) Q_RUN=0; printf '  SKIP  BL-402 arm q -- the installed apply.sh predates the finisher re-check; it lands with the pull that carries this fixture\n' ;;
  esac
else
  Q_RUN=1
fi
if [ "$Q_RUN" = 1 ]; then
  ks_ctl_ready
  [ "$KS_READY" = ok ] || Q_RUN=0
fi
if [ "$Q_RUN" = 1 ]; then
  Q_GOT="$(q_score "$HK")"
  case "$Q_GOT" in
    NOROW)   bad "FIXTURE BROKEN [BL-402 arm q]: the did-not-run row never appeared; refused at: $(cat "$WORK/norow.why")" ;;
    BROKEN)  bad "FIXTURE BROKEN [BL-402 arm q]: a world could not be seeded" ;;
    "$Q_WANT") ok "BL-402 arm q: the withheld row does not offer --finish while the refile is owed; --finish withholds over an unrefiled tree (finish-refile-owed) and over a 100644 file left +x outside the range (finish-exec-owed), and STAMPS the hand-refiled tree" ;;
    *)       bad "BL-402 arm q: $Q_GOT (want $Q_WANT; cells: W-row-names-finish|W-finish-stamp|W-refile-owed|H-stamp|X-stamp|X-exec-row)" ;;
  esac
fi

fi
if sg t; then
# --- arm t: `--finish`'s REFILE CHECK IS THE ORDINARY RUN'S PREDICATE, GATE AND ALL ----------------
# finish_reapply_owed diffed theirs against the consumer schema with no in-place-edit gate, and read
# a theirs line that only gained a trailing comma as consumer-added. Four worlds:
#   An  upstream retires `retired-skill`; the consumer schema is untouched (at base)
#                                     -> no finish-refile-owed row (it would restore a retired skill)
#   Ap  the same range; the consumer appended `my-persona-skill` in place  -> NOT owed: both sides
#       changed the schema, so the ordinary run buckets it BOTH-CHANGED->CLASSIFY and hands it back as
#       `semantic-merge` (measured), never a refile; the finisher, on the same predicate, owes nothing
#       and leaves the merge to that row. Without the gate it owed both names, retired one included.
#   Bk  refile done by hand (extension holds the skill), schema KEPT as is -> no owed row, STAMPS
#   Bn  as Bk with no extension written                                    -> owed, naming it
# Cell: "<An owes retired-skill?>|<Ap owes my-persona-skill?>|<Bk owed row?>|<Bk stamp>|<Bn owed?>"
t_score() { # t_score <hooked-reconcile-dir> [worlds] -> the cell above (`.` for a world not asked for), or NOROW / BROKEN
  local rec="$1" ws=" ${2:-tAn tAp tBk tBn} " w fo c1=. c2=. c3=. c4=. c5=.
  case "$ws" in *" tAn "*)
    w="$(t_aworld 0)" && [ -d "$w/cons" ] || { printf 'BROKEN'; return; }
    fo="$(bash "$rec/apply.sh" --finish "$w/dist" "$(cat "$w/.B")" "$w/cons" "$(cat "$w/.T")" 2>/dev/null)"
    c1="$(awk -F'\t' '$1=="WORKLIST" && $2=="finish-refile-owed" && index($4, "retired-skill") {f=1} END {print (f ? "RETIRED" : "-")}' <<<"$fo")" ;;
  esac
  case "$ws" in *" tAp "*)
    w="$(t_aworld 1)" && [ -d "$w/cons" ] || { printf 'BROKEN'; return; }
    fo="$(bash "$rec/apply.sh" --finish "$w/dist" "$(cat "$w/.B")" "$w/cons" "$(cat "$w/.T")" 2>/dev/null)"
    c2="$(awk -F'\t' '$1=="WORKLIST" && $2=="finish-refile-owed" && index($4, "my-persona-skill") {f=1} END {print (f ? "OWED" : "-")}' <<<"$fo")" ;;
  esac
  case "$ws" in *" tBk "*|*" tBn "*)
    q_base "$rec" || { printf 'BROKEN'; return; }
    grep -q 'did not run' <<<"$QT_OUT" || { norow_note "$QT_OUT" "$QT_ERR"; printf 'NOROW'; return; } ;;
  esac
  case "$ws" in *" tBk "*)
    q_world W || { printf 'BROKEN'; return; }
    mkdir -p "$(dirname "$Q_EXT")" && printf '{\n  "known_skills": [\n    "my-persona-skill"\n  ]\n}\n' > "$Q_EXT" || { printf 'BROKEN'; return; }
    grep -q 'my-persona-skill' "$Q_SCHEMA" || { printf 'BROKEN'; return; }
    fo="$(bash "$rec/apply.sh" --finish "$Q_DIST" "$Q_BASE" "$Q_CONSUMER" "$Q_THEIRS" 2>/dev/null)"
    c3="$(awk -F'\t' '$1=="WORKLIST" && $2=="finish-refile-owed" {printf "%s", (index($4, "bmad-party-mode") ? "BMAD" : "OTHER"); f=1} END {if (!f) print "-"}' <<<"$fo")"
    c4="$(grep -qE '^version: 9\.9\.9$' "$Q_STAMP" && echo STAMPED || echo -)" ;;
  esac
  case "$ws" in *" tBn "*)
    q_world W || { printf 'BROKEN'; return; }
    fo="$(bash "$rec/apply.sh" --finish "$Q_DIST" "$Q_BASE" "$Q_CONSUMER" "$Q_THEIRS" 2>/dev/null)"
    c5="$(awk -F'\t' '$1=="WORKLIST" && $2=="finish-refile-owed" && index($4, "my-persona-skill") {f=1} END {print (f ? "OWED" : "-")}' <<<"$fo")" ;;
  esac
  printf '%s|%s|%s|%s|%s' "$c1" "$c2" "$c3" "$c4" "$c5"
}
T_WANT='-|-|-|STAMPED|OWED'
T_RUN=1
if ! grep -qF 'ud_capture' "$APPLY"; then
  case "$APPLY" in
    */core/skills/ai-dlc-update/reconcile/apply.sh) printf '  --    (arm t: this apply.sh carries no shared in-place-edit gate; in the distribution arm t runs anyway and must go red)\n' ;;
    *) T_RUN=0; printf '  SKIP  arm t -- the installed apply.sh predates the shared refile gate; it lands with the pull that carries this fixture\n' ;;
  esac
fi
if [ "$T_RUN" = 1 ]; then
  ks_ctl_ready
  [ "$KS_READY" = ok ] || T_RUN=0
fi
if [ "$T_RUN" = 1 ]; then
  T_GOT="$(t_score "$HK")"
  case "$T_GOT" in
    NOROW)    bad "FIXTURE BROKEN [arm t]: the did-not-run row never appeared, so worlds Bk/Bn could not be built; refused at: $(cat "$WORK/norow.why")" ;;
    BROKEN)   bad "FIXTURE BROKEN [arm t]: a world could not be seeded" ;;
    "$T_WANT") ok "arm t: --finish owes no refile for an untouched schema whose range retires a skill, nor for a kept schema whose skills are in the extension (and stamps it), nor for a both-changed schema the ordinary run hands back as a semantic merge; it still owes an unrefiled in-place addition" ;;
    *)        bad "arm t: $T_GOT (want $T_WANT; cells: An-owes-retired|Ap-owed|Bk-owed-row|Bk-stamp|Bn-owed)" ;;
  esac
fi

fi
if sg v; then
# --- BL-413 arm v: `--finish` WITHHOLDS OVER A HANDED-BACK SEMANTIC MERGE NOBODY DID ---------------
# arm t's Ap world, driven the way a consumer drives it: the ORDINARY run first, then `--finish`. The
# ordinary run buckets the schema BOTH-CHANGED->CLASSIFY and hands it back as `semantic-merge`; it
# must leave the schema's bytes alone (asserted per world -- arm t's comment says so, this measures
# it). `--finish` used to raise no row there and stamp 9.9.9 over the unmerged schema.
#   Vu  untouched, then --finish                                   -> WITHHOLDS, finish-classify-unmerged
#   Vm  hand-merged (retired-skill dropped), then --finish          -> STAMPS
#   Vr  hand-merged, a SECOND ordinary run, then --finish           -> STAMPS (first write wins: the
#       re-run's record must not make the merged copy the reference)
#   Vo  untouched, the marker rewritten as the previous engine wrote it (no classify-hashes:) -> STAMPS,
#       with NOTE finish-classify-unrecorded (the fix cannot fire on the pull that delivers it)
# Cell: "<Vu stamp>|<Vu row>|<Vm stamp>|<Vr stamp>|<Vo stamp>|<Vo note>" ; a world whose ordinary run moved
# the schema, or drew no semantic-merge row, is BROKEN.
v_drive() { # v_drive <reconcile-dir> <u|m|r|o> -> "<stamp>|<unmerged row?>|<unrecorded note?>"
  local rec="$1" w b t sch h0 o fo
  w="$(t_aworld 1)" && [ -d "$w/cons" ] || { printf 'BROKEN'; return; }
  b="$(cat "$w/.B")"; t="$(cat "$w/.T")"; sch="$w/cons/.claude/schemas/provenance-block.json"
  h0="$(git hash-object "$sch")" || { printf 'BROKEN'; return; }
  o="$(bash "$rec/apply.sh" "$w/dist" "$b" "$w/cons" "$t" 2>/dev/null)"
  awk -F'\t' '$1=="WORKLIST" && $2=="semantic-merge" && $3=="schemas/provenance-block.json" {f=1} END {exit !f}' <<<"$o" \
    && [ "$(git hash-object "$sch")" = "$h0" ] || { printf 'BROKEN'; return; }
  case "$2" in
    m|r) printf '{\n  "known_skills": [\n    "bmad-party-mode",\n    "my-persona-skill"\n  ]\n}\n' > "$sch" || { printf 'BROKEN'; return; } ;;
  esac
  [ "$2" = r ] && bash "$rec/apply.sh" "$w/dist" "$b" "$w/cons" "$t" >/dev/null 2>&1
  [ "$2" = o ] && { printf 'base: %s\ntheirs: %s\n' "$b" "$t" > "$w/cons/.claude/.ai-dlc-applying" || { printf 'BROKEN'; return; }; }
  fo="$(bash "$rec/apply.sh" --finish "$w/dist" "$b" "$w/cons" "$t" 2>/dev/null)"
  printf '%s|%s|%s' \
    "$(grep -qE '^version: 9\.9\.9$' "$w/cons/.claude/.ai-dlc-version" && echo STAMPED || echo WITHHELD)" \
    "$(awk -F'\t' '$1=="WORKLIST" && $2=="finish-classify-unmerged" && $3==".claude/schemas/provenance-block.json" {f=1} END {print (f ? "UNMERGED" : "-")}' <<<"$fo")" \
    "$(awk -F'\t' '$1=="NOTE" && $2=="finish-classify-unrecorded" {f=1} END {print (f ? "NOTE" : "-")}' <<<"$fo")"
}
v_score() { # v_score <reconcile-dir> [worlds] -> the cell above (`.` for a world not asked for), or BROKEN
  local rec="$1" ws=" ${2:-vU vM vR vO} " c1=. c2=. c3=. c4=. c5=. c6=. x
  case "$ws" in *" vU "*) x="$(v_drive "$rec" u)"; [ "$x" = BROKEN ] && { printf 'BROKEN'; return; }; c1="${x%%|*}"; c2="$(printf '%s' "$x" | cut -d'|' -f2)" ;; esac
  case "$ws" in *" vM "*) x="$(v_drive "$rec" m)"; [ "$x" = BROKEN ] && { printf 'BROKEN'; return; }; c3="${x%%|*}" ;; esac
  case "$ws" in *" vR "*) x="$(v_drive "$rec" r)"; [ "$x" = BROKEN ] && { printf 'BROKEN'; return; }; c4="${x%%|*}" ;; esac
  case "$ws" in *" vO "*) x="$(v_drive "$rec" o)"; [ "$x" = BROKEN ] && { printf 'BROKEN'; return; }; c5="${x%%|*}"; c6="${x##*|}" ;; esac
  printf '%s|%s|%s|%s|%s|%s' "$c1" "$c2" "$c3" "$c4" "$c5" "$c6"
}
V_WANT='WITHHELD|UNMERGED|STAMPED|STAMPED|STAMPED|NOTE'
V_RUN=1
if ! grep -qF 'finish_classify_unmerged' "$APPLY"; then
  case "$APPLY" in
    */core/skills/ai-dlc-update/reconcile/apply.sh) printf '  --    (BL-413: this apply.sh records no CLASSIFY blobs; in the distribution arm v runs anyway and must go red)\n' ;;
    *) V_RUN=0; printf '  SKIP  BL-413 arm v -- the installed apply.sh predates the CLASSIFY record; it lands with the pull that carries this fixture\n' ;;
  esac
fi
if [ "$V_RUN" = 1 ]; then
  V_GOT="$(v_score "$(dirname "$APPLY")")"
  case "$V_GOT" in
    BROKEN)   bad "FIXTURE BROKEN [BL-413 arm v]: a world could not be seeded, or its ordinary run moved the schema or drew no semantic-merge row" ;;
    "$V_WANT") ok "BL-413 arm v: --finish withholds over an untouched handed-back merge (finish-classify-unmerged), stamps a hand-merged one, stamps it after a second ordinary run (first write wins), and stamps with a NOTE over a previous-engine marker" ;;
    *)        bad "BL-413 arm v: $V_GOT (want $V_WANT; cells: Vu-stamp|Vu-row|Vm-stamp|Vr-stamp|Vo-stamp|Vo-note)" ;;
  esac
fi

fi
if sg y; then
# --- BL-413 arm y: THE CLASSIFY RECORD READS A MERGE THAT IS ONLY A chmod, SURVIVES A RE-POINTED OR
# DELIVERING PULL, STANDS DOWN WHERE KEEPING THE CONSUMER COPY IS THE NORMAL OUTCOME, AND REFUSES A
# DIRECTORY AT THE MARKER'S PATH ---------------------------------------------------------------------
# Each world is driven the way a consumer drives it (ordinary run, the operator's hand, --finish):
#   Ym  theirs adds ONLY +x to a script the consumer edited; the merge is `chmod +x`     -> STAMPED
#   Yp  merge done, then the pull is re-pointed at a theirs that moves only another file -> STAMPED
#   Ys  both files merged for T, a second ordinary run on the SAME base at T2 (which moves one of them
#       again), that one merged again                                                  -> STAMPED
#   Yd  the DELIVERING pull: the first ordinary run was the previous engine (marker with no
#       `classify-hashes:`), one file merged, the re-run is this engine     -> STAMPED with the NOTE
#   Yx  theirs DELETED one consumer-modified file and never shipped another (ORPHANED-UNKNOWN); both
#       kept, the one real both-changed file merged                       -> STAMPED, no unmerged row
#   Yl  the per-line exit: one file's own `classify:` line deleted, the other still untouched ->
#       WITHHELD naming only the other, marker kept; after merging it          -> STAMPED, marker gone
#   Yn  a DIRECTORY at the marker's path -> DECISION applying-marker-unwritten and nothing moved into it
#   Yf  the marker became a DIRECTORY after a successful ordinary run, merge undone, then --finish
#       -> WITHHELD with WORKLIST finish-marker-directory (it used to stamp identity-unchecked)
# Cell: "Ym|Yp|Ys|Yd|Yx|Yl|Yn|Yf"; a world whose ordinary run drew no semantic-merge row for its subject
# is BROKEN.
yg() { git -c user.email=f@f -c user.name=fixture "$@"; }
y_init() { # -> a fresh world: dist/ (a git repo with VERSION 9.9.9) and cons/
  local _w; _w="$(mktemp -d "$WORK/y.XXXXXX")" || return 1
  mkdir -p "$_w/dist/core/scripts" "$_w/cons/scripts/ai-dlc" "$_w/cons/.claude" || return 1
  printf '9.9.9\n' > "$_w/dist/VERSION" && yg -C "$_w/dist" init -q && printf '%s' "$_w"
}
y_commit() { # y_commit <world> <label> -- commit dist, record the sha in <world>/.<label>
  yg -C "$1/dist" add -A && yg -C "$1/dist" commit -qm "$2" && yg -C "$1/dist" rev-parse HEAD > "$1/.$2"
}
y_stampat() { printf 'version: 0.0.1\ncommit: %s\n' "$(cat "$1/.B")" > "$1/cons/.claude/.ai-dlc-version"; }
y_run() { # y_run <rec> <world> <theirs-label> [--finish] -> manifest on stdout
  if [ "${4:-}" = --finish ]; then
    bash "$1/apply.sh" --finish "$2/dist" "$(cat "$2/.B")" "$2/cons" "$(cat "$2/.$3")" 2>/dev/null
  else
    bash "$1/apply.sh" "$2/dist" "$(cat "$2/.B")" "$2/cons" "$(cat "$2/.$3")" 2>/dev/null
  fi
}
y_sm() { awk -F'\t' -v p="$1" '$1=="WORKLIST" && $2=="semantic-merge" && $3==p {f=1} END {exit !f}'; }
y_stamp() { grep -qE '^version: 9\.9\.9$' "$1/cons/.claude/.ai-dlc-version" && printf STAMPED || printf WITHHELD; }
y_two() { # y_two <world> -- m.sh and n.sh, both changed by theirs at T and by the consumer
  printf 'a\nb\nc\n' > "$1/dist/core/scripts/m.sh"; printf 'a\nb\nc\n' > "$1/dist/core/scripts/n.sh"
  y_commit "$1" B || return 1
  printf 'a\nb\nc-T\n' > "$1/dist/core/scripts/m.sh"; printf 'a\nb\nc-T\n' > "$1/dist/core/scripts/n.sh"
  y_commit "$1" T || return 1
  printf 'a-C\nb\nc\n' > "$1/cons/scripts/ai-dlc/m.sh"; printf 'a-C\nb\nc\n' > "$1/cons/scripts/ai-dlc/n.sh"
  y_stampat "$1"
}
y_drive() { # y_drive <rec> <m|p|s|d|x|l|n> -> that world's cell, or BROKEN
  local rec="$1" w o fo M="a-C\nb\nc-T\n"
  w="$(y_init)" && [ -d "$w/cons" ] || { printf BROKEN; return; }
  case "$2" in
    m)
      printf '#!/bin/sh\necho base\n' > "$w/dist/core/scripts/x.sh"; chmod 644 "$w/dist/core/scripts/x.sh"
      y_commit "$w" B || { printf BROKEN; return; }
      chmod 755 "$w/dist/core/scripts/x.sh"; y_commit "$w" T || { printf BROKEN; return; }
      [ -n "$(yg -C "$w/dist" diff --name-only "$(cat "$w/.B")" "$(cat "$w/.T")")" ] || { printf BROKEN; return; }
      printf '#!/bin/sh\necho base\necho consumer-line\n' > "$w/cons/scripts/ai-dlc/x.sh"; chmod 644 "$w/cons/scripts/ai-dlc/x.sh"
      y_stampat "$w"
      y_run "$rec" "$w" T | y_sm scripts/x.sh || { printf BROKEN; return; }
      chmod 755 "$w/cons/scripts/ai-dlc/x.sh"
      y_run "$rec" "$w" T --finish >/dev/null; y_stamp "$w" ;;
    p)
      printf 'a\nb\nc\n' > "$w/dist/core/scripts/m.sh"; printf 'o\n' > "$w/dist/core/scripts/other.sh"
      y_commit "$w" B || { printf BROKEN; return; }
      printf 'a\nb\nc-T\n' > "$w/dist/core/scripts/m.sh"; y_commit "$w" T || { printf BROKEN; return; }
      printf 'o-T2\n' > "$w/dist/core/scripts/other.sh"; y_commit "$w" T2 || { printf BROKEN; return; }
      printf 'a-C\nb\nc\n' > "$w/cons/scripts/ai-dlc/m.sh"; printf 'o\n' > "$w/cons/scripts/ai-dlc/other.sh"
      y_stampat "$w"
      y_run "$rec" "$w" T | y_sm scripts/m.sh || { printf BROKEN; return; }
      printf "$M" > "$w/cons/scripts/ai-dlc/m.sh"
      y_run "$rec" "$w" T2 >/dev/null
      y_run "$rec" "$w" T2 --finish >/dev/null; y_stamp "$w" ;;
    s)
      y_two "$w" || { printf BROKEN; return; }
      printf 'a\nb\nc-T\nd-T2\n' > "$w/dist/core/scripts/m.sh"; y_commit "$w" T2 || { printf BROKEN; return; }
      y_run "$rec" "$w" T | y_sm scripts/n.sh || { printf BROKEN; return; }
      printf "$M" > "$w/cons/scripts/ai-dlc/m.sh"; printf "$M" > "$w/cons/scripts/ai-dlc/n.sh"
      y_run "$rec" "$w" T2 >/dev/null
      printf 'a-C\nb\nc-T\nd-T2\n' > "$w/cons/scripts/ai-dlc/m.sh"
      y_run "$rec" "$w" T2 --finish >/dev/null; y_stamp "$w" ;;
    d)
      y_two "$w" || { printf BROKEN; return; }
      y_run "$rec" "$w" T | y_sm scripts/m.sh || { printf BROKEN; return; }
      # The previous engine's marker: `base:` and `theirs:` and nothing else.
      printf 'base: %s\ntheirs: %s\n' "$(cat "$w/.B")" "$(cat "$w/.T")" > "$w/cons/.claude/.ai-dlc-applying" || { printf BROKEN; return; }
      printf "$M" > "$w/cons/scripts/ai-dlc/m.sh"
      y_run "$rec" "$w" T >/dev/null
      fo="$(y_run "$rec" "$w" T --finish)"
      printf '%s/%s' "$(y_stamp "$w")" "$(awk -F'\t' '$1=="NOTE" && $2=="finish-classify-unrecorded" {f=1} END {print (f ? "NOTE" : "-")}' <<<"$fo")" ;;
    x)
      printf 'a\nb\nc\n' > "$w/dist/core/scripts/m.sh"; printf 'gone\n' > "$w/dist/core/scripts/del.sh"
      y_commit "$w" B || { printf BROKEN; return; }
      printf 'a\nb\nc-T\n' > "$w/dist/core/scripts/m.sh"; yg -C "$w/dist" rm -q core/scripts/del.sh
      y_commit "$w" T || { printf BROKEN; return; }
      printf 'a-C\nb\nc\n' > "$w/cons/scripts/ai-dlc/m.sh"; printf 'gone\nconsumer-still-uses-this\n' > "$w/cons/scripts/ai-dlc/del.sh"
      mkdir -p "$w/cons/.claude/fixtures/mine" && printf 'consumer-authored\n' > "$w/cons/.claude/fixtures/mine/run.sh"
      y_stampat "$w"
      o="$(y_run "$rec" "$w" T)"
      y_sm scripts/del.sh <<<"$o" && y_sm fixtures/mine/run.sh <<<"$o" && y_sm scripts/m.sh <<<"$o" || { printf BROKEN; return; }
      printf "$M" > "$w/cons/scripts/ai-dlc/m.sh"
      fo="$(y_run "$rec" "$w" T --finish)"
      printf '%s/%s' "$(y_stamp "$w")" "$(awk -F'\t' '$1=="WORKLIST" && $2=="finish-classify-unmerged" {n++} END {print n+0}' <<<"$fo")" ;;
    l)
      y_two "$w" || { printf BROKEN; return; }
      y_run "$rec" "$w" T | y_sm scripts/m.sh || { printf BROKEN; return; }
      grep -q '	scripts/ai-dlc/m\.sh$' "$w/cons/.claude/.ai-dlc-applying" || { printf BROKEN; return; }
      awk '!/^classify: .*\tscripts\/ai-dlc\/m\.sh$/' "$w/cons/.claude/.ai-dlc-applying" > "$w/mk" \
        && cat "$w/mk" > "$w/cons/.claude/.ai-dlc-applying" || { printf BROKEN; return; }
      fo="$(y_run "$rec" "$w" T --finish)"
      o="$(y_stamp "$w"):$(awk -F'\t' '$1=="WORKLIST" && $2=="finish-classify-unmerged" {printf "%s,", $3}' <<<"$fo"):$([ -f "$w/cons/.claude/.ai-dlc-applying" ] && echo kept || echo gone)"
      printf "$M" > "$w/cons/scripts/ai-dlc/n.sh"
      y_run "$rec" "$w" T --finish >/dev/null
      printf '%s>%s:%s' "$o" "$(y_stamp "$w")" "$([ -e "$w/cons/.claude/.ai-dlc-applying" ] && echo kept || echo gone)" ;;
    f)
      y_two "$w" || { printf BROKEN; return; }
      y_run "$rec" "$w" T | y_sm scripts/m.sh || { printf BROKEN; return; }
      [ -f "$w/cons/.claude/.ai-dlc-applying" ] || { printf BROKEN; return; }
      mv "$w/cons/.claude/.ai-dlc-applying" "$w/marker.saved" && mkdir "$w/cons/.claude/.ai-dlc-applying" || { printf BROKEN; return; }
      fo="$(y_run "$rec" "$w" T --finish)"
      printf '%s/%s' "$(y_stamp "$w")" "$(awk -F'\t' '$1=="WORKLIST" && $2=="finish-marker-directory" {f=1} END {print (f ? "ROW" : "-")}' <<<"$fo")" ;;
    n)
      y_two "$w" || { printf BROKEN; return; }
      mkdir -p "$w/cons/.claude/.ai-dlc-applying" || { printf BROKEN; return; }
      o="$(y_run "$rec" "$w" T)"
      y_sm scripts/m.sh <<<"$o" || { printf BROKEN; return; }
      printf '%s/%s' "$(awk -F'\t' '$1=="DECISION" && $2=="applying-marker-unwritten" {f=1} END {print (f ? "REFUSED" : "-")}' <<<"$o")" \
        "$([ -z "$(ls -A "$w/cons/.claude/.ai-dlc-applying")" ] && echo empty || echo FILLED)" ;;
  esac
}
y_score() { # y_score <reconcile-dir> [<case>...] -> "|"-joined cells, or BROKEN
  local c g out=""
  for c in ${2:-m p s d x l n f}; do
    g="$(y_drive "$1" "$c")"
    [ "$g" = BROKEN ] && { printf BROKEN; return; }
    out="${out:+$out|}$g"
  done
  printf '%s' "$out"
}
Y_WANT='STAMPED|STAMPED|STAMPED|STAMPED/NOTE|STAMPED/0|WITHHELD:scripts/ai-dlc/n.sh,:kept>STAMPED:gone|REFUSED/empty|WITHHELD/ROW'
Y_RUN=1
if ! grep -qF '_unrec' "$APPLY"; then
  case "$APPLY" in
    */core/skills/ai-dlc-update/reconcile/apply.sh) printf '  --    (BL-413 arm y: this apply.sh records no mode, keys the record on theirs, or has no marker-directory refusal; in the distribution arm y runs anyway and must go red)\n' ;;
    *) Y_RUN=0; printf '  SKIP  BL-413 arm y -- the installed apply.sh predates the mode/base-keyed CLASSIFY record; it lands with the pull that carries this fixture\n' ;;
  esac
fi
if [ "$Y_RUN" = 1 ]; then
  Y_GOT="$(y_score "$(dirname "$APPLY")")"
  case "$Y_GOT" in
    BROKEN)   bad "FIXTURE BROKEN [BL-413 arm y]: a world could not be seeded, or its ordinary run drew no semantic-merge row for its subject" ;;
    "$Y_WANT") ok "BL-413 arm y: a chmod-only merge stamps; a re-pointed pull, a second same-base pull and the delivering pull keep the record and stamp after the merge; kept UPSTREAM-DELETED/ORPHANED copies do not withhold; the per-line exit withholds only the other file and keeps the marker; a directory at the marker's path is refused by the ordinary run and withholds --finish" ;;
    *)        bad "BL-413 arm y: $Y_GOT (want $Y_WANT; cells: Ym|Yp|Ys|Yd|Yx|Yl|Yn|Yf)" ;;
  esac
fi

fi
if sg u; then
# --- arm u: A `--finish` WHOSE FINISH-CHECK INPUT CANNOT BE STAGED WITHHOLDS THE STAMP ---------------
# finish_verify_tree read preclassify's rows from a heredoc. Under a file-size limit bash 3.2 cannot
# write the heredoc's temp file and runs the loop on EMPTY stdin: no finish-unapplied row, and the
# stamp advanced to theirs over a tree with every file still at base. The world: 100 files at base
# under one long directory, so the rows (~22 KB) exceed a 14 and a 20 KB limit while everything else
# the finish path writes fits under 14. Limits are in 1024-byte units, SIGXFSZ ignored.
# Cell per limit: "<finish-unapplied rows>|<fv staging-refused or finish-unverified-tree row?>|<stamp>"
u_cell() { # u_cell <world> <apply.sh> <limit|none>
  local w="$1" b t o
  b="$(cat "$w/.B")"; t="$(cat "$w/.T")"
  printf 'version: 0.0.1\ncommit: %s\n' "$b" > "$w/cons/.claude/.ai-dlc-version"
  printf 'base: %s\ntheirs: %s\n' "$b" "$t" > "$w/cons/.claude/.ai-dlc-applying"
  if [ "$3" = none ]; then
    o="$(bash "$2" --finish "$w/dist" "$b" "$w/cons" "$t" 2>/dev/null)"
  else
    o="$(trap '' XFSZ; ulimit -f "$3"; bash "$2" --finish "$w/dist" "$b" "$w/cons" "$t" 2>/dev/null)"
  fi
  printf '%s|%s|%s' \
    "$(awk -F'\t' '$1=="WORKLIST" && $2=="finish-unapplied"' <<<"$o" | wc -l | tr -d ' ')" \
    "$(awk -F'\t' '$1=="WORKLIST" && (($2=="staging-refused" && index($4, "for the finish check")) || $2=="finish-unverified-tree") {f=1} END {print (f ? "REFUSED" : "-")}' <<<"$o")" \
    "$(sed -n 's/^version: //p' "$w/cons/.claude/.ai-dlc-version")"
}
U_RUN=1
if ! grep -qF 'ap_stage fv-rows' "$APPLY"; then
  case "$APPLY" in
    */core/skills/ai-dlc-update/reconcile/apply.sh) printf '  --    (arm u: this apply.sh does not stage the finish check rows; in the distribution arm u runs anyway and must go red)\n' ;;
    *) U_RUN=0; printf '  SKIP  arm u -- the installed apply.sh predates the staged finish check; it lands with the pull that carries this fixture\n' ;;
  esac
fi
if [ "$U_RUN" = 1 ]; then
  UW="$(u_world)"
  if [ -z "$UW" ] || [ ! -d "$UW/cons" ]; then
    bad "FIXTURE BROKEN [arm u]: the many-files world could not be seeded"
  else
    U_CTL="$(u_cell "$UW" "$APPLY" none)"
    if [ "$U_CTL" != '100|-|0.0.1' ]; then
      bad "arm u control: with no limit --finish read $U_CTL (want 100|-|0.0.1) -- the world does not hold 100 files at base, so the limited runs prove nothing"
    else
      ok "arm u control: with no limit --finish names all 100 files still at base and leaves the stamp at 0.0.1"
      for U_L in 10 14 20; do
        u="$(u_cell "$UW" "$APPLY" "$U_L")"
        case "$u" in
          *'|REFUSED|0.0.1') ok "arm u (ulimit -f $U_L): the finish check could not stage its rows, says so, and withholds the stamp ($u)"
            ;;
          *) bad "arm u (ulimit -f $U_L): $u (want <n>|REFUSED|0.0.1) -- a finish check that could not read its rows let the stamp advance or said nothing" ;;
        esac
      done
    fi
  fi
fi

fi
if sg w; then
# --- BL-414 arm w: A BUCKET-ROW HAND-DOWN THAT CANNOT BE WRITTEN LEAKS NO PARTIAL ROW -------------
# apply.sh wrote preclassify's rows to the unregistered-drift and retired-tokens hand-down files with
# a builtin `printf … > file`. Under a file-size limit the write fails, its unflushed tail stays in
# the shell's stdout buffer, and the next manifest row carries it: one line such as
# `ddd…/f064<TAB>UPSTREAM-ONLY`. arm u's 100-file world makes the rows (~22 KB) exceed 14 and 20 KB.
# A line is MALFORMED when it is non-empty and its first field is none of the four row kinds.
# Cell per limit: "<malformed lines>|<hand-down staging-refused rows>|<stamp>"
w_cell() { # w_cell <world> <apply.sh> <limit|none>
  local w="$1" b t o
  b="$(cat "$w/.B")"; t="$(cat "$w/.T")"
  printf 'version: 0.0.1\ncommit: %s\n' "$b" > "$w/cons/.claude/.ai-dlc-version"
  rm -f "$w/cons/.claude/.ai-dlc-applying"
  local i=0 ld; ld="$(printf '%075d' 0 | tr 0 d)"
  while [ "$i" -lt 100 ]; do printf 'v1 %s\n' "$i" > "$w/cons/.claude/session-driver/$ld/f$(printf %03d "$i")"; i=$((i+1)); done
  if [ "$3" = none ]; then
    o="$(bash "$2" "$w/dist" "$b" "$w/cons" "$t" 2>/dev/null)"
  else
    o="$(trap '' XFSZ; ulimit -f "$3"; bash "$2" "$w/dist" "$b" "$w/cons" "$t" 2>/dev/null)"
  fi
  printf '%s|%s|%s' \
    "$(awk -F'\t' 'NF && $1!="RESOLVED" && $1!="WORKLIST" && $1!="DECISION" && $1!="NOTE" {n++} END {print n+0}' <<<"$o")" \
    "$(awk -F'\t' '$2=="staging-refused" && index($4, "bucket rows handed to") {n++} END {print n+0}' <<<"$o")" \
    "$(sed -n 's/^version: //p' "$w/cons/.claude/.ai-dlc-version")"
}
W_RUN=1
if ! grep -qF 'ap_stage ud-bucket-rows' "$APPLY"; then
  case "$APPLY" in
    */core/skills/ai-dlc-update/reconcile/apply.sh) printf '  --    (BL-414: this apply.sh does not stage the bucket-row hand-downs; in the distribution arm w runs anyway and must go red)\n' ;;
    *) W_RUN=0; printf '  SKIP  BL-414 arm w -- the installed apply.sh predates the staged hand-downs; it lands with the pull that carries this fixture\n' ;;
  esac
fi
if [ "$W_RUN" = 1 ]; then
  WW="$(u_world)"
  if [ -z "$WW" ] || [ ! -d "$WW/cons" ]; then
    bad "FIXTURE BROKEN [BL-414 arm w]: the many-files world could not be seeded"
  else
    W_CTL="$(w_cell "$WW" "$APPLY" none)"
    if [ "$W_CTL" != '0|0|9.9.9' ]; then
      bad "BL-414 arm w control: with no limit the ordinary apply read $W_CTL (want 0|0|9.9.9) -- the world does not apply cleanly, so the limited runs prove nothing"
    else
      ok "BL-414 arm w control: with no limit the ordinary apply prints no malformed line, refuses nothing and stamps 9.9.9"
      for W_L in 14 20; do
        w="$(w_cell "$WW" "$APPLY" "$W_L")"
        case "$w" in
          0\|2\|0.0.1) ok "BL-414 arm w (ulimit -f $W_L): no partial row leaks; both hand-downs refuse by name and the stamp is withheld ($w)"
            ;;
          *) bad "BL-414 arm w (ulimit -f $W_L): $w (want 0|2|0.0.1) -- a hand-down that could not be written leaked a row into the manifest, or refused silently" ;;
        esac
      done
    fi
  fi
fi

fi
if sg x; then
# --- BL-364 arm x: A NON-ASCII core/ PATH REACHES apply.sh's LISTING READERS RAW ---------------------
# Under the default core.quotePath git lists `core/scripts/café.sh` as `"core/scripts/caf\303\251.sh"`,
# and a reader that strips `core/`, maps the name or matches it against a consumer path loses the row
# at rc 0. Each world holds `plain.sh` beside `café.sh`, so the ASCII row is the same-run control.
#   XA  both 100755 upstream, unchanged in the range, consumer copies 0644 at scripts/ai-dlc/
#       -> exec_audit `not-executable` (the `ls-tree -r` mode listing) and the declared-set
#          `declared-not-executable` (manifest_dests' glob expansion, then a per-file mode lookup)
#   XB  both at the PRE-0.126.0 path scripts/<x> only -> `relocate` places each at scripts/ai-dlc/
#       (manifest_dests' glob expansion)
#   XC  both changed in the range; one artifact per file records a `derived` command naming it
#       -> artifact-derivations counts 2 (vd_join's moved-path needles); and, as GUARDS that quoting
#       cannot move (base passes them too): the written copies are executable (sync_mode_from_theirs's
#       mode lookup), and a tracked transient directory `café-state/` is counted (the ls-files count)
# Cell: "<XA café N>|<XA café D>|<XA plain N+D>|<XB café>|<XB plain>|<XC hits>|<XC café +x>|<XC tracked>"
x_world() { world_once x x_world_build "$1"; } # x_world <A|B|C> -> path of a fresh world, refs in .B/.T
x_world_build() {
  local _w _d _c _cf _f
  _w="$(mktemp -d "$WORK/x.XXXXXX")" || return 1
  _d="$_w/dist"; _c="$_w/cons"; _cf="$(printf 'caf\303\251')"
  mkdir -p "$_d/core/scripts" "$_d/core/session-driver" "$_c/scripts/ai-dlc" "$_c/.claude/session-driver" || return 1
  for _f in validate-synthetic plain "$_cf"; do
    printf '#!/usr/bin/env bash\necho %s v1\n' "$_f" > "$_d/core/scripts/$_f.sh" && chmod 755 "$_d/core/scripts/$_f.sh" || return 1
  done
  printf '#!/usr/bin/env bash\n# driver v1\n' > "$_d/core/session-driver/d.sh"
  printf '9.9.9\n' > "$_d/VERSION"
  # BL-631: world C carries `derived` fences, so vd_join consults the scope classifier, read out of
  # the DIST at THEIRS. The three real files are committed in the BASE commit and never change, so
  # they stay out of the moved set and the XC hit count still reads 2. Worlds A and B draw no
  # derivation row and are left exactly as they were. This function's stdout is captured by its
  # caller, so nothing is printed here; X_CLS_* are announced where the arm runs.
  if [ "$1" = C ]; then
    [ -n "${X_CLS_SH:-}" ] && [ -n "${X_CLS_SS:-}" ] && [ -n "${X_CLS_SCH:-}" ] || return 1
    mkdir -p "$_d/core/schemas" || return 1
    cp -p "$X_CLS_SH" "$_d/core/scripts/check-owed-derivations.sh" || return 1
    cp -p "$X_CLS_SS" "$_d/core/scripts/sprint-status.sh" || return 1
    cp -p "$X_CLS_SCH" "$_d/core/schemas/sprint-status.json" || return 1
  fi
  git -C "$_d" init -q && git -C "$_d" -c user.email=f@f -c user.name=fixture add -A \
    && git -C "$_d" -c user.email=f@f -c user.name=fixture commit -qm base || return 1
  git -C "$_d" rev-parse HEAD > "$_w/.B"
  printf '#!/usr/bin/env bash\n# driver v2\n' > "$_d/core/session-driver/d.sh"
  if [ "$1" = C ]; then
    for _f in plain "$_cf"; do printf '#!/usr/bin/env bash\necho %s v2\n' "$_f" > "$_d/core/scripts/$_f.sh"; done
  fi
  git -C "$_d" -c user.email=f@f -c user.name=fixture add -A \
    && git -C "$_d" -c user.email=f@f -c user.name=fixture commit -qm theirs || return 1
  git -C "$_d" rev-parse HEAD > "$_w/.T"
  printf '#!/usr/bin/env bash\n# driver v1\n' > "$_c/.claude/session-driver/d.sh"
  git -C "$_d" show "$(cat "$_w/.B"):core/scripts/validate-synthetic.sh" > "$_c/scripts/ai-dlc/validate-synthetic.sh" || return 1
  chmod 755 "$_c/scripts/ai-dlc/validate-synthetic.sh"
  for _f in plain "$_cf"; do
    case "$1" in
      A|C) git -C "$_d" show "$(cat "$_w/.B"):core/scripts/$_f.sh" > "$_c/scripts/ai-dlc/$_f.sh" && chmod 644 "$_c/scripts/ai-dlc/$_f.sh" || return 1 ;;
      B)   git -C "$_d" show "$(cat "$_w/.B"):core/scripts/$_f.sh" > "$_c/scripts/$_f.sh" || return 1 ;;
    esac
  done
  if [ "$1" = C ]; then
    mkdir -p "$_c/_bmad-output" "$_c/.claude/schemas" "$_c/$_cf-state" || return 1
    for _f in plain "$_cf"; do
      printf '# %s\n\n```derived\n$ bash scripts/ai-dlc/%s.sh\n```\n' "$_f" "$_f" > "$_c/_bmad-output/$_f.md" || return 1
    done
    printf '{"paths":[{"transient":true,"ignore":"%s-state/"}]}\n' "$_cf" > "$_c/.claude/schemas/pipeline-state-paths.json"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$_c/scripts/ai-dlc/sync-transient-ignore.sh"
    printf 'x\n' > "$_c/$_cf-state/x"
    git -C "$_c" init -q && git -C "$_c" -c user.email=f@f -c user.name=fixture add -A \
      && git -C "$_c" -c user.email=f@f -c user.name=fixture commit -qm consumer || return 1
  fi
  printf 'version: 0.0.1\ncommit: %s\n' "$(cat "$_w/.B")" > "$_c/.claude/.ai-dlc-version"
  printf '%s' "$_w"
}
x_score() { # x_score <reconcile-dir> [worlds] -> the cell above (`.` for a world not asked for), or BROKEN
  local rec="$1" ws=" ${2:-xA xB xC} " w o cf c1=. c2=. c3=. c4=. c5=. c6=. c7=. c8=.
  cf="$(printf 'caf\303\251')"
  case "$ws" in *" xA "*)
    w="$(x_world A)" && [ -d "$w/cons" ] || { printf 'BROKEN'; return; }
    o="$(bash "$rec/apply.sh" "$w/dist" "$(cat "$w/.B")" "$w/cons" "$(cat "$w/.T")" 2>/dev/null)"
    c1="$(awk -F'\t' -v p="scripts/ai-dlc/$cf.sh" '$1=="DECISION" && $2=="not-executable" && $3==p {f=1} END {print (f ? "N" : "-")}' <<<"$o")"
    c2="$(awk -F'\t' -v p="scripts/ai-dlc/$cf.sh" '$1=="DECISION" && $2=="declared-not-executable" && $3==p {f=1} END {print (f ? "D" : "-")}' <<<"$o")"
    c3="$(awk -F'\t' '$1=="DECISION" && ($2=="not-executable" || $2=="declared-not-executable") && $3=="scripts/ai-dlc/plain.sh" {n++} END {print n+0}' <<<"$o")" ;;
  esac
  case "$ws" in *" xB "*)
    w="$(x_world B)" && [ -d "$w/cons" ] || { printf 'BROKEN'; return; }
    o="$(bash "$rec/apply.sh" "$w/dist" "$(cat "$w/.B")" "$w/cons" "$(cat "$w/.T")" 2>/dev/null)"
    c4="$(awk -F'\t' -v p="scripts/ai-dlc/$cf.sh" '$1=="RESOLVED" && $2=="relocate" && $3==p {f=1} END {print (f ? "PLACED" : "-")}' <<<"$o")"
    c5="$(awk -F'\t' '$1=="RESOLVED" && $2=="relocate" && $3=="scripts/ai-dlc/plain.sh" {f=1} END {print (f ? "PLACED" : "-")}' <<<"$o")" ;;
  esac
  case "$ws" in *" xC "*)
    w="$(x_world C)" && [ -d "$w/cons" ] || { printf 'BROKEN'; return; }
    o="$(bash "$rec/apply.sh" "$w/dist" "$(cat "$w/.B")" "$w/cons" "$(cat "$w/.T")" 2>/dev/null)"
    c6="$(awk -F'\t' '$2=="artifact-derivations" || $2=="artifact-derivations-unchecked" {split($4, a, " "); print a[1]; f=1; exit} END {if (!f) print "-"}' <<<"$o")"
    c7="$([ -x "$w/cons/scripts/ai-dlc/$cf.sh" ] && grep -q "$cf v2" "$w/cons/scripts/ai-dlc/$cf.sh" && echo X || echo -)"
    c8="$(awk -F'\t' -v p="$cf-state/(1)" '$1=="WORKLIST" && $2=="transient-ignore-tracked" && index($4, p) {f=1} END {print (f ? "T" : "-")}' <<<"$o")" ;;
  esac
  printf '%s|%s|%s|%s|%s|%s|%s|%s' "$c1" "$c2" "$c3" "$c4" "$c5" "$c6" "$c7" "$c8"
}
X_WANT='N|D|2|PLACED|PLACED|2|X|T'
X_RUN=1
# The real scope classifier, resolved from this fixture's own repo root in either layout; world C
# commits it into the DIST (see x_world). Absent in a tree that predates it: the arm then cannot
# draw the row it counts, so it is skipped in a consumer and hard in the distribution.
X_REPO="$(cd "$(dirname "$APPLY")/../../../.." && pwd)"
X_CLS_SH=""; X_CLS_SS=""; X_CLS_SCH=""
for _c in "$X_REPO/core/scripts/check-owed-derivations.sh" "$X_REPO/scripts/ai-dlc/check-owed-derivations.sh"; do
  [ -f "$_c" ] && X_CLS_SH="$_c" && break
done
for _c in "$X_REPO/core/scripts/sprint-status.sh" "$X_REPO/scripts/ai-dlc/sprint-status.sh"; do
  [ -f "$_c" ] && X_CLS_SS="$_c" && break
done
for _c in "$X_REPO/core/schemas/sprint-status.json" "$X_REPO/.claude/schemas/sprint-status.json"; do
  [ -f "$_c" ] && X_CLS_SCH="$_c" && break
done
if [ -n "$X_CLS_SH" ] && [ -n "$X_CLS_SS" ] && [ -n "$X_CLS_SCH" ]; then
  echo "HERMETIC-CONSUMED $X_CLS_SH"; echo "HERMETIC-CONSUMED $X_CLS_SS"; echo "HERMETIC-CONSUMED $X_CLS_SCH"
elif [ -d "$X_REPO/core/skills/ai-dlc" ]; then
  :   # the distribution: world C then fails to seed and the arm goes red (BROKEN), never silent
else
  X_RUN=0; printf '  SKIP  BL-631 arm x -- the scope classifier is not in this tree, so world C cannot draw the derivation row it counts\n'
fi
if ! grep -qF -- '-c core.quotePath=false ls-tree -r "$THEIRS" -- core/' "$APPLY"; then
  case "$APPLY" in
    */core/skills/ai-dlc-update/reconcile/apply.sh) printf '  --    (BL-364: this apply.sh lists paths under the default core.quotePath; in the distribution arm x runs anyway and must go red)\n' ;;
    *) X_RUN=0; printf '  SKIP  BL-364 arm x -- the installed apply.sh predates the quotePath listings; it lands with the pull that carries this fixture\n' ;;
  esac
fi
if [ "$X_RUN" = 1 ] && ! command -v jq >/dev/null 2>&1; then
  X_RUN=0; printf '  SKIP  BL-364 arm x -- jq is absent, so the transient-ignore guard cell cannot run (this is not a pass)\n'
fi
if [ "$X_RUN" = 1 ]; then
  X_GOT="$(x_score "$(dirname "$APPLY")")"
  case "$X_GOT" in
    BROKEN)   bad "FIXTURE BROKEN [BL-364 arm x]: a world could not be seeded" ;;
    "$X_WANT") ok "BL-364 arm x: café.sh is audited for its exec bit, declared, relocated and matched as a derivation needle under its raw name beside plain.sh; the mode lookups and the tracked count hold for it too" ;;
    *)        bad "BL-364 arm x: $X_GOT (want $X_WANT; cells: XA-café-N|XA-café-D|XA-plain-N+D|XB-café|XB-plain|XC-hits|XC-café+x|XC-tracked)" ;;
  esac
fi

fi
if sg s; then
# --- BL-360 arm s: A RELABEL TOOL THAT REFUSED IS A ROW, NOT "NOTHING TO RELABEL" -----------------
# apply.sh read relabel-extension-checks.sh through `2>/dev/null || true`, so its refusal (exit 2,
# no count printed) read exactly like a catalog with no collisions. The copy's relabel tool is
# replaced by one that refuses; the arm reads the `relabel-refused` DECISION and the withheld stamp.
s_score() { # s_score <reconcile-dir> -> "<relabel-refused row?>|<stamp>"
  local w o
  w="$(seed_copy)" || { printf 'BROKEN'; return; }
  eval "$(sed 's/^/S_/' "$w/env.sh")"
  o="$(bash "$1/apply.sh" "$S_DIST" "$S_BASE" "$S_CONSUMER" "$S_THEIRS" 2>/dev/null)"
  printf '%s|%s' \
    "$(awk -F'\t' '$1=="DECISION" && $2=="relabel-refused" && index($4, "exited 2") {f=1} END {print (f ? "REFUSED" : "-")}' <<<"$o")" \
    "$(grep -qE '^version: 9\.9\.9$' "$S_STAMP" && echo STAMPED || echo -)"
}
s_copy() { # s_copy <dir> -- the reconcile dir with a relabel tool that refuses
  cp -R "$(dirname "$APPLY")" "$1" || return 1
  printf '#!/usr/bin/env bash\necho "relabel: REFUSED — fixture stub" >&2\nexit 2\n' > "$1/relabel-extension-checks.sh"
}
S_RUN=1
if ! grep -qF 'detector_run relabel relabel-extension-checks.sh' "$APPLY"; then
  case "$APPLY" in
    */core/skills/ai-dlc-update/reconcile/apply.sh) printf '  --    (BL-360: this apply.sh does not stage the relabel tool; in the distribution arm s runs anyway and must go red)\n' ;;
    *) S_RUN=0; printf '  SKIP  BL-360 arm s -- the installed apply.sh does not stage the relabel tool; it lands with the pull that carries this fixture\n' ;;
  esac
fi
if [ "$S_RUN" = 1 ]; then
  if s_copy "$WORK/s-ctl"; then
    S_GOT="$(s_score "$WORK/s-ctl")"
    if [ "$S_GOT" = 'REFUSED|-' ]; then
      ok "BL-360 arm s: a relabel tool that exits 2 draws DECISION relabel-refused and the stamp is withheld"
    else
      bad "BL-360 arm s: $S_GOT (want REFUSED|-)"
    fi
    # Control in the same run: the untouched tool on the same seed draws no refusal and stamps.
    S_CTL="$(s_score "$(dirname "$APPLY")")"
    [ "$S_CTL" = '-|STAMPED' ] && ok "BL-360 arm s control: the shipped relabel tool draws no refusal and the stamp advances" \
      || bad "BL-360 arm s control: $S_CTL (want -|STAMPED)"
  else
    bad "FIXTURE BROKEN [BL-360 arm s]: could not copy the reconcile dir"
  fi
fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS ($asserts assertions)"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
