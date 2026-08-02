# graph pull v0.240.0 — report-back

Executed end to end against `docs/reviews/graph-pull-0.240.0-operator-handoff.md`.
Consumer: `/Users/n8/git/graph`, branch `chore/pull-0.240.0`, commit `b52d456a9`,
**PR https://github.com/euron8/fee_accrual_graph/pull/855**.
Engine pinned at `/tmp/pull-engine-0240` = `029dfe1` (`VERSION` = `0.240.0`).
`origin/main` was `0be6529cd` at start — **unmoved from the brief**, so §4's
pre-measured figures were used as-issued, not re-derived.

---

## 6. Report-back

| reading | expected | measured |
|---|---|---|
| `apply.sh` rc / stderr bytes / row counts | 0 / 0 / 5 R, 1 D, **0 W** | **0 / 0 / 5 R, 1 D, 0 W** — all six rows byte-identical to §4.1 |
| diff shape | 3 files, +97 / −5, `_bmad-output` 0 | **3 files, +97 / −5**; `apply.sh` wrote nothing under `_bmad-output/` |
| `git tracks no file there` marker before → after | 0 → 1 | **0 → 1** (`grep -c` rc 1 on the before-read, as §3 warns) |
| `consumer-machinery-inventory` assertions | 19 → 24 | **19 → 24** |
| `layer-reference-resolution` (control) | 22 → 22 | **22 → 22** — did not move |
| fixture count (control) | 112 → 112 | **112 → 112** — did not move |
| stamp: which lines moved | `version`/`commit` only, `skill_*` preserved | **`0.239.0`/`bd740f6` → `0.240.0`/`029dfe1`; `skill_version: 0.238.0` / `skill_commit: 44db151` preserved** — §2.1 as specified |
| validator verdict before / after | `errors=0 warnings=1` both | **both `0 error(s), 1 warning(s)`**; `contract_version=13 entries=50 at_current=50 behind=0 undeclared=0` byte-identical |
| any NEW `E18` naming "git tracks no file there" | none expected (67/67 tracked) | **none** — the measured-empty false-positive set held |
| pre-push before / after, with the `PASS` control | `112 ok / 0 FAIL` rc 0 both | **`112 ok / 0 FAIL`, rc 0, on all three runs before and all three after; `PASS` control = 9 both**, non-zero, so the bare-`FAIL` form is reading verdict lines |
| suite median | ~42.9s | **45.52s before → 46.67s after** — see note |

**The one departure from §4, and why it is not the release.** The rehearsal
clone's 42.87s does not reproduce here. But the offset is present in the
**before** figures too (45.52s on unmodified `0be6529cd`), so it is a
machine-speed constant, not something v0.240.0 introduced. Before-vs-after on
this machine is +1.15s (2.5%), which is flat. Reported rather than treated as a
stop, because the local before-figure is the control that separates the two
readings.

**Stop conditions: none fired.** No `WORKLIST` row, nothing written under
`_bmad-output/` by `apply`, exactly one `DECISION` (the `extensions/README.md`
drift of §2.4, left alone — fifth pull running), `version`/`commit` advanced.

**§2.2's asymmetric greps were used as written**, `'^[[:space:]]+FAIL[[:space:]]*$'`
against `'^[[:space:]]+ok[[:space:]]'`, with the `PASS` count from the bare form
as the control.

---

## 7. The one question — the answer is **no** on both legs, and the ask should not be built

Measured against the engine at `029dfe1` and graph's real corpus (sprint 299).

### 7.1.1 — Is the breakdown line core already prints enough? **No, and it is worse than "unstable prose".**

Three findings, each measured.

**(a) The value slot is polymorphic, and only one of its four shapes is a number.**
`sprint-status.sh` appends to `per_view` at four sites:

```
:958   "no canonical on disk"
:964   "holds sprint %s, not %d — not derived"
:968   "no entry to derive (`stories:` %s)"
:1038  "%d entr%s, %d resolved"
```

printed by `print("  %-15s %s" % (view + ":", note))` at `:1049`. So a reader
taking the count off `  planning:` gets the word `no` on two legitimate states
and `holds` on a third. It is not a number field that might get reworded — it
is a field that **is not a number three times out of four**, and every one of
those three is a state a consumer's gate will actually meet. A `${x:-0}`
fallback turns each into a silent zero denominator; a strict parse fires a
false mismatch. Both are fail-open in the direction that matters.

**(b) Nothing declares the wording stable — the only thing pinning it anywhere
in the engine is core's own regression test.** A sweep of `029dfe1` for the
format finds exactly two hits, both in
`core/fixtures/story-fields-derive/run.sh:345-346`. `core/schemas/sprint-status.json`
declares a count as contract at its line 73 — but for `check-stories`, not for
this breakdown. A fixture is core's assertion about itself: core can rewrite the
format and the fixture in one commit, stay green, and every consumer parser goes
blind at the same instant with nothing red anywhere.

**(c) graph's own validator already forbids exactly this, in writing, about
exactly this program.** `scripts/ai-dlc-local/validate-story-status-consistency.sh:513-516`:

> Structured exit-code contract with sprint-status.sh derive-stories (NOT a
> string match on its warning text — a wording/i18n edit to that message
> must not silently disable this guard, the exact failure mode this
> remediation exists to kill, one layer up).

So: **confirmed, I would not parse that line.** Per §7.1's own terms the ask
therefore reduces to a declared footer rather than a wording promise — which is
leg 2.

### 7.1.2 — Would a declared footer actually be adopted? **No. Adopting it would remove discrimination cross-check B currently has.**

The footer is technically viable, and that was worth checking rather than
assuming: core's `view_entries` (`:972-977`) increments once per entry from
`parse_story_entries`, and the key matcher is
`story_key_re = "^([ \\t]+)([^ \\t#][^:]*?):[ \\t]*(?:#.*)?$"`
(`core/schemas/sprint-status.json:51`) — a **bare-key structural matcher, not a
story-id filter**. So a footer would preserve the regex-freedom that
`entry_count_no_idregex` exists to supply (`validate-story-status-consistency.sh:205-219`).
That leg passes.

**It fails on a different axis, and the failure is measured, not argued.**
Cross-check B's yaml side is currently read by `yq` — a real YAML parser.
Core's `parse_story_entries` (`:510-573`) is a hand-rolled indent-scanning line
reader that never invokes a YAML library. **They disagree on valid YAML.**
Executed against a synthetic sprint-299 envelope holding two entries, one of
them a quoted key containing a colon:

```yaml
stories:
  "story-S299-1: the draft":
    status: ready
  story-S299-2:
    status: ready
```

```
yq  (real YAML parser)             : 2 entries
core (derive-stories --check)      :   planning:       1 entry, 0 resolved
```

`STORY_KEY_RE`'s `[^:]*?` cannot span the internal colon, so the quoted key is
invisible to the scanner. Today cross-check B compares **`yq` against a
filesystem `find`** — two readers that fail in unrelated ways. Repointing the
denominator to a core footer makes it **core's line scanner against a
filesystem `find`**, and on the yaml side that swaps the stronger reader for the
weaker one. On the shape above, `checked` sees the story file and the
denominator has silently lost the entry: a false MISMATCH, or — if the file is
absent too — both sides drop together and the check goes blind on precisely the
entry the scanner cannot read. That is the "both sides of the comparison drop
together and the run reports a confident zero" failure the `entry_count_no_idregex`
comment was written to prevent, re-introduced through a different door.

**On the current corpus the footer would also buy nothing observable.**
Sprint 299, measured three ways: local `entry_count_no_idregex` = **1**; core's
per-view `planning:` = **1 entry**; core's union summary = **1 entry declared**.
The union's blindness is real but unrealised here, because the two views declare
the same single key.

### Verdict

**Core should not build the declared footer.** The honest answer is the one §7
named as legitimate and slightly stronger than "the `yq` call is cheap and
already correct": the `yq` call is not merely cheap, it is **the more
discriminating of the two readers**, and adopting core's number would be a
net loss of independence on the yaml side of the comparison. There is no
adopter here, and there should not be one.

This closes the question rather than deferring it. Nothing is owed back on it.

---

## Out of scope, confirmed untouched

- `W7` / `Check 11b` — still the single standing warning, still the control that
  the validator is emitting.
- `extensions/README.md` `DECISION drift` — §2.4, left.
- Declaring `field: title` — still owed, still one line, still the operator's
  word. Not in this pull.
- `sprint-168` provenance, and `_bmad-output/.audit-watermark` gitignored while
  both tools write it — unchanged, still nobody's step.
