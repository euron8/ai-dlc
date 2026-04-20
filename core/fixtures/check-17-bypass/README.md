# Check 17 (Skill-Invocation Provenance) Bypass Fixture

Scenarios (five variants):
- V1: retro-shaped doc with no provenance block at all
- V2: block present but tool_use_id stripped
- V3: block present but skill field names an unknown skill
- V4: retro party-mode block with transcript_path in wrong format
      (missing @<sha> suffix)
- V5: retro party-mode block citing a transcript SHA that does not
      byte-match the file contents on HEAD

V1-V4 fail validate-provenance-block.sh.
V5 passes that script but fails validate-retro-evidence.sh.

Run `seed.sh` to reproduce idempotently.
