import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { execSync } from "node:child_process";
import { mkdtempSync, cpSync, mkdirSync, existsSync, readFileSync, statSync } from "node:fs";
import { rmSync } from "node:fs";
import path from "node:path";
import os from "node:os";

const CLI_PATH = path.resolve(__dirname, "../dist/cli.js");
const REPO_ROOT = path.resolve(__dirname, "..");

function setupTestEnv(): string {
  const tmp = mkdtempSync(path.join(os.tmpdir(), "ff-profiles-prprep-test-"));
  const ffDir = path.join(tmp, "ff-profiles");
  mkdirSync(ffDir, { recursive: true });
  cpSync(path.join(REPO_ROOT, "claude-profiles"), path.join(ffDir, "claude-profiles"), {
    recursive: true,
  });
  cpSync(path.join(REPO_ROOT, "commands"), path.join(ffDir, "commands"), {
    recursive: true,
  });
  return tmp;
}

function swapPrPrep(tmp: string): void {
  execSync(`node ${CLI_PATH} swap pr-prep --repo-root ${path.join(tmp, "ff-profiles")} --target ${tmp}`, {
    encoding: "utf-8",
    stdio: ["pipe", "pipe", "pipe"],
  });
}

describe("pr-prep profile", () => {
  let tmp: string;
  beforeEach(() => {
    tmp = setupTestEnv();
  });
  afterEach(() => {
    rmSync(tmp, { recursive: true, force: true });
  });

  // ── profile discovery ──

  it("appears in list output", () => {
    const output = execSync(
      `node ${CLI_PATH} list --repo-root ${path.join(tmp, "ff-profiles")}`,
      { encoding: "utf-8" },
    );
    expect(output).toContain("pr-prep");
  });

  it("shows PR-related description in list", () => {
    const output = execSync(
      `node ${CLI_PATH} list --repo-root ${path.join(tmp, "ff-profiles")}`,
      { encoding: "utf-8" },
    );
    expect(output).toContain("PR");
  });

  // ── profile swap ──

  it("creates .claude/CLAUDE.md", () => {
    swapPrPrep(tmp);
    expect(existsSync(path.join(tmp, ".claude", "CLAUDE.md"))).toBe(true);
  });

  it("creates .claude/settings.json", () => {
    swapPrPrep(tmp);
    expect(existsSync(path.join(tmp, ".claude", "settings.json"))).toBe(true);
  });

  it("creates .claude/profile.json", () => {
    swapPrPrep(tmp);
    expect(existsSync(path.join(tmp, ".claude", "profile.json"))).toBe(true);
  });

  it("creates .claude/hooks.json", () => {
    swapPrPrep(tmp);
    expect(existsSync(path.join(tmp, ".claude", "hooks.json"))).toBe(true);
  });

  it("creates .claude/.mcp.json", () => {
    swapPrPrep(tmp);
    expect(existsSync(path.join(tmp, ".claude", ".mcp.json"))).toBe(true);
  });

  it("injects profiles.md command", () => {
    swapPrPrep(tmp);
    expect(existsSync(path.join(tmp, ".claude", "commands", "profiles.md"))).toBe(true);
  });

  // ── directory structure ──

  it("creates agents/ directory", () => {
    swapPrPrep(tmp);
    expect(existsSync(path.join(tmp, ".claude", "agents"))).toBe(true);
  });

  it("creates skills/ directory", () => {
    swapPrPrep(tmp);
    expect(existsSync(path.join(tmp, ".claude", "skills"))).toBe(true);
  });

  it("creates commands/ directory", () => {
    swapPrPrep(tmp);
    expect(existsSync(path.join(tmp, ".claude", "commands"))).toBe(true);
  });

  it("creates hooks/ directory", () => {
    swapPrPrep(tmp);
    expect(existsSync(path.join(tmp, ".claude", "hooks"))).toBe(true);
  });

  // ── agent files ──

  it("has pr-reviewer agent", () => {
    swapPrPrep(tmp);
    expect(existsSync(path.join(tmp, ".claude", "agents", "pr-reviewer.md"))).toBe(true);
  });

  it("has simplifier agent", () => {
    swapPrPrep(tmp);
    expect(existsSync(path.join(tmp, ".claude", "agents", "simplifier.md"))).toBe(true);
  });

  it("has validator agent", () => {
    swapPrPrep(tmp);
    expect(existsSync(path.join(tmp, ".claude", "agents", "validator.md"))).toBe(true);
  });

  // ── skill files ──

  it("has pr-checklist skill", () => {
    swapPrPrep(tmp);
    expect(existsSync(path.join(tmp, ".claude", "skills", "pr-checklist", "SKILL.md"))).toBe(true);
  });

  // ── command files ──

  it("has prep-pr command", () => {
    swapPrPrep(tmp);
    expect(existsSync(path.join(tmp, ".claude", "commands", "prep-pr.md"))).toBe(true);
  });

  // ── hook scripts ──

  it("has lint-on-save hook script", () => {
    swapPrPrep(tmp);
    expect(existsSync(path.join(tmp, ".claude", "hooks", "lint-on-save.sh"))).toBe(true);
  });

  it("lint-on-save hook script is executable", () => {
    swapPrPrep(tmp);
    const stats = statSync(path.join(tmp, ".claude", "hooks", "lint-on-save.sh"));
    expect(stats.mode & 0o111).not.toBe(0);
  });

  it("has completion-gate hook script", () => {
    swapPrPrep(tmp);
    expect(existsSync(path.join(tmp, ".claude", "hooks", "completion-gate.sh"))).toBe(true);
  });

  it("completion-gate hook script is executable", () => {
    swapPrPrep(tmp);
    const stats = statSync(path.join(tmp, ".claude", "hooks", "completion-gate.sh"));
    expect(stats.mode & 0o111).not.toBe(0);
  });

  // ── JSON validity ──

  it("profile.json is valid JSON", () => {
    swapPrPrep(tmp);
    const content = readFileSync(path.join(tmp, ".claude", "profile.json"), "utf-8");
    expect(() => JSON.parse(content)).not.toThrow();
  });

  it("settings.json is valid JSON", () => {
    swapPrPrep(tmp);
    const content = readFileSync(path.join(tmp, ".claude", "settings.json"), "utf-8");
    expect(() => JSON.parse(content)).not.toThrow();
  });

  it("hooks.json is valid JSON", () => {
    swapPrPrep(tmp);
    const content = readFileSync(path.join(tmp, ".claude", "hooks.json"), "utf-8");
    expect(() => JSON.parse(content)).not.toThrow();
  });

  it(".mcp.json is valid JSON", () => {
    swapPrPrep(tmp);
    const content = readFileSync(path.join(tmp, ".claude", ".mcp.json"), "utf-8");
    expect(() => JSON.parse(content)).not.toThrow();
  });

  // ── JSON structure ──

  it("settings.json has permissions.allow, deny, and ask", () => {
    swapPrPrep(tmp);
    const data = JSON.parse(readFileSync(path.join(tmp, ".claude", "settings.json"), "utf-8"));
    expect(data.permissions).toBeDefined();
    expect(data.permissions.allow).toBeDefined();
    expect(data.permissions.deny).toBeDefined();
    expect(data.permissions.ask).toBeDefined();
  });

  it("hooks.json has hooks.PostToolUse", () => {
    swapPrPrep(tmp);
    const data = JSON.parse(readFileSync(path.join(tmp, ".claude", "hooks.json"), "utf-8"));
    expect(data.hooks.PostToolUse).toBeDefined();
  });

  it("hooks.json has hooks.Stop", () => {
    swapPrPrep(tmp);
    const data = JSON.parse(readFileSync(path.join(tmp, ".claude", "hooks.json"), "utf-8"));
    expect(data.hooks.Stop).toBeDefined();
  });

  it(".mcp.json has mcpServers.github", () => {
    swapPrPrep(tmp);
    const data = JSON.parse(readFileSync(path.join(tmp, ".claude", ".mcp.json"), "utf-8"));
    expect(data.mcpServers.github).toBeDefined();
  });

  it("profile.json name is pr-prep", () => {
    swapPrPrep(tmp);
    const data = JSON.parse(readFileSync(path.join(tmp, ".claude", "profile.json"), "utf-8"));
    expect(data.name).toBe("pr-prep");
  });

  // ── swap isolation ──

  it("swapping from pr-prep to minimal removes agents/", () => {
    swapPrPrep(tmp);
    expect(existsSync(path.join(tmp, ".claude", "agents"))).toBe(true);
    execSync(
      `node ${CLI_PATH} swap minimal --repo-root ${path.join(tmp, "ff-profiles")} --target ${tmp}`,
      { encoding: "utf-8", stdio: ["pipe", "pipe", "pipe"] },
    );
    expect(existsSync(path.join(tmp, ".claude", "agents"))).toBe(false);
  });

  // ── existing profiles still listed ──

  it("list still shows developer, minimal, and pr-prep", () => {
    const output = execSync(
      `node ${CLI_PATH} list --repo-root ${path.join(tmp, "ff-profiles")}`,
      { encoding: "utf-8" },
    );
    expect(output).toContain("developer");
    expect(output).toContain("minimal");
    expect(output).toContain("pr-prep");
  });
});
