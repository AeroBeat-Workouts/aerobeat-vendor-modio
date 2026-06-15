extends SceneTree

const ModioEnvLoader = preload("res://modio_env_loader.gd")
const ModioVendorAdapter = preload("res://src/modio_vendor_adapter.gd")
const ModioHttpTransport = preload("res://src/network/modio_http_transport.gd")
const ModioListingQuery = preload("res://src/models/modio_listing_query.gd")
const ModioLiveHarness = preload("res://modio_live_harness_lib.gd")

const SAMPLE_MOD_LIMIT := 5
const COMMENT_LIMIT := 5
const TEMP_DIR := "user://modio_unlocked_family_harness"

func _initialize() -> void:
	var loader := ModioEnvLoader.new()
	var config = loader.build_client_config("test")
	var harness := ModioLiveHarness.new()
	var adapter := ModioVendorAdapter.new(config, ModioHttpTransport.new())
	var results: Array[Dictionary] = []

	if not config.has_public_credentials():
		_print_errors_and_quit(["Selected test environment is missing public game credentials"], 1)
		return
	if not config.has_access_token():
		_print_errors_and_quit(["Selected test environment is missing an access token in modio.session.local.cfg"], 1)
		return

	var mod_query := ModioListingQuery.new("", PackedStringArray(), SAMPLE_MOD_LIMIT, 0)
	var comment_query := ModioListingQuery.new("", PackedStringArray(), COMMENT_LIMIT, 0)
	var mods_result := _run_check(
		"mods",
		"Browse existing public sandbox mods",
		adapter.build_listing_request(mod_query),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_mods_response(adapter, response, SAMPLE_MOD_LIMIT)
	)
	results.append(mods_result)
	var parent_mod_id := int(mods_result.get("details", {}).get("selected_mod_id", 0))
	if parent_mod_id <= 0:
		results.append(_skipped_check("mod_comment_family", "Exercise mod comment family", "Skipped because no public sandbox mod was available"))
		results.append(_skipped_check("dependency_family", "Exercise dependency family", "Skipped because no public sandbox mod was available"))
		_print_summary(config, results)
		quit(1)
		return

	var mod_id_text := str(parent_mod_id)
	results.append(_run_check(
		"mod_comments_initial",
		"Read public mod comments before writes",
		adapter.build_mod_comments_request(mod_id_text, comment_query),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_mod_comments_presence_response(adapter, response, COMMENT_LIMIT)
	))

	var sweep_suffix := str(int(Time.get_unix_time_from_system()))
	var mod_comment_create_text := "oc-0fm mod comment create %s" % sweep_suffix
	var mod_comment_update_text := "oc-0fm mod comment update %s" % sweep_suffix
	var guide_name_id := "oc-0fm-guide-%s" % sweep_suffix
	var guide_name := "oc-0fm guide %s" % sweep_suffix
	var guide_comment_create_text := "oc-0fm guide comment create %s" % sweep_suffix
	var guide_comment_update_text := "oc-0fm guide comment update %s" % sweep_suffix
	var dependency_target_name_id := "oc-0fm-dependency-target-%s" % sweep_suffix
	var dependency_target_name := "oc-0fm dependency target %s" % sweep_suffix
	var temp_logo := _build_logo_file_part("guide-%s" % sweep_suffix)
	var temp_build := _build_zip_file_part("dependency-%s" % sweep_suffix, "oc-0fm dependency target build %s\n" % sweep_suffix)

	var created_guide_id := 0
	var created_target_mod_id := 0

	var mod_comment_create_result := _run_check(
		"mod_comment_create",
		"Create a disposable mod comment on the public sandbox workout",
		adapter.build_add_mod_comment_request(mod_id_text, mod_comment_create_text),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_mod_comment_write_response(adapter, response)
	)
	results.append(mod_comment_create_result)
	var mod_comment_id := int(mod_comment_create_result.get("details", {}).get("comment_id", 0)) if str(mod_comment_create_result.get("status", "")) == "ok" else 0
	if mod_comment_id > 0:
		var mod_comment_id_text := str(mod_comment_id)
		results.append(_run_check(
			"mod_comment_detail",
			"Read back the created mod comment",
			adapter.build_mod_comment_request(mod_id_text, mod_comment_id_text),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_mod_comment_detail_response(adapter, response)
		))
		results.append(_run_check(
			"mod_comment_list_after_create",
			"Verify the created mod comment appears in the public list",
			adapter.build_mod_comments_request(mod_id_text, comment_query),
			config,
			func(response: Dictionary) -> Dictionary:
				var summary := harness.summarize_mod_comments_presence_response(adapter, response, COMMENT_LIMIT, mod_comment_id)
				summary["expected_present"] = bool(summary.get("found_comment_id", false))
				return summary
		))
		results.append(_run_check(
			"mod_comment_update",
			"Update the created mod comment",
			adapter.build_update_mod_comment_request(mod_id_text, mod_comment_id_text, mod_comment_update_text),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_mod_comment_write_response(adapter, response)
		))
		results.append(_run_check(
			"mod_comment_detail_after_update",
			"Verify the updated mod comment",
			adapter.build_mod_comment_request(mod_id_text, mod_comment_id_text),
			config,
			func(response: Dictionary) -> Dictionary:
				var summary := harness.summarize_mod_comment_detail_response(adapter, response)
				summary["expected_content"] = mod_comment_update_text
				summary["matches_expected_content"] = str(summary.get("content", "")) == mod_comment_update_text
				return summary
		))
		results.append(_run_check(
			"mod_comment_delete",
			"Delete the created mod comment",
			adapter.build_delete_mod_comment_request(mod_id_text, mod_comment_id_text),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_no_content_write_response(adapter, response, "deleted")
		))
		results.append(_run_check(
			"mod_comment_list_after_delete",
			"Verify the deleted mod comment is gone from the public list",
			adapter.build_mod_comments_request(mod_id_text, comment_query),
			config,
			func(response: Dictionary) -> Dictionary:
				var summary := harness.summarize_mod_comments_presence_response(adapter, response, COMMENT_LIMIT, mod_comment_id)
				summary["expected_absent"] = not bool(summary.get("found_comment_id", false))
				return summary
		))

	var guide_create_result := _run_check(
		"guide_create",
		"Create a disposable guide with guide comments enabled",
		adapter.build_add_guide_request({
			"name": guide_name,
			"name_id": guide_name_id,
			"summary": "Disposable guide for oc-0fm sandbox validation.",
			"description": "Disposable guide body for oc-0fm sandbox validation.",
			"logo": temp_logo,
			"tags": ["exercise"],
			"status": 1,
			"community_options": ModioVendorAdapter.COMMUNITY_OPTION_ALLOW_GUIDE_COMMENTS,
			"date_live": int(Time.get_unix_time_from_system())
		}),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_guide_response(adapter, response)
	)
	results.append(guide_create_result)
	created_guide_id = int(guide_create_result.get("details", {}).get("id", 0)) if str(guide_create_result.get("status", "")) == "ok" else 0
	if created_guide_id > 0:
		var guide_id_text := str(created_guide_id)
		results.append(_run_check(
			"guides_after_create",
			"Browse public guides after creating the disposable guide",
			adapter.build_guides_request(mod_query),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_guides_response(adapter, response, SAMPLE_MOD_LIMIT)
		))
		results.append(_run_check(
			"guide_detail",
			"Read the created guide detail",
			adapter.build_guide_detail_request(guide_id_text),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_guide_response(adapter, response)
		))
		results.append(_run_check(
			"guide_update",
			"Update the disposable guide",
			adapter.build_update_guide_request(guide_id_text, {
				"summary": "Disposable guide for oc-0fm sandbox validation updated.",
				"description": "Updated disposable guide body for oc-0fm sandbox validation.",
				"community_options": ModioVendorAdapter.COMMUNITY_OPTION_ALLOW_GUIDE_COMMENTS,
				"status": 1,
				"url": "https://example.com/%s" % guide_name_id,
				"tags": ["exercise", "guide"]
			}),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_guide_response(adapter, response)
		))
		results.append(_run_check(
			"guide_detail_after_update",
			"Verify the updated guide detail",
			adapter.build_guide_detail_request(guide_id_text),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_guide_response(adapter, response)
		))
		results.append(_run_check(
			"guide_tags_after_update",
			"Read the public guide tag directory after guide creation",
			adapter.build_guide_tags_request(),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_guide_tags_response(adapter, response)
		))
		results.append(_run_check(
			"guide_comments_initial",
			"Read guide comments before writing",
			adapter.build_guide_comments_request(guide_id_text, comment_query),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_guide_comments_presence_response(adapter, response, COMMENT_LIMIT)
		))
		var guide_comment_create_result := _run_check(
			"guide_comment_create",
			"Create a disposable guide comment",
			adapter.build_add_guide_comment_request(guide_id_text, guide_comment_create_text),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_guide_comment_write_response(adapter, response)
		)
		results.append(guide_comment_create_result)
		var guide_comment_id := int(guide_comment_create_result.get("details", {}).get("comment_id", 0)) if str(guide_comment_create_result.get("status", "")) == "ok" else 0
		if guide_comment_id > 0:
			var guide_comment_id_text := str(guide_comment_id)
			results.append(_run_check(
				"guide_comment_detail",
				"Read back the created guide comment",
				adapter.build_guide_comment_request(guide_id_text, guide_comment_id_text),
				config,
				func(response: Dictionary) -> Dictionary:
					return harness.summarize_guide_comment_detail_response(adapter, response)
			))
			results.append(_run_check(
				"guide_comment_list_after_create",
				"Verify the created guide comment appears in the public list",
				adapter.build_guide_comments_request(guide_id_text, comment_query),
				config,
				func(response: Dictionary) -> Dictionary:
					var summary := harness.summarize_guide_comments_presence_response(adapter, response, COMMENT_LIMIT, guide_comment_id)
					summary["expected_present"] = bool(summary.get("found_comment_id", false))
					return summary
			))
			results.append(_run_check(
				"guide_comment_update",
				"Update the created guide comment",
				adapter.build_update_guide_comment_request(guide_id_text, guide_comment_id_text, guide_comment_update_text),
				config,
				func(response: Dictionary) -> Dictionary:
					return harness.summarize_guide_comment_write_response(adapter, response)
			))
			results.append(_run_check(
				"guide_comment_detail_after_update",
				"Verify the updated guide comment",
				adapter.build_guide_comment_request(guide_id_text, guide_comment_id_text),
				config,
				func(response: Dictionary) -> Dictionary:
					var summary := harness.summarize_guide_comment_detail_response(adapter, response)
					summary["expected_content"] = guide_comment_update_text
					summary["matches_expected_content"] = str(summary.get("content", "")) == guide_comment_update_text
					return summary
			))
			results.append(_run_check(
				"guide_comment_delete",
				"Delete the created guide comment",
				adapter.build_delete_guide_comment_request(guide_id_text, guide_comment_id_text),
				config,
				func(response: Dictionary) -> Dictionary:
					return harness.summarize_no_content_write_response(adapter, response, "deleted")
			))
			results.append(_run_check(
				"guide_comment_list_after_delete",
				"Verify the deleted guide comment is gone from the public list",
				adapter.build_guide_comments_request(guide_id_text, comment_query),
				config,
				func(response: Dictionary) -> Dictionary:
					var summary := harness.summarize_guide_comments_presence_response(adapter, response, COMMENT_LIMIT, guide_comment_id)
					summary["expected_absent"] = not bool(summary.get("found_comment_id", false))
					return summary
			))

	var target_mod_create_result := _run_check(
		"dependency_target_create",
		"Create a disposable dependency target mod",
		adapter.build_add_mod_request({
			"name": dependency_target_name,
			"name_id": dependency_target_name_id,
			"summary": "Disposable dependency target for oc-0fm.",
			"description": "Disposable dependency target body for oc-0fm sandbox validation.",
			"logo": temp_logo,
			"metadata_kvp": ["oc-0fm=dependency-target-%s" % sweep_suffix],
			"metadata_blob": "{}"
		}),
		config,
		func(response: Dictionary) -> Dictionary:
			return harness.summarize_mod_detail_response(adapter, response)
	)
	results.append(target_mod_create_result)
	created_target_mod_id = int(target_mod_create_result.get("details", {}).get("id", 0)) if str(target_mod_create_result.get("status", "")) == "ok" else 0
	if created_target_mod_id > 0:
		var target_mod_id_text := str(created_target_mod_id)
		results.append(_run_check(
			"dependency_target_modfile_add",
			"Upload a disposable build for the dependency target mod",
			adapter.build_add_modfile_request(target_mod_id_text, {
				"filedata": temp_build,
				"version": "0.0.1",
				"changelog": "oc-0fm dependency target build",
				"metadata_blob": "{\"build\":\"oc-0fm\"}"
			}),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_modfile_response(adapter, response)
		))
		var dependency_fields := {"dependencies": [created_target_mod_id]}
		results.append(_run_check(
			"dependency_add",
			"Add the disposable dependency target to the public sandbox workout",
			adapter.build_add_mod_dependencies_request(mod_id_text, dependency_fields),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_message_write_response(adapter, response, "created")
		))
		results.append(_run_check(
			"dependency_read_parent",
			"Read dependencies from the public sandbox workout after adding one",
			adapter.build_dependencies_request(mod_id_text, false),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_dependencies_response(adapter, response)
		))
		results.append(_run_check(
			"dependency_read_target_dependants",
			"Read dependants from the disposable dependency target",
			adapter.build_dependants_request(target_mod_id_text, comment_query),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_dependants_response(adapter, response)
		))
		results.append(_run_check(
			"dependency_delete",
			"Delete the disposable dependency from the public sandbox workout",
			adapter.build_delete_mod_dependencies_request(mod_id_text, dependency_fields),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_no_content_write_response(adapter, response, "deleted")
		))
		results.append(_run_check(
			"dependency_read_parent_after_delete",
			"Verify the disposable dependency no longer appears on the parent workout",
			adapter.build_dependencies_request(mod_id_text, false),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_dependencies_response(adapter, response)
		))

	if created_guide_id > 0:
		results.append(_run_check(
			"guide_delete",
			"Delete the disposable guide",
			adapter.build_delete_guide_request(str(created_guide_id)),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_no_content_write_response(adapter, response, "deleted")
		))
	if created_target_mod_id > 0:
		results.append(_run_check(
			"dependency_target_delete",
			"Delete the disposable dependency target mod",
			adapter.build_delete_mod_request(str(created_target_mod_id)),
			config,
			func(response: Dictionary) -> Dictionary:
				return harness.summarize_no_content_write_response(adapter, response, "deleted")
		))

	_print_summary(config, results)
	quit(0 if _results_are_ok(results) else 1)

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

func _skipped_check(id: String, label: String, reason: String) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"status": "skipped",
		"details": {"reason": reason}
	}

func _build_logo_file_part(prefix: String) -> Dictionary:
	_ensure_temp_dir()
	var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	image.fill(Color8(0, 180, 255, 255))
	var path := "%s/%s.png" % [TEMP_DIR, prefix]
	var save_error := image.save_png(path)
	if save_error != OK:
		push_error("Failed to save temp PNG: %s" % error_string(save_error))
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
		if str(result.get("status", "")) == "failed":
			return false
		var details: Dictionary = result.get("details", {})
		if details.has("expected_present") and not bool(details.get("expected_present", false)):
			return false
		if details.has("expected_absent") and not bool(details.get("expected_absent", false)):
			return false
		if details.has("matches_expected_content") and not bool(details.get("matches_expected_content", false)):
			return false
	return true

func _print_summary(config, results: Array[Dictionary]) -> void:
	print(JSON.stringify({
		"environment": "test",
		"base_url": config.resolve_base_url(),
		"host_kind": config.host_kind,
		"game_id": config.game_id,
		"checks": results,
		"ok": _results_are_ok(results)
	}, "  "))

func _print_errors_and_quit(errors: PackedStringArray, code: int) -> void:
	print(JSON.stringify({"ok": false, "errors": errors}, "  "))
	quit(code)
