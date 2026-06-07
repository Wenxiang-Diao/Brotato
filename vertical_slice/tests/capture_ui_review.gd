extends SceneTree

const OUTPUT_DIR := "res://playtest/ui_review"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scene: PackedScene = load("res://game/main.tscn")
	var game: Node2D = scene.instantiate()
	root.add_child(game)
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame

	var ui: GameUIRoot = game.get_node("UIRoot")
	game._start_run(true)
	game.tutorial_visible = false
	game.set_process(false)
	game.player.weapons = {
		"shell_pistol": 2,
		"magnetic_coin": 2,
		"frost_crystal": 1,
		"cracked_brick": 1,
	}
	var hud_debuffs: Array[String] = ["shifted_balance", "hollow_defense"]
	game.active_debuffs = hud_debuffs
	game._recalculate_player_stats()
	game.message_time = 0.0
	for i in 12:
		game._spawn_enemy("stardust_slime")
	ui.refresh()
	await _capture("01_combat_hud.png")

	game._gain_xp(40.0)
	ui.refresh()
	await process_frame
	await _capture("02_reward_selection.png")

	game._start_run(true)
	game.tutorial_visible = false
	game.player.weapons = {
		"shell_pistol": 2,
		"magnetic_coin": 2,
		"frost_crystal": 1,
	}
	var pause_debuffs: Array[String] = ["shifted_balance", "hollow_defense"]
	game.active_debuffs = pause_debuffs
	game._recalculate_player_stats()
	game.message_time = 0.0
	game.paused = true
	ui.refresh()
	await process_frame
	await _capture("03_pause_details.png")

	ui._open_settings()
	await process_frame
	await _capture("04_key_bindings.png")

	game.queue_free()
	await process_frame
	print("OK: UI review screenshots captured")
	quit(0)


func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_DIR.path_join(filename)))
	assert(error == OK)
