# Findings of reader `agent-a8eb666cad2276` (recovered verbatim from its transcript agent-a8eb666cad227637c.jsonl)

## FINAL-TEXT 2026-11-20T11:28:40.791Z

## Answers

**Caveat on sources:** WebFetch returned pointers to a context-mode search tool rather than page content, so I downloaded the pages with curl and read them directly. The page titled `plugins-reference.md` is the manifest reference, cited below under its canonical URL.

**1. What creates a project-scope install record**

The docs do not describe any automatic creation. Each candidate is covered as follows:

- **`enabledPlugins` in project settings:** the docs say it "doesn't install them, so each user installs them" ([settings-reference#enabledplugins](https://code.claude.com/docs/en/settings-reference#enabledplugins)). A plugin enabled only in project settings "doesn't load at session start until you install it on your machine" ([plugins/loading#enabled-in-project-settings-but-not-installed](https://code.claude.com/docs/en/plugins/loading#enabled-in-project-settings-but-not-installed)). Fetching happens only when user settings, untracked local settings, `--settings`, or managed settings set the plugin to `true`. The same section covers relative-path plugins in a git marketplace, which load for the current session only, without an install.
- **`extraKnownMarketplaces`:** it registers the marketplace. Marketplace records are per user, in `known_marketplaces.json` ([plugins/loading#check-which-stage-a-plugin-reached](https://code.claude.com/docs/en/plugins/loading#check-which-stage-a-plugin-reached)). No install record is documented.
- **Trust prompt:** it gates whether project-scope plugins load ([plugins/loading#trust-check-and-component-limits-for-repository-plugins](https://code.claude.com/docs/en/plugins/loading#trust-check-and-component-limits-for-repository-plugins)). Creating a record is not documented.
- **`claude plugin install --scope project`** (and the `/plugin` "Install for all collaborators" option): this is the documented trigger ([plugins/install#choose-an-install-scope](https://code.claude.com/docs/en/plugins/install#choose-an-install-scope), [plugins/cli-reference#plugin-install](https://code.claude.com/docs/en/plugins/cli-reference#plugin-install)).

Your automatic 2.1.5 record at session open (installedAt `2026-11-09T00:00:37.619Z`) matches none of the documented triggers. I could not identify the trigger from the docs.

**2. Desired state: one user install, project only enables or disables**

- **(a) Disable at project level.** Yes. The highest-precedence source that mentions the plugin wins ([plugins/loading#find-where-a-plugin-is-enabled](https://code.claude.com/docs/en/plugins/loading#find-where-a-plugin-is-enabled)). A `false` in the committed `.claude/settings.json` overrides the user `true` for everyone in the repo. A `false` in `.claude/settings.local.json` opts out on your machine only, which the loading page names as the way to opt out of a project-enabled plugin.
  - Caution: `claude plugin disable` without `--scope` auto-detects in the order local, project, user ([cli-reference#plugin-disable](https://code.claude.com/docs/en/plugins/cli-reference#plugin-disable)). Inside the repo it would write to the committed file. Always pass `--scope local`.
- **(b) Enable by inheritance.** Yes. A user-scope enable applies in every project ([plugins/install#choose-an-install-scope](https://code.claude.com/docs/en/plugins/install#choose-an-install-scope)). The loading page's advice for project-enabled plugins is "use `--scope user` to cover all your projects" ([plugins/loading#enabled-in-project-settings-but-not-installed](https://code.claude.com/docs/en/plugins/loading#enabled-in-project-settings-but-not-installed)). That sentence is written for a plugin enabled only in project settings, which is not your case. Writing `true` in project settings is documented as not installing anything. Your observed record contradicts that, and the docs do not explain why.
- **(c) Precedence for `enabledPlugins`:** `--add-dir` (lowest), then user, project, local, flag, managed (highest). Values merge per plugin ID ([plugins/loading#find-where-a-plugin-is-enabled](https://code.claude.com/docs/en/plugins/loading#find-where-a-plugin-is-enabled)).

**3. Removing only the project-scope record**

- Command: `claude plugin uninstall <name>@<marketplace> --scope <user|project|local>`, default scope `user` ([cli-reference#plugin-uninstall](https://code.claude.com/docs/en/plugins/cli-reference#plugin-uninstall)).
- The docs say the uninstall fails with `settings_still_on` if that scope's settings still enable the plugin. Your committed `true` would therefore block it. The docs do not say the CLI removes the settings entry itself.
- The `/plugin` Installed-tab uninstall of a project-enabled plugin offers "Uninstall for everyone", which removes the entry from the shared `.claude/settings.json` ([plugins/install#uninstall-a-plugin-the-project-enables](https://code.claude.com/docs/en/plugins/install#uninstall-a-plugin-the-project-enables)). The paragraph does not say whether the install record is also removed.
- **Not documented:** whether the uninstall needs to run from inside the project directory. I would run it from the repo root.
- **Hand-editing `installed_plugins.json`:** the docs neither endorse nor forbid it. They describe the file as a record. I would not hand-edit it.

**4. Which version loads with two records**

Not documented. Each record has its own `installPath` and `version` ([plugins/loading#check-which-stage-a-plugin-reached](https://code.claude.com/docs/en/plugins/loading#check-which-stage-a-plugin-reached)). The loading page does not say which one a session uses when both exist. Your user record is 2.1.7, the project record is 2.1.5, and the marketplace is at 2.1.7. Removing the project record makes the question moot.

**5. Updating project-scope installs**

- `claude plugin update <name>@<marketplace>` updates one scope per command. Without `--scope` it picks the most specific scope for the current project, checking local, project, user, managed ([cli-reference#which-scope-the-command-updates](https://code.claude.com/docs/en/plugins/cli-reference#which-scope-the-command-updates)). Run from the repo, it updates the 2.1.5 project record and leaves the user record alone. Use `--scope user` for the user record. The docs describe no all-scopes flag.
- The `/plugin` Marketplaces tab's "Update marketplace" updates "the plugins you installed from it" ([plugins/install#update-plugins-now](https://code.claude.com/docs/en/plugins/install#update-plugins-now)). It does not say whether that covers every scope.
- Auto-update: context-mode is a third-party marketplace, and auto-update is off by default for those ([plugins/install#keep-plugins-updated](https://code.claude.com/docs/en/plugins/install#keep-plugins-updated)). Your `known_marketplaces.json` has no `autoUpdate` key for it (`/Users/n8/.claude/plugins/known_marketplaces.json`), so auto-update does not apply. The docs do not say which scopes auto-update covers if it were on.

**6. Per-project plugin configuration**

- **Plugin options:** `pluginConfigs` is scoped to "User or managed" ([settings-reference#pluginconfigs](https://code.claude.com/docs/en/settings-reference#pluginconfigs)). Option values are therefore user-level. I found no documented per-project mechanism for them. Hook processes receive them as `CLAUDE_PLUGIN_OPTION_<KEY>` ([plugins/manifest-reference#user-configuration](https://code.claude.com/docs/en/plugins/manifest-reference#user-configuration)).
- **`env`:** the docs say `env` applies "for every session and for the subprocesses Claude Code starts" ([settings-reference#env](https://code.claude.com/docs/en/settings-reference#env)). Project-level `env` applies after workspace trust. When more than one file sets a variable, the highest-precedence file wins, so project beats user. `CTX_REPLACE_TRIGGER_BYTES` is not on the documented ignore list ([settings-reference#variables-claude-code-ignores-in-env](https://code.claude.com/docs/en/settings-reference#variables-claude-code-ignores-in-env)), so it should not be dropped.
  - **Inferred, not confirmed:** that the value reaches plugin hooks and MCP servers. The docs say "subprocesses" and do not name them.
  - **Not documented:** whether a running MCP server picks up a changed env. Restart the session to be sure.
  - The meaning of `CTX_REPLACE_TRIGGER_BYTES` is context-mode's, not Anthropic's.

## Recommended procedure

Your current state: user record 2.1.7, project record 2.1.5 for `/Users/n8/git/graph`, and a committed `"context-mode@context-mode": true` at `/Users/n8/git/graph/.claude/settings.json`, with no `extraKnownMarketplaces` or `pluginConfigs` there.

Run from `/Users/n8/git/graph` unless noted. Always pass `--scope`.

1. Confirm the current records: `claude plugin list`
2. Remove the committed enable, which is what makes the project record matter. Pick one:
   - (a) In a session, `/plugin` → Installed → context-mode → Uninstall → press `u` ("Uninstall for everyone"). Then check that the project record is gone.
   - (b) Delete the `"context-mode@context-mode": true` line from `.claude/settings.json`, then run `claude plugin uninstall context-mode@context-mode --scope project`.
   Either way this is a tracked-file change. Collaborators then need their own user-level enable.
3. Verify in a new session: `claude plugin list` should show one row, scope user, version 2.1.7.
4. Only if you want this project off: `claude plugin disable context-mode@context-mode --scope local`. This writes `false` to the gitignored `.claude/settings.local.json`.
5. Only if you want a per-project env value: put `"env": {"CTX_REPLACE_TRIGGER_BYTES": "65536"}` in `.claude/settings.local.json` (per machine) or `.claude/settings.json` (shared). Restart the session. Verify with `/context-mode:ctx-doctor`. Whether the value reaches the hooks and MCP server is unconfirmed.
6. Keep updates on the user record: `claude plugin update context-mode@context-mode --scope user`. Expect "already at the latest version" (2.1.7).

**Steps whose behaviour I could not confirm from the docs:**
- Whether the uninstall needs the repo as cwd.
- Whether `/plugin` "Uninstall for everyone" removes the install record or only the settings entry.
- What triggers the automatic project record, and whether it recurs after step 2. Check `claude --debug` output for the next session to see whether it reappears.
- Which version loads when both records exist.
- Whether `env` reaches plugin hooks and MCP servers, and whether a running MCP server sees a changed value.
- Whether hand-editing `installed_plugins.json` is supported. I recommend against it, but the docs are silent.

For a gap in these docs, use `/feedback`.

Sources:
- https://code.claude.com/docs/en/plugins/overview
- https://code.claude.com/docs/en/plugins/install
- https://code.claude.com/docs/en/plugins/loading
- https://code.claude.com/docs/en/plugins/cli-reference
- https://code.claude.com/docs/en/plugins/manifest-reference
- https://code.claude.com/docs/en/settings-reference

