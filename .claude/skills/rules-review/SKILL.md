---
name: rules-review
description: Checks the branch diff and the draft PR title and body against the writing rules in AGENTS.md and docs/conventions.md. Run it before you open or update a PR or publish other text.
argument-hint: "[draft PR title and body]"
context: fork
agent: general-purpose
background: false
---

# Rules review

Review a change against the rules of this repository. Edit nothing.

1. Read the sections from "All files" to "YAML and workflows" in `AGENTS.md`. Read `docs/conventions.md`.
2. Run `git diff origin/main...HEAD`. Read a changed file when a hunk needs more context.
3. Read the draft published text that follows. If it names a file, read that file. If it is empty, review only the diff.

$ARGUMENTS

4. Check each added or changed line and the published text against the rules. Do not report a line that the change does not add.
5. Report one bullet per finding: `path:line` or `PR title` or `PR body`, the rule that it breaks, and the fix. Quote the rule.
6. If there are no findings, write `No findings.` Write nothing else.
