extends Control

const SettingsScript = preload("res://scenes/settings/settings.gd")

@export var start_button: Button
@export var continue_button: Button
@export var setting_button: Button
@export var exit_button: Button

# Đổi đường dẫn tại đây nếu muốn thay icon chuột thường hoặc icon khi hover.
var cursor_normal = preload("res://assets/backgrounds/ui/cursor.png")
var cursor_hover = preload("res://assets/backgrounds/ui/cursor_hover.png")

func _ready() -> void:
	GlobalMenu.get_node("CanvasLayer").hide()	
	SettingsScript.apply_saved_audio_settings()
	continue_button.visible = GameManager.has_save()
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	setting_button.pressed.connect(_on_setting_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	Input.set_custom_mouse_cursor(cursor_normal)
	# Khi thêm Button mới vào menu, thêm biến đó vào danh sách này để có cursor hover.
	for button in [start_button, continue_button, setting_button, exit_button]:
		button.mouse_entered.connect(_on_button_mouse_entered)
		button.mouse_exited.connect(_on_button_mouse_exited)


# Chỉ thay icon chuột; âm thanh hover được xử lý trong hover_sfx.gd.
func _on_button_mouse_entered() -> void:
	Input.set_custom_mouse_cursor(cursor_hover)


# Rời nút thì trả cursor về trạng thái bình thường.
func _on_button_mouse_exited() -> void:
	Input.set_custom_mouse_cursor(cursor_normal)
	


func _on_start_pressed() -> void:
	GameManager.start_new_game()
	GameManager.change_scene("res://scenes/chapters/chapter_01/chapter1.tscn")


func _on_continue_pressed() -> void:
	var save_data: Dictionary = GameManager.load_game()
	var saved_scene: String = save_data.get("current_scene", "")
	if not GameManager.has_save() or bool(save_data.get("completed", false)) or saved_scene.is_empty() or not ResourceLoader.exists(saved_scene):
		continue_button.visible = false
		return
	GameManager.change_scene(saved_scene)


func _on_setting_pressed() -> void:
	var settings_scene := preload("res://scenes/settings/settings.tscn")
	var settings_instance := settings_scene.instantiate()
	get_tree().root.add_child(settings_instance)


func _on_exit_pressed() -> void:
	get_tree().quit()
