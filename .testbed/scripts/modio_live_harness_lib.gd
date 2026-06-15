extends RefCounted

const ModioClientConfig = preload("res://src/models/modio_client_config.gd")
const ModioEnvLoader = preload("res://modio_env_loader.gd")

const DEFAULT_MODS_LIMIT := 3
const DEFAULT_CHILD_LIMIT := 5
const DEFAULT_USER_LIMIT := 5

func summarize_ping_response(response: Dictionary) -> Dictionary:
	var payload: Dictionary = response.get("payload", {})
	return {"message": str(payload.get("message", ""))}

func summarize_game_response(adapter, response: Dictionary) -> Dictionary:
	var payload: Dictionary = response.get("payload", {})
	var data: Dictionary = adapter.normalize_game_response(payload)
	return {
		"id": int(data.get("id", 0)),
		"name": str(data.get("name", "")),
		"status": int(payload.get("status", -1))
	}

func summarize_mods_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_MODS_LIMIT) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_mod_list_response(response.get("payload", {}))
	var sample_mod_names: PackedStringArray = []
	var selected_mod_id := 0
	for entry in normalized.get("data", []):
		if not (entry is Dictionary):
			continue
		if sample_mod_names.size() >= requested_limit:
			break
		sample_mod_names.append(str(entry.get("name", "")))
		if selected_mod_id <= 0:
			selected_mod_id = int(entry.get("id", 0))
	return {
		"sample_mod_names": sample_mod_names,
		"selected_mod_id": selected_mod_id,
		"requested_limit": requested_limit,
		"response_result_count": int(normalized.get("result_count", 0)),
		"response_result_limit": int(normalized.get("result_limit", 0)),
		"response_result_offset": int(normalized.get("result_offset", 0)),
		"response_result_total": int(normalized.get("result_total", 0))
	}

func summarize_mod_detail_response(adapter, response: Dictionary) -> Dictionary:
	var data: Dictionary = adapter.normalize_mod_detail_response(response.get("payload", {}))
	var community_options := int(data.get("community_options", 0))
	return {
		"id": int(data.get("id", 0)),
		"name": str(data.get("name", "")),
		"name_id": str(data.get("name_id", "")),
		"status": int(data.get("status", 0)),
		"visible": int(data.get("visible", 0)),
		"community_options": community_options,
		"allows_collections": (community_options & 131072) != 0
	}

func summarize_modfiles_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_CHILD_LIMIT) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_modfiles_response(response.get("payload", {}))
	var sample_filenames: PackedStringArray = []
	var selected_file_id := 0
	for entry in normalized.get("data", []):
		if not (entry is Dictionary):
			continue
		if sample_filenames.size() >= requested_limit:
			break
		sample_filenames.append(str(entry.get("filename", "")))
		if selected_file_id <= 0:
			selected_file_id = int(entry.get("id", 0))
	return {
		"sample_filenames": sample_filenames,
		"selected_file_id": selected_file_id,
		"response_result_count": int(normalized.get("result_count", 0)),
		"response_result_limit": int(normalized.get("result_limit", 0)),
		"response_result_offset": int(normalized.get("result_offset", 0)),
		"response_result_total": int(normalized.get("result_total", 0))
	}

func summarize_modfile_response(adapter, response: Dictionary) -> Dictionary:
	var data: Dictionary = adapter.normalize_modfile_response(response.get("payload", {}))
	return {
		"id": int(data.get("id", 0)),
		"filename": str(data.get("filename", "")),
		"version": str(data.get("version", "")),
		"filesize": int(data.get("filesize", 0))
	}

func summarize_mod_stats_response(adapter, response: Dictionary) -> Dictionary:
	var data: Dictionary = adapter.normalize_mod_stats_response(response.get("payload", {}))
	return {
		"mod_id": int(data.get("mod_id", 0)),
		"downloads_total": int(data.get("downloads_total", 0)),
		"subscribers_total": int(data.get("subscribers_total", 0)),
		"ratings_total": int(data.get("ratings_total", 0)),
		"has_expiry": bool(data.get("has_expiry", false)),
		"is_stale": bool(data.get("is_stale", false))
	}

func summarize_dependants_response(adapter, response: Dictionary) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_dependants_response(response.get("payload", {}))
	var first_name := ""
	var data = normalized.get("data", [])
	if data is Array and not data.is_empty() and data[0] is Dictionary:
		first_name = str(data[0].get("name", ""))
	return {
		"first_name": first_name,
		"response_result_count": int(normalized.get("result_count", 0)),
		"response_result_limit": int(normalized.get("result_limit", 0)),
		"response_result_offset": int(normalized.get("result_offset", 0)),
		"response_result_total": int(normalized.get("result_total", 0))
	}

func summarize_mod_tags_response(adapter, response: Dictionary) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_mod_tags_response(response.get("payload", {}))
	var names: PackedStringArray = []
	for entry in normalized.get("data", []):
		if entry is Dictionary:
			names.append(str(entry.get("name", "")))
	return {
		"names": names,
		"response_result_count": int(normalized.get("result_count", 0)),
		"response_result_limit": int(normalized.get("result_limit", 0)),
		"response_result_offset": int(normalized.get("result_offset", 0)),
		"response_result_total": int(normalized.get("result_total", 0))
	}

func summarize_mod_metadata_kvp_response(adapter, response: Dictionary) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_mod_metadata_kvp_response(response.get("payload", {}))
	var pairs: Array[String] = []
	for entry in normalized.get("data", []):
		if entry is Dictionary:
			pairs.append("%s=%s" % [str(entry.get("metakey", "")), str(entry.get("metavalue", ""))])
	return {
		"pairs": pairs,
		"response_result_count": int(normalized.get("result_count", 0)),
		"response_result_limit": int(normalized.get("result_limit", 0)),
		"response_result_offset": int(normalized.get("result_offset", 0)),
		"response_result_total": int(normalized.get("result_total", 0))
	}

func summarize_mod_team_response(adapter, response: Dictionary) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_mod_team_response(response.get("payload", {}))
	var usernames: PackedStringArray = []
	for entry in normalized.get("data", []):
		if not (entry is Dictionary):
			continue
		var user: Dictionary = entry.get("user", {})
		usernames.append(str(user.get("username", "")))
	return {
		"usernames": usernames,
		"response_result_count": int(normalized.get("result_count", 0)),
		"response_result_limit": int(normalized.get("result_limit", 0)),
		"response_result_offset": int(normalized.get("result_offset", 0)),
		"response_result_total": int(normalized.get("result_total", 0))
	}

func summarize_dependencies_response(adapter, response: Dictionary) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_dependencies_response(response.get("payload", {}), false)
	var names: PackedStringArray = []
	for entry in normalized.get("data", []):
		if entry is Dictionary:
			names.append(str(entry.get("name", "")))
	return {
		"names": names,
		"response_result_count": int(normalized.get("result_count", 0)),
		"response_result_limit": int(normalized.get("result_limit", 0)),
		"response_result_offset": int(normalized.get("result_offset", 0)),
		"response_result_total": int(normalized.get("result_total", 0)),
		"recursive_requested": bool(normalized.get("resolution", {}).get("recursive_requested", false))
	}

func summarize_authenticated_user_response(adapter, response: Dictionary) -> Dictionary:
	var payload: Dictionary = response.get("payload", {})
	var data: Dictionary = adapter.normalize_authenticated_user_response(payload)
	return {
		"id": int(data.get("id", 0)),
		"username": str(data.get("username", "")),
		"name_id": str(data.get("name_id", ""))
	}

func summarize_terms_response(adapter, response: Dictionary) -> Dictionary:
	var data: Dictionary = adapter.normalize_terms_response(response.get("payload", {}))
	var required_links: PackedStringArray = []
	for key in data.get("links", {}).keys():
		var link: Dictionary = data.links.get(key, {})
		if bool(link.get("required", false)):
			required_links.append(str(key))
	required_links.sort()
	return {
		"plaintext_length": str(data.get("plaintext", "")).length(),
		"buttons": PackedStringArray(data.get("buttons", {}).keys()),
		"required_links": required_links
	}

func summarize_guides_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_CHILD_LIMIT) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_guides_response(response.get("payload", {}))
	var names: PackedStringArray = []
	var selected_guide_id := 0
	for entry in normalized.get("data", []):
		if not (entry is Dictionary):
			continue
		if names.size() >= requested_limit:
			break
		names.append(str(entry.get("name", "")))
		if selected_guide_id <= 0:
			selected_guide_id = int(entry.get("id", 0))
	return _list_result_summary(normalized, requested_limit, {
		"guide_names": names,
		"selected_guide_id": selected_guide_id
	})

func summarize_guide_response(adapter, response: Dictionary) -> Dictionary:
	var data: Dictionary = adapter.normalize_guide_response(response.get("payload", {}))
	return {
		"id": int(data.get("id", 0)),
		"name": str(data.get("name", "")),
		"name_id": str(data.get("name_id", "")),
		"status": int(data.get("status", 0)),
		"allows_comments": bool(data.get("allows_comments", false)),
		"comments_total": int(data.get("comments_total", 0))
	}

func summarize_guide_tags_response(adapter, response: Dictionary) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_guide_tags_response(response.get("payload", {}))
	var names: PackedStringArray = []
	for entry in normalized.get("data", []):
		if entry is Dictionary:
			names.append(str(entry.get("name", "")))
	return _list_result_summary(normalized, DEFAULT_CHILD_LIMIT, {
		"names": names
	})

func summarize_guide_comment_write_response(adapter, response: Dictionary) -> Dictionary:
	var data: Dictionary = adapter.normalize_guide_comment_write_response(response.get("payload", {}))
	var user: Dictionary = data.get("user", {})
	return {
		"comment_id": int(data.get("id", 0)),
		"reply_id": int(data.get("reply_id", 0)),
		"content": str(data.get("content", "")),
		"username": str(user.get("username", ""))
	}

func summarize_guide_comment_detail_response(adapter, response: Dictionary) -> Dictionary:
	var data: Dictionary = adapter.normalize_guide_comment_response(response.get("payload", {}))
	var user: Dictionary = data.get("user", {})
	return {
		"comment_id": int(data.get("id", 0)),
		"reply_id": int(data.get("reply_id", 0)),
		"content": str(data.get("content", "")),
		"username": str(user.get("username", ""))
	}

func summarize_guide_comments_presence_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_CHILD_LIMIT, expected_comment_id: int = 0) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_guide_comments_response(response.get("payload", {}))
	var ids: Array[int] = []
	var found_comment_id := false
	for entry in normalized.get("data", []):
		if not (entry is Dictionary):
			continue
		var comment_id := int(entry.get("id", 0))
		ids.append(comment_id)
		if expected_comment_id > 0 and comment_id == expected_comment_id:
			found_comment_id = true
	return _list_result_summary(normalized, requested_limit, {
		"comment_ids": ids,
		"found_comment_id": found_comment_id
	})

func summarize_user_games_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_USER_LIMIT) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_user_games_response(response.get("payload", {}))
	var first := _first_dictionary(normalized.get("data", []))
	return _list_result_summary(normalized, requested_limit, {
		"id": int(first.get("id", 0)),
		"name": str(first.get("name", "")),
		"name_id": str(first.get("name_id", ""))
	})

func summarize_user_mods_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_USER_LIMIT) -> Dictionary:
	var summary := summarize_mods_response(adapter, response, requested_limit)
	var normalized: Dictionary = adapter.normalize_user_mods_response(response.get("payload", {}))
	var first := _first_dictionary(normalized.get("data", []))
	summary["first_game_id"] = int(first.get("game_id", 0))
	return summary

func summarize_user_modfiles_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_USER_LIMIT) -> Dictionary:
	return summarize_modfiles_response(adapter, response, requested_limit)

func summarize_user_subscriptions_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_USER_LIMIT) -> Dictionary:
	var summary := summarize_mods_response(adapter, response, requested_limit)
	var normalized: Dictionary = adapter.normalize_mod_list_response(response.get("payload", {}))
	var first := _first_dictionary(normalized.get("data", []))
	summary["first_game_id"] = int(first.get("game_id", 0))
	return summary

func summarize_user_ratings_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_USER_LIMIT) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_user_ratings_response(response.get("payload", {}))
	var first := _first_dictionary(normalized.get("data", []))
	return _list_result_summary(normalized, requested_limit, {
		"first_game_id": int(first.get("game_id", 0)),
		"first_mod_id": int(first.get("mod_id", 0)),
		"first_resource_type": str(first.get("resource_type", "")),
		"first_rating": int(first.get("rating", 0))
	})

func summarize_me_collections_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_USER_LIMIT) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_me_collections_response(response.get("payload", {}))
	var first := _first_dictionary(normalized.get("data", []))
	return _list_result_summary(normalized, requested_limit, {
		"first_collection_id": int(first.get("id", 0)),
		"first_name": str(first.get("name", "")),
		"first_name_id": str(first.get("name_id", ""))
	})

func summarize_followed_collections_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_USER_LIMIT) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_followed_collections_response(response.get("payload", {}))
	var first := _first_dictionary(normalized.get("data", []))
	return _list_result_summary(normalized, requested_limit, {
		"first_collection_id": int(first.get("id", 0)),
		"first_name": str(first.get("name", "")),
		"first_name_id": str(first.get("name_id", ""))
	})

func summarize_collections_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_CHILD_LIMIT) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_collections_response(response.get("payload", {}))
	var names: PackedStringArray = []
	var selected_collection_id := 0
	for entry in normalized.get("data", []):
		if not (entry is Dictionary):
			continue
		if names.size() >= requested_limit:
			break
		names.append(str(entry.get("name", "")))
		if selected_collection_id <= 0:
			selected_collection_id = int(entry.get("id", 0))
	return _list_result_summary(normalized, requested_limit, {
		"collection_names": names,
		"selected_collection_id": selected_collection_id
	})

func summarize_collection_response(adapter, response: Dictionary) -> Dictionary:
	var data: Dictionary = adapter.normalize_collection_response(response.get("payload", {}))
	var stats: Dictionary = data.get("stats", {})
	return {
		"id": int(data.get("id", 0)),
		"name": str(data.get("name", "")),
		"name_id": str(data.get("name_id", "")),
		"status": int(data.get("status", 0)),
		"visible": bool(data.get("visible", false)),
		"category": str(data.get("category", "")),
		"tags": PackedStringArray(data.get("tags", [])),
		"downloads_total": int(stats.get("downloads_total", 0)),
		"followers_total": int(stats.get("followers_total", 0))
	}

func summarize_collection_mods_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_CHILD_LIMIT) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_collection_mods_response(response.get("payload", {}))
	var names: PackedStringArray = []
	for entry in normalized.get("data", []):
		if not (entry is Dictionary):
			continue
		if names.size() >= requested_limit:
			break
		names.append(str(entry.get("name", "")))
	return _list_result_summary(normalized, requested_limit, {
		"mod_names": names
	})

func summarize_collection_comment_write_response(adapter, response: Dictionary) -> Dictionary:
	var data: Dictionary = adapter.normalize_collection_comment_write_response(response.get("payload", {}))
	var user: Dictionary = data.get("user", {})
	return {
		"comment_id": int(data.get("id", 0)),
		"reply_id": int(data.get("reply_id", 0)),
		"content": str(data.get("content", "")),
		"username": str(user.get("username", ""))
	}

func summarize_collection_comment_detail_response(adapter, response: Dictionary) -> Dictionary:
	var data: Dictionary = adapter.normalize_collection_comment_response(response.get("payload", {}))
	var user: Dictionary = data.get("user", {})
	return {
		"comment_id": int(data.get("id", 0)),
		"reply_id": int(data.get("reply_id", 0)),
		"content": str(data.get("content", "")),
		"username": str(user.get("username", ""))
	}

func summarize_collection_comments_presence_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_CHILD_LIMIT, expected_comment_id: int = 0) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_collection_comments_response(response.get("payload", {}))
	var ids: Array[int] = []
	var found_comment_id := false
	for entry in normalized.get("data", []):
		if not (entry is Dictionary):
			continue
		var comment_id := int(entry.get("id", 0))
		ids.append(comment_id)
		if expected_comment_id > 0 and comment_id == expected_comment_id:
			found_comment_id = true
	return _list_result_summary(normalized, requested_limit, {
		"comment_ids": ids,
		"found_comment_id": found_comment_id
	})

func summarize_me_followers_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_USER_LIMIT) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_me_followers_response(response.get("payload", {}))
	var first := _first_dictionary(normalized.get("data", []))
	return _list_result_summary(normalized, requested_limit, {
		"first_user_id": int(first.get("id", 0)),
		"first_username": str(first.get("username", "")),
		"first_name_id": str(first.get("name_id", ""))
	})

func summarize_muted_users_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_USER_LIMIT) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_muted_users_response(response.get("payload", {}))
	var first := _first_dictionary(normalized.get("data", []))
	return _list_result_summary(normalized, requested_limit, {
		"first_user_id": int(first.get("id", 0)),
		"first_username": str(first.get("username", "")),
		"first_name_id": str(first.get("name_id", ""))
	})

func summarize_user_followers_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_USER_LIMIT) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_user_followers_response(response.get("payload", {}))
	var first := _first_dictionary(normalized.get("data", []))
	return _list_result_summary(normalized, requested_limit, {
		"first_user_id": int(first.get("id", 0)),
		"first_username": str(first.get("username", "")),
		"first_name_id": str(first.get("name_id", ""))
	})

func summarize_user_following_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_USER_LIMIT) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_user_following_response(response.get("payload", {}))
	var first := _first_dictionary(normalized.get("data", []))
	return _list_result_summary(normalized, requested_limit, {
		"first_user_id": int(first.get("id", 0)),
		"first_username": str(first.get("username", "")),
		"first_name_id": str(first.get("name_id", ""))
	})

func summarize_user_collections_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_USER_LIMIT) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_user_collections_response(response.get("payload", {}))
	var first := _first_dictionary(normalized.get("data", []))
	return _list_result_summary(normalized, requested_limit, {
		"first_collection_id": int(first.get("id", 0)),
		"first_name": str(first.get("name", "")),
		"first_name_id": str(first.get("name_id", ""))
	})

func summarize_subscription_write_response(adapter, response: Dictionary) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_subscription_write_response(
		int(response.get("status_code", 0)),
		response.get("headers", {}),
		response.get("payload", {})
	)
	var data: Dictionary = normalized.get("data", {})
	return {
		"already_subscribed": bool(normalized.get("already_subscribed", false)),
		"location": str(normalized.get("location", "")),
		"mod_id": int(data.get("id", 0)),
		"name": str(data.get("name", "")),
		"status": int(data.get("status", 0)),
		"visible": int(data.get("visible", 0))
	}

func summarize_no_content_write_response(adapter, response: Dictionary, flag_name: String) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_comment_delete_response(
		int(response.get("status_code", 0)),
		response.get("headers", {})
	)
	return {
		flag_name: bool(normalized.get("deleted", false)),
		"status_code": int(normalized.get("status_code", response.get("status_code", 0)))
	}

func summarize_message_write_response(adapter, response: Dictionary, created_key: String = "") -> Dictionary:
	var normalized: Dictionary = adapter.normalize_message_response(response.get("payload", {}))
	var summary: Dictionary = {
		"code": int(normalized.get("code", 0)),
		"message": str(normalized.get("message", "")),
		"success": bool(normalized.get("success", false))
	}
	if not created_key.is_empty():
		summary[created_key] = int(response.get("status_code", 0)) == 201
	return summary

func summarize_mod_comment_write_response(adapter, response: Dictionary) -> Dictionary:
	var data: Dictionary = adapter.normalize_comment_write_response(response.get("payload", {}))
	var user: Dictionary = data.get("user", {})
	return {
		"comment_id": int(data.get("id", 0)),
		"reply_id": int(data.get("reply_id", 0)),
		"content": str(data.get("content", "")),
		"username": str(user.get("username", ""))
	}

func summarize_mod_comment_detail_response(adapter, response: Dictionary) -> Dictionary:
	var data: Dictionary = adapter.normalize_mod_comment_response(response.get("payload", {}))
	var user: Dictionary = data.get("user", {})
	return {
		"comment_id": int(data.get("id", 0)),
		"reply_id": int(data.get("reply_id", 0)),
		"content": str(data.get("content", "")),
		"username": str(user.get("username", ""))
	}

func summarize_mod_comments_presence_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_CHILD_LIMIT, expected_comment_id: int = 0) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_mod_comments_response(response.get("payload", {}))
	var ids: Array[int] = []
	var found_comment_id := false
	for entry in normalized.get("data", []):
		if not (entry is Dictionary):
			continue
		var comment_id := int(entry.get("id", 0))
		ids.append(comment_id)
		if expected_comment_id > 0 and comment_id == expected_comment_id:
			found_comment_id = true
	return _list_result_summary(normalized, requested_limit, {
		"comment_ids": ids,
		"found_comment_id": found_comment_id
	})

func summarize_user_ratings_presence_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_USER_LIMIT, expected_mod_id: int = 0, expected_rating: int = 0) -> Dictionary:
	var summary: Dictionary = summarize_user_ratings_response(adapter, response, requested_limit)
	var normalized: Dictionary = adapter.normalize_user_ratings_response(response.get("payload", {}))
	var found_expected_rating := false
	for entry in normalized.get("data", []):
		if not (entry is Dictionary):
			continue
		if int(entry.get("mod_id", 0)) == expected_mod_id and int(entry.get("rating", 0)) == expected_rating:
			found_expected_rating = true
			break
	summary["found_expected_rating"] = found_expected_rating
	return summary

func summarize_mod_tags_presence_response(adapter, response: Dictionary, expected_tag: String = "") -> Dictionary:
	var summary: Dictionary = summarize_mod_tags_response(adapter, response)
	summary["found_expected_tag"] = not expected_tag.is_empty() and summary.get("names", PackedStringArray()).has(expected_tag)
	return summary

func summarize_mod_metadata_presence_response(adapter, response: Dictionary, expected_pair: String = "") -> Dictionary:
	var summary: Dictionary = summarize_mod_metadata_kvp_response(adapter, response)
	summary["found_expected_pair"] = not expected_pair.is_empty() and summary.get("pairs", []).has(expected_pair)
	return summary

func summarize_user_subscriptions_presence_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_USER_LIMIT, expected_mod_id: int = 0) -> Dictionary:
	var summary: Dictionary = summarize_user_subscriptions_response(adapter, response, requested_limit)
	summary["found_expected_mod_id"] = expected_mod_id > 0 and int(summary.get("selected_mod_id", 0)) == expected_mod_id
	return summary

func summarize_game_token_packs_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_CHILD_LIMIT) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_game_token_packs_response(response.get("payload", {}))
	var skus: PackedStringArray = []
	var selected_token_pack_id := 0
	for entry in normalized.get("data", []):
		if not (entry is Dictionary):
			continue
		if skus.size() >= requested_limit:
			break
		skus.append(str(entry.get("sku", "")))
		if selected_token_pack_id <= 0:
			selected_token_pack_id = int(entry.get("token_pack_id", entry.get("id", 0)))
	return _list_result_summary(normalized, requested_limit, {
		"skus": skus,
		"selected_token_pack_id": selected_token_pack_id
	})

func summarize_user_wallet_response(adapter, response: Dictionary) -> Dictionary:
	var data: Dictionary = adapter.normalize_user_wallet_response(response.get("payload", {}))
	return {
		"type": str(data.get("type", "")),
		"payment_method_id": str(data.get("payment_method_id", "")),
		"game_id": str(data.get("game_id", "")),
		"currency": str(data.get("currency", "")),
		"balance": int(data.get("balance", 0)),
		"pending_balance": int(data.get("pending_balance", 0)),
		"deficit": int(data.get("deficit", 0)),
		"monetization_status": int(data.get("monetization_status", 0))
	}

func summarize_user_purchased_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_USER_LIMIT) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_user_purchased_response(response.get("payload", {}))
	var names: PackedStringArray = []
	var selected_mod_id := 0
	var first := _first_dictionary(normalized.get("data", []))
	for entry in normalized.get("data", []):
		if not (entry is Dictionary):
			continue
		if names.size() >= requested_limit:
			break
		names.append(str(entry.get("name", "")))
		if selected_mod_id <= 0:
			selected_mod_id = int(entry.get("id", 0))
	return _list_result_summary(normalized, requested_limit, {
		"selected_mod_id": selected_mod_id,
		"sample_mod_names": names,
		"first_price": int(first.get("price", 0)),
		"first_tax": int(first.get("tax", 0))
	})

func summarize_user_entitlements_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_USER_LIMIT) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_user_entitlements_response(response.get("payload", {}))
	var sku_ids: PackedStringArray = []
	var entitlement_types: Array[int] = []
	for entry in normalized.get("data", []):
		if not (entry is Dictionary):
			continue
		if sku_ids.size() >= requested_limit:
			break
		sku_ids.append(str(entry.get("sku_id", "")))
		entitlement_types.append(int(entry.get("entitlement_type", 0)))
	return _list_result_summary(normalized, requested_limit, {
		"sku_ids": sku_ids,
		"entitlement_types": entitlement_types
	})

func summarize_mod_monetization_team_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_CHILD_LIMIT) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_mod_monetization_team_response(response.get("payload", {}))
	var usernames: PackedStringArray = []
	var splits: Array[int] = []
	for entry in normalized.get("data", []):
		if not (entry is Dictionary):
			continue
		if usernames.size() >= requested_limit:
			break
		usernames.append(str(entry.get("username", "")))
		splits.append(int(entry.get("split", 0)))
	return _list_result_summary(normalized, requested_limit, {
		"usernames": usernames,
		"splits": splits
	})

func summarize_checkout_response(adapter, response: Dictionary) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_checkout_response(
		int(response.get("status_code", 0)),
		response.get("headers", {}),
		response.get("payload", {})
	)
	var data: Dictionary = normalized.get("data", {})
	var mod: Dictionary = data.get("mod", {})
	return {
		"completed": bool(normalized.get("completed", false)),
		"transaction_id": int(data.get("transaction_id", 0)),
		"wallet_type": str(data.get("wallet_type", "")),
		"balance": int(data.get("balance", 0)),
		"mod_id": int(mod.get("id", 0)),
		"mod_name_id": str(mod.get("name_id", ""))
	}

func summarize_s2s_transactions_response(adapter, response: Dictionary, requested_limit: int = DEFAULT_CHILD_LIMIT) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_s2s_monetization_transactions_response(response.get("payload", {}))
	var transaction_ids: Array[int] = []
	var gateway_names: PackedStringArray = []
	for entry in normalized.get("data", []):
		if not (entry is Dictionary):
			continue
		if transaction_ids.size() >= requested_limit:
			break
		transaction_ids.append(int(entry.get("id", 0)))
		gateway_names.append(str(entry.get("gateway_name", "")))
	var pagination: Dictionary = normalized.get("pagination", {})
	return {
		"requested_limit": requested_limit,
		"transaction_ids": transaction_ids,
		"gateway_names": gateway_names,
		"selected_transaction_id": transaction_ids[0] if not transaction_ids.is_empty() else 0,
		"per_page": int(pagination.get("per_page", 0)),
		"current_page": str(pagination.get("current_page", ""))
	}

func summarize_s2s_transaction_response(adapter, response: Dictionary) -> Dictionary:
	var normalized: Dictionary = adapter.normalize_s2s_monetization_transaction_response(response.get("payload", {}))
	var transaction: Dictionary = normalized.get("transaction", {})
	var items: Array = transaction.get("items", [])
	var first_item := _first_dictionary(items)
	var line_items: Array = first_item.get("line_items", [])
	var first_line_item := _first_dictionary(line_items)
	return {
		"transaction_id": int(transaction.get("id", 0)),
		"gateway_name": str(transaction.get("gateway_name", "")),
		"item_count": items.size(),
		"first_mod_id": int(first_line_item.get("mod_id", 0)),
		"first_game_id": int(first_line_item.get("game_id", 0))
	}

func build_paid_mods_overview(plan_or_config, scene_mode: bool = false) -> Dictionary:
	var config = _resolve_plan_config(plan_or_config)
	var allow_paid_writes := false
	if plan_or_config is Dictionary:
		allow_paid_writes = bool(plan_or_config.get("allow_paid_writes", false))
	return {
		"run_checks_scope": "Bearer reads, owned-mod read, guarded buyer writes, and S2S/history reads.",
		"run_checks_behavior": "Scene Run Checks reports the route groups + prerequisites. CLI --paid-mods executes the same matrix, while buyer writes still require --allow-paid-writes.",
		"open_question": "Current harness keeps S2S/history behind service_token. Treat that as the current implementation, not a proven mod.io requirement.",
		"route_groups": build_paid_mods_route_groups(config, allow_paid_writes, scene_mode)
	}

func build_paid_mods_route_groups(config, allow_paid_writes: bool = false, scene_mode: bool = false) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	groups.append(_build_route_group(
		"paid_bearer_reads",
		"Bearer reads",
		"GET /games/{game-id}/monetization/token-packs; GET /me/wallets; GET /me/purchased",
		PackedStringArray(["access_token in .testbed/configs/modio.session.local.cfg"]),
		_missing_access_token(config),
		"Run first. No extra monetization-specific keys beyond normal bearer auth.",
		scene_mode
	))
	groups.append(_build_route_group(
		"paid_owned_mod_read",
		"Owned-mod read",
		"GET /games/{game-id}/mods/{owned_mod_id}/monetization/team",
		PackedStringArray(["access_token in .testbed/configs/modio.session.local.cfg", "owned_mod_id or paid_mod_id in .testbed/configs/modio.local.cfg"]),
		_missing_owned_mod_read_prereqs(config),
		"Still needs a concrete paid mod id; that is a route input, not extra wrapper breadth.",
		scene_mode
	))
	groups.append(_build_write_route_group(config, allow_paid_writes, scene_mode))
	groups.append(_build_s2s_route_group(config, scene_mode))
	return groups

func parse_args(args: PackedStringArray) -> Dictionary:
	var options := {
		"env": "",
		"mods_limit": DEFAULT_MODS_LIMIT,
		"json": false,
		"help": false,
		"public_only": false,
		"allow_writes": false,
		"paid_mods": false,
		"allow_paid_writes": false,
		"allow_paid_team_write": false,
		"allow_paid_s2s_writes": false,
		"stable_path": ModioEnvLoader.CONFIG_STABLE_PATH,
		"session_path": ModioEnvLoader.CONFIG_SESSION_PATH,
		"errors": PackedStringArray()
	}

	var index := 0
	while index < args.size():
		var arg := String(args[index])
		match arg:
			"--help", "-h":
				options.help = true
			"--json":
				options.json = true
			"--public-only":
				options.public_only = true
			"--allow-writes":
				options.allow_writes = true
			"--paid-mods":
				options.paid_mods = true
			"--allow-paid-writes":
				options.allow_paid_writes = true
			"--allow-paid-team-write":
				options.allow_paid_team_write = true
			"--allow-paid-s2s-writes":
				options.allow_paid_s2s_writes = true
			"--env":
				index += 1
				if index >= args.size():
					_append_error(options, "Missing value for --env")
				else:
					options.env = String(args[index]).strip_edges().to_lower()
			"--mods-limit":
				index += 1
				if index >= args.size():
					_append_error(options, "Missing value for --mods-limit")
				else:
					var raw_value := String(args[index]).strip_edges()
					if not raw_value.is_valid_int():
						_append_error(options, "Invalid --mods-limit value: %s" % raw_value)
					else:
						options.mods_limit = clampi(raw_value.to_int(), 1, 100)
			"--stable-config":
				index += 1
				if index >= args.size():
					_append_error(options, "Missing value for --stable-config")
				else:
					options.stable_path = String(args[index]).strip_edges()
			"--session-config":
				index += 1
				if index >= args.size():
					_append_error(options, "Missing value for --session-config")
				else:
					options.session_path = String(args[index]).strip_edges()
			_:
				_append_error(options, "Unknown argument: %s" % arg)
		index += 1

	if not options.env.is_empty() and not options.env in ModioEnvLoader.VALID_ENVIRONMENTS:
		_append_error(options, "Unsupported environment: %s" % options.env)

	return options

func build_run_plan(options: Dictionary, loader = null) -> Dictionary:
	if loader == null:
		loader = ModioEnvLoader.new()
	var resolved_env = loader.resolve_environment(
		str(options.get("env", "")),
		str(options.get("stable_path", ModioEnvLoader.CONFIG_STABLE_PATH)),
		str(options.get("session_path", ModioEnvLoader.CONFIG_SESSION_PATH))
	)
	var config = loader.build_client_config(
		str(options.get("env", "")),
		str(options.get("stable_path", ModioEnvLoader.CONFIG_STABLE_PATH)),
		str(options.get("session_path", ModioEnvLoader.CONFIG_SESSION_PATH))
	)
	var checks: Array[Dictionary] = [
		{
			"id": "ping",
			"label": "Ping mod.io API",
			"kind": "public"
		},
		{
			"id": "game",
			"label": "Read configured game detail",
			"kind": "public"
		},
		{
			"id": "mods",
			"label": "Browse configured game mods",
			"kind": "public"
		}
	]
	if bool(options.get("public_only", false)):
		checks.append({
			"id": "me",
			"label": "Read authenticated user profile",
			"kind": "auth",
			"skip": true,
			"skip_reason": "Skipped by --public-only"
		})
	elif config.has_access_token():
		checks.append({
			"id": "me",
			"label": "Read authenticated user profile",
			"kind": "auth"
		})
	else:
		checks.append({
			"id": "me",
			"label": "Read authenticated user profile",
			"kind": "auth",
			"skip": true,
			"skip_reason": "No access token configured in session config"
		})

	return {
		"environment": resolved_env,
		"config": config,
		"checks": checks,
		"mods_limit": int(options.get("mods_limit", DEFAULT_MODS_LIMIT)),
		"allow_writes": bool(options.get("allow_writes", false)),
		"paid_mods": bool(options.get("paid_mods", false)),
		"allow_paid_writes": bool(options.get("allow_paid_writes", false)),
		"allow_paid_team_write": bool(options.get("allow_paid_team_write", false)),
		"allow_paid_s2s_writes": bool(options.get("allow_paid_s2s_writes", false)),
		"stable_path": str(options.get("stable_path", ModioEnvLoader.CONFIG_STABLE_PATH)),
		"session_path": str(options.get("session_path", ModioEnvLoader.CONFIG_SESSION_PATH))
	}

func build_missing_config_warnings(plan: Dictionary) -> PackedStringArray:
	var warnings: PackedStringArray = []
	var config = plan.config
	if config.game_id.is_empty():
		warnings.append("Selected environment is missing game_id")
	if config.api_key.is_empty():
		warnings.append("Selected environment is missing api_key")
	return warnings

func help_text() -> String:
	return "
".join([
		"Safe mod.io live harness",
		"",
		"Usage:",
		"  godot --headless --path .testbed --script res://scripts/modio_live_harness.gd -- [options]",
		"",
		"Options:",
		"  --env test|live              Explicit environment selection (default: resolved from config, fallback test)",
		"  --mods-limit <1..100>        Browse-read limit for the mods listing check (default: %d)" % DEFAULT_MODS_LIMIT,
		"  --public-only                Skip optional authenticated /me check even if a token exists",
		"  --allow-writes               Opt into the low-risk authenticated sandbox write sweep",
		"  --paid-mods                  Opt into the monetization matrix: bearer reads, owned-mod read, guarded buyer writes, and S2S/history reads",
		"  --allow-paid-writes          Opt into buyer-write execution for entitlements + checkout when payload JSON is present",
		"  --allow-paid-team-write      Reserve the monetization-team write opt-in lane (currently a placeholder; no execution yet)",
		"  --allow-paid-s2s-writes      Reserve the S2S write opt-in lane (currently a placeholder; no execution yet)",
		"  --stable-config <path>       Override stable config path (default: res://configs/modio.local.cfg)",
		"  --session-config <path>      Override session config path (default: res://configs/modio.session.local.cfg)",
		"  --json                       Emit machine-readable JSON summary",
		"  --help                       Show this help",
		"",
		"Default checks are non-destructive:",
		"  1. GET /ping",
		"  2. GET /games/{game-id}",
		"  3. GET /games/{game-id}/mods",
		"  4. When at least one public mod exists, also check detail/files/file-detail/stats/tags/metadatakvp/team/dependants/dependencies on the first listed mod",
		"  5. GET /authenticate/terms",
		"  6. Optional authenticated sweep when an access token is present: /me, /me/games, /me/mods, /me/files, /me/subscribed, /me/ratings, /me/collections, /me/following/collections, /me/followers, /me/users/muted, plus /users/{me-id}/followers|following|collections",
		"  7. --paid-mods adds the monetization matrix in four groups:",
		"     - bearer reads: token-packs, wallets, purchased",
		"     - owned-mod read: monetization-team for owned_mod_id / paid_mod_id",
		"     - guarded buyer writes: entitlements + checkout (only with --allow-paid-writes)",
		"     - S2S/history reads: transaction list/detail, currently modeled behind service_token",
		"",
		"Agreement current/version reads are supported by the adapter, but the public terms payload does not",
		"currently expose agreement type/version ids in this sandbox, so the harness stops at GET /authenticate/terms.",
		"",
		"Paid-mods runtime inputs live in the ignored session cfg via entitlements_payload_json,",
		"checkout_payload_json, s2s_filters_json, s2s_transaction_id, and related S2S fields.",
		"Write flows stay disabled unless you explicitly pass their opt-in flags. Test is the default",
		"environment unless you explicitly select live via --env live, MODIO_ENV=live, or the",
		"local cfg override chain.",
	])

func _resolve_plan_config(plan_or_config):
	if plan_or_config is Dictionary:
		var config = plan_or_config.get("config", null)
		if config != null:
			return config
	if plan_or_config != null:
		return plan_or_config
	return ModioClientConfig.new()

func _missing_access_token(config) -> PackedStringArray:
	var missing := PackedStringArray()
	if not config.has_access_token():
		missing.append("access_token in .testbed/configs/modio.session.local.cfg")
	return missing

func _missing_owned_mod_read_prereqs(config) -> PackedStringArray:
	var missing := _missing_access_token(config)
	if config.resolve_owned_mod_id().is_empty():
		missing.append("owned_mod_id or paid_mod_id in .testbed/configs/modio.local.cfg")
	return missing

func _missing_buyer_write_prereqs(config) -> PackedStringArray:
	var missing := _missing_access_token(config)
	if config.paid_entitlements_input.is_empty():
		missing.append("entitlements_payload_json in .testbed/configs/modio.session.local.cfg")
	if config.paid_checkout_input.is_empty():
		missing.append("checkout_payload_json in .testbed/configs/modio.session.local.cfg")
	if config.resolve_paid_mod_id(str(config.paid_checkout_input.get("mod_id", ""))).is_empty():
		missing.append("paid_mod_id or checkout_payload_json.mod_id")
	return missing

func _build_write_route_group(config, allow_paid_writes: bool, scene_mode: bool) -> Dictionary:
	var requires := PackedStringArray([
		"--allow-paid-writes in the CLI harness",
		"access_token in .testbed/configs/modio.session.local.cfg",
		"entitlements_payload_json in .testbed/configs/modio.session.local.cfg",
		"checkout_payload_json in .testbed/configs/modio.session.local.cfg",
		"paid_mod_id or checkout_payload_json.mod_id"
	])
	var missing := _missing_buyer_write_prereqs(config)
	if scene_mode:
		return {
			"id": "paid_buyer_writes",
			"label": "Guarded buyer writes",
			"status": "guarded",
			"details": {
				"routes": "POST /me/entitlements; POST /games/{game-id}/mods/{paid_mod_id}/checkout",
				"requires": "; ".join(requires),
				"missing": "Scene Run Checks does not execute buyer writes. Use the CLI harness for the opt-in lane.",
				"note": "Payload JSON and paid_mod_id remain inherently required inputs."
			}
		}
	if not allow_paid_writes:
		return {
			"id": "paid_buyer_writes",
			"label": "Guarded buyer writes",
			"status": "guarded",
			"details": {
				"routes": "POST /me/entitlements; POST /games/{game-id}/mods/{paid_mod_id}/checkout",
				"requires": "; ".join(requires),
				"missing": "Run with --allow-paid-writes to execute this lane. Current config gaps: %s" % _join_missing_list(missing),
				"note": "Payload JSON and paid_mod_id remain inherently required inputs."
			}
		}
	return _build_route_group(
		"paid_buyer_writes",
		"Guarded buyer writes",
		"POST /me/entitlements; POST /games/{game-id}/mods/{paid_mod_id}/checkout",
		requires,
		missing,
		"These stay opt-in even when prerequisites exist.",
		scene_mode
	)

func _build_s2s_route_group(config, scene_mode: bool) -> Dictionary:
	var missing := PackedStringArray()
	if not config.has_service_token():
		missing.append("service_token in .testbed/configs/modio.local.cfg")
	if config.monetization_team_id.is_empty() and str(config.paid_s2s_filters_input.get("monetization_team_id", "")).strip_edges().is_empty():
		missing.append("monetization_team_id in .testbed/configs/modio.local.cfg or s2s_filters_json")
	return _build_route_group(
		"paid_s2s_history_reads",
		"S2S/history reads",
		"GET /s2s/monetization-teams/{monetization-team-id}/transactions; GET /s2s/monetization-teams/{monetization-team-id}/transactions/{transaction-id}",
		PackedStringArray([
			"service_token in .testbed/configs/modio.local.cfg (current harness assumption)",
			"monetization_team_id in .testbed/configs/modio.local.cfg or s2s_filters_json",
			"transaction_id via s2s_transaction_id or discovery from the history list"
		]),
		missing,
		"Open question: mod.io approval may not require service_token here, but the current implementation still does.",
		scene_mode
	)

func _build_route_group(id: String, label: String, routes: String, requires: PackedStringArray, missing: PackedStringArray, note: String, scene_mode: bool) -> Dictionary:
	var status := "ready" if missing.is_empty() else "blocked"
	if scene_mode and missing.is_empty():
		status = "covered"
	return {
		"id": id,
		"label": label,
		"status": status,
		"details": {
			"routes": routes,
			"requires": "; ".join(requires),
			"missing": _join_missing_list(missing),
			"note": note
		}
	}

func _join_missing_list(missing: PackedStringArray) -> String:
	return "none" if missing.is_empty() else "; ".join(missing)

func _first_dictionary(items: Variant) -> Dictionary:
	if items is Array and not items.is_empty() and items[0] is Dictionary:
		return items[0]
	return {}

func _list_result_summary(normalized: Dictionary, requested_limit: int, extras: Dictionary = {}) -> Dictionary:
	var summary := {
		"requested_limit": requested_limit,
		"response_result_count": int(normalized.get("result_count", 0)),
		"response_result_limit": int(normalized.get("result_limit", 0)),
		"response_result_offset": int(normalized.get("result_offset", 0)),
		"response_result_total": int(normalized.get("result_total", 0))
	}
	for key in extras.keys():
		summary[key] = extras[key]
	return summary

func _append_error(options: Dictionary, message: String) -> void:
	var errors: PackedStringArray = options.get("errors", PackedStringArray())
	errors.append(message)
	options.errors = errors
