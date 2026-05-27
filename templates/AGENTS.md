# AI 开发助手说明书

## 项目概述
本项目是 [项目名称]，基于 Go 微服务架构，使用 [框架名] 框架。

## 架构说明
- 分层架构：Controller → Service → Repository → Model
- 详细架构文档：参见 `docs/ARCHITECTURE.md`

## 目录结构
- `internal/` - 业务逻辑（按服务拆分子目录）
- `pkg/` - 公共工具库
- `api/` - API 定义（Proto/Swagger）
- `configs/` - 配置文件
- `scripts/` - 脚本工具

## 开发规范
- 代码规范：参见 `.codebuddy/rules/go.mdc`
- 数据库规范：所有查询走 Repository 层
- 错误处理：统一使用 `pkg/errors` 包装错误

## 常用命令
- 编译：`go build ./...`
- 测试：`go test ./...`
- Lint：`golangci-lint run`

## 当前进行中的需求
- 参见 `.codebuddy/plan/` 目录下的活跃需求

## 注意事项
- 添加新功能前，先检查 `pkg/` 下是否已有可复用的工具
- 数据库变更必须先生成 SQL 脚本
- 所有 API 变更需要更新 Swagger 文档
