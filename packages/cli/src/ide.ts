import type { Catalog, IdeChoice, IdeDef, IdeTarget } from "./types.js";

const ALL_TARGETS: IdeTarget[] = [
  "cursor",
  "codebuddy",
  "claude",
  "codex",
];

/** Expand manifest / CLI shorthand to concrete IDE targets. */
export function resolveIdeTargets(choice: IdeChoice): IdeTarget[] {
  switch (choice) {
    case "both":
      return ["cursor", "codebuddy"];
    case "all":
      return [...ALL_TARGETS];
    case "cursor":
    case "codebuddy":
    case "claude":
    case "codex":
      return [choice];
    default:
      return [choice];
  }
}

/** Parse `--ide cursor,claude` or single token `all`. */
export function parseIdeArg(value: string): {
  choice: IdeChoice;
  targets: IdeTarget[];
} {
  const trimmed = value.trim();
  if (!trimmed.includes(",")) {
    const choice = trimmed as IdeChoice;
    return { choice, targets: resolveIdeTargets(choice) };
  }

  const parts = trimmed.split(",").map((s) => s.trim()) as IdeTarget[];
  for (const p of parts) {
    if (!ALL_TARGETS.includes(p)) {
      throw new Error(
        `Unknown IDE "${p}". Valid: ${ALL_TARGETS.join(", ")}, both, all`
      );
    }
  }
  const unique = [...new Set(parts)];
  return { choice: trimmed as IdeChoice, targets: unique };
}

export function manifestIdeTargets(
  manifest: { ide: IdeChoice; ides?: IdeTarget[] }
): IdeTarget[] {
  if (manifest.ides?.length) {
    return manifest.ides;
  }
  return resolveIdeTargets(manifest.ide);
}

export function usesAgentsMd(targets: IdeTarget[]): boolean {
  return targets.some((t) => t === "cursor" || t === "codebuddy" || t === "codex");
}

export function usesClaudeMd(targets: IdeTarget[]): boolean {
  return targets.includes("claude");
}

export function ideTargetsWithRules(catalog: Catalog, targets: IdeTarget[]): IdeTarget[] {
  return targets.filter((t) => {
    const def = catalog.ides[t];
    return def?.rulesDir;
  });
}

export function getIdeDef(catalog: Catalog, target: IdeTarget): IdeDef {
  const def = catalog.ides[target];
  if (!def) {
    throw new Error(`IDE "${target}" is not defined in catalog/stacks.json`);
  }
  return def;
}
