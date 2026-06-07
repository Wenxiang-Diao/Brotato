class_name EntityFactory
extends RefCounted


func has_capacity(current_count: int, limit: int) -> bool:
	return current_count < limit


func create_player(view_size: Vector2) -> Dictionary:
	return {
		"position": view_size * 0.5,
		"radius": 16.0,
		"hp": 100.0,
		"stat_bonuses": {},
		"level": 1,
		"xp": 0.0,
		"xp_next": 16.0,
		"invulnerability": 0.0,
		"hit_flash": 0.0,
		"knockback_velocity": Vector2.ZERO,
		"skill_cooldown": 0.0,
		"weapons": {"shell_pistol": 1},
		"weapon_timers": {},
		"weapon_shots": {},
	}


func create_enemy(
	data: Dictionary,
	enemy_id: String,
	position: Vector2,
	hp_scale: float,
	uid: int,
	rng: RandomNumberGenerator
) -> Dictionary:
	var hp: float = float(data.hp) * hp_scale
	return {
		"uid": uid,
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
		"hit_flash": 0.0,
		"knockback_velocity": Vector2.ZERO,
		"boss_phase": 1,
		"dead": false,
	}


func create_player_projectile(
	position: Vector2,
	velocity: Vector2,
	weapon: Dictionary,
	level: int,
	status: String,
	precision: bool
) -> Dictionary:
	return {
		"owner": "player",
		"position": position,
		"velocity": velocity,
		"radius": 8.0 if precision else (5.0 if status == "mark" else 7.0),
		"damage": float(weapon.damage) * (1.0 + 0.25 * (level - 1)) * (1.8 if precision else 1.0),
		"status": status,
		"status_duration": float(weapon.status_duration),
		"heavy": false,
		"life": 2.0,
		"bounces": int(weapon.get("bounces", 0)) + level - 1,
		"hit_ids": [],
		"color": Color("#ffffff") if precision else Color(weapon.color),
	}


func create_enemy_projectile(
	position: Vector2,
	velocity: Vector2,
	damage: float
) -> Dictionary:
	return {
		"owner": "enemy",
		"position": position,
		"velocity": velocity,
		"radius": 8.0,
		"damage": damage,
		"life": 3.0,
		"color": Color("#ff7043"),
	}
