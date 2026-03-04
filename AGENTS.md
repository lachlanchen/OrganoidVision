# Repository Guidelines

## Project Structure & Module Organization
This repository is currently an initial scaffold. Add code using a predictable layout so contributors can onboard quickly:
- `src/`: application code, organized by feature (for example, `src/sensors/`, `src/pipeline/`).
- `tests/`: mirrors `src/` structure (for example, `tests/sensors/test_reader.*`).
- `assets/`: static resources such as sample datasets, diagrams, or calibration files.
- `docs/`: design notes, architecture decisions, and API references.

Keep modules focused and small. Prefer feature-based folders over large utility dumps.

## Build, Test, and Development Commands
No build tooling is committed yet. When introducing tooling, expose a minimal, standard command set and document it here:
- `make setup`: install dependencies and prepare local environment.
- `make test`: run the full test suite.
- `make lint`: run static checks and formatting validation.
- `make run`: start the main local workflow.

If `Makefile` is not used, provide equivalent commands in project scripts (for example, `npm run test` or `pytest`).

## Coding Style & Naming Conventions
- Use 4-space indentation for Python and 2 spaces for JS/TS/YAML.
- Use `snake_case` for Python modules/functions, `PascalCase` for classes, and `camelCase` for JS/TS variables/functions.
- Name files by responsibility (`sensor_reader.py`, `signal_filter.ts`).
- Run an auto-formatter and linter before commits (for example, `black`/`ruff` or `prettier`/`eslint`, depending on stack).

## Testing Guidelines
- Place unit tests under `tests/` with names like `test_<module>.*`.
- Add integration tests for cross-module workflows.
- Aim for meaningful coverage on core logic paths; include edge cases and failure modes.
- Ensure tests run locally via one documented command (`make test` or equivalent).

## Commit & Pull Request Guidelines
This repository has no commit history yet. Adopt Conventional Commits going forward:
- `feat: add signal normalization step`
- `fix: handle missing sensor timestamps`
- `docs: update setup instructions`

For PRs, include:
- clear summary of what changed and why,
- linked issue (`Closes #123`) when applicable,
- test evidence (command output or checklist),
- screenshots/log snippets for UI or pipeline behavior changes.

## Security & Configuration Tips
Do not commit secrets, credentials, or raw sensitive data. Keep local overrides in ignored files (for example, `.env.local`) and provide safe defaults in tracked example configs.

## Agent-Specific Workflow Rule
After any edit to `AGENTS.md`, immediately run:
1. `git add AGENTS.md`
2. `git commit -m "docs: update AGENTS guidelines"`
3. `git push`
