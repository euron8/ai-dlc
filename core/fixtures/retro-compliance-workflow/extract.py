#!/usr/bin/env python3
"""Pull EXECUTABLE material out of a GitHub Actions workflow.

This exists so run.sh can DRIVE the workflow's shell rather than grep it. A grep for
`docs/retro/sprint-` is satisfied by the header comment (the template carries one), and
is defeated by any rename; running the `run:` body against a seeded tree is not.

No YAML library is used or required. The two shapes needed here are read by indentation:

  run <step-name-substring>   the dedented body of the `run: |` block belonging to the
                              first step whose `name:` contains the substring. Printed
                              verbatim, so `${{ ... }}` survives for the caller to
                              substitute.
  paths                       the entries of `on.pull_request.paths`, one per line.
  match <glob> <path>         1/0 whether a GitHub Actions path filter matches. `*` and
                              `?` do not cross `/`; `**` does. Written here rather than
                              handed to the shell because bash globbing has neither rule.

Exit 3 on "asked for something that is not there" — distinct from a parse crash, so a
caller can tell a renamed step from a broken extractor.
"""
import re
import sys


def lines(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read().splitlines()


def indent_of(s):
    return len(s) - len(s.lstrip(" "))


def extract_run(path, needle):
    src = lines(path)
    i = 0
    while i < len(src):
        m = re.match(r"^(\s*)-\s+name:\s*(.*)$", src[i])
        if m and needle in m.group(2):
            step_indent = indent_of(src[i])
            j = i + 1
            while j < len(src):
                cur = src[j]
                if cur.strip() and indent_of(cur) <= step_indent:
                    break  # next step / next key at or above the list-item indent
                if re.match(r"^\s*run:\s*\|\s*$", cur):
                    body_indent = None
                    out = []
                    k = j + 1
                    while k < len(src):
                        b = src[k]
                        if not b.strip():
                            out.append("")
                            k += 1
                            continue
                        if body_indent is None:
                            body_indent = indent_of(b)
                        if indent_of(b) < body_indent:
                            break
                        out.append(b[body_indent:])
                        k += 1
                    while out and not out[-1].strip():
                        out.pop()
                    return "\n".join(out)
                j += 1
        i += 1
    return None


def extract_paths(path):
    src = lines(path)
    i = 0
    # on: -> pull_request: -> paths:
    while i < len(src) and not re.match(r"^on:\s*$", src[i]):
        i += 1
    if i >= len(src):
        return None
    i += 1
    while i < len(src) and not re.match(r"^\s+pull_request:\s*$", src[i]):
        if src[i].strip() and indent_of(src[i]) == 0:
            return None
        i += 1
    if i >= len(src):
        return None
    pr_indent = indent_of(src[i])
    i += 1
    while i < len(src):
        if src[i].strip() and indent_of(src[i]) <= pr_indent:
            return None
        if re.match(r"^\s+paths:\s*$", src[i]):
            break
        i += 1
    if i >= len(src):
        return None
    p_indent = indent_of(src[i])
    i += 1
    out = []
    while i < len(src):
        cur = src[i]
        if not cur.strip():
            i += 1
            continue
        if indent_of(cur) <= p_indent:
            break
        m = re.match(r"^\s*-\s*(.*?)\s*$", cur)
        if not m:
            break
        out.append(m.group(1).strip().strip('"').strip("'"))
        i += 1
    return out


def glob_to_re(g):
    out, i = ["^"], 0
    while i < len(g):
        c = g[i]
        if c == "*":
            if g[i:i + 2] == "**":
                out.append(".*")
                i += 2
                continue
            out.append("[^/]*")
        elif c == "?":
            out.append("[^/]")
        else:
            out.append(re.escape(c))
        i += 1
    out.append("$")
    return re.compile("".join(out))


def main(argv):
    if len(argv) < 3:
        print("usage: extract.py <workflow.yml> run|paths|match [args]", file=sys.stderr)
        return 2
    wf, mode = argv[1], argv[2]
    if mode == "run":
        body = extract_run(wf, argv[3])
        if body is None or not body.strip():
            print(f"extract.py: no `run: |` body for a step named like {argv[3]!r}",
                  file=sys.stderr)
            return 3
        print(body)
        return 0
    if mode == "paths":
        p = extract_paths(wf)
        if not p:
            print("extract.py: on.pull_request.paths is absent or empty", file=sys.stderr)
            return 3
        print("\n".join(p))
        return 0
    if mode == "match":
        print("1" if glob_to_re(argv[3]).match(argv[4]) else "0")
        return 0
    print(f"extract.py: unknown mode {mode!r}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
