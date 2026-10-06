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

## BL-451 — the six slowest fixtures take 29 to 41 minutes loaded each, and five of the six ship to consumers

**DEFECT.** Filed in batch 199 on the operator's direction that these wall clocks are not acceptable. Loaded costs in
`$(git rev-parse --git-common-dir)/ai-dlc-fixture-durations` at filing: `apply-self-overwrite` 2463s,
`apply-setup-sited-merge` 2430s, `self-update-fixture-log` 2425s, `remediator-shard-join` 2420s,
`backlog-receipt-binding` 2166s, `review-shard-merge` 1738s — six fixtures, the minimum 1738s (29 min). These are
LOADED figures and some may carry a laptop sleep (batch 198 recorded a 2608s gate run in transit); each must be
re-measured solo in a clean worktree before it is cut. Only `backlog-receipt-binding` is `.dist-only`; the other FIVE
ship, so the reference consumer pays them on every push that selects them.

**Measured cause, on one of them.** `review-shard-merge` went from 731s to 1738s across batch 199. Its `score()` runs
every predicate for every mutant (arms × mutants), and the batch added arms and mutants to both factors. The same shape
is likely behind the mutation-battery fixtures above (`self-update-fixture-log` 35 mutation sites,
`remediator-shard-join` 10, `apply-self-overwrite` 8). `apply-setup-sited-merge` is NOT mutation-free: it carries 24
`kill_if` mutants, already launched through a pool of 8 (`POOL=8` at its `launch()`), so serial scoring is not its
cause and its time is still unattributed.

**Progress — first instance, `review-shard-merge` (batch 200; entry stays open for the other five).** Its 71 arms stay
in the shipped fixture; the predicates and worlds moved to `core/fixtures/review-shard-merge/lib.sh` (ships beside it);
MX0 and the 51 mutants moved to the new `.dist-only` `review-shard-merge-mutants`, which sources the same `lib.sh` and
scores in a fixed pool of 8 with per-scorer scratch, a verdict-count reap, a 900s watchdog and an in-fixture probe of
its own judgment. Per-mutant killed sets were compared byte-for-byte against the unsplit serial battery.
Solo, clean worktrees, interleaved, 2 reps, box shared with other sessions (load 4-30 during the
old side): the unsplit fixture 2537s / 2476s; the shipped fixture after the split 42s / 40s; the new battery 358s /
347s. The shipped fixture is traced and mapped. `review-shard-merge-mutants` is still OMITTED from
`.ai-dlc-fixture-readsets.tsv` (0 rows, against 65 for `review-shard-merge`), so it runs on every push until a trace maps it.

**Remedy.** Per fixture: measure solo, attribute the time, then cut it — move a mutation battery behind a shipped
fixture into its own `.dist-only` fixture (`fixture-ship-decl.md`), score mutants in parallel within the fixture, and
remove repeated setup. `review-shard-merge` is being split in batch 199 as the first instance.

verify: manual -- the subject is wall clock on a loaded box, which no in-tree receipt can measure; close on a solo
re-measurement of each named fixture recorded in the closing entry.

## BL-457 — the recover hook measures `degraded` before the provenance wrap, so a stubbed block reports `degraded=no`

**DEFECT.** Filed in batch 200 by the 0.732.0 tip adversary. `core/hooks/ai-dlc-recover.sh` sets `degraded` from
`${#CONTEXT}` against the 10000-character cliff, then `ai_dlc_provenance_wrap` prepends the provenance tag (about 129
characters) to the string it actually emits. A block emitted at 10000-10128 characters is replaced by the harness with a
file stub, while `.recover-fired` records `degraded=no` and `injected_bytes` below the cliff, so `ai-dlc-postcompact.sh`
reports the context as landed. The check cannot fire in exactly the band where it is needed. Measured on the
resolvable-step-file branch with a precompact sidecar and a gate nonce: a 41-character nonce emits 10066 characters and
records `injected_bytes=9937 degraded=no`; real consumer recoveries of that shape (gate-resume with a sidecar) measured
10002-10026 emitted.

**Coverage gap beside it.** No fixture seeds a precompact sidecar together with a gate nonce and bounds the emitted
length: `core/fixtures/gate-resume/run.sh` bounds length with no sidecar, and `postcompact-rulebook-recovery` seeds no
gate nonce.

**Fix.** Decide `degraded` (and record `injected_bytes`) from the string actually emitted, after the wrap, and add a
fixture arm that seeds sidecar plus nonce and asserts both the length bound and `degraded`. The receipt sweeps the nonce
length across the cliff and passes only when every world over it reports `degraded=yes` and every world under it
`degraded=no`, so reporting `yes` unconditionally, or lowering the threshold to the trim ceiling, does not close it.

verify: sh S=core/hooks/ai-dlc-recover.sh; [ -f "$S" ] || exit 9; command -v jq >/dev/null 2>&1 || exit 9; W="$(mktemp -d)" || exit 9; lo=0; hi=0; bad=0; n=0; while [ "$n" -le 80 ]; do P="$W/w$n"; mkdir -p "$P/_bmad-output" "$P/scripts/ai-dlc" "$P/.claude/skills/ai-dlc/steps" || exit 9; echo x > "$P/.claude/skills/ai-dlc/steps/implementation.md"; printf '# Pipeline Snapshot\n\n## Pipeline Position\n- **Current step file:** `implementation.md`\n' > "$P/_bmad-output/pipeline-snapshot.md"; printf 'sidecar\n' > "$P/_bmad-output/pipeline-snapshot.precompact.md"; x="$(printf '%*s' "$n" '' | tr ' ' a)"; printf '#!/bin/sh\n[ "$1" = current ] && echo g%s\n' "$x" > "$P/scripts/ai-dlc/gate-checkpoint.sh"; chmod +x "$P/scripts/ai-dlc/gate-checkpoint.sh"; L="$(printf '{"source":"compact","session_id":"receipt"}' | CLAUDE_PROJECT_DIR="$P" bash "$S" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext | length' 2>/dev/null)"; D="$(sed -n 's/^degraded=//p' "$P/_bmad-output/.recover-fired" 2>/dev/null)"; [ -n "$L" ] && [ -n "$D" ] || exit 9; if [ "$L" -ge 10000 ]; then hi=$((hi + 1)); [ "$D" = yes ] || bad=$((bad + 1)); else lo=$((lo + 1)); [ "$D" = no ] || bad=$((bad + 1)); fi; n=$((n + 5)); done; [ "$lo" -gt 0 ] && [ "$hi" -gt 0 ] || exit 9; [ "$bad" -eq 0 ]

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

## BL-459 — Rule 32's advisor touchpoints are prose only, so a lead or teammate can skip every one

**DEFECT.** Filed in batch 200 on the operator's ruling (option A: build it in a later batch). `BL-454` put the
advisor touchpoints in SKILL.md Rule 32 and in every role file, and nothing enforces them. Measured in this repo's own
sessions: the plan's bold instruction got 2 advisor calls against about 15 owed (batch 199), and a warn-only PreToolUse
hook was pushed past four times in one release (batch 200). The operator's own hook, outside the distribution, was
redesigned the same batch into the conditional deny this entry ships.

**Design.**
- Gate only actions a hook can see: first, the lead's release push and PR merge, its gate-verdict writes and its
  repair-record writes. Second, a teammate's verdict write, judged on that teammate's own
  `<session>/subagents/agent-<id>.jsonl` and never on the parent transcript.
- Any advisor ATTEMPT (`server_tool_use` named `advisor`) after the last gated action clears the deny, including an
  attempt that errors. The deny is therefore always clearable by calling the tool.
- Drop to a warning when the agent's most recent `advisor_tool_result` carries `error_code: "unavailable"`; the
  harness withdraws the tool after that. A later successful result re-arms the deny.
- **No config knob and no default** (operator ruling: a lead on a local model and teammates on Anthropic models, or any
  other mix, is normal). Whether the gate applies is decided PER AGENT from that agent's own transcript. The harness
  writes an `attachment` line of type `advisor_tool` (`available`, `toolChange`, `model`) into each session's and each
  subagent's transcript when it grants the tool. Measured over this repo's 206 session transcripts: 36 carry it and 170
  do not; 0 of the 170 contain an advisor call, and 33 of the 36 do. Every sampled value read `available: true` with
  `toolChange` `"add"` or null. The build must also handle a withdrawn grant (`available: false` or
  `toolChange: "remove"`, not yet observed), and the latest grant state wins.
- The hook decides from a file the agent can write. Deny Edit, Write and Bash redirection onto
  `~/.claude/projects/**/*.jsonl`, or an agent can delete its own grant line or append a forged `unavailable` result
  and switch the gate off.
- A branch DELETE (`git push --delete`/`-d`) is not gated.
- Cost: measured median per call is 94s for the lead and 116s for a subagent. Gate the lead's points first.

**Done when, consumer side, owed as residue.** `BL-454`'s first-sprint census of advisor calls is the before-figure;
the first sprint after this ships is the after-figure.

**Receipt.** It drives the shipped hook on seeded transcripts. A transcript carrying a grant attachment and a release
push with no advisor attempt must be denied, and the same transcript with the grant line removed must be left silent.
The build adds the remaining cases to its fixture: an errored attempt clears, `unavailable` warns, a later success
re-arms, a withdrawn grant is silent, a delete is not gated, and a transcript write is denied.

verify: sh H=core/hooks/ai-dlc-advisor-gate.sh; [ -f "$H" ] || exit 1; command -v jq >/dev/null 2>&1 || exit 9; W="$(mktemp -d)" || exit 9; g='{"type":"attachment","attachment":{"type":"advisor_tool","available":true,"toolChange":"add","model":"m"}}'; u='{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"git push origin release/9.9.9"}}]}}'; printf '%s\n%s\n' "$g" "$u" > "$W/on.jsonl"; printf '%s\n' "$u" > "$W/off.jsonl"; run() { jq -cn --arg t "$W/$1.jsonl" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:"git push origin release/9.9.9"},transcript_path:$t}' | bash "$H" 2>/dev/null | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null; }; [ "$(run on)" = deny ] && [ -z "$(run off)" ]

## BL-460 — the requirements subject drifts after a terminal MET pass with nothing to see it

**DEFECT.** Found by batch 200's contract adversary on the requirements-subject build; it predates 0.735.0. A terminal
`requirements-adversarial-p<M>` pass names the subject manifest and carries a per-stem `artifact_sha` list. Arm J2
judges only an `artifact:` that resolves to ONE regular file with one sha256, and its header lists a `<stem>=<sha>` list
as "not judged" (`core/scripts/validate-adversarial-convergence.sh`, the J2 header). Arm K3 reads a subject whose disk
sha differs from the notarized one as PENDING. So a brief, SPEC, `prd.md` or `architecture-impact.md` edited after the
series met reads PENDING forever and never FAIL, where a single-file series would fail J2. J2's header also names cumulative
documents (`prd.md`, the product brief) as outside its subject, so this gap predates 0.735.0.

**Remedy.** Teach J2 the per-stem list: every stem whose disk sha differs from its notarized sha after a MET pass needs
the same repair chain or re-open a single-file series needs, stamp-gated like K3.

verify: manual -- the subject is a judgement over a constructed requirements series; close on a check-24 cell where a
stem edited after the terminal MET pass reads FAIL (J2), with a second stem left unchanged as the control.

## BL-461 — the requirements series is named at no Check 24 call site, and a `prd-*` series escapes the subject axis

**DEFECT.** Two of batch 200's 0.735.0 tip-adversary findings and one residual from `BL-458`, one subject: the gate
text must own the requirements series' NAME.
- `gate-validation.md`'s per-sprint Check 24 sweep runs `--series` over each `s<N>/*-adversarial-p*` series "whose
  terminal pass ... names one file in `artifact:`". A subject pass names the manifest, so whether the sweep includes it
  depends on how the lead reads "one file". No step or gate text names `s<N>/requirements-adversarial-p` as a
  `--series` argument (0 hits in `gate-validation.md`, control `adversarial-p*` 1).
- A series under any other stem, such as `prd-adversarial-p<M>` written by a `--document prd.md` merge, is not a
  requirements series to K3 and is judged by K2 alone. A lead that names its series `prd-*` escapes the subject axis.

**Remedy.** Name `<planning>/s<N>/requirements-adversarial-p` explicitly at the requirements gate's Check 24 call, and
have the requirements step refuse a `prd-adversarial-p*` series in a sprint that has a subject manifest.

verify: manual -- two subjects, and a text receipt could close on the first alone; close when the requirements gate's
Check 24 call names the requirements series AND a `prd-adversarial-p*` series in a sprint with a subject manifest is refused.

## BL-462 — a party round edits one document in place from several seats and nothing attributes the writes

**DEFECT.** Found independently by two of batch 200's hands. `core/skills/ai-dlc/steps/_gate-procedures.md`'s
party-mode procedure tells the seats to "apply every improvement". Under a seats x parts or seats x sections split,
several persona agents edit the same document in place concurrently, and no join records which seat wrote which change.
A lost update between two seats is invisible, and a review of the round cannot attribute a regression to a seat. The
requirements subject case already avoids this (its seats edit nothing, and repairs join by part), which is the shape to
generalise.

verify: manual -- the subject is the party-round procedure's write model across the step files; close when every
sharded party round writes per-seat records joined by a merge, as the requirements subject case does.

## BL-463 — a reused pid holds the live-trace lock for up to six hours

**NOTE.** Found by batch 200's 0.734.0 tip adversary. `readset_lock_stale` in both pre-push hooks treats the
live-trace lock as held while `kill -0` on its recorded pid succeeds and the lock is under 21600s old. A trace killed
uncleanly whose pid is then reused by an unrelated process keeps the lock, so unmapped fixtures stay unmapped, and run,
for up to six hours. The cost is wall clock, never a wrong verdict.

verify: manual -- close when the lock records something a reused pid cannot match (the process start time) and the
hook compares it.
