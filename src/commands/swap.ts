import { existsSync, cpSync, rmSync, mkdirSync } from "node:fs";
import path from "node:path";
import { resolveProfileDir, listProfilesInDir } from "../utils/profiles.js";

export function swapAction(
  name: string,
  options: { repoRoot: string; target?: string },
): void {
  const profilesDir = path.join(options.repoRoot, "claude-profiles");
  const customProfilesDir = path.join(options.repoRoot, "custom-profiles");
  const commandsDir = path.join(options.repoRoot, "commands");

  const profileDir = resolveProfileDir(name, profilesDir, customProfilesDir);

  if (!profileDir) {
    process.stderr.write(`Error: Profile "${name}" not found.\n`);
    process.stderr.write("Available profiles:\n");

    const builtins = listProfilesInDir(profilesDir);
    for (const p of builtins) {
      process.stderr.write(`  ${p.name}\n`);
    }
    const customs = listProfilesInDir(customProfilesDir);
    for (const p of customs) {
      process.stderr.write(`  ${p.name} [custom]\n`);
    }

    process.exit(1);
  }

  // Resolve target directory
  const target = options.target || path.resolve(options.repoRoot, "..");
  const targetClaudeDir = path.join(target, ".claude");

  // Remove existing .claude/ directory
  if (existsSync(targetClaudeDir)) {
    rmSync(targetClaudeDir, { recursive: true, force: true });
  }

  // Copy profile to .claude/
  cpSync(profileDir, targetClaudeDir, { recursive: true });

  // Inject /profiles command so it's always available
  mkdirSync(path.join(targetClaudeDir, "commands"), { recursive: true });
  const profilesMdSrc = path.join(commandsDir, "profiles.md");
  if (existsSync(profilesMdSrc)) {
    cpSync(profilesMdSrc, path.join(targetClaudeDir, "commands", "profiles.md"));
  }

  console.log(`Profile "${name}" applied to ${target}`);
}
