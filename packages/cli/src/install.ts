import path from "node:path";
import fs from "fs-extra";
import type {
  HarnessManifest,
  InitOptions,
  InstalledEntry,
} from "./types.js";
import {
  loadCatalog,
  planWorkflowFeature,
  rulesForStacks,
  featureFiles,
} from "./catalog.js";
import {
  findHarnessRoot,
  manifestPath,
  ruleFileName,
} from "./paths.js";
import {
  buildAgentsContext,
  renderAgents,
  renderArchitecture,
  renderClaude,
  skillsDirsForInit,
} from "./templates.js";
import { normalizeFeatures, readManifest, writeManifest } from "./manifest.js";
import {
  getIdeDef,
  ideTargetsWithRules,
  manifestIdeTargets,
  usesAgentsMd,
  usesClaudeMd,
} from "./ide.js";
import { mdcToClaudeRule, ruleDestBasename } from "./rules-convert.js";

export interface PlannedFile {
  dest: string;
  source: string;
  kind: InstalledEntry["kind"];
  action: "copy" | "generate" | "copy-claude-rule";
}

export async function planInit(options: InitOptions): Promise<PlannedFile[]> {
  const catalog = await loadCatalog(options.harnessRoot);
  const planned: PlannedFile[] = [];
  const ruleSources = rulesForStacks(catalog, options.stacks);

  for (const target of ideTargetsWithRules(catalog, options.ides)) {
    const def = getIdeDef(catalog, target);
    const rulesDir = def.rulesDir!;
    const format = def.rulesFormat ?? "mdc";

    for (const source of ruleSources) {
      const destName = ruleDestBasename(source, format);
      planned.push({
        dest: path.join(rulesDir, destName),
        source,
        kind: "rule",
        action: format === "md" ? "copy-claude-rule" : "copy",
      });
    }
  }

  if (usesAgentsMd(options.ides)) {
    planned.push({
      dest: "AGENTS.md",
      source: "generated:agents",
      kind: "agents",
      action: "generate",
    });
  }

  if (usesClaudeMd(options.ides)) {
    planned.push({
      dest: "CLAUDE.md",
      source: "generated:claude",
      kind: "agents",
      action: "generate",
    });
  }

  planned.push({
    dest: "docs/ARCHITECTURE.md",
    source: "generated:architecture",
    kind: "docs",
    action: "generate",
  });

  if (options.features.skeleton) {
    for (const f of featureFiles(catalog, "skeleton")) {
      planned.push({
        dest: f.replace(/^scaffold\/skeleton\//, ""),
        source: f,
        kind: "scaffold",
        action: "copy",
      });
    }
  }

  if (options.features.precommit) {
    for (const f of featureFiles(catalog, "precommit")) {
      planned.push({
        dest: path.basename(f),
        source: f,
        kind: "scaffold",
        action: "copy",
      });
    }
  }

  if (options.features.ci === "github") {
    for (const f of featureFiles(catalog, "ci")) {
      planned.push({
        dest: f.replace(/^scaffold\/ci\//, ""),
        source: f,
        kind: "scaffold",
        action: "copy",
      });
    }
  }

  if (options.features.skills) {
    for (const skillsDir of skillsDirsForInit(options.ides)) {
      planned.push({
        dest: path.join(skillsDir, "README.md"),
        source: "scaffold/skills/README.md",
        kind: "scaffold",
        action: "copy",
      });
    }
  }

  if (options.features.commands) {
    for (const item of planWorkflowFeature(catalog, "commands", options.ides)) {
      planned.push({ ...item, action: "copy" });
    }
  }

  if (options.features.agents) {
    for (const item of planWorkflowFeature(catalog, "agents", options.ides)) {
      planned.push({ ...item, action: "copy" });
    }
  }

  if (options.ides.includes("codex")) {
    for (const f of getIdeDef(catalog, "codex").configFiles ?? []) {
      planned.push({
        dest: f,
        source: `scaffold/codex/${f}`,
        kind: "scaffold",
        action: "copy",
      });
    }
  }

  return planned;
}

export async function executePlan(
  options: InitOptions,
  planned: PlannedFile[]
): Promise<InstalledEntry[]> {
  const installed: InstalledEntry[] = [];
  const ctx = buildAgentsContext(
    options.ides,
    options.projectName,
    options.projectDescription ?? "",
    options.primaryStack,
    options.stacks
  );

  for (const item of planned) {
    const destPath = path.join(options.cwd, item.dest);

    if (options.dryRun) {
      installed.push({
        path: item.dest,
        source: item.source,
        kind: item.kind,
      });
      continue;
    }

    if (item.action === "generate") {
      let content: string;
      if (item.source === "generated:agents") {
        content = await renderAgents(options.harnessRoot, ctx);
      } else if (item.source === "generated:claude") {
        content = await renderClaude(options.harnessRoot, ctx);
      } else if (item.source === "generated:architecture") {
        content = await renderArchitecture(options.harnessRoot, {
          projectName: options.projectName,
          primaryStack: options.primaryStack,
        });
      } else {
        throw new Error(`Unknown generator: ${item.source}`);
      }
      await fs.ensureDir(path.dirname(destPath));
      if ((await fs.pathExists(destPath)) && !options.yes) {
        console.warn(`Skip existing: ${item.dest}`);
        installed.push({
          path: item.dest,
          source: item.source,
          kind: item.kind,
        });
        continue;
      }
      await fs.writeFile(destPath, content, "utf8");
    } else if (item.action === "copy-claude-rule") {
      const srcPath = path.join(options.harnessRoot, item.source);
      const raw = await fs.readFile(srcPath, "utf8");
      const converted = mdcToClaudeRule(raw, ruleFileName(item.source));
      await fs.ensureDir(path.dirname(destPath));
      if ((await fs.pathExists(destPath)) && !options.yes) {
        console.warn(`Skip existing: ${item.dest}`);
      } else {
        await fs.writeFile(destPath, converted, "utf8");
      }
    } else {
      const srcPath = path.join(options.harnessRoot, item.source);
      await fs.ensureDir(path.dirname(destPath));
      await fs.copy(srcPath, destPath, { overwrite: options.yes ?? false });
    }

    installed.push({
      path: item.dest,
      source: item.source,
      kind: item.kind,
    });
  }

  return installed;
}

export async function runInit(options: InitOptions): Promise<HarnessManifest> {
  const pkgVersion = await getPackageVersion(options.harnessRoot);
  const planned = await planInit(options);
  const installed = await executePlan(options, planned);

  const manifest: HarnessManifest = {
    version: pkgVersion,
    harnessRef: `team-harness@${pkgVersion}`,
    ide: options.ide,
    ides: options.ides,
    stacks: options.stacks,
    features: options.features,
    project: {
      name: options.projectName,
      description: options.projectDescription,
      primaryStack: options.primaryStack,
    },
    installed,
  };

  if (!options.dryRun) {
    await writeManifest(options.cwd, manifest);
  }

  return manifest;
}

async function getPackageVersion(harnessRoot: string): Promise<string> {
  const pkgPath = path.join(harnessRoot, "package.json");
  const pkg = (await fs.readJson(pkgPath)) as { version?: string };
  return pkg.version ?? "0.1.0";
}

export interface DoctorIssue {
  level: "error" | "warn";
  message: string;
}

export async function runDoctor(cwd: string): Promise<DoctorIssue[]> {
  const issues: DoctorIssue[] = [];
  const manifest = await readManifest(cwd);

  if (!manifest) {
    issues.push({
      level: "error",
      message: `Missing ${manifestPath(cwd)} — run team-harness init`,
    });
    return issues;
  }

  let harnessRoot: string;
  try {
    harnessRoot = findHarnessRoot(cwd);
  } catch {
    harnessRoot = findHarnessRoot(path.dirname(manifestPath(cwd)));
  }

  for (const entry of manifest.installed) {
    const full = path.join(cwd, entry.path);
    if (!(await fs.pathExists(full))) {
      issues.push({
        level: "error",
        message: `Missing installed file: ${entry.path}`,
      });
    }
  }

  const agentsPath = path.join(cwd, "AGENTS.md");
  if (await fs.pathExists(agentsPath)) {
    const agents = await fs.readFile(agentsPath, "utf8");
    if (agents.includes("[项目名称]") || agents.includes("[框架名]")) {
      issues.push({
        level: "warn",
        message: "AGENTS.md still contains template placeholders",
      });
    }
  }

  const claudePath = path.join(cwd, "CLAUDE.md");
  if (await fs.pathExists(claudePath)) {
    const claude = await fs.readFile(claudePath, "utf8");
    if (claude.includes("[项目名称]")) {
      issues.push({
        level: "warn",
        message: "CLAUDE.md still contains template placeholders",
      });
    }
  }

  const catalog = await loadCatalog(harnessRoot);
  const targets = manifestIdeTargets(manifest);
  const expectedRules = rulesForStacks(catalog, manifest.stacks);

  for (const target of ideTargetsWithRules(catalog, targets)) {
    const def = getIdeDef(catalog, target);
    const format = def.rulesFormat ?? "mdc";
    for (const source of expectedRules) {
      const destName = ruleDestBasename(source, format);
      const expected = path.join(def.rulesDir!, destName);
      if (!(await fs.pathExists(path.join(cwd, expected)))) {
        issues.push({
          level: "warn",
          message: `Rule not projected: ${expected} (from ${source})`,
        });
      }
    }
  }

  return issues;
}

export async function runUpgrade(
  cwd: string,
  harnessRoot: string,
  opts: { yes?: boolean; dryRun?: boolean }
): Promise<{ manifest: HarnessManifest; planned: PlannedFile[] }> {
  const existing = await readManifest(cwd);
  if (!existing) {
    throw new Error("No .harness.yaml found. Run init first.");
  }

  const pkgVersion = await getPackageVersion(harnessRoot);
  const ides = manifestIdeTargets(existing);
  const initOptions: InitOptions = {
    cwd,
    harnessRoot,
    ide: existing.ide,
    ides,
    stacks: existing.stacks,
    features: normalizeFeatures(existing.features),
    projectName: existing.project?.name ?? "project",
    projectDescription: existing.project?.description,
    primaryStack: existing.project?.primaryStack ?? "generic",
    dryRun: opts.dryRun,
    yes: opts.yes ?? false,
  };

  const planned = await planInit(initOptions);
  const existingPaths = new Set(existing.installed.map((e) => e.path));
  const toAdd = planned.filter((p) => !existingPaths.has(p.dest));
  const installed = [...existing.installed];

  if (!opts.dryRun) {
    const added = await executePlan(
      { ...initOptions, yes: opts.yes ?? false },
      toAdd
    );
    for (const entry of added) {
      if (!existingPaths.has(entry.path)) {
        installed.push(entry);
      }
    }

    const manifest: HarnessManifest = {
      ...existing,
      version: pkgVersion,
      harnessRef: `team-harness@${pkgVersion}`,
      ides,
      installed,
    };
    await writeManifest(cwd, manifest);
    return { manifest, planned: toAdd };
  }

  return {
    manifest: { ...existing, version: pkgVersion, ides, installed },
    planned: toAdd,
  };
}
