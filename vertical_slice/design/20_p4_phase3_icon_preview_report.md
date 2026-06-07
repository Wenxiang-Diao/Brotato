# P4 阶段 3：首批正式图标预览报告

## 1. 当前状态

阶段 3 第一批图标预览板已完成，等待用户检查。

本轮已生成预览并拆分为独立待审核图标，但不替换 Figma 组件占位符，
不修改 Godot 运行时代码。独立文件仍属于预览资产，不是最终接入资源。

## 2. 图标清单

### 武器

1. 弹壳手枪
2. 磁暴硬币
3. 冻流水晶
4. 裂纹板砖

### 基础状态

5. 标记
6. 感电
7. 冻结
8. 灼烧

### 元素反应与技能

9. 雷链
10. 破碎
11. 热冲击
12. 星辉回路

### 通用 UI

13. 生命
14. 经验
15. 重抽
16. 暂停/设置

### 负面状态

17. 重心偏移
18. 防线空洞
19. 急促脉冲
20. 星屑漏损
21. 冻结迟钝
22. 裂隙回声

## 3. 视觉规则

- 正视或轻微 3/4 视角。
- 统一深色粗轮廓。
- 晶体切面、金属和能量材质。
- 使用青、金、电蓝、冰蓝、橙红和诅咒紫的既有色彩体系。
- 颜色与轮廓形状共同表达含义。
- 避免大面积模糊霓虹、写实枪械和复杂背景。
- 目标是在 32×32 状态位和 56×56 武器槽中保持可识别性。

## 4. 文件

- 透明预览源：
  `vertical_slice/art/p4_phase3_preview/icon_preview_board_v1.png`
- 色键生成源：
  `vertical_slice/art/p4_phase3_preview/icon_preview_board_chromakey_v1.png`
- 中文编号审核板：
  `vertical_slice/art/p4_phase3_preview/icon_preview_review_v1.jpg`
- 独立图标预览文件夹：
  `vertical_slice/art/p4_phase3_icons_preview/`
- 基于 22 个独立 PNG 重新拼装的总览图：
  `vertical_slice/art/p4_phase3_icons_preview/icon_overview_v1.png`
- 独立图标清单：
  `vertical_slice/art/p4_phase3_icons_preview/manifest.json`
- 审核板生成工具：
  `vertical_slice/tools/create_icon_preview_review.py`
- 图标拆分与总览工具：
  `vertical_slice/tools/split_icon_preview.py`
- Figma 页面：`10 Icon Preview`
- Figma 节点：
  <https://www.figma.com/design/kodk8k0rH7pvYLbTujVJgF?node-id=74-2>

## 5. 审核门槛

用户需要按编号确认：

- 可以保留的图标。
- 需要重做的图标。
- 需要调整的颜色、轮廓、透视或语义。

22 个独立 PNG 已生成供逐个检查。只有用户明确确认后，才允许将其
转入最终资源目录、替换 Figma 占位符，并进入 Godot UI 组件实现与图标接入。

## 6. 独立文件校验

- 数量：22。
- 尺寸：全部为 256×256。
- 格式：全部为 RGBA PNG。
- 四角透明：22/22 通过。
- 空图检查：22/22 通过。
- 相邻图标污染：使用逐行透明投影寻找真实空白分界，已修复固定网格
  拆分导致的枪口截断和邻格残片问题。
