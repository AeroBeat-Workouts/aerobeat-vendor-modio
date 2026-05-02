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

func build_auth_exchange_request(oauth_code: String, redirect_uri: String) -> Dictionary:
	return _transport.build_request(
		"POST",
		"/oauth/emailexchange",
		{},
		{
			"security_code": oauth_code.strip_edges(),
			"redirect_uri": redirect_uri.strip_edges(),
			"api_key": _config.api_key
		}
	)

func build_listing_request(query: ModioListingQuery = ModioListingQuery.new()) -> Dictionary:
	return _transport.build_request(
		"GET",
		"/games/%s/mods" % _config.game_id,
		query.to_query_dict(),
		{},
		_build_auth_headers()
	)

func build_download_request(request: ModioDownloadRequest) -> Dictionary:
	assert(request != null)
	assert(request.is_valid())

	return _transport.build_request(
		"GET",
		"/games/%s/mods/%s/files/%s/download" % [_config.game_id, request.mod_id, request.file_id],
		{},
		{},
		_build_auth_headers()
	)

func _build_auth_headers() -> Dictionary:
	var headers := {}
	if not _config.api_key.is_empty():
		headers["X-Modio-Api-Key"] = _config.api_key
	return headers
