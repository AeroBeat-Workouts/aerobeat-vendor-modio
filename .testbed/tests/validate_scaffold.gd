extends SceneTree

func _initialize() -> void:
	var failures: PackedStringArray = []
	var required_files := [
		"res://src/modio_vendor_adapter.gd",
		"res://src/models/modio_client_config.gd",
		"res://src/models/modio_listing_query.gd",
		"res://src/models/modio_download_request.gd",
		"res://src/network/modio_http_transport.gd"
	]

	for path in required_files:
		if not FileAccess.file_exists(path):
			failures.append("Missing required scaffold file: %s" % path)

	var config_script := load("res://src/models/modio_client_config.gd")
	var query_script := load("res://src/models/modio_listing_query.gd")
	var download_script := load("res://src/models/modio_download_request.gd")
	var transport_script := load("res://src/network/modio_http_transport.gd")
	var adapter_script := load("res://src/modio_vendor_adapter.gd")

	if config_script == null or query_script == null or download_script == null or transport_script == null or adapter_script == null:
		failures.append("One or more scripts failed to load.")
	else:
		var config = config_script.new("demo-game", "demo-key", config_script.DEFAULT_BASE_URL, "user-token", "en-US", "steam", "WINDOWS")
		var transport = transport_script.new()
		var adapter = adapter_script.new(config, transport)
		var auth_request: Dictionary = adapter.build_auth_exchange_request("demo-code", 1777777777)
		var listing_request: Dictionary = adapter.build_listing_request(query_script.new("boxing"))
		var modfiles_response: Dictionary = adapter.normalize_modfiles_response({
			"data": [
				{
					"id": 5678,
					"mod_id": 1234,
					"filename": "demo.zip",
					"filehash": {"md5": "demo-md5"},
					"download": {
						"binary_url": "https://api.mod.io/v1/games/1/mods/1234/files/5678/download/hash",
						"date_expires": 1777777777
					}
				}
			],
			"result_count": 1,
			"result_offset": 0,
			"result_limit": 100,
			"result_total": 1
		})
		var download_request: Dictionary = adapter.build_download_request(
			adapter.resolve_download_request_from_modfile("1234", modfiles_response.data[0])
		)

		if auth_request.get("path", "") != "/oauth/emailexchange":
			failures.append("Unexpected auth path: %s" % auth_request.get("path", "<missing>"))
		if listing_request.get("path", "") != "/games/demo-game/mods":
			failures.append("Unexpected listing path: %s" % listing_request.get("path", "<missing>"))
		if download_request.get("binary_url", "") == "":
			failures.append("Expected download metadata binary_url to be preserved.")
		if download_request.get("is_canonical_url", true):
			failures.append("Download metadata should flag mod.io binary_url values as non-canonical.")

	if failures.is_empty():
		print("Scaffold validation passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)

	quit(1)
