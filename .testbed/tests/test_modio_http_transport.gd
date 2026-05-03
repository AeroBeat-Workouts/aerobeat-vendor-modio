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

func test_normalizes_rate_limit_validation_admin_server_and_auth_error_cases_from_execute() -> void:
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

func test_rejects_bearer_requests_without_authorization_and_does_not_retry() -> void:
	var config := ModioClientConfig.new("777", "demo-key", "", "", "en-US", "steam", "WINDOWS", ModioClientConfig.HOST_GAME)
	var transport := ModioHttpTransport.new(Callable(self, "_transport_double"))
	var adapter := ModioVendorAdapter.new(config, transport)

	var response := transport.execute(adapter.build_authenticated_user_request(), config)
	assert_false(response.ok)
	assert_eq(response.error.category, "transport")
	assert_string_contains(response.error.message, "Authorization")
	assert_eq(_recorded_requests.size(), 0)

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
