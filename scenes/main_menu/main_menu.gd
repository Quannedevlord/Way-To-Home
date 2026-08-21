extends Control

const SettingsScript = preload("res://scenes/settings/settings.gd")

@export var start_button: Button
@export var continue_button: Button
@export var setting_button: Button
@export var exit_button: Button


func _ready() -> void:
	SettingsScript.apply_saved_audio_settings()
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	setting_button.pressed.connect(_on_setting_pressed)
	exit_button.pressed.connect(_on_exit_pressed)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/chapters/chapter_01/chapter1.tscn")


func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/chapters/chapter_01/chapter1.tscn")


func _on_setting_pressed() -> void:
	var settings_scene := preload("res://scenes/settings/settings.tscn")
	var settings_instance := settings_scene.instantiate()
	get_tree().root.add_child(settings_instance)


func _on_exit_pressed() -> void:
	get_tree().quit()
