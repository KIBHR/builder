# Архитектура Builder

## Godot 4 frontend

- `scenes/main.tscn`, `scripts/workspace.gd`: GitHub projects, accounts, settings, F11 fullscreen.
- `scripts/chat_panel.gd`: conversational UI; primary **Continue with ChatGPT** button, explicit consent status, dynamic models, new chat, cancel, optional API-key compatibility mode.
- `scripts/siwc_client.gd`: start/stop isolated local Node bridge, authenticated HTTP over 127.0.0.1, OAuth state, prompts and model catalog.
- `scripts/openai_client.gd`: optional separately billed OpenAI Platform API fallback.

## Official OpenAI Sign in with ChatGPT

- `bridge/setup.mjs` clones a **pinned** version of [OpenAI Sign in with ChatGPT DevKit](https://github.com/openai/sign-in-with-chatgpt-devkit) and builds `@siwc/local`, then installs local keyring bindings.
- `bridge/server.mjs` wraps official `createChatGPT({ appName: "Builder", appId: "kibhr-builder", sendHostId: true, ... })` in a **localhost-only** backend. The SDK handles dynamic OAuth client registration, browser authorization, PKCE, verified ID tokens, plan scopes, refresh and Responses API requests.
- OAuth credentials reside only in the local Node process and the SDK's encrypted profile store, with the AES-GCM key protected by the OS keyring. Godot sees only connection state, identity display, available model slugs, and explicitly requested response text.
- Only sessions with the granted `chatgpt.tokens.use.direct` scope can make subscription-backed requests; otherwise UI shows that more permission is needed. Explicit reconsent is supported.
- The browser used to authenticate is the default OS browser, not a Godot WebView or an embedded ChatGPT webpage.
- The SDK's license is **noncommercial** and separate from the Builder repository's license; use of this integration must comply with its terms.
- SIWC does not grant access to the account's chatgpt.com conversation history.

## Transport

Godot starts a Node.js sidecar with the current user's absolute `user://siwc` directory. The bridge binds a random ephemeral port to **127.0.0.1** and writes a 0600-protected handshake file with PID, port and random shared secret. Godot reads it, removes the file, and uses the secret for authenticated loopback calls. Requests with browser Origin headers are rejected and cross-origin access is not enabled. No backend is deployed and no tokens are shared across users.

Godot calls: `GET /session`, `GET /models`, `POST /signin`, `POST /disconnect`, `POST /chat`, `POST /cancel`, `GET /health`. Only user activity triggers inference. Local sidecar exits on app close or after idle timeout.

## Existing GitHub integration

Git and GitHub CLI operations are separate; account switching there never changes repository-owner Actions billing. Mirror pushes remain opt-in and non-force. Background CI-account rotation is not implemented.
