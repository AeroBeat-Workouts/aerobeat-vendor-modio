class_name ModioClientConfig
extends RefCounted

const DEFAULT_BASE_URL := "https://api.mod.io/v1"
const DEFAULT_ACCEPT_LANGUAGE := "en-US"

var game_id: String
var api_key: String
var access_token: String
var base_url: String
var accept_language: String
var portal: String
var platform: String

func _init(
	p_game_id: String = "",
	p_api_key: String = "",
	p_base_url: String = DEFAULT_BASE_URL,
	p_access_token: String = "",
	p_accept_language: String = DEFAULT_ACCEPT_LANGUAGE,
	p_portal: String = "",
	p_platform: String = ""
) -> void:
	game_id = p_game_id.strip_edges()
	api_key = p_api_key.strip_edges()
	base_url = p_base_url.strip_edges()
	access_token = p_access_token.strip_edges()
	accept_language = p_accept_language.strip_edges()
	portal = p_portal.strip_edges()
	platform = p_platform.strip_edges()

func has_public_credentials() -> bool:
	return not game_id.is_empty() and not api_key.is_empty()

func has_access_token() -> bool:
	return not access_token.is_empty()

func resolve_base_url() -> String:
	if not base_url.is_empty():
		return base_url
	if game_id.is_empty():
		return DEFAULT_BASE_URL
	return "https://g-%s.modapi.io/v1" % game_id

func build_default_headers() -> Dictionary:
	var headers := {}
	if not accept_language.is_empty():
		headers["Accept-Language"] = accept_language
	if not portal.is_empty():
		headers["X-Modio-Portal"] = portal
	if not platform.is_empty():
		headers["X-Modio-Platform"] = platform
	return headers
