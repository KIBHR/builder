#!/usr/bin/env node
// Local-only Sign in with ChatGPT runtime for the Godot desktop client.
// No OpenAI or GitHub tokens ever leave this process, and no remote bridge exists.
import { createServer } from "node:http";
import { randomBytes, createCipheriv, createDecipheriv, timingSafeEqual } from "node:crypto";
import { existsSync, mkdirSync, writeFileSync, renameSync, unlinkSync, chmodSync } from "node:fs";
import { resolve, join, dirname } from "node:path";
import { pathToFileURL } from "node:url";
import { spawn } from "node:child_process";
import { Entry } from "@napi-rs/keyring";

const MAX_BODY = 240_000;
const SESSION_HEADER = "x-builder-session";
const MAX_IDLE_MS = 180_000;
const stateDirectory = process.argv[2] && resolve(process.argv[2]);
const handshakeFile = process.argv[3] && resolve(process.argv[3]);

if (!stateDirectory || !handshakeFile) {
  process.stderr.write("Usage: node server.mjs <absolute-user-state-dir> <handshake-file>\n");
  process.exit(2);
}
if (dirname(handshakeFile) !== stateDirectory) {
  process.stderr.write("The handshake must be inside the user-specific state directory.\n");
  process.exit(2);
}
mkdirSync(stateDirectory, { recursive: true, mode: 0o700 });
try { chmodSync(stateDirectory, 0o700); } catch { /* OS can enforce ACLs instead. */ }

const SDK_ENTRY = resolve(import.meta.dirname, "../third_party/siwc-devkit/packages/local/dist/index.js");
if (!existsSync(SDK_ENTRY)) {
  process.stderr.write("Missing official Sign in with ChatGPT DevKit. Run node bridge/setup.mjs first.\n");
  process.exit(3);
}
const { createChatGPT } = await import(pathToFileURL(SDK_ENTRY).href);

// The encryption key is protected by macOS Keychain, Windows Credential Manager
// or the Linux Secret Service / kernel keyring. Never fall back to a plaintext key.
const keyring = new Entry("KIBHR.Builder.SIWC", "credential-key-v1");
let encryptionKey;
function getKey() {
  if (encryptionKey) return encryptionKey;
  let stored = keyring.getPassword();
  if (!stored) {
    const proposed = randomBytes(32).toString("base64");
    keyring.setPassword(proposed);
    stored = keyring.getPassword();
    if (stored !== proposed) throw new Error("OS credential vault did not retain the encryption key.");
  }
  const decoded = Buffer.from(stored, "base64");
  if (decoded.length !== 32) throw new Error("OS credential vault returned an invalid encryption key.");
  encryptionKey = decoded;
  return encryptionKey;
}
const credentialEncryption = {
  id: "builder-os-vault-aes256gcm-v1",
  isAvailable() {
    try { getKey(); return true; } catch { return false; }
  },
  encrypt(plaintext) {
    const iv = randomBytes(12);
    const cipher = createCipheriv("aes-256-gcm", getKey(), iv);
    const encrypted = Buffer.concat([cipher.update(plaintext, "utf8"), cipher.final()]);
    return Buffer.concat([Buffer.from([1]), iv, cipher.getAuthTag(), encrypted]);
  },
  decrypt(ciphertext) {
    const data = Buffer.from(ciphertext);
    if (data.length < 30 || data[0] !== 1) throw new Error("Invalid protected credential format.");
    const iv = data.subarray(1, 13);
    const tag = data.subarray(13, 29);
    const payload = data.subarray(29);
    const decipher = createDecipheriv("aes-256-gcm", getKey(), iv);
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(payload), decipher.final()]).toString("utf8");
  },
};

function openSystemBrowser(rawUrl) {
  const url = new URL(rawUrl);
  if (url.origin !== "https://auth.openai.com") {
    throw new Error("Unexpected OAuth authorization destination.");
  }
  const platform = process.platform;
  const command = platform === "darwin" ? "open" : platform === "win32" ? "rundll32.exe" : "xdg-open";
  const args = platform === "win32" ? ["url.dll,FileProtocolHandler", url.href] : [url.href];
  return new Promise((done, reject) => {
    const child = spawn(command, args, { detached: true, stdio: "ignore", windowsHide: true });
    child.once("error", () => reject(new Error("Could not open the system browser.")));
    child.once("spawn", () => { child.unref(); done(); });
  });
}

const chatgpt = createChatGPT({
  appName: "Builder",
  appId: "kibhr-builder",
  redirectPort: 0,
  storageDir: join(stateDirectory, "credentials"),
  credentialEncryption,
  sendHostId: true,
  openBrowser: openSystemBrowser,
});

const bridgeKey = randomBytes(32).toString("hex");
let lastHeartbeat = Date.now();
let activeRequest = null;
let loginBusy = false;
let authAttempt = { phase: "idle", startedAt: null, error: null };
function publicAuthState() {
  return {
    phase: authAttempt.phase,
    startedAt: authAttempt.startedAt,
    ...(authAttempt.error ? { error: authAttempt.error } : {}),
  };
}

function respond(response, status, body) {
  if (response.writableEnded) return;
  response.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
  });
  response.end(JSON.stringify(body));
}
function validateHeader(value) {
  if (typeof value !== "string") return false;
  const left = Buffer.from(value, "utf8");
  const right = Buffer.from(bridgeKey, "utf8");
  return left.length === right.length && timingSafeEqual(left, right);
}
async function readJson(request) {
  let bytes = 0;
  const chunks = [];
  for await (const chunk of request) {
    bytes += chunk.length;
    if (bytes > MAX_BODY) {
      const error = new Error("Request body exceeds 240 KB.");
      error.httpStatus = 413;
      throw error;
    }
    chunks.push(chunk);
  }
  const raw = Buffer.concat(chunks).toString("utf8");
  if (!raw) return {};
  const parsed = JSON.parse(raw);
  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("Expected a JSON object.");
  return parsed;
}
function safeFailure(error) {
  const code = typeof error?.code === "string" ? error.code : "request_failed";
  // Do not expose raw upstream error bodies or any request/token contents to the UI.
  const publicMessages = {
    sharing_not_enabled: "Разрешение на использование подписки ChatGPT не предоставлено.",
    sign_in_required: "Требуется вход через ChatGPT.",
    cancelled: "Запрос отменён.",
    reauth_required: "Войдите через ChatGPT заново.",
    usage_limit_reached: "Доступный лимит подписки исчерпан.",
  };
  return { error: publicMessages[code] ?? String(error?.message || "Ошибка подключения к ChatGPT").slice(0, 260), code };
}
async function handle(request, response) {
  if (request.headers.origin) return respond(response, 403, { error: "Requests from browser origins are not allowed." });
  if (!validateHeader(request.headers[SESSION_HEADER])) return respond(response, 403, { error: "Unauthorized local client." });
  lastHeartbeat = Date.now();
  const pathname = new URL(request.url ?? "/", "http://127.0.0.1").pathname;
  if (request.method === "GET" && pathname === "/health") return respond(response, 200, { ok: true, version: 1 });
  if (request.method === "GET" && pathname === "/session") {
    return respond(response, 200, { session: await chatgpt.getSession() });
  }
  if (request.method === "GET" && pathname === "/auth/status") {
    // Do not contend with the SDK's credential store while browser consent is pending.
    if (loginBusy) return respond(response, 200, { auth: publicAuthState() });
    return respond(response, 200, { auth: publicAuthState(), session: await chatgpt.getSession() });
  }
  if (request.method === "GET" && pathname === "/models") {
    const session = await chatgpt.getSession();
    if (!session.sharing) return respond(response, 200, { models: [] });
    return respond(response, 200, { models: await chatgpt.listModels() });
  }
  if (request.method === "POST" && pathname === "/signin") {
    if (loginBusy || activeRequest) return respond(response, 409, { error: "Дождитесь завершения предыдущего действия." });
    const params = await readJson(request);
    loginBusy = true;
    authAttempt = { phase: "waiting_browser", startedAt: Date.now(), error: null };
    // Never hold the Godot HTTP request open during interactive browser consent.
    // The official SDK listens on 127.0.0.1 and validates the OAuth callback.
    void chatgpt.signIn({ reconsent: params.reconsent === true })
      .then(() => { authAttempt = { ...authAttempt, phase: "connected", error: null }; })
      .catch((error) => { authAttempt = { ...authAttempt, phase: "failed", error: safeFailure(error) }; })
      .finally(() => { loginBusy = false; });
    return respond(response, 202, { started: true, auth: publicAuthState() });
  }
  if (request.method === "POST" && pathname === "/disconnect") {
    if (activeRequest || loginBusy) return respond(response, 409, { error: "Сначала отмените текущий запрос." });
    await chatgpt.disconnect();
    return respond(response, 200, { session: await chatgpt.getSession() });
  }
  if (request.method === "POST" && pathname === "/chat") {
    if (activeRequest || loginBusy) return respond(response, 409, { error: "Дождитесь предыдущего запроса." });
    const session = await chatgpt.getSession();
    if (!session.sharing) return respond(response, 403, { error: "Войдите в ChatGPT и разрешите использование подписки." });
    const input = await readJson(request);
    if (!Array.isArray(input.messages) || input.messages.length > 12 || typeof input.model !== "string" || typeof input.instructions !== "string") {
      return respond(response, 400, { error: "Некорректный запрос к модели." });
    }
    if (input.instructions.length > 8000 || input.messages.some((m) => !m || !["user", "assistant"].includes(m.role) || typeof m.content !== "string" || m.content.length > 72_000)) {
      return respond(response, 400, { error: "Сообщение превышает допустимый размер." });
    }
    const models = await chatgpt.listModels();
    if (!models.some((m) => m.slug === input.model)) return respond(response, 400, { error: "Выбранная модель недоступна аккаунту." });
    const controller = new AbortController();
    activeRequest = controller;
    try {
      const result = await chatgpt.streamResponse({
        model: input.model,
        input: input.messages,
        instructions: input.instructions,
        signal: controller.signal,
      });
      return respond(response, 200, { text: result.text });
    } finally { activeRequest = null; }
  }
  if (request.method === "POST" && pathname === "/cancel") {
    activeRequest?.abort();
    if (loginBusy) {
      authAttempt = { ...authAttempt, phase: "cancelling" };
      chatgpt.cancelSignIn();
    }
    return respond(response, 200, { cancelled: true });
  }
  if (request.method === "POST" && pathname === "/stop") {
    respond(response, 200, { stopping: true });
    setImmediate(shutdown);
    return;
  }
  return respond(response, 404, { error: "Unknown local bridge command." });
}
const server = createServer((request, response) => {
  // The bridge never exposes permissive CORS, so external web pages cannot
  // invoke authenticated endpoints. A separate unpredictable secret is required.
  void handle(request, response).catch((error) => respond(response, error.httpStatus || 500, safeFailure(error)));
});
server.requestTimeout = 190_000;

function shutdown() {
  activeRequest?.abort();
  if (loginBusy) chatgpt.cancelSignIn();
  try { unlinkSync(handshakeFile); } catch { /* Already removed by Godot. */ }
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 1500).unref();
}
process.once("SIGTERM", shutdown);
process.once("SIGINT", shutdown);
const timer = setInterval(() => {
  if (Date.now() - lastHeartbeat > MAX_IDLE_MS && !loginBusy && !activeRequest) shutdown();
}, 30_000);
timer.unref();

server.listen(0, "127.0.0.1", () => {
  const port = server.address().port;
  const temp = handshakeFile + "." + process.pid + ".tmp";
  writeFileSync(temp, JSON.stringify({ pid: process.pid, port, secret: bridgeKey }), { mode: 0o600, flag: "wx" });
  renameSync(temp, handshakeFile);
  try { chmodSync(handshakeFile, 0o600); } catch { /* ACL on Windows. */ }
  process.stdout.write("Builder ChatGPT local bridge ready.\n");
});
