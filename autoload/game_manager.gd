extends Node

const SAVE_PATH := "user://savegame.save"
const MAIN_MENU_PATH := "res://scenes/main_menu/main_menu.tscn"
const CHAPTERS_PATH := "res://scenes/chapters"
const CREDITS_PATH := "res://scenes/credits/credits.tscn"
const FIRST_CHAPTER_PATH := "res://scenes/chapters/chapter_01/chapter1.tscn"

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
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("Không tìm thấy scene: %s" % path)
		return

	var result := get_tree().change_scene_to_file(path)
	if result != OK:
		push_error("Không thể chuyển đến scene %s: %s" % [path, error_string(result)])
		return

	current_scene_path = path


func set_paused(paused: bool) -> void:
	get_tree().paused = paused


func start_new_game() -> void:
	clear_save()


func change_to_next_chapter() -> void:
	var next_chapter_path := get_next_chapter_path(current_scene_path)
	if next_chapter_path.is_empty():
		change_scene(CREDITS_PATH)
		save_game({"completed": true})
		return

	change_scene(next_chapter_path)
	save_game({
		"episode_index": 0,
		"scene_index": 0,
		"dialogue_index": 0,
		"selected_choice_index": -1,
		"completed": false,
	})


func get_next_chapter_path(current_path: String = current_scene_path) -> String:
	var current_chapter_number := _get_chapter_number(current_path)
	if current_chapter_number < 0:
		return ""

	var next_chapter_number := -1
	var next_chapter_directory := ""
	for directory_name in DirAccess.get_directories_at(CHAPTERS_PATH):
		var chapter_number := _get_chapter_number(directory_name)
		if chapter_number <= current_chapter_number:
			continue
		if next_chapter_number < 0 or chapter_number < next_chapter_number:
			next_chapter_number = chapter_number
			next_chapter_directory = directory_name

	if next_chapter_directory.is_empty():
		return ""

	return _find_chapter_scene(CHAPTERS_PATH.path_join(next_chapter_directory))


func _get_chapter_number(value: String) -> int:
	var directory_name := value.get_file()
	if value.contains("/"):
		directory_name = value.get_base_dir().get_file()
	if not directory_name.begins_with("chapter_"):
		return -1

	var number_text := directory_name.trim_prefix("chapter_")
	return int(number_text) if number_text.is_valid_int() else -1


func _find_chapter_scene(chapter_directory: String) -> String:
	var scene_paths: Array[String] = []
	for file_name in DirAccess.get_files_at(chapter_directory):
		if file_name.get_extension().to_lower() == "tscn" and file_name.get_basename().to_lower().begins_with("chapter"):
			scene_paths.append(chapter_directory.path_join(file_name))

	scene_paths.sort()
	return scene_paths[0] if not scene_paths.is_empty() else ""


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