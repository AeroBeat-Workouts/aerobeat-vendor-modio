class_name ModioSceneRunner
extends RefCounted

const AeroModIOManager = preload("res://addons/aerobeat-vendor-modio/src/AeroModIOManager.gd")
const ModioEnvLoader = preload("res://scripts/modio_env_loader.gd")

func build_manager(explicit_env: String = "") -> Dictionary:
	var loader = ModioEnvLoader.new()
	var environment = loader.resolve_environment(explicit_env)
	var manager = AeroModIOManager.new(loader.build_client_config(explicit_env))
	return {
		"environment": environment,
		"manager": manager,
		"warnings": _build_missing_config_warnings(manager)
	}

func run_group(group_id: String, explicit_env: String = "") -> Dictionary:
	var context = build_manager(explicit_env)
	var manager = context.get("manager")
	var warnings: PackedStringArray = context.get("warnings", PackedStringArray())
	var checks = _build_group_checks(group_id, manager)
	return {
		"group": group_id,
		"environment": str(context.get("environment", "")),
		"runtime": manager.describe_runtime(),
		"warnings": warnings,
		"checks": checks,
		"ok": warnings.is_empty()
	}

func stringify_report(report: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("group: %s" % str(report.get("group", "")))
	lines.append("environment: %s" % str(report.get("environment", "")))
	var runtime: Dictionary = report.get("runtime", {})
	lines.append("base_url: %s" % str(runtime.get("base_url", "")))
	lines.append("game_id: %s" % str(runtime.get("game_id", "")))
	lines.append("ok: %s" % str(report.get("ok", false)))
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

func _build_group_checks(group_id: String, manager: AeroModIOManager) -> Array[Dictionary]:
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
			if manager.has_access_token():
				return [
					_ready_check("me", "Read authenticated user profile"),
					_ready_check("user_reads", "Inspect authenticated user-state endpoints")
				]
			return [_skipped_check("auth", "Run authenticated user checks", "No access token configured in .testbed/configs/modio.session.local.cfg")]
		"safe_write":
			if manager.has_access_token():
				return [
					_ready_check("safe_write", "Run reversible sandbox subscribe / unsubscribe / rating checks"),
					_skipped_check("safe_write_guard", "Paid/team/S2S write lanes", "Preserved safe-write posture outside the scene-based slice")
				]
			return [_skipped_check("safe_write", "Run reversible sandbox write checks", "No access token configured in .testbed/configs/modio.session.local.cfg")]
		"paid_mods":
			var checks: Array[Dictionary] = []
			if manager.has_access_token():
				checks.append(_ready_check("paid_reads", "Inspect token packs, wallet, purchased mods, and monetization-team reads"))
			else:
				checks.append(_skipped_check("paid_auth", "Inspect authenticated paid-mod surfaces", "No access token configured in .testbed/configs/modio.session.local.cfg"))
			if manager.has_service_token():
				checks.append(_ready_check("paid_s2s_reads", "Inspect S2S transaction history entrypoints"))
			else:
				checks.append(_skipped_check("paid_s2s_reads", "Inspect S2S transaction history entrypoints", "No service_token configured in .testbed/configs/modio.local.cfg"))
			checks.append(_skipped_check("paid_write_guard", "Paid/team/S2S writes", "Checkout, entitlement sync, monetization-team writes, and S2S writes stay guarded"))
			return checks
	return [_skipped_check("unknown", "Unknown scene group", "Unsupported scene group: %s" % group_id)]

func _build_missing_config_warnings(manager: AeroModIOManager) -> PackedStringArray:
	var warnings: PackedStringArray = []
	var config = manager.get_config()
	if config.game_id.is_empty():
		warnings.append("Selected environment is missing game_id")
	if config.api_key.is_empty():
		warnings.append("Selected environment is missing api_key")
	return warnings

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
