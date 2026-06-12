基于 https://www.anthropic.com/engineering/harness-design-long-running-apps 写一篇文章。

核心论点：
- AI 写完代码后，引入一个独立的 agent 来 review，确保它的上下文窗口是干净的（fresh）
- review 的基准线是一份「合同」
- 要设计 / 写一份合同，代码必须被打分，分数高于阈值才算通过
