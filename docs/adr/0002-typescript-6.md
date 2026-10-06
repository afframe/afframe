# ADR 0002: TypeScript 6

| Property | Value |
|---|---|
| Status | Accepted |
| Date | 2026-10-06 |

## Context

- TypeScript 7 exposes no classic compiler API.
- typescript-eslint does not support TypeScript 7. Version 8.71.1 needs `typescript` lower than 6.1.

## Decision

- The project uses TypeScript 6.0. `docs/templates/app/README.md` holds the exact pin.
- Dependabot ignores major and minor updates of `typescript`. typescript-eslint rejects 6.1.
- The move to TypeScript 7 waits for typescript-eslint support.

## Rejected options

| Option | Reason |
|---|---|
| TypeScript 7 | typescript-eslint does not support it (Context). |

## Consequences

- Type checks and lint use one TypeScript version.
- A move to TypeScript 7 is a separate change. It also removes the Dependabot ignore.
