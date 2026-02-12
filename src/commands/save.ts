import { existsSync, cpSync, rmSync, mkdirSync, writeFileSync, unlinkSync } from "node:fs";
import path from "node:path";
import { isValidProfileName, isBuiltinProfile } from "../utils/profiles.js";

export function saveAction(
  name: string,
  options: { repoRoot: string; target?: string; description?: string; force?: boolean },
): void {
  const profilesDir = path.join(options.repoRoot, "claude-profiles");
  const customProfilesDir = path.join(options.repoRoot, "custom-profiles");

  // Validate --description has a real value (not another flag)
  if (options.description && options.description.startsWith("--")) {
    process.stderr.write("Error: --description requires a value.\n");
    process.exit(1);
  }

  // Validate profile name
  if (!isValidProfileName(name)) {
    process.stderr.write(
      "Error: Profile name must contain only letters, numbers, hyphens, and underscores.\n",
    );
    process.exit(1);
  }

  // Prevent shadowing built-in profiles
  if (isBuiltinProfile(name, profilesDir)) {
    process.stderr.write(
      `Error: "${name}" is a built-in profile name. Choose a different name.\n`,
    );
    process.exit(1);
  }

  // Resolve target directory
  const target = options.target || path.resolve(options.repoRoot, "..");
  const targetClaudeDir = path.join(target, ".claude");

  if (!existsSync(targetClaudeDir)) {
    process.stderr.write(`Error: No .claude/ directory found at ${targetClaudeDir}\n`);
    process.exit(1);
  }

  const saveDir = path.join(customProfilesDir, name);

  // Handle existing profile
  if (existsSync(saveDir)) {
    if (options.force) {
      rmSync(saveDir, { recursive: true, force: true });
    } else {
      process.stderr.write(
        `Error: Profile "${name}" already exists. Use --force to overwrite.\n`,
      );
      process.exit(1);
    }
  }

  // Create custom-profiles directory if needed
  mkdirSync(customProfilesDir, { recursive: true });

  // Copy .claude/ to custom-profiles/<name>
  cpSync(targetClaudeDir, saveDir, { recursive: true });

  // Strip injected profiles.md (it gets re-injected on swap)
  const injectedProfilesMd = path.join(saveDir, "commands", "profiles.md");
  if (existsSync(injectedProfilesMd)) {
    unlinkSync(injectedProfilesMd);
  }

  // Generate profile.json
  const description =
    options.description ||
    `Custom profile saved on ${new Date().toISOString().split("T")[0]}`;

  writeFileSync(
    path.join(saveDir, "profile.json"),
    JSON.stringify({ name, description }, null, 2) + "\n",
  );

  console.log(`Profile "${name}" saved to ${saveDir}`);
}
