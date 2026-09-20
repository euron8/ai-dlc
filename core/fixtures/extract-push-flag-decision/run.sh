#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# extract-push-flag-decision — prove the untangle extract site DECIDES `push_candidate`
# on the `domain-local` bullet instead of leaving it defaulted, and that `domain-local`
# gains no push route of its own.
#
# WHAT THE SUBJECT IS, AND WHAT THIS CANNOT OBSERVE. The subject is the bucket action
# list in `ai-dlc-update/SKILL.md` step 7u — the site where the extract decision is
# DECLARED. That file is a prompt: no executable reads it (`grep -rl` over the shipped
# `.sh` set matches the classifier prompt in 0 of them), so nothing here can observe
# whether a pull's classifier actually applied the rule, whether a written `false` was
# derived or guessed, or what any consumer entry ends up carrying. The only observable
# is the declared text, and every assertion below is scoped to that. The VALUE's
# correctness on a real entry is unobservable from this repo and is left to E9's
# required-boolean and to the operator; what this fixture buys is that the decision
# cannot silently revert to an omission.
#
# THE DEFECT THIS EXISTS TO CATCH. `domain-local` routed a block to `extensions/`
# writing no push flag at all while `un-pushed-innovation` wrote `push_candidate: true`
# one bullet below. A block whose machinery core text presupposes took the first route,
# landed with the flag unwritten, and was never offered upstream. `validate-layer-entries.sh`
# E9 already makes the key REQUIRED on every entry, so absence is unconstructible at the
# entry; what was constructible was this site declining to decide, which E9 cannot see
# because E9's corpus is consumer entries and this is upstream prose.
#
# WHY A BULLET-SCOPED PREDICATE AND NOT A FILE GREP. A whole-file — or whole-list —
# `grep` for `push_candidate` is satisfied by the `un-pushed-innovation` bullet four
# lines below the subject, and scores the pre-fix text CLEAN. That false green was
# produced deliberately and is asserted against in probe direction 3.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the subject regressed, 2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# ROOT IN BOTH LAYOUTS, named side by side, never by walking up for a VERSION file (I106):
# a consumer has no VERSION at its root, and the walk would exit 2 there on every push.
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$ROOT" ] && [ -f "$ROOT/core/skills/ai-dlc-update/SKILL.md" ]; then
  SUBJ="$ROOT/core/skills/ai-dlc-update/SKILL.md"
elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/skills/ai-dlc-update/SKILL.md" ]; then
  SUBJ="$ROOT/.claude/skills/ai-dlc-update/SKILL.md"
else
  echo "extract-push-flag-decision: FIXTURE BROKEN — ai-dlc-update/SKILL.md not found in either layout" >&2
  exit 2
fi

WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "extract-push-flag-decision:"

# --- THE EXTRACTOR ------------------------------------------------------------------
# Emits ONE bucket bullet's body, terminating on the next `- **` and on the blank line
# that ends the list. The bullets are not blank-separated, so terminating on a blank
# line alone would swallow the list; terminating on `- **` alone would run past the
# list's end into the prose below. Both terminators are required and probe direction 4
# is the input that proves the second one is load-bearing.
#
# LC_ALL=C is set for every awk call in this file: these sources carry em-dashes and a
# multibyte character aborts a BSD awk mid-file, which would empty the extraction and
# read as "the bullet says nothing" rather than as a broken scan.
bullet() { # bullet <file> <bucket-name>
  LC_ALL=C awk -v want="$2" '
    $0 ~ "^- [*][*]" want "[*][*]" { f=1; print; next }
    f && /^- [*][*]/ { exit }
    f && /^[[:space:]]*$/ { exit }
    f && /^## / { exit }
    f { print }
  ' "$1"
}

# The PREDICATE under test, stated once and applied to probe and corpus alike, so the
# probe cannot prove a different program from the one the corpus is scored by.
writes_flag() { # writes_flag <file> <bucket>  -> 0 if that bullet writes push_candidate
  b="$(bullet "$1" "$2")"
  [ -n "$b" ] || return 3
  grep -q 'push_candidate' <<<"$b"
}

# The VALUE the bullet writes, NORMALISED ACROSS THE LINE WRAP, which is the whole
# reason this helper exists rather than a regex at each site. The subject wraps as
# `push_candidate:` / newline / `true`, so a pattern anchored on `push_candidate:...$`
# matches the wrap itself and is satisfied by EITHER value on the next line. Written
# that way first, this arm passed a mutant that flipped `true` to `false` -- a check
# that could not fail, reading exactly like one that held. Collapse the body to one
# line, then read the token that actually follows the key.
flag_value() { # flag_value <file> <bucket>  -> echoes true|false|<nothing>
  b="$(bullet "$1" "$2")"
  [ -n "$b" ] || return 3
  printf '%s' "$b" \
    | tr '\n' ' ' \
    | LC_ALL=C sed -e 's/`//g' -e 's/  */ /g' \
    | LC_ALL=C grep -oE 'push_candidate: *(true|false)' \
    | LC_ALL=C sed -e 's/.*: *//' \
    | head -1
}

# --- SELF-PROBE, BEFORE THE CORPUS, IN BOTH DIRECTIONS, IN ONE RUN ------------------
# An arm reporting a clean corpus without first proving it can produce a finding has
# established that it ran, not that the corpus is clean. The negative sits BESIDE the
# offender here: a near-miss scored in a separate clean run can only ask "does this fire
# at all", never "does it fire on the RIGHT bullet".

# Direction 0: the extractor discriminates at all. Without this, every direction below
# scores against an extractor returning nothing and all of them read as passes.
if [ -n "$(bullet "$PROBE/offender.md" 'domain-local')" ] \
   && [ -n "$(bullet "$PROBE/offender.md" 'un-pushed-innovation')" ]; then
  ok "probe 0: the extractor returns a body for both bucket bullets"
else
  bad "FIXTURE BROKEN — the extractor returned an empty bullet; every direction below is a false pass"
  echo; echo "extract-push-flag-decision: FIXTURE BROKEN" >&2; exit 2
fi

# Direction 0b: and it returns DIFFERENT bodies for two different bullets. An extractor
# that returned the whole list for every name would satisfy direction 0 and score every
# bucket identically -- non-discriminating, and its agreement would read as a finding.
if [ "$(bullet "$PROBE/offender.md" 'domain-local')" != "$(bullet "$PROBE/offender.md" 'conflict')" ]; then
  ok "probe 0b: two different bucket names extract two different bodies"
else
  bad "FIXTURE BROKEN — two bucket names extracted the same text; the extractor is not bullet-scoped"
  echo; echo "extract-push-flag-decision: FIXTURE BROKEN" >&2; exit 2
fi

# Direction 1 (REPORTS the offender): the pre-fix wording must be scored as NOT writing
# the flag. This is the shipping defect, reproduced verbatim.
if writes_flag "$PROBE/offender.md" 'domain-local'; then
  bad "probe 1: the pre-fix domain-local bullet scored as WRITING the flag — the predicate cannot see its own subject"
else
  ok "probe 1: the pre-fix domain-local bullet is scored as NOT writing the flag (offender reported)"
fi

# Direction 2 (QUIET on the near-miss): a bullet that writes the flag in wording sharing
# no sentence with the committed fix must score as compliant. A predicate keyed on the
# shipped phrasing would fail here while passing direction 1, and that combination reads
# exactly like a working check.
if writes_flag "$PROBE/nearmiss.md" 'domain-local'; then
  ok "probe 2: a differently-worded bullet that writes the flag is scored compliant (not vocabulary-bound)"
else
  bad "probe 2: a compliant bullet in different wording scored as a violation — the predicate is keyed on a spelling"
fi

# Direction 3 (the list-scoped false green): the offender's SIBLING bullet writes the
# flag, so a predicate scoped to the list instead of the bullet passes the defect. Assert
# the sibling really does carry the token, or this direction proves nothing.
if writes_flag "$PROBE/offender.md" 'un-pushed-innovation'; then
  ok "probe 3: the offender's un-pushed-innovation bullet DOES carry the token..."
  if writes_flag "$PROBE/offender.md" 'domain-local'; then
    bad "probe 3: ...and the domain-local bullet was scored by it — the predicate is list-scoped, not bullet-scoped"
  else
    ok "probe 3: ...and it did NOT satisfy the domain-local bullet (the false green is excluded)"
  fi
else
  bad "FIXTURE BROKEN — the probe's un-pushed-innovation bullet carries no token, so direction 3 tests nothing"
fi

# Direction 4 (the below-list false green): the flag is written in the prose AFTER the
# list. An extractor terminating only on `- **` runs past the list end and scores this
# compliant. This is the input that proves the blank-line terminator is load-bearing.
if writes_flag "$PROBE/belowlist.md" 'domain-local'; then
  bad "probe 4: prose BELOW the list satisfied the bullet predicate — the extractor runs past the list end"
else
  ok "probe 4: a flag written below the list does not satisfy the bullet (extraction stops at the list end)"
fi

# Direction 4b: the VALUE reader crosses the line wrap. The subject wraps between the key
# and its value, so a naive pattern matches the wrap and is satisfied by EITHER value.
# Written that way first, assertion 5 below passed a mutant that flipped true to false.
# Both values are read from ONE seeded file in the same call, and they must DIFFER: two
# reads agreeing would be exactly the vacuity this direction exists to exclude.
PV_DL="$(flag_value "$PROBE/nearmiss.md" 'domain-local')"
PV_UP="$(flag_value "$PROBE/nearmiss.md" 'un-pushed-innovation')"
if [ "$PV_DL" = false ] && [ "$PV_UP" = true ]; then
  ok "probe 4b: the value reader crosses the line wrap and returns opposite values for the two bullets"
else
  bad "probe 4b: the value reader returned '${PV_DL:-<none>}'/'${PV_UP:-<none>}' where false/true was seeded — it cannot read a wrapped value, so every value assertion below is vacuous"
fi

# Direction 5: a bucket name that does not exist must be distinguishable from one whose
# bullet is silent. Both are "no token found"; only one is a finding.
# The upstream goes in a command substitution and the reader gets a here-string: feeding
# `grep -q` from a pipe makes the pipeline answer with the WRITER's EPIPE under pipefail
# and report not-found on input that contains the pattern. I54b caught this exact line.
NOBUCKET="$(bullet "$PROBE/offender.md" 'no-such-bucket')"
if grep -q . <<<"$NOBUCKET"; then
  bad "probe 5: a nonexistent bucket name extracted a body"
else
  ok "probe 5: a nonexistent bucket name extracts nothing, and is told apart from a silent bullet by rc 3"
fi
writes_flag "$PROBE/offender.md" 'no-such-bucket'; rc=$?
if [ "$rc" -eq 3 ]; then
  ok "probe 5b: an absent bucket returns rc 3, never the rc 1 a silent bullet returns"
else
  bad "probe 5b: an absent bucket returned rc $rc — indistinguishable from a bullet that simply omits the flag"
fi

# --- THE CORPUS ---------------------------------------------------------------------
# Only now, with both directions proven on seeded input, is the real file scored.

# Assertion 1: the decision site's domain-local bullet WRITES the flag.
if writes_flag "$SUBJ" 'domain-local'; then
  ok "the extract site's domain-local bullet writes push_candidate"
else
  rc=$?
  if [ "$rc" -eq 3 ]; then
    bad "FIXTURE STALE: no 'domain-local' bucket bullet found in $SUBJ — the bucket list moved or was renamed"
  else
    bad "the domain-local bullet extracts to extensions/ WITHOUT writing push_candidate: the flag is defaulted, and a block whose machinery core presupposes lands unflagged and is never offered upstream"
  fi
fi

# Assertion 2: and it writes FALSE there. A bullet writing `true` would satisfy
# assertion 1 while inverting the bucket's meaning, so the VALUE is asserted, not just
# the token's presence.
DL="$(bullet "$SUBJ" 'domain-local')"
DLV="$(flag_value "$SUBJ" 'domain-local')"
if [ "$DLV" = false ]; then
  ok "  and the value it writes is false"
else
  bad "  the domain-local bullet writes push_candidate '${DLV:-<no value>}', not false — the bucket's flag value is not declared"
fi

# Assertion 3: `domain-local` gains NO push route. If it routes to push, its distinction
# from `un-pushed-innovation` collapses at this site and `needs_operator_confirmation`
# becomes the only discriminator — the tautology the fix was required not to create.
# Keyed on the ROUTING verbs the sibling bullet uses, not on the word `push` alone: the
# fixed bullet legitimately names push_candidate and the bucket's lack of a route.
if grep -qiE 'flag for push|flag it for push|route (it )?to push|append to the push-candidate ledger' <<<"$DL"; then
  bad "the domain-local bullet acquired a push ROUTE — its distinction from un-pushed-innovation has collapsed and needs_operator_confirmation is the only discriminator left"
else
  ok "domain-local carries no push route of its own (the two buckets stay distinct)"
fi

# Assertion 4: the SIBLING still routes to push. The destructive regression that both
# receipts acquit is stripping the route from un-pushed-innovation and moving it to
# domain-local; assertions 1-3 alone all hold under it, because each reads one bullet.
UP="$(bullet "$SUBJ" 'un-pushed-innovation')"
if [ -z "$UP" ]; then
  bad "FIXTURE STALE: no 'un-pushed-innovation' bullet found — the bucket list moved or was renamed"
elif grep -q 'push_candidate' <<<"$UP"; then
  ok "un-pushed-innovation still writes push_candidate, so the push route was not MOVED between buckets"
else
  bad "un-pushed-innovation no longer writes push_candidate — the push route was stripped from the bucket that owns it"
fi

# Assertion 5: and it writes TRUE. The two bullets writing the same value is the state in
# which the flag stops carrying information, and every assertion above still holds there.
UPV="$(flag_value "$SUBJ" 'un-pushed-innovation')"
if [ "$UPV" = true ]; then
  ok "  and the value it writes is true, so the two buckets write OPPOSITE values"
else
  bad "  un-pushed-innovation writes push_candidate '${UPV:-<no value>}', not true — if both buckets write the same value the flag carries no information"
fi

# Assertion 6: the two bullets do not write the SAME value. Derived by comparing the two
# extracted values rather than by matching each against a literal, so an edit that
# converges them on any value -- including one neither assertion above names -- fails
# here. Both values must also be present: two empty strings compare equal and would
# score as a finding for the wrong reason.
if [ -n "$DLV" ] && [ -n "$UPV" ] && [ "$DLV" = "$UPV" ]; then
  bad "both bucket bullets write '$DLV' — the flag no longer distinguishes the two buckets"
else
  ok "the two bullets write different values ('${DLV:-<none>}' vs '${UPV:-<none>}')"
fi

# --- CWD INVARIANCE ------------------------------------------------------------------
# This fixture is green from the repo root because that is how the hook drives it. An
# assertion set that is green ONLY from there may be asserting nothing, so the subject
# resolution is re-run from a directory where no relative path could reach it.
SUBSHELL_OUT="$( cd / 2>/dev/null && LC_ALL=C awk '
    $0 ~ "^- [*][*]domain-local[*][*]" { f=1; print; next }
    f && /^- [*][*]/ { exit }
    f && /^[[:space:]]*$/ { exit }
    f { print }
  ' "$SUBJ" )"
if grep -q 'push_candidate' <<<"$SUBSHELL_OUT"; then
  ok "the same verdict holds with the process cwd outside the repo (the subject is resolved absolutely)"
else
  bad "the verdict changes when run from another cwd — the subject path is not resolved absolutely"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "extract-push-flag-decision: PASS"
  exit 0
fi
echo "extract-push-flag-decision: $fails FAILED" >&2
exit 1
