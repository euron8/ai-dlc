#!/usr/bin/env bash
# Pin deploy-validate.md §3's smoke-evidence classification text.
#
# SUBJECT. §3 (Smoke Tests) requires the `smoke_run_evidence` record to carry three
# fields -- `first_run_failures`, `transient_failures_cleared_on_retry`,
# `persistent_failures` -- and defines a transient failure as one a retry cleared with
# NO ACTION BY THE LEAD between the runs. The Production Validation Checkpoint's
# `Deployment` block reports the same split. No script reads `smoke_run_evidence`; the
# executing lead reads this prose, so the prose is the mechanism and this fixture pins it.
#
# KEYED ON THE SECTION, NOT THE FILE. Each field must be DEFINED as a `- \`<field>\` --`
# bullet inside §3's body (heading `### 3. Smoke Tests` up to the next `### ` heading).
# A whole-file grep is satisfied by a mention in any other section, and by the checkpoint
# block, which names the same concepts; the MOVE mutant below proves this arm is not.
#
# Exit 0 iff every arm holds; 1 on a finding; 2 (FIXTURE BROKEN) when the subject file
# cannot be located or §3 cannot be isolated. An absent subject is never green: a
# consumer that pulled this fixture ahead of the step file must see the gap.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

STEP=""
for cand in \
  "$DIR/../../skills/ai-dlc/steps/deploy-validate.md" \
  "$DIR/../../../.claude/skills/ai-dlc/steps/deploy-validate.md"; do
  [ -f "$cand" ] && STEP="$cand" && break
done
if [ -z "$STEP" ]; then
  echo "deploy-validate-smoke-classification: FIXTURE BROKEN -- could not locate deploy-validate.md in either layout (core/skills/ai-dlc/steps/ or .claude/skills/ai-dlc/steps/). An absent subject is not a passing one." >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dv-smoke-class.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
rc=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; rc=1; }

echo "deploy-validate-smoke-classification: subject $STEP"

FIELDS="first_run_failures transient_failures_cleared_on_retry persistent_failures"
DEF='A failure is transient ONLY when a retry cleared it with NO ACTION BY THE LEAD between the runs'
INRUN='in-run retry, same output'

sec3() { # <file> -> §3 body, heading line excluded
  awk '/^### 3\. Smoke Tests/{on=1; next} on && /^### /{exit} on{print}' "$1"
}
flat() { # stdin -> one line, runs of whitespace collapsed, bold markers dropped
  tr '\n' ' ' | sed -e 's/\*\*//g' -e 's/[[:space:]][[:space:]]*/ /g'
}
deploy_block() { # <file> -> the checkpoint's `### Deployment` block
  awk '/^### Deployment$/{on=1; next} on && /^### /{exit} on{print}' "$1"
}

# check <file> -> prints one line per failing arm; prints nothing when every arm holds.
# Presence-shaped throughout: every arm demands a string APPEAR, so an empty §3 fails
# every arm rather than passing any.
check() {
  local f="$1" body fl blk fld n
  body="$(sec3 "$f")"
  if [ -z "$body" ]; then echo "SECTION: §3 could not be isolated"; return; fi
  for fld in $FIELDS; do
    n="$(grep -cE "^- \`$fld\` " <<<"$body")" || n=0
    [ "$n" = "1" ] || echo "FIELD $fld: $n defining bullet(s) in §3, expected 1"
  done
  fl="$(flat <<<"$body")"
  case "$fl" in *"$DEF"*) : ;; *) echo "DEFINITION: the no-action-by-the-lead transient definition is absent from §3" ;; esac
  case "$fl" in *"$INRUN"*) : ;; *) echo "INRUN: the value '$INRUN' is absent from §3" ;; esac
  case "$fl" in *'Every other failure is persistent'*) : ;; *) echo "PERSISTENT: §3 does not route every non-transient failure to persistent" ;; esac
  case "$fl" in *'persistent_failures` is a red smoke run and enters the loop below'*) : ;; *) echo "LOOP: §3 does not send persistent failures into the fix loop" ;; esac
  blk="$(deploy_block "$f")"
  for n in 'First-run failures:' 'Transient, cleared on retry:' 'Persistent:'; do
    grep -qF -- "- Smoke tests:" <<<"$blk" || { echo "CHECKPOINT: no Smoke tests line in the Deployment block"; break; }
    grep -qF -- "$n" <<<"$blk" || echo "CHECKPOINT: '$n' absent from the Deployment block"
  done
}

# --- the subject -------------------------------------------------------------
out="$(check "$STEP")"
if [ -z "$out" ]; then
  ok "§3 defines all three fields, the transient definition, the in-run value and the loop routing; the checkpoint reports the split"
else
  while IFS= read -r l; do bad "$l"; done <<<"$out"
fi

# --- cwd invariance: the resolver keys on \$DIR, never on the process cwd ------
[ "${1:-}" = "--probe-only" ] && exit "$rc"
if ( cd / && bash "$DIR/run.sh" --probe-only ) >/dev/null 2>&1; then
  ok "CWD: the fixture resolves its subject from / as well as from the repo root"
else
  bad "CWD: run from / the fixture could not resolve or pass its subject"
fi

# --- mutants -----------------------------------------------------------------
# Each is a COPY of the resolved subject; `cmp -s` refuses a mutation that matched
# nothing, and each must produce ITS OWN finding and no other.
CTL="$WORK/control.md"; cp "$STEP" "$CTL"
if [ -z "$(check "$CTL")" ] && [ -n "$(sec3 "$CTL")" ]; then
  ok "CONTROL: an unmutated copy passes and §3 is non-empty, so a mutant's finding below is the mutation"
else
  bad "CONTROL: an unmutated copy fails -- every mutant verdict below is uninterpretable"
fi

mutant() { # <name> <awk-program> <expected-finding-prefix> <label>
  local m="$WORK/$1.md" res others
  awk "$2" "$STEP" > "$m"
  if cmp -s "$STEP" "$m"; then bad "FIXTURE ERROR: mutation '$1' matched nothing"; return; fi
  res="$(check "$m")"
  if ! grep -qF -- "$3" <<<"$res"; then
    bad "MUTATION '$1' SURVIVED -- $4"
    return
  fi
  others="$(grep -vF -- "$3" <<<"$res")"
  if [ -n "$others" ]; then
    bad "MUTATION '$1' fired other arms too ($others) -- the arms are entangled"
  else
    ok "MUTATION '$1' killed by its own arm only: $4"
  fi
}

for fld in $FIELDS; do
  mutant "del-$fld" \
    "/^### 3\\. Smoke Tests/{s=1} s && /^### 3b/{s=0} s && /^- \`$fld\` /{next} {print}" \
    "FIELD $fld:" "deleting the $fld bullet from §3 is caught"
  # MOVE: the bullet leaves §3 and reappears verbatim under §3b. A whole-file grep
  # still finds it; the section-keyed arm must not.
  mutant "move-$fld" \
    "/^### 3\\. Smoke Tests/{s=1} s && /^### 3b/{s=0; print; print held; next} s && /^- \`$fld\` /{held=\$0; next} {print}" \
    "FIELD $fld:" "moving the $fld bullet out of §3 (into §3b) is caught"
done

mutant "any-retry" \
  '/^\*\*A failure is transient ONLY when a retry cleared it with NO ACTION BY$/{print "**A failure is transient when any retry cleared it, whatever"; next} {print}' \
  "DEFINITION:" "redefining transient as any retry is caught"

mutant "no-inrun" \
  '{ gsub(/in-run retry, same output/, "in-run retry"); print }' \
  "INRUN:" "dropping the in-run retry value is caught"

mutant "checkpoint-persistent" \
  '/^  - Persistent: \[persistent_failures/{next} {print}' \
  "CHECKPOINT:" "dropping the Persistent line from the checkpoint Deployment block is caught"

# SECTION: §3's heading renamed -> nothing to isolate. Must be a finding, never clean.
mutant "no-section" \
  '/^### 3\. Smoke Tests/{print "### 3. Live checks"; next} {print}' \
  "SECTION:" "an unisolatable §3 is a finding, not an empty pass"

echo
if [ "$rc" -eq 0 ]; then
  echo "deploy-validate-smoke-classification: PASS"
else
  echo "deploy-validate-smoke-classification: FAILED" >&2
fi
exit $rc
