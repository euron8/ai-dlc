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

## Never read `$?` after a pipe, and never feed `grep -q` from one

`grep -q` leaves at its first match while the writer is still pushing. Under `pipefail` the
pipeline then answers with the writer's EPIPE and reports NOT-FOUND on input that contains
the pattern. **It is a size threshold, not a race** — correct until the output after the
match fills the pipe buffer, then wrong permanently and with no symptom. Put the upstream in
a command substitution and feed the reader a here-string.

Assignments and exit codes made inside `$( )` or in a pipeline's last stage are lost to a
subshell. Write them to a file, or restructure.

## BSD tools are not GNU tools, and they fail silently

- No `\s` in a BRE. `?`, `+` and `|` are literal without `-E`.
- `[ \t]` in a `sed` or `grep` bracket class is SPACE, BACKSLASH and the letter `t` — not a
  tab. Use `[[:blank:]]`.
- No backreference in `awk`'s `sub()`. `awk -v` strips escapes and cannot carry a newline.
- A multibyte character needs an alternation, not a bracket class.
- BSD `sed` no-ops several GNU constructs rather than erroring.

Reach for `awk` over `sed` when the expression is doing real work, and verify every new
expression against a positive control before trusting a zero from it.

## Git lies by default

- Pass `-M` or renames read as a delete plus an unrelated add.
- Brace every rev-path: `"${SHA}:path"`.
- Never depth-filter with a pathspec glob, and `set -f` before iterating pathspecs.
- **Never test whether work landed by ancestry** in a squash-merge repo — the commits that
  would answer are the ones a squash removed. Test by content.
- Commit or stash before any `git checkout` that names a path.

## Environment floor

`bash` is 3.2: no `mapfile`, no `readarray`, no `declare -A`, and an empty array under
`set -u` is an error. There is no `setsid`. SIP blocks `dtruss` but not `fs_usage`. The
interactive `grep` is a `ugrep` shim that honours `.gitignore`, so an interactive search and
a scripted one scan different sets. Measure under `env -i PATH=/usr/bin:/bin bash` when the
answer has to hold for a shipped script.
