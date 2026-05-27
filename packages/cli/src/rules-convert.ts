/**
 * Convert Cursor/CodeBuddy .mdc rule files to Claude Code .md rules.
 * @see https://code.claude.com/docs/en/memory
 */
export function mdcToClaudeRule(mdcContent: string, basename: string): string {
  const match = mdcContent.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n([\s\S]*)$/);
  if (!match) {
    return mdcContent.replace(/\.mdc$/i, ".md");
  }

  const frontmatter = match[1]!;
  const body = match[2]!.trimStart();
  const lines = frontmatter.split(/\r?\n/);
  const out: string[] = [];

  let globs: string | undefined;
  let alwaysApply: string | undefined;
  const passthrough: string[] = [];

  for (const line of lines) {
    const globsMatch = line.match(/^globs:\s*(.+)$/);
    const pathsMatch = line.match(/^paths:\s*(.+)$/);
    const alwaysMatch = line.match(/^alwaysApply:\s*(.+)$/);
    const descMatch = line.match(/^description:\s*(.+)$/);

    if (globsMatch) {
      globs = globsMatch[1]!.replace(/^["']|["']$/g, "");
    } else if (pathsMatch) {
      globs = pathsMatch[1]!.replace(/^["']|["']$/g, "");
    } else if (alwaysMatch) {
      alwaysApply = alwaysMatch[1]!.trim();
    } else if (descMatch) {
      passthrough.push(line);
    } else if (line.trim()) {
      passthrough.push(line);
    }
  }

  out.push("---");

  for (const line of passthrough) {
    out.push(line);
  }

  if (alwaysApply !== undefined) {
    out.push(`alwaysApply: ${alwaysApply}`);
  }

  if (globs) {
    const pathList = globs
      .split(",")
      .map((g) => g.trim())
      .filter(Boolean)
      .join(", ");
    out.push(`paths: ${pathList}`);
  }

  out.push("---");
  out.push("");
  out.push(`<!-- team-harness: ${basename} -->`);
  out.push("");
  out.push(body);

  return out.join("\n");
}

export function ruleDestBasename(
  sourcePath: string,
  format: "mdc" | "md"
): string {
  const base = sourcePath.split("/").pop() ?? sourcePath;
  if (format === "md") {
    return base.replace(/\.mdc$/i, ".md");
  }
  return base;
}
