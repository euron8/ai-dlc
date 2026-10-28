#!/usr/bin/env bash
# check-24-adversarial-convergence/receipt-bl814.sh [<validator>] -- the backlog receipt for BL-814: a
# MAJOR the terminal EXIT_CONDITION_MET pass leaves is closed on a record -- repaired by a linked repair
# entry of that pass naming it in `source:`, or deferred to the step's declared successor -- and the
# successor's context digest names every key deferred to it (arm J3). It drives the SHIPPED validator in
# a mktemp world and reads no fixture file.
#
#   exit 0   the fix is present        exit 1   it is not        exit 9   the receipt cannot measure
#
# The subject is resolved from this file's tree (core/scripts/ in the distribution, scripts/ai-dlc/
# installed); an argument names another copy, which is how the base and a mutant are scored.
#
# Each world is its own git repository, stamped at the validator's own J3_RELEASE (RCPT_STAMP_FROM when
# set), its series under `_bmad-output/planning-artifacts/s1/`, each pass the merge's sharded shape:
#   undeferred   coe, 1.md#F-1 and cross-1.md#F-1 MAJOR, no record            FAIL (J3), exit 1
#   deferred     coe, both keys deferred to requirements                       J3 silent, exit 0
#   deferbold    the same, bold labels, backticks, a pass-qualified token      J3 silent, exit 0
#   wrongstep    coe, both deferred to architecture                            FAIL (J3), exit 1
#   repaired     architecture, both named by a repair entry linked from the notarized sha   silent, 0
#   dirrepaired  graph s320 stories-p4's shape: a directory artifact, a `<stem>@<sha>` list, per-story
#                shards and one joined record whose per-file entries chain from those shas  silent, 0
#   stalepass    architecture p2's 1.md#F-1, named only by pass 1's repair record          FAIL, 1
#   unlinked     the repair entry starts from a sha the pass never notarized   FAIL (J3), exit 1
#   twof1        1.md#F-1 repaired, cross-1.md#F-1 neither (a bare `F-1` key reads both closed)  FAIL, 1
#   underonly    coe, major 2 = underived 2 (blocking 0), undeferred           FAIL (J3), exit 1
#   unkeyed      findings_major 2, one MAJOR heading, that one deferred        FAIL (J3), exit 1
#   nosucc       stories, both deferred -- stories declares no successor       FAIL (J3) naming that
#   legacy       undeferred's bytes, the series opened before the stamp        PENDING (J3), exit 0
#   succmiss     architecture series; a requirements deferral record defers 1.md#F-1 to it and
#                architecture-context.md does not name it                      FAIL (J3 -- DEFERRAL), 1
#   succok       the same, the context digest names the key                    J3 silent, exit 0
#   substr       1.md#F-1 deferred; the digest names only cross-1.md#F-1, 1.md#F-10, x1.md#F-1   FAIL, 1
#   subok        the digest names it at a line start and inside backticks       J3 silent, exit 0
#   ident        the only repair triple is notarized -> notarized (no byte moved)               FAIL, 1
#   partlink     two triples in one record, only the first linked; its token closes, the other not  FAIL
#   seriallink   the repair record links, the serial record does not; only the first key closes    FAIL
#   dupid        findings_major 2 over two MAJOR headings that are one key       FAIL (unkeyed), 1
#   idpunct      ids written `F-1:` and `F-1.` close by the plain tokens (the join's normalisation)  0
#   undeferred's DEFER remedy says to dispatch a remediator (the lead's write is denied after a FAIL)
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR

HERE="$(cd "$(dirname "$0")" && pwd)"
SUBJ="${1:-}"
if [ -z "$SUBJ" ]; then
  for c in "$HERE/../../scripts/validate-adversarial-convergence.sh" \
           "$HERE/../../../scripts/ai-dlc/validate-adversarial-convergence.sh"; do
    [ -f "$c" ] && { SUBJ="$c"; break; }
  done
fi
[ -n "$SUBJ" ] && [ -f "$SUBJ" ] || { echo "receipt: no validate-adversarial-convergence.sh to score" >&2; exit 9; }
command -v git >/dev/null 2>&1 || { echo "receipt: git is not on PATH" >&2; exit 9; }
STAMP_FROM="${RCPT_STAMP_FROM:-$SUBJ}"
[ -f "$STAMP_FROM" ] || { echo "receipt: RCPT_STAMP_FROM names no file ($STAMP_FROM)" >&2; exit 9; }
# A copy with no constant (the base) is stamped at a release every later constant owes.
REL="$(sed -n 's/^J3_RELEASE="\([0-9.]*\)"$/\1/p' "$STAMP_FROM")"; [ -n "$REL" ] || REL="99.0.0"

# RCPT_WORLD_DIR (optional): build the worlds ONCE under <dir>/rel-<REL> and reuse them on every later
# call stamped at the same release. The validator only reads a world, so a set built for one subject is
# the set every other subject would build. Absent, each call builds its own under mktemp, as before.
if [ -n "${RCPT_WORLD_DIR:-}" ]; then
  B="$RCPT_WORLD_DIR/rel-$REL"
  [ ! -d "$B" ] || [ -f "$B/.built" ] || { echo "receipt: $B holds a partial world set" >&2; exit 9; }
  mkdir -p "$B" || exit 9
else
  B="$(mktemp -d "${TMPDIR:-/tmp}/bl814-receipt-XXXXXX")" || exit 9
fi
B="$(cd "$B" && pwd -P)"
# RCPT_WORLDS (optional): judge only the named worlds. Every name must be one this receipt judges, or
# the call is refused (exit 9) -- a filter naming nothing real would otherwise report `fixed`.
# A world left out never runs the subject; its check line reads rc=99 and is dropped from the verdict, so
# the NOT FIXED line under a filter is exactly the unfiltered line restricted to the named worlds.
want() { [ -z "${RCPT_WORLDS:-}" ] && { RAN="$RAN $1 "; return 0; }; case " $RCPT_WORLDS " in *" $1 "*) RAN="$RAN $1 "; return 0 ;; esac; return 1; }
RAN=""
rcpt_filter() {
  [ -n "${RCPT_WORLDS:-}" ] || return 0
  local x kept=""
  for x in $RCPT_WORLDS; do
    case "$RAN" in *" $x "*) ;; *) echo "receipt: RCPT_WORLDS names '$x', which this receipt does not judge" >&2; exit 9 ;; esac
  done
  for x in $bad; do case "$x" in *"(rc=99)") ;; *) kept="$kept $x" ;; esac; done
  bad="$kept"
}
D=_bmad-output/planning-artifacts/s1
lg() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$1" -c user.name=r -c user.email=r@example.invalid \
       -c core.hooksPath=/dev/null -c commit.gpgsign=false "${@:2}"; }
sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1; else sha256sum "$1" | cut -d' ' -f1; fi; }
doc() { printf '# %s\n\n## Body\n\nrevision %s\n' "$1" "$2"; }   # one `##` section: arm K2 calls it serial
world() { # name -> the repo, stamped 0.669.0 at 09:00 and REL at 10:00
  local w="$B/$1"
  mkdir -p "$w/.claude" "$w/$D" || return 1
  ( printf 'version: 0.669.0\n' > "$w/.claude/.ai-dlc-version"
    lg "$w" init -q . && lg "$w" add .claude/.ai-dlc-version \
      && GIT_COMMITTER_DATE=2026-09-29T09:00:00Z GIT_AUTHOR_DATE=2026-09-29T09:00:00Z lg "$w" commit -q -m stamp-old || exit 1
    printf 'version: %s\n' "$REL" > "$w/.claude/.ai-dlc-version" && lg "$w" add .claude/.ai-dlc-version \
      && GIT_COMMITTER_DATE=2026-09-29T10:00:00Z GIT_AUTHOR_DATE=2026-09-29T10:00:00Z lg "$w" commit -q -m stamp-new ) >/dev/null 2>&1
}
# pass <world> <stem> <n> <artifact file> <sha> <major> <underived> <verdict> <invoked_at> <headings...>
#   Each heading spec is `<shard heading>|<id>|<severity>`, written under its own `## Shard:` and `## Findings`.
pass() {
  local w="$1" st="$2" n="$3" art="$4" s="$5" mj="$6" un="$7" v="$8" at="$9" h; shift 9
  { printf '# %s -- adversarial pass %s (merged from shards)\n' "$st" "$n"
    for h in "$@"; do
      printf '\n## Shard: %s\n\n## Findings\n\n### %s — %s — a finding\n\nbody\n' "${h%%|*}" "$(printf '%s' "$h" | cut -d'|' -f2)" "${h##*|}"
    done
    printf '\n<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: ai-dlc-adversary-review\ninvoked_at: %s\ntool_use_id: toolu_receipt_%s%s\n' "$at" "$st" "$n"
    printf 'mode: subagent\nlead_role: analyst\nartifact: %s\nartifact_sha: %s\n' "$D/$art" "$s"
    [ -z "${PASS_IDS:-}" ] || printf 'shard_tool_use_ids: %s\n' "$PASS_IDS"
    printf 'findings_critical: 0\nfindings_critical_prior_scope: 0\nfindings_major: %s\nfindings_major_underived: %s\nfindings_minor: 0\n' "$mj" "$un"
    printf 'verdict: %s\nSKILL_INVOCATION_PROVENANCE_END -->\n' "$v"; } > "$B/$w/$D/$st-adversarial-p$n.md"
}
# repair <file> <artifact> <before> <after> <source tokens...>  -- one entry per token, the remediator form
repair() {
  local f="$1" a="$2" b="$3" af="$4" t; shift 4
  { printf '# repair record\n\n- artifact: %s\n- artifact_sha_before: %s\n- artifact_sha_after: %s\n' "$D/$a" "$b" "$af"
    for t in "$@"; do printf '\n### %s — MAJOR\n- source: %s\n- disposition: repaired\n- edit: %s:3\n- derivation: n/a (no factual claim)\n' "${t#*#}" "$t" "$D/$a"; done
  } > "$f"
}
defer() { # <file> <step> <tokens...>
  local f="$1" s="$2" t; shift 2
  { printf '# deferral record\n'; for t in "$@"; do printf '\n- source: %s\n- deferred-to: %s\n' "$t" "$s"; done; } > "$f"
}
TWO="section 1|F-1|MAJOR"
TWOX="cross-section group 1 (1,2)|F-1|MAJOR"
coe_world() { # name invoked_at major underived [headings...] -> coe series p1 over carry-over-evaluation.md
  local n="$1" at="$2" mj="$3" un="$4"; shift 4
  world "$n" || return 1
  doc coe 1 > "$B/$n/$D/carry-over-evaluation.md"
  pass "$n" coe 1 carry-over-evaluation.md "$(sha "$B/$n/$D/carry-over-evaluation.md")" "$mj" "$un" EXIT_CONDITION_MET "$at" "$@"
}
build() {
  coe_world undeferred 2026-09-29T11:00:00Z 2 0 "$TWO" "$TWOX" || return 1
  coe_world deferred 2026-09-29T11:00:00Z 2 0 "$TWO" "$TWOX" || return 1
  defer "$B/deferred/$D/coe-deferral-p1.md" requirements 1.md#F-1 cross-1.md#F-1
  coe_world deferbold 2026-09-29T11:00:00Z 2 0 "$TWO" "$TWOX" || return 1
  printf '# deferral record\n\n- **source:** `coe-p1/1.md#F-1`\n- **deferred-to:** `requirements` (restated in requirements-context.md)\n\n- source: _bmad-output/planning-artifacts/s1/shards/coe-p1/cross-1.md#F-1\n- _deferred-to:_ requirements\n' \
    > "$B/deferbold/$D/coe-deferral-p1.md"
  coe_world wrongstep 2026-09-29T11:00:00Z 2 0 "$TWO" "$TWOX" || return 1
  defer "$B/wrongstep/$D/coe-deferral-p1.md" architecture 1.md#F-1 cross-1.md#F-1
  coe_world underonly 2026-09-29T11:00:00Z 2 2 "$TWO" "$TWOX" || return 1
  coe_world unkeyed 2026-09-29T11:00:00Z 2 0 "$TWO" || return 1
  defer "$B/unkeyed/$D/coe-deferral-p1.md" requirements 1.md#F-1
  coe_world legacy 2026-09-29T09:30:00Z 2 0 "$TWO" "$TWOX" || return 1
  # J3's basename dispatch: p12 (two digits) is judged. pxp2 and ptxt are near-misses it must NOT judge; each
  # still carries a pass number, because a name without one dies at arm ORDER before J3 is ever reached.
  # Each is undeferred's bytes under another name, so a misjudged near-miss would FAIL (J3).
  for w in p12:coe-adversarial-p12.md pxp2:coe-adversarial-px-p2.md ptxt:coe-adversarial-p1.txt; do
    coe_world "${w%%:*}" 2026-09-29T11:00:00Z 2 0 "$TWO" "$TWOX" || return 1
    mv "$B/${w%%:*}/$D/coe-adversarial-p1.md" "$B/${w%%:*}/$D/${w#*:}" || return 1
  done
  local w v1 v2 v0
  # repaired / unlinked / twof1: architecture p1 MET over v1; the repair moves it v1 -> v2 (arm J2's link).
  for w in repaired unlinked twof1; do
    world "$w" || return 1
    doc arch 1 > "$B/$w/$D/architecture.md"; v1="$(sha "$B/$w/$D/architecture.md")"
    pass "$w" architecture 1 architecture.md "$v1" 2 0 EXIT_CONDITION_MET 2026-09-29T11:00:00Z "$TWO" "$TWOX"
    doc arch 2 > "$B/$w/$D/architecture.md"; v2="$(sha "$B/$w/$D/architecture.md")"
  done
  repair "$B/repaired/$D/architecture-repair-p1.md" architecture.md "$(sha_of repaired 1)" "$(sha_of repaired 2)" 1.md#F-1 cross-1.md#F-1
  # unlinked: the record claims v0 -> v2; v0 is no sha the pass notarized (and no J2 link either).
  doc arch 0 > "$B/v0"; v0="$(sha "$B/v0")"
  repair "$B/unlinked/$D/architecture-repair-p1.md" architecture.md "$v0" "$(sha_of unlinked 2)" 1.md#F-1 cross-1.md#F-1
  repair "$B/twof1/$D/architecture-repair-p1.md" architecture.md "$(sha_of twof1 1)" "$(sha_of twof1 2)" 1.md#F-1
  # stalepass: p1 NOT_MET with 1.md#F-1, repaired v1 -> v2 by repair-p1; p2 MET over v2 carries its OWN
  # 1.md#F-1, which no record of pass 2 names. Ids collide across passes; the record is pass 1's.
  world stalepass || return 1
  doc arch 1 > "$B/stalepass/$D/architecture.md"
  pass stalepass architecture 1 architecture.md "$(sha_of stalepass 1)" 4 0 EXIT_CONDITION_NOT_MET 2026-09-29T11:00:00Z "$TWO"
  repair "$B/stalepass/$D/architecture-repair-p1.md" architecture.md "$(sha_of stalepass 1)" "$(sha_of stalepass 2)" 1.md#F-1
  # Pass 1's serial record moves v2 -> v3, so pass 1's records DO link from p2's notarized sha (and not by
  # an identity triple, which links nothing): only reading pass M's own records keeps the key open.
  repair "$B/stalepass/$D/architecture-serial-repair-p1.md" architecture.md "$(sha_of stalepass 2)" "$(sha_of stalepass 3)" 1.md#F-1
  doc arch 2 > "$B/stalepass/$D/architecture.md"
  pass stalepass architecture 2 architecture.md "$(sha_of stalepass 2)" 1 0 EXIT_CONDITION_MET 2026-09-29T12:00:00Z "$TWO"
  # dirrepaired: graph s320 stories-p4's shape -- a DIRECTORY artifact notarized as a `<stem>@<sha>` list,
  # a merged pass with per-story shards (and the merge's shard ids, so arm K is quiet), and a joined
  # repair record with one entry per story file, each chaining from that story's notarized sha.
  world dirrepaired || return 1
  mkdir -p "$B/dirrepaired/$D/arch"
  doc a 1 > "$B/dirrepaired/$D/arch/a.md"; doc b 1 > "$B/dirrepaired/$D/arch/b.md"
  local sa sb
  sa="$(sha "$B/dirrepaired/$D/arch/a.md")"; sb="$(sha "$B/dirrepaired/$D/arch/b.md")"
  PASS_IDS="01=toolu_01AbCdEfGhIjKlMnOpQrStUv 02=toolu_01BbCdEfGhIjKlMnOpQrStUv cross=toolu_01CbCdEfGhIjKlMnOpQrStUv" \
    pass dirrepaired architecture 1 arch "a@$sa b@$sb" 2 0 EXIT_CONDITION_MET 2026-09-29T11:00:00Z \
    "story 01|F-1|MAJOR" "story 02|F-1|MAJOR"
  { printf '# architecture repair -- pass 1 (joined from 2 shard records)\n'
    printf '\n<!-- shard: 1.md -->\n- artifact: %s/arch/a.md\n- artifact_sha_before: %s\n- artifact_sha_after: %s\n' "$D" "$sa" "$(doc a 2 > "$B/.a2"; sha "$B/.a2")"
    printf '\n### F-1 — MAJOR\n- source: 01.md#F-1\n- disposition: repaired\n- edit: %s/arch/a.md:3\n- derivation: n/a (no factual claim)\n' "$D"
    printf '\n<!-- shard: 2.md -->\n- **artifact:** `%s/arch/b.md`\n- **artifact_sha_before:** %s\n- **artifact_sha_after:** %s\n' "$D" "$sb" "$(doc b 2 > "$B/.b2"; sha "$B/.b2")"
    printf '\n### F-1 — MAJOR\n- **source:** `02.md#F-1`\n- **disposition:** repaired\n- **edit:** %s/arch/b.md:3\n- **derivation:** n/a\n' "$D"
  } > "$B/dirrepaired/$D/architecture-repair-p1.md"
  doc a 2 > "$B/dirrepaired/$D/arch/a.md"; doc b 2 > "$B/dirrepaired/$D/arch/b.md"
  # nosucc: stories declares no successor; a deferral cannot close its MAJORs.
  world nosucc || return 1
  doc stories 1 > "$B/nosucc/$D/stories.md"
  pass nosucc stories 1 stories.md "$(sha "$B/nosucc/$D/stories.md")" 2 0 EXIT_CONDITION_MET 2026-09-29T11:00:00Z "$TWO" "$TWOX"
  defer "$B/nosucc/$D/stories-deferral-p1.md" requirements 1.md#F-1 cross-1.md#F-1
  # succmiss / succok: the architecture series met clean; requirements deferred two keys to it.
  for w in succmiss succok; do
    world "$w" || return 1
    doc arch 1 > "$B/$w/$D/architecture.md"
    pass "$w" architecture 1 architecture.md "$(sha "$B/$w/$D/architecture.md")" 0 0 EXIT_CONDITION_MET 2026-09-29T11:00:00Z
    defer "$B/$w/$D/requirements-deferral-p2.md" architecture requirements-p2/1.md#F-1 requirements-p2/cross-1.md#F-2
    defer "$B/$w/$D/coe-deferral-p1.md" requirements coe-p1/4.md#F-9
  done
  printf '# architecture context\n\n## Inputs\n\n- requirements-p2/1.md#F-1 (restated as input A)\n' > "$B/succmiss/$D/architecture-context.md"
  printf '# architecture context\n\n## Inputs\n\n- requirements-p2/1.md#F-1 (input A)\n- requirements-p2/cross-1.md#F-2 (input B)\n' > "$B/succok/$D/architecture-context.md"
  # substr / subok: 1.md#F-1 deferred to architecture. substr's digest names only keys that CONTAIN it
  # (cross-1.md#F-1, 1.md#F-10, x1.md#F-1); subok's names it at a line start and inside backticks.
  for w in substr subok; do
    world "$w" || return 1
    doc arch 1 > "$B/$w/$D/architecture.md"
    pass "$w" architecture 1 architecture.md "$(sha "$B/$w/$D/architecture.md")" 0 0 EXIT_CONDITION_MET 2026-09-29T11:00:00Z
    defer "$B/$w/$D/requirements-deferral-p2.md" architecture 1.md#F-1 cross-1.md#F-2
  done
  printf '# ctx\n\n- cross-1.md#F-1 (A)\n- 1.md#F-10 (B)\n- x1.md#F-1 (C)\n- cross-1.md#F-2 (D)\n' > "$B/substr/$D/architecture-context.md"
  printf '1.md#F-1: input A\n- `cross-1.md#F-2`.\n' > "$B/subok/$D/architecture-context.md"
  # ident / partlink / seriallink: architecture p1 MET over v1, both keys named by a `repaired` entry.
  for w in ident partlink seriallink; do
    world "$w" || return 1
    doc arch 1 > "$B/$w/$D/architecture.md"
    pass "$w" architecture 1 architecture.md "$(sha_of x 1)" 2 0 EXIT_CONDITION_MET 2026-09-29T11:00:00Z "$TWO" "$TWOX"
    doc arch 2 > "$B/$w/$D/architecture.md"
  done
  # ident: one triple notarized -> notarized; no byte moved.
  repair "$B/ident/$D/architecture-repair-p1.md" architecture.md "$(sha_of x 1)" "$(sha_of x 1)" 1.md#F-1 cross-1.md#F-1
  # partlink: one record, two triples; only the first starts from the notarized sha.
  repair "$B/partlink/$D/architecture-repair-p1.md" architecture.md "$(sha_of x 1)" "$(sha_of x 2)" 1.md#F-1
  { printf '\n- artifact: %s/unrelated.md\n- artifact_sha_before: %s\n- artifact_sha_after: %s\n' "$D" "$(sha_of x 7)" "$(sha_of x 8)"
    printf '\n### F-1 — MAJOR\n- source: cross-1.md#F-1\n- disposition: repaired\n- edit: %s/unrelated.md:3\n- derivation: n/a\n' "$D"
  } >> "$B/partlink/$D/architecture-repair-p1.md"
  # seriallink: the repair record links; the serial record starts from a sha the pass never notarized.
  repair "$B/seriallink/$D/architecture-repair-p1.md" architecture.md "$(sha_of x 1)" "$(sha_of x 2)" 1.md#F-1
  repair "$B/seriallink/$D/architecture-serial-repair-p1.md" unrelated.md "$(sha_of x 7)" "$(sha_of x 8)" cross-1.md#F-1
  # dupid: findings_major 2 over two MAJOR headings that are ONE key (two `section 1` shards); one deferral.
  coe_world dupid 2026-09-29T11:00:00Z 2 0 "$TWO" "$TWO" || return 1
  defer "$B/dupid/$D/coe-deferral-p1.md" requirements 1.md#F-1
  # idpunct: the ids are written `F-1:` and `F-1.`; the join reads both as F-1, so the plain tokens close them.
  coe_world idpunct 2026-09-29T11:00:00Z 2 0 "section 1|F-1:|MAJOR" "cross-section group 1 (1,2)|F-1.|MAJOR" || return 1
  defer "$B/idpunct/$D/coe-deferral-p1.md" requirements 1.md#F-1 cross-1.md#F-1
}
sha_of() { doc arch "$2" > "$B/.v"; sha "$B/.v"; }
if [ ! -f "$B/.built" ]; then
  build || { echo "receipt: a world could not be built under $B" >&2; exit 9; }
  : > "$B/transcript.jsonl"
  : > "$B/.built"
fi
# THE WORLDS ARE WHAT THEY CLAIM: twof1 holds two keys sharing the id F-1, and stalepass's record is pass 1's.
[ "$(grep -c '^### F-1 — MAJOR' "$B/twof1/$D/architecture-adversarial-p1.md")" = 2 ] \
  && [ -f "$B/stalepass/$D/architecture-repair-p1.md" ] && [ ! -f "$B/stalepass/$D/architecture-repair-p2.md" ] \
  || { echo "receipt: twof1/stalepass shape wrong" >&2; exit 9; }

run() { # world stem -> RC, OUT
  OUT="$(GIT_CEILING_DIRECTORIES="$B" bash "$SUBJ" --series "$B/$1/$D/$2-adversarial-p" \
         --transcript "$B/transcript.jsonl" --transcript-dir "$B" 2>&1)"; RC=$?
}
bad=""
# A failing world's output goes to stderr, so a NOT FIXED line can be read without rebuilding the world.
run_() { run "$@"; }
run() { want "$1" || { OUT="__RCPT_SKIPPED__"; RC=99; return 0; }
  OUT="$(GIT_CEILING_DIRECTORIES="$B" bash "$SUBJ" --series "$B/$1/$D/$2-adversarial-p" \
         --transcript "$B/transcript.jsonl" --transcript-dir "$B" 2>&1)"; RC=$?
  [ -z "${RCPT_VERBOSE:-}" ] || printf '== %s rc=%s\n%s\n' "$1" "$RC" "$OUT" >&2; }
nj() { [[ "$OUT" != *"(J3 -- "* ]]; }
run undeferred coe; [ "$RC" -eq 1 ] && [[ "$OUT" == *"FAIL (J3 -- OPEN MAJOR)"* ]] && [[ "$OUT" == *"cross-1.md#F-1: repaired on no"* ]] \
  && [[ "$OUT" == *"DEFER    dispatch a remediator to write "*"coe-deferral-p1.md"* ]] || bad="$bad undeferred(rc=$RC)"
run p12 coe;        [ "$RC" -eq 1 ] && [[ "$OUT" == *"FAIL (J3 -- OPEN MAJOR)"* ]] || bad="$bad p12(rc=$RC)"
run pxp2 coe;       nj && [[ "$OUT" != *"FAIL (ORDER)"* ]] || bad="$bad pxp2(rc=$RC)"
run ptxt coe;       nj && [[ "$OUT" != *"FAIL (ORDER)"* ]] || bad="$bad ptxt(rc=$RC)"
run deferred coe;   [ "$RC" -eq 0 ] && nj || bad="$bad deferred(rc=$RC)"
run deferbold coe;  [ "$RC" -eq 0 ] && nj || bad="$bad deferbold(rc=$RC)"
run wrongstep coe;  [ "$RC" -eq 1 ] && [[ "$OUT" == *"deferred to architecture, not to requirements"* ]] || bad="$bad wrongstep(rc=$RC)"
run repaired architecture;  [ "$RC" -eq 0 ] && nj || bad="$bad repaired(rc=$RC)"
run dirrepaired architecture; [ "$RC" -eq 0 ] && nj || bad="$bad dirrepaired(rc=$RC)"
run stalepass architecture; [ "$RC" -eq 1 ] && [[ "$OUT" == *"FAIL (J3 -- OPEN MAJOR)"* ]] && [[ "$OUT" == *"1.md#F-1: repaired on no"* ]] || bad="$bad stalepass(rc=$RC)"
run unlinked architecture;  [[ "$OUT" == *"FAIL (J3 -- OPEN MAJOR)"* ]] || bad="$bad unlinked(rc=$RC)"
run twof1 architecture;     [ "$RC" -eq 1 ] && [[ "$OUT" == *"cross-1.md#F-1: repaired on no"* ]] && [[ "$OUT" != *"  1.md#F-1: repaired on no"* ]] || bad="$bad twof1(rc=$RC)"
run underonly coe;  [ "$RC" -eq 1 ] && [[ "$OUT" == *"FAIL (J3 -- OPEN MAJOR)"* ]] || bad="$bad underonly(rc=$RC)"
run unkeyed coe;    [ "$RC" -eq 1 ] && [[ "$OUT" == *"carry no MAJOR"* ]] || bad="$bad unkeyed(rc=$RC)"
run nosucc stories; [[ "$OUT" == *"FAIL (J3 -- OPEN MAJOR)"* ]] && [[ "$OUT" == *"declares no successor"* ]] || bad="$bad nosucc(rc=$RC)"
run legacy coe;     [ "$RC" -eq 0 ] && [[ "$OUT" == *"PENDING (J3 -- OPEN MAJOR)"* ]] && [[ "$OUT" == *"Legacy series."* ]] && [[ "$OUT" != *"FAIL (J3"* ]] || bad="$bad legacy(rc=$RC)"
run succmiss architecture; [ "$RC" -eq 1 ] && [[ "$OUT" == *"FAIL (J3 -- DEFERRAL)"* ]] && [[ "$OUT" == *"requirements-p2/cross-1.md#F-2 (requirements-deferral-p2.md)"* ]] && [[ "$OUT" != *"4.md#F-9"* ]] || bad="$bad succmiss(rc=$RC)"
run succok architecture;   [ "$RC" -eq 0 ] && nj || bad="$bad succok(rc=$RC)"
run substr architecture;   [ "$RC" -eq 1 ] && [[ "$OUT" == *"FAIL (J3 -- DEFERRAL)"* ]] && [[ "$OUT" == *" 1.md#F-1 (requirements-deferral-p2.md)"* ]] && [[ "$OUT" != *"cross-1.md#F-2 ("* ]] || bad="$bad substr(rc=$RC)"
run subok architecture;    [ "$RC" -eq 0 ] && nj || bad="$bad subok(rc=$RC)"
run ident architecture;    [ "$RC" -eq 1 ] && [[ "$OUT" == *"  1.md#F-1: repaired on no"* ]] && [[ "$OUT" == *"cross-1.md#F-1: repaired on no"* ]] || bad="$bad ident(rc=$RC)"
run partlink architecture; [ "$RC" -eq 1 ] && [[ "$OUT" == *"cross-1.md#F-1: repaired on no"* ]] && [[ "$OUT" != *"  1.md#F-1: repaired on no"* ]] || bad="$bad partlink(rc=$RC)"
run seriallink architecture; [ "$RC" -eq 1 ] && [[ "$OUT" == *"cross-1.md#F-1: repaired on no"* ]] && [[ "$OUT" != *"  1.md#F-1: repaired on no"* ]] || bad="$bad seriallink(rc=$RC)"
run dupid coe;             [ "$RC" -eq 1 ] && [[ "$OUT" == *"1 of findings_major 2 carry no MAJOR"* ]] || bad="$bad dupid(rc=$RC)"
run idpunct coe;           [ "$RC" -eq 0 ] && nj || bad="$bad idpunct(rc=$RC)"
rcpt_filter
[ -z "${RCPT_REPORT:-}" ] || echo "receipt worlds judged:$(echo $RAN)" >&2
if [ -n "$bad" ]; then echo "receipt BL-814: NOT FIXED --$bad"; exit 1; fi
echo "receipt BL-814: fixed (open MAJORs at MET refused, deferral to the successor and a linked pass-M repair close them, a stale-pass, unlinked, wrong-step or id-only close refused, underived and unkeyed MAJORs judged, legacy PENDING, the successor's digest names every deferred key)"
exit 0
