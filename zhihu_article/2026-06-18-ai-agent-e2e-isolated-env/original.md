# AI Agent 临时 E2E 测试环境方案

## 1. 背景

在使用 Claude Code 或其他 AI coding agent 做开发和测试时，经常需要运行 E2E 测试。

如果所有 agent 共用同一个测试环境，容易出现以下问题：

* 多个 agent 同时测试，端口冲突
* 测试数据互相污染
* 一个 agent 改坏环境，影响其他 agent
* E2E 测试结果不稳定
* 难以复现某次测试环境状态
* 不希望 AI agent 访问 production 或 shared staging 环境

因此，更推荐为每个 agent 或每次测试任务创建一套独立的临时环境。

这种方式通常叫：

```text
Ephemeral Test Environment
Preview Environment
Isolated E2E Environment
```

---

## 2. 核心思路

每个 AI agent 在测试时都创建一套独立环境：

```text
AI agent task starts
        ↓
create unique ENV_ID
        ↓
start Docker Compose / Kubernetes temporary environment
        ↓
seed test data
        ↓
run Playwright E2E tests
        ↓
collect logs / screenshots / reports
        ↓
destroy environment
```

核心原则：

```text
每个 agent 一套环境
每次测试独立运行
测试完成自动销毁
不访问 production
不共用数据库
不硬编码端口
```

---

## 3. 推荐方案一：Docker Compose 临时环境

这是最简单、最适合本地 Claude Code 和 Jenkins agent 的方案。

### 3.1 使用唯一 project name

Docker Compose 支持 `-p` 参数，可以为每次测试指定独立 project name。

例如：

```bash
ENV_ID=agent-$RANDOM
docker compose -p "$ENV_ID" -f docker-compose.e2e.yml up -d --build
```

这样 Docker 会自动创建独立的：

```text
container
network
volume
```

不同 agent 之间不会互相影响。

测试完成后销毁：

```bash
docker compose -p "$ENV_ID" -f docker-compose.e2e.yml down -v --remove-orphans
```

---

## 4. 推荐项目结构

```text
project/
  docker-compose.e2e.yml
  .env.e2e
  Makefile
  scripts/
    e2e-run-isolated.sh
    wait-for-services.sh
    seed-e2e-data.sh
  tests/
    e2e/
      login.spec.ts
      user-flow.spec.ts
  playwright.config.ts
  CLAUDE.md
  .claude/
    agents/
      test-agent.md
      security-agent.md
      review-agent.md
```

---

## 5. Docker Compose 示例

```yaml
services:
  frontend:
    build: ./frontend
    ports:
      - "3000"
    environment:
      API_BASE_URL: http://backend:8080
    depends_on:
      - backend

  backend:
    build: ./backend
    ports:
      - "8080"
    environment:
      SPRING_PROFILES_ACTIVE: e2e
      DB_HOST: db
      DB_PORT: 5432
      DB_NAME: app_e2e
      DB_USER: app
      DB_PASSWORD: app
    depends_on:
      - db
      - wiremock

  db:
    image: postgres:16
    environment:
      POSTGRES_DB: app_e2e
      POSTGRES_USER: app
      POSTGRES_PASSWORD: app
    volumes:
      - db_data:/var/lib/postgresql/data

  wiremock:
    image: wiremock/wiremock:latest
    ports:
      - "8080"
    volumes:
      - ./wiremock:/home/wiremock

volumes:
  db_data:
```

注意：

```text
ports:
  - "3000"
```

表示让 Docker 随机分配 host port，避免多个 agent 同时运行时端口冲突。

不要写成：

```text
ports:
  - "3000:3000"
```

否则多个环境同时运行时会冲突。

---

## 6. Isolated E2E 脚本示例

创建文件：

```text
scripts/e2e-run-isolated.sh
```

内容如下：

```bash
#!/usr/bin/env bash
set -euo pipefail

ENV_ID="agent-${USER:-local}-$(date +%s)-$RANDOM"
COMPOSE_FILE="docker-compose.e2e.yml"

echo "Starting isolated E2E environment: $ENV_ID"

docker compose -p "$ENV_ID" -f "$COMPOSE_FILE" up -d --build

cleanup() {
  echo "Cleaning isolated E2E environment: $ENV_ID"
  docker compose -p "$ENV_ID" -f "$COMPOSE_FILE" down -v --remove-orphans
}

trap cleanup EXIT

echo "Waiting for services..."
./scripts/wait-for-services.sh "$ENV_ID"

FRONTEND_PORT=$(docker compose -p "$ENV_ID" -f "$COMPOSE_FILE" port frontend 3000 | awk -F: '{print $2}')

export E2E_ENV_ID="$ENV_ID"
export E2E_BASE_URL="http://localhost:$FRONTEND_PORT"

echo "Running Playwright tests against $E2E_BASE_URL"

npx playwright test
```

给脚本执行权限：

```bash
chmod +x scripts/e2e-run-isolated.sh
```

运行：

```bash
./scripts/e2e-run-isolated.sh
```

---

## 7. wait-for-services 示例

创建文件：

```text
scripts/wait-for-services.sh
```

内容如下：

```bash
#!/usr/bin/env bash
set -euo pipefail

ENV_ID="${1:?ENV_ID is required}"
COMPOSE_FILE="docker-compose.e2e.yml"

FRONTEND_PORT=$(docker compose -p "$ENV_ID" -f "$COMPOSE_FILE" port frontend 3000 | awk -F: '{print $2}')

echo "Waiting for frontend on port $FRONTEND_PORT..."

for i in {1..60}; do
  if curl -fsS "http://localhost:$FRONTEND_PORT" >/dev/null 2>&1; then
    echo "Frontend is ready."
    exit 0
  fi

  echo "Waiting... attempt $i"
  sleep 2
done

echo "Frontend did not become ready in time."
exit 1
```

给脚本执行权限：

```bash
chmod +x scripts/wait-for-services.sh
```

---

## 8. Makefile 示例

```makefile
e2e-isolated:
    ./scripts/e2e-run-isolated.sh

e2e-env-up:
    docker compose -f docker-compose.e2e.yml up -d --build

e2e-env-down:
    docker compose -f docker-compose.e2e.yml down -v --remove-orphans

e2e:
    npx playwright test
```

AI agent 只需要执行：

```bash
make e2e-isolated
```

---

## 9. Playwright 配置

`playwright.config.ts` 示例：

```ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  use: {
    baseURL: process.env.E2E_BASE_URL || 'http://localhost:3000',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  reporter: [
    ['list'],
    ['html', { outputFolder: 'playwright-report' }],
  ],
});
```

测试代码中使用：

```ts
test('user can login', async ({ page }) => {
  await page.goto('/login');

  await page.fill('[data-testid="email"]', 'test@example.com');
  await page.fill('[data-testid="password"]', 'password');
  await page.click('[data-testid="login-button"]');

  await expect(page).toHaveURL('/dashboard');
});
```

---

## 10. AI Agent 使用规则

在 `CLAUDE.md` 中加入：

```md
## Isolated E2E Environment

For E2E testing, all agents must use the isolated temporary E2E environment.

Use:

`make e2e-isolated`

Rules:
- Do not run E2E tests against production.
- Do not reuse another agent's environment.
- Do not hardcode localhost ports.
- Use `E2E_BASE_URL` from the script.
- Always clean up the Docker Compose environment after testing.
- External third-party services must use sandbox or WireMock.
- Do not commit secrets, tokens, real customer data, or production credentials.
- If tests fail, inspect Playwright traces, screenshots, backend logs, and container logs before changing code.
```

---

## 11. 不同 Agent 的职责

### Implementation Agent

职责：

```text
修改代码
实现 feature
修复 bug
运行 targeted tests
必要时调用 e2e-isolated
```

### Test Agent

职责：

```text
创建或更新 Playwright E2E tests
启动 isolated E2E environment
验证用户流程
收集失败截图和 trace
```

### Security Agent

职责：

```text
检查登录、鉴权、CORS、CSRF、JWT、敏感日志
确认 E2E 不使用 production secrets
确认测试账号和测试数据安全
```

### Review Agent

职责：

```text
检查最终 diff
检查测试是否覆盖关键路径
确认环境被清理
总结风险和未覆盖场景
```

---

## 12. 适合 Mock 的部分

即使是比较真实的 E2E 环境，也不建议直接调用真实第三方服务。

可以 mock 或 sandbox：

```text
payment provider
email service
SMS service
CRA / government API
Jira / external SaaS
third-party identity provider
```

推荐方式：

```text
WireMock
MockServer
sandbox API
test tenant
```

但以下部分应尽量真实：

```text
frontend
Spring Boot backend
database engine
database migration
Spring Security config
JPA/Hibernate behavior
API gateway/reverse proxy pattern
```

---

## 13. Jenkins / CI 中的使用方式

在 Jenkins 中可以这样跑：

```groovy
stage('E2E Isolated') {
  steps {
    sh 'make e2e-isolated'
  }
}
```

如果需要保留失败报告：

```groovy
post {
  always {
    archiveArtifacts artifacts: 'playwright-report/**', allowEmptyArchive: true
    archiveArtifacts artifacts: 'test-results/**', allowEmptyArchive: true
  }
}
```

---

## 14. 更高级方案：Kubernetes Namespace Per Agent

如果公司已经使用 Kubernetes，可以为每个 agent 创建一个临时 namespace。

流程：

```bash
NAMESPACE="ai-agent-$BUILD_ID"

kubectl create namespace "$NAMESPACE"

helm upgrade --install app ./chart \
  --namespace "$NAMESPACE" \
  --set image.tag="$GIT_COMMIT"

E2E_BASE_URL="https://$NAMESPACE.preview.yourcompany.com" npx playwright test

kubectl delete namespace "$NAMESPACE"
```

优点：

```text
更接近真实云环境
适合 PR preview environment
适合多服务系统
适合公司级 CI/CD
```

缺点：

```text
搭建复杂
需要 DevOps 支持
成本更高
清理机制必须可靠
```

---

## 15. 推荐落地路线

### Phase 1：本地 Docker Compose

目标：

```text
让 Claude Code / AI agent 能一键启动临时 E2E 环境
```

实现：

```text
docker-compose.e2e.yml
scripts/e2e-run-isolated.sh
Makefile
Playwright config
CLAUDE.md instructions
```

### Phase 2：CI 集成

目标：

```text
每次 PR 或 main build 跑 isolated E2E
```

实现：

```text
Jenkins / GitHub Actions / GitLab CI
archive Playwright report
archive logs
quality gate
```

### Phase 3：Preview Environment

目标：

```text
每个 PR / agent 拥有接近 production 的临时环境
```

实现：

```text
Kubernetes namespace per PR
Helm deployment
temporary database
sandbox external services
automatic cleanup
```

---

## 16. 总结

AI agent 做 E2E 测试时，最好的方式不是共用一个固定测试环境，而是为每个 agent 或每次任务创建独立的临时环境。

推荐默认方案：

```text
Docker Compose
+ unique ENV_ID
+ dynamic ports
+ real frontend
+ real Spring Boot backend
+ real test database
+ WireMock/sandbox external services
+ Playwright
+ automatic cleanup
```

核心命令：

```bash
make e2e-isolated
```

这样可以实现：

```text
环境独立
测试稳定
可重复执行
不污染共享环境
不访问 production
适合 Claude Code / AI agent 自动测试
```
