export type IdeTarget = "cursor" | "codebuddy" | "claude" | "codex";

/** CLI / manifest shorthand (may expand to multiple {@link IdeTarget}). */
export type IdeChoice = IdeTarget | "both" | "all";

export type StackId =
  | "global"
  | "git"
  | "golang"
  | "python"
  | "frontend"
  | "docker"
  | "zsh";

export type PrimaryStack = "golang" | "python" | "frontend" | "generic";

export type InstalledKind =
  | "rule"
  | "template"
  | "scaffold"
  | "agents"
  | "docs"
  | "command"
  | "subagent";

export interface InstalledEntry {
  path: string;
  source: string;
  kind: InstalledKind;
}

export interface HarnessFeatures {
  precommit: boolean;
  ci: "github" | false;
  skills: boolean;
  skeleton: boolean;
  commands: boolean;
  agents: boolean;
}

export interface HarnessProject {
  name: string;
  description?: string;
  primaryStack: PrimaryStack;
}

export interface HarnessManifest {
  version: string;
  harnessRef?: string;
  /** Shorthand from init (cursor, both, all, or comma-separated custom). */
  ide: IdeChoice;
  /** Resolved IDE targets; preferred for doctor/upgrade. */
  ides?: IdeTarget[];
  stacks: StackId[];
  features: HarnessFeatures;
  project?: HarnessProject;
  installed: InstalledEntry[];
}

export interface StackDef {
  label: string;
  always?: boolean;
  optional?: boolean;
  detect?: string[];
  rules: string[];
}

export interface FeatureDef {
  label: string;
  files: string[];
  /** Workflow features: only install for these IDE targets (excludes codex). */
  ides?: IdeTarget[];
}

export type RulesFormat = "mdc" | "md";

export interface IdeDef {
  label: string;
  rulesDir?: string;
  /** How rules are written under rulesDir (default mdc). */
  rulesFormat?: RulesFormat;
  planDir?: string;
  skillsDir?: string;
  commandsDir?: string;
  agentsDir?: string;
  /** Project instruction file(s), relative to repo root. */
  contextFiles?: string[];
  /** Optional project config (e.g. Codex .codex/config.toml). */
  configFiles?: string[];
}

export interface Catalog {
  stacks: Record<string, StackDef>;
  features: Record<string, FeatureDef>;
  ides: Record<string, IdeDef>;
}

export interface InitOptions {
  cwd: string;
  harnessRoot: string;
  ide: IdeChoice;
  ides: IdeTarget[];
  stacks: StackId[];
  features: HarnessFeatures;
  projectName: string;
  projectDescription?: string;
  primaryStack: PrimaryStack;
  dryRun?: boolean;
  yes?: boolean;
}
