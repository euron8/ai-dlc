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

if [ "$fail" = "0" ]; then
  say "OK: validate-claude-rules -- A1 tracked-path containment, A2 no orphan globs, A3 paths-only frontmatter, A4 pointer/no-stub join. Corpus: $(rule_files | wc -l | tr -d ' ') rule file(s), $(rule_globs | wc -l | tr -d ' ') glob(s)."
fi
exit "$fail"
