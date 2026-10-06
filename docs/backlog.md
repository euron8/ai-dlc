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
| a second correct spelling (today's gate, argv by `sed` of the last hook line, siblings staged, root set) | 0 |

The receipt exits 9 if a precondition moves. That includes any of its three anchors changing: the renderer's body text
`FIRST action before any other work`, its comment `# --check NEVER WRITES, so it is safe`, and the provenance
validator's single `if strays:` line.

verify: sh G=core/skills/ai-dlc-update/reconcile/self-update-gate.sh; R=core/scripts/render-agent-definitions.sh; P=core/scripts/validate-provenance-block.sh; H=core/git-hooks/pre-push; K=core/schemas/provenance-block.json; [ -f "$G" ] && [ -f "$R" ] && [ -f "$P" ] && [ -f "$H" ] && [ -f "$K" ] || exit 9; command -v jq >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 || exit 9; grep -q 'FIRST action before any other work' "$R" && grep -q '^# --check NEVER WRITES, so it is safe' "$R" && [ "$(grep -c '^if strays:$' "$P")" = 1 ] || exit 9; W="$(mktemp -d)" || exit 9; sw() { D="$W/$1"; S="$D/c/scripts/ai-dlc/$2"; N="$D/d/core/scripts/$2"; mkdir -p "$D/d/core/scripts" "$D/c/scripts/ai-dlc" "$D/c/.githooks" "$D/c/.claude/schemas" || exit 9; git -C "$D/d" init -q || exit 9; cp "$R" "$P" "$D/d/core/scripts/" && cp "$R" "$P" "$D/c/scripts/ai-dlc/" && cp "$H" "$D/c/.githooks/pre-push" && cp "$K" "$D/c/.claude/schemas/" || exit 9; printf '0.1.0\n' > "$D/d/VERSION"; printf '{"aiDlcRoles":{"dev":{"model":"m"}},"aiDlcModels":{"m":"claude-x"}}\n' > "$D/c/.claude/settings.json"; bash "$R" --root "$D/c" >/dev/null 2>&1 || exit 9; [ "$3" = drift ] && printf 'drift\n' >> "$D/c/.claude/agents/dev.md"; git -C "$D/d" add -A && git -C "$D/d" -c user.name=r -c user.email=r@r commit -qm base || exit 9; sed "$4" "$S" > "$N"; cmp -s "$S" "$N" && exit 9; printf '0.2.0\n' > "$D/d/VERSION"; git -C "$D/d" -c user.name=r -c user.email=r@r commit -qam theirs || exit 9; HC="$( cd "$D/c" && AI_DLC_PROJECT_ROOT="$D/c" bash "$S" $5 >/dev/null 2>&1; echo $? )"; HN="$( cd "$D/c" && AI_DLC_PROJECT_ROOT="$D/c" bash "$N" $5 >/dev/null 2>&1; echo $? )"; A0="$(cat "$D/c/.claude/agents/"* | cksum)"; bash "$G" "$D/d" "$(git -C "$D/d" rev-parse HEAD~1)" "$(git -C "$D/d" rev-parse HEAD)" "$D/c" > "$D/out" 2>/dev/null; [ -s "$D/out" ] || exit 9; [ "$A0" = "$(cat "$D/c/.claude/agents/"* | cksum)" ] && AG=same || AG=moved; }; rf() { n="$(grep -cE "^SELF-UPDATE-(DEFER|UNDECIDED).$2" "$W/$1/out")" || n=0; printf '%s' "$n"; }; ok() { n="$(grep -cE "^SELF-UPDATE-OK.$2" "$W/$1/out")" || n=0; printf '%s' "$n"; }; sw body render-agent-definitions.sh clean 's/FIRST action before any other work/FIRST action, before any other work/' '--check --root .'; [ "$HC$HN" = 01 ] || exit 9; AB="$AG"; sw benign render-agent-definitions.sh clean 's/^# --check NEVER WRITES, so it is safe/# --check NEVER WRITES; it is safe/' '--check --root .'; [ "$HC$HN" = 00 ] || exit 9; sw drift render-agent-definitions.sh drift 's/^# --check NEVER WRITES, so it is safe/# --check NEVER WRITES; it is safe/' '--check --root .'; [ "$HC$HN" = 11 ] || exit 9; sw strays validate-provenance-block.sh clean 's/^if strays:$/if strays or candidates:/' '--strays'; [ "$HC$HN" = 01 ] || exit 9; [ "$(rf body render-agent-definitions)" -ge 1 ] && [ "$AB" = same ] && [ "$(rf benign '')" -eq 0 ] && [ "$(ok benign render-agent-definitions)" -eq 1 ] && [ "$(rf drift '')" -eq 0 ] && [ "$(ok drift render-agent-definitions)" -eq 1 ] && [ "$(rf strays validate-provenance-block)" -ge 1 ]

