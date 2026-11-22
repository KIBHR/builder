# Builder — AI Development Workspace

Builder is a **Godot 4 desktop** development workspace for GitHub repositories and an in-app AI assistant.

## New: Sign in with ChatGPT without an API key

Builder now offers **Continue with ChatGPT** through the [official Sign in with ChatGPT DevKit](https://github.com/openai/sign-in-with-chatgpt-devkit) for **open-source apps running on a user's own computer**. OAuth is handled in the system browser; Builder never asks for a ChatGPT password, browser cookie, API key, or unofficial Codex credential.

**Eligible ChatGPT Plus and Pro users** can approve access to their subscription allowance for supported AI requests; successful identity login alone is **not** enough. The app reads the permission flag and lists models actually available for the selected account. ChatGPT conversations from the website are **not** imported.

### Install once

Requirements: **Godot 4.2+**, Git, Node.js **22.12+**, npm, and an OS credential vault (macOS Keychain, Windows Credential Manager, or Linux Secret Service/keyutils).

In the cloned Builder checkout:

```sh
node bridge/setup.mjs
```

This command fetches a pinned revision of OpenAI's DevKit into the ignored `third_party/siwc-devkit/` directory, builds its `@siwc/local` package, and installs `@napi-rs/keyring` for Builder's local bridge. An internet connection is required for this setup. **The DevKit is under OpenAI's Sign-in with ChatGPT DevKit Noncommercial License**; respect the license before redistributing or using in a commercial product.

### Run

1. Open `project.godot` in Godot 4.2+ and run with F5.
2. Open **ChatGPT · в Builder**. If Node.js is not in Godot's PATH, set an absolute **Node.js** executable in **Настройки** first.
3. Click **Продолжить с ChatGPT**. Your usual browser opens an official OpenAI authorization page, where you choose your account/workspace and approve plan usage.
4. After permission is granted, Builder loads available models. Select one and send your message. You can attach explicitly selected source files from the chosen local checkout.
5. **Отключить аккаунт** revokes the local session credentials for the active connection; **Новый чат** resets only the local conversation context.
6. If you prefer a separately billed OpenAI Platform key, check **Вместо подписки использовать OpenAI API-ключ**. This mode remains optional.

**Window mode:** Click the upper-right control or press **F11** to toggle windowed/fullscreen.

### How it works

- Godot UI → HTTP on **127.0.0.1**, ephemeral port, authenticated with a unique local-session token.
- Local Node.js process `bridge/server.mjs` → official `@siwc/local` SDK → OpenAI authorization and Responses endpoints.
- `@napi-rs/keyring` protects an AES-256-GCM storage encryption key in the operating system credential vault. OAuth tokens remain encrypted in the user's `user://siwc` directory; the UI sees only the account identity/permission flag, model names, and requested response text.
- The bridge requires explicit local requests. No background inference, automated account rotation, or centralized token pooling.

The GitHub project manager still supports clone, fetch, explicit non-force mirror pushes, account switching via `gh`, and Actions run status. GitHub Actions quota belongs to repository owners; changing the login does not refill it.

### Current development status

The new integration is committed to **`feature/godot-workspace-mvp`** and tracked in Draft PR #1. We have not completed real OAuth consent and inference testing with a ChatGPT account on Windows/macOS/Linux in this environment. You will need a qualifying account with permission grants for the live login to complete. There are no signed installer binaries yet; Node.js and the one-time SDK setup remain required.

See [INSTALL_RU.md](INSTALL_RU.md), [SECURITY.md](SECURITY.md), and [ARCHITECTURE.md](ARCHITECTURE.md).
