---
description: Go backend architecture constraints — layered design, data access, and API documentation.
globs: "**/*.go"
alwaysApply: false
---

# Go Backend Architecture

## Architecture constraints (hard rules)

1. Follow layered architecture: Controller → Service → Repository → Model.
2. Controllers must not contain business logic; they validate input and format responses only.
3. All database access goes through the Repository layer; no raw SQL in Service layers.
4. All public APIs must include Swagger/OpenAPI annotations or equivalent generated docs.

## Code style

1. Brief comments on exported functions and non-obvious logic.
2. Never ignore errors with `_`; handle or propagate explicitly.
3. Use camelCase for variables; ALL_CAPS for constants.
4. Keep functions under ~80 lines; split when larger.

## Security

1. Generate SQL migration scripts for schema changes instead of applying ad hoc DDL in application code.
2. Load sensitive configuration from environment or config center; no hardcoded secrets.

## Development behavior

1. Reuse existing `pkg/` or shared utilities before adding new helpers.
2. Pair feature work with unit tests in the same PR.
