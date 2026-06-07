#!/usr/bin/env python3
"""Create CSV and Markdown summaries for vertical slice playtest JSONL."""

from __future__ import annotations

import argparse
import csv
import json
import statistics
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


def average(values: list[float]) -> float:
    return round(statistics.fmean(values), 2) if values else 0.0


def percent(numerator: int, denominator: int) -> float:
    return round((numerator / denominator) * 100.0, 1) if denominator else 0.0


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for line_number, line in enumerate(path.read_text("utf-8-sig").splitlines(), 1):
        if not line.strip():
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError as exc:
            raise ValueError(f"{path}: invalid JSON on line {line_number}: {exc}") from exc
        row["_source_file"] = path.name
        row["_source_line"] = line_number
        rows.append(row)
    return rows


def read_session_log(path: Path | None) -> list[dict[str, str]]:
    if path is None:
        return []
    if not path.exists():
        raise FileNotFoundError(path)
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def write_csv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def flatten_run(row: dict[str, Any]) -> dict[str, Any]:
    reactions = row.get("reactions", {}) or {}
    weapons = row.get("weapons", {}) or {}
    return {
        "source_file": row.get("_source_file", ""),
        "source_line": row.get("_source_line", ""),
        "schema_version": row.get("schema_version", ""),
		"mode": row.get("mode", ""),
		"result": row.get("result", ""),
		"exit_context": row.get("exit_context", ""),
		"debug_used": row.get("debug_used", False),
		"duration_seconds": round(float(row.get("duration_seconds", 0.0)), 2),
		"layer_reached": row.get("layer_reached", ""),
		"level_reached": row.get("level_reached", ""),
		"hp_at_end": round(float(row.get("hp_at_end", 0.0)), 2),
		"max_hp_at_end": round(float(row.get("max_hp_at_end", 0.0)), 2),
		"kills": row.get("kills", 0),
        "damage_dealt": round(float(row.get("damage_dealt", 0.0)), 2),
        "damage_taken": round(float(row.get("damage_taken", 0.0)), 2),
        "lightning_chain": reactions.get("lightning_chain", 0),
        "shatter": reactions.get("shatter", 0),
        "thermal_shock": reactions.get("thermal_shock", 0),
        "risk_rewards_offered": row.get("risk_rewards_offered", 0),
        "risk_rewards_chosen": row.get("risk_rewards_chosen", 0),
        "rerolls_used": row.get("rerolls_used", 0),
        "debuffs_accepted": "|".join(row.get("debuffs_accepted", [])),
        "corrections": "|".join(row.get("corrections", [])),
        "active_debuffs": "|".join(row.get("active_debuffs", [])),
        "weapons": "|".join(f"{key}:{value}" for key, value in weapons.items()),
        "feedback_mode": row.get("feedback_mode", ""),
    }


def build_mode_summary(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    output: list[dict[str, Any]] = []
    groups: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        if not row.get("debug_used", False):
            groups[str(row.get("mode", "unknown"))].append(row)
    for mode in sorted(groups):
        group = groups[mode]
        results = Counter(str(row.get("result", "unknown")) for row in group)
        wins = results.get("victory", 0)
        risk_offered = sum(int(row.get("risk_rewards_offered", 0)) for row in group)
        risk_chosen = sum(int(row.get("risk_rewards_chosen", 0)) for row in group)
        output.append({
            "mode": mode,
            "runs": len(group),
            "victories": wins,
            "win_rate_percent": percent(wins, len(group)),
            "results": json.dumps(dict(results), ensure_ascii=False),
            "avg_duration_seconds": average([float(row.get("duration_seconds", 0.0)) for row in group]),
            "avg_layer_reached": average([float(row.get("layer_reached", 0.0)) for row in group]),
            "avg_level_reached": average([float(row.get("level_reached", 0.0)) for row in group]),
            "avg_damage_taken": average([float(row.get("damage_taken", 0.0)) for row in group]),
            "risk_rewards_offered": risk_offered,
            "risk_rewards_chosen": risk_chosen,
            "risk_acceptance_percent": percent(risk_chosen, risk_offered),
        })
    return output


def build_reaction_summary(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    output: list[dict[str, Any]] = []
    groups: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        if not row.get("debug_used", False):
            groups[str(row.get("mode", "unknown"))].append(row)
    for mode in sorted(groups):
        totals = Counter()
        for row in groups[mode]:
            totals.update(row.get("reactions", {}) or {})
        for reaction in ("lightning_chain", "shatter", "thermal_shock"):
            output.append({
                "mode": mode,
                "reaction": reaction,
                "total": totals.get(reaction, 0),
                "avg_per_run": average([float((row.get("reactions", {}) or {}).get(reaction, 0)) for row in groups[mode]]),
            })
    return output


def build_debuff_summary(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    accepted = Counter()
    active_at_end = Counter()
    for row in rows:
        if row.get("debug_used", False):
            continue
        accepted.update(row.get("debuffs_accepted", []))
        active_at_end.update(row.get("active_debuffs", []))
    keys = sorted(set(accepted) | set(active_at_end))
    return [
        {
            "debuff_id": key,
            "accepted_count": accepted.get(key, 0),
            "active_at_end_count": active_at_end.get(key, 0),
        }
        for key in keys
    ]


def write_report(path: Path, rows: list[dict[str, Any]], mode_summary: list[dict[str, Any]], session_rows: list[dict[str, str]]) -> None:
    non_debug = [row for row in rows if not row.get("debug_used", False)]
    debug_count = len(rows) - len(non_debug)
    lines: list[str] = [
        "# Playtest Report",
        "",
        f"- Total JSONL runs: {len(rows)}",
        f"- Non-debug runs: {len(non_debug)}",
        f"- Debug excluded: {debug_count}",
        f"- Manual session rows: {len(session_rows)}",
        "",
        "## Mode Summary",
        "",
        "| Mode | Runs | Win Rate | Avg Duration | Avg Layer | Avg Level | Risk Acceptance |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for row in mode_summary:
        lines.append(
            "| {mode} | {runs} | {win_rate_percent}% | {avg_duration_seconds}s | {avg_layer_reached} | {avg_level_reached} | {risk_acceptance_percent}% |".format(**row)
        )
    lines.extend([
        "",
        "## Review Questions",
        "",
        "- Did at least 60% of testers want another run?",
        "- Did most testers understand at least two reactions?",
        "- Was risk acceptance high enough to suggest real strategy?",
        "- Were abandoned runs caused by confusion, difficulty, boredom, or UI mistakes?",
        "- Did standard and risk modes produce meaningfully different behavior?",
        "",
    ])
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("jsonl", nargs="+", type=Path, help="One or more vertical_slice_runs.jsonl files")
    parser.add_argument("--session-log", type=Path, default=None, help="Optional manual session CSV")
    parser.add_argument("--out-dir", type=Path, default=Path("playtest_output"), help="Directory for CSV and Markdown output")
    args = parser.parse_args()

    rows: list[dict[str, Any]] = []
    for path in args.jsonl:
        rows.extend(read_jsonl(path))
    session_rows = read_session_log(args.session_log)

    detail_rows = [flatten_run(row) for row in rows]
    mode_summary = build_mode_summary(rows)
    reaction_summary = build_reaction_summary(rows)
    debuff_summary = build_debuff_summary(rows)

    out_dir: Path = args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)
    write_csv(out_dir / "runs_detail.csv", detail_rows, list(detail_rows[0].keys()) if detail_rows else ["source_file"])
    write_csv(out_dir / "mode_summary.csv", mode_summary, list(mode_summary[0].keys()) if mode_summary else ["mode"])
    write_csv(out_dir / "reaction_summary.csv", reaction_summary, list(reaction_summary[0].keys()) if reaction_summary else ["mode", "reaction"])
    write_csv(out_dir / "debuff_summary.csv", debuff_summary, list(debuff_summary[0].keys()) if debuff_summary else ["debuff_id"])
    write_report(out_dir / "playtest_report.md", rows, mode_summary, session_rows)

    print(f"OK: wrote playtest analysis to {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
