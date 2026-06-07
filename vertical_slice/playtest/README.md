# 真人玩法验证材料

本目录用于执行 P1 真人 A/B 试玩。

## 文件说明

- `playtest_protocol.md`：测试主持流程和数据收集步骤。
- `questionnaire.md`：每名测试者试玩后的问卷。
- `session_log_template.csv`：人工记录表模板。
- `tester_profile_template.csv`：测试者背景信息模板。
- `jsonl_collection_guide.md`：Godot JSONL 数据收集和备份说明。

## 推荐流程

1. 修复 `6_8_TODO_LIST.md` 中 P0 数据可信度问题。
2. 为每名测试者分配编号，例如 `T01`、`T02`。
3. 按 `playtest_protocol.md` 执行标准模式和风险模式试玩。
4. 每局结束后备份 `user://vertical_slice_runs.jsonl`。
5. 在 `session_log_template.csv` 中记录人工观察。
6. 让测试者填写 `questionnaire.md`。
7. 使用 `tools/analyze_playtest.py` 汇总 JSONL 与人工表格。

## 推荐命令

```powershell
python vertical_slice/tools/analyze_playtest.py path\to\vertical_slice_runs.jsonl --session-log vertical_slice/playtest/session_log_template.csv --out-dir vertical_slice/playtest/output
```

