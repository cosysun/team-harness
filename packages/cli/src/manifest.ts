import fs from "fs-extra";
import { parse, stringify } from "yaml";
import type { HarnessFeatures, HarnessManifest } from "./types.js";
import { manifestPath } from "./paths.js";

export function normalizeFeatures(
  features: Partial<HarnessFeatures> | undefined
): HarnessFeatures {
  return {
    precommit: features?.precommit ?? false,
    ci: features?.ci ?? false,
    skills: features?.skills ?? false,
    skeleton: features?.skeleton ?? true,
    commands: features?.commands ?? false,
    agents: features?.agents ?? false,
  };
}

export async function readManifest(cwd: string): Promise<HarnessManifest | null> {
  const file = manifestPath(cwd);
  if (!(await fs.pathExists(file))) {
    return null;
  }
  const raw = await fs.readFile(file, "utf8");
  const manifest = parse(raw) as HarnessManifest;
  manifest.features = normalizeFeatures(manifest.features);
  return manifest;
}

export async function writeManifest(
  cwd: string,
  manifest: HarnessManifest
): Promise<void> {
  const file = manifestPath(cwd);
  const content = stringify(manifest, { lineWidth: 0 });
  await fs.writeFile(file, content, "utf8");
}

export function compareSemver(a: string, b: string): number {
  const pa = a.replace(/^v/, "").split(".").map(Number);
  const pb = b.replace(/^v/, "").split(".").map(Number);
  for (let i = 0; i < 3; i++) {
    const diff = (pa[i] ?? 0) - (pb[i] ?? 0);
    if (diff !== 0) return diff;
  }
  return 0;
}
