extends Control
## Điều khiển menu chính: chơi mới, Continue từ save, cài đặt và thoát.
## Nếu đã có mốc hoặc kết thúc, thêm sổ tay để người chơi xem lại ngay tại menu.

const SettingsScript = preload("res://scenes/settings/settings.gd")

# Bốn nút được gán trên root của main_menu.tscn trong Inspector.
@export var start_button: Button
@export var continue_button: Button
@export var setting_button: Button
@export var exit_button: Button

var new_game_dialog: ConfirmationDialog
var _new_game_shade: ColorRect
var _starting_new_game := false


## Thiết lập menu chính, cập nhật nút tiếp tục theo dữ liệu lưu và kết nối sự kiện.
func _ready() -> void:
	GameManager.load_campaign()
	if not GameManager.story_checkpoints.is_empty() or not GameManager.seen_endings.is_empty():
		add_child(preload("res://scenes/ui/story_notebook.gd").new())
	GlobalMenu.get_node("CanvasLayer").hide()	
	SettingsScript.apply_saved_audio_settings()
	MusicManager.play_event({"path": "res://assets/backgrounds/audio/bgm/Dream Portal.mp3", "loop": true})
	continue_button.visible = GameManager.has_save()
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	setting_button.pressed.connect(_on_setting_pressed)
	exit_button.pressed.connect(_on_exit_pressed)


## Bắt đầu trò chơi mới rồi mở màn đầu tiên của chương 1.
func _on_start_pressed() -> void:
	if _starting_new_game or GameManager.is_chapter_transition_active():
		return
	if GameManager.has_save() or not GameManager.story_checkpoints.is_empty() or not GameManager.campaign_state.is_empty():
		if not is_instance_valid(new_game_dialog):
			_new_game_shade = ColorRect.new()
			_new_game_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_new_game_shade.color = Color(0.015, 0.025, 0.055, 0.72)
			_new_game_shade.z_index = 100
			_new_game_shade.hide()
			add_child(_new_game_shade)
			new_game_dialog = preload("res://scenes/ui/new_game_dialog.gd").new()
			new_game_dialog.title = "Bắt đầu lượt chơi mới?"
			new_game_dialog.dialog_text = "Tiến trình hiện tại và các mốc lưu sẽ được đặt lại.\nNhững kết thúc đã sưu tập vẫn được giữ."
			new_game_dialog.ok_button_text = "Chơi mới"
			new_game_dialog.cancel_button_text = "Hủy"
			add_child(new_game_dialog)
			new_game_dialog.confirmed.connect(_start_new_game)
			new_game_dialog.canceled.connect(func() -> void: start_button.grab_focus())
			# Đóng bằng nút, Esc hay đổi scene đều gỡ lớp làm tối menu.
			new_game_dialog.visibility_changed.connect(func() -> void: _new_game_shade.visible = new_game_dialog.visible)
		if not new_game_dialog.visible:
			new_game_dialog.popup_centered(Vector2i(640, 370))
			# Enter đầu tiên không vô tình xóa tiến trình đang có.
			new_game_dialog.get_cancel_button().grab_focus()
		return
	_start_new_game()


func _start_new_game() -> void:
	if _starting_new_game or GameManager.is_chapter_transition_active():
		return
	_starting_new_game = true
	GameManager.start_new_game()
	GameManager.change_scene(GameManager.FIRST_CHAPTER_PATH, true)


## Tải dữ liệu lưu và tiếp tục nếu màn đã lưu hợp lệ; nếu không thì ẩn nút.
func _on_continue_pressed() -> void:
	var save_data: Dictionary = GameManager.load_game()
	var saved_scene: String = save_data.get("current_scene", "")
	if not GameManager.has_save() or bool(save_data.get("completed", false)) or saved_scene.is_empty() or not ResourceLoader.exists(saved_scene):
		continue_button.visible = false
		return
	GameManager.change_scene(saved_scene)


## Tạo và mở màn hình cài đặt từ menu chính.
func _on_setting_pressed() -> void:
	var settings_scene := preload("res://scenes/settings/settings.tscn")
	var settings_instance := settings_scene.instantiate()
	get_tree().root.add_child(settings_instance)


## Thoát ứng dụng.
func _on_exit_pressed() -> void:
	get_tree().quit()
