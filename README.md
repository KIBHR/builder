# Builder — AI Development Workspace

Builder is a **Godot 4 desktop** development workspace for GitHub repositories and an in-app AI assistant.

## Упрощённый Builder (Godot 4.7.2)

Новый интерфейс в тёмных тонах с навигацией слева, быстрым стартом, каталогом GitHub и встроенным ИИ. На главной странице есть последовательность подключения и крупные кнопки. В нижней части меню — **Выйти из Builder**.

### GitHub — подключить и загрузить проект

1. **GitHub-аккаунты → Войти через GitHub**. Builder запускает официальный `gh auth login --web` в терминале и открывает вход через браузер; токены в Builder не копируются. После входа нажмите **Проверить подключение**. Если терминал не открылся, команда авторизации уже скопирована в буфер обмена.
2. **Загрузить из GitHub** → найдите репозиторий → выберите локальную папку → **Добавить проект**. Builder использует `gh repo clone`, поэтому доступны и приватные репозитории, на которые есть права.
3. Подключённые проекты появятся в **Мои проекты**. Старый режим ручного указания URL и каталога сохранён как дополнительный.

### ИИ — выберите режим

| Режим | Нужно для входа | Работает без отдельного API-ключа |
|---|---|---|
| **ChatGPT** | Доступный для вашего плана официальный вход через ChatGPT и разрешение использовать подписку | Да |
| **Ollama** | Установить Ollama и скачать локальную модель; сервер 127.0.0.1:11434 | Да, для локальной модели |
| **LM Studio** | Установить LM Studio, загрузить модель и включить локальный сервер 127.0.0.1:1234 | Да, для локальной модели |
| **OpenAI API** | Ключ OpenAI Platform и отдельный биллинг | Нет |

В разделе **ИИ-помощник** модели выбираются по доступности. Для ChatGPT есть кнопка **Установить вход в ChatGPT** (разовая загрузка официального DevKit), затем **Продолжить с ChatGPT**. Для Ollama/LM Studio — **Найти модели**. Не нужно вводить API-ключ в локальных режимах. Локальный запрос с выбранной моделью не отправляется в OpenAI.

Пример установки компактной модели для Ollama через терминал:

```sh
ollama pull qwen2.5-coder:1.5b
```

Для LM Studio загрузите совместимую чат-модель в разделе моделей и включите API-сервер приложения. Builder запрашивает список моделей автоматически при выборе режима, а также по кнопке **Найти модели**.

**Дополнительно:** F11 переключает полноэкранный режим при запуске в отдельном окне; встраивание Game в редактор Godot нужно выключить. Переписка ИИ и явно прикреплённые файлы не сохраняются в настройках Builder.

См. [INSTALL_RU.md](INSTALL_RU.md) для запуска и [SECURITY.md](SECURITY.md) для ограничений по данным.

---

## New: Sign in with ChatGPT without an API key

Builder now offers **Continue with ChatGPT** through the [official Sign in with ChatGPT DevKit](https://github.com/openai/sign-in-with-chatgpt-devkit) for **open-source apps running on a user's own computer**. OAuth is handled in the system browser; Builder never asks for a ChatGPT password, browser cookie, API key, or unofficial Codex credential.

**Eligible ChatGPT Plus and Pro users** can approve access to their subscription allowance for supported AI requests; successful identity login alone is **not** enough. The app reads the permission flag and lists models actually available for the selected account. ChatGPT conversations from the website are **not** imported.

### Install once

Requirements: **Godot 4.2+**, Git, Node.js **22.12+**, npm, and an OS credential vault (macOS Keychain, Windows Credential Manager, or Linux Secret Service/keyutils).

You can now start installation via **ИИ-помощник → ChatGPT → Установить вход в ChatGPT**. If the guided setup is unavailable, run from the checkout:

```sh
node bridge/setup.mjs
```

This command fetches a pinned revision of OpenAI's DevKit into the ignored `third_party/siwc-devkit/` directory, builds its `@siwc/local` package, and installs `@napi-rs/keyring` for Builder's local bridge. An internet connection is required for this setup. **The DevKit is under OpenAI's Sign-in with ChatGPT DevKit Noncommercial License**; respect the license before redistributing or using in a commercial product.

### Run

1. Open `project.godot` in Godot 4.2+ and run with F5.
2. Open **ИИ-помощник**. If Node.js is not in Godot's PATH, set an absolute **Node.js** executable in **Настройки** first.
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
