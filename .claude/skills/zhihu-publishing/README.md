# zhihu-publishing

写并发布**知乎**文章的 Claude Code skill。AI 生成题图和解释图，一行命令把草稿推到知乎后台。

三条原则：

1. **轻润色，不重写。** 保留作者的语气，只修错字、切段，不"提升"文笔。
2. **每篇两张图。** 2.35:1 的题图（封面用）+ 比例自由的卡通解释图（正文用）。
3. **一行命令发草稿。** `upload-zhihu.sh` 直接调知乎 API：上传图片、建草稿，自动打开编辑页。预览后点发布。

## 怎么用

直接跟 Claude Code 说「写一篇知乎文章，思路是…」或 `/zhihu-publishing`，把草稿粘进来。skill 会问 1–2 个问题，然后产出文章目录：

```
articles/2026-05-09-my-slug/
├── original.md          # 你的原始输入（备份）
├── article.md           # 轻润色后的 markdown
├── cover.png            # 题图 900×383（严格 2.35:1）
├── illustration.png     # 解释图（比例由模型按内容定）
├── meta.json            # title / summary / author / slug
└── publish.json         # 发布后写入 draft_id / article_id
```

三个脚本分别管配图和发布：

```bash
DIR=articles/YYYY-MM-DD-slug

# 题图（2.35:1，自动裁到 900×383）
~/.claude/skills/zhihu-publishing/scripts/gen-cover-ai.sh "$DIR" "目标字词"

# 解释图（比例自由，不裁）
~/.claude/skills/zhihu-publishing/scripts/gen-illustration.sh "$DIR"

# 发布：建草稿到知乎
~/.claude/skills/zhihu-publishing/scripts/upload-zhihu.sh "$DIR"
```

图片脚本是幂等的——再跑一次得到不同结果（生成有随机性）。

## 安装

```bash
git clone https://github.com/jianshuo/claude-skills
cp -r claude-skills/.claude/skills/zhihu-publishing ~/.claude/skills/
```

之后在 Claude Code 里说「写一篇知乎文章」「润色」「发知乎」或 `/zhihu-publishing` 就会触发。

## 依赖

- **macOS / Linux**（`open` / `xdg-open` 打开浏览器）
- **Python 3**
- **[gpt-image-2-skill](https://github.com/Wangnov/gpt-image-2-skill)** — AI 配图用：

  ```bash
  git clone https://github.com/Wangnov/gpt-image-2-skill /tmp/g
  cp -r /tmp/g/skills/gpt-image-2-skill ~/.claude/skills/
  ```

  鉴权：`OPENAI_API_KEY`（`gpt-image-2` 需 OpenAI 组织认证）**或** Codex `~/.codex/auth.json`（任意 ChatGPT Plus 账号即可，免认证，推荐）。

## 配置知乎 Auth

```bash
mkdir -p ~/.config/zhihu
echo '{"z_c0":"YOUR_Z_C0_TOKEN"}' > ~/.config/zhihu/config.json
```

拿 `z_c0`：登录 zhihu.com → DevTools (`F12`) → Application → Cookies → `https://www.zhihu.com` → 复制 `z_c0` 值。

**写接口（PATCH / 发布）常需要 `_xsrf`**，只配 `z_c0` 可能报 401。最稳：复制整条 Cookie 请求头（DevTools → Network → 任一请求 → Request Headers → `cookie:` 整行），用 `cookie` 字段，脚本自动抽 `_xsrf`：

```bash
echo '{"cookie":"_xsrf=...; z_c0=...; d_c0=..."}' > ~/.config/zhihu/config.json
```

`upload-zhihu.sh` 把 `article.md` 转成 HTML（知乎正文是 HTML），建草稿 → 写正文 → `--publish` 时发布。`publish.json` 记录 draft id，重跑复用同一草稿。

## 自定义

两个图片生成器读可编辑的 prompt 模板：

- **`prompts/cover-prompt.md`** — 题图设计哲学，含 `[目标字词]` 占位符，锁定 2.35:1
- **`prompts/illustration-prompt.md`** — 解释图风格指南，含 `[文章内容]` 占位符，比例由模型按内容选

`upload-zhihu.sh` 的环境变量：
- `ZHIHU_NO_OPEN=1` — 不自动打开浏览器

## 文件结构

```
.
├── SKILL.md                    # skill 的行为（它的 prompt）
├── prompts/
│   ├── cover-prompt.md         # 题图 prompt 模板
│   └── illustration-prompt.md  # 解释图 prompt 模板
└── scripts/
    ├── gen-cover-ai.sh         # gpt-image-2 题图 → 900×383
    ├── gen-illustration.sh     # 解释图，不裁
    ├── upload-zhihu.sh         # 调知乎 API 建/更新草稿
    ├── pangu.py                # 盘古之白（中英间加空格）
    ├── update-draft-via-api.py # 草稿原地更新
    └── …                       # 留言抓取 / 群发等辅助脚本
```

## 为什么两张图？

**题图**是读者在知乎信息流里点开*之前*看到的封面，要在 2.35:1（900×383）里一击命中，靠的是字体和构图。

**解释图**在文章里，要帮读者在读文字前先抓住概念。把它硬塞进封面比例会毁掉它。不同的活，不同的比例。

## 它明确不做的事

- 不替你重写文笔。想让 LLM 代笔，这工具不对路。
- 不管理知乎账号、粉丝分析、定时发送。

## License

MIT — 见 [LICENSE](LICENSE)。

## 作者

Gary Wang
