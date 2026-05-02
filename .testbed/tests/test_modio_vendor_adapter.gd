extends GutTest

const ModioClientConfig = preload("res://src/models/modio_client_config.gd")
const ModioListingQuery = preload("res://src/models/modio_listing_query.gd")
const ModioDownloadRequest = preload("res://src/models/modio_download_request.gd")
const ModioHttpTransport = preload("res://src/network/modio_http_transport.gd")
const ModioVendorAdapter = preload("res://src/modio_vendor_adapter.gd")

func test_build_listing_request_targets_game_mods_endpoint() -> void:
	var adapter = ModioVendorAdapter.new(
		ModioClientConfig.new("demo-game", "demo-key"),
		ModioHttpTransport.new()
	)
	var request = adapter.build_listing_request(ModioListingQuery.new("boxing", PackedStringArray(["approved"]), 10, 5))

	assert_eq(request.path, "/games/demo-game/mods")
	assert_eq(request.query._q, "boxing")
	assert_eq(request.query.tags, "approved")
	assert_eq(request.query._limit, "10")
	assert_eq(request.query._offset, "5")

func test_build_download_request_targets_provider_file_download_endpoint() -> void:
	var adapter = ModioVendorAdapter.new(
		ModioClientConfig.new("demo-game", "demo-key"),
		ModioHttpTransport.new()
	)
	var request = adapter.build_download_request(ModioDownloadRequest.new("1234", "5678"))

	assert_eq(request.method, "GET")
	assert_eq(request.path, "/games/demo-game/mods/1234/files/5678/download")
	assert_eq(request.headers["X-Modio-Api-Key"], "demo-key")
