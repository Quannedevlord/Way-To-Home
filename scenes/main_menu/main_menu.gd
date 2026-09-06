extends Control

const SettingsScript = preload("res://scenes/settings/settings.gd")

@export var start_button: Button
@export var continue_button: Button
@export var setting_button: Button
@export var exit_button: Button


func _ready() -> void:
	SettingsScript.apply_saved_audio_settings()
	continue_button.visible = GameManager.has_save()
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	setting_button.pressed.connect(_on_setting_pressed)
	exit_button.pressed.connect(_on_exit_pressed)


func _on_start_pressed() -> void:
	GameManager.change_scene("res://scenes/chapters/chapter_01/chapter1.tscn")


func _on_continue_pressed() -> void:
	var save_data := GameManager.load_game()
	GameManager.change_scene(save_data.get("current_scene", "res://scenes/chapters/chapter_01/chapter1.tscn"))


func _on_setting_pressed() -> void:
	var settings_scene := preload("res://scenes/settings/settings.tscn")
	var settings_instance := settings_scene.instantiate()
	get_tree().root.add_child(settings_instance)


func _on_exit_pressed() -> void:
	get_tree().quit()