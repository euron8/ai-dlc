#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# apply-worklist-rows/run.sh — prove a WORKLIST row reaches the operator with its INSTRUCTION,
# and that an ATOMIC sequence emits every step it numbers.
#
# THE TWO DEFECTS THIS FIXTURE EXISTS FOR, both live in apply.sh until v0.311.0, both green
# everywhere, and both found only by RUNNING the script rather than reading it.
#
#   1. `say()` printed THREE fields while eighteen call sites passed FOUR. Every WORKLIST and
#      DECISION detail was computed and thrown away. The operator's row was
#      `WORKLIST<TAB>override-retire<TAB><path>` — no key, no ordering, no reason — while
#      SKILL.md step 7 told the reader to obey a detail field that was never printed.
#
#   2. The per-key loop was `printf '%s' "$keys" | tr ',' '\n' | while read`. `printf '%s'`
#      writes no trailing newline, so the LAST element arrives at EOF, `read` returns non-zero
#      and the body never runs on it. N keys emitted N-1 rows; the one-key case — every keyed
#      supersession core has ever declared — emitted ZERO. The sequence printed only its final
#      `2/2 ... --stamp retire` step while advertising a `1/2 write the key` step that did not
#      exist, which is the exact reverse of the order the block exists to enforce.
#
# WHY NOTHING CAUGHT EITHER. No fixture drove apply.sh's worklist rendering at all. The one
# fixture that greps a WORKLIST row (`apply-drift-after-write`) matches on the subject path,
# which is field 3 and survived both defects. `layer-readopt-gate` asserts the `replaces_with=`
# TOKEN that layer-drift.sh emits — the input to this rendering — and stops there. So the whole
# hand-off from detector to operator was untested end to end.
#
# HOW IT DRIVES THE REAL SCRIPT. apply.sh shells to `$SELF/layer-drift.sh` for its layer rows,
# so a copy of `reconcile/` with a STUB layer-drift makes the worklist a pure function of a TSV
# this file writes. Nothing is stubbed inside apply.sh itself: the rendering under test is the
# shipped code, byte for byte.
set -uo pipefail

# TWO LAYOUTS, and this fixture ships to consumers, so it must resolve in both. install.sh
# splits what shares a parent here: `core/skills/ai-dlc-update/reconcile/` in the distribution
# becomes `.claude/skills/ai-dlc-update/reconcile/` in a consumer. Both roots are the SAME three
# levels up from this file, so the discriminator is which of the two paths carries apply.sh --
# not a walk of a different depth. Resolved from `$0`, never from the process cwd, so the verdict
# does not depend on where the suite runner happens to stand.
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if   [ -n "$ROOT" ] && [ -f "$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  REC="$ROOT/core/skills/ai-dlc-update/reconcile"
elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  REC="$ROOT/.claude/skills/ai-dlc-update/reconcile"
else
  echo "apply-worklist-rows: FIXTURE BROKEN — reconcile/apply.sh not found in either layout" >&2
  exit 2
fi
W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }

echo "apply-worklist-rows:"

# --- ARM C1: every row CLASS apply.sh emits has a step-7 bullet in SKILL.md (BL-1017) ------------
# THE DEFECT ONE LEVEL UP. apply.sh prints rows as `<CLASS>\t<kind>\t<path>[\t<detail>]` and
# SKILL.md step 7 tells the session what to do with each class, one `   - \`CLASS …\`` bullet per
# class. NOTE (16 sites) had no bullet: step 7 said "Work only the WORKLIST and DECISION rows", so
# a NOTE was read by nobody. A class added to apply.sh later would be the same defect again.
# THE JOIN, both sides derived, nothing hand-listed:
#   classes  every non-comment `say [A-Z]+` (or `say "[A-Z]+"`) site of apply.sh, PLUS the
#            variable-class sites resolved: the one known site `say "$_k" staging-refused` takes
#            the literals `_k` is assigned inside the same function; ANY other `say "$var"` site,
#            or a non-literal `_k` assignment there, REFUSES -- its class is not derivable.
#   bullets  every `^   - \`[A-Z]+ ` line strictly between the `^7. **` and `^8. **` headings of
#            SKILL.md, each heading required exactly once and in that order.
# It FAILS naming each class with no bullet, and REFUSES (never passes) on an unreadable file, an
# empty class set, an empty bullet set, or a missing, duplicated or misordered heading.
# CEILING, stated: it checks that a bullet for the class EXISTS in step 7, not what the bullet
# says. A bullet reading "ignore these" satisfies it. What a session does with the bullet is model
# behaviour and no tree predicate reaches it.
# LAYOUT: SKILL.md is resolved as `$REC/../SKILL.md`, beside reconcile/. install.sh lands both
# under one parent in a consumer (`.claude/skills/ai-dlc-update/SKILL.md` and
# `.claude/skills/ai-dlc-update/reconcile/`), as they share `core/skills/ai-dlc-update/` here.
# FALSE-POSITIVE SET: measured EMPTY at the tip that adds the NOTE bullet (classes DECISION NOTE
# RESOLVED WORKLIST, bullets the same four); the only variable-class site at that tip is the known
# `_k` one. The literal grammar requires a non-word character before `say` and a quote, blank, `;`
# or end of line after the class, so `say() {`, `essay X` and `say Hello` are not sites.
# SELF-PROBE first, in mktemp copies of the two real files, both directions, and each seeded copy
# asserted to differ from the file it was seeded from so a seed that applied nothing cannot pass.
# No subject is run, and no bash is started: awk, grep and sed over two files, so the verdict is a
# function of their bytes alone and independent of load, timing and job count (BL-868).
SKILL="$REC/../SKILL.md"
cj_classes() { # cj_classes <apply.sh> -> rows `C <class>` and `R <reason>`
  awk '
    /^[[:blank:]]*#/ { next }
    /^[A-Za-z_][A-Za-z0-9_]*\(\)/ { kl = ""; kbad = 0 }
    {
      rest = $0
      while (match(rest, /(^|[^A-Za-z0-9_])_k=/)) {
        v = substr(rest, RSTART + RLENGTH)
        if (match(v, /^[A-Z][A-Z]*/) && (length(v) == RLENGTH || substr(v, RLENGTH + 1, 1) ~ /[[:blank:];]/)) kl = kl " " substr(v, 1, RLENGTH)
        else kbad = 1
        rest = v
      }
      rest = $0
      while (match(rest, /(^|[^A-Za-z0-9_])say[[:blank:]]+"?[A-Z][A-Z]*/)) {
        t = substr(rest, RSTART, RLENGTH); nx = substr(rest, RSTART + RLENGTH, 1)
        rest = substr(rest, RSTART + RLENGTH)
        if (nx != "" && nx !~ /["[:blank:];]/) continue
        sub(/.*say[[:blank:]]+"?/, "", t); print "C " t
      }
      if ($0 ~ /(^|[^A-Za-z0-9_])say[[:blank:]]+"?\$/) {
        if ($0 ~ /(^|[^A-Za-z0-9_])say "\$_k" staging-refused/) {
          if (kl == "" || kbad) print "R line " NR ": the known say \"$_k\" site has no literal-only _k assignment in its function"
          else { n = split(kl, a, " "); for (i = 1; i <= n; i++) print "C " a[i] }
        } else print "R line " NR ": a variable-class say site whose class cannot be derived"
      }
    }' "$1"
}
cj_bullets() { # cj_bullets <SKILL.md> -> rows `B <class>`, then `H <step-7 count> <step-8 count> <order>`
  awk '
    /^7\. \*\*/ { h7++; if (h8) bad = 1; in7 = 1; next }
    /^8\. \*\*/ { h8++; in7 = 0; next }
    in7 && /^   - `[A-Z][A-Z]* / { t = $0; sub(/^   - `/, "", t); sub(/ .*/, "", t); print "B " t }
    END { print "H " h7 + 0 " " h8 + 0 " " (bad ? "misordered" : "ordered") }' "$1"
}
# class_join <apply.sh> <SKILL.md> -> prints `MISSING <class>` / `REFUSE <why>`; 0 clean, 1 missing, 2 refuse
CJ_CLASSES=""; CJ_BULLETS=""
class_join() {
  local a="$1" s="$2" co bo cls bul c rc=0
  CJ_CLASSES=""; CJ_BULLETS=""
  { [ -r "$a" ] && [ -r "$s" ]; } || { echo "REFUSE cannot read $a or $s"; return 2; }
  co="$(cj_classes "$a")" || { echo "REFUSE the class scan of $a failed"; return 2; }
  bo="$(cj_bullets "$s")" || { echo "REFUSE the bullet scan of $s failed"; return 2; }
  if grep -q '^R ' <<<"$co"; then sed -n 's/^R /REFUSE /p' <<<"$co"; return 2; fi
  case "$bo" in *"H 1 1 ordered") ;; *) echo "REFUSE the step-7/step-8 headings of $s are not each present once and in order ($(sed -n '$p' <<<"$bo"))"; return 2 ;; esac
  cls="$(printf '%s\n' "$co" | sed -n 's/^C //p' | sort -u)"
  bul="$(printf '%s\n' "$bo" | sed -n 's/^B //p' | sort -u)"
  CJ_CLASSES="$(echo $cls)"; CJ_BULLETS="$(echo $bul)"
  [ -n "$cls" ] || { echo "REFUSE no row class derived from $a"; return 2; }
  [ -n "$bul" ] || { echo "REFUSE no class bullet found in step 7 of $s"; return 2; }
  for c in $cls; do
    grep -qxF "$c" <<<"$bul" || { echo "MISSING $c"; rc=1; }
  done
  return $rc
}
# cj_expect <label> <apply> <skill> <want rc> <want MISSING list, space-separated, or -> [<text the output must carry>]
# The sixth argument pins WHY a refusal refused, so a refusal for some other reason cannot pass.
CJ_PROBE_BAD=0
cj_expect() {
  local out rc got
  out="$(class_join "$2" "$3")"; rc=$?
  got="$(printf '%s\n' "$out" | sed -n 's/^MISSING //p' | sort | tr '\n' ' ' | sed 's/ $//')"
  [ -n "$got" ] || got=-
  if [ "$rc" = "$4" ] && [ "$got" = "$5" ] && { [ -z "${6:-}" ] || grep -qF "${6:-}" <<<"$out"; }; then
    ok "C1 self-probe $1: rc=$rc missing=$got"
  else
    bad "C1 self-probe $1: want rc=$4 missing=$5, got rc=$rc missing=$got: $(printf '%s' "$out" | tr '\n' '|')"
    CJ_PROBE_BAD=1
  fi
}
# cj_differs <label> <seeded> <seeded-from>: a seed that changed nothing cannot stand as a probe.
cj_differs() {
  if cmp -s "$2" "$3"; then bad "C1 self-probe $1: the seeded copy is byte-identical to its source -- the seed did not apply"; CJ_PROBE_BAD=1; return 1; fi
  return 0
}
CJ="$W/class-join"; mkdir -p "$CJ"
CJ_A="$REC/apply.sh"
if [ ! -f "$SKILL" ]; then
  bad "FIXTURE BROKEN — SKILL.md not found beside reconcile/ at $SKILL"; echo "apply-worklist-rows: FIXTURE BROKEN" >&2; exit 2
fi
SKILL="$(cd "$REC/.." && pwd)/SKILL.md"
echo "HERMETIC-CONSUMED $SKILL"
# Base shape: the real SKILL.md with every step-7 NOTE bullet removed -- the tree before BL-1017.
awk '/^7\. \*\*/{i=1} /^8\. \*\*/{i=0} i && /^   - `NOTE /{next} {print}' "$SKILL" > "$CJ/skill.base.md"
if [ "$(cj_bullets "$CJ/skill.base.md" | grep -c '^B NOTE$')" != 0 ]; then
  bad "C1 self-probe: the base-shaped copy still carries a step-7 NOTE bullet"; CJ_PROBE_BAD=1
fi
# Every seed is inserted on the line BEFORE the step-8 heading (still step 7) or AFTER it (step 8).
cj_seed() { # cj_seed <before|after> <line> <in> <out>
  awk -v w="$1" -v l="$2" '/^8\. \*\*/{ if (w == "before") print l; print; if (w == "after") print l; next } {print}' "$3" > "$4"
}
cj_seed before '   - `NOTE …` — probe bullet.' "$CJ/skill.base.md" "$CJ/skill.note.md"
cj_seed before '   A `NOTE …` row named in prose, not a bullet.' "$CJ/skill.base.md" "$CJ/skill.prose.md"
cj_seed after '   - `NOTE …` — probe bullet placed in step 8.' "$CJ/skill.base.md" "$CJ/skill.step8.md"
cp "$CJ_A" "$CJ/apply.info.sh";  printf '%s\n' 'say INFO probe-kind "x" "y"' >> "$CJ/apply.info.sh"
cp "$CJ_A" "$CJ/apply.var.sh";   printf '%s\n' 'say "$x" probe-kind "x" "y"' >> "$CJ/apply.var.sh"
awk '/^[[:blank:]]*local _k=DECISION$/{sub(/DECISION/, "HALTQ")} {print}' "$CJ_A" > "$CJ/apply.kclass.sh"
awk '/^[[:blank:]]*local _k=DECISION$/{sub(/DECISION/, "\"$_x\"")} {print}' "$CJ_A" > "$CJ/apply.kvar.sh"
for _p in skill.note.md skill.prose.md skill.step8.md; do cj_differs "$_p" "$CJ/$_p" "$CJ/skill.base.md"; done
for _p in apply.info.sh apply.var.sh apply.kclass.sh apply.kvar.sh; do cj_differs "$_p" "$CJ/$_p" "$CJ_A"; done
cj_differs skill.note.md-vs-real "$CJ/skill.note.md" "$SKILL"
cj_expect "1 base shape, no NOTE bullet (fires)"           "$CJ_A" "$CJ/skill.base.md"  1 NOTE
cj_expect "2 seeded NOTE bullet (quiet)"                   "$CJ_A" "$CJ/skill.note.md"  0 -
cj_expect "3 NOTE named only in prose (fires)"             "$CJ_A" "$CJ/skill.prose.md" 1 NOTE
cj_expect "4 a new say INFO site (fires)"                  "$CJ/apply.info.sh" "$CJ/skill.note.md" 1 INFO
cj_expect "5 the NOTE bullet placed in step 8 (fires)"     "$CJ_A" "$CJ/skill.step8.md" 1 NOTE
cj_expect "6 an extra variable-class say site (refuses)"   "$CJ/apply.var.sh" "$CJ/skill.note.md" 2 - "class cannot be derived"
cj_expect "7 a new literal assigned to _k (fires, derived)" "$CJ/apply.kclass.sh" "$CJ/skill.note.md" 1 HALTQ
cj_expect "8 a non-literal _k assignment (refuses)"         "$CJ/apply.kvar.sh" "$CJ/skill.note.md" 2 - "no literal-only _k assignment"
# The corpus read, only behind a self-probe that fired and stayed quiet where it should.
if [ "$CJ_PROBE_BAD" = 0 ]; then
  # Not in `$( )`: class_join sets CJ_CLASSES/CJ_BULLETS, which a subshell would discard.
  class_join "$CJ_A" "$SKILL" > "$CJ/corpus.out"; CJ_RC=$?
  CJ_OUT="$(cat "$CJ/corpus.out")"
  case "$CJ_RC" in
    0) ok "C1 every row class apply.sh emits ($CJ_CLASSES) has a step-7 bullet in SKILL.md ($CJ_BULLETS)" ;;
    1) for _c in $(printf '%s\n' "$CJ_OUT" | sed -n 's/^MISSING //p'); do
         bad "C1 row class $_c is emitted by apply.sh (say $_c) and has no \`   - \`$_c …\`\` bullet in step 7 of $SKILL (classes: $CJ_CLASSES; bullets: $CJ_BULLETS) -- add one saying what the session does with a $_c row"
       done ;;
    *) bad "C1 REFUSED -- the join cannot be computed: $(printf '%s' "$CJ_OUT" | tr '\n' '|')" ;;
  esac
else
  bad "C1 corpus read NOT run: the self-probe above did not discriminate, so a clean corpus read would establish nothing"
fi


# --- the synthetic pull -------------------------------------------------------------------
# Two throwaway git repos. apply.sh needs both to resolve refs; neither carries a core/ tree,
# so its pure-apply phase has nothing to write and the only rows are the ones under test.
mk_repo() { mkdir -p "$1" && git -C "$1" init -q . && echo seed > "$1/f" \
  && git -C "$1" add -A >/dev/null 2>&1 \
  && git -C "$1" -c user.email=f@x -c user.name=f commit -qm seed >/dev/null 2>&1; }
mk_repo "$W/dist" || { bad "FIXTURE BROKEN — could not build the dist repo"; exit 2; }
mk_repo "$W/cons" || { bad "FIXTURE BROKEN — could not build the consumer repo"; exit 2; }

OVR='.claude/skills/ai-dlc/overrides/one-key.md'
OVR_M='.claude/skills/ai-dlc/overrides/multi-key.md'
OVR_A='.claude/skills/ai-dlc/overrides/multi-adopted.md'
OVR_J="overrides/steps__w__adjudicated.md"
OVR_JR="overrides/steps__w__adjudicated_act_twin.md"
OVR_KR="overrides/steps__w__adjudicated_act_key.md"
OVR_KC="overrides/steps__w__adjudicated_act_contra.md"
OVR_AR="overrides/steps__w__adjudicated_act_anchor.md"
# BOTH DRIFT-HARD AND SUPERSEDED — the shape PC-S331 was filed on, and the one this fixture's
# tree could not EXPRESS until it was seeded here. Every other subject above is superseded ONLY,
# so no arm could ever have observed the co-emission, and a fixture whose tree cannot express the
# defect proves nothing about it. `_H` takes a FULL retire and must be marked subsumed; `_HA` is
# the exemption's own probe — drift-hard AND superseded, but by `retire_anchor=`, which leaves the
# entry on disk and its readopt REAL work. Without `_HA` a guard that marked every drift-hard
# supersession would pass every arm while destroying live work.
OVR_H="overrides/steps__w__hard_and_superseded.md"
OVR_HA="overrides/steps__w__hard_and_anchor_only.md"
ANCHOR='steps/w.md#4a. Close-Out Sweep'

# --- WHAT THE STUB HAS TO DECLARE, DERIVED FROM THE REAL SCRIPT --------------------------------
# apply.sh resolves the adjudication row's vocabulary from its SIBLING layer-drift.sh rather than
# holding literals (I86), and it fails closed when it cannot. So a stub that names only the
# declarations that existed when this fixture was written is an INCOMPLETE double: apply.sh exits
# 2 on every row and all the assertions below go vacuous in one step. That is measured, not
# hypothetical -- this file read `FIXTURE BROKEN` the moment `ADJ_KEEP_VERDICT` joined
# `ADJ_ROW_TOKEN`. Copying every PLAIN-LITERAL declaration verbatim means the next one arrives on
# its own. Literals only: the computed ones (`ADJ_VERDICTS` reads the schema out of a git ref)
# cannot run in a stub with no repository behind it, and apply.sh does not read them.
ADJ_DECLS="$(grep -E '^ADJ_[A-Z][A-Za-z0-9_]*="[^"$`]*"$' "$REC/layer-drift.sh" || true)"
ADJ_TOK="$(printf '%s\n' "$ADJ_DECLS" | sed -n 's/^ADJ_ROW_TOKEN="\([^"]*\)".*/\1/p' | head -1)"
ADJ_KEEP="$(printf '%s\n' "$ADJ_DECLS" | sed -n 's/^ADJ_KEEP_VERDICT="\([^"]*\)".*/\1/p' | head -1)"

# THE TWO VERDICTS THAT AUTHORIZE THE REMEDY, as seed input. The vocabulary is owned by
# `core/schemas/layer-adjudication-register.json`'s enum and bound to it by `layer-adjudication-tier`
# and by the distribution's own vocabulary join; nothing here restates it. These are the two members that
# are NOT the keep disposition, and the control below is what makes them so -- seeding a literal
# that silently became the keep verdict would leave every act-direction arm asserting the
# suppression it exists to forbid.
V_ACT1='retire'
V_ACT2='contradicts-core'

# CONTROLS ON THE SEED ITSELF, BEFORE ANY ROW IS READ. Each of these failing silently would make a
# whole direction of the fixture vacuous rather than red.
if [ -n "$ADJ_TOK" ] && [ -n "$ADJ_KEEP" ]; then
  ok "the stub's ADJ_ declarations are copied from the real layer-drift.sh (token '$ADJ_TOK', keep verdict '$ADJ_KEEP')"
else
  bad "FIXTURE BROKEN — could not resolve ADJ_ROW_TOKEN ('$ADJ_TOK') and/or ADJ_KEEP_VERDICT ('$ADJ_KEEP') from $REC/layer-drift.sh; apply.sh fails closed without them and every arm below would report on a run that emitted nothing"
  echo; echo "apply-worklist-rows: FIXTURE BROKEN" >&2; exit 2
fi
if [ "$V_ACT1" != "$ADJ_KEEP" ] && [ "$V_ACT2" != "$ADJ_KEEP" ]; then
  ok "  and the two act-direction seeds ('$V_ACT1', '$V_ACT2') are both DISTINCT from it — the arms below can tell the branch apart"
else
  bad "FIXTURE BROKEN — an act-direction seed equals the keep verdict '$ADJ_KEEP', so the arms requiring the retire sequence are asserting against the suppression path"
  echo; echo "apply-worklist-rows: FIXTURE BROKEN" >&2; exit 2
fi

# Build a reconcile directory: every shipped script, with layer-drift replaced by a stub emitting
# the three detail shapes whose rendering differs.
#
#   one-key       `replaces_with=` only          -> 1/2 write the key, 2/2 --stamp retire
#   multi-key     `replaces_with=` + `retire_anchor=` -> 1/2 write the key, 2/2 NARROW shadows:
#   multi-adopted `retire_anchor=` alone         -> one row, NARROW shadows:, no ATOMIC sequence
#
# One key is the case that emitted zero rows, and it is also the only shape core has ever
# declared with a key. `multi-adopted` is the shape that makes the token parse POSITIONAL: read
# with the old `${detail#replaces_with=}` + equality guard it yields `env_key=retire_anchor=<...>`
# and instructs the operator to write that string into settings.json as an environment key.
build_rec() { # build_rec <dir>
  # The `.md` siblings travel too: preclassify reads `setup-sites.md` beside itself, and a missing
  # manifest is a refusal (a broken install), not an empty set.
  mkdir -p "$1" && cp "$REC"/*.sh "$REC"/*.md "$1"/ || return 1
  # THE STUB CARRIES THE REAL SCRIPT'S `ADJ_` DECLARATIONS, COPIED. See the derivation above for
  # why they are copied rather than written out here.
  #
  # THE FOUR ADJUDICATED ROWS DIFFER IN THE VERDICT AND IN NOTHING ELSE THAT MATTERS. `${OVR_J}`
  # and `${OVR_JR}` are byte-twins apart from the verdict and the subject path, which is what lets
  # the differential below assert that the branch reads the verdict rather than the token.
  #
  #   ${OVR_J}   keep verdict, key + anchor       -> NOTE, no steps
  #   ${OVR_JR}  act verdict,  key + anchor       -> 1/2 write the key, 2/2 NARROW shadows:
  #   ${OVR_KR}  act verdict,  key only           -> 1/2 write the key, 2/2 --stamp retire
  #   ${OVR_KC}  other act verdict, key only      -> same, and the row cites the verdict
  #   ${OVR_AR}  act verdict,  anchor only        -> one row, NARROW shadows:, no ATOMIC sequence
  #
  # `${OVR_AR}` is the destructive shape. The adjudication token is an ordered prefix AHEAD of
  # `replaces_with=`/`retire_anchor=`, so an act branch that emits the sequence without stripping
  # it leaves both later tokens unmatched, lands in the no-key/no-anchor arm and prescribes
  # `--stamp retire` -- which deletes the whole override file when core superseded ONE anchor.
  cat > "$1/layer-drift.sh" <<STUB
#!/usr/bin/env bash
${ADJ_DECLS}
printf 'OVERRIDE-SUPERSEDED\t${OVR}\tsteps/w.md\treplaces_with=AI_DLC_ONE_KEY :: core 0.1.0 provides what this entry was written to work around.\n'
printf 'OVERRIDE-SUPERSEDED\t${OVR_M}\tsteps/w.md\treplaces_with=AI_DLC_ONE_KEY :: retire_anchor=${ANCHOR} :: core 0.1.0 provides what this entry'"'"'s shadow was written to work around.\n'
printf 'OVERRIDE-SUPERSEDED\t${OVR_A}\tsteps/w.md\tretire_anchor=${ANCHOR} :: core 0.1.0 ADOPTED what this entry says under that anchor.\n'
printf 'OVERRIDE-SUPERSEDED\t${OVR_J}\tsteps/w.md\t${ADJ_TOK}=${ADJ_KEEP} :: replaces_with=AI_DLC_ONE_KEY :: retire_anchor=${ANCHOR} :: core 0.1.0 provides what this entry was written to work around.\n'
printf 'OVERRIDE-SUPERSEDED\t${OVR_JR}\tsteps/w.md\t${ADJ_TOK}=${V_ACT1} :: replaces_with=AI_DLC_ONE_KEY :: retire_anchor=${ANCHOR} :: core 0.1.0 provides what this entry was written to work around.\n'
printf 'OVERRIDE-SUPERSEDED\t${OVR_KR}\tsteps/w.md\t${ADJ_TOK}=${V_ACT1} :: replaces_with=AI_DLC_ONE_KEY :: core 0.1.0 provides what this entry was written to work around.\n'
printf 'OVERRIDE-SUPERSEDED\t${OVR_KC}\tsteps/w.md\t${ADJ_TOK}=${V_ACT2} :: replaces_with=AI_DLC_ONE_KEY :: core 0.1.0 provides what this entry was written to work around.\n'
printf 'OVERRIDE-SUPERSEDED\t${OVR_AR}\tsteps/w.md\t${ADJ_TOK}=${V_ACT1} :: retire_anchor=${ANCHOR} :: core 0.1.0 ADOPTED what this entry says under that anchor.\n'
printf 'HARD-OVERRIDE-DRIFT-SECTION\t${OVR_H}\tsteps/w.md\tthe shadowed section moved upstream\n'
printf 'OVERRIDE-SUPERSEDED\t${OVR_H}\tsteps/w.md\treplaces_with=AI_DLC_ONE_KEY :: core 0.1.0 provides what this entry was written to work around.\n'
printf 'HARD-OVERRIDE-DRIFT-SECTION\t${OVR_HA}\tsteps/w.md\tthe shadowed section moved upstream\n'
printf 'OVERRIDE-SUPERSEDED\t${OVR_HA}\tsteps/w.md\tretire_anchor=${ANCHOR} :: core 0.1.0 ADOPTED what this entry says under that anchor.\n'
STUB
  chmod +x "$1/layer-drift.sh"
}

# ONE apply.sh run per reconcile directory. Every question asked of a directory (rows, notes,
# subsumed notes for any entry) reads the same stdout of the same world, so the run is captured once
# beside the directory and each entry is a filter over it. The cache lives INSIDE the directory it
# describes, so the run is read from its own directory.
run_rec() { # run_rec <rec-dir> -> that directory's apply.sh stdout
  [ -f "$1/.run.out" ] || bash "$1/apply.sh" "$W/dist" HEAD "$W/cons" HEAD 2>/dev/null > "$1/.run.out"
  cat "$1/.run.out"
}
# Rows for ONE entry, one per line, TAB-separated as apply.sh prints them.
rows_for() { # rows_for <rec-dir> <entry>
  run_rec "$1" \
    | awk -F'\t' -v o="$2" '$1=="WORKLIST" && $2=="override-retire" && $3==o'
}
retire_rows() { rows_for "$1" "$OVR"; }
# The COUNT of override-adjudicated NOTE rows for one entry, from the same driven run.
notes_for() { # notes_for <rec-dir> <entry>
  run_rec "$1" \
    | awk -F'\t' -v o="$2" '$1=="NOTE" && $2=="override-adjudicated" && $3==o' | grep -c . || true
}

echo "HERMETIC-CONSUMED $REC/apply.sh"
build_rec "$W/rec" || { bad "FIXTURE BROKEN — could not stage reconcile/"; echo; echo "apply-worklist-rows: FIXTURE BROKEN" >&2; exit 2; }

ROWS="$(retire_rows "$W/rec")"
N_ROWS="$(printf '%s\n' "$ROWS" | grep -c . || true)"

# --- SANITY: the harness produced rows at all ----------------------------------------------
# Both assertions below read this output. A run that emitted nothing — a stub apply.sh could
# not source, a changed row vocabulary — would satisfy neither by failing, which is the state
# this arm exists to separate from a real regression.
if [ "$N_ROWS" -ge 1 ]; then
  ok "the driven apply.sh emitted override-retire rows for the seeded supersession ($N_ROWS)"
else
  bad "FIXTURE BROKEN — apply.sh emitted NO override-retire row; the two assertions below would be vacuous"
  echo; echo "apply-worklist-rows: FIXTURE BROKEN" >&2; exit 2
fi

# --- ASSERTION 1: the ATOMIC sequence emits every step it numbers ---------------------------
# One declared key means two steps: write the key, then retire. The count is what defect 2
# broke, and it is deliberately insensitive to whether the detail field prints — so a
# regression in `say()` cannot also red this arm.
assert_count() { # assert_count <rows> <label>
  local n; n="$(printf '%s\n' "$1" | grep -c . || true)"
  [ "$n" -eq 2 ]
}
if assert_count "$ROWS"; then
  ok "a one-key supersession emits BOTH numbered steps (1/2 write the key, 2/2 retire)"
else
  bad "the ATOMIC sequence emitted ${N_ROWS} row(s), not 2 — a step it numbers is never printed, and the retire is the one that survives"
fi

# --- ASSERTION 2: a row carries its instruction ---------------------------------------------
# Read the LAST step's detail, not the first: the last row is emitted under BOTH defects, so
# this arm moves only when the detail field itself is lost. Asserting a POSITIVE outcome — the
# field is present and names the ordered step — rather than the absence of an old shape.
last_detail() { printf '%s\n' "$1" | awk -F'\t' 'NF>=4 {d=$4} END {print d}'; }
D_LAST="$(last_detail "$ROWS")"
case "$D_LAST" in
  *"ATOMIC"*) ok "  and the row carries its detail — the step the operator must perform is printed, not just its subject" ;;
  "")         bad "the worklist row printed NO detail field at all: the key to write, the ordering constraint and the reason were computed and discarded, and SKILL.md tells the reader to obey a field that is not there" ;;
  *)          bad "the detail field is present but does not name the ordered step: ${D_LAST:0:70}" ;;
esac

# --- ASSERTION 3: a superseded ANCHOR is narrowed, never retired -----------------------------
#
# `readopt-override.sh --stamp retire` DELETES THE OVERRIDE FILE; there is no per-anchor retire.
# When core supersedes ONE anchor of a multi-anchor `shadows:`, an operator obeying a retire row
# throws away the anchors core did NOT supersede, and every section they shadowed silently
# reverts to core. This is the one row in the file whose failure direction is destroying consumer
# text, so it is asserted on the RENDERED row rather than on the token layer-drift emits.
M_ROWS="$(rows_for "$W/rec" "$OVR_M")"
M_LAST="$(last_detail "$M_ROWS")"
case "$M_LAST" in
  *"remove the anchor"*"$ANCHOR"*) ok "a multi-anchor supersession's LAST step narrows shadows: and names the anchor" ;;
  *"--stamp retire"*)              bad "the last step is still a retire stamp on a multi-anchor entry — obeying it deletes the anchors core did NOT supersede" ;;
  *)                               bad "the multi-anchor last step names no action this fixture recognises: ${M_LAST:0:80}" ;;
esac
case "$M_LAST" in
  *"NOT --stamp retire"*) ok "  and it says outright that the retire stamp is the wrong action here" ;;
  *)                      bad "  the row narrows the shadow but never warns off --stamp retire, which is the instruction the operator already knows" ;;
esac

# --- ASSERTION 4: the token prefix is parsed positionally, not searched for -------------------
# An env-LESS multi-anchor detail leads with `retire_anchor=`. Read by the old
# `${detail#replaces_with=}` + "equals the whole detail" guard, that yields
# `env_key=retire_anchor=steps/w.md#4a. Close-Out Sweep` and renders a 1/2 ATOMIC row telling the
# operator to write that string into settings.json "env" as a key. There is no such key.
A_ROWS="$(rows_for "$W/rec" "$OVR_A")"
if [ "$(printf '%s\n' "$A_ROWS" | grep -c 'ATOMIC' || true)" -eq 0 ]; then
  ok "an env-less supersession renders NO ATOMIC sequence — there is no key to write, so there is no order to enforce"
else
  bad "an env-less detail rendered an ATOMIC sequence: the token after the prefix was parsed as an environment key, and the operator is told to write it into settings.json"
fi
case "$(last_detail "$A_ROWS")" in
  *"remove the anchor"*"$ANCHOR"*) ok "  and its single row still narrows shadows: rather than retiring the entry" ;;
  *)                               bad "  the env-less multi-anchor row does not narrow the shadow: $(last_detail "$A_ROWS" | cut -c1-80)" ;;
esac


subsumed_for() { # subsumed_for <rec-dir> <entry>
  run_rec "$1" \
    | awk -F'\t' -v o="$2" '$1=="NOTE" && $2=="override-readopt-subsumed" && $3==o' | grep -c . || true
}
# --- ASSERTION 5: a row carrying a RECORDED VERDICT emits no retire steps -------------------
# PC-S327: apply.sh built this worklist from layer-drift's rows and never asked whether the
# project had already decided. layer-drift.sh now writes `adjudicated=<verdict>` into the row
# when a verdict exists for that digest, and apply.sh must emit a NOTE instead of the ATOMIC
# retire sequence. Acting on those steps would UNDO a decision, not complete one — on the
# reference consumer, 119 consumer-only lines including a live closure guard.
#
# BOTH DIRECTIONS IN ONE ARM, because suppression that cannot be turned off is an exemption:
# the three rows above carry no token and must still produce their retire rows, which the
# assertions above already require. This one requires the fourth to produce none.
ADJ_ROWS="$(rows_for "$W/rec" "$OVR_J")"
ADJ_N="$(printf '%s\n' "$ADJ_ROWS" | grep -c . || true)"
ADJ_NOTE="$(notes_for "$W/rec" "$OVR_J")"
if [ "$ADJ_N" -eq 0 ] && [ "$ADJ_NOTE" -ge 1 ]; then
  ok "a KEEP verdict ('$ADJ_KEEP') emits a NOTE and NO retire steps"
else
  bad "an adjudicated supersession row carrying the KEEP verdict emitted $ADJ_N retire row(s) and $ADJ_NOTE note(s) — apply.sh is prescribing work over a recorded verdict (PC-S327)"
fi

# --- ASSERTION 6: an ACT verdict emits the sequence the operator recorded it to authorize ------
#
# PC-S307, the mirror of the arm above and produced by its fix. That fix keyed the suppression on
# the token's PRESENCE, so it fired for every member of the vocabulary: `adj_v` was extracted and
# then used for nothing but interpolation into the NOTE's own text, which asserts "acting on them
# would undo a decision, not complete one" -- a sentence that is true of the keep verdict alone.
# Recording the HONEST verdict was therefore what made the remedy unreachable, and the reference
# consumer hit it live on its 0.427.0 -> 0.430.1 pull.
#
# KEYED ON THE ROWS, NEVER ON A SPELLING. Which name the branch tests, and whether it tests a
# literal or a resolved declaration, is not this fixture's business: a grep for a verdict name in
# apply.sh passes against an apply.sh that mentions it in a comment and branches wrongly. What is
# asserted here is which rows reach the operator for which verdict.
assert_seq() { # assert_seq <subject> <expected-last-action-substring> <label>
  local rows n first last
  rows="$(rows_for "$W/rec" "$1")"
  n="$(printf '%s\n' "$rows" | grep -c . || true)"
  last="$(last_detail "$rows")"
  first="$(printf '%s\n' "$rows" | awk -F'\t' 'NF>=4 {print $4; exit}')"
  if [ "$n" -ne 2 ]; then
    bad "$3: the ATOMIC sequence emitted ${n} row(s), not 2 — a recorded verdict that AUTHORIZES the retire is suppressing the steps it authorizes (PC-S307)"
    return
  fi
  ok "$3: both numbered steps are emitted over the recorded verdict"
  case "$first" in
    "1/2 ATOMIC"*"AI_DLC_ONE_KEY"*) ok "  and step 1/2 is the key write, so the sequence still leads with the write" ;;
    *)                              bad "  step 1/2 is not the key write: ${first:0:80}" ;;
  esac
  case "$last" in
    "2/2 ATOMIC"*"$2"*) ok "  and step 2/2 — the LAST step — is the ${2:0:24}…, which is the order the block exists to enforce" ;;
    *"$2"*)             bad "  the expected last action appears but not as the numbered final step: ${last:0:80}" ;;
    *)                  bad "  the last step is not the expected action: ${last:0:90}" ;;
  esac
  case "$first" in
    *"--stamp retire"*|*"remove the anchor"*)
      bad "  the FIRST step already carries the destructive action — stamping before the key is written re-imposes the core constraint and reds the next gate" ;;
    *) ok "  and no earlier step carries it — the retire is LAST, not merely present" ;;
  esac
}
assert_seq "$OVR_KR" "--stamp retire"                "a '$V_ACT1' verdict on a keyed supersession"
assert_seq "$OVR_KC" "--stamp retire"                "a '$V_ACT2' verdict on a keyed supersession"
assert_seq "$OVR_JR" "remove the anchor \`$ANCHOR\`" "a '$V_ACT1' verdict on a MULTI-ANCHOR supersession"

# --- ASSERTION 7: the act branch CITES the verdict as the authorization ------------------------
# Asserted on the `$V_ACT2` subject alone, deliberately: `--stamp retire` contains the string
# `$V_ACT1`, so that subject cannot tell a citation from the action's own name.
case "$(last_detail "$(rows_for "$W/rec" "$OVR_KC")")" in
  *"$V_ACT2"*) ok "  and the row NAMES the recorded verdict — the operator can see the steps are the decision being carried out, not the pull ignoring it" ;;
  *)           bad "  the emitted sequence never mentions the verdict that authorized it, so it is indistinguishable from a pull that never read the register" ;;
esac

# --- ASSERTION 8: the token is STRIPPED before the positional parse ----------------------------
#
# THE ONE DIRECTION HERE WHOSE FAILURE DESTROYS CONSUMER TEXT. `${ADJ_TOK}=` is an ordered prefix
# sitting AHEAD of `replaces_with=`/`retire_anchor=`, and those are parsed positionally. An act
# branch that falls through with the token still attached matches neither, so an env-less
# multi-anchor supersession lands in the no-key/no-anchor arm and the operator is handed
# `--stamp retire` — which deletes the whole override file, including the anchors core did NOT
# supersede. This failure cannot exist while the branch always suppresses, so it arrives WITH the
# fix and nothing before now could have caught it.
AR_ROWS="$(rows_for "$W/rec" "$OVR_AR")"
if [ "$(printf '%s\n' "$AR_ROWS" | grep -c 'ATOMIC' || true)" -eq 0 ]; then
  ok "an adjudicated env-LESS supersession renders NO ATOMIC sequence — the token did not parse as an environment key"
else
  bad "an adjudicated env-less detail rendered an ATOMIC sequence: the adjudication token was read as a key and the operator is told to write it into settings.json"
fi
case "$(last_detail "$AR_ROWS")" in
  *"remove the anchor"*"$ANCHOR"*) ok "  and its single row narrows shadows: rather than retiring the entry" ;;
  *"--stamp retire"*)              bad "  an adjudicated env-less multi-anchor row prescribes --stamp retire: the adjudication prefix was not stripped, retire_anchor= never matched, and obeying this row DELETES the anchors core did not supersede" ;;
  "")                              bad "  the adjudicated env-less multi-anchor supersession emitted NO row at all — the verdict suppressed the narrowing it authorized (PC-S307)" ;;
  *)                               bad "  the adjudicated env-less row names no action this fixture recognises: $(last_detail "$AR_ROWS" | cut -c1-90)" ;;
esac

# --- ASSERTION 9: the DIFFERENTIAL, which is what makes the arms above about the VERDICT --------
# `$OVR_J` and `$OVR_JR` carry the same key, the same anchor and the same prose; they differ in
# the verdict alone. Asserting the two row sets DIFFER is the one arm here that cannot be
# satisfied by any implementation reading the token's presence, whatever it spells its branch,
# and it is checked against the seeds actually built rather than assumed.
if [ "$ADJ_N" -eq 0 ] && [ "$(printf '%s\n' "$(rows_for "$W/rec" "$OVR_JR")" | grep -c . || true)" -eq 2 ]; then
  ok "two rows identical but for the verdict produce DIFFERENT row sets (0 steps vs 2) — the branch reads the verdict, not the token's presence"
else
  bad "two rows identical but for the verdict produced the SAME outcome — apply.sh is matching the token's presence, so the recorded verdict changes nothing (PC-S307)"
fi

# --- ASSERTION 10: the un-adjudicated baseline acquires no NOTE --------------------------------
# The mirror of assertion 5. A branch that emits its NOTE outside the token arm tells the operator
# a verdict was recorded for a subject the register has never seen.
BASE_NOTES=$(( $(notes_for "$W/rec" "$OVR") + $(notes_for "$W/rec" "$OVR_M") + $(notes_for "$W/rec" "$OVR_A") ))
if [ "$BASE_NOTES" -eq 0 ]; then
  ok "the three token-LESS subjects acquire no override-adjudicated NOTE — the note is a property of the row, not of the run"
else
  bad "$BASE_NOTES token-less subject(s) were reported as adjudicated: apply.sh is claiming a recorded verdict for a subject with none"
fi

# --- AN OVERRIDE THAT IS BOTH DRIFT-HARD AND SUPERSEDED (PC-S331) -------------------------------
# Two remedies were built for this and BOTH were regressions, which is why the arms below assert
# what SURVIVES and not merely that something changed:
#   - suppressing the retire sequence left only the readopt — deleting the real work and keeping
#     the futile work, so arm 10 requires the retire rows to still be there;
#   - deleting "Same commit as the row(s) above." took the ATOMIC ordering instruction with it,
#     and that order is a safety property (SKILL.md:1131-1137), so arm 11 requires an atomicity
#     instruction to still be present while arm 12 requires it to stop saying "above".
H_ROWS="$(rows_for "$W/rec" "$OVR_H")"
H_LAST="$(last_detail "$H_ROWS")"

if [ "$(subsumed_for "$W/rec" "$OVR_H")" -ge 1 ]; then
  ok "9  a drift-hard AND superseded entry gets an override-readopt-subsumed NOTE — the reason the readopt is futile reaches the OPERATOR, not just the source comment"
else
  bad "9  no override-readopt-subsumed NOTE for $OVR_H: the readopt row and the retire sequence are printed for one path with nothing marking the first as subsumed (PC-S331)"
fi

if [ "$(printf '%s\n' "$H_ROWS" | grep -c . || true)" -ge 1 ]; then
  ok "10 and its retire sequence is STILL EMITTED — the subsumption marks the readopt, it does not delete the work that resolves the supersession"
else
  bad "10 the retire sequence for $OVR_H is gone: marking the readopt must not suppress the retire, which is the only row that resolves the supersession"
fi

case "$H_LAST" in
  *"Same commit"*) ok "11 the final ATOMIC step still carries its atomicity instruction — the ordering is a safety property and survives the rewording" ;;
  *)               bad "11 the final ATOMIC step for $OVR_H no longer says the steps share a commit: retire-before-key-write re-imposes the constraint and reds the next gate" ;;
esac

case "$H_LAST" in
  *"row(s) above"*) bad "12 the final ATOMIC step still says \"the row(s) above\", which for this entry names the override-readopt row it must NOT be committed with" ;;
  *)                ok "12 and it no longer says \"the row(s) above\" — it names its own sequence, so the readopt row printed above is not swept into the commit" ;;
esac

# THE EXEMPTION'S OWN PROBE. A guard that marked EVERY drift-hard supersession would pass arms
# 9-12 and destroy live work: `retire_anchor=` leaves the entry on disk, so its readopt is how the
# sections core did NOT supersede get the moved text. An exemption needs a probe proving it does
# not cover the arm's own subject.
if [ "$(subsumed_for "$W/rec" "$OVR_HA")" -eq 0 ]; then
  ok "13 a drift-hard entry superseded by retire_anchor= is NOT marked subsumed — the entry survives the anchor drop, so its readopt is real work"
else
  bad "13 $OVR_HA was marked subsumed, but retire_anchor= drops ONE anchor and leaves the file: the readopt is how its remaining shadowed sections get the moved text"
fi

echo ""
report_end apply-worklist-rows
