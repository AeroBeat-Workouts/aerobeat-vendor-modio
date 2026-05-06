extends GutTest

const ModioEnvLoader = preload("res://modio_env_loader.gd")
const ModioLiveHarness = preload("res://modio_live_harness_lib.gd")
const ModioVendorAdapter = preload("res://src/modio_vendor_adapter.gd")

const STABLE_PATH := "user://modio_live_harness_stable.cfg"
const SESSION_PATH := "user://modio_live_harness_session.cfg"

func after_each() -> void:
	_cleanup_file(STABLE_PATH)
	_cleanup_file(SESSION_PATH)

func test_parse_args_supports_safe_cli_flags() -> void:
	var harness := ModioLiveHarness.new()
	var options := harness.parse_args([
		"--env", "live",
		"--mods-limit", "9",
		"--public-only",
		"--allow-writes",
		"--json",
		"--stable-config", "user://stable.cfg",
		"--session-config", "user://session.cfg"
	])

	assert_eq(options.env, "live")
	assert_eq(options.mods_limit, 9)
	assert_true(options.public_only)
	assert_true(options.allow_writes)
	assert_true(options.json)
	assert_eq(options.stable_path, "user://stable.cfg")
	assert_eq(options.session_path, "user://session.cfg")
	assert_true(options.errors.is_empty())

func test_parse_args_rejects_invalid_environment_and_missing_values() -> void:
	var harness := ModioLiveHarness.new()
	var options := harness.parse_args(["--env", "preview", "--mods-limit"])

	assert_eq(options.errors.size(), 2)
	assert_true("Unsupported environment: preview" in options.errors)
	assert_true("Missing value for --mods-limit" in options.errors)

func test_build_run_plan_marks_optional_auth_check_skipped_when_no_token() -> void:
	_write_config(STABLE_PATH, _stable_config("test"))
	_write_config(SESSION_PATH, _session_config("", "", ""))

	var harness := ModioLiveHarness.new()
	var plan := harness.build_run_plan({
		"env": "",
		"mods_limit": 3,
		"public_only": false,
		"stable_path": STABLE_PATH,
		"session_path": SESSION_PATH
	})

	assert_eq(plan.environment, "test")
	assert_eq(plan.checks.size(), 4)
	assert_eq(plan.checks[3].id, "me")
	assert_true(plan.checks[3].skip)
	assert_eq(plan.checks[3].skip_reason, "No access token configured in session config")

func test_build_run_plan_includes_optional_auth_check_when_token_exists() -> void:
	_write_config(STABLE_PATH, _stable_config("test"))
	_write_config(SESSION_PATH, _session_config("", "", "session-token"))

	var harness := ModioLiveHarness.new()
	var plan := harness.build_run_plan({
		"env": "live",
		"mods_limit": 5,
		"public_only": false,
		"stable_path": STABLE_PATH,
		"session_path": SESSION_PATH
	})

	assert_eq(plan.environment, "live")
	assert_false(plan.config.use_test_environment)
	assert_false(bool(plan.checks[3].get("skip", false)))

func test_build_missing_config_warnings_detects_required_public_tuple() -> void:
	_write_config(STABLE_PATH, "[modio]\ndefault_environment=\"test\"\n\n[modio.test]\ngame_id=\"\"\napi_key=\"\"\n\n[modio.live]\ngame_id=\"2001\"\napi_key=\"live-key\"\n")
	_write_config(SESSION_PATH, _session_config("", "", ""))

	var harness := ModioLiveHarness.new()
	var plan := harness.build_run_plan({
		"env": "test",
		"mods_limit": 3,
		"public_only": true,
		"stable_path": STABLE_PATH,
		"session_path": SESSION_PATH
	})
	var warnings := harness.build_missing_config_warnings(plan)

	assert_true("Selected environment is missing game_id" in warnings)
	assert_true("Selected environment is missing api_key" in warnings)

func test_summarize_game_response_reads_top_level_detail_payload() -> void:
	var harness := ModioLiveHarness.new()
	var adapter := ModioVendorAdapter.new()
	var summary := harness.summarize_game_response(adapter, {"payload": _fixture("game.json")})

	assert_eq(summary.id, 777)
	assert_eq(summary.name, "AeroBeat")
	assert_eq(summary.status, -1)

func test_summarize_authenticated_user_response_reads_top_level_detail_payload() -> void:
	var harness := ModioLiveHarness.new()
	var adapter := ModioVendorAdapter.new()
	var summary := harness.summarize_authenticated_user_response(adapter, {"payload": _fixture("me.json")})

	assert_eq(summary.id, 42)
	assert_eq(summary.name_id, "aerobeat-player")
	assert_eq(summary.username, "AeroBeatPlayer")

func test_summarize_mods_response_reports_requested_limit_separately_from_server_page_echo() -> void:
	var harness := ModioLiveHarness.new()
	var adapter := ModioVendorAdapter.new()
	var summary := harness.summarize_mods_response(adapter, {"payload": _fixture("mods.json")}, 3)

	assert_eq(summary.requested_limit, 3)
	assert_eq(summary.response_result_count, 1)
	assert_eq(summary.response_result_limit, 10)
	assert_eq(summary.response_result_offset, 5)
	assert_eq(summary.response_result_total, 13)
	assert_eq(summary.selected_mod_id, 1001)
	assert_eq(summary.sample_mod_names.size(), 1)
	assert_eq(summary.sample_mod_names[0], "Cardio Blaster")

func test_summarize_mod_child_read_responses_from_existing_fixtures() -> void:
	var harness := ModioLiveHarness.new()
	var adapter := ModioVendorAdapter.new()

	var detail_summary := harness.summarize_mod_detail_response(adapter, {"payload": _fixture("mod_detail.json")})
	assert_eq(detail_summary.id, 1001)
	assert_eq(detail_summary.name, "Cardio Blaster")
	assert_eq(detail_summary.name_id, "cardio-blaster")
	assert_eq(detail_summary.status, 1)
	assert_eq(detail_summary.visible, 1)

	var files_summary := harness.summarize_modfiles_response(adapter, {"payload": _fixture("modfiles.json")})
	assert_eq(files_summary.selected_file_id, 5001)
	assert_eq(files_summary.response_result_count, 1)
	assert_eq(files_summary.sample_filenames[0], "cardio-blaster-v1.zip")

	var file_detail_summary := harness.summarize_modfile_response(adapter, {"payload": _fixture("modfile_detail.json")})
	assert_eq(file_detail_summary.id, 5002)
	assert_eq(file_detail_summary.filename, "cardio-blaster-v1.1.zip")
	assert_eq(file_detail_summary.version, "1.1.0")

	var stats_summary := harness.summarize_mod_stats_response(adapter, {"payload": _fixture("mod_stats.json")})
	assert_eq(stats_summary.mod_id, 1001)
	assert_eq(stats_summary.downloads_total, 2048)
	assert_eq(stats_summary.subscribers_total, 400)
	assert_eq(stats_summary.ratings_total, 72)

	var dependants_summary := harness.summarize_dependants_response(adapter, {"payload": _fixture("mod_dependants.json")})
	assert_eq(dependants_summary.response_result_total, 4)
	assert_eq(dependants_summary.first_name, "Cardio Remix Pack")

	var tags_summary := harness.summarize_mod_tags_response(adapter, {"payload": _fixture("mod_tags.json")})
	assert_eq(tags_summary.response_result_total, 2)
	assert_eq(tags_summary.names[0], "Featured")

	var metadata_summary := harness.summarize_mod_metadata_kvp_response(adapter, {"payload": _fixture("mod_metadata_kvp.json")})
	assert_eq(metadata_summary.response_result_total, 2)
	assert_eq(metadata_summary.pairs[0], "difficulty=expert")

	var team_summary := harness.summarize_mod_team_response(adapter, {"payload": _fixture("mod_team.json")})
	assert_eq(team_summary.response_result_total, 2)
	assert_eq(team_summary.usernames[0], "Coach Chip")

	var dependencies_summary := harness.summarize_dependencies_response(adapter, {"payload": _fixture("dependencies_recursive.json")})
	assert_eq(dependencies_summary.response_result_total, 2)
	assert_eq(dependencies_summary.names[0], "Warmup Kit")
	assert_false(dependencies_summary.recursive_requested)

func test_summarize_authenticated_user_read_sweep_responses_from_existing_fixtures() -> void:
	var harness := ModioLiveHarness.new()
	var adapter := ModioVendorAdapter.new()

	var terms_summary := harness.summarize_terms_response(adapter, {"payload": _fixture("terms.json")})
	assert_gt(terms_summary.plaintext_length, 20)
	assert_true("agree" in terms_summary.buttons)
	assert_true("disagree" in terms_summary.buttons)
	assert_true("privacy" in terms_summary.required_links)
	assert_true("terms" in terms_summary.required_links)

	var games_summary := harness.summarize_user_games_response(adapter, {"payload": _fixture("games.json")}, 5)
	assert_eq(games_summary.requested_limit, 5)
	assert_eq(games_summary.response_result_total, 2)
	assert_eq(games_summary.id, 777)
	assert_eq(games_summary.name, "AeroBeat")

	var user_mods_summary := harness.summarize_user_mods_response(adapter, {"payload": _fixture("mods.json")}, 5)
	assert_eq(user_mods_summary.selected_mod_id, 1001)
	assert_eq(user_mods_summary.first_game_id, 777)

	var user_files_summary := harness.summarize_user_modfiles_response(adapter, {"payload": _fixture("modfiles.json")}, 5)
	assert_eq(user_files_summary.selected_file_id, 5001)
	assert_eq(user_files_summary.sample_filenames[0], "cardio-blaster-v1.zip")

	var subscribed_summary := harness.summarize_user_subscriptions_response(adapter, {"payload": _fixture("subscribed.json")}, 5)
	assert_eq(subscribed_summary.selected_mod_id, 1001)
	assert_eq(subscribed_summary.first_game_id, 777)

	var ratings_summary := harness.summarize_user_ratings_response(adapter, {"payload": _fixture("user_ratings.json")}, 5)
	assert_eq(ratings_summary.response_result_total, 2)
	assert_eq(ratings_summary.first_mod_id, 1001)
	assert_eq(ratings_summary.first_resource_type, "mods")
	assert_eq(ratings_summary.first_rating, 1)

	var me_collections_summary := harness.summarize_me_collections_response(adapter, {"payload": _fixture("collections.json")}, 5)
	assert_eq(me_collections_summary.response_result_total, 5)
	assert_eq(me_collections_summary.first_collection_id, 3001)
	assert_eq(me_collections_summary.first_name, "Starter Bundle")

	var followed_collections_summary := harness.summarize_followed_collections_response(adapter, {"payload": _fixture("collections.json")}, 5)
	assert_eq(followed_collections_summary.first_collection_id, 3001)
	assert_eq(followed_collections_summary.first_name_id, "starter-bundle")

	var followers_summary := harness.summarize_me_followers_response(adapter, {"payload": _fixture("user_social_users.json")}, 5)
	assert_eq(followers_summary.response_result_total, 9)
	assert_eq(followers_summary.first_user_id, 77)
	assert_eq(followers_summary.first_username, "Designer Dash")

	var muted_summary := harness.summarize_muted_users_response(adapter, {"payload": _fixture("user_social_users.json")}, 5)
	assert_eq(muted_summary.first_user_id, 77)
	assert_eq(muted_summary.first_name_id, "designer-dash")

	var user_followers_summary := harness.summarize_user_followers_response(adapter, {"payload": _fixture("user_social_users.json")}, 5)
	assert_eq(user_followers_summary.first_user_id, 77)

	var user_following_summary := harness.summarize_user_following_response(adapter, {"payload": _fixture("user_social_users.json")}, 5)
	assert_eq(user_following_summary.first_username, "Designer Dash")

	var user_collections_summary := harness.summarize_user_collections_response(adapter, {"payload": _fixture("collections.json")}, 5)
	assert_eq(user_collections_summary.first_collection_id, 3001)
	assert_eq(user_collections_summary.first_name_id, "starter-bundle")

func test_summarize_low_risk_write_sweep_responses_from_existing_fixtures() -> void:
	var harness := ModioLiveHarness.new()
	var adapter := ModioVendorAdapter.new()

	var subscribe_summary := harness.summarize_subscription_write_response(adapter, {
		"status_code": 201,
		"headers": {"Location": "/games/777/mods/1001/subscribe"},
		"payload": _fixture("mod_detail.json")
	})
	assert_eq(subscribe_summary.mod_id, 1001)
	assert_eq(subscribe_summary.name, "Cardio Blaster")
	assert_false(subscribe_summary.already_subscribed)

	var rating_summary := harness.summarize_message_write_response(adapter, {
		"status_code": 201,
		"payload": _fixture("add_mod_rating_success.json")
	})
	assert_eq(rating_summary.code, 201)
	assert_eq(rating_summary.message, "response_mod_rating_add")
	assert_true(rating_summary.success)

	var ratings_presence := harness.summarize_user_ratings_presence_response(adapter, {
		"payload": _fixture("user_ratings.json")
	}, 5, 1001, 1)
	assert_true(ratings_presence.found_expected_rating)

	var comment_write := harness.summarize_mod_comment_write_response(adapter, {"payload": _fixture("comment_created.json")})
	assert_eq(comment_write.comment_id, 9010)
	assert_eq(comment_write.content, "Fresh reply from the wrapper")

	var comment_detail := harness.summarize_mod_comment_detail_response(adapter, {"payload": _fixture("comment_detail.json")})
	assert_eq(comment_detail.comment_id, 9002)
	assert_eq(comment_detail.username, "ThreadFriend")

	var comment_presence := harness.summarize_mod_comments_presence_response(adapter, {
		"payload": _fixture("comments_list.json")
	}, 5, 9002)
	assert_true(comment_presence.found_comment_id)

	var tag_presence := harness.summarize_mod_tags_presence_response(adapter, {
		"payload": _fixture("mod_tags.json")
	}, "Featured")
	assert_true(tag_presence.found_expected_tag)

	var metadata_presence := harness.summarize_mod_metadata_presence_response(adapter, {
		"payload": _fixture("mod_metadata_kvp.json")
	}, "difficulty=expert")
	assert_true(metadata_presence.found_expected_pair)

	var subscribed_presence := harness.summarize_user_subscriptions_presence_response(adapter, {
		"payload": _fixture("subscribed.json")
	}, 5, 1001)
	assert_true(subscribed_presence.found_expected_mod_id)

	var delete_summary := harness.summarize_no_content_write_response(adapter, {
		"status_code": 204,
		"headers": {}
	}, "deleted")
	assert_true(delete_summary.deleted)

func _stable_config(default_environment: String) -> String:
	return "".join([
		"[modio]\n",
		"default_environment=\"%s\"\n" % default_environment,
		"accept_language=\"en-US\"\n",
		"host_kind=\"api\"\n",
		"\n",
		"[modio.test]\n",
		"game_id=\"1001\"\n",
		"api_key=\"test-key\"\n",
		"base_url=\"\"\n",
		"service_token=\"\"\n",
		"portal=\"steam\"\n",
		"platform=\"WINDOWS\"\n",
		"monetization_team_id=\"\"\n",
		"\n",
		"[modio.live]\n",
		"game_id=\"2001\"\n",
		"api_key=\"live-key\"\n",
		"base_url=\"\"\n",
		"service_token=\"\"\n",
		"portal=\"steam\"\n",
		"platform=\"WINDOWS\"\n",
		"monetization_team_id=\"\"\n"
	])

func _session_config(environment: String, host_kind: String, access_token: String) -> String:
	return "".join([
		"[modio]\n",
		"environment=\"%s\"\n" % environment,
		"host_kind=\"%s\"\n" % host_kind,
		"\n",
		"[modio.test]\n",
		"access_token=\"%s\"\n" % access_token,
		"user_id=\"1111\"\n",
		"\n",
		"[modio.live]\n",
		"access_token=\"%s\"\n" % access_token,
		"user_id=\"2222\"\n"
	])

func _write_config(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func _cleanup_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _fixture(name: String) -> Dictionary:
	var path := "res://tests/fixtures/%s" % name
	var text := FileAccess.get_file_as_string(path)
	return JSON.parse_string(text)
