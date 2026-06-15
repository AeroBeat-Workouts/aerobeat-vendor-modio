class_name ModioSceneRunner
extends RefCounted

const STABLE_CONFIG_PATH := "res://configs/modio.local.cfg"
const SESSION_CONFIG_PATH := "res://configs/modio.session.local.cfg"
const VALID_ENVIRONMENTS := ["test", "live"]
const DEFAULT_BASE_URL := "https://api.mod.io/v1"

func build_manager(explicit_env: String = "") -> Dictionary:
	var stable := ConfigFile.new()
	var session := ConfigFile.new()
	var stable_loaded := stable.load(STABLE_CONFIG_PATH) == OK
	var session_loaded := session.load(SESSION_CONFIG_PATH) == OK
	var environment := _resolve_environment(explicit_env, stable, stable_loaded)
	var stable_section := "modio.%s" % environment
	var session_section := "modio.%s" % environment
	var runtime := {
		"base_url": _resolve_base_url(stable, stable_section),
		"game_id": _read_string(stable, stable_section, "game_id"),
		"host_kind": _read_string(stable, stable_section, "host_kind", "api"),
		"has_access_token": not _read_string(session, session_section, "access_token").is_empty(),
		"has_service_token": not _read_string(stable, stable_section, "service_token").is_empty()
	}
	return {
		"environment": environment,
		"runtime": runtime,
		"warnings": _build_missing_config_warnings(stable_loaded, session_loaded, runtime),
		"config": {
			"owned_mod_id": _read_string(stable, stable_section, "owned_mod_id"),
			"paid_mod_id": _read_string(stable, stable_section, "paid_mod_id"),
			"monetization_team_id": _read_string(stable, stable_section, "monetization_team_id"),
			"s2s_transaction_id": _read_string(session, session_section, "s2s_transaction_id"),
			"s2s_filters_team_id": _json_field_string(session, session_section, "s2s_filters_json", "monetization_team_id"),
			"checkout_mod_id": _json_field_string(session, session_section, "checkout_payload_json", "mod_id"),
			"has_checkout_payload": _has_json_dictionary(session, session_section, "checkout_payload_json"),
			"has_entitlements_payload": _has_json_dictionary(session, session_section, "entitlements_payload_json"),
			"has_access_token": runtime.has_access_token,
			"has_service_token": runtime.has_service_token
		}
	}

func run_group(group_id: String, explicit_env: String = "") -> Dictionary:
	var context = build_manager(explicit_env)
	return {
		"group": group_id,
		"environment": str(context.get("environment", "")),
		"runtime": context.get("runtime", {}),
		"warnings": context.get("warnings", PackedStringArray()),
		"overview": _build_group_overview(group_id),
		"checks": _build_group_checks(group_id, context.get("config", {})),
		"ok": PackedStringArray(context.get("warnings", PackedStringArray())).is_empty()
	}

func stringify_report(report: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("group: %s" % str(report.get("group", "")))
	lines.append("environment: %s" % str(report.get("environment", "")))
	var runtime: Dictionary = report.get("runtime", {})
	lines.append("base_url: %s" % str(runtime.get("base_url", "")))
	lines.append("game_id: %s" % str(runtime.get("game_id", "")))
	lines.append("ok: %s" % str(report.get("ok", false)))
	var overview: Dictionary = report.get("overview", {})
	if not overview.is_empty():
		if overview.has("run_checks_scope"):
			lines.append("run_checks_scope: %s" % str(overview.get("run_checks_scope", "")))
		if overview.has("run_checks_behavior"):
			lines.append("run_checks_behavior: %s" % str(overview.get("run_checks_behavior", "")))
		if overview.has("open_question"):
			lines.append("open_question: %s" % str(overview.get("open_question", "")))
	var warnings: PackedStringArray = report.get("warnings", PackedStringArray())
	if not warnings.is_empty():
		lines.append("warnings:")
		for warning in warnings:
			lines.append("  - %s" % warning)
	for check in report.get("checks", []):
		if not (check is Dictionary):
			continue
		lines.append("")
		lines.append("[%s] %s" % [str(check.get("status", "unknown")).to_upper(), str(check.get("label", check.get("id", "check")))])
		var details: Dictionary = check.get("details", {})
		for key in details.keys():
			lines.append("  %s: %s" % [str(key), str(details.get(key))])
	return "\n".join(lines)

func _build_group_checks(group_id: String, config: Dictionary) -> Array[Dictionary]:
	match group_id:
		"public_catalog":
			return [
				_ready_check("ping", "Ping mod.io API"),
				_ready_check("game", "Read configured game detail"),
				_ready_check("mods", "Browse configured game mods"),
				_ready_check("mod_children", "Inspect first listed public mod child endpoints"),
				_ready_check("terms", "Read authentication terms")
			]
		"authenticated_user":
			if bool(config.get("has_access_token", false)):
				return [
					_ready_check("me", "Read authenticated user profile"),
					_ready_check("user_reads", "Inspect authenticated user-state endpoints")
				]
			return [_skipped_check("auth", "Run authenticated user checks", "No access token configured in .testbed/configs/modio.session.local.cfg")]
		"safe_write":
			if bool(config.get("has_access_token", false)):
				return [
					_ready_check("safe_write", "Run reversible sandbox subscribe / unsubscribe / rating checks"),
					_skipped_check("safe_write_guard", "Paid/team/S2S write lanes", "Preserved safe-write posture outside the scene-based slice")
				]
			return [_skipped_check("safe_write", "Run reversible sandbox write checks", "No access token configured in .testbed/configs/modio.session.local.cfg")]
		"paid_mods":
			return _build_paid_mods_route_groups(config)
	return [_skipped_check("unknown", "Unknown scene group", "Unsupported scene group: %s" % group_id)]

func _build_group_overview(group_id: String) -> Dictionary:
	if group_id != "paid_mods":
		return {}
	return {
		"run_checks_scope": "Bearer reads, owned-mod read, guarded buyer writes, and S2S/history reads.",
		"run_checks_behavior": "Scene Run Checks reports route groups + prerequisites only. CLI --paid-mods executes the same narrow matrix, while buyer writes still require --allow-paid-writes.",
		"open_question": "Current harness keeps S2S/history behind service_token. Treat that as the current implementation, not a proven mod.io requirement."
	}

func _build_missing_config_warnings(stable_loaded: bool, session_loaded: bool, runtime: Dictionary) -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not stable_loaded:
		warnings.append("Stable config could not be loaded from %s" % STABLE_CONFIG_PATH)
	if not session_loaded:
		warnings.append("Session config could not be loaded from %s" % SESSION_CONFIG_PATH)
	if str(runtime.get("game_id", "")).is_empty():
		warnings.append("Selected environment is missing game_id")
	return warnings

func _build_paid_mods_route_groups(config: Dictionary) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	groups.append(_route_group(
		"paid_bearer_reads",
		"Bearer reads",
		"GET /games/{game-id}/monetization/token-packs; GET /me/wallets; GET /me/purchased",
		PackedStringArray(["access_token in .testbed/configs/modio.session.local.cfg"]),
		_missing_bearer_read_prereqs(config),
		"Run first. No extra monetization-specific keys beyond normal bearer auth."
	))
	groups.append(_route_group(
		"paid_owned_mod_read",
		"Owned-mod read",
		"GET /games/{game-id}/mods/{owned_mod_id}/monetization/team",
		PackedStringArray(["access_token in .testbed/configs/modio.session.local.cfg", "owned_mod_id or paid_mod_id in .testbed/configs/modio.local.cfg"]),
		_missing_owned_mod_read_prereqs(config),
		"Still needs a concrete paid mod id; that is a route input, not extra wrapper breadth."
	))
	groups.append({
		"id": "paid_buyer_writes",
		"label": "Guarded buyer writes",
		"status": "guarded",
		"details": {
			"routes": "POST /me/entitlements; POST /games/{game-id}/mods/{paid_mod_id}/checkout",
			"requires": "--allow-paid-writes in the CLI harness; access_token in .testbed/configs/modio.session.local.cfg; entitlements_payload_json in .testbed/configs/modio.session.local.cfg; checkout_payload_json in .testbed/configs/modio.session.local.cfg; paid_mod_id or checkout_payload_json.mod_id",
			"missing": "Scene Run Checks does not execute buyer writes. Current config gaps: %s" % _join_missing_list(_missing_buyer_write_prereqs(config)),
			"note": "Payload JSON and paid_mod_id remain inherently required inputs."
		}
	})
	groups.append(_route_group(
		"paid_s2s_history_reads",
		"S2S/history reads",
		"GET /s2s/monetization-teams/{monetization-team-id}/transactions; GET /s2s/monetization-teams/{monetization-team-id}/transactions/{transaction-id}",
		PackedStringArray([
			"service_token in .testbed/configs/modio.local.cfg (current harness assumption)",
			"monetization_team_id in .testbed/configs/modio.local.cfg or s2s_filters_json",
			"transaction_id via s2s_transaction_id or discovery from the history list"
		]),
		_missing_s2s_read_prereqs(config),
		"Open question: mod.io approval may not require service_token here, but the current implementation still does."
	))
	return groups

func _route_group(id: String, label: String, routes: String, requires: PackedStringArray, missing: PackedStringArray, note: String) -> Dictionary:
	var status := "covered" if missing.is_empty() else "blocked"
	return {
		"id": id,
		"label": label,
		"status": status,
		"details": {
			"routes": routes,
			"requires": "; ".join(requires),
			"missing": _join_missing_list(missing),
			"note": note
		}
	}

func _missing_bearer_read_prereqs(config: Dictionary) -> PackedStringArray:
	var missing := PackedStringArray()
	if not bool(config.get("has_access_token", false)):
		missing.append("access_token in .testbed/configs/modio.session.local.cfg")
	return missing

func _missing_owned_mod_read_prereqs(config: Dictionary) -> PackedStringArray:
	var missing := _missing_bearer_read_prereqs(config)
	if _resolve_owned_mod_id(config).is_empty():
		missing.append("owned_mod_id or paid_mod_id in .testbed/configs/modio.local.cfg")
	return missing

func _missing_buyer_write_prereqs(config: Dictionary) -> PackedStringArray:
	var missing := _missing_bearer_read_prereqs(config)
	if not bool(config.get("has_entitlements_payload", false)):
		missing.append("entitlements_payload_json in .testbed/configs/modio.session.local.cfg")
	if not bool(config.get("has_checkout_payload", false)):
		missing.append("checkout_payload_json in .testbed/configs/modio.session.local.cfg")
	if _resolve_paid_mod_id(config).is_empty():
		missing.append("paid_mod_id or checkout_payload_json.mod_id")
	return missing

func _missing_s2s_read_prereqs(config: Dictionary) -> PackedStringArray:
	var missing := PackedStringArray()
	if not bool(config.get("has_service_token", false)):
		missing.append("service_token in .testbed/configs/modio.local.cfg")
	if _resolve_s2s_team_id(config).is_empty():
		missing.append("monetization_team_id in .testbed/configs/modio.local.cfg or s2s_filters_json")
	return missing

func _resolve_owned_mod_id(config: Dictionary) -> String:
	var owned := str(config.get("owned_mod_id", "")).strip_edges()
	if not owned.is_empty():
		return owned
	return str(config.get("paid_mod_id", "")).strip_edges()

func _resolve_paid_mod_id(config: Dictionary) -> String:
	var paid := str(config.get("paid_mod_id", "")).strip_edges()
	if not paid.is_empty():
		return paid
	var checkout_mod_id := str(config.get("checkout_mod_id", "")).strip_edges()
	if not checkout_mod_id.is_empty():
		return checkout_mod_id
	return str(config.get("owned_mod_id", "")).strip_edges()

func _resolve_s2s_team_id(config: Dictionary) -> String:
	var explicit := str(config.get("s2s_filters_team_id", "")).strip_edges()
	if not explicit.is_empty():
		return explicit
	return str(config.get("monetization_team_id", "")).strip_edges()

func _join_missing_list(missing: PackedStringArray) -> String:
	return "none" if missing.is_empty() else "; ".join(missing)

func _resolve_environment(explicit_env: String, stable: ConfigFile, stable_loaded: bool) -> String:
	var cleaned := explicit_env.strip_edges().to_lower()
	if cleaned in VALID_ENVIRONMENTS:
		return cleaned
	if stable_loaded:
		var configured := _read_string(stable, "modio", "default_environment", "test").to_lower()
		if configured in VALID_ENVIRONMENTS:
			return configured
	return "test"

func _resolve_base_url(stable: ConfigFile, section: String) -> String:
	var configured := _read_string(stable, section, "base_url", "").strip_edges().rstrip("/")
	if not configured.is_empty():
		return configured
	var use_test_environment := _read_bool(stable, section, "use_test_environment", false)
	return "https://api.test.mod.io/v1" if use_test_environment else DEFAULT_BASE_URL

func _read_string(config: ConfigFile, section: String, key: String, fallback: String = "") -> String:
	if not config.has_section_key(section, key):
		return fallback
	return str(config.get_value(section, key, fallback)).strip_edges()

func _read_bool(config: ConfigFile, section: String, key: String, fallback: bool = false) -> bool:
	if not config.has_section_key(section, key):
		return fallback
	return bool(config.get_value(section, key, fallback))

func _has_json_dictionary(config: ConfigFile, section: String, key: String) -> bool:
	var raw := _read_string(config, section, key)
	if raw.is_empty():
		return false
	var parsed = JSON.parse_string(raw)
	return parsed is Dictionary and not parsed.is_empty()

func _json_field_string(config: ConfigFile, section: String, key: String, field: String) -> String:
	var raw := _read_string(config, section, key)
	if raw.is_empty():
		return ""
	var parsed = JSON.parse_string(raw)
	if parsed is Dictionary:
		return str(parsed.get(field, "")).strip_edges()
	return ""

func _ready_check(id: String, label: String) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"status": "ready",
		"details": {"mode": "scene-entrypoint"}
	}

func _skipped_check(id: String, label: String, reason: String) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"status": "skipped",
		"details": {"reason": reason}
	}
