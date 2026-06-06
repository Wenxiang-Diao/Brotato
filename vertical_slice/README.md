# 《星链回响》垂直切片

本目录是独立于 `full_design/` 的最小可玩版本，用于验证核心战斗是否成立。

## 目录

- `selected_sources/`：从完整策划中选出的原始设计文件。
- `design/`：垂直切片统一规格、范围和测试方案。
- `game/`：Godot 4.x 可运行原型。
- `data/`：机器可读游戏配置。
- `tools/`：数据校验工具。
- `tests/`：自动化检查。

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

数据校验：

```powershell
python vertical_slice/tools/validate_data.py
```
