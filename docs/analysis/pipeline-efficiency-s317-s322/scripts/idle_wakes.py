#!/usr/bin/env python3
"""BL-538 per-wake idle counter (stdlib only; read only on its inputs).

Definition (BL-538, "f7's heuristic"): a WAKE is a non-sidechain `user` line of a
lead transcript whose content carries a `<task-notification>` tag and is not a
`tool_result` carrier. A wake is IDLE when no assistant `tool_use` block appears
in the transcript between it and the next `user` line (or end of file). Queued
`queue-operation` lines are not wakes.

Usage:
  idle_wakes.py [--upto LINE] TRANSCRIPT.jsonl [...]
Prints one row per transcript: wakes, idle, share, then a kind split
(agent exit vs background-command completion, by the notification text).
--upto LINE counts only wakes whose line number is <= LINE (1-based file line,
the same numbering as `grep -n`), with the window's idle test still reading to
the next user line.

Control: the s319 lead transcript c61a91eb at --upto 2838 must read 37 idle of
54 wakes (BL-538 second/third readings). Run the control before any new reading.
"""
import json
import sys


def _is_wake(d):
    if d.get("type") != "user" or d.get("isSidechain"):
        return False
    c = d.get("message", {}).get("content")
    if isinstance(c, str):
        return "<task-notification>" in c
    if isinstance(c, list):
        if any(isinstance(b, dict) and b.get("type") == "tool_result" for b in c):
            return False
        return any(
            isinstance(b, dict) and b.get("type") == "text"
            and "<task-notification>" in (b.get("text") or "")
            for b in c
        )
    return False


def _text(d):
    c = d.get("message", {}).get("content")
    if isinstance(c, str):
        return c
    return " ".join(b.get("text", "") for b in c if isinstance(b, dict))


def _kind(t):
    return "cmd" if "Background command" in t else "agent"


def count(path, upto=None):
    wakes = []  # [line, kind, has_tool_use]
    cur = None
    with open(path, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            try:
                d = json.loads(line)
            except ValueError:
                continue
            t = d.get("type")
            if t == "user" and not d.get("isSidechain"):
                cur = None
                if _is_wake(d) and (upto is None or n <= upto):
                    cur = [n, _kind(_text(d)), False]
                    wakes.append(cur)
            elif t == "assistant" and cur is not None and not d.get("isSidechain"):
                c = d.get("message", {}).get("content")
                if isinstance(c, list) and any(
                    isinstance(b, dict) and b.get("type") == "tool_use" for b in c
                ):
                    cur[2] = True
    return wakes


def main(argv):
    upto = None
    args = []
    i = 0
    while i < len(argv):
        if argv[i] == "--upto":
            upto = int(argv[i + 1])
            i += 2
        else:
            args.append(argv[i])
            i += 1
    if not args:
        sys.stderr.write(__doc__)
        return 2
    tw = ti = 0
    for p in args:
        w = count(p, upto)
        idle = [x for x in w if not x[2]]
        a = [x for x in w if x[1] == "agent"]
        ai = [x for x in a if not x[2]]
        print("%s wakes=%d idle=%d share=%s agent=%d/%d cmd=%d/%d" % (
            p.rsplit("/", 1)[-1][:8], len(w), len(idle),
            ("%.0f%%" % (100.0 * len(idle) / len(w))) if w else "n/a",
            len(ai), len(a), len(idle) - len(ai), len(w) - len(a)))
        tw += len(w)
        ti += len(idle)
    if len(args) > 1:
        print("TOTAL wakes=%d idle=%d" % (tw, ti))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
