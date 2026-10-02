# App templates

Examples to copy when the first real app lands. Nothing here is wired into CI, the dev stack or the
deploy; they only become active once copied. The TypeScript files are for the React frontend (and a
TypeScript backend, if that is the choice); everything outside `apps/<name>/` stays
language-agnostic.

| File | Copy to | What it does |
|---|---|---|
| `compose.ci.yml.example` | `compose.ci.yml` (repo root) | The CI test run: `postgres:18` with a `pg_isready` healthcheck; `migrate` and `test` start once it is healthy. |
| `eslint.config.example.mjs` | `apps/<name>/eslint.config.mjs` | ESLint flat config, every rule an error. |
| `tsconfig.example.json` | `apps/<name>/tsconfig.json` | TypeScript 6 strict baseline. |

## compose.ci.yml

CI and `scripts/ci/local-gate.sh` run `migrate` (when the service exists), then `test`, each with
`docker compose -p <project> -f compose.ci.yml run --rm`, then `down -v --rmi local`.

- `migrate` builds the production image and runs the same command as `MIGRATE` in
  `deploy/services/<name>.env`, so CI applies migrations exactly as the deploy does. Keep the two in
  sync.
- `test` builds a `test` stage of the app's Dockerfile (the one with dev dependencies) and runs lint,
  then typecheck, then unit tests. The first failure stops it; its exit code is the result.
- Replace `web`, the commands and `DATABASE_URL` with what the app uses.

## eslint.config.mjs

ESLint flat config (written for ESLint 9; the same file works on ESLint 10) with `typescript-eslint`:

- `eslint-plugin-sonarjs`: `no-collapsible-if`, `no-identical-functions`, `no-duplicated-branches`,
  `cognitive-complexity` 15, `no-commented-code`.
- `@vitest/eslint-plugin` on `*.test.*` and `*.spec.*`: `no-focused-tests`, `no-disabled-tests`,
  `no-commented-out-tests`, `expect-expect`.
- `@typescript-eslint/ban-ts-comment`: `@ts-expect-error` only with a description; `@ts-ignore` and
  `@ts-nocheck` banned.
- `@eslint-community/eslint-plugin-eslint-comments`: `require-description`, `no-unlimited-disable`.
- `linterOptions.reportUnusedDisableDirectives: "error"`: a stale disable comment fails the lint.

All rules are errors: an empty app has nothing to grandfather, so there is no warning baseline.

## tsconfig.json

`strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `noImplicitOverride`,
`verbatimModuleSyntax`, `noEmit` (`tsc` only typechecks; the bundler or build step emits). Module
settings are for a bundler (Vite); a Node backend without a bundler uses `"module": "nodenext"` and
drops `moduleResolution`. A React app adds `"jsx": "react-jsx"` and the DOM libs.

## SQL migrations

Lint migrations with [squawk](https://squawkhq.com) (npm `squawk-cli`, a dev dependency of the app
that owns the migrations) in the `test` step. Its default rules match "Database changes" in
`CLAUDE.md`: `require-concurrent-index-creation` (`CREATE INDEX CONCURRENTLY`),
`constraint-missing-not-valid` (`NOT VALID`, then `VALIDATE` in a later migration),
`require-lock-timeout` and `require-statement-timeout`. Any finding exits non-zero.

New migration files against `main`:

```
git diff --name-only --diff-filter=A origin/main -- 'apps/<name>/migrations/*.sql' | xargs -r npx squawk --pg-version=18 --assume-in-transaction
```

The `test` container has no git history, so there it lints every migration
(`squawk --pg-version=18 --assume-in-transaction migrations/*.sql`); older files passed when they
were new, so only new ones can fail. `--assume-in-transaction` is for migration tools that wrap each
file in a transaction. `CREATE INDEX CONCURRENTLY` cannot run in one, so it goes in its own
no-transaction file, linted without that flag (with it, squawk reports
`ban-concurrent-index-creation-in-transaction`).
