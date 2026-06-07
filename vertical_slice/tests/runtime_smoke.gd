extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://game/main.tscn")
	assert(scene != null)
	var game: Node2D = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)

	_test_mode(game, false)
	game.tutorial_seen = false
	_test_mode(game, true)
	_test_entity_limits(game)
	_test_late_game_reroll_guard(game)
	_test_combat_feel(game)

	game.queue_free()
	await process_frame
	print("OK: Godot runtime smoke test passed")
	quit(0)


func _test_mode(game: Node2D, risk_mode: bool) -> void:
	game._start_run(risk_mode)
	assert(game.state == game.GameState.PLAYING)
	assert(game.tutorial_visible)
	assert(not game.player.is_empty())
	assert(game.weapons.size() == 4)
	assert(game.enemies_data.size() == 7)
	assert(game.rerolls_remaining == 2)

	var initial_time: float = game.total_time
	game._process(1.0)
	assert(game.total_time == initial_time)
	game.tutorial_visible = false
	game.paused = true
	game._process(1.0)
	assert(game.total_time == initial_time)
	game.paused = false

	game._spawn_enemy("stardust_slime", true)
	game._spawn_enemy("ember_spirit", true)
	assert(game.enemies.size() == 2)

	game._update_weapons(2.0)
	game._update_enemies(0.016)
	game._update_projectiles(0.016)
	game._update_pickups(0.016)
	game._update_zones(0.016)

	var target: Dictionary = game.enemies[0]
	game._apply_status(target, "mark", 2.0)
	game._damage_enemy(target, 10.0, "shock", false)
	game._apply_status(target, "freeze", 2.0)
	game._damage_enemy(target, 10.0, "brick", true)

	game._gain_xp(40.0)
	assert(game.state == game.GameState.REWARD)
	assert(not game.reward_choices.is_empty())
	var original_ids: Array[String] = []
	for reward in game.reward_choices:
		original_ids.append(str(reward.id))
	game._reroll_rewards()
	assert(game.rerolls_remaining == 1)
	assert(int(game.metrics.rerolls_used) == 1)
	for reward in game.reward_choices:
		assert(not original_ids.has(str(reward.id)))
	game._choose_reward(0)
	while game.state == game.GameState.REWARD:
		game._choose_reward(0)
	if game.state == game.GameState.CORRECTION:
		game._choose_correction(1)
	assert(game.state == game.GameState.PLAYING)

	game._finish_run("game_over")
	assert(game.state == game.GameState.GAME_OVER)
	assert(game.run_logged)
	assert(game.metrics_saved)
	assert(game.metrics.result == "game_over")
	assert(game.metrics.has("hp_at_end"))


func _test_entity_limits(game: Node2D) -> void:
	game._start_run(false)
	game.tutorial_visible = false
	game.enemies.clear()
	for i in game.MAX_ENEMIES:
		game._spawn_enemy("stardust_slime")
	assert(game.enemies.size() == game.MAX_ENEMIES)
	game.spawn_timer = 0.0
	game._update_spawning(1.0)
	assert(game.enemies.size() == game.MAX_ENEMIES)

	game.projectiles.clear()
	for i in game.MAX_PROJECTILES:
		game.projectiles.append({
			"owner": "player",
			"position": Vector2.ZERO,
			"velocity": Vector2.ZERO,
			"radius": 1.0,
			"damage": 0.0,
			"status": "",
			"status_duration": 0.0,
			"heavy": false,
			"life": 1.0,
			"bounces": 0,
			"hit_ids": [],
			"color": Color.WHITE,
		})
	var weapon: Dictionary = game._find_by_id(game.weapons, "shell_pistol")
	assert(not game._fire_projectile(weapon, 1, "mark"))
	assert(game.projectiles.size() == game.MAX_PROJECTILES)

	game._start_run(false)
	game.tutorial_visible = false
	game.total_time = 12.0
	game._return_to_menu()
	assert(game.state == game.GameState.MENU)
	assert(game.run_logged)
	assert(game.metrics.result == "abandoned_to_menu")
	assert(game.metrics.exit_context == "playing")


func _test_late_game_reroll_guard(game: Node2D) -> void:
	game._start_run(false)
	game.tutorial_visible = false
	game.player.weapons = {
		"shell_pistol": 3,
		"magnetic_coin": 3,
		"frost_crystal": 3,
		"cracked_brick": 3,
	}
	game.current_reward_level = 20
	var excluded_ids: Array[String] = []
	game._roll_reward_choices(excluded_ids)
	game.state = game.GameState.REWARD
	assert(game.reward_choices.size() == 3)
	var original_ids: Array[String] = []
	for reward in game.reward_choices:
		original_ids.append(str(reward.id))
	assert(not game._can_reroll_rewards())
	game._reroll_rewards()
	assert(game.rerolls_remaining == 2)
	assert(int(game.metrics.rerolls_used) == 0)
	var unchanged_ids: Array[String] = []
	for reward in game.reward_choices:
		unchanged_ids.append(str(reward.id))
	assert(unchanged_ids == original_ids)


func _test_combat_feel(game: Node2D) -> void:
	game._start_run(false)
	game.tutorial_visible = false
	game._spawn_enemy("star_bone_colossus", true)
	var boss: Dictionary = game.enemies[0]

	var initial_hp: float = float(boss.hp)
	var initial_shield: float = float(boss.shield)
	var brick: Dictionary = game._find_by_id(game.weapons, "cracked_brick")
	boss.position = game.player.position + Vector2(20.0, 0.0)
	assert(game._slam_brick(brick, 1))
	assert(game.zones.any(func(zone: Dictionary) -> bool: return zone.kind == "brick_windup"))
	game._update_zones(0.15)
	assert(float(boss.hp) < initial_hp or float(boss.shield) < initial_shield)
	assert(float(boss.hit_flash) > 0.0)
	assert(Vector2(boss.knockback_velocity).length() > 0.0)
	assert(game.combat_feedback.hit_stop_remaining <= 0.05)
	assert(game.combat_feedback.effects.size() <= game.combat_feedback.MAX_EFFECTS)

	game.paused = true
	game._resume_from_pause()
	assert(not game.paused)
	assert(game.resume_protection > 0.0)
	assert(float(game.player.invulnerability) >= 0.35)

	boss.shield = 0.0
	game._update_boss(boss, 0.0)
	assert(int(boss.boss_phase) == 2)
	boss.hp = float(boss.max_hp) * 0.34
	game._update_boss(boss, 0.0)
	assert(int(boss.boss_phase) == 3)
	boss.special_timer = 0.0
	game._update_boss(boss, 0.0)
	var warning: Dictionary = game.zones.back()
	assert(warning.kind == "boss_warning")
	assert(float(warning.warning_duration) >= 0.9)
	assert(float(warning.radius) >= 112.0)
