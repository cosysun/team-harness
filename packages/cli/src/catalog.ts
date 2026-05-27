import path from "node:path";
import fs from "fs-extra";
import type { Catalog, IdeTarget, InstalledKind, StackId } from "./types.js";
import { getIdeDef } from "./ide.js";

export async function loadCatalog(harnessRoot: string): Promise<Catalog> {
  const catalogPath = path.join(harnessRoot, "catalog", "stacks.json");
  return fs.readJson(catalogPath) as Promise<Catalog>;
}

export function allStackIds(catalog: Catalog): StackId[] {
  return Object.keys(catalog.stacks) as StackId[];
}

export function defaultStacks(catalog: Catalog): StackId[] {
  return (Object.entries(catalog.stacks) as [StackId, Catalog["stacks"][string]][])
    .filter(([, def]) => def.always)
    .map(([id]) => id);
}

export function optionalStackIds(catalog: Catalog): StackId[] {
  return (Object.entries(catalog.stacks) as [StackId, Catalog["stacks"][string]][])
    .filter(([, def]) => !def.always)
    .map(([id]) => id);
}

export function rulesForStacks(catalog: Catalog, stacks: StackId[]): string[] {
  const files = new Set<string>();
  for (const stack of stacks) {
    const def = catalog.stacks[stack];
    if (!def) continue;
    for (const rule of def.rules) {
      files.add(rule);
    }
  }
  return [...files];
}

export function featureFiles(
  catalog: Catalog,
  feature: string
): string[] {
  return catalog.features[feature]?.files ?? [];
}

const WORKFLOW_FEATURES = ["commands", "agents"] as const;
export type WorkflowFeature = (typeof WORKFLOW_FEATURES)[number];

/** Map workflow scaffold files to per-IDE command/agent paths. */
export function planWorkflowFeature(
  catalog: Catalog,
  featureKey: WorkflowFeature,
  ides: IdeTarget[]
): { dest: string; source: string; kind: InstalledKind }[] {
  const feature = catalog.features[featureKey];
  if (!feature) return [];

  const allowed = feature.ides ?? ["cursor", "codebuddy", "claude"];
  const dirKey = featureKey === "commands" ? "commandsDir" : "agentsDir";
  const kind: InstalledKind =
    featureKey === "commands" ? "command" : "subagent";
  const planned: { dest: string; source: string; kind: InstalledKind }[] = [];

  for (const target of ides) {
    if (!allowed.includes(target)) continue;
    const def = getIdeDef(catalog, target);
    const dir = def[dirKey];
    if (!dir) continue;

    for (const source of feature.files) {
      planned.push({
        dest: path.join(dir, path.basename(source)),
        source,
        kind,
      });
    }
  }

  return planned;
}
