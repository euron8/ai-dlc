#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# emit-report-refusal/run.sh — a sample or detector that did not run renders DETECTOR-REFUSED in
# the reconcile report, never `none`.
#
# THE DEFECT (BL-230). emit-report.sh's orientation block read no status at all: `diff` exit 2
# was swallowed with exit 1, the grep|sed|grep sample chain and its `grep -c` swallowed their own
# failures, and a failed `git show` rendered `THEIRS absent`. Seven sibling detector sites read
# their rows through a pipeline and rendered `none` whatever the detector's exit was. A batch-160
# pool put reconcile-emit-report's E3 on V-N at `3|BLOCKERS-RESOLVED|1|1|4|4`: an approval
# rendered while the orientation diff failed recorded a sample that never ran as an empty one.
# The TRIGGER, measured afterwards: `diff <(…) file` under four concurrent bash workers fails
# with `/dev/fd/63: Bad file descriptor`, rc 2 — between 0 and 9 of each 10000 calls across
# repeated runs, load-dependent — where the same comparison through a temp file failed 0 of
# 40000. A7 forces that interleaving rather than sampling it.
#
# WHY A SEPARATE UNIT. reconcile-emit-report is the suite's heaviest reconcile unit; these arms
# re-render the seed world many times, and added there they
# would move a pole-adjacent directory. The seed is SHARED, not copied: this unit runs the
# sibling's own `seed.sh`, so both units read one world.
#
# ARMS (each runs against the ctl copy of reconcile/):
#   A0  CONTROL: a copy of reconcile/ renders the seed world byte-identically to the
#       seed's own region, with positive rows in every section the stub arms later refuse.
#   A1  per site (retired-tokens, relabel, ledger-reverify, predicate-differential,
#       retired-fixtures, retired-layer-contract, retired-layer-passage): a stub exiting
#       non-zero renders exactly ONE column-0 `DETECTOR-REFUSED  <name> exited <rc>` in place of
#       the section, and the render still exits 0 with the unstubbed sections intact.
#   A2  relabel exiting 1 is its FINDING: its row renders, and no refusal does.
#   A3  per-FILE: the orientation diff failing on the SECOND of two CLASSIFY files refuses that
#       file only; the first keeps its complete sample and no `ONLY IN …: none` renders.
#   A4a the sample awk exiting non-zero refuses that side; A4b a non-numeric count refuses too.
#   A5  absence is decided by ls-tree: a failed ls-tree and a failed show each render a refusal,
#       while a path truly absent at theirs renders `THEIRS absent`.
#   A6  R1's shape: approve healthy, resolve the HARD drift, verify under a diff shim -> rc 1,
#       UNDECIDED, one DETECTOR-REFUSED line (an indented refusal reads rc 3 BLOCKERS-RESOLVED).
#   A7  the race itself, FORCED on the engine's own orientation-diff text (a `diff` shadowed by one fork),
#       against two reference spellings that must split 5/5 and 0/5 first.
set -uo pipefail

# HERMETIC -- scrub the operator's tuning before reading anything (I10). H1 below drives a world
# carrying an ai-dlc hook through the hook-registration validator.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
SIB="$HERE/../reconcile-emit-report"
[ -f "$SIB/seed.sh" ] \
  || { echo "FIXTURE ERROR: sibling reconcile-emit-report/seed.sh not found beside this unit" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
# The sibling seed reads emit-report.sh's two in-process wrap halves before it sources it (its header
# says why): 3 is a subject that predates the wrap (SKIP, never an ok), 4 one carrying one half (FAIL).
WORK="$(RER_SEED_INPROC=1 bash "$SIB/seed.sh")"; _seed_rc=$?
case "$_seed_rc" in
  0) ;;
  3) echo "SKIP: subject predates the in-process wrap"; fx_skip_exit "$HERE" ;;
  4) echo "emit-report-refusal: FAIL (1) -- emit-report.sh carries one half of the in-process wrap (the seed names it above)" >&2; exit 1 ;;
  *) echo "FIXTURE ERROR: the sibling seed failed" >&2; exit 2 ;;
esac
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"
RDIR="$(dirname "$EMIT")"
echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/emit-report.sh"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
# IN PROCESS (BL-878). Every render and --verify below is er_ip: a subshell that sources the engine copy it is
# handed and calls its er_main, so the subject's `exit`, traps and `set` stay there, and a copy of reconcile/ finds
# ITS stubbed siblings beside itself. `hash -r` empties the inherited command hash, so a `PATH=<shim>:$PATH er_ip`
# prefix reaches the shim as it reached a fresh `bash emit-report.sh`. Each pass is one fx_inproc logged under
# $EMIT (the inproc: row). NOT lib/inproc.sh's inproc_run: this fixture declares an unguarded bash subject
# (validate-hook-registration.sh), and inproc.sh's own operand sources then read as unpaired P2 drives here.
# The two cli cells (cells.decl) are the only command-line starts, each compared byte for byte.
[ -f "$HERE/../lib/mutant.sh" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: sourcing lib/mutant.sh failed" >&2; exit 2; }
er_ip() { # er_ip <emit-report.sh path> <args...> -> the subject's stdout, stderr and exit
  local _e="$1"; shift
  ( fx_inproc "$EMIT"; . "$_e" || exit 126; hash -r; er_main "$@" )
}
echo "emit-report-refusal:"

R="$WORK/err"; mkdir -p "$R/sh" "$R/prog" "$R/out"
REAL_DIFF="$(command -v diff)"; REAL_AWK="$(command -v awk)"; REAL_GIT="$(command -v git)"
[ -n "$REAL_DIFF" ] && [ -n "$REAL_AWK" ] && [ -n "$REAL_GIT" ] \
  || { echo "FIXTURE ERROR: diff/awk/git not on PATH" >&2; exit 2; }
CL='core/skills/ai-dlc/templates/classes.md'
ZE='core/skills/ai-dlc/templates/zeta.md'

# --- SHIMS --------------------------------------------------------------------------------
# Each fails ONE call shape and execs the real binary for every other. Keyed on TWO arguments
# with the SECOND the consumer file, so the diff shims fire whatever the first operand is: a
# `/dev/fd/*` process substitution until 0.647.0, `-` (the staged side piped in) since. EVERY
# FIRING APPENDS A LINE TO "$SHIM_FIRED", and every forced-failure arm below refuses as FIXTURE
# BROKEN when that file is empty: a shim that silently stopped matching the engine's call shape
# would otherwise read exactly like an engine that stopped refusing.
shim() { # shim <dir> <binary-name> <body-lines...>
  local d="$R/sh/$1" b="$2"; shift 2
  mkdir -p "$d"; printf '%s\n' '#!/bin/bash' "$@" > "$d/$b"; chmod +x "$d/$b"
}
FIRE='echo "$0 $*" >> "${SHIM_FIRED:-/dev/null}"'
shim diff-zeta    diff "case \"\$#:\${2:-}\" in 2:*templates/zeta.md) $FIRE; exit 2 ;; esac"    "exec '$REAL_DIFF' \"\$@\""
shim diff-classes diff "case \"\$#:\${2:-}\" in 2:*templates/classes.md) $FIRE; exit 2 ;; esac" "exec '$REAL_DIFF' \"\$@\""
shim awk-fail     awk "if [ \"\${1:-}\" = -v ] && [ \"\${2:-}\" = 'm=<' ]; then $FIRE; exit 2; fi"          "exec '$REAL_AWK' \"\$@\""
shim awk-nonnum   awk "if [ \"\${1:-}\" = -v ] && [ \"\${2:-}\" = 'm=<' ]; then $FIRE; echo x; exit 0; fi" "exec '$REAL_AWK' \"\$@\""
# Keyed on the ORIENTATION read's shape (`ls-tree <ref> -- <path>`), never on lib.sh's absence
# discriminator (`ls-tree -z --full-tree`), which preclassify also asks about classes.md at base: a
# forced failure there makes that absence unconfirmable and preclassify refuses first, correctly,
# so the orientation read this arm is about is never reached.
shim git-split    git 'case " $* " in' \
  "  *' --full-tree '*) exec '$REAL_GIT' \"\$@\" ;;" \
  "  *' ls-tree '*' -- $CL '*) $FIRE; exit 128 ;;" \
  "  *' show '*':$ZE '*) $FIRE; exit 128 ;;" 'esac' "exec '$REAL_GIT' \"\$@\""

# --- WORLDS -------------------------------------------------------------------------------
# W0 is the sibling's seed as it stands. T2 adds a SECOND both-added CLASSIFY file (zeta, sorted
# AFTER classes, so the refused file is the non-first) and deletes thing.json upstream, so one
# render carries a path truly absent at theirs beside two present ones.
C2="$R/c2"; cp -R "$CONSUMER" "$C2"
printf 'shared line\nSENTINEL-ZETA-OURS consumer\n' > "$C2/.claude/skills/ai-dlc/templates/zeta.md"
printf 'shared line\nSENTINEL-ZETA-THEIRS upstream\n' > "$DIST/$ZE"
TG() { git -C "$DIST" -c user.email=f@f -c user.name=fixture "$@" >/dev/null 2>&1; }
_head0="$(git -C "$DIST" rev-parse HEAD 2>/dev/null)"
TG checkout -q -b fixture-refusal-t2 "$THEIRS" && TG rm -q core/schemas/thing.json && TG add -A \
  && TG commit -q -m t2-second-classify-and-upstream-delete
T2="$(git -C "$DIST" rev-parse HEAD 2>/dev/null)"
TG checkout -q "$_head0"
rm -f "$DIST/$ZE"
if [ -z "$T2" ] || [ "$T2" = "$THEIRS" ] || [ "$(git -C "$DIST" rev-parse HEAD 2>/dev/null)" != "$_head0" ] \
   || [ -z "$(git -C "$DIST" ls-tree "$T2" -- "$ZE" 2>/dev/null)" ] \
   || [ -n "$(git -C "$DIST" ls-tree "$T2" -- core/schemas/thing.json 2>/dev/null)" ]; then
  echo "FIXTURE ERROR: world T2 was not built (T2=${T2:-<none>}; zeta must be present and thing.json absent at it, HEAD restored)" >&2
  exit 2
fi

# A6's approval, rendered ONCE by the shipped engine at the copy's own path (the region embeds
# the consumer path), then the HARD drift is resolved with base's own bytes.
C3="$R/c3"; cp -R "$CONSUMER" "$C3"
# ONE render, never a bounded retry (BL-868): the retry this replaced re-rendered up to 3 times until
# the DETECTOR-REFUSED set matched, so how often load reached the orientation-diff race decided which
# render A6 read. The engine's diff no longer races (A7's forced half proves it 5 of 5), so a single
# render must match; a mismatch is a broken seed, refused here, never retried into agreement.
# THE cli CELLS (cells.decl): emit-report.sh run as a PROGRAM once per distinct outcome this unit asserts,
# each compared with the in-process call on the same input -- stdout, stderr and exit, byte for byte -- and
# each asserting its own outcome, so two runs that both printed nothing cannot read as equivalent.
# cli-a6-render is A6's approval render itself (print mode, exit 0, the region on stdout); cli-refuse, below,
# is the refusing input, a --verify whose supplied region file is unreadable (exit 2, the refusal on stderr).
# The --verify outcomes 0, 1 and 3 are reconcile-emit-report's cli cells.
EQ="$R/eq"; mkdir -p "$EQ"
err_eqv() { # <cell-id> <subject args...> -> 0 when the program and the in-process call agree byte for byte
  local id="$1"; shift
  SHIM_FIRED="$EQ/$id.ip.fired" er_ip "$EMIT" "$@" > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  SHIM_FIRED="$EQ/$id.cl.fired" FXCELL="$id" bash "$EMIT" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
err_twin() { printf 'in-process rc=%s lines=%s err=[%s] / program rc=%s lines=%s err=[%s]' "$(cat "$EQ/$1.ip.rc")" "$(grep -c . "$EQ/$1.ip.out")" \
  "$(head -1 "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(grep -c . "$EQ/$1.cl.out")" "$(head -1 "$EQ/$1.cl.err")"; }
if err_eqv cli-a6-render "$DIST" "$BASE" "$C3" "$THEIRS" && [ "$(cat "$EQ/cli-a6-render.cl.rc")" = 0 ] \
   && grep -qF 'BEGIN GENERATED: reconcile-mechanical' "$EQ/cli-a6-render.cl.out"; then
  ok "cli-a6-render: the program renders A6's approval region exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-a6-render: the program and the in-process call differ, or the render is not exit 0 with a region ($(err_twin cli-a6-render))"; fi
cp "$EQ/cli-a6-render.ip.out" "$R/a6-region.md"
grep '^DETECTOR-REFUSED' "$R/a6-region.md" > "$R/a6-refused.txt"; grep '^DETECTOR-REFUSED' "$REGION" > "$R/region-refused.txt"
cmp -s "$R/a6-refused.txt" "$R/region-refused.txt" \
  || { echo "FIXTURE BROKEN: A6's approval render refused a different detector set from the seed region's" >&2; exit 2; }
{ echo "# Reconcile report (fixture)"; echo; cat "$R/a6-region.md"; } > "$R/a6-approved.md"
git -C "$DIST" show "${BASE}:core/schemas/thing.json" > "$C3/.claude/schemas/thing.json" 2>/dev/null
grep -q 'HARD-UNREGISTERED-CORE-DRIFT' "$R/a6-region.md" && ! cmp -s "$C3/.claude/schemas/thing.json" "$CONSUMER/.claude/schemas/thing.json" \
  || { echo "FIXTURE ERROR: A6's approval carries no HARD row, or the resolution changed nothing" >&2; exit 2; }
if err_eqv cli-refuse --verify --region-from "$R/no-such-region.md" "$R/a6-approved.md" "$DIST" "$BASE" "$C3" "$THEIRS" \
   && [ "$(cat "$EQ/cli-refuse.cl.rc")" = 2 ] && grep -qF 'cannot read the supplied region file' "$EQ/cli-refuse.cl.err"; then
  ok "cli-refuse: the program refuses an unreadable region file exactly as the in-process call does (stdout, stderr, exit 2)"
else bad "cli-refuse: the program and the in-process call differ, or the outcome is not exit 2 with the refusal line ($(err_twin cli-refuse))"; fi
if ! cmp -s "$EQ/cli-a6-render.cl.rc" "$EQ/cli-refuse.cl.rc" && ! cmp -s "$EQ/cli-a6-render.cl.out" "$EQ/cli-refuse.cl.out"; then
  ok "cli cells discriminate: the render and the refusal give different stdout and exit"
else bad "cli cells do not discriminate: cli-a6-render and cli-refuse gave the same stdout or exit"; fi

# --- PROGRAMS -----------------------------------------------------------------------------
# Every program is a copy of the WHOLE reconcile/ directory (emit-report.sh resolves $SELF
# beside itself), guarded for its siblings.
mkprog() { # mkprog <name> -> copies reconcile/, refuses a copy missing its siblings
  local d="$R/prog/$1"
  rm -rf "$d"; cp -R "$RDIR" "$d" || { bad "HARNESS BROKEN [$1]: copy of reconcile/ failed"; return 1; }
  [ -f "$d/preclassify.sh" ] && [ -f "$d/ledger-reverify.sh" ] \
    || { bad "HARNESS BROKEN [$1]: the copy lacks its siblings, so it would render nothing and every arm would read as a kill"; return 1; }
}
mkprog ctl

# --- THE ENGINE-DRIVEN ARMS H1, A8, A9: their worlds and constants --------------------------
# H1: THE HOOK VALIDATOR'S FIX LINE NAMES A STABLE PATH, SO TWO RENDERS ARE ONE. The validator prints
# `bash <its own path> --root …` at the foot of its FIX block, and emit-report runs THEIRS' copy out of a
# fresh mktemp file -- so with any ai-dlc hook unregistered every render differed in that line, `--verify`
# failed on every render, and the apply gate could not pass on that consumer state at all. The line now
# names the consumer's INSTALLED path. Its own world: the seed above carries no validator at THEIRS.
# SHIPS AHEAD OF ITS SUBJECT: an installed emit-report.sh that predates the rewrite SKIPs, keyed on the
# rewrite's own variable, which the pre-fix copy lacks. Decided on the RESOLVED engine dir.
H_ISDIST=0
[ "$RDIR" = "$(cd "$HERE/../../skills/ai-dlc-update/reconcile" 2>/dev/null && pwd)" ] && H_ISDIST=1
H1_STATE=on
if ! grep -qF 'HRI="$CONSUMER/scripts/ai-dlc/validate-hook-registration.sh"' "$EMIT" && [ "$H_ISDIST" = 0 ]; then
  H1_STATE=skip
  printf '  SKIP  H1 -- the installed emit-report.sh predates the stable hook-validator path; it lands with the pull that carries this fixture\n'
else
  HV=""; for _c in "$HERE/../../scripts/validate-hook-registration.sh" "$HERE/../../../scripts/ai-dlc/validate-hook-registration.sh"; do
    [ -f "$_c" ] && { HV="$_c"; break; }; done
  HM=""; for _c in "$RDIR/settings-merge.sh"; do [ -f "$_c" ] && HM="$_c"; done
  if [ -z "$HV" ] || [ -z "$HM" ]; then
    H1_STATE=broken
    bad "H1 FIXTURE BROKEN: validate-hook-registration.sh or settings-merge.sh not found beside this unit, so no world can carry an unregistered hook"
  else
    H="$WORK/hook"; mkdir -p "$H/d/core/scripts" "$H/d/templates" "$H/c/.claude/hooks" "$H/c/.claude/skills/ai-dlc-update/reconcile"
    cp "$HV" "$H/d/core/scripts/validate-hook-registration.sh"
    echo "HERMETIC-CONSUMED core/scripts/validate-hook-registration.sh"
    printf '{\n  "hooks": {}\n}\n' > "$H/d/templates/settings.json.template"
    hg() { git -C "$H/d" -c user.name=f -c user.email=f@f -c commit.gpgsign=false "$@"; }
    git init -q "$H/d"; hg add -A; hg commit -qm base; HB="$(hg rev-parse HEAD)"
    printf 'x\n' > "$H/d/templates/x.md"; hg add -A; hg commit -qm theirs; HT="$(hg rev-parse HEAD)"
    printf '{\n  "hooks": {}\n}\n' > "$H/c/.claude/settings.json"
    printf '#!/bin/sh\nexit 0\n' > "$H/c/.claude/hooks/ai-dlc-probe.sh"
    cp "$HM" "$H/c/.claude/skills/ai-dlc-update/reconcile/settings-merge.sh"
  fi
fi

# A8: A STABLE PREDICATE SITE RENDERS ITS POPULATION, NEVER `none`. The step-5 projection used to drop every
# PREDICATE-STABLE row, so a differential whose every site was STABLE rendered `none`: the null reached the
# operator with no population definition. A stub differential with FIXED rows drives the copy, so the cell
# is about the projection alone. The non-STABLE row's rendering is held byte-for-byte. Only the STATIC
# definition renders on the STABLE line; the live counts after it do not (A9 says why).
A8_STABLE="$(printf 'PREDICATE-STABLE\tvalidate-x.sh\tthe read-set moved and NO stored artifact changes verdict, long prose. population: root=`_bmad-output` corpus=`*p*` series=`s/$//`; records=3 series=3 compared=1 passed=1 unclassified=1.')"
A8_RECL="$(printf 'PREDICATE-RECLASSIFIES\tvalidate-y.sh\tAT LEAST 1 of 2 stored series change verdict. population: root=`_bmad-output` corpus=`*q*` series=`s/$//`; records=2 series=2 compared=2 unclassified=n/a (grammar spells failures only).')"
a8_prog() { # a8_prog <dir> <emit-source> <rows...> -> a reconcile/ copy whose differential prints <rows>
  local d="$1" e="$2"; shift 2
  cp -R "$RDIR" "$d" && cp "$e" "$d/emit-report.sh" || return 1
  { echo '#!/usr/bin/env bash'; for r in "$@"; do printf "printf '%%s\\\\n' '%s'\n" "$r"; done; echo 'exit 0'; } > "$d/predicate-differential.sh"
}
a8_sect() { # a8_sect <dir> -> the rendered Predicate reclassification section
  er_ip "$1/emit-report.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$1.out" 2>/dev/null
  sect "$1.out" '**Predicate reclassification'
}
a8_want_s='PREDICATE-STABLE  validate-x.sh  population: root=`_bmad-output` corpus=`*p*` series=`s/$//`'
a8_want_r="$(printf '%s' "$A8_RECL" | awk -F'\t' '{print $1"  "$2"  "$3}')"

# A9: A CORPUS THAT GROWS BETWEEN APPROVE AND VERIFY DOES NOT FAIL --verify. `apply.sh` runs `--verify` at
# step 7 against the region approved at step 5, byte-compared. The differential's counts come from the LIVE
# corpus, so a projection carrying them fails verify as stale/hand-edited the moment the consumer's own
# pipeline writes one artifact in between. The stub counts a real pattern under its consumer argument, so
# growing the corpus is a real write. Control: the same world verifies at rc 0 before the write.
a9_world() { # a9_world <dir> <emit-source> -> a reconcile/ copy and a private consumer copy
  local d="$1"
  cp -R "$RDIR" "$d" && cp "$2" "$d/emit-report.sh" && cp -R "$CONSUMER" "$d.c" || return 1
  mkdir -p "$d.c/_bmad-output/a9" && printf 'a9\n' > "$d.c/_bmad-output/a9/a9-pass1.md" || return 1
  cat > "$d/predicate-differential.sh" <<'A9STUB'
#!/usr/bin/env bash
n="$(find "$4/_bmad-output/a9" -type f -name 'a9-pass*' | wc -l | tr -d ' ')"
printf 'PREDICATE-STABLE\tvalidate-a9.sh\tthe read-set moved and NO stored artifact changes verdict. population: root=`_bmad-output` corpus=`a9-pass*` series=`s/$//`; records=%s series=%s compared=0 unclassified=n/a (grammar spells failures only).\n' "$n" "$n"
exit 0
A9STUB
}
a9_run() { # a9_run <dir> -> "<rc-before-write> <rc-after-write>"
  local d="$1" r1 r2
  er_ip "$d/emit-report.sh" "$DIST" "$BASE" "$d.c" "$THEIRS" > "$d.region" 2>/dev/null
  { echo "# Reconcile report (fixture)"; echo; cat "$d.region"; } > "$d.report"
  er_ip "$d/emit-report.sh" --verify "$d.report" "$DIST" "$BASE" "$d.c" "$THEIRS" >/dev/null 2>&1; r1=$?
  printf 'a9\n' > "$d.c/_bmad-output/a9/a9-pass2.md"
  er_ip "$d/emit-report.sh" --verify "$d.report" "$DIST" "$BASE" "$d.c" "$THEIRS" >/dev/null 2>&1; r2=$?
  printf '%s %s' "$r1" "$r2"
}

# --- UNITS ----------------------------------------------------------------------------------------
# A unit is one render or scenario of one program. It is a background job that writes ONLY under
# $R/out/<prog>/, is idempotent through its .done file, and asserts nothing; every verdict is
# read in the foreground, where `bad` counts.
STUBS="retired-tokens.sh:2 relabel-extension-checks.sh:2 ledger-reverify.sh:3 predicate-differential.sh:1 retired-fixtures.sh:3 retired-layer-contract.sh:2 retired-layer-passage.sh:1"
ren() { # ren <prog> <arm> <shim-or-> <theirs> <consumer> [<emit>]
  local o="$R/out/$1" p="$PATH" e="${6:-$R/prog/$1/emit-report.sh}"
  [ "$3" != - ] && p="$R/sh/$3:$PATH"
  : > "$o/$2.fired"
  PATH="$p" SHIM_FIRED="$o/$2.fired" er_ip "$e" "$DIST" "$BASE" "$5" "$4" > "$o/$2.out" 2>/dev/null
  echo "$?" > "$o/$2.rc"
}
unit_of() { # <arm> -> the unit whose run decides it
  case "$1" in
    A0) echo w0 ;; A1-*) echo a1 ;; A2) echo a2 ;; A3) echo a3 ;; A4a) echo a4a ;; A4b) echo a4b ;;
    A5) echo a5 ;; A6) echo a6 ;; H1) echo H1 ;; A8) echo A8 ;; A9) echo A9 ;;
  esac
}
h1_unit() { # <prog> -> $R/out/<prog>/H1.v = "<identical yes|no> <verify rc> <unregistered named yes|no>"
  local e="$R/prog/$1/emit-report.sh" o="$R/out/$1" a b v
  a="$(er_ip "$e" "$H/d" "$HB" "$H/c" "$HT" 2>/dev/null)"; b="$(er_ip "$e" "$H/d" "$HB" "$H/c" "$HT" 2>/dev/null)"
  printf '%s\n' "$a" > "$o/H1.report"
  er_ip "$e" --verify "$o/H1.report" "$H/d" "$HB" "$H/c" "$HT" >/dev/null 2>&1; v=$?
  printf '%s %s %s' "$([ "$a" = "$b" ] && echo yes || echo no)" "$v" \
    "$(grep -qF '.claude/hooks/ai-dlc-probe.sh' <<<"$a" && echo yes || echo no)" > "$o/H1.v"
}
a8_unit() { # <prog> -> A8.s (a STABLE-only differential's section) and A8.b (beside a RECLASSIFIES row)
  local e="$R/prog/$1/emit-report.sh" o="$R/out/$1"
  a8_prog "$R/a8-$1-s" "$e" "$A8_STABLE" && a8_sect "$R/a8-$1-s" > "$o/A8.s"
  a8_prog "$R/a8-$1-b" "$e" "$A8_STABLE" "$A8_RECL" && a8_sect "$R/a8-$1-b" > "$o/A8.b"
}
a9_unit() { # <prog> -> A9.v = "<verify rc before the write> <after>"; A9.live when the region carries the live count
  local e="$R/prog/$1/emit-report.sh" o="$R/out/$1"
  a9_world "$R/a9-$1" "$e" || { echo X > "$o/A9.v"; return 0; }
  a9_run "$R/a9-$1" > "$o/A9.v"
  grep -qF 'records=1 ' "$R/a9-$1.region" && : > "$o/A9.live"
}
unit_run() { # <prog> <unit>
  local p="$1" u="$2" o d s n c
  o="$R/out/$p"; d="$R/prog/$p"; mkdir -p "$o"
  [ -f "$o/$u.done" ] && return 0
  case "$u" in
    w0)  ren "$p" w0 - "$THEIRS" "$CONSUMER" ;;
    a3)  ren "$p" a3 diff-zeta "$T2" "$C2" ;;
    a4a) ren "$p" a4a awk-fail "$THEIRS" "$CONSUMER" ;;
    a4b) ren "$p" a4b awk-nonnum "$THEIRS" "$CONSUMER" ;;
    a5)  ren "$p" a5 git-split "$T2" "$C2" ;;
    a6)
      : > "$o/a6.fired"
      PATH="$R/sh/diff-classes:$PATH" SHIM_FIRED="$o/a6.fired" er_ip "$d/emit-report.sh" --verify "$R/a6-approved.md" "$DIST" "$BASE" "$C3" "$THEIRS" >/dev/null 2>"$o/a6.err"
      echo "$?" > "$o/a6.rc" ;;
    a1)
      cp -R "$d" "$d-allstub"
      for s in $STUBS; do n="${s%%:*}"; c="${s#*:}"; printf '#!/usr/bin/env bash\nexit %s\n' "$c" > "$d-allstub/$n"; done
      ren "$p" a1 - "$THEIRS" "$CONSUMER" "$d-allstub/emit-report.sh" ;;
    a2)
      cp -R "$d" "$d-rl1"
      printf '#!/usr/bin/env bash\nprintf "%%s\\n" "  + ### 7. probe relabel"\nexit 1\n' > "$d-rl1/relabel-extension-checks.sh"
      ren "$p" a2 - "$THEIRS" "$CONSUMER" "$d-rl1/emit-report.sh" ;;
    H1)  h1_unit "$p" ;;
    A8)  a8_unit "$p" ;;
    A9)  a9_unit "$p" ;;
  esac
  : > "$o/$u.done"
}

# --- JUDGES: each prints nothing and returns 0 on PASS, prints its reason and returns 1 ------
O=""
sect() { awk -v h="$2" 'f && /^$/ { exit } f { print } index($0, h) == 1 { f = 1 }' "$1"; }
cnt()  { local n; n="$(grep -c -e "$1" "$2" 2>/dev/null)" || n=0; printf '%s' "$n"; }
hdr_of() {
  case "$1" in
    relabel-extension-checks.sh) echo '**Catalog relabel' ;;
    ledger-reverify.sh)          echo '**Push-candidate ledger' ;;
    predicate-differential.sh)   echo '**Predicate reclassification' ;;
    retired-fixtures.sh)         echo '**Retired core fixtures' ;;
    retired-layer-contract.sh)   echo '**Retired contract shapes' ;;
    retired-layer-passage.sh)    echo '**Retired core passages' ;;
  esac
}
j_a0() {
  local f="$O/w0.out"
  [ "$(cat "$O/w0.rc" 2>/dev/null)" = 0 ] || { echo "render rc $(cat "$O/w0.rc" 2>/dev/null)"; return 1; }
  cmp -s "$f" "$REGION" || { echo "the copy's render differs from the seed region"; return 1; }
  [ "$(cnt 'ONLY IN THEIRS (1, complete):' "$f")" = 1 ] && [ "$(cnt '^NEEDS-REVIEW  PC-FIXTURE' "$f")" = 2 ] \
    && [ "$(cnt 'RETIRED-CONTRACT-TOKEN: none' "$f")" = 1 ] && [ "$(sect "$f" '**Catalog relabel')" = none ] \
    || { echo "a baseline row is missing (orientation sample, the two NEEDS-REVIEW rows, the RETIRED-CONTRACT-TOKEN line or relabel's none)"; return 1; }
  [ "$(grep '^DETECTOR-REFUSED' "$f" | awk '{ print $2 }')" = retired-layer-token.sh ] \
    || { echo "the seed's refusal set is not exactly {retired-layer-token.sh}"; return 1; }
}
j_a1() { # j_a1 <sibling>
  local f="$O/a1.out" s c b
  c="$(printf '%s\n' $STUBS | awk -F: -v n="$1" '$1 == n { print $2 }')"
  [ "$(cat "$O/a1.rc" 2>/dev/null)" = 0 ] || { echo "render rc $(cat "$O/a1.rc" 2>/dev/null)"; return 1; }
  grep -q '^HARD-UNREGISTERED-CORE-DRIFT' "$f" && [ "$(cnt 'ONLY IN OURS (1, complete):' "$f")" = 1 ] \
    || { echo "the unstubbed sections did not render (no HARD row or no orientation sample)"; return 1; }
  s="$(cnt "^DETECTOR-REFUSED  $1 exited $c " "$f")"
  [ "$s" = 1 ] || { echo "$s column-0 'DETECTOR-REFUSED  $1 exited $c' lines, want 1"; return 1; }
  if [ "$1" = retired-tokens.sh ]; then
    [ "$(cnt 'RETIRED-CONTRACT-TOKEN: none' "$f")" = 0 ] || { echo "RETIRED-CONTRACT-TOKEN: none still renders"; return 1; }
  else
    b="$(sect "$f" "$(hdr_of "$1")")"
    case "$b" in "DETECTOR-REFUSED  $1 exited $c "*) : ;; *) echo "its section reads '$(printf '%s' "$b" | head -1 | cut -c1-60)', not the refusal"; return 1 ;; esac
    [ "$(printf '%s\n' "$b" | grep -c .)" = 1 ] || { echo "its section carries more than the refusal"; return 1; }
  fi
}
j_a2() {
  local f="$O/a2.out"
  [ "$(cat "$O/a2.rc" 2>/dev/null)" = 0 ] && [ "$(sect "$f" '**Catalog relabel')" = '  ### 7. probe relabel' ] \
    && [ "$(cnt 'DETECTOR-REFUSED  relabel' "$f")" = 0 ] \
    || { echo "relabel exit 1 did not render exactly its row with no refusal"; return 1; }
}
j_a3() {
  local f="$O/a3.out"
  [ "$(cat "$O/a3.rc" 2>/dev/null)" = 0 ] || { echo "render rc $(cat "$O/a3.rc" 2>/dev/null)"; return 1; }
  [ "$(cnt "DETECTOR-REFUSED  orientation diff exited 2 for $ZE" "$f")" = 1 ] || { echo "no refusal naming zeta.md"; return 1; }
  [ "$(cnt 'DETECTOR-REFUSED  orientation' "$f")" = 1 ] || { echo "more than the one refused file refused"; return 1; }
  [ "$(cnt 'SENTINEL-THEIRS-ONLY upstream process class' "$f")" = 1 ] && [ "$(cnt 'ONLY IN THEIRS (1, complete):' "$f")" = 1 ] \
    || { echo "the FIRST file lost its sample"; return 1; }
  [ "$(cnt 'ONLY IN [A-Z]*: none' "$f")" = 0 ] || { echo "an ONLY IN …: none rendered"; return 1; }
}
j_a4() { # j_a4 <a4a|a4b> <rc-in-line>
  local f="$O/$1.out"
  [ "$(cat "$O/$1.rc" 2>/dev/null)" = 0 ] || { echo "render rc $(cat "$O/$1.rc" 2>/dev/null)"; return 1; }
  [ "$(cnt "DETECTOR-REFUSED  orientation sample exited $2 for $CL (THEIRS)" "$f")" = 1 ] || { echo "no THEIRS-side sample refusal exiting $2"; return 1; }
  [ "$(cnt 'ONLY IN OURS (1, complete):' "$f")" = 1 ] && [ "$(cnt 'ONLY IN THEIRS' "$f")" = 0 ] \
    || { echo "the OURS side did not keep its sample, or the THEIRS side rendered one"; return 1; }
}
j_a5() {
  local f="$O/a5.out"
  [ "$(cat "$O/a5.rc" 2>/dev/null)" = 0 ] || { echo "render rc $(cat "$O/a5.rc" 2>/dev/null)"; return 1; }
  [ "$(cnt "DETECTOR-REFUSED  orientation read of $CL at $T2 failed (ls-tree exited 128, show exited 0)" "$f")" = 1 ] || { echo "no ls-tree refusal for classes.md"; return 1; }
  [ "$(cnt "DETECTOR-REFUSED  orientation read of $ZE at $T2 failed (ls-tree exited 0, show exited 128)" "$f")" = 1 ] || { echo "no show refusal for zeta.md"; return 1; }
  [ "$(cnt "THEIRS absent at $T2" "$f")" = 1 ] || { echo "the truly absent thing.json did not render THEIRS absent (or a refused file did)"; return 1; }
}
j_a6() {
  local rc; rc="$(cat "$O/a6.rc" 2>/dev/null)"
  [ "$rc" = 1 ] && grep -q '^  cause: UNDECIDED .* and 1 DETECTOR-REFUSED line(s)' "$O/a6.err" \
    && grep -q '^< DETECTOR-REFUSED  orientation diff exited 2 for ' "$O/a6.err" \
    || { echo "verify rc $rc cause $(awk '/^  cause: /{ print $2; exit }' "$O/a6.err"), want 1 UNDECIDED counting 1 column-0 refusal"; return 1; }
}
ORIENT_ARMS="a3 a4a a4b a5 a6"
STUB_ARMS="a1:retired-tokens.sh a1:relabel-extension-checks.sh a1:ledger-reverify.sh a1:predicate-differential.sh a1:retired-fixtures.sh a1:retired-layer-contract.sh a1:retired-layer-passage.sh a2"
judge() { # judge <arm> -> reason on stdout, rc
  case "$1" in
    a0) j_a0 ;; a1:*) j_a1 "${1#a1:}" ;; a2) j_a2 ;; a3) j_a3 ;;
    a4a) j_a4 a4a 2 ;; a4b) j_a4 a4b 0 ;; a5) j_a5 ;; a6) j_a6 ;;
  esac
}
arm_text() {
  case "$1" in
    a0) echo "A0 CONTROL the copy renders the seed world byte-identically, with every section the stub arms refuse carrying its baseline row, and the seed's only refusal is retired-layer-token.sh" ;;
    a1:*) echo "A1 ${1#a1:} exiting non-zero renders ONE column-0 DETECTOR-REFUSED naming it and its rc in place of its section, render rc 0, the unstubbed sections intact" ;;
    a2) echo "A2 relabel exiting 1 is its FINDING: the row renders and no refusal does" ;;
    a3) echo "A3 the orientation diff failing on the SECOND CLASSIFY file refuses that file only; the first keeps its complete sample and no 'ONLY IN …: none' renders" ;;
    a4a) echo "A4a the sample awk exiting 2 refuses the THEIRS side and the OURS side keeps its sample" ;;
    a4b) echo "A4b the sample awk printing a non-numeric count refuses rather than defaulting to 0" ;;
    a5) echo "A5 a failed ls-tree and a failed show each render a refusal, while a path truly absent at theirs renders THEIRS absent" ;;
    a6) echo "A6 approve healthy, resolve the HARD drift, verify under a diff shim: rc 1 UNDECIDED counting the column-0 refusal, never BLOCKERS-RESOLVED" ;;
  esac
}

# --- ARM VERDICTS ----------------------------------------------------------------------------------
# armv <program> <arm> -> 0 the arm HOLDS, 1 it TRIPPED, X its unit never ran.
oldid() { case "$1" in A1-*) echo "a1:${1#A1-}" ;; *) printf '%s' "$1" | tr 'A-Z' 'a-z' ;; esac; }
a8_judge_s() { [ "$(cat "$1/A8.s" 2>/dev/null)" = "$a8_want_s" ]; }
a8_judge_b() {
  local b n r; b="$(cat "$1/A8.b" 2>/dev/null)"
  n="$(grep -c . <<<"$b")" || n=0; r="$(grep -F 'PREDICATE-RECLASSIFIES' <<<"$b")" || r=""
  [ "$n" = 2 ] && [ "$r" = "$a8_want_r" ] && grep -qxF "$a8_want_s" <<<"$b"
}
emit_verdict() { # <program> <arm>
  local p="$1" a="$2" u; u="$(unit_of "$a")"
  [ -f "$R/out/$p/$u.done" ] || { echo X; return 0; }
  O="$R/out/$p"
  case "$a" in
    H1) [ "$(cat "$O/H1.v" 2>/dev/null)" = "yes 0 yes" ] && echo 0 || echo 1 ;;
    A8) if a8_judge_s "$O" && a8_judge_b "$O"; then echo 0; else echo 1; fi ;;
    A9) [ "$(cat "$O/A9.v" 2>/dev/null)" = "0 0" ] && echo 0 || echo 1 ;;
    *)  if judge "$(oldid "$a")" >/dev/null; then echo 0; else echo 1; fi ;;
  esac
}
armv() { emit_verdict "$1" "$2"; } # <program> <arm>

EUNITS="w0 a1 a2 a3 a4a a4b a5 a6"
[ "$H1_STATE" = on ] && EUNITS="$EUNITS H1"
EUNITS="$EUNITS A8 A9"

# --- SCHEDULE: every unit, 4 at a time ------------------------------------------------
NEEDS=""
need() { NEEDS="$NEEDS $1:$2"; }
for _u in $EUNITS; do need ctl "$_u"; done
_n=0
for _x in $(printf '%s\n' $NEEDS | sort -u); do
  ( unit_run "${_x%%:*}" "${_x#*:}" ) &
  _n=$((_n+1)); [ "$_n" -ge 4 ] && { wait; _n=0; }
done
wait
N_UNITS="$(printf '%s\n' $NEEDS | sort -u | grep -c .)" || N_UNITS=0
printf '  units run: %s\n' "$N_UNITS"

# --- EVERY FORCED FAILURE MUST HAVE FIRED, ------------------------------
# Checked apart from the verdicts and before any is read: an arm whose shim never matched the engine's
# call shape measures a healthy render, which the ctl judges read as a failure.
# A5's shim has two call shapes (ls-tree on one file, show on another), so it fires at least twice.
_unfired=""
for _p in ctl; do
  for _f in a3:1 a4a:1 a4b:1 a5:2 a6:1; do
    [ -f "$R/out/$_p/${_f%%:*}.done" ] || continue
    _k="$(grep -c . "$R/out/$_p/${_f%%:*}.fired" 2>/dev/null)" || _k=0
    [ "$_k" -ge "${_f#*:}" ] || _unfired="$_unfired $_p/${_f%%:*}($_k)"
  done
done
[ -z "$_unfired" ] && ok "every forced-failure shim FIRED (a marker line per firing)" \
  || bad "FIXTURE BROKEN — these forced failures never fired, so their renders are healthy and every verdict on them is void:$_unfired — the engine's call shape moved away from the shim; re-key the shim, never relax this"

# --- VERDICTS ---------------------------------------------------------------------------------------
CTLBAD=""
O="$R/out/ctl"
for _a in a0 $STUB_ARMS $ORIENT_ARMS; do
  _arm="A0"; case "$_a" in a1:*) _arm="A1-${_a#a1:}" ;; a0) _arm=A0 ;; *) _arm="$(printf '%s' "$_a" | tr 'a-z' 'A-Z')"; _arm="${_arm/A4A/A4a}"; _arm="${_arm/A4B/A4b}" ;; esac
  if _why="$(judge "$_a")"; then ok "$(arm_text "$_a")"; else bad "$(arm_text "$_a") — FAILED: $_why"; CTLBAD="$CTLBAD $_arm"; fi
done
if [ "$H1_STATE" = on ]; then
  if [ "$(armv ctl H1)" = 0 ]; then
    ok "H1 a world with an unregistered ai-dlc hook renders byte-identically twice, names the hook, and --verify returns 0"
  else
    bad "H1 the unregistered-hook world: identical/verify/named = $(cat "$R/out/ctl/H1.v" 2>/dev/null), want 'yes 0 yes' — the FIX line is not stable, so --verify fails on every render of this state"; CTLBAD="$CTLBAD H1"
  fi
fi
a8_judge_s "$R/out/ctl" && ok "A8 a STABLE-only differential renders its site's population definition in one line, not 'none'" \
  || { bad "A8 a STABLE-only differential rendered [$(head -2 "$R/out/ctl/A8.s" | tr '\n' '|' | cut -c1-160)], want its population line"; CTLBAD="$CTLBAD A8"; }
a8_judge_b "$R/out/ctl" && ok "A8 beside a STABLE row, the RECLASSIFIES row renders byte-for-byte as before (status, subject, whole detail)" \
  || { bad "A8 the mixed render was [$(tr '\n' '|' < "$R/out/ctl/A8.b" | cut -c1-200)]"; CTLBAD="$CTLBAD A8"; }
[ -f "$R/out/ctl/A9.live" ] && bad "A9 FIXTURE BROKEN: the shipping region carries the live count, so the cell cannot separate the projections"
if [ "$(armv ctl A9)" = 0 ]; then
  ok "A9 a STABLE row's region survives a corpus write between approve and verify (verify rc 0 before and after; control rc 0 before)"
else
  bad "A9 verify before/after the corpus write read [$(cat "$R/out/ctl/A9.v" 2>/dev/null)], want [0 0]"; CTLBAD="$CTLBAD A9"
fi
CTLBAD="${CTLBAD# }"

# --- A7: THE RACE, FORCED, ON THE ENGINE'S OWN ORIENTATION-DIFF TEXT --------------------------
# The body is cut from emit-report.sh between the THEIRS line and the rc test, so whatever
# spelling ships is what runs.
#
# FORCED, NOT SAMPLED, BECAUSE A SAMPLE COULD NOT DISCRIMINATE. The same `<( )` spelling under 4
# concurrent workers measured 3, 0 and 0 failures in three runs of 2000 calls, and 1, 1, 2 and 9
# in four runs of 10000: a rate of roughly 0.01-0.15% that swings with load, where three expected
# failures at the low end needs ~30000 calls and still passes the unfixed engine by chance. So the
# interleaving is forced instead: `diff` is shadowed by a shell FUNCTION that runs one external
# command before the real fork, which makes bash reap the substitution first. The process-substitution
# spelling then fails EVERY call (`/dev/fd/63: Bad file descriptor`) and a temp-file spelling
# fails none. A counter proves the shadow was the `diff` that ran, so a body that bypasses it
# (`command diff`, `/usr/bin/diff`) cannot pass by never meeting the delay.
#
# THE ENGINE'S BODY NEEDS ITS HELPER. Since 0.647.0 the site stages THEIRS into "$_er_tmp" and
# pipes it through `er_pdiff`; both are cut from emit-report.sh here, so the arm drives the
# shipping function and not a restatement of it.
RB="$R/race-body.sh"; RF="$R/race-fn.sh"
awk '/^          echo "    THEIRS \$\{THEIRS\}:\$\{cp\}/ { f = 1; next } f && /^          if .*\$d_rc/ { exit } f' "$EMIT" > "$RB"
# Since BL-360 the THEIRS staging write is `er_stage`, a second helper cut the same way.
awk '/^(er_pdiff|er_stage)\(\) \{/ { f = 1 } f { print } f && /^}$/ { f = 0 }' "$EMIT" > "$RF"
_rbc="$(grep -c 'd_rc=\$?' "$RB")" || _rbc=0
_rfc="$(grep -c '^er_pdiff() {' "$RF")" || _rfc=0
_rsc="$(grep -c '^er_stage() {' "$RF")" || _rsc=0
# A helper is required only when the body CALLS it: an engine whose site diffs inline (the
# `<( )` spelling before 0.647.0) is driven as it is, and must then FAIL the forced half rather
# than stop at a harness refusal. Measured that way against 1f0a81f3's engine.
_rbu="$(grep -c 'er_pdiff' "$RB")" || _rbu=0
_rbs="$(grep -c 'er_stage' "$RB")" || _rbs=0
if [ "$_rbc" -ne 1 ] || { [ "$_rbu" -gt 0 ] && [ "$_rfc" -ne 1 ]; } || { [ "$_rbs" -gt 0 ] && [ "$_rsc" -ne 1 ]; }; then
  bad "A7 HARNESS BROKEN: the cut from emit-report.sh carries $_rbc 'd_rc=\$?' reads (want 1), calls er_pdiff $_rbu time(s) with $_rfc definition(s) cut and er_stage $_rbs time(s) with $_rsc cut — re-anchor the cut, never relax it"
else
  printf 'shared line\nSENTINEL-OURS-ONLY consumer domain class\n' > "$R/race-ours"
  # THE FORCING IS A FORK, NOT A DELAY (BL-868). The shadow used to `sleep 0.05` before the real diff,
  # which read as "give the substitution's child time to exit". Measured on bash 3.2.57, that is not
  # what closes the fd: a FOREGROUND EXTERNAL command run in the shell that owns the substitution
  # (sleep, /usr/bin/true, cat) makes bash reap the substitution and close /dev/fd/63 before diff opens
  # it, refusing 5 of 5 with the writer delayed 0s, 0.3s or 2s. A builtin (`:`) or a forking command
  # substitution refuses 0 of 5. So the shadow runs one `cat </dev/null`: the same forcing with no
  # elapsed time in it, and a slow box cannot move it.
  # The reference: the process-substitution spelling the engine shipped before 0.647.0, one line. Under
  # the forcing it must refuse 5 of 5; anything else means this bash keeps the fd open, the forcing
  # reproduces no race, and the engine's 0 refusals measure nothing.
  printf '%s\n' 'd="$(diff "$local_ours" <(printf '"'"'%s\n'"'"' "$t") 2>/dev/null)"; d_rc=$?' > "$R/race-ref.sh"
  cat > "$R/race.sh" <<'RACE'
#!/usr/bin/env bash
# race.sh <body> <ours> <iterations> <calls-file> <fn> <ref body>
#   -> "<refused> <shadow-calls> <ref refused> <ref shadow-calls>"
t="$(printf 'shared line\nSENTINEL-THEIRS-ONLY upstream process class\n')"; local_ours="$2"
. "$5"; _er_tmp="$(mktemp -d)" || exit 3
CALLS="$4"
diff() { echo x >> "$CALLS"; command cat </dev/null; command diff "$@"; }
for b in "$1" "$6"; do
  : > "$CALLS"; n=0; i=0
  while [ "$i" -lt "$3" ]; do i=$((i+1)); . "$b"; case "$d_rc" in 0|1) : ;; *) n=$((n+1)) ;; esac; done
  printf '%s %s ' "$n" "$(grep -c . "$CALLS")"
done
rm -rf "$_er_tmp"; echo
RACE
  _rr="$(bash "$R/race.sh" "$RB" "$R/race-ours" 5 "$R/calls.s" "$RF" "$R/race-ref.sh")"
  read -r _ra _rb _rc _rd <<<"$_rr"; _rs="$_ra $_rb"; _rref="$_rc $_rd"
  # A bash that holds the substitution's fd open across the call (bash 5) reads the reference `0 5`:
  # a fact about that shell, so INCONCLUSIVE, not a failure. Any other reading but `5 5` is a broken harness.
  if [ "${_rref#* }" != 5 ] || { [ "$_rref" != "0 5" ] && [ "$_rref" != "5 5" ]; }; then
    bad "A7 HARNESS BROKEN: the process-substitution reference refused/called [$_rref] under the forcing, want [5 5] (bash 3.2) or [0 5] (a bash that holds the fd), so the engine's result would mean nothing"
  elif [ "$_rref" = "0 5" ]; then
    printf '  INCONCLUSIVE  A7 forced: this bash (%s) keeps a process substitution'"'"'s fd open across the call, so the forcing cannot reproduce the bash 3.2 race and the engine'"'"'s 0 refusals are not read\n' "$BASH_VERSION"
  elif [ "${_rs#* }" != 5 ]; then
    bad "A7 the engine's orientation diff did not call the shadowed diff (calls: '${_rs#* }', want 5) — it bypasses \`diff\` by path or \`command\`, so this arm cannot reach it; re-point the arm, never relax it"
  elif [ "${_rs% *}" = 0 ]; then
    ok "A7 forced: the engine's orientation diff survives a forced interleaving 5 of 5"
  else
    bad "A7 forced: the engine's orientation diff refused ${_rs% *} of 5 under a forced interleaving — an operand is a process substitution whose /dev/fd can close before diff opens it, which under load is the BL-230 transient"
  fi
fi

echo
report_end emit-report-refusal
