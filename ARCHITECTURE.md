# Builder Architecture

Godot 4 desktop shell
- Projects → local Git checkout → primary GitHub origin → approved mirror remotes.
- Accounts → GitHub CLI / credential manager (explicitly chosen user; no tokens stored).
- Actions → GitHub REST workflow run list, not remaining-balance information.
- ChatGPT → system browser for MVP, no cookies copied into the application.
- Preferences → user://builder.json with nonsecret settings only.

## Billing and failover

Actions usage on private repositories belongs to the owner or organization, not to the individual who starts a workflow. Switching gh users on the same repo therefore does not change its billing allocation.

For uninterrupted CI, prefer an authorized self-hosted runner or a separately administered organization with its own billing and approved workflows. A future CI router should require explicit opt-in, equivalent secrets and permissions, commit-SHA checks, audit logs, rate limits and safe rollback. It must not silently rotate disposable personal accounts to evade limits.

GitHub Actions allowances, OpenAI plan limits, Codex usage, GitHub Copilot quotas and GitHub API rate limits are separate concepts.

## ChatGPT options

The current MVP uses the browser. Native WebView in Godot is possible through GDExtension projects such as godot_wry, but third-party sign-in in embedded browsers is not guaranteed. For an app-native assistant, use the documented OpenAI Responses API or eligible Sign in with ChatGPT open-source plan-usage flow. Normal identity scopes do not grant existing ChatGPT conversation history. ChatGPT-first project controls require a separately authenticated plugin/MCP server.

## Roadmap

1. Asynchronous Git and GitHub worker (Rust or Go) and OS credential-store integration.
2. Explicit multi-organization permissions and genuine usage reporting.
3. Safely controlled CI backend selection with self-hosted fallback.
4. OpenAI integration and optional native WebView.
5. Tested, signed Windows/macOS/Linux installers.
