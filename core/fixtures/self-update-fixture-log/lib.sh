# self-update-fixture-log/lib.sh -- the resolution, the seeded distribution and consumer trees,
# the per-part worlds and the log readers of self-update-fixture-log, sourced by that fixture's
# run.sh (the behavioural arms, shipped) and by self-update-fixture-log-mutants/run.sh (the
# mutation battery, distribution-only). ONE copy, so every mutant is driven against the very
# worlds, and read by the very readers, that the shipped arms use -- never a second implementation.
#
# The caller sets NAME (the shipped fixture also sets SUFL_RUNNER_ARG from its own $1) and sources
# this file. It sets the shell options, scrubs AI_DLC_*, builds at load the worlds every arm needs,
# and owns the ONE EXIT trap: a scratch path is registered with `sufl_tmp`, never with a second trap.
# A world only some parts need is a BUILDER, called where that part runs, so the shipped fixture
# builds each one at the point the unsplit fixture did and no arm reads a state it did not.
#
# Every body below is the unsplit fixture's, moved; the comments explaining each seed moved with
# it. One body changed shape: `sr_required_inputs` reads its name list from a here-string rather
# than from a piped loop, because this file ships.
set -uo pipefail

# HERMETIC -- scrub the operator's tuning before reading anything (I10). Part 14 names
# AI_DLC_GATE_IN_SAFE_STOP, the key gate_record_open() reads, so without this the arm
# asserts against whatever the developer's settings.json happens to say.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ -n "${NAME:-}" ] || { echo "FIXTURE ERROR: lib.sh sourced without NAME set" >&2; exit 2; }

# Resolution is from THIS file's directory, so the shipped fixture and the battery resolve alike.
SUFL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The ONE EXIT trap. A path is registered once, when it is made, and removed at exit.
SUFL_TMPS=""
sufl_tmp() { SUFL_TMPS="${SUFL_TMPS}${1}
"; }
sufl_cleanup() {
  local p
  while IFS= read -r p; do [ -n "$p" ] && rm -rf "$p"; done <<< "$SUFL_TMPS"
}
trap sufl_cleanup EXIT

pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
RUNNER="$(pick "${SUFL_RUNNER_ARG:-}" "$SUFL_DIR/../../../core/skills/ai-dlc-update/reconcile/self-update-fixtures.sh" \
                        "$SUFL_DIR/../../skills/ai-dlc-update/reconcile/self-update-fixtures.sh" \
                        "$SUFL_DIR/../../../.claude/skills/ai-dlc-update/reconcile/self-update-fixtures.sh")"
[ -n "$RUNNER" ] || { echo "FIXTURE ERROR: cannot locate self-update-fixtures.sh" >&2; exit 2; }
RECONCILE="$(cd "$(dirname "$RUNNER")" && pwd)"

CONS="$(bash "$SUFL_DIR/seed.sh")"; sufl_tmp "$CONS"
CONS2="$(bash "$SUFL_DIR/seed.sh")"; sufl_tmp "$CONS2"
DIST="$(mktemp -d)"; sufl_tmp "$DIST"
WREPO="$(mktemp -d)"; sufl_tmp "$WREPO"
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
  # THE GATE'S OWN NAME CLASS, READ LINE BY LINE. An ASCII `[A-Za-z0-9._-]` class could not spell a
  # hook-named `café.sh`, so the seed left out an input the runner demands; and a `for` over the
  # capture split a name on whitespace. The class is self-update-gate.sh's INVOKED negation.
  # The names are CAPTURED, then read from a here-string. This file ships, and a shipped file
  # carries no piped `while`: the loop body would run in a pipeline subshell.
  sr_ivs="$(grep -oE 'scripts/ai-dlc/[^]['"'"'"`[:space:];|&()<>$*?{}\\/,:=#!@%+~]+\.sh' "$sr_h" | sort -u)"
  while IFS= read -r sr_iv; do
    [ -n "$sr_iv" ] || continue
    sr_n="${sr_iv#scripts/ai-dlc/}"
    if [ -f "$1/$sr_iv" ]; then
      printf '# input: %s\t%s\tcore/scripts/%s\n' "$sr_iv" "$(git hash-object "$1/$sr_iv" 2>/dev/null)" "$sr_n"
    else
      printf '# input: %s\tABSENT\tcore/scripts/%s\n' "$sr_iv" "$sr_n"
    fi
  done <<< "$sr_ivs"
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
    # THE STAMP AS THE GATE SAW IT, and it is OMITTED unless a caller asks for it. A record with
    # no such line is what every gate older than the field writes, and that is the state the
    # runner must still handle strictly -- so the DEFAULT seed here is deliberately the
    # pre-header record, and only the split-stamp arms below set `$SR_SKILL_COMMIT`.
    [ -n "${SR_SKILL_COMMIT:-}" ] && echo "# skill-commit: ${SR_SKILL_COMMIT}"
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

# The refusal list, read back as a SET rather than as N greps. The name class is a NEGATION --
# anything but whitespace and `/` -- because an ASCII enumeration could not spell a directory named
# `café` and read its row as absent; `/` stays out so a path-shaped row is still not a bare name.
# An equality against the whole
# list is what carries the exemptions: a `.dist-only` directory that stopped being exempt
# appears here, and no absence-shaped assertion has to be written for it separately.
cov_set() {
  { [ -n "${1:-}" ] && [ -f "$1" ]; } || return 0
  sed -n '/^COVERAGE: the diff changes/,/^$/p' "$1" \
    | sed -n 's/^  \([^[:space:]/][^[:space:]/]*\)$/\1/p' | sort | tr '\n' ','
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
    | sed -n 's/^  \([^[:space:]/][^[:space:]/]*\) .*$/\1/p' | sort | tr '\n' ','
}

# THE SAME LIST READ WITHOUT A CHARACTER CLASS, and it exists because `uns_set` above CANNOT
# SPELL THE SUBJECT OF A SLASH ROW. Its capture is `[^[:space:]/]` followed by a space, so a
# row opening `core/fixtures/ — ...` matches nothing at all and the reader returns EMPTY —
# byte-identical to a run that refused nothing. Measured on this branch: a path-shape refusal
# scored `uns_set` empty while the row was present and correct. The subject an empty-name
# argument must keep is exactly such a row, so the arm that asserts it needs a reader whose
# grammar can spell it: the first whitespace-delimited token, whatever characters it carries.
# A row that LOST its subject opens with the em dash instead, so the two states stay distinct.
# `LC_ALL=C` because the order is compared as a string and a locale-sensitive sort would make
# the same set read differently on another machine.
uns_subj() {
  { [ -n "${1:-}" ] && [ -f "$1" ]; } || return 0
  sed -n '/^COVERAGE: the named set contains/,/^$/p' "$1" \
    | sed -n 's/^  \([^ ][^ ]*\) .*$/\1/p' | LC_ALL=C sort | tr '\n' ','
}

# The per-fixture section names, IN ARGUMENT ORDER and deliberately not sorted. What two runs
# of the same set in two argument SPELLINGS must agree on is the sequence the loop actually
# walked, and a sort would hide a normalisation that reordered the positionals.
sec_set() {
  { [ -n "${1:-}" ] && [ -f "$1" ]; } || return 0
  sed -n 's/^===== FIXTURE \(.*\) =====$/\1/p' "$1" | tr '\n' ','
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

# A FOURTH BASE: a RECORDING gate whose write site was REFLOWED — the timestamp moved into its
# own variable, an ordinary edit that changes nothing. Under the exact-text token
# `/self-update-gate-$(date` this text scored 0 and the gate still recorded, so a consumer on it
# with its records deleted reached NOT-REQUIRED — the ACQUITTING direction, which is the one that
# matters. The composed filename fragment scores 1 here and 0 on the declaring gate above; Part
# G23 is the arm.
dput "core/skills/ai-dlc-update/reconcile/self-update-gate.sh" '#!/usr/bin/env bash
# the engine that RECORDS, with its write site reflowed across two lines
GATE_REC_DIR="$4/_bmad-output/ai-dlc-update"
mkdir -p "$GATE_REC_DIR"
_ts="$(date -u +%Y%m%dT%H%M%SZ)"
_rec_p="$GATE_REC_DIR/self-update-gate-${_ts}.md"
printf "# verdict: OK\n" > "$_rec_p"'
G add -A >/dev/null 2>&1; G commit -q --no-verify -m base-recording-reflowed >/dev/null 2>&1
D_BASE_REFLOW="$(G rev-parse HEAD 2>/dev/null)"

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

# AN INTERMEDIATE RELEASE THAT ALREADY CARRIES THE `theirs` CONTENT OF `gate-changed.sh`, AND IT
# IS THE SPLIT-STAMP WORLD. A consumer whose `skill_commit` sits here has had a PRIOR self-update
# deliver that file, so a gate run on its tree honestly records the `theirs` blob for a path the
# range changes -- satisfying the PRE-WRITTEN arm's first three conjuncts with no self-comparison
# having occurred. Without this commit the two cases cannot be separated: `$D_THEIRS` itself also
# carries that content, so a seed using it as the recorded `skill_commit` is the FORGED case
# (a gate re-run after the write, which advances the stamp to theirs) and not this one.
#
# IT SITS ON ITS OWN COMMIT AFTER `theirs` RATHER THAN BEFORE IT, because `base..theirs` must
# still CHANGE `gate-changed.sh` for the arm to be reachable at all -- an intermediate inside the
# range that already held the final content would make `base:P == theirs:P` for the seeded world
# and the arm would never be entered. `merge-base` is irrelevant here: the runner only ever asks
# for `<recorded-sha>:<core path>`, so any commit carrying the right blob is a valid world.
dput "core/scripts/gate-changed.sh" 'gate-changed at theirs'
dput "core/scripts/machinery.sh" 'at the split-stamp intermediate'
G add -A >/dev/null 2>&1; G commit -q --no-verify -m split-stamp-intermediate >/dev/null 2>&1
D_SPLIT="$(G rev-parse HEAD 2>/dev/null)"

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

# --- The G-parts' consumer tree and its helpers -------------------------------------------
GCONS="$(bash "$SUFL_DIR/seed.sh")"; sufl_tmp "$GCONS"
GLOG="$GCONS/_bmad-output/ai-dlc-update"
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

# The digest no content has: Parts G18 and G19, and Mutants G10 and G11.
GZERO=0000000000000000000000000000000000000000

# --- BUILDER: Part 20's blob-filtered clone, and the 030 record for its range ----------------
# Called where Part 20 runs. The arm's comments, which say why the seed is shaped this way, stay
# with the arm in run.sh. `filt_ok` is the discrimination condition both the arm and Mutant 15
# read before scoring anything over this clone.
build_filt_world() {
  f_base=""; f_missing=0; f_cat=""; f_rev=""; f_ctl=""
FILT_ROOT="$(mktemp -d)"; sufl_tmp "$FILT_ROOT"
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
  fi
}
filt_ok() {
  [ -n "$f_base" ] && [ "$f_missing" -ne 0 ] && [ "$f_cat" = ABSENT ] \
    && [ "$f_rev" = present ] && [ "$f_ctl" = ABSENT ]
}

# --- BUILDER: Part G21's three-commit distribution (also Mutant G11's) -----------------------
IG(){ git -C "$I_D" -c user.name=ai-dlc-fixture -c user.email=fixture@invalid \
                    -c commit.gpgsign=false "$@"; }
iput(){ mkdir -p "$(dirname "$I_D/$1")" && printf '%s\n' "$2" > "$I_D/$1"; }
build_i_world() {
I_D="$(mktemp -d)"; sufl_tmp "$I_D"
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
}

# --- BUILDER: Part 21's world, and the readers its arms and mutants share ---------------------
P21_DISC_WANT="tree:rp=1,ce=1 blob:rp=0,ce=1 ctl:rp=0,ce=0"
p21_obj() { # p21_obj <spec> -> move that loose object aside; 0 when it is gone
  local s; s="$(git -C "$P21D" rev-parse -q --verify "$1" 2>/dev/null)" || return 1
  [ -n "$s" ] && mv "$P21D/.git/objects/${s%"${s#??}"}/${s#??}" "$P21/gone-$s" 2>/dev/null
}
p21_rp() { git -C "$P21D" rev-parse -q --verify "p21-theirs:core/fixtures/$1" >/dev/null 2>&1 && echo 0 || echo 1; }
p21_ce() { git -C "$P21D" cat-file -e "p21-theirs:core/fixtures/$1" >/dev/null 2>&1 && echo 0 || echo 1; }
p21_newest() { ls -t "$P21LOG"/self-update-fixtures-*.md 2>/dev/null | head -1; }
# p21_over <runner> -> "rc=<n> why=<unconfirmed|deleted|other> keeper=<refused|kept>"
p21_over() {
  local rc=0 l w=other k=kept
  rm -f "$P21LOG"/self-update-fixtures-*.md
  bash "$1" "$P21D" p21-base p21-theirs "$P21C" treeless keeper >/dev/null 2>&1 || rc=$?
  l="$(p21_newest)"
  if grep -q '^  treeless — its .dist-only marker at .* could not be confirmed present or absent' "${l:-/dev/null}"; then w=unconfirmed
  elif grep -q '^  treeless — no run.sh at .*upstream deleted the driver' "${l:-/dev/null}"; then w=deleted; fi
  grep -q '^  keeper ' "${l:-/dev/null}" && k=refused
  printf 'rc=%s why=%s keeper=%s\n' "$rc" "$w" "$k"
}
# p21_diff <runner> -> "rc=<n> tag=<unconfirmed|uncovered|none> subject=<blobless|->"
p21_diff() {
  local rc=0 l t=none s=-
  rm -f "$P21LOG"/self-update-fixtures-*.md
  bash "$1" "$P21D" p21-base p21-theirs "$P21C" keeper >/dev/null 2>&1 || rc=$?
  l="$(p21_newest)"
  if grep -q '^COVERAGE: UNCONFIRMED' "${l:-/dev/null}"; then
    t=unconfirmed
    # A whole-line membership `case`, not `| grep -q`, which I54b refuses under pipefail.
    p21_sec="$(sed -n '/^COVERAGE: UNCONFIRMED/,/^$/p' "$l")"
    case "
$p21_sec
" in *"
  blobless
"*) s=blobless ;; esac
  elif grep -q '^COVERAGE: the diff changes' "${l:-/dev/null}"; then t=uncovered; fi
  printf 'rc=%s tag=%s subject=%s\n' "$rc" "$t" "$s"
}
build_p21_world() {
P21="$(mktemp -d)"; sufl_tmp "$P21"
P21D="$P21/dist"
P21C="$(bash "$SUFL_DIR/seed.sh")"; sufl_tmp "$P21C"
P21LOG="$P21C/_bmad-output/ai-dlc-update"
(
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
  git -c init.templateDir= init -q "$P21D" || exit 1
  PG() { git -C "$P21D" -c user.name=ai-dlc-fixture -c user.email=fixture@invalid \
                        -c commit.gpgsign=false "$@"; }
  for f in keeper treeless blobless; do
    mkdir -p "$P21D/core/fixtures/$f"
    printf 'p21 unique base %s\n' "$f" > "$P21D/core/fixtures/$f/run.sh"
  done
  PG add -A && PG commit -q --no-verify -m base && PG tag p21-base || exit 1
  printf 'p21 unique theirs blobless\n' > "$P21D/core/fixtures/blobless/run.sh"
  printf 'p21 unique marker: a mutation battery, never shipped\n' > "$P21D/core/fixtures/blobless/.dist-only"
  PG add -A && PG commit -q --no-verify -m theirs && PG tag p21-theirs || exit 1
) >/dev/null 2>&1
seed_record "$P21LOG" "$P21D" p21-base p21-theirs OK 021 >/dev/null 2>&1
p21_obj 'p21-theirs:core/fixtures/treeless'
p21_obj 'p21-theirs:core/fixtures/blobless/.dist-only'
P21_DISC="tree:rp=$(p21_rp treeless/.dist-only),ce=$(p21_ce treeless) blob:rp=$(p21_rp blobless/.dist-only),ce=$(p21_ce blobless/.dist-only) ctl:rp=$(p21_rp keeper/run.sh),ce=$(p21_ce keeper)"
}

# --- BUILDER: Part 22's mktemp stub, into <dir>, and its driver -------------------------------
p22_stub() { # <dir> -> P22S=<dir>, holding a `mktemp` that hands the runner a read-only staging dir
P22S="$1"; mkdir -p "$P22S"
P22_REAL_MKTEMP="$(command -v mktemp)"
printf '#!/bin/sh\ncase "$*" in\n  *su-stage.XXXXXX*) d="$(%s "$@")" || exit $?; chmod 555 "$d"; echo fired >> %s/fired; printf "%%s\\n" "$d" ;;\n  *) exec %s "$@" ;;\nesac\n' \
  "$P22_REAL_MKTEMP" "$P22S" "$P22_REAL_MKTEMP" > "$P22S/mktemp"
chmod +x "$P22S/mktemp"
}
# p22 <runner> <stubbed:yes|no> -> "rc=<n> staging=<refused|none> fired=<n>"
p22() {
  local rc=0 l s=none
  rm -f "$LOGDIR2"/self-update-fixtures-*.md "$P22S/fired"
  if [ "$2" = yes ]; then
    PATH="$P22S:$PATH" bash "$1" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" green-one >/dev/null 2>&1 || rc=$?
  else
    bash "$1" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" green-one >/dev/null 2>&1 || rc=$?
  fi
  l="$(newest_log2)"
  grep -q '^STAGING: REFUSED — the gate-record candidate list could not be staged' "${l:-/dev/null}" && s=refused
  printf 'rc=%s staging=%s fired=%s\n' "$rc" "$s" "$(grep -c . "$P22S/fired" 2>/dev/null || echo 0)"
}

# --- BUILDER: Part Q's non-ASCII distribution, the consumer half, and its driver -------------
QDG() { git -C "$QD" -c user.name=ai-dlc-fixture -c user.email=fixture@invalid -c commit.gpgsign=false "$@"; }
build_q_world() {
QD="$(mktemp -d)"; sufl_tmp "$QD"; QU="$(printf 'caf\303\251')"
git -c init.templateDir= init -q "$QD" >/dev/null 2>&1
for f in green-one plain-touched "$QU"; do
  mkdir -p "$QD/core/fixtures/$f"; printf 'at base\n' > "$QD/core/fixtures/$f/run.sh"
done
QDG add -A >/dev/null 2>&1; QDG commit -q --no-verify -m base >/dev/null 2>&1
QD_B="$(QDG rev-parse HEAD 2>/dev/null)"
printf 'at theirs\n' > "$QD/core/fixtures/plain-touched/run.sh"
printf 'at theirs\n' > "$QD/core/fixtures/$QU/run.sh"
QDG add -A >/dev/null 2>&1; QDG commit -q --no-verify -m theirs >/dev/null 2>&1
QD_T="$(QDG rev-parse HEAD 2>/dev/null)"
}
q_consumer() { # the 040 record and the two consumer-side copies, into $LOGDIR2 and $CONS2
seed_record "$LOGDIR2" "$QD" "$QD_B" "$QD_T" OK 040 >/dev/null \
  || bad "FIXTURE ERROR: could not seed the non-ASCII range's gate record"
# The consumer-side copies the named runs execute; removed again below so no later part sees them.
for f in plain-touched "$QU"; do
  mkdir -p "$CONS2/tests/fixtures/$f"
  printf '#!/usr/bin/env bash\necho "%s: every assertion held"\n' "$f" > "$CONS2/tests/fixtures/$f/run.sh"
done
}
# q_run <runner> <locale:utf8|c> <named...> -> "rc=<n> cov=<set> sec=<sections>"
q_run() {
  local r="$1" loc="$2" rc=0 L; shift 2
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  if [ "$loc" = c ]; then
    env -i PATH="$PATH" HOME="${HOME:-/}" LC_ALL=C bash "$r" "$QD" "$QD_B" "$QD_T" "$CONS2" "$@" >/dev/null 2>&1 || rc=$?
  else
    LC_ALL=en_US.UTF-8 bash "$r" "$QD" "$QD_B" "$QD_T" "$CONS2" "$@" >/dev/null 2>&1 || rc=$?
  fi
  L="$(newest_log2)"
  printf 'rc=%s cov=%s sec=%s\n' "$rc" \
    "$({ [ -n "$L" ] && sed -n '/^COVERAGE: the diff changes/,/^$/p' "$L" | sed -n 's/^  \([^ ][^ ]*\)$/\1/p' | LC_ALL=C sort | tr '\n' ','; } 2>/dev/null)" \
    "$(sec_set "$L")"
}
