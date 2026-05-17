class_name ModioClientConfig
extends RefCounted

const DEFAULT_BASE_URL := "https://api.mod.io/v1"
const DEFAULT_ACCEPT_LANGUAGE := "en-US"
const HOST_API := "api"
const HOST_GAME := "game"
const HOST_USER := "user"

var game_id: String
var api_key: String
var access_token: String
var service_token: String
var base_url: String
var accept_language: String
var portal: String
var platform: String
var host_kind: String
var user_id: String
var monetization_team_id: String
var owned_mod_id: String
var paid_mod_id: String
var s2s_transaction_id: String
var s2s_delegation_token: String
var s2s_intent_idempotent_key: String
var s2s_commit_idempotent_key: String
var paid_entitlements_input: Dictionary
var paid_checkout_input: Dictionary
var paid_s2s_filters_input: Dictionary
var paid_s2s_intent_input: Dictionary
var paid_s2s_commit_input: Dictionary
var paid_s2s_clawback_input: Dictionary
var use_test_environment: bool

func _init(
	p_game_id: String = "",
	p_api_key: String = "",
	p_base_url: String = DEFAULT_BASE_URL,
	p_access_token: String = "",
	p_accept_language: String = DEFAULT_ACCEPT_LANGUAGE,
	p_portal: String = "",
	p_platform: String = "",
	p_host_kind: String = HOST_API,
	p_user_id: String = "",
	p_use_test_environment: bool = false,
	p_service_token: String = "",
	p_monetization_team_id: String = "",
	p_owned_mod_id: String = "",
	p_paid_mod_id: String = "",
	p_s2s_transaction_id: String = "",
	p_s2s_delegation_token: String = "",
	p_s2s_intent_idempotent_key: String = "",
	p_s2s_commit_idempotent_key: String = "",
	p_paid_entitlements_input: Dictionary = {},
	p_paid_checkout_input: Dictionary = {},
	p_paid_s2s_filters_input: Dictionary = {},
	p_paid_s2s_intent_input: Dictionary = {},
	p_paid_s2s_commit_input: Dictionary = {},
	p_paid_s2s_clawback_input: Dictionary = {}
) -> void:
	game_id = p_game_id.strip_edges()
	api_key = p_api_key.strip_edges()
	base_url = p_base_url.strip_edges()
	access_token = p_access_token.strip_edges()
	service_token = p_service_token.strip_edges()
	accept_language = p_accept_language.strip_edges()
	portal = p_portal.strip_edges()
	platform = p_platform.strip_edges()
	host_kind = p_host_kind.strip_edges().to_lower()
	user_id = p_user_id.strip_edges()
	monetization_team_id = p_monetization_team_id.strip_edges()
	owned_mod_id = p_owned_mod_id.strip_edges()
	paid_mod_id = p_paid_mod_id.strip_edges()
	s2s_transaction_id = p_s2s_transaction_id.strip_edges()
	s2s_delegation_token = p_s2s_delegation_token.strip_edges()
	s2s_intent_idempotent_key = p_s2s_intent_idempotent_key.strip_edges()
	s2s_commit_idempotent_key = p_s2s_commit_idempotent_key.strip_edges()
	paid_entitlements_input = p_paid_entitlements_input.duplicate(true)
	paid_checkout_input = p_paid_checkout_input.duplicate(true)
	paid_s2s_filters_input = p_paid_s2s_filters_input.duplicate(true)
	paid_s2s_intent_input = p_paid_s2s_intent_input.duplicate(true)
	paid_s2s_commit_input = p_paid_s2s_commit_input.duplicate(true)
	paid_s2s_clawback_input = p_paid_s2s_clawback_input.duplicate(true)
	use_test_environment = p_use_test_environment

func has_public_credentials() -> bool:
	return not game_id.is_empty() and not api_key.is_empty()

func has_access_token() -> bool:
	return not access_token.is_empty()

func has_service_token() -> bool:
	return not service_token.is_empty()

func resolve_base_url(base_url_override: String = "") -> String:
	var explicit_override := base_url_override.strip_edges()
	if not explicit_override.is_empty():
		return _normalize_base_url(explicit_override)
	if not base_url.is_empty():
		return _normalize_base_url(base_url)
	return _normalize_base_url(_build_host_base_url())

func build_default_headers() -> Dictionary:
	var headers := {}
	if not accept_language.is_empty():
		headers["Accept-Language"] = accept_language
	if not portal.is_empty():
		headers["X-Modio-Portal"] = portal
	if not platform.is_empty():
		headers["X-Modio-Platform"] = platform
	return headers

func resolve_owned_mod_id(explicit_mod_id: String = "") -> String:
	var candidate := explicit_mod_id.strip_edges()
	if not candidate.is_empty():
		return candidate
	if not owned_mod_id.is_empty():
		return owned_mod_id
	return paid_mod_id

func resolve_paid_mod_id(explicit_mod_id: String = "") -> String:
	var candidate := explicit_mod_id.strip_edges()
	if not candidate.is_empty():
		return candidate
	if not paid_mod_id.is_empty():
		return paid_mod_id
	return owned_mod_id

func _normalize_base_url(value: String) -> String:
	return value.strip_edges().rstrip("/")

func _build_host_base_url() -> String:
	var api_domain := "api.test.mod.io" if use_test_environment else "api.mod.io"
	var host := api_domain
	match host_kind:
		HOST_GAME:
			if not game_id.is_empty():
				host = "g-%s.%s" % [game_id, "test.mod.io" if use_test_environment else "modapi.io"]
		HOST_USER:
			if not user_id.is_empty():
				host = "u-%s.%s" % [user_id, "test.mod.io" if use_test_environment else "modapi.io"]
	return "https://%s/v1" % host
