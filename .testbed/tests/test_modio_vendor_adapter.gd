extends GutTest

const ModioClientConfig = preload("res://src/models/modio_client_config.gd")
const ModioListingQuery = preload("res://src/models/modio_listing_query.gd")
const ModioDownloadRequest = preload("res://src/models/modio_download_request.gd")
const ModioHttpTransport = preload("res://src/network/modio_http_transport.gd")
const ModioVendorAdapter = preload("res://src/modio_vendor_adapter.gd")

func test_builds_email_and_openid_auth_requests_with_current_shapes() -> void:
	var adapter := _build_adapter()

	var email_request = adapter.build_email_security_code_request(" player@example.com ")
	assert_eq(email_request.method, "POST")
	assert_eq(email_request.path, "/oauth/emailrequest")
	assert_eq(email_request.body.email, "player@example.com")
	assert_eq(email_request.content_type, ModioHttpTransport.CONTENT_TYPE_FORM)
	assert_eq(email_request.auth_mode, "api_key_query")
	assert_false(email_request.query.has("api_key"))

	var exchange_request = adapter.build_auth_exchange_request(" 123456 ", 1777777777)
	assert_eq(exchange_request.path, "/oauth/emailexchange")
	assert_eq(exchange_request.body.security_code, "123456")
	assert_eq(exchange_request.body.date_expires, "1777777777")

	var openid_request = adapter.build_openid_auth_request("jwt-token", true, "recover@example.com", 1777777777, false, "psn-code", 1)
	assert_eq(openid_request.path, "/external/openidauth")
	assert_eq(openid_request.body.id_token, "jwt-token")
	assert_true(openid_request.body.terms_agreed)
	assert_eq(openid_request.body.email, "recover@example.com")
	assert_eq(openid_request.body.date_expires, "1777777777")
	assert_eq(openid_request.body.psn_token, "psn-code")
	assert_eq(openid_request.body.psn_env, "1")

func test_builds_terms_and_agreement_requests_with_localization_headers() -> void:
	var adapter := _build_adapter()

	var terms_request = adapter.build_terms_request()
	assert_eq(terms_request.method, "GET")
	assert_eq(terms_request.path, "/authenticate/terms")
	assert_eq(terms_request.query.api_key, "demo-key")
	assert_eq(terms_request.headers["Accept-Language"], "en-US")
	assert_eq(terms_request.headers["X-Modio-Portal"], "steam")
	assert_eq(terms_request.headers["X-Modio-Platform"], "WINDOWS")

	var agreement_request = adapter.build_current_agreement_request("privacy")
	assert_eq(agreement_request.path, "/agreements/types/privacy/current")
	assert_eq(agreement_request.query.api_key, "demo-key")

func test_builds_browse_and_detail_requests_with_documented_query_shapes() -> void:
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
		"cardio-blaster"
	)

	var listing_request = adapter.build_listing_request(query)
	assert_eq(listing_request.path, "/games/777/mods")
	assert_eq(listing_request.query.api_key, "demo-key")
	assert_eq(listing_request.query._q, "boxing")
	assert_eq(listing_request.query.tags, "approved,featured")
	assert_eq(listing_request.query["tags-in"], "cardio")
	assert_eq(listing_request.query["tags-not-in"], "hidden")
	assert_eq(listing_request.query.metadata_blob, "{\"intensity\":\"high\"}")
	assert_eq(listing_request.query.metadata_kvp, "workout_type:cardio,difficulty:expert")
	assert_eq(listing_request.query._sort, "-downloads_total")
	assert_eq(listing_request.query.id, "1001")
	assert_eq(listing_request.query.name_id, "cardio-blaster")
	assert_eq(listing_request.query._limit, "10")
	assert_eq(listing_request.query._offset, "5")

	var detail_request = adapter.build_mod_detail_request("1001")
	assert_eq(detail_request.path, "/games/777/mods/1001")

	var modfiles_request = adapter.build_modfiles_request("1001", ModioListingQuery.new("", PackedStringArray(), 100, 0, "-date_added"))
	assert_eq(modfiles_request.path, "/games/777/mods/1001/files")
	assert_eq(modfiles_request.query._sort, "-date_added")

func test_builds_authenticated_subscription_requests() -> void:
	var adapter := _build_adapter_with_token()

	var me_request = adapter.build_authenticated_user_request("delegate-123")
	assert_eq(me_request.path, "/me")
	assert_eq(me_request.headers.Authorization, "Bearer user-token")
	assert_eq(me_request.headers["X-Modio-Delegation-Token"], "delegate-123")
	assert_false(me_request.query.has("api_key"))

	var subscribed_request = adapter.build_user_subscriptions_request(ModioListingQuery.new("", PackedStringArray(["approved"]), 25, 0))
	assert_eq(subscribed_request.path, "/me/subscribed")
	assert_eq(subscribed_request.headers.Authorization, "Bearer user-token")
	assert_eq(subscribed_request.query.tags, "approved")

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

func test_normalizes_fixture_payloads_for_current_slice() -> void:
	var adapter := _build_adapter_with_token()

	var token = adapter.normalize_access_token_response(_fixture("access_token.json"))
	assert_eq(token.access_token, "ey-demo-token")
	assert_eq(token.date_expires, 1777777777)

	var terms = adapter.normalize_terms_response(_fixture("terms.json"))
	assert_eq(terms.buttons.agree.text, "I Agree")
	assert_true(terms.links.terms.required)

	var agreement = adapter.normalize_agreement_response(_fixture("agreement_current.json"))
	assert_eq(agreement.name, "privacy")
	assert_eq(agreement.version, "2026-04-01")

	var me = adapter.normalize_authenticated_user_response(_fixture("me.json"))
	assert_eq(me.id, 42)
	assert_eq(me.username, "AeroBeatPlayer")

	var game = adapter.normalize_game_response(_fixture("game.json"))
	assert_eq(game.id, 777)
	assert_eq(game.api_access_options, 7)
	assert_eq(game.tag_options[0].name, "Difficulty")

	var mods = adapter.normalize_mod_list_response(_fixture("mods.json"))
	assert_eq(mods.result_offset, 5)
	assert_eq(mods.data[0].name_id, "cardio-blaster")
	assert_eq(mods.data[0].stats.downloads_total, 1024)

	var mod_detail = adapter.normalize_mod_detail_response(_fixture("mod_detail.json"))
	assert_eq(mod_detail.modfile.id, 5001)
	assert_eq(mod_detail.tags[1].name, "Expert")

	var modfiles = adapter.normalize_modfiles_response(_fixture("modfiles.json"))
	assert_eq(modfiles.data[0].download.binary_url, "https://api.mod.io/v1/games/777/mods/1001/files/5001/download/hash123")
	assert_true(modfiles.data[0].download.is_expiring)
	assert_false(modfiles.data[0].download.is_canonical_url)

	var subscriptions = adapter.normalize_subscriptions_response(_fixture("subscribed.json"))
	assert_eq(subscriptions.result_total, 1)
	assert_eq(subscriptions.data[0].id, 1001)

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

func test_normalizes_rate_limit_and_terms_required_errors() -> void:
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
	assert_eq(terms_required.error.error_ref, 11074)

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
