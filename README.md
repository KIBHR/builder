# Builder — AI Development Workspace

Godot 4.2+ desktop workspace for managing GitHub projects with **native in-app AI chat** via the official [OpenAI Responses API](https://developers.openai.com/api/reference/resources/responses/methods/create).

**Status:** development MVP. A signed installer and live API acceptance testing are still pending.

## What's included

- GitHub CLI accounts, Git clone/fetch, a GitHub Actions latest-run status view and explicit, non-force mirror branch push.
- **ChatGPT · в Builder**: conversation interface, configurable OpenAI model, in-memory multi-turn history, attach one chosen project source file (48 KiB max), copy latest assistant answer, cancel/clear conversation.
- **Windowed / fullscreen**: upper-right mode button, or **F11**. The app restores the previous non-fullscreen window mode, including size/position.
- Russian-language interface.

## Running

1. Install **Godot 4.2+**, Git and [GitHub CLI](https://cli.github.com/).
2. Import `project.godot` into Godot and run (F5).
3. For GitHub access, run `gh auth login -h github.com` and optionally `gh auth setup-git` in a terminal.
4. For native AI chat, create an **OpenAI Platform API key**. Either set `OPENAI_API_KEY` before starting Builder or paste it into **ChatGPT · в Builder → Подключить**. The key is held in process memory only and is not saved in the project or settings.
5. Select a model: `gpt-6.2-sol` (default), `gpt-6-luna`, `gpt-6.2-astra`, or `gpt-5.4-mini` (subject to your account availability). Type a message, click **Отправить** or press **Ctrl+Enter** / **Cmd+Enter**.
6. Optionally select a registered project. The repo name and branch are included in system context; only specifically attached source files are included in the message body. No automatic repository access or code editing is performed.
7. Toggle fullscreen with the header button or **F11**.

## ChatGPT API vs ChatGPT website

**Important:** The built-in panel uses the official OpenAI **API**, not an embedded copy of the chatgpt.com website. ChatGPT Plus/Pro subscriptions and API billing are separate. Your ChatGPT.com login/history is not shared with Builder. A separate commercial **Sign in with ChatGPT** integration would require the supported developer flow and eligibility; it is not implemented. The side link still opens the ChatGPT website externally.

## Privacy

- Only the requested message, up to ten prior chat messages, any explicitly attached text file (max 48 KiB), and the chosen repo name/branch go to OpenAI via HTTPS.
- `store: false` is sent in each Responses request. Provider-side retention terms still apply.
- Chat messages, API key and attached contents stay only in **RAM**; **Новый чат** clears memory history, and quitting Builder discards it.
- `user://builder.json` stores nonsecret GitHub/project metadata and selected model, **never secrets**.
- GitHub CLI handles its own credentials.

## Boundaries and status

GitHub Actions usage is billed to repository owners; switching logged-in GitHub accounts cannot refill an exhausted owner's quota. Mirror pushes may trigger CI and affect usage. No automatic quota circumvention is implemented.

Godot scripts must still pass CI and manual cross-platform testing before considering this production-ready. Git CLI operations are synchronous in the current MVP; OpenAI HTTP calls are asynchronous.

See [ARCHITECTURE.md](ARCHITECTURE.md) and [SECURITY.md](SECURITY.md).
