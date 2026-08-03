# Worked Example: Consolidating an Over-Atomized Plan

The original plan adds JSON config support to a small CLI: 7 tasks, each carrying its own test cycle (failing test → implement → run → commit).

## Before: 7 tasks

| # | Task | Files | Interfaces |
|---|------|-------|------------|
| 1 | Config type and defaults | src/config/types.ts | produces `Config`, `DEFAULT_CONFIG` |
| 2 | Config file loader | src/config/load.ts | consumes `Config`; produces `loadConfigFile()` |
| 3 | Env-var overrides | src/config/load.ts | consumes `Config`; produces `applyEnvOverrides()` |
| 4 | Config validation | src/config/validate.ts | consumes `Config`; produces `validateConfig()` |
| 5 | Wire config into CLI (`--config` flag, usage docs) | src/cli.ts, README.md | consumes tasks 2–4 |
| 6 | Replace `--verbose` with `--log-level` | src/cli.ts, README.md | independent behavior change |
| 7 | `withTempDir` test helper | test/helpers.ts | independent |

## Preview shown to the user

| Group | ← Tasks | Rationale | Files | Parallel (group numbers) |
|-------|---------|-----------|-------|----------|
| 1. Config module | 1–4 | One module (`src/config/`), unbroken Consumes/Produces chain; a reviewer approves or rejects config loading as a whole | src/config/*, test/config/* | Parallel-safe with groups 3, 4 |
| 2. CLI wiring | 5 | Merge signal with group 3 exists (same `src/cli.ts`) but fails the deciding test — see below | src/cli.ts, README.md | Parallel-safe with group 4 |
| 3. Log-level flag | 6 | A reviewer could reject the flag rename while approving config wiring — independent review risk, merge refused | src/cli.ts, README.md | Parallel-safe with groups 1, 4 |
| 4. Test helper | 7 | No shared files or interfaces with any group | test/helpers.ts | Parallel-safe with groups 1–3 |

**7 tasks → 4 dispatch units, order preserved.**

## After (excerpt)

````markdown
### Task 1: Config module — types, loader, env overrides, validation

Merged from: original tasks 1–4
Parallel-safe with: Task 3, Task 4

**Files:**
- Create: `src/config/types.ts`
- Create: `src/config/load.ts`
- Create: `src/config/validate.ts`
- Test: `test/config/types.test.ts`
- Test: `test/config/load.test.ts`
- Test: `test/config/validate.test.ts`

**Interfaces:**
- Consumes: nothing
- Produces: `interface Config { theme: string; refreshMs: number }`, `const DEFAULT_CONFIG: Config`
- Produces: `loadConfigFile(path: string): Config` — missing file returns defaults, invalid JSON throws
- Produces: `applyEnvOverrides(config: Config): Config` — reads `STATUSBAR_THEME`, `STATUSBAR_REFRESH_MS`
- Produces: `validateConfig(config: Config): void` — throws `Error` listing every invalid field

- [ ] **Step 1: Write the failing test**

```ts
import { DEFAULT_CONFIG } from "../../src/config/types";

test("defaults are sane", () => {
  expect(DEFAULT_CONFIG.theme).toBe("dark");
  expect(DEFAULT_CONFIG.refreshMs).toBeGreaterThan(0);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run test/config/types.test.ts`
Expected: FAIL — cannot find module

…
````

The remaining stages of Task 1 are original tasks 1–4's steps continuing in order (steps 3..17): every failing test, every verification run, every commit, byte-identical to the original. 30 checkbox steps before, 30 after.

## The two judgment calls

- **Tasks 5 and 6 stayed separate.** A shared file is only a *signal*. The deciding test is the review gate: the flag rename is a breaking change a reviewer can reject on its own while approving the config wiring. Independent review risks — no merge.
- **Task 7 merged with nothing** (no signals) **yet earned a marker:** `Parallel-safe with: Task 1, Task 2, Task 3`. The plan still executes sequentially; the marker is a hint for parallel dispatch later.
