class_name InputDeviceManager
extends Node

signal device_changed(device: StringName)

const KEYBOARD_MOUSE := &"keyboard_mouse"
const GAMEPAD := &"gamepad"

var current_device: StringName = KEYBOARD_MOUSE


func _input(event: InputEvent) -> void:
	var next_device := current_device
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		next_device = GAMEPAD
	elif event is InputEventKey or event is InputEventMouse:
		next_device = KEYBOARD_MOUSE
	if next_device != current_device:
		current_device = next_device
		device_changed.emit(current_device)


func prompt(keyboard_text: String, gamepad_text: String) -> String:
	return gamepad_text if current_device == GAMEPAD else keyboard_text
