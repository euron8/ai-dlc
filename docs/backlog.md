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

**Candidate fixes.** (a) Run each hook-named script with the hook's own argv, derived from the hook line that invokes it,
so the differential asks the hook's question. That edits `self-update-gate.sh`, which is a bootstrapping file. A consumer
runs the gate it already has, so (a) reaches a consumer only after one pull and must ship alone, machinery-only.
(b) Make the consumer hook re-render when the only difference is the rendered body, so a renderer body change cannot
refuse the push.

**Receipt.** It builds two mktemp worlds and drives the real gate in each. In the first, the incoming renderer changes
only rendered body text, and the receipt asserts that the hook's `--check --root .` arm really goes 0 to 1 there. In the
second, the incoming renderer changes only a comment, and the receipt asserts that the hook's arm stays at 0. The receipt
exits 0 only when the gate refuses (DEFER or UNDECIDED) the first world on `render-agent-definitions.sh` AND answers OK,
with no refusal, on the second. Scored under `bash -c 'set -uo pipefail; …'` on scratch copies of this tree: current
tree 1; a gate that turns equal non-zero codes into UNDECIDED 1 (it refuses the benign control too); a gate that passes
`--root "$CONSUMER"` with no `--check` 1 (write mode exits 0 on both sides, so it is still OK); a prototype of (a) that
passes `--check --root .` when the hook names it 0. The receipt exits 9 if a precondition moves. That includes either of
its two renderer anchors changing: the body text `FIRST action before any other work` and the comment
`# --check NEVER WRITES, so it is safe`.

verify: sh G=core/skills/ai-dlc-update/reconcile/self-update-gate.sh; R=core/scripts/render-agent-definitions.sh; H=core/git-hooks/pre-push; [ -f "$G" ] && [ -f "$R" ] && [ -f "$H" ] || exit 9; command -v jq >/dev/null 2>&1 || exit 9; grep -q 'FIRST action before any other work' "$R" || exit 9; W="$(mktemp -d)" || exit 9; sw() { D="$W/$1"; N="$D/d/core/scripts/render-agent-definitions.sh"; mkdir -p "$D/d/core/scripts" "$D/c/scripts/ai-dlc" "$D/c/.githooks" "$D/c/.claude" || exit 9; git -C "$D/d" init -q || exit 9; cp "$R" "$N" && cp "$R" "$D/c/scripts/ai-dlc/render-agent-definitions.sh" && cp "$H" "$D/c/.githooks/pre-push" || exit 9; printf '0.1.0\n' > "$D/d/VERSION"; printf '{"aiDlcRoles":{"dev":{"model":"m"}},"aiDlcModels":{"m":"claude-x"}}\n' > "$D/c/.claude/settings.json"; bash "$R" --root "$D/c" >/dev/null 2>&1 || exit 9; git -C "$D/d" add -A && git -C "$D/d" -c user.name=r -c user.email=r@r commit -qm base || exit 9; sed "$2" "$R" > "$N"; cmp -s "$R" "$N" && exit 9; printf '0.2.0\n' > "$D/d/VERSION"; git -C "$D/d" -c user.name=r -c user.email=r@r commit -qam theirs || exit 9; ( cd "$D/c" && bash "$N" --check --root . >/dev/null 2>&1 ); HRC=$?; bash "$G" "$D/d" "$(git -C "$D/d" rev-parse HEAD~1)" "$(git -C "$D/d" rev-parse HEAD)" "$D/c" > "$D/out" 2>/dev/null; [ -s "$D/out" ] || exit 9; }; sw body 's/FIRST action before any other work/FIRST action, before any other work/'; [ "$HRC" -eq 1 ] || exit 9; sw benign 's/^# --check NEVER WRITES, so it is safe/# --check NEVER WRITES; it is safe/'; [ "$HRC" -eq 0 ] || exit 9; b="$(grep -cE '^SELF-UPDATE-(DEFER|UNDECIDED).render-agent-definitions' "$W/body/out")" || b=0; k="$(grep -cE '^SELF-UPDATE-(DEFER|UNDECIDED)' "$W/benign/out")" || k=0; o="$(grep -cE '^SELF-UPDATE-OK.render-agent-definitions' "$W/benign/out")" || o=0; [ "$b" -ge 1 ] && [ "$k" -eq 0 ] && [ "$o" -eq 1 ]

