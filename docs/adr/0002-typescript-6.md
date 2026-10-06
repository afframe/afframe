# ADR 0002: TypeScript 6

| Property | Value |
|---|---|
| Status | Accepted |
| Date | 2026-10-06 |

## Context

- typescript-eslint needs the classic TypeScript compiler API.
- typescript-eslint 8.71.1 needs `typescript` lower than 6.1.

## Decision

- The project uses TypeScript 6.0. `docs/templates/app/README.md` holds the exact pin.
- Dependabot ignores major and minor updates of `typescript`. typescript-eslint rejects 6.1.
- A move past TypeScript 6.0 waits for typescript-eslint support.

## Consequences

- Type checks and lint use one TypeScript version.
- A move past TypeScript 6.0 is a separate change. It also updates the Dependabot ignore.
