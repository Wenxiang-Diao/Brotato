extends Node2D

const SliceDataRepositoryScript := preload("res://game/scripts/core/slice_data_repository.gd")
const RunMetricsRecorderScript := preload("res://game/scripts/core/run_metrics_recorder.gd")
const RewardServiceScript := preload("res://game/scripts/core/reward_service.gd")
const CombatRulesScript := preload("res://game/scripts/core/combat_rules.gd")
const EntityFactoryScript := preload("res://game/scripts/core/entity_factory.gd")
const ProgressionServiceScript := preload("res://game/scripts/core/progression_service.gd")
const TargetingServiceScript := preload("res://game/scripts/core/targeting_service.gd")
const CombatEventHubScript := preload("res://game/scripts/core/combat_event_hub.gd")
const CombatFeedbackScript := preload("res://game/scripts/core/combat_feedback.gd")
const VIEW_SIZE := Vector2(1280.0, 720.0)
const ARENA_MARGIN := 34.0
const RUN_SEED := 20260606
const MAX_ENEMIES := 150
const MAX_PROJECTILES := 100
const MAX_ACTIVE_DEBUFFS := 5
const BASE_PLAYER_STATS := {
	"max_hp": 100.0,
	"speed": 245.0,
	"damage_mult": 1.0,
	"attack_speed_mult": 1.0,
	"status_mult": 1.0,
	"xp_mult": 1.0,
	"spawn_mult": 1.0,
	"contact_damage_mult": 1.0,
	"freeze_duration_mult": 1.0,
	"skill_cooldown_max": 18.0,
}

enum GameState { MENU, PLAYING, REWARD, CORRECTION, GAME_OVER, VICTORY }

var state := GameState.MENU
var risk_mode := false
var rng := RandomNumberGenerator.new()
var reward_rng := RandomNumberGenerator.new()
var loot_rng := RandomNumberGenerator.new()
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var zones: Array[Dictionary] = []
var floating_text: Array[Dictionary] = []

var weapons: Array[Dictionary] = []
var enemies_data: Dictionary = {}
var rewards: Array[Dictionary] = []
var debuffs_data: Dictionary = {}
var statuses_data: Dictionary = {}
var reactions_data: Dictionary = {}
var run_config: Dictionary = {}
var data_repository: SliceDataRepository = SliceDataRepositoryScript.new()
var metrics_recorder: RunMetricsRecorder = RunMetricsRecorderScript.new()
var reward_service: RewardService = RewardServiceScript.new()
var combat_rules: CombatRules = CombatRulesScript.new()
var entity_factory: EntityFactory = EntityFactoryScript.new()
var progression_service: ProgressionService = ProgressionServiceScript.new()
var targeting_service: TargetingService = TargetingServiceScript.new()
var combat_events: CombatEventHub = CombatEventHubScript.new()
var combat_feedback: CombatFeedback = CombatFeedbackScript.new()

var player: Dictionary = {}
var layer := 1
var layer_time := 0.0
var total_time := 0.0
var spawn_timer := 0.0
var elite_spawned := false
var boss_spawned := false
var reward_choices: Array[Dictionary] = []
var active_debuffs: Array[String] = []
var correction_pending := false
var message := ""
var message_time := 0.0
var next_enemy_uid := 1
var metrics: Dictionary = {}
var run_logged := false
var pending_reward_levels: Array[int] = []
var current_reward_level := 0
var tutorial_visible := false
var tutorial_seen := false
var paused := false
var rerolls_remaining := 2
var metrics_saved := false
var debug_overlay_visible := false
var resume_protection := 0.0

var title_font: Font
var body_font: Font


func _ready() -> void:
	rng.seed = RUN_SEED
	title_font = ThemeDB.fallback_font
	body_font = ThemeDB.fallback_font
	if not _load_data():
		set_process(false)
	queue_redraw()


func _load_data() -> bool:
	if not data_repository.load_all():
		for error in data_repository.errors:
			push_error(error)
		return false
	weapons = data_repository.weapons
	rewards = data_repository.rewards
	enemies_data = data_repository.enemies
	debuffs_data = data_repository.debuffs
	statuses_data = data_repository.statuses
	reactions_data = data_repository.reactions
	run_config = data_repository.run_config
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if state == GameState.PLAYING:
		if tutorial_visible:
			if event.keycode == KEY_ENTER:
				tutorial_visible = false
				tutorial_seen = true
				queue_redraw()
			elif event.keycode == KEY_ESCAPE:
				state = GameState.MENU
				tutorial_visible = false
				queue_redraw()
			return
		if paused:
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
				_resume_from_pause()
			elif event.keycode == KEY_M:
				paused = false
				state = GameState.MENU
			queue_redraw()
			return
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			paused = true
			queue_redraw()
			return
	match state:
		GameState.MENU:
			if event.keycode == KEY_1:
				_start_run(false)
			elif event.keycode == KEY_2:
				_start_run(true)
		GameState.REWARD:
			if event.keycode == KEY_R:
				_reroll_rewards()
			elif event.keycode >= KEY_1 and event.keycode <= KEY_3:
				_choose_reward(event.keycode - KEY_1)
		GameState.CORRECTION:
			if event.keycode >= KEY_1 and event.keycode <= KEY_3:
				_choose_correction(event.keycode - KEY_1)
		GameState.GAME_OVER, GameState.VICTORY:
			if event.keycode == KEY_R:
				_start_run(risk_mode)
			elif event.keycode == KEY_M:
				state = GameState.MENU
				queue_redraw()
		GameState.PLAYING:
			if event.keycode == KEY_F8:
				combat_feedback.set_reduced_motion(not combat_feedback.reduced_motion)
				_show_message("低动态反馈：开" if combat_feedback.reduced_motion else "低动态反馈：关", 1.2)
			elif event.keycode == KEY_F9:
				debug_overlay_visible = not debug_overlay_visible
				queue_redraw()
			elif event.keycode == KEY_F10:
				metrics.debug_used = true
				_advance_layer()


func _start_run(use_risk_mode: bool) -> void:
	risk_mode = use_risk_mode
	rng.seed = RUN_SEED
	reward_rng.seed = RUN_SEED + 1
	loot_rng.seed = RUN_SEED + 2
	enemies.clear()
	projectiles.clear()
	pickups.clear()
	zones.clear()
	floating_text.clear()
	active_debuffs.clear()
	layer = 1
	layer_time = 0.0
	total_time = 0.0
	spawn_timer = 0.5
	elite_spawned = false
	boss_spawned = false
	correction_pending = false
	next_enemy_uid = 1
	run_logged = false
	pending_reward_levels.clear()
	current_reward_level = 0
	tutorial_visible = not tutorial_seen
	paused = false
	rerolls_remaining = 2
	metrics_saved = false
	resume_protection = 0.0
	combat_feedback.reset()
	metrics = metrics_recorder.create_run(RUN_SEED, risk_mode)
	player = entity_factory.create_player(VIEW_SIZE)
	_recalculate_player_stats()
	state = GameState.PLAYING
	_show_message("标准模式" if not risk_mode else "风险模式", 2.0)
	queue_redraw()


func _process(delta: float) -> void:
	var simulation_blocked: bool = combat_feedback.is_simulation_blocked()
	combat_feedback.update(delta)
	if message_time > 0.0:
		message_time -= delta
	if state == GameState.PLAYING and not tutorial_visible and not paused and not simulation_blocked:
		_update_run(delta)
	queue_redraw()


func _resume_from_pause() -> void:
	paused = false
	resume_protection = 0.35
	player.invulnerability = maxf(float(player.invulnerability), 0.35)


func _update_run(delta: float) -> void:
	total_time += delta
	layer_time += delta
	player.invulnerability = maxf(0.0, player.invulnerability - delta)
	player.hit_flash = maxf(0.0, float(player.hit_flash) - delta)
	resume_protection = maxf(0.0, resume_protection - delta)
	player.skill_cooldown = maxf(0.0, player.skill_cooldown - delta)
	_update_player(delta)
	_update_spawning(delta)
	_update_weapons(delta)
	_update_enemies(delta)
	_update_projectiles(delta)
	_update_pickups(delta)
	_update_zones(delta)
	_update_floating_text(delta)

	var duration := float(run_config.get("layer_duration_seconds", 90.0))
	var layer_count := int(run_config.get("layer_count", 6))
	var layer_kind := str(_current_layer_config().get("kind", "normal"))
	if layer < layer_count and layer_time >= duration and (layer_kind != "elite" or not _has_enemy_type("elite")):
		_advance_layer()
	elif layer_kind == "boss" and boss_spawned and not _has_enemy_type("boss"):
		_finish_run("victory")


func _update_player(delta: float) -> void:
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	player.position += (direction * float(player.speed) + Vector2(player.knockback_velocity)) * delta
	player.knockback_velocity = Vector2(player.knockback_velocity).move_toward(Vector2.ZERO, 900.0 * delta)
	player.position.x = clampf(player.position.x, ARENA_MARGIN, VIEW_SIZE.x - ARENA_MARGIN)
	player.position.y = clampf(player.position.y, ARENA_MARGIN, VIEW_SIZE.y - ARENA_MARGIN)
	if Input.is_action_just_pressed("active_skill") and player.skill_cooldown <= 0.0:
		player.skill_cooldown = float(player.skill_cooldown_max)
		zones.append({
			"position": player.position,
			"radius": 145.0,
			"time": 5.0,
			"tick": 0.0,
			"kind": "star_ring",
			"follow_player": true,
		})
		combat_feedback.trigger_ring(player.position, Color("#ffd166"), 92.0, 0.35)
		combat_feedback.trigger_ring(player.position, Color("#fff1a8"), 155.0, 0.45)
		combat_feedback.trigger_shake(2.5, 0.16)
		_show_message("星辉回路", 1.2)


func _update_spawning(delta: float) -> void:
	var layer_config: Dictionary = _current_layer_config()
	var layer_kind := str(layer_config.get("kind", "normal"))
	if layer_kind == "boss":
		if not boss_spawned:
			_spawn_enemy(str(layer_config.boss), true)
			boss_spawned = true
		return
	if layer_kind == "elite" and not elite_spawned:
		_spawn_enemy(str(layer_config.boss), true)
		elite_spawned = true

	if not entity_factory.has_capacity(enemies.size(), MAX_ENEMIES):
		return
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	var interval: float = maxf(0.35, 1.05 - layer * 0.09)
	spawn_timer = interval / float(player.spawn_mult)
	var pool: Array[String] = []
	for enemy_id in _current_layer_config().get("enemy_pool", ["stardust_slime"]):
		pool.append(str(enemy_id))
	_spawn_enemy(pool[rng.randi_range(0, pool.size() - 1)])


func _spawn_enemy(enemy_id: String, centered := false) -> void:
	if not enemies_data.has(enemy_id):
		return
	var data: Dictionary = enemies_data[enemy_id]
	var position: Vector2 = VIEW_SIZE * 0.5 + Vector2(0.0, -230.0)
	if not centered:
		var side: int = rng.randi_range(0, 3)
		match side:
			0: position = Vector2(rng.randf_range(30.0, 1250.0), 20.0)
			1: position = Vector2(1260.0, rng.randf_range(30.0, 690.0))
			2: position = Vector2(rng.randf_range(30.0, 1250.0), 700.0)
			_: position = Vector2(20.0, rng.randf_range(30.0, 690.0))
	var hp_scale: float = 1.0 + (layer - 1) * 0.22
	enemies.append(entity_factory.create_enemy(data, enemy_id, position, hp_scale, next_enemy_uid, rng))
	next_enemy_uid += 1


func _update_weapons(delta: float) -> void:
	for weapon_id in player.weapons.keys():
		var weapon: Dictionary = _find_by_id(weapons, weapon_id)
		if weapon.is_empty():
			continue
		var timers: Dictionary = player.weapon_timers
		var timer: float = float(timers.get(weapon_id, 0.0)) - delta
		if timer > 0.0:
			timers[weapon_id] = timer
			continue
		var level: int = int(player.weapons[weapon_id])
		var cooldown: float = float(weapon.cooldown) / float(player.attack_speed_mult)
		var did_attack: bool = false
		match weapon_id:
			"shell_pistol":
				var shots: Dictionary = player.weapon_shots
				var shot_count: int = int(shots.get(weapon_id, 0)) + 1
				did_attack = _fire_projectile(weapon, level, "mark", shot_count % 5 == 0)
				if did_attack:
					shots[weapon_id] = shot_count
			"magnetic_coin":
				did_attack = _fire_projectile(weapon, level, "shock")
			"frost_crystal":
				did_attack = _cast_frost_zone(weapon, level)
			"cracked_brick":
				did_attack = _slam_brick(weapon, level)
		timers[weapon_id] = cooldown if did_attack else 0.1


func _fire_projectile(weapon: Dictionary, level: int, status: String, precision := false) -> bool:
	if not entity_factory.has_capacity(projectiles.size(), MAX_PROJECTILES):
		return false
	var target: int = _precision_target() if precision else _nearest_enemy(player.position)
	if target < 0:
		return false
	var direction: Vector2 = (enemies[target].position - player.position).normalized()
	projectiles.append(entity_factory.create_player_projectile(
		player.position,
		direction * float(weapon.projectile_speed),
		weapon,
		level,
		status,
		precision
	))
	combat_feedback.trigger_line(
		player.position,
		player.position + direction * (34.0 if precision else 24.0),
		Color("#fff4bf") if precision else Color(weapon.color),
		4.0 if precision else 2.0
	)
	return true


func _cast_frost_zone(weapon: Dictionary, level: int) -> bool:
	var target: Vector2 = _densest_enemy_position()
	if target == Vector2.ZERO:
		return false
	zones.append({
		"position": target,
		"radius": float(weapon.radius) + (level - 1) * 8.0,
		"time": float(weapon.duration) + (level - 1) * 0.5,
		"tick": 0.0,
		"kind": "frost",
		"damage": float(weapon.damage),
	})
	combat_feedback.trigger_ring(target, Color("#8ad8ff"), float(weapon.radius), 0.4)
	return true


func _slam_brick(weapon: Dictionary, level: int) -> bool:
	var has_target: bool = false
	for enemy in enemies:
		if not enemy.dead and player.position.distance_to(enemy.position) <= float(weapon.radius):
			has_target = true
			break
	if not has_target:
		return false
	zones.append({
		"position": player.position,
		"radius": float(weapon.radius),
		"time": 0.14,
		"tick": 10.0,
		"kind": "brick_windup",
		"damage": float(weapon.damage) * (1.0 + 0.3 * (level - 1)),
	})
	return true


func _update_enemies(delta: float) -> void:
	var banner_positions: Array[Vector2] = []
	for enemy in enemies:
		if not enemy.dead and enemy.id == "banner_puppet":
			banner_positions.append(enemy.position)

	for enemy in enemies:
		if enemy.dead:
			continue
		enemy.hit_flash = maxf(0.0, float(enemy.hit_flash) - delta)
		_tick_statuses(enemy, delta)
		if enemy.dead:
			continue
		var speed_mult: float = 1.0
		if _has_status(enemy, "freeze"):
			speed_mult = 0.38
		for banner_pos in banner_positions:
			if banner_pos.distance_to(enemy.position) < 150.0 and enemy.id != "banner_puppet":
				speed_mult *= 1.22
				break
		if enemy.id == "molten_brute" and enemy.hp < enemy.max_hp * 0.5:
			speed_mult *= 1.35

		var direction: Vector2 = (player.position - enemy.position).normalized()
		if enemy.id == "ember_spirit":
			var distance: float = enemy.position.distance_to(player.position)
			if distance < 220.0:
				direction = -direction
			elif distance < 320.0:
				direction = Vector2.ZERO
		enemy.position += (direction * float(enemy.speed) * speed_mult + Vector2(enemy.knockback_velocity)) * delta
		enemy.knockback_velocity = Vector2(enemy.knockback_velocity).move_toward(Vector2.ZERO, 720.0 * delta)

		enemy.attack_timer -= delta
		if enemy.id == "ember_spirit" and enemy.attack_timer <= 0.0:
			enemy.attack_timer = 2.4
			_fire_enemy_projectile(enemy)
		elif enemy.id == "star_bone_colossus":
			_update_boss(enemy, delta)

		if enemy.position.distance_to(player.position) <= enemy.radius + player.radius:
			if player.invulnerability <= 0.0:
				var contact_damage: float = float(enemy.damage)
				if enemy.id == "molten_brute" and enemy.hp < enemy.max_hp * 0.5:
					contact_damage *= 1.35
				_damage_player(contact_damage, enemy.position)

	enemies = enemies.filter(func(enemy: Dictionary) -> bool: return not enemy.dead)


func _update_boss(enemy: Dictionary, delta: float) -> void:
	if int(enemy.boss_phase) == 1 and float(enemy.shield) <= 0.0:
		_set_boss_phase(enemy, 2, "核心暴露")
	elif int(enemy.boss_phase) < 3 and float(enemy.hp) <= float(enemy.max_hp) * 0.35:
		_set_boss_phase(enemy, 3, "星骸暴走")
	enemy.special_timer -= delta
	if enemy.special_timer <= 0.0:
		var phase: int = int(enemy.boss_phase)
		var interval: float = 4.0 if phase == 1 else (3.3 if phase == 2 else 2.6)
		var warning_duration: float = 1.1 if phase < 3 else 0.9
		var warning_radius: float = 92.0 if phase < 3 else 112.0
		enemy.special_timer = interval
		zones.append({
			"position": player.position,
			"radius": warning_radius,
			"time": warning_duration,
			"warning_duration": warning_duration,
			"tick": 0.0,
			"kind": "boss_warning",
			"damage": 24.0 if phase < 3 else 30.0,
			"phase": phase,
		})


func _set_boss_phase(enemy: Dictionary, phase: int, label: String) -> void:
	enemy.boss_phase = phase
	enemy.special_timer = 1.2
	enemy.hit_flash = 0.3
	combat_feedback.trigger_ring(enemy.position, Color("#d8c5ff"), float(enemy.radius) * 2.2, 0.5)
	combat_feedback.trigger_shake(8.0, 0.32)
	combat_feedback.trigger_hit_stop(0.05)
	combat_feedback.trigger_screen_flash(Color("#c9b6e4"), 0.14)
	_show_message(label, 1.5)


func _fire_enemy_projectile(enemy: Dictionary) -> void:
	if not entity_factory.has_capacity(projectiles.size(), MAX_PROJECTILES):
		return
	var direction: Vector2 = (player.position - enemy.position).normalized()
	projectiles.append(entity_factory.create_enemy_projectile(
		enemy.position,
		direction * 250.0,
		float(enemy.damage)
	))


func _update_projectiles(delta: float) -> void:
	for projectile in projectiles:
		projectile.position += projectile.velocity * delta
		projectile.life -= delta
		if projectile.owner == "enemy":
			if projectile.position.distance_to(player.position) <= projectile.radius + player.radius:
				_damage_player(float(projectile.damage), projectile.position)
				projectile.life = 0.0
			continue
		for enemy in enemies:
			if enemy.dead or projectile.hit_ids.has(enemy.uid):
				continue
			if projectile.position.distance_to(enemy.position) <= projectile.radius + enemy.radius:
				projectile.hit_ids.append(enemy.uid)
				_damage_enemy(enemy, float(projectile.damage), projectile.status, false)
				_apply_status(enemy, projectile.status, float(projectile.status_duration))
				if int(projectile.bounces) > 0:
					var next: int = _nearest_enemy(projectile.position, projectile.hit_ids)
					if next >= 0:
						combat_feedback.trigger_line(projectile.position, enemies[next].position, Color("#7aa2ff"), 2.5)
						projectile.velocity = (enemies[next].position - projectile.position).normalized() * projectile.velocity.length()
						projectile.bounces -= 1
					else:
						projectile.life = 0.0
				else:
					projectile.life = 0.0
				break
	projectiles = projectiles.filter(func(p: Dictionary) -> bool:
		return p.life > 0.0 and Rect2(-50.0, -50.0, 1380.0, 820.0).has_point(p.position)
	)


func _damage_enemy(enemy: Dictionary, base_damage: float, source: String, heavy: bool, already_scaled := false) -> void:
	if enemy.dead:
		return
	var raw_damage: float = base_damage if already_scaled else base_damage * float(player.damage_mult)

	if source == "shock" and _has_status(enemy, "mark"):
		var reaction := _reaction("lightning_chain")
		raw_damage *= float(reaction.damage_multiplier)
		_chain_reaction(enemy, raw_damage * float(reaction.secondary_multiplier))
		_reaction_text(enemy.position, "雷链", "lightning_chain")
		_record_reaction("lightning_chain")
		combat_feedback.trigger_ring(enemy.position, Color("#ffe66d"), 58.0, 0.25)
		combat_feedback.trigger_shake(5.0, 0.16)
		combat_feedback.trigger_hit_stop(0.025)
	if heavy and _has_status(enemy, "freeze"):
		var reaction := _reaction("shatter")
		_remove_status(enemy, "freeze")
		raw_damage *= float(reaction.damage_multiplier)
		_area_damage(enemy.position, float(reaction.radius), raw_damage * float(reaction.secondary_multiplier), enemy)
		_reaction_text(enemy.position, "破碎", "shatter")
		_record_reaction("shatter")
		combat_feedback.trigger_ring(enemy.position, Color("#8ad8ff"), 82.0, 0.3)
		combat_feedback.trigger_shake(7.0, 0.2)
		combat_feedback.trigger_hit_stop(0.045)
	if source == "burn_hit" and _has_status(enemy, "freeze"):
		var reaction := _reaction("thermal_shock")
		_remove_status(enemy, "freeze")
		raw_damage *= float(reaction.damage_multiplier)
		_reaction_text(enemy.position, "热冲击", "thermal_shock")
		_record_reaction("thermal_shock")
		combat_feedback.trigger_ring(enemy.position, Color("#ff8c42"), 68.0, 0.28)
		combat_feedback.trigger_shake(6.0, 0.18)
		combat_feedback.trigger_hit_stop(0.035)

	var damage_result: Dictionary = combat_rules.resolve_damage(raw_damage, float(enemy.armor), float(enemy.shield))
	var displayed_damage: float = float(damage_result.armored_damage)
	var hp_damage: float = float(damage_result.hp_damage)
	enemy.shield -= float(damage_result.shield_damage)
	metrics.damage_dealt += maxf(0.0, displayed_damage)
	enemy.hp -= hp_damage
	enemy.hit_flash = 0.11 if heavy else 0.07
	var knockback_strength: float = _knockback_strength(source, heavy)
	if knockback_strength > 0.0:
		var knockback_scale: float = 1.0
		if enemy.type == "elite":
			knockback_scale = 0.55
		elif enemy.type == "boss":
			knockback_scale = 0.25
		var knockback_direction: Vector2 = (enemy.position - player.position).normalized()
		enemy.knockback_velocity += knockback_direction * knockback_strength * knockback_scale
	if source != "burn_dot":
		combat_feedback.trigger_impact(enemy.position, _impact_color(source), 22.0 if heavy else 15.0)
	if heavy:
		combat_feedback.trigger_shake(4.0, 0.14)
		combat_feedback.trigger_hit_stop(0.035)
	combat_events.publish_damage({
		"target": "enemy",
		"target_uid": int(enemy.uid),
		"source": source,
		"raw_damage": raw_damage,
		"armored_damage": displayed_damage,
		"shield_damage": float(damage_result.shield_damage),
		"hp_damage": hp_damage,
	})
	_float_text(enemy.position, str(int(displayed_damage)), Color("#8ad8ff") if displayed_damage > hp_damage else Color.WHITE)
	if enemy.hp <= 0.0:
		_kill_enemy(enemy)


func _chain_reaction(origin: Dictionary, damage: float) -> void:
	var candidates: Array[Dictionary] = []
	for enemy in enemies:
		if enemy != origin and not enemy.dead and enemy.position.distance_to(origin.position) <= 180.0:
			candidates.append(enemy)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.position.distance_squared_to(origin.position) < b.position.distance_squared_to(origin.position)
	)
	var max_targets: int = int(_reaction("lightning_chain").max_targets)
	for i in mini(max_targets, candidates.size()):
		combat_feedback.trigger_line(origin.position, candidates[i].position, Color("#ffe66d"), 3.0)
		_damage_enemy(candidates[i], damage, "chain", false, true)


func _area_damage(position: Vector2, radius: float, damage: float, ignored: Dictionary = {}) -> void:
	for enemy in enemies:
		if enemy.dead or enemy == ignored:
			continue
		if enemy.position.distance_to(position) <= radius:
			_damage_enemy(enemy, damage, "area", false, true)


func _apply_status(enemy: Dictionary, status: String, duration: float) -> void:
	combat_rules.apply_status(
		enemy,
		status,
		duration,
		float(player.status_mult),
		float(player.freeze_duration_mult),
		statuses_data
	)
	if not status.is_empty():
		combat_events.publish_status({
			"target_uid": int(enemy.uid),
			"status": status,
			"duration": duration,
		})


func _tick_statuses(enemy: Dictionary, delta: float) -> void:
	var expired: Array[String] = []
	for status in enemy.statuses.keys():
		var current: Dictionary = enemy.statuses[status]
		current.time -= delta
		if status == "burn":
			current.tick -= delta
			if current.tick <= 0.0:
				current.tick = 1.0
				_damage_enemy(enemy, 4.0 * int(current.stacks), "burn_dot", false)
		if current.time <= 0.0:
			expired.append(status)
	for status in expired:
		enemy.statuses.erase(status)


func _has_status(enemy: Dictionary, status: String) -> bool:
	return combat_rules.has_status(enemy, status)


func _remove_status(enemy: Dictionary, status: String) -> void:
	combat_rules.remove_status(enemy, status)


func _kill_enemy(enemy: Dictionary) -> void:
	enemy.dead = true
	metrics.kills += 1
	combat_feedback.trigger_ring(enemy.position, Color(enemy.color), float(enemy.radius) * 1.6, 0.22)
	pickups.append({
		"position": enemy.position + Vector2.from_angle(loot_rng.randf_range(0.0, TAU)) * loot_rng.randf_range(0.0, 18.0),
		"value": float(enemy.xp),
	})


func _damage_player(amount: float, source_position: Vector2 = Vector2.ZERO) -> void:
	if player.invulnerability > 0.0 or resume_protection > 0.0 or state != GameState.PLAYING:
		return
	amount *= float(player.contact_damage_mult)
	player.hp -= amount
	metrics.damage_taken += amount
	combat_events.publish_damage({
		"target": "player",
		"source": "enemy",
		"raw_damage": amount,
		"armored_damage": amount,
		"shield_damage": 0.0,
		"hp_damage": amount,
	})
	player.invulnerability = 0.55
	player.hit_flash = 0.18
	if source_position != Vector2.ZERO:
		player.knockback_velocity += (player.position - source_position).normalized() * 180.0
	combat_feedback.trigger_shake(7.0, 0.22)
	combat_feedback.trigger_screen_flash(Color("#ff5d73"), 0.18)
	combat_feedback.trigger_impact(player.position, Color("#ff6b6b"), 24.0)
	_float_text(player.position, "-" + str(int(amount)), Color("#ff6b6b"))
	if player.hp <= 0.0:
		_finish_run("game_over")


func _update_pickups(delta: float) -> void:
	for pickup in pickups:
		var distance: float = pickup.position.distance_to(player.position)
		if distance < 125.0:
			pickup.position = pickup.position.move_toward(player.position, 340.0 * delta)
		if distance < player.radius + 7.0:
			_gain_xp(float(pickup.value) * float(player.xp_mult))
			pickup.value = 0.0
	pickups = pickups.filter(func(p: Dictionary) -> bool: return p.value > 0.0)


func _gain_xp(amount: float) -> void:
	for gained_level in progression_service.grant_xp(player, amount):
		pending_reward_levels.append(gained_level)
	if state == GameState.PLAYING and not pending_reward_levels.is_empty():
		_open_next_reward()


func _open_next_reward() -> void:
	if pending_reward_levels.is_empty():
		state = GameState.PLAYING
		return
	current_reward_level = pending_reward_levels.pop_front()
	_roll_reward_choices([])
	state = GameState.REWARD


func _roll_reward_choices(excluded_ids: Array[String]) -> void:
	var pool: Array[Dictionary] = _build_reward_pool(excluded_ids)
	reward_choices = reward_service.roll_choices(pool, current_reward_level, risk_mode, reward_rng)
	var offer_ids: Array[String] = []
	for reward in reward_choices:
		offer_ids.append(str(reward.id))
	metrics.reward_offers.append(offer_ids)
	if reward_service.choices_have_risk(reward_choices):
		metrics.risk_rewards_offered += 1


func _reroll_rewards() -> void:
	if not _can_reroll_rewards():
		return
	var excluded_ids: Array[String] = []
	for reward in reward_choices:
		excluded_ids.append(str(reward.id))
	rerolls_remaining -= 1
	metrics.rerolls_used += 1
	_roll_reward_choices(excluded_ids)


func _can_reroll_rewards() -> bool:
	if state != GameState.REWARD or rerolls_remaining <= 0:
		return false
	var excluded_ids: Array[String] = []
	for reward in reward_choices:
		excluded_ids.append(str(reward.id))
	return _build_reward_pool(excluded_ids).size() >= 3


func _build_reward_pool(excluded_ids: Array[String]) -> Array[Dictionary]:
	return reward_service.build_pool(
		rewards,
		risk_mode,
		player.weapons,
		active_debuffs,
		MAX_ACTIVE_DEBUFFS,
		excluded_ids
	)


func _choose_reward(index: int) -> void:
	if index < 0 or index >= reward_choices.size():
		return
	var reward: Dictionary = reward_choices[index]
	_apply_reward(reward)
	correction_pending = current_reward_level % 5 == 0 and not active_debuffs.is_empty()
	if correction_pending:
		state = GameState.CORRECTION
	else:
		_continue_after_choice()


func _apply_reward(reward: Dictionary) -> void:
	metrics.rewards.append(str(reward.id))
	match reward.type:
		"stat":
			var key: String = str(reward.stat)
			var bonuses: Dictionary = player.stat_bonuses
			bonuses[key] = float(bonuses.get(key, 0.0)) + float(reward.value)
			_recalculate_player_stats(float(reward.value) if key == "max_hp" else 0.0)
		"weapon_unlock":
			player.weapons[reward.weapon_id] = 1
		"weapon_level":
			var weapon_id: String = str(reward.weapon_id)
			player.weapons[weapon_id] = mini(3, int(player.weapons.get(weapon_id, 0)) + 1)
		"heal":
			player.hp = minf(float(player.max_hp), float(player.hp) + float(reward.value))
	var debuff_id: String = str(reward.get("debuff_id", ""))
	if not debuff_id.is_empty():
		metrics.risk_rewards_chosen += 1
		_add_debuff(debuff_id)
	_show_message(str(reward.name), 1.4)


func _add_debuff(debuff_id: String) -> void:
	if active_debuffs.has(debuff_id) or not debuffs_data.has(debuff_id):
		return
	active_debuffs.append(debuff_id)
	metrics.debuffs_accepted.append(debuff_id)
	_recalculate_player_stats()


func _choose_correction(index: int) -> void:
	if active_debuffs.is_empty():
		state = GameState.PLAYING
		return
	if index == 0:
		metrics.corrections.append("remove")
		_remove_debuff(active_debuffs[0])
	elif index == 1:
		metrics.corrections.append("heal")
		player.hp = minf(float(player.max_hp), float(player.hp) + 25.0)
	else:
		metrics.corrections.append("experience")
		_gain_xp(8.0)
	_continue_after_choice()


func _remove_debuff(debuff_id: String) -> void:
	if not debuffs_data.has(debuff_id):
		return
	var data: Dictionary = debuffs_data[debuff_id]
	active_debuffs.erase(debuff_id)
	_recalculate_player_stats()
	_show_message("已修正：" + str(data.name), 1.5)


func _update_zones(delta: float) -> void:
	for zone in zones:
		if bool(zone.get("follow_player", false)):
			zone.position = player.position
		zone.time -= delta
		zone.tick -= delta
		if zone.kind == "boss_warning" and zone.time <= 0.0:
			if player.position.distance_to(zone.position) <= zone.radius:
				_damage_player(float(zone.damage), zone.position)
			combat_feedback.trigger_shake(9.0, 0.28)
			combat_feedback.trigger_hit_stop(0.04)
			combat_feedback.trigger_ring(zone.position, Color("#ff6b6b"), float(zone.radius) * 1.15, 0.26)
			zone.time = -10.0
		elif zone.kind == "brick_windup" and zone.time <= 0.0:
			for enemy in enemies:
				if not enemy.dead and enemy.position.distance_to(zone.position) <= zone.radius:
					_damage_enemy(enemy, float(zone.damage), "brick", true)
			combat_feedback.trigger_ring(zone.position, Color("#e0a96d"), float(zone.radius), 0.24)
			zone.time = -10.0
		elif zone.tick <= 0.0:
			zone.tick = 0.55
			if zone.kind == "frost":
				for enemy in enemies:
					if not enemy.dead and enemy.position.distance_to(zone.position) <= zone.radius:
						_damage_enemy(enemy, float(zone.damage), "frost", false)
						_apply_status(enemy, "freeze", 1.4)
			elif zone.kind == "star_ring":
				for enemy in enemies:
					if not enemy.dead and enemy.position.distance_to(zone.position) <= zone.radius:
						_damage_enemy(enemy, 5.0, "burn_hit", false)
						_apply_status(enemy, "burn", 3.0)
	zones = zones.filter(func(z: Dictionary) -> bool: return z.time > 0.0)


func _advance_layer() -> void:
	_collect_remaining_pickups()
	layer += 1
	layer_time = 0.0
	enemies.clear()
	projectiles.clear()
	zones.clear()
	if layer > int(run_config.get("layer_count", 6)):
		_finish_run("victory")
	else:
		_show_message("进入第 %d 层" % layer, 2.0)


func _nearest_enemy(position: Vector2, ignored: Array = []) -> int:
	return targeting_service.nearest_enemy(enemies, position, ignored)


func _precision_target() -> int:
	return targeting_service.precision_target(enemies)


func _densest_enemy_position() -> Vector2:
	return targeting_service.densest_enemy_position(enemies, 120.0)


func _has_enemy_type(type_name: String) -> bool:
	return targeting_service.has_enemy_type(enemies, type_name)


func _current_layer_config() -> Dictionary:
	for entry in run_config.get("layers", []):
		if int(entry.get("layer", 0)) == layer:
			return entry
	return {}


func _reaction(reaction_id: String) -> Dictionary:
	return combat_rules.reaction(reactions_data, reaction_id)


func _continue_after_choice() -> void:
	if not pending_reward_levels.is_empty():
		_open_next_reward()
	else:
		state = GameState.PLAYING


func _collect_remaining_pickups() -> void:
	var remaining_xp: float = 0.0
	for pickup in pickups:
		remaining_xp += float(pickup.value)
	pickups.clear()
	if remaining_xp > 0.0:
		_gain_xp(remaining_xp * float(player.xp_mult))


func _recalculate_player_stats(heal_amount := 0.0) -> void:
	progression_service.recalculate_stats(
		player,
		BASE_PLAYER_STATS,
		active_debuffs,
		debuffs_data,
		heal_amount
	)


func _record_reaction(reaction_id: String) -> void:
	metrics_recorder.record_reaction(metrics, reaction_id)
	combat_events.publish_reaction({"reaction_id": reaction_id})


func _knockback_strength(source: String, heavy: bool) -> float:
	if heavy or source == "brick":
		return 280.0
	match source:
		"mark": return 55.0
		"shock": return 45.0
		"area": return 100.0
		"chain": return 40.0
		_: return 0.0


func _impact_color(source: String) -> Color:
	match source:
		"mark": return Color("#ffd166")
		"shock", "chain": return Color("#7aa2ff")
		"frost": return Color("#8ad8ff")
		"brick", "area": return Color("#e0a96d")
		"burn_hit": return Color("#ff7043")
		_: return Color.WHITE


func _finish_run(result: String) -> void:
	if run_logged:
		return
	run_logged = true
	metrics.feedback_mode = "reduced" if combat_feedback.reduced_motion else "full"
	metrics_saved = metrics_recorder.finalize_and_save(metrics, result, total_time, layer, player, active_debuffs)
	state = GameState.VICTORY if result == "victory" else GameState.GAME_OVER


func _find_by_id(rows: Array[Dictionary], id: String) -> Dictionary:
	return data_repository.find_by_id(rows, id)


func _show_message(text: String, duration: float) -> void:
	message = text
	message_time = duration


func _float_text(position: Vector2, text: String, color: Color) -> void:
	floating_text.append({"position": position, "text": text, "color": color, "time": 0.7})


func _reaction_text(position: Vector2, text: String, reaction_id: String) -> void:
	var reaction_colors: Dictionary = {
		"lightning_chain": Color("#ffe66d"),
		"shatter": Color("#8ad8ff"),
		"thermal_shock": Color("#ff8c42"),
	}
	var color: Color = reaction_colors.get(reaction_id, Color.WHITE)
	floating_text.append({"position": position, "text": text, "color": color, "time": 1.0})


func _update_floating_text(delta: float) -> void:
	for entry in floating_text:
		entry.time -= delta
		entry.position.y -= 28.0 * delta
	floating_text = floating_text.filter(func(entry: Dictionary) -> bool: return entry.time > 0.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("#101522"))
	for x in range(0, 1281, 64):
		draw_line(Vector2(x, 0), Vector2(x, 720), Color("#182237"), 1.0)
	for y in range(0, 721, 64):
		draw_line(Vector2(0, y), Vector2(1280, y), Color("#182237"), 1.0)

	if state == GameState.MENU:
		_draw_menu()
		return
	draw_set_transform(combat_feedback.shake_offset())
	_draw_world()
	draw_set_transform(Vector2.ZERO)
	_draw_hud()
	if combat_feedback.screen_flash_remaining > 0.0:
		var flash_color: Color = combat_feedback.screen_flash_color
		flash_color.a = combat_feedback.screen_flash_alpha()
		draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), flash_color)
	if state == GameState.REWARD:
		_draw_reward_overlay()
	elif state == GameState.CORRECTION:
		_draw_correction_overlay()
	elif state == GameState.GAME_OVER:
		_draw_end_overlay("挑战失败")
	elif state == GameState.VICTORY:
		_draw_end_overlay("垂直切片完成")
	elif tutorial_visible:
		_draw_tutorial_overlay()
	elif paused:
		_draw_pause_overlay()


func _draw_world() -> void:
	for zone in zones:
		var color: Color = Color("#55aaff33")
		if zone.kind == "star_ring":
			color = Color("#ffd16633")
		elif zone.kind == "brick_windup":
			color = Color("#e0a96d22")
		elif zone.kind == "boss_warning":
			color = Color("#ff303055") if int(zone.get("phase", 1)) >= 3 else Color("#ff4d4d44")
		draw_circle(zone.position, float(zone.radius), color)
		if zone.kind == "boss_warning":
			var warning_duration: float = float(zone.get("warning_duration", 1.1))
			var warning_ratio: float = clampf(float(zone.time) / warning_duration, 0.0, 1.0)
			draw_arc(zone.position, float(zone.radius), -PI * 0.5, -PI * 0.5 + TAU * warning_ratio, 48, Color("#ff6b6b"), 6.0)
			draw_string(body_font, zone.position + Vector2(-24.0, -float(zone.radius) - 10.0), "%.1f" % maxf(0.0, float(zone.time)), HORIZONTAL_ALIGNMENT_CENTER, 48, 18, Color.WHITE)
		elif zone.kind == "brick_windup":
			var brick_ratio: float = clampf(float(zone.time) / 0.14, 0.0, 1.0)
			draw_arc(zone.position, float(zone.radius) * (1.0 - brick_ratio * 0.2), 0.0, TAU, 36, Color("#e0a96d"), 4.0)
	for pickup in pickups:
		draw_circle(pickup.position, 5.0, Color("#7cf6ff"))
	for projectile in projectiles:
		draw_circle(projectile.position, float(projectile.radius), projectile.color)
	for enemy in enemies:
		var enemy_color: Color = Color.WHITE if float(enemy.hit_flash) > 0.0 else Color(enemy.color)
		draw_circle(enemy.position, float(enemy.radius), enemy_color)
		if enemy.id == "star_bone_colossus" and int(enemy.boss_phase) >= 2:
			var core_color: Color = Color("#ff6b6b") if int(enemy.boss_phase) >= 3 else Color("#ffe66d")
			draw_circle(enemy.position, float(enemy.radius) * 0.38, core_color)
		if float(enemy.shield) > 0.0:
			draw_arc(enemy.position, float(enemy.radius) + 5.0, 0.0, TAU, 28, Color("#8ad8ff"), 3.0)
		var hp_ratio: float = maxf(0.0, float(enemy.hp) / float(enemy.max_hp))
		draw_rect(Rect2(enemy.position + Vector2(-enemy.radius, -enemy.radius - 10.0), Vector2(enemy.radius * 2.0, 4.0)), Color("#321f28"))
		draw_rect(Rect2(enemy.position + Vector2(-enemy.radius, -enemy.radius - 10.0), Vector2(enemy.radius * 2.0 * hp_ratio, 4.0)), Color("#80ed99"))
		var offset: float = 0.0
		for status in enemy.statuses.keys():
			var status_colors: Dictionary = {
				"mark": Color("#ffd166"),
				"shock": Color("#7aa2ff"),
				"freeze": Color("#8ad8ff"),
				"burn": Color("#ff7043"),
			}
			var status_color: Color = Color.WHITE
			if status_colors.has(status):
				status_color = status_colors[status]
			draw_circle(enemy.position + Vector2(-12.0 + offset, enemy.radius + 7.0), 3.5, status_color)
			offset += 9.0
	var player_color: Color = Color("#ffffff")
	if float(player.hit_flash) > 0.0:
		player_color = Color("#ff6b6b")
	elif player.invulnerability > 0.0:
		player_color = Color("#ffb3b3")
	draw_circle(player.position, float(player.radius), player_color)
	draw_arc(player.position, float(player.radius) + 5.0, 0.0, TAU, 24, Color("#7cf6ff"), 2.0)
	for entry in floating_text:
		draw_string(body_font, entry.position, entry.text, HORIZONTAL_ALIGNMENT_CENTER, -1, 15, entry.color)
	_draw_combat_effects()


func _draw_combat_effects() -> void:
	for effect in combat_feedback.effects:
		var progress: float = 1.0 - float(effect.time) / float(effect.duration)
		var color: Color = Color(effect.color)
		color.a *= 1.0 - progress
		match str(effect.kind):
			"impact":
				var impact_radius: float = lerpf(3.0, float(effect.radius), progress)
				draw_circle(effect.position, impact_radius, color, false, 2.0)
				draw_line(effect.position - Vector2(impact_radius, 0.0), effect.position + Vector2(impact_radius, 0.0), color, 2.0)
				draw_line(effect.position - Vector2(0.0, impact_radius), effect.position + Vector2(0.0, impact_radius), color, 2.0)
			"ring":
				var ring_radius: float = lerpf(float(effect.radius) * 0.35, float(effect.radius), progress)
				draw_arc(effect.position, ring_radius, 0.0, TAU, 40, color, 3.0)
			"line":
				draw_line(effect.start, effect.end, color, float(effect.width))


func _draw_hud() -> void:
	var hp_ratio: float = maxf(0.0, float(player.hp) / float(player.max_hp))
	var xp_ratio: float = float(player.xp) / float(player.xp_next)
	draw_rect(Rect2(24, 22, 300, 18), Color("#2d2633"))
	draw_rect(Rect2(24, 22, 300 * hp_ratio, 18), Color("#ef476f"))
	draw_string(body_font, Vector2(28, 37), "HP %d / %d" % [player.hp, player.max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	draw_rect(Rect2(24, 48, 300, 10), Color("#26333c"))
	draw_rect(Rect2(24, 48, 300 * xp_ratio, 10), Color("#7cf6ff"))
	draw_string(body_font, Vector2(24, 80), "等级 %d  |  第 %d/%d 层  |  %02d:%02d" % [player.level, layer, int(run_config.get("layer_count", 6)), int(total_time) / 60, int(total_time) % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(body_font, Vector2(24, 105), "主动技能 [Space] %.1fs" % player.skill_cooldown, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#ffd166"))
	var weapon_labels: Array[String] = []
	for weapon_id in player.weapons.keys():
		var weapon_data: Dictionary = _find_by_id(weapons, str(weapon_id))
		var weapon_name: String = str(weapon_data.get("name", weapon_id))
		weapon_labels.append("%s Lv.%d" % [weapon_name, int(player.weapons[weapon_id])])
	draw_string(body_font, Vector2(24, 130), "武器：" + " / ".join(weapon_labels), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#b8c5d6"))
	var debuff_names: Array[String] = []
	for id in active_debuffs:
		debuff_names.append(str(debuffs_data[id].name))
	draw_string(body_font, Vector2(24, 154), "Debuff：" + ("无" if debuff_names.is_empty() else " / ".join(debuff_names)), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#ff9f7f"))
	draw_string(body_font, Vector2(1060, 30), "F10 跳层（调试）", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#66758c"))
	draw_string(body_font, Vector2(1060, 50), "F8 低动态反馈", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#66758c"))
	draw_string(body_font, Vector2(930, 80), "状态", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(body_font, Vector2(930, 104), "标记  感电  冻结  灼烧", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#b8c5d6"))
	draw_circle(Vector2(938, 121), 4.0, Color("#ffd166"))
	draw_circle(Vector2(986, 121), 4.0, Color("#7aa2ff"))
	draw_circle(Vector2(1034, 121), 4.0, Color("#8ad8ff"))
	draw_circle(Vector2(1082, 121), 4.0, Color("#ff7043"))
	draw_string(body_font, Vector2(930, 150), "雷链：标记+感电", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#ffe66d"))
	draw_string(body_font, Vector2(930, 170), "破碎：冻结+重击", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#8ad8ff"))
	draw_string(body_font, Vector2(930, 190), "热冲击：冻结+灼烧", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#ff8c42"))
	if debug_overlay_visible:
		draw_rect(Rect2(930, 225, 320, 135), Color("#080b12dd"))
		draw_string(body_font, Vector2(945, 250), "P2 Debug", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#7cf6ff"))
		draw_string(body_font, Vector2(945, 275), "FPS: %d" % Engine.get_frames_per_second(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		draw_string(body_font, Vector2(945, 298), "Enemies: %d / %d" % [enemies.size(), MAX_ENEMIES], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		draw_string(body_font, Vector2(945, 321), "Projectiles: %d / %d" % [projectiles.size(), MAX_PROJECTILES], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		draw_string(body_font, Vector2(945, 344), "Zones: %d  Pickups: %d" % [zones.size(), pickups.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		draw_string(body_font, Vector2(1110, 250), "Motion: %s" % ("LOW" if combat_feedback.reduced_motion else "FULL"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#ffd166"))
	if message_time > 0.0:
		draw_string(title_font, Vector2(480, 82), message, HORIZONTAL_ALIGNMENT_CENTER, 320, 28, Color("#ffe66d"))


func _draw_menu() -> void:
	draw_string(title_font, Vector2(340, 190), "星链回响", HORIZONTAL_ALIGNMENT_CENTER, 600, 54, Color("#ffffff"))
	draw_string(body_font, Vector2(390, 250), "P1 试玩就绪版", HORIZONTAL_ALIGNMENT_CENTER, 500, 24, Color("#7cf6ff"))
	draw_string(body_font, Vector2(390, 335), "[1] 标准模式：仅验证战斗与状态反应", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#ffffff"))
	draw_string(body_font, Vector2(390, 385), "[2] 风险模式：加入风险奖励与 Debuff", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#ffbf69"))
	draw_string(body_font, Vector2(390, 470), "WASD / 方向键移动，Space 主动技能", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#b8c5d6"))
	draw_string(body_font, Vector2(390, 505), "固定种子：%d" % RUN_SEED, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#66758c"))


func _draw_reward_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("#080b12aa"))
	draw_rect(Rect2(170, 130, 940, 470), Color("#0b0e18ee"))
	draw_string(title_font, Vector2(390, 180), "升级：选择一项", HORIZONTAL_ALIGNMENT_CENTER, 500, 34, Color.WHITE)
	var can_reroll: bool = _can_reroll_rewards()
	var reroll_text: String = "[R] 重抽（剩余 %d）" % rerolls_remaining
	if rerolls_remaining <= 0:
		reroll_text = "重抽次数已用完"
	elif not can_reroll:
		reroll_text = "没有足够的全新候选可供重抽"
	draw_string(body_font, Vector2(390, 210), reroll_text, HORIZONTAL_ALIGNMENT_CENTER, 500, 17, Color("#7cf6ff") if can_reroll else Color("#66758c"))
	for i in reward_choices.size():
		var reward: Dictionary = reward_choices[i]
		var x: float = 215.0 + i * 300.0
		var color: Color = Color("#263956") if str(reward.get("debuff_id", "")).is_empty() else Color("#5a3035")
		draw_rect(Rect2(x, 225, 260, 285), color)
		draw_string(title_font, Vector2(x + 18, 270), "[%d] %s" % [i + 1, reward.name], HORIZONTAL_ALIGNMENT_LEFT, 224, 22, Color.WHITE)
		draw_string(body_font, Vector2(x + 18, 300), _reward_type_label(str(reward.type)), HORIZONTAL_ALIGNMENT_LEFT, 224, 14, Color("#7cf6ff"))
		draw_multiline_string(body_font, Vector2(x + 18, 335), reward.description, HORIZONTAL_ALIGNMENT_LEFT, 224, 17, 24, Color("#dbe8f5"))
		var debuff_id: String = str(reward.get("debuff_id", ""))
		if not debuff_id.is_empty():
			draw_multiline_string(body_font, Vector2(x + 18, 430), "代价：" + str(debuffs_data[debuff_id].description), HORIZONTAL_ALIGNMENT_LEFT, 224, 15, 20, Color("#ffb4a2"))


func _reward_type_label(type_name: String) -> String:
	var labels: Dictionary = {
		"stat": "属性强化",
		"heal": "生存恢复",
		"weapon_unlock": "新武器",
		"weapon_level": "武器升级",
	}
	return str(labels.get(type_name, type_name))


func _draw_correction_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("#080b12aa"))
	draw_rect(Rect2(280, 165, 720, 390), Color("#0b0e18ee"))
	draw_string(title_font, Vector2(390, 215), "5 级修正窗口", HORIZONTAL_ALIGNMENT_CENTER, 500, 32, Color.WHITE)
	draw_string(body_font, Vector2(365, 290), "[1] 移除最早获得的 Debuff", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("#80ed99"))
	draw_string(body_font, Vector2(365, 345), "[2] 保留风险，恢复 25 生命", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("#ffd166"))
	draw_string(body_font, Vector2(365, 400), "[3] 保留风险，获得 8 经验", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("#ff9f7f"))


func _draw_tutorial_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("#080b12aa"))
	draw_rect(Rect2(250, 145, 780, 430), Color("#0b0e18f2"))
	draw_string(title_font, Vector2(340, 205), "战斗说明", HORIZONTAL_ALIGNMENT_CENTER, 600, 38, Color.WHITE)
	draw_string(body_font, Vector2(330, 275), "WASD / 方向键：移动与走位", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("#dbe8f5"))
	draw_string(body_font, Vector2(330, 320), "武器自动攻击；Space：释放星辉回路", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("#ffd166"))
	draw_string(body_font, Vector2(330, 365), "组合武器状态，触发雷链、破碎和热冲击", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("#7cf6ff"))
	draw_string(body_font, Vector2(330, 410), "击败敌人并完成 6 层，最终击败星骸巨像", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("#80ed99"))
	draw_string(body_font, Vector2(330, 455), "Esc / P：暂停", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#b8c5d6"))
	draw_string(title_font, Vector2(390, 525), "按 Enter 开始", HORIZONTAL_ALIGNMENT_CENTER, 500, 24, Color.WHITE)


func _draw_pause_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("#080b12aa"))
	draw_rect(Rect2(330, 220, 620, 280), Color("#0b0e18f2"))
	draw_string(title_font, Vector2(390, 285), "已暂停", HORIZONTAL_ALIGNMENT_CENTER, 500, 42, Color.WHITE)
	draw_string(body_font, Vector2(390, 355), "Esc / P：继续", HORIZONTAL_ALIGNMENT_CENTER, 500, 22, Color("#80ed99"))
	draw_string(body_font, Vector2(390, 405), "M：返回模式选择", HORIZONTAL_ALIGNMENT_CENTER, 500, 20, Color("#b8c5d6"))


func _draw_end_overlay(heading: String) -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("#080b12aa"))
	draw_rect(Rect2(250, 135, 780, 470), Color("#0b0e18f2"))
	draw_string(title_font, Vector2(340, 205), heading, HORIZONTAL_ALIGNMENT_CENTER, 600, 42, Color.WHITE)
	var mode_name: String = "风险模式" if risk_mode else "标准模式"
	draw_string(body_font, Vector2(340, 250), "%s  |  第 %d/%d 层  |  等级 %d" % [mode_name, layer, int(run_config.get("layer_count", 6)), int(player.level)], HORIZONTAL_ALIGNMENT_CENTER, 600, 20, Color("#7cf6ff"))
	draw_string(body_font, Vector2(360, 305), "击杀：%d" % int(metrics.get("kills", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#dbe8f5"))
	draw_string(body_font, Vector2(360, 340), "造成伤害：%d" % int(metrics.get("damage_dealt", 0.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#dbe8f5"))
	draw_string(body_font, Vector2(360, 375), "受到伤害：%d" % int(metrics.get("damage_taken", 0.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#ff9f7f"))
	var reaction_metrics: Dictionary = metrics.get("reactions", {})
	draw_string(body_font, Vector2(650, 305), "雷链：%d" % int(reaction_metrics.get("lightning_chain", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#ffe66d"))
	draw_string(body_font, Vector2(650, 340), "破碎：%d" % int(reaction_metrics.get("shatter", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#8ad8ff"))
	draw_string(body_font, Vector2(650, 375), "热冲击：%d" % int(reaction_metrics.get("thermal_shock", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#ff8c42"))
	draw_string(body_font, Vector2(340, 450), "[R] 以相同模式重新开始", HORIZONTAL_ALIGNMENT_CENTER, 600, 22, Color("#80ed99"))
	draw_string(body_font, Vector2(340, 495), "[M] 返回模式选择", HORIZONTAL_ALIGNMENT_CENTER, 600, 20, Color("#b8c5d6"))
	var save_text: String = "本局数据已写入 vertical_slice_runs.jsonl" if metrics_saved else "本局数据写入失败，请检查用户目录权限"
	draw_string(body_font, Vector2(340, 545), save_text, HORIZONTAL_ALIGNMENT_CENTER, 600, 15, Color("#66758c") if metrics_saved else Color("#ff9f7f"))
