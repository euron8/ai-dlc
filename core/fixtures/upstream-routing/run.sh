#!/usr/bin/env bash
# upstream-routing — assert `audit-upstream-routing.sh` can tell a MISROUTED carry-over entry
# from a correctly-routed one, and that every way it can read nothing is exit 2 rather than a
# clean-looking zero.
#
# Usage: run.sh [audit-upstream-routing.sh]
# Exit:  0 = every assertion holds, 1 = the reporter regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH, and every one of its failure modes is SILENT. The subject is
# a REPORTER: it exits 0 whether it finds nine misroutes or none, so no exit code moves when it
# breaks. Widen the predicate and correct consumer work is convicted; narrow it and the entry it
# exists for vanishes; lose one of the two heading shapes and the corpus shrinks while the report
# looks cleaner; lose the glob set entirely and EVERY path classifies as consumer-owned, which
# renders as a confident `MISROUTED (0)` over a predicate that is dead. Every assertion here is
# therefore on the OUTPUT.
#
# THE PREDICATE IS DECLARED, NEVER INFERRED, AND THE AGREEMENT ARM IS WHAT KEEPS IT THAT WAY.
# `core/fixtures/consumer-machinery-inventory/run.sh` records that eight predicates asking core to
# INFER which consumer executables are ai-dlc were measured and ALL EIGHT REFUTED. The subject
# does not re-attempt it: it asks `core-paths.sh --list` for the shipping glob set and matches
# in-process, because per-path `--is-core` costs a process spawn each and the suite is pole-bound.
# That optimisation is only safe while the two routes agree, and nothing about the code makes
# them agree — one is Python `fnmatch`, the other is a shell `case`. Assertions 2-4 run both over
# one seeded path set and require zero disagreements, so the two cannot drift apart silently.
#
# THE SUBJECT MAY LEGITIMATELY BE ABSENT ON A CONSUMER — a core fixture ships ahead of the code it
# guards. That is exit 2 FIXTURE BROKEN, never a green run: "I could not find the subject" and
# "the subject behaves" are different claims and must not share an exit code.
set -uo pipefail

# HERMETIC — a consumer that pins AI_DLC_* in settings.json exports it into every session, and
# `git push` inherits it. AI_DLC_PROJECT_ROOT in particular would relocate the subject's root out
# from under every arm below. Scrub by pattern so a NEW tunable cannot reintroduce the coupling.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"

# Resolve the project root by walking UP for a marker, never by counting `..` hops — a fixture
# that counts hops answers differently from the root, from a subdirectory and from a sandbox that
# copied it, and the sandbox answer is the silent one. Both install layouts are markers, because
# this fixture runs in the distribution (`core/skills/ai-dlc/`) and on a consumer
# (`.claude/skills/ai-dlc/`).
resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -d "$d/core/skills/ai-dlc" ] || [ -d "$d/.claude/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
ROOT="$(resolve_root "$HERE" || true)"
[ -n "$ROOT" ] || { echo "FIXTURE ERROR: no ai-dlc skill dir above $HERE in either layout" >&2; exit 2; }

pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
SUBJ="$(pick "${1:-}" \
  "$ROOT/core/scripts/audit-upstream-routing.sh" \
  "$ROOT/scripts/ai-dlc/audit-upstream-routing.sh")"
[ -n "$SUBJ" ] || { echo "FIXTURE ERROR: cannot locate audit-upstream-routing.sh in either layout" >&2; exit 2; }
case "$SUBJ" in /*) : ;; *) SUBJ="$(cd "$(dirname "$SUBJ")" && pwd)/$(basename "$SUBJ")" ;; esac

# NOT `pick`ed independently. The subject reads `core-paths.sh` from ITS OWN directory, so a
# sibling resolved from anywhere else would be a different file from the one under test — and
# assertion 15 exists precisely because a missing sibling is a refusal, not a finding.
CPATHS="$(dirname "$SUBJ")/core-paths.sh"
[ -f "$CPATHS" ] || { echo "FIXTURE ERROR: no core-paths.sh beside $SUBJ" >&2; exit 2; }

# The manifest, resolved HERE and passed EXPLICITLY to every direct `--is-core` probe below.
# Bare, that mode falls back to two RELATIVE candidates, so it would answer about whichever
# sandbox the probe `cd`s into — and every sandbox this file builds is deliberately manifest-less,
# so the probes would classify against nothing and refuse. Resolved up front so a fixture missing
# its own input reports BROKEN before any assertion prints, not halfway down the run.
MANIFEST_F="$(pick "$ROOT/.claude/skills/ai-dlc/core-manifest.md" "$ROOT/core/skills/ai-dlc/core-manifest.md")"
[ -n "$MANIFEST_F" ] || { echo "FIXTURE ERROR: no core-manifest.md under $ROOT in either layout" >&2; exit 2; }

# The core guard and the site data it needs, resolved HERE in whichever layout this tree is, for
# the same reason the manifest is. The guard is the THIRD party to the agreement arm below and is
# driven through its real PreToolUse contract rather than reimplemented.
GUARD_F="$(pick "$ROOT/.claude/hooks/ai-dlc-core-guard.sh" "$ROOT/core/hooks/ai-dlc-core-guard.sh")"
[ -n "$GUARD_F" ] || { echo "FIXTURE ERROR: no ai-dlc-core-guard.sh under $ROOT in either layout" >&2; exit 2; }
# NOT optional, and its absence is SILENT: `[ -r "$SITES" ] || exit 0` sits ABOVE the guard's deny,
# so a sandbox without this file allows every path and the agreement arm reads green having asked
# the guard nothing.
SITES_F="$(pick "$ROOT/.claude/skills/ai-dlc-update/reconcile/setup-sites.md" \
                "$ROOT/core/skills/ai-dlc-update/reconcile/setup-sites.md")"
[ -n "$SITES_F" ] || { echo "FIXTURE ERROR: no reconcile/setup-sites.md under $ROOT in either layout" >&2; exit 2; }

for _hc in "$SUBJ" "$GUARD_F" "$MANIFEST_F" "$SITES_F"; do
  echo "HERMETIC-CONSUMED $(cd "$(dirname "$_hc")" && pwd -P)/$(basename "$_hc")"
done

# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECTS. A consumer can receive this file one pull before the wrapped subjects, and
# sourcing a pre-wrap one would run its body in this shell (the hook would read stdin, the router would parse argv).
# Each subject's shape is checked first, on its two halves: neither the `<p>_main() {` line nor the column-0 source
# guard is a subject that predates the wrap, which prints SKIP and exits 0 -- never an ok. Exactly one half is a
# respelled subject this fixture can no longer drive, which FAILS. A subject that cannot be read is a fixture error.
wrap_state() { # <file> <prefix> -> WS_STATE=none|both|def-only|guard-only
  local d=0 g=0 x
  grep -q "^$2_main() {\$" "$1"; x=$?
  [ "$x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $1 (grep exit $x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$x" -ne 0 ] || d=1
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$1"; x=$?
  [ "$x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $1 (grep exit $x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$x" -ne 0 ] || g=1
  case "$d$g" in 00) WS_STATE=none ;; 11) WS_STATE=both ;; 10) WS_STATE=def-only ;; *) WS_STATE=guard-only ;; esac
}
wrap_state "$SUBJ" upr; ws_subj="$WS_STATE"
wrap_state "$GUARD_F" cwg; ws_guard="$WS_STATE"
for _w in "$ws_subj $SUBJ upr" "$ws_guard $GUARD_F cwg"; do
  set -- $_w
  case "$1" in
    def-only)   echo "   FAIL  $2 defines \`$3_main() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run $3_main in this shell" >&2; echo "upstream-routing: FAIL (1)" >&2; exit 1 ;;
    guard-only) echo "   FAIL  $2 carries the column-0 source guard but no \`$3_main() {\` line -- a respelled subject this fixture cannot drive" >&2; echo "upstream-routing: FAIL (1)" >&2; exit 1 ;;
  esac
done
if [ "$ws_subj" = none ] || [ "$ws_guard" = none ]; then echo "SKIP: subject predates the in-process wrap"; exit 0; fi

command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 absent" >&2; exit 2; }
# `jq` is the GUARD's own dependency, not this fixture's convenience. Without it the guard reads an
# empty tool_name, falls through its `case` to `exit 0`, and ALLOWS every path — a fail-open that
# reads exactly like three-way agreement.
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq absent — the core guard cannot be driven, and a guard that cannot run allows everything" >&2; exit 2; }

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

EXPECTED_ASSERTIONS=37
# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }
# A literal-tail path, never `. "$VAR"`: in a fixture opted in by an inproc: row, P1 reads an opaque source as a drive.
[ -f "$HERE/../lib/mutant.sh" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: sourcing lib/mutant.sh failed" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
# IN PROCESS (BL-878). The router and the guard are each SOURCED once into this shell (their guards return after
# defining upr_main and cwg_main) and every drive calls the function in a subshell, so a subject's `exit`, `set -uo
# pipefail`, cd and AI_DLC_PROJECT_ROOT stay there. Each call is one fx_inproc pass (the inproc: rows), paired on its line.
. "$SUBJ" || { echo "FIXTURE BROKEN: sourcing $SUBJ failed" >&2; exit 2; }
declare -F upr_main > /dev/null || { echo "FIXTURE BROKEN: sourcing $SUBJ defined no upr_main" >&2; exit 2; }
. "$GUARD_F" || { echo "FIXTURE BROKEN: sourcing $GUARD_F failed" >&2; exit 2; }
declare -F cwg_main > /dev/null || { echo "FIXTURE BROKEN: sourcing $GUARD_F defined no cwg_main" >&2; exit 2; }
show() { sed 's/^/        /' <<<"$1"; }
# Here-string, never a pipe. Under `pipefail` a `grep -q` that matches early exits while the
# writer is still pushing, and the pipeline then reports the writer's EPIPE — a MATCH read as a
# failed assertion, permanently and with no symptom once the output outgrows the pipe buffer.
has() { grep -q "$1" <<<"$2"; }

echo "upstream-routing:"

# Every invocation names its own cwd, and every `cd` is SUBSHELLED so the cwd of this script
# never moves — a `cd` that leaks relocates every later arm, and the resulting "No such file"
# reads as a deleted file rather than as a moved shell.
#
# THE RESULT GOES TO A FILE, NEVER THROUGH A COMMAND SUBSTITUTION. `out=$(runner)` puts the
# runner in a subshell, so the `RC=$?` inside it is discarded and the caller reads an unset
# variable — or, worse, the previous arm's exit code.
#
# A COPY OF THE SUBJECT RESOLVES ITS OWN ROOT AND WOULD IGNORE THE TREE UNDER TEST. The subject
# walks up from its own directory for a marker, so a copy under `mktemp` answers about whatever
# it finds above /var/folders — measured, and it renders as `EXAMINED NOTHING`,
# which reads exactly like a refusal. Every COPY is therefore pinned with
# AI_DLC_PROJECT_ROOT; the arms exercising the REAL subject pass `-` and let it resolve, because
# that resolution is itself under test at assertions 26 and 28.
_run() { # _run <script> <backlog> <outfile> <root|-> <cwd> <txt|json>
  local script="$1" backlog="$2" out="$3" root="$4" cwd="$5" mode="$6"
  ( cd "$cwd" || exit 2
    [ "$root" = "-" ] || export AI_DLC_PROJECT_ROOT="$root"
    # A COPY is sourced inside this subshell, so the real upr_main stays defined in this shell for the next arm; it
    # sits under core/scripts/, so its calls are counted under the subject's inproc: row.
    if [ "$script" != "$SUBJ" ]; then
      . "$script" || exit 2
    fi
    if [ "$mode" = json ]; then fx_inproc "$script"; upr_main --backlog "$backlog" --json >"$out" 2>"$out.err"
    else fx_inproc "$script"; upr_main --backlog "$backlog" >"$out" 2>&1; fi )
  RC=$?
}
# Default cwd is the project ROOT: that is where the pre-push hook runs a fixture, and it is the
# cwd under which the OLD manifest resolution happened to work — so it is the one that would hide
# the cwd-dependence assertion 26 exists to rule out.
run_txt()  { _run "$1" "$2" "$3" "${4:--}" "${5:-$ROOT}" txt; }
run_json() { _run "$1" "$2" "$3" "${4:--}" "${5:-$ROOT}" json; }

# A flat, greppable rendering of the JSON report. Reading a structured field beats grepping the
# prose report for a count: the prose is one line carrying three numbers and a substring match on
# it cannot say WHICH number moved.
cat >"$WORK/summarize.py" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
print("entries=%d" % d["entries"])
print("paired=%d" % d["paired"])
print("globs=%d" % d["globs"])
# Indexed, never .get()-ed. A subject that DELETES either key has stopped
# answering, and a default would render that as a legitimate zero — the shape of silence
# reading as a pass. A KeyError here fails the arm loudly instead.
print("absent_named=%d" % d["absent_named"])
# Same rule as absent_named: indexed, never .get()-ed. A subject that stopped emitting the
# PAIRED BUT UNPLACEABLE data must fail the arm loudly rather than render as an honest zero.
print("unplaceable_n=%d" % len(d["paired_unplaceable"]))
for u in d["paired_unplaceable"]:
    print("unplaceable=%s" % u["id"])
    for p in u["paths"]:
        print("unplaceable_path=%s %s" % (u["id"], p))
for f in d["findings"]:
    print("finding=%s" % f["id"])
    for p in f["paths"]:
        print("path=%s %s" % (f["id"], p))
    for r in f["named"]:
        print("named=%s %s %s" % (f["id"], r["path"], "present" if r["exists"] else "absent"))
PY
summarize() { python3 "$WORK/summarize.py" "$1"; }

# ---------------------------------------------------------------------------------------------
# THE SEEDS ARE THE PRODUCER'S SHAPES, NOT THE READER'S ACCEPT-SET. `steps/carry-over-evaluation.md`
# fixes the id grammar (`CO-S<sprint>-<descriptor>`) and requires `**Status:** OPEN` in the body;
# the two heading levels are the subject's own recorded measurement of the reference consumer's
# backlog, which carries `### CO-S...` AND `## [CO-S...]`. A seed derived from the regex in the
# subject would prove only that the subject accepts its own grammar, and would stay green through
# a change to both.
# ---------------------------------------------------------------------------------------------

# THE PAIRING DISCRIMINATOR AND ITS NEAR-MISS SIT IN ONE FILE, READ BY ONE INVOCATION, AND DIFFER
# IN EXACTLY ONE FIELD — the trailing `PC-` citation. A near-miss in a SEPARATE run is an ADJACENT
# input: it can establish that the arm fires, never that it fires on the RIGHT entry.
MAIN="$WORK/backlog-main.md"
cat >"$MAIN" <<'EOF'
# Carry-over backlog

Items deferred out of the sprint. Every item carries a Status.

### CO-S401-UNPAIRED
**Status:** OPEN
The resolver in `scripts/ai-dlc/core-paths.sh` picks the wrong manifest when both layouts
are present, so the gate classifies a core edit as consumer work.

### CO-S401-PAIRED
**Status:** OPEN
The resolver in `scripts/ai-dlc/core-paths.sh` picks the wrong manifest when both layouts
are present, so the gate classifies a core edit as consumer work. Filed upstream as PC-S401-01.

## [CO-S402-BRACKET]
**Status:** OPEN
`.claude/hooks/ai-dlc-core-guard.sh` denies a write to a path the manifest does not own.

### CO-S403-CONSUMER
**Status:** OPEN
`docs/architecture/decisions.md` contradicts `src/services/billing.py` on the retry budget.
EOF

# --- 1. SANITY, with a POSITIVE conjunct ------------------------------------------------------
# rc=0 alone is what a subject replaced by `exit 0` produces, so the sanity arm demands a named
# row as well. Without that conjunct every absence-shaped arm below scores a kill against silence.
run_txt "$SUBJ" "$MAIN" "$WORK/main.txt"; main_rc=$RC; main_txt="$(cat "$WORK/main.txt")"
if [ "$main_rc" = "0" ] && has 'CO-S401-UNPAIRED' "$main_txt"; then
  ok "SANITY: the seeded corpus produces a report that NAMES the misrouted entry (rc=0)"
else
  bad "SANITY: rc=$main_rc and the seeded misroute was not named — every assertion below is unreadable"
  show "$main_txt"
fi

# =============================================================================================
# 2-4. AGREEMENT WITH THE SHIPPING PREDICATE, ACROSS THREE PARTIES. The subject matches
# in-process against `--list`; `core-paths.sh --is-core` matches with a shell `case`;
# `ai-dlc-core-guard.sh` decides deny/allow on a write. Nothing in the three programs makes them
# agree, and all three must, because they are one rule with three readers.
#
# WHY THE GUARD IS HERE, AND WHY I25 IS NOT ENOUGH. `validate-enforcement-map.sh` (I25)
# byte-compares `parse_manifest()` and `to_consumer_glob()` between the guard and the resolver,
# and its own error text states the stake: "One denies edits to core, the other tells Check 16
# which files are core; a rule that differs between them means a file the guard protects can be
# audited as consumer-authored." Both functions are inside that join. THE DECISION IS NOT.
# `v0.457.0` forked the two at the decision — the guard went on denying a write to an invented
# name under `scripts/ai-dlc/`, while `--is-core` began refusing to call it core — and I25 passed
# on every run. This arm closes the gap by comparing the ANSWERS instead of the parsers.
#
# THE INVENTED FILENAME IS THE INPUT THAT SEPARATES THEM. Every other seeded path either is or is
# not core by a rule all three already share; only a name under a core glob that no tree contains
# distinguishes destination-ownership from file-existence. It is last in the set and it is the
# reason the set exists.
AGREE_PATHS='scripts/ai-dlc/core-paths.sh
.claude/hooks/ai-dlc-core-guard.sh
.claude/skills/ai-dlc/SKILL.md
.claude/skills/ai-dlc/steps/gate-validation.md
.claude/team-roles/dev.md
tests/fixtures/check-15-bypass/run.sh
.claude/skills/ai-dlc/overrides/gate-validation.md
scripts/ai-dlc-local/my-tool.sh
docs/architecture/decisions.md
src/services/billing.py
scripts/ai-dlc/NEVER-SHIPPED-BY-ANYONE.sh'
INVENTED='scripts/ai-dlc/NEVER-SHIPPED-BY-ANYONE.sh'

# One entry per path, none of them paired, so a path is reported if and only if the in-process
# predicate classified it as machinery.
AGREE_BL="$WORK/backlog-agree.md"
{
  echo "# Carry-over backlog"
  echo
  n=0
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    n=$((n+1))
    printf '### CO-S400-AGREE%d\n**Status:** OPEN\nThe failure reproduces in `%s`.\n\n' "$n" "$p"
  done <<EOF
$AGREE_PATHS
EOF
} >"$AGREE_BL"

# --- 2. EXTRACTION CONTROL: the NO set is a real NO, not a path the regex never saw -----------
# Absence from the findings list has two causes — "classified as consumer-owned" and "never
# extracted from the body at all" — and assertion 3 would read them identically. A stub `--list`
# emitting `*` makes every EXTRACTED path report, so the extracted set becomes observable through
# the shipping extractor rather than through a second implementation of it.
mkdir -p "$WORK/stub-all/core/scripts" "$WORK/stub-empty/core/scripts"
cp "$SUBJ" "$WORK/stub-all/core/scripts/audit-upstream-routing.sh"
cp "$SUBJ" "$WORK/stub-empty/core/scripts/audit-upstream-routing.sh"
cat >"$WORK/stub-all/core/scripts/core-paths.sh" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = "--list" ] && { printf '*\n'; exit 0; }
exit 2
EOF
cat >"$WORK/stub-empty/core/scripts/core-paths.sh" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = "--list" ] && exit 0
exit 2
EOF

run_json "$WORK/stub-all/core/scripts/audit-upstream-routing.sh" "$AGREE_BL" "$WORK/all.json" "$ROOT"
all_rc=$RC
missed=""
if [ "$all_rc" = "0" ]; then
  all_sum="$(summarize "$WORK/all.json")"
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    has "^path=CO-S400-AGREE[0-9]* ${p}\$" "$all_sum" || missed="${missed}${p}
"
  done <<EOF
$AGREE_PATHS
EOF
fi
if [ "$all_rc" = "0" ] && [ -z "$missed" ]; then
  ok "EXTRACTION CONTROL: with a glob set of '*' every seeded path is extracted and reported"
else
  bad "EXTRACTION CONTROL: rc=$all_rc and these seeded paths were never extracted, so their absence below means nothing:"
  show "${missed}$(cat "$WORK/all.json.err" 2>/dev/null)"
fi

# --- the guard sandbox: a LAYERED consumer, where all three parties are LIVE -------------------
# THE THIRD PARTY MUST BE ASKED WHERE IT IS ACTIVE. `ai-dlc-core-guard.sh` is a no-op off a
# layered consumer — a `.claude/.ai-dlc-version` stamp plus both layer dirs — so a guard probe run
# against $ROOT answers ALLOW for everything and the "agreement" is between two parties and a
# corpse. The resolver is asked from this same tree for the mirror reason: `v0.457.0`'s membership
# fork was itself gated on the layered-consumer rule, so from the dormant distribution root it
# answers exactly as the fixed one does and the defect is invisible. Measured while building this
# arm: from $ROOT the re-applied defect moves ZERO verdicts; from here it moves exactly one.
#
# EVERY SEEDED PATH IS CREATED HERE EXCEPT THE INVENTED ONE, so presence is uniform across the set
# and the invented path differs from its neighbours in exactly one property — the property under
# test. Without that the arm would be varying two things at once.
GTREE="$WORK/guard-tree"
mkdir -p "$GTREE/.claude/skills/ai-dlc/overrides" \
         "$GTREE/.claude/skills/ai-dlc/extensions" \
         "$GTREE/.claude/skills/ai-dlc-update/reconcile"
: > "$GTREE/.claude/.ai-dlc-version"
cp "$MANIFEST_F" "$GTREE/.claude/skills/ai-dlc/core-manifest.md"
cp "$SITES_F"    "$GTREE/.claude/skills/ai-dlc-update/reconcile/setup-sites.md"
while IFS= read -r p; do
  [ -n "$p" ] || continue
  [ "$p" = "$INVENTED" ] && continue
  mkdir -p "$GTREE/$(dirname "$p")" && : > "$GTREE/$p"
done <<EOF
$AGREE_PATHS
EOF
[ ! -e "$GTREE/$INVENTED" ] || { echo "FIXTURE ERROR: the invented path exists in the guard sandbox, so it is not invented" >&2; exit 2; }
[ -e "$GTREE/scripts/ai-dlc/core-paths.sh" ] || { echo "FIXTURE ERROR: the guard sandbox carries no real core file, so a deny cannot be told from a fail-open" >&2; exit 2; }

# THE GUARD'S VERDICT IS ITS STDOUT, NEVER ITS EXIT CODE. `route_and_deny` prints a
# permissionDecision JSON and then exits 0, and the allow paths exit 0 too — so a probe keyed on
# `$?` reads ALLOW for every input and can never fire. Measured while building this arm: 11 inputs,
# 11 exit zeros, 7 of them denials. `Write` is the tool driven on purpose: the guard short-circuits
# the /ai-dlc-setup config-region exemption for a whole-file overwrite, so its answer here is a
# pure core-membership verdict and nothing else.
guard_says() {   # <project-relative path> -> deny | allow
  local out
  out="$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$1" \
         | ( export CLAUDE_PROJECT_DIR="$GTREE"; fx_inproc "$GUARD_F"; cwg_main ) 2>/dev/null)"
  if has '"permissionDecision": *"deny"' "$out"; then printf 'deny'; else printf 'allow'; fi
}
# Asked once and cached: the sandbox does not move between assertions 3 and 31, and the guard is a
# bash+jq spawn per path on a pole-bound suite.
GUARD_VERDICTS=""
while IFS= read -r p; do
  [ -n "$p" ] || continue
  GUARD_VERDICTS="${GUARD_VERDICTS}${p} $(guard_says "$p")
"
done <<EOF
$AGREE_PATHS
EOF
# Exact string compare, not a regex: a `.` in a path is a BRE wildcard and would let one seeded
# path answer for another. MISSING is loud rather than defaulting to allow.
guard_verdict() { awk -v p="$1" '$1==p {print $2; f=1} END{if(!f) print "MISSING"}' <<<"$GUARD_VERDICTS"; }

# --- 3. AGREEMENT: three parties, one seeded set, zero disagreements ---------------------------
run_json "$SUBJ" "$AGREE_BL" "$WORK/agree.json"; agree_rc=$RC
inproc=""
if [ "$agree_rc" = "0" ]; then
  inproc="$(summarize "$WORK/agree.json")"
fi
disagree=""; n_core=0; n_not=0; n_refused=0; n_deny=0; n_allow=0; n_in_core=0; n_in_not=0
while IFS= read -r p; do
  [ -n "$p" ] || continue
  ( cd "$GTREE" && bash "$CPATHS" --is-core "$p" "$MANIFEST_F" >/dev/null 2>&1 ); is_rc=$?
  if has "^path=CO-S400-AGREE[0-9]* ${p}\$" "$inproc"; then
    in_says=core; n_in_core=$((n_in_core+1))
  else
    in_says=not-core; n_in_not=$((n_in_not+1))
  fi
  case "$is_rc" in
    0) is_says=core ;;
    1) is_says=not-core ;;
    *) is_says="refused($is_rc)"; n_refused=$((n_refused+1)) ;;
  esac
  [ "$is_says" = core ]     && n_core=$((n_core+1))
  [ "$is_says" = not-core ] && n_not=$((n_not+1))
  case "$(guard_verdict "$p")" in
    deny)  g_says=core;     n_deny=$((n_deny+1)) ;;
    allow) g_says=not-core; n_allow=$((n_allow+1)) ;;
    *)     g_says=MISSING ;;
  esac
  if [ "$in_says" != "$is_says" ] || [ "$in_says" != "$g_says" ]; then
    disagree="${disagree}${p}: in-process=${in_says} --is-core=${is_says} guard=${g_says}
"
  fi
done <<EOF
$AGREE_PATHS
EOF

if [ "$agree_rc" = "0" ] && [ "$n_refused" = "0" ] && [ -z "$disagree" ]; then
  ok "AGREEMENT: the router's in-process \`--list\` matching, \`core-paths.sh --is-core\` and \`ai-dlc-core-guard.sh\`'s deny/allow all give the same answer on every seeded path, INCLUDING an invented filename under a core glob"
else
  bad "AGREEMENT: rc=$agree_rc, $n_refused refusal(s), and the three routes disagreed. A file the guard protects can now be audited as consumer-authored; I25 binds only parse_manifest() and to_consumer_glob(), so a fork at the DECISION passes it:"
  show "$disagree"
fi

# --- 4. and it DISCRIMINATES. Three routes that all answer one class to everything also agree --
if [ "$n_core" -gt 0 ] && [ "$n_not" -gt 0 ] \
   && [ "$n_deny" -gt 0 ] && [ "$n_allow" -gt 0 ] \
   && [ "$n_in_core" -gt 0 ] && [ "$n_in_not" -gt 0 ]; then
  ok "AGREEMENT DISCRIMINATES: every route produced BOTH answers (--is-core $n_core/$n_not, guard $n_deny deny/$n_allow allow, in-process $n_in_core/$n_in_not)"
else
  bad "AGREEMENT DISCRIMINATES: --is-core $n_core/$n_not, guard $n_deny deny/$n_allow allow, in-process $n_in_core/$n_in_not — a route answering one class to everything makes assertion 3 vacuous. A guard reading 0 deny is the BROKEN-PROBE shape: it exits 0 on allow AND on deny, so a probe must read the permissionDecision on stdout, and it fails open without a readable setup-sites.md in the sandbox"
fi

# =============================================================================================
# 5-11. The report over the main corpus.
# =============================================================================================
run_json "$SUBJ" "$MAIN" "$WORK/main.json"; main_json_rc=$RC
if [ "$main_json_rc" != "0" ]; then
  main_sum=""
else
  main_sum="$(summarize "$WORK/main.json")"
fi

# --- 5. the unpaired entry IS reported --------------------------------------------------------
has '^finding=CO-S401-UNPAIRED$' "$main_sum" \
  && ok "an entry naming machinery with no PC- id is REPORTED" \
  || bad "the unpaired machinery entry was not reported — the subject's whole purpose cannot fire"

# --- 6. the paired near-miss is NOT (absence-shaped) -------------------
has '^finding=CO-S401-PAIRED$' "$main_sum" \
  && bad "the PC-cited entry was reported too — the pairing discriminator is gone, and every routed entry is now noise" \
  || ok "the near-miss differing ONLY in its PC- citation is NOT reported"

# --- 7. and the pairing was COUNTED, not merely skipped ---------------------------------------
has '^paired=1$' "$main_sum" \
  && ok "the paired entry is counted in the report's \`paired\` field" \
  || bad "the \`paired\` count did not read 1 — a skipped entry that is not counted is invisible"

# --- 8. the bracketed heading shape reaches the CLASSIFIER ------------------------------------
# OWNER of the heading-grammar case. Assertion 9's corpus size moves with it — the two are one
# defect seen twice — and this arm is the one that names the entry, so this arm owns it.
has '^finding=CO-S402-BRACKET$' "$main_sum" \
  && ok "a \`## [CO-S...]\` entry is parsed AND classified (both producer heading shapes)" \
  || bad "the bracketed heading shape was dropped — the corpus silently shrinks and the report looks cleaner"

# --- 9. the corpus size is the seeded one -----------------------------------------------------
has '^entries=4$' "$main_sum" \
  && ok "all 4 seeded entries were examined" \
  || bad "the examined-entry count is not 4 — a grammar that drops entries reports a smaller, cleaner corpus"

# --- 10. an entry naming only CONSUMER paths is NOT reported (absence-shaped) ----
has '^finding=CO-S403-CONSUMER$' "$main_sum" \
  && bad "an entry naming only consumer-owned paths was reported — the predicate convicts correct consumer work" \
  || ok "an entry naming only consumer-owned paths is NOT reported"

# --- 11. REPORT-ONLY: exit 0 WITH findings ----------------------------------------------------
# Asserted explicitly because the plausible "fix" is to make it exit 1, and that wedges every
# consumer sprint on a routing JUDGEMENT — which `mechanism-design.md` forbids outright.
if [ "$main_rc" = "0" ] && has 'MISROUTED (2) ' "$main_txt" && has 'REPORT-ONLY: this exits 0' "$main_txt"; then
  ok "REPORT-ONLY: 2 findings reported and the exit is still 0"
else
  bad "REPORT-ONLY: rc=$main_rc with findings — a reporter that fails the build wedges every sprint on a routing judgement"
  show "$main_txt"
fi

# --- 12. a fully-routed corpus reports MISROUTED (0) at exit 0 --------------------------------
CLEAN="$WORK/backlog-clean.md"
cat >"$CLEAN" <<'EOF'
# Carry-over backlog

### CO-S404-ROUTED
**Status:** OPEN
`scripts/ai-dlc/core-paths.sh` picks the wrong manifest. Filed upstream as PC-S404-01; the
CO- item tracks only the local workaround.
EOF
run_txt "$SUBJ" "$CLEAN" "$WORK/clean.txt"; clean_rc=$RC; clean_txt="$(cat "$WORK/clean.txt")"
if [ "$clean_rc" = "0" ] && has 'MISROUTED (0)' "$clean_txt"; then
  ok "a corpus whose machinery entries all cite a PC- id reports MISROUTED (0) at exit 0"
else
  bad "the fully-routed corpus did not report a clean 0 (rc=$clean_rc)"
  show "$clean_txt"
fi

# =============================================================================================
# 13-16. EXAMINED NOTHING IS EXIT 2, NEVER A CLEAN 0. Four ways the subject can read nothing.
# Each of them, reported as 0, is a lie about an unread corpus — and the empty-glob one is the
# worst, because an empty glob set classifies EVERY path as consumer-owned and produces a
# confident clean report over a predicate that is dead.
# =============================================================================================

# --- 13. the sibling core-paths.sh is absent --------------------------------------------------
mkdir -p "$WORK/nosib/core/scripts"
cp "$SUBJ" "$WORK/nosib/core/scripts/audit-upstream-routing.sh"
run_txt "$WORK/nosib/core/scripts/audit-upstream-routing.sh" "$MAIN" "$WORK/nosib.txt" "$ROOT"; nosib_rc=$RC; nosib_txt="$(cat "$WORK/nosib.txt")"
if [ "$nosib_rc" = "2" ] && has 'EXAMINED NOTHING' "$nosib_txt" && ! has 'MISROUTED' "$nosib_txt"; then
  ok "no core-paths.sh beside the subject -> exit 2 EXAMINED NOTHING, and no MISROUTED line"
else
  bad "a missing sibling gave rc=$nosib_rc — a refusal was rendered as a finding"
  show "$nosib_txt"
fi

# --- 14. `--list` produced no globs ----------------------------------
run_txt "$WORK/stub-empty/core/scripts/audit-upstream-routing.sh" "$MAIN" "$WORK/empty.txt" "$ROOT"; empty_rc=$RC; empty_txt="$(cat "$WORK/empty.txt")"
if [ "$empty_rc" = "2" ] && has 'EXAMINED NOTHING' "$empty_txt" && ! has 'MISROUTED (0)' "$empty_txt"; then
  ok "an EMPTY glob set -> exit 2, not a confident MISROUTED (0) over a dead predicate"
else
  bad "an empty glob set gave rc=$empty_rc — every path now classifies as consumer-owned and the report reads clean"
  show "$empty_txt"
fi

# --- 15. the backlog is absent ----------------------------------------------------------------
run_txt "$SUBJ" "$WORK/no-such-backlog.md" "$WORK/absent.txt"; absent_rc=$RC; absent_txt="$(cat "$WORK/absent.txt")"
if [ "$absent_rc" = "2" ] && has 'EXAMINED NOTHING' "$absent_txt" && ! has 'MISROUTED' "$absent_txt"; then
  ok "an absent backlog -> exit 2 EXAMINED NOTHING"
else
  bad "an absent backlog gave rc=$absent_rc — 'nothing was read' was rendered as 'no misrouted entries'"
  show "$absent_txt"
fi

# --- 16. the backlog parses to 0 entries -----------------------------
ZERO="$WORK/backlog-zero.md"
cat >"$ZERO" <<'EOF'
# Carry-over backlog

No items are open this sprint. The heading grammar below is the OLD one.

## Sprint 405
Nothing deferred.
EOF
run_txt "$SUBJ" "$ZERO" "$WORK/zero.txt"; zero_rc=$RC; zero_txt="$(cat "$WORK/zero.txt")"
if [ "$zero_rc" = "2" ] && has 'EXAMINED NOTHING' "$zero_txt" && ! has 'MISROUTED (0)' "$zero_txt"; then
  ok "a backlog parsing to 0 entries -> exit 2, not MISROUTED (0)"
else
  bad "a 0-entry parse gave rc=$zero_rc — a grammar that stopped matching the producer reads as a clean tree"
  show "$zero_txt"
fi

# A copy of the subject beside a copied core-paths.sh: the no-manifest arm below drives it.
CTL="$WORK/subj-copy/core/scripts"
mkdir -p "$CTL"; cp "$SUBJ" "$CTL/audit-upstream-routing.sh"; cp "$CPATHS" "$CTL/core-paths.sh"


# =============================================================================================
# 26-29. THE MANIFEST IS RESOLVED AGAINST THE ROOT MARKER, NOT AGAINST THE PROCESS CWD.
# `core-paths.sh --list` with no argument falls back to two RELATIVE candidate paths, so bare it
# answers about the working directory: the full glob set from a project root, NONE one directory
# down. A reporter that silently swaps a live predicate for a dead one depending on where it was
# invoked is the same defect as assertion 14, reached by a different route — and the route is a
# cwd, which no arm run only from the root can see.
# =============================================================================================

# --- 26. the report is identical from the ROOT and from a SUBDIRECTORY -------------------------
# THE ROOT IS PINNED ON BOTH SIDES, SO cwd IS THE ONLY VARIABLE. Left unpinned this arm also
# exercises the subject's root resolution, and then a subject supplied as $1 from outside the
# tree refuses on both sides for a reason that has nothing to do with cwd. Pinning loses nothing real, because for an
# in-tree subject the walk-up from its own directory always wins before cwd is ever consulted.
#
# The subdirectory is THIS fixture's own directory: it exists in both install layouts, it is
# always under the root, and it is deep enough that `--list`'s relative candidates cannot resolve
# from it.
SUBDIR="$HERE"
run_json "$SUBJ" "$MAIN" "$WORK/cwd-root.json" "$ROOT" "$ROOT";   cwd_root_rc=$RC
run_json "$SUBJ" "$MAIN" "$WORK/cwd-sub.json"  "$ROOT" "$SUBDIR"; cwd_sub_rc=$RC
if [ "$cwd_root_rc" = "0" ] && [ "$cwd_sub_rc" = "0" ] && cmp -s "$WORK/cwd-root.json" "$WORK/cwd-sub.json"; then
  ok "CWD-INVARIANT: byte-identical reports from the project root and from $(basename "$SUBDIR")/"
else
  bad "CWD-INVARIANT: root rc=$cwd_root_rc, subdir rc=$cwd_sub_rc, reports differ — the predicate depends on where the tool was invoked"
  show "$(diff "$WORK/cwd-root.json" "$WORK/cwd-sub.json" 2>&1 | head -20)"
fi


# --- 28. no core-manifest.md under the resolved root -> exit 2 --------------------------------
# The fifth way to examine nothing, and the one with a trap door: with no manifest the subject
# would hand `core-paths.sh` an EMPTY argument, which is not "no manifest" to that script — it is
# "fall back to the relative candidates", i.e. to the cwd. Assertion 29 builds that.
mkdir -p "$WORK/emptyroot"
run_txt "$CTL/audit-upstream-routing.sh" "$MAIN" "$WORK/noman.txt" "$WORK/emptyroot"; noman_rc=$RC
noman_txt="$(cat "$WORK/noman.txt")"
if [ "$noman_rc" = "2" ] && has 'EXAMINED NOTHING' "$noman_txt" && ! has 'MISROUTED' "$noman_txt"; then
  ok "a root with no core-manifest.md in either layout -> exit 2 EXAMINED NOTHING"
else
  bad "a rootless tree gave rc=$noman_rc — the subject classified against something it did not find"
  show "$noman_txt"
fi


# =============================================================================================
# 30-42. A GLOB MATCH IS EVIDENCE ABOUT A DESTINATION, NEVER ABOUT A FILE — AND THE TREE THE
# QUESTION IS ASKED ABOUT IS THE BACKLOG'S.
#
# ONE SUBJECT NOW, NOT TWO, AND THAT IS THE CORRECTION `v0.458.0` MAKES. `v0.457.0` taught
# `core-paths.sh --is-core` to refuse a path matching a core glob that named no file on a layered
# consumer. That was wrong: destination ownership of `scripts/ai-dlc/` is the shipped, deliberate
# design, stated verbatim in `ai-dlc-core-guard.sh`'s own remedy text — "scripts/ai-dlc/ is
# core-owned in its entirety (core-manifest.md claims `scripts/ai-dlc/*`), so this deny stands
# whether or not the distribution ships a file by that name". The guard must deny a Write to a
# path BEFORE it exists, which is exactly when a Write fires. `--is-core` answering 0 there was
# the resolver AGREEING with the guard; the change made them disagree. It is reverted, and
# assertions 3-4 are what would have caught it.
#
# WHAT SURVIVES IS THE REPORTER'S LABEL, whose root resolution is now the BACKLOG's tree rather
# than the running copy's. The reporter LABELS an absent path `[NO SUCH FILE HERE]` and
# deliberately does NOT filter it, because on the reference consumer both absent paths belonged
# upstream and a filter would have acquitted a true misroute.
#
# BOTH HALVES FAIL SILENTLY. The label simply stops appearing, which reads like a corpus with
# nothing absent in it; and a label keyed on the WRONG tree fires on everything, which reads like
# a corpus where nothing exists. So every arm below carries its opposite in the same run — a
# seeded offender AND a seeded near-miss, a rooted corpus AND an unrootable one, one tree AND a
# second one.
# =============================================================================================

# --- the label sandboxes: the tree is the BACKLOG's, and a SECOND tree is what proves it ------
# THE PAIR MUST SHARE A RUN AND A CORPUS. A near-miss measured in a SEPARATE run is an ADJACENT
# input: it can only ask whether the label fires at all, never whether it fires on the RIGHT path.
# So CO-S410-MIXED names one present path and one absent path IN THE SAME ENTRY, and both come
# from the SAME glob (`scripts/ai-dlc/*`) — the two probes differ in exactly one property, which
# is the one under test.
#
# THE FALSE POSITIVE THAT SHIPPED, AND THE REASON THERE ARE TWO TREES. `v0.457.0` keyed the
# existence check on AI_DLC_ROOT — wherever the RUNNING COPY resolved from — while the paths in a
# carry-over entry are relative to the consumer that WROTE it, and `--backlog` names a corpus in a
# third place. Measured on that release: the distribution's copy, pointed at the reference
# consumer's real backlog, marked 4 of 4 findings `[NO SUCH FILE HERE]`, because no
# consumer-relative path exists in a distribution checkout. CTREE is a layered consumer holding
# the corpus AND the files; OTHER is a different tree with a manifest and NONE of the paths,
# standing in for that distribution. One tree cannot express the defect at all.
CTREE="$WORK/consumer-tree"
mkdir -p "$CTREE/.claude/skills/ai-dlc/overrides" \
         "$CTREE/.claude/skills/ai-dlc/extensions" \
         "$CTREE/scripts/ai-dlc" "$CTREE/_bmad-output"
: > "$CTREE/.claude/.ai-dlc-version"
cp "$MANIFEST_F" "$CTREE/.claude/skills/ai-dlc/core-manifest.md"
: > "$CTREE/scripts/ai-dlc/core-paths.sh"
: > "$CTREE/scripts/ai-dlc/verdict-lib.sh"
# A WILDCARD FAMILY THAT REALLY EXISTS. `os.path.exists()` does not expand a glob, so the first
# cut of the label reported every `*` token absent unconditionally -- measured on the reference
# consumer, `.claude/hooks/ai-dlc-*.sh` matched 22 files and was still marked missing. Two members
# rather than one: a single file would leave a one-member glob and a literal path indistinguishable.
mkdir -p "$CTREE/.claude/hooks"
: > "$CTREE/.claude/hooks/ai-dlc-core-guard.sh"
: > "$CTREE/.claude/hooks/ai-dlc-acknowledge.sh"

OTHER="$WORK/other-tree"
mkdir -p "$OTHER/.claude/skills/ai-dlc"
cp "$MANIFEST_F" "$OTHER/.claude/skills/ai-dlc/core-manifest.md"
# ASSERTED, NOT ASSUMED: if OTHER happened to carry the seeded paths, assertion 35 would compare
# two identical labelings and pass while measuring nothing.
[ ! -e "$OTHER/scripts/ai-dlc/core-paths.sh" ] || { echo "FIXTURE ERROR: the second tree carries a seeded path, so assertion 35 cannot discriminate" >&2; exit 2; }

ABSBL="$CTREE/_bmad-output/backlog-absent.md"
cat >"$ABSBL" <<'MD'
# Carry-over backlog

### CO-S410-PRESENT
**Status:** OPEN
`scripts/ai-dlc/core-paths.sh` picks the wrong manifest when both layouts are present.

### CO-S410-MIXED
**Status:** OPEN
`scripts/ai-dlc/core-paths.sh` should hand the verdict merge to
`scripts/ai-dlc/merge-gate-verdicts.sh`, which this item proposes and no tree yet carries.

### CO-S410-ABSENTONLY
**Status:** OPEN
`scripts/ai-dlc/never-shipped-by-anyone.sh` reports the wrong sprint id.
MD

# A SEPARATE CORPUS, NOT A WIDER ONE. Assertions 33 and 36 count $ABSBL's entries and compare its
# id set against a sibling; adding rows there moves numbers those arms read, which is how a new
# arm breaks three old ones.
GLOBBL="$CTREE/_bmad-output/backlog-glob.md"
cat >"$GLOBBL" <<'MD'
# Carry-over backlog

### CO-S411-GLOBPRESENT
**Status:** OPEN
The dispatch guard family `.claude/hooks/ai-dlc-*.sh` stamps the wrong sprint.

### CO-S411-GLOBABSENT
**Status:** OPEN
The reporter family `scripts/ai-dlc/never-shipped-*.sh` cannot resolve its own root.
MD

# The SAME corpus with the two absent filenames swapped for present ones. Same ids, same entry
# count, same number of named paths per entry — the ONLY property that moves is whether the file
# is on disk. Assertion 32 reads the finding set off both and requires them identical.
PRESBL="$CTREE/_bmad-output/backlog-allpresent.md"
sed -e 's#scripts/ai-dlc/merge-gate-verdicts\.sh#scripts/ai-dlc/verdict-lib.sh#' \
    -e 's#scripts/ai-dlc/never-shipped-by-anyone\.sh#scripts/ai-dlc/verdict-lib.sh#' \
    "$ABSBL" >"$PRESBL"
if cmp -s "$ABSBL" "$PRESBL"; then
  echo "FIXTURE ERROR: the all-present corpus is byte-identical to the absent one — the sed matched nothing and assertion 33 would compare a corpus with itself" >&2
  exit 2
fi

# THE SAME BYTES, OUTSIDE ANY LAYERED TREE. $WORK is a mktemp directory with no
# `.claude/.ai-dlc-version` above it, so the corpus is identical and only its LOCATION differs —
# which is the single property assertion 36 is about.
UNROOTBL="$WORK/backlog-unrooted.md"
cp "$ABSBL" "$UNROOTBL"
# THE PREMISE, CHECKED RATHER THAN HOPED FOR. $WORK comes from `mktemp -d`, and if TMPDIR ever
# pointed inside a layered tree the corpus would be rootable after all — assertion 36 would then
# fail as though the subject were broken, when what moved was the sandbox. Report BROKEN instead.
_d="$WORK"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  if [ -f "$_d/.claude/.ai-dlc-version" ] \
     && [ -d "$_d/.claude/skills/ai-dlc/overrides" ] \
     && [ -d "$_d/.claude/skills/ai-dlc/extensions" ]; then
    echo "FIXTURE ERROR: \$WORK ($WORK) sits under a layered tree at $_d, so the unrootable corpus is rootable and assertion 36 has no subject" >&2
    exit 2
  fi
  _d="$(dirname "$_d")"
done

run_txt  "$SUBJ" "$ABSBL"  "$WORK/abs.txt"  "$CTREE"; abs_rc=$RC
abs_txt="$(cat "$WORK/abs.txt")"
run_json "$SUBJ" "$ABSBL"  "$WORK/abs.json"  "$CTREE"; absj_rc=$RC
run_json "$SUBJ" "$PRESBL" "$WORK/pres.json" "$CTREE"; presj_rc=$RC
# The same corpus read by a subject whose OWN root is a different tree entirely.
run_json "$SUBJ" "$ABSBL"  "$WORK/abs-other.json" "$OTHER"; absother_rc=$RC
# The unrootable corpus, read by a subject rooted in the layered tree — so a label appearing here
# could only have come from the RUNNING COPY's root, which is the defect.
run_txt  "$SUBJ" "$UNROOTBL" "$WORK/unroot.txt"  "$CTREE"; unroot_rc=$RC
run_json "$SUBJ" "$UNROOTBL" "$WORK/unroot.json" "$CTREE"; unrootj_rc=$RC

# --- 32. the label FIRES on the absent path and STAYS SILENT on the present one ---------------
# Both readings come out of ONE run over ONE corpus, and the marked path and the unmarked path sit
# in the SAME entry. The unmarked pattern is anchored at end-of-line: that is what makes it a
# silence assertion rather than a substring that a marked row would also satisfy.
if [ "$abs_rc" = "0" ] \
   && has '^      names: scripts/ai-dlc/merge-gate-verdicts\.sh   \[NO SUCH FILE HERE\]$' "$abs_txt" \
   && has '^      names: scripts/ai-dlc/core-paths\.sh$' "$abs_txt"; then
  ok "the [NO SUCH FILE HERE] label fires on the absent path and stays silent on the present one — same run, same corpus, same entry, same glob"
else
  bad "the label did not discriminate: rc=$abs_rc, absent path marked / present path unmarked not both true"
  show "$abs_txt"
fi

# --- A WILDCARD THAT MATCHES IS NOT A MISSING FILE, and one that matches nothing still is -------
# Both directions in ONE run over ONE corpus: a `*` token whose family exists on disk must go
# UNLABELLED, and a `*` token matching nothing must still be labelled. Either alone passes under
# the defect -- exists() reports every glob absent, so the labelled half is green for the wrong
# reason and reads exactly like a working arm.
run_txt "$SUBJ" "$GLOBBL" "$WORK/glob.txt" "$CTREE"; glob_rc=$RC; glob_txt="$(cat "$WORK/glob.txt")"
if [ "$glob_rc" = "0" ] \
   && has '^      names: \.claude/hooks/ai-dlc-\*\.sh$' "$glob_txt" \
   && ! has 'ai-dlc-\*\.sh   \[NO SUCH FILE HERE\]' "$glob_txt" \
   && has '^      names: scripts/ai-dlc/never-shipped-\*\.sh   \[NO SUCH FILE HERE\]$' "$glob_txt"; then
  ok "GLOB: a wildcard whose family EXISTS is unlabelled while a wildcard matching NOTHING is labelled — same run, and the labelled half alone would pass under exists()-without-glob"
else
  bad "GLOB: the two wildcard tokens did not split — a matching family and a matching-nothing family must render differently:"
  show "$(printf '%s\n' "$glob_txt" | grep -F 'names:' || true)"
fi

# --- 33. the label LABELS; it does not FILTER -------------------------------------------------
# THE ARM THAT CATCHES SOMEONE LATER "IMPROVING" THIS INTO A FILTER. An entry whose ONLY machinery
# path is absent must still be REPORTED: measured on the reference consumer, both absent paths sat
# in entries that belong upstream — one a script an item PROPOSES at a core destination — so a
# filter would ACQUIT a true misroute in order to remove a label the reader can apply themselves.
# The finding set is derived twice, from two corpora that differ only in file presence, and
# compared; a count alone would not say WHICH entry moved.
abs_ids="$(summarize "$WORK/abs.json" | grep '^finding=' || true)"
pres_ids="$(summarize "$WORK/pres.json" | grep '^finding=' || true)"
abs_n="$(summarize "$WORK/abs.json" | sed -n 's/^entries=//p')"
pres_n="$(summarize "$WORK/pres.json" | sed -n 's/^entries=//p')"
if [ "$absj_rc" = "0" ] && [ "$presj_rc" = "0" ] \
   && has '^finding=CO-S410-ABSENTONLY$' "$abs_ids" \
   && [ "$abs_ids" = "$pres_ids" ] && [ -n "$abs_ids" ] \
   && [ "$abs_n" = "$pres_n" ] && [ "$abs_n" = "3" ]; then
  ok "an absent named path changes NO finding: the entry whose only machinery path is absent is still reported, and the id set and entry count are identical to the all-present corpus (3 entries, non-empty id set as the control)"
else
  bad "the absent path moved the finding SET — absent ids [$(echo "$abs_ids" | tr '\n' ' ')] vs present ids [$(echo "$pres_ids" | tr '\n' ' ')], entries $abs_n vs $pres_n, rc=$absj_rc/$presj_rc"
fi

# --- 34. --json agrees with the TEXT, path by path and in total -------------------------------
# TWO INDEPENDENTLY DERIVED VALUES, NOT ONE READ OFF A RENDERING. `absent_named` comes from the
# JSON; the text count is derived by counting the `names:` ROWS that carry the marker.
#
# KEYED ON THE ROW, NOT ON THE LITERAL. The closing paragraph contains the string
# `[NO SUCH FILE HERE]` in its own prose, so a bare `grep -c` over the report counts the
# explanation as a finding — text ABOUT a program is not the program. The row anchor excludes it,
# and the paragraph's own count is then checked as a third derivation.
txt_absent="$(grep -c '^      names: .*\[NO SUCH FILE HERE\]$' "$WORK/abs.txt" || true)"
json_absent="$(summarize "$WORK/abs.json" | sed -n 's/^absent_named=//p')"
row_mismatch=""
while IFS= read -r nrow; do
  [ -n "$nrow" ] || continue
  np="$(printf '%s\n' "$nrow" | awk '{print $1}')"
  nx="$(printf '%s\n' "$nrow" | awk '{print $2}')"
  # Escape the dots: unescaped they are BRE any-char, and an any-char in the PRESENT branch could
  # match a marked row and hide the mismatch this loop exists to find.
  np_re="$(printf '%s\n' "$np" | sed 's/\./\\./g')"
  if [ "$nx" = "absent" ]; then
    has "^      names: ${np_re}   \[NO SUCH FILE HERE\]\$" "$abs_txt" \
      || row_mismatch="${row_mismatch}${np}: json=absent but the text row is not marked
"
  else
    has "^      names: ${np_re}\$" "$abs_txt" \
      || row_mismatch="${row_mismatch}${np}: json=present but the text row is not rendered unmarked
"
  fi
done <<EOF
$(summarize "$WORK/abs.json" | sed -n 's/^named=[^ ]* //p')
EOF
if [ "$txt_absent" = "$json_absent" ] && [ "$txt_absent" -gt 0 ] \
   && [ -z "$row_mismatch" ] \
   && has "^${txt_absent} named path(s) marked" "$abs_txt"; then
  ok "--json agrees with the text: absent_named=$json_absent equals the $txt_absent marked \`names:\` row(s) and the closing paragraph's own count, and every named[].exists agrees with its row (>0 as the control — 0 == 0 would pass vacuously)"
else
  bad "--json and the text disagree: absent_named=$json_absent, marked rows=$txt_absent, row mismatches: ${row_mismatch:-none}"
  show "$abs_txt"
fi

# --- 35. THE TREE IS THE BACKLOG'S, NOT THE RUNNING COPY'S -------------------------------------
# THE ARM THAT WOULD HAVE CAUGHT THE FALSE POSITIVE THAT SHIPPED, and the one this correction is
# for. The same corpus is read twice, differing ONLY in the root the subject itself resolved to:
# once from the layered tree that holds the files, once from a tree where none of them exist. The
# reports must be byte-identical, because presence is a fact about the BACKLOG's tree and the
# running copy has no standing to change it.
#
# TWO CONTROLS, BOTH NECESSARY, BOTH IN THIS ARM. Byte-equality between two reports that label
# NOTHING is trivially true, so the run must still mark something absent; and byte-equality
# between two reports that label EVERYTHING is equally trivial, so it must still mark something
# present. Without the pair, `cmp -s` passing says only that the two runs failed the same way.
other_sum="$(summarize "$WORK/abs-other.json" 2>/dev/null || true)"
other_absent="$(printf '%s' "$other_sum" | sed -n 's/^absent_named=//p')"
other_present_rows="$(printf '%s' "$other_sum" | grep '^named=.* present$' || true)"
if [ "$absj_rc" = "0" ] && [ "$absother_rc" = "0" ] \
   && cmp -s "$WORK/abs.json" "$WORK/abs-other.json" \
   && [ "${other_absent:-0}" -gt 0 ] && [ -n "$other_present_rows" ]; then
  ok "ROOT PROVENANCE: the same backlog read by a subject rooted in a DIFFERENT tree produces a BYTE-IDENTICAL report — a path is labelled by presence in the BACKLOG's tree, never because the running copy's own root happens to lack it (controls: ${other_absent} still marked absent AND at least one still marked present, so this is not two empty labelings agreeing)"
else
  bad "ROOT PROVENANCE: rc=$absj_rc/$absother_rc, absent_named=${other_absent:-?}, present rows [${other_present_rows:-none}] — the label follows the RUNNING COPY's root. That is the v0.457.0 false positive: the distribution's copy pointed at a consumer's backlog marked 4 of 4 findings absent"
  show "$(diff "$WORK/abs.json" "$WORK/abs-other.json" 2>&1 | head -20)"
fi

# --- 36. NO RESOLVABLE ROOT -> NO LABELS, AND THE FINDINGS ARE UNCHANGED -----------------------
# THE CONJUNCT THAT MATTERS IS THE SECOND ONE. "Nothing was labelled" and "the tool stopped
# reporting" are the same observation from outside, and only the unchanged finding set separates
# them — an unasked question must render as no claim, never as a smaller corpus.
#
# The subject is rooted in CTREE here while the corpus sits outside it, so a marker appearing in
# this run could ONLY have come from the running copy's root. That is what makes this arm a probe
# of provenance and not merely of silence.
unroot_sum="$(summarize "$WORK/unroot.json" 2>/dev/null || true)"
unroot_txt="$(cat "$WORK/unroot.txt" 2>/dev/null || true)"
unroot_ids="$(printf '%s' "$unroot_sum" | grep '^finding=' || true)"
unroot_absent="$(printf '%s' "$unroot_sum" | sed -n 's/^absent_named=//p')"
unroot_entries="$(printf '%s' "$unroot_sum" | sed -n 's/^entries=//p')"
abs_sum="$(summarize "$WORK/abs.json" 2>/dev/null || true)"
rooted_ids="$(printf '%s' "$abs_sum" | grep '^finding=' || true)"
rooted_absent="$(printf '%s' "$abs_sum" | sed -n 's/^absent_named=//p')"
rooted_entries="$(printf '%s' "$abs_sum" | sed -n 's/^entries=//p')"
if [ "$unrootj_rc" = "0" ] && [ "$unroot_rc" = "0" ] \
   && [ "${unroot_absent:-x}" = "0" ] && ! has 'NO SUCH FILE HERE' "$unroot_txt" \
   && [ -n "$unroot_ids" ] && [ "$unroot_ids" = "$rooted_ids" ] \
   && [ "${unroot_entries:-x}" = "${rooted_entries:-y}" ] \
   && [ "${rooted_absent:-0}" -gt 0 ]; then
  ok "UNROOTABLE CORPUS: a backlog with no layered root above it is labelled NOT AT ALL, while the SAME bytes inside a layered tree mark ${rooted_absent} absent (the control that the two runs really differ) — and the findings are identical either way ($unroot_entries entries, $(printf '%s' "$unroot_ids" | grep -c .) reported), so silence is distinguishable from the tool having stopped reporting"
else
  bad "UNROOTABLE CORPUS: rc=$unrootj_rc/$unroot_rc, absent_named=${unroot_absent:-?} (want 0), entries ${unroot_entries:-?} vs ${rooted_entries:-?}, rooted absent ${rooted_absent:-?} (want >0) — either an unplaceable corpus is being labelled from the running copy's root, or the findings changed with the corpus's location, or \$WORK unexpectedly sits under a layered tree so the premise is gone"
  show "$unroot_txt"
fi



# =============================================================================================
# 43-51. PAIRED BUT UNPLACEABLE — a candidate routed upstream against a subject no tree holds.
#
# THE SECTION EXISTS BECAUSE THE LABEL ABOVE HAD NO LIVE SUBJECT. `paired += 1; continue` runs
# before the rows are built, so on the reference consumer both absent tokens — the only two the
# label was written for — sat in paired entries and could never reach it. Routed is not the same
# as actionable: a `PC-` id against a path nobody can locate cannot be worked and cannot be
# closed, and it is the ORIGINAL harm the tool was filed about.
#
# A PAIRED ENTRY IS STILL NOT A FINDING, and every arm here says so in its own conjunct. The
# section is additive: the finding set, the entry count and `paired` are all required to be
# exactly what they were without it. `paired` counting an entry that the section ALSO lists is
# deliberate and is asserted, because a reader who assumed the two partition would double-subtract.
#
# ITS OWN CORPUS, NOT THE LABEL'S. Adding paired entries to $ABSBL would move the entry count that
# assertions 33 and 36 read, so a new subject gets a new seed rather than a widened one.
PAIRBL="$CTREE/_bmad-output/backlog-paired.md"
cat >"$PAIRBL" <<'MD'
# Carry-over backlog

### CO-S430-PAIRED-ABSENT
**Status:** OPEN
Routed upstream as PC-S430-VERDICT-MERGE. The subject is
`scripts/ai-dlc/never-shipped-by-anyone.sh`, which no tree carries.

### CO-S430-PAIRED-PRESENT
**Status:** OPEN
Routed upstream as PC-S430-MANIFEST-PICK. The subject is
`scripts/ai-dlc/core-paths.sh`, which is on disk.

### CO-S430-UNPAIRED
**Status:** OPEN
`scripts/ai-dlc/verdict-lib.sh` reports the wrong sprint id, and cites no push candidate.
MD

# THE NEAR-MISS, ONE PROPERTY APART. The same three entries with the absent filename swapped for
# a present one, so both paired entries name a file on disk and the section has nothing to list.
# The unpaired entry is untouched and still reports, which is what makes "silent" separable from
# "the section was removed" — and from the tool having stopped altogether.
PAIRSILENTBL="$CTREE/_bmad-output/backlog-paired-silent.md"
sed -e 's#scripts/ai-dlc/never-shipped-by-anyone\.sh#scripts/ai-dlc/verdict-lib.sh#' \
    "$PAIRBL" >"$PAIRSILENTBL"
if cmp -s "$PAIRBL" "$PAIRSILENTBL"; then
  echo "FIXTURE ERROR: the silent corpus is byte-identical to the unplaceable one — the sed matched nothing and assertion 46 would compare a corpus with itself" >&2
  exit 2
fi

# The section is the tail of the report; slice it so an id appearing elsewhere cannot be read as
# an id the section listed. `Text about a program is not the program` applies to its output too.
pair_section() { awk '/^PAIRED BUT UNPLACEABLE/{f=1} f' <<<"$1"; }

run_txt  "$SUBJ" "$PAIRBL"       "$WORK/pair.txt"    "$CTREE"; pair_rc=$RC
pair_txt="$(cat "$WORK/pair.txt")"
pair_sec="$(pair_section "$pair_txt")"
run_json "$SUBJ" "$PAIRBL"       "$WORK/pair.json"   "$CTREE"; pairj_rc=$RC
run_txt  "$SUBJ" "$PAIRSILENTBL" "$WORK/pairs.txt"   "$CTREE"; pairs_rc=$RC
pairs_txt="$(cat "$WORK/pairs.txt")"
run_json "$SUBJ" "$PAIRSILENTBL" "$WORK/pairs.json"  "$CTREE"; pairsj_rc=$RC
pair_sum=""; [ "$pairj_rc" = "0" ] && pair_sum="$(summarize "$WORK/pair.json")"
pairs_sum=""; [ "$pairsj_rc" = "0" ] && pairs_sum="$(summarize "$WORK/pairs.json")"

# --- 43. the section LISTS the unplaceable paired entry and OMITS the placeable one -----------
# Same run, same corpus, same glob, one property apart: both entries cite a PC- id and name one
# `scripts/ai-dlc/*` path, and the only difference is whether that file is on disk.
if [ "$pair_rc" = "0" ] && [ -n "$pair_sec" ] \
   && has '^  CO-S430-PAIRED-ABSENT ' "$pair_sec" \
   && has 'never-shipped-by-anyone\.sh' "$pair_sec" \
   && ! has 'CO-S430-PAIRED-PRESENT' "$pair_sec" \
   && ! has 'core-paths\.sh' "$pair_sec"; then
  ok "PAIRED BUT UNPLACEABLE: the section lists the paired entry whose named path is absent and OMITS the paired entry whose named path is present — same run, same corpus, one property apart"
else
  bad "PAIRED BUT UNPLACEABLE: rc=$pair_rc, section [${pair_sec:-absent}] — it must name CO-S430-PAIRED-ABSENT and must not name CO-S430-PAIRED-PRESENT"
  show "$pair_txt"
fi

# --- 44. and it changes NO finding ------------------------------------------------------------
# The section is additive or it is a regression. Ids AND count, derived from both corpora, with a
# non-empty id set as the control — two empty sets are identical and prove nothing.
pair_ids="$(printf '%s' "$pair_sum" | grep '^finding=' || true)"
pairs_ids="$(printf '%s' "$pairs_sum" | grep '^finding=' || true)"
pair_ent="$(printf '%s' "$pair_sum" | sed -n 's/^entries=//p')"
pairs_ent="$(printf '%s' "$pairs_sum" | sed -n 's/^entries=//p')"
if [ "$pairj_rc" = "0" ] && [ "$pairsj_rc" = "0" ] \
   && [ -n "$pair_ids" ] && [ "$pair_ids" = "$pairs_ids" ] \
   && [ "${pair_ent:-x}" = "${pairs_ent:-y}" ]; then
  ok "PAIRED BUT UNPLACEABLE changes NO finding: the id set and entry count are identical with and without an unplaceable paired entry in the corpus ($pair_ent entries, $(printf '%s' "$pair_ids" | grep -c .) reported, non-empty as the control)"
else
  bad "PAIRED BUT UNPLACEABLE changed the findings: rc=$pairj_rc/$pairsj_rc, ids [$(echo "$pair_ids" | tr '\n' ' ')] vs [$(echo "$pairs_ids" | tr '\n' ' ')], entries ${pair_ent:-?} vs ${pairs_ent:-?} — a paired entry is routed, not misrouted, and must never become a finding"
fi

# --- 45. --json agrees with the section, and `paired` still counts the listed entry -----------
# TWO INDEPENDENTLY DERIVED VALUES: one parsed out of the JSON, one counted off the rendered text.
# A single read cannot see the two disagree. The `paired` conjunct is the DOUBLE-COUNT trap stated
# as an assertion: a listed entry appears in `paired` AND in the section by design, so a reader
# who treats them as a partition subtracts it twice.
pair_json_n="$(printf '%s' "$pair_sum" | sed -n 's/^unplaceable_n=//p')"
pair_txt_n="$(printf '%s' "$pair_sec" | grep -c '^  CO-' || true)"
pair_paired="$(printf '%s' "$pair_sum" | sed -n 's/^paired=//p')"
if [ "$pairj_rc" = "0" ] && [ "${pair_json_n:-0}" -gt 0 ] \
   && [ "${pair_json_n:-x}" = "${pair_txt_n:-y}" ] \
   && [ "${pair_paired:-x}" = "2" ] \
   && has '^unplaceable=CO-S430-PAIRED-ABSENT$' "$pair_sum"; then
  ok "PAIRED BUT UNPLACEABLE json/text agree: paired_unplaceable carries $pair_json_n entry(s) and the rendered section lists $pair_txt_n (>0 as the control — 0 == 0 would pass vacuously), while \`paired\` still counts BOTH paired entries including the listed one"
else
  bad "PAIRED BUT UNPLACEABLE json/text: json=${pair_json_n:-?}, rendered=${pair_txt_n:-?}, paired=${pair_paired:-?} (want 2 — the listed entry is still a paired entry) — the JSON and the section are two renderings of one list and must not disagree"
fi

# --- 46. SILENT when no paired entry is unplaceable, and silence is not disappearance ---------
# The conjunct that matters is the second one: a section that vanished and a section with nothing
# to say look identical from outside, and only the findings still rendering separates them.
pairs_json_n="$(printf '%s' "$pairs_sum" | sed -n 's/^unplaceable_n=//p')"
if [ "$pairs_rc" = "0" ] && [ "$pairsj_rc" = "0" ] \
   && ! has 'PAIRED BUT UNPLACEABLE' "$pairs_txt" \
   && [ "${pairs_json_n:-x}" = "0" ] \
   && has 'MISROUTED (1)' "$pairs_txt" \
   && has 'CO-S430-UNPAIRED' "$pairs_txt"; then
  ok "PAIRED BUT UNPLACEABLE stays SILENT when every paired entry names a file that exists — no heading, paired_unplaceable empty — while the findings still render (MISROUTED (1), CO-S430-UNPAIRED), so silence is distinguishable from the section having been removed"
else
  bad "PAIRED BUT UNPLACEABLE silence: rc=$pairs_rc/$pairsj_rc, heading $(has 'PAIRED BUT UNPLACEABLE' "$pairs_txt" && echo present || echo absent), json=${pairs_json_n:-?} (want 0), findings still rendering=$(has 'CO-S430-UNPAIRED' "$pairs_txt" && echo yes || echo NO)"
  show "$pairs_txt"
fi


# --- 52. the section RENDERS when there are no findings at all --------------------------------
# THE CORPUS THAT MOTIVATES THE SECTION IS THE ONE THAT USED TO HIDE IT. A `raise SystemExit(0)`
# in the `MISROUTED (0)` branch returned before the section could print, so a consumer whose
# machinery entries are ALL properly paired — the good state, and the state the section is written
# for — saw "every entry naming AI/DLC machinery already cites a push candidate" and nothing else,
# while `--json` carried the unplaceable list the whole time. Two renderings of one list
# disagreeing, with no error anywhere. The better the consumer behaved, the more certainly the
# section was invisible.
#
# THE `MISROUTED (0)` CONJUNCT IS THE CONTROL, not decoration: without it an arm that merely finds
# the heading would also pass from the FINDINGS branch, which is the branch that always worked.
# It has to be established that this run took the zero-findings path.
PAIRZEROBL="$CTREE/_bmad-output/backlog-paired-zero.md"
sed -e 's#and cites no push candidate\.#and is routed upstream as PC-S430-SPRINT-ID.#' \
    "$PAIRBL" >"$PAIRZEROBL"
if cmp -s "$PAIRBL" "$PAIRZEROBL"; then
  echo "FIXTURE ERROR: the zero-findings corpus is byte-identical to the paired one — the sed matched nothing and assertion 52 would run against a corpus that still has a finding" >&2
  exit 2
fi
run_txt  "$SUBJ" "$PAIRZEROBL" "$WORK/pairz.txt"  "$CTREE"; pairz_rc=$RC
pairz_txt="$(cat "$WORK/pairz.txt")"
pairz_sec="$(pair_section "$pairz_txt")"
run_json "$SUBJ" "$PAIRZEROBL" "$WORK/pairz.json" "$CTREE"; pairzj_rc=$RC
pairz_sum=""; [ "$pairzj_rc" = "0" ] && pairz_sum="$(summarize "$WORK/pairz.json")"
pairz_find="$(printf '%s' "$pairz_sum" | grep -c '^finding=' || true)"
pairz_n="$(printf '%s' "$pairz_sum" | sed -n 's/^unplaceable_n=//p')"
if [ "$pairz_rc" = "0" ] && [ "$pairzj_rc" = "0" ] \
   && has 'MISROUTED (0)' "$pairz_txt" \
   && [ "${pairz_find:-x}" = "0" ] \
   && [ -n "$pairz_sec" ] \
   && has '^  CO-S430-PAIRED-ABSENT ' "$pairz_sec" \
   && [ "${pairz_n:-x}" = "1" ]; then
  ok "PAIRED BUT UNPLACEABLE RENDERS WITH ZERO FINDINGS: a corpus whose machinery entries are all paired reports MISROUTED (0) (the control that this run took the zero-findings branch, where an early exit used to return before the section) AND still lists CO-S430-PAIRED-ABSENT, with --json agreeing at $pairz_n"
else
  bad "PAIRED BUT UNPLACEABLE with zero findings: rc=$pairz_rc/$pairzj_rc, MISROUTED(0)=$(has 'MISROUTED (0)' "$pairz_txt" && echo yes || echo NO), findings=${pairz_find:-?} (want 0), section [${pairz_sec:-ABSENT}], json=${pairz_n:-?} (want 1) — an exit in the zero-findings branch hides the section on exactly the corpus it exists for, while --json goes on carrying the list"
  show "$pairz_txt"
fi

# --- the cli cells (cells.decl): each subject run as a PROGRAM once per distinct CLI outcome ---------------------
# The router's outcomes are exit x output class: 0 with the prose report on stdout, 0 with the JSON report, 2 with the
# DISARMED refusal on stderr, 2 with the usage line on stderr. The guard exits 0 on every path, so its outcomes are
# output classes: the deny JSON on stdout, nothing. One `FXCELL=<id> bash <subject>` start per outcome, each compared
# with the in-process call on the same input: stdout, stderr and exit separately, byte for byte. A cell also asserts
# its own outcome (a positive conjunct, so two runs that both printed nothing cannot read as equivalent), and the
# classes of each subject must differ.
EQ="$WORK/eq"; mkdir -p "$EQ"
eq_cmp() { cmp -s "$EQ/$1.ip.out" "$EQ/$1.cl.out" && cmp -s "$EQ/$1.ip.err" "$EQ/$1.cl.err" && cmp -s "$EQ/$1.ip.rc" "$EQ/$1.cl.rc"; }
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(cat "$EQ/$1.ip.out")" "$(cat "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(cat "$EQ/$1.cl.out")" "$(cat "$EQ/$1.cl.err")"; }
eqv() { # <cell-id> <upr_main args...> -> $EQ/<id>.{ip,cl}.{out,err,rc}, both runs from the project root
  local id="$1"; shift
  ( cd "$ROOT" && fx_inproc "$SUBJ"; upr_main "$@" ) > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  ( cd "$ROOT" && FXCELL="$id" bash "$SUBJ" "$@" ) > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  eq_cmp "$id"
}
eqg() { # <cell-id> <project-relative path> -> $EQ/<id>.{ip,cl}.{out,err,rc}: one Write payload through the guard
  local id="$1" json
  json="$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$2")"
  printf '%s' "$json" | ( export CLAUDE_PROJECT_DIR="$GTREE"; fx_inproc "$GUARD_F"; cwg_main ) > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  printf '%s' "$json" | CLAUDE_PROJECT_DIR="$GTREE" FXCELL="$id" bash "$GUARD_F" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  eq_cmp "$id"
}
echo "cli cells"
if eqv cli-report --backlog "$MAIN" && [ "$(cat "$EQ/cli-report.cl.rc")" = 0 ] && has 'CO-S401-UNPAIRED' "$(cat "$EQ/cli-report.cl.out")" \
   && [ ! -s "$EQ/cli-report.cl.err" ]; then
  ok "cli-report: the program reports the seeded misroute exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-report: the program and the in-process call differ, or the outcome is not exit 0 naming CO-S401-UNPAIRED ($(eq_twin cli-report))"; fi
if eqv cli-json --backlog "$MAIN" --json && [ "$(cat "$EQ/cli-json.cl.rc")" = 0 ] && has '"entries"' "$(cat "$EQ/cli-json.cl.out")" \
   && [ ! -s "$EQ/cli-json.cl.err" ]; then
  ok "cli-json: the program emits the JSON report exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-json: the program and the in-process call differ, or the outcome is not exit 0 with the JSON report ($(eq_twin cli-json))"; fi
if eqv cli-refuse --backlog "$WORK/no-such-backlog.md" && [ "$(cat "$EQ/cli-refuse.cl.rc")" = 2 ] && [ ! -s "$EQ/cli-refuse.cl.out" ] \
   && has 'EXAMINED NOTHING' "$(cat "$EQ/cli-refuse.cl.err")"; then
  ok "cli-refuse: the program refuses an absent backlog exactly as the in-process call does (stdout, stderr, exit 2)"
else bad "cli-refuse: the program and the in-process call differ, or the outcome is not exit 2 with EXAMINED NOTHING on stderr ($(eq_twin cli-refuse))"; fi
if eqv cli-usage --help && [ "$(cat "$EQ/cli-usage.cl.rc")" = 2 ] && [ ! -s "$EQ/cli-usage.cl.out" ] \
   && has '^usage: audit-upstream-routing.sh' "$(cat "$EQ/cli-usage.cl.err")"; then
  ok "cli-usage: the program prints its usage line exactly as the in-process call does (stdout, stderr, exit 2)"
else bad "cli-usage: the program and the in-process call differ, or the outcome is not exit 2 with the usage line ($(eq_twin cli-usage))"; fi
if ! cmp -s "$EQ/cli-report.cl.out" "$EQ/cli-refuse.cl.out" && ! cmp -s "$EQ/cli-report.cl.rc" "$EQ/cli-refuse.cl.rc" \
   && ! cmp -s "$EQ/cli-report.cl.out" "$EQ/cli-json.cl.out" && ! cmp -s "$EQ/cli-refuse.cl.err" "$EQ/cli-usage.cl.err"; then
  ok "router cli cells discriminate: the report, the JSON, the refusal and the usage line differ in stdout, stderr or exit"
else bad "router cli cells do not discriminate: two of cli-report, cli-json, cli-refuse and cli-usage gave the same output"; fi
if eqg cli-deny "scripts/ai-dlc/core-paths.sh" && [ "$(cat "$EQ/cli-deny.cl.rc")" = 0 ] \
   && has '"permissionDecision": *"deny"' "$(cat "$EQ/cli-deny.cl.out")" && [ ! -s "$EQ/cli-deny.cl.err" ]; then
  ok "cli-deny: the guard program denies a core write exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-deny: the program and the in-process call differ, or the outcome is not exit 0 with a deny decision ($(eq_twin cli-deny))"; fi
if eqg cli-allow "src/services/billing.py" && [ "$(cat "$EQ/cli-allow.cl.rc")" = 0 ] \
   && [ ! -s "$EQ/cli-allow.cl.out" ] && [ ! -s "$EQ/cli-allow.cl.err" ]; then
  ok "cli-allow: the guard program allows a consumer write exactly as the in-process call does (nothing on stdout or stderr, exit 0)"
else bad "cli-allow: the program and the in-process call differ, or the outcome is not exit 0 with no output ($(eq_twin cli-allow))"; fi
if ! cmp -s "$EQ/cli-deny.cl.out" "$EQ/cli-allow.cl.out"; then
  ok "guard cli cells discriminate: the core write and the consumer write give different stdout"
else bad "guard cli cells do not discriminate: cli-deny and cli-allow gave the same stdout"; fi

echo ""
report_end upstream-routing "$EXPECTED_ASSERTIONS"
