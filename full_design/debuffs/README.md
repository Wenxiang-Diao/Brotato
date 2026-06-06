# Debuff 风险管理系统｜总览

> 模块：Debuff Risk Management System  
> 优先级：P0  
> 适用阶段：MVP 起步版本  
> 依赖系统：战斗、元素 / 状态、角色、武器、怪物、节点、抽奖 / 奖励、水晶

---

## 1. 系统定位

Debuff 风险管理系统是《星链回响》的核心差异化系统之一。

它不是单纯惩罚玩家，而是让玩家在局内成长过程中不断面对“收益与代价”的选择：

```text
获得强力奖励
→ 接受一定负面效果
→ 通过 build / 角色 / 节点 / 水晶进行管理
→ 形成高风险高收益流派
```

总策划中已经明确：成长必然伴随负面效果，并且每 5 级提供一次“修正窗口”。本系统即围绕这一规则展开。

---

## 2. 核心目标

| 目标 | 说明 |
|---|---|
| 制造构筑压力 | 强奖励不应无成本获得 |
| 强化路线选择 | 玩家需要根据当前 Debuff 选择节点 |
| 支持风险流派 | 部分角色、武器、水晶可以利用 Debuff |
| 提高局内变化 | 每一局的风险组合不同 |
| 控制强度膨胀 | 用代价约束强力 build |
| 增加策略深度 | 玩家需要决定保留、修正还是转化 Debuff |

---

## 3. 文档索引

| 文件 | 内容 |
|---|---|
| `debuff_design_framework.md` | Debuff 系统框架与核心规则 |
| `debuff_taxonomy.md` | Debuff 分类与危险等级 |
| `debuff_acquisition_and_removal.md` | Debuff 获取、移除、压制和转化规则 |
| `risk_reward_binding_rules.md` | 风险奖励绑定规则 |
| `level_5_correction_window.md` | 每 5 级修正窗口设计 |
| `debuff_integration_rules.md` | 与角色、武器、状态、节点、奖励、水晶等系统的联动 |
| `debuff_examples.md` | 30 个 Debuff 示例 |
| `balance_and_ux_rules.md` | 平衡性与 UI / UX 规则 |

---

## 4. MVP 推荐范围

MVP 阶段建议实现：

- Debuff 分类：属性类、操作类、资源类、状态类、环境类、构筑类、诅咒类
- Debuff 危险等级：轻度、中度、重度、诅咒
- 每 5 级修正窗口
- 强力奖励绑定 Debuff
- 休息节点、商店节点、事件节点提供修正方式
- 角色 / 水晶对 Debuff 的有限转化
- 30 个基础 Debuff 示例

---

## 5. 设计关键词

```text
风险收益
可修正
可转化
可构筑
不纯惩罚
不破坏操作体验
机制优先于数值
```
