class_name TargetingService
extends RefCounted


func nearest_enemy(enemies: Array[Dictionary], position: Vector2, ignored: Array = []) -> int:
	var best: int = -1
	var best_distance: float = INF
	for i in enemies.size():
		var enemy: Dictionary = enemies[i]
		if bool(enemy.get("dead", false)) or ignored.has(enemy.get("uid", -1)):
			continue
		var distance: float = position.distance_squared_to(enemy.position)
		if distance < best_distance:
			best_distance = distance
			best = i
	return best


func precision_target(enemies: Array[Dictionary]) -> int:
	var best: int = -1
	var best_score: float = -INF
	for i in enemies.size():
		var enemy: Dictionary = enemies[i]
		if bool(enemy.get("dead", false)):
			continue
		var statuses: Dictionary = enemy.get("statuses", {})
		var score: float = float(enemy.get("hp", 0.0))
		if statuses.has("mark"):
			score += 100000.0
		if score > best_score:
			best_score = score
			best = i
	return best


func densest_enemy_position(enemies: Array[Dictionary], radius: float) -> Vector2:
	var best: Vector2 = Vector2.ZERO
	var best_count: int = 0
	for candidate in enemies:
		if bool(candidate.get("dead", false)):
			continue
		var count: int = 0
		for enemy in enemies:
			if not bool(enemy.get("dead", false)) and enemy.position.distance_to(candidate.position) < radius:
				count += 1
		if count > best_count:
			best_count = count
			best = candidate.position
	return best


func has_enemy_type(enemies: Array[Dictionary], type_name: String) -> bool:
	for enemy in enemies:
		if not bool(enemy.get("dead", false)) and str(enemy.get("type", "")) == type_name:
			return true
	return false
