#!/usr/bin/env python3
"""BL-538 idle agent-exit wakes by the role of the agent that sent each notice (stdlib only; read only).

The wake/idle definition is idle_wakes.py's count(), imported, not restated. Each agent-exit wake's
`<task-id>` is joined to the lead's own `Agent`/`Task` spawn through the tool_result whose `toolUseResult`
carries that agentId, and the spawn's tool_use id to its row in the consumer's spawn ledger. The class is the
row's `role`, refined by its `shard` line for the two roles a round-dispatcher could carry:
  adversary   single (no shard line, or `none (...)`), cross (`cross/...`), sharded (any other shard line)
  remediator  serial (no shard line, or `none (...)`), sharded (any other shard line)
A null `shard` is read as single/serial, so each `sharded` count is a floor. A notice carrying "waiting on its
own background work" (a spawner that ended its turn with live children) gets a `+interim` suffix. A task-id no
lead tool_result names is `unresolved`; a resolved spawn with no ledger row is `no-ledger-row`.

Usage:
  idle_wakes_by_role.py --ledger <spawn-ledger.jsonl> [--bound ID8=LINE,...] <lead transcript>...
--bound cuts one transcript's wakes at a 1-based line (idle_wakes.count's --upto), keyed by the file name's
first 8 characters. Exit 0 with a CONTROL line (all wakes and agent-exit wakes, idle/total) first; exit 2 on a
missing transcript, an unreadable or row-less ledger, a --bound naming no given transcript, or no transcript.
"""
import json
import os
import re
import sys
from collections import Counter

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import idle_wakes  # noqa: E402

INTERIM = "waiting on its own background work"


def refuse(msg):
    print("REFUSED: " + msg, file=sys.stderr)
    sys.exit(2)


def shard_class(role, shard):
    s = "" if shard is None else str(shard)
    plain = s == "" or s.startswith("none")
    if role.startswith("adversary"):
        return "adversary " + ("single" if plain else ("cross" if s.startswith("cross") else "sharded"))
    if role.startswith("remediator"):
        return "remediator " + ("serial" if plain else "sharded")
    return "role " + (role or '""')


def main(argv):
    ledger, bounds, paths = None, {}, []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--ledger" and i + 1 < len(argv):
            ledger = argv[i + 1]; i += 2; continue
        if a == "--bound" and i + 1 < len(argv):
            for kv in argv[i + 1].split(","):
                k, _, v = kv.partition("=")
                if not v.isdigit():
                    refuse("--bound takes ID8=LINE (got '%s')" % kv)
                bounds[k] = int(v)
            i += 2; continue
        paths.append(a); i += 1
    if not ledger or not paths:
        refuse("usage: --ledger <spawn-ledger.jsonl> [--bound ID8=LINE,...] <lead transcript>...")
    led = {}
    try:
        with open(ledger, encoding="utf-8") as fh:
            for line in fh:
                try:
                    r = json.loads(line)
                except ValueError:
                    continue
                if isinstance(r, dict) and r.get("tool_use_id"):
                    led[r["tool_use_id"]] = r
    except OSError as e:
        refuse("cannot read the ledger %s (%s)" % (ledger, e))
    if not led:
        refuse("the ledger %s holds no row with a tool_use_id" % ledger)
    ids = {os.path.basename(p)[:8] for p in paths}
    for k in bounds:
        if k not in ids:
            refuse("--bound names %s, which is no given transcript" % k)
    tot, idle = Counter(), Counter()
    w_all = i_all = w_ag = i_ag = 0
    for p in paths:
        if not os.path.isfile(p):
            refuse("no transcript at %s" % p)
        wakes = idle_wakes.count(p, bounds.get(os.path.basename(p)[:8]))
        with open(p, encoding="utf-8") as fh:
            lines = fh.read().split("\n")
        spawn, agent = {}, {}
        for line in lines:
            try:
                d = json.loads(line)
            except ValueError:
                continue
            c = d.get("message", {}).get("content")
            blocks = c if isinstance(c, list) else []
            for b in blocks:
                if isinstance(b, dict) and b.get("type") == "tool_use" and b.get("name") in ("Agent", "Task"):
                    spawn[b.get("id")] = True
            r = d.get("toolUseResult")
            if isinstance(r, dict) and r.get("agentId"):
                for b in blocks:
                    if isinstance(b, dict) and b.get("type") == "tool_result":
                        agent[r["agentId"]] = b.get("tool_use_id")
        for n, kind, acted in wakes:
            w_all += 1; i_all += (not acted)
            if kind != "agent":
                continue
            w_ag += 1; i_ag += (not acted)
            t = idle_wakes._text(json.loads(lines[n - 1]))
            m = re.search(r"<task-id>([^<]+)</task-id>", t)
            tu = agent.get(m.group(1)) if m else None
            if tu is None or tu not in spawn:
                cls = "unresolved"
            elif tu not in led:
                cls = "no-ledger-row"
            else:
                cls = shard_class(led[tu].get("role") or "", led[tu].get("shard"))
            if INTERIM in t:
                cls += "+interim"
            tot[cls] += 1
            idle[cls] += (not acted)
    print("CONTROL\tall wakes idle %d of %d\tagent-exit idle %d of %d" % (i_all, w_all, i_ag, w_ag))
    for k in sorted(tot, key=lambda k: (-idle[k], k)):
        print("%s\tidle %d of %d" % (k, idle[k], tot[k]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
