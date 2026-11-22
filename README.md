# Builder — AI Development Workspace

A local-first desktop workspace built with **Godot 4.2+** to manage GitHub repositories, authorized accounts, Git mirrors and CI run status.

**Status: early MVP.** This is a Godot project, not a packaged installer. Native ChatGPT embedding, OAuth onboarding, billing quota metrics and automatic CI failover are not yet implemented.

## Run locally

1. Install Godot 4.2+, Git and GitHub CLI (gh).
2. In a terminal run: gh auth login -h github.com. Repeat for accounts you are authorized to use.
3. Open project.godot in Godot and run the project (F5).
4. In Settings provide absolute paths to Git / gh if the GUI environment does not contain them in PATH.
5. Add GitHub usernames in Accounts and explicitly activate one with gh auth switch.
6. Add projects: primary repo owner/repo, absolute checkout directory, branch, and optional mirrors owner/repo.
7. Clone, fetch, inspect the latest Actions run or push the configured branch to mirrors after confirmation.

The app does not accept or persist GitHub tokens, passwords or ChatGPT cookies. GitHub authentication uses gh credential storage; HTTP Git pushes depend on existing Git credential configuration (e.g. gh auth setup-git).

## MVP features

- Russian-language Godot desktop interface, locally saved project/account references.
- GitHub CLI account switching, checked against gh api user.
- Git clone and non-destructive fetch.
- Verified-origin, clean-worktree, exact-commit checks before a **non-force**, explicitly approved mirror push. Divergent mirror branches are rejected.
- Latest GitHub Actions run state (not an account quota measure).
- Open ChatGPT in the system browser.
- Configurable paths for Git and gh.

## Limitations

- Operations run synchronously and may block the UI. A production release should use background workers.
- Mirroring copies a single selected Git branch. It does **not** clone GitHub issues, PRs, workflow history, branch protections or repository secrets.
- Pushes to mirrors can trigger workflows and incur GitHub Actions usage.
- ChatGPT is currently a browser shortcut, not an embedded authenticated chat or a plugin controlling Builder.
- **Switching GitHub users cannot refill the billing owner's exhausted Actions quota.** GitHub bills Actions usage to the repository owner. Avoid maintaining multiple free personal accounts to work around service limits.
- This project has not been compiled or smoke-tested in Godot in the authoring environment.

See ARCHITECTURE.md and SECURITY.md for the supported design and next steps.

## Planned

Async native sidecar for Git/GitHub API calls, properly scoped OAuth, signed installers, CI usage visibility with owner permissions, optional self-hosted runner fallback, native WebView experimentation, and authorized ChatGPT Responses API / open-source Sign in with ChatGPT or a plugin/MCP integration.
