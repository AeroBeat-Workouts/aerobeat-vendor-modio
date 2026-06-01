class_name ModioWorkoutUploadFlow
extends RefCounted

const PUBLISH_STATUS_ACCEPTED := 1
const PUBLISH_VISIBILITY_PUBLIC := 1
const DEFAULT_COMMUNITY_OPTIONS := 131072
const DEFAULT_METADATA_BLOB := "{}"
const MIN_LOGO_WIDTH := 512
const MIN_LOGO_HEIGHT := 288

func prepare_submission(fields: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	var name := _required_string(fields, "name", errors)
	var summary := _required_string(fields, "summary", errors)
	var metadata_kvp := _normalize_string_array(fields.get("metadata_kvp", fields.get("metadata", [])))
	if metadata_kvp.is_empty():
		errors.append("metadata_kvp is required and must contain at least one entry.")

	var logo_source := _normalize_existing_file(fields.get("logo_path", fields.get("logo", "")), "logo_path", errors)
	_validate_minimum_image_dimensions(logo_source.path, "logo_path", errors, MIN_LOGO_WIDTH, MIN_LOGO_HEIGHT)
	var zip_source := _normalize_existing_file(fields.get("zip_path", fields.get("filedata", "")), "zip_path", errors, PackedStringArray(["zip"]))
	var metadata_blob := str(fields.get("metadata_blob", DEFAULT_METADATA_BLOB)).strip_edges()
	if metadata_blob.is_empty():
		metadata_blob = DEFAULT_METADATA_BLOB

	var create_fields := {
		"name": name,
		"summary": summary,
		"logo": logo_source.request_value,
		"metadata_kvp": metadata_kvp,
		"metadata_blob": metadata_blob
	}
	_append_optional_string_field(fields, create_fields, "name_id")
	_append_optional_string_field(fields, create_fields, "description")
	_append_optional_string_array_field(fields, create_fields, "tags")
	_append_optional_int_field(fields, create_fields, "community_options")
	_append_optional_int_field(fields, create_fields, "maturity_option")
	_append_optional_int_field(fields, create_fields, "credit_options")
	_append_optional_int_field(fields, create_fields, "stock")

	if not create_fields.has("community_options"):
		create_fields["community_options"] = DEFAULT_COMMUNITY_OPTIONS

	var modfile_fields := {
		"filedata": zip_source.request_value
	}
	_append_optional_string_field(fields, modfile_fields, "version")
	_append_optional_string_field(fields, modfile_fields, "changelog")
	_append_optional_string_field(fields, modfile_fields, "modfile_metadata_blob")
	if modfile_fields.has("modfile_metadata_blob"):
		modfile_fields["metadata_blob"] = modfile_fields["modfile_metadata_blob"]
		modfile_fields.erase("modfile_metadata_blob")

	var publish_requested := bool(fields.get("publish_after_upload", fields.get("publish", false)))
	var publish_fields := _normalize_publish_fields(fields, create_fields, publish_requested)

	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"create_fields": create_fields,
		"modfile_fields": modfile_fields,
		"publish_fields": publish_fields,
		"publish_requested": publish_requested,
		"logo_source_path": logo_source.path,
		"zip_source_path": zip_source.path
	}

func submit_workout(manager, fields: Dictionary) -> Dictionary:
	var prepared := prepare_submission(fields)
	if not bool(prepared.get("ok", false)):
		return {
			"ok": false,
			"stage": "validation",
			"errors": prepared.get("errors", PackedStringArray()),
			"steps": [],
			"message": "Upload request is incomplete: %s" % "; ".join(prepared.get("errors", PackedStringArray()))
		}
	if manager == null:
		return _failed_result("client", "AeroModIOManager is required to submit workout uploads.")
	if not manager.has_public_credentials():
		return _failed_result("connection", "Game ID + API Key are required before workout uploads can run.")
	if not manager.has_access_token():
		return _failed_result("auth", "Athlete sign-in is required before creating or uploading workouts.")

	var steps: Array = []
	var create_step := _execute_step(manager, "create_draft", "build_add_mod_request", [prepared.get("create_fields", {})], "normalize_add_mod_response")
	steps.append(create_step)
	if not bool(create_step.get("ok", false)):
		return _result_from_steps(false, steps, create_step.get("message", "Failed to create the draft workout."))

	var created_mod: Dictionary = create_step.get("data", {})
	var mod_id := int(created_mod.get("id", 0))
	if mod_id <= 0:
		return _result_from_steps(false, steps, "mod.io created the workout draft, but the normalized response did not expose a valid mod id.")

	var upload_step := _execute_step(manager, "upload_modfile", "build_add_modfile_request", [str(mod_id), prepared.get("modfile_fields", {})], "normalize_add_modfile_response")
	steps.append(upload_step)
	if not bool(upload_step.get("ok", false)):
		return _result_from_steps(false, steps, upload_step.get("message", "Failed to upload the workout ZIP."), mod_id, created_mod)

	var created_modfile: Dictionary = upload_step.get("data", {})
	var publish_requested := bool(prepared.get("publish_requested", false))
	var published_mod: Dictionary = {}
	if publish_requested:
		var publish_step := _execute_step(manager, "publish_mod", "build_update_mod_request", [str(mod_id), prepared.get("publish_fields", {})], "normalize_update_mod_response")
		steps.append(publish_step)
		if not bool(publish_step.get("ok", false)):
			return _result_from_steps(false, steps, publish_step.get("message", "Workout draft and ZIP upload succeeded, but publish failed."), mod_id, created_mod, created_modfile)
		published_mod = publish_step.get("data", {})

	var message := "Created draft mod %s and uploaded modfile %s." % [mod_id, int(created_modfile.get("id", 0))]
	if publish_requested:
		message += " Published the workout to the public catalog."
	else:
		message += " Left the workout in draft state for follow-up review/publish."
	return {
		"ok": true,
		"stage": "complete",
		"steps": steps,
		"prepared": prepared,
		"mod_id": mod_id,
		"file_id": int(created_modfile.get("id", 0)),
		"created_mod": created_mod,
		"created_modfile": created_modfile,
		"published_mod": published_mod,
		"publish_requested": publish_requested,
		"message": message
	}

func _execute_step(manager, stage: String, builder_method: StringName, builder_args: Array, normalizer_method: StringName) -> Dictionary:
	var raw_response: Dictionary = manager.execute_adapter_request(builder_method, builder_args)
	if not bool(raw_response.get("ok", false)):
		return {
			"stage": stage,
			"ok": false,
			"raw": raw_response,
			"message": _response_error_message(raw_response, "mod.io request failed during %s." % stage)
		}
	var normalized = manager.normalize_with_adapter(normalizer_method, [int(raw_response.get("status_code", 0)), raw_response.get("headers", {}), raw_response.get("payload", {})])
	if not (normalized is Dictionary):
		return {
			"stage": stage,
			"ok": false,
			"raw": raw_response,
			"message": "Missing or invalid normalizer result for %s." % stage
		}
	if not bool(normalized.get("ok", false)):
		return {
			"stage": stage,
			"ok": false,
			"raw": raw_response,
			"normalized": normalized,
			"message": _response_error_message(normalized, "mod.io rejected %s." % stage)
		}
	return {
		"stage": stage,
		"ok": true,
		"raw": raw_response,
		"normalized": normalized,
		"data": normalized.get("data", {}),
		"message": "ok"
	}

func _response_error_message(response: Dictionary, fallback: String) -> String:
	var error_payload = response.get("error", {})
	if error_payload is Dictionary:
		var parts := PackedStringArray()
		var message := str(error_payload.get("message", "")).strip_edges()
		if not message.is_empty():
			parts.append(message)
		var detail_bits := _flatten_error_details(error_payload.get("details", {}))
		if not detail_bits.is_empty():
			parts.append("Details: %s" % "; ".join(detail_bits))
		var error_ref := int(error_payload.get("error_ref", 0))
		if error_ref > 0:
			parts.append("error_ref=%s" % error_ref)
		if not parts.is_empty():
			return " ".join(parts)
	return fallback

func _failed_result(stage: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"stage": stage,
		"steps": [],
		"message": message
	}

func _result_from_steps(ok: bool, steps: Array, message: String, mod_id: int = 0, created_mod: Dictionary = {}, created_modfile: Dictionary = {}) -> Dictionary:
	return {
		"ok": ok,
		"stage": "complete" if ok else (steps[-1].get("stage", "unknown") if not steps.is_empty() else "unknown"),
		"steps": steps,
		"message": message,
		"mod_id": mod_id,
		"created_mod": created_mod,
		"created_modfile": created_modfile,
		"file_id": int(created_modfile.get("id", 0))
	}

func _normalize_publish_fields(fields: Dictionary, create_fields: Dictionary, publish_requested: bool) -> Dictionary:
	if not publish_requested:
		return {}
	var publish_fields := {
		"status": PUBLISH_STATUS_ACCEPTED,
		"visible": int(fields.get("publish_visible", PUBLISH_VISIBILITY_PUBLIC))
	}
	if create_fields.has("summary"):
		publish_fields["summary"] = create_fields.get("summary", "")
	if create_fields.has("community_options"):
		publish_fields["community_options"] = int(create_fields.get("community_options", DEFAULT_COMMUNITY_OPTIONS))
	if fields.has("publish_fields") and fields.get("publish_fields") is Dictionary:
		publish_fields.merge(fields.get("publish_fields", {}), true)
	return publish_fields

func _required_string(fields: Dictionary, field_name: String, errors: PackedStringArray) -> String:
	var value := str(fields.get(field_name, "")).strip_edges()
	if value.is_empty():
		errors.append("%s is required." % field_name)
	return value

func _append_optional_string_field(source: Dictionary, target: Dictionary, field_name: String) -> void:
	var value := str(source.get(field_name, "")).strip_edges()
	if not value.is_empty():
		target[field_name] = value

func _append_optional_int_field(source: Dictionary, target: Dictionary, field_name: String) -> void:
	if not source.has(field_name):
		return
	var raw = source.get(field_name)
	if raw == null:
		return
	if raw is String and str(raw).strip_edges().is_empty():
		return
	target[field_name] = int(raw)

func _append_optional_string_array_field(source: Dictionary, target: Dictionary, field_name: String) -> void:
	var values: Array = _normalize_string_array(source.get(field_name, []))
	if not values.is_empty():
		target[field_name] = values

func _normalize_string_array(value: Variant) -> Array:
	var result: Array = []
	if value is PackedStringArray:
		for entry in value:
			var cleaned := str(entry).strip_edges()
			if not cleaned.is_empty():
				result.append(cleaned)
		return result
	if value is Array:
		for entry in value:
			var cleaned := str(entry).strip_edges()
			if not cleaned.is_empty():
				result.append(cleaned)
		return result
	var flattened := str(value).replace("\n", ",")
	for part in flattened.split(","):
		var cleaned := part.strip_edges()
		if not cleaned.is_empty():
			result.append(cleaned)
	return result

func _normalize_existing_file(value: Variant, field_name: String, errors: PackedStringArray, allowed_extensions: PackedStringArray = PackedStringArray()) -> Dictionary:
	var raw_path := str(value).strip_edges()
	if raw_path.begins_with("@"):
		raw_path = raw_path.substr(1)
	if raw_path.is_empty():
		errors.append("%s is required." % field_name)
		return {"path": "", "request_value": ""}
	var absolute_path := ProjectSettings.globalize_path(raw_path) if raw_path.begins_with("res://") or raw_path.begins_with("user://") else raw_path
	if not FileAccess.file_exists(absolute_path):
		errors.append("%s must point to an existing file." % field_name)
	if not allowed_extensions.is_empty():
		var extension := absolute_path.get_extension().to_lower()
		if not allowed_extensions.has(extension):
			errors.append("%s must use one of these extensions: %s." % [field_name, ", ".join(allowed_extensions)])
	return {
		"path": absolute_path,
		"request_value": "@%s" % absolute_path
	}

func _validate_minimum_image_dimensions(path: String, field_name: String, errors: PackedStringArray, minimum_width: int, minimum_height: int) -> void:
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		errors.append("%s must be a readable image file." % field_name)
		return
	if image.get_width() < minimum_width or image.get_height() < minimum_height:
		errors.append("%s must be at least %dx%d pixels for mod.io create-draft validation." % [field_name, minimum_width, minimum_height])

func _flatten_error_details(details: Variant, prefix: String = "") -> PackedStringArray:
	var result := PackedStringArray()
	if details is Dictionary:
		for key in details.keys():
			var nested_prefix := "%s.%s" % [prefix, str(key)] if not prefix.is_empty() else str(key)
			result.append_array(_flatten_error_details(details.get(key), nested_prefix))
		return result
	if details is Array:
		for entry in details:
			result.append_array(_flatten_error_details(entry, prefix))
		return result
	var cleaned := str(details).strip_edges()
	if cleaned.is_empty():
		return result
	result.append("%s: %s" % [prefix, cleaned] if not prefix.is_empty() else cleaned)
	return result
