#!/usr/bin/env bash
# reconcile-region: exempt — a remediation workflow that carries the operator through a block layer-drift.sh already reported in the region.
# readopt-override.sh — carry the operator through a HARD-OVERRIDE-DRIFT-SECTION.
#
# `layer-drift.sh` says the shadowed core section changed, so the override is now
# shadowing a rule that no longer exists upstream. Blocking there is necessary and
# not sufficient: stopping is not landing. This is the workflow that ends the block.
#
# THE TRAP THIS SCRIPT EXISTS TO CLOSE. Drift is computed as
# `core@base_sha[section] != core@theirs[section]`, so re-stamping `base_sha :=
# theirs` makes the two sides equal and the HARD status evaporates — WITHOUT the
# operator having merged one word of the new core text into the override body. The
# lead reads the OVERRIDE, not core. A bare re-stamp is "proceed by doing nothing"
# wearing a stamp, and it is precisely how a core fix lands on disk while the
# pipeline goes on running the rule it replaced.
#
# So the change is read in BOTH directions, and the two are TIERED DIFFERENTLY:
#
#   SUPERSEDED — a line core carried at `base_sha` whose words `theirs` no longer
#                carries, still sitting in the body. The override is teaching the
#                old rule. REFUSES `--stamp readopt`.
#   UNADOPTED  — a line core carries at `theirs` whose words `base_sha` did not,
#                which the body does not carry. The override never took the fix up.
#                REPORTS. It does not refuse, and v0.477.0 demoted it after v0.476.0
#                shipped it as a refusal.
#
# WHY THE SECOND ONE IS A REPORT, MEASURED ON 27 REAL ADJUDICATIONS. Replaying every
# commit in the reference consumer's history where an override's `base_sha` moved — the
# body scored as it stood when the stamp was taken — a refusing UNADOPTED arm refuses 7
# of the 27 re-adoptions that actually happened. At least one is a demonstrated FALSE
# refusal: 20 lines reported while the body already carried both identifiers that
# upstream addition introduces, reworded. **A body is a REWRITE by definition**, so the
# mirror predicate inherits the very defect the filing describes, with the sign flipped:
# line-literal on a rewritten body gives a false CLEAN one way and a false REFUSAL the
# other.
#
# AND THE ESCAPE MAKES A FALSE REFUSAL WORSE, NOT SAFER. `--stamp reaffirm --note`
# advances `base_sha`, so a falsely-refused re-adoption routed there is re-stamped: the
# upstream clause is never offered again, permanently, under a recorded note asserting
# this consumer deliberately declined text it had in fact already adopted. That is the
# failure this whole file exists to prevent, reached THROUGH the new arm instead of
# around it. `mechanism-design.md` — tier a finding as ERROR only where no
# false-positive path exists.
#
# ONE DIRECTION IS NOT THE GATE, AND SHIPPING ONLY THE FIRST MADE THE COMMONEST
# CHANGE INVISIBLE. A purely ADDITIVE upstream edit removes nothing, so the
# superseded set is empty BY CONSTRUCTION and the gate printed OK on a body
# carrying none of the new clause — then `--stamp readopt` advanced `base_sha`,
# which makes the next pull compute no drift at all, so the un-adopted upstream
# text is never offered again. Silent, permanent, and clean-looking.
# Measured on the reference consumer's own `steps__retro__domain-sections.md`
# across its `a5cbdf0b -> 95670e58` re-adoption: `--check` exit 0, and 5 lines of
# core's rewritten `#4a. Close-Out Sweep` absent from the body. Its other three
# anchors, whose sections did not move, score 0 in the same run.
#
# The containment test is WRAP-INSENSITIVE for the same reason `layer-drift.sh`'s
# `asserts_shadow_survives` flattens a body before matching: layer bodies are
# hard-wrapped, so a whole-line comparison returns a false zero the moment a
# consumer re-flows a paragraph it did adopt — or keeps a superseded sentence at a
# different column. Both sides are compared against the flattened body.
#
# WHAT NEITHER DIRECTION REACHES, stated so it is not mistaken for coverage: a body
# that REWORDS core's text rather than re-wrapping it. Same consumer, same pull:
# core's deleted `… Then **archive terminal entries` survives in that body with
# "relocate" where core says "archive", and no containment test over core's own
# words can see it. That case is caught here only because the UNADOPTED direction
# fires on the same entry; a reword inside an otherwise-adopted section is not
# mechanically detectable and is what `--stamp reaffirm --note` is for.
#
# Both tests are mechanical (containment of one side's lines in the other side's
# flattened section — `changed_lines` below says why not a whole-line set
# difference), both fail RED on a real
# defect today, and both can only be cleared by editing the body, by running
# `--merge`, or by an explicit, recorded re-affirm.
#
# Usage:
#   readopt-override.sh <dist> <theirs> <consumer> <override>            # dossier (default)
#   readopt-override.sh <dist> <theirs> <consumer> <override> --check    # gate only; exit 1 if stale
#   readopt-override.sh <dist> <theirs> <consumer> <override> --merge    # three-way re-adoption merge
#   readopt-override.sh <dist> <theirs> <consumer> <override> --stamp <outcome> [--note "..."]
#     <outcome> = readopt   body re-adopted; --check must pass; re-stamps base_sha
#                 reaffirm  old core text deliberately kept; REQUIRES --note; re-stamps
#                 retire    upstream absorbed it; deletes the override file
#
# Exit: 0 ok / 1 blocked (stale core text still in the body) / 2 usage, or a scan that did
#       not run to completion (a refusal; its reason is on stderr).
set -uo pipefail

DIST="${1:?usage: readopt-override.sh <dist> <theirs> <consumer> <override> [--check|--merge|--stamp <outcome>]}"
THEIRS="${2:?}"
CONSUMER="${3:?}"
OVR="${4:?}"
MODE="${5:-}"
OUTCOME="${6:-}"

[ -f "$OVR" ] || { echo "readopt-override: no such override: $OVR" >&2; exit 2; }

NOTE=""
prev=""
for arg in "$@"; do
  [ "$prev" = "--note" ] && NOTE="$arg"
  prev="$arg"
done

fm() { sed -n '/^---$/,/^---$/p' "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -1; }

# fm_block — the same read for a field that may be a YAML BLOCK SCALAR (`|` / `>`).
#
# `fm()` is `… | head -1`, which on `reason: |` captures the indicator character and nothing
# else, so the dossier's "WHY THIS OVERRIDE EXISTS" panel rendered a bare `|`. Eight of the
# reference consumer's overrides declare `reason:` as a block; every one printed empty. SKILL.md
# step 7's retire / readopt / reaffirm decision turns on exactly that field, so the operator was
# adjudicating a re-adoption against a blank rationale.
#
# The `--note` WRITER in this same file has tracked block scalars since the corruption it
# documents at its `inreason` loop; only the reader never got the treatment. The block-END rule
# here is that writer's rule — an unindented `key:` closes it — so reader and writer cannot
# disagree about where a reason stops.
#
# fm() keeps its single-line semantics for `shadows` and `base_sha`: widening the shared reader
# would change how two fields parse to fix a third.
#
# A MULTI-LINE PLAIN SCALAR IS THE SAME DEFECT ONE YAML SHAPE OVER, AND IT FAILS IN THE WORSE
# DIRECTION. The block-scalar fix above cured `reason: |`; `reason: <text>` continued over the
# lines beneath it took the `print v; exit` arm and rendered its FIRST LINE ONLY. A bare `|`
# rendered EMPTY, which the operator reads as a missing field and goes to the file for; one
# surviving line that ends in a complete sentence reads as the WHOLE reason, and step 7's
# retire / readopt / reaffirm decision is then taken against a fragment that looks whole.
# Measured on the reference consumer's overrides, with the shipping reader lifted verbatim: a
# 3-line plain scalar rendered 1 line where a 3-line block scalar rendered 3.
#
# SO THE PLAIN ARM ENTERS THE SAME CONTINUATION STATE rather than growing its own: `inb` already
# carries the block-END rule — an unindented `key:` closes it, which is the `--note` WRITER's own
# rule — and a plain scalar ends at exactly the same place. Reusing it is what keeps reader and
# writer unable to disagree about where a reason stops, and it is why this is one line and not a
# second state machine. The first line is printed BEFORE entering it, because for a plain scalar
# that line is content; for a block scalar the indicator is not.
fm_block() { # fm_block <file> <key>
  awk -v k="$2" '
    NR==1 && /^---$/                       { fm=1; next }
    fm && /^---$/                          { exit }
    fm && !inb && index($0, k ":") == 1 {
      v = substr($0, length(k) + 2); sub(/^[ \t]+/, "", v)
      if (v ~ /^[|>][0-9]*[-+]?$/) { inb = 1; next }
      print v; inb = 1; next
    }
    fm && inb && /^[A-Za-z_][A-Za-z0-9_]*:/ { exit }
    fm && inb                              { sub(/^[ \t]+/, "", $0); print }
  ' "$1"
}

SHADOWS="$(fm "$OVR" shadows)"
BASE_SHA="$(fm "$OVR" base_sha)"
TARGET="$(printf '%s' "${SHADOWS%%#*}" | tr -d ' ' | sed 's/,.*//')"

# Same mapping layer-drift.sh uses. Getting this wrong does not error — it makes
# `git show` return nothing, both sides of the set difference come back empty, and
# the gate reports OK on a live defect. A check that cannot fire, reading as a
# check that passed.
case "$TARGET" in
  team-roles/*) CORE="core/${TARGET}" ;;
  *)            CORE="core/skills/ai-dlc/${TARGET}" ;;
esac

[ -n "$BASE_SHA" ] || { echo "readopt-override: override has no base_sha:" >&2; exit 2; }

# section_of()/norm() — the ONE resolver, from lib.sh.
#
# A WEAKER resolver here is not a cosmetic divergence: layer-drift decides the
# section DRIFTED and blocks, this script then fails to resolve the same anchor,
# finds no stale lines, and clears the block. Two resolvers means the gate and its
# remedy can disagree, and the remedy always wins. That shipped, in v0.52.0.
# (Caught live: the anchor "Empirical gate validation (the `Enforcement:`
# paragraph)" is a descriptive label whose heading is just "## Empirical gate
# validation" — the bidirectional-substring match resolves it; an exact/prefix
# match does not.)
SELF="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$SELF/lib.sh" || { echo "readopt-override: cannot source $SELF/lib.sh" >&2; exit 1; }

# EVERY LOOP FEED BELOW IS STAGED TO A FILE AND ITS PRODUCER'S STATUS IS READ. They used to read
# `done < <(producer)`, which discards the status: a section read that failed part-way (a failed
# `sort` or `section_of`) returned an empty base set, so `stale_lines` found nothing and `--check`
# printed OK and exited 0 over a body still teaching the superseded rule -- the false clear this
# gate exists to withhold. A producer that did not run is now a refusal, exit 2, never OK (0)
# and never STALE (1).
#
# THE FUNCTIONS RUN INSIDE `$( )`, where an `exit` ends only the subshell, so each returns 3 on a
# staging failure and every caller reads that status and refuses in the main shell.
#
# A `git show` THAT RAN AND FOUND NO SUCH PATH IS NOT ONE OF THESE, deliberately: git exits 128
# for a path absent at the ref, that reads as an empty section exactly as it did, and
# `anchors_resolve` turns it into UNDECIDABLE, which already withholds the stamp. Refusing it
# would move that verdict from 1 to 2. EVERY OTHER STATUS IS: a `git` that could not be run or
# was killed (126, 127, a signal) staged an empty section too, and `--check` then read OK over a
# body it never compared -- so 0 passes, 128 stages empty, and anything else returns 3.
#
# One directory per run, one file per site, cleaned through lib.sh's composing `trap`.
RO_T="$(mktemp -d "${TMPDIR:-/tmp}/readopt-override.XXXXXX")" || {
  echo "readopt-override: could not create a staging directory; no verdict" >&2; exit 2; }
trap 'rm -rf "$RO_T"' EXIT
ro_refuse() { # ro_refuse <what did not run>
  echo "readopt-override: $1 did not run to completion, so this run has no verdict; re-run once the fault is gone" >&2
  exit 2
}
# ro_section <sha> <anchor> <site> -- the shadowed section at <sha>, staged to "$RO_T/<site>.sec".
# The ref read's status is split (see above): 0 passes, 128 (no such path at the ref) stages an
# empty section as it always read, anything else returns 3. section_of's failure returns 3.
ro_section() {
  local rc=0
  git -C "$DIST" show "${1}:${CORE}" 2>/dev/null > "$RO_T/$3.raw" || rc=$?
  case "$rc" in
    0) ;;
    128) : > "$RO_T/$3.raw" ;;
    *) return 3 ;;
  esac
  section_of "$2" < "$RO_T/$3.raw" > "$RO_T/$3.sec" || return 3
}
# NO HERE-STRING IN THIS FILE'S SCANS. bash 3.2 stages every `<<<` to a temp file, and when that
# write fails -- `ulimit -f`, a full TMPDIR -- it prints `cannot create temp file for here
# document` and the command reads EMPTY stdin: a `grep -qxF` answered "absent", and a
# `done <<<` loop ran zero times, which read as a body with no stale line -- `--check` OK, rc 0.
# A whole-line membership test is `ro_has_line`, a `case` with no file and no fork, so it cannot
# fail; a loop reads a file staged by `shadow_ids`, whose status is read and returns 3.
NL='
'
# ro_lines <text> -- split <text> on newlines into RO_L, in the main shell, with no file and no fork.
# The `--merge` span plan and the dossier's drift panel iterate RO_L. They read `done <<EOF`
# heredocs, which bash 3.2 stages to a temp file: when that write failed the loop ran ZERO times.
# Globbing is off for the split, so an anchor carrying `*` is an anchor, not a pattern. Empty lines
# are dropped, which both loops already skipped. Read it as `${RO_L[@]+"${RO_L[@]}"}`, the bash 3.2
# spelling that does not trip `set -u` on an empty list.
ro_lines() {
  local _ifs="$IFS"
  set -f; IFS="$NL"
  RO_L=($1)
  IFS="$_ifs"; set +f
}
ro_has_line() { # ro_has_line <haystack> <needle> -> 0 when <needle> is a WHOLE line of <haystack>
  case "$NL$1$NL" in *"$NL$2$NL"*) return 0 ;; esac
  return 1
}
# shadow_ids <site> -- the anchor ids named in `shadows:`, one per line, staged to "$RO_T/<site>".
shadow_ids() {
  printf '%s\n' "$SHADOWS" | tr ',' '\n' | sed -n 's/.*#//p' | sed 's/^ *//; s/ *$//' > "$RO_T/$1" || return 3
}

# Does every anchor in `shadows:` resolve in BOTH base and theirs?
#
# If an anchor resolves nowhere, `stale_lines` compares two empty sets, finds
# nothing, and reports the body clean — a check that CANNOT FAIL, gating the very
# re-stamp it exists to withhold. So an unresolvable anchor is not "clean", it is
# UNDECIDABLE, and `--stamp readopt` is refused on it. The operator can still get
# past with `--stamp reaffirm --note`, which puts a human's name on the decision.
anchors_resolve() {
  local id ok=yes
  shadow_ids resolve-ids || return 3
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    if [ -z "$(git -C "$DIST" show "${THEIRS}:${CORE}" 2>/dev/null | section_of "$id")" ] \
    || [ -z "$(git -C "$DIST" show "${BASE_SHA}:${CORE}" 2>/dev/null | section_of "$id")" ]; then
      ok=no
      printf 'UNRESOLVED-ANCHOR  #%s does not resolve to a heading in %s at %s/%s\n' \
        "$id" "$CORE" "$BASE_SHA" "$THEIRS_SHA" >&2
    fi
  done < "$RO_T/resolve-ids"
  printf '%s' "$ok"
}

THEIRS_SHA="$(git -C "$DIST" rev-parse --short "$THEIRS")"

# ---------------------------------------------------------------------------
# The gate: superseded core lines still sitting in the override body.
#
# A line qualifies iff it is (a) substantive, (b) present in core@base_sha's
# shadowed section, (c) ABSENT from core@theirs' section, and (d) still present
# in the override body. That is a line the override copied from a core rule that
# upstream has since rewritten — the split-brain, stated as a set.
#
# Trivial lines (blank, punctuation, fence markers, short fragments) are excluded:
# they collide by coincidence, not by copying, and a gate that trips on "```" is a
# gate someone comments out.
#
# THE FLOOR APPLIES TO THE UNADOPTED DIRECTION TOO, AND THAT IS A STATED LIMIT rather
# than an oversight. An upstream change made ENTIRELY of lines at or under 24 characters
# is invisible to both directions: measured, an added `STOP on any red.` scores 0 while
# one long clause in the same section scores 1 in the same run. Lowering the floor to
# reach it buys back the coincidental collisions it exists to exclude, on a corpus where
# short lines are mostly markup — so the floor stays and the blind spot is written down.
# ---------------------------------------------------------------------------

# The body as ONE line, internal whitespace squeezed. Every containment test below
# runs against this, so a paragraph the consumer re-flowed still reads as carried.
# What this replaces was a whole-line fixed-string match against the raw file. That
# spelling is NOT reproduced here, for the reason the `--merge` comment below gives:
# the consumer's ledger receipt for this defect is a substring test over this file, so
# a comment quoting the deleted flags keeps their receipt matching forever and the
# candidate never closes. It answered NO on a sentence the body demonstrably contains,
# wrapped at a different column — a false clean on the superseded side, and a false
# refusal on the other.
#
# THE FRONTMATTER IS NOT THE BODY, and reading the whole file was a hole this gate could
# not afford. `reason:` is prose ABOUT the override, and the natural way to decline an
# upstream clause is to quote it there — "upstream now says X; we decline it" — which,
# read as body text, scores X as adopted and clears the block on the entry that says in
# as many words that it did not adopt it. Measured on a constructed entry: whole-file
# reading exits 0, against a control of 1 for the same entry with the clause nowhere.
# Only the LEAD reads the body, so only the body can carry the adoption. Extraction is
# `--merge`'s, verbatim, so the two cannot disagree about where a body starts.
#
# AN HTML COMMENT IS NOT THE BODY EITHER, for the same reason and by the same measurement.
# The frontmatter fix closed one paste target and left the other: the same upstream lines
# dropped into `<!-- … -->` INSIDE the body scored as adoption, against a near-miss control
# of unrelated text in the same place that did not. `--check` prints the offending lines
# verbatim, so the tool emits the exact text that silences it. Comment spans are removed
# before flattening, in both directions — a line no lead reads is neither an adoption nor a
# rule anybody is still obeying.
BODY_FLAT="$(awk 'BEGIN{fm=0; started=0}
                  NR==1 && /^---$/ {fm=1; next}
                  fm && /^---$/    {fm=0; started=1; next}
                  fm               {next}
                  started          {print}' "$OVR" \
             | awk 'BEGIN{inc=0}
                    {
                      line=$0
                      while (1) {
                        if (inc) { i=index(line,"-->"); if (i==0) { line=""; break }
                                   line=substr(line,i+3); inc=0; continue }
                        i=index(line,"<!--"); if (i==0) break
                        rest=substr(line,i+4); j=index(rest,"-->")
                        if (j==0) { line=substr(line,1,i-1); inc=1; break }
                        line=substr(line,1,i-1) " " substr(rest,j+3)
                      }
                      print line
                    }' \
             | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | tr '\n' ' ' | tr -s ' ')"

# carries <haystack> <needle> — is this core line's word sequence in the haystack at all?
# The needle is squeezed the same way every haystack is, or a core line carrying a
# double space matches nothing and reports as absent.
carries() {
  local needle
  needle="$(printf '%s' "$2" | tr -s ' ')"
  case "$1" in *"$needle"*) return 0 ;; esac
  return 1
}
body_carries() { carries "$BODY_FLAT" "$1"; }

# section_lines <sha> <anchor> — the substantive lines of one shadowed section.
# ONE spelling for both directions: two copies of this filter is two chances for
# the sets being differenced to be built by different rules.
# <site> names the staging files. Returns 3 when a stage failed; grep's 1 -- every line under
# the floor -- is a healthy empty set.
section_lines() { # section_lines <sha> <anchor> <site>
  local ps
  ro_section "$1" "$2" "$3" || return 3
  sed 's/^[[:space:]]*//; s/[[:space:]]*$//' "$RO_T/$3.sec" | grep -vE '^.{0,24}$' | sort -u
  ps="${PIPESTATUS[*]}"
  case "$ps" in '0 0 0'|'0 1 0') return 0 ;; esac
  return 3
}

# section_flat <sha> <anchor> — the same section as ONE squeezed line, the shape
# BODY_FLAT has, so a core line is tested against a SECTION exactly as it is tested
# against the body.
section_flat() {
  git -C "$DIST" show "${1}:${CORE}" 2>/dev/null | section_of "$2" \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | tr '\n' ' ' | tr -s ' '
}

# section_ordered <sha> <anchor> — the section's non-blank lines in FILE ORDER, trimmed
# and squeezed, no floor and no sort. `carried_in_context` needs adjacency, which
# `section_lines` discards.
section_ordered() { # section_ordered <sha> <anchor> <site>; returns 3 when a stage failed
  local ps
  ro_section "$1" "$2" "$3" || return 3
  sed 's/^[[:space:]]*//; s/[[:space:]]*$//' "$RO_T/$3.sec" | grep -v '^$' | tr -s ' '
  ps="${PIPESTATUS[*]}"
  case "$ps" in '0 0 0'|'0 1 0') return 0 ;; esac
  return 3
}

# carried_in_context <to-sha> <anchor> <line> — does the BODY carry the run of consecutive
# TO lines that holds <line>'s words? Every start position is tried and the window grows
# until it contains the needle, so the shortest carrier at each start is tested; a body
# carrying any of them carries the needle IN THE CONTEXT TO GIVES IT.
# Returns 0 carried, 1 not carried. A section that could not be staged also returns 1 -- so the
# caller's one-line `&& continue` keeps its shape -- and drops the "$RO_T/refused" marker, which
# changed_lines reads after its loop and turns into status 3.
carried_in_context() {
  local needle i j n win l
  needle="$(printf '%s' "$3" | tr -s ' ')"
  local -a L
  i=0
  section_ordered "$1" "$2" cic-sec > "$RO_T/cic-ordered" || { : > "$RO_T/refused"; return 1; }
  while IFS= read -r l; do L[$i]="$l"; i=$((i+1)); done < "$RO_T/cic-ordered"
  n=$i
  i=0
  while [ "$i" -lt "$n" ]; do
    win="${L[$i]}"; j=$i
    while :; do
      case "$win" in *"$needle"*)
        body_carries "$win" && return 0
        break ;;
      esac
      j=$((j+1)); [ "$j" -lt "$n" ] || break
      win="$win ${L[$j]}"
    done
    i=$((i+1))
  done
  return 1
}

# changed_lines <from-sha> <to-sha> <anchor> — the substantive lines of the section at
# FROM that the section at TO no longer carries as a whole line, EXCEPT those whose words
# survive at TO inside a longer run of text that the body ALSO carries.
#
# A WHOLE-LINE SET DIFFERENCE IS A FALSE REFUSAL, AND BARE CONTAINMENT IS A FALSE PASS.
# Upstream re-flows paragraphs. When it does, a base line survives at theirs as the
# SUFFIX (or prefix, or middle) of a longer line, so a whole-line difference scores it
# as deleted while a body that adopted theirs faithfully still contains it — and the
# refusal below fires on exactly the state it exists to certify. Measured on the
# reference consumer's `steps__gate-validation__check-20.md` across `eb49b783 ->
# a798e215`: `--merge` reported 1 merged / 0 conflicted, a containment join found all 38
# substantive theirs lines in the body, and `--stamp readopt` refused on one line that
# theirs carried at the end of a longer sentence. The only stamp then available was
# `reaffirm`, which recorded a re-adoption under the wrong outcome name.
#
# But a base line's words also survive at theirs when upstream QUALIFIED or NEGATED the
# line in place — `Never` prepended, a clause appended, a table row extended — and there
# the body carrying only the base line is teaching the OLD rule. Measured over the last
# 60 non-merge commits touching the shipped rule text: of 209 deleted substantive lines,
# 46 survive by containment, 24 across a line join and 22 inside one line, and the
# consumer's own motivating line is in the second group. Requiring the containment to
# cross a line join would therefore refuse the case that motivated the change. What
# separates the two is the BODY: a faithful adoption carries the theirs text that now
# holds the base line's words, and a body teaching the old rule does not. So a contained
# line is acquitted only when `carried_in_context` finds the body carrying its carrier.
# Whole-line presence at TO is checked first, so an UNCHANGED line the body omits is never
# reported as new in the mirror direction. The 24-character floor on the needle side
# excludes coincidental short matches as before.
# Returns 3 when any section it reads could not be staged. <site> keeps the two directions'
# files apart.
changed_lines() { # changed_lines <from-sha> <to-sha> <anchor> <site>
  local to_lines to_flat line
  to_lines="$(section_lines "$2" "$3" "$4-to")" || return 3
  to_flat="$(section_flat "$2" "$3")"
  section_lines "$1" "$3" "$4-from" > "$RO_T/$4-from-lines" || return 3
  rm -f "$RO_T/refused"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    ro_has_line "$to_lines" "$line" && continue
    carries "$to_flat" "$line" && carried_in_context "$2" "$3" "$line" && continue
    printf '%s\n' "$line"
  done < "$RO_T/$4-from-lines"
  [ ! -e "$RO_T/refused" ] || return 3
}

stale_lines() {
  local id line
  shadow_ids stale-ids || return 3
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    changed_lines "$BASE_SHA" "$THEIRS" "$id" stale > "$RO_T/stale-changed" || return 3
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      body_carries "$line" && printf '%s\n' "$line"
    done < "$RO_T/stale-changed"
  done < "$RO_T/stale-ids"
}

# The mirror. The two refs swapped, and the body test NEGATED: core gained this line
# and the override does not have it.
unadopted_lines() {
  local id line
  shadow_ids unadopted-ids || return 3
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    changed_lines "$THEIRS" "$BASE_SHA" "$id" unadopted > "$RO_T/unadopted-changed" || return 3
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      body_carries "$line" || printf '%s\n' "$line"
    done < "$RO_T/unadopted-changed"
  done < "$RO_T/unadopted-ids"
}

# ONLY STATUS 3 IS A REFUSAL. Each scan's loop ends on a `body_carries … && printf`, so a clean
# body returns 1 from the function -- which is not a failure and must not be read as one.
_ro_rc=0; STALE="$(stale_lines)" || _ro_rc=$?
[ "$_ro_rc" -ne 3 ] || ro_refuse "the superseded-line scan (core@${BASE_SHA} against core@${THEIRS})"
N_STALE=0
[ -n "$STALE" ] && N_STALE="$(printf '%s\n' "$STALE" | grep -c .)"
_ro_rc=0; UNADOPTED="$(unadopted_lines)" || _ro_rc=$?
[ "$_ro_rc" -ne 3 ] || ro_refuse "the unadopted-line scan (core@${THEIRS} against core@${BASE_SHA})"
N_UNADOPTED=0
[ -n "$UNADOPTED" ] && N_UNADOPTED="$(printf '%s\n' "$UNADOPTED" | grep -c .)"
_ro_rc=0; RESOLVE="$(anchors_resolve 2>/dev/null)" || _ro_rc=$?
[ "$_ro_rc" -ne 3 ] || ro_refuse "the anchor-resolution check"

# ---------------------------------------------------------------------------
case "$MODE" in
  --check)
    if [ "$RESOLVE" != yes ]; then
      echo "UNDECIDABLE  $(basename "$OVR"): a shadowed anchor does not resolve to a heading in core."
      anchors_resolve >/dev/null
      echo "  The stale-text test compares two empty sections and would pass on ANY body."
      echo "  Repoint \`shadows:\` at a real heading, or --stamp reaffirm --note \"<why>\"."
      exit 1
    fi
    if [ "$N_STALE" -gt 0 ]; then
      echo "STALE-CORE-TEXT  $(basename "$OVR"): ${N_STALE} line(s) copied from core@${BASE_SHA} that core@${THEIRS_SHA} NO LONGER CONTAINS."
      printf '%s\n' "$STALE" | sed 's/^/    | /'
      echo "  The lead obeys this override, not core. Re-adopt the new core text into the body,"
      echo "  or --stamp reaffirm --note \"<why the old clause still stands>\"."
      exit 1
    fi
    if [ "$N_UNADOPTED" -gt 0 ]; then
      echo "UNADOPTED-CORE-TEXT (report)  $(basename "$OVR"): ${N_UNADOPTED} line(s) core@${THEIRS_SHA} ADDS to the shadowed section that the body does not carry."
      printf '%s\n' "$UNADOPTED" | sed 's/^/    | /'
      echo "  Nothing is stale, so the one-directional test is silent — and the lead never sees"
      echo "  this text, because the override replaces the section it was added to. Run --merge,"
      echo "  or decide deliberately that this consumer does not want it."
      echo "  REPORT, NOT A REFUSAL: a body that adopted upstream by REWORDING scores here too,"
      echo "  and refusing on that routes a correct re-adoption to reaffirm, which re-stamps."
    fi
    echo "OK  $(basename "$OVR"): body carries no superseded core text."
    exit 0
    ;;

  --merge)
    # Re-adoption is a THREE-WAY MERGE, not a hand edit.
    #
    #   base   = the core section at the override's base_sha  (what it forked from)
    #   ours   = the override body                            (base + the consumer delta)
    #   theirs = the core section at theirs                   (base + the upstream change)
    #
    # git merge-file applies the upstream change to the consumer's copy and keeps the
    # delta. Telling the operator to "merge the new core text in, preserving your
    # delta" by hand is asking them to run this algorithm in their head, on prose, and
    # a hand-merge is where a consumer silently drops half an upstream clause.
    #
    # A real conflict leaves standard <<<<<<< markers and exits 1 — the ONE spot that
    # genuinely needs a human. Everything else lands clean.
    # PER ANCHOR, not per file. A multi-anchor override used to be refused outright and
    # sent back for a hand-merge, which is the one procedure this mode exists to remove
    # and step 7 warns about. It is also more work than the drift justifies: an override
    # shadowing four sections typically has ONE that moved.
    #
    # The removed message is deliberately NOT quoted here. A consumer's ledger receipt is
    # a substring test against this file, so a comment that repeats a string the fix
    # deleted keeps the receipt matching forever and the entry never closes. Measured:
    # PC-S298-READOPT-MERGE-REFUSES-MULTI-ANCHOR-OVERRIDES reported STILL-LIVE against
    # 0.142.0 on this comment alone. Describe a deleted string; do not reproduce it.
    # Each anchor is merged in its own span; anchors whose core section is byte-identical
    # between base and theirs are left ALONE, so the diff stays scoped to what drifted.
    if [ "$RESOLVE" != yes ]; then
      echo "REFUSED  $(basename "$OVR"): a shadowed anchor resolves to no heading; cannot merge what cannot be located." >&2
      anchors_resolve >/dev/null
      exit 1
    fi

    ids="$(printf '%s\n' "$SHADOWS" | tr ',' '\n' | sed -n 's/.*#//p' | sed 's/^ *//; s/ *$//' | grep -v '^$')"

    # EVERY WRITE BELOW HAS ITS STATUS READ, AND THE OVERRIDE IS REPLACED BY A RENAME. This block
    # used to read no write status and end in a redirect straight onto the override, which truncates
    # it before writing it: under a write limit or a full disk the override was left cut short,
    # or the merge was assembled from a body file that had silently lost its tail and the operator's
    # sections were gone from the result, and the run still printed its merged/unchanged count. Every
    # temp file lives in RO_T, which the EXIT trap removes; the result is staged beside the override
    # so the final `mv` is a rename and the override is never half-written.
    ro_merge_refuse() { # ro_merge_refuse <what failed>
      echo "readopt-override: --merge could not $1, so nothing was written; $(basename "$OVR") is unchanged. Re-run once the fault is gone." >&2
      [ -n "${staged:-}" ] && rm -f "$staged"
      exit 2
    }
    fmf="$RO_T/merge-fm"; body="$RO_T/merge-body"; plan="$RO_T/merge-plan"; out="$RO_T/merge-out"; staged=""
    awk 'NR==1 && /^---$/ {infm=1; print; next}
         infm && /^---$/ {print; infm=0; done=1; next}
         infm {print}' "$OVR" > "$fmf" || ro_merge_refuse "stage the override's frontmatter"
    awk 'BEGIN{fm=0; started=0}
         NR==1 && /^---$/ {fm=1; next}
         fm && /^---$/ {fm=0; started=1; next}
         fm {next}
         started {print}' "$OVR" > "$body" || ro_merge_refuse "stage the override's body"

    # Locate each anchor's span IN THE BODY, then walk the body in line order.
    : > "$plan" || ro_merge_refuse "create the span plan"
    ro_lines "$ids"
    for id in ${RO_L[@]+"${RO_L[@]}"}; do
      [ -n "$id" ] || continue
      sp="$(span_of "$id" < "$body")" || ro_merge_refuse "locate #${id} in the body"
      if [ -n "$sp" ]; then printf '%s %s\n' "$sp" "$id" >> "$plan" || ro_merge_refuse "record #${id} in the span plan"; fi
    done

    # A body that restates no shadowed heading is the single-anchor shape: the whole body
    # IS the section. Treat it as one span so that case merges exactly as it always has.
    if [ ! -s "$plan" ]; then
      if [ "$(printf '%s\n' "$ids" | grep -c .)" -ne 1 ]; then
        echo "REFUSED  $(basename "$OVR"): shadows $(printf '%s\n' "$ids" | grep -c .) anchors and the body restates none of their headings, so no span can be located." >&2
        echo "  anchors: $(printf '%s' "$ids" | tr '\n' ' ')" >&2
        exit 2
      fi
      printf '1 %s %s\n' "$(grep -c '' "$body")" "$ids" >> "$plan" || ro_merge_refuse "record the whole-body span"
      WHOLE_BODY=1
    else
      WHOLE_BODY=0
    fi
    sort -n -k1,1 "$plan" -o "$plan" || ro_merge_refuse "order the span plan"

    : > "$out" || ro_merge_refuse "create the merged body"
    prev=0; n_merged=0; n_conflict=0; n_unchanged=0
    ours="$RO_T/merge-ours"; base="$RO_T/merge-base"; theirs="$RO_T/merge-theirs"; merged="$RO_T/merge-merged"
    while read -r s e id; do
      [ -n "$id" ] || continue
      # Everything between the previous span and this one is consumer prose no anchor
      # covers -- a preamble, a section core never had. It is copied byte-for-byte.
      if [ "$s" -gt $((prev + 1)) ]; then
        sed -n "$((prev + 1)),$((s - 1))p" "$body" >> "$out" || ro_merge_refuse "copy the body before #${id}"
      fi
      prev="$e"

      sed -n "${s},${e}p" "$body" > "$ours" || ro_merge_refuse "stage the body's #${id}"
      git -C "$DIST" show "${BASE_SHA}:${CORE}" | section_of "$id" > "$base" || ro_merge_refuse "stage core's #${id} at ${BASE_SHA}"
      git -C "$DIST" show "${THEIRS}:${CORE}"   | section_of "$id" > "$theirs" || ro_merge_refuse "stage core's #${id} at ${THEIRS}"

      if cmp -s "$base" "$theirs"; then
        cat "$ours" >> "$out" || ro_merge_refuse "copy the body's unchanged #${id}"
        n_unchanged=$((n_unchanged + 1))
        echo "  UNCHANGED  #${id} — core is byte-identical base..theirs; body left untouched."
        continue
      fi

      # Align the three inputs before merging. On the whole-body path the extractor emits a
      # leading blank line (the one after the frontmatter fence) while `section_of` starts
      # flush at the heading. That one-line offset makes `git merge-file` mis-align ours
      # against base and report a CONFLICT on a paragraph BYTE-IDENTICAL to base -- a clean
      # re-adoption handed back as prose to merge by hand, the exact failure this mode
      # removes. Strip the blank runs off all three, then RESTORE ours' own counts after:
      # the alignment is a merge concern, not a licence to reformat the operator's file.
      lead="$(awk '{ if (NF) exit; c++ } END { print c+0 }' "$ours")"
      tail_n="$(awk '{a[NR]=$0} END {n=NR; c=0; while (n>0 && a[n]=="") {c++; n--}; print c+0}' "$ours")"
      for f in "$ours" "$base" "$theirs"; do
        awk 'NF {p=1} p' "$f" | awk '{a[NR]=$0} END {n=NR; while (n>0 && a[n]=="") n--; for(i=1;i<=n;i++) print a[i]}' > "$f.n" \
          || ro_merge_refuse "align the three sides of #${id}"
        mv "$f.n" "$f" || ro_merge_refuse "align the three sides of #${id}"
      done

      cp "$ours" "$merged" || ro_merge_refuse "stage the merge of #${id}"
      # git merge-file exits with the conflict count (capped at 127) and a negative value -- 255 --
      # when it could not run or write, which used to be counted as a conflict.
      _mrc=0
      git merge-file -L "override (yours)" -L "core@${BASE_SHA}" -L "core@${THEIRS_SHA}" \
           "$merged" "$base" "$theirs" || _mrc=$?
      if [ "$_mrc" -eq 0 ]; then
        n_merged=$((n_merged + 1))
        echo "  MERGED     #${id} — upstream's change applied, the consumer delta preserved."
      elif [ "$_mrc" -le 127 ]; then
        n_conflict=$((n_conflict + 1))
        echo "  CONFLICT   #${id} — upstream and the consumer changed the same lines." >&2
      else
        ro_merge_refuse "merge #${id} (git merge-file exited ${_mrc})"
      fi
      { i=0; while [ "$i" -lt "$lead" ]; do echo; i=$((i + 1)); done
        cat "$merged"
        i=0; while [ "$i" -lt "$tail_n" ]; do echo; i=$((i + 1)); done
      } >> "$out" || ro_merge_refuse "append the merged #${id}"
    done < "$plan"

    # Trailing body after the last span.
    total="$(grep -c '' "$body")"
    if [ "$total" -gt "$prev" ]; then
      sed -n "$((prev + 1)),\$p" "$body" >> "$out" || ro_merge_refuse "copy the body after the last span"
    fi

    # No separator line is invented here. Overrides do not agree on whether a blank follows
    # the `---` fence -- the reference consumer's has none -- and emitting one unconditionally
    # is a whitespace edit to a file whose whole promise is that sections core did not touch
    # come out byte-for-byte. The body extractor already starts at the byte after the fence,
    # so concatenating reproduces whatever the file had.
    staged="$(mktemp "${OVR}.merge.XXXXXX")" || ro_merge_refuse "create a staging file beside the override"
    # `cp -p` first so the override keeps its own mode (`mktemp` creates 0600); the write then
    # truncates the copy, never the override.
    cp -p "$OVR" "$staged" || ro_merge_refuse "stage a copy of the override"
    cat "$fmf" "$out" > "$staged" || ro_merge_refuse "write the merged override"
    mv -f "$staged" "$OVR" || ro_merge_refuse "move the merged override into place"
    staged=""

    echo "$(basename "$OVR"): ${n_merged} merged, ${n_unchanged} unchanged, ${n_conflict} conflicted."
    if [ "$n_conflict" -gt 0 ]; then
      echo "  Conflict markers are in the body. Resolve them, then: --stamp readopt" >&2
      echo "  (--stamp readopt is refused while superseded core text remains, so an" >&2
      echo "   unresolved conflict cannot be stamped away.)" >&2
      exit 1
    fi
    echo "  Review the body, then: --stamp readopt"
    exit 0
    ;;

  --stamp)
    case "$OUTCOME" in
      retire)
        rm -f "$OVR"
        echo "RETIRED  $(basename "$OVR") deleted — upstream absorbed it."
        exit 0
        ;;
      readopt)
        if grep -qE '^(<{7}|={7}|>{7})' "$OVR"; then
          echo "REFUSED  $(basename "$OVR"): unresolved merge conflict markers in the body." >&2
          grep -nE '^(<{7}|={7}|>{7})' "$OVR" | sed 's/^/    /' >&2
          echo "  Stamping now would ship <<<<<<< into the rulebook the lead reads." >&2
          exit 1
        fi
        if [ "$RESOLVE" != yes ]; then
          echo "REFUSED  $(basename "$OVR"): a shadowed anchor resolves to no heading, so the stale-text test is VACUOUS." >&2
          anchors_resolve >/dev/null
          echo "  Refusing to clear a HARD block with a check that cannot fail. Repoint \`shadows:\`," >&2
          echo "  or --stamp reaffirm --note \"<why the old clause still stands>\"." >&2
          exit 1
        fi
        if [ "$N_STALE" -gt 0 ]; then
          echo "REFUSED  $(basename "$OVR"): ${N_STALE} superseded core line(s) still in the body." >&2
          printf '%s\n' "$STALE" | sed 's/^/    | /' >&2
          echo "  A bare re-stamp would clear the HARD block while leaving the lead obeying the OLD rule." >&2
          echo "  Edit the body to carry core@${THEIRS_SHA}'s text, then re-run. Or: --stamp reaffirm --note \"...\"" >&2
          exit 1
        fi
        if [ "$N_UNADOPTED" -gt 0 ]; then
          echo "UNADOPTED-CORE-TEXT (report)  $(basename "$OVR"): ${N_UNADOPTED} line(s) core@${THEIRS_SHA} ADDS to the shadowed section are absent from the body." >&2
          printf '%s\n' "$UNADOPTED" | sed 's/^/    | /' >&2
          echo "  Stamping advances base_sha, so the next pull computes NO drift on this section" >&2
          echo "  and does not offer this text again. Stamping anyway is a decision; make it one." >&2
        fi
        ;;
      reaffirm)
        [ -n "$NOTE" ] || { echo "REFUSED  reaffirm REQUIRES --note \"<why the old clause still stands>\" — the record must show a human decided." >&2; exit 1; }
        ;;
      *) echo "readopt-override: --stamp needs one of: readopt | reaffirm | retire" >&2; exit 2;;
    esac

    tmp="$(mktemp)"
    if [ "$OUTCOME" = reaffirm ]; then
      # Append the note at the END of the `reason:` block, as a continuation line.
      #
      # NEVER append to the `reason:` LINE. A reason is routinely a multi-line YAML
      # block (six of the reference consumer's overrides have one; the longest runs 99
      # lines), so appending to line 1 splices the note INTO THE MIDDLE OF A SENTENCE
      # and mangles the text. That shipped, and it corrupted a live override: the reason
      # read `... "runs on RE-AFFIRMED against 6c5e55e: ... still stands. every pull
      # request via ...`. The reason is what the NEXT pull reads to decide "does upstream
      # supersede this?" — corrupting it is corrupting the record the whole re-adoption
      # workflow turns on.
      awk -v s="$THEIRS_SHA" -v n="RE-AFFIRMED against ${THEIRS_SHA}: ${NOTE}" '
        BEGIN{ fm=0; inreason=0; done_sha=0 }
        NR==1 && /^---$/ { fm=1; print; next }
        fm && /^---$/ {
          if (inreason) { print "  " n; inreason=0 }
          fm=0; print; next
        }
        fm && /^base_sha:/ && !done_sha {
          if (inreason) { print "  " n; inreason=0 }
          print "base_sha: " s; done_sha=1; next
        }
        fm && /^reason:/ { inreason=1; print; next }
        fm && inreason && /^[A-Za-z_][A-Za-z0-9_]*:/ {
          print "  " n; inreason=0; print; next
        }
        { print }
      ' "$OVR" > "$tmp"
    else
      awk -v s="$THEIRS_SHA" '
        BEGIN{done_sha=0}
        /^base_sha:/ && !done_sha { print "base_sha: " s; done_sha=1; next }
        { print }
      ' "$OVR" > "$tmp"
    fi
    mv "$tmp" "$OVR"
    echo "STAMPED  $(basename "$OVR"): base_sha ${BASE_SHA} -> ${THEIRS_SHA} (${OUTCOME})"
    exit 0
    ;;
esac

# ---------------------------------------------------------------------------
# Default: the dossier. Everything the operator needs to answer ONE question.
# ---------------------------------------------------------------------------
#
# THE REASON PANEL'S CLIP ANNOUNCES ITSELF, AND THE ANNOUNCEMENT IS THE WHOLE POINT. It was
# `head -20`: a reason longer than twenty folded lines lost its tail with nothing in the output
# saying so, and the operator adjudicated step 7's retire / readopt / reaffirm against a
# fragment indistinguishable from a complete field. That is the same dangerous direction the
# plain-scalar defect above had — a plausible value is worse than an obviously missing one.
#
# RAISING THE LIMIT IS NOT THE FIX AND A LADDER OF LIMITS IS NOT EITHER. Every constant has a
# reason longer than it, and the silent clip simply moves. The `awk` END rule fires whenever the
# authored line count exceeds what was printed, so the notice is a function of the INPUT rather
# than of the bound, and no value of the bound can produce a silent clip.
#
# `awk`, NOT `head` PLUS A SECOND COUNT OF THE SAME PIPELINE. `fm_block` would have to run twice
# to compare a count against the bound, which is two reads of one file that can disagree; the END
# rule already holds `NR`, so one pass answers both. ASCII ONLY in that string: the suite runs awk
# under `LC_ALL=C`, where a multibyte character in the program text has aborted a scan mid-file.
#
# THE DOSSIER'S FIXED TEXT IS `printf '%s\n'` OF ITS LINES, NEVER A HEREDOC. bash 3.2 stages every
# heredoc to a temp file, and when that write failed -- `ulimit -f`, a full TMPDIR -- `cat` never ran:
# the header, the panel titles and THE ONE QUESTION's three commands vanished from the dossier at
# rc 0, and the panels below them read as belonging to the panel above. Each argument is one line of
# the heredoc it replaces, so the healthy output is byte-identical.
printf '%s\n' \
  '================================================================================' \
  "RE-ADOPTION DOSSIER — $(basename "$OVR")" \
  '================================================================================' \
  "shadows   : ${SHADOWS}" \
  "base_sha  : ${BASE_SHA}  ->  theirs: ${THEIRS_SHA}" \
  "core file : ${CORE}" \
  '' \
  '--- WHY THIS OVERRIDE EXISTS (its own stated reason) --------------------------' \
  "$(fm_block "$OVR" reason | fold -s -w 78 | sed 's/^/  /' | awk 'NR<=20{print} END{if (NR>20) printf "  [... %d further line(s) NOT SHOWN. Read the override file named above for the whole reason.]\n", NR-20}')" \
  '' \
  "--- WHAT UPSTREAM CHANGED IN THE SHADOWED SECTION (${BASE_SHA}..${THEIRS_SHA}) ---"

# THIS PANEL HAS NOW FAILED IN BOTH DIRECTIONS, AND THE REMEDY IS ONE PARTITION RATHER
# THAN TWO GUARDS.
#
# Direction 1, fixed earlier and kept here because it is why the loop is fed by a
# here-string: `printf '%s'` without the trailing newline made `while read` fail its
# condition on the final line, so the loop body NEVER RAN and the panel came out EMPTY --
# which reads as "nothing changed" on a section that changed. (`stale_lines` escaped it
# only because a here-string appends one.)
#
# Direction 2: the heading was echoed BEFORE the diff was computed, so an anchor whose
# section is byte-identical rendered as a bare `## <id>` underneath a title that asserts
# it CHANGED. Measured on the reference consumer, entry
# `overrides/steps__retro__domain-sections.md`, four anchors, `b1ee196..e3f7c20d`: four
# headings and ZERO diff hunks. The reader's inference from four headings is "four
# shadowed sections drifted", which points at the three-way re-adoption merge and the
# re-stamp -- surgery on an entry needing neither. THE FLAG NAMES ARE DELIBERATELY NOT
# SPELLED HERE: I59's fixture proves its undocumented-mode arm by reverting every site that
# names a dispatched mode, and a third naming site in this comment leaves that mutation
# green against a mode nothing documents. Describe the mode; do not spell it.
# It reached an operator's report before it was caught, and it is
# SELF-MASKING because the same rendering is correct whenever at least one anchor DID
# change, so nothing downstream disagrees.
#
# Both directions are one defect: the panel had no way to SAY "nothing drifted". So the
# states are now disjoint and every one of them is spoken. Silence is unconstructible
# here -- each path through this block prints something -- which is what stops a
# regression in either direction from reading as a verdict.
#
# NOT A PIPELINE, deliberately. A `while` on the last stage of a pipeline runs in a
# SUBSHELL and the counters below would die with it, leaving the panel reporting zero
# anchors on every entry. The anchor list is resolved into a variable first and split into
# RO_L in the main shell -- no heredoc, which bash 3.2 stages to a temp file and which, if that
# write failed, would run the loop ZERO times and print the "NO ANCHOR could be read" line over
# an entry whose anchors were all readable. Not forced: `shadow_ids` writes the same ids to a
# file earlier in every run, so no world makes this the one write past a limit. Each side is staged by `ro_section`, whose
# status is read: 128 (the path absent at the ref) is an empty side as it always read, and
# anything else refuses, where an unchecked `section_of > file` that failed read as an
# UNRESOLVED anchor.
_ids="$(printf '%s\n' "$SHADOWS" | tr ',' '\n' | sed -n 's/.*#//p' \
        | sed 's/^ *//; s/ *$//' | grep -v '^$')"
_panel="$RO_T/panel"
: > "$_panel" || ro_refuse "creating the drift panel"
_n_anchors=0; _n_drifted=0; _n_unres=0; _unresolved=""
ro_lines "$_ids"
for id in ${RO_L[@]+"${RO_L[@]}"}; do
  [ -n "$id" ] || continue
  _n_anchors=$((_n_anchors + 1))
  ro_section "$BASE_SHA" "$id" panel-base || ro_refuse "the drift panel's read of #${id} at ${BASE_SHA}"
  ro_section "$THEIRS" "$id" panel-theirs || ro_refuse "the drift panel's read of #${id} at ${THEIRS}"
  _bf="$RO_T/panel-base.sec"; _tf="$RO_T/panel-theirs.sec"
  # AN UNRESOLVABLE ANCHOR IS NOT AN UNCHANGED ONE. Both sides empty makes `diff` silent,
  # and folding that into "did not drift" is a false reassurance about the one anchor the
  # operator most needs told about -- it is the same vacuity `--stamp readopt` refuses on.
  if [ ! -s "$_bf" ] && [ ! -s "$_tf" ]; then
    _unresolved="${_unresolved:+$_unresolved, }#${id}"
    _n_unres=$((_n_unres + 1))
    continue
  fi
  _d="$(diff -u "$_bf" "$_tf" | tail -n +3 | sed 's/^/    /')"
  [ -n "$_d" ] || continue
  _n_drifted=$((_n_drifted + 1))
  { echo "  ## ${id}"; printf '%s\n' "$_d"; } >> "$_panel" || ro_refuse "appending #${id} to the drift panel"
done

# THE "byte-identical" SENTENCE MAY ONLY COUNT ANCHORS THAT WERE ACTUALLY COMPARED.
# Caught by this change's own control: an entry whose single anchor resolves nowhere
# printed "all 1 shadowed anchor(s) are byte-identical" immediately above the UNRESOLVED
# line contradicting it. An anchor that was never read is not an anchor that matched, and
# stating otherwise re-introduces the exact false reassurance this block exists to remove.
_n_compared=$((_n_anchors - _n_unres))
if [ "$_n_anchors" -eq 0 ]; then
  echo "  (NO ANCHOR could be read from this entry's \`shadows:\` value, so nothing was"
  echo "   compared. This panel is silent because the comparison never ran, NOT because"
  echo "   nothing changed.)"
elif [ "$_n_compared" -le 0 ]; then
  echo "  (NOT COMPARED -- every one of this entry's ${_n_anchors} shadowed anchor(s) resolves"
  echo "   to no heading at either ref. This panel says nothing about whether core moved;"
  echo "   see the UNRESOLVED line below.)"
elif [ "$_n_drifted" -eq 0 ]; then
  echo "  (none -- all ${_n_compared} compared anchor(s) are byte-identical at ${BASE_SHA}"
  echo "   and ${THEIRS_SHA}. Nothing upstream displaced this entry, so there is no core"
  echo "   text to re-adopt and no section to merge.)"
else
  cat "$_panel"
fi
[ -n "$_unresolved" ] && printf '%s\n' \
  "  UNRESOLVED: ${_unresolved} -- resolves to no heading at either ref, so it was NOT compared and its absence above is not a reading."

printf '%s\n' '' "--- SUPERSEDED CORE TEXT STILL IN THIS OVERRIDE'S BODY -------------------------"
if [ "$N_STALE" -gt 0 ]; then
  printf '%s\n' "$STALE" | sed 's/^/    | /'
  echo ""
  echo "  ${N_STALE} line(s) above are core text from ${BASE_SHA} that ${THEIRS_SHA} REPLACED."
  echo "  The lead obeys this override, not core: un-migrated, the fix is INERT here."
else
  echo "    (none — the body carries no text upstream has superseded)"
fi

printf '%s\n' '' "--- CORE TEXT ${THEIRS_SHA} ADDS THAT THIS BODY DOES NOT CARRY -------------------------"
if [ "$N_UNADOPTED" -gt 0 ]; then
  printf '%s\n' "$UNADOPTED" | sed 's/^/    | /'
  echo ""
  echo "  ${N_UNADOPTED} line(s) above are new in core@${THEIRS_SHA}'s shadowed section."
  echo "  The override replaces that section, so this text reaches no lead until it is merged."
  echo "  A purely additive upstream change leaves the panel above EMPTY and this one full;"
  echo "  read them together, or the commonest kind of drift looks like no drift at all."
else
  echo "    (none — the body carries everything upstream added to the shadowed section)"
fi

printf '%s\n' \
  '' \
  '--- THE ONE QUESTION -----------------------------------------------------------' \
  "  Does upstream's change SUPERSEDE the reason this override exists?" \
  '' \
  '  YES, entirely      -> retire    the override is redundant; core now does this.' \
  "       readopt-override.sh <dist> ${THEIRS} <consumer> ${OVR} --stamp retire" \
  '' \
  "  NO, but core's new text must be carried into it" \
  '                     -> readopt   merge the new core text into the body, preserving' \
  "                                  the consumer's delta, THEN stamp. The stamp is" \
  '                                  REFUSED while superseded core lines remain.' \
  "       \$EDITOR ${OVR}" \
  "       readopt-override.sh <dist> ${THEIRS} <consumer> ${OVR} --stamp readopt" \
  '' \
  '  NO, and the old clause still stands as written' \
  '                     -> reaffirm  requires a note; it goes into the record.' \
  "       readopt-override.sh <dist> ${THEIRS} <consumer> ${OVR} --stamp reaffirm --note \"...\"" \
  '' \
  '  DOING NOTHING IS NOT AN OUTCOME. The HARD block persists until base_sha is' \
  '  re-stamped, and a bare re-stamp is refused while the body is stale.' \
  '================================================================================'
