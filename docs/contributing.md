# Contributing

## 新增一种语言栈

1. 在 `rules/stacks/<stackId>/` 添加 `.mdc` 文件，设置准确的 `globs` frontmatter。
2. 在 `catalog/stacks.json` 注册 stack：
   - `label`、`detect`（可选）、`rules` 路径列表
3. 添加 `templates/agents/stacks/<stackId>.md.hbs`（若与 generic 差异大）。
4. 在 `schema/harness.schema.json` 的 `stacks` enum 中加入 id（若需严格校验）。
5. 运行 `team-harness list` 确认展示正确。
6. 在临时目录执行 `team-harness init --stacks <stackId> --non-interactive -y` 做冒烟测试。

## 新增 IDE 目标

1. 在 `catalog/stacks.json` → `ides` 注册路径、`rulesFormat`、`contextFiles`。
2. 若需新规则格式，在 `packages/cli/src/rules-convert.ts` 或 `install.ts` 增加投影逻辑。
3. 更新 `schema/harness.schema.json` 与 `packages/cli/src/ide.ts` 中的目标列表。

## 修改全局规范

编辑 `rules/global/engineering.mdc` 或 `rules/global/git.mdc`。避免在此放入语言专有内容。

## 发布版本

1. 更新 `package.json` 与 `packages/cli/package.json` 的 `version`。
2. 编写 `CHANGELOG.md`。
3. `npm run build`
4. 业务项目运行 `team-harness upgrade` 获取新 scaffold 文件。

## CLI 开发

```bash
cd packages/cli
npm run dev    # tsc --watch
node dist/index.js list
```

Harness root 解析：从当前工作目录向上查找 `catalog/stacks.json`，或从 CLI 包位置回退到仓库根。

## 测试清单

- [ ] `team-harness init` 交互与非交互
- [ ] `team-harness doctor` 在 healthy / 缺失文件场景
- [ ] `team-harness upgrade --dry-run`
- [ ] `ide: both` 双目录规则一致
