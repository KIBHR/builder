# Builder Architecture

- **Godot desktop shell**: `scenes/main.tscn` + `scripts/workspace.gd` (Projects / Accounts / Settings / ChatGPT, F11 fullscreen button).
- **AI chat UI**: `scripts/chat_panel.gd` (message input, model choice, selected-project context, explicit file attachment, conversation display).
- **OpenAI API client**: `scripts/openai_client.gd` (asynchronous POST to `https://api.openai.com/v1/responses`, TLS via Godot, `store: false`, bounded input and output, session-only API key).
- **Local config**: `scripts/data_store.gd` writes `user://builder.json` atomically without credentials, chats or attached file text.
- **GitHub**: `scripts/cli.gd` invokes local Git / `gh` with literal argument arrays; the GitHub CLI manages login credentials.

The built-in chat deliberately uses the supported Responses API instead of copying ChatGPT browser cookies, manipulating login forms, or embedding a blocked iframe. Sign in with ChatGPT integration and access to your ChatGPT plan would require its own supported authorization and enrollment.

File context is only read when explicitly selected from a registered checkout and sent when user clicks Send. Model does not have access to any other files or the ability to edit the repository.

The F11 handler stores the prior Godot main Window mode, position and dimensions before entering fullscreen and restores them when leaving fullscreen.

Actions billing attaches to repository owners, not individual trigger users. Future CI continuity may use authorized self-hosted runners; bypassing limits by switching disposable accounts is unsupported.
