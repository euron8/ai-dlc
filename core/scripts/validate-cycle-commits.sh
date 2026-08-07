#!/usr/bin/env bash
# validate-cycle-commits.sh
#
# Usage: ./validate-cycle-commits.sh [branch]
#
# Verifies that each planning artifact recorded in
# _bmad-output/validation-cycle-log.md has >=3 distinct cycle commits AND that
# the commit count agrees with the log's row count for that artifact.
#
# Two counting strategies, both must agree for PASS:
#   1. LOG-BASED: count rows per artifact section in validation-cycle-log.md.
#      Each row's commit SHA (if present) must exist on the branch, or the row
#      is "TBD" (a pending commit for the current story).
#   2. COMMIT-BASED: count commits on the branch whose subject matches
#      "Sprint N <artifact>: <cycle>", normalized so "discovery" counts toward
#      the sprint's first brief, "research-requirements" toward its first PRD,
#      and "stories-test-strategy" toward its stories.
#
# PASS per artifact:
#   - log_row_count >= MIN_CYCLES
#   - commit_count  >= MIN_CYCLES
#   - |log_row_count - commit_count| <= 1   (tolerate one TBD row)
#   - the commit set includes >=1 party-mode commit AND >=1 adversarial-review
#     commit (cycle-type coverage)
#
# Trunk base: commits are counted over "<trunk>..<branch>". Trunk defaults to
# "main"; override with AI_DLC_TRUNK.
#
# Exit codes:
#   0  -- all artifacts pass
#   1  -- one or more artifacts fail, or validation-cycle-log.md missing
#
# ----------------------------------------------------------------------------
# SECOND MODE: --audit-trunk [<genesis>]  -- the POST-MERGE TRUNK AUDIT.
#
# Usage: ./validate-cycle-commits.sh --audit-trunk [<genesis-sha>]
#
# The cycle-commit mode above audits a BRANCH before it lands. This one audits
# what actually LANDED, and it exists because the two hooks that enforce the
# process both watch a path a merge can go around. The PreToolUse hook sees only
# the agent's own tool calls; the pre-push hook sees only a push. A
# `gh pr merge --admin`, a merge from the web UI and a direct push to the trunk
# skip both -- and none of them can skip being a commit on the trunk. That is the
# only property this mode relies on.
#
# Per commit in <genesis>..<trunk>, first-parent, oldest first:
#   1. derive its changed paths and added lines from git
#   2. resolve it to a class declared in the consumer's PR-class taxonomy
#   3. check that commit's OWN tree out into a detached worktree and RE-RUN the
#      class's declared validators against it
#   4. advance the watermark to the last clean commit, stopping at the first
#      finding
#
# THE VERDICT COMES FROM THE RE-RUN, NEVER FROM A LOG. A gate log is local,
# gitignored, machine-specific and absent on a fresh clone, and the merge this
# mode exists to catch never wrote one. Re-derivation from the committed tree is
# reproducible anywhere, which is what makes the audit an instrument rather than
# a record of one.
#
# FAIL CLOSED ON AN UNRESOLVED CLASS. A trunk commit matching no declared class
# is a FINDING, not a skip -- an unclassifiable change on the trunk is the shape
# of the thing being looked for. A class that legitimately owes nothing is
# declared with `validator: none`, so "owes nothing" is a statement and not a
# silence.
#
# THE TAXONOMY IS THE CONSUMER'S AND CORE DOES NOT INFER IT. Which classes exist
# and what each owes are facts about the project, not about ai-dlc. Core derives
# the enumeration, the diff, the checkout and the re-run; the consumer declares
# the classes, in the file declared as `consumer_pr_class_file:` in
# layer-contract.yaml. An UNDECLARED taxonomy prints a worklist line and exits 0
# -- a project that has not adopted this must not have its trunk wedged by it --
# and every ERROR is against a declared taxonomy's own contents. That split is
# E17/W6's and E18/W10's, and neither wedged anyone.
#
# A DUTY KEYED TO SOMETHING THE COMMIT DETERMINES IS DECLARED WITH `capture:`.
# Until v0.236.0 every argument in a `validator:` line was a literal, so a
# consumer whose validator takes the audited commit's sprint number -- or its
# release number, or its story id -- could not declare that obligation at all
# and kept its own script for that reason alone. Measured on the reference
# consumer: three of its four retro-class obligations take the sprint number as
# an argument, so the declared taxonomy re-ran 2 where the incumbent re-ran 4.
#
#   capture: <name> <anchored-regex-with-one-capturing-group>
#   validator: some-check.sh {<name>}
#
# The regex is matched against the commit's CHANGED PATHS and must be anchored
# ^...$, because it extracts rather than tests -- an unanchored one leaves the
# unmatched remainder of the path in the value. Group 1 is the value.
#
# THE VALUE MUST BE EXACTLY ONE, AND EVERY OTHER OUTCOME IS A FINDING. Zero
# matching paths means the class's stated obligation is un-runnable against this
# commit; two different values mean the commit spans more than the capture
# assumed and core will not pick one. Neither is a skip, for the same reason an
# unresolved class is not. A value outside [A-Za-z0-9._-] is also a finding: the
# command is evaluated, so the capture is an injection surface fed by the
# repository's own paths, and `(.*)` is a legal thing for a consumer to write.
#
# There is NO runtime arm for "an unsubstituted {name} reached a validator's
# argv", and its absence is deliberate. The declaration-time join below binds
# every {name} to a `capture:` in the same class and every `capture:` to a
# {name} that reads it, in both directions, and a failure there stops the run
# before a single commit is audited -- so that arm's subject set would be empty
# by construction, and an arm that cannot fire reads exactly like one that
# passed.
#
# Exit codes (--audit-trunk):
#   0  -- every commit in range resolved and re-verified clean, or the taxonomy
#         is undeclared (worklist printed), or the range is empty
#   1  -- one or more findings, or the declared taxonomy is malformed
#   2  -- usage/setup error: not a git repo, no genesis, unreadable contract
#
# Companion to validate-retro-evidence.sh: this enforces ">=3 cycle commits per
# planning artifact"; retro-evidence enforces that retro party-mode was actually
# invoked. Different inputs, different outputs, both are pipeline structural
# enforcement.
#
# bash 3.2+ and Python 3.

TRUNK="${AI_DLC_TRUNK:-main}"

# ============================================================================
# --audit-trunk -- the post-merge trunk audit. Header above states what it is
# for and why the verdict is a re-run rather than a log.
# ============================================================================
if [ "${1:-}" = "--audit-trunk" ]; then
  shift
  audit_die() { echo "audit-trunk: $*" >&2; exit 2; }

  AROOT="$(git rev-parse --show-toplevel 2>/dev/null)" \
    || audit_die "not a git repository, so there is no trunk to audit."
  cd "$AROOT" || audit_die "cannot enter the repository root $AROOT."

  # The taxonomy's LOCATION comes from the declaration, never from a literal
  # here -- a reader that restates the path passes every agreement check while
  # the declaration moves out from under it. Both layouts are searched because
  # this script runs in both: installed as scripts/ai-dlc/ in a consumer and read
  # out of core/scripts/ by the distribution's own fixtures.
  A_LC=""
  for _c in ".claude/skills/ai-dlc/layer-contract.yaml" \
            "core/skills/ai-dlc/layer-contract.yaml"; do
    if [ -f "$AROOT/$_c" ]; then A_LC="$AROOT/$_c"; break; fi
  done
  [ -n "$A_LC" ] || audit_die "no layer-contract.yaml in either layout (looked for .claude/skills/ai-dlc/ and core/skills/ai-dlc/). The taxonomy's location is declared there and nowhere else, so this run has nothing to read -- which is not the same answer as a clean trunk."
  A_PRC_REL="$(sed -n 's/^consumer_pr_class_file:[[:space:]]*//p' "$A_LC" | head -1 | sed 's/[[:space:]]*$//')"

  # A contract that PREDATES the declaration is not a consumer failing to adopt
  # this. v0.228.0 recorded what happens to an arm that cannot tell those apart.
  if [ -z "$A_PRC_REL" ]; then
    echo "AUDIT-TRUNK: WORKLIST -- $(basename "$A_LC") declares no 'consumer_pr_class_file:', so this project's contract predates the trunk audit. Nothing was audited and nothing is wrong; the next pull ships the declaration."
    exit 0
  fi

  A_PRC="$AROOT/$A_PRC_REL"
  if [ ! -f "$A_PRC" ]; then
    echo "AUDIT-TRUNK: WORKLIST -- $A_PRC_REL: no PR-class taxonomy has been scaffolded, so this project has not declared what its trunk classes are or what each owes. install.sh and the pull driver both create it from core's template; until one has run, nothing states the taxonomy and nothing can be audited against it. Nothing was audited: that is a worklist item, not a clean trunk."
    exit 0
  fi

  # The block: every non-blank, non-comment line inside the fence, stripped. The
  # grammar is deliberately dumb -- the consumer writes this by hand, and a
  # clever parser turns a hand-written file into a source of parse errors.
  A_BLOCK="$(awk '/^```/{f=!f; next} f' "$A_PRC" 2>/dev/null \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^#' | grep -E '.' || true)"
  if [ -z "$A_BLOCK" ]; then
    echo "AUDIT-TRUNK: WORKLIST -- $A_PRC_REL: carries no taxonomy block at all, not even the literal 'none'. An undeclared taxonomy and an empty one must not look alike: state 'none' if this project declares no classes, or write one stanza per class. Nothing was audited."
    exit 0
  fi
  if [ "$A_BLOCK" = "none" ]; then
    echo "AUDIT-TRUNK: WORKLIST -- $A_PRC_REL declares 'none', so this project recognises no trunk classes yet and the audit has nothing to resolve commits against. That is a complete answer and it is not a clean trunk: declare the classes to start auditing."
    exit 0
  fi

  A_TMP="$(mktemp -d 2>/dev/null)" || audit_die "mktemp failed."
  trap 'rm -rf "$A_TMP"' EXIT
  A_N=0
  A_DECL_ERR=0
  decl_err() { echo "ERROR  $A_PRC_REL: $*" >&2; A_DECL_ERR=$((A_DECL_ERR+1)); }

  while IFS= read -r _line; do
    [ -n "$_line" ] || continue
    _key="${_line%%:*}"
    _val="${_line#*:}"
    _val="$(printf '%s' "$_val" | sed 's/^[[:space:]]*//')"
    case "$_key" in
      class)
        [ -n "$_val" ] || { decl_err "a 'class:' line declares no name."; continue; }
        _i=1
        while [ "$_i" -le "$A_N" ]; do
          if [ "$_val" = "$(cat "$A_TMP/c$_i.name")" ]; then
            decl_err "class '$_val' is declared twice. Two stanzas under one name cannot both be first-match, so one of them is unreachable."
          fi
          _i=$((_i+1))
        done
        A_N=$((A_N+1))
        printf '%s' "$_val" > "$A_TMP/c$A_N.name"
        : > "$A_TMP/c$A_N.paths"; : > "$A_TMP/c$A_N.added"; : > "$A_TMP/c$A_N.val"
        : > "$A_TMP/c$A_N.cap"
        ;;
      paths|added|validator|capture)
        if [ "$A_N" -eq 0 ]; then
          decl_err "'$_key:' appears before any 'class:' line, so it belongs to no class and nothing reads it."
          continue
        fi
        [ -n "$_val" ] || { decl_err "class '$(cat "$A_TMP/c$A_N.name")' has an empty '$_key:' value."; continue; }
        case "$_key" in
          paths)     printf '%s\n' "$_val" >> "$A_TMP/c$A_N.paths" ;;
          added)     printf '%s\n' "$_val" >> "$A_TMP/c$A_N.added" ;;
          validator) printf '%s\n' "$_val" >> "$A_TMP/c$A_N.val" ;;
          capture)
            # Every rejection below is at DECLARATION time and stops the whole
            # run, which is the design rather than an accident: it is what makes
            # it impossible for an unsubstituted `{name}` to reach a validator's
            # argv. There is deliberately no runtime arm for that -- with these
            # in place its subject set is empty, and a check that cannot fire
            # reads exactly like one that passed.
            _cnm="${_val%% *}"; _cre="${_val#* }"
            _cls="$(cat "$A_TMP/c$A_N.name")"
            if [ "$_cnm" = "$_val" ] || [ -z "$_cre" ]; then
              decl_err "class '$_cls' has 'capture: $_val', which is a name with no regex after it. The form is 'capture: <name> <anchored-regex-with-one-group>' -- the name is what a validator: line writes as {name}, and the regex is what extracts its value from this commit's changed paths."
              continue
            fi
            # Here-string, not a pipe: I54's rule -- a variable written into a
            # reader that stops at its first match answers "not found" on input
            # that contains the pattern, once the value clears the pipe buffer.
            if ! grep -qE '^[A-Za-z][A-Za-z0-9_]*$' <<<"$_cnm"; then
              decl_err "class '$_cls' declares capture name '$_cnm'. A capture name is [A-Za-z][A-Za-z0-9_]* so that {$_cnm} is unambiguous inside a validator: command; a name outside that set cannot be substituted for without guessing where it ends."
              continue
            fi
            case "$_cre" in
              '^'*'$') ;;
              *)
                decl_err "class '$_cls' capture '$_cnm' has regex '$_cre', which is not anchored ^...\$. paths: TESTS a path and may match part of one; a capture EXTRACTS from it, and an unanchored regex leaves the unmatched remainder in the value -- 's([0-9]+)/' against docs/retro/s168/retro.md yields docs/retro/retro.md, silently. Anchor it so the regex describes the whole path."
                continue
                ;;
            esac
            # ERE has no non-capturing group, so an unescaped '(' IS a group.
            # Strip escaped backslashes first, then escaped parens, then look.
            _probe="$(printf '%s' "$_cre" | sed 's/\\\\//g; s/\\(//g')"
            case "$_probe" in
              *'('*) ;;
              *)
                decl_err "class '$_cls' capture '$_cnm' has regex '$_cre', which contains no capturing group. A capture with nothing to capture matches or does not match and yields no value either way, so every commit of this class would report an unresolved capture."
                continue
                ;;
            esac
            if grep -qE "^${_cnm} " "$A_TMP/c$A_N.cap" 2>/dev/null; then
              decl_err "class '$_cls' declares capture '$_cnm' twice. Two regexes under one name cannot both supply {$_cnm}, and silently taking the first would make the second unreachable."
              continue
            fi
            # The extraction is a sed s///, so it needs a delimiter the regex
            # does not itself contain. Chosen HERE, at declaration time, and
            # stored -- picking it per commit would put a failure mode inside
            # the audit loop where it could only be discovered by a commit.
            _cd=""
            for _d in '/' '#' '%' ',' '@' '=' '+' '~' ':' ';' '!' '|'; do
              case "$_cre" in *"$_d"*) ;; *) _cd="$_d"; break ;; esac
            done
            if [ -z "$_cd" ]; then
              decl_err "class '$_cls' capture '$_cnm' has a regex containing every character this parser can use to delimit the extraction (/ # % , @ = + ~ : ; ! |). Rewrite it using a bracket expression for one of them."
              continue
            fi
            printf '%s %s %s\n' "$_cnm" "$_cd" "$_cre" >> "$A_TMP/c$A_N.cap"
            ;;
        esac
        ;;
      *)
        decl_err "unknown key '$_key'. The grammar is class:, paths:, added:, capture: and validator:; a line this parser does not know is a line the audit silently ignores, which is how a class ends up owing nothing by accident."
        ;;
    esac
  done <<A_EOF
$A_BLOCK
A_EOF

  # Every class must be able to MATCH and must state what it owes. Both are the
  # same defect in two directions: a class with no pattern can never fire, and a
  # class with no validator line is indistinguishable from one that owes nothing.
  _i=1
  while [ "$_i" -le "$A_N" ]; do
    _nm="$(cat "$A_TMP/c$_i.name")"
    if [ ! -s "$A_TMP/c$_i.paths" ] && [ ! -s "$A_TMP/c$_i.added" ]; then
      decl_err "class '$_nm' declares neither 'paths:' nor 'added:', so no commit can ever resolve to it. A class that cannot match is a check that cannot fire."
    fi
    if [ ! -s "$A_TMP/c$_i.val" ]; then
      decl_err "class '$_nm' declares no 'validator:'. If it owes nothing, say so with 'validator: none' -- silence and 'nothing owed' must not look alike."
    fi
    # The capture join, BOTH DIRECTIONS, because each direction is a different
    # defect and one of them is silent. A {name} with no capture behind it is
    # un-runnable and knowable now rather than on whichever future commit first
    # resolves to this class; a capture no validator reads costs a regex per
    # commit and does nothing, which is the shape of a field with no reader that
    # this program has already paid for twice.
    grep -oE '\{[A-Za-z][A-Za-z0-9_]*\}' "$A_TMP/c$_i.val" 2>/dev/null | sort -u \
      | while IFS= read -r _ref; do
          _rn="${_ref#\{}"; _rn="${_rn%\}}"
          grep -qE "^${_rn} " "$A_TMP/c$_i.cap" 2>/dev/null \
            || echo "$_rn"
        done > "$A_TMP/c$_i.unbound"
    while IFS= read -r _rn; do
      [ -n "$_rn" ] || continue
      decl_err "class '$_nm' has a validator: naming {$_rn} and declares no 'capture: $_rn'. Nothing would supply that value, so the command cannot be built -- and a taxonomy that ships this way would substitute nothing and hand the validator the literal string {$_rn}."
    done < "$A_TMP/c$_i.unbound"
    while IFS= read -r _cl; do
      [ -n "$_cl" ] || continue
      _cn="${_cl%% *}"
      grep -qF "{$_cn}" "$A_TMP/c$_i.val" 2>/dev/null \
        || decl_err "class '$_nm' declares 'capture: $_cn' and no validator: names {$_cn}. The capture is evaluated against every commit of this class and its value is then discarded, so it can only cost findings -- an ambiguous or unmatched capture would fail commits over a value nothing was going to use."
    done < "$A_TMP/c$_i.cap"
    _i=$((_i+1))
  done
  if [ "$A_N" -eq 0 ]; then
    decl_err "declares no classes at all, yet is not the literal 'none'. Nothing here can resolve a commit."
  fi
  if [ "$A_DECL_ERR" -gt 0 ]; then
    echo "AUDIT-TRUNK: declared=$A_N decl_errors=$A_DECL_ERR -- the taxonomy is malformed, so NOTHING was audited. A malformed taxonomy is not an empty one." >&2
    exit 1
  fi

  # ---- range ---------------------------------------------------------------
  A_WM="$AROOT/_bmad-output/.audit-watermark"
  A_GENESIS="${1:-}"
  if [ -z "$A_GENESIS" ] && [ -r "$A_WM" ]; then
    A_GENESIS="$(head -1 "$A_WM" | tr -d '[:space:]')"
  fi
  [ -n "$A_GENESIS" ] || audit_die "no genesis commit. Pass one as an argument, or record one in _bmad-output/.audit-watermark. This mode never defaults to the whole of history: an audit whose range nobody chose re-runs every validator against every tree that ever existed here, and the first old commit that predates a validator reads as a finding."
  git rev-parse --verify -q "${A_GENESIS}^{commit}" >/dev/null 2>&1 \
    || audit_die "genesis '$A_GENESIS' does not resolve to a commit in this repository."
  git rev-parse --verify -q "${TRUNK}^{commit}" >/dev/null 2>&1 \
    || audit_die "trunk '$TRUNK' does not resolve to a commit here. Set AI_DLC_TRUNK if this project's trunk is not '$TRUNK'."

  # EVERY first-parent commit in range, oldest first. Not "the merges": a direct
  # push to the trunk is neither a merge commit nor a squash subject, and it is
  # one of the three bypasses this mode exists for. Enumerating by shape would
  # put it outside the subject set by construction.
  A_COMMITS="$(git log "${A_GENESIS}..${TRUNK}" --first-parent --format='%H' 2>/dev/null \
    | awk '{a[NR]=$0} END{for(i=NR;i>=1;i--) print a[i]}')"
  A_TOTAL="$(printf '%s\n' "$A_COMMITS" | grep -cE '.' || true)"
  if [ "$A_TOTAL" -eq 0 ]; then
    # A zero here is the PASS, so it carries its control in the same run: the
    # trunk's own commit count proves the enumeration ran at all.
    echo "AUDIT-TRUNK: audited=0 clean=0 findings=0 range=${A_GENESIS}..${TRUNK} (empty; control: the trunk holds $(git rev-list --count "$TRUNK" 2>/dev/null || echo '?') commit(s), so the enumeration ran)"
    exit 0
  fi

  A_CLEAN=0; A_FIND=0; A_LAST_CLEAN="$A_GENESIS"

  # Prints the INDEX, not the name: the name is what the operator reads and the
  # index is what the validator list is keyed on, and returning the name would
  # make two classes with one name silently share a validator set. The duplicate
  # is already a declaration error above; this keeps it from mattering twice.
  resolve_class() { # $1 = paths file, $2 = added file -- prints the class index
    local i=1 re
    while [ "$i" -le "$A_N" ]; do
      while IFS= read -r re; do
        [ -n "$re" ] || continue
        if grep -qE "$re" "$1" 2>/dev/null; then printf '%s\n' "$i"; return 0; fi
      done < "$A_TMP/c$i.paths"
      while IFS= read -r re; do
        [ -n "$re" ] || continue
        if grep -qE "$re" "$2" 2>/dev/null; then printf '%s\n' "$i"; return 0; fi
      done < "$A_TMP/c$i.added"
      i=$((i+1))
    done
    return 1
  }

  for _sha in $A_COMMITS; do
    _f="$A_TMP/files"; _a="$A_TMP/added"
    if git rev-parse --verify -q "${_sha}^1" >/dev/null 2>&1; then
      git diff --name-only "${_sha}^1" "$_sha" > "$_f" 2>/dev/null || : > "$_f"
      git diff "${_sha}^1" "$_sha" 2>/dev/null | grep '^+' | grep -v '^+++' > "$_a" || : > "$_a"
    else
      git show --format= --name-only "$_sha" > "$_f" 2>/dev/null || : > "$_f"
      git show --format= "$_sha" 2>/dev/null | grep '^+' | grep -v '^+++' > "$_a" || : > "$_a"
    fi

    _ci="$(resolve_class "$_f" "$_a" || true)"
    _class=""
    [ -n "$_ci" ] && _class="$(cat "$A_TMP/c$_ci.name")"
    if [ -z "$_ci" ]; then
      echo "  FAIL    ${_sha} (UNRESOLVED): matches no declared class, so nothing states what it owed and nothing could be re-run. An unclassifiable change on the trunk is a finding, not a skip -- either it belongs to a class you have not declared, or it is the merge this audit exists to surface."
      A_FIND=$((A_FIND+1))
      break
    fi

    # ---- captures: resolve this commit's values, then build the commands -----
    # A capture is resolved from the commit's own changed paths, BEFORE the
    # worktree, and a capture that does not resolve is a FINDING rather than a
    # skip -- for the same reason an unresolved class is. The class's stated
    # obligation is un-runnable against this commit and saying nothing about
    # that reads exactly like having run it.
    : > "$A_TMP/subs"
    _cap_why=""
    while IFS= read -r _cl; do
      [ -n "$_cl" ] || continue
      _cn="${_cl%% *}"; _rest="${_cl#* }"; _cd="${_rest%% *}"; _cre="${_rest#* }"
      # -E, not plain sed: `paths:` and `added:` are grep -E, and a capture
      # written in a second dialect is a trap the consumer cannot see. In BRE
      # `(` is a literal and `+` is a literal, so the same regex silently
      # matches nothing and the capture reads as unresolved.
      _cvals="$(sed -nE "s${_cd}${_cre}${_cd}\\1${_cd}p" "$_f" 2>/dev/null | sort -u)"
      _cnum="$(printf '%s\n' "$_cvals" | grep -cE '.' || true)"
      if [ "$_cnum" -eq 0 ]; then
        _cap_why="${_cap_why} capture '$_cn' matched none of this commit's $(grep -cE '.' "$_f" || echo 0) changed path(s), so {$_cn} has no value and the class's obligations naming it could not be built. Either this commit belongs to a class you have not declared, or the capture's regex does not describe the paths this class actually changes;"
      elif [ "$_cnum" -gt 1 ]; then
        _cap_why="${_cap_why} capture '$_cn' matched $_cnum DIFFERENT values in one commit ($(printf '%s' "$_cvals" | tr '\n' ' ')), so {$_cn} is ambiguous here. Core will not pick one: running the class's validators against a guess is worse than reporting that the commit spans more than the capture assumed;"
      else
        case "$_cvals" in
          *[!A-Za-z0-9._-]*)
            # The command is run through eval, so a capture value is an
            # injection surface that the repository's own paths feed. The
            # consumer writes the regex, and `(.*)` is a legal thing to write.
            _cap_why="${_cap_why} capture '$_cn' resolved to '$_cvals', which is outside [A-Za-z0-9._-]. A capture value is substituted into a command that is then evaluated, so a value carrying shell syntax would run it; narrow the capture's group to the part you actually need;"
            ;;
          *)
            printf '%s %s\n' "$_cn" "$_cvals" >> "$A_TMP/subs"
            ;;
        esac
      fi
    done < "$A_TMP/c$_ci.cap"

    if [ -n "$_cap_why" ]; then
      echo "  FAIL    ${_sha} (${_class}):${_cap_why}"
      A_FIND=$((A_FIND+1))
      break
    fi

    # Substitution is parameter expansion against a QUOTED pattern, not a sed:
    # the value comes from a path and can carry any sed delimiter.
    : > "$A_TMP/valres"
    while IFS= read -r _cmd; do
      while IFS= read -r _s; do
        [ -n "$_s" ] || continue
        _sn="${_s%% *}"; _sv="${_s#* }"
        _cmd="${_cmd//"{$_sn}"/$_sv}"
      done < "$A_TMP/subs"
      printf '%s\n' "$_cmd" >> "$A_TMP/valres"
    done < "$A_TMP/c$_ci.val"

    _verdict="CLEAN"; _why=""
    _wt="$(mktemp -d 2>/dev/null)/w"
    if git worktree add --detach "$_wt" "$_sha" >/dev/null 2>&1; then
      while IFS= read -r _cmd; do
        [ -n "$_cmd" ] || continue
        [ "$_cmd" = "none" ] && continue
        _bin="$(printf '%s' "$_cmd" | awk '{print $1}')"
        case "$_bin" in
          */*)
            if [ ! -f "$_wt/$_bin" ]; then
              _verdict="FAIL"
              _why="${_why} declared validator '$_bin' does not exist in this commit's own tree, so the class's obligation could not be re-run against it. Either the validator postdates this commit -- move the genesis forward past it -- or this commit is what removed it;"
              continue
            fi
            ;;
        esac
        # THE VALIDATOR'S FIRST LINE IS CARRIED INTO THE FINDING, and it is there because of
        # a measured false positive rather than for tidiness. A declared command can fail
        # against an older tree because the MODE it passes postdates that commit -- measured
        # on the reference consumer, where `validate-provenance-block.sh --strays` answers
        # `ERROR: artifact not found: --strays` at a 2026-06 tree and exits 0 at HEAD. Core
        # gets only an exit code and cannot tell that from a real rejection, so the choice is
        # between a confident wrong diagnosis and handing the operator the line that settles
        # it. Parameter expansion, not a pipeline: this is the early-exiting-reader shape.
        if ! _out="$( cd "$_wt" && eval "$_cmd" 2>&1 )"; then
          _verdict="FAIL"
          _first="${_out%%$'\n'*}"
          [ -n "$_first" ] || _first="(it printed nothing)"
          _why="${_why} '$_cmd' exits non-zero against this commit's own tree, so this change reached the trunk without satisfying its class -- it said: ${_first};"
        fi
      done < "$A_TMP/valres"
      git worktree remove --force "$_wt" >/dev/null 2>&1 || true
    else
      _verdict="FAIL"
      _why=" could not check this commit's tree out into a worktree, so nothing was re-run against it. An unreadable tree is not a clean one;"
    fi
    rm -rf "$(dirname "$_wt")" 2>/dev/null || true

    if [ "$_verdict" = "CLEAN" ]; then
      echo "  CLEAN   ${_sha} (${_class})"
      A_CLEAN=$((A_CLEAN+1)); A_LAST_CLEAN="$_sha"
    else
      echo "  FAIL    ${_sha} (${_class}):${_why}"
      A_FIND=$((A_FIND+1))
      break
    fi
  done

  # The watermark advances only to the last clean commit, and only if the
  # directory core writes its artifacts into already exists -- creating it here
  # would make a repo that has never run ai-dlc look like one that has.
  if [ -d "$AROOT/_bmad-output" ]; then
    printf '%s\n' "$A_LAST_CLEAN" > "$A_WM" 2>/dev/null || true
  fi

  echo "AUDIT-TRUNK: audited=$((A_CLEAN + A_FIND)) of=$A_TOTAL clean=$A_CLEAN findings=$A_FIND classes=$A_N watermark=$A_LAST_CLEAN"
  [ "$A_FIND" -eq 0 ] || exit 1
  exit 0
fi

BRANCH="${1:-$(git rev-parse --abbrev-ref HEAD)}"
LOG_FILE="_bmad-output/validation-cycle-log.md"
MIN_CYCLES=3

# ---- Edge case: missing log file -------------------------------------------
if [ ! -f "$LOG_FILE" ]; then
  echo "ERROR: validation log file missing: $LOG_FILE" >&2
  exit 1
fi

# ---- Run the analysis via Python -------------------------------------------
python3 - "$BRANCH" "$LOG_FILE" "$MIN_CYCLES" "$TRUNK" << 'PYEOF'
import sys
import re
import subprocess

branch = sys.argv[1]
log_file = sys.argv[2]
min_cycles = int(sys.argv[3])
trunk = sys.argv[4]

# ---- Get all commit SHAs on branch since trunk ------------------------------
sha_result = subprocess.run(
    ["git", "log", f"{trunk}..{branch}", "--format=%H"],
    capture_output=True, text=True
)
branch_shas = set(sha_result.stdout.strip().splitlines())

# Helper: check if a given SHA exists anywhere in git history (not just branch)
def sha_exists_in_repo(sha):
    if not sha or sha == "TBD":
        return False
    r = subprocess.run(
        ["git", "cat-file", "-e", sha],
        capture_output=True, text=True
    )
    return r.returncode == 0

# Get commit subjects for secondary commit-based counting
subj_result = subprocess.run(
    ["git", "log", f"{trunk}..{branch}", "--format=%H %s"],
    capture_output=True, text=True
)
commits = [line for line in subj_result.stdout.strip().splitlines() if line]

if not commits:
    print(f"No commits on branch {branch} since {trunk} -- nothing to validate.")
    sys.exit(0)

# ---- Parse log file: count rows per artifact section -----------------------
# Sections: "## Sprint N — <Label> (...)"  or  "## Sprint N -- <Label> (...)"
# Each section has a table; count rows (lines starting "| <digit>").
# Also record commit SHAs from rows for branch-membership check.
artifacts = {}  # artifact_key -> {"rows": int, "shas": [str], "sprint": str}

SECTION_RE = re.compile(r'^## Sprint (\d+) [—\-]+ (.+)')
# Accept SHAs bare or wrapped in backticks; "TBD" marker for pending commits.
# Both spellings tolerated to avoid false-positive merge-detection failures on
# logs written before the backtick-wrapping convention.
ROW_RE = re.compile(r'^\|\s*(\d+)\s*\|.*\|\s*`?([0-9a-f]{6,40}|TBD)`?\s*\|?\s*$')

current = None
with open(log_file, encoding='utf-8') as f:
    for raw_line in f:
        line = raw_line.rstrip('\n')
        m = SECTION_RE.match(line)
        if m:
            sprint_n = m.group(1)
            label = m.group(2).strip()
            # Remove trailing parenthetical
            label = re.sub(r'\s*\(.*\)\s*$', '', label).strip()
            ll = label.lower()
            if ll.startswith('brief'):
                key = label[0].lower() + label[1:]
            elif ll.startswith('prd'):
                key = label
            elif ll.startswith('architecture'):
                key = 'architecture'
            elif ll.startswith('stories'):
                key = 'stories'
            elif ll.startswith('test strategy') or ll.startswith('test-strategy'):
                key = 'test-strategy'
            elif ll.startswith('retro'):
                key = 'retro'
            else:
                key = label
            full_key = f"{sprint_n}:{key}"
            artifacts[full_key] = {"rows": 0, "shas": [], "sprint": sprint_n, "label": key}
            current = full_key
            continue
        if current and re.match(r'^\|\s*\d+\s*\|', line):
            artifacts[current]["rows"] += 1
            # Extract commit SHA from last column (if present and not TBD).
            # Tolerate optional backtick wrapping for markdown rendering.
            sha_m = re.search(r'\|\s*`?([0-9a-f]{6,40})`?\s*\|?\s*$', line)
            if sha_m:
                artifacts[current]["shas"].append(sha_m.group(1))

if not artifacts:
    print("No artifact sections found in validation-cycle-log.md.")
    sys.exit(0)

# ---- Retro-branch awareness -------------------------------------------------
# On retro branches (ai-dlc/retro/sprint-N), planning-phase artifacts were
# squash-merged to trunk as part of the sprint PR. Their cycle commits are no
# longer visible on the retro branch (created from trunk AFTER the squash).
# Only the retro artifact has fresh cycle commits on the retro branch and should
# be validated. Planning artifacts from the current sprint are skipped with a
# SQUASHED annotation.
is_retro_branch = '/retro/sprint-' in branch or branch.endswith('/retro')
retro_sprint_n = None
if is_retro_branch:
    rm = re.search(r'/retro/sprint-(\d+)', branch)
    if rm:
        retro_sprint_n = rm.group(1)

# ---- Which sprint is UNDER VALIDATION ---------------------------------------
# Needed to tell "my sprint's cycle commits are missing" from "some sprint 160 ago has a dead
# SHA". Both used to render as the same opaque FAIL, and Check 2 reports this script's
# process-wide exit code as the retro's own verdict, so a single retro could not distinguish
# them without running this standalone and reading the per-artifact table by hand.
#
# DERIVED, in falling order of directness: the retro branch names its sprint; any branch may
# carry `sprint-<N>`; otherwise the newest section in the log is the one being worked on. The
# fallback is data, not a guess — the log grows a section per sprint and the highest number is
# the current one by construction.
current_sprint_n = retro_sprint_n
if current_sprint_n is None:
    bm = re.search(r'sprint-(\d+)', branch)
    if bm:
        current_sprint_n = bm.group(1)
if current_sprint_n is None and artifacts:
    current_sprint_n = str(max(int(a["sprint"]) for a in artifacts.values()))

# ---- Build commit-based counts per artifact --------------------------------
# Pattern: "Sprint N <artifact_key>: <cycle>"
# Normalization:
#   "discovery draft" -> the sprint's first brief artifact
#   "research-requirements draft" -> the sprint's first PRD artifact
#   "stories-test-strategy draft" -> the sprint's stories artifact
COMMIT_RE = re.compile(r'^[0-9a-f]+ Sprint (\d+) (.+?): .+')

# Cycle-type coverage: an artifact's commit set must include at least one
# party-mode commit AND at least one adversarial-review commit. The `pass N`
# suffix on AR is required so "AR-15 rifle"-style subjects do not match, and the
# `[-\s]+` separator rejects "AR15".
PARTY_MODE_RE = re.compile(r'\b(party[- ]?mode|pm)\b', re.IGNORECASE)
AR_RE = re.compile(r'\b(adversarial[- ]?review|AR[-\s]+pass\s*[0-9]+|ar pass\s*[0-9]+)\b', re.IGNORECASE)

commit_counts = {}  # artifact_key -> count
commit_subjects = {}  # artifact_key -> list of commit subject strings (for cycle-type check)
sprint_brief_map = {}   # sprint_n -> first brief key in artifacts
sprint_prd_map = {}     # sprint_n -> first PRD key in artifacts
sprint_stories_map = {} # sprint_n -> first stories key in artifacts
sprint_test_strategy_map = {} # sprint_n -> first test-strategy key in artifacts

for fk, info in artifacts.items():
    sn = info["sprint"]
    lbl = info["label"].lower()
    if lbl.startswith("brief") and sn not in sprint_brief_map:
        sprint_brief_map[sn] = fk
    if lbl.startswith("prd") and sn not in sprint_prd_map:
        sprint_prd_map[sn] = fk
    if lbl.startswith("stories") and sn not in sprint_stories_map:
        sprint_stories_map[sn] = fk
    if lbl.startswith("test-strategy") and sn not in sprint_test_strategy_map:
        sprint_test_strategy_map[sn] = fk

for line in commits:
    m = COMMIT_RE.match(line)
    if not m:
        continue
    sprint_n = m.group(1)
    artifact = re.sub(r'\s+draft$', '', m.group(2).strip())
    # Capture the full subject after the SHA for cycle-type regex.
    subject_after_sha = line.split(' ', 1)[1] if ' ' in line else line

    # Normalize step-file names to the log's artifact labels. Accept any string
    # starting with the step name (e.g. "discovery Scope 101") as an alias for
    # the sprint's first artifact of that class, tolerating commit-subject
    # variation without changing the structural intent.
    artifact_lc = artifact.lower()
    if artifact_lc == 'discovery' or artifact_lc.startswith('discovery '):
        target = sprint_brief_map.get(sprint_n)
        if target:
            commit_counts[target] = commit_counts.get(target, 0) + 1
            commit_subjects.setdefault(target, []).append(subject_after_sha)
        continue
    if artifact_lc == 'research-requirements' or artifact_lc.startswith('research-requirements '):
        target = sprint_prd_map.get(sprint_n)
        if target:
            commit_counts[target] = commit_counts.get(target, 0) + 1
            commit_subjects.setdefault(target, []).append(subject_after_sha)
        continue
    if artifact_lc == 'stories-test-strategy' or artifact_lc.startswith('stories-test-strategy '):
        target = sprint_stories_map.get(sprint_n)
        if target:
            commit_counts[target] = commit_counts.get(target, 0) + 1
            commit_subjects.setdefault(target, []).append(subject_after_sha)
        continue
    if artifact_lc == 'test-strategy' or artifact_lc.startswith('test-strategy ') \
            or artifact_lc == 'test strategy' or artifact_lc.startswith('test strategy '):
        target = sprint_test_strategy_map.get(sprint_n)
        if target:
            commit_counts[target] = commit_counts.get(target, 0) + 1
            commit_subjects.setdefault(target, []).append(subject_after_sha)
        continue

    # Standard case: look for matching artifact key in our artifacts dict
    fk = f"{sprint_n}:{artifact}"
    if fk in artifacts:
        commit_counts[fk] = commit_counts.get(fk, 0) + 1
        commit_subjects.setdefault(fk, []).append(subject_after_sha)

# ---- Output table and check PASS/FAIL conditions ---------------------------
fail = False
unverifiable = []
print()
print(f"{'ARTIFACT':<42} | {'COMMITS':>7} | {'LOG ROWS':>8} | {'SHA CHECK':>10} | MATCH")
print("-" * 90)

for fk in sorted(artifacts.keys()):
    info = artifacts[fk]
    sprint_n = info["sprint"]
    label = info["label"]
    log_rows = info["rows"]
    cycles = commit_counts.get(fk, 0)

    # SHA check: how many log row SHAs exist on the branch
    sha_hits = sum(1 for s in info["shas"] if any(b.startswith(s) or s.startswith(b[:7]) for b in branch_shas))
    sha_total = len(info["shas"])
    sha_status = f"{sha_hits}/{sha_total}"

    # Retro-branch awareness: planning artifacts from the retro's own sprint were
    # squash-merged to trunk and are not directly visible on the retro branch.
    # Skip them as SQUASHED rather than failing.
    if is_retro_branch and retro_sprint_n == sprint_n and label != 'retro':
        match = "SQUASHED (pre-retro)"
        disp = f"Sprint {sprint_n} {label}"
        print(f"{disp:<42} | {cycles:>7} | {log_rows:>8} | {sha_status:>10} | {match}")
        continue

    # Prior-sprint awareness: artifacts from a PRIOR sprint whose cycle commits
    # were merged to trunk in a completed sprint PR. Their SHAs are no longer in
    # trunk..HEAD but exist in git history. If log rows >= min_cycles AND all
    # non-TBD log SHAs exist in the repo, mark MERGED and skip -- a new sprint's
    # artifacts validate without re-validating every prior sprint's, whose cycle
    # integrity is locked in by the merged trunk history.
    if cycles == 0 and log_rows >= min_cycles and info["shas"]:
        non_tbd_shas = [s for s in info["shas"] if s.lower() != "tbd"]
        if non_tbd_shas and all(sha_exists_in_repo(s) for s in non_tbd_shas):
            match = "MERGED (prior sprint)"
            disp = f"Sprint {sprint_n} {label}"
            print(f"{disp:<42} | {cycles:>7} | {log_rows:>8} | {sha_status:>10} | {match}")
            continue
        # THE SAME SHAPE, ONE SHA SHORT. Zero commits on this branch and enough log rows, but
        # at least one row SHA is no longer an object in the repo — a squash-history rewrite,
        # or a log row written before the SHA-citation convention existed. The MERGED carve-out
        # above requires every SHA to resolve, so it cannot fire, and the row fell through to
        # `FAIL (<N commits)` with NO PATH BACK: nothing a future sprint does can make a dead
        # SHA live again short of hand-editing 150-sprint-old rows. Measured on the reference
        # consumer: five sections from sprints 136-155 failed every retro from S298 onward,
        # none of them related to the sprint being validated.
        #
        # A prior sprint's cycle integrity is locked in by the merged trunk history either way;
        # what is lost is only the ability to RE-verify it here. That is a different fact from
        # "this sprint skipped its cycles", so it gets its own name and does not fail the run.
        # The CURRENT sprint is never exempted — see below.
        if str(sprint_n) != str(current_sprint_n):
            match = "UNVERIFIABLE (history rewritten)"
            disp = f"Sprint {sprint_n} {label}"
            unverifiable.append(disp)
            print(f"{disp:<42} | {cycles:>7} | {log_rows:>8} | {sha_status:>10} | {match}")
            continue

    if log_rows < min_cycles:
        match = f"FAIL (<{min_cycles} log rows)"
        fail = True
    elif cycles < min_cycles:
        match = f"FAIL (<{min_cycles} commits)"
        fail = True
    elif abs(cycles - log_rows) > 1:
        match = "FAIL (mismatch >1)"
        fail = True
    else:
        # Cycle-type coverage: require >=1 party-mode AND >=1 adversarial-review
        # commit in the artifact's commit set.
        subjects = commit_subjects.get(fk, [])
        has_party_mode = any(PARTY_MODE_RE.search(s) for s in subjects)
        has_ar = any(AR_RE.search(s) for s in subjects)
        if not has_party_mode:
            match = "FAIL (missing cycle type: party-mode)"
            fail = True
        elif not has_ar:
            match = "FAIL (missing cycle type: adversarial-review)"
            fail = True
        else:
            match = "PASS"

    disp = f"Sprint {sprint_n} {label}"
    print(f"{disp:<42} | {cycles:>7} | {log_rows:>8} | {sha_status:>10} | {match}")

print()
# NAMED, NOT SWALLOWED. An exemption nobody can see is indistinguishable from a check that
# scanned nothing, so say which rows were skipped and why — the operator can then tell a quiet
# run from a run that quietly stopped looking.
if unverifiable:
    print(f"NOTE: {len(unverifiable)} prior-sprint section(s) UNVERIFIABLE (row SHAs no longer "
          f"in this repo; their cycle integrity is locked in by merged trunk history, and "
          f"re-verification here is what was lost): {', '.join(unverifiable)}")
    print(f"      Sprint {current_sprint_n} is under validation and is never exempted this way.")
if fail:
    print(f"RESULT: FAIL -- one or more artifacts have <{min_cycles} cycles or mismatch.",
          file=sys.stderr)
    sys.exit(1)
else:
    print(f"RESULT: PASS -- all artifacts have >={min_cycles} cycles with matching log rows.")
    sys.exit(0)
PYEOF
