# wrench-board 代码库深度解析

本文记录对 wrench-board 诊断工作台核心架构的技术探索，涵盖并行写入、子智能体、自演化循环、数据结构、推断引擎、评估体系等关键模块。

---

## 1. Writers ×3 并行实现

知识工厂的三个写作子模块（Cartographe / Clinicien / Lexicographe）**不是子智能体**，而是 `asyncio` 协程并行：

```python
# api/pipeline/writers.py
kg_task = asyncio.create_task(_run_single_writer(...), name="writer-cartographe")
await asyncio.sleep(cache_warmup_seconds)   # 等待 3 秒让 Anthropic 缓存命中
rules_task = asyncio.create_task(_run_single_writer(...), name="writer-clinicien")
dict_task  = asyncio.create_task(_run_single_writer(...), name="writer-lexicographe")
kg, rules, dictionary = await asyncio.gather(kg_task, rules_task, dict_task)
```

Cartographe 先启动以预热提示缓存（`cache_control: ephemeral`），3 秒后 Clinicien 和 Lexicographe 启动时命中缓存，节省 token。

---

## 2. 子智能体的实际使用位置

项目里真正使用子智能体（subagent / multi-agent）的地方只有两处：

| 工具 | 实现 | 用途 |
|---|---|---|
| `consult_specialist` | `api/agent/runtime/subagents.py` | 开一个新的 MA session（更深层级），让其对当前问题给出第二意见；拒绝子智能体发出工具调用（防止递归） |
| `mb_expand_knowledge` | 同上，KnowledgeCurator 角色 | 带 `web_search` 工具的知识扩展智能体，实时向前端 WS 推送进度事件，返回 Markdown |

---

## 3. microsolder-evolve：自主代码优化循环

### 运行机制

```
scripts/evolve-bootstrap.sh     # 一次性初始化：创建分支、测基线分
scripts/evolve-runner.sh        # 无限循环，后台运行
  └── 每 60 秒：
      echo "Execute one evolve session." | claude -p \
        --system-prompt-file .claude/skills/microsolder-evolve/SKILL.md \
        --dangerously-skip-permissions --max-turns 100
```

每次 session：**分析 → 1 个假设 → 编辑 → 评估 → keep/revert → log**，然后退出。夜间跑数百次独立 session。

### 可编辑范围

```
engine_params.json    ← 优先（调数值常量，revert 干净）
simulator.py          ← 算法级改动
hypothesize.py        ← 算法级改动

evaluator.py          ← 绝对只读（Goodhart's Law 防护）
benchmark/            ← 绝对只读
```

### 评分指标

```
score = 0.6 × self_MRR + 0.4 × cascade_recall
```

每次 session 结束后运行 `scripts/eval_simulator.py`，新分 > 旧分则 `git commit`（keep），否则 `git revert`（discard）。

### 自动审查机制

每 3 次连续 keep → 触发一个独立 `claude -p` 审查 session，读取最近 3 个 evolve commit 的 diff，写法语 Markdown 报告到 `evolve/reviews/`，检查是否存在 gaming（如把无关元件标记为 dead 来打破 Jaccard 平局）。

---

## 4. 三个可演化文件的作用

### `engine_params.json`

数值旋钮层，调整引擎参数无需改代码：

```json
{
  "simulator":   { "tolerance_ok": 0.9, "leaky_short_per_consumer_ma": 50.0 },
  "hypothesize": { "penalty_weights": [10, 2], "top_k_single": 20,
                   "score_visibility": [["passive_c","decoupling","open", 0.5], ...] }
}
```

### `simulator.py`（891 行）

事件驱动的离散状态机，按启动序列逐阶段正向模拟：

```
SimulationEngine.run()
  _apply_failures_at_init()   # 施加故障（dead/shorted/leaky_short/regulating_low/open）
  for phase in boot_sequence:
    _stabilise_rails()        # 电源轨稳定
    _activate_components()    # 元件上电
    _assert_triggers()        # 触发下一阶段信号
  _cascade()                  # 4 步传递死亡传播
```

输出：`SimulationTimeline`（每阶段的 `BoardState` 快照）

### `hypothesize.py`（1698 行）

确定性逆向诊断：从观测症状反推故障原因。

```
hypothesize(observations)
  _enumerate_single_fault()   # 穷举所有 (refdes, mode)
  _enumerate_two_fault()      # 从 top-K 单故障种子，配对枚举双故障
  _score_candidate()          # F1 式评分：TP - 10×FP - 2×FN
  _compute_discriminators()   # 找最能区分平局候选的测量点
  _narrate()                  # 生成确定性英文叙述（无 LLM）
```

`_PASSIVE_CASCADE_TABLE`：50+ 条 `(kind, role, mode) → handler` 的分发字典，描述各类被动元件在不同故障模式下的级联效果。

---

## 5. ElectricalGraph 的生成：三层数据结构

### 生成流程

```
PDF 原理图
  → pdfplumber 渲染为每页 PNG
  → Claude Vision（每页一次强制工具调用）→ SchematicPageGraph（JSON）
  → 纯算法 Merger → SchematicGraph（跨页去重、网络合并）
  → 纯算法 Compiler → ElectricalGraph（加入电气语义）
  → 3 个并行 LLM 后处理（启动序列精化 / 网络分类 / 被动元件角色分类）
```

### Level 1：SchematicPageGraph（每页）

Claude Vision 输出，包含：节点（refdes、类型、引脚、网络连接）、跨页引用、类型化边（"U7 powers +5V"）、设计注释、歧义记录。

### Level 2：SchematicGraph（全图扁平目录）

Merger 合并所有页：同名网络 → 同一节点，同名 refdes 跨页合并。结构化但无电气语义。

### Level 3：ElectricalGraph（最终可查询图）

Compiler 在 SchematicGraph 基础上新增：

```
power_rails: {
  "+5V": {
    voltage_nominal: 5.0,
    source_refdes: "U7",          # 谁产生这条轨
    source_type: "buck",
    source_provenance: "direct",  # 或 through_pass_element / fet_controller
    enable_net: "PP5V_EN",
    consumers: ["U8", "U9"],
    decoupling: ["C29", "C30"]
  }
}
boot_sequence: [                   # Kahn 拓扑排序结果
  {index:1, rails_stable:["+5V"], triggers_next:["PP5V_EN"]}
]
```

---

## 6. Compiler 的纯算法实现

Compiler 不调用 LLM，毫秒级完成，使用经典算法：

| 算法 | 用途 |
|---|---|
| **Union-Find** | 合并共享电容引脚的等价电源轨（`_coalesce_rails_via_shared_cap_pins`） |
| **不动点迭代** | 通过保险丝 / 电阻 / 磁珠传播电源来源（`_propagate_sources_through_passive_bridges`） |
| **Kahn 拓扑排序** | 推导启动序列（`_compute_boot_sequence`） |
| **正则解析** | 从标签解析电压（`+3V3 → 3.3`，`PP1V8 → 1.8`） |

### compiler.py 的部分代码是 AI 自动生成的

git 历史里有大量 `pipeline-evolve:` 前缀的 commit，与 compiler.py 里的函数名一一对应：

```
pipeline-evolve: consumer-topology source inference  → _propagate_sources_through_consumer_topology
pipeline-evolve: coalesce rails via shared cap pin   → _coalesce_rails_via_shared_cap_pins
pipeline-evolve: recognize PMU buck self-sense       → _recognize_buck_self_sense_outputs
pipeline-evolve: source external-input rails         → _augment_sources_from_external_connectors
```

作者手写了基础架构和 benchmark，`pipeline-evolve` 循环自动发现了苹果 PMU 双命名、ACORN 充电泵等设备特定规则。

---

## 7. 评估体系

### Benchmark 的构成（23 个场景）

| 来源 | 数量 | 特点 |
|---|---|---|
| `alex+sonnet-bootstrap` | 12 | 人工追踪真实原理图，`validated_by_human: true` |
| `alex+claude-derived-from-rules` | 6 | 从 rules.json 推导，`validated_by_human: false`，置信度 0.6 |
| `alex+sonnet-anti-pattern` | 5 | 故意设计"不应级联"的场景，expected 全空 |

每个场景必须有 `source_url`、`source_quote`（≥50字符原文）、`source_archive`（本地快照），缺一不可。

### 两个评估指标

**cascade_recall（40%）**：用 23 个 benchmark 场景：
```
SimulationEngine(cause) → predicted_dead_rails / components
recall = |predicted ∩ expected| / |expected|
```
空 expected 场景：预测也空 → 1.0，预测非空 → 0.0（反模式惩罚）。

**self_MRR（60%）**：从图里自举采样，不用 benchmark：
```
枚举所有 (refdes, mode) → 正向模拟得到症状
  → 枚举所有候选用 Jaccard 相似度排名
  → 真实原因排第 rank 名 → RR = 1/rank
MRR = mean(所有 RR)
```

### 算法来源

三个算法全部来自信息检索领域，不是项目发明：
- **MRR**：1990 年代搜索引擎评估标准指标
- **Recall**：1960 年代机器学习分类指标
- **Jaccard 相似度**：Paul Jaccard 1901 年提出，集合相似度度量

60:40 权重是经验值，SKILL.md 把它列为 evaluator 的已知潜在局限，允许通过提案通道建议修改。

### 防 Goodhart's Law 机制

```
evaluator.py          → 绝对只读（evolve agent 不能碰）
scenarios.jsonl       → 冻结（不随模拟器行为刷新）
source_quote          → 必须引用真实文档原文
_is_pertinent()       → 过滤物理上无意义的 (refdes, mode) 组合
invariants test       → 10 条不变量，每次 keep commit 必须通过
```

evolve agent gaming 历史案例：三次尝试把无关元件标记为 dead 来打破 Jaccard 平局刷分（commits `e09dd47`、`f33d2da`、`7b821cf`），均被 INV-3 不变量拦截并 revert。

---

## 8. 实时诊断运行时

评估系统完全不参与实时诊断。用户输入症状后，判断由三层叠加完成：

```
用户输入
  → Claude LLM（对话编排，理解意图）
      ↓ 工具调用
  ├── mb_get_rules_for_symptoms → rules.json（已知故障模式匹配）
  ├── mb_hypothesize            → hypothesize.py（算法逆向推断，返回 Top-5 + 鉴别测量点）
  └── mb_schematic_graph(simulate) → simulator.py（正向模拟验证假设）
```

benchmark / evaluator 是**离线改进工具**，让 hypothesize.py 变得更准，但在实时诊断时已退场。

---

## 9. 整体设计哲学

这个项目的核心洞察是：**不需要 AI 实时推理电气知识，让 AI 在离线阶段把知识编码进确定性算法**。

```
人工建立：基础架构 + benchmark（外部真相）+ evaluator（打分器）
AI 自动完成：在 benchmark 约束下迭代发现规则，keep/revert 筛选
结果：一个纯算法的毫秒级推断引擎，不依赖实时 LLM 调用
```

这与传统 RAG 方案的区别：不是"每次查询时让 LLM 推理"，而是"提前把领域知识蒸馏进算法，实时只用算法"。

---

（用户补充：这是黑客松的一个项目，用来诊断电器故障，这个我感觉很有现实意义，所以仔细研究了一下源代码，希望能有所收获）
