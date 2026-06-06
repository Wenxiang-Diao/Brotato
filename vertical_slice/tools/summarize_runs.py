#!/usr/bin/env python3
"""Summarize JSONL metrics exported by the Godot vertical slice."""

from __future__ import annotations

import json
import statistics
import sys
from collections import Counter, defaultdict
from pathlib import Path


def average(values):
    return round(statistics.fmean(values), 2) if values else 0.0


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: python summarize_runs.py <vertical_slice_runs.jsonl>")
        return 2
    path = Path(sys.argv[1])
    if not path.exists():
        print(f"ERROR: file not found: {path}", file=sys.stderr)
        return 1

    groups = defaultdict(list)
    for line_number, line in enumerate(path.read_text("utf-8-sig").splitlines(), 1):
        if not line.strip():
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError as exc:
            print(f"ERROR: invalid JSON on line {line_number}: {exc}", file=sys.stderr)
            return 1
        groups[row["mode"]].append(row)

    for mode in ("standard", "risk"):
        all_rows = groups.get(mode, [])
        rows = [row for row in all_rows if not row.get("debug_used", False)]
        print(f"\n[{mode}] runs={len(rows)}, debug_excluded={len(all_rows) - len(rows)}")
        if not rows:
            continue
        results = Counter(row["result"] for row in rows)
        print(f"results={dict(results)}")
        print(f"avg_duration_seconds={average([row['duration_seconds'] for row in rows])}")
        print(f"avg_level={average([row['level_reached'] for row in rows])}")
        print(f"avg_damage_taken={average([row['damage_taken'] for row in rows])}")
        reaction_totals = Counter()
        for row in rows:
            reaction_totals.update(row.get("reactions", {}))
        print(f"reaction_totals={dict(reaction_totals)}")
        if mode == "risk":
            accepted = sum(len(row.get("debuffs_accepted", [])) for row in rows)
            corrections = sum(len(row.get("corrections", [])) for row in rows)
            offered = sum(int(row.get("risk_rewards_offered", 0)) for row in rows)
            chosen = sum(int(row.get("risk_rewards_chosen", 0)) for row in rows)
            print(f"debuffs_accepted={accepted}")
            print(f"corrections_used={corrections}")
            print(f"risk_reward_offer_screens={offered}")
            print(f"risk_rewards_chosen={chosen}")
            print(f"risk_acceptance_rate={round(chosen / offered, 3) if offered else 0.0}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
