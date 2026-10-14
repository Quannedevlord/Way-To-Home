extends Node

const SAVE_PATH := "user://savegame.save"
const MAIN_MENU_PATH := "res://scenes/main_menu/main_menu.tscn"
const CHAPTERS_PATH := "res://scenes/chapters"
const CREDITS_PATH := "res://scenes/credits/credits.tscn"
const FIRST_CHAPTER_PATH := "res://scenes/chapters/chapter_01/chapter1.tscn"

var current_scene_path: String = "res://scenes/main_menu/main_menu.tscn"
# Cho phép bài kiểm tra dùng save riêng; game luôn dùng SAVE_PATH mặc định.
var save_path: String = SAVE_PATH


## Nhận thông báo của Godot; khi đóng cửa sổ, lưu tiến trình ngoài menu rồi thoát.
## `what` là mã thông báo; các thông báo khác không được xử lý tại đây.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if current_scene_path != "res://scenes/main_menu/main_menu.tscn":
			save_game()
		get_tree().quit()


## Lưu chapter đang chơi rồi chuyển sang scene tại `path`.
## Trả true khi yêu cầu chuyển thành công; false nếu thiếu scene hoặc Godot báo lỗi.
func change_scene(path: String) -> bool:
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("Không tìm thấy scene: %s" % path)
		return false
	var active_scene := get_tree().current_scene
	if active_scene != null and active_scene.has_method("get_progress") and active_scene.scene_file_path == current_scene_path:
		save_game()
	var result := get_tree().change_scene_to_file(path)
	if result != OK:
		push_error("Không thể chuyển đến scene %s: %s" % [path, error_string(result)])
		return false
	current_scene_path = path
	return true


## Đặt trạng thái tạm dừng của cây scene theo `paused`.
## Node được cấu hình chạy khi pause vẫn có thể hoạt động, ví dụ menu tạm dừng.
func set_paused(paused: bool) -> void:
	get_tree().paused = paused


## Xóa save để chuẩn bị lượt chơi mới; hàm này chưa mở scene chapter đầu tiên.
func start_new_game() -> void:
	clear_save()


## Mở chapter kế tiếp và lưu tiến trình mới từ đầu; nếu hết chapter thì mở credits.
## Chỉ cập nhật save sau khi yêu cầu chuyển scene thành công.
func change_to_next_chapter() -> void:
	var next_chapter_path := get_next_chapter_path(current_scene_path)
	if next_chapter_path.is_empty():
		if change_scene(CREDITS_PATH):
			save_game({"completed": true})
		return
	if change_scene(next_chapter_path):
		save_game({
			"current_story_path": "",
			"episode_index": 0,
			"scene_index": 0,
			"dialogue_index": 0,
			"selected_choice_index": -1,
			"completed": false,
		})


## Nhận thông báo hoàn thành từ `chapter` và điều phối sang chapter/credits kế tiếp.
## Bỏ qua thông báo của scene cũ để tránh chuyển chapter hai lần.
func on_chapter_completed(chapter: Node) -> void:
	if get_tree().current_scene == chapter and chapter.scene_file_path == current_scene_path:
		change_to_next_chapter()


## Tìm chapter có số thứ tự nhỏ nhất nhưng lớn hơn chapter trong `current_path`.
## Trả đường dẫn scene tìm được, hoặc chuỗi rỗng nếu không có chapter hợp lệ.
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


## Lấy số chương từ tên thư mục `chapter_XX` hoặc đường dẫn scene trong thư mục đó.
## Trả -1 nếu `value` không chứa tên chapter hợp lệ.
func _get_chapter_number(value: String) -> int:
	var directory_name := value.get_file()
	if value.contains("/"):
		directory_name = value.get_base_dir().get_file()
	if not directory_name.begins_with("chapter_"):
		return -1

	var number_text := directory_name.trim_prefix("chapter_")
	return int(number_text) if number_text.is_valid_int() else -1


## Tìm file .tscn có tên bắt đầu bằng `chapter` trong `chapter_directory`.
## Nếu có nhiều file, lấy tên đầu tiên theo thứ tự chữ; không tìm thấy thì trả chuỗi rỗng.
func _find_chapter_scene(chapter_directory: String) -> String:
	var scene_paths: Array[String] = []
	for file_name in DirAccess.get_files_at(chapter_directory):
		if file_name.get_extension().to_lower() == "tscn" and file_name.get_basename().to_lower().begins_with("chapter"):
			scene_paths.append(chapter_directory.path_join(file_name))

	scene_paths.sort()
	return scene_paths[0] if not scene_paths.is_empty() else ""


## Ghi save; bỏ trống `progress` để lấy `get_progress()` từ chapter đang hoạt động.
## `source_scene_path` chặn scene cũ ghi đè; giữ các trường save khác nếu vẫn cùng scene.
## Trả true khi lưu thành công hoặc đang ở menu; false nếu sai scene hay ghi file lỗi.
func save_game(progress: Dictionary = {}, source_scene_path: String = "") -> bool:
	# Không cho callback của scene cũ ghi vào save của chapter vừa chuyển tới.
	if not source_scene_path.is_empty() and source_scene_path != current_scene_path:
		return false
	var active_scene := get_tree().current_scene
	if current_scene_path == MAIN_MENU_PATH:
		return true
	if progress.is_empty() and active_scene != null and active_scene.scene_file_path == current_scene_path and active_scene.has_method("get_progress"):
		progress = active_scene.call("get_progress")
	var config := ConfigFile.new()
	config.load(save_path)
	if config.get_value("progress", "current_scene", "") != current_scene_path and config.has_section("progress"):
		config.erase_section("progress")
	config.set_value("progress", "current_scene", current_scene_path)
	for key in progress:
		config.set_value("progress", key, progress[key])
	return config.save(save_path) == OK


## Đọc toàn bộ các trường trong phần progress của save thành Dictionary.
## Trả Dictionary rỗng nếu không đọc được file hoặc file chưa có phần progress.
func load_game() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return {}
	if not config.has_section("progress"):
		return {}
	var progress: Dictionary = {}
	for key in config.get_section_keys("progress"):
		progress[key] = config.get_value("progress", key)
	return progress


## Trả true khi save có vị trí thoại, chưa hoàn thành và scene vẫn tồn tại để Continue.
## Hàm chỉ kiểm tra khả năng tiếp tục, chưa nạp truyện hay khôi phục chapter.
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


## Xóa file tại `save_path` nếu nó tồn tại; dùng để bỏ tiến trình trước lượt chơi mới.
func clear_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
