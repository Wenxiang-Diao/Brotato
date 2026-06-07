# 《星链回响》垂直切片

本目录是独立于 `full_design/` 的最小可玩版本，用于验证核心战斗是否成立。

## 目录

- `selected_sources/`：从完整策划中选出的原始设计文件。
- `design/`：垂直切片统一规格、范围和测试方案。
- `game/`：Godot 4.x 可运行原型。
- `data/`：机器可读游戏配置。
- `tools/`：数据校验工具。
- `tests/`：自动化检查。

## 工程结构

- `game/scripts/main.gd`：输入、状态机、帧循环和灰盒绘制。
- `game/scripts/core/`：数据、指标、奖励、战斗规则、实体工厂、成长、目标查询与战斗事件。
- `data/manifest.json`：数据 schema 与必需配置清单。

P2 架构说明见 `design/10_p2_architecture_plan.md`，完成结论见 `design/11_p2_completion_report.md`。

## 启动目标

```text
移动与走位
→ 自动武器攻击
→ 施加状态
→ 触发反应
→ 获得经验并三选一
→ 完成 6 层战斗
→ 击败星骸巨像
```

## 两种验证模式

- `标准模式`：不生成风险奖励和 Debuff，用作核心战斗基线。
- `风险模式`：风险奖励可绑定 Debuff，用于判断风险管理是否提升体验。

## 运行

使用 Godot 4.x 打开本目录下的 `project.godot`，运行主场景。

操作：

- `1`：标准模式。
- `2`：风险模式。
- `WASD` / 方向键：移动。
- `Space`：主动技能。
- 首次战斗引导按 `Enter` 开始。
- `Esc` / `P`：暂停或继续。
- 奖励界面 `R`：消耗一次重抽。
- 结算界面 `R`：以相同模式重开。
- 暂停或结算界面 `M`：返回模式选择。
- `F9`：显示或隐藏性能调试面板。
- `F8`：切换低动态反馈，关闭屏幕震动与命中停顿。
- `F10`：调试跳层；该局不会进入正式 A/B 汇总。

P1 新增新手引导、Boss 倒计时预警、状态反应图例、奖励重抽、武器等级显示和结算统计。完整验收项见 `design/08_p1_completion_checklist.md`。

数据校验：

```powershell
python vertical_slice/tools/validate_data.py
```
