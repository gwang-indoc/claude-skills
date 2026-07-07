# AgentMemory 安装与 Claude Code 基本使用指南

> 适用场景：你已经在 Claude Code 里安装好了 `agentmemory` plugin，想知道后续如何启动、验证、查看记忆，以及日常如何使用。

---

## 1. AgentMemory 是什么？

`agentmemory` 可以理解为一个给 AI coding agent 使用的长期记忆系统。

它和普通的 `CLAUDE.md` / `MEMORY.md` 不完全一样：

| 工具 | 作用 |
|---|---|
| `CLAUDE.md` | 存放稳定规则，例如项目技术栈、代码风格、运行命令 |
| `agentmemory` | 记录长期有用的经验，例如项目决策、bug 修复经验、历史任务、handoff 记录 |

简单理解：

```text
CLAUDE.md = 规则
agentmemory = 经验 / 历史 / 可检索记忆
```

---

## 2. 安装方式

如果还没有安装，可以使用：

```bash
npm install -g @agentmemory/agentmemory
```

或者临时运行：

```bash
npx @agentmemory/agentmemory
```

如果使用 Claude Code plugin，一般流程是：

```text
/plugin marketplace add rohitg00/agentmemory
/plugin install agentmemory
```

安装后，建议完全退出 Claude Code，然后重新打开。

---

## 3. 每次使用前如何启动？

在一个单独的 terminal 里启动 agentmemory server：

```bash
npx @agentmemory/agentmemory
```

如果已经全局安装，也可以用：

```bash
agentmemory
```

这个 terminal 建议保持运行，不要关掉。

然后再打开另一个 terminal，进入你的项目目录：

```bash
cd your-project
claude
```

---

## 4. 如何验证是否启动成功？

运行：

```bash
curl http://localhost:3111/agentmemory/health
```

如果有返回 health/status 类似的 JSON，说明 server 正常。

常用端口可以这样记：

```text
3111 = AgentMemory API / server
3113 = Web Viewer，看 memory 的页面
3114 = Console / 管理页面
```

---

## 5. 如何在网页里查看记忆？

启动 server 后，在浏览器打开：

```text
http://localhost:3113
```

这个页面通常可以看到：

```text
memories
sessions
recall results
session replay
tool calls / prompts / responses
```

如果打不开，先检查 server 是否还在运行：

```bash
curl http://localhost:3111/agentmemory/health
```

如果没有正常返回，就重新启动：

```bash
npx -y @agentmemory/agentmemory@latest
```

---

## 6. 在 Claude Code 里是否必须手动 `/recall`？

不一定。

安装 plugin 后，agentmemory 可能会通过 hooks 自动记录和注入相关记忆。

但是，重要任务前建议手动使用 `/recall`，这样更稳。

可以这样理解：

```text
自动 recall = 平时可能自动带入相关背景
/recall = 你主动指定要查哪一类记忆
```

所以：

```text
小任务：不一定需要 /recall
大任务：建议先 /recall
Claude 好像忘了：手动 /recall
想查具体内容：使用 /recall
```

---

## 7. 日常推荐工作流

### Step 1：启动 agentmemory server

```bash
npx @agentmemory/agentmemory
```

### Step 2：进入项目并打开 Claude Code

```bash
cd your-project
claude
```

### Step 3：开始任务前 recall

```text
/recall relevant context for this project, including architecture decisions, test commands, previous bugs, and user preferences
```

或者中文：

```text
/recall 这个项目的技术栈、启动命令、测试命令、重要架构决策、之前踩过的坑和用户偏好
```

### Step 4：做完重要任务后 remember

```text
/remember Summarize the durable lesson from this task: what changed, why, files involved, and what to check next time. Do not store secrets.
```

中文也可以：

```text
/remember 请保存这次任务中长期有用的信息：改了什么、为什么改、涉及哪些文件、以后遇到类似问题要注意什么。不要保存 API key、token、密码或 .env 内容。
```

### Step 5：结束 session 前 handoff

```text
/handoff Create a concise handoff for the next Claude Code session.
```

中文：

```text
/handoff 请总结当前任务进度、已经改了哪些文件、还剩什么没做、下一步应该从哪里继续。
```

下次回来后可以：

```text
/recall 上次 handoff 的内容，继续之前的任务。
```

---

## 8. 常用命令总结

| 命令 | 用途 |
|---|---|
| `/remember` | 手动保存长期有用的信息 |
| `/recall` | 查询之前保存的相关记忆 |
| `/handoff` | 生成下次继续工作的交接总结 |
| `/recap` | 总结当前 session |
| `/forget` | 删除错误、过期或不该保存的记忆 |
| `/session-history` | 查看之前 session 的历史记录 |
| `/commit-context` | 保存当前 commit 相关上下文 |
| `/commit-history` | 查看 commit 相关历史 |

---

## 9. 什么内容适合保存到 agentmemory？

适合保存：

```text
项目技术栈
启动命令
测试命令
重要目录结构
架构决策
bug 原因和修复方法
容易踩坑的地方
不要改的文件
deployment 注意事项
用户 coding 偏好
```

例子：

```text
/remember This project uses pnpm, not npm. Always run pnpm install and pnpm test.
```

```text
/remember Database migrations live in prisma/migrations. Do not manually edit generated Prisma client files.
```

```text
/remember Authentication middleware is in src/middleware/auth.ts. After editing auth code, run pnpm test:auth.
```

---

## 10. 什么内容不要保存？

不要保存：

```text
API key
.env 内容
密码
token
客户资料
隐私信息
临时 debug log
不确定的猜测
一次性聊天废话
```

推荐每次保存 memory 时加一句：

```text
Only save durable project knowledge. Do not save secrets, credentials, temporary logs, or guesses.
```

---

## 11. 推荐和 CLAUDE.md 搭配使用

### CLAUDE.md 适合放稳定规则

例如：

```text
Use pnpm.
Use TypeScript.
Run tests before final answer.
Do not change public API contracts without asking.
Follow the existing folder structure.
```

### AgentMemory 适合放长期经验

例如：

```text
上次为什么这样设计
哪个 bug 怎么修
哪个测试容易失败
某个模块的隐藏限制
上次任务做到哪里
```

推荐组合：

```text
CLAUDE.md = 项目规则
agentmemory = 项目经验和历史
```

---

## 12. 最推荐的固定使用模板

### 每次打开项目后

```text
/recall relevant context for this project
```

### 开始大任务前

```text
Recall previous decisions, bugs, testing commands, and constraints related to this task before editing.
```

### 任务完成后

```text
/remember Summarize the durable lesson from this task: what changed, why, files involved, and what to check next time. Do not store secrets.
```

### 退出 Claude Code 前

```text
/handoff Create a concise handoff for the next Claude Code session.
```

---

## 13. 最简版记忆

如果只想记住最核心流程：

```text
1. 先启动 server：
   npx @agentmemory/agentmemory

2. 打开 viewer：
   http://localhost:3113

3. 进入项目：
   cd your-project
   claude

4. 大任务前：
   /recall relevant context for this project

5. 重要信息：
   /remember ...

6. 结束前：
   /handoff ...
```

---

## 14. 排错 checklist

### 网页打不开

检查 server：

```bash
curl http://localhost:3111/agentmemory/health
```

如果不正常，重新启动：

```bash
npx -y @agentmemory/agentmemory@latest
```

### Claude Code 里好像没有 memory

尝试：

```text
/reload-plugins
```

或者完全退出 Claude Code，再重新打开。

### Claude 好像没想起来以前内容

手动查：

```text
/recall 你想查询的具体内容
```

例如：

```text
/recall 上次 authentication bug 是怎么修的
```

### 记忆内容错了或过期了

使用：

```text
/forget
```

或者手动告诉 Claude：

```text
之前关于 XXX 的 memory 已经过期，请不要再使用，并保存新的规则：YYY。
```

---

## 15. 建议使用习惯

最好的习惯是：

```text
开始前 recall
完成后 remember
结束前 handoff
定期 forget 过期内容
不要保存 secrets
```

这样 agentmemory 才会越来越有用，而不是变成一堆无效聊天记录。

---

# 16. Team 如何使用 AgentMemory？

如果是一个 team 在同一个项目上工作，不建议所有东西都混在一个 shared memory 里。最好的方式是分层：

```text
Repo 里的 CLAUDE.md
= 团队共同规则，所有人都应该遵守

AgentMemory shared/team memory
= 项目历史经验、架构决策、bug 修复经验、handoff

AgentMemory private/user memory
= 每个人自己的偏好、习惯、临时实验记录
```

核心原则：

```text
团队共享规则进 CLAUDE.md
团队长期经验进 shared AgentMemory
个人偏好和本地信息留在 private memory
敏感信息永远不要保存
```

---

## 16.1 团队共享规则：放到 CLAUDE.md

这些内容应该放进 repo 里的 `CLAUDE.md`，并且进入 Git，让所有人都能 review：

```text
Use pnpm, not npm.
Run pnpm test before submitting changes.
Do not edit generated Prisma files manually.
API contracts must not be changed without discussion.
Follow existing folder structure.
```

推荐文件位置：

```text
./CLAUDE.md
```

或者：

```text
./.claude/CLAUDE.md
```

这类内容是团队规则，不应该只存在某个人的本地 memory 里。

---

## 16.2 团队共享 AgentMemory：保存项目经验

Shared memory 适合保存这些：

```text
某个 bug 的原因和修复方式
为什么选了某个库
某个模块的隐藏约束
deployment 的特殊步骤
某个测试为什么容易失败
上次任务 handoff
```

例如，团队成员 A 修了一个 auth bug，可以保存：

```text
/remember Shared project memory: Auth token refresh bugs in this repo often come from missing cookie options in src/middleware/auth.ts. After editing auth code, run pnpm test:auth. Do not store secrets.
```

团队成员 B 下次做 auth 相关任务时，可以：

```text
/recall auth middleware token refresh previous bugs test command
```

---

## 16.3 个人私有记忆：不要共享

这些不应该进入 shared memory：

```text
我个人喜欢先写测试
我本地数据库 URL
我本地 sandbox 路径
我自己的 debugging habit
我临时开的 branch 计划
```

这些应该留在 private/user memory，或者本地的 `CLAUDE.local.md`。

如果使用 `CLAUDE.local.md`，建议加入 `.gitignore`：

```gitignore
CLAUDE.local.md
```

---

## 16.4 建议写进 CLAUDE.md 的 Team Memory Rules

可以把下面这段加到项目的 `CLAUDE.md` 里：

```md
## AgentMemory Team Rules

- Use agentmemory for durable project knowledge only.
- Shared memory should include architecture decisions, recurring bugs, test commands, deployment notes, and task handoffs.
- Do not save API keys, tokens, passwords, .env contents, customer data, or private personal preferences.
- Mark uncertain information as uncertain.
- If a memory becomes outdated, use /forget or save a superseding memory.
- Before major changes, recall relevant project memory.
- After fixing a non-trivial bug or completing a feature, save a concise durable memory.
```

---

## 16.5 Team member 的日常流程

开始工作前：

```text
/recall relevant shared project memory for this task, including architecture decisions, previous bugs, test commands, and constraints
```

做任务中，如果发现长期有用的信息：

```text
/remember Shared project memory: [长期有用的信息]. Do not store secrets.
```

结束前：

```text
/handoff Summarize what changed, files touched, tests run, remaining risks, and next steps for another teammate to continue.
```

接别人任务时：

```text
/recall latest handoff for this project and any memories related to [feature/bug/module]
```

---

## 16.6 共享 server 还是每个人本地 server？

### 模式 A：每个人本地 AgentMemory

适合小 team / 早期试用。

```text
每个人本机跑 agentmemory
共享规则靠 CLAUDE.md
重要经验通过 PR / docs / handoff 同步
```

优点：

```text
简单
安全
不容易互相污染 memory
```

缺点：

```text
memory 不能天然共享
```

### 模式 B：团队共享 AgentMemory server

适合固定团队、同一个 repo、多人持续开发。

这种模式通常需要设置：

```env
TEAM_ID=your-team-id
USER_ID=your-user-id
TEAM_MODE=private
AGENTMEMORY_SECRET=your-secret
```

注意：

```text
一定要区分 team/shared memory 和 private/user memory
一定要设置访问控制
一定要定期清理过期 memory
不要保存 secrets
```

---

## 16.7 Team 使用建议

如果只是普通开发小组，建议先用：

```text
CLAUDE.md 进 Git
+ 每个人本地 agentmemory
+ 重要经验通过 PR / docs / handoff 同步
```

等真的需要多人共享 AI 记忆，再上：

```text
shared agentmemory server
+ TEAM_ID / USER_ID
+ private/shared namespace
+ secret/auth
+ 定期审计和清理 memory
```

一句话总结：

```text
team shared memory 只保存"团队以后都需要知道的项目知识"，不要保存个人习惯、secret、临时猜测。
```

---

# 17. Dashboard 配置项：AUTO_COMPRESS 和 GRAPH_EXTRACTION

Dashboard 里可能会看到这些选项：

```text
Knowledge graph extraction
GRAPH_EXTRACTION_ENABLED

LLM-powered observation compression
AGENTMEMORY_AUTO_COMPRESS
```

这两个不是一开始必须配置，但理解它们很重要。

---

## 17.1 AGENTMEMORY_AUTO_COMPRESS 是什么？

```env
AGENTMEMORY_AUTO_COMPRESS=true
```

这个是 **LLM-powered observation compression**。

意思是：Claude Code 每次做事情，比如读文件、改代码、跑测试、报错，agentmemory 会产生一些 raw observation。打开这个开关后，它会用 LLM 把原始记录压缩成更有用的结构化记忆，例如：

```text
事实
概念
文件关系
bug 原因
任务总结
可复用经验
```

简单理解：

```text
不开 AUTO_COMPRESS：
agentmemory 记录较原始的信息

打开 AUTO_COMPRESS：
agentmemory 会用 LLM 总结、压缩、提炼重要信息
```

---

## 17.2 AUTO_COMPRESS 要不要打开？

建议：

```text
刚开始试用：可以先不开
认真长期用：建议打开
担心 API/token 成本：先不开，或者用本地模型
```

如果你想开启，可以在配置里写：

```env
AGENTMEMORY_AUTO_COMPRESS=true
```

如果你暂时不想开启：

```env
AGENTMEMORY_AUTO_COMPRESS=false
```

一句话：

```text
AUTO_COMPRESS = 提高 memory 质量，但可能增加 token/API 成本。
```

---

## 17.3 GRAPH_EXTRACTION_ENABLED 是什么？

```env
GRAPH_EXTRACTION_ENABLED=true
```

这个是 **Knowledge graph extraction**。

意思是：agentmemory 不只是保存一条条记忆，还会从 session 总结和 compressed observations 里抽取实体和关系，建立 knowledge graph。

例如它可能抽取：

```text
实体：
src/middleware/auth.ts
JWT authentication
auth bug
pnpm test:auth

关系：
src/middleware/auth.ts -> handles -> JWT authentication
auth bug -> caused by -> missing cookie options
pnpm test:auth -> validates -> authentication middleware
```

简单理解：

```text
普通 memory = 一条条笔记
knowledge graph = 把文件、模块、bug、命令、功能之间的关系连起来
```

---

## 17.4 GRAPH_EXTRACTION 有什么用？

主要让 recall 更聪明。

普通搜索可能只靠关键词或语义相似度；graph 可以帮助 agent 顺着关系找东西。

例如你问：

```text
/recall authentication related bugs and tests
```

有 graph 的情况下，它可能更容易把这些内容连起来：

```text
auth middleware
token refresh bug
cookie options
pnpm test:auth
相关文件
之前修复方式
```

---

## 17.5 GRAPH_EXTRACTION 要不要打开？

建议：

```text
小项目 / 刚开始试：不用急着开
长期项目 / 多 session：可以考虑打开
team 项目 / 大型代码库：比较有价值
```

开启：

```env
GRAPH_EXTRACTION_ENABLED=true
```

关闭：

```env
GRAPH_EXTRACTION_ENABLED=false
```

一句话：

```text
GRAPH_EXTRACTION = 建立项目关系图，适合长期、大型、team 项目。
```

---

## 17.6 配置应该写在哪里？

建议把 runtime config 放到：

```bash
~/.agentmemory/.env
```

创建文件：

```bash
mkdir -p ~/.agentmemory
nano ~/.agentmemory/.env
```

写入例如：

```env
AGENTMEMORY_AUTO_COMPRESS=false
GRAPH_EXTRACTION_ENABLED=false
```

或者长期项目可以用：

```env
AGENTMEMORY_AUTO_COMPRESS=true
GRAPH_EXTRACTION_ENABLED=true
```

保存后重启 agentmemory：

```bash
pkill -f agentmemory
npx -y @agentmemory/agentmemory@latest
```

如果你是全局安装的，也可以：

```bash
pkill -f agentmemory
agentmemory
```

---

## 17.7 推荐配置阶段

### 阶段 1：刚开始，最低成本

```env
AGENTMEMORY_AUTO_COMPRESS=false
GRAPH_EXTRACTION_ENABLED=false
```

适合先确认：

```text
Claude Code hooks 正常
/remember 可以保存
/recall 可以查到
http://localhost:3113 能看到 memories
```

---

### 阶段 2：认真长期使用

```env
AGENTMEMORY_AUTO_COMPRESS=true
GRAPH_EXTRACTION_ENABLED=false
```

适合你真的想让它长期记住项目经验。

---

### 阶段 3：长期项目 / team 项目 / 大型代码库

```env
AGENTMEMORY_AUTO_COMPRESS=true
GRAPH_EXTRACTION_ENABLED=true
```

适合多人开发或大型 repo。

---

## 17.8 最推荐的当前设置

如果你刚装好 plugin，我建议先用：

```env
AGENTMEMORY_AUTO_COMPRESS=false
GRAPH_EXTRACTION_ENABLED=false
```

先确认基础功能都正常。

等用几天后，再打开：

```env
AGENTMEMORY_AUTO_COMPRESS=true
```

如果开始长期做一个项目，或者 team 一起用，再打开：

```env
GRAPH_EXTRACTION_ENABLED=true
```

最简单总结：

```text
AUTO_COMPRESS = 提高记忆质量，但可能花 token
GRAPH_EXTRACTION = 建立项目关系图，适合长期/大型/team 项目
刚开始可以都不开
稳定后先开 AUTO_COMPRESS
项目复杂后再开 GRAPH_EXTRACTION
```

---

# 18. BM25 / Vector / Graph 是否需要额外配置？

AgentMemory 的检索通常可以理解成三层：

```text
BM25 = 关键词搜索
Vector = 语义搜索 / embedding 搜索
Graph = knowledge graph 关系检索
```

它们不是都需要额外配置。

---

## 18.1 BM25：一般默认开启

BM25 是关键词检索，通常不需要额外配置。只要 AgentMemory server 正常运行，BM25 搜索一般就能工作。

简单理解：

```text
BM25 = 根据关键词找 memory
例如：auth、middleware、pnpm、deployment
```

适合：

```text
明确关键词
文件名
命令名
模块名
错误信息
```

例如：

```text
/recall auth middleware token refresh
```

---

## 18.2 中文 Memory 建议安装分词器

如果你的 memory 里很多是中文，建议额外安装中文/日文分词相关依赖，否则 BM25 可能对中文检索效果较差。

可以安装：

```bash
npm install @node-rs/jieba tiny-segmenter
```

推荐理解：

```text
英文 memory：BM25 默认通常够用
中文 memory 多：建议安装 jieba
```

---

## 18.3 Vector Search：需要 embedding provider

Vector search 是语义搜索。它不是只看关键词，而是看意思是否接近。

例如你查：

```text
/recall login issue
```

它也可能找到：

```text
authentication bug
token refresh problem
session cookie issue
```

这就需要 embedding provider。

如果不配置 embedding，AgentMemory 仍然可以靠 BM25 工作，但语义搜索能力会弱一些。

---

## 18.4 推荐本地 embedding 配置

如果你不想用 OpenAI / Voyage / Gemini 这类 API，可以使用本地 embedding。

先安装：

```bash
npm install @xenova/transformers
```

然后在配置文件里写：

```env
EMBEDDING_PROVIDER=local
```

配置文件建议放在：

```bash
~/.agentmemory/.env
```

如果文件不存在，可以创建：

```bash
mkdir -p ~/.agentmemory
nano ~/.agentmemory/.env
```

然后写入：

```env
EMBEDDING_PROVIDER=local
```

本地 embedding 的优点：

```text
免费
离线
不需要 API key
适合个人项目先用
```

缺点：

```text
效果可能不如高质量商业 embedding
第一次运行可能需要下载模型
```

---

## 18.5 如果使用 OpenAI 等 embedding

也可以使用 API provider，例如 OpenAI embedding。

示例：

```env
OPENAI_API_KEY=sk-...
OPENAI_EMBEDDING_MODEL=text-embedding-3-small
```

注意：

```text
这可能产生 API 成本
不要把 API key 提交到 Git
不要把 .env 内容保存到 shared memory
```

---

## 18.6 Graph Search：需要打开 GRAPH_EXTRACTION_ENABLED

Graph search 依赖 knowledge graph。它不是普通关键词搜索，而是通过实体和关系找信息。

需要开启：

```env
GRAPH_EXTRACTION_ENABLED=true
```

Graph 可以理解成：

```text
普通 memory = 一条条笔记
knowledge graph = 把文件、模块、bug、命令、功能之间的关系连起来
```

例如：

```text
src/middleware/auth.ts -> handles -> authentication
auth bug -> caused by -> missing cookie options
pnpm test:auth -> validates -> authentication middleware
```

这样以后你问 auth 相关问题，AgentMemory 可能更容易找到相关文件、bug、测试命令和历史结论。

---

## 18.7 Graph 最好配合 AUTO_COMPRESS

只打开：

```env
GRAPH_EXTRACTION_ENABLED=true
```

不一定效果最好。

更推荐长期项目里这样搭配：

```env
AGENTMEMORY_AUTO_COMPRESS=true
GRAPH_EXTRACTION_ENABLED=true
```

原因是：

```text
AUTO_COMPRESS 先把原始 observation 压缩成结构化 memory
GRAPH_EXTRACTION 再从结构化 memory 里抽取实体和关系
```

所以：

```text
没有 AUTO_COMPRESS：graph 信息可能不够好
有 AUTO_COMPRESS：graph 更容易抽出有价值的关系
```

---

## 18.8 推荐配置阶段

### 阶段 1：刚开始，最低成本

适合刚安装好、先确认基础功能：

```env
AGENTMEMORY_AUTO_COMPRESS=false
GRAPH_EXTRACTION_ENABLED=false
```

这时主要靠：

```text
BM25 keyword search
手动 /remember
手动 /recall
```

---

### 阶段 2：加本地 vector search

推荐你先试这个，因为成本低、效果提升明显：

```bash
npm install @xenova/transformers
```

```env
EMBEDDING_PROVIDER=local
AGENTMEMORY_AUTO_COMPRESS=false
GRAPH_EXTRACTION_ENABLED=false
```

适合：

```text
个人长期项目
想提升 recall 质量
不想增加 API 成本
```

---

### 阶段 3：中文 memory 较多

再加中文分词：

```bash
npm install @node-rs/jieba tiny-segmenter
```

推荐配置：

```env
EMBEDDING_PROVIDER=local
AGENTMEMORY_AUTO_COMPRESS=false
GRAPH_EXTRACTION_ENABLED=false
```

---

### 阶段 4：长期项目 / team 项目 / 大型代码库

可以开启压缩和 graph：

```env
EMBEDDING_PROVIDER=local
AGENTMEMORY_AUTO_COMPRESS=true
GRAPH_EXTRACTION_ENABLED=true
```

适合：

```text
长期项目
多人 team 项目
大型 repo
跨很多 session 的复杂任务
```

注意：

```text
AGENTMEMORY_AUTO_COMPRESS=true 可能增加 token / API 成本
GRAPH_EXTRACTION=true 适合项目复杂后再开
```

---

## 18.9 如果你用 Claude Code subscription 做压缩

如果没有单独 API key，又想尝试让 AgentMemory 用 Claude Code / agent SDK 做压缩，可以考虑：

```env
AGENTMEMORY_ALLOW_AGENT_SDK=true
AGENTMEMORY_AUTO_COMPRESS=true
```

但注意：

```text
这可能消耗 Claude Code / subscription 相关额度
活跃 session 可能产生明显额外成本
建议先小规模测试
```

---

## 18.10 最推荐你现在的配置

如果你现在刚装好 plugin，我建议：

```bash
npm install @xenova/transformers
npm install @node-rs/jieba tiny-segmenter
```

然后在：

```bash
~/.agentmemory/.env
```

写入：

```env
EMBEDDING_PROVIDER=local
AGENTMEMORY_AUTO_COMPRESS=false
GRAPH_EXTRACTION_ENABLED=false
```

等你确认 `/remember`、`/recall`、dashboard、Replay 都正常后，再考虑：

```env
AGENTMEMORY_AUTO_COMPRESS=true
```

如果之后开始长期维护一个复杂项目或 team 项目，再打开：

```env
GRAPH_EXTRACTION_ENABLED=true
```

---

## 18.11 一句话总结

```text
BM25：默认开启，不需要额外配置；中文建议装 jieba
Vector：需要 embedding provider；推荐先用 local embedding
Graph：需要 GRAPH_EXTRACTION_ENABLED=true，最好配合 AUTO_COMPRESS
```

最稳路线：

```text
先用 BM25
再加 local embedding
中文多就装 jieba
长期项目再开 AUTO_COMPRESS
大型/team 项目再开 GRAPH_EXTRACTION
```
