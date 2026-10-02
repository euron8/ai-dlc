#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# setup-config-drift/run.sh — prove unregistered-drift.sh's setup-config-region exemption.
#
# THE DEFECT THIS EXISTS TO CATCH. ai-dlc-setup/SKILL.md is overwrite-on-pull core, but it was
# outside the drift detector's scan — so an in-place edit there fell to the both-changed
# classifier, whose default is keep-ours, silently perpetuating the drift the layer system
# forbids. The fix scans it AND exempts the declared heading-block config regions. This proves
# both halves: an edit inside a declared region is exempt; an edit outside it is HARD.
#
# Retargeted in v0.174.0 from `setup-model-strategy` (retired — model strings moved to the
# consumer-owned aiDlcModels block) to `dev-ownership-paths`. Same machinery, live site.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

CF="$CONSUMER/.claude/$REL"
BASECONTENT="$WORK/base.md"
git -C "$DIST" show "$BASE:core/$REL" > "$BASECONTENT"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

status_of() { # status_of [rel] -> the STATUS token unregistered-drift.sh emits for that core file
  bash "$SCRIPT" "$DIST" "$BASE" "$CONSUMER" 2>/dev/null \
    | awk -F'\t' -v f="${1:-$REL}" '$2==f {print $1; exit}'
}

echo "setup-config-drift:"

# --- Assertion 0: SANITY — clean consumer is CORE-OK -------------------------
cp "$BASECONTENT" "$CF"
s="$(status_of)"
[ "$s" = "CORE-OK" ] && ok "byte-identical consumer → CORE-OK" \
  || { bad "FIXTURE BROKEN — clean consumer is '$s', not CORE-OK; negatives below are meaningless"; echo; echo "setup-config-drift: FIXTURE BROKEN" >&2; exit 2; }

# --- Assertion 1: declared-region config edit is EXEMPT (not drift) ----------
# Rewrite an ownership path inside `## Ownership` — a real per-project config choice.
sed 's|- `src/` (application source code)|- `lib/` (this project keeps its source here)|' "$BASECONTENT" > "$CF"
if ! cmp -s "$BASECONTENT" "$CF"; then
  s="$(status_of)"
  [ "$s" = "CORE-TEMPLATE-SUBSTITUTED" ] && ok "an edit inside ## Ownership → CORE-TEMPLATE-SUBSTITUTED (declared config, exempt)" \
    || bad "an ownership-paths edit classified '$s', expected CORE-TEMPLATE-SUBSTITUTED — the config region is not being exempted"
else
  bad "FIXTURE STALE: the ownership-paths line did not change (base text drifted)"
fi

# --- Assertion 2: an edit OUTSIDE the declared region is HARD drift ----------
sed 's/Fixed rulebook prose./Fixed rulebook prose EDITED IN PLACE by the consumer./' "$BASECONTENT" > "$CF"
if ! cmp -s "$BASECONTENT" "$CF"; then
  s="$(status_of)"
  [ "$s" = "HARD-UNREGISTERED-CORE-DRIFT" ] && ok "an in-place edit to ## Responsibilities (rulebook prose) → HARD-UNREGISTERED-CORE-DRIFT (blocks apply)" \
    || bad "a non-config in-place edit classified '$s', expected HARD-UNREGISTERED-CORE-DRIFT — the drift gate is not firing outside the config region"
else
  bad "FIXTURE STALE: the ## Responsibilities line did not change"
fi

# --- Assertion 3: RESTORE → CORE-OK -----------------------------------------
cp "$BASECONTENT" "$CF"
s="$(status_of)"
[ "$s" = "CORE-OK" ] && ok "restored consumer → CORE-OK" || bad "restored consumer is '$s', not CORE-OK"

# --- Assertion 3b: a SCHEMA edit is scanned and flagged HARD -----------------
# schemas/ is core the consumer must not edit — no {token}, no config region, so any edit is
# silent drift. Proves unregistered-drift.sh actually scans core/schemas/ (the v0.63.2 gap).
SCF="$CONSUMER/.claude/$SCHEMA_REL"
printf '{\n  "schema_id": "FIXTURE v1",\n  "rule": "consumer-loosened-it"\n}\n' > "$SCF"
s="$(status_of "$SCHEMA_REL")"
[ "$s" = "HARD-UNREGISTERED-CORE-DRIFT" ] && ok "an in-place edit to a core schema → HARD-UNREGISTERED-CORE-DRIFT (schemas/ is scanned)" \
  || bad "a schema edit classified '$s', expected HARD — core/schemas/ is not being scanned"
git -C "$DIST" show "$BASE:core/$SCHEMA_REL" > "$SCF"   # restore

# --- Assertion 4: the site is actually DECLARED -----------------------------
SITES="$(dirname "$SCRIPT")/setup-sites.md"
if grep -q "id: dev-ownership-paths" "$SITES" && grep -q "heading: '## Ownership'" "$SITES"; then
  ok "setup-sites.md declares the dev-ownership-paths heading-block site"
else
  bad "setup-sites.md does not declare the ownership config site — the exemption above rests on nothing"
fi

# --- Assertion 5: content PAST the terminator is NOT exempt ------------------
# A heading-block span is bounded at `next_heading`, exclusive. If the bound is wrong — or is
# silently widened — everything after it inherits the exemption, and rulebook prose the
# consumer edited in place stops being reported. That is not hypothetical: the retired
# `setup-model-strategy` site was originally bounded on the next STEP heading and swallowed
# ~140 lines of instructions, so upstream could add a block no layered consumer ever received.
#
# The edited line deliberately carries NO {token}. The token arm of the exemption is
# independent of the span and exempts any hunk whose base side holds one, so a `{token}` row
# proves nothing about the boundary — it would read as exempt under either declaration. Only a
# token-free line past the terminator isolates the span.
sed 's|More fixed rulebook prose, after the terminator.|EDITED IN PLACE by the consumer.|' "$BASECONTENT" > "$CF"
if ! cmp -s "$BASECONTENT" "$CF"; then
  s="$(status_of)"
  [ "$s" = "HARD-UNREGISTERED-CORE-DRIFT" ] && ok "an edit past the terminator → HARD-UNREGISTERED-CORE-DRIFT (outside the bounded span)" \
    || bad "an edit past the terminator classified '$s', expected HARD-UNREGISTERED-CORE-DRIFT — the span is reaching beyond next_heading and exempting rulebook prose"
else
  bad "FIXTURE STALE: the post-terminator row did not change (seed text drifted)"
fi
git -C "$DIST" show "$BASE:core/$REL" > "$CF"   # restore

# --- Assertion 6: an unresolvable terminator withholds the exemption ---------
# The old code widened the span to EOF when `next_heading` was not found at base — one stale
# anchor became a blanket exemption over the rest of the file, silently. Fail CLOSED instead:
# no exemption, so the drift is reported. Wrong in the recoverable direction.
# The engine is COPIED and the copy is perturbed — the real reconcile/ tree is never written
# to, so an interrupted run cannot leave the distribution dirty.
ENGINE="$WORK/engine"
mkdir -p "$ENGINE" && cp "$(dirname "$SCRIPT")/"* "$ENGINE/" 2>/dev/null
sed "s|next_heading: '## Responsibilities'|next_heading: '## NO SUCH TERMINATOR EXISTS'|" \
  "$SITES" > "$ENGINE/setup-sites.md"
if ! cmp -s "$SITES" "$ENGINE/setup-sites.md"; then
  sed 's|- `src/` (application source code)|- `lib/` (this project keeps its source here)|' "$BASECONTENT" > "$CF"
  s="$(bash "$ENGINE/unregistered-drift.sh" "$DIST" "$BASE" "$CONSUMER" 2>/dev/null \
        | awk -F'\t' -v f="$REL" '$2==f {print $1; exit}')"
  [ "$s" = "HARD-UNREGISTERED-CORE-DRIFT" ] && ok "an unresolvable terminator withholds the exemption (fail-closed), never widens the span to EOF" \
    || bad "with an unresolvable terminator the config edit classified '$s' — the span is being widened to EOF again, which exempts the whole rest of the file on one stale anchor"
else
  bad "FIXTURE STALE: could not build the broken-terminator mutant — setup-sites.md's next_heading is not the expected line"
fi
git -C "$DIST" show "$BASE:core/$REL" > "$CF"   # restore

# --- BEHIND vs FORKED: the differential ---------------------------------------
#
# Every other status here measures the consumer against BASE, and BASE is the consumer's own
# stamp. A file excluded from apply — by a per-entry acceptance, say — freezes while the stamp
# advances, so its base-relative diff grows with staleness and reads as a fork that grew on its
# own. `absorbed_pct` cannot separate the two: a real fork upstream ignored scores 0 hits, and
# so does a stale file whose "added" lines are old upstream text upstream has since rewritten.
# On the reference consumer that produced three consecutive pulls of the wrong disposition.
#
# The pair below differ in ONE variable — which upstream blob the consumer's copy is anchored
# at. Assertion 2 above is the other half of this differential and must stay green: a consumer
# at base plus an edit is still DRIFT, because it best-matches base's own blob.
ASSERT_STALE="$(bash "$SCRIPT" "$DIST" "$BASE" "$STALE" 2>/dev/null | awk -F'\t' -v f="$REL" '$2==f {print $1; exit}')"
[ "$ASSERT_STALE" = "HARD-CORE-BEHIND" ] \
  && ok "a copy frozen at an ancestor of base, plus one line of its own → HARD-CORE-BEHIND (remedy is take-theirs, not refile-as-override)" \
  || bad "a stale copy classified '$ASSERT_STALE', expected HARD-CORE-BEHIND — upstream's own change since the old release is being read as consumer drift"

# The DETAIL must carry both numbers. The disposition turns on their RATIO, and an operator
# who sees only the base-relative one adjudicates a fork that is not there.
D="$(bash "$SCRIPT" "$DIST" "$BASE" "$STALE" 2>/dev/null | awk -F'\t' -v f="$REL" '$2==f {print $3; exit}')"
if grep -q 'differs from core@.* by [0-9]* lines, but from .* by only [0-9]*' <<<"$D"; then
  ok "the row states both distances — against base AND against the ancestor it is really anchored at"
else
  bad "the HARD-CORE-BEHIND detail does not carry both distances; the operator cannot see that the base-relative number is mostly upstream's own change"
fi

# --- A FAILED `diff` MUST NOT READ AS A VERDICT -------------------------------
#
# The template-substitution classifier and the ancestor search both parse `diff` output, and an
# empty stream from a diff that FAILED (fork refused, EAGAIN, unreadable file) used to be read as
# a clean answer: no hunk -> `no` -> CORE-TEMPLATE-SUBSTITUTED, and zero differing lines -> a
# perfect ancestor -> HARD-CORE-BEHIND. Both acquit or re-route a real in-place edit silently.
# Forced here with a `diff` shim on PATH, never with load: `shim-all` fails every call, `shim-old`
# fails ONLY the diff of the OLD-release blob (stdin lacking base's `## Escalation Protocol`),
# so base's own diff succeeds and exactly one ancestor candidate goes unread. Each shim drops a
# marker when it refuses, so an arm cannot pass on a shim that never fired.
#
# Each arm has a committed mutant, built in a copy of the WHOLE reconcile dir (the script sources
# lib.sh and evals preclassify.sh beside itself), and the UNMUTATED copy is driven through the same
# shim as the positive control that the copy runs at all.
REAL_DIFF="$(command -v diff)"
mkdir -p "$WORK/shim-all" "$WORK/shim-old"
cat > "$WORK/shim-all/diff" <<SHIM
#!/usr/bin/env bash
: > "$WORK/shim-all.fired"
exit 2
SHIM
cat > "$WORK/shim-old/diff" <<SHIM
#!/usr/bin/env bash
if [ "\${1:-}" = "-" ]; then
  in="\$(cat)"
  case "\$in" in *"## Escalation Protocol"*) printf '%s\n' "\$in" | "$REAL_DIFF" "\$@"; exit \$? ;; esac
  : > "$WORK/shim-old.fired"
  exit 2
fi
exec "$REAL_DIFF" "\$@"
SHIM
chmod +x "$WORK/shim-all/diff" "$WORK/shim-old/diff"

drive() { # drive <script> <shim-dir> <rel> -> "STATUS<TAB>DETAIL" for rel, diff shimmed
  PATH="$2:$PATH" bash "$1" "$DIST" "$BASE" "$CONSUMER" 2>/dev/null \
    | awk -F'\t' -v f="$3" '$2==f {print $1 "\t" $3; exit}'
}

FC="$WORK/failclosed"
mkdir -p "$FC/ctl" "$FC/mA" "$FC/mB"
for d in ctl mA mB; do cp "$(dirname "$SCRIPT")/"* "$FC/$d/" 2>/dev/null; done
# mA reverts EVERY layer of the classifier fix: the exit/empty check, the awk END refusal, and
# the caller branch that turns the refusal into a HARD row.
sed -e '/if \[ "\$drc" -ne 1 \] || \[ -z "\$d" \]; then printf .unknown.; return 0; fi/d' \
    -e 's/if (!hunk) { print "unknown"; exit } //' \
    -e 's/if \[ "\$unreg" != "yes" \] && \[ "\$unreg" != "no" \]; then/if false; then/' \
    "$SCRIPT" > "$FC/mA/unregistered-drift.sh"
# mB reverts the ancestor-search fix: a failed candidate diff is scored instead of skipped.
sed 's/\[ "\$_as" -le 1 \] || continue/: || continue/' "$SCRIPT" > "$FC/mB/unregistered-drift.sh"
# Counted from a FILE, never from a pipe: `diff` exits 1 on the difference it is being asked for,
# and under pipefail a `diff | grep -c` pipeline then "fails" and `|| n=0` overwrites the count.
# mA is one deletion plus two in-place edits (1 + 2x2 marker lines); mB is one edit (2).
diff "$SCRIPT" "$FC/mA/unregistered-drift.sh" > "$FC/mA.d"
diff "$SCRIPT" "$FC/mB/unregistered-drift.sh" > "$FC/mB.d"
n_a="$(grep -c '^[<>]' "$FC/mA.d")" || n_a=0
n_b="$(grep -c '^[<>]' "$FC/mB.d")" || n_b=0

# World A: a schema edited in place, every diff failing.
printf '{\n  "schema_id": "FIXTURE v1",\n  "rule": "consumer-loosened-it"\n}\n' > "$SCF"
rm -f "$WORK/shim-all.fired"
r="$(drive "$FC/ctl/unregistered-drift.sh" "$WORK/shim-all" "$SCHEMA_REL")"
if [ ! -f "$WORK/shim-all.fired" ]; then
  bad "FIXTURE BROKEN — the failing diff shim never ran, so the fail-closed arm below asserts nothing"
elif [ "${r%%	*}" = "HARD-UNREGISTERED-CORE-DRIFT" ] && grep -q 'CLASSIFIER DID NOT RUN' <<<"$r"; then
  ok "a diff that FAILED on a drifted schema → HARD-UNREGISTERED-CORE-DRIFT carrying 'CLASSIFIER DID NOT RUN', not CORE-TEMPLATE-SUBSTITUTED"
else
  bad "with every diff failing the drifted schema classified '${r%%	*}' — a diff that did not run is being read as a verdict (expected HARD-UNREGISTERED-CORE-DRIFT / CLASSIFIER DID NOT RUN)"
fi
if [ "$n_a" -ne 5 ]; then
  bad "MUTANT A DID NOT APPLY — expected 5 diff marker lines, got $n_a; the classifier fix was re-spelled and the mutant must be re-anchored"
else
  r="$(drive "$FC/mA/unregistered-drift.sh" "$WORK/shim-all" "$SCHEMA_REL")"
  [ "${r%%	*}" = "CORE-TEMPLATE-SUBSTITUTED" ] \
    && ok "mutant A (classifier fix reverted) reproduces the defect: CORE-TEMPLATE-SUBSTITUTED" \
    || bad "mutant A classified '${r%%	*}', expected CORE-TEMPLATE-SUBSTITUTED — the arm above cannot tell the fix from its revert"
fi
git -C "$DIST" show "$BASE:core/$SCHEMA_REL" > "$SCF"   # restore

# World B: rulebook prose edited in place (plain drift anchored at base), only the OLD blob's
# diff failing.
sed 's/Fixed rulebook prose./Fixed rulebook prose EDITED IN PLACE by the consumer./' "$BASECONTENT" > "$CF"
rm -f "$WORK/shim-old.fired"
r="$(drive "$FC/ctl/unregistered-drift.sh" "$WORK/shim-old" "$REL")"
if [ ! -f "$WORK/shim-old.fired" ]; then
  bad "FIXTURE BROKEN — the old-blob diff shim never refused, so the ancestor arm below asserts nothing"
elif [ "${r%%	*}" = "HARD-UNREGISTERED-CORE-DRIFT" ]; then
  ok "an ancestor candidate whose diff FAILED is skipped, not scored as a perfect match → HARD-UNREGISTERED-CORE-DRIFT, not HARD-CORE-BEHIND"
else
  bad "with the old blob's diff failing, plain drift classified '${r%%	*}' — a failed diff scored as zero differing lines (expected HARD-UNREGISTERED-CORE-DRIFT)"
fi
if [ "$n_b" -ne 2 ]; then
  bad "MUTANT B DID NOT APPLY — expected 2 diff marker lines, got $n_b; the ancestor fix was re-spelled and the mutant must be re-anchored"
else
  r="$(drive "$FC/mB/unregistered-drift.sh" "$WORK/shim-old" "$REL")"
  [ "${r%%	*}" = "HARD-CORE-BEHIND" ] \
    && ok "mutant B (ancestor fix reverted) reproduces the defect: HARD-CORE-BEHIND" \
    || bad "mutant B classified '${r%%	*}', expected HARD-CORE-BEHIND — the arm above cannot tell the fix from its revert"
fi
# Each mutant is inert on the OTHER arm's world, so neither arm is carried by the other's fix.
r="$(drive "$FC/mA/unregistered-drift.sh" "$WORK/shim-old" "$REL")"
[ "${r%%	*}" = "HARD-UNREGISTERED-CORE-DRIFT" ] && ok "mutant A leaves the ancestor arm green (the arms are not entangled)" \
  || bad "mutant A moved the ancestor arm to '${r%%	*}' — the two arms are entangled"
printf '{\n  "schema_id": "FIXTURE v1",\n  "rule": "consumer-loosened-it"\n}\n' > "$SCF"
r="$(drive "$FC/mB/unregistered-drift.sh" "$WORK/shim-all" "$SCHEMA_REL")"
[ "${r%%	*}" = "HARD-UNREGISTERED-CORE-DRIFT" ] && ok "mutant B leaves the classifier arm green (the arms are not entangled)" \
  || bad "mutant B moved the classifier arm to '${r%%	*}' — the two arms are entangled"
git -C "$DIST" show "$BASE:core/$SCHEMA_REL" > "$SCF"   # restore
git -C "$DIST" show "$BASE:core/$REL" > "$CF"           # restore

# --- A MEMO THAT CANNOT SERVE THE BASE BLOB REFUSES; IT NEVER CLASSIFIES -------------------------
# `git_show … | cmp -s - "$cons"` read no status, so a cached base blob lib.sh could not serve (its
# 125) fed `cmp` nothing and a byte-identical file fell through to HARD-UNREGISTERED-CORE-DRIFT at
# rc 0 -- a remedy telling the operator to refile or revert an edit nobody made. The blob is now
# staged with its status read; a 125 is `unregistered-drift: REFUSED`, exit 2, the memo named.
cp "$BASECONTENT" "$CF"
UM="$(mktemp -d "$WORK/ud-memo.XXXXXX")"
AI_DLC_RECONCILE_MEMO="$UM" bash "$SCRIPT" "$DIST" "$BASE" "$CONSUMER" > "$WORK/um.ctl" 2>/dev/null; um_rc=$?
um_n=0
for um_f in "$UM"/"s "*" ${BASE}:core%2Fteam-roles%2Fdev.md.s"; do [ -f "$um_f" ] || continue; um_n=$((um_n + 1)); : > "$um_f"; : > "${um_f%.s}.c"; done
AI_DLC_RECONCILE_MEMO="$UM" bash "$SCRIPT" "$DIST" "$BASE" "$CONSUMER" > "$WORK/um.out" 2> "$WORK/um.err"; um_frc=$?
if [ "$um_rc" != 0 ] || ! grep -q "^CORE-OK	$REL	" "$WORK/um.ctl" || [ "$um_n" -ne 1 ]; then
  bad "FIXTURE BROKEN — the memo cell's warm run was rc=$um_rc with no CORE-OK row for $REL, or found $um_n memo key(s) for it (want 1)"
elif [ "$um_frc" = 2 ] && grep -qF 'could not be served by the reconcile memo' "$WORK/um.err" \
     && ! grep -q "	$REL	" "$WORK/um.out"; then
  ok "a base blob the memo cannot serve REFUSES — exit 2, the memo named, no row decided for the file"
else
  bad "a base blob the memo cannot serve gave rc=$um_frc and '$(awk -F'\t' -v f="$REL" '$2==f {print $1}' "$WORK/um.out")' for a byte-identical file — a lost cached object decided its row"
fi

# --- A MEMO THAT CANNOT SERVE AN ANCESTOR BLOB REFUSES; IT NEVER RE-ROUTES THE STALE COPY ---------
# `closest_ancestor_blob` piped each candidate into `diff -`. A memo serve that failed EMPTY (125)
# lost to diff's own 1 under pipefail, the candidate scored as wholly different, and the stale copy's
# HARD-CORE-BEHIND ("take theirs") fell to HARD-UNREGISTERED-CORE-DRIFT ("refile or revert") at rc 0.
# The candidate is now staged with its read status read. Warm on the STALE consumer, then empty the
# OLD-release blob's `.s` and `.c` -- the empty-serve mode; a full serve already propagated 125.
AM="$(mktemp -d "$WORK/ud-anc-memo.XXXXXX")"
AI_DLC_RECONCILE_MEMO="$AM" bash "$SCRIPT" "$DIST" "$BASE" "$STALE" > "$WORK/am.ctl" 2>/dev/null; am_rc=$?
am_n=0
for am_f in "$AM"/"s "*" ${OLD}:core%2Fteam-roles%2Fdev.md.s"; do [ -f "$am_f" ] || continue; am_n=$((am_n + 1)); : > "$am_f"; : > "${am_f%.s}.c"; done
AI_DLC_RECONCILE_MEMO="$AM" bash "$SCRIPT" "$DIST" "$BASE" "$STALE" > "$WORK/am.out" 2> "$WORK/am.err"; am_frc=$?
if [ "$am_rc" != 0 ] || ! grep -q "^HARD-CORE-BEHIND	$REL	" "$WORK/am.ctl" || [ "$am_n" -ne 1 ]; then
  bad "FIXTURE BROKEN — the ancestor memo cell's warm run was rc=$am_rc with no HARD-CORE-BEHIND row for $REL, or found $am_n memo key(s) for its ancestor blob (want 1)"
elif [ "$am_frc" = 2 ] && grep -qF 'could not be served by the reconcile memo' "$WORK/am.err" \
     && ! grep -q "	$REL	" "$WORK/am.out"; then
  ok "an ancestor blob the memo cannot serve REFUSES — exit 2, the memo named, the stale copy not re-routed to drift"
else
  bad "an ancestor blob the memo cannot serve gave rc=$am_frc and '$(awk -F'\t' -v f="$REL" '$2==f {print $1}' "$WORK/am.out")' for the stale copy — a lost cached object chose its remedy"
fi

# --- THE EXEMPTION READS A BASE THAT CANNOT BE STAGED: HEALTHY OR REFUSED, NEVER DRIFT ----------
# `exempt_ranges` searched the base blob through two `<<<"$base"`s and read its site list from a
# `done <<EOF`. Under a full disk (modelled: `trap '' XFSZ; ulimit -f N`, so the write fails with
# EFBIG and the script lives) a here-string that cannot be staged is EMPTY: no heading found, no
# exemption, and a declared config edit reported HARD at rc 0. The base blob here is calibrated past
# the limit and the scan listing below it. Accepted: CORE-TEMPLATE-SUBSTITUTED (healthy) or the
# detector's own `unregistered-drift: REFUSED` at a non-zero exit. /bin/bash: 3.2 stages every `<<<`.
# On the tip the refusal is `ud_stage_blob`'s, at the scan loop's one staging of the base blob that
# `exempt_ranges` now reads; the exemption itself no longer stages anything the limit can reach.
FD="$WORK/forced"; mkdir -p "$FD"
cp -R "$DIST" "$FD/dist"; mkdir -p "$FD/cons/.claude/team-roles"
i=0; { cat "$BASECONTENT"; while [ "$i" -lt 400 ]; do printf 'padding prose line %03d that makes this core role file larger than the limit\n' "$i"; i=$((i+1)); done; } > "$FD/dist/core/$REL"
git -C "$FD/dist" -c user.email=f@f -c user.name=fixture add -A
git -C "$FD/dist" -c user.email=f@f -c user.name=fixture commit -qm padded
FB="$(git -C "$FD/dist" rev-parse HEAD)"
sed 's|- `src/` (application source code)|- `lib/` (this project keeps its source here)|' "$FD/dist/core/$REL" > "$FD/cons/.claude/$REL"
f_blob="$(wc -c < "$FD/dist/core/$REL" | tr -d ' ')"
f_ls="$(git -C "$FD/dist" ls-tree -r --name-only "$FB" | wc -c | tr -d ' ')"
f_blk="$( ( trap '' XFSZ; ulimit -f 1; printf '%08192d' 0 > "$FD/blk" ) 2>/dev/null; wc -c < "$FD/blk" | tr -d ' ')"
f_lim=""; case "$f_blk" in ''|*[!0-9]*|0) ;; *) f_lim=$(( (f_blob / 2) / f_blk )) ;; esac
f_cal=""
if [ -n "$f_lim" ] && [ "$f_lim" -gt 0 ]; then
  f_hs="$(/bin/bash -c 'trap "" XFSZ; ulimit -f "$1" || exit 97; wc -c <<<"$2"' _ "$f_lim" "$(cat "$FD/dist/core/$REL")" 2>/dev/null)"
  /bin/bash -c 'trap "" XFSZ; ulimit -f "$1" || exit 97; printf "%0${2}d" 0 > "$3"' _ "$f_lim" "$f_ls" "$FD/cal" 2>/dev/null
  case "$f_hs" in *[1-9]*) ;; *) [ "$(wc -c < "$FD/cal" | tr -d ' ')" = "$f_ls" ] && f_cal=ok ;; esac
fi
f_st() { awk -F'\t' -v f="$REL" '$2==f {print $1; exit}' "$1"; }
if [ "$f_cal" != ok ]; then
  bad "FIXTURE BROKEN — calibration: under ulimit -f ${f_lim:-?} a ${f_blob}-byte here-string did not fail or a ${f_ls}-byte write did not land whole; the forced cell cannot discriminate"
else
  bash "$SCRIPT" "$FD/dist" "$FB" "$FD/cons" > "$FD/u.out" 2>/dev/null; f_urc=$?
  if [ "$f_urc" = 0 ] && [ "$(f_st "$FD/u.out")" = CORE-TEMPLATE-SUBSTITUTED ]; then
    ok "unforced control: the ownership edit on the ${f_blob}-byte role file reads CORE-TEMPLATE-SUBSTITUTED"
  else
    bad "FIXTURE BROKEN — unforced control rc=$f_urc status '$(f_st "$FD/u.out")'; the forced cell has no healthy answer"
  fi
  /bin/bash -c 'trap "" XFSZ; ulimit -f "$1" || exit 97; shift; exec /bin/bash "$@"' _ "$f_lim" "$SCRIPT" "$FD/dist" "$FB" "$FD/cons" > "$FD/f.out" 2> "$FD/f.err"; f_frc=$?
  if { [ "$f_frc" = 0 ] && [ "$(f_st "$FD/f.out")" = CORE-TEMPLATE-SUBSTITUTED ]; } \
     || { [ "$f_frc" -ne 0 ] && [ "$f_frc" -ne 97 ] && grep -q '^unregistered-drift: REFUSED' "$FD/f.err" && [ -z "$(f_st "$FD/f.out")" ]; }; then
    ok "forced: a base blob that cannot be staged under ulimit -f $f_lim gives the healthy row or the named refusal (rc=$f_frc)"
  else
    bad "forced: a base blob that cannot be staged under ulimit -f $f_lim gave rc=$f_frc status '$(f_st "$FD/f.out")' — an unstaged base read as empty"
  fi
fi

# --- THE DIFF HUNKS THAT CANNOT BE STAGED: HEALTHY OR REFUSED, NEVER DRIFT ------------------------
# `is_unregistered` fed its hunk classifier from `<<<"$d"`. A here-string that could not be staged
# fed the awk an EMPTY stream, which reads `unknown`, and `unknown` blocks as HARD at rc 0 -- a
# declared config edit reported as unregistered drift. The world: the base blob is SMALL, and the
# consumer's edit is a large insertion INSIDE `## Ownership`, so the diff is calibrated past the limit
# while the blob, the listing and the rows fit under it; the only write that can fail is the hunks'.
FH="$WORK/forced-hunks"; mkdir -p "$FH/cons/.claude/team-roles"
awk '{ print } /^- `src\/` \(application source code\)$/ { for (i = 0; i < 300; i++) printf "- `zz%03d/` (a directory this project keeps, one config line of many)\n", i }' \
  "$BASECONTENT" > "$FH/cons/.claude/$REL"
h_blob="$(wc -c < "$BASECONTENT" | tr -d ' ')"
h_diff="$(git -C "$DIST" show "$BASE:core/$REL" | diff - "$FH/cons/.claude/$REL" | wc -c | tr -d ' ')"
h_ls="$(git -C "$DIST" ls-tree -r --name-only "$BASE" | wc -c | tr -d ' ')"
h_lim=""; case "$f_blk" in ''|*[!0-9]*|0) ;; *) h_lim=$(( (h_diff / 2) / f_blk )) ;; esac
h_cal=""
if [ -n "$h_lim" ] && [ "$h_lim" -gt 0 ] && [ $(( h_lim * f_blk )) -gt "$h_blob" ] && [ $(( h_lim * f_blk )) -gt "$h_ls" ]; then
  h_hs="$(/bin/bash -c 'trap "" XFSZ; ulimit -f "$1" || exit 97; wc -c <<<"$2"' _ "$h_lim" "$(printf "%0${h_diff}d" 0)" 2>/dev/null)"
  case "$h_hs" in *[1-9]*) ;; *) h_cal=ok ;; esac
fi
if [ "$h_cal" != ok ]; then
  bad "FIXTURE BROKEN — calibration: under ulimit -f ${h_lim:-?} (block ${f_blk:-?} B) a ${h_diff}-byte here-string did not fail, or the ${h_blob}-byte blob or ${h_ls}-byte listing does not fit; the hunks cell cannot discriminate"
else
  bash "$SCRIPT" "$DIST" "$BASE" "$FH/cons" > "$FH/u.out" 2>/dev/null; h_urc=$?
  if [ "$h_urc" = 0 ] && [ "$(f_st "$FH/u.out")" = CORE-TEMPLATE-SUBSTITUTED ]; then
    ok "unforced control: a ${h_diff}-byte diff inside ## Ownership reads CORE-TEMPLATE-SUBSTITUTED"
  else
    bad "FIXTURE BROKEN — hunks unforced control rc=$h_urc status '$(f_st "$FH/u.out")'; the forced cell has no healthy answer"
  fi
  /bin/bash -c 'trap "" XFSZ; ulimit -f "$1" || exit 97; shift; exec /bin/bash "$@"' _ "$h_lim" "$SCRIPT" "$DIST" "$BASE" "$FH/cons" > "$FH/f.out" 2> "$FH/f.err"; h_frc=$?
  if { [ "$h_frc" = 0 ] && [ "$(f_st "$FH/f.out")" = CORE-TEMPLATE-SUBSTITUTED ]; } \
     || { [ "$h_frc" -ne 0 ] && [ "$h_frc" -ne 97 ] && grep -q '^unregistered-drift: REFUSED' "$FH/f.err" && [ -z "$(f_st "$FH/f.out")" ]; }; then
    ok "forced: diff hunks that cannot be staged under ulimit -f $h_lim give the healthy row or the named refusal (rc=$h_frc)"
  else
    bad "forced: diff hunks that cannot be staged under ulimit -f $h_lim gave rc=$h_frc status '$(f_st "$FH/f.out")' — an unstaged hunk stream read as drift"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "setup-config-drift: PASS"; exit 0; fi
echo "setup-config-drift: $fails assertion(s) FAILED" >&2
exit 1
