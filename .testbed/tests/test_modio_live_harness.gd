extends GutTest

const ModioEnvLoader = preload("res://modio_env_loader.gd")
const ModioLiveHarness = preload("res://modio_live_harness_lib.gd")
const ModioVendorAdapter = preload("res://src/modio_vendor_adapter.gd")

const STABLE_PATH := "user://modio_live_harness_stable.cfg"
const SESSION_PATH := "user://modio_live_harness_session.cfg"

func after_each() -> void:
	_cleanup_file(STABLE_PATH)
	_cleanup_file(SESSION_PATH)

func test_parse_args_supports_safe_cli_flags() -> void:
	var harness := ModioLiveHarness.new()
	var options := harness.parse_args([
		"--env", "live",
		"--mods-limit", "9",
		"--public-only",
		"--json",
		"--stable-config", "user://stable.cfg",
		"--session-config", "user://session.cfg"
	])

	assert_eq(options.env, "live")
	assert_eq(options.mods_limit, 9)
	assert_true(options.public_only)
	assert_true(options.json)
	assert_eq(options.stable_path, "user://stable.cfg")
	assert_eq(options.session_path, "user://session.cfg")
	assert_true(options.errors.is_empty())

func test_parse_args_rejects_invalid_environment_and_missing_values() -> void:
	var harness := ModioLiveHarness.new()
	var options := harness.parse_args(["--env", "preview", "--mods-limit"])

	assert_eq(options.errors.size(), 2)
	assert_true("Unsupported environment: preview" in options.errors)
	assert_true("Missing value for --mods-limit" in options.errors)

func test_build_run_plan_marks_optional_auth_check_skipped_when_no_token() -> void:
	_write_config(STABLE_PATH, _stable_config("test"))
	_write_config(SESSION_PATH, _session_config("", "", ""))

	var harness := ModioLiveHarness.new()
	var plan := harness.build_run_plan({
		"env": "",
		"mods_limit": 3,
		"public_only": false,
		"stable_path": STABLE_PATH,
		"session_path": SESSION_PATH
	})

	assert_eq(plan.environment, "test")
	assert_eq(plan.checks.size(), 4)
	assert_eq(plan.checks[3].id, "me")
	assert_true(plan.checks[3].skip)
	assert_eq(plan.checks[3].skip_reason, "No access token configured in session config")

func test_build_run_plan_includes_optional_auth_check_when_token_exists() -> void:
	_write_config(STABLE_PATH, _stable_config("test"))
	_write_config(SESSION_PATH, _session_config("", "", "session-token"))

	var harness := ModioLiveHarness.new()
	var plan := harness.build_run_plan({
		"env": "live",
		"mods_limit": 5,
		"public_only": false,
		"stable_path": STABLE_PATH,
		"session_path": SESSION_PATH
	})

	assert_eq(plan.environment, "live")
	assert_false(plan.config.use_test_environment)
	assert_false(bool(plan.checks[3].get("skip", false)))

func test_build_missing_config_warnings_detects_required_public_tuple() -> void:
	_write_config(STABLE_PATH, "[modio]\ndefault_environment=\"test\"\n\n[modio.test]\ngame_id=\"\"\napi_key=\"\"\n\n[modio.live]\ngame_id=\"2001\"\napi_key=\"live-key\"\n")
	_write_config(SESSION_PATH, _session_config("", "", ""))

	var harness := ModioLiveHarness.new()
	var plan := harness.build_run_plan({
		"env": "test",
		"mods_limit": 3,
		"public_only": true,
		"stable_path": STABLE_PATH,
		"session_path": SESSION_PATH
	})
	var warnings := harness.build_missing_config_warnings(plan)

	assert_true("Selected environment is missing game_id" in warnings)
	assert_true("Selected environment is missing api_key" in warnings)

func test_summarize_game_response_reads_top_level_detail_payload() -> void:
	var harness := ModioLiveHarness.new()
	var adapter := ModioVendorAdapter.new()
	var summary := harness.summarize_game_response(adapter, {"payload": _fixture("game.json")})

	assert_eq(summary.id, 777)
	assert_eq(summary.name, "AeroBeat")
	assert_eq(summary.status, -1)

func test_summarize_authenticated_user_response_reads_top_level_detail_payload() -> void:
	var harness := ModioLiveHarness.new()
	var adapter := ModioVendorAdapter.new()
	var summary := harness.summarize_authenticated_user_response(adapter, {"payload": _fixture("me.json")})

	assert_eq(summary.id, 42)
	assert_eq(summary.name_id, "aerobeat-player")
	assert_eq(summary.username, "AeroBeatPlayer")

func test_summarize_mods_response_reports_requested_limit_separately_from_server_page_echo() -> void:
	var harness := ModioLiveHarness.new()
	var summary := harness.summarize_mods_response({"payload": _fixture("mods.json")}, 3)

	assert_eq(summary.requested_limit, 3)
	assert_eq(summary.response_result_count, 1)
	assert_eq(summary.response_result_limit, 10)
	assert_eq(summary.response_result_offset, 5)
	assert_eq(summary.response_result_total, 13)
	assert_eq(summary.sample_mod_names.size(), 1)
	assert_eq(summary.sample_mod_names[0], "Cardio Blaster")

func _stable_config(default_environment: String) -> String:
	return "".join([
		"[modio]\n",
		"default_environment=\"%s\"\n" % default_environment,
		"accept_language=\"en-US\"\n",
		"host_kind=\"api\"\n",
		"\n",
		"[modio.test]\n",
		"game_id=\"1001\"\n",
		"api_key=\"test-key\"\n",
		"base_url=\"\"\n",
		"service_token=\"\"\n",
		"portal=\"steam\"\n",
		"platform=\"WINDOWS\"\n",
		"monetization_team_id=\"\"\n",
		"\n",
		"[modio.live]\n",
		"game_id=\"2001\"\n",
		"api_key=\"live-key\"\n",
		"base_url=\"\"\n",
		"service_token=\"\"\n",
		"portal=\"steam\"\n",
		"platform=\"WINDOWS\"\n",
		"monetization_team_id=\"\"\n"
	])

func _session_config(environment: String, host_kind: String, access_token: String) -> String:
	return "".join([
		"[modio]\n",
		"environment=\"%s\"\n" % environment,
		"host_kind=\"%s\"\n" % host_kind,
		"\n",
		"[modio.test]\n",
		"access_token=\"%s\"\n" % access_token,
		"user_id=\"1111\"\n",
		"\n",
		"[modio.live]\n",
		"access_token=\"%s\"\n" % access_token,
		"user_id=\"2222\"\n"
	])

func _write_config(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func _cleanup_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _fixture(name: String) -> Dictionary:
	var path := "res://tests/fixtures/%s" % name
	var text := FileAccess.get_file_as_string(path)
	return JSON.parse_string(text)
