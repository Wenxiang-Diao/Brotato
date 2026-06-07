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
            for path in (SLICE_ROOT / "game").rglob("*.gd")
        )
        for token in (
            "start_requested.connect(_start_run)",
            "start_requested.emit(false)",
            "start_requested.emit(true)",
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

    def test_p4_control_ui_and_approved_icons_exist(self):
        ui_root = SLICE_ROOT / "game" / "ui"
        for path in (
            ui_root / "ui_root.tscn",
            ui_root / "ui_root.gd",
            ui_root / "input_device_manager.gd",
            ui_root / "theme" / "ui_tokens.gd",
            SLICE_ROOT / "tests" / "ui_runtime_test.gd",
        ):
            self.assertTrue(path.exists(), path)

        icons = list((SLICE_ROOT / "assets" / "ui" / "icons").glob("*.png"))
        self.assertEqual(22, len(icons))
        self.assertTrue((SLICE_ROOT / "assets" / "fonts" / "NotoSansSC-VF.ttf").exists())

        main_scene = (SLICE_ROOT / "game" / "main.tscn").read_text(encoding="utf-8")
        main_script = (SLICE_ROOT / "game" / "scripts" / "main.gd").read_text(
            encoding="utf-8"
        )
        ui_script = (ui_root / "ui_root.gd").read_text(encoding="utf-8")
        self.assertIn('res://game/ui/ui_root.tscn', main_scene)
        self.assertIn("ui_root.bind_game(self)", main_script)
        for layer in ("HUD", "ScreenStack", "ModalStack", "ToastLayer", "DebugLayer"):
            self.assertIn(f'_full_control("{layer}")', ui_script)
        for action in ("ui_reroll", "ui_details", "ui_pause"):
            self.assertIn(action, ui_script)
        self.assertIn("NotoSansSC-VF.ttf", ui_script + main_script)
        self.assertIn("reward_confirm_button", ui_script)
        self.assertIn("pause_requested", ui_script + main_script)
        self.assertNotIn("P1 试玩就绪版", main_script)


if __name__ == "__main__":
    unittest.main()
