extends Control

const SETTINGS_SCENE := preload("res://scenes/settings/settings.tscn")
const HOVER_SCALE := Vector2(1.12, 1.12)
const HOVER_DURATION := 0.12

@onready var menu_button: TextureButton = $CanvasLayer/MenuButton
@onready var canvas_layer: CanvasLayer = $CanvasLayer as CanvasLayer
@onready var popup_panel: Control = get_node_or_null("CanvasLayer/PopupPanel") as Control
@onready var settings_button: Button = get_node_or_null("CanvasLayer/PopupPanel/VBoxContainer/setting") as Button
@onready var main_menu_button: Button = get_node_or_null("CanvasLayer/PopupPanel/VBoxContainer/main_menu") as Button
@onready var close_button: Button = get_node_or_null("CanvasLayer/PopupPanel/VBoxContainer/close") as Button

var _hover_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	if menu_button == null:
		push_error("[GlobalMenu] Không tìm thấy CanvasLayer/MenuButton.")
		return
	menu_button.process_mode = Node.PROCESS_MODE_ALWAYS
	if popup_panel != null:
		popup_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_button.pivot_offset = menu_button.size * 0.5
	if not menu_button.pressed.is_connected(_on_menu_button_pressed):
		menu_button.pressed.connect(_on_menu_button_pressed)
	if not menu_button.mouse_entered.is_connected(_on_menu_button_mouse_entered):
		menu_button.mouse_entered.connect(_on_menu_button_mouse_entered)
	if not menu_button.mouse_exited.is_connected(_on_menu_button_mouse_exited):
		menu_button.mouse_exited.connect(_on_menu_button_mouse_exited)
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


func _on_menu_button_mouse_entered() -> void:
	_animate_menu_button(HOVER_SCALE, Color(1.12, 1.12, 1.12, 1.0))


func _on_menu_button_mouse_exited() -> void:
	_animate_menu_button(Vector2.ONE, Color.WHITE)


func _animate_menu_button(target_scale: Vector2, target_modulate: Color) -> void:
	if _hover_tween != null and _hover_tween.is_running():
		_hover_tween.kill()
	_hover_tween = create_tween().set_parallel(true)
	_hover_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(menu_button, "scale", target_scale, HOVER_DURATION)
	_hover_tween.tween_property(menu_button, "modulate", target_modulate, HOVER_DURATION)


func _process(_delta: float) -> void:
	var current_scene = get_tree().current_scene

	if current_scene == null:
		return

	if current_scene.name == "MainMenu" or current_scene.name == "Splash" or current_scene.name == "Credits":
		canvas_layer.visible = false
	else:
		canvas_layer.visible = true


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode != KEY_ESCAPE and event.physical_keycode != KEY_ESCAPE:
		return
	if not canvas_layer.visible:
		return

	_open_settings()
	get_viewport().set_input_as_handled()


func _on_setting_button_pressed() -> void:
	if popup_panel != null:
		popup_panel.visible = false
	_open_settings()


func _open_settings() -> void:
	# Settings là lớp phủ, nên scene đang chơi và tiến độ hiện tại không bị thay đổi.
	if get_tree().root.get_node_or_null("Setting") != null:
		return
	GameManager.set_paused(true)
	var settings_instance := SETTINGS_SCENE.instantiate()
	settings_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(settings_instance)


func _on_close_button_pressed() -> void:
	if popup_panel != null:
		popup_panel.hide()


func _on_main_menu_button_pressed() -> void:
	GameManager.set_paused(false)
	GameManager.change_scene(GameManager.MAIN_MENU_PATH)
