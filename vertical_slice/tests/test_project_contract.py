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
        script = (SLICE_ROOT / "game" / "scripts" / "main.gd").read_text(
            encoding="utf-8"
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
            self.assertIn(token, script)
        self.assertNotIn("get_instance_id()", script)

    def test_runtime_regressions_are_guarded(self):
        script = (SLICE_ROOT / "game" / "scripts" / "main.gd").read_text(
            encoding="utf-8"
        )
        self.assertIn("pending_reward_levels", script)
        self.assertIn("active_debuffs.has(debuff_id)", script)
        self.assertIn("already_scaled := false", script)
        self.assertIn("MAX_ENEMIES := 150", script)
        self.assertIn("MAX_PROJECTILES := 100", script)
        self.assertIn("MAX_ACTIVE_DEBUFFS := 5", script)
        self.assertIn("risk_rewards_offered", script)
        self.assertIn("risk_rewards_chosen", script)

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
