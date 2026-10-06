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
347s. The sandbox read-set trace for both fixtures is owed by the lead, not yet committed.

**Remedy.** Per fixture: measure solo, attribute the time, then cut it — move a mutation battery behind a shipped
fixture into its own `.dist-only` fixture (`fixture-ship-decl.md`), score mutants in parallel within the fixture, and
remove repeated setup. `review-shard-merge` is being split in batch 199 as the first instance.

verify: manual -- the subject is wall clock on a loaded box, which no in-tree receipt can measure; close on a solo
re-measurement of each named fixture recorded in the closing entry.

## BL-458 — the requirements step's validation cycle is never sharded over its subject, so the PRD is reviewed alone and the brief, SPEC and architecture-impact never are

**DEFECT.** Carries the reference consumer's PC-S317-REQUIREMENTS-STEP-CYCLE-IS-NEVER-SHARDED-BECAUSE-ITS-SUBJECT-IS-THREE-FILES-AND-THE-PRD-IS-CUMULATIVE.
The requirements step reviews the product brief, the spec kernel, `prd.md` and `s<N>/architecture-impact.md` as one
subject, and Rule 28 had no axis for a multi-file subject, so every sub-pass ran one agent per seat. The consumer's s317
series shows the workaround: its pass 2 is a `--document prd.md` section merge filed as `requirements-adversarial-p2`,
so the cumulative PRD was sectioned whole and the other three files were reviewed by nobody. The remedy is the subject
axis: `partition-subject.sh` maps the four files over what changed since one base recorded in
`s<N>/requirements-subject.md`, `merge-adversarial-shards.sh --subject` and `join-remediator-shards.sh --subject`
join every sub-pass, and Check 24 arm K3 holds the requirements series to that shape.

**Residual, not closed by this entry.** B4 makes `--document` refuse a shard dir named `requirements-p<M>`, so subject
mode is the only writer of `requirements-adversarial-p<M>`. A series under any other stem — `prd-adversarial-p<M>`,
written by a `--document prd.md` merge — is not a requirements series to K3 and is judged by K2 alone, so a lead that
names its series `prd-*` escapes the subject axis. Closing that needs the step to own the series name in a way a
validator can read, which no gate does today.

verify: sh [ -f core/fixtures/subject-partition/receipt.sh ] || exit 9; bash core/fixtures/subject-partition/receipt.sh "$PWD"

## BL-452 — pre-push never traces the unmapped fixtures it runs, so they stay unmapped and run on every push

**DEFECT.** Filed in batch 199 on the operator's direction ("close the cycle"). A fixture with no row in
`.ai-dlc-fixture-readsets.tsv` runs on every push, and nothing maps it unless a session hand-runs the deriver. Supersedes
`BL-375`'s stage 1, closed by ruling in the same batch. Design and two adversary rounds: the contract is quoted
verbatim in the batch-199 record of `docs/plans/graph-ledger-full-drain.md` (or its archive once rotated). In short: after a green suite, both hooks start one detached, unprivileged `derive-fixture-readsets.sh --tracer sandbox`
run for the unmapped fixtures and record clean traces in a local map under git-common-dir, keyed on the hash of every
recorded path and of the deriver. Measured: per-fixture `FXTAG` profile tags attribute concurrent reports with zero
cross-attribution, drops are system-wide, and silent loss requires a private tree copy so the atime canary can run.

**Receipt.** Behavioural, in both hooks. It extracts each hook's FIXTURE_POOL block into a fresh repository whose one fixture passes and whose deriver is a stub that records its argv, runs `run_fixtures`, and requires the stub to have run with `--list u --tracer sandbox --local-map .git/ai-dlc-fixture-readsets.local`, and NOT to have run under `AI_DLC_READSET_LIVE_TRACE=0`. Exits 9 when the suite in that world is not green or the trace tools are absent. Scored under `bash -c 'set -uo pipefail; ...'`: the fixed tree 0; base `d6e25229` 1; the call site deleted from both hooks 1; the knob defaulting off 1; either hook alone carrying the change 1; an empty tree 9.

verify: sh unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY; for v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$v"; done; command -v sandbox-exec >/dev/null 2>&1 && [ -x /usr/bin/log ] && command -v python3 >/dev/null 2>&1 || exit 9; W="$(mktemp -d)" || exit 9; W="$(cd "$W" && pwd -P)" || exit 9; lt() { H="$1"; K="$2"; D="$W/$3"; [ -f "$H" ] || exit 9; mkdir -p "$D/w" && sed -n '/# FIXTURE_POOL_BEGIN/,/# FIXTURE_POOL_END/p' "$H" > "$D/pool.sh" || exit 9; [ -s "$D/pool.sh" ] || exit 9; F="$(sed -n 's|^[[:space:]]*for d in \([A-Za-z0-9_./-]*\)/\*/;.*|\1|p' "$D/pool.sh" | sort -u)"; [ "$(printf '%s\n' "$F" | grep -c .)" -eq 1 ] || exit 9; mkdir -p "$D/w/$F/u" "$D/w/core/scripts" || exit 9; printf '#!/bin/bash\necho "  ok    u"\n' > "$D/w/$F/u/run.sh"; printf '#!/bin/bash\nprintf "%%s\\n" "$*" > "%s/ran"\n' "$D" > "$D/w/core/scripts/derive-fixture-readsets.sh"; ( cd "$D/w" && git init -q . && git add -A && git -c user.email=r@r -c user.name=r commit -qm seed ) >/dev/null 2>&1 || exit 9; ( cd "$D/w" || exit 1; [ "$K" = off ] && export AI_DLC_READSET_LIVE_TRACE=0; . "$D/pool.sh" >/dev/null 2>&1; run_fixtures > "$D/out" 2>&1; echo "$?" > "$D/rc" ); [ "$(cat "$D/rc" 2>/dev/null)" = 0 ] || exit 9; grep -q 'ok    u' "$D/out" || exit 9; i=0; while [ "$i" -lt 100 ] && { [ -d "$D/w/.git/ai-dlc-fixture-readsets.local.lock" ] || { [ "$K" = on ] && [ ! -f "$D/ran" ]; }; }; do sleep 0.1; i=$((i+1)); done; if [ ! -f "$D/ran" ]; then V=no; elif grep -qx -- '--list u --tracer sandbox --local-map .git/ai-dlc-fixture-readsets.local' "$D/ran"; then V=yes; else V=bad; fi; }; for h in .githooks/pre-push core/git-hooks/pre-push; do n="${h%%/*}"; n="${n#.}"; lt "$h" on "$n.on"; [ "$V" = yes ] || exit 1; lt "$h" off "$n.off"; [ "$V" = no ] || exit 1; done

## BL-453 — teammate verification calls are ad-hoc compound shell that no allow rule matches, so an unattended sprint stops for approval

**DEFECT.** Carries the reference consumer's PC-S317-TEAMMATE-VERIFICATION-COMMANDS-ARE-AD-HOC-COMPOUND-SHELL-THAT-NO-ALLOW-RULE-MATCHES-SO-THEY-STOP-FOR-APPROVAL.
A teammate confirming a claim writes a `bash -c` wrapper, a function definition, or a chain of variable assignments
joined by `;`/`&&`. None of those matches a command-prefix allow rule, so each one raises an approval prompt, and in an
unattended sprint nobody is there to answer it. The filing's census counted 38 wrapper-shape calls in 840 (a function
definition or `bash -c`); remediator 30/290, adversary 3/525.

**Fix (option 1 of the filing).** One byte-identical paragraph in every file matching `core/team-roles/*.md`, the glob
`install.sh` copies, opening `**Verify with one read-only command per Bash call.**`: confirm a claim with a `derived`
fence replayed by one `scripts/ai-dlc/validate-artifact-derivations.sh` call, or with one read-only command in its own
Bash call. Invariant `I121` binds it: present exactly once in every role file as its own paragraph, byte-identical,
no copy elsewhere, and the validator path resolving to `core/scripts/validate-artifact-derivations.sh`.

**Done when, consumer side, owed as residue and not held open here.** On the first consumer sprint after a pull that
carries this text, re-run the filing's census over that sprint's subagent transcripts (wrapper-shape calls: a function
definition or `bash -c`), against the before figures above. Options (2)-(4) of the filing are weighed only if the rate
stays high. That census is recorded as owed residue in the CHANGELOG at release; the receipt below closes on the text.

verify: sh set -- core/team-roles/*.md; [ -f "$1" ] || exit 9; awk -v n="$#" -v op='**Verify with one read-only command per Bash call.**' -v fp='`scripts/ai-dlc/validate-artifact-derivations.sh <that file>`' 'function chk() { if (w != 1 || s != 1 || !p) bad++ } FNR == 1 { if (nf++) chk(); w = 0; s = 0; p = 0; at = 0; pr = "" } { if (index($0, op)) s++; if (index($0, op) == 1 && pr == "") { w++; at = FNR } if (at && FNR - at <= 7 && index($0, fp)) p = 1; pr = $0 } END { if (nf) chk(); if (nf != n) bad++; exit (bad ? 1 : 0) }' "$@"

## BL-454 — the lead and its teammates never consult the advisor tool, even when the harness supplies one

**DEFECT.** Carries the reference consumer's PC-S317-CONSULT-THE-ADVISOR-TOOL-AT-NAMED-TOUCHPOINTS-IN-THE-LEAD-AND-IN-ROLE-CONTRACTS-WHEN-IT-IS-AVAILABLE.
Core named `advisor` nowhere, while subagents on the reference consumer have carried the tool since it arrived (every
remediator transcript in that era). Neither the lead nor any role contract told an agent to call it, so a stronger
reviewer sat unused through post-compact recovery, gates, repair loops and pushes. Measured call cost: lead median 94s,
max 176s, 4 of 14 over 150s; subagent median 116s, max 295s. Check A of `validate-steering-budget.sh` read no server-side
tool at all, so those calls were never measured either.

**Fix.** SKILL.md Rule 32 names the lead's touchpoints (R, G1, G2, V1, V2, P, I) with the degrade clause in its opening
paragraph, and the postcompact digest carries it; one-line cites at each step-file site. The recover hook is
unchanged: touchpoint R reaches a compacted lead through the digest, because a hook line naming it pushed measured
consumer recoveries past the 10000-character stub cliff (`BL-457`). Every file matching `core/team-roles/*.md` carries one byte-identical paragraph opening
``**Consult the `advisor` tool when it is available.**``, bound by `I122`; no renderer change, because a rendered line
would read DRIFTED at a consumer's self-update gate. Check A reads `server_tool_use` / `*_tool_result` pairs and
exempts `advisor` by name; every other server tool is still charged.

**Done when, consumer side, owed as residue and not held open here.** After a pull carrying this, the consumer
re-renders `.claude/agents/` only if its own render inputs moved (they do not here), and the first sprint's lead
transcripts show advisor calls at the named touchpoints. The receipt below closes on the text.

verify: sh set -- core/team-roles/*.md; [ -f "$1" ] || exit 9; awk -v n="$#" -v op='**Consult the `advisor` tool when it is available.**' 'function chk(  b) { b = tolower(j); if (k != 1 || !index(b, "call it") || !index(b, "`advisor`") || !index(b, "available") || index(b, "never") || index(b, "do not call") || index(b, "must not") || index(b, "don\047t")) bad++ } FNR == 1 { if (nf++) chk(); k = 0; on = 0; j = ""; pr = "" } { if (index($0, op) == 1 && pr == "") { k++; on = 1 } if (on) { if ($0 == "") on = 0; else j = j " " $0 } pr = $0 } END { if (nf) chk(); if (nf != n) bad++; exit (bad ? 1 : 0) }' "$@" && h="$(grep -E '^### Rule [0-9]+ -- .*advisor' core/skills/ai-dlc/SKILL.md | head -n 1)" && [ -n "$h" ] && awk -v h="$h" 'index($0, "<!-- BEGIN GENERATED: postcompact-digest") == 1 { g = 1 } index($0, "<!-- END GENERATED: postcompact-digest") == 1 { g = 0 } g && $0 == h { f = 1 } END { exit (f ? 0 : 1) }' core/skills/ai-dlc/postcompact-digest.md

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

## BL-455 — arm H accepts any `*-repair-p<M>.md`, so another repair's record satisfies a series' pass M

**DEFECT.** Found in batch 200 while adjudicating
PC-S317-REQUIREMENTS-STEP-CYCLE-IS-NEVER-SHARDED-BECAUSE-ITS-SUBJECT-IS-THREE-FILES-AND-THE-PRD-IS-CUMULATIVE.
`core/scripts/validate-adversarial-convergence.sh` arm H looked for the repair record of pass M with the glob
`<dir>/*-repair-p<M>.md`. Any structured record for pass number M in the sprint directory satisfied it, including a
party-round repair, a gate repair, or a record belonging to another series. As a result, a series whose own repair
was done inline passed on a neighbour's record. The name `_gate-procedures.md` prescribes, and
`join-remediator-shards.sh` writes, is `<artifact>-repair-p<M>.md`.

**Measured on the reference consumer** (a scratch clone at 0.730.0, the working-tree `_bmad-output/` copied over it,
109 series, base and tip validators side by side). 36 pass-pairs in 27 series are satisfied only by a
differently-named record. Examples are s309 `coe-adversarial-p1` by `architecture-adversarial-repair-p1.md`, s307
`prd-adversarial-p1` by `carry-over-evaluation-advanced-elicitation-repair-p1.md`, and s302 `product-brief-adversarial-p1`
by `architecture-repair-p1.md`. With the fix, every one of them reads `PENDING (H -- REPAIR-RECORD)`, because no
commit there stamps the release. No exit code changes on any of the 109 series.

**What the fix does not close.** The s317 instance that surfaced this is not reachable by the name rule.
`s317/requirements-repair-p1.md` sits at the series' own stem name but records the requirements PARTY round, so
the stem-named record satisfies requirements pass 1. That instance closes only when party and elicitation repair
records are renamed outside `*-repair-p<M>.md` (`requirements-party-repair.md`, `requirements-elicitation-repair.md`),
which belongs to the requirements-subject release.

**Remedy (this release).** Arm H requires exactly `<stem>-repair-p<M>.md`, where the stem is the pass name before its
last `p<N>`/`pass<N>` token with one trailing `-adversarial` removed. The requirement sits behind `H_RELEASE`, a stamp
keyed on the series' first pass as for K, K2 and J2, so a legacy series reads PENDING rather than FAIL. Fixture:
check-24's `h-worlds` cells and four mutants.

verify: sh bash -c 'v=core/scripts/validate-adversarial-convergence.sh; [ -f "$v" ] || exit 9; d=$(mktemp -d) || exit 9; mkdir -p "$d/.claude" && echo "version: 9.0.0" > "$d/.claude/.ai-dlc-version" || exit 9; (unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; cd "$d" && git init -q . && git add .claude && GIT_COMMITTER_DATE=2026-01-01T00:00:00Z GIT_AUTHOR_DATE=2026-01-01T00:00:00Z git -c user.email=r@x.invalid -c user.name=r -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q -m s) || exit 9; for n in 1 2; do vd=EXIT_CONDITION_NOT_MET; m=3; [ "$n" = 2 ] && vd=EXIT_CONDITION_MET && m=0; printf -- "<!-- SKILL_INVOCATION_PROVENANCE v1\ninvoked_at: 2026-01-0%sT00:00:00Z\nfindings_critical: 0\nfindings_major: %s\nverdict: %s\nSKILL_INVOCATION_PROVENANCE_END -->\n" "$((n + 1))" "$m" "$vd" > "$d/prd-adversarial-p$n.md"; done; r="- disposition: repaired\n- edit: prd.md:1\n- derivation: n/a\n"; printf -- "$r" > "$d/arch-repair-p1.md"; o=$(bash "$v" --series "$d/prd-adversarial-p" 2>&1); rc=$?; [ "$rc" = 1 ] && grep -qF "The only structured record for pass 1 is arch-repair-p1.md" <<<"$o" || exit 1; printf -- "$r" > "$d/prd-repair-p1.md"; bash "$v" --series "$d/prd-adversarial-p" >/dev/null 2>&1'

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
