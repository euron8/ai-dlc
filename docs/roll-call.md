# Roll call

The lead runs this every 45 minutes while builder sessions are active.

## Procedure

1. The lead sends the message below, verbatim with only `<batch>`, `<lead>`, `<origin/main>` and `<handoff dir>`
   filled in, to every active builder session, in groups of three, waiting for each group's replies before sending the next. It opens each
   cited governing line and checks every read range reaches EOF.
2. AFTER ALL REPLIES ARE IN, the lead rereads, with the Read tool, offset and limit, never ctx_*, cat, sed or grep:
   - `CLAUDE.md` and the 6 unscoped `.claude/rules/*.md` (verification-discipline, tool-hazards,
     consumer-boundary, mechanism-design, resident-context, operator-rulings), in chunks of at most 80 lines, to EOF.
   - The batch's rulings log in `<handoff dir>`, in chunks of at most 40 lines, from the line after the last one read in the previous
     roll call to EOF. Record that last line number in the log's roll-call entry.
   - `<handoff dir>/handoff-common.md`.
   If a read comes back as a stub, halve the limit and reread.
3. The lead makes an advisor call in its own message, after the reread.
4. The lead appends to the log: the time, its own read ranges, the advisor call made, each session's reply, and
   any defect it found.
5. The lead arms the next roll call 45 minutes after this one started (a one-shot cron firing this procedure).

## Message

```
ROLL CALL (batch <batch>, lead <lead>). origin/main is <origin/main>. CLAUDE.md "## Build process" is the process.

Reread with the Read tool, ALWAYS with offset AND limit. Never use ctx_*, cat, sed or grep for this.
- /Users/n8/git/ai-dlc/CLAUDE.md and the 6 unscoped .claude/rules files, in chunks of at most 80 lines, to EOF.
- The scoped .claude/rules files for any paths you edit.
- <handoff dir>/handoff-common.md and your own handoff file.

If a read comes back as a stub, halve the limit and reread.

You MUST reply. Send the reply to <lead> with the SendMessage tool as soon as the reread is done, before any
other work and before ending your turn; plain output reaches nobody. The reply contains:
- state
- sha
- blocker
- the line ranges you read, per file
- the file:line that governs your next step
- whether you made the advisor call
```
