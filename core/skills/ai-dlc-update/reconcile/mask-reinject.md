# Mask/reinject transform

### Mask/reinject transform (setup-substitution sites)

Some core-manifest files carry consumer config `ai-dlc-setup` filled in at
install time — model strings, ownership paths, deploy/smoke commands — living
inside otherwise upstream-owned files (team-role files, `deploy-validate.md`,
`implementation.md`). These are consumer config, not rulebook divergence, and
a plain overwrite would destroy them. `reconcile/setup-sites.md` is the
declared list of every such site (file, anchor, capture pattern). This
transform is used by BOTH SKILL.md step 7 (every ordinary pull, once any manifest
site exists) and by step 7u of `reconcile/untangle.md` (its mask-aware overwrite) — it is not
untangle-specific. On an ordinary pull `apply.sh` resolves the clean case itself
(`RESOLVED setup-site-merge`), so the steps below apply to the setup-sited
files it still hands back as `semantic-merge`.

For each file listed in `setup-sites.md`, before overwriting with `theirs`:
1. Locate each declared site in `ours` (its regex `match`, or its
   `heading`/`next_heading` span) and extract the captured value(s).
2. Overwrite the file with `theirs` — **the complete `theirs` content,
   verbatim**. This is a genuine whole-file replacement: theirs' surrounding
   structure (HTML `<!-- ... -->` config comments, blank lines, adjacent
   prose) is what the file now IS. Do NOT carry over `ours`'s structure around
   the sites — the whole point is that core becomes byte-reconcilable with
   theirs everywhere except the declared value spans.
3. Re-locate each site by the SAME locator in the freshly-written `theirs`
   content and reinject ONLY the extracted value into the captured span
   (single-line sites) or the heading-block body (heading-block sites).
   Touch nothing outside the captured span — a single-line site's
   `<!-- {token} -->` doc comment two lines up is NOT part of the span and
   MUST survive from `theirs` untouched. After reinject, the file must equal
   `theirs` byte-for-byte EXCEPT inside the declared site spans; if it differs
   anywhere else, the transform over-reached — redo it from a clean `theirs`
   copy.
4. **Anchor-drift:** if a site's locator cannot be found in the freshly-written
   `theirs` content (upstream restructured or reworded that section), STOP and
   flag the site for operator adjudication in the report/log — do not drop the
   value, and do not guess a new location for it.

**Setup site inside an overridden section.** A setup site can sit inside a
section that ALSO has a consumer `overrides/` entry shadowing it (e.g. a
`#Identity` override on a team-role file whose own lines are declared sites
within that same section). These are two independent layers and
must not be conflated: **core** is still restored to `theirs` verbatim and the
setup value reinjected into its span (per above) — core stays byte-reconcilable;
the **override** shadows the section at load time per Rule 27 (`overrides >
core`) using its own body, which describes only its deliberate change (e.g.
"remove the Local (Ollama) bullet") and explicitly does NOT restate the setup
`/model` lines (those live concrete in core and are reinjected there, not in
the override). Do NOT let the override's presence cause core to keep `ours`'s
structure at the site — that is the exact over-reach step 3 forbids, and it
leaves a non-site core deviation from theirs that the §7v gate (criterion 5)
must catch.

This is why SKILL.md's "Layered consumers" section is a fast-forward everywhere EXCEPT at
declared sites, not everywhere unconditionally.
