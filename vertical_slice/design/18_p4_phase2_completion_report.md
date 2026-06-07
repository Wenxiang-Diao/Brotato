# P4 阶段 2：UI/UX 规范与线框完成报告

## 1. 完成范围

阶段 2 已完成本地设计文档和 Figma 原生画布落地：

- 统一视觉 token。
- 中文排版与阴影样式。
- 核心组件状态。
- 主菜单、战斗 HUD、奖励、修正、暂停、设置、结算和教程线框。
- 键盘、鼠标与手柄焦点规则。
- Godot `Control` 架构契约。

本阶段没有生成正式图标，也没有修改 Godot 运行时代码。

## 2. Figma 文件

- 文件：`星链回响 - P4 UIUX v1`
- 地址：<https://www.figma.com/design/kodk8k0rH7pvYLbTujVJgF>
- 团队：`Brotato`
- 设计席位：Professional Full

## 3. Foundations

已创建：

- `P4 Primitives`：26 个原始颜色变量。
- `P4 Semantic`：31 个语义颜色变量。
- `P4 Dimensions`：18 个间距、圆角和尺寸变量。
- 8 套 `Noto Sans SC` 文字样式。
- 1 套面板阴影样式。

所有语义颜色使用变量别名关联原始颜色，并设置了明确 scopes。最终检查未发现缺失字体。

## 4. 组件库

| 组件 | 变体 |
| --- | --- |
| Action Button | Default、Hover、Focused、Pressed、Selected、Disabled、Dangerous |
| Status Badge | Mark、Shock、Freeze、Burn、Risk |
| Reward Card | Standard、Focused、Risk |
| Progress Bar | Health、XP、Boss |
| Weapon Slot | Ready、Cooldown |
| Input Prompt | Keyboard、Gamepad |
| Icon Button | Default、Focused、Disabled、Dangerous |
| Confirm Dialog | 独立组件；标题和说明可编辑 |

状态、武器和奖励图标目前使用几何占位符。正式图标将在阶段 3 生成。

## 5. 页面与线框

Figma 文件包含 10 个页面：

1. `00 Cover`
2. `01 Foundations`
3. `02 Components`
4. `03 Main Menu`
5. `04 Combat HUD`
6. `05 Reward Selection`
7. `06 Correction`
8. `07 Pause & Settings`
9. `08 Results`
10. `09 Input & Accessibility`

已完成 17 个 1280×720 Screen：

- Main Menu
- Combat HUD
- Combat HUD / Boss
- Reward Selection
- Correction
- Pause
- Pause / Confirm Restart
- Pause / Confirm Main Menu
- Settings / Accessibility
- Settings / Display
- Settings / Audio
- Settings / Controls
- Results
- Tutorial Step 1
- Tutorial Step 2
- Tutorial Step 3
- Input & Focus Rules

## 6. 视觉复核

- 主菜单默认焦点、风险说明和输入提示清晰。
- HUD 不再使用左右两块长文本，一级信息、武器、技能与风险区域分离。
- 奖励页完整展示当前构筑、品质、收益、代价、危险等级和适配提示。
- 修正窗口显示实际状态、来源、影响和安全默认选项。
- 暂停页包含构筑摘要，重新开始和返回主菜单均有二次确认画板。
- 设置页覆盖显示、音频、操作和可访问性四类入口。
- 结算页分离构筑总结与战斗统计。
- 教程按移动、自动攻击/技能、元素反应三个单一概念分步。
- 输入提示使用动作语义，运行时再根据最近输入设备替换键帽或手柄提示。

## 7. 最终结构检查

- 75 个本地变量。
- 8 个文字样式。
- 1 个效果样式。
- 7 个组件集和 1 个独立确认弹窗组件。
- 17 个标准 Screen。
- 0 个缺失字体。
- 112 个 Figma 默认通用层名已统一重命名。

阶段 2 的二次复核与修复详情记录于
`vertical_slice/design/19_p4_phase2_revalidation_report.md`。

## 8. 下一阶段边界

阶段 3 只生成第一批正式图标预览板：

- 4 个武器。
- 4 个基础状态。
- 3 个元素反应。
- 1 个主动技能。
- 4 个通用 UI 图标。
- 垂直切片实际使用的负面状态图标。

生成后必须停止，等待用户检查。只有用户明确同意后，才允许进入 Godot UI 组件实现和图标接入。
