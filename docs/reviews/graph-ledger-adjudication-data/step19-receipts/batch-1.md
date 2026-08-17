# Step 19 batch 1 — replacement `verify:` receipts

Pinned ledger md5 `2fd444dcf406cdff728fe3c0c4352267`, 4356 lines — **verified before any read**.
All derivations against `/Users/n8/git/ai-dlc` at committed HEAD **`e939a92`** (the tree moved
during the session; the branch tip was `95e421a` at session start). Consumer read-only at
`/Users/n8/git/graph`. Nothing was written outside this scratchpad; no commits in ai-dlc.

---

## READ THIS FIRST — THE POLARITY IN THE TASK BRIEF IS INVERTED FOR THIS LEDGER

The brief said a replacement receipt "MUST exit non-zero today (the defect is live)". That is
the **`docs/backlog.md`** grammar (`sh` exit 0 = the fix is present → CLOSE-CANDIDATE). This
batch is a **consumer push-candidate ledger**, run by
`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh`, whose `sh` verb is the **opposite**:

```
core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:29-30
#   verify: sh <one-liner>
#       Escape hatch. Runs with $DIST/$BASE/$THEIRS/$CONSUMER exported. Exit 0 = the entry
#       STILL reproduces at theirs (stays open); nonzero = it no longer does → CLOSE-CANDIDATE.
```

and the dispatch at `:1017-1019` confirms it — `0)` emits `STILL-LIVE`, the default arm emits
`CLOSE-CANDIDATE`. **A receipt written to exit non-zero today would be reported CLOSE-CANDIDATE
on its first run** — the exact data-losing verdict this step exists to prevent. All four
receipts below therefore **exit 0 today** and non-zero once fixed. This applies to the other
three batches too.

**Verified in the engine that will actually run them.** A consumer executes its OWN installed
copy, not ai-dlc HEAD, so the polarity was checked in both:

| engine | lines | md5 | `sh` rc=0 arm | 126/127 arm |
|---|---|---|---|---|
| `core/skills/…/ledger-reverify.sh` (ai-dlc HEAD) | 1177 | `2dd0fb12…` | `:1019` STILL-LIVE | `:1020` |
| `/Users/n8/git/graph/.claude/skills/…/ledger-reverify.sh` (installed) | 1116 | `b3e83588…` | `:958` STILL-LIVE | `:959` NEEDS-REVIEW |

The installed copy is 61 lines behind but **identical on this point** — same header sentence at
`:30`, same dispatch, same `cd "$CONSUMER"` + exported `DIST/BASE/THEIRS/CONSUMER` at `:953-954`.

Two further consequences of the engine that shaped every receipt here:

- `126|127` → **NEEDS-REVIEW**, not a close. Every infrastructure failure in these receipts
  (`git archive`, `tar`, a moved subject, a broken in-receipt control) exits **127**, so a
  fragile step can never fabricate a close. `receipt_absent_subjects` cannot help here: it
  resolves *consumer-relative* paths, and these receipts name `$DIST`-side refs.
- The receipt runs `bash -c "cd \"$CONSUMER\" && { $rest; }"` (`:1014-1015`), so it stands at
  the consumer root. Every path below is absolute or explicitly `$DIST`/`$CONSUMER`-anchored.

---

## Entry 1 — pin 860 · `PC-S296-REJECTION-CARRIES-UNRELATED-GAPS` · LIVE

**OLD receipt (verbatim)**

```
verify: theirs_has core/skills/ai-dlc-update/reconcile/classify-block.md "assign ONE bucket"
```

**Why it can never go green.** `assign ONE bucket` is the heading of the bucket-assignment
section. The entry's own proposed fix is an **addition** — one extra field on `domain-local`
blocks — which leaves per-block single-bucket assignment intact. The anchor is text the fix
KEEPS: anchor-failure shape 1, in its purest form.

**Re-derivation at `e939a92`.** The defect is LIVE. `classify-block.md:36-39` still reads
`Action: keep ours; note any non-conflicting upstream additions to layer around it.` with no
dependency question, and the `Return` schema (`:92-96`) carries exactly five per-block keys —
`id`, `bucket`, `action`, `needs_operator_confirmation`, `note` — none of them expressing
whether core text depends on the machinery being kept local.

**NEW receipt**

```
verify: sh f=$(git -C "$DIST" show "$THEIRS:core/skills/ai-dlc-update/reconcile/classify-block.md") || exit 127; k=$(LC_ALL=C awk "/^## Return/{r=1} r&&/^[[:space:]]+-?[[:space:]]*[a-z_]+:/{sub(/^[[:space:]-]+/,\"\");sub(/:.*/,\"\");print}" <<<"$f"); [ "$(LC_ALL=C grep -xcE "id|bucket|action|needs_operator_confirmation|note" <<<"$k")" -ge 5 ] || exit 127; [ "$(LC_ALL=C grep -vxcE "id|bucket|action|needs_operator_confirmation|note" <<<"$k")" -eq 0 ] || exit 1; s=$(LC_ALL=C awk "/^## For each block where/{p=1} /^## Whole-file case/{p=0} p" <<<"$f"); [ -n "$s" ] || exit 127; ! LC_ALL=C grep -qiE "depends|dependency|presuppos|push_candidate" <<<"$s"
```

Two independent ADD-shaped arms, either of which closes the entry, plus a self-control that
must come back ≥5 before either arm is read:

| arm | still-live condition | scope |
|---|---|---|
| schema | the per-block `Return` schema has no key outside the known five | the `## Return` fenced block |
| prose | the bucket-assignment section names no dependency test | `## For each block where …` → `## Whole-file case` |

**Measured today: rc=0** (STILL-LIVE — correct, the defect is live).

**Controls, same invocation** (`r1-arms.sh`):

```
e939a92  known-keys=5  extra-keys=0  dep-in-span=0     <- both arms quiet, control non-zero
m1a      known-keys=5  extra-keys=1  dep-in-span=0     <- schema arm fires
m1b      known-keys=5  extra-keys=0  dep-in-span=1     <- prose arm fires
```

**Two-sided probe** (fix-shaped mutants in a scratch clone; sides asserted to differ first):
base rc=0 · `m1a` (adds `core_depends_on_it: <true|false>` to the schema) rc=1 · `m1b` (adds the
dependency question to the `domain-local` bullet) rc=1. A ref with the subject absent → **rc=127**.

**What makes it pass.** Either half of the entry's own proposed change: a new per-block field,
or the dependency question written into the bucket-assignment section.

**FP narrowing recorded.** A bare `depend` matches `independent` at `classify-block.md:78`
(measured — that line is the sole whole-file hit). The pattern is therefore
`depends|dependency|presuppos|push_candidate`, and the span deliberately excludes the
`needs_operator_confirmation` section where line 78 sits.

**Anchor shapes checked.** *Fix quotes it back* — both arms are ADD-shaped, so a comment
recording the change would itself contain the added token and would (correctly) close the
entry; there is no surviving-comment failure mode. *Filing-invented phrasing* —
`push_candidate` is the filing's own word, so it is only ONE of four alternatives and never the
sole anchor; `depends` is the concept word core prose would reach for. *Word the fix's own
closing clause contains* — the receipt was run against the DEFECTIVE state and returned 0, not
against the fixed state only.

---

## Entry 2 — pin 1069 · `PC-S297-LOCKED-ANCHOR-VALIDATOR-VACUOUS` · LIVE (close withdrawn)

**OLD receipt (verbatim)**

```
verify: theirs_has core/scripts/validate-locked-anchor.sh "is never byte-matched"
```

**Why it can never go green.** It anchors on **prose inside a header comment**
(`validate-locked-anchor.sh:18`, `:451-452`, `:498-499`). A fix that starts byte-matching
`requires_context` blocks would document what it changed, and the phrase survives in that
comment — anchor-failure shape 1. The entry's own body already records that its PREVIOUS
receipt was unfalsifiable; this is the second unfalsifiable receipt on the same entry.

**Re-derivation at `e939a92` — reproduced BEHAVIOURALLY, not read off the code.**
`sources` is built from `FULL_TEXT_RE` only (`:437`); a block with no `full_text_source`
`continue`s at `:487` before `windows` is built (`:512-524`). Measured with a fabricated
requirement bullet:

```
requires_context: product-brief.md#LR-S1-ALPHA   + fabricated bullet -> PASS, rc=0
full_text_source: product-brief.md:LR-S1-ALPHA   + same bullet       -> FAIL, rc=1
```

The two sides DIFFER, and they differ by exactly the `requires_context` exemption — so the
control proves the byte-match machinery works and is not merely absent.

**NEW receipt**

```
verify: sh t=$(mktemp -d) || exit 127; git -C "$DIST" archive "$THEIRS" core/scripts >"$t/a.tar" 2>/dev/null && tar -xf "$t/a.tar" -C "$t" || { rm -rf "$t"; exit 127; }; v="$t/core/scripts/validate-locked-anchor.sh"; [ -f "$v" ] || { rm -rf "$t"; exit 127; }; printf "# Brief\n\n## LR-S1-ALPHA\n\nReal brief text.\n\n## Other\n" >"$t/product-brief.md"; printf "# S\n\n\x3c!-- LOCKED_REQUIREMENTS -->\nrequires_context: product-brief.md#LR-S1-ALPHA\n- ZZQQ-FABRICATED-REQUIREMENT-NOT-IN-THE-BRIEF\n\x3c!-- END LOCKED_REQUIREMENTS -->\n" >"$t/story-rc.md"; printf "# S\n\n\x3c!-- LOCKED_REQUIREMENTS -->\nfull_text_source: product-brief.md:LR-S1-ALPHA\n- ZZQQ-FABRICATED-REQUIREMENT-NOT-IN-THE-BRIEF\n\x3c!-- END LOCKED_REQUIREMENTS -->\n" >"$t/story-fts.md"; bash "$v" "$t/story-rc.md" >/dev/null 2>&1; a=$?; bash "$v" "$t/story-fts.md" >/dev/null 2>&1; c=$?; rm -rf "$t"; [ "$c" -eq 1 ] || exit 127; [ "$a" -eq 0 ]
```

The `\x3c` is deliberate: a literal `<!--` in a markdown ledger opens an HTML comment that
swallows the rest of the file in any rendered view. `bash` `printf` expands `\x3c`, verified
with a control (`\x7a` → `z`); the escaped and unescaped receipts were measured to behave
identically.

**Measured today: rc=0** (STILL-LIVE).

**Control, baked into the receipt:** `[ "$c" -eq 1 ] || exit 127` — the `full_text_source`
side must FAIL. If it does not, the probe is broken and the receipt reports NEEDS-REVIEW rather
than any verdict.

**Two-sided probe:** base rc=0 · mutant `m2` (feeds `REQUIRES_CTX_CITE_RE` citations into
`sources`) rc=1. The mutant was confirmed to die by the **right arm** — its output is
`requirement not byte-present at the cited anchor(s) 'product-brief.md:LR-S1-ALPHA'`, i.e. the
byte-match now fires on a `requires_context`-only block, not a crash.

**What makes it pass.** Byte-matching `requires_context` bullets against the anchor window.

**Anchor shapes checked.** All three are structurally unreachable: the receipt reads no source
text at all, so no comment a fix writes can change its verdict, and no phrasing is involved.

**⚠ HESITATION — THIS ENTRY MAY WANT RETIRING, NOT PUSHING.** Its own body says so: *"if that
exemption is correct by design, this entry should be retired rather than pushed."* Upstream
documents the exemption deliberately and gives a measured reason for it (`:496-505`: failing
`requires_context` blocks *"would red every cite-by-reference block in the repo"*). **This
receipt measures whether the exemption EXISTS; it does not adjudicate whether the exemption is
RIGHT.** That adjudication is still owed and is not something any receipt can carry. The
disposition `LIVE (close withdrawn)` is consistent with what I measured, but the open question
is a design ruling, not a defect.

---

## Entry 3 — pin 1093 · `PC-S297-CHECK16-ELEMENT2-REGEX-DEAD` · LIVE

**OLD receipt (verbatim)**

```
verify: theirs_has core/scripts/validate-stub-audit.sh "=~ ^-\ Item\ "
```

**Why it can never go green.** The substring matches BOTH element-2 conditions
(`validate-stub-audit.sh:217-218`), and a fix that WIDENS the grammar — the obvious repair,
e.g. adding `(\*\*)?` — keeps `^-\ Item\ ` intact as one alternative. The anchor survives its
own fix.

**Re-derivation at `e939a92`, against the LIVE corpus, with a control.** The consumer's real
backlog is `_bmad-output/planning-artifacts/carry-over-backlog.md` (167 143 bytes):

```
ARM      element 2's grammar  ^- Item [0-9]+.*(OPEN|IN SPRINT [0-9]+)   -> 0 matches
CONTROL  the live grammar     Item [0-9]+                               -> 1 match
         and the line is:  - **Item 452 / live-OA-2 ledger** — only live-OA-2 row open …
```

The live form is `- **Item N …**`; element 2 demands `- Item N` with no `**`. Running the
shipping script on a probe citing that item:

```
FINDING probe.sh:3 element2-item-open — Item 452 is absent from the backlog, or is not OPEN / IN SPRINT
```

— against a backlog that plainly carries Item 452. **The defect is LIVE and behavioural.**

**NEW receipt**

```
verify: sh t=$(mktemp -d) || exit 127; git -C "$DIST" archive "$THEIRS" core/scripts >"$t/a.tar" 2>/dev/null && tar -xf "$t/a.tar" -C "$t" || { rm -rf "$t"; exit 127; }; v="$t/core/scripts/validate-stub-audit.sh"; b=_bmad-output/planning-artifacts/carry-over-backlog.md; mkdir -p "$t/r/_bmad-output/planning-artifacts"; { [ -f "$v" ] && cp "$CONSUMER/$b" "$t/r/$b"; } || { rm -rf "$t"; exit 127; }; it=$(LC_ALL=C sed -n "s/^- \*\*Item \([0-9][0-9]*\).*/\1/p" "$t/r/$b" | head -1); { [ -n "$it" ] && LC_ALL=C grep -qE "^- \*\*Item ${it}[^0-9]" "$t/r/$b"; } || { rm -rf "$t"; exit 127; }; printf "#!/usr/bin/env bash\n# deferred: carry-over Item %s is still open in the backlog\n# see scripts/ai-dlc/validate-stub-audit.sh:217 for the element grammar\n# deferral-reason: waiting on the upstream element-two grammar repair\n#\n#\necho placeholder-TODO\n" "$it" >"$t/r/probe.sh"; o=$( cd "$t/r" && bash "$v" --root "$t/r" probe.sh 2>&1 ); rm -rf "$t"; case "$o" in *element1-item-ref*) exit 127;; esac; case "$o" in *element2-item-open*) exit 0;; esac; exit 1
```

The item number is **derived from the live backlog's own grammar**, never invented — the
seeded-from-what-the-reader-accepts trap. The backlog is **copied** into a temp root; the
consumer tree is only read.

**Measured today: rc=0** (STILL-LIVE).

**Controls, baked into the receipt:** (a) an item must be derivable AND re-confirmable as
`^- \*\*Item N[^0-9]` in the live file, else 127 — this is the control that contradicts the
finding's own "absent from the backlog" claim; (b) if `element1-item-ref` appears, element 1
broke and the receipt reports 127 rather than reading element 2's silence as a fix.

**Two-sided probe:** base rc=0 · mutant `m3` (element 2 widened to `^- (\*\*)?Item N`) rc=1.
Confirmed to die by the **right arm** — under `m3` the run advances past element 2 to
`element4-reason`, i.e. element 2 now ACCEPTS Item 452; it is not a crash.

**What makes it pass.** Element 2 recognising the field's `- **Item N**` form (and an
open-state test the live backlog can actually satisfy).

**Anchor shapes checked.** Behavioural, so no text a fix quotes can affect it, and no filing
phrasing is used. The old receipt's `^-\ Item\ ` — precisely the token the obvious fix KEEPS —
is not referenced.

**HESITATION.** The finding text is *"absent from the backlog, **or** is not OPEN / IN SPRINT"*.
My control establishes only the first half — the item IS present. I do not assert it is OPEN,
because the live backlog carries no `OPEN`/`IN SPRINT` token at all, which is itself part of the
defect. If a fix repairs only the openness half and leaves the `- **Item N` form unmatched, the
receipt correctly stays at rc=0. If a fix repairs only the form and the derived item turns out
not to be open, the receipt would report CLOSE-CANDIDATE while element 2 is still partly wrong.
Second hesitation: this receipt depends on consumer content. If the backlog is reformatted away
from `- **Item N`, control (a) fails and the verdict is 127 NEEDS-REVIEW — the safe direction,
never a false close.

---

## Entry 4 — pin 1136 · `PC-S297-PROVENANCE-FLAGLESS-FAIL-OPEN-BY-DEFAULT` · LIVE

**OLD receipt (verbatim)**

```
verify: theirs_has core/scripts/validate-provenance-block.sh "[--require-skill <skill-name>]"
```

**Why it can never go green.** It anchors on the **usage string**
(`validate-provenance-block.sh:3`, `:40-41`). The proposed fix keeps `--require-skill` and adds
an `--allow-missing`-style opt-out beside it, so the usage line survives verbatim. Anchor-failure
shape 1 again, and this one is unusually clear-cut: the anchor is the name of the flag the fix
is built AROUND.

**Re-derivation at `e939a92` — reproduced, with the control in the same invocation:**

```
bash core/scripts/validate-provenance-block.sh /etc/hosts                                  -> rc=0
bash core/scripts/validate-provenance-block.sh /etc/hosts --require-skill bmad-review-…    -> rc=1
```

Flagless says `OK: no provenance block required or present`. The sides differ, so rc=0 is the
fail-open behaviour and not an inert probe. **LIVE.**

**NEW receipt**

```
verify: sh t=$(mktemp -d) || exit 127; git -C "$DIST" archive "$THEIRS" core/scripts core/schemas >"$t/a.tar" 2>/dev/null && tar -xf "$t/a.tar" -C "$t" || { rm -rf "$t"; exit 127; }; v="$t/core/scripts/validate-provenance-block.sh"; [ -f "$v" ] || { rm -rf "$t"; exit 127; }; printf "no provenance block here\n" >"$t/probe.md"; AI_DLC_PROJECT_ROOT="$t" bash "$v" "$t/probe.md" >/dev/null 2>&1; a=$?; AI_DLC_PROJECT_ROOT="$t" bash "$v" "$t/probe.md" --require-skill bmad-review-adversarial-general >/dev/null 2>&1; c=$?; rm -rf "$t"; [ "$c" -eq 1 ] || exit 127; [ "$a" -eq 0 ]
```

`core/schemas` is archived alongside because the script LOADS `schemas/provenance-block.json`
and refuses to run without it (`:116-128`); `AI_DLC_PROJECT_ROOT` is the script's own documented
override (`:109`), so the extracted copy resolves its schema without a repo.

**Measured today: rc=0** (STILL-LIVE).

**Control, baked into the receipt:** `[ "$c" -eq 1 ] || exit 127` — the flagged call must still
FAIL. That is what separates "fails open without the flag" from "the extracted script cannot run
at all", which would otherwise also produce a flagless rc≠1.

**Two-sided probe:** base rc=0 · mutant `m4` (flagless requires a block unless `--allow-missing`)
rc=1. Confirmed to die by the **right arm**: flagless went 0→1 while flagged stayed 1, so the
flip is attributable to the flagless path alone.

**What makes it pass.** Making the default fail-closed with an explicit opt-out flag.

**Anchor shapes checked.** Behavioural. The `--require-skill` token appears in the receipt only
as the CONTROL's argument, never as the thing being asserted, so a fix keeping that flag cannot
hold the entry open.

---

## Reproduction

- `run-receipts.sh` — runs all four exactly as `ledger-reverify.sh` does.
- `receipts2.sh` — the four receipt bodies (`\x3c`-escaped form).
- `receipt-lines-final.txt` — the four lines as they should appear in the ledger.
- `mutants.sh` — seeds `m1a m1b m2 m3 m4` in a `git clone --local` scratch copy of ai-dlc at
  `step19/mut`. Nothing is committed to the real repo.
- `mutkill2.sh` — the two-sided probe; asserts the sides differ before reading the comparison.
- `r1-arms.sh` — which R1 arm each mutant killed, plus the `independent`/`depend` FP narrowing.
- `probe-e2.sh`, `probe-e3.sh` — the standalone differentials for entries 2 and 3.

## Standing caveats

- Everything is measured at `e939a92`. Other agents committed during the session; these four
  subjects were re-derived after that, and all four receipts read `$THEIRS` from git rather than
  a working tree, so a dirty tree cannot change a verdict.
- Receipt lengths: 653 / 902 / 1055 / 575 bytes on one line. None ends in a backtick or a period
  (verified, with a positive control), so `ledger-reverify.sh`'s directive trimming (`:794`) is a
  no-op on all four.
- These four are long for a ledger line. The alternative — a `theirs_has` on a token the fix must
  remove — was rejected for entries 2, 3 and 4 because in each case the obvious fix is an
  ADDITION beside code that stays, so no such token exists. Entry 1 is the one where no
  executable exists at all (the subject is a classifier prompt), which is why it alone is textual.
