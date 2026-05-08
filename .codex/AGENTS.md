# Repository Guidelines

## Commit Messages

Use the conventional `type: subject` format for every commit.

- Use a lowercase type followed by a colon and one space.
- Keep the subject concise, imperative, and without a trailing period.
- Start the subject in lowercase unless the word is a proper noun, acronym, file name, or version.
- Preserve required capitalization for names such as `README`, `OpenCode`, `macOS`, `GitHub`, `iTerm2`, and version strings such as `v0.2.0`.

Allowed commit types:

- `feat`: user-facing feature or behavior addition
- `fix`: bug fix
- `docs`: README, changelog, installation, or other documentation changes
- `test`: test additions or updates
- `refactor`: code structure changes without intended behavior change
- `chore`: maintenance, packaging, scripts, project metadata, or dependency housekeeping
- `release`: release commits and version publication changes

Examples:

- `docs: add Korean README`
- `docs: improve README discoverability`
- `release: v0.2.0`
- `chore: add local release packaging script`
- `feat: avoid stealing focus for explicit new sessions`

Do not use title-only or title-case messages such as:

- `Add Korean README`
- `Improve README discoverability`
- `Release v0.2.0`

## Atomic Commit Boundaries

- Split commits by one clear purpose: feature behavior, UI structure, tests, documentation, assets, or maintenance.
- Keep each commit independently explainable from its subject and diff.
- Do not mix repo-local rules, app behavior, generated assets, and README changes unless they are part of the same user-visible outcome.
- Stage intentionally and inspect each staged diff before committing.

Before pushing commits, check the recent history with:

```bash
git log --oneline --decorate -8
```

If a just-created local commit does not follow this format, amend it before pushing:

```bash
git commit --amend -m "type: subject"
```

If a non-conforming commit has already been pushed to a shared branch, only rewrite history when explicitly requested. Use `--force-with-lease` for branch updates and move any affected release tags to the rewritten release commit.
