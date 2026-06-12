---
name: zhihu-publishing
description: 当用户想写文章并发布到知乎（zhihu.com）时使用——给出零散思路、草稿或笔记，润色、生成题图和解释图，一行命令发知乎草稿。触发词："写一篇文章"、"发知乎"、"知乎"、"润色"、"题图"、"/zhihu-publishing"。
---

# zhihu-publishing

帮用户写文章并发布到知乎。**轻润色，不重写。** 自动生成题图和解释图，本地图片自动上传知乎自有图床（zhimg.com CDN），一行命令推知乎草稿。

## ⚠️ 风格唯一权威：STYLE.md（写作 / 润色前必读）

**写或润色每一篇文章前，先读同目录的 [`STYLE.md`](./STYLE.md)，并严格遵循。** 那是作者本人维护的风格定义文件——语气 DNA、长度、加粗、排版、红线清单全在那里。本 SKILL.md 只管**机制与工作流**（脚本、配图、HTML 转换、发布）。

风格上 STYLE.md 与本文件冲突时，**以 STYLE.md 为准**。要调风格 = 改 STYLE.md，不在这里改、更不在草稿里改。

下面只保留机制相关的写作约束：

- **字数**（STYLE.md 定预算，这里给计数命令）：

```bash
python3 -c "import re; t=open('article.md').read(); t=re.sub(r'\!\[.*?\]\(.*?\)','',t); print(len(re.findall(r'[一-鿿]',t)) + len(re.findall(r'[A-Za-z]+',t)))"
```

- **代码独立成段**：用标准 fenced block，必须带语言标签（知乎原生支持，不需要任何 raw HTML 补丁）：
  ````
  ```bash
  npm install -g xxx
  ```
  ````
- **引用**：直接用 `> text`（知乎支持，不需要 raw HTML blockquote）。
- **强调**：`**bold**`。知乎不渲染 `<span style="color:...">` 彩色，禁用。

## 介绍 skill 的文章：末尾必须附安装方法

**触发条件**：这篇在介绍 / 推荐某个具体的 Claude Code skill。

**前置 — 确认 skill 已发布**：确认 skill 已在公开 git repo 里，用 `gh api repos/<owner>/<repo>/contents/<skill-name>` 确认。

**末尾附下面这段**（`<SKILL_NAME>` 替换成实际名）：

```markdown
## 安装方法

不用复制命令。打开你用的 AI agent——Claude Code、Codex、Kimi Code、OpenClaw 都可以，对它说一句：

> 安装 https://github.com/jianshuo/claude-skills/blob/main/<SKILL_NAME>/SKILL.md

它会自己 fetch、放到 skill 目录里、提示你重启对话。

用 Hermes 的话直接命令行：

\`\`\`bash
hermes skills install https://github.com/jianshuo/claude-skills/blob/main/<SKILL_NAME>/SKILL.md
\`\`\`

装完之后，对 agent 说一句「<一句最自然的触发语，紧扣这个 skill 的入口>」，就能用。
```

规则：
1. 这段**不计入**正文字数预算
2. URL 用 `github.com/<owner>/<repo>/blob/main/<path>`——浏览器能直接看，LLM agent 也能从 blob URL 抽 markdown
3. Hermes 单独列**命令行**，因为它是 registry CLI 而非 chat agent
4. 最后那句触发语按当前 skill 实际入口写，**不要漏**
5. 通常放最后；有 `## 后注` 则放后注之前

## 工作流

### Step 0: 接收输入

输入形式：完整草稿 / 散乱思路 / 长段没分段 / 语音转写（可能有错字）。太散就**问一个问题**："想写一篇文章，还是几个独立想法？"——只问这一次。

### Step 1: 轻润色

- 修错字（"的得地"、同音字、"我我"重复字）
- 每 1–3 句一段
- 拗口处做最小改动；改完语气变了宁可不改
- 标点：中文全角，英文 / 数字间空格
- 保留原本开头和结尾

### Step 2: 标题候选

给 **3 个候选**：A) 直白型；B) 故事型；C) 原文里最有味道的一句。不做标题党、夸张、"震惊"、"必看"。

### Step 3: 摘要（50–80 字）

不是第一段的复制；一句话说清读者会获得什么；用作者语气，不是营销腔。

### Step 4: 配图（每篇两张，自动生成不问用户）

- **题图 cover.png** — **严格 2.35:1**（900×383），强字体、强构图、文字主导
- **解释图 illustration.png** — **比例由内容决定**（模型自选），扁平卡通、有标签和流程

```bash
~/.claude/skills/zhihu-publishing/scripts/gen-cover-ai.sh <article-folder> ["目标字词"]
~/.claude/skills/zhihu-publishing/scripts/gen-illustration.sh <article-folder>
```

- 不传第二参数时从 `meta.json` 取 `title`；建议挑核心概念字词（1–4 字）
- 内部走 `gpt-image-2-skill` 的 `--provider codex`，需要 `~/.codex/auth.json`
- 题图自动裁到 900×383；解释图不裁

**解释图必须在 markdown 里被引用**——`article.md` 要有 `![](./illustration.png)` 一行，否则草稿里看不到。

**图片上 CDN（全自动）**：正文里任何 `![](./xxx.png)` 形式的本地图片，发布脚本都会自动走知乎图床流程（`api.zhihu.com/images` 申请 token → 上传到阿里云 OSS `zhihu-pics` 桶 → 替换成 `picx.zhimg.com` URL）。题图 `cover.png` 同样自动上传并设为 `titleImage` 封面。**关键：必须用知乎自有 CDN——imgur 等外链会被知乎保存时静默删除，图就没了。**

**插入位置：紧跟与图最相关的那段内容之后**——解释图讲的是哪个概念 / 流程，就插在那段论述刚讲完的地方，让图就近佐证文字。**不要默认堆到文末。** 只有当全文围绕单一主线、没有明显的「最相关段」时，才落在正文最后落点之后（有 `## 安装方法` 放安装方法前）。

**绝不给解释图写引导语**——不写「整件事画起来是这样」「如图所示」之类，图自己说话。

### Step 5: 输出文件包

在**当前项目根目录**下的 `zhihu_article/` 文件夹创建：

```
zhihu_article/2026-05-09-{slug}/
├── article.md           # 润色后的 markdown
├── cover.png            # 题图 900×383
├── illustration.png     # 解释图
├── meta.json            # { title, summary, author, date, slug, tags }
└── original.md          # 用户原始输入
```

`{slug}`：拼音首字母 + 关键词，30 字符内。

### Step 6a: 发布到知乎（可选，用户明确要求才执行）

**默认跳过。** 用户说"发知乎"才执行。

**⚠️ 两段式发布，中间必须有人工确认门——绝不一步到位 `--publish`。** 即使用户说"发布"，第一次也只建 / 更新草稿，让他先在知乎看过、可再改，明确确认后才真正发布。

**Claude 执行步骤**：
1. 确认 `~/.config/zhihu/config.json` 存在且 `z_c0` 不是占位符；否则提示用户配置
2. 用 Bash 工具直接运行脚本（**不带 `--publish`**），**不要只打印命令让用户自己跑**：

```bash
SCRIPT=~/.claude/skills/zhihu-publishing/scripts/upload-zhihu.sh
"$SCRIPT" <article-folder>          # 只建 / 更新草稿
```

3. 把草稿 URL 给用户，请他在知乎里**审一遍**（题图、配图、排版、话题），告诉他："看过没问题就说一声，我再发布；要改就改 `article.md` / 配图，我重跑更新草稿。"
4. **用户改了** → 重跑第 2 步命令（`publish.json` 已记 `draft_id`，原地更新同一篇，不建重复），再请他复审。如此往复直到他满意。
5. **用户明确确认发布**后，才加 `--publish`：

```bash
"$SCRIPT" <article-folder> --publish  # 复用同一草稿 → 发布
```

**机制**：脚本把 `article.md` 转成 HTML（知乎正文是 HTML，不是 markdown），再走：
1. 本地图片（正文 `./xxx.png` + 题图 `cover.png`）逐张上传知乎图床，换成 `picx.zhimg.com` URL
2. `POST /api/articles/drafts` 建草稿拿 `id`
3. `PATCH /api/articles/{id}/draft` 写入标题 + HTML 正文 + 封面（`titleImage` + `title_image_size`）
4. `--publish` 时 `PUT /api/articles/{id}/publish` 发布

> 注意：知乎写接口（PATCH/PUT）成功时返回 **HTTP 200 空 body**，只有建草稿的 POST 回 JSON——脚本把"2xx + 空 body"当成功，不要误判为错误。封面写入键是**驼峰 `titleImage`**（下划线 `title_image` 是只读输出字段，写了不生效）。

`publish.json` 记录 `draft_id`，重跑同一篇会复用草稿（原地更新，不会建重复）。

**前置 — 一次性配置**（只做一次）：

```bash
mkdir -p ~/.config/zhihu
echo '{"z_c0":"YOUR_Z_C0_TOKEN"}' > ~/.config/zhihu/config.json
```

拿 `z_c0`：登录 zhihu.com → DevTools (`F12`) → Application → Cookies → `https://www.zhihu.com` → 复制 `z_c0` 值。

**⚠️ 写接口常需要 `_xsrf`**——只配 `z_c0` 可能在 PATCH/PUT 时报 401。最稳的做法：复制**整条 Cookie 请求头**（DevTools → Network → 任一请求 → Request Headers → `cookie:` 整行），用 `cookie` 字段：

```bash
echo '{"cookie":"_xsrf=...; z_c0=...; d_c0=..."}' > ~/.config/zhihu/config.json
```

脚本自动从中抽出 `_xsrf` 填 `x-xsrftoken` 头。

**图片**：正文里的本地图片（`./illustration.png` 等）和题图 `cover.png` 自动走知乎自有图床（`api.zhihu.com/images` → 阿里云 OSS → `picx.zhimg.com`），封面写入 `titleImage` 字段。无需手动处理。**不要用 imgur 等外链——知乎保存时会静默删掉非 zhimg.com 的图。**

**注意**：`z_c0` / cookie 会过期，失效（401 / code 100）时重新从浏览器 DevTools 复制更新。

## 润色启发 / 分段 / 红线 / 改动清单

**全部移到 [`STYLE.md`](./STYLE.md)**——错字模式、分段规则、红线清单、交付前先给改动清单，都在那里。润色前读 STYLE.md，按它执行。

依赖外部 skill：`gpt-image-2-skill`（cover/illustration 生成，需要 `~/.codex/auth.json`）。

## 完成标准

- [ ] `zhihu_article/YYYY-MM-DD-{slug}/` 文件夹存在
- [ ] 含 article.md、cover.png、illustration.png、meta.json、original.md
- [ ] meta.json 字段齐全（含 tags）
- [ ] 用户没说"再改改"

发布到知乎额外需要：
- [ ] 草稿在 zhuanlan.zhihu.com 可见（仅用户明确要求发布时检查）
