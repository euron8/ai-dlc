#!/usr/bin/env bash
# validate-spec-join.sh — the spec traceability joins
#
# Usage: ./scripts/ai-dlc/validate-spec-join.sh --spec DIR --prd FILE [--story FILE]...
#                                              [--spine-lint JSON] [--trace-verdict FILE]
#
# Gate-validation Check 30 enforcer (story gates).
#
# WHAT IT GUARDS. The chain from operator intent to a test is
#
#   LOCKED_REQUIREMENTS -> CAP-N -> FR-<n> -> story AC -> test
#
# and until now its middle joins were hand-typed prose. A PRD carries
# `FR-S290-1 (<- LR-S290-1)`; the arrow is a character, not a join, and nothing
# reads it. Two failures follow, both silent:
#
#   - A requirement reaches no capability. Observed: a locked requirement dropped
#     during an ADR pivot with no SUPERSEDED disposition — it simply stopped being
#     mentioned, and every artifact downstream stayed internally consistent.
#   - A definition is re-transcribed instead of cited. Observed: a roster of
#     always-on safety pollers restated per-story, at 5, 6 and 4 members in three
#     places, because no story pointed at one canonical definition.
#
# BMAD supplies the stable IDs this needs and does not join them: `bmad-spec`
# guarantees `CAP-N` is never reused or renumbered, `bmad-architecture` gives
# `AD-n`, and `bmad-create-epics-and-stories` emits an `FR Coverage Map`. What
# none of them does is FAIL. This is the caller that decides.
#
# THE JOINS, all ID-mechanical:
#   (1) every LOCKED_REQUIREMENTS bullet in the spec's memlog maps to >=1 CAP-N
#   (2) every CAP-N in SPEC.md is cited by a functional-requirement entry in prd.md
#       -- NOT in BMAD's FR Coverage Map, whose content propagates whatever FR label
#       the PRD used and is therefore a derived surface, not an independent one
#  (2a) every CAP-N is bound by an architecture decision (`- **Binds:**` in the spine)
#   (3) every `capabilities:` entry in a story frontmatter resolves to a CAP-N
#       that SPEC.md defines
#
# ANCHOR ON THE MEMLOG, NOT SPEC.md. `bmad-spec` is the single writer of SPEC.md
# and re-derives it from `.memlog.md` on every run: "a hand-edit to SPEC.md from
# outside is unsupported and is overwritten on the next derive." A byte anchor into
# a re-rendered file holds until the next derive and then reports a drift that never
# happened. `.memlog.md` is append-only and never reordered, so requirement text is
# anchored there.
#
# TWO BORROWED VERDICTS, EACH READ FROM A NAMED KEY. `--spine-lint` takes
# `lint_spine.py`'s JSON, which always exits 0 by design and lets the caller decide;
# severity comes from its own `severity` field (any `high` fails, `low` records), never
# from a hand-list of category names -- it has four, and the two an earlier version
# listed omitted `ad_id`, which is the ID-stability failure every join here rests on.
# `--trace-verdict` takes `bmad-testarch-trace`'s `gate-decision.json` and reads
# `gate_status`; the same file carries `p0_status`, `p1_status` and a prose `rationale`,
# so a whole-file grep for FAIL fails a gate the tool passed. Both are OPT-IN FLAGS:
# whether they ran is the gate's evidence question, not something this script can infer.
#
# EXIT CODES
#   0  -- every join closes
#   1  -- an orphan or a dangling reference
#   2  -- DISARMED or usage error: a required input is unreadable, or SPEC.md
#         defines ZERO capabilities. A zero-capability spec closes every join
#         vacuously and prints the same line as a spec that closes them for real.

set -u

PROG="validate-spec-join.sh"
SPEC=""; PRD=""; SPINE=""; SPINE_MD=""; TRACE=""; BASELINE=""
STORIES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --spec)          SPEC="${2:-}"; shift 2 || exit 2 ;;
    --prd)           PRD="${2:-}";  shift 2 || exit 2 ;;
    --story)         STORIES+=("${2:-}"); shift 2 || exit 2 ;;
    --spine)         SPINE_MD="${2:-}"; shift 2 || exit 2 ;;
    --spine-lint)    SPINE="${2:-}"; shift 2 || exit 2 ;;
    --trace-verdict) TRACE="${2:-}"; shift 2 || exit 2 ;;
    --baseline)      BASELINE="${2:-}"; shift 2 || exit 2 ;;
    -h|--help) echo "usage: $PROG --spec DIR --prd FILE [--story FILE]... [--spine FILE] [--spine-lint JSON] [--trace-verdict FILE] [--baseline FILE]" >&2; exit 2 ;;
    *) echo "$PROG: unexpected argument '$1'" >&2; exit 2 ;;
  esac
done

# --- the baseline, and the arm that stops it outliving its cause ---------------
# A CORRECTED CHECK THAT BLOCKS ON DEBT IT DID NOT CREATE GETS TURNED OFF. Adopting
# this check against an existing corpus means inheriting whatever orphans the chain
# already has -- 15 in the reference consumer (5 LR->CAP, 10 CAP->FR), none of them
# caused by adopting the check. `--baseline` names them so the gate reports them
# without blocking on them.
#
# THE SECOND ARM IS WHY THIS IS NOT A MUTE BUTTON. A baseline entry that does NOT
# reproduce is itself a FAIL. Without that, a baseline written once outlives the
# thing it excused: the orphan gets fixed, the entry stays, and the next real
# instance of the same id is silently suppressed by a line whose cause is gone. The
# entry must be deleted when the failure it names is, and this is what forces it.
#
# KEYS ARE NAMESPACED because two joins key on the same identifier -- join (2) and
# join (2a) both fail per CAP-<n>, so a bare `CAP-1` would suppress a capability
# missing its FR *and* the same capability missing its AD, on one line.
#
#   lr:<LR-id>        join (1)  requirement reaches no capability
#   fr:<CAP-id>       join (2)  capability cited by no functional requirement
#   ad:<CAP-id>       join (2a) capability bound by no architecture decision
#   no-ad:<CAP-id>    join (2a) a No-AD disposition for an id the kernel does not define
#   no-ad-form:<spine-basename>
#                     join (2a) a No-AD bullet this reader cannot parse
#
#   no-ad-stale:<CAP-id>
#                     join (2a) a No-AD disposition an AD has since overtaken
#
# EVERY No-AD ARM IS KEYED, AND AN EARLIER VERSION OF THIS COMMENT ARGUED THE OPPOSITE.
# The argument was that a staleness report is META -- it says a suppression is invalid --
# so muting it would restore the inner suppression to silence. That reasoning is sound in
# general and WRONG HERE, because in every state these arms report, THE No-AD IS ALREADY
# INERT: a disposition for a capability an AD binds suppresses nothing (the binding
# carries it, and the loop never reaches the hatch), one for an id the kernel does not
# define suppresses nothing, and a malformed bullet disposes nothing. There is no live
# suppression for a baseline to hide behind, so the general argument does not apply and
# the arms are ordinary primary findings.
#
# THAT MATTERS BEYOND TIDINESS. Measured by the adversarial pass: a stray No-AD bullet in
# a rejected-drafts appendix is BIDIRECTIONAL where a stray `- **Binds:**` is not -- it can
# BLOCK a spine that is fully and correctly bound, and while the staleness arm had no key
# there was no disposition for that at all, with supplying the neighbouring keys making the
# run strictly worse. Keying it is what stops an unfenced example from wedging a correct
# spine with no way out.
#
# The did-not-reproduce arm at the foot of this script is still unkeyed, and that one IS
# the meta case: it reports that a BASELINE LINE is stale, and muting it would be muting
# the expiry of a live suppression.
#   story:<basename>  join (3)  story `capabilities:` FIELD -- absent, or empty and unexplained
#   story-cap:<basename>:<CAP-id>
#                     join (3)  one story citation that resolves to no capability
#
# THE TWO story KEYS ARE SEPARATE ON PURPOSE. A file-level `story:<basename>` covering
# both would let one baseline line excuse a missing field AND every dangling citation in
# the same file, which is the coarse-key failure the namespacing above exists to prevent.
#
# THE BORROWED VERDICTS ARE NOT BASELINEABLE. `lint_spine.py` and
# `bmad-testarch-trace` publish their own findings with no stable per-item key here,
# and suppressing another tool's verdict from this side would be adopting a
# self-declared pass by omission.
BASELINE_KEYS=""
BASELINE_HIT=""
if [ -n "$BASELINE" ]; then
  [ -f "$BASELINE" ] || { echo "$PROG: DISARMED — --baseline names an unreadable file: $BASELINE. An unreadable baseline is not an empty one; exiting rather than reporting every baselined failure as new." >&2; exit 2; }
  BASELINE_KEYS="$(sed 's/#.*//; s/^[[:space:]]*//; s/[[:space:]]*$//' "$BASELINE" | grep -v '^$' || true)"
fi

# fail_join <namespaced-key> <message>
#   Emits FAIL and sets rc, unless the key is baselined -- in which case it records
#   the hit so the did-not-reproduce arm below can tell a live baseline from a stale one.
fail_join() {
  local key="$1" msg="$2"
  if [ -n "$BASELINE_KEYS" ] && grep -qxF -- "$key" <<<"$BASELINE_KEYS"; then
    echo "  BASELINED  $key — pre-existing, suppressed by $BASELINE (still reproducing)"
    BASELINE_HIT="${BASELINE_HIT}${key}
"
    return
  fi
  echo "FAIL: $msg" >&2
  rc=1
}

# no_ad_ids <bullet>
#   The DISPOSED IDS of a `- **No-AD:**` bullet: the segment BEFORE `REASON:`, and only
#   that.
#
#   THE WHOLE BULLET IS THE WRONG POPULATION, MEASURED ON THIS ARM BEFORE IT SHIPPED. A
#   reason is prose and prose names other capabilities -- "unlike CAP-1, which AD-1
#   binds" -- and reading ids out of it fails in BOTH directions at once. A bound id
#   quoted in a reason was reported as a stale disposition, a hard FAIL with no baseline
#   to disposition it. An unbound id quoted in a reason was silently EXCUSED by a bullet
#   that never disposed it, which is the same silent exemption this whole check exists to
#   prevent, reintroduced by its own escape hatch.
#
#   A bullet with no `REASON:` disposes nothing: it fails the excuse predicate, so the
#   capability it names still FAILs loudly, and it contributes no ids here.
# is_reason <text>
#   A REASON is text a person wrote, not the placeholder this script's own FAIL messages
#   print. Both hatches told the author to write `<reason>` / `<why>` into the file, and
#   both then ACCEPTED that literal back -- a one-character predicate satisfied by the
#   instruction that produced it. An angle-bracket placeholder alone is rejected; so is a
#   lone punctuation mark.
is_reason() {
  local r
  r="$(printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  # STRIP MARKDOWN WRAPPERS FIRST. A placeholder in a spec is normally written in a code
  # span or emphasis, and the bare `<...>` test caught only the unwrapped form -- so
  # `` `<why>` ``, `**<reason>**` and `_<why>_` all passed while the identical text
  # unwrapped was rejected.
  while :; do
    case "$r" in
      '`'*'`'|'**'*'**'|'__'*'__'|'*'*'*'|'_'*'_')
        r="$(printf '%s' "$r" | sed 's/^[`*_][`*_]*//; s/[`*_][`*_]*$//; s/^[[:space:]]*//; s/[[:space:]]*$//')" ;;
      # BRACKETS ARE STRIPPED AND THEN TESTED, NOT REJECTED WHOLESALE. Rejecting on the
      # WRAPPER made `(it extends the ladder)` -- a real justification that happens to be
      # written entirely in parentheses -- a hard failure on the No-AD hatch, whatever it
      # said. Emphasis was already handled this way; brackets were not, and the blanket
      # reject was introduced by the fix for the placeholder families. `(<why>)` still
      # rejects, because the `<...>` test runs on the CONTENT.
      '('*')'|'['*']'|'{'*'}')
        r="$(printf '%s' "$r" | sed 's/^.//; s/.$//; s/^[[:space:]]*//; s/[[:space:]]*$//')" ;;
      *) break ;;
    esac
  done
  case "$r" in ''|'<'*'>') return 1 ;; esac
  # A PLACEHOLDER WORD IS NOT A REASON EITHER. These are what an author writes when they
  # intend to come back, and the whole point of the reason is that somebody already
  # decided.
  case "$(printf '%s' "$r" | tr 'A-Z' 'a-z')" in
    todo|tbd|tba|fixme|xxx|'n/a'|na|none|pending|'?') return 1 ;;
    # The bracket stripping above EXPOSES these: `[reason]` and `{why}` reduce to the bare
    # placeholder word, which is the same non-reason the angle-bracket form is. As the
    # WHOLE trimmed string only -- a reason that merely contains the word is untouched.
    reason|why|rationale|explanation|justification|reasons) return 1 ;;
  esac
  grep -qE '[A-Za-z0-9]{2,}' <<<"$r"
}

no_ad_ids() {
  case "$1" in *REASON:*) ;; *) return ;; esac
  is_reason "${1#*REASON:}" || return
  no_ad_id_segment_ok "$1" || return
  printf '%s\n' "${1%%REASON:*}" | grep -ohE "$CAP_GRAMMAR" || true
}

# no_ad_id_segment_ok <bullet>
#   The segment before `REASON:` must BE an id list: CAP ids, separators, and nothing
#   else.
#
#   READING IDS OUT OF A SEGMENT THAT IS ALSO PROSE FAILS IN BOTH DIRECTIONS, and once the
#   lifetime arm exists the wrong direction is a HARD, UNBASELINEABLE FAIL on a correct
#   spine. Measured: `- **No-AD:** CAP-2, CAP-3 (unlike CAP-1, which AD-1 binds) — REASON:
#   ...` is a correct bullet -- CAP-1 is correctly bound and correctly not disposed -- and
#   it wedged the gate with a message telling the author to delete an id from a
#   parenthetical, which is the most natural way to write "these two, unlike that one".
#   Folded context lines before the `REASON:` did the same thing, so the more thoroughly a
#   decision was explained the likelier it failed. It also gave the English plural a second
#   emission site, in spine prose, where the kernel's residue arm cannot reach.
#
#   A PARTITION, NOT A HEURISTIC. Rather than guess which ids in a mixed segment are
#   disposed, the mixed segment is REFUSED: commentary belongs after `REASON:`, where the
#   grammar already says prose lives, and the diagnostic says exactly that. This is the
#   only new hard edge in the hatch, so it is baselineable -- see the arm that reports it.
no_ad_id_segment_ok() {
  local seg
  # BRE, NOT ERE, AND `\b` IS NOT BRE. Passing $CAP_GRAMMAR to sed here matched NOTHING --
  # silently, leaving every id in the segment and failing every well-formed bullet. The
  # token pattern is spelled out in BRE rather than reusing the ERE grammar, and the two
  # are held together by the arm that requires a canonical bullet to PASS.
  seg="$(printf '%s\n' "${1%%REASON:*}" | sed -e 's/^[[:space:]]*[-*][[:space:]]*\*\*No-AD:\*\*//' -e 's/CAP-[0-9][0-9]*[a-z]*//g')"
  ! grep -qE '[A-Za-z0-9]' <<<"$seg"
}

# no_ad_bullet_for <cap>
#   The first No-AD bullet that DISPOSES <cap> -- named in its id segment, with a reason.
no_ad_bullet_for() {
  local c="$1" line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if no_ad_ids "$line" | grep -qx -- "$c"; then printf '%s\n' "$line"; return 0; fi
  done <<<"$NO_AD"
  return 1
}

[ -n "$SPEC" ] && [ -d "$SPEC" ] || { echo "$PROG: DISARMED — --spec must name the spec folder (holding SPEC.md and .memlog.md); got '${SPEC:-<none>}'." >&2; exit 2; }
KERNEL="$SPEC/SPEC.md"
MEMLOG="$SPEC/.memlog.md"
[ -f "$KERNEL" ] || { echo "$PROG: DISARMED — no SPEC.md in $SPEC. Run bmad-spec before this gate; a missing kernel is not an empty one." >&2; exit 2; }
[ -f "$MEMLOG" ] || { echo "$PROG: DISARMED — no .memlog.md in $SPEC. The memlog is the append-only decision-of-record and the anchor surface for requirement text; without it join (1) cannot be checked at all." >&2; exit 2; }
[ -n "$PRD" ] && [ -f "$PRD" ] || { echo "$PROG: DISARMED — --prd must name a readable PRD; got '${PRD:-<none>}'." >&2; exit 2; }

# Capabilities the kernel defines.
#
# THE SUFFIXED FORM IS THE PRODUCER'S GRAMMAR, NOT A TYPO. `bmad-spec` guarantees
# CAP-<n> is never reused or renumbered, so a capability inserted between two existing
# ones is spelled `CAP-1a` -- the alphabetic suffix IS the mechanism that keeps the
# promise every join here rests on. `\bCAP-[0-9]+\b` cannot match it: `a` is a word
# character, so the trailing boundary fails and the id leaves the capability set in
# SILENCE. Measured on a real kernel defining `CAP-1a` in full, with intent, an EARS
# success criterion and a note: extracted 0 times by the old expression, present 2 times.
#
# THE DROP DOES NOT SURFACE AS A MISSING CAPABILITY. IT SURFACES AS AN ACCUSATION
# AGAINST THE AUTHOR. Join (3) reads a story citing `CAP-1a`, finds no such id in CAPS,
# and reports the STORY as citing an id "that does not exist ... a typo or a stale
# reference" -- high confidence, about someone's work, while the id sits defined in the
# kernel. Meanwhile the unparsed capability is exempt from joins (1), (2) and (2a): no FR
# is required to cite it, no AD is required to bind it, and the summary prints as though
# coverage were complete. A parser that cannot spell an id does not report a gap. It
# reports the wrong party and stops looking.
#
# THE RESIDUE ARM IS WHY THIS IS NOT ONE MORE SUFFIX SHAPE. Widening to `[a-z]?` fixes
# `CAP-1a` and leaves `CAP-1ab` failing identically and just as silently -- the same
# defect, one character further out, with nothing watching. So the accepted grammar is
# PARTITIONED against everything else that looks like a numbered CAP token: anything
# matching `CAP-<digit>...` that the accepted form does not match IN FULL disarms,
# loudly, rather than vanishing from the set. A grammar this check cannot represent is
# the producer's grammar having moved, which takes the same DISARM the memlog entry
# types already take. `CAP-<n>` and `CAP-N` in prose are not residue: the class requires
# a DIGIT after the hyphen, which is what separates a real id from a template token.
# THIS IS NOT A COMPLEMENT AND THE EARLIER CLAIM THAT IT WAS HAS BEEN DELETED, because a
# future author would have widened one side trusting it. Two gaps were demonstrated: any
# WORD CHARACTER before `CAP` defeats both expressions at once, since both open with `\b`
# (`_CAP-1a_` is markdown italics); and `\b`'s word set is LOCALE-dependent and includes
# accented letters, so `CAP-1é` fails the accepted grammar's closing `\b` while the
# residue class truncates it to a well-formed `CAP-1`. What closes the realistic half of
# that is not a wider class, it is the SHAPE arm below: a definition-shaped bullet whose
# id is wrapped in emphasis or code markers but not in the canonical `**CAP-<n>**` form is
# reported, whatever characters surround the id.
#
# THE SCAN IS KERNEL-SCOPED BY DESIGN, NOT BY ACCIDENT. It reads `$KERNEL` and nothing
# else. A consumer reported a `CAP-1ab` token sitting in its operator-history transcript,
# logged verbatim from a message discussing this very grammar -- so widening the scanned
# set past the kernel would DISARM the gate on a transcript quoting an example id. The
# kernel is the only file that DEFINES capabilities; every other mention is a citation,
# and a citation of an unparseable id already surfaces at the join that reads it.
#
# `sort -V` already orders `CAP-1 CAP-1a CAP-2` correctly, so the suffix costs nothing
# downstream, and the per-capability loops below match with an explicit non-id boundary
# class -- so `CAP-1` does not match `CAP-1a` and the two stay distinct ids.
# A CAPABILITY IS DECLARED BY ITS DEFINITION BULLET, NOT BY BEING MENTIONED. Reading
# CAP tokens out of the whole kernel is what made the widening dangerous in the other
# direction: `\bCAP-[0-9]+[a-z]?\b` matches the ENGLISH PLURAL. A kernel sentence reading
# "the CAP-1s and CAP-2s described above" minted two phantom capabilities, which then hard
# -blocked joins (2) and (2a) with an accusation about ids nobody defined -- and the
# residue partition below is structurally unable to see it, because `CAP-1s` is a
# well-formed id. The residue arm guards the UNDER-parsed direction; this scoping is what
# guards the OVER-parsed one. Under the OLD grammar the plural was invisible by accident,
# so the defect arrived with the fix.
#
# Only the BOLDED id is taken, never the description: `- **CAP-1** — supersedes CAP-2`
# defines CAP-1 and mentions CAP-2, and reading the whole bullet would define both.
# Measured on all five real kernels available: definition-bullet extraction and
# whole-file extraction return the IDENTICAL set, so this narrows the population without
# losing a capability -- and it also drops the prose mentions that made a fenced grammar
# example in a kernel able to DISARM the gate.
CAP_GRAMMAR='\bCAP-[0-9]+[a-z]?\b'
# FENCED BLOCKS ARE STRIPPED FIRST. A kernel that DOCUMENTS its own id grammar shows the
# definition shape in an example block, and a definition-shaped line inside a fence is an
# illustration, not a declaration. Without this the residue arm DISARMS the gate on a
# kernel for explaining itself -- a hard block, on correct content, with the remedy being
# to delete the documentation.
# THE MARKER SET IS DEFINED ONCE AND CONSUMED BY BOTH READERS.
#
# It was written twice -- the fold split on asterisk-pairs ONLY while the scan gate knew
# five markers -- and the two had already drifted, so a declaration that wrapped in
# italics, code, underscore-bold or single-asterisk was never folded and dropped its
# second id in silence. Four reconstructions, each with a one-line control that fires, so
# the wrap was the only variable. That is the same failure as the whitespace-class drift
# between the two capability guards, one level down and inside a single arm, where
# deleting an arm cannot fix it.
#
# THE DECLARATION RUN IS THE FIRST CAP-OPENING RUN, WITH ONE EXCEPTION THAT IS THE WHOLE
# DIFFICULTY. Taking the item FIRST run outright was wrong: any emphasis before the
# declaration diverted the reader and the declaration was never examined, so
# "- *(deprecated)* **CAP-3 and CAP-9 together**" dropped CAP-9 in silence -- three shapes,
# one line each, no fold involved. But taking the first CAP-OPENING run outright is also
# wrong, because "- **Note:** see `CAP-99` in the platform spec" has exactly that shape and
# CAP-99 is a CITATION of another spec, not a declaration.
#
# NO RULE KEYED ON POSITION ALONE SEPARATES THEM. What does is the run CONTENT: a citation
# is a BARE well-formed id, a declaration carries ids plus text. So a CAP-opening run is
# read as a declaration when it LEADS the item, or when its content is not a bare
# well-formed id -- and a run that is neither is walked PAST rather than ending the search.
#
# LEADING MEANS STARTING THE ITEM CONTENT, NOT MERELY BEING THE FIRST EMPHASIS RUN. That
# distinction is the whole difference: "- see `CAP-1` then **CAP-3 and CAP-9 together**"
# has a CITATION as its first run, and reading first-run as leading accepted that citation
# as the declaration, answered "nothing dropped", and stopped -- so the two-id declaration
# further along was never examined and its second id vanished. That is the shape every
# reconstruction of this defect has used, hidden behind an ordinary cross-reference. A run
# LEADS when everything before it on the item is list, quote or heading markers and space.
#
# A SECOND LIMIT, THIS ONE WITH A DISCRIMINATOR I FOUND AND DID NOT TAKE. A bolded phrase
# in an intent naming TWO OR MORE ids none of which this kernel declares --
# "- **CAP-3** -- unlike **CAP-99 and CAP-98**" -- is read as the declaration and beats the
# real one, DISARMING a correct kernel. It needs two undefined ids inside one emphasised
# phrase, so it is narrow, but the SHAPE is not hypothetical: the five real kernels carry 8
# bolded multi-id phrases between them. None fires today, because in every one of the 8 all
# the ids are declared.
#
# THE DISCRIMINATOR: a declaration that drops an id has MIXED membership -- the id it
# declared is in CAPS, the dropped one is not -- while a foreign citation phrase has every
# id absent. Gating the stronger-run rule on "leading OR mixed" separates this from every
# case above, INCLUDING the two-citations-then-declaration case that a simpler "an earlier
# declaration wins" rule loses.
#
# IT IS GATED BY A PARAMETER, AND THE REASON IS NOT ORDERING. An earlier version of this
# comment said the fold "runs before the capability set exists". That is FALSE and
# checkable -- CAPS is built long before KERNEL_ITEMS and derives from KERNEL_PROSE, so
# there is no circularity. The real obstacle is that the fold consumes the SELECTION, not
# just the helper: it folds while DECL_OPEN holds, so a membership-gated selection would
# change WHICH RUN the fold considers open, and a kernel edit adding a capability would
# alter the folding of an unrelated item. That nonlocal effect is what must not happen.
#
# So `strict` is a parameter: the fold passes 0 and keeps exactly its previous behaviour,
# the scan passes 1 and gains the membership gate. One function, one marker set, one
# selection algorithm. The divergence it buys is deliberate and is the correct one -- the
# FOLD HAS NO BUSINESS KNOWING ABOUT MEMBERSHIP, because folding is a question about text
# and membership is a question about the spec.
#
# THE LIMIT THIS RULE CANNOT ESCAPE, stated because it is irreducible rather than unfixed.
# A declaration carrying a short prefix and naming exactly ONE id -- "- *(deprecated)*
# **CAP-9** intent" -- is structurally identical to a citation: not the first run, content
# a bare well-formed id, id absent from CAPS. Same position class, same content class,
# same membership answer. No predicate over the text separates them, because the id is
# absent for two different reasons and the text does not record which. So the capability
# is dropped silently, and the discriminating control is not whether the arm FIRES but
# whether the id reaches the set -- the same line without the prefix is a canonical
# declaration and correctly triggers nothing.
#
# WHAT FORBIDS THE OBVIOUS WIDENING IS A MEASUREMENT, not a preference. Flagging every
# not-first bare CAP-opening run whose id is absent would fire on all 18 such items in the
# five real kernels, and all 18 are citations. Both directions were measured:
#   18 late-run bare-id items, of which 0 hold anything but a bare id  (the FP direction)
#   of those 18, 17 + 1 are IN their own kernel CAPS and 0 are ABSENT   (the MISS direction)
# The ambiguous class -- a not-first bare id absent from its kernel -- is EMPTY on the real
# corpus, so this limit has no live instance today. A seeded absent id is found by the same
# probe, which is what says the zero is a measurement rather than a broken scan.
#
# THE RESIDUAL IS NAMED RATHER THAN HIDDEN: "- **Note:** see `CAP-99 and CAP-98` upstream"
# -- a citation of TWO foreign ids in one code span after a non-declaration lead-in -- now
# DISARMS. It is taken deliberately: the alternative is a SILENT DROP, which is the failure
# this arm exists for, and a hard DISARM at least tells the author something. Measured over
# the five real kernels: 18 items carry a late CAP-opening run and ZERO of them hold
# anything but a bare id, so the residual has no live instance.
#
# So the shared predicate lives here, in one shell variable, and is injected verbatim into
# both awk programs: FIRST_MK and FIRST_AFTER describe the item FIRST emphasis run, and
# decl_run reports the item DECLARATION run, if it has one. The fold asks whether it is
# still open; the scan asks what is inside it. Neither can learn a marker the other does
# not. The value is single-quoted at assignment, so the backtick in the class is literal,
# and expansion does not re-parse it.
CAP_DECL_AWK='
# ONE CONTAINER CLASS, DEFINED AS DATA AND BUILT INTO EVERY EXPRESSION THAT NEEDS IT.
#
# This set was written FOUR times before it was extracted -- the fold terminator, the
# leading test, the scan heading gate and the reader -- and no two agreed. Each drift was
# introduced by the repair of the previous one: the marker set written twice, then the
# container set a third time, then a fourth, over consecutive fixes. Three of those were
# silent drops of a real capability and every one was invisible to the fixture. A series
# that recurs at a steady rate under repeated repair is not converging, and the answer is
# not a fifth careful copy: it is to make the fifth copy UNCONSTRUCTIBLE by having one
# definition that every position derives from.
#
# THE READER IS DELIBERATELY NOT IN THIS SET, and that is a design decision rather than an
# omission. A capability is DECLARED only in a dash-or-star bullet; every other container
# is read as unparseable and DISARMS. Widening the reader to this class would silently
# start accepting declarations the check is built to refuse. So the class answers "what
# starts a block-level item" -- which the fold and the leading test both ask -- and the
# reader answers a narrower question of its own.
BEGIN { CONTAINER = "([-*+>|]|[0-9]+[.)])" }
function container_start(l) { return (l ~ "^[[:space:]]*" CONTAINER "[[:space:]]") }
function only_container_markers(pre) { return (pre ~ "^([[:space:]]|" CONTAINER "|#+)*$") }
function known(run,   t, id) {
  t = run
  while (match(t, /CAP-[0-9][A-Za-z0-9_-]*/)) {
    id = substr(t, RSTART, RLENGTH)
    if (id in ok) return 1
    t = substr(t, RSTART + RLENGTH)
  }
  return 0
}
function decl_run(t, strict,   two, mk, after, e, run, rest, pre, leading, fb, fbopen, hasfb) {
  DECL_RUN = ""; DECL_FOUND = 0; DECL_OPEN = 0
  rest = t; pre = ""; hasfb = 0
  while (match(rest, /(\*\*|__|\*|_|`)/)) {
    pre = pre substr(rest, 1, RSTART - 1)
    two = substr(rest, RSTART, 2)
    if (two == "**" || two == "__") { mk = two } else { mk = substr(rest, RSTART, 1) }
    after = substr(rest, RSTART + length(mk))
    e = index(after, mk)
    if (e > 0) { run = substr(after, 1, e - 1); rest = substr(after, e + length(mk)) }
    else       { run = after; rest = "" }
    if (after ~ /^CAP-[0-9]/) {
      leading = 0
      if (only_container_markers(pre)) { leading = 1 }
      if (run !~ /^CAP-[0-9]+[a-z]?$/) {
        if (!strict || leading || known(run)) {
          DECL_RUN = run; DECL_FOUND = 1
          if (e == 0) { DECL_OPEN = 1 }
          return 1
        }
      } else if (leading && !hasfb) {
        fb = run; fbopen = (e == 0); hasfb = 1
      }
    }
    pre = pre mk run mk
  }
  if (hasfb) { DECL_RUN = fb; DECL_FOUND = 1; DECL_OPEN = fbopen; return 1 }
  return 0
}
'


# HTML COMMENTS ARE STRIPPED WITH THE FENCES, and for the same reason. Commenting out a
# capability is how an author removes one without losing the text, and an unstripped
# comment made that a hard DISARM -- the removed declaration was still read as a live one.
KERNEL_PROSE="$(awk '
  BEGIN { f = 0; c = 0 }
  /^[[:space:]]*(```|~~~)/ { f = !f; next }
  f { next }
  {
    if (c) { if (sub(/^.*-->/, "")) { c = 0 } else { next } }
    while (sub(/<!--.*-->/, "")) { }
    if (sub(/<!--.*$/, "")) { c = 1 }
    print
  }' "$KERNEL")"
CAP_DEFS="$(printf '%s\n' "$KERNEL_PROSE" | sed -n 's/^[[:space:]]*[-*][[:space:]]*\*\*\(CAP-[0-9][^*]*\)\*\*.*/\1/p')"
CAPS="$(printf '%s\n' "$CAP_DEFS" | grep -xE 'CAP-[0-9]+[a-z]?' | sort -u -V || true)"
# EVERY ID THAT LOOKS DECLARED MUST HAVE PARSED AS A DEFINITION. One join replaces the
# residue partition that used to sit here, and the replacement is a SUBTRACTION: the old
# arm's population was `CAP_DEFS` itself, so it could only see a malformed id inside a
# well-formed CONTAINER, and every id it caught this one catches too.
#
# A GUARD SCOPED TO THE SAME POPULATION AS THE READER IT GUARDS CANNOT SEE THE READER'S
# BLIND SPOT. That is the lesson this arm cost twice. The reader takes `- **CAP-<n>**`
# bullets; the first guard also required a `[-*]` bullet, so a RIGHT emphasis in a WRONG
# container was invisible to both -- a numbered item, a table row, an `### CAP-2` heading,
# a bold paragraph, and a canonical bullet inside a blockquote each dropped a defined
# capability silently, leaving the count on the PASS line as the only trace. The guard is
# therefore scoped by EMPHASIS alone and says nothing about containers.
#
# AND IT EXTRACTS THE ID AS WRITTEN, NOT THE LONGEST WELL-FORMED PREFIX. With the lenient
# grammar `CAP-[0-9]+[a-z]?`, `**CAP-1ab` yields `CAP-1a` -- so a kernel that defines
# `CAP-1a` CANCELS the finding for a `CAP-1ab` typo and the malformed id is silent again.
# That is the failure the suffix scheme makes likely, since `CAP-1`, `CAP-1a` and a typo
# `CAP-1ab` are exactly the ids that coexist. Two sides of a join derived by the SAME
# lenient grammar cannot see a malformed member; this side reads to the end of the token.
#
# THE EMPHASIS DELIMITER IS LOAD-BEARING AND WAS MEASURED TWICE. Ordinary prose that
# merely BEGINS with a capability id -- "- CAP-10's enforcement surface is settled by ..."
# -- numbers 18 across the five real kernels available, and a probe that counted those
# would DISARM four of the five. Requiring an emphasis or code marker IMMEDIATELY before
# the id, or a heading, holds the false-positive set at ZERO across all five while still
# finding every shape above.
# THE READER MUST BE CONTAINER-SCOPED. NO GUARD OVER IT MAY BE.
#
# That sentence is here because this change violated it THREE TIMES, each time in a fresh
# arm written to fix the previous violation. The reader takes `- **CAP-<n>**` bullets and
# genuinely needs to: a bullet is what declares a capability. Every guard ABOVE it inherits
# that requirement by reflex, it reads as harmless because it matches the reader, and it
# silently limits the guard to the one container the reader already handles correctly. A
# guard scoped to its reader's population cannot see that reader's blind spot.
#
# A DECLARATION-SHAPED LINE MUST NOT DROP AN ID. This is the shape assertion, and it is
# what the join below cannot express: the join compares ID SETS, so a definition whose
# defect is that it holds TWO IDS is invisible to it -- the second id never enters the
# declarative side (no marker immediately before it) and the first is CANCELLED by an
# identically-spelled id from a clean bullet elsewhere in the same kernel.
#
# IT KEYS ON THE OPENER AND READS THE WHOLE LINE. An earlier form required the run to be
# CLOSED, and an unclosed `**` -- an ordinary hand-edit typo, on a file that is hand-edited
# between derives -- matched nothing at all and reproduced the defect an eighth way. It
# also fired on any run that was not exactly an id, WHETHER OR NOT anything was lost, which
# hard-DISARMED a correct kernel for writing `### CAP-1 — the routing capability` or
# `## CAP-1 and CAP-2 interactions` above its own canonical bullets. Both were found by
# attacking the predicate after it existed, by the person who proposed it.
#
# So the condition is exactly the harm: a line whose emphasis or heading run OPENS with a
# CAP id, carrying some CAP id the reader did not take. A heading or bolded sentence over
# ids that all parsed has lost nothing and is silent.
#
# THE DEPENDENCY ON `CAPS` RUNS THE SAFE WAY, and it was checked rather than assumed
# because consulting the reader's own output is one step from the reflex that produced
# three defects in this file. An id declared in a container the reader does not take is
# ABSENT from `CAPS`, so the arm FIRES rather than cancelling.
#
# `awk -v` IS NOT USED TO PASS `CAPS`: it carries no newline, so a newline-separated set
# arrives as one string and every membership test silently fails. The set is fed on stdin
# ahead of the corpus, terminated by a sentinel.
#
# FALSE-POSITIVE SET MEASURED AT ZERO across the five real kernels, each against its own
# capability set, with a seeded two-id line inside one of those kernels as the control that
# the probe can fire at all.
# A DECLARATION THAT WRAPS IS STILL ONE DECLARATION. The spine side of this file folds
# physical lines into logical list items and its comment says why; the kernel side never
# got the same treatment, so `- **CAP-1 and` / `  CAP-2 together**` split the defect across
# two lines that are each innocent -- line one opens a run and drops nothing, line two
# carries the dropped id and opens no run -- and the declaration that is wrong spans both.
# Ninth reconstruction of the same cancellation, with the same control: change the leading
# id to one not defined elsewhere and the wrapped form DISARMs.
#
# THE FOLD IS BOUNDED BY THE OPEN RUN, NOT BY THE LIST ITEM, and that is the one place this
# departs from the spine's version. Folding a whole list item would pull a definition's
# DESCRIPTION into its declaration, so `- **CAP-1** — routing` followed by a continuation
# mentioning another spec's `CAP-99` would read as a declaration that drops CAP-99. Joining
# only while the emphasis run is still OPEN -- an odd count of `**` -- makes that
# unconstructible instead of merely absent: a closed run takes no continuation at all.
# Measured either way at zero across the five real kernels; the bound is for the sixth.
KERNEL_ITEMS="$(printf '%s\n' "$KERNEL_PROSE" | awk "$CAP_DECL_AWK"'
  # The open-run test is decl_run plus DECL_OPEN, defined once in CAP_DECL_AWK above.
  {
    if (acc != "") {
      if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^#/ || container_start($0)) { print acc; acc = "" }
      else if (decl_run(acc, 0) && DECL_OPEN) { acc = acc " " $0; next }
      else { print acc; acc = "" }
    }
    if (acc == "") { acc = $0 }
  }
  END { if (acc != "") print acc }')"
CAP_DECL_MALFORMED="$({ printf '%s\n' "$CAPS"; echo '___CAPS_END___'; printf '%s\n' "$KERNEL_ITEMS"; } | awk "$CAP_DECL_AWK"'
  !seen { if ($0 == "___CAPS_END___") { seen = 1; next } if ($0 != "") ok[$0] = 1; next }
  # SCAN INSIDE DECLARATION RUNS ONLY. Scanning the whole item made a capability whose
  # INTENT PROSE cites a neighbouring spec into a hard DISARM: "- **CAP-3** -- the sweep
  # bound, like CAP-99 in the platform spec" was read as a line that DROPS CAP-99, which
  # it does not, because CAP-99 was never this kernel to declare. The tell was that the
  # identical sentence one line further down was accepted, so the verdict depended on
  # where the author wrapped -- a wrong POPULATION, not a wrong predicate.
  #
  # A run that does not OPEN with a CAP id is not a declaration, and everything outside a
  # declaration run is prose. That is the same principle the fold bound already applies,
  # one level in, so the two now agree about what a declaration is.
  #
  # A HEADING declares only its own leading id, never the rest of the heading text, or a
  # section titled after one capability and mentioning another would fire the same way.
  /(\*\*|__|\*|_|`)CAP-[0-9]|^ {0,3}#+[[:space:]]*CAP-[0-9]/ {
    item = $0; bad = 0
    # A HEADING IS ITS OWN RUN, WHOLE. Reading only the heading LEADING id let
    # "### CAP-1 and CAP-2 together" declare CAP-1 and drop CAP-2 in silence -- the same
    # cancellation as every other container, reconstructed through the one container that
    # has no closing marker to bound it. A heading has no delimiter, so its text IS the
    # run and every id in it is declared by it.
    #
    # THE COST IS ACCEPTED AND NAMED, and it is NARROWER than it first reads. This arm only
    # looks at headings that START with a CAP id and only fires when one of the ids is not
    # in CAPS, so the false-positive population is not "a heading citing a foreign id" but
    # "a heading that BOTH opens with a defined capability id AND names an undefined one".
    # A navigational heading such as "## Comparison with CAP-99 upstream" is untouched, and
    # so is one citing a defined sibling. The alternative is a silent drop, which is the
    # failure this arm exists for.
    #
    # A SEPARATOR-BOUNDED VERSION WAS PROPOSED AND REJECTED ON MEASUREMENT. Bounding the
    # heading scan at the first " -- " or ": " would keep both the fire and the quiet, but
    # only if the producer separates a heading id from its description that way. Measured
    # across the five real kernels: ZERO headings begin with a CAP id at all -- capabilities
    # are declared as bullets under a "## Capabilities" section -- so there is no producer
    # convention to observe and the rule would be an assumption about a grammar this repo
    # does not own. The heading path here is DEFENSIVE, for a kernel that declares that way,
    # and a named cost beats an unmeasurable assumption.
    # UP TO THREE SPACES, WHICH IS THE SPEC BOUND AND NOT A ROUND NUMBER. CommonMark allows
    # a heading to be indented up to three spaces; four makes it an indented code block,
    # which is the limit deliberately kept above. An anchor of ^#+ alone was defeated by one
    # to three spaces.
    if (match(item, /^ {0,3}#+[[:space:]]*CAP-[0-9]/)) {
      head = item
      while (match(head, /CAP-[0-9][A-Za-z0-9_-]*/)) {
        id = substr(head, RSTART, RLENGTH)
        if (!(id in ok)) bad = 1
        head = substr(head, RSTART + RLENGTH)
      }
    }
    # THE FIRST EMPHASIS RUN, AND ONLY THAT ONE. An item declares at most one capability,
    # so a later run is prose no matter what it contains. Scanning every CAP-opening run
    # meant a backticked cross-spec citation inside an intent -- "- **CAP-3** -- mirrors
    # `CAP-99` upstream" -- was read as a second declaration and DISARMED, while the same
    # id in unbackticked prose on the same line was fine. And if the FIRST run does not
    # open with a CAP id the item declares nothing at all, which is what keeps
    # "- **Note:** see `CAP-9`" out of this arm.
    if (decl_run(item, 1)) {
      run = DECL_RUN
      while (match(run, /CAP-[0-9][A-Za-z0-9_-]*/)) {
        id = substr(run, RSTART, RLENGTH)
        if (!(id in ok)) bad = 1
        run = substr(run, RSTART + RLENGTH)
      }
    }
    if (bad) print item
  }' | sort -u || true)"
CAP_DECL_DROPPED="$(comm -13 <(printf '%s\n' "$CAPS" | grep -v '^$' | sort -u) \
  <(printf '%s\n' "$CAP_DECL_MALFORMED" | grep -oE 'CAP-[0-9][A-Za-z0-9_-]*' | sort -u) || true)"
if [ -n "$CAP_DECL_MALFORMED" ]; then
  echo "$PROG: DISARMED — $KERNEL carries declaration-shaped lines that drop these capability ids: $(printf '%s' "$CAP_DECL_DROPPED" | tr '\n' ' '). A definition declares exactly ONE capability and its emphasised text must be exactly that id — CAP-<n> with an optional single lowercase suffix. A line naming two ids declares neither, and every id in it the reader could not take is absent from the capability set, exempt from every join below, and reported as nonexistent if a story cites it. Offending line(s):" >&2
  printf '%s\n' "$CAP_DECL_MALFORMED" | head -5 | sed 's/^/  /' | cut -c1-140 >&2
  exit 2
fi

# WHAT THE SURVIVING ARM EXCLUDES, AND WHY THERE IS NOW ONLY ONE OF THEM.
#
# A SECOND ARM STOOD HERE -- a join between "ids that look declared" and "ids that
# parsed" -- and it was DELETED after an adversarial attempt failed to construct anything
# it caught that the arm above does not. That attempt is the evidence; the reasoning
# alone would not have been enough, because the same reasoning deleted a partition twice
# in this file and was wrong both times.
#
# THE DISTINCTION THAT MAKES THIS DELETION CHECKABLE AND THOSE ONES NOT: subsumption is
# only decidable when both arms key on the SAME PREDICATE over the SAME POPULATION. The
# residue partition keyed on a malformed STRING while the join keyed on an ID SET, and a
# string can be malformed while every id in it is accounted for -- which is exactly the
# case the deletion dropped. These two both keyed on "an id not in CAPS, gated by an
# emphasis-or-heading opener", over the same id grammar and the same set, so the
# containment is a comparison of two expressions rather than an argument about behaviour:
# the surviving arm scans EVERY id on a gated line, which is a strict superset of the
# deleted arm's marker-adjacent scan.
#
# AND KEEPING BOTH WAS ITSELF A LIABILITY, WHICH IS THE PART THAT DECIDED IT. Correctness
# depended on two hand-written gates staying identical, and they HAD ALREADY DRIFTED --
# `[ \t]` here against `[[:space:]]` there -- silently, with nothing able to see it. The
# surviving gate was widened to `[[:space:]]` in the same change that removed the second
# one, so the one case the drift made reachable is not lost with it.
#
# WHAT REMAINS EXCLUDED, unchanged by the deletion: an id that is neither emphasised,
# coded, nor heading-initial is outside this arm entirely -- `- CAP-2 — intent`,
# `- CAP-2: intent`, a plain numbered item, a plain table row, a definition-list body, a
# plain paragraph. That is NOT closable from here: a plain-text DEFINITION and a
# plain-text MENTION are the same string, and dropping the marker requirement is the
# widening measured at 18 false positives across five real kernels, which would have
# DISARMED four of them. The limit is the price of that measurement; do not widen this
# without re-taking it.
#
# TWO SMALLER EXCLUSIONS, both measured and both left open deliberately.
#
# HTML EMPHASIS IS NOT IN THE MARKER SET, so `- <b>CAP-9</b> intent` declares a capability
# this reader does not take, silently. It is the unemphasised-id limit above wearing a tag
# rather than a new class, and closing it means teaching this arm HTML, which is a larger
# grammar than the producer emits.
#
# AN INDENTED CODE BLOCK IS NOT STRIPPED, so a definition-shaped line four spaces deep in
# an example becomes a PHANTOM capability that then fails join (2) against the PRD. The
# fence stripper and the four-space rule disagree about what code is. It is left alone
# because stripping four-space indentation would also eat list-item continuations, which
# is the corpus this file actually has, and the failure is LOUD -- a named capability with
# no FR -- rather than a silent drop.
#
# FENCED CONTENT IS EXCLUDED TOO, so a kernel that fences PART of its capability block
# undercounts silently (a fully fenced one is loud, via the empty-set DISARM below).
# Measured across the five real kernels: ZERO fenced regions of any kind, so this has no
# live instance -- and the stripping stays, because a kernel that DOCUMENTS the id grammar
# in an example is a real shape and DISARMing it for explaining itself is the worse trade.

# THE DEFINITION GRAMMAR IS THE PRODUCER'S AND CAN MOVE. A kernel that MENTIONS
# capabilities but declares none the reader can take is empty for a reason that is NOT
# "this spec has no capabilities", and closing every join against an empty set is the
# vacuity the DISARM below exists to prevent. Say which it is.
if [ -z "$CAPS" ] && grep -qE "$CAP_GRAMMAR" <<<"$KERNEL_PROSE"; then
  echo "$PROG: DISARMED — $KERNEL mentions CAP-<n> identifiers but DEFINES none in the '- **CAP-<n>** — <intent>' bullet shape this check reads. Either the kernel is malformed, or bmad-spec's definition grammar has changed and this reader must change with it. It is not a spec with zero capabilities, and it must not be scored as one." >&2
  exit 2
fi
NCAPS="$(printf '%s\n' "$CAPS" | grep -c . )"
if [ "$NCAPS" -eq 0 ]; then
  echo "$PROG: DISARMED — $KERNEL defines ZERO capabilities (no CAP-<n> found). Every join below would close against an empty set and print the same PASS line as a spec that closes them for real." >&2
  exit 2
fi

rc=0
note=0

# --- (1) every locked requirement reaches a capability -------------------------
# The memlog is TYPED -- `- (capability) ...`, `- (constraint) ...`, `- (event) ...`
# -- and this join reads CAPABILITY ENTRIES ONLY.
#
# READING ANY LINE IS THE DEFECT, NOT A SHORTCUT. bmad-spec's Self-Validate appends
# its own verdict as an `(event)` entry, and that verdict enumerates the very
# mapping this join checks:
#
#   - (event) pass 2 preservation PASS: LR-S300-1 -> CAP-1 + routing-knob constraint,
#     LR-S300-2 -> CAP-2 + BLOCKS constraint, LR-S300-3 -> CAP-3 + $0.00 constraint
#
# A predicate that scans every line mentioning the LR is satisfied by that summary.
# Measured against real bmad-spec output: severing the actual `(capability)` entry
# for a requirement left the join PASSING, because the spec's own claim that the
# join holds was being read as evidence that it holds. That is the self-declared
# verdict Rule 30 forbids adopting, committed by the check meant to enforce it.
# The tag grammar is the PRODUCER's and the qualifier is optional per append: the memlog
# writer emits `(<type>)`, or `(<type> by <author>)` when the append carried an author. So
# `(capability)` and `(capability by bmad-spec)` are the SAME entry type and both are read
# here. This accepts anything after the type word rather than ` by ` specifically, because
# the type itself is free text on the producer's side and a narrower predicate would have to
# track its wording. The `[[:space:]]` inside the optional group is load-bearing: without it
# the group also swallows `(capability-review)`, and the join widens to a different type.
CAP_ENTRIES="$(grep -E '^[[:space:]]*[-*][[:space:]]*\((capability|capabilities)([[:space:]][^)]*)?\)' "$MEMLOG")"
if [ -z "$CAP_ENTRIES" ]; then
  echo "$PROG: DISARMED — $MEMLOG contains no '(capability)' entries. The LR->CAP join reads those entries and only those; with none present it would close against an empty set. An optional qualifier after the type — '(capability by <author>)' — is legal and is read here; a memlog with neither form has no capability entries at all. If bmad-spec's memlog entry TYPES change, this predicate must change with them rather than fall back to scanning every line." >&2
  exit 2
fi

# THE THIRD DISPOSITION. A locked requirement can be correct, current, and map to no
# capability: a WHAT/HOW meta-clause that constrains how the OTHER locked entries are
# READ and asserts no behaviour of its own. It is not SUPERSEDED and not AMENDED --
# it was never wrong and still governs -- so the two dispositions this join offered had
# no state for it, and it failed every run forever.
#
# BASELINING IT IS THE WRONG INSTRUMENT AND SAYS THE WRONG THING. A baseline entry means
# "still reproducing, cause not yet fixed", and the did-not-reproduce arm below is built
# to delete it when the cause is gone. Here there is no cause and nothing to fix, so the
# ledger carries a permanent line describing a defect that does not exist -- measured on
# a real consumer, whose baseline held exactly that entry under a paragraph of comment
# explaining it was a script gap rather than a dropped requirement.
#
# THE HATCH IS TYPE-ANCHORED AND NARROW, for the same reason join (1) reads
# `(capability)` entries ONLY: prose that merely mentions the id must not satisfy it.
# It requires a `(disposition)` entry in the producer's own tag grammar (qualifier
# optional, as above), naming this LR, carrying the literal token NO-CAPABILITY, and
# carrying a REASON after it. A bare NO-CAPABILITY with nothing behind it is an
# unexplained blank, which is precisely what the story arm below already refuses to
# accept from an empty `capabilities:` field. It is recorded as a NOTE, never passed in
# silence -- a disposition nobody can see is not a disposition.
# `(decision)` IS READ TOO, BECAUSE `(disposition)` IS NOT A TYPE THE PRODUCER EMITS.
# Measured across the reference consumer's 58 memlogs: the observed types are constraint,
# event, capability, decision, note, question, direction, assumption, correction,
# resolution and change. `disposition` occurs ZERO times. A hatch keyed on a type nobody
# writes is a hatch nobody can reach, and the one real instance in the corpus is a
# `(decision)` entry. Both are accepted; the NO-CAPABILITY token adjacent to the id is what
# carries the meaning, and the type anchor only has to establish that this is a TYPED
# entry rather than prose.
DISP_ENTRIES="$(grep -E '^[[:space:]]*[-*][[:space:]]*\((disposition|decision)([[:space:]][^)]*)?\)' "$MEMLOG" || true)"

LRS="$(grep -ohE '\bLR-[A-Za-z0-9]+-[0-9]+[a-z]?\b' "$MEMLOG" | sort -u)"
NLRS="$(printf '%s\n' "$LRS" | grep -c . )"
if [ "$NLRS" -eq 0 ]; then
  echo "$PROG: DISARMED — no LR-<...> identifiers found in $MEMLOG. Join (1) has nothing to check, which is not the same as closing." >&2
  exit 2
fi
for lr in $LRS; do
  # THE LR MUST BE THE SUBJECT, NOT MERELY ON THE LINE. Two chained greps -- "a line
  # naming this LR" then "a line containing NO-CAPABILITY" -- ask nothing about whether
  # the token disposes THIS requirement, which is the self-report class join (1)'s own
  # comment exists to prevent, reintroduced inside `(disposition)` entries. Measured:
  # `- (disposition) LR-S1-2 SUPERSEDED by LR-S1-9 — see the NO-CAPABILITY convention`
  # excused BOTH ids, one of them dispositioned as something else entirely and the other
  # merely named as its superseder. Anchoring the token directly after the id also makes
  # one entry disposition exactly one requirement, which is the coarse-key problem the
  # baseline section of this same file argues against.
  if [ -n "$DISP_ENTRIES" ] && printf '%s\n' "$DISP_ENTRIES" \
       | grep -qE "(^|[^A-Za-z0-9-])$lr[[:space:]]+NO-CAPABILITY[[:space:]]+[^[:space:]]"; then
    lr_reason="$(printf '%s\n' "$DISP_ENTRIES" | grep -E "(^|[^A-Za-z0-9-])$lr[[:space:]]+NO-CAPABILITY[[:space:]]" | head -1 | sed 's/.*NO-CAPABILITY[[:space:]]*//')"
    if is_reason "$lr_reason"; then
      echo "  note  $lr is dispositioned NO-CAPABILITY in $MEMLOG — $lr_reason"
      note=$((note+1))
      continue
    fi
  fi
  # A `(capability)` entry naming both this LR and a CAP-N is the join. Nothing else
  # counts -- see the note above on why scanning every line reads a self-report.
  if ! printf '%s\n' "$CAP_ENTRIES" | grep -E "(^|[^A-Za-z0-9-])$lr([^A-Za-z0-9-]|\$)" | grep -qE "$CAP_GRAMMAR"; then
    fail_join "lr:$lr" "$lr appears in the memlog but no capability entry cites it alongside a CAP-<n>. A locked requirement that reaches no capability is dropped, and every artifact downstream stays internally consistent while it is missing. Either map it to a capability, record an explicit SUPERSEDED/AMENDED disposition for it, or — if it asserts no behaviour of its own and correctly maps to none — record '- (disposition) $lr NO-CAPABILITY <reason>' in $MEMLOG."
  fi
done

# --- (2) every capability is cited by a functional requirement -----------------
# READ THE PRD's FR ENTRIES, NOT BMAD's FR COVERAGE MAP.
#
# The Coverage Map is bmad-create-epics-and-stories' artifact and its template emits
# `FR1: Epic 1 - <description>` — an FR-to-EPIC mapping with no capability token in
# it at all. The first version of this join required each CAP to appear there, which
# would have failed every capability against a perfectly correct map: a hard false
# positive blocking every planning gate. Reading the real template settled it; a
# paraphrase had already said `FR1: Epic 1` and the `(CAP-1)` was invented here.
#
# FR-to-epic coverage is already `bmad-check-implementation-readiness` step 03's job,
# so duplicating it would violate Rule 26(b). What ai-dlc owns is prd.md's own FR
# entries — `research-requirements.md` mandates the capability citation there, e.g.
# `- **FR-S300-1 (CAP-1)** ...` alongside the existing `(← LR-...)` form.
FR_LINES="$(grep -nE '(^|[^A-Za-z0-9-])N?FR-?[A-Za-z0-9]*-?[0-9]+' "$PRD")"
if [ -z "$FR_LINES" ]; then
  echo "$PROG: DISARMED — $PRD contains no functional-requirement identifiers (nothing matching FR-<n> / FR-S<N>-<n>). Join (2) has nothing to read, which is not the same as closing." >&2
  exit 2
fi
for cap in $CAPS; do
  if ! grep -qE "(^|[^A-Za-z0-9-])$cap([^A-Za-z0-9-]|\$)" <<<"$FR_LINES"; then
    fail_join "fr:$cap" "$cap is defined in SPEC.md but no functional requirement in $PRD cites it. A capability with no FR behind it is specified and unplanned — it reaches no epic, no story and no test. Add the citation to the FR entry, in the form research-requirements.md mandates."
  fi
done

# --- (3) every story capability reference resolves -----------------------------
if [ "${#STORIES[@]}" -gt 0 ]; then
  for s in "${STORIES[@]}"; do
    [ -f "$s" ] || { echo "$PROG: DISARMED — --story names an unreadable file: $s" >&2; exit 2; }
    refs="$(sed -n '/^capabilities:/{s/^capabilities:[[:space:]]*//; s/[][]//g; s/,/ /g; p; }' "$s" | head -1)"
    # THREE STATES, NOT ONE. An empty `$refs` was reported as "carries no 'capabilities:'
    # frontmatter field" regardless of why it was empty, and that sentence is FALSE for two
    # of the three cases. Measured on the reference consumer: of the 4 in-scope stories, 3
    # carry a `capabilities:` line that is EMPTY and were told they carry none.
    #
    # A WRONG DIAGNOSIS ON A HARD BLOCK IS HOW CHECKS GET TURNED OFF. The author reads
    # "carries no field", looks at the field sitting in the frontmatter, and concludes the
    # check is broken -- which, on that sentence, it is. The remedy it names does not apply
    # and the real one is never stated.
    #
    #   key absent          the story predates the frontmatter contract or ignored it.
    #                       Nothing was claimed. Add the field.
    #   key empty, no why   the story CLAIMS it implements no capability. That is a real
    #                       claim about the chain and it is unexplained -- which is a
    #                       different defect with a different remedy, not a missing field.
    #   key empty + why     the claim is DECLARED, in the pattern Check 33's
    #                       `NOT-IN-SCOPE` disposition already establishes: an explicit,
    #                       visible, per-item disposition beats an unexplained blank.
    #                       Recorded as a note, not a pass in silence.
    if [ -z "$refs" ]; then
      cap_rationale="$(sed -n 's/^capabilities_rationale:[[:space:]]*//p' "$s" | head -1 | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
      if ! grep -q '^capabilities:' "$s"; then
        fail_join "story:$(basename "$s")" "$s carries no 'capabilities:' frontmatter field at all. That field is the only mechanical link from a story to the spec; without it the story's place in the chain is prose. Add it — with the CAP-<n> ids this story implements, or empty plus a 'capabilities_rationale:' saying why it implements none."
      elif [ -n "$cap_rationale" ]; then
        echo "  note  $(basename "$s") declares no capability, with a rationale: $cap_rationale"
        note=$((note+1))
      else
        fail_join "story:$(basename "$s")" "$s declares 'capabilities:' EMPTY and gives no 'capabilities_rationale:'. The field IS present — this is not a missing field, it is an unexplained claim that this story implements none of the spec's capabilities. Either name the CAP-<n> ids it implements, or state why it implements none: 'capabilities_rationale: <reason>'."
      fi
      continue
    fi
    for r in $refs; do
      case "$r" in CAP-*) ;; *) continue ;; esac
      if ! grep -qx -- "$r" <<<"$CAPS"; then
        # THROUGH fail_join, LIKE EVERY OTHER ARM. This one emitted a bare echo and set
        # rc directly, so it registered no key and `--baseline` could not reach it --
        # while `:243`/`:248` in this same loop DO route through fail_join. That made it
        # the one arm with no disposition short of an operator turn, which is the worst
        # place for a check to be wrong: a consumer that can PROVE a false positive here
        # has nowhere to record it and the gate stays blocked.
        fail_join "story-cap:$(basename "$s"):$r" "$s cites '$r' and $KERNEL defines no such capability. A story pointing at an ID that does not exist is a story nobody can trace, and CAP-<n> is never renumbered — so this is a typo or a stale reference, not a renumbering."
      fi
    done
  done
fi

# --- (2a) every capability is bound by an architecture decision ----------------
# bmad-architecture renders each decision as `### AD-<n> — <title>` followed by
# `- **Binds:** <what>`, and Binds names CAPABILITIES: a real generated spine reads
# `- **Binds:** CAP-1`. So the CAP -> AD leg is a real join, and the chain this check
# documents asserted it without checking it. A leg claimed and unenforced is the same
# defect as a rule with no mechanism.
#
# `all` binds every capability -- a spine-wide invariant, which is how the real output
# expresses a decision that governs everything.
if [ -n "$SPINE_MD" ]; then
  [ -f "$SPINE_MD" ] || { echo "$PROG: DISARMED — --spine names an unreadable file: $SPINE_MD" >&2; exit 2; }
  # ONE FOLD, TWO READERS. `- **Binds:**` and `- **No-AD:**` are the same bullet grammar
  # and wrap for the same reason, so the spine is folded into logical list items ONCE and
  # both readers filter that. A second copy of this accumulator is a second grammar to
  # drift.
  #
  # A LOGICAL LIST ITEM, NOT A PHYSICAL LINE. `grep` returns lines, and a `- **Binds:**`
  # bullet that WRAPS carries its remaining capabilities on continuation lines that a
  # line-matcher discards before the per-capability search below ever runs. The failure
  # is silent and INVERTED: it accuses a spine that DID declare the binding, and the more
  # thoroughly an AD is documented the likelier its Binds line wraps at all. Measured on
  # a real spine: of 17 capabilities, the ONE whose id sat on the same physical line as
  # its marker passed and the other 16 were reported unbound.
  #
  # FOLD, DO NOT WIDEN THE GREP. Widening to match any line carrying a CAP token would
  # read capabilities out of `- **Prevents:**` and `- **Rule:**` bullets and out of
  # ordinary prose, closing the join against text that binds nothing. This accumulates
  # continuation lines onto their own bullet and stops where the list item does: at a
  # blank line, at the next bullet, or at a heading.
  # A FENCED BLOCK IS NOT SPINE CONTENT. A closing ``` matches no terminator, so an
  # accumulator that ignores fences folds straight through a worked EXAMPLE of the entry
  # shape and out the other side, binding whatever the prose after it mentions. Skipping
  # fences also retires a defect older than this fold: a `- **Binds:** CAP-2` written
  # INSIDE an example block was already being read as a real binding by the plain grep.
  #
  # THE TERMINATOR SET IS THE WHOLE CORRECTNESS ARGUMENT, and three cases short is a
  # false PASS, not a missed one. Blockquotes, table rows, thematic breaks and ordered
  # list items all end a list item and none of them is a `-` bullet or a heading.
  #
  # A MORE-INDENTED BULLET CONTINUES THE ITEM; a same-or-less-indented one ends it. That
  # is what makes the most idiomatic markdown for a multi-capability binding -- a nested
  # list under the marker -- read as the binding it plainly is.
  #
  # KNOWN LIMIT, STATED BECAUSE IT IS NOT FIXABLE HERE. Prose lazily continuing a Binds
  # bullet IS part of that list item in markdown, so a sentence like "this deliberately
  # does NOT bind CAP-2" inside the bullet reads as a binding. No lexical rule separates
  # it from a wrapped id list -- real spines wrap mid-phrase, with no trailing punctuation
  # to key on. The previous reader got that case right only by discarding EVERY
  # continuation line, which is the defect this fold exists to fix; it was never a
  # capability, it was a coincidence of the bug. Put dispositions in a `- **No-AD:**`
  # bullet, which is what that bullet is for.
  SPINE_BULLETS="$(awk '
    BEGIN { fence = 0 }
    /^[[:space:]]*(```|~~~)/ { if (acc != "") { print acc; acc = "" } fence = !fence; next }
    fence { next }
    /^[[:space:]]*[-*][[:space:]]*\*\*(Binds|No-AD):\*\*/ {
      if (acc != "") print acc
      acc = $0; ind = match($0, /[^ \t]/); next
    }
    {
      if (acc != "") {
        if ($0 ~ /^[[:space:]]*$/) { print acc; acc = ""; next }
        if ($0 ~ /^[[:space:]]*([-*+]|[0-9]+[.)])[[:space:]]/) {
          if (match($0, /[^ \t]/) > ind) { acc = acc " " $0; next }
          print acc; acc = ""; next
        }
        if ($0 ~ /^#/ || $0 ~ /^[[:space:]]*>/ || $0 ~ /^[[:space:]]*\|/ || $0 ~ /^[[:space:]]*(---|===|___|\*\*\*)/) {
          print acc; acc = ""; next
        }
        acc = acc " " $0
      }
    }
    END { if (acc != "") print acc }
  ' "$SPINE_MD")"
  BINDS="$(printf '%s\n' "$SPINE_BULLETS" | grep -E '^[[:space:]]*[-*][[:space:]]*\*\*Binds:\*\*' || true)"
  NO_AD="$(printf '%s\n' "$SPINE_BULLETS" | grep -E '^[[:space:]]*[-*][[:space:]]*\*\*No-AD:\*\*' || true)"

  # REPORT ONLY WHEN THE TRUNCATION ACTUALLY LOSES AN ID. Firing on the PRESENCE of a
  # second marker made a hard failure out of ordinary writing: "- **Binds:** CAP-1, CAP-2,
  # CAP-3 — the **Rule:** is stated in AD-2" cross-references another key in trailing prose,
  # loses nothing to the truncation, and closes the join — and the wrapped form of that same
  # sentence is the exact shape the fold exists to support. A capability id AFTER the second
  # marker is precisely the condition under which truncation removes something, so that is
  # the condition the arm keys on. What remains is a Binds bullet whose trailing prose names
  # a capability after a bold key, which is genuinely ambiguous, and there firing is right.
  BINDS_EATEN="$(printf '%s\n' "$BINDS" | awk '{
    h = index($0, "**Binds:**")
    if (h > 0) {
      rest = substr($0, h + 10)
      if (match(rest, /\*\*[A-Za-z][A-Za-z-]*:\*\*/)) {
        after = substr(rest, RSTART + RLENGTH)
        if (after ~ /CAP-[0-9]/) print $0
      }
    }
  }')"
  if [ -n "$BINDS_EATEN" ]; then
    fail_join "no-ad-form:$(basename "$SPINE_MD")" "$SPINE_MD names a capability AFTER a second '**<Key>:**' marker inside a '- **Binds:**' bullet. A continuation line carrying a marker folds into the Binds bullet, so a sentence like 'see **No-AD:** below for CAP-2' makes those capabilities read as BOUND — silently, with no note and no failure. An entry must start its own bullet: '- **No-AD:** <CAP ids> — REASON: <why>'. Offending bullet: $(printf '%s' "$BINDS_EATEN" | head -1 | cut -c1-120)"
  fi
  # AND THE IDS AFTER THAT MARKER ARE NOT BOUND, so the bullet is TRUNCATED there. Reporting
  # alone would leave the capabilities counted as bound, which is the silence being fixed.
  # This keys on the spine's OWN entry grammar rather than on prose shape -- the fold's
  # grammar already says a `**Key:**` marker starts a bullet, so one appearing mid-bullet is
  # a marker that got eaten, never part of a genuine id list. That is what separates this
  # case from lazily-continued prose, which carries no such marker and stays a known limit.
  BINDS="$(printf '%s\n' "$BINDS" | awk '{
    h = index($0, "**Binds:**")
    if (h > 0) {
      rest = substr($0, h + 10)
      if (match(rest, /\*\*[A-Za-z][A-Za-z-]*:\*\*/)) { print substr($0, 1, h + 9 + RSTART - 1); next }
    }
    print
  }')"
  if [ -z "$BINDS" ]; then
    echo "$PROG: DISARMED — $SPINE_MD contains no '- **Binds:**' entries, so no AD declares what it governs. Either this is not an ARCHITECTURE-SPINE.md or the AD entry shape changed; both would close this join against an empty set." >&2
    exit 2
  fi
  # `all` IS READ OFF THE PHYSICAL MARKER LINE, AND MUST BE THE WHOLE VALUE. This is the
  # single most dangerous string in the file: it switches join (2a) off for every
  # capability at once, and the summary then prints identically to a spine that closes the
  # join for real. Read from the FOLDED bullet it was manufacturable out of ordinary
  # prose -- `- **Binds:**` with a continuation line beginning "all routing decisions are
  # deferred to AD-2 and this AD binds nothing yet" folded to `**Binds:** all routing...`,
  # which `all\b` accepted. A sentence saying the AD binds NOTHING turned the join off
  # entirely. Requiring `all` to be the ENTIRE value, on the marker line itself, makes
  # that state unconstructible from prose rather than detectable in it.
  if grep -qiE '^[[:space:]]*[-*][[:space:]]*\*\*Binds:\*\*[[:space:]]*all[[:space:]]*\.?[[:space:]]*$' "$SPINE_MD"; then
    binds_all=1   # a spine-wide AD binds every capability
    echo "  note  $SPINE_MD declares '**Binds:** all', so join (2a) closes spine-wide for all $NCAPS capability(ies) without checking any of them individually."
    note=$((note+1))
  else
    binds_all=0
    for cap in $CAPS; do
      if grep -qE "(^|[^A-Za-z0-9-])$cap([^A-Za-z0-9-]|\$)" <<<"$BINDS"; then
        continue
      fi
      # THE THIRD DISPOSITION, ONE JOIN OVER. Join (2a) admitted "bound" or "FAIL" and had
      # no state for a capability an architect DELIBERATELY declined to write an AD for --
      # the same gap join (1) had, in the same shape. A capability that extends an existing
      # ladder or an existing pattern adds no new mechanism class, so there is no invariant
      # for an AD to carry and nothing two independently-built units could implement
      # incompatibly. That is a decision, and it was already being recorded in the spine as
      # PROSE that no join could read.
      #
      # THE TWO ROUTES THIS REPLACES ARE BOTH WORSE, AND BOTH WERE MEASURED ON A REAL
      # CONSUMER. Authoring an AD to satisfy the join FABRICATES architecture for a decision
      # the architect explicitly declined to make. Baselining it files a permanent entry in a
      # ledger whose contract is that every line keeps reproducing and names a removal
      # condition -- and this one has no cause to fix, so it can never be removed. A check
      # that leaves only those two exits is a check that gets satisfied dishonestly.
      #
      # SAME NARROWNESS AS THE MEMLOG HATCH. Type-anchored to its own bullet marker in the
      # spine's own `- **Key:** value` grammar, must name the capability, and must carry a
      # literal `REASON:` with text after it -- prose that merely mentions the id does not
      # satisfy it, and neither does an id list with no reason. Recorded as a NOTE: a
      # disposition nobody can see is not a disposition.
      if [ -n "$NO_AD" ]; then
        nad="$(no_ad_bullet_for "$cap" | head -1)"
        if [ -n "$nad" ] && is_reason "${nad#*REASON:}"; then
          echo "  note  $cap is dispositioned No-AD in $SPINE_MD —${nad#*REASON:}"
          note=$((note+1))
          continue
        fi
      fi
      fail_join "ad:$cap" "$cap is defined in SPEC.md but no architecture decision in $SPINE_MD binds it. A capability no AD governs was never designed — it reaches implementation with no invariant constraining how. If no AD is the deliberate decision — the capability extends an existing pattern and introduces no new mechanism class — record it in $SPINE_MD as '- **No-AD:** $cap — REASON: <why>' rather than authoring an AD to satisfy this join or baselining a failure with no cause to fix."
    done
  fi

  # A No-AD MARKER INSIDE A Binds BULLET IS A DECLARATION THAT WAS EATEN. A continuation
  # line reading "see **No-AD:** below for CAP-2 and CAP-3 — REASON: deferred" folds into
  # the Binds bullet, because the marker is not at bullet start and so never begins a
  # No-AD bullet of its own. The capabilities it names then read as BOUND: no FAIL, no
  # note, and a sentence explicitly saying no AD exists produces silence. That is worse
  # than binding them falsely, and it defeats "a disposition nobody can see is not a
  # disposition" at the only place the reader would look.
  # --- the arm that stops a No-AD outliving its cause ---------------------------
  # THE HATCH ABOVE IS READ ONLY WHERE IT EXCUSES, WHICH MEANS ITS OWN CONTENT WAS
  # NEVER CHECKED. `$NO_AD` is consulted at exactly one place -- inside the loop, after
  # a `continue` has already skipped every capability an AD binds -- so the ids a No-AD
  # bullet NAMES are validated nowhere. Two states pass in silence, and they are the
  # same two the `--baseline` ledger has a second arm to prevent:
  #
  #   - A No-AD names a capability an AD LATER binds. The spine now asserts both, and
  #     the join reads the one that does not fire. The excuse has outlived its cause and
  #     nothing says so -- exactly the stale-baseline failure, with no expiry.
  #   - A No-AD names an id SPEC.md does not define -- a typo, or a capability that was
  #     removed. The loop iterates $CAPS, so an id outside that set is never looked up.
  #     It reads as an excuse and excuses nothing.
  #
  # THIS ARM IS DELIBERATELY NOT BASELINEABLE, and that is not the omission the story
  # arm was. The distinction is the consumer filing's, and it is sharper than the one
  # this comment first carried: a `story-cap:` failure is PRIMARY -- a story cites a
  # capability that does not exist -- so baselining it suppresses one failure and the
  # per-citation key bounds the blast radius. A staleness failure is META: it reports
  # that a suppression is invalid. Baselining a meta-failure does not suppress one thing,
  # it restores the INNER suppression to silence, leaving two stacked with the dangerous
  # one invisible again. The did-not-reproduce arm at the foot of this script is
  # non-baselineable for the identical reason, and both have the same one-line remedy --
  # delete the id from the bullet. A constraint whose remedy is always one line and
  # always available has no "expensive to fix, suppress for now" case to serve.
  # A No-AD BULLET WITH NO REASON IS REPORTED AS THE MALFORMED BULLET IT IS. Without
  # this the only signal is the capability's own FAIL further up, which names the correct
  # form but never says "the bullet you already wrote is the problem" -- so an author who
  # wrote one and expected it to work is told about an id instead of about their bullet.
  # It disposes nothing, so its ids are not validated below: reporting a bound id inside
  # a bullet that excuses nothing would answer a question nobody asked.
  if [ -n "$NO_AD" ]; then
    while IFS= read -r nad_line; do
      [ -n "$nad_line" ] || continue
      case "$nad_line" in
        *REASON:*)
          if ! is_reason "${nad_line#*REASON:}"; then
            fail_join "no-ad-form:$(basename "$SPINE_MD")" "$SPINE_MD carries a '- **No-AD:**' bullet whose 'REASON:' has no text, so it disposes nothing and every capability it names still fails this join. The form is '- **No-AD:** <CAP ids> — REASON: <why>'. Offending bullet: $(printf '%s' "$nad_line" | cut -c1-120)"
          elif ! grep -qE "$CAP_GRAMMAR" <<<"${nad_line%%REASON:*}"; then
            fail_join "no-ad-form:$(basename "$SPINE_MD")" "$SPINE_MD carries a '- **No-AD:**' bullet that names no capability before its 'REASON:'. The ids come from the segment BEFORE 'REASON:', so writing the fields in the other order disposes nothing and the capabilities it was meant to cover still fail this join, with nothing pointing at the bullet. The form is '- **No-AD:** <CAP ids> — REASON: <why>'. Offending bullet: $(printf '%s' "$nad_line" | cut -c1-120)"
          elif ! no_ad_id_segment_ok "$nad_line"; then
            fail_join "no-ad-form:$(basename "$SPINE_MD")" "$SPINE_MD carries a '- **No-AD:**' bullet whose id segment is not an id list. Everything before 'REASON:' must be CAP ids and separators only — a capability named there is DISPOSED by this bullet, so a parenthetical or an explanatory clause naming a capability it does not dispose would either excuse it silently or fail the gate for a contradiction that is not one. Move the commentary after 'REASON:', where prose belongs. Offending bullet: $(printf '%s' "$nad_line" | cut -c1-120)"
          fi
          continue ;;
      esac
      fail_join "no-ad-form:$(basename "$SPINE_MD")" "$SPINE_MD carries a '- **No-AD:**' bullet with no 'REASON:' at all, so it disposes nothing and every capability it names still fails this join. The form is '- **No-AD:** <CAP ids> — REASON: <why>'. Offending bullet: $(printf '%s' "$nad_line" | cut -c1-120)"
    done <<<"$NO_AD"
  fi

  if [ -n "$NO_AD" ]; then
    NO_AD_IDS=""
    while IFS= read -r nad_line; do
      [ -n "$nad_line" ] || continue
      NO_AD_IDS="${NO_AD_IDS}$(no_ad_ids "$nad_line")
"
    done <<<"$NO_AD"
    for nid in $(printf '%s\n' "$NO_AD_IDS" | grep -v '^$' | sort -u -V); do
      if ! grep -qx -- "$nid" <<<"$CAPS"; then
        fail_join "no-ad:$nid" "$SPINE_MD carries a '- **No-AD:**' disposition for '$nid', which $KERNEL does not define. A disposition for an id that is not a capability excuses nothing — it is a typo, or it outlived the capability it named. Delete it from the bullet."
      elif [ "$binds_all" -eq 1 ] || grep -qE "(^|[^A-Za-z0-9-])$nid([^A-Za-z0-9-]|\$)" <<<"$BINDS"; then
        fail_join "no-ad-stale:$nid" "$SPINE_MD carries a '- **No-AD:**' disposition for '$nid' AND an architecture decision that binds it. The spine asserts both, and this join reads only the one that does not fire, so the contradiction is invisible from here. The decision not to write an AD was overtaken; delete '$nid' from the No-AD bullet."
      fi
    done
  fi
fi

# --- borrowed verdict: lint_spine.py ------------------------------------------
if [ -n "$SPINE" ]; then
  [ -f "$SPINE" ] || { echo "$PROG: DISARMED — --spine-lint names an unreadable file: $SPINE" >&2; exit 2; }
  # lint_spine.py always exits 0 by design and publishes its verdict in an envelope:
  #   {"ok": bool, "spine": str, "total_findings": int, "by_severity": {...},
  #    "findings": [{"category": ..., "severity": ..., "detail": ..., "location": ...}]}
  #
  # READ THE ENVELOPE, DO NOT HAND-LIST CATEGORIES. The first version of this checked
  # for two category names, `ad_fields` and `placeholder`. There are four —
  # `ad_id` and `version_pin` were silently ignored, and `ad_id` is "id reused" /
  # "non-monotonic; ids must ascend and never renumber", i.e. exactly the ID-stability
  # failure this whole check's premise rests on. A hand-list also goes stale the moment
  # BMAD adds a fifth category, with no signal that it has.
  #
  # Severity comes from the script, not from here: any `high` finding fails, `low` is
  # reported. `low` is its "possible unfilled template token (verify)" class, and
  # failing a gate on a maybe is how a live check earns a blanket waiver.
  sev="$(sed -n 's/.*"severity"[[:space:]]*:[[:space:]]*"\([a-z]*\)".*/\1/p' "$SPINE" | sort -u)"
  total="$(sed -n 's/.*"total_findings"[[:space:]]*:[[:space:]]*\([0-9]\{1,\}\).*/\1/p' "$SPINE" | head -1)"
  if [ -z "$total" ]; then
    echo "$PROG: DISARMED — $SPINE carries no \"total_findings\" key, so it is not a lint_spine.py envelope. Exiting 2 rather than reporting a clean spine: a file this script cannot parse is not a file with no findings." >&2
    exit 2
  fi
  if grep -qx high <<<"$sev"; then
    n_high="$(grep -c '"severity"[[:space:]]*:[[:space:]]*"high"' "$SPINE")"
    echo "FAIL: lint_spine.py reported $n_high high-severity finding(s) in the architecture spine ($total total, $SPINE). It exits 0 by design and leaves the decision to its caller; this is that decision. An AD missing Binds/Prevents/Rule binds nothing, a reused or non-monotonic AD id breaks the ID stability every downstream join depends on, and an unfilled placeholder is an unratified decision." >&2
    grep -E '"(category|detail)"' "$SPINE" | sed 's/^[[:space:]]*/    /' >&2
    rc=1
  elif [ "$total" -gt 0 ]; then
    echo "  note  lint_spine.py reported $total low-severity finding(s) in $SPINE — recorded, not gating."
    note=$((note+1))
  fi
fi

# --- borrowed verdict: bmad-testarch-trace ------------------------------------
if [ -n "$TRACE" ]; then
  [ -f "$TRACE" ] || { echo "$PROG: DISARMED — --trace-verdict names an unreadable file: $TRACE. bmad-testarch-trace writes gate-decision.json only when the gate was evaluated AND produced PASS/CONCERNS/FAIL/WAIVED; its absence therefore means the gate did NOT evaluate, which is not the same as passing." >&2; exit 2; }
  # READ THE `gate_status` KEY, NOT THE WHOLE FILE. gate-decision.json also carries
  # `p0_status`, `p1_status`, `overall_status` and a prose `rationale`, any of which
  # can contain the token FAIL while the gate decision is CONCERNS. A whole-file grep
  # for FAIL therefore fails a gate the tool passed.
  gs="$(sed -n 's/.*"gate_status"[[:space:]]*:[[:space:]]*"\([A-Z_]*\)".*/\1/p' "$TRACE" | head -1)"
  case "${gs:-}" in
    FAIL)
      echo "FAIL: the traceability gate decision in $TRACE is FAIL. Requirements are not covered by tests; the matrix names which." >&2
      rc=1 ;;
    CONCERNS|WAIVED)
      echo "  note  traceability gate_status is $gs — recorded, not dropped. Matrix: $TRACE"
      note=$((note+1)) ;;
    PASS) ;;
    *)
      # Covers a missing/renamed key and NOT_EVALUATED, which the tool deliberately
      # excludes from this file. A trace that did not evaluate reads exactly like a
      # trace that passed, so it cannot be allowed to exit 0.
      echo "$PROG: DISARMED — $TRACE carries no readable \"gate_status\" (found '${gs:-<none>}'). Either the gate was not evaluated or the key was renamed; both would otherwise be indistinguishable from a PASS." >&2
      exit 2 ;;
  esac
fi

# --- the baseline must not outlive its cause ----------------------------------
# THE ARM THAT MAKES --baseline A LEDGER RATHER THAN A MUTE BUTTON. A baselined key
# that did not fire this run names a failure that is FIXED, and the line excusing it
# is now excusing nothing -- while still standing ready to suppress the next real
# instance of that same id, silently. That is a suppression with no lifetime, which is
# the shape this repo has already had to fix elsewhere.
#
# It is deliberately a FAIL and not a note: a note is what a stale baseline would
# accumulate for the rest of its life without anyone deleting a line.
n_base=0
if [ -n "$BASELINE_KEYS" ]; then
  while IFS= read -r bk; do
    [ -n "$bk" ] || continue
    n_base=$((n_base + 1))
    if ! grep -qxF -- "$bk" <<<"$BASELINE_HIT"; then
      echo "FAIL: baseline entry '$bk' in $BASELINE did NOT reproduce this run. The failure it was written to excuse is gone, so the entry now excuses nothing — and would silently suppress the next real instance of that same id. Delete the line. A baseline must not outlive its cause." >&2
      rc=1
    fi
  done <<<"$BASELINE_KEYS"
fi

if [ "$rc" -eq 0 ]; then
  echo "$PROG: PASS ($NLRS locked requirement(s), $NCAPS capability(ies), ${#STORIES[@]} story(ies), $note recorded note(s), $n_base baselined)"
fi
exit $rc
