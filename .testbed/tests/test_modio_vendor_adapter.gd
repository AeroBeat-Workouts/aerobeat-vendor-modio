extends GutTest

const ModioClientConfig = preload("res://src/models/modio_client_config.gd")
const ModioListingQuery = preload("res://src/models/modio_listing_query.gd")
const ModioDownloadRequest = preload("res://src/models/modio_download_request.gd")
const ModioHttpTransport = preload("res://src/network/modio_http_transport.gd")
const ModioVendorAdapter = preload("res://src/modio_vendor_adapter.gd")

func test_builds_email_and_openid_auth_requests_with_hardened_expiry_handling() -> void:
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

	var mods = adapter.normalize_mod_list_response(_fixture("mods.json"))
	assert_eq(mods.result_offset, 5)
	assert_true(mods.page.has_next)
	assert_eq(mods.page.next_offset, 6)
	assert_eq(mods.page.page_index, 0)
	assert_eq(mods.data[0].name_id, "cardio-blaster")
	assert_eq(mods.data[0].stats.downloads_total, 1024)
	assert_eq(mods.data[0].community_options, 1025)
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
	assert_eq(add_rating.message, "response_mod_rating_added")

	var report = adapter.normalize_report_response(_fixture("report_success.json"))
	assert_true(report.success)
	assert_eq(report.message, "response_report_add")

	var logout = adapter.normalize_logout_response(_fixture("logout_success.json"))
	assert_true(logout.success)
	assert_string_contains(logout.message, "logged out")

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

func test_normalizes_rating_and_report_error_variants() -> void:
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
