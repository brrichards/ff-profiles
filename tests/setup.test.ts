import { describe, it, expect, afterEach } from "vitest";
import { execSync } from "node:child_process";
import { mkdtempSync, cpSync, mkdirSync, writeFileSync, existsSync, readFileSync } from "node:fs";
import { rmSync } from "node:fs";
import path from "node:path";
import os from "node:os";

const REPO_ROOT = path.resolve(__dirname, "..");

function runSetup(target: string): string {
  return execSync(
    `bash ${path.join(target, "ff-profiles", "setup.sh")} --local --skip-install --target ${target}`,
    { encoding: "utf-8", stdio: ["pipe", "pipe", "pipe"] },
  );
}

describe("setup.sh", () => {
  const temps: string[] = [];

  function createTestEnv(): string {
    const tmp = mkdtempSync(path.join(os.tmpdir(), "ff-profiles-setup-test-"));
    cpSync(REPO_ROOT, path.join(tmp, "ff-profiles"), { recursive: true });
    temps.push(tmp);
    return tmp;
  }

  afterEach(() => {
    for (const t of temps) {
      rmSync(t, { recursive: true, force: true });
    }
    temps.length = 0;
  });

  it("copies developer profile to .claude/", () => {
    const tmp = createTestEnv();
    runSetup(tmp);
    expect(existsSync(path.join(tmp, ".claude", "CLAUDE.md"))).toBe(true);
    expect(existsSync(path.join(tmp, ".claude", "settings.json"))).toBe(true);
  });

  it("injects profiles.md command", () => {
    const tmp = createTestEnv();
    runSetup(tmp);
    expect(existsSync(path.join(tmp, ".claude", "commands", "profiles.md"))).toBe(true);
  });

  it("copies agents directory", () => {
    const tmp = createTestEnv();
    runSetup(tmp);
    expect(existsSync(path.join(tmp, ".claude", "agents"))).toBe(true);
  });

  it("copies skills directory", () => {
    const tmp = createTestEnv();
    runSetup(tmp);
    expect(existsSync(path.join(tmp, ".claude", "skills"))).toBe(true);
  });

  it("prints profile name in output", () => {
    const tmp = createTestEnv();
    const output = runSetup(tmp);
    expect(output).toContain("developer");
  });

  it("overwrites existing .claude/ directory (removes stale files)", () => {
    const tmp = createTestEnv();
    // Create a pre-existing .claude/ with a stale file
    mkdirSync(path.join(tmp, ".claude"), { recursive: true });
    writeFileSync(path.join(tmp, ".claude", "stale-file.txt"), "stale");
    runSetup(tmp);
    expect(existsSync(path.join(tmp, ".claude", "CLAUDE.md"))).toBe(true);
    expect(existsSync(path.join(tmp, ".claude", "stale-file.txt"))).toBe(false);
  });
});
