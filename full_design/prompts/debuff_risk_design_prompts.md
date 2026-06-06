# Debuff 风险管理系统设计 Prompts

以下 prompts 适用于在 Codex 或其他仓库协作工具中，基于当前《星链回响》项目文档继续扩充 Debuff 风险管理系统。建议按阶段执行。

---

## Prompt 1：读取并理解已有设定，不修改文件

```text
这是一个本地 Git 仓库中的游戏策划文档项目。请先读取当前仓库中的所有已有文件，尤其是：

1. 项目总策划案 / GDD
2. 元素系统 / 状态系统设计文档
3. 武器设计文档，如果存在 weapons/ 文件夹
4. 角色设计文档，如果存在 characters/ 文件夹
5. 怪物设计文档，如果存在 monsters/ 文件夹
6. 节点 / 关卡路线系统，如果存在 nodes/ 文件夹
7. 抽奖 / 奖励系统，如果存在 rewards/ 文件夹

本阶段只允许阅读和分析，不要创建、修改或删除任何文件。

请完成以下任务：
1. 总结当前项目中 Debuff 风险管理系统的已有描述。
2. 总结当前项目为什么需要 Debuff 系统。
3. 分析 Debuff 系统与元素、状态、武器、角色、怪物、节点、抽奖、奖励、水晶系统之间的关系。
4. 参考 Roguelite / Action Survival / Brotato-like / Vampire Survivors-like 游戏，总结适合本项目的风险收益设计原则。
5. 提炼 Debuff 系统设计时必须遵守的约束。
6. 判断当前仓库是否已经存在 debuffs/ 文件夹。
7. 输出你读取到的关键文件列表。

注意：不要修改文件，不要创建文件，不要提交 commit，只做理解和总结。
```

---

## Prompt 2：设计 Debuff 系统框架，不写文件

```text
基于你刚才读取到的项目设定，请先设计一个适用于本项目的 Debuff 风险管理系统框架。

本阶段不要创建、修改或删除任何文件，只输出系统框架供我确认。

该系统需要服务于当前项目的核心目标：
- 成长必然伴随风险
- 强力 build 需要付出代价
- 每 5 级提供一次“修正窗口”
- 玩家可以主动构筑风险型流派
- Debuff 不是纯粹惩罚，而是 Roguelite 构筑的一部分

请设计以下内容：
1. 系统目标
2. 设计原则
3. Debuff 分类
4. Debuff 品质 / 危险等级
5. Debuff 获取方式
6. Debuff 移除和修正规则
7. 每 5 级修正窗口规则
8. Debuff 与奖励 / 抽奖系统的绑定规则
9. Debuff 与角色、武器、状态、怪物、节点、水晶系统的联动
10. UI / UX 提示规则
11. 平衡性约束
12. MVP 范围和后续扩展方向

请确保该框架可开发落地，不要设计过度复杂的系统。
```

---

## Prompt 3：设计 Debuff 分类与示例清单，不写文件

```text
基于已确认的 Debuff 系统框架，请先提出一套 Debuff 分类和示例清单。

本阶段仍然不要创建、修改或删除任何文件，只输出设计方案供我检查。

请至少设计 30 个 Debuff，分为以下类别：
1. 属性类 Debuff
2. 操作类 Debuff
3. 资源类 Debuff
4. 状态类 Debuff
5. 环境类 Debuff
6. 抽奖 / 构筑类 Debuff
7. 高风险诅咒类 Debuff

每个 Debuff 需要包含：
- 名称
- 分类
- 危险等级
- 效果描述
- 适合绑定的奖励类型
- 可被哪些方式修正或移除
- 是否适合风险流派利用
- 平衡性备注

要求：
1. 不要只设计单纯扣属性的 Debuff。
2. Debuff 应该能制造选择压力。
3. 一部分 Debuff 可以被特定角色或 build 转化为收益。
4. 避免无法操作、纯恶心或破坏体验的效果。
5. 与当前元素 / 状态 / 抽奖 / 节点系统保持一致。
```

---

## Prompt 4：正式创建 debuffs/ 文档

```text
我确认 Debuff 系统框架和 Debuff 示例方案可以继续。

现在请在仓库根目录创建 `debuffs/` 文件夹，并正式写入 Debuff 风险管理系统文档。

请创建以下 Markdown 文件：

- `debuffs/README.md`
- `debuffs/debuff_design_framework.md`
- `debuffs/debuff_taxonomy.md`
- `debuffs/debuff_acquisition_and_removal.md`
- `debuffs/risk_reward_binding_rules.md`
- `debuffs/level_5_correction_window.md`
- `debuffs/debuff_integration_rules.md`
- `debuffs/debuff_examples.md`
- `debuffs/balance_and_ux_rules.md`

文档要求：
1. 保持中文策划文档风格。
2. 与当前总策划、元素系统、角色、武器、怪物、节点、奖励系统保持一致。
3. Debuff 要体现风险收益，而不是纯惩罚。
4. 每个 Debuff 都要有明确限制和修正方式。
5. `debuff_examples.md` 至少包含 30 个 Debuff 示例。
6. `README.md` 需要提供系统总览和文档索引。
7. 不要删除或破坏已有文件。
8. 如果引用已有系统，请保持设定一致。

完成后请输出新增文件列表和设计摘要。
```

---

## Prompt 5：自查和修复

```text
请检查刚才新增的 `debuffs/` 文件夹和所有 Markdown 文件。

重点检查：
1. 是否存在全部 9 个文档。
2. README 索引是否完整。
3. Debuff 分类是否覆盖属性、操作、资源、状态、环境、抽奖构筑、诅咒等方向。
4. 是否至少有 30 个 Debuff 示例。
5. Debuff 是否与奖励系统、节点系统、角色系统、状态系统、水晶系统匹配。
6. 是否存在过于恶心、破坏体验或无法开发落地的 Debuff。
7. 是否存在没有修正手段的 Debuff。
8. 是否存在明显过强或过弱的风险奖励绑定。
9. 每 5 级修正窗口是否规则清晰。

如果发现问题，请直接修复。

完成后输出修复摘要、仍需人工确认的问题和建议的 Git commit message。
```
