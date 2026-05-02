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
		var config = config_script.new("demo-game", "demo-key")
		var transport = transport_script.new()
		var adapter = adapter_script.new(config, transport)
		var auth_request: Dictionary = adapter.build_auth_exchange_request("demo-code", "aerobeat://callback")
		var listing_request: Dictionary = adapter.build_listing_request(query_script.new("boxing"))
		var download_request: Dictionary = adapter.build_download_request(download_script.new("1234", "5678"))

		if auth_request.get("path", "") != "/oauth/emailexchange":
			failures.append("Unexpected auth path: %s" % auth_request.get("path", "<missing>"))
		if listing_request.get("path", "") != "/games/demo-game/mods":
			failures.append("Unexpected listing path: %s" % listing_request.get("path", "<missing>"))
		if download_request.get("path", "") != "/games/demo-game/mods/1234/files/5678/download":
			failures.append("Unexpected download path: %s" % download_request.get("path", "<missing>"))
		if download_request.get("method", "") != "GET":
			failures.append("Download request should use GET.")

	if failures.is_empty():
		print("Scaffold validation passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)

	quit(1)
