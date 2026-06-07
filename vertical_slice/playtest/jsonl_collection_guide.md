# JSONL 数据收集说明

## 1. 为什么保留 JSONL

本项目应该继续使用 JSONL 作为机器记录源。

理由：

- 每局一行，追加写入，不容易破坏旧数据。
- 字段可以逐步增加，适合原型阶段。
- Python 可以直接汇总。
- 后续也可以转换成 CSV 给表格软件查看。

CSV 更适合人工记录和最终分析视图，不适合作为 Godot 运行时原始日志。

推荐结构：

- Godot 自动输出：`vertical_slice_runs.jsonl`
- 主持人人工记录：`session_log_template.csv`
- 测试者背景：`tester_profile_template.csv`
- 汇总输出：由 `tools/analyze_playtest.py` 生成 CSV 和 Markdown

## 2. Godot 的 JSONL 文件位置

游戏写入路径为：

```text
user://vertical_slice_runs.jsonl
```

在 Windows 上通常位于 Godot 用户数据目录。不同 Godot 版本和项目名可能略有差异。

最快确认方法：

1. 运行一局游戏并结束。
2. 结算页确认没有“数据保存失败”。
3. 在系统中搜索 `vertical_slice_runs.jsonl`。
4. 每次测试结束后复制一份到测试资料目录。

建议备份命名：

```text
playtest_runs_2026-06-08_T01.jsonl
playtest_runs_2026-06-08_T02.jsonl
playtest_runs_2026-06-08_all.jsonl
```

## 3. 每局结束后的检查

每局结束后确认：

- JSONL 文件新增了一行。
- `mode` 是 `standard` 或 `risk`。
- `result` 是胜利、死亡或中途退出类型。
- `debug_used` 为 `false`。
- `duration_seconds` 大于 0。
- `layer_reached` 与玩家实际进度一致。

## 4. 多名测试者的数据合并

JSONL 可以直接把多个文件拼接到一起，但注意不要混入空行或手动编辑坏 JSON。

PowerShell 示例：

```powershell
Get-Content playtest_runs_*.jsonl | Set-Content playtest_runs_all.jsonl
```

如果担心编码问题，也可以直接把每名测试者的 JSONL 分别传给分析脚本，后续再合并 CSV。

## 5. 推荐分析命令

```powershell
python vertical_slice/tools/analyze_playtest.py playtest_runs_all.jsonl --session-log vertical_slice/playtest/session_log_template.csv --out-dir vertical_slice/playtest/output
```

输出：

- `runs_detail.csv`：每局机器数据明细。
- `mode_summary.csv`：按模式聚合。
- `reaction_summary.csv`：反应触发统计。
- `debuff_summary.csv`：Debuff 接受统计。
- `playtest_report.md`：可直接阅读的测试报告。

## 6. 人工表格为什么仍然需要

JSONL 只能说明发生了什么，不能说明玩家为什么这么做。

人工表格用于记录：

- 玩家是否困惑。
- 是否误操作。
- 死亡主因。
- 是否主动想再玩。
- 帧率和可读性的主观感受。

最终判断必须同时看 JSONL 和问卷，不要只看通关率。

