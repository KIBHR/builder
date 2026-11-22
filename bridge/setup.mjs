#!/usr/bin/env node
// One-time setup for the official OpenAI SIWC DevKit (not checked into Builder).
import { existsSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const devkitRevision = "0a36fefeb913055c8c7a1a29b63d82b96b2e841a";
const bridgeDir = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(bridgeDir, "..");
const devkitDir = resolve(repositoryRoot, "third_party", "siwc-devkit");
const sdkOutput = resolve(devkitDir, "packages", "local", "dist", "index.js");

function run(program, args, cwd) {
  process.stdout.write("+ " + program + " " + args.join(" ") + "\n");
  const result = spawnSync(program, args, {
    cwd,
    stdio: "inherit",
    shell: process.platform === "win32" && program === "npm",
  });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(program + " failed with exit code " + result.status);
}
if (Number(process.versions.node.split(".")[0]) < 22) {
  throw new Error("Node.js >=22.12.0 is required for the official SIWC DevKit.");
}
mkdirSync(dirname(devkitDir), { recursive: true });
if (!existsSync(resolve(devkitDir, ".git"))) {
  run("git", ["clone", "https://github.com/openai/sign-in-with-chatgpt-devkit.git", devkitDir], repositoryRoot);
}
run("git", ["checkout", "--detach", devkitRevision], devkitDir);
if (!existsSync(sdkOutput)) {
  run("npm", ["ci", "--workspace", "@siwc/local", "--include-workspace-root"], devkitDir);
  run("npm", ["run", "build", "--workspace", "@siwc/local"], devkitDir);
}
run("npm", ["install", "--no-audit", "--no-fund"], bridgeDir);
process.stdout.write("\nBuilder SIWC bridge installed. Open Godot and choose 'Продолжить с ChatGPT'.\n");
