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

command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 absent" >&2; exit 2; }

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

EXPECTED_ASSERTIONS=29
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
for f in d["findings"]:
    print("finding=%s" % f["id"])
    for p in f["paths"]:
        print("path=%s %s" % (f["id"], p))
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
# 2-4. AGREEMENT WITH THE SHIPPING PREDICATE. The subject matches in-process against
# `--list`; `core-paths.sh --is-core` matches with a shell `case`. Nothing in either program
# makes them agree, and the subject's header banks the equivalence as measured. These arms carry
# that measurement forward so the two cannot drift apart silently.
# =============================================================================================
AGREE_PATHS='scripts/ai-dlc/core-paths.sh
.claude/hooks/ai-dlc-core-guard.sh
.claude/skills/ai-dlc/SKILL.md
.claude/skills/ai-dlc/steps/gate-validation.md
.claude/team-roles/dev.md
tests/fixtures/check-15-bypass/run.sh
.claude/skills/ai-dlc/overrides/gate-validation.md
scripts/ai-dlc-local/my-tool.sh
docs/architecture/decisions.md
src/services/billing.py'

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

# --- 3. AGREEMENT: in-process matching vs per-path `--is-core`, zero disagreements ------------
run_json "$SUBJ" "$AGREE_BL" "$WORK/agree.json"; agree_rc=$RC
inproc=""
if [ "$agree_rc" = "0" ]; then
  inproc="$(summarize "$WORK/agree.json")"
fi
disagree=""; n_core=0; n_not=0; n_refused=0
while IFS= read -r p; do
  [ -n "$p" ] || continue
  ( cd "$ROOT" && bash "$CPATHS" --is-core "$p" >/dev/null 2>&1 ); is_rc=$?
  if has "^path=CO-S400-AGREE[0-9]* ${p}\$" "$inproc"; then in_says=core; else in_says=not-core; fi
  case "$is_rc" in
    0) is_says=core ;;
    1) is_says=not-core ;;
    *) is_says="refused($is_rc)"; n_refused=$((n_refused+1)) ;;
  esac
  [ "$is_says" = core ]     && n_core=$((n_core+1))
  [ "$is_says" = not-core ] && n_not=$((n_not+1))
  [ "$in_says" = "$is_says" ] || disagree="${disagree}${p}: in-process=${in_says} --is-core=${is_says}
"
done <<EOF
$AGREE_PATHS
EOF

if [ "$agree_rc" = "0" ] && [ "$n_refused" = "0" ] && [ -z "$disagree" ]; then
  ok "AGREEMENT: in-process matching and per-path \`--is-core\` agree on every seeded path"
else
  bad "AGREEMENT: rc=$agree_rc, $n_refused refusals, and the two routes disagreed — the subject's --list optimisation has drifted from the shipping resolver:"
  show "$disagree"
fi

# --- 4. and it DISCRIMINATES. Two routes that both answer `core` to everything also agree ------
if [ "$n_core" -gt 0 ] && [ "$n_not" -gt 0 ]; then
  ok "AGREEMENT DISCRIMINATES: the seeded set contains both classes ($n_core core, $n_not not-core)"
else
  bad "AGREEMENT DISCRIMINATES: the seeded set resolved to $n_core core / $n_not not-core — a one-class set makes assertion 3 vacuous"
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
mkmut() { # mkmut <label> <find> <replace> -> the mutant script path, or nothing on a refusal
  local d="$WORK/mut-$1"
  rm -rf "$d"; mkdir -p "$d" || return 0
  cp "$SUBJ" "$d/audit-upstream-routing.sh" || return 0
  cp "$CPATHS" "$d/core-paths.sh" || return 0
  python3 - "$d/audit-upstream-routing.sh" "$2" "$3" <<'PY' || return 0
import io, sys
p, a, b = sys.argv[1], sys.argv[2], sys.argv[3]
s = io.open(p, encoding="utf-8").read()
# A no-op mutation and a NON-UNIQUE anchor fail the same way: the first proves nothing, the
# second edits the arm beside the one under test and scores a kill it did not earn.
if s.count(a) != 1:
    raise SystemExit(3)
io.open(p, "w", encoding="utf-8").write(s.replace(a, b))
PY
  cmp -s "$SUBJ" "$d/audit-upstream-routing.sh" && return 0
  printf '%s' "$d/audit-upstream-routing.sh"
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

echo ""
if [ "$made" -ne "$EXPECTED_ASSERTIONS" ]; then
  echo "upstream-routing: FAIL — $made assertions ran, $EXPECTED_ASSERTIONS were written. One did not execute at all, which is not the same as one that passed."
  exit 1
fi
if [ "$fails" -eq 0 ]; then echo "upstream-routing: PASS ($made assertions)"; exit 0; fi
echo "upstream-routing: FAIL ($fails of $made)"; exit 1
