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
# therefore on the OUTPUT, and every absence-shaped one carries a mutant.
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

command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 absent" >&2; exit 2; }
# `jq` is the GUARD's own dependency, not this fixture's convenience. Without it the guard reads an
# empty tool_name, falls through its `case` to `exit 0`, and ALLOWS every path — a fail-open that
# reads exactly like three-way agreement.
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq absent — the core guard cannot be driven, and a guard that cannot run allows everything" >&2; exit 2; }

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

EXPECTED_ASSERTIONS=42
fails=0; made=0
ok()   { printf '  ok    %s\n' "$1"; made=$((made+1)); }
bad()  { printf '  FAIL  %s\n' "$1"; made=$((made+1)); fails=$((fails+1)); }
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
# it finds above /var/folders — measured, and it renders as `EXAMINED NOTHING` on every mutant,
# which reads exactly like a mutation that took. Every COPY is therefore pinned with
# AI_DLC_PROJECT_ROOT; the arms exercising the REAL subject pass `-` and let it resolve, because
# that resolution is itself under test at assertions 26 and 28.
_run() { # _run <script> <backlog> <outfile> <root|-> <cwd> <txt|json>
  if [ "$6" = json ]; then
    if [ "$4" = "-" ]; then ( cd "$5" && bash "$1" --backlog "$2" --json >"$3" 2>"$3.err" )
    else ( cd "$5" && AI_DLC_PROJECT_ROOT="$4" bash "$1" --backlog "$2" --json >"$3" 2>"$3.err" ); fi
  else
    if [ "$4" = "-" ]; then ( cd "$5" && bash "$1" --backlog "$2" >"$3" 2>&1 )
    else ( cd "$5" && AI_DLC_PROJECT_ROOT="$4" bash "$1" --backlog "$2" >"$3" 2>&1 ); fi
  fi
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
# Indexed, never .get()-ed. A mutation that DELETES either key is a subject that stopped
# answering, and a default would render that as a legitimate zero — the shape of silence
# scoring as a kill. A KeyError here fails the arm loudly instead.
print("absent_named=%d" % d["absent_named"])
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
mkdir -p "$WORK/stub-all" "$WORK/stub-empty"
cp "$SUBJ" "$WORK/stub-all/audit-upstream-routing.sh"
cp "$SUBJ" "$WORK/stub-empty/audit-upstream-routing.sh"
cat >"$WORK/stub-all/core-paths.sh" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = "--list" ] && { printf '*\n'; exit 0; }
exit 2
EOF
cat >"$WORK/stub-empty/core-paths.sh" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = "--list" ] && exit 0
exit 2
EOF

run_json "$WORK/stub-all/audit-upstream-routing.sh" "$AGREE_BL" "$WORK/all.json" "$ROOT"
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
         | CLAUDE_PROJECT_DIR="$GTREE" bash "$GUARD_F" 2>/dev/null)"
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

# --- 6. the paired near-miss is NOT (absence-shaped; mutant at assertion 20) -------------------
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

# --- 10. an entry naming only CONSUMER paths is NOT reported (absence-shaped; mutant at 25) ----
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
mkdir -p "$WORK/nosib"
cp "$SUBJ" "$WORK/nosib/audit-upstream-routing.sh"
run_txt "$WORK/nosib/audit-upstream-routing.sh" "$MAIN" "$WORK/nosib.txt" "$ROOT"; nosib_rc=$RC; nosib_txt="$(cat "$WORK/nosib.txt")"
if [ "$nosib_rc" = "2" ] && has 'EXAMINED NOTHING' "$nosib_txt" && ! has 'MISROUTED' "$nosib_txt"; then
  ok "no core-paths.sh beside the subject -> exit 2 EXAMINED NOTHING, and no MISROUTED line"
else
  bad "a missing sibling gave rc=$nosib_rc — a refusal was rendered as a finding"
  show "$nosib_txt"
fi

# --- 14. `--list` produced no globs (mutant at assertion 23) ----------------------------------
run_txt "$WORK/stub-empty/audit-upstream-routing.sh" "$MAIN" "$WORK/empty.txt" "$ROOT"; empty_rc=$RC; empty_txt="$(cat "$WORK/empty.txt")"
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

# --- 16. the backlog parses to 0 entries (mutant at assertion 24) -----------------------------
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

# =============================================================================================
# 17-25. MUTANTS. Every absence-shaped arm above passes against a subject that emits nothing, so
# each one needs a mutant to mean anything. Keyed on LOCATION and observable BEHAVIOUR.
# =============================================================================================
cat >"$WORK/mutate.py" <<'PY'
import io, sys
p, a, b = sys.argv[1], sys.argv[2], sys.argv[3]
s = io.open(p, encoding="utf-8").read()
# A no-op mutation and a NON-UNIQUE anchor fail the same way: the first proves nothing, the
# second edits the arm beside the one under test and scores a kill it did not earn.
if s.count(a) != 1:
    raise SystemExit(3)
io.open(p, "w", encoding="utf-8").write(s.replace(a, b))
PY

mkmut() { # mkmut <label> <find> <replace> -> the mutant script path, or nothing on a refusal
  local d="$WORK/mut-$1"
  rm -rf "$d"; mkdir -p "$d" || return 0
  cp "$SUBJ" "$d/audit-upstream-routing.sh" || return 0
  cp "$CPATHS" "$d/core-paths.sh" || return 0
  python3 "$WORK/mutate.py" "$d/audit-upstream-routing.sh" "$2" "$3" || return 0
  cmp -s "$SUBJ" "$d/audit-upstream-routing.sh" && return 0
  printf '%s' "$d/audit-upstream-routing.sh"
}

# The reporter is not the only subject this fixture guards. `core-paths.sh` answers the
# destination-vs-file question the label above renders, and its new arm is invisible in a dormant
# tree, so it needs mutating too. Same harness, same refusals, a second subject — the mutator is
# shared as data rather than written twice, because two copies of a uniqueness control are two
# chances for one of them to stop being a control.
mkmutcp() { # mkmutcp <label> <find> <replace> -> the mutant core-paths.sh path, or nothing
  local d="$WORK/mutcp-$1"
  rm -rf "$d"; mkdir -p "$d" || return 0
  cp "$CPATHS" "$d/core-paths.sh" || return 0
  python3 "$WORK/mutate.py" "$d/core-paths.sh" "$2" "$3" || return 0
  cmp -s "$CPATHS" "$d/core-paths.sh" && return 0
  printf '%s' "$d/core-paths.sh"
}

# --- 17. the mutation harness itself refuses an anchor that is not there -----------------------
if [ -z "$(mkmut impossible 'ZZ-THIS-ANCHOR-IS-NOT-IN-THE-SUBJECT-ZZ' 'x')" ]; then
  ok "MKMUT CONTROL: an anchor that matches nothing is refused, so a no-op cannot pass as a mutation"
else
  bad "MKMUT CONTROL: an impossible anchor produced a mutant — every mutation below may be a no-op"
fi

# --- 18. the unmutated CONTROL, with a POSITIVE conjunct --------------------------------------
# rc=0-and-no-complaint is exactly what a copy that died on load produces. The conjunct is what
# separates "the harness works" from "the harness is silent".
CTL="$WORK/mut-control"
mkdir -p "$CTL"; cp "$SUBJ" "$CTL/audit-upstream-routing.sh"; cp "$CPATHS" "$CTL/core-paths.sh"
run_txt "$CTL/audit-upstream-routing.sh" "$MAIN" "$WORK/ctl.txt" "$ROOT"; ctl_rc=$RC; ctl_txt="$(cat "$WORK/ctl.txt")"
if [ "$ctl_rc" = "0" ] && has 'CO-S401-UNPAIRED' "$ctl_txt" && has 'MISROUTED (2) ' "$ctl_txt"; then
  ok "CONTROL: an UNMUTATED copy beside a copied core-paths.sh still NAMES the seeded misroute"
else
  bad "CONTROL: the unmutated copy gave rc=$ctl_rc without naming the seeded row — every mutant below scores against a broken harness"
  show "$ctl_txt"
fi

# --- 19. DISARM: the classifier examines zero entries and still reports a clean 0 --------------
# THE SHAPE THAT MATTERS. It exits 0, prints `MISROUTED (0)`, and still reports the corpus as
# examined — indistinguishable from a correctly-routed tree to anything that reads only the exit
# code or the headline. It is caught because every arm above is PRESENCE-shaped.
M_DISARM="$(mkmut disarm 'for cid, ln, body in entries:' 'for cid, ln, body in []:')"
if [ -z "$M_DISARM" ]; then
  bad "MUTANT disarm: the anchor matched nothing — the disarm is unbuilt and the presence arms prove nothing"
else
  run_txt "$M_DISARM" "$MAIN" "$WORK/disarm.txt" "$ROOT"; d_rc=$RC; d_txt="$(cat "$WORK/disarm.txt")"
  if [ "$d_rc" = "0" ] && has 'MISROUTED (0)' "$d_txt" && ! has 'CO-S401-UNPAIRED' "$d_txt"; then
    ok "MUTANT disarm: a classifier examining nothing prints a clean MISROUTED (0) at exit 0 and is caught only by the presence arms"
  else
    bad "MUTANT disarm: rc=$d_rc and the seeded row survived — the disarm did not take, so the presence arms are untested"
    show "$d_txt"
  fi
fi

# --- 20. the pairing discriminator removed (assertion 6 is live) -------------------------------
M_PAIR="$(mkmut pair '    if PC.search(body):' '    if False:')"
if [ -z "$M_PAIR" ]; then
  bad "MUTANT pair: the anchor matched nothing — assertion 6 proves nothing"
else
  run_json "$M_PAIR" "$MAIN" "$WORK/pair.json" "$ROOT"; p_rc=$RC
  p_sum=""; [ "$p_rc" = "0" ] && p_sum="$(summarize "$WORK/pair.json")"
  if has '^finding=CO-S401-PAIRED$' "$p_sum"; then
    ok "MUTANT pair: without the PC- skip the near-miss IS reported — so assertion 6 discriminates on the citation"
  else
    bad "MUTANT pair: the near-miss stayed unreported with the discriminator gone — assertion 6 passes whatever the subject does"
  fi
fi

# --- 21. the heading grammar loses the bracket alternative (assertion 8 is live) ---------------
M_HEAD="$(mkmut head 'HEAD = re.compile(r"^#{2,4}\s+\[?(CO-[A-Z0-9][A-Z0-9.-]*)\]?")' \
                     'HEAD = re.compile(r"^#{2,4}\s+(CO-[A-Z0-9][A-Z0-9.-]*)")')"
if [ -z "$M_HEAD" ]; then
  bad "MUTANT head: the anchor matched nothing — assertion 8 proves nothing"
else
  run_json "$M_HEAD" "$MAIN" "$WORK/head.json" "$ROOT"; h_rc=$RC
  h_sum=""; [ "$h_rc" = "0" ] && h_sum="$(summarize "$WORK/head.json")"
  if ! has '^finding=CO-S402-BRACKET$' "$h_sum" && has '^finding=CO-S401-UNPAIRED$' "$h_sum"; then
    ok "MUTANT head: a grammar knowing only \`### CO-\` drops the bracketed entry while still reporting the other — so assertion 8 is a statement about the SHAPE"
  else
    bad "MUTANT head: the bracketed entry survived a grammar that cannot spell it — assertion 8 is vacuous"
    show "$h_sum"
  fi
fi

# --- 22. the predicate widened to match every path (assertion 10 is live) ----------------------
# Widened, not narrowed: a mutation that makes a guard match NOTHING often reproduces the
# original's output and scores a kill it did not earn. This one has a positive observable — the
# consumer-only entry APPEARS.
M_WIDE="$(mkmut wide '        if any(fnmatch.fnmatch(p, g) for g in globs):' '        if True:')"
if [ -z "$M_WIDE" ]; then
  bad "MUTANT wide: the anchor matched nothing — assertion 10 proves nothing"
else
  run_json "$M_WIDE" "$MAIN" "$WORK/wide.json" "$ROOT"; w_rc=$RC
  w_sum=""; [ "$w_rc" = "0" ] && w_sum="$(summarize "$WORK/wide.json")"
  if has '^finding=CO-S403-CONSUMER$' "$w_sum"; then
    ok "MUTANT wide: with the glob test gone the consumer-only entry IS convicted — so assertion 10 is a statement about the predicate"
  else
    bad "MUTANT wide: the consumer-only entry stayed clean with the predicate matching everything — assertion 10 is vacuous"
  fi
fi

# --- 23. the empty-glob refusal removed (assertion 14 is live) --------------------------------
# The mutant runs beside the EMPTY stub, so the arm being tested is the refusal and not the
# glob set: without the guard the subject sails past a dead predicate into a clean report.
M_GLOB="$(mkmut glob 'if [ -z "$GLOBS" ]; then' 'if [ -z "${GLOBS}x" ]; then')"
if [ -z "$M_GLOB" ]; then
  bad "MUTANT glob: the anchor matched nothing — assertion 14 proves nothing"
else
  cp "$WORK/stub-empty/core-paths.sh" "$(dirname "$M_GLOB")/core-paths.sh"
  run_txt "$M_GLOB" "$MAIN" "$WORK/mglob.txt" "$ROOT"; g_rc=$RC; g_txt="$(cat "$WORK/mglob.txt")"
  if [ "$g_rc" = "0" ] && has 'MISROUTED (0)' "$g_txt"; then
    ok "MUTANT glob: without the refusal an EMPTY glob set yields a confident MISROUTED (0) at exit 0 — so assertion 14 is what stops a dead predicate reading clean"
  else
    bad "MUTANT glob: rc=$g_rc with the refusal removed — assertion 14 is vacuous"
    show "$g_txt"
  fi
fi

# --- 24. the zero-entries refusal removed (assertion 16 is live) ------------------------------
M_ENT="$(mkmut entries 'if not entries:' 'if False:')"
if [ -z "$M_ENT" ]; then
  bad "MUTANT entries: the anchor matched nothing — assertion 16 proves nothing"
else
  run_txt "$M_ENT" "$ZERO" "$WORK/ment.txt" "$ROOT"; e_rc=$RC; e_txt="$(cat "$WORK/ment.txt")"
  if [ "$e_rc" = "0" ] && has 'MISROUTED (0)' "$e_txt"; then
    ok "MUTANT entries: without the refusal an unparseable backlog reports MISROUTED (0) at exit 0 — so assertion 16 is live"
  else
    bad "MUTANT entries: rc=$e_rc with the refusal removed — assertion 16 is vacuous"
    show "$e_txt"
  fi
fi

# --- 25. report-only turned into a gate (assertion 11 is live) --------------------------------
# The anchor is the two-line tail, not the bare `exit 0`: the shell tail and the Python
# `SystemExit(0)` calls are different exits, and an anchor on the shared spelling would move a
# cell this arm does not own.
M_EXIT="$(mkmut exitcode '[ "$rc" = 2 ] && exit 2
exit 0' '[ "$rc" = 2 ] && exit 2
exit 1')"
if [ -z "$M_EXIT" ]; then
  bad "MUTANT exitcode: the anchor matched nothing — assertion 11 proves nothing"
else
  run_txt "$M_EXIT" "$MAIN" "$WORK/mexit.txt" "$ROOT"; x_rc=$RC; x_txt="$(cat "$WORK/mexit.txt")"
  if [ "$x_rc" = "1" ] && has 'MISROUTED (2) ' "$x_txt"; then
    ok "MUTANT exitcode: a reporter turned into a gate exits 1 on the same findings — so assertion 11 pins the report-only contract"
  else
    bad "MUTANT exitcode: rc=$x_rc — assertion 11 does not actually read the exit code"
    show "$x_txt"
  fi
fi

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
# tree — which is exactly how a mutation replay drives this fixture — refuses on both sides for a
# reason that has nothing to do with cwd. Measured: six unrelated mutants all reported a
# cwd-dependence that was an artifact of the harness. Pinning loses nothing real, because for an
# in-tree subject the walk-up from its own directory always wins before cwd is ever consulted.
#
# The subdirectory is THIS fixture's own directory: it exists in both install layouts, it is
# always under the root, and it is deep enough that `--list`'s relative candidates cannot resolve
# from it — which is the condition the mutation at assertion 27 restores.
SUBDIR="$HERE"
run_json "$SUBJ" "$MAIN" "$WORK/cwd-root.json" "$ROOT" "$ROOT";   cwd_root_rc=$RC
run_json "$SUBJ" "$MAIN" "$WORK/cwd-sub.json"  "$ROOT" "$SUBDIR"; cwd_sub_rc=$RC
if [ "$cwd_root_rc" = "0" ] && [ "$cwd_sub_rc" = "0" ] && cmp -s "$WORK/cwd-root.json" "$WORK/cwd-sub.json"; then
  ok "CWD-INVARIANT: byte-identical reports from the project root and from $(basename "$SUBDIR")/"
else
  bad "CWD-INVARIANT: root rc=$cwd_root_rc, subdir rc=$cwd_sub_rc, reports differ — the predicate depends on where the tool was invoked"
  show "$(diff "$WORK/cwd-root.json" "$WORK/cwd-sub.json" 2>&1 | head -20)"
fi

# --- 27. MUTANT: the manifest handed back to the cwd (assertion 26 is live) --------------------
# The mutation restores the measured old behaviour exactly — `--list` with no manifest argument.
# From the root it still answers; from the subdirectory it yields no globs and refuses. That
# asymmetry is the whole content of assertion 26, and nothing else in this battery can see it.
M_CWD="$(mkmut cwd 'GLOBS="$(bash "$CORE_PATHS" --list "$MANIFEST" 2>/dev/null || true)"' \
                   'GLOBS="$(bash "$CORE_PATHS" --list 2>/dev/null || true)"')"
if [ -z "$M_CWD" ]; then
  bad "MUTANT cwd: the anchor matched nothing — assertion 26 proves nothing"
else
  run_json "$M_CWD" "$MAIN" "$WORK/mcwd-root.json" "$ROOT" "$ROOT";   mc_root_rc=$RC
  run_json "$M_CWD" "$MAIN" "$WORK/mcwd-sub.json"  "$ROOT" "$SUBDIR"; mc_sub_rc=$RC
  if [ "$mc_root_rc" = "0" ] && [ "$mc_sub_rc" = "2" ]; then
    ok "MUTANT cwd: with the manifest unpassed the SAME tree answers from the root (rc=0) and refuses from a subdirectory (rc=2) — so assertion 26 pins the resolution"
  else
    bad "MUTANT cwd: root rc=$mc_root_rc, subdir rc=$mc_sub_rc — assertion 26 is vacuous"
  fi
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

# --- 29. MUTANT: the manifest refusal removed (assertion 28 is live) ---------------------------
# Without the refusal the empty MANIFEST reaches `--list` as an empty argument and that script
# falls back to its cwd-relative candidates, so a tree with NO manifest produces a full,
# confident report borrowed from wherever the process happened to be standing.
M_MAN="$(mkmut manifest 'if [ -z "$MANIFEST" ]; then' 'if [ -z "${MANIFEST}x" ]; then')"
if [ -z "$M_MAN" ]; then
  bad "MUTANT manifest: the anchor matched nothing — assertion 28 proves nothing"
else
  run_txt "$M_MAN" "$MAIN" "$WORK/mman.txt" "$WORK/emptyroot" "$ROOT"; mm_rc=$RC
  mm_txt="$(cat "$WORK/mman.txt")"
  if [ "$mm_rc" = "0" ] && has 'MISROUTED (2) ' "$mm_txt"; then
    ok "MUTANT manifest: without the refusal a manifest-less root reports on globs borrowed from the cwd — so assertion 28 is what stops it"
  else
    bad "MUTANT manifest: rc=$mm_rc with the refusal removed — assertion 28 is vacuous"
    show "$mm_txt"
  fi
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
# assertions 3-4 and 31 are what would have caught it.
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
# second one — and every one has a mutant, because a near-miss establishes that an arm
# DISCRIMINATES and only a mutant establishes that it fires at all.
# =============================================================================================

# --- 30. CONTROL: the core-paths mutator refuses an anchor that matches nothing ---------------
# The second subject gets its own harness, so it gets its own control. A replacement that matched
# nothing produces an unmutated copy, and an unmutated copy passes assertion 31 — a mutation that
# killed nothing reads exactly like an arm that cannot fire.
if [ -z "$(mkmutcp impossible 'ZZ-NOT-IN-THE-SUBJECT-ZZ' 'x')" ] \
   && [ -n "$(mkmutcp control 'REL="${TARGET#./}"' 'REL="${TARGET#./}" # control')" ]; then
  ok "CONTROL: mkmutcp refuses an anchor present 0 times and accepts one present exactly once — assertion 31 scores against a real mutation"
else
  bad "CONTROL: mkmutcp accepted an impossible anchor or refused a real one — assertion 31's mutant is unscored"
fi

# --- 31. MUTANT: v0.457.0's `--is-core` re-applied (assertions 3-4 are live) ------------------
# THE ARM THAT WOULD HAVE CAUGHT THE RELEASE THIS ONE CORRECTS, scored rather than argued about.
# The mutation restores the reverted decision fork verbatim — walk up from $PWD for the layered
# activation elements, then refuse a matched path naming no file. Only the exit is restored; the
# diagnostic echoes that went with it move no verdict.
#
# IT MUST SPLIT THE PARTIES ON EXACTLY THE INVENTED PATH. Every other seeded path is on disk in
# $GTREE, so a mutant moving more than one verdict is a broken mutation and not a caught defect,
# and this arm fails on that too rather than reading a bigger number as a better kill. The
# comparison replayed here IS assertion 3's, three routes and all, so what it demonstrates is that
# assertion 3 goes red — not merely that the resolver changed its mind.
#
# THE FRAGMENTS GO THROUGH FILES, NOT `$(cat <<'X')`. A quoted heredoc nested inside a command
# substitution does NOT reliably suppress expansion in bash 3.2 when its body itself contains
# `$( )` — measured here: the `_d="$(dirname "$_d")"` line below made the whole body expand, and
# `set -u` then killed the run on `LAYERED_ROOT` at the closing paren, four lines past anything
# that names it. At top level the same heredoc is literal.
cat >"$WORK/m457.find" <<'M457A'
REL="${TARGET#./}"

while IFS= read -r g; do
  [ -n "$g" ] || continue
  # shellcheck disable=SC2254
  case "$REL" in
M457A
cat >"$WORK/m457.repl" <<'M457B'
REL="${TARGET#./}"

LAYERED_ROOT=""
if [ "$MODE" = "--is-core" ]; then
  _d="$PWD"
  while [ -n "$_d" ] && [ "$_d" != "/" ]; do
    if [ -f "$_d/.claude/.ai-dlc-version" ] \
       && [ -d "$_d/.claude/skills/ai-dlc/overrides" ] \
       && [ -d "$_d/.claude/skills/ai-dlc/extensions" ]; then
      LAYERED_ROOT="$_d"; break
    fi
    _d="$(dirname "$_d")"
  done
fi

while IFS= read -r g; do
  [ -n "$g" ] || continue
  # shellcheck disable=SC2254
  case "$REL" in
    $g) [ -n "$LAYERED_ROOT" ] && [ ! -e "${LAYERED_ROOT}/${REL}" ] && exit 2 ;;
  esac
  case "$REL" in
M457B
# The heredocs above are LITERAL, so a body that expanded is a fixture defect and not a finding.
# `$MODE` names a variable this fixture never sets, which makes it the cheapest tell.
if ! grep -q 'MODE' "$WORK/m457.repl"; then
  echo "FIXTURE ERROR: the mutation fragment expanded instead of staying literal — assertion 31 would score a mutation nobody wrote" >&2
  exit 2
fi
M457="$(mkmutcp is457 "$(cat "$WORK/m457.find")" "$(cat "$WORK/m457.repl")")"
if [ -z "$M457" ]; then
  bad "MUTANT is457: the anchor matched nothing — assertions 3-4 prove nothing"
else
  m457_dis=""; m457_ref=0
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    ( cd "$GTREE" && bash "$M457" --is-core "$p" "$MANIFEST_F" >/dev/null 2>&1 ); m_rc=$?
    case "$m_rc" in
      0) m_says=core ;;
      1) m_says=not-core ;;
      *) m_says="refused($m_rc)"; m457_ref=$((m457_ref+1)) ;;
    esac
    if has "^path=CO-S400-AGREE[0-9]* ${p}\$" "$inproc"; then mi_says=core; else mi_says=not-core; fi
    if [ "$(guard_verdict "$p")" = "deny" ]; then mg_says=core; else mg_says=not-core; fi
    if [ "$mi_says" != "$m_says" ] || [ "$mi_says" != "$mg_says" ]; then
      m457_dis="${m457_dis}${p}: in-process=${mi_says} --is-core=${m_says} guard=${mg_says}
"
    fi
  done <<EOF
$AGREE_PATHS
EOF
  m457_n="$(printf '%s' "$m457_dis" | grep -c . || true)"
  if [ "$m457_n" = "1" ] && [ "$m457_ref" = "1" ] && has "^${INVENTED}: " "$m457_dis"; then
    ok "MUTANT is457: re-applying v0.457.0's \`--is-core\` splits the resolver from the guard on EXACTLY the invented path, which the guard still DENIES — so assertion 3 is what catches a fork at the DECISION, the fork I25 cannot see because it byte-compares only parse_manifest() and to_consumer_glob()"
  else
    bad "MUTANT is457: $m457_n disagreement(s) and $m457_ref refusal(s), want exactly 1 of each on $INVENTED — assertion 3 is vacuous or the mutation was not surgical: ${m457_dis:-none}"
  fi
fi

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

# --- 37. MUTANT: existence never checked (assertion 32's FIRES direction is live) -------------
# The label stops appearing and everything else about the report is unchanged, which is exactly
# what a broken label looks like from the outside. The positive conjunct — the finding is still
# named — is what stops a subject that emits NOTHING from scoring as a kill here.
M_EXT="$(mkmut existstrue '"exists": True if root is None else os.path.exists(os.path.join(root, p))' '"exists": True')"
if [ -z "$M_EXT" ]; then
  bad "MUTANT existstrue: the anchor matched nothing — assertion 32 proves nothing"
else
  run_txt "$M_EXT" "$ABSBL" "$WORK/mext.txt" "$CTREE"; mext_rc=$RC
  mext_txt="$(cat "$WORK/mext.txt")"
  if [ "$mext_rc" = "0" ] && has 'CO-S410-ABSENTONLY' "$mext_txt" \
     && ! has 'NO SUCH FILE HERE' "$mext_txt"; then
    ok "MUTANT existstrue: with existence hardcoded true the absent path renders unmarked while the finding is still reported — so assertion 32 is what makes the label fire"
  else
    bad "MUTANT existstrue: rc=$mext_rc, marker still present or the finding vanished — assertion 32's fires-direction is vacuous"
    show "$mext_txt"
  fi
fi

# --- 38. MUTANT: everything marked absent (assertion 32's SILENT direction is live) -----------
# The mirror, and the one that a fires-only arm cannot catch: a label that flags EVERY path reads
# identically to one that discriminates, unless something asserts the near-miss stays quiet.
M_EXF="$(mkmut existsfalse '"exists": True if root is None else os.path.exists(os.path.join(root, p))' '"exists": False')"
if [ -z "$M_EXF" ]; then
  bad "MUTANT existsfalse: the anchor matched nothing — assertion 32 proves nothing"
else
  run_txt "$M_EXF" "$ABSBL" "$WORK/mexf.txt" "$CTREE"; mexf_rc=$RC
  mexf_txt="$(cat "$WORK/mexf.txt")"
  if [ "$mexf_rc" = "0" ] \
     && has '^      names: scripts/ai-dlc/core-paths\.sh   \[NO SUCH FILE HERE\]$' "$mexf_txt"; then
    ok "MUTANT existsfalse: with existence hardcoded false the PRESENT path is marked too — so assertion 32's near-miss is what stops a label that flags everything"
  else
    bad "MUTANT existsfalse: rc=$mexf_rc and the present path stayed unmarked — assertion 32's silent-direction is vacuous"
    show "$mexf_txt"
  fi
fi

# --- 39. MUTANT: the label turned into a filter (assertion 33 is live) ------------------------
# The "improvement" assertion 33 exists to catch, built and scored rather than argued about: skip
# an entry whose named machinery is not on disk. CO-S410-MIXED survives with its marker intact, so
# this mutant fails assertion 33 and ONLY assertion 33 — the acquittal is the whole finding.
M_FIL="$(mkmut absentfilter \
  '    absent_total += sum(1 for r in rows if not r["exists"])' \
  '    absent_total += sum(1 for r in rows if not r["exists"])
    if not any(r["exists"] for r in rows): continue')"
if [ -z "$M_FIL" ]; then
  bad "MUTANT absentfilter: the anchor matched nothing — assertion 33 proves nothing"
else
  run_json "$M_FIL" "$ABSBL" "$WORK/mfil.json" "$CTREE"; mfil_rc=$RC
  mfil_ids=""; [ "$mfil_rc" = "0" ] && mfil_ids="$(summarize "$WORK/mfil.json" | grep '^finding=' || true)"
  if [ "$mfil_rc" = "0" ] && ! has '^finding=CO-S410-ABSENTONLY$' "$mfil_ids" \
     && has '^finding=CO-S410-MIXED$' "$mfil_ids" \
     && has '^finding=CO-S410-PRESENT$' "$mfil_ids"; then
    ok "MUTANT absentfilter: filtering on existence ACQUITS the entry whose only machinery path is absent while the other two survive — so assertion 33 is what keeps a true misroute reportable"
  else
    bad "MUTANT absentfilter: rc=$mfil_rc, ids [$(echo "$mfil_ids" | tr '\n' ' ')] — assertion 33 is vacuous"
  fi
fi

# --- 40. MUTANT: absent_named decoupled from the text (assertion 34 is live) ------------------
# The text still marks the rows and only the JSON total lies, which is the failure a single-value
# read could never see — and the reason assertion 34 derives the count twice instead of once.
M_CNT="$(mkmut absentcount '"absent_named": absent_total,' '"absent_named": 0,')"
if [ -z "$M_CNT" ]; then
  bad "MUTANT absentcount: the anchor matched nothing — assertion 34 proves nothing"
else
  run_json "$M_CNT" "$ABSBL" "$WORK/mcnt.json" "$CTREE"; mcnt_rc=$RC
  mcnt_absent=""; [ "$mcnt_rc" = "0" ] && mcnt_absent="$(summarize "$WORK/mcnt.json" | sed -n 's/^absent_named=//p')"
  mcnt_named=""; [ "$mcnt_rc" = "0" ] && mcnt_named="$(summarize "$WORK/mcnt.json" | grep '^named=.* absent$' || true)"
  if [ "$mcnt_rc" = "0" ] && [ "$mcnt_absent" = "0" ] && [ -n "$mcnt_named" ]; then
    ok "MUTANT absentcount: the JSON total reads 0 while named[] still carries absent rows — so assertion 34's two derivations are what bind the count to the rendering"
  else
    bad "MUTANT absentcount: rc=$mcnt_rc, absent_named=$mcnt_absent, absent named[] rows [${mcnt_named:-none}] — assertion 34 is vacuous"
  fi
fi

# --- 41. MUTANT: the root re-keyed to the RUNNING COPY (assertion 35 is live) -----------------
# `v0.457.0`'s exact spelling, restored: ask AI_DLC_ROOT instead of walking up from the backlog.
# Under it the two runs of the SAME corpus diverge — the tree with the files reports them present,
# the tree without reports them absent — which is the shipped false positive reproduced in one
# line. The conjunct naming the PRESENT path is what makes this a kill rather than a coincidence:
# a mutant that merely crashed would also make the reports differ.
M_ROOTENV="$(mkmut rootenv 'root = backlog_root(backlog)' 'root = os.environ["AI_DLC_ROOT"]')"
if [ -z "$M_ROOTENV" ]; then
  bad "MUTANT rootenv: the anchor matched nothing — assertion 35 proves nothing"
else
  run_json "$M_ROOTENV" "$ABSBL" "$WORK/mroot-c.json" "$CTREE"; mrootc_rc=$RC
  run_json "$M_ROOTENV" "$ABSBL" "$WORK/mroot-o.json" "$OTHER"; mrooto_rc=$RC
  mrooto_present=""; mrootc_present=""
  [ "$mrooto_rc" = "0" ] && mrooto_present="$(summarize "$WORK/mroot-o.json" | grep '^named=.* present$' || true)"
  [ "$mrootc_rc" = "0" ] && mrootc_present="$(summarize "$WORK/mroot-c.json" | grep '^named=.* present$' || true)"
  if [ "$mrootc_rc" = "0" ] && [ "$mrooto_rc" = "0" ] \
     && ! cmp -s "$WORK/mroot-c.json" "$WORK/mroot-o.json" \
     && [ -n "$mrootc_present" ] && [ -z "$mrooto_present" ]; then
    ok "MUTANT rootenv: keying existence on the RUNNING COPY's root makes one corpus render two ways — every path present from the tree that holds them, NONE present from the tree that does not — so assertion 35 is what pins the label to the backlog's tree"
  else
    bad "MUTANT rootenv: rc=$mrootc_rc/$mrooto_rc, reports $(cmp -s "$WORK/mroot-c.json" "$WORK/mroot-o.json" && echo identical || echo differing), present rows CTREE [${mrootc_present:-none}] OTHER [${mrooto_present:-none}] — assertion 35 is vacuous"
  fi
fi

# --- 42. MUTANT: an unplaceable corpus given a root anyway (assertion 36 is live) -------------
# The walk terminates at `/` and returns it instead of refusing, so the unrootable backlog gets a
# root where nothing exists and every path is labelled absent. This is the failure assertion 36's
# no-labels conjunct owns; the findings-unchanged conjunct survives it, which is correct — the two
# conjuncts are there for different failures and only one of them is this mutant's.
M_ROOTANY="$(mkmut rootany '        if parent == d:
            return None' '        if parent == d:
            return d')"
if [ -z "$M_ROOTANY" ]; then
  bad "MUTANT rootany: the anchor matched nothing — assertion 36 proves nothing"
else
  run_txt "$M_ROOTANY" "$UNROOTBL" "$WORK/mrany.txt" "$CTREE"; mrany_rc=$RC
  mrany_txt="$(cat "$WORK/mrany.txt")"
  if [ "$mrany_rc" = "0" ] && has 'NO SUCH FILE HERE' "$mrany_txt" \
     && has 'CO-S410-ABSENTONLY' "$mrany_txt"; then
    ok "MUTANT rootany: returning a root rather than refusing labels the unplaceable corpus after all, while the findings still report — so assertion 36's no-labels conjunct is what keeps an unasked question from rendering as an answer"
  else
    bad "MUTANT rootany: rc=$mrany_rc, marker absent or the findings vanished — assertion 36 is vacuous"
    show "$mrany_txt"
  fi
fi


echo ""
if [ "$made" -ne "$EXPECTED_ASSERTIONS" ]; then
  echo "upstream-routing: FAIL — $made assertions ran, $EXPECTED_ASSERTIONS were written. One did not execute at all, which is not the same as one that passed."
  exit 1
fi
if [ "$fails" -eq 0 ]; then echo "upstream-routing: PASS ($made assertions)"; exit 0; fi
echo "upstream-routing: FAIL ($fails of $made)"; exit 1
