extends Control

const SETTINGS_SCENE := preload("res://scenes/settings/settings.tscn")

@onready var menu_button: TextureButton = $CanvasLayer/MenuButton
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var popup_panel: Control = get_node_or_null("CanvasLayer/PopupPanel")
@onready var settings_button: Button = get_node_or_null("CanvasLayer/PopupPanel/VBoxContainer/setting")
@onready var main_menu_button: Button = get_node_or_null("CanvasLayer/PopupPanel/VBoxContainer/main_menu")
@onready var close_button: Button = get_node_or_null("CanvasLayer/PopupPanel/VBoxContainer/close")


func _ready() -> void:
	menu_button.pressed.connect(_on_menu_button_pressed)
	if settings_button != null:
		settings_button.pressed.connect(_on_setting_button_pressed)
	if main_menu_button != null:
		main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	if close_button != null:
		close_button.pressed.connect(_on_close_button_pressed)
	if popup_panel != null:
		popup_panel.hide()


func _on_menu_button_pressed() -> void:
	_open_settings()


func _process(_delta: float) -> void:
	var current_scene = get_tree().current_scene

	if current_scene == null:
		return

	if current_scene.name == "MainMenu" or current_scene.name == "Splash":
		canvas_layer.visible = false
	else:
		canvas_layer.visible = true


func _on_setting_button_pressed() -> void:
	if popup_panel != null:
		popup_panel.visible = false
	_open_settings()


func _open_settings() -> void:
	# Settings là lớp phủ, nên scene đang chơi và tiến độ hiện tại không bị thay đổi.
	if get_tree().root.get_node_or_null("Setting") != null:
		return
	var settings_instance := SETTINGS_SCENE.instantiate()
	get_tree().root.add_child(settings_instance)


func _on_close_button_pressed() -> void:
	if popup_panel != null:
		popup_panel.hide()


func _on_main_menu_button_pressed() -> void:
	print("Về giao diện chính")
