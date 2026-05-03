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
