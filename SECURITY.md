# Security and privacy

- Never commit GitHub/OpenAI tokens, ChatGPT cookies, private repo source, local config, or secrets to the repo.
- The OpenAI key is read from `OPENAI_API_KEY` or a masked input for the **current process**; it is not written to settings, chat history or logs.
- HTTPS requests go to the fixed `https://api.openai.com/v1/responses` endpoint; credentials are not sent to any custom endpoint.
- Requests are user-triggered. Only an explicitly chosen file (up to 48 KiB, limited text extensions) can be attached; review for private data before sending.
- Local chat history and attached contents are in RAM; `store: false` does not supersede OpenAI Platform data retention and privacy terms.
- The GitHub CLI holds GitHub credentials. Builder changes active `gh` account only on explicit action.
- Mirror push requires approval, verified primary origin, clean checkout and exact local/origin SHA, and forbids `--force`.
- In production, add proper keychain storage, safety review of filesystem boundaries/symlinks, background Git workers with timeouts, key rotation and tested signed installers.
