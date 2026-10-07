#!/usr/bin/env bash
# process-rule-pins — pin three process rules to the SECTION that makes them bind.
#
# Usage: run.sh            full run: probes, near-misses, mutants, then the real corpus
#        run.sh --report   corpus verdict only (used by the cwd-invariance arm)
# Exit:  0 = every assertion holds, 1 = a pin regressed, 2 = fixture broken.
#
# THE SUBJECT. Three rules are prose with no mechanism behind them, so the text IS the rule:
#   - a state claim in Check 12's evidence carries its command (gate-validation.md);
#   - an operator attribution cites the operator's message (rule-13.md, discovery.md §4a,
#     and an adversary Severity rung);
#   - a later event invalidating an authorization premise returns to the operator
#     (escalations.md, and a second adversary Severity rung);
#   - the bug root-cause claim gets an adversarial pass in bug-investigation.md §2c, and the
#     folded-defect routes (route.md, stories-test-strategy.md) reach §2c;
#   - a party round's seats edit nothing and one repair writer applies their findings, every
#     entry carrying `source: <seat-file>#<finding-id>` (_gate-procedures.md "Validation cycle",
#     sprint-review.md §2, remediator.md). The `source:` resolution itself is mechanised in
#     join-remediator-shards.sh and owned by remediator-shard-join; these rows pin the PROSE that
#     tells the seats not to write, which no program can read off a seat's behaviour.
#
# LEADS ARE NOT ENOUGH. A bold lead left intact over a body rewritten to say the opposite
# ("need NOT carry", "dropped only through a HARD_BLOCK", "an assertion is a sufficient
# disposition", a MAJOR downgraded to MINOR) passed every lead-only pin. The para rows pin
# the binding clause inside the lead's own paragraph, and a negation mutant proves each.
#
# WHY SECTION-BOUNDED. A whole-file grep closes on any mention anywhere, including a comment,
# a fenced example, or the same sentence moved into a section that does not bind. Every pin
# therefore requires its line INSIDE a named span, anchored at line start, outside fences and
# outside line-leading HTML comments. Each pin is shown to fail on a deletion mutant, on the
# line relocated outside its span, on the line wrapped in a fence, on the line wrapped in a
# comment, and (for line-start pins) on the line indented — all on mktemp copies, before the
# real corpus is read.
#
# LAYOUTS. The subject exists on a consumer too, so this fixture ships. The root is found by
# walking up from this script for the skill directory — core/skills/ai-dlc in the
# distribution, .claude/skills/ai-dlc in an installed consumer — never by counting hops, and
# never from the cwd. The cwd arm at the end re-runs the corpus from a decoy tree and requires
# a byte-identical verdict.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SELF="$HERE/$(basename "$0")"

# resolve_root <start-dir> [<ceiling>] -> prints "<layout> <root>", or fails. The ceiling
# exists for the probes only: it is the last directory examined, so a probe tree cannot be
# rescued by whatever happens to sit above the temp directory.
resolve_root() {
  local d="$1" ceil="${2:-}"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -d "$d/core/skills/ai-dlc" ] && [ -d "$d/core/team-roles" ]; then
      printf 'dist %s\n' "$d"; return 0
    fi
    if [ -d "$d/.claude/skills/ai-dlc" ] && [ -d "$d/.claude/team-roles" ]; then
      printf 'consumer %s\n' "$d"; return 0
    fi
    [ -n "$ceil" ] && [ "$d" = "$ceil" ] && return 1
    d="$(dirname "$d")"
  done
  return 1
}

dirs_for() { # dirs_for "<layout> <root>" -> sets SKILL_DIR ROLES_DIR ROOT LAYOUT
  LAYOUT="${1%% *}"; ROOT="${1#* }"
  case "$LAYOUT" in
    dist)     SKILL_DIR="$ROOT/core/skills/ai-dlc";    ROLES_DIR="$ROOT/core/team-roles" ;;
    consumer) SKILL_DIR="$ROOT/.claude/skills/ai-dlc"; ROLES_DIR="$ROOT/.claude/team-roles" ;;
    *) return 1 ;;
  esac
}

# pin_scan <file> <span-start-prefix|""> <span-end-prefix> <lead> <prefix|contains|para> [<token>]
#   prints "<in-span hits> <whole-file hits> <span start line> <span end line> <first hit line>"
#   Fenced lines and <!-- --> comments are invisible to every test, the span markers
#   included. A comment opened MID-LINE hides everything after it until its close, exactly
#   as a renderer does. An empty start means the span opens at line 1. rc 2 on an
#   unbalanced fence or comment, which would otherwise make every later line invisible.
#
#   para mode tests PARAGRAPHS, not lines: blank-line separated, whitespace collapsed, so a
#   binding clause wrapped across lines is one string. A hit is a paragraph that BEGINS with
#   the lead and CONTAINS the token. That is what pins the binding sentence under a bold
#   lead, which a lead-only pin cannot see negated.
pin_scan() {
  PS_START="$2" PS_END="$3" PS_LEAD="$4" PS_MODE="$5" PS_TOK="${6:-}" awk '
  function flush(   q) {
    if (p == "") return
    q = p; gsub(/[ \t]+/, " ", q); sub(/^ /, "", q)
    if (index(q, l) == 1 && index(q, k) > 0) { whole++; if (fl == 0) fl = pl; if (pst == 1) ins++ }
    p = ""
  }
  BEGIN { s = ENVIRON["PS_START"]; e = ENVIRON["PS_END"]; l = ENVIRON["PS_LEAD"]; m = ENVIRON["PS_MODE"]
          k = ENVIRON["PS_TOK"]
          fence = ""; com = 0; ins = 0; whole = 0; el = 0; fl = 0; p = ""
          if (s == "") { state = 1; sl = 1 } else { state = 0; sl = 0 } }
  {
    line = $0
    if (com) { if (index(line, "-->")) com = 0; if (m == "para") flush(); next }
    t = line; sub(/^[ \t]+/, "", t)
    if (fence == "") {
      if (substr(t, 1, 3) == "```" || substr(t, 1, 3) == "~~~") { fence = substr(t, 1, 3); if (m == "para") flush(); next }
    } else {
      if (substr(t, 1, 3) == fence) fence = ""
      next
    }
    if (substr(t, 1, 4) == "<!--") { if (index(substr(t, 5), "-->") == 0) com = 1; if (m == "para") flush(); next }
    c = index(line, "<!--")
    if (c > 0 && index(substr(line, c + 4), "-->") == 0) { line = substr(line, 1, c - 1); com = 1 }
    if (m == "para") {
      if (line ~ /^[ \t]*$/) { flush(); next }
      if (state == 0) { if (index(line, s) == 1) { flush(); state = 1; sl = NR }; if (p == "") { p = line; pl = NR; pst = state } else p = p " " line; next }
      if (state == 1 && index(line, e) == 1) { flush(); state = 2; el = NR; next }
      if (substr(line, 1, 1) == "#") { flush(); p = line; pl = NR; pst = state; flush(); next }
      if (p == "") { p = line; pl = NR; pst = state } else p = p " " line
      next
    }
    if (m == "contains") hit = (index(line, l) > 0); else hit = (index(line, l) == 1)
    if (hit) { whole++; if (fl == 0) fl = NR }
    if (state == 0) { if (index(line, s) == 1) { state = 1; sl = NR }; next }
    if (state == 1) {
      if (index(line, e) == 1) { state = 2; el = NR; next }
      if (hit) ins++
    }
  }
  END { if (m == "para") flush()
        if (fence != "" || com) { print "UNBALANCED"; exit 2 }
        print ins, whole, sl, el, fl }' "$1"
}

# The pin table. Fields: id | S (skill dir) or R (roles dir) | relative file | span start
# (empty = top of file) | span end | lead | match mode | token (para mode only).
#
# The para rows pin the BINDING sentence beneath a lead: a lead-only pin passes a body
# rewritten to say the opposite. Each token is the clause whose negation inverts the rule.
# Two texts are deliberately NOT pinned because they are being reworded: the repair clause of
# the attribution rung, and the closing sentence of the §2c disposal paragraph.
pins() {
  cat <<'PINS'
gv-body-must|S|steps/gate-validation.md|### 12.|### 13.|**A state claim MUST carry its command.**|para|MUST carry, in the same row
gv-body-output|S|steps/gate-validation.md|### 12.|### 13.|**A state claim MUST carry its command.**|para|the command that produced it and that command's output
r13-body-void|S|rule-bodies/rule-13.md||## HANDOFF PROTOCOL|**An operator attribution MUST cite the operator's message.**|para|never entered the locked set
r13-body-locator|S|rule-bodies/rule-13.md||## HANDOFF PROTOCOL|**An operator attribution MUST cite the operator's message.**|para|a verbatim quote of the operator's message and a locator
disc-body-struck|S|steps/discovery.md|### 4a.|### 4b|**Every operator attribution carries a quote and a locator**|para|is struck here and never enters `LOCKED_REQUIREMENTS`
esc-body-hardblock|S|escalations.md|**Permanent-default change disclosure.**|**Terminal-entry archival|**Authorization-premise invalidation disclosure.**|para|File a new `HARD_BLOCK` entry
esc-body-operator|S|escalations.md|**Permanent-default change disclosure.**|**Terminal-entry archival|**Authorization-premise invalidation disclosure.**|para|put the question back to the operator
bug-2b-included|S|steps/bug-investigation.md|### 2b.|### 2c.|**The lead cannot apply the relief, so nothing substitutes for asking.**|para|between section 2 and section 3, §2c included.
bug-2c-adversary|S|steps/bug-investigation.md|### 2c.|### 3.|**The root-cause claim gets an adversarial pass before section 3.**|para|Dispatch ONE `adversary`
bug-2c-path|S|steps/bug-investigation.md|### 2c.|### 3.|It writes findings to|para|`_bmad-output/planning-artifacts/bug-analysis-adversarial.md`
bug-2c-evidence|S|steps/bug-investigation.md|### 2c.|### 3.|**Dispose of every CRITICAL and MAJOR before section 3**|para|An assertion without evidence is not a disposition.
adv-attr-body|R|adversary.md|## Severity|## |**An operator attribution missing its quote or its locator is a MAJOR.**|para|An attribution missing either is a MAJOR
adv-prem-body|R|adversary.md|## Severity|## |**An authorization whose named outcome a later event contradicted is a MAJOR.**|para|file a MAJOR.
gv-state-claim|S|steps/gate-validation.md|### 12.|### 13.|**A state claim MUST carry its command.**|prefix
r13-attribution|S|rule-bodies/rule-13.md||## HANDOFF PROTOCOL|**An operator attribution MUST cite the operator's message.**|prefix
disc-attribution|S|steps/discovery.md|### 4a.|### 4b|**Every operator attribution carries a quote and a locator**|prefix
esc-premise|S|escalations.md|**Permanent-default change disclosure.**|**Terminal-entry archival|**Authorization-premise invalidation disclosure.**|prefix
bug-2c-title|S|steps/bug-investigation.md|### 2b.|### 3.|### 2c. Adversarial verification of the root-cause claim|prefix
bug-2c-pass|S|steps/bug-investigation.md|### 2c.|### 3.|**The root-cause claim gets an adversarial pass before section 3.**|prefix
bug-2c-dispose|S|steps/bug-investigation.md|### 2c.|### 3.|**Dispose of every CRITICAL and MAJOR before section 3**|prefix
adv-attr-rung|R|adversary.md|## Severity|## |### An uncited operator attribution is a MAJOR|prefix
adv-attr-lead|R|adversary.md|## Severity|## |**An operator attribution missing its quote or its locator is a MAJOR.**|prefix
adv-prem-rung|R|adversary.md|## Severity|## |### A premise a later event contradicted is a MAJOR|prefix
adv-prem-lead|R|adversary.md|## Severity|## |**An authorization whose named outcome a later event contradicted is a MAJOR.**|prefix
route-range|S|steps/route.md|### Step 4:|### Step 5:|sections 0–2c|contains
sts-range|S|steps/stories-test-strategy.md|### 3a.|### 4.|sections 0–2c|contains
sts-names-2c|S|steps/stories-test-strategy.md|### 3a.|### 4.|§2c's adversarial verification of the root-cause|contains
party-seats-record|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**The seats edit nothing, in every case below.**|para|Each seat writes one findings file per (seat, shard)
party-seats-sections|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**The seats edit nothing, in every case below.**|para|carrying one `sections:` line
party-early-write|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**Every seat writes its file early and closes it with a completion line.**|para|Write the file's header first
party-complete-line|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**Every seat writes its file early and closes it with a completion line.**|para|Every beat that joins such a file passes `--complete`
party-one-writer|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**One repair writer applies them.**|para|never back to a seat
party-source|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**One repair writer applies them.**|para|carries `source: <seat-file>#<finding-id>`
party-unsharded|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**An unsharded round has the same write model.**|para|the seats still edit nothing, and ONE remediator
party-unsharded-check|S|steps/_gate-procedures.md|## Validation cycle|## Where a changelog is written|**An unsharded round has the same write model.**|para|join-remediator-shards.sh --sources <that record> --sprint <N>
srev-seats-record|S|steps/sprint-review.md|### 2. Sprint-Level Party Mode|### 3.|- Record every finding; the seats edit nothing|prefix
rem-party-source|R|remediator.md|## The evidence contract|## A REPAIR IS NOT A RESOLUTION|**A party repair names the seat finding behind every entry.**|para|every entry carries a `source:` line
PINS
}

pin_path() { case "$1" in S) printf '%s/%s\n' "$SKILL_DIR" "$2" ;; R) printf '%s/%s\n' "$ROLES_DIR" "$2" ;; esac; }

# The retired range. Alternation, never a bracket class: the en dash is multibyte.
RANGE_OLD='0(–|-)2b'
RANGE_NEW='0(–|-)2c'
range_count() { # range_count <regex> <dir>... -> matching line count across the dirs
  local re="$1" n; shift
  n="$(grep -rhE "$re" "$@" 2>/dev/null | wc -l | tr -d ' ')" || n=0
  printf '%s\n' "${n:-0}"
}

# consumer_owned — basenames of the consumer-owned scaffolds beside the core flat files,
# DERIVED from the layer contract's consumer_*_file keys rather than hand-listed. An
# installed tree lays those scaffolds down next to core's own files, and their content is
# the consumer's, which this fixture has no standing over.
consumer_owned() {
  local lc="$SKILL_DIR/layer-contract.yaml"
  [ -f "$lc" ] || return 1
  awk '/^consumer_[a-z_]*_file:[ \t]/ { v = $2; n = split(v, a, "/"); print a[n] }' "$lc"
}

range_scope() { # the core-installed paths only; paths carry no whitespace in either layout
  local p b own
  own=" $(consumer_owned | tr '\n' ' ') "
  for p in "$SKILL_DIR"/*.md "$SKILL_DIR/steps" "$SKILL_DIR/rule-bodies" "$ROLES_DIR"; do
    [ -e "$p" ] || continue
    b="$(basename "$p")"
    case "$own" in *" $b "*) continue ;; esac
    printf '%s ' "$p"
  done
}

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# corpus_report — the verdict over the resolved tree. Printed identically by --report.
corpus_report() {
  printf '  root: %s (%s)\n' "$ROOT" "$LAYOUT"
  local id base rel s e lead mode tok f out rc ins whole sl el fl
  while IFS='|' read -r id base rel s e lead mode tok; do
    f="$(pin_path "$base" "$rel")"
    [ -f "$f" ] || { bad "$id: subject file absent: ${f#"$ROOT/"}"; continue; }
    out="$(pin_scan "$f" "$s" "$e" "$lead" "$mode" "$tok")"; rc=$?
    [ "$rc" -eq 0 ] || { bad "$id: ${f#"$ROOT/"} has an unbalanced fence or comment"; continue; }
    read -r ins whole sl el fl <<<"$out"
    if [ "$sl" -eq 0 ] || [ "$el" -eq 0 ]; then
      bad "$id: span [${s:-<top>} .. $e] not found in ${f#"$ROOT/"} (start=$sl end=$el)"
    elif [ "$ins" -ge 1 ]; then
      ok "$id: pinned inside [${s:-<top>} .. $e] of ${f#"$ROOT/"}"
    else
      bad "$id: not inside [${s:-<top>} .. $e] of ${f#"$ROOT/"} (whole-file hits: $whole)"
    fi
  done <<<"$(pins)"

  # §2b precedes §2c precedes §3 — the title pin above proves §2c sits between §2b and §3;
  # this proves the three headings appear in that order as first occurrences.
  local bf="$SKILL_DIR/steps/bug-investigation.md" b2 c2 t3
  if [ -f "$bf" ]; then
    b2="$(pin_scan "$bf" "" "@@never@@" "### 2b." prefix | awk '{print $5}')"
    c2="$(pin_scan "$bf" "" "@@never@@" "### 2c." prefix | awk '{print $5}')"
    t3="$(pin_scan "$bf" "" "@@never@@" "### 3." prefix | awk '{print $5}')"
    if [ "${b2:-0}" -gt 0 ] && [ "${c2:-0}" -gt "${b2:-0}" ] && [ "${t3:-0}" -gt "${c2:-0}" ]; then
      ok "order: §2b (line $b2) < §2c (line $c2) < §3 (line $t3)"
    else
      bad "order: §2b=${b2:-?} §2c=${c2:-?} §3=${t3:-?} — §2c must sit after §2b and before §3"
    fi
  else
    bad "order: bug-investigation.md absent"
  fi

  # No retired 0–2b range remains; the 0–2c count beside it proves the scan reads the tree.
  # Scope: what install.sh lays down — the flat skill files, steps/, rule-bodies/ and the
  # roles. Never extensions/ or overrides/, which on a consumer hold consumer-owned prose
  # this fixture has no standing over.
  local old new scope nown
  nown="$(consumer_owned | grep -c .)" || nown=0
  [ "$nown" -ge 1 ] || bad "range: no consumer_*_file key derivable from layer-contract.yaml — consumer scaffolds cannot be excluded"
  scope="$(range_scope)"
  old="$(range_count "$RANGE_OLD" $scope)"
  new="$(range_count "$RANGE_NEW" $scope)"
  if [ "$old" -gt 0 ]; then
    bad "range: $old line(s) still carry the retired 0–2b range"
  elif [ "$new" -lt 2 ]; then
    bad "range: control found only $new line(s) carrying 0–2c — the scan cannot see the tree, its zero is no finding"
  else
    ok "range: 0 lines carry the retired 0–2b range (control: $new carry 0–2c)"
  fi
}

RESOLVED="$(resolve_root "$HERE" || true)"
if [ "${1:-}" = "--report" ]; then
  [ -n "$RESOLVED" ] && dirs_for "$RESOLVED" || { echo "FIXTURE ERROR: no ai-dlc skill dir above $HERE" >&2; exit 2; }
  corpus_report
  [ "$fails" -eq 0 ] && exit 0 || exit 1
fi

echo "process-rule-pins"
WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

# --- 1. resolver probes, every root shape --------------------------------------
LAY="$WORK/lay"
mkdir -p "$LAY/dist/core/skills/ai-dlc" "$LAY/dist/core/team-roles" "$LAY/dist/core/fixtures/x" \
         "$LAY/cons/.claude/skills/ai-dlc" "$LAY/cons/.claude/team-roles" "$LAY/cons/tests/fixtures/x" \
         "$LAY/none/tests/fixtures/x" || exit 2
got="$(resolve_root "$LAY/dist/core/fixtures/x" || true)"
[ "$got" = "dist $LAY/dist" ] && ok "resolver: distribution layout from core/fixtures/<name>" \
                              || bad "resolver: distribution layout — got '${got:-<none>}'"
got="$(resolve_root "$LAY/cons/tests/fixtures/x" || true)"
[ "$got" = "consumer $LAY/cons" ] && ok "resolver: consumer layout from tests/fixtures/<name>" \
                                  || bad "resolver: consumer layout — got '${got:-<none>}'"
# Fail-closed: ceilinged at the probe tree, so nothing above the temp dir can answer. The
# exit status AND the empty output are both asserted; either alone admits an invented root.
got="$(resolve_root "$LAY/none/tests/fixtures/x" "$LAY/none")"; rc=$?
[ "$rc" -eq 1 ] && [ -z "$got" ] && ok "resolver: fails closed (rc=1, no root) on a tree with neither layout" \
                                 || bad "resolver: did not fail closed on a tree with neither layout — rc=$rc got='$got'"
got="$(resolve_root "$LAY/cons/tests/fixtures/x" "$LAY/cons")"; rc=$?
[ "$rc" -eq 0 ] && [ "$got" = "consumer $LAY/cons" ] && ok "CONTROL: the same ceiling still admits a root that IS inside it" \
                                                   || bad "CONTROL: the ceiling refused a root inside it — rc=$rc got='$got'"

# --- 2. engine probes, both directions, on synthetic text ----------------------
P="$WORK/probe"; mkdir -p "$P" || exit 2
probe() { # probe <label> <expected-ins> <file> <start> <end> <lead> <mode> [<token>]
  local label="$1" want="$2" out rc ins
  out="$(pin_scan "$3" "$4" "$5" "$6" "$7" "${8:-}")"; rc=$?
  [ "$rc" -eq 0 ] || { bad "engine: $label — scan returned rc=$rc"; return; }
  ins="${out%% *}"
  [ "$ins" = "$want" ] && ok "engine: $label (in-span=$ins)" || bad "engine: $label — in-span=$ins, wanted $want"
}
printf '# t\n## A\n**LEAD.** in span\n## B\n**LEAD.** after\n' > "$P/hit.md"
probe "a lead inside the span is found" 1 "$P/hit.md" "## A" "## B" "**LEAD.**" prefix
printf '# t\n## A\nprose\n## B\n**LEAD.** after\n' > "$P/out.md"
probe "a lead only outside the span is not found" 0 "$P/out.md" "## A" "## B" "**LEAD.**" prefix
printf '## A\n```\n**LEAD.** fenced\n```\n## B\n' > "$P/fence.md"
probe "a fenced lead is not found" 0 "$P/fence.md" "## A" "## B" "**LEAD.**" prefix
printf '## A\n<!--\n**LEAD.** commented\n-->\n<!-- **LEAD.** one-line -->\n## B\n' > "$P/com.md"
probe "a commented lead is not found" 0 "$P/com.md" "## A" "## B" "**LEAD.**" prefix
printf '## A\n  **LEAD.** indented\nsee **LEAD.** mid-line\n## B\n' > "$P/indent.md"
probe "an indented or mid-line lead is not a line-start pin" 0 "$P/indent.md" "## A" "## B" "**LEAD.**" prefix
probe "a mid-line token IS found in contains mode" 2 "$P/indent.md" "## A" "## B" "**LEAD.**" contains
printf '## A\n```\n## B fenced end marker\n```\n**LEAD.** after fenced marker\n## B\n' > "$P/fend.md"
probe "a fenced span-end marker does not close the span" 1 "$P/fend.md" "## A" "## B" "**LEAD.**" prefix
printf '## A\n### sub\n**LEAD.** under a subheading\n## B\n' > "$P/sub.md"
probe "a ### heading does not close a ## span" 1 "$P/sub.md" "## A" "## " "**LEAD.**" prefix
printf '**LEAD.** top\n## B\n**LEAD.** after\n' > "$P/top.md"
probe "an empty start opens the span at line 1" 1 "$P/top.md" "" "## B" "**LEAD.**" prefix
out="$(pin_scan "$P/out.md" "## Z" "## B" "**LEAD.**" prefix)"
[ "$(printf '%s' "$out" | awk '{print $3}')" = "0" ] && ok "engine: a missing span start is reported as start=0" \
                                                     || bad "engine: missing span start not reported — '$out'"
printf '## A\n```\n**LEAD.**\n## B\n' > "$P/unbal.md"
pin_scan "$P/unbal.md" "## A" "## B" "**LEAD.**" prefix >/dev/null; rc=$?
[ "$rc" -eq 2 ] && ok "engine: an unbalanced fence is a broken file (rc=2), not a missing pin" \
                || bad "engine: unbalanced fence returned rc=$rc"
# A comment opened mid-line hides the rest of the line and what follows until it closes.
printf '## A\nprose <!--\n**LEAD.** hidden\n-->\n## B\n' > "$P/midcom.md"
probe "a lead after a mid-line comment opener is hidden" 0 "$P/midcom.md" "## A" "## B" "**LEAD.**" prefix

# Paragraph mode: lead and token joined across a line wrap, both directions.
printf '## A\n\n**LEAD.** the rule MUST\ncarry it here.\n\n## B\n' > "$P/para.md"
probe "para: a token wrapped across lines under the lead is found" 1 "$P/para.md" "## A" "## B" "**LEAD.**" para "MUST carry it"
printf '## A\n\n**LEAD.** the rule need NOT\ncarry it here.\n\n## B\n' > "$P/paraneg.md"
probe "para: the same paragraph with the clause negated is not found" 0 "$P/paraneg.md" "## A" "## B" "**LEAD.**" para "MUST carry it"
printf '## A\n\n**LEAD.** the rule.\n\nMUST carry it, in another paragraph.\n\n## B\n' > "$P/parasplit.md"
probe "para: the token in a DIFFERENT paragraph from the lead is not found" 0 "$P/parasplit.md" "## A" "## B" "**LEAD.**" para "MUST carry it"
printf '## A\n\n**LEAD.** the rule.\n\n## B\n\n**LEAD.** MUST carry it.\n' > "$P/paraout.md"
probe "para: lead and token together but outside the span are not found" 0 "$P/paraout.md" "## A" "## B" "**LEAD.**" para "MUST carry it"
printf '## A\n\n**LEAD.** the rule\n<!-- MUST carry it -->\n\n## B\n' > "$P/paracom.md"
probe "para: the token inside a comment is not found" 0 "$P/paracom.md" "## A" "## B" "**LEAD.**" para "MUST carry it"
printf '## A\n**LEAD.** the rule\n## B\nMUST carry it\n' > "$P/parahead.md"
probe "para: a heading ends a paragraph, so a token beyond the span end does not join" 0 "$P/parahead.md" "## A" "## B" "**LEAD.**" para "MUST carry it"

# Range scan probe, both directions.
mkdir -p "$P/r1" "$P/r2" || exit 2
printf 'sections 0–2b for the defect\nsections 0-2b ascii\n' > "$P/r1/a.md"
printf 'sections 0–2c here; §2b stays; section 2b too\n' > "$P/r2/a.md"
n="$(range_count "$RANGE_OLD" "$P/r1")"
[ "$n" = "2" ] && ok "range probe: en-dash and hyphen spellings of 0–2b both found (2)" || bad "range probe: found $n of 2 seeded 0–2b lines"
n="$(range_count "$RANGE_OLD" "$P/r2")"
[ "$n" = "0" ] && ok "range probe: 0–2c and a bare §2b are not the retired range (0)" || bad "range probe: near-miss scored $n"
# Scope probe: a consumer-owned extension carrying the old range is out of scope; the same
# text in steps/ is in scope.
mkdir -p "$P/sc/sk/extensions" "$P/sc/sk/steps" "$P/sc/roles" || exit 2
printf 'sections 0–2b in an extension\n' > "$P/sc/sk/extensions/x.md"
n="$( SKILL_DIR="$P/sc/sk" ROLES_DIR="$P/sc/roles"; range_count "$RANGE_OLD" $(range_scope) )"
[ "$n" = "0" ] && ok "range scope: extensions/ is not scanned (0)" || bad "range scope: extensions/ scanned ($n)"
printf 'sections 0–2b in a step\n' > "$P/sc/sk/steps/s.md"
n="$( SKILL_DIR="$P/sc/sk" ROLES_DIR="$P/sc/roles"; range_count "$RANGE_OLD" $(range_scope) )"
[ "$n" = "1" ] && ok "range scope: steps/ is scanned (1)" || bad "range scope: steps/ not scanned ($n)"
# Consumer-layout scope: a consumer-owned scaffold beside the core flat files, declared by a
# consumer_*_file key, is out of scope; a core flat file beside it is in scope; and with the
# key removed the same scaffold IS read, which proves the exclusion is the derivation.
CS="$P/cs/.claude/skills/ai-dlc"; mkdir -p "$CS/steps" "$P/cs/.claude/team-roles" || exit 2
printf 'consumer_crosswalk_file: .claude/skills/ai-dlc/crosswalk.md\n' > "$CS/layer-contract.yaml"
printf 'sections 0–2b in a consumer crosswalk\n' > "$CS/crosswalk.md"
n="$( SKILL_DIR="$CS" ROLES_DIR="$P/cs/.claude/team-roles"; range_count "$RANGE_OLD" $(range_scope) )"
[ "$n" = "0" ] && ok "range scope (consumer): crosswalk.md, declared consumer-owned, is not scanned (0)" \
               || bad "range scope (consumer): consumer-owned crosswalk.md scanned ($n)"
printf 'sections 0–2b in a core flat file\n' > "$CS/escalations.md"
n="$( SKILL_DIR="$CS" ROLES_DIR="$P/cs/.claude/team-roles"; range_count "$RANGE_OLD" $(range_scope) )"
[ "$n" = "1" ] && ok "range scope (consumer): a core flat file beside it is scanned (1)" \
               || bad "range scope (consumer): core flat file not scanned ($n)"
printf 'unrelated: 1\n' > "$CS/layer-contract.yaml"
n="$( SKILL_DIR="$CS" ROLES_DIR="$P/cs/.claude/team-roles"; range_count "$RANGE_OLD" $(range_scope) )"
[ "$n" = "2" ] && ok "MUTANT range scope: without the consumer_*_file key the crosswalk IS read (2) — the exclusion is the derivation" \
               || bad "MUTANT range scope: removing the key left the count at $n — the exclusion is not what the probe credited"

# --- 3. resolve the real tree --------------------------------------------------
[ -n "$RESOLVED" ] && dirs_for "$RESOLVED" || {
  echo "FIXTURE ERROR: no ai-dlc skill dir found walking up from $HERE" >&2; exit 2; }

# --- 4. per-pin near-misses and deletion mutants, on copies of the real files ---
# mutate <mode> <src> <dst> <lead> <match>  — rewrites every line carrying the lead
mutate() {
  MU_MODE="$1" MU_LEAD="$4" MU_MATCH="$5" awk '
  BEGIN { m = ENVIRON["MU_MODE"]; l = ENVIRON["MU_LEAD"]; k = ENVIRON["MU_MATCH"]; n = 0 }
  {
    if (k == "contains") hit = (index($0, l) > 0); else hit = (index($0, l) == 1)
    if (!hit) { print; next }
    if (m == "delete")   next
    if (m == "relocate") { held[++n] = $0; next }
    if (m == "fence")    { print "```"; print; print "```"; next }
    if (m == "comment")  { print "<!--"; print; print "-->"; next }
    if (m == "indent")   { print "  " $0; next }
    print
  }
  END { for (i = 1; i <= n; i++) print held[i] }' "$2" > "$3"
}
# flatten <src> <dst> — every paragraph outside fences and comments onto ONE line. The para
# mutants edit this form so a token wrapped across lines can be negated or moved whole; a
# control asserts the flattened copy scores exactly as the original does before any mutant
# verdict is read.
flatten() {
  awk '
  function out() { if (p != "") print p; p = "" }
  {
    t = $0; sub(/^[ \t]+/, "", t)
    if (com) { print; if (index($0, "-->")) com = 0; next }
    if (fence != "") { print; if (substr(t, 1, 3) == fence) fence = ""; next }
    if (substr(t, 1, 3) == "```" || substr(t, 1, 3) == "~~~") { out(); fence = substr(t, 1, 3); print; next }
    if (index($0, "<!--") && !index(substr($0, index($0, "<!--") + 4), "-->")) { out(); com = 1; print; next }
    if (t == "") { out(); print; next }
    if (substr(t, 1, 1) == "#") { out(); print; next }
    p = (p == "" ? $0 : p " " $0)
  }
  END { out() }' "$1" > "$2"
}
# pmutate <mode> <flat-src> <dst> <lead> <token> — acts on the one paragraph line that begins
# with the lead and carries the token.
pmutate() {
  MU_MODE="$1" MU_LEAD="$4" MU_TOK="$5" awk '
  BEGIN { m = ENVIRON["MU_MODE"]; l = ENVIRON["MU_LEAD"]; k = ENVIRON["MU_TOK"]; n = 0 }
  {
    # Collapsed and left-trimmed exactly as pin_scan flush() does, so a paragraph indented under
    # a numbered list item is the same string to the mutator as to the scanner.
    q = $0; gsub(/[ \t]+/, " ", q); sub(/^ /, "", q)
    if (!(index(q, l) == 1 && index(q, k) > 0)) { print; next }
    if (m == "negate")   { i = index(q, k); print substr(q, 1, i - 1) "NEGATED-CLAUSE" substr(q, i + length(k)); next }
    if (m == "relocate") { held[++n] = q; next }
    if (m == "fence")    { print "```"; print q; print "```"; next }
    if (m == "comment")  { print "<!--"; print q; print "-->"; next }
    print
  }
  END { for (i = 1; i <= n; i++) { print ""; print held[i] } }' "$2" > "$3"
}

M="$WORK/mut"; mkdir -p "$M" || exit 2
while IFS='|' read -r id base rel s e lead mode tok; do
  f="$(pin_path "$base" "$rel")"
  [ -f "$f" ] || { bad "$id: subject ${f#"$ROOT/"} absent — no near-miss or mutant can be built"; continue; }
  raw="$(grep -cF -- "$lead" "$f")" || raw=0
  [ "$raw" -ge 1 ] || { bad "$id: lead absent from ${f#"$ROOT/"} — mutants have no subject"; continue; }
  if [ "$mode" = "para" ]; then
    flat="$M/$id.flat.md"; flatten "$f" "$flat"
    o1="$(pin_scan "$f" "$s" "$e" "$lead" para "$tok")"; o2="$(pin_scan "$flat" "$s" "$e" "$lead" para "$tok")"
    if [ "${o1%% *}" != "1" ] || [ "${o2%% *}" != "1" ]; then
      bad "$id: CONTROL — original in-span=${o1%% *}, flattened in-span=${o2%% *}; both must be 1 before a mutant is read"; continue
    fi
    for mm in negate relocate fence comment; do
      dst="$M/$id.$mm.md"
      pmutate "$mm" "$flat" "$dst" "$lead" "$tok"
      if cmp -s "$flat" "$dst"; then bad "$id/$mm: mutation did not apply"; continue; fi
      out="$(pin_scan "$dst" "$s" "$e" "$lead" para "$tok")"; rc=$?
      [ "$rc" -eq 0 ] || { bad "$id/$mm: mutated copy unbalanced (rc=$rc)"; continue; }
      read -r ins whole sl el fl <<<"$out"
      case "$mm" in
        negate)   [ "$ins" -eq 0 ] && [ "$whole" -eq 0 ] && ok "$id/negate: binding clause rewritten under an intact lead — killed" \
                    || bad "$id/negate: SURVIVED (in-span=$ins whole=$whole)" ;;
        relocate) [ "$ins" -eq 0 ] && [ "$whole" -ge 1 ] && ok "$id/relocate: paragraph outside the span fails though it is still in the file" \
                    || bad "$id/relocate: in-span=$ins whole=$whole — span does not discriminate" ;;
        fence|comment)
                  [ "$ins" -eq 0 ] && [ "$whole" -eq 0 ] && ok "$id/$mm: wrapped paragraph is invisible though still present" \
                    || bad "$id/$mm: in-span=$ins whole=$whole" ;;
      esac
    done
    continue
  fi
  modes="delete relocate fence comment"
  [ "$mode" = "prefix" ] && modes="$modes indent"
  for mm in $modes; do
    dst="$M/$id.$mm.md"
    mutate "$mm" "$f" "$dst" "$lead" "$mode"
    if cmp -s "$f" "$dst"; then bad "$id/$mm: mutation did not apply"; continue; fi
    out="$(pin_scan "$dst" "$s" "$e" "$lead" "$mode")"; rc=$?
    [ "$rc" -eq 0 ] || { bad "$id/$mm: mutated copy unbalanced (rc=$rc)"; continue; }
    read -r ins whole sl el fl <<<"$out"
    case "$mm" in
      delete)   [ "$ins" -eq 0 ] && [ "$whole" -eq 0 ] && ok "$id/delete: mutant killed" \
                  || bad "$id/delete: SURVIVED (in-span=$ins whole=$whole)" ;;
      relocate) [ "$ins" -eq 0 ] && [ "$whole" -ge 1 ] && ok "$id/relocate: outside the span fails though the line is still in the file" \
                  || bad "$id/relocate: in-span=$ins whole=$whole — span does not discriminate" ;;
      fence|comment)
                kept="$(grep -cF -- "$lead" "$dst")" || kept=0
                [ "$ins" -eq 0 ] && [ "$whole" -eq 0 ] && [ "$kept" -ge 1 ] && ok "$id/$mm: wrapped line is invisible though still present" \
                  || bad "$id/$mm: in-span=$ins whole=$whole raw=$kept" ;;
      indent)   [ "$ins" -eq 0 ] && ok "$id/indent: not at line start fails" \
                  || bad "$id/indent: indented lead still pinned (in-span=$ins)" ;;
    esac
  done
done <<<"$(pins)"

# --- 4b. a join over seat or cross files passes --complete -----------------------
# A seat or cross shard writes its file early and is finished only at its final `seat-complete:`
# line, so a beat without --complete takes a half-written file as delivered. join_scan prints one
# row per wait-for-deliverable.sh CALL (the name, a blank, then <, [ or -) outside fences and
# comments: <file>:<line> TAB P=<1 when the paragraph names seat or cross> TAB COMPLETE|BARE.
# The FINDING is a P=1 paragraph with no COMPLETE call. A paragraph may also join a non-shard
# deliverable with a bare call beside its --complete one (carry-over-evaluation.md joins the
# analyst artifact that way), so the unit is the paragraph, never the single call. A join that
# names no seat or cross path is exempt.
# How the false-positive set reached zero: a per-call clause rule flagged the analyst call in
# that mixed paragraph; a section-wide rule pulled the generic "Join every spawn" paragraph of
# the Validation cycle in under item 1. Paragraph scope with "any COMPLETE" is the narrowing.
join_scan() {
  awk '
  function flush(   s, i, c, rest, k, args, q, ln, base) {
    if (p == "") return
    s = p; base = 0
    while ((i = index(s, "wait-for-deliverable.sh ")) > 0) {
      c = substr(s, i + 24, 1); rest = substr(s, i + 24)
      if (c == "<" || c == "[" || c == "-") {
        k = index(rest, "`"); args = (k ? substr(rest, 1, k - 1) : rest)
        ln = 0; for (q = 1; q <= nl; q++) if (st[q] <= base + i) ln = lno[q]
        printf "%s:%d:%d\tP=%d\t%s\n", pf, pl, ln, (tolower(p) ~ /seat|cross/), (args ~ /--complete/ ? "COMPLETE" : "BARE")
      }
      base += i + 23; s = rest
    }
    p = ""; nl = 0
  }
  FNR == 1 { flush(); fence = ""; com = 0 }
  {
    t = $0; sub(/^[ \t]+/, "", t)
    if (com) { if (index($0, "-->")) com = 0; flush(); next }
    if (fence != "") { if (substr(t, 1, 3) == fence) fence = ""; next }
    if (substr(t, 1, 3) == "```" || substr(t, 1, 3) == "~~~") { flush(); fence = substr(t, 1, 3); next }
    if (substr(t, 1, 4) == "<!--") { if (!index(substr(t, 5), "-->")) com = 1; flush(); next }
    if (t == "" || t ~ /^#+ /) { flush(); next }
    if (p == "") { pf = FILENAME; pl = FNR; p = t; nl = 1; st[1] = 1; lno[1] = FNR }
    else { nl++; st[nl] = length(p) + 2; lno[nl] = FNR; p = p " " t }
  }
  END { flush() }' "$@"
}
# join_findings <files...> -> one line per seat/cross paragraph with no --complete call
join_findings() {
  join_scan "$@" | awk -F'\t' '{ split($1, a, ":"); key = a[1] ":" a[2] }
    $2 == "P=1" { seen[key] = $1; if ($3 == "COMPLETE") ok[key] = 1 }
    END { for (k in seen) if (!(k in ok)) print seen[k] }'
}
JS="$WORK/join"; mkdir -p "$JS" || exit 2
printf 'Join the seats with one `scripts/ai-dlc/wait-for-deliverable.sh <path> [<path> ...]` call per wave.\n' > "$JS/off.md"
printf 'Join the artifact with one `scripts/ai-dlc/wait-for-deliverable.sh <artifact_path>` call.\n' > "$JS/exempt.md"
printf 'The analyst with `scripts/ai-dlc/wait-for-deliverable.sh <path>`, and each wave of seat files\nwith `scripts/ai-dlc/wait-for-deliverable.sh --complete <path>`.\n' > "$JS/mixed.md"
printf '```\nJoin the seats with `scripts/ai-dlc/wait-for-deliverable.sh <path>`.\n```\n' > "$JS/fenced.md"
n_off="$(join_findings "$JS/off.md" | grep -c .)" || n_off=0
n_ex="$(join_findings "$JS/exempt.md" | grep -c .)" || n_ex=0
n_mx="$(join_findings "$JS/mixed.md" | grep -c .)" || n_mx=0
n_fc="$(join_findings "$JS/fenced.md" | grep -c .)" || n_fc=0
n_exc="$(join_scan "$JS/exempt.md" | grep -c .)" || n_exc=0
if [ "$n_off" = 1 ] && [ "$n_ex" = 0 ] && [ "$n_exc" = 1 ] && [ "$n_mx" = 0 ] && [ "$n_fc" = 0 ]; then
  ok "join-pre: a bare seat join is flagged (1); a non-shard join is scanned (1 call) and exempt (0); a seat paragraph with one --complete call beside a bare one passes (0); a fenced seat join is not read (0)"
else
  bad "join-pre: FIXTURE BROKEN -- off=$n_off exempt=$n_ex (calls $n_exc) mixed=$n_mx fenced=$n_fc; want 1 0 (1) 0 0"
fi
JSCOPE="$SKILL_DIR/steps/*.md $SKILL_DIR/rule-bodies/*.md $ROLES_DIR/*.md"
# shellcheck disable=SC2086 # the scope globs are expanded on purpose; no path carries a blank
n_seat="$(join_scan $JSCOPE | awk -F'\t' '$2 == "P=1"' | grep -c .)" || n_seat=0
# shellcheck disable=SC2086
jf="$(join_findings $JSCOPE)"
if [ "$n_seat" -lt 3 ]; then
  bad "join: only $n_seat seat or cross join call(s) found in the steps, rule bodies and roles -- the scan cannot see the joins it guards, so its zero is no finding"
elif [ -n "$jf" ]; then
  bad "join: a seat or cross join paragraph carries no --complete call: $(printf '%s' "$jf" | sed "s|$ROOT/||g" | tr '\n' ' ')"
else
  ok "join: every seat or cross join paragraph carries --complete ($n_seat seat or cross join call(s) scanned)"
fi
# MUTANTS: --complete stripped from each real site, ONE LINE AT A TIME; every strip must be flagged.
# The site list is derived from the corpus, and its count is asserted, so a site the scan cannot see
# reads as a survivor rather than as a smaller battery.
jm="$WORK/join-mut"; mkdir -p "$jm" || exit 2
n_sites=0; n_killed=0; j_surv=""
# shellcheck disable=SC2086
for jf_f in $JSCOPE; do
  for jf_l in $(grep -n 'wait-for-deliverable\.sh --complete' "$jf_f" | cut -d: -f1); do
    n_sites=$((n_sites + 1))
    awk -v L="$jf_l" 'NR == L { gsub(/wait-for-deliverable\.sh --complete/, "wait-for-deliverable.sh") } { print }' "$jf_f" > "$jm/m.md"
    if cmp -s "$jf_f" "$jm/m.md"; then j_surv="$j_surv ${jf_f#"$ROOT/"}:$jf_l(no-apply)"; continue; fi
    n_m="$(join_findings "$jm/m.md" | grep -c .)" || n_m=0
    if [ "$n_m" -ge 1 ]; then n_killed=$((n_killed + 1)); else j_surv="$j_surv ${jf_f#"$ROOT/"}:$jf_l"; fi
  done
done
if [ "$n_sites" -lt 3 ]; then
  bad "join/mutant: only $n_sites --complete site(s) found -- the battery has nothing to strip"
elif [ -n "$j_surv" ]; then
  bad "join/mutant: SURVIVED -- --complete stripped at [${j_surv# }] was not flagged ($n_killed/$n_sites killed)"
else
  ok "join/mutant: --complete stripped from each of $n_sites real sites, one at a time, is flagged ($n_killed/$n_sites)"
fi

# --- 5. the real corpus ---------------------------------------------------------
echo ""
echo "  corpus:"
REP_HERE="$(bash "$SELF" --report 2>&1)"; rc_here=$?
printf '%s\n' "$REP_HERE"
n_ok="$(grep -c '^  ok ' <<<"$REP_HERE")" || n_ok=0
n_bad="$(grep -c '^  FAIL ' <<<"$REP_HERE")" || n_bad=0
fails=$((fails + n_bad))
[ "$rc_here" -eq 0 ] || [ "$n_bad" -gt 0 ] || bad "corpus: --report exited $rc_here with no FAIL line"
n_want=$(( $(pins | wc -l) + 2 ))
[ "$n_ok" -eq "$n_want" ] || bad "corpus: $n_ok ok line(s), wanted $n_want (one per pin, plus order and range) — a report that ran nothing is not a pass"

# --- 6. cwd-invariance: the same verdict from a decoy tree ----------------------
DECOY="$WORK/decoy"
mkdir -p "$DECOY/.claude/skills/ai-dlc/steps" "$DECOY/.claude/team-roles" || exit 2
printf '### 12. decoy\n### 13. decoy\n' > "$DECOY/.claude/skills/ai-dlc/steps/gate-validation.md"
REP_DECOY="$( cd "$DECOY" && bash "$SELF" --report 2>&1 )"; rc_decoy=$?
if [ "$REP_DECOY" = "$REP_HERE" ] && [ "$rc_decoy" -eq "$rc_here" ]; then
  ok "cwd: a decoy ai-dlc tree as cwd yields the byte-identical verdict (root: $ROOT)"
else
  bad "cwd: verdict changed with the cwd (rc $rc_here -> $rc_decoy)"
fi
got="$( cd "$DECOY" && resolve_root "$(pwd)" || true )"
[ "$got" = "consumer $DECOY" ] && ok "CONTROL: the decoy is a resolvable root, so a cwd-seeded resolver would have read it" \
                               || bad "CONTROL: the decoy did not resolve from its own cwd ('${got:-<none>}') — the cwd arm proves nothing"
MC="$WORK/mutcwd"; mkdir -p "$MC" || exit 2
anchor='RESOLVED="$(resolve_root "$HERE" || true)"'
na="$(grep -cxF -- "$anchor" "$SELF")" || na=0
if [ "$na" -ne 1 ]; then
  bad "MUTANT cwd: resolver anchor found $na times, wanted 1 — the cwd mutant cannot be built"
else
  sed -e 's@^RESOLVED="$(resolve_root "$HERE" || true)"$@RESOLVED="$(resolve_root "$(pwd)" || true)"@' "$SELF" > "$MC/run.sh"
  if cmp -s "$SELF" "$MC/run.sh"; then
    bad "MUTANT cwd: sed did not apply"
  else
    mout="$( cd "$DECOY" && bash "$MC/run.sh" --report 2>&1 )"
    case "$mout" in
      *"root: $DECOY (consumer)"*) ok "MUTANT cwd: a resolver seeded from the cwd reads the decoy; the cwd arm kills it" ;;
      *) bad "MUTANT cwd: cwd-seeded resolver did not read the decoy — the cwd arm cannot fire" ;;
    esac
  fi
fi

echo ""
if [ "$fails" -eq 0 ]; then
  echo "process-rule-pins: PASS"
  exit 0
fi
echo "process-rule-pins: FAIL ($fails assertion(s))"
exit 1
