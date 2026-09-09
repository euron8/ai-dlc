#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# self-update-fixture-log — assert step 2's fixture run leaves evidence behind, and that its
# COVERAGE join refuses a slice that omits a fixture the pull itself changes.
#
# THE LOAD-BEARING ASSERTION IS PART 3: the failing fixture's own output must still be
# readable AFTER the tree it ran in has been deleted. That is the whole defect this runner
# closes — step 2 discards the branch and restores the tree on red, so a run whose output
# lived only in the operating agent's context left the next operator with "the self-update
# failed" and nothing else. It happened twice on the reference consumer.
#
# Parts 4 and 5 are the other half, and they are not decoration: a runner that exits 0 when
# it ran nothing turns an empty set into a green suite, which is the failure mode this repo
# names "a zero is not a finding". A green run and a run that never happened must not be the
# same exit code.
#
# PARTS 7-12 COVER THE `base..theirs` COVERAGE JOIN, and they are why this fixture now builds
# a THROWAWAY DISTRIBUTION REPO. The join resolves both refs and derives the diff, so the
# literal `base-sha` / `theirs-ref` strings this fixture used to pass now stop every run at
# the unresolvable arm before it asserts anything about the log. The repo is shaped so ONE
# range carries all four coverage cases at once — an offender, a NAMED near-miss, a
# `.dist-only` exemption and a deleted-upstream exemption — because a near-miss standing in a
# SEPARATE run only asks whether the arm fires, never whether it fires on the right directory.
#
# TWO GUARDS SIT ON THE SAME PATH AND ONE COVERS THE OTHER, so the seeds are chosen to split
# them. A bogus ref is refused by the ref-resolution loop AND, with that loop removed, by the
# diff-failure arm below it — same exit code either way. The input only the FIRST can see is
# a sha that names a TREE: it cannot be peeled to a commit, and `git diff <tree> <commit>`
# succeeds, so with the ref loop neutered the join runs against a base that never resolved
# and reports green. Part 12 is that input, and it is what the ref-loop mutant dies on.
#
# Usage: run.sh [path-to-self-update-fixtures.sh]
# Exit:  0 = every assertion holds, 1 = something regressed, 2 = the harness could not run.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
RUNNER="$(pick "${1:-}" "$HERE/../../../core/skills/ai-dlc-update/reconcile/self-update-fixtures.sh" \
                        "$HERE/../../skills/ai-dlc-update/reconcile/self-update-fixtures.sh" \
                        "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/self-update-fixtures.sh")"
[ -n "$RUNNER" ] || { echo "FIXTURE ERROR: cannot locate self-update-fixtures.sh" >&2; exit 2; }
RECONCILE="$(cd "$(dirname "$RUNNER")" && pwd)"

CONS="$(bash "$HERE/seed.sh")"
CONS2="$(bash "$HERE/seed.sh")"
DIST="$(mktemp -d)"
WREPO="$(mktemp -d)"
trap 'rm -rf "$CONS" "$CONS2" "$DIST" "$WREPO"' EXIT
LOGDIR="$CONS/_bmad-output/ai-dlc-update"
LOGDIR2="$CONS2/_bmad-output/ai-dlc-update"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

newest_log()  { ls -t "$LOGDIR"/self-update-fixtures-*.md 2>/dev/null | head -1; }
newest_log2() { ls -t "$LOGDIR2"/self-update-fixtures-*.md 2>/dev/null | head -1; }

# --- The GATE RECORD, and the FALSE-POSITIVE SET this fixture had to be narrowed against ----
# The runner now refuses to run any fixture without a recorded `# verdict: OK` from
# `self-update-gate.sh` for its own resolved range. EVERY PART BELOW WAS A FALSE POSITIVE OF
# THAT ARM ON ITS FIRST RUN — parts 1 to 20 drive the runner directly and none of them had ever
# invoked the gate, so all of them exited 2 with a GATE-RECORD line. That is the whole
# false-positive set, it is enumerated (it is every part that drives the runner), and the
# narrowing is `seed_record` below: each part seeds the OK record its own range needs, exactly
# as step 2's real cycle produces one by running the gate first.
#
# THE SEEDED RECORD IS FORGED, DELIBERATELY, FOR THE PARTS THAT TEST THE RUNNER'S READ SIDE.
# What those parts assert is what the runner DOES with a record, and a forged file exercises
# that completely while costing no gate invocation. What a forged file cannot establish is that
# the SHIPPING gate writes a record this reader accepts — two programs agreeing because one
# author wrote both sides of the grammar is the drift this repo keeps paying for — so Part G4
# drives the real `self-update-gate.sh` and reads its output with the same parser, and it is the
# only part here that may not use `seed_record`.
#
# The shas are RESOLVED, not the argument strings: the runner peels its own refs and compares
# commit to commit, so a record forged with the literal `theirs-tag` would be refused. That is
# Mutant G2's subject from the other side.
# The consumer-relative file every default-seeded record names as an input, written into each
# consumer tree below. It sits OUTSIDE `tests/`, and that is load-bearing rather than tidy: Part
# 3 performs the branch discard as `rm -rf "$CONS/tests"`, so a probe under there vanishes
# mid-run and every later part reads INPUT-MOVED — a refusal that belongs to the seed and reads
# as a defect in whatever arm happens to be next. Measured; it took Part 5 red.
SR_PROBE_REL="_bmad-output/.gate-input-probe"

# The sentinel for "this record names NO inputs at all". An empty `$SR_INPUTS` cannot say it —
# an unset variable and one set to the empty string are the same test, so the default block runs
# and the record gets an input line after all. Measured: Part G7 passed for the wrong reason.
SR_NO_INPUTS="@@none@@"

# THE DEFAULT INPUT BLOCK IS THE RUNNER'S DERIVED REQUIRED SET, NOT A LINE OF THIS AUTHOR'S
# CHOOSING. The runner resolves the consumer's `.githooks/pre-push` and demands an input row for
# the hook and for every `scripts/ai-dlc/<name>` it names, so a default record that carried only
# a probe file would be refused by every part below — correctly, and for a reason none of them is
# about. It is spelled from the same two facts the runner reads (the hook path, the scripts it
# names) rather than from a list, so a seed and a reader cannot drift into agreeing about a set
# neither derives.
#
# Three columns: `<consumer path>\t<digest|ABSENT>\t<core path|->`. The core path is what lets the
# reader accept a file the slice moved to `theirs`, and it is the column a forged record cannot
# fake for a path it does not own.
sr_required_inputs() { # $1=consumer root -> the record's input block for a clean pre-write tree
  sr_h="$1/.githooks/pre-push"
  [ -f "$sr_h" ] || return 0
  printf '# input: .githooks/pre-push\t%s\t-\n' "$(git hash-object "$sr_h" 2>/dev/null)"
  for sr_iv in $(grep -oE 'scripts/ai-dlc/[A-Za-z0-9._-]+\.sh' "$sr_h" | sort -u); do
    sr_n="${sr_iv#scripts/ai-dlc/}"
    if [ -f "$1/$sr_iv" ]; then
      printf '# input: %s\t%s\tcore/scripts/%s\n' "$sr_iv" "$(git hash-object "$1/$sr_iv" 2>/dev/null)" "$sr_n"
    else
      printf '# input: %s\tABSENT\tcore/scripts/%s\n' "$sr_iv" "$sr_n"
    fi
  done
}

seed_record() { # $1=log dir $2=dist $3=base-ref $4=theirs-ref [$5=verdict] [$6=name suffix]
  sr_b="$(git -C "$2" rev-parse "${3}^{commit}" 2>/dev/null)"
  sr_t="$(git -C "$2" rev-parse "${4}^{commit}" 2>/dev/null)"
  [ -n "$sr_b" ] && [ -n "$sr_t" ] || { echo "FIXTURE ERROR: seed_record could not peel ${3}/${4}" >&2; return 1; }
  mkdir -p "$1"
  # The name carries the timestamp the gate stamps into it, and the runner orders candidates by
  # NAME — so two records seeded inside one wall-clock second would sort identically and Part G5
  # could not tell the two orderings apart. The disambiguating suffix is therefore an ARGUMENT
  # and not a counter this function increments: a caller that captures the printed path runs this
  # inside `$( )`, where an assignment is lost to the subshell, and the first draft's counter
  # silently produced ONE file for Part G5's two calls — the OK record overwritten by the DEFER,
  # which reads exactly like a correct newest-wins answer.
  sr_f="$1/self-update-gate-$(date -u +%Y%m%dT%H%M%SZ)-${6:-000}.md"
  # THE INPUT LINES ARE PART OF THE MINIMUM VALID RECORD, so the default seed carries them.
  # The gate's verdict is a DIFFERENTIAL against the consumer's own copies, and a record naming
  # no input authorises a question about no tree — which the runner refuses. `$SR_INPUTS`, when
  # the caller sets it, REPLACES this default and is written verbatim; that is how the arms
  # below build a record whose inputs are absent, malformed, or about to be edited.
  { echo "# ai-dlc-update step-2 self-update — gate verdict record"
    echo "# generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# base ${3} -> theirs ${4}"
    echo "# consumer: seeded-by-fixture   dist: ${2}"
    echo "# base-sha: ${sr_b}"
    echo "# theirs-sha: ${sr_t}"
    sr_root="${1%/_bmad-output/ai-dlc-update}"
    if [ "${SR_INPUTS:-}" = "$SR_NO_INPUTS" ]; then
      :
    elif [ -n "${SR_INPUTS:-}" ]; then
      printf '%s\n' "$SR_INPUTS"
    else
      sr_required_inputs "$sr_root"
    fi
    echo ""
    printf 'SELF-UPDATE-OK\t-\tseeded by the fixture: this range changes no gating script.\n'
    echo ""
    echo "# verdict: ${5:-OK}"
    echo "# rows: 1"; } > "$sr_f"
  printf '%s' "$sr_f"
}

# Every range any part below drives, recorded OK once, up front. Seeding per-part would make
# each part's verdict depend on a seeding step written beside it, and a part whose seed silently
# failed would report the runner refusing for the reason the part was testing.
#
# THE SUFFIXES ARE DISTINCT AND THAT IS LOAD-BEARING, NOT TIDY. All four land inside one
# wall-clock second, so a shared suffix makes them ONE FILE: each write clobbers the last, three
# ranges lose their record, and every part driving them exits 2 on a missing approval. Measured —
# it took twenty-six parts red at once, all of them reading as regressions in the arm under test.
seed_ranges() { # $1=log dir
  seed_record "$1" "$DIST" "$D_THEIRS" "$D_QUIET"  OK 010 >/dev/null || return 1
  seed_record "$1" "$DIST" "$D_QUIET"  "$D_SHIP"   OK 011 >/dev/null || return 1
  seed_record "$1" "$DIST" "$D_BASE"   theirs-tag  OK 012 >/dev/null || return 1
  seed_record "$1" "$DIST" "$D_THEIRS" "$D_BASE"   OK 013 >/dev/null || return 1
}

# The refusal list, read back as a SET rather than as N greps. An equality against the whole
# list is what carries the exemptions: a `.dist-only` directory that stopped being exempt
# appears here, and no absence-shaped assertion has to be written for it separately.
cov_set() {
  { [ -n "${1:-}" ] && [ -f "$1" ]; } || return 0
  sed -n '/^COVERAGE: the diff changes/,/^$/p' "$1" \
    | sed -n 's/^  \([A-Za-z0-9._-][A-Za-z0-9._-]*\)$/\1/p' | sort | tr '\n' ','
}

# The OVER-completeness refusal list, read the same way and for the same reason. Its rows carry
# a reason after the directory name, so the name is taken up to the first space; the em dash is
# deliberately not in the pattern, because a multibyte character in a bracket class is three
# separate bytes to a BSD `sed` and the match would depend on the locale the suite happens to
# run under. Set equality here is what carries the ACQUITTALS: a legitimate directory that
# started being refused shows up as an extra member, with no absence-shaped assertion written
# for it separately.
uns_set() {
  { [ -n "${1:-}" ] && [ -f "$1" ]; } || return 0
  sed -n '/^COVERAGE: the named set contains/,/^$/p' "$1" \
    | sed -n 's/^  \([A-Za-z0-9._-][A-Za-z0-9._-]*\) .*$/\1/p' | sort | tr '\n' ','
}

# --- The throwaway DISTRIBUTION repo ------------------------------------------------------
# `--no-verify` and an empty `init.templateDir` because this runs on an operator's machine:
# a global hook path or commit template would otherwise decide whether the seed builds.
G()    { git -C "$DIST" -c user.name=ai-dlc-fixture -c user.email=fixture@invalid \
                        -c commit.gpgsign=false "$@"; }
dput() { mkdir -p "$(dirname "$DIST/$1")" && printf '%s\n' "$2" > "$DIST/$1"; }

git -c init.templateDir= init -q -b main "$DIST" >/dev/null 2>&1 \
  || git -c init.templateDir= init -q "$DIST" >/dev/null 2>&1

for f in touched-shippable touched-named touched-distonly touched-deleted untouched-one; do
  dput "core/fixtures/$f/run.sh" 'at base'
done
dput "core/fixtures/touched-distonly/.dist-only" 'a mutation battery over core sources; never shipped'

# EVERY NAMED DIRECTORY IS READ IN THIS REPO, so every name any part below passes to the
# runner has to exist here. The OVER-completeness arm probes `${THEIRS}:core/fixtures/<d>/...`
# for each argument, so a consumer-side-only name — `green-one`, `red-one`, `cwd-probe`, the
# deliberately-absent `never-written-by-the-slice` — resolves to nothing and is convicted as
# unshippable before the run reaches whatever the part was actually asserting. That is not a
# subject defect: a real step-2 set names directories that exist in `core/fixtures/`.
for f in green-one cwd-probe red-one never-written-by-the-slice \
         disk-only-distonly disk-missing-driver; do
  dput "core/fixtures/$f/run.sh" 'at base'
done

# The OVER-completeness cases, all UNTOUCHED by base..theirs so that naming one exercises the
# over-arm alone and Part 0's diff-side census is unmoved:
#   named-distonly       carries the marker at theirs — the filed episode's shape
#   theirs-only-distonly the marker at theirs and NOT on disk
#   theirs-only-nodriver no run.sh at theirs, and one written to disk below
#   disk-only-distonly   shippable at theirs, with a marker written to disk below
#   disk-missing-driver  shippable at theirs, with its run.sh removed from disk below
dput "core/fixtures/named-distonly/run.sh" 'at base'
dput "core/fixtures/named-distonly/.dist-only" 'a mutation battery over core sources; never shipped'
dput "core/fixtures/theirs-only-distonly/run.sh" 'at base'
dput "core/fixtures/theirs-only-distonly/.dist-only" 'a mutation battery over core sources; never shipped'
dput "core/fixtures/theirs-only-nodriver/.keep" 'a directory upstream carries with no driver in it'

dput "core/scripts/machinery.sh" 'at base'
# THE DISTRIBUTION FALLBACK HOOK, and it is what Part G4 stands on. The seeded consumer has no
# `.githooks/pre-push`, so the shipping gate falls back to `$DIST/core/git-hooks/pre-push`; with
# neither present it emits SELF-UPDATE-UNDECIDED ("no pre-push hook found") and records a
# verdict the runner correctly refuses -- and G4 then fails for a reason that has nothing to do
# with the join it exists to prove. Measured on the first integrated run: the record read
# UNDECIDED, one row naming the missing hook. The hook names the one machinery script so the
# differential arm runs too; the consumer lacks a current copy, which the gate scores OK ("this
# pull ADDS it") and records as an ABSENT input the runner then compares in both directions.
dput "core/git-hooks/pre-push" '#!/usr/bin/env bash
bash scripts/ai-dlc/machinery.sh'

# --- The GATING SCRIPTS the record's DERIVED required set is taken over ----------------------
# `seed.sh` writes a `.githooks/pre-push` naming these two, so the runner's arm 1 resolves the
# CONSUMER's hook and demands an input line for each. They differ in the one property the
# post-write arms turn on: `gate-changed.sh` moves across base..theirs — so the slice rewrites
# it and a verdict can be taken on a tree that already holds it — while `gate-steady.sh` never
# moves and must stay equal to its recorded digest through every legitimate flow. A required set
# with ONE member cannot tell a reader that scanned the set from one that stopped at its first
# entry, which is why there are two.
dput "core/scripts/gate-changed.sh" 'gate-changed at base'
dput "core/scripts/gate-steady.sh" 'gate-steady, never moved'

# --- TWO GATE TEXTS, differing ONLY in whether they carry a record-writing site ---------------
# The tolerance arm asks whether the gate the consumer INSTALLED could have recorded, and reads
# that out of the distribution at BASE. So this base carries a gate that records nothing and the
# next commit carries one that does; every other byte is held equal, or the arm could not say
# which property it read.
#
# THE TOKEN IS `GATE_REC_DIR` ON A NON-COMMENT LINE, and picking it was itself a measurement:
# `self-update-gate-${` scored 0 against BOTH texts — a probe that cannot fire reads exactly like
# one that passed, and it fails in the ACQUITTING direction, so it would have exempted every
# consumer forever. Against the real gate at the two revisions this token scores 0 and 4.
dput "core/skills/ai-dlc-update/reconcile/self-update-gate.sh" '#!/usr/bin/env bash
# the engine a consumer had BEFORE recording: it classifies and persists nothing
emit() { printf "%s\t%s\t%s\n" "$1" "$2" "$3"; }
emit SELF-UPDATE-OK - nothing'
G add -A >/dev/null 2>&1; G commit -q --no-verify -m base >/dev/null 2>&1
D_BASE="$(G rev-parse HEAD 2>/dev/null)"

# The RECORDING gate, on its own commit. Nothing under `core/fixtures/` moves here, so the
# coverage join sees the identical diff from either base and the tolerance arm is the only thing
# that can tell the two apart.
dput "core/skills/ai-dlc-update/reconcile/self-update-gate.sh" '#!/usr/bin/env bash
# the engine that RECORDS. The write site is what the runner probes for.
GATE_REC_DIR="$4/_bmad-output/ai-dlc-update"
mkdir -p "$GATE_REC_DIR"
_rec_p="$GATE_REC_DIR/self-update-gate-$(date -u +%Y%m%dT%H%M%SZ).md"
printf "# verdict: OK\n" > "$_rec_p"'
G add -A >/dev/null 2>&1; G commit -q --no-verify -m base-recording >/dev/null 2>&1
D_BASE_REC="$(G rev-parse HEAD 2>/dev/null)"

# A THIRD BASE: a gate that DECLARES the record directory and never writes. It is the near-miss
# for the probe token, and it is what forced the token off `GATE_REC_DIR` — that spelling names
# an ASSIGNMENT, so this text scores 1 and is read as a recording gate, turning a local edit
# into a refusal whose message says the records were deleted. The composed FILENAME cannot be
# present without the write, so this text scores 0 under it and the recording gate above scores
# 1. Part G22 is the arm; the two texts are one property apart and nothing else separates them.
dput "core/skills/ai-dlc-update/reconcile/self-update-gate.sh" '#!/usr/bin/env bash
# declares the record directory and never writes a record — a locally patched old gate
GATE_REC_DIR="$4/_bmad-output/ai-dlc-update"
emit() { printf "%s\t%s\t%s\n" "$1" "$2" "$3"; }
emit SELF-UPDATE-OK - nothing'
G add -A >/dev/null 2>&1; G commit -q --no-verify -m base-declaring >/dev/null 2>&1
D_BASE_DECL="$(G rev-parse HEAD 2>/dev/null)"

# theirs: three fixtures changed, one deleted, one left alone, and a machinery path moved
# alongside them so the `-- core/fixtures/` pathspec has something to exclude.
for f in touched-shippable touched-named touched-distonly; do
  dput "core/fixtures/$f/run.sh" 'at theirs'
done
rm -rf "$DIST/core/fixtures/touched-deleted"
dput "core/scripts/machinery.sh" 'at theirs'
# `gate-changed.sh` MOVES and `gate-steady.sh` does not. That difference is the whole subject of
# the post-write arms: the slice rewrites the first to this content, so a consumer copy equal to
# it is the written slice; a digest RECORDED as this content, for this path, means the gate ran
# on a tree that already held it.
dput "core/scripts/gate-changed.sh" 'gate-changed at theirs'
G add -A >/dev/null 2>&1; G commit -q --no-verify -m theirs >/dev/null 2>&1
D_THEIRS="$(G rev-parse HEAD 2>/dev/null)"
G tag theirs-tag >/dev/null 2>&1

# A quiet commit on top: machinery only, no fixture touched. Parts 1-6 run over this range so
# the coverage join stands down and they assert about the LOG, exactly as they did before.
dput "core/scripts/machinery.sh" 'after theirs'
G add -A >/dev/null 2>&1; G commit -q --no-verify -m quiet >/dev/null 2>&1
D_QUIET="$(G rev-parse HEAD 2>/dev/null)"
D_TREE="$(G rev-parse "${D_THEIRS}^{tree}" 2>/dev/null)"

# A range carrying ONE diff-touched fixture and no exempt directory at all. Part 8 runs over
# this rather than over base..theirs so that a mutant which breaks an EXEMPTION cannot also
# fail Part 8: the exemptions are Part 7's to own, and two arms failing on one mutation means
# one of them is asserting the other's subject.
dput "core/fixtures/touched-shippable/run.sh" 'after quiet'
G add -A >/dev/null 2>&1; G commit -q --no-verify -m ship >/dev/null 2>&1
D_SHIP="$(G rev-parse HEAD 2>/dev/null)"

# --- The DIST WORKTREE, made to DISAGREE with `theirs` in both directions -------------------
# LAST, and uncommitted, because nothing below runs `G add`. Every probe in the runner reads at
# a REF; an implementation reading `$DIST/core/fixtures/<d>/...` off disk answers for whatever
# the checkout happens to hold, which is a different tree from the one being delivered. On a
# seed where disk and theirs AGREE the two implementations are indistinguishable, so the wrong
# one passes. These four writes split them for BOTH probes in BOTH directions, and they are
# confined to four directories no other part names — the disk-reading mutant must fail Part 17
# and nothing else, or the arm that owns the read is not identifiable.
rm -f "$DIST/core/fixtures/theirs-only-distonly/.dist-only"
mkdir -p "$DIST/core/fixtures/theirs-only-nodriver"
printf '%s\n' 'on disk, committed nowhere' > "$DIST/core/fixtures/theirs-only-nodriver/run.sh"
printf '%s\n' 'on disk, committed nowhere' > "$DIST/core/fixtures/disk-only-distonly/.dist-only"
rm -f "$DIST/core/fixtures/disk-missing-driver/run.sh"

# --- A repo that is a git checkout but NOT the distribution --------------------------------
# The state is reachable from THIS fixture's own resolver: `pick` above takes the runner from
# three layouts, two of them consumer layouts, and walking up four levels from a consumer
# `.claude/skills/.../reconcile` lands on the consumer root — a git repo whose `theirs` has no
# `core/fixtures` tree, so the diff comes back empty and the join passes having seen nothing.
#
# THE SEED IS SHAPED TO SAY WHICH READ IS WRONG, not merely that something is. `core/fixtures`
# is COMMITTED AT BASE and deleted at theirs, and then written back to the WORKTREE
# uncommitted — so a guard keyed on the base ref, or on what is on disk, would pass here and
# only a read at THEIRS refuses. That is also why the exemptions have to be committed at the
# theirs commit rather than left on disk in the distribution seed above.
W()     { git -C "$WREPO" -c user.name=ai-dlc-fixture -c user.email=fixture@invalid \
                          -c commit.gpgsign=false "$@"; }
wput()  { mkdir -p "$(dirname "$WREPO/$1")" && printf '%s\n' "$2" > "$WREPO/$1"; }

git -c init.templateDir= init -q -b main "$WREPO" >/dev/null 2>&1 \
  || git -c init.templateDir= init -q "$WREPO" >/dev/null 2>&1
wput "core/fixtures/touched-shippable/run.sh" 'present at base only'
wput "tests/fixtures/green-one/run.sh" 'a consumer-layout fixture'
W add -A >/dev/null 2>&1; W commit -q --no-verify -m base >/dev/null 2>&1
W_BASE="$(W rev-parse HEAD 2>/dev/null)"

rm -rf "$WREPO/core"
wput "tests/fixtures/green-one/run.sh" 'a consumer-layout fixture, changed'
W add -A >/dev/null 2>&1; W commit -q --no-verify -m theirs >/dev/null 2>&1
W_THEIRS="$(W rev-parse HEAD 2>/dev/null)"
wput "core/fixtures/touched-shippable/run.sh" 'back on disk, committed nowhere'

# --- The FP-set repair, applied ONCE for every range every part below drives ----------------
# Both consumer trees, because parts 1 to 6 run against `$CONS` and 7 onward against `$CONS2`.
# `W_THEIRS -> W_BASE` is Part 13b's swapped range and Mutant 5's, the two runs against the
# wrong-repo checkout that are supposed to REACH the loop.
seed_ranges "$LOGDIR"  || bad "FIXTURE ERROR: could not seed the gate records for \$CONS"
seed_ranges "$LOGDIR2" || bad "FIXTURE ERROR: could not seed the gate records for \$CONS2"
seed_record "$LOGDIR2" "$WREPO" "$W_THEIRS" "$W_BASE"   OK 020 >/dev/null \
  || bad "FIXTURE ERROR: could not seed the wrong-repo swapped-range gate record"
seed_record "$LOGDIR2" "$WREPO" "$W_BASE"   "$W_THEIRS" OK 021 >/dev/null \
  || bad "FIXTURE ERROR: could not seed the wrong-repo forward-range gate record"

# --- Part 0: the seed can EXPRESS the defect ----------------------------------------------
# A fixture whose tree cannot reach the branch under test proves nothing, and every arm below
# would report green over a range the join never had anything to say about.
DIFFSET="$(G diff --name-only "$D_BASE" theirs-tag -- core/fixtures/ 2>/dev/null \
            | sed -E 's#^core/fixtures/([^/]+)/.*#\1#' | sort -u | tr '\n' ',')"
QUIETSET="$(G diff --name-only "$D_THEIRS" "$D_QUIET" -- core/fixtures/ 2>/dev/null | tr -d '\n')"
SHIPSET="$(G diff --name-only "$D_QUIET" "$D_SHIP" -- core/fixtures/ 2>/dev/null \
            | sed -E 's#^core/fixtures/([^/]+)/.*#\1#' | sort -u | tr '\n' ',')"
if [ "$DIFFSET" = "touched-deleted,touched-distonly,touched-named,touched-shippable," ] \
   && [ -z "$QUIETSET" ] && [ "$SHIPSET" = "touched-shippable," ] \
   && [ -n "$D_TREE" ] && [ -n "$D_BASE" ] && [ "$D_BASE" != "$D_THEIRS" ]; then
  ok "SEED: base..theirs carries all four coverage cases, the quiet range carries none, and the ship range carries one with no exemption in it"
else
  bad "FIXTURE ERROR: the seeded distribution does not present the coverage cases (base..theirs gave '${DIFFSET}', the quiet range gave '${QUIETSET:-empty}', the ship range gave '${SHIPSET:-empty}', tree '${D_TREE:-none}'). Every assertion below would be taken over a range the join cannot reach"
fi

# The wrong-repo seed has to be wrong in ONE readable way. If `core/fixtures` were absent at
# base and off disk too, Part 13 would fire for a guard reading any of the three, and the arm
# would not be able to say which read it is asserting.
if ! W cat-file -e "${W_THEIRS}:core/fixtures" 2>/dev/null \
   && W cat-file -e "${W_BASE}:core/fixtures" 2>/dev/null \
   && [ -f "$WREPO/core/fixtures/touched-shippable/run.sh" ] && [ -n "$W_BASE" ]; then
  ok "SEED: the wrong-repo checkout has core/fixtures at BASE and on DISK but not at THEIRS — only a read at theirs can refuse it"
else
  bad "FIXTURE ERROR: the wrong-repo seed is not shaped to discriminate (theirs-tree present, or base tree and worktree copy absent). Part 13 would fire for a guard reading the base ref or the working directory, and could not tell them apart"
fi

# The over-completeness seed has to disagree with itself, and one equality carries all of it.
# Six probes, each scored `<at-theirs><on-disk>`. Four of them are the discriminating pairs; the
# last two are the directories Parts 14 and 15 use, asserted to AGREE so that a disk-reading
# implementation moves Part 17 and leaves those two alone. Without this arm a seed whose disk
# state had drifted back into agreement would leave Part 17 passing for either implementation.
DISKSET=""
for probe in theirs-only-distonly/.dist-only theirs-only-nodriver/run.sh \
             disk-only-distonly/.dist-only disk-missing-driver/run.sh \
             named-distonly/.dist-only touched-deleted/run.sh; do
  pt=n; pd=n
  G cat-file -e "${D_QUIET}:core/fixtures/${probe}" 2>/dev/null && pt=y
  [ -e "$DIST/core/fixtures/${probe}" ] && pd=y
  DISKSET="${DISKSET}${probe}:${pt}${pd},"
done
if [ "$DISKSET" = "theirs-only-distonly/.dist-only:yn,theirs-only-nodriver/run.sh:ny,disk-only-distonly/.dist-only:ny,disk-missing-driver/run.sh:yn,named-distonly/.dist-only:yy,touched-deleted/run.sh:nn," ]; then
  ok "SEED: four directories disagree between the theirs tree and the DIST worktree, in both directions for both probes, and Parts 14 and 15's own directories agree"
else
  bad "FIXTURE ERROR: the disk/theirs disagreement seed reads '${DISKSET:-empty}'. Where disk and theirs agree, a probe reading the checkout and a probe reading the ref are the same program, and Part 17 would pass for either"
fi

# --- Part 1: an all-green run exits 0 and still writes the log --------------------------
# The log is not a failure artifact. A green self-update that is later questioned needs the
# same record, and a runner that wrote only on red would have none.
rm -f "$LOGDIR"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS" green-one cwd-probe >/dev/null 2>&1
rc=$?
L="$(newest_log)"
if [ "$rc" -eq 0 ] && [ -n "$L" ] && [ -s "$L" ]; then
  ok "an all-green run exits 0 and writes a non-empty log"
else
  bad "all-green run: expected rc=0 with a non-empty log, got rc=$rc log='${L:-none}'"
fi

# --- Part 2: the fixture runs from the CONSUMER ROOT ------------------------------------
if [ -n "$L" ] && grep -qF "cwd-probe ran from: $CONS" "$L"; then
  ok "the fixture is run with the consumer root current — the same directory both pre-push hooks use"
else
  bad "the fixture did not run from the consumer root. A fixture whose verdict depends on the caller's directory has shipped before (v0.263.0), so the runner deciding a self-update must stand where the gate deciding a push stands"
fi

# --- Part 3: THE DECISIVE ONE — the output outlives the tree ----------------------------
# Run a red fixture, then destroy the fixture tree exactly as step 2 does on red, and require
# the failing output to still be readable. The log is written to _bmad-output/, which the
# branch discard does not touch; a runner that buffered and wrote at exit would pass Parts 1
# and 2 and fail here, and so would one that wrote into the tree it is about to lose.
rm -f "$LOGDIR"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS" green-one red-one >/dev/null 2>&1
rc=$?
L="$(newest_log)"
rm -rf "$CONS/tests"          # the branch discard, in one line
if [ "$rc" -ne 0 ] && [ -n "$L" ] && grep -qF "THE DECISIVE LINE the operator needs after the branch is gone" "$L"; then
  ok "a red run exits non-zero and its failing output survives the tree being destroyed"
else
  bad "a red run left nothing readable after the tree was discarded (rc=$rc). That is the whole defect: the record died with the branch"
fi
if [ -n "$L" ] && grep -qF "red-one: and a stderr line too" "$L"; then
  ok "stderr is captured too — a fixture that reports its failure on stderr is the common case"
else
  bad "the log captured stdout only; a fixture failing on stderr would leave a log that reads clean"
fi
if [ -n "$L" ] && grep -qF "green-one: every assertion held" "$L"; then
  ok "the green fixture's output is in the same log — the reader can see what DID pass alongside what did not"
else
  bad "only the failing fixture was logged; without the passing ones the reader cannot tell a broken slice from a broken harness"
fi

# --- Part 4: an EMPTY set must not read as green ----------------------------------------
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS" >/dev/null 2>&1
if [ $? -eq 2 ]; then
  ok "naming no fixtures exits 2, not 0 — 'no failures' and 'no assertions' are not the same answer"
else
  bad "naming no fixtures did not exit 2. An empty set reporting green is how a self-update ships having verified nothing"
fi

# --- Part 5: a named fixture with no driver is not a pass -------------------------------
# The derived set comes from the distribution; if the slice did not write one of them, that is
# a finding about the CYCLE. Counting it green is how a missing file becomes a silent skip.
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS" never-written-by-the-slice >/dev/null 2>&1
rc=$?
L5="$(newest_log)"
if [ "$rc" -ne 0 ] && [ -n "$L5" ] && grep -qF "MISSING: tests/fixtures/never-written-by-the-slice/run.sh" "$L5"; then
  ok "a named fixture whose driver the slice never wrote is not counted as a pass, and the log says which one"
else
  bad "a named fixture with no run.sh scored as green (rc=$rc), or the log did not name it — a slice that wrote nothing would report a clean suite"
fi

# --- Part 6: the log extension is one git can still show ---------------------------------
# A reference consumer's .gitignore carries `*.log` and `*.txt`. Either would produce an
# artifact that exists on disk and is invisible to every `git status` the operator reads.
if [ -n "$L" ] && case "$L" in *.md) true ;; *) false ;; esac; then
  ok "the log is written as .md — not an extension a consumer's .gitignore commonly swallows"
else
  bad "the log is '${L:-none}'. A .log or .txt artifact is on disk and absent from git status, which is how evidence goes missing twice"
fi

# --- Part 7: the COVERAGE join refuses an INCOMPLETE set, and only for the right directory -
# ONE run, four cases. `touched-shippable` is changed by the diff, shippable and omitted — the
# offender. Standing beside it in the SAME run: `touched-named`, changed and NAMED;
# `touched-distonly`, changed and carrying the marker at theirs; `touched-deleted`, whose
# run.sh the diff removes; and `untouched-one`, which the diff never touches. All four are
# omitted from the named set, and none of them may appear in the refusal.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
OUT7="$CONS2/out-part7.txt"; ERR7="$CONS2/err-part7.txt"
bash "$RUNNER" "$DIST" "$D_BASE" theirs-tag "$CONS2" touched-named green-one >"$OUT7" 2>"$ERR7"
rc=$?
L7="$(newest_log2)"
COV7="$(cov_set "$L7")"
if [ "$rc" -eq 2 ] && grep -qF "the slice omits fixtures this diff CHANGES:" "$ERR7" \
   && grep -qF "touched-shippable" "$ERR7"; then
  ok "a diff-touched shippable fixture the slice omits is refused with exit 2 and named on stderr"
else
  bad "the slice omitted 'touched-shippable', which base..theirs changes, and the runner did not refuse (rc=$rc). Step 2's grep term cannot see a fixture the pull REPAIRS, so this join is the only thing between that slice and a consumer pre-push that stays red"
fi
if [ "$COV7" = "touched-shippable," ]; then
  ok "the logged refusal is EXACTLY the omitted shippable fixture — the named, the .dist-only, the deleted and the untouched directory all stood down in the same run"
else
  bad "the logged refusal is '${COV7:-empty}', not 'touched-shippable,'. Anything extra is an exemption that stopped exempting; anything missing is the join failing to see its own subject — and both are decided in this one run, so neither can be an artefact of a separate invocation"
fi
# ORDERING, on both channels in one arm. They are one property — nothing ran before the
# refusal — and splitting them would give a single placement change two cells to move.
if [ "$rc" -eq 2 ] && [ -n "$L7" ] && grep -qF "COVERAGE: the diff changes" "$L7" \
   && ! grep -qF "===== FIXTURE " "$L7" && ! grep -qE '^ +(ok|FAIL|MISS) +' "$OUT7"; then
  ok "the refusal is ORDERED BEFORE the fixture loop — no per-fixture section in the log and no per-fixture verdict on stdout"
else
  bad "the refusal was reported after the loop had already run: log sections $(grep -cF '===== FIXTURE ' "$L7" 2>/dev/null), stdout verdicts $(grep -cE '^ +(ok|FAIL|MISS) +' "$OUT7" 2>/dev/null). An incomplete set that prints a plausible green above its own finding is the state this arm exists to refuse, and an operator reads whichever channel is in front of them"
fi

# --- Part 8: naming the diff-touched fixture clears the join ------------------------------
# The positive direction, and it is what stops Part 7 from passing for a join that refuses
# everything. It runs over the SHIP range, whose diff carries one fixture and no exempt
# directory at all: over base..theirs a mutation to an exemption would fail this arm as well
# as Part 7's, and two arms moving on one edit means one of them is watching the other.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_QUIET" "$D_SHIP" "$CONS2" touched-shippable green-one \
  >"$CONS2/out-part8.txt" 2>"$CONS2/err-part8.txt"
rc=$?
L8="$(newest_log2)"
if [ "$rc" -eq 0 ] && [ -n "$L8" ] && grep -qF "===== FIXTURE touched-shippable =====" "$L8" \
   && grep -qF "===== FIXTURE green-one =====" "$L8" && ! grep -qF "COVERAGE:" "$L8"; then
  ok "naming the fixture the diff changes clears the join: the run reaches the loop and exits 0"
else
  bad "naming the one diff-touched fixture did not produce a green run (rc=$rc). A join that refuses a correct slice wedges every self-update, which is worse than the gap it closes"
fi

# --- Part 9: a range that touches no fixture is not a refusal -----------------------------
rm -f "$LOGDIR2"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" green-one \
  >"$CONS2/out-part9.txt" 2>"$CONS2/err-part9.txt"
rc=$?
L9="$(newest_log2)"
if [ "$rc" -eq 0 ] && [ -n "$L9" ] && grep -qF "===== FIXTURE green-one =====" "$L9" \
   && ! grep -qF "COVERAGE:" "$L9"; then
  ok "a range whose only change is a machinery path leaves every fixture unnamed and unrefused"
else
  bad "a range touching no fixture at all produced a coverage finding or a non-zero exit (rc=$rc). The pathspec is what bounds this join, and a join that fires on a machinery-only pull refuses every one of them"
fi

# --- Parts 10 and 11: an unresolvable ref is exit 2, never a silent skip -------------------
# BOTH positions, because the resolution loop walks BASE and THEIRS and a guard that reads
# only the first answers correctly for the input a one-sided test supplies. The assertion
# keys on the ref-resolution message specifically: the diff-failure arm below it also exits 2
# on a bogus ref, so an arm keyed on the exit code alone cannot tell the two apart.
#
# It does NOT re-assert that nothing ran first. Part 7 owns the ordering of this block, and a
# placement change would otherwise move four cells for one edit.
p_unresolvable() { # $1=label $2=base $3=theirs $4=the ref that must be named
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$RUNNER" "$DIST" "$2" "$3" "$CONS2" green-one >/dev/null 2>"$CONS2/err-unres.txt"
  local r=$? lg; lg="$(newest_log2)"
  if [ "$r" -eq 2 ] && [ -n "$lg" ] \
     && grep -qF "COVERAGE: UNRESOLVABLE — '${4}' does not name a commit" "$lg"; then
    ok "$1"
  else
    bad "$1 — got rc=$r and a log that does not record '${4}' as unresolvable. A coverage check that did not run reads exactly like one that passed, and it must not be the fixture loop's job to notice"
  fi
}
p_unresolvable "an unresolvable BASE exits 2 and logs COVERAGE: UNRESOLVABLE naming that ref" \
               no-such-base-ref theirs-tag no-such-base-ref
p_unresolvable "an unresolvable THEIRS exits 2 and logs it too — the loop reads both positions" \
               "$D_BASE" no-such-theirs-ref no-such-theirs-ref

# --- Part 12: a ref that resolves to a TREE is still unresolvable --------------------------
# The input only the ref-resolution loop can see. `git diff <tree> <commit>` SUCCEEDS, so the
# diff-failure arm never fires here; without the peel to `^{commit}` the join would run
# against a base that names no commit and report green over whatever fell out.
p_unresolvable "a BASE naming a TREE rather than a commit is refused — the one input the diff-failure arm below cannot catch" \
               "$D_TREE" theirs-tag "$D_TREE"

# --- Part 13: a git repo that is NOT the distribution is refused --------------------------
# Both refs resolve and `git diff` succeeds, so neither arm above sees this. What comes back
# is an EMPTY diff, which walks the join to its own success: nothing uncovered, nothing said,
# a pass that is byte-identical to a complete set. Naming a fixture that WOULD run green is
# deliberate — the failure this refuses is a green suite, so the arm has to be able to see one.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
bash "$RUNNER" "$WREPO" "$W_BASE" "$W_THEIRS" "$CONS2" green-one \
  >"$CONS2/out-part13.txt" 2>"$CONS2/err-part13.txt"
rc=$?
L13="$(newest_log2)"
if [ "$rc" -eq 2 ] && [ -n "$L13" ] && grep -qF "COVERAGE: WRONG-REPO" "$L13" \
   && grep -qF "has no core/fixtures tree" "$CONS2/err-part13.txt"; then
  ok "a \$DIST that is a git repo but carries no core/fixtures at theirs is refused with exit 2 and COVERAGE: WRONG-REPO"
else
  bad "a \$DIST with no core/fixtures at theirs was accepted (rc=$rc). Its diff is EMPTY, so the join reports nothing having OBSERVED nothing — and this fixture's own resolver reaches that state, because walking up four levels from a consumer-layout copy of the runner lands on the consumer root"
fi
# The near-miss, in the SAME repo with ONE argument different: swap the refs and theirs now
# carries the tree. An arm that fired here as well would be refusing the repo, not the read.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
bash "$RUNNER" "$WREPO" "$W_THEIRS" "$W_BASE" "$CONS2" touched-shippable \
  >"$CONS2/out-part13b.txt" 2>"$CONS2/err-part13b.txt"
rc=$?
L13B="$(newest_log2)"
if [ "$rc" -eq 0 ] && [ -n "$L13B" ] && grep -qF "===== FIXTURE touched-shippable =====" "$L13B" \
   && ! grep -qF "COVERAGE:" "$L13B"; then
  ok "the same checkout with the refs swapped is NOT refused — the tree is read at THEIRS, not at base and not off disk"
else
  bad "the same checkout was refused with the refs swapped (rc=$rc), so the guard is keyed on something other than the theirs position. core/fixtures is committed at that end of this range"
fi

# --- Parts 14 to 19: the OVER-completeness arm ---------------------------------------------
# The join above refuses a set that OMITS a diff-touched directory. These refuse a set that
# CONTAINS one no consumer can ever hold. Filed by the reference consumer as
# PC-S307-STEP-2-FIXTURE-TERM-B-EXCLUSIONS-ARE-DERIVABLE-BY-HAND-AND-WERE-MIS-DERIVED: a hand
# derivation of step 2's term B yielded `backlog-size-ceiling`, which carries `.dist-only`, and
# it was written into the consumer's `tests/fixtures/` as a RETIRED-FIXTURE-ORPHAN. The run was
# GREEN — the slice delivered what was named, so the MISS arm had nothing to say.
#
# ALL OF THESE RUN OVER THE QUIET RANGE, whose diff touches no fixture at all. That is what
# makes a refusal here unambiguous: the miss-join has nothing to report over that range, so any
# COVERAGE finding is this arm's, and a mutation to one arm cannot be scored by the other.
#
# WHICH ARM OWNS WHICH MUTATION, measured by running THIS WHOLE FIXTURE against each of Mutants
# 6 to 14 as its subject rather than by reading the scoring blocks below. Most of them move more
# than one arm, and that is reported here rather than engineered away: the overlaps are
# conservation rather than vacuity, because a wrong implementation of a two-probe guard is wrong
# in several ways at once. No arm here may be deleted on the grounds that another also catches
# its mutant.
#   14  ordering, the reason text, and the exit code       shares every mutant with 15 or 17
#   15  the deleted-driver exclusion, under its own reason shares every mutant with 14 or 17
#   16  the ACQUITTAL of a wholly shippable set            the arm Mutant 14 is scored on, and
#                                                          the only one a WIDENING copy fails
#   17  the read is at THEIRS, not off the checkout        Mutant 11 moves THIS ARM ALONE
#   18  sited below the ref-resolution loop                Mutant 9
#   19  sited below the wrong-repo guard                   Mutant 10, which Part 18 cannot see
# Mutants 9 and 10 also move Parts 11 and 13. That is the same property read from the other
# side — an arm hoisted above a guard makes that guard unreachable — not a second subject.

# --- Part 14: the .dist-only offender, convicted BESIDE three legitimate directories ---------
# ONE run, four directories. A near-miss in a SEPARATE run is an ADJACENT input: it can only ask
# whether the arm fires, never whether it fires on the right directory, and this repo has paid
# three rounds for that shape already. The set equality is the whole assertion — `named-distonly`
# present is the conviction, the other three absent is the acquittal, and both are decided by the
# same invocation over the same tree.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
OUT14="$CONS2/out-part14.txt"; ERR14="$CONS2/err-part14.txt"
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
     named-distonly green-one cwd-probe touched-shippable >"$OUT14" 2>"$ERR14"
rc=$?
L14="$(newest_log2)"
UNS14="$(uns_set "$L14")"
if [ "$rc" -eq 2 ] && grep -qF "the named set contains fixtures no consumer can run:" "$ERR14"; then
  ok "a named directory carrying .dist-only at theirs is refused with exit 2 and the arm's own message"
else
  bad "the named set contained 'named-distonly', which carries .dist-only at theirs, and the runner did not refuse with that message (rc=$rc). Step 2 derives this set by hand; the exclusions were stated for the diff-side term only, and the surplus directory reaches the consumer as a fixture core never ships"
fi
if [ "$UNS14" = "named-distonly," ]; then
  ok "the logged refusal is EXACTLY the unshippable directory — the three legitimate names beside it in the SAME run were all acquitted"
else
  bad "the logged refusal is '${UNS14:-empty}', not 'named-distonly,'. Anything extra is the arm convicting a directory a consumer can perfectly well run, which wedges every self-update; anything missing is the arm failing to see its own subject. Both are decided here, so neither can be an artefact of a separate invocation"
fi
if grep -qF "carries .dist-only at" "$ERR14"; then
  ok "the refusal states WHICH exclusion it applied, so an operator can tell a never-shipped fixture from a deleted driver"
else
  bad "the refusal named the directory without its reason. Two exclusions produce this exit and a remedy that cannot say which one applied sends the reader to the wrong half of step 2"
fi
# ORDERING, both channels in one arm — they are one property and splitting them would give a
# single placement change two cells to move.
if [ "$rc" -eq 2 ] && [ -n "$L14" ] && ! grep -qF "===== FIXTURE " "$L14" \
   && ! grep -qE '^ +(ok|FAIL|MISS) +' "$OUT14"; then
  ok "the refusal is ORDERED BEFORE the fixture loop — no per-fixture section in the log and no per-fixture verdict on stdout"
else
  bad "the refusal was reported after the loop had already run: log sections $(grep -cF '===== FIXTURE ' "$L14" 2>/dev/null), stdout verdicts $(grep -cE '^ +(ok|FAIL|MISS) +' "$OUT14" 2>/dev/null). Running the surplus fixture first is how the orphan gets a green verdict printed above the finding that condemns it"
fi

# --- Part 15: the deleted-driver offender, in its own run and with its own reason ------------
# The SECOND exclusion, and it needs its own run rather than a second offender in Part 14's: a
# mutant that deletes one probe and keeps the other must move exactly one of these two arms.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
ERR15="$CONS2/err-part15.txt"
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
     touched-deleted green-one cwd-probe touched-shippable \
     >"$CONS2/out-part15.txt" 2>"$ERR15"
rc=$?
UNS15="$(uns_set "$(newest_log2)")"
if [ "$rc" -eq 2 ] && [ "$UNS15" = "touched-deleted," ] && grep -qF "no run.sh at" "$ERR15"; then
  ok "a named directory whose driver upstream DELETED is refused, named alone, and reported under the deleted-driver reason"
else
  bad "a named directory with no run.sh at theirs was not refused under its own reason (rc=$rc, refused '${UNS15:-empty}'). The MISS arm below reports this only when the slice FAILED to write the directory; when the slice writes it the run is green and the orphan survives, which is the episode that was filed"
fi

# --- Part 16: a wholly legitimate set does NOT trip the arm ----------------------------------
# The negative direction, and it is keyed on the arm's OWN MESSAGE rather than on the exit code:
# exit 2 has six producers in this runner and a control reading only the code cannot tell them
# apart. The positive conjunct is a fixture section — an arm asserting only that nothing was said
# passes against a subject replaced by `exit 0`.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
ERR16="$CONS2/err-part16.txt"
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
     green-one cwd-probe touched-named touched-shippable \
     >"$CONS2/out-part16.txt" 2>"$ERR16"
rc=$?
L16="$(newest_log2)"
if [ "$rc" -eq 0 ] && [ -n "$L16" ] && grep -qF "===== FIXTURE touched-named =====" "$L16" \
   && ! grep -qF "COVERAGE: the named set contains" "$L16" \
   && ! grep -qF "no consumer can run" "$ERR16"; then
  ok "a set of four directories a consumer CAN run reaches the loop and exits 0 — the arm stays silent on correct input"
else
  bad "a wholly shippable named set was refused, or never reached the loop (rc=$rc). An over-completeness arm that fires on a correct slice wedges every self-update, which is worse than the orphan it prevents"
fi

# --- Part 17: THE READ IS AT THEIRS, not off the distribution checkout -----------------------
# Four directories whose disk state and theirs state DISAGREE, in one run, two convicted and two
# acquitted. An implementation probing `$DIST/core/fixtures/<d>/...` on the filesystem returns the
# exact inverse of this set, and would pass a seed where the two agreed. The distribution checkout
# is not the tree being delivered: `$DIST` is a working copy at whatever revision the caller left
# it, and the slice is computed from `theirs`.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
     theirs-only-distonly theirs-only-nodriver disk-only-distonly disk-missing-driver green-one \
     >"$CONS2/out-part17.txt" 2>"$CONS2/err-part17.txt"
rc=$?
UNS17="$(uns_set "$(newest_log2)")"
if [ "$rc" -eq 2 ] && [ "$UNS17" = "theirs-only-distonly,theirs-only-nodriver," ]; then
  ok "the exclusions are read AT THEIRS: the two directories unshippable at theirs are refused though the checkout says otherwise, and the two the checkout condemns are acquitted"
else
  bad "the refusal is '${UNS17:-empty}', not 'theirs-only-distonly,theirs-only-nodriver,' (rc=$rc). 'disk-only-distonly,disk-missing-driver,' is the answer a probe reading \$DIST off the filesystem gives, and it is wrong in both directions at once: it acquits an orphan bound for the consumer and convicts two fixtures the pull delivers"
fi

# --- Part 18: the arm is SITED AFTER the ref resolution --------------------------------------
# Both of its probes are `cat-file -e` at theirs. Against an unresolvable THEIRS every one of them
# fails, so an arm placed above the resolution loop convicts the ENTIRE named set — a check whose
# failure mode is to indict correct input, pointing the operator at a slice that is fine. Both
# names here are directories the distribution genuinely ships, so the only thing the misplaced
# copy can produce is a false conviction. The assertion is on the two MESSAGES, not on the exit
# code, which is 2 either way.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_THEIRS" no-such-theirs-ref "$CONS2" green-one touched-shippable \
  >"$CONS2/out-part18.txt" 2>"$CONS2/err-part18.txt"
rc=$?
L18="$(newest_log2)"
if [ "$rc" -eq 2 ] && [ -n "$L18" ] \
   && grep -qF "COVERAGE: UNRESOLVABLE — 'no-such-theirs-ref' does not name a commit" "$L18" \
   && ! grep -qF "COVERAGE: the named set contains" "$L18"; then
  ok "an unresolvable THEIRS exits on the RESOLUTION arm — the over-completeness arm cannot speak before its own probes can resolve"
else
  bad "an unresolvable THEIRS did not exit on the resolution arm (rc=$rc). With the over-completeness arm above it, every \`cat-file -e\` fails and both of these perfectly shippable directories are convicted for a reason that has nothing to do with the slice"
fi

# --- Part 19: the arm is SITED AFTER the WRONG-REPO guard ------------------------------------
# The input the arm above cannot see: both refs resolve here, so Part 18 is satisfied by a copy
# sited between the resolution loop and this guard. What that copy gets wrong is a checkout with
# no `core/fixtures` tree at theirs — every probe fails again, and both named directories are
# condemned instead of the repo.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
bash "$RUNNER" "$WREPO" "$W_BASE" "$W_THEIRS" "$CONS2" green-one touched-shippable \
  >"$CONS2/out-part19.txt" 2>"$CONS2/err-part19.txt"
rc=$?
L19="$(newest_log2)"
if [ "$rc" -eq 2 ] && [ -n "$L19" ] && grep -qF "COVERAGE: WRONG-REPO" "$L19" \
   && ! grep -qF "COVERAGE: the named set contains" "$L19"; then
  ok "a \$DIST with no core/fixtures at theirs exits on the WRONG-REPO guard — the over-completeness arm is sited below it and convicts nothing"
else
  bad "a checkout with no core/fixtures at theirs was reported as an over-complete named set (rc=$rc), not as the wrong repo. Both refs resolve here, so the resolution loop lets this through and only the wrong-repo guard's position keeps the arm from indicting two directories the distribution genuinely ships"
fi

# --- Parts G1 to G5: the RECORDED GATE VERDICT is what authorises the cycle ------------------
# Step 2 cuts a branch, writes the machinery slice, pushes and auto-merges with NO operator
# gate, and until this arm existed the only record of the decision that permitted the write was
# the operating agent's narration in a PR body. `self-update-gate.sh` prints TSV and the runner
# ran whatever it was handed, so a cycle that never invoked the gate at all was
# indistinguishable from one the gate cleared.
#
# THE PARTS ARE SPLIT BY WHAT EACH ONE CAN SEE, and no two share an input:
#   G1  no record at all                     the state every cycle starts in
#   G2  a record whose verdict is DEFER      a gate that RAN and said no
#   G3  an OK record for a DIFFERENT range   the input a presence-only check accepts
#   G4  the SHIPPING gate's own record       the only part that proves the two grammars agree
#   G5  a DEFER record NEWER than an OK      the input a first-match-wins reader accepts
#
# EVERY ONE OF THESE USES ITS OWN CONSUMER TREE. `$CONS`/`$CONS2` already carry the seeded OK
# records for every range the parts above drive, and an arm asserting a REFUSAL cannot be run in
# a directory where an acquitting record exists — the refusal would be the seed's absence rather
# than the arm's subject, and seeding is not something a part should have to undo.
GCONS="$(bash "$HERE/seed.sh")"
GLOG="$GCONS/_bmad-output/ai-dlc-update"
trap 'rm -rf "$CONS" "$CONS2" "$DIST" "$WREPO" "$GCONS"' EXIT
newest_glog() { ls -t "$GLOG"/self-update-fixtures-*.md 2>/dev/null | head -1; }

GIN_CHANGED="scripts/ai-dlc/gate-changed.sh"
GIN_STEADY="scripts/ai-dlc/gate-steady.sh"
GIN_REL="$GIN_CHANGED"
gin_seed() { # $1=inputs block $2=suffix -> seeds ONE record for the G-range, clearing first
  rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
  SR_INPUTS="$1" seed_record "$GLOG" "$DIST" "$D_BASE" "$D_THEIRS" OK "$2" >/dev/null \
    || bad "FIXTURE ERROR: could not seed the input-bearing record for suffix $2"
}
# A record over the range that CHANGES the gating script, whose inputs are the derived required
# set taken on the tree as it stands right now. Every G-part starts from this and then moves one
# thing.
gin_seed_clean() { # $1=suffix
  gin_seed "$(sr_required_inputs "$GCONS")" "$1"
}
# The same record with a DEFER trailer. Its inputs are the derived required set too, so a reader
# refusing it on the verdict and one refusing it on a missing input cannot be told apart unless
# the inputs are complete.
gin_seed_defer() { # $1=suffix
  rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
  SR_INPUTS="$(sr_required_inputs "$GCONS")" \
    seed_record "$GLOG" "$DIST" "$D_BASE" "$D_THEIRS" DEFER "$1" >/dev/null \
    || bad "FIXTURE ERROR: could not seed the DEFER record for suffix $1"
}
gin_hash() { git hash-object "$GCONS/$1" 2>/dev/null; }
# Restore both gating scripts to their BASE content — the state the gate is run on.
gin_restore() {
  printf '%s\n' 'gate-changed at base' > "$GCONS/$GIN_CHANGED"
  printf '%s\n' 'gate-steady, never moved' > "$GCONS/$GIN_STEADY"
  chmod +x "$GCONS/$GIN_CHANGED" "$GCONS/$GIN_STEADY"
}
# The slice, as step 2 writes it: every hook-named script the range changes, taken from theirs.
gin_write_slice() {
  git -C "$DIST" show "${D_THEIRS}:core/scripts/gate-changed.sh" > "$GCONS/$GIN_CHANGED" 2>/dev/null
}

# --- Part G1: NO record for this range is a refusal, not a green run --------------------------
# Keyed on the `GATE-RECORD:` line in the runner's OWN LOG as well as the exit code, because
# exit 2 has seven producers in this runner and a part reading only the code cannot say which
# one answered. The named set is wholly legitimate for this range — the only thing wrong here is
# that nothing authorised the cycle.
#
# A RECORD FOR AN UNRELATED RANGE IS SEEDED FIRST, AND IT IS WHAT MAKES THIS PART ITS OWN. An
# EMPTY record directory is the delivery-pull state Part G12 owns, where proceeding is correct;
# with one record present this consumer has demonstrably recorded a verdict before, so the
# requirement binds. The two parts are one property apart and the seed is the property.
gin_restore
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
seed_record "$GLOG" "$DIST" "$D_QUIET" "$D_SHIP" OK 190 >/dev/null \
  || bad "FIXTURE ERROR: could not seed Part G1's unrelated-range record"
ERRG1="$GCONS/err-g1.txt"; OUTG1="$GCONS/out-g1.txt"
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one >"$OUTG1" 2>"$ERRG1"
rc=$?
LG1="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG1" ] && grep -qF "GATE-RECORD:" "$LG1"; then
  ok "with NO gate record the runner refuses with exit 2 and a GATE-RECORD line in its own log"
else
  bad "the runner ran the fixtures with no recorded gate verdict at all (rc=$rc, log '${LG1:-none}'). Step 2 pushes and auto-merges autonomously, so the gate's recorded OK is the only artifact of the decision that permitted the write — without this the suite reports green for a cycle nothing authorised"
fi
if grep -qF "self-update-gate.sh" "$ERRG1"; then
  ok "the stderr remedy names the exact gate command, so the operator is not left to derive it"
else
  bad "the refusal did not name the gate command on stderr. A refusal whose remedy the reader has to reconstruct is where a cycle gets rerun with the check switched off"
fi
# ORDERING, both channels in one arm — the refusal must precede the loop, or a green verdict is
# printed above the finding that condemns it.
if [ -n "$LG1" ] && ! grep -qF "===== FIXTURE " "$LG1" && ! grep -qE '^ +(ok|FAIL|MISS) +' "$OUTG1"; then
  ok "the gate-record refusal is ORDERED BEFORE the fixture loop — no per-fixture section and no per-fixture verdict"
else
  bad "the runner reported fixture verdicts before refusing for a missing gate record: sections $(grep -cF '===== FIXTURE ' "$LG1" 2>/dev/null), stdout verdicts $(grep -cE '^ +(ok|FAIL|MISS) +' "$OUTG1" 2>/dev/null)"
fi

# --- Part G2: a DEFER record is a refusal ----------------------------------------------------
# The input a PRESENCE check cannot see. A record exists, its shas match this exact range, and
# the gate said do not proceed — so a reader that only asks whether a record is there acquits
# the one case the gate explicitly refused.
gin_restore
gin_seed_defer 195
ERRG2="$GCONS/err-g2.txt"
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one >/dev/null 2>"$ERRG2"
rc=$?
LG2="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG2" ] && grep -qF "GATE-RECORD:" "$LG2" && grep -qF "DEFER" "$LG2"; then
  ok "a gate record for this range whose verdict is DEFER is refused, and the log says which verdict it read"
else
  bad "a DEFER verdict for this exact range did not stop the run (rc=$rc). A reader asking only whether a record EXISTS acquits the one case the gate explicitly refused, which is worse than no check at all"
fi

# --- Part G3: an OK record for a DIFFERENT range is a refusal --------------------------------
# The input only a sha-matching reader can see. The record is real, its verdict is OK, and it
# classified a different pull entirely — a stale artifact from the previous self-update, which is
# the state a consumer's `_bmad-output/` is in on every cycle after the first.
gin_restore
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
seed_record "$GLOG" "$DIST" "$D_QUIET" "$D_SHIP" OK 196 >/dev/null \
  || bad "FIXTURE ERROR: could not seed the wrong-range record for Part G3"
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one >/dev/null 2>&1
rc=$?
LG3="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG3" ] && grep -qF "GATE-RECORD:" "$LG3"; then
  ok "an OK record classifying a DIFFERENT range does not authorise this one — the stale artifact of the previous cycle is refused"
else
  bad "an OK record for another range authorised this cycle (rc=$rc). After the first self-update a consumer's _bmad-output/ always holds one, so a reader that does not compare shas is permanently satisfied by an artifact that classified a different pull"
fi

# --- Part G4: THE SHIPPING GATE'S OWN RECORD, not a forged one -------------------------------
# The only part here that establishes the two halves agree. Every other part seeds a record this
# fixture's own author wrote, so they all prove the reader accepts its author's grammar — which
# stays true through a change to BOTH sides. This one runs `self-update-gate.sh` against the
# throwaway distribution and the seeded consumer, then hands the runner whatever it wrote.
#
# THE THROWAWAY DIST CARRIES A `core/git-hooks/pre-push`, and that is required rather than
# decorative: with no hook at the consumer and none in the distribution the gate emits
# SELF-UPDATE-UNDECIDED ("no pre-push hook found") and records a verdict this runner correctly
# refuses — the part would then fail for a reason that has nothing to do with the join.
GATE_SH="$RECONCILE/self-update-gate.sh"
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
if [ ! -f "$GATE_SH" ]; then
  bad "FIXTURE ERROR: self-update-gate.sh is not beside the runner at $RECONCILE, so the record's WRITER cannot be driven and nothing here establishes that the two grammars agree"
else
  G_OUT="$GCONS/out-g4-gate.txt"; G_ERR="$GCONS/err-g4-gate.txt"
  gin_restore
  bash "$GATE_SH" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" >"$G_OUT" 2>"$G_ERR"
  g_rc=$?
  G_REC="$(ls -t "$GLOG"/self-update-gate-*.md 2>/dev/null | head -1)"
  if [ "$g_rc" -eq 0 ] && [ -n "$G_REC" ] && [ -s "$G_REC" ]; then
    ok "the SHIPPING gate writes a record of its own under _bmad-output/ai-dlc-update/"
    # The record has to say OK for the join to be observable at all; if the gate defers on this
    # seed the arm below cannot distinguish a reader defect from a correct refusal, so the
    # verdict is read and reported rather than assumed.
    g_verdict="$(awk 'index($0, "# verdict:") == 1 { s = substr($0, 11); gsub(/[[:space:]]/, "", s); print s; exit }' "$G_REC")"
    if [ "$g_verdict" = "OK" ]; then
      # IN STEP 2'S ORDER: the slice is written between the gate and the runner, so this arm
      # exercises the join on the state a real cycle presents rather than on a tree nothing
      # touched. Driving the two back to back is what let the shipped runner refuse every
      # legitimate self-update while this part stayed green.
      gin_write_slice
      bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one >/dev/null 2>&1
      rc=$?
      LG4="$(newest_glog)"
      # THE COLUMN COUNT IS READ BEFORE THE VERDICT IS SCORED, so "the writer has not landed
      # yet" and "the join is broken" are two different rows rather than one. A record whose
      # input lines carry two fields is the PRE-correction gate: the reader needs the core path
      # to accept a file the slice moved to `theirs`, and without it every line is unevaluable.
      g4_cols="$(awk -F'\t' 'index($0, "# input: ") == 1 { print NF; exit }' "$G_REC" 2>/dev/null)"
      if [ "$rc" -eq 0 ] && [ -n "$LG4" ] && grep -qF "===== FIXTURE green-one =====" "$LG4" \
         && ! grep -qF "GATE-RECORD:" "$LG4"; then
        ok "the runner ACCEPTS the record the shipping gate wrote, in step 2's real order, and reaches the loop — the writer's grammar and the reader's agree, established by running both and not by one author writing both"
      elif [ "${g4_cols:-0}" -lt 3 ]; then
        bad "PENDING the three-column writer: the shipping gate wrote ${g4_cols:-0}-field input lines and this reader requires three (path, digest, CORE PATH). The core path is what lets an input the slice moved to \`theirs\` be accepted, so a two-column record cannot express the legitimate post-write state at all. This is the only arm here that reads the real writer, and it stays red until that half lands"
      else
        bad "the runner refused the record the SHIPPING gate wrote for this exact range (rc=$rc): $(grep -m1 '^GATE-RECORD:' "$LG4" 2>/dev/null | cut -c1-160). Every other part here seeds a record this fixture authored, so they would all stay green through a change that broke the join; this is the only arm that can see it"
      fi
      if [ -n "$LG4" ] && grep -qF "$(basename "$G_REC")" "$LG4"; then
        ok "the runner's log header CITES the gate record it accepted, so the two artifacts of one cycle name each other"
      else
        bad "the runner ran on a gate record and did not name it in its log. The pair of records is the approval artifact for an autonomous write, and a log that does not say which record authorised it leaves the reader to guess"
      fi
    else
      bad "FIXTURE ERROR: the shipping gate recorded verdict '${g_verdict:-<absent>}' on this seed, not OK, so the acceptance join below could not be scored. Gate stdout: $(head -1 "$G_OUT" 2>/dev/null | cut -c1-160)"
    fi
  else
    bad "PENDING hand-gate: the shipping self-update-gate.sh wrote no record under $GLOG (rc=$g_rc). The record's WRITER is the other half of batch 78 and lands in a separate commit; until it does, this part is the only failing one here and its failure is that absence, not a defect in the reader"
  fi
fi

# --- Part G5: the NEWEST matching record decides, and it is picked by NAME --------------------
# The input a first-match-wins reader accepts. An OK is written, the operator changes something,
# the gate runs again and DEFERS — and a reader that stops at the first matching record it finds
# revives the superseded OK. Both records match this range exactly, so nothing but the ordering
# separates them.
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
gin_restore
G5_OK="$(SR_INPUTS="$(sr_required_inputs "$GCONS")" seed_record "$GLOG" "$DIST" "$D_BASE" "$D_THEIRS" OK 100)" \
  || bad "FIXTURE ERROR: could not seed Part G5's OK record"
G5_DEFER="$(SR_INPUTS="$(sr_required_inputs "$GCONS")" seed_record "$GLOG" "$DIST" "$D_BASE" "$D_THEIRS" DEFER 900)" \
  || bad "FIXTURE ERROR: could not seed Part G5's DEFER record"
# THE SEED IS ASSERTED TO DISCRIMINATE BEFORE IT IS SCORED. Two records written inside the same
# wall-clock second sort identically, and the arm would then pass for either implementation.
if [ -n "${G5_OK:-}" ] && [ -n "${G5_DEFER:-}" ] \
   && [ "$(basename "$G5_DEFER")" \> "$(basename "$G5_OK")" ]; then
  ok "SEED: Part G5's DEFER record sorts strictly AFTER its OK record by name, so the two orderings give different answers"
else
  bad "FIXTURE ERROR: Part G5's two records do not order ('${G5_OK:-none}' then '${G5_DEFER:-none}'). Where the newest and the oldest are the same file, an implementation picking either passes, and the arm below asserts nothing"
fi
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one >/dev/null 2>&1
rc=$?
LG5="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG5" ] && grep -qF "GATE-RECORD:" "$LG5"; then
  ok "with a DEFER record NEWER than an OK for the same range the runner reads the newest and refuses — a superseded OK cannot be revived by reaching further back"
else
  bad "a superseded OK record authorised the cycle (rc=$rc). The gate ran twice and its LAST answer was DEFER; a reader taking the oldest, or the first it happens to encounter, acts on a verdict the gate has already withdrawn"
fi

# --- Parts G6 to G11: the record binds the CONSUMER TREE, and WHICH WAY an input moved --------
# The gate's verdict is a DIFFERENTIAL — it runs the consumer's CURRENT copy of each gating
# script against the incoming one — so the same command over one range answers differently as
# the tree moves. But "nothing moved" is the WRONG rule and it refused every legitimate
# self-update: step 2's order is gate, WRITE THE SLICE, runner, so the files the slice replaced
# are exactly the ones that differ. Measured on the gate's own seed driving both shipping
# programs in that order: 4 of 9 recorded inputs moved, every one to precisely the `theirs` blob
# of its core path.
#
# SO THE DISCRIMINATOR IS WHICH INPUT MOVED AND TOWARD WHAT. `now` equal to the recorded digest
# is untouched; equal to `theirs:<core path>` is the written slice; equal to neither is a third
# hand. And a digest RECORDED as the `theirs` blob, on a path the range changes, is a gate that
# compared the incoming file with itself — the one case where record and tree agree perfectly and
# the verdict is still worthless.
#
# Each part below is the ONE input that separates a reader from a weaker one:
#   G6   a gating script the SLICE wrote           the NORMAL order — a "nothing moved" reader refuses
#   G7   a record naming NO inputs                 a reader looping over zero lines accepts
#   G8   a third-hand edit                         a reader accepting any change accepts
#   G9   a recorded ABSENT that is now PRESENT     a reader skipping ABSENT accepts
#   G10  a recorded digest whose file is now ABSENT  a reader testing only "differs" accepts
#   G11  an input value that is neither hex nor ABSENT  a reader `continue`-ing on the unknown
#   G14  a LATE GATE                               a digest reader cannot see it — the digests agree
#   G15  a forged single-line record               a reader trusting the record's own input list
#   G16  a `-` row naming a non-hook core path     a reader resolving `-` against anything
#
# THE TWO GATING SCRIPTS `seed.sh` WRITES ARE THE SUBJECTS. `gate-changed.sh` moves across
# base..theirs, so it is the one the slice rewrites; `gate-steady.sh` does not, so it must hold
# its recorded digest through every legitimate flow. Both are named by the consumer's own hook,
# which is what the runner derives its required set from.

# --- SEED CONTROL: the two gating scripts must DIFFER across the range in one direction only ---
# `gate-changed.sh` moving and `gate-steady.sh` not moving is the property every part below
# turns on, and where both moved (or neither did) a reader accepting anything and a reader
# accepting only `theirs` would give the same answer on every input here.
gin_cb="$(git -C "$DIST" rev-parse -q --verify "${D_BASE}:core/scripts/gate-changed.sh" 2>/dev/null)"
gin_ct="$(git -C "$DIST" rev-parse -q --verify "${D_THEIRS}:core/scripts/gate-changed.sh" 2>/dev/null)"
gin_sb="$(git -C "$DIST" rev-parse -q --verify "${D_BASE}:core/scripts/gate-steady.sh" 2>/dev/null)"
gin_st="$(git -C "$DIST" rev-parse -q --verify "${D_THEIRS}:core/scripts/gate-steady.sh" 2>/dev/null)"
if [ -n "$gin_cb" ] && [ -n "$gin_ct" ] && [ "$gin_cb" != "$gin_ct" ] \
   && [ -n "$gin_sb" ] && [ "$gin_sb" = "$gin_st" ] \
   && [ -f "$GCONS/.githooks/pre-push" ]; then
  ok "SEED: the consumer has its own pre-push hook, and of the two scripts it names exactly ONE changes across base..theirs — so a reader accepting any change and one accepting only \`theirs\` give different answers"
else
  bad "FIXTURE ERROR: the gating-script seed does not discriminate (changed ${gin_cb:-none}->${gin_ct:-none}, steady ${gin_sb:-none}->${gin_st:-none}, hook $([ -f "$GCONS/.githooks/pre-push" ] && echo present || echo ABSENT)). Where both scripts move, or neither does, every arm below passes for a reader that accepts any post-record content"
fi

# --- Part G6: THE NORMAL ORDER — gate, write the slice, runner ACCEPTS ------------------------
# THE LOAD-BEARING ARM, and the one whose absence let the shipped runner refuse every legitimate
# self-update. Step 2 runs the gate on the pre-write tree, writes the slice, then runs this
# runner; the recorded digest of every script the slice replaced is therefore STALE BY DESIGN.
# Measured on the gate's own seed with both shipping programs driven in that order: 4 of 9
# recorded inputs moved, all four to exactly the `theirs` blob. An arm that only ever ran the
# gate and the runner back to back — with nothing written between — could not see it.
gin_restore
gin_seed_clean 200
gin_write_slice
ERRG6="$GCONS/err-g6.txt"
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>"$ERRG6"
rc=$?
LG6="$(newest_glog)"
if [ "$rc" -eq 0 ] && [ -n "$LG6" ] && grep -qF "===== FIXTURE green-one =====" "$LG6" \
   && ! grep -qF "GATE-RECORD:" "$LG6"; then
  ok "THE NORMAL ORDER: gate, write the slice, runner — a gating script now holding what this pull SHIPS is the slice the cycle just wrote, and the run reaches the loop"
else
  bad "the legitimate flow was REFUSED (rc=$rc): $(grep -m2 '^GATE-RECORD:' "$LG6" 2>/dev/null | tr '\n' ' ' | cut -c1-200). Step 2 writes the slice BETWEEN the gate and this runner, so the recorded digests of the replaced scripts are stale by design; a rule spelled 'nothing moved' fails closed on every self-update whose range changes a gating script"
fi
# The UNTOUCHED script must still be compared, or the arm above passes for a reader that accepts
# any post-record content whatsoever.
if [ "$(gin_hash "$GIN_STEADY")" = "$gin_sb" ]; then
  ok "...and the script the range does NOT change still holds its recorded content, so the acceptance above is about the slice and not about the check having stopped looking"
else
  bad "gate-steady.sh moved during Part G6, so the acceptance cannot be attributed to the theirs-blob rule. Every arm here would pass for a reader comparing nothing"
fi

# --- Part G7: a record naming NO inputs is malformed ------------------------------------------
# Zero lines to compare is a comparison that cannot fail, and its silence is byte-identical to a
# comparison that passed.
gin_restore
gin_seed "$SR_NO_INPUTS" 210
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG7="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG7" ] && grep -qF "GATE-RECORD:" "$LG7"; then
  ok "a record for this range, verdict OK, naming NO input files is refused — nothing to compare is not the same as nothing changed"
else
  bad "a record naming no inputs authorised the cycle (rc=$rc). A loop over zero input lines reports agreement having compared nothing, which is the silent pass the input binding exists to remove"
fi

# --- Part G8: a THIRD HAND is refused ---------------------------------------------------------
# One property from Part G6: the same script, changed after the record, but to content that is
# neither what was recorded nor what this pull ships. A reader that accepted G6 by dropping the
# comparison altogether accepts this too, and only the pair can tell the two readers apart.
gin_restore
gin_seed_clean 220
printf '%s\n' 'neither the recorded content nor what the pull ships' > "$GCONS/$GIN_CHANGED"
ERRG8="$GCONS/err-g8.txt"
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>"$ERRG8"
rc=$?
LG8="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG8" ] && grep -qF "GATE-RECORD: INPUT-MOVED $GIN_CHANGED" "$LG8"; then
  ok "a gating script holding content that is NEITHER the recorded digest NOR what the pull ships is refused as INPUT-MOVED — the acceptance in Part G6 is keyed on the theirs blob, not on 'something changed'"
else
  bad "a third hand edited a file the verdict READ, to content this pull does not ship, and the runner accepted the record (rc=$rc). Then Part G6 passes for a reader that stopped comparing, and the tree binding is gone"
fi
if grep -qF "AS IT NOW STANDS" "$ERRG8"; then
  ok "the remedy tells the operator to re-run the gate against the tree as it now stands, not merely that something is wrong"
else
  bad "the INPUT-MOVED refusal gave the generic missing-record remedy. The operator has a record and will read 'run the gate' as already done"
fi
gin_restore

# --- Part G9: a recorded ABSENT that is now PRESENT, with content the pull does NOT ship -------
# Absence is a recorded VALUE. The gate reads inputs that are not there — a script the hook names
# and the consumer lacks — and its verdict rests on that absence, so a file ARRIVING moves the
# verdict exactly as an edit does. The exception the slice earns is asserted in Part G17.
gin_restore
gin_seed "$(printf '# input: %s\tABSENT\tcore/scripts/gate-steady.sh\n%s' \
  "scripts/ai-dlc/appeared-since.sh" "$(sr_required_inputs "$GCONS")")" 230
mkdir -p "$GCONS/scripts/ai-dlc"
printf '%s\n' 'written after the gate ran, and not what the pull ships' \
  > "$GCONS/scripts/ai-dlc/appeared-since.sh"
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG9="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG9" ] && grep -qF "INPUT-MOVED" "$LG9" && grep -qF "appeared-since" "$LG9"; then
  ok "a path the record read as ABSENT and the consumer now holds, with content the pull does not ship, is refused — absence is a value, compared in both directions"
else
  bad "a file that appeared after the gate ran did not move the verdict (rc=$rc). A reader treating ABSENT as 'nothing to check' acquits exactly the direction where a new file arrives between the gate and the run"
fi
rm -f "$GCONS/scripts/ai-dlc/appeared-since.sh"

# --- Part G10: a recorded DIGEST whose file is now ABSENT -------------------------------------
# The mirror of G9, and the input a reader testing only "the hashes differ" cannot see: there is
# no hash to differ from once the file is gone.
gin_restore
gin_seed_clean 240
GIN_SAVED="$(cat "$GCONS/$GIN_STEADY")"
rm -f "$GCONS/$GIN_STEADY"
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG10="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG10" ] && grep -qF "INPUT-MOVED $GIN_STEADY" "$LG10"; then
  ok "a path recorded with a digest and now ABSENT from the consumer is refused — a reader comparing only two hashes has none to compare here"
else
  bad "a recorded input file was DELETED after the gate ran and the record was still accepted (rc=$rc). An absent file produces no hash, so a check spelled as 'the hashes differ' passes over it silently"
fi
printf '%s\n' "$GIN_SAVED" > "$GCONS/$GIN_STEADY"; chmod +x "$GCONS/$GIN_STEADY"

# --- Part G11: an input VALUE that is neither a digest nor ABSENT -----------------------------
# A line this reader cannot evaluate. Skipping it is a record silently authorising whatever it
# could not spell, and the skip is invisible — the run goes green with one fewer comparison.
gin_restore
gin_seed "$(printf '# input: %s\tmaybe-changed\tcore/scripts/gate-steady.sh' "$GIN_STEADY")" 250
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG11="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG11" ] && grep -qF "GATE-RECORD:" "$LG11"; then
  ok "an input value that is neither a 40-hex digest nor ABSENT is refused rather than skipped"
else
  bad "an uninterpretable input value was skipped and the record accepted (rc=$rc). A reader that continues past what it cannot spell reports agreement over a line it never evaluated, and nothing announces the missing comparison"
fi

# --- Part G14: A LATE GATE is refused, and NO DIGEST COMPARISON CAN SEE IT --------------------
# The mirror of G6 and the case that makes the whole design necessary. Run the gate AFTER the
# write and every gating script's current copy IS the incoming version, so `cur` and `new` are
# the same bytes, the differential reads OK for the one reason that means nothing, and the record
# it writes carries post-write digests that the runner then re-reads and finds in perfect
# agreement. Record and tree match exactly; the verdict is worthless.
#
# It is keyed on the RANGE instead: a digest recorded as the `theirs` blob, for a path the range
# CHANGES, says the consumer already held the incoming version when the gate ran.
gin_restore
gin_write_slice                      # the slice, written FIRST
gin_seed_clean 270                   # ...and the gate run after it, recording post-write digests
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG14="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG14" ] && grep -qF "GATE-RECORD: PRE-WRITTEN $GIN_CHANGED" "$LG14"; then
  ok "a verdict taken AFTER the slice was written is refused as PRE-WRITTEN — the gate compared the incoming script with a copy of itself, and every digest in that record agrees with the tree"
else
  bad "a gate run on the already-written tree authorised the cycle (rc=$rc). Its OK says only that the file equals itself, and no digest comparison can catch it: the record and the tree agree perfectly. The range is what separates them — recorded == theirs, on a path base..theirs changes"
fi
gin_restore

# --- Part G15: a FORGED record naming inputs of its author's choosing -------------------------
# The record cannot be trusted to declare its own coverage. A single input line satisfies any
# "at least one line" rule, so the required set is DERIVED from the consumer's own hook and the
# scripts it names — both sides of that join come from the same file, and neither is authored.
gin_restore
gin_seed "$(printf '# input: %s\t%s\t-' "$SR_PROBE_REL" "$(git hash-object "$GCONS/$SR_PROBE_REL" 2>/dev/null)")" 280
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG15="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG15" ] && grep -qF "GATE-RECORD: INPUT-MISSING" "$LG15" \
   && grep -qF "$GIN_CHANGED" "$LG15"; then
  ok "a record naming ONE input of its author's choosing is refused: the required set is derived from the consumer's own pre-push hook, and the missing gating scripts are named"
else
  bad "a forged single-line record authorised the cycle (rc=$rc). A reader that trusts the record's own input list can be satisfied by any one line — the coverage has to be derived from the hook, which is the same file the gate derives it from"
fi

# --- Part G16: a `-` row may name ONE core path, and it is the fallback hook -------------------
# Column 1 `-` means "read from the distribution", which exists for exactly one file: the
# fallback hook a consumer without its own cannot name in consumer-relative form. Left
# unconstrained it is an aim-anywhere primitive — a record could point the reader at any
# distribution file that happens to be stable and satisfy its own comparison.
gin_restore
gin_seed "$(printf -- '# input: -\t%s\tcore/scripts/machinery.sh\n%s' \
  "$(git -C "$DIST" rev-parse -q --verify "${D_THEIRS}:core/scripts/machinery.sh" 2>/dev/null)" \
  "$(sr_required_inputs "$GCONS")")" 290
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG16="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG16" ] && grep -qF "GATE-RECORD:" "$LG16" \
   && grep -qF "core/git-hooks/pre-push" "$LG16"; then
  ok "a distribution-side row naming a core path OTHER than the fallback hook is refused, and the message names the one path that spelling is for"
else
  bad "a \`-\` row naming an arbitrary distribution file was accepted (rc=$rc). That spelling exists for the fallback hook alone; unconstrained it lets a record choose which file its own comparison reads"
fi

# --- Part G17: the slice ADDING a file the pull ships is accepted ------------------------------
# The acquittal for the ABSENT direction, and it is what stops Part G9 from passing for a reader
# that refuses every arrival. A script the hook names, absent when the gate ran, present now with
# exactly the content this pull ships, is the slice — one property from G9's third-hand arrival.
gin_restore
gin_seed "$(printf '# input: %s\tABSENT\tcore/scripts/machinery.sh\n%s' \
  "scripts/ai-dlc/machinery.sh" "$(sr_required_inputs "$GCONS")")" 295
mkdir -p "$GCONS/scripts/ai-dlc"
git -C "$DIST" show "${D_THEIRS}:core/scripts/machinery.sh" > "$GCONS/scripts/ai-dlc/machinery.sh" 2>/dev/null
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG17="$(newest_glog)"
if [ "$rc" -eq 0 ] && [ -n "$LG17" ] && grep -qF "===== FIXTURE green-one =====" "$LG17" \
   && ! grep -qF "GATE-RECORD:" "$LG17"; then
  ok "a path recorded ABSENT and now holding exactly what this pull SHIPS is the slice adding it, and is accepted — G9's refusal is keyed on the content, not on the arrival"
else
  bad "the slice ADDING a file the pull ships was refused (rc=$rc). Then Part G9 passes for a reader that refuses every arrival, and a pull delivering a new gating script wedges"
fi
rm -f "$GCONS/scripts/ai-dlc/machinery.sh"

# --- Parts G18 to G21: the digest column must be LOAD-BEARING ---------------------------------
# ARM 2 accepts an input whose content is now the `theirs` blob, because that is the slice this
# cycle wrote. Taken alone that makes the RECORDED digest decorative: after the write EVERY
# gating script is at `theirs`, so a record whose digests were never read off anything passes.
# Measured on the shipped arm — an all-zero forgery naming the derived required set returned
# rc=0, against a control with one script at a third-hand blob which correctly returned rc=2.
#
# The repair is that a recorded digest differing from `now` must be a content the path actually
# CARRIED in the range: its blob at BASE, or at any commit in `base..theirs` that touches it.
# G21 is why that set is not narrowed to "the base blob" — a split stamp legitimately leaves the
# consumer holding an intermediate release's blob.
#   G18  an all-zero forgery, consumer at theirs   the arm's own subject
#   G19  a decoy digest on the `-` row             the fallback hook always matches theirs
#   G20  the honest normal order                   the acquittal, re-asserted after the narrowing
#   G21  a consumer at an INTERMEDIATE blob        the acquittal a base-only rule would refuse
GZERO=0000000000000000000000000000000000000000

# --- Part G18: a record whose digests were never read off anything ----------------------------
# The required set is NAMED in full, so arm 1 is satisfied and cannot be what refuses; every
# digest is forty zeroes. The consumer is post-slice, which is the state that makes the forgery
# work: `now` equals `theirs` for the changed script, so a bare theirs-acceptance passes it.
gin_restore
gin_write_slice
gin_seed "$(printf '# input: .githooks/pre-push\t%s\t-\n# input: %s\t%s\tcore/scripts/gate-changed.sh\n# input: %s\t%s\tcore/scripts/gate-steady.sh' \
  "$(git hash-object "$GCONS/.githooks/pre-push")" \
  "$GIN_CHANGED" "$GZERO" "$GIN_STEADY" "$GZERO")" 400
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG18="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG18" ] && grep -qF "GATE-RECORD: INPUT-MOVED $GIN_CHANGED" "$LG18" \
   && grep -qF "is not a content this path carried anywhere" "$LG18"; then
  ok "a record whose digests are content this path NEVER carried is refused, though every file is at theirs — the digest column stays load-bearing after the slice is written"
else
  bad "an all-zero-digest record naming the full required set authorised the cycle (rc=$rc). After the write every gating script IS at theirs, so accepting on that alone makes the recorded digest decorative and a forged record indistinguishable from a gate's"
fi
gin_restore

# --- Part G19: a DECOY digest on the distribution-side row ------------------------------------
# The `-` row's file is the distribution's own copy, which the reader resolves under $DIST — so
# `now` equals the theirs blob by construction on every run, and a theirs-acceptance there would
# accept any digest at all. The slice never writes that file, so strict equality costs nothing.
# The consumer here has NO hook of its own, which is the only state that produces a `-` row.
GH="$(bash "$HERE/seed.sh")"
rm -rf "$GH/.githooks"
GHLOG="$GH/_bmad-output/ai-dlc-update"
mkdir -p "$GHLOG"
SR_INPUTS="$(printf -- '# input: -\t%s\tcore/git-hooks/pre-push\n# input: %s\tABSENT\tcore/scripts/machinery.sh' \
  "$GZERO" "scripts/ai-dlc/machinery.sh")" \
  seed_record "$GHLOG" "$DIST" "$D_BASE" "$D_THEIRS" OK 410 >/dev/null \
  || bad "FIXTURE ERROR: could not seed Part G19's decoy record"
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GH" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG19="$(ls -t "$GHLOG"/self-update-fixtures-*.md 2>/dev/null | head -1)"
if [ "$rc" -eq 2 ] && [ -n "$LG19" ] && grep -qF "INPUT-MOVED" "$LG19" \
   && grep -qF "distribution fallback hook" "$LG19"; then
  ok "a decoy digest on the distribution-side row is refused: that row is compared STRICTLY, because its file is the one the reader itself resolves"
else
  bad "a decoy digest on the \`-\` row was accepted (rc=$rc). The fallback hook's file IS the distribution's copy, so it equals the theirs blob on every run — a theirs-acceptance there accepts forty zeroes as readily as a real digest"
fi
# The ACQUITTAL for the same row, one property apart: the true digest must pass, or the arm
# above would be satisfied by a reader that refuses every `-` row.
SR_INPUTS="$(printf -- '# input: -\t%s\tcore/git-hooks/pre-push\n# input: %s\tABSENT\tcore/scripts/machinery.sh' \
  "$(git hash-object "$DIST/core/git-hooks/pre-push" 2>/dev/null)" "scripts/ai-dlc/machinery.sh")" \
  seed_record "$GHLOG" "$DIST" "$D_BASE" "$D_THEIRS" OK 411 >/dev/null
rm -f "$GHLOG"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GH" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG19B="$(ls -t "$GHLOG"/self-update-fixtures-*.md 2>/dev/null | head -1)"
if [ "$rc" -eq 0 ] && [ -n "$LG19B" ] && grep -qF "===== FIXTURE green-one =====" "$LG19B"; then
  ok "...and the row's TRUE digest is accepted, so the refusal above is about the digest and not about the \`-\` spelling"
else
  bad "the distribution-side row was refused with its true digest (rc=$rc). A consumer with no hook of its own would then be refused on every self-update, forever"
fi
rm -rf "$GH"

# --- Part G20: the honest normal order still passes, after the narrowing ----------------------
# Re-asserted here rather than left to Part G6 because the conjunct added for G18 is the one
# thing that could refuse it: the recorded digest is the pre-write content, which must be found
# in the range's history for this path.
gin_restore
gin_seed_clean 420
gin_write_slice
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG20="$(newest_glog)"
if [ "$rc" -eq 0 ] && [ -n "$LG20" ] && grep -qF "===== FIXTURE green-one =====" "$LG20" \
   && ! grep -qF "GATE-RECORD:" "$LG20"; then
  ok "the honest normal order still passes with the carried-content conjunct in place — the pre-write digest IS a content the path carried at base"
else
  bad "the narrowing added for Part G18 refused the legitimate flow (rc=$rc): $(grep -m1 '^GATE-RECORD:' "$LG20" 2>/dev/null | cut -c1-150). A conjunct that refuses the honest case wedges every self-update, which is worse than the forgery it prevents"
fi
gin_restore

# --- Part G21: a consumer holding an INTERMEDIATE release's blob ------------------------------
# The acquittal a base-only rule would refuse, and the reason the carried-content set is derived
# from `git log` rather than from BASE alone. A split stamp — `skill_commit` ahead of `commit` —
# leaves the consumer at some release BETWEEN base and theirs, which is the normal state after
# any self-update and one this cycle itself creates. Its own three-commit distribution, because
# the shared one has no intermediate commit touching a gating script.
I_D="$(mktemp -d)"
IG(){ git -C "$I_D" -c user.name=ai-dlc-fixture -c user.email=fixture@invalid \
                    -c commit.gpgsign=false "$@"; }
iput(){ mkdir -p "$(dirname "$I_D/$1")" && printf '%s\n' "$2" > "$I_D/$1"; }
git -c init.templateDir= init -q -b main "$I_D" >/dev/null 2>&1 \
  || git -c init.templateDir= init -q "$I_D" >/dev/null 2>&1
iput "core/fixtures/probe/run.sh" 'exit 0'
iput "core/scripts/gate-changed.sh" 'gate-changed at base'
iput "core/skills/ai-dlc-update/reconcile/self-update-gate.sh" 'a gate that records nothing'
IG add -A >/dev/null 2>&1; IG commit -q --no-verify -m base >/dev/null 2>&1
I_B="$(IG rev-parse HEAD 2>/dev/null)"
iput "core/scripts/gate-changed.sh" 'gate-changed at MID'
IG add -A >/dev/null 2>&1; IG commit -q --no-verify -m mid >/dev/null 2>&1
I_M="$(IG rev-parse HEAD 2>/dev/null)"
iput "core/scripts/gate-changed.sh" 'gate-changed at theirs'
IG add -A >/dev/null 2>&1; IG commit -q --no-verify -m theirs >/dev/null 2>&1
I_T="$(IG rev-parse HEAD 2>/dev/null)"
I_MB="$(IG rev-parse -q --verify "${I_M}:core/scripts/gate-changed.sh" 2>/dev/null)"
I_BB="$(IG rev-parse -q --verify "${I_B}:core/scripts/gate-changed.sh" 2>/dev/null)"
I_TB="$(IG rev-parse -q --verify "${I_T}:core/scripts/gate-changed.sh" 2>/dev/null)"
# THE SEED IS ASSERTED TO DISCRIMINATE. Three distinct blobs are what make "carried in the
# range" and "equals the base blob" different answers; where mid equals base or theirs the arm
# below passes for either implementation.
if [ -n "$I_MB" ] && [ "$I_MB" != "$I_BB" ] && [ "$I_MB" != "$I_TB" ]; then
  ok "SEED: the intermediate release's blob differs from BOTH base and theirs, so 'carried anywhere in the range' and 'equals the base blob' give different answers"
else
  bad "FIXTURE ERROR: the intermediate seed's three blobs are not distinct (base ${I_BB:-none}, mid ${I_MB:-none}, theirs ${I_TB:-none}). Part G21 would then pass for a base-only rule and the narrowing is untested"
fi
I_K="$(mktemp -d)"
mkdir -p "$I_K/_bmad-output/ai-dlc-update" "$I_K/tests/fixtures/probe" "$I_K/.githooks" "$I_K/scripts/ai-dlc"
printf 'exit 0\n' > "$I_K/tests/fixtures/probe/run.sh"
printf 'bash scripts/ai-dlc/gate-changed.sh\n' > "$I_K/.githooks/pre-push"
# The consumer sits at MID when the gate runs — the split-stamp state.
IG show "${I_M}:core/scripts/gate-changed.sh" > "$I_K/scripts/ai-dlc/gate-changed.sh" 2>/dev/null
printf '# base-sha: %s\n# theirs-sha: %s\n# input: .githooks/pre-push\t%s\t-\n# input: scripts/ai-dlc/gate-changed.sh\t%s\tcore/scripts/gate-changed.sh\n\n# verdict: OK\n' \
  "$I_B" "$I_T" "$(git hash-object "$I_K/.githooks/pre-push")" "$I_MB" \
  > "$I_K/_bmad-output/ai-dlc-update/self-update-gate-19700101T000000Z.md"
# ...and then the slice is written, exactly as step 2 writes it.
IG show "${I_T}:core/scripts/gate-changed.sh" > "$I_K/scripts/ai-dlc/gate-changed.sh" 2>/dev/null
bash "$RUNNER" "$I_D" "$I_B" "$I_T" "$I_K" probe >/dev/null 2>&1
rc=$?
LG21="$(ls -t "$I_K"/_bmad-output/ai-dlc-update/self-update-fixtures-*.md 2>/dev/null | head -1)"
if [ "$rc" -eq 0 ] && [ -n "$LG21" ] && ! grep -qF "GATE-RECORD:" "$LG21"; then
  ok "a consumer whose pre-write copy was an INTERMEDIATE release's blob is accepted — the carried-content set is every blob the path held in the range, not the base blob alone"
else
  bad "a split-stamp consumer at an intermediate release's blob was refused (rc=$rc): $(grep -m1 '^GATE-RECORD:' "$LG21" 2>/dev/null | cut -c1-150). That is the normal state after any self-update and one this cycle itself creates, so narrowing the accepted set to the base blob wedges those consumers"
fi

# --- Part G22: a base gate that DECLARES the record directory and never writes ----------------
# ARM 4's token has to spell the WRITE, not an assignment. Keyed on `GATE_REC_DIR` it scores 1
# on a locally patched old gate that declares the variable and never writes — converting a local
# edit into a refusal whose message says the records were deleted. The composed filename cannot
# be present without the write.
gin_restore
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_BASE_DECL" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG22="$(newest_glog)"
if [ "$rc" -eq 0 ] && [ -n "$LG22" ] && grep -qF "GATE-RECORD: NOT-REQUIRED" "$LG22"; then
  ok "a base gate that DECLARES the record directory and never writes is read as non-recording — the token spells the write site, not an assignment"
else
  bad "a gate declaring GATE_REC_DIR without writing was read as a recording gate (rc=$rc), so an empty directory becomes a refusal saying the records were deleted. A local edit that adds the variable then wedges the consumer with a message about a state that never happened"
fi

# --- Parts G12 and G13: the DELIVERY-PULL tolerance, and the state it must NOT cover -----------
# A fix to a bootstrapping step can never be delivered by that step. On the pull that DELIVERS
# this requirement the OLD gate runs and records nothing, the slice installs this runner, and a
# hard refusal blocks the self-update carrying the fixed gate — with step 2 requiring green
# before the push, that pull can never land. Measured on the reference consumer: 69 of 87
# self-update commits wrote some `reconcile/` file and 3 wrote this runner, against a control of
# 0 of 87 for an impossible path.
#
# THE EXEMPTION IS KEYED ON THE GATE THE CONSUMER HAD, READ FROM THE DISTRIBUTION AT BASE — not
# on the record directory being empty, which `rm -f` reaches at will. G13 is the probe that it
# does not cover the arm's own subject.

# --- Part G12: no record, and the gate at BASE could not have recorded -------------------------
# `$D_BASE`'s gate carries no record-writing site, so this is the delivery pull.
gin_restore
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
ERRG12="$GCONS/err-g12.txt"
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>"$ERRG12"
rc=$?
LG12="$(newest_glog)"
if [ "$rc" -eq 0 ] && [ -n "$LG12" ] && grep -qF "GATE-RECORD: NOT-REQUIRED" "$LG12" \
   && grep -qF "===== FIXTURE green-one =====" "$LG12"; then
  ok "no record, and the gate at BASE carries no record-writing site: the run proceeds with NOT-REQUIRED — the pull that delivers recording can still land"
else
  bad "a consumer whose installed gate could not have recorded was refused (rc=$rc). The old gate writes no record, so this is the state of the very pull that installs the recording one; refusing it means the fix can never be delivered by the step that delivers it"
fi
if grep -qF "NOT-REQUIRED" "$ERRG12"; then
  ok "the tolerance is announced on stderr too, so a green run does not silently omit the check"
else
  bad "the run proceeded on the tolerance and said so only in the log. A skipped requirement that reports nothing to the operator's channel reads exactly like one that passed"
fi

# --- Part G13a: records DELETED, with a RECORDING gate at base, still refuses ------------------
# The input an emptiness test cannot see, and the one the adversary reached with `rm -f`. Same
# empty directory as Part G12; the only thing different is which gate the consumer had, which is
# read out of the distribution where a deletion on the consumer cannot touch it.
gin_restore
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_BASE_REC" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG13A="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG13A" ] && grep -qF "GATE-RECORD: MISSING" "$LG13A" \
   && ! grep -qF "NOT-REQUIRED" "$LG13A"; then
  ok "an EMPTY record directory with a RECORDING gate at base is refused as MISSING — the tolerance reads which gate the consumer had, not whether the directory happens to be empty"
else
  bad "deleting the records reached the tolerance (rc=$rc). \`rm -f self-update-gate-*.md\` is then the whole bypass, and the requirement is advisory for anyone willing to run it"
fi

# --- Part G13b: ONE record, for a DIFFERENT range, still refuses ------------------------------
# A consumer that HAS recorded a verdict, just not for this range. That is the ordinary
# post-first-cycle state, and an exemption widened to "no record for THIS range" acquits all of them.
gin_restore
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
seed_record "$GLOG" "$DIST" "$D_QUIET" "$D_SHIP" OK 260 >/dev/null \
  || bad "FIXTURE ERROR: could not seed Part G13b's wrong-range record"
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG13="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG13" ] && grep -qF "GATE-RECORD:" "$LG13" \
   && ! grep -qF "NOT-REQUIRED" "$LG13"; then
  ok "with ONE record present, for a DIFFERENT range, the requirement still binds — the tolerance covers a consumer whose gate could not record, not a range that has not been classified"
else
  bad "a consumer holding a record for another range was let through on the delivery-pull tolerance (rc=$rc). That is the ordinary state after the first cycle, so this widening acquits every subsequent self-update and the exemption defends the defect the arm exists for"
fi

# --- MUTATION: prove the arms above can fail -----------------------------------------------
# The runner sources nothing from its own directory, so a lone copy is a working harness here
# — but the copies are still taken beside the original and checked with an unmutated control,
# because "the mutant emitted nothing" and "the mutant survived" are the same bytes.
MUTDIR="$(mktemp -d)"; trap 'rm -rf "$CONS" "$CONS2" "$DIST" "$WREPO" "$MUTDIR"' EXIT
cp "$RECONCILE"/*.sh "$MUTDIR"/ 2>/dev/null
CTL="$MUTDIR/control-unmutated.sh"; cp "$RUNNER" "$CTL"

# Every mutation is a copy, and the anchor must occur EXACTLY once. A `replace(...,1)` against
# an anchor that has moved edits nothing and comes back green, and one against an anchor that
# has become ambiguous edits the wrong site — both are mutants that prove nothing, and both
# read as a passing battery.
mkmutant() { # $1=dest $2=old $3=new
  MUT_OLD="$2" MUT_NEW="$3" python3 -c 'import os,sys
s = open(sys.argv[1]).read()
old, new = os.environ["MUT_OLD"], os.environ["MUT_NEW"]
if s.count(old) != 1: sys.exit(3)
open(sys.argv[2], "w").write(s.replace(old, new, 1))' "$RUNNER" "$1" 2>/dev/null || return 1
  [ -s "$1" ] && ! cmp -s "$RUNNER" "$1"
}

# A TWO-LAYER revert, for a state two guards independently refuse. A partial revert leaves a
# mutant that proves whichever layer was left in place, and it comes out green — so where a
# second guard covers the first, both come off in one copy and the arm scores the pair. The
# second anchor is counted AFTER the first substitution, so an edit that makes it ambiguous is
# a refusal rather than a silent wrong-site replacement.
mkmutant2() { # $1=dest $2=old1 $3=new1 $4=old2 $5=new2
  MUT_O1="$2" MUT_N1="$3" MUT_O2="$4" MUT_N2="$5" python3 -c 'import os,sys
s = open(sys.argv[1]).read()
for o, n in ((os.environ["MUT_O1"], os.environ["MUT_N1"]),
             (os.environ["MUT_O2"], os.environ["MUT_N2"])):
    if s.count(o) != 1: sys.exit(3)
    s = s.replace(o, n, 1)
open(sys.argv[2], "w").write(s)' "$RUNNER" "$1" 2>/dev/null || return 1
  [ -s "$1" ] && ! cmp -s "$RUNNER" "$1"
}

# --- CONTROL --------------------------------------------------------------------------------
# Two arms, and the second one is why the first is not enough: an rc=2-and-nothing-reported
# control passes against a subject replaced by `exit 0`, because that is exactly what a clean
# copy looks like. The green arm demands a baseline row be THERE.
bash "$CTL" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" >/dev/null 2>&1
if [ $? -eq 2 ]; then
  ok "CONTROL: the unmutated copy still exits 2 on an empty set — the mutant verdicts below are their edits"
else
  bad "FIXTURE ERROR: the unmutated copy did not exit 2 on an empty set, so the copied harness is what is being measured"
fi
rm -f "$LOGDIR2"/self-update-fixtures-*.md
bash "$CTL" "$DIST" "$D_QUIET" "$D_SHIP" "$CONS2" touched-shippable green-one >/dev/null 2>&1
rc=$?
LC="$(newest_log2)"
if [ "$rc" -eq 0 ] && [ -n "$LC" ] && grep -qF "===== FIXTURE green-one =====" "$LC"; then
  ok "CONTROL: the unmutated copy runs the named fixtures and writes their sections — a copy that emitted nothing would fail here rather than score as a kill"
else
  bad "FIXTURE ERROR: the unmutated copy did not produce a green run with a green-one section (rc=$rc). Every kill below would be the copied harness dying, not the mutation"
fi

# --- MUTANT 0: the empty-set guard returns 0 ------------------------------------------------
M0="$MUTDIR/m0-emptyset-green.sh"
if mkmutant "$M0" '  exit 2
fi

SELF=' '  exit 0
fi

SELF='; then
  bash "$M0" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    ok "MUTATION — with the empty-set guard returning 0, naming nothing reads as a green suite: Part 4 is what catches that"
  else
    bad "MUTATION — the empty-set guard was neutered and the runner still refused; Part 4's assertion is vacuous"
  fi
else
  bad "FIXTURE ERROR: the empty-set anchor no longer occurs exactly once in the runner — Part 4 proves nothing. Re-anchor it on the runner's real empty-set guard"
fi

# --- Part 20: A BLOB-FILTERED $DIST MUST NOT CONVICT A CORRECT SET ---------------------------
# `git cat-file -e <rev>:<path>` requires the BLOB OBJECT locally. On a `--filter=blob:none`
# clone whose promisor is unreachable it answers ABSENT for a path that exists, so BOTH probes
# fail: the over-completeness arm convicts every named directory, and the under-completeness
# join silently reports nothing having compared nothing. `rev-parse -q --verify` resolves through
# the TREE and needs no blob.
#
# THE GUARDS ABOVE CANNOT COVER THIS, WHICH IS WHY IT NEEDS ITS OWN ARM. `${THEIRS}:core/fixtures`
# is a TREE, and trees are not filtered — it resolves fine, so both the ref-resolution loop and
# the wrong-repo guard pass and hand the arm a repo it cannot read.
#
# BOTH DIRECTIONS, ONE RUN, and the probe is only believed once it is shown to DISCRIMINATE: the
# arm below refuses to score unless the filtered clone is genuinely missing objects and the two
# spellings disagree on a path that exists while agreeing on one that does not.
# PART 20 BUILDS ITS OWN SOURCE REPO RATHER THAN CLONING `$DIST`, and the reason is a null this
# arm produced on its first run. Git blobs are CONTENT-ADDRESSED, and `$DIST`'s seed writes the
# same two strings into every file — so every historical blob collapses onto an object the
# checkout already holds, a filtered clone is missing nothing, and the arm correctly reported
# SKIP. Here every version of every file is UNIQUE, so the base-side blobs are genuinely absent
# from a `blob:none` checkout and the two spellings can disagree.
FILT_ROOT="$(mktemp -d)"
FILT_SRC="$FILT_ROOT/src"
FILT_SRV="$FILT_ROOT/src.git"
FILT="$FILT_ROOT/filtered-dist"
(
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
  git -c init.templateDir= init -q -b main "$FILT_SRC" >/dev/null 2>&1 \
    || git -c init.templateDir= init -q "$FILT_SRC" >/dev/null 2>&1
  # Assert the probe repo is its own before the first write — `GIT_DIR` outranks `git -C`, and a
  # stray one has committed into the real repository from a fixture before. Compared against the
  # SYMLINK-RESOLVED path: `mktemp -d` hands back `/var/folders/...` on this platform while
  # `--absolute-git-dir` answers `/private/var/folders/...`, so a literal compare fails on a
  # correct repo and silently skips the whole arm — which is how this one first read as
  # "could not build a clone".
  [ "$(git -C "$FILT_SRC" rev-parse --absolute-git-dir 2>/dev/null)" \
    = "$(cd "$FILT_SRC" && pwd -P)/.git" ] || exit 1
  FG() { git -C "$FILT_SRC" -c user.name=ai-dlc-fixture -c user.email=fixture@invalid \
                            -c commit.gpgsign=false "$@"; }
  for f in keeper mover; do
    mkdir -p "$FILT_SRC/core/fixtures/$f"
    printf 'unique-base-%s-aaaaaaaaaaaaaaaaaaaaaaaa\n' "$f" > "$FILT_SRC/core/fixtures/$f/run.sh"
  done
  mkdir -p "$FILT_SRC/core/scripts"
  printf 'unique-base-machinery-bbbbbbbbbbbbbbbb\n' > "$FILT_SRC/core/scripts/machinery.sh"
  FG add -A >/dev/null 2>&1; FG commit -q --no-verify -m base >/dev/null 2>&1
  for f in keeper mover; do
    printf 'unique-theirs-%s-cccccccccccccccccccccccc\n' "$f" > "$FILT_SRC/core/fixtures/$f/run.sh"
  done
  printf 'unique-theirs-machinery-dddddddddddddddd\n' > "$FILT_SRC/core/scripts/machinery.sh"
  FG add -A >/dev/null 2>&1; FG commit -q --no-verify -m theirs >/dev/null 2>&1
  FG tag filt-theirs >/dev/null 2>&1
  # A FOURTH commit that moves the fixtures AGAIN, and it is what makes the arm discriminate.
  # A `blob:none` clone still holds every blob its CHECKOUT needs, so if `filt-theirs` were the
  # tip its fixture blobs would be present and `cat-file -e` would answer correctly — the arm
  # would pass against its own mutant. Measured: the first version of this seed did exactly
  # that. With HEAD moved past it, the blobs at `filt-theirs` are genuinely filtered out.
  for f in keeper mover; do
    printf 'unique-final-%s-ffffffffffffffffffffffff\n' "$f" > "$FILT_SRC/core/fixtures/$f/run.sh"
  done
  printf 'unique-final-machinery-eeeeeeeeeeeeeeee\n' > "$FILT_SRC/core/scripts/machinery.sh"
  FG add -A >/dev/null 2>&1; FG commit -q --no-verify -m final >/dev/null 2>&1
  git clone --quiet --bare "$FILT_SRC" "$FILT_SRV" >/dev/null 2>&1
  git -C "$FILT_SRV" config uploadpack.allowFilter true
  git clone --quiet --no-local --filter=blob:none "file://$FILT_SRV" "$FILT" >/dev/null 2>&1
) >/dev/null 2>&1
if [ -d "$FILT/.git" ]; then
  # The promisor is moved away, which is what makes the clone genuinely OFFLINE. Without this
  # every probe lazily refetches, the two spellings agree, and the null reads as a pass.
  mv "$FILT_SRV" "${FILT_SRV}.gone" 2>/dev/null
  f_base="$(git -C "$FILT" rev-parse -q --verify filt-theirs^ 2>/dev/null)"
  f_missing="$(git -C "$FILT" rev-list --objects --all --missing=print 2>/dev/null | grep -c '^?')"
  f_cat="$(git -C "$FILT" cat-file -e "${f_base}:core/fixtures/keeper/run.sh" 2>/dev/null && echo present || echo ABSENT)"
  f_rev="$(git -C "$FILT" rev-parse -q --verify "${f_base}:core/fixtures/keeper/run.sh" >/dev/null 2>&1 && echo present || echo ABSENT)"
  f_ctl="$(git -C "$FILT" rev-parse -q --verify "${f_base}:core/fixtures/zzz-no-such/run.sh" >/dev/null 2>&1 && echo present || echo ABSENT)"
  # The filtered clone is a FIFTH range, in a repo built inside this block, so `seed_ranges`
  # above could not have covered it: the runner refuses any range with no recorded OK, and every
  # run below would exit 2 on that before reaching a probe.
  seed_record "$LOGDIR2" "$FILT" "${f_base:-HEAD}" filt-theirs OK 030 >/dev/null 2>&1
  if [ -z "$f_base" ] || [ "$f_missing" -eq 0 ] || [ "$f_cat" != ABSENT ] \
     || [ "$f_rev" != present ] || [ "$f_ctl" != ABSENT ]; then
    ok "SKIP: this git/transport did not produce a DISCRIMINATING blob-filtered clone (missing=$f_missing, cat-file=$f_cat, rev-parse=$f_rev, control=$f_ctl) — reporting that rather than scoring a null the probe could not have failed"
  else
    # The OVER arm. `theirs` is the HISTORICAL `filt-theirs`, never the tip: the named set is
    # wholly shippable there, and its blobs are the ones the filter left out. Both dirs are named,
    # so the under-completeness join is satisfied and this run scores the over-arm alone.
    rm -f "$LOGDIR2"/self-update-fixtures-*.md
    bash "$RUNNER" "$FILT" "$f_base" filt-theirs "$CONS2" keeper mover >/dev/null 2>&1
    rc=$?
    if [ "$rc" -ne 2 ] || [ -z "$(uns_set "$(newest_log2)")" ]; then
      ok "a blob-filtered \$DIST does not convict a correct set — the probes resolve through the TREE, and a filtered blob is not a missing path"
    else
      bad "a blob-filtered \$DIST convicted a wholly shippable set (rc=$rc, refused '$(uns_set "$(newest_log2)")'). The probes are reading BLOBS: \`cat-file -e\` answers ABSENT for a filtered object and the arm indicts correct input"
    fi
    # ...and the UNDER-completeness join must still find its subject on the same clone. There the
    # same defect is SILENT: both exemption probes fail, every diff-touched dir takes `|| continue`,
    # `uncovered` stays empty, and the join reports nothing having compared nothing.
    rm -f "$LOGDIR2"/self-update-fixtures-*.md
    bash "$RUNNER" "$FILT" "$f_base" filt-theirs "$CONS2" keeper >/dev/null 2>&1
    if [ "$(cov_set "$(newest_log2)")" = "mover," ]; then
      ok "...and on the same clone the under-completeness join still names its subject — the silent half of the same defect is repaired too"
    else
      bad "on a blob-filtered \$DIST the under-completeness join reported '$(cov_set "$(newest_log2)")' instead of 'mover,'. Its exemption probes are reading BLOBS, so every diff-touched dir is skipped and an incomplete set passes over an empty comparison"
    fi

    # MUTANT 15, scored HERE because the clone it needs is alive only inside this block. Both
    # arms above are the shape `fixture-mutants.md` warns about — one asserts an acquittal and
    # the other a presence, and a subject that emits nothing would satisfy the first. This is
    # what makes them load-bearing: put the blob-reading spelling back at all four probe sites.
    #
    # `mkmutant` writes into `$MUTDIR`, which already holds the reconcile siblings. A copy made
    # anywhere else cannot load `map_consumer()` out of `preclassify.sh` and exits 2 as a
    # REFUSAL — measured while building this arm, and it scored as a kill for both halves while
    # the mutation itself was never executed.
    M15="$MUTDIR/m15-probe-reads-the-blob.sh"
    MUT_N=0
    MUT_N="$(python3 -c 'import re,sys
s = open(sys.argv[1]).read()
pat = r"git -C \"\$DIST\" rev-parse -q --verify \"\$\{THEIRS\}:core/fixtures/([^\"]+)\" >/dev/null 2>&1"
out, n = re.subn(pat, lambda m: "git -C \"$DIST\" cat-file -e \"${THEIRS}:core/fixtures/" + m.group(1) + "\" 2>/dev/null", s)
open(sys.argv[2], "w").write(out)
print(n)' "$RUNNER" "$M15" 2>/dev/null || echo 0)"
    if [ "${MUT_N:-0}" -ne 4 ] || cmp -s "$RUNNER" "$M15"; then
      bad "FIXTURE ERROR: expected 4 tree-resolving probe sites to mutate, moved ${MUT_N:-0} — Part 20 proves nothing"
    else
      rm -f "$LOGDIR2"/self-update-fixtures-*.md
      bash "$M15" "$FILT" "$f_base" filt-theirs "$CONS2" keeper mover >/dev/null 2>&1
      m_over="$(uns_set "$(newest_log2)")"
      rm -f "$LOGDIR2"/self-update-fixtures-*.md
      bash "$M15" "$FILT" "$f_base" filt-theirs "$CONS2" keeper >/dev/null 2>&1
      m_under="$(cov_set "$(newest_log2)")"
      if [ "$m_over" = "keeper,mover," ] && [ -z "$m_under" ]; then
        ok "MUTATION — reading the BLOB instead of the tree convicts the whole correct set (keeper,mover) AND silences the under-completeness join on the same clone: both halves of Part 20 are what catch that"
      else
        bad "MUTATION — the probes were reverted to \`cat-file -e\` and Part 20 did not see it (over refused '$m_over', expected 'keeper,mover,'; under reported '$m_under', expected empty). One or both halves are asserting something no mutation can move"
      fi
    fi
  fi
  rm -rf "$FILT_ROOT"
else
  rm -rf "$FILT_ROOT"
  ok "SKIP: could not build a blob-filtered clone here — reporting that rather than scoring a null"
fi

# --- MUTANT 1: the .dist-only exemption inverted ---------------------------------------------
M1="$MUTDIR/m1-exemption-inverted.sh"
if mkmutant "$M1" 'core/fixtures/${d}/.dist-only" >/dev/null 2>&1 && continue' \
                  'core/fixtures/${d}/.dist-only" >/dev/null 2>&1 || true'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M1" "$DIST" "$D_BASE" theirs-tag "$CONS2" touched-named green-one >/dev/null 2>&1
  if [ "$(cov_set "$(newest_log2)")" = "touched-distonly,touched-shippable," ]; then
    ok "MUTATION — with the .dist-only exemption inverted a never-shipped fixture joins the refusal: Part 7's set equality is what catches that"
  else
    bad "MUTATION — the .dist-only exemption was inverted and the refusal list did not change. Part 7 asserts an exemption no run can move, so the exemption is untested"
  fi
else
  bad "FIXTURE ERROR: the .dist-only exemption anchor no longer occurs exactly once in the runner — the exemption half of Part 7 proves nothing"
fi

# --- MUTANT 2: the coverage join deleted outright --------------------------------------------
# The block is excised rather than edited, because a partial revert leaves a mutant that proves
# whichever layer was left in place.
M2="$MUTDIR/m2-coverage-deleted.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a, b = s.index("# --- The COVERAGE join"), s.index("n_run=0; n_ok=0")
open(sys.argv[2], "w").write(s[:a] + s[b:])' "$RUNNER" "$M2" 2>/dev/null
if [ -s "$M2" ] && ! cmp -s "$RUNNER" "$M2"; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M2" "$DIST" "$D_BASE" theirs-tag "$CONS2" touched-named green-one >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && ! grep -qF "COVERAGE:" "$LM"; then
    ok "MUTATION — with the whole coverage join removed the incomplete slice runs green: Part 7 is what catches that"
  else
    bad "MUTATION — the coverage join was removed and the incomplete slice was still refused (rc=$rc). Something else is producing Part 7's verdict"
  fi
else
  bad "FIXTURE ERROR: the coverage block could not be excised — its start or end anchor has moved, and Part 7 proves nothing"
fi

# --- MUTANT 3: the coverage join moved AFTER the fixture loop ---------------------------------
# A placement mutant, and the reason Part 7 asserts on ordering rather than on the verdict: this
# copy still refuses, with the same list, having already run and reported every fixture first.
M3="$MUTDIR/m3-coverage-after-loop.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a, b = s.index("# --- The COVERAGE join"), s.index("n_run=0; n_ok=0")
blk, t = s[a:b], s[:a] + s[b:]
c = t.index("{\n  echo \"# summary:")
open(sys.argv[2], "w").write(t[:c] + blk + t[c:])' "$RUNNER" "$M3" 2>/dev/null
if [ -s "$M3" ] && ! cmp -s "$RUNNER" "$M3" && ! cmp -s "$M2" "$M3"; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M3" "$DIST" "$D_BASE" theirs-tag "$CONS2" touched-named green-one >"$CONS2/out-m3.txt" 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 2 ] && [ -n "$LM" ] && grep -qF "COVERAGE: the diff changes" "$LM" \
     && grep -qF "===== FIXTURE green-one =====" "$LM"; then
    ok "MUTATION — moved below the loop the join still refuses with the same list, having reported every fixture first: only Part 7's ordering arm sees it"
  else
    bad "MUTATION — the join was moved after the fixture loop and Part 7's ordering arm did not fire (rc=$rc). An arm that cannot tell before from after is asserting the verdict twice"
  fi
else
  bad "FIXTURE ERROR: the coverage block could not be relocated — an anchor has moved, or the relocated copy is byte-identical to the deleted one, and the ordering arm proves nothing"
fi

# --- MUTANT 4: the ref-resolution loop neutered ------------------------------------------------
# `&& continue` becomes `; continue`, so every ref is accepted. On a BOGUS ref this changes
# almost nothing — the diff-failure arm underneath still exits 2 — which is why the mutant is
# scored on Part 12's input instead: `git diff <tree> <commit>` succeeds, so that arm never fires
# either, and the loop's peel to `^{commit}` is the only thing standing between a base that names
# no commit and a join taken over whatever fell out.
#
# SCORED ON THE MESSAGE AND NOT ON THE EXIT CODE, AND THE REASON IS A SECOND GUARD DOWNSTREAM.
# The gate-record arm peels both refs too, so an unpeelable base now reaches it and is refused
# there as an unidentifiable range — the copy still exits 2, and an arm reading the code alone
# would score a kill for a loop it never reached. That is the shape Parts 18 and 19 already own
# from the other side: an arm hoisted above a guard makes the guard unreachable, and which arm
# ANSWERS is the property, not whether something did. So the pair is asserted — the unmutated
# copy records UNRESOLVABLE for this input and the mutant does not — with the mutant's own
# refusal read as the control that says it RAN. Parts 10 to 12 key on the same message for the
# same reason.
M4="$MUTDIR/m4-refcheck-neutered.sh"
if mkmutant "$M4" 'rev-parse --verify --quiet "${r}^{commit}" >/dev/null 2>&1 && continue' \
                  'rev-parse --verify --quiet "${r}^{commit}" >/dev/null 2>&1; continue'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M4" "$DIST" "$D_TREE" theirs-tag "$CONS2" green-one >/dev/null 2>&1
  rc=$?
  LM4="$(newest_log2)"
  m4_mut_unres=1; { [ -n "$LM4" ] && grep -qF "COVERAGE: UNRESOLVABLE" "$LM4"; } || m4_mut_unres=0
  m4_mut_said=0; { [ -n "$LM4" ] && grep -qE "^(COVERAGE|GATE-RECORD):" "$LM4"; } && m4_mut_said=1
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$CTL" "$DIST" "$D_TREE" theirs-tag "$CONS2" green-one >/dev/null 2>&1
  LM4C="$(newest_log2)"
  m4_ctl_unres=0; { [ -n "$LM4C" ] && grep -qF "COVERAGE: UNRESOLVABLE" "$LM4C"; } && m4_ctl_unres=1
  if [ "$m4_ctl_unres" -eq 1 ] && [ "$m4_mut_unres" -eq 0 ] && [ "$m4_mut_said" -eq 1 ]; then
    ok "MUTATION — with the ref peel removed a base that names a TREE stops being reported as UNRESOLVABLE (the unmutated copy reports it on the same input, and the mutant still writes a log, so it ran): Part 12 is what catches that"
  else
    bad "MUTATION — the ref-resolution loop was neutered and Part 12's message did not move (unmutated UNRESOLVABLE=$m4_ctl_unres expected 1, mutant UNRESOLVABLE=$m4_mut_unres expected 0, mutant wrote a finding=$m4_mut_said expected 1). Either Part 12's input does not reach that loop, or the copy emitted nothing and its silence was about to score as a kill"
  fi
else
  bad "FIXTURE ERROR: the ref-resolution anchor no longer occurs exactly once in the runner — Parts 10 to 12 prove nothing"
fi

# --- MUTANT 5: the distribution check neutered ------------------------------------------------
# `if ! git cat-file -e ...` becomes `if false`, so any git repo is accepted. Part 13 is
# absence-shaped without this: the arm asks for a refusal, and a subject that refuses nothing
# at all — including one replaced by `exit 0` — is exactly what a wrong repo looks like once
# the guard is gone. The copy reports a GREEN SUITE over a checkout holding no fixtures.
#
# TWO LAYERS COME OFF, because a second guard now covers this one. The over-completeness arm
# below also refuses a wrong repo — every `cat-file -e` at a theirs with no `core/fixtures`
# tree fails, so it convicts the whole named set — and with the distribution check alone
# removed this copy would still exit 2, scoring a kill for a guard that had not been reached.
# Removing only the emission keeps the arm's own logic intact and reverts exactly the covering
# layer. Which of the two SHOULD answer is Part 19's subject, not this one's.
M5="$MUTDIR/m5-distcheck-neutered.sh"
if mkmutant2 "$M5" 'if ! git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures" 2>/dev/null; then' \
                   'if false; then' \
                   'if [ -n "$unshippable" ]; then' \
                   'if false; then'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M5" "$WREPO" "$W_BASE" "$W_THEIRS" "$CONS2" green-one >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE green-one =====" "$LM" \
     && ! grep -qF "COVERAGE:" "$LM"; then
    ok "MUTATION — with the distribution check removed a repo holding no core/fixtures runs to a green suite: Part 13 is what catches that"
  else
    bad "MUTATION — the distribution check was neutered and the wrong repo was still refused (rc=$rc). Part 13's verdict is coming from somewhere else, and the guard is untested"
  fi
else
  bad "FIXTURE ERROR: the distribution-check anchor no longer occurs exactly once in the runner — Part 13 proves nothing"
fi

# --- MUTANTS 6 to 13: the OVER-completeness arm --------------------------------------------
# Keyed on LOCATION and on observable BEHAVIOUR, never on a spelling — Mutant 13 is a competent
# author's OTHER phrasing of the same fix and every arm above has to pass it. Each mutant's
# scoring input is the input of the ONE part that owns it, so a mutant that moves two cells is
# a report that two arms are watching the same subject.

# --- MUTANT 6: the whole over-completeness arm excised ---------------------------------------
# Excised rather than edited: a partial revert leaves a mutant that proves whichever probe was
# left in place. The named set is Part 14's, and the surplus directory has a driver in the
# consumer seed — so the copy runs it and reports a GREEN suite, which is exactly what the
# reference consumer saw while the orphan was being committed.
M6="$MUTDIR/m6-overarm-deleted.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a, b = s.index("# --- The OVER-completeness arm"), s.index("# The diff is taken into a variable")
open(sys.argv[2], "w").write(s[:a] + s[b:])' "$RUNNER" "$M6" 2>/dev/null
if [ -s "$M6" ] && ! cmp -s "$RUNNER" "$M6"; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M6" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       named-distonly green-one cwd-probe touched-shippable >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE named-distonly =====" "$LM" \
     && ! grep -qF "COVERAGE: the named set contains" "$LM"; then
    ok "MUTATION — with the over-completeness arm removed, a set naming a never-shipped fixture RUNS it and reports green: Part 14 is what catches that"
  else
    bad "MUTATION — the over-completeness arm was removed and the surplus directory was still refused (rc=$rc). Something else is producing Part 14's verdict, and the arm is untested"
  fi
else
  bad "FIXTURE ERROR: the over-completeness block could not be excised — its start or end anchor has moved, and Parts 14 to 19 prove nothing"
fi

# --- MUTANT 7: the .dist-only probe neutered, the run.sh probe kept ---------------------------
# One exclusion at a time, because a mutant that removes both cannot say which arm saw it. The
# anchor carries the `  if ` prefix that the diff-side copy of the same probe does not, so the
# substitution cannot land on the miss-join's exemption instead.
M7="$MUTDIR/m7-distonly-probe-gone.sh"
if mkmutant "$M7" '  if git -C "$DIST" rev-parse -q --verify "${THEIRS}:core/fixtures/${d}/.dist-only" >/dev/null 2>&1; then' \
                  '  if false; then'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M7" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       named-distonly green-one cwd-probe touched-shippable >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE named-distonly =====" "$LM"; then
    ok "MUTATION — with only the .dist-only probe gone the never-shipped directory has a run.sh at theirs, passes the surviving probe and is RUN: Part 14 is what catches that"
  else
    bad "MUTATION — the .dist-only probe was removed and the directory was still refused (rc=$rc). Part 14's verdict is coming from the run.sh probe, so the exclusion that produced the filed episode is untested"
  fi
else
  bad "FIXTURE ERROR: the .dist-only probe anchor no longer occurs exactly once in the runner — Part 14 proves nothing"
fi

# --- MUTANT 8: the run.sh probe neutered, the .dist-only probe kept ---------------------------
M8="$MUTDIR/m8-runsh-probe-gone.sh"
if mkmutant "$M8" '  elif ! git -C "$DIST" rev-parse -q --verify "${THEIRS}:core/fixtures/${d}/run.sh" >/dev/null 2>&1; then' \
                  '  elif false; then'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M8" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       touched-deleted green-one cwd-probe touched-shippable >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE touched-deleted =====" "$LM"; then
    ok "MUTATION — with only the run.sh probe gone a directory upstream DELETED is accepted and run: Part 15 is what catches that"
  else
    bad "MUTATION — the run.sh probe was removed and the deleted-driver directory was still refused (rc=$rc). Part 15 is being answered by the .dist-only probe, so the second exclusion is untested"
  fi
else
  bad "FIXTURE ERROR: the run.sh probe anchor no longer occurs exactly once in the runner — Part 15 proves nothing"
fi

# --- MUTANT 9: the arm relocated ABOVE the ref-resolution loop --------------------------------
# The placement mutant Part 18 owns. It is a strictly wider move than Mutant 10's — above the
# resolution loop is also above the wrong-repo guard — so Part 19 fires on this copy too. That
# is the direction that is allowed: Mutant 10 is the input only Part 19 can see, and it is what
# stops Part 19 from being an echo of Part 18.
M9="$MUTDIR/m9-overarm-above-refloop.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a, b = s.index("# --- The OVER-completeness arm"), s.index("# The diff is taken into a variable")
blk, t = s[a:b], s[:a] + s[b:]
c = t.index("for r in \"$BASE\" \"$THEIRS\"; do")
open(sys.argv[2], "w").write(t[:c] + blk + t[c:])' "$RUNNER" "$M9" 2>/dev/null
if [ -s "$M9" ] && ! cmp -s "$RUNNER" "$M9" && ! cmp -s "$M6" "$M9"; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M9" "$DIST" "$D_THEIRS" no-such-theirs-ref "$CONS2" green-one touched-shippable \
    >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 2 ] && [ "$(uns_set "$LM")" = "green-one,touched-shippable," ] \
     && ! grep -qF "COVERAGE: UNRESOLVABLE" "$LM"; then
    ok "MUTATION — sited above the ref-resolution loop the arm probes an unresolvable theirs, every cat-file fails, and it convicts two directories the distribution ships: Part 18 is what catches that"
  else
    bad "MUTATION — the arm was moved above the ref-resolution loop and Part 18's arm did not fire (rc=$rc, refused '$(uns_set "$LM")'). An arm keyed on the exit code alone cannot tell the resolution refusal from this one, because both are 2"
  fi
else
  bad "FIXTURE ERROR: the over-completeness block could not be relocated above the ref loop — an anchor has moved, or the relocated copy is byte-identical to the deleted one, and Part 18 proves nothing"
fi

# --- MUTANT 10: the arm relocated ABOVE the wrong-repo guard, BELOW the ref loop ---------------
# The input only Part 19 can see. Both refs resolve here, so the resolution loop is satisfied and
# Part 18 passes against this copy — what it gets wrong is a checkout whose theirs carries no
# `core/fixtures` tree at all, where every probe fails again and the repo's defect is reported as
# the slice's.
M10="$MUTDIR/m10-overarm-above-distguard.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a, b = s.index("# --- The OVER-completeness arm"), s.index("# The diff is taken into a variable")
blk, t = s[a:b], s[:a] + s[b:]
c = t.index("# AND `$DIST` MUST BE THE DISTRIBUTION")
open(sys.argv[2], "w").write(t[:c] + blk + t[c:])' "$RUNNER" "$M10" 2>/dev/null
if [ -s "$M10" ] && ! cmp -s "$RUNNER" "$M10" && ! cmp -s "$M9" "$M10"; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M10" "$WREPO" "$W_BASE" "$W_THEIRS" "$CONS2" green-one touched-shippable >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 2 ] && [ "$(uns_set "$LM")" = "green-one,touched-shippable," ] \
     && ! grep -qF "COVERAGE: WRONG-REPO" "$LM"; then
    ok "MUTATION — sited above the wrong-repo guard the arm indicts the named set of a checkout that is simply the wrong repo, and Part 18 cannot see it because both refs resolve: Part 19 is what catches that"
  else
    bad "MUTATION — the arm was moved above the wrong-repo guard and Part 19's arm did not fire (rc=$rc, refused '$(uns_set "$LM")'). Part 19 is then an echo of Part 18 and the ordering it asserts is untested"
  fi
else
  bad "FIXTURE ERROR: the over-completeness block could not be relocated above the wrong-repo guard — an anchor has moved, or the copy is byte-identical to Mutant 9's, and Part 19 proves nothing"
fi

# --- MUTANT 11: both probes read the DISTRIBUTION CHECKOUT instead of theirs -------------------
# The implementation a naive seed cannot distinguish from the right one. It returns the exact
# INVERSE of Part 17's set, and it is wrong in both directions at once: it acquits an orphan
# bound for the consumer and convicts two fixtures the pull genuinely delivers.
M11="$MUTDIR/m11-probes-read-disk.sh"
if mkmutant2 "$M11" 'if git -C "$DIST" rev-parse -q --verify "${THEIRS}:core/fixtures/${d}/.dist-only" >/dev/null 2>&1; then' \
                    'if [ -f "$DIST/core/fixtures/${d}/.dist-only" ]; then' \
                    'elif ! git -C "$DIST" rev-parse -q --verify "${THEIRS}:core/fixtures/${d}/run.sh" >/dev/null 2>&1; then' \
                    'elif [ ! -f "$DIST/core/fixtures/${d}/run.sh" ]; then'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M11" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       theirs-only-distonly theirs-only-nodriver disk-only-distonly disk-missing-driver green-one \
       >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && [ "$(uns_set "$(newest_log2)")" = "disk-missing-driver,disk-only-distonly," ]; then
    ok "MUTATION — probing the checkout instead of theirs inverts the verdict exactly: the two orphans are acquitted and two shippable fixtures convicted. Part 17 is what catches that"
  else
    bad "MUTATION — the probes were pointed at the \$DIST worktree and Part 17 did not change its answer (rc=$rc, refused '$(uns_set "$(newest_log2)")'). Then disk and theirs agree for every directory Part 17 names, and the arm cannot tell the two implementations apart"
  fi
else
  bad "FIXTURE ERROR: one of the two probe anchors no longer occurs exactly once in the runner — Part 17 proves nothing"
fi

# --- MUTANT 12: the refusal degraded to a warning that falls through ---------------------------
# `exit 2` becomes `:`. The two refusal blocks in this runner end in BYTE-IDENTICAL three-line
# tails, so the anchor carries the remedy sentence that only this one has — keying on the shared
# tail would edit the miss-join and score a kill this arm did not earn.
M12="$MUTDIR/m12-refusal-is-a-warning.sh"
if mkmutant "$M12" '  never ships — the RETIRED-FIXTURE-ORPHAN class. Drop them from the slice and re-run." >&2
  echo "  log: $LOG" >&2
  exit 2' \
                   '  never ships — the RETIRED-FIXTURE-ORPHAN class. Drop them from the slice and re-run." >&2
  echo "  log: $LOG" >&2
  :'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M12" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       named-distonly green-one cwd-probe touched-shippable >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "COVERAGE: the named set contains" "$LM" \
     && grep -qF "===== FIXTURE named-distonly =====" "$LM"; then
    ok "MUTATION — reporting the surplus directory and then RUNNING it anyway exits 0, and a green exit is the only thing step 2 reads: Part 14's exit-code and ordering arms are what catch that"
  else
    bad "MUTATION — the refusal was degraded to a warning and the run still failed (rc=$rc). Part 14 is asserting on the message alone, and a finding printed above a green exit reaches nobody"
  fi
else
  bad "FIXTURE ERROR: the refusal-tail anchor no longer occurs exactly once in the runner — Part 14's exit-code arm proves nothing"
fi

# --- MUTANT 13: a SECOND SPELLING of the CORRECT fix, which must PASS --------------------------
# A competent author's other phrasing: the two probes lifted into a helper that returns the
# reason, the loop reduced to a call and an append. Same reads, same ref, same messages, same
# exit. A battery that rejects this is not testing the property, it is testing one author's
# formatting — and the next correct change to the runner would come back red for no reason.
SPELL2="$MUTDIR/second-spelling-body.txt"
cat > "$SPELL2" <<'SPELLEOF'
unship_reason() { # $1=directory name — echoes the reason it cannot ship, or nothing
  if git -C "$DIST" rev-parse -q --verify "${THEIRS}:core/fixtures/${1}/.dist-only" >/dev/null 2>&1; then
    printf 'carries .dist-only at %s: never shipped, so no consumer can hold it' "$THEIRS"
  elif ! git -C "$DIST" rev-parse -q --verify "${THEIRS}:core/fixtures/${1}/run.sh" >/dev/null 2>&1; then
    printf 'no run.sh at %s: upstream deleted the driver, so there is nothing to write' "$THEIRS"
  fi
}
unshippable=""
for d in "$@"; do
  why="$(unship_reason "$d")"
  [ -n "$why" ] || continue
  unshippable="$unshippable
  $d — $why"
done

if [ -n "$unshippable" ]; then
  { echo "COVERAGE: the named set contains fixture(s) no consumer can run:"
    printf '%s\n' "${unshippable#
}"
    echo ""; } >> "$LOG"
  echo "self-update-fixtures: the named set contains fixtures no consumer can run:" >&2
  printf '%s\n' "$unshippable" >&2
  echo "  Step 2 derives the covering set by hand and the exclusions are stated for the" >&2
  echo "  diff-side term. Writing one of these into the consumer creates a fixture core" >&2
  echo "  never ships — the RETIRED-FIXTURE-ORPHAN class. Drop them from the slice and re-run." >&2
  echo "  log: $LOG" >&2
  exit 2
fi

SPELLEOF
M13="$MUTDIR/m13-second-spelling.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a, b = s.index("unshippable=\"\"\n"), s.index("# The diff is taken into a variable")
open(sys.argv[2], "w").write(s[:a] + open(sys.argv[3]).read() + s[b:])' "$RUNNER" "$M13" "$SPELL2" 2>/dev/null
if [ -s "$M13" ] && ! cmp -s "$RUNNER" "$M13"; then
  s13=0
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M13" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       named-distonly green-one cwd-probe touched-shippable >/dev/null 2>&1
  [ $? -eq 2 ] && [ "$(uns_set "$(newest_log2)")" = "named-distonly," ] || s13=$((s13+1))
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M13" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       theirs-only-distonly theirs-only-nodriver disk-only-distonly disk-missing-driver green-one \
       >/dev/null 2>&1
  [ $? -eq 2 ] && [ "$(uns_set "$(newest_log2)")" = "theirs-only-distonly,theirs-only-nodriver," ] || s13=$((s13+1))
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M13" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       green-one cwd-probe touched-named touched-shippable >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  { [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE touched-named =====" "$LM" \
      && ! grep -qF "COVERAGE: the named set contains" "$LM"; } || s13=$((s13+1))
  if [ "$s13" -eq 0 ]; then
    ok "SECOND SPELLING — the same fix written with a reason-returning helper passes Parts 14, 16 and 17 unchanged: the arms are keyed on the property, not on one author's phrasing"
  else
    bad "SECOND SPELLING — an equivalent implementation of the SAME fix failed $s13 of Parts 14, 16 and 17. A battery that only accepts the phrasing it was written against rejects the next correct change, and this repo has shipped a receipt that certified a regression and refused the real fix"
  fi
else
  bad "FIXTURE ERROR: the second spelling could not be built — the over-completeness block's anchors have moved, and nothing establishes that Parts 14 to 19 accept an equivalent implementation"
fi

# --- MUTANT 14: the .dist-only probe WIDENED to convict every shippable directory -------------
# The mutation the other seven cannot produce. Every one of them makes the arm say LESS, and an
# arm that says less is caught by a set equality missing a member; this one makes it say MORE,
# and Part 16 is the only arm whose subject that is. It was the last arm here with no mutant at
# all, which is the state `fixture-mutants.md` names: an arm asserting that nothing was said
# passes against a subject that says nothing, and only a widening copy tells the two apart.
M14="$MUTDIR/m14-distonly-probe-widened.sh"
if mkmutant "$M14" '  if git -C "$DIST" rev-parse -q --verify "${THEIRS}:core/fixtures/${d}/.dist-only" >/dev/null 2>&1; then' \
                   '  if ! git -C "$DIST" rev-parse -q --verify "${THEIRS}:core/fixtures/${d}/.dist-only" >/dev/null 2>&1; then'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M14" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       green-one cwd-probe touched-named touched-shippable >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] \
     && [ "$(uns_set "$(newest_log2)")" = "cwd-probe,green-one,touched-named,touched-shippable," ]; then
    ok "MUTATION — with the .dist-only probe inverted the arm convicts every directory a consumer CAN run and wedges the self-update: Part 16 is what catches that"
  else
    bad "MUTATION — the .dist-only probe was widened to convict everything and the wholly shippable set was still accepted (rc=$rc, refused '$(uns_set "$(newest_log2)")'). Part 16 asserts an absence no run can produce, so it would pass against a subject that says nothing"
  fi
else
  bad "FIXTURE ERROR: the .dist-only probe anchor no longer occurs exactly once in the runner — Part 16 proves nothing"
fi

# --- MUTANTS G1 to G4: the GATE-RECORD requirement --------------------------------------------
# Keyed on LOCATION and on observable BEHAVIOUR. Each is scored on the input of the ONE part
# that owns it, and the scoring runs in `$GCONS` — the only consumer tree with no acquitting
# record seeded into it.
#   G1  the requirement excised outright      Part G1
#   G2  the shas compared as STRINGS          Part G3 (the record's header is resolved; the
#                                             argument is a tag, so a string compare refuses
#                                             the right range and the arm reads it as a refusal
#                                             for the wrong reason — see the two-run scoring)
#   G3  the verdict check accepts DEFER       Part G2
#   G4  the candidates ordered OLDEST first   Part G5

# --- MUTANT G1: the whole gate-record requirement excised ------------------------------------
# Excised rather than edited: a partial revert leaves whichever layer was not touched, and this
# refusal has two (the peel and the record match). The named set is legitimate for this range, so
# the copy runs the fixtures and reports a GREEN suite over a cycle nothing authorised — exactly
# the state step 2 was in before this arm existed.
MG1="$MUTDIR/mg1-gaterecord-deleted.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a, b = s.index("# --- THE GATE RECORD"), s.index("# --- The OVER-completeness arm")
open(sys.argv[2], "w").write(s[:a] + s[b:])' "$RUNNER" "$MG1" 2>/dev/null
if [ -s "$MG1" ] && ! cmp -s "$RUNNER" "$MG1"; then
  gin_restore
  gin_seed "$SR_NO_INPUTS" 190
  bash "$MG1" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one >/dev/null 2>&1
  rc=$?
  LM="$(newest_glog)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE green-one =====" "$LM" \
     && ! grep -qF "GATE-RECORD:" "$LM"; then
    ok "MUTATION — with the gate-record requirement removed a record that names NOTHING authorises a green suite, and so would no record at all: Parts G1 and G7 are what catch that"
  else
    bad "MUTATION — the gate-record requirement was removed and the cycle was still refused (rc=$rc). Part G1's verdict is coming from somewhere else and the requirement is untested"
  fi
else
  bad "FIXTURE ERROR: the gate-record block could not be excised — its start or end anchor has moved, and Parts G1 to G5 prove nothing"
fi

# --- MUTANT G2: the shas compared as STRINGS rather than resolved ------------------------------
# The implementation a naive seed cannot tell from the right one. Both sides are compared as the
# CALLER SPELLED them, so a record written for `theirs-tag` matches an argument of `theirs-tag`
# and everything looks fine — until the two spellings differ, which is the normal case, because
# step 2 passes a ref and the gate records what it resolved to.
#
# SCORED IN TWO RUNS, because a mutant that refuses EVERYTHING would satisfy a one-run arm keyed
# on a refusal. The first run is the legitimate range Part G4's shape uses, spelled as a TAG:
# correct code accepts it, the mutant refuses. The second is Part G3's wrong-range input, which
# BOTH implementations must refuse — so the kill is the pair, and a copy that simply always
# refuses fails the pair rather than scoring it.
MG2="$MUTDIR/mg2-sha-compared-as-string.sh"
if mkmutant2 "$MG2" 'gr_base="$(git -C "$DIST" rev-parse "${BASE}^{commit}" 2>/dev/null)"' \
                    'gr_base="$BASE"' \
                    'gr_theirs="$(git -C "$DIST" rev-parse "${THEIRS}^{commit}" 2>/dev/null)"' \
                    'gr_theirs="$THEIRS"'; then
  # A record for D_BASE..theirs-tag, written with RESOLVED shas exactly as the gate writes it.
  gin_restore
  gin_seed_clean 191
  bash "$MG2" "$DIST" "$D_BASE" theirs-tag "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  mg2_tag=$?
  mg2_tag_ref=0
  bash "$RUNNER" "$DIST" "$D_BASE" theirs-tag "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1 || mg2_tag_ref=1
  # ...and a record for a DIFFERENT range, which both implementations must refuse.
  rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
  seed_record "$GLOG" "$DIST" "$D_QUIET" "$D_SHIP" OK 192 >/dev/null
  bash "$MG2" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  mg2_wrong=$?
  if [ "$mg2_tag" -eq 2 ] && [ "$mg2_tag_ref" -eq 0 ] && [ "$mg2_wrong" -eq 2 ]; then
    ok "MUTATION — comparing the ARGUMENT STRINGS instead of the resolved shas refuses a record written for this very range one minute earlier (tag ref: correct=accepted, mutant=exit 2), while still refusing the wrong range: Part G3's sha comparison is what catches that"
  else
    bad "MUTATION — the sha comparison was replaced by a string comparison and the fixture did not see it (mutant on the tag ref rc=$mg2_tag expected 2, unmutated rc=$mg2_tag_ref expected 0, wrong-range rc=$mg2_wrong expected 2). Step 2 passes a REF and the gate records a SHA, so a string comparison wedges every self-update whose theirs is not spelled as a raw sha"
  fi
else
  bad "FIXTURE ERROR: one of the two rev-parse anchors no longer occurs exactly once in the runner — the resolved-sha comparison is untested"
fi

# --- MUTANT G3: the verdict check accepts DEFER ------------------------------------------------
# The presence-only reader: a record for the right range is enough and its verdict is never read.
# It passes Parts G1 and G3 — there is no record and a wrong-range record in those — and the only
# thing it gets wrong is the one case the gate explicitly refused.
MG3="$MUTDIR/mg3-verdict-unread.sh"
if mkmutant "$MG3" '    if [ "$gr_verdict" != "OK" ]; then' \
                   '    if [ -z "$gr_verdict" ]; then'; then
  gin_restore
  SR_INPUTS="$(sr_required_inputs "$GCONS")" gin_seed_defer 193
  bash "$MG3" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one >/dev/null 2>&1
  rc=$?
  LM="$(newest_glog)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE green-one =====" "$LM"; then
    ok "MUTATION — with the verdict unread a DEFER record authorises the cycle, because a record EXISTS: Part G2 is what catches that"
  else
    bad "MUTATION — the verdict check was reduced to a presence check and the DEFER record still stopped the run (rc=$rc). Part G2 is being answered by the sha match, so the verdict itself is untested"
  fi
else
  bad "FIXTURE ERROR: the verdict-check anchor no longer occurs exactly once in the runner — Part G2 proves nothing"
fi

# --- MUTANT G4: the newest-record selection picks the OLDEST -----------------------------------
# `sort -r` becomes `sort`. Every other part here seeds exactly one matching record, so this copy
# is correct for all of them; the only input that separates the two orderings is Part G5's pair.
MG4="$MUTDIR/mg4-oldest-record-wins.sh"
if mkmutant "$MG4" 'gr_cands="$(ls "$OUT_DIR"/self-update-gate-*.md 2>/dev/null | sort -r)"' \
                   'gr_cands="$(ls "$OUT_DIR"/self-update-gate-*.md 2>/dev/null | sort)"'; then
  gin_restore
  rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
  SR_INPUTS="$(sr_required_inputs "$GCONS")" seed_record "$GLOG" "$DIST" "$D_BASE" "$D_THEIRS" OK    100 >/dev/null
  SR_INPUTS="$(sr_required_inputs "$GCONS")" seed_record "$GLOG" "$DIST" "$D_BASE" "$D_THEIRS" DEFER 900 >/dev/null
  bash "$MG4" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one >/dev/null 2>&1
  rc=$?
  LM="$(newest_glog)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE green-one =====" "$LM"; then
    ok "MUTATION — ordering the candidates oldest-first revives an OK the gate has already superseded with a DEFER: Part G5 is what catches that"
  else
    bad "MUTATION — the record ordering was reversed and Part G5 did not see it (rc=$rc). Where every part seeds one matching record the two orderings are the same program, and the arm asserts nothing"
  fi
else
  bad "FIXTURE ERROR: the record-ordering anchor no longer occurs exactly once in the runner — Part G5 proves nothing"
fi

# --- MUTANTS G5 to G9: the corrected input join and the re-keyed tolerance ---------------------
#   G5  the whole input comparison removed        Part G8   (a third hand walks in)
#   G6  the inputs COUNTED, never compared        Part G8   — the shape that reads as a check
#   G7  the THEIRS acceptance removed             Part G6   (the normal flow refused)
#   G8  the PRE-WRITTEN arm removed               Part G14  (a late gate accepted)
#   G9  the tolerance keyed on emptiness alone    Part G13a (deleted records acquitted)
#
# G7 and G8 are the pair the v2 correction turns on, and they pull in OPPOSITE directions: G7
# makes the reader stricter (it refuses the slice) and G8 makes it laxer (it accepts a verdict
# taken after the slice). A battery carrying only one of them would certify whichever error its
# author was not thinking about.

# --- MUTANT G5: the input comparison removed ---------------------------------------------------
# The whole `else` branch under the OK verdict, so a matching range and an OK verdict are the
# entire requirement again. Scored on Part G8's input: the record is real, its verdict is OK, and
# a third hand has put content in a gating script that this pull does not ship.
MG5="$MUTDIR/mg5-inputs-unchecked.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a = s.index("    else\n      # THE INPUTS THE VERDICT READ")
b = s.index("  elif [ \"$gr_seen\" -eq 0 ]; then")
open(sys.argv[2], "w").write(s[:a] + "    fi\n" + s[b:])' "$RUNNER" "$MG5" 2>/dev/null
if [ -s "$MG5" ] && ! cmp -s "$RUNNER" "$MG5" && bash -n "$MG5" 2>/dev/null; then
  gin_restore
  gin_seed_clean 300
  printf '%s\n' 'neither the recorded content nor what the pull ships' > "$GCONS/$GIN_CHANGED"
  bash "$MG5" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  rc=$?
  LM="$(newest_glog)"
  gin_restore
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE green-one =====" "$LM" \
     && ! grep -qF "GATE-RECORD:" "$LM"; then
    ok "MUTATION — with the input comparison removed a verdict taken against a DIFFERENT consumer tree authorises this run: Part G8 is what catches that"
  else
    bad "MUTATION — the input comparison was removed and the third-hand edit was still refused (rc=$rc). Part G8's verdict is coming from the range match, so the tree binding is untested"
  fi
else
  bad "FIXTURE ERROR: the input-comparison block could not be excised or the result does not parse — an anchor has moved, and Parts G6 to G17 prove nothing"
fi

# --- MUTANT G6: the inputs COUNTED, never compared ---------------------------------------------
# The shape that looks exactly like a working check and is the one this repo keeps shipping: the
# record's input lines are counted, the count is asserted non-zero, and no byte of the consumer
# is ever read. It passes Part G7 — a record with no inputs still counts zero — and only an arm
# that MOVES a file can tell the two apart.
MG6="$MUTDIR/mg6-inputs-counted-not-compared.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a = s.index("    else\n      # THE INPUTS THE VERDICT READ")
b = s.index("  elif [ \"$gr_seen\" -eq 0 ]; then")
body = """    else
      gr_n_in="$(grep -c "^# input: " "$GATE_REC")" || gr_n_in=0
      gr_moved=""; gr_required=""; gr_prewritten=""
      if [ "$gr_n_in" -eq 0 ]; then
        GATE_REC_WHY="the gate record $(basename "$GATE_REC") names NO input files"
      fi
    fi
"""
open(sys.argv[2], "w").write(s[:a] + body + s[b:])' "$RUNNER" "$MG6" 2>/dev/null
if [ -s "$MG6" ] && ! cmp -s "$RUNNER" "$MG6" && ! cmp -s "$MG5" "$MG6" && bash -n "$MG6" 2>/dev/null; then
  # BOTH DIRECTIONS, because a copy that refuses everything would satisfy a one-run arm: the
  # no-input record must still be refused (so the copy RAN and its count arm works) and the
  # third-hand edit must be accepted (so it never looked at the tree).
  gin_restore
  gin_seed "$SR_NO_INPUTS" 310
  bash "$MG6" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  mg6_empty=$?
  gin_seed_clean 311
  printf '%s\n' 'neither the recorded content nor what the pull ships' > "$GCONS/$GIN_CHANGED"
  bash "$MG6" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  mg6_moved=$?
  gin_restore
  if [ "$mg6_empty" -eq 2 ] && [ "$mg6_moved" -eq 0 ]; then
    ok "MUTATION — COUNTING the input lines instead of comparing them still refuses an empty record (so the copy ran) and accepts a tree a third hand has edited: Part G8 is what catches that"
  else
    bad "MUTATION — the inputs were counted rather than compared and the fixture did not see it (empty-record rc=$mg6_empty expected 2, third-hand rc=$mg6_moved expected 0). A count is true either way, and an arm asserting only that the record names SOMETHING passes against a check that never opens a file"
  fi
else
  bad "FIXTURE ERROR: the count-only mutant could not be built or does not parse — Part G8's comparison is untested"
fi

# --- MUTANT G7: the THEIRS acceptance removed — the SHIPPED DEFECT, rebuilt --------------------
# This is the runner as it was actually shipped: an input that moved is refused, full stop. It
# refuses the legitimate flow, and Part G6 is the only arm that can see it — every other arm here
# either moves nothing or moves something to content the pull does not ship, and this copy is
# CORRECT on all of them. That is why the arm had to model the real order rather than run the
# gate and the runner back to back.
MG7="$MUTDIR/mg7-theirs-acceptance-removed.sh"
if mkmutant "$MG7" '              elif [ -n "$gr_tb" ] && [ "$gr_now" = "$gr_tb" ]; then' \
                   '              elif false; then' ; then
  gin_restore
  gin_seed_clean 320
  gin_write_slice
  bash "$MG7" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  rc=$?
  LM="$(newest_glog)"
  gin_restore
  if [ "$rc" -eq 2 ] && [ -n "$LM" ] && grep -qF "GATE-RECORD: INPUT-MOVED $GIN_CHANGED" "$LM"; then
    ok "MUTATION — without the theirs-blob acceptance the runner refuses the slice the cycle itself just wrote, which is every legitimate self-update whose range changes a gating script: Part G6 is what catches that"
  else
    bad "MUTATION — the theirs acceptance was removed and the NORMAL order still ran (rc=$rc). Part G6 is not modelling step 2's real order — gate, WRITE, runner — and the shipped defect would pass this battery unchanged"
  fi
else
  bad "FIXTURE ERROR: the theirs-acceptance anchor no longer occurs exactly once in the runner — Part G6 proves nothing"
fi

# --- MUTANT G8: the PRE-WRITTEN arm removed ----------------------------------------------------
# The opposite error to G7's, and no digest comparison can catch it: with this arm gone a gate run
# AFTER the write records digests that match the tree perfectly, so every other check here agrees
# and the OK means only that each file equals itself.
MG8="$MUTDIR/mg8-prewritten-arm-removed.sh"
if mkmutant "$MG8" '            if [ -n "$gr_tb" ] && [ -n "$gr_bb" ] && [ "$gr_bb" != "$gr_tb" ] \
               && [ "$gr_h" = "$gr_tb" ]; then' \
                   '            if false; then'; then
  gin_restore
  gin_write_slice
  gin_seed_clean 330
  bash "$MG8" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  rc=$?
  LM="$(newest_glog)"
  gin_restore
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE green-one =====" "$LM" \
     && ! grep -qF "GATE-RECORD:" "$LM"; then
    ok "MUTATION — with the PRE-WRITTEN arm gone a gate run AFTER the write authorises the cycle, and every digest in that record agrees with the tree: Part G14 is what catches that"
  else
    bad "MUTATION — the PRE-WRITTEN arm was removed and the late gate was still refused (rc=$rc). Nothing else here can see it — the record and the tree agree perfectly — so Part G14 is being answered by something that is not its subject"
  fi
else
  bad "FIXTURE ERROR: the PRE-WRITTEN anchor no longer occurs exactly once in the runner — Part G14 proves nothing"
fi

# --- MUTANT G9: the tolerance keyed on EMPTINESS alone -----------------------------------------
# The exemption as it was first built: an empty record directory is the delivery pull. `rm -f
# self-update-gate-*.md` then reaches it at will, so the requirement is advisory for anyone
# willing to run one command — a mechanism defending its own defect.
MG9="$MUTDIR/mg9-tolerance-on-emptiness.sh"
if mkmutant "$MG9" '    if [ "$gr_tok_base" -gt 0 ]; then' \
                   '    if false; then'; then
  gin_restore
  rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
  bash "$MG9" "$DIST" "$D_BASE_REC" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  rc=$?
  LM="$(newest_glog)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "NOT-REQUIRED" "$LM"; then
    ok "MUTATION — keyed on emptiness alone, deleting the records reaches the tolerance even where the gate at base DOES record: Part G13a is what catches that"
  else
    bad "MUTATION — the tolerance was keyed on the directory being empty and Part G13a did not fire (rc=$rc). Then \`rm -f\` is the whole bypass and nothing here would say so"
  fi
else
  bad "FIXTURE ERROR: the tolerance anchor no longer occurs exactly once in the runner — Part G13a proves nothing"
fi


# --- MUTANTS G10 to G12: the digest column and the probe token --------------------------------
#   G10  the carried-content conjunct removed     Part G18  (all-zero forgery accepted)
#   G11  the set narrowed to the BASE blob        Part G21  (intermediate-blob consumer refused)
#   G12  the probe token back to GATE_REC_DIR     Part G22  (a declaring gate read as recording)
#
# G10 and G11 pull in opposite directions, exactly as G7 and G8 do: one makes the reader accept
# a record no gate produced, the other makes it refuse a consumer in a state this cycle itself
# creates. Either alone certifies whichever error its author was not thinking about.

# --- MUTANT G10: the carried-content conjunct removed -----------------------------------------
# ARM 2 back to a bare theirs-acceptance, which is what shipped. After the slice every gating
# script IS at theirs, so a record whose digests were never read off anything passes.
MG10="$MUTDIR/mg10-theirs-acceptance-unqualified.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a = s.index("                # ARM 2, and the second conjunct is what keeps the digest column")
b = s.index("              else\n                gr_moved=\"$gr_moved\n  $gr_p — recorded ${gr_h}, now ${gr_now:-<unhashable>}, which is neither")
open(sys.argv[2], "w").write(s[:a] + "                :\n" + s[b:])' "$RUNNER" "$MG10" 2>/dev/null
if [ -s "$MG10" ] && ! cmp -s "$RUNNER" "$MG10" && bash -n "$MG10" 2>/dev/null; then
  gin_restore
  gin_write_slice
  gin_seed "$(printf '# input: .githooks/pre-push\t%s\t-\n# input: %s\t%s\tcore/scripts/gate-changed.sh\n# input: %s\t%s\tcore/scripts/gate-steady.sh' \
    "$(git hash-object "$GCONS/.githooks/pre-push")" \
    "$GIN_CHANGED" "$GZERO" "$GIN_STEADY" "$GZERO")" 430
  bash "$MG10" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  rc=$?
  LM="$(newest_glog)"
  gin_restore
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE green-one =====" "$LM" \
     && ! grep -qF "GATE-RECORD:" "$LM"; then
    ok "MUTATION — with the carried-content conjunct gone an all-zero-digest record passes, because after the write every file IS at theirs: Part G18 is what catches that"
  else
    bad "MUTATION — the conjunct was removed and the forged record was still refused (rc=$rc). Part G18's verdict is coming from somewhere else, and the digest column's load-bearing half is untested"
  fi
else
  bad "FIXTURE ERROR: the carried-content conjunct could not be excised or the result does not parse — Part G18 proves nothing"
fi

# --- MUTANT G11: the carried set narrowed to the BASE blob ------------------------------------
# The over-tight repair, and the one a hand reaching for the simplest fix writes. It refuses a
# consumer whose pre-write copy was an intermediate release's blob — the split-stamp state this
# cycle itself creates — while passing every other arm here, because the shared distribution has
# no intermediate commit touching a gating script.
MG11="$MUTDIR/mg11-carried-set-base-only.sh"
if mkmutant "$MG11" '                gr_hist="$(
                  { git -C "$DIST" rev-parse -q --verify "${BASE}:${gr_c}" 2>/dev/null
                    for gr_cm in $(git -C "$DIST" log --format=%H "${BASE}..${THEIRS}" -- "$gr_c" 2>/dev/null); do
                      git -C "$DIST" rev-parse -q --verify "${gr_cm}:${gr_c}" 2>/dev/null
                    done
                  } | sort -u
                )"' \
                    '                gr_hist="$(git -C "$DIST" rev-parse -q --verify "${BASE}:${gr_c}" 2>/dev/null)"'; then
  # Rebuilt here rather than reusing Part G21's, because that world is torn down with its own
  # temp dirs and a mutant reading a deleted tree is a mutant that never ran.
  M11K="$(mktemp -d)"
  mkdir -p "$M11K/_bmad-output/ai-dlc-update" "$M11K/tests/fixtures/probe" "$M11K/.githooks" "$M11K/scripts/ai-dlc"
  printf 'exit 0\n' > "$M11K/tests/fixtures/probe/run.sh"
  printf 'bash scripts/ai-dlc/gate-changed.sh\n' > "$M11K/.githooks/pre-push"
  IG show "${I_M}:core/scripts/gate-changed.sh" > "$M11K/scripts/ai-dlc/gate-changed.sh" 2>/dev/null
  printf '# base-sha: %s\n# theirs-sha: %s\n# input: .githooks/pre-push\t%s\t-\n# input: scripts/ai-dlc/gate-changed.sh\t%s\tcore/scripts/gate-changed.sh\n\n# verdict: OK\n' \
    "$I_B" "$I_T" "$(git hash-object "$M11K/.githooks/pre-push")" "$I_MB" \
    > "$M11K/_bmad-output/ai-dlc-update/self-update-gate-19700101T000000Z.md"
  IG show "${I_T}:core/scripts/gate-changed.sh" > "$M11K/scripts/ai-dlc/gate-changed.sh" 2>/dev/null
  bash "$MG11" "$I_D" "$I_B" "$I_T" "$M11K" probe >/dev/null 2>&1
  m11_int=$?
  # ...and the control: the SAME copy must still refuse the all-zero forgery, or the kill above
  # is a copy that refuses everything rather than one that narrowed the set.
  gin_restore
  gin_write_slice
  gin_seed "$(printf '# input: .githooks/pre-push\t%s\t-\n# input: %s\t%s\tcore/scripts/gate-changed.sh\n# input: %s\t%s\tcore/scripts/gate-steady.sh' \
    "$(git hash-object "$GCONS/.githooks/pre-push")" \
    "$GIN_CHANGED" "$GZERO" "$GIN_STEADY" "$GZERO")" 440
  bash "$MG11" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  m11_forge=$?
  gin_restore
  M11L="$(ls -t "$M11K"/_bmad-output/ai-dlc-update/self-update-fixtures-*.md 2>/dev/null | head -1)"
  if [ "$m11_int" -eq 2 ] && [ "$m11_forge" -eq 2 ] \
     && [ -n "$M11L" ] && grep -qF "INPUT-MOVED" "$M11L"; then
    ok "MUTATION — narrowing the carried set to the BASE blob refuses a consumer at an intermediate release's blob, while still refusing the forgery: Part G21 is what catches that"
  else
    bad "MUTATION — the carried set was narrowed to base-only and Part G21 did not see it (intermediate rc=$m11_int expected 2, forgery rc=$m11_forge expected 2). A split stamp is the normal state after any self-update, so this narrowing wedges those consumers and no arm here would say so"
  fi
  rm -rf "$M11K"
else
  bad "FIXTURE ERROR: the carried-set anchor no longer occurs exactly once in the runner — Part G21 proves nothing"
fi
rm -rf "$I_D" "$I_K"

# --- MUTANT G12: the probe token back to the ASSIGNMENT ---------------------------------------
# `GATE_REC_DIR` scores correctly at both real revisions and is still wrong: it names an
# assignment, so a gate that declares the variable and never writes reads as a recording gate.
# Both directions, because a token that matched nothing would also "kill" Part G22 by making
# every base look non-recording — the recording base must still be seen.
MG12="$MUTDIR/mg12-token-names-an-assignment.sh"
if mkmutant2 "$MG12" "gr_tok_base=\"\$(git -C \"\$DIST\" show \"\${BASE}:\${gr_gate_core}\" 2>/dev/null \\
                   | grep -v '^[[:space:]]*#' | grep -cF '/self-update-gate-\$(date')\" || gr_tok_base=0" \
                     "gr_tok_base=\"\$(git -C \"\$DIST\" show \"\${BASE}:\${gr_gate_core}\" 2>/dev/null \\
                   | grep -v '^[[:space:]]*#' | grep -cF 'GATE_REC_DIR')\" || gr_tok_base=0" \
                     "gr_tok_theirs=\"\$(git -C \"\$DIST\" show \"\${THEIRS}:\${gr_gate_core}\" 2>/dev/null \\
                     | grep -v '^[[:space:]]*#' | grep -cF '/self-update-gate-\$(date')\" || gr_tok_theirs=0" \
                     "gr_tok_theirs=\"\$(git -C \"\$DIST\" show \"\${THEIRS}:\${gr_gate_core}\" 2>/dev/null \\
                     | grep -v '^[[:space:]]*#' | grep -cF 'GATE_REC_DIR')\" || gr_tok_theirs=0"; then
  gin_restore
  rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
  bash "$MG12" "$DIST" "$D_BASE_DECL" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  m12_decl=$?
  M12L="$(newest_glog)"
  # SCORED BEFORE THE CLEAR, because the clear below deletes the very file this reads and a
  # grep over a missing path is a clean zero indistinguishable from a message that was absent.
  m12_missing=0
  { [ -n "$M12L" ] && grep -qF "GATE-RECORD: MISSING" "$M12L"; } && m12_missing=1
  # The control: the genuinely NON-recording base must still reach the tolerance under the
  # mutated token, or the kill is a token that matches nothing rather than one that over-matches.
  rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
  bash "$MG12" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
    >/dev/null 2>&1
  m12_plain=$?
  if [ "$m12_decl" -eq 2 ] && [ "$m12_missing" -eq 1 ] && [ "$m12_plain" -eq 0 ]; then
    ok "MUTATION — keyed on the ASSIGNMENT, a gate that declares the record directory and never writes is read as recording, and the consumer is refused with a message saying its records were deleted: Part G22 is what catches that"
  else
    bad "MUTATION — the token was pointed back at the assignment and Part G22 did not fire (declaring-base rc=$m12_decl expected 2, MISSING line=$m12_missing expected 1, non-recording base rc=$m12_plain expected 0). Either the arm cannot see the over-match, or the mutated token matches nothing at all and the kill would be for the wrong reason"
  fi
else
  bad "FIXTURE ERROR: one of the two probe-token sites no longer occurs exactly once in the runner — Part G22 proves nothing"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "self-update-fixture-log: PASS"
  exit 0
fi
echo "self-update-fixture-log: FAIL ($fails)"
exit 1
