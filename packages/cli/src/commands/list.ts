import { findHarnessRoot } from "../paths.js";
import { loadCatalog, allStackIds, optionalStackIds } from "../catalog.js";

export async function listCommand(cwd: string): Promise<void> {
  const harnessRoot = findHarnessRoot(cwd);
  const catalog = await loadCatalog(harnessRoot);

  console.log("Stacks:");
  for (const id of allStackIds(catalog)) {
    const def = catalog.stacks[id]!;
    const tags = [
      def.always ? "always" : null,
      def.optional ? "optional" : null,
      def.detect?.length ? `detect: ${def.detect.join(", ")}` : null,
    ]
      .filter(Boolean)
      .join(" | ");
    console.log(`  ${id.padEnd(12)} ${def.label}${tags ? ` (${tags})` : ""}`);
    for (const rule of def.rules) {
      console.log(`    - ${rule}`);
    }
  }

  console.log("\nOptional stacks:", optionalStackIds(catalog).join(", "));

  console.log("\nFeatures:");
  for (const [id, def] of Object.entries(catalog.features)) {
    console.log(`  ${id.padEnd(12)} ${def.label}`);
    for (const f of def.files) {
      console.log(`    - ${f}`);
    }
  }

  console.log("\nIDE targets:");
  for (const [id, def] of Object.entries(catalog.ides)) {
    const parts = [
      def.rulesDir ? `rules → ${def.rulesDir}` : null,
      def.commandsDir ? `commands → ${def.commandsDir}` : null,
      def.agentsDir ? `agents → ${def.agentsDir}` : null,
      def.contextFiles?.length
        ? `context → ${def.contextFiles.join(", ")}`
        : null,
      def.configFiles?.length
        ? `config → ${def.configFiles.join(", ")}`
        : null,
    ].filter(Boolean);
    console.log(`  ${id.padEnd(12)} ${def.label}`);
    for (const p of parts) {
      console.log(`    ${p}`);
    }
  }
}
