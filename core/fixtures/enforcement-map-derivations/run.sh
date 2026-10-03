#!/usr/bin/env bash
# enforcement-map-derivations — assert the derivations validate-enforcement-map.sh runs
# in a LOOP still fire.
#
# Usage: run.sh [--run-one <assertion>] [--group <shard>]
# Exit:  0 = every assertion holds, 1 = a check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH, and why it is a separate fixture from
# enforcement-map-sites. Six of that validator's invariants evaluate a predicate once per
# item over a corpus -- once per manifest row, once per map entry, once per fixture, once
# per role, once per rule-prose file, once per seed. None of the six had an assertion
# anywhere in the tree. They were rewritten in v0.205.0 to read each corpus once instead
# of forking per item, and the only evidence available at the time was a one-off
# differential against the pre-change copy, which does not survive the merge.
#
# That is this repo's named class one layer out: the invariants were live and correct, and
# a rewrite that quietly emptied any one of their subject sets would have produced the
# same green line. So the differential is made permanent here in the shape that outlives
# it -- mutate the tree, require the message.
#
# Each assertion mutates a PRISTINE copy of the seed and asserts a POSITIVE outcome (the
# specific message appears), never the absence of an old one. Assertion 0 is the unmutated
# control: without it a validator erroring for reasons of its own scores every negative
# below as a kill.
#
# ONE TREE PER ASSERTION, IN ONE PROCESS PER ASSERTION, AND THE REASON IS WALL CLOCK.
# Same shape and the same argument as the sibling `enforcement-map-sites`, arrived at from
# the other end: that fixture was the suite's critical path until it grew an inner pool,
# and this one then became it. Every assertion below runs
# `validate-enforcement-map.sh` over a freshly copied tree, that validator is ~8.5s a call
# with no hot spot inside it (measured by cut-bisect: 3.66s at 30% of the file rising
# monotonically to 8.73s, i.e. ~76 invariants each scanning the tree, not one slow one),
# and there are ~16 of those calls here. The pre-push pool parallelizes ACROSS fixtures and
# every one of those calls was running SEQUENTIALLY inside a single pool slot, which is why
# the suite makespan sat at this file's duration and no `AI_DLC_FIXTURE_JOBS` value moved
# it: a pool's makespan is bounded below by its longest single unit.
#
# Nothing about that is a property of the assertions. Each one already re-copied a pristine
# tree and shared no state with any other, so they were independent before this driver
# existed; the serial `t="$(fresh)"` sequence was just the cheapest way to write them down.
#
# AND EACH ASSERTION NOW RUNS ONLY THE ARM IT TESTS. The per-call cost above is the cost of a
# WHOLE-FILE run, which exactly one assertion still makes: A00, whose claim is an absence over
# every arm and which therefore cannot be selected. Every other assertion tests one invariant,
# names it in its own function name, and reaches it through
# `validate-enforcement-map.sh --arms I<n>` -- so it pays the file's prologue plus its own
# unit instead of ~76 invariants scanning a tree it does not care about. The selector is
# DERIVED from the assertion's name and never from a table beside it, there is no fallback to
# a whole-file run, and the control below fails the shard if selection quietly stops
# happening. See `arm_id_of`, `run_map` and the selection join at the foot of this file.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
D_ROOT="$(cd "$HERE/../../.." && pwd)"

# Distribution-only, same as the sibling: validate-enforcement-map.sh checks the
# distribution's own two writers against each other and install.sh does not ship it, so in
# a consumer tree there is nothing to test. Say so and stop; do not fake a pass.
if [ ! -f "$D_ROOT/scripts/validate-enforcement-map.sh" ]; then
  echo "enforcement-map-derivations: SKIP — distribution-only (validate-enforcement-map.sh is not shipped to consumers)"
  exit 0
fi

fails=0
broken=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

SKILL_REL="core/skills/ai-dlc/SKILL.md"

# I112's three subjects, named once. The arm compares each OWNER's template line against that
# owner's own bullet in the READER's Check 1 span, and scans that span for unowned tokens.
CR_OWNER="core/team-roles/code-reviewer.md"
QA_OWNER="core/team-roles/qa.md"
CR_READER="core/skills/ai-dlc/steps/gate-validation.md"

# seed_tree — build this process's own pristine tree and scratch dir. Called by --run-one
# only, so a worker owns everything it touches and no two workers share a path.
seed_tree() {
  PRISTINE="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
  WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
}

# A fresh COPY of the pristine seed, never an edit of it. A mutation applied in place
# leaks into every later assertion, and the one that leaks reads as the one that fired.
# It stays a copy even now that each assertion has its own process: the arms of a single
# assertion still need a clean tree between them, and a `fresh()` that handed back the
# pristine root itself would put that back the way it was.
fresh() {
  rm -rf "$WORK/t"
  cp -R "$PRISTINE" "$WORK/t"
  printf '%s' "$WORK/t"
}

# edit <file> <awk program> — rewrite a file through awk, then REQUIRE the bytes changed.
# A program that matched nothing leaves a tree that is not a mutant, and the assertion
# built on it would report the check passing on input that never violated it.
edit() {
  local f="$1" prog="$2"
  awk "$prog" "$f" > "$f.mut" || { bad "FIXTURE BROKEN — awk failed on $f"; return 1; }
  if cmp -s "$f" "$f.mut"; then
    bad "FIXTURE BROKEN — the mutation of ${f##*/} changed nothing; the assertion below would test a clean tree"
    rm -f "$f.mut"; return 1
  fi
  mv "$f.mut" "$f"
}

# edit_json <file> <python program> — `edit`, for a file whose grammar is JSON.
#
# THE VALIDITY ASSERT IS THE POINT, and it is what an awk edit cannot give. A schema mutated
# into unparseable JSON makes the walker that reads it yield NOTHING, the exclusion goes empty,
# and the arm reports every enum token in the span -- a fire the assertion would score as its
# own kill while the real cause was a broken seed. So the program is handed the parsed text and
# its output is REPARSED before it lands. The `cmp -s` guard is `edit`'s, for `edit`'s reason.
#
# The program reads the file path as argv[1] and writes the new text to stdout.
edit_json() {
  local f="$1" prog="$2"
  python3 -c "$prog" "$f" > "$f.mut" 2>/dev/null || {
    bad "FIXTURE BROKEN — the python mutation of ${f##*/} failed; no tree was built and nothing below was tested"
    rm -f "$f.mut"; return 1
  }
  if cmp -s "$f" "$f.mut"; then
    bad "FIXTURE BROKEN — the mutation of ${f##*/} changed nothing; the assertion below would test a clean tree"
    rm -f "$f.mut"; return 1
  fi
  if ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$f.mut" 2>/dev/null; then
    bad "FIXTURE BROKEN — the mutation left ${f##*/} as invalid JSON. The renderer's walker would read NOTHING out of it, the enum exclusion would go empty, and the arm would report every enum token in the span — a fire this assertion would misread as its own."
    rm -f "$f.mut"; return 1
  fi
  mv "$f.mut" "$f"
}

# arm_id_of <name> — the invariant id a name DECLARES, or empty.
#
# EVERY ASSERTION IS NAMED `A<nn>_i<id>_<what>`, AND THAT EMBEDDED SEGMENT IS THE
# DECLARATION. `A24_i85_fails_closed_when_blind` declares I85; `A26_i33b_two_step_walk`
# declares I33b; `A00_control` declares nothing, because the whole file is its subject. A
# table beside these functions mapping assertion to invariant would be a second list to keep
# in step, and a drifted row runs the wrong arm while still printing `ok`.
#
# The grammar is the validator's own `I[0-9]+[a-c]?`, so an id shape `--arms` can select is
# exactly an id shape this can derive; the two cannot disagree about what an id looks like.
arm_id_of() {
  awk -v n="$1" 'BEGIN {
    k = split(n, p, "_")
    for (i = 2; i <= k; i++) if (p[i] ~ /^i[0-9]+[a-c]?$/) { print "I" substr(p[i], 2); exit }
  }'
}

# run_map <id> — THE ONE PLACE this fixture invokes the validator, and the ledger every
# invocation is written into. A non-empty <id> runs only that arm's unit (`--arms`); an empty
# one runs the whole file.
#
# THE LEDGER IS A FILE, NOT A COUNTER VARIABLE, and that is forced. Every caller but A00's
# reads the output through `$( )`, and an assignment made inside a command substitution is
# lost with the subshell -- a counter incremented there would read zero at the control below,
# which is precisely the reading that means selection never happened. A file survives the
# subshell.
run_map() {
  local id="$1"
  if [ -z "$id" ]; then
    printf 'f\n' >> "$WORK/calls"
    bash "$t/scripts/validate-enforcement-map.sh" 2>&1
    return $?
  fi
  printf 's %s\n' "$id" >> "$WORK/calls"
  bash "$t/scripts/validate-enforcement-map.sh" --arms "$id" 2>&1
}

# sel_guard <rc> <id> <output> — a validator exit of 2 is a SELECTION failure and never an
# invariant violation: an id no arm declares, a malformed flag, or a generated subprogram
# that returned without reaching the verdict block. Nothing was checked, so it must not be
# scored as a mutant surviving OR as one dying; both readings are false, and the second is
# the dangerous one because it prints `ok`.
#
# CALLED FROM THE ASSERTION'S OWN FRAME, NEVER INSIDE `$( )`. An `exit` inside a command
# substitution leaves the subshell and the run continues; the `bad` line would be captured
# into the caller's output variable instead of being printed.
sel_guard() {
  [ "$1" = "2" ] || return 0
  bad "FIXTURE BROKEN — 'validate-enforcement-map.sh --arms $2' exited 2. That is a selection or usage failure, never an invariant violation, so NOTHING was checked here and this is not a surviving mutant. The validator said: $3"
  exit 2
}

# assert <label> <expected substring> — run ONLY the arm this assertion tests, in $t, and
# require the message.
#
# THE ARM IS DERIVED FROM THE CALLER'S NAME. `${FUNCNAME[@]}` is walked outward and the
# innermost frame declaring an id wins, so the 25-odd call sites below are unchanged and an
# assertion added later selects its arm by being named correctly rather than by anyone
# remembering a second place to edit it.
#
# THERE IS NO SILENT FALLBACK TO A FULL RUN, AND THAT IS THE WHOLE DESIGN. A frame with no
# derivable id is FIXTURE BROKEN, not "run everything". A full run would still contain the
# message this assertion is looking for and would still print `ok`, so a fallback is a
# selection mechanism that cannot fire reading exactly like one that fired -- this file's own
# subject, one level out.
assert_fires() {
  local label="$1" want="$2" out rc id="" f
  for f in "${FUNCNAME[@]}"; do
    id="$(arm_id_of "$f")"
    [ -n "$id" ] && break
  done
  if [ -z "$id" ]; then
    bad "FIXTURE BROKEN — no frame above assert_fires is named A<nn>_i<id>_<what>, so the arm to select cannot be derived and nothing was checked. Name the assertion for the invariant it tests."
    exit 2
  fi
  out="$(run_map "$id")"
  rc=$?
  sel_guard "$rc" "$id" "$out"
  case "$out" in
    *"$want"*) ok "$label" ;;
    *)         bad "$label — the validator did NOT report it. The predicate no longer reaches this subject, and a corpus it cannot see reads exactly like a corpus with nothing wrong in it." ;;
  esac
}

# arm_of — the id the calling assertion declares, or FIXTURE BROKEN. Lifted out of
# assert_fires so the counting forms below select their arm by the same derivation rather than
# by a second copy of the walk.
arm_of() {
  local f id=""
  for f in "${FUNCNAME[@]}"; do
    id="$(arm_id_of "$f")"
    [ -n "$id" ] && break
  done
  printf '%s' "$id"
}

# assert_fires_n <label> <want> <want_n> — assert_fires, plus the count of findings the run
# produced.
#
# THE COUNT IS THE WHOLE OF "EXACTLY ONE DIRECTION", AND A SUBSTRING MATCH CANNOT SAY IT.
# I112 reports three distinct findings out of one arm -- owner->reader, reader->owner, and the
# span scan -- and a mutation that moves two of them is a mutation whose subject is shared
# between two directions, which is `fixture-mutants.md`'s entangled-assertions rule with three
# cells instead of two. `assert_fires` would print `ok` for every one of them. So the number of
# `FAIL:` lines is asserted, and every line is required to NAME the selected arm: a finding
# from the selector prologue is not this arm firing, and counting it as one would let a broken
# `--arms` run satisfy an assertion about the corpus.
assert_fires_n() {
  local label="$1" want="$2" want_n="$3" out rc id n n_arm
  id="$(arm_of)"
  if [ -z "$id" ]; then
    bad "FIXTURE BROKEN — no frame above assert_fires_n is named A<nn>_i<id>_<what>, so the arm to select cannot be derived and nothing was checked."
    exit 2
  fi
  out="$(run_map "$id")"
  rc=$?
  sel_guard "$rc" "$id" "$out"
  n="$(grep -c '^FAIL:' <<<"$out")" || n=0
  n_arm="$(grep -c "^FAIL: $id" <<<"$out")" || n_arm=0
  case "$out" in
    *"$want"*) ;;
    *) bad "$label — $id did NOT report it. The predicate no longer reaches this subject, and a corpus it cannot see reads exactly like a corpus with nothing wrong in it."
       grep '^FAIL:' <<<"$out" | cut -c1-160 | sed 's/^/          | /'
       return ;;
  esac
  if [ "$n" -ne "$want_n" ]; then
    bad "$label — it fired, but the run produced $n finding(s) where $want_n was expected. Two of $id's three directions moving on one mutation means they share a subject and one of them is vacuous."
    grep '^FAIL:' <<<"$out" | cut -c1-160 | sed 's/^/          | /'
    return
  fi
  if [ "$n_arm" -ne "$n" ]; then
    bad "$label — $n_arm of $n finding(s) name $id. The rest came from somewhere other than the arm under test, so the count above is not a statement about it."
    return
  fi
  ok "$label"
}

# assert_silent <label> — the mutated tree produces NO finding, and the arm RAN.
#
# AN ABSENCE-SHAPED ASSERTION NEEDS A POSITIVE CONJUNCT OR A SUBJECT THAT NEVER RAN SATISFIES
# IT. `fixture-mutants.md` records a control asserting rc=0-and-nothing-reported passing
# against a subject replaced by `exit 0`. Here the positive conjunct is the validator's own
# `OK:` line, which only a run that reached its verdict block can print -- and `sel_guard`
# above has already refused the exit-2 case where `--arms` selected no subprogram at all.
# The anchor stops before the catalog-check COUNT in that line, which is derived and moves.
#
# EVERY CALLER PAIRS THIS WITH AN ALLOW TWIN IN ITS OWN FRAME, one property apart. A silence
# arm alone cannot tell an exclusion keyed on the right property from a scan that stopped
# matching, and the two read identically.
assert_silent() {
  local label="$1" out rc id n
  id="$(arm_of)"
  if [ -z "$id" ]; then
    bad "FIXTURE BROKEN — no frame above assert_silent is named A<nn>_i<id>_<what>, so the arm to select cannot be derived and nothing was checked."
    exit 2
  fi
  out="$(run_map "$id")"
  rc=$?
  sel_guard "$rc" "$id" "$out"
  n="$(grep -c '^FAIL:' <<<"$out")" || n=0
  case "$out" in
    *"OK: enforcement-map.yaml in sync with"*) ;;
    *) bad "$label — the validator printed no verdict line, so it did not reach the end of its run and this silence is not evidence that $id acquitted anything."
       return ;;
  esac
  if [ "$n" -ne 0 ]; then
    bad "$label — the run produced $n finding(s) where the seeded token was supposed to be acquitted. $id is reporting on a tree the exclusion is meant to cover."
    grep '^FAIL:' <<<"$out" | cut -c1-160 | sed 's/^/          | /'
    return
  fi
  ok "$label"
}

# cr_after_check1 <line> — an awk program inserting <line> immediately after Check 1's heading.
#
# ONE INSERTION POINT FOR EVERY SPAN SEED, so the seeds below differ ONLY in the text they
# carry. A seed placed at a different offset differs from its twin in two properties and the
# pair stops being one property apart, which is the whole of what a DENY/ALLOW twin asserts.
# The address is the heading the arm's own span extractor opens on, so a seed can never land
# outside the span it is meant to be inside.
cr_after_check1() {
  printf '%s' '/^### 1\. Validation cycle complete\?/ && !d { print; print "'"$1"'"; d=1; next } { print }'
}

# cr_owner_members <owner file> — the template line's members, in template order.
#
# DERIVED FROM THE OWNER, NEVER WRITTEN DOWN HERE. The expected message text names members by
# name, and a hand-typed list of them in this file would be a second declaration of the very
# set I112 exists to keep single -- it would go stale in the release that changes the template
# and the assertion would then read `ok` for a message about different members. The count is
# guarded by every caller, because an extraction that stopped matching yields an empty want
# string and a `case` on an empty pattern matches every output there is.
cr_owner_members() {
  awk '/^## Verdict$/ { on = 1; next }
       on && /^[A-Z_]+( \| [A-Z_]+)+$/ { n = split($0, m, /[[:blank:]]*\|[[:blank:]]*/)
                                         for (i = 1; i <= n; i++) print m[i]; exit }' "$1"
}

# cr_enum_unseen <tree root> — a screaming-compound schema enum member that Check 1's span does
# NOT already carry, run out of the renderer's own SCHEMA_PY walker exactly as the arm derives
# its exclusion.
#
# THE SEED FOR THE ENUM ACQUITTAL IS DERIVED BY RUNNING THE WALKER, not by naming a member of
# it. A typed enum name is a claim about core/schemas/ that nothing rechecks: the day that
# member is renamed, the seed stops being a schema enum member, the arm correctly reports it,
# and the silence assertion fails looking exactly like a regression in the exclusion.
#
# AND IT MUST BE A MEMBER THE SPAN DOES NOT ALREADY HAVE, which is the half that makes the
# assertion discriminate. The walker's FIRST member is `EXIT_CONDITION_MET` and Check 1 names
# it on the real tree -- measured -- so a seed of that token re-exercises an acquittal the
# UNMUTATED control already proves, and the assertion would pass against a mutated tree that
# never acquitted anything new. `fixture-mutants.md`: seed the discriminating member, not the
# first one. The scan is over the same span the arm extracts, so "already carried" is decided
# against the text the arm reads rather than against the whole file.
# cr_enum_all <tree root> — every screaming-compound enum member the renderer's walker yields.
# The shared half of `cr_enum_unseen` and A41's precondition, so the three callers cannot
# disagree about what "a schema enum member" means.
cr_enum_all() {
  local w
  w="$(awk "/^SCHEMA_PY='\$/ { on = 1; next } on && /^'\$/ { exit } on { print }" \
        "$1/scripts/render-vocabulary-index.sh")"
  [ -n "$w" ] || return 1
  python3 -c "$w" "$1/core/schemas" 2>/dev/null \
    | awk -F'\t' '{ n = split($3, m, " ")
                    for (i = 1; i <= n; i++)
                      if (m[i] ~ /^[A-Z]+([-_][A-Z]+)+$/ && !(m[i] in s)) { s[m[i]] = 1; print m[i] } }'
}

# cr_enum_schema <tree root> — the schema file the walker reads a screaming-compound enum out
# of, as a tree-relative path. ASKED OF THE WALKER rather than named here: a hand-named schema
# is the same defect A41 exists to catch, correct today and silently wrong the release that
# file is reorganised.
#
# THE WALKER'S FIRST COLUMN IS A BASENAME, NOT A PATH -- measured, `provenance-block.json` and
# not `core/schemas/provenance-block.json`. The directory is re-attached here rather than
# assumed, and the result is required to EXIST, because a path that resolves to nothing makes
# the caller's mutation match nothing and `edit_json` would report a broken fixture for a
# reason that has nothing to do with the schema.
cr_enum_schema() {
  local w base
  w="$(awk "/^SCHEMA_PY='\$/ { on = 1; next } on && /^'\$/ { exit } on { print }" \
        "$1/scripts/render-vocabulary-index.sh")"
  [ -n "$w" ] || return 1
  base="$(python3 -c "$w" "$1/core/schemas" 2>/dev/null \
          | awk -F'\t' '{ n = split($3, m, " ")
                          for (i = 1; i <= n; i++)
                            if (m[i] ~ /^[A-Z]+([-_][A-Z]+)+$/) { print $1; exit } }')"
  [ -n "$base" ] || return 1
  base="core/schemas/${base##*/}"
  [ -f "$1/$base" ] || return 1
  printf '%s\n' "$base"
}

cr_enum_unseen() {
  local w span
  w="$(awk "/^SCHEMA_PY='\$/ { on = 1; next } on && /^'\$/ { exit } on { print }" \
        "$1/scripts/render-vocabulary-index.sh")"
  [ -n "$w" ] || return 1
  span="$(awk '/^### 1\. Validation cycle complete\?/ { on = 1; next }
               on && /^### / { exit }
               on { print }' "$1/$CR_READER")"
  [ -n "$span" ] || return 1
  python3 -c "$w" "$1/core/schemas" 2>/dev/null \
    | awk -F'\t' '{ n = split($3, m, " ")
                    for (i = 1; i <= n; i++)
                      if (m[i] ~ /^[A-Z]+([-_][A-Z]+)+$/ && !(m[i] in s)) { s[m[i]] = 1; print m[i] } }' \
    | while IFS= read -r e; do
        grep -qF "$e" <<<"$span" || { printf '%s\n' "$e"; break; }
      done
}

# --- Assertion 0: CONTROL -----------------------------------------------------
# The unmutated seed must PASS. If it does not, the validator is failing for a reason of
# its own and every "it fired as expected" below is a false pass. It exits 2 rather than 1
# because "nothing was tested" and "a check regressed" are different answers, and the
# driver runs this one first and alone so that a failure here stops the run instead of
# reporting fourteen unattributable kills.
#
# THE ONE ASSERTION THAT KEEPS THE FULL RUN, and it is not an oversight. Its claim is that
# the seed violates NOTHING -- an absence over every arm in the file. A selected run says
# nothing whatever about the arms it did not run, so an `--arms` control would license the
# assertions below against a validator that could still be failing anywhere else. It carries
# no `_i<id>_` segment, which is how the selection control below knows it is exempt.
A00_control() {
  t="$(fresh)"
  if run_map "" >/dev/null 2>&1; then
    ok "unmutated seed passes (the assertions below mean something)"
  else
    bad "FIXTURE BROKEN — the unmutated seed does not pass validate-enforcement-map.sh. Every assertion below would be a false pass."
    exit 2
  fi
}

# --- Assertion 1: I3 — the GATE_MANIFEST row loop -----------------------------
# I3 walks every manifest row and every comma-separated id inside it. A row naming a check
# the map has no entry for must be reported; if the per-id walk stops reaching the ids, a
# manifest requiring a check that does not exist gates nothing and says PASS.
A01_i3_manifest_row_loop() {
  t="$(fresh)"
  if edit "$t/core/skills/ai-dlc/steps/gate-validation.md" \
       '!done && /^\| universal +\| / { sub(/^\| universal +\| /, "&zz9, "); done=1 } { print }'; then
    assert_fires "I3  a GATE_MANIFEST row naming a check the map does not define is REPORTED" \
                 "GATE_MANIFEST names check zz9"
  fi
}

# --- Assertion 2: I9/W1 — the per-entry call_sites walk -----------------------
# W1 is the invariant that exists because validate-steering-budget.sh guarded eleven live
# violations from zero gates. Strip every call_sites block and each script-adjudicated
# entry must be named.
A02_i9_w1_call_sites_walk() {
  t="$(fresh)"
  if edit "$t/core/skills/ai-dlc/enforcement-map.yaml" \
       '/^    call_sites:/ { skip=1; next }
        skip && (/^    [a-z_]+:/ || /^  - id:/ || /^[a-z]/) { skip=0 }
        skip { next }
        { print }'; then
    assert_fires "I9  a script-adjudicated entry with NO call_sites is REPORTED (W1)" \
                 "is adjudication:script but declares NO call_sites"
  fi
}

# --- Assertion 3: I9/W2 — the per-(enforcer, site) resolution -----------------
# W2 resolves each declared site to a file and requires that file to name the enforcer.
# Repoint every site at a step file that has never heard of them.
A03_i9_w2_site_resolution() {
  t="$(fresh)"
  if edit "$t/core/skills/ai-dlc/enforcement-map.yaml" \
       '/^      - site: / { sub(/gate-validation\.md/, "retro.md") } { print }'; then
    assert_fires "I9  a call site whose file never names the enforcer is REPORTED (W2)" \
                 "The site is fictional"
  fi
}

# --- Assertion 4: I10 — the per-fixture hermeticity walk ----------------------
# The token is ASSEMBLED, not written. I10's own subject set is core/fixtures/*/run.sh --
# this file -- so spelling the hook path here in one piece makes I10 fire on the fixture
# that tests it, on the real tree, every push.
A04_i10_fixture_hermeticity() {
  t="$(fresh)"
  local hookish
  hookish="hooks/""ai-dlc-core-guard.sh"
  mkdir -p "$t/core/fixtures/zz-hookless"
  { printf '#!/usr/bin/env bash\n'
    printf '# drives %s and scrubs no ambient AI_DLC_* env\n' "$hookish"
    printf 'exit 0\n'; } > "$t/core/fixtures/zz-hookless/run.sh"
  assert_fires "I10 a hook-driving fixture that never scrubs AI_DLC_* is REPORTED" \
               "fixture 'zz-hookless' invokes a hook but never scrubs"
}

# --- Assertion 5: I22 — the per-role config resolution ------------------------
# I22 exists because the dispatch guard FAILS OPEN on an unresolvable model: the role runs
# on whatever it inherits and nothing says so at runtime. Point the first role at a key
# aiDlcModels does not define.
A05_i22_role_config_resolution() {
  t="$(fresh)"
  if edit "$t/templates/settings.json.template" \
       '/"aiDlcRoles"/ { inr=1 }
        inr && !done && /"model"[[:space:]]*:/ { sub(/:[[:space:]]*"[^"]*"/, ": \"no-such-model-key\""); done=1 }
        { print }'; then
    assert_fires "I22 a role naming a model key aiDlcModels does not define is REPORTED" \
                 "but aiDlcModels does not define it"
  fi
}

# --- Assertion 6: I23 — the per-rule-prose-file corpus join -------------------
# Both sides of I23 are derived: the shipped set from install.sh's copy paths, the corpus
# from `audit-rule-files.sh --list`. Drop the team-roles class from what --list returns --
# the BUILDER is untouched, so those files stay shipped and stop being scanned, which is
# precisely I23's subject.
A06_i23_rule_prose_corpus_join() {
  t="$(fresh)"
  if edit "$t/core/scripts/audit-rule-files.sh" \
       '/^if MODE == "--list":/ && !done { print "corpus = [p for p in corpus if not p.startswith(\"core/team-roles/\")]"; done=1 }
        { print }'; then
    assert_fires "I23 an installed rule-prose file absent from the audit corpus is REPORTED" \
                 "is absent from the audit-rule-files.sh corpus"
  fi
}

# --- Assertion 7: I16 — the per-seed root-resolution depth --------------------
# A seed that resolves its root two dirs up lands at `tests/` in a consumer and every seed
# there dies -- correct in the distribution, broken on every consumer, which is why this
# has to be asserted here rather than noticed there.
#
# THE ID IS IN THE NAME BECAUSE IT HAS TO BE DERIVABLE, and it was measured rather than
# assumed: the `err` carrying "must be '$HERE/../../..'" falls inside the column-0 unit that
# `render-invariant-index.sh --arm-lines` attributes to I16, and on a tree mutated exactly as
# below, `--arms I16` reports it while `--arms I3` over the same mutated tree does not.
A07_i16_seed_root_resolution_depth() {
  t="$(fresh)"
  local victim
  victim="$(grep -lE '[DC]_ROOT="\$\(cd "\$HERE/\.\./\.\./\.\.' "$t"/core/fixtures/*/seed.sh 2>/dev/null | head -1)"
  if [ -z "$victim" ]; then
    bad "FIXTURE BROKEN — no seed in the tree resolves its root with \$HERE/../../.., so there is nothing to shorten and this assertion tests nothing."
  elif edit "$victim" \
         '/[DC]_ROOT="\$\(cd "\$HERE\// { sub(/\.\.\/\.\.\/\.\./, "../..") } { print }'; then
    assert_fires "root-depth: a seed resolving the repo root two dirs up is REPORTED" \
                 "must be '\$HERE/../../..'"
  fi
}

# --- I79: the carrier declaration on every rule below the re-attach cut ---------
# The rule this whole invariant exists for: a rule survives a compaction only if
# something other than the lead's memory carries it. Rule 19 held at 89% across the
# boundary because a dispatch template carries it; Rule 23 collapsed 13x with nothing
# but its own prose.

# THE ASSERTION THAT MATTERS MOST. The band must be DERIVED from the re-attach budget,
# never hardcoded: a band written as "14-30" silently stops matching the moment a rule is
# inserted, and it would keep printing this same clean line. Halving the window must move
# the reported band size. If this stops firing, every assertion below is scoped to a
# subject set the invariant chose rather than measured.
#
# SELECTED EXPLICITLY, because this one does not go through assert_fires -- it reads a COUNT
# out of the output and compares two runs. The predicate is presence-shaped on I79 (I79's own
# band line must appear, and must MOVE), so an I79-only run carries everything it reads and
# nothing it reads comes from another arm.
A08_i79_band_is_derived() {
  t="$(fresh)"
  local base_n moved_n base_out moved_out rc
  base_out="$(run_map I79)"; rc=$?
  sel_guard "$rc" I79 "$base_out"
  base_n="$(sed -n 's/.*I79: \([0-9]*\) rule(s).*/\1/p' <<<"$base_out")"
  if edit "$t/core/scripts/validate-reattach-budget.sh" \
        '/^BUDGET=/ { print "BUDGET=\"${AI_DLC_REATTACH_BUDGET:-2500}\""; next } { print }'; then
    moved_out="$(run_map I79)"; rc=$?
    sel_guard "$rc" I79 "$moved_out"
    moved_n="$(sed -n 's/.*I79: \([0-9]*\) rule(s).*/\1/p' <<<"$moved_out")"
    if [ -n "$base_n" ] && [ -n "$moved_n" ] && [ "$moved_n" -gt "$base_n" ]; then
      ok "I79: halving the re-attach window GROWS the band ($base_n -> $moved_n) — it is derived, not hardcoded"
    else
      bad "I79: the band did not move when the window changed (base='$base_n' moved='$moved_n') — it is hardcoded, and a rule inserted into the band would never be scanned"
    fi
  fi
}

# A band rule that declares no carrier at all.
A09_i79_rule_with_no_carrier() {
  t="$(fresh)"
  if edit "$t/$SKILL_REL" \
        '/^\*\*Carrier:\*\* `scripts\/ai-dlc\/validate-spawn-ledger\.sh`$/ { next } { print }'; then
    assert_fires "I79: a band rule with NO **Carrier:** declaration is REPORTED" \
                 "declares no '**Carrier:**'"
  fi
}

# A carrier that names a path which does not exist. An unresolvable carrier carries
# nothing, and the declaration would otherwise keep reading like coverage.
A10_i79_carrier_path_absent() {
  t="$(fresh)"
  if edit "$t/$SKILL_REL" \
        '/^\*\*Carrier:\*\* `scripts\/ai-dlc\/validate-spawn-ledger\.sh`$/ { print "**Carrier:** `scripts/ai-dlc/validate-nothing-at-all.sh`"; next } { print }'; then
    assert_fires "I79: a carrier naming a path that does not exist is REPORTED" \
                 "does not exist in the tree"
  fi
}

# `none` with no reason. A declared exemption with no argument is the defect this repo
# keeps finding, so "none" may not be the cheap way out.
A11_i79_carrier_none_with_no_reason() {
  t="$(fresh)"
  if edit "$t/$SKILL_REL" \
        '/^\*\*Carrier:\*\* none -- write shape is invisible/ { print "**Carrier:** none"; next } { print }'; then
    assert_fires "I79: 'carrier: none' with no reason is REPORTED" \
                 "with no reason"
  fi
}

# RULE NUMBERS AND CHECK NUMBERS ARE UNRELATED NAMESPACES. Check 22 is "Teammate-spawn
# role binding", which is RULE 19's subject; Check 23 is "Analyst-draft sprint stamps
# (Rule 24)". A carrier naming a check must be one the MAP lists, and this proves the
# invariant looks it up rather than assuming Rule N is carried by Check N.
A12_i79_carrier_names_absent_check() {
  t="$(fresh)"
  if edit "$t/$SKILL_REL" \
        '/^\*\*Carrier:\*\* `scripts\/ai-dlc\/validate-spawn-ledger\.sh`$/ { print "**Carrier:** `Check 9999`"; next } { print }'; then
    assert_fires "I79: a carrier naming a check id absent from the map is REPORTED" \
                 "is not an id in enforcement-map.yaml"
  fi
}

# A carrier that is neither a mappable consumer path nor a check id. SKILL.md is a RUNTIME
# file, so a `core/...` path is a dead link for every consumer reading it.
A13_i79_carrier_maps_to_no_layout() {
  t="$(fresh)"
  if edit "$t/$SKILL_REL" \
        '/^\*\*Carrier:\*\* `scripts\/ai-dlc\/validate-spawn-ledger\.sh`$/ { print "**Carrier:** `somewhere in the codebase`"; next } { print }'; then
    assert_fires "I79: a carrier that maps to no layout is REPORTED" \
                 "neither a consumer path this invariant can map"
  fi
}

# The gap count is REPORTED rather than silently tolerated — a bound the invariant accepts
# must be visible, or an accepted gap reads as full coverage.
#
# SELECTED EXPLICITLY, for A08's reason: the predicate matches a phrase I79 itself emits, so
# an I79-only run is the whole population it reads.
A14_i79_gap_count_is_reported() {
  t="$(fresh)"
  local out rc
  out="$(run_map I79)"; rc=$?
  sel_guard "$rc" I79 "$out"
  case "$out" in
    *"declared carrier gap(s)."*) ok "I79: the declared-gap count is reported, not silently accepted" ;;
    *) bad "I79: no gap count in the output — an accepted gap reads exactly like full coverage" ;;
  esac
}

# --- I79's carrier-stamp binding, driven through the REAL corpus ---------------
# The arm's own self-probe proves `i79_moved` names the right side on a three-rule toy
# SKILL.md. It does not prove the CORPUS loop reaches that comparison: measured, replacing
# the corpus drift `err` with `:` and editing Rule 23's body left I79 exit 0 and every fixture
# green, because nothing edited the real SKILL.md or the real carrier and required the message.
# These three do; against that mutant, built by hand in a copy, (a) and (b) FAIL and (c) and
# A14 stay ok. Each is presence-shaped -- (a) and (b) require a message to APPEAR, (c)
# requires the stamp-bound count to APPEAR beside the silence -- so a corpus loop that stopped
# emitting fails them rather than satisfying them.
#
# ONE LINE IN EACH SUBJECT, AND THE ANCHOR IS A LINE ONLY THAT SUBJECT CARRIES. Rule 23(b)'s
# heading line and Rule 24's first paragraph line each occur once in SKILL.md; `edit` refuses
# a program that matched nothing, so an anchor that drifts is FIXTURE BROKEN, not a pass.

# (a) Rule 23's body moves under an unchanged carrier -> exactly one finding, naming the body.
A43_i79_rule_body_drift_is_reported() {
  t="$(fresh)"
  if edit "$t/$SKILL_REL" \
        '/^\*\*\(b\) Sliced re-read of large step files\.\*\* / && !d { print $0 " A clause the carrier does not carry."; d=1; next } { print }'; then
    assert_fires_n "I79: an edit to Rule 23's body under an unchanged carrier is REPORTED as the rule body moving" \
                   "the rule body moved" 1
  fi
}

# (b) The carrier moves under an unchanged rule -> exactly one finding, naming the carrier.
# The carrier's path is the one the rule DECLARES, mapped the way I79 maps it; it is not a
# second list of carriers.
A44_i79_carrier_drift_is_reported() {
  t="$(fresh)"
  if edit "$t/core/rules/ai-dlc-resident-discipline.md" \
        '/^\*\*\(b\) Sliced re-read\.\*\* / && !d { print $0 " A clause the rule does not have."; d=1; next } { print }'; then
    assert_fires_n "I79: an edit to Rule 23's carrier under an unchanged rule is REPORTED as the carrier moving" \
                   "the carrier moved" 1
  fi
}

# (c) THE NEAR-MISS: Rule 24, the rule immediately after Rule 23, is edited. A stamp that
# hashed more than Rule 23's span would fire here -- measured by hand against a copy whose
# corpus hashed the whole SKILL.md (re-stamped to its own unedited pair, so only this arm
# separates it): (c) FAILED, (a) and (b) stayed ok. The silence is scored
# only beside a POSITIVE conjunct I79 itself prints -- the stamp-bound count, at least one --
# so a corpus loop that never reached the stamp comparison cannot pass this as a clean run.
A45_i79_neighbour_rule_edit_is_silent() {
  t="$(fresh)"
  local out rc n
  if edit "$t/$SKILL_REL" \
        '/^Read-heavy exploration in the planning and retro steps / && !d { print $0 " An edit to the neighbouring rule."; d=1; next } { print }'; then
    out="$(run_map I79)"; rc=$?
    sel_guard "$rc" I79 "$out"
    n="$(grep -c '^FAIL:' <<<"$out")" || n=0
    case "$out" in
      *"I79 carrier stamps: "[1-9]*" rule(s) stamp-bound to a .claude/rules/ carrier."*) ;;
      *) bad "I79: an edit to Rule 24 printed no stamp-bound count of at least one — the corpus loop never reached the stamp comparison, so its silence says nothing"
         return ;;
    esac
    case "$out" in
      *"the rule body moved"*|*"the carrier moved"*|*"AND carrier moved"*)
        bad "I79: an edit to Rule 24 was REPORTED as Rule 23 drifting — the stamp hashes more than Rule 23's own span, so every neighbouring edit will demand a re-stamp" ;;
      *)
        if [ "$rc" -ne 0 ] || [ "$n" -ne 0 ]; then
          bad "I79: an edit to Rule 24 produced rc=$rc and $n finding(s); the neighbouring rule is not the stamp's subject"
          grep '^FAIL:' <<<"$out" | cut -c1-160 | sed 's/^/          | /'
        else
          ok "I79: an edit to Rule 24, the neighbour, leaves the Rule 23 stamp silent and still stamp-bound"
        fi ;;
    esac
  fi
}

# --- I84: the story corpus location is ONE declaration ------------------------
# Four arms, because the invariant has four ways to stop meaning anything and three of them
# are SILENT. The literal it bans had four copies in the tree before it existed.

# A restatement in a shipped program is REPORTED. The mutation is the exact regression: the
# protect hook's component-keyed pattern put back the way it was, which is the copy that
# would have gone inert — a protected-path pattern matching nothing ALLOWS.
A15_i84_restatement_is_reported() {
  t="$(fresh)"
  # THE PATH IS ASSEMBLED, NOT SPELLED, and spelling it is what this fixture's own control
  # caught: I10 scores a fixture that NAMES a hook as one that DRIVES a hook, and this file
  # deliberately sits outside that set (see A04's `hookish`) because the scrub loop I10 wants
  # has an ordering hazard against values the worker wrapper has already resolved. Mutating a
  # file that happens to live under core/hooks/ is not driving a hook.
  local protect
  protect="$t/core/hooks/""ai-dlc-protect.sh"
  if edit "$protect" \
       '!done && /^  "\*\/stories\/\*\.md"$/ { print "  \"_bmad-output/planning-artifacts/stories/*.md\""; done=1; next } { print }'; then
    assert_fires "I84 a shipped program restating an area-qualified story path is REPORTED" \
                 "restate an area-qualified story corpus path"
  fi
}

# The TEMPLATE losing its sprint slot is REPORTED. This is the silent one: every sprint then
# resolves to the same directory, which is the flat cross-sprint corpus rule 2 exists to end,
# and it resolves to a directory that EXISTS — so every reader reports a full corpus and none
# of them is looking at this sprint.
A16_i84_template_without_slot() {
  t="$(fresh)"
  if edit "$t/core/schemas/sprint-status.json" \
       '!done && /"stories_dir":/ { sub(/s\{sprint\}\//, ""); done=1 } { print }'; then
    assert_fires "I84 a stories_dir template with no sprint slot is REPORTED" \
                 "does not contain its own sprint slot"
  fi
}

# A reader that takes the template and never substitutes is REPORTED. It composes a path
# containing a literal `{sprint}`, which exists nowhere, so it finds an empty corpus — and an
# empty corpus is what a clean one looks like.
A17_i84_reader_never_substitutes() {
  t="$(fresh)"
  if edit "$t/core/scripts/validate-mandatory-rules.sh" \
       '/stories_dir_sprint_placeholder/ { next } { print }'; then
    assert_fires "I84 a reader of stories_dir that never names the slot is REPORTED" \
                 "never name its sprint slot"
  fi
}

# The declaration going missing from its home is REPORTED, rather than leaving every reader
# resolving an empty template — which composes the repo root, not nothing.
A18_i84_declaration_missing() {
  t="$(fresh)"
  if edit "$t/core/schemas/sprint-status.json" \
       '/"stories_dir":/ { next } { print }'; then
    assert_fires "I84 stories_dir absent from its declared home is REPORTED" \
                 "Both are required"
  fi
}

# ---------------------------------------------------------------------------
# THE DRIVER
# ---------------------------------------------------------------------------
# --- Assertion 19: I74(b) — install.sh must still DERIVE the ship set ---------
# install.sh's fixture loop was a hand-written list of 120 names until it became a
# derivation over `core/fixtures/*/` minus `.dist-only`. The invariant that used to join
# that list against the tree could not survive the change — joining a derivation to itself
# passes for a reason unrelated to anything being right — so what replaced it is an
# assertion that the derivation is THERE. Break the tree read.
A19_i74_install_derives() {
  t="$(fresh)"
  if edit "$t/scripts/install.sh" \
       '{ gsub(/core\/fixtures\/"\*\//, "core/schemas/\"*/") } { print }'; then
    assert_fires "I74 install.sh no longer deriving the ship set from core/fixtures/ is REPORTED" \
                 "does not read core/fixtures/"
  fi
}

# --- Assertion 20: I74(b) — and must still EXCLUDE the marker -----------------
# The other half, and the one that fails in the shipping direction: a derivation that
# reads the right directory but drops the `.dist-only` guard copies every
# distribution-only fixture into the consumer's suite schedule. That is v0.230.0's defect,
# where a distribution-only battery became the reference consumer's pole, and no join can
# see it because every join resolves the same marker this loop stopped resolving.
A20_i74_install_excludes_marker() {
  t="$(fresh)"
  if edit "$t/scripts/install.sh" \
       '{ sub(/\[ -f "\$_fd\.dist-only" \] && continue/, "") } { print }'; then
    assert_fires "I74 an install derivation that stops excluding .dist-only is REPORTED" \
                 "does not exclude"
  fi
}

# --- Assertion 21: I74(d) — a `.dist-only` marker with no reason --------------
# The marker excludes a fixture from every consumer. Empty, it says nothing about why, and
# the next author cannot tell a considered exclusion from one copied by pattern-match.
# Seven of the twelve were zero bytes when this arm was written. Truncation is the
# mutation, so `edit` is not the helper — it rewrites through awk and an empty result is
# what we want.
A21_i74_marker_with_no_reason() {
  t="$(fresh)"
  local m="$t/core/fixtures/plan-shape/.dist-only"
  if [ ! -s "$m" ]; then
    bad "FIXTURE BROKEN — plan-shape/.dist-only is already empty in the seed, so truncating it is not a mutation and the assertion below would test an unchanged tree."
    return 1
  fi
  : > "$m"
  assert_fires "I74 a .dist-only marker with an EMPTY body is REPORTED" \
               "EMPTY body"
}

# --- Assertion 22: I8 — uninstall.sh's list vs the derived ship set -----------
# uninstall.sh keeps a hand-written list on purpose: it runs on a consumer where
# core/fixtures/ does not exist, and it bounds a DESTRUCTIVE loop that must not glob the
# consumer's own tests/fixtures/. That is why it is the side I8 joins now that install.sh
# derives. Drop one name and the fixture is orphaned in every consumer's tree forever.
A22_i8_uninstall_orphan() {
  t="$(fresh)"
  if edit "$t/scripts/uninstall.sh" \
       '{ sub(/ check-23-draft-stamps /, " ") } { print }'; then
    assert_fires "I8  a fixture install ships that uninstall.sh does not name is REPORTED" \
                 "uninstall.sh never names"
  fi
}

# --- Assertion 23: I85 — a backtick that runs the operator's own answer -------
# Backticks inside a double-quoted string are command substitution: the shell runs the
# quoted word and substitutes its empty output, so the word DISAPPEARS from the message
# and the sentence still reads like a sentence. Measured live as PC-S320 — four sites in
# reconcile/layer-drift.sh, every one wrapping `still-additive`, which is the VERDICT an
# operator must record to clear a BLOCKING adjudication row. The row told them a verdict
# clears the block and deleted which verdict.
A23_i85_backtick_in_message() {
  t="$(fresh)"
  if edit "$t/core/skills/ai-dlc-update/reconcile/layer-drift.sh" \
       '{ gsub(/\\`still-additive\\`/, "`still-additive`") } { print }'; then
    assert_fires "I85 an unescaped backtick inside an operator-facing message is REPORTED" \
                 "command-substitute inside an operator-facing message"
  fi
}

# --- Assertion 24: I85 — the scanner must FAIL CLOSED when blinded -----------
# THE ASSERTION THAT MATTERS MOST HERE. A23 proves the scanner sees the defect; this
# proves that a scanner which has stopped seeing it says so instead of reporting clean.
# Break the character it matches on: the invariant's own positive probe must catch that
# in the same run, because "no findings" and "an instrument that cannot find anything"
# are the same output otherwise.
A24_i85_fails_closed_when_blind() {
  t="$(fresh)"
  if edit "$t/scripts/validate-enforcement-map.sh" \
       '{ sub(/if \(c == "`" && p != "\\\\"\) \{/, "if (c == \"~\" \&\& p != \"\\\\\\\\\") {") } { print }'; then
    assert_fires "I85 a BLINDED scanner reports its own probe rather than a clean tree" \
                 "positive probe was NOT reported"
  fi
}

# --- Assertion 25: I85 — the heredoc narrowing is load-bearing ---------------
# The crude form of this scan flags SEVEN files; six are Python inside `<<'PY'` quoted
# heredocs, where the shell expands nothing and a backtick is literal. Drop the heredoc
# tracking and those six correct files enter the finding set — which is how a lint gets
# turned off. The negative probe is what refuses that, so break the skip and require it.
A25_i85_heredoc_narrowing_holds() {
  t="$(fresh)"
  if edit "$t/scripts/validate-enforcement-map.sh" \
       '{ sub(/hd != "" \{ if \(\$0 == hd\) \{ hd = ""; hdq = 0 \} ; next \}/, "hd != \"\" { if ($0 == hd) { hd = \"\" } }") } { print }'; then
    assert_fires "I85 losing the quoted-heredoc narrowing is REPORTED by its own negative probe" \
                 "negative probe WAS reported"
  fi
}

# --- Assertion 26: I33b — the two-step walk across the install split ---------
# I33 catches `$(dirname "$X")/../<subtree>/` in ONE expression. The defect does not need
# one: whole-read-pool shipped the dirname into a variable and walked up off that on the
# next line, and I33's own pattern returns ZERO on it. The parent holds in core/ and is
# SPLIT by install.sh on every consumer, so the fixture was green here and exited 2 there —
# a permanent stop on the consumer's pre-push, which is how it was found (PC-S326).
A26_i33b_two_step_walk() {
  t="$(fresh)"
  if edit "$t/core/fixtures/whole-read-pool/run.sh" \
       '{ sub(/^  SPRINT_SCHEMA="\$ROOT\/core\/schemas\/sprint-status\.json"$/, "  SPRINT_SCHEMA=\"$SCRIPTS_DIR/../schemas/sprint-status.json\"") } { print }'; then
    assert_fires "I33b a dirname VARIABLE walked up into a sibling subtree is REPORTED" \
                 "walking up from a dirname VARIABLE"
  fi
}

# --- Assertion 27b: I33b — the scan resets its state at every file boundary --
# THE BOUNDARY ONLY EXISTS BECAUSE THE SCAN IS BATCHED, AND NOTHING ELSE WATCHES IT. The
# per-file shell predicate this replaced could not have this defect: each file got its own
# process. One awk pass over the whole corpus carries `vars`, `seen` and `walk` across the
# FNR==1 boundary unless it clears them, and the failure is SILENT AND IN THE ACQUITTING
# DIRECTION — a name already marked `seen` in an earlier file never re-enters `vars[]`, so
# the later file's walk-up is never reported at all.
#
# THE CORPUS ALREADY EXERCISES IT: 14 fixture scripts declare `d` and 5 declare `_d`
# (derived from the live corpus, not typed), so name reuse across files is the normal case
# and a regression here would hide real findings rather than invent false ones.
#
# The seed puts the OFFENDER SECOND, behind a file declaring the same name, because a
# one-file seed cannot tell "scans every file" from "scans the first one".
A27b_i33b_resets_state_per_file() {
  t="$(fresh)"
  # Two files, same variable name. The FIRST declares `d` and never walks up; the SECOND
  # declares `d` and does walk up. Only the second is a finding, and it is only reachable if
  # the scan cleared `seen` at the boundary.
  mkdir -p "$t/core/fixtures/zz-i33b-reset-a" "$t/core/fixtures/zz-i33b-reset-b" 2>/dev/null
  printf 'd="$(dirname "$X")"\nS="$d/sibling.sh"\n' > "$t/core/fixtures/zz-i33b-reset-a/run.sh"
  printf 'd="$(dirname "$Y")"\nS="$d/../schemas/x.json"\n' > "$t/core/fixtures/zz-i33b-reset-b/run.sh"
  if [ ! -s "$t/core/fixtures/zz-i33b-reset-b/run.sh" ]; then
    bad "FIXTURE BROKEN — the I33b reset seed could not be written, so the assertion below would test a tree that never carried its subject."
    return
  fi
  assert_fires "I33b a walk-up in a LATER file reusing an earlier file's variable name is REPORTED" \
               "zz-i33b-reset-b"
}

# --- Assertion 27c: I33b — pattern substitution is not a directory walk ------
# THE NARROWING IS ASSERTED RATHER THAN INCIDENTAL, WHICH IS WHAT `BL-273` ASKED FOR. The
# per-file predicate this replaced spelled the brace group as `\$(\{)?VAR(\})?/\.\./`, which
# makes the opening and closing braces optional INDEPENDENTLY — so `${A/../foo}`, bash pattern
# substitution and not a directory walk at all, satisfied it as `${A` plus `/../`. That was a
# false positive. The batched program requires the brace to CLOSE before `/../`, so it is
# correct, and the two grammars therefore DISAGREE on an input no corpus file contains.
#
# THIS IS THE SILENCE HALF AND IT HAS ITS ALLOW TWIN ONE PROPERTY APART. A silence arm alone
# passes identically against a predicate that stopped matching everything, so the seed carries
# BOTH forms in one tree: the pattern-substitution file must NOT be named, and the braced
# walk-up beside it — same variable, same braces, differing only in whether the brace closes
# before `/../` — must be. A29's own remedy text is the model.
A27c_i33b_pattern_substitution_is_not_a_walk() {
  t="$(fresh)"
  mkdir -p "$t/core/fixtures/zz-i33b-patsub" 2>/dev/null
  # The near-miss: a dirname variable used in pattern substitution. Not a walk.
  printf 'A="$(dirname "$X")"\nB="${A/../foo}"\n' > "$t/core/fixtures/zz-i33b-patsub/run.sh"
  # The ALLOW TWIN: the same variable, braced, where the brace DOES close before /../
  mkdir -p "$t/core/fixtures/zz-i33b-braced" 2>/dev/null
  printf 'A="$(dirname "$X")"\nB="${A}/../schemas/x.json"\n' > "$t/core/fixtures/zz-i33b-braced/run.sh"
  if [ ! -s "$t/core/fixtures/zz-i33b-patsub/run.sh" ] || [ ! -s "$t/core/fixtures/zz-i33b-braced/run.sh" ]; then
    bad "FIXTURE BROKEN — the I33b pattern-substitution seed could not be written, so neither direction below was tested."
    return
  fi
  out="$(run_map I33b 2>&1)"
  sel_guard "$?" I33b "$out"
  # EVERY FAIL GOES THROUGH `bad`, NEVER A RAW printf. The worker's exit is `$fails`, so a FAIL
  # line printed around it leaves the worker at 0 and the parent never reads the line: this arm
  # shipped that way and would have printed FAIL inside a shard that reported PASS.
  #
  # HERE-STRINGS, NOT PIPES. A validator run is far larger than the pipe buffer, and under
  # pipefail `printf | grep -q` answers with the WRITER's EPIPE once the output after the match
  # passes it -- so both tests below would report NOT FOUND on output that contains the token,
  # permanently and with no symptom. I54 and I54b caught exactly that in the first draft of this
  # arm; the redirect goes at the end of the grep and the pipe disappears.
  if grep -q 'zz-i33b-patsub' <<< "$out"; then
    bad 'I33b named zz-i33b-patsub: `${A/../foo}` is bash pattern substitution, not a walk up into a sibling subtree, and reporting it is the false positive the batched grammar exists to have removed'
    return 1
  fi
  if ! grep -q 'zz-i33b-braced' <<< "$out"; then
    bad 'I33b did NOT name zz-i33b-braced: `${A}/../` IS a walk up from a dirname variable, so the silence above is the predicate matching nothing rather than discriminating'
    return 1
  fi
  ok 'I33b `${A/../foo}` is acquitted while `${A}/../` one property apart is REPORTED'
}

# --- Assertion 27: I33b — one predicate, and it fails closed when blinded ----
# THE ASSERTION THAT MATTERS MOST HERE. An earlier draft inlined the detection twice, so
# blinding the corpus scan left the probe passing against its own private copy — a probe
# certifying an instrument it never exercised. Scan and probe now call ONE function, so
# breaking it must surface as the probe failing, not as a clean tree.
#
# RE-ANCHORED WHEN THE PREDICATE WAS BATCHED. The mutation used to key on the per-variable
# `grep -qE` inside the old per-file shell function; that line no longer exists, and a
# mutation matching nothing is a LOST SUBJECT whose repair is a new subject rather than a
# relaxed assertion. The blinding point is now the declaration regex inside `I33B_WALK_AWK`
# — the one grammar BOTH callers execute, so blinding it is exactly the "private copy"
# failure this assertion was written for. Verified before shipping: the anchor resolves to
# exactly ONE line (control: an impossible anchor returns 0), the mutant fires this arm and
# no other, and the unmutated subject stays silent.
A27_i33b_fails_closed_when_blind() {
  t="$(fresh)"
  if edit "$t/scripts/validate-enforcement-map.sh" \
       '{ if ($0 ~ /\^\[\[:space:\]\]\*\[A-Za-z_\]\[A-Za-z0-9_\]\*="\\\$\\\(dirname/ && !done) { sub(/\/\^.*\/ \{/, "/ZZNOMATCHZZ/ {"); done=1 } } { print }'; then
    assert_fires "I33b a BLINDED predicate reports its own probe rather than a clean tree" \
                 "positive probe was NOT reported"
  fi
}

# --- Assertion 28: I86 — apply.sh must not restate the row token ------------
# layer-drift.sh declares ADJ_ROW_TOKEN and writes it into an OVERRIDE-SUPERSEDED row when a
# verdict is already recorded for that digest; apply.sh resolves that declaration and skips
# prescribing the retire sequence. A restated literal drifts silently — the case arm stops
# matching and a pull carrying an adjudicated row reads exactly like one carrying none.
A28_i86_apply_restates_token() {
  t="$(fresh)"
  if edit "$t/core/skills/ai-dlc-update/reconcile/apply.sh" \
       '{ if (!done && index($0, "ADJ_ROW_TOKEN=\"$(sed")) { print "ADJ_ROW_TOKEN=\"adjudicated\""; done=1; next } } { print }'; then
    assert_fires "I86 apply.sh restating the row token literal is REPORTED" \
                 "restates the adjudication row token literal"
  fi
}

# --- Assertion 29: I86 — the writer must still WRITE the token --------------
# The other direction, and the one that fails silently. A token with a home and no emitter
# leaves apply.sh's suppression unable to fire on any pull, forever — which is this repo's
# recurring class arriving inside the guard against it.
A29_i86_writer_stops_emitting() {
  t="$(fresh)"
  if edit "$t/core/skills/ai-dlc-update/reconcile/layer-drift.sh" \
       '{ gsub(/\$\{ADJ_ROW_TOKEN\}=/, "adjudicatedX=") } { print }'; then
    assert_fires "I86 a declared row token that is never written into a row is REPORTED" \
                 "never writes it into a row"
  fi
}

# ============================================================================
# I112 — the code-review verdict set, across its owner and the gate step that reads it
# ============================================================================
# WHY THESE LIVE HERE AND NOT IN A NEW DIRECTORY. I112's subject is an arm of
# `scripts/validate-enforcement-map.sh`, which is this fixture's subject and nothing else's;
# the fixture is already `.dist-only` for that reason, its shard partition DEALS a new
# assertion out automatically, and the read-set map already lists both of I112's subject files
# against both shards -- so these assertions run on a push that touches either of them, with no
# hand-maintained list anywhere. A twelfth fixture directory would have cost the suite a new
# unit, a `.dist-only` marker, a read-set trace only root can run, and a second copy of the
# seed, to test one arm of a validator this file already drives thirty times.
#
# THE ARM REPORTS THREE DISTINCT FINDINGS AND THEY ARE NOT INTERCHANGEABLE. Owner->reader says
# a declared member is unexplained by the step; reader->owner says the step teaches a value no
# review file can carry; the span scan says a screaming compound token in Check 1 belongs to
# neither vocabulary. Each assertion below asserts the message AND the finding COUNT, because
# a mutation moving two cells means two directions share a subject and one of them proves
# nothing -- and a substring match cannot see that.
#
# EVERY SEEDED TOKEN IS ASSEMBLED FROM PIECES, NEVER TYPED. I112's own corpus is Check 1's
# span and this repo's files; I111's header records that arm reporting ITSELF because a
# literal sat in its source. The same hazard reaches here through the RENDERED indexes: a
# fixture spelling a non-member in one piece is a file in the tree carrying that token.
#
# THE SILENCE ASSERTIONS EACH HAVE AN ALLOW TWIN ONE PROPERTY APART, which is the half that
# makes them mean anything. A33's comment-wrapped token is the same token A32 seeds in prose;
# A34's schema-enum token differs from A33's only in being a member of an enum the walker
# yields. A silence arm alone passes identically against an exclusion keyed on the right
# property and a scan that stopped matching.

# --- Assertion 30: I112 — the owner losing a member -------------------------
# Direction 2 ALONE, and the direction is not the obvious one: dropping `BLOCKED` from the
# template leaves Check 1's bullet still naming it, so the finding is "the step teaches a value
# the owner does not declare". Direction 1 cannot also fire here -- the owner's set shrank, so
# every remaining member is still named -- and the count is what says so.
A30_i112_owner_loses_a_member() {
  t="$(fresh)"
  local members last
  members="$(cr_owner_members "$t/$CR_OWNER")"
  last="$(printf '%s\n' "$members" | tail -1)"
  if [ -z "$last" ] || [ "$(printf '%s\n' "$members" | grep -c .)" -lt 3 ]; then
    bad "FIXTURE BROKEN — the \`## Verdict\` template in $CR_OWNER yielded fewer than three members, so there is no member to drop and the expected message below cannot be built."
    return
  fi
  if edit "$t/$CR_OWNER" \
       '/^[A-Z_]+( \| [A-Z_]+)+$/ && !d { sub(/[[:blank:]]*\|[[:blank:]]*[A-Z_]+$/, ""); d=1 } { print }'; then
    assert_fires_n "I112 a verdict the owner stops declaring while Check 1 still names it is REPORTED" \
                   "does not declare: $last" 1
  fi
}

# --- Assertion 31: I112 — the owner gaining a member ------------------------
# The mirror, and DIRECTION 1 alone. A fourth member in the template that Check 1 never
# explains is a value a reviewer can write and the gate has no stated behaviour for. The token
# is assembled: written whole it would be a fourth verdict name sitting in the tree.
A31_i112_owner_gains_an_untaught_member() {
  t="$(fresh)"
  local newm
  newm="DEF"; newm="${newm}ERRED"
  if edit "$t/$CR_OWNER" \
       "/^[A-Z_]+( \\| [A-Z_]+)+\$/ && !d { \$0 = \$0 \" | $newm\"; d=1 } { print }"; then
    assert_fires_n "I112 a verdict added to the owner template and never taught in Check 1 is REPORTED" \
                   "never names: $newm" 1
  fi
}

# --- Assertion 32: I112 — the motivating case, back in Check 1's prose ------
# THIS IS THE DEFECT THE ARM SHIPPED FOR. `CHANGES-REQUESTED` sat in an ordinary sentence in
# the one paragraph in the system about verdict VALUES -- not on the bullet, which is why the
# set comparison alone could never have seen it and the span scan exists. The SPAN finding
# fires and neither set direction moves, because the bullet and the template are untouched.
A32_i112_nonmember_in_check1_prose() {
  t="$(fresh)"
  local tok
  tok="CHANGES"; tok="${tok}-REQUESTED"
  if edit "$t/$CR_READER" "$(cr_after_check1 "- A sentence naming $tok.")"; then
    assert_fires_n "I112 a non-member verdict token in Check 1's PROSE is REPORTED by the span scan" \
                   "schema enum member: $tok" 1
  fi
}

# --- Assertion 33: I112 — a compound token in NO vocabulary at all ----------
# A32's token is a real historical non-member, so an exclusion narrowed to acquit everything
# EXCEPT that one string would still pass it. This one belongs to no enum, no template and no
# history: it is assembled from two ordinary words, and the arm must report it for the shape of
# the token rather than for its identity.
A33_i112_unknown_compound_in_check1_prose() {
  t="$(fresh)"
  local tok
  tok="NOT_A"; tok="${tok}_VERDICT"
  if edit "$t/$CR_READER" "$(cr_after_check1 "- A sentence naming $tok.")"; then
    assert_fires_n "I112 a screaming compound token in no vocabulary at all is REPORTED" \
                   "schema enum member: $tok" 1
  fi
}

# --- Assertion 34: I112 — the HTML-comment exclusion, A33's ALLOW twin ------
# ONE PROPERTY APART FROM A33: same token, same insertion point, wrapped in a comment. Every
# check in gate-validation.md opens with a `CHECK_LOADED` marker of exactly this shape, so an
# arm without the exclusion reports a finding on a correct tree and gets turned off. Without
# A33 beside it this assertion passes against a span scan that stopped matching anything.
#
# THE SEED IS INDENTED, AND THAT IS THE DISCRIMINATING PROPERTY RATHER THAN A DETAIL. The span
# extractor's comment address is `^[[:blank:]]*<!--`; every comment on the real tree and every
# comment the arm's own self-probe seeds sits at column zero, so the `[[:blank:]]*` is a clause
# no input anywhere exercises and its removal changes nothing observable. Measured while
# building this: narrowing the address to the `CHECK_LOADED` marker makes the arm's SELF-PROBE
# fire, so the unmutated control dies too and no assertion's kill can be attributed. An
# indented comment is a shape a markdown author writes, it keeps the baseline clean, and it is
# the only seed in this file that dies alone when that clause is dropped.
A34_i112_comment_wrapped_token_is_acquitted() {
  t="$(fresh)"
  local tok
  tok="NOT_A"; tok="${tok}_VERDICT"
  if edit "$t/$CR_READER" "$(cr_after_check1 "  <!-- $tok -->")"; then
    assert_silent "I112 the same token inside an INDENTED HTML COMMENT is acquitted (A33's twin)"
  fi
}

# --- Assertion 35: I112 — the schema-enum exclusion, also A33's twin --------
# The second ALLOW twin, one property apart in the OTHER direction: a token in ordinary prose
# exactly like A33's, differing only in being a member of an enum the renderer's own SCHEMA_PY
# walker yields. Check 1 legitimately names one today, so this exclusion is load-bearing on the
# real tree and not a hypothetical.
#
# THE TOKEN IS RUN OUT OF THE WALKER, NOT NAMED, and it is a member the span does NOT already
# carry -- see `cr_enum_unseen` for the measurement that forced the second condition. A typed
# enum member stops being one the day it is renamed, and this assertion would then fail reading
# exactly like the exclusion breaking.
A35_i112_schema_enum_token_is_acquitted() {
  t="$(fresh)"
  local tok
  tok="$(cr_enum_unseen "$t")"
  if [ -z "$tok" ]; then
    bad "FIXTURE BROKEN — render-vocabulary-index.sh's SCHEMA_PY walker yielded no screaming-compound enum member that Check 1's span does not already carry, so this assertion would re-exercise an acquittal the unmutated control already proves rather than seeding a new one."
    return
  fi
  if edit "$t/$CR_READER" "$(cr_after_check1 "- A sentence naming $tok.")"; then
    assert_silent "I112 a SCHEMA ENUM member in Check 1's prose is acquitted (A33's twin, one property apart)"
  fi
}

# --- Assertion 36: I112 — the owner's heading renamed -----------------------
# THE ZERO GUARD, and it is the one that keeps every assertion above honest. Two empty sets
# compare equal, so an owner extraction that stops matching makes both set directions report
# agreement forever. Renaming the heading is how that happens in practice -- a role file
# reorganised by someone who never heard of this arm.
A36_i112_owner_heading_renamed() {
  t="$(fresh)"
  if edit "$t/$CR_OWNER" \
       '/^## Verdict$/ && !d { $0 = $0 " Values"; d=1 } { print }'; then
    assert_fires_n "I112 an owner whose \`## Verdict\` heading moved REPORTS rather than comparing two empty sets" \
                   "could not derive the code-review verdict set: 0 member(s)" 1
  fi
}

# --- Assertion 37: I112 — the reader's bullet deleted -----------------------
# The reader-side zero, and it fails as DIRECTION 1 NAMING EVERY MEMBER rather than as its own
# guard: with the bullet gone the reader set is empty and every declared member is unexplained.
# So this asserts all three names, derived from the template rather than written here -- an
# assertion naming one of them would pass against a bullet that lost two.
A37_i112_reader_bullet_deleted() {
  t="$(fresh)"
  local members want n
  members="$(cr_owner_members "$t/$CR_OWNER")"
  n="$(printf '%s\n' "$members" | grep -c .)"
  if [ "$n" -lt 3 ]; then
    bad "FIXTURE BROKEN — the \`## Verdict\` template yielded $n member(s); the expected message below names the whole set, and a short set would make this assertion weaker than it reads."
    return
  fi
  # The message lists the set SORTED, space-separated, which is the order the arm's own
  # `LC_ALL=C sort -u` produces. Derived here the same way rather than assumed.
  want="$(printf '%s\n' "$members" | LC_ALL=C sort -u | tr '\n' ' ' | sed 's/ $//' | sed 's/^/never names: /')"
  if edit "$t/$CR_READER" '/^- \*\*Code-review verdict values/ { next } { print }'; then
    assert_fires_n "I112 deleting Check 1's \`- **Code-review verdict values\` bullet REPORTS every declared member" \
                   "$want" 1
  fi
}

# --- Assertion 38: I112 — a member named BARE on the bullet -----------------
# THE BULLET'S BACKTICK DELIMITERS, WHICH ARE INVISIBLE UNTIL SOMETHING ASSERTS THEM. The
# reader extractor takes BACKTICKED screaming tokens off the one bullet, and the delimiters are
# what stop it harvesting `FAILS` out of the surrounding prose. Stripping them from one member
# leaves the member still spelled on the line and still readable by a human -- and direction 1
# must fire anyway, because the arm reads the delimited form and nothing else. A widening of
# that grammar to bare words passes every other assertion in this file.
A38_i112_bullet_member_loses_its_delimiters() {
  t="$(fresh)"
  local members last
  members="$(cr_owner_members "$t/$CR_OWNER")"
  last="$(printf '%s\n' "$members" | LC_ALL=C sort -u | tail -1)"
  if [ -z "$last" ]; then
    bad "FIXTURE BROKEN — no member read out of the \`## Verdict\` template, so there is nothing to un-delimit on the bullet."
    return
  fi
  if ! grep -q -- "- \*\*Code-review verdict values.*\`$last\`" "$t/$CR_READER"; then
    bad "FIXTURE BROKEN — Check 1's \`- **Code-review verdict values\` bullet does not carry \`$last\` backticked, so stripping its delimiters is not the mutation this assertion describes."
    return
  fi
  if edit "$t/$CR_READER" \
       "/^- \\*\\*Code-review verdict values/ && !d { gsub(/\`$last\`/, \"$last\"); d=1 } { print }"; then
    assert_fires_n "I112 a member spelled BARE on the bullet is REPORTED — the backtick delimiters carry the reader set" \
                   "never names: $last" 1
  fi
}

# --- Assertion 39: I112 — a non-member named on the bullet ------------------
# THE QUOTE-FORM QUESTION `fixture-mutants.md` REQUIRES ASKING, answered in the direction that
# turned out to matter. The span scan's recorded limit is that a BARE SCREAMING NON-COMPOUND
# token (no hyphen, no underscore) is invisible to it -- measured, and widening is refuted
# because the span legitimately carries `FAIL` and `FAILS`. So a non-member of that shape can
# only be caught on the BULLET, by the set comparison, and every other assertion in this file
# seeds a COMPOUND token: without this one, the half of the arm that covers the uncatchable
# shape has no subject at all.
A39_i112_noncompound_nonmember_on_the_bullet() {
  t="$(fresh)"
  local tok
  tok="REJ"; tok="${tok}ECTED"
  if edit "$t/$CR_READER" \
       "/^- \\*\\*Code-review verdict values/ && !d { \$0 = \$0 \" \\\`$tok\\\` also fails it.\"; d=1 } { print }"; then
    assert_fires_n "I112 a bare non-compound non-member TAUGHT on the bullet is REPORTED by the set comparison" \
                   "does not declare: $tok" 1
  fi
}

# --- Assertion 40: I112 — the same token in PROSE is the recorded limit -----
# A39'S TWIN, AND IT ASSERTS A DOCUMENTED BLIND SPOT RATHER THAN A CAPABILITY. Same token, in
# prose instead of on the bullet: the span scan's compound grammar scores it as a non-instance
# and the arm is silent. That silence is DELIBERATE and its refutation is in the arm's header.
# It is asserted here so the limit is a measured property rather than a sentence -- and so that
# a later author widening the grammar to bare words finds this assertion failing and reads the
# refutation before shipping the false positives it predicts.
A40_i112_noncompound_nonmember_in_prose_is_the_limit() {
  t="$(fresh)"
  local tok
  tok="REJ"; tok="${tok}ECTED"
  if edit "$t/$CR_READER" "$(cr_after_check1 "- A sentence naming $tok.")"; then
    assert_silent "I112 the same bare non-compound token in PROSE is silent — the recorded limit, asserted (A39's twin)"
  fi
}

# --- Assertion 41: I112 — the enum exclusion must be DERIVED, not a typed list ---
# A WRONG IMPLEMENTATION THAT PASSES EVERYTHING ABOVE. Replace the arm's `i112_walker` /
# `i112_enum` derivation with the three enum members spelled out as literals, and every
# assertion in this file stays green: A35 derives its own seed from the CURRENT schemas, so a
# hand-list that is correct today acquits exactly what A35 seeds, today and forever. The list
# goes wrong on the release that adds a member, and nothing announces it.
#
# SO THE SEED MOVES THE POPULATION RATHER THAN THE TOKEN. It adds a FOURTH screaming-compound
# member to an enum the walker reads AND writes that token into Check 1's prose. A derived
# exclusion picks the new member up in the same run and is silent. A typed list cannot, and
# reports it -- which is the whole difference between the two implementations, invisible to
# every other assertion here.
#
# THE ENUM IS FOUND BY RUNNING THE WALKER, not by naming a schema. `cr_enum_schema` asks which
# file the walker actually reads a screaming-compound enum out of; a hand-named schema would be
# the same defect this assertion exists to catch, one level down.
#
# THE ONE-PER-LINE LAYOUT IS LOAD-BEARING AND IS PRESERVED. The register schema's own
# description says layer-drift.sh reads that array line by line. `edit_json` reparses the
# result, so a seed that broke the file would be reported as a broken fixture rather than
# scored as this assertion's kill.
A41_i112_enum_exclusion_is_derived() {
  t="$(fresh)"
  local schema tok
  schema="$(cr_enum_schema "$t")"
  if [ -z "$schema" ]; then
    bad "FIXTURE BROKEN — no schema under core/schemas/ yields a screaming-compound enum member through render-vocabulary-index.sh's walker, so there is no enum to extend and this assertion would prove nothing about how the exclusion is built."
    return
  fi
  tok="SUPERSEDED_BY"; tok="${tok}_UPSTREAM"
  # The insert is keyed on the enum's own LAST member, derived, so it cannot drift onto some
  # other array in the file and it needs no hand-named anchor.
  if ! edit_json "$t/$schema" '
import json, re, sys
p = sys.argv[1]
s = open(p).read()
tok = "SUPERSEDED_BY" + "_UPSTREAM"
m = None
for m in re.finditer(r"^(\s*)\"([A-Z]+(?:[-_][A-Z]+)+)\"\n(\s*\])", s, re.M):
    pass
assert m, "no one-per-line screaming-compound enum tail found"
s = s[:m.start()] + "%s\"%s\",\n%s\"%s\"\n%s" % (m.group(1), m.group(2), m.group(1), tok, m.group(3)) + s[m.end():]
json.loads(s)
sys.stdout.write(s)
'; then
    return
  fi
  # The new member must actually reach the walker's output, or the silence below is a silence
  # about a token that is not in any enum -- which is A33, passing under this name.
  if ! grep -qF "$tok" <<<"$(cr_enum_all "$t")"; then
    bad "FIXTURE BROKEN — the seeded fourth member is not in what render-vocabulary-index.sh's walker yields over the mutated schemas, so the silence below would be a silence about a token in NO enum. That is A33's subject, not this one."
    return
  fi
  if edit "$t/$CR_READER" "$(cr_after_check1 "- A sentence naming $tok.")"; then
    assert_silent "I112 a schema enum member added in the SAME tree is acquitted — the exclusion is derived, not a typed list"
  fi
}

# --- Assertion 42: I112 — the owner grammar is ANCHORED, like the renderer's -----
# THE SECOND WRONG IMPLEMENTATION THAT PASSES EVERYTHING ABOVE. Drop the `^`/`$` anchors from
# `i112_owner_set` -- have it `match()` the alternation anywhere on a line instead of requiring
# the line to BE one -- and every assertion above stays green, because on a tree that still has
# its template line the anchored and unanchored grammars read the same set.
#
# THEY DIVERGE ON THE TREE WHERE THE TEMPLATE IS GONE, and that tree is one edit away.
# code-reviewer.md writes the same three names a SECOND time, as a parenthesised alternation
# inside a Communication sentence. Derived over this tree: the anchored shape matches exactly
# ONE line, and the unanchored one matches that line plus the prose sentence. So deleting the
# template leaves the anchored grammar with nothing -- its zero guard fires, correctly, because
# the declaration a review file is written FROM is gone -- while the unanchored grammar
# silently harvests the SENTENCE and reports a healthy three-member set. Text about a program
# is not the program, and this is that rule with a set on the end of it.
#
# THE PRECONDITION IS ASSERTED, NOT ASSUMED. If the prose alternation is ever removed this
# stops being a discriminating seed and quietly becomes a second copy of A36, so the mutated
# owner is required to still CONTAIN an unanchored match before the verdict is read.
A42_i112_owner_grammar_is_anchored() {
  t="$(fresh)"
  local anchored unanchored
  anchored="$(grep -cE '^[A-Z_]+( \| [A-Z_]+)+$' "$t/$CR_OWNER")" || anchored=0
  if [ "$anchored" -ne 1 ]; then
    bad "FIXTURE BROKEN — $anchored line(s) in ${CR_OWNER##*/} ARE a verdict template; this assertion deletes the one template line and needs exactly one to delete."
    return
  fi
  if edit "$t/$CR_OWNER" '/^[A-Z_]+( \| [A-Z_]+)+$/ && !d { d=1; next } { print }'; then
    # THE DISCRIMINATING PROPERTY, CHECKED ON THE TREE THE VALIDATOR WILL READ. An unanchored
    # grammar must still find something here, or the two implementations agree on this input
    # and the assertion below is scored against a tree that cannot tell them apart.
    unanchored="$(grep -cE '[A-Z_]+( \| [A-Z_]+)+' "$t/$CR_OWNER")" || unanchored=0
    if [ "$unanchored" -lt 1 ]; then
      bad "FIXTURE BROKEN — with the template line deleted, ${CR_OWNER##*/} carries NO unanchored verdict alternation either, so an unanchored grammar would read zero here too. The two implementations agree on this tree and this assertion has become a second copy of A36."
      return
    fi
    assert_fires_n "I112 deleting the template line REPORTS, even though the prose alternation survives — the owner grammar is anchored" \
                   "could not derive the code-review verdict set: 0 member(s)" 1
  fi
}

# ============================================================================
# I112 — the SECOND owner: qa.md's `## Verdict` set and Check 1's QA bullet
# ============================================================================
# The arm binds two owners, each to its OWN bullet. Every assertion above seeds the code-review
# owner, so without these the QA half -- its heading refusal, both of its set directions, and
# the per-owner split that keeps the two bullets apart -- has no subject in this file.
#
# EACH ONE SCORES ITS OWN UNMUTATED CONTROL FIRST, IN THE SAME FRAME. `qa_control` runs the arm
# on the fresh copy and requires it to reach its verdict line with nothing reported; only then
# is the copy mutated. A kill recorded against a tree the arm was already reporting on is not a
# kill, and A00's control is a different process.
#
# EVERY MUTATION IS KEYED ON A BULLET'S PREFIX OR AN OWNER'S TEMPLATE LINE, NEVER ON A MEMBER.
# `NEEDS_REWORK` sits on BOTH bullets -- it is A38's sorted-last member and QA's too -- so an
# edit addressed by that token moves two subjects and scores a two-cell flip as one kill.
#
# THE CROSS-OWNER TOKENS ARE DERIVED AS SET DIFFERENCES, never typed. "A code-review member QA
# does not declare" and "a QA member code-review does not declare" are read out of the two
# templates, so the assertions stay about the other gate's vocabulary when either set moves.

# qa_control <label> — the in-frame unmutated control. Returns nonzero when it failed, so the
# caller stops before mutating a tree whose verdict was already wrong.
qa_control() {
  local before="$fails"
  assert_silent "$1"
  [ "$fails" -eq "$before" ]
}

# qa_only_in <file A> <file B> — the members of A's `## Verdict` template that B's does not
# carry, in A's template order.
qa_only_in() {
  local a b m
  a="$(cr_owner_members "$1")"; b="$(cr_owner_members "$2")"
  [ -n "$a" ] && [ -n "$b" ] || return 1
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    grep -qxF -- "$m" <<<"$b" || printf '%s\n' "$m"
  done <<<"$a"
}

# qa_bullets_present <tree> — both owner bullets are in Check 1 exactly once, or FIXTURE BROKEN.
# A bullet missing from the seed makes every mutation below match nothing or the wrong line.
qa_bullets_present() {
  local nc nq
  nc="$(grep -c '^- \*\*Code-review verdict values (' "$1/$CR_READER")" || nc=0
  nq="$(grep -c '^- \*\*QA verdict values (' "$1/$CR_READER")" || nq=0
  if [ "$nc" -ne 1 ] || [ "$nq" -ne 1 ]; then
    bad "FIXTURE BROKEN — Check 1 carries $nc code-review bullet(s) and $nq QA bullet(s) where one of each was expected, so the mutations below are not the ones they describe."
    return 1
  fi
}

# --- Assertion 58: I112 — qa.md loses its `## Verdict` heading ---------------
# The QA owner's zero guard, A36's mirror. Two empty sets compare equal, and with the heading
# gone the QA set is empty and so is nothing on the bullet's side of the comparison that could
# say so. The refusal is the QA-specific one, not the member-count one beneath it.
A58_i112_qa_owner_loses_verdict_heading() {
  t="$(fresh)"
  qa_control "I112 QA control: the unmutated copy is silent before qa.md loses \`## Verdict\`" || return 0
  if edit "$t/$QA_OWNER" '/^## Verdict$/ && !d { d=1; next } { print }'; then
    assert_fires_n "I112 qa.md losing its bare \`## Verdict\` heading REPORTS rather than comparing an empty set" \
                   "could not derive the QA verdict set: 0 member(s) read, because core/team-roles/qa.md carries no bare" 1
  fi
}

# --- Assertion 59: I112 — qa.md gains a member Check 1 does not name ---------
# The QA owner's direction 1, A31's mirror. A third QA member Check 1 never explains is a value
# QA can write and the gate has no stated behaviour for. The message names the QA owner, and the
# count says the code-review comparison did not also move.
A59_i112_qa_owner_gains_an_untaught_member() {
  t="$(fresh)"
  local newm
  newm="WAI"; newm="${newm}VED"
  qa_control "I112 QA control: the unmutated copy is silent before qa.md gains a member" || return 0
  if edit "$t/$QA_OWNER" \
       "/^[A-Z_]+( \\| [A-Z_]+)+\$/ && !d { \$0 = \$0 \" | $newm\"; d=1 } { print }"; then
    assert_fires_n "I112 a member added to qa.md's template and never named on the QA bullet is REPORTED" \
                   "core/team-roles/qa.md declares QA verdict(s) that gate-validation.md's Check 1 never names: $newm" 1
  fi
}

# --- Assertion 60: I112 — a code-review member placed on the QA bullet -------
# THE PER-OWNER SPLIT, READER SIDE. The token is a member of the code-review set, so a reader
# that POOLED the two bullets, or an owner set built as the union, would read it as declared and
# stay silent. Per owner, the QA bullet teaches a value qa.md does not declare.
A60_i112_cr_member_on_the_qa_bullet() {
  t="$(fresh)"
  local tok
  qa_bullets_present "$t" || return 0
  tok="$(qa_only_in "$t/$CR_OWNER" "$t/$QA_OWNER" | head -1)"
  if [ -z "$tok" ]; then
    bad "FIXTURE BROKEN — no code-review verdict is outside qa.md's set, so there is no other-gate member to put on the QA bullet."
    return
  fi
  qa_control "I112 QA control: the unmutated copy is silent before \`$tok\` is put on the QA bullet" || return 0
  if edit "$t/$CR_READER" \
       "/^- \\*\\*QA verdict values \\(/ && !d { \$0 = \$0 \" \\\`$tok\\\` also passes it.\"; d=1 } { print }"; then
    assert_fires_n "I112 a code-review member written on the QA bullet is REPORTED against qa.md — the bullets are compared per owner" \
                   "names QA verdict value(s) core/team-roles/qa.md does not declare: $tok" 1
  fi
}

# --- Assertion 61: I112 — a QA member placed on the code-review bullet -------
# A60's mirror: the QA-only member on the code-review bullet. Same pooled-reader blindness, the
# other owner's message.
A61_i112_qa_member_on_the_cr_bullet() {
  t="$(fresh)"
  local tok
  qa_bullets_present "$t" || return 0
  tok="$(qa_only_in "$t/$QA_OWNER" "$t/$CR_OWNER" | head -1)"
  if [ -z "$tok" ]; then
    bad "FIXTURE BROKEN — no QA verdict is outside code-reviewer.md's set, so there is no other-gate member to put on the code-review bullet."
    return
  fi
  qa_control "I112 QA control: the unmutated copy is silent before \`$tok\` is put on the code-review bullet" || return 0
  if edit "$t/$CR_READER" \
       "/^- \\*\\*Code-review verdict values \\(/ && !d { \$0 = \$0 \" \\\`$tok\\\` also passes it.\"; d=1 } { print }"; then
    assert_fires_n "I112 a QA member written on the code-review bullet is REPORTED against code-reviewer.md — the bullets are compared per owner" \
                   "names code-review verdict value(s) core/team-roles/code-reviewer.md does not declare: $tok" 1
  fi
}

# --- Assertion 62: I112 — the two bullets merged into one --------------------
# The QA bullet's text is appended to the code-review bullet and its own line deleted, which is
# what a tidy-up into "one verdict-values bullet" looks like. TWO findings, and both are true:
# the code-review bullet now teaches the QA-only member, and the QA owner has no bullet, so every
# QA member is unnamed. The count is 2 by construction, so both messages are asserted -- one
# message at that count would leave the other cell unread.
A62_i112_bullets_merged_into_one() {
  t="$(fresh)"
  local extra qall
  qa_bullets_present "$t" || return 0
  extra="$(qa_only_in "$t/$QA_OWNER" "$t/$CR_OWNER" | LC_ALL=C sort -u | tr '\n' ' ' | sed 's/ $//')"
  qall="$(cr_owner_members "$t/$QA_OWNER" | LC_ALL=C sort -u | tr '\n' ' ' | sed 's/ $//')"
  if [ -z "$extra" ] || [ -z "$qall" ]; then
    bad "FIXTURE BROKEN — the QA template yielded no member outside the code-review set (got '$extra') or no member at all (got '$qall'), so the expected messages cannot be built."
    return
  fi
  qa_control "I112 QA control: the unmutated copy is silent before the two bullets are merged" || return 0
  if edit "$t/$CR_READER" '
       /^- \*\*Code-review verdict values \(/ && !c { c = NR; cl = $0; next }
       /^- \*\*QA verdict values \(/ && !q { q = 1; sub(/^- \*\*QA verdict values \([^)]*\)\*\* — /, ""); cl = cl " " $0; next }
       c && !p && NR > c { print cl; p = 1 }
       { print }
       END { if (c && !p) print cl }'; then
    if grep -q '^- \*\*QA verdict values (' "$t/$CR_READER"; then
      bad "FIXTURE BROKEN — the merge left a QA bullet in Check 1, so this is not the merged-bullet tree."
      return
    fi
    assert_fires_n "I112 merging the bullets REPORTS the QA-only member as undeclared by code-reviewer.md" \
                   "names code-review verdict value(s) core/team-roles/code-reviewer.md does not declare: $extra" 2
    assert_fires_n "I112 merging the bullets REPORTS every QA member as unnamed — qa.md has no bullet of its own" \
                   "core/team-roles/qa.md declares QA verdict(s) that gate-validation.md's Check 1 never names: $qall" 2
  fi
}

# --- Assertion 63: I112 — a QA member added to code-reviewer.md's template ---
# THE PER-OWNER SPLIT, OWNER SIDE, and A31 with a token that discriminates. The QA bullet names
# this token, so a comparison pooling the two bullets would read it as named; per owner, the
# code-review bullet does not, and the code-review owner's direction 1 fires.
A63_i112_qa_member_in_cr_template() {
  t="$(fresh)"
  local tok
  tok="$(qa_only_in "$t/$QA_OWNER" "$t/$CR_OWNER" | head -1)"
  if [ -z "$tok" ]; then
    bad "FIXTURE BROKEN — no QA verdict is outside code-reviewer.md's set, so there is no QA member to add to the code-review template."
    return
  fi
  qa_control "I112 QA control: the unmutated copy is silent before \`$tok\` joins code-reviewer.md's template" || return 0
  if edit "$t/$CR_OWNER" \
       "/^[A-Z_]+( \\| [A-Z_]+)+\$/ && !d { \$0 = \$0 \" | $tok\"; d=1 } { print }"; then
    assert_fires_n "I112 a QA member added to code-reviewer.md's template is REPORTED as unnamed on the code-review bullet" \
                   "core/team-roles/code-reviewer.md declares code-review verdict(s) that gate-validation.md's Check 1 never names: $tok" 1
  fi
}

# ============================================================================
# I117 — the `--cite` verdict set, across its emitter and every reader that compares it
# ============================================================================
# Same home as I112, for I112's reason: the subject is an arm of the validator this fixture
# already drives, and the shard partition deals new assertions out by itself.
#
# EVERY SEEDED TOKEN IS ASSEMBLED, AND HERE THAT IS NOT STYLE. I117's reader scan walks every
# `.sh` under core/ for a QUOTED verdict-shaped literal, and this file is one of them: a typed
# non-member in a quoted string here would be a finding against the real tree. `"${CV_NM}..."`
# carries a `$` after the quote and the scan's grammar cannot read it.
#
# THREE FINDINGS AND THREE FIRING ASSERTIONS, each moving exactly one cell, plus two ALLOW
# twins one property away from A49 -- the reader-compare finding is the one with an absence
# shape on the real tree, so it is the one that needs the twins.
CV_OWNER="core/scripts/validate-steering-budget.sh"
CV_READER="core/scripts/validate-escalation-resolution.sh"
CV_NM="NO"; CV_NM="${CV_NM}MATCH"
# The awk program that inserts one line ABOVE the block's final plain `NOMATCH` emitter, the
# last statement in the `if (CITE) {` block -- so the inserted line is inside the block.
cv_insert_in_block() {
  printf '%s' "BEGIN { q = sprintf(\"%c\", 34) } /^  console\\.log\\(\"${CV_NM}\"\\); process\\.exit\\(2\\);\$/ && !d { print $1; d = 1 } { print }"
}
cv_append() { # <line built with q as the quote> -> awk program appending it
  printf '%s' "BEGIN { q = sprintf(\"%c\", 34) } { print } END { print $1 }"
}

# --- Assertion 46: I117 — the motivating drift ----------------------------
# The owner renames the member validate-adversarial-convergence.sh exact-compares. That
# compare can then never be true and the acquittal it guards becomes a deny, with every gate
# green before this arm. One finding: the stray compare. The rename stays in the verdict shape,
# so finding 2 cannot also fire.
A46_i117_compared_member_renamed() {
  t="$(fresh)"
  local was now
  was="${CV_NM}-NO-RECORDS"; now="${CV_NM}-EMPTY-CORPUS"
  if edit "$t/$CV_OWNER" "{ sub(/\"${was}\" :/, \"\\\"${now}\\\" :\") } { print }"; then
    assert_fires_n "I117 renaming the member a reader exact-compares REPORTS the reader's dead compare" \
                   "validate-adversarial-convergence.sh:" 1
  fi
}

# --- Assertion 47: I117 — an emitter the grammar cannot spell --------------
A47_i117_variable_emitter() {
  t="$(fresh)"
  if edit "$t/$CV_OWNER" "$(cv_insert_in_block '"  if (z) { console.log(cv_v); process.exit(2); }"')"; then
    assert_fires_n "I117 a console.log of a variable inside the --cite block is REPORTED, not dropped" \
                   "prints no literal verdict" 1
  fi
}

# --- Assertion 48: I117 — a member outside the verdict shape ---------------
# A NEW emitter rather than a rename, so no reader compares it and the stray finding cannot
# also fire: the off-shape cell moves alone.
A48_i117_offshape_member() {
  t="$(fresh)"
  if edit "$t/$CV_OWNER" "$(cv_insert_in_block '"  if (z) { console.log(" q "Unverified" q "); process.exit(2); }"')"; then
    assert_fires_n "I117 a verdict outside the MATCH / NOMATCH-<WORD> shape is REPORTED" \
                   "shape: Unverified" 1
  fi
}

# --- Assertion 49: I117 — a reader comparing a non-member ------------------
A49_i117_reader_compares_nonmember() {
  t="$(fresh)"
  local tok
  tok="${CV_NM}-NOT-A-VERDICT"
  if edit "$t/$CV_READER" "$(cv_append "\"[ \" q \"\$o\" q \" = \" q \"${tok}\" q \" ] && :\"")"; then
    assert_fires_n "I117 a core script comparing --cite stdout against a non-member is REPORTED" \
                   "compares ${tok};" 1
  fi
}

# --- Assertion 50: I117 — A49's ALLOW twin: the same compare of a NEW member -
# One property apart from A49: the token is now a member, because the owner prints it inside
# the block. A scan that reported every quoted verdict-shaped literal would fire here.
A50_i117_new_member_compared_is_silent() {
  t="$(fresh)"
  local tok
  tok="${CV_NM}-NOT-A-VERDICT"
  if edit "$t/$CV_OWNER" "$(cv_insert_in_block "\"  if (z) { console.log(\" q \"${tok}\" q \"); process.exit(2); }\"")" \
     && edit "$t/$CV_READER" "$(cv_append "\"[ \" q \"\$o\" q \" = \" q \"${tok}\" q \" ] && :\"")"; then
    assert_silent "I117 the same compare is silent once the owner emits the token (A49's twin)"
  fi
}

# --- Assertion 51: I117 — A49's second ALLOW twin: the token UNQUOTED -------
# One property apart from A49 the other way: the same non-member, same file, no quotes -- a
# comment mentioning a verdict. This is the narrowing that took the false-positive set to
# zero, asserted so it cannot be widened back without a red here.
A51_i117_unquoted_mention_is_silent() {
  t="$(fresh)"
  local tok
  tok="${CV_NM}-NOT-A-VERDICT"
  if edit "$t/$CV_READER" "$(cv_append "\"# ${tok} is only mentioned here\"")"; then
    assert_silent "I117 the same non-member UNQUOTED in a comment is silent (A49's twin)"
  fi
}

# ============================================================================
# I118 — a mapped fixture's read-set rows carry the core/hooks/ paths it names
# ============================================================================
# The seed copies `core scripts .githooks templates` and no read-set map, and has no `.git`, so
# I118 stands its corpus scan down on the pristine tree -- which is what A00 runs. Each assertion
# below therefore WRITES a map into its own copy, in the generator's format, plus one synthetic
# fixture directory, and only then mutates. Writing the map is the world; the `edit` that
# follows is the mutation, under the usual `cmp -s` guard.
#
# THE HOOK PATH IS ASSEMBLED, NEVER TYPED. I118 scans this file: it is a mapped fixture's run.sh,
# and a typed `core/hooks/<name>.sh` on a code line here would demand a row for that hook in this
# fixture's own read set.
RS_FX="zz-i118-probe"
RS_HOOK="ai-dlc-continue.sh"
RS_CORE="core/hooks/"; RS_CORE="${RS_CORE}${RS_HOOK}"
RS_UP="../../hooks/"; RS_UP="${RS_UP}${RS_HOOK}"
# rs_world <run.sh line> [<seed.sh line>] — the synthetic fixture and a map carrying its row.
rs_world() {
  mkdir -p "$t/core/fixtures/$RS_FX"
  printf '%s\n' "$1" > "$t/core/fixtures/$RS_FX/run.sh"
  [ -z "${2:-}" ] || printf '%s\n' "$2" > "$t/core/fixtures/$RS_FX/seed.sh"
  printf '# GENERATED by derive-fixture-readsets.sh -- DO NOT EDIT BY HAND.\n%s\t%s\n%s\t%s\n' \
    "$RS_FX" "core/fixtures/$RS_FX/run.sh" "$RS_FX" "$RS_CORE" > "$t/.ai-dlc-fixture-readsets.tsv"
}
rs_drop_row() { printf '%s' "!(\$1 == \"$RS_FX\" && \$2 == \"$RS_CORE\") { print }"; }

# --- Assertion 52: I118 — the motivating omission ---------------------------
# A mapped fixture runs a core hook from run.sh and its rows lose that hook. Exactly one finding.
A52_i118_row_omitted() {
  t="$(fresh)"
  rs_world "bash \"\$D_ROOT/${RS_CORE}\" < in.json"
  if edit "$t/.ai-dlc-fixture-readsets.tsv" "BEGIN { FS = \"\\t\" } $(rs_drop_row)"; then
    assert_fires_n "I118 a mapped fixture whose rows omit a core hook its run.sh runs is REPORTED" \
                   "$RS_FX omits $RS_CORE" 1
  fi
}

# --- Assertion 53: I118 — A52's ALLOW twin: the same line as a COMMENT ------
# One property apart from A52: the identical path, row likewise dropped, on a comment line. The
# comment rule is the narrowing that took 22 comment-only mentions out of the false-positive
# set, asserted so it cannot be widened back without a red here.
A53_i118_commented_mention_is_silent() {
  t="$(fresh)"
  rs_world "  # bash \"\$D_ROOT/${RS_CORE}\" < in.json"
  if edit "$t/.ai-dlc-fixture-readsets.tsv" "BEGIN { FS = \"\\t\" } $(rs_drop_row)"; then
    assert_silent "I118 the same core hook path on a comment line is silent with its row dropped (A52's twin)"
  fi
}

# --- Assertion 54: I118 — the hook resolved in seed.sh, not in run.sh -------
# run.sh names the hook only in a message; seed.sh resolves it through `../../hooks/`. This is
# the postcompact-rulebook-recovery shape, and it dies if seed.sh leaves the corpus or the
# `../..` spelling leaves the grammar.
A54_i118_seed_resolved_omission() {
  t="$(fresh)"
  rs_world "echo \"FAIL: ${RS_HOOK} did not fire\"" "HOOK=\"\$HERE/${RS_UP}\""
  if edit "$t/.ai-dlc-fixture-readsets.tsv" "BEGIN { FS = \"\\t\" } $(rs_drop_row)"; then
    assert_fires_n "I118 a hook resolved in seed.sh through ../../hooks/ with no row is REPORTED" \
                   "$RS_FX omits $RS_CORE (named at core/fixtures/$RS_FX/seed.sh:1)" 1
  fi
}

# ============================================================================
# I54 — the shell walk prunes .claude/worktrees/ by its exact path (BL-401)
# ============================================================================
# `.claude/worktrees/` holds gitignored agent worktrees, each a full checkout carrying a
# builder's UNCOMMITTED work, and a run from the main checkout once failed I54b on one of them.
# The walk I54 and I54b share now prunes "$REPO_ROOT/.claude/worktrees" by -path. Three
# assertions: the pruned offender is silent, the same offender one directory over still fires,
# and a committed mutant restoring the unpruned find line makes the pruned offender fire again.
#
# THE OFFENDER IS ASSEMBLED, NEVER TYPED. I54 scans every `.sh` in the tree, this file included,
# so a literal of the banned idiom on a code line here would be a finding against the real tree.
# It sits under `scripts/` in each seeded directory, never under a `hooks/` directory, so I118
# does not read the seeded path as a core hook.
WT_Q="'"; WT_FMT="${WT_Q}%""s${WT_Q}"
WT_LINE="if printf ${WT_FMT} \"\$v\" | grep -q TOKEN; then :; fi"
wt_seed() { # <dir relative to the tree root>
  mkdir -p "$t/$1/scripts"
  printf '%s\n' '#!/usr/bin/env bash' 'v=x' "$WT_LINE" > "$t/$1/scripts/zz.sh"
}
# The mutation: the find line as it was before BL-401, pruning `.git` alone. Matched by index()
# on the exact prune clause, not by a regex, so the escapes in the line are taken literally.
WT_UNPRUNE='$0 ~ /^i54_files=/ { s = "\\( -name .git -o -path \"$REPO_ROOT/.claude/worktrees\" \\) -prune"; i = index($0, s); if (i) $0 = substr($0, 1, i - 1) "-name .git -prune" substr($0, i + length(s)) } { print }'

# --- Assertion 55: I54 — an offender under .claude/worktrees/ is silent ------
A55_i54_agent_worktree_offender_is_silent() {
  t="$(fresh)"
  wt_seed ".claude/worktrees/agent-x"
  assert_silent "I54 an offender inside .claude/worktrees/agent-x/ is not scanned (BL-401)"
}

# --- Assertion 56: I54 — A55's twin one directory over: .claude/worktrees-not/ -
# One property apart from A55: the same offender in a sibling whose name merely STARTS with
# `worktrees`. A prune keyed on a name prefix or a glob would silence this too.
A56_i54_worktrees_sibling_still_fires() {
  t="$(fresh)"
  wt_seed ".claude/worktrees-not"
  assert_fires_n "I54 the same offender in .claude/worktrees-not/ is still REPORTED (A55's twin)" \
                 ".claude/worktrees-not/scripts/zz.sh:3:" 1
}

# --- Assertion 57: I54 — the unpruned find line, as a committed mutant ------
# Whole-tree copy (`fresh`), offender under agent-x. POSITIVE CONTROL FIRST, on the same tree
# unmutated: the run must reach its verdict line silent, so a validator that is broken for its
# own reasons cannot score the mutant below as a kill. Then `edit` restores the old find line
# under its `cmp -s` guard, and the agent-x offender must be reported.
A57_i54_unpruned_find_mutant_reports_worktree() {
  t="$(fresh)"
  wt_seed ".claude/worktrees/agent-x"
  local before="$fails"
  assert_silent "I54 mutant control: the unmutated copy is silent on the agent-x offender"
  [ "$fails" -eq "$before" ] || return 0
  if edit "$t/scripts/validate-enforcement-map.sh" "$WT_UNPRUNE"; then
    assert_fires_n "I54 mutant: restoring the unpruned find line REPORTS the agent-x offender" \
                   ".claude/worktrees/agent-x/scripts/zz.sh:3:" 1
  fi
}

# THE ASSERTION LIST IS DERIVED FROM THIS FILE'S OWN DEFINITIONS, in source order. A
# hand-written list here would be this fixture's own subject defect one level out: an
# assertion dropped from the list runs nothing and prints nothing, and a suite reporting 14
# greens instead of 15 reads exactly like a suite that passed. The zero guard is the same
# argument -- a naming grammar that stops matching yields an empty list, and an empty list
# passes every assertion it never made.
#
# THE OPTIONAL LETTER IS LOAD-BEARING. The grammar was `^A[0-9]{2}_`, and A27b and A27c were
# defined, commented, cited by a backlog receipt as the guard on their fix -- and never
# dispatched by either shard. `--run-one` ran them fine, which is how a hand-run "proven both
# ways" was recorded against an arm the suite had never executed.
NAMES="$(grep -oE '^A[0-9]{2}[a-z]?_[a-z0-9_]+\(\) \{' "$0" | sed 's/() {$//')"
N_LISTED="$(printf '%s\n' "$NAMES" | grep -c . || true)"
if [ "$N_LISTED" -lt 10 ]; then
  echo "FIXTURE ERROR: derived $N_LISTED assertion(s) from this file — the A<nn>_ naming grammar moved" >&2
  exit 2
fi

# EVERY DEFINED ASSERTION IS A DISPATCHED ASSERTION, AND THE TWO SIDES USE DIFFERENT GRAMMARS
# ON PURPOSE. A count taken with the enumerator's own regex agrees with the enumerator by
# construction -- 46 against 46 under the grammar that dropped A27b/A27c -- so it could never
# fire. This side is deliberately LOOSE: any function whose name starts `A<digit>`, with or
# without `function`, indentation or spacing before `()`. A definition the strict enumerator
# cannot spell (a second letter, an uppercase tail, a `function` keyword) is counted here and
# missed there, and the run refuses rather than shipping an arm that runs nowhere.
#
# False-positive set measured before shipping: EMPTY. On the tree that added this guard the
# loose grammar and the widened enumerator both read 48, and no helper in this file starts
# with `A<digit>` (the helpers are lowercase). The shard partition check below then closes
# the chain: defined == listed here, listed - 1 == dealt there.
N_DEFINED="$(grep -cE '^[[:space:]]*(function[[:space:]]+)?A[0-9][A-Za-z0-9_]*[[:space:]]*\(\)' "$0" || true)"
if [ "$N_DEFINED" -ne "$N_LISTED" ]; then
  echo "FIXTURE BROKEN: this file DEFINES $N_DEFINED assertion function(s) but the enumerator lists $N_LISTED." >&2
  echo "  The difference is defined, reads as coverage, and is dispatched by no shard. Rename it to A<nn>[a-z]_i<id>_<what> or widen the enumerator." >&2
  exit 2
fi

# `--run-one <assertion>` is one assertion, in one process, against one freshly seeded
# tree. It is the unit the pool schedules and it is also how a human runs a single
# assertion while working on it.
#
# IT RUNS ONLY WHAT THE SHARDS WOULD. A name that is a defined function but not in $NAMES is
# refused, so a hand-run of an undispatched arm fails instead of printing `ok` for a guard the
# suite never executes.
if [ "${1:-}" = "--run-one" ]; then
  FN="${2:-}"
  declare -F "$FN" >/dev/null 2>&1 || {
    echo "FIXTURE ERROR: --run-one needs an assertion function name; '$FN' is not one" >&2
    exit 2
  }
  case "
$NAMES
" in
    *"
$FN
"*) ;;
    *) echo "FIXTURE ERROR: '$FN' is defined but is not in the dispatched assertion list, so no shard runs it; a hand-run here would certify a guard the suite never executes" >&2
       exit 2 ;;
  esac
  seed_tree
  trap 'rm -rf "$PRISTINE" "$WORK"' EXIT
  : > "$WORK/calls"
  "$FN"
  fn_rc=$?
  # AN ASSERTION THAT RETURNED NONZERO WITHOUT CHARGING `bad` IS A FAILURE, NOT A PASS. The
  # worker's exit below is `$fails`; an arm that printed its own FAIL and returned 1 used to
  # exit 0 here, and the parent reads FAIL lines only from a nonzero worker.
  if [ "$fn_rc" -ne 0 ] && [ "$fails" -eq 0 ]; then
    bad "$FN returned $fn_rc without charging a failure through bad — its verdict is unknown, so it is not a pass"
  fi

  # THE POSITIVE CONTROL THAT SELECTION ACTUALLY HAPPENED, and it is here rather than only in
  # the parent because this is the process that made the calls.
  #
  # A conversion that silently stops selecting must turn the fixture RED, not merely make it
  # slow. Both sides are derived from the same string: what this assertion SHOULD have done
  # comes from its own name, what it DID comes from run_map's ledger. An assertion declaring
  # an id must have made at least one selected call and no full one; A00, which declares
  # none, must have made no selected call at all.
  #
  # It stands down when the assertion has already failed. An assertion whose mutation could
  # not be built returns before it ever reaches the validator, and charging that a second
  # line here would entangle two findings in one already-red run.
  sel_n="$(grep -c '^s ' "$WORK/calls" || true)"
  full_n="$(grep -c '^f$' "$WORK/calls" || true)"
  want="$(arm_id_of "$FN")"
  [ -z "${EMD_OUT:-}" ] || printf '%s %s\n' "$sel_n" "$full_n" > "$EMD_OUT/$FN.sel"
  if [ "$fails" -eq 0 ]; then
    if [ -n "$want" ]; then
      if [ "$sel_n" -lt 1 ] || [ "$full_n" -ne 0 ]; then
        bad "FIXTURE BROKEN — $FN declares $want but made $sel_n selected and $full_n whole-file validator run(s). A whole-file run contains this assertion's message whatever the selector did, so it would print ok either way."
      fi
    elif [ "$sel_n" -ne 0 ]; then
      bad "FIXTURE BROKEN — $FN declares no arm id, so its claim is an ABSENCE over every arm and it must run the WHOLE file; it made $sel_n selected run(s), which say nothing about the arms they did not run."
    fi
  fi
  [ "$fails" -eq 0 ] || exit 1
  exit 0
fi

# ---------------------------------------------------------------------------
# THE SHARD SPLIT, AND IT IS A MEASUREMENT RATHER THAN A PREFERENCE
# ---------------------------------------------------------------------------
# The pre-push suite is POLE-BOUND: its makespan tracks its single longest unit, and the
# unit is a DIRECTORY, because `core/fixtures/*/run.sh` is what the outer pool schedules.
# This directory sat on the suite's top shelf -- 452s in `.git/ai-dlc-fixture-durations`
# against a 173s next-longest outside that shelf -- and the inner pool below could not change
# it, because an inner pool moves work off the wall clock only while there are free cores and
# the outer pool has already taken them. Run ALONE from the repo root it costs 136s of wall
# clock and ~930 CPU-seconds; that solo figure and the 452s are NOT comparable, because the
# recorded one is measured under the 16-way outer pool.
#
# So the fixture is SHARDED ACROSS DIRECTORIES, which is the same move and the same reason
# as the sibling `enforcement-map-sites`. Each shard is a directory the outer pool can start
# independently and interleave with everything else.
#
# TWO, NOT THREE. Every shard re-pays the control's validator run in full, so each further
# shard adds a fixed cost to what the machine computes while removing a smaller slice from
# this directory's critical path -- and the added concurrency inflates every other unit's
# loaded cost at the same time. Two takes the largest available cut and pays that fixed cost
# once.
#
# ROUND-ROBIN, NOT CONTIGUOUS HALVES. These assertions differ by an order of magnitude in
# cost -- several seed a tree and run the validator once, a few run it over rebuilt trees --
# so a contiguous cut puts the expensive neighbours in one shard and rebuilds the pole inside
# it. Dealing them out in turn spreads that without anyone having to maintain a cost table
# that would go stale the first time an assertion changed.
#
# EVERY SHARD RUNS THE CONTROL. A00 is the arm that says the validator is not simply broken,
# and a shard without it would report its own assertions as kills earned against a tree
# nobody checked. It costs one validator run per shard and it is not optional.
SHARDS="a b"

# THE SHARD ARRIVES AS AN ARGUMENT, NOT AS AN ENVIRONMENT VARIABLE, and the reason here is
# NOT the sibling's. That file scrubs every ambient AI_DLC_* name near its top for I10, so a
# tunable would be unset before it could be read; this file carries no scrub at all (it
# assembles its one hook token rather than spelling it, and its worker wrapper is named EMD_*
# for the reason at the pool below). The reason the argument form is used HERE is that the two
# fixtures share ONE shard protocol: the same --group parse, the same membership guard, the
# same coverage join, the same round-robin partition. A protocol spelled two ways is two
# grammars to keep in step, and the shard driver beside this directory is written against the
# argument form. Keeping them identical is what lets either file's shard machinery be read
# as evidence about the other's.
GROUP=a
if [ "${1:-}" = "--group" ]; then
  GROUP="${2:-}"
  [ -n "$GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; }
fi
case " $SHARDS " in
  *" $GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;;
esac

# THE COVERAGE JOIN. Sharding moves assertions out of this directory, so the failure mode it
# introduces is a shard whose directory is deleted, renamed, or never installed: the suite
# then runs fewer assertions and reports a shorter green run, which is this repository's
# named recurring defect wearing a new hat. Shard `a` therefore DERIVES the set of shards
# that actually exist beside it and refuses to pass if any declared shard has no driver.
# The control is the same grep finding this file's own sibling directories at all.
if [ "$GROUP" = a ]; then
  missing=""
  for _s in $SHARDS; do
    [ "$_s" = a ] && continue
    [ -f "$HERE/../enforcement-map-derivations-$_s/run.sh" ] || missing="$missing $_s"
  done
  if [ -n "$missing" ]; then
    echo "FIXTURE ERROR: shard(s)$missing declared in SHARDS have no driver directory beside this one." >&2
    echo "  Their assertions would run NOWHERE, and this suite would report a shorter green run." >&2
    exit 2
  fi
fi

NAME="enforcement-map-derivations"
[ "$GROUP" = a ] || NAME="enforcement-map-derivations-$GROUP"

echo "$NAME:"

OUT="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$OUT"' EXIT
SELF="$HERE/$(basename "$0")"

# The control, first and alone. Its verdict licenses every assertion after it, so a failure
# here stops the run rather than reporting fourteen unattributable kills.
CTL="$(printf '%s\n' "$NAMES" | head -1)"
EMD_OUT="$OUT" bash "$SELF" --run-one "$CTL" > "$OUT/$CTL" 2>"$OUT/$CTL.err"
ctl_rc=$?
cat "$OUT/$CTL"
if [ "$ctl_rc" -ne 0 ]; then
  [ -s "$OUT/$CTL.err" ] && cat "$OUT/$CTL.err" >&2
  echo
  echo "$NAME: 1 assertion(s) FAILED" >&2
  exit 2
fi

# FOUR, and the arithmetic is the whole reason. This pool nests inside the pre-push suite's
# own pool, so a knob here multiplies against a knob there and the product is what lands on
# the machine. This fixture used to be ONE directory at 8 wide; it is now TWO directories,
# and the outer pool starts both. Two directories x 4 = the same 8 cores this fixture
# demanded before the split, so the split buys wall clock without raising the load the rest
# of the suite is scheduled against.
#
# The worker wrapper's two variables are NOT named AI_DLC_*. I10 requires a fixture that
# drives a hook to scrub every ambient AI_DLC_* name, and a scrub is a `unset` loop that
# would have to be ordered ahead of values this wrapper has already resolved -- the sibling
# carries exactly that ordering hazard in a comment. This fixture assembles its one hook
# token rather than spelling it, so it is outside I10's set today; naming these two outside
# the AI_DLC_ namespace means it stays correct if that ever changes.
JOBS=4
# Deal the non-control assertions out to the shards in turn. The partition is DERIVED from
# the same list the control came off, so an assertion added to this file lands in a shard
# automatically rather than needing a table updated in a second place.
printf '%s\n' "$NAMES" | tail -n +2 \
  | awk -v g="$GROUP" -v shards="$SHARDS" '
      BEGIN { n = split(shards, S, " ") }
      { if (S[((NR - 1) % n) + 1] == g) print }
    ' > "$OUT/list"
N_MINE="$(grep -c . "$OUT/list" || true)"
if [ "$N_MINE" -eq 0 ]; then
  echo "$NAME: FIXTURE ERROR — shard '$GROUP' was dealt no assertions out of $N_LISTED; an empty shard passes every assertion it never made" >&2
  exit 2
fi

# THE PARTITION IS A PARTITION, AND IT IS ASSERTED RATHER THAN ASSUMED. The coverage join
# above proves every declared shard has a DRIVER; it says nothing about whether the deal
# reaches every assertion. An off-by-one in the round-robin index, or a shard name in
# $SHARDS that the awk never emits, drops assertions on the floor in EVERY shard at once —
# and every shard then prints a shorter green run, which is exactly the failure this file
# exists to catch one level out. So shard `a` re-runs the same partition for every value of
# $SHARDS and requires the counts to sum to the non-control total. Shard `a` alone can
# compute it because the partition is a pure function of $NAMES and $SHARDS, both of which
# every shard holds.
if [ "$GROUP" = a ]; then
  dealt=0
  for _s in $SHARDS; do
    _n="$(printf '%s\n' "$NAMES" | tail -n +2 \
          | awk -v g="$_s" -v shards="$SHARDS" '
              BEGIN { n = split(shards, S, " ") }
              { if (S[((NR - 1) % n) + 1] == g) print }
            ' | grep -c . || true)"
    dealt=$((dealt + _n))
  done
  if [ "$dealt" -ne "$((N_LISTED - 1))" ]; then
    echo "$NAME: FIXTURE ERROR — the shards $SHARDS were dealt $dealt assertions between them, but this file defines $((N_LISTED - 1)) non-control assertions." >&2
    echo "  The difference runs NOWHERE, in every shard, and each shard still reports a green run." >&2
    exit 2
  fi
fi
EMD_SELF="$SELF" EMD_OUT="$OUT" \
  xargs -P "$JOBS" -I{} bash -c '
    n="$1"
    bash "$EMD_SELF" --run-one "$n" \
      > "$EMD_OUT/$n" 2> "$EMD_OUT/$n.err"
    printf %s $? > "$EMD_OUT/$n.rc"
  ' _ {} < "$OUT/list"

# Rendered in SOURCE order, never completion order, so the output is byte-comparable
# against the serial version and diffable across runs.
#
# A MISSING VERDICT IS A FAILURE, not a gap. Serially, an assertion that never ran could
# not print an `ok` -- the loop and the report were the same thing. With a pool they are
# not, and a dropped job is silent. So the verdict file's absence is asserted, and a worker
# that exited nonzero without printing a FAIL line (a crash, a failed seed) is charged one
# rather than counted as clean.
while IFS= read -r n; do
  [ -n "$n" ] || continue
  if [ ! -f "$OUT/$n.rc" ]; then
    printf '  FAIL  %s produced no verdict — the pool dropped work, and a short green run reads exactly like a passing one\n' "$n"
    fails=$((fails + 1))
    continue
  fi
  cat "$OUT/$n"
  [ -s "$OUT/$n.err" ] && cat "$OUT/$n.err" >&2
  wrc="$(cat "$OUT/$n.rc")"
  # 2 IS NOT 1. `FIXTURE BROKEN` (a failed seed, an unbuildable mutant) and `an assertion
  # regressed` are different answers. Routing an assertion through a worker would otherwise
  # collapse them: the parent sees a nonzero rc, charges one assertion and exits 1 —
  # reporting a regression where the truth is that nothing was tested.
  if [ "$wrc" = "2" ]; then broken=1; fi
  if [ "$wrc" != "0" ]; then
    c="$(grep -c '^  FAIL' "$OUT/$n" || true)"
    [ "$c" -gt 0 ] || { printf '  FAIL  %s exited nonzero without an assertion line — the assertion did not run to a verdict\n' "$n"; c=1; }
    fails=$((fails + c))
  fi
done < "$OUT/list"

# THE SELECTION JOIN, ACROSS THIS SHARD'S WHOLE DISPATCHED SET.
#
# Each worker checks its own ledger; this checks that every worker reached that check and
# that the number which selected is the number that was supposed to. Both sides are derived:
# the expected count from the A<nn>_i<id>_ naming grammar over the names this shard actually
# ran, the actual count from the ledgers those runs wrote. Nothing here is a written-down
# number, so an assertion added or renamed moves both sides together.
#
# THE ZERO GUARD IS THE POINT OF THE FIRST ARM. If the naming grammar moved, no name declares
# an id, the expected count and the actual count are both zero, and a join of 0 against 0
# passes -- a check that cannot fire, which is the defect this whole file exists to catch.
# So an empty expected set is itself the failure.
#
# These lines print only on failure, so a green run is byte-identical to the whole-file
# version this replaced.
{ printf '%s\n' "$CTL"; cat "$OUT/list"; } > "$OUT/ran"
sel_expect=0
sel_actual=0
sel_nofile=""
while IFS= read -r n; do
  [ -n "$n" ] || continue
  [ -z "$(arm_id_of "$n")" ] || sel_expect=$((sel_expect + 1))
  if [ ! -f "$OUT/$n.sel" ]; then
    sel_nofile="$sel_nofile $n"
    continue
  fi
  s="$(cut -d' ' -f1 < "$OUT/$n.sel")"
  [ -n "$s" ] && [ "$s" -ge 1 ] && sel_actual=$((sel_actual + 1))
done < "$OUT/ran"

if [ "$sel_expect" -eq 0 ]; then
  printf '  FAIL  the selection join has NO SUBJECT — not one assertion this shard ran declares an arm id, so the A<nn>_i<id>_ naming grammar moved and every count below is zero against zero\n'
  fails=$((fails + 1))
elif [ -n "$sel_nofile" ]; then
  printf '  FAIL  no selection ledger from:%s — the assertion never reached its own selection control, so whether it selected an arm is unknown\n' "$sel_nofile"
  fails=$((fails + 1))
elif [ "$sel_actual" -ne "$sel_expect" ]; then
  printf '  FAIL  %s of %s id-declaring assertion(s) selected their arm — the rest ran something else, and a whole-file run prints ok whatever the selector did\n' "$sel_actual" "$sel_expect"
  fails=$((fails + 1))
fi

echo
if [ "$broken" -ne 0 ]; then
  echo "$NAME: FIXTURE BROKEN — an assertion could not run to a verdict" >&2
  exit 2
fi
if [ "$fails" -eq 0 ]; then
  echo "$NAME: PASS"
  exit 0
fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
