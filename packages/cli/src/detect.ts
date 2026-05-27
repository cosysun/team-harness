import path from "node:path";
import fs from "fs-extra";
import type { Catalog, PrimaryStack, StackId } from "./types.js";
import { defaultStacks, optionalStackIds } from "./catalog.js";

export async function detectStacks(
  cwd: string,
  catalog: Catalog
): Promise<StackId[]> {
  const found = new Set<StackId>(defaultStacks(catalog));

  for (const stackId of optionalStackIds(catalog)) {
    const def = catalog.stacks[stackId];
    if (!def?.detect?.length) continue;

    for (const marker of def.detect) {
      const direct = path.join(cwd, marker);
      if (await fs.pathExists(direct)) {
        found.add(stackId);
        break;
      }
      // Dockerfile etc. may live in subdirs — shallow scan one level
      if (marker === "Dockerfile" || marker.startsWith("docker-compose")) {
        const entries = await fs.readdir(cwd).catch(() => [] as string[]);
        for (const entry of entries) {
          const p = path.join(cwd, entry, marker);
          if (await fs.pathExists(p)) {
            found.add(stackId);
            break;
          }
        }
      }
    }
  }

  return [...found];
}

export function inferPrimaryStack(stacks: StackId[]): PrimaryStack {
  if (stacks.includes("golang")) return "golang";
  if (stacks.includes("python")) return "python";
  if (stacks.includes("frontend")) return "frontend";
  return "generic";
}

export async function detectProjectName(cwd: string): Promise<string> {
  const pkgPath = path.join(cwd, "package.json");
  if (await fs.pathExists(pkgPath)) {
    const pkg = (await fs.readJson(pkgPath)) as { name?: string };
    if (pkg.name) return pkg.name;
  }
  return path.basename(cwd);
}
