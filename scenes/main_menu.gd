extends Control

@onready var start_button: Button = $"MarginContainer/main button/start"
@onready var continue_button: Button = $"MarginContainer/main button/continue"
@onready var setting_button: Button = $"MarginContainer/main button/setting"
@onready var exit_button: Button = $"MarginContainer/main button/exit"


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	setting_button.pressed.connect(_on_setting_pressed)
	exit_button.pressed.connect(_on_exit_pressed)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/chapter1.tscn")


func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/chapter1.tscn")


func _on_setting_pressed() -> void:
	var settings_scene := preload("res://scenes/settings.tscn")
	var settings_instance := settings_scene.instantiate()
	get_tree().root.add_child(settings_instance)


func _on_exit_pressed() -> void:
	get_tree().quit()
