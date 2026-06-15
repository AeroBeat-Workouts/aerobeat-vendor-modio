extends Control

const ModioSceneRunner = preload("res://scripts/modio_scene_runner.gd")
const SCENE_GROUP_ID := "paid_mods"
const SCENE_DESCRIPTION := "Monetization route matrix:\n• Bearer reads — token packs, wallet, purchased\n• Owned-mod read — monetization team for owned_mod_id / paid_mod_id\n• Guarded buyer writes — entitlements + checkout stay opt-in\n• S2S/history reads — shown with the current service_token assumption and open question"
const INITIAL_OUTPUT := "Press Run Checks to see the monetization route groups, what Run Checks covers, and which prerequisites are currently missing."

var _runner := ModioSceneRunner.new()

func _ready() -> void:
	$MarginContainer/VBoxContainer/DescriptionLabel.text = SCENE_DESCRIPTION
	$MarginContainer/VBoxContainer/RunButton.pressed.connect(_on_run_button_pressed)
	$MarginContainer/VBoxContainer/OutputEdit.text = INITIAL_OUTPUT

func describe_scene_surface() -> Dictionary:
	return {
		"group_id": SCENE_GROUP_ID,
		"description": SCENE_DESCRIPTION,
		"initial_output": INITIAL_OUTPUT,
		"has_run_button": is_instance_valid($MarginContainer/VBoxContainer/RunButton),
		"has_output": is_instance_valid($MarginContainer/VBoxContainer/OutputEdit)
	}

func _on_run_button_pressed() -> void:
	$MarginContainer/VBoxContainer/OutputEdit.text = "Running %s…" % SCENE_GROUP_ID
	var report := _runner.run_group(SCENE_GROUP_ID)
	$MarginContainer/VBoxContainer/OutputEdit.text = _runner.stringify_report(report)
