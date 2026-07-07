风格是可以蒸馏的。

让 AI 帮你写文章，最常见的结果是：内容对，但口气不对。你写的是口语化的、有点偏激的、爱直接下断言的东西，AI 给你返回一篇四平八稳、"首先其次综上所述"的东西。

用它，读者一眼看出来不是你写的。不用它，白润色了一遍。

问题不是 AI 不懂风格，是你没有给他一个可以参考的、持久的风格定义。

每次开新对话，他都是从零开始的。你说"帮我润色"，他就按他理解的"好文章"来——四平八稳、结构清晰、连接词齐全。这不是他的错，是你没告诉他你要的是什么。

所以我做了个叫 style-distiller 的 skill。

## 它只做一件事

把一批你自己写的文章样本丢进 `./samples/` 文件夹，对 Claude Code 说一句「Use the style-distiller skill」，它输出一个 `./style.md`。

不重写文章。不生成新内容。只分析，只蒸馏。

`style.md` 是一份可复用的风格画像——之后你让 AI 帮你写或润色任何文章，先把这个文件给他，他就知道该怎么下笔了。

## 蒸馏的是什么

skill 从十个维度分析样本里的写作习惯：

| 维度 | 分析什么 |
|---|---|
| 句子长度 | 以短句为主、长句为主，还是混搭？爱不爱用断句？ |
| 节奏 | 流畅、跳脱、压缩、舒展？ |
| 词汇 | 口语、学术、文学、冷静、技术？ |
| 语气 | 克制、讽刺、幽默、严肃、亲近？ |
| 意象 | 靠具体细节还是靠抽象判断？ |
| 段落结构 | 短打、慢展开、对话重、反思重？ |
| 叙事距离 | 贴近内心还是旁观？ |
| 修辞手法 | 排比、对比、反问、留白？ |
| 信息密度 | 密实、留白、铺开解释还是压缩暗示？ |
| 情绪表达 | 直说还是靠行动 / 场景 / 细节暗示？ |

分析完，输出的 `style.md` 分两个部分：一段综述，说清楚这个人写东西的整体感觉；然后是 **Do** 和 **Don't** 两个清单，直接告诉之后写作时该做什么、不该做什么。

是指令，不是描述。

比如，如果样本文章里作者的句子普遍很短、爱用反问、很少铺垫就下判断——蒸馏出来的 **Do** 可能会写：「用短句，每句不超过 20 字；判断直接说，不加"我觉得可能"这类缓冲」。**Don't** 会写：「不用"首先 / 其次 / 综上所述"；不在结论前铺超过一句的背景」。

这种东西很难靠语言描述传递给 AI，但很容易用样本文章蒸馏出来。

![](./illustration.png)

## 为什么要蒸馏成文件

直接把样本文章粘给 AI，让他"模仿这个风格"——也能用，但它只管这一次。

下次开新对话，他不记得了。你又得把样本粘一遍，或者重新解释一遍"我的风格是……"。

`style.md` 把这件事持久化了：

- **可放进项目**——任何 agent 都能读，不用每次手动喂
- **可手动改**——觉得分析不准，直接改那个文件，比重新喂一堆样本更快
- **可积累**——写了更多文章之后，觉得风格又调整了，重新跑一次蒸馏，更新文件
- **可审计**——你能看到 AI 认为你的特点是什么，不对的地方可以纠正

比"模仿"更可靠，因为中间多了一层你能看见的东西。

## 怎么用

**第一步**：把三到五篇自己写的文章（`.md` 或 `.txt` 格式）放进 `./samples/`。

**第二步**：对 Claude Code 说一句：

```text
Use the style-distiller skill.
```

它自动读 `./samples/` 里所有文件，分析，输出 `./style.md`。

从此以后，每次开始写文章之前，先把 `style.md` 给他看一眼：

```text
Read style.md，然后帮我润色这篇草稿。
```

样本越多，分析越准。三篇是起步，五篇以上会更稳。

## 什么时候最有用

这个 skill 对几类人特别有用：

**长期写某一类内容的人。** 技术博客、专栏、行业评论——风格是品牌的一部分。AI 帮你写的时候，最不想要的就是风格不一致。样本越多、写得越久，蒸馏出来的 `style.md` 越准。

**有合作写作需求的人。** 你定义好 `style.md`，把文件夹分享给另一个人，让他用同一套风格续写或投稿——等于把风格变成了可交接的规范，而不是只有你自己感受得到的东西。

**想保住自己声音的人。** AI 最容易做的事是把你的文章写得更"标准"——句子更圆滑，结构更完整，词汇更得体。但有时候你要的不是更标准，是更像你。`style.md` 让他知道哪些地方不要动。

## 说一点实话

这 skill 现在比较初级，分析质量高度依赖 AI 对"风格"的理解——有时候蒸馏出来的东西太泛，说你"句子简洁"但说不清简洁在哪里。

遇到这种情况，直接改 `style.md`。把他写得不准的地方换成你自己的话，加上他漏掉的规则。

这正是它的价值所在：不是让你信任 AI 的判断，是给你一个起点，你来修订。`style.md` 最后是你的文件，不是他的。

我自己的 `style.md` 里，有一条 AI 分析出来的规则我改了措辞——他写的是"句子简洁"，我改成了"每段只讲一件事，讲完就停，不做收尾句"。这才是我实际的习惯，"简洁"太泛，对下次写作没有帮助。

改完这一条，下次润色的结果明显准了。

**风格是你的，蒸馏只是第一步。**

---

如有错误或不严谨之处，欢迎评论区指正。

## 附：SKILL.md 原文

```markdown
# Style Distiller

## Description

Use this skill when the user wants to distill an author's writing style from sample articles.

When this skill is invoked, automatically read all supported text files from the `samples/` directory and create a `style.md` file that summarizes the author's writing style.

The user does not need to manually paste the articles.

## What This Skill Does

This skill only does one thing:

Read articles from ./samples/
Analyze the writing style
Output the style profile to ./style.md

It does not rewrite articles.
It does not generate new articles.
It only distills the writing style into a reusable markdown file.

## Input Folder

Read writing samples from:

./samples/

Supported file types:

.md
.txt

Read all supported files inside `./samples/`.

If the `samples/` directory does not exist, or if no supported files are found, tell the user:

No writing samples found. Please place .md or .txt article samples in ./samples/ and run the skill again.

## Output File

Create or overwrite:

./style.md

The output should describe the author's style in a reusable way.

## Task

When this skill is called:

1. Read all `.md` and `.txt` files inside `./samples/`.
2. Analyze the writing style across all samples.
3. Focus on repeated style patterns, not one-off details.
4. Create a `style.md` file.
5. Do not rewrite the articles.
6. Do not copy distinctive sentences or phrases from the samples.
7. Keep the output clear, practical, and easy to reuse.

## Analyze These Dimensions

Analyze the writing based on the following dimensions:

| Dimension            | What to Look For                                                                                                           |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Sentence Length      | Are the sentences mostly long, short, or mixed? Are there frequent fragments or broken sentences?                          |
| Rhythm               | Is the rhythm smooth, fast, fragmented, slow, jumpy, or compressed?                                                        |
| Vocabulary           | Is the wording simple, academic, conversational, literary, cold, technical, or poetic?                                     |
| Tone                 | Is the tone gentle, ironic, restrained, humorous, serious, tense, detached, or intimate?                                   |
| Imagery              | Does the writing use concrete details, sensory images, physical objects, or abstract ideas?                                |
| Paragraph Structure  | Are paragraphs short and punchy, or long and slowly developed?                                                             |
| Narrative Distance   | Is the voice close to inner thoughts, or more observational and distant?                                                   |
| Rhetoric             | Does the writing use metaphor, repetition, contrast, rhetorical questions, parallel structure, understatement, or silence? |
| Information Density  | Is the writing dense, sparse, explanatory, compressed, or suggestive?                                                      |
| Emotional Expression | Are emotions stated directly, or implied through action, setting, pacing, and detail?                                      |

## style.md Output Format

Write `style.md` using this exact structure:

# Writing Style Profile

## Source

This style profile was distilled from the articles in `./samples/`.

## Overall Style

Summarize the overall writing style in 3–5 sentences.

## Style Dimensions

### Sentence Length
### Rhythm
### Vocabulary
### Tone
### Imagery
### Paragraph Structure
### Narrative Distance
### Rhetoric
### Information Density
### Emotional Expression

## Reusable Style Instructions

## Do

- List what future writing should do.

## Don't

- List what future writing should avoid.

## Rules

* Always read from `./samples/` by default.
* Always output to `./style.md`.
* Do not ask the user to paste articles unless `./samples/` is missing or empty.
* Do not rewrite the articles.
* Do not generate a new article.
* Do not directly imitate a living author by name.
* Do not copy exact sentences, metaphors, or distinctive phrases.
* Focus on abstract and reusable style traits.
* Keep the result practical, clear, and not overly long.
* The final deliverable must be the `style.md` file.

## Example Invocation

The user can simply say:

Use the style-distiller skill.

Then the skill should automatically:

Read ./samples/
Analyze the articles
Create ./style.md
```
