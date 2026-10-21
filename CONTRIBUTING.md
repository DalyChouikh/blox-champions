# Contributing

## Workflow

1. Every change starts from a GitHub issue in a milestone.
2. Create a branch named `<type>/<issue>-<slug>`, where `<type>` is one of `feat`, `fix`, `chore`, `docs`, `test`. Example: `feat/12-lap-tracker`.
3. Open one pull request per issue. Its description contains `Closes #<issue>`.
4. CI (`quality` check) must be green before the pull request is merged into `main`.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/): `<type>(<area>): <summary>`.

```
test(rules): lap streak resets on opponent pickup
feat(rules): reset lap streak when the other team picks up the ball
```

Keep commits small and focused; a test and the code that makes it pass land together.

## Test-driven development

1. Write a failing test for the behavior.
2. Run it and watch it fail for the expected reason.
3. Write the minimal code that makes it pass.
4. Run the suite again, then refactor while it stays green.

Tests live in `tests/`, mirror the `src/` folders, and are named `<Module>.spec.luau`. Import every Jest function from `JestGlobals`. See [Running tests](README.md#running-tests).

## Code rules

- Every `.luau` file starts with `--!strict`.
- Formatting is StyLua (`stylua src tests scripts`); linting is selene (`selene src tests scripts`). CI fails on either.
- Inside `src/`, require siblings relative to `script`; tests require through service paths (`ReplicatedStorage.Shared...`).
- Gameplay numbers live in `src/shared/Config/`, never hard-coded in logic.
