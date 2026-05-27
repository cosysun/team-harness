import path from "node:path";
import readline from "node:readline/promises";
import { stdin as input, stdout as output } from "node:process";
import fs from "fs-extra";
import type {
  HarnessFeatures,
  IdeChoice,
  PrimaryStack,
  StackId,
} from "../types.js";
import { findHarnessRoot } from "../paths.js";
import { loadCatalog, defaultStacks, optionalStackIds } from "../catalog.js";
import {
  detectStacks,
  detectProjectName,
  inferPrimaryStack,
} from "../detect.js";
import { planInit, runInit } from "../install.js";
import { readManifest } from "../manifest.js";
import { parseIdeArg } from "../ide.js";
import type { IdeTarget } from "../types.js";

export interface InitCliOptions {
  cwd?: string;
  /** Single IDE, `both`, `all`, or comma-separated: `cursor,claude,codex` */
  ide?: string;
  stacks?: string;
  precommit?: boolean;
  noPrecommit?: boolean;
  ci?: boolean;
  noCi?: boolean;
  skills?: boolean;
  skeleton?: boolean;
  noSkeleton?: boolean;
  commands?: boolean;
  noCommands?: boolean;
  agents?: boolean;
  noAgents?: boolean;
  name?: string;
  description?: string;
  primaryStack?: PrimaryStack;
  dryRun?: boolean;
  yes?: boolean;
  nonInteractive?: boolean;
}

async function promptChoice<T extends string>(
  rl: readline.Interface,
  question: string,
  choices: { value: T; label: string }[]
): Promise<T> {
  console.log(question);
  choices.forEach((c, i) => console.log(`  ${i + 1}. ${c.label}`));
  const answer = await rl.question(`Choose [1-${choices.length}]: `);
  const idx = parseInt(answer, 10) - 1;
  if (idx >= 0 && idx < choices.length) {
    return choices[idx]!.value;
  }
  return choices[0]!.value;
}

async function promptConfirm(
  rl: readline.Interface,
  question: string,
  defaultYes = true
): Promise<boolean> {
  const hint = defaultYes ? "Y/n" : "y/N";
  const answer = await rl.question(`${question} (${hint}): `);
  if (!answer.trim()) return defaultYes;
  return /^y/i.test(answer);
}

export async function initCommand(opts: InitCliOptions): Promise<number> {
  const cwd = path.resolve(opts.cwd ?? process.cwd());
  const harnessRoot = findHarnessRoot(harnessRootCandidate(cwd, opts));

  const existing = await readManifest(cwd);
  if (existing && !opts.yes && !opts.dryRun) {
    console.error(
      ".harness.yaml already exists. Use --yes to overwrite files or team-harness upgrade."
    );
    return 1;
  }

  const catalog = await loadCatalog(harnessRoot);
  const rl = opts.nonInteractive
    ? null
    : readline.createInterface({ input, output });

  try {
    let ide: IdeChoice = "cursor";
    let ides: IdeTarget[] = ["cursor"];
    if (opts.ide) {
      const parsed = parseIdeArg(opts.ide);
      ide = parsed.choice;
      ides = parsed.targets;
    } else if (rl) {
      ide = await promptChoice(rl, "Target IDE:", [
        { value: "cursor", label: "Cursor (.cursor/rules + AGENTS.md)" },
        { value: "codebuddy", label: "CodeBuddy (.codebuddy/rules + AGENTS.md)" },
        { value: "claude", label: "Claude Code (.claude/rules + CLAUDE.md)" },
        { value: "codex", label: "Codex CLI (AGENTS.md + .codex/config.toml)" },
        { value: "both", label: "Cursor + CodeBuddy" },
        { value: "all", label: "All supported IDEs" },
      ]);
      ides = parseIdeArg(ide).targets;
    }

    let stacks: StackId[] = defaultStacks(catalog);
    const detected = await detectStacks(cwd, catalog);
    if (opts.stacks) {
      stacks = opts.stacks.split(",").map((s) => s.trim()) as StackId[];
    } else if (rl) {
      const detectedStr = detected.filter((s) => !defaultStacks(catalog).includes(s));
      console.log(
        `\nDetected stacks: ${detected.join(", ")}` +
          (detectedStr.length ? "" : " (no extra stacks)")
      );
      const useDetected = await promptConfirm(
        rl,
        "Use detected stacks?",
        true
      );
      stacks = useDetected ? detected : defaultStacks(catalog);
      if (!useDetected) {
        console.log("Optional stacks:", optionalStackIds(catalog).join(", "));
        const custom = await rl.question(
          "Comma-separated stack ids (empty = defaults only): "
        );
        if (custom.trim()) {
          stacks = [
            ...defaultStacks(catalog),
            ...custom.split(",").map((s) => s.trim() as StackId),
          ];
        }
      }
    } else {
      stacks = detected;
    }

    // Ensure always-on stacks
    for (const s of defaultStacks(catalog)) {
      if (!stacks.includes(s)) stacks.push(s);
    }

    let features: HarnessFeatures = {
      precommit: opts.precommit ?? (!opts.noPrecommit && !opts.nonInteractive),
      ci: opts.noCi
        ? false
        : opts.ci
          ? "github"
          : opts.nonInteractive
            ? false
            : "github",
      skills: opts.skills ?? false,
      skeleton: opts.skeleton ?? (!opts.noSkeleton),
      commands: opts.commands ?? false,
      agents: opts.agents ?? false,
    };

    if (rl && !opts.nonInteractive) {
      features.precommit = await promptConfirm(
        rl,
        "Install pre-commit config?",
        features.precommit
      );
      features.ci = (await promptConfirm(
        rl,
        "Install GitHub Actions CI template?",
        features.ci === "github"
      ))
        ? "github"
        : false;
      features.skills = await promptConfirm(
        rl,
        "Create skills directory placeholder?",
        false
      );
      features.skeleton = await promptConfirm(
        rl,
        "Create docs/ and scripts/ skeleton?",
        features.skeleton
      );
      features.commands = await promptConfirm(
        rl,
        "Install starter slash commands (review, ship, debug)?",
        false
      );
      features.agents = await promptConfirm(
        rl,
        "Install starter subagents (explore, code-reviewer)?",
        false
      );
    }

    if (opts.noCommands) features.commands = false;
    if (opts.noAgents) features.agents = false;

    const projectName =
      opts.name ?? (rl ? await detectProjectName(cwd) : path.basename(cwd));
    const primaryStack =
      opts.primaryStack ?? inferPrimaryStack(stacks);

    const initOpts = {
      cwd,
      harnessRoot,
      ide,
      ides,
      stacks,
      features,
      projectName,
      projectDescription: opts.description ?? "",
      primaryStack,
      dryRun: opts.dryRun,
      yes: opts.yes,
    };

    const planned = await planInit(initOpts);
    console.log("\nFiles to install:");
    for (const p of planned) {
      console.log(`  ${p.dest} ← ${p.source}`);
    }

    if (rl && !opts.nonInteractive && !opts.dryRun) {
      const ok = await promptConfirm(rl, "\nProceed?", true);
      if (!ok) {
        console.log("Aborted.");
        return 1;
      }
    }

    const manifest = await runInit(initOpts);
    if (opts.dryRun) {
      console.log("\nDry run complete (no files written).");
    } else {
      console.log(`\n✓ Initialized team-harness ${manifest.version}`);
      console.log(`  Manifest: .harness.yaml`);
      console.log(`  Run: team-harness doctor`);
    }

    return 0;
  } finally {
    rl?.close();
  }
}

function harnessRootCandidate(cwd: string, opts: InitCliOptions): string {
  if (opts.nonInteractive) return cwd;
  return cwd;
}
