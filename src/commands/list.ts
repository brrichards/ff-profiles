import path from "node:path";
import { listProfilesInDir } from "../utils/profiles.js";

export function listAction(options: { repoRoot: string }): void {
  const profilesDir = path.join(options.repoRoot, "claude-profiles");
  const customProfilesDir = path.join(options.repoRoot, "custom-profiles");

  console.log("Available profiles:");
  console.log("");

  const builtins = listProfilesInDir(profilesDir);
  for (const p of builtins) {
    console.log(`  ${p.name.padEnd(20)} ${p.description}`);
  }

  const customs = listProfilesInDir(customProfilesDir);
  for (const p of customs) {
    console.log(`  ${p.name.padEnd(20)} [custom] ${p.description}`);
  }

  console.log("");
}
