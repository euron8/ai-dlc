<!-- unconditional: these govern ad-hoc tool calls, which leave no file behind — there is no path to scope to, and `CLAUDE.md` already records that a rule about a Bash behaviour cannot be carried by a file-read trigger. The tracked-file half of the same subject is enforced by invariants instead; only the unmechanizable remainder is here. -->

# Tool hazards on this machine

Behaviours that return a WRONG answer rather than an error. Each has produced a shipped
false conclusion here. The half of this subject that lives in tracked files is mechanized —
`I54`/`I54b` for the pipeline cases, `I71` for the bracket-class case — and is not restated
here. What follows has no corpus to scan because it happens in tool calls.

## The Bash tool's shell is zsh

- **No `PIPESTATUS`.** A pipeline's component statuses are simply unavailable, so
  `cmd | tail` reports the status of `tail`. A failing `git push` piped anywhere reports 0.
- **Unquoted `$var` is not word-split**, so a loop written for bash iterates once over the
  whole string.
- **History modifiers eat unbraced references.** `"$r:core/..."` becomes garbage because
  `:c` and `:t` are modifiers that consume the next character. Always `"${r}:core/..."`.
- **`case` patterns are not glob-substituted** the way a bash author expects.

**Force `bash -c` for any loop, any heredoc, and any hook test.** The rule is not "be careful
in zsh"; it is "do not author shell logic in the interactive shell at all".

## Delegation hazards: three ways a tool call lies about another agent

**A backgrounded `sleep` returns immediately**, so chained "waits" are rapid polling granting no
wall clock. Measured: apparent ten-minute waits spanned one minute, four agents were called silent
having barely started, one agent's finished work was redone. Block on the condition instead.

**A CLAIM about a call's output must not share a parallel block with the call** — both dispatch
together, so the claim predates the result. Measured: "a `find` returns nothing" was sent in the
same block as that find, which returned the file.

**An untracked file is not a missing file.** `git ls-files`, `git show HEAD:` and any tree grep
cannot see one, and the clean run reads as a real absence. Measured: three delegated deliverables
declared missing while on disk as `??`. `ls` it, check `git status --porcelain`, ask the agent by
name. An idle notification is not a result; silence is not death.

## Never read `$?` after a pipe, and never feed `grep -q` from one

`grep -q` leaves at its first match while the writer is still pushing. Under `pipefail` the
pipeline then answers with the writer's EPIPE and reports NOT-FOUND on input that contains
the pattern. **It is a size threshold, not a race** — correct until the output after the
match fills the pipe buffer, then wrong permanently and with no symptom. Put the upstream in
a command substitution and feed the reader a here-string.

Assignments and exit codes made inside `$( )` or in a pipeline's last stage are lost to a
subshell. Write them to a file, or restructure.

## BSD tools are not GNU tools, and they fail silently

In a tracked file, arms S1–S7 of `scripts/validate-shell-portability.sh` and `I71` mechanize
this and it is not restated here — read those arms for the grammars. In an ad-hoc tool call
nothing is watching, and two traps no arm can cover, because correct and incorrect use are
the same shape to a regex:

- **`awk -v` strips one level of escaping** and carries no newline at all. A regex passed
  through it needs doubled backslashes, so a correct site looks wrong.
- **A multibyte character needs an alternation, not a bracket class.**

Reach for `awk` over `sed` when the expression does real work, and verify every new expression
against a positive control before trusting a zero from it.

## Git lies by default

- Pass `-M` or renames read as a delete plus an unrelated add.
- Brace every rev-path: `"${SHA}:path"`.
- Never depth-filter with a pathspec glob, and `set -f` before iterating pathspecs.
- **Never test whether work landed by ancestry** in a squash-merge repo — the commits that
  would answer are the ones a squash removed. Test by content.
- Commit or stash before any `git checkout` that names a path.

## Environment floor

`bash` is 3.2, and an empty array under `set -u` is an error. `mapfile`, `readarray`,
`declare -A` and `setsid` are unavailable, and the validator above fails the push on all four
in a tracked file. SIP blocks `dtruss` but not `fs_usage`. The
interactive `grep` is a `ugrep` shim that honours `.gitignore`, so an interactive search and
a scripted one scan different sets. Measure under `env -i PATH=/usr/bin:/bin bash` when the
answer has to hold for a shipped script.
