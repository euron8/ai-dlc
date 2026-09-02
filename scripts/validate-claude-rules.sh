#!/usr/bin/env bash
set -uo pipefail

# validate-claude-rules.sh -- the join between CLAUDE.md and `.claude/rules/*.md`
#
# Distribution-only. `.claude/rules/` here holds THIS repo's authoring rulebook; it is
# not installed onto a consumer and install.sh never writes that path.
#
# WHY THIS EXISTS. Splitting narrow prose out of CLAUDE.md into path-scoped rule files
# creates three failure modes that did not exist while the prose was in one file, and
# every one of them is silent:
#
#   A1  a tracked path under `.claude/` that is not a rule file. `.gitignore` was
#       narrowed from `.claude/` to `.claude/*` + negations so rule files could be
#       committed at all; that narrowing is what makes a hook artifact committable, so
#       the narrowing has to be bounded by something that runs.
#   A2  a `paths:` glob matching NOTHING. The rule then never loads, and a rule that
#       never loads reads exactly like a rule that is being obeyed.
#   A3  frontmatter using `globs:` / `description:` / `alwaysApply:` / `apply:` instead
#       of `paths:`. MEASURED on the CC 2.1.226 loader: `paths` is the ONLY key
#       consulted, so such a file is silently UNCONDITIONAL -- resident in every
#       session forever -- while reading to a human exactly like a scoped rule. This is
#       Cursor's `.mdc` schema leaking into Claude Code's `.md` one.
#   A4  a pointer in CLAUDE.md naming a rule file that does not exist, and its inverse,
#       a rule with neither a CLAUDE.md pointer nor a `<!-- no-stub: reason -->`
#       marker. audit-rule-files.sh's pointer scan cannot see either: it excludes
#       CLAUDE.md from its targets and restricts its sources to the skill tree.
#
# EVERY ARM CARRIES A SELF-PROBE, and the probe runs BEFORE the corpus. An arm that
# reports "0 findings" without first proving it can produce 1 has established that it
# ran, not that the corpus is clean -- which is the defect this repo names most often.
# The probe trees are built under mktemp and are never the real corpus.
#
# usage:  validate-claude-rules.sh [--quiet]
# exit 0 = all arms pass;  1 = at least one finding;  2 = usage/environment error

QUIET=0
for a in "${@:-}"; do
  case "$a" in
    ""|--quiet) [ "$a" = "--quiet" ] && QUIET=1 ;;
    *) echo "usage: validate-claude-rules.sh [--quiet]" >&2; exit 2 ;;
  esac
done

# Resolve the root by walking UP for a marker, never by counting `..` hops -- this
# script must give the same answer from the repo root and from a fixture sandbox.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/VERSION" ]; do ROOT="$(dirname "$ROOT")"; done
if [ ! -f "$ROOT/VERSION" ]; then
  echo "validate-claude-rules: FAIL -- could not resolve repo root (no VERSION marker above $0)" >&2
  exit 2
fi
cd "$ROOT" || exit 2

fail=0
say() { [ "$QUIET" = "1" ] || printf '%s\n' "$*"; }
err() { printf 'FAIL: %s\n' "$*" >&2; fail=1; }

RULES_DIR=".claude/rules"

# ---------------------------------------------------------------------------
# Shared derivations. `rule_files` is the SAME polarity the loader uses: recursive,
# `.md` only. Deriving it once means the arms below cannot disagree about the corpus.
# ---------------------------------------------------------------------------
rule_files() { find "$RULES_DIR" -type f -name '*.md' 2>/dev/null | LC_ALL=C sort; }

# Emit `<file>\t<glob>` for every entry of every `paths:` block. Parses only the
# frontmatter (between the first two `---` lines), so a `paths:` in prose is not a glob.
rule_globs() {
  local f
  for f in $(rule_files); do
    awk -v F="$f" '
      NR==1 && $0=="---" { infm=1; next }
      infm && $0=="---"  { exit }
      infm && /^paths:[[:space:]]*$/ { inp=1; next }
      infm && inp && /^[[:space:]]*-[[:space:]]*/ {
        g=$0; sub(/^[[:space:]]*-[[:space:]]*/,"",g); gsub(/^["'"'"']|["'"'"']$/,"",g)
        if (g != "") print F "\t" g; next
      }
      infm && inp && /^[^[:space:]-]/ { inp=0 }
    ' "$f"
  done
}

# The frontmatter keys of one file, one per line.
fm_keys() {
  awk 'NR==1 && $0=="---" {infm=1; next}
       infm && $0=="---" {exit}
       infm && /^[A-Za-z_][A-Za-z0-9_-]*:/ {k=$0; sub(/:.*/,"",k); print k}' "$1"
}

# ---------------------------------------------------------------------------
# A1 -- every TRACKED path under `.claude/` is a rule file.
# ---------------------------------------------------------------------------
a1_offenders() { git ls-files -- '.claude' | grep -vE '^\.claude/rules/.*\.md$' || true; }

probe="$(mktemp -d)"; trap 'rm -rf "$probe"' EXIT
(
  cd "$probe" && git init -q . && mkdir -p .claude/rules
  printf 'x\n' > .claude/rules/ok.md && printf 'x\n' > .claude/settings.json
  git add -A -f >/dev/null 2>&1
  git ls-files -- '.claude' | grep -vE '^\.claude/rules/.*\.md$'
) > "$probe/out" 2>/dev/null
if ! grep -q 'settings.json' "$probe/out"; then
  err "A1's own probe did not fire: a tracked \`.claude/settings.json\` was NOT reported. The extraction is broken, so the corpus result below would be an empty set produced by a scan that cannot find an offender -- indistinguishable from a clean tree."
else
  off="$(a1_offenders)"
  if [ -n "$off" ]; then
    err "A1: tracked path(s) under .claude/ that are not \`.claude/rules/**/*.md\`. The .gitignore narrowing exists ONLY to admit rule files; anything else here is a hook artifact that .gitignore:19-24 was written to keep out:"
    printf '  %s\n' $off >&2
  else
    say "  A1  ok  -- tracked .claude/ paths are rule files only (probe fired)"
  fi
fi

# ---------------------------------------------------------------------------
# A2 -- no `paths:` glob matches an empty set.
# Uses git's OWN pathspec matching, because the loader matches with gitignore
# semantics against repo-root-relative paths. `fnmatch` would disagree on `**`.
# ---------------------------------------------------------------------------
glob_matches() { git ls-files -- ":(glob)$1" 2>/dev/null | head -1; }

if [ -n "$(glob_matches 'core/fixtures/**')" ] && [ -z "$(glob_matches 'core/fixture/**')" ]; then
  : # probe fired: a real glob matches, a typo'd one does not
else
  err "A2's own probe did not fire: \`core/fixtures/**\` must match and \`core/fixture/**\` (typo) must not. Got match=[$(glob_matches 'core/fixtures/**')] typo=[$(glob_matches 'core/fixture/**')]. Every orphan-glob verdict below is then unreadable."
fi
while IFS=$'\t' read -r f g; do
  [ -z "${f:-}" ] && continue
  if [ -z "$(glob_matches "$g")" ]; then
    err "A2: $f declares \`paths:\` glob '$g' which matches NO tracked path. That rule can never load, and a rule that never loads reads exactly like one that is being obeyed."
  fi
done < <(rule_globs)
[ "$fail" = "0" ] && say "  A2  ok  -- every paths: glob matches at least one tracked path (probe fired)"

# ---------------------------------------------------------------------------
# A3 -- frontmatter uses `paths:`, never a Cursor-schema key.
# ---------------------------------------------------------------------------
BAD_KEYS='^(globs|description|alwaysApply|apply|rule-type)$'
printf -- '---\nglobs:\n  - "x/**"\n---\nbody\n' > "$probe/a3bad.md"
printf -- '---\npaths:\n  - "x/**"\n---\nbody\n'  > "$probe/a3good.md"
if ! grep -qE "$BAD_KEYS" <<<"$(fm_keys "$probe/a3bad.md")"; then
  err "A3's own probe did not fire: a frontmatter \`globs:\` key was not extracted. The key scan is broken and the corpus verdict below is vacuous."
elif grep -qE "$BAD_KEYS" <<<"$(fm_keys "$probe/a3good.md")"; then
  err "A3's own probe misfired: a correct \`paths:\` frontmatter was reported as a Cursor key. The scan discriminates nothing."
else
  for f in $(rule_files); do
    bad="$(fm_keys "$f" | grep -E "$BAD_KEYS" || true)"
    if [ -n "$bad" ]; then
      err "A3: $f frontmatter carries $(echo $bad | tr '\n' ' ')-- Claude Code consults ONLY \`paths:\`. This file is silently UNCONDITIONAL: resident in every session, while reading like a scoped rule. (That is Cursor's .mdc schema, not this one.)"
    fi
  done
  say "  A3  ok  -- no Cursor-schema frontmatter keys (probe fired both ways)"
fi

# ---------------------------------------------------------------------------
# A4 -- pointers resolve, and every rule is reachable (pointer OR no-stub marker).
# ---------------------------------------------------------------------------
pointers() { grep -oE '\.claude/rules/[A-Za-z0-9._/-]+\.md' CLAUDE.md 2>/dev/null | LC_ALL=C sort -u; }

if ! grep -qE '\.claude/rules/[A-Za-z0-9._/-]+\.md' <<<'see .claude/rules/zzz-probe.md here'; then
  err "A4's own probe did not fire: the pointer pattern did not match a literal \`.claude/rules/zzz-probe.md\`. Both directions below are unreadable."
else
  for p in $(pointers); do
    [ -f "$p" ] || err "A4: CLAUDE.md points at \`$p\`, which does not exist. A dangling pointer here is caught by nothing else -- audit-rule-files.sh excludes CLAUDE.md from its pointer targets and restricts its sources to the skill tree."
  done
  for f in $(rule_files); do
    if ! grep -qxF "$f" <<<"$(pointers)"; then
      if ! grep -q '<!-- *no-stub:' "$f"; then
        err "A4: $f has no CLAUDE.md pointer and no \`<!-- no-stub: <reason> -->\` marker. Its trigger may never fire and nothing names it -- invisible in both channels. Add the pointer, or declare in the marker why the read trigger suffices."
      elif ! grep -qE '<!-- *no-stub:[[:space:]]*[^[:space:]>-]' "$f"; then
        err "A4: $f carries an EMPTY \`no-stub:\` marker. A marker with no reason is a decision nobody can audit -- the same rule .dist-only markers are held to."
      fi
    fi
  done
  say "  A4  ok  -- pointers resolve; every rule has a pointer or a reasoned no-stub (probe fired)"
fi

# ---------------------------------------------------------------------------
# A3b -- a rule file declares its scope EXACTLY ONCE: either a `paths:` block, or a
# `<!-- unconditional: <reason> -->` marker. Never neither, never both.
#
# WHY THIS BECAME NECESSARY. While every rule file was scoped, an absent `paths:` key
# could only be an accident. It is now also a DELIBERATE declaration: a rule file with no
# `paths:` is re-injected on every compaction (`load_reason:"compact"`, measured), which
# is the only channel that survives one -- so the authoring rulebook deliberately puts
# its unscoped rules there. Those two states are byte-indistinguishable in the file, and
# they differ by a cost paid on every compaction of every session. The marker is what
# separates them, and it is held to the same non-empty-reason rule as `.dist-only` and
# `no-stub`: a resident-forever decision nobody wrote a reason for is unauditable.
# ---------------------------------------------------------------------------
# HERE-STRING, NOT A PIPE (I54/I54b). `fm_keys | grep -q` feeds a reader that leaves at its
# first match while the writer is still pushing; under `pipefail` the pipeline then answers
# with the writer's EPIPE and reports NOT-FOUND on frontmatter that contains the key. It is a
# size threshold, not a race -- correct until the output after the match fills the pipe
# buffer, then wrong permanently and silently. Both sites here were written as pipes and the
# invariant caught them at push.
has_paths_key() { grep -qx 'paths' <<<"$(fm_keys "$1")"; }
has_uncond()    { grep -q '<!-- *unconditional:' "$1"; }

printf -- '---\npaths:\n  - "x/**"\n---\nbody\n'            > "$probe/a3b_scoped.md"
printf -- '<!-- unconditional: because reasons -->\nbody\n'  > "$probe/a3b_uncond.md"
printf -- 'body only, no declaration\n'                      > "$probe/a3b_neither.md"
if has_paths_key "$probe/a3b_scoped.md" && ! has_uncond "$probe/a3b_scoped.md" \
   && has_uncond "$probe/a3b_uncond.md" && ! has_paths_key "$probe/a3b_uncond.md" \
   && ! has_paths_key "$probe/a3b_neither.md" && ! has_uncond "$probe/a3b_neither.md"; then
  for f in $(rule_files); do
    # A3 OWNS THE CURSOR-KEY CASE, and this arm stands down for it. A file carrying
    # `globs:` has MISdeclared its scope, not failed to declare one, and both arms firing
    # on one mutation makes neither attributable -- the entanglement the mutation battery
    # exists to catch. A3's message is the one that names the actual repair.
    if grep -qE "$BAD_KEYS" <<<"$(fm_keys "$f")"; then continue; fi
    p=0; u=0
    has_paths_key "$f" && p=1
    has_uncond "$f" && u=1
    if [ "$p" = "0" ] && [ "$u" = "0" ]; then
      err "A3b: $f declares no scope. It has no \`paths:\` block, so the loader treats it as UNCONDITIONAL and re-injects it on every compaction of every session -- but nothing here says that was intended. Add \`paths:\`, or declare \`<!-- unconditional: <reason> -->\`."
    elif [ "$p" = "1" ] && [ "$u" = "1" ]; then
      err "A3b: $f carries BOTH a \`paths:\` block and an \`<!-- unconditional: -->\` marker. The loader obeys \`paths:\` and the marker is then a false claim about when this file loads."
    elif [ "$u" = "1" ] && ! grep -qE '<!-- *unconditional:[[:space:]]*[^[:space:]>-]' "$f"; then
      err "A3b: $f carries an EMPTY \`unconditional:\` marker. Resident-in-every-session is the most expensive declaration in this repo and it is the one nobody can audit without a reason."
    fi
  done
  say "  A3b ok  -- every rule declares its scope exactly once (probe fired all three ways)"
else
  err "A3b's own probe did not fire: scoped/unconditional/neither were not told apart. The scope verdicts below are vacuous."
fi

# ---------------------------------------------------------------------------
# A5 -- every invariant cited as a MECHANISM names one that exists.
#
# THE DEFECT, measured: CLAUDE.md cited **I88** twice as the thing binding it to
# `.claude/rules/`. No arm has ever carried that ID -- the invariant is this script, arms
# A1-A4 -- and `CHANGELOG.md` and `docs/plans/claude-rules-adoption.md` both already
# recorded the deviation. The rulebook contradicted its own changelog for five releases
# because nothing joined its citations to what exists.
#
# THE GRAMMAR IS THE FILE'S OWN, AND IT PREDATES THIS ARM. A bold **I<n>** is how this
# rulebook names a live mechanism; a backticked `I<n>` is how it discusses a literal
# token. Measured against the pre-fix CLAUDE.md, the bold form yields exactly I33, I66
# and I88 -- one true positive and two live controls, false-positive set EMPTY. The
# backtick form is not an exemption bolted on for this arm; it is what the file already
# did, and it is the only way to write about a retired ID at all.
#
# THE LIVE SET IS READ, NOT RE-DERIVED. docs/invariant-index.md is rendered from the arm
# headers and byte-compared at an earlier pre-push step, so consuming it here means one
# extractor rather than two that can disagree.
# ---------------------------------------------------------------------------
INDEX="docs/invariant-index.md"
live_ids() { grep -oE '^\| I[0-9]+[a-c]? \|' "$INDEX" 2>/dev/null | tr -d '| ' | LC_ALL=C sort -u; }
bold_ids() { grep -ohE '\*\*I[0-9]+[a-c]?\*\*' "$@" 2>/dev/null | tr -d '*' | LC_ALL=C sort -u; }

LIVE="$(live_ids)"
if [ ! -f "$INDEX" ]; then
  err "A5: $INDEX is missing, so no citation can be checked. This fails rather than passing: an absent index and a clean corpus produce the same silence."
elif [ -z "$LIVE" ]; then
  err "A5: parsed ZERO invariant IDs out of $INDEX. The row grammar changed. An empty live set makes every citation look dead OR every citation look fine depending on the comparison direction, so this fails closed."
else
  printf 'cites **I99999** and **%s**\n' "$(printf '%s\n' "$LIVE" | head -1)" > "$probe/a5.md"
  probe_bad="$(bold_ids "$probe/a5.md" | grep -vxF -f <(printf '%s\n' "$LIVE") || true)"
  if [ "$probe_bad" != "I99999" ]; then
    err "A5's own probe did not fire: a bold **I99999** beside a live ID should report exactly I99999, got [$probe_bad]. Every citation verdict below is unreadable."
  else
    for f in CLAUDE.md $(rule_files); do
      dead="$(bold_ids "$f" | grep -vxF -f <(printf '%s\n' "$LIVE") || true)"
      if [ -n "$dead" ]; then
        err "A5: $f cites $(printf '%s' "$dead" | tr '\n' ' ')as a live mechanism, and no arm declares it. Cite the invariant that exists, or if you are writing ABOUT a retired id use backticks, which is what the surrounding prose already does."
      fi
    done
    say "  A5  ok  -- every bold invariant citation resolves against $INDEX ($(printf '%s\n' "$LIVE" | grep -c .) live) (probe fired)"
  fi
fi

# ---------------------------------------------------------------------------
# A6 -- the compaction-durable channel has a ceiling.
#
# CLAUDE.md and every unconditional rule file are re-injected on EVERY compaction of
# EVERY session. That is the only channel that survives a compaction, and it was the only
# channel in this repo with no budget at all: `validate-reattach-budget.sh` is
# `--skill`-scoped to SKILL.md's recovery region and measures nothing here.
#
# MEASURED IN BYTES, NOT ESTIMATED TOKENS, deliberately. The re-attach budget divides by a
# bytes-per-token figure calibrated on SKILL.md; that divisor under-counts prose-heavy
# files, and importing it here would import a calibration taken over a different
# population. Bytes are what this arm can actually observe.
#
# THE CEILING IS A POLICY NUMBER, NOT A MEASUREMENT, and it is the operator's to set;
# `AI_DLC_DURABLE_BYTES` overrides it the way AI_DLC_REATTACH_BUDGET overrides that one.
#
# IT HAS BEEN RAISED ONCE AND THAT IS THE INTERESTING PART. The first value was picked
# before the rulebooks it was meant to bound had been written -- an estimate of six files at
# the then-current per-file mean. The files landed larger, and the arm fired on the very
# change that created them. It was raised to the measured channel plus modest headroom,
# because the alternative was cutting rule prose to fit a number invented before the prose
# existed, and `.claude/rules/resident-context.md` establishes that rule text here is not
# trimmed for byte cost.
#
# RAISING IT A SECOND TIME TO ADMIT NEW PROSE IS HOW THIS GUARD BECOMES DECORATIVE. The
# number exists so that growth in the one channel re-injected on every compaction of every
# session is a decision somebody makes, rather than a drift nobody measures. When this fires,
# the first question is what can be MECHANIZED or SCOPED out of the channel -- a rule with an
# enforcer belongs in the enforcer's header, and a rule whose work reliably begins with a
# matching read belongs behind `paths:`. Raising the ceiling is the last resort, not the
# first, and it is the operator's call rather than the author's.
#
# IT HAS NOW BEEN RAISED A SECOND TIME, 40960 -> 43520, ON AN OPERATOR RULING, AND THE
# PARAGRAPH ABOVE IS THE STANDARD IT WAS HELD TO RATHER THAN A RULE IT BROKE.
#
# THE FIGURE WAS RULED TWICE, AND THE SECOND TIME IS THE INSTRUCTIVE ONE. 43008 was approved
# against an author's ESTIMATE that the incoming rules needed 1300-1600 bytes. Written at the
# terseness where each still carries the measurement that justifies it, they needed 2628, and
# the channel landed 156 over the ceiling that had just been approved for it. The author's
# estimate was the error, not the rules -- so the ceiling moved again rather than the prose
# being ground down to fit a number invented before it existed, which is the same reasoning
# that produced the FIRST raise and is recorded above. An estimate of prose you have not yet
# written is a hypothesis; cost it after drafting, not before.
#
# Seven prose-only rules had accumulated with no durable carrier. Both prior remedies were
# asked first and both were EXHAUSTED, which is the precondition the paragraph above states:
#   - MECHANIZED: none can be. Each fires inside a tool call -- a backgrounded `sleep`, a
#     parallel tool block, a count read off a rendering -- or is a judgement about a
#     population. Nothing in a tracked file expresses any of them, so no arm can scan for one.
#   - SCOPED: barred. `resident-context.md` forbids scoping a PROSE-ONLY rule, because a
#     `paths:` file is not re-injected after a compaction and is therefore silently deleted
#     from every session that has compacted once. Scoping these would hide them, not carry them.
#
# AND THE SUBTRACTION POOL WAS MEASURED BEFORE THE RAISE, NOT ASSUMED. Every section of
# `CLAUDE.md` and of the six rulebooks was tested against `resident-context.md`'s three
# vestigial clauses -- mechanism nameable, instruction authoritative elsewhere, inbound
# references grepped with a control. 82% of `CLAUDE.md` and 100% of the rulebooks FAILED at
# least one clause. The defensible set was 384 measured bytes against a need of ~1300-1600,
# and the one block large enough to close the gap alone declares its own enforcer to be THE
# READER, which cannot be vestigial by construction.
#
# THE 384 BYTES WERE STILL CUT, and that is the half that keeps this guard honest. Raising the
# ceiling while leaving defensible vestigial prose resident is precisely the decorative
# outcome this header warns about, so the raise and the trade were taken together.
#
# RAISED A THIRD TIME, 43520 -> 44544, ON AN OPERATOR RULING, FOR ONE RULE COSTING 722 BYTES.
# `tool-hazards.md` gained "The Bash tool's OUTPUT is rewritten before you read it": a
# compressor edits text inside Bash results, code included, and it returned
# `[ -n "${A_ESC:-}" || continue` for a line that reads `[ -n "${A_ESC:-}" ] || continue`.
# Both prior remedies were asked first and both were exhausted, as this header requires. It
# cannot be MECHANIZED: the corruption happens in the tool call, and no tracked file carries
# a trace of it for an arm to scan. It cannot be SCOPED: it is prose-only, and
# `resident-context.md` bars scoping those because a `paths:` file is silently absent from
# every session that has compacted once. It is admitted at full length rather than trimmed
# because it corrupts the one input every other reading is derived from, and the corrupted
# form is syntactically valid -- the failure it prevents is a confident wrong answer, which
# is the class this whole channel exists for. The bump is 1024 bytes and leaves 345 free.
#
# RAISED A FOURTH TIME, 44544 -> 45377, ON AN OPERATOR RULING, FOR TWO RULES COSTING 831 BYTES.
# THIS ONE CARRIED NO SUBTRACTION, AND THAT IS WHAT SEPARATES IT FROM THE THREE ABOVE. The
# operator was shown the cheaper sequence this header mandates -- measure today's vestigial
# pool, then try to mechanize -- and ruled to raise without it, having been told in the same
# breath that an unearned raise is how this guard becomes decorative. Recorded as the standard
# it did NOT meet, so the next author does not read four raises as four precedents.
#
# The two rules are batch 9's: `verification-discipline.md` gains "a receipt that reads a
# RENDERED artifact is closable by prose" -- a receipt keyed on a generated index row whose
# cell renders from an unvalidated COMMENT returned 0 for three names appended to that one
# line, with nothing else changed -- and `tool-hazards.md` gains "a delegate's CLOSING SUMMARY
# can be stale", measured on a hand that reported four defects as outstanding after they were
# fixed. Neither can be SCOPED: both are prose-only, which `resident-context.md` bars. The
# receipt rule is plausibly MECHANIZABLE as an arm over `docs/backlog.md`, and that was offered
# and declined for now; if it is ever built, this raise is the one to hand back.
#
# THE ESTIMATE WAS WRONG AGAIN, BY A FACTOR OF TWO -- 400 bytes quoted, 831 measured after
# drafting. That is the second time an author's pre-drafting estimate has moved this number,
# and it is why the figure above is a measurement and the prose was not ground down to meet
# the quote. Cost prose after writing it, never before.
#
# RAISED A FIFTH TIME, 45377 -> 45900, ON AN OPERATOR RULING, FOR ONE RULE COSTING 520 BYTES.
# THE SUBTRACTION WAS OFFERED AND DECLINED AGAIN, WHICH IS NOW THE PATTERN AND NOT THE
# EXCEPTION -- two raises running have carried none, and a guard that only ever moves upward is
# on its way to decorative. The next author should read this block as four precedents for
# raising and ZERO for the sequence the header mandates.
#
# The rule is `verification-discipline.md`'s "an entry with two subjects expires only when both
# do", earned at v0.417.0 by the triage sweep over all 64 live backlog entries. Two verifiers
# attacking one proposed close agreed on EVERY measurement and split on what the entry CLAIMED:
# the named fix was real and the cited code genuinely gone, while a second subject one paragraph
# down was untouched. The close was rejected on scope, not on evidence. It cannot be SCOPED --
# it is prose-only, which `resident-context.md` bars, and the hands that need it are SUBAGENTS,
# whose reads never reach the parent that dispatches them. It is not plausibly MECHANIZABLE
# either: the predicate is "enumerate the distinct claims in an entry's prose", and no arm
# parses that. Unlike the fourth raise, there is no mechanization to hand this one back to.
#
# THE ESTIMATE WAS RIGHT THIS TIME, because it was made the way the line above prescribes --
# the rule was drafted first, measured at 520 bytes with `wc -c`, and the ceiling set from the
# measurement. That is the header's own instruction working; record it as the first raise that
# followed it.
# ---------------------------------------------------------------------------
#
# RAISED A SIXTH TIME, 45900 -> 47600, FOR FOUR RULES COSTING 1700 BYTES, AND THIS IS THE SIXTH
# CONSECUTIVE RAISE CARRYING NO SUBTRACTION. The block above predicted exactly that and called a
# guard that only ever moves upward "on its way to decorative". It is right, and this raise does
# not refute it.
#
# WHAT WAS ATTEMPTED, SO THE NEXT AUTHOR KNOWS WHICH SUBTRACTION IS STILL OWED. The four rules
# were drafted, measured at 2131 bytes, then rewritten denser and re-measured at 1700 -- a 20%
# cut taken from the NEW prose, which is the header's own sequence working. What was NOT done is
# a vestigial sweep of the EXISTING channel. That is the subtraction the header actually asks
# for, and it was skipped deliberately rather than missed: `resident-context.md` permits cutting
# only text whose enforcing mechanism can be NAMED and whose instruction lives authoritatively
# elsewhere, and requires grepping for inbound references before each cut. Done carelessly under
# time pressure that deletes scar tissue, which is strictly worse than a raise.
#
# The four rules, each earned at v0.421.0 by batch 12 and each prose-only, so none may be SCOPED:
# "count a suite's distinct input SHAPES, not its arms" (a wrong fix passed a self-probe, a
# receipt and 21 mutants because all three seeded the duplicate adjacent to the original);
# "point a search grammar at its own subject before trusting its zero" (two grammars in one sweep
# scored their own subject as a non-instance); the unobservable-property clause in
# `mechanism-design.md`; and the subagent report-file hook in `tool-hazards.md`. The first three
# are needed by SUBAGENTS, whose reads never reach the parent, which bars scoping independently.
#
# ---------------------------------------------------------------------------
#
# RAISED A SEVENTH TIME, 47600 -> 48100, FOR ONE RULE COSTING 477 BYTES, ON AN EXPLICIT OPERATOR
# RULING. The subtraction is STILL OWED and this is the seventh consecutive raise without one.
#
# WHAT IS DIFFERENT THIS TIME, AND IT IS ONLY PROCEDURAL: the choice was put to the operator as
# three costed options -- raise, subtract first, or do not carry it -- with the shortfall measured
# (477 bytes against 27 free) before the question was asked rather than after. They chose the
# raise knowing a vestigial sweep had NOT been attempted. So this raise is a decision on record
# rather than a default taken under time pressure, which is the only respect in which it improves
# on the sixth.
#
# THE RULE: "a receipt that accepts TWO candidate fixes has established neither", folded into the
# existing receipt section of `verification-discipline.md` rather than opening a new one. Earned
# at v0.423.0/v0.424.0 -- `BL-033` said in its own text that its receipt "takes either fix", and
# it did: one of the two was an arm reorder that answers ALREADY-AT-THEIRS for both a consumer
# that has the exec bit and one that still needs it. It carries a second clause because the two
# were learned together: once an entry ROTATES, its receipt is archived and inert while the
# FIXTURE still runs, so a proposed receipt-weakness must be scored against the fixture before it
# is read as a coverage gap. Measured at v0.424.0 -- four implementations satisfied one receipt
# and the fixture killed three of them; only the fourth was a real gap.
#
# Prose-only, so it may NOT be scoped, and it is exactly the kind of judgment a subagent
# adjudicating a receipt needs -- which bars `paths:` independently of the prose-only bar.
#
# ---------------------------------------------------------------------------
#
# RAISED AN EIGHTH TIME, 48100 -> 48800, FOR ONE RULE COSTING 690 BYTES, ON AN EXPLICIT OPERATOR
# RULING. The subtraction is STILL OWED and this is the eighth consecutive raise without one.
# The choice was put as three costed options -- raise, sweep for a 640-byte subtraction first, or
# leave the rule uncarried -- with the shortfall measured (690 bytes against 50 free) before the
# question was asked, and with it stated that no vestigial sweep had been attempted.
#
# THE RULE: "a validator that resolves its own root ignores the probe tree you built for it", in
# `tool-hazards.md`. Earned at v0.428.0 and it cost real work: `report-propagation-fanout.sh` and
# `validate-gate-adjudication.sh` both `cd` to a root found by walking up from the SCRIPT's own
# directory, so a `mktemp` probe repo entered with `cd` is discarded and the run answers about the
# DISTRIBUTION. Two of six receipts were scored against the wrong tree before a control caught it,
# and the first fanout receipt read green with a worklist citing `docs/backlog.archive.md`.
#
# WHY IT CANNOT BE SCOPED, AND THE ANSWER IS NOT THE PROSE-ONLY BAR THIS TIME. There IS a
# mechanism nearby -- `I33`/`I33b` fail the push on a fixture reaching a core subtree by walking
# up -- but it binds the VALIDATOR's own path resolution, not the caller's probe. The failure here
# happens in an ad-hoc tool call, against a copy under `mktemp`, in a tree no gate scans; that is
# the whole subject of `tool-hazards.md` and the reason that file has no corpus. A `paths:` list
# could not fire either, because building a probe reads nothing that matches.
#
# RAISED A NINTH TIME, 48800 -> 49550, FOR TWO RULES COSTING 743 BYTES, ON AN EXPLICIT OPERATOR
# RULING. The subtraction is STILL OWED and this is the ninth consecutive raise without one.
# Put as four costed options -- take both, take only the higher-consequence one, sweep for a
# subtraction first, or leave both uncarried -- with the shortfall measured (743 bytes against 60
# free) before the question was asked, and with it stated that no vestigial sweep had been
# attempted.
#
# RULE ONE: "a differential must be able to RESOLVE the effect", in `verification-discipline.md`,
# beside the rule that a differential must prove its two sides differ. Earned at v0.430.0: a
# removal differential read 7130 against 7130 with a spread of +/-2 and shipped "costs ZERO
# forks", which a per-line attribution table contradicted directly. The existing paragraph covers
# two sides that are IDENTICAL; this covers two sides that genuinely differ by less than the
# instrument can see, which reads as a clean null rather than as a broken comparison.
#
# RULE TWO: "ask what it ACQUITS, not only what it catches", in `mechanism-design.md`, beside
# "ask what a change makes always-true downstream". Earned the same release and it is the more
# expensive of the two: a new arm's slot exemption acquitted a path the consumer-side validator
# BLOCKS, the arm's own remedy pointed at that form, and its own probe asserted the acquittal on
# every run. A mechanism that defends its own defect passes every check its author would run, and
# only a pre-merge adversarial pass found it -- after the same false claim had already been
# carried into consumer-facing prose.
#
# WHY NEITHER CAN BE SCOPED. Both are prose-only: no mechanism can decide whether a differential
# could resolve its effect, or whether an exemption is too wide, without being the judgment
# itself. A `paths:` list could not fire either -- the first is exercised while writing an ad-hoc
# measurement, and the second while writing a validator arm, neither of which reliably begins
# with a matching Read. `resident-context.md` forbids scoping a prose-only rule outright.
#
# RAISED A TENTH TIME, 49550 -> 50202, FOR ONE RULE COSTING 711 BYTES, ON AN EXPLICIT OPERATOR
# RULING. The subtraction is STILL OWED and this is the tenth consecutive raise without one. Put
# as four costed options -- raise, pay for it with a subtraction first, land a shorter rule, or
# leave it in the memory corpus uncarried -- with the shortfall measured (711 bytes against 59
# free) before the question was asked, and with it stated plainly that no vestigial sweep had
# been attempted and that guessing at one would not be honest.
#
# THE RULE: "a consumer pull is NOT preapproved, and being ready is not being told", in
# `operator-rulings.md`, directly beneath "Merges are preapproved" so the two read as the pair
# they are. Earned the same day: a distribution session measured the delivery gap, wrote and
# rehearsed a runbook, asked the operator "dispatch or bank", got "dispatch" -- and handed the
# runbook straight to a peer session that `ListAgents` had just reported as `busy`. It was
# mid-sprint, and the range replaces `apply.sh`, `layer-drift.sh` and the skill files a sprint
# EXECUTES. Nothing landed, and the operator caught it rather than the session. The deeper half
# is the second paragraph: the QUESTION was defective before the send was, because the peer's
# state was known and was not put in front of the person deciding.
#
# WHY IT CANNOT BE SCOPED OR MECHANIZED. There is no act to detect -- sending a peer a message is
# not a tracked write, and no validator can see it. The work does not begin with a matching Read
# either: the session that did this was reading its own plan, not the runbook. That leaves the
# unconditional channel, and `resident-context.md` forbids scoping a prose-only rule outright.
#
# RAISED AGAIN, 50202 -> 50600, ON AN OPERATOR RULING, FOR ONE RULE COSTING 351 BYTES.
# THIS ONE CARRIED NO SUBTRACTION EITHER, AND IT IS THE SECOND CONSECUTIVE RAISE THAT DID NOT.
# Recorded as the standard it did NOT meet, in the same form as the fourth raise above, so the
# next author does not read the run of them as precedent. The author looked for a subtraction
# and reported finding none defensible; the vestigial pool was NOT re-measured against
# `resident-context.md`'s three clauses this time, which is a cheaper check than the raise and
# was skipped. That omission is the honest part of this entry.
#
# The rule is `verification-discipline.md`'s "differing sides are not enough: ask what makes
# both fail" -- two genuinely DIFFERENT programs both failing for a reason NEITHER owns is
# non-discriminating, and the resulting null is byte-identical to agreement. The existing
# section beside it covers only the case where the two sides are the SAME program, which is a
# different defect with a different control. Earned at v0.444.0: an exit-code differential over
# the reference consumer's real corpus read 16 series, 16 identical `1 -> 1` pairs and 0
# findings, because the subject fails CLOSED without a flag a bare probe cannot pass. It shipped
# as a clean, plausible, wrong ZERO and was caught only by comparing the ARM each side NAMED.
#
# WHY IT CANNOT BE SCOPED OR MECHANIZED. No tracked file carries a trace of it: the failure is a
# property of the INPUT a differential is run on, decided in a tool call, and no arm can scan for
# "both sides failed for the same unrelated reason". The specific instance IS mechanized -- the
# `predicate-reclassification` fixture's M1 mutant kills the exit-code spelling -- but that arm
# is bound to one detector and says nothing to the next differential in another subsystem. Prose
# only, so `resident-context.md` bars scoping it.
# ---------------------------------------------------------------------------
# RAISED AGAIN, 50600 -> 51300, ON AN OPERATOR RULING, FOR TWO RULES COSTING 707 BYTES. THIS ONE
# CARRIED NO SUBTRACTION EITHER, AND IT IS THE THIRD CONSECUTIVE RAISE THAT DID NOT -- but it is
# the first where the cheaper check the entry above records as SKIPPED was actually run, and it
# came back empty rather than unexamined. Measured over the seven durable files: ZERO cross-file
# duplicate sentences above 60 characters, against a control confirming the scan finds a sentence
# known to sit in exactly one file; and all 19 enforcer references in the channel are CITATIONS of
# the form `mechanism-design.md` prescribes, not restatements of what the enforcer does. So the
# mechanical vestigial pool is empty.
#
# WHAT THAT CHECK DID NOT COVER, stated because an unmeasured limit reads as a measured zero: it
# finds RESTATEMENT, not prose whose behavioural instruction lives authoritatively in a validator
# header OUTSIDE the channel. That second form needs judgement per passage and was not
# exhaustively enumerated. The next author raising this ceiling should start there.
#
# The rules are `verification-discipline.md`'s "read the CONSUMING mechanism's own remedy text
# before calling its input wrong" and `tool-hazards.md`'s truncation clause. Earned in one batch:
# v0.457.0 shipped a fix for a filing whose premise `ai-dlc-core-guard.sh` contradicts in its own
# deny message, and v0.458.0 reverted it. The gate was green throughout, because `I25` binds the
# guard and the resolver by byte-comparing `parse_manifest()` and `to_consumer_glob()` while the
# fork landed at the DECISION, outside both. Two hands had measured the answer and had gone idle
# twice each, delivering nothing until after the merge, with their payloads then truncated.
#
# WHY NEITHER CAN BE SCOPED OR MECHANIZED. The first is a judgement about which file to open
# before believing a filing -- no act to detect, and the work begins by reading the SUBJECT, never
# the consuming mechanism, so a `paths:` trigger keyed on the thing you failed to read cannot
# fire. The second is a property of a tool result, not of any tracked file. The specific instance
# IS mechanized -- the three-way agreement arm in `core/fixtures/upstream-routing/run.sh` kills
# the exact fork -- but that arm is bound to one resolver and says nothing to the next author
# trusting a filing in another subsystem. Prose only, so `resident-context.md` bars scoping both.
# ---------------------------------------------------------------------------
# RAISED AGAIN, 51300 -> 51800, ON AN OPERATOR RULING, FOR ONE RULE COSTING 491 BYTES. The
# duplicate scan was run BEFORE the raise, not after: zero occurrences of the rule's subject across
# the durable channel, against a positive control finding a phrase known to sit in `CLAUDE.md` and
# a negative control returning nothing. The A6 arm was also observed FAILING at 51791 before the
# ceiling moved, so this raise is a response to a check that fired rather than to one assumed.
#
# The rule is `verification-discipline.md`'s "a correction is itself a measurement, and NARROWING
# is not the safe direction". Earned in v0.464.0: a CHANGELOG entry was corrected mid-batch to say
# a gate's blindness held only outside one file class, which was one ROW of a two-row table read as
# the whole table -- on the other row the gate caught nothing at all, and an adversarial hand had to
# WIDEN the claim back. The correction was made in good faith, reviewed, and shipped wrong.
#
# WHY IT CANNOT BE SCOPED OR MECHANIZED. It is a judgement about the population a CORRECTION was
# measured on, made while editing prose, and no tracked file carries a trace of the error -- the
# narrowed claim and the true one are both well-formed English about the same subject. Nothing can
# scan for "this correction was measured on a different population than the claim it corrects".
# Prose only, so `resident-context.md` bars scoping it. It sits beside "Ask what SET a number was
# taken over" deliberately: that rule governs a figure, this one governs a revision to a figure,
# and the second is the case the first did not cover.
#
# WHAT WAS STILL NOT COVERED. The judgement-per-passage vestigial form the entry above names as the
# place to start was again NOT exhaustively enumerated. That debt is now three raises old and is
# stated rather than quietly carried forward.
# ---------------------------------------------------------------------------
# RAISED AGAIN, 51800 -> 52350, ON AN OPERATOR RULING, FOR ONE RULE COSTING 518 BYTES. The
# duplicate scan was run BEFORE the raise, as the entry above requires: zero occurrences of the
# rule's subject across the durable channel over six distinct tokens, against a positive control
# finding a phrase known to sit in `CLAUDE.md` and a negative control returning nothing. The single
# near-match, `the executor` at `CLAUDE.md:243`, is a session executing a PLAN and not a program
# executing input -- read, not assumed from the count. A6 was observed FAILING at 52309 before the
# ceiling moved, so this raise responds to a check that fired.
#
# The rule is `verification-discipline.md`'s "cross-check a parser against what EXECUTES it, never
# against another parser". Earned in v0.474.0: a shell quote scanner was checked against python
# `shlex` and against `bash -n -c` over the same 3408 commands. The two oracles disagreed on 23;
# `shlex` was wrong on 20, and the 2 the scanner got wrong were a real false-refusal defect about to
# ship. `shlex` as the oracle buys 21 phantom cases and misses both true ones.
#
# WHY IT CANNOT BE SCOPED OR MECHANIZED. It is a judgement about which of two available oracles to
# believe, made while designing a check, and no tracked file records which one was consulted -- both
# choices produce the same shape of comparison and the same clean-looking table. It generalises past
# shells to any grammar with a real interpreter, so an arm bound to one resolver would say nothing to
# the next author. Prose only, so `resident-context.md` bars scoping it. It sits beside "run the
# shipping code against the real corpus" deliberately: that rule governs choosing the real PROGRAM
# over a probe, this one governs choosing between two programs that both look real.
#
# WHAT WAS STILL NOT COVERED. The judgement-per-passage vestigial form is STILL not exhaustively
# enumerated. That debt is now four raises old.
DURABLE_MAX="${AI_DLC_DURABLE_BYTES:-52350}"
durable_files() {
  printf '%s\n' CLAUDE.md
  for f in $(rule_files); do has_paths_key "$f" || printf '%s\n' "$f"; done
}
d_total=0; d_list=""
while IFS= read -r f; do
  [ -n "$f" ] && [ -f "$f" ] || continue
  b="$(wc -c < "$f" | tr -d ' ')"
  d_total=$(( d_total + b ))
  d_list="${d_list}    ${f} ${b}
"
done <<<"$(durable_files)"
if [ "$d_total" -eq 0 ]; then
  err "A6: measured ZERO bytes of compaction-durable prose, which cannot be right while CLAUDE.md exists. The file list is broken, so the headroom below is not a reading."
elif [ "$d_total" -gt "$DURABLE_MAX" ]; then
  err "A6: the compaction-durable channel is ${d_total} bytes against a ceiling of ${DURABLE_MAX}. Every byte here is re-injected on every compaction of every session. Move a rule to a \`paths:\`-scoped file if its work reliably begins with a matching read, or cut it:"
  printf '%s' "$d_list" >&2
else
  say "  A6  ok  -- compaction-durable channel ${d_total}/${DURABLE_MAX} bytes across $(durable_files | grep -c .) file(s)"
fi

if [ "$fail" = "0" ]; then
  say "OK: validate-claude-rules -- A1 tracked-path containment, A2 no orphan globs, A3 paths-only frontmatter, A3b scope declared once, A4 pointer/no-stub join, A5 live invariant citations, A6 durable-channel ceiling. Corpus: $(rule_files | wc -l | tr -d ' ') rule file(s), $(rule_globs | wc -l | tr -d ' ') glob(s), ${d_total}B durable."
fi
exit "$fail"
