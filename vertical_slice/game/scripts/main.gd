extends Node2D

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

var title_font: Font
var body_font: Font


func _ready() -> void:
	rng.seed = RUN_SEED
	title_font = ThemeDB.fallback_font
	body_font = ThemeDB.fallback_font
	_load_data()
	queue_redraw()


func _load_data() -> void:
	weapons = _load_json_array("res://data/weapons.json")
	rewards = _load_json_array("res://data/rewards.json")
	for row in _load_json_array("res://data/enemies.json"):
		enemies_data[row.id] = row
	for row in _load_json_array("res://data/debuffs.json"):
		debuffs_data[row.id] = row
	for row in _load_json_array("res://data/statuses.json"):
		statuses_data[row.id] = row
	for row in _load_json_array("res://data/reactions.json"):
		reactions_data[row.id] = row
	var config = _load_json("res://data/run_config.json")
	if config is Dictionary:
		run_config = config


func _load_json_array(path: String) -> Array[Dictionary]:
	var value = _load_json(path)
	var output: Array[Dictionary] = []
	if value is Array:
		for row in value:
			if row is Dictionary:
				output.append(row)
	return output


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Missing data file: " + path)
		return []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null:
		push_error("Invalid JSON: " + path)
		return []
	return parsed


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
				paused = false
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
			if event.keycode == KEY_F10:
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
	metrics = {
		"seed": RUN_SEED,
		"mode": "risk" if risk_mode else "standard",
		"kills": 0,
		"damage_dealt": 0.0,
		"damage_taken": 0.0,
		"reactions": {"lightning_chain": 0, "shatter": 0, "thermal_shock": 0},
		"rewards": [],
		"debuffs_accepted": [],
		"corrections": [],
		"reward_offers": [],
		"risk_rewards_offered": 0,
		"risk_rewards_chosen": 0,
		"rerolls_used": 0,
		"debug_used": false,
	}
	player = {
		"position": VIEW_SIZE * 0.5,
		"radius": 16.0,
		"hp": 100.0,
		"stat_bonuses": {},
		"level": 1,
		"xp": 0.0,
		"xp_next": 16.0,
		"invulnerability": 0.0,
		"skill_cooldown": 0.0,
		"weapons": {"shell_pistol": 1},
		"weapon_timers": {},
		"weapon_shots": {},
	}
	_recalculate_player_stats()
	state = GameState.PLAYING
	_show_message("标准模式" if not risk_mode else "风险模式", 2.0)
	queue_redraw()


func _process(delta: float) -> void:
	if message_time > 0.0:
		message_time -= delta
	if state == GameState.PLAYING and not tutorial_visible and not paused:
		_update_run(delta)
	queue_redraw()


func _update_run(delta: float) -> void:
	total_time += delta
	layer_time += delta
	player.invulnerability = maxf(0.0, player.invulnerability - delta)
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
	player.position += direction * float(player.speed) * delta
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

	if enemies.size() >= MAX_ENEMIES:
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
	var hp: float = float(data.hp) * hp_scale
	enemies.append({
		"uid": next_enemy_uid,
		"id": enemy_id,
		"name": data.name,
		"type": data.type,
		"position": position,
		"radius": float(data.radius),
		"hp": hp,
		"max_hp": hp,
		"speed": float(data.speed),
		"damage": float(data.damage),
		"xp": float(data.xp),
		"armor": float(data.get("armor", 0.0)),
		"color": Color(data.color),
		"statuses": {},
		"attack_timer": rng.randf_range(0.2, 1.0),
		"special_timer": rng.randf_range(1.0, 2.0),
		"shield": float(data.get("shield", 0.0)) * hp_scale,
		"shield_max": float(data.get("shield", 0.0)) * hp_scale,
		"dead": false,
	})
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
	if projectiles.size() >= MAX_PROJECTILES:
		return false
	var target: int = _precision_target() if precision else _nearest_enemy(player.position)
	if target < 0:
		return false
	var direction: Vector2 = (enemies[target].position - player.position).normalized()
	projectiles.append({
		"owner": "player",
		"position": player.position,
		"velocity": direction * float(weapon.projectile_speed),
		"radius": 8.0 if precision else (5.0 if status == "mark" else 7.0),
		"damage": float(weapon.damage) * (1.0 + 0.25 * (level - 1)) * (1.8 if precision else 1.0),
		"status": status,
		"status_duration": float(weapon.status_duration),
		"heavy": false,
		"life": 2.0,
		"bounces": int(weapon.get("bounces", 0)) + level - 1,
		"hit_ids": [],
		"color": Color("#ffffff") if precision else Color(weapon.color),
	})
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
	return true


func _slam_brick(weapon: Dictionary, level: int) -> bool:
	var hit: bool = false
	for enemy in enemies:
		if enemy.dead:
			continue
		if player.position.distance_to(enemy.position) <= float(weapon.radius):
			_damage_enemy(enemy, float(weapon.damage) * (1.0 + 0.3 * (level - 1)), "brick", true)
			hit = true
	return hit


func _update_enemies(delta: float) -> void:
	var banner_positions: Array[Vector2] = []
	for enemy in enemies:
		if not enemy.dead and enemy.id == "banner_puppet":
			banner_positions.append(enemy.position)

	for enemy in enemies:
		if enemy.dead:
			continue
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
		enemy.position += direction * float(enemy.speed) * speed_mult * delta

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
				_damage_player(contact_damage)

	enemies = enemies.filter(func(enemy: Dictionary) -> bool: return not enemy.dead)


func _update_boss(enemy: Dictionary, delta: float) -> void:
	enemy.special_timer -= delta
	if enemy.special_timer <= 0.0:
		enemy.special_timer = 4.0
		zones.append({
			"position": player.position,
			"radius": 92.0,
			"time": 1.1,
			"warning_duration": 1.1,
			"tick": 0.0,
			"kind": "boss_warning",
			"damage": 24.0,
		})


func _fire_enemy_projectile(enemy: Dictionary) -> void:
	if projectiles.size() >= MAX_PROJECTILES:
		return
	var direction: Vector2 = (player.position - enemy.position).normalized()
	projectiles.append({
		"owner": "enemy",
		"position": enemy.position,
		"velocity": direction * 250.0,
		"radius": 8.0,
		"damage": float(enemy.damage),
		"life": 3.0,
		"color": Color("#ff7043"),
	})


func _update_projectiles(delta: float) -> void:
	for projectile in projectiles:
		projectile.position += projectile.velocity * delta
		projectile.life -= delta
		if projectile.owner == "enemy":
			if projectile.position.distance_to(player.position) <= projectile.radius + player.radius:
				_damage_player(float(projectile.damage))
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
	if heavy and _has_status(enemy, "freeze"):
		var reaction := _reaction("shatter")
		_remove_status(enemy, "freeze")
		raw_damage *= float(reaction.damage_multiplier)
		_area_damage(enemy.position, float(reaction.radius), raw_damage * float(reaction.secondary_multiplier), enemy)
		_reaction_text(enemy.position, "破碎", "shatter")
		_record_reaction("shatter")
	if source == "burn_hit" and _has_status(enemy, "freeze"):
		var reaction := _reaction("thermal_shock")
		_remove_status(enemy, "freeze")
		raw_damage *= float(reaction.damage_multiplier)
		_reaction_text(enemy.position, "热冲击", "thermal_shock")
		_record_reaction("thermal_shock")

	var damage: float = raw_damage * 100.0 / (100.0 + float(enemy.armor))
	var displayed_damage: float = damage
	if float(enemy.shield) > 0.0:
		var absorbed: float = minf(float(enemy.shield), damage)
		enemy.shield -= absorbed
		damage -= absorbed
	metrics.damage_dealt += maxf(0.0, displayed_damage)
	enemy.hp -= damage
	_float_text(enemy.position, str(int(displayed_damage)), Color("#8ad8ff") if displayed_damage > damage else Color.WHITE)
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
		_damage_enemy(candidates[i], damage, "chain", false, true)


func _area_damage(position: Vector2, radius: float, damage: float, ignored: Dictionary = {}) -> void:
	for enemy in enemies:
		if enemy.dead or enemy == ignored:
			continue
		if enemy.position.distance_to(position) <= radius:
			_damage_enemy(enemy, damage, "area", false, true)


func _apply_status(enemy: Dictionary, status: String, duration: float) -> void:
	if status.is_empty():
		return
	if status == "freeze":
		duration *= float(player.freeze_duration_mult)
	var status_data: Dictionary = statuses_data.get(status, {})
	var max_stacks: int = int(status_data.get("max_stacks", 1))
	var statuses: Dictionary = enemy.statuses
	var current: Dictionary = statuses.get(status, {"stacks": 0, "time": 0.0, "tick": 1.0})
	current.stacks = mini(max_stacks, int(current.stacks) + 1)
	current.time = maxf(float(current.time), duration * float(player.status_mult))
	statuses[status] = current


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
	return enemy.statuses.has(status)


func _remove_status(enemy: Dictionary, status: String) -> void:
	enemy.statuses.erase(status)


func _kill_enemy(enemy: Dictionary) -> void:
	enemy.dead = true
	metrics.kills += 1
	pickups.append({
		"position": enemy.position + Vector2.from_angle(loot_rng.randf_range(0.0, TAU)) * loot_rng.randf_range(0.0, 18.0),
		"value": float(enemy.xp),
	})


func _damage_player(amount: float) -> void:
	if player.invulnerability > 0.0 or state != GameState.PLAYING:
		return
	amount *= float(player.contact_damage_mult)
	player.hp -= amount
	metrics.damage_taken += amount
	player.invulnerability = 0.55
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
	player.xp += amount
	while player.xp >= player.xp_next:
		player.xp -= player.xp_next
		player.level += 1
		player.xp_next = floorf(float(player.xp_next) * 1.22 + 5.0)
		pending_reward_levels.append(int(player.level))
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
	reward_choices.clear()
	var pool: Array[Dictionary] = _build_reward_pool(excluded_ids)
	if current_reward_level <= 4:
		_take_guided_reward(pool, "weapon_unlock")
	if risk_mode and current_reward_level >= 3:
		_take_guided_reward(pool, "risk")
	while reward_choices.size() < 3 and not pool.is_empty():
		var index: int = reward_rng.randi_range(0, pool.size() - 1)
		if _choices_have_risk() and not str(pool[index].get("debuff_id", "")).is_empty():
			pool.remove_at(index)
			continue
		reward_choices.append(pool[index])
		pool.remove_at(index)
	var offer_ids: Array[String] = []
	for reward in reward_choices:
		offer_ids.append(str(reward.id))
	metrics.reward_offers.append(offer_ids)
	if _choices_have_risk():
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
	var pool: Array[Dictionary] = []
	for reward in rewards:
		if excluded_ids.has(str(reward.id)):
			continue
		if not risk_mode and not str(reward.get("debuff_id", "")).is_empty():
			continue
		if reward.type == "weapon_unlock" and player.weapons.has(reward.weapon_id):
			continue
		if reward.type == "weapon_level" and not player.weapons.has(reward.weapon_id):
			continue
		if reward.type == "weapon_level" and int(player.weapons[reward.weapon_id]) >= 3:
			continue
		var debuff_id: String = str(reward.get("debuff_id", ""))
		if not debuff_id.is_empty() and active_debuffs.size() >= MAX_ACTIVE_DEBUFFS:
			continue
		if not debuff_id.is_empty() and active_debuffs.has(debuff_id):
			continue
		pool.append(reward)
	return pool


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
				_damage_player(float(zone.damage))
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
	var best: int = -1
	var best_distance: float = INF
	for i in enemies.size():
		var enemy: Dictionary = enemies[i]
		if enemy.dead or ignored.has(enemy.uid):
			continue
		var distance: float = position.distance_squared_to(enemy.position)
		if distance < best_distance:
			best_distance = distance
			best = i
	return best


func _precision_target() -> int:
	var best: int = -1
	var best_score: float = -INF
	for i in enemies.size():
		var enemy: Dictionary = enemies[i]
		if enemy.dead:
			continue
		var score: float = float(enemy.hp)
		if _has_status(enemy, "mark"):
			score += 100000.0
		if score > best_score:
			best_score = score
			best = i
	return best


func _densest_enemy_position() -> Vector2:
	var best: Vector2 = Vector2.ZERO
	var best_count: int = 0
	for candidate in enemies:
		if candidate.dead:
			continue
		var count: int = 0
		for enemy in enemies:
			if not enemy.dead and enemy.position.distance_to(candidate.position) < 120.0:
				count += 1
		if count > best_count:
			best_count = count
			best = candidate.position
	return best


func _has_enemy_type(type_name: String) -> bool:
	for enemy in enemies:
		if not enemy.dead and enemy.type == type_name:
			return true
	return false


func _current_layer_config() -> Dictionary:
	for entry in run_config.get("layers", []):
		if int(entry.get("layer", 0)) == layer:
			return entry
	return {}


func _reaction(reaction_id: String) -> Dictionary:
	return reactions_data.get(reaction_id, {})


func _take_guided_reward(pool: Array[Dictionary], kind: String) -> void:
	if reward_choices.size() >= 3:
		return
	var candidates: Array[int] = []
	for i in pool.size():
		var reward: Dictionary = pool[i]
		if kind == "weapon_unlock" and reward.type == "weapon_unlock":
			candidates.append(i)
		elif kind == "risk" and not str(reward.get("debuff_id", "")).is_empty():
			candidates.append(i)
	if candidates.is_empty():
		return
	var candidate_index: int = candidates[reward_rng.randi_range(0, candidates.size() - 1)]
	reward_choices.append(pool[candidate_index])
	pool.remove_at(candidate_index)


func _choices_have_risk() -> bool:
	for reward in reward_choices:
		if not str(reward.get("debuff_id", "")).is_empty():
			return true
	return false


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
	var bonuses: Dictionary = player.get("stat_bonuses", {})
	for key in BASE_PLAYER_STATS.keys():
		var value: float = float(BASE_PLAYER_STATS[key]) + float(bonuses.get(key, 0.0))
		for debuff_id in active_debuffs:
			var modifiers: Dictionary = debuffs_data[debuff_id].modifiers
			if modifiers.has(key):
				value *= float(modifiers[key])
		player[key] = value
	player.hp = minf(float(player.max_hp), float(player.hp) + heal_amount)


func _record_reaction(reaction_id: String) -> void:
	var reaction_metrics: Dictionary = metrics.reactions
	reaction_metrics[reaction_id] = int(reaction_metrics.get(reaction_id, 0)) + 1


func _finish_run(result: String) -> void:
	if run_logged:
		return
	run_logged = true
	metrics.result = result
	metrics.duration_seconds = total_time
	metrics.layer_reached = layer
	metrics.level_reached = int(player.level)
	metrics.active_debuffs = active_debuffs.duplicate()
	metrics.weapons = player.weapons.duplicate()
	var metrics_path: String = "user://vertical_slice_runs.jsonl"
	var mode: FileAccess.ModeFlags = FileAccess.READ_WRITE if FileAccess.file_exists(metrics_path) else FileAccess.WRITE_READ
	var file: FileAccess = FileAccess.open(metrics_path, mode)
	if file:
		file.seek_end()
		file.store_line(JSON.stringify(metrics))
		file.flush()
		metrics_saved = file.get_error() == OK
	state = GameState.VICTORY if result == "victory" else GameState.GAME_OVER


func _find_by_id(rows: Array[Dictionary], id: String) -> Dictionary:
	for row in rows:
		if row.id == id:
			return row
	return {}


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
	_draw_world()
	_draw_hud()
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
		elif zone.kind == "boss_warning":
			color = Color("#ff4d4d44")
		draw_circle(zone.position, float(zone.radius), color)
		if zone.kind == "boss_warning":
			var warning_duration: float = float(zone.get("warning_duration", 1.1))
			var warning_ratio: float = clampf(float(zone.time) / warning_duration, 0.0, 1.0)
			draw_arc(zone.position, float(zone.radius), -PI * 0.5, -PI * 0.5 + TAU * warning_ratio, 48, Color("#ff6b6b"), 6.0)
			draw_string(body_font, zone.position + Vector2(-24.0, -float(zone.radius) - 10.0), "%.1f" % maxf(0.0, float(zone.time)), HORIZONTAL_ALIGNMENT_CENTER, 48, 18, Color.WHITE)
	for pickup in pickups:
		draw_circle(pickup.position, 5.0, Color("#7cf6ff"))
	for projectile in projectiles:
		draw_circle(projectile.position, float(projectile.radius), projectile.color)
	for enemy in enemies:
		draw_circle(enemy.position, float(enemy.radius), enemy.color)
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
	var player_color: Color = Color("#ffffff") if player.invulnerability <= 0.0 else Color("#ff9f9f")
	draw_circle(player.position, float(player.radius), player_color)
	draw_arc(player.position, float(player.radius) + 5.0, 0.0, TAU, 24, Color("#7cf6ff"), 2.0)
	for entry in floating_text:
		draw_string(body_font, entry.position, entry.text, HORIZONTAL_ALIGNMENT_CENTER, -1, 15, entry.color)


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
	draw_string(body_font, Vector2(930, 80), "状态", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(body_font, Vector2(930, 104), "标记  感电  冻结  灼烧", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#b8c5d6"))
	draw_circle(Vector2(938, 121), 4.0, Color("#ffd166"))
	draw_circle(Vector2(986, 121), 4.0, Color("#7aa2ff"))
	draw_circle(Vector2(1034, 121), 4.0, Color("#8ad8ff"))
	draw_circle(Vector2(1082, 121), 4.0, Color("#ff7043"))
	draw_string(body_font, Vector2(930, 150), "雷链：标记+感电", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#ffe66d"))
	draw_string(body_font, Vector2(930, 170), "破碎：冻结+重击", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#8ad8ff"))
	draw_string(body_font, Vector2(930, 190), "热冲击：冻结+灼烧", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#ff8c42"))
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
