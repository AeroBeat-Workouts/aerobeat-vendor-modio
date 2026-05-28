extends SceneTree

const ModioEnvLoader = preload("res://modio_env_loader.gd")
const ModioVendorAdapter = preload("res://addons/aerobeat-vendor-modio/src/modio_vendor_adapter.gd")
const ModioHttpTransport = preload("res://addons/aerobeat-vendor-modio/src/network/modio_http_transport.gd")
const ModioListingQuery = preload("res://addons/aerobeat-vendor-modio/src/models/modio_listing_query.gd")
const ModioLiveHarness = preload("res://modio_live_harness_lib.gd")

const GUIDE_ID := 43
const SAMPLE_PARENT_MOD_ID := 16112
const COLLECTION_LIMIT := 5
const COMMENT_LIMIT := 5
const SEED_COUNT := 3
const TEMP_DIR := "user://modio_collection_eligibility_harness"
const COLLECTION_CATEGORY := "essential"
const COLLECTION_TAGS := ["GAMEPLAY", "AUDIO"]

func _initialize() -> void:
	var loader := ModioEnvLoader.new()
	var config = loader.build_client_config("test")
	var harness := ModioLiveHarness.new()
	var adapter := ModioVendorAdapter.new(config, ModioHttpTransport.new())
	var results: Array[Dictionary] = []
	var guide_comment_id := 0
	var created_seed_mod_ids: Array[int] = []
	var created_seed_modfile_ids: Array[int] = []
	var created_collection_id := 0
	var created_collection_name := ""
	var sweep_suffix := str(int(Time.get_unix_time_from_system()))

	if not config.has_public_credentials():
		_print_errors_and_quit(["Selected test environment is missing public game credentials"], 1)
		return
	if not config.has_access_token():
		_print_errors_and_quit(["Selected test environment is missing an access token in modio.session.local.cfg"], 1)
		return

	var collection_query := ModioListingQuery.new("", PackedStringArray(), COLLECTION_LIMIT, 0)
	var comment_query := ModioListingQuery.new("", PackedStringArray(), COMMENT_LIMIT, 0)
	var guide_id_text := str(GUIDE_ID)
	var parent_mod_id_text := str(SAMPLE_PARENT_MOD_ID)
	var collection_logo := _build_collection_logo_file_part("oc-3z6v-collection-%s" % sweep_suffix)
	var mod_logo := _build_mod_logo_file_part("oc-3z6v-mod-%s" % sweep_suffix)
	var build_file := _build_zip_file_part("oc-3z6v-build-%s" % sweep_suffix, "oc-3z6v sandbox build %s\n" % sweep_suffix)

	results.append(_run_check(
		"guide_detail_43",
		"Read the real published guide fixture 43",
		adapter.build_guide_detail_request(guide_id_text),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_guide_response(adapter, response)
	))
	var guide_comments_result := _run_check(
		"guide_comments_43",
		"Read the real guide fixture 43 comment list",
		adapter.build_guide_comments_request(guide_id_text, comment_query),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_guide_comments_presence_response(adapter, response, COMMENT_LIMIT)
	)
	results.append(guide_comments_result)
	var guide_comment_ids: Array = guide_comments_result.get("details", {}).get("comment_ids", [])
	if not guide_comment_ids.is_empty():
		guide_comment_id = int(guide_comment_ids[0])
	if guide_comment_id > 0:
		results.append(_run_check(
			"guide_comment_detail_43",
			"Read the real guide fixture 43 first comment detail",
			adapter.build_guide_comment_request(guide_id_text, str(guide_comment_id)),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_guide_comment_detail_response(adapter, response)
		))
	results.append(_run_check(
		"guide_tags_after_43",
		"Read the public guide tag directory after guide 43 publication",
		adapter.build_guide_tags_request(),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_guide_tags_response(adapter, response)
	))

	var one_mod_collection_name := "oc-3z6v one-mod probe %s" % sweep_suffix
	var one_mod_collection_id := _attempt_collection_create(
		adapter,
		config,
		results,
		"collection_create_one_mod",
		"Attempt collection creation with only sample workout 16112",
		one_mod_collection_name,
		"oc-3z6v-one-mod-probe-%s" % sweep_suffix,
		collection_logo,
		[SAMPLE_PARENT_MOD_ID]
	)
	if one_mod_collection_id > 0:
		results.append(_run_check(
			"collection_delete_one_mod_probe",
			"Delete the unexpected one-mod probe collection",
			adapter.build_delete_collection_request(str(one_mod_collection_id)),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_no_content_write_response(adapter, response, "deleted")
		))

	for seed_index in range(SEED_COUNT):
		var seed_number := seed_index + 1
		var seed_slug := "oc-3z6v-seed-%s-%s" % [sweep_suffix, seed_number]
		var seed_name := "oc-3z6v collection seed %s %s" % [seed_number, sweep_suffix]
		var create_result := _run_check(
			"seed_mod_create_%s" % seed_number,
			"Create seed workout %s for collection eligibility" % seed_number,
			adapter.build_add_mod_request({
				"name": seed_name,
				"name_id": seed_slug,
				"summary": "Collection eligibility seed workout %s." % seed_number,
				"description": "Disposable public seed workout %s for oc-3z6v collection validation." % seed_number,
				"logo": mod_logo,
				"community_options": 131072,
				"metadata_kvp": ["oc-3z6v=seed-%s" % seed_number],
				"metadata_blob": "{}"
			}),
			config,
			func(response: Dictionary) -> Dictionary:
				var summary := harness.summarize_mod_detail_response(adapter, response)
				summary["seed_number"] = seed_number
				return summary
		)
		results.append(create_result)
		var created_mod_id := int(create_result.get("details", {}).get("id", 0)) if str(create_result.get("status", "")) == "ok" else 0
		if created_mod_id <= 0:
			_print_summary(config, results, created_seed_mod_ids, created_seed_modfile_ids, created_collection_id, created_collection_name)
			quit(1)
			return
		created_seed_mod_ids.append(created_mod_id)
		var created_mod_id_text := str(created_mod_id)

		var modfile_result := _run_check(
			"seed_modfile_add_%s" % seed_number,
			"Upload seed workout build %s" % seed_number,
			adapter.build_add_modfile_request(created_mod_id_text, {
				"filedata": build_file,
				"version": "0.0.%s" % seed_number,
				"changelog": "oc-3z6v collection seed build %s" % seed_number,
				"metadata_blob": "{\"seed\":%s}" % seed_number
			}),
			config,
			func(response: Dictionary) -> Dictionary:
				var summary := harness.summarize_modfile_response(adapter, response)
				summary["seed_number"] = seed_number
				return summary
		)
		results.append(modfile_result)
		var created_modfile_id := int(modfile_result.get("details", {}).get("id", 0)) if str(modfile_result.get("status", "")) == "ok" else 0
		if created_modfile_id <= 0:
			_print_summary(config, results, created_seed_mod_ids, created_seed_modfile_ids, created_collection_id, created_collection_name)
			quit(1)
			return
		created_seed_modfile_ids.append(created_modfile_id)

		results.append(_run_check(
			"seed_mod_publish_%s" % seed_number,
			"Publish seed workout %s after build upload" % seed_number,
			adapter.build_update_mod_request(created_mod_id_text, {
				"status": 1,
				"visible": 1,
				"community_options": 131072,
				"summary": "Collection eligibility seed workout %s published." % seed_number
			}),
			config,
			func(response: Dictionary) -> Dictionary:
				var summary := harness.summarize_mod_detail_response(adapter, response)
				summary["seed_number"] = seed_number
				return summary
		))
		results.append(_run_check(
			"seed_mod_public_detail_%s" % seed_number,
			"Verify seed workout %s is publicly readable" % seed_number,
			adapter.build_mod_detail_request(created_mod_id_text),
			config,
			func(response: Dictionary) -> Dictionary:
				var summary := harness.summarize_mod_detail_response(adapter, response)
				summary["seed_number"] = seed_number
				return summary
		))

	var collection_mod_ids: Array[int] = [SAMPLE_PARENT_MOD_ID]
	collection_mod_ids.append_array(created_seed_mod_ids)
	created_collection_name = "oc-3z6v collection unlock %s" % sweep_suffix
	created_collection_id = _attempt_collection_create(
		adapter,
		config,
		results,
		"collection_create_four_mods",
		"Create collection with sample workout plus three public seed workouts",
		created_collection_name,
		"oc-3z6v-collection-unlock-%s" % sweep_suffix,
		collection_logo,
		collection_mod_ids
	)
	if created_collection_id > 0:
		var created_collection_id_text := str(created_collection_id)
		results.append(_run_check(
			"collections_after_create",
			"Browse public collections after collection unlock",
			adapter.build_collections_request(collection_query),
			config,
			func(response: Dictionary) -> Dictionary:
				var summary := harness.summarize_collections_response(adapter, response, COLLECTION_LIMIT)
				summary["expected_collection_id"] = created_collection_id
				return summary
		))
		results.append(_run_check(
			"collection_detail_after_create",
			"Read the created collection detail",
			adapter.build_collection_request(created_collection_id_text),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_collection_response(adapter, response)
		))
		results.append(_run_check(
			"collection_mods_after_create",
			"Read collection members after creation",
			adapter.build_collection_mods_request(created_collection_id_text, collection_query),
			config,
			func(response: Dictionary) -> Dictionary:
				var summary := harness.summarize_collection_mods_response(adapter, response, COLLECTION_LIMIT)
				summary["expected_mod_ids"] = collection_mod_ids
				return summary
		))
		results.append(_run_check(
			"me_collections_after_create",
			"Read owner collection inventory after collection creation",
			adapter.build_me_collections_request(collection_query),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_me_collections_response(adapter, response, COLLECTION_LIMIT)
		))
		results.append(_run_check(
			"collection_comments_initial",
			"Read collection comments before collection-specific writes",
			adapter.build_collection_comments_request(created_collection_id_text, comment_query),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_collection_comments_presence_response(adapter, response, COMMENT_LIMIT)
		))

	results.append_array(_cleanup_disposable_fixtures(adapter, config, harness, created_collection_id, created_seed_mod_ids))
	_print_summary(config, results, created_seed_mod_ids, created_seed_modfile_ids, created_collection_id, created_collection_name)
	quit(0 if _results_are_ok(results) else 1)

func _attempt_collection_create(adapter, config, results: Array[Dictionary], id: String, label: String, name: String, name_id: String, logo: Dictionary, mod_ids: Array[int]) -> int:
	var create_result := _run_check(
		id,
		label,
		adapter.build_add_collection_request({
			"name": name,
			"name_id": name_id,
			"summary": "Collection eligibility sandbox validation bundle.",
			"description": "Disposable collection used to validate collection eligibility rules in the AeroBeat sandbox.",
			"logo": logo,
			"category": COLLECTION_CATEGORY,
			"status": 1,
			"visible": 1,
			"tags": COLLECTION_TAGS,
			"mod_ids": mod_ids
		}),
		config,
		func(response: Dictionary) -> Dictionary:
			var summary := ModioLiveHarness.new().summarize_collection_response(adapter, response)
			summary["requested_mod_ids"] = mod_ids
			return summary
	)
	results.append(create_result)
	return int(create_result.get("details", {}).get("id", 0)) if str(create_result.get("status", "")) == "ok" else 0

func _cleanup_disposable_fixtures(adapter, config, harness: ModioLiveHarness, created_collection_id: int, created_seed_mod_ids: Array[int]) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if created_collection_id > 0:
		results.append(_run_check(
			"cleanup_collection_delete",
			"Delete the disposable collection unlock fixture",
			adapter.build_delete_collection_request(str(created_collection_id)),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_no_content_write_response(adapter, response, "deleted")
		))
	for index in range(created_seed_mod_ids.size() - 1, -1, -1):
		var mod_id := int(created_seed_mod_ids[index])
		if mod_id <= 0:
			continue
		results.append(_run_check(
			"cleanup_seed_mod_delete_%s" % str(index + 1),
			"Delete disposable seed workout %s" % str(index + 1),
			adapter.build_delete_mod_request(str(mod_id)),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_no_content_write_response(adapter, response, "deleted")
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

func _build_collection_logo_file_part(prefix: String) -> Dictionary:
	_ensure_temp_dir()
	var image := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	image.fill(Color8(255, 140, 0, 255))
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
	image.fill(Color8(0, 180, 255, 255))
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
		if str(result.get("status", "")) != "failed":
			continue
		if str(result.get("id", "")) == "collection_create_one_mod":
			continue
		return false
	return true

func _print_summary(config, results: Array[Dictionary], seed_mod_ids: Array[int], seed_modfile_ids: Array[int], collection_id: int, collection_name: String) -> void:
	print(JSON.stringify({
		"environment": "test",
		"base_url": config.resolve_base_url(),
		"host_kind": config.host_kind,
		"game_id": config.game_id,
		"seed_mod_ids": seed_mod_ids,
		"seed_modfile_ids": seed_modfile_ids,
		"created_collection_id": collection_id,
		"created_collection_name": collection_name,
		"checks": results,
		"ok": _results_are_ok(results)
	}, "  "))

func _print_errors_and_quit(errors: PackedStringArray, code: int) -> void:
	print(JSON.stringify({"ok": false, "errors": errors}, "  "))
	quit(code)
