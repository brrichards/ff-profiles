import { readdirSync, readFileSync, existsSync, statSync } from "node:fs";
import path from "node:path";

export interface ProfileInfo {
  name: string;
  description: string;
}

export function listProfilesInDir(dir: string): ProfileInfo[] {
  if (!existsSync(dir)) return [];

  const entries = readdirSync(dir);
  const profiles: ProfileInfo[] = [];

  for (const entry of entries) {
    const fullPath = path.join(dir, entry);
    if (!statSync(fullPath).isDirectory()) continue;

    let description = "(no description)";
    const profileJsonPath = path.join(fullPath, "profile.json");
    if (existsSync(profileJsonPath)) {
      try {
        const data = JSON.parse(readFileSync(profileJsonPath, "utf-8"));
        if (data.description) {
          description = data.description;
        }
      } catch {
        // ignore parse errors
      }
    }

    profiles.push({ name: entry, description });
  }

  return profiles;
}

export function resolveProfileDir(
  profileName: string,
  profilesDir: string,
  customProfilesDir: string,
): string | null {
  const builtinPath = path.join(profilesDir, profileName);
  if (existsSync(builtinPath) && statSync(builtinPath).isDirectory()) {
    return builtinPath;
  }

  const customPath = path.join(customProfilesDir, profileName);
  if (existsSync(customPath) && statSync(customPath).isDirectory()) {
    return customPath;
  }

  return null;
}

export function isValidProfileName(name: string): boolean {
  return /^[a-zA-Z0-9_-]+$/.test(name);
}

export function isBuiltinProfile(name: string, profilesDir: string): boolean {
  const builtinPath = path.join(profilesDir, name);
  return existsSync(builtinPath) && statSync(builtinPath).isDirectory();
}
