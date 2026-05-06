extends SceneTree

const ModioListingQuery = preload("res://src/models/modio_listing_query.gd")
const ModioVendorAdapter = preload("res://src/modio_vendor_adapter.gd")
const ModioHttpTransport = preload("res://src/network/modio_http_transport.gd")
const ModioLiveHarness = preload("res://modio_live_harness_lib.gd")

func _initialize() -> void:
	var harness := ModioLiveHarness.new()
	var options := harness.parse_args(OS.get_cmdline_user_args())
	var errors: PackedStringArray = options.get("errors", PackedStringArray())

	if bool(options.get("help", false)):
		print(harness.help_text())
		quit(0)
		return

	if not errors.is_empty():
		_print_failures(errors, bool(options.get("json", false)))
		quit(1)
		return

	var plan := harness.build_run_plan(options)
	var warnings := harness.build_missing_config_warnings(plan)
	if not warnings.is_empty():
		_print_failures(warnings, bool(options.get("json", false)))
		quit(1)
		return

	var config = plan.config
	var adapter := ModioVendorAdapter.new(config, ModioHttpTransport.new())
	var results: Array[Dictionary] = []

	results.append(_run_ping_check(adapter, config))
	results.append(_run_game_check(adapter, config))
	results.append(_run_mods_check(adapter, config, int(plan.get("mods_limit", 3))))
	results.append_array(_run_optional_auth_checks(plan, adapter, config))

	var summary := {
		"environment": str(plan.get("environment", "")),
		"base_url": config.resolve_base_url(),
		"host_kind": config.host_kind,
		"game_id": config.game_id,
		"public_only": bool(options.get("public_only", false)),
		"checks": results,
		"ok": _results_are_ok(results)
	}

	if bool(options.get("json", false)):
		print(JSON.stringify(summary, "  "))
	else:
		_print_human_summary(summary)

	quit(0 if bool(summary.ok) else 1)

func _run_ping_check(adapter: ModioVendorAdapter, config) -> Dictionary:
	var harness := ModioLiveHarness.new()
	var request := adapter.build_ping_request()
	if config.has_public_credentials():
		var query: Dictionary = request.get("query", {}).duplicate(true)
		query["api_key"] = config.api_key
		request["query"] = query
	return _run_check(
		"ping",
		"Ping mod.io API",
		request,
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_ping_response(response)
	)

func _run_game_check(adapter: ModioVendorAdapter, config) -> Dictionary:
	var harness := ModioLiveHarness.new()
	return _run_check(
		"game",
		"Read configured game detail",
		adapter.build_game_request(),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_game_response(adapter, response)
	)

func _run_mods_check(adapter: ModioVendorAdapter, config, mods_limit: int) -> Dictionary:
	var harness := ModioLiveHarness.new()
	var query := ModioListingQuery.new("", PackedStringArray(), mods_limit, 0)
	return _run_check(
		"mods",
		"Browse configured game mods",
		adapter.build_listing_request(query),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_mods_response(response)
	)

func _run_optional_auth_checks(plan: Dictionary, adapter: ModioVendorAdapter, config) -> Array[Dictionary]:
	var harness := ModioLiveHarness.new()
	var results: Array[Dictionary] = []
	for check in plan.get("checks", []):
		if not (check is Dictionary):
			continue
		if str(check.get("id", "")) != "me":
			continue
		if bool(check.get("skip", false)):
			results.append({
				"id": "me",
				"label": str(check.get("label", "Read authenticated user profile")),
				"status": "skipped",
				"details": {"reason": str(check.get("skip_reason", "Skipped"))}
			})
			continue
		results.append(_run_check(
			"me",
			"Read authenticated user profile",
			adapter.build_authenticated_user_request(),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_authenticated_user_response(adapter, response)
		))
	return results

func _run_check(id: String, label: String, request: Dictionary, config, detail_builder: Callable) -> Dictionary:
	var transport := ModioHttpTransport.new()
	var response := transport.execute(request, config)
	if bool(response.get("ok", false)):
		return {
			"id": id,
			"label": label,
			"status": "ok",
			"status_code": int(response.get("status_code", 0)),
			"details": detail_builder.call(response) if detail_builder.is_valid() else {}
		}

	var error_info: Dictionary = response.get("error", {})
	return {
		"id": id,
		"label": label,
		"status": "failed",
		"status_code": int(response.get("status_code", 0)),
		"details": {
			"message": str(error_info.get("message", response.get("transport_error", "Unknown error"))),
			"category": str(error_info.get("category", "transport")),
			"error_ref": int(error_info.get("error_ref", 0))
		}
	}

func _results_are_ok(results: Array[Dictionary]) -> bool:
	for result in results:
		if str(result.get("status", "")) == "failed":
			return false
	return true

func _print_human_summary(summary: Dictionary) -> void:
	print("mod.io safe harness")
	print("  environment: %s" % str(summary.get("environment", "")))
	print("  host_kind: %s" % str(summary.get("host_kind", "")))
	print("  base_url: %s" % str(summary.get("base_url", "")))
	print("  game_id: %s" % str(summary.get("game_id", "")))
	for check in summary.get("checks", []):
		if not (check is Dictionary):
			continue
		print("  [%s] %s" % [str(check.get("status", "unknown")).to_upper(), str(check.get("label", check.get("id", "check")))])
		var details: Dictionary = check.get("details", {})
		for key in details.keys():
			print("    %s: %s" % [str(key), str(details[key])])

func _print_failures(messages: PackedStringArray, as_json: bool) -> void:
	if as_json:
		print(JSON.stringify({"ok": false, "errors": messages}, "  "))
		return
	for message in messages:
		push_error(message)
		print(message)
