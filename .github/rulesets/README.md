# Rulesets

The repository settings must keep the squash commit title at `PR_TITLE`, because the `pr-title` check validates the PR title.

GitHub enforces a file here only after someone applies it. A merge does not apply it. Ruleset IDs differ per repository, so look them up by name.

List the live rulesets:

```bash
gh api repos/{owner}/{repo}/rulesets --jq '.[] | "\(.id) \(.name)"'
```

Apply a file. Use `PUT` with the ID of the same name, or `POST` when the name is not live yet:

```bash
gh api -X PUT repos/{owner}/{repo}/rulesets/<id> --input .github/rulesets/main.json
gh api -X POST repos/{owner}/{repo}/rulesets --input .github/rulesets/tags.json
```

Check for drift. An empty diff means the live ruleset matches the file:

```bash
keys='{name, target, enforcement, conditions, bypass_actors, rules}'
diff <(gh api repos/{owner}/{repo}/rulesets/<id> | jq -S "$keys") <(jq -S "$keys" .github/rulesets/main.json)
```
