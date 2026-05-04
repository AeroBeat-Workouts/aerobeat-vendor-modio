extends GutTest

const ModioClientConfig = preload("res://src/models/modio_client_config.gd")
const ModioListingQuery = preload("res://src/models/modio_listing_query.gd")
const ModioHttpTransport = preload("res://src/network/modio_http_transport.gd")
const ModioVendorAdapter = preload("res://src/modio_vendor_adapter.gd")

var _recorded_requests: Array = []
var _queued_responses: Array = []

func before_each() -> void:
	_recorded_requests.clear()
	_queued_responses.clear()

func test_resolves_base_urls_with_explicit_override_and_deterministic_fallbacks() -> void:
	var default_config := ModioClientConfig.new("777", "demo-key")
	assert_eq(default_config.resolve_base_url(" https://mods.example.com/custom/ "), "https://mods.example.com/custom")
	assert_eq(default_config.resolve_base_url(""), ModioClientConfig.DEFAULT_BASE_URL)

	var game_host_config := ModioClientConfig.new("777", "demo-key", "", "", "en-US", "steam", "WINDOWS", ModioClientConfig.HOST_GAME)
	assert_eq(game_host_config.resolve_base_url(), "https://g-777.modapi.io/v1")

	var sandbox_game_host_config := ModioClientConfig.new("777", "demo-key", "", "", "en-US", "steam", "WINDOWS", ModioClientConfig.HOST_GAME, "", true)
	assert_eq(sandbox_game_host_config.resolve_base_url(), "https://g-777.test.mod.io/v1")

	var user_host_config := ModioClientConfig.new("777", "demo-key", "", "", "en-US", "steam", "WINDOWS", ModioClientConfig.HOST_USER, "42", true)
	assert_eq(user_host_config.resolve_base_url(), "https://u-42.test.mod.io/v1")

func test_executes_public_get_requests_with_final_encoded_query_and_headers() -> void:
	var config := ModioClientConfig.new("777", "demo-key", "https://api.mod.io/v1/", "", "fr-CA", "steam", "WINDOWS")
	var transport := ModioHttpTransport.new(Callable(self, "_transport_double"))
	var adapter := ModioVendorAdapter.new(config, transport)
	var query := ModioListingQuery.new(
		"boxing gloves",
		PackedStringArray(["approved", "featured"]),
		10,
		5,
		"-downloads_total",
		PackedStringArray(["cardio"]),
		PackedStringArray(["hidden"]),
		"{\"intensity\":\"high\"}",
		{"difficulty": "expert", "workout_type": "cardio"},
		"1001",
		"cardio-blaster",
		1,
		1,
		"55"
	)

	_queue_json_response(200, _fixture("mods.json"))
	var response := transport.execute(adapter.build_listing_request(query), config)

	assert_true(response.ok)
	assert_eq(_recorded_requests.size(), 1)
	assert_eq(_recorded_requests[0].url, "https://api.mod.io/v1/games/777/mods?_limit=10&_offset=5&_q=boxing%20gloves&_sort=-downloads_total&api_key=demo-key&id=1001&metadata_blob=%7B%22intensity%22%3A%22high%22%7D&metadata_kvp=difficulty%3Aexpert%2Cworkout_type%3Acardio&name_id=cardio-blaster&status=1&submitted_by=55&tags=approved%2Cfeatured&tags-in=cardio&tags-not-in=hidden&visible=1")
	assert_eq(_recorded_requests[0].headers["Accept-Language"], "fr-CA")

	var invalid_mod_sort_query := ModioListingQuery.new()
	invalid_mod_sort_query.sort = "-comments_total"
	_queue_json_response(200, _fixture("mods.json"))
	var invalid_mod_sort_response := transport.execute(adapter.build_listing_request(invalid_mod_sort_query), config)
	assert_true(invalid_mod_sort_response.ok)
	assert_eq(_recorded_requests[1].url, "https://api.mod.io/v1/games/777/mods?_limit=25&_offset=0&api_key=demo-key")

	assert_eq(_recorded_requests[0].headers["X-Modio-Platform"], "WINDOWS")
	assert_eq(_recorded_requests[0].headers["X-Modio-Portal"], "steam")
	assert_eq(int(response.payload.result_total), 13)

func test_executes_authenticated_terms_me_and_agreement_requests_without_api_key_leaks() -> void:
	var config := ModioClientConfig.new("777", "demo-key", "", "user-token", "en-US", "steam", "WINDOWS", ModioClientConfig.HOST_GAME)
	var transport := ModioHttpTransport.new(Callable(self, "_transport_double"))
	var adapter := ModioVendorAdapter.new(config, transport)

	_queue_json_response(200, _fixture("terms.json"))
	var terms_response := transport.execute(adapter.build_terms_request(), config, {"base_url": "https://api.test.mod.io/v1/"})
	assert_true(terms_response.ok)
	assert_eq(_recorded_requests[0].url, "https://api.test.mod.io/v1/authenticate/terms?api_key=demo-key")
	assert_false(_recorded_requests[0].headers.has("Authorization"))

	_queue_json_response(200, _fixture("agreement_current.json"))
	var agreement_response := transport.execute(adapter.build_current_agreement_request(2), config)
	assert_true(agreement_response.ok)
	assert_eq(_recorded_requests[1].url, "https://g-777.modapi.io/v1/agreements/types/2/current?api_key=demo-key")

	_queue_json_response(200, _fixture("me.json"))
	var me_response := transport.execute(adapter.build_authenticated_user_request("delegate-123"), config)
	assert_true(me_response.ok)
	assert_eq(_recorded_requests[2].url, "https://g-777.modapi.io/v1/me")
	assert_eq(_recorded_requests[2].headers.Authorization, "Bearer user-token")
	assert_eq(_recorded_requests[2].headers["X-Modio-Delegation-Token"], "delegate-123")
	assert_false(_recorded_requests[2].url.contains("api_key="))
	assert_eq(int(me_response.payload.id), 42)

func test_executes_form_encoded_logout_and_subscription_writes_with_bearer_auth_only() -> void:
	var config := ModioClientConfig.new("777", "demo-key", "", "user-token", "en-US", "steam", "WINDOWS", ModioClientConfig.HOST_GAME)
	var transport := ModioHttpTransport.new(Callable(self, "_transport_double"))
	var adapter := ModioVendorAdapter.new(config, transport)

	_queue_json_response(200, _fixture("logout_success.json"))
	var logout_response := transport.execute(adapter.build_logout_request(), config)
	assert_true(logout_response.ok)
	assert_eq(_recorded_requests[0].method, "POST")
	assert_eq(_recorded_requests[0].url, "https://g-777.modapi.io/v1/oauth/logout")
	assert_eq(_recorded_requests[0].headers.Authorization, "Bearer user-token")
	assert_eq(_recorded_requests[0].headers["Content-Type"], ModioHttpTransport.CONTENT_TYPE_FORM)
	assert_eq(_recorded_requests[0].body_string, "")
	assert_false(_recorded_requests[0].url.contains("api_key="))

	_queue_json_response(201, _fixture("mod_detail.json"), {"Location": "/me/subscribed/1001"})
	var subscribe_response := transport.execute(adapter.build_subscribe_request("1001", true), config)
	assert_true(subscribe_response.ok)
	assert_eq(_recorded_requests[1].method, "POST")
	assert_eq(_recorded_requests[1].url, "https://g-777.modapi.io/v1/games/777/mods/1001/subscribe")
	assert_eq(_recorded_requests[1].body_string, "include_dependencies=true")
	assert_eq(_recorded_requests[1].headers.Authorization, "Bearer user-token")
	assert_false(_recorded_requests[1].url.contains("api_key="))

	_queue_response({"status_code": 204, "headers": {}, "body": ""})
	var unsubscribe_response := transport.execute(adapter.build_unsubscribe_request("1001"), config)
	assert_true(unsubscribe_response.ok)
	assert_eq(_recorded_requests[2].method, "DELETE")
	assert_eq(_recorded_requests[2].url, "https://g-777.modapi.io/v1/games/777/mods/1001/subscribe")
	assert_eq(unsubscribe_response.payload, {})

func test_executes_raw_multipart_part_uploads_with_query_headers_and_bytes() -> void:
	var config := ModioClientConfig.new("777", "demo-key", "", "user-token", "en-US", "steam", "WINDOWS", ModioClientConfig.HOST_GAME)
	var transport := ModioHttpTransport.new(Callable(self, "_transport_double"))
	var adapter := ModioVendorAdapter.new(config, transport)
	var part_bytes := PackedByteArray([0, 1, 2, 3, 4])

	_queue_json_response(200, {"upload_id": "123e4567-e89b-12d3-a456-426614174000", "part_number": 1, "part_size": 5, "date_added": 1777800001})
	var response := transport.execute(adapter.build_upload_multipart_part_request("1001", "123e4567-e89b-12d3-a456-426614174000", part_bytes, "bytes 0-4/5", "sha-256=:abc="), config)

	assert_true(response.ok)
	assert_eq(_recorded_requests.size(), 1)
	assert_eq(_recorded_requests[0].method, "PUT")
	assert_eq(_recorded_requests[0].url, "https://g-777.modapi.io/v1/games/777/mods/1001/files/multipart?upload_id=123e4567-e89b-12d3-a456-426614174000")
	assert_eq(_recorded_requests[0].headers.Authorization, "Bearer user-token")
	assert_eq(_recorded_requests[0].headers["Content-Type"], "application/octet-stream")
	assert_eq(_recorded_requests[0].headers["Content-Range"], "bytes 0-4/5")
	assert_eq(_recorded_requests[0].headers.Digest, "sha-256=:abc=")
	assert_eq(_recorded_requests[0].headers["Content-Length"], "5")
	assert_true(_recorded_requests[0].has_raw_body)
	assert_eq(_recorded_requests[0].body_bytes, part_bytes)
	assert_eq(int(response.payload.part_size), 5)

func test_executes_external_auth_requests_with_documented_paths_bodies_and_headers() -> void:
	var config := ModioClientConfig.new("777", "demo-key", "", "user-token")
	var transport := ModioHttpTransport.new(Callable(self, "_transport_double"))
	var adapter := ModioVendorAdapter.new(config, transport)
	var now := int(Time.get_unix_time_from_system())
	var requested_expiry := now + 999999999
	var expected_week_expiry := now + 604800
	var expected_year_expiry := now + 31536000

	_queue_json_response(200, _fixture("access_token.json"))
	transport.execute(adapter.build_apple_auth_request("apple-jwt", true, requested_expiry), config, {"base_url": "https://api.mod.io/v1"})
	assert_eq(_recorded_requests[0].url, "https://api.mod.io/v1/external/appleauth?api_key=demo-key")
	assert_eq(_recorded_requests[0].body_string, "date_expires=%s&id_token=apple-jwt&terms_agreed=true" % [expected_week_expiry])
	assert_false(_recorded_requests[0].headers.has("Authorization"))

	_queue_json_response(200, _fixture("access_token.json"))
	transport.execute(adapter.build_gog_galaxy_auth_request("gog-ticket", true, "gog@example.com", requested_expiry), config, {"base_url": "https://api.mod.io/v1"})
	assert_eq(_recorded_requests[1].url, "https://api.mod.io/v1/external/galaxyauth?api_key=demo-key")
	assert_eq(_recorded_requests[1].body_string, "appdata=gog-ticket&date_expires=" + str(expected_week_expiry) + "&email=gog%40example.com&terms_agreed=true")

	_queue_json_response(200, _fixture("access_token.json"))
	transport.execute(adapter.build_google_auth_request("google-auth-code", "", true, requested_expiry), config, {"base_url": "https://api.mod.io/v1"})
	assert_eq(_recorded_requests[2].url, "https://api.mod.io/v1/external/googleauth?api_key=demo-key")
	assert_eq(_recorded_requests[2].body_string, "auth_code=google-auth-code&date_expires=%s&terms_agreed=true" % [expected_week_expiry])

	_queue_json_response(200, _fixture("access_token.json"))
	transport.execute(adapter.build_oculus_auth_request("quest", "nonce-value", 1829770514, "access-token", true, "vr@example.com", requested_expiry), config, {"base_url": "https://api.mod.io/v1"})
	assert_eq(_recorded_requests[3].url, "https://api.mod.io/v1/external/oculusauth?api_key=demo-key")
	assert_eq(_recorded_requests[3].body_string, "access_token=access-token&date_expires=" + str(expected_year_expiry) + "&device=quest&email=vr%40example.com&nonce=nonce-value&terms_agreed=true&user_id=1829770514")

	_queue_json_response(200, _fixture("access_token.json"))
	transport.execute(adapter.build_udt_auth_request("delegate-123"), config, {"base_url": "https://api.mod.io/v1"})
	assert_eq(_recorded_requests[4].url, "https://api.mod.io/v1/external/udtauth?api_key=demo-key")
	assert_eq(_recorded_requests[4].body_string, "")
	assert_eq(_recorded_requests[4].headers["X-Modio-Delegation-Token"], "delegate-123")
	assert_false(_recorded_requests[4].headers.has("Authorization"))

	_queue_json_response(200, _fixture("access_token.json"))
	transport.execute(adapter.build_xbox_live_auth_request("xbl-token", true, "xbox@example.com", requested_expiry), config, {"base_url": "https://api.mod.io/v1"})
	assert_eq(_recorded_requests[5].url, "https://api.mod.io/v1/external/xboxauth?api_key=demo-key")
	assert_eq(_recorded_requests[5].body_string, "date_expires=" + str(expected_year_expiry) + "&email=xbox%40example.com&terms_agreed=true&xbox_token=xbl-token")

func test_executes_platform_targeted_subscription_sync_with_required_game_id() -> void:
	var config := ModioClientConfig.new("777", "demo-key", "", "user-token", "en-US", "steam", "WINDOWS", ModioClientConfig.HOST_GAME)
	var transport := ModioHttpTransport.new(Callable(self, "_transport_double"))
	var adapter := ModioVendorAdapter.new(config, transport)
	var query := ModioListingQuery.new(
		"boxing",
		PackedStringArray(["approved"]),
		25,
		25,
		"-downloads_total",
		PackedStringArray(["cardio"]),
		PackedStringArray(["hidden"]),
		"{\"intensity\":\"high\"}",
		{"workout_type": "cardio"},
		"1001",
		"cardio-blaster",
		1,
		1,
		"55"
	)

	_queue_json_response(200, _fixture("subscribed.json"))
	var response := transport.execute(adapter.build_user_subscriptions_request(query), config)
	assert_true(response.ok)
	assert_eq(_recorded_requests[0].url, "https://g-777.modapi.io/v1/me/subscribed?_limit=25&_offset=25&_q=boxing&_sort=-downloads_total&game_id=777&id=1001&metadata_blob=%7B%22intensity%22%3A%22high%22%7D&metadata_kvp=workout_type%3Acardio&name_id=cardio-blaster&status=1&submitted_by=55&tags=approved&tags-in=cardio&tags-not-in=hidden&visible=1")
	assert_eq(_recorded_requests[0].headers.Authorization, "Bearer user-token")
	assert_false(_recorded_requests[0].url.contains("api_key="))

	var invalid_subscription_sort_query := ModioListingQuery.new()
	invalid_subscription_sort_query.sort = "-ratings_weighted_aggregate"
	_queue_json_response(200, _fixture("subscribed.json"))
	var invalid_subscription_sort_response := transport.execute(adapter.build_user_subscriptions_request(invalid_subscription_sort_query), config)
	assert_true(invalid_subscription_sort_response.ok)
	assert_eq(_recorded_requests[1].url, "https://g-777.modapi.io/v1/me/subscribed?_limit=25&_offset=0&game_id=777")

func test_executes_dependency_requests_with_explicit_recursive_semantics() -> void:
	var config := ModioClientConfig.new("777", "demo-key", "https://api.mod.io/v1/", "", "en-US", "steam", "WINDOWS")
	var transport := ModioHttpTransport.new(Callable(self, "_transport_double"))
	var adapter := ModioVendorAdapter.new(config, transport)

	_queue_json_response(200, _fixture("dependencies_recursive.json"))
	var immediate_response := transport.execute(adapter.build_dependencies_request("1001"), config)
	assert_true(immediate_response.ok)
	assert_eq(_recorded_requests[0].url, "https://api.mod.io/v1/games/777/mods/1001/dependencies?api_key=demo-key&recursive=false")

	_queue_json_response(200, _fixture("dependencies_recursive.json"))
	var recursive_response := transport.execute(adapter.build_dependencies_request("1001", true), config)
	assert_true(recursive_response.ok)
	assert_eq(_recorded_requests[1].url, "https://api.mod.io/v1/games/777/mods/1001/dependencies?api_key=demo-key&recursive=true")
	assert_eq(int(recursive_response.payload.result_total), 2)

func test_executes_mod_adjacent_read_enrichment_requests_with_documented_urls() -> void:
	var config := ModioClientConfig.new("777", "demo-key", "https://api.mod.io/v1/", "", "en-US", "steam", "WINDOWS")
	var transport := ModioHttpTransport.new(Callable(self, "_transport_double"))
	var adapter := ModioVendorAdapter.new(config, transport)

	var dependants_query := ModioListingQuery.new()
	dependants_query.limit = 12
	dependants_query.offset = 24
	_queue_json_response(200, _fixture("mod_dependants.json"))
	var dependants_response := transport.execute(adapter.build_dependants_request("1001", dependants_query), config)
	assert_true(dependants_response.ok)
	assert_eq(_recorded_requests[0].url, "https://api.mod.io/v1/games/777/mods/1001/dependants?_limit=12&_offset=24&api_key=demo-key")

	var tags_query := ModioListingQuery.new()
	tags_query.limit = 15
	tags_query.offset = 30
	tags_query.tag = "Featured"
	tags_query.date_added = 1777800001
	_queue_json_response(200, _fixture("mod_tags.json"))
	var tags_response := transport.execute(adapter.build_mod_tags_request("1001", tags_query), config)
	assert_true(tags_response.ok)
	assert_eq(_recorded_requests[1].url, "https://api.mod.io/v1/games/777/mods/1001/tags?_limit=15&_offset=30&api_key=demo-key&date_added=1777800001&tag=Featured")

	var metadata_query := ModioListingQuery.new()
	metadata_query.limit = 8
	metadata_query.offset = 16
	_queue_json_response(200, _fixture("mod_metadata_kvp.json"))
	var metadata_response := transport.execute(adapter.build_mod_metadata_kvp_request("1001", metadata_query), config)
	assert_true(metadata_response.ok)
	assert_eq(_recorded_requests[2].url, "https://api.mod.io/v1/games/777/mods/1001/metadatakvp?_limit=8&_offset=16&api_key=demo-key")

	var team_query := ModioListingQuery.new()
	team_query.limit = 20
	team_query.offset = 40
	team_query.id = "457"
	team_query.user_id = "42"
	team_query.username = "Coach Chip"
	team_query.level = 8
	team_query.date_added = 1777801000
	team_query.pending = 1
	_queue_json_response(200, _fixture("mod_team.json"))
	var team_response := transport.execute(adapter.build_mod_team_request("1001", team_query), config)
	assert_true(team_response.ok)
	assert_eq(_recorded_requests[3].url, "https://api.mod.io/v1/games/777/mods/1001/team?_limit=20&_offset=40&api_key=demo-key&date_added=1777801000&id=457&level=8&pending=1&user_id=42&username=Coach%20Chip")
	assert_eq(int(team_response.payload.result_total), 2)

func test_executes_modfile_stats_ratings_and_report_requests_with_documented_shapes() -> void:
	var public_config := ModioClientConfig.new("777", "demo-key", "https://api.mod.io/v1/", "", "en-US", "steam", "WINDOWS")
	var auth_config := ModioClientConfig.new("777", "demo-key", "", "user-token", "en-US", "steam", "WINDOWS", ModioClientConfig.HOST_GAME)
	var transport := ModioHttpTransport.new(Callable(self, "_transport_double"))
	var public_adapter := ModioVendorAdapter.new(public_config, transport)
	var auth_adapter := ModioVendorAdapter.new(auth_config, transport)

	_queue_json_response(200, _fixture("modfile_detail.json"))
	var modfile_response := transport.execute(public_adapter.build_modfile_request("1001", "5002"), public_config)
	assert_true(modfile_response.ok)
	assert_eq(_recorded_requests[0].url, "https://api.mod.io/v1/games/777/mods/1001/files/5002?api_key=demo-key")

	_queue_json_response(200, _fixture("mod_stats.json"))
	var mod_stats_response := transport.execute(public_adapter.build_mod_stats_request("1001"), public_config)
	assert_true(mod_stats_response.ok)
	assert_eq(_recorded_requests[1].url, "https://api.mod.io/v1/games/777/mods/1001/stats?api_key=demo-key")

	var ratings_query := ModioListingQuery.new("", PackedStringArray(), 50, 0, "", PackedStringArray(), PackedStringArray(), "", {}, "", "", -1, -1, "", "777", "1001", -1, "mods", 1777800001)
	_queue_json_response(200, _fixture("user_ratings.json"))
	var ratings_response := transport.execute(auth_adapter.build_user_ratings_request(ratings_query), auth_config)
	assert_true(ratings_response.ok)
	assert_eq(_recorded_requests[2].url, "https://g-777.modapi.io/v1/me/ratings?_limit=50&_offset=0&date_added=1777800001&game_id=777&mod_id=1001&rating=-1&resource_type=mods")
	assert_eq(_recorded_requests[2].headers.Authorization, "Bearer user-token")
	assert_false(_recorded_requests[2].url.contains("api_key="))

	_queue_json_response(201, _fixture("add_mod_rating_success.json"))
	var add_rating_response := transport.execute(auth_adapter.build_add_mod_rating_request("1001", -1), auth_config)
	assert_true(add_rating_response.ok)
	assert_eq(_recorded_requests[3].url, "https://g-777.modapi.io/v1/games/777/mods/1001/ratings")
	assert_eq(_recorded_requests[3].body_string, "rating=-1")
	assert_eq(_recorded_requests[3].headers.Authorization, "Bearer user-token")

	_queue_json_response(201, _fixture("report_success.json"))
	var report_response := transport.execute(auth_adapter.build_submit_report_request("mods", "1001", 2, "crashes after song load", {
		"reason": 6,
		"platforms": "WINDOWS",
		"game_name_id": "aerobeat"
	}), auth_config)
	assert_true(report_response.ok)
	assert_eq(_recorded_requests[4].url, "https://g-777.modapi.io/v1/report")
	assert_eq(_recorded_requests[4].body_string, "game_name_id=aerobeat&id=1001&platforms=WINDOWS&reason=6&resource=MODS&summary=crashes%20after%20song%20load&type=2")
	assert_eq(_recorded_requests[4].headers.Authorization, "Bearer user-token")

func test_executes_modfile_write_requests_with_documented_multipart_form_and_delete_shapes() -> void:
	var public_config := ModioClientConfig.new("777", "demo-key", "https://api.mod.io/v1/", "", "en-US", "steam", "WINDOWS")
	var auth_config := ModioClientConfig.new("777", "demo-key", "", "user-token", "en-US", "steam", "WINDOWS", ModioClientConfig.HOST_GAME)
	var transport := ModioHttpTransport.new(Callable(self, "_transport_double"))
	var public_adapter := ModioVendorAdapter.new(public_config, transport)
	var auth_adapter := ModioVendorAdapter.new(auth_config, transport)

	_queue_json_response(200, _fixture("modfile_cooks.json"))
	var cooks_response := transport.execute(public_adapter.build_modfile_cooks_request("1001"), public_config)
	assert_true(cooks_response.ok)
	assert_eq(_recorded_requests[0].method, "GET")
	assert_eq(_recorded_requests[0].url, "https://api.mod.io/v1/games/777/mods/1001/cooks?api_key=demo-key")

	_queue_json_response(201, _fixture("modfile_detail.json"), {"Location": "/games/777/mods/1001/files/5002"})
	var add_response := transport.execute(auth_adapter.build_add_modfile_request("1001", {
		"filedata": "@/tmp/cardio-blaster-v1-1.zip",
		"version": "1.1.0",
		"changelog": "New cardio pass",
		"active": true,
		"filehash": "938c2cc0dcc05f2b68c4287040cfcf71",
		"metadata_blob": "client_signature:abcd-5002",
		"platforms": ["WINDOWS", "SWITCH2"]
	}), auth_config, {"multipart_boundary": "TEST-BOUNDARY"})
	assert_true(add_response.ok)
	assert_eq(_recorded_requests[1].method, "POST")
	assert_eq(_recorded_requests[1].url, "https://g-777.modapi.io/v1/games/777/mods/1001/files")
	assert_eq(_recorded_requests[1].headers.Authorization, "Bearer user-token")
	assert_eq(_recorded_requests[1].headers["Content-Type"], "multipart/form-data; boundary=TEST-BOUNDARY")
	assert_string_contains(_recorded_requests[1].body_string, 'name="filedata"')
	assert_string_contains(_recorded_requests[1].body_string, '@/tmp/cardio-blaster-v1-1.zip')
	assert_string_contains(_recorded_requests[1].body_string, 'name="platforms[]"')
	assert_string_contains(_recorded_requests[1].body_string, 'WINDOWS')
	assert_string_contains(_recorded_requests[1].body_string, 'SWITCH2')
	assert_string_contains(_recorded_requests[1].body_string, 'name="active"')
	assert_string_contains(_recorded_requests[1].body_string, 'true')

	_queue_json_response(200, _fixture("modfile_detail.json"))
	var update_response := transport.execute(auth_adapter.build_update_modfile_request("1001", "5002", {
		"version": "1.1.1",
		"changelog": "Timing cleanup",
		"active": false,
		"metadata_blob": "game_version:1.1.1"
	}), auth_config)
	assert_true(update_response.ok)
	assert_eq(_recorded_requests[2].method, "PUT")
	assert_eq(_recorded_requests[2].url, "https://g-777.modapi.io/v1/games/777/mods/1001/files/5002")
	assert_eq(_recorded_requests[2].headers.Authorization, "Bearer user-token")
	assert_eq(_recorded_requests[2].headers["Content-Type"], ModioHttpTransport.CONTENT_TYPE_FORM)
	assert_eq(_recorded_requests[2].body_string, "active=false&changelog=Timing%20cleanup&metadata_blob=game_version%3A1.1.1&version=1.1.1")

	_queue_json_response(200, _fixture("modfile_platform_status_updated.json"))
	var manage_platforms_response := transport.execute(auth_adapter.build_manage_modfile_platforms_request("1001", "5002", {
		"approved": ["WINDOWS", "PLAYSTATION5"],
		"denied": ["SWITCH2"]
	}), auth_config)
	assert_true(manage_platforms_response.ok)
	assert_eq(_recorded_requests[3].method, "POST")
	assert_eq(_recorded_requests[3].url, "https://g-777.modapi.io/v1/games/777/mods/1001/files/5002/platforms")
	assert_eq(_recorded_requests[3].headers.Authorization, "Bearer user-token")
	assert_eq(_recorded_requests[3].headers["Content-Type"], ModioHttpTransport.CONTENT_TYPE_FORM)
	assert_eq(_recorded_requests[3].body_string, "approved%5B%5D=WINDOWS&approved%5B%5D=PLAYSTATION5&denied%5B%5D=SWITCH2")

	_queue_response({"status_code": 204, "headers": {}, "body": ""})
	var finalize_response := transport.execute(auth_adapter.build_finalize_cloud_cooking_request(), auth_config)
	assert_true(finalize_response.ok)
	assert_eq(_recorded_requests[4].method, "POST")
	assert_eq(_recorded_requests[4].url, "https://g-777.modapi.io/v1/games/777/cloud-cooking/finalization")
	assert_eq(_recorded_requests[4].headers.Authorization, "Bearer user-token")
	assert_eq(_recorded_requests[4].headers["Content-Type"], ModioHttpTransport.CONTENT_TYPE_FORM)
	assert_eq(_recorded_requests[4].body_string, "")

	_queue_response({"status_code": 204, "headers": {}, "body": ""})
	var delete_response := transport.execute(auth_adapter.build_delete_modfile_request("1001", "5002"), auth_config)
	assert_true(delete_response.ok)
	assert_eq(_recorded_requests[5].method, "DELETE")
	assert_eq(_recorded_requests[5].url, "https://g-777.modapi.io/v1/games/777/mods/1001/files/5002")
	assert_eq(_recorded_requests[5].headers.Authorization, "Bearer user-token")
	assert_eq(_recorded_requests[5].headers["Content-Type"], ModioHttpTransport.CONTENT_TYPE_FORM)
	assert_eq(_recorded_requests[5].body_string, "")

	var invalid_add_response := transport.execute(auth_adapter.build_add_modfile_request("1001", {
		"filedata": "@/tmp/mod.zip",
		"upload_id": "123e4567-e89b-12d3-a456-426614174000"
	}), auth_config)
	assert_false(invalid_add_response.ok)
	assert_eq(invalid_add_response.error.category, "transport")
	assert_string_contains(invalid_add_response.error.message, "Exactly one of filedata or upload_id must be supplied")

func test_executes_guide_requests_with_documented_urls_filters_and_form_bodies() -> void:
	var public_config := ModioClientConfig.new("777", "demo-key", "https://api.mod.io/v1/", "", "en-US", "steam", "WINDOWS")
	var auth_config := ModioClientConfig.new("777", "demo-key", "", "user-token", "en-US", "steam", "WINDOWS", ModioClientConfig.HOST_GAME)
	var transport := ModioHttpTransport.new(Callable(self, "_transport_double"))
	var public_adapter := ModioVendorAdapter.new(public_config, transport)
	var auth_adapter := ModioVendorAdapter.new(auth_config, transport)
	var guide_query := ModioListingQuery.new()
	guide_query.search_term = "ignored-search"
	guide_query.tags_all = PackedStringArray(["Instructions", "Beginner"])
	guide_query.limit = 20
	guide_query.offset = 40
	guide_query.sort = "-comments_total"
	guide_query.tags_any = PackedStringArray(["Featured"])
	guide_query.tags_not_in = PackedStringArray(["Hidden"])
	guide_query.metadata_blob = "ignored-metadata"
	guide_query.metadata_kvp = {"ignored": "pair"}
	guide_query.id = "7001"
	guide_query.name_id = "building-your-first-routine"
	guide_query.status = 1
	guide_query.submitted_by = "77"
	guide_query.game_id = "777"
	guide_query.date_added = 1777800001
	guide_query.submitted_by_display_name = "Coach Chip"
	guide_query.date_updated = 1777803600
	guide_query.date_live = 1777807200
	var guide_comment_query := ModioListingQuery.new()
	guide_comment_query.search_term = "ignored-search"
	guide_comment_query.tags_all = PackedStringArray(["Instructions"])
	guide_comment_query.limit = 15
	guide_comment_query.offset = 30
	guide_comment_query.sort = "ignored-sort"
	guide_comment_query.tags_any = PackedStringArray(["Featured"])
	guide_comment_query.tags_not_in = PackedStringArray(["Hidden"])
	guide_comment_query.metadata_blob = "ignored-metadata"
	guide_comment_query.metadata_kvp = {"ignored": "pair"}
	guide_comment_query.id = "9902"
	guide_comment_query.name_id = "ignored-name-id"
	guide_comment_query.status = 1
	guide_comment_query.submitted_by = "77"
	guide_comment_query.game_id = "777"
	guide_comment_query.date_added = 1777808300
	guide_comment_query.resource_id = "7001"
	guide_comment_query.reply_id = 9901
	guide_comment_query.thread_position = "01.01"
	guide_comment_query.karma = -1
	guide_comment_query.content = "Second-level reply"
	guide_comment_query.submitted_by_display_name = "ignored-display-name"
	guide_comment_query.date_updated = 1777803600
	guide_comment_query.date_live = 1777807200

	_queue_json_response(200, _fixture("guides.json"))
	var guides_response := transport.execute(public_adapter.build_guides_request(guide_query), public_config)
	assert_true(guides_response.ok)
	assert_eq(_recorded_requests[0].url, "https://api.mod.io/v1/games/777/guides?_limit=20&_offset=40&_sort=-comments_total&api_key=demo-key&date_added=1777800001&date_live=1777807200&date_updated=1777803600&game_id=777&id=7001&name_id=building-your-first-routine&status=1&submitted_by=77&submitted_by_display_name=Coach%20Chip&tags=Instructions%2CBeginner&tags-in=Featured&tags-not-in=Hidden")

	var invalid_guide_sort_query := ModioListingQuery.new()
	invalid_guide_sort_query.sort = "-downloads_total"
	_queue_json_response(200, _fixture("guides.json"))
	var invalid_guide_sort_response := transport.execute(public_adapter.build_guides_request(invalid_guide_sort_query), public_config)
	assert_true(invalid_guide_sort_response.ok)
	assert_eq(_recorded_requests[1].url, "https://api.mod.io/v1/games/777/guides?_limit=25&_offset=0&api_key=demo-key")

	_queue_json_response(200, _fixture("guide_detail.json"))
	var guide_response := transport.execute(public_adapter.build_guide_detail_request("7001"), public_config)
	assert_true(guide_response.ok)
	assert_eq(_recorded_requests[2].url, "https://api.mod.io/v1/games/777/guides/7001?api_key=demo-key")

	_queue_json_response(200, _fixture("guide_comments_list.json"))
	var guide_comments_response := transport.execute(public_adapter.build_guide_comments_request("7001", guide_comment_query), public_config)
	assert_true(guide_comments_response.ok)
	assert_eq(_recorded_requests[3].url, "https://api.mod.io/v1/games/777/guides/7001/comments?_limit=15&_offset=30&api_key=demo-key&content=Second-level%20reply&date_added=1777808300&id=9902&karma=-1&reply_id=9901&resource_id=7001&submitted_by=77&thread_position=01.01")

	_queue_json_response(200, _fixture("guide_comment_detail.json"))
	var guide_comment_response := transport.execute(public_adapter.build_guide_comment_request("7001", "9902"), public_config)
	assert_true(guide_comment_response.ok)
	assert_eq(_recorded_requests[4].url, "https://api.mod.io/v1/games/777/guides/7001/comments/9902?api_key=demo-key")

	_queue_json_response(201, _fixture("guide_comment_created.json"), {"Location": "/games/777/guides/7001/comments/9903"})
	var create_response := transport.execute(auth_adapter.build_add_guide_comment_request("7001", "Great pacing tip", 9901), auth_config)
	assert_true(create_response.ok)
	assert_eq(_recorded_requests[5].method, "POST")
	assert_eq(_recorded_requests[5].url, "https://g-777.modapi.io/v1/games/777/guides/7001/comments")
	assert_eq(_recorded_requests[5].body_string, "content=Great%20pacing%20tip&reply_id=9901")
	assert_eq(_recorded_requests[5].headers.Authorization, "Bearer user-token")

	_queue_json_response(200, _fixture("guide_comment_updated.json"))
	var update_response := transport.execute(auth_adapter.build_update_guide_comment_request("7001", "9903", "Tweaked for recovery"), auth_config)
	assert_true(update_response.ok)
	assert_eq(_recorded_requests[6].method, "PUT")
	assert_eq(_recorded_requests[6].url, "https://g-777.modapi.io/v1/games/777/guides/7001/comments/9903")
	assert_eq(_recorded_requests[6].body_string, "content=Tweaked%20for%20recovery")

	_queue_response({"status_code": 204, "headers": {}, "body": ""})
	var delete_response := transport.execute(auth_adapter.build_delete_guide_comment_request("7001", "9903"), auth_config)
	assert_true(delete_response.ok)
	assert_eq(_recorded_requests[7].method, "DELETE")
	assert_eq(_recorded_requests[7].url, "https://g-777.modapi.io/v1/games/777/guides/7001/comments/9903")

	_queue_json_response(200, _fixture("guide_comment_karma_updated.json"))
	var karma_response := transport.execute(auth_adapter.build_add_guide_comment_karma_request("7001", "9902", -1), auth_config)
	assert_true(karma_response.ok)
	assert_eq(_recorded_requests[8].method, "POST")
	assert_eq(_recorded_requests[8].url, "https://g-777.modapi.io/v1/games/777/guides/7001/comments/9902/karma")
	assert_eq(_recorded_requests[8].body_string, "karma=-1")

	_queue_json_response(403, _fixture("guide_comment_karma_downvote_disabled_error.json"))
	var guide_karma_forbidden_response := transport.execute(auth_adapter.build_add_guide_comment_karma_request("7001", "9902", -1), auth_config)
	assert_false(guide_karma_forbidden_response.ok)
	assert_eq(guide_karma_forbidden_response.error.category, "forbidden")
	assert_eq(guide_karma_forbidden_response.error.error_ref, 19045)

func test_executes_collection_requests_with_documented_urls_filters_and_form_bodies() -> void:
	var public_config := ModioClientConfig.new("777", "demo-key", "https://api.mod.io/v1/", "", "en-US", "steam", "WINDOWS")
	var auth_config := ModioClientConfig.new("777", "demo-key", "", "user-token", "en-US", "steam", "WINDOWS", ModioClientConfig.HOST_GAME)
	var transport := ModioHttpTransport.new(Callable(self, "_transport_double"))
	var public_adapter := ModioVendorAdapter.new(public_config, transport)
	var auth_adapter := ModioVendorAdapter.new(auth_config, transport)
	var collection_query := ModioListingQuery.new()
	collection_query.tags_all = PackedStringArray(["GAMEPLAY", "QUALITY_OF_LIFE"])
	collection_query.tags_any = PackedStringArray(["VISUAL"])
	collection_query.tags_not_in = PackedStringArray(["BUGFIXES"])
	collection_query.limit = 12
	collection_query.offset = 24
	collection_query.sort = "-date_updated"
	collection_query.id = "3001"
	collection_query.status = 1
	collection_query.mod_id = "1001"
	collection_query.category = "Cardio"
	collection_query.submitted_by = "42"
	collection_query.submitted_by_display_name = "Coach Chip"
	collection_query.date_added = 1777800001
	collection_query.date_updated = 1777803600
	collection_query.date_live = 1777807200
	collection_query.name = "Starter Bundle"
	collection_query.name_id = "starter-bundle"
	collection_query.maturity_option = 4
	var collection_mods_query := ModioListingQuery.new()
	collection_mods_query.limit = 5
	collection_mods_query.offset = 10
	collection_mods_query.sort = "-downloads_total"
	collection_mods_query.maturity_option = 8
	collection_mods_query.show_hidden_mods = true
	var collection_comment_query := ModioListingQuery.new()
	collection_comment_query.limit = 15
	collection_comment_query.offset = 30
	collection_comment_query.id = "9902"
	collection_comment_query.resource_id = "3001"
	collection_comment_query.submitted_by = "77"
	collection_comment_query.date_added = 1777801600
	collection_comment_query.reply_id = 9901
	collection_comment_query.thread_position = "01.01"
	collection_comment_query.karma = -1
	collection_comment_query.content = "Collection reply"

	_queue_json_response(200, _fixture("collections.json"))
	var collections_response := transport.execute(public_adapter.build_collections_request(collection_query), public_config)
	assert_true(collections_response.ok)
	assert_eq(_recorded_requests[0].url, "https://api.mod.io/v1/games/777/collections?_limit=12&_offset=24&_sort=-date_updated&api_key=demo-key&category=Cardio&date_added=1777800001&date_live=1777807200&date_updated=1777803600&id=3001&maturity_option=4&mod_id=1001&name=Starter%20Bundle&name_id=starter-bundle&status=1&submitted_by=42&submitted_by_display_name=Coach%20Chip&tags=GAMEPLAY%2CQUALITY_OF_LIFE&tags-in=VISUAL&tags-not-in=BUGFIXES")

	var invalid_collection_sort_query := ModioListingQuery.new()
	invalid_collection_sort_query.sort = "-downloads_total"
	_queue_json_response(200, _fixture("collections.json"))
	var invalid_collection_sort_response := transport.execute(public_adapter.build_collections_request(invalid_collection_sort_query), public_config)
	assert_true(invalid_collection_sort_response.ok)
	assert_eq(_recorded_requests[1].url, "https://api.mod.io/v1/games/777/collections?_limit=25&_offset=0&api_key=demo-key")

	_queue_json_response(200, _fixture("collection_detail.json"))
	var collection_response := transport.execute(public_adapter.build_collection_request("3001"), public_config)
	assert_true(collection_response.ok)
	assert_eq(_recorded_requests[2].url, "https://api.mod.io/v1/games/777/collections/3001?api_key=demo-key")

	_queue_json_response(200, _fixture("mods.json"))
	var collection_mods_response := transport.execute(public_adapter.build_collection_mods_request("3001", collection_mods_query), public_config)
	assert_true(collection_mods_response.ok)
	assert_eq(_recorded_requests[3].url, "https://api.mod.io/v1/games/777/collections/3001/mods?_limit=5&_offset=10&_sort=-downloads_total&api_key=demo-key&maturity_option=8&show_hidden_mods=true")

	var invalid_collection_mod_sort_query := ModioListingQuery.new()
	invalid_collection_mod_sort_query.sort = "-ratings_weighted_aggregate"
	_queue_json_response(200, _fixture("mods.json"))
	var invalid_collection_mod_sort_response := transport.execute(public_adapter.build_collection_mods_request("3001", invalid_collection_mod_sort_query), public_config)
	assert_true(invalid_collection_mod_sort_response.ok)
	assert_eq(_recorded_requests[4].url, "https://api.mod.io/v1/games/777/collections/3001/mods?_limit=25&_offset=0&api_key=demo-key")

	_queue_json_response(200, _fixture("collection_comments_list.json"))
	var collection_comments_response := transport.execute(public_adapter.build_collection_comments_request("3001", collection_comment_query), public_config)
	assert_true(collection_comments_response.ok)
	assert_eq(_recorded_requests[5].url, "https://api.mod.io/v1/games/777/collections/3001/comments?_limit=15&_offset=30&api_key=demo-key&content=Collection%20reply&date_added=1777801600&id=9902&karma=-1&reply_id=9901&resource_id=3001&submitted_by=77&thread_position=01.01")

	_queue_json_response(200, _fixture("collection_comment_detail.json"))
	var collection_comment_response := transport.execute(public_adapter.build_collection_comment_request("3001", "9902"), public_config)
	assert_true(collection_comment_response.ok)
	assert_eq(_recorded_requests[6].url, "https://api.mod.io/v1/games/777/collections/3001/comments/9902?api_key=demo-key")

	_queue_json_response(201, _fixture("collection_comment_created.json"), {"Location": "/games/777/collections/3001/comments/9910"})
	var create_response := transport.execute(auth_adapter.build_add_collection_comment_request("3001", "Fresh collection reply", 9901), auth_config)
	assert_true(create_response.ok)
	assert_eq(_recorded_requests[7].method, "POST")
	assert_eq(_recorded_requests[7].url, "https://g-777.modapi.io/v1/games/777/collections/3001/comments")
	assert_eq(_recorded_requests[7].body_string, "content=Fresh%20collection%20reply&reply_id=9901")
	assert_eq(_recorded_requests[7].headers.Authorization, "Bearer user-token")

	_queue_json_response(200, _fixture("collection_comment_updated.json"))
	var update_response := transport.execute(auth_adapter.build_update_collection_comment_request("3001", "9902", "Collection reply edited for clarity"), auth_config)
	assert_true(update_response.ok)
	assert_eq(_recorded_requests[8].method, "PUT")
	assert_eq(_recorded_requests[8].url, "https://g-777.modapi.io/v1/games/777/collections/3001/comments/9902")
	assert_eq(_recorded_requests[8].body_string, "content=Collection%20reply%20edited%20for%20clarity")

	_queue_response({"status_code": 204, "headers": {}, "body": ""})
	var delete_response := transport.execute(auth_adapter.build_delete_collection_comment_request("3001", "9902"), auth_config)
	assert_true(delete_response.ok)
	assert_eq(_recorded_requests[9].method, "DELETE")
	assert_eq(_recorded_requests[9].url, "https://g-777.modapi.io/v1/games/777/collections/3001/comments/9902")

	_queue_json_response(200, _fixture("collection_comment_karma_updated.json"))
	var karma_response := transport.execute(auth_adapter.build_add_collection_comment_karma_request("3001", "9902", -1), auth_config)
	assert_true(karma_response.ok)
	assert_eq(_recorded_requests[10].method, "POST")
	assert_eq(_recorded_requests[10].url, "https://g-777.modapi.io/v1/games/777/collections/3001/comments/9902/karma")
	assert_eq(_recorded_requests[10].body_string, "karma=-1")

	_queue_json_response(201, _fixture("add_collection_compatibility_success.json"))
	var compatibility_response := transport.execute(auth_adapter.build_add_collection_compatibility_request("3001", 1), auth_config)
	assert_true(compatibility_response.ok)
	assert_eq(_recorded_requests[11].method, "POST")
	assert_eq(_recorded_requests[11].url, "https://g-777.modapi.io/v1/games/777/collections/3001/compatibility")
	assert_eq(_recorded_requests[11].body_string, "rating=1")

func test_executes_user_inventory_requests_with_documented_authenticated_urls() -> void:
	var auth_config := ModioClientConfig.new("777", "demo-key", "", "user-token", "en-US", "steam", "WINDOWS", ModioClientConfig.HOST_GAME)
	var transport := ModioHttpTransport.new(Callable(self, "_transport_double"))
	var auth_adapter := ModioVendorAdapter.new(auth_config, transport)

	var games_query := ModioListingQuery.new()
	games_query.limit = 6
	games_query.offset = 12
	games_query.sort = "-date_updated"
	games_query.name = "AeroBeat"
	games_query.summary = "Rhythm workouts"
	games_query.instructions_url = "https://docs.aerobeat.example/mods"
	games_query.ugc_name = "mods"
	games_query.presentation_option = 0
	games_query.submission_option = 1
	games_query.curation_option = 2
	games_query.profanity_option = 3
	games_query.dependency_option = 2
	games_query.community_options = 258
	games_query.monetization_options = 1
	games_query.api_access_options = 7
	games_query.maturity_option = 0
	games_query.show_hidden_mods = true
	games_query.status = 1
	games_query.submitted_by = "42"

	_queue_json_response(200, _fixture("games.json"))
	var user_games_response := transport.execute(auth_adapter.build_user_games_request(games_query), auth_config)
	assert_true(user_games_response.ok)
	assert_eq(_recorded_requests[0].url, "https://g-777.modapi.io/v1/me/games?_limit=6&_offset=12&_sort=-date_updated&api_access_options=7&community_options=258&curation_option=2&dependency_option=2&instructions_url=https%3A%2F%2Fdocs.aerobeat.example%2Fmods&maturity_options=0&monetization_options=1&name=AeroBeat&presentation_option=0&profanity_option=3&show_hidden_tags=true&status=1&submission_option=1&submitted_by=42&summary=Rhythm%20workouts&ugc_name=mods")
	assert_eq(_recorded_requests[0].headers.Authorization, "Bearer user-token")
	assert_false(_recorded_requests[0].url.contains("api_key="))

	var user_mods_query := ModioListingQuery.new()
	user_mods_query.limit = 15
	user_mods_query.offset = 45
	user_mods_query.sort = "-downloads_total"
	user_mods_query.id = "1001"
	user_mods_query.game_id = "777"
	user_mods_query.status = 1
	user_mods_query.visible = 1
	user_mods_query.submitted_by = "55"
	user_mods_query.date_added = 1777800001
	user_mods_query.date_updated = 1777803600
	user_mods_query.date_live = 1777807200
	user_mods_query.name = "Cardio Blaster"
	user_mods_query.name_id = "cardio-blaster"
	user_mods_query.modfile = "5002"
	user_mods_query.metadata_blob = "{\"intensity\":\"high\"}"
	user_mods_query.metadata_kvp = {"difficulty": "expert", "workout_type": "cardio"}
	user_mods_query.tags_all = PackedStringArray(["Featured", "Cardio"])
	user_mods_query.maturity_option = 4
	user_mods_query.monetization_options = 1
	user_mods_query.platform_status = "live_and_pending"

	_queue_json_response(200, _fixture("mods.json"))
	var user_mods_response := transport.execute(auth_adapter.build_user_mods_request(user_mods_query), auth_config)
	assert_true(user_mods_response.ok)
	assert_eq(_recorded_requests[1].url, "https://g-777.modapi.io/v1/me/mods?_limit=15&_offset=45&_sort=-downloads_total&date_added=1777800001&date_live=1777807200&date_updated=1777803600&game_id=777&id=1001&maturity_option=4&metadata_blob=%7B%22intensity%22%3A%22high%22%7D&metadata_kvp=difficulty%3Aexpert%2Cworkout_type%3Acardio&modfile=5002&monetization_options=1&name=Cardio%20Blaster&name_id=cardio-blaster&platform_status=live_and_pending&status=1&submitted_by=55&tags=Featured%2CCardio&visible=1")
	assert_eq(_recorded_requests[1].headers.Authorization, "Bearer user-token")
	assert_false(_recorded_requests[1].url.contains("api_key="))

	var user_modfiles_query := ModioListingQuery.new()
	user_modfiles_query.limit = 9
	user_modfiles_query.offset = 18
	user_modfiles_query.id = "5002"
	user_modfiles_query.mod_id = "1001"
	user_modfiles_query.date_added = 1777800001
	user_modfiles_query.date_scanned = 1777801800
	user_modfiles_query.virus_status = 1
	user_modfiles_query.virus_positive = 0
	user_modfiles_query.filesize = 15181
	user_modfiles_query.filehash = "2d4a0e2d7273db6b0a94b0740a88ad0d"
	user_modfiles_query.filename = "cardio-blaster-v1.zip"
	user_modfiles_query.version = "1.3"
	user_modfiles_query.changelog = "Fixed stamina desync"
	user_modfiles_query.metadata_blob = "cardio,featured"
	user_modfiles_query.platform_status = "approved_only"

	_queue_json_response(200, _fixture("modfiles.json"))
	var user_modfiles_response := transport.execute(auth_adapter.build_user_modfiles_request(user_modfiles_query), auth_config)
	assert_true(user_modfiles_response.ok)
	assert_eq(_recorded_requests[2].url, "https://g-777.modapi.io/v1/me/files?_limit=9&_offset=18&changelog=Fixed%20stamina%20desync&date_added=1777800001&date_scanned=1777801800&filehash=2d4a0e2d7273db6b0a94b0740a88ad0d&filename=cardio-blaster-v1.zip&filesize=15181&id=5002&metadata_blob=cardio%2Cfeatured&mod_id=1001&platform_status=approved_only&version=1.3&virus_positive=0&virus_status=1")
	assert_eq(_recorded_requests[2].headers.Authorization, "Bearer user-token")
	assert_false(_recorded_requests[2].url.contains("api_key="))

func test_executes_user_social_and_account_state_requests_with_documented_urls() -> void:
	var public_config := ModioClientConfig.new("777", "demo-key", "https://api.mod.io/v1/", "", "en-US", "steam", "WINDOWS")
	var auth_config := ModioClientConfig.new("777", "demo-key", "", "user-token", "en-US", "steam", "WINDOWS", ModioClientConfig.HOST_GAME)
	var transport := ModioHttpTransport.new(Callable(self, "_transport_double"))
	var public_adapter := ModioVendorAdapter.new(public_config, transport)
	var auth_adapter := ModioVendorAdapter.new(auth_config, transport)
	var query := ModioListingQuery.new()
	query.limit = 40
	query.offset = 80
	query.sort = "-date_updated"
	query.search_term = "ignored-search"
	query.tags_all = PackedStringArray(["ignored-tag"])
	query.id = "9001"

	_queue_json_response(200, _fixture("user_social_users.json"))
	var user_followers_response := transport.execute(public_adapter.build_user_followers_request("42", query), public_config)
	assert_true(user_followers_response.ok)
	assert_eq(_recorded_requests[0].url, "https://api.mod.io/v1/users/42/followers?_limit=40&_offset=80&api_key=demo-key")

	_queue_json_response(200, _fixture("user_social_users.json"))
	var auth_user_followers_response := transport.execute(auth_adapter.build_user_followers_request("42", query), auth_config)
	assert_true(auth_user_followers_response.ok)
	assert_eq(_recorded_requests[1].url, "https://g-777.modapi.io/v1/users/42/followers?_limit=40&_offset=80")
	assert_eq(_recorded_requests[1].headers.Authorization, "Bearer user-token")

	_queue_json_response(200, _fixture("user_social_users.json"))
	var user_following_response := transport.execute(public_adapter.build_user_following_request("42", query), public_config)
	assert_true(user_following_response.ok)
	assert_eq(_recorded_requests[2].url, "https://api.mod.io/v1/users/42/following?_limit=40&_offset=80&api_key=demo-key")

	_queue_json_response(200, _fixture("user_social_users.json"))
	var auth_user_following_response := transport.execute(auth_adapter.build_user_following_request("42", query), auth_config)
	assert_true(auth_user_following_response.ok)
	assert_eq(_recorded_requests[3].url, "https://g-777.modapi.io/v1/users/42/following?_limit=40&_offset=80")
	assert_eq(_recorded_requests[3].headers.Authorization, "Bearer user-token")

	_queue_json_response(200, _fixture("collections.json"))
	var user_collections_response := transport.execute(public_adapter.build_user_collections_request("42", query), public_config)
	assert_true(user_collections_response.ok)
	assert_eq(_recorded_requests[4].url, "https://api.mod.io/v1/users/42/collections?_limit=40&_offset=80&api_key=demo-key")

	_queue_json_response(200, _fixture("collections.json"))
	var auth_user_collections_response := transport.execute(auth_adapter.build_user_collections_request("42", query), auth_config)
	assert_true(auth_user_collections_response.ok)
	assert_eq(_recorded_requests[5].url, "https://g-777.modapi.io/v1/users/42/collections?_limit=40&_offset=80")
	assert_eq(_recorded_requests[5].headers.Authorization, "Bearer user-token")

	_queue_json_response(200, _fixture("user_social_users.json"))
	var me_followers_response := transport.execute(auth_adapter.build_me_followers_request(query), auth_config)
	assert_true(me_followers_response.ok)
	assert_eq(_recorded_requests[6].url, "https://g-777.modapi.io/v1/me/followers?_limit=40&_offset=80")
	assert_eq(_recorded_requests[6].headers.Authorization, "Bearer user-token")

	_queue_json_response(200, _fixture("user_social_users.json"))
	var muted_users_response := transport.execute(auth_adapter.build_muted_users_request(query), auth_config)
	assert_true(muted_users_response.ok)
	assert_eq(_recorded_requests[7].url, "https://g-777.modapi.io/v1/me/users/muted?_limit=40&_offset=80")
	assert_eq(_recorded_requests[7].headers.Authorization, "Bearer user-token")

	_queue_json_response(200, _fixture("collections.json"))
	var me_collections_response := transport.execute(auth_adapter.build_me_collections_request(query), auth_config)
	assert_true(me_collections_response.ok)
	assert_eq(_recorded_requests[8].url, "https://g-777.modapi.io/v1/me/collections?_limit=40&_offset=80")
	assert_eq(_recorded_requests[8].headers.Authorization, "Bearer user-token")

	_queue_json_response(200, _fixture("collections.json"))
	var followed_collections_response := transport.execute(auth_adapter.build_followed_collections_request(query), auth_config)
	assert_true(followed_collections_response.ok)
	assert_eq(_recorded_requests[9].url, "https://g-777.modapi.io/v1/me/following/collections?_limit=40&_offset=80")
	assert_eq(_recorded_requests[9].headers.Authorization, "Bearer user-token")

func test_executes_social_mutation_writes_with_documented_urls_bodies_and_bearer_auth() -> void:
	var auth_config := ModioClientConfig.new("777", "demo-key", "", "user-token", "en-US", "steam", "WINDOWS", ModioClientConfig.HOST_GAME)
	var transport := ModioHttpTransport.new(Callable(self, "_transport_double"))
	var auth_adapter := ModioVendorAdapter.new(auth_config, transport)

	_queue_response({"status_code": 204, "headers": {}, "body": ""})
	var follow_user_response := transport.execute(auth_adapter.build_follow_user_request("42", "55"), auth_config)
	assert_true(follow_user_response.ok)
	assert_eq(_recorded_requests[0].method, "POST")
	assert_eq(_recorded_requests[0].url, "https://g-777.modapi.io/v1/users/42/following")
	assert_eq(_recorded_requests[0].body_string, "user_id=55")
	assert_eq(_recorded_requests[0].headers.Authorization, "Bearer user-token")
	assert_false(_recorded_requests[0].url.contains("api_key="))

	_queue_response({"status_code": 204, "headers": {}, "body": ""})
	var unfollow_user_response := transport.execute(auth_adapter.build_unfollow_user_request("42", "55"), auth_config)
	assert_true(unfollow_user_response.ok)
	assert_eq(_recorded_requests[1].method, "DELETE")
	assert_eq(_recorded_requests[1].url, "https://g-777.modapi.io/v1/users/42/following/55")
	assert_eq(_recorded_requests[1].body_string, "")

	_queue_response({"status_code": 204, "headers": {}, "body": ""})
	var mute_user_response := transport.execute(auth_adapter.build_mute_user_request("42"), auth_config)
	assert_true(mute_user_response.ok)
	assert_eq(_recorded_requests[2].method, "POST")
	assert_eq(_recorded_requests[2].url, "https://g-777.modapi.io/v1/users/42/mute")
	assert_eq(_recorded_requests[2].body_string, "")

	_queue_response({"status_code": 204, "headers": {}, "body": ""})
	var unmute_user_response := transport.execute(auth_adapter.build_unmute_user_request("42"), auth_config)
	assert_true(unmute_user_response.ok)
	assert_eq(_recorded_requests[3].method, "DELETE")
	assert_eq(_recorded_requests[3].url, "https://g-777.modapi.io/v1/users/42/mute")
	assert_eq(_recorded_requests[3].body_string, "")

	_queue_json_response(201, _fixture("collection_detail.json"), {"Location": "/games/777/collections/3001/followers"})
	var follow_collection_response := transport.execute(auth_adapter.build_follow_collection_request("3001"), auth_config)
	assert_true(follow_collection_response.ok)
	assert_eq(_recorded_requests[4].method, "POST")
	assert_eq(_recorded_requests[4].url, "https://g-777.modapi.io/v1/games/777/collections/3001/followers")
	assert_eq(_recorded_requests[4].body_string, "")
	assert_eq(_recorded_requests[4].headers.Authorization, "Bearer user-token")
	assert_eq(int(follow_collection_response.payload.id), 3001)

	_queue_response({"status_code": 204, "headers": {}, "body": ""})
	var unfollow_collection_response := transport.execute(auth_adapter.build_unfollow_collection_request("3001"), auth_config)
	assert_true(unfollow_collection_response.ok)
	assert_eq(_recorded_requests[5].method, "DELETE")
	assert_eq(_recorded_requests[5].url, "https://g-777.modapi.io/v1/games/777/collections/3001/followers")
	assert_eq(_recorded_requests[5].body_string, "")

	_queue_json_response(200, _fixture("collection_detail.json"))
	var subscribe_collection_response := transport.execute(auth_adapter.build_subscribe_collection_request("3001"), auth_config)
	assert_true(subscribe_collection_response.ok)
	assert_eq(_recorded_requests[6].method, "POST")
	assert_eq(_recorded_requests[6].url, "https://g-777.modapi.io/v1/games/777/collections/3001/subscriptions")
	assert_eq(_recorded_requests[6].body_string, "")
	assert_eq(_recorded_requests[6].headers.Authorization, "Bearer user-token")
	assert_eq(int(subscribe_collection_response.payload.id), 3001)

	_queue_json_response(200, _fixture("collection_detail.json"), {"Location": "/games/777/collections/3001/subscriptions"})
	var unsubscribe_collection_response := transport.execute(auth_adapter.build_unsubscribe_collection_request("3001"), auth_config)
	assert_true(unsubscribe_collection_response.ok)
	assert_eq(_recorded_requests[7].method, "DELETE")
	assert_eq(_recorded_requests[7].url, "https://g-777.modapi.io/v1/games/777/collections/3001/subscriptions")
	assert_eq(_recorded_requests[7].body_string, "")
	assert_eq(int(unsubscribe_collection_response.payload.id), 3001)

func test_executes_mod_comment_requests_with_documented_urls_and_form_bodies() -> void:
	var public_config := ModioClientConfig.new("777", "demo-key", "https://api.mod.io/v1/", "", "en-US", "steam", "WINDOWS")
	var auth_config := ModioClientConfig.new("777", "demo-key", "", "user-token", "en-US", "steam", "WINDOWS", ModioClientConfig.HOST_GAME)
	var transport := ModioHttpTransport.new(Callable(self, "_transport_double"))
	var public_adapter := ModioVendorAdapter.new(public_config, transport)
	var auth_adapter := ModioVendorAdapter.new(auth_config, transport)
	var comment_query := ModioListingQuery.new(
		"ignored",
		PackedStringArray(["approved"]),
		15,
		30,
		"ignored-sort",
		PackedStringArray(["cardio"]),
		PackedStringArray(["hidden"]),
		"ignored-metadata",
		{"ignored": "pair"},
		"9002",
		"ignored-name-id",
		1,
		1,
		"77",
		"",
		"1001",
		0,
		"",
		1777801300,
		"1001",
		9001,
		"01.01",
		-1,
		"Second-level reply"
	)

	_queue_json_response(200, _fixture("comments_list.json"))
	var comments_response := transport.execute(public_adapter.build_mod_comments_request("1001", comment_query), public_config)
	assert_true(comments_response.ok)
	assert_eq(_recorded_requests[0].url, "https://api.mod.io/v1/games/777/mods/1001/comments?_limit=15&_offset=30&api_key=demo-key&content=Second-level%20reply&date_added=1777801300&id=9002&karma=-1&mod_id=1001&reply_id=9001&resource_id=1001&submitted_by=77&thread_position=01.01")

	_queue_json_response(200, _fixture("comment_detail.json"))
	var comment_response := transport.execute(public_adapter.build_mod_comment_request("1001", "9002"), public_config)
	assert_true(comment_response.ok)
	assert_eq(_recorded_requests[1].url, "https://api.mod.io/v1/games/777/mods/1001/comments/9002?api_key=demo-key")

	_queue_json_response(201, _fixture("comment_created.json"), {"Location": "/games/777/mods/1001/comments/9010"})
	var create_response := transport.execute(auth_adapter.build_add_mod_comment_request("1001", "Fresh reply from the wrapper", 9001), auth_config)
	assert_true(create_response.ok)
	assert_eq(_recorded_requests[2].method, "POST")
	assert_eq(_recorded_requests[2].url, "https://g-777.modapi.io/v1/games/777/mods/1001/comments")
	assert_eq(_recorded_requests[2].body_string, "content=Fresh%20reply%20from%20the%20wrapper&reply_id=9001")
	assert_eq(_recorded_requests[2].headers.Authorization, "Bearer user-token")

	_queue_json_response(200, _fixture("comment_updated.json"))
	var update_response := transport.execute(auth_adapter.build_update_mod_comment_request("1001", "9010", "Edited reply from the wrapper"), auth_config)
	assert_true(update_response.ok)
	assert_eq(_recorded_requests[3].method, "PUT")
	assert_eq(_recorded_requests[3].url, "https://g-777.modapi.io/v1/games/777/mods/1001/comments/9010")
	assert_eq(_recorded_requests[3].body_string, "content=Edited%20reply%20from%20the%20wrapper")
	assert_eq(_recorded_requests[3].headers.Authorization, "Bearer user-token")

	_queue_response({"status_code": 204, "headers": {}, "body": ""})
	var delete_response := transport.execute(auth_adapter.build_delete_mod_comment_request("1001", "9010"), auth_config)
	assert_true(delete_response.ok)
	assert_eq(_recorded_requests[4].method, "DELETE")
	assert_eq(_recorded_requests[4].url, "https://g-777.modapi.io/v1/games/777/mods/1001/comments/9010")
	assert_eq(_recorded_requests[4].body_string, "")

	_queue_json_response(200, _fixture("comment_karma_updated.json"))
	var karma_response := transport.execute(auth_adapter.build_add_mod_comment_karma_request("1001", "9002", -1), auth_config)
	assert_true(karma_response.ok)
	assert_eq(_recorded_requests[5].method, "POST")
	assert_eq(_recorded_requests[5].url, "https://g-777.modapi.io/v1/games/777/mods/1001/comments/9002/karma")
	assert_eq(_recorded_requests[5].body_string, "karma=-1")
	assert_eq(_recorded_requests[5].headers.Authorization, "Bearer user-token")

func test_normalizes_rate_limit_validation_admin_server_auth_and_comment_error_cases_from_execute() -> void:
	var config := ModioClientConfig.new("777", "demo-key", "", "user-token", "en-US", "steam", "WINDOWS", ModioClientConfig.HOST_GAME)
	var transport := ModioHttpTransport.new(Callable(self, "_transport_double"))
	var adapter := ModioVendorAdapter.new(config, transport)

	_queue_json_response(429, _fixture("global_rate_limit_error.json"), {"Retry-After": "12"})
	var global_limit := transport.execute(adapter.build_terms_request(), config, {"base_url": "https://api.mod.io/v1"})
	assert_false(global_limit.ok)
	assert_eq(global_limit.retry_after_seconds, 12)
	assert_eq(global_limit.rate_limit_scope, "global")
	assert_eq(global_limit.error.category, "rate_limited")

	_queue_json_response(429, _fixture("rate_limit_error.json"), {"Retry-After": "0"})
	var endpoint_limit := transport.execute(adapter.build_terms_request(), config, {"base_url": "https://api.mod.io/v1"})
	assert_false(endpoint_limit.ok)
	assert_eq(endpoint_limit.retry_after_seconds, 60)
	assert_eq(endpoint_limit.rate_limit_scope, "endpoint")

	_queue_json_response(422, _fixture("validation_error.json"))
	var validation_error := transport.execute(adapter.build_subscribe_request("1001", true), config)
	assert_false(validation_error.ok)
	assert_eq(validation_error.error.category, "validation")
	assert_eq(validation_error.error.details.include_dependencies[0], "The include_dependencies field must be true or false.")

	_queue_json_response(403, _fixture("admin_filter_error.json"))
	var admin_error := transport.execute(adapter.build_listing_request(ModioListingQuery.new()), config, {"base_url": "https://api.mod.io/v1"})
	assert_false(admin_error.ok)
	assert_eq(admin_error.error.category, "admin_filter")
	assert_eq(admin_error.error.error_ref, 15025)

	_queue_json_response(503, _fixture("server_error.json"))
	var server_error := transport.execute(adapter.build_logout_request(), config)
	assert_false(server_error.ok)
	assert_eq(server_error.error.category, "server")

	_queue_json_response(403, _fixture("terms_required_error.json"))
	var terms_error := transport.execute(adapter.build_openid_auth_request("jwt-token", false), config, {"base_url": "https://api.mod.io/v1"})
	assert_false(terms_error.ok)
	assert_true(terms_error.error.should_retry_with_terms)
	assert_eq(terms_error.error.category, "terms_required")

	_queue_json_response(401, _fixture("auth_code_expired_error.json"))
	var auth_error := transport.execute(adapter.build_auth_exchange_request("123456"), config, {"base_url": "https://api.mod.io/v1"})
	assert_false(auth_error.ok)
	assert_eq(auth_error.error.category, "auth")

	_queue_json_response(403, _fixture("comment_restricted_error.json"))
	var restricted_comment_error := transport.execute(adapter.build_add_mod_comment_request("1001", "blocked"), config)
	assert_false(restricted_comment_error.ok)
	assert_eq(restricted_comment_error.error.category, "comments_restricted")
	assert_eq(restricted_comment_error.error.error_ref, 40004)

	_queue_json_response(400, _fixture("comment_karma_deleted_error.json"))
	var deleted_comment_error := transport.execute(adapter.build_add_mod_comment_karma_request("1001", "9002", 1), config)
	assert_false(deleted_comment_error.ok)
	assert_eq(deleted_comment_error.error.category, "conflict")
	assert_eq(deleted_comment_error.error.error_ref, 15090)

	_queue_json_response(403, _fixture("comment_karma_conflict_error.json"))
	var karma_conflict_error := transport.execute(adapter.build_add_mod_comment_karma_request("1001", "9002", 1), config)
	assert_false(karma_conflict_error.ok)
	assert_eq(karma_conflict_error.error.category, "conflict")
	assert_eq(karma_conflict_error.error.error_ref, 15059)

	_queue_json_response(403, _fixture("comment_karma_forbidden_error.json"))
	var karma_forbidden_error := transport.execute(adapter.build_add_mod_comment_karma_request("1001", "9002", 1), config)
	assert_false(karma_forbidden_error.ok)
	assert_eq(karma_forbidden_error.error.category, "forbidden")
	assert_eq(karma_forbidden_error.error.error_ref, 15055)

	_queue_json_response(403, _fixture("comment_karma_downvote_disabled_error.json"))
	var karma_downvote_disabled_error := transport.execute(adapter.build_add_mod_comment_karma_request("1001", "9002", -1), config)
	assert_false(karma_downvote_disabled_error.ok)
	assert_eq(karma_downvote_disabled_error.error.category, "forbidden")
	assert_eq(karma_downvote_disabled_error.error.error_ref, 15095)

func test_rejects_bearer_requests_without_authorization_and_does_not_retry() -> void:
	var config := ModioClientConfig.new("777", "demo-key", "", "", "en-US", "steam", "WINDOWS", ModioClientConfig.HOST_GAME)
	var transport := ModioHttpTransport.new(Callable(self, "_transport_double"))
	var adapter := ModioVendorAdapter.new(config, transport)

	var response := transport.execute(adapter.build_authenticated_user_request(), config)
	assert_false(response.ok)
	assert_eq(response.error.category, "transport")
	assert_string_contains(response.error.message, "Authorization")
	assert_eq(_recorded_requests.size(), 0)


func test_executes_catalog_game_meta_and_taxonomy_reads_with_doc_corrected_urls() -> void:
	var public_config := ModioClientConfig.new("777", "demo-key", "https://api.mod.io/v1/", "", "en-US", "steam", "WINDOWS")
	var auth_config := ModioClientConfig.new("777", "demo-key", "", "user-token", "en-US", "steam", "WINDOWS", ModioClientConfig.HOST_GAME)
	var transport := ModioHttpTransport.new(Callable(self, "_transport_double"))
	var public_adapter := ModioVendorAdapter.new(public_config, transport)
	var auth_adapter := ModioVendorAdapter.new(auth_config, transport)

	var games_query := ModioListingQuery.new("", PackedStringArray(), 3, 1, "-date_updated")
	games_query.name = "AeroBeat"
	games_query.status = 1
	games_query.submitted_by = "42"
	games_query.summary = "Rhythm workouts"
	games_query.instructions_url = "https://docs.aerobeat.example/mods"
	games_query.ugc_name = "mods"
	games_query.presentation_option = 0
	games_query.submission_option = 1
	games_query.curation_option = 2
	games_query.profanity_option = 3
	games_query.dependency_option = 2
	games_query.community_options = 258
	games_query.monetization_options = 1
	games_query.api_access_options = 7
	games_query.maturity_option = 0
	games_query.show_hidden_mods = true

	_queued_responses.append({"status_code": 200, "headers": {}, "body": JSON.stringify(_fixture("games.json"))})
	var games_response := transport.execute(public_adapter.build_games_request(games_query), public_config)
	assert_true(games_response.ok)
	assert_eq(_recorded_requests[0].url, "https://api.mod.io/v1/games?_limit=3&_offset=1&_sort=-date_updated&api_access_options=7&api_key=demo-key&community_options=258&curation_option=2&dependency_option=2&instructions_url=https%3A%2F%2Fdocs.aerobeat.example%2Fmods&maturity_options=0&monetization_options=1&name=AeroBeat&presentation_option=0&profanity_option=3&show_hidden_tags=true&status=1&submission_option=1&submitted_by=42&summary=Rhythm%20workouts&ugc_name=mods")

	_queued_responses.append({"status_code": 200, "headers": {}, "body": JSON.stringify(_fixture("game_stats.json"))})
	var game_stats_response := transport.execute(public_adapter.build_game_stats_request(), public_config)
	assert_true(game_stats_response.ok)
	assert_eq(_recorded_requests[1].url, "https://api.mod.io/v1/games/777/stats?api_key=demo-key")

	_queued_responses.append({"status_code": 200, "headers": {}, "body": JSON.stringify(_fixture("game_tags.json"))})
	var game_tags_response := transport.execute(public_adapter.build_game_tags_request("888", true), public_config)
	assert_true(game_tags_response.ok)
	assert_eq(_recorded_requests[2].url, "https://api.mod.io/v1/games/888/tags?api_key=demo-key&show_hidden_tags=true")

	var mod_stats_query := ModioListingQuery.new()
	mod_stats_query.mod_id = "1001"
	_queued_responses.append({"status_code": 200, "headers": {}, "body": JSON.stringify(_fixture("game_mod_stats.json"))})
	var game_mod_stats_response := transport.execute(public_adapter.build_game_mod_stats_request("888", mod_stats_query), public_config)
	assert_true(game_mod_stats_response.ok)
	assert_eq(_recorded_requests[3].url, "https://api.mod.io/v1/games/888/mods/stats?_limit=25&_offset=0&api_key=demo-key&mod_id=1001")

	_queued_responses.append({"status_code": 200, "headers": {}, "body": JSON.stringify(_fixture("guide_tags.json"))})
	var guide_tags_response := transport.execute(public_adapter.build_guide_tags_request("888"), public_config)
	assert_true(guide_tags_response.ok)
	assert_eq(_recorded_requests[4].url, "https://api.mod.io/v1/games/888/guides/tags?api_key=demo-key")

	_queued_responses.append({"status_code": 200, "headers": {}, "body": JSON.stringify(_fixture("agreement_version.json"))})
	var agreement_version_response := transport.execute(public_adapter.build_agreement_version_request(31), public_config)
	assert_true(agreement_version_response.ok)
	assert_eq(_recorded_requests[5].url, "https://api.mod.io/v1/agreements/versions/31?api_key=demo-key")

	_queued_responses.append({"status_code": 200, "headers": {}, "body": JSON.stringify(_fixture("game_token_packs.json"))})
	var token_packs_response := transport.execute(auth_adapter.build_game_token_packs_request("888"), auth_config)
	assert_true(token_packs_response.ok)
	assert_eq(_recorded_requests[6].url, "https://g-777.modapi.io/v1/games/888/monetization/token-packs")
	assert_eq(_recorded_requests[6].headers.Authorization, "Bearer user-token")
	assert_false(_recorded_requests[6].url.contains("api_key="))

	_queued_responses.append({"status_code": 200, "headers": {}, "body": JSON.stringify(_fixture("ping.json"))})
	var ping_response := transport.execute(public_adapter.build_ping_request(), public_config)
	assert_true(ping_response.ok)
	assert_eq(_recorded_requests[7].url, "https://api.mod.io/v1/ping")

func test_executes_guide_authoring_requests_with_documented_multipart_and_validation() -> void:
	var auth_config := ModioClientConfig.new("777", "demo-key", "", "user-token", "en-US", "steam", "WINDOWS", ModioClientConfig.HOST_GAME)
	var transport := ModioHttpTransport.new(Callable(self, "_transport_double"))
	var auth_adapter := ModioVendorAdapter.new(auth_config, transport)

	_queue_json_response(201, _fixture("guide_detail.json"), {"Location": "/games/777/guides/7001"})
	var create_response := transport.execute(auth_adapter.build_add_guide_request({
		"name": "Getting Started",
		"summary": "A practical intro guide for your first AeroBeat routine.",
		"description": "<h2>Warm up</h2><p>Keep moving.</p>",
		"logo": "@/tmp/guide.png",
		"status": 1,
		"community_options": 2048,
		"tags": ["Instructions", "Beginner"]
	}), auth_config, {"multipart_boundary": "TEST-BOUNDARY"})
	assert_true(create_response.ok)
	assert_eq(_recorded_requests[0].method, "POST")
	assert_eq(_recorded_requests[0].url, "https://g-777.modapi.io/v1/games/777/guides")
	assert_eq(_recorded_requests[0].headers.Authorization, "Bearer user-token")
	assert_eq(_recorded_requests[0].headers["Content-Type"], "multipart/form-data; boundary=TEST-BOUNDARY")
	assert_string_contains(_recorded_requests[0].body_string, 'name="name"')
	assert_string_contains(_recorded_requests[0].body_string, "Getting Started")
	assert_string_contains(_recorded_requests[0].body_string, 'name="tags[]"')
	assert_string_contains(_recorded_requests[0].body_string, "Instructions")
	assert_string_contains(_recorded_requests[0].body_string, "Beginner")
	assert_string_contains(_recorded_requests[0].body_string, "@/tmp/guide.png")

	_queue_json_response(200, _fixture("guide_detail.json"))
	var update_response := transport.execute(auth_adapter.build_update_guide_request("7001", {
		"status": 1,
		"name_id": "guide-v2",
		"url": "https://guides.example.com/aerobeat",
		"tags": []
	}), auth_config, {"multipart_boundary": "TEST-BOUNDARY"})
	assert_true(update_response.ok)
	assert_eq(_recorded_requests[1].url, "https://g-777.modapi.io/v1/games/777/guides/7001")
	assert_string_contains(_recorded_requests[1].body_string, 'name="url"')
	assert_string_contains(_recorded_requests[1].body_string, 'name="tags[]"')

	_queue_response({"status_code": 204, "headers": {}, "body": ""})
	var delete_response := transport.execute(auth_adapter.build_delete_guide_request("7001"), auth_config)
	assert_true(delete_response.ok)
	assert_eq(_recorded_requests[2].method, "DELETE")
	assert_eq(_recorded_requests[2].url, "https://g-777.modapi.io/v1/games/777/guides/7001")
	assert_eq(_recorded_requests[2].body_string, "")

	var invalid_response := transport.execute(auth_adapter.build_add_guide_request({
		"name": "Tiny",
		"summary": "short",
		"description": "desc",
		"logo": "logo.png",
		"tags": ["repeat", "repeat"]
	}), auth_config)
	assert_false(invalid_response.ok)
	assert_eq(invalid_response.error.category, "transport")
	assert_string_contains(invalid_response.error.message, "summary must be at least 20 characters")

func test_executes_collection_authoring_requests_with_documented_multipart_and_delete_form_body() -> void:
	var auth_config := ModioClientConfig.new("777", "demo-key", "", "user-token", "en-US", "steam", "WINDOWS", ModioClientConfig.HOST_GAME)
	var transport := ModioHttpTransport.new(Callable(self, "_transport_double"))
	var auth_adapter := ModioVendorAdapter.new(auth_config, transport)

	_queue_json_response(201, _fixture("collection_detail.json"), {"Location": "/games/777/collections/3001"})
	var create_response := transport.execute(auth_adapter.build_add_collection_request({
		"name": "Starter Bundle",
		"summary": "A bundle of cardio-friendly starter mods.",
		"category": 2,
		"description": "All the essentials.",
		"logo": "@/tmp/collection.png",
		"status": 1,
		"visible": 1,
		"tags": ["GAMEPLAY", "AUDIO"],
		"mod_ids": [1001, 1002]
	}), auth_config, {"multipart_boundary": "TEST-BOUNDARY"})
	assert_true(create_response.ok)
	assert_eq(_recorded_requests[0].url, "https://g-777.modapi.io/v1/games/777/collections")
	assert_eq(_recorded_requests[0].headers["Content-Type"], "multipart/form-data; boundary=TEST-BOUNDARY")
	assert_string_contains(_recorded_requests[0].body_string, 'name="mod_ids[]"')
	assert_string_contains(_recorded_requests[0].body_string, "1001")
	assert_string_contains(_recorded_requests[0].body_string, "1002")

	_queue_json_response(200, _fixture("collection_detail.json"))
	var update_response := transport.execute(auth_adapter.build_update_collection_request("3001", {
		"sync": true,
		"mod_ids": [],
		"tags": ["UI"]
	}), auth_config, {"multipart_boundary": "TEST-BOUNDARY"})
	assert_true(update_response.ok)
	assert_eq(_recorded_requests[1].url, "https://g-777.modapi.io/v1/games/777/collections/3001")
	assert_string_contains(_recorded_requests[1].body_string, 'name="sync"')
	assert_string_contains(_recorded_requests[1].body_string, "true")
	assert_string_contains(_recorded_requests[1].body_string, 'name="mod_ids[]"')

	_queue_response({"status_code": 204, "headers": {}, "body": ""})
	var delete_response := transport.execute(auth_adapter.build_delete_collection_request("3001", {"permanent": true, "reason": "Stolen Content"}), auth_config)
	assert_true(delete_response.ok)
	assert_eq(_recorded_requests[2].method, "DELETE")
	assert_eq(_recorded_requests[2].url, "https://g-777.modapi.io/v1/games/777/collections/3001")
	assert_eq(_recorded_requests[2].body_string, "permanent=true&reason=Stolen%20Content")

	var invalid_response := transport.execute(auth_adapter.build_update_collection_request("3001", {
		"tags": ["BAD"],
		"sync": "maybe"
	}), auth_config)
	assert_false(invalid_response.ok)
	assert_eq(invalid_response.error.category, "transport")
	assert_string_contains(invalid_response.error.message, "sync must be a boolean")

func _transport_double(final_request: Dictionary, _options: Dictionary) -> Dictionary:
	_recorded_requests.append(final_request.duplicate(true))
	assert_true(_queued_responses.size() > 0, "No queued transport response for request %s" % final_request.url)
	return _queued_responses.pop_front()

func _queue_json_response(status_code: int, payload: Dictionary, headers: Dictionary = {}) -> void:
	_queued_responses.append({
		"status_code": status_code,
		"headers": headers,
		"body": JSON.stringify(payload)
	})

func _queue_response(response: Dictionary) -> void:
	_queued_responses.append(response)

func _fixture(name: String) -> Dictionary:
	var path := "res://tests/fixtures/%s" % name
	var text := FileAccess.get_file_as_string(path)
	var payload = JSON.parse_string(text)
	assert_true(payload is Dictionary, "failed to parse fixture %s" % path)
	return payload
