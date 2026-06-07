extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://game/main.tscn")
	assert(scene != null)
	var game: Node2D = scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var ui: GameUIRoot = game.get_node("UIRoot")
	assert(ui != null)
	assert(ui.hud != null)
	assert(ui.screens != null)
	assert(ui.modal_layer != null)
	assert(ui.toast_layer != null)
	assert(ui.menu_screen.visible)
	assert(not ui.hud.visible)
	assert(_has_focused_button(ui.menu_screen))
	assert(ui.hud.theme.default_font != ThemeDB.fallback_font)
	ui._open_tutorial_from_menu()
	ui.refresh()
	assert(ui.tutorial_screen.visible)
	assert(not ui.menu_screen.visible)
	ui._show_tutorial_step(2)
	ui._advance_tutorial()
	assert(ui.menu_screen.visible)

	for action in ["ui_accept", "ui_cancel", "ui_left", "ui_right", "ui_up", "ui_down", "ui_reroll", "ui_details", "ui_pause"]:
		assert(InputMap.has_action(action), action)

	game._start_run(false)
	game.tutorial_visible = false
	ui.refresh()
	assert(ui.hud.visible)
	assert(not ui.menu_screen.visible)
	assert(ui.weapon_row.get_child_count() == game.player.weapons.size())

	game._gain_xp(40.0)
	ui.refresh()
	await process_frame
	assert(game.state == game.GameState.REWARD)
	assert(ui.reward_screen.visible)
	assert(ui.reward_cards.get_child_count() == 3)
	assert(_has_focused_button(ui.reward_screen))
	var mouse_click := InputEventMouseButton.new()
	mouse_click.button_index = MOUSE_BUTTON_LEFT
	mouse_click.pressed = true
	ui._on_reward_card_gui_input(mouse_click, 0)
	assert(game.state == game.GameState.REWARD)
	var accept_event := InputEventKey.new()
	accept_event.physical_keycode = KEY_ENTER
	accept_event.keycode = KEY_ENTER
	accept_event.pressed = true
	InputMap.action_add_event("ui_accept", accept_event)
	ui._input(accept_event)
	assert(game.state == game.GameState.REWARD)
	ui._confirm_selected_reward()

	while game.state == game.GameState.REWARD:
		game._choose_reward(0)
	if game.state == game.GameState.CORRECTION:
		ui.refresh()
		assert(ui.correction_screen.visible)
		assert(_has_focused_button(ui.correction_screen))
		game._choose_correction(0)

	game.paused = true
	ui.refresh()
	await process_frame
	assert(ui.pause_screen.visible)
	assert(_has_focused_button(ui.pause_screen))
	ui._open_settings()
	assert(ui.settings_screen.visible)
	assert(ui.rebind_buttons.size() == 6)
	ui._cycle_ui_scale()
	assert(is_equal_approx(ui.ui_scale, 1.1))
	ui._toggle_reduced_motion()
	assert(game.combat_feedback.reduced_motion)
	ui._toggle_screen_shake()
	assert(not game.combat_feedback.shake_enabled)
	ui._toggle_hit_stop()
	assert(not game.combat_feedback.hit_stop_enabled)
	ui._cycle_flash_intensity()
	assert(is_equal_approx(game.combat_feedback.flash_intensity, 0.5))
	ui._close_settings()
	assert(ui.pause_screen.visible)

	for resolution in [Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.size = resolution
		await process_frame
		assert(ui.menu_screen.size.x > 0.0)
		assert(ui.pause_screen.size.y > 0.0)

	game._finish_run("game_over")
	ui.refresh()
	await process_frame
	assert(ui.results_screen.visible)
	assert(_has_focused_button(ui.results_screen))

	game._start_run(false)
	game.tutorial_visible = false
	ui.refresh()
	var pause_event := InputEventKey.new()
	pause_event.physical_keycode = KEY_P
	pause_event.keycode = KEY_P
	pause_event.pressed = true
	ui._input(pause_event)
	assert(game.paused)
	ui._input(pause_event)
	assert(not game.paused)

	game._start_run(false)
	assert(game.tutorial_visible)
	ui._input(pause_event)
	assert(not game.tutorial_visible)
	assert(game.state == game.GameState.PLAYING)

	game.queue_free()
	await process_frame
	print("OK: UI runtime test passed")
	quit(0)


func _has_focused_button(root_node: Node) -> bool:
	var owner := root_node.get_viewport().gui_get_focus_owner()
	return owner is Button and root_node.is_ancestor_of(owner)
