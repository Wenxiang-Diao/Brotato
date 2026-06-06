# 《星链回响》开发与美术制作规范 v1.0

> 适用范围：本规范用于《星链回响》项目的 MVP 阶段开发、美术资源制作、代码组织、文件命名和数据配置。
>
> 核心原则：本项目优先采用 **2D / 2.5D 表现方式**，不做重度 3D 建模；角色、武器、怪物、场景主要使用 2D Sprite、Tilemap、UI 图片和粒子特效实现。

---

## 1. 总体技术路线

| 项目 | 统一选择 |
|---|---|
| 游戏类型 | 2D / 2.5D 动作生存 Roguelite |
| 推荐引擎 | Godot 4.x |
| 编程语言 | GDScript |
| 数据配置 | CSV / JSON |
| 文档格式 | Markdown |
| 美术风格 | Q版二次元 2D |
| 动画方式 | Sprite Sheet 帧动画为主，Spine 骨骼动画可选 |
| 场景方式 | 2D Tilemap + 背景图 + 粒子特效 |
| 版本管理 | GitHub + Git LFS |

---

## 2. 必须使用的软件清单

### 2.1 核心开发软件

| 软件 | 用途 | 是否必须 |
|---|---|---|
| Godot 4.x | 游戏开发引擎 | 必须 |
| VS Code | 写代码、编辑配置文件 | 必须 |
| Git | 本地版本管理 | 必须 |
| GitHub Desktop / Git 命令行 | 上传、同步仓库 | 必须 |
| Git LFS | 管理图片、音频、大资源 | 必须 |
| Excel / Google Sheets | 配置武器、角色、怪物、抽奖表 | 必须 |

### 2.2 美术软件

| 软件 | 用途 | 是否必须 |
|---|---|---|
| Aseprite | 角色小人、武器图标、怪物、Sprite 动画 | 强烈推荐 |
| Krita | 角色立绘、背景图、事件插画 | 推荐 |
| Figma | UI、节点路线、抽奖界面、商店界面 | 必须 |
| Photopea / Photoshop | 修图、抠图、导出 PNG | 可选 |
| Spine 2D | 高质量骨骼动画 | 可选 |
| Blender | 仅用于宣传图或 2.5D 辅助，不作为主流程 | 可选 |

### 2.3 音频软件

| 软件 | 用途 |
|---|---|
| Audacity | 音效剪辑 |
| Bfxr / ChipTone | 简单音效生成 |
| Reaper | 音乐、复杂音效编辑，可选 |

---

## 3. 各美术部分制作规范

## 3.1 角色

### 是否需要建模

不需要 3D 建模。

角色使用：

```text
2D Q版 Sprite
+
Sprite Sheet 帧动画
+
技能粒子特效
```

### 使用软件与制作方式

| 内容 | 软件 | 方式 |
|---|---|---|
| 角色头像 | Krita / Photoshop | 画 2D 头像 |
| 角色战斗小人 | Aseprite | 画 Q版 Sprite |
| 移动动画 | Aseprite | Sprite Sheet 帧动画 |
| 攻击动画 | Aseprite | Sprite Sheet 帧动画 |
| 技能动画 | Aseprite + Godot 粒子 | 角色动作 + 特效 |
| 终极技能 | Godot 粒子系统 | 主要靠特效表现 |
| 高级角色动画 | Spine | 可选，不是 MVP 必须 |

### 最低动画要求

每个角色至少需要：

```text
idle      站立
run       移动
attack    攻击
hurt      受击
death     死亡
skill     主动技能
```

### 推荐文件命名

```text
char_001_idle.png
char_001_run.png
char_001_attack.png
char_001_hurt.png
char_001_death.png
char_001_skill.png
char_001_portrait.png
```

---

## 3.2 武器

### 是否需要建模

不需要 3D 建模。

武器使用：

```text
2D 图标
+
2D 弹道贴图
+
命中特效
+
元素粒子
```

### 使用软件与制作方式

| 内容 | 软件 | 方式 |
|---|---|---|
| 武器图标 | Aseprite / Krita | PNG 图标 |
| 武器弹道 | Aseprite | Sprite / Sprite Sheet |
| 命中特效 | Aseprite + Godot 粒子 | 帧动画或粒子 |
| 元素附着效果 | Godot 粒子系统 | 火、冰、电、毒、结晶 |
| 稀有度边框 | Figma / Aseprite | UI 边框图 |

### 推荐文件命名

```text
weapon_001_icon.png
weapon_001_projectile.png
weapon_001_hit.png
weapon_001_vfx.png
```

示例：

```text
weapon_brick_icon.png
weapon_coin_projectile.png
weapon_fire_staff_icon.png
weapon_poison_bottle_hit.png
```

---

## 3.3 怪物

### 是否需要建模

不需要 3D 建模。

怪物使用：

```text
2D Sprite
+
简单帧动画
+
状态特效覆盖
```

### 使用软件与制作方式

| 内容 | 软件 | 方式 |
|---|---|---|
| 普通怪物 | Aseprite | 小型 Sprite |
| 精英怪物 | Aseprite | 普通怪变体、换色、加特效 |
| Boss | Krita / Aseprite / Spine | 大体型 2D 图或骨骼动画 |
| 怪物状态表现 | Godot 粒子 | 燃烧、中毒、冻结、感电 |

### 推荐文件命名

```text
enemy_001_idle.png
enemy_001_run.png
enemy_001_attack.png
enemy_001_death.png
enemy_001_elite.png
boss_001_idle.png
boss_001_attack.png
```

---

## 3.4 场景 / 背景

### 是否需要建模

MVP 阶段不需要 3D 建模。

场景使用：

```text
2D Tilemap
+
背景图
+
障碍物 Sprite
+
环境粒子
```

### 使用软件与制作方式

| 内容 | 软件 | 方式 |
|---|---|---|
| 地砖 | Aseprite / Krita | Tilemap |
| 背景图 | Krita | 2D 背景 |
| 障碍物 | Aseprite / Krita | 石头、树、水晶、废墟 |
| 商店背景 | Krita / Figma | 插画或 UI 场景 |
| 事件背景 | Krita | 插画 |
| 节点地图 | Figma | 路线图 UI |
| 环境特效 | Godot 粒子 | 星光、雾、火花、水晶光 |

### 推荐文件命名

```text
map_forest_tileset.png
map_crystal_tileset.png
bg_forest_001.png
bg_shop_001.png
bg_event_001.png
prop_tree_001.png
prop_crystal_001.png
```

---

## 3.5 UI

### 是否需要建模

不需要建模。

UI 使用：

```text
Figma 设计
+
PNG / SVG 导出
+
Godot UI 实现
```

### 使用软件与制作方式

| 内容 | 软件 | 方式 |
|---|---|---|
| 主菜单 | Figma | UI 原型 |
| 角色选择 | Figma | 页面布局 |
| 抽奖三选一 | Figma | 卡牌 UI |
| 商店界面 | Figma | 商品栏、价格、按钮 |
| 状态图标 | Aseprite / Figma | 小图标 |
| 节点路线 | Figma | 路线图界面 |
| 水晶树 | Figma | 技能树 UI |

### 推荐文件命名

```text
ui_button_default.png
ui_button_hover.png
ui_card_common.png
ui_card_rare.png
ui_icon_burn.png
ui_icon_poison.png
ui_icon_freeze.png
ui_node_battle.png
ui_node_shop.png
ui_node_boss.png
```

---

## 3.6 特效 VFX

### 是否需要建模

不需要建模。

特效主要用：

```text
Godot 粒子系统
+
少量 Aseprite 帧动画
+
透明 PNG 贴图
```

### 使用软件与制作方式

| 内容 | 软件 | 方式 |
|---|---|---|
| 火焰 | Godot GPUParticles2D | 粒子 |
| 冰冻 | Godot Shader / 粒子 | 冰晶、减速圈 |
| 感电 | Godot Line2D / 粒子 | 电弧连锁 |
| 中毒 | Godot 粒子 | 毒雾 |
| 爆炸 | Aseprite / Godot 粒子 | 帧动画或粒子 |
| 结晶 | Aseprite + 粒子 | 晶体碎片 |

### 推荐文件命名

```text
vfx_fire_burst.png
vfx_ice_shard.png
vfx_poison_cloud.png
vfx_shock_arc.png
vfx_crystal_break.png
vfx_explosion_001.png
```

---

## 4. 代码语言与格式规范

## 4.1 推荐语言

| 部分 | 语言 / 格式 |
|---|---|
| Godot 游戏逻辑 | GDScript |
| 数据配置 | CSV / JSON |
| 工具脚本 | Python，可选 |
| 文档 | Markdown |
| 表格 | CSV / XLSX |

---

## 4.2 GDScript 命名规范

| 类型 | 命名方式 | 示例 |
|---|---|---|
| 文件名 | snake_case | `player_controller.gd` |
| 变量名 | snake_case | `move_speed` |
| 函数名 | snake_case | `apply_damage()` |
| 类名 | PascalCase | `PlayerController` |
| 常量 | UPPER_SNAKE_CASE | `MAX_STATUS_STACK` |
| 信号 | snake_case | `health_changed` |
| 节点名 | PascalCase | `PlayerBody` |
| 场景文件 | snake_case | `player_scene.tscn` |

---

## 4.3 GDScript 示例格式

```gdscript
class_name PlayerController
extends CharacterBody2D

const MAX_MOVE_SPEED := 320.0

@export var move_speed: float = 240.0
@export var max_health: int = 100

var current_health: int = 100
var is_dead: bool = false

signal health_changed(current_health: int, max_health: int)
signal player_died

func _ready() -> void:
    current_health = max_health


func _physics_process(delta: float) -> void:
    if is_dead:
        return

    var input_vector := Input.get_vector(
        "move_left",
        "move_right",
        "move_up",
        "move_down"
    )

    velocity = input_vector * move_speed
    move_and_slide()


func apply_damage(amount: int) -> void:
    if is_dead:
        return

    current_health = max(current_health - amount, 0)
    health_changed.emit(current_health, max_health)

    if current_health <= 0:
        die()


func die() -> void:
    is_dead = true
    player_died.emit()
```

---

## 5. 数据表格式规范

所有策划数据建议放在 `data/` 目录下，用 CSV 或 JSON。

---

## 5.1 武器表

文件名：

```text
data/weapons.csv
```

字段建议：

```text
weapon_id
weapon_name
weapon_type
attack_type
rarity
base_damage
attack_speed
attack_range
status_1
status_2
status_3
trigger_condition
trigger_effect
build_type
description
```

示例：

```csv
weapon_id,weapon_name,weapon_type,attack_type,rarity,base_damage,attack_speed,attack_range,status_1,status_2,status_3,trigger_condition,trigger_effect,build_type,description
weapon_001,板砖,physical,melee,blue,12,1.2,80,stun,,,,hit_enemy,bonus_damage_to_frozen,control,对冻结敌人造成额外伤害
```

---

## 5.2 角色表

文件名：

```text
data/characters.csv
```

字段建议：

```text
character_id
character_name
max_health
move_speed
element_affinity
passive_skill
active_skill
ultimate_skill
weapon_limit
unlock_condition
description
```

---

## 5.3 状态表

文件名：

```text
data/statuses.csv
```

字段建议：

```text
status_id
status_name
status_type
max_stack
duration
tick_interval
base_value
can_stack
description
```

---

## 5.4 状态反应表

文件名：

```text
data/status_reactions.csv
```

字段建议：

```text
reaction_id
status_a
status_b
status_c
reaction_name
effect_type
effect_value
cooldown
description
```

---

## 5.5 怪物表

文件名：

```text
data/enemies.csv
```

字段建议：

```text
enemy_id
enemy_name
enemy_type
max_health
move_speed
attack_damage
attack_range
status_resistance
drop_exp
drop_resource
description
```

---

## 5.6 抽奖表

文件名：

```text
data/loot_pool.csv
```

字段建议：

```text
loot_id
loot_name
loot_type
rarity
weight
required_level
required_condition
effect_id
description
```

---

## 6. 项目目录规范

推荐 GitHub 仓库结构：

```text
Brotato/
├── README.md
├── docs/
│   ├── gdd_overview.md
│   ├── character_design.md
│   ├── weapon_design.md
│   ├── status_system.md
│   ├── enemy_design.md
│   ├── node_map_system.md
│   └── reward_system.md
│
├── game/
│   └── echoes_of_astra/
│       ├── project.godot
│       ├── scenes/
│       ├── scripts/
│       ├── assets/
│       └── data/
│
├── data/
│   ├── characters.csv
│   ├── weapons.csv
│   ├── statuses.csv
│   ├── status_reactions.csv
│   ├── enemies.csv
│   ├── loot_pool.csv
│   ├── crystal_tree.csv
│   └── node_events.csv
│
├── assets/
│   ├── characters/
│   ├── weapons/
│   ├── enemies/
│   ├── maps/
│   ├── ui/
│   ├── vfx/
│   └── audio/
│
└── tools/
    └── data_validator.py
```

---

## 7. 资源文件命名总规范

### 7.1 通用规则

统一使用：

```text
小写英文
+
下划线
+
编号
+
类型后缀
```

禁止使用：

```text
中文文件名
空格
特殊符号
随意缩写
```

### 7.2 正确示例

```text
char_001_idle.png
weapon_003_icon.png
enemy_002_run.png
map_forest_tileset.png
ui_card_rare.png
vfx_fire_burst.png
bg_shop_001.png
audio_hit_light_001.wav
```

### 7.3 错误示例

```text
角色1站立.png
Weapon Icon Final.png
火焰爆炸!!.png
新建文件夹/未命名.png
```

---

## 8. 图片与音频导出格式规范

| 类型 | 格式 | 要求 |
|---|---|---|
| 角色 Sprite | PNG | 透明背景 |
| 武器图标 | PNG | 透明背景 |
| 弹道贴图 | PNG | 透明背景 |
| UI 按钮 | PNG / SVG | 透明背景 |
| 背景图 | PNG / JPG | 不需要透明 |
| Tilemap | PNG | 统一格子尺寸 |
| 粒子贴图 | PNG | 透明背景 |
| 音效 | WAV / OGG | 游戏内推荐 OGG |
| 音乐 | OGG | 循环播放友好 |

---

## 9. Sprite 尺寸建议

### 9.1 角色

| 类型 | 推荐尺寸 |
|---|---|
| 战斗小人 | 64×64 或 96×96 |
| 角色头像 | 256×256 |
| 角色立绘 | 1024×1024 或 1024×1536 |

### 9.2 武器

| 类型 | 推荐尺寸 |
|---|---|
| 武器图标 | 64×64 或 128×128 |
| 弹道贴图 | 32×32 / 64×64 |
| 命中特效 | 128×128 |

### 9.3 怪物

| 类型 | 推荐尺寸 |
|---|---|
| 普通怪 | 64×64 |
| 精英怪 | 96×96 |
| Boss | 256×256 或更大 |

### 9.4 UI

| 类型 | 推荐尺寸 |
|---|---|
| 状态图标 | 32×32 或 64×64 |
| 卡牌图标 | 128×128 |
| 按钮 | 根据 UI 设计导出 |

---

## 10. 每个部分最终使用方式总结

| 部分 | 是否建模 | 制作方式 | 软件 | 导出 |
|---|---|---|---|---|
| 角色 | 不做 3D 建模 | 2D Sprite / 帧动画 | Aseprite / Krita | PNG / Sprite Sheet |
| 武器 | 不做 3D 建模 | 图标 + 弹道 + 特效 | Aseprite / Krita | PNG |
| 怪物 | 不做 3D 建模 | Sprite + 简单动画 | Aseprite | PNG / Sprite Sheet |
| Boss | 可选骨骼动画 | 大型 2D 图 / Spine | Krita / Spine | PNG / Spine 文件 |
| 场景 | 不做 3D 建模 | Tilemap + 背景图 | Aseprite / Krita | PNG |
| UI | 不建模 | Figma 设计 | Figma | PNG / SVG |
| 特效 | 不建模 | 粒子 + 帧动画 | Godot / Aseprite | Particle / PNG |
| 音效 | 不建模 | 剪辑 / 合成 | Audacity / Bfxr | WAV / OGG |
| 数据 | 不建模 | 表格配置 | Excel / Google Sheets | CSV / JSON |
| 代码 | 不建模 | GDScript | Godot / VS Code | `.gd` |

---

## 11. 最终推荐组合

本项目 MVP 阶段推荐组合：

```text
Godot 4.x
+
GDScript
+
Aseprite
+
Krita
+
Figma
+
Excel / Google Sheets
+
GitHub
+
Git LFS
```

---

## 12. 一句话规范

角色、武器、怪物、场景都不要先做 3D 建模；全部按 2D Sprite、Tilemap、UI 图片和粒子特效来做。代码统一用 Godot + GDScript，资源统一用 PNG / Sprite Sheet，数据统一用 CSV / JSON，文件命名统一小写英文加下划线。
