#!/usr/bin/env node
import { Command } from "commander";
import { initCommand } from "./commands/init.js";
import { doctorCommand } from "./commands/doctor.js";
import { listCommand } from "./commands/list.js";
import { upgradeCommand } from "./commands/upgrade.js";
import type { PrimaryStack } from "./types.js";

const program = new Command();

program
  .name("team-harness")
  .description("Team Harness — universal AI coding scaffold for any project")
  .version("0.3.0");

program
  .command("init")
  .description("Initialize harness in the current project")
  .option("-C, --cwd <dir>", "Target project directory", process.cwd())
  .option(
    "--ide <target>",
    "cursor | codebuddy | claude | codex | both | all | comma-separated (e.g. cursor,claude)"
  )
  .option("--stacks <ids>", "Comma-separated stack ids")
  .option("--name <name>", "Project name for AGENTS.md")
  .option("--description <text>", "Project description")
  .option(
    "--primary-stack <stack>",
    "golang | python | frontend | generic"
  )
  .option("--precommit", "Enable pre-commit scaffold")
  .option("--no-precommit", "Disable pre-commit scaffold")
  .option("--ci", "Enable GitHub CI scaffold")
  .option("--no-ci", "Disable GitHub CI scaffold")
  .option("--skills", "Enable skills placeholder")
  .option("--commands", "Install starter slash commands (Cursor/Claude)")
  .option("--no-commands", "Disable slash commands")
  .option("--agents", "Install starter subagents (Cursor/Claude)")
  .option("--no-agents", "Disable subagents")
  .option("--skeleton", "Enable docs/scripts skeleton")
  .option("--no-skeleton", "Disable skeleton")
  .option("--dry-run", "Preview without writing")
  .option("-y, --yes", "Overwrite existing files where applicable")
  .option("--non-interactive", "Skip prompts (use flags or defaults)")
  .action(async (opts) => {
    const code = await initCommand({
      cwd: opts.cwd,
      ide: opts.ide,
      stacks: opts.stacks,
      name: opts.name,
      description: opts.description,
      primaryStack: opts.primaryStack as PrimaryStack | undefined,
      precommit: opts.precommit,
      noPrecommit: opts.noPrecommit,
      ci: opts.ci,
      noCi: opts.noCi,
      skills: opts.skills,
      commands: opts.commands,
      noCommands: opts.noCommands,
      agents: opts.agents,
      noAgents: opts.noAgents,
      skeleton: opts.skeleton,
      noSkeleton: opts.noSkeleton,
      dryRun: opts.dryRun,
      yes: opts.yes,
      nonInteractive: opts.nonInteractive,
    });
    process.exit(code);
  });

program
  .command("doctor")
  .description("Check manifest vs installed files")
  .option("-C, --cwd <dir>", "Project directory", process.cwd())
  .action(async (opts) => {
    const code = await doctorCommand(opts.cwd);
    process.exit(code);
  });

program
  .command("list")
  .description("List available stacks and features")
  .option("-C, --cwd <dir>", "Working directory", process.cwd())
  .action(async (opts) => {
    await listCommand(opts.cwd);
  });

program
  .command("upgrade")
  .description("Install new harness files for the current manifest")
  .option("-C, --cwd <dir>", "Project directory", process.cwd())
  .option("--dry-run", "Preview changes")
  .option("-y, --yes", "Overwrite generated files")
  .action(async (opts) => {
    const code = await upgradeCommand(opts.cwd, {
      yes: opts.yes,
      dryRun: opts.dryRun,
    });
    process.exit(code);
  });

program.parse();
