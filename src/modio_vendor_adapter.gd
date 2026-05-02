class_name ModioVendorAdapter
extends RefCounted

const ModioClientConfig = preload("res://src/models/modio_client_config.gd")
const ModioListingQuery = preload("res://src/models/modio_listing_query.gd")
const ModioDownloadRequest = preload("res://src/models/modio_download_request.gd")
const ModioHttpTransport = preload("res://src/network/modio_http_transport.gd")

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
	if date_expires > 0:
		body["date_expires"] = date_expires
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
	if not email.strip_edges().is_empty():
		body["email"] = email.strip_edges()
	if date_expires > 0:
		body["date_expires"] = date_expires
	if monetization_account:
		body["monetization_account"] = true
	if not psn_token.strip_edges().is_empty():
		body["psn_token"] = psn_token.strip_edges()
		if psn_env >= 0:
			body["psn_env"] = psn_env
	return _transport.build_request(
		"POST",
		"/external/openidauth",
		{},
		body,
		_build_form_headers(false),
		{"content_type": ModioHttpTransport.CONTENT_TYPE_FORM, "auth_mode": "api_key_query"}
	)

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

func build_listing_request(query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_public_query()
	full_query.merge(query.to_query_dict(), true)
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

func build_modfiles_request(mod_id: String, query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_public_query()
	full_query.merge(query.to_query_dict(), true)
	return _transport.build_request(
		"GET",
		"/games/%s/mods/%s/files" % [_config.game_id, mod_id.strip_edges()],
		full_query,
		{},
		_build_read_headers(false),
		{"auth_mode": _resolve_read_auth_mode(false)}
	)

func build_user_subscriptions_request(query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	var full_query := _build_authenticated_query()
	full_query.merge(query.to_query_dict(), true)
	return _transport.build_request(
		"GET",
		"/me/subscribed",
		full_query,
		{},
		_build_read_headers(true),
		{"auth_mode": _resolve_read_auth_mode(true)}
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
	return {
		"access_token": str(payload.get("access_token", "")),
		"date_expires": int(payload.get("date_expires", 0)),
		"token_type": "Bearer"
	}

func normalize_terms_response(payload: Dictionary) -> Dictionary:
	return {
		"plaintext": str(payload.get("plaintext", "")),
		"html": str(payload.get("html", "")),
		"buttons": payload.get("buttons", {}),
		"links": payload.get("links", {})
	}

func normalize_agreement_response(payload: Dictionary) -> Dictionary:
	return {
		"id": int(payload.get("id", 0)),
		"is_active": bool(payload.get("is_active", false)),
		"is_latest": bool(payload.get("is_latest", false)),
		"type": int(payload.get("type", 0)),
		"user": payload.get("user", {}),
		"date_added": int(payload.get("date_added", 0)),
		"date_updated": int(payload.get("date_updated", 0)),
		"date_live": int(payload.get("date_live", 0)),
		"name": str(payload.get("name", "")),
		"changelog": str(payload.get("changelog", "")),
		"description": str(payload.get("description", "")),
		"adjacent_versions": payload.get("adjacent_versions", {})
	}

func normalize_authenticated_user_response(payload: Dictionary) -> Dictionary:
	return {
		"id": int(payload.get("id", 0)),
		"name_id": str(payload.get("name_id", "")),
		"username": str(payload.get("username", "")),
		"display_name_portal": payload.get("display_name_portal", null),
		"profile_url": str(payload.get("profile_url", "")),
		"status": int(payload.get("status", 0)),
		"avatar": payload.get("avatar", {})
	}

func normalize_game_response(payload: Dictionary) -> Dictionary:
	return {
		"id": int(payload.get("id", 0)),
		"name": str(payload.get("name", "")),
		"name_id": str(payload.get("name_id", "")),
		"api_access_options": int(payload.get("api_access_options", 0)),
		"submission_option": int(payload.get("submission_option", 0)),
		"tag_options": payload.get("tag_options", []),
		"platforms": payload.get("platforms", [])
	}

func normalize_mod_list_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_mod_object"))

func normalize_mod_detail_response(payload: Dictionary) -> Dictionary:
	return _normalize_mod_object(payload)

func normalize_modfiles_response(payload: Dictionary) -> Dictionary:
	return _normalize_list_payload(payload, Callable(self, "_normalize_modfile_object"))

func normalize_subscriptions_response(payload: Dictionary) -> Dictionary:
	return normalize_mod_list_response(payload)

func normalize_subscription_write_response(status_code: int, headers: Dictionary, payload: Dictionary) -> Dictionary:
	var response := _transport.normalize_response(status_code, headers, payload)
	if not response.ok:
		return response
	response["data"] = _normalize_mod_object(payload)
	response["already_subscribed"] = status_code == 200
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
		str(int(modfile_payload.get("id", 0))),
		str(download.get("binary_url", "")),
		int(download.get("date_expires", 0)),
		str(filehash.get("md5", "")),
		str(modfile_payload.get("filename", ""))
	)

func normalize_transport_response(status_code: int, headers: Dictionary = {}, payload: Variant = null) -> Dictionary:
	return _transport.normalize_response(status_code, headers, payload)

func _normalize_list_payload(payload: Dictionary, item_normalizer: Callable) -> Dictionary:
	var normalized_items: Array = []
	for item in payload.get("data", []):
		normalized_items.append(item_normalizer.call(item))
	return {
		"data": normalized_items,
		"result_count": int(payload.get("result_count", normalized_items.size())),
		"result_offset": int(payload.get("result_offset", 0)),
		"result_limit": int(payload.get("result_limit", normalized_items.size())),
		"result_total": int(payload.get("result_total", normalized_items.size()))
	}

func _normalize_mod_object(payload: Dictionary) -> Dictionary:
	var normalized_modfile := {}
	if payload.get("modfile", null) is Dictionary:
		normalized_modfile = _normalize_modfile_object(payload.modfile)
	return {
		"id": int(payload.get("id", 0)),
		"game_id": int(payload.get("game_id", 0)),
		"name": str(payload.get("name", "")),
		"name_id": str(payload.get("name_id", "")),
		"profile_url": str(payload.get("profile_url", "")),
		"summary": str(payload.get("summary", "")),
		"description": str(payload.get("description", "")),
		"description_plaintext": str(payload.get("description_plaintext", "")),
		"submitted_by": payload.get("submitted_by", {}),
		"status": int(payload.get("status", 0)),
		"visible": int(payload.get("visible", 0)),
		"date_added": int(payload.get("date_added", 0)),
		"date_updated": int(payload.get("date_updated", 0)),
		"date_live": int(payload.get("date_live", 0)),
		"metadata_blob": str(payload.get("metadata_blob", "")),
		"metadata_kvp": payload.get("metadata_kvp", []),
		"tags": payload.get("tags", []),
		"platforms": payload.get("platforms", []),
		"stats": _normalize_stats_object(payload.get("stats", {})),
		"modfile": normalized_modfile
	}

func _normalize_stats_object(payload: Dictionary) -> Dictionary:
	return {
		"mod_id": int(payload.get("mod_id", 0)),
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
		"filesize": int(payload.get("filesize", 0)),
		"filesize_uncompressed": int(payload.get("filesize_uncompressed", 0)),
		"filehash": payload.get("filehash", {}),
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
		"platforms": payload.get("platforms", [])
	}

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
	elif not requires_bearer and _config.has_access_token():
		headers["Authorization"] = "Bearer %s" % _config.access_token
	return headers

func _build_form_headers(requires_bearer: bool) -> Dictionary:
	var headers := _build_read_headers(requires_bearer)
	headers["Content-Type"] = ModioHttpTransport.CONTENT_TYPE_FORM
	return headers

func _resolve_read_auth_mode(requires_bearer: bool) -> String:
	if _config.has_access_token():
		return "bearer"
	if requires_bearer:
		return "api_key_fallback"
	return "api_key_query"
