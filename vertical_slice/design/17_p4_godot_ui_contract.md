# P4 阶段 2：Godot UI 架构契约

## 1. 目标结构

正式 UI 不继续扩展 `main.gd` 的 `_draw_*()`。迁移目标：

```text
Main (Node2D)
├── WorldRoot (Node2D)
├── EffectsRoot (Node2D)
└── UILayer (CanvasLayer)
    ├── HUD (Control)
    ├── ScreenStack (Control)
    ├── ModalStack (Control)
    ├── ToastLayer (Control)
    └── DebugLayer (Control)
```

职责：

- `Main`：游戏状态与场景编排。
- `HUD`：只显示可观察状态，不修改战斗规则。
- `ScreenStack`：主菜单、结算等全屏页面。
- `ModalStack`：教程、奖励、修正、暂停、确认框。
- `ToastLayer`：短暂非阻断消息。
- `DebugLayer`：开发构建专用。

## 2. 场景目录

```text
game/ui/
├── ui_root.tscn
├── theme/
│   ├── game_theme.tres
│   └── ui_tokens.gd
├── components/
│   ├── action_button.tscn
│   ├── icon_button.tscn
│   ├── reward_card.tscn
│   ├── weapon_slot.tscn
│   ├── status_badge.tscn
│   ├── progress_bar.tscn
│   ├── input_prompt.tscn
│   └── confirm_dialog.tscn
├── hud/
│   ├── combat_hud.tscn
│   └── boss_hud.tscn
└── screens/
    ├── main_menu.tscn
    ├── tutorial_dialog.tscn
    ├── reward_screen.tscn
    ├── correction_dialog.tscn
    ├── pause_screen.tscn
    ├── settings_screen.tscn
    └── results_screen.tscn
```

## 3. 数据边界

UI 不直接读取或修改战斗数组。`Main` 或专用 presenter 负责生成只读视图模型。

示例：

```gdscript
var hud_view := {
	"hp": 78.0,
	"max_hp": 100.0,
	"xp": 24.0,
	"xp_required": 40.0,
	"level": 3,
	"layer": 2,
	"layer_count": 6,
	"time_remaining": 42.0,
	"weapons": [],
	"debuffs": [],
}
```

奖励卡视图模型至少包含：

```gdscript
{
	"id": "magnetic_coin",
	"title": "磁暴硬币",
	"quality": "blue",
	"reward_type": "weapon_unlock",
	"summary": "解锁可弹射的感电武器",
	"description": "...",
	"icon_path": "res://assets/ui/icons/weapons/magnetic_coin.png",
	"tags": ["感电", "连锁"],
	"current_level": 0,
	"next_level": 1,
	"risk": null,
}
```

风险对象必须包含：

- 名称
- 危险等级
- 效果
- 层数
- 来源
- 是否绑定奖励
- 是否可移除
- 修正方式
- 与当前构筑的关系

## 4. 信号契约

UI 只发出意图：

```gdscript
signal mode_selected(risk_mode: bool)
signal reward_selected(index: int)
signal reroll_requested
signal correction_selected(index: int)
signal pause_requested
signal resume_requested
signal restart_requested
signal menu_requested
signal setting_changed(key: StringName, value: Variant)
```

战斗层验证意图是否合法，再更新状态并刷新 UI。按钮不得直接调用伤害、奖励或存档服务。

## 5. 输入映射

`project.godot` 后续必须增加：

- `ui_accept`
- `ui_cancel`
- `ui_left`
- `ui_right`
- `ui_up`
- `ui_down`
- `ui_reroll`
- `ui_details`
- `ui_pause`

设备检测记录最近一次有效输入类型：

- KeyboardMouse
- Gamepad

输入提示组件只订阅设备变化，不在每个页面分别判断按键。

## 6. 主题实现

`game_theme.tres` 负责：

- 默认字体与字号。
- Button、Panel、ProgressBar、Label 的基础 StyleBox。
- Focus、Disabled、Dangerous 的样式覆盖。
- 内容边距和最小尺寸。

`ui_tokens.gd` 只存放 Godot Theme 无法清晰表达的语义常量，例如品质、元素状态和动效时长。

禁止：

- 在页面脚本中散落十六进制颜色。
- 为每张卡复制一套 StyleBox。
- 用图片文字替代真实 Label。
- 依赖系统字体。

## 7. 布局实现

- 页面根节点使用 Full Rect anchors。
- 结构布局使用 `MarginContainer`、`VBoxContainer`、`HBoxContainer`、`GridContainer`。
- 固定坐标只用于装饰层，不用于正文和交互控件。
- 奖励卡使用三列 `GridContainer`，窄窗口可切换横向滚动或单列。
- HUD 使用四个独立锚点区域，不使用一个长文本块。
- Modal 打开时暂停战斗并阻止底层鼠标与焦点输入。

## 8. 状态同步

避免每帧重建控件：

- HP、XP、计时等高频数值只更新属性。
- 武器、Debuff、奖励列表只在集合变化时重建。
- 图标资源预加载或缓存。
- UI 动画不参与战斗确定性，也不改变游戏状态。

## 9. 迁移顺序

1. 建立 Theme、输入 actions 和 UI 根节点。
2. 迁移主菜单与暂停页，验证焦点和鼠标/手柄。
3. 迁移 HUD，保留旧 `_draw_hud()` 作为短期对照。
4. 迁移奖励与修正页，接入只读视图模型。
5. 迁移教程与结算。
6. 删除旧 `_draw_*()` UI 和硬编码菜单输入。
7. 将调试面板移至 `DebugLayer`。

每次只迁移一个页面，旧页面在新页面通过测试前不得删除。

## 10. 自动化验收

至少增加以下测试：

- 所有 UI 场景可无错误实例化。
- Theme 和字体资源存在。
- 所有交互控件具有非空焦点邻居或由容器自动导航。
- 奖励页三张卡均可由键盘、鼠标与模拟手柄选择。
- 模态打开时战斗时间不推进。
- 关闭模态后焦点返回正确控件。
- 1280×720、1280×800、1920×1080 下关键文本不越界。
- 低动态模式不会播放位移、缩放或闪烁动画。
- DebugLayer 在正式构建默认隐藏。

## 11. 阶段边界

本契约只定义正式实现方式，不在 P4 阶段 2 改造运行时代码。

阶段 3：

- 按统一规范生成图标预览板。
- 用户检查并明确同意后才可进入实现。

阶段 4：

- 创建 Godot UI 组件和页面。
- 按迁移顺序替换旧程序化 UI。
