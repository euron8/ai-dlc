#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# apply-restamp-theirs — the re-stamp reads VERSION from THEIRS, never from the
# distribution's working tree.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# apply.sh resolves every file it copies through `git show "${THEIRS}:core/..."`, and
# takes the stamp's `commit:` from `git rev-parse "$THEIRS"`. One line did not follow:
# the stamp's `version:` came from `cat "$DIST/VERSION"` — whatever ref the operator's
# distribution checkout happened to be sitting on.
#
# Hit live on the v0.92.0 pull. The checkout sat on a v0.93.0 branch while theirs was
# origin/main at v0.92.0, so the stamp was written `version: 0.93.0` against 0.92.0
# content, and had to be corrected by hand. Note the shape: the SAME stamp carried a
# `commit:` taken correctly from theirs. The result is not merely stale, it is
# INCOHERENT — a version and a commit that cannot both be true of one tree.
#
# Why it matters more than a cosmetic field: `.ai-dlc-version` is what the NEXT pull
# reads to compute its base. A stamp that overstates the version silently mis-bases that
# merge, and the damage surfaces a pull later, far from the run that caused it.
#
# WHY THIS FIXTURE IS NOT VACUOUS. The assertion only means anything if the working
# tree's VERSION differs from THEIRS' — otherwise `cat` and `git show` agree and a
# reverted fix would still pass. So the dist repo below is built with THREE different
# versions (base 1.0.0, theirs 2.0.0, working tree 9.9.9) and assertion 0 FAILS THE
# FIXTURE if that separation ever collapses.
#

set -uo pipefail
# No arguments: any argument is a usage error, never a silent run.
[ "$#" -eq 0 ] || { echo "apply-restamp-theirs: usage: run.sh" >&2; exit 2; }

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

# apply.sh WRITES the in-flight marker; pre-push READS it. Both halves are resolved here,
# because a marker nothing refuses on is a file, not a guard.
for cand in "$ROOT/core/git-hooks/pre-push" "$ROOT/.githooks/pre-push"; do
  [ -f "$cand" ] && PREPUSH="$cand" && break
done
[ -n "${PREPUSH:-}" ] || { echo "FIXTURE ERROR: pre-push not found in either layout — the marker's READER cannot be evaluated, and passing without it would report the guard as working when it was never run." >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/apply-restamp.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

DIST="$WORK/dist"; CONSUMER="$WORK/consumer"
mkdir -p "$DIST/core/session-driver" "$CONSUMER/.claude/session-driver" \
         "$DIST/core/scripts" || exit 2
git -C "$DIST" init -q 2>/dev/null || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }
gitc() { git -C "$DIST" -c user.email=f@f -c user.name=fixture "$@"; }

# BASE at 1.0.0.
printf '1.0.0\n' > "$DIST/VERSION"
printf '#!/usr/bin/env bash\n# driver v1\n' > "$DIST/core/session-driver/ai-dlc-session-driver.sh"
# A real distribution ALWAYS ships core validators, and since v0.160.0 the manifest
# claims them as `core/scripts/ai-dlc/*` -- one entry apply.sh expands against THEIRS'
# tree. A synthetic DIST that ships none makes that expansion empty, which apply.sh
# reports as manifest-unreadable and withholds the re-stamp for, correctly: a stamp
# claiming a version whose validators are absent is the failure it exists to prevent.
# This fixture used to pass through that hole -- the old 27-name enumeration produced
# 27 individual cat-file misses, and 27 misses read as "nothing to relocate".
printf '#!/usr/bin/env bash\necho v\n' > "$DIST/core/scripts/validate-synthetic.sh"
# A fixture that CHANGES in the range, so the write ORDER is observable. core/fixtures/
# sorts before core/scripts/ and core/session-driver/, so preclassify emits it first and
# the unsorted order is exactly backwards: the test lands before its subject.
mkdir -p "$DIST/core/fixtures/synthetic-fx" "$CONSUMER/tests/fixtures/synthetic-fx" || exit 2
printf '#!/usr/bin/env bash\n# fx v1\n' > "$DIST/core/fixtures/synthetic-fx/run.sh"
printf '#!/usr/bin/env bash\n# fx v1\n' > "$CONSUMER/tests/fixtures/synthetic-fx/run.sh"
gitc add -A && gitc commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"

# THEIRS at 2.0.0 — this is the version the stamp must record.
printf '2.0.0\n' > "$DIST/VERSION"
printf '#!/usr/bin/env bash\n# driver v2 UPSTREAM\n' > "$DIST/core/session-driver/ai-dlc-session-driver.sh"
printf '#!/usr/bin/env bash\n# fx v2 UPSTREAM\n' > "$DIST/core/fixtures/synthetic-fx/run.sh"
gitc add -A && gitc commit -q -m theirs
THEIRS="$(git -C "$DIST" rev-parse HEAD)"
THEIRS_SHORT="$(git -C "$DIST" rev-parse --short HEAD)"

# The operator's checkout is on something else entirely — a later release branch. This is
# the live condition: the tree says 9.9.9 while the pull is bringing 2.0.0.
printf '9.9.9\n' > "$DIST/VERSION"

# Consumer sits at BASE, unmodified: the plainest possible pull.
printf '#!/usr/bin/env bash\n# driver v1\n' > "$CONSUMER/.claude/session-driver/ai-dlc-session-driver.sh"
STAMP="$CONSUMER/.claude/.ai-dlc-version"
printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$STAMP"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
# --- THE SUBJECT IS ASKED IN PROCESS ---------------------------------------------------------------
# apply.sh is loadable: sourcing it defines `apl_main` and returns at its column-0 source guard. It is sourced ONCE
# here, and `AP_S=<apply.sh> ap_eng <args>` answers what `bash <apply.sh> <args>` prints and exits with, in a subshell
# made to look like a fresh bash (core/fixtures/lib/inproc.sh). A copy of the reconcile directory is sourced inside
# that run's own subshell. KEPT END TO END: the two `cli` cells (cli-pass, cli-refuse), each byte-compared with the
# in-process answer, and the real pre-push hook (EXIT trap, set -m pool, top-level exit), which cells.decl names.
# shellcheck source=/dev/null
. "$HERE/../lib/inproc.sh" 2>/dev/null || { echo "FIXTURE BROKEN: core/fixtures/lib/inproc.sh absent beside $HERE" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
# PRE-WRAP CONSUMER GATE (BL-878): a consumer one pull behind carries this fixture with an apply.sh that predates the
# in-process wrap, and loading it would run its whole body. Neither half is SKIP (FIXTURE BROKEN in the distribution,
# exit 0 on a consumer); exactly one half FAILS; an unreadable subject is FIXTURE ERROR.
grep -qxF 'apl_main() { set -uo pipefail' "$APPLY"; _wg1=$?
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$APPLY"; _wg2=$?
[ "$_wg1" -le 1 ] && [ "$_wg2" -le 1 ] || { echo "FIXTURE ERROR: cannot read $APPLY (grep exit $_wg1/$_wg2)" >&2; exit 2; }
case "$_wg1$_wg2" in
  00) : ;;
  11) echo "SKIP: apply-restamp-theirs: $APPLY predates the in-process wrap"; fx_skip_exit "$HERE" ;;
  *) bad "$APPLY carries one half of the in-process wrap (apl_main line: rc $_wg1, column-0 source guard: rc $_wg2) -- a respelled subject this fixture cannot drive"
     report_end apply-restamp-theirs ;;
esac
inproc_load "$APPLY" || { echo "FIXTURE BROKEN: sourcing $APPLY defined nothing" >&2; exit 2; }
declare -F apl_main >/dev/null || { echo "FIXTURE BROKEN: $APPLY defined no apl_main when sourced" >&2; exit 2; }
ap_eng() { inproc_run "$AP_S" apl_main "$@"; } # AP_S=<apply.sh> ap_eng [args...] -> what `bash <apply.sh> [args...]` prints and exits with
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A consumer receives this file on the pull
# that carries it, and the assertion's subject may land later in the same pull -- or in the
# gated reconcile after it. "Subject not installed" is NOT "subject regressed", and
# reporting it as a failure is what deadlocked the reference consumer: the self-update
# requires its derived fixtures green, so a fixture failing on an un-upgraded subject blocks
# the very cycle that would install it.
#
# In the DISTRIBUTION the subject is always present, so an absent one is a hard error and
# upstream can never go green vacuously. Only a consumer layout skips.
IS_DIST=0; [ -d "$ROOT/core/skills/ai-dlc" ] && IS_DIST=1
skip() { # skip <what> <why>
  if [ "$IS_DIST" = 1 ]; then bad "$1 -- $2 (HARD in the distribution: the subject must be present here)"
  else printf '  SKIP  %s -- %s\n' "$1" "$2"; fi
}

echo "apply-restamp-theirs:"

# --- Assertion 0: the three versions are actually distinct --------------------
# Without this the whole fixture can go quietly vacuous.
wt_ver="$(cat "$DIST/VERSION")"
theirs_ver="$(git -C "$DIST" show "$THEIRS:VERSION")"
if [ "$wt_ver" != "$theirs_ver" ] && [ "$theirs_ver" != "1.0.0" ]; then
  ok "setup: working tree ($wt_ver) differs from theirs ($theirs_ver) — the assertion can fail"
else
  bad "setup: working tree ($wt_ver) and theirs ($theirs_ver) are not separated — every assertion below would pass vacuously"
  echo; echo "FIXTURE BROKEN apply-restamp-theirs: the separation this fixture depends on is gone."
  exit 2
fi

# The pristine consumer, kept so the cli cells below start from the very tree the in-process baseline did.
cp -R "$CONSUMER" "$WORK/consumer.pristine" || { echo "FIXTURE ERROR: could not copy the pristine consumer" >&2; exit 2; }

# --- Assertion 1: the stamp records THEIRS' version ---------------------------
out="$(AP_S="$APPLY" ap_eng "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>&1)"
got_ver="$(sed -n 's/^version: *//p' "$STAMP")"
if [ "$got_ver" = "$theirs_ver" ]; then
  ok "stamp records theirs' version ($theirs_ver)"
elif [ "$got_ver" = "$wt_ver" ]; then
  bad "stamp records the WORKING TREE's version ($got_ver), not theirs ($theirs_ver) — this is the v0.92.0 defect: apply.sh read VERSION with cat instead of git show \"\$THEIRS:VERSION\""
else
  bad "stamp records $got_ver, expected theirs' $theirs_ver"
fi

# --- Assertion 2: version and commit describe the SAME tree -------------------
# The defect's signature is a coherent commit beside an incoherent version, so assert
# the pair, not just the field that broke.
got_sha="$(sed -n 's/^commit: *//p' "$STAMP")"
if [ "$got_sha" = "$THEIRS_SHORT" ] && [ "$got_ver" = "$theirs_ver" ]; then
  ok "version and commit describe one tree ($theirs_ver @ $THEIRS_SHORT)"
else
  bad "stamp is internally inconsistent: version $got_ver with commit $got_sha (theirs is $theirs_ver @ $THEIRS_SHORT)"
fi

# --- Assertion 3: the control — checkout ON theirs still stamps correctly -----
# A fix that hardcoded the wrong ref, or broke the ordinary path, fails here.
printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$STAMP"
# Put the working tree genuinely ON theirs. `git checkout` will NOT do it here: VERSION
# is modified-and-uncommitted, so the dirty 9.9.9 survives the checkout and the "control"
# would silently still be testing the mismatched case.
git -C "$DIST" show "$THEIRS:VERSION" > "$DIST/VERSION"
AP_S="$APPLY" ap_eng "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>&1
ctl_ver="$(sed -n 's/^version: *//p' "$STAMP")"
if [ "$ctl_ver" = "$theirs_ver" ]; then
  ok "control: checkout already on theirs still stamps $theirs_ver"
else
  bad "control: checkout on theirs stamped $ctl_ver, expected $theirs_ver — the ordinary path regressed"
fi

# --- Assertion 4: A FIXTURE IS WRITTEN AFTER ITS SUBJECT ----------------------
# core/fixtures/ sorts first, so preclassify's natural order writes the test before the
# thing it tests. A suite run in that window fails on behaviour that is not installed
# yet: on the 0.156.0 -> 0.162.0 pull, check-15-bypass could not find core-paths.sh and
# core-write-guard read the core-fixture deny as `allow`. Assert every fixtures/ row
# lands after every non-fixture row.
fx_first="$(printf '%s\n' "$out" | awk '$0 ~ /pure-apply/ {print $3}' | grep -n '^fixtures/' | head -1 | cut -d: -f1)"
nonfx_last="$(printf '%s\n' "$out" | awk '$0 ~ /pure-apply/ {print $3}' | grep -vn '^fixtures/' | tail -1 | cut -d: -f1)"
if [ -z "$fx_first" ] || [ -z "$nonfx_last" ]; then
  bad "setup: the report has no fixtures/ row and/or no non-fixture row — assertion 4 would pass vacuously"
elif [ "$fx_first" -gt "$nonfx_last" ]; then
  ok "a changed fixture is written AFTER every non-fixture core file (test never precedes subject)"
else
  bad "a fixture was written at position $fx_first, before a non-fixture core file at $nonfx_last — the suite can run against a test newer than its subject"
fi

# --- Assertion 5: THE IN-FLIGHT MARKER CLEARS WITH THE STAMP ------------------
# Ordering cannot make the window safe on its own -- only one of the two directions can
# be last, and the reverse one breaks OLD assertions against a newer subject (this very
# fixture and apply-drift-refile both failed that way against a newer apply.sh). So the
# tree carries a marker saying "do not judge me yet", and pre-push refuses the suite while
# it exists. It must be GONE after a clean apply, or the consumer can never push again.
APPLYING="$CONSUMER/.claude/.ai-dlc-applying"
if [ ! -f "$APPLYING" ]; then
  ok "the in-flight marker is cleared by a clean apply (pre-push is not left wedged)"
else
  bad "the in-flight marker survived a CLEAN apply — every subsequent push blocks on a consistent tree"
fi
# --- THE ONE STEP-7 ARTIFACT apply.sh DOES NOT WRITE, NAMED ON THE RUN THAT OWES IT ---------
#
# Filed by the reference consumer as PC-S329-APPLY-SH-NEVER-WRITES-THE-RECONCILE-LOG. Step 7 used
# to hand the re-stamp and the log to the reader in ONE bullet, one sentence apart from
# "apply.sh does this; you do not edit the stamp" — so a reader attributed both to the tool.
# Measured when they filed it: ZERO occurrences of the token in apply.sh against NINE files in
# the distribution naming the artifact. The run succeeded, the stamp advanced, and the only
# durable record of what the apply decided was absent.
#
# THE TOOL DOES NOT WRITE IT, DELIBERATELY — the log records the gates, the post-apply re-runs,
# the validators and the ledger decisions, none of which apply.sh can observe, and a skeleton it
# could fill would ship a file whose empty sections read as written ones. What it does instead is
# SAY SO, on the successful run, where the omission happens. Prose alone is what failed here the
# first time, which is why this is asserted rather than left to the step file.
if grep -q 'NOT WRITTEN BY THIS TOOL' <<<"$out" && grep -q 'reconcile-log' <<<"$out"; then
  ok "a successful apply NAMES the reconcile log it does not write"
else
  bad "a successful apply said nothing about reconcile-log-<ts>.md. The step file hands it to the reader in the same breath as the re-stamp this tool DOES perform, so silence here is what let a whole pull finish with no durable record of what it decided"
fi
# CONTROL: it must not claim to have written it, which is the failure mode a louder message
# invites. The line is a hand-off, not a receipt.
if grep -qE 'RESOLVED[[:space:]]+reconcile-log|wrote .*reconcile-log' <<<"$out"; then
  bad "apply.sh reported the reconcile log as something it RESOLVED or wrote. It writes no such file, and a receipt for an unwritten artifact is worse than silence"
else
  ok "  and it does not claim to have written it — the line is a hand-off, not a receipt"
fi

if grep -q 'RESOLVED.*consistent' <<<"$out"; then
  ok "  and the report says so, rather than clearing it silently"
else
  bad "  the report does not record the tree becoming consistent"
fi

# --- Assertion 6: A WITHHELD RE-STAMP KEEPS THE MARKER -----------------------
# The half that matters. A tree that could not be fully applied IS inconsistent, so the
# marker must stay and keep blocking the suite. Clearing it in a trap would have looked
# correct and defeated the whole guard. Drive the same withheld path assertion 0's
# manifest-unreadable case uses: no core/scripts/ in THEIRS means zero validators.
RECON2="$WORK/recon2"
mkdir -p "$RECON2" || exit 2
cp "$(dirname "$APPLY")"/* "$RECON2/" 2>/dev/null || { echo "FIXTURE ERROR: could not copy reconcile/" >&2; exit 2; }
printf '# no core_manifest block here\n' > "$RECON2/setup-sites.md"
APPLY2="$RECON2/apply.sh"
W2="$WORK/consumer2"
mkdir -p "$W2/.claude/session-driver" "$W2/tests/fixtures" || exit 2
printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$W2/.claude/.ai-dlc-version"
out6="$(AP_S="$APPLY2" ap_eng "$DIST" "$BASE" "$W2" "$THEIRS" 2>&1)"
if grep -q 'restamp-withheld' <<<"$out6"; then
  if [ -f "$W2/.claude/.ai-dlc-applying" ]; then
    ok "a withheld re-stamp LEAVES the marker — the suite stays blocked on a partial tree"
  else
    bad "the marker was cleared despite a withheld re-stamp — a partially applied tree would report false fixture failures as if they were real"
  fi
else
  bad "setup: could not drive a withheld re-stamp, so assertion 6 proves nothing"
  printf '%s\n' "$out6" | sed 's/^/        /' | head -5
fi

# --- A FINISH OVER A TREE AN EARLIER APPLY ALREADY STAMPED (finish-base-unverified; the post-stamp staging remedy) --
# Assertion 3 left CONSUMER stamped at THEIRS with no marker: the state an earlier apply (or finish) leaves. A
# --finish naming BASE there cannot verify anything, and re-running it with the stamp's own commit as base (THEIRS)
# makes every range empty. FC1 needs the row to say so; FC2 and FC3 are its twins, each one property apart (the stamp
# is not THEIRS / the marker is present), and keep the re-run remedy. FE1 drives a staging refusal that runs AFTER
# write_stamp under --finish, where no marker is left, and needs it NOT to send the reader to a --finish re-run.
fc_row() { awk -F'\t' '$1=="WORKLIST" && $2=="finish-base-unverified"' <<<"$1"; }
FC1_O="$(AP_S="$APPLY" ap_eng --finish "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>&1)"
FC1_R="$(fc_row "$FC1_O")"
if [ "$(grep -c . <<<"$FC1_R")" = 1 ] && grep -qF 'there is nothing left to verify' <<<"$FC1_R" && grep -qF 'Deliver' <<<"$FC1_R" \
   && ! grep -qF "Re-run with the stamp's own" <<<"$FC1_R"; then
  ok "FC1 stamp == THEIRS and no marker: finish-base-unverified says nothing is left to verify and to deliver, and prescribes no re-run"
else
  bad "FC1 stamp == THEIRS, no marker: the finish-base-unverified row is wrong: $(cut -c1-500 <<<"$FC1_R")"
fi
FC2_C="$WORK/fc2"; FC2_T="$(gitc commit-tree "${THEIRS}^{tree}" -p "$THEIRS" -m other)"
rm -rf "$FC2_C"; cp -R "$CONSUMER" "$FC2_C" && printf 'version: 2.0.0\ncommit: %s\n' "$FC2_T" > "$FC2_C/.claude/.ai-dlc-version"
FC2_R="$(fc_row "$(AP_S="$APPLY" ap_eng --finish "$DIST" "$BASE" "$FC2_C" "$THEIRS" 2>&1)")"
if [ -n "$FC2_T" ] && [ "$(grep -c . <<<"$FC2_R")" = 1 ] && grep -qF "Re-run with the stamp's own" <<<"$FC2_R" && ! grep -qF 'nothing left to verify' <<<"$FC2_R"; then
  ok "FC2 stamp != THEIRS: finish-base-unverified keeps the re-run remedy"
else
  bad "FC2 stamp != THEIRS (commit '$FC2_T'): the row lost the re-run remedy or gained the deliver text: $(cut -c1-500 <<<"$FC2_R")"
fi
FC3_C="$WORK/fc3"; rm -rf "$FC3_C"; cp -R "$CONSUMER" "$FC3_C" && printf 'base: %s\ntheirs: %s\n' "$BASE" "$THEIRS" > "$FC3_C/.claude/.ai-dlc-applying"
FC3_R="$(fc_row "$(AP_S="$APPLY" ap_eng --finish "$DIST" "$BASE" "$FC3_C" "$THEIRS" 2>&1)")"
if [ "$(grep -c . <<<"$FC3_R")" = 1 ] && grep -qF "Re-run with the stamp's own" <<<"$FC3_R" && ! grep -qF 'nothing left to verify' <<<"$FC3_R"; then
  ok "FC3 stamp == THEIRS but the marker is present: finish-base-unverified keeps the re-run remedy"
else
  bad "FC3 stamp == THEIRS with the marker present: the row lost the re-run remedy or gained the deliver text: $(cut -c1-500 <<<"$FC3_R")"
fi
FE_C="$WORK/fe"; rm -rf "$FE_C"; cp -R "$CONSUMER" "$FE_C" && mkdir -p "$FE_C/.claude/schemas" "$FE_C/scripts/ai-dlc" \
  && printf '#!/usr/bin/env bash\nexit 0\n' > "$FE_C/scripts/ai-dlc/sync-transient-ignore.sh" \
  && printf '{"paths":[{"transient":true,"ignore":"scratch-x/"}]}\n' > "$FE_C/.claude/schemas/pipeline-state-paths.json" \
  && git -C "$FE_C" init -q 2>/dev/null
FE_O="$(TMPDIR="$WORK/no-such-tmpdir" AP_S="$APPLY" ap_eng --finish "$DIST" "$BASE" "$FE_C" "$THEIRS" 2>&1)"
FE_R="$(awk -F'\t' '$2=="staging-refused" && index($4, "transient path patterns")' <<<"$FE_O")"
if [ ! -e "$FE_C/.claude/.ai-dlc-applying" ] && [ "$(grep -c . <<<"$FE_R")" = 1 ] && grep -qF 'post-write-gates' <<<"$FE_R" && ! grep -qF 're-run --finish' <<<"$FE_R"; then
  ok "FE1 a staging refusal after the stamp under --finish (no marker) names no --finish re-run"
else
  bad "FE1 the post-stamp staging refusal row is wrong or absent: $(cut -c1-500 <<<"$FE_R")"
fi

# --- THE COMMAND LINE ANSWERS WHAT THE IN-PROCESS RUN ANSWERS (cli-pass, cli-refuse) ------------------
# One `cli` cell per distinct command-line outcome of apply.sh, each byte-compared (stdout, stderr, exit) with ap_eng on
# the same input from the same path: a completed apply (rc 0, the stamp advanced) and a usage refusal (rc 2).
EQ="$WORK/eq"; EQC="$EQ/consumer"; EQ_FN=ap_eng
eq_cell() { # eq_cell <id> <arg>... : in-process then cli on a fresh copy of the pristine consumer at the same path; leaves $EQ/<id>.{in,cli}.{out,err,rc}
  local id="$1"; shift
  rm -rf "$EQC"; mkdir -p "$EQ" && cp -R "$WORK/consumer.pristine" "$EQC" || return 1
  AP_S="$APPLY" "$EQ_FN" "$@" > "$EQ/$id.in.out" 2> "$EQ/$id.in.err"; echo $? > "$EQ/$id.in.rc"
  rm -rf "$EQC"; cp -R "$WORK/consumer.pristine" "$EQC" || return 1
  FXCELL="$id" bash "$APPLY" "$@" > "$EQ/$id.cli.out" 2> "$EQ/$id.cli.err"; echo $? > "$EQ/$id.cli.rc"
}
eq_same() { # eq_same <id> -> 0 when stdout, stderr and exit are byte-identical
  cmp -s "$EQ/$1.in.out" "$EQ/$1.cli.out" && cmp -s "$EQ/$1.in.err" "$EQ/$1.cli.err" && cmp -s "$EQ/$1.in.rc" "$EQ/$1.cli.rc"
}
if eq_cell cli-pass "$DIST" "$BASE" "$EQC" "$THEIRS" && eq_cell cli-refuse --bogus "$DIST" "$BASE" "$EQC" "$THEIRS" && eq_cell cli-error "$DIST" "$BASE" "$EQC"; then
  if eq_same cli-pass && [ "$(cat "$EQ/cli-pass.cli.rc")" = 0 ] && [ -s "$EQ/cli-pass.cli.out" ]; then
    ok "cli-pass: the command line gives the in-process answer on a completed apply (rc 0, $(wc -c < "$EQ/cli-pass.cli.out" | tr -d ' ') bytes of report)"
  else
    bad "cli-pass: the command line and the in-process run differ on a completed apply (cli rc $(cat "$EQ/cli-pass.cli.rc"), in rc $(cat "$EQ/cli-pass.in.rc"))"
  fi
  if eq_same cli-refuse && [ "$(cat "$EQ/cli-refuse.cli.rc")" = 2 ] && [ -s "$EQ/cli-refuse.cli.err" ]; then
    ok "cli-refuse: the command line gives the in-process answer on a usage refusal (rc 2, $(head -1 "$EQ/cli-refuse.cli.err" | cut -c1-60))"
  else
    bad "cli-refuse: the command line and the in-process run differ on a usage refusal (cli rc $(cat "$EQ/cli-refuse.cli.rc"), in rc $(cat "$EQ/cli-refuse.in.rc"))"
  fi
  if eq_same cli-error && [ "$(cat "$EQ/cli-error.cli.rc")" = 1 ] && [ -s "$EQ/cli-error.cli.err" ]; then
    ok "cli-error: the command line gives the in-process answer on a missing argument (rc 1, $(head -1 "$EQ/cli-error.cli.err" | sed 's/^.*: line [0-9]*: //' | cut -c1-40))"
  else
    bad "cli-error: the command line and the in-process run differ on a missing argument (cli rc $(cat "$EQ/cli-error.cli.rc"), in rc $(cat "$EQ/cli-error.in.rc")) err: [$(cat "$EQ/cli-error.cli.err")] vs [$(cat "$EQ/cli-error.in.err")]"
  fi
  if [ "$(cat "$EQ/cli-pass.cli.rc")$(cat "$EQ/cli-refuse.cli.rc")$(cat "$EQ/cli-error.cli.rc")" = 021 ] \
     && ! cmp -s "$EQ/cli-pass.cli.out" "$EQ/cli-refuse.cli.err" && ! cmp -s "$EQ/cli-refuse.cli.err" "$EQ/cli-error.cli.err"; then
    ok "  the three command-line outcomes are distinct (rc 0, 2 and 1, three different outputs)"
  else
    bad "  cli-pass, cli-refuse and cli-error are not three distinct outcomes, so the equivalence above compares one outcome with itself"
  fi
else
  bad "setup: could not build the cli cells' consumer copy"
fi

# --- Assertions 7/8: THE MARKER'S READER ACTUALLY REFUSES ---------------------
# A marker nothing refuses on is a file, not a guard -- and it would have looked identical
# in the report. Drive the real pre-push in a throwaway tree, both directions: the message
# must appear and the hook must exit non-zero with the marker, and the suite must run
# normally without it. The paired control is what makes assertion 7 mean anything, because
# every other step in that minimal tree fails too.
if ! grep -q 'ai-dlc-applying' "$PREPUSH" 2>/dev/null; then
  skip "pre-push mid-pull refusal" "the resolved pre-push ($PREPUSH) predates the in-flight marker; it lands with this same pull"
else
echo "HERMETIC-CONSUMED $PREPUSH"
PP="$WORK/pptree"
mkdir -p "$PP/.claude" "$PP/tests/fixtures/x" || exit 2
printf '#!/usr/bin/env bash\nexit 0\n' > "$PP/tests/fixtures/x/run.sh"
: > "$PP/.claude/.ai-dlc-applying"
pp_out="$(cd "$PP" && FXCELL=e2e-marker-refuses AI_DLC_READSET_LIVE_TRACE=0 bash "$PREPUSH" </dev/null 2>&1)"; pp_rc=$?
if grep -q 'ai-dlc-applying' <<<"$pp_out" && [ "$pp_rc" -ne 0 ]; then
  ok "pre-push REFUSES the fixture suite while the marker exists, and names the file"
else
  bad "pre-push ran the suite on a mid-pull tree (rc=$pp_rc) — the marker is written but nothing reads it"
fi
rm -f "$PP/.claude/.ai-dlc-applying"
pp_out2="$(cd "$PP" && FXCELL=e2e-marker-absent AI_DLC_READSET_LIVE_TRACE=0 bash "$PREPUSH" </dev/null 2>&1)"
if ! grep -q 'ai-dlc-applying' <<<"$pp_out2"; then
  ok "  control: with no marker the suite runs normally (the guard is not always-on)"
else
  bad "  the guard fires with no marker present — it would block every push forever"
fi
fi

# --- Assertions 9/10: THE SETUP-SITED SET apply.sh LOADS IS STATUS-CHECKED (BL-418) -----------
# apply.sh loads preclassify's `setup_sited_paths()` twice: for the in-flight marker's CLASSIFY
# hashes, and for `--finish`'s setup-sited NOTE rows. Both used to eval an assignment whose awk
# status nothing read, so an unreadable manifest was an EMPTY set and the run went on: the marker
# was written with no sited exclusion, and `--finish` advanced the stamp having verified nothing.
# Forced with an `awk` stub failing the Nth call whose program carries the sited grammar. In both
# modes call 1 is preclassify's own read and call 2 is apply.sh's, so N=2 is the cell; the stub
# logs every call, so a cell whose stub never reached call 2 reads as broken, not as a pass.
if ! grep -q '^setup_sited_paths() {' "$(dirname "$APPLY")/preclassify.sh" 2>/dev/null; then
  skip "setup-sited set status" "the installed preclassify.sh predates setup_sited_paths(); it lands with this same pull"
else
SS="$WORK/sited"; SSD="$SS/dist"; SSC="$SS/cons"
mkdir -p "$SSD/core/session-driver" "$SSD/core/scripts" "$SSC/.claude/session-driver" "$SSC/scripts/ai-dlc" "$SS/sh" || exit 2
ssg() { git -C "$SSD" -c user.email=f@f -c user.name=fixture -c commit.gpgsign=false "$@"; }
git -C "$SSD" init -q
printf '1.0.0\n' > "$SSD/VERSION"
printf '#!/usr/bin/env bash\n# driver v1\n' > "$SSD/core/session-driver/ai-dlc-session-driver.sh"
printf '#!/usr/bin/env bash\necho v\n' > "$SSD/core/scripts/validate-synthetic.sh"
ssg add -A && ssg commit -qm base; SS_B="$(git -C "$SSD" rev-parse HEAD)"
printf '2.0.0\n' > "$SSD/VERSION"
printf '#!/usr/bin/env bash\n# driver v2 UPSTREAM\n' > "$SSD/core/session-driver/ai-dlc-session-driver.sh"
ssg add -A && ssg commit -qm theirs; SS_T="$(git -C "$SSD" rev-parse HEAD)"
printf '#!/usr/bin/env bash\n# driver v1\n' > "$SSC/.claude/session-driver/ai-dlc-session-driver.sh"
printf '#!/usr/bin/env bash\necho v\n' > "$SSC/scripts/ai-dlc/validate-synthetic.sh"
printf 'version: 1.0.0\ncommit: %s\n' "$SS_B" > "$SSC/.claude/.ai-dlc-version"
# EACH CALL IS IDENTIFIED BY ITS CALLER'S ARGV, NOT ONLY COUNTED. The stub logs one class per call,
# read off the parent process's command line: `pc` preclassify.sh without `--templates` (phase 0's
# core run), `pct` preclassify.sh WITH `--templates` (template_scan's fork), `ap` apply.sh itself,
# `?` anything else. A count alone cannot tell the templates fork from an unrelated new preclassify
# call; the sequence can, so the cells below compare it.
cat > "$SS/sh/awk" <<SH
#!/bin/bash
case "\$*" in *'file:[ \\t]*core'*)
  n=\$(( \$(wc -l < "$SS/sh/LOG") + 1 ))
  pa="\$(ps -o args= -p "\$PPID" 2>/dev/null)"
  case "\$pa" in
    *preclassify.sh*--templates*) k=pct ;;
    *preclassify.sh*) k=pc ;;
    *apply.sh*|*apply-restamp-theirs/run.sh*) k=ap ;;
    *) k='?' ;;
  esac
  printf '%s %s\n' "\$n" "\$k" >> "$SS/sh/LOG"
  [ "\$n" = 2 ] && exit 2 ;;
esac
exec "$(command -v awk)" "\$@"
SH
chmod +x "$SS/sh/awk"
ss_seq() { awk '{print $2}' "$SS/sh/LOG" | paste -sd, -; }
ss_apply() { # ss_apply -> "calls=<n> seq=<classes> unwritten=<n> stamp=<v>" for an ordinary apply, call 2 failed
  local c="$SS/c.$RANDOM" o
  cp -R "$SSC" "$c"; : > "$SS/sh/LOG"
  o="$(PATH="$SS/sh:$PATH" AP_S="$APPLY" ap_eng "$SSD" "$SS_B" "$c" "$SS_T" 2>&1)"
  printf 'calls=%s seq=%s unwritten=%s stamp=%s' "$(grep -c . "$SS/sh/LOG")" "$(ss_seq)" \
    "$(printf '%s\n' "$o" | awk -F'\t' '$1=="DECISION" && $2=="applying-marker-unwritten" && index($4,"setup_sited_paths")' | grep -c .)" \
    "$(sed -n 's/^version: //p' "$c/.claude/.ai-dlc-version")"
}
ss_finish() { # ss_finish -> "calls=<n> unverified=<n> stamp=<v>" for --finish over a tree AT theirs
  local c="$SS/f.$RANDOM" o
  cp -R "$SSC" "$c"; : > "$SS/sh/LOG"
  git -C "$SSD" show "$SS_T:core/session-driver/ai-dlc-session-driver.sh" > "$c/.claude/session-driver/ai-dlc-session-driver.sh"
  printf 'base: %s\ntheirs: %s\n' "$SS_B" "$SS_T" > "$c/.claude/.ai-dlc-applying"
  o="$(PATH="$SS/sh:$PATH" AP_S="$APPLY" ap_eng --finish "$SSD" "$SS_B" "$c" "$SS_T" 2>&1)"
  printf 'calls=%s seq=%s unverified=%s stamp=%s' "$(grep -c . "$SS/sh/LOG")" "$(ss_seq)" \
    "$(printf '%s\n' "$o" | awk -F'\t' '$1=="WORKLIST" && $2=="finish-unverified-tree" && index($4,"setup_sited_paths")' | grep -c .)" \
    "$(sed -n 's/^version: //p' "$c/.claude/.ai-dlc-version")"
}
WANT_SS_APPLY="calls=2 seq=pc,ap unwritten=1 stamp=1.0.0"
WANT_SS_FINISH="calls=2 seq=pc,ap unverified=1 stamp=1.0.0"
r="$(ss_apply)"
if [ "$r" = "$WANT_SS_APPLY" ]; then
  ok "a sited set apply.sh cannot load withholds the in-flight marker and the stamp ($r)"
else
  bad "a failed sited-set load in the marker was read as an empty set: got [$r], want [$WANT_SS_APPLY]"
fi
r="$(ss_finish)"
if [ "$r" = "$WANT_SS_FINISH" ]; then
  ok "--finish over a tree at theirs withholds the stamp when its sited set cannot be loaded ($r)"
else
  bad "--finish advanced or verified nothing with no sited set: got [$r], want [$WANT_SS_FINISH]"
fi
# The pre-R1 extractor drive.
OLD_RANGE='/^SETUP_SITED_PATHS=/,/sort -u\)"$/'
ss_old_extract() { # ss_old_extract <reconcile-dir> -> "rc=<n> after=<0|1> lines=<n> match=<0|1>"
  local want
  # The sited set derived here, from the manifest beside the subject, by this file's own grammar.
  want="$(awk '/^[ \t]*file:[ \t]*core\//{sub(/^[ \t]*file:[ \t]*/,""); print}' "$1/setup-sites.md" 2>/dev/null | sort -u)"
  OLD_RANGE="$OLD_RANGE" SELF="$1" WANT="$want" bash -c '
    set -uo pipefail
    SETUP_SITED_PATHS=""
    eval "$(awk "$OLD_RANGE" "$SELF/preclassify.sh" 2>/dev/null)"; rc=$?
    printf "rc=%s after=1 lines=%s match=%s" "$rc" "$(printf "%s\n" "$SETUP_SITED_PATHS" | grep -c .)" \
      "$([ -n "$WANT" ] && [ "$SETUP_SITED_PATHS" = "$WANT" ] && echo 1 || echo 0)"' "$1/apply.sh" 2>/dev/null \
    || printf ' aborted'
}

# --- Assertions 11/12: A MIXED PULL, IN BOTH DIRECTIONS ------------------------------------------
# A consumer runs its OWN installed engine, so one pull can pair an apply.sh and a preclassify.sh
# from different releases. OLD apply.sh + NEW preclassify.sh: the old engine loads the sited set with
# the literal range below and evals it under its own `set -u`; without a one-line assignment that
# closes that range, the range ran to EOF, evaluated preclassify's top level and aborted the apply on
# an unbound variable. The cell evals exactly that range in a foreign shell carrying none of
# preclassify's variables, and demands rc 0, a statement AFTER the eval, and the real sited set.
r="$(ss_old_extract "$(dirname "$APPLY")")"
case "$r" in
  "rc=0 after=1 lines="*" match=1") case "$r" in *"lines=0 "*) bad "the pre-R1 apply.sh extractor read an EMPTY sited set from this preclassify.sh ($r)" ;;
                                      *) ok "a pre-R1 apply.sh extractor evals this preclassify.sh's range cleanly and reads the real sited set ($r)" ;; esac ;;
  *) bad "a pre-R1 apply.sh extractor against this preclassify.sh did not close its range cleanly: [$r] -- a mixed pull aborts the apply" ;;
esac
# NEW apply.sh + OLD preclassify.sh: no `setup_sited_paths()` to load. Failing closed is right; the
# remedy must name the version skew, not "present and readable". The old preclassify is synthesised
# from this one: the function deleted and the status-checked block deleted, leaving the shim line --
# which is exactly the assignment a pre-R1 preclassify.sh carried.
OLDPD="$SS/old-pre"; mkdir -p "$OLDPD" && cp "$(dirname "$APPLY")"/* "$OLDPD/" 2>/dev/null
awk '/^setup_sited_paths\(\) \{/ {s=1} s && /^\}/ {s=0; next} s {next}
     /^if _pc_ssp="\$\(setup_sited_paths\)"; then$/ {f=1} f && /^fi$/ {f=0; next} f {next} {print}' \
  "$(dirname "$APPLY")/preclassify.sh" > "$OLDPD/preclassify.sh"
old_live="$(grep -v '^[[:space:]]*#' "$OLDPD/preclassify.sh" | grep -c 'setup_sited_paths\|_pc_ssp')" || old_live=0
if [ "$old_live" -ne 0 ] \
   || ! grep -q '^SETUP_SITED_PATHS="\$(awk ' "$OLDPD/preclassify.sh" \
   || ! bash -n "$OLDPD/preclassify.sh" 2>/dev/null; then
  bad "FIXTURE BROKEN: could not synthesise a pre-R1 preclassify.sh (function or block anchors moved)"
else
  c="$SS/skew.$RANDOM"; cp -R "$SSC" "$c"
  o="$(AP_S="$OLDPD/apply.sh" ap_eng "$SSD" "$SS_B" "$c" "$SS_T" 2>&1)"
  r="$(printf '%s\n' "$o" | awk -F'\t' '$1=="DECISION" && $2=="applying-marker-unwritten" && index($4,"(exit 127)") && index($4,"predates") && index($4,"version skew") && !index($4,"present and readable")' | grep -c .)"
  [ "$r" = 1 ] && ok "a newer apply.sh beside a pre-R1 preclassify.sh fails closed and names the version skew, not an unreadable file" \
    || bad "a newer apply.sh beside a pre-R1 preclassify.sh did not name the version skew: $(printf '%s\n' "$o" | awk -F'\t' '$2=="applying-marker-unwritten" {print $4}' | cut -c1-200)"
  c="$SS/skewf.$RANDOM"; cp -R "$SSC" "$c"
  git -C "$SSD" show "$SS_T:core/session-driver/ai-dlc-session-driver.sh" > "$c/.claude/session-driver/ai-dlc-session-driver.sh"
  printf 'base: %s\ntheirs: %s\n' "$SS_B" "$SS_T" > "$c/.claude/.ai-dlc-applying"
  o="$(AP_S="$OLDPD/apply.sh" ap_eng --finish "$SSD" "$SS_B" "$c" "$SS_T" 2>&1)"
  r="$(printf '%s\n' "$o" | awk -F'\t' '$1=="WORKLIST" && $2=="finish-unverified-tree" && index($4,"(exit 127)") && index($4,"version skew") && !index($4,"present and readable")' | grep -c .)"
  [ "$r" = 1 ] && ok "--finish with a pre-R1 preclassify.sh withholds the stamp and names the version skew" \
    || bad "--finish with a pre-R1 preclassify.sh did not name the version skew: $(printf '%s\n' "$o" | awk -F'\t' '$2=="finish-unverified-tree" {print $4}' | cut -c1-200)"
fi
fi

# --- BL-886: TEMPLATE-DERIVED FILES ARE HANDED BACK, RECORDED, AND RE-CHECKED BY --finish ---------
# receipt-bl886.sh beside this file owns the worlds and the cells (its header lists them): the prose
# claim (pa..pg, pe), the json claim (ja..jd, jn), one row per remedy (c3a..c3c) and every
# settings-merge fill on a range that leaves the template alone (ea, eb, er, ez, ex, em, ek, en), each read off the
# STAMP and the MARKER, never off a row name alone. The shipped reconcile directory must answer every
# cell.
if [ -f "$HERE/receipt-bl886.sh" ]; then
  TP_REC="$(dirname "$APPLY")"
  # The run fills TP_WC with the distribution and the four consumer worlds.
  TP_WC="$WORK/bl886-worlds"
  tp_out="$(bash "$HERE/receipt-bl886.sh" "$TP_REC" "" "$TP_WC" 2>&1)"; tp_rc=$?
  if [ "$tp_rc" -eq 0 ]; then
    ok "BL-886: a changed prose template hands its file back (stamp at base, template: line recorded), --finish withholds while it is untouched and stamps once it changes or its line is deleted, a same-base re-run keeps the pre-merge record, an older engine's marker stamps with a NOTE, a --templates refusal withholds; a settings.json the merge would change is handed back and recorded, --finish re-tests it by merging a copy (an edit that is not the merge still withholds) and stamps after the merge or the line's deletion, one the merge would not change is neither handed back nor recorded; the settings-merge hook row stands down while the json row owns the remedy and returns when its line is deleted; on a range that leaves the template alone a settings.json still enabling context-mode at project scope is handed back and stamps once merged, one whose role lacks a template-owned key is handed back with the fill named in the row, a merge the engine cannot run there (script absent or failing) withholds, a file the merge refuses (not an object, a wrong-typed key) raises nothing, and one the merge would not change (that id false beside another plugin) is not"
  else
    bad "BL-886: receipt-bl886.sh exited $tp_rc on the shipped reconcile directory: $(printf '%s\n' "$tp_out" | head -12 | tr '\n' ' ')"
  fi
elif [ "$IS_DIST" = 1 ]; then
  bad "BL-886: receipt-bl886.sh is not beside this fixture in the distribution"
fi

echo
report_end apply-restamp-theirs
