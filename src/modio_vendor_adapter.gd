class_name ModioVendorAdapter
extends RefCounted

const ModioClientConfig = preload("res://src/models/modio_client_config.gd")
const ModioListingQuery = preload("res://src/models/modio_listing_query.gd")
const ModioDownloadRequest = preload("res://src/models/modio_download_request.gd")
const ModioHttpTransport = preload("res://src/network/modio_http_transport.gd")

const PROVIDER_NAME := "modio"
const COMMON_YEAR_SECONDS := 31536000
const WEEK_SECONDS := 604800
const DOCUMENTED_RECURSIVE_DEPENDENCY_DEPTH := 5

const API_ACCESS_OPEN := 1
const API_ACCESS_DOWNLOADS := 2
const API_ACCESS_AUTHORISED_DOWNLOADS := 4
const API_ACCESS_PAID_DOWNLOADS := 8

const DEPENDENCY_OPTION_DISALLOW := 0
const DEPENDENCY_OPTION_ALLOW_OPT_IN := 1
const DEPENDENCY_OPTION_ALLOW_OPT_OUT := 2
const DEPENDENCY_OPTION_ALLOW_ALL := 3

const COMMUNITY_OPTION_ALLOW_MOD_COMMENTS := 1
const COMMUNITY_OPTION_ALLOW_GUIDES := 2
const COMMUNITY_OPTION_ALLOW_NEGATIVE_RATINGS := 256
const COMMUNITY_OPTION_ALLOW_DEPENDENCY := 1024
const COMMUNITY_OPTION_ALLOW_GUIDE_COMMENTS := 2048

const COMMENT_OPTION_PINNED := 1
const COMMENT_OPTION_LOCKED := 2

const DEPENDENCY_POLICY_NONE := "none"
const DEPENDENCY_POLICY_IMMEDIATE_ONLY := "immediate_only"
const DEPENDENCY_POLICY_RECURSIVE := "recursive"
const DEPENDENCY_POLICY_SUBSCRIPTION_INCLUDE := "subscription_include_dependencies"

const GUIDE_STATUS_VALUES := [0, 1, 3]
const GUIDE_COMMUNITY_OPTION_VALUES := [0, 2048]
const MOD_STATUS_VALUES := [0, 1, 3]
const MOD_VISIBILITY_VALUES := [0, 1]
const MOD_STOCK_VALUES := [0, 1]
const MOD_MONETIZATION_OPTION_VALUES := [0, 1, 2, 8]
const MOD_MATURITY_OPTION_VALUES := [0, 1, 2, 4, 8]
const MOD_COMMUNITY_OPTION_VALUES := [0, 1, 64, 128, 1024, 131072]
const MOD_CREDIT_OPTION_VALUES := [0, 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024]
const COLLECTION_STATUS_VALUES := [0, 1]
const MULTIPART_UPLOAD_STATUS_VALUES := [0, 1, 2, 3, 4]
const COLLECTION_VISIBILITY_VALUES := [0, 1]
const COLLECTION_TAG_VALUES := ["ANIMATION", "AUDIO", "BUGFIXES", "CHEATING", "ENVIRONMENT", "GAMEPLAY", "QUALITY_OF_LIFE", "UI", "VISUAL"]
const MODFILE_PLATFORM_VALUES := ["ALL", "WINDOWS", "MAC", "LINUX", "ANDROID", "IOS", "XBOXONE", "XBOXSERIESX", "PLAYSTATION4", "PLAYSTATION5", "SWITCH", "OCULUS", "SOURCE", "SWITCH2", "WINDOWSSERVER", "LINUXSERVER"]
const CHECKOUT_TYPE_VALUES := [0, 1, 2, 3, 4]
const MONETIZATION_TRANSACTION_TYPE_VALUES := ["CANCELLED", "CLEARED", "CREDITED", "FAILED", "PAID", "PENDING", "REFUNDED"]
const MONETIZATION_TYPE_VALUES := ["FIAT", "TOKEN", "EXTERNAL"]
const CHECKOUT_PORTAL_VALUES := ["steam", "xboxlive", "psn", "epicgames"]
const CLAWBACK_PORTAL_VALUES := ["apple", "google", "xboxlive", "psn", "steam"]

var _config: ModioClientConfig
var _transport: ModioHttpTransport

func _init(config: ModioClientConfig = ModioClientConfig.new(), transport: ModioHttpTransport = ModioHttpTransport.new()) -> void:
	_config = config
	_transport = transport

func build_email_security_code_request(email: String) -> Dictionary:
	return _transport.build_request(
		"POST",
		"/oauth/emailrequest",
		{},
		{"email": email.strip_edges()},
		_build_form_headers(false),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "api_key_query"}
	)

func build_auth_exchange_request(security_code: String, date_expires: int = 0) -> Dictionary:
	var body := {"security_code": security_code.strip_edges()}
	var sanitized_date_expires := _sanitize_requested_expiry(date_expires, COMMON_YEAR_SECONDS)
	if sanitized_date_expires > 0:
		body["date_expires"] = sanitized_date_expires
	return _transport.build_request(
		"POST",
		"/oauth/emailexchange",
		{},
		body,
		_build_form_headers(false),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "api_key_query"}
	)

func build_openid_auth_request(
	id_token: String,
	terms_agreed: bool,
	email: String = "",
	date_expires: int = 0,
	monetization_account: bool = false,
	psn_token: String = "",
	psn_env: int = -1
) -> Dictionary:
	var body := {
		"id_token": id_token.strip_edges(),
		"terms_agreed": terms_agreed
	}
	_append_optional_email(body, email)
	_append_optional_date_expires(body, date_expires, WEEK_SECONDS)
	if monetization_account:
		body["monetization_account"] = true
	if not psn_token.strip_edges().is_empty():
		body["psn_token"] = psn_token.strip_edges()
		if psn_env >= 0:
			body["psn_env"] = psn_env
	return _build_external_auth_request("/external/openidauth", body)

func build_apple_auth_request(id_token: String, terms_agreed: bool, date_expires: int = 0) -> Dictionary:
	var body := {
		"id_token": id_token.strip_edges(),
		"terms_agreed": terms_agreed
	}
	_append_optional_date_expires(body, date_expires, WEEK_SECONDS)
	return _build_external_auth_request("/external/appleauth", body)

func build_discord_auth_request(discord_token: String, terms_agreed: bool, email: String = "", date_expires: int = 0) -> Dictionary:
	var body := {
		"discord_token": discord_token.strip_edges(),
		"terms_agreed": terms_agreed
	}
	_append_optional_email(body, email)
	_append_optional_date_expires(body, date_expires, WEEK_SECONDS)
	return _build_external_auth_request("/external/discordauth", body)

func build_epic_games_auth_request(id_token: String, terms_agreed: bool, email: String = "", date_expires: int = 0) -> Dictionary:
	var body := {
		"id_token": id_token.strip_edges(),
		"terms_agreed": terms_agreed
	}
	_append_optional_email(body, email)
	_append_optional_date_expires(body, date_expires, WEEK_SECONDS)
	return _build_external_auth_request("/external/epicgamesauth", body)

func build_gog_galaxy_auth_request(appdata: String, terms_agreed: bool, email: String = "", date_expires: int = 0) -> Dictionary:
	var body := {
		"appdata": appdata.strip_edges(),
		"terms_agreed": terms_agreed
	}
	_append_optional_email(body, email)
	_append_optional_date_expires(body, date_expires, WEEK_SECONDS)
	return _build_external_auth_request("/external/galaxyauth", body)

func build_google_auth_request(auth_code: String = "", id_token: String = "", terms_agreed: bool = false, date_expires: int = 0) -> Dictionary:
	var body := {"terms_agreed": terms_agreed}
	if not auth_code.strip_edges().is_empty():
		body["auth_code"] = auth_code.strip_edges()
	if not id_token.strip_edges().is_empty():
		body["id_token"] = id_token.strip_edges()
	_append_optional_date_expires(body, date_expires, WEEK_SECONDS)
	return _build_external_auth_request("/external/googleauth", body)

func build_oculus_auth_request(device: String, nonce: String, user_id: int, access_token: String, terms_agreed: bool, email: String = "", date_expires: int = 0) -> Dictionary:
	var body := {
		"device": device.strip_edges(),
		"nonce": nonce.strip_edges(),
		"user_id": user_id,
		"access_token": access_token.strip_edges(),
		"terms_agreed": terms_agreed
	}
	_append_optional_email(body, email)
	_append_optional_date_expires(body, date_expires, COMMON_YEAR_SECONDS)
	return _build_external_auth_request("/external/oculusauth", body)

func build_psn_auth_request(auth_code: String, terms_agreed: bool, email: String = "", env: int = -1, date_expires: int = 0) -> Dictionary:
	var body := {
		"auth_code": auth_code.strip_edges(),
		"terms_agreed": terms_agreed
	}
	_append_optional_email(body, email)
	if env >= 0:
		body["env"] = env
	_append_optional_date_expires(body, date_expires, COMMON_YEAR_SECONDS)
	return _build_external_auth_request("/external/psnauth", body)

func build_steam_auth_request(appdata: String, terms_agreed: bool, email: String = "", date_expires: int = 0) -> Dictionary:
	var body := {
		"appdata": appdata.strip_edges(),
		"terms_agreed": terms_agreed
	}
	_append_optional_email(body, email)
	_append_optional_date_expires(body, date_expires, WEEK_SECONDS)
	return _build_external_auth_request("/external/steamauth", body)

func build_switch_auth_request(id_token: String, terms_agreed: bool, email: String = "", date_expires: int = 0) -> Dictionary:
	var body := {
		"id_token": id_token.strip_edges(),
		"terms_agreed": terms_agreed
	}
	_append_optional_email(body, email)
	_append_optional_date_expires(body, date_expires, COMMON_YEAR_SECONDS)
	return _build_external_auth_request("/external/switchauth", body)

func build_udt_auth_request(delegation_token: String) -> Dictionary:
	var headers := _build_form_headers(false)
	headers["X-Modio-Delegation-Token"] = delegation_token.strip_edges()
	return _transport.build_request(
		"POST",
		"/external/udtauth",
		{},
		{},
		headers,
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "api_key_query"}
	)

func build_xbox_live_auth_request(xbox_token: String, terms_agreed: bool, email: String = "", date_expires: int = 0) -> Dictionary:
	var body := {
		"xbox_token": xbox_token.strip_edges(),
		"terms_agreed": terms_agreed
	}
	_append_optional_email(body, email)
	_append_optional_date_expires(body, date_expires, COMMON_YEAR_SECONDS)
	return _build_external_auth_request("/external/xboxauth", body)

func build_terms_request() -> Dictionary:
	return _transport.build_request(
		"GET",
		"/authenticate/terms",
		_build_public_query(),
		{},
		_build_read_headers(false),
		{"auth_mode": "api_key_query"}
	)

func build_current_agreement_request(agreement_type_id: int) -> Dictionary:
	return _transport.build_request(
		"GET",
		"/agreements/types/%s/current" % agreement_type_id,
		_build_public_query(),
		{},
		_build_read_headers(false),
		{"auth_mode": "api_key_query"}
	)

func build_agreement_version_request(agreement_version_id: int) -> Dictionary:
	return _transport.build_request(
		"GET",
		"/agreements/versions/%s" % agreement_version_id,
		_build_public_query(),
		{},
		_build_read_headers(false),
		{"auth_mode": "api_key_query"}
	)

func build_authenticated_user_request(delegation_token: String = "") -> Dictionary:
	var headers := _build_read_headers(true)
	if not delegation_token.strip_edges().is_empty():
		headers["X-Modio-Delegation-Token"] = delegation_token.strip_edges()
	return _transport.build_request(
		"GET",
		"/me",
		_build_authenticated_query(),
		{},
		headers,
		{"auth_mode": _resolve_read_auth_mode(true)}
	)

func build_logout_request() -> Dictionary:
	return _transport.build_request(
		"POST",
		"/oauth/logout",
		{},
		{},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_game_request(show_hidden_tags: bool = false) -> Dictionary:
	var query := _build_public_query()
	if show_hidden_tags:
		query["show_hidden_tags"] = true
	return _transport.build_request(
		"GET",
		"/games/%s" % _config.game_id,
		query,
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)}
	)

func build_games_request(query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_public_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_GAMES), true)
	return _transport.build_request(
		"GET",
		"/games",
		full_query,
		{},
		_build_read_headers(false),
		{"auth_mode": "api_key_query"}
	)

func build_user_games_request(query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_authenticated_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_USER_GAMES), true)
	return _transport.build_request(
		"GET",
		"/me/games",
		full_query,
		{},
		_build_read_headers(true),
		{"auth_mode": "bearer"}
	)

func build_game_stats_request(game_id: String = "") -> Dictionary:
	return _transport.build_request(
		"GET",
		"/games/%s/stats" % _resolve_requested_game_id(game_id),
		_build_public_query(),
		{},
		_build_read_headers(false),
		{"auth_mode": "api_key_query"}
	)

func build_game_tags_request(game_id: String = "", show_hidden_tags: bool = false) -> Dictionary:
	var query := _build_public_query()
	if show_hidden_tags:
		query["show_hidden_tags"] = true
	return _transport.build_request(
		"GET",
		"/games/%s/tags" % _resolve_requested_game_id(game_id),
		query,
		{},
		_build_read_headers(false),
		{"auth_mode": "api_key_query"}
	)

func build_game_token_packs_request(game_id: String = "") -> Dictionary:
	return _transport.build_request(
		"GET",
		"/games/%s/monetization/token-packs" % _resolve_requested_game_id(game_id),
		_build_authenticated_query(),
		{},
		_build_read_headers(true),
		{"auth_mode": "bearer"}
	)

func build_game_mod_stats_request(game_id: String = "", query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_public_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_GAME_MOD_STATS), true)
	return _transport.build_request(
		"GET",
		"/games/%s/mods/stats" % _resolve_requested_game_id(game_id),
		full_query,
		{},
		_build_read_headers(false),
		{"auth_mode": "api_key_query"}
	)

func build_guide_tags_request(game_id: String = "") -> Dictionary:
	return _transport.build_request(
		"GET",
		"/games/%s/guides/tags" % _resolve_requested_game_id(game_id),
		_build_public_query(),
		{},
		_build_read_headers(false),
		{"auth_mode": "api_key_query"}
	)

func build_ping_request() -> Dictionary:
	return _transport.build_request(
		"GET",
		"/ping",
		{},
		{},
		_build_read_headers(false),
		{"auth_mode": "none"}
	)

func build_listing_request(query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_public_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_MODS), true)
	return _transport.build_request(
		"GET",
		"/games/%s/mods" % _config.game_id,
		full_query,
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)}
	)

func build_mod_detail_request(mod_id: String) -> Dictionary:
	return _transport.build_request(
		"GET",
		"/games/%s/mods/%s" % [_config.game_id, mod_id.strip_edges()],
		_build_public_query(),
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)}
	)

func build_add_mod_request(fields: Dictionary) -> Dictionary:
	var normalized := _normalize_mod_authoring_fields(fields, true)
	return _build_validated_request(
		"POST",
		"/games/%s/mods" % _config.game_id,
		{},
		normalized.body,
		_build_multipart_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_MULTIPART, "auth_mode": "bearer"},
		normalized.errors
	)

func build_update_mod_request(mod_id: String, fields: Dictionary) -> Dictionary:
	var errors: Array = []
	_append_required_positive_id_error(mod_id, "mod_id", errors)
	var normalized := _normalize_mod_authoring_fields(fields, false)
	errors.append_array(normalized.errors)
	return _build_validated_request(
		"POST",
		"/games/%s/mods/%s" % [_config.game_id, mod_id.strip_edges()],
		{},
		normalized.body,
		_build_multipart_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_MULTIPART, "auth_mode": "bearer"},
		errors
	)

func build_delete_mod_request(mod_id: String) -> Dictionary:
	var errors: Array = []
	_append_required_positive_id_error(mod_id, "mod_id", errors)
	return _build_validated_request(
		"DELETE",
		"/games/%s/mods/%s" % [_config.game_id, mod_id.strip_edges()],
		{},
		{},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"},
		errors
	)

func build_modfiles_request(mod_id: String, query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_public_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_MODFILES), true)
	return _transport.build_request(
		"GET",
		"/games/%s/mods/%s/files" % [_config.game_id, mod_id.strip_edges()],
		full_query,
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)}
	)

func build_modfile_request(mod_id: String, file_id: String) -> Dictionary:
	return _transport.build_request(
		"GET",
		"/games/%s/mods/%s/files/%s" % [_config.game_id, mod_id.strip_edges(), file_id.strip_edges()],
		_build_public_query(),
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)}
	)

func build_modfile_cooks_request(mod_id: String) -> Dictionary:
	var errors: Array = []
	_append_required_positive_id_error(mod_id, "mod_id", errors)
	return _build_validated_request(
		"GET",
		"/games/%s/mods/%s/cooks" % [_config.game_id, mod_id.strip_edges()],
		_build_public_query(),
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)},
		errors
	)

func build_manage_modfile_platforms_request(mod_id: String, file_id: String, fields: Dictionary) -> Dictionary:
	var errors: Array = []
	_append_required_positive_id_error(mod_id, "mod_id", errors)
	_append_required_positive_id_error(file_id, "file_id", errors)
	var normalized := _normalize_manage_modfile_platforms_fields(fields)
	errors.append_array(normalized.errors)
	return _build_validated_request(
		"POST",
		"/games/%s/mods/%s/files/%s/platforms" % [_config.game_id, mod_id.strip_edges(), file_id.strip_edges()],
		{},
		normalized.body,
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"},
		errors
	)

func build_finalize_cloud_cooking_request() -> Dictionary:
	return _build_validated_request(
		"POST",
		"/games/%s/cloud-cooking/finalization" % _config.game_id,
		{},
		{},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"},
		[]
	)

func build_add_modfile_request(mod_id: String, fields: Dictionary) -> Dictionary:
	var errors: Array = []
	_append_required_positive_id_error(mod_id, "mod_id", errors)
	var normalized := _normalize_add_modfile_fields(fields)
	errors.append_array(normalized.errors)
	return _build_validated_request(
		"POST",
		"/games/%s/mods/%s/files" % [_config.game_id, mod_id.strip_edges()],
		{},
		normalized.body,
		_build_multipart_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_MULTIPART, "auth_mode": "bearer"},
		errors
	)

func build_update_modfile_request(mod_id: String, file_id: String, fields: Dictionary) -> Dictionary:
	var errors: Array = []
	_append_required_positive_id_error(mod_id, "mod_id", errors)
	_append_required_positive_id_error(file_id, "file_id", errors)
	var normalized := _normalize_update_modfile_fields(fields)
	errors.append_array(normalized.errors)
	return _build_validated_request(
		"PUT",
		"/games/%s/mods/%s/files/%s" % [_config.game_id, mod_id.strip_edges(), file_id.strip_edges()],
		{},
		normalized.body,
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"},
		errors
	)

func build_delete_modfile_request(mod_id: String, file_id: String) -> Dictionary:
	var errors: Array = []
	_append_required_positive_id_error(mod_id, "mod_id", errors)
	_append_required_positive_id_error(file_id, "file_id", errors)
	return _build_validated_request(
		"DELETE",
		"/games/%s/mods/%s/files/%s" % [_config.game_id, mod_id.strip_edges(), file_id.strip_edges()],
		{},
		{},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"},
		errors
	)

func build_source_modfiles_request(mod_id: String) -> Dictionary:
	var errors: Array = []
	_append_required_positive_id_error(mod_id, "mod_id", errors)
	return _build_validated_request(
		"GET",
		"/games/%s/mods/%s/sources" % [_config.game_id, mod_id.strip_edges()],
		_build_public_query(),
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)},
		errors
	)

func build_add_source_modfile_request(mod_id: String, fields: Dictionary) -> Dictionary:
	var errors: Array = []
	_append_required_positive_id_error(mod_id, "mod_id", errors)
	var normalized := _normalize_add_modfile_fields(fields)
	errors.append_array(normalized.errors)
	return _build_validated_request(
		"POST",
		"/games/%s/mods/%s/sources" % [_config.game_id, mod_id.strip_edges()],
		{},
		normalized.body,
		_build_multipart_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_MULTIPART, "auth_mode": "bearer"},
		errors
	)

func build_create_multipart_upload_session_request(mod_id: String, fields: Dictionary) -> Dictionary:
	var errors: Array = []
	_append_required_positive_id_error(mod_id, "mod_id", errors)
	var normalized := _normalize_create_multipart_upload_session_fields(fields)
	errors.append_array(normalized.errors)
	return _build_validated_request(
		"POST",
		"/games/%s/mods/%s/files/multipart" % [_config.game_id, mod_id.strip_edges()],
		{},
		normalized.body,
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"},
		errors
	)

func build_multipart_upload_sessions_request(mod_id: String, filters: Dictionary = {}) -> Dictionary:
	var errors: Array = []
	_append_required_positive_id_error(mod_id, "mod_id", errors)
	var normalized := _normalize_multipart_upload_session_filters(filters)
	errors.append_array(normalized.errors)
	return _build_validated_request(
		"GET",
		"/games/%s/mods/%s/files/multipart/sessions" % [_config.game_id, mod_id.strip_edges()],
		normalized.query,
		{},
		_build_read_headers(true),
		{"auth_mode": "bearer"},
		errors
	)

func build_multipart_upload_parts_request(mod_id: String, upload_id: String) -> Dictionary:
	var errors: Array = []
	_append_required_positive_id_error(mod_id, "mod_id", errors)
	var query := _build_multipart_upload_id_query(upload_id, errors)
	return _build_validated_request(
		"GET",
		"/games/%s/mods/%s/files/multipart" % [_config.game_id, mod_id.strip_edges()],
		query,
		{},
		_build_read_headers(true),
		{"auth_mode": "bearer"},
		errors
	)

func build_upload_multipart_part_request(mod_id: String, upload_id: String, part_body: Variant, content_range: String, digest: String = "") -> Dictionary:
	var errors: Array = []
	_append_required_positive_id_error(mod_id, "mod_id", errors)
	var query := _build_multipart_upload_id_query(upload_id, errors)
	var headers := _build_read_headers(true)
	var normalized_headers := _normalize_multipart_upload_part_headers(content_range, digest, errors)
	headers.merge(normalized_headers, true)
	var normalized_body: Variant = _normalize_multipart_upload_part_body(part_body, errors)
	var meta := {
		"content_type": "application/octet-stream",
		"auth_mode": "bearer",
		"raw_body": normalized_body
	}
	return _build_validated_request(
		"PUT",
		"/games/%s/mods/%s/files/multipart" % [_config.game_id, mod_id.strip_edges()],
		query,
		{},
		headers,
		meta,
		errors
	)

func build_complete_multipart_upload_session_request(mod_id: String, upload_id: String) -> Dictionary:
	var errors: Array = []
	_append_required_positive_id_error(mod_id, "mod_id", errors)
	var query := _build_multipart_upload_id_query(upload_id, errors)
	return _build_validated_request(
		"POST",
		"/games/%s/mods/%s/files/multipart/complete" % [_config.game_id, mod_id.strip_edges()],
		query,
		{},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"},
		errors
	)

func build_delete_multipart_upload_session_request(mod_id: String, upload_id: String) -> Dictionary:
	var errors: Array = []
	_append_required_positive_id_error(mod_id, "mod_id", errors)
	var query := _build_multipart_upload_id_query(upload_id, errors)
	return _build_validated_request(
		"DELETE",
		"/games/%s/mods/%s/files/multipart" % [_config.game_id, mod_id.strip_edges()],
		query,
		{},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"},
		errors
	)

func build_add_mod_media_request(mod_id: String, fields: Dictionary) -> Dictionary:
	var errors: Array = []
	_append_required_positive_id_error(mod_id, "mod_id", errors)
	var normalized := _normalize_add_mod_media_fields(fields)
	errors.append_array(normalized.errors)
	return _build_validated_request(
		"POST",
		"/games/%s/mods/%s/media" % [_config.game_id, mod_id.strip_edges()],
		{},
		normalized.body,
		_build_multipart_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_MULTIPART, "auth_mode": "bearer"},
		errors
	)

func build_reorder_mod_media_request(mod_id: String, fields: Dictionary) -> Dictionary:
	var errors: Array = []
	_append_required_positive_id_error(mod_id, "mod_id", errors)
	var normalized := _normalize_reorder_or_delete_mod_media_fields(fields, "reorder mod media")
	errors.append_array(normalized.errors)
	return _build_validated_request(
		"PUT",
		"/games/%s/mods/%s/media/reorder" % [_config.game_id, mod_id.strip_edges()],
		{},
		normalized.body,
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"},
		errors
	)

func build_delete_mod_media_request(mod_id: String, fields: Dictionary) -> Dictionary:
	var errors: Array = []
	_append_required_positive_id_error(mod_id, "mod_id", errors)
	var normalized := _normalize_reorder_or_delete_mod_media_fields(fields, "delete mod media")
	errors.append_array(normalized.errors)
	return _build_validated_request(
		"DELETE",
		"/games/%s/mods/%s/media" % [_config.game_id, mod_id.strip_edges()],
		{},
		normalized.body,
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"},
		errors
	)

func build_add_game_media_request(fields: Dictionary) -> Dictionary:
	var normalized := _normalize_add_game_media_fields(fields)
	return _build_validated_request(
		"POST",
		"/games/%s/media" % _config.game_id,
		{},
		normalized.body,
		_build_multipart_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_MULTIPART, "auth_mode": "bearer"},
		normalized.errors
	)

func build_mod_stats_request(mod_id: String) -> Dictionary:
	return _transport.build_request(
		"GET",
		"/games/%s/mods/%s/stats" % [_config.game_id, mod_id.strip_edges()],
		_build_public_query(),
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)}
	)

func build_user_mods_request(query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_authenticated_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_USER_MODS), true)
	return _transport.build_request(
		"GET",
		"/me/mods",
		full_query,
		{},
		_build_read_headers(true),
		{"auth_mode": "bearer"}
	)

func build_user_modfiles_request(query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_authenticated_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_USER_MODFILES), true)
	return _transport.build_request(
		"GET",
		"/me/files",
		full_query,
		{},
		_build_read_headers(true),
		{"auth_mode": "bearer"}
	)

func build_collections_request(query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_public_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_COLLECTIONS), true)
	return _transport.build_request(
		"GET",
		"/games/%s/collections" % _config.game_id,
		full_query,
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)}
	)

func build_collection_request(collection_id: String) -> Dictionary:
	return _transport.build_request(
		"GET",
		"/games/%s/collections/%s" % [_config.game_id, collection_id.strip_edges()],
		_build_public_query(),
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)}
	)

func build_user_followers_request(user_id: String, query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var has_access_token := _config.has_access_token()
	var full_query := _build_public_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_USER_SOCIAL), true)
	return _transport.build_request(
		"GET",
		"/users/%s/followers" % user_id.strip_edges(),
		full_query,
		{},
		_build_read_headers(has_access_token),
		{"auth_mode": "api_key_fallback"}
	)

func build_user_following_request(user_id: String, query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var has_access_token := _config.has_access_token()
	var full_query := _build_public_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_USER_SOCIAL), true)
	return _transport.build_request(
		"GET",
		"/users/%s/following" % user_id.strip_edges(),
		full_query,
		{},
		_build_read_headers(has_access_token),
		{"auth_mode": "api_key_fallback"}
	)

func build_follow_user_request(user_id: String, target_user_id: String) -> Dictionary:
	return _transport.build_request(
		"POST",
		"/users/%s/following" % user_id.strip_edges(),
		{},
		_build_follow_user_body(target_user_id),
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_unfollow_user_request(user_id: String, target_user_id: String) -> Dictionary:
	return _transport.build_request(
		"DELETE",
		"/users/%s/following/%s" % [user_id.strip_edges(), target_user_id.strip_edges()],
		{},
		{},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_mute_user_request(user_id: String) -> Dictionary:
	return _transport.build_request(
		"POST",
		"/users/%s/mute" % user_id.strip_edges(),
		{},
		{},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_unmute_user_request(user_id: String) -> Dictionary:
	return _transport.build_request(
		"DELETE",
		"/users/%s/mute" % user_id.strip_edges(),
		{},
		{},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_user_collections_request(user_id: String, query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var has_access_token := _config.has_access_token()
	var full_query := _build_public_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_USER_COLLECTIONS), true)
	return _transport.build_request(
		"GET",
		"/users/%s/collections" % user_id.strip_edges(),
		full_query,
		{},
		_build_read_headers(has_access_token),
		{"auth_mode": "api_key_fallback"}
	)

func build_me_followers_request(query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_authenticated_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_USER_SOCIAL), true)
	return _transport.build_request(
		"GET",
		"/me/followers",
		full_query,
		{},
		_build_read_headers(true),
		{"auth_mode": _resolve_read_auth_mode(true)}
	)

func build_muted_users_request(query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_authenticated_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_USER_SOCIAL), true)
	return _transport.build_request(
		"GET",
		"/me/users/muted",
		full_query,
		{},
		_build_read_headers(true),
		{"auth_mode": _resolve_read_auth_mode(true)}
	)

func build_me_collections_request(query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_authenticated_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_USER_COLLECTIONS), true)
	return _transport.build_request(
		"GET",
		"/me/collections",
		full_query,
		{},
		_build_read_headers(true),
		{"auth_mode": _resolve_read_auth_mode(true)}
	)

func build_followed_collections_request(query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_authenticated_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_USER_COLLECTIONS), true)
	return _transport.build_request(
		"GET",
		"/me/following/collections",
		full_query,
		{},
		_build_read_headers(true),
		{"auth_mode": _resolve_read_auth_mode(true)}
	)

func build_follow_collection_request(collection_id: String) -> Dictionary:
	return _transport.build_request(
		"POST",
		"/games/%s/collections/%s/followers" % [_config.game_id, collection_id.strip_edges()],
		{},
		{},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_unfollow_collection_request(collection_id: String) -> Dictionary:
	return _transport.build_request(
		"DELETE",
		"/games/%s/collections/%s/followers" % [_config.game_id, collection_id.strip_edges()],
		{},
		{},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_subscribe_collection_request(collection_id: String) -> Dictionary:
	return _transport.build_request(
		"POST",
		"/games/%s/collections/%s/subscriptions" % [_config.game_id, collection_id.strip_edges()],
		{},
		{},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_unsubscribe_collection_request(collection_id: String) -> Dictionary:
	return _transport.build_request(
		"DELETE",
		"/games/%s/collections/%s/subscriptions" % [_config.game_id, collection_id.strip_edges()],
		{},
		{},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_collection_mods_request(collection_id: String, query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_public_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_COLLECTION_MODS), true)
	return _transport.build_request(
		"GET",
		"/games/%s/collections/%s/mods" % [_config.game_id, collection_id.strip_edges()],
		full_query,
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)}
	)

func build_delete_collection_mods_request(collection_id: String, fields: Dictionary) -> Dictionary:
	var errors: Array = []
	_append_required_positive_id_error(collection_id, "collection_id", errors)
	var normalized := _normalize_delete_collection_mods_fields(fields)
	errors.append_array(normalized.errors)
	return _build_validated_request(
		"DELETE",
		"/games/%s/collections/%s/mods" % [_config.game_id, collection_id.strip_edges()],
		{},
		normalized.body,
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"},
		errors
	)

func build_add_collection_request(fields: Dictionary) -> Dictionary:
	var normalized := _normalize_collection_authoring_fields(fields, false)
	return _build_validated_request(
		"POST",
		"/games/%s/collections" % _config.game_id,
		{},
		normalized.body,
		_build_multipart_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_MULTIPART, "auth_mode": "bearer"},
		normalized.errors
	)

func build_update_collection_request(collection_id: String, fields: Dictionary) -> Dictionary:
	var normalized := _normalize_collection_authoring_fields(fields, true)
	return _build_validated_request(
		"POST",
		"/games/%s/collections/%s" % [_config.game_id, collection_id.strip_edges()],
		{},
		normalized.body,
		_build_multipart_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_MULTIPART, "auth_mode": "bearer"},
		normalized.errors
	)

func build_delete_collection_request(collection_id: String, fields: Dictionary = {}) -> Dictionary:
	var normalized := _normalize_collection_delete_fields(fields)
	return _build_validated_request(
		"DELETE",
		"/games/%s/collections/%s" % [_config.game_id, collection_id.strip_edges()],
		{},
		normalized.body,
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"},
		normalized.errors
	)

func build_collection_comments_request(collection_id: String, query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_public_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_COLLECTION_COMMENTS), true)
	return _transport.build_request(
		"GET",
		"/games/%s/collections/%s/comments" % [_config.game_id, collection_id.strip_edges()],
		full_query,
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)}
	)

func build_collection_comment_request(collection_id: String, comment_id: String) -> Dictionary:
	return _transport.build_request(
		"GET",
		"/games/%s/collections/%s/comments/%s" % [_config.game_id, collection_id.strip_edges(), comment_id.strip_edges()],
		_build_public_query(),
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)}
	)

func build_add_collection_comment_request(collection_id: String, content: String, reply_id: int = 0) -> Dictionary:
	var body := {"content": content.strip_edges()}
	if reply_id > 0:
		body["reply_id"] = reply_id
	return _transport.build_request(
		"POST",
		"/games/%s/collections/%s/comments" % [_config.game_id, collection_id.strip_edges()],
		{},
		body,
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_update_collection_comment_request(collection_id: String, comment_id: String, content: String) -> Dictionary:
	return _transport.build_request(
		"PUT",
		"/games/%s/collections/%s/comments/%s" % [_config.game_id, collection_id.strip_edges(), comment_id.strip_edges()],
		{},
		{"content": content.strip_edges()},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_delete_collection_comment_request(collection_id: String, comment_id: String) -> Dictionary:
	return _transport.build_request(
		"DELETE",
		"/games/%s/collections/%s/comments/%s" % [_config.game_id, collection_id.strip_edges(), comment_id.strip_edges()],
		{},
		{},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_add_collection_comment_karma_request(collection_id: String, comment_id: String, karma: int) -> Dictionary:
	return _transport.build_request(
		"POST",
		"/games/%s/collections/%s/comments/%s/karma" % [_config.game_id, collection_id.strip_edges(), comment_id.strip_edges()],
		{},
		{"karma": 1 if karma >= 0 else -1},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_add_collection_compatibility_request(collection_id: String, rating: int) -> Dictionary:
	return _transport.build_request(
		"POST",
		"/games/%s/collections/%s/compatibility" % [_config.game_id, collection_id.strip_edges()],
		{},
		{"rating": clampi(rating, -1, 1)},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_guides_request(query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_public_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_GUIDES), true)
	return _transport.build_request(
		"GET",
		"/games/%s/guides" % _config.game_id,
		full_query,
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)}
	)

func build_guide_detail_request(guide_id: String) -> Dictionary:
	return _transport.build_request(
		"GET",
		"/games/%s/guides/%s" % [_config.game_id, guide_id.strip_edges()],
		_build_public_query(),
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)}
	)

func build_guide_comments_request(guide_id: String, query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_public_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_GUIDE_COMMENTS), true)
	return _transport.build_request(
		"GET",
		"/games/%s/guides/%s/comments" % [_config.game_id, guide_id.strip_edges()],
		full_query,
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)}
	)

func build_add_guide_request(fields: Dictionary) -> Dictionary:
	var normalized := _normalize_guide_authoring_fields(fields, true)
	return _build_validated_request(
		"POST",
		"/games/%s/guides" % _config.game_id,
		{},
		normalized.body,
		_build_multipart_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_MULTIPART, "auth_mode": "bearer"},
		normalized.errors
	)

func build_update_guide_request(guide_id: String, fields: Dictionary) -> Dictionary:
	var normalized := _normalize_guide_authoring_fields(fields, false)
	return _build_validated_request(
		"POST",
		"/games/%s/guides/%s" % [_config.game_id, guide_id.strip_edges()],
		{},
		normalized.body,
		_build_multipart_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_MULTIPART, "auth_mode": "bearer"},
		normalized.errors
	)

func build_delete_guide_request(guide_id: String) -> Dictionary:
	return _transport.build_request(
		"DELETE",
		"/games/%s/guides/%s" % [_config.game_id, guide_id.strip_edges()],
		{},
		{},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_guide_comment_request(guide_id: String, comment_id: String) -> Dictionary:
	return _transport.build_request(
		"GET",
		"/games/%s/guides/%s/comments/%s" % [_config.game_id, guide_id.strip_edges(), comment_id.strip_edges()],
		_build_public_query(),
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)}
	)

func build_add_guide_comment_request(guide_id: String, content: String, reply_id: int = 0) -> Dictionary:
	var body := {"content": content.strip_edges()}
	if reply_id > 0:
		body["reply_id"] = reply_id
	return _transport.build_request(
		"POST",
		"/games/%s/guides/%s/comments" % [_config.game_id, guide_id.strip_edges()],
		{},
		body,
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_update_guide_comment_request(guide_id: String, comment_id: String, content: String) -> Dictionary:
	return _transport.build_request(
		"PUT",
		"/games/%s/guides/%s/comments/%s" % [_config.game_id, guide_id.strip_edges(), comment_id.strip_edges()],
		{},
		{"content": content.strip_edges()},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_delete_guide_comment_request(guide_id: String, comment_id: String) -> Dictionary:
	return _transport.build_request(
		"DELETE",
		"/games/%s/guides/%s/comments/%s" % [_config.game_id, guide_id.strip_edges(), comment_id.strip_edges()],
		{},
		{},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_add_guide_comment_karma_request(guide_id: String, comment_id: String, karma: int) -> Dictionary:
	return _transport.build_request(
		"POST",
		"/games/%s/guides/%s/comments/%s/karma" % [_config.game_id, guide_id.strip_edges(), comment_id.strip_edges()],
		{},
		{"karma": 1 if karma >= 0 else -1},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_mod_comments_request(mod_id: String, query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_public_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_MOD_COMMENTS), true)
	return _transport.build_request(
		"GET",
		"/games/%s/mods/%s/comments" % [_config.game_id, mod_id.strip_edges()],
		full_query,
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)}
	)

func build_mod_comment_request(mod_id: String, comment_id: String) -> Dictionary:
	return _transport.build_request(
		"GET",
		"/games/%s/mods/%s/comments/%s" % [_config.game_id, mod_id.strip_edges(), comment_id.strip_edges()],
		_build_public_query(),
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)}
	)

func build_add_mod_comment_request(mod_id: String, content: String, reply_id: int = 0) -> Dictionary:
	var body := {"content": content.strip_edges()}
	if reply_id > 0:
		body["reply_id"] = reply_id
	return _transport.build_request(
		"POST",
		"/games/%s/mods/%s/comments" % [_config.game_id, mod_id.strip_edges()],
		{},
		body,
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_update_mod_comment_request(mod_id: String, comment_id: String, content: String) -> Dictionary:
	return _transport.build_request(
		"PUT",
		"/games/%s/mods/%s/comments/%s" % [_config.game_id, mod_id.strip_edges(), comment_id.strip_edges()],
		{},
		{"content": content.strip_edges()},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_delete_mod_comment_request(mod_id: String, comment_id: String) -> Dictionary:
	return _transport.build_request(
		"DELETE",
		"/games/%s/mods/%s/comments/%s" % [_config.game_id, mod_id.strip_edges(), comment_id.strip_edges()],
		{},
		{},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_add_mod_comment_karma_request(mod_id: String, comment_id: String, karma: int) -> Dictionary:
	return _transport.build_request(
		"POST",
		"/games/%s/mods/%s/comments/%s/karma" % [_config.game_id, mod_id.strip_edges(), comment_id.strip_edges()],
		{},
		{"karma": 1 if karma >= 0 else -1},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_dependencies_request(mod_id: String, recursive: bool = false) -> Dictionary:
	var full_query := _build_public_query()
	full_query["recursive"] = recursive
	return _transport.build_request(
		"GET",
		"/games/%s/mods/%s/dependencies" % [_config.game_id, mod_id.strip_edges()],
		full_query,
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)}
	)

func build_dependants_request(mod_id: String, query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_public_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_MOD_DEPENDANTS), true)
	return _transport.build_request(
		"GET",
		"/games/%s/mods/%s/dependants" % [_config.game_id, mod_id.strip_edges()],
		full_query,
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)}
	)

func build_mod_tags_request(mod_id: String, query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_public_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_MOD_TAGS), true)
	return _transport.build_request(
		"GET",
		"/games/%s/mods/%s/tags" % [_config.game_id, mod_id.strip_edges()],
		full_query,
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)}
	)

func build_mod_metadata_kvp_request(mod_id: String, query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_public_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_MOD_DEPENDANTS), true)
	return _transport.build_request(
		"GET",
		"/games/%s/mods/%s/metadatakvp" % [_config.game_id, mod_id.strip_edges()],
		full_query,
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)}
	)

func build_add_mod_tags_request(mod_id: String, fields: Dictionary) -> Dictionary:
	var normalized := _normalize_mod_tags_write_fields(mod_id, fields)
	return _build_validated_request(
		"POST",
		"/games/%s/mods/%s/tags" % [_config.game_id, mod_id.strip_edges()],
		{},
		normalized.body,
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"},
		normalized.errors
	)

func build_delete_mod_tags_request(mod_id: String, fields: Dictionary) -> Dictionary:
	var normalized := _normalize_mod_tags_write_fields(mod_id, fields)
	return _build_validated_request(
		"DELETE",
		"/games/%s/mods/%s/tags" % [_config.game_id, mod_id.strip_edges()],
		{},
		normalized.body,
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"},
		normalized.errors
	)

func build_add_mod_metadata_kvp_request(mod_id: String, fields: Dictionary) -> Dictionary:
	var normalized := _normalize_mod_metadata_kvp_write_fields(mod_id, fields)
	return _build_validated_request(
		"POST",
		"/games/%s/mods/%s/metadatakvp" % [_config.game_id, mod_id.strip_edges()],
		{},
		normalized.body,
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"},
		normalized.errors
	)

func build_delete_mod_metadata_kvp_request(mod_id: String, fields: Dictionary) -> Dictionary:
	var normalized := _normalize_mod_metadata_kvp_write_fields(mod_id, fields)
	return _build_validated_request(
		"DELETE",
		"/games/%s/mods/%s/metadatakvp" % [_config.game_id, mod_id.strip_edges()],
		{},
		normalized.body,
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"},
		normalized.errors
	)

func build_add_mod_dependencies_request(mod_id: String, fields: Dictionary) -> Dictionary:
	var normalized := _normalize_mod_dependencies_write_fields(mod_id, fields, true)
	return _build_validated_request(
		"POST",
		"/games/%s/mods/%s/dependencies" % [_config.game_id, mod_id.strip_edges()],
		{},
		normalized.body,
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"},
		normalized.errors
	)

func build_delete_mod_dependencies_request(mod_id: String, fields: Dictionary) -> Dictionary:
	var normalized := _normalize_mod_dependencies_write_fields(mod_id, fields, false)
	return _build_validated_request(
		"DELETE",
		"/games/%s/mods/%s/dependencies" % [_config.game_id, mod_id.strip_edges()],
		{},
		normalized.body,
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"},
		normalized.errors
	)

func build_mod_team_request(mod_id: String, query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_public_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_MOD_TEAM), true)
	return _transport.build_request(
		"GET",
		"/games/%s/mods/%s/team" % [_config.game_id, mod_id.strip_edges()],
		full_query,
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)}
	)

func build_mod_monetization_team_request(mod_id: String) -> Dictionary:
	var validation_errors: Array = []
	_append_required_positive_id_error(mod_id, "mod_id", validation_errors)
	return _build_validated_request(
		"GET",
		"/games/%s/mods/%s/monetization/team" % [_config.game_id, mod_id.strip_edges()],
		{},
		{},
		_build_read_headers(true),
		{"auth_mode": "bearer"},
		validation_errors
	)

func build_create_mod_monetization_team_request(mod_id: String, fields: Dictionary) -> Dictionary:
	var normalized := _normalize_create_mod_monetization_team_fields(mod_id, fields)
	return _build_validated_request(
		"POST",
		"/games/%s/mods/%s/monetization/team" % [_config.game_id, mod_id.strip_edges()],
		{},
		normalized.body,
		normalized.headers,
		{"content_type": ModioHttpTransport.CONTENT_TYPE_MULTIPART, "auth_mode": "bearer"},
		normalized.errors
	)

func build_user_subscriptions_request(query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_authenticated_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_SUBSCRIPTIONS), true)
	if not _config.platform.is_empty() and not _config.game_id.is_empty():
		full_query["game_id"] = _config.game_id
	return _transport.build_request(
		"GET",
		"/me/subscribed",
		full_query,
		{},
		_build_read_headers(true),
		{"auth_mode": _resolve_read_auth_mode(true)}
	)

func build_user_wallet_request(game_id: String = "") -> Dictionary:
	var query := _build_authenticated_query()
	var resolved_game_id := _resolve_requested_game_id(game_id)
	var validation_errors: Array = []
	if resolved_game_id.is_empty():
		validation_errors.append("game_id is required unless using a g-url host")
	else:
		query["game_id"] = resolved_game_id
	return _build_validated_request(
		"GET",
		"/me/wallets",
		query,
		{},
		_build_read_headers(true),
		{"auth_mode": _resolve_read_auth_mode(true)},
		validation_errors
	)

func build_user_purchased_request(query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_authenticated_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_USER_PURCHASED), true)
	if not _config.platform.is_empty() and not full_query.has("game_id") and not _config.game_id.is_empty():
		full_query["game_id"] = _config.game_id
	return _transport.build_request(
		"GET",
		"/me/purchased",
		full_query,
		{},
		_build_read_headers(true),
		{"auth_mode": _resolve_read_auth_mode(true)}
	)

func build_user_entitlements_request(fields: Dictionary, portal: String = "", platform: String = "") -> Dictionary:
	var normalized := _normalize_user_entitlements_fields(fields, portal, platform)
	return _build_validated_request(
		"POST",
		"/me/entitlements",
		{},
		normalized.body,
		normalized.headers,
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"},
		normalized.errors
	)

func build_checkout_request(mod_id: String, fields: Dictionary, portal: String = "", platform: String = "") -> Dictionary:
	var normalized := _normalize_checkout_fields(mod_id, fields, portal, platform)
	return _build_validated_request(
		"POST",
		"/games/%s/mods/%s/checkout" % [_config.game_id, mod_id.strip_edges()],
		{},
		normalized.body,
		normalized.headers,
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"},
		normalized.errors
	)

func build_s2s_transaction_intent_request(fields: Dictionary, delegation_token: String, idempotent_key: String = "") -> Dictionary:
	var normalized := _normalize_s2s_transaction_intent_fields(fields, delegation_token, idempotent_key)
	return _build_validated_request(
		"POST",
		"/s2s/transactions/intent",
		{},
		normalized.body,
		normalized.headers,
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"},
		normalized.errors
	)

func build_s2s_transaction_commit_request(fields: Dictionary, idempotent_key: String = "") -> Dictionary:
	var normalized := _normalize_s2s_transaction_commit_fields(fields, idempotent_key)
	return _build_validated_request(
		"POST",
		"/s2s/transactions/commit",
		{},
		normalized.body,
		normalized.headers,
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"},
		normalized.errors
	)

func build_s2s_transaction_clawback_request(fields: Dictionary) -> Dictionary:
	var normalized := _normalize_s2s_transaction_clawback_fields(fields)
	return _build_validated_request(
		"POST",
		"/s2s/transactions/clawback",
		{},
		normalized.body,
		normalized.headers,
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"},
		normalized.errors
	)

func build_s2s_disconnect_request(portal_id: String) -> Dictionary:
	var normalized := _normalize_s2s_disconnect_path(portal_id)
	return _build_validated_request(
		"DELETE",
		"/s2s/connections/%s" % normalized.portal_id,
		{},
		{},
		normalized.headers,
		{"auth_mode": "bearer"},
		normalized.errors
	)

func build_s2s_monetization_transactions_request(filters: Dictionary = {}, monetization_team_id: String = "") -> Dictionary:
	var normalized := _normalize_s2s_monetization_transactions_filters(filters, monetization_team_id)
	return _build_validated_request(
		"GET",
		"/s2s/monetization-teams/%s/transactions" % normalized.monetization_team_id,
		normalized.query,
		{},
		normalized.headers,
		{"auth_mode": "bearer"},
		normalized.errors
	)

func build_s2s_monetization_transaction_request(transaction_id: String, monetization_team_id: String = "") -> Dictionary:
	var normalized := _normalize_s2s_monetization_transaction_path(transaction_id, monetization_team_id)
	return _build_validated_request(
		"GET",
		"/s2s/monetization-teams/%s/transactions/%s" % [normalized.monetization_team_id, normalized.transaction_id],
		{},
		{},
		normalized.headers,
		{"auth_mode": "bearer"},
		normalized.errors
	)

func build_user_ratings_request(query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_authenticated_query()
	full_query.merge(query.to_query_dict(ModioListingQuery.ENDPOINT_USER_RATINGS), true)
	if not full_query.has("resource_type"):
		full_query["resource_type"] = "mods"
	if not full_query.has("game_id") and not _config.game_id.is_empty():
		full_query["game_id"] = _config.game_id
	return _transport.build_request(
		"GET",
		"/me/ratings",
		full_query,
		{},
		_build_read_headers(true),
		{"auth_mode": _resolve_read_auth_mode(true)}
	)

func build_add_mod_rating_request(mod_id: String, rating: int) -> Dictionary:
	return _transport.build_request(
		"POST",
		"/games/%s/mods/%s/ratings" % [_config.game_id, mod_id.strip_edges()],
		{},
		{"rating": rating},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_submit_report_request(resource: String, resource_id: String, report_type: int, summary: String, options: Dictionary = {}) -> Dictionary:
	var body := {
		"resource": resource.strip_edges().to_upper(),
		"id": resource_id.strip_edges(),
		"type": report_type,
		"summary": summary.strip_edges()
	}
	if options.has("name") and not str(options.get("name", "")).strip_edges().is_empty():
		body["name"] = str(options.get("name", "")).strip_edges()
	if options.has("contact") and not str(options.get("contact", "")).strip_edges().is_empty():
		body["contact"] = str(options.get("contact", "")).strip_edges()
	if options.has("reason"):
		var reason := int(options.get("reason", 0))
		if reason >= 0:
			body["reason"] = reason
	if options.has("platforms") and not str(options.get("platforms", "")).strip_edges().is_empty():
		body["platforms"] = str(options.get("platforms", "")).strip_edges().to_upper()
	if options.has("game_name_id") and not str(options.get("game_name_id", "")).strip_edges().is_empty():
		body["game_name_id"] = str(options.get("game_name_id", "")).strip_edges()
	return _transport.build_request(
		"POST",
		"/report",
		{},
		body,
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_subscribe_request(mod_id: String, include_dependencies: bool = false) -> Dictionary:
	var body := {}
	if include_dependencies:
		body["include_dependencies"] = true
	return _transport.build_request(
		"POST",
		"/games/%s/mods/%s/subscribe" % [_config.game_id, mod_id.strip_edges()],
		{},
		body,
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func build_unsubscribe_request(mod_id: String) -> Dictionary:
	return _transport.build_request(
		"DELETE",
		"/games/%s/mods/%s/subscribe" % [_config.game_id, mod_id.strip_edges()],
		{},
		{},
		_build_form_headers(true),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "bearer"}
	)

func normalize_access_token_response(payload: Dictionary) -> Dictionary:
	var date_expires := int(payload.get("date_expires", 0))
	var now := Time.get_unix_time_from_system()
	return {
		"access_token": str(payload.get("access_token", "")),
		"date_expires": date_expires,
		"expires_at": date_expires,
		"token_type": "Bearer",
		"has_expiry": date_expires > 0,
		"is_expired": date_expires > 0 and date_expires <= now,
		"expires_in_seconds": maxi(0, date_expires - now) if date_expires > 0 else -1
	}

func normalize_terms_response(payload: Dictionary) -> Dictionary:
	return {
		"plaintext": str(payload.get("plaintext", "")),
		"html": str(payload.get("html", "")),
		"buttons": _normalize_terms_buttons(payload.get("buttons", {})),
		"links": _normalize_terms_links(payload.get("links", {}))
	}

func normalize_agreement_response(payload: Dictionary) -> Dictionary:
	return {
		"id": int(payload.get("id", 0)),
		"is_active": bool(payload.get("is_active", false)),
		"is_latest": bool(payload.get("is_latest", false)),
		"type": int(payload.get("type", 0)),
		"user": _normalize_user_object(payload.get("user", {})),
		"date_added": int(payload.get("date_added", 0)),
		"date_updated": int(payload.get("date_updated", 0)),
		"date_live": int(payload.get("date_live", 0)),
		"name": str(payload.get("name", "")),
		"changelog": str(payload.get("changelog", "")),
		"description": str(payload.get("description", "")),
		"adjacent_versions": _normalize_adjacent_versions(payload.get("adjacent_versions", {}))
	}

func normalize_agreement_version_response(payload: Dictionary) -> Dictionary:
	return normalize_agreement_response(payload)

func normalize_authenticated_user_response(payload: Dictionary) -> Dictionary:
	var user := _normalize_user_object(payload)
	user["country"] = str(payload.get("country", ""))
	user["privacy_options"] = int(payload.get("privacy_options", 0))
	user["status"] = int(payload.get("status", 0))
	user["monetization_status"] = int(payload.get("monetization_status", 0))
	user["is_authenticated"] = user.id > 0
	return user

func normalize_game_response(payload: Dictionary) -> Dictionary:
	return {
		"id": int(payload.get("id", 0)),
		"name": str(payload.get("name", "")),
		"name_id": str(payload.get("name_id", "")),
		"profile_url": str(payload.get("profile_url", "")),
		"summary": str(payload.get("summary", "")),
		"instructions": str(payload.get("instructions", "")),
		"instructions_url": str(payload.get("instructions_url", "")),
		"api_access_options": int(payload.get("api_access_options", 0)),
		"dependency_option": int(payload.get("dependency_option", 0)),
		"submission_option": int(payload.get("submission_option", 0)),
		"community_options": int(payload.get("community_options", 0)),
		"maturity_options": int(payload.get("maturity_options", 0)),
		"tag_options": _normalize_tag_options(payload.get("tag_options", [])),
		"platforms": _normalize_game_platforms(payload.get("platforms", [])),
		"theme": _normalize_dictionary(payload.get("theme", {})),
		"stats": _normalize_game_stats_object(payload.get("stats", {})),
		"download_policy": interpret_game_download_policy(payload),
		"community_policy": interpret_game_community_policy(payload)
	}

func normalize_games_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_game_object"))

func normalize_user_games_response(payload: Dictionary) -> Dictionary:
	return normalize_games_response(payload)

func normalize_game_stats_response(payload: Dictionary) -> Dictionary:
	return _normalize_game_stats_object(payload)

func normalize_game_tags_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_game_tag_option_object"))

func normalize_game_token_packs_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_game_token_pack_object"))

func normalize_game_mod_stats_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_stats_object"))

func normalize_guide_tags_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_guide_tag_object"))

func normalize_ping_response(payload: Dictionary) -> Dictionary:
	return normalize_message_response(payload)

func normalize_mod_list_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_mod_object"))

func normalize_user_mods_response(payload: Dictionary) -> Dictionary:
	return normalize_mod_list_response(payload)

func normalize_mod_detail_response(payload: Dictionary) -> Dictionary:
	return _normalize_mod_object(payload)

func normalize_add_mod_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _normalize_mod_write_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["created"] = status_code == 201
	return response

func normalize_update_mod_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _normalize_mod_write_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["updated"] = status_code == 200
	return response

func normalize_delete_mod_response(status_code: int, headers: Dictionary = {}) -> Dictionary:
	var response := _normalize_no_content_write_response(status_code, headers)
	response["deleted"] = response.ok and status_code == 204
	return response

func normalize_modfiles_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_modfile_object"))

func normalize_user_modfiles_response(payload: Dictionary) -> Dictionary:
	return normalize_modfiles_response(payload)

func normalize_modfile_response(payload: Dictionary) -> Dictionary:
	return _normalize_modfile_object(payload)

func normalize_modfile_cooks_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_modfile_cook_object"))

func normalize_manage_modfile_platforms_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _normalize_modfile_write_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["updated"] = status_code == 200
	return response

func normalize_finalize_cloud_cooking_response(status_code: int, headers: Dictionary = {}) -> Dictionary:
	var response := _normalize_no_content_write_response(status_code, headers)
	response["finalized"] = response.ok and status_code == 204
	return response

func normalize_add_modfile_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _normalize_modfile_write_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["created"] = status_code == 201
	return response

func normalize_update_modfile_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _normalize_modfile_write_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["updated"] = status_code == 200
	return response

func normalize_delete_modfile_response(status_code: int, headers: Dictionary = {}) -> Dictionary:
	var response := _normalize_no_content_write_response(status_code, headers)
	response["deleted"] = response.ok and status_code == 204
	return response

func normalize_source_modfiles_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_modfile_object"))

func normalize_add_source_modfile_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _normalize_modfile_write_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["created"] = status_code == 201
	response["is_source_modfile"] = true
	return response

func normalize_create_multipart_upload_session_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _normalize_multipart_upload_write_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["created"] = status_code == 200
	return response

func normalize_multipart_upload_sessions_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_multipart_upload_object"))

func normalize_multipart_upload_parts_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_multipart_upload_part_object"))

func normalize_upload_multipart_part_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _transport.normalize_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["data"] = _normalize_multipart_upload_part_object(payload)
	response["uploaded"] = status_code == 200
	return response

func normalize_complete_multipart_upload_session_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _normalize_multipart_upload_write_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["completed"] = status_code == 200
	return response

func normalize_delete_multipart_upload_session_response(status_code: int, headers: Dictionary = {}) -> Dictionary:
	var response := _normalize_no_content_write_response(status_code, headers)
	response["deleted"] = response.ok and status_code == 204
	return response

func normalize_mod_stats_response(payload: Dictionary) -> Dictionary:
	var normalized := _normalize_stats_object(payload)
	var now := Time.get_unix_time_from_system()
	normalized["has_expiry"] = normalized.date_expires > 0
	normalized["is_stale"] = normalized.date_expires > 0 and normalized.date_expires <= now
	return normalized

func normalize_collections_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_collection_object"))

func normalize_user_followers_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_user_object"))

func normalize_user_following_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_user_object"))

func normalize_user_collections_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_collection_object"))

func normalize_me_followers_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_user_object"))

func normalize_muted_users_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_user_object"))

func normalize_me_collections_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_collection_object"))

func normalize_followed_collections_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_collection_object"))

func normalize_collection_response(payload: Dictionary) -> Dictionary:
	return _normalize_collection_object(payload)

func normalize_collection_mods_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_mod_object"))

func normalize_collection_comments_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_collection_comment_object"))

func normalize_collection_comment_response(payload: Dictionary) -> Dictionary:
	return _normalize_collection_comment_object(payload)

func normalize_collection_comment_write_response(payload: Dictionary) -> Dictionary:
	return _normalize_collection_comment_object(payload)

func normalize_add_collection_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _normalize_collection_write_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["created"] = status_code == 201
	return response

func normalize_update_collection_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _normalize_collection_write_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["updated"] = status_code == 200
	return response

func normalize_delete_collection_response(status_code: int, headers: Dictionary = {}) -> Dictionary:
	var response := _normalize_no_content_write_response(status_code, headers)
	response["deleted"] = response.ok and status_code == 204
	return response

func normalize_delete_collection_mods_response(status_code: int, headers: Dictionary = {}) -> Dictionary:
	var response := _normalize_no_content_write_response(status_code, headers)
	response["deleted"] = response.ok and status_code == 204
	return response

func normalize_guides_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_guide_object"))

func normalize_guide_response(payload: Dictionary) -> Dictionary:
	return _normalize_guide_object(payload)

func normalize_guide_comments_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_guide_comment_object"))

func normalize_guide_comment_response(payload: Dictionary) -> Dictionary:
	return _normalize_guide_comment_object(payload)

func normalize_guide_comment_write_response(payload: Dictionary) -> Dictionary:
	return _normalize_guide_comment_object(payload)

func normalize_add_guide_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _normalize_guide_write_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["created"] = status_code == 201
	return response

func normalize_update_guide_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _normalize_guide_write_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["updated"] = status_code == 200
	return response

func normalize_delete_guide_response(status_code: int, headers: Dictionary = {}) -> Dictionary:
	var response := _normalize_no_content_write_response(status_code, headers)
	response["deleted"] = response.ok and status_code == 204
	return response

func normalize_mod_comments_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_comment_object"))

func normalize_mod_comment_response(payload: Dictionary) -> Dictionary:
	return _normalize_comment_object(payload)

func normalize_comment_write_response(payload: Dictionary) -> Dictionary:
	return _normalize_comment_object(payload)

func normalize_follow_user_response(status_code: int, headers: Dictionary = {}) -> Dictionary:
	var response := _normalize_no_content_write_response(status_code, headers)
	response["followed"] = response.ok and status_code == 204
	return response

func normalize_unfollow_user_response(status_code: int, headers: Dictionary = {}) -> Dictionary:
	var response := _normalize_no_content_write_response(status_code, headers)
	response["unfollowed"] = response.ok and status_code == 204
	return response

func normalize_mute_user_response(status_code: int, headers: Dictionary = {}) -> Dictionary:
	var response := _normalize_no_content_write_response(status_code, headers)
	response["muted"] = response.ok and status_code == 204
	return response

func normalize_unmute_user_response(status_code: int, headers: Dictionary = {}) -> Dictionary:
	var response := _normalize_no_content_write_response(status_code, headers)
	response["unmuted"] = response.ok and status_code == 204
	return response

func normalize_follow_collection_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _transport.normalize_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["data"] = _normalize_collection_object(payload)
	response["already_followed"] = status_code == 200
	response["location"] = response.headers.get("location", "")
	return response

func normalize_unfollow_collection_response(status_code: int, headers: Dictionary = {}) -> Dictionary:
	var response := _normalize_no_content_write_response(status_code, headers)
	response["unfollowed"] = response.ok and status_code == 204
	return response

func normalize_comment_delete_response(status_code: int, headers: Dictionary = {}) -> Dictionary:
	var response := _normalize_no_content_write_response(status_code, headers)
	response["deleted"] = response.ok and status_code == 204
	return response

func normalize_user_ratings_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_rating_object"))

func normalize_message_response(payload: Dictionary) -> Dictionary:
	return {
		"code": int(payload.get("code", 0)),
		"message": str(payload.get("message", "")),
		"success": int(payload.get("code", 0)) >= 200 and int(payload.get("code", 0)) < 300
	}

func normalize_add_mod_rating_response(payload: Dictionary) -> Dictionary:
	return normalize_message_response(payload)

func normalize_add_collection_compatibility_response(payload: Dictionary) -> Dictionary:
	return normalize_message_response(payload)

func normalize_report_response(payload: Dictionary) -> Dictionary:
	return normalize_message_response(payload)

func normalize_dependencies_response(payload: Dictionary, recursive_requested: bool = false) -> Dictionary:
	var normalized := _normalize_list_payload(payload, Callable(self, "_normalize_dependency_object"))
	normalized["resolution"] = {
		"recursive_requested": recursive_requested,
		"policy": DEPENDENCY_POLICY_RECURSIVE if recursive_requested else DEPENDENCY_POLICY_IMMEDIATE_ONLY,
		"documented_recursive_depth_limit": DOCUMENTED_RECURSIVE_DEPENDENCY_DEPTH
	}
	return normalized

func normalize_dependants_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_dependant_object"))

func normalize_mod_tags_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_mod_tag_object"))

func normalize_mod_metadata_kvp_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_metadata_kvp_object"))

func normalize_add_mod_tags_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _normalize_message_write_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["created"] = status_code == 201
	return response

func normalize_delete_mod_tags_response(status_code: int, headers: Dictionary = {}) -> Dictionary:
	var response := _normalize_no_content_write_response(status_code, headers)
	response["deleted"] = response.ok and status_code == 204
	return response

func normalize_add_mod_metadata_kvp_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _normalize_message_write_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["created"] = status_code == 201
	return response

func normalize_delete_mod_metadata_kvp_response(status_code: int, headers: Dictionary = {}) -> Dictionary:
	var response := _normalize_no_content_write_response(status_code, headers)
	response["deleted"] = response.ok and status_code == 204
	return response

func normalize_add_mod_dependencies_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _normalize_message_write_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["created"] = status_code == 201
	return response

func normalize_delete_mod_dependencies_response(status_code: int, headers: Dictionary = {}) -> Dictionary:
	var response := _normalize_no_content_write_response(status_code, headers)
	response["deleted"] = response.ok and status_code == 204
	return response

func normalize_add_mod_media_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _normalize_message_write_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["created"] = status_code == 201
	return response

func normalize_reorder_mod_media_response(status_code: int, headers: Dictionary = {}) -> Dictionary:
	var response := _normalize_no_content_write_response(status_code, headers)
	response["reordered"] = response.ok and status_code == 204
	return response

func normalize_delete_mod_media_response(status_code: int, headers: Dictionary = {}) -> Dictionary:
	var response := _normalize_no_content_write_response(status_code, headers)
	response["deleted"] = response.ok and status_code == 204
	return response

func normalize_add_game_media_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _normalize_message_write_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["uploaded"] = status_code == 200
	return response

func normalize_mod_team_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_team_member_object"))

func normalize_mod_monetization_team_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_monetization_team_account_object"))

func normalize_create_mod_monetization_team_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _transport.normalize_response(status_code, headers, payload)
	if not response.ok:
		return response
	var normalized := normalize_mod_monetization_team_response(payload)
	for key in ["data", "result_count", "result_offset", "result_limit", "result_total", "page", "pagination"]:
		if normalized.has(key):
			response[key] = normalized[key]
	response["created"] = status_code == 200 and response.data is Array and response.data.size() > 0
	return response

func normalize_subscriptions_response(payload: Dictionary) -> Dictionary:
	return normalize_mod_list_response(payload)

func normalize_user_wallet_response(payload: Dictionary) -> Dictionary:
	return _normalize_user_wallet_object(payload)

func normalize_user_purchased_response(payload: Dictionary) -> Dictionary:
	return normalize_mod_list_response(payload)

func normalize_user_entitlements_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_entitlement_object"))

func normalize_checkout_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _transport.normalize_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["data"] = _normalize_checkout_pay_object(payload)
	response["completed"] = status_code == 200 and int(response.data.get("transaction_id", 0)) > 0
	return response

func normalize_s2s_transaction_intent_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _transport.normalize_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["data"] = _normalize_s2s_pay_object(payload)
	response["created"] = status_code == 200 and int(response.data.get("transaction_id", 0)) > 0
	return response

func normalize_s2s_transaction_commit_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _transport.normalize_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["data"] = _normalize_s2s_pay_object(payload)
	response["committed"] = status_code == 200 and int(response.data.get("transaction_id", 0)) > 0
	return response

func normalize_s2s_transaction_clawback_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _transport.normalize_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["data"] = _normalize_refund_object(payload)
	response["clawed_back"] = status_code == 200 and int(response.data.get("transaction_id", 0)) > 0
	return response

func normalize_s2s_disconnect_response(status_code: int, headers: Dictionary = {}) -> Dictionary:
	var response := _normalize_no_content_write_response(status_code, headers)
	response["disconnected"] = response.ok and status_code == 204
	return response

func normalize_s2s_monetization_transactions_response(payload: Dictionary) -> Dictionary:
	return {
		"data": _normalize_monetization_transaction_array(payload.get("data", [])),
		"pagination": _normalize_dictionary(payload.get("download", {})),
		"download": _normalize_dictionary(payload.get("download", {})),
		"drift_notes": [
			"The refreshed REST page models list filters under a GET body schema; this adapter serializes them as query parameters.",
			"The refreshed REST page labels the pagination envelope as 'download'; this adapter preserves it verbatim and aliases it to pagination."
		]
	}

func normalize_s2s_monetization_transaction_response(payload: Dictionary) -> Dictionary:
	var data := _normalize_monetization_transaction_array(payload.get("data", []))
	return {
		"data": data,
		"transaction": data[0] if data.size() > 0 else {},
		"drift_notes": [
			"The refreshed REST page models the single-transaction response as a data array rather than a singular object; this adapter preserves the array and exposes the first row as transaction for convenience."
		]
	}

func normalize_logout_response(payload: Dictionary) -> Dictionary:
	return normalize_message_response(payload)

func normalize_subscription_write_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _transport.normalize_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["data"] = _normalize_mod_object(payload)
	response["already_subscribed"] = status_code == 200
	response["location"] = response.headers.get("location", "")
	return response

func normalize_subscribe_collection_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _normalize_collection_write_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["subscribed"] = true
	return response

func normalize_unsubscribe_collection_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _normalize_collection_write_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["unsubscribed"] = true
	return response

func _normalize_no_content_write_response(status_code: int, headers: Dictionary = {}) -> Dictionary:
	var response := _transport.normalize_response(status_code, headers, {})
	if not response.ok:
		return response
	response["data"] = {}
	return response

func _normalize_mod_write_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _transport.normalize_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["data"] = _normalize_mod_object(payload)
	response["location"] = response.headers.get("location", "")
	return response

func _normalize_modfile_write_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _transport.normalize_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["data"] = _normalize_modfile_object(payload)
	response["location"] = response.headers.get("location", "")
	return response

func _normalize_multipart_upload_write_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _transport.normalize_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["data"] = _normalize_multipart_upload_object(payload)
	return response

func _normalize_collection_write_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _transport.normalize_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["data"] = _normalize_collection_object(payload)
	response["location"] = response.headers.get("location", "")
	return response

func _normalize_message_write_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _transport.normalize_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["data"] = normalize_message_response(payload)
	response["location"] = response.headers.get("location", "")
	return response

func _normalize_guide_write_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _transport.normalize_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["data"] = _normalize_guide_object(payload)
	response["location"] = response.headers.get("location", "")
	return response

func build_download_request(request: ModioDownloadRequest) -> Dictionary:
	assert(request != null)
	assert(request.is_valid())
	return {
		"mod_id": request.mod_id,
		"file_id": request.file_id,
		"binary_url": request.binary_url,
		"date_expires": request.date_expires,
		"md5": request.md5,
		"filename": request.filename,
		"is_expiring": request.date_expires > 0,
		"is_canonical_url": false,
		"warning": "mod.io binary_url values are expiring delivery URLs, not canonical permanent file URLs"
	}

func resolve_download_request_from_modfile(mod_id: String, modfile_payload: Dictionary) -> ModioDownloadRequest:
	var download: Dictionary = modfile_payload.get("download", {})
	var filehash: Dictionary = modfile_payload.get("filehash", {})
	return ModioDownloadRequest.new(
		mod_id.strip_edges(),
		_stringify_id_value(modfile_payload.get("id", 0)),
		str(download.get("binary_url", "")),
		int(download.get("date_expires", 0)),
		str(filehash.get("md5", "")),
		str(modfile_payload.get("filename", ""))
	)

func interpret_game_download_policy(game_payload: Dictionary) -> Dictionary:
	var api_access_options := int(game_payload.get("api_access_options", 0))
	var dependency_option := int(game_payload.get("dependency_option", DEPENDENCY_OPTION_DISALLOW))
	var allows_direct_downloads := (api_access_options & API_ACCESS_DOWNLOADS) != 0
	var requires_authenticated_download := (api_access_options & API_ACCESS_AUTHORISED_DOWNLOADS) != 0 or (api_access_options & API_ACCESS_PAID_DOWNLOADS) != 0
	var requires_entitlement_download := (api_access_options & API_ACCESS_PAID_DOWNLOADS) != 0
	return {
		"api_access_options": api_access_options,
		"dependency_option": dependency_option,
		"allows_open_api": (api_access_options & API_ACCESS_OPEN) != 0,
		"allows_direct_downloads": allows_direct_downloads,
		"requires_authenticated_download": requires_authenticated_download,
		"requires_entitlement_download": requires_entitlement_download,
		"delivery_urls_require_api_resolution": not allows_direct_downloads,
		"dependencies_enabled": dependency_option != DEPENDENCY_OPTION_DISALLOW,
		"dependency_mode": _dependency_option_to_string(dependency_option)
	}

func interpret_game_community_policy(game_payload: Dictionary) -> Dictionary:
	var community_options := int(game_payload.get("community_options", 0))
	return {
		"community_options": community_options,
		"allows_mod_comments": (community_options & COMMUNITY_OPTION_ALLOW_MOD_COMMENTS) != 0,
		"allows_guides": (community_options & COMMUNITY_OPTION_ALLOW_GUIDES) != 0,
		"allows_negative_ratings": (community_options & COMMUNITY_OPTION_ALLOW_NEGATIVE_RATINGS) != 0,
		"allows_dependencies": (community_options & COMMUNITY_OPTION_ALLOW_DEPENDENCY) != 0,
		"allows_guide_comments": (community_options & COMMUNITY_OPTION_ALLOW_GUIDE_COMMENTS) != 0
	}

func interpret_mod_community_policy(mod_payload: Dictionary) -> Dictionary:
	var community_options := int(mod_payload.get("community_options", 0))
	return {
		"community_options": community_options,
		"allows_comments": (community_options & COMMUNITY_OPTION_ALLOW_MOD_COMMENTS) != 0,
		"allows_negative_ratings": (community_options & COMMUNITY_OPTION_ALLOW_NEGATIVE_RATINGS) != 0,
		"allows_dependencies": (community_options & COMMUNITY_OPTION_ALLOW_DEPENDENCY) != 0
	}

func resolve_artifact_record_from_mod_detail(mod_payload: Dictionary, game_payload: Dictionary = {}) -> Dictionary:
	var source := {
		"kind": "mod_detail_current_modfile",
		"endpoint": "get_mod",
		"has_embedded_modfile": mod_payload.get("modfile", null) is Dictionary
	}
	return _build_artifact_record_from_mod_object(mod_payload, game_payload, source, _build_dependency_block(DEPENDENCY_POLICY_NONE, false, "", -1, false))

func resolve_artifact_record_from_modfile(mod_id: String, modfile_payload: Dictionary, game_payload: Dictionary = {}, extra: Dictionary = {}) -> Dictionary:
	var source := {
		"kind": str(extra.get("source_kind", "modfiles_item")),
		"endpoint": str(extra.get("source_endpoint", "get_modfiles")),
		"has_embedded_modfile": false
	}
	var dependency_block := _build_dependency_block(
		str(extra.get("dependency_policy", DEPENDENCY_POLICY_NONE)),
		bool(extra.get("is_dependency", false)),
		_stringify_id_value(extra.get("parent_mod_id", "")),
		int(extra.get("dependency_depth", -1)),
		bool(extra.get("recursive_requested", false))
	)
	var game_id := _resolve_game_id(game_payload, modfile_payload)
	return _build_artifact_record(game_id, mod_id, modfile_payload, game_payload, source, dependency_block)

func resolve_artifact_records_from_modfiles(mod_id: String, payload: Dictionary, game_payload: Dictionary = {}) -> Array:
	var records: Array = []
	for item in payload.get("data", []):
		if item is Dictionary:
			records.append(resolve_artifact_record_from_modfile(mod_id, item, game_payload))
	return dedupe_artifact_records(records)

func resolve_artifact_records_from_dependencies(parent_mod_id: String, payload: Dictionary, game_payload: Dictionary = {}, recursive_requested: bool = false) -> Dictionary:
	var records: Array = []
	for item in payload.get("data", []):
		if item is Dictionary:
			var mod_payload: Dictionary = item
			var source := {
				"kind": "dependency_modfile",
				"endpoint": "get_mod_dependencies",
				"has_embedded_modfile": mod_payload.get("modfile", null) is Dictionary
			}
			var dependency_block := _build_dependency_block(
				DEPENDENCY_POLICY_RECURSIVE if recursive_requested else DEPENDENCY_POLICY_IMMEDIATE_ONLY,
				true,
				parent_mod_id,
				int(mod_payload.get("dependency_depth", 0)),
				recursive_requested
			)
			records.append(_build_artifact_record_from_mod_object(mod_payload, game_payload, source, dependency_block))
	return {
		"artifacts": dedupe_artifact_records(records),
		"resolution": {
			"parent_mod_id": parent_mod_id,
			"recursive_requested": recursive_requested,
			"policy": DEPENDENCY_POLICY_RECURSIVE if recursive_requested else DEPENDENCY_POLICY_IMMEDIATE_ONLY,
			"documented_recursive_depth_limit": DOCUMENTED_RECURSIVE_DEPENDENCY_DEPTH
		}
	}

func dedupe_artifact_records(records: Array) -> Array:
	var deduped: Array = []
	var seen := {}
	for record in records:
		if not (record is Dictionary):
			continue
		var artifact_key := str(record.get("artifact_key", ""))
		if artifact_key.is_empty():
			deduped.append(record)
			continue
		if seen.has(artifact_key):
			continue
		seen[artifact_key] = true
		deduped.append(record)
	return deduped

func normalize_transport_response(status_code: int, headers: Dictionary = {}, payload: Variant = null) -> Dictionary:
	return _transport.normalize_response(status_code, headers, payload)

func _normalize_list_payload(payload: Dictionary, item_normalizer: Callable) -> Dictionary:
	var normalized_items: Array = []
	for item in payload.get("data", []):
		normalized_items.append(item_normalizer.call(item))
	var result_count := int(payload.get("result_count", normalized_items.size()))
	var result_offset := int(payload.get("result_offset", 0))
	var result_limit := int(payload.get("result_limit", normalized_items.size()))
	var result_total := int(payload.get("result_total", normalized_items.size()))
	return {
		"data": normalized_items,
		"result_count": result_count,
		"result_offset": result_offset,
		"result_limit": result_limit,
		"result_total": result_total,
		"page": _normalize_page_info(result_count, result_offset, result_limit, result_total)
	}

func _normalize_page_info(result_count: int, result_offset: int, result_limit: int, result_total: int) -> Dictionary:
	var safe_limit := maxi(result_limit, 1)
	var next_offset := result_offset + result_count
	var has_next := next_offset < result_total
	var has_previous := result_offset > 0
	return {
		"count": result_count,
		"offset": result_offset,
		"limit": safe_limit,
		"total": result_total,
		"has_next": has_next,
		"has_previous": has_previous,
		"next_offset": next_offset if has_next else -1,
		"previous_offset": maxi(0, result_offset - safe_limit) if has_previous else -1,
		"page_index": int(floor(float(result_offset) / float(safe_limit))),
		"page_count": int(ceil(float(result_total) / float(safe_limit))) if result_total > 0 else 0
	}

func _normalize_mod_object(payload: Dictionary) -> Dictionary:
	var normalized_modfile := {}
	if payload.get("modfile", null) is Dictionary:
		normalized_modfile = _normalize_modfile_object(payload.modfile)
	var normalized := {
		"id": int(payload.get("id", 0)),
		"game_id": int(payload.get("game_id", 0)),
		"name": str(payload.get("name", "")),
		"name_id": str(payload.get("name_id", "")),
		"profile_url": str(payload.get("profile_url", "")),
		"homepage_url": str(payload.get("homepage_url", "")),
		"summary": str(payload.get("summary", "")),
		"description": str(payload.get("description", "")),
		"description_plaintext": str(payload.get("description_plaintext", "")),
		"submitted_by": _normalize_user_object(payload.get("submitted_by", {})),
		"status": int(payload.get("status", 0)),
		"visible": int(payload.get("visible", 0)),
		"date_added": int(payload.get("date_added", 0)),
		"date_updated": int(payload.get("date_updated", 0)),
		"date_live": int(payload.get("date_live", 0)),
		"maturity_option": int(payload.get("maturity_option", 0)),
		"community_options": int(payload.get("community_options", 0)),
		"community_policy": interpret_mod_community_policy(payload),
		"monetization_options": int(payload.get("monetization_options", 0)),
		"credit_options": int(payload.get("credit_options", 0)),
		"stock": int(payload.get("stock", 0)),
		"price": int(payload.get("price", 0)),
		"tax": int(payload.get("tax", 0)),
		"dependencies": bool(payload.get("dependencies", false)),
		"metadata_blob": str(payload.get("metadata_blob", "")),
		"metadata_kvp": _normalize_metadata_kvp(payload.get("metadata_kvp", [])),
		"tags": _normalize_tags(payload.get("tags", [])),
		"platforms": _normalize_mod_platforms(payload.get("platforms", [])),
		"logo": _normalize_dictionary(payload.get("logo", {})),
		"media": _normalize_media_object(payload.get("media", {})),
		"stats": _normalize_stats_object(payload.get("stats", {})),
		"modfile": normalized_modfile,
		"skus": _normalize_skus(payload.get("skus", []))
	}
	if payload.has("dependency_depth"):
		normalized["dependency_depth"] = int(payload.get("dependency_depth", 0))
	return normalized

func _normalize_dependency_object(payload: Dictionary) -> Dictionary:
	var normalized := _normalize_mod_object(payload)
	normalized["dependency_depth"] = int(payload.get("dependency_depth", 0))
	return normalized

func _normalize_dependant_object(payload: Dictionary) -> Dictionary:
	return {
		"mod_id": int(payload.get("mod_id", 0)),
		"name": str(payload.get("name", "")),
		"name_id": str(payload.get("name_id", "")),
		"status": int(payload.get("status", 0)),
		"visible": int(payload.get("visible", 0)),
		"date_added": int(payload.get("date_added", 0)),
		"date_updated": int(payload.get("date_updated", 0)),
		"logo": _normalize_dictionary(payload.get("logo", {}))
	}

func _normalize_collection_object(payload: Dictionary) -> Dictionary:
	var normalized_stats := _normalize_collection_stats(payload.get("stats", {}))
	return {
		"id": int(payload.get("id", 0)),
		"game_id": int(payload.get("game_id", 0)),
		"status": int(payload.get("status", 0)),
		"visible": bool(payload.get("visible", false)),
		"submitted_by": _normalize_user_object(payload.get("submitted_by", {})),
		"category": str(payload.get("category", "")),
		"date_added": int(payload.get("date_added", 0)),
		"date_updated": int(payload.get("date_updated", 0)),
		"date_live": int(payload.get("date_live", 0)),
		"date_disabled": int(payload.get("date_disabled", 0)),
		"limit_number_mods": int(payload.get("limit_number_mods", 0)),
		"maturity_option": int(payload.get("maturity_option", 0)),
		"filesize": int(payload.get("filesize", 0)),
		"filesize_uncompressed": int(payload.get("filesize_uncompressed", 0)),
		"platforms": _normalize_string_array(payload.get("platforms", [])),
		"tags": _normalize_string_array(payload.get("tags", [])),
		"stats": normalized_stats,
		"logo": _normalize_dictionary(payload.get("logo", {})),
		"name": str(payload.get("name", "")),
		"name_id": str(payload.get("name_id", "")),
		"summary": str(payload.get("summary", "")),
		"description": str(payload.get("description", ""))
	}

func _normalize_guide_object(payload: Dictionary) -> Dictionary:
	var raw_community_options := int(payload.get("community_options", 0))
	var allows_comments := (raw_community_options & COMMUNITY_OPTION_ALLOW_GUIDE_COMMENTS) != 0
	var normalized_stats := _normalize_guide_stats(payload.get("stats", {}))
	return {
		"id": int(payload.get("id", 0)),
		"game_id": int(payload.get("game_id", 0)),
		"game_name": str(payload.get("game_name", "")),
		"resource_type": "guide",
		"logo": _normalize_dictionary(payload.get("logo", {})),
		"user": _normalize_user_object(payload.get("user", {})),
		"date_added": int(payload.get("date_added", 0)),
		"date_updated": int(payload.get("date_updated", 0)),
		"date_live": int(payload.get("date_live", 0)),
		"status": int(payload.get("status", 0)),
		"url": str(payload.get("url", "")),
		"name": str(payload.get("name", "")),
		"name_id": str(payload.get("name_id", "")),
		"summary": str(payload.get("summary", "")),
		"description": str(payload.get("description", "")),
		"community_options": raw_community_options,
		"allows_comments": allows_comments,
		"community_policy": {
			"community_options": raw_community_options,
			"allows_comments": allows_comments
		},
		"tags": _normalize_guide_tags(payload.get("tags", [])),
		"stats": normalized_stats,
		"visits_today": int(normalized_stats.get("visits_today", 0)),
		"visits_total": int(normalized_stats.get("visits_total", 0)),
		"comments_total": int(normalized_stats.get("comments_total", 0))
	}

func _normalize_game_object(payload: Dictionary) -> Dictionary:
	return normalize_game_response(payload)

func _normalize_game_stats_object(payload: Dictionary) -> Dictionary:
	var normalized := {
		"game_id": int(payload.get("game_id", 0)),
		"mods_count_total": int(payload.get("mods_count_total", 0)),
		"mods_downloads_today": int(payload.get("mods_downloads_today", 0)),
		"mods_downloads_total": int(payload.get("mods_downloads_total", 0)),
		"mods_downloads_daily_average": int(payload.get("mods_downloads_daily_average", 0)),
		"mods_subscribers_total": int(payload.get("mods_subscribers_total", 0)),
		"date_expires": int(payload.get("date_expires", 0))
	}
	var now := Time.get_unix_time_from_system()
	normalized["has_expiry"] = normalized.date_expires > 0
	normalized["is_stale"] = normalized.date_expires > 0 and normalized.date_expires <= now
	return normalized

func _normalize_stats_object(payload: Dictionary) -> Dictionary:
	return {
		"mod_id": int(payload.get("mod_id", 0)),
		"popularity_rank_position": int(payload.get("popularity_rank_position", 0)),
		"popularity_rank_total_mods": int(payload.get("popularity_rank_total_mods", 0)),
		"downloads_today": int(payload.get("downloads_today", 0)),
		"downloads_total": int(payload.get("downloads_total", 0)),
		"subscribers_total": int(payload.get("subscribers_total", 0)),
		"ratings_total": int(payload.get("ratings_total", 0)),
		"ratings_positive": int(payload.get("ratings_positive", 0)),
		"ratings_negative": int(payload.get("ratings_negative", 0)),
		"ratings_percentage_positive": int(payload.get("ratings_percentage_positive", 0)),
		"ratings_weighted_aggregate": float(payload.get("ratings_weighted_aggregate", 0.0)),
		"ratings_display_text": str(payload.get("ratings_display_text", "")),
		"date_expires": int(payload.get("date_expires", 0))
	}

func _normalize_rating_object(payload: Dictionary) -> Dictionary:
	var raw_rating := int(payload.get("rating", 0))
	var resource_type := str(payload.get("resource_type", "")).to_lower()
	var resource_id := int(payload.get("resource_id", 0))
	return {
		"game_id": int(payload.get("game_id", 0)),
		"mod_id": int(payload.get("mod_id", 0)),
		"resource_type": resource_type,
		"resource_id": resource_id,
		"rating": raw_rating,
		"is_positive": raw_rating > 0,
		"is_negative": raw_rating < 0,
		"sentiment": "positive" if raw_rating > 0 else "negative" if raw_rating < 0 else "neutral",
		"date_added": int(payload.get("date_added", 0))
	}

func _normalize_modfile_object(payload: Dictionary) -> Dictionary:
	var download: Dictionary = payload.get("download", {})
	return {
		"id": int(payload.get("id", 0)),
		"mod_id": int(payload.get("mod_id", 0)),
		"date_added": int(payload.get("date_added", 0)),
		"date_updated": int(payload.get("date_updated", 0)),
		"date_scanned": int(payload.get("date_scanned", 0)),
		"virus_status": int(payload.get("virus_status", 0)),
		"virus_positive": int(payload.get("virus_positive", 0)),
		"virustotal_hash": str(payload.get("virustotal_hash", "")),
		"filesize": int(payload.get("filesize", 0)),
		"filesize_uncompressed": int(payload.get("filesize_uncompressed", 0)),
		"filehash": _normalize_dictionary(payload.get("filehash", {})),
		"filename": str(payload.get("filename", "")),
		"version": str(payload.get("version", "")),
		"changelog": str(payload.get("changelog", "")),
		"metadata_blob": str(payload.get("metadata_blob", "")),
		"download": {
			"binary_url": str(download.get("binary_url", "")),
			"date_expires": int(download.get("date_expires", 0)),
			"is_expiring": int(download.get("date_expires", 0)) > 0,
			"is_canonical_url": false
		},
		"platforms": _normalize_file_platforms(payload.get("platforms", []))
	}

func _normalize_modfile_cook_object(payload: Dictionary) -> Dictionary:
	return {
		"cook_uuid": str(payload.get("cook_uuid", "")),
		"modfile": int(payload.get("modfile", 0)),
		"platform": str(payload.get("platform", "")),
		"status": int(payload.get("status", 0)),
		"date_added": int(payload.get("date_added", 0)),
		"date_updated": int(payload.get("date_updated", 0)),
		"metadata": _normalize_string_array(payload.get("metadata", [])),
		"logs": _normalize_string_array(payload.get("logs", [])),
		"filename": str(payload.get("filename", "")),
		"filesize": int(payload.get("filesize", 0)),
		"version": str(payload.get("version", ""))
	}

func _normalize_multipart_upload_object(payload: Dictionary) -> Dictionary:
	var status := int(payload.get("status", 0))
	return {
		"upload_id": str(payload.get("upload_id", "")),
		"status": status,
		"status_label": _multipart_upload_status_label(status),
		"is_incomplete": status == 0,
		"is_pending": status == 1,
		"is_processing": status == 2,
		"is_complete": status == 3,
		"is_cancelled": status == 4
	}

func _normalize_multipart_upload_part_object(payload: Dictionary) -> Dictionary:
	return {
		"upload_id": str(payload.get("upload_id", "")),
		"part_number": int(payload.get("part_number", 0)),
		"part_size": int(payload.get("part_size", 0)),
		"date_added": int(payload.get("date_added", 0))
	}

func _normalize_guide_comment_object(payload: Dictionary) -> Dictionary:
	var normalized := _normalize_comment_object(payload)
	normalized["resource_type"] = "guide_comment"
	return normalized

func _normalize_collection_comment_object(payload: Dictionary) -> Dictionary:
	var normalized := _normalize_comment_object(payload)
	normalized["resource_type"] = "collection_comment"
	return normalized

func _normalize_comment_object(payload: Dictionary) -> Dictionary:
	var raw_reply_id := int(payload.get("reply_id", 0))
	var raw_thread_position := str(payload.get("thread_position", ""))
	var raw_options := int(payload.get("options", 0))
	return {
		"id": int(payload.get("id", 0)),
		"game_id": int(payload.get("game_id", 0)),
		"mod_id": int(payload.get("mod_id", 0)),
		"resource_id": int(payload.get("resource_id", 0)),
		"resource_ownership": int(payload.get("resource_ownership", 0)),
		"user": _normalize_user_object(payload.get("user", {})),
		"date_added": int(payload.get("date_added", 0)),
		"reply_id": raw_reply_id,
		"thread_position": raw_thread_position,
		"karma": int(payload.get("karma", 0)),
		"karma_guest": int(payload.get("karma_guest", 0)),
		"content": str(payload.get("content", "")),
		"options": raw_options,
		"is_reply": raw_reply_id > 0,
		"thread_depth": _calculate_comment_thread_depth(raw_thread_position),
		"is_pinned": (raw_options & COMMENT_OPTION_PINNED) != 0,
		"is_locked": (raw_options & COMMENT_OPTION_LOCKED) != 0,
		"option_flags": _build_comment_option_flags(raw_options),
		"resource_type": "mod_comment"
	}

func _normalize_user_object(payload: Dictionary) -> Dictionary:
	if payload.is_empty():
		return {}
	return {
		"id": int(payload.get("id", 0)),
		"name_id": str(payload.get("name_id", "")),
		"username": str(payload.get("username", "")),
		"display_name_portal": payload.get("display_name_portal", null),
		"date_online": int(payload.get("date_online", 0)),
		"date_joined": int(payload.get("date_joined", 0)),
		"avatar": _normalize_dictionary(payload.get("avatar", {})),
		"timezone": str(payload.get("timezone", "")),
		"language": str(payload.get("language", "")),
		"profile_url": str(payload.get("profile_url", ""))
	}

func _normalize_terms_buttons(payload: Dictionary) -> Dictionary:
	var normalized := {}
	for key in payload.keys():
		normalized[str(key)] = _normalize_dictionary(payload.get(key, {}))
	return normalized

func _normalize_terms_links(payload: Dictionary) -> Dictionary:
	var normalized := {}
	for key in payload.keys():
		var link: Dictionary = payload.get(key, {})
		normalized[str(key)] = {
			"text": str(link.get("text", "")),
			"url": str(link.get("url", "")),
			"required": bool(link.get("required", false))
		}
	return normalized

func _normalize_adjacent_versions(payload: Dictionary) -> Dictionary:
	var normalized := {}
	for key in payload.keys():
		var version: Dictionary = payload.get(key, {})
		normalized[str(key)] = {
			"id": int(version.get("id", 0)),
			"date_live": int(version.get("date_live", 0))
		}
	return normalized

func _normalize_game_tag_option_object(payload: Dictionary) -> Dictionary:
	var name_localization := _normalize_dictionary(payload.get("name_localization", {}))
	var tags_localized := _normalize_dictionary(payload.get("tags_localized", {}))
	return {
		"name": str(payload.get("name", "")),
		"name_localized": str(payload.get("name_localized", "")),
		"name_localization": name_localization,
		"type": str(payload.get("type", "")),
		"tags": _normalize_string_array(payload.get("tags", [])),
		"tags_localized": tags_localized,
		"tags_localization": _normalize_tag_localizations(payload.get("tags_localization", [])),
		"tag_count_map": _normalize_dictionary(payload.get("tag_count_map", {})),
		"hidden": bool(payload.get("hidden", false)),
		"locked": bool(payload.get("locked", false))
	}

func _normalize_tag_options(payload: Array) -> Array:
	var normalized: Array = []
	for item in payload:
		if item is Dictionary:
			normalized.append(_normalize_game_tag_option_object(item))
	return normalized

func _normalize_game_platforms(payload: Array) -> Array:
	var normalized: Array = []
	for item in payload:
		if item is Dictionary:
			normalized.append({
				"platform": str(item.get("platform", "")),
				"label": str(item.get("label", "")),
				"moderated": bool(item.get("moderated", false)),
				"locked": bool(item.get("locked", false))
			})
	return normalized

func _normalize_mod_platforms(payload: Array) -> Array:
	var normalized: Array = []
	for item in payload:
		if item is Dictionary:
			normalized.append({
				"platform": str(item.get("platform", "")),
				"modfile_live": int(item.get("modfile_live", 0))
			})
	return normalized

func _normalize_file_platforms(payload: Array) -> Array:
	var normalized: Array = []
	for item in payload:
		if item is Dictionary:
			normalized.append({
				"platform": str(item.get("platform", "")),
				"status": int(item.get("status", 0))
			})
	return normalized

func _normalize_metadata_kvp(payload: Array) -> Array:
	var normalized: Array = []
	for item in payload:
		if item is Dictionary:
			normalized.append(_normalize_metadata_kvp_object(item))
	return normalized

func _normalize_metadata_kvp_object(payload: Dictionary) -> Dictionary:
	return {
		"metakey": str(payload.get("metakey", "")),
		"metavalue": str(payload.get("metavalue", ""))
	}

func _normalize_tags(payload: Array) -> Array:
	var normalized: Array = []
	for item in payload:
		if item is Dictionary:
			normalized.append(_normalize_mod_tag_object(item))
	return normalized

func _normalize_mod_tag_object(payload: Dictionary) -> Dictionary:
	return {
		"name": str(payload.get("name", "")),
		"name_localized": str(payload.get("name_localized", "")),
		"date_added": int(payload.get("date_added", 0))
	}

func _normalize_guide_tag_object(payload: Dictionary) -> Dictionary:
	return {
		"name": str(payload.get("name", "")),
		"date_added": int(payload.get("date_added", 0)),
		"count": int(payload.get("count", 0))
	}

func _normalize_guide_tags(payload: Array) -> Array:
	var normalized: Array = []
	for item in payload:
		if item is Dictionary:
			normalized.append(_normalize_guide_tag_object(item))
	return normalized

func _normalize_guide_stats(payload: Variant) -> Dictionary:
	var source: Dictionary = {}
	if payload is Array:
		if payload.size() > 0 and payload[0] is Dictionary:
			source = payload[0]
	elif payload is Dictionary:
		source = payload
	return {
		"guide_id": int(source.get("guide_id", 0)),
		"visits_today": int(source.get("visits_today", 0)),
		"visits_total": int(source.get("visits_total", 0)),
		"comments_total": int(source.get("comments_total", 0))
	}

func _normalize_tag_localizations(payload: Array) -> Array:
	var normalized: Array = []
	for item in payload:
		if item is Dictionary:
			normalized.append({
				"tag": str(item.get("tag", "")),
				"translations": _normalize_dictionary(item.get("translations", {}))
			})
	return normalized

func _normalize_team_member_object(payload: Dictionary) -> Dictionary:
	var level := int(payload.get("level", 0))
	var invite_pending := int(payload.get("invite_pending", 0))
	return {
		"id": int(payload.get("id", 0)),
		"user": _normalize_user_object(payload.get("user", {})),
		"level": level,
		"date_added": int(payload.get("date_added", 0)),
		"position": str(payload.get("position", "")),
		"invite_pending": invite_pending,
		"is_pending": invite_pending != 0
	}

func _normalize_monetization_team_account_object(payload: Dictionary) -> Dictionary:
	return {
		"id": int(payload.get("id", 0)),
		"name_id": str(payload.get("name_id", "")),
		"username": str(payload.get("username", "")),
		"monetization_status": int(payload.get("monetization_status", 0)),
		"monetization_options": int(payload.get("monetization_options", 0)),
		"split": int(payload.get("split", 0))
	}

func _normalize_game_token_pack_object(payload: Dictionary) -> Dictionary:
	return {
		"id": int(payload.get("id", 0)),
		"token_pack_id": int(payload.get("token_pack_id", 0)),
		"price": int(payload.get("price", 0)),
		"amount": int(payload.get("amount", 0)),
		"portal": str(payload.get("portal", "")),
		"sku": str(payload.get("sku", "")),
		"name": str(payload.get("name", "")),
		"description": str(payload.get("description", "")),
		"date_added": int(payload.get("date_added", 0)),
		"date_updated": int(payload.get("date_updated", 0))
	}

func _normalize_user_wallet_object(payload: Dictionary) -> Dictionary:
	return {
		"type": str(payload.get("type", "")),
		"payment_method_id": str(payload.get("payment_method_id", "")),
		"game_id": str(payload.get("game_id", "")),
		"currency": str(payload.get("currency", "")),
		"balance": int(payload.get("balance", 0)),
		"pending_balance": int(payload.get("pending_balance", 0)),
		"deficit": int(payload.get("deficit", 0)),
		"monetization_status": int(payload.get("monetization_status", 0))
	}

func _normalize_entitlement_object(payload: Dictionary) -> Dictionary:
	return {
		"sku_id": str(payload.get("sku_id", "")),
		"entitlement_type": int(payload.get("entitlement_type", 0))
	}

func _normalize_transaction_meta_array(payload: Array) -> Array:
	var normalized: Array = []
	for item in payload:
		if item is Dictionary:
			normalized.append(_normalize_dictionary(item))
	return normalized

func _normalize_payment_method_array(payload: Array) -> Array:
	var normalized: Array = []
	for item in payload:
		if item is Dictionary:
			normalized.append({
				"name": str(item.get("name", "")),
				"id": str(item.get("id", "")),
				"amount": int(item.get("amount", 0)),
				"display_amount": str(item.get("display_amount", ""))
			})
	return normalized

func _normalize_transaction_line_items(payload: Array) -> Array:
	var normalized: Array = []
	for item in payload:
		if item is Dictionary:
			normalized.append(_normalize_dictionary(item))
	return normalized

func _normalize_transaction_items(payload: Array) -> Array:
	var normalized: Array = []
	for item in payload:
		if item is Dictionary:
			var normalized_item := _normalize_dictionary(item)
			normalized_item["line_items"] = _normalize_transaction_line_items(item.get("line_items", []))
			normalized_item["breakdown"] = item.get("breakdown", [])
			normalized.append(normalized_item)
	return normalized

func _normalize_checkout_pay_object(payload: Dictionary) -> Dictionary:
	var normalized := _normalize_s2s_pay_object(payload)
	normalized["wallet_type"] = str(payload.get("wallet_type", ""))
	normalized["balance"] = int(payload.get("balance", 0))
	normalized["deficit"] = int(payload.get("deficit", 0))
	normalized["payment_method_id"] = str(payload.get("payment_method_id", ""))
	normalized["mod"] = _normalize_mod_object(payload.get("mod", {})) if payload.get("mod", null) is Dictionary else {}
	return normalized

func _normalize_s2s_pay_object(payload: Dictionary) -> Dictionary:
	return {
		"transaction_id": int(payload.get("transaction_id", 0)),
		"gateway_uuid": str(payload.get("gateway_uuid", "")),
		"gross_amount": int(payload.get("gross_amount", 0)),
		"net_amount": int(payload.get("net_amount", 0)),
		"platform_fee": int(payload.get("platform_fee", 0)),
		"gateway_fee": int(payload.get("gateway_fee", 0)),
		"transaction_type": str(payload.get("transaction_type", "")),
		"meta": _normalize_transaction_meta_array(payload.get("meta", [])),
		"purchase_date": int(payload.get("purchase_date", 0))
	}

func _normalize_refund_object(payload: Dictionary) -> Dictionary:
	var normalized := _normalize_s2s_pay_object(payload)
	normalized["tax"] = int(payload.get("tax", 0))
	normalized["tax_type"] = str(payload.get("tax_type", ""))
	return normalized

func _normalize_monetization_transaction_array(payload: Array) -> Array:
	var normalized: Array = []
	for item in payload:
		if item is Dictionary:
			normalized.append(_normalize_monetization_transaction_object(item))
	return normalized

func _normalize_monetization_transaction_object(payload: Dictionary) -> Dictionary:
	return {
		"id": int(payload.get("id", 0)),
		"gateway_uuid": str(payload.get("gateway_uuid", "")),
		"gateway_name": str(payload.get("gateway_name", "")),
		"account_id": int(payload.get("account_id", 0)),
		"gross_amount": int(payload.get("gross_amount", 0)),
		"net_amount": int(payload.get("net_amount", 0)),
		"platform_fee": int(payload.get("platform_fee", 0)),
		"gateway_fee": int(payload.get("gateway_fee", 0)),
		"tax": int(payload.get("tax", 0)),
		"tax_type": str(payload.get("tax_type", "")),
		"currency": str(payload.get("currency", "")),
		"tokens": int(payload.get("tokens", 0)),
		"transaction_type": str(payload.get("transaction_type", "")),
		"monetization_type": str(payload.get("monetization_type", "")),
		"purchase_date": str(payload.get("purchase_date", "")),
		"created_at": str(payload.get("created_at", "")),
		"payment_method": _normalize_payment_method_array(payload.get("payment_method", [])),
		"items": _normalize_transaction_items(payload.get("items", [])),
		"line_items": _normalize_transaction_line_items(payload.get("line_items", []))
	}

func _normalize_collection_stats(payload: Variant) -> Dictionary:
	var source: Dictionary = {}
	if payload is Array:
		if payload.size() > 0 and payload[0] is Dictionary:
			source = payload[0]
	elif payload is Dictionary:
		source = payload
	return {
		"collection_id": int(source.get("collection_id", 0)),
		"downloads_today": int(source.get("downloads_today", 0)),
		"downloads_unique": int(source.get("downloads_unique", 0)),
		"downloads_total": int(source.get("downloads_total", 0)),
		"followers_total": int(source.get("followers_total", 0)),
		"ratings_positive_30_days": int(source.get("ratings_positive_30_days", 0))
	}

func _normalize_string_array(payload: Array) -> Array:
	var normalized: Array = []
	for item in payload:
		normalized.append(str(item))
	return normalized

func _normalize_media_object(payload: Dictionary) -> Dictionary:
	var images: Array = []
	for image in payload.get("images", []):
		if image is Dictionary:
			images.append(_normalize_dictionary(image))
	return {
		"youtube": payload.get("youtube", []),
		"sketchfab": payload.get("sketchfab", []),
		"images": images
	}

func _normalize_skus(payload: Array) -> Array:
	var normalized: Array = []
	for item in payload:
		if item is Dictionary:
			normalized.append({
				"id": int(item.get("id", 0)),
				"sku": str(item.get("sku", "")),
				"portal": str(item.get("portal", ""))
			})
	return normalized

func _normalize_dictionary(payload: Dictionary) -> Dictionary:
	return payload.duplicate(true)

func _calculate_comment_thread_depth(thread_position: String) -> int:
	var sanitized := thread_position.strip_edges()
	if sanitized.is_empty():
		return 0
	return sanitized.split(".").size()

func _build_comment_option_flags(raw_options: int) -> Dictionary:
	return {
		"pinned": (raw_options & COMMENT_OPTION_PINNED) != 0,
		"locked": (raw_options & COMMENT_OPTION_LOCKED) != 0
	}

func _build_external_auth_request(path: String, body: Dictionary) -> Dictionary:
	return _transport.build_request(
		"POST",
		path,
		{},
		body,
		_build_form_headers(false),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "api_key_query"}
	)

func _append_optional_email(body: Dictionary, email: String) -> void:
	var sanitized_email := email.strip_edges()
	if not sanitized_email.is_empty():
		body["email"] = sanitized_email

func _build_follow_user_body(target_user_id: String) -> Dictionary:
	return {"user_id": target_user_id.strip_edges()}

func _append_optional_date_expires(body: Dictionary, date_expires: int, max_lifetime_seconds: int) -> void:
	var sanitized_date_expires := _sanitize_requested_expiry(date_expires, max_lifetime_seconds)
	if sanitized_date_expires > 0:
		body["date_expires"] = sanitized_date_expires

func _normalize_guide_authoring_fields(fields: Dictionary, is_create: bool) -> Dictionary:
	var body := {}
	var errors: Array = []
	var allowed_fields := ["name", "summary", "description", "logo", "date_live", "status", "community_options", "tags", "name_id"]
	if not is_create:
		allowed_fields.append("url")
	_validate_allowed_fields(fields, allowed_fields, errors, "guide")
	_append_validated_string_field(fields, body, "name", 70, errors, is_create)
	_append_validated_string_field(fields, body, "summary", 250, errors, is_create, 20)
	_append_validated_string_field(fields, body, "description", 150000, errors, is_create)
	_append_raw_multipart_field(fields, body, "logo", errors, is_create)
	_append_optional_non_negative_int_field(fields, body, "date_live", errors)
	_append_optional_enum_int_field(fields, body, "status", GUIDE_STATUS_VALUES, errors)
	_append_optional_enum_int_field(fields, body, "community_options", GUIDE_COMMUNITY_OPTION_VALUES, errors)
	_append_validated_string_field(fields, body, "name_id", 50, errors, false)
	if not is_create:
		_append_validated_url_field(fields, body, "url", errors)
	_append_guide_tags_field(fields, body, errors, is_create)
	return {"body": body, "errors": errors}

func _normalize_mod_authoring_fields(fields: Dictionary, is_create: bool) -> Dictionary:
	var body := {}
	var errors: Array = []
	var allowed_fields := [
		"name",
		"name_id",
		"summary",
		"description",
		"logo",
		"homepage_url",
		"visible",
		"maturity_option",
		"community_options",
		"credit_options",
		"stock",
		"metadata_kvp",
		"metadata_blob",
		"tags",
		"tokenpack_id"
	]
	if not is_create:
		allowed_fields.append_array(["status", "price", "monetization_options"])
	_validate_allowed_fields(fields, allowed_fields, errors, "mod")
	if is_create:
		_append_required_non_empty_string_field(fields, body, "name", errors, true)
	else:
		_append_optional_non_empty_string_field(fields, body, "name", errors)
	_append_optional_non_empty_string_field(fields, body, "name_id", errors)
	_append_optional_string_field(fields, body, "summary", errors)
	_append_optional_string_field(fields, body, "description", errors)
	_append_raw_multipart_field(fields, body, "logo", errors, is_create)
	_append_validated_url_field(fields, body, "homepage_url", errors)
	_append_optional_enum_int_field(fields, body, "visible", MOD_VISIBILITY_VALUES, errors)
	_append_optional_enum_int_field(fields, body, "maturity_option", MOD_MATURITY_OPTION_VALUES, errors)
	_append_optional_enum_int_field(fields, body, "community_options", MOD_COMMUNITY_OPTION_VALUES, errors)
	_append_optional_enum_int_field(fields, body, "credit_options", MOD_CREDIT_OPTION_VALUES, errors)
	_append_optional_enum_int_field(fields, body, "stock", MOD_STOCK_VALUES, errors)
	if is_create:
		_append_required_string_array_field(fields, body, "metadata_kvp", errors)
	else:
		_append_optional_string_array_field(fields, body, "metadata_kvp", errors)
	if body.has("metadata_kvp"):
		body["metadata[]"] = body["metadata_kvp"]
		body.erase("metadata_kvp")
	_append_optional_string_field(fields, body, "metadata_blob", errors)
	_append_optional_string_array_field(fields, body, "tags", errors)
	_append_optional_int_like_field(fields, body, "tokenpack_id", errors)
	if not is_create:
		_append_optional_enum_int_field(fields, body, "status", MOD_STATUS_VALUES, errors)
		_append_optional_int_like_field(fields, body, "price", errors)
		_append_optional_enum_int_field(fields, body, "monetization_options", MOD_MONETIZATION_OPTION_VALUES, errors)
	return {"body": body, "errors": errors}

func _normalize_collection_authoring_fields(fields: Dictionary, is_update: bool) -> Dictionary:
	var body := {}
	var errors: Array = []
	var allowed_fields := ["name", "name_id", "summary", "category", "description", "logo", "status", "visible", "tags", "mod_ids"]
	if is_update:
		allowed_fields.append("sync")
	_validate_allowed_fields(fields, allowed_fields, errors, "collection")
	_append_validated_string_field(fields, body, "name", 50, errors, false)
	_append_validated_string_field(fields, body, "name_id", 50, errors, false)
	_append_validated_string_field(fields, body, "summary", 250, errors, false)
	_append_validated_string_field(fields, body, "description", 50000, errors, false)
	_append_raw_multipart_field(fields, body, "logo", errors, false)
	_append_optional_int_like_field(fields, body, "category", errors)
	_append_optional_enum_int_field(fields, body, "status", COLLECTION_STATUS_VALUES, errors)
	_append_optional_enum_int_field(fields, body, "visible", COLLECTION_VISIBILITY_VALUES, errors)
	_append_collection_tags_field(fields, body, errors)
	_append_int_array_field(fields, body, "mod_ids", errors)
	if is_update:
		_append_optional_boolean_field(fields, body, "sync", errors)
	return {"body": body, "errors": errors}

func _normalize_add_modfile_fields(fields: Dictionary) -> Dictionary:
	var body := {}
	var errors: Array = []
	_validate_allowed_fields(fields, ["filedata", "upload_id", "version", "changelog", "active", "filehash", "metadata_blob", "platforms"], errors, "modfile")
	_append_raw_multipart_field(fields, body, "filedata", errors, false)
	_append_required_non_empty_string_field(fields, body, "upload_id", errors, false)
	_append_optional_string_field(fields, body, "version", errors)
	_append_optional_string_field(fields, body, "changelog", errors)
	_append_optional_boolean_field(fields, body, "active", errors)
	_append_optional_string_field(fields, body, "filehash", errors)
	_append_optional_string_field(fields, body, "metadata_blob", errors)
	_append_modfile_platforms_field(fields, body, errors)
	var has_filedata := body.has("filedata")
	var has_upload_id := body.has("upload_id")
	if has_filedata == has_upload_id:
		errors.append("Exactly one of filedata or upload_id must be supplied")
	return {"body": body, "errors": errors}

func _normalize_update_modfile_fields(fields: Dictionary) -> Dictionary:
	var body := {}
	var errors: Array = []
	_validate_allowed_fields(fields, ["version", "changelog", "active", "metadata_blob"], errors, "modfile")
	_append_optional_string_field(fields, body, "version", errors)
	_append_optional_string_field(fields, body, "changelog", errors)
	_append_optional_boolean_field(fields, body, "active", errors)
	_append_optional_string_field(fields, body, "metadata_blob", errors)
	return {"body": body, "errors": errors}

func _normalize_manage_modfile_platforms_fields(fields: Dictionary) -> Dictionary:
	var body := {}
	var errors: Array = []
	_validate_allowed_fields(fields, ["approved", "denied"], errors, "platform status")
	var provided_field_count := 0
	if fields.has("approved"):
		provided_field_count += 1
		_append_platform_status_array_field(fields["approved"], body, "approved[]", "approved", errors)
	if fields.has("denied"):
		provided_field_count += 1
		_append_platform_status_array_field(fields["denied"], body, "denied[]", "denied", errors)
	if provided_field_count == 0:
		errors.append("At least one of approved or denied must be supplied")
	return {"body": body, "errors": errors}

func _normalize_create_multipart_upload_session_fields(fields: Dictionary) -> Dictionary:
	var body := {}
	var errors: Array = []
	_validate_allowed_fields(fields, ["filename", "nonce"], errors, "multipart upload session")
	_append_validated_string_field(fields, body, "filename", 100, errors, true)
	if body.has("filename") and not str(body.filename).to_lower().ends_with(".zip"):
		errors.append("filename must include the .zip extension")
	_append_validated_string_field(fields, body, "nonce", 64, errors, false)
	return {"body": body, "errors": errors}

func _normalize_multipart_upload_session_filters(filters: Dictionary) -> Dictionary:
	var query := _build_authenticated_query()
	var errors: Array = []
	_validate_allowed_fields(filters, ["status", "_limit", "_offset"], errors, "multipart upload session filter")
	if filters.has("status"):
		var parsed_status = _parse_int_like(filters["status"])
		if parsed_status == null or not MULTIPART_UPLOAD_STATUS_VALUES.has(int(parsed_status)):
			errors.append("status must be one of 0, 1, 2, 3, 4")
		else:
			query["status"] = str(int(parsed_status))
	if filters.has("_limit"):
		var parsed_limit = _parse_int_like(filters["_limit"])
		if parsed_limit == null or int(parsed_limit) < 1 or int(parsed_limit) > 100:
			errors.append("_limit must be an integer between 1 and 100")
		else:
			query["_limit"] = str(int(parsed_limit))
	if filters.has("_offset"):
		var parsed_offset = _parse_int_like(filters["_offset"])
		if parsed_offset == null or int(parsed_offset) < 0:
			errors.append("_offset must be a non-negative integer")
		else:
			query["_offset"] = str(int(parsed_offset))
	return {"query": query, "errors": errors}

func _build_multipart_upload_id_query(upload_id: String, errors: Array) -> Dictionary:
	var query := _build_authenticated_query()
	var sanitized := upload_id.strip_edges()
	if sanitized.is_empty():
		errors.append("upload_id must be a non-empty string")
	else:
		query["upload_id"] = sanitized
	return query

func _normalize_multipart_upload_part_headers(content_range: String, digest: String, errors: Array) -> Dictionary:
	var headers := {}
	var sanitized_content_range := content_range.strip_edges()
	if sanitized_content_range.is_empty():
		errors.append("Content-Range must be a non-empty string")
	else:
		headers["Content-Range"] = sanitized_content_range
	var sanitized_digest := digest.strip_edges()
	if not sanitized_digest.is_empty():
		headers["Digest"] = sanitized_digest
	return headers

func _normalize_multipart_upload_part_body(part_body: Variant, errors: Array) -> Variant:
	if part_body == null:
		errors.append("part_body must be raw bytes")
		return PackedByteArray()
	if part_body is PackedByteArray:
		if part_body.is_empty():
			errors.append("part_body must not be empty")
		return part_body
	errors.append("part_body must be raw bytes")
	return PackedByteArray()

func _normalize_collection_delete_fields(fields: Dictionary) -> Dictionary:
	var body := {}
	var errors: Array = []
	_validate_allowed_fields(fields, ["permanent", "reason"], errors, "delete collection")
	_append_optional_boolean_field(fields, body, "permanent", errors)
	_append_validated_string_field(fields, body, "reason", 1000, errors, false)
	return {"body": body, "errors": errors}

func _normalize_delete_collection_mods_fields(fields: Dictionary) -> Dictionary:
	var body := {}
	var errors: Array = []
	_validate_allowed_fields(fields, ["mod_ids"], errors, "delete collection mods")
	_append_required_positive_int_array_field(fields, body, "mod_ids", errors)
	return {"body": body, "errors": errors}

func _normalize_mod_tags_write_fields(mod_id: String, fields: Dictionary) -> Dictionary:
	var body := {}
	var errors: Array = []
	_append_required_positive_id_error(mod_id, "mod_id", errors)
	_validate_allowed_fields(fields, ["tags"], errors, "mod tags")
	_append_required_string_array_field(fields, body, "tags", errors)
	return {"body": body, "errors": errors}

func _normalize_mod_metadata_kvp_write_fields(mod_id: String, fields: Dictionary) -> Dictionary:
	var body := {}
	var errors: Array = []
	_append_required_positive_id_error(mod_id, "mod_id", errors)
	_validate_allowed_fields(fields, ["metadata"], errors, "mod metadata")
	_append_required_string_array_field(fields, body, "metadata", errors)
	return {"body": body, "errors": errors}

func _normalize_mod_dependencies_write_fields(mod_id: String, fields: Dictionary, allow_sync: bool) -> Dictionary:
	var body := {}
	var errors: Array = []
	var allowed_fields := ["dependencies"]
	if allow_sync:
		allowed_fields.append("sync")
	_append_required_positive_id_error(mod_id, "mod_id", errors)
	_validate_allowed_fields(fields, allowed_fields, errors, "mod dependencies")
	_append_optional_int_array_field(fields, body, "dependencies", errors)
	if allow_sync:
		_append_optional_boolean_field(fields, body, "sync", errors)
	return {"body": body, "errors": errors}

func _normalize_add_mod_media_fields(fields: Dictionary) -> Dictionary:
	var body := {}
	var errors: Array = []
	_validate_allowed_fields(fields, ["images", "sync", "youtube", "sketchfab"], errors, "mod media")
	_append_mod_media_images_field(fields, body, errors)
	_append_optional_boolean_field(fields, body, "sync", errors)
	_append_optional_url_array_field(fields, body, "youtube", errors)
	_append_optional_url_array_field(fields, body, "sketchfab", errors)
	return {"body": body, "errors": errors}

func _normalize_add_game_media_fields(fields: Dictionary) -> Dictionary:
	var body := {}
	var errors: Array = []
	_validate_allowed_fields(fields, ["logo", "icon", "header", "redirect_uris"], errors, "game media")
	_append_raw_multipart_field(fields, body, "logo", errors, false)
	_append_raw_multipart_field(fields, body, "icon", errors, false)
	_append_raw_multipart_field(fields, body, "header", errors, false)
	_append_optional_url_array_field(fields, body, "redirect_uris", errors)
	return {"body": body, "errors": errors}

func _normalize_reorder_or_delete_mod_media_fields(fields: Dictionary, label: String) -> Dictionary:
	var body := {}
	var errors: Array = []
	_validate_allowed_fields(fields, ["images", "youtube", "sketchfab"], errors, label)
	_append_optional_string_array_field(fields, body, "images", errors)
	_append_optional_url_array_field(fields, body, "youtube", errors)
	_append_optional_url_array_field(fields, body, "sketchfab", errors)
	return {"body": body, "errors": errors}

func _validate_allowed_fields(fields: Dictionary, allowed_fields: Array, errors: Array, label: String) -> void:
	for key in fields.keys():
		if not allowed_fields.has(str(key)):
			errors.append("%s field '%s' is not documented" % [label.capitalize(), str(key)])

func _append_validated_string_field(fields: Dictionary, body: Dictionary, field_name: String, max_length: int, errors: Array, required: bool, min_length: int = 0) -> void:
	if not fields.has(field_name):
		if required:
			errors.append("%s is required" % field_name)
		return
	var value = fields[field_name]
	if value == null:
		errors.append("%s must be a string" % field_name)
		return
	var sanitized := str(value).strip_edges()
	if required and sanitized.is_empty():
		errors.append("%s is required" % field_name)
		return
	if min_length > 0 and sanitized.length() < min_length:
		errors.append("%s must be at least %d characters" % [field_name, min_length])
	if max_length > 0 and sanitized.length() > max_length:
		errors.append("%s must be at most %d characters" % [field_name, max_length])
	body[field_name] = sanitized

func _append_validated_url_field(fields: Dictionary, body: Dictionary, field_name: String, errors: Array) -> void:
	if not fields.has(field_name):
		return
	var value = fields[field_name]
	if value == null:
		errors.append("%s must be a valid URL string" % field_name)
		return
	var sanitized := str(value).strip_edges()
	if sanitized.is_empty() or not (sanitized.begins_with("http://") or sanitized.begins_with("https://")):
		errors.append("%s must be a valid URL string" % field_name)
		return
	body[field_name] = sanitized

func _append_raw_multipart_field(fields: Dictionary, body: Dictionary, field_name: String, errors: Array, required: bool) -> void:
	if not fields.has(field_name):
		if required:
			errors.append("%s is required" % field_name)
		return
	var normalized = _normalize_raw_multipart_value(fields[field_name], field_name, errors)
	if normalized == null:
		return
	body[field_name] = normalized

func _normalize_raw_multipart_value(value: Variant, field_name: String, errors: Array):
	if value == null:
		errors.append("%s must be a non-empty raw multipart value" % field_name)
		return null
	if value is String:
		var sanitized := str(value).strip_edges()
		if sanitized.is_empty():
			errors.append("%s must be a non-empty raw multipart value" % field_name)
			return null
		return sanitized
	if value is Dictionary:
		for key in value.keys():
			if not ["filename", "content_type", "data"].has(str(key)):
				errors.append("%s multipart file part field '%s' is not documented" % [field_name, str(key)])
		var filename := str(value.get("filename", "")).strip_edges()
		if filename.is_empty():
			errors.append("%s multipart file part filename must be a non-empty string" % field_name)
		var content_type := str(value.get("content_type", "")).strip_edges()
		if value.has("content_type") and content_type.is_empty():
			errors.append("%s multipart file part content_type must be a non-empty string" % field_name)
		var data = value.get("data", null)
		if not (data is PackedByteArray):
			errors.append("%s multipart file part data must be raw bytes" % field_name)
			return null
		if data.is_empty():
			errors.append("%s multipart file part data must not be empty" % field_name)
			return null
		if filename.is_empty():
			return null
		return {
			"filename": filename,
			"content_type": content_type,
			"data": data
		}
	return value

func _append_required_non_empty_string_field(fields: Dictionary, body: Dictionary, field_name: String, errors: Array, required: bool) -> void:
	if not fields.has(field_name):
		if required:
			errors.append("%s is required" % field_name)
		return
	var value = fields[field_name]
	if value == null:
		errors.append("%s must be a non-empty string" % field_name)
		return
	var sanitized := str(value).strip_edges()
	if sanitized.is_empty():
		errors.append("%s must be a non-empty string" % field_name)
		return
	body[field_name] = sanitized

func _append_optional_string_field(fields: Dictionary, body: Dictionary, field_name: String, errors: Array) -> void:
	if not fields.has(field_name):
		return
	var value = fields[field_name]
	if value == null:
		errors.append("%s must be a string" % field_name)
		return
	body[field_name] = str(value).strip_edges()

func _append_optional_non_empty_string_field(fields: Dictionary, body: Dictionary, field_name: String, errors: Array, allow_empty: bool = false) -> void:
	if not fields.has(field_name):
		return
	var value = fields[field_name]
	if value == null:
		errors.append("%s must be a non-empty string" % field_name)
		return
	var sanitized := str(value).strip_edges()
	if sanitized.is_empty() and not allow_empty:
		errors.append("%s must be a non-empty string" % field_name)
		return
	body[field_name] = sanitized

func _append_optional_enum_int_field(fields: Dictionary, body: Dictionary, field_name: String, allowed_values: Array, errors: Array) -> void:
	if not fields.has(field_name):
		return
	var parsed = _parse_int_like(fields[field_name])
	if parsed == null:
		errors.append("%s must be an integer" % field_name)
		return
	if not allowed_values.has(parsed):
		errors.append("%s must be one of %s" % [field_name, str(allowed_values)])
		return
	body[field_name] = parsed

func _append_optional_non_negative_int_field(fields: Dictionary, body: Dictionary, field_name: String, errors: Array) -> void:
	if not fields.has(field_name):
		return
	var parsed = _parse_int_like(fields[field_name])
	if parsed == null:
		errors.append("%s must be an integer" % field_name)
		return
	if parsed < 0:
		errors.append("%s must be greater than or equal to 0" % field_name)
		return
	body[field_name] = parsed

func _append_optional_int_like_field(fields: Dictionary, body: Dictionary, field_name: String, errors: Array) -> void:
	if not fields.has(field_name):
		return
	var parsed = _parse_int_like(fields[field_name])
	if parsed == null:
		errors.append("%s must be an integer" % field_name)
		return
	body[field_name] = parsed

func _append_optional_boolean_field(fields: Dictionary, body: Dictionary, field_name: String, errors: Array) -> void:
	if not fields.has(field_name):
		return
	var value = fields[field_name]
	if value is bool:
		body[field_name] = value
		return
	if value is int and int(value) in [0, 1]:
		body[field_name] = int(value) == 1
		return
	if value is String:
		var normalized := str(value).strip_edges().to_lower()
		if normalized in ["true", "1"]:
			body[field_name] = true
			return
		if normalized in ["false", "0"]:
			body[field_name] = false
			return
	errors.append("%s must be a boolean" % field_name)

func _append_optional_query_string_or_array(fields: Dictionary, query: Dictionary, field_name: String, allowed_values: Array, errors: Array) -> void:
	if not fields.has(field_name):
		return
	var value = fields[field_name]
	if value is Array:
		if value.is_empty():
			errors.append("%s must not be empty" % field_name)
			return
		var normalized: Array = []
		for item in value:
			var sanitized := str(item).strip_edges().to_upper()
			if sanitized.is_empty():
				errors.append("%s must contain only non-empty strings" % field_name)
				return
			if not allowed_values.has(sanitized):
				errors.append("%s contains undocumented value '%s'" % [field_name, sanitized])
			normalized.append(sanitized)
		query[field_name] = normalized
		return
	var sanitized := str(value).strip_edges().to_upper()
	if sanitized.is_empty():
		errors.append("%s must be a non-empty string or array" % field_name)
		return
	if not allowed_values.has(sanitized):
		errors.append("%s must be one of %s" % [field_name, str(allowed_values)])
		return
	query[field_name] = sanitized

func _append_guide_tags_field(fields: Dictionary, body: Dictionary, errors: Array, required: bool) -> void:
	if not fields.has("tags"):
		if required:
			errors.append("tags is required")
		return
	var normalized_tags = _normalize_string_array_field(fields["tags"], "tags", errors, 30, 7, true)
	if normalized_tags == null:
		return
	if required and normalized_tags.is_empty():
		errors.append("tags must contain at least one tag")
	body["tags"] = normalized_tags

func _append_collection_tags_field(fields: Dictionary, body: Dictionary, errors: Array) -> void:
	if not fields.has("tags"):
		return
	var normalized_tags = _normalize_string_array_field(fields["tags"], "tags", errors, 64, -1, false)
	if normalized_tags == null:
		return
	for tag in normalized_tags:
		if not COLLECTION_TAG_VALUES.has(tag):
			errors.append("tags contains undocumented collection tag '%s'" % tag)
	body["tags"] = normalized_tags

func _append_required_string_array_field(fields: Dictionary, body: Dictionary, field_name: String, errors: Array) -> void:
	if not fields.has(field_name):
		errors.append("%s is required" % field_name)
		return
	var normalized = _normalize_string_array_field(fields[field_name], field_name, errors, -1, -1, false)
	if normalized == null:
		return
	body[field_name] = normalized

func _append_optional_string_array_field(fields: Dictionary, body: Dictionary, field_name: String, errors: Array) -> void:
	if not fields.has(field_name):
		return
	var normalized = _normalize_string_array_field(fields[field_name], field_name, errors, -1, -1, false)
	if normalized == null:
		return
	body[field_name] = normalized

func _append_optional_url_array_field(fields: Dictionary, body: Dictionary, field_name: String, errors: Array) -> void:
	if not fields.has(field_name):
		return
	var normalized = _normalize_string_array_field(fields[field_name], field_name, errors, -1, -1, false)
	if normalized == null:
		return
	for item in normalized:
		if not (item.begins_with("http://") or item.begins_with("https://")):
			errors.append("%s must contain only valid URL strings" % field_name)
			return
	body[field_name] = normalized

func _append_optional_int_array_field(fields: Dictionary, body: Dictionary, field_name: String, errors: Array) -> void:
	if not fields.has(field_name):
		return
	_append_int_array_field(fields, body, field_name, errors)

func _append_required_positive_int_array_field(fields: Dictionary, body: Dictionary, field_name: String, errors: Array) -> void:
	if not fields.has(field_name):
		errors.append("%s is required" % field_name)
		return
	var value = fields[field_name]
	if not (value is Array):
		errors.append("%s must be an array of positive integers" % field_name)
		return
	if value.is_empty():
		errors.append("%s must contain at least one positive integer" % field_name)
		return
	var normalized: Array = []
	for item in value:
		var parsed = _parse_int_like(item)
		if parsed == null or int(parsed) <= 0:
			errors.append("%s must contain only positive integers" % field_name)
			return
		normalized.append(int(parsed))
	body[field_name] = normalized

func _append_int_array_field(fields: Dictionary, body: Dictionary, field_name: String, errors: Array) -> void:
	if not fields.has(field_name):
		return
	var value = fields[field_name]
	if not (value is Array):
		errors.append("%s must be an array of integers" % field_name)
		return
	var normalized: Array = []
	for item in value:
		var parsed = _parse_int_like(item)
		if parsed == null:
			errors.append("%s must contain only integers" % field_name)
			return
		normalized.append(parsed)
	body[field_name] = normalized

func _append_modfile_platforms_field(fields: Dictionary, body: Dictionary, errors: Array) -> void:
	if not fields.has("platforms"):
		return
	var normalized: Variant = _normalize_documented_platform_array(fields["platforms"], "platforms", errors)
	if normalized == null:
		return
	body["platforms"] = normalized

func _append_mod_media_images_field(fields: Dictionary, body: Dictionary, errors: Array) -> void:
	if not fields.has("images"):
		return
	var images = fields["images"]
	if not (images is Dictionary):
		errors.append("images must be an object mapping multipart field names to raw multipart values")
		return
	for raw_field_name in images.keys():
		var field_name := str(raw_field_name).strip_edges()
		if field_name.is_empty():
			errors.append("images field names must be non-empty strings")
			continue
		var normalized = _normalize_raw_multipart_value(images[raw_field_name], field_name, errors)
		if normalized == null:
			continue
		body[field_name] = normalized

func _append_platform_status_array_field(value: Variant, body: Dictionary, body_field_name: String, error_field_name: String, errors: Array) -> void:
	var normalized: Variant = _normalize_documented_platform_array(value, error_field_name, errors)
	if normalized == null:
		return
	body[body_field_name] = normalized

func _normalize_documented_platform_array(value: Variant, field_name: String, errors: Array):
	if not (value is Array):
		errors.append("%s must be an array of documented platform strings" % field_name)
		return null
	if value.is_empty():
		errors.append("%s must contain at least one documented platform string" % field_name)
		return null
	var normalized: Array = []
	for item in value:
		if item == null:
			errors.append("%s must contain only documented platform strings" % field_name)
			return null
		var platform := str(item).strip_edges()
		if platform.is_empty():
			errors.append("%s must contain only documented platform strings" % field_name)
			return null
		if not MODFILE_PLATFORM_VALUES.has(platform):
			errors.append("%s contains undocumented platform '%s'" % [field_name, platform])
		normalized.append(platform)
	return normalized

func _normalize_string_array_field(value: Variant, field_name: String, errors: Array, max_item_length: int, max_items: int, distinct_required: bool):
	if not (value is Array):
		errors.append("%s must be an array" % field_name)
		return null
	var normalized: Array = []
	var seen := {}
	for item in value:
		if item == null:
			errors.append("%s must contain only strings" % field_name)
			return null
		var sanitized := str(item).strip_edges()
		if sanitized.is_empty():
			errors.append("%s must not contain empty items" % field_name)
			return null
		if max_item_length > 0 and sanitized.length() > max_item_length:
			errors.append("%s items must be at most %d characters" % [field_name, max_item_length])
		if distinct_required and seen.has(sanitized):
			errors.append("%s must contain distinct values" % field_name)
		seen[sanitized] = true
		normalized.append(sanitized)
	if max_items > -1 and normalized.size() > max_items:
		errors.append("%s must contain at most %d items" % [field_name, max_items])
	return normalized

func _parse_int_like(value: Variant) -> Variant:
	if value is int:
		return int(value)
	if value is float and floor(value) == value:
		return int(value)
	var as_string := str(value).strip_edges()
	if as_string.is_empty() or not as_string.is_valid_int():
		return null
	return int(as_string)

func _append_required_positive_id_error(value: Variant, field_name: String, errors: Array) -> void:
	var parsed = _parse_int_like(value)
	if parsed == null or int(parsed) <= 0:
		errors.append("%s must be a positive integer path id" % field_name)

func _normalize_create_mod_monetization_team_fields(mod_id: String, fields: Dictionary) -> Dictionary:
	var errors: Array = []
	var body := {}
	var headers := _build_multipart_headers(true)
	_append_required_positive_id_error(mod_id, "mod_id", errors)
	_validate_allowed_fields(fields, ["users"], errors, "Create Mod Monetization Team")
	if not fields.has("users"):
		errors.append("users is required")
		return {"body": body, "headers": headers, "errors": errors}
	var users = fields["users"]
	if not (users is Array):
		errors.append("users must be an array")
		return {"body": body, "headers": headers, "errors": errors}
	if users.is_empty():
		errors.append("users must contain at least one user object")
		return {"body": body, "headers": headers, "errors": errors}
	if users.size() > 5:
		errors.append("users may contain at most 5 user objects")
	var total_split := 0
	var valid_split_count := 0
	for index in range(users.size()):
		var user = users[index]
		if not (user is Dictionary):
			errors.append("users[%d] must be an object" % index)
			continue
		for key in user.keys():
			if not ["id", "split"].has(str(key)):
				errors.append("Create Mod Monetization Team User field '%s' is not documented" % str(key))
		if not user.has("id"):
			errors.append("users[%d].id is required" % index)
		else:
			var user_id = _parse_int_like(user["id"])
			if user_id == null or int(user_id) <= 0:
				errors.append("users[%d].id must be a positive integer" % index)
			else:
				body["users[%d][id]" % index] = int(user_id)
		if not user.has("split"):
			errors.append("users[%d].split is required" % index)
		else:
			var split = _parse_int_like(user["split"])
			if split == null:
				errors.append("users[%d].split must be an integer" % index)
			else:
				body["users[%d][split]" % index] = int(split)
				total_split += int(split)
				valid_split_count += 1
	if valid_split_count == users.size() and total_split != 100:
		errors.append("users split values must total 100")
	return {"body": body, "headers": headers, "errors": errors}

func _normalize_user_entitlements_fields(fields: Dictionary, portal: String, platform: String) -> Dictionary:
	var errors: Array = []
	var body := {}
	var headers := _build_form_headers(true)
	var resolved_portal := portal.strip_edges().to_lower()
	if resolved_portal.is_empty():
		resolved_portal = _config.portal.to_lower()
	if resolved_portal.is_empty():
		errors.append("X-Modio-Portal is required")
	else:
		headers["X-Modio-Portal"] = resolved_portal

	var resolved_platform := platform.strip_edges()
	if resolved_platform.is_empty():
		resolved_platform = _config.platform.strip_edges()
	if resolved_platform.is_empty():
		headers.erase("X-Modio-Platform")
	else:
		headers["X-Modio-Platform"] = resolved_platform

	var allowed_fields := ["game_id", "psn_token", "psn_env", "psn_service_label", "xbox_token", "epicgames_token", "epicgames_sandbox_id"]
	_validate_allowed_fields(fields, allowed_fields, errors, "User Entitlement")

	var resolved_game_id := _resolve_requested_game_id(str(fields.get("game_id", "")))
	if resolved_game_id.is_empty():
		errors.append("game_id is required unless using a g-url host")
	else:
		body["game_id"] = resolved_game_id

	match resolved_portal:
		"psn":
			if resolved_platform.is_empty():
				errors.append("X-Modio-Platform is required when portal is psn")
			var psn_token := str(fields.get("psn_token", "")).strip_edges()
			if psn_token.is_empty():
				errors.append("psn_token is required when portal is psn")
			else:
				body["psn_token"] = psn_token
			if fields.has("psn_env"):
				var psn_env = _parse_int_like(fields["psn_env"])
				if psn_env == null:
					errors.append("psn_env must be an integer")
				else:
					body["psn_env"] = int(psn_env)
			if fields.has("psn_service_label"):
				var psn_service_label = _parse_int_like(fields["psn_service_label"])
				if psn_service_label == null:
					errors.append("psn_service_label must be an integer")
				else:
					body["psn_service_label"] = int(psn_service_label)
		"xboxlive":
			var xbox_token := str(fields.get("xbox_token", "")).strip_edges()
			if xbox_token.is_empty():
				errors.append("xbox_token is required when portal is xboxlive")
			else:
				body["xbox_token"] = xbox_token
		"epicgames":
			var epicgames_token := str(fields.get("epicgames_token", "")).strip_edges()
			if epicgames_token.is_empty():
				errors.append("epicgames_token is required when portal is epicgames")
			else:
				body["epicgames_token"] = epicgames_token
			var epicgames_sandbox_id := str(fields.get("epicgames_sandbox_id", "")).strip_edges()
			if epicgames_sandbox_id.is_empty():
				errors.append("epicgames_sandbox_id is required when portal is epicgames")
			else:
				body["epicgames_sandbox_id"] = epicgames_sandbox_id
		_:
			pass

	return {"body": body, "headers": headers, "errors": errors}

func _normalize_checkout_fields(mod_id: String, fields: Dictionary, portal: String, platform: String) -> Dictionary:
	var errors: Array = []
	var body := {}
	var headers := _build_form_headers(true)
	_append_required_positive_id_error(_config.game_id, "game_id", errors)
	_append_required_positive_id_error(mod_id, "mod_id", errors)
	var resolved_portal := portal.strip_edges().to_lower()
	if resolved_portal.is_empty():
		resolved_portal = _config.portal.to_lower()
	if not resolved_portal.is_empty():
		if not CHECKOUT_PORTAL_VALUES.has(resolved_portal):
			errors.append("X-Modio-Portal must be one of %s" % str(CHECKOUT_PORTAL_VALUES))
		else:
			headers["X-Modio-Portal"] = resolved_portal

	var resolved_platform := platform.strip_edges()
	if resolved_platform.is_empty():
		resolved_platform = _config.platform.strip_edges()
	if resolved_portal == "psn":
		if resolved_platform.is_empty():
			errors.append("X-Modio-Platform is required when portal is psn")
		else:
			headers["X-Modio-Platform"] = resolved_platform
	elif not resolved_platform.is_empty():
		headers["X-Modio-Platform"] = resolved_platform

	var allowed_fields := ["display_amount", "idempotent_key", "type", "subscribe", "psn_token", "psn_env", "psn_service_label", "xbox_token", "epicgames_token", "epicgames_sandbox_id", "payment_method_id", "terms_accepted", "refund_accepted", "transaction_id"]
	_validate_allowed_fields(fields, allowed_fields, errors, "Checkout")
	_append_required_non_empty_string_field(fields, body, "idempotent_key", errors, true)
	_append_optional_enum_int_field(fields, body, "type", CHECKOUT_TYPE_VALUES, errors)
	_append_optional_boolean_field(fields, body, "subscribe", errors)
	_append_optional_int_like_field(fields, body, "display_amount", errors)
	_append_optional_non_empty_string_field(fields, body, "psn_token", errors, false)
	_append_optional_int_like_field(fields, body, "psn_env", errors)
	_append_optional_int_like_field(fields, body, "psn_service_label", errors)
	_append_optional_non_empty_string_field(fields, body, "xbox_token", errors, false)
	_append_optional_non_empty_string_field(fields, body, "epicgames_token", errors, false)
	_append_optional_non_empty_string_field(fields, body, "epicgames_sandbox_id", errors, false)
	_append_optional_non_empty_string_field(fields, body, "payment_method_id", errors, false)
	_append_optional_boolean_field(fields, body, "terms_accepted", errors)
	_append_optional_boolean_field(fields, body, "refund_accepted", errors)
	_append_optional_int_like_field(fields, body, "transaction_id", errors)

	var checkout_type = _parse_int_like(fields.get("type", null))
	if checkout_type == null:
		errors.append("type is required")
	else:
		match int(checkout_type):
			0:
				if not body.has("display_amount"):
					errors.append("display_amount is required when type is 0")
			2, 3:
				if not body.has("payment_method_id"):
					errors.append("payment_method_id is required when type is %d" % int(checkout_type))
				if not body.has("terms_accepted"):
					errors.append("terms_accepted is required when type is %d" % int(checkout_type))
				if not body.has("refund_accepted"):
					errors.append("refund_accepted is required when type is %d" % int(checkout_type))
			4:
				if not body.has("transaction_id"):
					errors.append("transaction_id is required when type is 4")

	match resolved_portal:
		"psn":
			if not body.has("psn_token"):
				errors.append("psn_token is required when portal is psn")
		"xboxlive":
			if not body.has("xbox_token"):
				errors.append("xbox_token is required when portal is xboxlive")
		"epicgames":
			if not body.has("epicgames_token"):
				errors.append("epicgames_token is required when portal is epicgames")
			if not body.has("epicgames_sandbox_id"):
				errors.append("epicgames_sandbox_id is required when portal is epicgames")
		_:
			pass

	return {"body": body, "headers": headers, "errors": errors}

func _normalize_s2s_transaction_intent_fields(fields: Dictionary, delegation_token: String, idempotent_key: String) -> Dictionary:
	var errors: Array = []
	var body := {}
	var headers := _build_service_form_headers()
	if not _config.has_service_token():
		errors.append("service_token is required for S2S requests")
	var sanitized_delegation_token := delegation_token.strip_edges()
	if sanitized_delegation_token.is_empty():
		errors.append("X-Modio-Delegation-Token is required")
	else:
		headers["X-Modio-Delegation-Token"] = sanitized_delegation_token
	var sanitized_idempotent_key := idempotent_key.strip_edges()
	if not sanitized_idempotent_key.is_empty():
		headers["X-Modio-Idempotent-Key"] = sanitized_idempotent_key
	var allowed_fields := ["sku", "portal", "gateway_uuid"]
	_validate_allowed_fields(fields, allowed_fields, errors, "S2S transaction intent")
	_append_required_non_empty_string_field(fields, body, "sku", errors, true)
	_append_required_non_empty_string_field(fields, body, "portal", errors, true)
	_append_optional_non_empty_string_field(fields, body, "gateway_uuid", errors, false)
	return {"body": body, "headers": headers, "errors": errors}

func _normalize_s2s_transaction_commit_fields(fields: Dictionary, idempotent_key: String) -> Dictionary:
	var errors: Array = []
	var body := {}
	var headers := _build_service_form_headers()
	if not _config.has_service_token():
		errors.append("service_token is required for S2S requests")
	var sanitized_idempotent_key := idempotent_key.strip_edges()
	if not sanitized_idempotent_key.is_empty():
		headers["X-Modio-Idempotent-Key"] = sanitized_idempotent_key
	var allowed_fields := ["transaction_id", "clawback_uuid"]
	_validate_allowed_fields(fields, allowed_fields, errors, "S2S transaction commit")
	_append_optional_int_like_field(fields, body, "transaction_id", errors)
	_append_optional_non_empty_string_field(fields, body, "clawback_uuid", errors, false)
	if not body.has("transaction_id"):
		errors.append("transaction_id is required")
	return {"body": body, "headers": headers, "errors": errors}

func _normalize_s2s_transaction_clawback_fields(fields: Dictionary) -> Dictionary:
	var errors: Array = []
	var body := {}
	var headers := _build_service_form_headers()
	if not _config.has_service_token():
		errors.append("service_token is required for S2S requests")
	var allowed_fields := ["transaction_id", "gateway_uuid", "portal", "refund_reason", "clawback_uuid"]
	_validate_allowed_fields(fields, allowed_fields, errors, "S2S transaction clawback")
	_append_optional_int_like_field(fields, body, "transaction_id", errors)
	_append_optional_non_empty_string_field(fields, body, "gateway_uuid", errors, false)
	_append_required_non_empty_string_field(fields, body, "portal", errors, true)
	_append_required_non_empty_string_field(fields, body, "refund_reason", errors, true)
	_append_optional_non_empty_string_field(fields, body, "clawback_uuid", errors, false)
	if not body.has("transaction_id") and not body.has("gateway_uuid"):
		errors.append("transaction_id or gateway_uuid is required")
	if body.has("portal") and not CLAWBACK_PORTAL_VALUES.has(str(body.get("portal", "")).to_lower()):
		errors.append("portal must be one of %s" % str(CLAWBACK_PORTAL_VALUES))
	if body.has("portal"):
		body["portal"] = str(body["portal"]).to_lower()
	return {
		"body": body,
		"headers": headers,
		"errors": errors,
		"drift_notes": ["The refreshed REST page types gateway_uuid as an integer even though the description says it is an alpha-dash identifier; this adapter treats it as a string."]
	}

func _normalize_s2s_disconnect_path(portal_id: String) -> Dictionary:
	var errors: Array = []
	var headers := _build_service_read_headers()
	if not _config.has_service_token():
		errors.append("service_token is required for S2S requests")
	var sanitized_portal_id := portal_id.strip_edges()
	_append_required_positive_id_error(sanitized_portal_id, "portal_id", errors)
	return {"portal_id": sanitized_portal_id, "headers": headers, "errors": errors}

func _normalize_s2s_monetization_transactions_filters(filters: Dictionary, monetization_team_id: String) -> Dictionary:
	var errors: Array = []
	var query := {}
	var headers := _build_service_read_headers()
	if not _config.has_service_token():
		errors.append("service_token is required for S2S requests")
	var resolved_team_id := _resolve_monetization_team_id(monetization_team_id)
	if resolved_team_id.is_empty():
		errors.append("monetization_team_id is required")
	else:
		_append_required_positive_id_error(resolved_team_id, "monetization_team_id", errors)
	var allowed_fields := ["transaction_type", "monetization_type", "buyer", "clawback_uuid", "gateway_uuid", "line_items", "created_at_start"]
	_validate_allowed_fields(filters, allowed_fields, errors, "S2S monetization transactions")
	_append_optional_query_string_or_array(filters, query, "transaction_type", MONETIZATION_TRANSACTION_TYPE_VALUES, errors)
	_append_optional_query_string_or_array(filters, query, "monetization_type", MONETIZATION_TYPE_VALUES, errors)
	_append_optional_int_like_field(filters, query, "buyer", errors)
	_append_optional_non_empty_string_field(filters, query, "clawback_uuid", errors, false)
	_append_optional_non_empty_string_field(filters, query, "gateway_uuid", errors, false)
	_append_optional_non_empty_string_field(filters, query, "line_items", errors, false)
	_append_optional_int_like_field(filters, query, "created_at_start", errors)
	return {"monetization_team_id": resolved_team_id, "query": query, "headers": headers, "errors": errors}

func _normalize_s2s_monetization_transaction_path(transaction_id: String, monetization_team_id: String) -> Dictionary:
	var errors: Array = []
	var headers := _build_service_read_headers()
	if not _config.has_service_token():
		errors.append("service_token is required for S2S requests")
	var resolved_team_id := _resolve_monetization_team_id(monetization_team_id)
	if resolved_team_id.is_empty():
		errors.append("monetization_team_id is required")
	else:
		_append_required_positive_id_error(resolved_team_id, "monetization_team_id", errors)
	var sanitized_transaction_id := transaction_id.strip_edges()
	_append_required_positive_id_error(sanitized_transaction_id, "transaction_id", errors)
	return {"monetization_team_id": resolved_team_id, "transaction_id": sanitized_transaction_id, "headers": headers, "errors": errors}

func _build_public_query() -> Dictionary:
	var query := {}
	if not _config.api_key.is_empty():
		query["api_key"] = _config.api_key
	return query

func _build_authenticated_query() -> Dictionary:
	if _config.has_access_token():
		return {}
	return _build_public_query()

func _build_read_headers(requires_bearer: bool) -> Dictionary:
	var headers := _config.build_default_headers()
	if requires_bearer and _config.has_access_token():
		headers["Authorization"] = "Bearer %s" % _config.access_token
	return headers

func _build_service_read_headers() -> Dictionary:
	var headers := _config.build_default_headers()
	if _config.has_service_token():
		headers["Authorization"] = "Bearer %s" % _config.service_token
	return headers

func _build_form_headers(requires_bearer: bool) -> Dictionary:
	var headers := _build_read_headers(requires_bearer)
	headers["Content-Type"] = ModioHttpTransport.CONTENT_TYPE_FORM
	return headers

func _build_service_form_headers() -> Dictionary:
	var headers := _build_service_read_headers()
	headers["Content-Type"] = ModioHttpTransport.CONTENT_TYPE_FORM
	return headers

func _build_multipart_headers(requires_bearer: bool) -> Dictionary:
	return _build_read_headers(requires_bearer)

func _build_validated_request(method: String, path: String, query: Dictionary, body: Dictionary, headers: Dictionary, meta: Dictionary, validation_errors: Array) -> Dictionary:
	var effective_meta := meta.duplicate(true)
	if validation_errors.size() > 0:
		effective_meta["validation_errors"] = validation_errors
		effective_meta["validation_error"] = "Invalid mod.io request: %s" % "; ".join(PackedStringArray(validation_errors))
	return _transport.build_request(method, path, query, body, headers, effective_meta)

func _multipart_upload_status_label(status: int) -> String:
	match status:
		0:
			return "incomplete"
		1:
			return "pending"
		2:
			return "processing"
		3:
			return "complete"
		4:
			return "cancelled"
		_:
			return "unknown"

func _resolve_read_auth_mode(requires_bearer: bool) -> String:
	if requires_bearer:
		return "bearer"
	return "api_key_query"

func _resolve_monetization_team_id(monetization_team_id: String = "") -> String:
	var explicit_team_id := monetization_team_id.strip_edges()
	if not explicit_team_id.is_empty():
		return explicit_team_id
	return _config.monetization_team_id.strip_edges()

func _sanitize_requested_expiry(requested_expiry: int, max_lifetime_seconds: int) -> int:
	if requested_expiry <= 0:
		return 0
	var now := Time.get_unix_time_from_system()
	if requested_expiry <= now:
		return 0
	var max_expiry := now + max_lifetime_seconds
	return mini(requested_expiry, max_expiry)

func _build_artifact_record_from_mod_object(mod_payload: Dictionary, game_payload: Dictionary, source: Dictionary, dependency_block: Dictionary) -> Dictionary:
	var modfile_payload: Dictionary = mod_payload.get("modfile", {})
	var game_id: String = _resolve_game_id(game_payload, mod_payload)
	var mod_id: String = _stringify_id_value(mod_payload.get("id", 0))
	return _build_artifact_record(game_id, mod_id, modfile_payload, game_payload, source, dependency_block)

func _build_artifact_record(game_id: String, mod_id: String, modfile_payload: Dictionary, game_payload: Dictionary, source: Dictionary, dependency_block: Dictionary) -> Dictionary:
	var resolved_at := Time.get_unix_time_from_system()
	var file_id := _stringify_id_value(modfile_payload.get("id", 0))
	var binary_url := str(modfile_payload.get("download", {}).get("binary_url", "")).strip_edges()
	var date_expires := int(modfile_payload.get("download", {}).get("date_expires", 0))
	var md5 := str(modfile_payload.get("filehash", {}).get("md5", "")).strip_edges()
	var artifact_key := build_artifact_key(game_id, mod_id, file_id)
	var game_policy := interpret_game_download_policy(game_payload)
	var error_issues: Array = []
	var warning_issues: Array = []
	if game_id.is_empty():
		error_issues.append("missing game_id")
	if mod_id.is_empty():
		error_issues.append("missing mod_id")
	if file_id.is_empty():
		error_issues.append("missing modfile.id")
	if binary_url.is_empty():
		warning_issues.append("missing download.binary_url")
	if md5.is_empty():
		warning_issues.append("missing filehash.md5")
	var is_expired: bool = date_expires > 0 and date_expires <= resolved_at
	var requires_fresh_resolution: bool = binary_url.is_empty() or is_expired
	var is_delivery_url_expiring: bool = date_expires > 0 or bool(game_policy.get("delivery_urls_require_api_resolution", false))
	var has_identity: bool = error_issues.is_empty()
	var has_integrity: bool = not md5.is_empty()
	var has_delivery: bool = not binary_url.is_empty()
	return {
		"provider": PROVIDER_NAME,
		"game_id": game_id,
		"mod_id": mod_id,
		"file_id": file_id,
		"artifact_key": artifact_key,
		"cache_key": artifact_key,
		"identity": {
			"provider": PROVIDER_NAME,
			"game_id": game_id,
			"mod_id": mod_id,
			"file_id": file_id,
			"canonical_id": artifact_key
		},
		"integrity": {
			"md5": md5,
			"filename": str(modfile_payload.get("filename", "")),
			"version": str(modfile_payload.get("version", "")),
			"filesize": int(modfile_payload.get("filesize", 0)),
			"filesize_uncompressed": int(modfile_payload.get("filesize_uncompressed", 0)),
			"metadata_blob": str(modfile_payload.get("metadata_blob", "")),
			"virus_status": int(modfile_payload.get("virus_status", 0)),
			"virus_positive": int(modfile_payload.get("virus_positive", 0)),
			"virustotal_hash": str(modfile_payload.get("virustotal_hash", "")),
			"platforms": _normalize_file_platforms(modfile_payload.get("platforms", []))
		},
		"delivery": {
			"binary_url": binary_url,
			"date_expires": date_expires,
			"resolved_at": resolved_at,
			"has_binary_url": has_delivery,
			"is_delivery_url_expiring": is_delivery_url_expiring,
			"is_delivery_url_expired": is_expired,
			"requires_fresh_resolution": requires_fresh_resolution,
			"is_canonical_url": false,
			"is_transient_transport": true
		},
		"dependency": dependency_block,
		"game_policy": game_policy,
		"source": source,
		"validity": {
			"has_identity": has_identity,
			"has_integrity": has_integrity,
			"has_delivery": has_delivery,
			"is_cacheable": has_identity and has_integrity and has_delivery,
			"is_partial": not (has_identity and has_integrity and has_delivery),
			"issues": {
				"errors": error_issues,
				"warnings": warning_issues
			}
		}
	}

func build_artifact_key(game_id: String, mod_id: String, file_id: String) -> String:
	if game_id.strip_edges().is_empty() or mod_id.strip_edges().is_empty() or file_id.strip_edges().is_empty():
		return ""
	return "%s:%s:%s:%s" % [PROVIDER_NAME, game_id.strip_edges(), mod_id.strip_edges(), file_id.strip_edges()]

func _resolve_requested_game_id(game_id: String = "") -> String:
	var requested := game_id.strip_edges()
	if not requested.is_empty():
		return requested
	return _config.game_id.strip_edges()

func _resolve_game_id(game_payload: Dictionary, fallback_payload: Dictionary = {}) -> String:
	var from_game := _stringify_id_value(game_payload.get("id", 0))
	if not from_game.is_empty():
		return from_game
	var from_payload := _stringify_id_value(fallback_payload.get("game_id", 0))
	if not from_payload.is_empty():
		return from_payload
	return _config.game_id.strip_edges()

func _stringify_id_value(value: Variant) -> String:
	if value is int or value is float:
		var numeric_value := int(value)
		return "" if numeric_value <= 0 else str(numeric_value)
	var text := str(value).strip_edges()
	if text == "" or text == "0" or text == "0.0":
		return ""
	return text

func _build_dependency_block(policy: String, is_dependency: bool, parent_mod_id: String, dependency_depth: int, recursive_requested: bool) -> Dictionary:
	return {
		"policy": policy,
		"is_dependency": is_dependency,
		"parent_mod_id": parent_mod_id,
		"dependency_depth": dependency_depth,
		"recursive_requested": recursive_requested,
		"documented_recursive_depth_limit": DOCUMENTED_RECURSIVE_DEPENDENCY_DEPTH if recursive_requested else 0
	}

func _dependency_option_to_string(value: int) -> String:
	match value:
		DEPENDENCY_OPTION_ALLOW_OPT_IN:
			return "allow_opt_in"
		DEPENDENCY_OPTION_ALLOW_OPT_OUT:
			return "allow_opt_out"
		DEPENDENCY_OPTION_ALLOW_ALL:
			return "allow_all"
		_:
			return "disallow"
