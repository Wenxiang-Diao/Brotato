class_name CombatFeedback
extends RefCounted

const MAX_EFFECTS := 80

var effects: Array[Dictionary] = []
var hit_stop_remaining := 0.0
var shake_remaining := 0.0
var shake_duration := 0.0
var shake_strength := 0.0
var screen_flash_remaining := 0.0
var screen_flash_color := Color.TRANSPARENT
var elapsed := 0.0
var reduced_motion := false
var shake_enabled := true
var hit_stop_enabled := true
var flash_intensity := 1.0


func reset() -> void:
	effects.clear()
	hit_stop_remaining = 0.0
	shake_remaining = 0.0
	shake_duration = 0.0
	shake_strength = 0.0
	screen_flash_remaining = 0.0
	screen_flash_color = Color.TRANSPARENT
	elapsed = 0.0


func update(delta: float) -> void:
	elapsed += delta
	hit_stop_remaining = maxf(0.0, hit_stop_remaining - delta)
	shake_remaining = maxf(0.0, shake_remaining - delta)
	screen_flash_remaining = maxf(0.0, screen_flash_remaining - delta)
	for effect in effects:
		effect.time -= delta
	effects = effects.filter(func(effect: Dictionary) -> bool: return float(effect.time) > 0.0)


func trigger_impact(position: Vector2, color: Color, radius: float = 18.0) -> void:
	_add_effect({
		"kind": "impact",
		"position": position,
		"color": color,
		"radius": radius,
		"time": 0.16,
		"duration": 0.16,
	})


func trigger_ring(position: Vector2, color: Color, radius: float, duration: float = 0.28) -> void:
	_add_effect({
		"kind": "ring",
		"position": position,
		"color": color,
		"radius": radius,
		"time": duration,
		"duration": duration,
	})


func trigger_line(start: Vector2, end: Vector2, color: Color, width: float = 2.0) -> void:
	_add_effect({
		"kind": "line",
		"start": start,
		"end": end,
		"color": color,
		"width": width,
		"time": 0.09,
		"duration": 0.09,
	})


func trigger_shake(strength: float, duration: float) -> void:
	if reduced_motion or not shake_enabled:
		return
	if strength >= shake_strength or shake_remaining <= 0.0:
		shake_strength = strength
		shake_duration = duration
	shake_remaining = maxf(shake_remaining, duration)


func trigger_hit_stop(duration: float) -> void:
	if reduced_motion or not hit_stop_enabled:
		return
	hit_stop_remaining = minf(0.05, maxf(hit_stop_remaining, duration))


func trigger_screen_flash(color: Color, duration: float) -> void:
	screen_flash_color = color
	screen_flash_remaining = maxf(screen_flash_remaining, minf(duration, 0.08) if reduced_motion else duration)


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if enabled:
		hit_stop_remaining = 0.0
		shake_remaining = 0.0


func is_simulation_blocked() -> bool:
	return hit_stop_remaining > 0.0


func shake_offset() -> Vector2:
	if shake_remaining <= 0.0 or shake_duration <= 0.0:
		return Vector2.ZERO
	var fade: float = shake_remaining / shake_duration
	return Vector2(
		sin(elapsed * 91.0) * shake_strength * fade,
		cos(elapsed * 73.0) * shake_strength * fade
	)


func screen_flash_alpha() -> float:
	if screen_flash_remaining <= 0.0:
		return 0.0
	var max_alpha: float = (0.14 if reduced_motion else 0.32) * flash_intensity
	return clampf(screen_flash_remaining / 0.18, 0.0, 1.0) * max_alpha


func _add_effect(effect: Dictionary) -> void:
	if effects.size() >= MAX_EFFECTS:
		effects.pop_front()
	effects.append(effect)
