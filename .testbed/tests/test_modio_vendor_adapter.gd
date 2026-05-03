extends GutTest

const ModioClientConfig = preload("res://src/models/modio_client_config.gd")
const ModioListingQuery = preload("res://src/models/modio_listing_query.gd")
const ModioDownloadRequest = preload("res://src/models/modio_download_request.gd")
const ModioHttpTransport = preload("res://src/network/modio_http_transport.gd")
const ModioVendorAdapter = preload("res://src/modio_vendor_adapter.gd")

func test_builds_email_and_external_auth_requests_with_hardened_expiry_handling() -> void:
	var adapter := _build_adapter()

	var email_request = adapter.build_email_security_code_request(" player@example.com ")
	assert_eq(email_request.method, "POST")
	assert_eq(email_request.path, "/oauth/emailrequest")
	assert_eq(email_request.body.email, "player@example.com")
	assert_eq(email_request.content_type, ModioHttpTransport.CONTENT_TYPE_FORM)
	assert_eq(email_request.auth_mode, "api_key_query")
	assert_false(email_request.query.has("api_key"))

	var past_exchange = adapter.build_auth_exchange_request(" 123456 ", 1)
	assert_false(past_exchange.body.has("date_expires"))

	var now := Time.get_unix_time_from_system()
	var too_far_exchange = adapter.build_auth_exchange_request(" 123456 ", now + 999999999)
	assert_true(int(too_far_exchange.body.date_expires) <= now + 31536000)

	var openid_request = adapter.build_openid_auth_request("jwt-token", true, "recover@example.com", now + 999999999, false, "psn-code", 1)
	assert_eq(openid_request.path, "/external/openidauth")
	assert_eq(openid_request.body.id_token, "jwt-token")
	assert_true(openid_request.body.terms_agreed)
	assert_eq(openid_request.body.email, "recover@example.com")
	assert_eq(openid_request.body.psn_token, "psn-code")
	assert_eq(openid_request.body.psn_env, "1")
	assert_true(int(openid_request.body.date_expires) <= now + 604800)

	var apple_request = adapter.build_apple_auth_request(" apple-jwt ", false, now + 999999999)
	assert_eq(apple_request.path, "/external/appleauth")
	assert_eq(apple_request.body.id_token, "apple-jwt")
	assert_false(apple_request.body.terms_agreed)
	assert_true(int(apple_request.body.date_expires) <= now + 604800)
	assert_false(apple_request.body.has("email"))

	var discord_request = adapter.build_discord_auth_request(" discord-token ", true, " discord@example.com ", now + 999999999)
	assert_eq(discord_request.path, "/external/discordauth")
	assert_eq(discord_request.body.discord_token, "discord-token")
	assert_eq(discord_request.body.email, "discord@example.com")
	assert_true(int(discord_request.body.date_expires) <= now + 604800)

	var epic_request = adapter.build_epic_games_auth_request(" epic-id-token ", true, " epic@example.com ", now + 999999999)
	assert_eq(epic_request.path, "/external/epicgamesauth")
	assert_eq(epic_request.body.id_token, "epic-id-token")
	assert_eq(epic_request.body.email, "epic@example.com")
	assert_true(int(epic_request.body.date_expires) <= now + 604800)

	var gog_request = adapter.build_gog_galaxy_auth_request(" gog-ticket ", true, " gog@example.com ", now + 999999999)
	assert_eq(gog_request.path, "/external/galaxyauth")
	assert_eq(gog_request.body.appdata, "gog-ticket")
	assert_eq(gog_request.body.email, "gog@example.com")
	assert_true(int(gog_request.body.date_expires) <= now + 604800)

	var google_auth_code_request = adapter.build_google_auth_request(" google-auth-code ", "", true, now + 999999999)
	assert_eq(google_auth_code_request.path, "/external/googleauth")
	assert_eq(google_auth_code_request.body.auth_code, "google-auth-code")
	assert_false(google_auth_code_request.body.has("id_token"))
	assert_true(int(google_auth_code_request.body.date_expires) <= now + 604800)

	var google_id_token_request = adapter.build_google_auth_request("", " google-id-token ", false)
	assert_eq(google_id_token_request.body.id_token, "google-id-token")
	assert_false(google_id_token_request.body.has("auth_code"))
	assert_false(google_id_token_request.body.has("date_expires"))

	var oculus_request = adapter.build_oculus_auth_request(" quest ", " nonce-value ", 1829770514, " access-token ", true, " vr@example.com ", now + 999999999)
	assert_eq(oculus_request.path, "/external/oculusauth")
	assert_eq(oculus_request.body.device, "quest")
	assert_eq(oculus_request.body.nonce, "nonce-value")
	assert_eq(oculus_request.body.user_id, "1829770514")
	assert_eq(oculus_request.body.access_token, "access-token")
	assert_eq(oculus_request.body.email, "vr@example.com")
	assert_true(int(oculus_request.body.date_expires) <= now + 31536000)

	var psn_request = adapter.build_psn_auth_request(" psn-auth-code ", true, " psn@example.com ", 1, now + 999999999)
	assert_eq(psn_request.path, "/external/psnauth")
	assert_eq(psn_request.body.auth_code, "psn-auth-code")
	assert_eq(psn_request.body.email, "psn@example.com")
	assert_eq(psn_request.body.env, "1")
	assert_true(int(psn_request.body.date_expires) <= now + 31536000)

	var steam_request = adapter.build_steam_auth_request(" steam-ticket ", true, " steam@example.com ", now + 999999999)
	assert_eq(steam_request.path, "/external/steamauth")
	assert_eq(steam_request.body.appdata, "steam-ticket")
	assert_eq(steam_request.body.email, "steam@example.com")
	assert_true(int(steam_request.body.date_expires) <= now + 604800)

	var switch_request = adapter.build_switch_auth_request(" switch-id-token ", true, " switch@example.com ", now + 999999999)
	assert_eq(switch_request.path, "/external/switchauth")
	assert_eq(switch_request.body.id_token, "switch-id-token")
	assert_eq(switch_request.body.email, "switch@example.com")
	assert_true(int(switch_request.body.date_expires) <= now + 31536000)

	var udt_request = adapter.build_udt_auth_request(" delegate-123 ")
	assert_eq(udt_request.path, "/external/udtauth")
	assert_eq(udt_request.headers["X-Modio-Delegation-Token"], "delegate-123")
	assert_true(udt_request.body.is_empty())

	var xbox_request = adapter.build_xbox_live_auth_request(" xbl-token ", true, " xbox@example.com ", now + 999999999)
	assert_eq(xbox_request.path, "/external/xboxauth")
	assert_eq(xbox_request.body.xbox_token, "xbl-token")
	assert_eq(xbox_request.body.email, "xbox@example.com")
	assert_true(int(xbox_request.body.date_expires) <= now + 31536000)

func test_builds_terms_and_agreement_requests_with_localization_headers() -> void:
	var adapter := _build_adapter()

	var terms_request = adapter.build_terms_request()
	assert_eq(terms_request.method, "GET")
	assert_eq(terms_request.path, "/authenticate/terms")
	assert_eq(terms_request.query.api_key, "demo-key")
	assert_eq(terms_request.headers["Accept-Language"], "en-US")
	assert_eq(terms_request.headers["X-Modio-Portal"], "steam")
	assert_eq(terms_request.headers["X-Modio-Platform"], "WINDOWS")

	var agreement_request = adapter.build_current_agreement_request(2)
	assert_eq(agreement_request.path, "/agreements/types/2/current")
	assert_eq(agreement_request.query.api_key, "demo-key")

func test_builds_browse_and_detail_requests_with_endpoint_aware_query_shapes() -> void:
	var adapter := _build_adapter()
	var query := ModioListingQuery.new(
		"boxing",
		PackedStringArray(["approved", "featured"]),
		10,
		5,
		"-downloads_total",
		PackedStringArray(["cardio"]),
		PackedStringArray(["hidden"]),
		"{\"intensity\":\"high\"}",
		{"workout_type": "cardio", "difficulty": "expert"},
		"1001",
		"cardio-blaster",
		1,
		1,
		"55"
	)

	var listing_request = adapter.build_listing_request(query)
	assert_eq(listing_request.path, "/games/777/mods")
	assert_eq(listing_request.query.api_key, "demo-key")
	assert_eq(listing_request.query._q, "boxing")
	assert_eq(listing_request.query.tags, "approved,featured")
	assert_eq(listing_request.query["tags-in"], "cardio")
	assert_eq(listing_request.query["tags-not-in"], "hidden")
	assert_eq(listing_request.query.metadata_blob, "{\"intensity\":\"high\"}")
	assert_eq(listing_request.query.metadata_kvp, "difficulty:expert,workout_type:cardio")
	assert_eq(listing_request.query._sort, "-downloads_total")
	assert_eq(listing_request.query.id, "1001")
	assert_eq(listing_request.query.name_id, "cardio-blaster")
	assert_eq(listing_request.query.status, "1")
	assert_eq(listing_request.query.visible, "1")
	assert_eq(listing_request.query.submitted_by, "55")
	assert_eq(listing_request.query._limit, "10")
	assert_eq(listing_request.query._offset, "5")

	var invalid_mod_sort_query := ModioListingQuery.new()
	invalid_mod_sort_query.sort = "-comments_total"
	var invalid_mod_sort_request = adapter.build_listing_request(invalid_mod_sort_query)
	assert_false(invalid_mod_sort_request.query.has("_sort"))

	var detail_request = adapter.build_mod_detail_request("1001")
	assert_eq(detail_request.path, "/games/777/mods/1001")

	var modfiles_request = adapter.build_modfiles_request("1001", query)
	assert_eq(modfiles_request.path, "/games/777/mods/1001/files")
	assert_eq(modfiles_request.query.id, "1001")
	assert_false(modfiles_request.query.has("_sort"))
	assert_false(modfiles_request.query.has("_q"))
	assert_false(modfiles_request.query.has("tags"))
	assert_false(modfiles_request.query.has("metadata_kvp"))
	assert_false(modfiles_request.query.has("status"))
	assert_false(modfiles_request.query.has("submitted_by"))

	var modfile_request = adapter.build_modfile_request("1001", "5002")
	assert_eq(modfile_request.path, "/games/777/mods/1001/files/5002")

	var mod_stats_request = adapter.build_mod_stats_request("1001")
	assert_eq(mod_stats_request.path, "/games/777/mods/1001/stats")

func test_builds_authenticated_subscription_requests_and_gates_unsupported_filters() -> void:
	var adapter := _build_adapter_with_token()

	var me_request = adapter.build_authenticated_user_request("delegate-123")
	assert_eq(me_request.path, "/me")
	assert_eq(me_request.headers.Authorization, "Bearer user-token")
	assert_eq(me_request.headers["X-Modio-Delegation-Token"], "delegate-123")
	assert_false(me_request.query.has("api_key"))

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
	var subscribed_request = adapter.build_user_subscriptions_request(query)
	assert_eq(subscribed_request.path, "/me/subscribed")
	assert_eq(subscribed_request.headers.Authorization, "Bearer user-token")
	assert_eq(subscribed_request.query.tags, "approved")
	assert_eq(subscribed_request.query.game_id, "777")
	assert_eq(subscribed_request.query._offset, "25")
	assert_eq(subscribed_request.query.status, "1")
	assert_eq(subscribed_request.query.visible, "1")
	assert_eq(subscribed_request.query.submitted_by, "55")

	var invalid_subscription_sort_query := ModioListingQuery.new()
	invalid_subscription_sort_query.sort = "-ratings_weighted_aggregate"
	var invalid_subscription_sort_request = adapter.build_user_subscriptions_request(invalid_subscription_sort_query)
	assert_false(invalid_subscription_sort_request.query.has("_sort"))

	var ratings_query := ModioListingQuery.new("", PackedStringArray(), 50, 0, "", PackedStringArray(), PackedStringArray(), "", {}, "", "", -1, -1, "", "777", "1001", -1, "mods", 1777800001)
	var user_ratings_request = adapter.build_user_ratings_request(ratings_query)
	assert_eq(user_ratings_request.path, "/me/ratings")
	assert_eq(user_ratings_request.headers.Authorization, "Bearer user-token")
	assert_eq(user_ratings_request.query.game_id, "777")
	assert_eq(user_ratings_request.query.mod_id, "1001")
	assert_eq(user_ratings_request.query.rating, "-1")
	assert_eq(user_ratings_request.query.resource_type, "mods")
	assert_eq(user_ratings_request.query.date_added, "1777800001")
	assert_false(user_ratings_request.query.has("api_key"))

	var default_user_ratings_request = adapter.build_user_ratings_request()
	assert_eq(default_user_ratings_request.query.resource_type, "mods")
	assert_eq(default_user_ratings_request.query.game_id, "777")

	var add_rating_request = adapter.build_add_mod_rating_request("1001", -1)
	assert_eq(add_rating_request.method, "POST")
	assert_eq(add_rating_request.path, "/games/777/mods/1001/ratings")
	assert_eq(add_rating_request.headers.Authorization, "Bearer user-token")
	assert_eq(add_rating_request.body.rating, "-1")

	var report_request = adapter.build_submit_report_request("mods", "1001", 2, "  crashes after song load  ", {
		"name": "Player One",
		"contact": "player@example.com",
		"reason": 6,
		"platforms": "windows",
		"game_name_id": "aerobeat"
	})
	assert_eq(report_request.method, "POST")
	assert_eq(report_request.path, "/report")
	assert_eq(report_request.headers.Authorization, "Bearer user-token")
	assert_eq(report_request.body.resource, "MODS")
	assert_eq(report_request.body.id, "1001")
	assert_eq(report_request.body.type, "2")
	assert_eq(report_request.body.summary, "crashes after song load")
	assert_eq(report_request.body.reason, "6")
	assert_eq(report_request.body.platforms, "WINDOWS")
	assert_eq(report_request.body.game_name_id, "aerobeat")

	var subscribe_request = adapter.build_subscribe_request("1001", true)
	assert_eq(subscribe_request.method, "POST")
	assert_eq(subscribe_request.path, "/games/777/mods/1001/subscribe")
	assert_eq(subscribe_request.headers.Authorization, "Bearer user-token")
	assert_true(subscribe_request.body.include_dependencies)

	var unsubscribe_request = adapter.build_unsubscribe_request("1001")
	assert_eq(unsubscribe_request.method, "DELETE")
	assert_eq(unsubscribe_request.path, "/games/777/mods/1001/subscribe")

	var logout_request = adapter.build_logout_request()
	assert_eq(logout_request.path, "/oauth/logout")
	assert_eq(logout_request.headers.Authorization, "Bearer user-token")

func test_builds_guide_requests_with_documented_filter_and_sort_support() -> void:
	var public_adapter := _build_adapter()
	var auth_adapter := _build_adapter_with_token()
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

	var guides_request = public_adapter.build_guides_request(guide_query)
	assert_eq(guides_request.method, "GET")
	assert_eq(guides_request.path, "/games/777/guides")
	assert_eq(guides_request.query.api_key, "demo-key")
	assert_eq(guides_request.query.id, "7001")
	assert_eq(guides_request.query.game_id, "777")
	assert_eq(guides_request.query.status, "1")
	assert_eq(guides_request.query.submitted_by, "77")
	assert_eq(guides_request.query.submitted_by_display_name, "Coach Chip")
	assert_eq(guides_request.query.date_added, "1777800001")
	assert_eq(guides_request.query.date_updated, "1777803600")
	assert_eq(guides_request.query.date_live, "1777807200")
	assert_eq(guides_request.query.name_id, "building-your-first-routine")
	assert_eq(guides_request.query.tags, "Instructions,Beginner")
	assert_eq(guides_request.query["tags-in"], "Featured")
	assert_eq(guides_request.query["tags-not-in"], "Hidden")
	assert_eq(guides_request.query._sort, "-comments_total")
	assert_eq(guides_request.query._limit, "20")
	assert_eq(guides_request.query._offset, "40")
	assert_false(guides_request.query.has("_q"))
	assert_false(guides_request.query.has("metadata_blob"))
	assert_false(guides_request.query.has("metadata_kvp"))
	assert_false(guides_request.query.has("visible"))

	var invalid_guide_sort_query := ModioListingQuery.new()
	invalid_guide_sort_query.sort = "-downloads_total"
	var invalid_guide_sort_request = public_adapter.build_guides_request(invalid_guide_sort_query)
	assert_false(invalid_guide_sort_request.query.has("_sort"))

	var guide_detail_request = public_adapter.build_guide_detail_request("7001")
	assert_eq(guide_detail_request.path, "/games/777/guides/7001")
	assert_eq(guide_detail_request.query.api_key, "demo-key")

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
	var guide_comments_request = public_adapter.build_guide_comments_request("7001", guide_comment_query)
	assert_eq(guide_comments_request.path, "/games/777/guides/7001/comments")
	assert_eq(guide_comments_request.query.id, "9902")
	assert_eq(guide_comments_request.query.resource_id, "7001")
	assert_eq(guide_comments_request.query.submitted_by, "77")
	assert_eq(guide_comments_request.query.date_added, "1777808300")
	assert_eq(guide_comments_request.query.reply_id, "9901")
	assert_eq(guide_comments_request.query.thread_position, "01.01")
	assert_eq(guide_comments_request.query.karma, "-1")
	assert_eq(guide_comments_request.query.content, "Second-level reply")
	assert_false(guide_comments_request.query.has("game_id"))
	assert_false(guide_comments_request.query.has("tags"))
	assert_false(guide_comments_request.query.has("_sort"))
	assert_false(guide_comments_request.query.has("submitted_by_display_name"))

	var create_request = auth_adapter.build_add_guide_comment_request("7001", "  Great pacing tip  ", 9901)
	assert_eq(create_request.method, "POST")
	assert_eq(create_request.path, "/games/777/guides/7001/comments")
	assert_eq(create_request.headers.Authorization, "Bearer user-token")
	assert_eq(create_request.body.content, "Great pacing tip")
	assert_eq(create_request.body.reply_id, "9901")

	var update_request = auth_adapter.build_update_guide_comment_request("7001", "9903", "  Tweaked for recovery  ")
	assert_eq(update_request.method, "PUT")
	assert_eq(update_request.path, "/games/777/guides/7001/comments/9903")
	assert_eq(update_request.body.content, "Tweaked for recovery")

	var delete_request = auth_adapter.build_delete_guide_comment_request("7001", "9903")
	assert_eq(delete_request.method, "DELETE")
	assert_eq(delete_request.path, "/games/777/guides/7001/comments/9903")

	var karma_request = auth_adapter.build_add_guide_comment_karma_request("7001", "9902", -99)
	assert_eq(karma_request.method, "POST")
	assert_eq(karma_request.path, "/games/777/guides/7001/comments/9902/karma")
	assert_eq(karma_request.body.karma, "-1")

func test_builds_collection_requests_with_documented_filter_and_sort_support() -> void:
	var public_adapter := _build_adapter()
	var auth_adapter := _build_adapter_with_token()
	var collection_query := ModioListingQuery.new()
	collection_query.search_term = "ignored-search"
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
	collection_query.metadata_blob = "ignored-metadata"
	collection_query.metadata_kvp = {"ignored": "pair"}
	collection_query.visible = 1

	var collections_request = public_adapter.build_collections_request(collection_query)
	assert_eq(collections_request.method, "GET")
	assert_eq(collections_request.path, "/games/777/collections")
	assert_eq(collections_request.query.api_key, "demo-key")
	assert_eq(collections_request.query.id, "3001")
	assert_eq(collections_request.query.status, "1")
	assert_eq(collections_request.query.mod_id, "1001")
	assert_eq(collections_request.query.category, "Cardio")
	assert_eq(collections_request.query.submitted_by, "42")
	assert_eq(collections_request.query.submitted_by_display_name, "Coach Chip")
	assert_eq(collections_request.query.date_added, "1777800001")
	assert_eq(collections_request.query.date_updated, "1777803600")
	assert_eq(collections_request.query.date_live, "1777807200")
	assert_eq(collections_request.query.name, "Starter Bundle")
	assert_eq(collections_request.query.name_id, "starter-bundle")
	assert_eq(collections_request.query.maturity_option, "4")
	assert_eq(collections_request.query.tags, "GAMEPLAY,QUALITY_OF_LIFE")
	assert_eq(collections_request.query["tags-in"], "VISUAL")
	assert_eq(collections_request.query["tags-not-in"], "BUGFIXES")
	assert_eq(collections_request.query._sort, "-date_updated")
	assert_eq(collections_request.query._limit, "12")
	assert_eq(collections_request.query._offset, "24")
	assert_false(collections_request.query.has("_q"))
	assert_false(collections_request.query.has("metadata_blob"))
	assert_false(collections_request.query.has("metadata_kvp"))
	assert_false(collections_request.query.has("visible"))

	var invalid_collection_sort_query := ModioListingQuery.new()
	invalid_collection_sort_query.sort = "-downloads_total"
	var invalid_collection_sort_request = public_adapter.build_collections_request(invalid_collection_sort_query)
	assert_false(invalid_collection_sort_request.query.has("_sort"))

	var collection_detail_request = public_adapter.build_collection_request("3001")
	assert_eq(collection_detail_request.path, "/games/777/collections/3001")
	assert_eq(collection_detail_request.query.api_key, "demo-key")

	var collection_mods_query := ModioListingQuery.new()
	collection_mods_query.search_term = "ignored-search"
	collection_mods_query.tags_all = PackedStringArray(["ignored-tag"])
	collection_mods_query.limit = 5
	collection_mods_query.offset = 10
	collection_mods_query.sort = "-downloads_total"
	collection_mods_query.maturity_option = 8
	collection_mods_query.show_hidden_mods = true
	collection_mods_query.status = 1
	var collection_mods_request = public_adapter.build_collection_mods_request("3001", collection_mods_query)
	assert_eq(collection_mods_request.path, "/games/777/collections/3001/mods")
	assert_eq(collection_mods_request.query._limit, "5")
	assert_eq(collection_mods_request.query._offset, "10")
	assert_eq(collection_mods_request.query._sort, "-downloads_total")
	assert_eq(collection_mods_request.query.maturity_option, "8")
	assert_true(collection_mods_request.query.show_hidden_mods)
	assert_false(collection_mods_request.query.has("_q"))
	assert_false(collection_mods_request.query.has("tags"))
	assert_false(collection_mods_request.query.has("status"))

	var invalid_collection_mod_sort_query := ModioListingQuery.new()
	invalid_collection_mod_sort_query.sort = "-ratings_weighted_aggregate"
	var invalid_collection_mod_sort_request = public_adapter.build_collection_mods_request("3001", invalid_collection_mod_sort_query)
	assert_false(invalid_collection_mod_sort_request.query.has("_sort"))

	var collection_comment_query := ModioListingQuery.new()
	collection_comment_query.search_term = "ignored-search"
	collection_comment_query.tags_all = PackedStringArray(["ignored-tag"])
	collection_comment_query.limit = 15
	collection_comment_query.offset = 30
	collection_comment_query.sort = "ignored-sort"
	collection_comment_query.id = "9902"
	collection_comment_query.resource_id = "3001"
	collection_comment_query.submitted_by = "77"
	collection_comment_query.date_added = 1777801600
	collection_comment_query.reply_id = 9901
	collection_comment_query.thread_position = "01.01"
	collection_comment_query.karma = -1
	collection_comment_query.content = "Collection reply"
	collection_comment_query.submitted_by_display_name = "ignored-display-name"
	collection_comment_query.category = "ignored-category"
	var collection_comments_request = public_adapter.build_collection_comments_request("3001", collection_comment_query)
	assert_eq(collection_comments_request.path, "/games/777/collections/3001/comments")
	assert_eq(collection_comments_request.query.id, "9902")
	assert_eq(collection_comments_request.query.resource_id, "3001")
	assert_eq(collection_comments_request.query.submitted_by, "77")
	assert_eq(collection_comments_request.query.date_added, "1777801600")
	assert_eq(collection_comments_request.query.reply_id, "9901")
	assert_eq(collection_comments_request.query.thread_position, "01.01")
	assert_eq(collection_comments_request.query.karma, "-1")
	assert_eq(collection_comments_request.query.content, "Collection reply")
	assert_eq(collection_comments_request.query._limit, "15")
	assert_eq(collection_comments_request.query._offset, "30")
	assert_false(collection_comments_request.query.has("_q"))
	assert_false(collection_comments_request.query.has("tags"))
	assert_false(collection_comments_request.query.has("_sort"))
	assert_false(collection_comments_request.query.has("submitted_by_display_name"))
	assert_false(collection_comments_request.query.has("category"))

	var collection_comment_detail_request = public_adapter.build_collection_comment_request("3001", "9902")
	assert_eq(collection_comment_detail_request.path, "/games/777/collections/3001/comments/9902")

	var create_request = auth_adapter.build_add_collection_comment_request("3001", "  Fresh collection reply  ", 9901)
	assert_eq(create_request.method, "POST")
	assert_eq(create_request.path, "/games/777/collections/3001/comments")
	assert_eq(create_request.headers.Authorization, "Bearer user-token")
	assert_eq(create_request.body.content, "Fresh collection reply")
	assert_eq(create_request.body.reply_id, "9901")

	var update_request = auth_adapter.build_update_collection_comment_request("3001", "9902", "  Collection reply edited for clarity  ")
	assert_eq(update_request.method, "PUT")
	assert_eq(update_request.path, "/games/777/collections/3001/comments/9902")
	assert_eq(update_request.body.content, "Collection reply edited for clarity")

	var delete_request = auth_adapter.build_delete_collection_comment_request("3001", "9902")
	assert_eq(delete_request.method, "DELETE")
	assert_eq(delete_request.path, "/games/777/collections/3001/comments/9902")

	var karma_request = auth_adapter.build_add_collection_comment_karma_request("3001", "9902", -999)
	assert_eq(karma_request.method, "POST")
	assert_eq(karma_request.path, "/games/777/collections/3001/comments/9902/karma")
	assert_eq(karma_request.body.karma, "-1")

	var compatibility_request = auth_adapter.build_add_collection_compatibility_request("3001", 99)
	assert_eq(compatibility_request.method, "POST")
	assert_eq(compatibility_request.path, "/games/777/collections/3001/compatibility")
	assert_eq(compatibility_request.headers.Authorization, "Bearer user-token")
	assert_eq(compatibility_request.body.rating, "1")

func test_builds_user_inventory_requests_with_documented_authenticated_query_shapes() -> void:
	var auth_adapter := _build_adapter_with_token()

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

	var user_games_request = auth_adapter.build_user_games_request(games_query)
	assert_eq(user_games_request.method, "GET")
	assert_eq(user_games_request.path, "/me/games")
	assert_eq(user_games_request.auth_mode, "bearer")
	assert_eq(user_games_request.headers.Authorization, "Bearer user-token")
	assert_eq(user_games_request.query._limit, "6")
	assert_eq(user_games_request.query._offset, "12")
	assert_eq(user_games_request.query._sort, "-date_updated")
	assert_eq(user_games_request.query.name, "AeroBeat")
	assert_eq(user_games_request.query.summary, "Rhythm workouts")
	assert_eq(user_games_request.query.instructions_url, "https://docs.aerobeat.example/mods")
	assert_eq(user_games_request.query.ugc_name, "mods")
	assert_eq(user_games_request.query.presentation_option, "0")
	assert_eq(user_games_request.query.submission_option, "1")
	assert_eq(user_games_request.query.curation_option, "2")
	assert_eq(user_games_request.query.profanity_option, "3")
	assert_eq(user_games_request.query.dependency_option, "2")
	assert_eq(user_games_request.query.community_options, "258")
	assert_eq(user_games_request.query.monetization_options, "1")
	assert_eq(user_games_request.query.api_access_options, "7")
	assert_eq(user_games_request.query.maturity_options, "0")
	assert_true(user_games_request.query.show_hidden_tags)
	assert_false(user_games_request.query.has("api_key"))
	assert_false(user_games_request.query.has("_q"))

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
	user_mods_query.search_term = "ignored-search"
	user_mods_query.tags_any = PackedStringArray(["ignored-tag"])
	user_mods_query.tags_not_in = PackedStringArray(["ignored-tag"])

	var user_mods_request = auth_adapter.build_user_mods_request(user_mods_query)
	assert_eq(user_mods_request.path, "/me/mods")
	assert_eq(user_mods_request.auth_mode, "bearer")
	assert_eq(user_mods_request.headers.Authorization, "Bearer user-token")
	assert_eq(user_mods_request.query.tags, "Featured,Cardio")
	assert_eq(user_mods_request.query.metadata_kvp, "difficulty:expert,workout_type:cardio")
	assert_eq(user_mods_request.query.modfile, "5002")
	assert_eq(user_mods_request.query.platform_status, "live_and_pending")
	assert_eq(user_mods_request.query._sort, "-downloads_total")
	assert_false(user_mods_request.query.has("api_key"))
	assert_false(user_mods_request.query.has("_q"))
	assert_false(user_mods_request.query.has("tags-in"))
	assert_false(user_mods_request.query.has("tags-not-in"))

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
	user_modfiles_query.sort = "-date_updated"

	var user_modfiles_request = auth_adapter.build_user_modfiles_request(user_modfiles_query)
	assert_eq(user_modfiles_request.path, "/me/files")
	assert_eq(user_modfiles_request.auth_mode, "bearer")
	assert_eq(user_modfiles_request.headers.Authorization, "Bearer user-token")
	assert_eq(user_modfiles_request.query.id, "5002")
	assert_eq(user_modfiles_request.query.mod_id, "1001")
	assert_eq(user_modfiles_request.query.date_scanned, "1777801800")
	assert_eq(user_modfiles_request.query.virus_status, "1")
	assert_eq(user_modfiles_request.query.virus_positive, "0")
	assert_eq(user_modfiles_request.query.filesize, "15181")
	assert_eq(user_modfiles_request.query.filehash, "2d4a0e2d7273db6b0a94b0740a88ad0d")
	assert_eq(user_modfiles_request.query.filename, "cardio-blaster-v1.zip")
	assert_eq(user_modfiles_request.query.version, "1.3")
	assert_eq(user_modfiles_request.query.changelog, "Fixed stamina desync")
	assert_eq(user_modfiles_request.query.platform_status, "approved_only")
	assert_false(user_modfiles_request.query.has("api_key"))
	assert_false(user_modfiles_request.query.has("_sort"))

func test_builds_user_social_and_account_state_requests_with_paging_only_query_shapes() -> void:
	var public_adapter := _build_adapter()
	var auth_adapter := _build_adapter_with_token()
	var query := ModioListingQuery.new()
	query.limit = 40
	query.offset = 80
	query.sort = "-date_updated"
	query.search_term = "ignored-search"
	query.tags_all = PackedStringArray(["ignored-tag"])
	query.id = "9001"
	query.submitted_by = "42"

	var user_followers_request = public_adapter.build_user_followers_request("42", query)
	assert_eq(user_followers_request.method, "GET")
	assert_eq(user_followers_request.path, "/users/42/followers")
	assert_eq(user_followers_request.auth_mode, "api_key_fallback")
	assert_eq(user_followers_request.query.api_key, "demo-key")
	assert_eq(user_followers_request.query._limit, "40")
	assert_eq(user_followers_request.query._offset, "80")
	assert_false(user_followers_request.query.has("_sort"))
	assert_false(user_followers_request.query.has("_q"))
	assert_false(user_followers_request.query.has("tags"))
	assert_false(user_followers_request.query.has("id"))

	var auth_user_followers_request = auth_adapter.build_user_followers_request("42", query)
	assert_eq(auth_user_followers_request.auth_mode, "api_key_fallback")
	assert_eq(auth_user_followers_request.headers.Authorization, "Bearer user-token")

	var user_following_request = public_adapter.build_user_following_request("42", query)
	assert_eq(user_following_request.path, "/users/42/following")
	assert_eq(user_following_request.auth_mode, "api_key_fallback")
	assert_eq(user_following_request.query._limit, "40")
	assert_eq(user_following_request.query._offset, "80")
	assert_false(user_following_request.query.has("submitted_by"))

	var auth_user_following_request = auth_adapter.build_user_following_request("42", query)
	assert_eq(auth_user_following_request.headers.Authorization, "Bearer user-token")

	var user_collections_request = public_adapter.build_user_collections_request("42", query)
	assert_eq(user_collections_request.path, "/users/42/collections")
	assert_eq(user_collections_request.auth_mode, "api_key_fallback")
	assert_eq(user_collections_request.query._limit, "40")
	assert_eq(user_collections_request.query._offset, "80")
	assert_false(user_collections_request.query.has("_sort"))
	assert_false(user_collections_request.query.has("id"))

	var auth_user_collections_request = auth_adapter.build_user_collections_request("42", query)
	assert_eq(auth_user_collections_request.headers.Authorization, "Bearer user-token")

	var me_followers_request = auth_adapter.build_me_followers_request(query)
	assert_eq(me_followers_request.path, "/me/followers")
	assert_eq(me_followers_request.auth_mode, "bearer")
	assert_eq(me_followers_request.headers.Authorization, "Bearer user-token")
	assert_eq(me_followers_request.query._limit, "40")
	assert_eq(me_followers_request.query._offset, "80")
	assert_false(me_followers_request.query.has("api_key"))
	assert_false(me_followers_request.query.has("_sort"))

	var muted_users_request = auth_adapter.build_muted_users_request(query)
	assert_eq(muted_users_request.path, "/me/users/muted")
	assert_eq(muted_users_request.headers.Authorization, "Bearer user-token")
	assert_eq(muted_users_request.query._limit, "40")
	assert_eq(muted_users_request.query._offset, "80")
	assert_false(muted_users_request.query.has("_q"))

	var me_collections_request = auth_adapter.build_me_collections_request(query)
	assert_eq(me_collections_request.path, "/me/collections")
	assert_eq(me_collections_request.headers.Authorization, "Bearer user-token")
	assert_eq(me_collections_request.query._limit, "40")
	assert_eq(me_collections_request.query._offset, "80")
	assert_false(me_collections_request.query.has("tags"))

	var followed_collections_request = auth_adapter.build_followed_collections_request(query)
	assert_eq(followed_collections_request.path, "/me/following/collections")
	assert_eq(followed_collections_request.headers.Authorization, "Bearer user-token")
	assert_eq(followed_collections_request.query._limit, "40")
	assert_eq(followed_collections_request.query._offset, "80")
	assert_false(followed_collections_request.query.has("submitted_by"))

	var follow_user_request = auth_adapter.build_follow_user_request("42", "55")
	assert_eq(follow_user_request.method, "POST")
	assert_eq(follow_user_request.path, "/users/42/following")
	assert_eq(follow_user_request.headers.Authorization, "Bearer user-token")
	assert_eq(follow_user_request.body.user_id, "55")

	var unfollow_user_request = auth_adapter.build_unfollow_user_request("42", "55")
	assert_eq(unfollow_user_request.method, "DELETE")
	assert_eq(unfollow_user_request.path, "/users/42/following/55")
	assert_eq(unfollow_user_request.headers.Authorization, "Bearer user-token")

	var mute_user_request = auth_adapter.build_mute_user_request("42")
	assert_eq(mute_user_request.method, "POST")
	assert_eq(mute_user_request.path, "/users/42/mute")
	assert_eq(mute_user_request.headers.Authorization, "Bearer user-token")

	var unmute_user_request = auth_adapter.build_unmute_user_request("42")
	assert_eq(unmute_user_request.method, "DELETE")
	assert_eq(unmute_user_request.path, "/users/42/mute")
	assert_eq(unmute_user_request.headers.Authorization, "Bearer user-token")

	var follow_collection_request = auth_adapter.build_follow_collection_request("3001")
	assert_eq(follow_collection_request.method, "POST")
	assert_eq(follow_collection_request.path, "/games/777/collections/3001/followers")
	assert_eq(follow_collection_request.headers.Authorization, "Bearer user-token")

	var unfollow_collection_request = auth_adapter.build_unfollow_collection_request("3001")
	assert_eq(unfollow_collection_request.method, "DELETE")
	assert_eq(unfollow_collection_request.path, "/games/777/collections/3001/followers")
	assert_eq(unfollow_collection_request.headers.Authorization, "Bearer user-token")

func test_normalizes_user_inventory_fixture_payloads() -> void:
	var adapter := _build_adapter_with_token()

	var user_games := adapter.normalize_user_games_response(_fixture("games.json"))
	assert_eq(user_games.result_total, 2)
	assert_eq(user_games.data[0].name, "AeroBeat")
	assert_true(user_games.data[0].download_policy.requires_authenticated_download)

	var user_mods := adapter.normalize_user_mods_response(_fixture("mods.json"))
	assert_eq(user_mods.result_total, 13)
	assert_eq(user_mods.data[0].name_id, "cardio-blaster")
	assert_eq(user_mods.data[0].modfile.id, 5001)

	var user_modfiles := adapter.normalize_user_modfiles_response(_fixture("modfiles.json"))
	assert_eq(user_modfiles.result_total, 1)
	assert_eq(user_modfiles.data[0].filename, "cardio-blaster-v1.zip")
	assert_true(user_modfiles.data[0].download.is_expiring)

func test_normalizes_user_social_and_account_state_fixture_payloads() -> void:
	var adapter := _build_adapter_with_token()

	var user_followers := adapter.normalize_user_followers_response(_fixture("user_social_users.json"))
	assert_eq(user_followers.result_total, 9)
	assert_eq(user_followers.page.next_offset, 7)
	assert_eq(user_followers.page.previous_offset, 3)
	assert_eq(user_followers.data[0].username, "Designer Dash")
	assert_eq(user_followers.data[1].display_name_portal, null)

	var user_following := adapter.normalize_user_following_response(_fixture("user_social_users.json"))
	assert_eq(user_following.data[1].name_id, "runner-rhythm")

	var me_followers := adapter.normalize_me_followers_response(_fixture("user_social_users.json"))
	assert_true(me_followers.page.has_next)
	assert_true(me_followers.page.has_previous)

	var muted_users := adapter.normalize_muted_users_response(_fixture("user_social_users.json"))
	assert_eq(muted_users.data[0].avatar.filename, "dash.png")

	var user_collections := adapter.normalize_user_collections_response(_fixture("collections.json"))
	assert_eq(user_collections.data[0].name, "Starter Bundle")
	assert_eq(user_collections.data[0].stats.followers_total, 120)

	var me_collections := adapter.normalize_me_collections_response(_fixture("collections.json"))
	assert_eq(me_collections.data[1].name_id, "advanced-bundle")

	var followed_collections := adapter.normalize_followed_collections_response(_fixture("collections.json"))
	assert_true(followed_collections.page.has_next)

func test_builds_mod_comment_requests_with_doc_gated_filters_and_auth_modes() -> void:
	var public_adapter := _build_adapter()
	var auth_adapter := _build_adapter_with_token()
	var comment_query := ModioListingQuery.new(
		"should_not_serialize",
		PackedStringArray(["approved"]),
		15,
		30,
		"thread_position",
		PackedStringArray(["cardio"]),
		PackedStringArray(["hidden"]),
		"{\"intensity\":\"high\"}",
		{"workout_type": "cardio"},
		"9002",
		"also_ignored",
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

	var comments_request = public_adapter.build_mod_comments_request("1001", comment_query)
	assert_eq(comments_request.method, "GET")
	assert_eq(comments_request.path, "/games/777/mods/1001/comments")
	assert_eq(comments_request.auth_mode, "api_key_query")
	assert_eq(comments_request.query.api_key, "demo-key")
	assert_eq(comments_request.query.id, "9002")
	assert_eq(comments_request.query.mod_id, "1001")
	assert_eq(comments_request.query.resource_id, "1001")
	assert_eq(comments_request.query.submitted_by, "77")
	assert_eq(comments_request.query.date_added, "1777801300")
	assert_eq(comments_request.query.reply_id, "9001")
	assert_eq(comments_request.query.thread_position, "01.01")
	assert_eq(comments_request.query.karma, "-1")
	assert_eq(comments_request.query.content, "Second-level reply")
	assert_eq(comments_request.query._limit, "15")
	assert_eq(comments_request.query._offset, "30")
	assert_false(comments_request.query.has("_q"))
	assert_false(comments_request.query.has("tags"))
	assert_false(comments_request.query.has("tags-in"))
	assert_false(comments_request.query.has("tags-not-in"))
	assert_false(comments_request.query.has("metadata_blob"))
	assert_false(comments_request.query.has("metadata_kvp"))
	assert_false(comments_request.query.has("_sort"))
	assert_false(comments_request.query.has("status"))
	assert_false(comments_request.query.has("visible"))
	assert_false(comments_request.query.has("name_id"))

	var detail_request = public_adapter.build_mod_comment_request("1001", "9002")
	assert_eq(detail_request.path, "/games/777/mods/1001/comments/9002")
	assert_eq(detail_request.query.api_key, "demo-key")

	var create_request = auth_adapter.build_add_mod_comment_request("1001", "  Fresh reply from the wrapper  ", 9001)
	assert_eq(create_request.method, "POST")
	assert_eq(create_request.path, "/games/777/mods/1001/comments")
	assert_eq(create_request.headers.Authorization, "Bearer user-token")
	assert_eq(create_request.body.content, "Fresh reply from the wrapper")
	assert_eq(create_request.body.reply_id, "9001")

	var update_request = auth_adapter.build_update_mod_comment_request("1001", "9010", "  Edited reply from the wrapper  ")
	assert_eq(update_request.method, "PUT")
	assert_eq(update_request.path, "/games/777/mods/1001/comments/9010")
	assert_eq(update_request.headers.Authorization, "Bearer user-token")
	assert_eq(update_request.body.content, "Edited reply from the wrapper")

	var delete_request = auth_adapter.build_delete_mod_comment_request("1001", "9010")
	assert_eq(delete_request.method, "DELETE")
	assert_eq(delete_request.path, "/games/777/mods/1001/comments/9010")
	assert_eq(delete_request.headers.Authorization, "Bearer user-token")

	var karma_request = auth_adapter.build_add_mod_comment_karma_request("1001", "9002", -999)
	assert_eq(karma_request.method, "POST")
	assert_eq(karma_request.path, "/games/777/mods/1001/comments/9002/karma")
	assert_eq(karma_request.headers.Authorization, "Bearer user-token")
	assert_eq(karma_request.body.karma, "-1")

func test_builds_dependency_requests_and_normalizes_recursive_dependency_payloads() -> void:
	var adapter := _build_adapter()

	var immediate_request = adapter.build_dependencies_request("1001")
	assert_eq(immediate_request.path, "/games/777/mods/1001/dependencies")
	assert_eq(immediate_request.query.api_key, "demo-key")
	assert_false(immediate_request.query.recursive)

	var recursive_request = adapter.build_dependencies_request("1001", true)
	assert_true(recursive_request.query.recursive)

	var normalized_dependencies = adapter.normalize_dependencies_response(_fixture("dependencies_recursive.json"), true)
	assert_eq(normalized_dependencies.data.size(), 2)
	assert_true(normalized_dependencies.resolution.recursive_requested)
	assert_eq(normalized_dependencies.resolution.policy, ModioVendorAdapter.DEPENDENCY_POLICY_RECURSIVE)
	assert_eq(normalized_dependencies.data[0].dependency_depth, 0)
	assert_eq(normalized_dependencies.data[1].dependency_depth, 1)

	var artifact_resolution = adapter.resolve_artifact_records_from_dependencies("1001", _fixture("dependencies_recursive.json"), _fixture("game.json"), true)
	assert_eq(artifact_resolution.artifacts.size(), 2)
	assert_eq(artifact_resolution.resolution.parent_mod_id, "1001")
	assert_eq(artifact_resolution.artifacts[0].dependency.policy, ModioVendorAdapter.DEPENDENCY_POLICY_RECURSIVE)
	assert_eq(artifact_resolution.artifacts[1].dependency.dependency_depth, 1)
	assert_true(artifact_resolution.artifacts[0].game_policy.requires_authenticated_download)

func test_builds_mod_adjacent_read_enrichment_requests_with_documented_filter_support() -> void:
	var adapter := _build_adapter()

	var dependant_query := ModioListingQuery.new()
	dependant_query.limit = 12
	dependant_query.offset = 24
	dependant_query.search_term = "ignored-search"
	var dependants_request = adapter.build_dependants_request("1001", dependant_query)
	assert_eq(dependants_request.path, "/games/777/mods/1001/dependants")
	assert_eq(dependants_request.query.api_key, "demo-key")
	assert_eq(dependants_request.query._limit, "12")
	assert_eq(dependants_request.query._offset, "24")
	assert_false(dependants_request.query.has("_q"))
	assert_false(dependants_request.query.has("tags"))

	var tags_query := ModioListingQuery.new()
	tags_query.limit = 15
	tags_query.offset = 30
	tags_query.tag = "Featured"
	tags_query.date_added = 1777800001
	tags_query.sort = "-date_updated"
	tags_query.tags_all = PackedStringArray(["ignored-tag"])
	var tags_request = adapter.build_mod_tags_request("1001", tags_query)
	assert_eq(tags_request.path, "/games/777/mods/1001/tags")
	assert_eq(tags_request.query.tag, "Featured")
	assert_eq(tags_request.query.date_added, "1777800001")
	assert_eq(tags_request.query._limit, "15")
	assert_eq(tags_request.query._offset, "30")
	assert_false(tags_request.query.has("_sort"))
	assert_false(tags_request.query.has("tags"))

	var metadata_query := ModioListingQuery.new()
	metadata_query.limit = 8
	metadata_query.offset = 16
	metadata_query.metadata_kvp = {"ignored": "pair"}
	metadata_query.search_term = "ignored-search"
	var metadata_request = adapter.build_mod_metadata_kvp_request("1001", metadata_query)
	assert_eq(metadata_request.path, "/games/777/mods/1001/metadatakvp")
	assert_eq(metadata_request.query._limit, "8")
	assert_eq(metadata_request.query._offset, "16")
	assert_false(metadata_request.query.has("metadata_kvp"))
	assert_false(metadata_request.query.has("_q"))

	var team_query := ModioListingQuery.new()
	team_query.limit = 20
	team_query.offset = 40
	team_query.id = "457"
	team_query.user_id = "42"
	team_query.username = "Coach Chip"
	team_query.level = 8
	team_query.date_added = 1777801000
	team_query.pending = 1
	team_query.submitted_by = "ignored-user"
	var team_request = adapter.build_mod_team_request("1001", team_query)
	assert_eq(team_request.path, "/games/777/mods/1001/team")
	assert_eq(team_request.query.id, "457")
	assert_eq(team_request.query.user_id, "42")
	assert_eq(team_request.query.username, "Coach Chip")
	assert_eq(team_request.query.level, "8")
	assert_eq(team_request.query.date_added, "1777801000")
	assert_eq(team_request.query.pending, "1")
	assert_eq(team_request.query._limit, "20")
	assert_eq(team_request.query._offset, "40")
	assert_false(team_request.query.has("submitted_by"))

func test_normalizes_mod_adjacent_read_enrichment_fixture_payloads() -> void:
	var adapter := _build_adapter()

	var dependants = adapter.normalize_dependants_response(_fixture("mod_dependants.json"))
	assert_eq(dependants.result_total, 4)
	assert_true(dependants.page.has_next)
	assert_eq(dependants.data[0].mod_id, 2101)
	assert_eq(dependants.data[1].visible, 0)
	assert_eq(dependants.data[0].logo.thumb_320x180, "https://assets.modcdn.io/images/mods/cardio-remix_320x180.png")

	var mod_tags = adapter.normalize_mod_tags_response(_fixture("mod_tags.json"))
	assert_eq(mod_tags.data[0].name, "Featured")
	assert_eq(mod_tags.data[1].name_localized, "Debutant")
	assert_eq(mod_tags.page.page_count, 1)

	var metadata = adapter.normalize_mod_metadata_kvp_response(_fixture("mod_metadata_kvp.json"))
	assert_eq(metadata.data[0].metakey, "difficulty")
	assert_eq(metadata.data[1].metavalue, "cardio")

	var team = adapter.normalize_mod_team_response(_fixture("mod_team.json"))
	assert_eq(team.data[0].level, 8)
	assert_eq(team.data[0].user.username, "Coach Chip")
	assert_false(team.data[0].is_pending)
	assert_true(team.data[1].is_pending)
	assert_eq(team.data[1].position, "Moderator")

func test_normalizes_fixture_payloads_for_richer_slice() -> void:
	var adapter := _build_adapter_with_token()

	var token = adapter.normalize_access_token_response(_fixture("access_token.json"))
	assert_eq(token.access_token, "ey-demo-token")
	assert_eq(token.date_expires, 1777777777)
	assert_eq(token.expires_at, 1777777777)
	assert_true(token.has_expiry)

	var terms = adapter.normalize_terms_response(_fixture("terms.json"))
	assert_eq(terms.buttons.agree.text, "I Agree")
	assert_true(terms.links.terms.required)
	assert_eq(terms.links.manage.url, "https://mod.io/me/account")

	var agreement = adapter.normalize_agreement_response(_fixture("agreement_current.json"))
	assert_eq(agreement.name, "Privacy Policy")
	assert_true(agreement.is_latest)
	assert_eq(agreement.type, 2)
	assert_eq(agreement.adjacent_versions.next.id, 31)
	assert_string_contains(agreement.description, "Privacy Agreement")

	var me = adapter.normalize_authenticated_user_response(_fixture("me.json"))
	assert_eq(me.id, 42)
	assert_eq(me.username, "AeroBeatPlayer")
	assert_eq(me.country, "US")
	assert_true(me.is_authenticated)

	var game = adapter.normalize_game_response(_fixture("game.json"))
	assert_eq(game.id, 777)
	assert_eq(game.api_access_options, 7)
	assert_eq(game.dependency_option, 2)
	assert_eq(game.download_policy.dependency_mode, "allow_opt_out")
	assert_true(game.download_policy.allows_direct_downloads)
	assert_true(game.download_policy.requires_authenticated_download)
	assert_false(game.download_policy.requires_entitlement_download)
	assert_true(game.community_policy.allows_mod_comments)
	assert_false(game.community_policy.allows_dependencies)
	assert_false(game.community_policy.allows_negative_ratings)
	assert_eq(game.tag_options[0].name, "Difficulty")
	assert_eq(game.platforms[0].platform, "WINDOWS")
	assert_eq(game.theme.primary, "#101820")
	assert_eq(game.theme.dark, "#17242f")
	assert_eq(game.stats.game_id, 777)
	assert_eq(game.stats.mods_count_total, 44)
	assert_eq(game.stats.mods_subscribers_total, 2301)

	var games = adapter.normalize_games_response(_fixture("games.json"))
	assert_eq(games.result_total, 2)
	assert_eq(games.data[1].name_id, "aerobeat-trials")
	assert_true(games.data[0].stats.has_expiry)

	var game_stats = adapter.normalize_game_stats_response(_fixture("game_stats.json"))
	assert_eq(game_stats.mods_downloads_total, 2048)
	assert_true(game_stats.has_expiry)
	assert_false(game_stats.is_stale)

	var game_tags = adapter.normalize_game_tags_response(_fixture("game_tags.json"))
	assert_eq(game_tags.result_total, 1)
	assert_eq(game_tags.data[0].name_localization.fr, "Difficulte")
	assert_eq(game_tags.data[0].tags_localization[0].translations.fr, "Debutant")

	var token_packs = adapter.normalize_game_token_packs_response(_fixture("game_token_packs.json"))
	assert_eq(token_packs.data.size(), 2)
	assert_eq(token_packs.data[0].sku, "AEROBEAT_TOKEN_PACK_A")

	var game_mod_stats = adapter.normalize_game_mod_stats_response(_fixture("game_mod_stats.json"))
	assert_eq(game_mod_stats.result_total, 2)
	assert_eq(game_mod_stats.data[0].mod_id, 1001)
	assert_eq(game_mod_stats.data[1].ratings_display_text, "Positive")

	var guide_tags = adapter.normalize_guide_tags_response(_fixture("guide_tags.json"))
	assert_eq(guide_tags.data[0].count, 8)
	assert_eq(guide_tags.data[1].name, "Beginner")

	var agreement_version = adapter.normalize_agreement_version_response(_fixture("agreement_version.json"))
	assert_eq(agreement_version.id, 31)
	assert_eq(agreement_version.adjacent_versions.previous.id, 13)

	var ping = adapter.normalize_ping_response(_fixture("ping.json"))
	assert_true(ping.success)
	assert_eq(ping.message, "mod.io API reachable")

	var mods = adapter.normalize_mod_list_response(_fixture("mods.json"))
	assert_eq(mods.result_offset, 5)
	assert_true(mods.page.has_next)
	assert_eq(mods.page.next_offset, 6)
	assert_eq(mods.page.page_index, 0)
	assert_eq(mods.data[0].name_id, "cardio-blaster")
	assert_eq(mods.data[0].stats.downloads_total, 1024)
	assert_eq(mods.data[0].community_options, 1025)
	assert_true(mods.data[0].community_policy.allows_comments)
	assert_eq(mods.data[0].logo.thumb_320x180, "https://assets.modcdn.io/images/rogue/card_320x180.png")
	assert_eq(mods.data[0].submitted_by.avatar.filename, "avatar.png")

	var mod_detail = adapter.normalize_mod_detail_response(_fixture("mod_detail.json"))
	assert_eq(mod_detail.modfile.id, 5001)
	assert_eq(mod_detail.tags[1].name, "Expert")
	assert_eq(mod_detail.metadata_kvp[1].metakey, "difficulty")
	assert_eq(mod_detail.platforms[1].platform, "SOURCE")
	assert_eq(mod_detail.media.images[0].filename, "cardio-shot.png")
	assert_eq(mod_detail.skus[0].portal, "steam")

	var modfiles = adapter.normalize_modfiles_response(_fixture("modfiles.json"))
	assert_eq(modfiles.data[0].download.binary_url, "https://api.mod.io/v1/games/777/mods/1001/files/5001/download/hash123")
	assert_true(modfiles.data[0].download.is_expiring)
	assert_false(modfiles.data[0].download.is_canonical_url)
	assert_eq(modfiles.data[0].platforms[1].platform, "SOURCE")
	assert_eq(modfiles.page.page_count, 1)

	var modfile_detail = adapter.normalize_modfile_response(_fixture("modfile_detail.json"))
	assert_eq(modfile_detail.id, 5002)
	assert_eq(modfile_detail.filehash.md5, "def456md5")
	assert_eq(modfile_detail.download.binary_url, "https://api.mod.io/v1/games/777/mods/1001/files/5002/download/hash456")

	var mod_stats = adapter.normalize_mod_stats_response(_fixture("mod_stats.json"))
	assert_eq(mod_stats.mod_id, 1001)
	assert_eq(mod_stats.ratings_negative, 6)
	assert_true(mod_stats.has_expiry)
	assert_false(mod_stats.is_stale)

	var comments = adapter.normalize_mod_comments_response(_fixture("comments_list.json"))
	assert_eq(comments.data.size(), 3)
	assert_true(comments.page.has_next)
	assert_eq(comments.page.next_offset, 3)
	assert_eq(comments.data[0].resource_type, "mod_comment")
	assert_true(comments.data[0].is_pinned)
	assert_false(comments.data[0].is_locked)
	assert_false(comments.data[0].is_reply)
	assert_eq(comments.data[0].thread_depth, 1)
	assert_true(comments.data[2].is_reply)
	assert_true(comments.data[2].is_locked)
	assert_eq(comments.data[2].thread_depth, 3)
	assert_true(comments.data[2].option_flags.locked)
	assert_false(comments.data[2].option_flags.pinned)

	var comment_detail = adapter.normalize_mod_comment_response(_fixture("comment_detail.json"))
	assert_eq(comment_detail.id, 9002)
	assert_eq(comment_detail.reply_id, 9001)
	assert_eq(comment_detail.thread_depth, 2)
	assert_false(comment_detail.is_pinned)

	var created_comment = adapter.normalize_comment_write_response(_fixture("comment_created.json"))
	assert_eq(created_comment.content, "Fresh reply from the wrapper")
	assert_true(created_comment.is_reply)

	var updated_comment = adapter.normalize_comment_write_response(_fixture("comment_updated.json"))
	assert_eq(updated_comment.karma, 1)
	assert_eq(updated_comment.thread_position, "01.02")

	var karma_updated_comment = adapter.normalize_comment_write_response(_fixture("comment_karma_updated.json"))
	assert_eq(karma_updated_comment.karma, 2)

	var deleted_comment = adapter.normalize_comment_delete_response(204)
	assert_true(deleted_comment.ok)
	assert_true(deleted_comment.deleted)
	assert_eq(deleted_comment.data, {})

	var user_ratings = adapter.normalize_user_ratings_response(_fixture("user_ratings.json"))
	assert_eq(user_ratings.data.size(), 2)
	assert_true(user_ratings.data[0].is_positive)
	assert_false(user_ratings.data[0].is_negative)
	assert_true(user_ratings.data[1].is_negative)
	assert_eq(user_ratings.data[1].rating, -1)
	assert_eq(user_ratings.page.page_count, 1)

	var subscriptions = adapter.normalize_subscriptions_response(_fixture("subscribed.json"))
	assert_eq(subscriptions.result_total, 3)
	assert_true(subscriptions.page.has_next)
	assert_eq(subscriptions.data[0].id, 1001)

	var add_rating = adapter.normalize_add_mod_rating_response(_fixture("add_mod_rating_success.json"))
	assert_true(add_rating.success)
	assert_eq(add_rating.message, "response_mod_rating_add")

	var report = adapter.normalize_report_response(_fixture("report_success.json"))
	assert_true(report.success)
	assert_eq(report.message, "response_report_add")

	var logout = adapter.normalize_logout_response(_fixture("logout_success.json"))
	assert_true(logout.success)
	assert_string_contains(logout.message, "logged out")

func test_normalizes_collection_and_collection_comment_fixture_payloads() -> void:
	var adapter := _build_adapter()

	var collections = adapter.normalize_collections_response(_fixture("collections.json"))
	assert_eq(collections.result_total, 5)
	assert_true(collections.page.has_next)
	assert_eq(collections.data[0].name, "Starter Bundle")
	assert_true(collections.data[0].visible)
	assert_eq(collections.data[0].platforms[0], "WINDOWS")
	assert_eq(collections.data[0].tags[1], "QUALITY_OF_LIFE")
	assert_eq(collections.data[0].stats.downloads_unique, 60)
	assert_eq(collections.data[1].date_disabled, 1777890000)

	var collection_detail = adapter.normalize_collection_response(_fixture("collection_detail.json"))
	assert_eq(collection_detail.id, 3001)
	assert_eq(collection_detail.submitted_by.username, "Coach Chip")
	assert_eq(collection_detail.logo.thumb_320x180, "https://assets.modcdn.io/images/collections/starter-bundle_320x180.png")

	var collection_comments = adapter.normalize_collection_comments_response(_fixture("collection_comments_list.json"))
	assert_eq(collection_comments.data.size(), 2)
	assert_true(collection_comments.page.has_next)
	assert_eq(collection_comments.page.previous_offset, 0)
	assert_eq(collection_comments.data[0].resource_type, "collection_comment")
	assert_true(collection_comments.data[0].is_pinned)
	assert_true(collection_comments.data[1].is_reply)
	assert_true(collection_comments.data[1].is_locked)
	assert_eq(collection_comments.data[1].thread_depth, 2)

	var collection_comment_detail = adapter.normalize_collection_comment_response(_fixture("collection_comment_detail.json"))
	assert_eq(collection_comment_detail.id, 9902)
	assert_eq(collection_comment_detail.reply_id, 9901)
	assert_eq(collection_comment_detail.resource_type, "collection_comment")

	var created_collection_comment = adapter.normalize_collection_comment_write_response(_fixture("collection_comment_created.json"))
	assert_eq(created_collection_comment.thread_position, "01.02")
	assert_true(created_collection_comment.is_reply)

	var updated_collection_comment = adapter.normalize_collection_comment_write_response(_fixture("collection_comment_updated.json"))
	assert_eq(updated_collection_comment.karma, 0)
	assert_eq(updated_collection_comment.content, "Collection reply edited for clarity")

	var karma_updated_collection_comment = adapter.normalize_collection_comment_write_response(_fixture("collection_comment_karma_updated.json"))
	assert_eq(karma_updated_collection_comment.karma, 1)
	assert_true(karma_updated_collection_comment.is_locked)

	var compatibility_response = adapter.normalize_add_collection_compatibility_response(_fixture("add_collection_compatibility_success.json"))
	assert_eq(compatibility_response.code, 201)
	assert_eq(compatibility_response.message, "response_collection_rating_add")
	assert_true(compatibility_response.success)

func test_normalizes_guides_and_guide_comment_fixture_payloads() -> void:
	var adapter := _build_adapter_with_token()

	var guides = adapter.normalize_guides_response(_fixture("guides.json"))
	assert_eq(guides.result_total, 5)
	assert_true(guides.page.has_next)
	assert_eq(guides.data[0].name, "Building Your First Routine")
	assert_eq(guides.data[0].resource_type, "guide")
	assert_true(guides.data[0].allows_comments)
	assert_true(guides.data[0].community_policy.allows_comments)
	assert_false(guides.data[1].community_policy.allows_comments)
	assert_eq(guides.data[0].tags[0].count, 8)
	assert_eq(guides.data[0].stats.visits_total, 320)
	assert_eq(guides.data[0].visits_total, 320)
	assert_eq(guides.data[0].comments_total, 5)

	var guide_detail = adapter.normalize_guide_response(_fixture("guide_detail.json"))
	assert_eq(guide_detail.id, 7001)
	assert_eq(guide_detail.resource_type, "guide")
	assert_eq(guide_detail.user.username, "Coach Chip")
	assert_eq(guide_detail.stats.comments_total, 5)
	assert_eq(guide_detail.comments_total, 5)
	assert_eq(guide_detail.logo.thumb_320x180, "https://assets.modcdn.io/images/guides/guide-card_320x180.png")

	var guide_comments = adapter.normalize_guide_comments_response(_fixture("guide_comments_list.json"))
	assert_eq(guide_comments.data.size(), 2)
	assert_eq(guide_comments.data[0].resource_type, "guide_comment")
	assert_true(guide_comments.data[0].is_pinned)
	assert_true(guide_comments.data[1].is_reply)
	assert_true(guide_comments.data[1].is_locked)
	assert_eq(guide_comments.data[1].thread_depth, 2)

	var guide_comment_detail = adapter.normalize_guide_comment_response(_fixture("guide_comment_detail.json"))
	assert_eq(guide_comment_detail.id, 9902)
	assert_eq(guide_comment_detail.reply_id, 9901)
	assert_eq(guide_comment_detail.resource_type, "guide_comment")

	var created_guide_comment = adapter.normalize_guide_comment_write_response(_fixture("guide_comment_created.json"))
	assert_eq(created_guide_comment.thread_position, "01.02")
	assert_true(created_guide_comment.is_reply)

	var updated_guide_comment = adapter.normalize_guide_comment_write_response(_fixture("guide_comment_updated.json"))
	assert_eq(updated_guide_comment.karma, 1)
	assert_eq(updated_guide_comment.content, "I added a lighter recovery block and it fixed the pacing.")

	var karma_updated_guide_comment = adapter.normalize_guide_comment_write_response(_fixture("guide_comment_karma_updated.json"))
	assert_eq(karma_updated_guide_comment.karma, 0)
	assert_true(karma_updated_guide_comment.is_locked)

	var guide_karma_downvote_disabled = adapter.normalize_transport_response(403, {}, _fixture("guide_comment_karma_downvote_disabled_error.json"))
	assert_false(guide_karma_downvote_disabled.ok)
	assert_eq(guide_karma_downvote_disabled.error.category, "forbidden")
	assert_eq(guide_karma_downvote_disabled.error.error_ref, 19045)

func test_resolves_download_requests_from_modfile_metadata_not_download_endpoint() -> void:
	var adapter := _build_adapter_with_token()
	var modfile_payload: Dictionary = _fixture("modfiles.json").data[0]
	var download_request: ModioDownloadRequest = adapter.resolve_download_request_from_modfile("1001", modfile_payload)
	var normalized = adapter.build_download_request(download_request)

	assert_eq(normalized.mod_id, "1001")
	assert_eq(normalized.file_id, "5001")
	assert_eq(normalized.binary_url, "https://api.mod.io/v1/games/777/mods/1001/files/5001/download/hash123")
	assert_eq(normalized.md5, "abc123md5")
	assert_true(normalized.is_expiring)
	assert_false(normalized.is_canonical_url)
	assert_string_contains(normalized.warning, "expiring delivery URLs")

func test_builds_stable_artifact_keys_and_dedupes_by_identity() -> void:
	var adapter := _build_adapter_with_token()
	var game_payload := _fixture("game.json")
	var mod_detail_payload := _fixture("mod_detail.json")
	var modfiles_payload := _fixture("modfiles.json")

	var detail_record = adapter.resolve_artifact_record_from_mod_detail(mod_detail_payload, game_payload)
	var modfile_payload: Dictionary = modfiles_payload.data[0].duplicate(true)
		
	modfile_payload.download.binary_url = "https://api.mod.io/v1/games/777/mods/1001/files/5001/download/hash456"
	var list_record = adapter.resolve_artifact_record_from_modfile("1001", modfile_payload, game_payload)

	assert_eq(detail_record.identity.canonical_id, "modio:777:1001:5001")
	assert_eq(detail_record.artifact_key, list_record.artifact_key)
	assert_eq(detail_record.cache_key, list_record.cache_key)
	assert_ne(detail_record.delivery.binary_url, list_record.delivery.binary_url)

	var deduped = adapter.dedupe_artifact_records([detail_record, list_record])
	assert_eq(deduped.size(), 1)
	assert_eq(deduped[0].artifact_key, "modio:777:1001:5001")

func test_marks_expired_urls_and_interprets_api_access_options_for_cache_metadata() -> void:
	var adapter := _build_adapter_with_token()
	var restricted_game := _fixture("game.json").duplicate(true)
	restricted_game.api_access_options = 12
	var expired_modfile: Dictionary = _fixture("modfiles.json").data[0].duplicate(true)
	expired_modfile.download.date_expires = Time.get_unix_time_from_system() - 30

	var record = adapter.resolve_artifact_record_from_modfile("1001", expired_modfile, restricted_game)

	assert_true(record.delivery.is_delivery_url_expired)
	assert_true(record.delivery.requires_fresh_resolution)
	assert_true(record.delivery.is_delivery_url_expiring)
	assert_false(record.game_policy.allows_direct_downloads)
	assert_true(record.game_policy.requires_authenticated_download)
	assert_true(record.game_policy.requires_entitlement_download)
	assert_true(record.game_policy.delivery_urls_require_api_resolution)

func test_flags_partial_or_invalid_artifact_metadata_when_download_fields_are_missing() -> void:
	var adapter := _build_adapter_with_token()
	var game_payload := _fixture("game.json")
	var partial_modfile: Dictionary = _fixture("modfiles.json").data[0].duplicate(true)
	partial_modfile.download = {}
	partial_modfile.filehash = {}

	var partial_record = adapter.resolve_artifact_record_from_modfile("1001", partial_modfile, game_payload)
	assert_false(partial_record.validity.has_delivery)
	assert_false(partial_record.validity.has_integrity)
	assert_false(partial_record.validity.is_cacheable)
	assert_true(partial_record.validity.is_partial)
	assert_eq(partial_record.validity.issues.warnings[0], "missing download.binary_url")
	assert_eq(partial_record.validity.issues.warnings[1], "missing filehash.md5")

	var invalid_modfile: Dictionary = partial_modfile.duplicate(true)
	invalid_modfile.id = 0
	var invalid_record = adapter.resolve_artifact_record_from_modfile("1001", invalid_modfile, game_payload)
	assert_false(invalid_record.validity.has_identity)
	assert_eq(invalid_record.artifact_key, "")
	assert_eq(invalid_record.validity.issues.errors[0], "missing modfile.id")

func test_normalizes_auth_failure_variants_and_terms_handling() -> void:
	var adapter := _build_adapter_with_token()

	var rate_limited = adapter.normalize_transport_response(429, {"Retry-After": "0"}, _fixture("rate_limit_error.json"))
	assert_false(rate_limited.ok)
	assert_eq(rate_limited.retry_after_seconds, 60)
	assert_eq(rate_limited.rate_limit_scope, "endpoint")
	assert_eq(rate_limited.error.category, "rate_limited")
	assert_eq(rate_limited.error.error_ref, 11009)

	var terms_required = adapter.normalize_transport_response(403, {}, _fixture("terms_required_error.json"))
	assert_false(terms_required.ok)
	assert_eq(terms_required.error.category, "terms_required")
	assert_true(terms_required.error.should_retry_with_terms)
	assert_eq(terms_required.error.error_ref, 11074)

	var code_expired = adapter.normalize_transport_response(401, {}, _fixture("auth_code_expired_error.json"))
	assert_false(code_expired.ok)
	assert_eq(code_expired.error.category, "auth")
	assert_eq(code_expired.error.error_ref, 11012)

	var key_restricted = adapter.normalize_transport_response(403, {}, _fixture("auth_key_restricted_error.json"))
	assert_false(key_restricted.ok)
	assert_eq(key_restricted.error.category, "key_restricted")
	assert_true(key_restricted.error.is_key_issue)

	var account_locked = adapter.normalize_transport_response(403, {}, _fixture("auth_account_locked_error.json"))
	assert_false(account_locked.ok)
	assert_eq(account_locked.error.category, "account_locked")
	assert_true(account_locked.error.is_account_locked)

func test_normalizes_subscription_write_success_variants() -> void:
	var adapter := _build_adapter_with_token()
	var payload := _fixture("mod_detail.json")

	var created = adapter.normalize_subscription_write_response(201, {"Location": "/me/subscribed/1001"}, payload)
	assert_true(created.ok)
	assert_false(created.already_subscribed)
	assert_eq(created.location, "/me/subscribed/1001")
	assert_eq(created.data.id, 1001)

	var existing = adapter.normalize_subscription_write_response(200, {}, payload)
	assert_true(existing.ok)
	assert_true(existing.already_subscribed)

func test_normalizes_social_mutation_write_success_variants() -> void:
	var adapter := _build_adapter_with_token()
	var collection_payload := _fixture("collection_detail.json")

	var followed_user = adapter.normalize_follow_user_response(204)
	assert_true(followed_user.ok)
	assert_true(followed_user.followed)
	assert_eq(followed_user.data, {})

	var unfollowed_user = adapter.normalize_unfollow_user_response(204)
	assert_true(unfollowed_user.ok)
	assert_true(unfollowed_user.unfollowed)

	var muted_user = adapter.normalize_mute_user_response(204)
	assert_true(muted_user.ok)
	assert_true(muted_user.muted)

	var unmuted_user = adapter.normalize_unmute_user_response(204)
	assert_true(unmuted_user.ok)
	assert_true(unmuted_user.unmuted)

	var followed_collection = adapter.normalize_follow_collection_response(201, {"Location": "/games/777/collections/3001/followers"}, collection_payload)
	assert_true(followed_collection.ok)
	assert_false(followed_collection.already_followed)
	assert_eq(followed_collection.location, "/games/777/collections/3001/followers")
	assert_eq(followed_collection.data.id, 3001)

	var already_followed_collection = adapter.normalize_follow_collection_response(200, {}, collection_payload)
	assert_true(already_followed_collection.ok)
	assert_true(already_followed_collection.already_followed)

	var unfollowed_collection = adapter.normalize_unfollow_collection_response(204)
	assert_true(unfollowed_collection.ok)
	assert_true(unfollowed_collection.unfollowed)
	assert_eq(unfollowed_collection.data, {})

func test_normalizes_rating_report_and_comment_error_variants() -> void:
	var adapter := _build_adapter_with_token()

	var rating_exists = adapter.normalize_transport_response(409, {}, _fixture("rating_already_exists_error.json"))
	assert_false(rating_exists.ok)
	assert_eq(rating_exists.error.category, "conflict")
	assert_eq(rating_exists.error.error_ref, 15028)

	var rating_missing = adapter.normalize_transport_response(409, {}, _fixture("rating_revert_missing_error.json"))
	assert_false(rating_missing.ok)
	assert_eq(rating_missing.error.category, "conflict")
	assert_eq(rating_missing.error.error_ref, 15043)

	var report_permission = adapter.normalize_transport_response(403, {}, _fixture("report_permission_error.json"))
	assert_false(report_permission.ok)
	assert_eq(report_permission.error.category, "forbidden")
	assert_eq(report_permission.error.error_ref, 15029)

	var report_unavailable = adapter.normalize_transport_response(403, {}, _fixture("report_unavailable_error.json"))
	assert_false(report_unavailable.ok)
	assert_eq(report_unavailable.error.category, "forbidden")
	assert_eq(report_unavailable.error.error_ref, 15030)

	var report_not_found = adapter.normalize_transport_response(404, {}, _fixture("report_not_found_error.json"))
	assert_false(report_not_found.ok)
	assert_eq(report_not_found.error.category, "not_found")
	assert_eq(report_not_found.error.error_ref, 14000)

	var restricted_comments = adapter.normalize_transport_response(403, {}, _fixture("comment_restricted_error.json"))
	assert_false(restricted_comments.ok)
	assert_eq(restricted_comments.error.category, "comments_restricted")
	assert_eq(restricted_comments.error.error_ref, 40004)

	var deleted_comment = adapter.normalize_transport_response(400, {}, _fixture("comment_karma_deleted_error.json"))
	assert_false(deleted_comment.ok)
	assert_eq(deleted_comment.error.category, "conflict")
	assert_eq(deleted_comment.error.error_ref, 15090)

	var karma_conflict = adapter.normalize_transport_response(403, {}, _fixture("comment_karma_conflict_error.json"))
	assert_false(karma_conflict.ok)
	assert_eq(karma_conflict.error.category, "conflict")
	assert_eq(karma_conflict.error.error_ref, 15059)

	var karma_forbidden = adapter.normalize_transport_response(403, {}, _fixture("comment_karma_forbidden_error.json"))
	assert_false(karma_forbidden.ok)
	assert_eq(karma_forbidden.error.category, "forbidden")
	assert_eq(karma_forbidden.error.error_ref, 15055)

	var karma_downvote_disabled = adapter.normalize_transport_response(403, {}, _fixture("comment_karma_downvote_disabled_error.json"))
	assert_false(karma_downvote_disabled.ok)
	assert_eq(karma_downvote_disabled.error.category, "forbidden")
	assert_eq(karma_downvote_disabled.error.error_ref, 15095)


func test_builds_catalog_game_meta_and_taxonomy_requests_with_doc_corrected_paths() -> void:
	var public_adapter := _build_adapter()
	var auth_adapter := _build_adapter_with_token()
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

	var games_request = public_adapter.build_games_request(games_query)
	assert_eq(games_request.path, "/games")
	assert_eq(games_request.query.api_key, "demo-key")
	assert_eq(games_request.query._sort, "-date_updated")
	assert_eq(games_request.query.name, "AeroBeat")
	assert_eq(games_request.query.summary, "Rhythm workouts")
	assert_eq(games_request.query.instructions_url, "https://docs.aerobeat.example/mods")
	assert_eq(games_request.query.ugc_name, "mods")
	assert_eq(games_request.query.presentation_option, "0")
	assert_eq(games_request.query.submission_option, "1")
	assert_eq(games_request.query.curation_option, "2")
	assert_eq(games_request.query.profanity_option, "3")
	assert_eq(games_request.query.dependency_option, "2")
	assert_eq(games_request.query.community_options, "258")
	assert_eq(games_request.query.monetization_options, "1")
	assert_eq(games_request.query.api_access_options, "7")
	assert_eq(games_request.query.maturity_options, "0")
	assert_true(games_request.query.show_hidden_tags)

	var invalid_games_sort := ModioListingQuery.new()
	invalid_games_sort.sort = "-ratings_weighted_aggregate"
	var invalid_games_request = public_adapter.build_games_request(invalid_games_sort)
	assert_false(invalid_games_request.query.has("_sort"))

	var game_stats_request = public_adapter.build_game_stats_request()
	assert_eq(game_stats_request.path, "/games/777/stats")

	var game_tags_request = public_adapter.build_game_tags_request("888", true)
	assert_eq(game_tags_request.path, "/games/888/tags")
	assert_true(game_tags_request.query.show_hidden_tags)

	var token_packs_request = auth_adapter.build_game_token_packs_request("888")
	assert_eq(token_packs_request.path, "/games/888/monetization/token-packs")
	assert_eq(token_packs_request.headers.Authorization, "Bearer user-token")
	assert_eq(token_packs_request.auth_mode, "bearer")

	var mod_stats_query := ModioListingQuery.new()
	mod_stats_query.mod_id = "1001"
	var game_mod_stats_request = public_adapter.build_game_mod_stats_request("888", mod_stats_query)
	assert_eq(game_mod_stats_request.path, "/games/888/mods/stats")
	assert_eq(game_mod_stats_request.query.mod_id, "1001")

	var guide_tags_request = public_adapter.build_guide_tags_request("888")
	assert_eq(guide_tags_request.path, "/games/888/guides/tags")

	var agreement_version_request = public_adapter.build_agreement_version_request(31)
	assert_eq(agreement_version_request.path, "/agreements/versions/31")

	var ping_request = public_adapter.build_ping_request()
	assert_eq(ping_request.path, "/ping")
	assert_eq(ping_request.auth_mode, "none")
	assert_eq(ping_request.query, {})

func _build_adapter() -> ModioVendorAdapter:
	return ModioVendorAdapter.new(
		ModioClientConfig.new("777", "demo-key", ModioClientConfig.DEFAULT_BASE_URL, "", "en-US", "steam", "WINDOWS"),
		ModioHttpTransport.new()
	)

func _build_adapter_with_token() -> ModioVendorAdapter:
	return ModioVendorAdapter.new(
		ModioClientConfig.new("777", "demo-key", ModioClientConfig.DEFAULT_BASE_URL, "user-token", "en-US", "steam", "WINDOWS"),
		ModioHttpTransport.new()
	)

func _fixture(name: String) -> Dictionary:
	var path := "res://tests/fixtures/%s" % name
	var text := FileAccess.get_file_as_string(path)
	var payload = JSON.parse_string(text)
	assert_true(payload is Dictionary, "failed to parse fixture %s" % path)
	return payload
