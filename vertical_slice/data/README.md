# 数据目录

该目录是垂直切片的游戏配置唯一来源。

| 文件 | 内容 |
|---|---|
| `weapons.json` | 4 把武器的基础数值与状态 |
| `enemies.json` | 5 普通怪、1 精英、1 Boss |
| `statuses.json` | 4 个战斗状态 |
| `reactions.json` | 3 个状态反应 |
| `rewards.json` | 18 个升级奖励 |
| `debuffs.json` | 6 个风险效果 |
| `run_config.json` | 固定种子、层数和敌人池 |

修改配置后必须运行：

```powershell
python vertical_slice/tools/validate_data.py
python -m unittest vertical_slice/tests/test_data.py
```

