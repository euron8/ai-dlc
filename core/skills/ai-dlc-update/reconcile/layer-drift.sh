#!/usr/bin/env bash
# ai-dlc-update — layer-drift detection for the Rule 27 consumer layers.
#
# Mechanizes what was previously PROSE ONLY. `SKILL.md`'s "Layered consumers"
# section told the agent to check, per override, whether upstream changed the
# core rule it shadows. Nothing implemented it: `preclassify.sh` never referenced
# `extensions`/`overrides`/`base_sha`/`shadows`/`hooks`. So the check depended on
# an agent remembering to run `git diff` twelve times, and in practice it never
# ran. A real consumer accumulated 5 overrides whose `base_sha` pointed at the
# CONSUMER's own repo (so any diff would have died on `fatal: bad revision`), and
# two shipped upstream changes were silently discarded by a stale override.
#
# Self-contained per the skill's HARD CONSTRAINT: shells to git, reads only layer
# FRONTMATTER and markdown headings. It classifies text; it never interprets a
# pipeline rule.
#
# Usage: layer-drift.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>
#   dist-repo      path to the distribution git checkout (source of core/)
#   base-sha       the `commit` field from the consumer's .ai-dlc-version stamp
#   theirs-ref     target upstream ref (e.g. main, HEAD, a tag)
#   consumer-root  the consumer project root (contains .claude/)
#
# Output: TSV to stdout — STATUS<TAB>ENTRY<TAB>TARGET<TAB>DETAIL
# Exit:   0 always (a classifier, not a gate). The CALLER decides; statuses
#         prefixed HARD- must block `apply` until the operator adjudicates.
#
# Statuses
#   HARD-OVERRIDE-BASE-CONSUMER-SHA  base_sha resolves in the CONSUMER repo, so it
#                                    is the wrong repo's sha; drift undecidable
#   HARD-OVERRIDE-BASE-UNRESOLVABLE  base_sha resolves in neither repo
#   HARD-OVERRIDE-DRIFT-SECTION      shadowed section's text changed base..theirs, so
#                                    the override is now shadowing a rule that NO LONGER
#                                    EXISTS upstream. BLOCKS `apply` until adjudicated:
#                                    re-adopt the new clause into the override and
#                                    re-stamp base_sha, or confirm the old text still
#                                    applies and re-stamp anyway. Either way, LOOK.
#                                    Was advisory until v0.52.0, and that is precisely
#                                    how a core fix could land while the consumer went
#                                    on running the rule it replaced -- the lead reads
#                                    the OVERRIDE, not core. Distinct from
#                                    EXTENSION-CHECK-NUMBER-COLLISION below, which is
#                                    cosmetic, consumer-fixable, and must NOT block:
#                                    this one changes the RULES THE LEAD OBEYS.
#   OVERRIDE-DELEGATES-INTO-SHADOW   the override's BODY names a construct defined in a
#                                    heading INSIDE a section it shadows. Precedence is
#                                    overrides > extensions > core, so at load time the
#                                    override replaces that section -- including the
#                                    construct it is pointing the lead at. It reads as a
#                                    correct single-source delegation and behaves as a
#                                    dropped one. Every OTHER status here asks whether
#                                    UPSTREAM moved; this asks whether the override can
#                                    reach its own target, which is true or false today
#                                    and independent of any pull. Report-only: the
#                                    delegation is sometimes deliberate (the lead may be
#                                    expected to open core), so this must not block, but
#                                    it must be VISIBLE -- the reference consumer carried
#                                    two of these while every mechanical check reported
#                                    green, and the mechanism they broke is the one by
#                                    which any future change to the delegated-to construct
#                                    silently fails to arrive.
#   OVERRIDE-ASSERTS-SHADOW-SURVIVES the override's BODY asserts that the section it
#                                    shadows is UNCHANGED and still governs. The sibling of
#                                    OVERRIDE-DELEGATES-INTO-SHADOW and the same mechanism:
#                                    precedence replaces the whole section at load time, so
#                                    a body that replaces one paragraph of a three-paragraph
#                                    section and says the other two still govern is stating
#                                    something FALSE ABOUT ITS OWN EFFECT. The delegation
#                                    case points the lead at text that is gone; this one
#                                    tells the lead the text is still there. Both read as
#                                    careful authorship, which is why neither is visible.
#                                    Report-only, and independent of any pull: true or false
#                                    today, like its sibling.
#   OVERRIDE-LOOSE-ANCHOR            a `shadows:` anchor resolves only by the REVERSE arm of
#                                    the containment match — the anchor CONTAINS the heading —
#                                    so it declares something finer than a heading and quietly
#                                    resolves to the WHOLE section instead. E7 errors on this
#                                    at authoring time; that validator is consumer-run and
#                                    SKIPPABLE and the pull is not, which is the whole reason
#                                    this exists. Report-only: resolution is unchanged and the
#                                    entry renders, so what is wrong is the operator's belief
#                                    about its extent, not the pull.
#   OVERRIDE-DOUBLE-SHADOW           two entries declare the same (file, normalised anchor).
#                                    Each is well-formed alone; only the PAIR is the finding,
#                                    which is why it is computed across entries after the
#                                    loop. Precedence resolves the overlap silently, so which
#                                    body governs is an ordering accident no entry declares,
#                                    and every commit touching the span invalidates BOTH
#                                    stamps. Report-only: the one live instance is deliberate
#                                    and says so in prose, and an ERROR would fire on a case
#                                    the consumer already reasoned about in writing.
#   OVERRIDE-DRIFT-FILE              anchor is not a locatable heading AND the file
#                                    changed -> cannot prove the section is safe;
#                                    surface for re-confirmation (never skip)
#   OVERRIDE-ANCHOR-UNRESOLVED       anchor not found in theirs (upstream restructured)
#   OVERRIDE-OK                      shadowed section unchanged
#   EXTENSION-HOOK-MISSING           hooks: target absent in theirs
#   EXTENSION-FIXTURE-UNBOUND        an entry declares `fixtures:` naming a directory this
#                                    consumer does not have. That binding is what puts a
#                                    consumer check's fixture into core H1's DERIVED set, so
#                                    a dangling one makes H1 report coverage it does not have
#                                    — the same shape as the hand-typed enumeration H1 deleted.
#                                    Level-triggered: a state of the tree, not an event.
#   EXTENSION-RETIRE-CANDIDATE       theirs' core file NEWLY defines a section this
#                                    extension also defines, matched by TITLE (at the
#                                    same number or a different one) -> upstream
#                                    absorbed it this pull; the consumer copy is now
#                                    a duplicate. THE absorption-retirement signal.
#   EXTENSION-RESTATES-CORE          same, but core already had it AT BASE. The
#                                    consumer has been carrying a duplicate of a core
#                                    section for some number of releases and was never
#                                    told, because the old detector only fired on the
#                                    single pull that landed the absorption. Rule 27(c)
#                                    forbids restating core: retire it, or refile as an
#                                    override with a base_sha if it hardens core.
#   EXTENSION-CHECK-NUMBER-COLLISION theirs' core file defines this extension's check
#                                    NUMBER with a DIFFERENT title -> one integer now
#                                    names two unrelated checks in the merged document,
#                                    so the bare "Check N" the lead commits to the gate
#                                    log has no referent. The exact complement of the
#                                    absorption signal. Report-only: a collision is
#                                    decidable and consumer-fixable, so it must not
#                                    block a pull (a consumer must never be unable to
#                                    take a security fix because its own catalog needs
#                                    relabelling). Tagged NEW-THIS-PULL / PRE-EXISTING.
#   EXTENSION-HOOK-DRIFT             hooked core file changed base..theirs, and the
#                                    entry declares no `extends:` anchor -> its drift
#                                    subject is the whole FILE. 1421 (entry, commit)
#                                    events on the reference consumer against 133 at
#                                    anchor grain; the other 91% is the cost of not
#                                    declaring one.
#   EXTENSION-ANCHOR-DRIFT           the entry DOES declare `extends:`, and that span
#                                    changed base..theirs. The same re-read duty,
#                                    narrowed to the section the entry named.
#   EXTENSION-ANCHOR-MISSING         `extends:` resolves to no heading at theirs ->
#                                    upstream renamed or absorbed the section away.
#                                    LOUD and deliberately not folded into -OK: a
#                                    span that resolves to nothing compares empty
#                                    against empty, so the natural failure of the
#                                    narrowing is silence on a real change.
#   EXTENSION-OK                     hooked core file unchanged, OR it changed and the
#                                    declared `extends:` span did not

set -uo pipefail

# MODES
#   layer-drift.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>
#       classify. The only mode a pull runs.
#   layer-drift.sh --adjudicated-codes <dist-repo> <theirs-ref>
#       print, one per line, the clause CODES this script will hold to the layer conformance
#       adjudication — derived from layer-contract.yaml at <theirs-ref> by the same grammar the
#       classifier uses, because it IS that grammar and not a copy of it. Exists so I58 can join
#       the reader against the declaration by RUNNING the reader: a restated extraction in the
#       invariant would agree with itself while the shipped one had gone inert. Exit 0 with no
#       output is a legitimate answer (no clause sits at that level).
MODE=classify
if [ "${1:-}" = "--adjudicated-codes" ]; then
  [ $# -eq 3 ] || { echo "usage: layer-drift.sh --adjudicated-codes <dist-repo> <theirs-ref>" >&2; exit 2; }
  MODE=codes; DIST="$2"; THEIRS="$3"; BASE=""; CONSUMER=""
else
  [ $# -eq 4 ] || { echo "usage: layer-drift.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>" >&2; exit 2; }
  DIST="$1"; BASE="$2"; THEIRS="$3"; CONSUMER="$4"
  # ABSOLUTIZE, BECAUSE ONE READER OF $CONSUMER RUNS INSIDE THE OTHER REPO.
  # `adj_digest` hashes the consumer's entry file with `git -C "$DIST" hash-object
  # "$CONSUMER/$1"` -- and `-C` moves git into the DISTRIBUTION first, so a RELATIVE
  # consumer root resolves there and the hash silently fails. Every ADJUDICATED row then
  # reports "subject digest could not be computed (entry or target unreadable)" instead of
  # carrying the digest the operator needs to record a verdict against.
  #
  # WHAT MAKES IT A DEFECT RATHER THAN A USAGE ERROR: the BLOCKER COUNT IS IDENTICAL either
  # way. Measured on the reference consumer at 0.263.0 -- 11 "could not be computed" under
  # `.`, 0 under the absolute path, and 13 HARD- rows in BOTH runs. Nothing in the output
  # tells the reader they are holding eleven unactionable messages, which is this repo's
  # "a check that cannot fire reads exactly like one that passed" in its reporting form.
  #
  # Fixed at parse time rather than at the call site so no LATER reader of $CONSUMER can
  # reintroduce it, and in preclassify.sh's donor form rather than a new one -- it has
  # absolutized both roots this way since it was written. The `codes` mode above leaves
  # CONSUMER empty by design and must not be absolutized into the current directory.
  CONSUMER="$(cd "$CONSUMER" 2>/dev/null && pwd)" || { echo "layer-drift: consumer-root not a directory: ${4}" >&2; exit 2; }
fi

SKILL_DIR="$CONSUMER/.claude/skills/ai-dlc"
EXT_DIR="$SKILL_DIR/extensions"
OVR_DIR="$SKILL_DIR/overrides"

# section_of()/norm() — shared with register-drift.sh and readopt-override.sh.
# Three copies of the section resolver drifted apart twice (v0.52.0, v0.54.2);
# see lib.sh for the history and why this one is sourced rather than inlined.
SELF="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$SELF/lib.sh" || { echo "layer-drift: cannot source $SELF/lib.sh" >&2; exit 1; }

# emit() is also where the layer conformance adjudication is applied — see the ADJUDICATION
# block below for why the duty lives HERE and not at the two drift call sites.
emit() {
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"
  adj_check "$1" "$2" "$3"
}

TAB="$(printf '\t')"

# Every (file, anchor) an override claims, accumulated across ALL entries for the duplicate check
# after the loop. bash 3.2 ships on macOS and has no associative arrays; a plain accumulating
# string is safe here only because nothing ever SEARCHES it -- it is handed whole to sort/awk,
# which key on the full field. A substring test against a growing string is how a normalised key
# that happens to be a prefix of another starts matching it.
#
# NOT A TEMP FILE WITH AN `EXIT` TRAP, and this cost a measurement to learn: installing the trap
# made bash report `printf: write error: Broken pipe` from every `printf | grep -q` in this
# script -- 90 lines of stderr on a classifier whose stderr an operator is meant to read, from
# pipelines the change did not touch. Removing the trap took it to 0 with byte-identical rows.
shadow_keys=""

# core/-relative layer target -> path INSIDE the distribution tree.
dist_path() {
  case "$1" in
    team-roles/*) printf 'core/%s' "$1" ;;
    *)            printf 'core/skills/ai-dlc/%s' "$1" ;;
  esac
}

fm() { # fm <file> <key>
  awk -v k="$2" '
    NR==1 && $0=="---" { inf=1; next }
    inf && $0=="---"   { exit }
    inf && index($0, k":")==1 { sub("^"k":[[:space:]]*", ""); print; exit }
  ' "$1"
}

layer_files() { [ -d "$1" ] || return 0; find "$1" -type f -name '*.md' ! -name 'README.md' 2>/dev/null | sort; }

# An entry's body — everything after the closing frontmatter `---`.
#
# awk, not `sed '1,/^---$/d'`: BSD sed rejects the multi-command form this needs, and
# the failure mode is an EMPTY body, which makes every predicate below report a clean
# zero. Measured during development: the first probe scanned 13 overrides, printed no
# findings, and had in fact read nothing.
body_of() {
  awk 'NR==1 && $0=="---" { fm=1; next } fm && $0=="---" { fm=0; next } !fm' "$1"
}

# Backticked constructs in a stream, lowercased and deduped — the join key for
# OVERRIDE-DELEGATES-INTO-SHADOW.
#
# Backticks, not heading TEXT. A delegation names the construct (`## Machine Audits`),
# never the full title of the heading that defines it ("`## Machine Audits` — one table,
# not five transcriptions"). Matching whole heading text found ZERO of the two real
# instances; matching the backticked span found both with no false positives.
ticks_of() { grep -o '`[^`]\{3,60\}`' | tr 'A-Z' 'a-z' | sort -u; }
rel() { printf '%s' "${1#"$CONSUMER"/}"; }

git_show() { git -C "$DIST" show "$1:$2" 2>/dev/null; }
have()     { git -C "$DIST" cat-file -e "$1:$2" 2>/dev/null; }

# supersessions_of <ref> — TSV rows `shadows<TAB>since<TAB>settings_env_key` from core's
# `override_supersessions:` block at that ref. PARSED, not sourced: the contract is data
# the pull reads, and this file's HARD CONSTRAINT is that it shells to git and reads
# frontmatter and headings, never interprets a pipeline rule. Read at THEIRS rather than
# at the consumer's stamp, because the whole point is a supersession the consumer has not
# seen yet. Top-level-key detection ends the block, so a later key cannot leak rows in.
supersessions_of() {
  git_show "$1" core/skills/ai-dlc/layer-contract.yaml | awk -v TAB="$TAB" '
    /^override_supersessions:/ { inblk=1; next }
    inblk && /^[a-z_]+:/       { inblk=0 }
    !inblk                     { next }
    /^[[:space:]]*-[[:space:]]*shadows:[[:space:]]*/ {
      if (sh != "") print sh TAB si TAB en
      sh=$0; sub(/^[[:space:]]*-[[:space:]]*shadows:[[:space:]]*/,"",sh); si=""; en=""; next
    }
    /^[[:space:]]*since_core_version:[[:space:]]*/ {
      si=$0; sub(/^[[:space:]]*since_core_version:[[:space:]]*/,"",si); gsub(/"/,"",si); next
    }
    /^[[:space:]]*settings_env_key:[[:space:]]*/ {
      en=$0; sub(/^[[:space:]]*settings_env_key:[[:space:]]*/,"",en); next
    }
    END { if (sh != "") print sh TAB si TAB en }
  '
}

# ---------------------------------------------------------------------------
# THE LAYER CONFORMANCE ADJUDICATION
#
# A clause at `level: ADJUDICATED` has a mechanized candidate set and a HUMAN verdict. This
# block is the enforcement: every row whose status is such a clause's code must have a verdict
# recorded in the consumer's register under the subject digest it fired on, or the pull blocks.
#
# WHY THE DUTY LIVES IN emit() AND NOT AT THE DRIFT CALL SITES. A per-call-site opt-in is a
# hand-list wearing control flow: a future clause moved to ADJUDICATED whose call site was not
# also edited would carry the level and none of the duty, and a clause that cannot fire reads
# exactly like one that passed. Sited here, the level in the contract is the ONLY thing that
# decides, so migrating a clause is a one-line edit to that file and no edit to this script.
#
# WHY THE SUBJECT IS THE WHOLE TARGET FILE, INCLUDING AT ANCHOR GRAIN. emit() knows the entry
# and the target path and nothing else; deriving a finer subject would need the call site to
# hand one over, which is the opt-in this siting exists to avoid. File grain therefore over-
# fires for LC-E14 relative to the span it narrowed to. That asymmetry is deliberate and it is
# the safe one: an extra re-fire costs one adjudication, and the failure it forecloses is a
# stale verdict silently inherited across a core change — the direction this repo has shipped
# wrong before (see EXTENSION-ANCHOR-MISSING's own header, one narrowing over).
#
# THE DIGEST IS COMPUTED HERE AND NOWHERE ELSE, and it is PRINTED in the blocking row. The
# operator copies a value; nobody re-derives one. A digest an operator can compute two ways is
# a digest that will be computed two ways.
ADJ_REGISTER="$CONSUMER/_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl"
ADJ_SCHEMA_REL="core/schemas/layer-adjudication-register.json"
ADJ_CONTRACT_REL="core/skills/ai-dlc/layer-contract.yaml"

# The ADJUDICATED code set, DERIVED from the contract at THEIRS — the version being pulled is
# the version the consumer is held to. `level:` precedes `code:` in every clause, which is what
# lets one pass carry the level forward onto the code it belongs to.
ADJ_CODES="$(git_show "$THEIRS" "$ADJ_CONTRACT_REL" | awk '
  /^  - id:/       { lvl=""; next }
  /^    level:/    { lvl=$2; next }
  /^    code:/     { if (lvl == "ADJUDICATED") print $2; next }
')"

# The verdict vocabulary, read from the schema's own `verdict` enum rather than restated. A
# record whose verdict is outside it does not satisfy the duty: otherwise any string clears a
# blocking row and the adjudication is a formality a typo passes.
#
# The FIRST draft of this extractor kept only tokens containing a hyphen, which silently dropped
# `retire` — two of three values survived and every probe still looked like it worked. Hence the
# emptiness guard below, and hence reading the enum the schema already validates against instead
# of a second array beside it.
# The anchor is the PROPERTY (`"verdict": {`), not the token: `"verdict"` also appears in the
# schema's `required` array, and anchoring on the bare token would start the scan at whichever
# of the two came first in the file.
ADJ_VERDICTS="$(git_show "$THEIRS" "$ADJ_SCHEMA_REL" | awk '
  /"verdict"[[:space:]]*:[[:space:]]*\{/ { inv=1; next }
  inv && /"enum"[[:space:]]*:/           { f=1; next }
  f && /\]/                              { exit }
  f                                      { gsub(/[^a-z-]/, ""); if ($0 != "") print }
')"

if [ "$MODE" = codes ]; then
  [ -z "$ADJ_CODES" ] || printf '%s\n' "$ADJ_CODES"
  exit 0
fi

adj_active() { [ -n "$ADJ_CODES" ]; }

# A vocabulary that came back empty while clauses sit at ADJUDICATED means the extraction broke,
# not that there are no verdicts. Left silent it would reject every record and read as a consumer
# who had adjudicated nothing — a broken reader wearing an unadjudicated tree's clothes.
if adj_active && [ -z "$ADJ_VERDICTS" ]; then
  echo "layer-drift: the verdict vocabulary could not be read out of ${ADJ_SCHEMA_REL} at ${THEIRS}, while layer-contract.yaml carries clauses at level ADJUDICATED. Every record would be rejected and the tree would report as wholly unadjudicated. Fix the schema's verdict enum or this extractor; do not read the resulting rows as findings." >&2
  exit 1
fi

# Does this status name a clause at ADJUDICATED? Whole-line match: a substring test would let
# one code that is a prefix of another inherit its level.
adj_is_adjudicated() { adj_active && grep -qxF -- "$1" <<<"$ADJ_CODES"; }

# (entry file at the consumer) + (target file at THEIRS). Either moving moves the digest.
adj_digest() { # $1 entry (consumer-relative), $2 core-relative target
  local ef tb
  ef="$(git -C "$DIST" hash-object "$CONSUMER/$1" 2>/dev/null)"
  tb="$(git -C "$DIST" rev-parse "$THEIRS:$(dist_path "$2")" 2>/dev/null)"
  [ -n "$ef" ] && [ -n "$tb" ] || return 1
  printf '%s\n%s\n' "$ef" "$tb" | git -C "$DIST" hash-object --stdin
}

# jq is already a reconcile dependency (preclassify.sh, settings-merge.sh). Its ABSENCE must be
# loud: a register that cannot be read is not a register with nothing in it, and answering the
# second way round would turn a missing tool into a silent blanket exemption.
# NOT A PIPELINE INTO `grep -q`, and I54's message is the reason even though its grammar does
# not reach this shape: under `pipefail` a reader that stops at its first match SIGPIPEs the
# writer, and the pipeline then reports the WRITER's status — so a MATCH answers non-zero once
# the value clears the pipe buffer. Here a match means "adjudicated", so the failure direction
# would be a blocking row on a consumer who had recorded the verdict. Both sides are read into
# variables first and the test is a here-string.
adj_lookup() { # $1 digest -> 0 if a record with a vocabulary verdict exists
  [ -f "$ADJ_REGISTER" ] || return 1
  command -v jq >/dev/null 2>&1 || return 2
  local found
  found="$(jq -r --arg d "$1" 'select(.subject_digest == $d) | .verdict' "$ADJ_REGISTER" 2>/dev/null)"
  [ -n "$found" ] || return 1
  grep -qxF -f <(printf '%s\n' "$ADJ_VERDICTS") <<<"$found"
}

adj_check() { # $1 status, $2 entry, $3 target
  adj_is_adjudicated "$1" || return 0
  case "$3" in ''|'?') return 0 ;; esac
  local d rc
  d="$(adj_digest "$2" "$3")" || {
    emit_raw HARD-LAYER-ADJUDICATION-MISSING "$2" "$3" \
      "row '$1' is a clause at level ADJUDICATED, but its subject digest could not be computed (entry or target unreadable), so no recorded verdict can be matched against it. This blocks rather than passes: an unkeyable row is the one case where 'no record found' and 'nothing to look up' are indistinguishable."
    return 0
  }
  adj_lookup "$d"; rc=$?
  case "$rc" in
    0) return 0 ;;
    2) emit_raw HARD-LAYER-ADJUDICATION-MISSING "$2" "$3" \
         "row '$1' needs a recorded verdict and jq is not on PATH, so ${ADJ_REGISTER#"$CONSUMER"/} cannot be read. A register that cannot be read is not an empty one." ;;
    *) emit_raw HARD-LAYER-ADJUDICATION-MISSING "$2" "$3" \
         "row '$1' is the layer conformance adjudication: its candidate set is mechanized and its verdict is yours. Record one line in ${ADJ_REGISTER#"$CONSUMER"/} with subject_digest ${d} and a verdict of $(printf '%s' "$ADJ_VERDICTS" | tr '\n' '|' | sed 's/|$//'), plus a reason. The digest covers this entry AND the core file it hooks at ${THEIRS}, so the verdict is spent the next time either one moves — it is not an exemption for the path." ;;
  esac
}

# The raw printer, for rows adj_check itself emits: routing those back through emit() would
# recurse, and a blocking row is never itself adjudicable.
emit_raw() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }

# A contradiction is a property of the REGISTER, not of a row, so it is checked once. Records
# are compared in FILE ORDER: the later of two differing verdicts under one key is the one that
# must declare what it overturns.
adj_register_contradictions() {
  adj_active || return 0
  [ -f "$ADJ_REGISTER" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  jq -r '[(.clause // ""), (.entry // ""), (.subject_digest // ""), (.verdict // ""), (.supersedes // ""), (.reason // "")] | @tsv' \
    "$ADJ_REGISTER" 2>/dev/null \
  | awk -F'\t' -v OFS='\t' '
      { key = $1 "\x01" $2 "\x01" $3 }
      seen[key] && prev[key] != $4 && ($5 == "" || $6 == "") {
        print "HARD-REGISTER-CONTRADICTION", $2, $1,
          "the register states two different verdicts under one key (" prev[key] " then " $4 ") and the later record declares no supersedes plus reason. Undeclared, a lookup answers with whichever record is read and the blocking half of this tier depends on file order. Retraction is available; declare it."
      }
      { seen[key] = 1; prev[key] = $4 }
    '
}
adj_register_contradictions

# Section anchors a markdown STREAM defines: `### 5c. T` headings + `**7a-post. T**`
# bold anchors (a layer entry may define 7a-post the bold way; see
# bold_anchors_of_file below for how a bold anchor is told from a bold prose list).
#
# Three tolerances, each paid for by a real miss:
#   `Check `  core wrote one check as `### Check 24.` while every other is
#             `### 24.`; a digit-anchored regex skipped it, so the v0.48.0 number
#             collision was invisible to the tool built to surface layer drift.
#   letter    two consumer extensions head their checks `## Check AP — …` /
#             `## Check VH — …`, which yielded ZERO anchors. Both are
#             `push_candidate: true` — they ARE the push queue, the entries most
#             likely to be absorbed — so absorption of either could never fire.
#   `—`       those same headings separate id from title with an em-dash, not a dot.
#
# The id shape stays deliberately narrow -- `24`, `3b`, `11a`, `H1`, `AP` -- and is
# NOT a general word. A permissive `[A-Z]*[a-z-]*` would read `### Scope.` as an
# anchor named "Scope" and start diffing prose sections against each other.
ANCHOR_RE='^#{2,4}[[:space:]]+(Check[[:space:]]+)?([0-9]+[a-z-]*|[A-Z]{1,3}[0-9]*)[[:space:]]*[.—]'
strip_anchor() { sed -E 's/^#+[[:space:]]+(Check[[:space:]]+)?//; s/[[:space:]]*[.—]$//'; }
anchors_of_stream() {
  { grep -Eho "$ANCHOR_RE" | strip_anchor
  } 2>/dev/null | grep -E '.' | sort -u
}
# A bold section ANCHOR (`**7a-post. Log Rotation …**`) against a bold PROSE LIST
# item (`**1. Narrative drift.** Rule text continues…`). Both open identically, so
# the opening is not the signal: what follows the CLOSING `**` is. An anchor's bold
# span IS the heading — it ends the line, or the heading wraps and never closes on
# it. A list item closes its label and then continues in plain prose.
#
# Paid for by a real miss, like the tolerances above. Matching the opening alone read
# a consumer's three-item rule-weakness triage list as sections 1/2/3 and collided
# them with core's retro steps 1/2/3: a defect reported on every pull, forever, in
# text that defines no section — and the remedy the message prescribes ("label the
# heading `### 1. [ext:<id>] …`") cannot be applied to a sentence. A detector that
# cannot be silenced by following its own advice teaches the operator to stop
# reading it, which is the failure the whole file is written against.
bold_anchors_of_file() {
  awk '
    /^\*\*(Check[ \t]+)?[0-9]+[a-z-]*\./ {
      if ($0 ~ /^\*\*[^*]*\*\*[ \t]*[^ \t]/) next   # label closes, prose follows -> list item
      id = $0
      sub(/^\*\*(Check[ \t]+)?/, "", id)
      sub(/\..*$/, "", id)
      print id
    }' "$1" 2>/dev/null
}
anchors_of_file() {
  { grep -Eho "$ANCHOR_RE" "$1" 2>/dev/null | strip_anchor
    bold_anchors_of_file "$1"
  } | grep -E '.' | sort -u
}

# Normalized heading TEXT for a given anchor, from a stream on stdin.
# e.g. anchor "1a" in "### 1a. Prior-Decision Search (settled corpus)" -> "prior decision search settled corpus"
heading_text_for() { # heading_text_for <anchor>  < stream
  awk -v a="$1" '
    function nrm(s){ s=tolower(s); gsub(/[`*]/,"",s); gsub(/[^a-z0-9]+/," ",s); gsub(/^ +| +$/,"",s); return s }
    $0 ~ ("^#{2,4}[ \t]+(Check[ \t]+)?" a "[.—]") || $0 ~ ("^\\*\\*(Check[ \t]+)?" a "\\.") {
      h=$0; sub(/^#+[ \t]+/,"",h); sub(/^\*\*/,"",h); sub(/^Check[ \t]+/,"",h)
      sub("^" a "[.—][ \t]*","",h)
      # Strip the catalog label before normalizing, or "[ext:foo]" becomes part of the
      # title and a correctly-labelled heading can never match the core title.
      gsub(/\[ext:[A-Za-z0-9_.-]+\][ \t]*/, "", h); gsub(/\[core\][ \t]*/, "", h)
      print nrm(h); exit
    }' 2>/dev/null
}

# Does the heading at <anchor> carry an explicit catalog label?
#
# A labelled heading is the RESOLVED state of a number collision, not a violation:
# `### 25. [ext:foo] …` and core's `### 25.` name their catalogs at the point of use,
# which is exactly what the v0.49.0 crosswalk asks for.
#
# `validate-layer-entries.sh` learned this in v0.53.0. THIS script did not, so after a
# consumer correctly relabelled all 16 of its colliding headings, layer-drift went on
# reporting 11 collisions — on every pull, forever, for entries that are FIXED. It is
# report-only, so it corrupts nothing; it just trains the operator to stop reading the
# reconcile report. A report that is always wrong is a report nobody reads.
#
# Third instance in this project of the same defect: TWO implementations of one
# predicate, drifting apart. (readopt-override's resolver vs layer-drift's;
# register-drift's resolver vs layer-drift's; now this.)
heading_labelled_for() { # heading_labelled_for <anchor>  < stream
  awk -v a="$1" '
    $0 ~ ("^#{2,4}[ \t]+(Check[ \t]+)?" a "[.—]") || $0 ~ ("^\\*\\*(Check[ \t]+)?" a "\\.") {
      print ($0 ~ /\[ext:[A-Za-z0-9_.-]+\]|\[core\]/) ? "yes" : "no"; exit
    }' 2>/dev/null
}

# Do two normalized headings describe the same section? Jaccard over significant
# tokens (>=0.6), OR near-total containment of the shorter title in the longer
# (>=0.75, which forgives an appended provenance tag like "[PI-S259-1 addendum]").
#
# The old rule -- >=2 shared tokens among the first 4 significant words -- was far
# too loose to carry the weight now placed on it. Verified: consumer check 22
# "Smoke test evidence (deploy-validate gate only)" and core check 11 "Smoke test
# coverage for user-facing changes?" share {smoke, test} and were judged the SAME
# section. Since a title match now drives EXTENSION-RETIRE-CANDIDATE, that pair
# would have told a consumer to delete a live deploy-validate check. A loose title
# match is worse than no title match: it turns a reporting tool into a data-loss bug.
#
# Consumer gate-validation check NUMBERS remain a sanctioned separate namespace
# (core's "Consumer-catalog crosswalk"), so a bare number match is never evidence
# of absorption on its own — the titles must agree too.
# --- OVERRIDE-ASSERTS-SHADOW-SURVIVES -------------------------------------------------
# THE BODY MUST BE FLATTENED BEFORE MATCHING, and this is not a style choice. Layer bodies
# are hard-wrapped at ~72 columns, so the claim splits across a newline: the reference
# consumer's second instance wraps between "Every other part of" and "Check 14". Every
# line-based grep for it returns ZERO, which reads exactly like the claim not being there.
# That false zero was measured while choosing this predicate, on a probe written to be the
# CONTROL for a different question.
#
# WHAT DISCRIMINATES, MEASURED. A bare survival-vocabulary scan (unchanged / still governs /
# untouched / survives) matches 5 of the reference consumer's 13 overrides and only 2 are
# real -- the unshippable shape this repo forbids. The three false ones are each a claim
# about something OUTSIDE the shadowed span, and they separate on ONE structural signal: the
# noun the claim is about.
#   - "the seven-precondition evaluation ... apply unchanged"    -> subject is another FILE
#   - "a repair edits the artifact on UNCHANGED scope"           -> adjectival; no referent
#   - "(Rule 5 fast-track still applies)"                        -> a DIFFERENT named unit
#   - "the audit basis recorded below holds unchanged"           -> the override is own body
# So the predicate requires a scope phrase whose noun is the SHADOWED GRAIN -- section,
# check, rule, clause. That takes the false-positive set to ZERO across all 13, and it is
# also why no separate carve-out is needed for the legitimate shape the grain warning names:
# "the rest of the FILE is unchanged" is TRUE for an override shadowing one section, and
# `file` is not in the noun set, so it cannot match. That is a structural exclusion, not a
# suppression list.
#
# THE GAP IS PUNCTUATION-FREE (`[a-z0-9 ]{0,20}`) on purpose. Allowing punctuation lets the
# phrase bleed across clause boundaries and join a scope word in one sentence to a noun in
# the next, which is the same containment degeneracy same_section() records below.
#
# WHAT IT DOES NOT CATCH, STATED PLAINLY. An override shadowing a SUB-heading whose body
# correctly says the surrounding PARENT section is unchanged would match, because the noun is
# still `section`. No instance exists on the reference consumer, and the status is
# report-only, so the cost is one line an operator dismisses. Closing it means joining each
# named construct to the shadowed span's text at base_sha -- both real instances name the
# constructs they claim survive, in an em-dash list -- which is the strengthening path if an
# operator ever reports that false positive.
SURVIVAL_SCOPE_RE='(surrounding|rest of the|remainder of the|every other part of|other parts of|rest of this)[ ]?[a-z0-9 ]{0,20}(section|check|rule|clause)'
SURVIVAL_CLAIM_RE="unchanged|untouched|still governs?|still applies|still holds?|remains in force|survives?|is core's"
asserts_shadow_survives() { # asserts_shadow_survives <body-text>  -> 0 if it makes the claim
  printf '%s' "$1" | tr '\n' ' ' | tr -s ' ' \
    | grep -oiE "$SURVIVAL_SCOPE_RE.{0,250}" \
    | grep -qiE "$SURVIVAL_CLAIM_RE"
}

same_section() { # same_section <textA> <textB>
  [ -n "$1" ] && [ -n "$2" ] || return 1
  awk -v A="$1" -v B="$2" '
    BEGIN {
      split("the a an of and for to in on this its only gate gates", s, " ")
      for (i in s) stop[s[i]] = 1
      n = split(A, x, " "); for (i = 1; i <= n; i++) if (!(x[i] in stop)) a[x[i]] = 1
      n = split(B, y, " "); for (i = 1; i <= n; i++) if (!(y[i] in stop)) b[y[i]] = 1
      for (k in a) { na++; u++; if (k in b) inter++ }
      for (k in b) { nb++; if (!(k in a)) u++ }
      if (u == 0 || na == 0 || nb == 0) exit 1
      smaller = (na < nb) ? na : nb
      # NOTE: this awk is a single-quoted string. No apostrophes below, ever.
      #
      # Containment forgives an appended provenance tag -- but it DEGENERATES when the
      # shorter title has ONE significant token: inter/smaller is then 1/1 = 1.00 for any
      # title containing that word, and the OR short-circuits the jaccard test. The core
      # heading "### 2. Deploy" reduces to {deploy} (the stoplist eats gate/gates), so
      # every consumer heading naming deploy matched it at jaccard 0.12-0.20. Twelve of
      # the 166 anchored core headings reduce to one token: not a one-file accident.
      #
      # Requiring smaller >= 2 is the same rule as "containment needs >=2 shared
      # significant tokens": at 0.75, smaller=2 already forces inter=2.
      #
      # The cost is a real false NEGATIVE, not the impossibility it looks like: with a
      # 1-token core title and inter=1, jaccard is 1/nb, so a 2-token ext title scores
      # 0.5 and is now missed. That is the correct trade here -- this predicate drives
      # EXTENSION-RETIRE-CANDIDATE, which proposes DELETION, and a loose title match is
      # worse than no title match (see above).
      exit (inter / u >= 0.6 || (smaller >= 2 && inter / smaller >= 0.75)) ? 0 : 1
    }'
}

# Extract the section named by <id> from a markdown stream on stdin.
# Prints nothing (rc 1) if no heading matches.  Defined in lib.sh — one resolver.

# ---------------------------------------------------------------------------
# Overrides
# ---------------------------------------------------------------------------
while IFS= read -r f; do
  [ -n "$f" ] || continue
  entry="$(rel "$f")"
  shadows="$(fm "$f" shadows)"; base_sha="$(fm "$f" base_sha)"
  tgt="$(printf '%s' "${shadows%%#*}" | tr -d ' ' | sed 's/,.*//')"
  [ -n "$tgt" ] || { emit OVERRIDE-ANCHOR-UNRESOLVED "$entry" "?" "no shadows: target"; continue; }
  cp="$(dist_path "$tgt")"

  # base_sha provenance — fail LOUD, never skip (this is the whole point).
  if [ -z "$base_sha" ]; then
    emit HARD-OVERRIDE-BASE-UNRESOLVABLE "$entry" "$tgt" "no base_sha in frontmatter"; continue
  fi
  if ! git -C "$DIST" rev-parse -q --verify "${base_sha}^{commit}" >/dev/null 2>&1; then
    if git -C "$CONSUMER" rev-parse -q --verify "${base_sha}^{commit}" >/dev/null 2>&1; then
      subj="$(git -C "$CONSUMER" log -1 --format='%s' "$base_sha" 2>/dev/null | cut -c1-40)"
      emit HARD-OVERRIDE-BASE-CONSUMER-SHA "$entry" "$tgt" "base_sha $base_sha is a CONSUMER commit (${subj}); must be a distribution sha"
    else
      emit HARD-OVERRIDE-BASE-UNRESOLVABLE "$entry" "$tgt" "base_sha $base_sha resolves in neither repo"
    fi
    continue
  fi

  # The fourth separately-asked question, and the only one whose answer is DELETE THIS ENTRY.
  # Every other status asks whether the override is still correct. This asks whether it is still
  # NEEDED -- core may since have provided the thing the entry was written to work around. The
  # pull could not previously tell the difference: a superseded override presents as ordinary
  # section drift, which reads as "re-adopt the new wording", not "you can retire this". So the
  # entry survives, and because an override replaces its whole section it goes on freezing every
  # unrelated line in that span at its base_sha. That is how v0.268.0's Check 14 fix failed to
  # reach the reference consumer. The declaration lives in core's layer-contract.yaml; matching
  # is on the SAME normalised shadows: key the double-shadow arm uses, so a spelling difference
  # cannot hide a supersession.
  sup_env=""; sup_since=""; sup_reason=""
  while IFS="$TAB" read -r s_shadows s_since s_env; do
    [ -n "$s_shadows" ] || continue
    [ "$(norm "$s_shadows")" = "$(norm "$shadows")" ] || continue
    sup_env="$s_env"; sup_since="$s_since"; break
  done <<< "$(supersessions_of "$THEIRS")"
  [ -n "$sup_env" ] && emit OVERRIDE-SUPERSEDED "$entry" "$tgt" \
    "replaces_with=${sup_env} :: core ${sup_since} provides what this entry was written to work around, so it can be RETIRED rather than re-adopted: set ${sup_env} in .claude/settings.json (see override_supersessions in layer-contract.yaml for how to derive its value) and run readopt-override.sh --stamp retire. Retiring it also releases every unrelated line this entry froze at its base_sha -- an override replaces its WHOLE section, so those lines stop shadowing away later core fixes. Report-only: the operator decides, and a consumer that still wants the shadow for its own reasons keeps it."

  have "$THEIRS" "$cp" || { emit OVERRIDE-ANCHOR-UNRESOLVED "$entry" "$tgt" "target absent at $THEIRS"; continue; }

  file_changed=no
  if ! git -C "$DIST" diff --quiet "$base_sha" "$THEIRS" -- "$cp" 2>/dev/null; then file_changed=yes; fi

  # Evaluate every (file, anchor) pair in a possibly multi-anchor `shadows:` value.
  #
  # THE FILE IS NOW PER PAIR. This read ONE file for the whole entry — part one's — and checked
  # every harvested anchor against it, so `a.md#One, b.md#Two` resolved `Two` inside `a.md`.
  # Latent only because no live entry names two files. `shadow_parts` is the one reading of
  # `shadows:`, byte-identical to the authoring linter's under I40, and it also supplies the
  # file-inheriting spelling (`a.md#One, #Two`) that the linter was skipping until v0.191.0.
  #
  # `tgt`/`cp`/`file_changed` above stay as the ENTRY-level values: they are what the emitted
  # row's third column has always named, and what the base_sha provenance arm resolved against.
  pairs="$(shadow_parts "$shadows")"
  [ -n "$pairs" ] || pairs="$(printf '%s\t' "$tgt")"

  # A multi-anchor override must report EVERY affected anchor, not just the last
  # one examined. Accumulate per category and compose the detail after the loop:
  # a single-section message on an override shadowing eight sections invites the
  # operator to reconcile that one and silently drop the rest.
  worst=OVERRIDE-OK
  drifted=""; unprovable=""; unresolved=""; whole_file=""; delegated=""; loose=""
  ov_ticks="$(body_of "$f" | ticks_of)"
  while IFS= read -r pair; do
    [ -n "$pair" ] || continue
    # Split by parameter expansion: a tab is IFS WHITESPACE, so `IFS=<tab> read a b` absorbs a
    # leading one and a target-less part arrives as a target named after its own anchor.
    a_tgt="${pair%%"$TAB"*}"; id="${pair#*"$TAB"}"
    if [ -z "$a_tgt" ]; then
      [ "$worst" = OVERRIDE-OK ] && worst=OVERRIDE-ANCHOR-UNRESOLVED
      unresolved="${unresolved:+$unresolved, }#${id} (no target file: no earlier comma-part names one)"
      continue
    fi
    a_cp="$(dist_path "$a_tgt")"
    if ! have "$THEIRS" "$a_cp"; then
      [ "$worst" = OVERRIDE-OK ] && worst=OVERRIDE-ANCHOR-UNRESOLVED
      unresolved="${unresolved:+$unresolved, }#${id} (${a_tgt} absent at theirs)"
      continue
    fi
    a_changed=no
    git -C "$DIST" diff --quiet "$base_sha" "$THEIRS" -- "$a_cp" 2>/dev/null || a_changed=yes

    # Record the (file, anchor) key for the cross-entry duplicate check below. Normalised on
    # both halves, because `#4a. Close-Out Sweep` and `#4a Close-Out sweep` are one anchor to
    # the resolver and must be one key here or the collision hides behind its own spelling.
    shadow_keys="${shadow_keys}$(norm "$a_tgt")|$(norm "$id")${TAB}${entry}${TAB}${a_tgt}${id:+#$id}
"

    if [ -z "$id" ]; then
      [ "$a_changed" = yes ] && { worst=OVERRIDE-DRIFT-FILE; whole_file="yes"; }
      continue
    fi

    # HERE-STRING, NOT A PIPE, and the blob read ONCE. `anchor_arm` exits its awk program the
    # moment it finds a forward match, which closes the pipe under a still-writing `git show`
    # and printed a `write error: Broken pipe` per anchor to stderr — noise on a classifier
    # whose stderr an operator is meant to read. It also re-ran `git show` three times per
    # anchor on a 200+ line file.
    a_text="$(git_show "$THEIRS" "$a_cp")"

    # LOOSE ANCHOR — resolves only by the REVERSE arm of the containment match, so it silently
    # widens the shadow to the whole section. The authoring linter errors on this (E7); the
    # authoring linter is consumer-run and skippable, and the pull is not.
    arm="$(anchor_arm "$id" <<< "$a_text")"
    case "$arm" in
      REVERSE:*) loose="${loose:+$loose; }#${id} -> '${arm#REVERSE:}'" ;;
    esac

    s_theirs="$(section_of "$id" <<< "$a_text")"

    # Does this override delegate INTO the section it replaces?  See the status
    # note in the header.  `s_theirs` is the exact text the override displaces, so
    # a construct named in a heading there is one the lead can no longer reach.
    # Line 1 is the anchor heading itself and is dropped: an override naming the
    # section it overrides is not a delegation, and leaving it in reported every
    # entry whose anchor carries a backticked term (measured: 1 of 13, the sole
    # false positive, and it went to zero when the heading was excluded).
    if [ -n "$s_theirs" ] && [ -n "$ov_ticks" ]; then
      inner="$(printf '%s\n' "$s_theirs" | awk 'NR>1 && /^#{2,6}[ \t]/' | ticks_of)"
      if [ -n "$inner" ]; then
        both="$(comm -12 <(printf '%s\n' "$ov_ticks") <(printf '%s\n' "$inner") | tr '\n' ' ')"
        both="${both% }"
        [ -n "$both" ] && delegated="${delegated:+$delegated; }#${id} -> ${both}"
      fi
    fi
    if [ -z "$s_theirs" ]; then
      if [ "$a_changed" = yes ]; then
        [ "$worst" = HARD-OVERRIDE-DRIFT-SECTION ] || worst=OVERRIDE-DRIFT-FILE
        unprovable="${unprovable:+$unprovable, }#$id"
      else
        [ "$worst" = OVERRIDE-OK ] && worst=OVERRIDE-ANCHOR-UNRESOLVED
        unresolved="${unresolved:+$unresolved, }#$id"
      fi
      continue
    fi
    s_base="$(git_show "$base_sha" "$a_cp" | section_of "$id")"
    if [ "$s_base" != "$s_theirs" ]; then
      worst=HARD-OVERRIDE-DRIFT-SECTION
      drifted="${drifted:+$drifted, }#$id"
    fi
  done <<< "$pairs"

  # `emit` writes one tab-separated line, so the detail stays on one line.
  n_of() { printf '%s' "$1" | awk -F', ' '{print NF}'; }
  detail=""
  [ -n "$whole_file" ] && detail="whole-file shadow; file changed"
  if [ -n "$drifted" ]; then
    detail="${detail:+$detail; }$(n_of "$drifted") shadowed section(s) changed ${base_sha}..${THEIRS}: ${drifted}"
  fi
  if [ -n "$unprovable" ]; then
    detail="${detail:+$detail; }$(n_of "$unprovable") anchor(s) not a locatable heading in theirs; file changed -> cannot prove section safe: ${unprovable}"
  fi
  if [ -n "$unresolved" ]; then
    detail="${detail:+$detail; }$(n_of "$unresolved") anchor(s) not found in theirs: ${unresolved}"
  fi
  [ -n "$detail" ] || detail="shadowed section(s) unchanged"
  emit "$worst" "$entry" "$tgt" "$detail"

  # Reported SEPARATELY from `worst`, never folded into it: this is a different
  # question. `worst` asks whether the shadowed section moved upstream; this asks
  # whether the override's own body can still reach what it points at. An entry can
  # be OVERRIDE-OK on every anchor and still delegate into its own shadow -- both
  # of the real instances do exactly that.
  [ -n "$delegated" ] && emit OVERRIDE-DELEGATES-INTO-SHADOW "$entry" "$tgt" \
    "the body names construct(s) defined INSIDE the section(s) it replaces, so at load time (overrides > extensions > core) the delegation target is gone: ${delegated}. Every future upstream change to those constructs also fails to arrive here while every check stays green. Restate the construct in this override, narrow shadows: to the sub-headings actually rewritten, or delegate to something outside the shadowed span. Report-only -- delegating to a construct the lead is expected to open core for is sometimes deliberate."

  # The sibling question, asked separately for the same reason: `worst` asks whether upstream
  # moved, and this asks whether the override's own body describes its own effect truthfully.
  # An entry can be OVERRIDE-OK on every anchor and still assert that the span it deletes
  # survives -- both real instances do exactly that.
  if asserts_shadow_survives "$(body_of "$f")"; then
    emit OVERRIDE-ASSERTS-SHADOW-SURVIVES "$entry" "$tgt" \
      "the body asserts that the section(s) it shadows are unchanged and still govern. Precedence is overrides > extensions > core, so at load time this entry replaces the WHOLE shadowed span -- if the body rewrites one paragraph of it and states the rest still governs, that sentence is false about this entry's own effect, and the dropped text is exactly what nobody will look for. Narrow shadows: to the sub-heading actually rewritten, or restate the surviving text in this body. Report-only -- an override shadowing a sub-heading may be describing the surrounding PARENT section correctly."
  fi

  # The fifth separately-asked question: not whether upstream moved, but whether this entry's
  # own DECLARATION addresses what its author meant. E7 asks it at authoring time and errors;
  # that validator is consumer-run and skippable, and the pull is not.
  [ -n "$loose" ] && emit OVERRIDE-LOOSE-ANCHOR "$entry" "$tgt" \
    "anchor(s) that resolve only by the REVERSE arm of the containment match -- the anchor CONTAINS the heading rather than the heading containing the anchor: ${loose}. An anchor finer than a heading (a paragraph, a sub-clause, a renamed section) is not a grain the resolver can address, so it silently resolves to the WHOLE section instead: you believe you shadowed a narrower span and you have shadowed everything under that heading. Write the anchor as the heading named above, or narrow shadows: to the sub-headings actually rewritten. Report-only -- the resolution is unchanged and the entry still renders; what is wrong is what the operator believes it covers."
done < <(layer_files "$OVR_DIR")

# ---------------------------------------------------------------------------
# OVERRIDE-DOUBLE-SHADOW — two entries claiming one (file, anchor)
# ---------------------------------------------------------------------------
# Asked ACROSS entries, which is why it cannot live in the loop above: each entry is individually
# well-formed and only the pair is the finding. At load time both bodies claim the same span and
# precedence resolves it silently, so which one wins is an ordering accident nobody declared.
#
# It also multiplies drift: every commit touching that span invalidates BOTH entries' stamps, and
# an operator who reconciles one has reconciled half. Measured on the reference consumer, the one
# live collision is the largest shadowed span it has.
#
# Report-only, and the reason is on the record: the live collision is DELIBERATE and
# self-documented -- one of the two entries states in prose that it does not restate the other's
# body and names the file that does. An ERROR would fire on a case the consumer already reasoned
# about in writing.
if [ -n "$shadow_keys" ]; then
  # `sort -u` first: one entry declaring the same anchor twice is a different (and harmless)
  # shape, and counting it as a collision with itself would be a false positive nothing could act
  # on. The duplicate must be across two DIFFERENT entries.
  printf '%s' "$shadow_keys" | sort -u | awk -F'\t' '
    { if (k[$1]) { k[$1] = k[$1] ", " $2 } else { k[$1] = $2; lbl[$1] = $3 }; n[$1]++ }
    END { for (key in n) if (n[key] > 1) printf "%s\t%s\t%d\n", lbl[key], k[key], n[key] }
  ' | sort | while IFS="$TAB" read -r label entries cnt; do
    # One row PER PARTICIPATING ENTRY: the report is read per entry, and a single row filed under
    # one of the two leaves the other reading clean on the very finding it is half of.
    printf '%s\n' "$entries" | tr ',' '\n' | sed 's/^ *//' | while IFS= read -r one; do
      [ -n "$one" ] || continue
      emit OVERRIDE-DOUBLE-SHADOW "$one" "${label%%#*}" \
        "${cnt} override entries declare the same shadow target '${label}': ${entries}. At load time both bodies claim that span and precedence picks one silently, so which body governs is an ordering accident no entry declares. Every upstream commit touching the span also invalidates BOTH base_sha stamps, and reconciling one of them looks complete. Narrow one entry's shadows: to the sub-heading it actually rewrites, or merge the two. Report-only -- a deliberate split can be correct, but it has to be stated in the bodies."
    done
  done
fi

# ---------------------------------------------------------------------------
# Extensions
#
# The comparison base here is $BASE (the consumer's stamp commit — the last core
# it received), NOT any per-override base_sha. Unset that loop-local so a stale
# value can never leak in: reusing it silently made every hooked file look
# drifted, because a poisoned override sha does not resolve in the distribution.
# ---------------------------------------------------------------------------
unset base_sha
while IFS= read -r f; do
  [ -n "$f" ] || continue
  entry="$(rel "$f")"
  hooks="$(fm "$f" hooks | awk '{print $1}')"
  [ -n "$hooks" ] || { emit EXTENSION-HOOK-MISSING "$entry" "?" "no hooks: frontmatter"; continue; }
  cp="$(dist_path "$hooks")"

  have "$THEIRS" "$cp" || { emit EXTENSION-HOOK-MISSING "$entry" "$hooks" "hooks target absent at $THEIRS"; continue; }

  # A `fixtures:` binding is how a consumer check's adversarial fixture reaches core H1's
  # DERIVED set. The binding is the whole mechanism, so a binding that points at nothing is
  # H1 reporting coverage it does not have — the exact failure H1's own enumeration was
  # deleted to end, reintroduced one layer out. LEVEL-TRIGGERED, like ORPHANED-RELOCATED: it
  # is a state of the consumer tree, so a pull that changes nothing here must still report it.
  for fx in $(fm "$f" fixtures | tr ',' ' '); do
    [ -n "$fx" ] || continue
    case "$fx" in tests/fixtures/*) ;; *) fx="tests/fixtures/$fx" ;; esac
    [ -d "$CONSUMER/$fx" ] || emit EXTENSION-FIXTURE-UNBOUND "$entry" "$hooks" \
      "declares fixtures: $fx, which is not a directory in this consumer. H1 derives its coverage set from these bindings, so a dangling one reads exactly like coverage."
  done

  # Catalog reconciliation between this extension and the core file it hooks.
  #
  # The old rule tested ONE thing -- "is a section this extension defines NEWLY
  # defined upstream (present at theirs, absent at base)?" -- and reported nothing
  # otherwise. That is edge-triggered: it can only fire on the single pull that
  # lands an absorption, and never again. Miss that one report and the duplicate
  # rots forever, which is exactly what happened. A real consumer has carried the
  # SAME check as core since v0.13.0 (core says so in its own prose: "This is
  # graph's Check 21 absorbed as distribution Check 20") across ~35 minor versions
  # of pulls, and this tool said nothing on any of them, because by the time anyone
  # looked the section was no longer "new".
  #
  # Absorption is a STATE ("upstream now defines this section"), not an EVENT. So
  # test the state on every pull and use $BASE only to TAG the finding. And join on
  # BOTH axes, because the old number-keyed join was blind in both directions:
  #
  #   same number, same title   -> RESTATES-CORE / RETIRE-CANDIDATE (a duplicate)
  #   same number, diff  title  -> CHECK-NUMBER-COLLISION  (one integer, two checks)
  #   diff number, same title   -> absorbed-but-RENUMBERED (invisible to a number
  #                                join -- this is how the v0.13.0 duplicate hid)
  #   diff number, diff title   -> nothing; the catalogs are simply disjoint here
  ext_anchors="$(anchors_of_file "$f")"
  if [ -n "$ext_anchors" ]; then
    base_anchors="$(git_show "$BASE" "$cp" | anchors_of_stream)"
    theirs_blob="$(git_show "$THEIRS" "$cp")"
    theirs_anchors="$(printf '%s' "$theirs_blob" | anchors_of_stream)"

    while IFS= read -r a; do
      [ -n "$a" ] || continue
      t_ext="$(heading_text_for "$a" < "$f")"
      [ -n "$t_ext" ] || continue

      if grep -Fxq -- "$a" <<<"$theirs_anchors"; then
        # -- same NUMBER upstream. Title decides which defect this is.
        t_up="$(printf '%s' "$theirs_blob" | heading_text_for "$a")"
        if grep -Fxq -- "$a" <<<"$base_anchors"; then tag=PRE-EXISTING; else tag=NEW-THIS-PULL; fi

        if same_section "$t_ext" "$t_up"; then
          if [ "$tag" = NEW-THIS-PULL ]; then
            emit EXTENSION-RETIRE-CANDIDATE "$entry" "$hooks" \
              "NEW-THIS-PULL: upstream ${BASE}..${THEIRS} now defines '$a. $t_up', which this entry also defines — absorbed; retire the consumer copy"
          else
            emit EXTENSION-RESTATES-CORE "$entry" "$hooks" \
              "PRE-EXISTING: defines '$a. $t_ext', which core already defines at the SAME number and title — and did so at base, so the absorption signal never fired. Rule 27(c): an extension MUST NOT restate a core section; the copy cannot drift-check against the original, so it forks silently. If it only duplicates core, retire it; if it hardens or restricts core, refile it in overrides/ with a base_sha so drift is tracked."
          fi
          continue
        fi

        # A labelled heading is the RESOLVED state. Reporting it anyway means the
        # remedy this very message prescribes can never silence the message.
        if [ "$(heading_labelled_for "$a" < "$f")" = yes ]; then
          continue
        fi

        emit EXTENSION-CHECK-NUMBER-COLLISION "$entry" "$hooks" \
          "${tag}: '$a' names TWO different checks — here \"$t_ext\", in core \"$t_up\". Extensions are ADDITIVE, so both render into ONE merged list under ONE integer: the bare \"Check $a\" the lead writes into the gate log has no referent. Label the catalogs at the point of use (core \"### $a. [core] …\" vs this entry \"### $a. [ext:<id>] …\") and never attribute fire history across catalogs by number."
        # NO `continue` here. A number collision does NOT mean upstream lacks this
        # CHECK -- it may carry it under a DIFFERENT number, and then the entry is
        # both a collision and a duplicate. That is not hypothetical: a consumer's
        # push check 21 collides with core's 21 (test-strategy presence) AND *is*
        # core's 20 (validation-intensity), which core's own prose records as
        # "graph's Check 21 absorbed as distribution Check 20". Returning early here
        # would report the collision and silently drop the absorption -- the single
        # most important fact about that entry. Fall through to the title search.
      fi

      # -- is the same CHECK upstream under a DIFFERENT number?
      while IFS= read -r b; do
        [ "$b" = "$a" ] && continue
        [ -n "$b" ] || continue
        t_up="$(printf '%s' "$theirs_blob" | heading_text_for "$b")"
        same_section "$t_ext" "$t_up" || continue
        if grep -Fxq -- "$b" <<<"$base_anchors"; then
          emit EXTENSION-RESTATES-CORE "$entry" "$hooks" \
            "PRE-EXISTING (renumbered): this entry's '$a. $t_ext' IS core's '$b. $t_up'. Upstream absorbed it under a DIFFERENT number, so a number-keyed retirement signal could never fire and the duplicate has been carried silently ever since. Retire it, or refile as an override if it hardens core."
        else
          emit EXTENSION-RETIRE-CANDIDATE "$entry" "$hooks" \
            "NEW-THIS-PULL (renumbered): upstream now defines this entry's '$a. $t_ext' as core '$b' — absorbed under a different number; retire the consumer copy"
        fi
        break
      done <<< "$theirs_anchors"
    done <<< "$ext_anchors"
  fi

  # --- drift, at whichever grain the entry declared --------------------------
  #
  # An entry that declares only `hooks:` has a FILE as its drift subject, so any
  # change anywhere in that file lands on the operator's re-read worklist. That is
  # not a conservative default, it is a loud one: measured over the reference
  # consumer's 33 entries and the full history of the 17 core files they hook,
  # file grain produces 1421 (entry, commit) drift events against an expected 133
  # at anchor grain. Nine of every ten re-reads are a change to a part of the file
  # the entry never referred to, and a worklist that is 91% noise is one the
  # operator learns to clear rather than read.
  #
  # `extends:` is the consumer's declaration of the finer subject, so when it is
  # present the comparison is the ANCHOR'S SPAN rather than the file.
  #
  # THE NARROWING MUST NOT BE ABLE TO INVENT SILENCE. Narrowing a check is how a
  # loud true report becomes a quiet false one: if the anchor stops resolving
  # upstream — core renamed the heading, or absorbed the section away — then a
  # span-vs-span comparison has nothing to compare and the natural failure is to
  # report clean. That is this repo's named defect class arriving through the door
  # marked "improvement". So a span that does not resolve at THEIRS is its own
  # LOUD status, and it is deliberately not folded into EXTENSION-OK.
  #
  # `shadow_parts` and `section_of` are lib.sh's, byte-identical to the authoring
  # linter's under I40 — the linter's E11 and this arm must agree about which span
  # an entry declares, or whichever the operator did not run is the one that is
  # wrong.
  extends="$(unquote "$(fm "$f" extends)")"
  ext_anc=""
  if [ -n "$extends" ]; then
    ext_line="$(shadow_parts "$extends" | head -1)"
    ext_file="$(printf '%s' "$ext_line" | cut -f1)"
    ext_anc="$(printf '%s' "$ext_line" | cut -f2)"
    [ -n "$ext_file" ] || ext_file="$hooks"
    # A mismatch is E11's ERROR at authoring time. Here it only means the anchor
    # names a file this loop is not looking at, so narrowing would watch the wrong
    # span: fall back to file grain rather than report on a span nothing declared.
    [ "$ext_file" = "$hooks" ] || ext_anc=""
  fi

  if git -C "$DIST" diff --quiet "$BASE" "$THEIRS" -- "$cp" 2>/dev/null; then
    emit EXTENSION-OK "$entry" "$hooks" "hooked core file unchanged"
  elif [ -n "$ext_anc" ]; then
    ext_new="$(git_show "$THEIRS" "$cp" | section_of "$ext_anc")"
    if [ -z "$ext_new" ]; then
      emit EXTENSION-ANCHOR-MISSING "$entry" "$hooks" \
        "declares extends: '${ext_anc}', which resolves to NO heading in '$hooks' at ${THEIRS}. Upstream renamed or removed the section this entry augments, so there is no longer a span to narrow drift to — and an anchor that resolves to nothing would otherwise compare empty against empty and report clean forever. Re-anchor extends: to the heading that replaced it, or retire the entry if the section was absorbed away."
    else
      ext_old="$(git_show "$BASE" "$cp" | section_of "$ext_anc")"
      if [ "$ext_old" = "$ext_new" ]; then
        emit EXTENSION-OK "$entry" "$hooks" "hooked core file changed ${BASE}..${THEIRS} but the declared extends: span '${ext_anc}' did not"
      else
        emit EXTENSION-ANCHOR-DRIFT "$entry" "$hooks" \
          "the declared extends: span '${ext_anc}' in '$hooks' changed ${BASE}..${THEIRS} — re-read this entry against the new core text for that section. This is the file-grain re-read narrowed to the span the entry actually declared; everything else that moved in this file is not this entry's business."
      fi
    fi
  else
    emit EXTENSION-HOOK-DRIFT "$entry" "$hooks" "hooked core file changed ${BASE}..${THEIRS} — this entry declares no extends: anchor, so its drift subject is the whole file; re-read it against the new core text"
  fi
done < <(layer_files "$EXT_DIR")
