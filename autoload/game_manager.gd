extends Node

# Ghi nhớ đang ở scene nào — dùng để "Tiếp tục" quay lại đúng chỗ.
# TODO: khi có hệ thống dialogue (Tuần 1-2), thêm biến current_chapter, current_line, flags... vào đây.
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


func save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "current_scene", current_scene_path)
	config.save("user://savegame.save")


func load_game() -> Dictionary:
	var config := ConfigFile.new()
	if config.load("user://savegame.save") != OK:
		return {}
	return {
		"current_scene": config.get_value("progress", "current_scene", "res://scenes/main_menu/main_menu.tscn")
	}


func has_save() -> bool:
	var config := ConfigFile.new()
	if config.load("user://savegame.save") != OK:
		return false
	var saved_scene: String = config.get_value("progress", "current_scene", "")
	return not saved_scene.is_empty() and saved_scene != "res://scenes/main_menu/main_menu.tscn"