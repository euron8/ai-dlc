#!/usr/bin/env bash
# consumer-machinery-home — assert I43 and I44 cannot go quiet.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THESE EXIST TO CATCH. `scripts/ai-dlc-local/` — the directory the core-guard
# tells an author to put their own pipeline tooling in when it refuses a write under
# `scripts/ai-dlc/` — was written out by hand in FIVE shipped surfaces and declared as
# data in none: the guard's deny reason and its additionalContext, the LOCAL_DIR default
# in reconcile/warn-shadowed-local-validators.sh, two fixtures, and core-manifest.md's
# prose. Nothing compared them.
#
# That is the affordance-is-the-defect shape. The guard PROMISES the home; the promise was
# the only thing holding the value. Rename it in one surface and the guard keeps routing
# authors to a directory the reader never walks — and BOTH halves stay green, because each
# is internally consistent with itself. core-manifest.md and the guard also both promise,
# in those words, that core "never reads, never writes and never overwrites" the home, and
# nothing asserted that either; a manifest entry landing under it would make the promise
# false while every reader of the prose still believed it.
#
# So the assertions below are about the CHECKS, not about today's path. That the tree
# spells the home consistently right now proves nothing. What must hold is that a rename
# in one surface, a guard that stops routing there, a divergence between the two
# declarations, a missing declaration, and an installer target under the home each FAIL.
#
# WHY A POOL AT ALL: the suite's critical path. Seven runs of a ~8.5s validator, end to end,
# cost 58s standalone and ~190s inside the 16-way pre-push suite, and that suite is
# POLE-BOUND — its makespan tracks its single longest unit (measured 268s against a 268s wall
# clock). An internally-serial fixture therefore sets the wall clock for the whole push no
# matter what AI_DLC_FIXTURE_JOBS is set to.
#
# THE ALIEN TOKENS ARE ASSEMBLED, NOT WRITTEN. This file lives under core/fixtures/, which
# is inside I43's own forward scan, and that scan rejects any home spelling other than the
# two real ones. An edit that wrote its alien path as a literal would therefore make I43
# fire on THIS FILE against the PRISTINE tree, and assertion 0 would report the fixture
# broken — which is exactly what happened twice while this was being written, once for the
# seds and once for a comment describing them. The seds below build their alien paths by
# concatenating core's own prefix at runtime, so no extra spelling exists on disk, and this
# comment describes the shape rather than reproducing it.
set -uo pipefail

# This fixture names a hook by path (it edits the guard's deny TEXT in a copy; it never drives the
# hook). Scrub anyway — a fixture that touches hook files costs nothing to make hermetic,
# and I10's keyword scan is deliberately wider than "actually executes one".
#
# Ordered before HERE= and before the pool: the worker wrapper resolves its own variables in
# its `bash -c` ahead of anything it invokes, so unsetting them here cannot reach values that
# have already been resolved.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }

# Built from a prefix that IS core's own home, so neither literal appears in this file.
_CORE_HOME='scripts/ai-dlc'
ALIEN_RENAME="${_CORE_HOME}-elsewhere"

# Distribution-only. `validate-enforcement-map.sh` is not shipped by install.sh (it checks
# the distribution's own writers against each other — a consumer has neither), so in a
# consumer tree there is nothing to test. Say so and stop; do not fake a pass.
if [ ! -f "$HERE/../../../scripts/validate-enforcement-map.sh" ]; then
  echo "consumer-machinery-home: SKIP — distribution-only (validate-enforcement-map.sh is not shipped to consumers)"
  fx_skip_exit "$HERE"
fi

echo "HERMETIC-CONSUMED scripts/validate-enforcement-map.sh"

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
# fx_inproc (one row per in-process vem_entry pass, BL-982) comes from lib/mutant.sh, exported because every
# pass runs in an xargs bash -c worker below.
[ -f "$HERE/../lib/mutant.sh" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/../lib/mutant.sh"
export -f fx_inproc
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

# The five surfaces, as paths RELATIVE to a seeded root — each worker seeds its own,
# so an absolute path resolved here would point every worker at one tree and put back exactly
# the sharing this file now exists without.
MANIFEST_REL='core/skills/ai-dlc/core-manifest.md'
SITES_REL='core/skills/ai-dlc-update/reconcile/setup-sites.md'
GUARD_REL='core/hooks/ai-dlc-core-guard.sh'
WARN_REL='core/skills/ai-dlc-update/reconcile/warn-shadowed-local-validators.sh'
INSTALL_REL='scripts/install.sh'

RUNS="$WORK/runs"; : > "$RUNS"
SEDS="$WORK/seds"; mkdir -p "$SEDS"
OUTD="$WORK/out";  mkdir -p "$OUTD"

# reg <kind> <label> <relative-file> <sed program> <expected substring>
#
# The sed program goes to a FILE rather than into the registry. These programs carry `#`
# delimiters, `$` anchors and the assembled alien paths, and one that arrived at the worker
# subtly re-quoted would still apply, still satisfy `cmp -s`, and prove something other than
# what its call site says.
#
# PHASE 1 IS REGISTRATION ONLY. The arms below, and their reasoning, are in declaration order
# and the report is rendered in that same order — which is what keeps this fixture's stdout
# byte-comparable against the serial version it replaces.
reg() {
  printf '%s' "$4" > "$SEDS/$2.sed"
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$5" >> "$RUNS"
}

echo "consumer-machinery-home:"

# --- Assertion 0: SANITY ------------------------------------------------------
# The pristine tree must PASS. If it does not, the validator is erroring for a reason of
# its own and every "it failed as expected" below is a false pass.
reg sanity a0-sanity '' '' ''

# --- Assertion 1: I43 forward — a rename in ONE surface ------------------------
# THE headline defect: the READER drifts from the ROUTER. The guard still sends authors to
# the declared home and both declarations still agree, so every other arm is clean; only
# `warn-shadowed-local-validators.sh` now walks somewhere else, and it walks it silently
# because an absent directory is its documented no-op. Before I43 nothing compared them.
#
# The READER, not the guard, deliberately. Renaming the home in the GUARD fires two arms at
# once — it introduces an alien spelling AND stops the guard naming the declared home — so
# it cannot isolate either. Measured: 2 FAIL lines. This edit fires exactly one.
reg world a1-reader-rename "$WARN_REL" "s#${_CORE_HOME}-local#${ALIEN_RENAME}#g" \
    "is neither core's own"

# ==================== PHASE 2: seed, edit and validate, in a pool ====================
# The zero guard: a registration grammar that stopped filling yields an empty list, and an
# empty list passes every assertion it never made.
N_RUNS="$(grep -c . "$RUNS" || true)"
if [ "$N_RUNS" -lt 2 ]; then
  echo "FIXTURE ERROR: registered only $N_RUNS run(s) — the registry did not fill, so nothing below is evidence" >&2
  exit 2
fi

# Fixed rather than tunable for the reason the sibling pools state in place: this
# pool nests inside the pre-push suite's own, so a knob here multiplies against the knob
# there and the PRODUCT is what lands on the machine. A wider pool than there is work
# is pure contention for the sibling fixtures.
# READSET_POOL_WIDTH narrows this pool when derive-fixture-readsets.sh traces the fixture (its nest launch sets 1):
# at full width the sweeps outrun `log stream` and the trace is discarded. It changes the schedule, not the work.
CMH_JOBS="${READSET_POOL_WIDTH:-6}"
case "$CMH_JOBS" in ''|*[!0-9]*|????*) echo "FIXTURE BROKEN: READSET_POOL_WIDTH='$CMH_JOBS' is not an integer from 1 to 64" >&2; exit 2 ;; esac
{ [ "$CMH_JOBS" -ge 1 ] && [ "$CMH_JOBS" -le 64 ]; } || { echo "FIXTURE BROKEN: READSET_POOL_WIDTH='$CMH_JOBS' is not an integer from 1 to 64" >&2; exit 2; }
CMH_HERE="$HERE" CMH_SEDS="$SEDS" CMH_OUT="$OUTD" CMH_RUNS="$RUNS" \
  xargs -P "$CMH_JOBS" -I{} bash -c '
    l="$1"
    f="$(awk -F"\t" -v k="$l" "\$2==k{print \$3}" "$CMH_RUNS")"
    root="$(bash "$CMH_HERE/seed.sh")" || { printf SEEDFAIL > "$CMH_OUT/$l.state"; printf done > "$CMH_OUT/$l.done"; exit 0; }
    if [ -n "$f" ]; then
      sed -f "$CMH_SEDS/$l.sed" "$root/$f" > "$root/$f.mut" 2>/dev/null
      if cmp -s "$root/$f" "$root/$f.mut"; then
        printf VACUOUS > "$CMH_OUT/$l.state"
        printf done    > "$CMH_OUT/$l.done"
        rm -rf "$root"; exit 0
      fi
      mv "$root/$f.mut" "$root/$f"
    fi
    _arms="--arms I43,I44"
    # IN-PROCESS: the seeded validator is sourced ONCE by absolute path and run as a vem_entry subshell.
    # The two cli cells (cells.decl) start it as a program on the pristine tree (a pass) and on
    # a1-reader-rename (a refusal) and must answer byte for byte as the in-process run did.
    . "$root/scripts/validate-enforcement-map.sh"
    fx_inproc "$root/scripts/validate-enforcement-map.sh"
    ( vem_entry $_arms ) > "$CMH_OUT/$l.so" 2> "$CMH_OUT/$l.se"
    irc=$?
    printf %s $irc > "$CMH_OUT/$l.rc"
    cat "$CMH_OUT/$l.so" "$CMH_OUT/$l.se" > "$CMH_OUT/$l.out"
    case "$l" in a0-sanity) tag=cli-pass ;; a1-reader-rename) tag=cli-refuse ;; *) tag="" ;; esac
    if [ -n "$tag" ]; then
      FXCELL="$tag" bash "$root/scripts/validate-enforcement-map.sh" $_arms > "$CMH_OUT/$l.cso" 2> "$CMH_OUT/$l.cse"
      crc=$?
      if cmp -s "$CMH_OUT/$l.so" "$CMH_OUT/$l.cso" && cmp -s "$CMH_OUT/$l.se" "$CMH_OUT/$l.cse" && [ "$irc" = "$crc" ]; then
        printf same > "$CMH_OUT/$l.twin"
      else
        printf "DIFF rc=%s/%s" "$irc" "$crc" > "$CMH_OUT/$l.twin"
      fi
    fi
    printf done  > "$CMH_OUT/$l.done"
    rm -rf "$root"
  ' _ {} < <(cut -f2 "$RUNS")

# ================= PHASE 3: evaluate, serially, in DECLARATION order =================
while IFS=$'\t' read -r kind label file want; do
  [ -n "$label" ] || continue

  # A MISSING VERDICT IS A FAILURE, not a gap. `.done` is written after the run, so its
  # absence means the pool dropped the job — which otherwise contributes exactly what a
  # passing assertion contributes: nothing.
  if [ ! -f "$OUTD/$label.done" ]; then
    bad "$label produced no verdict — the pool dropped work, and a short green run reads exactly like a passing one"
    continue
  fi

  if [ -f "$OUTD/$label.state" ]; then
    case "$(cat "$OUTD/$label.state")" in
      SEEDFAIL)
        echo "FIXTURE ERROR: seed failed for $label" >&2
        echo; echo "consumer-machinery-home: $((fails + 1)) assertion(s) FAILED" >&2; exit 2 ;;
      VACUOUS)
        bad "SEED EDIT VACUOUS — the sed program matched nothing in ${file##*/}, so the tree is unchanged and the refusal below would be asserted on a clean tree" ;;
    esac
    continue
  fi

  out="$(cat "$OUTD/$label.out" 2>/dev/null)"
  rc="$(cat "$OUTD/$label.rc" 2>/dev/null)"

  case "$kind" in
    sanity)
      if [ "$rc" = "0" ]; then
        ok "pristine distribution tree passes (the negatives below mean something) — also the control: the harness itself is not what failed"
      else
        bad "FIXTURE BROKEN — the pristine tree does not pass validate-enforcement-map.sh. Every assertion below would be a false pass."
        echo; echo "consumer-machinery-home: $fails assertion(s) FAILED" >&2; exit 2
      fi ;;
  esac
done < "$RUNS"

# THE CLI TWINS (cells.decl): the program answers the pristine tree (a pass, exit 0) and a1-reader-rename
# (a refusal, exit 1 with I43 text) exactly as the in-process entry did, on stdout, stderr and exit. An
# absent twin file reads as a failure, never as agreement.
_cp_rc="$(cat "$OUTD/a0-sanity.rc" 2>/dev/null)"
_cr_rc="$(cat "$OUTD/a1-reader-rename.rc" 2>/dev/null)"
if [ "$(cat "$OUTD/a0-sanity.twin" 2>/dev/null)" = same ] && [ "$_cp_rc" = 0 ] && grep -q '^OK: ' "$OUTD/a0-sanity.cso" 2>/dev/null; then
  ok "cli-pass: the program answers the pristine tree exactly as the in-process entry does (stdout, stderr, exit 0)"
else
  bad "cli-pass: the program differs from the in-process entry on the pristine tree ($(cat "$OUTD/a0-sanity.twin" 2>/dev/null))"
fi
if [ "$(cat "$OUTD/a1-reader-rename.twin" 2>/dev/null)" = same ] && [ "$_cr_rc" = 1 ] && grep -qF "is neither core" <<<"$(cat "$OUTD/a1-reader-rename.cso" "$OUTD/a1-reader-rename.cse" 2>/dev/null)"; then
  ok "cli-refuse: the program refuses a1-reader-rename exactly as the in-process entry does (stdout, stderr, exit 1)"
else
  bad "cli-refuse: the program differs from the in-process entry on a1-reader-rename ($(cat "$OUTD/a1-reader-rename.twin" 2>/dev/null))"
fi

echo
report_end consumer-machinery-home
