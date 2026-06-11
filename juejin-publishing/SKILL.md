---
name: juejin-publishing
description: 当用户想写文章并发布到掘金（juejin.cn）时使用——给出零散思路、草稿或笔记，润色、生成题图和解释图，一行命令发掘金草稿。触发词："写一篇文章"、"发掘金"、"掘金"、"润色"、"题图"、"/juejin-publishing"。
---

# juejin-publishing

帮用户写文章并发布到掘金。**轻润色，不重写。** 自动生成题图和解释图，本地图片自动上传 imgur CDN，一行命令推掘金草稿。

## ⚠️ 风格唯一权威：STYLE.md（写作 / 润色前必读）

**写或润色每一篇文章前，先读同目录的 [`STYLE.md`](./STYLE.md)，并严格遵循。** 那是王建硕本人维护的风格定义文件——语气 DNA、长度、加粗、排版、红线清单全在那里。本 SKILL.md 只管**机制与工作流**（脚本、配图、HTML 转换、发布）。

风格上 STYLE.md 与本文件冲突时，**以 STYLE.md 为准**。要调风格 = 改 STYLE.md，不在这里改、更不在草稿里改。

下面只保留机制相关的写作约束：

- **字数**（STYLE.md 定预算，这里给计数命令）：

```bash
python3 -c "import re; t=open('article.md').read(); t=re.sub(r'\!\[.*?\]\(.*?\)','',t); print(len(re.findall(r'[一-鿿]',t)) + len(re.findall(r'[A-Za-z]+',t)))"
```

- **加粗加红的机制**：`upload-draft.sh` 把 `**...**` 渲染成红色粗体（用法见 STYLE.md「加粗加红」）。
- **盘古之白的机制**：`upload-draft.sh` 自动跑 `scripts/pangu.py`，Claude 不用手动加空格。
- **命令 / 代码独立成段的写法**（规则见 STYLE.md，这里给可复制的样式）：
  - **首选**——淡底色代码块（raw HTML 块，整段一行，内部不能有空行）：
    ```
    <section style="background:#f6f8fa;border-radius:6px;padding:14px 16px;overflow-x:auto;font-family:Menlo,Consolas,monospace;font-size:14px;line-height:1.8;color:#24292e;">npm install -g xxx<br>xxx run</section>
    ```
  - 或 fenced ```` ```bash ```` 块，脚本转成独立 `<p><code>…</code></p>`。

## 介绍 skill 的文章：末尾必须附安装方法

**触发条件**：这篇在介绍 / 推荐某个具体的 Claude Code skill。

**前置 — 确认 skill 已发布**：王建硕自己的 `wjs-*` skill 由 `~/.claude/skills-publish-hook.sh` 自动 push 到 [github.com/jianshuo/claude-skills](https://github.com/jianshuo/claude-skills)，用 `gh api repos/jianshuo/claude-skills/contents/<skill-name>` 确认。别人的 skill 先确认在公开 git repo 里。

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
1. 这段**不计入** 800–1000 字预算
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
~/.claude/skills/juejin-publishing/scripts/gen-cover-ai.sh <article-folder> ["目标字词"]
~/.claude/skills/juejin-publishing/scripts/gen-illustration.sh <article-folder>
```

- 不传第二参数时从 `meta.json` 取 `title`；建议挑核心概念字词（1–4 字）
- 内部走 `gpt-image-2-skill` 的 `--provider codex`，需要 `~/.codex/auth.json`
- 题图自动裁到 900×383；解释图不裁

**解释图必须在 markdown 里被引用**——`article.md` 要有 `![](./illustration.png)` 一行，否则草稿里看不到。

**⚠️ 正文里除 `cover.png` / `illustration.png` 外的图不会自动上 CDN。** 用户给的本地截图（如 `img-xxx.png`）每张先 `md2wechat upload_image img-xxx.png --json` 拿 `data.wechat_url`，再替换 `article.md` 里的本地路径。验证：`grep -c mmbiz content.html` = 正文图片数，`grep -c 'img-' content.html` = 0。

默认插入位置：**正文最后落点之后**（有 `## 后注` 放后注前；有 `## 安装方法` 放安装方法前）。

**绝不给解释图写引导语**——不写「整件事画起来是这样」「如图所示」之类，图自己说话。详见 [[no-illustration-caption]]。

> 安全网：`illustration.png` 存在但 `article.md` 没引用时，`upload-draft.sh` 自动插入并改写，幂等。

### Step 5: 输出文件包

在工作目录（默认 `~/wechat-publish/articles/`）创建：

```
articles/2026-05-09-{slug}/
├── article.md           # 润色后的 markdown
├── cover.png            # 题图 900×383
├── illustration.png     # 解释图
├── meta.json            # { title, summary, author, date, slug }
└── original.md          # 用户原始输入
```

`{slug}`：拼音首字母 + 关键词，30 字符内。

### Step 6a: 发布到掘金（可选，用户明确要求才执行）

**默认跳过。** 用户说"发掘金"才执行。

**Claude 执行步骤**：
1. 确认 `~/.config/juejin/config.json` 存在且 `session_id` 不是占位符；否则提示用户配置
2. 用 Bash 工具直接运行脚本，**不要只打印命令让用户自己跑**：

```bash
SCRIPT=/Users/gwang/github_repo/claude-skills/.claude/skills/juejin-publishing/scripts/upload-juejin.sh
"$SCRIPT" <article-folder>          # 建草稿
"$SCRIPT" <article-folder> --publish  # 建草稿 + 立即发布
```

3. 把脚本输出的草稿 URL 告诉用户，问是否需要加 `--publish`

**前置 — 一次性配置**（只做一次，配过就不用再配）：

```bash
mkdir -p ~/.config/juejin
echo '{"session_id":"YOUR_SESSIONID","category_id":"6809637771511070726"}' > ~/.config/juejin/config.json
```

拿 `session_id`：登录 juejin.cn → DevTools (`F12`) → Application → Cookies → `https://juejin.cn` → 复制 `sessionid` 值。

常用 `category_id`：前端 `6809637767543259144`｜后端 `6809637769959178254`｜AI `6809637771511070726`｜工具 `6809637777629245448`

**图片**：正文里的本地图片（`./illustration.png` 等）自动上传到 imgur CDN，路径替换成公开 URL 后写入草稿。无需手动处理。

**注意**：`sessionid` 会过期，失效时重新从浏览器 DevTools 复制更新 `~/.config/juejin/config.json`。

### Step 6b: 发布到微信（可选，用户明确要求才执行）

**默认跳过此步。** 用户说"发布"、"推到公众号"才执行。

```bash
~/.claude/skills/juejin-publishing/scripts/upload-draft.sh <workspace>/articles/YYYY-MM-DD-{slug}
```

脚本做的事：

1. 跑 `pangu.py` 加盘古之白
2. `md2wechat upload_image cover.png` → 拿 `thumb_media_id`
3. `illustration.png` 存在但没引用时自动插入并 upload 拿 CDN URL（幂等安全网）
4. 从 `article.md` 生成 `content.html`（转换规则见下）
5. 装 `draft.json`，调 `create_draft` 或（`publish.json` 有 `draft_media_id` 时）`draft/update` 原地更新
6. 自动打开草稿：macOS 走 `scripts/open-draft-edit.sh`——读已登录浏览器的 session token、按标题查出 `appmsgid`、**直达这一篇的编辑页**（没登录则回退开首页）；Linux 开 `mp.weixin.qq.com` 首页。`WECHAT_PUBLISH_NO_OPEN=1` 关掉
7. 自动 `git add / commit / push` 文章目录到 origin

**前置依赖（仅发布时需要）**：
- `md2wechat` CLI（`github.com/jianshuo/md2wechat`）装好且 `WECHAT_APPID` + `WECHAT_SECRET` 配好
- **当前公网 IP 在公众号后台白名单**：mp.weixin.qq.com → 设置与开发 → 基本配置 → IP 白名单。漏掉会 `errcode=40164`

**常见 errcode**：`40164` IP 不在白名单 ｜ `45004` `summary` 为空 / 太短 ｜ `40007` 老 `draft_media_id` 被删（脚本自动 fallback 建新）。

成功后到草稿箱 → 手机预览 → 发布。

## 润色启发 / 分段 / 红线 / 改动清单

**全部移到 [`STYLE.md`](./STYLE.md)**——错字模式、分段规则、红线清单、交付前先给改动清单，都在那里。润色前读 STYLE.md，按它执行。

依赖外部 skill：`gpt-image-2-skill`（cover/illustration 生成，需要 `~/.codex/auth.json`）。`md2wechat` 仅发布时需要。

## 完成标准

- [ ] `articles/YYYY-MM-DD-{slug}/` 文件夹存在
- [ ] 含 article.md、cover.png、illustration.png、meta.json、original.md
- [ ] meta.json 字段齐全
- [ ] 用户没说"再改改"

发布到微信额外需要：
- [ ] 草稿在 mp.weixin.qq.com 后台可见（仅用户明确要求发布时检查）
