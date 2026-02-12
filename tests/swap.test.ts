import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { execSync } from "node:child_process";
import {
  mkdtempSync,
  cpSync,
  mkdirSync,
  writeFileSync,
  existsSync,
  readFileSync,
  readdirSync,
} from "node:fs";
import { rmSync } from "node:fs";
import path from "node:path";
import os from "node:os";

const CLI_PATH = path.resolve(__dirname, "../dist/cli.js");
const REPO_ROOT = path.resolve(__dirname, "..");

function setupTestEnv(): string {
  const tmp = mkdtempSync(path.join(os.tmpdir(), "ff-profiles-test-"));
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

function setupClaudeDir(target: string): void {
  const claudeDir = path.join(target, ".claude");
  mkdirSync(path.join(claudeDir, "commands"), { recursive: true });
  mkdirSync(path.join(claudeDir, "agents"), { recursive: true });
  writeFileSync(path.join(claudeDir, "CLAUDE.md"), "# My Custom Instructions");
  writeFileSync(path.join(claudeDir, "settings.json"), '{"$schema":"..."}');
  writeFileSync(path.join(claudeDir, "agents", "my-agent.md"), "agent content");
  // Simulate the injected profiles.md (should be stripped on save)
  writeFileSync(path.join(claudeDir, "commands", "profiles.md"), "profiles command");
  // A user-created command (should be kept on save)
  writeFileSync(path.join(claudeDir, "commands", "my-command.md"), "my command");
}

function run(
  args: string,
  repoRoot: string,
  options: { expectFailure?: boolean } = {},
): { stdout: string; exitCode: number } {
  try {
    const stdout = execSync(`node ${CLI_PATH} ${args} --repo-root ${repoRoot}`, {
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
    });
    return { stdout, exitCode: 0 };
  } catch (err: any) {
    if (options.expectFailure) {
      return {
        stdout: (err.stdout || "") + (err.stderr || ""),
        exitCode: err.status ?? 1,
      };
    }
    throw err;
  }
}

// ── list subcommand ──

describe("list", () => {
  let tmp: string;
  beforeEach(() => {
    tmp = setupTestEnv();
  });
  afterEach(() => {
    rmSync(tmp, { recursive: true, force: true });
  });

  it("shows built-in profiles", () => {
    const { stdout } = run("list", path.join(tmp, "ff-profiles"));
    expect(stdout).toContain("developer");
    expect(stdout).toContain("minimal");
  });

  it("shows profile descriptions", () => {
    const { stdout } = run("list", path.join(tmp, "ff-profiles"));
    expect(stdout).toContain("FluidFramework");
    expect(stdout).toContain("Bare-bones");
  });

  it("shows custom profiles with [custom] tag", () => {
    setupClaudeDir(tmp);
    // First save a custom profile
    run(
      `save my-custom --description "A custom one" --target ${tmp}`,
      path.join(tmp, "ff-profiles"),
    );
    const { stdout } = run("list", path.join(tmp, "ff-profiles"));
    expect(stdout).toContain("my-custom");
    expect(stdout).toContain("A custom one");
    expect(stdout).toContain("[custom]");
  });
});

// ── swap subcommand ──

describe("swap", () => {
  let tmp: string;
  beforeEach(() => {
    tmp = setupTestEnv();
  });
  afterEach(() => {
    rmSync(tmp, { recursive: true, force: true });
  });

  it("copies developer profile to .claude/", () => {
    run(`swap developer --target ${tmp}`, path.join(tmp, "ff-profiles"));
    expect(existsSync(path.join(tmp, ".claude", "CLAUDE.md"))).toBe(true);
    expect(existsSync(path.join(tmp, ".claude", "settings.json"))).toBe(true);
  });

  it("copies minimal profile to .claude/", () => {
    run(`swap minimal --target ${tmp}`, path.join(tmp, "ff-profiles"));
    expect(existsSync(path.join(tmp, ".claude", "CLAUDE.md"))).toBe(true);
    expect(existsSync(path.join(tmp, ".claude", "settings.json"))).toBe(true);
  });

  it("overwrites existing .claude/ directory", () => {
    run(`swap developer --target ${tmp}`, path.join(tmp, "ff-profiles"));
    const hadAgents = existsSync(path.join(tmp, ".claude", "agents"));
    run(`swap minimal --target ${tmp}`, path.join(tmp, "ff-profiles"));
    const hasAgentsAfter = existsSync(path.join(tmp, ".claude", "agents"));
    expect(hadAgents).toBe(true);
    expect(hasAgentsAfter).toBe(false);
  });

  it("injects profiles.md into .claude/commands/", () => {
    run(`swap developer --target ${tmp}`, path.join(tmp, "ff-profiles"));
    expect(existsSync(path.join(tmp, ".claude", "commands", "profiles.md"))).toBe(true);
  });

  it("injects profiles.md for minimal profile too", () => {
    run(`swap minimal --target ${tmp}`, path.join(tmp, "ff-profiles"));
    expect(existsSync(path.join(tmp, ".claude", "commands", "profiles.md"))).toBe(true);
  });

  it("errors on invalid profile name", () => {
    const { stdout, exitCode } = run(
      `swap nonexistent --target ${tmp}`,
      path.join(tmp, "ff-profiles"),
      { expectFailure: true },
    );
    expect(exitCode).toBe(1);
    expect(stdout).toContain("not found");
  });

  it("errors when no profile name given", () => {
    const { exitCode } = run(`swap --target ${tmp}`, path.join(tmp, "ff-profiles"), {
      expectFailure: true,
    });
    expect(exitCode).not.toBe(0);
  });

  it("loads a previously saved custom profile", () => {
    setupClaudeDir(tmp);
    // Save custom profile
    run(`save my-custom --target ${tmp}`, path.join(tmp, "ff-profiles"));
    // Swap to minimal (destroys .claude/)
    run(`swap minimal --target ${tmp}`, path.join(tmp, "ff-profiles"));
    // Swap back to custom
    run(`swap my-custom --target ${tmp}`, path.join(tmp, "ff-profiles"));
    expect(existsSync(path.join(tmp, ".claude", "CLAUDE.md"))).toBe(true);
    const content = readFileSync(path.join(tmp, ".claude", "CLAUDE.md"), "utf-8");
    expect(content).toContain("My Custom Instructions");
    expect(existsSync(path.join(tmp, ".claude", "agents", "my-agent.md"))).toBe(true);
  });
});

// ── save subcommand ──

describe("save", () => {
  let tmp: string;
  beforeEach(() => {
    tmp = setupTestEnv();
  });
  afterEach(() => {
    rmSync(tmp, { recursive: true, force: true });
  });

  it("creates a custom profile from .claude/", () => {
    setupClaudeDir(tmp);
    run(`save my-custom --target ${tmp}`, path.join(tmp, "ff-profiles"));
    const saveDir = path.join(tmp, "ff-profiles", "custom-profiles", "my-custom");
    expect(existsSync(path.join(saveDir, "CLAUDE.md"))).toBe(true);
    expect(existsSync(path.join(saveDir, "settings.json"))).toBe(true);
    expect(existsSync(path.join(saveDir, "agents", "my-agent.md"))).toBe(true);
  });

  it("generates profile.json with name and description", () => {
    setupClaudeDir(tmp);
    run(`save my-custom --target ${tmp}`, path.join(tmp, "ff-profiles"));
    const profileJsonPath = path.join(
      tmp,
      "ff-profiles",
      "custom-profiles",
      "my-custom",
      "profile.json",
    );
    expect(existsSync(profileJsonPath)).toBe(true);
    const content = readFileSync(profileJsonPath, "utf-8");
    expect(content).toContain('"my-custom"');
    expect(content).toContain('"description"');
  });

  it("uses custom description from --description flag", () => {
    setupClaudeDir(tmp);
    run(
      `save my-custom --description "My custom setup" --target ${tmp}`,
      path.join(tmp, "ff-profiles"),
    );
    const content = readFileSync(
      path.join(tmp, "ff-profiles", "custom-profiles", "my-custom", "profile.json"),
      "utf-8",
    );
    expect(content).toContain("My custom setup");
  });

  it("strips injected profiles.md but keeps user commands", () => {
    setupClaudeDir(tmp);
    run(`save my-custom --target ${tmp}`, path.join(tmp, "ff-profiles"));
    const saveDir = path.join(tmp, "ff-profiles", "custom-profiles", "my-custom");
    expect(existsSync(path.join(saveDir, "commands", "profiles.md"))).toBe(false);
    expect(existsSync(path.join(saveDir, "commands", "my-command.md"))).toBe(true);
  });

  it("refuses overwrite without --force in non-interactive mode", () => {
    setupClaudeDir(tmp);
    run(`save my-custom --target ${tmp}`, path.join(tmp, "ff-profiles"));
    const { exitCode, stdout } = run(
      `save my-custom --target ${tmp}`,
      path.join(tmp, "ff-profiles"),
      { expectFailure: true },
    );
    expect(exitCode).toBe(1);
    expect(stdout).toContain("--force");
  });

  it("overwrites with --force flag", () => {
    setupClaudeDir(tmp);
    run(`save my-custom --target ${tmp}`, path.join(tmp, "ff-profiles"));
    // Modify .claude/ to confirm overwrite actually happens
    writeFileSync(path.join(tmp, ".claude", "CLAUDE.md"), "# Updated Instructions");
    const { exitCode } = run(
      `save my-custom --force --target ${tmp}`,
      path.join(tmp, "ff-profiles"),
    );
    expect(exitCode).toBe(0);
    const content = readFileSync(
      path.join(tmp, "ff-profiles", "custom-profiles", "my-custom", "CLAUDE.md"),
      "utf-8",
    );
    expect(content).toContain("Updated Instructions");
  });

  it("errors when no name given", () => {
    setupClaudeDir(tmp);
    const { exitCode } = run(`save --target ${tmp}`, path.join(tmp, "ff-profiles"), {
      expectFailure: true,
    });
    expect(exitCode).not.toBe(0);
  });

  it("errors when no .claude/ directory exists", () => {
    const { exitCode, stdout } = run(
      `save my-custom --target ${tmp}`,
      path.join(tmp, "ff-profiles"),
      { expectFailure: true },
    );
    expect(exitCode).toBe(1);
    expect(stdout).toContain(".claude");
  });

  it("rejects invalid profile name (path traversal)", () => {
    setupClaudeDir(tmp);
    const { exitCode, stdout } = run(
      `save "../escape" --target ${tmp}`,
      path.join(tmp, "ff-profiles"),
      { expectFailure: true },
    );
    expect(exitCode).toBe(1);
    expect(stdout).toContain("letters");
  });

  it("rejects name with slash", () => {
    setupClaudeDir(tmp);
    const { exitCode } = run(
      `save "foo/bar" --target ${tmp}`,
      path.join(tmp, "ff-profiles"),
      { expectFailure: true },
    );
    expect(exitCode).toBe(1);
  });

  it("rejects built-in profile name", () => {
    setupClaudeDir(tmp);
    const { exitCode, stdout } = run(
      `save developer --target ${tmp}`,
      path.join(tmp, "ff-profiles"),
      { expectFailure: true },
    );
    expect(exitCode).toBe(1);
    expect(stdout).toContain("built-in");
  });

  it("escapes quotes in description JSON", () => {
    setupClaudeDir(tmp);
    run(
      `save my-custom --description "has \\"quotes\\" inside" --target ${tmp}`,
      path.join(tmp, "ff-profiles"),
    );
    const content = readFileSync(
      path.join(tmp, "ff-profiles", "custom-profiles", "my-custom", "profile.json"),
      "utf-8",
    );
    // JSON.parse should work — that's the real test
    const parsed = JSON.parse(content);
    expect(parsed.description).toContain("quotes");
  });

  it("errors when --description has no value", () => {
    setupClaudeDir(tmp);
    const { exitCode, stdout } = run(
      `save my-custom --description --force --target ${tmp}`,
      path.join(tmp, "ff-profiles"),
      { expectFailure: true },
    );
    // Commander should reject --description when the next arg looks like a flag
    expect(exitCode).not.toBe(0);
  });
});

// ── help subcommand ──

describe("help", () => {
  let tmp: string;
  beforeEach(() => {
    tmp = setupTestEnv();
  });
  afterEach(() => {
    rmSync(tmp, { recursive: true, force: true });
  });

  it("shows usage info", () => {
    const { stdout } = run("help", path.join(tmp, "ff-profiles"));
    expect(stdout.toLowerCase()).toMatch(/usage|commands|help/i);
  });

  it("mentions list, swap, and save commands", () => {
    const { stdout } = run("help", path.join(tmp, "ff-profiles"));
    expect(stdout).toContain("list");
    expect(stdout).toContain("swap");
    expect(stdout).toContain("save");
  });
});
