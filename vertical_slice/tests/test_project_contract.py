import json
import unittest
from pathlib import Path


SLICE_ROOT = Path(__file__).resolve().parents[1]


class ProjectContractTest(unittest.TestCase):
    def test_project_entrypoint_exists(self):
        project = (SLICE_ROOT / "project.godot").read_text(encoding="utf-8")
        self.assertIn('run/main_scene="res://game/main.tscn"', project)
        for action in ("move_left", "move_right", "move_up", "move_down", "active_skill"):
            self.assertIn(action, project)
        self.assertTrue((SLICE_ROOT / "game" / "main.tscn").exists())
        self.assertTrue((SLICE_ROOT / "game" / "scripts" / "main.gd").exists())

    def test_two_validation_modes_and_metrics_exist(self):
        scripts = "\n".join(
            path.read_text(encoding="utf-8")
            for path in (SLICE_ROOT / "game" / "scripts").rglob("*.gd")
        )
        for token in (
            "_start_run(false)",
            "_start_run(true)",
            "vertical_slice_runs.jsonl",
            "lightning_chain",
            "shatter",
            "thermal_shock",
            "reward_rng",
            "loot_rng",
        ):
            self.assertIn(token, scripts)
        self.assertNotIn("get_instance_id()", scripts)

    def test_runtime_regressions_are_guarded(self):
        scripts = "\n".join(
            path.read_text(encoding="utf-8")
            for path in (SLICE_ROOT / "game" / "scripts").rglob("*.gd")
        )
        self.assertIn("pending_reward_levels", scripts)
        self.assertIn("active_debuffs.has(debuff_id)", scripts)
        self.assertIn("already_scaled := false", scripts)
        self.assertIn("MAX_ENEMIES := 150", scripts)
        self.assertIn("MAX_PROJECTILES := 100", scripts)
        self.assertIn("MAX_ACTIVE_DEBUFFS := 5", scripts)
        self.assertIn("risk_rewards_offered", scripts)
        self.assertIn("risk_rewards_chosen", scripts)

    def test_p2_core_modules_exist(self):
        core = SLICE_ROOT / "game" / "scripts" / "core"
        expected = {
            "slice_data_repository.gd",
            "run_metrics_recorder.gd",
            "reward_service.gd",
            "combat_rules.gd",
            "entity_factory.gd",
            "progression_service.gd",
            "targeting_service.gd",
            "combat_event_hub.gd",
            "combat_feedback.gd",
        }
        self.assertEqual(expected, {path.name for path in core.glob("*.gd")})
        main_script = (SLICE_ROOT / "game" / "scripts" / "main.gd").read_text(
            encoding="utf-8"
        )
        for module in expected:
            self.assertIn(f"core/{module}", main_script)
        self.assertNotIn("FileAccess.open", main_script)
        self.assertNotIn("JSON.parse", main_script)
        self.assertNotIn("func _load_json(", main_script)

    def test_slice_counts_match_scope(self):
        expected = {
            "weapons": 4,
            "enemies": 7,
            "statuses": 4,
            "reactions": 3,
            "debuffs": 6,
            "rewards": 18,
        }
        for name, count in expected.items():
            rows = json.loads((SLICE_ROOT / "data" / f"{name}.json").read_text("utf-8"))
            self.assertEqual(count, len(rows), name)

    def test_selected_source_snapshot_is_complete(self):
        selected = list((SLICE_ROOT / "selected_sources").rglob("*.md"))
        self.assertEqual(12, len(selected))


if __name__ == "__main__":
    unittest.main()
