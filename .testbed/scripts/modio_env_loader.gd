class_name ModioEnvLoader
extends RefCounted

const ENV_TEST := "test"
const ENV_LIVE := "live"
const DEFAULT_ENVIRONMENT := ENV_TEST
const MODIO_ENV_VAR := "MODIO_ENV"

const CONFIG_STABLE_PATH := "res://configs/modio.local.cfg"
const CONFIG_SESSION_PATH := "res://configs/modio.session.local.cfg"

const VALID_ENVIRONMENTS := [ENV_TEST, ENV_LIVE]

func build_client_config(
		explicit_env: String = "",
		stable_path: String = CONFIG_STABLE_PATH,
		session_path: String = CONFIG_SESSION_PATH,
		env_override: String = ""
	) -> ModioClientConfig:
	var stable_config := _load_config(stable_path)
	var session_config := _load_config(session_path)
	var selected_env := _resolve_environment(explicit_env, env_override, stable_config, session_config)

	var shared_accept_language := _read_string(
		stable_config,
		"modio",
		"accept_language",
		ModioClientConfig.DEFAULT_ACCEPT_LANGUAGE
	)
	if shared_accept_language.is_empty():
		shared_accept_language = ModioClientConfig.DEFAULT_ACCEPT_LANGUAGE

	var shared_host_kind := _read_string(stable_config, "modio", "host_kind", ModioClientConfig.HOST_API)
	var session_host_kind := _read_string(session_config, "modio", "host_kind", "")
	var resolved_host_kind := _resolve_host_kind(session_host_kind, shared_host_kind)

	var stable_env_section := "modio.%s" % selected_env
	var session_env_section := "modio.%s" % selected_env

	var game_id := _read_string(stable_config, stable_env_section, "game_id", "")
	var api_key := _read_string(stable_config, stable_env_section, "api_key", "")
	var base_url := _read_string(stable_config, stable_env_section, "base_url", "")
	var service_token := _read_string(stable_config, stable_env_section, "service_token", "")
	var portal := _read_string(stable_config, stable_env_section, "portal", "")
	var platform := _read_string(stable_config, stable_env_section, "platform", "")
	var monetization_team_id := _read_string(stable_config, stable_env_section, "monetization_team_id", "")
	var owned_mod_id := _read_string(stable_config, stable_env_section, "owned_mod_id", "")
	var paid_mod_id := _read_string(stable_config, stable_env_section, "paid_mod_id", "")

	var access_token := _read_string(session_config, session_env_section, "access_token", "")
	var user_id := _read_string(session_config, session_env_section, "user_id", "")
	var s2s_transaction_id := _read_string(session_config, session_env_section, "s2s_transaction_id", "")
	var s2s_delegation_token := _read_string(session_config, session_env_section, "s2s_delegation_token", "")
	var s2s_intent_idempotent_key := _read_string(session_config, session_env_section, "s2s_intent_idempotent_key", "")
	var s2s_commit_idempotent_key := _read_string(session_config, session_env_section, "s2s_commit_idempotent_key", "")
	var paid_entitlements_input := _read_json_dictionary(session_config, session_env_section, "entitlements_payload_json")
	var paid_checkout_input := _read_json_dictionary(session_config, session_env_section, "checkout_payload_json")
	var paid_s2s_filters_input := _read_json_dictionary(session_config, session_env_section, "s2s_filters_json")
	var paid_s2s_intent_input := _read_json_dictionary(session_config, session_env_section, "s2s_intent_payload_json")
	var paid_s2s_commit_input := _read_json_dictionary(session_config, session_env_section, "s2s_commit_payload_json")
	var paid_s2s_clawback_input := _read_json_dictionary(session_config, session_env_section, "s2s_clawback_payload_json")

	return ModioClientConfig.new(
		game_id,
		api_key,
		base_url,
		access_token,
		shared_accept_language,
		portal,
		platform,
		resolved_host_kind,
		user_id,
		selected_env == ENV_TEST,
		service_token,
		monetization_team_id,
		owned_mod_id,
		paid_mod_id,
		s2s_transaction_id,
		s2s_delegation_token,
		s2s_intent_idempotent_key,
		s2s_commit_idempotent_key,
		paid_entitlements_input,
		paid_checkout_input,
		paid_s2s_filters_input,
		paid_s2s_intent_input,
		paid_s2s_commit_input,
		paid_s2s_clawback_input
	)

func resolve_environment(
		explicit_env: String = "",
		stable_path: String = CONFIG_STABLE_PATH,
		session_path: String = CONFIG_SESSION_PATH,
		env_override: String = ""
	) -> String:
	var stable_config := _load_config(stable_path)
	var session_config := _load_config(session_path)
	return _resolve_environment(explicit_env, env_override, stable_config, session_config)

func _resolve_environment(
		explicit_env: String,
		env_override: String,
		stable_config: ConfigFile,
		session_config: ConfigFile
	) -> String:
	var candidate := _normalize_environment(explicit_env)
	if not candidate.is_empty():
		return candidate

	var env_candidate := env_override
	if env_candidate.is_empty():
		env_candidate = OS.get_environment(MODIO_ENV_VAR)
	candidate = _normalize_environment(env_candidate)
	if not candidate.is_empty():
		return candidate

	candidate = _normalize_environment(_read_string(session_config, "modio", "environment", ""))
	if not candidate.is_empty():
		return candidate

	candidate = _normalize_environment(_read_string(stable_config, "modio", "default_environment", ""))
	if not candidate.is_empty():
		return candidate

	return DEFAULT_ENVIRONMENT

func _load_config(path: String) -> ConfigFile:
	var config := ConfigFile.new()
	if FileAccess.file_exists(path):
		var load_result := config.load(path)
		if load_result != OK:
			push_error("Failed to load config at %s" % path)
	return config

func _read_string(config: ConfigFile, section: String, key: String, fallback: String) -> String:
	if config.has_section_key(section, key):
		return str(config.get_value(section, key, fallback)).strip_edges()
	return fallback

func _read_json_dictionary(config: ConfigFile, section: String, key: String) -> Dictionary:
	var raw := _read_string(config, section, key, "")
	if raw.is_empty():
		return {}
	var parsed = JSON.parse_string(raw)
	if parsed is Dictionary:
		return parsed
	push_error("Expected %s.%s to contain a JSON object" % [section, key])
	return {}

func _normalize_environment(value: String) -> String:
	var candidate := value.strip_edges().to_lower()
	return candidate if candidate in VALID_ENVIRONMENTS else ""

func _resolve_host_kind(session_value: String, fallback_value: String) -> String:
	var session_candidate := _normalize_host_kind(session_value)
	if not session_candidate.is_empty():
		return session_candidate
	var fallback_candidate := _normalize_host_kind(fallback_value)
	if not fallback_candidate.is_empty():
		return fallback_candidate
	return ModioClientConfig.HOST_API

func _normalize_host_kind(value: String) -> String:
	var candidate := value.strip_edges().to_lower()
	match candidate:
		ModioClientConfig.HOST_API, ModioClientConfig.HOST_GAME, ModioClientConfig.HOST_USER:
			return candidate
	return ""
