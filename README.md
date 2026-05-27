# team-harness

团队通用的 **AI 编码 Harness 脚手架**：一套规则、模板与 CLI，适用于任意编程语言项目。

## 功能

- **规则分层**：全局工程规范 + Git 工作流 + 按语言栈可选包（Go、Python、前端、Docker、Shell）
- **多 IDE**：`init` 时选择 Cursor、CodeBuddy、Claude Code、Codex CLI，或组合（`--ide all` / `cursor,claude`）
- **项目上下文**：自动生成 `AGENTS.md` 与 `docs/ARCHITECTURE.md`
- **DevX 可选**：pre-commit、GitHub Actions CI、目录骨架、skills 占位
- **工作流可选**：starter 斜杠命令（`review` / `ship` / `debug`）与子代理（`explore` / `code-reviewer`），支持 Cursor / Claude / CodeBuddy
- **可升级**：`.harness.yaml` 记录已安装文件，`doctor` / `upgrade` 保持一致

## 快速开始

```bash
# 在 team-harness 仓库内
npm install
npm run build

# 在目标项目目录
node /path/to/team-harness/packages/cli/dist/index.js init

# 或非交互
team-harness init --non-interactive --ide cursor --stacks golang,git,global --commands --agents -y
```

## CLI 命令

| 命令 | 说明 |
|------|------|
| `team-harness init` | 检测技术栈，安装规则与模板，写入 `.harness.yaml`（支持 `--ide claude,codex`） |
| `team-harness doctor` | 检查 manifest 与磁盘文件是否一致 |
| `team-harness list` | 列出可用 stacks 与 features |
| `team-harness upgrade` | 按当前 manifest 安装 harness 新版本新增文件 |

## 目录结构

```
team-harness/
├── catalog/stacks.json      # 栈与 feature 清单
├── rules/
│   ├── global/              # 语言无关 + Git
│   └── stacks/              # golang, python, frontend, ...
├── templates/agents/        # AGENTS.md Handlebars 模板
├── scaffold/                # pre-commit、CI、skills、skeleton、workflows
├── packages/cli/            # TypeScript CLI
├── schema/harness.schema.json
└── docs/
```

## 文档

- [Getting started](docs/getting-started.md)
- [Architecture](docs/architecture.md)
- [Contributing](docs/contributing.md)

## 许可证

MIT
