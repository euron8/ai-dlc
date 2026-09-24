#!/usr/bin/env bash
# reconcile-region: exempt — a remediation action that pulls an unregistered edit INTO the layer system; unregistered-drift.sh is the classifier and it IS in the region.
# register-drift.sh — pull an unregistered in-place core edit INTO the layer system.
#
# `unregistered-drift.sh` finds a core file the consumer edited in place: no override
# entry, no base_sha, invisible to layer-drift.sh, and DELETED without a word by the
# next `apply` (core is upstream-owned and overwritten). Detecting that was half the
# job. Telling the operator "refile the delta as an override with a base_sha" and
# leaving them to hand-author the YAML, pick the anchor, and copy the right section out
# is the other half, undone — and a hand-authored anchor that resolves to no heading is
# how drift detection dies silently (this repo has repointed four such overrides).
#
# This authors the entry, extracts the consumer's own section verbatim, and reverts
# core. The operator confirms and writes the `reason:`; they do not do the surgery.
#
# The `base_sha` is stamped at BASE -- the sha the consumer's text actually forked
# from, not the sha being pulled. If upstream ALSO changed that section in this pull,
# the new entry is immediately reported as HARD-OVERRIDE-DRIFT-SECTION and goes through
# `readopt-override.sh --merge` like any other. Stamping `theirs` here would silently
# claim the consumer had already read upstream's change. It has not.
#
# Usage: register-drift.sh <dist-repo> <base-sha> <consumer-root> <core-rel-path> [--apply]
#          core-rel-path e.g. team-roles/tea.md  |  skills/ai-dlc/steps/retro.md
#        (default: dry-run -- print the override it WOULD write)
# Exit:  0 ok / 1 nothing to register / 2 usage OR refusal -- a section that cannot be
#        classified or accounted for; nothing is written and core is NOT reverted
set -uo pipefail

DIST="${1:?usage: register-drift.sh <dist-repo> <base-sha> <consumer-root> <core-rel-path> [--apply]}"
BASE="${2:?}"
CONSUMER="${3:?}"
REL="${4:?}"
APPLY="${5:-}"

case "$REL" in
  skills/ai-dlc/*) CONS_FILE="$CONSUMER/.claude/skills/ai-dlc/${REL#skills/ai-dlc/}"; SHADOW_TGT="${REL#skills/ai-dlc/}" ;;
  team-roles/*)    CONS_FILE="$CONSUMER/.claude/team-roles/${REL#team-roles/}";       SHADOW_TGT="$REL" ;;
  hooks/*)
    echo "register-drift: $REL is a HOOK. The layer system has no override grain for hooks —" >&2
    echo "  overrides shadow rulebook headings. Keep the consumer hook (accept per-entry) or" >&2
    echo "  upstream the change." >&2
    echo "  If upstream has ALREADY absorbed it, unregistered-drift.sh reports" >&2
    echo "  HARD-CORE-DRIFT-ABSORBED and the remedy is a REVERT, not an override." >&2
    exit 2 ;;
  # THE SECOND NO-GRAIN CASE, and it needs its own name for the same reason hooks does.
  # Overrides live at `.claude/skills/ai-dlc/overrides/` and every one of them shadows a heading
  # in a file inside THAT skill. `ai-dlc-setup` is a second skill and `schemas/` is data with no
  # headings, so neither has anything to shadow. Both are `scan`-marked in I12, so
  # unregistered-drift.sh DOES report them and the report hands the operator the register-drift
  # command below — which used to answer `unrecognized core path`, a message that reads like a
  # typo in the path rather than a structural refusal, on a path the report itself supplied.
  #
  # This list is not free: validate-enforcement-map.sh I31 requires every I12 `scan` subtree to
  # be either registerable above or named here, so a new scan-marked subtree fails the build
  # until someone decides which it is.
  schemas/*|skills/ai-dlc-setup/*)
    echo "register-drift: $REL has NO OVERRIDE GRAIN. The layer system's overrides live at" >&2
    echo "  .claude/skills/ai-dlc/overrides/ and each one shadows a HEADING inside the ai-dlc" >&2
    echo "  skill. A second core skill (ai-dlc-setup) and schema data have no heading to shadow," >&2
    echo "  so there is nothing to refile into. This is structural, not a missing case." >&2
    echo "  Two dispositions, and both are real: keep the consumer's version (accept per-entry —" >&2
    echo "  it re-reports HARD- on every pull, which is the honest cost), or take the change" >&2
    echo "  upstream so the divergence disappears. Reverting destroys the divergence; say so" >&2
    echo "  before anyone chooses it." >&2
    echo "  If upstream has ALREADY absorbed it, unregistered-drift.sh reports" >&2
    echo "  HARD-CORE-DRIFT-ABSORBED and the remedy is a REVERT, not an override." >&2
    exit 2 ;;
  *) echo "register-drift: unrecognized core path: $REL" >&2; exit 2 ;;
esac

CORE="core/${REL}"
[ -f "$CONS_FILE" ] || { echo "register-drift: consumer file absent: $CONS_FILE" >&2; exit 2; }
git -C "$DIST" cat-file -e "${BASE}:${CORE}" 2>/dev/null || { echo "register-drift: $CORE absent at $BASE" >&2; exit 2; }

OVR_DIR="$CONSUMER/.claude/skills/ai-dlc/overrides"
mkdir -p "$OVR_DIR"

# Top-level heading names in the consumer's file.
headings_of() { grep -nE '^#{2,3} ' "$1" | sed 's/:.*#\{2,3\} /:/'; }

# section_of() — the ONE resolver, from lib.sh.
#
# A stricter matcher here does not merely miss a section; it MISFILES it. The resolver
# matches bidirectionally on substrings, so the consumer's `## Escalation Protocol`
# resolves against core's `## Escalation` — a RENAMED section, which is an override. An
# exact matcher finds nothing, concludes core has no such heading, and routes it to
# `extensions/` as an ADDITION. Extensions are additive: core's `Escalation` and the
# consumer's `Escalation Protocol` would then BOTH render, as duplicate and conflicting
# guidance in one document. That shipped, in v0.54.2.
#
# Two resolvers that disagree means the tool and the gate disagree, and the tool wins.
# This used to say "byte for byte" over a hand-copied body; now there is one body.
SELF="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$SELF/lib.sh" || { echo "register-drift: cannot source $SELF/lib.sh" >&2; exit 1; }

# Which sections did the consumer actually change? Only those go in the override —
# an override that restates unchanged core is a fork waiting to happen (Rule 27(c)).
#
# A section whose ONLY difference is a `{token}` template site is NOT a consumer change:
# that is install.sh doing its job. Pulling it into the override would shadow core text
# the consumer never touched, and every future upstream edit to it would be discarded
# unseen. Same asymmetric test unregistered-drift.sh uses — the DIST side must carry the
# token, so a consumer cannot manufacture an exemption by typing "{foo}" into its copy.
#
# THREE ANSWERS, NOT TWO: `yes`, `no`, and `unknown` when the diff did not run -- the discipline
# unregistered-drift.sh's is_unregistered() took for the same shape. The caller reaches this only
# AFTER `[ "$a" = "$b" ]` has shown the sections differ, so the only legitimate `diff` exit is 1
# with at least one hunk. Anything else is a diff that FAILED (a fork refused under load, EAGAIN
# on the process substitution), and the awk below used to print `yes` for an empty stream. `yes`
# means "leave this section out of the override", and the section is then destroyed by the
# revert at the end. Measured with a `diff` shim that exits 2 only for one section: two edited
# sections, Alpha and Beta, the diff failing only for Beta -- rc 0, `skipped: Beta`, the override
# carried Alpha alone, core was reverted, and Beta's edit was gone with no line on stderr.
# The exit status is checked AND the awk refuses an empty stream, because either failure alone
# reaches `yes`. The captured variable loses only diff's trailing newline, which the here-string
# restores.
#
# ONE TOKEN DOES NOT EXEMPT A WHOLE HUNK. `diff` coalesces adjacent changed lines into one hunk,
# so a real edit on the line beside a token site shares the token's hunk. Exempting any hunk with
# a token on its core side lost that edit silently, rc 0, at every sha: `run {test_cmd} first.` /
# `then merge.` edited to `run pytest first.` / `then merge after REVIEW.` read as substitution
# only, and REVIEW was reverted away. A hunk is exempt only if some core-side line carries a
# token AND every token-FREE core-side line reappears verbatim on the consumer side -- so the
# hunk changed nothing but token lines. The same rule is in the conservation check's awk below;
# the two must agree, or the classifier skips a section the check then refuses.
substitution_only() { # <consumer-section-text> <dist-section-text>
  local d drc
  d="$(diff <(printf '%s\n' "$2") <(printf '%s\n' "$1") 2>/dev/null)"; drc=$?
  if [ "$drc" -ne 1 ] || [ -z "$d" ]; then printf 'unknown'; return 0; fi
  awk '
    function endh(   k) {
      if (!inh) return
      inh = 0
      if (!tok) { bad = 1; return }
      for (k = 1; k <= ntf; k++) if (!(TF[k] in GT)) { bad = 1; return }
    }
    /^[0-9]/ { endh(); inh = 1; nh++; tok = 0; ntf = 0; split("", GT); next }
    /^</     { if ($0 ~ /\{[a-z_][a-z0-9_]*\}/) tok = 1; else { ntf++; TF[ntf] = substr($0, 3) } }
    /^>/     { GT[substr($0, 3)] = 1 }
    END      { endh(); if (!nh) { print "unknown"; exit } print (bad ? "no" : "yes") }
  ' <<<"$d"
}

# A refusal names the section and exits 2 with core NOT reverted. It is the only safe answer
# here: every path below that proceeds on a guess ends in `git show > core`, which deletes
# whatever the guess left out. Writes go to temp files that are published only after every
# check has passed, and the EXIT trap removes them, so a refusal leaves the consumer as it was.
#
# TWO KINDS OF REFUSAL, and they need different advice. `refuse` is for a step that FAILED -- a
# diff, a temp file, a `git show`, a write -- where running again can succeed. `refuse_fixed` is
# for a verdict about the file itself: the same input refuses the same way every time, so telling
# the operator to re-run sends them round a loop. It says what to change instead.
refuse() { echo "register-drift: $1" >&2; echo "  ${CONS_FILE#$CONSUMER/} NOT reverted; the consumer's edit is still in place. Re-run; if it repeats, register by hand." >&2; exit 2; }
refuse_fixed() { printf 'register-drift: %s\n' "$1" >&2; echo "  ${CONS_FILE#$CONSUMER/} NOT reverted; the consumer's edit is still in place. This refusal is about the file's content: re-running without changing the file refuses the same way." >&2; exit 2; }

# grep exits 1 on a file with no headings (a real answer: the `no ## / ### section differs`
# exit handles it); anything above 1 is a grep that did not run, and an empty list would read as
# a file with nothing to classify.
hl="$(headings_of "$CONS_FILE")"; hrc=$?
[ "$hrc" -le 1 ] || refuse "cannot list the headings of $CONS_FILE (grep exit $hrc)"

changed=""
skipped=""
added=""
unaddressable=""
while IFS= read -r line; do
  h="${line#*:}"
  [ -n "$h" ] || continue
  # section_of returns non-zero when its temp file cannot be made, and `git show` fails the
  # pipeline under pipefail. Both used to leave an EMPTY string that reads as an answer: an
  # empty `b` files a core section as consumer-only (an extensions/ duplicate of a heading
  # core still defines), and an empty `a` compares unequal to everything. Measured with a
  # `mktemp` shim failing on the dist side of Beta alone: Beta went to extensions/ as an
  # addition while core's Beta rendered beside it.
  a="$(section_of "$h" < "$CONS_FILE")" || refuse "cannot read the consumer's section '${h}'"

  # A heading the resolver cannot ADDRESS: its name normalizes to nothing (`## 概要`, `## ***`),
  # so section_of matches no line even in the file the heading was read from. An override
  # anchors by that same resolver, so no override or extension can carry such a section. It is
  # left to the positional conservation check below: unchanged, it is byte-equal to core and
  # needs no carrying; changed, the check refuses it by position. Measured before this: the
  # empty `b` filed an unchanged `## 概要` as a consumer-only ADDITION -- the dry run previewed
  # an empty extension -- and --apply then refused it as "reads EMPTY" on every re-run.
  if [ -z "$a" ]; then
    unaddressable="${unaddressable}${unaddressable:+; }${h}"
    continue
  fi
  b="$(git -C "$DIST" show "${BASE}:${CORE}" | section_of "$h")" || refuse "cannot read core's section '${h}' at ${BASE}"

  # A section the CONSUMER has but CORE does not is an ADDITION, not an override.
  #
  # An override shadows an existing core heading; the resolver locates it by heading.
  # Anchor `shadows:` at a heading core never had and the anchor resolves to NOTHING —
  # layer-drift reports OVERRIDE-ANCHOR-UNRESOLVED and drift detection is DEAD for that
  # section, forever, silently. This project has had to repoint four overrides for
  # exactly that, and an earlier cut of THIS script wrote two more (tea.md's
  # `Context Loading` and `Communication`, which core does not define). Additive content
  # belongs in `extensions/`, which is file-hooked and needs no anchor.
  if [ -z "$b" ]; then
    added="${added}${added:+$'\n'}${h}"
    continue
  fi

  [ "$a" = "$b" ] && continue
  # Refused HERE, inside the loop, so a dry run refuses too: a dry run that prints an override
  # missing a section is the preview the operator approves before --apply.
  so="$(substitution_only "$a" "$b")"
  case "$so" in
    yes) skipped="${skipped}${skipped:+, }${h}"; continue ;;
    no)  ;;
    *)   refuse "cannot classify section '${h}': diff did not run" ;;
  esac
  changed="${changed}${changed:+$'\n'}${h}"
done <<<"$hl"

[ -n "$skipped" ] && echo "── skipped (template substitution only, not a consumer change): ${skipped}"
[ -n "$unaddressable" ] && echo "── headings no override can anchor to (the name normalizes to nothing; conserved only if unchanged): ${unaddressable}"
[ -n "$added" ] && echo "── consumer-ONLY sections (core has no such heading) -> extensions/, not overrides/: $(printf '%s' "$added" | tr '\n' ';')"

if [ -z "$changed" ]; then
  echo "register-drift: $REL differs from ${BASE}, but no ## / ### section differs."
  echo "  The delta is outside any heading (frontmatter, preamble, or a token site)."
  echo "  An override anchors to a heading, so this cannot be registered as one. Revert it,"
  echo "  or take it upstream."
  exit 1
fi

n_changed="$(printf '%s\n' "$changed" | grep -c .)"
slug="$(printf '%s' "$REL" | sed 's|/|__|g; s|\.md$||')"
first="$(printf '%s\n' "$changed" | head -1)"
OUT="$OVR_DIR/$(printf '%s' "$slug" | sed 's|skills__ai-dlc__||')__consumer-drift.md"

shadow_line="$SHADOW_TGT#$(printf '%s\n' "$changed" | paste -sd '@' - | sed "s|@|, ${SHADOW_TGT}#|g")"

body="$(printf '%s\n' "$changed" | while IFS= read -r h; do
          [ -n "$h" ] || continue
          section_of "$h" < "$CONS_FILE"; echo
        done)"

render() {
  cat <<EOF
---
shadows: ${shadow_line}
base_sha: ${BASE}
reason: TODO — one line: why this consumer changes the core rule. Registered by register-drift.sh; this text was carried as an UNREGISTERED in-place edit of core/${REL} (no override entry, no base_sha, invisible to layer-drift.sh, and destroyed by the next apply). Content is unchanged from what the consumer was already running; only its registration is new.
---

${body}
EOF
}

# Everything is STAGED in temp files first and checked before anything is published -- in a dry
# run too, so the preview and the apply cannot disagree about whether this file is registrable.
# Measured: with the override path unwritable (a directory in its place), an unchecked
# `render > "$OUT"` failed, the script carried on, printed REGISTERED, reverted core, and the
# edit existed nowhere under the consumer. Writing in place and refusing afterwards is not
# enough either: an override with an EMPTY body (a failed body extraction) is a live file that
# shadows core's section with nothing on the next render.
#
# Under --apply the temp files sit beside their targets, so the final `mv` is a rename; a dry run
# stages them outside the consumer. The EXIT trap removes whatever was not published. A target
# must be a regular file or absent: `mv` onto a DIRECTORY succeeds by moving the file inside it,
# which is the unwritable-path case above reporting success a second way.
OUT_TMP=""; EXT_TMP=""; rtmp=""
cleanup_tmps() { local t; for t in "$OUT_TMP" "$EXT_TMP" "$rtmp"; do [ -n "$t" ] && rm -f "$t"; done; return 0; }
trap cleanup_tmps EXIT
stage() { # <target> -> path of a fresh temp file to stage it in
  if [ "$APPLY" = "--apply" ]; then
    [ ! -e "$1" ] || [ -f "$1" ] || refuse_fixed "${1#$CONSUMER/} exists and is not a regular file"
    mktemp "${1}.tmp.XXXXXX"
  else
    mktemp
  fi
}
OUT_TMP="$(stage "$OUT")" || refuse "cannot stage the override ${OUT#$CONSUMER/}"
render > "$OUT_TMP" || refuse "cannot write the override ${OUT#$CONSUMER/}"

# Consumer-only sections go to extensions/ — additive, file-hooked, no anchor to break.
# Dropping them would DELETE consumer content when core is overwritten; putting them in
# `shadows:` would create an anchor that resolves to nothing.
if [ -n "$added" ]; then
  case "$REL" in
    team-roles/*) EXT_SUB="roles"; EXT_KIND="role" ;;
    *)            EXT_SUB="steps-domain"; EXT_KIND="step" ;;
  esac
  EXT_DIR="$CONSUMER/.claude/skills/ai-dlc/extensions/$EXT_SUB"
  if [ "$APPLY" = "--apply" ]; then mkdir -p "$EXT_DIR" || refuse "cannot create ${EXT_DIR#$CONSUMER/}"; fi
  ext_id="$(printf '%s' "$REL" | sed 's|.*/||; s|\.md$||')-consumer"
  EXT_OUT="$EXT_DIR/${ext_id}.md"
  EXT_TMP="$(stage "$EXT_OUT")" || refuse "cannot stage the extension ${EXT_OUT#$CONSUMER/}"
  {
    printf -- '---\nkind: %s\nhooks: %s\nid: %s\n' "$EXT_KIND" "$SHADOW_TGT" "$ext_id"
    printf 'reason: TODO — one line: why this consumer ADDS these sections. Written by register-drift.sh; core defines no heading for them, so they are additive and cannot be an override (an override anchors to a core heading; one that resolves to nothing is drift detection that is silently dead).\n---\n\n'
    printf '%s\n' "$added" | while IFS= read -r h; do
      [ -n "$h" ] || continue
      section_of "$h" < "$CONS_FILE"; echo
    done
  } > "$EXT_TMP" || refuse "cannot write the extension ${EXT_OUT#$CONSUMER/}"
fi

# Core at BASE, exactly as the revert will write it. Staged in a FILE, not a process
# substitution, because a `git show` that fails inside `<( )` hands `diff` an empty file and the
# failure is invisible. Under --apply this same file is what gets moved over the consumer's.
if [ "$APPLY" = "--apply" ]; then
  rtmp="$(mktemp "${CONS_FILE}.revert.XXXXXX")" || refuse "cannot create a temp file beside ${CONS_FILE#$CONSUMER/}"
  # `cp -p` first so the reverted file keeps the consumer file's mode.
  cp -p "$CONS_FILE" "$rtmp" || refuse "cannot stage the revert of ${CONS_FILE#$CONSUMER/}"
else
  rtmp="$(mktemp)" || refuse "cannot stage core's ${CORE} for the dry run's check"
fi
git -C "$DIST" show "${BASE}:${CORE}" > "$rtmp" || refuse "cannot read core's ${CORE} at ${BASE}"

# PRE-REVERT CONSERVATION CHECK, and it is POSITIONAL. The revert overwrites the consumer's file
# with core, so every line the consumer changed must already be carried by something written.
#
# It does NOT ask the classifier's question again by heading NAME. `section_of` resolves a
# heading by bidirectional substring match and returns the FIRST hit, so a check built on it is
# blind exactly where the classifier is. Measured, each with rc 0, REGISTERED, core reverted and
# the edit gone: an edited `## Review` below an unedited `## Review Process` (both resolve to the
# latter); a duplicate heading edited at its second occurrence; a preamble edit beside an edited
# section. It is real on a consumer: 9 of 564 headings across 8 installed files resolve to a
# different line, among them `## The evidence contract — ...` resolving to `## Contract`.
#
# So the hunks come from ONE `diff` of core at BASE against the whole consumer file, and each
# must be either:
#   - a template-substitution hunk: a core-side line carries a `{token}` and every token-free
#     core-side line reappears on the consumer side (install.sh's own edit, the same rule
#     substitution_only uses); or
#   - carried on both of its sides, as set out beside the check below.
# Anything else -- a section the resolver misfiled, a preamble edit, a deleted section -- is
# refused with core NOT reverted. The override system anchors by heading NAME through that same
# resolver, so these shapes cannot be expressed as an override at all; refusing is the answer,
# not a limitation of this check. The `diff` is checked like substitution_only's: exit 1 with a
# hunk, or refuse, because a diff that did not run is the defect this whole check backs up.
core_d="$(diff "$rtmp" "$CONS_FILE" 2>/dev/null)"; core_drc=$?
[ "$core_drc" -eq 1 ] && [ -n "$core_d" ] \
  || refuse "conservation: diff of core at ${BASE} against ${CONS_FILE#$CONSUMER/} did not run (exit ${core_drc})"
[ -s "$OUT_TMP" ] || refuse "conservation: the staged override is empty"
if [ -n "$added" ]; then
  [ -s "$EXT_TMP" ] || refuse "conservation: the staged extension is empty"
  nw=2
else
  nw=1
fi
# BOTH SIDES of every hunk are checked, because either can lose the edit:
#   - each consumer line the hunk adds must sit in a POSITIONAL section whose whole text (trailing
#     blank lines trimmed, since the override body is captured by `$( )`) appears verbatim in
#     what was written;
#   - each core line the hunk removes must sit in a core span the override SHADOWS -- resolved
#     from `shadows:` by the same resolver the renderer uses. A removed core line outside every
#     shadowed span renders back, so the consumer's change to it is undone. Measured on graph's
#     analyst.md shape: the consumer edits `## Contract` and `## The evidence contract — ...`;
#     both names resolve to `## Contract`, the consumer side of each is carried, and the
#     evidence-contract edit was still lost, because nothing shadows core's evidence section.
# Files are told apart by FNR resets, which an EMPTY file never produces -- hence the -s guards.
shadow_spans=""
while IFS= read -r h; do
  [ -n "$h" ] || continue
  s="$(span_of "$h" < "$rtmp")" || refuse "conservation: cannot resolve core's span for '${h}'"
  [ -n "$s" ] || refuse_fixed "conservation: the override shadows '${h}', which resolves to no heading in core at ${BASE}"
  shadow_spans="${shadow_spans}${shadow_spans:+,}${s% *}-${s#* }"
done <<<"$changed"
cons_check="$(awk -v nw="$nw" -v shadow="$shadow_spans" '
  function spans(   i, j, m, k, SR, rr) {
    sp = 1
    for (i = 1; i <= nc; i++) {
      LV[i] = 0
      if (match(C[i], /^#+/) && RLENGTH >= 2 && RLENGTH <= 6 && substr(C[i], RLENGTH + 1, 1) ~ /[ \t]/) LV[i] = RLENGTH
    }
    for (i = 1; i <= nc; i++) {
      if (LV[i] < 2 || LV[i] > 3 || substr(C[i], LV[i] + 1, 1) != " ") continue
      ST[i] = 1; E[i] = nc
      for (j = i + 1; j <= nc; j++) if (LV[j] && LV[j] <= LV[i]) { E[i] = j - 1; break }
    }
    m = split(shadow, SR, ",")
    for (k = 1; k <= m; k++) { if (SR[k] == "") continue; split(SR[k], rr, "-"); ns++; SS[ns] = rr[1] + 0; SE[ns] = rr[2] + 0 }
  }
  function carried(i,   k, t, te) {
    if (i in CA) return CA[i]
    te = E[i]; while (te > i && (C[te] == "" || C[te] == "\r")) te--
    t = C[i]; for (k = i + 1; k <= te; k++) t = t "\n" C[k]
    CA[i] = (index("\n" W, "\n" t "\n") > 0)
    return CA[i]
  }
  function covered(L,   i) {
    for (i = 1; i <= L; i++) if ((i in ST) && E[i] >= L && carried(i)) return 1
    return 0
  }
  function shadowed(k,   s) {
    for (s = 1; s <= ns; s++) if (k >= SS[s] && k <= SE[s]) return 1
    return 0
  }
  # A token hunk is exempt only when it changed nothing but token lines -- the rule
  # substitution_only states, and the reason is written there.
  function token_only(   k) {
    if (!tok) return 0
    for (k = 1; k <= ntf; k++) if (!(TF[k] in GT)) return 0
    return 1
  }
  function close_hunk(   L, k, t) {
    if (!inh) return
    inh = 0
    if (bad != "" || token_only()) return
    if (!sp) spans()
    for (k = 1; k <= nlost; k++) if (!shadowed(LOST[k])) {
      t = LOSTT[k]
      if (t ~ /^##+[ \t]/)
        bad = "the consumer DELETED core heading \"" t "\" (core line " LOST[k] "). An override can only replace a heading it names, and the revert would bring this one back, so the deletion cannot be registered as it stands.\n  Way through: keep the heading in the consumer file with a body that states the retirement (e.g. \"Retired locally: <why>.\"), then run register-drift again; the section is then a changed section and is carried by the override."
      else
        bad = "core line " LOST[k] " (" t ") was changed or removed by the consumer, and no section the override shadows contains it. It sits before any ## / ### heading, or under a heading whose name resolves to a different section, so no override can carry the change. Move the edit into a uniquely named ## / ### section, or take it upstream."
      return
    }
    if (op == "d") return
    # A BLANK added line is never charged. It carries no content, and the most common shape puts
    # one inside a span nothing carries: an edited section plus a new section appended at EOF,
    # where the separator blank lands in the last core section. Charging it refused that shape
    # on 61 of 63 core files, which end on a non-blank line.
    for (L = rs; L <= re; L++) {
      if (C[L] == "" || C[L] == "\r") continue
      if (!covered(L)) {
        bad = "consumer line " L " (" C[L] ") is carried by nothing that was written. It sits before any ## / ### heading, or under a heading whose name resolves to a different section, so no override can carry it. Move the edit into a uniquely named ## / ### section, or take it upstream."
        return
      }
    }
  }
  FNR == 1 { f++ }
  f == 1 { C[FNR] = $0; nc = FNR; next }
  f <= 1 + nw { W = W $0 "\n"; next }
  /^[0-9]/ {
    close_hunk()
    p = match($0, /[acd]/); op = substr($0, p, 1)
    n = split(substr($0, 1, p - 1), R, ","); ls = R[1] + 0
    n = split(substr($0, p + 1), R, ","); rs = R[1] + 0; re = (n > 1 ? R[2] : R[1]) + 0
    inh = 1; tok = 0; ntf = 0; split("", GT); nlost = 0; kl = ls; nh++
    next
  }
  /^</ {
    if ($0 ~ /\{[a-z_][a-z0-9_]*\}/) tok = 1; else { ntf++; TF[ntf] = substr($0, 3) }
    nlost++; LOST[nlost] = kl; LOSTT[nlost] = substr($0, 3, 60); kl++
  }
  /^>/ { GT[substr($0, 3)] = 1 }
  END {
    close_hunk()
    if (f != nw + 2 || !nh) { print "the whole-file diff was not read (files " f ", hunks " nh ")"; exit 3 }
    if (bad != "") { print bad; exit 1 }
    print "ok " nh
  }
' "$CONS_FILE" "$OUT_TMP" ${EXT_TMP:+"$EXT_TMP"} - <<<"$core_d")"; crc=$?
# Exit 1 is a VERDICT on the file and refuses without "re-run"; anything else is a check that did
# not complete, which running again can fix.
case "$crc" in
  0) [ "${cons_check%% *}" = ok ] || refuse "conservation: the check did not report (awk exit 0, output '${cons_check}')" ;;
  1) refuse_fixed "conservation: ${cons_check}" ;;
  *) refuse "conservation: ${cons_check:-the check did not run (awk exit ${crc})}" ;;
esac

if [ "$APPLY" != "--apply" ]; then
  echo "── would write: ${OUT#$CONSUMER/}"
  echo "── would revert: ${CONS_FILE#$CONSUMER/} to ${BASE}"
  echo "── ${n_changed} changed section(s): $(printf '%s' "$changed" | tr '\n' ';')"
  echo ""
  cat "$OUT_TMP"
  echo ""
  echo "register-drift: DRY RUN. Re-run with --apply to write it."
  exit 0
fi

# Publish, in the order that keeps the edit somewhere at every step: the override and the
# extension land first, core is reverted last. `mktemp` creates 0600; the published files get
# the mode a plain redirect would have given them.
fmode="$(printf '%o' $(( 0666 & ~$(umask) )))"
chmod "$fmode" "$OUT_TMP" ${EXT_TMP:+"$EXT_TMP"} || refuse "cannot set the mode of the files to publish"
mv -f "$OUT_TMP" "$OUT" || refuse "cannot move the override into place at ${OUT#$CONSUMER/}"
OUT_TMP=""
if [ -n "$added" ]; then
  mv -f "$EXT_TMP" "$EXT_OUT" \
    || refuse "cannot move the extension into place at ${EXT_OUT#$CONSUMER/}; the override ${OUT#$CONSUMER/} IS written and carries the changed sections"
  EXT_TMP=""
  echo "EXTENSION   ${EXT_OUT#$CONSUMER/}  ($(printf '%s' "$added" | tr '\n' ';'))"
fi
mv -f "$rtmp" "$CONS_FILE" \
  || refuse "the revert did not land; the override ${OUT#$CONSUMER/} IS written, so the edit is now in both places"
rtmp=""

echo "REGISTERED  ${OUT#$CONSUMER/}"
echo "  shadows      : ${shadow_line}"
echo "  base_sha     : ${BASE}  (where the delta forked from, NOT the sha being pulled)"
echo "  core reverted: ${CONS_FILE#$CONSUMER/} restored to ${BASE}"
echo ""
echo "  WRITE THE reason: LINE. It says TODO. An override whose reason nobody stated is"
echo "  one nobody can ever retire — the next pull cannot ask 'does upstream supersede this?'"
echo "  about a reason that was never given."
