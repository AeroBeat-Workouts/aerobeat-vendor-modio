class_name ModioLiveHarness
extends RefCounted

const ModioClientConfig = preload("res://src/models/modio_client_config.gd")
const ModioEnvLoader = preload("res://modio_env_loader.gd")

const DEFAULT_MODS_LIMIT := 3

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

func summarize_mods_response(response: Dictionary, requested_limit: int = DEFAULT_MODS_LIMIT) -> Dictionary:
	var payload: Dictionary = response.get("payload", {})
	var sample_mod_names: PackedStringArray = []
	var data: Variant = payload.get("data", [])
	if data is Array:
		for entry in data:
			if sample_mod_names.size() >= requested_limit:
				break
			if entry is Dictionary:
				sample_mod_names.append(str(entry.get("name", "")))
	return {
		"sample_mod_names": sample_mod_names,
		"requested_limit": requested_limit,
		"response_result_count": int(payload.get("result_count", 0)),
		"response_result_limit": int(payload.get("result_limit", 0)),
		"response_result_offset": int(payload.get("result_offset", 0)),
		"response_result_total": int(payload.get("result_total", 0))
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
		"  4. Optional GET /me when an access token is present",
		"",
		"The harness never performs write flows. Test is the default environment unless you explicitly",
		"select live via --env live, MODIO_ENV=live, or the local cfg override chain.",
	])

func _append_error(options: Dictionary, message: String) -> void:
	var errors: PackedStringArray = options.get("errors", PackedStringArray())
	errors.append(message)
	options.errors = errors
