class_name ModioSessionConfigStore
extends RefCounted

func get_storage_path(path: String = ModioEnvLoader.CONFIG_SESSION_PATH) -> String:
	return path

func get_global_storage_path(path: String = ModioEnvLoader.CONFIG_SESSION_PATH) -> String:
	return ProjectSettings.globalize_path(path)

func load_config(path: String = ModioEnvLoader.CONFIG_SESSION_PATH) -> ConfigFile:
	var config := ConfigFile.new()
	if FileAccess.file_exists(path):
		config.load(path)
	return config

func read_environment(path: String = ModioEnvLoader.CONFIG_SESSION_PATH) -> String:
	var config := load_config(path)
	if config.has_section_key("modio", "environment"):
		return str(config.get_value("modio", "environment", "")).strip_edges().to_lower()
	return ""

func read_env_value(environment: String, key: String, path: String = ModioEnvLoader.CONFIG_SESSION_PATH, fallback: String = "") -> String:
	var config := load_config(path)
	var section := _section_name(environment)
	if config.has_section_key(section, key):
		return str(config.get_value(section, key, fallback)).strip_edges()
	return fallback

func save_session_values(environment: String, values: Dictionary, path: String = ModioEnvLoader.CONFIG_SESSION_PATH) -> Dictionary:
	var config := load_config(path)
	var normalized_env := environment.strip_edges().to_lower()
	if normalized_env.is_empty():
		normalized_env = ModioEnvLoader.DEFAULT_ENVIRONMENT
	config.set_value("modio", "environment", normalized_env)
	var section := _section_name(normalized_env)
	for key in values.keys():
		var key_name := str(key)
		if key_name.is_empty():
			continue
		var value_text := str(values[key]).strip_edges()
		config.set_value(section, key_name, value_text)
	var global_path := get_global_storage_path(path)
	var parent_dir := global_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent_dir):
		DirAccess.make_dir_recursive_absolute(parent_dir)
	var save_error := config.save(global_path)
	return {
		"ok": save_error == OK,
		"path": path,
		"global_path": global_path,
		"error_code": save_error
	}

func clear_session_values(environment: String, keys: PackedStringArray, path: String = ModioEnvLoader.CONFIG_SESSION_PATH) -> Dictionary:
	var config := load_config(path)
	var normalized_env := environment.strip_edges().to_lower()
	if normalized_env.is_empty():
		normalized_env = ModioEnvLoader.DEFAULT_ENVIRONMENT
	config.set_value("modio", "environment", normalized_env)
	var section := _section_name(normalized_env)
	for key in keys:
		if config.has_section_key(section, key):
			config.erase_section_key(section, key)
	var global_path := get_global_storage_path(path)
	var save_error := config.save(global_path)
	return {
		"ok": save_error == OK,
		"path": path,
		"global_path": global_path,
		"error_code": save_error
	}

func _section_name(environment: String) -> String:
	return "modio.%s" % environment.strip_edges().to_lower()
