# App templates

Nothing here runs in CI or in the deploy until you copy it. The templates fit a Node app in the pnpm workspace and assume no framework.

| File | Copy to |
|---|---|
| `Dockerfile.example` | `apps/<name>/Dockerfile` |
| `compose.ci.yml.example` | `compose.ci.yml` at the repository root |
| `eslint.config.example.mjs` | `apps/<name>/eslint.config.mjs` |
| `tsconfig.example.json` | `apps/<name>/tsconfig.json` |

## Steps

1. Create `apps/<name>/` with a `package.json`. Its `name` is the folder name.
2. Copy the files to the paths in the table. Replace `web` with the folder name.
3. Write `deploy/services/<name>.conf` with the keys in "Service contract" of `AGENTS.md`.
4. Set `command` of `migrate-<name>` to the same words as `MIGRATE` in `deploy/services/<name>.conf`.
5. Remove the placeholder as "Rules" in `AGENTS.md` requires.
6. Run `pnpm install` at the repository root, so that `pnpm-lock.yaml` has the app. Then run `bash scripts/ci/local-gate.sh`.
7. If pnpm stops on a build script of a dependency, add the package to `allowBuilds` in `pnpm-workspace.yaml`. Set `true` to run the script or `false` to skip it. The Docker build reads the same file.

## App package

| Item | Value |
|---|---|
| Scripts | `build`, `lint`, `typecheck` and `test`. The `test` target of the Dockerfile runs the last three in the app and each workspace package it uses. |
| `files` | `dist` and `migrations`. `pnpm deploy` copies only these into the shipped image. |
| Start | `CMD` of the Dockerfile. It runs `dist/main.js`. |
| Listen | `$PORT` with no host argument. Node then listens on IPv4 and IPv6. |
| Database | The connection URL in the variable that `compose.ci.yml.example` sets. Production gets the same name from Vault. |
| TypeScript | `pnpm --filter <name> add -DE typescript@6.0.3 @types/node`. Keep the exact pin. `docs/adr/0002-typescript-6.md` gives the reason. |

- A workspace package that the app uses also needs a `build` script and `files`, if it has a build output. The filtered build in the Dockerfile builds it first.
- A Node backend that `tsc` compiles sets `"module": "nodenext"`, `"rootDir": "src"` and `"outDir": "dist"` in `tsconfig.json`.
- That backend removes `moduleResolution` and `noEmit` from `tsconfig.json`.

## Migrations

- `MIGRATE` runs in the shipped image. The deploy splits it into words and runs no shell.
- Write `MIGRATE` as one command, for example `node dist/migrate.js`. `sh -c "a && b"` does not work.
- In CI, `migrate` waits for each `migrate-<name>`. When two apps share tables, the later `migrate-<name>` lists the earlier one in `depends_on`.
- `test` starts the app again, so `migrate-<name>` runs a second time. A migration run that finds nothing to do must exit 0.

## CI

- `probe-<name>` checks `/health` on the shipped image over IPv4 and IPv6, on a port that is not the image default.

## SQL migrations

Lint migrations with [squawk](https://squawkhq.com) (npm `squawk-cli`) in the `test` stage. Its default rules match "Database changes" in `AGENTS.md`. On a host with git history, lint the new migration files:

```
git diff --name-only --diff-filter=A origin/main -- 'apps/<name>/migrations/*.sql' | xargs -r npx squawk --pg-version=<major> --assume-in-transaction
```

- `<major>` is the Postgres major version in the `FROM` line of `deploy/postgres/Dockerfile`.
- The `test` container has no git history. There, lint all files with `squawk --pg-version=<major> --assume-in-transaction migrations/*.sql`.
- `--assume-in-transaction` is for migration tools that wrap each file in a transaction.
- Put `CREATE INDEX CONCURRENTLY` in a separate file without a transaction. Lint that file without `--assume-in-transaction`.
