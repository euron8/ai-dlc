#!/usr/bin/env bash
#
# validate-enforcement-map.sh
#
# Distribution-only integrity check for core/skills/ai-dlc/enforcement-map.yaml
# — the derived machine index of the gate-validation check catalog and its
# enforcement bindings. Runs upstream (repo-root scripts/, alongside
# audit-machinery-efficacy.js); NOT shipped to consumers via install.sh.
#
# The enforcement-map has no independent authority: it is only ever a VALIDATED
# view of steps/gate-validation.md. This script is what keeps it honest. It
# asserts:
#
#   I1  catalog ⊆ map   — every real CHECK_LOADED anchor in gate-validation.md
#                         has an entry under `checks:` in the map.
#   I2  map ⊆ catalog   — every `checks:` entry corresponds to a real anchor
#                         (catches a stale entry left after a check is removed).
#   I3  gate-type sync  — for every (gate_type, check) pair in the GATE_MANIFEST
#                         block, the map entry's gate_types list contains that
#                         type (the id/gate_type columns cannot drift from the
#                         authoritative manifest).
#   I4  no dormant binding — every enforcer/ci_workflow path the map references
#                         exists on disk; every named fixture exists under
#                         core/fixtures/. (This is the check the v0.27.0
#                         machinery-efficacy audit found missing.)
#   I5  core_manifest sync — core-manifest.md and reconcile/setup-sites.md list
#                         the same logical core file set (prefix-normalized).
#                         Both files flag this hand-synced duplication as a
#                         hazard; this asserts they never silently diverge.
#   I6  heading ⇔ anchor — every check heading is `### <id>.` (never
#                         `### Check <id>.`) and its id set equals the anchor set.
#                         Nothing tied the two together, so v0.48.0's
#                         `### Check 24.` passed I1-I5 while going invisible to
#                         every anchor extractor in the distribution and in the
#                         consumer-shipped layer linter at once.
#   I7  fixture ⇔ manifest — check-manifest-bypass/seed.sh seeds exactly the
#                         universal core + PLANNING row and none of the
#                         IMPLEMENTATION row. Its anchor list is hand-maintained and
#                         had already rotted (the manifest gained check 24, the
#                         fixture did not), so H1's self-test was seeding a slice
#                         that no longer existed.
#   I20 fixture ⇒ driver — every fixture under core/fixtures/ has a run.sh, or a
#                         README declaring why one is impossible. pre-push skips a
#                         driverless fixture silently, so it reads exactly like one
#                         that passed; two adversarial fixtures sat in that hole for
#                         their whole existence. Exemptions are derived from the
#                         READMEs, never hand-listed here.
#   I21 reconcile helpers single-homed — no reconcile/*.sh redefines a helper that
#                         reconcile/lib.sh already owns, and none calls one without
#                         sourcing lib.sh. `section_of()` shipped divergent twice
#                         (v0.52.0, v0.54.2); v0.90.0 collapsed the three copies but
#                         nothing stopped a fourth. The helper set is derived from
#                         lib.sh, never hand-listed.
#   I9  enforcer ⇒ call site — every `adjudication: script` entry declares
#                         `call_sites:` with a posture (W1), and no declared site
#                         is fictional — the file it names must at least know the
#                         enforcer exists (W2). W2 canNOT tell an invocation from a
#                         prose mention; see its inline note. The teeth are W1 plus
#                         the reviewable `posture:`. The map recorded WHO enforces each
#                         rule (38/38) and WHERE it runs (1/38), so "Enforced by
#                         validate-X.sh" was a claim nothing could falsify. That
#                         is how validate-steering-budget.sh came to sit on 11
#                         real starvation violations while invoked from zero
#                         gates, and why implementation.md could say it "fails
#                         the gate" when it ran at no gate at all.
#   I8  fixture packaging — core/fixtures/, install.sh's fixture loop, and
#                         uninstall.sh's fixture loop name the same set. All three
#                         are hardcoded and had drifted (9 on disk, 9 installed, 5
#                         uninstalled). A fixture missing from install.sh reaches no
#                         consumer at all — an adversarial self-test that silently
#                         does not exist, while the catalog claims coverage. Dist-only
#                         fixtures are DERIVED from a `.dist-only` marker beside the
#                         fixture, not a hand-maintained exemption string.
#   I10 fixture hermeticity — a fixture that drives a hook must scrub ambient AI_DLC_*
#                         first, or a consumer's sanctioned tunable makes it fail against
#                         a hook behaving correctly, and the pre-push gate blocks every push.
#   I11 convergence-cycle scope — the three sets that must be one set (steps that dispatch
#                         an adversarial REVIEW, steps that reference the REPAIR dispatch,
#                         and Check 24's Scope sentence) are DERIVED and asserted equal. A
#                         step in the first but not the third runs a convergence loop no
#                         gate reads — which reads exactly like a loop that converged. The
#                         list was hand-maintained and rotted twice (v0.58.0 caught two of
#                         three; carry-over-evaluation was the third).
#   I12 drift-scan coverage bound — reconcile/unregistered-drift.sh's hand-listed scan set is
#                         bound to a reviewed per-subtree policy: every core/skills/<skill>/ and
#                         core/<dir>/ is classified scan|exempt:<reason>, and the scan-marked set
#                         must EQUAL the tool's ls-tree. The list rotted twice (ai-dlc-setup/ in
#                         v0.63.0, schemas/ this release) — a new core dir escaping the scan reads
#                         exactly like a dir with no drift. Now a new subtree fails the build until
#                         it is classified.
#   I43 consumer machinery home is ONE string — the directory the core-guard tells an author
#                         to put their own pipeline tooling in was hand-written in five shipped
#                         surfaces and declared in none, joined by nothing. Both directions: no
#                         core file names a scripts/ai-dlc* path other than core's own home and
#                         the declared one, AND the guard's deny text still routes to the declared
#                         home. A home no affordance points at is one no author finds.
#   I44 core never writes the home — core-manifest.md and the guard both promise, in those
#                         words, that core "never reads, never writes and never overwrites" it.
#                         Nothing asserted it. Derived from install.sh/uninstall.sh's targets and
#                         the core_manifest globs, with a positive control so a broken extractor
#                         cannot report the same clean result as a correct one.
#   I45 core allocates BELOW the reserved consumer band — the other half of E15's partition.
#                         E15 tells a consumer its check and rule numbers live at BAND_FLOOR and
#                         above; that is worth nothing unless core is held to the complement,
#                         because the guarantee a consumer buys is "core will never allocate the
#                         number you just took". Derived from steps/gate-validation.md's check
#                         anchors and SKILL.md's rule headings using the SHIPPING grammars, never
#                         hand-listed, with a zero guard on each extraction: an empty catalog
#                         contains nothing above the floor and would pass this exactly like a
#                         conforming one. The floor is READ from validate-layer-entries.sh rather
#                         than restated, so the two halves of the partition cannot drift apart —
#                         a second spelling of 900 could declare a range safe that core is still
#                         allocating from.
#   I61 the prose home states the SAME SEVERITY the contract declares — I38 asks only that the
#                         home MENTIONS the clause id, which a bullet whose every other word has
#                         gone stale satisfies. Three had: LC-N5 said WARN one release after its
#                         promotion to ERROR rewrote 24 lines of that same bullet, and LC-E4 /
#                         LC-E14 said WARN against ADJUDICATED, which blocks `apply`. The
#                         severity vocabulary is derived from the contract's own level: values,
#                         and a clause bullet stating no severity is itself an error — otherwise
#                         the join empties one bullet at a time.
#   I62 prose that NAMES a contract code cites the clause that claims it. The shape I38 and I61
#                         both leave open: I38 is satisfied by one mention of an id anywhere in
#                         the file, I61 only inspects bullets that already carry one. Prose that
#                         states a duty, names its code and cites no clause was live in ELEVEN
#                         places. Keyed on the CODE, not on a MUST/NEVER keyword scan — that
#                         predicate's false-positive set never emptied at any of three grains,
#                         and one 100%-bound home names no code at all, so it cannot even detect
#                         binding. Scope is derived per file from I63's role. Vacuity is defended
#                         by a two-directional probe the invariant writes and runs each time,
#                         not by a count a corpus edit retires.
#   I63 the contract PINS the files it absorbed, and each still is what it says — home, pointer
#                         or none. `prose_home:` alone cannot close this: it is written per
#                         clause, so a file that stops carrying clauses stops appearing, and its
#                         silence is identical to a file never in scope. Two of the four sites
#                         the contract claims to have absorbed carried zero clauses for nineteen
#                         releases with nothing able to say so. Both directions, so the list
#                         cannot fall behind the contract.
#   I65 every clause names the FIXTURE that proves it, that fixture drives the clause's own
#                         declared enforcer, and it names the clause's code where a run can
#                         attribute it. I64 binds the code to an emission SITE; this binds the
#                         clause to the PROOF that the site fires. `fixture: none` is a declared,
#                         counted gap rather than an absence, and a reverse arm stops `none` from
#                         being written over a fixture that would satisfy the join.
#
# Tool dependencies: bash ≥3.2, grep, sed, awk, sort, comm. No hard dep on
# jq/yq/rg — the map is authored line-oriented so the portable subset parses it
# (same posture as validate-ci-gates.sh).
#
# Usage:
#   validate-enforcement-map.sh                 run every arm
#   validate-enforcement-map.sh --arms I8,I45   run only the units declaring those ids
#
# Exit codes:
#   0 — all invariants hold
#   1 — one or more invariants violated (drift / dormant binding)
#   2 — tool-availability, missing-input, or arm-selection failure

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GV="$REPO_ROOT/core/skills/ai-dlc/steps/gate-validation.md"
MAP="$REPO_ROOT/core/skills/ai-dlc/enforcement-map.yaml"
CORE_MANIFEST="$REPO_ROOT/core/skills/ai-dlc/core-manifest.md"
SETUP_SITES="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/setup-sites.md"

for f in "$GV" "$MAP" "$CORE_MANIFEST" "$SETUP_SITES"; do
  if [ ! -f "$f" ]; then
    echo "tool-fail: required input not found: $f" >&2
    exit 2
  fi
done

fail=0
err() { echo "FAIL: $*" >&2; fail=1; }

# --- The fork budget: this script's cost, stated as CODE rather than as prose --------------
#
# THIS SCRIPT'S COST IS PROCESS SPAWN, MEASURED RATHER THAN ASSUMED. Nothing here is compute:
# the files are small and the patterns are literals. The suite runs this script more than a
# hundred times per full push, so its fork count is a large fraction of everything the fixture
# suite computes, and an invariant added as a per-file loop is a change to the suite's wall
# clock whether or not its author looked.
#
# THE NUMBER IS EXECUTABLE BECAUSE THE PROSE VERSION DECAYED 4.1x AND NOTHING NOTICED. This
# paragraph used to state "1582 external commands, 643 of them grep" in a sentence. It was true
# when written and no program read it; re-measured with scripts/fork-profile.sh the same
# quantity is 6553, and the sentence still read exactly like a fresh measurement. `FORK_BUDGET`
# is that sentence with a reader: core/fixtures/validator-fork-budget/ profiles a real run and
# fails the push when the count crosses it, and fails it the other way when the budget has
# ratcheted so far above the truth that nothing could ever cross it.
#
# WHAT IS COUNTED, EXACTLY: external commands this script's own trace shows it invoking. It is
# not total process creations -- every `$( )` also forks a subshell that no trace line reports,
# so the real process count is higher by a constant shape. That bias cancels in a like-for-like
# comparison, which is all a budget ever asks; see fork-profile.sh's header.
#
# RAISING IT IS MEANT TO BE A ONE-LINE REVIEWABLE DIFF, and there is deliberately NO
# environment override. A budget a stray `AI_DLC_*` key could lift is an instruction that
# ships its own opt-out, and it would additionally put this file in I87's readable-key set for
# a tunable no consumer has any business setting.
#
# A WALL-CLOCK BUDGET WAS REJECTED, and the reason is not squeamishness about timing. This
# script is invoked from fixtures that run inside a 16-wide worker pool, nine of which open
# inner pools of their own; a wall reading taken there measures contention, not this file. And
# a threshold with enough headroom to survive a loaded box cannot resolve the size of
# regression that matters -- one invariant added as a nested loop moved this script 39% and
# the whole suite by minutes. Fork count is deterministic and load-independent: load does not
# change how many times a script calls execve.
FORK_BUDGET=7050

# --- Fork-free membership, and the reason it is worth a helper ------------------
#
# The single worst shape is an exact-line membership test against a string ALREADY IN MEMORY,
# written as `grep -qxF -- "$x" <<<"$list"`. That forks a process and builds a here-string to
# answer a question bash can answer with a glob. Measured, 2000 iterations of each:
#
#     grep -qxF -- b <<<"$L"    3.717s        case "$L" in ... 0.007s      ~530x
#
# `in_lines` is that glob. It wraps both sides in newlines so the match is a WHOLE LINE and
# never a substring of one — `E1` must not satisfy a list containing only `E10`, which is the
# same two-digit hazard I36 reverse already carries a comment about.
#
# A NEEDLE MUST NOT BE EMPTY. An empty needle becomes "\n\n", which matches any list holding a
# blank line, so every caller either guards for emptiness first or is reading from a generator
# that cannot emit one. Stated because the failure would be a silent PASS, which is this
# repository's whole subject.
in_lines() {
  case "
$2
" in
    *"
$1
"*) return 0 ;;
  esac
  return 1
}

# `in_body <needle> <file-contents>` — the substring form, replacing `grep -qF -- x FILE`
# once the file has been read into a variable. Callers read with `$(<file)`, which measured
# 0.83ms against 2.04ms for `$(cat file)`; where a loop revisits one file they hold the body
# in a last-file memo, so a run of clauses sharing an enforcer reads it once. The memo is a
# plain string pair rather than an associative array because this must run under bash 3.2,
# which macOS still ships and which has no `declare -A`. The same string-memo idiom is already
# in this file at w2_cache.
in_body() {
  case "$2" in *"$1"*) return 0 ;; esac
  return 1
}

# The memo pairs, declared here because this script runs under `set -u` and a memo is by
# definition read before it is first written. Empty is the correct initial value: no path
# equals "", so the first clause of every loop takes the read branch.
_i36_body_of=""; _i36_body=""
_i38_body_of=""; _i38_body=""

# --- ARM SELECTION: `--arms I<n>[,I<n>...]` runs one arm's UNIT, not the whole file --------
#
# WHY THIS EXISTS. The three mutation batteries invoke this script once per assertion, and
# each assertion tests exactly one invariant. Measured: 137 invocations per full suite run at
# ~15.7s each, about 49% of everything the fixture suite computes, to exercise one arm at a
# time. The cost attributable to every line ABOVE the first arm header -- which includes
# executing every helper defined there -- is 0.1s of 13.8s, 0.7%. So selection pays
# essentially no fixed tax, and a selected run costs the prologue plus its own unit.
#
# THE SUBPROGRAM IS GENERATED FROM THE SHIPPED EXTRACTOR, NEVER FROM A FRESH GREP.
# `render-invariant-index.sh --arm-lines` serves the one arm-header grammar this repo has,
# and the reason it is served rather than copied is recorded in that file: a column-0 pattern
# finds 83 of the header-shaped lines here and a blanks-tolerant one finds 96, and the
# thirteen it drops are silently merged into the preceding arm's bucket. A misplaced boundary
# here means a selected arm's body is attributed to its neighbour and DOES NOT RUN, which
# reads exactly like an arm that passed. A second region-finder would be a second set of bugs.
#
# WHY THE SELECTABLE UNIT IS THE COLUMN-0 ARM AND NOT EVERY ARM. Ten arm headers are
# INDENTED, because they sit inside an enclosing block -- nine inside the layer contract's
# `if [ -f "$lc_file" ]`, one inside I31's. Their line ranges are not balanced shell, so a
# subprogram sliced at one of them does not parse. A UNIT is therefore a column-0 arm header
# through the line before the next one, and an indented arm is reached by selecting the unit
# that contains it. All 81 units were checked to parse standalone; if a future edit breaks
# that, `eval` below returns instead of reaching the verdict and this exits 2 rather than
# falling through -- a syntax error must never be reported as exit 1, which a battery would
# read as the mutant it seeded being killed.
#
# WHY IT IS A FLAG AND NOT AN ENVIRONMENT KEY. I10 requires a fixture driving a hook to scrub
# every ambient `AI_DLC_*` name and `enforcement-map-sites/run.sh` does exactly that, so an
# `AI_DLC_ARMS` would be unset before it was read and every caller would silently fall back
# to running everything -- a mechanism that cannot fire, reading exactly like one that fired.
#
# NO PER-ID "CAN THIS ARM EMIT" GUARD IS NEEDED, AND THAT IS A PARTITION RATHER THAN AN
# OMISSION. `--arm-lines` runs the renderer's self-probe and every totality assertion BEFORE
# it prints a line: zero orphan emitters, zero SILENT arms, zero ID collisions, non-zero arm
# count. By the time a range reaches this code, an id whose region contains no emitter is
# unconstructible; the failure surfaces as the renderer's non-zero exit, handled here as 2.
#
# `# requires-arms: I<n> ...` IS THE ESCAPE HATCH FOR A VALUE THAT CANNOT BE HOISTED. Most
# cross-unit reads were fixed by moving the value above the first arm header (see the hoist
# block below). Three are another arm's DERIVED OUTPUT rather than a constant, and hoisting
# them would make every selected run pay for a derivation it does not use; those units carry
# a marker naming what they need and selection takes the transitive closure. The marker is
# checked for naming declared ids on every `--arms` run whether or not its unit is selected,
# because a typo in a declaration nothing reads is a declaration that stops working silently.
ARMS_SEL=""
case "${1:-}" in
  "")     : ;;
  --arms) ARMS_SEL="${2-}"
          if [ "$#" -ne 2 ] || [ -z "$ARMS_SEL" ]; then
            echo "usage: ${0##*/} [--arms I<n>[,I<n>...]]" >&2; exit 2
          fi ;;
  *)      echo "usage: ${0##*/} [--arms I<n>[,I<n>...]]" >&2; exit 2 ;;
esac

# The selector, as one awk program over (the served arm map, this file). It emits the
# subprogram on stdout, or a reason on stderr and a non-zero exit. Everything is validated in
# END before a single line is printed, so a partial program can never be handed to `eval`.
ARMS_SELECT_AWK='
BEGIN { FS = "\t" }
{ if ($1 ~ /^[0-9]+$/) { hdr[$1 + 0] = $2; nhdr++ } }
END {
  if (nhdr == 0) { print "the arm map is empty" > "/dev/stderr"; exit 2 }
  bad = ""
  ln = 0; nu = 0; verdict = 0; nverd = 0
  while ((getline l < src) > 0) {
    ln++
    if (ln in hdr) {
      if (l ~ /^#/) { nu++; ustart[nu] = ln; uids[nu] = hdr[ln] }
      else if (nu == 0) { bad = bad "  an indented arm header at line " ln " precedes every column-0 one\n" }
      else { uids[nu] = uids[nu] " / " hdr[ln] }
    }
    if (l ~ /^# --- Verdict/) { verdict = ln; nverd++ }
    if (match(l, /^[[:blank:]]*#[[:blank:]]*requires-arms:[[:blank:]]*/)) {
      r = substr(l, RSTART + RLENGTH)
      gsub(/[^A-Za-z0-9]+/, " ", r)
      if (nu == 0) bad = bad "  a requires-arms: marker at line " ln " sits outside every arm\n"
      else { req[nu] = req[nu] " " r; reqline[nu] = ln }
    }
  }
  close(src)
  if (nu == 0) bad = bad "  no column-0 arm header was found in " src "\n"
  if (nverd != 1) bad = bad "  expected exactly one epilogue anchor line matching /^# --- Verdict/, found " nverd "\n"
  if (nu > 0 && verdict <= ustart[nu]) bad = bad "  the epilogue anchor at line " verdict " is not below the last arm header\n"
  if (bad != "") { printf "%s", bad > "/dev/stderr"; exit 2 }

  for (i = 1; i < nu; i++) uend[i] = ustart[i + 1] - 1
  uend[nu] = verdict - 1

  for (i = 1; i <= nu; i++) {
    s = uids[i]
    while (match(s, /I[0-9]+[a-c]?/)) {
      id = substr(s, RSTART, RLENGTH)
      # An OVERVIEW header and the sub-arm implementing it both name the id -- `I36/I37/I38`
      # above `I37`s own indented arm -- and both fall in the same unit, which is the whole
      # point of merging indented arms upward. Only a repeat across two DIFFERENT units is a
      # collision, and the renderer already fails the push on the solo form of that.
      if ((id in unitof) && unitof[id] != i) bad = bad "  id " id " is declared by two units\n"
      unitof[id] = i
      s = substr(s, RSTART + RLENGTH)
    }
  }

  for (i = 1; i <= nu; i++) {
    if (!(i in req)) continue
    m = split(req[i], rr, /[[:blank:]]+/)
    for (k = 1; k <= m; k++) {
      id = rr[k]
      if (id == "") continue
      if (!(id in unitof)) { bad = bad "  the requires-arms: marker at line " reqline[i] " names " id ", which no arm declares\n"; continue }
      if (unitof[id] == i) bad = bad "  the requires-arms: marker at line " reqline[i] " names " id ", an id its own unit declares\n"
    }
  }
  if (bad != "") { printf "%s", bad > "/dev/stderr"; exit 2 }

  nsel = 0; nbadid = 0
  m = split(want, w, /[,[:blank:]]+/)
  for (k = 1; k <= m; k++) {
    id = w[k]
    if (id == "") continue
    if (!(id in unitof)) { print "no arm declares " id > "/dev/stderr"; nbadid++; continue }
    if (!sel[unitof[id]]) { sel[unitof[id]] = 1; nsel++ }
  }
  if (nbadid > 0) exit 2
  if (nsel == 0) { print "--arms selected nothing" > "/dev/stderr"; exit 2 }

  changed = 1
  while (changed) {
    changed = 0
    for (i = 1; i <= nu; i++) {
      if (!sel[i] || !(i in req)) continue
      m = split(req[i], rr, /[[:blank:]]+/)
      for (k = 1; k <= m; k++) {
        id = rr[k]
        if (id == "") continue
        j = unitof[id]
        if (!sel[j]) { sel[j] = 1; changed = 1 }
      }
    }
  }

  for (i = 1; i <= nu; i++) if (sel[i]) for (x = ustart[i]; x <= uend[i]; x++) keep[x] = 1
  ln = 0
  while ((getline l < src) > 0) {
    ln++
    if (ln < ustart[1] || ln >= verdict || (ln in keep)) print l
  }
  close(src)
}
'

if [ -n "$ARMS_SEL" ]; then
  arms_renderer="$REPO_ROOT/scripts/render-invariant-index.sh"
  if [ ! -f "$arms_renderer" ] || [ ! -r "$0" ]; then
    echo "validate-enforcement-map: --arms needs $arms_renderer and a readable \$0 ('$0'); one is missing." >&2
    exit 2
  fi
  # THE SOURCE IS PASSED EXPLICITLY, and that is load-bearing rather than tidy. The renderer
  # locates its own root by walking up for a VERSION marker, and the seeded trees the mutation
  # batteries build carry core/, scripts/, .githooks/ and templates/ but no VERSION -- so an
  # argument-less call walks to / and exits 2 inside every sandbox this mode exists to serve.
  # Measured before this line was written: `--arms I45` inside enforcement-map-sites' own seed
  # failed exactly that way.
  arms_map="$(bash "$arms_renderer" --arm-lines "$0" 2>&1)"
  if [ "$?" -ne 0 ] || [ -z "$arms_map" ]; then
    echo "validate-enforcement-map: --arms cannot resolve arm boundaries — render-invariant-index.sh --arm-lines failed:" >&2
    printf '%s\n' "$arms_map" >&2
    exit 2
  fi
  arms_prog="$(awk -v want="$ARMS_SEL" -v src="$0" "$ARMS_SELECT_AWK" <<<"$arms_map")"
  if [ "$?" -ne 0 ] || [ -z "$arms_prog" ]; then
    echo "validate-enforcement-map: --arms '$ARMS_SEL' selected no runnable subprogram. Nothing was checked." >&2
    exit 2
  fi
  set --
  eval "$arms_prog"
  echo "validate-enforcement-map: the --arms subprogram returned without reaching the verdict block. That is a generated-program failure, not an invariant violation, so this exits 2 rather than 1." >&2
  exit 2
fi

# --- Values and helpers HOISTED above the first arm header --------------------------------
#
# Each of these was assigned inside one arm's region and read from another's. That coupling
# is invisible while the file always runs top to bottom, and it is a defect the moment one
# unit runs alone: under `set -u` a missing name is a loud crash in the MAIN shell, but the
# same read inside a `$( )` kills only the subshell -- measured, `i54_files` read that way
# exits 0 with the arm silently evaluating an empty subject. The hoist is what makes the
# reads unconditional; it changes no behaviour in a full run, which the all-ids byte-identity
# assertion in core/fixtures/validator-arm-selection/ checks on every push.
TEMPLATE="$REPO_ROOT/templates/settings.json.template"      # set at I13, read by I14
SETTINGS_TMPL="$REPO_ROOT/templates/settings.json.template" # set at I22, read by I22b
PP_DIST="$REPO_ROOT/.githooks/pre-push"                     # set at I30, read by I66
PP_CONS="$REPO_ROOT/core/git-hooks/pre-push"                # set at I30, read by I66
LC_YAML="$REPO_ROOT/core/skills/ai-dlc/layer-contract.yaml" # set at I67, read by I70 and I73

# Set at I35, read by I52. Derived from this file's own text, so it does not depend on any
# arm having run -- which is what makes hoisting it a move rather than a reordering.
em_marker="$(sed -n "s/^EXEMPT_MARKER='\(.*\)'$/\1/p" "$REPO_ROOT/scripts/validate-enforcement-map.sh" | head -1)"

# Defined here rather than at I5 because I8, I26 and I28 need it too, and I5's own use is
# further down the file. Pure function; its only input is $1.
norm_core_manifest() {
  awk '
    /^core_manifest:/ {f=1; next}
    f && /^  - / {v=$0; sub(/^  - /,"",v); print v; next}
    f {f=0}
  ' "$1" | sed -E 's#^core/skills/ai-dlc/##; s#^core/##' | sort -u
}

# --- Catalog anchor set -------------------------------------------------------
# Real anchors sit at column 0 directly under a check heading. Inline format
# EXAMPLES in the manifest/H1 prose are mid-line (backtick-prefixed) and carry
# the literal placeholder "<id>" — both are excluded.
anchors="$(grep -oE '^<!-- CHECK_LOADED: [^ ]+ -->' "$GV" \
           | sed -E 's/^<!-- CHECK_LOADED: (.+) -->$/\1/' \
           | grep -vF '<id>' | sort -u)"

# --- Map check-id set (under `checks:` only, not `non_catalog_units:`) ---------
map_ids="$(awk '
  /^checks:/ {inck=1; next}
  /^non_catalog_units:/ {inck=0}
  inck && /^  - id:/ { v=$0; sub(/^  - id:[ ]*/,"",v); gsub(/"/,"",v); print v }
' "$MAP" | sort -u)"

# --- I1 / I2: set equality between the catalog anchor set and the map's check ids ---
# The arm header is the DECLARATION render-invariant-index.sh derives from, and this arm
# carried a plain `#` comment instead, so both invariants were live and absent from every
# enumeration of them. The two emitters below were the only two in the file sitting outside
# any declared arm.
missing_in_map="$(comm -23 <(printf '%s\n' "$anchors") <(printf '%s\n' "$map_ids"))"
stale_in_map="$(comm -13 <(printf '%s\n' "$anchors") <(printf '%s\n' "$map_ids"))"
[ -n "$missing_in_map" ] && err "catalog check(s) with no enforcement-map entry: $(echo $missing_in_map)"
[ -n "$stale_in_map" ]   && err "enforcement-map entr(y/ies) with no CHECK_LOADED anchor: $(echo $stale_in_map)"

# --- I6: heading form <-> anchor set ------------------------------------------
# NOTHING tied a check's HEADING to its CHECK_LOADED anchor, so the heading could
# drift from the catalog with CI green. Not hypothetical: v0.48.0 shipped
# `### Check 24.` while every other check is `### 24.`, with a correct
# `<!-- CHECK_LOADED: 24 -->` under it. I1-I5 all passed. But every anchor
# extractor — here, in reconcile/layer-drift.sh, in the consumer-shipped
# validate-layer-entries.sh, and in audit-machinery-efficacy.js — keys on
# `^### <n>.`, so check 24 went invisible to all of them at once. That included
# the one check that would have caught the number collision v0.48.0 itself created,
# and the efficacy auditor, which silently folded check 24's token cost into 23.
# A one-character heading deviation disabled four tools. This is the invariant that
# was missing.
#
# Two word-titled checks (Core-layer immutability, the gate-failure protocol) carry
# anchors but are prose-headed by design. They are NAMED, not pattern-matched, so a
# third one has to be added here deliberately rather than slipping in.
WORD_ANCHORS='core-layer-immutability|failure'

bad_form="$(grep -nE '^#{2,4}[[:space:]]+Check[[:space:]]+[0-9]' "$GV")"
[ -n "$bad_form" ] && err "check heading(s) written '### Check <n>.' — the catalog form is '### <n>.'. Every anchor extractor keys on the latter, so this form hides the check from all of them: $(echo $bad_form)"

head_ids="$(grep -oE '^### ([0-9]+[a-z]?|H[0-9]+)\.' "$GV" | sed -E 's/^### //; s/\.$//' | sort -u)"
anchor_ids="$(printf '%s\n' "$anchors" | grep -vE "^($WORD_ANCHORS)$" | sort -u)"
no_anchor="$(comm -23 <(printf '%s\n' "$head_ids") <(printf '%s\n' "$anchor_ids"))"
no_head="$(comm -13 <(printf '%s\n' "$head_ids") <(printf '%s\n' "$anchor_ids"))"
[ -n "$no_anchor" ] && err "check heading(s) with no CHECK_LOADED anchor: $(echo $no_anchor)"
[ -n "$no_head" ]   && err "CHECK_LOADED anchor(s) with no '### <id>.' heading: $(echo $no_head)"

# --- I3: GATE_MANIFEST (gate_type, check) pairs vs map gate_types -------------
# Per-id gate_types csv from the map.
gt_lookup="$(awk '
  /^checks:/ {inck=1; next}
  /^non_catalog_units:/ {inck=0}
  inck && /^  - id:/ {
    if (id != "") print id"\t"gt;
    id=$0; sub(/^  - id:[ ]*/,"",id); gsub(/"/,"",id); gt=""
  }
  inck && /^    gate_types:/ {
    gt=$0; sub(/^    gate_types:[ ]*\[/,"",gt); sub(/\][ ]*$/,"",gt); gsub(/ /,"",gt)
  }
  END { if (id != "") print id"\t"gt }
' "$MAP")"
# Leading newline so the first entry is reachable by the same `\n<id><TAB>` probe as the rest.
gt_nl="
$gt_lookup"

# Each manifest row: | <type> | <id, id, ...> |. Skip header + separator rows.
while IFS= read -r row; do
  case "$row" in
    *"Gate type"*|*"---"*) continue ;;
  esac
  # Field split and lookup done in the shell: the row is `| <type> | <ids> | ...` and
  # gt_lookup is `<id><TAB><csv>` lines, so awk/tr/grep/cut per row and per id bought
  # nothing but forks. Same fields, same comma split, same whitespace stripping.
  gtype="${row#*|}"; gtype="${gtype%%|*}"; gtype="${gtype// /}"
  ids="${row#*|}"; ids="${ids#*|}"; ids="${ids%%|*}"
  [ -z "$gtype" ] && continue
  # split ids on comma
  oldIFS="$IFS"; IFS=','
  for cid in $ids; do
    cid="${cid// /}"
    [ -z "$cid" ] && continue
    entry=""
    case "$gt_nl" in
      *"
$cid	"*) entry="${gt_nl#*"
$cid	"}"; entry="${entry%%
*}"; entry="$cid	$entry" ;;
    esac
    if [ -z "$entry" ]; then
      err "GATE_MANIFEST names check $cid ($gtype) but the map has no such entry"
    else
      csv="${entry#*	}"
      case ",$csv," in
        *",$gtype,"*) : ;;
        *) err "map entry $cid omits gate_type '$gtype' that GATE_MANIFEST requires (has: $csv)" ;;
      esac
    fi
  done
  IFS="$oldIFS"
done <<EOF
$(awk '/<!-- GATE_MANIFEST v1 -->/{f=1;next} /<!-- GATE_MANIFEST_END -->/{f=0} f && /^\|/{print}' "$GV")
EOF

# --- I7: check-manifest-bypass fixture vs the manifest it exists to test -------
# The fixture seeds "universal core + the PLANNING row" and then declares gate type
# `implementation`, so H1 must fail on the implementation row's absent anchors.
# Both halves of that sentence are a hand-maintained anchor list inside seed.sh, and
# the planning half had already rotted: the manifest gained check 24 and the fixture
# did not, so the seed no longer seeded what its own prose claimed. A fixture that
# has drifted from the manifest is not a self-test, it is a decoration. Assert both
# directions against the live manifest instead of trusting the copy.
SEED="$REPO_ROOT/core/fixtures/check-manifest-bypass/seed.sh"
if [ -f "$SEED" ]; then
  manifest_row() { # manifest_row <gate-type> -> ids, one per line
    awk -v want="$1" '
      /<!-- GATE_MANIFEST v1 -->/{f=1;next} /<!-- GATE_MANIFEST_END -->/{f=0}
      f && /^\|/ {
        gt=$0; sub(/^\|[ ]*/,"",gt); sub(/[ ]*\|.*$/,"",gt)
        if (gt != want) next
        n=split($0, c, "|"); ids=c[3]; gsub(/ /,"",ids)
        n=split(ids, a, ","); for (i=1;i<=n;i++) if (a[i] != "") print a[i]
      }' "$GV"
  }
  # Read once, then match in-shell: this is called once per check id and $SEED does not
  # change underneath the loop.
  _seed_body="$(<"$SEED")"
  seed_has() { in_body "<!-- CHECK_LOADED: $1 -->" "$_seed_body"; }

  # The universal half of that sentence was a hand-maintained copy too, and it had
  # rotted the same way every other copy of this set rotted: the seed carried the
  # 14 ids the old gate-validation.md PROSE listed and never gained 2a or 25. The
  # universal core is a manifest row as of v0.73.0, so derive it here like any other.
  for cid in $(manifest_row universal); do
    seed_has "$cid" || err "check-manifest-bypass/seed.sh seeds the UNIVERSAL core but omits check $cid, which the GATE_MANIFEST universal row requires — the fixture claims to seed 'universal core + the planning row' and does not, so H1's self-test runs against a slice no gate ever loads"
  done
  for cid in $(manifest_row planning); do
    seed_has "$cid" || err "check-manifest-bypass/seed.sh seeds the PLANNING slice but omits check $cid, which the GATE_MANIFEST planning row requires — the fixture no longer seeds what it claims, and H1's self-test is testing a slice that does not exist"
  done
  for cid in $(manifest_row implementation); do
    seed_has "$cid" && err "check-manifest-bypass/seed.sh contains check $cid from the IMPLEMENTATION row — the fixture's whole purpose is that those anchors are ABSENT so H1 fails; including one makes the self-test vacuous"
  done
fi

# --- I8: fixture packaging (core/fixtures == install loop == uninstall loop ==
# --- core_manifest's fixtures/ entries) ---------------------------------------
# The fixture dirs are shipped by a HARDCODED, enumerated loop in install.sh and
# removed by a second hardcoded loop in uninstall.sh. Nothing kept the three in sync,
# and they had already drifted: nine fixtures on disk, nine in install, FIVE in
# uninstall. A fixture missing from install never reaches a consumer at all — it is an
# adversarial self-test that silently does not exist, which is strictly worse than no
# fixture, because the catalog claims it is covered. Glob the truth and compare.
#
# INSTALL.SH NO LONGER HOLDS A LIST -- it derives the ship set from `core/fixtures/*/`
# minus `.dist-only`, which is the same derivation `shippable` is below. So the arms that
# used to join install.sh against disk are GONE rather than kept as tautologies: comparing
# a derivation to itself passes for a reason unrelated to anything being right, and a
# tautology reads exactly like a check that holds. What replaces them is I74(b), which
# asserts the derivation is still THERE and still excludes the marker. uninstall.sh keeps
# its list -- it runs on a consumer where core/fixtures/ does not exist, and it bounds a
# DESTRUCTIVE loop that must not glob the consumer's own tests/fixtures/ -- so it is the
# side this block now joins.
fixture_list() { # fixture_list <script> -> dir names, one per line
  awk '/^for fixture_dir in /{ sub(/^for fixture_dir in /,""); sub(/; do.*$/,""); print }' "$1" \
    | tr ' ' '\n' | grep -E '.' | sort -u
}
on_disk="$( { for _d in "$REPO_ROOT"/core/fixtures/*/; do _d="${_d%/}"; [ -d "$_d" ] || continue; printf '%s\n' "${_d##*/}"; done; } 2>/dev/null | sort -u)"
in_uninstall="$(fixture_list "$REPO_ROOT/scripts/uninstall.sh")"
if [ "$(grep -c . <<<"$in_uninstall" || true)" -lt 10 ]; then
  err "I8's uninstall.sh fixture extractor read fewer than ten names. It stopped matching, and an empty set agrees with every other set -- this fails closed rather than reporting an agreement it did not compute."
fi

# DIST-ONLY fixtures. A fixture is shipped so it can RUN on the consumer. One whose
# subject is not shipped cannot run there, and shipping it anyway plants a fixture that
# is permanently dormant on every consumer — the same "the catalog claims it is covered
# and it is not" failure this block exists to prevent, just pointed the other way. Such a
# fixture is NOT expected in install.sh's loop.
#
# The exemption is not self-certifying: a dist-only fixture must ALSO be absent from
# install.sh's loop (a stale exemption for a now-shipped fixture would silently excuse it
# from the sync check above).
# DERIVED, not listed. A fixture is dist-only iff it carries a `.dist-only` marker file.
# It was a hand-maintained string here, and three readers had to agree about it: install.sh
# (which omitted it, correctly), map_consumer() (which shipped every core/fixtures/* on every
# pull, and therefore shipped it anyway), and this check. They did not agree, and the
# reference consumer ended up with tests/fixtures/enforcement-map-sites/ and no subject script
# beside it. A list two writers must remember to update is the bug. The marker sits next to
# the fixture it exempts, and every reader derives the same answer from the same file.
DIST_ONLY="$(cd "$REPO_ROOT/core/fixtures" 2>/dev/null && for d in */; do
  [ -f "${d}.dist-only" ] && printf '%s\n' "${d%/}"
done | sort -u)"
for f in $DIST_ONLY; do
  grep -qx "$f" <<<"$in_uninstall" && err "fixture '$f' carries a .dist-only marker but uninstall.sh names it. install.sh never copies a marked fixture, so this is a removal loop reaching for a path no consumer was ever given."
  [ -d "$REPO_ROOT/core/fixtures/$f" ] || err "fixture '$f' carries a .dist-only marker but does not exist in core/fixtures/ — stale marker."
done

shippable="$(comm -23 <(printf '%s\n' "$on_disk") <(printf '%s\n' "$DIST_ONLY"))"
miss_uninstall="$(comm -23 <(printf '%s\n' "$shippable") <(printf '%s\n' "$in_uninstall"))"
[ -n "$miss_uninstall" ] && err "fixture(s) install.sh ships that uninstall.sh never names, so an uninstall orphans them in the consumer's tests/fixtures/ forever: $(echo $miss_uninstall)"
ghost_uninstall="$(comm -13 <(printf '%s\n' "$on_disk") <(printf '%s\n' "$in_uninstall"))"
[ -n "$ghost_uninstall" ] && err "uninstall.sh names fixture(s) that do not exist in core/fixtures/: $(echo $ghost_uninstall). Its loop guards on \`[ -d ]\`, so a renamed or deleted fixture is a silent no-op rather than a failure."

# The manifest CLAIMS these fixtures for the core layer, and the claim must equal the
# set a consumer actually RECEIVES -- which is $shippable above, already computed and
# already bound to uninstall's loop. One derivation, four readers: a .dist-only marker moves
# all of them together, so the manifest's fixture entries cannot become a fifth hand-list.
# Both directions:
#
#   a shipped fixture with NO entry -> ai-dlc-core-guard.sh permits an in-place edit to
#     upstream test data, and Check 16 audits it as consumer-authored -- a marker in a
#     core fixture becomes a gate FAIL whose only remediation VACATES the fixture,
#     because those markers are the payload its own assertions read.
#   an entry with no shippable fixture -> the guard denies edits to a path no consumer
#     has, and a deny that protects nothing reads as protection.
#
# core-manifest.md alone is sufficient: I5 binds the second copy to it.
cm_fixtures="$(norm_core_manifest "$CORE_MANIFEST" | sed -n 's#^fixtures/\(.*\)/\*\*$#\1#p' | sort -u)"
miss_entry="$(comm -23 <(printf '%s\n' "$shippable") <(printf '%s\n' "$cm_fixtures"))"
[ -n "$miss_entry" ] && err "fixture(s) install.sh ships to every consumer with NO core_manifest entry, so the core guard permits an in-place edit to upstream test data and Check 16 audits it as consumer-authored: $(echo $miss_entry). Add 'fixtures/<name>/**' to BOTH manifest copies."
ghost_entry="$(comm -13 <(printf '%s\n' "$shippable") <(printf '%s\n' "$cm_fixtures"))"
[ -n "$ghost_entry" ] && err "core_manifest claims fixture(s) that are not shippable — dist-only, or absent from core/fixtures/: $(echo $ghost_entry). The guard would deny edits to a path no consumer has, and a deny that protects nothing reads as protection."

# --- I10: fixture hermeticity -------------------------------------------------
# A fixture that invokes a hook and INHERITS the operator's ambient config tests the
# CONFIG, not the code. The hooks honour thirteen AI_DLC_* tunables; a consumer that sets
# any one of them in settings.json exports it into every session, `git push` inherits it,
# and the pre-push gate then runs the fixture against a hook configured differently from
# what its assertions assume.
#
# Observed live: a consumer pinned AI_DLC_MODEL_ROW=1M — the documented way to declare the
# model row — and SEVEN context-sensor assertions failed against a sensor behaving exactly
# as specified. The gate blocked every push on that repo. The distribution never caught it
# because the distribution sets none of these: THE CHECK COULD NOT FIRE WHERE IT WAS
# AUTHORED, which is the same defect this file has now shipped three fixes for.
#
# So: any fixture that drives a hook must scrub AI_DLC_* first. Asserted, not trusted.
# Two greps over the whole set rather than two per fixture: `-l` lists the hook-driving
# fixtures, `-L` lists those of them that do NOT scrub. Both preserve argument order, so the
# reported set and its order are what the per-file loop produced.
hook_fx="$(grep -lE 'hooks/ai-dlc|\$HOOK' "$REPO_ROOT"/core/fixtures/*/run.sh 2>/dev/null)"
if [ -n "$hook_fx" ]; then
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    d="${r%/run.sh}"
    err "fixture '${d##*/}' invokes a hook but never scrubs ambient AI_DLC_* env. A consumer that tunes any of the hooks' AI_DLC_* variables in settings.json will fail this fixture — and its pre-push gate will then block every push — against a hook that is behaving correctly. Scrub the env at the top of run.sh."
  done < <(printf '%s\n' "$hook_fx" | tr '\n' '\0' | xargs -0 grep -LE 'unset "\$_v"|env -u AI_DLC' 2>/dev/null)
fi

# --- I13: every shipped hook is REGISTERED. install.sh copies core/hooks/*.sh by GLOB, so a
# new hook always reaches the consumer's .claude/hooks/ — but it only ever RUNS if
# templates/settings.json.template names it in a matcher block (settings-merge.sh strips and
# re-appends by the ai-dlc-*.sh pattern on pull, so the template is the single registration
# site). Nothing asserted the two agree. A hook that is copied but never registered installs
# to every consumer, is present on disk, passes its own fixture, and silently never fires:
# a check that cannot fire, in the most literal form this repo has — the file is RIGHT THERE.
# The glob is what makes it invisible; the fixture is what makes it feel covered.
if [ -r "$TEMPLATE" ]; then
  for h in "$REPO_ROOT"/core/hooks/ai-dlc-*.sh; do
    [ -f "$h" ] || continue
    hb="$(basename "$h")"
    grep -q "$hb" "$TEMPLATE" \
      || err "hook '$hb' exists in core/hooks/ but is never named in templates/settings.json.template. install.sh copies it by glob, so it WILL land in every consumer's .claude/hooks/ and WILL never run — no matcher block invokes it. Register it in the template (settings-merge.sh upserts it on pull), or delete the hook."
  done
  # And the inverse: a template entry naming a hook that no longer exists wires a consumer's
  # settings.json to a missing command on the next pull.
  while IFS= read -r hb; do
    [ -f "$REPO_ROOT/core/hooks/$hb" ] \
      || err "templates/settings.json.template registers '$hb', which does not exist in core/hooks/. Every consumer's settings.json would get a hook command pointing at a missing file."
  done < <(grep -oE 'ai-dlc-[a-z0-9-]+\.sh' "$TEMPLATE" | sort -u)
fi

# --- I14: a registered hook must be COMMITTED EXECUTABLE. Registration (I13) proves a hook is
# WIRED; it does not prove it can RUN. settings.json invokes a hook as a bare path, so a hook
# committed 0644 installs byte-perfect and inert — the harness cannot exec it, nothing errors
# loudly, and every content-diffing verification in the reconcile still reports green.
#
# This is I13's own blind spot, and it had already bitten twice before anyone looked:
# ai-dlc-driver-signal.sh (a Stop hook) and the session driver were both committed 0644. Fresh
# installs hid it because install.sh chmods the whole glob after copying; only a PULLING consumer
# ever saw the real mode. Assert the source mode, so the fix in reconcile/apply.sh (which now
# derives the bit from git's tree) has a correct bit to derive FROM.
for h in "$REPO_ROOT"/core/hooks/ai-dlc-*.sh; do
  [ -f "$h" ] || continue
  hb="$(basename "$h")"
  grep -q "$hb" "$TEMPLATE" 2>/dev/null || continue          # unregistered -> I13 already errs
  m="$(git -C "$REPO_ROOT" ls-files -s -- "core/hooks/$hb" 2>/dev/null | awk '{print $1}')"
  [ -n "$m" ] || continue                                     # untracked -> not shippable yet
  [ "$m" = "100755" ] \
    || err "hook '$hb' is registered in templates/settings.json.template but is COMMITTED $m, not 100755. settings.json invokes it as a bare path, so every consumer that PULLS it gets it non-executable and INERT — its enforcement silently absent while every content check reports green. Fix with: git update-index --chmod=+x core/hooks/$hb"
done

# Same rule for anything else a consumer executes as a bare path. The session driver and the
# pre-push git hook are both invoked directly, never via `bash <path>`. (Fixtures are exempt by
# construction: core/git-hooks/pre-push runs them as `bash "$d/run.sh"`, so their mode is inert.)
for rel in session-driver/ai-dlc-session-driver.sh git-hooks/pre-push; do
  [ -e "$REPO_ROOT/core/$rel" ] || continue
  m="$(git -C "$REPO_ROOT" ls-files -s -- "core/$rel" 2>/dev/null | awk '{print $1}')"
  [ -n "$m" ] || continue
  [ "$m" = "100755" ] \
    || err "core/$rel is executed as a bare path by consumers but is COMMITTED $m, not 100755. A pulling consumer gets it non-executable. Fix with: git update-index --chmod=+x core/$rel"
done

# --- I15: ONE anchor grammar. layer-drift.sh REPORTS a heading-number collision and
# relabel-extension-checks.sh FIXES it. They are two programs reading one thing, so a
# grammar that drifts between them means the operator is told to relabel a collision with
# a tool that cannot see the heading. relabel shipped the narrower copy for ~20 versions:
# it required `[0-9]+` first, so core's real `### H1.` / `### H2.` yielded no anchor and an
# extension colliding on H1 was unrelabellable.
#
# The two are now byte-identical by assertion rather than by hope. A sourced helper would
# be the textbook fix, but it must then be installed and resolved in both fixture layouts —
# the v0.55.2 dead-path failure mode — for a single shared line. Assert equality instead.
#
# NOT joined to validate-enforcement-map's own head_ids (line 149): that one is deliberately
# narrower and its sibling at line 146 BANS the `Check ` prefix ANCHOR_RE tolerates. It
# polices core's catalog form; these two read arbitrary consumer layer files. Different job.
ag_drift="$(sed -n 's/^ANCHOR_RE=//p' "$REPO_ROOT/core/skills/ai-dlc-update/reconcile/layer-drift.sh" | head -1)"
ag_relabel="$(sed -n 's/^ANCHOR_RE=//p' "$REPO_ROOT/core/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh" | head -1)"
if [ -z "$ag_drift" ] || [ -z "$ag_relabel" ]; then
  err "I15 cannot find an ANCHOR_RE definition in layer-drift.sh and/or relabel-extension-checks.sh. The check that binds the two anchor grammars just went vacuous — it must locate both or fail loudly, never pass by finding nothing."
elif [ "$ag_drift" != "$ag_relabel" ]; then
  err "the anchor grammar has forked: layer-drift.sh defines ANCHOR_RE=$ag_drift but relabel-extension-checks.sh defines ANCHOR_RE=$ag_relabel. layer-drift REPORTS collisions and relabel FIXES them; a narrower grammar in either means a reported collision no tool can resolve. Make them byte-identical."
fi

# --- I18: ONE bold-anchor rule. The SAME split as I15, one function down. layer-drift.sh
# classifies a pull; validate-layer-entries.sh lints at authoring time and runs in CI. Both
# must agree on what a bold `**7a-post. …**` anchor is versus a `**1. Narrative drift.** …`
# prose list item, because whichever the operator did not run is the one that is wrong.
#
# The narrower question — does the opening `**N.` alone make an anchor? — shipped as YES in
# both copies and read a consumer's three-item triage list as sections 1/2/3, colliding them
# with core's retro steps 1/2/3 forever, with a prescribed remedy ("label the heading") that
# cannot be applied to a sentence.
#
# Byte-identical by assertion, not by hope — same reasoning as I15: a sourced helper must then
# be installed and resolved in both fixture layouts (the v0.55.2 dead-path mode) for one shared
# function. The layer-catalog-collision fixture binds the two BEHAVIOURALLY on a real input;
# this binds them TEXTUALLY, and unlike the fixture it also runs when nobody seeds a consumer.
ba_fn() { awk '/^bold_anchors_of_file\(\) \{/,/^\}/' "$1" 2>/dev/null; }
ba_drift="$(ba_fn "$REPO_ROOT/core/skills/ai-dlc-update/reconcile/layer-drift.sh")"
ba_lint="$(ba_fn "$REPO_ROOT/core/scripts/validate-layer-entries.sh")"
if [ -z "$ba_drift" ] || [ -z "$ba_lint" ]; then
  err "I18 cannot find a bold_anchors_of_file() definition in layer-drift.sh and/or validate-layer-entries.sh. The check that binds the two bold-anchor rules just went vacuous — it must locate both or fail loudly, never pass by finding nothing."
elif [ "$ba_drift" != "$ba_lint" ]; then
  err "the bold-anchor rule has forked between layer-drift.sh and validate-layer-entries.sh. One classifies the pull and the other lints authoring and gates CI; a rule that differs between them means the two disagree about what a section IS, and the operator believes whichever they happened to run. Make bold_anchors_of_file() byte-identical."
fi

# --- I36/I37/I38: the layer contract is joined to its enforcers, both ways -----
# THE STATE THESE MAKE UNREPRESENTABLE. Measured at v0.180.0: the consumer layer contract was
# 41 clauses across four files, of which SEVENTEEN had no enforcer — three saying so in their
# own prose. Both reporters returned 0 errors / 0 warnings on a tree carrying real violations.
# A contract nothing can fail is this repo's named defect class one level up from a check.
#
# The join is on a token the enforcer ALREADY emits (`E1`..`W4`, or a literal pull-time status),
# so nothing had to be sprinkled into a script to make it work and there is no second vocabulary
# to hand-sync. That is what lets I36 run in BOTH directions.
# PATH IS OVERRIDABLE so a fixture can mutate the CONTRACT without writing into the repo it is
# validating. It cannot be used to weaken the gate: I36's reverse direction requires every code
# the real enforcers emit to be claimed, so a stripped-down substitute fails louder than the
# original, not quieter. The enforcers and prose homes are always resolved against $REPO_ROOT.
lc_file="${AI_DLC_LAYER_CONTRACT:-$REPO_ROOT/core/skills/ai-dlc/layer-contract.yaml}"
if [ ! -f "$lc_file" ]; then
  err "I36 cannot find the layer contract at $lc_file. A scan over nothing reads exactly like agreement — the file is core_manifest machinery and must exist."
else
  # Parse the clause table. Three fields per clause; a clause missing any of them is I37's
  # subject, not a parse error to swallow.
  lc_ids="$(awk '/^  - id:/{print $3}' "$lc_file")"
  lc_n="$(printf '%s\n' "$lc_ids" | grep -c . )"
  if [ "$lc_n" -eq 0 ]; then
    err "I36 read ZERO clauses out of layer-contract.yaml. The contract cannot be empty and a zero here would make I36/I37/I38 all pass vacuously — the exact shape they exist to forbid."
  fi

  # --- I41: a clause id is unique. ------------------------------------------------------
  # HOW THIS SHIPPED. v0.187.0 added LC-O12 and v0.192.0 added a SECOND one, and the build
  # stayed green through both. Every existing invariant keys on something else: I36 joins on
  # `code:` (unique), I37 on the presence of three fields, I38 greps the prose home for the id
  # as a SUBSTRING — so two clauses sharing an id satisfy I38 on one line of prose. The id was
  # the one field nothing checked, which is why it was the one field that collided.
  #
  # It is not cosmetic. The id is the only handle a report, a CHANGELOG or an operator has for
  # naming which clause fired, and `overrides/README.md` had carried both under one label since
  # v0.192.0 — the reader-facing side of the contract had two different rules with one name. It
  # is also the key row 11's disposition register is specified to use, per (entry, clause, digest).
  #
  # The collision hid because the file is NOT in numeric order: LC-O12 sat ABOVE LC-O10 and
  # LC-O11, so an author appending after LC-O11 counted forward and landed on a taken number
  # without it ever appearing adjacent. Ordering is not the fix; a mechanism is.
  lc_dupes="$(printf '%s\n' "$lc_ids" | grep . | sort | uniq -d | tr '\n' ' ')"
  if [ -n "$lc_dupes" ]; then
    err "I41: layer-contract.yaml declares the same clause id more than once — ${lc_dupes% }. The id is the only name a report, a README or an operator has for a clause, so two clauses under one id make every citation of it ambiguous and let one clause satisfy I38 on the other's prose. Renumber the collision; the id space is append-only, so take the next free number rather than reordering the file."
  fi

  # --- I42: no clause is introduced at a contract_version the contract has not reached. --
  # `since:` dates a clause, and `validate-layer-entries.sh` subtracts it from each entry's
  # `conforms_to` receipt to name that entry's migration worklist. A clause whose `since` is
  # ABOVE `contract_version` can never appear on any worklist, because no entry may declare a
  # receipt above the version. It is a clause that cannot fire wearing a version number, which
  # is this repo's named defect class at contract grain.
  #
  # MEASURED WHEN THIS WAS ADDED: contract_version was 2 while THREE clauses declared `since: 3`
  # (both LC-O12s and LC-O13). v0.183.0 set the 2; v0.187.0 and v0.192.0 each wrote a 3 past it.
  # Nothing read either field, so nothing objected. That gap closed at contract_version 9, which
  # gave both fields their first reader — and closed it in the opposite semantics to the one this
  # comment used to state. `conforms_to` does NOT hold an entry to a subset of the clauses: every
  # clause fires whatever it declares, and what the receipt buys is scope. Do not restate that
  # rule here; `layer-contract.yaml`'s header owns it.
  #
  # A missing `since:` or an unparseable `contract_version` is an ERROR, not a skip: either one
  # would let this scan pass by finding nothing.
  lc_cv="$(awk '/^contract_version:/{print $2; exit}' "$lc_file")"
  case "$lc_cv" in
    ''|*[!0-9]*)
      err "I42 cannot read a numeric contract_version out of layer-contract.yaml (got '${lc_cv:-<none>}'). Every clause's since: is compared against it, so an unreadable value would retire this check silently rather than failing it." ;;
    *)
      lc_i42="$(awk -v cv="$lc_cv" '
        /^  - id:/    { if (id != "") check(); id=$3; since=""; next }
        /^    since:/ { since=$2; next }
        END           { if (id != "") check() }
        function check() {
          if (since == "")                      printf "%s has no since:; ", id
          else if (since ~ /[^0-9]/)            printf "%s since %s is not a number; ", id, since
          else if (since + 0 > cv + 0)          printf "%s since %s > contract_version %s; ", id, since, cv
        }
      ' "$lc_file")"
      if [ -n "$lc_i42" ]; then
        err "I42: layer-contract.yaml carries a clause the contract's own version has not reached — $lc_i42 No entry may declare a conforms_to receipt above contract_version, so a clause introduced above it can never reach any entry's migration worklist. Bump contract_version in the same release that introduces the clause."
      fi ;;
  esac

  # --- I37: no prose-only clause. A clause must name a level, an enforcer and a code. ---
  # This is the invariant that keeps the seventeen-unenforced state out. `enforcement: pending`
  # is not a permitted value anywhere, deliberately: a placeholder is the same
  # declaration-without-a-mechanism defect wearing a new file's clothes.
  lc_i37="$(awk '
    /^  - id:/          { if (id != "") check(); id=$3; lvl=""; enf=""; code=""; next }
    /^    level:/       { lvl=$2; next }
    /^    enforcer:/    { enf=$2; next }
    /^    code:/        { code=$2; next }
    END                 { if (id != "") check() }
    function check() {
      if (lvl == "")  printf "%s has no level:; ", id
      if (enf == "")  printf "%s has no enforcer:; ", id
      if (code == "") printf "%s has no code:; ", id
      if (lvl != "" && lvl != "ERROR" && lvl != "WARN" && lvl != "ADJUDICATED")
        printf "%s level %s is not ERROR, WARN or ADJUDICATED; ", id, lvl
    }
  ' "$lc_file")"
  if [ -n "$lc_i37" ]; then
    err "I37: layer-contract.yaml carries a clause with no mechanism — $lc_i37 Every clause states level + enforcer + code, or it is prose pretending to be a rule, which is the state this contract was created to end. Ship the clause WITH its enforcer, or leave it in the CHANGELOG backlog until you have one."
  fi

  # --- I36 forward: every clause names a code its declared enforcer actually emits. ---
  while IFS='|' read -r cid cenf ccode; do
    [ -n "$cid" ] || continue
    if [ ! -f "$REPO_ROOT/$cenf" ]; then
      err "I36 $cid: declared enforcer '$cenf' does not exist. A clause bound to a missing script is unenforced with a citation, which reads better than nothing and is worth less."
    else
    # LAST-FILE MEMO, not a sort. Grouping the clauses by enforcer would read each file once,
    # but it would also reorder the findings, and the order errors come out in is the only
    # thing a reader has to walk back to the clause. Clauses already arrive grouped in
    # practice, so this reads each enforcer once; when they interleave it degrades to one
    # `$(<file)` per clause, which is still cheaper than the grep it replaces and never worse.
    if [ "$cenf" != "$_i36_body_of" ]; then _i36_body_of="$cenf"; _i36_body="$(<"$REPO_ROOT/$cenf")"; fi
    if ! in_body "$ccode" "$_i36_body"; then
      err "I36 $cid: '$cenf' never emits the code '$ccode' this clause claims. The clause cannot fire, and a clause that cannot fire reads exactly like one that passed. Fix the code, or point the clause at the script that does emit it."
    fi
    fi
  done <<EOF
$(awk '
  /^  - id:/       { if (id != "") emit(); id=$3; enf=""; code="" ; next }
  /^    enforcer:/ { enf=$2; next }
  /^    code:/     { code=$2; next }
  END              { if (id != "") emit() }
  function emit() { if (enf != "" && code != "") printf "%s|%s|%s\n", id, enf, code }
' "$lc_file")
EOF

  # --- I36 reverse: every code an enforcer emits is claimed by exactly one clause. ---
  # THE DIRECTION THAT ACTUALLY CATCHES DRIFT. Forward-only, a new status could ship with no
  # clause and the contract would still build green — which is how a status reaches an operator
  # with no stated rule behind it, and how the seventeen-clause gap grew in the first place.
  #
  # The `*-OK` statuses are excluded by a DERIVED suffix rule, not a hand-list: an `-OK` row is
  # a clean state, not a finding, so it has no clause to state. A hand-list of exceptions here
  # would be the restated-enumeration defect I26 exists for.
  lc_claimed="$(awk '/^    code:/{print $2}' "$lc_file" | sort -u)"
  lc_declared_enf="$(awk '/^    enforcer:/{print $2}' "$lc_file" | sort -u)"
  for enf in $lc_declared_enf; do
    [ -f "$REPO_ROOT/$enf" ] || continue
    case "$enf" in
      # TWO DIGITS, and the second one is not cosmetic. `E[1-9]` cannot match `E10`:
      # the trailing `\b` needs a non-word character and the `0` is a word character,
      # so the code is skipped in silence. E1..E9 were ALL allocated by v0.195.0, so
      # the very next error code this file gained would have been invisible to the
      # reverse join — the clause claiming it would satisfy the FORWARD direction,
      # the build would stay green, and the one direction that actually catches an
      # unclaimed code would simply not cover it. Widening is a no-op on the tree that
      # shipped it (verified: identical extraction before and after), which is exactly
      # why it had to be done before the codes existed rather than after.
      *validate-layer-entries.sh) emitted="$(grep -oE '\b(E[1-9][0-9]?|W[1-9][0-9]?)\b' "$REPO_ROOT/$enf" | sort -u)" ;;
      *layer-drift.sh)            emitted="$(grep -oE '\b(HARD-[A-Z0-9-]+|OVERRIDE-[A-Z0-9-]+|EXTENSION-[A-Z0-9-]+)\b' "$REPO_ROOT/$enf" | sort -u | grep -v -- '-OK$')" ;;
      # TWO DIGITS from the first release that allocates one, not after the ninth —
      # the `E[1-9]` lesson one vocabulary over, applied before it can cost anything.
      *validate-gate-manifest.sh) emitted="$(grep -oE '\bGM[1-9][0-9]?\b' "$REPO_ROOT/$enf" | sort -u)" ;;
      *)                          emitted="" ;;
    esac
    if [ -z "$emitted" ]; then
      err "I36 reverse: found NO codes in declared enforcer '$enf'. Either the extraction pattern no longer matches that script's vocabulary or the script changed shape; a zero here silently retires this whole direction of the join."
    fi
    for code in $emitted; do
      if ! in_lines "$code" "$lc_claimed"; then
        err "I36 reverse: '$enf' emits '$code' but NO clause in layer-contract.yaml claims it. An operator can be handed that verdict with no stated rule behind it. Add the clause, or stop emitting the code."
      fi
    done
  done

  # --- I38 forward: every clause id appears in the prose home it declares. ---
  # ONLY the forward direction ships, and the reason is measured. (It was written when the
  # contract was at version 1 and said so; the number was never updated across two bumps, which
  # is a small instance of exactly what I42 now guards — do not restate a version in prose.) The
  # reverse direction — every normative sentence carries a clause id — has no sound predicate
  # yet: a keyword scan (MUST|NEVER|never|cannot|only) over the two layer READMEs matches 26
  # lines against 10 real clauses, and the structural form is worse, because the two files do
  # not share one: all 10 bold-led clause bullets are in extensions/README.md and
  # overrides/README.md has ZERO, stating its clauses as prose paragraphs and section headings.
  # A structural predicate would therefore be unable to fire on half its subject. Normalising
  # that prose is a separate change; until then the reverse direction would be a lint with an
  # unmeasured false-positive set, which is the one this repo forbids shipping.
  while IFS='|' read -r cid chome; do
    [ -n "$cid" ] || continue
    if [ ! -f "$REPO_ROOT/$chome" ]; then
      err "I38 $cid: declared prose_home '$chome' does not exist."
    else
    if [ "$chome" != "$_i38_body_of" ]; then _i38_body_of="$chome"; _i38_body="$(<"$REPO_ROOT/$chome")"; fi
    if ! in_body "$cid" "$_i38_body"; then
      err "I38 $cid: '$chome' never mentions '$cid'. The contract points a reader at prose that does not carry the clause, so the human-readable side and the enforced side have already diverged."
    fi
    fi
  done <<EOF
$(awk '
  /^  - id:/         { if (id != "") emit(); id=$3; home="" ; next }
  /^    prose_home:/ { home=$2; next }
  END                { if (id != "") emit() }
  function emit() { if (home != "") printf "%s|%s\n", id, home }
' "$lc_file")
EOF

  # --- I61: the prose home states the SAME SEVERITY the contract declares. ---
  #
  # I38 forward asks only that the home MENTIONS the id. That is satisfied by a bullet whose
  # every other word has gone stale, and three of them had — measured on the tree that shipped
  # this invariant, with the join below and a control of 39 bullets parsed:
  #
  #   LC-N5   contract ERROR        extensions/README.md said WARN
  #   LC-E4   contract ADJUDICATED  extensions/README.md said WARN
  #   LC-E14  contract ADJUDICATED  extensions/README.md said WARN
  #
  # None of the three is cosmetic. LC-N5 was promoted W5 -> E15 one release earlier and its
  # bullet BODY was rewritten in that same release to describe the total partition — the author
  # rewrote 24 lines of the bullet and left the severity word at its head untouched. So the
  # consumer-facing contract told an author the total naming partition was a non-blocking WARN
  # while their own pre-push was refusing on it. LC-E4 and LC-E14 understated ADJUDICATED, whose
  # whole point is that it BLOCKS `apply` until a verdict is recorded.
  #
  # This is the restatement-drift class the contract exists to end, arriving in the contract's
  # own reader-facing half: a mechanism restated in prose drifts TIGHTER or LOOSER, invisibly,
  # because nothing joins the restatement to the thing restated. The severity is the one field
  # where the drift changes what an author will do about it.
  #
  # THE VOCABULARY IS DERIVED, never hand-listed — it is the set of `level:` values the contract
  # itself uses, so adding a fourth level tomorrow needs no edit here. And the bullet grammar is
  # required to CARRY a severity: a clause bullet stating none would otherwise be an escape hatch
  # that empties this join one bullet at a time. Measured false-positive set: 0 of 39 bullets
  # across the two declared READMEs lack one.
  lc_homes="$(awk '/^    prose_home:/{print $2}' "$lc_file" | sort -u)"
  lc_levels="$(awk '/^  - id:/{id=$3} /^    level:/{ if (id != "") { print id, $2; id="" } }' "$lc_file")"
  lc_vocab="$(awk '{print $2}' <<<"$lc_levels" | sort -u)"
  lc_bullets_n=0
  if [ -z "$lc_vocab" ]; then
    err "I61 read ZERO level: values out of layer-contract.yaml, so the severity vocabulary it joins against is empty and every bullet below would fail or pass for the wrong reason."
  else
    for lc_home in $lc_homes; do
      [ -f "$REPO_ROOT/$lc_home" ] || continue
      while IFS= read -r lc_line; do
        [ -n "$lc_line" ] || continue
        lc_bullets_n=$((lc_bullets_n+1))
        lc_bid="$(sed -E 's/^- \*\*\[(LC-[A-Za-z0-9]+)\]\*\*.*/\1/' <<<"$lc_line")"
        lc_btok="$(sed -E 's/^- \*\*\[LC-[A-Za-z0-9]+\]\*\*[[:space:]]*//' <<<"$lc_line" | grep -oE '^[A-Z]+')"
        lc_bdecl="$(awk -v w="$lc_bid" '$1==w{print $2; exit}' <<<"$lc_levels")"
        if [ -z "$lc_bdecl" ]; then
          err "I61: '$lc_home' carries a clause bullet for '$lc_bid' that layer-contract.yaml does not declare. A reader is being handed a rule with no enforcer behind it — the exact state the contract was created to end, arriving from the prose side."
        elif [ -z "$lc_btok" ] || ! in_lines "$lc_btok" "$lc_vocab"; then
          err "I61: '$lc_home' states clause $lc_bid with no severity from the contract's own vocabulary [$(printf '%s' "$lc_vocab" | tr '\n' ' ')]. Every clause bullet leads with its severity; one that does not is a bullet this join cannot check, and an unchecked bullet is how the three live mismatches this invariant shipped for got there."
        elif [ "$lc_btok" != "$lc_bdecl" ]; then
          err "I61: '$lc_home' states clause $lc_bid as $lc_btok but layer-contract.yaml declares it $lc_bdecl. The enforced side and the reader-facing side disagree about whether this blocks, so an author reads a severity their own pre-push does not apply. The contract is the source of truth; fix the prose."
        fi
      done < <(grep -E '^- \*\*\[LC-[A-Za-z0-9]+\]\*\*' "$REPO_ROOT/$lc_home")
    done
    if [ "$lc_bullets_n" -eq 0 ]; then
      err "I61 found ZERO clause bullets across the $(printf '%s' "$lc_homes" | grep -c .) declared prose home(s). Either the bullet grammar moved or the homes did; a zero here retires the whole severity join in silence, which is indistinguishable from every bullet agreeing."
    fi
  fi

  # --- I63: the contract PINS the files it absorbed, and each one still is what it says. ---
  #
  # WHAT THIS CLOSES. The contract's own header names the four files it was created to absorb.
  # Nothing joined that claim to anything, so "the four prose homes are reduced to pointers" was
  # a sentence rather than a state, and a home could contribute zero clauses invisibly — which
  # two of the four did for nineteen releases. `prose_home:` alone cannot close it: it is written
  # per clause, so a file that stops carrying clauses simply stops appearing, and its silence is
  # identical to a file that was never in scope.
  #
  # THE ROLES ARE THE POINT. `home` means the file states clauses and is a declared prose_home.
  # `pointer` means it states none and only refers to clauses homed elsewhere — Rule 27's state,
  # and the charter's stated goal for all four. `none` means it carries no contract prose at all;
  # core-manifest.md is pinned that way on measurement, not on the charter's say-so, which listed
  # it as a scatter site: it names zero contract codes and carries zero clause bullets, so the
  # charter's four-site list was wrong about it and this records that rather than papering it.
  #
  # BOTH DIRECTIONS, or the pin rots the way every hand-maintained list in this repo has. Forward:
  # a pinned file must match its declared role. Reverse: a file that becomes a prose_home without
  # being pinned fails the build, so the list cannot silently fall behind the contract.
  lc_pins="$(awk '
    /^absorbed_from:/  { inblk=1; next }
    inblk && /^[a-z_]/ { inblk=0 }
    inblk && /^  - path:/ { p=$3; next }
    inblk && /^    role:/ { if (p != "") { printf "%s|%s\n", p, $2; p="" } }
  ' "$lc_file")"
  lc_pin_n="$(printf '%s' "$lc_pins" | grep -c . || true)"
  if [ "$lc_pin_n" -eq 0 ]; then
    err "I63 read ZERO entries out of layer-contract.yaml's absorbed_from: list. The contract states which files it absorbed and this is the only thing holding that claim to the tree; an empty read passes every arm below by having no subject, which reads exactly like a contract whose homes are all correct."
  else
    while IFS='|' read -r lc_pin_path lc_pin_role; do
      [ -n "$lc_pin_path" ] || continue
      if [ ! -f "$REPO_ROOT/$lc_pin_path" ]; then
        err "I63: absorbed_from pins '$lc_pin_path', which does not exist. A pin at a path the tree does not carry silently drops that file from every arm below."
        continue
      fi
      lc_pin_clauses="$(awk -v h="$lc_pin_path" '/^    prose_home:/ && $2==h' "$lc_file" | grep -c . || true)"
      # ONE PASS over the file rather than a grep per code: 43 codes x 5 pinned files is 215
      # invocations, and a per-code `grep -q` fed a shell variable is the construct I54 forbids.
      lc_pin_codes="$(awk '
        NR==FNR { code[$1]=1; next }
        { for (c in code) { if ($0 ~ ("(^|[^A-Za-z0-9_-])" c "([^A-Za-z0-9_-]|$)")) { seen[c]=1 } } }
        END { n=0; for (c in seen) { n++ }; print n }
      ' <(awk '/^    code:/{print $2}' "$lc_file" | sort -u) "$REPO_ROOT/$lc_pin_path")"
      case "$lc_pin_role" in
        home)
          [ "$lc_pin_clauses" -gt 0 ] || err "I63: '$lc_pin_path' is pinned role: home but is the declared prose_home of NO clause. A home contributing zero clauses is the invisible gap this pin exists to make loud — either it still states clauses and one of them should declare it, or its role is pointer or none." ;;
        pointer)
          # NOT ALSO "pointer homes no clause": for a file in this list that is the same
          # condition the reverse arm below tests, and shipping both would mean neither could
          # be mutated in isolation. Reverse covers it, and covers unlisted files too.
          [ "$lc_pin_codes" -gt 0 ] || err "I63: '$lc_pin_path' is pinned role: pointer but names NO contract code at all. It points at nothing, so the pin asserts a relationship the file does not have — pin it role: none, or restore the reference it lost." ;;
        none)
          [ "$lc_pin_codes" -eq 0 ] || err "I63: '$lc_pin_path' is pinned role: none but names $lc_pin_codes contract code(s). It has grown contract prose since it was pinned, and role: none is what keeps it outside I62's citation join — so every duty it now states is unbound and unmeasured." ;;
        *)
          err "I63: '$lc_pin_path' is pinned with role '${lc_pin_role:-<none>}', which is not one of home, pointer or none. An unrecognised role matches no arm below, so the file is pinned and checked by nothing." ;;
      esac
    done <<EOF
$lc_pins
EOF
    # REVERSE: every declared prose_home is pinned. Without this the list falls behind the
    # contract silently, which is the failure mode of every hand-maintained list this repo has
    # retired — and the forward arms above would all still pass.
    awk '/^    prose_home:/{print $2}' "$lc_file" | sort -u | while IFS= read -r lc_h; do
      [ -n "$lc_h" ] || continue
      if ! grep -qxF -- "$lc_h|home" <<<"$lc_pins"; then
        err "I63 reverse: '$lc_h' is a declared prose_home but is not pinned role: home in absorbed_from. The contract states which files it absorbed; a home outside that list is checked by no role arm and reduced to a pointer by nothing."
      fi
    done
  fi

  TMPDIR_I62="$(mktemp -d "${TMPDIR:-/tmp}/i62-XXXXXX")"

  # --- I62: prose that NAMES a contract code cites the clause that claims it. ---
  #
  # THE HALF I38 AND I61 BOTH LEAVE OPEN. I38 iterates CLAUSES and asks that each id appear
  # somewhere in its declared home — file grain, satisfied by one mention anywhere. I61 iterates
  # BULLETS THAT ALREADY CARRY AN ID and checks their severity. Neither can see the opposite
  # shape: prose that states a duty, names the code that enforces it, and carries no clause id
  # at all. That is the seventeen-unenforced state arriving from the prose side, and it was live
  # in ELEVEN places on the tree this shipped against — eight in declared homes, three in Rule 27.
  #
  # THE PREDICATE, AND WHY IT IS NOT THE ONE THE PLAN SPECIFIED. The specified reverse arm was
  # "every normative sentence carries a clause id", keyed on a MUST/NEVER keyword scan. Measured
  # at three grains — line, bullet, paragraph — its false-positive set never emptied: on
  # extensions/README.md, a file whose 27 clauses are 100% bound at bullet grain, six units still
  # read as unbound because they explain a mechanism rather than state a rule. The distinction is
  # semantic, so no grain reaches it. Worse, overrides/README.md — also 100% bound — names ZERO
  # codes, so a code-shaped predicate cannot even detect that it is bound. Keying on the CODE
  # instead of on a keyword is what makes the subject set decidable: a code is a token this
  # contract already joins on in both directions (I36), so "names a code" is machine-answerable
  # where "states a rule" is not.
  #
  # THE SCOPE IS DERIVED, NOT LISTED. For a declared `prose_home`, the subject is the codes that
  # file is the home FOR — a file must bind the duties it is the stated home of, while naming
  # another home's code is a cross-reference, not a restatement. That derivation is what drops
  # ai-dlc-update/SKILL.md from 21 candidate units to 2 without a single hand-written exclusion:
  # the other 19 narrate report rows whose clauses live elsewhere. For a file pinned `pointer`
  # (I63), the subject is EVERY code it names, because a pointer's whole job is to point at the
  # clause and it homes none of its own.
  #
  # THE VACUITY DEFENCE IS A PROBE THIS INVARIANT WRITES ITSELF, not a count. A zero here is
  # indistinguishable from a tree where every mention is cited, and every count-based floor this
  # could assert is one an edit to the corpus retires silently. So the extractor is run each time
  # against two units the invariant authors: one naming a code with no id, one naming the same
  # code WITH it. Reporting anything but exactly the first means the grammar has stopped reading
  # either the code or the citation, and every clean line below is unattributable.
  lc_units_flagged() {
    # $1 file to scan   $2 file of "CODE LC-ID" pairs in scope   $3 label used in the report
    awk -v home="$3" '
      NR==FNR { want[$1]=$2; next }
      function flush(   c, miss) {
        if (buf == "") { return }
        miss = ""
        for (c in want) {
          if (buf ~ ("(^|[^A-Za-z0-9_-])" c "([^A-Za-z0-9_-]|$)") &&
              buf !~ ("(^|[^A-Za-z0-9_-])" want[c] "([^A-Za-z0-9_-]|$)")) {
            miss = miss " " c " [" want[c] "]"
          }
        }
        if (miss != "") { printf "%s:%d names%s\n", home, start, miss }
        buf = ""
      }
      {
        if ($0 ~ /^```/) { fence = !fence }
        # Interval expressions are not portable to every awk this repo runs on, so the
        # list-item indents are spelled out rather than written as a {0,3} bound.
        isitem = (!fence && ($0 ~ /^([-*]|[0-9]+\.)[ \t]/ || $0 ~ /^ ([-*]|[0-9]+\.)[ \t]/ || \
                             $0 ~ /^  ([-*]|[0-9]+\.)[ \t]/ || $0 ~ /^   ([-*]|[0-9]+\.)[ \t]/))
        if ((!fence && $0 ~ /^[ \t]*$/) || isitem) { flush(); start = FNR }
        buf = buf "\n" $0
      }
      END { flush() }
    ' "$2" "$1"
  }

  lc_pairs_all="$TMPDIR_I62/all.pairs"
  # `prose_home:` precedes `code:` inside a clause, so the triple is completed at the code line,
  # not at the home line. Emitting on the wrong one reads zero triples and passes every file for
  # want of a vocabulary — which is what the first cut of this did.
  awk '
    /^  - id:/         { id=$3; home=""; next }
    /^    prose_home:/ { home=$2; next }
    /^    code:/       { if (id != "" && home != "") { print $2, id, home }; id=""; home=""; next }
  ' "$lc_file" > "$lc_pairs_all"
  if [ ! -s "$lc_pairs_all" ]; then
    err "I62 read ZERO (code, clause, prose_home) triples out of layer-contract.yaml, so every file below would be scanned against an empty vocabulary and report clean for the reason a conforming tree does."
  else
    # THE SELF-WRITTEN PROBE. Both directions, every run.
    lc_probe62="$TMPDIR_I62/probe"
    mkdir -p "$lc_probe62"
    awk '{ print $1, $2; exit }' "$lc_pairs_all" > "$lc_probe62/pairs"
    lc_pc="$(awk '{print $1; exit}' "$lc_probe62/pairs")"
    lc_pi="$(awk '{print $2; exit}' "$lc_probe62/pairs")"
    {
      printf -- '- **Uncited.** The pull reports %s against the entry.\n' "$lc_pc"
      printf -- '\n'
      printf -- '- **Cited.** The pull reports %s against the entry [%s].\n' "$lc_pc" "$lc_pi"
    } > "$lc_probe62/home.md"
    lc_probe62_out="$(lc_units_flagged "$lc_probe62/home.md" "$lc_probe62/pairs" "probe")"
    lc_probe62_n="$(printf '%s' "$lc_probe62_out" | grep -c . || true)"
    if [ "$lc_probe62_n" != "1" ]; then
      err "I62's probe answered with $lc_probe62_n finding(s) where exactly 1 is correct [$(printf '%s' "$lc_probe62_out" | tr '\n' '; ')]. The probe carries one uncited mention of '$lc_pc' and one cited by '$lc_pi'; anything but the uncited one alone means the extractor has stopped reading the code, the citation or the unit boundary, and every clean result below is an empty set produced by a grammar that can no longer find a ghost."
    fi

    while IFS='|' read -r lc_pin_path lc_pin_role; do
      [ -n "$lc_pin_path" ] || continue
      [ -f "$REPO_ROOT/$lc_pin_path" ] || continue
      case "$lc_pin_role" in
        home)    awk -v h="$lc_pin_path" '$3==h {print $1, $2}' "$lc_pairs_all" > "$TMPDIR_I62/scope" ;;
        pointer) awk '{print $1, $2}' "$lc_pairs_all" > "$TMPDIR_I62/scope" ;;
        *)       : > "$TMPDIR_I62/scope" ;;
      esac
      [ -s "$TMPDIR_I62/scope" ] || continue
      while IFS= read -r lc_hit; do
        [ -n "$lc_hit" ] || continue
        err "I62: $lc_hit but cites no clause id. The prose states a duty and names the code that enforces it while the clause that owns it goes unnamed, so the reader-facing side and the enforced side are joined by nothing — which is how three severities drifted apart one field over before I61 caught them. Cite the clause id in the same bullet or paragraph."
      done <<EOF
$(lc_units_flagged "$REPO_ROOT/$lc_pin_path" "$TMPDIR_I62/scope" "$lc_pin_path")
EOF
    done <<EOF
$lc_pins
EOF
  fi
  rm -rf "$TMPDIR_I62"

  # --- I64: every clause's code reaches an ATTRIBUTABLE EMISSION SITE in its enforcer. ---
  #
  # THE HOLE THIS CLOSES, AND IT SAT UNDER THE CONTRACT'S CENTRAL CLAIM. layer-contract.yaml's
  # header states "THE BINDING IS ON A TOKEN THE ENFORCER ALREADY EMITS". I36 forward tests that
  # with `grep -qF` over the WHOLE enforcer file — comments included. Measured on the tree this
  # shipped against: of the 22 codes clauses bind to validate-layer-entries.sh, EIGHTEEN occurred
  # nowhere in it but comments, and two of the remaining four occurred only inside a NEIGHBOURING
  # code's message prose. Both GM codes were comment-only too. So twenty of forty-three clauses
  # satisfied the contract's central join on text that no run can ever print.
  #
  # It is not a cosmetic gap. A finding that does not name its code cannot be joined back to the
  # rule it came from by the operator reading it, by a gate log, or by the per-code census the
  # enforcer now emits — and a clause whose code no code path emits is a clause that CANNOT FIRE
  # while reading, to I36, exactly like one that passed. That is this repo's named defect class
  # sitting inside the mechanism built to end it.
  #
  # THE PREDICATE IS PER-ENFORCER, deliberately, and mirrors I36 reverse's `case` rather than
  # inventing a second shape. "Non-comment line" was measured and REJECTED as the uniform
  # predicate: E6 appears on two non-comment lines of validate-layer-entries.sh, both inside
  # E15's message text explaining why E6 is silent, so a line-grain predicate scores E6 bound on
  # a cross-reference. For the emitter-based script the site is the CODE ARGUMENT itself, which
  # cannot be satisfied by prose about another clause. The two classifier scripts print their
  # codes as row tokens, so non-comment is exact there.
  #
  # FORWARD ONLY, and that is a decision taken against a measurement rather than an oversight.
  # A reverse arm here — every attributably-emitted code is claimed — would be strictly stronger
  # than I36 reverse, which harvests the whole file and so cannot see a typo'd code at a CALL
  # SITE whenever the correct token also sits in a nearby comment. It is not shipped because
  # that unique subject cannot be constructed by mutating the contract, which is the only thing
  # this invariant's fixture can mutate: every contract-side mutation that orphans a code trips
  # I36 reverse on the same finding. An arm whose own unique case cannot be demonstrated red is
  # an arm that reads exactly like one that passed, so it stays out until it has a fixture that
  # can mutate an ENFORCER. Recorded rather than silently omitted.
  lc_i64_sites() { # lc_i64_sites <enforcer-relpath> -> one emitted code per line
    case "$1" in
      *validate-layer-entries.sh)
        grep -oE '\b(err|warn)[[:space:]]+(E[1-9][0-9]?|W[1-9][0-9]?)\b' "$REPO_ROOT/$1" \
          | awk '{print $2}' | sort -u ;;
      *layer-drift.sh)
        grep -vE '^[[:space:]]*#' "$REPO_ROOT/$1" \
          | grep -oE '\b(HARD-[A-Z0-9-]+|OVERRIDE-[A-Z0-9-]+|EXTENSION-[A-Z0-9-]+)\b' \
          | sort -u | grep -v -- '-OK$' ;;
      *validate-gate-manifest.sh)
        grep -vE '^[[:space:]]*#' "$REPO_ROOT/$1" | grep -oE '\bGM[1-9][0-9]?\b' | sort -u ;;
      *) : ;;
    esac
  }

  # Forward: a clause's code is emitted somewhere its enforcer can attribute it.
  while IFS='|' read -r cid cenf ccode; do
    [ -n "$cid" ] || continue
    [ -f "$REPO_ROOT/$cenf" ] || continue          # I36 forward already errs on a missing enforcer
    lc_i64_emitted="$(lc_i64_sites "$cenf")"
    if [ -z "$lc_i64_emitted" ]; then
      err "I64: found NO attributable emission sites in declared enforcer '$cenf'. Either that script changed shape or the extraction above no longer matches its vocabulary; a zero here silently retires this invariant for every clause bound to it, which is the state it exists to report."
      continue
    fi
    in_lines "$ccode" "$lc_i64_emitted" \
      || err "I64 $cid: '$cenf' never emits '$ccode' at a site a run can attribute — the token appears only in prose there, if at all. I36 forward passes on that, because it greps the whole file including comments. A finding that cannot name its clause cannot be joined back to this contract by the operator who receives it, and a code no code path prints is a clause that cannot fire while reading exactly like one that passed. Pass the code to err/warn at the site that reports it, or print it in the row."
  done <<EOF
$(awk '
  /^  - id:/       { if (id != "") emit(); id=$3; enf=""; code="" ; next }
  /^    enforcer:/ { enf=$2; next }
  /^    code:/     { code=$2; next }
  END              { if (id != "") emit() }
  function emit() { if (enf != "" && code != "") printf "%s|%s|%s\n", id, enf, code }
' "$lc_file")
EOF

  # --- I65: every clause names the FIXTURE that proves it, and that fixture can prove it. ---
  #
  # WHAT THIS ADDS TO I64, AND WHY ONE DOES NOT IMPLY THE OTHER. I64 asks that the clause's
  # code reach a site its enforcer can attribute — that the mechanism can SPEAK. It says
  # nothing about whether anything ever makes it speak. A clause can pass I36, I37 and I64
  # with an enforcer arm no fixture has ever driven, which is this repo's named class one
  # level up: an unexercised arm reads exactly like an exercised one that passed.
  #
  # THE JOIN VERIFIES A DECLARED PAIR AND MUST NEVER DERIVE ONE. Measured before this was
  # built: a derived join ("which fixture names this code") has a non-empty false-positive
  # set at every grain tried. At word grain `E4` matches `LC-E4`. At token grain `W2` and
  # `W3` match core/fixtures/release-version-triple/, where they are SHELL VARIABLE NAMES
  # (`W2="$WORK/cumulative"`, `W3="$WORK/branchbase"`) — and that particular false positive
  # is not merely noise: it scored LC-R1 as covered when W3 is exercised by no fixture at
  # all, so the reason to reject the derived join was also hiding a real gap.
  #
  # SO THE PREDICATE HAS THREE PARTS, and each was added because the two before it passed
  # something that could not be proof:
  #
  #   (1) the declared directory exists under core/fixtures/ AND carries a run.sh. A
  #       directory with no driver is skipped by the pre-push loop in silence — that is
  #       I20's finding, and a clause citing such a directory cites a fixture that never runs.
  #   (2) it names the clause's OWN declared enforcer. Without this, `enforcement-map-derivations`
  #       satisfies LC-E8 and LC-N2, because validate-enforcement-map.sh has its own W1 and W2
  #       and the two vocabularies collide on the token. A fixture that never drives the script
  #       the clause binds cannot be evidence about that clause whatever it names.
  #   (3) it names the code on a line that is neither a COMMENT nor a contract `code:`
  #       declaration. The comment half is I64's hole arriving one file over — a fixture whose
  #       only mention of a code is a header sentence saying which checks it covers proves
  #       nothing, and six fixtures were in exactly that state. The `code:` half is the other
  #       direction: fixtures that SEED a contract copy (layer-adjudication-tier,
  #       layer-contract-conformance) name every code they seed, and a mutation harness that
  #       rewrites `code: W2` into `code: W4` would otherwise satisfy this join for both.
  #
  # `fixture: none` IS DATA, NOT AN EXEMPTION, and this is the field's whole point. The
  # charter asked for a row per clause carrying its proof; a clause with no fixture is then a
  # counted gap that the build reports, rather than an absence nobody can see. Measured when
  # this shipped: 29 clauses declare a fixture, 14 declare none. The reverse arm is what stops
  # `none` decaying into the exemption it looks like — a clause may not declare `none` while a
  # fixture exists that would satisfy (1)-(3), so writing a fixture and forgetting the clause
  # fails the build instead of leaving the gap on the books forever.
  # READ EACH CORPUS ONCE. THE FIRST CUT OF THIS INVARIANT FORKED ~5,000 GREPS AND NEARLY
  # DOUBLED THE VALIDATOR — 5.59s to 10.36s, at 6.21s SYSTEM against 3.73s USER. That ratio is
  # the diagnosis, not the total: it is process creation, not work, and it is the exact shape
  # v0.205.0 removed from six other invariants here. The naive form asked its three questions
  # per (clause, fixture-dir) pair, and the `none` reverse arm alone is 14 clauses x 92
  # directories x 4 forks.
  #
  # So the corpus is indexed ONCE, into a set of (dir, enforcer, code) triples that satisfy the
  # whole predicate, and every arm below is a lookup in that one file. One grep over
  # core/fixtures/ for the code vocabulary, one per enforcer basename, and a fork-free glob for
  # run.sh. Measured after: the validator is back under the pre-I65 figure.
  #
  # THE INDEX IS BUILT BY A FUNCTION TAKING A ROOT, so the probe below can build one over its
  # own synthetic tree and exercise THE SHIPPING CODE PATH. A probe that tested a separate
  # helper would prove nothing about the index the arms actually read.
  lc_i65_index() { # lc_i65_index <fixtures-root> <out-triples-file>
    local root="$1" out="$2" d b
    : > "$out"
    [ -d "$root" ] || return 0

    # (a) drivable directories — a glob, no forks.
    : > "$TMPDIR_I65/drv"
    for d in "$root"/*/; do
      [ -f "${d}run.sh" ] || continue
      _db="${d%/}"; printf '%s\n' "${_db##*/}" >> "$TMPDIR_I65/drv"
    done
    [ -s "$TMPDIR_I65/drv" ] || return 0

    # (b) which directories name each enforcer basename — one grep per enforcer, not per pair.
    : > "$TMPDIR_I65/enf"
    while IFS= read -r b; do
      [ -n "$b" ] || continue
      grep -rls -- "$b" "$root" > "$TMPDIR_I65/hits" 2>/dev/null || true
      awk -v r="$root/" -v e="$b" '{ p=$0; sub("^" r, "", p); sub("/.*", "", p); print p "\t" e }' \
        "$TMPDIR_I65/hits" | sort -u >> "$TMPDIR_I65/enf"
    done < "$TMPDIR_I65/enfnames"

    # (c) which directories name each code AT AN ATTRIBUTABLE SITE — ONE grep for the whole
    # vocabulary, then the comment and `code:` exclusions applied in awk over only the lines
    # that matched. grep -n keeps the filename so the directory is recoverable.
    grep -rnE "(^|[^A-Za-z0-9_-])(${LC_I65_ALT})([^A-Za-z0-9_-]|$)" "$root" \
      > "$TMPDIR_I65/craw" 2>/dev/null || true
    awk -v r="$root/" -F: '
      NR==FNR { codes[++nc]=$0; next }
      {
        path=$1; text=$0
        sub("^[^:]*:[0-9]*:", "", text)
        if (text ~ /^[[:space:]]*#/) next          # a comment is prose about the proof
        sub("^" r, "", path); sub("/.*", "", path)
        for (i=1; i<=nc; i++) {
          c=codes[i]
          if (text ~ ("code:[[:space:]]*" c "([^A-Za-z0-9_-]|$)")) continue   # a seeded contract row
          if (text ~ ("(^|[^A-Za-z0-9_-])" c "([^A-Za-z0-9_-]|$)")) print path "\t" c
        }
      }' "$TMPDIR_I65/codes" "$TMPDIR_I65/craw" | sort -u > "$TMPDIR_I65/code"

    # (d) the join: a triple survives only if the directory is drivable, names the enforcer and
    # names the code. Three sorted sets, one awk, no per-pair forks.
    awk -F'\t' '
      FILENAME==d  { drv[$0]=1; next }
      FILENAME==e  { enf[$1 SUBSEP $2]=1; ed[$1]=ed[$1] " " $2; next }
      { if (!($1 in drv)) next
        n=split(ed[$1], es, " ")
        for (i=1; i<=n; i++) if (es[i] != "") print $1 "|" es[i] "|" $2 }
    ' d="$TMPDIR_I65/drv" e="$TMPDIR_I65/enf" \
      "$TMPDIR_I65/drv" "$TMPDIR_I65/enf" "$TMPDIR_I65/code" | sort -u > "$out"
  }

  TMPDIR_I65="$(mktemp -d "${TMPDIR:-/tmp}/i65-XXXXXX")"

  lc_i65_pairs="$TMPDIR_I65/pairs"
  awk '
    /^  - id:/       { if (id != "") emit(); id=$3; enf=""; code=""; fx="" ; next }
    /^    enforcer:/ { enf=$2; next }
    /^    code:/     { code=$2; next }
    /^    fixture:/  { fx=$2; next }
    END              { if (id != "") emit() }
    function emit() { if (enf != "" && code != "") printf "%s|%s|%s|%s\n", id, enf, code, fx }
  ' "$lc_file" > "$lc_i65_pairs"

  if [ ! -s "$lc_i65_pairs" ]; then
    err "I65 read ZERO (clause, enforcer, code, fixture) rows out of layer-contract.yaml. Every arm below iterates that set, so an empty read passes the whole invariant by having no subject — which reads exactly like a contract whose every clause is proven."
  fi

  # The vocabularies the index is built over, derived from the contract rather than listed.
  awk -F'|' '{print $3}' "$lc_i65_pairs" | sort -u > "$TMPDIR_I65/codes"
  awk -F'|' '{n=split($2,p,"/"); print p[n]}' "$lc_i65_pairs" | sort -u > "$TMPDIR_I65/enfnames"
  LC_I65_ALT="$(awk 'NR>1{printf "|"} {printf "%s", $0}' "$TMPDIR_I65/codes")"

  # THE PROBE, written and run here rather than trusted, and it drives THE SAME INDEXER the
  # arms below read. lc_i65_index() is a grep, an awk and a three-way join; a change to any of
  # them can turn it into a function that answers "bound" for everything or nothing, and either
  # way every arm goes quiet in the same direction. So build a tree whose four directories have
  # exactly one right answer between them, index it with the shipping function, and refuse to
  # run the invariant unless the answers total exactly 1.
  lc_p65="$TMPDIR_I65/probe"
  mkdir -p "$lc_p65/fx/yes" "$lc_p65/fx/no-comment" "$lc_p65/fx/no-driver" "$lc_p65/fx/other-enf"
  printf 'bash probe-enforcer.sh\nok "PROBE65 fired"\n'  > "$lc_p65/fx/yes/run.sh"
  printf 'bash probe-enforcer.sh\n# PROBE65 is not exercised here\n    code: PROBE65\n' \
                                                         > "$lc_p65/fx/no-comment/run.sh"
  printf 'bash probe-enforcer.sh\nok "PROBE65 fired"\n'  > "$lc_p65/fx/no-driver/driver.sh"
  printf 'bash other-enforcer.sh\nok "PROBE65 fired"\n'  > "$lc_p65/fx/other-enf/run.sh"
  lc_p65_codes_save="$TMPDIR_I65/codes.save"; cp "$TMPDIR_I65/codes" "$lc_p65_codes_save"
  lc_p65_enf_save="$TMPDIR_I65/enfnames.save"; cp "$TMPDIR_I65/enfnames" "$lc_p65_enf_save"
  lc_p65_alt_save="$LC_I65_ALT"
  printf 'PROBE65\n' > "$TMPDIR_I65/codes"
  printf 'probe-enforcer.sh\n' > "$TMPDIR_I65/enfnames"
  LC_I65_ALT='PROBE65'
  lc_i65_index "$lc_p65/fx" "$TMPDIR_I65/probe.triples"
  lc_p65_n=0
  grep -qxF 'yes|probe-enforcer.sh|PROBE65'        "$TMPDIR_I65/probe.triples" && lc_p65_n=$((lc_p65_n+1))
  grep -qxF 'no-comment|probe-enforcer.sh|PROBE65' "$TMPDIR_I65/probe.triples" && lc_p65_n=$((lc_p65_n+100))
  grep -qxF 'no-driver|probe-enforcer.sh|PROBE65'  "$TMPDIR_I65/probe.triples" && lc_p65_n=$((lc_p65_n+1000))
  grep -qxF 'other-enf|probe-enforcer.sh|PROBE65'  "$TMPDIR_I65/probe.triples" && lc_p65_n=$((lc_p65_n+10000))
  cp "$lc_p65_codes_save" "$TMPDIR_I65/codes"
  cp "$lc_p65_enf_save"   "$TMPDIR_I65/enfnames"
  LC_I65_ALT="$lc_p65_alt_save"
  if [ "$lc_p65_n" -ne 1 ]; then
    err "I65's probe scored $lc_p65_n where exactly 1 is correct. The four probe directories are: one bound (+1), one naming the code only in a comment and on a contract code: line (+100), one with no run.sh (+1000), and one naming a DIFFERENT enforcer (+10000). Any other total means lc_i65_index has stopped reading the driver, the comment grain, the code: grain or the enforcer, and every result below is produced by an index that can no longer tell proof from mention."
  else
    # THE REAL INDEX, built once. Every arm below is a lookup in this file.
    lc_i65_index "$REPO_ROOT/core/fixtures" "$TMPDIR_I65/triples"
    if [ ! -s "$TMPDIR_I65/triples" ]; then
      err "I65 indexed core/fixtures/ and found ZERO (directory, enforcer, code) triples. The probe above proves the indexer works, so an empty result here means the fixture corpus moved out from under it — and an empty index makes every declared fixture fail and every 'none' pass, which is loud in one direction and silent in the other."
    fi
    # HELD IN MEMORY, and read HERE rather than earlier: `lc_i65_index` above rewrites both of
    # these files, and the probe run before it deliberately writes a fake enforcer list and
    # restores it. Loading them any sooner would answer every lookup below from the probe's
    # index instead of the real one. Two reads replace two greps per clause.
    _i65_enf="$(<"$TMPDIR_I65/enf")"
    _i65_triples="$(<"$TMPDIR_I65/triples")"
    while IFS='|' read -r fid fenf fcode ffx; do
      [ -n "$fid" ] || continue
      if [ -z "$ffx" ]; then
        err "I65 $fid: no 'fixture:' declared. Every clause names the fixture that proves its code fires, or the literal 'none' to record that nothing does. An undeclared field is neither, and it is the only one of the three states this invariant cannot report."
        continue
      fi
      fenf_base="${fenf##*/}"
      if [ "$ffx" = none ]; then
        # REVERSE: 'none' may not be written over a fixture that would satisfy the join. One
        # awk over the index, not a walk of 92 directories per clause.
        lc_i65_witness="$(awk -F'|' -v e="$fenf_base" -v c="$fcode" '$2==e && $3==c {print $1; exit}' "$TMPDIR_I65/triples")"
        [ -z "$lc_i65_witness" ] \
          || err "I65 $fid: declares 'fixture: none' but core/fixtures/$lc_i65_witness/ drives '$fenf_base' and names '$fcode' at an attributable site — so the proof exists and the clause says it does not. 'none' is a counted gap, not a default; a fixture written without updating the clause it proves leaves the gap on the books forever."
        continue
      fi
      case "$ffx" in
        */*|.*) err "I65 $fid: fixture '$ffx' is not a bare directory name under core/fixtures/. The value is joined to that one root so a clause cannot cite a proof living outside the suite the pre-push drives."; continue ;;
      esac
      fdir="$REPO_ROOT/core/fixtures/$ffx"
      if [ ! -d "$fdir" ]; then
        err "I65 $fid: declares fixture '$ffx', which is not a directory under core/fixtures/. A clause citing a fixture that does not exist states a proof nothing can run."
        continue
      fi
      if [ ! -f "$fdir/run.sh" ]; then
        err "I65 $fid: fixture '$ffx' has no run.sh. The pre-push loop skips a driverless directory in silence (I20's finding), so this clause cites a proof that never executes and reads exactly like one that passes every push."
        continue
      fi
      if ! in_lines "$ffx	$fenf_base" "$_i65_enf"; then
        err "I65 $fid: fixture '$ffx' never names '$fenf_base', the enforcer this clause declares. A fixture that does not drive the script the clause binds cannot be evidence about that clause — the two W1/W2 vocabularies in this repo collide on the token, so naming the code alone is satisfied by a fixture for a different enforcer entirely."
        continue
      fi
      in_lines "$ffx|$fenf_base|$fcode" "$_i65_triples" \
        || err "I65 $fid: fixture '$ffx' drives '$fenf_base' but names '$fcode' nowhere a run can attribute — only in comments, or only on a seeded contract 'code:' line. A fixture header sentence listing the checks it covers is prose about the proof, not the proof; when this shipped, six fixtures were in exactly that state for codes they do exercise. Name the code in the assertion that proves it, so the fixture's own output says which clause it closed."
    done < "$lc_i65_pairs"
  fi
  rm -rf "$TMPDIR_I65"

  # --- I58: the ADJUDICATED level is one token across the contract and the enforcer that acts
  # on it, PROVEN BY RUNNING THE ENFORCER rather than by grepping it. ---
  # vocabulary: ADJUDICATED clause codes
  # vocabulary-invariant: I58
  # vocabulary-owner: core/skills/ai-dlc/layer-contract.yaml
  # vocabulary-extract: adjudicated-codes
  # vocabulary-readers: core/skills/ai-dlc-update/reconcile/layer-drift.sh
  #
  # `level:` was declared for six contract versions with NO behavioural reader anywhere in the
  # tree: I37 checked it was present and nothing checked what it did. v0.213.0 gave it one —
  # `reconcile/layer-drift.sh` derives its adjudicable code set from this file — and that is
  # exactly the shape that goes inert without a sound. Rename the token on either side, break
  # the reader's awk, point it at the wrong path, and every ADJUDICATED clause quietly degrades
  # to a WARN with extra prose: the classifier still runs, still emits every row it emitted
  # before, and the blocking half simply never appears. Nothing else in the build would notice,
  # because there is no row whose ABSENCE any other check asserts.
  #
  # So this joins the two sides by running the reader's own `--adjudicated-codes` mode against
  # the same ref the declaration is read from. A restated extraction here would agree with
  # itself while the shipped one had stopped resolving — the defect it exists to catch.
  #
  # BOTH REFS ARE HEAD, deliberately. Reading the declaration from the worktree and the reader's
  # answer from a ref makes every uncommitted contract edit a false positive, which is the shape
  # an operator turns off. The join is about grammar agreement, not about staged content, and
  # pre-push runs it against the commits actually being pushed.
  lc_rel="core/skills/ai-dlc/layer-contract.yaml"
  lc_drift="core/skills/ai-dlc-update/reconcile/layer-drift.sh"
  if [ "$lc_file" = "$REPO_ROOT/$lc_rel" ] && git -C "$REPO_ROOT" cat-file -e "HEAD:$lc_rel" 2>/dev/null; then
    lc_adj_declared="$(git -C "$REPO_ROOT" show "HEAD:$lc_rel" | awk '
      /^  - id:/    { lvl=""; next }
      /^    level:/ { lvl=$2; next }
      /^    code:/  { if (lvl == "ADJUDICATED") print $2; next }
    ' | sort)"
    lc_adj_read="$(bash "$REPO_ROOT/$lc_drift" --adjudicated-codes "$REPO_ROOT" HEAD 2>/dev/null | sort)"

    if [ "$lc_adj_declared" != "$lc_adj_read" ]; then
      err "I58: layer-contract.yaml declares $(printf '%s' "$lc_adj_declared" | grep -c .) clause code(s) at level ADJUDICATED [$(printf '%s' "$lc_adj_declared" | tr '\n' ' ')] but layer-drift.sh's own --adjudicated-codes reader answers with [$(printf '%s' "$lc_adj_read" | tr '\n' ' ')]. The level is declared and not acted on, so every clause at it degrades to a WARN with extra prose and no blocking row ever appears."
    elif [ -z "$lc_adj_declared" ]; then
      echo "  note: I58 — 0 clauses at level ADJUDICATED, so the reader has no subject. This is an affirmative zero, not a pass: the negative probe below still runs." >&2
    fi

    # THE NEGATIVE PROBE. Everything above is satisfied by a reader that returns the right set
    # for the wrong reason — including one that hard-codes it. Mutate the LEVEL TOKEN in a copy
    # of the contract, publish that copy as a throwaway commit (a dangling object; nothing is
    # written to any ref), and re-ask. A reader keying on the token answers empty. A reader that
    # answers the same thing is not reading the level at all.
    lc_probe_tmp="$(mktemp -d)"
    git -C "$REPO_ROOT" show "HEAD:$lc_rel" | sed 's/^\(    level:\) ADJUDICATED$/\1 ADJUDICATEDX/' > "$lc_probe_tmp/c.yaml"
    if git -C "$REPO_ROOT" show "HEAD:$lc_rel" | cmp -s - "$lc_probe_tmp/c.yaml"; then
      err "I58 negative probe: the level-token mutation matched nothing in layer-contract.yaml, so the probe never mutated anything and its silence proves nothing about the reader."
    else
      lc_probe_blob="$(git -C "$REPO_ROOT" hash-object -w "$lc_probe_tmp/c.yaml")"
      lc_probe_idx="$lc_probe_tmp/index"
      GIT_INDEX_FILE="$lc_probe_idx" git -C "$REPO_ROOT" read-tree HEAD 2>/dev/null
      GIT_INDEX_FILE="$lc_probe_idx" git -C "$REPO_ROOT" update-index --cacheinfo "100644,$lc_probe_blob,$lc_rel" 2>/dev/null
      lc_probe_tree="$(GIT_INDEX_FILE="$lc_probe_idx" git -C "$REPO_ROOT" write-tree 2>/dev/null)"
      lc_probe_commit="$(git -C "$REPO_ROOT" commit-tree "$lc_probe_tree" -m "I58 probe" </dev/null 2>/dev/null)"
      if [ -z "$lc_probe_commit" ]; then
        err "I58 negative probe: could not build the probe commit, so the reader's dependence on the level token is UNPROVEN. Do not read the clean result above as coverage."
      else
        lc_probe_read="$(bash "$REPO_ROOT/$lc_drift" --adjudicated-codes "$REPO_ROOT" "$lc_probe_commit" 2>/dev/null)"
        if [ -n "$lc_probe_read" ]; then
          err "I58 negative probe: the level token was mutated to ADJUDICATEDX and layer-drift.sh still reports [$(printf '%s' "$lc_probe_read" | tr '\n' ' ')] as adjudicable. Its set is not derived from the contract's level field, so moving a clause between levels there changes nothing about what blocks."
        fi
      fi
    fi
    rm -rf "$lc_probe_tmp"
  fi
fi

# --- I59: every mode a shipped script DISPATCHES is named in that script's own prose --
# THE STATE THIS MAKES UNREPRESENTABLE. A `case` arm no line of prose names is a mode that
# exists and cannot be found. Nothing breaks; the mode is invisible, and the operator who
# reads the usage block concludes it is not there.
#
# THE DEFECT THIS WAS DERIVED FROM, v0.213.1. `readopt-override.sh --merge` has been a
# dispatched three-way re-adoption merge since before the reference consumer's base sha, and
# the script's `# Usage:` header and its exit-2 usage string both listed only
# dossier / --check / --stamp. A consumer mid-pull read that block, concluded the flag did
# not exist, and filed the pull brief's own instruction — which names it correctly — as a
# defect. The report was wrong and the documentation was the reason.
#
# I49 already holds both halves for ONE script (core-paths.sh), keyed on a sentinel that
# script carries. This is the same predicate with the CORPUS derived instead of named: every
# shipped `.sh` under core/, arms parsed from the case statements themselves, so a script
# that ships tomorrow is in scope without an edit here.
#
# MEASURED BEFORE SHIPPING, which is this repo's bar for a new lint. 111 mode arms across the
# shipped corpus. The false-positive set is EMPTY with ONE enumerated exemption, `--help`:
# six scripts dispatch `-h|--help` to print their own header, and requiring the header to
# name it is asking a file to cite itself. Every other arm was already documented except the
# two real findings this was derived from — `--merge` above and
# `validate-adversarial-convergence.sh --transcript`, both fixed in the same release.
#
# THE REVERSE DIRECTION IS DELIBERATELY NOT CHECKED, and this is a measurement, not an
# oversight: a flag cited in a usage line is dispatched by a `case` arm in only some scripts
# — others use `if [ "$1" = ... ]` — so the same join run backwards reports 7 of 35 cited
# flags as undispatched, all 7 false. A lint with a fifth of its output wrong is one the
# operator turns off.
#
# core/fixtures/ is out of corpus for the reason I49 and I50 state: fixtures deliberately
# carry ghost text, and a lint that reads them reports their mutants as findings.
#
# ONE READER, used by the corpus scan AND by the probe below. A probe that exercises a copy
# of the extraction proves the copy.
i59_modes_of() {
  grep -oE '^[[:space:]]*(--?[a-z][a-z0-9-]*\|)*--?[a-z][a-z0-9-]*\)' "$1" \
    | tr -d ' )' | tr '|' '\n' | grep '^--' | sort -u
}
i59_undocumented_in() {   # <file> -> one undocumented mode per line
  local f="$1" m
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    if [ "$m" = "--help" ]; then continue; fi   # I59_HELP_EXEMPTION
    awk -v m="$m" 'index($0,m) && ($0 ~ /^[[:space:]]*#/ || index($0,"usage")) { found=1; exit }
                   END { exit !found }' "$f" || printf '%s\n' "$m"
  done < <(i59_modes_of "$f")
}

# THE LIVENESS PROBE. This invariant reports an ABSENCE, and its extraction is a regex over a
# shell construct — the side that moves. A grammar that stops matching returns the same empty
# set as a clean tree. So it is asked, every run, to answer a file whose answer is known.
i59_probe_dir="$(mktemp -d)"
cat > "$i59_probe_dir/probe.sh" <<'I59_PROBE'
#!/usr/bin/env bash
# Usage:
#   probe.sh --documented    named right here, so it must NOT be reported
case "$1" in
  --documented) : ;;
  --probe-undocumented) : ;;
  -h|--help) : ;;
esac
I59_PROBE
i59_probe="$(i59_undocumented_in "$i59_probe_dir/probe.sh" | tr '\n' ' ')"
rm -rf "$i59_probe_dir"

if ! grep -q -- '--probe-undocumented' <<<"$i59_probe"; then
  err "I59's dispatch grammar did not fire on its own probe: a case arm that no comment names was not reported [probe answered: ${i59_probe:-<nothing>}]. The corpus result below is an empty set produced by an extraction that matches nothing, which reads exactly like a documented tree."
elif grep -q -- '--documented ' <<<"$i59_probe"; then
  err "I59 reported a DOCUMENTED mode on its own probe [probe answered: $i59_probe]. The predicate is not reading the prose, so every finding it prints is suspect."
elif grep -q -- '--help' <<<"$i59_probe"; then
  err "I59 reported the exempt --help arm on its own probe [probe answered: $i59_probe]. The exemption is gone or narrowed, and the six scripts that dispatch -h|--help to print their own header become findings — the measured-empty false-positive set is held by that exemption."
else
  # CORPUS BY `find`, NOT `git ls-files`. The fixture that tests this invariant seeds a
  # COPY of the tree with no `.git` in it, where `ls-files` answers nothing — so a
  # git-derived corpus would make the scan vacuous inside the very fixture that exists to
  # prove it fires, and read as a clean tree in both places. The count is guarded below for
  # the same reason.
  i59_undoc=""
  i59_n=0
  i59_files=0
  while IFS= read -r i59_f; do
    [ -n "$i59_f" ] || continue
    i59_files=$((i59_files + 1))
    while IFS= read -r i59_m; do
      [ -n "$i59_m" ] || continue
      i59_undoc="${i59_undoc}
  ${i59_f#"$REPO_ROOT/"} $i59_m"
      i59_n=$((i59_n + 1))
    done < <(i59_undocumented_in "$i59_f")
  done < <(find "$REPO_ROOT/core" -type f -name '*.sh' -not -path "$REPO_ROOT/core/fixtures/*" | sort)
  if [ "$i59_files" -lt 20 ]; then
    err "I59 found only $i59_files shipped script(s) under core/ to scan. The corpus is derived by find; a count this low means the tree is not the one this runs against, and an empty corpus reports the same clean line as a documented one."
  elif [ "$i59_n" -ne 0 ]; then
    err "I59 found $i59_n dispatched mode(s) documented nowhere in their own file:$i59_undoc
  Each is a mode that exists and cannot be discovered. Name it in the script's usage block — an operator who reads that block and concludes the mode is absent files a correct instruction as a defect, which is the v0.213.1 case this invariant was derived from."
  fi
fi

# --- I60: every MODE one shipped file names on another shipped script is dispatched there --
#
# THE STATE THIS MAKES UNREPRESENTABLE. A file — prose or code — tells a caller to run
# `<script>.sh --mode`, and the script does not accept `--mode`. The call exits 2 on an
# unknown argument. Whether that 2 reaches anyone depends entirely on the call site, and the
# two sites already hand-listed show both endings: I49's caller reads 2 as "cannot determine
# what core is", so a typo and an unreadable manifest arrive as the same answer; I53's reads
# any non-zero as "no operator citation" and turns a clean tree into a FAIL.
#
# WHY THIS EXISTS RATHER THAN A THIRD HAND-LISTING. I49 binds core-paths.sh's modes; I53
# binds validate-escalation-resolution.sh's. v0.210.0 opened a third instance
# (`validate-mandatory-rules.sh` → `validate-audit-anchors.sh --prior-sprint-sha`) and it was
# never given an invariant. CLAUDE.md says to derive both sides of a join rather than
# hand-list either. Both sides are derived here: the citation side by grep over the shipped
# corpus, the dispatch side out of each target's own argument parsing, so a script that ships
# tomorrow and a caller written tomorrow are both in scope without an edit here.
#
# I59 IS NOT THIS INVARIANT, and the difference is the whole reason this one is owed. I59
# generalised the OTHER half of the same join — every dispatched mode is named in its own
# file's prose. This is the half no general invariant holds: every CITED mode is dispatched.
# I59 also does not subsume I49/I53's documentation arms, which is a measurement rather than a
# reading: drop `--list` from core-paths.sh's usage() echo and I49 reports it while I59 stays
# silent, because I59 accepts a mode named in ANY comment and I49 requires it in the usage
# line. I49 and I53 therefore keep both of their arms. The redundancy with the ghost arm here
# is deliberate and has a precedent in this file: v0.214.0 shipped I59 alongside I49's
# documentation arm for the same reason — the per-target invariants carry the per-target harm
# in their message text, and a derived corpus cannot.
#
# MEASURED BEFORE SHIPPING, which is this repo's bar for a new lint. 44 (script, mode) pairs
# across 25 targets; false-positive set EMPTY. The predecessor's §9 recorded this
# generalisation as measured-and-rejected at 31 pairs across 15 targets with 8 misses, and the
# re-derivation found the misses were the extraction's, in two enumerated classes:
#   - FIVE of the eight are produced by THIS FILE, which quotes `<script>.sh --mode` inside
#     error prose, inside its own grep flags (`--exclude=core-paths.sh --exclude=…` reads as
#     a citation of `--exclude`) and inside I59's probe heredoc. I49 and I53 already exclude
#     this file by name for exactly that reason; the exclusion is inherited, not invented.
#   - THREE are dispatch forms the `case`-arm grammar cannot see. Six shipped scripts parse
#     their mode with `[ "$1" = "--x" ]` or `[[ "$1" == "--x" ]]` rather than a case arm, and
#     `audit-rule-files.sh` dispatches `--fail-on=any|deterministic` as VALUED arms while the
#     citation names `--fail-on`. Both sides are normalised at `=` and both dispatch forms are
#     read below. This is the same class I59's header names as its reason for declining the
#     reverse direction within a single file.
# So the recorded "not empty" was the derivation's own grammar, exactly as §9 suspected, and
# the count was of the wrong set as well as the wrong size.
#
# UNRESOLVED TARGETS ARE SKIPPED, not reported. "Does core ship a script by this name" is I50's
# join, over a different citation grammar (`scripts/ai-dlc/<x>`), and reporting it here would
# fire on every consumer-owned script a template legitimately names. Measured: 0 citations in
# the shipped corpus resolve to nothing, so the skip discards no live subject today.
#
# core/fixtures/ is out of corpus for the reason I49, I50 and I59 all state: fixtures write
# wrong spellings on purpose, and a lint that reads them reports their mutants as findings.
#
# ONE READER PAIR, used by the corpus scan AND by the probe below. A probe that exercises a
# copy of the extraction proves the copy, not the extraction.
i60_citations() {   # <root> -> "<basename.sh> <--mode>" per line
  grep -rhoE '[A-Za-z0-9_.-]+\.sh"?[[:space:]]+--[a-z][a-z0-9-]*' \
    "$1/core" "$1/scripts" "$1/templates" 2>/dev/null \
    --exclude-dir=fixtures --exclude="$(basename "$0")" \
    | tr -d '"' | sed -E 's/[[:space:]]+/ /g' | sort -u
}
i60_dispatches() {  # <file> -> one dispatched mode per line, `=`-valued arms normalised
  { grep -oE '^[[:space:]]*(--[a-z][a-z0-9-]*(=[a-zA-Z0-9|-]*)?\|)*--[a-z][a-z0-9-]*(=[a-zA-Z0-9-]*)?\)' "$1" \
      | tr -d ' )' | tr '|' '\n'
    grep -oE '==?[[:space:]]+"--[a-z][a-z0-9-]*"' "$1" | grep -oE -- '--[a-z][a-z0-9-]*'
  } | sed -E 's/=.*//' | grep '^--' | sort -u
}
i60_ghosts_in() {   # <root> -> "<target.sh> <--mode>" per undispatched citation
  local root="$1" t m f
  while read -r t m; do
    [ -n "$t" ] && [ -n "$m" ] || continue
    f="$(find "$root/core" -type f -name "$t" -not -path '*/core/fixtures/*' 2>/dev/null | head -1)"
    [ -n "$f" ] || continue
    i60_dispatches "$f" | grep -qx -- "$m" || printf '%s %s\n' "$t" "$m"
  done < <(i60_citations "$root")
}

# THE LIVENESS PROBE. This invariant reports an ABSENCE across two regexes over shell
# constructs — both sides move. A citation grammar that stops matching, or a dispatch grammar
# that matches everything, returns the same empty set as a tree with no ghost in it. So it is
# asked, every run, to answer a tree whose answer is known — and the probe target dispatches
# one mode as a `case` arm and one as a `[ "$1" = … ]` test, because the second form is the
# fix this invariant shipped and an extraction that lost it again would go quiet, not red.
i60_probe_dir="$(mktemp -d)"
mkdir -p "$i60_probe_dir/core/scripts" "$i60_probe_dir/scripts" "$i60_probe_dir/templates"
cat > "$i60_probe_dir/core/scripts/i60-probe-target.sh" <<'I60_TARGET'
#!/usr/bin/env bash
case "$1" in
  --probe-case) : ;;
esac
if [ "$1" = "--probe-if" ]; then :; fi
I60_TARGET
cat > "$i60_probe_dir/core/i60-probe-caller.md" <<'I60_CALLER'
Run i60-probe-target.sh --probe-case to start.
Then i60-probe-target.sh --probe-if to confirm.
Finally i60-probe-target.sh --probe-ghost, which the target does not dispatch.
I60_CALLER
i60_probe="$(i60_ghosts_in "$i60_probe_dir" | awk '{print $2}' | tr '\n' ' ')"
rm -rf "$i60_probe_dir"

if ! grep -q -- '--probe-ghost' <<<"$i60_probe"; then
  err "I60's join did not fire on its own probe: a cited mode the probe target does not dispatch was not reported [probe answered: ${i60_probe:-<nothing>}]. Either the citation grammar matched nothing or the dispatch grammar matched everything; the corpus result below is an empty set produced by an extraction that cannot find a ghost, which reads exactly like a tree that has none."
elif grep -q -- '--probe-case' <<<"$i60_probe"; then
  err "I60 reported a mode the probe target dispatches as a case arm [probe answered: $i60_probe]. The dispatch side is not reading case arms, so every finding it prints is suspect."
elif grep -q -- '--probe-if' <<<"$i60_probe"; then
  err "I60 reported a mode the probe target dispatches as \`[ \"\$1\" = \"--probe-if\" ]\` [probe answered: $i60_probe]. The dispatch side has lost the non-case form — six shipped scripts parse their mode that way, and every one of them becomes a false finding. That regression is the measured false-positive set this invariant was blocked on for two programs."
else
  i60_pairs="$(i60_citations "$REPO_ROOT" | grep -c .)"
  i60_targets="$(i60_citations "$REPO_ROOT" | awk '{print $1}' | sort -u | grep -c .)"
  if [ "$i60_pairs" -lt 20 ] || [ "$i60_targets" -lt 10 ]; then
    err "I60 derived only $i60_pairs cited (script, mode) pair(s) across $i60_targets target(s). The corpus is derived by grep over core/, scripts/ and templates/; counts this low mean the citation grammar stopped matching the tree, and an empty corpus reports the same clean line as a tree with no ghost citation in it."
  else
    i60_ghost="$(i60_ghosts_in "$REPO_ROOT")"
    if [ -n "$i60_ghost" ]; then
      err "I60 found shipped file(s) naming a mode the target script does not dispatch:
  $(printf '%s' "$i60_ghost" | tr '\n' '~' | sed 's/~/\n  /g')
  Each is an instruction that exits 2 on an unknown argument. Whether that 2 is read as a refusal or as a malformed invocation is the call site's business, and the two sites hand-listed by I49 and I53 read it both ways — so a mode named here and absent there is a wrong instruction reaching a gate as an authoritative answer."
    fi
  fi
fi

# --- I39: the ledger status vocabulary is one set across emitter and rulebook --
# vocabulary: push-candidate ledger statuses
# vocabulary-invariant: I39
# vocabulary-owner: core/skills/ai-dlc-update/reconcile/ledger-reverify.sh
# vocabulary-extract: ledger-statuses
# vocabulary-readers: core/skills/ai-dlc-update/SKILL.md, core/skills/ai-dlc-update/reconcile/emit-report.sh
# THE STATE THIS MAKES UNREPRESENTABLE. `ledger-reverify.sh`'s statuses are a contract with
# three readers that do not check each other: the operator following SKILL.md step 3f, the
# report heading in emit-report.sh, and any consumer script grepping the TSV. Nothing joined
# them. Renaming a status in the emitter alone left step 3f documenting a token no run can
# produce and — the silent half — a status reaching an operator with no entry in the step that
# tells them what to do with it. Both halves read exactly like a complete rename.
#
# MEASURED at v0.186.0, renaming the `NAMED-*` status: five statuses emitted, five documented,
# the two sets equal, and the false-positive set of this predicate EMPTY. The bound matters —
# the same bullet grammar over the WHOLE of SKILL.md matches 20 tokens, 15 of them other
# detectors' statuses, so the reverse direction is scoped to step 3f's own span. Widening it
# would need those detectors joined too, and their emission styles are not uniform (layer-drift
# emits through variables), which is a zero waiting to happen in the extraction rather than a
# finding. One script, one uniform `emit <LITERAL>` style, both directions.
lr_file="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh"
lr_skill="$REPO_ROOT/core/skills/ai-dlc-update/SKILL.md"
if [ ! -f "$lr_file" ] || [ ! -f "$lr_skill" ]; then
  err "I39 cannot find ledger-reverify.sh or its ai-dlc-update/SKILL.md. A scan over a missing file reads exactly like agreement; both are core_manifest machinery and must exist."
else
  lr_emitted="$(grep -oE '^[[:space:]]*emit [A-Z][A-Z0-9-]+' "$lr_file" | awk '{print $2}' | sort -u)"
  lr_documented="$(awk '/^3f\. \*\*/{on=1} on && /^[0-9]+\. \*\*/{exit} on' "$lr_skill" \
    | grep -oE '^[[:space:]]*- `[A-Z][A-Z0-9-]+` →' | grep -oE '[A-Z][A-Z0-9-]+' | sort -u)"
  # Either side coming back empty is the failure this check exists to prevent, not a pass:
  # an extraction that has stopped matching reports agreement between two empty sets.
  if [ -z "$lr_emitted" ]; then
    err "I39 found NO statuses in ledger-reverify.sh. Either the emitter no longer uses 'emit <STATUS>' or the script changed shape; a zero here silently retires the whole check."
  elif [ -z "$lr_documented" ]; then
    err "I39 found NO documented statuses in ai-dlc-update/SKILL.md step 3f. Either the step was renumbered or its bullet grammar changed; a zero here silently retires the whole check."
  else
    for st in $lr_emitted; do
      grep -qxF -- "$st" <<<"$lr_documented" || \
        err "I39: ledger-reverify.sh emits '$st' but SKILL.md step 3f never documents it. The operator is handed a verdict the step that governs the ledger does not explain, which is how a status reaches a pull with no stated handling."
    done
    for st in $lr_documented; do
      grep -qxF -- "$st" <<<"$lr_emitted" || \
        err "I39: SKILL.md step 3f documents '$st' but ledger-reverify.sh never emits it. The step describes a row no run can produce — an operator waiting on a signal that cannot arrive reads it as 'nothing to do'."
    done
    # The heading emit-report.sh renders is the third reader, and it names a SUBSET by design
    # (the rows the operator acts on). A subset is checkable without hand-listing it: every
    # status the heading names must be one the emitter still produces.
    er_file="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/emit-report.sh"
    if [ -f "$er_file" ]; then
      er_sts="$(grep -oE 'Push-candidate ledger — [A-Z][A-Z0-9 /-]+' "$er_file" \
                | grep -oE '\b[A-Z][A-Z0-9-]*-[A-Z][A-Z0-9-]*\b' | sort -u)"
      for st in $er_sts; do
        grep -qxF -- "$st" <<<"$lr_emitted" || \
          err "I39: emit-report.sh's push-candidate heading names '$st', which ledger-reverify.sh does not emit. The report promises the operator a section that can never have rows in it."
      done
      # THE FOURTH READER IS THE ONE THAT ACTS, and it was the one nothing checked. The heading
      # above announces the rows to the operator; step 8 is where the operator does something
      # about them. A status the report puts in front of a reader and step 8 gives no
      # disposition to is a DUTY WITH NO ACTOR -- and it fails silently in the closing
      # direction, because a reader executing step 8 literally leaves such a row unannotated
      # and the entry then re-reports forever on a receipt step 3f has already called
      # structurally incapable of deciding it.
      #
      # THE THREE ARMS ABOVE CANNOT SEE IT AND WIDENING THEM IS NOT THE FIX. Their SKILL-side
      # population is step 3f's span alone, bounded for the reason in this arm's header: the
      # same bullet grammar over the whole file matches other detectors' statuses. 3f is the
      # DESCRIPTION and was correct throughout; the disagreement lived in the ACTION.
      #
      # BACKTICK-DELIMITED, AND THAT IS THE WHOLE OF THE FALSE-POSITIVE NARROWING. An unbounded
      # `grep -F NAMED-UPSTREAM` is satisfied by `NAMED-UPSTREAM-AMBIGUOUS` -- a different
      # status carrying a different duty, deliberately NOT attributed -- so the bare-substring
      # form passes on a disposition written for the wrong row. SKILL.md writes every status in
      # backticks, so the delimiters are a boundary this corpus already supplies rather than one
      # imposed on it. Measured over the acting region with the delimiters: the eight statuses
      # that owe an action all resolve, and `STILL-LIVE` -- filtered from the report and owed no
      # action -- resolves 0, so the predicate discriminates rather than flagging everything.
      s8="$(awk '/^8\. \*\*Deliver/{on=1} on && /^9\. \*\*Safety/{exit} on' "$lr_skill")"
      if [ -z "$er_sts" ]; then
        err "I39: emit-report.sh's push-candidate heading yielded NO statuses. The two arms above just went vacuous over an empty set, which reads exactly like agreement."
      elif [ -z "$s8" ]; then
        err "I39 could not locate SKILL.md's step 8 acting region. Either the step was renumbered or its heading grammar changed; a zero here retires the acting-reader check while the arms above still pass."
      else
        # SCOPED TO THE HEADING STATUSES THE EMITTER ACTUALLY PRODUCES, and that intersection is
        # the difference between one finding per defect and two. A heading naming a PHANTOM status
        # is already reported by the subset arm above; adding a second message for it says nothing
        # new, because a row that can never exist owes the operator no disposition. Entangled arms
        # are the shape where one of the two is vacuous and nobody can tell which -- measured here
        # as a mutation battery whose phantom-heading mutant produced two failures for one defect.
        for st in $er_sts; do
          grep -qxF -- "$st" <<<"$lr_emitted" || continue
          grep -qF -- "\`$st\`" <<<"$s8" || \
            err "I39: emit-report.sh's push-candidate heading puts '$st' in front of the operator, but SKILL.md step 8 -- the step that ACTS on those rows -- never names it. The operator is handed a row with no stated disposition, which is read as nothing to do."
        done
      fi
    fi
  fi
fi

# --- I35: H1's fixture criterion states I20's contract, not a stricter one ----
# H1 is LLM-read at every gate and had RESTATED this contract instead of stating the
# property: it required a `README.md` and a `seed.sh` of every bound fixture, and
# attributed that to "the validate-enforcement-map.sh I20 contract". I20 requires
# neither. It requires a DRIVER, falling back to a README that declares why one is
# impossible. The restatement was strictly tighter than the mechanism it cited, and
# core itself violates it: 44 of 73 fixtures ship no README and 26 no seed.sh, all of
# them correct, all of them a gate FAIL under the old prose. A consumer hit it on two
# core-owned fixtures it cannot edit, behind a P0 fix.
#
# The marker is the joinable part: H1 tells the reader which string declares the
# exemption, and if I20's marker moves, H1 sends them looking for a string no README
# carries and compliant fixtures start failing. Bind the two, same shape as I15/I18/I34.
# The rest of the criterion is prose an LLM reads; this pins the one literal in it.
gv_file="$REPO_ROOT/core/skills/ai-dlc/steps/gate-validation.md"
if [ -z "$em_marker" ]; then
  err "I35 cannot read EXEMPT_MARKER out of validate-enforcement-map.sh. The check binding H1's stated exemption marker to I20's just went vacuous — it must locate the marker or fail loudly, never pass by finding nothing."
elif [ ! -f "$gv_file" ]; then
  err "I35 cannot find gate-validation.md at $gv_file. A scan over nothing reads exactly like agreement."
elif ! grep -qF -- "$em_marker" "$gv_file"; then
  err "I35: H1 in gate-validation.md does not quote I20's exemption marker '$em_marker'. H1 is read by an LLM at every gate and tells it which declaration makes a driverless fixture legitimate; if that string does not match the one I20 enforces, H1 sends the reader looking for text no README carries and FAILs compliant fixtures. Quote the marker verbatim in H1's fixture criterion, or change both together."
fi

# --- I52: the drivability exemption marker is ONE string, and the second reader
#          of it runs on every consumer over a tree containing CORE's fixtures ---
# I35 binds H1's quoted marker to I20's because a diverged marker sends an LLM looking
# for text no README carries. I52 binds the SHIPPED validator's copy for a harder
# reason: `validate-fixture-drivability.sh` is installed and wired into the consumer's
# pre-push, and it judges `tests/fixtures/` — which is where install.sh puts CORE's
# fixtures. Two of those (check-h1-recursion, check-manifest-bypass) are legitimately
# driverless and pass only by carrying this marker in their READMEs. If the two strings
# diverge, every consumer's next push FAILS on core files they did not write, cannot
# fix, and did not change. Same blast radius as I48's region slug, same remedy: derive
# the marker from one home and compare, never restate it in prose.
#
# The guards are separate on purpose. An unreadable marker on either side must ERROR,
# not skip: a comparison of two empty strings succeeds, and this join's whole value is
# that it cannot pass by finding nothing.
fd_script="$REPO_ROOT/core/scripts/validate-fixture-drivability.sh"
if [ ! -f "$fd_script" ]; then
  err "I52 cannot find validate-fixture-drivability.sh at $fd_script. The shipped reader of I20's exemption marker is gone or renamed, so the binding that keeps core's own driverless fixtures passing on every consumer's push is now vacuous. Restore the path, or retire I52 in the same change."
else
  fd_marker="$(sed -n "s/^EXEMPT_MARKER='\(.*\)'$/\1/p" "$fd_script" | head -1)"
  if [ -z "$em_marker" ]; then
    err "I52 cannot read EXEMPT_MARKER out of validate-enforcement-map.sh (I20's home). It must locate the marker or fail loudly, never pass by comparing two empty strings."
  elif [ -z "$fd_marker" ]; then
    err "I52 cannot read EXEMPT_MARKER out of validate-fixture-drivability.sh. It must locate the marker or fail loudly, never pass by comparing two empty strings."
  elif [ "$em_marker" != "$fd_marker" ]; then
    err "I52: the drivability exemption marker differs between I20 ('$em_marker') and the shipped validate-fixture-drivability.sh ('$fd_marker'). That script runs in every consumer's pre-push over tests/fixtures/, where install.sh puts core's own fixtures; core ships two that are driverless and legitimate, and they pass ONLY by carrying I20's marker. A diverged marker fails every consumer's next push on core files they did not write. Change both together."
  fi
fi

# --- I34: ONE rule grammar. The SAME split as I15, in the RULE namespace. -----
# `validate-layer-entries.sh` (W4) REPORTS an extension rule number colliding with core's;
# `relabel-extension-checks.sh` FIXES it by writing the `[ext:<id>]` label. Two programs,
# one grammar. If the reporter's is wider, it names a collision the fixer cannot rewrite and
# the operator is handed a remedy that does not run — which is how the CHECK label went
# unadopted for three releases and is exactly the failure I15 was added for.
#
# Separate from I15 on purpose. ANCHOR_RE matches `### 24.` and terminates on `[.—]`; a rule
# heading is `### Rule 29 -- Steering budget` and has no terminator, so ANCHOR_RE matches
# 0 of core's 30 rules. Folding the word `Rule` into ANCHOR_RE would merge `Rule 29` and
# check `29` into one id and start joining two unrelated catalogs by integer.
rg_lint="$(sed -n 's/^RULE_RE=//p' "$REPO_ROOT/core/scripts/validate-layer-entries.sh" | head -1)"
rg_relabel="$(sed -n 's/^RULE_RE=//p' "$REPO_ROOT/core/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh" | head -1)"
if [ -z "$rg_lint" ] || [ -z "$rg_relabel" ]; then
  err "I34 cannot find a RULE_RE definition in validate-layer-entries.sh and/or relabel-extension-checks.sh. The check that binds the two rule grammars just went vacuous — it must locate both or fail loudly, never pass by finding nothing."
elif [ "$rg_lint" != "$rg_relabel" ]; then
  err "the rule grammar has forked: validate-layer-entries.sh defines RULE_RE=$rg_lint but relabel-extension-checks.sh defines RULE_RE=$rg_relabel. The linter REPORTS rule-number collisions and relabel FIXES them; a narrower grammar in either means a reported collision no tool can resolve. Make them byte-identical."
fi

# --- I25: the core-path derivation is ONE rule, in two places, byte-identical --
# `hooks/ai-dlc-core-guard.sh` decides at EDIT time whether a path is core (and
# denies the write). `scripts/core-paths.sh` answers the same question for callers
# that are not a hook -- Check 16's stub audit asks it whether a marker sits in an
# upstream-owned file, because a core file can satisfy none of the four elements
# (no consumer backlog item can be added to a file the guard forbids editing).
#
# Same shape as I18, and the same reason it is a COPY rather than a source: the
# guard must stay self-contained. A guard that sources a helper stops denying core
# writes entirely when that helper is missing from a partial install -- it fails
# open, silently, and a disabled write guard is far worse than a duplicated
# 25-line parser. The duplication is only safe because this assertion exists: two
# copies bound byte-for-byte cannot drift, one copy with a fragile load path can
# vanish. If these two ever disagree, the edit-time guard and the gate-time check
# classify the same file differently -- the gate exempts what the guard protects,
# or the guard denies what the gate audits.
cp_fn() { awk "/^$2\(\) \{/,/^\}/" "$1" 2>/dev/null; }
CP_GUARD="$REPO_ROOT/core/hooks/ai-dlc-core-guard.sh"
CP_LIB="$REPO_ROOT/core/scripts/core-paths.sh"
for cp_f in parse_manifest to_consumer_glob; do
  cp_a="$(cp_fn "$CP_GUARD" "$cp_f")"
  cp_b="$(cp_fn "$CP_LIB" "$cp_f")"
  if [ -z "$cp_a" ] || [ -z "$cp_b" ]; then
    err "I25 cannot find a ${cp_f}() definition in ai-dlc-core-guard.sh and/or core-paths.sh. The check binding the edit-time and gate-time core-path rules just went vacuous — it must locate both or fail loudly, never pass by finding nothing."
  elif [ "$cp_a" != "$cp_b" ]; then
    err "the core-path derivation has forked between ai-dlc-core-guard.sh and core-paths.sh at ${cp_f}(). One denies edits to core, the other tells Check 16 which files are core; a rule that differs between them means a file the guard protects can be audited as consumer-authored, or a file the gate exempts can still be edited. Make ${cp_f}() byte-identical."
  fi
done

# --- I40: ONE reading of an anchor, across the linter and the pull classifier ---
# `core/scripts/validate-layer-entries.sh` ERRORs at authoring time on an anchor that resolves
# only by the reverse containment arm; `reconcile/layer-drift.sh` reports the same shape at pull
# time. They must agree about three things, and each disagreement has already shipped:
#
#   nrm_awk        is this the SAME heading? Three spellings existed — two awk copies in the
#                  linter and one inline in lib.sh's span_of — of the normalizer that every
#                  anchor join in the repo rests on.
#   shadow_parts   WHAT does this entry shadow? The linter read only the first comma-part
#                  (nineteen anchor instances unvalidated), then read every part but computed
#                  the file per part (the file-inheriting spelling skipped entirely, 1 of 4
#                  anchors checked); the classifier read ONE file for the whole entry and
#                  checked every anchor against it.
#   anchor_arm     WHICH DIRECTION resolved it? A narrower copy in either tool reports a loose
#                  anchor the other calls fine, and the operator believes whichever they ran.
#   unquote        is `'#X'` the anchor `#X` or the anchor `X'`? `extends:` must be quoted to be
#                  valid YAML (a bare `#` opens a comment), so every reader of it strips quotes
#                  or resolves against a span that does not exist.
#
# COPIES rather than a source, for I25's reason and I29's: core/scripts must not depend on the
# update skill, and I29 confines ai-dlc-update to reconcile/, so neither may source the other's
# file. The duplication is only safe because this assertion exists.
la_fn() { awk "/^$2\(\) \{/,/^\}/" "$1" 2>/dev/null; }
LA_LINT="$REPO_ROOT/core/scripts/validate-layer-entries.sh"
LA_LIB="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"
for la_f in nrm_awk anchor_arm shadow_parts unquote; do
  la_a="$(la_fn "$LA_LINT" "$la_f")"
  la_b="$(la_fn "$LA_LIB" "$la_f")"
  if [ -z "$la_a" ] || [ -z "$la_b" ]; then
    err "I40 cannot find a ${la_f}() definition in validate-layer-entries.sh and/or reconcile/lib.sh. The check binding the authoring linter's anchor reading to the pull classifier's just went vacuous — it must locate both or fail loudly, never pass by finding nothing."
  elif [ "$la_a" != "$la_b" ]; then
    err "the anchor reading has forked between validate-layer-entries.sh and reconcile/lib.sh at ${la_f}(). The linter ERRORs at authoring time and the classifier reports at pull time; a copy that differs means the two disagree about what an entry shadows or about which heading an anchor names, and the operator believes whichever they happened to run. Make ${la_f}() byte-identical."
  fi
done

# --- I29: ai-dlc-update names no helper that is not in reconcile/ ---------------
# The skill's HARD CONSTRAINT is that it reads only its own reconcile/ files, which is why
# setup-sites.md carries a duplicate manifest at all. A step that tells the reader to use a
# helper living outside reconcile/ is not a wrong path -- it is an instruction to violate the
# constraint, and the reader's fallback is to hand-write what the helper would have done.
# Shipped once: step 2 said "Both helpers are in reconcile/" of map_consumer() (true) and
# to_consumer_glob() (in core/scripts/core-paths.sh and core/hooks/ai-dlc-core-guard.sh).
# Bind the claim to the directory rather than trusting prose.
UPD_SKILL="$REPO_ROOT/core/skills/ai-dlc-update/SKILL.md"
UPD_RECON="$REPO_ROOT/core/skills/ai-dlc-update/reconcile"
if [ ! -r "$UPD_SKILL" ] || [ ! -d "$UPD_RECON" ]; then
  err "I29 cannot read core/skills/ai-dlc-update/SKILL.md and/or its reconcile/ dir. A check that cannot locate either side scans nothing and reports clean."
else
  # Every `name()` the skill cites in backticks, that reconcile/ does not define.
  #
  # CARVE-OUT, deliberately narrow: a paragraph opening `Do NOT reach for` is a PROHIBITION,
  # not a citation -- it exists to stop the next author re-adding the bad instruction, and
  # naming the helper is the whole point of it. Citations there are skipped, and only there:
  # the exemption is one opening phrase and ends at the next blank line, so it cannot be
  # stretched to excuse a real citation.
  upd_missing=""
  while IFS= read -r fn; do
    [ -n "$fn" ] || continue
    grep -rqE "^[[:space:]]*(function[[:space:]]+)?${fn}\(\)" "$UPD_RECON" 2>/dev/null || upd_missing="$upd_missing $fn"
  done <<EOF
$(awk '/Do NOT reach for/{skip=1} skip&&/^[[:space:]]*$/{skip=0} !skip' "$UPD_SKILL" \
   | grep -oE '`[a-z_][a-z0-9_]*\(\)`' | tr -d '`()' | sort -u)
EOF
  if [ -n "$upd_missing" ]; then
    err "I29 ai-dlc-update/SKILL.md cites helper(s) that reconcile/ does not define:${upd_missing}. This skill's HARD CONSTRAINT is that it reads only its own reconcile/ files, so naming a helper from elsewhere instructs the reader to violate it — and the fallback is hand-writing the mapping the helper existed to make derivable. Either move the logic into reconcile/, or state the rule inline and say explicitly that the outside helper must NOT be read."
  fi
fi

# --- I28: layer grain is DECLARED and PARTITIONS the manifest -------------------
# `machinery` (no overrides/ or extensions/ grain) vs `rulebook` (consumer-layerable prose)
# decided three things and was written down in none of them: the core-guard's routing advice,
# and -- the one that bit -- which paths ai-dlc-update's self-update cycle may pull
# autonomously. That cycle pulled `skills/ai-dlc-update/**` plus the fixtures covering it,
# and those fixtures depend on machinery OUTSIDE that slice (core-paths.sh, core-manifest.md),
# so a red derived fixture HARD-STOPPED the self-update on a pull that broke nothing. The
# slice is now the machinery set, which needs the set to exist as data.
#
# PARTITION, not two lists that happen to agree: every non-fixtures/ entry must be in exactly
# one. In neither means a new entry is silently treated as rulebook and never reaches the
# self-update slice -- the same wedge again, one release later. In both means the two readers
# can disagree about the same path. fixtures/ is excluded: test data has no layer grain and
# its enumeration is already derived from core/fixtures/ minus .dist-only (I8).
norm_key() { # <file> <key> -> entries under that key, prefix-normalized like I5
  awk -v k="$2" '
    $0 == k ":" {f=1; next}
    f && /^  - / {v=$0; sub(/^  - /,"",v); print v; next}
    f && /^[^ \t]/ {f=0}
  ' "$1" | sed -E 's#^core/skills/ai-dlc/##; s#^core/##' | sort -u
}
cm_all="$(norm_core_manifest "$CORE_MANIFEST" | grep -v '^fixtures/' | sort -u)"
for lg_k in machinery rulebook; do
  a="$(norm_key "$CORE_MANIFEST" "$lg_k")"
  b="$(norm_key "$SETUP_SITES" "$lg_k")"
  if [ -z "$a" ] || [ -z "$b" ]; then
    err "I28 the '${lg_k}:' list is missing or unparseable in core-manifest.md and/or reconcile/setup-sites.md (found $(printf '%s' "$a" | grep -c . ) and $(printf '%s' "$b" | grep -c . ) entries). Layer grain decides the core-guard's routing and which paths the self-update may pull autonomously; an absent list makes both fall back to a default silently."
  elif [ "$a" != "$b" ]; then
    err "I28 the '${lg_k}:' lists diverge between core-manifest.md and reconcile/setup-sites.md:"
    diff <(printf '%s\n' "$a") <(printf '%s\n' "$b") >&2 || true
  fi
done
mach="$(norm_key "$CORE_MANIFEST" machinery)"
rule="$(norm_key "$CORE_MANIFEST" rulebook)"
lg_both="$(comm -12 <(printf '%s\n' "$mach") <(printf '%s\n' "$rule"))"
[ -n "$lg_both" ] && err "I28 entr(y/ies) declared BOTH machinery and rulebook: $(echo $lg_both). Layer grain is one answer per path; two readers would route the same file differently."
lg_neither="$(comm -23 <(printf '%s\n' "$cm_all") <(printf '%s\n' "$mach" "$rule" | sort -u))"
[ -n "$lg_neither" ] && err "I28 core_manifest entr(y/ies) with NO layer grain declared: $(echo $lg_neither). Add each to machinery: (no overrides/extensions grain — hooks, validators, schemas, templates, the setup/update engines) or rulebook: (consumer-layerable prose). Unclassified defaults to rulebook at every reader, which is how a machinery path silently stops reaching ai-dlc-update's self-update slice."
lg_ghost="$(comm -13 <(printf '%s\n' "$cm_all") <(printf '%s\n' "$mach" "$rule" | sort -u))"
[ -n "$lg_ghost" ] && err "I28 layer grain declared for path(s) that are not core_manifest entries: $(echo $lg_ghost). A grain for a path the manifest does not claim protects nothing and reads as coverage."

# --- I27: the in-flight marker is ONE path, written by apply.sh and read by pre-push --
# A pull writes core one file at a time, so mid-apply the tree is a mixture of two releases
# and its own fixture suite fails in BOTH directions -- a fixture newer than its subject
# asserts behaviour that is not installed, an older one breaks against a newer subject.
# apply.sh marks that state and pre-push refuses the suite while the mark is there.
#
# TWO FILES, ONE STRING. If they name different paths the marker is written and nothing
# reads it: the guard is silently absent and looks exactly like a guard that passed. That
# is the shape v0.55.2's map_consumer() and v0.63.0's drift-scan list both failed in, so
# bind the two ends rather than trusting them to agree.
MK_APPLY="$(sed -nE 's@^APPLYING="\$CONSUMER/(.+)"$@\1@p' \
  "$REPO_ROOT/core/skills/ai-dlc-update/reconcile/apply.sh" | head -1)"
MK_PP="$(sed -nE 's@^if \[ -f (\.[^ ]+) \]; then$@\1@p' \
  "$REPO_ROOT/core/git-hooks/pre-push" | grep 'applying' | head -1)"
if [ -z "$MK_APPLY" ] || [ -z "$MK_PP" ]; then
  err "I27 could not locate the in-flight marker path in apply.sh (\`APPLYING=\`) and/or core/git-hooks/pre-push (\`if [ -f ... ]\`). One end missing means the marker is written with nothing refusing on it, or refused on with nothing writing it — and either way this check just went vacuous. Found apply='${MK_APPLY:-<none>}' pre-push='${MK_PP:-<none>}'."
elif [ "$MK_APPLY" != "$MK_PP" ]; then
  err "I27 the in-flight marker path has forked: apply.sh writes '\$CONSUMER/${MK_APPLY}' but core/git-hooks/pre-push refuses on '${MK_PP}'. The writer and the reader must name the SAME path, or a mid-pull tree runs its own fixture suite and reports failures that are neither a regression nor the consumer's fault."
fi

# --- I26: core-layer-immutability keeps the core set DERIVED, never restated ---
# The check body used to tell the adjudicator to read core-manifest.md "for the
# authoritative path list" and then spell that list out inline. It named 6 of the
# manifest's 12 non-fixture entries, omitting templates/, session-driver/, schemas/,
# both ai-dlc-setup/ and ai-dlc-update/ subtrees, and scripts/ai-dlc/ -- so the retro
# backstop stopped firing on six core subtrees, and the omission read exactly like a
# clean pass. Same failure I24 records for H1's fixture set, in the one check whose
# entire job is a core-manifest intersection.
#
# A COUNT of manifest entries in the span is the wrong detector: the body legitimately
# cites rule-authoring.md for guidance and names hooks/ai-dlc-*.sh for a real
# behavioural carve-out (a changed core hook can have no overrides/ shadow, so it always
# FAILs). What distinguishes a restated LIST is punctuation adjacency -- a list puts the
# entries on one line, a reference stands alone. Measured against the pre-fix text: two
# lines carried three entries each; the fixed text carries at most one per line.
CLI_SPAN="$(awk '/<!-- CHECK_LOADED: core-layer-immutability -->/{on=1} on{print} on && /^### /&&!/core-layer-immutability/{exit}' \
  "$REPO_ROOT/core/skills/ai-dlc/steps/gate-validation.md" 2>/dev/null)"
if [ -z "$CLI_SPAN" ]; then
  err "I26 could not isolate the core-layer-immutability span in gate-validation.md. A span that does not resolve scans nothing and reports clean."
elif ! grep -q 'core-paths.sh --is-core' <<<"$CLI_SPAN"; then
  err "I26 the core-layer-immutability check body does not invoke \`core-paths.sh --is-core\`. It must DERIVE the core set from the same resolver the edit-time guard reads, not decide for itself which paths are core — a body that answers that question on its own is the restated list this invariant exists to prevent."
else
  # Entries derived from the manifest, never hand-listed here. Fixtures are excluded:
  # 66 of them would swamp the per-line test and none is a plausible restatement.
  cli_entries="$(norm_core_manifest "$CORE_MANIFEST" | grep -v '^fixtures/')"
  cli_bad=""
  while IFS= read -r cli_line; do
    cli_n=0
    while IFS= read -r cli_e; do
      [ -n "$cli_e" ] || continue
      # A LITERAL SUBSTRING TEST, NOT A FORK. `grep -qF` is the same predicate as a case glob on a
      # quoted variable, and this loop runs (span lines x manifest entries) -- about 2,300 greps per
      # validator run, and this validator runs 20 times inside core/fixtures/enforcement-map-sites/.
      # Measured: 7.18s -> 4.11s per run, output byte-identical, on the largest fixture in the suite.
      case "$cli_line" in *"$cli_e"*) cli_n=$((cli_n+1)) ;; esac
    done <<EOF
$cli_entries
EOF
    [ "$cli_n" -ge 2 ] && cli_bad="${cli_bad}
      ${cli_n} entries on: $(printf '%s' "$cli_line" | cut -c1-80)"
  done <<EOF
$(printf '%s\n' "$CLI_SPAN")
EOF
  if [ -n "$cli_bad" ]; then
    err "I26 the core-layer-immutability check body restates the core path set:${cli_bad}
      A line naming two or more manifest entries is a list, not a cross-reference. The set is DERIVED from core-paths.sh --is-core; a list here rots against the manifest in the one direction that matters, because every entry it omits is a core subtree this check silently stops firing on. It had already omitted six."
  fi
fi

# --- I19: SKILL.md Rule 8's intensity table is the ONLY place the validation-cycle
# minimums are enumerated. Check 20 kept its own copy of them and the copy dropped a row:
# Rule 8 defines four intensities, Check 20 listed three, and `carry-over-single` appeared
# ZERO times in gate-validation.md. A gate declaring it reached the one check that enforces
# intensity and found no minimum to test against — indistinguishable from a gate that met it.
#
# Third instance in two releases of one class: a set declared twice, one copy drifts (the
# universal core across three sources; check-manifest-bypass's fourth copy of it; now this).
# Where the duplicate MUST exist the copies are bound (I15, I18). Here it must not exist at
# all, so assert it does not come back rather than binding a copy into permanence.
#
# The signal is an intensity name and an evaluation name on one line — how a minimum is
# written. Naming an intensity is fine and common (route.md declares one, discovery.md
# branches on one); RESTATING what it requires is the defect.
r8_dupes="$(grep -rnE '`(full|standard|lightweight|carry-over-single)`[^|]*(Party Mode|Advanced Elicitation|Adversarial Review)' \
             "$REPO_ROOT/core/skills/ai-dlc/steps/" 2>/dev/null | grep -v '^[^:]*:[0-9]*:.*Rule 8' || true)"
if [ -n "$r8_dupes" ]; then
  err "the validation-intensity minimums are enumerated outside SKILL.md Rule 8's table — that table is the single source and a second copy is what dropped carry-over-single from Check 20. Cite the table's 'Minimum cycle per planning artifact' column instead of restating it:
$r8_dupes"
fi

# --- I96: the adversarial cycle's stopping rule is a VERDICT, never a pass count -----
# Rule 8's intensity table names EVALUATIONS. The cycle ends when a pass stamps
# EXIT_CONDITION_MET and at no other moment, so a minimum, maximum or expected number of
# adversarial passes stated anywhere in shipped prose is a SECOND stopping rule that can
# only disagree with the first.
#
# WHY I19 CANNOT COVER THIS. I19 keys on a backticked intensity name AND an evaluation
# name on one line, which is how a table ROW is written. The count drifted three times
# into prose that names no intensity -- `_gate-procedures.md` ("2+ passes (a floor, not a
# target)"), `gate-validation.md` Check 1 ("completed (2+ passes, only nitpicks remain)?")
# and two copies in `templates/QUICKSTART.md.template`, which no invariant reached at all.
# All three sat under I19 for their whole lifetime and it never saw one of them.
#
# THE GRAMMAR IS TWO TOKENS ON ONE LINE, and it is two rather than one because measurement
# said so. A pass COUNT alone flags five lines that use the word in its other sense --
# `artifact-consolidation.md` "Only Steps 3-4 pass:", `_gate-procedures.md` "preconditions
# 3-7 pass, fire", `gate-validation.md` "seed H1 passes means", `remediator.md` "Measured:
# 13 passes, ~12 hours", and SKILL.md's STALL sentence "a nonzero MAJOR held at zero
# CRITICAL across 2+ passes", whose 2 is arm E's STALL_THRESHOLD and a different number
# entirely. Requiring the line to ALSO name the adversarial cycle drops all five.
#
# FALSE-POSITIVE SET: measured at 10 hits before the count was retired, every one of them
# a site that had to change; 0 after. The near-miss control is SKILL.md's STALL sentence,
# which must stay silent -- if it ever fires, the grammar has been widened to a single
# token and arm E's threshold is being read as a floor.
#
# WHAT IT DOES NOT CATCH, stated because an unstated limit is read as coverage: a bare
# count in running prose that names no adversarial token on its own line. Widening to one
# token buys that case and the five false positives above with it, so the narrow form
# ships. This arm catches the RESTATEMENT shape, which is the one that actually drifted.
i96_cnt='[0-9]+\+?[[:space:]]+pass(es)?([^a-zA-Z]|$)'
i96_adv='Adversarial Review|adversarial convergence|convergence cycle|Rule 8|adversarial pass'
i96_hits="$(grep -rniE "$i96_cnt" \
             "$REPO_ROOT/core/skills/" "$REPO_ROOT/core/team-roles/" "$REPO_ROOT/templates/" \
             2>/dev/null | grep -iE "$i96_adv" || true)"
if [ -n "$i96_hits" ]; then
  err "a pass COUNT is stated beside the adversarial cycle. Rule 8's intensity table names evaluations, and the cycle ends when a pass stamps EXIT_CONDITION_MET -- a count is a second stopping rule that can only disagree with the first. Cite the verdict, not a number:
$i96_hits"
fi

# --- I97: only validate-locked-anchor.sh may MATCH a LOCKED_REQUIREMENTS marker ---------
# The block sentinel has SIX measured spellings across opener and closer -- the census is in
# validate-locked-anchor.sh's own header -- an unrecognised closer extracts as NOTHING, and a
# non-greedy span lets one block SWALLOW dozens of real ones. That grammar cost a release to
# get right, which is why `--emit-blocks` exists there and why every other reader calls it.
#
# THIS ARM EXISTS BECAUSE THE VIOLATION SHIPPED INTO A WORKING TREE. Adding the declared LR
# population to validate-spec-join.sh, a hand-rolled opener/closer pair went in and read 2 of
# the 6 spellings; on the reference consumer it left s299 unterminated, whose closer is
# `<!-- END S299 LOCKED_REQUIREMENTS -->`. Nothing caught it. Three readers now exist
# (validate-request-coverage.sh, validate-spec-join.sh, and the owner) and a fourth will be
# written the same way unless the affordance is removed rather than the violation policed.
#
# THE GRAMMAR IS TWO TOKENS ON ONE NON-COMMENT LINE: the HTML comment opener and the
# sentinel word. One token alone is useless -- the sentinel appears in DISARM message strings
# in validate-spec-join.sh and in three hooks' prose, five files in all, none of them matching
# anything. Requiring `<!--` on the same line drops every one of them.
#
# FALSE-POSITIVE SET: measured over core/scripts/*.sh, scripts/*.sh, core/hooks/*.sh,
# core/git-hooks/* and .githooks/* -- FOUR hits, all four inside the owner, ZERO elsewhere.
# Two of the owner's four are its real regexes and two are the remediation sentence it prints;
# both stay, because the owner is the file allowed to carry them. The positive control is that
# the owner MUST be in the set: an arm that finds the owner clean is scanning nothing.
# THE OPENER LITERAL IS ASSEMBLED, NOT WRITTEN. Spelled out, this arm's own grep line
# carries both tokens and the arm convicts itself -- measured, it did. Building the literal
# from two halves keeps the source line below the arm's own grammar without weakening it.
i97_open="$(printf '<!%s' '--')"
i97_owner="core/scripts/validate-locked-anchor.sh"
i97_files=""
for _d in "$REPO_ROOT"/core/scripts/*.sh "$REPO_ROOT"/scripts/*.sh "$REPO_ROOT"/core/hooks/*.sh \
          "$REPO_ROOT"/core/git-hooks/* "$REPO_ROOT"/.githooks/*; do
  [ -f "$_d" ] || continue
  i97_files="$i97_files $_d"
done
if [ -z "$i97_files" ]; then
  err "I97 found no shipped scripts to scan. A scan over nothing reports clean, which is the shape this check exists to end."
else
  # ONE FORK FOR THE WHOLE SCAN. This validator's fork count IS the suite's wall clock --
  # `validator-fork-budget` is a fixture, not a guideline -- and this arm was measured three
  # ways before it landed: a per-file loop of four commands over ~60 files cost 240 forks and
  # put the budget 344 OVER; one grep pass plus two filters and a sed cost 4 and left it 1
  # over; this awk costs 1. EVERY hit line carries its own path, because grep -n emits one
  # line per hit and labelling the BLOCK rather than the line is how the owner's own four
  # lines first read as four violations. Path stripping is index/substr rather than a
  # dynamic regex, so a root containing a regex metacharacter cannot silently mis-strip.
  i97_all="$(awk -v root="$REPO_ROOT/" -v open="$i97_open" '
    index($0, "LOCKED_REQUIREMENTS") == 0 { next }
    index($0, open) == 0 { next }
    { s = $0; sub(/^[ \t]+/, "", s); if (substr(s, 1, 1) == "#") next
      p = FILENAME; if (index(p, root) == 1) p = substr(p, length(root) + 1)
      print p ":" FNR ":" $0 }
  ' $i97_files 2>/dev/null || true)"
  # POSITIVE CONTROL, in the same pass: the owner carries the grammar, so it must appear.
  # Without this the arm reads identically whether it scanned the corpus or missed it.
  if ! grep -qF "$i97_owner" <<<"$i97_all"; then
    err "I97's positive control failed: $i97_owner carries the LOCKED_REQUIREMENTS marker grammar and did not appear in this arm's own scan. The arm is reading the wrong corpus or the wrong grammar, and its silence about every OTHER file means nothing."
  fi
  i97_hits="$(printf '%s\n' "$i97_all" | grep -v "^$i97_owner:" | grep -v '^$' || true)"
  if [ -n "$i97_hits" ]; then
    err "these shipped scripts MATCH a LOCKED_REQUIREMENTS marker themselves instead of asking the tool that owns it. The sentinel has six measured spellings and a partial matcher reads an unrecognised closer as NO BLOCK, which is indistinguishable from a sprint that locked nothing. Call \`bash validate-locked-anchor.sh <file> --emit-blocks\` and read its output, as validate-request-coverage.sh and validate-spec-join.sh do:
$i97_hits"
  fi
fi

# --- I16: runtime-pipeline prose must cite CONSUMER paths, never `core/`-prefixed ones.
# install.sh maps core/<x> -> .claude/<x>, but that governs where files LAND, not path
# references in the prose INSIDE them. So installed core kept citing the distribution's own
# layout, which resolves nowhere at any consumer: Check 19 sent the reviewer to
# `core/team-roles/code-reviewer.md` for the Self-Discrimination Map, a dead path.
#
# Not cosmetic. That one unsubstituted ref is the only legitimate reason a consumer's Check-19
# extension forked from core at all — it localized the path, and in forking silently dropped
# core's ~28-line core-path wiring-citation clause. One dead link cost a live gate rule.
#
# DERIVE the directory list from core/*/ on disk. The hand-listed five-directory set this bug
# was first reported with already omitted four live subtrees (schemas, fixtures, ci-templates,
# git-hooks) — the same rot I8 exists to catch.
#
# Scope is the RUNTIME pipeline only. `core/skills/ai-dlc-update/**` reasons about the
# distribution layout by design (comparing core/ to .claude/), fixtures build real core/ trees
# on disk, and enforcement-map.yaml's `core/scripts/...` values are DATA this very script greps
# in that exact shape at I9. Markdown-only + the core-manifest exclusion keeps all of them out.
core_dirs="$( { for _d in "$REPO_ROOT"/core/*/; do _d="${_d%/}"; [ -d "$_d" ] || continue; printf '%s\n' "${_d##*/}"; done; } | sort | paste -sd'|' -)"
if [ -z "$core_dirs" ]; then
  err "I16 derived an EMPTY core/ directory list — the prose-path check just went vacuous and would pass over any dead citation. Expected core/*/ subtrees to exist."
else
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    err "runtime-pipeline prose cites a distribution path that does not exist at any consumer: ${hit}. install.sh maps core/<x> -> .claude/<x>, so an installed file citing 'core/...' is a dead link for every reader. Cite the consumer path (e.g. '.claude/team-roles/qa.md' — core's own convention, ~29 uses) or a bare filename."
  done < <(find "$REPO_ROOT/core/skills/ai-dlc" "$REPO_ROOT/core/team-roles" -name '*.md' -type f \
             ! -name 'core-manifest.md' 2>/dev/null \
           | sort \
           | xargs grep -InE "core/(${core_dirs})/" 2>/dev/null \
           | sed "s|^$REPO_ROOT/||" | cut -c1-160)
fi

# --- Fixture root-resolution depth: a seed that hand-resolves the repo root must use the
# SAME `$HERE/../../..` depth for BOTH layouts. A fixture lives at `core/fixtures/<name>/`
# upstream and `tests/fixtures/<name>/` in a consumer (install.sh's map) — BOTH exactly three
# dirs below root. A seed that resolves its consumer branch with `$HERE/../..` (two dirs) lands
# at `tests/` in a consumer, never finds its script/schema, and every seed dies with "not found
# in either layout" → the consumer's pre-push fixture suite FAILS against tooling that is
# correct in the distribution. This bit eight fixtures at once (the distribution takes the
# other branch, so it never exercised the buggy one — the distribution is not a consumer).
# Assert both cd-depths are three, so the next copy-paste cannot re-introduce it.
# ONE grep over every seed, not a grep+sed pair per fixture. `-H` keeps the filename so the
# error can still name its fixture, and grep walks its arguments in glob order and each file
# in line order -- the same traversal the per-file loop made, so the findings and their order
# are unchanged.
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  s="${hit%%:*}"; depth="${hit#*\$HERE/}"
  [ "$depth" = "../../.." ] || { d="${s%/seed.sh}"; err "fixture '${d##*/}' seed resolves a repo-root var with depth '\$HERE/$depth' — must be '\$HERE/../../..' (three dirs below root, matching BOTH core/fixtures/<name>/ and tests/fixtures/<name>/). A shallower depth passes in the distribution and fails in every consumer's pre-push."; }
done < <(grep -oHE '[DC]_ROOT="\$\(cd "\$HERE/(\.\./)*\.\.' "$REPO_ROOT"/core/fixtures/*/seed.sh 2>/dev/null)

# --- Audit-anchors template is BOUND to its canonical schema. The housekeeping schema used to
# live in two places (this template + each project's live header) with nothing comparing them;
# they drifted (the template went stale, missing `audit_window`). Now the schema is canonical in
# core/schemas/audit-anchors.json, the template's header is RENDERED from it, and the entry
# validator loads it. Assert the shipped template still passes its own validator, so the template
# cannot silently re-stale from the schema.
AA_VALIDATOR="$REPO_ROOT/core/scripts/validate-audit-anchors.sh"
AA_TEMPLATE="$REPO_ROOT/templates/audit-anchors.md.template"
if [ -f "$AA_VALIDATOR" ] && [ -f "$AA_TEMPLATE" ]; then
  bash "$AA_VALIDATOR" "$AA_TEMPLATE" >/dev/null 2>&1 \
    || err "templates/audit-anchors.md.template no longer matches core/schemas/audit-anchors.json (header drift or a malformed bootstrap entry). Re-render its header with 'core/scripts/validate-audit-anchors.sh --render' and fix the entry — the template must never drift from the canonical schema again."
fi

# --- I11: the convergence-cycle scope list is DERIVED, not remembered ---------
# THREE SETS MUST BE ONE SET:
#   (a) steps whose file dispatches an adversarial REVIEW  (they run a convergence cycle)
#   (b) steps whose file references the adversarial REPAIR dispatch (a remediator repairs;
#       the LEAD must not — it is the most context-saturated agent in the pipeline, which is
#       the whole reason the remediator role exists)
#   (c) steps named in Check 24's Scope sentence            (a gate reads the verdict)
#
# A step in (a) but not (c) runs an unbounded convergence loop that NO GATE ADJUDICATES —
# and a loop nobody adjudicates reads exactly like a loop that converged. A step in (a) but
# not (b) has its own author repairing its own artifact, which is the failure the remediator
# was created to end.
#
# This list was hand-maintained and it rotted TWICE. v0.58.0 caught doc-repair-backfill and
# sprint-review-next running unadjudicated cycles and added them to Check 24's scope. The
# same sweep walked straight past carry-over-evaluation, which was running one too — Rule 8
# binds it ("per planning artifact"), its step file never said so, and the reference consumer
# ran a 2-pass cycle there with the lead repairing and no gate reading the verdict. The sweep
# missed it for exactly the reason I8's site table missed core/git-hooks/: the list was
# hand-maintained, so the check had no row for it, and a check that cannot fire reads exactly
# like a check that passed. Derive the list. Never hand-maintain it.
STEPS_DIR="$REPO_ROOT/core/skills/ai-dlc/steps"
if [ -d "$STEPS_DIR" ]; then
  # The python goes to a temp FILE, not a heredoc inside $( ). On bash 3.2 (macOS, the
  # floor this repo targets) a heredoc nested in a command substitution has its body
  # scanned for shell quotes BEFORE the heredoc is processed -- so a lone apostrophe in a
  # python comment ("Check 24's scope") is read as an opening quote and the whole script
  # fails to parse. Top-level heredocs are fine; nested ones are not.
  I11_PY="$(mktemp)"
  cat > "$I11_PY" <<'I11EOF'
import os, re, sys
steps_dir, gv = sys.argv[1], sys.argv[2]

def collapse(p):
    # The procedure names WRAP across lines in the step files (Adversarial review /
    # dispatch). A line-oriented grep misses them, and a check that cannot see the thing
    # it checks reads exactly like a check that passed. Collapse whitespace first.
    return re.sub(r"\s+", " ", open(p, encoding="utf-8").read())

steps = {}
for fn in sorted(os.listdir(steps_dir)):
    if not fn.endswith(".md") or fn.startswith("_"):
        continue
    steps[fn[:-3]] = collapse(os.path.join(steps_dir, fn))

review = set(n for n, t in steps.items() if "Adversarial review dispatch" in t)
repair = set(n for n, t in steps.items() if "Adversarial repair dispatch" in t)

# Check 24 Scope sentence. Only names that are REAL step files count -- the sentence also
# backticks `lightweight`, which is an intensity, not a step.
gvt = open(gv, encoding="utf-8").read()
m = re.search(r"^### 24\.(.*?)^### ", gvt, re.S | re.M)
scope = set()
if m:
    sm = re.search(r"Those steps are:(.*?)\n\n", m.group(1), re.S)
    if sm:
        scope = set(t for t in re.findall(r"`([a-z-]+)`", sm.group(1)) if t in steps)

def emit(names, msg):
    if names:
        sys.stdout.write("ERR\t" + " ".join(sorted(names)) + "\t" + msg + "\n")

emit(review - scope,
     "step(s) run an adversarial convergence cycle but are ABSENT from Check 24 scope -- the loop is adjudicated by nobody, which reads exactly like a loop that converged")
emit(scope - review,
     "Check 24 scope names step(s) that dispatch no adversarial review -- a stale scope entry makes the check self-skip on a gate it claims to cover")
emit(review - repair,
     "step(s) dispatch an adversarial REVIEW but never reference the adversarial REPAIR dispatch -- the lead will repair its own artifact, which is the failure the remediator role exists to end")
I11EOF
  I11_OUT="$(python3 "$I11_PY" "$STEPS_DIR" "$GV")"
  rm -f "$I11_PY"
  while IFS="$(printf '\t')" read -r tag names msg; do
    [ "$tag" = "ERR" ] || continue
    err "$msg: $names"
  done <<EOF
$I11_OUT
EOF
fi

# --- I17: apply.sh's runtime composition writes where install.sh writes ---------
# The THIRD writer. install.sh is not the only thing that puts core/ files into a
# consumer — `reconcile/preclassify.sh`'s map_consumer() does too, on every pull, and
# the two must agree on the destination or the consumer gets two copies at two paths
# and the live one goes stale. They HAD diverged: map_consumer had no `core/fixtures/`
# case, so the `core/*` catch-all filed fixtures under `.claude/fixtures/` while
# install.sh writes `tests/fixtures/` — the only path gate-validation and H1 reference.
# Evaluate the real function rather than trusting a grep of it.
PRECLASS="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/preclassify.sh"
if [ -f "$PRECLASS" ]; then
  maps_to() { bash -c "CONS=/nonexistent; $(awk '/^map_consumer\(\) \{/,/^\}/' "$PRECLASS"); map_consumer '$1'" 2>/dev/null; }

  # I17's probe. Compose the two functions exactly as apply.sh does at runtime — map_consumer
  # from preclassify, consumer_path from apply — and evaluate the result. Composing rather
  # than grepping means this stays honest whether apply.sh delegates (as it must) or someone
  # reintroduces a private case list: either way we measure where a real path LANDS.
  APPLY_SH="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/apply.sh"
  APPLIES_TO_OK=""
  if [ -f "$APPLY_SH" ]; then
    applies_to() { bash -c "
      CONSUMER=/nonexistent-consumer
      $(awk '/^map_consumer\(\) \{/,/^\}/' "$PRECLASS")
      $(awk '/^consumer_path\(\) \{/,/^\}/' "$APPLY_SH")
      consumer_path '$1'" 2>/dev/null; }
    if [ -n "$(applies_to 'team-roles/PROBE')" ]; then
      APPLIES_TO_OK=yes
    else
      err "I17 could not evaluate apply.sh's consumer_path() — the check that binds the pull's WRITER to install.sh just went vacuous, and a vacuous check reads exactly like a passing one. Expected 'consumer_path() {' in $APPLY_SH and 'map_consumer() {' in $PRECLASS, each with its closing brace in column 0."
    fi
  fi
  # <core dir>|<the destination install.sh writes>. Every core/ subtree the installer
  # ALSO places must be listed, or the catch-all silently invents a second home for it.
  # Three entries here were live bugs: fixtures landed in .claude/fixtures/ (dead, while
  # H1 reads tests/fixtures/), ci-templates in .claude/ci-templates/ (dead, while
  # workflows run from .github/workflows/ — which is why a real consumer's CI gates sat
  # dormant and never once fired), and git-hooks in .claude/git-hooks/ (dead, while
  # install.sh writes .githooks/ — so v0.53.0's pre-push gate, the CI replacement, reached
  # the reference consumer at a path no runner, no git config, and no script reads).
  #
  # THE TABLE IS NOW BOUND AT BOTH ENDS, AND THAT IS THE POINT. Listing sites by hand is
  # what let git-hooks through: the check passed because the row was simply absent, and a
  # check that cannot fire reads exactly like a check that passed. So:
  #   (a) COMPLETENESS — every core/<dir>/ on disk must have a row here. A new subtree with
  #       no row is an ERROR, not a silent fall-through to the `core/*` catch-all.
  #   (b) AGREEMENT    — map_consumer() must send each subtree to its stated destination.
  #   (c) INSTALLER    — the stated destination must actually appear in install.sh, so a
  #       row cannot be satisfied by writing a destination the installer never uses.
  SITES_TABLE="$(cat <<'SITES'
ci-templates|.github/workflows
fixtures|tests/fixtures
git-hooks|.githooks
schemas|.claude/schemas
rules|.claude/rules
hooks|.claude/hooks
scripts|scripts/ai-dlc
session-driver|.claude/session-driver
skills|.claude/skills
team-roles|.claude/team-roles
SITES
)"
  # (a) Completeness: every core/<dir>/ on disk is accounted for.
  for d in "$REPO_ROOT"/core/*/; do
    [ -d "$d" ] || continue
    cdir="${d%/}"; cdir="${cdir##*/}"
    grep -q "^${cdir}|" <<<"$SITES_TABLE" || err "core/${cdir}/ has no destination row in I8's site table. map_consumer()'s \`core/*\` catch-all will file it under '.claude/${cdir}/' — add a row stating where install.sh actually writes it (or '.claude/${cdir}' if the catch-all is right). This is the check core/git-hooks/ slipped past by being absent."
  done
  # (b) Agreement + (c) installer binding.
  while IFS='|' read -r cdir dest; do
    [ -n "$cdir" ] || continue
    [ -d "$REPO_ROOT/core/$cdir" ] || continue
    got="$(maps_to "core/$cdir/PROBE")"
    [ "$got" = "$dest/PROBE" ] || err "the pull and the installer disagree on where core/$cdir/ goes: map_consumer() sends it to '$got', install.sh writes '$dest/'. The consumer gets two copies at two paths, and the one the pull keeps fresh is not the one anything reads."
    # Anchored at a path boundary, deliberately. A bare substring match is satisfied by
    # any destination that merely STARTS with this one (`.githooks-REMOVED` contains
    # `.githooks`), so the row would stay green against an installer that no longer
    # writes it — the check would be as hand-wavy as the list it replaced.
    dest_re="$(printf '%s' "$dest" | sed 's/[][\.^$*+?(){}|]/\\&/g')"
    grep -qE '\$PROJECT_ROOT/'"$dest_re"'([/"]|$)' "$REPO_ROOT/scripts/install.sh" || err "I8's site table says core/$cdir/ goes to '$dest/', but install.sh never writes \$PROJECT_ROOT/$dest. Either the row is wrong or the installer stopped shipping it."
    # (d) I17 — THE WRITER. map_consumer() only CLASSIFIES; on a pull, reconcile/apply.sh is
    # the thing that actually places files, and it was bound to nothing. It carried its own
    # hand-listed copy of this table and omitted core/session-driver/, core/ci-templates/ and
    # core/git-hooks/ — which therefore never applied, while the same run re-stamped
    # .ai-dlc-version anyway. A consumer's stamp claimed a version its tree did not have.
    # session-driver hid for releases because its only delta was ever a mode bit install.sh
    # had already set. Evaluate the real composed function; a grep would not have caught it.
    if [ -n "$APPLIES_TO_OK" ]; then
      got_a="$(applies_to "$cdir/PROBE")"
      [ "$got_a" = "/nonexistent-consumer/$dest/PROBE" ] || err "reconcile/apply.sh — the thing that WRITES on a pull — sends core/$cdir/ to '${got_a:-<nothing>}', but I8's table and install.sh say '$dest/'. A subtree apply.sh cannot place is silently skipped while the run still re-stamps, leaving a consumer whose .ai-dlc-version claims a version its tree lacks. apply.sh must derive every path from preclassify.sh's map_consumer(), never from a private table."
    fi
  done <<< "$SITES_TABLE"
fi

# --- I4: no dormant binding ---------------------------------------------------
# enforcer + ci_workflow file paths (distribution layout). Restricted to actual
# value lines (enforcer list items and ci_workflow: values) so prose/comment
# mentions of a path never register as a binding.
paths="$( {
  grep -oE '^      - core/(scripts|ci-templates)/[A-Za-z0-9._/-]+\.(sh|yml)' "$MAP" | sed -E 's/^      - //'
  grep -oE '^    ci_workflow: core/[A-Za-z0-9._/-]+\.yml' "$MAP" | sed -E 's/^    ci_workflow: //'
} | sort -u)"
for p in $paths; do
  [ -f "$REPO_ROOT/$p" ] || err "dormant binding: '$p' referenced in map but not on disk"
done
# fixtures: map uses consumer-runtime paths (tests/fixtures/<name>); upstream
# they live under core/fixtures/<name>. Resolve by basename.
fixtures="$(grep -oE 'tests/fixtures/[A-Za-z0-9._-]+' "$MAP" | sed -E 's#tests/fixtures/##' | sort -u)"
for d in $fixtures; do
  [ -d "$REPO_ROOT/core/fixtures/$d" ] || err "fixture '$d' named in map but missing under core/fixtures/"
done

# --- I9: every script enforcer declares WHERE it is invoked -------------------
# The map recorded `enforcer:` (WHO enforces a rule) on every entry and
# `call_sites:` (WHERE the enforcer is actually invoked) on ONE of them. So
# "Enforced by validate-X.sh" was a CLAIM, and nothing could tell a claim from a
# wiring. Measured on the reference consumer at v0.51.0:
#
#   validate-steering-budget.sh   11 real starvation violations, worst 10.0 min
#                                 -- invoked from NO gate. implementation.md:152
#                                 says "fails the gate on it"; that sentence was
#                                 false at every gate, in every phase.
#
# That is the mechanism behind three consecutive half-wired releases. A rule whose
# enforcer is called from nowhere is indistinguishable, in this file, from one
# called everywhere. I9 makes the difference representable and then required.
#
# Scope: `adjudication: script` only. An `llm` check is adjudicated by the lead
# READING gate-validation.md, so that file is inherently its call site; demanding
# a call_sites list there would be ceremony.
# ONE pass over the map, emitting a tagged stream, instead of re-awking the whole file
# once per check id and then forking sites_of()/enforcers_of() on each block. The three
# extractions below are the same three grammars the per-block helpers used, transcribed
# unchanged; what changes is that the map is read once rather than 41 times.
#
#   A<TAB>id<TAB>adjudication       first `    adjudication:` in the block
#   S<TAB>id<TAB>site               each `      - site:` inside `    call_sites:`
#   E<TAB>id<TAB>enforcer           each `      - core/(scripts|hooks)/...` line
#
# Emission order is the map's own order, so the ids, their enforcers and their sites are
# still visited in the sequence the old nested loops visited them and the errors below
# come out in the same order.
map_stream="$(awk '
  /^checks:/ { inck = 1 }
  inck && /^  - id:/ {
    id = $0; sub(/^  - id:[ ]*/, "", id); gsub(/"/, "", id); adj = ""; cs = 0; next
  }
  !inck { next }
  /^    call_sites:/ { cs = 1; next }
  cs && /^    [a-z_]+:/ { cs = 0 }
  cs && /^      - site:/ { v = $0; sub(/^      - site:[ ]*/, "", v); print "S\t" id "\t" v }
  /^    adjudication: [a-z]/ {
    if (adj == "") { a = $0; sub(/^    adjudication: /, "", a); sub(/[^a-z].*$/, "", a); adj = a; print "A\t" id "\t" adj }
  }
  match($0, /^      - core\/(scripts|hooks)\/[A-Za-z0-9._-]+/) {
    e = substr($0, RSTART, RLENGTH); sub(/^      - /, "", e); print "E\t" id "\t" e
  }
' "$MAP")"

# Resolve a site's leading file token to a real path under the skill.
resolve_site_file() {
  case "$1" in
    SKILL.md*)            echo "$REPO_ROOT/core/skills/ai-dlc/SKILL.md" ;;
    enforcement-map.yaml*) echo "" ;;
    *.md*)                echo "$REPO_ROOT/core/skills/ai-dlc/steps/${1%%[ ]*}" ;;
    *)                    echo "" ;;
  esac
}

w2_cache=""
i9_entry() { # i9_entry <id> <adjudication> ; reads $sites and $enfs
  local blk_id="$1" adj="$2"
  [ -n "$blk_id" ] || return 0
  [ "$adj" = "script" ] || return 0

  # W1 -- a script enforcer with no declared call site.
  if [ -z "$sites" ]; then
    err "enforcement-map entry '$blk_id' is adjudication:script but declares NO call_sites. Its enforcer may be invoked from nowhere and nothing would notice — this is exactly how validate-steering-budget.sh came to guard 11 live violations from zero gates. Declare where it runs, with a posture."
    return 0
  fi

  # W2 -- a declared call site must at least NAME the enforcer in the file it
  # points at. This catches a fictional site: an entry claiming to run at a step
  # whose file has never heard of the script.
  #
  # What W2 deliberately does NOT do, stated so nobody reads it as covered: it
  # cannot distinguish an INVOCATION from a PROSE MENTION. `retro.md:639` is a real
  # indented command; `implementation.md:152` ("validate-steering-budget.sh fails
  # the gate") is a sentence that was false for every gate that ever ran -- and a
  # basename grep passes both. Telling them apart means parsing English, and a
  # heuristic that fails closed on a legitimate new phrasing is an unpassable gate,
  # which gets turned off.
  #
  # The teeth are therefore in W1 + the `posture:` field, not here: an author must
  # WRITE DOWN where the enforcer runs and what happens when it fails, and that
  # declaration is reviewable. W2 only stops the declaration from naming a file
  # that does not know the script exists.
  #
  # Accept the bare form (`scripts/validate-X.sh`) and the verdict.sh wrapper
  # (`verdict.sh validate-X`), which is how gate-validation.md legitimately invokes
  # artifact-budget -- a basename-only grep misses the wrapped call entirely.
  local enf base stem site f hit
  for enf in $enfs; do
    base="${enf##*/}"
    stem="${base%.sh}"
    case "$enf" in core/hooks/*) continue ;; esac   # hooks are wired in settings, not step files
    while IFS= read -r site; do
      [ -n "$site" ] || continue
      f="$(resolve_site_file "$site")"
      [ -n "$f" ] || continue
      if [ ! -f "$f" ]; then
        err "entry '$blk_id' names call site '$site', but $f does not exist"
        continue
      fi
      # The same (file, enforcer) pair recurs across entries -- gate-validation.md is the
      # site for most of the catalog -- so the answer is remembered rather than re-grepped.
      # The predicate is unchanged; only the number of times it is evaluated is. The cache
      # is keyed on both halves, so it cannot answer for a pair it was not asked about.
      case "$w2_cache" in
        *"|$f|$base|y|"*) hit=y ;;
        *"|$f|$base|n|"*) hit=n ;;
        *) if grep -qE "(${base}|verdict\.sh ${stem}\b)" "$f"; then hit=y; else hit=n; fi
           w2_cache="$w2_cache|$f|$base|$hit|" ;;
      esac
      if [ "$hit" = n ]; then
        err "entry '$blk_id' declares call site '$site', but ${f##*/} never mentions ${base} (nor 'verdict.sh ${stem}'). The site is fictional: the file it names has never heard of the enforcer."
      fi
    done <<SITES
$sites
SITES
  done
}

# Walk the tagged stream once, flushing each id's accumulated block when the id changes.
cur=""; cur_adj=""; sites=""; enfs=""
while IFS="$(printf '\t')" read -r i9_tag i9_id i9_val; do
  [ -n "$i9_tag" ] || continue
  if [ "$i9_id" != "$cur" ]; then
    [ -n "$cur" ] && i9_entry "$cur" "$cur_adj"
    cur="$i9_id"; cur_adj=""; sites=""; enfs=""
  fi
  case "$i9_tag" in
    A) cur_adj="$i9_val" ;;
    S) sites="${sites:+$sites
}$i9_val" ;;
    E) enfs="${enfs:+$enfs
}$i9_val" ;;
  esac
done <<STREAM
$map_stream
STREAM
[ -n "$cur" ] && i9_entry "$cur" "$cur_adj"

# --- I5: core_manifest copies in sync (prefix-normalized) --------------------
# norm_core_manifest() is defined above I8, which needs it too. One definition.
cm="$(norm_core_manifest "$CORE_MANIFEST")"
ss="$(norm_core_manifest "$SETUP_SITES")"
if [ "$cm" != "$ss" ]; then
  err "core_manifest copies diverge (core-manifest.md vs reconcile/setup-sites.md):"
  diff <(printf '%s\n' "$cm") <(printf '%s\n' "$ss") >&2 || true
fi

# --- I43: the consumer machinery home is ONE string across every surface -------
# requires-arms: I5
# THE DEFECT. `scripts/ai-dlc-local/` was advertised in FIVE independent hand-written
# spellings and declared in none: the core-guard's deny text routes an author there,
# `reconcile/warn-shadowed-local-validators.sh` defaults `LOCAL_DIR` to it, two fixtures
# write into it, and core-manifest.md said it in prose. Nothing compared them. This is
# the affordance-is-the-defect shape -- the guard PROMISES a home, and the promise was
# the only thing holding the value. A rename in any one surface leaves the guard routing
# authors to a directory the reader never walks, and both halves stay green because each
# is internally consistent.
#
# BOTH DIRECTIONS, and the reverse one is the one that matters:
#   forward  no core file names a `scripts/ai-dlc*` path other than core's own
#            `scripts/ai-dlc` and the declared home. Catches a rename or a second home.
#   reverse  the declared home is actually named by the core-guard's deny text. A home
#            no affordance routes to is one no author finds, so the declaration would be
#            live, self-consistent, and reachable by nobody.
#
# The grammar is `scripts/ai-dlc[A-Za-z0-9_-]*` and its false-positive set over the whole
# distribution is EMPTY: exactly two tokens exist, `scripts/ai-dlc` (458 occurrences) and
# `scripts/ai-dlc-local` (14). Measured before this check was written, per CLAUDE.md.
cmh_decl() { # <file> -> the declared home, trailing slash stripped
  sed -n 's/^consumer_machinery_home:[[:space:]]*//p' "$1" | head -1 | sed 's#/*$##'
}
CMH="$(cmh_decl "$CORE_MANIFEST")"
CMH_SS="$(cmh_decl "$SETUP_SITES")"
CORE_SCRIPTS_HOME="$(printf '%s\n' "$cm" | grep -E '^scripts/[A-Za-z0-9_-]+/\*$' | sed 's#/\*$##' | head -1)"

if [ -z "$CMH" ] || [ -z "$CMH_SS" ]; then
  err "I43 could not read 'consumer_machinery_home:' from core-manifest.md and/or reconcile/setup-sites.md (got '${CMH:-<none>}' and '${CMH_SS:-<none>}'). Both copies are required: the core-guard routes authors to this path and reconcile/ cannot read core-manifest.md at runtime, so an absent declaration leaves the two ends bound by nothing while this check reports the same line as agreement."
elif [ "$CMH" != "$CMH_SS" ]; then
  err "I43 the consumer machinery home differs between its two declarations — core-manifest.md says '$CMH', reconcile/setup-sites.md says '$CMH_SS'. ai-dlc-update reads its own copy, everything else reads the manifest's, so the guard would route an author to one directory while the reader walks another."
elif [ -z "$CORE_SCRIPTS_HOME" ]; then
  err "I43 could not derive core's own scripts home from the core_manifest entries (expected one 'scripts/<dir>/*' glob). Without it the token scan below cannot tell core's directory from the consumer's, so every occurrence would read as a violation or none would."
else
  # Forward: every scripts/ai-dlc* token in a shipped core file is one of the two homes.
  cmh_bad="$(grep -rhoE 'scripts/ai-dlc[A-Za-z0-9_-]*' \
               "$REPO_ROOT/core" "$REPO_ROOT/scripts" "$REPO_ROOT/templates" "$REPO_ROOT/.githooks" 2>/dev/null \
             | sort -u | grep -vxF "$CORE_SCRIPTS_HOME" | grep -vxF "$CMH" || true)"
  if [ -n "$cmh_bad" ]; then
    err "I43 shipped core file(s) name a scripts/ai-dlc* path that is neither core's own '$CORE_SCRIPTS_HOME' nor the declared consumer machinery home '$CMH': $(echo $cmh_bad). Either the home was renamed in one surface and not the declaration, or a second home was invented. Both leave the core-guard routing authors somewhere no reader walks. Offending file(s):"
    grep -rlE "$(printf '%s' "$cmh_bad" | paste -sd'|' -)" "$REPO_ROOT/core" "$REPO_ROOT/scripts" "$REPO_ROOT/templates" "$REPO_ROOT/.githooks" 2>/dev/null >&2 || true
  fi
  # Zero guard on the forward scan: the grammar must still match core's own home
  # somewhere, or an extraction that stopped matching would report a clean scan.
  if ! grep -rqoE 'scripts/ai-dlc[A-Za-z0-9_-]*' "$REPO_ROOT/core" 2>/dev/null; then
    err "I43's token scan matched NOTHING under core/, not even core's own '$CORE_SCRIPTS_HOME'. The grammar or the search root has moved, and an empty scan passes the forward arm exactly like a clean tree."
  fi
  # Reverse: the guard's deny text must route an author to the declared home.
  CMH_GUARD="$REPO_ROOT/core/hooks/ai-dlc-core-guard.sh"
  if [ ! -f "$CMH_GUARD" ]; then
    err "I43 could not read the core-guard at $CMH_GUARD, so the reverse arm compared nothing. A missing guard is not a passing one."
  elif ! grep -qF "$CMH" "$CMH_GUARD"; then
    err "I43 the declared consumer machinery home '$CMH' appears nowhere in core/hooks/ai-dlc-core-guard.sh. The guard's deny text is the ONLY thing that routes an author to this directory when it refuses a write under core's own scripts home; a declared home nothing points at is an affordance no author ever finds, and it fails silently because the declaration itself stays internally consistent."
  fi
fi

# --- I44: core never reads, never writes and never overwrites the home ---------
# requires-arms: I43
# core-manifest.md and the guard's deny text BOTH make this promise in those words.
# Nothing asserted it. A manifest entry or an install.sh target landing under the home
# would make the promise false while every reader of the prose still believes it -- and
# the consumer finds out when a pull clobbers a script it authored.
#
# Derived, not hand-listed: every literal `$PROJECT_ROOT/`-rooted path install.sh and
# uninstall.sh name, plus every core_manifest entry mapped to consumer form.
cmh_targets="$(grep -ohE '\$PROJECT_ROOT/[A-Za-z0-9_./$-]*' "$REPO_ROOT/scripts/install.sh" "$REPO_ROOT/scripts/uninstall.sh" 2>/dev/null \
               | sed 's|^\$PROJECT_ROOT/||' | sort -u)"
cmh_claims="$(printf '%s\n' "$cm" | sed -E '
  s@^team-roles/@.claude/team-roles/@;
  s@^hooks/@.claude/hooks/@;
  s@^session-driver/@.claude/session-driver/@;
  s@^schemas/@.claude/schemas/@;
  s@^skills/@.claude/skills/@;
  s@^fixtures/@tests/fixtures/@;
  s@^git-hooks/@.githooks/@' | sort -u)"
if [ -n "$CMH" ]; then
  if [ -z "$cmh_targets" ]; then
    err "I44 extracted ZERO \$PROJECT_ROOT-rooted targets from install.sh/uninstall.sh. An empty target set contains nothing under the home, so this invariant would pass on a tree that installs straight into it."
  elif ! grep -q "^${CORE_SCRIPTS_HOME:-scripts/ai-dlc}" <<<"$cmh_targets"; then
    err "I44's target extraction no longer sees core's own scripts home among install.sh's targets — the \$PROJECT_ROOT grammar has moved. Without that positive control a broken extractor reports the same clean result as a correct one."
  else
    cmh_hits="$(printf '%s\n%s\n' "$cmh_targets" "$cmh_claims" | sort -u | grep -E "^${CMH}(/|$)" || true)"
    [ -n "$cmh_hits" ] && err "I44 core writes or claims path(s) under the consumer machinery home '$CMH': $(echo $cmh_hits). core-manifest.md and the core-guard's deny text both promise core 'never reads, never writes and never overwrites' this directory, and a consumer that believed the promise has its own script clobbered by the next pull. Move the path out of the home, or retract the promise in both places."
  fi
fi

# --- I45: core allocates below the reserved consumer band ----------------------
# The complement of E15. A consumer that renumbers its catalog into the band has bought
# exactly one guarantee — that core will never allocate the number it just took — and
# that guarantee is this check. Without it the band is a declaration with no mechanism,
# and the failure mode is the worst kind: it is invisible until core ships the
# allocation, at which point the collision it was supposed to prevent appears
# retroactively across every gate log the consumer has ever written.
#
# EVERYTHING HERE IS DERIVED, and the catalogs are read by RUNNING the shipping
# extractors rather than by copying their regexes. `defined_anchors` and
# `defined_rules` are lifted out of validate-layer-entries.sh and executed against
# core's own catalogs, so this invariant cannot answer a question the checker would
# answer differently — which is the failure a copied grammar produces and the one
# I26 exists for. The floor is read from the same file's BAND_FLOOR assignment. A
# partition whose halves disagree is worse than none: it publishes a range as
# reserved while core is still allocating from it.
vle="$REPO_ROOT/core/scripts/validate-layer-entries.sh"
if [ ! -f "$vle" ]; then
  err "I45 cannot find validate-layer-entries.sh at $vle. The band floor and both catalog extractors are read from it, so its absence would retire this invariant while reporting nothing."
else
  band_floor="$(sed -n 's/^BAND_FLOOR=\([0-9][0-9]*\)$/\1/p' "$vle" | head -1)"
  band_alpha="$(sed -n 's/^BAND_ALPHA_PREFIX=\([A-Za-z]\)$/\1/p' "$vle" | head -1)"
  band_gv="$REPO_ROOT/core/skills/ai-dlc/steps/gate-validation.md"
  band_sk="$REPO_ROOT/core/skills/ai-dlc/SKILL.md"
  # awk, not sed: BSD sed mis-parses the `{` in a `/^fn\(\) \{/` address. Same
  # extraction the layer-catalog-collision fixture uses on this file's functions.
  band_fn() { awk -v fn="$1" '$0 ~ "^" fn "\\(\\) \\{" {p=1} p {print} p && /^\}/ {exit}' "$vle"; }

  if [ -z "$band_floor" ]; then
    err "I45 could not read BAND_FLOOR out of core/scripts/validate-layer-entries.sh. The floor is the only thing that says which numbers are core's, so an unreadable one makes every core number conforming and this check vacuous."
  elif [ -z "$band_alpha" ]; then
    err "I45 could not read BAND_ALPHA_PREFIX out of core/scripts/validate-layer-entries.sh. It is the ALPHABETIC half of the same partition — the half that keeps core off 'XAP' after a consumer renames 'AP' into it — and an unreadable value makes every core alphabetic id conforming, which is this arm's PASS."
  elif [ ! -f "$band_gv" ] || [ ! -f "$band_sk" ]; then
    err "I45 cannot find core's catalogs (steps/gate-validation.md and/or SKILL.md). A scan over a missing file reports the same clean result as a scan over a conforming one."
  else
    # The CHECK_HEAD_RE assignment travels with the function, exactly as RULE_RE does
    # below: the grammar was hoisted out of defined_anchors so validate-gate-manifest.sh
    # could carry the same string (I47), and a lifted function whose pattern variable is
    # unset greps for the empty string and harvests NOTHING — which is this invariant's
    # PASS. The zero guard caught precisely that when the hoist landed.
    band_checks="$(bash -c "$(sed -n "/^CHECK_HEAD_RE='/p" "$vle")
$(band_fn bold_anchors_of_file)
$(band_fn defined_anchors)
defined_anchors \"\$1\"" _ "$band_gv" 2>/dev/null)"
    band_rules="$(bash -c "$(sed -n "/^RULE_RE='/p" "$vle")
$(band_fn defined_rules)
defined_rules \"\$1\"" _ "$band_sk" 2>/dev/null)"
    # THE ZERO GUARD, one per catalog, and it is the reason this check is worth
    # shipping rather than the scan below. Both grammars have drifted before —
    # ANCHOR_RE was widened for `### H1.` in v0.49.0's era and RULE_RE matched 0 of
    # 30 rules with the check grammar — and either extraction going empty produces
    # "no core number is in the band", which is precisely this invariant's PASS.
    if [ -z "$band_checks" ]; then
      err "I45 extracted ZERO check anchors from steps/gate-validation.md. The grammar or the file has moved; an empty catalog has nothing above the band floor, so this reads exactly like a conforming core."
    elif [ -z "$band_rules" ]; then
      err "I45 extracted ZERO rule headings from SKILL.md. Same shape as the check arm above — an empty rulebook passes the band assertion by containing nothing."
    else
      # BOTH HALVES OF THE PARTITION, and the numeric one is no longer `^[0-9]+$`.
      # That anchor meant a core id like `901a` — numeric-leading, suffixed, inside
      # the consumer band — was not a subject, so core could allocate into the range
      # it publishes as reserved and this invariant would report clean. The consumer
      # side governs the leading integer of ANY numeric-leading id (`19b` -> `919b`),
      # so this side has to read the same thing or the halves disagree.
      band_num='{ n=$0; sub(/[^0-9].*$/,"",n); if (n != "" && n+0 >= f+0) print $0 }'
      band_bad_c="$(printf '%s\n' "$band_checks" | awk -v f="$band_floor" "$band_num" | tr '\n' ' ')"
      band_bad_r="$(printf '%s\n' "$band_rules"  | awk -v f="$band_floor" "$band_num" | tr '\n' ' ')"
      # The alphabetic half. Rules carry no alphabetic ids today, so this arm reads the
      # check catalog only — and it is NOT scoped that way by preference: `defined_rules`
      # harvests `[0-9]+[a-z]*`, which cannot produce a leading letter at all, so an
      # alphabetic arm over it would be a check that cannot fire.
      band_bad_x="$(printf '%s\n' "$band_checks" | grep -E "^${band_alpha}" | tr '\n' ' ')"
      [ -n "$band_bad_x" ] && err "I45 core allocates alphabetic check id(s) beginning with the reserved consumer prefix '${band_alpha}': ${band_bad_x% }. A band is numeric and alphabetic ids have no place in one, so the partition's alphabetic half is a PREFIX: a consumer renames 'AP' to '${band_alpha}AP' and E15 tells it to. Core allocating '${band_alpha}…' recreates the collision that rename was performed to end, for every consumer at once. Allocate an alphabetic id that does not begin with '${band_alpha}'."
      [ -n "$band_bad_c" ] && err "I45 core allocates check number(s) at or above the reserved consumer band floor ${band_floor}: ${band_bad_c% }. steps/gate-validation.md is core's catalog and everything from ${band_floor} up belongs to the consumer — E15 tells authors to renumber into that range, so a core allocation there recreates, upstream and for every consumer at once, the exact collision the band exists to make unrepresentable. Allocate below ${band_floor}."
      [ -n "$band_bad_r" ] && err "I45 core allocates rule number(s) at or above the reserved consumer band floor ${band_floor}: ${band_bad_r% }. SKILL.md's rulebook is core's catalog and the band above ${band_floor} is the consumer's; a core rule there collides with every consumer that followed E15's advice, and it collides retroactively across rulebook citations already written. Allocate below ${band_floor}."
    fi
  fi
fi

# --- I46: the extension kind vocabulary is one set --------------------------------
# vocabulary: layer extension kinds
# vocabulary-invariant: I46
# vocabulary-owner: core/scripts/validate-layer-entries.sh
# vocabulary-extract: extension-kinds
# vocabulary-readers: core/skills/ai-dlc/extensions/README.md
#
# `LAYER_KINDS` in validate-layer-entries.sh is what E10 REJECTS against; the entry
# contract in extensions/README.md is what an author READS. Two copies of a closed
# vocabulary, and the failure is asymmetric in the worst direction: add a kind to the
# enum and forget the prose, and the grain exists with nothing telling anyone to use
# it; document a kind the enum does not carry, and the README instructs authors to
# write an entry the linter ERRORs on. Neither shows up in a test run of either file.
#
# This is I39's shape one vocabulary over, and the same reason: a hand-synced list is
# not a single source. Both sides are DERIVED — the enum from its shell assignment, the
# prose from the fenced `kind:` line in the entry contract — so neither can be
# satisfied by restating the other somewhere convenient.
lk_lint="$REPO_ROOT/core/scripts/validate-layer-entries.sh"
lk_doc="$REPO_ROOT/core/skills/ai-dlc/extensions/README.md"
if [ ! -f "$lk_lint" ] || [ ! -f "$lk_doc" ]; then
  err "I46 cannot find validate-layer-entries.sh and/or extensions/README.md. It joins the kind vocabulary across the two; a missing side would make the join pass by comparing nothing."
else
  # The enum, as the script defines it.
  lk_enum="$(sed -n "s/^LAYER_KINDS='\([^']*\)'.*/\1/p" "$lk_lint" | tr ' ' '\n' | grep -v '^$' | sort -u)"
  # The prose, from the `kind: a | b | c` line inside the entry contract's fence.
  lk_prose="$(sed -n 's/^kind:[[:space:]]*\(.*[|].*\)$/\1/p' "$lk_doc" | head -1 | tr '|' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' | sort -u)"
  if [ -z "$lk_enum" ]; then
    err "I46 could not read LAYER_KINDS out of core/scripts/validate-layer-entries.sh. That assignment is the set E10 rejects against, so an unreadable one makes this join vacuous while E10 keeps running."
  elif [ -z "$lk_prose" ]; then
    err "I46 could not read a 'kind: a | b | c' line out of extensions/README.md's entry contract. The prose side of the vocabulary is what authors read; extracting nothing from it compares the enum against an empty set, which is this invariant's PASS."
  else
    lk_only_enum="$(comm -23 <(printf '%s\n' "$lk_enum") <(printf '%s\n' "$lk_prose") | tr '\n' ' ')"
    lk_only_prose="$(comm -13 <(printf '%s\n' "$lk_enum") <(printf '%s\n' "$lk_prose") | tr '\n' ' ')"
    [ -n "$lk_only_enum" ]  && err "I46: validate-layer-entries.sh accepts kind(s) extensions/README.md never documents — ${lk_only_enum% }. A grain the linter allows and the entry contract omits is one no author is told exists, so it ships as dead vocabulary. Document it in the entry contract, or drop it from LAYER_KINDS."
    [ -n "$lk_only_prose" ] && err "I46: extensions/README.md documents kind(s) validate-layer-entries.sh rejects — ${lk_only_prose% }. The entry contract is instructing authors to write an entry E10 fails the build on. Add it to LAYER_KINDS, or stop documenting it."
  fi
fi

# --- I47: ONE check-heading grammar, across the linter and the manifest resolver ---
#
# `CHECK_HEAD_RE` decides what counts as a check DEFINITION. Two tools need it and they
# reach opposite verdicts if it forks: validate-layer-entries.sh harvests the ids a layer
# entry allocates (E6/W1/E15), and validate-gate-manifest.sh reports a definition that
# never became loadable (GM1). A narrower copy in the resolver silently shrinks GM1's
# subject set — and GM1's whole subject is checks nothing else reports, so the shrinkage
# would restore the exact silence it was written to end, with the build green.
#
# I40's reason for byte-identical COPIES rather than a shared source applies unchanged:
# the resolver is bash+python and python's `re` has no `[[:space:]]`, so the grammar
# lives in the bash half of both files precisely so it CAN be the same string.
# THE PAIR-OF-PAIRS EDGE, added because the pairs themselves forked and neither pair-check
# could see it. I15 held layer-drift.sh and relabel-extension-checks.sh identical while they
# widened to `[A-Z]{1,3}[0-9]*` and the `—` terminator; the two-file check above held the
# lint/resolver pair identical while they did not. Both invariants were green for four
# releases, and the reference consumer's `Check AP` and `Check VH` were live, unloadable and
# unreportable the whole time — a heading the REWRITER could relabel that the DETECTOR could
# not see. Two internally-consistent halves of one grammar is the same defect as one forked
# copy, and it is strictly harder to spot. So the join is three-way: the relabeller's
# ANCHOR_RE is compared here too, and I15 carries the fourth definition transitively.
ch_lint="$REPO_ROOT/core/scripts/validate-layer-entries.sh"
ch_man="$REPO_ROOT/core/scripts/validate-gate-manifest.sh"
ch_rel="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh"
if [ ! -f "$ch_lint" ] || [ ! -f "$ch_man" ] || [ ! -f "$ch_rel" ]; then
  err "I47 cannot find validate-layer-entries.sh, validate-gate-manifest.sh and/or reconcile/relabel-extension-checks.sh. It binds the check-heading grammar across the three; a missing side would make the join pass by comparing nothing."
else
  ch_a="$(grep -n '^CHECK_HEAD_RE=' "$ch_lint")"
  ch_b="$(grep -n '^CHECK_HEAD_RE=' "$ch_man")"
  ch_c="$(sed -n 's/^ANCHOR_RE=//p' "$ch_rel" | head -1)"
  if [ -z "$ch_a" ] || [ -z "$ch_b" ]; then
    err "I47 could not find a CHECK_HEAD_RE= assignment in validate-layer-entries.sh and/or validate-gate-manifest.sh. That assignment is what both tools call a check definition; failing to locate one makes this join vacuous while both keep running against whatever they do use."
  elif [ -z "$ch_c" ]; then
    err "I47 could not find an ANCHOR_RE= assignment in reconcile/relabel-extension-checks.sh. That assignment is what the rewriter calls a check heading; failing to locate it makes the detector-vs-rewriter half of this join vacuous while both keep running against whatever they do use."
  elif [ "${ch_a#*:}" != "${ch_b#*:}" ]; then
    err "I47: the check-heading grammar has forked between validate-layer-entries.sh and validate-gate-manifest.sh. One decides which check ids a layer entry allocates, the other which defined check never became loadable — a copy that differs means a heading one tool treats as a check definition the other cannot see, and GM1's subject set shrinks in silence. Make the CHECK_HEAD_RE= line byte-identical."
  elif [ "${ch_a#*:CHECK_HEAD_RE=}" != "$ch_c" ]; then
    err "I47: the DETECTORS' check-heading grammar and the REWRITER's have forked. validate-layer-entries.sh and validate-gate-manifest.sh define CHECK_HEAD_RE=${ch_a#*:CHECK_HEAD_RE=} while reconcile/relabel-extension-checks.sh defines ANCHOR_RE=$ch_c. Wider in the rewriter means a heading it will relabel that no detector reports — the state that hid two live unloadable checks for four releases. Wider in the detectors means a reported heading the operator is told to relabel with a tool that cannot see it. Widen all of them or none, in one release."
  fi
fi

# --- I48: the generated-region name is READ by both its writer and its reader ---
#
# `sync-taught-schema.sh` WRITES `<!-- BEGIN GENERATED: <slug>/<profile> … -->` regions; the
# `--strays` scan in `validate-provenance-block.sh` CUTS those same regions out before deciding
# whether a party-mode block is a relocated forgery. The one legitimately-rendered party-mode
# example in the whole distribution sits inside one, so the two agreeing about the slug is what
# separates "the taught example" from "a forgery".
#
# I25 and I47 bind two copies byte-identically because their subject cannot be a shared source.
# This one can: the slug is a schema key. So the assertion is not that two strings match — it is
# that neither side reintroduces a literal, which is the only way they could disagree again. The
# drift's failure mode is the reason it earns a check rather than a comment: the carve-out stops
# matching, core's own retro.md reports as a forgery, and an operator turns off a scan that is
# working perfectly.
rs_schema="$REPO_ROOT/core/schemas/provenance-block.json"
rs_writer="$REPO_ROOT/core/scripts/sync-taught-schema.sh"
rs_reader="$REPO_ROOT/core/scripts/validate-provenance-block.sh"
if [ ! -f "$rs_schema" ] || [ ! -f "$rs_writer" ] || [ ! -f "$rs_reader" ]; then
  err "I48 cannot find provenance-block.json, sync-taught-schema.sh and/or validate-provenance-block.sh. It binds the generated-region name across the schema that declares it and the two scripts that build it; a missing side would make the join pass by comparing nothing."
else
  rs_slug="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["region_slug"])' "$rs_schema" 2>/dev/null)"
  if [ -z "$rs_slug" ]; then
    err "I48: core/schemas/provenance-block.json declares no region_slug. Both the renderer and the stray scan build the generated-region markers from that key; with it gone each falls back to whatever it hard-codes, and the two can diverge without either failing."
  else
    for rs_f in "$rs_writer" "$rs_reader"; do
      # The SUBSCRIPT, not the name. A bare `region_slug` is satisfied by the sentence in this
      # file's own comment explaining why the key exists — measured, not hypothesised: the first
      # mutant here reverted the renderer to a literal and passed, because the comment left
      # behind still said the word. An arm a comment can satisfy is not an arm.
      if ! grep -qF '["region_slug"]' "$rs_f"; then
        err "I48: $(basename "$rs_f") no longer reads the schema's region_slug (no [\"region_slug\"] subscript). It builds a generated-region marker from a literal instead, and the renderer and the --strays carve-out can now name different regions. When they do, the one taught party-mode example in core reports as a forgery and the scan gets turned off. Read region_slug from the schema."
      fi
      # And the literal must not come back beside it. A file that reads the key AND hard-codes
      # the old name is the half-done change that reads exactly like a finished one.
      if grep -n "GENERATED: ${rs_slug}" "$rs_f" | grep -qv '^[0-9]*:[[:space:]]*#'; then
        err "I48: $(basename "$rs_f") hard-codes the region name 'GENERATED: ${rs_slug}' outside a comment. That is the second spelling this key exists to prevent — build the marker from region_slug."
      fi
    done
  fi
fi

# --- I49: every core-paths.sh MODE a rule file tells someone to run actually exists ---
#
# `core-paths.sh` is the one resolver three different enforcement surfaces agree through, and
# every one of them reaches it by a STRING typed into prose: the gate check body, SKILL.md
# Rule 27, the protected-path-editor role. Those callers are agents following a paragraph, not
# code a linter type-checks. A mode named in prose that the dispatch does not accept prints
# `usage:` and exits 2 — and 2 is this script's "cannot determine", so the instruction being
# WRONG and the manifest being UNREADABLE arrive at the caller as the same answer.
#
# The reverse direction is deliberately NOT "every mode has a caller": `--list` has none today
# and is a shipped interface, so that arm would fail on a fact this invariant has no business
# resolving. It is "every mode the dispatch accepts is in usage()" instead — a hidden mode is
# one no operator can find and no rename can reach.
cpm_f="$REPO_ROOT/core/scripts/core-paths.sh"
if [ ! -f "$cpm_f" ]; then
  err "I49 cannot find core/scripts/core-paths.sh. It binds the modes that script dispatches to the modes core's rule files tell an agent to run; with the script gone the join compares nothing and passes."
else
  # The dispatch arm, bounded by its own sentinels so the extraction cannot drift onto some
  # other `case` in the file.
  cpm_modes="$(awk '/# MODE_DISPATCH_BEGIN/{on=1} on{print} /# MODE_DISPATCH_END/{exit}' "$cpm_f" \
    | sed -nE 's@^[[:space:]]*(--[a-z-]+([|]--[a-z-]+)*)\).*@\1@p' | tr '|' '\n' | sort -u)"
  # Every mode spelling cited anywhere in core/ or scripts/, minus three subjects that are
  # not CALLERS. Each exclusion was measured, not anticipated — the first two turned the
  # pristine tree red while this invariant was being written, which is the same shape
  # v0.194.0 recorded for the machinery-home scan firing on its own fixture:
  #   - `core/fixtures/`  — its job is to write the wrong spelling down on purpose;
  #   - this file         — it quotes mode names inside error prose and inside the grep
  #                         flags below, and it never calls the resolver;
  #   - `core-paths.sh`   — a script documenting itself is not a caller, and counting it
  #                         would make the forward arm vacuous by construction.
  cpm_skip="--exclude-dir=fixtures"
  cpm_cited="$(grep -rhoE 'core-paths\.sh --[a-z-]+' "$REPO_ROOT/core" "$REPO_ROOT/scripts" 2>/dev/null \
    $cpm_skip --exclude=core-paths.sh --exclude="$(basename "$0")" \
    | sed -E 's@^core-paths\.sh @@' | sort -u)"
  cpm_usage="$(sed -nE 's@^[[:space:]]*echo "(usage: )?[[:space:]]*core-paths\.sh (--[a-z-]+).*@\2@p' "$cpm_f" | sort -u)"
  if [ -z "$cpm_modes" ] || [ -z "$cpm_cited" ] || [ -z "$cpm_usage" ]; then
    err "I49 parsed ZERO modes out of core-paths.sh's dispatch ($(printf '%s' "$cpm_modes" | grep -c . ) found), out of the rule files that cite it ($(printf '%s' "$cpm_cited" | grep -c . ) found), and/or out of its usage() text ($(printf '%s' "$cpm_usage" | grep -c . ) found). An empty set is a subset of everything, so this fails closed rather than reporting agreement it never computed."
  else
    cpm_ghost="$(comm -23 <(printf '%s\n' "$cpm_cited") <(printf '%s\n' "$cpm_modes") | tr '\n' ' ')"
    [ -n "$cpm_ghost" ] && err "I49 core rule files tell a caller to run core-paths.sh mode(s) the script does not dispatch: ${cpm_ghost}. That call prints usage and exits 2 — which this resolver defines as 'cannot determine what core is', so a wrong instruction and an unreadable manifest reach the gate as the same answer, and the one that is a typo reads as the one that is a real refusal."
    cpm_undoc="$(comm -23 <(printf '%s\n' "$cpm_modes") <(printf '%s\n' "$cpm_usage") | tr '\n' ' ')"
    [ -n "$cpm_undoc" ] && err "I49 core-paths.sh dispatches mode(s) its own usage() never names: ${cpm_undoc}. A mode no usage line mentions is one an operator cannot discover and a rename cannot reach — the callers are prose, and prose is updated by whoever read the usage text."
  fi
fi

# --- I53: the escalation-citation modes one core script asks another for actually exist ------
#
# I49 binds core-paths.sh's modes to the PROSE that names them. This is the same join where the
# caller is CODE: `core-paths.sh --audit-diff` decides whether the operator authorized an
# in-place core edit by shelling out to `validate-escalation-resolution.sh --any-authorized`,
# because that script owns the escalations.md citation grammar and the arm used to restate a
# looser one. A delegation is only better than a restatement while the mode on the other side
# is real — rename or drop it and the call exits 2 on an unknown argument, which the caller
# reads as "no citation" and turns into a FAIL on every consumer whose tree is clean.
#
# Both arms are the ones I49 settled on, for the same measured reasons: forward, every mode a
# caller names is dispatched; reverse, every dispatched mode appears in the USAGE block, because
# a hidden mode is one no operator finds and no rename reaches. "Every mode has a caller" is
# again NOT asserted — `--transcript` is a modifier of the gate mode, not a caller's entry point.
i53_f="$REPO_ROOT/core/scripts/validate-escalation-resolution.sh"
if [ ! -f "$i53_f" ]; then
  err "I53 cannot find core/scripts/validate-escalation-resolution.sh. It binds the modes that script dispatches to the modes core's other scripts invoke on it; with the script gone the join compares nothing and passes, while core-paths.sh's citation arm calls a file that is not there."
else
  i53_modes="$(awk '/# MODE_DISPATCH_BEGIN/{on=1;next} /# MODE_DISPATCH_END/{exit} on{print}' "$i53_f" \
    | sed -nE 's@^[[:space:]]*(--[a-z-]+([|]--[a-z-]+)*)\).*@\1@p' | tr '|' '\n' | sort -u)"
  # Callers, minus the three subjects I49 measured as non-callers, for the same reasons:
  # core/fixtures/ writes wrong spellings on purpose, this file quotes them in prose and in its
  # own grep flags, and a script documenting itself is not a caller.
  # Callers name the delegate in full, so the mode is a literal beside the script name in both
  # the code that calls it (`"$ESC_DIR/validate-escalation-resolution.sh" --mode`) and the prose
  # that describes the call. The optional closing quote is what lets one pattern see both.
  i53_cited="$(grep -rhoE 'validate-escalation-resolution\.sh"? --[a-z-]+' "$REPO_ROOT/core" "$REPO_ROOT/scripts" "$REPO_ROOT/templates" 2>/dev/null \
    --exclude-dir=fixtures --exclude=validate-escalation-resolution.sh --exclude="$(basename "$0")" \
    | sed -E 's@^validate-escalation-resolution\.sh"? @@' | sort -u)"
  # USAGE is a comment block here rather than an echo, and the EXIT block below it discusses
  # the same mode names in prose. Read the usage LINES — the ones spelling out an invocation —
  # not the block, or the reverse arm is satisfied by the paragraph explaining the exit codes.
  i53_usage="$(sed -nE 's@^#[[:space:]]+validate-escalation-resolution\.sh (.*)$@\1@p' "$i53_f" \
    | grep -oE '\-\-[a-z-]+' | sort -u)"
  if [ -z "$i53_modes" ] || [ -z "$i53_cited" ] || [ -z "$i53_usage" ]; then
    err "I53 parsed ZERO modes out of validate-escalation-resolution.sh's dispatch ($(printf '%s' "$i53_modes" | grep -c . ) found), out of the core scripts that invoke it ($(printf '%s' "$i53_cited" | grep -c . ) found), and/or out of its USAGE block ($(printf '%s' "$i53_usage" | grep -c . ) found). An empty set is a subset of everything, so this fails closed rather than reporting agreement it never computed."
  else
    i53_ghost="$(comm -23 <(printf '%s\n' "$i53_cited") <(printf '%s\n' "$i53_modes") | tr '\n' ' ')"
    [ -n "$i53_ghost" ] && err "I53 core scripts invoke validate-escalation-resolution.sh mode(s) it does not dispatch: ${i53_ghost}. That call exits 2 on an unknown argument, and core-paths.sh's citation arm reads any non-zero as 'no operator citation' — so a renamed mode turns the core-layer-immutability backstop into a FAIL on trees that are clean, which is how a working check gets switched off."
    i53_undoc="$(comm -23 <(printf '%s\n' "$i53_modes") <(printf '%s\n' "$i53_usage") | tr '\n' ' ')"
    [ -n "$i53_undoc" ] && err "I53 validate-escalation-resolution.sh dispatches mode(s) its own USAGE block never names: ${i53_undoc}. A mode no usage line mentions is one an operator cannot discover and a rename cannot reach."
  fi
fi

# --- I50: every scripts/ai-dlc/<script> a shipped file names is one core actually ships ---
#
# I49 binds the MODES of one resolver. This is the same join one level out, over every
# validator core tells an agent to run: `scripts/ai-dlc/<x>.sh` is a string typed into a
# role file, a step file or an enforcement-map row, and install.sh DERIVES that directory
# from `core/scripts/` — so a citation naming a file core does not ship resolves to
# nothing in every consumer tree. The agent following that paragraph runs a command that
# is not there, and "the validator did not report anything" is what a clean run looks
# like. This repo's named defect class, reached through a filename instead of a flag.
#
# ONE DIRECTION ONLY, and the reason is measured: `validate-cycle-commits.sh` ships and no
# shipped file names it by path. A shipped-but-uncited validator is reached through the
# gate catalog, a hook, or another script, so the reverse arm would fail on a fact this
# invariant has no business resolving — the same call I49 makes about `--list`.
#
# core/fixtures/ is excluded, and that exclusion is load-bearing rather than tidy: the
# fixtures write 13 deliberately-nonexistent `scripts/ai-dlc/` paths, because inventing a
# validator that is not there is exactly what several of them test. templates/ IS in the
# corpus — it is installed into the consumer's tree, so a dead citation there is dead in
# the same place, for the same reader.
i50_have="$(ls "$REPO_ROOT/core/scripts" 2>/dev/null | sed 's@^@scripts/ai-dlc/@' | sort -u)"
i50_cited="$(grep -rhoE 'scripts/ai-dlc/[A-Za-z0-9_.-]+\.(sh|js)' \
  "$REPO_ROOT/core" "$REPO_ROOT/templates" 2>/dev/null --exclude-dir=fixtures | sort -u)"
if [ -z "$i50_have" ] || [ -z "$i50_cited" ]; then
  err "I50 derived an EMPTY set: $(printf '%s' "$i50_have" | grep -c .) script(s) under core/scripts/, $(printf '%s' "$i50_cited" | grep -c .) citation(s) across core/ and templates/. Every citation is a member of a set that contains everything, so this fails closed rather than reporting an agreement it never computed."
else
  i50_ghost="$(comm -23 <(printf '%s\n' "$i50_cited") <(printf '%s\n' "$i50_have") | tr '\n' ' ')"
  [ -n "$i50_ghost" ] && err "I50 shipped file(s) tell an agent to run validator(s) core does not ship: ${i50_ghost}. install.sh writes scripts/ai-dlc/ from core/scripts/, so that path exists in no consumer tree; the command fails to start, and a validator that never ran reports exactly what a validator that found nothing reports."
fi

# --- I51: the one commit Step 5b licenses has ONE subject across the schema and the step file ---
#
# Two copies of a commit subject, and they are read by different readers at different times:
# `retro.md` Step 5b is what the LEAD types, `backfill_commit.subject_pattern` is what
# --trunk-push MATCHES at push time. Drift between them does not fail loudly — it fails at the
# moment the lead has already written the commit and cannot land it, on the one push in the
# sprint that has no PR to fall back to, with the retro already merged.
#
# The prose carries a template (`<N>`, `<PR>`); the schema carries a regex. Neither is derivable
# from the other by string equality, so the join FILLS the template and matches it — which is
# exactly what the lead does by hand, and what the matcher then sees.
i51_out="$(python3 - "$REPO_ROOT" <<'PY'
import json, os, re, sys
root = sys.argv[1]
try:
    bc  = json.load(open(os.path.join(root, "core/schemas/audit-anchors.json")))["backfill_commit"]
    pat = bc["subject_pattern"]; ex = bc.get("subject_example", "")
except Exception as e:
    print(f"ZERO the schema has no readable backfill_commit block ({e})"); raise SystemExit(0)
if not pat or not ex:
    print("ZERO backfill_commit is missing subject_pattern or subject_example"); raise SystemExit(0)
try:
    prose = open(os.path.join(root, "core/skills/ai-dlc/steps/retro.md")).read()
except Exception as e:
    print(f"ZERO cannot read retro.md ({e})"); raise SystemExit(0)
# The delimiter is a backtick, spelled \x60 throughout. A literal one here is still seen by
# the command substitution this heredoc sits inside and closes nothing, which surfaces as a
# syntax error two hundred lines away with no relation to this block. For the same reason
# there is no apostrophe anywhere in this heredoc: one opens a quote that swallows the rest.
#
# Keyed on "backfill", NOT on the chore(s<N>) prefix: retro.md carries a SECOND commit
# template under that same prefix (gate-log rotation, Step 6f). Keying on the shared prefix
# picked whichever appeared first in the file, so deleting the backfill template selected
# the rotation one and the vacuity case came back as an ordinary mismatch. Exactly one
# template may match; two would make the comparison depend on file order again.
found = re.findall("\x60(chore\\(s<N>\\): backfill[^\x60]*)\x60", prose)
if len(found) != 1:
    print(f"ZERO retro.md carries {len(found)} backfill subject templates in backticks, expected exactly 1")
    raise SystemExit(0)
tmpl   = found[0]
filled = tmpl.replace("<N>", "299").replace("<PR>", "828")
if not re.match(pat, filled):
    print(f"TEMPLATE {tmpl}")
if not re.match(pat, ex):
    print(f"EXAMPLE {ex}")
PY
)"
case "$i51_out" in
  ZERO*)
    err "I51 could not derive both sides: ${i51_out#ZERO }. The subject the lead types and the subject --trunk-push matches are then compared by nothing, and this fails closed rather than reporting an agreement it never computed." ;;
  *TEMPLATE*)
    err "I51 retro.md Step 5b tells the lead to write a subject the shipped matcher rejects: $(printf '%s' "$i51_out" | sed -n 's/^TEMPLATE //p'). A lead who follows the step file to the letter writes a commit --trunk-push refuses, on the one push in the sprint with no PR route around it. Reconcile the template with backfill_commit.subject_pattern." ;;
esac
case "$i51_out" in
  *EXAMPLE*)
    err "I51 backfill_commit.subject_example does not match backfill_commit.subject_pattern in the same block: $(printf '%s' "$i51_out" | sed -n 's/^EXAMPLE //p'). --trunk-push prints that example as the remedy on every rejection, so a consumer told to copy it writes a commit the same run just refused." ;;
esac

# I5b lived here until v0.160.0: it asserted the manifest's 27 enumerated validators
# equalled `ls core/scripts/`. The manifest now claims `scripts/ai-dlc/*`, so the
# direction that mattered -- a validator added upstream with no manifest entry, hence
# unguarded at edit time -- is structurally impossible rather than merely checked, and
# an entry with no file cannot occur. What the enumeration could still detect (a
# consumer file squatting in the core directory) measured zero occurrences and is now
# handled at edit time instead: the guard classifies a squatter as core and denies both
# the edit and the Write that would create it. core/fixtures/core-script-boundary/
# assertion 8 asserts that. Nothing else in the repo joined the manifest to
# core/scripts/, so nothing replaced it.

# --- I12: unregistered-drift scan set is BOUND, not hand-listed ---------------
# reconcile/unregistered-drift.sh scans a HAND-LISTED set of core subtrees for in-place drift.
# Twice that list silently missed a subtree that carried silently-driftable content —
# ai-dlc-setup/ (v0.63.0) and schemas/ (this release) — each overwrite-on-pull, each undetected
# until a real pull hit it. A hand-list is exactly the shape that rots: the next core dir escapes
# the scan and reads, forever, like a dir with no drift. So bind the list to a REVIEWED per-subtree
# policy, and make a new core subtree FAIL the build until it is classified.
#
#   COMPLETENESS — every core/skills/<skill>/ and every other core/<dir>/ has a policy row.
#   SCAN-MATCH   — the rows marked `scan` are EXACTLY the subtrees the ls-tree scans.
# The reason string on each `exempt` row is the review, and it must state a property that
# HOLDS: machinery breaks loudly (not silent prose drift), the update skill self-updates its own
# tree, and test data carries no rule to drift. `fixtures` was exempted as "not consumer-authored"
# until the reference consumer was measured carrying four edited fixture files — the exemption was
# right and its reason was false, which is the shape that survives review by being unread.
UD="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/unregistered-drift.sh"
if [ -f "$UD" ]; then
  DRIFT_POLICY="$(cat <<'POL'
skills/ai-dlc|scan
skills/ai-dlc-setup|scan
skills/ai-dlc-update|exempt:self-update owns this subtree (step 2), not the drift scan
team-roles|scan
hooks|scan
schemas|scan
rules|exempt:a DUPLICATE carrier of SKILL.md prose, not an authority — the rule file itself defers to overrides/, so a consumer changing Rule 23 edits the layer and not this copy, and the text that IS authoritative (SKILL.md) is scan-marked above
scripts|exempt:machinery — an in-place edit breaks loudly (a failing validator), not as silent prose drift
session-driver|exempt:machinery (automation shell), not consumer-read rulebook
ci-templates|exempt:CI templates run from .github/workflows, not consumer-read rulebook
git-hooks|exempt:machinery (git hook), not consumer-read rulebook
fixtures|exempt:test data, not layered rulebook — an in-place edit changes no rule the lead obeys and has no overrides/ entry to refile into, and it cannot be silently destroyed: apply writes only the base→theirs diff, where preclassify already buckets a consumer-edited file as BOTH-CHANGED->CLASSIFY
POL
)"
  # Subtrees actually scanned: the core/ paths on unregistered-drift's ls-tree pathspec line.
  ud_scanned="$(awk '/ls-tree -r --name-only/{f=1} f{print} /2>\/dev\/null/{f=0}' "$UD" \
    | grep -oE 'core/skills/[A-Za-z0-9_-]+|core/[A-Za-z0-9_-]+' | sed 's#^core/##' | sort -u)"
  # Units on disk: each skill under core/skills/, plus each other core/<dir>.
  ud_units="$( { for d in "$REPO_ROOT"/core/skills/*/; do d="${d%/}"; [ -d "$d" ] && echo "skills/${d##*/}"; done
                 for d in "$REPO_ROOT"/core/*/; do d="${d%/}"; b="${d##*/}"; [ "$b" = skills ] && continue; [ -d "$d" ] && echo "$b"; done; } | sort -u)"

  # COMPLETENESS — every unit on disk is classified.
  while IFS= read -r u; do
    [ -n "$u" ] || continue
    grep -q "^${u}|" <<<"$DRIFT_POLICY" \
      || err "core/${u}/ has no drift-scan policy row in validate-enforcement-map.sh I12. Classify it 'scan' (prose/schema a consumer could silently drift) or 'exempt:<reason>' (machinery / self-updated). This is the guard that stops the unregistered-drift scan set rotting the way ai-dlc-setup/ and schemas/ did."
  done <<EOF
$ud_units
EOF
  # Stale rows — every policy row names a real subtree.
  while IFS='|' read -r u disp; do
    [ -n "$u" ] || continue
    [ -d "$REPO_ROOT/core/$u" ] || err "I12 drift-scan policy names core/$u/, which does not exist — stale row."
  done <<EOF
$DRIFT_POLICY
EOF
  # SCAN-MATCH — the scan-marked policy set equals the tool's actual scan set.
  scan_policy="$(printf '%s\n' "$DRIFT_POLICY" | awk -F'|' '$2=="scan"{print $1}' | sort -u)"
  miss_scan="$(comm -23 <(printf '%s\n' "$scan_policy") <(printf '%s\n' "$ud_scanned"))"
  extra_scan="$(comm -13 <(printf '%s\n' "$scan_policy") <(printf '%s\n' "$ud_scanned"))"
  [ -n "$miss_scan" ]  && err "I12: policy marks these core subtrees 'scan' but unregistered-drift.sh does NOT scan them: $(echo $miss_scan). A scan-marked dir the tool skips is a silent-drift hole."
  [ -n "$extra_scan" ] && err "I12: unregistered-drift.sh scans these but the policy does not mark them 'scan': $(echo $extra_scan). Add a 'scan' row or drop them from the ls-tree."

  # --- I31: every scan-marked subtree has a DISPOSITION in register-drift.sh -----
  # I12 above makes a scan-marked subtree REPORTABLE. It says nothing about what the operator
  # does next, and the report hands them exactly one command: register-drift.sh. That script
  # recognised `skills/ai-dlc/*` and `team-roles/*`, named a refusal for `hooks/*`, and dropped
  # everything else into `unrecognized core path` — a message that reads like a typo in a path
  # the REPORT ITSELF supplied. Measured: `skills/ai-dlc-setup` and `schemas` are both scan-marked
  # and both landed there, so a consumer with deliberate divergence in either had no sanctioned
  # disposition at all, and the pull re-reported HARD- forever.
  #
  # So bind the second list to the first. The case labels are DERIVED from the script — a hand
  # copy of them here would be the same rot one file over.
  RD="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/register-drift.sh"
  if [ -f "$RD" ]; then
    rd_disposed="$(awk '/^case "\$REL" in/{f=1; next} f && /^esac/{exit} f' "$RD" \
      | grep -oE '^[[:space:]]*[a-z][A-Za-z0-9_./*|-]*\)' \
      | tr -d ' )' | tr '|' '\n' | sed 's#/\*$##' | grep -v '^\*$' | sort -u)"
    if [ -z "$rd_disposed" ]; then
      err "I31: could not parse any case label out of register-drift.sh — the check below would pass on nothing. Fix the parse, do not delete the check."
    else
      no_disp="$(comm -23 <(printf '%s\n' "$scan_policy") <(printf '%s\n' "$rd_disposed"))"
      [ -n "$no_disp" ] && err "I31: these core subtrees are I12 'scan' (so unregistered-drift.sh REPORTS them and the report hands the operator register-drift.sh) but register-drift.sh has no case for them: $(echo $no_disp). They fall to 'unrecognized core path', which reads as a bad path rather than a structural refusal. Give each one a registering case or a NAMED no-grain refusal."
    fi
  fi
fi

# --- I32: a Check 17 skill PIN names the skill its own step file invokes -------
# THE DEFECT. Check 17's arms pin a provenance block to a skill NAME, and the step file that
# runs the evaluation names the skill it INVOKES. Two files, one fact, nothing comparing them.
# v0.169.0 repointed `research-requirements.md` §3 from `/bmad-validate-prd` to `/bmad-prd` and
# left the arm pinning the old name, so the gate would have failed on a correctly-executed run
# — and nothing said so for three minors, because a pin and an invocation look identical when
# read one file at a time.
#
# SCOPED TO `bmad-*` PINS, on a stated and derivable ground. The native `ai-dlc-*` reviews are
# invoked by NO step file by design — team-roles/adversary.md is explicit that a convergence
# review "invoke[s] NO skill", so the story-readiness arm's `ai-dlc-adversary-review` appears in
# zero step files and always would. Measured before this check was written; a literal-invocation
# join over all arms would have fired on it. A prefix is the rule, not a hand-listed exemption.
GV="$REPO_ROOT/core/skills/ai-dlc/steps/gate-validation.md"
PB_SCHEMA="$REPO_ROOT/core/schemas/provenance-block.json"
if [ -f "$GV" ] && [ -f "$PB_SCHEMA" ]; then
  # Arms of Check 17, one per line: "<parenthetical>|<required skill>". Multi-line arms are
  # joined first — `--require-skill` routinely wraps onto the next line.
  arms="$(awk '/<!-- CHECK_LOADED: 17 -->/{on=1} /<!-- CHECK_LOADED: 18 -->/{on=0}
    on && /^- \*\*/ { if (buf != "") print buf; buf=$0; next }
    on && buf != ""  { buf = buf " " $0 }
    END { if (buf != "") print buf }' "$GV" \
    | sed -nE 's/^- \*\*[^(]*\(([^)]*)\).*--require-skill[[:space:]]+`?([A-Za-z0-9._-]+)`?.*$/\1|\2/p')"
  # Step-file basenames, DERIVED from the tree — never a second list to keep in sync.
  step_names="$(cd "$REPO_ROOT/core/skills/ai-dlc/steps" 2>/dev/null && ls *.md 2>/dev/null | sed 's/\.md$//')"
  n_bmad_arms=0
  while IFS='|' read -r hint skill; do
    [ -n "$skill" ] || continue
    case "$skill" in bmad-*) ;; *) continue ;; esac
    n_bmad_arms=$((n_bmad_arms + 1))
    step=""
    for s in $step_names; do
      case "$hint" in *"$s"*) [ ${#s} -gt ${#step} ] && step="$s" ;; esac
    done
    if [ -z "$step" ]; then
      err "I32: Check 17's arm '($hint)' pins '$skill' but its parenthetical names no step file under core/skills/ai-dlc/steps/. The arm has to say which step runs the evaluation, or the pin cannot be joined to anything."
      continue
    fi
    # The step may name the pinned skill or any name the schema records as the same evaluation
    # under a different release's name.
    accepted="$skill $(python3 - "$PB_SCHEMA" "$skill" <<'PY' 2>/dev/null
import json, sys
sup = {k: v for k, v in json.load(open(sys.argv[1])).get("superseded_skills", {}).items() if not k.startswith("$")}
want = sys.argv[2]
print(" ".join(sorted({v for k, v in sup.items() if k == want} | {k for k, v in sup.items() if v == want})))
PY
)"
    hit=0
    for a in $accepted; do
      grep -q -- "$a" "$REPO_ROOT/core/skills/ai-dlc/steps/$step.md" 2>/dev/null && hit=1 && break
    done
    [ "$hit" -eq 1 ] || err "I32: Check 17's '$hint' arm pins --require-skill '$skill', but steps/$step.md never names it (nor any superseded name for it). The gate then fails a correctly-executed run: the step invokes one skill and the pin demands another. Repoint whichever is stale — they are one fact in two files."
  done <<EOF
$arms
EOF
  # NON-VACUITY. Every guard above runs inside the loop, so an arm regex that stops matching
  # scans nothing and reports clean — which is the failure this whole check exists to end.
  [ "$n_bmad_arms" -gt 0 ] \
    || err "I32 matched no bmad-* skill pin in Check 17 at all. Either every arm lost its --require-skill, or the arm grammar changed and this check now compares nothing. 'Nothing to compare' must not read as 'the pins agree'."
fi

# --- I33: a fixture never reaches a core subtree by walking up from a RESOLVED script --
# THE DEFECT. `core/fixtures/story-provenance/run.sh` located the schema as
# `$(dirname "$WRITER")/../schemas/...`. That holds in the distribution, where the writer and
# the schema share a parent, and fails on EVERY consumer, where the install mapping splits
# them: core/scripts/<x> -> <root>/scripts/ai-dlc/<x> while core/schemas/ -> <root>/.claude/
# schemas/. The fixture was green here and red there, and because step 2 requires the derived
# fixtures green BEFORE the push, that red was a permanent stop on the consumer's self-update.
#
# The house pattern is already established and is not this: root the chain at the FIXTURE's own
# self-location and name both layouts explicitly (check-17-counts does), or ask the tool that
# owns the path (`stamp-story-provenance.sh --print-schema`). What must not happen is a second,
# private derivation hanging off a path some other resolver produced.
#
# MEASURED BEFORE WRITING: after the fix, this pattern occurs ZERO times across every
# core/fixtures/**/*.sh. The false-positive set is empty today, which is the only reason this
# is a check rather than a lint nobody can keep green. The subtree list is DERIVED from ls core/.
fx_walk_hits=""
fx_sh_count=0
if [ -d "$REPO_ROOT/core/fixtures" ]; then
  fx_sh_count="$(find "$REPO_ROOT/core/fixtures" -name '*.sh' -type f 2>/dev/null | wc -l | tr -d ' ')"
  for sub in $(ls -d "$REPO_ROOT"/core/*/ 2>/dev/null | sed 's|.*/core/||; s|/$||'); do
    [ "$sub" = "fixtures" ] && continue
    hits="$(grep -rlE "dirname \"\\\$[A-Za-z_][A-Za-z0-9_]*\"\)(/\.\.)+/$sub/" \
      "$REPO_ROOT/core/fixtures" --include='*.sh' 2>/dev/null || true)"
    [ -n "$hits" ] && fx_walk_hits="$fx_walk_hits $(echo $hits | sed "s|$REPO_ROOT/||g")"
  done
  if [ "$fx_sh_count" -eq 0 ]; then
    err "I33 found no *.sh under core/fixtures/ to scan. A scan over nothing reports clean, which is the shape this check exists to end."
  elif [ -n "$fx_walk_hits" ]; then
    err "I33: these fixtures reach a core subtree by walking up from a path another resolver produced:$fx_walk_hits. That parent-sharing holds in core/ and is broken by the install mapping on every consumer, so the fixture goes green here and red there — and step 2 turns a red derived fixture into a permanent stop on the self-update. Root the chain at the fixture's own self-location and name both layouts, or ask the tool that owns the path."
  fi
fi

# --- I33b: the same walk, with a VARIABLE in between --------------------------
# I33's grammar requires the `dirname` call and the `/..` walk in ONE expression. The
# defect does not: `core/fixtures/whole-read-pool/run.sh` shipped at v0.322.0 as
#
#     SCRIPTS_DIR="$(dirname "$VALIDATOR")"
#     SPRINT_SCHEMA="$SCRIPTS_DIR/../schemas/sprint-status.json"
#
# which is the identical defect one assignment apart, and I33's own pattern returns ZERO
# on that file. **A zero over the wrong grammar reads exactly like a clean tree** -- and
# I33's header records "this pattern occurs ZERO times" as its false-positive measurement,
# which was true of the single-expression form and blind to this one. Same shape as I54 ->
# I54b, where the pipeline form sat outside I54's grammar by construction.
#
# THE COST WAS PAID BEFORE IT WAS FOUND. The fixture was green in the distribution and
# exited 2 on the reference consumer, whose pre-push blocks on it -- so the consumer could
# not push without --no-verify, and the v0.322.0 pool arm that stops the locked-requirements
# move grading itself was unreachable on every consumer. The consumer filed it as PC-S326.
#
# MEASURED BEFORE SHIPPING: this form occurs ONCE across every core/fixtures/**/*.sh -- the
# file above -- and ZERO times after the fix. The false-positive set is empty.
# ONE PREDICATE, TWO CALLERS. The scan below and the probe beneath it call the SAME
# function. An earlier draft of this invariant inlined the detection twice -- so blinding
# the corpus scan left the probe passing against its own private copy, and the probe would
# have certified an instrument it never exercised. That is the "a check that cannot fire
# reads exactly like one that passed" class, arriving inside the guard against it.
i33b_scan() { # i33b_scan <file> -> one line per (file, variable) that walks up
  _f="$1"
  _vars="$(sed -n 's/^[[:space:]]*\([A-Za-z_][A-Za-z0-9_]*\)="\$(dirname "\$[A-Za-z_][A-Za-z0-9_]*")".*/\1/p' "$_f" 2>/dev/null | sort -u)"
  for _v in $_vars; do
    grep -qE "\\\$(\{)?${_v}(\})?/\.\./" "$_f" 2>/dev/null && printf '%s(%s)\n' "$_f" "\$$_v"
  done
}

# The probe proves BOTH directions in the same run, through the function the scan uses.
# A scanner that cannot see the two-step form reports the same clean line as a tree that
# does not use it; one that flags a dirname variable which never walks up would put every
# fixture's own $HERE/$DIR in the finding set. Built here, because a probe in the tree is
# a subject.
i33b_probe="$(mktemp -d 2>/dev/null)"
if [ -n "$i33b_probe" ] && [ -d "$i33b_probe" ]; then
  printf 'D="$(dirname "$TOOL")"\nS="$D/../schemas/x.json"\n' > "$i33b_probe/bad.sh"
  printf 'D="$(dirname "$TOOL")"\nS="$D/sibling.sh"\nH="$(dirname "$0")"\nR="$H/../../.."\n' > "$i33b_probe/ok.sh"
  i33b_pp="$(i33b_scan "$i33b_probe/bad.sh" | grep -c . || true)"
  i33b_pn="$(i33b_scan "$i33b_probe/ok.sh"  | grep -c . || true)"
  rm -rf "$i33b_probe"
  [ "$i33b_pp" -eq 0 ] && err "I33b's own positive probe was NOT reported: a two-step dirname-then-walk went unseen by the SAME function the scan below calls, so a clean result there would mean nothing. The invariant fails closed rather than reporting an absence its instrument could not have found."
  [ "$i33b_pn" -ne 0 ] && err "I33b's negative probe WAS reported: a dirname variable used WITHOUT walking up, or a fixture's own \$HERE-rooted chain, was flagged. Both are the house pattern I33 prescribes, and flagging them would put every fixture in the finding set."
else
  err "I33b could not create its probe directory, so neither direction of its scanner was proven this run."
fi

i33b_hits=""
if [ -d "$REPO_ROOT/core/fixtures" ]; then
  for _sf in $(find "$REPO_ROOT/core/fixtures" -name '*.sh' -type f 2>/dev/null | sort); do
    _r="$(i33b_scan "$_sf")"
    [ -n "$_r" ] && i33b_hits="$i33b_hits $(printf '%s' "$_r" | sed "s|$REPO_ROOT/||g" | tr '\n' ' ')"
  done
fi

if [ -n "${i33b_hits// /}" ]; then
  err "I33b: these fixtures reach a sibling subtree by walking up from a dirname VARIABLE:${i33b_hits}. I33 catches the one-expression form and this is the same defect one assignment apart -- true in core/, broken by the install mapping on every consumer (core/scripts/<x> -> scripts/ai-dlc/<x> while core/schemas/ -> .claude/schemas/). Root the chain at the fixture's own self-location and name BOTH layouts, the way sprint-status.sh:129-137 resolves this same schema."
fi

# --- I33c: a SELF-ROOTED walk must name BOTH layouts ---------------------------
# I33 AND I33b BOTH CHECK WHERE A CHAIN IS ROOTED, AND NEITHER CHECKS THAT BOTH LAYOUTS ARE
# NAMED. Rooting at the fixture's own location is the form both of them PRESCRIBE as the
# remedy -- "root the chain at the fixture's own self-location and name both layouts" -- and
# only the first half of that sentence has ever been mechanised. So a self-rooted chain
# naming ONE layout passes both invariants and is the identical consumer-side failure.
#
# THE DEFECT. v0.343.0 shipped `core/fixtures/apply-drift-after-write/seed.sh` with
#
#     _SCHEMA_SRC="$(cd "$(dirname "$0")/../.." && pwd)/schemas/layer-adjudication-register.json"
#
# which resolves in the distribution, where the seed and `core/schemas/` share the `core/`
# parent, and resolves nowhere on a consumer, where `install.sh` splits that parent:
# `core/fixtures/` -> `tests/fixtures/` at the project root while `core/schemas/` ->
# `.claude/schemas/`. The seed took its own FIXTURE BROKEN arm and exited 2 on every
# consumer -- and because step 2 requires the derived fixtures green BEFORE the push, that
# red is a permanent stop on the self-update. Reported by the reference consumer against the
# 0.341.0 -> 0.344.0 pull, and reproduced on a tree built by running install.sh into an
# empty directory.
#
# AND THE `cd … && pwd` SPELLING IS A THIRD ONE. I33's grammar wants the dirname and the
# walk in one expression; I33b's wants a variable in between. This form normalises through
# `cd`/`pwd`, so BOTH of them return zero on it -- the third appearance of "a zero over the
# wrong grammar reads exactly like a clean tree", after I33 -> I33b and I54 -> I54b.
#
# MEASURED BEFORE SHIPPING: across every core/fixtures/**/*.sh this grammar matches ONE
# file -- the one above -- and its false-positive set is EMPTY. After the fix it matches
# none, which is why the probe below is not optional: a corpus the grammar cannot match
# reports the same clean line as a corpus with nothing to find.
#
# ONE PREDICATE, TWO CALLERS, as I33b established. The probe and the corpus scan call the
# SAME function, or the probe certifies an instrument the scan never uses.
#
# COMMENTS ARE EXCLUDED, AND THAT NARROWING IS DERIVED FROM ONE MEASURED FALSE POSITIVE --
# this invariant's first run flagged the very file it had just fixed, because the fix's own
# comment QUOTES the defective expression to explain it. A scanner satisfied by its own
# documentation is the I87 narrowing arriving again; the same run that found it is why the
# filter is here rather than in a later release.
#
# ONE PATTERN, TWO USES, AND THE SECOND ONE IS WHY THIS IS NOT A NESTED LOOP. The first
# draft ran `i33c_scan` for every (subtree, fixture file) pair -- 8 x 210 = 1680 invocations,
# three processes each. Measured against the validator this invariant lives in: 13.0s before
# I33c, 18.1s after, a 39% regression on a program the enforcement-map fixtures re-run dozens
# of times per shard, and those shards are the fixture suite's POLE. It moved the suite's
# whole wall clock. The corpus scan below therefore does what I33 does -- one recursive grep
# per subtree to find CANDIDATE files -- and pays for the per-line refinement only on files
# that already matched, which today is none.
i33c_pat() { # i33c_pat <subtree> -> the ERE, defined once and used by both callers
  printf '(dirname "\\$0"\\)(/\\.\\.)+/%s/|cd "\\$\\(dirname "\\$0"\\)(/\\.\\.)+" && pwd\\)/%s/)' "$1" "$1"
}
i33c_scan() { # i33c_scan <file> <subtree> -> the offending line(s), if any
  grep -nE "$(i33c_pat "$2")" "$1" 2>/dev/null \
    | grep -vE '^[0-9]+:[[:space:]]*#' \
    | grep -vE '\.claude/'"$2"'/'
}

i33c_subs="$(ls -d "$REPO_ROOT"/core/*/ 2>/dev/null | sed 's|.*/core/||; s|/$||' | grep -v '^fixtures$')"
if [ -z "$i33c_subs" ]; then
  err "I33c derived NO core subtree to scan for, so its corpus scan could only report clean. The subtree list is derived from ls core/ and an empty one is an instrument failure, not a pass."
fi

# BOTH DIRECTIONS, through the scan's own function. A grammar blind to the cd/pwd spelling
# reports the same clean line as a fixed tree; one that flags a chain which DOES name the
# consumer layout would flag the remedy this invariant prescribes.
i33c_probe="$(mktemp -d 2>/dev/null)"
if [ -n "$i33c_probe" ] && [ -d "$i33c_probe" ]; then
  printf 'S="$(cd "$(dirname "$0")/../.." && pwd)/schemas/x.json"\n' > "$i33c_probe/bad1.sh"
  printf 'S="$(dirname "$0")/../../schemas/x.json"\n'                 > "$i33c_probe/bad2.sh"
  printf 'H="$(cd "$(dirname "$0")" && pwd)"\nfor c in "$H/../../schemas/x.json" "$H/../../../.claude/schemas/x.json"; do :; done\n' > "$i33c_probe/ok.sh"
  i33c_p1="$(i33c_scan "$i33c_probe/bad1.sh" schemas | grep -c . || true)"
  i33c_p2="$(i33c_scan "$i33c_probe/bad2.sh" schemas | grep -c . || true)"
  i33c_pn="$(i33c_scan "$i33c_probe/ok.sh"   schemas | grep -c . || true)"
  rm -rf "$i33c_probe"
  [ "$i33c_p1" -eq 0 ] && err "I33c's cd/pwd positive probe was NOT reported. That is the exact spelling v0.343.0 shipped, and the one I33 and I33b are both blind to, so a clean corpus result would mean nothing."
  [ "$i33c_p2" -eq 0 ] && err "I33c's direct-walk positive probe was NOT reported, so the grammar covers only one of the two self-rooted spellings."
  [ "$i33c_pn" -ne 0 ] && err "I33c's negative probe WAS reported: a self-rooted chain that DOES name the consumer layout was flagged. That is the remedy this invariant prescribes, and flagging it would make the check unsatisfiable."
else
  err "I33c could not create its probe directory, so neither direction of its scanner was proven this run."
fi

i33c_hits=""
if [ -d "$REPO_ROOT/core/fixtures" ]; then
  for _sub in $i33c_subs; do
    # CANDIDATES first, one recursive grep per subtree. The refinement below (comment lines,
    # a consumer candidate on the same line) is per-line and only a matched file can need it.
    for _sf in $(grep -rlE "$(i33c_pat "$_sub")" "$REPO_ROOT/core/fixtures" --include='*.sh' 2>/dev/null | sort); do
      _r="$(i33c_scan "$_sf" "$_sub")"
      [ -n "$_r" ] && i33c_hits="$i33c_hits $(printf '%s' "${_sf#$REPO_ROOT/}" )"
    done
  done
fi
if [ -n "${i33c_hits// /}" ]; then
  err "I33c: these fixtures walk up from their OWN location into a core subtree while naming only the DISTRIBUTION layout:${i33c_hits}. Self-rooting is what I33 and I33b prescribe and it is only half the remedy -- install.sh splits the parent (core/fixtures/ -> tests/fixtures/ at the project root, core/schemas/ -> .claude/schemas/), so the fixture is green here and exits nonzero on every consumer, which step 2 turns into a permanent stop on the self-update. Add the consumer candidate beside the distribution one, as apply-drift-after-write/seed.sh now does."
fi

# --- I20: every fixture is DRIVEN, or declares in writing that it cannot be -----
# core/git-hooks/pre-push runs the fixture suite as
#
#     for d in tests/fixtures/*/; do
#       [ -f "$d/run.sh" ] || continue
#
# directly beneath the comment "a fixture never driven is a green light nobody earned."
# A fixture with no run.sh is therefore SKIPPED on every push, silently, while still
# being declared an adversarial self-test in the map. check-1c-bypass and
# check-15-bypass sat in that hole for their entire existence: both were `echo`
# statements describing artifacts they never created, both were bound to a check, and
# no gate, hook or suite could tell them from fixtures that passed.
#
# The hole is structural, not a property of those two — the NEXT driverless fixture
# disappears the same way. So require, of every fixture on disk: a run.sh, or a README
# that states plainly why one is impossible. Two fixtures legitimately cannot have one
# (check-h1-recursion tests an LLM's control flow; check-manifest-bypass tests an LLM's
# read of loaded context — no script observes either), and the exemption is DERIVED
# from each README rather than hand-listed here, because a hand-list is the shape that
# rots: the list itself becomes the thing nobody updates.
#
# Scope: this validator is a dev-repo gate (not installed, not called by pre-push), so
# I20 binds fixtures where they are AUTHORED. A fixture that reaches a consumer without
# a driver has already passed through here.
EXEMPT_MARKER='No `run.sh`, deliberately'
for d in "$REPO_ROOT"/core/fixtures/*/; do
  [ -d "$d" ] || continue
  name="${d%/}"; name="${name##*/}"
  [ -f "$d/run.sh" ] && continue
  if [ ! -f "$d/README.md" ]; then
    err "I20 fixture '$name' has neither run.sh nor a README. pre-push skips it silently, so it is indistinguishable from a fixture that passed. Add a driver, or a README stating why one is impossible (marker: '$EXEMPT_MARKER')."
    continue
  fi
  grep -qF "$EXEMPT_MARKER" "$d/README.md" \
    || err "I20 fixture '$name' has no run.sh and its README does not declare the exemption. pre-push skips it silently ('[ -f \"\$d/run.sh\" ] || continue'), so it reads exactly like a fixture that passed. Add a driver, or state why one is impossible with the marker '$EXEMPT_MARKER' and the reason."
done

# --- I21: ONE home for the reconcile helpers, and nothing may grow a second.
#
# `section_of()` is THE section resolver the drift classifiers share, and its divergence
# has already SHIPPED TWICE:
#
#   v0.52.0 — readopt-override's copy was WEAKER than layer-drift's, so it could not
#             resolve the anchor layer-drift had just blocked on, found no stale lines,
#             and would have CLEARED the block.
#   v0.54.2 — register-drift's copy was STRICTER, so it misfiled a renamed section
#             (`## Escalation Protocol` vs core's `## Escalation`) as an ADDITION, which
#             would have rendered core's heading and the consumer's side by side.
#
# Both times the remedy was to hand-copy one body over the other, and both times the
# CHANGELOG recorded "there is one resolver" while nothing MADE it one — so the copies
# drifted again. v0.90.0 finally collapsed all three into reconcile/lib.sh, which the
# three classifiers now source. That fixed the INSTANCES. It did not fix the HOLE:
# nothing stops a fourth file from inlining its own `section_of()` tomorrow, and the
# failure mode is silent by construction — a private copy runs, resolves differently,
# and the tool reports a confident verdict computed from the wrong section.
#
# Same shape as I19, and the same remedy: where the duplicate MUST exist the copies are
# bound (I15, I18); here it must not exist at all, so assert it does not come back rather
# than binding a copy into permanence.
#
# The helper set is DERIVED from lib.sh's own definitions, never hand-listed — a
# hand-list is the thing that stops being updated (I8's site table, I12's scan set).
# Two failures, because a helper can go wrong in two directions: a file that REDEFINES
# it has a private copy that can drift, and a file that CALLS it without sourcing lib.sh
# has a call that cannot resolve at all.
RLIB="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"
if [ ! -f "$RLIB" ]; then
  err "I21 cannot find core/skills/ai-dlc-update/reconcile/lib.sh. The check that keeps the shared drift helpers single-homed just went vacuous — it must locate the library or fail loudly, never pass by finding nothing to bind."
else
  lib_fns="$(sed -n 's/^\([a-z_][a-z0-9_]*\)() {.*/\1/p' "$RLIB")"
  if [ -z "$lib_fns" ]; then
    err "I21 found no function definitions in reconcile/lib.sh. Either the library was emptied or its definition form changed; either way the no-second-copy assertion is now testing nothing and would pass against a tree with four resolvers in it."
  else
    # ONE awk pass per file, not two greps per (file, helper) pair. The predicates are
    # transcribed unchanged — same comment stripping, same two regexes, same
    # define-beats-call precedence — and the reporting loop below still walks lib_fns in
    # lib.sh's own order inside the glob's file order, so the messages and the sequence
    # they appear in are identical. This is a fork count, not a subject set: on today's
    # tree the old shape forked ~600 greps here.
    for f in "$REPO_ROOT"/core/skills/ai-dlc-update/reconcile/*.sh; do
      [ -f "$f" ] || continue
      fbase="${f##*/}"
      [ "$fbase" = "lib.sh" ] && continue
      # Comment lines are stripped: every classifier documents WHY it sources lib.sh,
      # and a check that reads its own documentation as a violation is a check that
      # gets switched off.
      # Space-joined, not newline-joined: BSD awk rejects a literal newline inside a -v
      # value, and the failure is 144 lines of parse noise on stderr rather than a wrong
      # answer -- but a check whose helper set arrives empty would report nothing at all.
      seen="$(awk -v fns="$(printf '%s ' $lib_fns)" '
        BEGIN { n = split(fns, F, " ") }
        /^[[:space:]]*#/ { next }
        {
          if ($0 ~ /lib\.sh/) srcs = 1
          for (i = 1; i <= n; i++) {
            if (F[i] == "") continue
            if ($0 ~ "^[[:space:]]*" F[i] "\\(\\)[[:space:]]*\\{") D[F[i]] = 1
            else if ($0 ~ "(^|[^a-zA-Z0-9_])" F[i] "([^a-zA-Z0-9_]|$)") C[F[i]] = 1
          }
        }
        END {
          print "SOURCES\t" (srcs ? 1 : 0)
          for (i = 1; i <= n; i++) if (F[i] != "") print F[i] "\t" (D[F[i]] ? 1 : 0) "\t" (C[F[i]] ? 1 : 0)
        }
      ' "$f")"
      sources_lib=0
      case "$seen" in SOURCES$'\t'1*) sources_lib=1 ;; esac
      for fn in $lib_fns; do
        row="${seen#*$'\n'"$fn"$'\t'}"; row="${row%%$'\n'*}"
        case "$row" in
          1*)
            err "I21 reconcile/$fbase defines its own ${fn}(), but reconcile/lib.sh is its ONE home. A private copy is exactly the shape that shipped divergent resolvers in v0.52.0 and v0.54.2: each tool reports a confident verdict computed from a different section, and no run compares them. Delete the local definition and source lib.sh." ;;
          0$'\t'1)
            [ "$sources_lib" -eq 0 ] \
              && err "I21 reconcile/$fbase calls ${fn}() but never sources reconcile/lib.sh. The call resolves to nothing at runtime, and these scripts run on a consumer's pull — where the resulting empty section reads as 'no drift' rather than as an error. Add: . \"\$SELF/lib.sh\"" ;;
        esac
      done
    done
  fi
fi

# --- I22: every role has a config entry, and every entry resolves.
#
# The role file no longer states a model or an effort — `aiDlcRoles.<role>` in the
# consumer's settings.json does, and `ai-dlc-dispatch-guard.sh` reads it there. Two
# ways that can be silently wrong, and the guard FAILS OPEN on both, so neither
# announces itself at runtime:
#
#   1. A role file with no `aiDlcRoles` entry. The guard finds no model and no effort
#      and binds nothing; that teammate runs on whatever it inherits.
#   2. An entry whose `model` names a key `aiDlcModels` does not define. The key does
#      not resolve, so again nothing is bound.
#
# Both sides are DERIVED — role files off disk, entries out of the shipped template —
# because a hand-maintained list is this repo's recurring bug (I8's site table, I12's
# scan set, and I22's own two earlier escapes).
attr_of() { # attr_of <newline-prefixed "key<TAB>model<TAB>effort" rows> <key> <2|3>
  local rows="$1" key="$2" n="$3" row
  case "$rows" in *"
$key	"*) ;; *) return 0 ;; esac
  row="${rows#*"
$key	"}"; row="${row%%
*}"
  if [ "$n" = 2 ]; then printf '%s' "${row%%	*}"; else printf '%s' "${row#*	}"; fi
}

if [ ! -f "$SETTINGS_TMPL" ]; then
  err "I22 cannot find templates/settings.json.template. The check that keeps every role's model and effort resolvable just went vacuous — it must locate the shipped config or fail loudly, never pass by finding nothing to compare."
else
  role_files="$( { for _f in "$REPO_ROOT"/core/team-roles/*.md; do [ -f "$_f" ] || continue; _f="${_f##*/}"; printf '%s\n' "${_f%.md}"; done; } 2>/dev/null | sort -u)"
  declared="$(jq -r '.aiDlcRoles // {} | keys[]' "$SETTINGS_TMPL" 2>/dev/null | sort -u)"
  model_keys="$(jq -r '.aiDlcModels // {} | keys[]' "$SETTINGS_TMPL" 2>/dev/null | sort -u)"

  if [ -z "$role_files" ]; then
    err "I22 found no role files in core/team-roles/. Either the directory moved or it was emptied; either way this assertion is testing nothing."
  elif [ -z "$declared" ]; then
    err "I22 templates/settings.json.template declares no aiDlcRoles entries. Every role would dispatch with no model and no effort bound, silently, because ai-dlc-dispatch-guard.sh fails open on a missing entry. Restore the block."
  elif [ -z "$model_keys" ]; then
    err "I22 templates/settings.json.template declares no aiDlcModels keys, so no role's model can resolve. Restore the block."
  else
    for r in $role_files; do
      grep -qx "$r" <<<"$declared" \
        || err "I22 core/team-roles/$r.md ships but templates/settings.json.template has no aiDlcRoles entry for '$r'. A consumer installing fresh gets a role with no model and no effort; the dispatch guard fails open and that teammate runs on whatever it inherits. Add the entry."
    done
    # Every entry's model (when it has one — the party personas legitimately have an
    # effort and no model) must be a key aiDlcModels defines.
    #
    # One jq for the whole block instead of one per role, and the membership test moved
    # into the shell. Same two fields off the same file; the loops below still walk
    # `declared` (jq's sorted key order) so the errors keep their order.
    role_attrs="
$(jq -r '.aiDlcRoles // {} | to_entries[] | "\(.key)\t\(.value.model // "")\t\(.value.effort // "")"' "$SETTINGS_TMPL" 2>/dev/null)"
    model_nl="
$model_keys
"
    for r in $declared; do
      k="$(attr_of "$role_attrs" "$r" 2)"
      [ -n "$k" ] || continue
      case "$model_nl" in
        *"
$k
"*) ;;
        *) err "I22 aiDlcRoles.$r names model key '$k' but aiDlcModels does not define it. The key does not resolve, so ai-dlc-dispatch-guard.sh binds no model for that role and takes its fail-open branch. Add the key, or point the role at one that exists." ;;
      esac
    done
    # Effort is injected into the dispatch prompt as a `/effort <level>` directive, so
    # an unrecognised level would instruct a teammate to run a command that does not
    # exist. The guard drops one rather than passing it through; catch it here instead
    # of shipping a value that is silently ignored.
    for r in $declared; do
      e="$(attr_of "$role_attrs" "$r" 3)"
      [ -n "$e" ] || continue
      case "$e" in
        low|medium|high|xhigh|max) ;;
        *) err "I22 aiDlcRoles.$r declares effort '$e', which is not one of low/medium/high/xhigh/max. ai-dlc-dispatch-guard.sh drops an unrecognised level rather than injecting a directive for a command that does not exist, so that role would silently run at the session default." ;;
      esac
    done
  fi
fi

# --- I22b: the guard reads the blocks the template actually ships ---------------
# I22 checks the CONTENT of the config. Nothing checked that the guard still looks
# where that content lives. The hook resolves two top-level blocks by name; rename
# either in the template (or in the hook) and the lookups return empty, the guard
# takes its fail-open branch, and EVERY role dispatches unbound — with the suite
# green, because every other assertion here reads the template directly and would
# still pass. Bind the two ends: the block names are read OUT OF THE HOOK, never
# restated, and must exist in the shipped template.
DG_HOOK="$REPO_ROOT/core/hooks/ai-dlc-dispatch-guard.sh"
if [ ! -f "$DG_HOOK" ]; then
  err "I22b cannot find core/hooks/ai-dlc-dispatch-guard.sh."
elif [ ! -f "$SETTINGS_TMPL" ]; then
  : # I22 already reported the missing template
else
  blocks="$(grep -oE "\.aiDlc[A-Za-z]+\[" "$DG_HOOK" | sed 's/^\.//; s/\[$//' | sort -u)"
  if [ -z "$blocks" ]; then
    err "I22b found no .aiDlc*[...] lookup in ai-dlc-dispatch-guard.sh. Either the hook stopped reading its config or the lookup changed shape; either way this assertion can no longer tell which blocks the guard depends on and would pass without comparing anything."
  else
    for b in $blocks; do
      jq -e --arg b "$b" 'has($b)' "$SETTINGS_TMPL" >/dev/null 2>&1 \
        || err "I22b ai-dlc-dispatch-guard.sh reads the '$b' block but templates/settings.json.template does not ship one. Every lookup against it returns empty, the guard fails open, and every role dispatches with nothing bound — silently. Rename one end or the other, not just one."
    done
  fi
fi

# --- I24: H1's fixture set stays DERIVED, never restated in gate-validation.md --
# H1 used to carry a hand-typed check->fixture enumeration. It listed 7 checks while
# the map bound 11, so four checks shipped fixtures H1 could not see and the omission
# read exactly like coverage. The list is gone and the map is the single source; this
# asserts it does not grow back, and that every fixture the map names is one a check
# actually claims.
H1_SPAN="$(awk '/<!-- CHECK_LOADED: H1 -->/{on=1} on{print} on && /<!-- CHECK_LOADED: H2 -->/{exit}' \
  "$REPO_ROOT/core/skills/ai-dlc/steps/gate-validation.md" 2>/dev/null)"
if [ -z "$H1_SPAN" ]; then
  err "I24 could not isolate the H1 span in gate-validation.md. A span that does not resolve scans nothing and reports clean."
else
  # H1's OWN fixture is exempt: it proves H1's manifest-completeness pass, so naming it
  # is a self-test reference, not a restatement of the coverage set H1 reads from the map.
  # Derived from the map's H1 entry, never hand-listed here.
  own_fx="$(awk '/^  - id: "H1"/{on=1} on && /fixtures:/{print; exit}' \
    "$REPO_ROOT/core/skills/ai-dlc/enforcement-map.yaml" | grep -oE 'tests/fixtures/[a-z0-9-]+' | sort -u)"
  restated="$(printf '%s\n' "$H1_SPAN" | grep -oE 'tests/fixtures/[a-z0-9-]+' | sort -u \
    | { [ -n "$own_fx" ] && grep -vxF "$own_fx" || cat; })"
  if [ -n "$restated" ]; then
    err "I24 the H1 check body names fixture path(s) directly: $(echo $restated). H1's check->fixture set is derived from enforcement-map.yaml's \`fixtures:\` bindings; a path restated here is the hand-maintained list growing back, and it is what let Checks 2, 2a, 25 and 26 ship fixtures H1 could not see. Cite the map, not the path. (H1's own bound fixture is exempt.)"
  fi
  # And the reverse direction: a fixture bound in the map must exist on disk. I4 already
  # covers this for enforcer paths; this closes it for the fixture bindings H1 now reads.
  for fx in $(grep -oE 'tests/fixtures/[a-z0-9-]+' "$REPO_ROOT/core/skills/ai-dlc/enforcement-map.yaml" | sed 's|tests/fixtures/||' | sort -u); do
    [ -d "$REPO_ROOT/core/fixtures/$fx" ] \
      || err "I24 enforcement-map.yaml binds fixture '$fx' but core/fixtures/$fx does not exist. H1 reads these bindings as its coverage set, so a dangling one is a check reporting coverage it does not have."
  done
fi

# --- I23: every SHIPPED rule-prose file is in the audit corpus -----------------
# audit-rule-files.sh enforces Rule 18 and rule-authoring.md over a corpus it
# builds itself. Nothing compared that corpus to the set install.sh delivers, so
# a rule file could ship to every consumer while being scanned by nothing, and
# the audit would report CLEAN over it. Both sides are DERIVED: the shipped set
# from install.sh's own copy paths, the corpus from `--list`.
AUDIT_SH="$REPO_ROOT/core/scripts/audit-rule-files.sh"
INSTALL_SH="$REPO_ROOT/scripts/install.sh"
if [ ! -f "$AUDIT_SH" ] || [ ! -f "$INSTALL_SH" ]; then
  err "I23 cannot run: audit-rule-files.sh or install.sh is missing. A skipped corpus check reads exactly like a covered corpus."
else
  corpus_list="$(cd "$REPO_ROOT" && bash core/scripts/audit-rule-files.sh --list 2>/dev/null | sort -u)"
  if [ -z "$corpus_list" ]; then
    err "I23 audit-rule-files.sh --list returned nothing from the distribution root. The corpus builder cannot see the distribution layout, so every class it reports is scanned over zero files."
  else
    rule_prose="$(cd "$REPO_ROOT" && ls core/skills/ai-dlc/*.md core/skills/ai-dlc/steps/*.md \
                    core/skills/ai-dlc/templates/*.md core/skills/ai-dlc/extensions/*.md \
                    core/skills/ai-dlc/overrides/*.md core/team-roles/*.md \
                    core/skills/ai-dlc-setup/SKILL.md core/skills/ai-dlc-update/SKILL.md \
                    core/skills/ai-dlc-update/reconcile/*.md patterns/*.md 2>/dev/null | sort -u)"
    # install.sh and the corpus list are read ONCE and matched in the shell. `grep -qF`
    # is a fixed-string containment test and so is bash's `*"$s"*`; `grep -qx` against a
    # path is a whole-line match. Same two questions, ~300 fewer forks over today's corpus.
    install_txt="$(cat "$INSTALL_SH")"
    corpus_nl="
$corpus_list
"
    unshipped=""
    for rp in $rule_prose; do
      base="${rp##*/}"; dir="${rp%/*}"
      # A skill-root file is matched by basename only: every skill-root path shares
      # the `core/skills/ai-dlc/` prefix, so a directory match there would call the
      # whole directory shipped and the check would assert nothing.
      if [ "$dir" = "core/skills/ai-dlc" ]; then
        case "$install_txt" in *"$base"*) ;; *) unshipped="$unshipped $rp"; continue ;; esac
      else
        case "$install_txt" in
          *"$dir/"*) ;;
          *"$base"*) ;;
          *) unshipped="$unshipped $rp"; continue ;;
        esac
      fi
      case "$corpus_nl" in
        *"
$rp
"*) ;;
        *) err "I23 $rp is installed into every consumer but is absent from the audit-rule-files.sh corpus. Rule 18 and rule-authoring.md are unenforced over it, and the audit reports CLEAN having never opened it. Add it to the corpus builder." ;;
      esac
    done
    for rp in $unshipped; do
      echo "  note: $rp is a rule-prose file that install.sh never ships; it is correctly outside the audit corpus." >&2
    done
  fi
fi

# --- I30: the two pre-push syntax globs are one set, mapped ---------------------
# vocabulary: pre-push shell-syntax globs
# vocabulary-invariant: I30
# vocabulary-owner: .githooks/pre-push
# vocabulary-extract: syntax-globs
# vocabulary-readers: core/git-hooks/pre-push
# A shipped script with a syntax error is a gate that cannot run at all, so both hooks
# run `bash -n` over every class of shipped script. The two lists are the same set
# expressed in two layouts, and nothing compared them: core validators moved to
# scripts/ai-dlc/ in v0.126.0, the distribution glob followed, the consumer glob did
# not. For four releases no shipped core validator -- and no part of the update engine
# that would deliver the fix -- was syntax-checked on any consumer, while the step
# printed the same green line either way.
#
# DERIVE the consumer set from the distribution set through the same map_consumer()
# apply.sh uses, and compare. A hand-kept pair is the bug; the pair is derivable.
syn_globs() { # <hook file> -> one glob per line, from the sentinel-bounded block
  # Join backslash continuations FIRST. A line-at-a-time reader drops every entry
  # after the first wrap, and it drops them from BOTH hooks alike -- so the compare
  # succeeds on two equally-truncated sets and reports agreement it never tested.
  # That is the exact vacuity this invariant is here to prevent, so it must not be
  # the way this invariant is implemented.
  sed -n '/# SYNTAX_GLOB_BEGIN/,/# SYNTAX_GLOB_END/p' "$1" \
    | awk '{ if (sub(/\\$/,"")) { printf "%s", $0 } else { print } }' \
    | sed -n 's/.*for f in \(.*\); *do.*/\1/p' \
    | tr -s ' \t' '\n' | grep -E '\*' | sort -u
}
if [ ! -f "$PP_DIST" ] || [ ! -f "$PP_CONS" ]; then
  err "I30 could not read one of the pre-push hooks (dist='$PP_DIST' consumer='$PP_CONS'). With one end missing this invariant compares nothing and prints the same line as a pass."
else
  syn_dist="$(syn_globs "$PP_DIST")"
  syn_cons="$(syn_globs "$PP_CONS")"
  if [ -z "$syn_dist" ] || [ -z "$syn_cons" ]; then
    err "I30 parsed ZERO globs out of the syntax_all() block in $( [ -z "$syn_dist" ] && echo '.githooks/pre-push' || echo 'core/git-hooks/pre-push' ). The SYNTAX_GLOB_BEGIN/END sentinels or the \`for f in\` shape changed. An empty set compares equal to an empty set, so this invariant fails closed rather than reporting agreement it never checked."
  else
    # map_consumer(), same rules as reconcile/preclassify.sh:66-75.
    syn_expect="$(printf '%s\n' "$syn_dist" | sed -E '
      s@^core/scripts/@scripts/ai-dlc/@;
      s@^core/fixtures/@tests/fixtures/@;
      s@^core/ci-templates/@.github/workflows/@;
      s@^core/git-hooks/@.githooks/@;
      s@^core/@.claude/@' | sort -u)"
    if [ "$syn_expect" != "$syn_cons" ]; then
      only_dist="$(comm -23 <(printf '%s\n' "$syn_expect") <(printf '%s\n' "$syn_cons") | tr '\n' ' ')"
      only_cons="$(comm -13 <(printf '%s\n' "$syn_expect") <(printf '%s\n' "$syn_cons") | tr '\n' ' ')"
      err "I30 the pre-push syntax globs have forked. Classes the distribution checks but no consumer does:${only_dist:- <none>}. Classes only the consumer checks:${only_cons:- <none>}. A class missing from the consumer hook is a class of shipped script that reaches every consumer with no syntax check, and the step prints the same green line as a full scan. Update core/git-hooks/pre-push's SYNTAX_GLOB block to the mapped image of the distribution's."
    fi
  fi
fi

# --- I66: ONE fixture-suite runner across both pre-push hooks ------------------
# I30 above joins the two hooks on the SYNTAX glob and has done since v0.126.x. The
# suite runner beside it was joined by nothing, and it forked for the project's whole
# history: the distribution ran its fixtures through a worker pool with a completeness
# assertion and an empty-suite guard, while the file install.sh copies into every
# consumer ran a serial `for` loop that returned 0 when the glob matched nothing AND
# when no directory carried a run.sh. Measured on the reference consumer before
# v0.226.0: 3 `xargs -P` here against 0 there, 5 completeness lines against 0, 1
# empty-suite guard against 0 -- and `cmp -s` said the consumer's installed hook was
# byte-identical to what core ships, so the consumer was running exactly that. Its
# suite passed when it ran nothing, in the one gate a consumer actually has.
#
# The consumer could not fix it either: install.sh:445 marks the hook "always
# overwrite -- upstream-owned", so a consumer-side pool is deleted at the next pull
# with nothing reporting the regression. That is what makes this a JOIN rather than
# advice.
#
# THE COMPARISON IS ON EXECUTABLE LINES ONLY, and that is the load-bearing choice.
# The two hooks' prose is deliberately different -- one addresses a maintainer of this
# repo, the other a consumer who must re-derive the pool size on their own box -- so
# requiring byte-identity of the whole block would force one of those audiences to
# read the other's measurements. Comments are therefore stripped before the diff.
# I64's finding is why the strip runs in this direction rather than the other: a join
# a COMMENT can satisfy is no join at all, because the token is present and the
# mechanism is absent. Here the comment is what may differ and the code is what may
# not, so nothing a comment says can make this invariant pass.
#
# The only permitted difference is the fixture root, which the install layout defines:
# core/fixtures/ here, tests/fixtures/ there. It is mapped, not exempted -- a block
# that differed anywhere else would still be reported.
# THE SENTINEL MATCH IS ANCHORED, and the mutant that made it so is worth stating.
# Written unanchored -- `/# FIXTURE_POOL_BEGIN/` -- the address still matches
# `# FIXTURE_POOL_BEGINS`, so renaming the sentinel extracted the block anyway and
# the zero guard below could never be reached by that mutation. The guard read as
# correct and was unreachable: this file's own recurring class, produced while
# building the check that names it. Anchoring is what makes a renamed sentinel
# extract EMPTY, which is the state the guard exists to refuse.
fx_pool_block() {
  sed -n '/^# FIXTURE_POOL_BEGIN$/,/^# FIXTURE_POOL_END$/p' "$1" \
    | grep -vE '^[[:space:]]*#' | grep -vE '^[[:space:]]*$'
}
if [ ! -f "$PP_DIST" ] || [ ! -f "$PP_CONS" ]; then
  err "I66 could not read one of the pre-push hooks (dist='$PP_DIST' consumer='$PP_CONS'). With one end missing this invariant compares nothing and prints the same line as a pass."
else
  fx_dist="$(fx_pool_block "$PP_DIST")"
  fx_cons="$(fx_pool_block "$PP_CONS")"
  # ZERO GUARD, and it is the same one I30 needs: two empty extractions compare EQUAL,
  # so a renamed sentinel would report agreement this invariant never tested. Fail
  # closed on either end being empty rather than reporting a match between nothings.
  if [ -z "$fx_dist" ] || [ -z "$fx_cons" ]; then
    err "I66 parsed ZERO executable lines out of the FIXTURE_POOL block in $( [ -z "$fx_dist" ] && echo '.githooks/pre-push' || echo 'core/git-hooks/pre-push' ). The FIXTURE_POOL_BEGIN/END sentinels moved or the block became comment-only. An empty set compares equal to an empty set, so this invariant fails closed rather than reporting agreement it never checked."
  else
    fx_expect="$(printf '%s\n' "$fx_dist" | sed 's|core/fixtures/|tests/fixtures/|g')"
    if [ "$fx_expect" != "$fx_cons" ]; then
      fx_diff="$(diff <(printf '%s\n' "$fx_expect") <(printf '%s\n' "$fx_cons") | sed -n '1,12p' | tr '\n' ' ')"
      err "I66 the two pre-push fixture-suite runners have forked. Mapped diff (distribution expected, consumer actual): ${fx_diff:-<none>}. The consumer hook is the ONLY fixture gate a consumer has and install.sh always overwrites it, so a runner that loses the pool, the empty-suite guard or the verdict-completeness assertion here reaches every consumer and cannot be repaired downstream. Bring core/git-hooks/pre-push's FIXTURE_POOL block to the mapped image of the distribution's."
    fi
  fi
fi

# --- I67: the crosswalk file is ONE string, and no reader restates it ----------
# THE DEFECT IT REPLACES, measured. LC-N6 is an ERROR whose only compliant output was a row
# in `extensions/README.md` — a file the distribution ships, `install.sh` scaffolds and
# `unregistered-drift.sh` compares against base. The reference consumer's migration wrote
# nineteen rows there and earned a permanent `HARD-UNREGISTERED-CORE-DRIFT` whose two printed
# remedies respectively DELETE the rows and file them where no reader looks. Relocating the
# table fixes that, and relocating it is exactly the change that creates a new hand-copied
# path: the validator reads it, the installer scaffolds it, and ai-dlc-update's own manifest
# names it. Three spellings and nothing comparing them is I43's defect one release later.
#
# BOTH DIRECTIONS, and the reverse one is again the one that matters:
#   forward  the two declarations agree. Catches a rename in one surface.
#   reverse  NEITHER the validator nor the installer carries the literal path. A reader that
#            hard-codes it passes the forward arm forever while the declaration drifts under
#            it, which is precisely how `CROSSWALK_MD="$EXT_DIR/README.md"` survived.
ccf_decl() { # <file> -> the declared crosswalk file, trailing whitespace stripped
  sed -n 's/^consumer_crosswalk_file:[[:space:]]*//p' "$1" | head -1 | sed 's/[[:space:]]*$//'
}
CCF="$(ccf_decl "$LC_YAML")"
CCF_SS="$(ccf_decl "$SETUP_SITES")"
CCF_READERS="$REPO_ROOT/core/scripts/validate-layer-entries.sh $REPO_ROOT/scripts/install.sh $REPO_ROOT/core/skills/ai-dlc-update/reconcile/apply.sh"

if [ -z "$CCF" ] || [ -z "$CCF_SS" ]; then
  err "I67 could not read 'consumer_crosswalk_file:' from layer-contract.yaml and/or reconcile/setup-sites.md (got '${CCF:-<none>}' and '${CCF_SS:-<none>}'). Both copies are required: the validator reads the contract's, ai-dlc-update cannot read pipeline files and reads its own, and an absent declaration leaves the two ends bound by nothing while this check reports the same line as agreement."
elif [ "$CCF" != "$CCF_SS" ]; then
  err "I67 the declared crosswalk file differs between its two declarations — layer-contract.yaml says '$CCF', reconcile/setup-sites.md says '$CCF_SS'. The validator would read one path while the updater reasoned about another, and a consumer's rows would sit in a file nothing enforces against."
else
  # Reverse: no reader may carry the literal. The declaration lines themselves are the only
  # place the string is allowed to appear, and neither reader is one of those files.
  ccf_hard="$(grep -lF -- "$CCF" $CCF_READERS 2>/dev/null || true)"
  if [ -n "$ccf_hard" ]; then
    err "I67 the declared crosswalk path '$CCF' appears LITERALLY in $(echo $ccf_hard). Every reader must derive it from the declaration; one that restates it passes the agreement arm above forever while the declaration moves out from under it, which is exactly how the hard-wired \`CROSSWALK_MD=\"\$EXT_DIR/README.md\"\` outlived the ownership model it broke."
  fi
  # Zero guard: the readers must actually READ the key, or "no literal" is satisfied by a
  # file that has nothing to do with the crosswalk at all.
  for _r in $CCF_READERS; do
    grep -qF 'consumer_crosswalk_file:' "$_r" 2>/dev/null || \
      err "I67 $(basename "$_r") does not read 'consumer_crosswalk_file:' at all. The no-literal arm above is satisfied by a reader that resolves the path some third way just as well as by one that derives it, so the read is asserted rather than assumed."
  done
fi

# --- I68: core's own shipped files yield ZERO crosswalk rows -------------------
# THE DEFECT THIS ENDS, and it had shipped for as long as the table existed. The crosswalk
# reader harvests column 1 of every pipe table in the file it is given, deliberately not
# scoped to a heading — and it did not skip fenced blocks. Core's `extensions/README.md`
# carries a worked example: two rows inside a ``` fence and one live row in the table. All
# three were harvested, so EVERY consumer inherited a crosswalk row for `24` without an
# operator ever writing one, and E16 could not fire on that id in any tree. A worked example
# that satisfies the clause it illustrates is a check that cannot fire for its subject.
#
# The subject is every file CORE ships that the reader is ever pointed at: the retired
# location and the scaffold a new consumer starts from. Derived from the declaration rather
# than hand-listed, so a third such file cannot appear without entering this set.
#
# THE ZERO CARRIES ITS CONTROL IN THE SAME RUN. An extractor that stopped matching reads zero
# on a file full of rows and is indistinguishable from core being clean, so each subject is
# re-read with one unfenced row appended and must then yield exactly one.
cw_harvest() { # cw_harvest <file> -> count of ids the shipping reader would take
  awk -F'|' '
    /^[[:space:]]*```/ { fence = !fence; next }
    fence { next }
    /^[[:space:]]*\|/ {
      v=$2; gsub(/^[ \t`*]+|[ \t`*]+$/,"",v)
      if (v == "" || v ~ /^-+$/) next
      if (tolower(v) ~ /^your (number|id)$/) next
      print v
    }' "$1" | sort -u | grep -c . || true
}
CCF_BASE="$(basename "${CCF:-crosswalk.md}")"
for _cw in "$REPO_ROOT/core/skills/ai-dlc/extensions/README.md" \
           "$REPO_ROOT/core/skills/ai-dlc/templates/$CCF_BASE"; do
  if [ ! -f "$_cw" ]; then
    err "I68 could not read $(basename "$(dirname "$_cw")")/$(basename "$_cw"), so it was not checked. A missing subject is not a clean one — the scaffold and the retired location are the two files core ships that the crosswalk reader is ever pointed at."
    continue
  fi
  _n="$(cw_harvest "$_cw")"
  if [ "$_n" -ne 0 ]; then
    err "I68 core ships $_n crosswalk row(s) in ${_cw#"$REPO_ROOT"/}: $(awk -F'|' '/^[[:space:]]*```/{f=!f;next} f{next} /^[[:space:]]*\|/{v=$2; gsub(/^[ \t`*]+|[ \t`*]+$/,"",v); if (v=="" || v ~ /^-+$/) next; if (tolower(v) ~ /^your (number|id)$/) next; print v}' "$_cw" | sort -u | paste -sd', ' -). Every consumer inherits them, so LC-N6 and LC-R2 clear themselves on those ids in a tree whose operator never wrote a row — a check that cannot fire, for exactly the ids core happened to use in an example. Fence the example, or drop the data row."
  fi
  # THE PROBE IS WRITTEN OUTSIDE THE REPOSITORY, and that is not fastidiousness. The first
  # cut of this arm wrote `.i68-probe.md` into $REPO_ROOT. Measured: an untracked, unignored
  # file at the repo root MOVES `scripts/suite-content-key.sh`'s value — key `3488ca3…` clean
  # against `b6c9884…` with a probe present — so a check about checks-that-cannot-fire was
  # quietly invalidating the suite skip for every later run. That is v0.208.0's finding
  # exactly: a fixture writing into the repo it tests, and a transient write leaves no trace
  # to find it by.
  _probe="$(mktemp "${TMPDIR:-/tmp}/i68-probe.XXXXXX")" || continue
  cp "$_cw" "$_probe" 2>/dev/null || { rm -f "$_probe"; continue; }
  printf '\n| ZZ-PROBE | x | y | z | w |\n' >> "$_probe"
  _p="$(cw_harvest "$_probe")"
  rm -f "$_probe"
  # ONE MORE than the base count, not one. Written as `-eq 1` this arm fired alongside the
  # claim above on every mutant that added a row, so a single defect scored two failures and
  # neither assertion was independently meaningful — the entanglement CLAUDE.md forbids.
  # The delta is what the control is actually about: the reader can still SEE a row.
  [ "$_p" -eq $((_n + 1)) ] || err "I68's control failed on ${_cw#"$REPO_ROOT"/}: the reader yielded $_n on the file and $_p on the same file plus ONE unfenced row, so appending a row did not move the count by one. The reading above is therefore a broken extractor rather than a measurement of the file, and this invariant would report every future example row as absent."
done

# --- I69: prose naming the declaration's HOME must name a file that carries it --
# THE DEFECT, measured on the release that shipped the declaration. Four sites told the
# reader the home was `core-manifest.md`: the clause text of LC-N6 and LC-N7, the
# extensions README, the scaffold template a consumer receives, and W8's own remedy
# string. The key has never been in that file — it is in layer-contract.yaml, and the
# contract's own header explains at length why it is there rather than in the manifest.
# So a consumer following the remedy while migrating its rows would open a file that does
# not carry the declaration, and the one site an operator reads DURING the migration was
# the one shipped inside the message telling them to migrate.
#
# THIS IS THE REMEDY CLASS v0.225.0 CLOSED FOR `anchor_form`, one string over: a fix whose
# instructions cannot be followed literally. W8's site is fixed the same way — it now emits
# `$(rel "$LC_FILE")` and carries no literal at all, which is why it is absent from the
# subject set below rather than passing it. A message that derives its own remedy cannot be
# wrong about it.
#
# THE GRAMMAR IS A HOME CLAIM, NOT A CO-OCCURRENCE, and that distinction is the whole
# false-positive set. Two paragraphs — one in the contract, one in the validator — name
# `core-manifest.md` precisely to say the declaration is NOT there and why, with the
# measurement behind the choice. A rule keyed on "a manifest-shaped filename appears near
# the token" reports both, and a check that fires on the rationale for its own subject gets
# turned off. Measured against the tree that carried the defect: this grammar returns the 4
# real sites and neither rationale paragraph.
#
# The window is the line plus the one before it, because the claim wraps in prose — the
# template's spans two lines and a line-scoped reader missed it while its control fired.
i69_claims() { # i69_claims <root> -> "<file>\t<named-file>" per home claim
  local _f
  for _f in $(grep -rl 'consumer_crosswalk_file' "$1/core" "$1/scripts" 2>/dev/null | grep -v '/fixtures/'); do
    awk -v F="${_f#"$1"/}" '
      { win = prev " " $0; prev = $0
        if (match(win, /[A-Za-z0-9._\/-]+\.(md|yaml)`?[^.]{0,40}declares as `?consumer_crosswalk_file/)) {
          s = substr(win, RSTART, RLENGTH); match(s, /[A-Za-z0-9._\/-]+\.(md|yaml)/)
          print F "\t" substr(s, RSTART, RLENGTH); next }
        if (match(win, /consumer_crosswalk_file:?.?[^.]{0,40}[ `\x27]in[ `\x27]+[A-Za-z0-9._\/-]+\.(md|yaml)/)) {
          s = substr(win, RSTART, RLENGTH)
          if (match(s, /[ `\x27]in[ `\x27]+[A-Za-z0-9._\/-]+\.(md|yaml)/)) {
            t = substr(s, RSTART, RLENGTH); match(t, /[A-Za-z0-9._\/-]+\.(md|yaml)/)
            print F "\t" substr(t, RSTART, RLENGTH) } }
      }' "$_f"
  done | sort -u
}
I69_CLAIMS="$(i69_claims "$REPO_ROOT")"
# ZERO GUARD. An empty claim set means the grammar stopped matching, not that core stopped
# restating the home — and this arm's whole failure mode is going quiet, because every fix
# to it removes one of its own subjects.
if [ -z "$I69_CLAIMS" ]; then
  err "I69 found no 'consumer_crosswalk_file:' home claim anywhere in core/ or scripts/, and there are three: the extensions README, the contract's own clause text, and the scaffold template. A zero here is this grammar having stopped matching, which reads exactly like core having stopped restating the declaration's home."
else
  while IFS="$(printf '\t')" read -r _cf _named; do
    [ -n "$_cf" ] || continue
    if ! grep -q '^consumer_crosswalk_file:' "$REPO_ROOT/core/skills/ai-dlc/$(basename "$_named")" 2>/dev/null \
       && ! grep -q '^consumer_crosswalk_file:' "$REPO_ROOT/core/skills/ai-dlc-update/reconcile/$(basename "$_named")" 2>/dev/null; then
      err "I69 $_cf names '$_named' as the home of the 'consumer_crosswalk_file:' declaration, and that file does not carry it. The declaration lives in core/skills/ai-dlc/layer-contract.yaml, twinned into reconcile/setup-sites.md; a consumer following this text during a migration opens a file with no declaration in it. Name the file that carries the key, or derive the name as W8 does."
    fi
  done <<EOF
$I69_CLAIMS
EOF
fi

# --- I70: the PR-class taxonomy is declared once and derived by every reader ----
# vocabulary: PR classes
# vocabulary-invariant: I70
# vocabulary-owner: (consumer-owned) the taxonomy lives in THEIRS's own contract, which ai-dlc-update reads through git show rather than carrying a copy; no member of it exists in this tree to render
# I67's rule, applied to the third consumer-owned file this contract declares. There is no
# forward arm because there is no twin: `ai-dlc-update` reads THEIRS's own contract through
# `git show` rather than carrying a copy, so the declaration has exactly one home and the
# only way for the ends to drift is a reader that restates the literal.
#
# THE ARMS, and each one exists because the other two are satisfiable without it:
#   no-literal  a reader that hard-codes the path passes every agreement check forever while
#               the declaration moves out from under it — how `CROSSWALK_MD="$EXT_DIR/README.md"`
#               survived, which is the defect I67 was written for.
#   reads-key   "carries no literal" is satisfied just as well by a file that has nothing to
#               do with the taxonomy, so the read is asserted rather than assumed.
#   template    the installer names the template LITERALLY and the pull driver DERIVES it from
#               the declared basename. Those two agree today and nothing compares them, so a
#               rename of the declaration would leave install.sh scaffolding and the pull
#               driver reporting `pr-class-template-missing` — a divergence visible only to a
#               consumer mid-pull, which is the audience least able to act on it.
PCF_DECL="$(sed -n 's/^consumer_pr_class_file:[[:space:]]*//p' "$LC_YAML" 2>/dev/null | head -1 | sed 's/[[:space:]]*$//')"
PCF_READERS="$REPO_ROOT/core/scripts/validate-cycle-commits.sh $REPO_ROOT/scripts/install.sh $REPO_ROOT/core/skills/ai-dlc-update/reconcile/apply.sh"
if [ -z "$PCF_DECL" ]; then
  err "I70 could not read 'consumer_pr_class_file:' from core/skills/ai-dlc/layer-contract.yaml. The trunk audit, the installer and the pull driver all derive the taxonomy's location from that one line; without it the audit reports every consumer as predating the declaration, which is silence that reads exactly like a clean trunk."
else
  pcf_hard="$(grep -lF -- "$PCF_DECL" $PCF_READERS 2>/dev/null || true)"
  if [ -n "$pcf_hard" ]; then
    err "I70 the declared PR-class taxonomy path '$PCF_DECL' appears LITERALLY in $(echo $pcf_hard). Every reader must derive it from the declaration; one that restates it agrees with the contract until the day the contract changes, and then disagrees silently."
  fi
  for _r in $PCF_READERS; do
    grep -qF 'consumer_pr_class_file:' "$_r" 2>/dev/null || \
      err "I70 $(basename "$_r") does not read 'consumer_pr_class_file:' at all. The no-literal arm above is satisfied by a file that never touches the taxonomy just as well as by one that derives its location, so the read is asserted here rather than assumed."
  done
  _pcf_tpl="$REPO_ROOT/core/skills/ai-dlc/templates/$(basename "$PCF_DECL")"
  [ -f "$_pcf_tpl" ] || \
    err "I70 core ships no templates/$(basename "$PCF_DECL") to scaffold the declared taxonomy from. install.sh names that template literally and reconcile/apply.sh derives it from the declaration's basename; with the file absent the installer fails loudly and the pull driver files 'pr-class-template-missing', and a consumer that never runs install.sh again sees only the second."
fi

# --- I74: install.sh DERIVES the ship set, and every `.dist-only` says why ----------
# The shipped set is `core/fixtures/*/` minus every directory carrying a `.dist-only` marker.
# That is the only definition, and the marker is the fixture's own colocated declaration.
#
# THIS INVARIANT USED TO JOIN install.sh's HAND-WRITTEN LIST against the tree, in both
# directions. install.sh now derives, so that join would compare a derivation to itself and
# pass for a reason unrelated to anything being right. **A tautology reads exactly like a
# check that holds**, so the join was not kept -- it was replaced by (b), which asserts the
# derivation is still there and still excludes the marker, and the list-vs-tree joins that
# remain live in I8 over uninstall.sh, which still has a list and needs one.
#
# MEASURED WHEN THE ORIGINAL WAS WRITTEN: 93 listed, 94 shipped, exactly ONE unlisted -- the
# fixture the release adding this invariant had just written. Nothing caught it; the consumer
# install did, by not having it. Re-measured at the derivation: 132 on disk, 120 shipped, 12
# `.dist-only`, all three remaining declarations agreeing at 120, and ground-truthed by running
# install.sh into an empty tree: 120 fixture directories, 0 marked ones leaked.
#
# THE MARKER MUST CARRY A REASON. A zero-byte `.dist-only` is a decision nobody can audit, and
# seven of the twelve were zero bytes until this arm existed. The criterion for writing one is in
# CLAUDE.md; the marker states why THIS fixture has one.
# I74(b) -- install.sh must DERIVE, and this arm exists because the arm above stopped
# watching it. If the hand-list ever comes back, or the `.dist-only` exclusion is dropped
# from the derivation, install.sh ships the wrong set and every join above still agrees --
# they are all joined to the DERIVED set, which the derivation is what produces.
i74_iloop="$(sed -n '/^for fixture_dir in /,/^); do$/p' "$REPO_ROOT/scripts/install.sh" 2>/dev/null)"
if [ -z "$i74_iloop" ]; then
  err "I74(b) could not find install.sh's fixture loop at all. Either it was renamed -- in which case every arm above is joining against a set nothing installs -- or this extractor is looking at the wrong shape, and its silence means nothing."
else
  case "$i74_iloop" in
    *'core/fixtures/'*) : ;;
    *) err "I74(b) install.sh's fixture loop does not read core/fixtures/. It is no longer deriving the ship set from the tree." ;;
  esac
  case "$i74_iloop" in
    *'.dist-only'*) : ;;
    *) err "I74(b) install.sh's fixture loop does not exclude \`.dist-only\`. Every distribution-only fixture would be copied into the consumer's suite schedule -- the v0.230.0 defect, and the joins above cannot see it because they all resolve the same marker themselves." ;;
  esac
fi

# I74(d) -- every `.dist-only` marker carries a reason. A zero-byte marker is a decision
# nobody can audit: it excludes a fixture from every consumer and says nothing about why,
# and seven of the twelve were zero bytes when this arm was written.
i74_mute=""
for _fd in "$REPO_ROOT"/core/fixtures/*/; do
  [ -f "$_fd.dist-only" ] || continue
  if [ ! -s "$_fd.dist-only" ]; then
    _fn="${_fd%/}"; i74_mute="${i74_mute} ${_fn##*/}"
  fi
done
[ -n "${i74_mute// /}" ] && err "I74(d) \`.dist-only\` marker(s) with an EMPTY body:${i74_mute}. The marker excludes the fixture from every consumer; with no reason written in it, the next author cannot tell a considered exclusion from one copied by pattern-match. The criterion is in CLAUDE.md."

# --- I79: every rule below the re-attach cut declares what CARRIES it -------------
# A compacted lead holds only the rules that survive the harness's skill re-attach cut.
# Measured over 261 real re-attaches, the cut is deterministic and 13 of 30 rules survive
# it, so 17 are absent from every post-compaction lead. Rule 19 sits in that band and HELD
# at 89% across the boundary because a dispatch template carries its requirement; Rule 23
# sits beside it and collapsed 13x because nothing outside its own prose does. A rule
# survives a compaction only if something other than the lead's memory carries it.
#
# WHY THIS IS A DECLARATION AND NOT A SCANNER, WHICH IS THE WHOLE DESIGN. Inference was
# measured and FAILS IN BOTH DIRECTIONS:
#   * Name-matching FALSE-POSITIVES. Rule 30 contains zero occurrences of "Rule 30" and is
#     nonetheless carried by validate-spec-join.sh and Check 30. A scanner keyed on the
#     rule's own number reports a gap that does not exist.
#   * Semantic matching FALSE-NEGATIVES exactly where it costs most. Broadening the probe
#     to context-mode/ctx_search "rescues" Rule 23 with hits that are ALL the filename
#     `context-mode-protection-log.md` and its rotation -- an artifact-budget concern under
#     Rule 25. The one rule with the strongest measured collapse would score as carried.
# So the rule DECLARES its carrier and this invariant verifies the declaration RESOLVES.
#
# RULE NUMBERS AND CHECK NUMBERS ARE UNRELATED NAMESPACES. Check 22 is "Teammate-spawn role
# binding", which is RULE 19's subject; Check 23 is "Analyst-draft sprint stamps (Rule 24)".
# Any join keyed on `Rule N <-> Check N` is wrong by construction -- the collision class
# that has already shipped here twice. This invariant never forms that join: a carrier that
# names a check must spell it `Check <id>` and is looked up in the map by that id alone.
#
# BOTH SIDES DERIVED. The band comes from validate-reattach-budget.sh's own window and
# bytes-per-token, never from a hardcoded "14-30" -- a hardcoded band silently stops
# matching the moment a rule is inserted, and would keep printing this same clean line.
i79_budget="$(sed -n 's/^BUDGET="${AI_DLC_REATTACH_BUDGET:-\([0-9]*\)}"/\1/p' "$REPO_ROOT/core/scripts/validate-reattach-budget.sh" | head -1)"
i79_bpt="$(sed -n 's/^BPT="${AI_DLC_BYTES_PER_TOKEN:-\([0-9]*\)}"/\1/p' "$REPO_ROOT/core/scripts/validate-reattach-budget.sh" | head -1)"
i79_skill="$REPO_ROOT/core/skills/ai-dlc/SKILL.md"
if [ -z "$i79_budget" ] || [ -z "$i79_bpt" ] || [ ! -f "$i79_skill" ]; then
  err "I79 could not derive the re-attach cut (BUDGET='$i79_budget', BPT='$i79_bpt', SKILL.md present=$([ -f "$i79_skill" ] && echo yes || echo no)). An underived band would either scan nothing or scan everything, and both print a clean line."
else
  i79_cut=$(( i79_budget * i79_bpt ))
  i79_total="$(grep -c '^### Rule [0-9]' "$i79_skill")"
  i79_resident="$(head -c "$i79_cut" "$i79_skill" | grep -c '^### Rule [0-9]')"
  if [ "$i79_resident" -lt 1 ] || [ "$i79_resident" -ge "$i79_total" ]; then
    err "I79 derived a degenerate band: $i79_resident resident of $i79_total at a ${i79_cut}-byte cut. Either every rule is resident or none is, so the invariant has no subject and would pass vacuously."
  else
    # The band is every rule heading at or past the cut.
    i79_band="$(awk -v cut="$i79_cut" '
      { off += length($0) + 1 }
      /^### Rule [0-9]/ { if (off > cut) { n=$3; print n } }
    ' "$i79_skill")"
    i79_band_n="$(printf '%s\n' "$i79_band" | grep -c .)"
    i79_expect=$(( i79_total - i79_resident ))
    if [ "$i79_band_n" -ne "$i79_expect" ]; then
      err "I79 band derivation disagrees with itself: offset walk found $i79_band_n rules past the ${i79_cut}-byte cut, head -c found $i79_expect. One of the two readings is wrong and the invariant cannot say which."
    fi
    i79_gaps=0
    for i79_n in $i79_band; do
      # the rule's own body span, so a Carrier line cannot be borrowed from a neighbour
      i79_body="$(awk -v n="$i79_n" '
        $0 ~ ("^### Rule " n " ") { inb=1; next }
        inb && /^### Rule [0-9]/ { exit }
        inb && /^## / { exit }
        inb { print }
      ' "$i79_skill")"
      i79_line="$(grep -c '^\*\*Carrier:\*\*' <<<"$i79_body")"
      if [ "$i79_line" -eq 0 ]; then
        err "I79 Rule $i79_n is below the re-attach cut and declares no '**Carrier:**'. A compacted lead does not hold this rule; without a declared carrier nothing does, and the omission is indistinguishable from a rule that genuinely needs none."
        continue
      elif [ "$i79_line" -gt 1 ]; then
        err "I79 Rule $i79_n declares $i79_line '**Carrier:**' lines. One rule, one carrier declaration -- two readings make the resolution below ambiguous."
        continue
      fi
      i79_val="$(grep -m1 '^\*\*Carrier:\*\*' <<<"$i79_body" | sed 's/^\*\*Carrier:\*\* *//')"
      case "$i79_val" in
        none*)
          # A gap is legal, but it must say WHY, or "none" becomes the cheap way out.
          if ! grep -q '^none[[:space:]]*--[[:space:]]*[^[:space:]]' <<<"$i79_val"; then
            err "I79 Rule $i79_n declares 'carrier: none' with no reason. A declared exemption with no argument is the defect this repo keeps finding; write 'none -- <why>'."
          else
            i79_gaps=$(( i79_gaps + 1 ))
          fi
          ;;
        '')
          err "I79 Rule $i79_n has an empty '**Carrier:**' declaration."
          ;;
        *)
          # Resolve it. A carrier that names nothing real is prose wearing a field name.
          i79_target="$(sed -e 's/^`//' -e 's/`.*$//' <<<"$i79_val")"
          case "$i79_target" in
            Check\ *)
              i79_cid="${i79_target#Check }"
              if ! grep -qE "^  - id: \"?${i79_cid}\"?$" "$MAP"; then
                err "I79 Rule $i79_n declares carrier '$i79_target', which is not an id in enforcement-map.yaml. Note that rule numbers and check numbers are UNRELATED namespaces -- Check 22 is Rule 19's subject -- so a check carrier must be one the map actually lists."
              fi
              ;;
            *)
              # TWO LAYOUTS. SKILL.md is a RUNTIME file: it is read by consumers, where a
              # `core/...` path is a dead link. So the declaration carries the CONSUMER
              # path and this invariant maps it back to the distribution tree it is
              # checking, using install.sh's own two mappings. Never walk up from one core
              # file to find another (I33) -- both forms are resolved from the repo root.
              case "$i79_target" in
                scripts/ai-dlc/*)          i79_dist="core/scripts/${i79_target#scripts/ai-dlc/}" ;;
                .claude/skills/ai-dlc/*)   i79_dist="core/skills/ai-dlc/${i79_target#.claude/skills/ai-dlc/}" ;;
                .claude/*)                 i79_dist="core/${i79_target#.claude/}" ;;
                *)
                  err "I79 Rule $i79_n declares carrier '$i79_target', which is neither a consumer path this invariant can map to the distribution tree (scripts/ai-dlc/... or .claude/...) nor a 'Check <id>'. An unmappable carrier cannot be resolved, and an unresolved carrier reads exactly like a real one."
                  i79_dist=""
                  ;;
              esac
              if [ -n "$i79_dist" ] && [ ! -e "$REPO_ROOT/$i79_dist" ]; then
                err "I79 Rule $i79_n declares carrier '$i79_target' (distribution path '$i79_dist'), which does not exist in the tree. A carrier that cannot be resolved carries nothing, and this declaration would keep reading like coverage."
              fi
              ;;
          esac
          ;;
      esac
    done
    # The gap count is REPORTED, never silently tolerated. Per CLAUDE.md, a bound the
    # invariant accepts must be visible or it reads as full coverage.
    echo "  I79: ${i79_band_n} rule(s) below the ${i79_cut}-byte re-attach cut; ${i79_gaps} declared carrier gap(s)."
  fi
fi

# --- I78: the copyable example declares the CURRENT contract version ---------------
# `extensions/README.md`'s fenced frontmatter is what an author copies when writing a new
# entry, so a stale `conforms_to:` there seeds every new entry with a stale value that
# [LC-C1] then measures them against. Found at `conforms_to: 9` against
# `contract_version: 13` -- four versions behind, and it reached a consumer, which had
# corrected it locally and thereby tripped HARD-UNREGISTERED-CORE-DRIFT on its own pull.
# Both sides derived, so this cannot go stale again when the contract advances.
i78_cv="$(sed -n 's/^contract_version: //p' "$REPO_ROOT/core/skills/ai-dlc/layer-contract.yaml" | head -1)"
i78_ex="$(sed -n 's/^conforms_to: \([0-9][0-9]*\).*/\1/p' "$REPO_ROOT/core/skills/ai-dlc/extensions/README.md" | head -1)"
if [ -z "$i78_cv" ] || [ -z "$i78_ex" ]; then
  err "I78 could not read both sides (contract_version='$i78_cv', README example='$i78_ex'). An unread side compares equal to nothing, so this fails closed rather than reporting agreement it did not compute."
elif [ "$i78_cv" != "$i78_ex" ]; then
  err "I78 the extensions/README.md example declares 'conforms_to: $i78_ex' while layer-contract.yaml declares 'contract_version: $i78_cv'. The example is what an author COPIES, so every new entry it seeds is born stale and [LC-C1] measures them against it."
fi

# --- I77: every shipped shell file is EXECUTABLE in git ----------------------------
# `apply.sh` derives each file's mode from GIT'S TREE and chmods the consumer copy to match
# (`100644) chmod -x "$2"`), so a mode bit lost upstream is actively STRIPPED on every
# consumer at the next pull. `install.sh` chmods on fresh install, which is exactly why this
# hid: a fresh consumer was fine and an UPDATING one got `rc=126 permission denied` on the
# first invocation by path.
#
# MEASURED WHEN THIS WAS WRITTEN: 12 shipped `.sh` files at `100644`, seven of them
# `core/scripts/` validators that consumers invoke by path -- including
# `validate-bmad-invocations.sh`, the Check 32 driver. They were made non-executable by a
# release that rewrote them with `awk > tmp && mv`, which creates a new file at the umask
# and silently drops the mode. Nothing compared the mode of a shipped file to anything, so
# the release went out green and a real consumer's pull found it.
#
# The subject set is DERIVED: every `*.sh` git tracks under a subtree that ships. A file
# that is data rather than a program does not carry `.sh`.
# THE INDEX, not HEAD: the mode is fixable before the commit that would ship it, and at
# pre-push the index and HEAD agree, so nothing is lost by catching it earlier.
i77_bad="$(cd "$REPO_ROOT" && git ls-files -s 2>/dev/null \
  | awk '$1=="100644" && $4 ~ /\.sh$/ {print "    " $4}')"
i77_n="$(cd "$REPO_ROOT" && git ls-files -s 2>/dev/null | awk '$4 ~ /\.sh$/' | grep -c . || true)"
# SCOPE, and it is a distinction not a loophole. This invariant's subject is git's own
# index, so it can only run where there IS one. Fixture harnesses copy this validator into
# a scratch tree that is not a work tree; failing closed there produced a false red that
# ENTANGLED another fixture's mutants -- two failures where the assertion expected one,
# which is the shape that makes a mutant unattributable. "git is absent" and "git works and
# found nothing" are different answers and only the second is a finding.
if ! (cd "$REPO_ROOT" && git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
  : # not a work tree -- I77 has no index to read. Not a pass and not a failure.
elif [ "$i77_n" -lt 20 ]; then
  err "I77 read git's index and enumerated $i77_n tracked shell file(s). Fewer than twenty inside a real work tree means the enumerator stopped matching, not that the tree shrank -- and an empty subject set has no offenders by construction, so this fails closed rather than reporting a cleanliness it did not measure."
else
  # SELF-PROBE. Without it, an enumerator that silently returned no rows would print the
  # same clean line as a tree with every mode correct.
  i77_probe="$(cd "$REPO_ROOT" && git ls-files -s 2>/dev/null \
    | awk '$1=="100755" && $4 ~ /\.sh$/' | grep -c . || true)"
  [ "$i77_probe" -gt 0 ] || err "I77 self-probe FAILED: the reader found ZERO executable shell files, so it cannot distinguish a 100644 from a 100755 and its verdict below is unattributable."
  if [ -n "$i77_bad" ]; then
    err "I77 shipped shell file(s) tracked as 100644 (not executable):
$i77_bad
    apply.sh derives the consumer's mode from git and chmods to match, so each of these is
    actively made non-executable on every consumer at the next pull -- \`rc=126 permission
    denied\` on the first invocation by path. install.sh chmods on FRESH install, so this is
    invisible until a real consumer updates. Fix with \`git update-index --chmod=+x <path>\`;
    beware editors that rewrite a file via \`> tmp && mv\`, which drops the mode at the umask."
  fi
fi

# --- I76: every flat skill-root file is shipped AND claimed, or declared not-shipped --
# `install.sh` copied the skill root's flat files from a HAND-LIST that nothing compared
# to anything. Two live asymmetries when this was written, in opposite directions:
#
#   `enforcement-map.yaml`   SHIPPED, and absent from `core_manifest:`. The core-write
#                            guard and Check 16's scope filter both key on that manifest,
#                            so the file was UNPROTECTED on every consumer.
#   `research-citations.md`  in `audit-rule-files.sh`'s IN_SCOPE and shipped by NOBODY.
#                            IN_SCOPE is the set of paths a pointer may resolve against,
#                            so an alternand naming a file no consumer has is a target
#                            that can never resolve — a check that cannot fire.
#
# THE INSTALL SIDE IS MEASURED BY RUNNING THE LOOP, not by pattern-matching its source.
# The loop is now a glob, so there is no list to read; and a source-shaped assertion is
# what let the hand-list drift in the first place. I8's site-table precedent.
#
# `.not-shipped` is the same self-declaring exemption I8 uses for `.dist-only`, with the
# same reverse arm: a marked file may not ALSO be claimed by `core_manifest:`, so the
# marker cannot decay into a way of having it both ways.
i76_skill="$REPO_ROOT/core/skills/ai-dlc"
i76_loop="$(sed -n '/^for doc in /,/^done$/p' "$REPO_ROOT/scripts/install.sh")"
[ -n "$i76_loop" ] || err "I76 could not extract install.sh's skill-root copy loop. It measures the ship side by RUNNING that loop; with nothing extracted it would report every file unshipped."
i76_probe="$(mktemp -d)"
mkdir -p "$i76_probe/.claude/skills/ai-dlc"
( cd "$REPO_ROOT" && SCRIPT_DIR="$REPO_ROOT/scripts" PROJECT_ROOT="$i76_probe" \
  bash -c "$i76_loop" ) 2>/dev/null
i76_shipped="$(cd "$i76_probe/.claude/skills/ai-dlc" 2>/dev/null && ls 2>/dev/null | sort)"
rm -rf "$i76_probe"

i76_flat="$(cd "$i76_skill" && ls *.md *.yaml 2>/dev/null | grep -v '^SKILL\.md$' | sort)"
i76_nf="$(grep -c . <<<"$i76_flat" || true)"
if [ "$i76_nf" -lt 3 ]; then
  err "I76 found $i76_nf flat file(s) under core/skills/ai-dlc/. Fewer than three means the enumerator stopped matching, not that the rulebook shrank — and an empty subject set satisfies every requirement, so this fails closed."
else
  i76_bad=""
  while IFS= read -r _f; do
    [ -n "$_f" ] || continue
    _marked=0; [ -f "$i76_skill/$_f.not-shipped" ] && _marked=1
    _ships=0;  grep -qx "$_f" <<<"$i76_shipped" && _ships=1
    _claimed=0; grep -qE "^  - $(printf '%s' "$_f" | sed 's/\./\\./g')$" "$i76_skill/core-manifest.md" && _claimed=1
    if [ "$_marked" -eq 1 ]; then
      [ "$_ships" -eq 0 ] || i76_bad="${i76_bad}$_f(declared not-shipped but the installer copies it) "
      [ "$_claimed" -eq 0 ] || i76_bad="${i76_bad}$_f(declared not-shipped but core_manifest: claims it — the exemption is not self-certifying) "
    else
      [ "$_ships" -eq 1 ]   || i76_bad="${i76_bad}$_f(reaches no consumer and carries no .not-shipped marker) "
      [ "$_claimed" -eq 1 ] || i76_bad="${i76_bad}$_f(ships but core_manifest: does not claim it, so the core-write guard cannot protect it) "
    fi
  done <<<"$i76_flat"

  # SELF-PROBES. Without them a run whose installer probe copied NOTHING would report
  # every file as unshipped, or — worse, if the ls failed — as trivially consistent.
  grep -qx "core-manifest.md" <<<"$i76_shipped" \
    || err "I76 self-probe FAILED: the installer probe did not copy core-manifest.md, a file that plainly ships. The probe is broken, so every verdict below is unattributable."
  [ -n "$(cd "$i76_skill" && ls *.not-shipped 2>/dev/null)" ] \
    || err "I76 self-probe FAILED: no .not-shipped marker exists anywhere, so the exemption arm has never been exercised and cannot be known to fire."

  if [ -n "${i76_bad// /}" ]; then
    err "I76 skill-root flat file(s) whose ship path and manifest claim disagree: ${i76_bad}. Every flat file under core/skills/ai-dlc/ must SHIP and be claimed by core_manifest:, or carry a \`<name>.not-shipped\` marker and be claimed by neither. A file that ships unclaimed is invisible to the core-write guard on every consumer; a file claimed but unshipped is a manifest entry no consumer can satisfy."
  fi
fi

# --- I75: a validator that consults a project root consults it through ONE block ----
# Eight of the fifteen `core/scripts/*.sh` that consult a project root did it with a bare
# `${CLAUDE_PROJECT_DIR:-.}` or `${AI_DLC_PROJECT_ROOT:-.}` — no walk, no fallback to the
# script's own install path. `CLAUDE_PROJECT_DIR` is set by the harness for whatever repo
# the session started in, so a validator installed in repo B and run against repo B
# answered about repo A. MEASURED on a real pair of trees before this shipped: three of
# five answered about the wrong repository and TWO OF THOSE RETURNED 0 where the same
# script returns 1 on the right one — a pass reachable by two structurally different
# roads, which is this repository's recurring defect in its purest form.
#
# The canonical block already existed, inline, in seven siblings, with the right
# precedence: `AI_DLC_PROJECT_ROOT` (operator override) -> walk up from the script's own
# location -> `CLAUDE_PROJECT_DIR` -> walk up from cwd -> exit 2. Inline duplication is
# correct and the block says why: locating a shared lib is the same unsolved problem.
#
# BOTH SIDES DERIVED. The subject set is every script mentioning a root token; the
# required text is the MODAL span across that same subject set, so no donor file is
# named and a rename cannot quietly make this vacuous. Scripts that take the root as an
# ARGUMENT (`${1:-$(pwd)}`, `ROOT="$PWD"`) mention none of the tokens and are out of
# scope BY DECISION, not by accident: that is a different and legitimate contract.
# NOT byte-identity, and that is a measurement rather than a preference. The block's
# PROSE legitimately differs per script — each copy names the failure that script saw,
# which is this repository's house style — and two copies fail closed by substituting an
# unresolvable path instead of `exit 2`, because they must not die mid-parse. Demanding
# identical bytes would force churn on six working scripts to satisfy a requirement
# stricter than the defect. So I75 asserts the two things that actually stop it:
#   (1) the PRECEDENCE CHAIN is the canonical sequence, compared on executable lines
#       with indentation and the script's own variable names normalised away (the I66
#       precedent: compare executable lines so no comment can satisfy the check);
#   (2) the chain FAILS CLOSED. Four scripts had no terminal guard at all: an
#       unresolved root left the variable empty and every derived path became absolute
#       from `/`. Both idioms are accepted; having neither is not.
i75_norm() {
  awk '/^# --- AI_DLC_ROOT ---/,/^# --- end AI_DLC_ROOT ---/' "$1" 2>/dev/null \
    | grep -vE '^[[:space:]]*(#|$)' \
    | sed -e 's/AI_DLC_PROJECT_ROOT/@OVR@/g' \
          -e 's/[A-Z0-9_]*SCRIPT_DIR/SELFVAR/g' \
          -e 's/AI_DLC_SELF_DIR/SELFVAR/g' \
          -e 's/[A-Z][A-Z0-9_]*_ROOT/ROOTVAR/g' \
          -e 's/@OVR@/AI_DLC_PROJECT_ROOT/g' \
          -e 's/^[[:space:]]*//'
}
# The chain only: from the override read to the cwd walk. The terminal guard is asserted
# separately because its two forms are both correct.
i75_chain() { i75_norm "$1" | sed -n '/^ROOTVAR="\${AI_DLC_PROJECT_ROOT:-}"$/,/ai_dlc_resolve_root "\$(pwd)"/p'; }
i75_failsclosed() { i75_norm "$1" | grep -qE 'exit [0-9]|:-/nonexistent'; }

i75_subjects="$(grep -lE 'AI_DLC_PROJECT_ROOT|CLAUDE_PROJECT_DIR|ai_dlc_resolve_root' \
  "$REPO_ROOT"/core/scripts/*.sh 2>/dev/null | sort)"
i75_n="$(grep -c . <<<"$i75_subjects" || true)"
if [ "$i75_n" -lt 5 ]; then
  err "I75's subject extractor found $i75_n script(s) consulting a project root. Fewer than five means the extractor stopped matching, not that the population shrank — and an empty subject set agrees with every requirement, so this fails closed."
else
  i75_modal="$(while IFS= read -r _f; do
      [ -n "$_f" ] || continue
      i75_chain "$_f" | { shasum -a 256 2>/dev/null || sha256sum; } | cut -d' ' -f1
    done <<<"$i75_subjects" | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')"
  i75_empty="$(printf '' | { shasum -a 256 2>/dev/null || sha256sum; } | cut -d' ' -f1)"
  if [ -z "$i75_modal" ] || [ "$i75_modal" = "$i75_empty" ]; then
    err "I75 could not derive a canonical precedence chain: the most common chain across $i75_n subject script(s) is EMPTY, and an empty chain matches every subject. Failing closed rather than reporting an agreement it did not compute."
  else
    i75_drift=""; i75_open=""
    while IFS= read -r _f; do
      [ -n "$_f" ] || continue
      _s="$(i75_chain "$_f" | { shasum -a 256 2>/dev/null || sha256sum; } | cut -d' ' -f1)"
      [ "$_s" = "$i75_modal" ]   || i75_drift="${i75_drift}$(basename "$_f") "
      i75_failsclosed "$_f"      || i75_open="${i75_open}$(basename "$_f") "
    done <<<"$i75_subjects"

    # SELF-PROBES, written here rather than assumed. Without them, a run whose extractor
    # returns nothing for every subject prints the same clean line as a real pass.
    i75_pd="$(mktemp -d)"
    awk '/^# --- AI_DLC_ROOT ---/,/^# --- end AI_DLC_ROOT ---/' \
      "$REPO_ROOT/core/scripts/validate-ci-gates.sh" > "$i75_pd/blk.txt"
    { echo '#!/usr/bin/env bash'; cat "$i75_pd/blk.txt"; } > "$i75_pd/good.sh"
    { echo '#!/usr/bin/env bash'; echo '# --- AI_DLC_ROOT ---'
      echo 'ROOT="${CLAUDE_PROJECT_DIR:-.}"'; echo '# --- end AI_DLC_ROOT ---'; } > "$i75_pd/bad.sh"
    i75_pg="$(i75_chain "$i75_pd/good.sh" | { shasum -a 256 2>/dev/null || sha256sum; } | cut -d' ' -f1)"
    i75_pb="$(i75_chain "$i75_pd/bad.sh"  | { shasum -a 256 2>/dev/null || sha256sum; } | cut -d' ' -f1)"
    i75_pbo=0; i75_failsclosed "$i75_pd/bad.sh" || i75_pbo=1
    rm -rf "$i75_pd"
    [ "$i75_pg" = "$i75_modal" ] || err "I75 self-probe FAILED: a synthetic script carrying the canonical chain did not match the derived one. The comparison is broken, so every verdict below is unattributable."
    [ "$i75_pb" != "$i75_modal" ] || err "I75 self-probe FAILED: a synthetic script carrying only a bare \`\${CLAUDE_PROJECT_DIR:-.}\` MATCHED the derived chain. The check cannot fire and would report every tree clean."
    [ "$i75_pbo" -eq 1 ] || err "I75 self-probe FAILED: the fail-closed reader accepted a block with no terminal guard. That arm cannot fire."

    if [ -n "${i75_drift// /}" ]; then
      err "I75 script(s) whose root-resolution precedence chain differs from the canonical one: ${i75_drift}. The chain is override -> walk up from the script's own location -> CLAUDE_PROJECT_DIR -> walk up from cwd. A script that reads CLAUDE_PROJECT_DIR before its own install path answers about whichever repository the session started in; measured on a real pair of trees, two such scripts returned 0 on the wrong repository where they return 1 on the right one. \`core/fixtures/validator-path-resolution\` asserts every subject ignores a CLAUDE_PROJECT_DIR pointing at another tree."
    fi
    if [ -n "${i75_open// /}" ]; then
      err "I75 script(s) whose root resolution does not fail closed: ${i75_open}. With no terminal guard an unresolved root leaves the variable EMPTY, every derived path becomes absolute from \`/\`, and the script reports about a tree that does not exist rather than saying it cannot find one. End the chain with an \`exit\` guard, or substitute an unresolvable path as \`validate-gate-adjudication.sh\` does."
    fi
  fi
fi

# --- I73: the derivable story-field list is declared once and derived by every reader
# I67/I70's rule, applied to the fourth consumer-owned file this contract declares. Same three
# arms, and each still exists because the other two are satisfiable without it.
#
# A FOURTH ARM IS HERE THAT I70 DOES NOT HAVE, and it is the one specific to this declaration:
# `status` must NOT be readable from the consumer's list. It is the field Check 5 depends on, it
# is declared in the schema, and the whole point of splitting floor from declaration is that a
# consumer cannot declare its way out of it. If the derive ever read its field set from the
# declaration alone, every arm above would still pass.
SFF_DECL="$(sed -n 's/^consumer_story_fields_file:[[:space:]]*//p' "$LC_YAML" 2>/dev/null | head -1 | sed 's/[[:space:]]*$//')"
SFF_READERS="$REPO_ROOT/core/scripts/sprint-status.sh $REPO_ROOT/scripts/install.sh $REPO_ROOT/core/skills/ai-dlc-update/reconcile/apply.sh"
if [ -z "$SFF_DECL" ]; then
  err "I73 could not read 'consumer_story_fields_file:' from core/skills/ai-dlc/layer-contract.yaml. The derive, the installer and the pull driver all derive the list's location from that one line; without it the derive reports every consumer as predating the declaration, which is a worklist line that reads exactly like a consumer who has nothing to declare."
else
  sff_hard="$(grep -lF -- "$SFF_DECL" $SFF_READERS 2>/dev/null || true)"
  if [ -n "$sff_hard" ]; then
    err "I73 the declared story-field list path '$SFF_DECL' appears LITERALLY in $(echo $sff_hard). Every reader must derive it from the declaration; one that restates it agrees with the contract until the day the contract changes, and then disagrees silently."
  fi
  for _r in $SFF_READERS; do
    grep -qF 'consumer_story_fields_file:' "$_r" 2>/dev/null || \
      err "I73 $(basename "$_r") does not read 'consumer_story_fields_file:' at all. The no-literal arm above is satisfied by a file that never touches the declaration just as well as by one that derives its location."
  done
  _sff_tpl="$REPO_ROOT/core/skills/ai-dlc/templates/$(basename "$SFF_DECL")"
  [ -f "$_sff_tpl" ] || \
    err "I73 core ships no templates/$(basename "$SFF_DECL") to scaffold the declared list from. install.sh names that template literally and reconcile/apply.sh derives it from the declaration's basename; with the file absent the installer fails loudly and the pull driver files 'story-fields-template-missing'."
  # The floor arm. `status` must come from the schema's story_entry_fields, and the derive must
  # read it from there rather than from the consumer's list.
  if ! grep -q 'story_entry_fields' "$REPO_ROOT/core/scripts/sprint-status.sh" 2>/dev/null; then
    err "I73 sprint-status.sh does not read the schema's 'story_entry_fields' at all, so the derive's floor is not the schema's -- which means \`status\` is whatever the consumer's list says it is, and a consumer can declare its way out of the one field Check 5 depends on."
  fi
  if ! grep -q '"status"' "$REPO_ROOT/core/schemas/sprint-status.json" 2>/dev/null; then
    err "I73 core/schemas/sprint-status.json declares no 'status' story-entry field, so the floor the arm above reads is empty and the derive would silently derive nothing at all on a consumer that declares 'none'."
  fi
fi

# --- I71: no sed or grep expression uses a bracket class containing \t ---------
# In awk, `[ \t]` is correct: awk processes the escape when it compiles the regex.
# In sed and grep it is NOT. POSIX bracket expressions have no escapes, so the
# class is the three characters SPACE, BACKSLASH and `t` -- and `s/[ \t]*$//`,
# the idiom every declaration reader in this tree used to strip trailing space,
# silently eats a trailing `t` or backslash instead.
#
# Measured on this box, BSD sed: `capture: sprint` -> `capture: sprin`, and
# `validator: x --strict` -> `validator: x --stric`. The leading form is the same
# defect one end over: ` true` -> `rue`. There is no error and no exit code; the
# value is simply the wrong string from then on. It is the false-zero class from
# CLAUDE.md arriving through a character class rather than through a pathspec.
#
# Found by v0.236.0 while extending the PR-class parser, whose own new `capture:`
# names are [A-Za-z][A-Za-z0-9_]* and therefore routinely end in `t`. The sweep
# was 22 sites with an FP set of ZERO -- every candidate was real, including the
# one that also carries `awk` on the same physical line, where the awk is a
# separate stage of the same pipeline and the `sed` is the violation.
#
# The needle is ASSEMBLED rather than written, so this file does not itself carry
# the construct it forbids and needs no exemption for its own definition site --
# an exemption is the thing this repo has learned to distrust most.
i71_needle="$(printf '[ %st]' '\')"
i71_scan() { # $1 = root -- prints `file:line` for every violating line
  grep -rn -F -- "$i71_needle" "$1" 2>/dev/null \
    | grep -E '(^|[^a-zA-Z0-9_])(sed|grep)([^a-zA-Z0-9_]|$)' \
    | cut -d: -f1,2 || true
}
# The probe proves BOTH directions in the same run, because "0 findings" and "the
# scanner is broken" are the same output. A sed line carrying the needle must be
# reported; an awk line carrying the same needle must NOT be, since that one is
# correct and reporting it would make this invariant an FP machine on 75 live
# sites. Built here rather than committed: a probe in the tree is a subject.
i71_probe="$(mktemp -d 2>/dev/null)"
if [ -n "$i71_probe" ] && [ -d "$i71_probe" ]; then
  printf 'X="$(sed -n %ss/^k:%s*//p%s f)"\n' "'" "$i71_needle" "'" > "$i71_probe/bad.sh"
  printf 'Y="$(awk %s{sub(/%s+/,"",$0); print}%s f)"\n' "'" "$i71_needle" "'" > "$i71_probe/ok.sh"
  i71_pos="$(i71_scan "$i71_probe" | grep -c 'bad\.sh' || true)"
  i71_neg="$(i71_scan "$i71_probe" | grep -c 'ok\.sh' || true)"
  rm -rf "$i71_probe"
  if [ "$i71_pos" -ne 1 ]; then
    err "I71's own probe was NOT reported: a sed expression carrying a bracket class with a backslash-t went unseen by the scanner, so a clean result below would mean nothing. The invariant fails closed rather than reporting an absence its instrument could not have found."
  fi
  if [ "$i71_neg" -ne 0 ]; then
    err "I71's negative probe WAS reported: an awk expression carrying the same bracket class was flagged, and awk's is correct. Shipping this would put 75 live and correct sites into the finding set, which is how a lint gets turned off."
  fi
fi
i71_hits="$(i71_scan "$REPO_ROOT/core"; i71_scan "$REPO_ROOT/scripts")"
if [ -n "$i71_hits" ]; then
  err "I71 sed or grep expression(s) using a bracket class that contains a literal backslash and t, which in a POSIX bracket expression is the CHARACTER SET rather than a tab:
$(printf '%s\n' "$i71_hits" | sed 's/^/  /')
Each one silently truncates any value ending in 't' or a backslash -- 'capture: sprint' becomes 'capture: sprin' with no error and no non-zero exit. Use [[:space:]]. If the expression is awk's, this invariant does not report it and something on the same physical line is invoking sed or grep."
fi

# --- I72: the PR-class grammar is ONE key set across the parser and the template
# vocabulary: PR-class taxonomy grammar keys
# vocabulary-invariant: I72
# vocabulary-owner: core/scripts/validate-cycle-commits.sh
# vocabulary-extract: pr-class-keys
# vocabulary-readers: core/skills/ai-dlc/templates/pr-classes.md
# The parser dispatches on a `case`; the template is what a consumer actually reads before
# writing a taxonomy. A key in one and not the other is silent in both directions and both
# directions have a victim:
#   parser-only   the key works and nobody knows it exists, so the obligation it expresses is
#                 kept in the consumer's own script -- which is the exact failure v0.236.0
#                 was written to end, arriving one level up as a documentation gap.
#   template-only the consumer writes the key, the parser's `*)` arm calls it unknown, and
#                 the taxonomy is MALFORMED -- so following core's own instructions wedges
#                 the audit.
# Both sides are DERIVED. A hand-listed key set is the thing this invariant exists to stop.
i72_parser="$(sed -n '/^    case "\$_key" in/,/^    esac/p' \
    "$REPO_ROOT/core/scripts/validate-cycle-commits.sh" 2>/dev/null \
  | grep -oE '^      [a-z|]+\)' | tr -d ' )' | tr '|' '\n' | grep -v '^\*$' | sort -u)"
i72_tpl="$(sed -n '/^## The grammar/,/^### /p' \
    "$REPO_ROOT/core/skills/ai-dlc/templates/pr-classes.md" 2>/dev/null \
  | grep -oE '^- `[a-z]+:' | tr -d '`-: ' | sort -u)"
i72_np="$(grep -c . <<<"$i72_parser" || true)"
i72_nt="$(grep -c . <<<"$i72_tpl" || true)"
if [ "$i72_np" -lt 2 ] || [ "$i72_nt" -lt 2 ]; then
  err "I72's extractors read $i72_np parser key(s) and $i72_nt template key(s). Fewer than two on either side means an extractor stopped matching, not that the grammar shrank -- and an empty set agrees with every other empty set, so this fails closed rather than reporting agreement it did not compute."
else
  i72_only_p="$(comm -23 <(printf '%s\n' "$i72_parser") <(printf '%s\n' "$i72_tpl") | tr '\n' ' ')"
  i72_only_t="$(comm -13 <(printf '%s\n' "$i72_parser") <(printf '%s\n' "$i72_tpl") | tr '\n' ' ')"
  if [ -n "${i72_only_p// /}" ]; then
    err "I72 the PR-class parser dispatches key(s) the template never documents: ${i72_only_p}. A consumer writes its taxonomy from that template, so a key only the parser knows is an obligation nobody can declare -- and keeping an obligation undeclarable is what left 364 lines in the reference consumer's own script."
  fi
  if [ -n "${i72_only_t// /}" ]; then
    err "I72 the PR-class template documents key(s) the parser does not dispatch: ${i72_only_t}. Following core's own instructions would produce 'unknown key' and a MALFORMED taxonomy, which audits nothing and exits 1."
  fi
fi

# --- I54: no shell variable is written into an EARLY-EXITING reader ------------
# `grep -q` stops at its first match. Under `set -o pipefail` the pipeline's status
# is then the WRITER's, and a writer that still had bytes to push gets EPIPE and
# exits non-zero -- so the `if` takes the branch for "not found" on input where the
# pattern WAS found. Measured on this machine: with the match near the start of a
# 64 KiB input, 300 of 300 runs reported not-found; the same test reading the value
# as a here-string reported found 300 of 300. The threshold is the pipe buffer and
# it does not move under load (32 KiB correct, 64 KiB wrong, idle and at -P24
# alike), so this is a size trap rather than a race -- which is worse, because a
# value that grows past the buffer switches the check off permanently and silently.
#
# In a POSITIVE assertion this shows up as a puzzling FAIL, which someone chases.
# In a NEGATIVE one -- match means the tree is bad -- it is a permanent PASS, which
# is this repo's named defect class with no symptom at all.
#
# The remedy has no pipe: read the value as a here-string. There is no legitimate
# reason to prefer the pipe here, and no `#!/bin/sh` script in this tree, so `<<<`
# is always available. The subject set is deliberately NARROW: a builtin writing a
# shell variable. `cmd | grep -q` is fine when cmd is short-lived, and banning it
# outright would be the unmeasured lint CLAUDE.md warns about.
#
# The grammar is assembled from fragments and the messages DESCRIBE the shape
# rather than reproducing it. This scan covers core/fixtures/, so a literal here
# -- or in the fixture that proves this fires -- would report itself.
# Walked from REPO_ROOT rather than asked of git, for the same reason every other
# invariant here resolves that way: this script runs inside seeded fixture trees
# that are not repositories, and `git ls-files` answers EMPTY there -- which would
# trip the zero guard below on every assertion in enforcement-map-sites rather
# than on a real defect. A walk also sees a script that is written but not yet
# added, which is exactly when this idiom gets introduced.
i54_files="$(find "$REPO_ROOT" -name .git -prune -o -type f -name '*.sh' -print 2>/dev/null)"
i54_n="$(printf '%s\n' "$i54_files" | grep -c .)"
i54_fmt="'%""s'"
i54_re="(printf[[:space:]]+${i54_fmt%\'}(\\\\n)?'|echo)[[:space:]]+\"[^\"]*\"[[:space:]]*[|][[:space:]]*grep[[:space:]]+-[A-Za-z]*q"
# A grammar that matches nothing reads exactly like a clean tree, so it is tested
# against a probe of the banned shape and a probe of the permitted one, both built
# here, before its verdict on the tree is believed.
i54_probe_bad="if printf ${i54_fmt} \"\$v\" | grep -q TOKEN; then"
i54_probe_ok='git log --oneline | grep -q TOKEN'
# A COMMENT IS NOT A SITE, and this arm shipped for eleven releases without that test.
# Measured: a fixture added in v0.357.0 quoted the banned idiom in a comment warning the
# next author away from it, and was reported as carrying it. That is the failure direction
# that gets a check switched off -- and the remedy the author reaches for first is to
# reword the warning, which deletes the documentation the arm's own message asks for.
# I54b, forty lines below, has carried this exact test since it was written (`a comment is
# not a site`), and I87 carries it on a different corpus for the same measured reason. This
# is that test, not a second approach to it.
#
# ANCHORED, AND ONLY ANCHORED. A `#` mid-line opens a comment only when it is not inside a
# quote, and deciding that needs a quote-aware reader. An unanchored strip would drop any
# line whose match sits after a `#` in a string -- a false NEGATIVE, which is the direction
# that switches the check off silently, and the one this repo names as its defect class.
# So a banned site written after a trailing `#` is still reported; the tree carries zero of
# those today, measured over its whole .sh corpus against this arm's own grammar.
#
# THE GRAMMAR CROSSES INTO awk THROUGH ENVIRON, NEVER THROUGH -v, AND THAT IS MEASURED.
# awk expands escape sequences in a -v VALUE, and this grammar carries the fragment that
# admits a trailing-newline format. Same regex, same two files, one reader each:
#
#   reader                  printf with a bare format    printf with a newline format
#   grep -E (the original)  hit                          hit
#   awk, ENVIRON            hit                          hit
#   awk, -v                 hit                          MISS
#
# The -v row is the whole class this repo is named for: half the grammar goes quiet and the
# arm prints a clean line over the half of the tree it can no longer see. So the live probe
# below carries BOTH formats, and asserts on the COUNT. One probe file of the bare form
# alone cannot tell the two readers apart -- it is the row where they agree.
#
# The probes run through the SAME reader as the corpus scan, so a transfer that broke the
# grammar takes them down with it rather than reporting a clean tree.
i54_awk='
  /^[[:space:]]*#/ { next }
  $0 ~ ENVIRON["I54_RE"] { print FILENAME ":" FNR ":" $0 }
'
i54_scan() {   # NUL-separated file list on stdin -> path:line:text per live banned site
  I54_RE="$i54_re" xargs -0 awk "$i54_awk" 2>/dev/null
}
# The probe FILES are written from the assembled fragments, never from a literal, for the
# reason stated above: this scan covers this file.
i54_fmt_nl="${i54_fmt%\'}"'\n'"'"
i54_probe_bad_nl="if printf ${i54_fmt_nl} \"\$v\" | grep -q TOKEN; then"
i54_pd="$(mktemp -d)"
printf '%s\n' '#!/usr/bin/env bash' \
  "$i54_probe_bad" ' :; fi' "$i54_probe_bad_nl" ' :; fi' > "$i54_pd/live.sh"
printf '%s\n' '#!/usr/bin/env bash' "#   never write this: $i54_probe_bad" > "$i54_pd/commented.sh"
i54_p_live="$(printf '%s\0' "$i54_pd/live.sh" | i54_scan)"
i54_p_live_n="$(printf '%s\n' "$i54_p_live" | grep -c .)"
i54_p_cmt="$(printf '%s\0' "$i54_pd/commented.sh" | i54_scan)"
rm -rf "$i54_pd"
if [ "$i54_n" -eq 0 ]; then
  err "I54 enumerated ZERO tracked .sh files under $REPO_ROOT. It reports an ABSENCE -- that no shipped script writes a variable into an early-exiting reader -- and an absence over an empty corpus is not a finding. Fails closed."
elif ! grep -qE "$i54_re" <<<"$i54_probe_bad"; then
  err "I54's grammar no longer matches the shape it bans, tested against a probe built in this script. Every tree passes it now, including one full of the defect. Fix the grammar or retire the invariant; do not leave it printing a clean line."
elif grep -qE "$i54_re" <<<"$i54_probe_ok"; then
  err "I54's grammar matches an ordinary command piped into grep -q, which is permitted and common. As written it would report a false positive on nearly every script in the tree. Narrow it back to a builtin writing a shell variable."
elif [ "$i54_p_live_n" -ne 2 ]; then
  err "I54's reader reported ${i54_p_live_n} of the 2 LIVE banned sites in a probe file this script wrote itself -- one per printf format the grammar admits, the bare one and the trailing-newline one. The corpus scan below runs that same reader, so its verdict on the tree is a set produced by a reader that cannot see the whole defect, and a half-blind reader prints the same clean line as a clean tree. At ONE hit the likeliest cause is the grammar losing its trailing-newline half on the way into awk: it must cross through ENVIRON, never through -v, which expands escape sequences in the value. At zero, the grammar did not survive the transfer at all."
elif [ -n "$i54_p_cmt" ]; then
  err "I54 reported a probe file whose only banned line is a COMMENT [reader answered: $i54_p_cmt]. The comment exclusion was derived from a measured false positive -- a fixture quoting the idiom in order to warn against it -- and without it this arm fires on the documentation it asks people to write, which is how a check gets switched off."
else
  i54_hits="$(printf '%s\n' "$i54_files" | tr '\n' '\0' | i54_scan | sed "s@^${REPO_ROOT}/@@")"
  if [ -n "$i54_hits" ]; then
    i54_c="$(printf '%s\n' "$i54_hits" | grep -c .)"
    err "I54 found ${i54_c} site(s) writing a shell variable into a grep that stops at its first match, across ${i54_n} tracked shell files:
$(printf '%s\n' "$i54_hits" | cut -c1-160)
Under pipefail the pipeline reports the WRITER's status, so once the value passes the pipe buffer (64 KiB here) the test answers 'not found' on input that contains the pattern -- permanently, not intermittently. Where a match means the tree is BAD, that is a check that can no longer fire and a suite that goes green without looking. Read the value as a here-string instead: the redirect goes at the end of the grep command and the pipe disappears. Every one of these was converted in v0.207.0; a new one means the idiom came back."
  fi
fi

# --- I54b: nor does any PIPELINE, where the status is load-bearing -------------
# requires-arms: I54
# The arm above bans one WRITER -- a builtin pushing a shell variable -- and it
# requires the reader to be the IMMEDIATELY next stage. Both halves of that are
# narrower than the defect, and the tree had 17 sites in the gap:
#
#   a COMMAND's output into the reader   git show REF:path | <reader>
#   one filter in between                printf ... "$v" | awk ... | <reader>
#
# Neither is a variant of the guarded form. Each is outside its subject set BY
# CONSTRUCTION, which is why v0.207.0's 300-site sweep did not end the class and
# why the arm above kept printing a clean line over a tree that carried it.
#
# WHAT MADE THIS SHIPPABLE IS THE TWO NARROWINGS, AND BOTH ARE DERIVED FROM THE
# FILE RATHER THAN HAND-LISTED. A plain ban on a pipe into a first-match reader
# is the unmeasured lint CLAUDE.md warns about -- 43 sites, most of them correct.
#
#   1. The file must enable pipefail. Without it the pipeline's status is the
#      READER's alone and the writer's EPIPE is discarded, so the construct is
#      simply correct. Measured behaviourally, not argued: the same 200 KB input
#      answers TRUE under `set -u` and FALSE under `set -uo pipefail`.
#   2. The status must be load-bearing -- a conditional keyword, `&&`, `||` or a
#      negation. A pipeline whose status nothing reads cannot mislead anything.
#
# Together they cut 43 candidate sites to 17, all 17 were converted, and the arm
# now reports zero over a corpus where the unnarrowed grammar would report 28.
#
# THE FALSE-POSITIVE SET IS EMPTY AND THAT IS A MEASUREMENT, NOT A CLAIM. Every
# `grep -q` reading a pipe in this tree was instrumented across a whole suite run
# plus the validators -- 6,737 calls. The number that decides the hazard is the
# bytes sitting AFTER the first match, because that is what the writer still has
# to push when the reader leaves: median 24, max 1,885, and ZERO above the 65,536
# -byte buffer. The control in the same run is the one call that DID exceed it,
# the early-exit-reader fixture's own 200 KB probe, so the zero is a reading and
# not a blind instrument.
#
# So no site in this tree is a LIVE defect today, and the arm is still worth its
# lines for the reason the arm above already gives: the threshold is a SIZE, so a
# site that is safe at 24 bytes switches the check off permanently and silently
# the day its input grows. Seventeen latent inversions, each one token to remove.
#
# `head -N` and `read` were measured in the same pass and are REFUTED as members:
# `| read` has no sites at all, and of 118 `| head -N` sites exactly one sits in a
# file combining `set -e` with pipefail -- the only mode where head's early exit
# can bite -- and that one's upstream emits a single line. Recorded so a fourth
# instance does not re-derive it.
#
# The grammar is assembled from fragments and every probe is built at runtime, for
# the reason the arm above states: this scan covers its own file.
i54b_rd="gre""p"
i54b_pf_re="^[[:space:]]*set[[:space:]]+-[a-zA-Z]*[[:space:]]*pipefail"
i54b_re="[^|][|][[:space:]]*${i54b_rd}[[:space:]]+(-[A-Za-z]*q[A-Za-z]*|--quiet)([[:space:]]|\$)"
i54b_st_re="(^|[[:space:]])(if|elif|while|until)[[:space:]]|&&|[|][|]|![[:space:]]"
# Probes, all four tested before the verdict on the tree is believed. A grammar
# that matches nothing and a narrowing that excludes everything both read exactly
# like a clean tree.
i54b_p_bad="if git show REF:p | ${i54b_rd} -q TOKEN; then"
i54b_p_here="if ${i54b_rd} -q TOKEN <<<\"\$(git show REF:p)\"; then"
i54b_p_or="${i54b_rd} -q A f || ${i54b_rd} -q B f"
i54b_p_free="git log | ${i54b_rd} -q TOKEN"
if ! grep -qE "$i54b_re" <<<"$i54b_p_bad"; then
  err "I54b's grammar no longer matches a pipeline feeding a reader that stops at its first match, tested against a probe built in this script. Every tree passes it now, including one full of the defect."
elif grep -qE "$i54b_re" <<<"$i54b_p_here"; then
  err "I54b's grammar matches the very form it tells people to convert TO. It would report every remediated site, which is the unmeasured lint that gets switched off."
elif grep -qE "$i54b_re" <<<"$i54b_p_or"; then
  err "I54b's grammar reads a shell OR as a pipe. Two guarded readers joined by || carry no pipeline at all, so every such line would be reported and none of them is a defect."
elif grep -qE "$i54b_st_re" <<<"$i54b_p_free"; then
  err "I54b's load-bearing-status narrowing matches a pipeline whose status nothing reads. The narrowing is what keeps this arm off the 26 correct sites in this tree; without it the arm is a blanket ban."
elif ! grep -qE "$i54b_pf_re" <<<"set -uo pipefail"; then
  err "I54b's pipefail detector does not recognise the form this repo actually writes, tested against a probe built in this script. It would exclude every file and the arm would report a clean tree by excluding all of it."
elif grep -qE "$i54b_pf_re" <<<"set -u"; then
  err "I54b's pipefail detector fires on a file that does NOT enable pipefail. That file's pipeline reports the reader's status alone and the construct is correct there, so the arm would report sites that cannot misbehave."
else
  # ONE awk pass over the whole corpus -- no fork per file, and no second grep
  # for the pipefail set. §7's gate item 2 says to read each corpus once and
  # answer every question from the index; this arm runs on every push.
  #
  # IT JOINS BACKSLASH CONTINUATIONS FIRST, AND THAT IS NOT TIDINESS. A first cut
  # classified PHYSICAL lines and read three sites as status-free because their
  # `&&` sat on the next one:
  #
  #     lstat "$m" | <reader> "..." \
  #       && bad "the mutant did not fire" \
  #       || ok  "MUTANT killed"
  #
  # The status there decides whether a MUTANT SCORES A KILL, so a false "not
  # found" awards one that was never earned -- this repo's named defect, reached
  # through the check written to catch it. A per-line narrowing cannot see it,
  # so the unit of classification is the LOGICAL line and the reported number is
  # the line it starts on.
  i54b_hits="$(printf '%s\n' "$i54_files" | tr '\n' '\0' \
    | xargs -0 awk -v pfre="$i54b_pf_re" -v re="$i54b_re" -v stre="$i54b_st_re" '
        FNR == 1 { buf = ""; start = 0 }
        {
          if (FILENAME != seen_f) { seen_f = FILENAME; files[++nf] = FILENAME }
          if ($0 ~ pfre) pf[FILENAME] = 1
          line = $0
          if (buf != "") { buf = buf " " line } else { buf = line; start = FNR }
          if (line ~ /\\[[:space:]]*$/) next        # logical line continues
          body = buf; buf = ""
          if (body ~ /^[[:space:]]*#/) next         # a comment is not a site
          if (body !~ re) next
          if (body !~ stre) next                    # narrowing 2: status not load-bearing
          hits[++nh] = FILENAME ":" start
          hitf[nh]  = FILENAME
        }
        END {
          for (i = 1; i <= nh; i++)
            if (hitf[i] in pf) print hits[i]        # narrowing 1: no pipefail, no defect
        }' 2>/dev/null | sed "s@^${REPO_ROOT}/@@")"
  if [ -n "$i54b_hits" ]; then
    i54b_c="$(printf '%s\n' "$i54b_hits" | grep -c .)"
    err "I54b found ${i54b_c} pipeline(s) feeding a reader that stops at its first match, in a file that enables pipefail and on a line whose status decides something:
$(printf '%s\n' "$i54b_hits" | cut -c1-160)
The reader leaves at its first match and the writer is still pushing, so under pipefail the pipeline answers with the WRITER's EPIPE and the test reports 'not found' on input that contains the pattern. It is a SIZE threshold, not a race: correct until the upstream's output after the match passes the pipe buffer, then wrong permanently and with no symptom. Remove the pipe -- put the upstream in a command substitution and feed the reader a here-string. Seventeen sites were converted that way in v0.231.0 and the false-positive set was empty; a new one means the idiom came back through the writer or the intermediate stage this arm exists to see."
  fi
fi

# --- I55: what the suite's content key does NOT cover stays uncovered ----------
# The pre-push hook skips the fixture suite when a content key over the tree is
# unchanged since the last fully green run. That is a check that did not run, and
# a check that did not run reads exactly like one that passed -- so the one thing
# holding it up is that the key covers a SUPERSET of the suite's inputs. It does
# that by including everything except a short declared exclusion set, measured at
# authoring time by overwriting every excluded path and showing all 84 verdicts
# unchanged.
#
# A measurement taken once decays. This is the durable half: it fails the build if
# the declaration drifts from the tree, or if a fixture starts reaching for an
# excluded path at the DISTRIBUTION root -- which is the move that would turn an
# excluded path into a suite input without anyone re-taking the measurement.
#
# Arm 3's subject set is core/fixtures/ and not the whole tree, and that is
# deliberate rather than lazy. `core/scripts/validate-artifact-budget.sh` and
# `validate-ci-gates.sh` both name "$ROOT/docs", but their ROOT is the CONSUMER
# project they are pointed at, which in every fixture that drives them is a
# sandbox; scanning them would report 4 false positives. The fixtures are where a
# subject set is chosen, so that is where the grammar reads. FP set measured
# EMPTY at authoring time against a control of 172 matches for an INCLUDED path
# under the identical grammar.
#
# WHAT ARM 3 DOES NOT SEE, stated rather than implied: a fixture that hands the
# distribution root to a shipped validator as a project argument, without naming
# an excluded path itself. None exists today. The release says so too.
i55_key_script="$REPO_ROOT/scripts/suite-content-key.sh"
i55_hook="$REPO_ROOT/.githooks/pre-push"
if [ ! -f "$i55_key_script" ]; then
  err "I55 cannot find scripts/suite-content-key.sh. The pre-push hook skips the whole fixture suite on that script's verdict; with the script gone the hook falls back to a full run, but this invariant is then guarding a declaration that no longer exists and would pass over any exclusion set at all. Restore it, or retire I55 and the skip together."
elif [ ! -f "$i55_hook" ]; then
  err "I55 cannot find .githooks/pre-push, the one consumer of the content key. Restore it, or retire I55."
else
  i55_excl="$(sed -n '/^# EXCLUDE_BEGIN$/,/^# EXCLUDE_END$/p' "$i55_key_script" \
              | sed -n 's/^\([A-Za-z._][A-Za-z0-9._/-]*\)$/\1/p')"
  i55_n="$(printf '%s\n' "$i55_excl" | grep -c .)"
  if [ "$i55_n" -eq 0 ]; then
    err "I55 parsed ZERO entries out of suite-content-key.sh's EXCLUDE block. Every arm below then compares against an empty set and reports agreement it never computed -- and an empty exclusion set is indistinguishable here from a correct one. Fails closed: fix the markers or the grammar."
  else
    # Arm 1: every exclusion is a bare TOP-LEVEL name. suite-content-key.sh filters
    # by exact string equality against `ls -A`, so `docs/analysis` or `*.md` matches
    # no entry and excludes nothing -- while reading, to the author and to every
    # reviewer after them, exactly like an exclusion that took effect. That is this
    # repo's named defect class inside the declaration that the rest of I55 guards.
    # Deliberately tree-independent: this invariant also runs inside seeded fixture
    # trees that carry no docs/ or .git, where an existence test would fire on the
    # pristine seed and take every other assertion with it.
    i55_shape=""
    while IFS= read -r e; do
      [ -n "$e" ] || continue
      case "$e" in
        */*|*'*'*|*'?'*|*'['*) i55_shape="${i55_shape} $e" ;;
      esac
    done <<<"$i55_excl"
    [ -n "$i55_shape" ] && err "I55 suite-content-key.sh excludes entr(ies) that are not bare top-level names:${i55_shape}. That filter compares each entry for exact string equality against a top-level listing, so a path with a slash or a glob matches nothing and excludes nothing -- the declaration reads as coverage removed and removes none. Name the top-level entry, or teach the filter the shape you meant."

    # Arm 2: .git must stay excluded. Not a fidelity matter -- the opposite. The
    # object store changes on every commit, so including it makes the key miss
    # every time and the machinery becomes 0.3s of dead weight nobody notices.
    grep -qx '\.git' <<<"$i55_excl" || err "I55 suite-content-key.sh no longer excludes .git. The object store changes on every commit, so the key can never match a previous run and the suite skip is now unreachable code that still prints. Re-exclude it; the one thing inside .git the suite reads -- the tracked path set -- is already folded in as the key's 'tracked' component."

    # Arm 3: no fixture reaches an excluded path at the DISTRIBUTION root.
    i55_roots='(REPO_ROOT|ROOT|D_ROOT|C_ROOT)'
    i55_ctl="$(grep -rhoE '\$\{?'"$i55_roots"'\}?/core([/"]|$)' "$REPO_ROOT"/core/fixtures/*/*.sh 2>/dev/null | grep -c .)"
    if [ "${i55_ctl:-0}" -lt 10 ]; then
      err "I55 arm 3's control found only ${i55_ctl:-0} reference(s) to an INCLUDED path under the same grammar it uses to report an absence. It is about to report that no fixture names an excluded path at the distribution root; over a corpus this grammar cannot read, that zero is a broken matcher and not a finding. Fails closed."
    else
      i55_reach=""
      while IFS= read -r e; do
        [ -n "$e" ] || continue
        [ "$e" = ".git" ] && continue
        i55_hit="$(grep -rHnoE '\$\{?'"$i55_roots"'\}?/'"$(printf '%s' "$e" | sed 's/\./\\./g')"'([/"'"'"' ]|$)' \
                   "$REPO_ROOT"/core/fixtures/*/*.sh 2>/dev/null | sed "s@^${REPO_ROOT}/@@")"
        [ -n "$i55_hit" ] && i55_reach="${i55_reach}
${i55_hit}"
      done <<<"$i55_excl"
      [ -n "$i55_reach" ] && err "I55 fixture(s) reach a content-key-EXCLUDED path at the distribution root:${i55_reach}
The pre-push hook skips the entire fixture suite when the key is unchanged, and the key does not hash those paths -- so a fixture reading one is a fixture whose input can change without the suite ever re-running. Either stop reading it, or delete its line from suite-content-key.sh's EXCLUDE block and re-take the mutation measurement recorded in that script's header."
    fi

    # Arm 4: EVERY cross-run record the hook keeps lives outside the working tree. A
    # record inside it would be hashed by the key it stores, so writing it would
    # invalidate that key and no push could ever hit -- the machinery would run forever
    # and never pay.
    #
    # THE SUBJECT SET IS DERIVED, and v0.229.0 is why. This arm read one hand-named
    # variable, `KEY_RECORD`, for as long as the hook kept one record. The LPT dispatch
    # order added a SECOND -- `DURATIONS_RECORD`, written once per run for the next run
    # to schedule on -- and a hand-named arm would have gone on reporting green about
    # the first while the second sat wherever it was put. The prohibition is the same
    # for both, so the grammar names the SHAPE and the arm inherits every record the
    # hook grows. A third one is covered the moment it is written.
    i55_recs="$(sed -n 's/^\([A-Z][A-Z0-9_]*_RECORD\)="\(.*\)"$/\1 \2/p' "$i55_hook")"
    if [ -z "$i55_recs" ]; then
      err "I55 found no <NAME>_RECORD= assignment in .githooks/pre-push. This arm exists to prove every cross-run record the hook keeps lives outside the tree its own content key hashes; over an empty subject set it proves nothing and prints exactly what a pass prints. Fails closed: either a record was renamed out of this grammar, or the machinery it guards is gone and this arm should be retired with it."
    else
      i55_badrec=""
      while IFS=' ' read -r i55_rn i55_rv; do
        [ -n "$i55_rn" ] || continue
        case "$i55_rv" in
          .git/*) : ;;
          *) i55_badrec="${i55_badrec} ${i55_rn}='${i55_rv}'" ;;
        esac
      done <<<"$i55_recs"
      [ -n "$i55_badrec" ] && err "I55 .githooks/pre-push keeps a cross-run record inside the working tree:${i55_badrec}. suite-content-key.sh hashes that tree, so a file the hook writes there is part of the key it is trying to match: the key moves on every run, every push misses, and the suite skip becomes machinery that can never fire. Put it under .git/, which the key's exclusion set already accounts for."
    fi
  fi
fi

# --- I56: the model pin is ONE rule across the dispatch guard and the gate -----
# `core/hooks/ai-dlc-dispatch-guard.sh` resolves a role's pin at PreToolUse and binds
# the teammate's model to it. `core/scripts/validate-spawn-ledger.sh` re-asks the same
# question at the gate for Check 22 -- is the model each recorded spawn actually ran on
# the one its role's config pins. The two must agree on what the pin IS (`pin_key`) and
# on when a value matches it (`matches_pin`), or a spawn the guard corrected clears the
# gate, or one it bound correctly fails it, and the operator believes whichever ran.
#
# Same shape as I25 and I40, and a COPY rather than a sourced helper for I25's reason:
# a guard that sources a helper stops binding models entirely when a partial install
# omits it -- fail-open, silently -- and a disabled dispatch guard is far worse than
# two bound copies of eleven lines.
#
# ARM 2 IS NOT DECORATION. Before v0.211.0 the guard carried TWO definitions of
# `matches_pin()`, verbatim apart from one word of comment, the first shadowed and
# dead. Nothing was looking, and a range-extraction like arm 1's silently concatenates
# both spans -- so a second definition does not fork the comparison, it breaks the
# check that would have caught a fork. Count first, then compare.
i56_guard="$REPO_ROOT/core/hooks/ai-dlc-dispatch-guard.sh"
i56_val="$REPO_ROOT/core/scripts/validate-spawn-ledger.sh"
if [ ! -f "$i56_guard" ] || [ ! -f "$i56_val" ]; then
  err "I56 cannot find core/hooks/ai-dlc-dispatch-guard.sh and/or core/scripts/validate-spawn-ledger.sh. It binds the dispatch-time model pin to the gate-time one; with either file gone it compares nothing and reports agreement it never computed."
else
  for i56_f in pin_key matches_pin; do
    i56_ng="$(grep -c "^${i56_f}() {" "$i56_guard" || true)"
    i56_nv="$(grep -c "^${i56_f}() {" "$i56_val" || true)"
    if [ "$i56_ng" != 1 ] || [ "$i56_nv" != 1 ]; then
      err "I56 expected exactly one ${i56_f}() definition in each of ai-dlc-dispatch-guard.sh (found ${i56_ng}) and validate-spawn-ledger.sh (found ${i56_nv}). Zero means the binding below extracts nothing and passes vacuously; more than one means the later definition silently shadows the earlier, the byte-identity arm compares two spans against one, and a genuine fork could hide behind a duplicate. This is the exact state the guard shipped in until v0.211.0."
      continue
    fi
    i56_a="$(awk "/^${i56_f}\(\) \{/,/^\}/" "$i56_guard" 2>/dev/null)"
    i56_b="$(awk "/^${i56_f}\(\) \{/,/^\}/" "$i56_val" 2>/dev/null)"
    if [ -z "$i56_a" ] || [ -z "$i56_b" ]; then
      err "I56 located a ${i56_f}() definition line in both files but extracted an EMPTY body from at least one. The comparison below would pass on two empty strings, so it fails here instead."
    elif [ "$i56_a" != "$i56_b" ]; then
      err "the model pin has forked between ai-dlc-dispatch-guard.sh and validate-spawn-ledger.sh at ${i56_f}(). One decides at dispatch what a teammate runs on, the other decides at the gate whether that was right; a rule that differs between them means Check 22 clears a spawn the guard corrected, or fails one it bound correctly. Make ${i56_f}() byte-identical."
    fi
  done
fi

# --- I57: a check that tells the lead an exit code decides it names its enforcer ---
# The row-10b class, generalised. Three releases (v0.209.0 Check 16, v0.210.0 Check 18,
# v0.211.0 Check 22) each found the same defect one instance at a time: a check whose own
# body publishes a MECHANICAL predicate -- run this validator, exit 0 required -- while its
# enforcement-map row says nothing enforces it. The map is the one artifact that answers
# "what actually enforces this check", so an unbound predicate is a check the efficacy audit
# reads as adjudicated prose and the operator reads as a paragraph to re-perform at every
# gate. This ends the class instead of the next instance.
#
# The SUBJECT is not "a check that mentions a validator". Naming a validator is not being
# enforced by it, and the map has three legitimate ways to name one that is not the
# predicate: `reads:` (a delegation the bound script makes internally), a producer the check
# describes, and the remedy a check offers on FAIL. Measured over gate-validation.md at
# v0.211.0, 35 citations sit inside check bodies and only 12 are predicates.
#
# THE DISCRIMINATOR IS THE FORM OF THE SENTENCE, NOT THE CITATION. A predicate asserts that
# an exit code binds the gate -- "exit 0 required", "this check FAILS", "Check 15 FAILS" --
# where a delegation publishes a code LEGEND ("exit 0 = dropped, exit 1 = consumer-owned")
# and a remedy sits under an On-FAIL heading. Both non-predicate forms cite a validator in
# an imperative sentence, so an imperative-verb scan does not separate them; the exit-code
# POSTURE does. Measured false-positive set: EMPTY. 12 selected, 10 already bound, 2 real
# (both stamp-story-provenance.sh --check at Check 17, bound in the same release).
#
# THE POSTURE REGEX WAS CASE-SENSITIVE ON ONE ALTERNATIVE AND NOT THE OTHER (v0.357.0). The
# `FAILS` alternative had always been written `[Cc]heck`; the exit-code alternative was a bare
# `exits?`, so a check body ending its sentence at the clause boundary -- `. Exit 0 required.`
# rather than `; exit 0 required.` -- was INVISIBLE to arm 1. That is an author stepping
# outside a grammar without meaning to, in a file whose sentences are wrapped and re-flowed
# constantly, and it is not detectable by reading the invariant: both spellings look correct.
#
#   MEASURED on gate-validation.md:  lowercase `exit N required`   12   (selected)
#                                    capitalised `Exit N required`  2   (INVISIBLE)
#
# The two were Check 26 -- the fail-closed check through which the lead adopts EVERY
# adjudication:llm verdict -- and Check 30. LATENT, NOT LIVE, and the difference matters for
# how this is written up: both rows were bound anyway (26 -> validate-gate-adjudication.sh,
# 30 -> validate-spec-join.sh, both confirmed by reading the map rows), so no wrong PASS was
# ever emitted. What the hole cost was the ability to NOTICE if either row were removed.
#
# FALSE-POSITIVE MEASUREMENT OF THE WIDENING, which is the part that is not optional, since
# widening a selector adds rows to the subject set and every added row must genuinely bind:
# the LIVE i57_awk was extracted from this file and run against gate-validation.md with both
# regexes. Before 15 pairs, after 17, newly selected EXACTLY `26 validate-gate-adjudication.sh`
# and `30 validate-spec-join.sh`, nothing lost (the widening is strictly additive), and the
# full validator run with the widened grammar emits ZERO I57 findings. No row was bound to
# make the lint quiet and the grammar was not narrowed back.
#
# TWO RESOLUTIONS THE NAIVE JOIN GETS WRONG, and each produced phantom findings before it
# was added. (i) `verdict.sh` is a DISPATCHER -- `verdict.sh <validator> [args]` -- so the
# citation's basename is the wrapper and the enforcer is its first argument; without this,
# Checks 2 and 26 report unbound while their rows bind the dispatched validator correctly.
# (ii) A `non_catalog_units:` row can bind a validator and name the check as a `call_sites:`
# site, which is how the artifact-budget unit binds Checks 14 and 15; the binding is real and
# reviewable, just not on the check's own row. Five of the eight pairs a basename-only join
# reports are these two shapes, not defects.
i57_awk='
function base(p) { sub(/^.*\//, "", p); return p }
{ line[NR] = $0 }
END {
  cur = ""
  for (i = 1; i <= NR; i++) {
    if (line[i] ~ /^<!-- CHECK_LOADED: [^ ]+ -->/) {
      id = line[i]; sub(/^<!-- CHECK_LOADED: /, "", id); sub(/ -->.*$/, "", id)
      if (id != "<id>") cur = id
      owner[i] = ""
      continue
    }
    owner[i] = cur
  }
  for (i = 1; i <= NR; i++) {
    if (owner[i] == "") continue
    n = 0
    t = line[i]
    while (match(t, /scripts\/ai-dlc\/verdict\.sh[ \t]+[A-Za-z0-9._-]+/)) {
      m = substr(t, RSTART, RLENGTH); sub(/^scripts\/ai-dlc\/verdict\.sh[ \t]+/, "", m)
      if (m !~ /\.sh$/) m = m ".sh"
      names[++n] = m
      t = substr(t, RSTART + RLENGTH)
    }
    t = line[i]
    while (match(t, /scripts\/ai-dlc\/[A-Za-z0-9._-]+\.sh/)) {
      m = base(substr(t, RSTART, RLENGTH))
      if (m != "verdict.sh") names[++n] = m
      t = substr(t, RSTART + RLENGTH)
    }
    if (n == 0) continue
    a = i; b = i
    while (a > 1) {
      if (line[a-1] ~ /^[ \t]*$/) {
        if (a-2 >= 1 && (line[a-2] ~ /^    / || line[a] ~ /^    /)) { a--; continue }
        break
      }
      a--
    }
    while (b < NR) {
      if (line[b+1] ~ /^[ \t]*$/) {
        if (b+2 <= NR && (line[b+2] ~ /^    / || line[b] ~ /^    /)) { b++; continue }
        break
      }
      b++
    }
    posture = 0
    for (j = a; j <= b; j++)
      if (line[j] ~ /[Ee]xits?[ ]+[0-9][ ]+required/ || line[j] ~ /[Cc]heck([ ]+[0-9A-Za-z]+)?[ ]+FAILS/)
        posture = 1
    if (posture) for (k = 1; k <= n; k++) print owner[i] "\t" names[k]
    for (k = 1; k <= n; k++) delete names[k]
  }
}'

# The binding side: OWN rows come from the check itself, SITE rows from a
# non_catalog_units enforcer whose call_sites names a gate-validation.md check.
i57_map_awk='
function base(p) { sub(/^.*\//, "", p); return p }
function flush(  ne, ns, ii, jj, ea, sa, cid, s) {
  if (id == "") return
  ne = split(enf, ea, "\n")
  if (blk == "c") {
    for (ii = 1; ii <= ne; ii++) if (ea[ii] != "") print "OWN\t" id "\t" base(ea[ii])
  } else {
    ns = split(sites, sa, "\n")
    for (ii = 1; ii <= ne; ii++) {
      if (ea[ii] == "") continue
      for (jj = 1; jj <= ns; jj++) {
        s = sa[jj]
        if (s !~ /gate-validation\.md/) continue
        cid = s
        sub(/^.*gate-validation\.md[ \t]+/, "", cid)
        sub(/^[Cc]heck[ \t]+/, "", cid)
        sub(/[^0-9A-Za-z-].*$/, "", cid)
        if (cid != "") print "SITE\t" cid "\t" base(ea[ii])
      }
    }
  }
  enf = ""; sites = ""
}
/^checks:/            { flush(); blk = "c"; id = ""; fld = ""; next }
/^non_catalog_units:/ { flush(); blk = "n"; id = ""; fld = ""; next }
blk == "" { next }
/^  - id:/ {
  flush()
  id = $0; sub(/^  - id:[ \t]*/, "", id); gsub(/"/, "", id); sub(/[ \t]*#.*$/, "", id)
  fld = ""
  next
}
/^    [a-z_]+:/ {
  fld = $0; sub(/:.*$/, "", fld); gsub(/[ \t]/, "", fld)
  v = $0; sub(/^    [a-z_]+:[ \t]*/, "", v); sub(/[ \t]+#.*$/, "", v); gsub(/"/, "", v)
  if (fld == "enforcer" && v != "" && v !~ /^\[/) enf = enf v "\n"
  next
}
/^      - site:/ {
  if (fld == "call_sites") { v = $0; sub(/^      - site:[ \t]*/, "", v); sites = sites v "\n" }
  next
}
/^      - / {
  if (fld == "enforcer") { v = $0; sub(/^      - /, "", v); sub(/[ \t]+#.*$/, "", v); gsub(/"/, "", v); enf = enf v "\n" }
  next
}
END { flush() }'

i57_sel="$(awk "$i57_awk" "$GV" | sort -u)"
i57_bind="$(awk "$i57_map_awk" "$MAP" | sort -u)"
i57_nsel="$(printf '%s\n' "$i57_sel" | grep -c . )"
i57_nbind="$(printf '%s\n' "$i57_bind" | grep -c . )"

# Grammar liveness, proved against a probe rather than against the corpus: a corpus with
# nothing to find and a grammar that can find nothing print the same clean line. The probe
# paths are ASSEMBLED so this file carries no literal citation of its own -- I50 scans a
# different corpus today, and a scan that later widens onto this one must not read the
# probe as a real citation.
i57_dir="scripts/ai-dlc"
#
# THE PROBE CARRIES BOTH SPELLINGS, and that arm is here because the grammar was blind to one
# of them for its whole existence: `; exit 0 required.` was selected and `. Exit 0 required.`
# was not, hiding Checks 26 and 30 from arm 1 (both bound anyway, so latent rather than live).
# Two spellings of the same sentence must select alike, and asserting it costs one probe line.
i57_probe="$(printf '%s\n' \
  '<!-- CHECK_LOADED: probe -->' \
  "- **Check.** Run \`${i57_dir}/validate-i57-probe-positive.sh <arg>\`; exit 0 required." \
  '' \
  '<!-- CHECK_LOADED: probecap -->' \
  "- **Check.** Run \`${i57_dir}/validate-i57-probe-capital.sh <arg>\`. Exit 0 required." \
  '' \
  "- The bound script consults \`${i57_dir}/validate-i57-probe-negative.sh --mode x\` first:" \
  '  exit 0 = out of scope, exit 1 = in scope.')"
i57_probe_out="$(printf '%s\n' "$i57_probe" | awk "$i57_awk")"
case "$i57_probe_out" in
  *validate-i57-probe-positive.sh*) : ;;
  *) err "I57's selection grammar did not fire on a probe written in the exact shape it exists to catch -- a check body naming a validator with 'exit 0 required' beside it. Every tree passes this invariant now, including one full of the defect. Fix the grammar or retire I57; do not leave it printing a clean line." ;;
esac
case "$i57_probe_out" in
  *validate-i57-probe-capital.sh*) : ;;
  *) err "I57's selection grammar selected the lowercase 'exit 0 required' probe but NOT the identical sentence written 'Exit 0 required' at a sentence start. That is the exact blindness v0.357.0 removed: an author who ends the preceding clause with a full stop instead of a semicolon steps outside the grammar without meaning to, and the check goes quiet on their row while printing the same clean line. Measured when it was live: 12 lowercase sites selected, 2 capitalised ones invisible — Check 26, the fail-closed check through which the lead adopts every adjudication:llm verdict, and Check 30. Restore the case-tolerant class; do not re-narrow it." ;;
esac
case "$i57_probe_out" in
  *validate-i57-probe-negative.sh*) err "I57's selection grammar fired on a probe carrying an exit-code LEGEND ('exit 0 = out of scope') rather than an exit-code REQUIREMENT. That is the form Check 16 uses to describe a delegation validate-stub-audit.sh makes internally, and it is correctly carried under reads:. As written the grammar reports a false positive on it. Narrow it back to a posture that binds the gate." ;;
esac

if [ "$i57_nsel" -eq 0 ] || [ "$i57_nbind" -eq 0 ]; then
  err "I57 derived an EMPTY set: ${i57_nsel} exit-code-posture citation(s) in ${GV##*/}, ${i57_nbind} enforcer binding(s) in ${MAP##*/}. It reports an ABSENCE -- that no check states a mechanical predicate its row leaves unbound -- and over an empty corpus that absence is a broken extractor, not a finding. Fails closed."
else
  i57_unbound=""
  i57_ctl=0
  while IFS="$(printf '\t')" read -r i57_cid i57_scr; do
    [ -z "$i57_cid" ] && continue
    if grep -qxF "OWN	${i57_cid}	${i57_scr}" <<<"$i57_bind" \
    || grep -qxF "SITE	${i57_cid}	${i57_scr}" <<<"$i57_bind"; then
      i57_ctl=$((i57_ctl + 1))
    else
      case "
$i57_unbound" in
        *"
  Check ${i57_cid}: ${i57_scr}"*) : ;;
        *) i57_unbound="${i57_unbound}
  Check ${i57_cid}: ${i57_scr}" ;;
      esac
    fi
  done <<EOF
$i57_sel
EOF
  if [ "$i57_ctl" -eq 0 ]; then
    err "I57's control is empty: of ${i57_nsel} exit-code-posture citation(s), NOT ONE resolved to a binding in the enforcement map. A correct tree has many; zero means the binding extractor stopped reading the map, and every check is about to be reported as unbound. Fails closed rather than printing a wall of findings it did not compute."
  elif [ -n "$i57_unbound" ]; then
    err "check(s) whose own body makes a validator's exit code decide the gate, while the enforcement map binds nothing to them:${i57_unbound}
The map is the one artifact that answers 'what actually enforces this check'. A row reading \`enforcer: []\` under a body that says 'exit 0 required' tells the efficacy audit the check is adjudicated prose and tells the operator to re-perform a mechanical comparison by reading a paragraph at every gate -- which is exactly the state Checks 16, 18 and 22 shipped in until v0.209.0-v0.211.0. Bind it on the check's row, or on a non_catalog_units row whose call_sites names this check. If the citation is NOT the predicate -- a producer, or the remedy offered on FAIL -- then the check's own wording is wrong, because it currently states an exit code that binds the gate."
  fi
fi

# --- I91: harness-origin prefixes are ONE declaration, never a second copy ------
# WHY. The harness raises UserPromptSubmit identically when a backgrounded task completes as
# when a human types, so three readers in three languages must tell those apart: the capture
# hook (bash), Check 33's enforcer (Python), and validate-steering-budget.sh's
# genuineOperatorText (JS). ai-dlc-pause.sh's own header foresaw this and left an instruction
# rather than a list -- "if a broader predicate is ever needed, single-source it, do not copy
# it" -- because a hand-maintained enumeration of harness spellings in a second language is
# two lists that drift. v0.265.0 needed the broader predicate. This is what keeps it one.
#
# BOTH SIDES DERIVED. The declaration's prefixes are read from the schema, and the JS
# predicate's are extracted from its own alternation. Neither is written here, so this
# invariant cannot pass by agreeing with a copy of itself.
i91_schema="core/schemas/harness-origin.json"
if [ ! -f "$i91_schema" ]; then
  err "I91: $i91_schema is missing. It is the single declaration of harness-raised prompt prefixes, and without it the capture hook records background events as operator requests and Check 33 compares the sprint plan against one — measured on the reference consumer as a NOT-APPLICABLE pass where the operator's real ask exits 1."
else
  # BOTH SIDES SORTED BY THE SAME COLLATION. Python's sorted() is byte order and the shell's
  # `sort` is locale-aware; `[` lands on opposite sides of the alphabetics between them, and
  # comm then reports a prefix present in both as missing from each. That is a drift report
  # produced by the comparison rather than by the code, and it cost a debugging pass here.
  i91_declared="$(python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1]))["prefixes"]))' "$i91_schema" 2>/dev/null | LC_ALL=C sort)"
  # The JS side: the alternation inside genuineOperatorText's prefix test.
  # The JS literal escapes `[` for the regex engine; the declaration carries the plain
  # character. Unescape before comparing, or the two sides differ on a backslash and the
  # invariant reports drift that is only a quoting convention.
  i91_js="$(sed -n 's/.*if (\/^(\(<task-notification[^)]*\))\/\.test(txt)) return "";.*/\1/p' \
              core/scripts/validate-steering-budget.sh | head -1 | tr '|' '\n' \
            | sed -e 's/\\//g' | sed '/^$/d' | LC_ALL=C sort)"
  if [ -z "$i91_declared" ] || [ -z "$i91_js" ]; then
    err "I91 could not parse one side: declared=$(printf '%s' "$i91_declared" | grep -c .) js=$(printf '%s' "$i91_js" | grep -c .). An empty set compares equal to nothing, so this fails closed rather than reporting an agreement it never computed."
  else
    i91_only_js="$(LC_ALL=C comm -13 <(printf '%s\n' "$i91_declared") <(printf '%s\n' "$i91_js") | tr '\n' ' ' | sed 's/ *$//')"
    i91_only_decl="$(LC_ALL=C comm -23 <(printf '%s\n' "$i91_declared") <(printf '%s\n' "$i91_js") | tr '\n' ' ' | sed 's/ *$//')"
    [ -n "$i91_only_js" ] && err "I91: genuineOperatorText rejects prefix(es) the declaration does not carry:${i91_only_js:+ $i91_only_js}. The two readings have drifted, which means a prompt one component treats as harness noise the other records as the sprint's ask. Add it to $i91_schema."
    [ -n "$i91_only_decl" ] && err "I91: $i91_schema declares prefix(es) genuineOperatorText does not reject:${i91_only_decl:+ $i91_only_decl}. The capture would drop a prompt the steering budget still counts as a genuine operator turn."
  fi
  # No shipped file may restate a declared prefix outside the declaration and the one
  # predicate bound to it. A copy is how this becomes two lists again, and a comment naming
  # one is exactly how the last copy got in.
  # The exempt set is DECLARED, not written here -- see copy_scan_exempt's own description
  # for the measured false-positive set that produced it.
  i91_exempt="$(python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1])).get("copy_scan_exempt") or []))' "$i91_schema" 2>/dev/null)"
  i91_copies=""
  while IFS= read -r pfx; do
    [ -n "$pfx" ] || continue
    # HERE-STRING, not a pipe into grep -q. I54 caught the pipe form on this very line:
    # under pipefail the pipeline reports the WRITER's status, so a match answers non-zero
    # once the value clears the pipe buffer, and the exemption would silently stop applying.
    grep -qxF -- "$pfx" <<<"$i91_exempt" && continue
    hits="$(grep -rlF -- "$pfx" core/ scripts/ 2>/dev/null \
            | grep -v '^core/schemas/harness-origin.json$' \
            | grep -v '^core/scripts/validate-steering-budget.sh$' \
            | grep -v '^scripts/validate-enforcement-map.sh$' \
            | grep -v '^core/fixtures/' | tr '\n' ' ')"
    [ -n "$hits" ] && i91_copies="$i91_copies
  $pfx -> $hits"
  done <<EOF
$i91_declared
EOF
  [ -n "$i91_copies" ] && err "I91: shipped file(s) restate a harness-origin prefix outside the declaration:$i91_copies
Resolve it from core/schemas/harness-origin.json instead. A second copy in a second language is the drift v0.265.0 exists to end, and the file that carried the last one warned about it in prose that nothing enforced."
fi

# --- I94: the pause branch text and the handoff-intent PATTERNS are ONE declaration ---
# WHY. Two hooks now hand the lead the same three-way branch when the pipeline pauses --
# ai-dlc-pause.sh on a typed message, ai-dlc-answer-capture.sh on an AskUserQuestion answer
# carrying handoff intent -- and those two plus ai-dlc-continue.sh's Check 0 share the two
# regular expressions that decide what "handoff intent" means. Every one of those was a
# string literal in a hook before the answer channel was routed. A second copy of the branch
# is a lead given different instructions depending on which channel the operator used, and a
# second copy of a pattern is a request one component routes and another ignores.
# ai-dlc-pause.sh's own header had already ruled on this for its harness-prefix list, and
# I91 is the same invariant one subject over.
#
# NOT A VOCABULARY, AND THE HEADER SAYS PATTERNS FOR THAT REASON. What is bound here is two
# EREs and three prose strings; there is no enumerable member set, so there is nothing for
# render-vocabulary-index.sh to render and no `# vocabulary:` marker to write. Its guard
# reads arm headers for the word and demanded one when this header carried it -- correctly,
# since a header claiming a set with no marker is how the index goes blind.
#
# THREE ARMS, AND THE THIRD IS THE ONE THAT COULD NOT BE SKIPPED. (a) the declaration is
# present and every field carries a value -- an empty field would let both readers emit
# nothing and agree perfectly. (b) no shipped file restates a declared value. (c) every
# reader actually READS it: a copy scan alone passes against a hook that resolves nothing
# and emits nothing, which is exactly the shape a broken install has, so the bind is keyed
# on the line that FEEDS the schema path to jq, not on a file that mentions the filename.
#
# ONE `python3`, NOT ELEVEN. The first draft resolved each field with its own interpreter
# start, twice over -- once per arm -- and validator-fork-budget caught it at 7020 against a
# 7000 ceiling. That budget is not cosmetic: the suite runs this validator well over a
# hundred times per push, so an arm's fork count is a change to the suite's wall clock. The
# whole declaration is dumped once, as `name<TAB>value` lines, and both arms read the dump.
i94_schema="core/schemas/pause-routing.json"
if [ ! -f "$i94_schema" ]; then
  err "I94: $i94_schema is missing. It is the single declaration of the pause branch text and the handoff-intent patterns; without it ai-dlc-pause.sh emits no branch at all, ai-dlc-continue.sh's Check 0 skips entirely, and a handoff arriving as an AskUserQuestion answer goes unrouted — which is the defect the declaration was created to close."
else
  # Tab-delimited is safe here and asserted to be: every declared value is a single-line JSON
  # string with no tab in it, and the dump refuses to emit a field that has one rather than
  # producing a row that would silently truncate at the split below.
  i94_dump="$(python3 - "$i94_schema" <<'PY' 2>/dev/null
import json, sys
want = ["pause_branch_text", "prompt_pause_preamble", "answer_pause_preamble",
        "handoff_intent_pattern", "handoff_mention_exclusion_pattern"]
d = json.load(open(sys.argv[1]))
for k in want:
    v = d.get(k) or ""
    if "\t" in v or "\n" in v:
        v = ""          # unsplittable -> reported as EMPTY, never as a truncated value
    print("%s\t%s" % (k, v))
PY
)"
  i94_empty=""
  i94_copies=""
  i94_needle=""
  if [ -z "$i94_dump" ]; then
    err "I94 could not read $i94_schema at all — it is present but did not parse, so neither the empty-field arm nor the copy scan below ran. A silent parse failure would leave both reporting clean."
  else
    # (b) THE COPY SCAN, folded into the same pass as (a). Fixtures are IN scope, unlike
    # I91's: nothing here is an ordinary transcript token that unrelated code legitimately
    # handles, and a fixture that hard-coded the branch text would keep passing across a
    # change to the declaration. FALSE-POSITIVE SET MEASURED AT ZERO over core/ and scripts/
    # with all five values, which is the whole corpus these ship into; the narrowing that got
    # it there was writing every reader to resolve the value through jq rather than to
    # compare against a literal.
    while IFS="$(printf '\t')" read -r _f _v; do
      [ -n "$_f" ] || continue
      if [ -z "$_v" ]; then i94_empty="$i94_empty $_f"; continue; fi
      [ "$_f" = pause_branch_text ] && i94_needle="$_v"
      # ONE FORK PER FIELD. The obvious `grep -rlF | grep -v | tr` is three processes, and
      # this loop runs once per declared field -- 15 forks for a filter and a join the shell
      # does for free. The declaration's own path is excluded here rather than by a second
      # grep, and the list is joined by accumulation rather than by `tr`.
      _out="$(grep -rlF -- "$_v" core/ scripts/ 2>/dev/null)"
      _hits=""
      while IFS= read -r _p; do
        [ -n "$_p" ] || continue
        [ "$_p" = "$i94_schema" ] && continue
        _hits="$_hits $_p"
      done <<EOF
$_out
EOF
      [ -n "${_hits// /}" ] && i94_copies="$i94_copies
  $_f ->$_hits"
    done <<EOF
$i94_dump
EOF
  fi
  [ -n "${i94_empty// /}" ] && err "I94: $i94_schema declares empty, missing, or unsplittable field(s):${i94_empty}. Both readers concatenate these, so an empty one produces a shorter instruction in every channel at once and the copies still agree — the join passes while the lead is told nothing."
  [ -n "${i94_copies// /}" ] && err "I94: shipped file(s) restate a pause-routing value outside the declaration:$i94_copies
Resolve it from $i94_schema instead. A second copy of the branch text hands the lead one instruction on one channel and a stale one on the other, and nothing compares them."

  # (c) THE READER BIND, keyed on the line that passes the resolved path to jq. A hook that
  # merely names the file in a comment satisfies a whole-file grep and reads nothing.
  for _r in core/hooks/ai-dlc-pause.sh core/hooks/ai-dlc-answer-capture.sh core/hooks/ai-dlc-continue.sh; do
    if [ ! -f "$_r" ]; then
      err "I94(c): $_r is missing, so this invariant cannot establish that the declaration has the readers it claims."
    elif ! grep -q 'jq -rj .*"\$PAUSE_ROUTING_SCHEMA"' "$_r"; then
      err "I94(c): $_r does not READ $i94_schema — no line feeds \$PAUSE_ROUTING_SCHEMA to jq. Either it went back to a literal, in which case arm (b) above is scanning for a value this file no longer carries verbatim, or it stopped emitting the branch at all. Both are silent."
    fi
  done

  # SELF-PROBE, both directions, on a mktemp tree rather than the corpus. An arm reporting
  # zero copies without first producing one has established that it ran, not that the tree is
  # clean; and an arm that flags a near-miss would flag every paraphrase in the CHANGELOG.
  i94_probe="$(mktemp -d 2>/dev/null)"
  if [ -z "$i94_probe" ] || [ -z "$i94_needle" ]; then
    err "I94 could not build its probe (dir='${i94_probe:-}' needle=${#i94_needle}B), so neither direction of its copy scan was proven this run. An empty needle is contained by nothing and matched by everything, depending on the tool — either way the scan above is unproven."
  else
    printf '%s\n' "$i94_needle" > "$i94_probe/offender.sh"
    # The near-miss drops the first word. Same subject, same length class, not the value.
    printf '%s\n' "${i94_needle#* }" > "$i94_probe/nearmiss.sh"
    # Read the EXIT STATUS, not a piped `grep -c` of the output: `grep -lF` already answers
    # "did this file contain it", and counting its lines costs a second process for an
    # answer the first one gave.
    i94_pp=0; i94_pn=0
    grep -qlF -- "$i94_needle" "$i94_probe/offender.sh" 2>/dev/null && i94_pp=1
    grep -qlF -- "$i94_needle" "$i94_probe/nearmiss.sh" 2>/dev/null && i94_pn=1
    rm -rf "$i94_probe"
    [ "$i94_pp" -eq 0 ] && err "I94's positive probe was NOT reported: a seeded verbatim copy of the branch text went unseen by the same scan the corpus arm runs, so a clean result above means nothing. This fails closed."
    [ "$i94_pn" -ne 0 ] && err "I94's negative probe WAS reported: a near-miss that is not the declared value was flagged as a copy. The scan is not fixed-string, and every paraphrase in the tree is now in its finding set."
  fi
fi

# --- I95: every pipeline state path is CLASSIFIED transient or durable, in one place ---
# WHY. The distribution shipped no .gitignore rule at all -- install.sh carried zero
# references to one -- so every consumer discovered the transient half of _bmad-output/ by
# finding churn in its own git history and hand-adding entries. The reference consumer had
# added four that way over roughly four hundred releases, and meanwhile three others had
# quietly become TRACKED: .wait-beats/ at 134 files, .driver/ at 3, .context-sensor-state at
# 1. Nothing joined that hand-written list to the hooks creating the paths, so it could only
# ever lag, and nothing reported the lag.
#
# THE SUBJECT IS THE PARTITION, NOT THE IGNORE LIST, and that is the whole reason this arm
# earns its cost. Binding only the transient half would leave a new state path invisible until
# someone noticed it in a diff -- the same failure one level up. Every top-level name the
# machinery constructs must be classified one way or the other, so an unclassified path fails
# the push the moment it is written. What renders into .gitignore is then a projection of a
# complete declaration rather than a list somebody maintains.
#
# THE GRAMMAR IS SHARED WITH THE DECLARATION AND IS DELIBERATELY COMMENT-BLIND. core carries
# worked path EXAMPLES in prose -- _bmad-output/x.md, s177/foo.md, party-mode/s<N>/ -- and an
# arm that counted those would demand a declaration for names no program ever creates. The
# false-positive set was measured over the live tree at ZERO with comments excluded and at
# five with them included, and the five were all documentation examples. That exclusion is
# also why arm (a) checks a declared producer with the SAME grammar rather than a whole-file
# grep: a producer that only NAMES its path in a header comment constructs nothing, and a
# substring search cannot tell those apart.
#
# ONE `python3` FOR THE CORPUS AND BOTH PROBE DIRECTIONS. An arm's fork count is a change to
# the suite's wall clock -- validator-fork-budget exists to say so, and I94's first draft
# breached it by resolving fields one interpreter start at a time. The reader below takes
# (tag, root, schema) triples and tags every finding, so the live corpus and the two seeded
# trees are one process rather than three.
i95_schema="core/schemas/pipeline-state-paths.json"
if [ ! -f "$i95_schema" ]; then
  err "I95: $i95_schema is missing. It is the single classification of every path the shipped machinery writes under the pipeline root, and install.sh renders the consumer's .gitignore from it — without the file the installer writes NO ignore rules and reports that it skipped them, which is how 134 transient files became tracked in the reference consumer in the first place."
else
  # PROBE TREES FIRST, so the arm's ability to fire is established before its verdict on the
  # corpus is read. The offender constructs an undeclared path on a live line; the near-miss
  # names the same shape of path in a COMMENT and additionally constructs one that IS
  # declared. An arm that flagged the near-miss would flag every documented example in core.
  i95_probe="$(mktemp -d 2>/dev/null)"
  i95_pos_root=""; i95_neg_root=""
  if [ -n "$i95_probe" ]; then
    mkdir -p "$i95_probe/pos/core/hooks" "$i95_probe/neg/core/hooks"
    printf 'X="${STATE_DIR}/.i95-probe-undeclared"\n' > "$i95_probe/pos/core/hooks/probe.sh"
    {
      printf '# X="${STATE_DIR}/.i95-probe-nearmiss"\n'
      printf 'Y="${STATE_DIR}/.wait-beats"\n'
    } > "$i95_probe/neg/core/hooks/probe.sh"
    i95_pos_root="$i95_probe/pos"; i95_neg_root="$i95_probe/neg"
  fi

  i95_out="$(python3 - \
      live "$REPO_ROOT" "$REPO_ROOT/$i95_schema" \
      pos "${i95_pos_root:-}" "$REPO_ROOT/$i95_schema" \
      neg "${i95_neg_root:-}" "$REPO_ROOT/$i95_schema" <<'PY' 2>&1
import io, json, os, re, sys

NAME = r'[A-Za-z0-9_.-]+'
PAT = re.compile(r'(?:\$\{(?:STATE_DIR|LOG_DIR)\}|_bmad-output)/(' + NAME + r')')
DIRS = ['core/hooks', 'core/scripts', 'core/session-driver', 'core/git-hooks']


def population(root):
    """name -> first constructing file:line, over non-comment lines only."""
    found = {}
    for d in DIRS:
        ad = os.path.join(root, d)
        if not os.path.isdir(ad):
            continue
        for dirpath, _dirs, filenames in os.walk(ad):
            for fn in sorted(filenames):
                fp = os.path.join(dirpath, fn)
                try:
                    raw = io.open(fp, encoding='utf-8', errors='replace').read()
                except Exception:
                    continue
                for i, line in enumerate(raw.splitlines(), 1):
                    if line.lstrip().startswith('#'):
                        continue
                    for m in PAT.finditer(line):
                        nm = m.group(1).rstrip('.')
                        if nm and nm != '_bmad-output':
                            found.setdefault(nm, '%s:%d' % (os.path.relpath(fp, root), i))
    return found


def constructs(path, name):
    try:
        raw = io.open(path, encoding='utf-8', errors='replace').read()
    except Exception:
        return False
    for line in raw.splitlines():
        if line.lstrip().startswith('#'):
            continue
        for m in PAT.finditer(line):
            if m.group(1).rstrip('.') == name:
                return True
    return False


args = sys.argv[1:]
for i in range(0, len(args), 3):
    tag, root, schema_p = args[i], args[i + 1], args[i + 2]
    if not root or not os.path.isdir(root):
        print('%s\tPROBEBROKEN\t-\troot %r is not a directory' % (tag, root))
        continue
    derived = population(root)
    if not derived:
        print('%s\tDISARMED\t-\tthe grammar matched nothing under %s' % (tag, ', '.join(DIRS)))
        continue
    try:
        decl = json.load(io.open(schema_p, encoding='utf-8'))
    except Exception as exc:
        print('%s\tUNPARSED\t%s\t%s' % (tag, schema_p, exc))
        continue

    declared = {}
    for e in (decl.get('paths') or []):
        nm = (e.get('name') or '').strip()
        if not nm:
            print('%s\tFIELD\t<unnamed>\tan entry declares no name' % tag)
            continue
        if nm in declared:
            print('%s\tFIELD\t%s\tdeclared twice' % (tag, nm))
        declared[nm] = e
        for req in ('producer', 'reason'):
            if not (e.get(req) or '').strip():
                print('%s\tFIELD\t%s\tempty %s' % (tag, nm, req))
        if not isinstance(e.get('transient'), bool):
            print('%s\tFIELD\t%s\ttransient is not a boolean' % (tag, nm))
            continue
        ig = (e.get('ignore') or '').strip()
        if e['transient']:
            if not ig:
                print('%s\tFIELD\t%s\ttransient but declares no ignore pattern' % (tag, nm))
            elif not ig.startswith((decl.get('root') or '') + '/'):
                print('%s\tFIELD\t%s\tignore pattern %s is not under the declared root'
                      % (tag, nm, ig))
        elif ig:
            print('%s\tFIELD\t%s\tdurable but declares an ignore pattern (%s)' % (tag, nm, ig))
        prod = (e.get('producer') or '').strip()
        # Only the live corpus can be asked about producers; a probe tree holds no machinery,
        # and checking there would emit a finding per entry and drown the seeded signal.
        if prod and tag == 'live':
            pp = os.path.join(root, prod)
            if not os.path.isfile(pp):
                print('%s\tPRODUCER\t%s\t%s does not exist' % (tag, nm, prod))
            elif not constructs(pp, nm):
                print('%s\tPRODUCER\t%s\t%s does not construct it on a non-comment line'
                      % (tag, nm, prod))

    for nm in sorted(set(derived) - set(declared)):
        print('%s\tUNDECLARED\t%s\t%s' % (tag, nm, derived[nm]))
    if tag == 'live':
        for nm in sorted(set(declared) - set(derived)):
            print('%s\tORPHAN\t%s\t-' % (tag, nm))
    print('%s\tPOP\t%d\t%d' % (tag, len(derived), len(declared)))
PY
)"
  [ -n "$i95_probe" ] && rm -rf "$i95_probe"

  if [ -z "$i95_out" ]; then
    err "I95's reader produced NO output at all, not even its population count. It did not run, so neither the corpus verdict nor the probe that proves the corpus verdict means anything. This fails closed."
  else
    i95_pos_fired=0
    i95_neg_fired=0
    i95_live_pop=0
    while IFS="$(printf '\t')" read -r _tag _kind _what _where; do
      [ -n "$_tag" ] || continue
      case "$_tag:$_kind" in
        pos:UNDECLARED) [ "$_what" = ".i95-probe-undeclared" ] && i95_pos_fired=1 ;;
        neg:UNDECLARED) i95_neg_fired=1 ;;
        live:POP) i95_live_pop="$_what" ;;
        live:UNDECLARED)
          err "I95: $_what is constructed at $_where and is classified NOWHERE in $i95_schema. Add it with transient true or false: transient means per-run coordination state, which renders into the consumer's .gitignore, and durable means a pipeline artifact the consumer commits. An unclassified path is exactly how .wait-beats/ reached 134 tracked files." ;;
        live:ORPHAN)
          err "I95: $i95_schema declares '$_what', but no shipped file under core/hooks, core/scripts, core/session-driver or core/git-hooks constructs it on a non-comment line. Either the machinery that wrote it was removed — in which case delete the entry, and if it was transient the consumer's .gitignore keeps a rule for a path nothing creates — or it moved somewhere this arm does not look, which means the population it scans is no longer the population that matters." ;;
        live:FIELD)
          err "I95: entry '$_what' in $i95_schema is malformed — $_where. Every field is load-bearing: a transient entry with no ignore pattern is classified correctly and still reaches no .gitignore, and a durable entry that carries one gets a consumer's committed artifact ignored." ;;
        live:PRODUCER)
          err "I95: entry '$_what' names a producer that does not hold up — $_where. The producer is checked with the same grammar that derived the population, so naming the path in a header comment does not satisfy it. A declaration pointing at the wrong file cannot tell anyone where a path comes from when they need to change it." ;;
        live:UNPARSED)
          err "I95: $_what did not parse as JSON ($_where), so nothing below it ran and the corpus arm reported nothing rather than reporting clean." ;;
        live:DISARMED)
          err "I95's population grammar matched NOTHING in the live tree — $_where. Every hook that writes pipeline state would have to have stopped doing so; far likelier is that the directories moved, in which case this arm is scanning an empty set and passing." ;;
        *:PROBEBROKEN)
          err "I95 could not build its $_tag probe tree ($_where), so that direction of its self-probe did not run this run." ;;
      esac
    done <<EOF
$i95_out
EOF

    [ "$i95_pos_fired" -eq 0 ] && err "I95's POSITIVE probe was NOT reported: a seeded file constructing an undeclared path went unseen by the same reader the corpus arm runs, so a clean corpus result above establishes only that the reader executed. This fails closed."
    [ "$i95_neg_fired" -ne 0 ] && err "I95's NEGATIVE probe WAS reported: a path named only inside a COMMENT was treated as constructed. The grammar is not comment-blind, and every worked path example in core's prose is now in this arm's finding set."
    [ "${i95_live_pop:-0}" -lt 2 ] && err "I95 derived ${i95_live_pop:-0} path(s) from the live tree. The probe trees derive one each by construction, so a live population that small means the corpus scan resolved to a probe-sized tree rather than to core/, and its set-compare is meaningless."

    # (c) THE READERS, keyed on the line that FEEDS the schema path to jq. A script that names
    # the file in a comment satisfies a whole-file grep and reads nothing, and the failure is
    # silent in the worst direction: a consumer with no rendered block looks exactly like one
    # whose block is up to date.
    for _r in core/scripts/sync-transient-ignore.sh scripts/uninstall.sh; do
      if [ ! -f "$_r" ]; then
        err "I95(c): $_r is missing, so this invariant cannot establish that $i95_schema has the readers it claims."
      elif ! grep -q 'jq [^|]*"\$[A-Z_]*SCHEMA"' "$_r"; then
        err "I95(c): $_r does not READ $i95_schema — no line feeds a resolved schema path to jq. The renderer projects the declaration's transient half into the consumer's .gitignore and uninstall.sh cuts that block by the markers declared in it; a copy of either the markers or the path list inside those scripts is a second source that drifts from this one silently."
      fi
    done

    # (d) THE RENDERER SHIPS, AND install.sh CALLS IT. This is the arm that would have caught
    # the shape this release started with. The renderer lived inside install.sh, which no
    # consumer has: apply.sh would have delivered the declaration on every pull and the code
    # that renders it on none, so the consumers with committed transient state -- the whole
    # subject -- were the ones it could never reach. Keyed on the INVOCATION, because
    # install.sh naming the script in a comment is how that regression would read.
    if [ ! -f core/scripts/sync-transient-ignore.sh ]; then
      err "I95(d): core/scripts/sync-transient-ignore.sh is missing. It is the only thing that writes the consumer's .gitignore block, and install.sh's copy loop over core/scripts/ is what delivers it to a consumer as scripts/ai-dlc/sync-transient-ignore.sh — without it the declaration ships to every consumer and nothing renders it anywhere."
    elif ! grep -q 'bash "\$SYNC_IGNORE"' scripts/install.sh 2>/dev/null; then
      err "I95(d): scripts/install.sh does not INVOKE sync-transient-ignore.sh. A fresh install would copy the renderer into scripts/ai-dlc/ and never run it, so a new consumer starts with no ignore block and no indication that one was expected."
    fi
  fi
fi

# --- I80: an enumeration of the intensity SET names every member of it -------------
# vocabulary: validation intensities
# vocabulary-invariant: I80
# vocabulary-owner: core/skills/ai-dlc/SKILL.md
# vocabulary-extract: intensity-table
# vocabulary-readers: core/skills/ai-dlc/steps/route.md, core/skills/ai-dlc/steps/gate-validation.md
# I19 binds the intensity table's MINIMUMS column: it forbids a second copy of what an
# intensity requires. It does not bind the SET. So the same row kept dropping out of the
# other half — route.md, the file that ASSIGNS validation_intensity, listed three of four
# and omitted carry-over-single, which meant the one value that governs a carry-over sprint
# could not be selected by a lead following the assignment step literally. Check 14's
# snapshot-content spec dropped the identical row.
#
# This is the second time this row has been dropped and the first fix is why: v0.74.0
# repaired the READER (Check 20 now resolves the minimum from the table) and left the
# WRITERS untouched, and I19's own comment names route.md as a sanctioned shape — naming an
# intensity is fine, restating its minimum is not. A file may name ONE intensity and branch
# on it; a file that enumerates two or more is claiming to present the set, and a partial
# set is the defect.
#
# The set is DERIVED from Rule 8's table, never hand-listed. Two enumeration shapes exist in
# the tree and both wrap across source lines, so paragraphs are whitespace-flattened before
# matching — a line-oriented scan sees neither, and reports CLEAN on both.
i80_out="$(python3 - "$REPO_ROOT" <<'PY' 2>&1
import re, glob, io, os, sys
root = os.path.join(sys.argv[1], 'core/skills/ai-dlc')
skill_p = os.path.join(root, 'SKILL.md')
if not os.path.isfile(skill_p):
    print("DISARMED: %s unreadable" % skill_p); sys.exit(0)
skill = io.open(skill_p, encoding='utf-8').read()
tbl = re.search(r'\| Intensity \| Trigger.*?\n(?:\|.*\n)+', skill)
if not tbl:
    print("DISARMED: Rule 8 intensity table not found in SKILL.md"); sys.exit(0)
names = re.findall(r'^\| `([a-z-]+)`', tbl.group(0), re.M)
if len(names) < 2:
    print("DISARMED: derived %d intensity name(s) from the table; need >=2" % len(names)); sys.exit(0)
alt = '|'.join(re.escape(n) for n in sorted(names, key=len, reverse=True))
for f in sorted(glob.glob(os.path.join(root, 'steps/*.md'))) + [skill_p]:
    raw = io.open(f, encoding='utf-8').read()
    off = 0
    for para in re.split(r'\n\s*\n', raw):
        idx = raw.find(para, off)
        line_no = raw[:idx].count('\n') + 1 if para.strip() else 0
        off = idx + len(para)
        if not para.strip() or para.lstrip().startswith('|'):
            continue
        flat = ' '.join(para.split())
        pipe = re.findall(r'(?:`?(?:%s)`?\s*\|\s*)+`?(?:%s)`?' % (alt, alt), flat)
        for grp, kind in ((set(re.findall(alt, ' '.join(pipe))), 'inline'),
                          (set(re.findall(r'-\s+`(%s)`' % alt, flat)), 'bullet')):
            if len(grp) >= 2 and grp != set(names):
                print("  %s:%d  %s enumeration names %d of %d — missing %s"
                      % (os.path.relpath(f, sys.argv[1]), line_no, kind,
                         len(grp), len(names), ', '.join(sorted(set(names) - grp))))
PY
)"
case "$i80_out" in
  DISARMED:*) err "I80 could not derive the intensity set: $i80_out
      The set is read from SKILL.md Rule 8's table. An unreadable table is not an empty one, so this reports rather than passing." ;;
  ?*) err "I80: a validation-intensity enumeration is missing a member of the set:
$i80_out
      Rule 8's table is the set. A file may name ONE intensity and branch on it; enumerating two or more claims to present the set, and a partial set is how carry-over-single became unassignable in the step that assigns it." ;;
esac

# --- I81: the live adversarial series is derived ONE way, in both hooks ----------
# WHY. Two hooks decide whether the Rule 8 stall/divergence block is armed --
# ai-dlc-continue.sh (Stop) and ai-dlc-acknowledge.sh (PreToolUse, which owns the DENY) --
# and each has to answer "which adversarial cycle is live" before it can ask the validator
# anything. They carried that derivation as two copies, and the copies were both wrong the
# same way: pick the newest glob match FIRST, strip the pass suffix SECOND. A filename the
# strip could not match then yielded a SERIES that was the whole filename, which resolves as
# a ONE-PASS series -- and a one-pass series can never be STALLED or DIVERGENT, so the guard
# returned CONTINUE and allowed the dispatch while a real multi-pass series sat stalled.
# Measured on the reference consumer: 6 of 135 files matching the glob defeat the strip.
#
# The fix filters INSIDE the pick (`sed -n 's/.../p'` prints only where it substituted), so
# a non-conforming name is never a candidate. This invariant keeps that ONE expression: a
# second copy is how it became two wrong copies the first time, and the DENY hook is the one
# that would go quiet.
#
# THE DERIVATION IS NOW A BLOCK, NOT A LINE, and the invariant follows it. v0.299.0 scoped the
# glob to the DECLARED sprint's own directory, which takes three statements -- resolve, reject a
# non-numeric answer, glob -- and splitting a two-copy hazard across three lines while checking
# one of them is how the other two drift apart. The hooks delimit the block themselves; this
# extractor reads between the markers and strips leading whitespace, because acknowledge.sh
# carries the block inside an `if` and indentation is not a difference in the program.
#
# BOTH SIDES DERIVED, and neither written here. The block is extracted from each hook by its own
# markers, so this cannot pass by agreeing with a literal kept in this file.
i81_hooks="core/hooks/ai-dlc-continue.sh core/hooks/ai-dlc-acknowledge.sh"
i81_expr_of() { awk '/>>> I81 LIVE-SERIES BLOCK >>>/{f=1;next} /<<< I81 LIVE-SERIES BLOCK <<</{f=0} f' "$1" | sed 's/^[[:space:]]*//'; }
i81_missing=""
for i81_h in $i81_hooks; do [ -f "$i81_h" ] || i81_missing="$i81_missing $i81_h"; done
if [ -n "$i81_missing" ]; then
  err "I81 cannot find hook(s):${i81_missing}. These are the two readers that arm the Rule 8 stall block; an absent one makes this invariant compare a single copy against itself, which is its PASS."
else
  i81_a="$(i81_expr_of core/hooks/ai-dlc-continue.sh)"
  i81_b="$(i81_expr_of core/hooks/ai-dlc-acknowledge.sh)"
  # ONE block per hook, and it must be non-empty. The marker count is what catches a second
  # block; the line count is what catches a marker pair that opens and closes on nothing.
  i81_na="$(grep -c '>>> I81 LIVE-SERIES BLOCK >>>' core/hooks/ai-dlc-continue.sh)"
  i81_nb="$(grep -c '>>> I81 LIVE-SERIES BLOCK >>>' core/hooks/ai-dlc-acknowledge.sh)"
  i81_la="$(printf '%s\n' "$i81_a" | grep -c .)"
  i81_lb="$(printf '%s\n' "$i81_b" | grep -c .)"
  if [ "$i81_na" -ne 1 ] || [ "$i81_nb" -ne 1 ] || [ "$i81_la" -eq 0 ] || [ "$i81_lb" -eq 0 ]; then
    err "I81 found $i81_na live-series block(s) in ai-dlc-continue.sh ($i81_la line(s)) and $i81_nb in ai-dlc-acknowledge.sh ($i81_lb line(s)); each must have exactly ONE, and it must not be empty. Zero blocks, or an empty one, means the markers or the derivation moved and this invariant is scanning for something that no longer exists -- which reads exactly like agreement. More than one means the hook decides the live series in two places."
  elif [ "$i81_a" != "$i81_b" ]; then
    err "I81 the two hooks derive the live adversarial series DIFFERENTLY:
  ai-dlc-continue.sh:    $i81_a
  ai-dlc-acknowledge.sh: $i81_b
The PreToolUse hook is the one that DENIES a dispatch; if it resolves a different series than the Stop hook that reports the state, the pipeline reports a stall it will not enforce. Make them one expression."
  else
    # TWO PROPERTIES, not just agreement. Byte-identity alone is satisfied by two copies of the
    # OLD expression, which is how this became two wrong copies the first time.
    case "$i81_a" in
      *"sed -E -n 's/(pass|p)[0-9]+\\.md\$//p'"*) : ;;
      *) err "I81 both hooks agree, but not on the filtering form. The live-series expression must select with \`sed -E -n 's/(pass|p)[0-9]+\\.md\$//p'\`, which emits ONLY where the substitution succeeded. Picking the newest match and stripping afterwards lets a non-conforming filename become a one-pass series, and a one-pass series can never be STALLED or DIVERGENT -- the guard then reports CONTINUE and allows the dispatch. Got: $i81_a" ;;
    esac
    # ...and it must be SCOPED to the declared sprint's directory. An unscoped glob agrees with
    # itself just as happily, and it is the form that let a touch on a long-converged series
    # redirect the guard across 56 sprints in one directory.
    case "$i81_a" in
      *'"${ART_DIR}/s${SPRINT_N'*) : ;;
      *) err "I81 both hooks agree, but the live-series glob is not scoped to the declared sprint's directory (\`\${ART_DIR}/s\${SPRINT_N...\`). An unscoped glob asks 'which cycle is live' of every series the project has ever written and answers it by mtime -- measured at 135 files across 56 sprints on the reference consumer. The sprint is DECLARED (\`sprint-status.sh sprint-id\`); compose the path from it. Got: $i81_a" ;;
    esac
    # PROBES, written here so a run proves both arms above can FAIL. They are deliberately
    # INDEPENDENT of the shipped block: each asserts that the extractor SEES a probe carrying
    # the old form and that the corresponding test REJECTS it. Comparing a probe to the shipped
    # value instead would entangle these with the arms above -- a hook reverted to the old form
    # would trip both, and two failures from one cause is how an assertion becomes vacuous
    # without anyone noticing.
    i81_probe="$(mktemp 2>/dev/null || echo /tmp/i81probe.$$)"
    {
      printf '%s\n' '# >>> I81 LIVE-SERIES BLOCK >>>'
      printf '%s\n' 'SERIES="$(ls -t "${ART_DIR}"/*adversarial*p*.md 2>/dev/null | head -1)"'
      printf '%s\n' '# <<< I81 LIVE-SERIES BLOCK <<<'
    } > "$i81_probe"
    i81_pexpr="$(i81_expr_of "$i81_probe")"
    rm -f "$i81_probe"
    if [ -z "$i81_pexpr" ]; then
      err "I81's own probe returned nothing: the extractor does not read a marked block at all, so the agreement it reported above means nothing."
    else
      case "$i81_pexpr" in
        *"sed -E -n 's/(pass|p)[0-9]+\.md\$//p'"*)
          err "I81's filtering-form test MATCHED a probe carrying the old newest-then-strip form. The test cannot tell the two apart, so it would pass over the exact regression it exists to catch." ;;
      esac
      case "$i81_pexpr" in
        *'"${ART_DIR}/s${SPRINT_N'*)
          err "I81's sprint-scope test MATCHED a probe carrying the old UNSCOPED glob. The test cannot tell a scoped glob from an unscoped one, so it would pass over the mtime-across-56-sprints defect it exists to catch." ;;
      esac
    fi
  fi
fi

# --- I82: core's own artifact-path prescriptions obey core's own grammar --------
# artifact-path-grammar.md declares that the DIRECTORY is the only sprint slot: `s<N>/`, and no
# basename may carry a sprint token. Core prescribed FIVE spellings across four positions before
# this existed, and the consumer's four-position mess is that grammar faithfully executed — so a
# declaration with no enforcer here would be re-broken by the next step file anyone writes.
#
# WHAT IT ASSERTS, in both directions:
#   * every artifact path core prescribes either conforms, or is named in the grammar file's
#     migration ledger. This is the arm that stops a SIXTH spelling.
#   * every ledger entry is still prescribed somewhere. A ledger that can outlive what it
#     excuses is a carve-out; one that must shrink is a ratchet, and the difference is exactly
#     this direction of the join.
#
# THE GRAMMAR FILE IS EXCLUDED FROM ITS OWN CORPUS, and that exclusion is load-bearing rather
# than tidy. The ledger lists the offending paths verbatim; if the file were scanned, every entry
# would be "still prescribed" by the ledger itself, the stale-entry arm could never fire, and the
# ratchet would be a carve-out wearing its clothes.
I82_GRAMMAR="$REPO_ROOT/core/skills/ai-dlc/artifact-path-grammar.md"
if [ ! -r "$I82_GRAMMAR" ]; then
  err "I82 cannot read core/skills/ai-dlc/artifact-path-grammar.md. It is the declared home of the artifact path grammar and of the migration ledger this invariant joins against; absent it, every prescription core makes is unchecked and this invariant's silence is indistinguishable from conformance."
else
  # A path component carries a sprint token when it names a sprint ANYWHERE but the reserved
  # slot. Placeholder (`<N>`, bare `N`, `*`) and literal digits alike, prefix and suffix alike,
  # both capitalisations of `s` — the four positions measured in the tree.
  # `s*` is the SAME reserved slot quantified over every sprint, and it is exempt only as a
  # WHOLE component. A cross-sprint read is not a currency question, so it is not the search
  # rule 2 exists to stop; `s*-retro.md` is a basename carrying a sprint token and is still
  # rejected below. The probe block asserts exactly that boundary, because widening an
  # exemption is how a predicate stops seeing the thing it was written for.
  #
  # THE ERE IS RESOLVED, NOT WRITTEN HERE, and that is a fix rather than a tidy-up. This block
  # carried its own widened copy while `artifact-path-config.sh`'s header claimed to be the single
  # home of the sprint-token expression — a claim true of the digits form and false of the rule.
  # The two then differed in the one way that matters: the shipped form is `[0-9]+`, so a checker
  # built on it matches no PRESCRIPTION at all and reports a clean zero on its own subject. There
  # is one home now, with two modes, and the probes below prove this reader still gets the wider
  # one. A resolver that cannot answer is a REFUSAL here, never a fallback to a local literal:
  # falling back is how the fork would grow back silently.
  i82_tok_re="$(bash "$REPO_ROOT/core/scripts/artifact-path-config.sh" --token-re-prescribed 2>/dev/null)"
  if [ -z "$i82_tok_re" ]; then
    err "I82 could not resolve the prescribed-path sprint-token ERE from core/scripts/artifact-path-config.sh --token-re-prescribed. That resolver is the single home of the expression; without it this invariant has no predicate, and a predicate that matches nothing reports every prescription core makes as conforming."
    i82_tok_re='(?!)'
  fi
  # THE SLOT EXEMPTION IS RESOLVED TOO, and this invariant is the third site that hand-listed it.
  # It skipped the literal `s<N>` and `s*` and nothing else, so a core prescription naming a
  # CONCRETE slot -- `docs/retro/s294/retro.md` -- would be reported as carrying a token outside
  # the slot, which is the spelling the remedy asks for. The consumer-facing clause built on the
  # same hand-list did exactly that on 7 of 7 of a consumer's rows before it was fixed. Same
  # refusal discipline as the expression above: an unresolvable slot ERE keeps the OLD literal
  # pair rather than widening to match everything, because an empty ERE in the `grep` below would
  # exempt every component and report a clean zero over a corpus it never judged.
  i82_slot_re="$(bash "$REPO_ROOT/core/scripts/artifact-path-config.sh" --slot-re-prescribed 2>/dev/null)"
  [ -n "$i82_slot_re" ] || err "I82 could not resolve the sprint-slot ERE from core/scripts/artifact-path-config.sh --slot-re-prescribed. Falling back to the literal pair, which under-exempts: a prescription naming a concrete slot will be reported as a violation of the rule it satisfies."
  i82_is_sprint_token() { # <component> -> 0 when it carries one
    if [ -n "$i82_slot_re" ]; then
      grep -qE "$i82_slot_re" <<<"$1" && return 1       # the reserved directory slot, any spelling
    else
      [ "$1" = 's<N>' ] && return 1
      [ "$1" = 's*' ] && return 1
    fi
    grep -qE "$i82_tok_re" <<<"$1"
  }

  # THE CORPUS IS DERIVED, never listed: every step file, every skill-root rule file except the
  # grammar itself, and every role file. A hand list here would be a second declaration of what
  # core's rulebook is, and the one thing added to it would be the one thing not scanned.
  i82_corpus=()
  for f in "$REPO_ROOT"/core/skills/ai-dlc/steps/*.md "$REPO_ROOT"/core/skills/ai-dlc/*.md "$REPO_ROOT"/core/team-roles/*.md; do
    [ -f "$f" ] || continue
    [ "$f" = "$I82_GRAMMAR" ] && continue
    i82_corpus+=("$f")
  done

  # Both roots lists come from the grammar's own blocks, so widening either moves the
  # enforcement with it rather than leaving the new prefix unscanned. They answer different
  # questions -- `areas:` is where an `s<N>/` directory may live, `scan-roots` is what this
  # invariant READS -- and scan-roots is the wider of the two by construction, because rule 2
  # governs paths that are not sprint artifacts at all (a rotation archive of a live log).
  #
  # BOTH ARE RESOLVED BY core/scripts/artifact-path-config.sh, WHICH IS THE ONLY READER OF THOSE
  # BLOCKS. This invariant carried its own copy of the two extractions, byte-identical to the
  # pair in migrate-artifact-paths.sh — which is what a fork looks like the day before it stops
  # being one, and the conformance validator would have been the third. There is one now, and
  # I83 below forbids a second. The consumer-area join the resolver performs is a no-op here:
  # the distribution has no `.claude/skills/ai-dlc/artifact-paths.md`, and an area declared by
  # some consumer would in any case still have to sit under a scan root.
  i82_cfg="$REPO_ROOT/core/scripts/artifact-path-config.sh"
  i82_areas="$(bash "$i82_cfg" --areas --root "$REPO_ROOT" --grammar "$I82_GRAMMAR" 2>/dev/null)"
  i82_roots="$(bash "$i82_cfg" --scan-roots --root "$REPO_ROOT" --grammar "$I82_GRAMMAR" 2>/dev/null)"
  i82_narea="$(printf '%s\n' "$i82_areas" | grep -c .)"
  i82_nroot="$(printf '%s\n' "$i82_roots" | grep -c .)"
  if [ "${#i82_corpus[@]}" -eq 0 ] || [ "$i82_narea" -eq 0 ] || [ "$i82_nroot" -eq 0 ]; then
    err "I82 derived ${#i82_corpus[@]} corpus file(s), $i82_narea area root(s) and $i82_nroot scan root(s); all three must be non-zero. A zero on any of them makes this invariant scan nothing and report conformance."
  else
    # An area outside every scan root is an area nothing reads, and it would go unenforced
    # while the grammar went on declaring it. Widen one, widen the other.
    i82_orphan=""
    while IFS= read -r a; do
      [ -n "$a" ] || continue
      i82_under=0
      while IFS= read -r r; do
        [ -n "$r" ] || continue
        case "$a/" in "$r"/*) i82_under=1 ;; esac
      done <<<"$i82_roots"
      [ "$i82_under" -eq 1 ] || i82_orphan="${i82_orphan} $a"
    done <<<"$i82_areas"
    [ -n "$i82_orphan" ] && err "I82 artifact-path-grammar.md declares area root(s) that sit under no scan root:${i82_orphan}. The grammar would govern them and this invariant would never read them — a declared area nothing enforces."

    i82_alt="$(printf '%s\n' "$i82_roots" | sed 's#/*$##' | paste -sd'|' -)"
    i82_seen="$(grep -rhoE "(${i82_alt})/[A-Za-z0-9_./<>{}*-]*" "${i82_corpus[@]}" 2>/dev/null \
      | sed -e 's/[.,)]*$//' -e 's#/$##' | grep -E '.' | sort -u)"
    i82_ledger="$(awk '/^```legacy-artifact-paths$/{f=1;next} f&&/^```/{f=0} f' "$I82_GRAMMAR" | grep -E '.' | sort -u)"

    if [ -z "$i82_seen" ]; then
      err "I82 extracted ZERO artifact paths from ${#i82_corpus[@]} rule file(s) under $i82_narea area root(s). Core prescribes dozens; zero means the extractor no longer matches how they are written, and an extractor that matches nothing reports every prescription as conforming."
    else
      i82_viol=""
      while IFS= read -r p; do
        [ -n "$p" ] || continue
        i82_bad=""
        while IFS= read -r c; do
          [ -n "$c" ] || continue
          i82_is_sprint_token "$c" && i82_bad="$c"
        done < <(printf '%s\n' "$p" | tr '/' '\n')
        [ -n "$i82_bad" ] || continue
        grep -qxF "$p" <<<"$i82_ledger" && continue
        i82_viol="${i82_viol}
  $p    (component '$i82_bad')"
      done <<<"$i82_seen"

      [ -n "$i82_viol" ] && err "I82 core prescribes artifact path(s) carrying a sprint token outside the reserved \`s<N>/\` directory slot, and they are not in artifact-path-grammar.md's migration ledger:${i82_viol}

The directory is the only sprint slot. A basename that carries one makes the reader search — and search means mtime, which is how both hooks came to pick the live adversarial series across 56 sprints in one directory. Rewrite it as <area>/s<N>/<kind>.md, or, if the readers cannot move yet, add it to the ledger with the sub-release that removes it."

      # The other direction. A ledger entry no prescription still makes is an excuse for nothing,
      # and leaving it lets the ledger stop shrinking without anyone seeing it stop.
      i82_stale=""
      while IFS= read -r e; do
        [ -n "$e" ] || continue
        grep -qxF "$e" <<<"$i82_seen" || i82_stale="${i82_stale} $e"
      done <<<"$i82_ledger"
      [ -n "$i82_stale" ] && err "I82 artifact-path-grammar.md's migration ledger names path(s) core no longer prescribes:${i82_stale}. The ledger is a ratchet, not a carve-out: an entry outliving the prescription it excuses is how the list stops shrinking. Delete the entry."

      # PROVE IT CAN FIRE. The predicate above is the whole invariant, and a predicate that
      # matched nothing would produce this same silence. Both probes, every run.
      i82_is_sprint_token 's<N>' \
        && err "I82's own probe: the reserved slot \`s<N>\` was flagged as a violation. The predicate rejects the one spelling the grammar requires, so conformance and violation are the same verdict."
      i82_is_sprint_token 's*' \
        && err "I82's own probe: the all-sprints slot \`s*\` was flagged as a violation. Rule 1 declares it the same reserved slot quantified over every sprint, so a cross-sprint read core legitimately prescribes cannot be written at all."
      for i82_p in 'sprint-<N>-retro.md' 's<N>-research-notes.md' 'gate-log-archive-s<N>.md' 'ui-mockups-sprint-N.md' 'spec-s<N>-<slug>' 's*-retro.md' 'story-S<N>-1-slug.md'; do
        i82_is_sprint_token "$i82_p" \
          || err "I82's own probe: '$i82_p' was NOT flagged. That is one of the four positions measured in the tree, so the predicate cannot see the defect it exists to catch and every PASS above means nothing."
      done

    # --- I82b: a DIRECTORY core prescribes under an area spells the sprint slot ------
    # I82 above reads a prescription COMPONENT BY COMPONENT and asks whether any of them carries
    # a sprint token outside the slot. That question is unanswerable about a prescription which
    # names no sprint at all, and the blindness is structural rather than a gap in its regex:
    # `planning-artifacts/party-mode/` has no token in any component, so I82 passed it, and the
    # sprint dimension every artifact underneath it carries got placed by whoever wrote the first
    # file. Measured on the reference consumer: 24 blocking paths at
    # `_bmad-output/planning-artifacts/party-mode/s305/**`, produced by a prescription I82 read
    # and certified, while three earlier sprints had guessed a different and legal position for
    # the same artifact. A prose scanner cannot see a violation that only exists at expansion.
    #
    # WHAT IT ASSERTS, in both directions:
    #   * A path core prescribes which (a) ends at a DIRECTORY, (b) sits STRICTLY BELOW a declared
    #     area, and (c) spells the reserved slot nowhere, is under-specified: the grammar gives an
    #     area root exactly two shapes below it, `<name>.md` and `s<N>/`, so a directory in neither
    #     position is a slot the prescription declined to place. Write the slot.
    #   * Every `s<N>/` core DOES prescribe sits directly under a declared area. The grammar's
    #     `areas:` block is the declaration of where a slot may live and I82 already asserts every
    #     area sits under a scan root; without this converse, core could prescribe a slot in a
    #     position its own grammar never declared and nothing would read the contradiction.
    #     MEASURED: 43 slot-bearing prescriptions in the corpus, 0 whose slot parent is not a
    #     declared area — and removing one line from the `areas:` block produces exactly one
    #     offender, which is this direction's positive control on the live tree.
    #
    # HOW THE FALSE-POSITIVE SET REACHED ZERO, which is the part the next author will widen back.
    # The raw extraction over the same corpus I82 reads is 83 path-shaped strings; keeping only
    # the ones written with a trailing `/` leaves 10. Three narrowings take it to 0, and each is
    # DERIVED from a declaration rather than listed here:
    #   * a scan root itself (`_bmad-output/`) is below no area -> excluded by (b);
    #   * an AREA ROOT (`_bmad-output/specs/`, `docs/reviews/`) is not strictly below itself ->
    #     excluded by (b). Area roots are durable by definition and must never carry a slot, so
    #     a rule that flagged them would contradict the grammar it enforces;
    #   * anything already spelling the slot (`_bmad-output/specs/s<N>/<slug>/`) -> excluded by (c).
    # `_bmad-output/pipeline-history/` falls out through the first of those and not through a
    # carve-out, which matters because the grammar exempts it for a reason of its own and two
    # independent statements of one exemption is how they drift apart.
    i82b_a1="$(printf '%s\n' "$i82_areas" | grep -E '.' | head -1)"
    i82b_is_slot() {
      if [ -n "$i82_slot_re" ]; then
        [[ "$1" =~ $i82_slot_re ]]
      else
        [ "$1" = 's<N>' ] || [ "$1" = 's*' ]
      fi
    }
    # 0 == under-specified. Every early return names which of (a)/(b)/(c) acquitted the path.
    #
    # SPLIT WITH PARAMETER EXPANSION, NOT `printf | tr`. Both helpers here walk components of
    # every extracted path, and the obvious spelling forks twice per path. Measured: the arm as
    # first written put `validator-fork-budget` 84 forks over its 7000 ceiling, which that
    # fixture reports as a change to the suite's WALL CLOCK rather than as a style note — this
    # validator runs well over a hundred times per full push. `set -- $p` under a `/` IFS is not
    # the fix either: `s*` is a real component spelling here and would glob.
    i82b_underspecified() {
      local p="$1" a="" x rest c
      while IFS= read -r x; do
        [ -n "$x" ] || continue
        case "$p/" in "$x"/*) [ "${#x}" -gt "${#a}" ] && a="$x" ;; esac
      done <<<"$i82_areas"
      [ -n "$a" ] || return 1                     # (b) below no area at all
      rest="${p#"$a"/}"
      [ "$rest" != "$p" ] || return 1             # (b) IS an area root, not below one
      rest="$p"
      while [ -n "$rest" ]; do
        c="${rest%%/*}"
        if [ "$c" = "$rest" ]; then rest=""; else rest="${rest#*/}"; fi
        [ -n "$c" ] || continue
        i82b_is_slot "$c" && return 1             # (c) the slot is already placed
      done
      return 0
    }

    # THE SAME EXTRACTION AS I82's, MINUS THE ONE `sed` THAT ERASES THE SUBJECT. `i82_seen` ends
    # with `s#/$##`, so by the time I82 sees a path it can no longer tell a directory from a file
    # — which is why this arm re-extracts rather than filtering that set.
    i82b_dirs="$(grep -rhoE "(${i82_alt})/[A-Za-z0-9_./<>{}*-]*" "${i82_corpus[@]}" 2>/dev/null \
      | sed -e 's/[.,)]*$//' | grep '/$' | sed 's#/*$##' | grep -E '.' | sort -u)"

    if [ -z "$i82b_dirs" ]; then
      err "I82b extracted ZERO directory-shaped artifact paths from ${#i82_corpus[@]} rule file(s). Core prescribes several; zero means the trailing-slash extraction no longer matches how a directory is written, and an extractor that matches nothing reports every prescription as fully specified."
    else
      i82b_viol=""
      while IFS= read -r i82b_p; do
        [ -n "$i82b_p" ] || continue
        i82b_underspecified "$i82b_p" && i82b_viol="${i82b_viol}
  ${i82b_p}/"
      done <<<"$i82b_dirs"

      [ -n "$i82b_viol" ] && err "I82b core prescribes directory(ies) under a declared area that place no sprint slot:${i82b_viol}

An area root has exactly two legal shapes below it — a durable \`<name>.md\`, or \`s<N>/\`. A directory in neither position does not forbid a sprint token; it leaves the sprint UNPLACED, and the first session to write a file underneath picks a position that this invariant's sibling I82 cannot see, because at prose time there is no token to read. Spell it: <area>/s<N>/<dir>/, or move the directory up to be an area in artifact-path-grammar.md's \`areas:\` block."

      # PROVE IT CAN FIRE, BOTH DIRECTIONS, ON PATHS DERIVED FROM THE LIVE DECLARATION rather
      # than invented — an invented area would exercise the predicate against a tree the grammar
      # does not describe, and would go on passing after a real area was renamed out from under it.
      i82b_underspecified "${i82b_a1}/probe-findings" \
        || err "I82b's own probe: '${i82b_a1}/probe-findings' was NOT flagged. That is the exact shape measured on the reference consumer (a bare directory below an area, no slot), so the predicate cannot see the defect it exists to catch and every PASS above means nothing."
      i82b_underspecified "${i82b_a1}" \
        && err "I82b's own probe: the area root '${i82b_a1}' was flagged. An area is durable and carries no sprint token by definition, so this predicate rejects the one shape the grammar's \`areas:\` block requires."
      i82b_underspecified "${i82b_a1}/s<N>/probe-findings" \
        && err "I82b's own probe: '${i82b_a1}/s<N>/probe-findings' was flagged. It places the reserved slot correctly, so flagging it makes the remedy this invariant prescribes into a violation of it."

      # THE CONVERSE DIRECTION. Finds the prefix ABOVE the first slot component of every
      # prescription that has one, and requires it to be a declared area. `i82_seen` is reused
      # deliberately: a path is a file or a directory here without distinction, because the
      # question is where the SLOT sits and not what hangs below it.
      #
      # THE RESULT COMES BACK IN A GLOBAL, NOT ON STDOUT, for the same reason the split above is
      # parameter expansion: `$(f "$p")` forks once per call and this runs over the whole
      # extracted corpus. Membership goes through a `case` glob over a flattened copy of the
      # area list rather than a `grep` per path -- and a flattened list is also why the areas are
      # padded with spaces on both sides, so a prefix cannot match a longer sibling.
      i82b_par=""
      i82b_slot_parent() {                        # sets i82b_par: prefix above the first slot, or empty
        local acc="" c rest="$1"
        i82b_par=""
        while [ -n "$rest" ]; do
          c="${rest%%/*}"
          if [ "$c" = "$rest" ]; then rest=""; else rest="${rest#*/}"; fi
          [ -n "$c" ] || continue
          i82b_is_slot "$c" && { i82b_par="$acc"; return 0; }
          acc="${acc:+$acc/}$c"
        done
        return 0
      }
      i82b_areas_flat=" $(printf '%s' "$i82_areas" | tr '\n' ' ') "
      i82b_orphan=""
      i82b_nslot=0
      while IFS= read -r i82b_p; do
        [ -n "$i82b_p" ] || continue
        i82b_slot_parent "$i82b_p"
        [ -n "$i82b_par" ] || continue
        i82b_nslot=$(( i82b_nslot + 1 ))
        case "$i82b_areas_flat" in *" $i82b_par "*) continue ;; esac
        i82b_orphan="${i82b_orphan}
  $i82b_p    (slot parent '$i82b_par' is not a declared area)"
      done <<<"$i82_seen"

      [ "$i82b_nslot" -eq 0 ] && err "I82b found ZERO prescriptions carrying a sprint slot across ${#i82_corpus[@]} rule file(s). Core prescribes dozens; zero means the slot predicate no longer matches how the slot is written, and a predicate that matches nothing reports every slot as correctly sited."
      [ -n "$i82b_orphan" ] && err "I82b core prescribes a sprint slot in a position artifact-path-grammar.md's \`areas:\` block does not declare:${i82b_orphan}

The \`areas:\` block IS the declaration of where an \`s<N>/\` directory may live, and I82 above already requires every area to sit under a scan root. A slot prescribed outside that set is a home core invented in one rule file and told no reader about — the consumer's migrate and validate both resolve an artifact's area from this block, so the position holds only for as long as nobody asks. Add the parent to \`areas:\`, or move the prescription under an area already declared."
    fi
    fi
  fi
fi

# --- I83: the grammar's blocks have exactly ONE reader ------------------------
#
# THE STATE THIS MAKES UNREPRESENTABLE. A second file grows its own copy of the four-line awk
# that extracts `areas:` or the ```scan-roots fence out of artifact-path-grammar.md, the grammar
# is later widened, and whichever copy nobody edited goes on governing a SMALLER tree while
# printing the same clean line. That is not hypothetical: migrate-artifact-paths.sh and I82 above
# each carried a copy, byte-identical, and the conformance validator shipped in this release
# would have been the third. All three now resolve through core/scripts/artifact-path-config.sh.
#
# BOTH SIDES DERIVED. The corpus is every shipped `.sh` under core/ plus this repo's own
# scripts/ and .githooks/, found rather than listed, so a file that ships tomorrow is in scope
# without an edit here. The single exemption is the resolver itself — asking a file not to
# contain its own definition is asking it not to exist.
#
# core/fixtures/ is out of corpus for the reason I49, I50 and I59 state: fixtures deliberately
# carry ghost text and mutated copies, and a lint that reads them reports their mutants.
#
# FALSE-POSITIVE SET MEASURED BEFORE SHIPPING, which is this repo's bar for a new lint: ZERO
# files outside the resolver match, with a control proving the expression still matches the
# resolver itself.
# THE PREDICATE IS THE AWK ACTION, NOT THE PATTERN TEXT, and that narrowing was forced rather
# than chosen. Matching the pattern alone reported THIS FILE, because the expression below has to
# quote the thing it is looking for — the same self-reference the resolver exemption exists for,
# arriving one level out. Requiring the brace that opens an awk action separates an EXTRACTOR
# from a MENTION of one: the expression below writes the pattern escaped, an extractor writes it
# bare and follows it with an action.
I83_RESOLVER="core/scripts/artifact-path-config.sh"
i83_extracts() { grep -qE '/\^areas:\$/[[:space:]]*\{|scan-roots\$/[[:space:]]*\{' "$1"; }

# THE LIVENESS PROBE. This reports an ABSENCE and its whole answer is one grep. An expression
# that stopped matching would return the same empty set as a tree with one reader, so it is
# asked about two files whose answers are known, every run.
#
# THE PROBE'S EXTRACTOR IS ASSEMBLED FROM HALVES AND NEVER WRITTEN WHOLE, because a heredoc
# carrying it would make THIS file a positive — and the exemption that would fix that is an
# exemption for the one file copy number three actually lived in. Two halves that only ever meet
# at runtime cost nothing and keep the corpus honest.
i83_probe_dir="$(mktemp -d)"
i83_h='/^are'; i83_t='as:$/{f=1;next}'
printf '#!/usr/bin/env bash\nareas="$(awk %s%s%s%s \"$1\")"\n' \
  "'" "$i83_h" "$i83_t" "'" > "$i83_probe_dir/copy.sh"
printf '#!/usr/bin/env bash\necho no extraction here\n' > "$i83_probe_dir/clean.sh"
if ! i83_extracts "$i83_probe_dir/copy.sh"; then
  err "I83's own probe: a file carrying the areas extractor was NOT matched. The corpus result below is an empty set produced by an expression that matches nothing, which reads exactly like a tree with one reader."
elif i83_extracts "$i83_probe_dir/clean.sh"; then
  err "I83's own probe: a file carrying no extraction WAS matched, so every finding it prints is suspect."
else
  i83_extra=""
  i83_files=0
  i83_resolver_seen=0
  while IFS= read -r i83_f; do
    [ -n "$i83_f" ] || continue
    i83_files=$((i83_files + 1))
    i83_rel="${i83_f#"$REPO_ROOT/"}"
    if [ "$i83_rel" = "$I83_RESOLVER" ]; then
      i83_extracts "$i83_f" && i83_resolver_seen=1
      continue
    fi
    i83_extracts "$i83_f" && i83_extra="${i83_extra} $i83_rel"
  done < <( { find "$REPO_ROOT/core" -type f -name '*.sh' -not -path "$REPO_ROOT/core/fixtures/*"
              find "$REPO_ROOT/scripts" "$REPO_ROOT/.githooks" -type f 2>/dev/null; } | sort )
  if [ "$i83_files" -lt 20 ]; then
    err "I83 found only $i83_files file(s) to scan. The corpus is derived by find; a count this low means the tree is not the one this runs against, and an empty corpus reports the same one-reader line as a bound one."
  elif [ "$i83_resolver_seen" -ne 1 ]; then
    err "I83 did not find the grammar extraction in $I83_RESOLVER, the one file that is supposed to carry it. Either the resolver stopped reading the grammar — in which case every caller is resolving against nothing — or this invariant is looking at the wrong path, and its zero below means nothing."
  elif [ -n "$i83_extra" ]; then
    err "I83 file(s) other than $I83_RESOLVER extract the artifact path grammar's own blocks:${i83_extra}
  Widen \`areas:\` or the scan roots and whichever copy nobody edits goes on governing a smaller tree while reporting the same clean line — the fork migrate-artifact-paths.sh and I82 were one edit away from. Call \`artifact-path-config.sh --areas\` / \`--scan-roots\` instead."
  fi
fi
rm -rf "$i83_probe_dir"

# --- I84: the story corpus location is ONE declaration ------------------------
#
# THE STATE THIS MAKES UNREPRESENTABLE, and it is the state the tree was actually in. The story
# corpus path lived as a hard-coded literal in FOUR places — the schema, validate-mandatory-rules.sh,
# the protect hook and install.sh — so moving it under `s<N>/` (artifact-path-grammar.md rule 2)
# meant finding all four from memory. Three of them would have gone silently inert rather than
# loudly wrong: a protected-path pattern that matches nothing allows, a glob that matches nothing
# verifies nothing and prints PASS, and a scaffolded directory nobody writes to is invisible.
#
# schemas/sprint-status.json `story_file.stories_dir` is now the only home, and it is a TEMPLATE
# carrying the sprint slot rather than a path.
#
# TWO ARMS, because the restatement ban alone is satisfied by a tree where nothing resolves at all.
#   (a) no shipped PROGRAM carries an area-qualified story path;
#   (b) the home still carries the template WITH its slot, and every reader of the key also
#       substitutes the slot — a reader that reads the template and never substitutes composes a
#       path containing a literal `{sprint}`, which exists nowhere, and reports an empty corpus.
#
# NARROWED TO NON-COMMENT LINES, and the narrowing was forced: the two files that stopped
# restating the literal both EXPLAIN what they stopped doing, and quoting the old path is how they
# explain it. A line whose first non-space character is `#` is the comment form used throughout;
# an inline trailing comment is not stripped, and no shipped file has one carrying this path.
#
# core/fixtures/ is out of corpus for the reason I49, I50, I59 and I83 state: fixtures seed
# CONSUMER trees and must name concrete paths to do it.
#
# FALSE-POSITIVE SET MEASURED BEFORE SHIPPING: zero files match, with the probe below proving the
# expression still matches a restatement when one exists.
I84_SCHEMA="$REPO_ROOT/core/schemas/sprint-status.json"

# Assembled from halves and never written whole, for I83's reason one level out: a literal here
# would make THIS file the only positive, and the exemption that fixes that is an exemption for
# exactly the kind of file the ban exists for.
i84_a='planning-'; i84_b='artifacts[^ ]*stories'
i84_restates() { # <file> -> 0 when a non-comment line carries an area-qualified story path
  grep -v '^[[:space:]]*#' "$1" 2>/dev/null | grep -qE "${i84_a}${i84_b}"
}
# The SAME comment narrowing, and it is here because arm (b) fired on its first run without it:
# migrate-artifact-paths.sh MENTIONS `stories_dir` in the comment explaining why it deferred the
# corpus, and was scored as a reader that had forgotten to substitute. A mention is not a read.
i84_reads() { # <file> -> 0 when a non-comment line reads the declaration
  grep -v '^[[:space:]]*#' "$1" 2>/dev/null | grep -q 'stories_dir'
}

i84_probe_dir="$(mktemp -d)"
printf '#!/usr/bin/env bash\nD="_bmad-output/%s%s"\n' "$i84_a" 'artifacts/stories' > "$i84_probe_dir/restate.sh"
printf '#!/usr/bin/env bash\n# _bmad-output/%s%s is what this used to say\nP="*/stories/*.md"\n' \
  "$i84_a" 'artifacts/stories' > "$i84_probe_dir/clean.sh"
if ! i84_restates "$i84_probe_dir/restate.sh"; then
  err "I84's own probe: a file that DOES restate the story corpus path was not matched. The zero below is produced by an expression that matches nothing, which reads exactly like a tree with one declaration."
elif i84_restates "$i84_probe_dir/clean.sh"; then
  err "I84's own probe: a file carrying the path only in a COMMENT, and the component-keyed pattern the protect hook uses, WAS matched. The expression cannot tell a restatement from an explanation of one, so every finding it prints is suspect."
elif [ ! -r "$I84_SCHEMA" ]; then
  err "I84 cannot read core/schemas/sprint-status.json. It is the declared home of the story corpus template; absent it, every program composing a story path is unchecked and this invariant's silence is indistinguishable from conformance."
else
  i84_tmpl="$(sed -n 's/.*"stories_dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$I84_SCHEMA" | head -1)"
  i84_slot="$(sed -n 's/.*"stories_dir_sprint_placeholder"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$I84_SCHEMA" | head -1)"
  # `case`, not `printf | grep -qF`: a variable written into a grep at the end of a pipeline is
  # the EPIPE-under-pipefail class I54 exists for, and I54 flagged this line on its first run.
  i84_has_slot=0
  case "$i84_tmpl" in *"$i84_slot"*) i84_has_slot=1 ;; esac
  if [ -z "$i84_tmpl" ] || [ -z "$i84_slot" ]; then
    err "I84 read core/schemas/sprint-status.json but found stories_dir='${i84_tmpl:-<absent>}' and its slot placeholder='${i84_slot:-<absent>}'. Both are required: the declaration is the thing every reader resolves, and a reader resolving an empty template composes the repo root."
  elif [ "$i84_has_slot" -ne 1 ]; then
    err "I84 the stories_dir template '$i84_tmpl' does not contain its own sprint slot '$i84_slot'. Every sprint would then resolve to the SAME directory — the flat, cross-sprint corpus rule 2 exists to end — and it would do so silently, because a shared directory is a directory that exists."
  else
    i84_bad=""
    i84_nosub=""
    i84_readers=0
    i84_files=0
    while IFS= read -r i84_f; do
      [ -n "$i84_f" ] || continue
      i84_files=$((i84_files + 1))
      i84_rel="${i84_f#"$REPO_ROOT/"}"
      i84_restates "$i84_f" && i84_bad="${i84_bad} $i84_rel"
      if i84_reads "$i84_f"; then
        i84_readers=$((i84_readers + 1))
        grep -qF "$i84_slot" "$i84_f" 2>/dev/null \
          || grep -q 'stories_dir_sprint_placeholder' "$i84_f" 2>/dev/null \
          || i84_nosub="${i84_nosub} $i84_rel"
      fi
    done < <( { find "$REPO_ROOT/core" -type f -name '*.sh' -not -path "$REPO_ROOT/core/fixtures/*"
                find "$REPO_ROOT/scripts" "$REPO_ROOT/.githooks" -type f 2>/dev/null; } | sort )
    if [ "$i84_files" -lt 20 ]; then
      err "I84 found only $i84_files file(s) to scan. The corpus is derived by find; a count this low means the tree is not the one this runs against, and an empty corpus reports the same one-declaration line as a bound one."
    elif [ "$i84_readers" -lt 1 ]; then
      err "I84 found NO shipped program reading \`stories_dir\` at all. The declaration has a home and no readers, so the ban below is enforcing a rule nothing obeys — and Check 6, the story-status join and the protected-path set have all stopped resolving the corpus."
    elif [ -n "$i84_bad" ]; then
      err "I84 shipped program(s) restate an area-qualified story corpus path instead of resolving \`stories_dir\` from core/schemas/sprint-status.json:${i84_bad}
  That literal had four copies before this invariant, and moving the corpus under \`s<N>/\` meant finding them from memory. Three would have failed SILENTLY — a protected-path pattern that matches nothing allows, and a glob that matches nothing prints PASS. Read the template from the schema and substitute its slot."
    elif [ -n "$i84_nosub" ]; then
      err "I84 shipped program(s) read \`stories_dir\` but never name its sprint slot '$i84_slot':${i84_nosub}
  The value is a TEMPLATE, not a path. Using it unsubstituted composes a directory whose name contains '$i84_slot' literally — which exists nowhere, so the reader finds an empty corpus and reports it as clean."
    fi
  fi
fi
rm -rf "$i84_probe_dir"

# --- I85: no shipped script command-substitutes inside its own operator message ----
# BACKTICKS INSIDE A DOUBLE-QUOTED STRING ARE COMMAND SUBSTITUTION. A message written
# `like this` runs the quoted word as a command, prints `<word>: command not found` on
# stderr, and substitutes the empty output -- so the word VANISHES from the message the
# operator reads. The remediation still looks like a sentence, which is why nobody sees it.
#
# MEASURED WHEN THIS WAS WRITTEN, and reported by the reference consumer as PC-S320:
# `reconcile/layer-drift.sh` carried four of them, lines 960/963/967/970, and every one
# wrapped the token `still-additive`. That token is the VERDICT an operator must write into
# the adjudication register to clear an `OVERRIDE-SUPERSEDED` row -- an ADJUDICATED row that
# BLOCKS the pull. So the blocking row's own remedy read "records  with a reason and the
# block clears": it told the operator a verdict clears the block and deleted which verdict.
# The same file already carried correctly-escaped backticks, so the idiom was known and four
# sites were missed -- which is exactly the shape a lint catches and review does not.
#
# THE FALSE-POSITIVE SET WAS MEASURED BEFORE THIS SHIPPED, and it is why the scan resolves
# heredoc quoting rather than grepping for a backtick. A crude probe flags SEVEN files; six
# are inert, every one of them Python inside a `<<'PY'`-style QUOTED heredoc, where the shell
# expands nothing and a backtick is a literal. Exactly one file executed. Shipping the crude
# form would have put six correct files into the finding set, which is how a lint gets turned
# off.
#
# SCOPE. Shipped shell only, and only lines that are continuation/message lines of a
# double-quoted string. This deliberately does not chase every backtick in every expression:
# the subject is text written FOR AN OPERATOR that silently loses a word.
i85_scan() { # i85_scan <root> -> "<file>:<line>: <word>" per finding
  find "$1" -type f -name '*.sh' 2>/dev/null | sort | while IFS= read -r i85_f; do
    awk -v F="$i85_f" '
      # Track heredoc state so a QUOTED heredoc (<<EOF with quotes) is skipped entirely.
      hd == "" {
        if (match($0, /<<-?[ \t]*("[A-Za-z_]+"|'"'"'[A-Za-z_]+'"'"'|[A-Za-z_]+)/)) {
          d = substr($0, RSTART, RLENGTH)
          sub(/^<<-?[ \t]*/, "", d)
          q = (substr(d,1,1) == "\"" || substr(d,1,1) == "'"'"'")
          gsub(/["'"'"']/, "", d)
          hd = d; hdq = q; next
        }
      }
      hd != "" { if ($0 == hd) { hd = ""; hdq = 0 } ; next }
      # Only message lines: a continuation line that opens with a double quote.
      /^[ \t]*"/ {
        line = $0
        for (i = 1; i <= length(line); i++) {
          c = substr(line, i, 1)
          p = (i > 1) ? substr(line, i-1, 1) : ""
          if (c == "`" && p != "\\") {
            rest = substr(line, i+1)
            if (match(rest, /^[^`]*`/)) {
              w = substr(rest, 1, RLENGTH-1)
              printf "%s:%d: %s\n", F, NR, w
              i = i + RLENGTH
            }
          }
        }
      }
    ' "$i85_f"
  done
}

# The probe proves BOTH directions in the same run: a zero from a scanner that cannot see
# the positive is not a clean tree, and a scanner that also flags the heredoc form would
# ship the six-file false-positive set this narrowing exists to exclude. Built here rather
# than committed, because a probe in the tree is a subject.
i85_probe="$(mktemp -d 2>/dev/null)"
if [ -n "$i85_probe" ] && [ -d "$i85_probe" ]; then
  {
    printf 'emit X \\\n'
    printf '  "records `%s` with a reason"\n' 'still-additive'
  } > "$i85_probe/bad.sh"
  {
    printf 'emit X \\\n'
    printf '  "records \\\\`%s\\\\` with a reason"\n' 'still-additive'
    printf "python3 - <<'PY'\n"
    printf '  "a docstring saying `%s` inside a quoted heredoc"\n' 'still-additive'
    printf 'PY\n'
  } > "$i85_probe/ok.sh"
  i85_pos="$(i85_scan "$i85_probe" | grep -c 'bad\.sh' || true)"
  i85_neg="$(i85_scan "$i85_probe" | grep -c 'ok\.sh' || true)"
  rm -rf "$i85_probe"
  if [ "$i85_pos" -eq 0 ]; then
    err "I85's own positive probe was NOT reported: an unescaped backtick inside a double-quoted message went unseen by the scanner, so a clean result below would mean nothing. The invariant fails closed rather than reporting an absence its instrument could not have found."
  fi
  if [ "$i85_neg" -ne 0 ]; then
    err "I85's negative probe WAS reported: either a correctly ESCAPED backtick or one inside a QUOTED heredoc was flagged. Both are correct code — the heredoc form alone is six live files — and shipping this would put them in the finding set, which is how a lint gets turned off."
  fi
else
  err "I85 could not create its probe directory, so neither direction of its scanner was proven this run. A finding set it produces now is unattributable."
fi

i85_hits="$( { i85_scan "$REPO_ROOT/core"; i85_scan "$REPO_ROOT/scripts"; } 2>/dev/null )"
if [ -n "$i85_hits" ]; then
  err "I85 shipped script(s) command-substitute inside an operator-facing message. Backticks in a double-quoted string RUN the quoted word and substitute its empty output, so the word is deleted from what the operator reads and the shell prints '<word>: command not found'. Escape them as \\\` :
$(printf '%s\n' "$i85_hits" | sed 's|^|  |')"
fi

# --- I86: the adjudication row token is ONE string, and apply.sh may not restate it ----
# apply.sh had NO reader for the adjudication register and therefore emitted a destructive
# override-retire worklist over an entry whose `still-additive` verdict was already recorded --
# while layer-drift.sh, which DOES read the register, correctly emitted no blocking row. The two
# tools disagreed, and the one an operator is told to work top-down was the wrong one. Measured on
# the reference consumer that filed it (PC-S327): 0 mentions of the register in apply.sh against 2
# in layer-drift.sh, and the prescribed step would have deleted 119 consumer-only lines the verdict
# exists to keep.
#
# The fix routes the answer through the ROW: layer-drift.sh declares `ADJ_ROW_TOKEN`, writes it
# into the OVERRIDE-SUPERSEDED detail when a verdict is recorded for that digest, and apply.sh
# RESOLVES that declaration rather than restating it.
#
# WHY THIS IS AN INVARIANT AND NOT A COMMENT. A restated literal drifts silently: apply.sh's case
# arm simply stops matching, and a pull with an adjudicated row then looks exactly like a pull with
# none. And the first draft of that arm referenced the variable without resolving it at all, which
# under apply.sh's `set -u` aborts the run mid-apply -- so both failure directions are live.
i86_decl="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/layer-drift.sh"
i86_read="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/apply.sh"
if [ ! -r "$i86_decl" ] || [ ! -r "$i86_read" ]; then
  err "I86 cannot read both sides of the join ($i86_decl, $i86_read). An unreadable side reports the same silence as an agreeing one."
else
  i86_tok="$(sed -n 's/^ADJ_ROW_TOKEN="\([A-Za-z_][A-Za-z0-9_-]*\)".*/\1/p' "$i86_decl" | head -1)"
  if [ -z "$i86_tok" ]; then
    err "I86 found no ADJ_ROW_TOKEN declaration in layer-drift.sh. It is the single home of the token apply.sh resolves; without it apply.sh fails closed at runtime, and this invariant has no subject."
  else
    # apply.sh must RESOLVE it (name the declaration) and must NOT carry the bare literal.
    grep -q 'ADJ_ROW_TOKEN=.*layer-drift\.sh\|sed -n .*ADJ_ROW_TOKEN.*layer-drift\.sh' "$i86_read" 2>/dev/null \
      || grep -q 'layer-drift\.sh' "$i86_read" 2>/dev/null \
      || err "I86 apply.sh does not resolve ADJ_ROW_TOKEN from layer-drift.sh. Without that resolution it either restates the literal (which drifts silently) or leaves the variable unbound (which aborts the run under set -u)."
    if grep -qE "(\"|')${i86_tok}(\"|')" "$i86_read" 2>/dev/null; then
      err "I86 apply.sh restates the adjudication row token literal '${i86_tok}' instead of resolving it from layer-drift.sh. Two copies of a token one side writes and the other matches on is the drift this join exists to prevent: the case arm stops matching and a pull carrying an adjudicated row reads exactly like one carrying none."
    fi
    # And the writer must still WRITE it into the row, or the reader matches nothing forever.
    grep -q '\${ADJ_ROW_TOKEN}=' "$i86_decl" 2>/dev/null \
      || err "I86 layer-drift.sh declares ADJ_ROW_TOKEN but never writes it into a row. The token has a home and no emitter, so apply.sh's suppression can never fire — a check that cannot fire reading exactly like one that passed."
  fi
fi

# --- I87: a fixture cannot inherit a consumer's AI_DLC_* tunable and test the CONFIG ----
#
# THE DEFECT THIS WAS DERIVED FROM. v0.289.0 fixed three fixtures that read a tunable out of the
# AMBIENT environment and therefore asserted against whatever the developer's `.claude/settings.json`
# happened to say. A fixture in that state does not fail — it passes for the wrong reason on the
# machine that set the key, and fails on a correct build for the machine that set it differently.
#
# THE SUBJECT SET WAS THE WHOLE PROBLEM, and the plan that owed this guard predicted the wrong
# side. It said the honest subject is "the declared consumer-settable tunables" and that the
# declaration had to be derived first. There is no such declaration, and there does not need to be:
# a tunable is ambient-dangerous exactly when a SHIPPED PROGRAM DEREFERENCES IT, which is derived
# from the code on both sides and cannot go stale.
#
# THE NARROWING, MEASURED AT EVERY STEP rather than argued:
#
#   any fixture naming any AI_DLC_* token                              37
#   -> keys a shipped program actually dereferences                    24   (67 such keys exist)
#   -> minus fixtures that ASSIGN the key themselves                   11 -> 2
#   -> minus comments and single-quoted program text                    2 -> 0
#
# The 19-fixture false-positive set the plan recorded was produced by the first line of that
# table. Most of those fixtures name keys they invent as their own worker-pool plumbing
# (`AI_DLC_LCC_OUT`, `AI_DLC_SFD_SCRIPT`, `AI_DLC_TAC_VALIDATOR`, `AI_DLC_RFO_DETECT`,
# `AI_DLC_CMI_VALIDATOR`) — 21 tokens with NO shipped reader at all, so no consumer can set them
# and clearing them protects nothing.
#
# THE LAST TWO NARROWINGS EACH CAME FROM ONE MEASURED FALSE POSITIVE, and both are named here so
# the exclusions are auditable rather than tidy:
#   * `whole-read-pool` names `AI_DLC_SELF_DIR` in a COMMENT explaining why a lone copy fails.
#   * `enforcement-map-derivations` names `AI_DLC_REATTACH_BUDGET` inside a single-quoted awk
#     program — it is building a mutation STRING, where no expansion happens at all.
#
# ZERO SUBJECTS TODAY, WHICH IS WHY THE PROBE IS NOT OPTIONAL. This is a regression guard: the
# three fixtures that had the defect were fixed before it existed. A guard whose real answer is
# always zero is exactly this repo's "a check that cannot fire reads like one that passed", so it
# is asked every run to answer a tree whose answer is known — one exposed probe fixture, and two
# that must stay silent for the two different reasons the exclusions encode.
#
# ONE READER, used by the corpus scan AND by the probe. A probe exercising a copy proves the copy.
i87_readable() {   # <root> -> AI_DLC_* keys a shipped program dereferences, one per line
  { find "$1/core" "$1/scripts" -type f \( -name '*.sh' -o -name '*.js' -o -name '*.py' \) \
       -not -path '*/core/fixtures/*' 2>/dev/null | while IFS= read -r _f; do
      grep -ohE '\$\{?AI_DLC_[A-Z0-9_]+' "$_f" 2>/dev/null
    done; } | sed -E 's/^\$\{?//' | sort -u
}
i87_exposed_in() { # <fixture dir> <readable-key file> -> exposed keys, one per line
  local d="$1" rk="$2" blob named assigned
  blob="$(cat "$d"/*.sh 2>/dev/null)"
  # The clearing loop makes every key in this fixture safe at once — that is its whole purpose.
  grep -q 'unset "\$_v"' <<<"$blob" && return 0
  grep -q 'unset AI_DLC' <<<"$blob" && return 0
  assigned="$(grep -ohE '(^|[[:space:]]|;|export[[:space:]]+)AI_DLC_[A-Z0-9_]+=' <<<"$blob" 2>/dev/null \
              | grep -ohE 'AI_DLC_[A-Z0-9_]+' | sort -u)"
  # LIVE LINES ONLY: not a comment, and not a line whose token sits inside single quotes.
  named="$(grep -vE '^[[:space:]]*#' <<<"$blob" \
           | grep -vE "'[^']*AI_DLC_[A-Z0-9_]+[^']*'" \
           | grep -ohE 'AI_DLC_[A-Z0-9_]+' | sort -u)"
  [ -n "$named" ] || return 0
  grep -Fxf "$rk" <<<"$named" 2>/dev/null | { [ -n "$assigned" ] && grep -Fxv "$assigned" || cat; }
}

i87_probe_dir="$(mktemp -d)"
mkdir -p "$i87_probe_dir/core/scripts" "$i87_probe_dir/scripts" \
         "$i87_probe_dir/fx-exposed" "$i87_probe_dir/fx-assigns" "$i87_probe_dir/fx-comment"
printf '%s\n' '#!/usr/bin/env bash' 'echo "${AI_DLC_I87_PROBE:-default}"' > "$i87_probe_dir/core/scripts/i87-probe.sh"
printf '%s\n' '#!/usr/bin/env bash' 'bash i87-probe.sh' 'echo AI_DLC_I87_PROBE' > "$i87_probe_dir/fx-exposed/run.sh"
printf '%s\n' '#!/usr/bin/env bash' 'AI_DLC_I87_PROBE=fixed' 'bash i87-probe.sh' > "$i87_probe_dir/fx-assigns/run.sh"
printf '%s\n' '#!/usr/bin/env bash' '# AI_DLC_I87_PROBE is named only here' 'bash i87-probe.sh' > "$i87_probe_dir/fx-comment/run.sh"
i87_prk="$i87_probe_dir/readable.txt"; i87_readable "$i87_probe_dir" > "$i87_prk"
i87_p_exp="$(i87_exposed_in "$i87_probe_dir/fx-exposed" "$i87_prk" | tr '\n' ' ')"
i87_p_asg="$(i87_exposed_in "$i87_probe_dir/fx-assigns" "$i87_prk" | tr '\n' ' ')"
i87_p_cmt="$(i87_exposed_in "$i87_probe_dir/fx-comment" "$i87_prk" | tr '\n' ' ')"
rm -rf "$i87_probe_dir"

if ! grep -q 'AI_DLC_I87_PROBE' <<<"$i87_p_exp"; then
  err "I87's join did not fire on its own probe: a fixture naming a key a shipped program dereferences, without assigning it and without clearing the environment, was NOT reported [probe answered: ${i87_p_exp:-<nothing>}]. Either the readable-key derivation matched nothing or the naming scan did; the corpus result below is then an empty set produced by an extraction that cannot find an exposure, which reads exactly like a suite with none."
elif grep -q 'AI_DLC_I87_PROBE' <<<"$i87_p_asg"; then
  err "I87 reported a fixture that ASSIGNS the key itself [probe answered: $i87_p_asg]. A fixture setting the value cannot inherit one, so every fixture that pins its own tunable becomes a finding — and that is most of the suite."
elif grep -q 'AI_DLC_I87_PROBE' <<<"$i87_p_cmt"; then
  err "I87 reported a key named only in a COMMENT [probe answered: $i87_p_cmt]. That exclusion was derived from a measured false positive (whole-read-pool explaining why a lone copy fails); without it the guard fires on fixtures documenting the very hazard it exists for."
else
  i87_rk="$(mktemp)"; i87_readable "$REPO_ROOT" > "$i87_rk"
  i87_nrk="$(grep -c . "$i87_rk")"
  i87_nfx="$(find "$REPO_ROOT/core/fixtures" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | grep -c .)"
  if [ "$i87_nrk" -lt 20 ] || [ "$i87_nfx" -lt 20 ]; then
    err "I87 derived $i87_nrk dereferenced AI_DLC_* key(s) across $i87_nfx fixture(s); counts this low mean one of the two sides stopped matching the tree, and an empty key set reports every fixture as safe without reading one."
  else
    i87_bad=""
    while IFS= read -r i87_d; do
      [ -n "$i87_d" ] || continue
      i87_k="$(i87_exposed_in "$i87_d" "$i87_rk" | tr '\n' ' ')"
      [ -n "${i87_k// /}" ] && i87_bad="${i87_bad}
  $(basename "$i87_d")    ${i87_k}"
    done < <(find "$REPO_ROOT/core/fixtures" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
    [ -n "$i87_bad" ] && err "I87 fixture(s) name an AI_DLC_* tunable a shipped program reads, without assigning it and without clearing the ambient environment:${i87_bad}

Each one asserts against whatever the developer's .claude/settings.json happens to say — it passes for the wrong reason on the machine that set the key and fails on a correct build for the machine that set it differently. v0.289.0 fixed three fixtures in exactly that state. Add the clearing loop the suite already uses (\`for _v in \$(env | sed -n 's/^\\(AI_DLC_[A-Za-z0-9_]*\\)=.*/\\1/p'); do unset \"\$_v\"; done\`) or set the key explicitly."
    rm -f "$i87_rk"
  fi
fi

# --- I89 / I90: the procedure citation join, and the fix-imperative attribution --
#
# Two invariants over the same corpus in one python process, because the cost of this
# script is process spawn (see in_lines above) and both read the same twenty-odd step
# files. Measured: 62ms for ten runs of the pair, against this script's 13.9s baseline.
#
# =============================================================================
# I89 -- a procedure citation must resolve to a heading that exists.
# =============================================================================
# `_gate-procedures.md` holds ten procedures that step files invoke BY NAME -- the file
# says so itself: "These procedures are invoked **by name** from pipeline step files."
# The name IS the linkage. There is no anchor, no id, no include; a step file that says
# READ AND FOLLOW `_gate-procedures.md` "Adversarial repair dispatch" finds it by
# scanning for that string.
#
# WHAT THIS RELEASE ALMOST SHIPPED, AND WHY I11 COULD NOT SEE IT. v0.357.0 widened the
# heading from `## Adversarial repair dispatch` to `## Adversarial repair dispatch
# (referenced by step files and by the gate)`, because the gate became its second caller.
# Five step-file edits landed in the same change citing the procedure by its old name.
# They still resolve -- the new heading CONTAINS the cited string as a prefix -- and that
# is luck, not a mechanism. I11 substring-matches the literal "Adversarial repair
# dispatch" in the STEP FILES to derive its set (b); it never reads the heading at all,
# so a rename in the other direction (`## Repair dispatch`) would strand every citation
# in the corpus and I11 would report the same clean line it reports today. A pointer that
# fails silently is worse than no pointer: the step file still tells the reader to go and
# follow a procedure, and nothing is there.
#
# BOTH SIDES ARE DERIVED. Headings come from `^## ` with the `(referenced by ...)`
# qualifier stripped -- stripped on the HEADING side rather than tolerated on the citing
# side, so the qualifier stays free to change without touching thirteen files. Citations
# come from an emphasised phrase ADJACENT to a `_gate-procedures.md` mention, in the five
# forms the corpus actually uses (`file, "Name"`, `file — "Name"`, `file \"Name\"`,
# `file **Name**`, `file § *Name*`, and `**Name** sub-routine (file)`).
#
# ADJACENCY IS THE WHOLE FALSE-POSITIVE MEASUREMENT. A plain proximity window (+/-200
# chars) over the same corpus returns 59 candidates with ELEVEN non-citations: bold field
# labels (`**Carrier:**`, `**Review passes:**`), quoted prose ("the user is still
# active"), and sentences that happen to be emphasised near a file mention
# (`**Join it with the bounded-join beat**`). Requiring adjacency drops those eleven and
# keeps every real citation: 48 candidates across 13 files, ZERO unresolved, all ten
# headings cited.
#
# The second arm is dormancy. A procedure nobody invokes reads exactly like a live one,
# and this file's contract is that every procedure in it has a caller.
#
# =============================================================================
# I90 -- a fix-imperative names a seat, or declares that it does not.
# =============================================================================
# Rule 28(c): the lead owns PASS/FAIL, the disposition and the escalation; the EDIT that
# follows is dispatched. v0.25.0 purged the bare "fix it directly" imperatives from the
# step files once. They grew back -- v0.357.0 requalified six more, measured against a
# consumer session in which the lead made 104 inline `Edit` calls during one gate
# remediation and dispatched the `remediator` zero times. This is the mechanism that
# stops the third growth; the PreToolUse deny is what stops the edits.
#
# THE GRAMMAR IS THE ENTIRE DESIGN, AND TWO BROADER ONES WERE MEASURED AND REJECTED
# rather than argued about:
#
#   (1) line starts with a fix verb                    19 hits, mostly `### 14. Update
#                                                      pipeline snapshot.` headings and
#                                                      line-wrap fragments
#   (2) sentence-initial fix imperative                20 hits, 15 with no dispatch
#                                                      target -- and 11 of those 15 are
#                                                      correct prose
#   (3) sentence-initial fix imperative whose OBJECT     8 hits, 4 firing, and all four
#       is a FINDING                                     just-requalified sites silent
#
# (3) ships. The object test is what makes it shippable: the lead's Rule 28(a) mutations
# name a FILE -- "Update `_bmad-output/pipeline-snapshot.md`", "Update sprint-status.yaml
# in the same commit" -- and drop out of the population on their own, with nothing
# hand-listed anywhere. A remediation imperative names a FINDING: gaps, findings,
# improvements, a mismatch. That is the class Rule 28(c) is about.
#
# FIRST-RUN YIELD, recorded because it is the argument for the check existing: the A6
# purge requalified ONE site per file and left a second one of identical shape in the
# SAME file twice -- `stories-test-strategy.md` (:548 fixed, :18 left) and
# `research-requirements.md` (:40 fixed, :105 left). Both were repaired before this
# shipped. A hand sweep found six; this found the two the hand sweep walked past.
#
# THE CARVE-OUT IS DECLARED IN THE STEP FILE, NEVER LISTED HERE. That is the I20/I74
# posture and it exists for the same reason: a carve-out list living in the checker is
# invisible to the person reading the rule. Two accepted forms -- a `Rule 28(a)` citation,
# or `<!-- inline-ok: <reason> -->`. The reason is REQUIRED to be non-empty, because a
# marker with no reason is a decision nobody can audit; seven `.dist-only` markers were
# zero bytes until I74(d) said the same thing.
#
# SKILL.md IS IN THE CORPUS, AND ARM 2 IS WHY. Extending a step-file grammar onto normative
# rule text is not obviously safe, so the wrong answers were measured before the right one:
#
#   arm 1 alone, applied to SKILL.md                       population 0
#   "any imperative in a RESIDENT rule with no actor named" 12 hits, 12 of them CORRECT
#
# That second grammar is the one to refuse, and the reason generalises. SKILL.md's implicit
# grammatical subject IS the lead -- every rule is addressed to it -- so "the actor is
# unattributed" is the NORMAL and correct form of nearly every rule sentence ("Do not skip
# sections", "Do not summarize", "Write escalations to pending.md"). What separated Rule 7's
# defect from those twelve was never attribution; it was whether the ACT is delegable. That
# is a semantic judgment and a lint cannot make it.
#
# What CAN be checked is the narrow rhetorical form Rule 7 actually used, which arm 2 is:
# `Just`/`Simply` + a repair verb + a pronoun. Those two words are an instruction not to
# route the act, which is exactly the thing Rule 28(c) removes. Measured false-positive set
# across steps/*.md AND SKILL.md: EMPTY. A bare pronoun-object widening without the prefix
# takes it to 1 -- `route.md`'s "Resolve it here", where "it" is a sprint_id being DERIVED --
# and that one line is why the prefix is mandatory rather than decorative.
#
# WHY THE FILE IS WORTH THE CORPUS SLOT AT ALL: Rule 7 sits at byte 8,722, RESIDENT above the
# 20,000-byte re-attach cut. Rule 28, which attributed it, sits at 79,510, and
# `_gate-procedures.md` is a separate file the lead never loaded. 13 of 31 rules are resident,
# 18 are below the cut. A compacted lead therefore holds "Just fix it" verbatim and holds
# nothing that says who fixes it. Proven: reverting Rule 7 to its pre-v0.357.0 text makes this
# invariant fire at SKILL.md:185, against a same-tree control that reports nothing.
#
# NOT ATTEMPTED, DELIBERATELY: reporting which resident rules depend on below-cut material
# for their attribution. 9 of 13 cite a below-cut rule or an external step file, and that
# count is not 9 defects -- most are legitimate pointers to a procedure. Separating "points
# at a procedure" from "depends on it for who acts" is the valuable half and this grammar
# cannot do it, so it does not pretend to.
#
# BOTH INVARIANTS ANSWER A KNOWN TREE FIRST. I89's real answer is "everything resolves"
# and I90's known-good arms are the requalified sites -- and an extraction that has
# stopped matching reports exactly that same silence. The probe renames a heading and
# requires the strand to be reported; it feeds I90 a bare imperative, a dispatched one, a
# declared one, an empty-reason marker and a file-object imperative, and requires the
# five verdicts to differ in the five ways the grammar claims. If any probe answers
# wrong, that is the only error reported and the corpus scan does not run -- a corpus
# result from a reader that cannot find its subject is worth nothing.
I89_PY="$(mktemp)"
cat > "$I89_PY" <<'I89EOF'
import os, re, sys, tempfile, shutil

ROOT = sys.argv[1]
STEPS = os.path.join(ROOT, "core/skills/ai-dlc/steps")
GP = os.path.join(STEPS, "_gate-procedures.md")
ROLES_DIR = os.path.join(ROOT, "core/team-roles")

def out(msg):
    sys.stdout.write("ERR\t" + msg.replace("\n", "\\n") + "\n")

def collapse(t):
    return re.sub(r"\s+", " ", t)

# ---------------------------------------------------------------- I89 predicates
# Side A. The heading lines as written. The resolve is CONTAINMENT against these (see
# i89 below); base_name only supplies a readable name for the dormancy message.
def raw_headings(gp_text):
    return [m.group(1).strip() for m in re.finditer(r"^## (.+)$", gp_text, re.M)]

def base_name(h):
    return re.sub(r"\s*\(referenced by [^)]*\)\s*$", "", h).strip()

# Side B. A citation is an EMPHASISED phrase ADJACENT to a `_gate-procedures.md`
# mention. Adjacency is what keeps the false-positive set empty -- see the header.
_EMPH = r'(?:\\?"([^"\\]{3,60})\\?"|\*\*([^*]{3,60})\*\*|\*([^*]{3,60})\*)'
_FILE = r'_gate-procedures\.md`?'
CITE_PATS = [
    re.compile(_FILE + r'[\s,\.—\-§]{0,6}' + _EMPH),
    re.compile(_EMPH + r'\s+sub-routines?\s*\(`?' + _FILE),
]

def citations(text):
    coll = collapse(text)
    found = []
    for pat in CITE_PATS:
        for m in pat.finditer(coll):
            g = [x for x in m.groups() if x]
            if g:
                found.append((g[0].strip(), coll[max(0, m.start() - 70):m.end() + 30]))
    return found

def i89_corpus():
    files = []
    for base in (os.path.join(ROOT, "core/skills/ai-dlc"), ROLES_DIR):
        for d, _, fs in os.walk(base):
            for f in fs:
                if f.endswith(".md") and f != "_gate-procedures.md":
                    files.append(os.path.join(d, f))
    return sorted(files)

def i89(gp_path, corpus):
    # BIND ON THE SUBSTRING, NOT THE HEADING LINE. A citation resolves when SOME heading
    # CONTAINS the cited phrase. Equality against the whole line would go red the moment
    # anyone touched the `(referenced by ...)` qualifier — churn, not protection — and
    # containment is also how I11 already reads this file (`"Adversarial repair dispatch"
    # in collapsed_text`), so the two cannot disagree about what a citation is. Stripping
    # the parenthetical is kept for NAMING a heading in the dormancy message; the resolve
    # itself never depends on the qualifier having a particular shape, which matters
    # because the next qualifier may not be parenthesised at all.
    raw = raw_headings(open(gp_path, encoding="utf-8").read())
    unresolved, cited = [], set()
    n = 0
    for p in corpus:
        for name, ctx in citations(open(p, encoding="utf-8").read()):
            n += 1
            hit = [h for h in raw if name in h]
            if hit:
                cited.update(hit)
            else:
                unresolved.append((p, name, ctx))
    dormant = sorted(base_name(h) for h in raw if h not in cited)
    return unresolved, dormant, n, len(raw)

# ---------------------------------------------------------------- I90 predicates
# A fix-imperative is a SENTENCE-INITIAL repair verb whose object is a FINDING, not a
# named file. That object test is the narrowing; see the header for the three grammars
# measured and the population each returned.
# CASE-TOLERANT FIRST LETTER, and it is not cosmetic: the `Just `/`Simply ` prefix leaves the
# verb LOWERCASE ("Just fix it"), so a capitalised-only class cannot match the one sentence
# this invariant most exists to catch. The same defect I57 carried until v0.357.0. The match
# is anchored at a SENTENCE start, so admitting lowercase costs nothing mid-prose.
I90_VERBS = r"(?:[Aa]pply|[Ff]ix|[Rr]epair|[Cc]orrect|[Rr]emediate|[Rr]esolve|[Aa]ddress)"
I90_OBJ = (r"(?:gap|finding|improvement|fix|issue|mismatch|misalignment|defect"
           r"|error|ERROR|problem|violation)(?:e?s)?")
# ARM 1 -- the object is a FINDING. See the header for the populations measured.
I90_PAT = re.compile(
    r"^(?:Just\s+|Simply\s+|Then\s+|Also\s+)?" + I90_VERBS +
    r"\s+(?:all\s+|any\s+|the\s+|every\s+|each\s+|its\s+|those\s+|these\s+)?"
    r"(?:\S+\s+){0,2}?" + I90_OBJ + r"\b")
# ARM 2 -- the DISMISSIVE bare imperative: "Just fix it", "Simply apply them". A pronoun
# object is far too broad on its own (it selects `route.md`'s "Resolve it here", where "it"
# is a sprint_id being DERIVED, not a finding being repaired). The `Just`/`Simply` prefix is
# the whole discriminator, and it is a discriminator about MEANING rather than a lucky
# narrowing: those words are the rhetorical instruction not to route the act. Measured FP set
# across steps/*.md and SKILL.md: EMPTY.
I90_DISMISSIVE = re.compile(
    r"^(?:Just|Simply)\s+" + I90_VERBS + r"\s+(?:it|them|these|those)\b")
# A closing quote or bracket may sit between the stop and the space. Without this the
# sentence `Do not ask "should I fix this?" Just fix it.` is ONE unit beginning "Do", and
# Rule 7's "Just fix it" is invisible -- measured against the pre-fix text.
I90_SENT = re.compile(r"""(?<![A-Z0-9])[.!?]["'”’)\]]*(?:\s+|$)""")

def i90_dispatch_re(roles):
    return re.compile(
        r"`(?:" + "|".join(sorted(roles)) + r")`|dispatch|teammate"
        r"|route (?:it |them )?back to|delegat|sub-routine", re.I)

# The carve-out is DECLARED IN THE STEP FILE, never listed here -- the I20/I74 posture.
I90_MARKER = re.compile(r"<!--\s*inline-ok:\s*(.*?)\s*-->", re.S)
I90_RULE28A = re.compile(r"Rule 28\(a\)")

def i90_blocks(path):
    """[(line_no, block_text)]. A block is one list item or one paragraph run.
    Headings and fenced code are excluded: `### 4. Apply Process Improvements` is a
    section title, not an instruction."""
    out_, fence, cur = [], False, None
    for i, l in enumerate(open(path, encoding="utf-8").read().split("\n"), 1):
        if l.lstrip().startswith("```"):
            fence = not fence
            continue
        if fence:
            continue
        if l.startswith("#") or not l.strip():
            if cur:
                out_.append(cur)
                cur = None
            continue
        m = re.match(r"^\s*(?:[-*+]\s+|\d+\.\s+)", l)
        if m:
            if cur:
                out_.append(cur)
            cur = [i, l[m.end():]]
        elif cur:
            cur[1] += " " + l.strip()
        else:
            cur = [i, l.strip()]
    if cur:
        out_.append(cur)
    return out_

def i90_corpus(root):
    """The step files AND SKILL.md. SKILL.md is in the corpus because Rule 7 ended on a
    bare `Just fix it.` whose actor was established only by Rule 28 -- and Rule 7 sits at
    byte 8,722, RESIDENT above the 20,000-byte re-attach cut, while Rule 28 sits at 79,510
    and `_gate-procedures.md` is a separate file the lead never loaded. A compacted lead
    holds the imperative and holds neither thing that attributes it. The reader who does not
    follow the pointer is not a careless reader; after a compaction it is the only reader."""
    files = []
    steps = os.path.join(root, "core/skills/ai-dlc/steps")
    if os.path.isdir(steps):
        files += [os.path.join(steps, f) for f in sorted(os.listdir(steps))
                  if f.endswith(".md")]
    sk = os.path.join(root, "core/skills/ai-dlc/SKILL.md")
    if os.path.isfile(sk):
        files.append(sk)
    return files

def i90_scan(paths, roles, root=None):
    disp = i90_dispatch_re(roles)
    fires, silent, bad = [], [], []
    for path in paths:
        name = os.path.relpath(path, root) if root else os.path.basename(path)
        for ln, block in i90_blocks(path):
            block = collapse(block)
            for m in I90_MARKER.finditer(block):
                if not m.group(1).strip():
                    bad.append((name, ln))
            start = 0
            for sm in list(I90_SENT.finditer(block)) + [None]:
                end = sm.start() + 1 if sm else len(block)
                sent = re.sub(r"^[\*_\s]+", "", block[start:end].strip())
                start = sm.end() if sm else 0
                if not (I90_PAT.match(sent) or I90_DISMISSIVE.match(sent)):
                    continue
                declared = any(m.group(1).strip() for m in I90_MARKER.finditer(block)) \
                    or bool(I90_RULE28A.search(block))
                if disp.search(block) or declared:
                    silent.append((name, ln, sent))
                else:
                    fires.append((name, ln, sent))
    return fires, silent, bad

# ---------------------------------------------------------------- probes
def probe():
    d = tempfile.mkdtemp()
    try:
        st = os.path.join(d, "steps")
        os.makedirs(st)
        gp = os.path.join(st, "_gate-procedures.md")
        good = os.path.join(st, "good.md")
        open(gp, "w").write("# T\n\n## Probe procedure (referenced by step files)\n\nbody\n")
        open(good, "w").write('See `_gate-procedures.md`, "Probe procedure" for this.\n')
        unres, uncited, n, _ = i89(gp, [good])
        if unres or uncited or n != 1:
            return ("I89 did not read its own agreeing probe as clean: %d unresolved, "
                    "%d uncited, %d citation(s) seen (expected 0/0/1). The extraction has "
                    "stopped matching the citation grammar, so a clean repo result is an "
                    "empty set produced by a reader that finds nothing."
                    % (len(unres), len(uncited), n))
        # The qualifier must be free to change, in ANY shape, without stranding a citation.
        # This is what "bind on the substring, not the heading line" buys, and it is asserted
        # rather than assumed: an equality-based resolve passes the clean probe above and
        # fails only here, which is exactly the churn this design exists to avoid.
        open(gp, "w").write("# T\n\n## Probe procedure — now referenced by the gate too\n\nbody\n")
        unres, uncited, n, _ = i89(gp, [good])
        if unres or uncited:
            return ("I89 stranded a citation when only the heading's QUALIFIER changed "
                    "(`(referenced by step files)` -> `— now referenced by the gate too`). "
                    "The resolve has become an equality against the whole heading line, so "
                    "every edit to a parenthetical now reds the push across thirteen citing "
                    "files. Bind on the substring the citations carry, as I11 does.")
        open(gp, "w").write("# T\n\n## Renamed procedure (referenced by step files)\n\nbody\n")
        unres, uncited, n, _ = i89(gp, [good])
        if not unres:
            return ("I89 did not fire on a RENAMED heading: the probe cites "
                    '"Probe procedure" and the file now heads "Renamed procedure", and the '
                    "join reported no stranded citation. That is the exact defect the "
                    "invariant exists for, and a check that cannot fire reads exactly like "
                    "one that passed.")
        if not uncited:
            return ("I89 did not report the renamed heading as UNCITED. The dormancy arm has "
                    "gone vacuous, so a procedure nobody invokes reads as a live one.")
        for name, body in (
            ("p_bare.md",     "Run the validator. Fix all gaps found.\n"),
            ("p_named.md",    "Run the validator. Fix all gaps found by dispatching a "
                              "`remediator`.\n"),
            ("p_declared.md", "Run the validator. Fix all gaps found. <!-- inline-ok: the "
                              "probe's declared reason -->\n"),
            ("p_baremark.md", "Run the validator. Fix all gaps found. <!-- inline-ok: -->\n"),
            ("p_file.md",     "Update `sprint-status.yaml` to match.\n"),
            # THE WRAP PROBE. The verb and its object on opposite sides of a line break is
            # the shape a hand `grep -c "Repair its findings"` returns 0 on while the folded
            # read returns 1 — measured on stories-test-strategy.md:548, a site that WAS
            # requalified and still went invisible to a line-based sweep. The extractor here
            # folds by construction (a block is one list item or paragraph run), so this
            # arm is not fixing anything; it is pinning the property, so a future narrowing
            # of i90_blocks cannot silently reintroduce a blind spot whose symptom is a
            # clean run.
            ("p_wrap.md",     "- Repair all\n  findings.\n"),
            # THE DISMISSIVE ARM, written in the exact shape Rule 7 carried: a quoted
            # question ending in `?"` followed by the bare imperative. Both halves are
            # load-bearing. If the sentence splitter stops treating `?"` as a boundary the
            # whole thing reads as one sentence beginning "Do" and the arm sees nothing;
            # if the verb class re-narrows to capitals the lowercase `fix` after `Just`
            # stops matching. Verified against the real pre-fix text of SKILL.md Rule 7.
            ("p_dismiss.md",  'Do not ask "should I fix this?" Just fix it.\n'),
            # ...and its NEGATIVE twin, which is why arm 2 requires the Just/Simply prefix
            # rather than simply admitting a pronoun object. This is `route.md`'s real
            # sentence, where "it" is a sprint_id being DERIVED. A bare pronoun-object
            # widening selects it; the measured false-positive set went 0 -> 1 on exactly
            # this line before the prefix was made mandatory.
            ("p_pronoun.md", "Resolve it here, before creating the snapshot.\n"),
        ):
            open(os.path.join(st, name), "w").write(body)
        os.remove(good)
        os.remove(gp)
        fires, silent, badm = i90_scan(
            [os.path.join(st, f) for f in sorted(os.listdir(st))], {"remediator"})
        ff = set(f for f, _, _ in fires)
        ss = set(f for f, _, _ in silent)
        if "p_bare.md" not in ff:
            return ("I90 did not fire on a bare fix-imperative probe ('Fix all gaps found.' "
                    "with no dispatch target and no declaration). The grammar has stopped "
                    "matching its own subject; the corpus scan would then report a clean "
                    "tree it never read.")
        if "p_wrap.md" not in ff:
            return ("I90 did not fire on a WRAPPED bare imperative ('Repair all' / newline / "
                    "'findings.'). The reader has stopped folding, so its unit is a LINE "
                    "while its declared unit is a block — and every fix-imperative that "
                    "happens to wrap between the verb and its object is now invisible while "
                    "the run prints the same clean line it prints for a requalified site. "
                    "Measured: a line-based sweep of stories-test-strategy.md:548 returned 0 "
                    "on a site that was correctly requalified.")
        if "p_dismiss.md" not in ff:
            return ("I90 did not fire on the DISMISSIVE bare imperative probe -- the exact "
                    "text SKILL.md Rule 7 carried until v0.357.0: 'Do not ask \"should I fix "
                    "this?\" Just fix it.' Two things can break it and both are silent. "
                    "Either the sentence splitter stopped treating a stop-inside-a-quote "
                    "(`?\"`) as a boundary, so the unit begins 'Do' and the imperative is "
                    "buried mid-sentence; or the verb class re-narrowed to capitals, and the "
                    "verb after `Just ` is lowercase. Rule 7 is RESIDENT above the 20,000-byte "
                    "re-attach cut while the rule that attributed it is not, so this is the "
                    "one sentence in the corpus a compacted lead is most likely to hold "
                    "alone.")
        if "p_pronoun.md" not in ff and "p_pronoun.md" in ss:
            return ("I90 treated the pronoun-object probe as a SILENT site rather than one "
                    "outside its population. It should match neither arm.")
        if "p_pronoun.md" in ff:
            return ("I90 fired on 'Resolve it here, before creating the snapshot.' -- the "
                    "pronoun-object arm has lost its `Just`/`Simply` prefix requirement. "
                    "That prefix is the discriminator: it is the instruction not to route "
                    "the act. Without it the arm selects any imperative with a pronoun "
                    "object, and `route.md`'s sprint_id derivation becomes a finding.")
        if "p_named.md" not in ss:
            return ("I90 fired on a probe that NAMES a dispatch target. Every requalified "
                    "site in the corpus becomes a finding, which is the shape an operator "
                    "turns the lint off over.")
        if "p_declared.md" not in ss:
            return ("I90 fired on a probe carrying a declared `<!-- inline-ok: ... -->` "
                    "carve-out with a reason. That declaration is the only way a legitimate "
                    "inline edit can be recorded where the rule's reader sees it.")
        if "p_baremark.md" not in ff:
            return ("I90 accepted an `<!-- inline-ok: -->` marker with an EMPTY reason. A "
                    "carve-out with no reason is a decision nobody can audit -- the same hole "
                    "a zero-byte `.dist-only` marker left until I74(d).")
        if not badm:
            return "I90's empty-reason marker arm did not report the bare marker probe."
        if "p_file.md" in ff or "p_file.md" in ss:
            return ("I90's population includes an imperative whose object is a FILE "
                    "('Update `sprint-status.yaml`'). That is one of the lead's own Rule "
                    "28(a) mutations, and the finding-object narrowing is what keeps it out; "
                    "without it the check reports 15 sites, 11 of them correct prose.")
        return None
    finally:
        shutil.rmtree(d, ignore_errors=True)

# ---------------------------------------------------------------- run
p = probe()
if p:
    out(p)
    sys.exit(0)

if not os.path.isfile(GP):
    out("I89/I90 could not read %s. An unreadable side reports the same silence as an "
        "agreeing one." % GP)
    sys.exit(0)

unres, uncited, ncite, nhead = i89(GP, i89_corpus())
if ncite < 10 or nhead < 5:
    out("I89 derived %d citation(s) against %d heading(s); counts this low mean one side "
        "stopped matching the tree, and an empty citation set resolves vacuously."
        % (ncite, nhead))
for p_, name, ctx in unres:
    out("I89 %s cites `_gate-procedures.md` procedure \"%s\", and no `## ` heading in that "
        "file carries that name.\nThe citation resolves to nothing: a step file told to READ "
        "AND FOLLOW a named procedure will not find it, and the pointer fails silently "
        "because nothing but this join reads both sides.\nEither restore the heading or "
        "update the citation. The heading may carry a `(referenced by ...)` qualifier -- "
        "that part is stripped before comparing, so only the base name has to agree.\n"
        "  at: ...%s..." % (os.path.relpath(p_, ROOT), name, ctx[-150:]))
for name in uncited:
    out("I89 `_gate-procedures.md` heads a procedure \"%s\" that NOTHING cites. That file's "
        "own contract is that its procedures are invoked BY NAME from step files; a "
        "procedure with no caller is dormant, and a dormant procedure reads exactly like a "
        "live one." % name)

roles = set(f[:-3] for f in os.listdir(ROLES_DIR) if f.endswith(".md")) \
    if os.path.isdir(ROLES_DIR) else set()
if not roles:
    out("I90 derived no role names from core/team-roles/. The dispatch-target test then "
        "matches nothing and every requalified site becomes a finding.")
else:
    # THE CORPUS IS ASSERTED, NOT ASSUMED. Deleting SKILL.md from i90_corpus() produced no
    # error at all until this arm existed: the invariant simply scanned a smaller tree and
    # printed the same clean line, which is this file's own recurring defect committed inside
    # the check written to close it. Membership is named here because it is a DECISION (rule
    # text is in scope) rather than a glob result.
    i90_files = i90_corpus(ROOT)
    i90_names = set(os.path.relpath(f, ROOT) for f in i90_files)
    for owed in ("core/skills/ai-dlc/SKILL.md",
                 "core/skills/ai-dlc/steps/gate-validation.md",
                 "core/skills/ai-dlc/steps/_gate-procedures.md"):
        if owed not in i90_names:
            out("I90's corpus does not contain %s. The scan below covers a SMALLER tree than "
                "this invariant claims and reports the same clean line it would report for a "
                "clean one. SKILL.md in particular is in scope by decision, not by glob: Rule "
                "7's `Just fix it` sat there, RESIDENT above the re-attach cut, with its actor "
                "established only by a rule below the cut." % owed)
    if len(i90_files) < 15:
        out("I90 derived only %d corpus file(s); the step directory has stopped enumerating "
            "and an empty corpus reports no bare imperatives without reading one."
            % len(i90_files))
    fires, silent, badm = i90_scan(i90_files, roles, ROOT)
    if not silent:
        out("I90's population contains no site that NAMES a dispatch target. The requalified "
            "sites (v0.25.0's sprint-review model and v0.357.0's) are the standing control "
            "that the silent arm can still be reached; with none of them present the grammar "
            "is matching something other than its subject.")
    for fn, ln in badm:
        out("I90 %s:%d carries an `<!-- inline-ok: -->` marker with "
            "an EMPTY reason. A carve-out with no reason is a decision nobody can audit. "
            "Write why the lead edits this one inline." % (fn, ln))
    for fn, ln, sent in fires:
        out("I90 %s:%d is a bare fix-imperative -- it names no "
            "dispatch target and declares no inline carve-out:\n    %s\nRule 28: the lead "
            "owns PASS/FAIL, the disposition and the escalation; the EDIT that follows is "
            "dispatched. A step file that says only \"fix it\" leaves the subject "
            "unattributed, and the most context-saturated agent in the pipeline is the one "
            "that reads it.\nResolve it one of three ways:\n  * name the seat -- a "
            "`remediator` for planning artifacts (`_gate-procedures.md`, \"Adversarial repair "
            "dispatch\"), dev teammates for code. steps/sprint-review.md and "
            "steps/stories-test-strategy.md carry the requalified wording.\n  * cite `Rule "
            "28(a)` if this really is one of the lead's own sanctioned mutations.\n  * "
            "declare it: `<!-- inline-ok: <why the lead edits this one inline> -->`. The "
            "reason is required and is checked for being non-empty." % (fn, ln, sent))
I89EOF
I89_OUT="$(python3 "$I89_PY" "$REPO_ROOT" 2>&1)" || err "I89/I90 could not run: $I89_OUT"
rm -f "$I89_PY"
while IFS="$(printf '\t')" read -r i89_tag i89_msg; do
  [ "$i89_tag" = "ERR" ] || continue
  err "$(printf '%b' "$i89_msg")"
done <<EOF
$I89_OUT
EOF

# --- I92: the transcript-corpus predicate is one rule in three copies, byte-identical ---
# WHAT IT BINDS. `steer_dir_has_transcript()` answers a single question -- does this directory
# hold a readable `*.jsonl` -- and at all three sites that one answer decides the same thing:
# whether the steer is issued as `--dir <corpus>` or falls back. Two of the three are gate
# validators handed the directory as `--transcript-dir`; the third is the remediation guard,
# which derives it from the session transcript and gates a dispatch on it. All three previously
# tested only that the path EXISTED, which classified an EMPTY corpus as operator forgery and
# denied every dispatch. The repair is one predicate written into three files, and three copies
# are three chances for the guard to deny what the validators accept -- a disagreement that
# surfaces as a refused dispatch with two green validators beside it, which reads as a correct
# denial.
#
# COPIES RATHER THAN A SHARED SOURCE, for I25's reason and I33's. install.sh splits what shares
# a parent here: `core/scripts/<x>` lands at `scripts/ai-dlc/<x>` and `core/hooks/` lands
# elsewhere, and I33 fails the build on locating one core file by walking up from another, so in
# an installed tree there is no path all three could source. A hook that sources a helper also
# fails OPEN when a partial install omits it, which is the failure I25 records at length. The
# duplication is only safe because this assertion exists.
#
# NOT A VOCABULARY, so no `# vocabulary:` marker. The subject is an executable predicate's BODY,
# not an enumerated membership a second reader could restate: there is no owner-and-readers
# split to render and nothing for docs/vocabulary-index.md to list. What is bound here is that
# three byte strings are one byte string.
#
# THE FOURTH-COPY HALF, AND ITS MEASURED FALSE-POSITIVE SET. Byte-equality across three
# hand-written paths cannot see a fourth copy appearing in a fourth file, so the site list is
# DERIVED as well as declared: every file under core/ and scripts/ that names the helper must be
# one of the three. A declared site that stops defining it fails the first half; an undeclared
# file that starts naming it fails this one.
#
# Measured over the real tree, every hit outside the three declared sites is a MUTATION
# BATTERY under core/fixtures/ that seeds a REVERT of this very repair, and therefore has to
# quote the line it reverts. That is the entire false-positive set. It is excluded by DIRECTORY
# and not by name, and the reason is measured rather than tidy: the battery count went from one
# to three inside the single session that wrote this arm, as the fixtures for the same repair
# landed. A per-file exemption list would have been stale twice before it was committed.
#
# The exclusion is also the right shape on its own terms. Nothing under core/fixtures/ is ever
# executed as the guard or as a validator, so it cannot be the fourth copy that drifts, and a
# fixture written to prove THIS arm would have to name its subject for the same reason. This
# file is excluded one level up for that reason exactly -- an arm names the helper it binds,
# and it is read back below as this half's positive control.
i92_needle='steer_dir_has_transcript'
i92_declared='core/scripts/validate-adversarial-convergence.sh
core/scripts/validate-escalation-resolution.sh
core/hooks/ai-dlc-gate-remediation-guard.sh'

# The same extractor I25 and I40 use, for the same reason: a function body is a line range
# between its opening line at column 0 and the matching closing brace at column 0.
i92_body() { awk "/^$2\(\) \{/,/^\}/" "$1" 2>/dev/null; }
# The site scan, as a function taking its roots, so the probe below drives THE SHIPPING CODE
# PATH rather than a second implementation of it.
i92_sites() { i92_n="$1"; shift; grep -rlF -- "$i92_n" "$@" 2>/dev/null; }

# THE PROBE, RUN BEFORE THE CORPUS. Both halves of this arm are absence-shaped: a body that no
# longer extracts compares empty-to-empty and reports agreement, and a scan that no longer
# matches reports no fourth copy. Both silences read exactly like a conforming tree. So the two
# functions above are first driven over a tree with one right answer, and the corpus is not
# scanned at all unless they produce it. The tree fires in BOTH directions -- a seeded offender
# must be reported and a seeded near-miss must not.
i92_probe_dir="$(mktemp -d "${TMPDIR:-/tmp}/i92-XXXXXX")"
mkdir -p "$i92_probe_dir/t"
#  a  the reference body.
printf 'lead=1\n%s() { # note\n  f "$1"\n}\ntail=2\n' "$i92_needle" > "$i92_probe_dir/t/a.sh"
#  b  NEAR-MISS for the equality half: identical body, different surrounding text. Must compare
#     EQUAL, or this arm reports drift on every file that is merely not a copy of its neighbour.
printf 'other=9\n%s() { # note\n  f "$1"\n}\nmore=0\n' "$i92_needle" > "$i92_probe_dir/t/b.sh"
#  c  DRIFT: one character inside the body differs. Must compare UNEQUAL.
printf '%s() { # note\n  f "$2"\n}\n' "$i92_needle" > "$i92_probe_dir/t/c.sh"
#  d  no definition at all. Extraction must be EMPTY -- an extractor that invents a body here
#     is one that would compare two inventions and call them equal.
printf 'unrelated_helper() {\n  :\n}\n' > "$i92_probe_dir/t/d.sh"
#  e  a FOURTH SITE that MENTIONS the helper without defining it. The scan must SEE it: a copy
#     arrives as a mention before it arrives as a definition.
printf '# dispatches through %s\n' "$i92_needle" > "$i92_probe_dir/t/e.sh"
#  f  NEAR-MISS for the scan half: a differently-named helper in the same family. Must stay
#     quiet, or the scan flags files for resembling the subject rather than carrying it.
printf 'steer_dir_has_nothing() { :; }\n' > "$i92_probe_dir/t/f.sh"
i92_pa="$(i92_body "$i92_probe_dir/t/a.sh" "$i92_needle")"
i92_pb="$(i92_body "$i92_probe_dir/t/b.sh" "$i92_needle")"
i92_pc="$(i92_body "$i92_probe_dir/t/c.sh" "$i92_needle")"
i92_pd="$(i92_body "$i92_probe_dir/t/d.sh" "$i92_needle")"
i92_pm="$(i92_sites "$i92_needle" "$i92_probe_dir/t" | LC_ALL=C sort)"
i92_pm_want="$i92_probe_dir/t/a.sh
$i92_probe_dir/t/b.sh
$i92_probe_dir/t/c.sh
$i92_probe_dir/t/e.sh"
i92_score=0
[ -n "$i92_pa" ]              || i92_score=$((i92_score + 1))
[ "$i92_pa" = "$i92_pb" ]     || i92_score=$((i92_score + 10))
[ "$i92_pa" != "$i92_pc" ]    || i92_score=$((i92_score + 100))
[ -z "$i92_pd" ]              || i92_score=$((i92_score + 1000))
[ "$i92_pm" = "$i92_pm_want" ] || i92_score=$((i92_score + 10000))
rm -rf "$i92_probe_dir"
if [ "$i92_score" -ne 0 ]; then
  err "I92's probe scored $i92_score where 0 is the only correct total, so the corpus below was not scanned. +1 the extractor found no body where one is defined; +10 it called two IDENTICAL bodies in differently-surrounded files different, which would report drift on a conforming tree; +100 it called a body differing by one character the SAME, which is the state this arm exists to report; +1000 it returned a body from a file defining no such function, so the equality half would be comparing two inventions; +10000 the site scan did not name exactly the four probe files that carry the string -- it either missed the mention-only fourth site or flagged the similarly-named near-miss. Any non-zero total means both halves of I92 would report a clean tree for the reason a broken reader does."
else
  # HALF ONE: the three declared copies are one byte string. Read against the FIRST readable
  # copy rather than pairwise, so N files cost N extractions.
  i92_ref=''; i92_ref_of=''; i92_vacuous=''; i92_drift=''
  while IFS= read -r i92_rel; do
    [ -n "$i92_rel" ] || continue
    i92_abs="$REPO_ROOT/$i92_rel"
    i92_got="$(i92_body "$i92_abs" "$i92_needle")"
    if [ -z "$i92_got" ]; then
      i92_vacuous="$i92_vacuous $i92_rel"
    elif [ -z "$i92_ref" ]; then
      i92_ref="$i92_got"; i92_ref_of="$i92_rel"
    elif [ "$i92_got" != "$i92_ref" ]; then
      i92_drift="$i92_drift $i92_rel"
    fi
  done <<EOF
$i92_declared
EOF
  [ -z "$i92_vacuous" ] || err "I92 cannot find a ${i92_needle}() definition in:$i92_vacuous. The check binding the three readings of what makes a transcript directory a usable corpus just went vacuous -- it must locate all three or fail loudly, never pass by finding nothing. If the helper was renamed or lifted, rename it here in the same change."
  [ -z "$i92_drift" ] || err "I92: the transcript-corpus predicate has forked. $i92_ref_of and$i92_drift define ${i92_needle}() differently. Two of the three sites are gate validators deciding whether a --dir corpus is real; the third is the remediation guard deciding whether a dispatch may proceed. A copy that differs means the guard denies a dispatch over a directory the validators just accepted, and the operator sees a refusal with two green validators beside it. Make ${i92_needle}() byte-identical across all three."

  # HALF TWO: no fourth site. The hit list is DERIVED; the three declared paths and the two
  # excluded directories are the only things written down.
  #
  # THE POSITIVE CONTROL IS THIS FILE, AND IT REPLACED A GUARD THAT COULD NOT FIRE. The first
  # cut asserted the hit list was non-EMPTY, on the reasoning that an empty one satisfies the
  # fourth-copy half by having nothing left to check. Measured against a tree with the helper
  # renamed out of all four files that carry it: that guard stayed silent, because this arm is
  # itself inside the scanned roots and names the needle at i92_needle= and throughout the prose
  # above. An empty hit list is unconstructible while the arm exists, so the guard was a
  # condition that changes no outcome -- and one that reads exactly like a check that passed.
  #
  # What IS constructible is a scan that stops reading one of its roots: narrow it to core/, or
  # let REPO_ROOT resolve somewhere else -- this file run from a copy under /tmp answers with a
  # different root and finishes in milliseconds -- and the fourth-copy half goes quiet over a
  # corpus it never opened. So the control is a token already known to be present, read in the
  # same invocation: this file must appear in its own scan.
  i92_hits="$(i92_sites "$i92_needle" "$REPO_ROOT/core" "$REPO_ROOT/scripts" | LC_ALL=C sort)"
  i92_self="scripts/validate-enforcement-map.sh"
  if ! in_lines "$REPO_ROOT/$i92_self" "$i92_hits"; then
    err "I92's site scan did not find $i92_self, which carries ${i92_needle} in this arm's own i92_needle= assignment and in the paragraphs above it. That is the control failing, not a finding about the tree: the scan is not reading the roots it was handed, so its report of no fourth copy would be a zero taken over a corpus it never opened. Fix the roots passed to i92_sites, or the resolution of REPO_ROOT, before reading anything below."
  else
    i92_extra=''
    while IFS= read -r i92_hit; do
      [ -n "$i92_hit" ] || continue
      i92_r="${i92_hit#"$REPO_ROOT"/}"
      case "$i92_r" in
        core/fixtures/*) continue ;;
        scripts/validate-enforcement-map.sh) continue ;;
      esac
      in_lines "$i92_r" "$i92_declared" || i92_extra="$i92_extra $i92_r"
    done <<EOF
$i92_hits
EOF
    [ -z "$i92_extra" ] || err "I92: file(s) outside the three bound sites name ${i92_needle}:$i92_extra. A fourth copy is an unbound copy -- the equality half above compares only the three it is given, so a fourth drifts in silence and decides the same corpus question its own way. Either resolve it from one of the three bound sites, or add it to i92_declared here in the same change so it is held byte-identical with them. A file that merely CITES the name in prose still counts: that is how the last unbound copy in this repository arrived."
  fi
fi

# --- I93: an "examined nothing" verdict is ONE token across every emitter of it ----
# vocabulary: empty-subject verdict token
# vocabulary-invariant: I93
# vocabulary-owner: core/skills/ai-dlc/enforcement-map.yaml
# vocabulary-extract: empty-subject-verdict
# vocabulary-readers: core/scripts/validate-stub-audit.sh, core/scripts/validate-locked-anchor.sh, core/scripts/validate-ci-gates.sh, core/skills/ai-dlc/steps/gate-validation.md, core/skills/ai-dlc/steps/retro.md
#
# WHY. Three core validators printed "this run examined nothing" in three spellings at three
# exit codes -- `AUDITED NOTHING` at 4, `PASS -- NOTHING VERIFIED` at 0, `VACUOUS:` at 78 --
# and no vocabulary joined them. Each was argued at length in its own header and none was
# wrong on its own terms; the DISAGREEMENT was the defect, because an operator reading a gate
# log had to know three grammars to recognise one state and a fourth emitter would have
# invented a fourth spelling with nothing to stop it.
#
# THE EXIT CODES ARE NOT BOUND HERE AND MUST NOT BE. 4, 0 and 78 are per-validator caller
# contracts, each argued in its own header (4 = not a pass, the caller decides; 0 = a legal
# state that must still say what it did not do; 78 = a check that COULD NOT run must not share
# a code with one that ran and passed). Unifying them is consumer-visible and is not this
# arm's business. One token says "nothing was examined"; the code says what that is worth.
#
# THE OWNER IS THE MAP, NOT ONE OF THE THREE. They are co-equal peers, so promoting one picks
# a winner on no criterion; the map is the only file in the tree that declares all three under
# `enforcer:` (derived, not asserted: the set of files naming all three emitters is this file,
# the map, the CHANGELOG, docs/ and the generated readset table).
#
# THE FALSE-POSITIVE NARROWING IS THE EMISSION SITE, NOT A DELIMITER, and that is a departure
# from the sibling readers of I39 on purpose. Those narrow with backticks because SKILL.md
# writes every status in backticks and a bare `grep -F` on one member matches a longer member
# containing it. Neither holds here: this corpus is shell and Python, where a backtick RUNS
# the quoted word (I85 fails the push on one), and the set has a single member with no longer
# sibling to be confused with. What a whole-file `grep -qF` gets wrong in THIS corpus is a
# COMMENT -- the same defect one grain over -- so esv_sites drops comment-only lines.
#
# HOW THE FALSE-POSITIVE SET REACHED ZERO, WHICH IS PART OF THE ARM. Over the REAL tree the
# narrowed and unnarrowed forms both report zero, because this change rewrote each emitter's
# exit-code TABLE along with its emission; the real corpus does not discriminate the two and
# therefore cannot be the evidence for the narrowing. What discriminates them is the shape
# arm C has to TOLERATE: a validator whose header RECORDS the retirement -- "78 = EXAMINED
# NOTHING; was VACUOUS: until the vocabulary landed, so a consumer grepping old gate logs
# finds those runs under the new token". That is the right thing for a header to say. Seeded
# and measured side by side in one invocation: narrowed 0 findings, unnarrowed 3, with the
# declared token found on the seed's one emitting line as the control. The narrowing buys
# exactly that, and the probe below asserts both directions of it before the corpus is read.

# `esv_sites <token> <file>...` -> "file:line" for each NON-COMMENT line carrying the token.
# ONE awk over the whole file list rather than a loop: the fixture-suite pole invokes this
# script and a per-file fork is a change to the suite's wall clock. The token is carried by
# `-v`, which strips one level of escaping and transports no newline -- safe here only
# because the declared token holds neither.
esv_sites() {
  esv_t="$1"; shift
  awk -v t="$esv_t" '
    { if (index($0, t) == 0) next
      s = $0; sub(/^[[:space:]]+/, "", s)
      if (substr(s, 1, 1) == "#") next
      print FILENAME ":" FNR }
  ' "$@"
}

# `esv_rows <yaml>` -> "<key><TAB><value>" rows for the empty_subject_verdict: block ALONE.
# Scoped to the block and exited at the next top-level key, so a `token:` under any other
# key cannot leak in -- the probe below seeds one on each side to prove it.
esv_rows() {
  awk '
    /^empty_subject_verdict:/                     { on = 1; next }
    on && /^[^[:space:]#]/                        { exit }
    !on                                           { next }
    /^  [a-z_]+:[[:space:]]*$/                    { k = $1; sub(/:$/, "", k); next }
    /^  [a-z_]+:[[:space:]]*[^[:space:]]/         { k = $1; sub(/:$/, "", k)
                                                    v = $0
                                                    sub(/^  [a-z_]+:[[:space:]]*/, "", v)
                                                    print k "\t" v; k = ""; next }
    /^    - /                                     { if (k != "") { v = $0
                                                      sub(/^    - /, "", v)
                                                      gsub(/^"|"$/, "", v)
                                                      print k "\t" v } }
  ' "$1"
}
esv_val() { awk -F'\t' -v k="$1" '$1 == k { print $2 }' <<EOF
$2
EOF
}

# --- the probe, over a seeded tree, BEFORE the corpus ------------------------------------
ESV_TMP="$(mktemp -d "${TMPDIR:-/tmp}/i93-XXXXXX")"
printf '%s\n' \
  'decoy_before:' \
  '  token: DECOY93A' \
  'empty_subject_verdict:' \
  '  token: PROBE93 TOKEN' \
  '  emitters:' \
  '    - a.sh' \
  '    - b.sh' \
  '  retired:' \
  '    - "OLD93:"' \
  'checks:' \
  '  token: DECOY93B' > "$ESV_TMP/map.yaml"
printf '%s\n' 'echo "PROBE93 TOKEN reached the operator"' > "$ESV_TMP/emit.sh"
printf '%s\n' '#   4 = PROBE93 TOKEN, in an exit-code table' \
              '    # PROBE93 TOKEN, indented comment' > "$ESV_TMP/comment.sh"
printf '%s\n' 'echo "nothing to see"' > "$ESV_TMP/silent.sh"

esv_p_rows="$(esv_rows "$ESV_TMP/map.yaml")"
esv_score=0
[ "$(esv_val token "$esv_p_rows")" = "PROBE93 TOKEN" ] || esv_score=$((esv_score + 1))
[ "$(esv_val emitters "$esv_p_rows" | grep -c .)" = "2" ] || esv_score=$((esv_score + 10))
[ "$(esv_val retired "$esv_p_rows")" = "OLD93:" ] || esv_score=$((esv_score + 100))
[ -n "$(esv_sites 'PROBE93 TOKEN' "$ESV_TMP/emit.sh")" ] || esv_score=$((esv_score + 1000))
[ -z "$(esv_sites 'PROBE93 TOKEN' "$ESV_TMP/comment.sh")" ] || esv_score=$((esv_score + 10000))
[ -z "$(esv_sites 'PROBE93 TOKEN' "$ESV_TMP/silent.sh")" ] || esv_score=$((esv_score + 100000))
rm -rf "$ESV_TMP"

if [ "$esv_score" -ne 0 ]; then
  err "I93's probe scored $esv_score where 0 is the only correct total, so nothing below was read by a working reader. +1 the block reader lost the token or picked up a decoy \`token:\` outside the block; +10 it read the wrong number of emitters, so the list grammar moved; +100 it did not strip the quotes off a retired spelling, so arm C would search for a literal with quotes in it and find nothing forever; +1000 esv_sites found no emission in a file whose only line EMITS the token, which makes arm A pass by finding nothing; +10000 it counted a COMMENT as an emission, which is the whole of this arm's false-positive narrowing and makes arm C fire on every exit-code table; +100000 it reported a site in a file carrying no token at all."
else
  esv_rows_all="$(esv_rows "$MAP")"
  esv_tok="$(esv_val token "$esv_rows_all")"
  esv_emitters="$(esv_val emitters "$esv_rows_all")"
  esv_readers="$(esv_val readers "$esv_rows_all")"
  esv_retired="$(esv_val retired "$esv_rows_all")"
  if [ -z "$esv_tok" ] || [ -z "$esv_emitters" ] || [ -z "$esv_readers" ] || [ -z "$esv_retired" ]; then
    err "I93: the \`empty_subject_verdict:\` block in $MAP did not yield all four of token/emitters/readers/retired (token='$esv_tok'; $(printf '%s' "$esv_emitters" | grep -c .) emitter(s), $(printf '%s' "$esv_readers" | grep -c .) reader(s), $(printf '%s' "$esv_retired" | grep -c .) retired spelling(s)). Either the block was removed or its shape changed. This fails closed: with an empty declaration every loop below iterates zero times and the arm reports a unified tree it never looked at."
  else
    # ARM A -- every declared emitter EMITS the token, and emits no retired spelling.
    while IFS= read -r esv_f; do
      [ -n "$esv_f" ] || continue
      if [ ! -f "$REPO_ROOT/$esv_f" ]; then
        err "I93: $MAP declares '$esv_f' as an emitter of the empty-subject verdict and no such file exists. A scan over a missing file reads exactly like an emitter that conforms."
        continue
      fi
      [ -n "$(esv_sites "$esv_tok" "$REPO_ROOT/$esv_f")" ] || \
        err "I93: $esv_f is declared an emitter of the empty-subject verdict and no line of it OUTSIDE A COMMENT prints '$esv_tok'. Either it stopped emitting the verdict, or it emits a spelling of its own -- which is the three-grammar state this vocabulary replaced. The token is declared at $MAP \`empty_subject_verdict: token:\`; change it there and here in one commit, never in one emitter."
      while IFS= read -r esv_r; do
        [ -n "$esv_r" ] || continue
        esv_hit="$(esv_sites "$esv_r" "$REPO_ROOT/$esv_f")"
        [ -z "$esv_hit" ] || \
          err "I93: $esv_f emits the RETIRED spelling '$esv_r' at $esv_hit. It was replaced by '$esv_tok' precisely so that one state has one grammar; an emitter carrying both prints two names for one thing and an operator grepping the gate log for either finds half the runs."
      done <<EOF
$esv_retired
EOF
    done <<EOF
$esv_emitters
EOF

    # ARM B -- every declared reader NAMES the token and no retired spelling. These are
    # step files an agent reads at a gate: a step that restates a spelling the script no
    # longer prints tells the agent to look for a line that will never appear. Read with
    # `$(<file)` and matched with in_body, so the whole arm costs no fork -- and matched
    # WHOLE-FILE deliberately, because prose has no emission site to key on and `#` is a
    # markdown heading rather than a comment.
    while IFS= read -r esv_f; do
      [ -n "$esv_f" ] || continue
      if [ ! -f "$REPO_ROOT/$esv_f" ]; then
        err "I93: $MAP declares '$esv_f' as a reader of the empty-subject verdict and no such file exists."
        continue
      fi
      esv_body="$(<"$REPO_ROOT/$esv_f")"
      in_body "$esv_tok" "$esv_body" || \
        err "I93: $esv_f is declared a reader of the empty-subject verdict and never names '$esv_tok'. It is a step file an agent reads AT the gate; if it does not carry the token the agent is told to read a report line by a name nothing prints."
      while IFS= read -r esv_r; do
        [ -n "$esv_r" ] || continue
        ! in_body "$esv_r" "$esv_body" || \
          err "I93: $esv_f still restates the RETIRED spelling '$esv_r'. The emitters print '$esv_tok' now, so this instructs an agent to look for a line that no longer exists."
      done <<EOF
$esv_retired
EOF
    done <<EOF
$esv_readers
EOF

    # ARM C -- no OTHER shipped validator revives a retired spelling. Arm A holds the three
    # declared emitters; this holds the rest of core/scripts/, which is where a fourth
    # emitter would appear. Scoped to emissions for the reason in the header: every one of
    # the three retired spellings still appears, correctly, in the exit-code COMMENT tables
    # and headers that record what each code used to be called.
    esv_files=()
    for esv_f in "$REPO_ROOT"/core/scripts/*.sh; do
      [ -f "$esv_f" ] && esv_files[${#esv_files[@]}]="$esv_f"
    done
    if [ "${#esv_files[@]}" -eq 0 ]; then
      err "I93: the glob core/scripts/*.sh matched no file, so arm C's sweep for revived spellings would report a clean tree having opened nothing. An unmatched glob and a conforming corpus print the same zero."
    elif [ -z "$(esv_sites "$esv_tok" "${esv_files[@]}")" ]; then
      # THE POSITIVE CONTROL, IN THE SAME INVOCATION AS THE ZEROS BELOW. Arm A already
      # requires each declared emitter to print the token and all three live under
      # core/scripts/, so the identical scan over this file list MUST find them. If it does
      # not, the sweep is not reading the corpus it was handed and every "no revived
      # spelling" below is a zero taken over nothing.
      err "I93: arm C's control failed -- scanning $(printf '%s' "${#esv_files[@]}") core/scripts/*.sh file(s) for the DECLARED token '$esv_tok' found no emission, while arm A above requires three of those files to emit it. The file list or esv_sites is not reading the tree, so the retired-spelling sweep below cannot be believed."
    else
    while IFS= read -r esv_r; do
      [ -n "$esv_r" ] || continue
      esv_hits="$(esv_sites "$esv_r" "${esv_files[@]}" | sed "s|^$REPO_ROOT/||" | tr '\n' ' ')"
      [ -z "$esv_hits" ] || \
        err "I93: the retired empty-subject spelling '$esv_r' is emitted again under core/scripts/: $esv_hits. This vocabulary exists because three validators each invented their own name for one state. The declared token is '$esv_tok' ($MAP \`empty_subject_verdict:\`); if a new validator needs this verdict it emits that, and if the token itself must change it changes at the owner."
    done <<EOF
$esv_retired
EOF
    fi
  fi
fi

# --- Verdict ------------------------------------------------------------------
if [ "$fail" -eq 0 ]; then
  n="$(printf '%s\n' "$map_ids" | grep -c .)"
  # THE ENUMERATION IS DERIVED, and this line is why the renderer exists. It used to carry a
  # hand-typed list of the invariants considered live, 12,243 characters of it. Measured when
  # that list was replaced: it named 71 IDs while 93 arms in this file could fire, so 22
  # invariants were enforcing the tree while absent from the only enumeration that claimed to
  # cover them -- including I1 and I2, the catalog joins everything here is built on. Nothing
  # read the sentence but a human, and a human cannot audit a 12,000-character sentence.
  #
  # The list now lives in docs/invariant-index.md, rendered by scripts/render-invariant-index.sh
  # from THIS file's own arm headers and byte-compared at pre-push. It is not restated here:
  # a second copy is a second thing to go stale, which is what this replaced.
  echo "OK: enforcement-map.yaml in sync with gate-validation.md ($n catalog checks), all bindings live, core_manifest copies match. The live invariant enumeration is docs/invariant-index.md, rendered from this file and gated at pre-push."
  exit 0
fi
exit 1
