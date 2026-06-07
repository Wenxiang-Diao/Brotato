class_name SliceDataRepository
extends RefCounted

var weapons: Array[Dictionary] = []
var enemies: Dictionary = {}
var rewards: Array[Dictionary] = []
var debuffs: Dictionary = {}
var statuses: Dictionary = {}
var reactions: Dictionary = {}
var run_config: Dictionary = {}
var manifest: Dictionary = {}
var errors: Array[String] = []


func load_all() -> bool:
	errors.clear()
	var manifest_value: Variant = _load_json("res://data/manifest.json")
	if manifest_value is Dictionary:
		manifest = manifest_value
		_validate_manifest()
	else:
		errors.append("manifest.json must contain a Dictionary")
	weapons = _load_json_array("res://data/weapons.json")
	rewards = _load_json_array("res://data/rewards.json")
	enemies = _index_by_id(_load_json_array("res://data/enemies.json"), "enemies")
	debuffs = _index_by_id(_load_json_array("res://data/debuffs.json"), "debuffs")
	statuses = _index_by_id(_load_json_array("res://data/statuses.json"), "statuses")
	reactions = _index_by_id(_load_json_array("res://data/reactions.json"), "reactions")
	var config: Variant = _load_json("res://data/run_config.json")
	if config is Dictionary:
		run_config = config
	else:
		errors.append("run_config.json must contain a Dictionary")
	return errors.is_empty()


func _validate_manifest() -> void:
	if int(manifest.get("schema_version", 0)) != 1:
		errors.append("Unsupported data schema_version: %s" % manifest.get("schema_version", 0))
	var required_files: Variant = manifest.get("required_files", [])
	if not required_files is Array:
		errors.append("manifest required_files must contain an Array")
		return
	for filename in required_files:
		var path: String = "res://data/" + str(filename)
		if not FileAccess.file_exists(path):
			errors.append("Manifest references missing data file: " + path)


func find_by_id(rows: Array[Dictionary], id: String) -> Dictionary:
	for row in rows:
		if str(row.get("id", "")) == id:
			return row
	return {}


func _index_by_id(rows: Array[Dictionary], label: String) -> Dictionary:
	var output: Dictionary = {}
	for row in rows:
		var id: String = str(row.get("id", ""))
		if id.is_empty():
			errors.append("%s contains an entry without id" % label)
		elif output.has(id):
			errors.append("%s contains duplicate id: %s" % [label, id])
		else:
			output[id] = row
	return output


func _load_json_array(path: String) -> Array[Dictionary]:
	var value: Variant = _load_json(path)
	var output: Array[Dictionary] = []
	if value is Array:
		for row in value:
			if row is Dictionary:
				output.append(row)
			else:
				errors.append("%s contains a non-Dictionary entry" % path)
	else:
		errors.append("%s must contain an Array" % path)
	return output


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("Missing data file: " + path)
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("Cannot open data file: " + path)
		return null
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(file.get_as_text())
	if parse_error != OK:
		errors.append("Invalid JSON %s: %s at line %d" % [path, json.get_error_message(), json.get_error_line()])
		return null
	return json.data
