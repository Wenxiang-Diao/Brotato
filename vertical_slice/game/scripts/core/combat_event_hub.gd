class_name CombatEventHub
extends RefCounted

signal damage_resolved(event: Dictionary)
signal status_applied(event: Dictionary)
signal reaction_triggered(event: Dictionary)


func publish_damage(event: Dictionary) -> void:
	damage_resolved.emit(event)


func publish_status(event: Dictionary) -> void:
	status_applied.emit(event)


func publish_reaction(event: Dictionary) -> void:
	reaction_triggered.emit(event)
