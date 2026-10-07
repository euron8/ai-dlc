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
validator, and must be refused.

Round 5 made two more fixes. First, the hook-change key now carries the guard column, so a hook that keeps the test but
unties it from the run is a new question (`hu-keeptest`, mutant `hu-mut-dropguard`). Second, the if-frame stack opens
only on a SHELL `if`, never on an awk `if (` inside a quoted program; that opener had left both shipped hooks at depth
4, and they now end at 0 (`hu-awkif`, `hu-mut-awkopen`, `hu-stack-depth`). Known shapes the scan does not model, each
failing closed or found in no real hook, and exercised by no world: a one-line `then … else` on the run's line, a
closing `fi;`, an `if` opened inside a heredoc body, and the status of a run inside a longer `&&` list. The current side reads 0 where today's hook does not ask the question or the consumer has no copy,
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

## BL-464 — the cross seat is the serial tail of a sharded party round and writes nothing until it is done

**DEFECT.** Filed by the consumer as `PC-S317-CROSS-SEAT-IS-THE-SERIAL-TAIL-OF-A-SECTIONS-PARTY-ROUND-AND-WRITES-NOTHING-UNTIL-DONE`,
measured on its S317 architecture step: a seats x sections party round of 4 seats x (8 parts + one cross seat each). The 32
part seats finished in 47 minutes; the cross seats then ran 34, 96 and 102 minutes, and the fourth (`tea-cross`) delivered
only after 142.1 minutes and 1,025,333 output tokens. Wall clock tracked output tokens at about 100 per second; tool time
was 0.4 minutes of 91.7 on the seat it was measured on. Every cross agent with that shape — the party cross seat on all
three seats axes, the adversarial-review cross shard, the elicitation cross-part adversary — is one agent holding every
pair of parts, and none of them was told to write before it finished, so the join saw nothing on disk for 138 minutes
and could not tell a working seat from a dead one. The consumer's own grep found no early-write instruction in
`_gate-procedures.md` or the role file (0, against a control of 18 and 3 on the same files).

**The distinct claims, and which survived.**

1. *Prune the cross work list to pairs whose parts cite a shared identifier* (direction 1). **Refuted** on the S317 spine:
   the shipped MAJOR `dev` finding F-X5 rests on the pair (4,7), whose two parts share zero identifier tokens, so the
   pruning would have dropped a real MAJOR. Measured by the batch lead on the consumer's S317 spine; it cannot be
   re-derived in this tree. Not built.
2. *Fan the cross seat out per pair-group, in the same waves as the parts* (direction 2). **Built**:
   `partition-document.sh --cross-groups <K>` prints at most six groups covering every unordered pair, and every cross
   agent on every axis is one per group (`_gate-procedures.md` "Validation cycle" item 1, Rule 28 "The cross-part agent is
   sharded too"). **Each cross agent reads the whole document; its group's pairs are its focus, not its boundary.**
   The groups cover every pair, not every triple. Measured on the consumer's s3* cross corpus with this tree's
   partitioner (39 files, 117 findings citing two or more ordinals, 4 of them refused by `--cross-owner`), parsed by
   one `awk` pass that reads every column-0 `stories:`, `sections:` or `parts:` line citing two or more distinct
   ordinals as one finding (the batch's scratch `b202-csint2-graph.sh`): 42 cite three or more, and 30 of
   those are held by NO group, so a group-bounded citation rule loses them. Wall clock tracks the tokens a cross agent
   writes, not the bytes it reads (the consumer's ledger), so the whole read is cheap and the focus is what shortens it.
   The merges (`merge-adversarial-shards.sh` in every mode, `merge-review-shards.sh`) accept a cross finding from any
   group and refuse one outside its owner (`--cross-owner`) only when the owner's shard carries the identical cited set.
   **Inflation that rule allows, measured once on the same corpus:** at most 124 extra counted findings over 117,
   one per group beyond the owner that holds two or more of a finding's ordinals, if each reported its own distinct
   subset; 0 if they report the identical set. The corpus is single-reporter history, so this is a bound, not an observation.
3. *Write early and let the join key on the file* (direction 3). **Confirmed and built**, with the key changed: the
   closing record shows a DELIVERED beat on an early-written file can be partial (DELIVERED at the first `Write`, three
   minutes before the file was final). So growth alone is not the key; every seat and adversary ends its file with ONE
   `seat-complete: <step> <seat> <shard> findings=<n>` line, written once as its final write and never with its header,
   `wait-for-deliverable.sh --complete` takes only that as delivered, and each target's own growth is its progress.
   The beat reads the marker only; both merges compare `findings=<n>` with the findings they parse and refuse a shard
   that disagrees, so an all-marked directory with one truncated shard no longer merges. A party round's seat files are
   read by the lead and `join-remediator-shards.sh`, neither of which checks the count. `--progress-path` is not used.
4. *Size the beat ceiling for the cross seat, or pass `--progress-path` by default* (direction 4). **Not built**: no ceiling
   knob. A grant reaches 120 minutes and S317's `tea-cross` took 142.1, so no grant would have covered it; the fan-out is
   the fix, not a longer wait.
5. *Run the cross round after the part repairs* (direction 5). **Not built**: it lengthens the critical path and its
   precondition (the pruned work list) was refuted. Replaced by a derivation re-check: the serial remediator runs
   `validate-artifact-derivations.sh` on the cross files against the assembled document and re-derives any STALE finding
   before applying it. Its limit is stated where it is prescribed: only `derived`-fenced claims are re-run.
6. *The second effect: cross findings cite pre-repair line numbers* — holds for three of the four S317 cross files; it is
   what claim 5's replacement addresses. The first record's "6 of 54 derivations stale" was measured on a partial file and
   was retracted by the consumer; it is not relied on here.
7. *The tail shortens.* **A hypothesis, not a measurement.** Nothing here has run a consumer round. It is measured on the
   consumer's next sharded party round, by comparing the slowest cross shard's span against the 142.1 minutes above.

**Receipt.** Behavioural, on mktemp state. Arm 1 is the control (a skeleton with no flag is DELIVERED); a failed control
exits 9. Arm 2: the same skeleton under `--complete` is WAITING. Arm 3: the marker last is DELIVERED, a finding after it is
WAITING, trailing blanks are skipped. Arm 4: two targets under `--complete`, one growing and one static — the growing one
reads PROGRESS and the static one NON-DELIVERY, rc 1. Arm 5: `--cross-groups` for K=2..24 covers every pair with G<=6 and
is byte-identical on two runs; K=2 is one row, K=8 six; K<2 and non-numeric exit 64; `--cross-owner` names the owner; and
the control (K=8 with its last row dropped) leaves a pair uncovered, else exit 9. Arm 6, in each of files, `--document`
and `--subject --elicitation` at K=8: `cross-1..6` merges with cross-1's `tool_use_id`, `cross.md` alone is refused, a
finding `{1,2}` reported by its owner group AND a non-owner group is refused, and a finding `{1,2,K-1}` reported only by a
non-owner merges; at K=2 a lone `cross.md` merges (files, document).
Arm 7, Check 24 K3 on an installed world: a terminal subject pass with ordinals plus `cross-1..6` passes; ordinals plus
one `cross` FAILs after the `K3C_RELEASE` stamp and is PENDING before it. Arm 8, `merge-review-shards.sh` at K=8:
`cross-1..6` merges, one `cross.md` is refused as owed only at K=2, and a finding `{1,2}` reported in both its owner
`cross-1` and in `cross-3` is refused, nothing written in either refusal. Arms 6-7 take the group table from a reference construction
written into the receipt, never from the tree's partitioner, so a wrong partitioner cannot grade itself.

**The hand-over rule that shipped differs from the contract, and the shipped one holds.** The contract assigned a QA
part shard's handed-over replay to the owner group of the ordinals involved. The shipped rule is that the first cross
QA (`cross-1`, or `cross` at K=2) runs every handed-over replay and writes the per-AC table and `## Deferred ACs`; every
other cross QA executes nothing (`core/team-roles/qa.md` "With more than one cross group", and the Gate-2 dispatch
paragraph of `core/skills/ai-dlc/steps/implementation.md`). The reason is that every replay runs in the one frozen
worktree at the go-signal sha: spreading them across groups would put several agents mutating and restoring the same
checkout at once, and a hand-over is about one part's AC, not an interaction between two parts, so it has no owner pair.
`merge-review-shards.sh` enforces it by refusing a `handover-run:` line in any cross shard but the first.

verify: sh W="$PWD/"core/scripts/wait-for-deliverable.sh; P="$PWD/"core/scripts/partition-document.sh; [ -f "$W" ] && [ -f "$P" ] || exit 9; T="$(mktemp -d)" || exit 9; F=0; has() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }; wb() { OUT="$(cd "$T" && env -u CLAUDE_CODE_SESSION_ID AI_DLC_STATE_DIR="$1" AI_DLC_WAIT_BEAT_SECS=3 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=0 AI_DLC_MAX_WAIT_BEATS=1 AI_DLC_TEAMMATE_DIR="$T/none" bash "$W" "${@:2}" 2>&1)"; RC=$?; }; S=$(( $(date +%s) - 30 )); printf '# seat skeleton\n\n- finding one\n' > "$T/a.md"; wb "$T/s1" --since "$S" "$T/a.md"; has "$OUT" "DELIVERED $T/a.md" || exit 9; printf '# seat skeleton\n\n- finding one\n' > "$T/b.md"; wb "$T/s2" --complete --since "$S" "$T/b.md"; { has "$OUT" "WAITING   $T/b.md" && ! has "$OUT" "DELIVERED $T/b.md" && [ "$RC" -eq 0 ]; } || F=$((F + 1)); printf '# s\n- f\nseat-complete: requirements pm cross-1\n' > "$T/c.md"; wb "$T/s3a" --complete --since "$S" "$T/c.md"; o1="$OUT"; printf '# s\nseat-complete: requirements pm cross-1\n- a finding appended after it\n' > "$T/d.md"; wb "$T/s3b" --complete --since "$S" "$T/d.md"; o2="$OUT"; printf '# s\n- f\nseat-complete: requirements pm cross-1\n\n  \n\n' > "$T/e.md"; wb "$T/s3c" --complete --since "$S" "$T/e.md"; o3="$OUT"; { has "$o1" "DELIVERED $T/c.md" && has "$o2" "WAITING   $T/d.md" && ! has "$o2" "DELIVERED $T/d.md" && has "$o3" "DELIVERED $T/e.md"; } || F=$((F + 10)); printf '# grow\n' > "$T/g.md"; printf '# static\n' > "$T/st.md"; ( sleep 1; printf -- '- finding\n' >> "$T/g.md" ) & wb "$T/s4" --complete --since "$S" "$T/g.md" "$T/st.md"; o1="$OUT"; wait; wb "$T/s4" --complete --since "$S" "$T/g.md" "$T/st.md"; o2="$OUT"; r2=$RC; { has "$o1" "WAITING   $T/g.md" && has "$o2" "PROGRESS  $T/g.md" && has "$o2" "NON-DELIVERY $T/st.md" && ! has "$o2" "NON-DELIVERY $T/g.md" && ! has "$o2" "PROGRESS  $T/st.md" && [ "$r2" -eq 1 ]; } || F=$((F + 100)); cov() { /usr/bin/awk -F'\t' -v K="$1" '{ G++; n = split($2, a, ","); for (i = 1; i <= n; i++) for (j = i + 1; j <= n; j++) c[a[i] "," a[j]] = 1 } END { m = 0; for (i = 1; i <= K; i++) for (j = i + 1; j <= K; j++) if (!((i "," j) in c)) m++; print m " " G + 0 }'; }; b5=0; for K in $(seq 2 24); do a="$(bash "$P" --cross-groups "$K" 2>/dev/null)"; b="$(bash "$P" --cross-groups "$K" 2>/dev/null)"; r="$(cov "$K" <<<"$a")"; { [ -n "$a" ] && [ "$a" = "$b" ] && [ "${r% *}" -eq 0 ] && [ "${r#* }" -ge 1 ] && [ "${r#* }" -le 6 ]; } || b5=1; done; [ "$(bash "$P" --cross-groups 2 2>/dev/null)" = "$(printf '1\t1,2')" ] || b5=1; n8="$(bash "$P" --cross-groups 8 2>/dev/null | grep -c .)" || n8=0; [ "$n8" -eq 6 ] || b5=1; bash "$P" --cross-groups 1 >/dev/null 2>&1; [ $? -eq 64 ] || b5=1; bash "$P" --cross-groups x >/dev/null 2>&1; [ $? -eq 64 ] || b5=1; for c in "1,2:1" "3,5:4" "8,2,7:3" "1,8:3"; do [ "$(bash "$P" --cross-owner 8 "${c%%:*}" 2>/dev/null)" = "${c##*:}" ] || b5=1; done; ctl="$(bash "$P" --cross-groups 8 2>/dev/null | sed '$d' | cov 8)"; [ "$b5" -eq 1 ] || [ "${ctl% *}" -gt 0 ] || exit 9; [ "$b5" -eq 0 ] || F=$((F + 1000)); ( for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done; unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; S6="$PWD/"core/scripts; [ -f "$PWD/"core/scripts/merge-adversarial-shards.sh ] && [ -f "$PWD/"core/scripts/partition-subject.sh ] || exit 9; W6="$(mktemp -d)" || exit 9; trap 'rm -rf "$W6"' EXIT; miss() { echo "ARM6/7 STILL LIVE -- $*"; exit 1; }; qgroups() { /usr/bin/awk -v K="$1" 'BEGIN { n = 0; s = 1; for (i = 1; i <= 4; i++) { sz = int(K / 4) + (i <= K % 4 ? 1 : 0); if (sz > 0) { n++; lo[n] = s; hi[n] = s + sz - 1; s += sz } }; if (n == 2) { printf "1\t"; for (x = 1; x <= K; x++) printf "%s%d", (x > 1 ? "," : ""), x; printf "\n"; exit }; g = 0; for (a = 1; a <= n; a++) for (b = a + 1; b <= n; b++) { g++; printf "%d\t", g; f = 1; for (x = lo[a]; x <= hi[a]; x++) { printf "%s%d", (f ? "" : ","), x; f = 0 }; for (x = lo[b]; x <= hi[b]; x++) printf ",%d", x; printf "\n" } }'; }; qowner() { qgroups "$1" | /usr/bin/awk -F'\t' -v a="$2" -v b="$3" '{ n = split($2, t, ","); h = 0; for (i = 1; i <= n; i++) if (t[i] == a || t[i] == b) h++; if (h == 2) { print $1; exit } }'; }; qkeys() { local g; g="$(qgroups "$1" | grep -c .)"; if [ "$g" -eq 1 ]; then echo cross; else seq 1 "$g" | sed 's/^/cross-/'; fi; }; qcover() { qgroups "$1" | /usr/bin/awk -F'\t' '$2 ~ /(^|,)1(,|$)/ && $2 ~ /(^|,)2(,|$)/ { print $1 }'; }; [ "$(qgroups 8 | grep -c .)" -eq 6 ] && [ "$(qgroups 2)" = "$(printf '1\t1,2')" ] || exit 9; lorem() { local i; for i in $(seq 1 "$2"); do printf '%s line %d of the section, carrying enough prose to weigh something real.\n' "$1" "$i"; done; }; g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$1" -c user.name=r -c user.email=r@example.invalid -c core.hooksPath=/dev/null -c commit.gpgsign=false "${@:2}"; }; shard() { local d="$1" k="$2" c="$3" n="$4" mode="$5" art="${6:-}" sh="${7:-}" i=0 ax=stories mm; [ "$mode" = files ] || ax=sections; case "$k" in cross) mm=59 ;; cross-*) mm=$((50 + ${k#cross-})) ;; *) mm=$((10#$k)) ;; esac; { printf '# shard %s\n\n## Findings\n\n'; while [ "$i" -lt "$n" ]; do i=$((i + 1)); printf '### M%s — MAJOR — finding\n\n%s: %s\n\n' "$i" "$ax" "$c"; done; printf '<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: %s\ninvoked_at: 2026-10-01T10:%02d:00Z\n' "$( [ "$mode" = elicit ] && echo bmad-advanced-elicitation || echo ai-dlc-adversary-review)" "$mm"; printf 'tool_use_id: toolu_r67%s\nmode: subagent\nlead_role: requirements\n' "$k"; [ -n "$art" ] && printf 'artifact: %s\n' "$art"; [ -n "$sh" ] && printf 'artifact_sha: %s\n' "$sh"; printf 'findings_critical: 0\nfindings_major: %s\n' "$n"; [ "$mode" = elicit ] || printf 'verdict: EXIT_CONDITION_MET\n'; printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'; } > "$d/$k.md"; }; files_world() { local pa i; rm -rf "$W6/fw"; pa="$W6/fw/pa"; mkdir -p "$pa/s1/stories" "$pa/s1/shards/stories-p1"; for i in $(seq 1 "$1"); do printf '# Story %s\n' "$i" > "$pa/s1/stories/story-$(printf '%02d' "$i").md"; done; for i in $(seq 1 "$1"); do shard "$pa/s1/shards/stories-p1" "$i" "$i" 0 files "" "$(shasum -a 256 "$pa/s1/stories/story-$(printf '%02d' "$i").md" | cut -d' ' -f1)"; done; d="$pa/s1/shards/stories-p1"; }; doc_world() { local pa i n doc; rm -rf "$W6/dw"; pa="$W6/dw/pa"; mkdir -p "$pa/s1/shards/doc-p1"; doc="$pa/s1/doc.md"; if [ "$1" -eq 2 ]; then { printf '## A\n\n'; lorem a 15; printf '## B\n\n'; lorem b 15; } > "$doc"; else { printf '# D\n\n'; for i in $(seq 1 "$1"); do printf '## S%s\n\n' "$i"; lorem "s$i" 15; printf '\n'; done; } > "$doc"; fi; n="$(bash "$S6"/partition-document.sh --map "$doc" | grep -c .)" || n=0; [ "$n" -eq "$1" ] || return 1; for i in $(seq 1 "$1"); do shard "$pa/s1/shards/doc-p1" "$i" "$i" 0 document "$doc" "$(shasum -a 256 "$doc" | cut -d' ' -f1)"; done; d="$pa/s1/shards/doc-p1"; art="$doc"; sh="$(shasum -a 256 "$doc" | cut -d' ' -f1)"; }; SPA=_bmad-output/planning-artifacts; w="$W6/ww"; mkw() { local pa i; rm -rf "$w"; mkdir -p "$w" || return 1; pa="$w/$SPA"; mkdir -p "$pa/s9" "$w/_bmad-output/specs/s9/kernel" "$w/.claude"; [ "${2:-}" = scripts ] && { mkdir -p "$w/scripts"; cp -R "$S6" "$w/scripts/ai-dlc"; }; { g "$w" init -q . && g "$w" checkout -q -b main && { printf '# Brief\n\n## V\n\n'; lorem v 10; } > "$pa/product-brief.md" && { printf '# PRD\n\n## Current\n\n'; lorem c 20; printf '\n## S8\n\n'; lorem s8 20; printf '\n'; } > "$pa/prd.md" && printf -- '- FR-S8-1: architecture_impact: none\n' > "$pa/s9/architecture-impact.md" && printf 'version: 9.0.0\n' > "$w/.claude/.ai-dlc-version" && g "$w" add -A && GIT_COMMITTER_DATE="$1" GIT_AUTHOR_DATE="$1" g "$w" commit -q -m stamp && g "$w" checkout -q -b sprint-9; } >/dev/null 2>&1 || return 1; printf 'A new brief line.\n' >> "$pa/product-brief.md"; { printf '## Sprint 9\n\n'; for i in 1 2 3 4 5 6; do printf '### R%s\n\n' "$i"; lorem "r$i" 30; printf '\n'; done; } >> "$pa/prd.md"; printf '# SPEC\n\ncap-1: THE system SHALL x.\n' > "$w/_bmad-output/specs/s9/kernel/SPEC.md"; printf -- '- FR-S9-1: architecture_impact: none\n' >> "$pa/s9/architecture-impact.md"; AI_DLC_PROJECT_ROOT="$w" bash "$S6"/partition-subject.sh --map 9 > "$w/subject.map" 2>/dev/null || return 1; }; stems() { printf 'product-brief=%s SPEC=%s prd=%s architecture-impact=%s' "$(shasum -a 256 "$w/$SPA/product-brief.md" | cut -d' ' -f1)" "$(shasum -a 256 "$w/_bmad-output/specs/s9/kernel/SPEC.md" | cut -d' ' -f1)" "$(shasum -a 256 "$w/$SPA/prd.md" | cut -d' ' -f1)" "$(shasum -a 256 "$w/$SPA/s9/architecture-impact.md" | cut -d' ' -f1)"; }; subj_shards() { local o; mkdir -p "$1"; for o in $(cut -f1 "$w/subject.map"); do shard "$1" "$o" "$o" 0 "$2" "$SPA/s9/requirements-subject.md" "$(stems)"; done; }; xshards() { local k; for k in $3; do shard "$1" "$k" "$4" "${7:-0}" "$2" "${5:-}" "${6:-}"; done; }; run_merge() { case "$1" in files) bash "$S6"/merge-adversarial-shards.sh "$2" > "$W6/mo" 2>&1 ;; document) bash "$S6"/merge-adversarial-shards.sh --document "$(dirname "$(dirname "$2")")/doc.md" "$2" > "$W6/mo" 2>&1 ;; elicit) bash "$S6"/merge-adversarial-shards.sh --subject 9 --elicitation "$2" > "$W6/mo" 2>&1 ;; esac; RC=$?; }; mk() { case "$mode" in files) files_world 8; K=8; art="_bmad-output/s1/stories"; sh="" ;; document) d=""; doc_world 8 || exit 9; K=8 ;; elicit) mkw 2026-01-01T00:00:00Z || exit 9; d="$w/$SPA/s9/shards/requirements-elicitation"; K="$(grep -c . "$w/subject.map")"; subj_shards "$d" elicit; art="$SPA/s9/requirements-subject.md"; sh="$(stems)" ;; esac; [ -d "$d" ] || exit 9; }; arm6_mode() { local own non out; mode="$1"; mk; [ "$K" -ge 5 ] || miss "6 ($mode) the world maps to $K units; G=6 needs K>=5"; xshards "$d" "$mode" "$(qkeys "$K")" "1, 2" "$art" "$sh"; run_merge "$mode" "$d"; [ "$RC" -eq 0 ] || miss "6 ($mode) K=$K with cross-1..6 did not merge: $(head -1 "$W6/mo")"; case "$mode" in files) grep -qx 'tool_use_id: toolu_r67cross-1' "$W6/fw/pa/s1/stories-adversarial-p1.md" ;; document) grep -qx 'tool_use_id: toolu_r67cross-1' "$W6/dw/pa/s1/doc-adversarial-p1.md" ;; elicit) grep -qx 'tool_use_id: toolu_r67cross-1' "$W6/ww/_bmad-output/planning-artifacts/s9/requirements-elicitation.md" ;; esac 2>/dev/null || miss "6 ($mode) the merged tool_use_id is not cross-1's"; mk; xshards "$d" "$mode" cross "1, 2" "$art" "$sh"; run_merge "$mode" "$d"; [ "$RC" -eq 2 ] || miss "6 ($mode) K=$K with only cross.md merged (rc=$RC)"; own="$(qowner "$K" 1 2)"; non="$(qcover "$K" | grep -vx "$own" | head -1)"; [ -n "$non" ] || exit 9; mk; xshards "$d" "$mode" "$(qkeys "$K")" "1, 2" "$art" "$sh"; shard "$d" "cross-$own" "1, 2" 1 "$mode" "$art" "$sh"; shard "$d" "cross-$non" "1, 2" 1 "$mode" "$art" "$sh"; run_merge "$mode" "$d"; [ "$RC" -eq 2 ] || miss "6 ($mode) a finding in owner cross-$own AND non-owner cross-$non merged (rc=$RC)"; non3="$(qgroups "$K" | /usr/bin/awk -F'\t' -v o="$own" -v z="$((K - 1))" '$1 != o && ("," $2 ",") ~ /,1,/ && ("," $2 ",") ~ ("," z ",") { print $1; exit }')"; [ -n "$non3" ] || exit 9; mk; xshards "$d" "$mode" "$(qkeys "$K")" "1, 2" "$art" "$sh"; shard "$d" "cross-$non3" "1, 2, $((K - 1))" 1 "$mode" "$art" "$sh"; run_merge "$mode" "$d"; [ "$RC" -eq 0 ] || miss "6 ($mode) a finding citing 1, 2, $((K - 1)) held only by non-owner cross-$non3 did not merge (rc=$RC): $(head -1 "$W6/mo")"; [ "$mode" = elicit ] && return 0; case "$mode" in files) files_world 2; art="_bmad-output/s1/stories"; sh="" ;; document) doc_world 2 || exit 9 ;; esac; xshards "$d" "$mode" cross "1, 2" "$art" "$sh"; run_merge "$mode" "$d"; [ "$RC" -eq 0 ] || miss "6 ($mode) K=2 with cross.md did not merge: $(head -1 "$W6/mo")"; }; arm6_mode files; arm6_mode document; arm6_mode elicit; k3_pass() { local K o ids="" sl; K="$(grep -c . "$w/subject.map")"; sl="$(stems)"; for o in $(cut -f1 "$w/subject.map"); do ids="$ids $o=toolu_k$o"; done; if [ "$1" = groups ]; then for o in $(qkeys "$K"); do ids="$ids $o=toolu_k$o"; done; else ids="$ids cross=toolu_kx"; fi; { printf '# requirements -- adversarial pass 1\n\n## Findings\n\n'; printf '<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: ai-dlc-adversary-review\ninvoked_at: 2026-10-01T10:00:00Z\n'; printf 'tool_use_id: toolu_kfirst\nshard_tool_use_ids:%s\nmode: subagent\nlead_role: requirements\n' "$ids"; printf 'artifact: %s/s9/requirements-subject.md\nartifact_sha: %s\n' "$SPA" "$sl"; printf 'findings_critical: 0\nfindings_critical_prior_scope: 0\nfindings_major: 0\nfindings_major_underived: 0\nfindings_minor: 0\nverdict: EXIT_CONDITION_MET\n'; printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'; } > "$w/$SPA/s9/requirements-adversarial-p1.md"; }; k3_run() { bash "$w/scripts/ai-dlc/validate-adversarial-convergence.sh" --series "$w/$SPA/s9/requirements-adversarial-p" > "$W6/vo" 2>&1; VRC=$?; }; mkw 2026-01-01T00:00:00Z scripts && [ "$(grep -c . "$w/subject.map")" -ge 5 ] || exit 9; k3_pass groups; k3_run; { [ "$VRC" -eq 0 ] && ! grep -q 'K3 -- SUBJECT' "$W6/vo"; } || miss "7 a terminal pass with ordinals + cross-1..6 did not pass K3 (rc=$VRC)"; k3_pass single; k3_run; { [ "$VRC" -eq 1 ] && grep -q 'FAIL (K3' "$W6/vo"; } || miss "7 ordinals + cross, post-stamp, did not FAIL K3 (rc=$VRC)"; mkw 2026-12-01T00:00:00Z scripts || exit 9; k3_pass single; k3_run; { [ "$VRC" -eq 0 ] && grep -q 'PENDING (K3' "$W6/vo" && ! grep -q 'FAIL (K3' "$W6/vo"; } || miss "7 ordinals + cross, pre-stamp, was not PENDING (rc=$VRC)"; exit 0 ); r67=$?; [ "$r67" -eq 9 ] && exit 9; [ "$r67" -eq 0 ] || F=$((F + 10000)); ( SD="$PWD/"core/scripts; PROJ="$PWD"; [ -f "$PWD/"core/scripts/merge-review-shards.sh ] && [ -f "$PWD/"core/scripts/partition-review-diff.sh ] && [ -f "$PWD/"core/skills/ai-dlc/artifact-path-grammar.md ] || exit 9; X="$(mktemp -d)" || exit 9; trap 'rm -rf "$X"' EXIT; gg() { git -c user.name=r -c user.email=r@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }; R="$X/repo"; mkdir -p "$R/core/skills/ai-dlc"; gg init -q "$R" || exit 9; cp "$PROJ/"core/skills/ai-dlc/artifact-path-grammar.md "$R/core/skills/ai-dlc/" || exit 9; echo seed > "$R/README"; gg -C "$R" add -A && gg -C "$R" commit -q -m base || exit 9; for i in 1 2 3 4 5 6 7 8; do mkdir -p "$R/e$i"; for f in a b; do : > "$R/e$i/$f.txt"; for n in 1 2 3 4 5; do echo "e$i-$f $n" >> "$R/e$i/$f.txt"; done; done; done; gg -C "$R" add -A && gg -C "$R" commit -q -m frozen || exit 9; BASE="$(gg -C "$R" rev-parse HEAD~1)"; SHA="$(gg -C "$R" rev-parse HEAD)"; S12="$(printf '%s' "$SHA" | cut -c1-12)"; XGROUPS="1:1,2,3,4 2:1,2,5,6 3:1,2,7,8 4:3,4,5,6 5:3,4,7,8 6:5,6,7,8"; rshard() { { printf '# Code Review shard %s\n\nreviewed-sha: %s\nshard-verdict: APPROVED\n\n' "$2" "$SHA"; printf '## Findings\n\n### Critical (must fix before merge)\n\n#### F-%s-1 x\nparts: %s\n\nBody.\n\n' "$2" "$3"; [ -n "${4:-}" ] && printf '%s\n\n' "$4"; printf '### Important (should fix, can be follow-up)\n\n### Suggestions (optional improvements)\n'; } > "$1/$2.md"; }; D="$X/w/1-code-review-$S12"; rbuild() { local k; rm -rf "$X/w"; mkdir -p "$X/w"; bash "$SD"/partition-review-diff.sh --map "$R" "$BASE" "$SHA" --min-files 4 --max-parts 8 --shard-dir "$D" > "$X/w.map" 2>&1 < /dev/null || return 1; [ "$(grep -c '^part' "$D/.manifest")" = 8 ] || return 1; for k in $(cut -f1 "$X/w.map"); do rshard "$D" "$k" "$k"; done; }; rxg() { local r g gl; for r in $XGROUPS; do g="${r%%:*}"; gl="${r#*:}"; if [ "$g" = 3 ] || [ "$g" = 1 ]; then rshard "$1" "cross-$g" "${gl%%,*}, ${gl##*,}" "${2:-}"; else rshard "$1" "cross-$g" "${gl%%,*}, ${gl##*,}"; fi; done; }; rmerge() { AI_DLC_PROJECT_ROOT="$PROJ" bash "$SD"/merge-review-shards.sh "$D" --gate code-review --out "$X/w/1-code-review.md" > "$X/w.out" 2>&1 < /dev/null; echo $?; }; A=bad; B=bad; C=bad; rbuild && { rxg "$D"; rc="$(rmerge)"; [ "$rc" = 0 ] && grep -q '^MERGED:' "$X/w.out" && A=ok; }; rbuild && { rshard "$D" cross "1, 8"; rc="$(rmerge)"; [ "$rc" = 2 ] && grep -qF 'a single cross shard is owed only at K=2' "$X/w.out" && [ ! -e "$X/w/1-code-review.md" ] && B=ok; }; rbuild && { rxg "$D" "$(printf '#### F-dup an interaction\nparts: 1, 2\n\nBody.')"; rc="$(rmerge)"; [ "$rc" = 2 ] && grep -qF 'a finding owned by cross-1 (partition-document.sh --cross-owner)' "$X/w.out" && [ ! -e "$X/w/1-code-review.md" ] && C=ok; }; [ "$A$B$C" = okokok ] || { echo "ARM8 STILL LIVE -- A=$A B=$B C=$C"; exit 1; }; exit 0 ); r8=$?; [ "$r8" -eq 9 ] && exit 9; [ "$r8" -eq 0 ] || F=$((F + 100000)); [ "$F" -eq 0 ]
