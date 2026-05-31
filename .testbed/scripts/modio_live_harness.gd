extends SceneTree

const ModioListingQuery = preload("res://addons/aerobeat-vendor-modio/src/models/modio_listing_query.gd")
const ModioVendorAdapter = preload("res://addons/aerobeat-vendor-modio/src/modio_vendor_adapter.gd")
const ModioHttpTransport = preload("res://addons/aerobeat-vendor-modio/src/network/modio_http_transport.gd")
const ModioLiveHarness = preload("res://scripts/modio_live_harness_lib.gd")

func _initialize() -> void:
	var harness := ModioLiveHarness.new()
	var options := harness.parse_args(OS.get_cmdline_user_args())
	var errors: PackedStringArray = options.get("errors", PackedStringArray())

	if bool(options.get("help", false)):
		print(harness.help_text())
		quit(0)
		return

	if not errors.is_empty():
		_print_failures(errors, bool(options.get("json", false)))
		quit(1)
		return

	var plan := harness.build_run_plan(options)
	var warnings := harness.build_missing_config_warnings(plan)
	if not warnings.is_empty():
		_print_failures(warnings, bool(options.get("json", false)))
		quit(1)
		return

	var config = plan.config
	var adapter := ModioVendorAdapter.new(config, ModioHttpTransport.new())
	var results: Array[Dictionary] = []

	results.append(_run_ping_check(adapter, config))
	results.append(_run_game_check(adapter, config))
	var mods_result := _run_mods_check(adapter, config, int(plan.get("mods_limit", 3)))
	results.append(mods_result)
	results.append_array(_run_public_mod_child_checks(adapter, config, mods_result))
	results.append(_run_terms_check(adapter, config))
	results.append_array(_run_optional_auth_checks(plan, adapter, config))
	results.append_array(_run_optional_paid_mods_sweep(plan, adapter, config))
	results.append_array(_run_optional_low_risk_write_sweep(plan, adapter, config, mods_result))

	var summary := {
		"environment": str(plan.get("environment", "")),
		"base_url": config.resolve_base_url(),
		"host_kind": config.host_kind,
		"game_id": config.game_id,
		"public_only": bool(options.get("public_only", false)),
		"allow_writes": bool(plan.get("allow_writes", false)),
		"paid_mods": bool(plan.get("paid_mods", false)),
		"allow_paid_writes": bool(plan.get("allow_paid_writes", false)),
		"checks": results,
		"ok": _results_are_ok(results)
	}

	if bool(options.get("json", false)):
		print(JSON.stringify(summary, "  "))
	else:
		_print_human_summary(summary)

	quit(0 if bool(summary.ok) else 1)

func _run_ping_check(adapter: ModioVendorAdapter, config) -> Dictionary:
	var harness := ModioLiveHarness.new()
	var request := adapter.build_ping_request()
	if config.has_public_credentials():
		var query: Dictionary = request.get("query", {}).duplicate(true)
		query["api_key"] = config.api_key
		request["query"] = query
	return _run_check(
		"ping",
		"Ping mod.io API",
		request,
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_ping_response(response)
	)

func _run_game_check(adapter: ModioVendorAdapter, config) -> Dictionary:
	var harness := ModioLiveHarness.new()
	return _run_check(
		"game",
		"Read configured game detail",
		adapter.build_game_request(),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_game_response(adapter, response)
	)

func _run_mods_check(adapter: ModioVendorAdapter, config, mods_limit: int) -> Dictionary:
	var harness := ModioLiveHarness.new()
	var query := ModioListingQuery.new("", PackedStringArray(), mods_limit, 0)
	return _run_check(
		"mods",
		"Browse configured game mods",
		adapter.build_listing_request(query),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_mods_response(adapter, response, mods_limit)
	)

func _run_terms_check(adapter: ModioVendorAdapter, config) -> Dictionary:
	var harness := ModioLiveHarness.new()
	return _run_check(
		"terms",
		"Read authentication terms",
		adapter.build_terms_request(),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_terms_response(adapter, response)
	)

func _run_public_mod_child_checks(adapter: ModioVendorAdapter, config, mods_result: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if str(mods_result.get("status", "")) != "ok":
		results.append(_skipped_check("mod_children", "Read first listed mod child endpoints", "Skipped because public mod listing failed"))
		return results

	var details: Dictionary = mods_result.get("details", {})
	var mod_id := int(details.get("selected_mod_id", 0))
	if mod_id <= 0:
		results.append(_skipped_check("mod_children", "Read first listed mod child endpoints", "Skipped because public mod listing returned no mod id"))
		return results

	var harness := ModioLiveHarness.new()
	var mod_id_text := str(mod_id)
	var child_query := ModioListingQuery.new("", PackedStringArray(), ModioLiveHarness.DEFAULT_CHILD_LIMIT, 0)
	results.append(_run_check(
		"mod_detail",
		"Read first listed public mod detail",
		adapter.build_mod_detail_request(mod_id_text),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_mod_detail_response(adapter, response)
	))
	var files_result := _run_check(
		"mod_files",
		"Read first listed public mod files",
		adapter.build_modfiles_request(mod_id_text, child_query),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_modfiles_response(adapter, response, ModioLiveHarness.DEFAULT_CHILD_LIMIT)
	)
	results.append(files_result)
	results.append_array(_run_optional_modfile_detail_check(adapter, config, mod_id_text, files_result))
	results.append(_run_check(
		"mod_stats",
		"Read first listed public mod stats",
		adapter.build_mod_stats_request(mod_id_text),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_mod_stats_response(adapter, response)
	))
	results.append(_run_check(
		"mod_dependants",
		"Read first listed public mod dependants",
		adapter.build_dependants_request(mod_id_text, child_query),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_dependants_response(adapter, response)
	))
	results.append(_run_check(
		"mod_tags",
		"Read first listed public mod tags",
		adapter.build_mod_tags_request(mod_id_text, child_query),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_mod_tags_response(adapter, response)
	))
	results.append(_run_check(
		"mod_metadata_kvp",
		"Read first listed public mod metadata KVP",
		adapter.build_mod_metadata_kvp_request(mod_id_text, child_query),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_mod_metadata_kvp_response(adapter, response)
	))
	results.append(_run_check(
		"mod_team",
		"Read first listed public mod team",
		adapter.build_mod_team_request(mod_id_text, child_query),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_mod_team_response(adapter, response)
	))
	results.append(_run_check(
		"mod_dependencies",
		"Read first listed public mod dependencies",
		adapter.build_dependencies_request(mod_id_text, false),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_dependencies_response(adapter, response)
	))
	return results

func _run_optional_modfile_detail_check(adapter: ModioVendorAdapter, config, mod_id: String, files_result: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if str(files_result.get("status", "")) != "ok":
		results.append(_skipped_check("mod_file_detail", "Read first listed public mod file detail", "Skipped because public mod files request failed"))
		return results

	var details: Dictionary = files_result.get("details", {})
	var file_id := int(details.get("selected_file_id", 0))
	if file_id <= 0:
		results.append(_skipped_check("mod_file_detail", "Read first listed public mod file detail", "Skipped because public mod files returned no file id"))
		return results

	var harness := ModioLiveHarness.new()
	results.append(_run_check(
		"mod_file_detail",
		"Read first listed public mod file detail",
		adapter.build_modfile_request(mod_id, str(file_id)),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_modfile_response(adapter, response)
	))
	return results

func _run_optional_auth_checks(plan: Dictionary, adapter: ModioVendorAdapter, config) -> Array[Dictionary]:
	var harness := ModioLiveHarness.new()
	var results: Array[Dictionary] = []
	for check in plan.get("checks", []):
		if not (check is Dictionary):
			continue
		if str(check.get("id", "")) != "me":
			continue
		if bool(check.get("skip", false)):
			results.append(_skipped_check(
				"me",
				str(check.get("label", "Read authenticated user profile")),
				str(check.get("skip_reason", "Skipped"))
			))
			results.append(_skipped_check("me_user_reads", "Run authenticated user-read sweep", str(check.get("skip_reason", "Skipped"))))
			continue
		var me_result := _run_check(
			"me",
			"Read authenticated user profile",
			adapter.build_authenticated_user_request(),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_authenticated_user_response(adapter, response)
		)
		results.append(me_result)
		results.append_array(_run_authenticated_user_read_sweep(adapter, config, me_result))
	return results

func _run_authenticated_user_read_sweep(adapter: ModioVendorAdapter, config, me_result: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if str(me_result.get("status", "")) != "ok":
		results.append(_skipped_check("me_user_reads", "Run authenticated user-read sweep", "Skipped because authenticated /me failed"))
		return results

	var harness := ModioLiveHarness.new()
	var query := ModioListingQuery.new("", PackedStringArray(), ModioLiveHarness.DEFAULT_USER_LIMIT, 0)
	results.append(_run_check(
		"me_games",
		"Read authenticated user games",
		adapter.build_user_games_request(query),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_user_games_response(adapter, response, ModioLiveHarness.DEFAULT_USER_LIMIT)
	))
	results.append(_run_check(
		"me_mods",
		"Read authenticated user mods",
		adapter.build_user_mods_request(query),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_user_mods_response(adapter, response, ModioLiveHarness.DEFAULT_USER_LIMIT)
	))
	results.append(_run_check(
		"me_files",
		"Read authenticated user files",
		adapter.build_user_modfiles_request(query),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_user_modfiles_response(adapter, response, ModioLiveHarness.DEFAULT_USER_LIMIT)
	))
	results.append(_run_check(
		"me_subscribed",
		"Read authenticated user subscriptions",
		adapter.build_user_subscriptions_request(query),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_user_subscriptions_response(adapter, response, ModioLiveHarness.DEFAULT_USER_LIMIT)
	))
	results.append(_run_check(
		"me_ratings",
		"Read authenticated user ratings",
		adapter.build_user_ratings_request(query),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_user_ratings_response(adapter, response, ModioLiveHarness.DEFAULT_USER_LIMIT)
	))
	results.append(_run_check(
		"me_collections",
		"Read authenticated user collections",
		adapter.build_me_collections_request(query),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_me_collections_response(adapter, response, ModioLiveHarness.DEFAULT_USER_LIMIT)
	))
	results.append(_run_check(
		"me_following_collections",
		"Read authenticated user followed collections",
		adapter.build_followed_collections_request(query),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_followed_collections_response(adapter, response, ModioLiveHarness.DEFAULT_USER_LIMIT)
	))
	results.append(_run_check(
		"me_followers",
		"Read authenticated user followers",
		adapter.build_me_followers_request(query),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_me_followers_response(adapter, response, ModioLiveHarness.DEFAULT_USER_LIMIT)
	))
	results.append(_run_check(
		"me_muted_users",
		"Read authenticated muted users",
		adapter.build_muted_users_request(query),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_muted_users_response(adapter, response, ModioLiveHarness.DEFAULT_USER_LIMIT)
	))

	var me_details: Dictionary = me_result.get("details", {})
	var me_id := int(me_details.get("id", 0))
	if me_id <= 0:
		results.append(_skipped_check("user_social_reads", "Read derived /users/{me-id} social + collections", "Skipped because authenticated /me returned no user id"))
		return results

	var me_id_text := str(me_id)
	results.append(_run_check(
		"user_followers",
		"Read /users/{me-id}/followers",
		adapter.build_user_followers_request(me_id_text, query),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_user_followers_response(adapter, response, ModioLiveHarness.DEFAULT_USER_LIMIT)
	))
	results.append(_run_check(
		"user_following",
		"Read /users/{me-id}/following",
		adapter.build_user_following_request(me_id_text, query),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_user_following_response(adapter, response, ModioLiveHarness.DEFAULT_USER_LIMIT)
	))
	results.append(_run_check(
		"user_collections",
		"Read /users/{me-id}/collections",
		adapter.build_user_collections_request(me_id_text, query),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_user_collections_response(adapter, response, ModioLiveHarness.DEFAULT_USER_LIMIT)
	))
	return results

func _run_optional_paid_mods_sweep(plan: Dictionary, adapter: ModioVendorAdapter, config) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not bool(plan.get("paid_mods", false)):
		return results

	var harness := ModioLiveHarness.new()
	var user_query := ModioListingQuery.new("", PackedStringArray(), ModioLiveHarness.DEFAULT_USER_LIMIT, 0)
	if config.has_access_token():
		results.append(_run_check(
			"paid_token_packs",
			"Read game monetization token packs",
			adapter.build_game_token_packs_request(),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_game_token_packs_response(adapter, response, ModioLiveHarness.DEFAULT_CHILD_LIMIT)
		))
		results.append(_run_check(
			"paid_wallet",
			"Read authenticated user wallet",
			adapter.build_user_wallet_request(),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_user_wallet_response(adapter, response)
		))
		results.append(_run_check(
			"paid_purchased",
			"Read authenticated user purchased paid mods",
			adapter.build_user_purchased_request(user_query),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_user_purchased_response(adapter, response, ModioLiveHarness.DEFAULT_USER_LIMIT)
		))
		var owned_mod_id: String = config.resolve_owned_mod_id()
		if owned_mod_id.is_empty():
			results.append(_skipped_check("paid_monetization_team", "Read owned paid-mod monetization team", "Skipped because owned_mod_id or paid_mod_id is not configured"))
		else:
			results.append(_run_check(
				"paid_monetization_team",
				"Read owned paid-mod monetization team",
				adapter.build_mod_monetization_team_request(owned_mod_id),
				config,
				func(response: Dictionary) -> Dictionary:
					return harness.summarize_mod_monetization_team_response(adapter, response, ModioLiveHarness.DEFAULT_CHILD_LIMIT)
			))
	else:
		var missing_access_reason := "Skipped because no access token is configured in session config"
		results.append(_skipped_check("paid_token_packs", "Read game monetization token packs", missing_access_reason))
		results.append(_skipped_check("paid_wallet", "Read authenticated user wallet", missing_access_reason))
		results.append(_skipped_check("paid_purchased", "Read authenticated user purchased paid mods", missing_access_reason))
		results.append(_skipped_check("paid_monetization_team", "Read owned paid-mod monetization team", missing_access_reason))

	if not bool(plan.get("allow_paid_writes", false)):
		var disabled_reason := "Skipped unless --allow-paid-writes is explicitly enabled"
		results.append(_skipped_check("paid_entitlements", "Run paid entitlement sync", disabled_reason))
		results.append(_skipped_check("paid_checkout", "Run paid checkout", disabled_reason))
	else:
		results.append(_run_paid_entitlements_check(adapter, config))
		results.append(_run_paid_checkout_check(adapter, config))

	if config.has_service_token():
		var s2s_filters_input: Dictionary = config.paid_s2s_filters_input.duplicate(true)
		var s2s_filters: Dictionary = _extract_guarded_fields(s2s_filters_input, ["monetization_team_id"])
		var s2s_team_id := str(s2s_filters_input.get("monetization_team_id", ""))
		var s2s_transactions_result := _run_check(
			"paid_s2s_transactions",
			"Read S2S monetization-team transaction history",
			adapter.build_s2s_monetization_transactions_request(s2s_filters, s2s_team_id),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_s2s_transactions_response(adapter, response, ModioLiveHarness.DEFAULT_CHILD_LIMIT)
		)
		results.append(s2s_transactions_result)
		var transaction_id: String = config.s2s_transaction_id
		if transaction_id.is_empty():
			transaction_id = str(s2s_transactions_result.get("details", {}).get("selected_transaction_id", 0))
		if str(s2s_transactions_result.get("status", "")) != "ok":
			results.append(_skipped_check("paid_s2s_transaction", "Read one S2S monetization transaction", "Skipped because S2S monetization-team transaction history failed"))
		elif transaction_id.is_empty() or transaction_id == "0":
			results.append(_skipped_check("paid_s2s_transaction", "Read one S2S monetization transaction", "Skipped because no s2s_transaction_id was configured and the list response returned no transaction id"))
		else:
			results.append(_run_check(
				"paid_s2s_transaction",
				"Read one S2S monetization transaction",
				adapter.build_s2s_monetization_transaction_request(transaction_id, s2s_team_id),
				config,
				func(response: Dictionary) -> Dictionary:
					return harness.summarize_s2s_transaction_response(adapter, response)
			))
	else:
		var missing_service_reason := "Skipped because no service_token is configured in stable config"
		results.append(_skipped_check("paid_s2s_transactions", "Read S2S monetization-team transaction history", missing_service_reason))
		results.append(_skipped_check("paid_s2s_transaction", "Read one S2S monetization transaction", missing_service_reason))

	var paid_team_write_reason := "Skipped by default; this write stays behind explicit collaborator-fixture opt-in guard"
	if bool(plan.get("allow_paid_team_write", false)):
		paid_team_write_reason = "Skipped because monetization-team write execution is not wired in the harness yet; the flag currently reserves the opt-in lane only"
	results.append(_skipped_check(
		"paid_team_write",
		"Create/update paid-mod monetization team",
		paid_team_write_reason
	))
	var paid_s2s_writes_reason := "Skipped by default; these service-token writes stay behind explicit opt-in guards"
	if bool(plan.get("allow_paid_s2s_writes", false)):
		paid_s2s_writes_reason = "Skipped because S2S intent/commit/clawback execution is not wired in the harness yet; the flag currently reserves the opt-in lane only"
	results.append(_skipped_check(
		"paid_s2s_writes",
		"Run S2S monetization intent/commit/clawback writes",
		paid_s2s_writes_reason
	))
	return results

func _run_paid_entitlements_check(adapter: ModioVendorAdapter, config) -> Dictionary:
	if not config.has_access_token():
		return _skipped_check("paid_entitlements", "Run paid entitlement sync", "Skipped because no access token is configured in session config")
	var payload: Dictionary = config.paid_entitlements_input.duplicate(true)
	if payload.is_empty():
		return _skipped_check("paid_entitlements", "Run paid entitlement sync", "Skipped because entitlements_payload_json is empty in the session config")
	var portal := str(payload.get("portal", ""))
	var platform := str(payload.get("platform", ""))
	var fields := _extract_guarded_fields(payload, ["portal", "platform"])
	var harness := ModioLiveHarness.new()
	return _run_check(
		"paid_entitlements",
		"Run paid entitlement sync",
		adapter.build_user_entitlements_request(fields, portal, platform),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_user_entitlements_response(adapter, response, ModioLiveHarness.DEFAULT_USER_LIMIT)
	)

func _run_paid_checkout_check(adapter: ModioVendorAdapter, config) -> Dictionary:
	if not config.has_access_token():
		return _skipped_check("paid_checkout", "Run paid checkout", "Skipped because no access token is configured in session config")
	var payload: Dictionary = config.paid_checkout_input.duplicate(true)
	if payload.is_empty():
		return _skipped_check("paid_checkout", "Run paid checkout", "Skipped because checkout_payload_json is empty in the session config")
	var portal := str(payload.get("portal", ""))
	var platform := str(payload.get("platform", ""))
	var mod_id: String = config.resolve_paid_mod_id(str(payload.get("mod_id", "")))
	if mod_id.is_empty():
		return _skipped_check("paid_checkout", "Run paid checkout", "Skipped because paid_mod_id or checkout_payload_json.mod_id is not configured")
	var fields := _extract_guarded_fields(payload, ["portal", "platform", "mod_id"])
	var harness := ModioLiveHarness.new()
	return _run_check(
		"paid_checkout",
		"Run paid checkout",
		adapter.build_checkout_request(mod_id, fields, portal, platform),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_checkout_response(adapter, response)
	)

func _extract_guarded_fields(payload: Dictionary, reserved_keys: Array[String]) -> Dictionary:
	var explicit_fields = payload.get("fields", null)
	if explicit_fields is Dictionary:
		return explicit_fields.duplicate(true)
	var fields := payload.duplicate(true)
	for key in reserved_keys:
		fields.erase(key)
	return fields

func _run_optional_low_risk_write_sweep(plan: Dictionary, adapter: ModioVendorAdapter, config, mods_result: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not bool(plan.get("allow_writes", false)):
		return results
	if not config.has_access_token():
		results.append(_skipped_check("write_sweep", "Run low-risk authenticated write sweep", "Skipped because no access token is configured"))
		return results
	if str(mods_result.get("status", "")) != "ok":
		results.append(_skipped_check("write_sweep", "Run low-risk authenticated write sweep", "Skipped because public mod listing failed"))
		return results

	var mod_id := int(mods_result.get("details", {}).get("selected_mod_id", 0))
	if mod_id <= 0:
		results.append(_skipped_check("write_sweep", "Run low-risk authenticated write sweep", "Skipped because no public sandbox mod was available"))
		return results

	var harness := ModioLiveHarness.new()
	var mod_id_text := str(mod_id)
	var user_query := ModioListingQuery.new("", PackedStringArray(), ModioLiveHarness.DEFAULT_USER_LIMIT, 0)
	var comment_query := ModioListingQuery.new("", PackedStringArray(), ModioLiveHarness.DEFAULT_CHILD_LIMIT, 0)
	var sweep_suffix := str(Time.get_unix_time_from_system())
	var tag_name := "oc-vrf-tag-%s" % sweep_suffix
	var metadata_pair := "oc-vrf:%s" % sweep_suffix
	var rating_value := 1
	var comment_create_content := "oc-vrf sandbox comment create %s" % sweep_suffix
	var comment_update_content := "oc-vrf sandbox comment update %s" % sweep_suffix

	results.append(_run_check(
		"write_subscribe",
		"Subscribe to the sample sandbox mod",
		adapter.build_subscribe_request(mod_id_text),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_subscription_write_response(adapter, response)
	))
	results.append(_run_check(
		"write_subscribed_read",
		"Verify subscription via authenticated user subscriptions",
		adapter.build_user_subscriptions_request(user_query),
		config,
		func(response: Dictionary) -> Dictionary:
			var summary := harness.summarize_user_subscriptions_presence_response(adapter, response, ModioLiveHarness.DEFAULT_USER_LIMIT, mod_id)
			summary["expected_present"] = bool(summary.get("found_expected_mod_id", false))
			return summary
	))
	results.append(_run_check(
		"write_unsubscribe",
		"Unsubscribe from the sample sandbox mod",
		adapter.build_unsubscribe_request(mod_id_text),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_no_content_write_response(adapter, response, "unsubscribed")
	))
	results.append(_run_check(
		"write_subscribed_read_after_delete",
		"Verify subscription removal via authenticated user subscriptions",
		adapter.build_user_subscriptions_request(user_query),
		config,
		func(response: Dictionary) -> Dictionary:
			var summary := harness.summarize_user_subscriptions_presence_response(adapter, response, ModioLiveHarness.DEFAULT_USER_LIMIT, mod_id)
			summary["expected_absent"] = not bool(summary.get("found_expected_mod_id", false))
			return summary
	))
	var add_rating_result := _run_check(
		"write_rating",
		"Apply a positive rating to the sample sandbox mod",
		adapter.build_add_mod_rating_request(mod_id_text, rating_value),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_message_write_response(adapter, response)
	)
	if str(add_rating_result.get("status", "")) == "failed" and int(add_rating_result.get("details", {}).get("error_ref", 0)) == 15028:
		results.append(_skipped_check("write_rating", "Apply a positive rating to the sample sandbox mod", "Skipped because the sandbox already holds the same positive rating for this workout"))
	else:
		results.append(add_rating_result)
	results.append(_run_check(
		"write_ratings_read",
		"Verify rating via authenticated user ratings",
		adapter.build_user_ratings_request(user_query),
		config,
		func(response: Dictionary) -> Dictionary:
			var summary := harness.summarize_user_ratings_presence_response(adapter, response, ModioLiveHarness.DEFAULT_USER_LIMIT, mod_id, rating_value)
			summary["expected_present"] = bool(summary.get("found_expected_rating", false))
			return summary
	))

	var create_comment_result := _run_check(
		"write_comment_create",
		"Create a sandbox mod comment",
		adapter.build_add_mod_comment_request(mod_id_text, comment_create_content),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_mod_comment_write_response(adapter, response)
	)
	if str(create_comment_result.get("status", "")) == "failed" and int(create_comment_result.get("details", {}).get("error_ref", 0)) == 14038:
		results.append(_skipped_check("write_comment_create", "Create a sandbox mod comment", "Skipped because the sandbox has mod comments disabled for this workout"))
		results.append(_skipped_check("write_comment_followups", "Verify/update/delete sandbox mod comment", "Skipped because the sandbox has mod comments disabled for this workout"))
	else:
		results.append(create_comment_result)
		var comment_id := int(create_comment_result.get("details", {}).get("comment_id", 0)) if str(create_comment_result.get("status", "")) == "ok" else 0
		if comment_id <= 0:
			results.append(_skipped_check("write_comment_followups", "Verify/update/delete sandbox mod comment", "Skipped because comment creation did not return an id"))
		else:
			var comment_id_text := str(comment_id)
			results.append(_run_check(
				"write_comment_detail",
				"Read back the created sandbox mod comment",
				adapter.build_mod_comment_request(mod_id_text, comment_id_text),
				config,
				func(response: Dictionary) -> Dictionary:
					return harness.summarize_mod_comment_detail_response(adapter, response)
			))
			results.append(_run_check(
				"write_comment_list",
				"Verify the created sandbox mod comment appears in the comment list",
				adapter.build_mod_comments_request(mod_id_text, comment_query),
				config,
				func(response: Dictionary) -> Dictionary:
					var summary := harness.summarize_mod_comments_presence_response(adapter, response, ModioLiveHarness.DEFAULT_CHILD_LIMIT, comment_id)
					summary["expected_present"] = bool(summary.get("found_comment_id", false))
					return summary
			))
			results.append(_run_check(
				"write_comment_update",
				"Update the created sandbox mod comment",
				adapter.build_update_mod_comment_request(mod_id_text, comment_id_text, comment_update_content),
				config,
				func(response: Dictionary) -> Dictionary:
					return harness.summarize_mod_comment_write_response(adapter, response)
			))
			results.append(_run_check(
				"write_comment_detail_after_update",
				"Verify the updated sandbox mod comment",
				adapter.build_mod_comment_request(mod_id_text, comment_id_text),
				config,
				func(response: Dictionary) -> Dictionary:
					return harness.summarize_mod_comment_detail_response(adapter, response)
			))
			results.append(_run_check(
				"write_comment_delete",
				"Delete the created sandbox mod comment",
				adapter.build_delete_mod_comment_request(mod_id_text, comment_id_text),
				config,
				func(response: Dictionary) -> Dictionary:
					return harness.summarize_no_content_write_response(adapter, response, "deleted")
			))
			results.append(_run_check(
				"write_comment_list_after_delete",
				"Verify the deleted sandbox mod comment is gone from the comment list",
				adapter.build_mod_comments_request(mod_id_text, comment_query),
				config,
				func(response: Dictionary) -> Dictionary:
					var summary := harness.summarize_mod_comments_presence_response(adapter, response, ModioLiveHarness.DEFAULT_CHILD_LIMIT, comment_id)
					summary["expected_absent"] = not bool(summary.get("found_comment_id", false))
					return summary
			))

	var add_tag_result := _run_check(
		"write_tag_add",
		"Add a sandbox tag to the sample mod",
		adapter.build_add_mod_tags_request(mod_id_text, {"tags": [tag_name]}),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_message_write_response(adapter, response, "created")
	)
	if str(add_tag_result.get("status", "")) == "failed" and int(add_tag_result.get("details", {}).get("error_ref", 0)) == 13009:
		results.append(_skipped_check("write_tag_add", "Add a sandbox tag to the sample mod", "Skipped because the sandbox rejected freeform mod tag writes for this workout"))
		results.append(_skipped_check("write_tag_followups", "Verify/delete sandbox mod tags", "Skipped because the sandbox rejected freeform mod tag writes for this workout"))
	else:
		results.append(add_tag_result)
		results.append(_run_check(
			"write_tag_read",
			"Verify the sandbox tag via mod tags readback",
			adapter.build_mod_tags_request(mod_id_text, comment_query),
			config,
			func(response: Dictionary) -> Dictionary:
				var summary := harness.summarize_mod_tags_presence_response(adapter, response, tag_name)
				summary["expected_present"] = bool(summary.get("found_expected_tag", false))
				return summary
		))
		results.append(_run_check(
			"write_tag_delete",
			"Delete the sandbox tag from the sample mod",
			adapter.build_delete_mod_tags_request(mod_id_text, {"tags": [tag_name]}),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_no_content_write_response(adapter, response, "deleted")
		))
		results.append(_run_check(
			"write_tag_read_after_delete",
			"Verify the sandbox tag was removed",
			adapter.build_mod_tags_request(mod_id_text, comment_query),
			config,
			func(response: Dictionary) -> Dictionary:
				var summary := harness.summarize_mod_tags_presence_response(adapter, response, tag_name)
				summary["expected_absent"] = not bool(summary.get("found_expected_tag", false))
				return summary
		))

	results.append(_run_check(
		"write_metadata_add",
		"Add sandbox metadata KVP to the sample mod",
		adapter.build_add_mod_metadata_kvp_request(mod_id_text, {"metadata": [metadata_pair]}),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_message_write_response(adapter, response, "created")
	))
	results.append(_run_check(
		"write_metadata_read",
		"Verify sandbox metadata KVP via readback",
		adapter.build_mod_metadata_kvp_request(mod_id_text, comment_query),
		config,
		func(response: Dictionary) -> Dictionary:
			var summary := harness.summarize_mod_metadata_presence_response(adapter, response, metadata_pair.replace(":", "="))
			summary["expected_present"] = bool(summary.get("found_expected_pair", false))
			return summary
	))
	results.append(_run_check(
		"write_metadata_delete",
		"Delete sandbox metadata KVP from the sample mod",
		adapter.build_delete_mod_metadata_kvp_request(mod_id_text, {"metadata": [metadata_pair]}),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_no_content_write_response(adapter, response, "deleted")
	))
	results.append(_run_check(
		"write_metadata_read_after_delete",
		"Verify sandbox metadata KVP was removed",
		adapter.build_mod_metadata_kvp_request(mod_id_text, comment_query),
		config,
		func(response: Dictionary) -> Dictionary:
			var summary := harness.summarize_mod_metadata_presence_response(adapter, response, metadata_pair.replace(":", "="))
			summary["expected_absent"] = not bool(summary.get("found_expected_pair", false))
			return summary
	))

	results.append(_skipped_check(
		"write_dependencies",
		"Run dependency maintenance on the sample mod",
		"Skipped because the sandbox currently exposes only one safe owned mod, so there is no second reversible dependency target yet"
	))
	return results

func _run_check(id: String, label: String, request: Dictionary, config, detail_builder: Callable) -> Dictionary:
	var transport := ModioHttpTransport.new()
	var response := transport.execute(request, config)
	if bool(response.get("ok", false)):
		return {
			"id": id,
			"label": label,
			"status": "ok",
			"status_code": int(response.get("status_code", 0)),
			"details": detail_builder.call(response) if detail_builder.is_valid() else {}
		}

	var error_info: Dictionary = response.get("error", {})
	return {
		"id": id,
		"label": label,
		"status": "failed",
		"status_code": int(response.get("status_code", 0)),
		"details": {
			"message": str(error_info.get("message", response.get("transport_error", "Unknown error"))),
			"category": str(error_info.get("category", "transport")),
			"error_ref": int(error_info.get("error_ref", 0))
		}
	}

func _skipped_check(id: String, label: String, reason: String) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"status": "skipped",
		"details": {"reason": reason}
	}

func _results_are_ok(results: Array[Dictionary]) -> bool:
	for result in results:
		if str(result.get("status", "")) == "failed":
			return false
	return true

func _print_human_summary(summary: Dictionary) -> void:
	print("mod.io safe harness")
	print("  environment: %s" % str(summary.get("environment", "")))
	print("  host_kind: %s" % str(summary.get("host_kind", "")))
	print("  base_url: %s" % str(summary.get("base_url", "")))
	print("  game_id: %s" % str(summary.get("game_id", "")))
	print("  allow_writes: %s" % str(summary.get("allow_writes", false)))
	for check in summary.get("checks", []):
		if not (check is Dictionary):
			continue
		print("  [%s] %s" % [str(check.get("status", "unknown")).to_upper(), str(check.get("label", check.get("id", "check")))])
		var details: Dictionary = check.get("details", {})
		for key in details.keys():
			print("    %s: %s" % [str(key), str(details[key])])

func _print_failures(messages: PackedStringArray, as_json: bool) -> void:
	if as_json:
		print(JSON.stringify({"ok": false, "errors": messages}, "  "))
		return
	for message in messages:
		push_error(message)
		print(message)
