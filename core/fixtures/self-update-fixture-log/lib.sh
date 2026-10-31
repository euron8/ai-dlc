# self-update-fixture-log/lib.sh -- the resolution, the seeded distribution and consumer trees,
# the per-part worlds and the log readers of self-update-fixture-log, sourced by that fixture's
# run.sh (the behavioural arms, shipped) (the retired mutation battery sourced it too).
# ONE copy, so every arm is driven against the very
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

DIST="$(mktemp -d)"; sufl_tmp "$DIST"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

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
# THE SHARED SUPPORT DIRECTORY, upstream's `lib/`: shipped with no run.sh and untouched by
# base..theirs, so Part 0's census is unmoved. Part D12s-lib writes it; `theirs-only-nodriver`
# above is Part D12s-seed's seed-only directory.
dput "core/fixtures/lib/inproc.sh" 'shared helpers every fixture sources; no driver of its own'
# A fixture whose run.sh BLOB Part D12u removes from a copy of this repo, so `cat-file -e` on it
# answers 1 with its tree still readable: the `.dist-only` read confirms an absence and the run.sh
# read can confirm neither. The content is unique so no other path shares the blob.
dput "core/fixtures/unreadable-driver/run.sh" 'a driver whose blob one copy of the distribution loses'
# A BLOB where a fixture directory would be, whose object the same copy loses, so the `.dist-only`
# and run.sh reads at theirs confirm an absence (no tree to descend) and the directory read can
# confirm neither: Part D12d's subject. Unique content, so no other path shares the blob.
dput "core/fixtures/flat-entry" 'a blob, not a directory, whose object one copy of the distribution loses'

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

SUFL_NL='
'
# aw_replace_once <src> <dst> <old> <new> -> <dst> is <src> with the ONE occurrence of <old> replaced;
# exit 3, and no <dst> worth reading, unless <old> occurs exactly once. awk rather than a `sed`
# (an `&` in the replacement is the whole match) and rather than python3 (a tool this shipping
# fixture would otherwise carry onto every consumer). index()/substr() are literal, not regex;
# the strings come in through ENVIRON, which `-v` would strip a level of backslashes from; the
# file is joined into one string so a multi-line <old> can match; LC_ALL=C so a multibyte byte in
# the subject cannot abort a BSD awk mid-file.
aw_replace_once() {
  AW_OLD="$3" AW_NEW="$4" LC_ALL=C awk '
    { s = s $0 "\n" }
    END {
      o = ENVIRON["AW_OLD"]; n = ENVIRON["AW_NEW"]
      if (o == "") exit 3
      c = 0; t = s
      while ((i = index(t, o)) > 0) { c++; t = substr(t, i + length(o)) }
      if (c != 1) exit 3
      i = index(s, o)
      printf "%s%s%s", substr(s, 1, i - 1), n, substr(s, i + length(o))
    }' "$1" > "$2"
}

# --- ck: the checker, driven with its four arguments, its stdout kept as the arm's log ----------
# The checker writes nothing into the consumer (the push wrapper runs it right before the hook, and
# a file appearing there would trip the hook's read-set skip), so the log an arm reads is the
# checker's own stdout, captured here. Fixture names an arm passes after the fourth argument are
# NOT forwarded: the checker refuses them, which is arm BH's subject and no other arm's.
CKD="$(mktemp -d)"; sufl_tmp "$CKD"
CK_N=0; CK_LAST=""
ck() { # ck <dist> <base> <theirs> <consumer> [ignored...] -> the checker's exit; its stdout echoed
  local rc=0
  CK_N=$((CK_N + 1)); CK_LAST="$CKD/ck-$CK_N.out"
  bash "$RUNNER" "$1" "$2" "$3" "$4" > "$CK_LAST" || rc=$?
  cat "$CK_LAST"
  return "$rc"
}
newest_glog() { printf '%s' "$CK_LAST"; }

# --- BUILDER: a consumer that is its OWN git repository, with a self-update commit on top -------
# For D9 and D12. The base commit holds an unrelated file; the second commit writes what the
# caller names under tests/fixtures/, as step 2's self-update commit would. No gate record exists,
# and `$D_BASE`'s gate records nothing, so the gate-record arm takes NOT-REQUIRED and the slice
# check is the only thing that can refuse.
sc_consumer() { # sc_consumer <dir> <relpath>... -> 0 when built; each relpath written with "exit 0"
  local c="$1" p; shift
  (
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
    git -c init.templateDir= init -q "$c" || exit 1
    [ "$(git -C "$c" rev-parse --absolute-git-dir 2>/dev/null)" = "$(cd "$c" && pwd -P)/.git" ] || exit 1
    printf 'base\n' > "$c/README"
    git -C "$c" add README || exit 1
    git -C "$c" -c user.name=ai-dlc-fixture -c user.email=fixture@invalid -c commit.gpgsign=false commit -q --no-verify -m base || exit 1
    for p in "$@"; do mkdir -p "$c/$(dirname "$p")" && printf 'exit 0\n' > "$c/$p" || exit 1; done
    git -C "$c" add -- tests || exit 1
    git -C "$c" -c user.name=ai-dlc-fixture -c user.email=fixture@invalid -c commit.gpgsign=false commit -q --no-verify -m self-update || exit 1
  ) >/dev/null 2>&1
}
