#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# apply-relabel-noop-row — the catalog-relabel manifest row appears only when a heading was
# actually relabelled.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# apply.sh's relabel arm invoked `relabel-extension-checks.sh` with its output discarded and
# branched on the EXIT STATUS. That tool exits 0 three different ways -- it labelled n headings,
# it found nothing to label, or the consumer has no `extensions/` directory at all -- so the
# guard could not tell work from no work, and printed the same row either way:
#
#     RESOLVED    relabel    ext-check collisions labelled
#
# Filed by the reference consumer as PC-S332, measured on its own 0.345.0 -> 0.347.0 apply, where
# the tool printed `no unlabelled core-number collisions.` and the manifest claimed the
# collisions had been labelled.
#
# WHY A FALSE ROW COSTS MORE THAN A MISCOUNT. Step 7 of the updater skill tells the reader "Do
# NOT re-do a `RESOLVED` row by hand. Work the `WORKLIST` and `DECISION` rows, and every `NOTE`
# row as the NOTE bullet above says", and names
# catalog relabels in that legend specifically. So this row is read by someone who has been
# instructed not to verify it. On a consumer whose catalog was never colliding it says "your
# catalog was colliding and I fixed it", with no count and no subject to disambiguate it -- the
# same shape `apply-restamp-theirs` already refuses for the reconcile log, on the grounds that a
# receipt for an unwritten artifact is worse than silence.
#
# WHY IT SHIPPED. No fixture drove apply.sh over a ZERO-COLLISION consumer. `relabel-theirs-
# collision` drives the relabel tool directly and always seeds a collision; every apply fixture
# seeds a tree with nothing to label and asserted nothing about the row's absence. The bug lived
# in the one arm nothing observed.
set -uo pipefail

# HERMETIC -- scrub the operator's tuning before invoking anything (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

# Two layouts, both derived from install.sh's mapping: core/skills/<x> lands under
# .claude/skills/<x> on a consumer.
if [ -n "$ROOT" ] && [ -f "$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  APPLY="$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  APPLY="$ROOT/.claude/skills/ai-dlc-update/reconcile/apply.sh"
else
  echo "FIXTURE ERROR: apply.sh not found in either layout" >&2
  echo "  looked in: $ROOT/core/skills/... (distribution), $ROOT/.claude/skills/... (consumer)" >&2
  exit 2
fi

echo "HERMETIC-CONSUMED $APPLY"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/apply-relabel-noop.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
# shellcheck source=/dev/null
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
# shellcheck source=/dev/null
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE BROKEN: cannot source lib/inproc.sh" >&2; exit 2; }

# IN PROCESS (BL-878). Every apply of the three consumers below is asked through apl(), which hands the subject to
# lib/inproc.sh's inproc_run (a pass of $APPLY, one `inproc:` row). Two program starts remain, cells.decl's cli-usage and
# cli-pass, each compared byte for byte with the in-process answer by eqv() on a refusing and a passing input.
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A present apply.sh with neither the `apl_main() {` line nor the column-0
# source guard predates the wrap, and loading it would run its whole body: SKIP and exit 0 on a consumer (FIXTURE BROKEN
# in the distribution). Exactly one half FAILS. An unreadable subject is FIXTURE ERROR.
_ra_d=0; _ra_g=0
grep -qF 'apl_main() {' "$APPLY"; _ra_x=$?
[ "$_ra_x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $APPLY (grep exit $_ra_x)" >&2; exit 2; }
[ "$_ra_x" -ne 0 ] || _ra_d=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$APPLY"; _ra_x=$?
[ "$_ra_x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $APPLY (grep exit $_ra_x)" >&2; exit 2; }
[ "$_ra_x" -ne 0 ] || _ra_g=1
case "$_ra_d$_ra_g" in
  11) : ;;
  00) echo "SKIP: apply-relabel-noop-row: $APPLY predates the in-process wrap"; fx_skip_exit "$HERE" ;;
  *) echo "FIXTURE ERROR: $APPLY carries one half of the in-process wrap (apl_main line, column-0 source guard: $_ra_d$_ra_g)" >&2; exit 2 ;;
esac
inproc_load "$APPLY" || { echo "FIXTURE BROKEN: cannot load $APPLY in process" >&2; exit 2; }
apl() { inproc_run "$APPLY" apl_main "$@"; } # apl <args...> -> apl_main's stdout, stderr and exit

DIST="$WORK/dist"
GV="skills/ai-dlc/steps/gate-validation.md"
mkdir -p "$DIST/core/skills/ai-dlc/steps" "$DIST/core/session-driver" "$DIST/core/scripts" \
         "$DIST/core/fixtures/synthetic-fx" || exit 2
git -C "$DIST" init -q 2>/dev/null || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }
gitc() { git -C "$DIST" -c user.email=f@f -c user.name=fixture "$@"; }

# BASE. Core carries `### 25.` only. A real distribution always ships core validators, and a
# synthetic one that ships none makes apply.sh's manifest expansion empty -- which it correctly
# reports as manifest-unreadable and withholds the re-stamp for, taking this fixture's control
# arm down with it.
printf '1.0.0\n' > "$DIST/VERSION"
printf '#!/usr/bin/env bash\necho v\n' > "$DIST/core/scripts/validate-synthetic.sh"
printf '#!/usr/bin/env bash\n# fx v1\n'  > "$DIST/core/fixtures/synthetic-fx/run.sh"
printf '#!/usr/bin/env bash\n# driver v1\n' > "$DIST/core/session-driver/ai-dlc-session-driver.sh"
cat > "$DIST/core/$GV" <<'CORE'
# Gate validation (fixture)
### 25. Existing universal check.
CORE
gitc add -A && gitc commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"

# THEIRS adds `### 26.` to core. That is what makes an extension already defining `### 26.` a
# NEW-THIS-PULL collision -- invisible without --theirs, which is the flag apply.sh passes.
printf '2.0.0\n' > "$DIST/VERSION"
printf '#!/usr/bin/env bash\n# driver v2 UPSTREAM\n' > "$DIST/core/session-driver/ai-dlc-session-driver.sh"
printf '#!/usr/bin/env bash\n# fx v2 UPSTREAM\n' > "$DIST/core/fixtures/synthetic-fx/run.sh"
cat > "$DIST/core/$GV" <<'CORE'
# Gate validation (fixture)
### 25. Existing universal check.
### 26. Core gate-check adjudication verdict.
CORE
gitc add -A && gitc commit -q -m theirs
THEIRS="$(git -C "$DIST" rev-parse HEAD)"

# THREE CONSUMER SHAPES, all sitting at BASE. `clean` and `noext` are the two zero-collision
# trees the defect fired on; `collide` is the one where the work is real.
mkconsumer() { # <dir> <clean|noext|collide>
  local c="$1" kind="$2"
  mkdir -p "$c/.claude/skills/ai-dlc/steps" "$c/.claude/session-driver" \
           "$c/tests/fixtures/synthetic-fx" || return 2
  printf '#!/usr/bin/env bash\n# driver v1\n' > "$c/.claude/session-driver/ai-dlc-session-driver.sh"
  printf '#!/usr/bin/env bash\n# fx v1\n'     > "$c/tests/fixtures/synthetic-fx/run.sh"
  cat > "$c/.claude/$GV" <<'CORE'
# Gate validation (fixture)
### 25. Existing universal check.
CORE
  printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$c/.claude/.ai-dlc-version"
  case "$kind" in
    noext) : ;;   # no extensions/ at all -- relabel exits 0 before it reaches its own summary
    clean)
      mkdir -p "$c/.claude/skills/ai-dlc/extensions/checks" || return 2
      # An extension that exists and does NOT collide: numbered inside the consumer's reserved
      # band, which is the state a correctly-maintained catalog is in.
      cat > "$c/.claude/skills/ai-dlc/extensions/checks/mydomain.md" <<'EXT'
---
kind: check
id: mydomain
hooks: steps/gate-validation.md
---
### 90. Ext deployed-ranges consistency gate.
EXT
      ;;
    collide)
      mkdir -p "$c/.claude/skills/ai-dlc/extensions/checks" || return 2
      cat > "$c/.claude/skills/ai-dlc/extensions/checks/mydomain.md" <<'EXT'
---
kind: check
id: mydomain
hooks: steps/gate-validation.md
---
### 26. Ext deployed-ranges consistency gate.
EXT
      ;;
  esac
  return 0
}

# Read the manifest by FIELD, not by substring. `grep -q relabel` is satisfied by the word
# appearing in any column of any row, including a DECISION or a detail string.
relabel_row() { awk -F'\t' '$1=="RESOLVED" && $2=="relabel"' <<<"$1"; }

echo "apply-relabel-noop-row:"

# =============================================================================
# 0. THE CONTROL — apply.sh ran at all.
# =============================================================================
# Every assertion below is an ABSENCE, and an absence over a program that died on its first line
# is indistinguishable from an absence over a program that worked. Establish that this synthetic
# tree produces a manifest before reading a missing row as evidence.
C_CLEAN="$WORK/c-clean"; mkconsumer "$C_CLEAN" clean || { echo "FIXTURE ERROR: mkconsumer failed" >&2; exit 2; }
OUT_CLEAN="$(apl "$DIST" "$BASE" "$C_CLEAN" "$THEIRS" 2>&1)"
n_resolved="$(awk -F'\t' '$1=="RESOLVED"' <<<"$OUT_CLEAN" | grep -c . || true)"
if [ "$n_resolved" -gt 0 ]; then
  ok "CONTROL: the apply produced $n_resolved RESOLVED row(s) on the clean tree — a missing relabel row below is an absence, not a dead program"
else
  bad "FIXTURE BROKEN: the apply produced no RESOLVED rows at all, so every absence asserted below proves nothing"
  echo; echo "apply-relabel-noop-row: FIXTURE BROKEN" >&2; exit 2
fi

# =============================================================================
# 1. A CLEAN CATALOG PRODUCES NO ROW.
# =============================================================================
if [ -z "$(relabel_row "$OUT_CLEAN")" ]; then
  ok "a consumer whose catalog has NO unlabelled collisions gets no \`RESOLVED relabel\` row"
else
  bad "the clean tree still claims a relabel: $(relabel_row "$OUT_CLEAN" | tr '\t' '|') — this is PC-S332, the row asserting work that did not occur"
fi

# =============================================================================
# 2. NO extensions/ DIRECTORY AT ALL — the third exit-0 path.
# =============================================================================
# `relabel-extension-checks.sh` returns 0 with `no extensions/ under <dir>` BEFORE it reaches its
# own summary, so this path never even counts. The consumer's filed entry did not name it; a
# guard keyed on the count covers it for the same reason it covers the clean tree.
C_NOEXT="$WORK/c-noext"; mkconsumer "$C_NOEXT" noext || { echo "FIXTURE ERROR: mkconsumer failed" >&2; exit 2; }
EQ="$WORK/eq"; mkdir -p "$EQ" || { echo "FIXTURE ERROR: mkdir eq" >&2; exit 2; }
cp -R "$C_NOEXT" "$WORK/c-noext.pristine" || { echo "FIXTURE ERROR: cp pristine failed" >&2; exit 2; }
apl "$DIST" "$BASE" "$C_NOEXT" "$THEIRS" > "$EQ/cli-pass.ip.out" 2> "$EQ/cli-pass.ip.err"; echo "$?" > "$EQ/cli-pass.ip.rc"
OUT_NOEXT="$(cat "$EQ/cli-pass.ip.out" "$EQ/cli-pass.ip.err")"
if [ -z "$(relabel_row "$OUT_NOEXT")" ]; then
  ok "a consumer with no extensions/ directory gets no \`RESOLVED relabel\` row either"
else
  bad "a consumer with no extensions/ at all claims a relabel: $(relabel_row "$OUT_NOEXT" | tr '\t' '|')"
fi

# =============================================================================
# 3. A REAL COLLISION PRODUCES A ROW, AND THE ROW CARRIES ITS COUNT.
# =============================================================================
# The other half. A guard tightened until it never fires is not a fix, it is the same defect
# pointing the other way, and it would leave the operator re-doing work the tool already did.
C_HIT="$WORK/c-collide"; mkconsumer "$C_HIT" collide || { echo "FIXTURE ERROR: mkconsumer failed" >&2; exit 2; }
OUT_HIT="$(apl "$DIST" "$BASE" "$C_HIT" "$THEIRS" 2>&1)"
ROW_HIT="$(relabel_row "$OUT_HIT")"
if [ -n "$ROW_HIT" ]; then
  ok "a consumer with a real unlabelled collision DOES get a \`RESOLVED relabel\` row"
else
  bad "a real collision produced NO relabel row — the guard was tightened past the work it is meant to report"
fi
# The subject field, not the whole line: the count is what makes the row checkable against the
# reader's own tree, and it is the field every other RESOLVED arm in apply.sh carries.
subj="$(awk -F'\t' '$1=="RESOLVED" && $2=="relabel"{print $3}' <<<"$OUT_HIT")"
case "$subj" in
  [1-9]*" colliding heading(s)") ok "the row names its COUNT in the subject field ('$subj'), so a reader can check it against their own catalog" ;;
  "")  bad "the relabel row has no subject field at all — a bare row is the one a reader cannot sanity-check, which is half of what PC-S332 reported" ;;
  *)   bad "the relabel row's subject is '$subj', which carries no positive count" ;;
esac
# ...and the work must ACTUALLY have happened. A row with a plausible count over a heading that
# was never rewritten is the same defect with better wording.
if grep -qE '^### 26\. \[ext:mydomain\] ' "$C_HIT/.claude/skills/ai-dlc/extensions/checks/mydomain.md"; then
  ok "the heading really was rewritten to '### 26. [ext:mydomain] …' — the row reports work that occurred"
else
  bad "the row claims a relabel but the extension heading is unchanged — the count is as false as the old bare row"
fi

# =============================================================================
# 4. THE CLI HALVES — `bash apply.sh` answers as the in-process pass does.
# =============================================================================
# One program start per distinct CLI outcome (cells.decl): a usage refusal (exit 1) and a passing apply over the
# consumer with no extensions/ (exit 0, the cheapest passing run), each compared byte for byte (stdout, stderr, exit) with the in-process answer. The
# passing apply writes its consumer, so the pristine copy is restored between the two sides; cli-pass's in-process side is
# section 2's own pass.
EQ="$WORK/eq"; mkdir -p "$EQ" || { echo "FIXTURE ERROR: mkdir eq" >&2; exit 2; }
cli_side() { # cli_side <id> <args...> -> the CLI answer in $EQ/<id>.cl.{out,err,rc}, tagged FXCELL=<id>
  local id="$1"; shift
  FXCELL="$id" command bash "$APPLY" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
}
same3() { # same3 <id> -> 0 when the in-process and CLI answers agree on stdout, stderr and exit
  cmp -s "$EQ/$1.ip.out" "$EQ/$1.cl.out" && cmp -s "$EQ/$1.ip.err" "$EQ/$1.cl.err" && cmp -s "$EQ/$1.ip.rc" "$EQ/$1.cl.rc"
}
apl > "$EQ/cli-usage.ip.out" 2> "$EQ/cli-usage.ip.err"; echo "$?" > "$EQ/cli-usage.ip.rc"
cli_side cli-usage; same3 cli-usage; eq_u=$?
# cli-pass: the in-process side is section 2's own pass over C_NOEXT; the consumer is put back to its pristine state first.
mv "$C_NOEXT" "$WORK/c-noext.ip" && cp -R "$WORK/c-noext.pristine" "$C_NOEXT" || { echo "FIXTURE ERROR: restoring c-noext failed" >&2; exit 2; }
cli_side cli-pass "$DIST" "$BASE" "$C_NOEXT" "$THEIRS"; same3 cli-pass; eq_p=$?
rc_u="$(cat "$EQ/cli-usage.cl.rc" 2>/dev/null)"; rc_p="$(cat "$EQ/cli-pass.cl.rc" 2>/dev/null)"
if [ "$rc_u" = 1 ] && [ "$rc_p" = 0 ] && ! cmp -s "$EQ/cli-usage.cl.out" "$EQ/cli-pass.cl.out" \
   && [ -s "$EQ/cli-pass.cl.out" ] && grep -q 'RESOLVED' "$EQ/cli-pass.cl.out"; then
  ok "the two CLI cells differ: usage refusal exit $rc_u with no manifest, passing apply exit $rc_p carrying RESOLVED rows"
else
  bad "the CLI cells do not differ as designed (usage rc='$rc_u', pass rc='$rc_p') -- an equivalence over two identical answers proves nothing"
fi
[ "$eq_u" -eq 0 ] && ok "cli-usage: stdout, stderr and exit of \`bash apply.sh\` equal the in-process answer" \
  || bad "cli-usage: the CLI run and the in-process pass disagree (see $EQ/cli-usage.*)"
[ "$eq_p" -eq 0 ] && ok "cli-pass: stdout, stderr and exit of \`bash apply.sh\` equal the in-process answer" \
  || bad "cli-pass: the CLI run and the in-process pass disagree (see $EQ/cli-pass.*)"

echo
report_end apply-relabel-noop-row
