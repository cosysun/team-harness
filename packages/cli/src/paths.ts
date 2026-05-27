import path from "node:path";
import { fileURLToPath } from "node:url";
import fs from "fs-extra";
import type { IdeTarget } from "./types.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** Repo root: team-harness/ (three levels up from packages/cli/dist or src) */
export function findHarnessRoot(startDir: string): string {
  let dir = path.resolve(startDir);
  const root = path.parse(dir).root;

  while (dir !== root) {
    const catalog = path.join(dir, "catalog", "stacks.json");
    if (fs.existsSync(catalog)) {
      return dir;
    }
    dir = path.dirname(dir);
  }

  const fromPackage = path.resolve(__dirname, "../../..");
  if (fs.existsSync(path.join(fromPackage, "catalog", "stacks.json"))) {
    return fromPackage;
  }

  throw new Error(
    "Could not locate team-harness root (missing catalog/stacks.json). Run from the harness repo or install @team/harness."
  );
}

export function rulesDirsForTargets(targets: IdeTarget[]): string[] {
  const dirs: string[] = [];
  if (targets.includes("cursor")) dirs.push(".cursor/rules");
  if (targets.includes("codebuddy")) dirs.push(".codebuddy/rules");
  if (targets.includes("claude")) dirs.push(".claude/rules");
  return dirs;
}

export function planDirsForTargets(targets: IdeTarget[]): string[] {
  const dirs: string[] = [];
  if (targets.includes("cursor")) dirs.push(".cursor/plan");
  if (targets.includes("codebuddy")) dirs.push(".codebuddy/plan");
  if (targets.includes("claude")) dirs.push(".claude/plan");
  return dirs;
}

export function skillsDirsForTargets(targets: IdeTarget[]): string[] {
  const dirs: string[] = [];
  if (targets.includes("cursor")) dirs.push(".cursor/skills");
  if (targets.includes("codebuddy")) dirs.push(".codebuddy/skills");
  if (targets.includes("claude")) dirs.push(".claude/skills");
  return dirs;
}

/** @deprecated Use rulesDirsForTargets */
export function rulesDirsForIde(
  ide: "cursor" | "codebuddy" | "both"
): string[] {
  if (ide === "both") return [".cursor/rules", ".codebuddy/rules"];
  if (ide === "codebuddy") return [".codebuddy/rules"];
  return [".cursor/rules"];
}

export function manifestPath(cwd: string): string {
  return path.join(cwd, ".harness.yaml");
}

export function ruleFileName(sourcePath: string): string {
  return path.basename(sourcePath);
}
