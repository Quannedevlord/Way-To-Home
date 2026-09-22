extends Node

const SAVE_PATH := "user://savegame.save"
const MAIN_MENU_PATH := "res://scenes/main_menu/main_menu.tscn"

var current_scene_path: String = "res://scenes/main_menu/main_menu.tscn"


# Bắt sự kiện đóng cửa sổ bằng nút X / Alt+F4 — không bắt được nút "Thoát" trong game
# (nút đó gọi quit() trực tiếp, không đi qua notification này).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if current_scene_path != "res://scenes/main_menu/main_menu.tscn":
			save_game()
		get_tree().quit()


# Dùng hàm này thay cho get_tree().change_scene_to_file() ở mọi nơi trong game,
# để current_scene_path luôn được cập nhật đúng.
func change_scene(path: String) -> void:
	current_scene_path = path
	get_tree().change_scene_to_file(path)


func start_new_game() -> void:
	clear_save()
	current_scene_path = "res://scenes/chapters/chapter_01/chapter1.tscn"


func save_game(progress: Dictionary = {}) -> bool:
	var config := ConfigFile.new()
	config.set_value("progress", "current_scene", current_scene_path)
	for key in progress:
		config.set_value("progress", key, progress[key])
	return config.save(SAVE_PATH) == OK


func load_game() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return {}
	var progress: Dictionary = {}
	for key in config.get_section_keys("progress"):
		progress[key] = config.get_value("progress", key)
	return progress


func has_save() -> bool:
	var save_data := load_game()
	var saved_scene: String = save_data.get("current_scene", "")
	return save_data.has("episode_index") \
		and save_data.has("scene_index") \
		and save_data.has("dialogue_index") \
		and not bool(save_data.get("completed", false)) \
		and not saved_scene.is_empty() \
		and saved_scene != MAIN_MENU_PATH \
		and ResourceLoader.exists(saved_scene)


func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))