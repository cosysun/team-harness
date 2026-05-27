import path from "node:path";
import fs from "fs-extra";
import { findHarnessRoot } from "../paths.js";
import { runUpgrade } from "../install.js";
import { readManifest, compareSemver } from "../manifest.js";

export async function upgradeCommand(
  cwd: string,
  opts: { yes?: boolean; dryRun?: boolean }
): Promise<number> {
  const harnessRoot = findHarnessRoot(cwd);
  const existing = await readManifest(cwd);

  if (existing) {
    const pkg = (await fs.readJson(
      path.join(harnessRoot, "package.json")
    )) as { version: string };
    const cmp = compareSemver(pkg.version, existing.version);
    if (cmp <= 0 && !opts.dryRun) {
      console.log(
        `Already at harness ${existing.version} (package ${pkg.version}).`
      );
    } else if (cmp > 0) {
      console.log(`Upgrading harness ${existing.version} → ${pkg.version}`);
    }
  }

  const { manifest, planned } = await runUpgrade(cwd, harnessRoot, opts);

  if (opts.dryRun) {
    console.log("\nDry run — would add/update:");
    for (const p of planned) {
      console.log(`  ${p.dest} ← ${p.source}`);
    }
    return 0;
  }

  console.log(`\n✓ Upgraded to harness ${manifest.version}`);
  if (planned.length === 0) {
    console.log("  No new files to install.");
  } else {
    console.log(`  Added ${planned.length} file(s).`);
  }

  if (!opts.yes) {
    console.log(
      "\nTip: use --yes to overwrite generated files on future upgrades."
    );
  }

  return 0;
}
