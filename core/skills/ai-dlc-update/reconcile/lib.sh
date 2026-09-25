# reconcile/lib.sh — helpers that MUST be identical across the drift classifiers.
# reconcile-region: exempt — a sourced library, never invoked as a program.
#
# Not a general dumping ground. A helper earns a place here only when two tools
# disagreeing about it is itself a bug — when the gate and the tool would reach
# different verdicts on the same input. Helpers that merely LOOK alike
# (`emit()`'s three arities, `fm()`'s awk-vs-sed readers) stay in their own
# files: collapsing those changes behavior without removing a failure mode.
#
# Sourced, not eval-scraped. `apply.sh` pulls `map_consumer()` out of
# `preclassify.sh` with awk because it needs exactly one function out of a
# script that would otherwise RUN on source. This file's only top-level statements
# are the memo block below `ai_dlc_memo_cleanup`, which builds the cross-process memo
# and arms its cleanup on the sourcing shell's EXIT, so `.` is safe and the function
# bodies stay greppable.

# ---------------------------------------------------------------------------
# section_of — THE section resolver. One copy, by hard-won default.
# ---------------------------------------------------------------------------
# Three files carried three copies of this predicate, and the divergence shipped
# twice:
#
#   v0.52.0 — readopt-override's resolver was WEAKER than layer-drift's, so it
#             could not resolve the anchor layer-drift had just blocked on,
#             found no stale lines, and would have CLEARED the block.
#   v0.54.2 — register-drift's resolver was STRICTER than layer-drift's, so it
#             misfiled a renamed section (`## Escalation Protocol` vs core's
#             `## Escalation`) as an ADDITION, which would have rendered core's
#             heading and the consumer's side by side.
#
# Both times the fix was to hand-copy layer-drift's body over the divergent one,
# and the CHANGELOG recorded "there is one resolver" — but nothing MADE it one,
# so by the time this file was written the copies had drifted in form again.
# A hand-synced invariant is not an invariant. Now there is one body.
#
# The matcher is deliberately BIDIRECTIONAL substring, not exact: a consumer
# renaming `Escalation` to `Escalation Protocol` must still resolve to core's
# heading, or the rename gets misfiled as an addition and both render. The
# `length(h) > 3` guard on the reverse direction stops a 1-3 char heading
# (`## Do`) from matching every longer `want` that contains it.
#
# Normalization happens INSIDE awk (`BEGIN { w = nrm(want) }`) rather than in a
# shell `norm "$1"` at the call site. Two reasons: the body no longer depends on
# a `norm()` its caller might not define, and normalization is idempotent
# (post-norm text is lowercase alnum with single spaces, so re-running it is a
# no-op), so a caller that pre-normalizes gets the same answer either way.
# ---------------------------------------------------------------------------
# nrm_awk — THE heading normalizer, as awk source. One copy.
# ---------------------------------------------------------------------------
# It decides whether two headings are THE SAME heading, which is the join every
# anchor question in this repo rests on: span_of's containment, anchor_arm's
# direction, layer-drift's duplicate-key detection, and the authoring linter's
# per-anchor check. `norm()` below is its shell-side spelling.
#
# Emitted as awk source rather than a shell function for the same reason
# `ledger_entry_awk` is: every call site is an awk program, and it is
# CONCATENATED onto the front by adjacent-string quoting, so the remainder of
# each program stays single-quoted and needs no escaping.
#
# This was three spellings — two in validate-layer-entries.sh's awk programs and
# one inline in span_of below — and the whole point of a normalizer is that there
# is exactly one answer to "is this the same heading".
nrm_awk() {
  cat <<'AWK'
function nrm(s){ s=tolower(s); gsub(/[`*]/,"",s); gsub(/[^a-z0-9]+/," ",s); gsub(/^ +| +$/,"",s); return s }
AWK
}

# span_of is THE matcher; section_of is a slice of it. Splitting them this way rather than
# writing the predicate twice is the same decision the history above records: readopt-override
# needs a section's LINE RANGE (to merge one anchor of a multi-anchor override in place and
# leave the rest byte-untouched), everything else needs its TEXT. Two functions with two copies
# of the matcher is how the v0.52.0 and v0.54.2 divergences happened. There is one copy.
span_of() { # span_of <heading-text>  < stream   ->  "<start> <end>" 1-indexed inclusive, or nothing
  awk -v want="$1" "$(nrm_awk)"'
    BEGIN { w = nrm(want) }
    /^#{2,6}[ \t]/ {
      match($0, /^#+/); lvl = RLENGTH
      h = $0; sub(/^#+[ \t]+/, "", h); h = nrm(h)
      if (inside) { if (lvl <= mylvl) { print start, NR - 1; done = 1; exit } }
      else if (w != "" && (index(h, w) > 0 || (length(h) > 3 && index(w, h) > 0))) {
        inside = 1; mylvl = lvl; start = NR; next
      }
    }
    END { if (inside && !done) print start, NR }
  '
}

section_of() { # section_of <heading-text>  < stream
  local _t _s
  _t="$(mktemp)" || return 1
  cat > "$_t"
  _s="$(span_of "$1" < "$_t")"
  [ -n "$_s" ] && sed -n "${_s%% *},${_s##* }p" "$_t"
  rm -f "$_t"
}

# ---------------------------------------------------------------------------
# norm — the shell-side spelling of section_of's `nrm()`.
# ---------------------------------------------------------------------------
# Callers compare anchors to headings outside awk (layer-drift's `same_section`,
# readopt-override's `anchors_resolve`). Those comparisons must use the SAME
# normalization the resolver uses, or a heading that section_of matches can read
# as unresolved to its own caller.
norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -d '`*' | sed -E 's/[^a-z0-9]+/ /g; s/^ +| +$//g'; }

# ---------------------------------------------------------------------------
# norm_lines — norm()'s LINE-ORIENTED sibling: a stream filter, not a string call.
# ---------------------------------------------------------------------------
# WHY A SECOND FORM RATHER THAN A LOOP OVER norm(). `norm` takes one string as an
# argument, so normalising a file means one subprocess per line. Measured while
# building retired-layer-passage.sh: over 120s across a 45-file layer corpus, against
# 0.78s for a single stream pass. A validator's runtime is the fixture suite's wall
# clock, so the per-line form is not usable on a whole-corpus scan.
#
# IT IS ALSO DELIBERATELY LESS AGGRESSIVE, and that is the real reason it is separate.
# `norm` squashes EVERY non-alphanumeric run to a space, which is right for comparing
# anchors and titles. A line-level comparison of rulebook PROSE keeps the internal
# punctuation that distinguishes two directives and strips only what is presentation:
# list markers, ordered-list numbering, emphasis, and run-together whitespace. A layer
# file that renumbers core's step 4 as its own step 7 is still carrying core's sentence.
#
# LINE-PRESERVING BY CONTRACT. It emits exactly one output line per input line, so a
# caller may take grep's line numbers as the source file's own. Do not add a filter here.
norm_lines() {
  sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//
          s/^[-*+][[:space:]]+//
          s/^[0-9]+[.)][[:space:]]+//
          s/[`*_]//g
          s/[[:space:]]+/ /g
          s/[.[:space:]]+$//' \
  | tr '[:upper:]' '[:lower:]'
}

# ---------------------------------------------------------------------------
# anchor_arm — WHICH DIRECTION of span_of's containment resolved this anchor.
# ---------------------------------------------------------------------------
# span_of matches in EITHER direction: the heading contains the anchor (forward),
# or the anchor contains the heading (reverse). Forward is the legitimate grain —
# `SKILL.md#Rule 8` resolving to `### Rule 8 -- Run the validation cycle per
# declared intensity` is a consumer naming a rule by its id, not restating a title.
#
# REVERSE IS NOT A GRAIN, IT IS A SILENT WIDENING. An anchor that CONTAINS the
# heading declares something finer than a heading — a paragraph, a sub-clause, a
# renamed section — which the resolver cannot address, so it quietly resolves to
# the WHOLE section instead. The consumer believes it shadowed a paragraph and has
# in fact shadowed everything under that heading.
#
# THE RESOLVER IS NOT CHANGED. span_of's reverse arm is load-bearing (v0.54.2
# above records a release where a stricter resolver misfiled a consumer-renamed
# heading as an addition). Declaration is tightened; resolution is left alone.
# That asymmetry is the point: a reverse-only declaration is reported WITH the
# exact heading to substitute, so the fix is a copy-paste.
#
# SCOPE, STATED SO IT IS NOT MISTAKEN FOR MORE. This asks whether SOME heading
# forward-matches. It does not resolve ambiguity — a short anchor can forward-match
# several headings and still pass. Uniqueness is a different check with a different
# false-positive set, and folding it in here is how the recorded short-title
# degeneracy (`same_section()`'s containment arm, five false positives) would
# arrive in a new detector.
#
# Stdin, not a path, so ONE body serves both callers: the authoring linter reads a
# file on disk and the pull classifier reads a `git show` stream.
anchor_arm() { # anchor_arm <anchor>  < stream  -> FORWARD | REVERSE:<heading> | NONE
  awk -v want="$1" "$(nrm_awk)"'
    BEGIN { w = nrm(want); res = "NONE" }
    /^#{2,6}[ \t]/ {
      h = $0; sub(/^#+[ \t]+/, "", h); hn = nrm(h)
      if (hn == "") next
      if (w != "" && index(hn, w) > 0) { print "FORWARD"; found = 1; exit }
      # length > 3 mirrors span_of: a heading of three characters or fewer
      # contains-matches almost anything, which is noise rather than a finding.
      if (length(hn) > 3 && w != "" && index(w, hn) > 0 && res == "NONE") res = "REVERSE:" h
    }
    END { if (!found) print res }
  '
}

# ---------------------------------------------------------------------------
# shadow_parts — WHAT AN OVERRIDE SHADOWS. One reading of `shadows:`.
# ---------------------------------------------------------------------------
# The authoring linter and the pull classifier must agree about which (file,
# anchor) pairs an entry declares, or whichever the operator did not run is the
# one that is wrong. They forked twice, both times silently:
#
#   the linter read only the FIRST comma-part, so nineteen anchor instances
#   across twelve overrides were never validated (v0.16x);
#   the linter then read every part but computed the file PER PART, so the
#   file-inheriting spelling `a.md#One, #Two` skipped part two entirely before
#   any anchor check ran — 1 of 4 anchors checked on the reference consumer
#   (v0.191.0).
#
# The classifier had a third reading: ONE file for the whole entry (part one's)
# with every anchor harvested and checked against it, so `a.md#One, b.md#Two`
# would check `Two` against `a.md`. Latent only because no live entry names two
# files. All three are now this function.
#
# A part with no file of its own INHERITS the last one that had one. A FIRST part
# with no file emits an EMPTY file field: what to do about a part that names no
# target is the caller's decision (the linter errors; the classifier reports it
# unresolved), and burying that verdict here would give one of them the other's.
shadow_parts() { # shadow_parts <shadows-value>  -> one `<file>\t<anchor>` line per comma-part
  awk -v s="$1" '
    BEGIN {
      n = split(s, p, ",")
      for (i = 1; i <= n; i++) {
        part = p[i]; gsub(/^[ \t]+|[ \t]+$/, "", part)
        if (part == "") continue
        h = index(part, "#")
        if (h > 0) { f = substr(part, 1, h - 1); a = substr(part, h + 1) }
        else       { f = part; a = "" }
        gsub(/[ \t]+$/, "", f); gsub(/^[ \t]+|[ \t]+$/, "", a)
        if (f != "") last = f; else f = last
        print f "\t" a
      }
    }
  ' < /dev/null
}

# ---------------------------------------------------------------------------
# unquote — strip ONE matched pair of surrounding quotes from a frontmatter value.
# ---------------------------------------------------------------------------
# `fm()` is a line reader, not a YAML parser: it hands back everything after the
# key, quotes included. For every key that existed before `extends:` that was
# harmless, because none of their values need quoting.
#
# `extends:` does. Its whole point is a value that may begin with `#`, and an
# UNQUOTED `#` opens a YAML comment — so `extends: #Rule 8` is, to any real YAML
# reader, an empty value followed by a comment. The spelling an author must write
# is therefore the quoted one, and a reader that does not strip the quotes sees
# the file part of `'#Rule 8'` as a lone apostrophe and reports that the anchor
# lives in a file called `'`. That is not hypothetical: it is what this repo's
# own fixture reported the first time it ran.
#
# Shared for I40's reason rather than copied for convenience. The authoring linter
# ERRORs on an unresolvable `extends:` and the pull classifier narrows drift with
# it; if they disagreed about whether `'#X'` names the anchor `#X` or the anchor
# `X'`, one of them would be quietly watching a span that does not exist, and the
# operator would believe whichever they happened to run.
#
# ONE pair, and only when both ends match. A value that merely ENDS in a quote is
# left alone: guessing at unbalanced quotes would silently rewrite an anchor whose
# heading really does contain one.
unquote() { # unquote <value>
  case "$1" in
    "'"*"'") printf '%s' "${1#\'}" | sed "s/'\$//" ;;
    '"'*'"') printf '%s' "${1#\"}" | sed 's/"$//' ;;
    *)       printf '%s' "$1" ;;
  esac
}

# ---------------------------------------------------------------------------
# ledger_entry_awk — THE push-candidate ledger's entry-boundary rule. One copy.
# ---------------------------------------------------------------------------
# `ledger-reverify.sh` decides which lines belong to which entry; `ledger-rotate.sh` decides
# which entries move to the archive. Both need the same answer to "does this line start a new
# entry?", and disagreeing about it is a data-loss bug in one direction (a live entry swept
# into an archive nobody re-reads) and a silent-skip bug in the other.
#
# They were two hand-copies. `ledger-rotate.sh`'s header said so outright — "Entry BOUNDARIES
# are lifted from ledger-reverify's parser unchanged" — which is the same sentence the
# `section_of()` history above records twice before the copies drifted anyway. One release was
# enough: the LABEL rules in that supposedly-unchanged block already differ (rotate omits
# reverify's ` — ` truncation, so `## PC-FOO — title` labels differently in each).
#
# THIS PASSAGE ONCE READ "the two close-predicates stay in their own files because they differ
# DELIBERATELY", and that was the defect. The two predicates do differ, but by ONE PROPERTY —
# rotation requires the bold span reverify treats as optional — and the reason given for keeping
# them apart licensed two independent TOKEN SETS, which is how one file came to honour a close
# the other could not spell. `ledger_close_awk()` and `ledger_archive_awk()` below now emit both
# from one home: the difference is a derivation, not a second list.
#
# The label rules also stay put: unifying them changes rotate's `moved-names` output, which is
# a behaviour change and not this one's business. That is the same admission rule this file
# opened with — a helper earns a place here only when two tools disagreeing about it is itself
# a bug.
#
# Emitted as awk source rather than a shell function because both call sites are awk programs.
# The shape is returned, not a boolean, because each caller extracts its label differently from
# a bullet and from a heading.
#
# FENCE-AWARE, AND THE OBVIOUS FORM OF THAT IS THE WRONG ONE -- `scripts/backlog-rotate.sh`
# measured it before this landed: a plain `infence = !infence` toggle took the reference
# consumer's entry count from 142 to 95, because that corpus carries an ODD number of fence
# delimiters. Re-measured here on the same consumer's four ledger files: the toggle hides 6 live
# ids (one live line OPENS with an inline code span, three backticks followed by more backticks,
# which is not a fence) and 59 archived ones, 34 headings and 25 bullets (fences left
# unterminated by earlier splits). Global
# pairing desynchronises at the first unterminated fence and never recovers.
#
# SO THE FENCE IS BOUNDED BY THE ID RULE. Inside a fence, an entry-shaped line whose label is
# NOT id-keyed is ignored -- that is the subject of PC-S308-LEDGER-REVERIFY-ENTRY-BOUNDARY-
# IGNORES-FENCED-HEADINGS, a `derived` block whose recorded output carries `## <ts> -- EVENT`
# lines and split the entry that carried it. An entry-shaped line that IS id-keyed still opens
# an entry and RESETS the fence state, so an unterminated fence can hide nothing that carries an
# id: the fence was either unterminated or is quoting an entry heading, and in both cases
# opening the entry is the failure that loses nothing. `ledger-reverify.sh` reports that reset
# as an ENTRY-SWALLOWED row so the ledger gets fixed rather than the parse guessed at. Measured
# over the reference consumer live ledger, its archive and both distribution backlog files: no
# id-keyed boundary changes, exactly one non-id line stops being a boundary (the fenced
# timestamp heading the filing names), and two id-keyed headings inside earlier-split fences
# are kept and flagged.
#
# THE OPENER GRAMMAR IS COMMONMARK, NOT "A LINE STARTING WITH THREE BACKTICKS". An opener is
# three or more backticks or tildes, indentation tolerated, whose info string carries no
# backtick; a closer is the same character, at least as many of it, and nothing else. The
# backtick-in-info-string clause is what keeps the inline-span line above from opening a fence.
# Indentation is tolerated in FULL where CommonMark allows three spaces: a delimiter indented
# four or more is read as a delimiter here and as literal content there. Permissive direction,
# and the shape tests below read the UNSTRIPPED line, so an indented heading is still not
# entry-shaped.
#
# WHAT THIS DOES NOT GUARANTEE. A prose-titled (id-less) entry-shaped line after a fence that
# never closes, or after a closer carrying trailing text, is read as fenced and opens nothing
# -- silently, because the reset that reverify reports fires only on an id-keyed line. On the
# reference consumer's four ledger files the only such line is the fenced timestamp heading the
# filing names. A fence still open at end of file IS reported, by reverify's END rule.
#
# STATEFUL, MEMOISED ON NR. Callers ask this once per line and some ask twice
# (`warn-shadowed-local-validators.sh` has two pattern rules on one line), so the fence
# decision is taken once per NR and replayed; state resets at FNR==1 so a second file in one
# awk run starts clean. `__lef_reset` carries the NR at which an id-keyed boundary reset an
# open fence, for readers that report it.
#
# `ledger_entry_id()` LIVES IN THIS EMITTER NOW, because the shape rule reads it. It used to
# be `ledger_entry_id_awk()` on its own, and every caller loaded both; that emitter is kept as
# a no-op so those concatenations still parse, and its header says why.
ledger_entry_awk() {
  cat <<'AWK'
function ledger_entry_id(label) {
  if (match(label, /^`?(PC|BL)-[A-Za-z0-9_.-]+/))
    return substr(label, RSTART, RLENGTH)
  return ""
}
function ledger_entry_shape(l,   t, rest, sh, line) {
  if (FNR == 1 && __lef_nr != NR) { __lef_in = 0; __lef_stray = 0 }
  if (__lef_nr == NR) return __lef_shape
  __lef_nr = NR; __lef_reset = 0
  sh = ""
  if (l ~ /^- \*\*/)           sh = "bullet"
  else if (l ~ /^#{2,6}[ \t]/) sh = "heading"
  t = l; sub(/^[ \t]+/, "", t)
  if (!__lef_in) {
    if (match(t, /^```+/) || match(t, /^~~~+/)) {
      rest = substr(t, RLENGTH + 1)
      if (substr(t, 1, 1) == "~" || index(rest, "`") == 0) {
        # A closer-shaped line right after a reset is the CLOSER of the fence the reset broke
        # out of -- a quoted entry heading still has its fence closed below it -- so it is
        # consumed rather than read as a new opener, which would invert parity until the next
        # delimiter and report the next real entry as fenced too.
        if (__lef_stray && rest ~ /^[ \t]*$/) { __lef_stray = 0 }
        else { __lef_in = 1; __lef_ch = substr(t, 1, 1); __lef_len = RLENGTH; __lef_stray = 0 }
        sh = ""
      }
    } else if (sh != "") __lef_stray = 0
    # THE FLAG CLEARS ON THE NEXT ENTRY-SHAPED LINE, AND THAT IS A MEASURED CHOICE. After a
    # reset the tracker cannot tell an UNTERMINATED fence (the next bare delimiter is a real
    # opener) from a fence QUOTING headings (the next bare delimiter is its closer). Letting the
    # flag survive entry-shaped lines serves the quoting case and, on the reference consumer's
    # archive, turned 2 true resets into 9 by eating the next real opener after each of its
    # unterminated fences. Clearing it here serves the unterminated case, which is the one that
    # exists on every corpus measured, and costs the quoting case ONE false row on the entry
    # after a fence that quotes TWO headings -- beside the true row about the same fence.
    # `core/fixtures/ledger-reverify` pins both sides.
  } else {
    if ((match(t, /^```+[ \t]*$/) || match(t, /^~~~+[ \t]*$/)) && substr(t, 1, 1) == __lef_ch) {
      match(t, /^[`~]+/)
      if (RLENGTH >= __lef_len) { __lef_in = 0; sh = "" }
    }
    if (__lef_in && sh != "") {
      line = l
      if (sh == "heading") sub(/^#{2,6}[ \t]+/, "", line); else sub(/^- \*\*/, "", line)
      if (ledger_entry_id(line) != "") { __lef_in = 0; __lef_stray = 1; __lef_reset = NR }
      else sh = ""
    }
  }
  __lef_shape = sh
  return sh
}
AWK
}

# WHICH BOUNDARY LINES CARRY AN ENTRY ID -- the second half of the boundary question, and it
# is here for the same reason the shape rule is: two tools disagreeing about what counts as an
# id is itself a bug. `ledger-entry-boundary-measurement.md` closes on "Fix
# `lib.sh` once ... both readers must move together", and this is that once.
#
# THE SHAPE RULE ALONE CANNOT SAY WHETHER A `- **` BULLET IS AN ENTRY OR AN ANNOTATION, AND
# NOTHING CAN. An annotation written as a lead-in is byte-indistinguishable from an entry
# written as a title. So neither reader guesses. `ledger-rotate.sh` uses this to REFUSE an
# input it would corrupt, and `ledger-reverify.sh` uses it to REPORT a capture it would
# otherwise perform silently. Both are the non-destructive direction; the shape rule keeps
# deciding boundaries, so no legacy id-less entry stops being seen.
#
# ANCHORED AT THE START OF THE LABEL, DELIBERATELY. An unanchored match is satisfied by an
# annotation that MENTIONS another entry -- `- **Note: see PC-S300 for detail**` -- which would
# make the rotator's guard fall silent on exactly the line it exists to catch. A real entry
# opens with its own id; a reference to one does not.
#
# THE CHARACTER CLASS IS WIDER THAN `ledger-reverify.sh`'s LOCAL `idshape()` WAS, AND THAT WAS
# A LIVE FALSE NEGATIVE. `idshape()` required `^[A-Z0-9-]+$`, which excludes `_` and `.`;
# measured over the reference consumer, `PC-S330-PREPUSH-LEAKS-GIT_DIR-INTO-EVERY-FIXTURE-`
# `SANDBOX` and `PC-S300-SEVEN-VALIDATORS-SHIPPED-NON-EXECUTABLE-AT-0.242.0` each failed it --
# one real entry in the live ledger and one in the archive, scored as annotations. Neither
# produced a wrong row under the old colon gate, because that gate fired on nothing at all.
# A leading backtick is tolerated because the ledger's own label rule strips backticks only
# after the caller has extracted the span.
# THE `BL-` LABEL RULE -- distinct from `ledger_entry_id()` below, and the distinction is
# load-bearing rather than stylistic. Its readers are the distribution's own backlog tooling; a
# consumer tree carries no `BL-` ledger, so nothing here fires there.
#
# WHY IT IS NOT `ledger_entry_id()`. That one is backtick-tolerant by design (see its header), and
# the `BL-` readers do not strip backticks before matching. Measured on the live backlog: this rule
# counts 65 entries and `ledger_entry_id()` counts 68, the three extra being prose cross-reference
# bullets of the form `- **`BL-081`'s receipt**`. The next author will reach for the shared id
# function on principle; this exists so that reaching for the shared thing is still correct.
#
# WHY IT IS HERE AND NOT IN ITS CALLER. It was defined in `backlog-rotate.sh`, whose own comment
# said it "is defined ONCE ... A guard keyed on a restatement of the predicate it protects drifts
# from it." A second reader -- the backlog depth ceiling -- then needed it and restated it, which
# is exactly the drift this file's `ledger_entry_awk` header records happening within ONE release.
# Moved here so both readers load it. NOTE this does NOT unify rotate's and reverify's label rules
# with each other -- that stays barred for the reason stated above, because it would change
# rotate's `moved-names` output.
backlog_entry_label_awk() {
  cat <<'AWK'
function backlog_entry_label(l,   line, shape) {
  shape = ledger_entry_shape(l)
  if (shape == "") return ""
  line = l
  if (shape == "heading") { sub(/^#{2,6}[ \t]+/, "", line) }
  else                    { sub(/^- \*\*/, "", line); sub(/\*\*.*$/, "", line) }
  if (match(line, /^BL-[0-9]+/)) return substr(line, 1, RLENGTH)
  return ""
}
AWK
}

# A NO-OP, DELIBERATELY. `ledger_entry_id()` is emitted by `ledger_entry_awk()` above, because
# the fence-aware shape rule reads it. Callers concatenate `"$(ledger_entry_awk)$(ledger_entry_id_awk)"`
# and defining the function twice is an awk error, so this emits NOTHING -- not a comment, which
# `$( )` would strip the newline from and which would then swallow the first line of whatever is
# concatenated after it.
ledger_entry_id_awk() { :; }

# WHICH BODY LINES CLOSE AN ENTRY -- lifted from `ledger-reverify.sh`, never restated.
#
# THE DEFECT THIS REPLACES, MEASURED. `ledger-rotate.sh` reported its "closed for re-verification
# but not archivable" set on an UNANCHORED phrase test while `ledger-reverify.sh` decided the same
# question with a LINE-LEADING anchor, and rotate's own comment called the loose form
# "reverify.sh entry_line_closes(), restated as the LOOSE side of the same question" -- a
# restatement of a mechanism rather than a citation of it, and wrong about which mechanism:
# `entry_line_closes()` is applied to the ENTRY LINE, while the BODY rule is the anchored one this
# function lifts. On the reference consumer the report named 12 entries and 7 of them were OPEN,
# including the very entry that filed the defect. Four predicates across three programs had
# drifted the same way, so this is single-homed rather than corrected in place.
#
# WHY THIS READS THE SIBLING RATHER THAN OWNING THE REGEX. Moving the predicate INTO this file was
# built and measured too. It gives the same correct answer and it breaks two INDEPENDENT anchors
# that key on the emitting line's text: `core/fixtures/ledger-reverify/run.sh`'s mutation arm,
# which then reports "the mutation matched nothing, so the anchor assertions above are unproven",
# and the backlog receipt that certifies this very fix. Reading the line leaves
# `ledger-reverify.sh` byte-unchanged, so both keep working and the grammar still exists once.
#
# THE LIFT SHAPE IS THIS DIRECTORY'S OWN. `map_consumer()` is defined once in `preclassify.sh` and
# eval'd out of it by six other programs; this is that pattern for an awk rule rather than a shell
# function.
#
# IT REFUSES RATHER THAN GUESSING, IN BOTH DIRECTIONS. No matching line means the emitter moved or
# was reworded, and a silently empty predicate would make every caller decide that NOTHING is
# closed -- a rotation guard that permits everything, reading exactly like one that found nothing
# to stop. More than one match means the grammar is no longer single-homed, and lifting "the" line
# is then not a question with an answer.
#
# THE FINDER MUST NOT HAND-LIST THE TOKEN SET IT IS LOOKING FOR, AND IT DID. This grep used to
# spell `\(ADOPTED UPSTREAM\|WITHDRAWN\)` — the emitter's alternation, verbatim — so ADDING a
# close token to the single home silently matched 0 and every caller refused. MEASURED at exactly
# that point in this change: adding `CLOSED AS REJECTED` to the two predicates in
# `ledger-reverify.sh` took both finders here from 1 to 0 in the same invocation, against a
# control of 1 for the relaxed forms below and 0 for an impossible token. That is the LOUD
# direction — `ledger_close_awk` refuses, the caller exits 2 — but it means the single home is
# not single: it is one grammar joined to a copy of its own membership, and the copy is here.
# The finders now key on the STRUCTURE of the rule (a line-pattern setting `closed=1`; a `return`
# testing `s`) plus ONE anchor token that is load-bearing for every spelling, and the
# exactly-one guard is what keeps that anchor from matching two rules.
#
# THE PATTERN IS EXTRACTED ONCE, BY `ledger_close_awk_pattern()`, because `ledger_archive_awk()`
# below DERIVES rotation's grammar from the same bytes. Two extractions of one line are two
# chances to disagree about what that line says, which is the failure this whole block exists to
# prevent, one level down.
ledger_close_awk_pattern() { # the BODY close regex, bare, on stdout
  _lca_src="${SELF:-.}/ledger-reverify.sh"
  _lca_re_find='^[[:space:]]*/.*ADOPTED UPSTREAM.*closed=1 \}$'
  if [ ! -r "$_lca_src" ]; then
    echo "lib.sh: ledger_close_awk cannot read $_lca_src -- the close grammar is single-homed there and must not be restated here" >&2
    return 1
  fi
  _lca_n="$(grep -cE "$_lca_re_find" "$_lca_src")"
  if [ "$_lca_n" != 1 ]; then
    echo "lib.sh: ledger_close_awk found $_lca_n candidate close rules in $_lca_src, expected exactly 1 -- the grammar is not single-homed, so there is no line to lift" >&2
    return 1
  fi
  _lca_rule="$(grep -E "$_lca_re_find" "$_lca_src")"
  _lca_pat="$(printf '%s\n' "$_lca_rule" | sed -E 's|^[[:space:]]*/(.*)/[[:space:]]*\{[[:space:]]*closed=1[[:space:]]*\}[[:space:]]*$|\1|')"
  if [ -z "$_lca_pat" ] || [ "$_lca_pat" = "$_lca_rule" ]; then
    echo "lib.sh: ledger_close_awk could not extract a pattern out of: $_lca_rule" >&2
    return 1
  fi
  printf '%s\n' "$_lca_pat"
}
ledger_close_awk() {
  _lcw_pat="$(ledger_close_awk_pattern)" || return 1
  printf 'function ledger_body_closes(l) { return (l ~ /%s/) }\n' "$_lcw_pat"
}

# ledger_archive_awk() — ROTATION's grammar, DERIVED from the skip grammar rather than
# hand-listed beside it.
#
# THE DEFECT THIS CLOSES, MEASURED. `ledger-reverify.sh` honoured a SET of close tokens;
# `ledger-rotate.sh` archived on ONE literal, `**ADOPTED UPSTREAM (v[0-9]`, written out at three
# sites and containing the token `WITHDRAWN` zero times (control, same file: `ADOPTED UPSTREAM`
# 19 times; impossible token 0). An entry closed by a token rotate could not spell was therefore
# SKIPPED by every re-verification and REFUSED by every rotation at once — invisible in the report
# and permanently resident in the live ledger. `ledger-rotate.sh` already named that class
# "closed-and-unarchivable" in its own stuck-report comment, having never been able to shrink it.
# Measured on the reference consumer live ledger at this change: SIX entries stranded, five of
# which this grammar takes.
#
# WHAT THE TRANSFORM IS, AND WHY IT IS THE WHOLE OF ROTATION'S EXTRA STRICTNESS. The skip rule is
# anchored line-leading structure, an OPTIONAL bold span, then the token alternation. Rotation
# wants exactly the same thing with the bold span MANDATORY: an annotation opens a bold span, a
# prose mention does not. So this makes `(\*\*[^`]*)?` into `\*\*[^`]*` and changes nothing else,
# which is why a token added to the skip rule reaches rotation in the SAME edit and a fourth
# spelling cannot appear in one file alone.
#
# THE TRANSFORM IS STRICTLY NARROWING, AND THAT IS ASSERTED RATHER THAN ASSUMED. Measured over the
# reference consumer's two ledger files in one invocation: skip 5 / archive 4 on the live file and
# 265 / 265 on the archive, with the not-a-subset count ZERO on both and an impossible-token
# control 0. An archive verdict this grammar reaches is therefore always one reverify already
# skips — the acceptance invariant `ledger-rotate.sh`'s header states, now true by construction
# rather than by two authors agreeing.
#
# IT IS ALSO STRICTLY WIDER THAN THE LITERAL IT REPLACES, WHICH IS THE HALF THAT COULD LOSE WORK.
# Measured over every boundary-shaped line of both consumer files: the old `(v[0-9]` literal takes
# 0 live / 14 archived, this grammar takes 1 / 14, and the lines the OLD rule takes that this one
# does NOT number ZERO on both files. So nothing that archived before stops archiving. The one
# addition on the live file is `PC-S300-…-CITATIONS — **WITHDRAWN 2026-07-25, the premise was
# false**`, a real close this repo's own vocabulary already honoured.
#
# WHAT IT DELIBERATELY DOES NOT DO: INVENT A VERSION. The old literal demanded a digit after
# `(v`, so a genuine close that HAS no version — a withdrawal, an absorption predating the pull's
# base, a rejection adjudicated by date — could never satisfy it, and the only ways out were to
# leave the entry live forever or to annotate a falsehood. This grammar requires the annotation
# FORM and says nothing about the parenthetical, so a versionless close archives on its own terms.
# The digit anchor's own defect (`\(v` matching `(verified`) dies with the literal.
#
# REFUSES RATHER THAN GUESSING, exactly as the two lifts above do and for the same reason: an
# empty archive predicate would make rotation move NOTHING while exiting 0, which reads
# identically to a ledger with nothing closed in it.
ledger_archive_awk() {
  _lar_pat="$(ledger_close_awk_pattern)" || return 1
  # THE OPTIONAL BOLD SPAN, AS A LITERAL. The emitter writes it exactly this way; a REGEX match
  # here would be a third grammar to keep in step, and a substring test cannot silently half-match.
  _lar_opt='(\*\*[^`]*)?'
  _lar_req='\*\*[^`]*'
  case "$_lar_pat" in
    *"$_lar_opt"*) ;;
    *)
      echo "lib.sh: ledger_archive_awk cannot find the optional bold span '$_lar_opt' in the close grammar '$_lar_pat' -- rotation's extra strictness IS that span becoming mandatory, so with no span to promote there is no archive rule to derive" >&2
      return 1 ;;
  esac
  _lar_head="${_lar_pat%%"$_lar_opt"*}"
  _lar_tail="${_lar_pat#*"$_lar_opt"}"
  printf 'function ledger_body_archives(l) { return (l ~ /%s%s%s/) }\n' "$_lar_head" "$_lar_req" "$_lar_tail"

  # TWO PREDICATES, BECAUSE A CLOSE SITS IN TWO PLACES AND ONLY ONE OF THEM HAS A LINE START TO
  # ANCHOR ON. A BODY annotation is line-leading. An ENTRY-LINE close sits mid-line after the
  # title (`## PC-FOO — **WITHDRAWN …**`), so the body anchor there is not merely wrong but INERT:
  # it can never match a line beginning `- **` or `## `, and every entry line ever passed to it
  # would answer "not closed". `ledger_entry_line_close_awk` records that measurement.
  #
  # AND THE ENTRY-LINE RULE IS DERIVED FROM REVERIFY'S ENTRY-LINE RULE, NOT FROM THE BODY ONE,
  # BECAUSE THE TWO DO NOT HONOUR THE SAME SET. `entry_line_closes()` carries a SECOND disjunct
  # the body rule has never had: the retained-copy parenthetical `(original text, retained for
  # the record)`, which closes the copy a withdrawal supersedes. Deriving rotation's entry-line
  # rule from the body grammar would have left that token skipped-but-unarchivable — the exact
  # class this whole change exists to empty, surviving in the one member nobody was looking at.
  # MEASURED on the reference consumer: with the body-derived form, stuck fell 6 -> 2 and this
  # entry was one of the two.
  #
  # THE TRANSFORM IS APPLIED TO THE TOKEN TERM ONLY, AND THE RETAINED-COPY TERM IS CARRIED
  # THROUGH UNCHANGED. That is not an oversight and it is not a relaxation. A close annotation
  # opens a bold span, which is why requiring one separates an annotation from a mention; the
  # retained-copy marker is not an annotation at all but a TITLE SUFFIX, and the convention
  # writes it bare — `## PC-FOO (original text, retained for the record) — …`. Requiring a bold
  # span of it would be requiring a form it never has, which is this entry's own defect pointed
  # the other way.
  #
  # ITS FALSE-POSITIVE SET IS MEASURED OVER THE POPULATION IT IS ACTUALLY APPLIED TO, WHICH IS
  # BOUNDARY LINES AND NOT THE FILE. Across the reference consumer's live ledger and archive the
  # parenthetical occurs twice: once on a boundary line, the genuine retained copy this takes,
  # and once inside prose that DESCRIBES the convention — a line beginning with a backtick, which
  # is not boundary-shaped and which no caller ever hands to this predicate. So the set is EMPTY,
  # enumerated rather than asserted, with an impossible-token control of 0 in the same invocation.
  #
  # THE TOKEN TERM IS REPLACED, NOT EDITED IN PLACE, AND THAT IS A CORRECTNESS FIX RATHER THAN A
  # STYLE ONE. The entry-line rule writes its alternation UNGROUPED -- `/ADOPTED UPSTREAM|WITHDRAWN
  # |CLOSED AS REJECTED/` -- where the body rule wraps it in parentheses. Splicing the bold prefix
  # into the ungrouped form binds it to the FIRST alternative only (`|` is the lowest-precedence
  # operator in an ERE), so the built rule reads "bolded ADOPTED UPSTREAM, or a bare WITHDRAWN
  # anywhere on the line" -- looser than the skip rule it is supposed to narrow, which is the one
  # direction that archives live work. BUILT AND MEASURED before this note existed. So the token
  # term is taken from the BODY archive pattern, where the grouping is already correct, with only
  # the line-leading anchor dropped; the retained-copy term is carried across untouched.
  _lar_elc="$(ledger_entry_line_close_awk)" || return 1
  _lar_elc="${_lar_elc#function ledger_entry_line_closes(s) \{ }"
  _lar_elc="${_lar_elc% \}}"
  _lar_key='return (s ~ /'
  case "$_lar_elc" in
    "$_lar_key"*) ;;
    *)
      echo "lib.sh: ledger_archive_awk expected the entry-line close rule to OPEN with '$_lar_key' and got '$_lar_elc' -- rotation's entry-line grammar replaces that first term with a bolded one and carries the rest across, so a rule of another shape cannot be derived from" >&2
      return 1 ;;
  esac
  # EVERYTHING AFTER THE FIRST TERM, CARRIED VERBATIM. A rule with no second disjunct leaves this
  # empty and the built rule is the token test alone, which is the right answer for that emitter.
  _lar_rest="${_lar_elc#"$_lar_key"}"
  case "$_lar_rest" in
    */\)\ \|\|\ *) _lar_rest=" || ${_lar_rest#*/) || }" ;;
    *)             _lar_rest="" ;;
  esac
  printf 'function ledger_entry_line_archives(s) { return (s ~ /%s%s/)%s }\n' "$_lar_req" "$_lar_tail" "$_lar_rest"

  # A TITLE WRAPS, AND A CLOSE THAT STRADDLES THE WRAP IS INVISIBLE TO EVERY PER-LINE RULE.
  # An entry title is prose an operator types, so it runs long and gets broken across lines with
  # the bold span still OPEN:
  #
  #   - **PC-S311-SNAPSHOT-NEVER-ADVANCES-PAST-DEPLOY-VALIDATE-AT-SPRINT-CLOSE —
  #     ADOPTED UPSTREAM (v0.554.0, verified 2026-09-15)** —
  #
  # Neither line is a complete annotation. The first opens a bold span and carries no token; the
  # second carries the token and the CLOSING `**` but has no opener, so a rule demanding
  # `\*\*[^`]*<token>` scores it a non-instance. Every predicate in this directory is per-line,
  # so the entry was skipped by re-verification -- `entry_line_closes()` is unanchored and fires
  # on the token wherever it sits -- and refused by every rotation. Skipped-but-unarchivable
  # again, in the one shape the bold transform cannot reach.
  #
  # THE FIX NORMALISES THE INPUT RATHER THAN WIDENING THE REGEX, AND THAT CHOICE IS THE POINT.
  # A two-line regex would have to re-express the alternation across a join, which is exactly
  # where the ungrouped-alternation defect recorded above was born. Joining the lines FIRST and
  # handing the result to `ledger_entry_line_archives()` unchanged means the grammar is still
  # written once, still grouped correctly, and the straddle costs no new pattern at all.
  #
  # THE JOIN IS DELIBERATELY NOT "THE WHOLE BUFFERED ENTRY", AND THAT WAS MEASURED, NOT ASSUMED.
  # Rotation buffers every line of an entry before deciding, so a rule of the form "a bold span
  # opens on ANY buffered line and a token appears before it closes" is available and is the
  # obvious shape. It has a FALSE POSITIVE on the reference consumer live ledger, enumerated:
  # `## Validator-fork retirement record`, a human record whose own prose explains that it keys
  # on a bolded annotation and "is meant to stay whole rather than have pieces of it swept into
  # the archive". Its narrative BOLDS a phrase, and a later line quotes the convention -- so the
  # whole-buffer rule archives the very entry that documents why it must not be archived. That
  # is `ledger-rotate.sh`s instruction/narrative discrimination failing in the direction that
  # loses work. Scored over both consumer files: whole-buffer newly archives 1 live / 0 archived,
  # and that 1 is the false positive; this title join newly archives 1 live / 0 archived, and
  # that 1 is the genuine straddle. Same count, opposite entry.
  #
  # THREE CLAUSES BOUND IT, and each one is what keeps a narrative line out.
  #   - It starts ONLY on an entry-shape line whose bold span is still open. A body line can
  #     never start a join, which is what excludes the narrative case above entirely.
  #   - It ends at the first line that CLOSES the span, and tests only then. An unbalanced title
  #     joins nothing.
  #   - A BLANK line abandons it. A title wrap has no blank line in it; a body that merely opens
  #     bold is separated from the title by one, so an unterminated span cannot run on and
  #     swallow the body.
  # The token still has to sit inside the joined bold span, because the predicate handed the
  # join is byte-identical to the one handed a single line.
  printf '%s\n' 'function ledger_title_join(l,   j) {'
  printf '%s\n' '  if (__ltj_open) {'
  printf '%s\n' '    if (l ~ /^[ \t]*$/) { __ltj_open = 0; __ltj_buf = ""; return "" }'
  printf '%s\n' '    j = l; sub(/^[ \t]+/, " ", j); __ltj_buf = __ltj_buf j'
  printf '%s\n' '    if (gsub(/\*\*/, "", j) % 2 == 1) { __ltj_open = 0; j = __ltj_buf; __ltj_buf = ""; return j }'
  printf '%s\n' '    return ""'
  printf '%s\n' '  }'
  printf '%s\n' '  return ""'
  printf '%s\n' '}'
  # ARMED ONLY BY THE CALLER, ON A LINE IT HAS ALREADY CLASSIFIED AS AN ENTRY BOUNDARY. The
  # caller owns the boundary rule (`ledger_entry_shape`), so asking it to arm the join keeps the
  # one definition of "entry line" where it already lives instead of restating it here.
  printf '%s\n' 'function ledger_title_arm(l,   t) {'
  printf '%s\n' '  t = l; __ltj_open = 0; __ltj_buf = ""'
  printf '%s\n' '  if (gsub(/\*\*/, "", t) % 2 == 1) { __ltj_open = 1; __ltj_buf = l }'
  printf '%s\n' '}'
}

# ---------------------------------------------------------------------------
# THE CROSS-PROCESS BLOB/TREE MEMO — one cache, shared by every reconcile/*.sh process
# a single emit-report.sh RENDER forks.
# ---------------------------------------------------------------------------
# `ledger-reverify.sh` carried a memo first, IN-PROCESS: the same blob read many times
# inside one ledger walk. That does not touch the bigger repeat measured here (batch
# 121) — `emit-report.sh` execs roughly a dozen independent sub-detector SCRIPTS per
# render, each its own process with its own shell state, and every one of them
# re-reads the same handful of `<ref>:<path>` blobs and `<ref>` tree listings every
# OTHER sub-detector in the SAME render already read. A single render makes 4 distinct
# git calls; the fixture's 143-render matrix (13 programs x 11 worlds) turned that into
# 19219 total git invocations, 302 distinct — the repetition is ACROSS processes, not
# within one, and an in-process memo cannot see it.
#
# A FILESYSTEM CACHE IS THE ONLY SHAPE THAT CROSSES A PROCESS BOUNDARY. `declare -A`
# is unavailable on bash 3.2 for the reason this file's other notes give, and even on a
# bash that has it, an associative array lives in ONE process's memory — a child
# `bash "$SELF/x.sh"` starts a fresh interpreter that never sees it.
#
# THE CACHE DIRECTORY IS NEVER CREATED HERE — it is either handed down by an EXPORTED
# `AI_DLC_RECONCILE_MEMO` (an orchestrator, `emit-report.sh`, made ONE `mktemp -d` for
# the whole render and owns cleaning it up), or these functions fall back to
# `ledger-reverify.sh`'s original per-process shape: lazily `mktemp -d` a PRIVATE
# directory, cleaned by THIS process's own exit trap. Sharing is opt-in on the
# ENVIRONMENT, never a hardcoded path — two concurrent consumer runs that never
# exported the variable get two private directories and cannot collide, and a caller
# with no orchestrator above it (an operator invoking ledger-reverify.sh directly, or
# apply.sh) behaves exactly as it did before this cache existed.
# The three are NEVER EXPORTED, so a child process starts with none of them. They are
# preserved rather than reset when a shell sources this file a SECOND time: a reset would drop
# the owner of the directory the first source made, and that directory would then be borrowed
# through `AI_DLC_RECONCILE_MEMO` and never removed.
AI_DLC_MEMO_DIR="${AI_DLC_MEMO_DIR:-}"     # the cache directory THIS PROCESS is using, or "" when not built
AI_DLC_MEMO_STATE="${AI_DLC_MEMO_STATE:-}" # "" not attempted | ok | unavailable
AI_DLC_MEMO_OWNED="${AI_DLC_MEMO_OWNED:-}" # set only when THIS process's own mktemp made the
                        # directory — the cleanup must remove only what this process
                        # created, never a directory an orchestrator handed down and will
                        # clean up itself.
ai_dlc_memo_dir() { # 0 = $AI_DLC_MEMO_DIR holds a directory; 1 = uncacheable, go direct
  case "$AI_DLC_MEMO_STATE" in
    ok)          return 0 ;;
    unavailable) return 1 ;;
  esac
  if [ -n "${AI_DLC_RECONCILE_MEMO:-}" ] && [ -d "${AI_DLC_RECONCILE_MEMO:-}" ]; then
    AI_DLC_MEMO_DIR="$AI_DLC_RECONCILE_MEMO"
    AI_DLC_MEMO_STATE=ok
    return 0
  fi
  # THE FALLBACK, reached only when the source-time block below could not build a directory
  # (or lib.sh was itself sourced inside a subshell). A directory made HERE, in a subshell, is
  # an orphan by construction: the ownership assignment dies with the subshell and no EXIT
  # trap that survives it can name the path. So a subshell goes direct and uncached, and only
  # the main shell may still build one.
  [ "${BASH_SUBSHELL:-0}" -gt 0 ] && return 1
  AI_DLC_MEMO_STATE=unavailable
  AI_DLC_MEMO_DIR="$(mktemp -d "${TMPDIR:-/tmp}/reconcile-memo.XXXXXX" 2>/dev/null)" || return 1
  [ -n "$AI_DLC_MEMO_DIR" ] && [ -d "$AI_DLC_MEMO_DIR" ] || return 1
  AI_DLC_MEMO_OWNED="$AI_DLC_MEMO_DIR"
  AI_DLC_MEMO_STATE=ok
  return 0
}
# ai_dlc_memo_cleanup — removes `$AI_DLC_MEMO_OWNED`, never `$AI_DLC_MEMO_DIR`: the latter
# can hold a directory this process merely BORROWED from an orchestrator that cleans it up
# itself. The EXIT composition below runs it on every exit of a sourcing script; a caller that
# still invokes it from its own handler is harmless, because the owner is cleared on the first
# call and a second call finds nothing to remove.
ai_dlc_memo_cleanup() {
  [ -n "${AI_DLC_MEMO_OWNED:-}" ] && rm -rf "$AI_DLC_MEMO_OWNED"
  AI_DLC_MEMO_OWNED=""
  return 0
}

# ---------------------------------------------------------------------------
# THE MEMO IS BUILT AT SOURCE TIME, IN THE MAIN SHELL, AND CLEANED BY AN EXIT HANDLER NO
# SOURCING SCRIPT CAN REPLACE.
# ---------------------------------------------------------------------------
# The lazy shape above leaked, in two independent ways. First, the first lookup in most
# detectors runs inside `$( … | … )` (ledger-reverify's `TV="$(theirs_show VERSION | …)"`),
# so the directory was built in a subshell, `AI_DLC_MEMO_OWNED` died with it, and the main
# shell built a SECOND one at its next lookup. Every such subshell before the main shell's
# first call made one orphan. Second, only ledger-reverify.sh ever called the cleanup, so
# every other memo user leaked its main-shell directory as well. Measured, one standalone run
# each under a private TMPDIR: unregistered-drift left 105 directories, preclassify 7,
# layer-drift 4, retired-fixtures 1, ledger-reverify 1. This machine's TMPDIR held 433455
# `reconcile-memo.*` directories, none older than two days.
#
# A SUBSHELL CANNOT CLEAN UP AFTER ITSELF, so moving the cleanup into one does not work: under
# bash 3.2 an EXIT trap set in a function that runs as a pipeline stage inside `$( )` never
# fires. Measured with the trap armed inside `ai_dlc_memo_dir` whenever `$BASH_SUBSHELL` is
# non-zero: still 1 directory left.
#
# So the directory is made HERE, once, while the script is sourcing this file in its main
# shell, and EXPORTED, so every subshell and every child `bash x.sh` borrows it through the
# inherited-directory branch above instead of building its own. An orchestrator's exported
# directory is borrowed the same way and is never owned, so it is never removed.
#
# THE CLEANUP CANNOT BE LEFT TO EACH CALLER'S OWN `trap … EXIT`, because bash EXIT traps
# REPLACE each other and six sourcing scripts install their own after sourcing this file
# (ledger-reverify, unregistered-drift, register-drift, ledger-rotate, retired-layer-token,
# retired-layer-passage). A trap installed here alone would be overwritten by every one of
# them. `trap` is therefore a shell function for the rest of the sourcing script: every query
# form (`trap`, `trap -p`, `trap -l`) and every non-EXIT signal goes straight to
# `builtin trap`, and any EXIT disposition is composed with this file's cleanup running FIRST.
# First, not last, because a handler that calls `exit` ends the handler there, and a cleanup
# placed after it never runs. A reset (`trap - EXIT`, `trap EXIT`) or an ignore
# (`trap '' EXIT`) keeps the cleanup and drops only the caller's own handler.
#
# The one way round this is `builtin trap … EXIT` in a sourcing script, which replaces the
# composed handler outright. I115 in scripts/validate-enforcement-map.sh refuses that spelling,
# and the reset spellings beside it, in every file that sources this one.
#
# THE CLEANUP RUNS ONLY IN THE SHELL THAT SOURCED THIS FILE. `AI_DLC_MEMO_OWNED` is an ordinary
# variable, so a `( … )` or `$( … )` subshell inherits a copy of it, and a subshell that arms its
# own `trap X EXIT` gets the composed handler too. Without a level guard that subshell's exit
# would delete the parent's live memo halfway through the run.
#
# THE GUARD IS TAKEN WHEN THE TRAP IS SET, NOT WHEN IT FIRES. Inside the EXIT handler of a `$( )`
# subshell, bash 3.2 reports `$BASH_SUBSHELL` as 0, the main shell's level, so a handler-time
# comparison passes there and `x=$(trap : EXIT; :)` deleted the parent's live memo (measured:
# the directory was gone on return). A `( … )` subshell reports its real level and was never
# affected. So the shadow `trap` below compares levels on ENTRY, where `$BASH_SUBSHELL` is right in
# both forms, and a subshell's `trap` goes straight to `builtin trap` without the cleanup. The
# handler-time comparison stays as a second line of defence for a subshell that inherited an
# already-composed handler.
#
# THE CALLER'S HANDLER MUST STILL RUN UNDER `set -e`. `_ai_dlc_lib_exit` returns the exit status it
# was entered with, so a failing script enters the handler with a non-zero `$?`, and a bare
# `_ai_dlc_lib_exit` as the handler's first command then trips errexit and ends the handler
# before the caller's own command runs (measured: `set -e; trap 'echo OWN' EXIT; false` printed
# nothing). The composition is therefore `_ai_dlc_lib_exit && :`, a list errexit does not act on,
# which leaves `$?` at the original status for the caller's handler to read.
_ai_dlc_lib_exit() { # preserves $?, so a caller's handler that reads it still sees the exit status
  local _rc=$?
  [ "${BASH_SUBSHELL:-0}" -eq "${_AI_DLC_LIB_LEVEL:-0}" ] && ai_dlc_memo_cleanup
  return "$_rc"
}
_AI_DLC_LIB_LEVEL="${BASH_SUBSHELL:-0}"
trap() {
  local _a _h _exit=0 _rest=""
  [ "${BASH_SUBSHELL:-0}" -eq "${_AI_DLC_LIB_LEVEL:-0}" ] || { builtin trap "$@"; return; }
  case "${1:-}" in
    --) shift ;;
    -?*) builtin trap "$@"; return ;;
  esac
  [ "$#" -eq 0 ] && { builtin trap; return; }
  if [ "$#" -eq 1 ]; then _h=-; else _h="$1"; shift; fi
  for _a in "$@"; do
    case "$_a" in
      EXIT|exit|0) _exit=1 ;;
      *) _rest="$_rest $_a" ;;
    esac
  done
  if [ -n "$_rest" ]; then
    # shellcheck disable=SC2086 # signal names carry no whitespace; the split is the point
    builtin trap -- "$_h" $_rest || return
  fi
  [ "$_exit" -eq 1 ] || return 0
  # A handler read back with `trap -p` and re-armed already carries the cleanup; it is stripped
  # here so the composition never stacks it twice.
  _h="${_h#_ai_dlc_lib_exit && :
}"
  case "$_h" in
    -|''|_ai_dlc_lib_exit) builtin trap _ai_dlc_lib_exit EXIT ;;
    *)    builtin trap "_ai_dlc_lib_exit && :
$_h" EXIT ;;
  esac
}
if [ "${BASH_SUBSHELL:-0}" -eq 0 ]; then
  if [ -n "${AI_DLC_RECONCILE_MEMO:-}" ] && [ -d "${AI_DLC_RECONCILE_MEMO:-}" ]; then
    AI_DLC_MEMO_DIR="$AI_DLC_RECONCILE_MEMO"
    AI_DLC_MEMO_STATE=ok
  else
    _ai_dlc_m="$(mktemp -d "${TMPDIR:-/tmp}/reconcile-memo.XXXXXX" 2>/dev/null)" || _ai_dlc_m=""
    if [ -n "$_ai_dlc_m" ] && [ -d "$_ai_dlc_m" ]; then
      AI_DLC_MEMO_DIR="$_ai_dlc_m"
      AI_DLC_MEMO_OWNED="$_ai_dlc_m"
      AI_DLC_MEMO_STATE=ok
      AI_DLC_RECONCILE_MEMO="$_ai_dlc_m"
      export AI_DLC_RECONCILE_MEMO
    fi
    unset _ai_dlc_m
  fi
  # AN EXIT HANDLER ARMED BEFORE THIS FILE WAS SOURCED IS KEPT, not overwritten: it is read back
  # and re-armed through the composing `trap` above. `trap -p` inside `$( )` reports the parent's
  # disposition on bash 3.2, and its output is `trap -- '<handler>' EXIT`, re-read here as words.
  # A handler that already carries the cleanup came from an earlier source of this file in the
  # same shell, and the composing `trap` strips it before re-arming, so it is never doubled.
  _ai_dlc_prev="$(builtin trap -p EXIT)"
  if [ -n "$_ai_dlc_prev" ]; then
    _ai_dlc_h() { _ai_dlc_prev="$2"; }
    eval "_ai_dlc_h ${_ai_dlc_prev#trap }"
    unset -f _ai_dlc_h
    trap "$_ai_dlc_prev" EXIT
  else
    builtin trap _ai_dlc_lib_exit EXIT
  fi
  unset _ai_dlc_prev
fi

# --- ONLY A GIT ANSWER IS CACHED, NEVER A GIT FAILURE ------------------------------------------
#
# Every memo below used to write `$?` into its `.s` file whatever it was. A git that FAILED --
# a fork refused under load, an index lock, a PATH shim returning 128 -- was therefore cached as
# if it were git's answer, and every later lookup of that key in the same render was served the
# failure without git being asked again. Measured with a git shim returning 128 once: the key's
# `.s` held `128` and every later preclassify in the render read the path as absent.
#
# So each memo caches only the statuses that are its subcommand's ANSWERS, measured per
# subcommand on this machine rather than recalled:
#
#   rev-parse -q --verify "${rev}:<path>"  0 present; 1 absent path OR unresolvable rev; 128 a git
#                                        that could not run (not a repository). Cache 0 and 1.
#   ls-tree -r --name-only <ref>         0 only. A bad ref is 128, the same as a failure.
#   diff --no-renames --name-status      0 only (no --exit-code). A bad ref is 128.
#   show "${rev}:<path>", cat-file -e    0 present; 128 for an absent path AND for a failure --
#                                        the two are the same status. A 128 is cached only when
#                                        `rev-parse -q --verify` on the SAME spec answers 1, the
#                                        one command whose status separates them. It costs one
#                                        fork per MISSED key, once per render.
#
# Anything else is returned to the caller UNCACHED, so the next lookup asks git again. The fill
# goes to a per-process temp and is renamed into place only when it is cacheable, so an uncached
# failure never leaves bytes a later reader could mistake for an answer; the `.s` file is still
# written LAST, so an interrupted fill reads as a miss rather than as a cached lie.
_ai_dlc_memo_absent() { # <dist> <spec> -> 0 only when git itself says the spec does not resolve
  git -C "$1" rev-parse -q --verify "$2" >/dev/null 2>&1
  [ "$?" -eq 1 ]
}
_ai_dlc_memo_commit() { # <file-stem> <tmp> <status> -> cache the fill; always serves it
  mv -f "$2" "$1.c" 2>/dev/null || { cat "$2"; rm -f "$2"; return 0; }
  { printf '%s' "$3" > "$1.s"; } 2>/dev/null
  cat "$1.c"
}

# --- A MEMO FILE THAT CANNOT BE CREATED MUST NOT CHANGE THE ANSWER ---------------------------
#
# Every memo file is named after its key, and the key embeds the percent-encoded dist path. Past
# the 255-character filename limit, or in a memo directory that cannot be written (read-only, or
# ENOSPC at file creation -- the realistic trigger on a full disk), the fill's `> "$_t"` redirect
# failed before git ever ran. The fill then reported the REDIRECT's status as git's, served the
# temp it never wrote, and returned 1 with no output. Measured at the previous release, one
# process per case: a 372-character dist and a `chmod 555` memo each read WRONG on 7 of 11
# per-function cells (a present blob, an empty blob, a rev-parse, the ls-tree listing and the
# diff all came back empty with status 1), and `preclassify.sh` from a long dist emitted 0 bytes
# with exit 0. No refusal, no stderr the caller keeps -- a present path read as absent.
#
# So on a MISS the fill file is created FIRST, as an empty file under its real name, and a miss
# whose fill file cannot be created goes to the function's own direct line -- the same one an
# unavailable memo takes -- which asks git uncached. The probe is on `$_t` itself, not on `.c`:
# the temp carries `.$$.$RANDOM` past `.c`, so a probe of the shorter name passes at key lengths
# where the fill still fails. A HIT pays nothing new; only a miss pays the probe.
#
# No length bound and no hash. A bound cannot see an unwritable directory at any length (a short
# key in a `chmod 555` memo reads exactly as wrong), and the percent-encoded key is injective
# where a short hash is not. The `.s` write after a fill discards its own error, and the fill
# returns the status it holds in memory, never a read-back of `.s`: only a HIT reads `.s`.
#
# _ai_dlc_memo_open <key> -- sets the CALLER's `_f` (the file stem) and `_t` (the fill temp, or ""
# on a hit), which bash's dynamic scope reaches because every caller declares both `local`.
# 0 = serve from the memo (a hit, or a miss whose fill file now exists); 1 = go direct.
_ai_dlc_memo_open() {
  ai_dlc_memo_dir || return 1
  _f="$AI_DLC_MEMO_DIR/$1"
  _t=""
  [ -f "$_f.s" ] && return 0
  _t="$_f.c.$$.$RANDOM"
  { : > "$_t"; } 2>/dev/null
}
_ai_dlc_memo_serve() { # <tmp> -> serve an uncacheable fill and discard it
  cat "$1"; rm -f "$1"
}

# memo_show <dist> <ref> <path> -- the blob on stdout, git's own exit status preserved.
# A MISS AND AN EMPTY BLOB ARE DIFFERENT STATES, and the status file (`.s`) is what
# separates them: `git show` of an ABSENT path writes nothing and exits non-zero,
# `git show` of an EMPTY blob writes nothing and exits 0.
memo_show() {
  local _dist="$1" _ref="$2" _path="$3" _k _f _st _t
  _k="s $_dist $_ref:$_path"; _k="${_k//%/%25}"; _k="${_k//\//%2F}"
  _ai_dlc_memo_open "$_k" || { git -C "$_dist" show "${_ref}:${_path}" 2>/dev/null; return $?; }
  if [ -n "$_t" ]; then
    git -C "$_dist" show "${_ref}:${_path}" > "$_t" 2>/dev/null
    _st=$?
    if [ "$_st" -eq 0 ] || { [ "$_st" -eq 128 ] && _ai_dlc_memo_absent "$_dist" "${_ref}:${_path}"; }; then
      _ai_dlc_memo_commit "$_f" "$_t" "$_st"
    else
      _ai_dlc_memo_serve "$_t"
    fi
    return "$_st"
  fi
  # `cat`, NOT `printf '%s\n' "$(<f)"`. A command substitution strips EVERY trailing
  # newline and the printf adds exactly one back, so a blob with none comes back one byte
  # LONGER and a blob with three comes back two bytes shorter. Measured on this tree:
  # core/hooks/ai-dlc-continue.sh 90735 -> 90736, core/schemas/provenance-block.json
  # 26564 -> 26565, an empty blob 0 -> 1. The single-trailing-newline case -- every normal
  # file -- is byte-identical either way, which is why the round trip reads correct.
  # unregistered-drift.sh pipes this straight into `cmp -s -`, where the spurious byte
  # reports a byte-identical consumer file as DRIFTED. One fork per hit is the price of
  # serving bytes; the git call this replaces costs far more.
  cat "$_f.c"
  _st="$(<"$_f.s")"
  return "$_st"
}

# memo_has_path <dist> <ref> <path> -- 0 when the path exists at the ref. THE STATUS IS
# THE ANSWER here, unlike memo_show, so it is the only thing cached.
memo_has_path() {
  local _dist="$1" _ref="$2" _path="$3" _k _f _st _t
  _k="e $_dist $_ref:$_path"; _k="${_k//%/%25}"; _k="${_k//\//%2F}"
  # The probe is a TEMP renamed onto `.s`, never an empty `.s` created in place: an empty `.s`
  # left behind by an uncacheable status would be read by the next HIT as `return ""`, which is
  # 255, the very wrong answer this guard exists to prevent.
  _ai_dlc_memo_open "$_k" || { git -C "$_dist" cat-file -e "${_ref}:${_path}" 2>/dev/null; return $?; }
  if [ -n "$_t" ]; then
    git -C "$_dist" cat-file -e "${_ref}:${_path}" 2>/dev/null
    _st=$?
    # 128 is BOTH "absent" and "git could not answer" for `cat-file -e`; only the former is cached.
    if [ "$_st" -eq 0 ] || { [ "$_st" -eq 128 ] && _ai_dlc_memo_absent "$_dist" "${_ref}:${_path}"; }; then
      { printf '%s' "$_st" > "$_t" && mv -f "$_t" "$_f.s"; } 2>/dev/null || rm -f "$_t"
    else
      rm -f "$_t"
    fi
    return "$_st"
  fi
  _st="$(<"$_f.s")"
  return "$_st"
}

# memo_rev_parse <dist> <spec> -- `git rev-parse -q --verify <spec>`'s stdout (a sha, or
# empty) on stdout, exit status preserved. <spec> is typically `<ref>:<path>` and it IS
# the whole key, percent/slash-escaped exactly as memo_show's key is, so two different
# specs never collide.
memo_rev_parse() {
  local _dist="$1" _spec="$2" _k _f _st _t
  _k="r $_dist $_spec"; _k="${_k//%/%25}"; _k="${_k//\//%2F}"
  _ai_dlc_memo_open "$_k" || { git -C "$_dist" rev-parse -q --verify "$_spec" 2>/dev/null; return $?; }
  if [ -n "$_t" ]; then
    git -C "$_dist" rev-parse -q --verify "$_spec" > "$_t" 2>/dev/null
    _st=$?
    # 0 resolved, 1 does not resolve -- `-q --verify`'s two answers. Anything else is a failure.
    case "$_st" in
      0|1) _ai_dlc_memo_commit "$_f" "$_t" "$_st" ;;
      *)   _ai_dlc_memo_serve "$_t" ;;
    esac
    return "$_st"
  fi
  # `cat` for the same reason memo_show uses it: a `$(<f)` round trip rewrites the trailing
  # newline count. A failed rev-parse writes an EMPTY file, which the printf form served as
  # a bare newline rather than as nothing.
  cat "$_f.c"
  _st="$(<"$_f.s")"
  return "$_st"
}

# memo_ls_tree <dist> <ref> -- the FULL recursive `ls-tree -r --name-only <ref>`
# listing (no pathspec), one line per path, on stdout. git's exit status preserved.
#
# EVERY CALL SITE THAT PASSED A PATHSPEC FILTERS THIS OUTPUT ITSELF, AFTERWARDS, WITH A
# LITERAL-PREFIX GREP — never by asking git to filter a second time. `tool-hazards.md`:
# `ls-tree` does not glob a pathspec; it matches by literal PREFIX, so `-- core/` and
# `-- core/fixtures` are both exactly "every line of the unfiltered listing whose path
# starts with that string". Filtering the cached full listing afterwards is
# byte-identical to asking git to filter it a second time, and it is what lets several
# call sites across several files, each with a DIFFERENT pathspec (or none), share one
# cached read of the same `<dist,ref>` pair instead of one cached read per pathspec.
memo_ls_tree() {
  local _dist="$1" _ref="$2" _k _f _st _t
  _k="t $_dist $_ref"; _k="${_k//%/%25}"; _k="${_k//\//%2F}"
  _ai_dlc_memo_open "$_k" || { git -C "$_dist" ls-tree -r --name-only "$_ref" 2>/dev/null; return $?; }
  if [ -n "$_t" ]; then
    git -C "$_dist" ls-tree -r --name-only "$_ref" > "$_t" 2>/dev/null
    _st=$?
    if [ "$_st" -eq 0 ]; then _ai_dlc_memo_commit "$_f" "$_t" "$_st"; else _ai_dlc_memo_serve "$_t"; fi
    return "$_st"
  fi
  cat "$_f.c"
  _st="$(<"$_f.s")"
  return "$_st"
}

# memo_diff_name_status <dist> <base> <theirs> <pathspec...> -- `git diff --no-renames
# --name-status <base> <theirs> -- <pathspec...>`'s stdout, exit status preserved. The
# PATHSPEC is part of the key (unlike memo_ls_tree, git diff genuinely filters server-side
# and there is exactly one call site of this shape today), so this does not need the
# filter-the-full-answer-locally discipline memo_ls_tree uses.
memo_diff_name_status() {
  local _dist="$1" _base="$2" _theirs="$3" _k _f _st _t; shift 3
  _k="d $_dist $_base $_theirs $*"; _k="${_k//%/%25}"; _k="${_k//\//%2F}"; _k="${_k// /%20}"
  _ai_dlc_memo_open "$_k" || { git -C "$_dist" diff --no-renames --name-status "$_base" "$_theirs" -- "$@" 2>/dev/null; return $?; }
  if [ -n "$_t" ]; then
    git -C "$_dist" diff --no-renames --name-status "$_base" "$_theirs" -- "$@" > "$_t" 2>/dev/null
    _st=$?
    if [ "$_st" -eq 0 ]; then _ai_dlc_memo_commit "$_f" "$_t" "$_st"; else _ai_dlc_memo_serve "$_t"; fi
    return "$_st"
  fi
  cat "$_f.c"
  _st="$(<"$_f.s")"
  return "$_st"
}

# ledger_entry_line_close_awk() — the ENTRY-LINE close rule, lifted from the same single home.
#
# WHY A SECOND LIFT RATHER THAN REUSING THE FIRST. `ledger_body_closes()` is ANCHORED at `^[ \t]*`
# because the ledger is prose that discusses closes as well as carrying them. A boundary line
# begins `- **` or `## `, so that anchor can NEVER match one -- and a caller that tests a boundary
# line with the body rule gets a predicate that is not merely wrong but INERT, silently answering
# "not closed" for every entry line ever passed to it. Measured while building exactly that: the
# arm asserting a versionless boundary-line close becomes a reported stuck row failed, because the
# body rule could not fire on a bullet.
#
# reverify answers the boundary question with `entry_line_closes()`, which is deliberately
# unanchored, and that is the rule a caller asking "would reverify skip this entry" must use.
# Lifted rather than restated for the reason the function above states: a second copy of a
# grammar is a second thing to keep in step, and this directory already lost that bet twice.
#
# THE EXTRACTION KEYS ON THE `return` LINE, not on the function header, because the header
# carries no grammar and a header-keyed grep would happily lift a renamed function`s body.
ledger_entry_line_close_awk() {
  _elc_src="${SELF:-.}/ledger-reverify.sh"
  # LITERAL PARENS AND A LITERAL PIPE, as in the sibling above: under `grep -E` a backslashed
  # `\(` `\|` `\)` matches those characters, which is what the target line actually contains.
  # Written unescaped they are a group and an alternation, and the group never closes -- the
  # shim reports `error at position 66` rather than matching nothing, which at least fails loudly.
  # TOKEN-SET-AGNOSTIC, for the reason `ledger_close_awk` above states at length: a finder that
  # spells the alternation it is hunting scores 0 the day a close token is added, and the single
  # home stops being single. `[^/]*` spans whatever the alternation holds; the exactly-one guard
  # below is what stops this matching a second `return (s ~ /…/)` rule.
  _elc_re_find='^[[:space:]]*return \(s ~ /[^/]*ADOPTED UPSTREAM[^/]*/\)'
  if [ ! -r "$_elc_src" ]; then
    echo "lib.sh: ledger_entry_line_close_awk cannot read $_elc_src -- the entry-line close grammar is single-homed there and must not be restated here" >&2
    return 1
  fi
  _elc_n="$(grep -cE "$_elc_re_find" "$_elc_src")"
  if [ "$_elc_n" != 1 ]; then
    echo "lib.sh: ledger_entry_line_close_awk found $_elc_n candidate entry-line close rules in $_elc_src, expected exactly 1 -- the grammar is not single-homed, so there is no line to lift" >&2
    return 1
  fi
  _elc_body="$(grep -E "$_elc_re_find" "$_elc_src" | sed -E 's|^[[:space:]]*||')"
  printf 'function ledger_entry_line_closes(s) { %s }\n' "$_elc_body"
}
