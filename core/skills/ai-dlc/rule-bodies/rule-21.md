### Rule 21 -- READ AND FOLLOW is a Read tool call, not recall

This file is the full text of Rule 21 of `SKILL.md`; the stub in that file is the load pointer. It ships with the skill and is audited as rule prose under the same standard as the stub.

A `READ AND FOLLOW` directive MUST produce a `Read` tool call (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) for the
target step file as the FIRST tool call in the response. No other
action (Bash, Edit, Write, Agent, Skill) before the Read. The lead
MUST NOT substitute memory, prior-session knowledge, or accumulated
context for the Read. The Read tool call is the mechanical
verification that the step was loaded into the current conversation
context. **For `gate-validation.md` alone the Read is SLICED, never
whole**: run `scripts/ai-dlc/gate-slice.sh --type <gate type>`, which
emits the `offset`/`limit` spans covering the `GATE_MANIFEST` universal
row plus the declared type's row, and issue one native `Read` per span.
On a resume after a compaction, pass `--done "$(scripts/ai-dlc/gate-checkpoint.sh
--nonce <gate_nonce> done)"` so checks already verdicted at this nonce
are omitted from the plan. The bounded Read is the compliant Read.

**Each step file carries a `STEP_LOADED_TOKEN` HTML comment** (format:
`<!-- STEP_LOADED_TOKEN: <step-name> -->`). It is a marker, and no gate
reads it. No rule requires the gate log entry to cite the token and no gate
fails on a missing citation; neither is implemented, so
neither is claimed.
A gate log entry is written by the same lead the rule constrains, so a
token cited there is a SELF-REPORT: the lead this rule exists to catch
— the one that pattern-matches on "I know what this step does" and
skips the Read — writes the token from memory exactly as readily as one
that read the file. The evidence that discriminates is the `Read` tool
call in the transcript, which the checked agent does not author;
`.claude/hooks/ai-dlc-acknowledge.sh` Check 2z consumes it that way for
`route.md`, keyed deliberately on a `file_path` and not on this token.
Extending that shape to the other step files is a separate, larger
change and is not claimed here.

**Sliced loading for `gate-validation.md`.** For
`gate-validation.md` alone, "loaded" does NOT mean the whole file. That
file is sliced by gate type: "loaded" means the **universal core** — the
`GATE_MANIFEST` universal row in `gate-validation.md`, which is the single
source for that set and MUST NOT be re-typed here — **and**
every check the file's `GATE_MANIFEST` marks required for the declared
gate type — that exact set present in context, nothing less. The
invoking step MUST declare the gate type when it says "run gate
validation" (format: `run gate validation [<type>]`, where `<type>` is
one of `planning`, `story`, `implementation`, `sprint-review`, `retro`);
the type is the step's already-known phase, not a new computation. The
file-level `STEP_LOADED_TOKEN` no longer proves completeness (the file
is not read whole), so each check carries its own
`<!-- CHECK_LOADED: <id> -->` anchor and H1 reads the manifest and FAILS
the gate if any required check's anchor is absent — completeness is a
checked invariant, not a trust-the-loader assumption. See
`steps/gate-validation.md` "Gate-type manifest". All OTHER step
files remain whole-file `READ AND FOLLOW` as above.

**The slice is EMITTED, never derived by hand.** `scripts/ai-dlc/gate-slice.sh
--type <type>` resolves the rendered manifest — core's table, or the
`overrides/` entry shadowing it, plus every `extensions/checks/` entry
declaring `gate_types:` — and prints one `offset<TAB>limit<TAB>checks`
row per contiguous span. Issue exactly those Reads, natively; never route
the file through a `ctx_*` tool (Rule 23(c)). It exits 2 rather than
shortening the plan when a required check has no anchor. A consumer
extension's checks are reported as a separate load.

**A gate resumes; it does not restart.** Every check that reaches a
verdict is recorded at once —
`scripts/ai-dlc/gate-checkpoint.sh --nonce <gate_nonce> record <id> <PASS|FAIL|SKIP|PENDING>`
— and a resume after a compaction passes the settled set back as
`--done`. Only `PASS` and `SKIP` narrow a resume. The ledger is keyed on
the nonce; a re-dispatch mints a fresh nonce and reads an empty ledger.
The gate is `open`ed at nonce mint and `close`d after Check 15, and
`scripts/ai-dlc/gate-checkpoint.sh current` names the open nonce — a
resume that finds none resumes no gate.

**Failure mode this prevents.** In hot sessions with many completed
gates, the lead pattern-matches on "I know what this step does" and
skips the Read entirely, executing from memory. The Read tool call
is the interrupt that forces re-engagement with the step's actual
instructions. Memory of a step file is not equivalent to loading it.
