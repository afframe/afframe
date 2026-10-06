# Conventions

## Naming

- File names are lowercase with dashes unless a repository contract or tool requires a fixed name, such as `AGENTS.md`, `ARCHITECTURE.md` or `Dockerfile`. Host commands are `deploy/bin/afframe-<verb>`. CI scripts are `scripts/ci/<noun>.sh`.
- A test is `<script>.test.sh` next to its script. Tests for `deploy/` are in `deploy/test/`, which the deploy does not ship.
- Environment inputs of the host commands in `deploy/bin/` are `AFFRAME_<NAME>`. Standard client variables of a tool keep their names, such as `VAULT_ADDR`. Script locals are lowercase.
- Persistent volume names stay literal `name:` values in `deploy/compose.prod.yml`. A rename detaches the data. A deploy test asserts these names.
- In `deploy/` outside `deploy/test/`, and in the deploy workflow, build all other Docker object names from the project name. Do not type a full name such as `afframe-postgres` again. Dev and CI scripts can type their own names.

## Configuration

| Value | Single source | Readers use |
|---|---|---|
| Project name and the Docker names built from it | `name:` in `deploy/compose.prod.yml`, constants in `deploy/bin/common.sh` | `${COMPOSE_PROJECT_NAME}`, the shell constants |
| Postgres user, database, stanza, data path | `ENV` in `deploy/postgres/Dockerfile` | the container environment |
| Service host name, port, memory, migration | `deploy/services/<name>.conf` | `read_vars` |
| Deploy target (user and host) | one repository secret | `.github/workflows/deploy.yml`, through the secret context |
| Switches and settings such as `DEPLOY_ENABLED` and `CLAUDE_REVIEW_OWNER` | repository variable | the `vars` context |
| `AFFRAME_HOME` | default in `deploy/bin/common.sh`, or the environment | the host scripts |
| Vault address and Vault path | `$AFFRAME_HOME/host.conf` | `vault-env` |
| systemd `User=` | a host drop-in, documented in `$INTERNAL` | systemd |
| Runtime credentials | Vault | `deploy/bin/vault-env` |
| Schedules | `deploy/host/systemd/*.timer`, and `on.schedule` in each scheduled workflow for its own | systemd and GitHub Actions. Documents name the file. |
| Image, action and tool versions | the pin line | Dependabot |

- Some files cannot read a variable: Traefik static config, `on.push.branches`, `.github/CODEOWNERS` and `afframe-receive`, which runs before a release exists. Keep the value there once. The reader names that file in a 1-line comment, and a test proves the match when a second copy is in the repository.
- `.github/workflows/deploy.yml` keeps host path literals. A 1-line comment points to `deploy/bin/common.sh`. Actions logs are public. Never echo an absolute host path.
- Tests keep literal expected values. A test that reads a value from the code under test cannot find a change.

## Documents

| Fact | File |
|---|---|
| Rules for agents and contributors | `AGENTS.md` |
| The system as it is now | `ARCHITECTURE.md` |
| Names and the source of each value | `docs/conventions.md` |
| A decision and its reasons | `docs/adr/` |
| Private facts | `$INTERNAL`, as "All files" in `AGENTS.md` states |
| Facts about one app | `apps/<name>/README.md`, when the file exists |

- `AGENTS.md` section Rules tells when to write an ADR.
- The status of an ADR is `Accepted` or `Superseded by NNNN`.
- A proposal is an issue, not a document.
- Each new document gets a row in the index table of `README.md`. The `docs/adr/` row covers each ADR.
