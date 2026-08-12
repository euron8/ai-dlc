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
# ---------------------------------------------------------------------------
DURABLE_MAX="${AI_DLC_DURABLE_BYTES:-40960}"
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
