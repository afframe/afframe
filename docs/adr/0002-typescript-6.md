# ADR 0002: TypeScript 6

| Property | Value |
|---|---|
| Date | 2026-10-06 |

## Context

- The project lints TypeScript with typescript-eslint.
- The typescript-eslint peer range accepts `typescript` only below 6.1.

## Decision

- The project uses TypeScript 6.0. `docs/templates/app/README.md` holds the exact pin.
- Dependabot ignores major and minor updates of `typescript`, so the pin stays inside that peer range.

## Consequences

- Type checks and lint use one TypeScript version.
- A TypeScript update past 6.0 waits until the typescript-eslint peer range accepts it. That change also updates the Dependabot ignore.
