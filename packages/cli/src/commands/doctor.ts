import { runDoctor } from "../install.js";

export async function doctorCommand(cwd: string): Promise<number> {
  const issues = await runDoctor(cwd);

  if (issues.length === 0) {
    console.log("✓ Harness healthy — manifest and files are consistent.");
    return 0;
  }

  for (const issue of issues) {
    const prefix = issue.level === "error" ? "✗" : "⚠";
    console.log(`${prefix} [${issue.level}] ${issue.message}`);
  }

  const hasError = issues.some((i) => i.level === "error");
  return hasError ? 1 : 0;
}
