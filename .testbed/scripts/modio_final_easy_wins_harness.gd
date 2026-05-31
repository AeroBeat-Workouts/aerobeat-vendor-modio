extends SceneTree

const ModioEnvLoader = preload("res://scripts/modio_env_loader.gd")
const ModioVendorAdapter = preload("res://addons/aerobeat-vendor-modio/src/modio_vendor_adapter.gd")
const ModioHttpTransport = preload("res://addons/aerobeat-vendor-modio/src/network/modio_http_transport.gd")
const ModioListingQuery = preload("res://addons/aerobeat-vendor-modio/src/models/modio_listing_query.gd")

const SAMPLE_MOD_ID := 16112
const COMMENT_LIMIT := 5
const COLLECTION_LIMIT := 5
const SEED_COUNT := 3
const TEMP_DIR := "user://modio_final_easy_wins_harness"
const COLLECTION_CATEGORY := "essential"
const COLLECTION_TAGS := ["GAMEPLAY", "AUDIO"]
const TAXONOMY_TAGS := ["boxing", "easy", "edm"]
const MAX_REDIRECTS := 5
const HTTP_TIMEOUT_SECONDS := 30.0

func _initialize() -> void:
	var loader := ModioEnvLoader.new()
	var config = loader.build_client_config("test")
	var harness := ModioHttpTransport.new()
	var adapter := ModioVendorAdapter.new(config, harness)
	var results: Array[Dictionary] = []
	var warnings: PackedStringArray = []
	var created_seed_mod_ids: Array[int] = []
	var created_collection_id := 0
	var created_comment_id := 0
	var sweep_suffix := str(int(Time.get_unix_time_from_system()))
	var collection_query := ModioListingQuery.new("", PackedStringArray(), COLLECTION_LIMIT, 0)
	var comment_query := ModioListingQuery.new("", PackedStringArray(), COMMENT_LIMIT, 0)

	if not config.has_public_credentials():
		_print_errors_and_quit(["Selected test environment is missing public game credentials"], 1)
		return
	if not config.has_access_token():
		_print_errors_and_quit(["Selected test environment is missing an access token in modio.session.local.cfg"], 1)
		return

	var mod_logo := _build_mod_logo_file_part("oc-meid-mod-%s" % sweep_suffix)
	var collection_logo := _build_collection_logo_file_part("oc-meid-collection-%s" % sweep_suffix)
	var build_file := _build_zip_file_part("oc-meid-build-%s" % sweep_suffix, "oc-meid sandbox build %s\n" % sweep_suffix)

	var modfiles_result := _run_check(
		"sample_modfiles",
		"Read sample workout 16112 file list",
		adapter.build_modfiles_request(str(SAMPLE_MOD_ID), collection_query),
		config,
		func(response: Dictionary) -> Dictionary:
			return _summarize_modfiles(response)
	)
	results.append(modfiles_result)
	var download_metadata := _first_modfile_metadata(modfiles_result.get("details", {}))
	if int(download_metadata.get("id", 0)) > 0:
		results.append(_run_check(
			"sample_modfile_detail",
			"Read sample workout 16112 first file detail",
			adapter.build_modfile_request(str(SAMPLE_MOD_ID), str(int(download_metadata.get("id", 0)))),
			config,
			func(response: Dictionary) -> Dictionary:
				return _summarize_modfile(response)
		))
		results.append(_download_check("sample_modfile_binary_download", "Download sample workout 16112 first file from real delivery URL", download_metadata))

	var taxonomy_result := _run_check(
		"game_tags_directory",
		"Read configured game taxonomy directory",
		adapter.build_game_tags_request(),
		config,
		func(response: Dictionary) -> Dictionary:
			return _summarize_game_tags(response)
	)
	results.append(taxonomy_result)
	results.append(_run_check(
		"mod_tags_add_valid_taxonomy",
		"Add valid configured taxonomy tags to sample workout 16112",
		adapter.build_add_mod_tags_request(str(SAMPLE_MOD_ID), {"tags": TAXONOMY_TAGS}),
		config,
		func(response: Dictionary) -> Dictionary:
			return _summarize_message_payload(response)
	))
	results.append(_run_check(
		"mod_tags_after_add",
		"Read sample workout 16112 tags after valid taxonomy add",
		adapter.build_mod_tags_request(str(SAMPLE_MOD_ID), collection_query),
		config,
		func(response: Dictionary) -> Dictionary:
			return _summarize_mod_tags(response)
	))
	results.append(_run_check(
		"mod_tags_delete_valid_taxonomy",
		"Delete the temporary valid taxonomy tags from sample workout 16112",
		adapter.build_delete_mod_tags_request(str(SAMPLE_MOD_ID), {"tags": TAXONOMY_TAGS}),
		config,
		func(response: Dictionary) -> Dictionary:
			return _summarize_no_content(response, "deleted")
	))
	results.append(_run_check(
		"mod_tags_after_delete",
		"Read sample workout 16112 tags after cleanup",
		adapter.build_mod_tags_request(str(SAMPLE_MOD_ID), collection_query),
		config,
		func(response: Dictionary) -> Dictionary:
			return _summarize_mod_tags(response)
	))

	for seed_index in range(SEED_COUNT):
		var seed_number := seed_index + 1
		var seed_slug := "oc-meid-seed-%s-%s" % [sweep_suffix, seed_number]
		var seed_name := "oc-meid collection seed %s %s" % [seed_number, sweep_suffix]
		var create_result := _run_check(
			"seed_mod_create_%s" % seed_number,
			"Create collection seed workout %s" % seed_number,
			adapter.build_add_mod_request({
				"name": seed_name,
				"name_id": seed_slug,
				"summary": "Final easy-win collection seed workout %s." % seed_number,
				"description": "Disposable public seed workout %s for oc-meid collection coverage." % seed_number,
				"logo": mod_logo,
				"community_options": 131072,
				"metadata_kvp": ["oc-meid=seed-%s" % seed_number],
				"metadata_blob": "{}"
			}),
			config,
			func(response: Dictionary) -> Dictionary:
				return _summarize_mod_detail(response)
		)
		results.append(create_result)
		var created_mod_id := int(create_result.get("details", {}).get("id", 0)) if str(create_result.get("status", "")) == "ok" else 0
		if created_mod_id <= 0:
			_print_summary(config, results, warnings, created_seed_mod_ids, created_collection_id, created_comment_id)
			quit(1)
			return
		created_seed_mod_ids.append(created_mod_id)
		results.append(_run_check(
			"seed_modfile_add_%s" % seed_number,
			"Upload collection seed workout build %s" % seed_number,
			adapter.build_add_modfile_request(str(created_mod_id), {
				"filedata": build_file,
				"version": "0.0.%s" % seed_number,
				"changelog": "oc-meid collection seed build %s" % seed_number,
				"metadata_blob": "{\"seed\":%s}" % seed_number
			}),
			config,
			func(response: Dictionary) -> Dictionary:
				return _summarize_modfile(response)
		))
		results.append(_run_check(
			"seed_mod_publish_%s" % seed_number,
			"Publish collection seed workout %s" % seed_number,
			adapter.build_update_mod_request(str(created_mod_id), {
				"status": 1,
				"visible": 1,
				"community_options": 131072,
				"summary": "Final easy-win collection seed workout %s published." % seed_number
			}),
			config,
			func(response: Dictionary) -> Dictionary:
				return _summarize_mod_detail(response)
		))
		results.append(_run_check(
			"seed_mod_public_detail_%s" % seed_number,
			"Verify collection seed workout %s is publicly readable",
			adapter.build_mod_detail_request(str(created_mod_id)),
			config,
			func(response: Dictionary) -> Dictionary:
				return _summarize_mod_detail(response)
		))

	var collection_mod_ids: Array[int] = [SAMPLE_MOD_ID]
	collection_mod_ids.append_array(created_seed_mod_ids)
	var create_collection_result := _run_check(
		"collection_create",
		"Create disposable public collection for expanded collection-family coverage",
		adapter.build_add_collection_request({
			"name": "oc-meid collection %s" % sweep_suffix,
			"name_id": "oc-meid-collection-%s" % sweep_suffix,
			"summary": "Disposable collection for final easy-win coverage.",
			"description": "Disposable collection for follow/subscription/comment/compatibility coverage.",
			"logo": collection_logo,
			"category": COLLECTION_CATEGORY,
			"status": 1,
			"visible": 1,
			"tags": COLLECTION_TAGS,
			"mod_ids": collection_mod_ids
		}),
		config,
		func(response: Dictionary) -> Dictionary:
			var summary := _summarize_collection(response)
			summary["requested_mod_ids"] = collection_mod_ids
			return summary
	)
	results.append(create_collection_result)
	created_collection_id = int(create_collection_result.get("details", {}).get("id", 0)) if str(create_collection_result.get("status", "")) == "ok" else 0
	if created_collection_id <= 0:
		_print_summary(config, results, warnings, created_seed_mod_ids, created_collection_id, created_comment_id)
		quit(1)
		return

	var created_collection_id_text := str(created_collection_id)
	results.append(_run_check(
		"collections_public_list",
		"Browse public collections after disposable collection create",
		adapter.build_collections_request(collection_query),
		config,
		func(response: Dictionary) -> Dictionary:
			var summary := _summarize_collection_list(response, COLLECTION_LIMIT)
			summary["expected_collection_id"] = created_collection_id
			return summary
	))
	results.append(_run_check(
		"collection_detail_public",
		"Read the disposable public collection detail",
		adapter.build_collection_request(created_collection_id_text),
		config,
		func(response: Dictionary) -> Dictionary:
			return _summarize_collection(response)
	))
	results.append(_run_check(
		"collection_mods_public",
		"Read collection members for the disposable public collection",
		adapter.build_collection_mods_request(created_collection_id_text, collection_query),
		config,
		func(response: Dictionary) -> Dictionary:
			var summary := _summarize_collection_mods(response, COLLECTION_LIMIT)
			summary["expected_mod_ids"] = collection_mod_ids
			return summary
	))
	results.append(_run_check(
		"me_collections_after_create",
		"Read owner collection inventory after disposable collection create",
		adapter.build_me_collections_request(collection_query),
		config,
		func(response: Dictionary) -> Dictionary:
			return _summarize_collection_list(response, COLLECTION_LIMIT)
	))
	results.append(_run_check(
		"followed_collections_before",
		"Read followed collections before collection follow",
		adapter.build_followed_collections_request(collection_query),
		config,
		func(response: Dictionary) -> Dictionary:
			return _summarize_collection_list(response, COLLECTION_LIMIT)
	))
	results.append(_run_check(
		"collection_follow",
		"Follow the disposable public collection",
		adapter.build_follow_collection_request(created_collection_id_text),
		config,
		func(response: Dictionary) -> Dictionary:
			return _summarize_collection(response)
	))
	results.append(_run_check(
		"followed_collections_after_follow",
		"Read followed collections after collection follow",
		adapter.build_followed_collections_request(collection_query),
		config,
		func(response: Dictionary) -> Dictionary:
			var summary := _summarize_collection_list(response, COLLECTION_LIMIT)
			summary["expected_collection_id"] = created_collection_id
			return summary
	))
	results.append(_run_check(
		"collection_unfollow",
		"Unfollow the disposable public collection",
		adapter.build_unfollow_collection_request(created_collection_id_text),
		config,
		func(response: Dictionary) -> Dictionary:
			return _summarize_no_content(response, "deleted")
	))
	results.append(_run_check(
		"followed_collections_after_unfollow",
		"Read followed collections after collection unfollow",
		adapter.build_followed_collections_request(collection_query),
		config,
		func(response: Dictionary) -> Dictionary:
			return _summarize_collection_list(response, COLLECTION_LIMIT)
	))
	results.append(_run_check(
		"collection_subscribe",
		"Subscribe to the disposable public collection",
		adapter.build_subscribe_collection_request(created_collection_id_text),
		config,
		func(response: Dictionary) -> Dictionary:
			return _summarize_collection(response)
	))
	results.append(_run_check(
		"collection_unsubscribe",
		"Unsubscribe from the disposable public collection",
		adapter.build_unsubscribe_collection_request(created_collection_id_text),
		config,
		func(response: Dictionary) -> Dictionary:
			return _summarize_collection(response)
	))
	results.append(_run_check(
		"collection_comments_before",
		"Read collection comments before collection comment writes",
		adapter.build_collection_comments_request(created_collection_id_text, comment_query),
		config,
		func(response: Dictionary) -> Dictionary:
			return _summarize_comment_list(response, COMMENT_LIMIT)
	))

	var create_comment_result := _run_check(
		"collection_comment_create",
		"Create a disposable collection comment",
		adapter.build_add_collection_comment_request(created_collection_id_text, "oc-meid collection comment create %s" % sweep_suffix),
		config,
		func(response: Dictionary) -> Dictionary:
			return _summarize_comment_detail(response)
	)
	results.append(create_comment_result)
	created_comment_id = int(create_comment_result.get("details", {}).get("comment_id", 0)) if str(create_comment_result.get("status", "")) == "ok" else 0
	if created_comment_id > 0:
		var created_comment_id_text := str(created_comment_id)
		results.append(_run_check(
			"collection_comment_detail_after_create",
			"Read the disposable collection comment detail after create",
			adapter.build_collection_comment_request(created_collection_id_text, created_comment_id_text),
			config,
			func(response: Dictionary) -> Dictionary:
				return _summarize_comment_detail(response)
		))
		results.append(_run_check(
			"collection_comments_after_create",
			"Read collection comments after collection comment create",
			adapter.build_collection_comments_request(created_collection_id_text, comment_query),
			config,
			func(response: Dictionary) -> Dictionary:
				var summary := _summarize_comment_list(response, COMMENT_LIMIT)
				summary["expected_comment_id"] = created_comment_id
				return summary
		))
		var updated_comment_content := "oc-meid collection comment update %s" % sweep_suffix
		results.append(_run_check(
			"collection_comment_update",
			"Update the disposable collection comment",
			adapter.build_update_collection_comment_request(created_collection_id_text, created_comment_id_text, updated_comment_content),
			config,
			func(response: Dictionary) -> Dictionary:
				return _summarize_comment_detail(response)
		))
		var comment_detail_after_update_result := _run_check(
			"collection_comment_detail_after_update",
			"Read the disposable collection comment detail immediately after update",
			adapter.build_collection_comment_request(created_collection_id_text, created_comment_id_text),
			config,
			func(response: Dictionary) -> Dictionary:
				return _summarize_comment_detail(response)
		)
		results.append(comment_detail_after_update_result)
		var update_content := str(results[results.size() - 2].get("details", {}).get("content", ""))
		var reread_content := str(comment_detail_after_update_result.get("details", {}).get("content", ""))
		if not update_content.is_empty() and update_content != reread_content:
			warnings.append("Immediate collection comment detail reread stayed stale after update; update response returned '%s' but detail reread returned '%s'." % [update_content, reread_content])
		results.append(_run_check(
			"collection_comment_delete",
			"Delete the disposable collection comment",
			adapter.build_delete_collection_comment_request(created_collection_id_text, created_comment_id_text),
			config,
			func(response: Dictionary) -> Dictionary:
				return _summarize_no_content(response, "deleted")
		))
		results.append(_run_check(
			"collection_comments_after_delete",
			"Read collection comments after collection comment delete",
			adapter.build_collection_comments_request(created_collection_id_text, comment_query),
			config,
			func(response: Dictionary) -> Dictionary:
				return _summarize_comment_list(response, COMMENT_LIMIT)
		))

	results.append(_run_check(
		"collection_compatibility_positive",
		"Submit a positive compatibility rating for the disposable public collection",
		adapter.build_add_collection_compatibility_request(created_collection_id_text, 1),
		config,
		func(response: Dictionary) -> Dictionary:
			return _summarize_message_payload(response)
	))
	results.append(_run_check(
		"collection_remove_one_member",
		"Remove one disposable seed workout from the collection membership",
		adapter.build_delete_collection_mods_request(created_collection_id_text, {"mod_ids": [created_seed_mod_ids[0]]}),
		config,
		func(response: Dictionary) -> Dictionary:
			return _summarize_no_content(response, "deleted")
	))
	results.append(_run_check(
		"collection_mods_after_member_delete",
		"Read collection members after removing one disposable seed workout",
		adapter.build_collection_mods_request(created_collection_id_text, collection_query),
		config,
		func(response: Dictionary) -> Dictionary:
			return _summarize_collection_mods(response, COLLECTION_LIMIT)
	))

	results.append_array(_cleanup_disposable_fixtures(adapter, config, created_collection_id, created_seed_mod_ids))
	_print_summary(config, results, warnings, created_seed_mod_ids, created_collection_id, created_comment_id)
	quit(0 if _results_are_ok(results) else 1)

func _cleanup_disposable_fixtures(adapter, config, created_collection_id: int, created_seed_mod_ids: Array[int]) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if created_collection_id > 0:
		results.append(_run_check(
			"cleanup_collection_delete",
			"Delete the disposable collection fixture",
			adapter.build_delete_collection_request(str(created_collection_id)),
			config,
			func(response: Dictionary) -> Dictionary:
				return _summarize_no_content(response, "deleted")
		))
	for index in range(created_seed_mod_ids.size() - 1, -1, -1):
		var mod_id := int(created_seed_mod_ids[index])
		if mod_id <= 0:
			continue
		results.append(_run_check(
			"cleanup_seed_mod_delete_%s" % str(index + 1),
			"Delete disposable collection seed workout %s" % str(index + 1),
			adapter.build_delete_mod_request(str(mod_id)),
			config,
			func(response: Dictionary) -> Dictionary:
				return _summarize_no_content(response, "deleted")
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
			"error_ref": int(error_info.get("error_ref", 0)),
			"field_errors": error_info.get("details", {})
		}
	}

func _download_check(id: String, label: String, download_metadata: Dictionary) -> Dictionary:
	var response := _download_binary(str(download_metadata.get("binary_url", "")))
	if not bool(response.get("ok", false)):
		return {
			"id": id,
			"label": label,
			"status": "failed",
			"status_code": int(response.get("status_code", 0)),
			"details": {
				"message": str(response.get("message", "Binary download failed")),
				"category": str(response.get("category", "transport")),
				"error_ref": 0,
				"field_errors": {}
			}
		}
	return {
		"id": id,
		"label": label,
		"status": "ok",
		"status_code": int(response.get("status_code", 0)),
		"details": {
			"url": str(download_metadata.get("binary_url", "")),
			"redirect_chain": response.get("redirect_chain", []),
			"bytes": int(response.get("bytes", 0)),
			"md5": str(response.get("md5", "")),
			"expected_md5": str(download_metadata.get("md5", "")),
			"md5_matches": str(response.get("md5", "")) == str(download_metadata.get("md5", "")),
			"zip_entries": response.get("zip_entries", []),
			"filename": str(download_metadata.get("filename", ""))
		}
	}

func _download_binary(url: String) -> Dictionary:
	var redirect_chain: Array[String] = []
	var current_url := url.strip_edges()
	for _redirect_index in range(MAX_REDIRECTS + 1):
		var parsed := _parse_url(current_url)
		if not bool(parsed.get("ok", false)):
			return {"ok": false, "status_code": -1, "message": str(parsed.get("message", "Unsupported URL")), "category": "transport"}
		var client := HTTPClient.new()
		var tls_options := TLSOptions.client() if bool(parsed.get("tls", false)) else null
		var connect_error := client.connect_to_host(str(parsed.get("host", "")), int(parsed.get("port", 0)), tls_options)
		if connect_error != OK:
			return {"ok": false, "status_code": -1, "message": error_string(connect_error), "category": "transport"}
		if not _wait_for_client(client, [HTTPClient.STATUS_CONNECTED]):
			return {"ok": false, "status_code": -1, "message": "Timed out connecting to binary host.", "category": "transport"}
		var request_error := client.request(HTTPClient.METHOD_GET, str(parsed.get("request_path", "/")), PackedStringArray(), "")
		if request_error != OK:
			return {"ok": false, "status_code": -1, "message": error_string(request_error), "category": "transport"}
		if not _wait_for_client(client, [HTTPClient.STATUS_BODY, HTTPClient.STATUS_CONNECTED]):
			return {"ok": false, "status_code": -1, "message": "Timed out waiting for binary response.", "category": "transport"}
		var status_code := client.get_response_code()
		var headers := _response_headers_to_dictionary(client.get_response_headers())
		if status_code >= 300 and status_code < 400 and headers.has("location"):
			redirect_chain.append(str(headers["location"]))
			current_url = str(headers["location"])
			continue
		var body_chunks := PackedByteArray()
		while client.get_status() == HTTPClient.STATUS_BODY:
			client.poll()
			var chunk := client.read_response_body_chunk()
			if chunk.is_empty():
				OS.delay_msec(10)
				continue
			body_chunks.append_array(chunk)
		if status_code < 200 or status_code >= 300:
			return {"ok": false, "status_code": status_code, "message": "HTTP %s" % status_code, "category": "transport", "redirect_chain": redirect_chain}
		return {
			"ok": true,
			"status_code": status_code,
			"redirect_chain": redirect_chain,
			"bytes": body_chunks.size(),
			"md5": _compute_md5(body_chunks),
			"zip_entries": _zip_entries_from_bytes(body_chunks)
		}
	return {"ok": false, "status_code": -1, "message": "Too many redirects while downloading binary.", "category": "transport", "redirect_chain": redirect_chain}

func _parse_url(url: String) -> Dictionary:
	var trimmed := url.strip_edges()
	var parts := trimmed.split("://", false, 1)
	if parts.size() != 2:
		return {"ok": false, "message": "Unsupported URL: %s" % url}
	var scheme := parts[0].to_lower()
	var remainder := parts[1]
	var slash_index := remainder.find("/")
	var host_port := remainder
	var request_path := "/"
	if slash_index >= 0:
		host_port = remainder.substr(0, slash_index)
		request_path = remainder.substr(slash_index)
	var host := host_port
	var port := 443 if scheme == "https" else 80
	if host_port.contains(":"):
		var host_parts := host_port.rsplit(":", true, 1)
		host = host_parts[0]
		port = int(host_parts[1])
	return {
		"ok": true,
		"scheme": scheme,
		"tls": scheme == "https",
		"host": host,
		"port": port,
		"request_path": request_path
	}

func _wait_for_client(client: HTTPClient, terminal_statuses: Array) -> bool:
	var started_at := Time.get_ticks_msec()
	while true:
		client.poll()
		var status := client.get_status()
		if terminal_statuses.has(status):
			return true
		if status == HTTPClient.STATUS_DISCONNECTED:
			return false
		var elapsed_seconds := float(Time.get_ticks_msec() - started_at) / 1000.0
		if elapsed_seconds >= HTTP_TIMEOUT_SECONDS:
			return false
		OS.delay_msec(10)
	return false

func _response_headers_to_dictionary(header_lines: PackedStringArray) -> Dictionary:
	var headers := {}
	for line in header_lines:
		var separator_index := line.find(":")
		if separator_index < 0:
			continue
		var key := line.substr(0, separator_index).strip_edges().to_lower()
		var value := line.substr(separator_index + 1).strip_edges()
		headers[key] = value
	return headers

func _compute_md5(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_MD5)
	hashing.update(bytes)
	return hashing.finish().hex_encode()

func _zip_entries_from_bytes(bytes: PackedByteArray) -> PackedStringArray:
	_ensure_temp_dir()
	var path := ProjectSettings.globalize_path("%s/download-probe.zip" % TEMP_DIR)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return PackedStringArray()
	file.store_buffer(bytes)
	file.close()
	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		return PackedStringArray()
	var entries := PackedStringArray(reader.get_files())
	reader.close()
	return entries

func _first_modfile_metadata(details: Dictionary) -> Dictionary:
	var records: Array = details.get("records", [])
	if records.is_empty() or not (records[0] is Dictionary):
		return {}
	return records[0]

func _summarize_modfiles(response: Dictionary) -> Dictionary:
	var payload: Dictionary = response.get("payload", {})
	var records: Array[Dictionary] = []
	var data = payload.get("data", [])
	if data is Array:
		for entry in data:
			if not (entry is Dictionary):
				continue
			records.append({
				"id": int(entry.get("id", 0)),
				"filename": str(entry.get("filename", "")),
				"filesize": int(entry.get("filesize", 0)),
				"md5": str(entry.get("filehash", {}).get("md5", "")),
				"binary_url": str(entry.get("download", {}).get("binary_url", "")),
				"date_expires": int(entry.get("download", {}).get("date_expires", 0))
			})
	return {
		"records": records,
		"response_result_count": int(payload.get("result_count", 0)),
		"response_result_limit": int(payload.get("result_limit", 0)),
		"response_result_offset": int(payload.get("result_offset", 0)),
		"response_result_total": int(payload.get("result_total", 0))
	}

func _summarize_modfile(response: Dictionary) -> Dictionary:
	var payload: Dictionary = response.get("payload", {})
	return {
		"id": int(payload.get("id", 0)),
		"filename": str(payload.get("filename", "")),
		"filesize": int(payload.get("filesize", 0)),
		"md5": str(payload.get("filehash", {}).get("md5", "")),
		"binary_url": str(payload.get("download", {}).get("binary_url", "")),
		"date_expires": int(payload.get("download", {}).get("date_expires", 0))
	}

func _summarize_game_tags(response: Dictionary) -> Dictionary:
	var payload: Dictionary = response.get("payload", {})
	var groups := {}
	var data = payload.get("data", [])
	if data is Array:
		for entry in data:
			if not (entry is Dictionary):
				continue
			groups[str(entry.get("name", ""))] = PackedStringArray(entry.get("tags", []))
	return {
		"groups": groups,
		"response_result_total": int(payload.get("result_total", 0))
	}

func _summarize_mod_tags(response: Dictionary) -> Dictionary:
	var payload: Dictionary = response.get("payload", {})
	var names := PackedStringArray()
	var data = payload.get("data", [])
	if data is Array:
		for entry in data:
			if entry is Dictionary:
				names.append(str(entry.get("name", "")))
	return {
		"names": names,
		"response_result_count": int(payload.get("result_count", 0)),
		"response_result_total": int(payload.get("result_total", 0))
	}

func _summarize_message_payload(response: Dictionary) -> Dictionary:
	var payload: Dictionary = response.get("payload", {})
	return {
		"code": int(payload.get("code", response.get("status_code", 0))),
		"message": str(payload.get("message", ""))
	}

func _summarize_mod_detail(response: Dictionary) -> Dictionary:
	var payload: Dictionary = response.get("payload", {})
	return {
		"id": int(payload.get("id", 0)),
		"name": str(payload.get("name", "")),
		"status": int(payload.get("status", 0)),
		"visible": int(payload.get("visible", 0)),
		"community_options": int(payload.get("community_options", 0))
	}

func _summarize_collection(response: Dictionary) -> Dictionary:
	var payload: Dictionary = response.get("payload", {})
	return {
		"id": int(payload.get("id", 0)),
		"name": str(payload.get("name", "")),
		"status": int(payload.get("status", 0)),
		"visible": bool(int(payload.get("visible", 0))),
		"category": str(payload.get("category", "")),
		"tags": PackedStringArray(payload.get("tags", [])),
		"mods_total": int(payload.get("stats", {}).get("mods_total", 0))
	}

func _summarize_collection_list(response: Dictionary, requested_limit: int) -> Dictionary:
	var payload: Dictionary = response.get("payload", {})
	var ids: Array[int] = []
	var names := PackedStringArray()
	var data = payload.get("data", [])
	if data is Array:
		for entry in data:
			if not (entry is Dictionary):
				continue
			ids.append(int(entry.get("id", 0)))
			names.append(str(entry.get("name", "")))
	return {
		"requested_limit": requested_limit,
		"collection_ids": ids,
		"collection_names": names,
		"response_result_count": int(payload.get("result_count", 0)),
		"response_result_limit": int(payload.get("result_limit", 0)),
		"response_result_offset": int(payload.get("result_offset", 0)),
		"response_result_total": int(payload.get("result_total", 0))
	}

func _summarize_collection_mods(response: Dictionary, requested_limit: int) -> Dictionary:
	var payload: Dictionary = response.get("payload", {})
	var ids: Array[int] = []
	var names := PackedStringArray()
	var data = payload.get("data", [])
	if data is Array:
		for entry in data:
			if not (entry is Dictionary):
				continue
			ids.append(int(entry.get("id", 0)))
			names.append(str(entry.get("name", "")))
	return {
		"requested_limit": requested_limit,
		"mod_ids": ids,
		"mod_names": names,
		"response_result_count": int(payload.get("result_count", 0)),
		"response_result_limit": int(payload.get("result_limit", 0)),
		"response_result_offset": int(payload.get("result_offset", 0)),
		"response_result_total": int(payload.get("result_total", 0))
	}

func _summarize_comment_detail(response: Dictionary) -> Dictionary:
	var payload: Dictionary = response.get("payload", {})
	var user: Dictionary = payload.get("user", {})
	return {
		"comment_id": int(payload.get("id", 0)),
		"reply_id": int(payload.get("reply_id", 0)),
		"content": str(payload.get("content", "")),
		"username": str(user.get("username", ""))
	}

func _summarize_comment_list(response: Dictionary, requested_limit: int) -> Dictionary:
	var payload: Dictionary = response.get("payload", {})
	var ids: Array[int] = []
	var data = payload.get("data", [])
	if data is Array:
		for entry in data:
			if entry is Dictionary:
				ids.append(int(entry.get("id", 0)))
	return {
		"requested_limit": requested_limit,
		"comment_ids": ids,
		"response_result_count": int(payload.get("result_count", 0)),
		"response_result_limit": int(payload.get("result_limit", 0)),
		"response_result_offset": int(payload.get("result_offset", 0)),
		"response_result_total": int(payload.get("result_total", 0))
	}

func _summarize_no_content(response: Dictionary, flag_name: String) -> Dictionary:
	return {
		flag_name: int(response.get("status_code", 0)) == 204,
		"status_code": int(response.get("status_code", 0))
	}

func _build_collection_logo_file_part(prefix: String) -> Dictionary:
	_ensure_temp_dir()
	var image := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	image.fill(Color8(255, 80, 120, 255))
	var path := "%s/%s.png" % [TEMP_DIR, prefix]
	var save_error := image.save_png(path)
	if save_error != OK:
		push_error("Failed to save collection PNG: %s" % error_string(save_error))
	return {
		"filename": "%s.png" % prefix,
		"content_type": "image/png",
		"data": FileAccess.get_file_as_bytes(path)
	}

func _build_mod_logo_file_part(prefix: String) -> Dictionary:
	_ensure_temp_dir()
	var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	image.fill(Color8(80, 180, 255, 255))
	var path := "%s/%s.png" % [TEMP_DIR, prefix]
	var save_error := image.save_png(path)
	if save_error != OK:
		push_error("Failed to save mod PNG: %s" % error_string(save_error))
	return {
		"filename": "%s.png" % prefix,
		"content_type": "image/png",
		"data": FileAccess.get_file_as_bytes(path)
	}

func _build_zip_file_part(prefix: String, content: String) -> Dictionary:
	_ensure_temp_dir()
	var path := "%s/%s.zip" % [TEMP_DIR, prefix]
	var zipper := ZIPPacker.new()
	var open_error := zipper.open(ProjectSettings.globalize_path(path))
	if open_error != OK:
		push_error("Failed to open temp ZIP: %s" % error_string(open_error))
	else:
		var start_error := zipper.start_file("README.txt")
		if start_error != OK:
			push_error("Failed to start temp ZIP entry: %s" % error_string(start_error))
		else:
			zipper.write_file(content.to_utf8_buffer())
			zipper.close_file()
		zipper.close()
	return {
		"filename": "%s.zip" % prefix,
		"content_type": "application/zip",
		"data": FileAccess.get_file_as_bytes(path)
	}

func _ensure_temp_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_DIR))

func _results_are_ok(results: Array[Dictionary]) -> bool:
	for result in results:
		if str(result.get("status", "")) != "ok":
			return false
	return true

func _print_summary(config, results: Array[Dictionary], warnings: PackedStringArray, seed_mod_ids: Array[int], collection_id: int, comment_id: int) -> void:
	print(JSON.stringify({
		"environment": "test",
		"base_url": config.resolve_base_url(),
		"host_kind": config.host_kind,
		"game_id": config.game_id,
		"seed_mod_ids": seed_mod_ids,
		"created_collection_id": collection_id,
		"created_comment_id": comment_id,
		"warnings": warnings,
		"checks": results,
		"ok": _results_are_ok(results)
	}, "  "))

func _print_errors_and_quit(errors: PackedStringArray, code: int) -> void:
	print(JSON.stringify({"ok": false, "errors": errors}, "  "))
	quit(code)
