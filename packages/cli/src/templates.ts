import path from "node:path";
import fs from "fs-extra";
import Handlebars from "handlebars";
import type { IdeTarget, PrimaryStack } from "./types.js";
import {
  planDirsForTargets,
  rulesDirsForTargets,
  skillsDirsForTargets,
} from "./paths.js";

export interface AgentsTemplateContext {
  projectName: string;
  projectDescription: string;
  primaryStack: PrimaryStack;
  rulesPath: string;
  planPath: string;
  stacks: string[];
  ides: IdeTarget[];
  hasClaude: boolean;
  hasCodex: boolean;
  hasMdcRules: boolean;
  mdcRulesPath: string;
  claudeRulesPath: string;
}

function joinPaths(paths: string[]): string {
  if (paths.length === 0) return "(none)";
  if (paths.length === 1) return paths[0]!;
  if (paths.length === 2) return `${paths[0]} and ${paths[1]}`;
  return `${paths.slice(0, -1).join(", ")}, and ${paths.at(-1)}`;
}

export function buildAgentsContext(
  ides: IdeTarget[],
  projectName: string,
  projectDescription: string,
  primaryStack: PrimaryStack,
  stacks: string[]
): AgentsTemplateContext {
  const mdcDirs = rulesDirsForTargets(
    ides.filter((i) => i === "cursor" || i === "codebuddy")
  );
  const planDirs = planDirsForTargets(ides);

  return {
    projectName,
    projectDescription,
    primaryStack,
    rulesPath: joinPaths(rulesDirsForTargets(ides)),
    planPath: joinPaths(planDirs.map((d) => `${d}/`)),
    stacks,
    ides,
    hasClaude: ides.includes("claude"),
    hasCodex: ides.includes("codex"),
    hasMdcRules: mdcDirs.length > 0,
    mdcRulesPath: joinPaths(mdcDirs),
    claudeRulesPath: ".claude/rules",
  };
}

export async function renderAgents(
  harnessRoot: string,
  ctx: AgentsTemplateContext
): Promise<string> {
  const templatesDir = path.join(harnessRoot, "templates", "agents");
  const basePath = path.join(templatesDir, "base.md.hbs");
  const stackPath = path.join(
    templatesDir,
    "stacks",
    `${ctx.primaryStack}.md.hbs`
  );

  const baseTpl = Handlebars.compile(await fs.readFile(basePath, "utf8"));
  let stackSection = "";
  if (await fs.pathExists(stackPath)) {
    const stackTpl = Handlebars.compile(await fs.readFile(stackPath, "utf8"));
    stackSection = stackTpl(ctx);
  }

  return baseTpl({ ...ctx, stackSection });
}

/** Claude Code reads CLAUDE.md; content mirrors AGENTS with Claude-specific notes. */
export async function renderClaude(
  harnessRoot: string,
  ctx: AgentsTemplateContext
): Promise<string> {
  const tplPath = path.join(harnessRoot, "templates", "claude", "CLAUDE.md.hbs");
  const body = await renderAgents(harnessRoot, ctx);
  const wrapperTpl = Handlebars.compile(await fs.readFile(tplPath, "utf8"));
  return wrapperTpl({ ...ctx, agentsBody: body });
}

export async function renderArchitecture(
  harnessRoot: string,
  ctx: { projectName: string; primaryStack: PrimaryStack }
): Promise<string> {
  const tplPath = path.join(
    harnessRoot,
    "templates",
    "docs",
    "ARCHITECTURE.md.hbs"
  );
  const tpl = Handlebars.compile(await fs.readFile(tplPath, "utf8"));
  return tpl(ctx);
}

export function skillsDirsForInit(ides: IdeTarget[]): string[] {
  return skillsDirsForTargets(ides);
}
