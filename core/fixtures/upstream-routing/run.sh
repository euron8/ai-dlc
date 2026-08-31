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

command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 absent" >&2; exit 2; }

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

EXPECTED_ASSERTIONS=44
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
# 30-44. A GLOB MATCH IS EVIDENCE ABOUT A DESTINATION, NEVER ABOUT A FILE.
#
# Two subjects, one defect. `core-paths.sh --is-core` used to answer 0 for any path matching a
# core glob whether or not a file was there, and `scripts/ai-dlc/*` is a whole namespace, so an
# invented filename answered "core". It now exits 2 for a matched path naming no file — on a
# LAYERED consumer only. Beside it, the reporter LABELS such a path `[NO SUCH FILE HERE]` and
# deliberately does NOT filter it, because on the reference consumer both absent paths belonged
# upstream and a filter would have acquitted a true misroute.
#
# BOTH HALVES FAIL SILENTLY. The label simply stops appearing, which reads like a corpus with
# nothing absent in it; and the resolver's new answer is INVISIBLE in any tree that is dormant,
# which is every tree this fixture ran in before today. So every arm below carries its opposite
# in the same run — a seeded offender AND a seeded near-miss, a layered sandbox AND a dormant
# one — and every one of them has a mutant, because a near-miss establishes that an arm
# DISCRIMINATES and only a mutant establishes that it fires at all.
# =============================================================================================

# --- 30. ASSERTION 3's PREMISE: the tree it asks `--is-core` in is DORMANT --------------------
# A TRAP ARM 3 WILL HIT, WRITTEN BEFORE IT DOES. That assertion cross-checks in-process `--list`
# matching against per-path `--is-core` and counts any exit other than 0 or 1 as a refusal, which
# it fails on. On a LAYERED tree those two now legitimately DISAGREE for a path that matches a
# glob and names no file: `--list` still emits the glob, `--is-core` answers 2. Every path in
# AGREE_PATHS is exactly that shape here — `scripts/ai-dlc/core-paths.sh` is a core DESTINATION
# and the distribution keeps the file at `core/scripts/`, so no consumer-relative core path is on
# disk. Assertion 3 survives only because $ROOT is dormant. Pin that dependency, so a future
# author who layers this sandbox gets a named failure instead of a mystery.
#
# The second probe is the CONTROL and it is in the same invocation set: a non-core path must come
# back 1. Without it a 0 on the first probe cannot be told from a dead predicate — a resolver that
# classified nothing would answer 0 for a matched path too, having matched none.
( cd "$ROOT" && bash "$CPATHS" --is-core scripts/ai-dlc/core-paths.sh "$MANIFEST_F" >/dev/null 2>&1 ); prem_core=$?
( cd "$ROOT" && bash "$CPATHS" --is-core docs/architecture/decisions.md "$MANIFEST_F" >/dev/null 2>&1 ); prem_not=$?
if [ "$prem_core" = "0" ] && [ "$prem_not" = "1" ]; then
  ok "ASSERTION 3's PREMISE: \$ROOT is DORMANT — an absent core destination answers 0, not 2 (control, same invocation set: a non-core path answers 1, so the resolver ran and discriminated)"
elif [ "$prem_core" = "2" ]; then
  bad "ASSERTION 3's PREMISE IS GONE: \$ROOT now resolves as a LAYERED consumer, so --is-core answers 2 for the absent core destinations in AGREE_PATHS and assertion 3 counts them as refusals. Assertion 3 is what needs changing, not this one"
else
  bad "ASSERTION 3's PREMISE: core destination rc=$prem_core (want 0), non-core rc=$prem_not (want 1) — the resolver did not discriminate, so neither arm measures anything"
fi

# --- the label sandbox: one tree, one corpus, present and absent side by side -----------------
# THE PAIR MUST SHARE A RUN AND A CORPUS. A near-miss measured in a SEPARATE run is an ADJACENT
# input: it can only ask whether the label fires at all, never whether it fires on the RIGHT path.
# So CO-S410-MIXED names one present path and one absent path IN THE SAME ENTRY, and both come
# from the SAME glob (`scripts/ai-dlc/*`) — the two probes differ in exactly one property, which
# is the one under test.
EXTREE="$WORK/exists-tree"
mkdir -p "$EXTREE/.claude/skills/ai-dlc" "$EXTREE/scripts/ai-dlc"
cp "$MANIFEST_F" "$EXTREE/.claude/skills/ai-dlc/core-manifest.md"
: > "$EXTREE/scripts/ai-dlc/core-paths.sh"
: > "$EXTREE/scripts/ai-dlc/verdict-lib.sh"

ABSBL="$WORK/backlog-absent.md"
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
PRESBL="$WORK/backlog-allpresent.md"
sed -e 's#scripts/ai-dlc/merge-gate-verdicts\.sh#scripts/ai-dlc/verdict-lib.sh#' \
    -e 's#scripts/ai-dlc/never-shipped-by-anyone\.sh#scripts/ai-dlc/verdict-lib.sh#' \
    "$ABSBL" >"$PRESBL"
if cmp -s "$ABSBL" "$PRESBL"; then
  echo "FIXTURE ERROR: the all-present corpus is byte-identical to the absent one — the sed matched nothing and assertion 32 would compare a corpus with itself" >&2
  exit 2
fi

run_txt  "$SUBJ" "$ABSBL"  "$WORK/abs.txt"  "$EXTREE"; abs_rc=$RC
abs_txt="$(cat "$WORK/abs.txt")"
run_json "$SUBJ" "$ABSBL"  "$WORK/abs.json"  "$EXTREE"; absj_rc=$RC
run_json "$SUBJ" "$PRESBL" "$WORK/pres.json" "$EXTREE"; presj_rc=$RC

# --- 31. the label FIRES on the absent path and STAYS SILENT on the present one ---------------
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

# --- 32. the label LABELS; it does not FILTER -------------------------------------------------
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

# --- 33. --json agrees with the TEXT, path by path and in total -------------------------------
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

# --- 34. MUTANT: existence never checked (assertion 31's FIRES direction is live) -------------
# The label stops appearing and everything else about the report is unchanged, which is exactly
# what a broken label looks like from the outside. The positive conjunct — the finding is still
# named — is what stops a subject that emits NOTHING from scoring as a kill here.
M_EXT="$(mkmut existstrue '"exists": os.path.exists(os.path.join(root, p))' '"exists": True')"
if [ -z "$M_EXT" ]; then
  bad "MUTANT existstrue: the anchor matched nothing — assertion 31 proves nothing"
else
  run_txt "$M_EXT" "$ABSBL" "$WORK/mext.txt" "$EXTREE"; mext_rc=$RC
  mext_txt="$(cat "$WORK/mext.txt")"
  if [ "$mext_rc" = "0" ] && has 'CO-S410-ABSENTONLY' "$mext_txt" \
     && ! has 'NO SUCH FILE HERE' "$mext_txt"; then
    ok "MUTANT existstrue: with existence hardcoded true the absent path renders unmarked while the finding is still reported — so assertion 31 is what makes the label fire"
  else
    bad "MUTANT existstrue: rc=$mext_rc, marker still present or the finding vanished — assertion 31's fires-direction is vacuous"
    show "$mext_txt"
  fi
fi

# --- 35. MUTANT: everything marked absent (assertion 31's SILENT direction is live) -----------
# The mirror, and the one that a fires-only arm cannot catch: a label that flags EVERY path reads
# identically to one that discriminates, unless something asserts the near-miss stays quiet.
M_EXF="$(mkmut existsfalse '"exists": os.path.exists(os.path.join(root, p))' '"exists": False')"
if [ -z "$M_EXF" ]; then
  bad "MUTANT existsfalse: the anchor matched nothing — assertion 31 proves nothing"
else
  run_txt "$M_EXF" "$ABSBL" "$WORK/mexf.txt" "$EXTREE"; mexf_rc=$RC
  mexf_txt="$(cat "$WORK/mexf.txt")"
  if [ "$mexf_rc" = "0" ] \
     && has '^      names: scripts/ai-dlc/core-paths\.sh   \[NO SUCH FILE HERE\]$' "$mexf_txt"; then
    ok "MUTANT existsfalse: with existence hardcoded false the PRESENT path is marked too — so assertion 31's near-miss is what stops a label that flags everything"
  else
    bad "MUTANT existsfalse: rc=$mexf_rc and the present path stayed unmarked — assertion 31's silent-direction is vacuous"
    show "$mexf_txt"
  fi
fi

# --- 36. MUTANT: the label turned into a filter (assertion 32 is live) ------------------------
# The "improvement" assertion 32 exists to catch, built and scored rather than argued about: skip
# an entry whose named machinery is not on disk. CO-S410-MIXED survives with its marker intact, so
# this mutant fails assertion 32 and ONLY assertion 32 — the acquittal is the whole finding.
M_FIL="$(mkmut absentfilter \
  '    absent_total += sum(1 for r in rows if not r["exists"])' \
  '    absent_total += sum(1 for r in rows if not r["exists"])
    if not any(r["exists"] for r in rows): continue')"
if [ -z "$M_FIL" ]; then
  bad "MUTANT absentfilter: the anchor matched nothing — assertion 32 proves nothing"
else
  run_json "$M_FIL" "$ABSBL" "$WORK/mfil.json" "$EXTREE"; mfil_rc=$RC
  mfil_ids=""; [ "$mfil_rc" = "0" ] && mfil_ids="$(summarize "$WORK/mfil.json" | grep '^finding=' || true)"
  if [ "$mfil_rc" = "0" ] && ! has '^finding=CO-S410-ABSENTONLY$' "$mfil_ids" \
     && has '^finding=CO-S410-MIXED$' "$mfil_ids" \
     && has '^finding=CO-S410-PRESENT$' "$mfil_ids"; then
    ok "MUTANT absentfilter: filtering on existence ACQUITS the entry whose only machinery path is absent while the other two survive — so assertion 32 is what keeps a true misroute reportable"
  else
    bad "MUTANT absentfilter: rc=$mfil_rc, ids [$(echo "$mfil_ids" | tr '\n' ' ')] — assertion 32 is vacuous"
  fi
fi

# --- 37. MUTANT: absent_named decoupled from the text (assertion 33 is live) ------------------
# The text still marks the rows and only the JSON total lies, which is the failure a single-value
# read could never see — and the reason assertion 33 derives the count twice instead of once.
M_CNT="$(mkmut absentcount '"absent_named": absent_total,' '"absent_named": 0,')"
if [ -z "$M_CNT" ]; then
  bad "MUTANT absentcount: the anchor matched nothing — assertion 33 proves nothing"
else
  run_json "$M_CNT" "$ABSBL" "$WORK/mcnt.json" "$EXTREE"; mcnt_rc=$RC
  mcnt_absent=""; [ "$mcnt_rc" = "0" ] && mcnt_absent="$(summarize "$WORK/mcnt.json" | sed -n 's/^absent_named=//p')"
  mcnt_named=""; [ "$mcnt_rc" = "0" ] && mcnt_named="$(summarize "$WORK/mcnt.json" | grep '^named=.* absent$' || true)"
  if [ "$mcnt_rc" = "0" ] && [ "$mcnt_absent" = "0" ] && [ -n "$mcnt_named" ]; then
    ok "MUTANT absentcount: the JSON total reads 0 while named[] still carries absent rows — so assertion 33's two derivations are what bind the count to the rendering"
  else
    bad "MUTANT absentcount: rc=$mcnt_rc, absent_named=$mcnt_absent, absent named[] rows [${mcnt_named:-none}] — assertion 33 is vacuous"
  fi
fi

# --- the core-paths sandboxes: one LAYERED, one bare, otherwise identical ---------------------
# The activation rule is read off the subject, not restated: a `.claude/.ai-dlc-version` FILE plus
# the `overrides/` and `extensions/` layer DIRECTORIES, walked up from $PWD. Both sandboxes carry
# the same real file at a core destination and the same subdirectory; the layered one carries the
# three activation elements and the bare one carries none. That is the only difference, and it is
# what makes the pair a control rather than two separate observations.
#
# NEITHER SANDBOX HOLDS A MANIFEST. `--is-core`'s manifest fallback is cwd-relative, so a manifest
# here would be a second variable moving between the two trees; every probe is handed $MANIFEST_F
# explicitly instead.
LAY="$WORK/layered"; PLAIN="$WORK/plain"
for _t in "$LAY" "$PLAIN"; do
  mkdir -p "$_t/scripts/ai-dlc" "$_t/deep/nested"
  : > "$_t/scripts/ai-dlc/core-paths.sh"
done
mkdir -p "$LAY/.claude/skills/ai-dlc/overrides" "$LAY/.claude/skills/ai-dlc/extensions"
: > "$LAY/.claude/.ai-dlc-version"

# THE TRIO IS THE ASSERTION, AND IT IS ONE INVOCATION SET. A real file under a core glob, an
# INVENTED name under the SAME glob, and a non-core path. The first and third are the answers that
# do NOT move between a layered tree and a dormant one, so they are the control: a middle verdict
# read on its own cannot tell a working gate from a resolver that classified nothing.
cp_trio() { # cp_trio <core-paths.sh> <cwd> -> "<rc-real> <rc-invented> <rc-noncore>"
  local s="$1" c="$2" out="" p rc
  for p in scripts/ai-dlc/core-paths.sh scripts/ai-dlc/NEVER-SHIPPED-BY-ANYONE.sh docs/architecture/decisions.md; do
    ( cd "$c" && bash "$s" --is-core "$p" "$MANIFEST_F" >/dev/null 2>&1 ); rc=$?
    out="${out}${rc} "
  done
  printf '%s' "${out% }"
}
lay_root="$(cp_trio "$CPATHS" "$LAY")"
lay_sub="$(cp_trio "$CPATHS" "$LAY/deep/nested")"
pln_root="$(cp_trio "$CPATHS" "$PLAIN")"
pln_sub="$(cp_trio "$CPATHS" "$PLAIN/deep/nested")"

# --- 38. CONTROL: the core-paths mutator refuses an anchor that matches nothing ---------------
# The second subject gets its own harness, so it gets its own control. A `sed` that matched
# nothing produces an unmutated copy, and an unmutated copy passes every arm below — a mutation
# that killed nothing reads exactly like an arm that cannot fire.
if [ -z "$(mkmutcp impossible 'ZZ-NOT-IN-THE-SUBJECT-ZZ' 'x')" ] \
   && [ -n "$(mkmutcp control 'LAYERED_ROOT=""' 'LAYERED_ROOT="" # control')" ]; then
  ok "CONTROL: mkmutcp refuses an anchor present 0 times and accepts one present exactly once — assertions 42-44 score against real mutations"
else
  bad "CONTROL: mkmutcp accepted an impossible anchor or refused a real one — every core-paths mutant below is unscored"
fi

# --- 39. LAYERED: a matched path naming no file is a REFUSAL, not a 0 -------------------------
if [ "$lay_root" = "0 2 1" ]; then
  ok "on a LAYERED tree --is-core answers 0 / 2 / 1 for a real core file, an invented name under the SAME glob, and a non-core path — the glob match alone no longer decides"
else
  bad "on a LAYERED tree --is-core answered [$lay_root], want [0 2 1]"
fi

# --- 40. DORMANT: the same three inputs, and the mode behaves exactly as before ---------------
# THE PAIR IS THE WHOLE POINT. Assertion 39 alone cannot tell a working gate from one that fires
# everywhere, and assertion 40 alone cannot tell a dormant tree from a disarmed one. Same three
# inputs, same file on disk, activation elements removed — the middle answer moves and nothing
# else does.
if [ "$pln_root" = "0 0 1" ]; then
  ok "on a NON-layered tree the same three inputs answer 0 / 0 / 1 — the mode stays dormant, which is what keeps assertion 3 and the distribution's own gates measuring what they always measured"
else
  bad "on a NON-layered tree --is-core answered [$pln_root], want [0 0 1] — the new arm is not dormant off a layered consumer"
fi

# --- 41. the answer is cwd-INVARIANT: the root is walked up to, never counted in hops ---------
# A validator that counts `..` hops answers differently from the root, from a subdirectory and
# from a sandbox, and the sandbox answer is the silent one. The third conjunct is the control: if
# both subdirectory runs collapsed to the same "found nothing" answer they would agree trivially,
# and an equality between two identical failures reads exactly like invariance.
if [ "$lay_root" = "$lay_sub" ] && [ "$pln_root" = "$pln_sub" ] && [ "$lay_sub" != "$pln_sub" ]; then
  ok "the verdicts are cwd-invariant: layered root [$lay_root] == layered subdir, bare root [$pln_root] == bare subdir, and the two subdirs still DIFFER (the control — equal-because-both-blind would read as invariance)"
else
  bad "cwd changed the answer: layered [$lay_root] vs [$lay_sub], bare [$pln_root] vs [$pln_sub]"
fi

# --- 42. MUTANT: the layered root never recorded (assertion 39 is live) -----------------------
# THE DISARMED GATE, AND IT READS EXACTLY LIKE THE DORMANT ONE. With the root never recorded the
# existence check cannot run, so a layered consumer answers 0 / 0 / 1 — byte-identical to
# assertion 40's dormant tree. That is why neither arm can stand alone.
M_LOFF="$(mkmutcp layeroff 'LAYERED_ROOT="$_d"; break' 'break')"
if [ -z "$M_LOFF" ]; then
  bad "MUTANT layeroff: the anchor matched nothing — assertion 39 proves nothing"
else
  moff_lay="$(cp_trio "$M_LOFF" "$LAY")"
  moff_pln="$(cp_trio "$M_LOFF" "$PLAIN")"
  if [ "$moff_lay" = "0 0 1" ] && [ "$moff_pln" = "0 0 1" ]; then
    ok "MUTANT layeroff: with the layered root never recorded the LAYERED tree answers [0 0 1] — indistinguishable from the dormant tree — so assertion 39 is the only thing that separates them"
  else
    bad "MUTANT layeroff: layered [$moff_lay] bare [$moff_pln], want [0 0 1] for both — assertion 39 is vacuous"
  fi
fi

# --- 43. MUTANT: the dormancy guard removed (assertion 40 is live) ----------------------------
# The mirror failure, and the expensive one: with the activation test dropped, `${LAYERED_ROOT}`
# is empty, every matched path is looked for at `/scripts/...`, and the distribution — where every
# path IS core — starts refusing its own files. Assertion 40 is what makes that unshippable.
M_LALW="$(mkmutcp layeralways \
  'if [ -n "$LAYERED_ROOT" ] && [ ! -e "${LAYERED_ROOT}/${REL}" ]; then' \
  'if [ ! -e "${LAYERED_ROOT}/${REL}" ]; then')"
if [ -z "$M_LALW" ]; then
  bad "MUTANT layeralways: the anchor matched nothing — assertion 40 proves nothing"
else
  malw_pln="$(cp_trio "$M_LALW" "$PLAIN")"
  malw_lay="$(cp_trio "$M_LALW" "$LAY")"
  if [ "$malw_pln" = "2 2 1" ] && [ "$malw_lay" = "0 2 1" ]; then
    ok "MUTANT layeralways: without the dormancy guard a NON-layered tree refuses its own real core file [$malw_pln] while the layered tree is unchanged — so assertion 40 is what keeps the mode dormant"
  else
    bad "MUTANT layeralways: bare [$malw_pln] (want [2 2 1]), layered [$malw_lay] (want [0 2 1]) — assertion 40 is vacuous"
  fi
fi

# --- 44. MUTANT: the walk-up reduced to a single hop (assertion 41 is live) -------------------
# One hop is the cheapest wrong answer available here and it is silent: the root run still sees
# the stamp, so the tree looks correctly gated, while every run from a subdirectory quietly falls
# back to the dormant answer.
M_HOP="$(mkmutcp onehop '    _d="$(dirname "$_d")"' '    _d=""')"
if [ -z "$M_HOP" ]; then
  bad "MUTANT onehop: the anchor matched nothing — assertion 41 proves nothing"
else
  mhop_root="$(cp_trio "$M_HOP" "$LAY")"
  mhop_sub="$(cp_trio "$M_HOP" "$LAY/deep/nested")"
  if [ "$mhop_root" = "0 2 1" ] && [ "$mhop_sub" = "0 0 1" ]; then
    ok "MUTANT onehop: checking only \$PWD leaves the root run correct [$mhop_root] and the subdirectory run dormant [$mhop_sub] — so assertion 41 is what rules out a cwd-dependent verdict"
  else
    bad "MUTANT onehop: root [$mhop_root] (want [0 2 1]), subdir [$mhop_sub] (want [0 0 1]) — assertion 41 is vacuous"
  fi
fi

echo ""
if [ "$made" -ne "$EXPECTED_ASSERTIONS" ]; then
  echo "upstream-routing: FAIL — $made assertions ran, $EXPECTED_ASSERTIONS were written. One did not execute at all, which is not the same as one that passed."
  exit 1
fi
if [ "$fails" -eq 0 ]; then echo "upstream-routing: PASS ($made assertions)"; exit 0; fi
echo "upstream-routing: FAIL ($fails of $made)"; exit 1
