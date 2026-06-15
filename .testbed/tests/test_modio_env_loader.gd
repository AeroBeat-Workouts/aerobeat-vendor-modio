extends GutTest

const ModioClientConfig = preload("res://src/models/modio_client_config.gd")
const ModioEnvLoader = preload("res://modio_env_loader.gd")

const STABLE_PATH := "user://modio_env_loader_stable.cfg"
const SESSION_PATH := "user://modio_env_loader_session.cfg"

func after_each() -> void:
	_cleanup_file(STABLE_PATH)
	_cleanup_file(SESSION_PATH)

func test_explicit_env_selection_wins() -> void:
	_write_config(STABLE_PATH, _stable_config("test"))
	_write_config(SESSION_PATH, _session_config("live", "user"))

	var loader := ModioEnvLoader.new()
	var config := loader.build_client_config("live", STABLE_PATH, SESSION_PATH)

	assert_false(config.use_test_environment)
	assert_eq(config.host_kind, ModioClientConfig.HOST_USER)
	assert_eq(config.user_id, "2222")
	assert_eq(config.access_token, "live-token")

func test_env_var_selection_precedes_session_and_default() -> void:
	_write_config(STABLE_PATH, _stable_config("test"))
	_write_config(SESSION_PATH, _session_config("test", ""))

	var loader := ModioEnvLoader.new()
	var config := loader.build_client_config("", STABLE_PATH, SESSION_PATH, "live")

	assert_false(config.use_test_environment)
	assert_eq(config.api_key, "live-key")

func test_session_override_precedes_default() -> void:
	_write_config(STABLE_PATH, _stable_config("test"))
	_write_config(SESSION_PATH, _session_config("live", ""))

	var loader := ModioEnvLoader.new()
	var config := loader.build_client_config("", STABLE_PATH, SESSION_PATH)

	assert_false(config.use_test_environment)
	assert_eq(config.api_key, "live-key")

func test_default_environment_used_when_no_override() -> void:
	_write_config(STABLE_PATH, _stable_config("live"))
	_write_config(SESSION_PATH, _session_config("", ""))

	var loader := ModioEnvLoader.new()
	var config := loader.build_client_config("", STABLE_PATH, SESSION_PATH)

	assert_false(config.use_test_environment)
	assert_eq(config.game_id, "2001")

func test_fallback_environment_is_test_when_unset() -> void:
	_write_config(STABLE_PATH, _stable_config(""))
	_write_config(SESSION_PATH, _session_config("", ""))

	var loader := ModioEnvLoader.new()
	var config := loader.build_client_config("", STABLE_PATH, SESSION_PATH)

	assert_true(config.use_test_environment)
	assert_eq(config.game_id, "1001")

func test_invalid_environment_values_fallback_to_test() -> void:
	_write_config(STABLE_PATH, _stable_config("staging"))
	_write_config(SESSION_PATH, _session_config("preview", ""))

	var loader := ModioEnvLoader.new()
	var config := loader.build_client_config("qa", STABLE_PATH, SESSION_PATH)

	assert_true(config.use_test_environment)
	assert_eq(config.game_id, "1001")

func test_session_host_kind_override_applies() -> void:
	_write_config(STABLE_PATH, _stable_config("test"))
	_write_config(SESSION_PATH, _session_config("", "user"))

	var loader := ModioEnvLoader.new()
	var config := loader.build_client_config("", STABLE_PATH, SESSION_PATH)

	assert_eq(config.host_kind, ModioClientConfig.HOST_USER)


func test_paid_mod_and_runtime_json_inputs_are_loaded_from_config() -> void:
	_write_config(STABLE_PATH, _stable_config("test"))
	_write_config(SESSION_PATH, _session_config("", ""))

	var loader := ModioEnvLoader.new()
	var config := loader.build_client_config("", STABLE_PATH, SESSION_PATH)

	assert_eq(config.owned_mod_id, "3001")
	assert_eq(config.paid_mod_id, "4001")
	assert_eq(config.s2s_transaction_id, "1234")
	assert_eq(config.s2s_delegation_token, "delegation-token")
	assert_eq(config.s2s_intent_idempotent_key, "intent-idem")
	assert_eq(config.s2s_commit_idempotent_key, "commit-idem")
	assert_eq(config.paid_entitlements_input.portal, "epicgames")
	assert_eq(config.paid_entitlements_input.fields.game_id, "1001")
	assert_eq(config.paid_checkout_input.mod_id, "4001")
	assert_eq(config.paid_checkout_input.fields.idempotent_key, "checkout-idem")
	assert_eq(config.paid_s2s_filters_input.transaction_type[0], "PAID")

func test_accept_language_defaults_when_missing() -> void:
	var content := _stable_config("test").replace("accept_language=\"en-US\"\n", "accept_language=\"\"\n")
	_write_config(STABLE_PATH, content)
	_write_config(SESSION_PATH, _session_config("", ""))

	var loader := ModioEnvLoader.new()
	var config := loader.build_client_config("", STABLE_PATH, SESSION_PATH)

	assert_eq(config.accept_language, ModioClientConfig.DEFAULT_ACCEPT_LANGUAGE)

func _stable_config(default_environment: String) -> String:
	return "".join([
		"[modio]\n",
		"default_environment=\"%s\"\n" % default_environment,
		"accept_language=\"en-US\"\n",
		"host_kind=\"game\"\n",
		"\n",
		"[modio.test]\n",
		"game_id=\"1001\"\n",
		"api_key=\"test-key\"\n",
		"base_url=\"\"\n",
		"service_token=\"service-test\"\n",
		"portal=\"steam\"\n",
		"platform=\"WINDOWS\"\n",
		"monetization_team_id=\"88\"\n",
		"owned_mod_id=\"3001\"\n",
		"paid_mod_id=\"4001\"\n",
		"\n",
		"[modio.live]\n",
		"game_id=\"2001\"\n",
		"api_key=\"live-key\"\n",
		"base_url=\"\"\n",
		"service_token=\"service-live\"\n",
		"portal=\"steam\"\n",
		"platform=\"WINDOWS\"\n",
		"monetization_team_id=\"188\"\n",
		"owned_mod_id=\"3002\"\n",
		"paid_mod_id=\"4002\"\n"
	])

func _session_config(environment: String, host_kind: String) -> String:
	return "".join([
		"[modio]\n",
		"environment=\"%s\"\n" % environment,
		"host_kind=\"%s\"\n" % host_kind,
		"\n",
		"[modio.test]\n",
		"access_token=\"test-token\"\n",
		"user_id=\"1111\"\n",
		"s2s_transaction_id=\"1234\"\n",
		"s2s_delegation_token=\"delegation-token\"\n",
		"s2s_intent_idempotent_key=\"intent-idem\"\n",
		"s2s_commit_idempotent_key=\"commit-idem\"\n",
		"entitlements_payload_json=\"{\\\"portal\\\":\\\"epicgames\\\",\\\"fields\\\":{\\\"game_id\\\":\\\"1001\\\"}}\"\n",
		"checkout_payload_json=\"{\\\"portal\\\":\\\"steam\\\",\\\"mod_id\\\":\\\"4001\\\",\\\"fields\\\":{\\\"idempotent_key\\\":\\\"checkout-idem\\\",\\\"type\\\":0,\\\"display_amount\\\":499}}\"\n",
		"s2s_filters_json=\"{\\\"transaction_type\\\":[\\\"PAID\\\"]}\"\n",
		"s2s_intent_payload_json=\"\"\n",
		"s2s_commit_payload_json=\"\"\n",
		"s2s_clawback_payload_json=\"\"\n",
		"\n",
		"[modio.live]\n",
		"access_token=\"live-token\"\n",
		"user_id=\"2222\"\n",
		"s2s_transaction_id=\"1234\"\n",
		"s2s_delegation_token=\"delegation-token\"\n",
		"s2s_intent_idempotent_key=\"intent-idem\"\n",
		"s2s_commit_idempotent_key=\"commit-idem\"\n",
		"entitlements_payload_json=\"{\\\"portal\\\":\\\"epicgames\\\",\\\"fields\\\":{\\\"game_id\\\":\\\"2001\\\"}}\"\n",
		"checkout_payload_json=\"{\\\"portal\\\":\\\"steam\\\",\\\"mod_id\\\":\\\"4001\\\",\\\"fields\\\":{\\\"idempotent_key\\\":\\\"checkout-idem\\\",\\\"type\\\":0,\\\"display_amount\\\":499}}\"\n",
		"s2s_filters_json=\"{\\\"transaction_type\\\":[\\\"PAID\\\"]}\"\n",
		"s2s_intent_payload_json=\"\"\n",
		"s2s_commit_payload_json=\"\"\n",
		"s2s_clawback_payload_json=\"\"\n"
	])

func _write_config(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func _cleanup_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
