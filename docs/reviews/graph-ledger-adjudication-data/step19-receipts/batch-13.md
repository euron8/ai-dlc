# Step 19 batch 13 — the two post-pin entries that carry no directive

Authored inline after `step19-b12` went silent through three status checks with nothing on disk.
Its assignment file is `batch-12.tsv`; this file supersedes it and `batch-12.md` was never written.
If that agent later delivers, the extractor's ARM 4b refuses on a duplicate pin rather than
silently taking one of the two.

**These two sit ABOVE the corpus pin**, at live ledger lines 4357 and 4392, so they are outside
the Phase 0 census and outside the 115-row partition. They were read from the live ledger. The pin
itself still holds — the file's first 4356 lines hash to `2fd444dcf406cdff728fe3c0c4352267` with
the 4355-line control differing — and every graph addition so far has been a pure append, so those
line numbers are current.

**Both are filed upstream already**, as `BL-063` (pin 4357) and `BL-064` (pin 4392), each carrying
a receipt read by `scripts/backlog-reverify.sh`. Those exit NON-zero while the defect is live. The
two receipts below are the INVERSE, because `ledger-reverify.sh` reads `rc=0` as STILL-LIVE — they
are not transcriptions with a flipped comparison, but they do reuse the upstream receipts' proven
subjects, and the sanity guards were re-sited from `exit 9` to `exit 127` so an unresolvable
subject reports NEEDS-REVIEW on the consumer engine rather than a bare non-zero that reads as a
close.

## Pin 4357 — `PC-S303-SPEC-JOIN-MEMLOG-REGEX-STALE-VS-AUTHOR-SUFFIX`

**Re-derivation.** `core/scripts/validate-spec-join.sh:164` builds `CAP_ENTRIES` with
`grep -E '^[[:space:]]*[-*][[:space:]]*\((capability|capabilities)\)'`, which requires `)`
immediately after the entry type. The `exit 2` it guards at `:167` precedes every other join in
the script. Driven rather than read, both arms in the same invocation against one PRD: a memlog
seeded `- (capability) LR-S1-1 -> CAP-1` returns rc 0, and the otherwise byte-identical memlog
seeded `- (capability by bmad-spec) LR-S1-1 -> CAP-1` returns rc 2, DISARMED. The two memlogs are
asserted to differ (`cmp -s` must fail) before either exit code is read.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: sh D=$(mktemp -d) || exit 127; mkdir -p "$D/b" "$D/s" || { rm -rf "$D"; exit 127; }; printf "# PRD\n\n- FR-S1-1 the functional requirement, CAP-1\n- LR-S1-1 the locked requirement\n" > "$D/prd.md"; printf "# SPEC\n\nCAP-1 the capability\n" > "$D/b/SPEC.md"; cp "$D/b/SPEC.md" "$D/s/SPEC.md"; printf -- "- (capability) LR-S1-1 -> CAP-1\n" > "$D/b/.memlog.md"; printf -- "- (capability by bmad-spec) LR-S1-1 -> CAP-1\n" > "$D/s/.memlog.md"; cmp -s "$D/b/.memlog.md" "$D/s/.memlog.md" && { rm -rf "$D"; exit 127; }; V="$DIST/core/scripts/validate-spec-join.sh"; [ -f "$V" ] || { rm -rf "$D"; exit 127; }; bash "$V" --spec "$D/b" --prd "$D/prd.md" >/dev/null 2>&1; b=$?; bash "$V" --spec "$D/s" --prd "$D/prd.md" >/dev/null 2>&1; s=$?; rm -rf "$D"; [ "$b" -eq 0 ] || exit 127; [ "$s" -eq 2 ]
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe.** Base rc=0. Mutant: line 164's predicate widened to
`\((capability|capabilities)( by [^)]*)?\)` — rc=1, so the fix closes it. The mutant was built by
an `index`/`substr` replacement rather than a regex, and **the two versions of line 164 were
asserted to differ before either run** — a `sed` that expands to the identical line has produced
perfect agreement read as "no regression" in this repo before.

**Controls, in the receipt itself.** The bare-form arm must return **exactly 0**, not merely
non-2: an earlier upstream draft of this predicate returned non-zero for the wrong reason, because
its control spec carried no `FR-` identifier and DISARMED at a different arm, which reads exactly
like the finding. And the two memlogs must differ, or both arms read one file.

**Anchor shapes checked.** *Quote-back*: structurally impossible — the receipt reads an EXIT CODE,
so no comment recording what a fix removed can satisfy it. *Invented phrasing*: the only literals
are `(capability)` and `(capability by bmad-spec)`, both of which the producer emits and the
script's own error text names. *The fix's own closing clause*: nothing textual is matched.

**Hesitation.** The receipt closes when `:164` accepts the qualifier, but `BL-063` records that
the guarding fixture `core/fixtures/spec-join-integrity/` seeds **0** suffixed entries against 13
bare ones and stays green under both predicates. So this receipt will report the entry closed
while the fixture still cannot express the case. That is a real gap and it is upstream's to fix,
not a defect in the predicate here.

## Pin 4392 — `PC-S303-FANOUT-SCRIPT-ARGV-OVERFLOW-ON-LARGE-DIFF`

**Re-derivation.** `core/scripts/report-propagation-fanout.sh:255-261` is one `export` carrying ten
`FANOUT_*` variables — the full unified diff and the entire `git ls-files` corpus among them — and
`:262` then runs `python3 - <<'PYEOF'`. `execve` charges its size limit on the environment block
whatever the heredoc does. Driven behaviourally with a `python3` shim first on `PATH` so the thing
under test is the program rather than a reading of it: the child's environment carries the corpus
signature **1** time and a diff hunk header **30** times, with `PATH=` present as the proof the
shim was reached at all.

**The filing is wrong about which input causes it, and the receipt is scoped to the true one.** It
is a large-REPO defect, not a large-diff one: the fixed cost is the file list. On the reference
consumer `git ls-files` is 607945 bytes across 10146 paths, 58% of this machine's 1048576-byte
`ARG_MAX` consumed before a single byte of diff exists. So the receipt looks for EITHER payload's
signature, and a fix that relocates only one of them does not close it.

**OLD**

```
verify: (absent — this entry carries no directive, so flush() emits no row for it)
```

**NEW**

```
verify: sh d=$(mktemp -d) || exit 127; n="$d/env"; printf "#!/bin/sh\ncat >/dev/null\nenv > %s\n" "$n" > "$d/python3" || { rm -rf "$d"; exit 127; }; chmod +x "$d/python3" || { rm -rf "$d"; exit 127; }; S="$DIST/core/scripts/report-propagation-fanout.sh"; [ -f "$S" ] || { rm -rf "$d"; exit 127; }; ( cd "$DIST" && PATH="$d:$PATH" AI_DLC_PROJECT_ROOT="$DIST" bash "$S" HEAD~1 >/dev/null 2>&1 ); [ -s "$n" ] || { rm -rf "$d"; exit 127; }; p=$(LC_ALL=C grep -c "PATH=" "$n"); f=$(LC_ALL=C grep -c "core/scripts/report-propagation-fanout.sh" "$n"); g=$(LC_ALL=C grep -c "^@@ " "$n"); rm -rf "$d"; [ "$p" -ge 1 ] || exit 127; { [ "$f" -ge 1 ] || [ "$g" -ge 1 ]; }
```

**Measured today: rc=0 (STILL-LIVE).**

**Two-sided probe, three variants, and the middle one is the point.** Base: corpus signature 1,
diff signature 30, rc=0. Full fix — both payloads written to temp files and both variables exported
empty: signatures 0 and 0, rc=1, closed. **Partial fix — only the corpus file list moved off the
environment, the diff left on it: signatures 0 and 30, rc=0, STAYS OPEN.** Each mutant was
`cmp`-asserted to differ from the shipping script before its output was read.

**Controls, in the receipt itself.** `[ -s "$n" ]` and `[ "$p" -ge 1 ]` assert the shim was
REACHED — an env dump that is empty, or that lacks `PATH=`, means the script exited before
`exec`ing `python3` and the receipt reports NEEDS-REVIEW rather than reading a stale file. That
guard exists because the upstream draft's own satisfiability proof was invalid without it: its
mutant was a copy under `/tmp`, which resolves the root elsewhere and exited 2 before ever
`exec`ing, so a dead mutant reported as a passing fix. `AI_DLC_PROJECT_ROOT` is pinned here for
the same reason.

**It does NOT threshold total environment size**, which is the other measured failure: a size
threshold of 4096 bytes passed a mutant whose child environment was 4113 bytes with the diff
channel still live. Signatures, not sizes.

**Anchor shapes checked.** *Quote-back*: the receipt matches the child's ENVIRONMENT, not the
script's text, so a comment recording the change cannot satisfy it. *Invented phrasing*: neither
signature is prose — one is a tracked path this repo really contains, the other is `diff`'s own
hunk-header syntax. *A variable name*: deliberately not used, so renaming `FANOUT_DIFF` while
leaving it on the env channel cannot close it.

**Hesitation.** The diff signature depends on `HEAD~1` differing from the tree. If that ever went
empty the diff leg would read 0 for a reason unrelated to any fix — but the corpus leg is
independent of it and the two are OR'd, so the receipt degrades to half strength rather than
false-closing. `BL-064` carries the same dependency and it is recorded there too.

## Reproduction

The probe that produced every figure above:
`/private/tmp/claude-501/-Users-n8-git-ai-dlc/<session>/scratchpad/b13-probe.sh` — session-scoped
and therefore not evidence a later session can re-run. What IS re-runnable is
`step19-receipts/run-receipts.sh`, which re-executes both receipts from the committed TSV under the
engine's own exported environment and asserts each measures what the TSV records, with controls
both ways in the same invocation.
