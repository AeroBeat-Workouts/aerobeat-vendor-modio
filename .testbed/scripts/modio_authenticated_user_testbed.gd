extends Control

const ModioSceneRunner = preload("res://scripts/modio_scene_runner.gd")
const SCENE_GROUP_ID := "authenticated_user"
const SCENE_DESCRIPTION := "Authenticated user-state reads: /me, owned games/mods/files, subscriptions, ratings, collections, followers, and muted-user state using local session config."

var _runner := ModioSceneRunner.new()

func _ready() -> void:
	$MarginContainer/VBoxContainer/DescriptionLabel.text = SCENE_DESCRIPTION
	$MarginContainer/VBoxContainer/RunButton.pressed.connect(_on_run_button_pressed)
	$MarginContainer/VBoxContainer/OutputEdit.text = "Press Run Checks to exercise the %s slice." % SCENE_GROUP_ID

func describe_scene_surface() -> Dictionary:
	return {
		"group_id": SCENE_GROUP_ID,
		"description": SCENE_DESCRIPTION,
		"has_run_button": is_instance_valid($MarginContainer/VBoxContainer/RunButton),
		"has_output": is_instance_valid($MarginContainer/VBoxContainer/OutputEdit)
	}

func _on_run_button_pressed() -> void:
	$MarginContainer/VBoxContainer/OutputEdit.text = "Running %s…" % SCENE_GROUP_ID
	var report := _runner.run_group(SCENE_GROUP_ID)
	$MarginContainer/VBoxContainer/OutputEdit.text = _runner.stringify_report(report)
