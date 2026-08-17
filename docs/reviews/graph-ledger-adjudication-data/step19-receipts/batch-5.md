# Step 19 batch 5 — replacement receipts for the `push_candidate: true` extension roster

Pinned ledger md5 `2fd444dcf406cdff728fe3c0c4352267` over the first 4356 lines — **verified**, with
the 4355-line control differing (`d4e39a96a33c5c92adfe4c8457020064`).

Adjudicated against `/Users/n8/git/ai-dlc` at HEAD `2db4035`, branch `ai-dlc/graph-ledger-drain`.

**Re-verified after HEAD moved.** Another session advanced the branch `2db4035` → `e95dcce` while
this ran. All four receipt subjects are byte-identical across that range — `gate-validation.md`
`c7c6429d`, `deploy-validate.md` `deb0c0a8`, `retro.md` `e76a3322`, `implementation.md` `e029c190`
at both revs — and `git diff --numstat 2db4035..e95dcce -- core/skills/ai-dlc/steps/` returns 0 rows
against a whole-tree control of 14 rows in the same range. Every receipt below was re-run as
shipped at `e95dcce` and returned the identical exit code.
All four pins are roster bullets carrying **no directive**, so each OLD fence holds the
no-directive line verbatim.

Polarity taken from the emitter, `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:1017-1021`:
rc 0 → `STILL-LIVE`, rc 126/127 → `NEEDS-REVIEW`, any other non-zero → `CLOSE-CANDIDATE`. Every
receipt below is written to exit 0 while the roster line is still a pushable lead.

**Two facts these four receipts are shaped around.** The engine execs
`bash -c "cd \"$CONSUMER\" && { $rest; }"` (`:1014-1015`) while this program's runner execs
`( cd "$DIST" && eval … )`, so every receipt resolves through `git -C "$DIST"` and absolute
`$CONSUMER/…` paths and reads nothing from the cwd. Each was measured at **both** cwds and
returned the identical exit code in all twelve runs recorded below.

`layer-drift.sh` was not used as an oracle anywhere in this batch — its `EXTENSION-OK` arm compares
base..theirs only, and three of these four bullets turn out to name blocks absorbed upstream
*before* `BASE=adec9ae`, which is exactly the case that arm cannot see.

---

## Pin 226 — `extensions/checks/gate-validation-push.md`

**Re-derivation.** The file is present at `$CONSUMER/.claude/skills/ai-dlc/extensions/checks/gate-validation-push.md`, 168 lines, and `grep -oE '^### [0-9]+[a-z]*'` over it yields exactly `902s 903a 914 918 921` against a control of 5 total `^### ` headings in the same invocation — so the bullet's roster member **"7 (non-vacuous artifact assertion)" names a section that does not exist in the file**, the same defect the entry body already records for `"Check 2 (escalation pending-archive rotation)"`. That is the mechanism error; the line still holds, because four of the five real sections are unabsorbed at HEAD. `git grep -lF` over `core/` at `2db4035` returns 0 files for `rare_event` (902s), `_call_real_` (903a's SUT-pointer convention), `spec_ambiguity` (914's canonical `hard_block_class[]` taxonomy) and `menu_skip_provenance` (921), while the same invocation's control token `hard_block_class` returns 2 files (`core/skills/ai-dlc/enforcement-map.yaml`, `core/skills/ai-dlc/steps/retro.md`) — core carries the snapshot FIELD and not the class taxonomy, which is the discrimination this receipt rests on.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: sh set -e; x="$CONSUMER/.claude/skills/ai-dlc/extensions/checks/gate-validation-push.md"; [ -f "$x" ] || exit 127; git -C "$DIST" cat-file -e "${THEIRS}:core/skills/ai-dlc/steps/gate-validation.md" || exit 127; git -C "$DIST" grep -qF -e hard_block_class "$THEIRS" -- core/ || exit 127; for t in rare_event _call_real_ spec_ambiguity menu_skip_provenance; do git -C "$DIST" grep -qF -e "$t" "$THEIRS" -- core/ || exit 0; done; exit 1
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe.** Base rc=0 at both cwds. Near-miss mutant (one arm only — `rare_event` appended to core's `gate-validation.md` in a scratch clone) rc=0, so the receipt does not flip on partial absorption. Full fix-shaped mutant (all four anchors absorbed) rc=1 at both cwds. Unresolvable-subject arms both fire: an empty `$CONSUMER` root gives 127, and deleting `core/skills/ai-dlc/steps/gate-validation.md` at theirs gives 127 rather than a close. The two trees were asserted to differ before any comparison was read — `gate-validation.md` md5 `4f654f85…` real vs `fea064a0…` mutant, with an unmutated `VERSION` identical on both sides as the control.

**Anchor shapes checked.** Quote-back: none of the four tokens can survive inside a comment recording their own removal, because a fix here ADDS them to core rather than deleting them. Invented phrasing: all four were taken from the consumer file's own text, not from the ledger's prose, and each is a machine-read key or enum value (`hard_block_class[]` member, carry-over class, wrapper-name convention, snapshot field) that a reworded absorption still has to write. Fix's own clause: the receipt reads only `core/` at theirs, so nothing the consumer-side entry says can satisfy it.

**Hesitation.** The arms are OR'd, so the line flips only when all four blocks are absorbed at once; if 902s alone lands upstream this receipt keeps reporting STILL-LIVE on a roster that is by then three-sixths stale. I judged that the correct reading of a roster bullet — it is a lead while any member is pushable — but it makes the receipt coarse. I also deliberately left **918 out of the predicate**: its own text scopes it to `server/test_*.py` + `rebalancer/tests/**` + `scripts/tests/**` and a consumer-local fixture, so no upstream absorption can ever exist for it and any anchor on it would be unfalsifiable.

## Pin 252 — `extensions/steps-domain/deploy-validate-push.md`

**Re-derivation.** File present, 233 lines. Two of the bullet's three roster members are already upstream, which is the mechanism error. (a) The deferral-justification triple: `git grep -nF EFFORT-BLOCKER` over `core/` at `2db4035` hits `core/skills/ai-dlc/steps/retro.md:386` and `:419` — core owns TRIGGER/EFFORT-BLOCKER/CONDITION, and the extension's own text cites `retro.md §4a` for it; what is NOT upstream is its attachment at the PVC, and the same token returns **0 hits** in `core/skills/ai-dlc/steps/deploy-validate.md`. Those two greps are one invocation, same token, opposite results — the control and the claim. (b) Post-smoke approval ordering is substantively upstream: `core/skills/ai-dlc/steps/deploy-validate.md:151` reads "do NOT present PVC without smoke evidence" and `:323` "After human validates:". What holds unabsorbed is Fix-Forward Cluster Accounting — `cascade-depth` and `Fix-Forward Cluster` each return 0 files across `core/`, against `smoke` returning 31 files in the same corpus as the control.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: sh set -e; x="$CONSUMER/.claude/skills/ai-dlc/extensions/steps-domain/deploy-validate-push.md"; [ -f "$x" ] || exit 127; git -C "$DIST" cat-file -e "${THEIRS}:core/skills/ai-dlc/steps/deploy-validate.md" || exit 127; git -C "$DIST" grep -qF -e EFFORT-BLOCKER "$THEIRS" -- core/skills/ai-dlc/steps/retro.md || exit 127; git -C "$DIST" grep -qF -e EFFORT-BLOCKER "$THEIRS" -- core/skills/ai-dlc/steps/deploy-validate.md || exit 0; git -C "$DIST" grep -qF -e cascade-depth "$THEIRS" -- core/ || exit 0; exit 1
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe.** Base rc=0 at both cwds. Near-miss mutant (`cascade-depth` absorbed into core's `deploy-validate.md`, the PVC triple still absent) rc=0. Full mutant (both `EFFORT-BLOCKER` at the PVC and `cascade-depth` absorbed) rc=1 at both cwds. 127 arms: empty `$CONSUMER` → 127; deleting core's `retro.md` — the control's home — → 127, so losing the control cannot read as an absorption. Sides asserted to differ first: `deploy-validate.md` md5 `a9fe9332…` real vs `760facf4…` mutant, `VERSION` identical as control.

**Anchor shapes checked.** Quote-back: `EFFORT-BLOCKER` is a slot label an absorbing edit must WRITE into `deploy-validate.md`, not a string a removal comment would carry; `cascade-depth` likewise names the rule being added. Invented phrasing: both come from the extension's own prose (`Rule (i) — Cascade-depth threshold on fix-forward PRs`, and the triple's own slot names), and `EFFORT-BLOCKER` is independently proven to be core's own vocabulary by its two `retro.md` hits. Fix's own clause: the first `EFFORT-BLOCKER` grep is file-scoped to `retro.md` and the second to `deploy-validate.md`, so core's existing retro-side wording cannot satisfy the PVC-side arm.

**Hesitation.** The PVC arm is file-scoped, so an absorption that put the PVC deferral triple in `steps/_gate-procedures.md` or in a new shared include — a relocation upstream has already done once for the auto-handoff helper — would leave this receipt reporting STILL-LIVE forever. Widening the arm to all of `core/` was not available: `EFFORT-BLOCKER` is already present there, so the wide form is vacuous in the other direction. I took the narrow form and am recording the failure mode rather than pretending it is covered.

## Pin 255 — `extensions/steps-domain/retro-push.md`

**Re-derivation.** **The file named by this bullet does not exist.** `[ -f ]` on `$CONSUMER/.claude/skills/ai-dlc/extensions/steps-domain/retro-push.md` fails, against a control listing of that directory which returns 26 entries in the same invocation. `git -C "$CONSUMER" log --oneline -M --diff-filter=D` on the path returns `9b5d408a3 chore(extensions): split retro-push into six anchored entries; anchor retro-domain (#835)` — a RELOCATION, not a retirement, and the six successors (`retro-push-branch-creation.md`, `-validator-preflight.md`, `-party-mode.md`, `-process-improvements.md`, `-sprint-ship-verification.md`, `-next-sprint-prompt.md`) are all on disk. That is the mechanism error, and it is the exact shape the brief's 127 rule exists for. The roster is stale in a second way: `dual-counter` and `Empirical gate` both hit `core/skills/ai-dlc/steps/retro.md` at `2db4035`, so the "Sprint-Ship dual-counter" and "Empirical-gate" members are upstream already, and `retro-push-process-improvements.md:11` says so itself ("Absorbed upstream at `v0.41.0`"). Unabsorbed at HEAD: the fail-fast branch-name self-check — `--abbrev-ref` returns 0 hits in core's `retro.md` while `checkout -b ai-dlc/retro` returns a hit in that same file — and the next-sprint-prompt completeness mandate, whose required literal `end of known work` returns 0 files across all of `core/`.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: sh set -e; d="$CONSUMER/.claude/skills/ai-dlc/extensions/steps-domain"; ls "$d"/retro-push*.md >/dev/null 2>&1 || exit 127; git -C "$DIST" cat-file -e "${THEIRS}:core/skills/ai-dlc/steps/retro.md" || exit 127; git -C "$DIST" grep -qF -e "checkout -b ai-dlc/retro" "$THEIRS" -- core/skills/ai-dlc/steps/retro.md || exit 127; git -C "$DIST" grep -qF -e dual-counter "$THEIRS" -- core/skills/ai-dlc/steps/retro.md || exit 127; git -C "$DIST" grep -qF -e "--abbrev-ref" "$THEIRS" -- core/skills/ai-dlc/steps/retro.md || exit 0; git -C "$DIST" grep -qF -e "end of known work" "$THEIRS" -- core/ || exit 0; exit 1
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe.** Base rc=0 at both cwds. Near-miss mutant (`--abbrev-ref` absorbed into core's `retro.md`, the terminality literal still absent) rc=0. Full mutant (both absorbed) rc=1 at both cwds. 127 arms: empty `$CONSUMER` → 127 via the successor glob; deleting core's `retro.md` at theirs → 127. Sides asserted to differ first: `retro.md` md5 `1a62c1c8…` real vs `3723e95a…` mutant, `VERSION` identical as control.

**Anchor shapes checked.** Quote-back: both anchors are additions a fix must make to core, and the `--abbrev-ref` arm is scoped to the one file that would carry it. Invented phrasing: `--abbrev-ref` is the flag the extension's own self-check command runs, and `end of known work` is a quoted literal the rule mandates the agent EMIT — neither is the ledger's paraphrase. Fix's own clause: `dual-counter` is used only as a control, never as a claim, so the two already-absorbed roster members cannot pin the entry open.

**Hesitation.** The receipt is deliberately keyed on the two members I could anchor mechanically, so it says nothing about "skill-invocation-provenance" or the `audit-rule-files` finding-classes rule, and the glob `retro-push*.md` would also be satisfied by a single leftover successor file — a partial teardown of the family would still resolve. The stronger claim, that the whole relocated family is unabsorbed, is not what this predicate measures.

## Pin 259 — `extensions/steps-domain/implementation-push.md`

**Re-derivation.** File present, 133 lines. Two of the five roster members are already upstream — the mechanism error here. `git grep -nF 'isolation: worktree'` over `core/` at `2db4035` hits `core/skills/ai-dlc/steps/implementation.md:87` with the extension's own finding ("is NOT a reliable isolation mechanism"), and `:101`/`:110` carry the `git worktree add … -b dev/sprint-<N>/story-<X>` protocol; `bug-class checklist` hits the same file at `:225`. Unabsorbed: `done-pending-liveness` — a status STRING the extension requires written verbatim into story frontmatter and both `sprint-status.yaml` views — returns 0 files across `core/`, and so does the mandated heading `Mid-Sprint Scope Re-Check`, both against the 1-file control hit for `isolation: worktree` in the same invocation.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: sh set -e; x="$CONSUMER/.claude/skills/ai-dlc/extensions/steps-domain/implementation-push.md"; [ -f "$x" ] || exit 127; git -C "$DIST" cat-file -e "${THEIRS}:core/skills/ai-dlc/steps/implementation.md" || exit 127; git -C "$DIST" grep -qF -e "isolation: worktree" "$THEIRS" -- core/skills/ai-dlc/steps/implementation.md || exit 127; git -C "$DIST" grep -qF -e done-pending-liveness "$THEIRS" -- core/ || exit 0; git -C "$DIST" grep -qF -e "Mid-Sprint Scope Re-Check" "$THEIRS" -- core/ || exit 0; exit 1
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe.** Base rc=0 at both cwds. Near-miss mutant (`done-pending-liveness` absorbed, the re-check heading still absent) rc=0. Full mutant (both absorbed) rc=1 at both cwds. 127 arms: empty `$CONSUMER` → 127; deleting `core/skills/ai-dlc/steps/implementation.md` at theirs → 127 measured on the mutant clone, so a relocation of core's implementation step cannot read as an absorption. Sides asserted to differ first: `implementation.md` md5 `a1a51c72…` real vs `eaced73b…` mutant, `VERSION` identical as control.

**Anchor shapes checked.** Quote-back: both anchors are strings a fix ADDS to core; neither could survive as the residue of a deletion. Invented phrasing: `done-pending-liveness` is a status value the consumer's own route/retro consistency check compares verbatim, and `Mid-Sprint Scope Re-Check` is the literal heading the rule requires the paragraph to sit under — a reworded absorption still has to write both, because both are compared as strings by the machinery that consumes them. Fix's own clause: the control token is a member the entry no longer needs to push, so it can never satisfy either claim arm.

**Hesitation.** The `status-consistency-after-gate-1` member is unrepresented, because its whole mechanism is `scripts/ai-dlc-local/validate-story-status-consistency.sh`, a consumer-local script upstream has no counterpart for — an anchor on it would report STILL-LIVE forever. So this receipt covers two of five named members and is silent on a third that may not be pushable at all.
