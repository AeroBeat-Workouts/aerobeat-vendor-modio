class_name ModioLiveHarness
extends RefCounted

const ModioClientConfig = preload("res://src/models/modio_client_config.gd")
const ModioEnvLoader = preload("res://modio_env_loader.gd")

const DEFAULT_MODS_LIMIT := 3
const DEFAULT_CHILD_LIMIT := 5

func summarize_ping_response(response: Dictionary) -> Dictionary:
	var payload: Dictionary = response.get("payload", {})
	return {"message": str(payload.get("message", ""))}

func summarize_game_response(adapter, response: Dictionary) -> Dictionary:
	var payload: Dictionary = response.get("payload", {})
	var data: Dictionary = adapter.normalize_game_response(payload)
	return {
		"id": int(data.get("id", 0)),
		"name": str(data.get("name", "")),
		"status": int(payload.get("status", -1))
	}

func summarize_mods_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_MODS_LIMIT) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_mod_list_response(response.get("payload", {}))
	var sample_mod_names: PackedStringArray = []
	var selected_mod_id := 0
	for entry in normalized.get("data", []):
		if not (entry is Dictionary):
			continue
		if sample_mod_names.size() >= requested_limit:
			break
		sample_mod_names.append(str(entry.get("name", "")))
		if selected_mod_id <= 0:
			selected_mod_id = int(entry.get("id", 0))
	return {
		"sample_mod_names": sample_mod_names,
		"selected_mod_id": selected_mod_id,
		"requested_limit": requested_limit,
		"response_result_count": int(normalized.get("result_count", 0)),
		"response_result_limit": int(normalized.get("result_limit", 0)),
		"response_result_offset": int(normalized.get("result_offset", 0)),
		"response_result_total": int(normalized.get("result_total", 0))
	}

func summarize_mod_detail_response(adapter, response: Dictionary) -> Dictionary:
	var data: Dictionary = adapter.normalize_mod_detail_response(response.get("payload", {}))
	return {
		"id": int(data.get("id", 0)),
		"name": str(data.get("name", "")),
		"name_id": str(data.get("name_id", "")),
		"status": int(data.get("status", 0)),
		"visible": int(data.get("visible", 0))
	}

func summarize_modfiles_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_CHILD_LIMIT) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_modfiles_response(response.get("payload", {}))
	var sample_filenames: PackedStringArray = []
	var selected_file_id := 0
	for entry in normalized.get("data", []):
		if not (entry is Dictionary):
			continue
		if sample_filenames.size() >= requested_limit:
			break
		sample_filenames.append(str(entry.get("filename", "")))
		if selected_file_id <= 0:
			selected_file_id = int(entry.get("id", 0))
	return {
		"sample_filenames": sample_filenames,
		"selected_file_id": selected_file_id,
		"response_result_count": int(normalized.get("result_count", 0)),
		"response_result_limit": int(normalized.get("result_limit", 0)),
		"response_result_offset": int(normalized.get("result_offset", 0)),
		"response_result_total": int(normalized.get("result_total", 0))
	}

func summarize_modfile_response(adapter, response: Dictionary) -> Dictionary:
	var data: Dictionary = adapter.normalize_modfile_response(response.get("payload", {}))
	return {
		"id": int(data.get("id", 0)),
		"filename": str(data.get("filename", "")),
		"version": str(data.get("version", "")),
		"filesize": int(data.get("filesize", 0))
	}

func summarize_mod_stats_response(adapter, response: Dictionary) -> Dictionary:
	var data: Dictionary = adapter.normalize_mod_stats_response(response.get("payload", {}))
	return {
		"mod_id": int(data.get("mod_id", 0)),
		"downloads_total": int(data.get("downloads_total", 0)),
		"subscribers_total": int(data.get("subscribers_total", 0)),
		"ratings_total": int(data.get("ratings_total", 0)),
		"has_expiry": bool(data.get("has_expiry", false)),
		"is_stale": bool(data.get("is_stale", false))
	}

func summarize_dependants_response(adapter, response: Dictionary) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_dependants_response(response.get("payload", {}))
	var first_name := ""
	var data = normalized.get("data", [])
	if data is Array and not data.is_empty() and data[0] is Dictionary:
		first_name = str(data[0].get("name", ""))
	return {
		"first_name": first_name,
		"response_result_count": int(normalized.get("result_count", 0)),
		"response_result_limit": int(normalized.get("result_limit", 0)),
		"response_result_offset": int(normalized.get("result_offset", 0)),
		"response_result_total": int(normalized.get("result_total", 0))
	}

func summarize_mod_tags_response(adapter, response: Dictionary) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_mod_tags_response(response.get("payload", {}))
	var names: PackedStringArray = []
	for entry in normalized.get("data", []):
		if entry is Dictionary:
			names.append(str(entry.get("name", "")))
	return {
		"names": names,
		"response_result_count": int(normalized.get("result_count", 0)),
		"response_result_limit": int(normalized.get("result_limit", 0)),
		"response_result_offset": int(normalized.get("result_offset", 0)),
		"response_result_total": int(normalized.get("result_total", 0))
	}

func summarize_mod_metadata_kvp_response(adapter, response: Dictionary) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_mod_metadata_kvp_response(response.get("payload", {}))
	var pairs: Array[String] = []
	for entry in normalized.get("data", []):
		if entry is Dictionary:
			pairs.append("%s=%s" % [str(entry.get("metakey", "")), str(entry.get("metavalue", ""))])
	return {
		"pairs": pairs,
		"response_result_count": int(normalized.get("result_count", 0)),
		"response_result_limit": int(normalized.get("result_limit", 0)),
		"response_result_offset": int(normalized.get("result_offset", 0)),
		"response_result_total": int(normalized.get("result_total", 0))
	}

func summarize_mod_team_response(adapter, response: Dictionary) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_mod_team_response(response.get("payload", {}))
	var usernames: PackedStringArray = []
	for entry in normalized.get("data", []):
		if not (entry is Dictionary):
			continue
		var user: Dictionary = entry.get("user", {})
		usernames.append(str(user.get("username", "")))
	return {
		"usernames": usernames,
		"response_result_count": int(normalized.get("result_count", 0)),
		"response_result_limit": int(normalized.get("result_limit", 0)),
		"response_result_offset": int(normalized.get("result_offset", 0)),
		"response_result_total": int(normalized.get("result_total", 0))
	}

func summarize_dependencies_response(adapter, response: Dictionary) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_dependencies_response(response.get("payload", {}), false)
	var names: PackedStringArray = []
	for entry in normalized.get("data", []):
		if entry is Dictionary:
			names.append(str(entry.get("name", "")))
	return {
		"names": names,
		"response_result_count": int(normalized.get("result_count", 0)),
		"response_result_limit": int(normalized.get("result_limit", 0)),
		"response_result_offset": int(normalized.get("result_offset", 0)),
		"response_result_total": int(normalized.get("result_total", 0)),
		"recursive_requested": bool(normalized.get("resolution", {}).get("recursive_requested", false))
	}

func summarize_authenticated_user_response(adapter, response: Dictionary) -> Dictionary:
	var payload: Dictionary = response.get("payload", {})
	var data: Dictionary = adapter.normalize_authenticated_user_response(payload)
	return {
		"id": int(data.get("id", 0)),
		"username": str(data.get("username", "")),
		"name_id": str(data.get("name_id", ""))
	}

func parse_args(args: PackedStringArray) -> Dictionary:
	var options := {
		"env": "",
		"mods_limit": DEFAULT_MODS_LIMIT,
		"json": false,
		"help": false,
		"public_only": false,
		"stable_path": ModioEnvLoader.CONFIG_STABLE_PATH,
		"session_path": ModioEnvLoader.CONFIG_SESSION_PATH,
		"errors": PackedStringArray()
	}

	var index := 0
	while index < args.size():
		var arg := String(args[index])
		match arg:
			"--help", "-h":
				options.help = true
			"--json":
				options.json = true
			"--public-only":
				options.public_only = true
			"--env":
				index += 1
				if index >= args.size():
					_append_error(options, "Missing value for --env")
				else:
					options.env = String(args[index]).strip_edges().to_lower()
			"--mods-limit":
				index += 1
				if index >= args.size():
					_append_error(options, "Missing value for --mods-limit")
				else:
					var raw_value := String(args[index]).strip_edges()
					if not raw_value.is_valid_int():
						_append_error(options, "Invalid --mods-limit value: %s" % raw_value)
					else:
						options.mods_limit = clampi(raw_value.to_int(), 1, 100)
			"--stable-config":
				index += 1
				if index >= args.size():
					_append_error(options, "Missing value for --stable-config")
				else:
					options.stable_path = String(args[index]).strip_edges()
			"--session-config":
				index += 1
				if index >= args.size():
					_append_error(options, "Missing value for --session-config")
				else:
					options.session_path = String(args[index]).strip_edges()
			_:
				_append_error(options, "Unknown argument: %s" % arg)
		index += 1

	if not options.env.is_empty() and not options.env in ModioEnvLoader.VALID_ENVIRONMENTS:
		_append_error(options, "Unsupported environment: %s" % options.env)

	return options

func build_run_plan(options: Dictionary, loader: ModioEnvLoader = ModioEnvLoader.new()) -> Dictionary:
	var resolved_env := loader.resolve_environment(
		str(options.get("env", "")),
		str(options.get("stable_path", ModioEnvLoader.CONFIG_STABLE_PATH)),
		str(options.get("session_path", ModioEnvLoader.CONFIG_SESSION_PATH))
	)
	var config := loader.build_client_config(
		str(options.get("env", "")),
		str(options.get("stable_path", ModioEnvLoader.CONFIG_STABLE_PATH)),
		str(options.get("session_path", ModioEnvLoader.CONFIG_SESSION_PATH))
	)
	var checks: Array[Dictionary] = [
		{
			"id": "ping",
			"label": "Ping mod.io API",
			"kind": "public"
		},
		{
			"id": "game",
			"label": "Read configured game detail",
			"kind": "public"
		},
		{
			"id": "mods",
			"label": "Browse configured game mods",
			"kind": "public"
		}
	]
	if bool(options.get("public_only", false)):
		checks.append({
			"id": "me",
			"label": "Read authenticated user profile",
			"kind": "auth",
			"skip": true,
			"skip_reason": "Skipped by --public-only"
		})
	elif config.has_access_token():
		checks.append({
			"id": "me",
			"label": "Read authenticated user profile",
			"kind": "auth"
		})
	else:
		checks.append({
			"id": "me",
			"label": "Read authenticated user profile",
			"kind": "auth",
			"skip": true,
			"skip_reason": "No access token configured in session config"
		})

	return {
		"environment": resolved_env,
		"config": config,
		"checks": checks,
		"mods_limit": int(options.get("mods_limit", DEFAULT_MODS_LIMIT)),
		"stable_path": str(options.get("stable_path", ModioEnvLoader.CONFIG_STABLE_PATH)),
		"session_path": str(options.get("session_path", ModioEnvLoader.CONFIG_SESSION_PATH))
	}

func build_missing_config_warnings(plan: Dictionary) -> PackedStringArray:
	var warnings: PackedStringArray = []
	var config: ModioClientConfig = plan.config
	if config.game_id.is_empty():
		warnings.append("Selected environment is missing game_id")
	if config.api_key.is_empty():
		warnings.append("Selected environment is missing api_key")
	return warnings

func help_text() -> String:
	return "\n".join([
		"Safe mod.io live harness",
		"",
		"Usage:",
		"  godot --headless --path .testbed --script res://modio_live_harness.gd -- [options]",
		"",
		"Options:",
		"  --env test|live           Explicit environment selection (default: resolved from config, fallback test)",
		"  --mods-limit <1..100>     Browse-read limit for the mods listing check (default: %d)" % DEFAULT_MODS_LIMIT,
		"  --public-only             Skip optional authenticated /me check even if a token exists",
		"  --stable-config <path>    Override stable config path (default: res://modio.local.cfg)",
		"  --session-config <path>   Override session config path (default: res://modio.session.local.cfg)",
		"  --json                    Emit machine-readable JSON summary",
		"  --help                    Show this help",
		"",
		"Default checks are non-destructive:",
		"  1. GET /ping",
		"  2. GET /games/{game-id}",
		"  3. GET /games/{game-id}/mods",
		"  4. When at least one public mod exists, also check detail/files/file-detail/stats/tags/metadatakvp/team/dependants/dependencies on the first listed mod",
		"  5. Optional GET /me when an access token is present",
		"",
		"The harness never performs write flows. Test is the default environment unless you explicitly",
		"select live via --env live, MODIO_ENV=live, or the local cfg override chain.",
	])

func _append_error(options: Dictionary, message: String) -> void:
	var errors: PackedStringArray = options.get("errors", PackedStringArray())
	errors.append(message)
	options.errors = errors
