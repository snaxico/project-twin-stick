# Solo Dev Rules

## Working Model

- Build one vertical slice at a time.
- Prefer the smallest testable version of a system.
- Expand only after the current slice is runnable and documented.

## AI-Assisted Change Control

- Give AI one bounded task at a time.
- Do not let AI modify multiple untested systems in one pass.
- Review generated code before treating it as accepted.
- Record important AI-assisted design or architecture changes in docs.

## Git Rule

- Git is required.
- Commit only after a patch or sub-feature is working.
- Never commit a broken intermediate state as if it passed validation.

## Documentation Rule

- Read `current-state.md` and the latest history entry at the start of work.
- Update `current-state.md` and session history after meaningful work.
- If implementation changes scope or architecture, update the relevant process doc in the same slice.

## Definition Of Done

Work is done only when:

- the intended behavior exists
- the behavior matches current scope
- the result is understandable
- the important docs are updated
- the next step can be picked up without guessing

