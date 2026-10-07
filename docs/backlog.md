# Carry-over backlog

Items this repo owes itself. An entry lives here when it is real, measured, and **not the
subject of any live plan** — the state that previously had no home, so it survived only by
being written into a plan about something else and vanished when that plan was discharged.

**This is the DISTRIBUTION's backlog, and it is not a push-candidate ledger.** A consumer's
`_bmad-output/ai-dlc-update/push-candidate-ledger.md` tracks what that consumer wants pushed
UPSTREAM to ai-dlc, and its receipts resolve against a pull's `theirs` ref with the verbs
`theirs_has` / `theirs_lacks`. This file tracks what ai-dlc owes ITSELF, its receipts resolve
against this working tree, and its verbs are `sh` / `has` / `lacks`. The two grammars are
mutually unreadable by each other's engine on purpose. Entry ids are `BL-`, never `PC-`.

**Read by** `scripts/backlog-reverify.sh`, which executes each entry's `verify:` receipt and
emits a status. **Rotated by** `scripts/backlog-rotate.sh`, which moves closed entries to
`docs/backlog.archive.md` — it moves, it never deletes. Neither ships; both are
distribution-only, as `core/fixtures/plan-shape/.dist-only` already is.

## Receipts

```
verify: sh <one-liner>              exit 0 = the fix is present -> CLOSE-CANDIDATE
                                    exit 9 = the receipt cannot measure its subject -> NEEDS-REVIEW
                                    any other non-zero = still reproduces -> STILL-LIVE
verify: has   <repo-rel-path> "<substr>"    close when the file CONTAINS the substring
verify: lacks <repo-rel-path> "<substr>"    close when the file LACKS it
verify: manual                      no mechanical predicate by design -> HAND-REVIEW
```

**Prefer `sh`.** The tree is right here and executable, which the consumer's ledger cannot
assume of the ref it greps. A receipt runs from the repo root with stdin closed, so it names
any input it reads as a file. A behavioural predicate asserts the defect itself and cannot be
anchored on prose the author invented to describe a wanted fix.

**THIS FILE'S `sh` POLARITY IS THE OPPOSITE OF THE CONSUMER LEDGER'S, AND THE TWO ARE WRITTEN
IN THE SAME SESSIONS.** Here, `scripts/backlog-reverify.sh:334-335` reads **exit 0 as "the fix
is present"** and non-zero as "still reproduces". In a consumer's push-candidate ledger,
`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:2929` reads it the other way — **exit 0
means the entry STILL REPRODUCES**, and non-zero proposes CLOSE-CANDIDATE. Carrying this file's
rule into a consumer receipt writes a predicate that proposes closing a LIVE defect, which is
the one direction that loses data permanently. Check which file your receipt lands in before
you fix its polarity, and read the emitter rather than either header.

**In a consumer receipt, guard the unresolvable subject too.** A RENAMED subject also exits
non-zero there, so a relocation reads as an absorption that never happened; `[ -n "$s" ] ||
exit 127` makes it NEEDS-REVIEW instead. This file's engine needs no such guard, because its
non-zero direction is the one that keeps the entry open.

**When you must use `has`/`lacks`, anchor on a token the fix CANNOT BE WRITTEN WITHOUT** — a
flag, a path, a function name — never a phrase describing the fix. The consumer's engine
detects that error by reading a third ref; this one has no third ref to read, so the rule is
enforced by the author and by review, not by the tool. `core/fixtures/ledger-reverify-unfalsifiable/README.md`
is the measurement: 13 entries on the reference consumer carried predicates that could never
have gone green, and would have reported "still open" forever.

**A closed entry is annotated in place and left for rotation**, in the form
`**LANDED (v<version>, verified <sha>).**` — the annotation FORM is what the rotator keys on,
never the word anywhere in prose, because an entry that merely discusses landing something is
not a closed entry.

## BL-456 — the self-update gate probes gating scripts bare, so a renderer change the consumer's hook rejects reads SELF-UPDATE-OK

**DEFECT.** Found by batch 200's adversary. `core/skills/ai-dlc-update/reconcile/self-update-gate.sh:1345-1346` runs the
consumer's current copy and the incoming copy of each hook-named gating script with no arguments, from the consumer root,
and `:1383` reads equal exit codes as `SELF-UPDATE-OK`. A script that needs arguments exits the same usage or
not-applicable code on both sides. `render-agent-definitions.sh` with no arguments resolves its root by walking up from its
own temp copy, finds none, and exits 2 under both versions. The consumer hook runs it as `--check --root .`
(`core/git-hooks/pre-push:234`). So when an incoming renderer changes only the text it renders, the hook's check goes
from 0 to 1 on every consumer with pinned roles. The gate cannot see that, step 2's autonomous push is refused, and the
cycle is discarded. The printed remedy re-runs the consumer's OLD renderer, which writes the old text again, so the next
cycle hits the same refusal.

**Measured** on a scratch world that holds a distribution whose base-to-theirs diff changes only the renderer, and a
consumer with the shipped hook, one pinned role, and definitions rendered by the current renderer. The gate was driven as
step 2 drives it, as `self-update-gate.sh <dist> <base> <theirs> <consumer>`:

```
body-only change ("FIRST action before" -> "FIRST action, before"):
  hook arm --check --root . : current renderer rc=0, incoming rc=1
  gate's bare probe         : rc_cur=2 rc_new=2
  gate                      : SELF-UPDATE-OK  render-agent-definitions.sh  both versions exit 2 ...
control, incoming renderer exits 1 at line 2 (a change the bare probe CAN see):
  gate's bare probe         : rc_cur=2 rc_new=1
  gate                      : SELF-UPDATE-UNDECIDED ... / SELF-UPDATE-DEFER - ...
```

**Claim 3, the remedy loop, is a consequence of claim 1's OK and not a defect of its own. Measured.** On a scratch
world with the real renderer, the shipped hook, one pinned role and a bare remote, each gate was followed through two
cycles in the order SKILL.md step 2 takes them:

```
gate at 8854b5eb (bare probe):
  cycle 1: render row SELF-UPDATE-OK -> step-2 push, hook --check rc=1, remedy printed
           `bash scripts/ai-dlc/render-agent-definitions.sh`; cycle discarded, installed renderer OLD;
           remedy rc=0, .claude/agents unchanged
  cycle 2: render row SELF-UPDATE-OK -> push refused again, rc=1, same remedy, same OLD renderer
gate at the fix:
  cycle 1: render row SELF-UPDATE-DEFER (2 DEFER rows), nothing pushed. The gated apply writes the slice:
           hook --check rc=1 BEFORE any remedy, installed renderer INCOMING; apply.sh's agent-definitions
           WORKLIST row names the same command; running it, the hook --check goes to rc=0
```

The remedy text never named the wrong command. It names the INSTALLED renderer, and that is the old one only on the
path where step 2 pushed and the cycle was discarded. That path needs an OK verdict on a body change, which is claim 1.
Once the gate defers, the slice lands in the gated apply before its push, and the same command re-renders with the
incoming renderer. `core/fixtures/self-update-gate/run.sh` arm `c3-remedy-after-defer` pins this: it follows the cycle
the verdict selects, runs the remedy, and asserts the incoming `--check` exits 0. Its mutant `c3-mut-bare` restores
the bare probe and reads `OK gate-wrote=no next-check=1`, which is the loop. The receipt's body world now exits 9
unless re-rendering with the old renderer leaves the incoming check at 1 and the incoming renderer clears it to 0, so
the world it scores is one in which the loop can occur. The arm drives the REAL
`apply.sh --carried-machinery-slice` and asserts `DEFER pure-apply=yes worklist=yes installed=theirs remedy=0 check=1->0`;
its mutant `c3-mut-nowrite` keeps the pure-apply row and skips the write, and reads `worklist=no installed=current`.

**The same loop IS live through the HOOK, and it is fixed here.** The gate scanned only the consumer's CURRENT hook, and
its gating set was changed scripts that hook invokes. But the hook is machinery: step 2 writes theirs'
`core/git-hooks/pre-push` and git runs THAT one on the push. Measured at 68be2a28 (two cycles each, real renderer whose
body changes, consumer with `core.hooksPath .githooks` and a bare remote):

```
theirs' hook ADDS the --check step     cycle 1 gate OK, push rc=1 DRIFTED; cycle 2 gate OK, push rc=1
theirs' hook reads `--check || true`   cycle 1 gate OK, push rc=1 DRIFTED; cycle 2 gate OK, push rc=1
the pull ADDS the renderer (no copy)   cycle 1 gate OK, push rc=1 no .claude/agents/dev.md; cycle 2 identical
same three worlds, this gate           cycle 1 render row SELF-UPDATE-DEFER, nothing pushed
```

The gate now judges against the hook the push will run: theirs' whenever the range changes `core/git-hooks/pre-push` and
arm C did not carry it. A script whose scan rows differ between the two hooks, kind and argv (a new mention included, which can only
add a refusal-direction row), joins the gating set even if the pull does not change it. A pull that changes ONLY the
hook, with no core/scripts/ path, is not exercised by any world.

**A script that joins the gating set only through the hook is judged by the copy the push runs, not theirs'.** Step 2
writes the range diff and nothing else, so a script the range does not change is still the consumer's copy after the
write, or absent. The round-2 gate judged it by theirs' copy. Measured with a driver that applies step 2's write and
runs theirs' hook on the result. Theirs adds `bash scripts/ai-dlc/validate-y.sh --strict || fail=1`, and validate-y.sh
is unchanged in the range:

| world | post-write hook rc | gate at the round-2 tip | gate now |
|---|---|---|---|
| local-fail (consumer's y exits 1, theirs' 0) | 1 | OK | DEFER |
| local-pass (consumer's y exits 0, theirs' 1) | 0 | DEFER | OK |
| guarded-deleted (no y, step under `if [ -f … ]`) | 0 | DEFER | OK |
| unguarded-deleted (no y, unguarded step) | 1 | DEFER, blaming theirs' copy | DEFER, row says ABSENT |

The incoming side is now theirs' copy only for a script the range changes. Otherwise it is the consumer's copy, or,
where the consumer has none, the hook's own existence test: a guarded step is skipped at rc 0, and an unguarded step
fails and is reported as ABSENT. The `hu-` arms pin the four worlds. `hu-mut-theirs` reverts the one line that decides
which copy runs, and `hu-mut-guard` ignores the existence test. The receipt's `unch` world runs the shipped hook as
theirs' over a base hook that lacks the provenance step; the consumer's own validate-provenance-block.sh exits 1 and
the range does not change it, so it must be refused.

**The guard is tied to the run.** The round-3 gate read any `-f`/`-x`/`-e` test of the path anywhere in the hook as the
guard of its run. A hook with `[ -f y ] || echo missing` and an unguarded `bash y` would then read OK for a consumer
lacking y, and that push fails. `gate_argv_scan` now emits a fourth column on every R row: `guarded` only when the run
sits inside an `if [ -f|-x|-e <same path> ]` block (a frame pushed by the opener, made non-guarding by `else`/`elif`,
popped by `fi`), or follows `[ -f <path> ] && { …` or a plain `[ -f <path> ] && bash <path>` with no `||` after the run.
`[ -f p ] && bash p || fail=1` is unguarded, because the `||` also catches the test failing. Anything the scan cannot
tie reads `unguarded`, which turns an absent script into a refusal: the fail-closed direction. A script counts as
guarded only when every status-read run of it is. On the shipped hook 9 of 11 runs read `guarded`; the 2 that read
`unguarded` (`validate-audit-anchors.sh` through `trunk_push`, `validate-fixture-drivability.sh` through
`drivability`) are runs inside function bodies whose guard is at the call site. That is the doubtful case, and it is
decided as not guarded, which reads DEFER only when the consumer lacks the script AND the pull does not write it.
Worlds `hu-orecho`, `hu-andand`, `hu-andor`, `hu-block` and `hu-else` take their expected verdicts from theirs' hook run
on the post-write tree. One mutant per guard leg is keyed on its own line, and `hu-mut-anytest` restores the round-3
rule. The receipt's `orguard` world appends the two lines to a base hook over a consumer that lacks the provenance
validator, and must be refused. The current side reads 0 where today's hook does not ask the question or the consumer has no copy,
because today's push cannot be refused there. A script arm C carried is not written, so it reads OK "carried". The
`hk-` arms pin the four worlds, plus a deleted-by-consumer near-miss, and the mutants `hk-mut-curhook`, `hk-mut-adds`
and `hk-mut-carried` each revert one leg. The receipt adds `hookadd` (the current hook has no renderer step, theirs'
is the shipped hook), `hookbenign` (the same pair with a comment-only renderer change, which must read OK) and
`absent` (the pull ADDS the renderer).

**Candidate fixes.** (a) Run each hook-named script with the hook's own argv, derived from the hook line that invokes it,
so the differential asks the hook's question. That edits `self-update-gate.sh`, which is a bootstrapping file. A consumer
runs the gate it already has, so (a) reaches a consumer only after one pull and must ship alone, machinery-only.
(b) Make the consumer hook re-render when the only difference is the rendered body, so a renderer body change cannot
refuse the push.

**Receipt.** It builds four mktemp worlds from the real renderer, the real provenance validator, the shipped hook and
the shipped schema, and drives the real gate in each, as step 2 drives it. Before reading the gate, it measures each
world's own hook-argv exit pair, current then incoming, and exits 9 unless the pair is what the world claims:
- `body`: the incoming renderer changes only rendered body text, and the hook's `--check --root .` goes 0 to 1.
- `benign`: the incoming renderer changes only a comment, and the pair is 0 and 0.
- `drift`: the same comment change on a consumer whose definitions were already hand-edited, and the pair is 1 and 1.
- `strays`: a SECOND argv-dependent script. The incoming `validate-provenance-block.sh` fails `--strays` on any
  envelope-carrying file, and the hook's `--strays` goes 0 to 1.

It exits 0 only when all of these hold:
- the gate refuses `body` on the renderer, and the consumer's `.claude/agents` is byte-identical across that run;
- it answers OK on the renderer with no refusal at all in `benign` and in `drift`;
- it refuses `strays` on the provenance validator.

Scored under `bash -c 'set -uo pipefail; …'`, each build in its own scratch copy of `core/`:

| build | exit |
|---|---|
| the fix | 0 |
| today's tree (bare probe) | 1 |
| a gate that hand-lists the renderer's `--check --root .` | 1 (`strays` reads OK) |
| a gate that passes `--root "$CONSUMER"` with no `--check` | 1 (`body` reads OK, and `.claude/agents` is rewritten) |
| a gate that turns equal non-zero codes into UNDECIDED | 1 (it refuses `drift`) |
| a gate that scans only the consumer's current hook | 1 (`hookadd` reads no row) |
| a gate that reads an absent current copy as "ADDS it", OK | 1 (`absent` reads OK) |
| a gate that judges a script the range does not change by theirs' copy | 1 (`unch` reads OK) |
| a gate that reads any existence test of the path anywhere in the hook as the run's guard | 1 (`orguard` reads OK) |
| the base gate with only the hook argv added (claim 1 alone, no staging) | 1 (`strays` reads OK) |

The receipt exits 9 if a precondition moves. That includes any of its three anchors changing: the renderer's body text
`FIRST action before any other work`, its comment `# --check NEVER WRITES, so it is safe`, and the provenance
validator's single `if strays:` line.

verify: sh G=core/skills/ai-dlc-update/reconcile/self-update-gate.sh; R=core/scripts/render-agent-definitions.sh; P=core/scripts/validate-provenance-block.sh; H=core/git-hooks/pre-push; K=core/schemas/provenance-block.json; [ -f "$G" ] && [ -f "$R" ] && [ -f "$P" ] && [ -f "$H" ] && [ -f "$K" ] || exit 9; command -v jq >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 || exit 9; grep -q 'FIRST action before any other work' "$R" && grep -q '^# --check NEVER WRITES, so it is safe' "$R" && [ "$(grep -c '^if strays:$' "$P")" = 1 ] || exit 9; W="$(mktemp -d)" || exit 9; sw() { D="$W/$1"; S="$D/c/scripts/ai-dlc/$2"; N="$D/d/core/scripts/$2"; mkdir -p "$D/d/core/scripts" "$D/c/scripts/ai-dlc" "$D/c/.githooks" "$D/c/.claude/schemas" || exit 9; git -C "$D/d" init -q || exit 9; cp "$R" "$P" "$D/d/core/scripts/" && cp "$R" "$P" "$D/c/scripts/ai-dlc/" && cp "$H" "$D/c/.githooks/pre-push" && cp "$K" "$D/c/.claude/schemas/" || exit 9; case "${6:-}" in hook*) mkdir -p "$D/d/core/git-hooks" && awk '/^if \[ -f scripts\/ai-dlc\/render-agent-definitions\.sh \]; then$/ {s=1} !s {print} s && /^fi$/ {s=0}' "$H" > "$D/d/core/git-hooks/pre-push" && cp "$D/d/core/git-hooks/pre-push" "$D/c/.githooks/pre-push" || exit 9; [ "$(grep -c render-agent-definitions "$D/c/.githooks/pre-push")" = 0 ] || exit 9 ;; esac; printf '0.1.0\n' > "$D/d/VERSION"; printf '{"aiDlcRoles":{"dev":{"model":"m"}},"aiDlcModels":{"m":"claude-x"}}\n' > "$D/c/.claude/settings.json"; bash "$R" --root "$D/c" >/dev/null 2>&1 || exit 9; [ "$3" = drift ] && printf 'drift\n' >> "$D/c/.claude/agents/dev.md"; [ "${6:-}" = absent ] && rm -f "$D/d/core/scripts/$2"; git -C "$D/d" add -A && git -C "$D/d" -c user.name=r -c user.email=r@r commit -qm base || exit 9; sed "$4" "$S" > "$N"; cmp -s "$S" "$N" && exit 9; case "${6:-}" in hook*) cp "$H" "$D/d/core/git-hooks/pre-push" || exit 9 ;; esac; printf '0.2.0\n' > "$D/d/VERSION"; git -C "$D/d" add -A && git -C "$D/d" -c user.name=r -c user.email=r@r commit -qm theirs || exit 9; [ "${6:-}" = absent ] && rm -f "$S"; HC="$( cd "$D/c" && AI_DLC_PROJECT_ROOT="$D/c" bash "$S" $5 >/dev/null 2>&1; echo $? )"; HN="$( cd "$D/c" && AI_DLC_PROJECT_ROOT="$D/c" bash "$N" $5 >/dev/null 2>&1; echo $? )"; A0="$(cat "$D/c/.claude/agents/"* | cksum)"; bash "$G" "$D/d" "$(git -C "$D/d" rev-parse HEAD~1)" "$(git -C "$D/d" rev-parse HEAD)" "$D/c" > "$D/out" 2>/dev/null; [ -s "$D/out" ] || exit 9; [ "$A0" = "$(cat "$D/c/.claude/agents/"* | cksum)" ] && AG=same || AG=moved; }; rf() { n="$(grep -cE "^SELF-UPDATE-(DEFER|UNDECIDED).$2" "$W/$1/out")" || n=0; printf '%s' "$n"; }; ok() { n="$(grep -cE "^SELF-UPDATE-OK.$2" "$W/$1/out")" || n=0; printf '%s' "$n"; }; sw body render-agent-definitions.sh clean 's/FIRST action before any other work/FIRST action, before any other work/' '--check --root .'; [ "$HC$HN" = 01 ] || exit 9; AB="$AG"; cp -R "$D/c" "$D/o" && cp -R "$D/c" "$D/n" && cp "$N" "$D/n/scripts/ai-dlc/render-agent-definitions.sh" || exit 9; ( cd "$D/o" && bash scripts/ai-dlc/render-agent-definitions.sh --root . >/dev/null 2>&1 ); ( cd "$D/n" && bash scripts/ai-dlc/render-agent-definitions.sh --root . >/dev/null 2>&1 ); L3="$( cd "$D/o" && bash "$N" --check --root . >/dev/null 2>&1; echo $? )$( cd "$D/n" && bash "$N" --check --root . >/dev/null 2>&1; echo $? )"; [ "$L3" = 10 ] || exit 9; sw benign render-agent-definitions.sh clean 's/^# --check NEVER WRITES, so it is safe/# --check NEVER WRITES; it is safe/' '--check --root .'; [ "$HC$HN" = 00 ] || exit 9; sw drift render-agent-definitions.sh drift 's/^# --check NEVER WRITES, so it is safe/# --check NEVER WRITES; it is safe/' '--check --root .'; [ "$HC$HN" = 11 ] || exit 9; sw strays validate-provenance-block.sh clean 's/^if strays:$/if strays or candidates:/' '--strays'; [ "$HC$HN" = 01 ] || exit 9; sw hookadd render-agent-definitions.sh clean 's/FIRST action before any other work/FIRST action, before any other work/' '--check --root .' hookadd; [ "$HC$HN" = 01 ] || exit 9; sw hookbenign render-agent-definitions.sh clean 's/^# --check NEVER WRITES, so it is safe/# --check NEVER WRITES; it is safe/' '--check --root .' hookbenign; [ "$HC$HN" = 00 ] || exit 9; sw absent render-agent-definitions.sh clean 's/FIRST action before any other work/FIRST action, before any other work/' '--check --root .' absent; [ "$HC$HN" = 1271 ] || exit 9; U="$W/unch"; mkdir -p "$U/d/core/scripts" "$U/d/core/git-hooks" "$U/c/scripts/ai-dlc" "$U/c/.githooks" "$U/c/.claude/schemas" || exit 9; git -C "$U/d" init -q || exit 9; cp "$R" "$P" "$U/d/core/scripts/" && cp "$R" "$U/c/scripts/ai-dlc/" && cp "$K" "$U/c/.claude/schemas/" || exit 9; printf '#!/bin/sh\n# consumer edit\nexit 1\n' > "$U/c/scripts/ai-dlc/validate-provenance-block.sh"; awk '/^if \[ -f scripts\/ai-dlc\/validate-provenance-block\.sh \]; then$/ {s=1} !s {print} s && /^fi$/ {s=0}' "$H" > "$U/d/core/git-hooks/pre-push" && cp "$U/d/core/git-hooks/pre-push" "$U/c/.githooks/pre-push" || exit 9; [ "$(grep -v '^[[:space:]]*#' "$U/c/.githooks/pre-push" | grep -c validate-provenance-block)" = 0 ] || exit 9; printf '{"aiDlcRoles":{"dev":{"model":"m"}},"aiDlcModels":{"m":"claude-x"}}\n' > "$U/c/.claude/settings.json"; bash "$R" --root "$U/c" >/dev/null 2>&1 || exit 9; printf '0.1.0\n' > "$U/d/VERSION"; git -C "$U/d" add -A && git -C "$U/d" -c user.name=r -c user.email=r@r commit -qm base || exit 9; sed 's/^# --check NEVER WRITES, so it is safe/# --check NEVER WRITES; it is safe/' "$R" > "$U/d/core/scripts/render-agent-definitions.sh"; cp "$H" "$U/d/core/git-hooks/pre-push"; printf '0.2.0\n' > "$U/d/VERSION"; git -C "$U/d" add -A && git -C "$U/d" -c user.name=r -c user.email=r@r commit -qm theirs || exit 9; [ "$(git -C "$U/d" diff --name-only HEAD~1 HEAD -- core/scripts/validate-provenance-block.sh | grep -c .)" = 0 ] || exit 9; UC="$( cd "$U/c" && bash scripts/ai-dlc/validate-provenance-block.sh --strays >/dev/null 2>&1; echo $? )$( cd "$U/c" && AI_DLC_PROJECT_ROOT="$U/c" bash "$U/d/core/scripts/validate-provenance-block.sh" --strays >/dev/null 2>&1; echo $? )"; [ "$UC" = 10 ] || exit 9; bash "$G" "$U/d" "$(git -C "$U/d" rev-parse HEAD~1)" "$(git -C "$U/d" rev-parse HEAD)" "$U/c" > "$U/out" 2>/dev/null; [ -s "$U/out" ] || exit 9; O2="$W/orguard"; mkdir -p "$O2/d/core/scripts" "$O2/d/core/git-hooks" "$O2/c/scripts/ai-dlc" "$O2/c/.githooks" "$O2/c/.claude/schemas" || exit 9; git -C "$O2/d" init -q || exit 9; cp "$R" "$P" "$O2/d/core/scripts/" && cp "$R" "$O2/c/scripts/ai-dlc/" && cp "$K" "$O2/c/.claude/schemas/" && cp "$U/c/.claude/settings.json" "$O2/c/.claude/" || exit 9; git -C "$U/d" show HEAD~1:core/git-hooks/pre-push > "$O2/d/core/git-hooks/pre-push" && cp "$O2/d/core/git-hooks/pre-push" "$O2/c/.githooks/pre-push" || exit 9; bash "$R" --root "$O2/c" >/dev/null 2>&1 || exit 9; printf '0.1.0\n' > "$O2/d/VERSION"; git -C "$O2/d" add -A && git -C "$O2/d" -c user.name=r -c user.email=r@r commit -qm base || exit 9; GL='[ -f scripts/ai-dlc/validate-provenance-block.sh ] || echo missing'; RL='bash scripts/ai-dlc/validate-provenance-block.sh --strays || exit 1'; printf '%s\n%s\n' "$GL" "$RL" >> "$O2/d/core/git-hooks/pre-push"; sed 's/^# --check NEVER WRITES, so it is safe/# --check NEVER WRITES; it is safe/' "$R" > "$O2/d/core/scripts/render-agent-definitions.sh"; printf '0.2.0\n' > "$O2/d/VERSION"; git -C "$O2/d" add -A && git -C "$O2/d" -c user.name=r -c user.email=r@r commit -qm theirs || exit 9; [ "$(git -C "$O2/d" diff --name-only HEAD~1 HEAD -- core/scripts/validate-provenance-block.sh | grep -c .)" = 0 ] || exit 9; [ -f "$O2/c/scripts/ai-dlc/validate-provenance-block.sh" ] && exit 9; OG="$( cd "$O2/c" && bash -c "$GL; $RL" >/dev/null 2>&1; echo $? )"; [ "$OG" = 0 ] && exit 9; bash "$G" "$O2/d" "$(git -C "$O2/d" rev-parse HEAD~1)" "$(git -C "$O2/d" rev-parse HEAD)" "$O2/c" > "$O2/out" 2>/dev/null; [ -s "$O2/out" ] || exit 9; [ "$(rf orguard validate-provenance-block)" -ge 1 ] && [ "$(rf unch validate-provenance-block)" -ge 1 ] && [ "$(rf hookadd render-agent-definitions)" -ge 1 ] && [ "$(rf hookbenign '')" -eq 0 ] && [ "$(ok hookbenign render-agent-definitions)" -eq 1 ] && [ "$(rf absent render-agent-definitions)" -ge 1 ] && [ "$(rf body render-agent-definitions)" -ge 1 ] && [ "$AB" = same ] && [ "$(rf benign '')" -eq 0 ] && [ "$(ok benign render-agent-definitions)" -eq 1 ] && [ "$(rf drift '')" -eq 0 ] && [ "$(ok drift render-agent-definitions)" -eq 1 ] && [ "$(rf strays validate-provenance-block)" -ge 1 ]

