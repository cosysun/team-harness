# Getting started

## 1. 安装 CLI

从本仓库构建：

```bash
git clone <your-org>/team-harness
cd team-harness
npm install
npm run build
```

全局链接（可选）：

```bash
npm link
```

## 2. 在新项目中初始化

```bash
cd your-project
team-harness init
```

交互流程：

1. 选择 IDE：`cursor` / `codebuddy` / `claude` / `codex` / `both` / `all`（或 `--ide cursor,claude`）
2. 确认检测到的技术栈（`go.mod` → golang，`package.json` → frontend，等）
3. 选择 pre-commit、CI、skills、skeleton、commands、agents
4. 确认文件列表后安装

生成物示例：

- `.harness.yaml` — manifest
- `.cursor/rules/*.mdc` 或 `.claude/rules/*.md` — AI 规则（视 IDE 而定）
- `AGENTS.md` / `CLAUDE.md` — 项目 AI 说明书
- `.cursor/commands/*.md`、`.cursor/agents/*.md` — 可选工作流 starter（`--commands` / `--agents`）
- `.codex/config.toml` — Codex 项目配置（选用 Codex 时；Codex 不安装 commands/agents）
- `docs/ARCHITECTURE.md` — 架构占位

## 3. 健康检查

```bash
team-harness doctor
```

## 4. 升级 harness

在 team-harness 仓库更新后，于业务项目执行：

```bash
team-harness upgrade
team-harness upgrade --dry-run   # 预览
```

## 非交互示例

```bash
team-harness init \
  --non-interactive \
  --ide claude,codex \
  --stacks global,git,golang,docker \
  --name my-api \
  --primary-stack golang \
  --precommit --ci --skeleton \
  --commands --agents \
  -y
```

## 仅拷贝规则（无 CLI）

仍可手工将 `rules/global/` 与 `rules/stacks/<stack>/` 复制到 `.cursor/rules/`，但无法获得 manifest 与 `upgrade`/`doctor` 能力。
