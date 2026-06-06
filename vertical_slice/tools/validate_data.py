#!/usr/bin/env python3
"""Validate the vertical slice data contracts without requiring Godot."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any


SLICE_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = SLICE_ROOT / "data"
MAIN_SCRIPT = SLICE_ROOT / "game" / "scripts" / "main.gd"

EXPECTED_COUNTS = {
    "weapons": 4,
    "enemies": 7,
    "statuses": 4,
    "reactions": 3,
    "debuffs": 6,
    "rewards": 18,
}

ATTACK_TAGS = {"heavy_hit", "area", "chain"}
VALID_ENEMY_TYPES = {"normal", "elite", "boss"}
VALID_REWARD_TYPES = {"stat", "weapon_unlock", "weapon_level", "heal"}
VALID_SEVERITIES = {"light", "medium", "heavy"}
VALID_PLAYER_STATS = {
    "max_hp",
    "speed",
    "damage_mult",
    "attack_speed_mult",
    "status_mult",
    "xp_mult",
    "spawn_mult",
    "contact_damage_mult",
    "freeze_duration_mult",
    "skill_cooldown_max",
}


class ValidationError(Exception):
    pass


def load_json(name: str) -> Any:
    path = DATA_DIR / f"{name}.json"
    if not path.exists():
        raise ValidationError(f"missing data file: {path}")
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError as exc:
        raise ValidationError(f"invalid JSON in {path}: {exc}") from exc


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def index_rows(name: str, rows: Any) -> dict[str, dict[str, Any]]:
    require(isinstance(rows, list), f"{name}.json must contain a list")
    require(
        len(rows) == EXPECTED_COUNTS[name],
        f"{name}: expected {EXPECTED_COUNTS[name]} rows, got {len(rows)}",
    )
    output: dict[str, dict[str, Any]] = {}
    for position, row in enumerate(rows):
        require(isinstance(row, dict), f"{name}[{position}] must be an object")
        row_id = row.get("id")
        require(isinstance(row_id, str) and row_id, f"{name}[{position}] has no id")
        require(row_id not in output, f"{name}: duplicate id {row_id}")
        output[row_id] = row
    return output


def validate() -> list[str]:
    messages: list[str] = []
    weapons = index_rows("weapons", load_json("weapons"))
    enemies = index_rows("enemies", load_json("enemies"))
    statuses = index_rows("statuses", load_json("statuses"))
    reactions = index_rows("reactions", load_json("reactions"))
    debuffs = index_rows("debuffs", load_json("debuffs"))
    rewards = index_rows("rewards", load_json("rewards"))
    run_config = load_json("run_config")

    for weapon_id, weapon in weapons.items():
        require(float(weapon.get("damage", 0)) > 0, f"{weapon_id}: damage must be positive")
        require(float(weapon.get("cooldown", 0)) > 0, f"{weapon_id}: cooldown must be positive")
        status_id = weapon.get("status", "")
        require(
            not status_id or status_id in statuses,
            f"{weapon_id}: unknown status {status_id}",
        )

    for enemy_id, enemy in enemies.items():
        require(enemy.get("type") in VALID_ENEMY_TYPES, f"{enemy_id}: invalid type")
        require(float(enemy.get("hp", 0)) > 0, f"{enemy_id}: hp must be positive")
        require(float(enemy.get("speed", 0)) >= 0, f"{enemy_id}: speed cannot be negative")
        require(float(enemy.get("radius", 0)) > 0, f"{enemy_id}: radius must be positive")

    for status_id, status in statuses.items():
        require(int(status.get("max_stacks", 0)) >= 1, f"{status_id}: invalid max_stacks")
        require(float(status.get("base_duration", 0)) > 0, f"{status_id}: invalid duration")

    for reaction_id, reaction in reactions.items():
        requirements = reaction.get("requirements", [])
        consumes = reaction.get("consumes", [])
        require(len(requirements) == 2, f"{reaction_id}: exactly two requirements required")
        for requirement in requirements:
            require(
                requirement in statuses or requirement in ATTACK_TAGS,
                f"{reaction_id}: unknown requirement {requirement}",
            )
        for status_id in consumes:
            require(status_id in statuses, f"{reaction_id}: consumes unknown status {status_id}")
        require(
            float(reaction.get("damage_multiplier", 0)) > 0,
            f"{reaction_id}: damage_multiplier must be positive",
        )
        require(
            float(reaction.get("secondary_multiplier", 0)) >= 0,
            f"{reaction_id}: secondary_multiplier cannot be negative",
        )
        require(float(reaction.get("radius", 0)) >= 0, f"{reaction_id}: radius cannot be negative")
        require(
            int(reaction.get("max_targets", 0)) >= 0,
            f"{reaction_id}: max_targets cannot be negative",
        )

    for debuff_id, debuff in debuffs.items():
        require(debuff.get("severity") in VALID_SEVERITIES, f"{debuff_id}: invalid severity")
        modifiers = debuff.get("modifiers")
        require(isinstance(modifiers, dict) and modifiers, f"{debuff_id}: modifiers required")
        for key, value in modifiers.items():
            require(key in VALID_PLAYER_STATS, f"{debuff_id}: unknown modifier stat {key}")
            require(float(value) > 0, f"{debuff_id}: modifier {key} must be positive")

    referenced_debuffs = set()
    for reward_id, reward in rewards.items():
        reward_type = reward.get("type")
        require(reward_type in VALID_REWARD_TYPES, f"{reward_id}: invalid reward type")
        debuff_id = reward.get("debuff_id", "")
        require(not debuff_id or debuff_id in debuffs, f"{reward_id}: unknown debuff {debuff_id}")
        if debuff_id:
            referenced_debuffs.add(debuff_id)
        if reward_type in {"weapon_unlock", "weapon_level"}:
            require(
                reward.get("weapon_id") in weapons,
                f"{reward_id}: unknown weapon {reward.get('weapon_id')}",
            )
        if reward_type == "stat":
            require(reward.get("stat") in VALID_PLAYER_STATS, f"{reward_id}: invalid stat")
            require(float(reward.get("value", 0)) != 0, f"{reward_id}: non-zero value required")
    require(
        referenced_debuffs == set(debuffs),
        "every configured debuff must be reachable from a risk reward",
    )

    require(isinstance(run_config, dict), "run_config.json must contain an object")
    require(int(run_config.get("layer_count", 0)) == 6, "run_config: layer_count must be 6")
    layers = run_config.get("layers", [])
    require(isinstance(layers, list) and len(layers) == 6, "run_config: six layers required")
    require(
        [int(layer.get("layer", 0)) for layer in layers] == list(range(1, 7)),
        "run_config: layers must be consecutive from 1 to 6",
    )
    for layer in layers:
        kind = layer.get("kind")
        require(kind in {"normal", "elite", "boss"}, f"layer {layer['layer']}: invalid kind")
        for enemy_id in layer.get("enemy_pool", []):
            require(enemy_id in enemies, f"layer {layer['layer']}: unknown enemy {enemy_id}")
            require(
                enemies[enemy_id]["type"] == "normal",
                f"layer {layer['layer']}: enemy_pool must contain normal enemies",
            )
        boss_id = layer.get("boss")
        if boss_id:
            require(boss_id in enemies, f"layer {layer['layer']}: unknown boss {boss_id}")
        if kind == "normal":
            require(not boss_id, f"layer {layer['layer']}: normal layer cannot define boss")
        elif kind == "elite":
            require(boss_id and enemies[boss_id]["type"] == "elite", f"layer {layer['layer']}: elite required")
        elif kind == "boss":
            require(boss_id and enemies[boss_id]["type"] == "boss", f"layer {layer['layer']}: boss required")
    estimated_seconds = (
        (int(run_config["layer_count"]) - 1) * float(run_config["layer_duration_seconds"])
        + float(run_config.get("expected_boss_seconds", 0))
    )
    require(
        float(run_config["target_run_minutes_min"]) * 60
        <= estimated_seconds
        <= float(run_config["target_run_minutes_max"]) * 60,
        "estimated run duration must stay inside the configured target window",
    )

    seed = int(run_config.get("seed", -1))
    script_text = MAIN_SCRIPT.read_text(encoding="utf-8-sig")
    seed_match = re.search(r"const RUN_SEED := (\d+)", script_text)
    require(seed_match is not None, "main.gd: RUN_SEED constant not found")
    require(int(seed_match.group(1)) == seed, "run seed differs between data and code")
    require("reward_rng" in script_text and "loot_rng" in script_text, "separate RNG streams required")
    require("get_instance_id" not in script_text, "dictionary enemies cannot use get_instance_id()")

    for weapon_id in weapons:
        require(weapon_id in script_text, f"main.gd has no handler for weapon {weapon_id}")
    configured_enemy_ids = {
        enemy_id
        for layer in layers
        for enemy_id in [*layer.get("enemy_pool", []), layer.get("boss")]
        if enemy_id
    }
    require(
        configured_enemy_ids == set(enemies),
        "run_config must reference every configured enemy exactly as part of the slice",
    )

    messages.append(
        "validated "
        + ", ".join(f"{name}={count}" for name, count in EXPECTED_COUNTS.items())
    )
    messages.append(f"validated layers=6, fixed_seed={seed}")
    messages.append("all cross-file references are valid")
    return messages


def main() -> int:
    try:
        for message in validate():
            print(f"OK: {message}")
    except (ValidationError, OSError, ValueError, TypeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
