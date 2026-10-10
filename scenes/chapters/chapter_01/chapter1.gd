extends Control

@export var chat_feed: VBoxContainer
@export var scroll_container: ScrollContainer
@export var location_label: Label
@export var choice_container: VBoxContainer
@export var continue_hint: Control

const STORY_PATH := "res://data/chap1_story/main_story.json"
const CHAT_MESSAGE_SCENE := preload("res://scenes/chapters/chapter_01/chat_message.tscn")
const CHAT_FONT := preload("res://assets/backgrounds/fonts/Roboto-Light.ttf")
const SettingsScript = preload("res://scenes/settings/settings.gd")

var avatar_paths := {
	"Kiên": "res://assets/avatars/kien.png",
	"Vy": "res://assets/avatars/vy.png",
	"Nhân vật": "res://assets/avatars/vy.png",
	"Thư": "res://assets/avatars/thu.png",
	"Thầy giáo": "",
	"Mẹ Kiên": "",
	"???": "",
}

var protagonist_speakers := ["Kiên"]

var story_data: Dictionary = {}
var episode_index := 0
var scene_index := 0
var dialogue_index := 0
var current_dialogues: Array = []
var story_finished := false
var selected_choice_index := -1
var _current_scene_id := ""
var _lines_shown := 0
var _last_speaker := ""
var _inline_choice_resolved := false


func _ready() -> void:
	SettingsScript.apply_saved_audio_settings()
	if not load_story(STORY_PATH):
		return

	var save_data: Dictionary = GameManager.load_game()
	var has_saved_progress := save_data.has("episode_index") or save_data.has("scene_index") or save_data.has("dialogue_index")

	if not has_saved_progress:
		load_scene_dialogues(true)
		show_current_line()
		return

	restore_progress()
	var saved_dialogue_index := dialogue_index
	load_scene_dialogues(false)
	dialogue_index = saved_dialogue_index
	_rebuild_chat_history()
	save_progress()


func load_story(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("[Chapter1] Không tìm thấy file: %s" % path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	var result = JSON.parse_string(file.get_as_text())
	if result == null:
		push_error("[Chapter1] File JSON bị lỗi cú pháp: %s" % path)
		return false

	if result is Array:
		story_data = {
			"episodes": [{
				"title": "Chương 1",
				"scenes": [{
					"id": "1.1",
					"location": "Chương 1",
					"dialogues": _normalize_script(result),
				}],
			}],
		}
	elif result is Dictionary and result.has("episodes"):
		story_data = result
	else:
		push_error("[Chapter1] Định dạng story không nhận diện được: %s" % path)
		return false

	return true


func _normalize_script(lines: Array) -> Array:
	var out: Array = []
	for item in lines:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var line: Dictionary = item.duplicate(true)
		if line.has("text") and not line.has("message"):
			line["message"] = line["text"]
		if line.has("illustration"):
			line["illustration"] = _remap_asset(str(line["illustration"]))
		if line.has("avatar"):
			line["avatar"] = _remap_asset(str(line["avatar"]))
		if not line.has("type"):
			line["type"] = "narration" if not line.has("speaker") else "dialogue"
		out.append(line)
	return out


func _remap_asset(path: String) -> String:
	if path.is_empty():
		return ""
	var file_name := path.get_file()
	var mapped := {
		"kien.png": "res://assets/avatars/kien.png",
		"thu.png": "res://assets/avatars/thu.png",
		"vy.png": "res://assets/avatars/vy.png",
	}
	if mapped.has(file_name):
		return mapped[file_name]
	if ResourceLoader.exists(path):
		return path
	var alt := "res://assets/avatars/" + file_name
	if ResourceLoader.exists(alt):
		return alt
	return ""


func get_current_scene() -> Dictionary:
	return story_data["episodes"][episode_index]["scenes"][scene_index]


func load_scene_dialogues(show_location: bool = true) -> void:
	var scene := get_current_scene()
	_current_scene_id = scene.get("id", "")
	_last_speaker = ""
	_inline_choice_resolved = false

	choice_container.get_parent().visible = false
	for child in choice_container.get_children():
		child.queue_free()

	location_label.text = scene.get("location", "Chương 1")

	if scene.has("dialogues"):
		current_dialogues = scene["dialogues"]
	elif scene.has("choices"):
		current_dialogues = []
		if selected_choice_index >= 0 and selected_choice_index < scene["choices"].size():
			current_dialogues = scene["choices"][selected_choice_index].get("dialogues", [])
		else:
			show_choices(scene["choices"])
	else:
		current_dialogues = []

	if show_location and _current_scene_id != "":
		_append_location_divider(scene.get("location", ""))


func _rebuild_chat_history() -> void:
	for child in chat_feed.get_children():
		child.queue_free()

	_lines_shown = 0
	_last_speaker = ""
	var scene := get_current_scene()
	_append_location_divider(scene.get("location", ""))

	for i in range(mini(dialogue_index + 1, current_dialogues.size())):
		_append_line(current_dialogues[i], false, false, false)

	_lines_shown = mini(dialogue_index + 1, current_dialogues.size())
	_try_show_inline_choices()
	_update_continue_hint()
	call_deferred("_scroll_to_bottom")


func _append_line(line: Dictionary, scroll: bool = true, play_sound: bool = true, animate: bool = true) -> void:
	if str(line.get("time", "")) != "":
		location_label.text = str(line["time"])
		
	if play_sound and line.has("sfx") and str(line["sfx"]) != "":
		var sfx_path = "res://assets/sound_effect/" + str(line["sfx"]) + ".mp3" # Tự động tìm trong thư mục sound_effect của bạn
		if ResourceLoader.exists(sfx_path):
				var sfx_player := AudioStreamPlayer.new()
				sfx_player.bus = "SFX"
				add_child(sfx_player)
				sfx_player.stream = load(sfx_path)
				sfx_player.play()
				sfx_player.finished.connect(sfx_player.queue_free)

	var line_type: String = line.get("type", "narration" if not line.has("speaker") else "dialogue")
	var message: String = str(line.get("message", line.get("text", "")))
	var illustration: String = str(line.get("illustration", ""))

	match line_type:
		"narration":
			_last_speaker = ""
			if illustration != "" and ResourceLoader.exists(illustration):
				_append_image(load(illustration), false, animate)
			if message != "":
				_append_narration(message, animate)
		"image":
			_last_speaker = ""
			var image_path: String = str(line.get("path", illustration))
			if image_path != "" and ResourceLoader.exists(image_path):
				var align_right := str(line.get("align", "left")) == "right"
				_append_image(load(image_path), align_right, animate)
		_:
			var speaker: String = str(line.get("speaker", "???"))
			var avatar_path: String = str(line.get("avatar", avatar_paths.get(speaker, "")))
			_append_dialogue(speaker, message, avatar_path, animate)
			_last_speaker = speaker

	if scroll:
		call_deferred("_scroll_to_bottom")


func _append_dialogue(speaker: String, message: String, avatar_path: String = "", animate: bool = true) -> void:
	var msg := CHAT_MESSAGE_SCENE.instantiate()
	msg.set_font(CHAT_FONT)
	if avatar_path.is_empty():
		avatar_path = str(avatar_paths.get(speaker, ""))
	var avatar_tex: Texture2D = null
	if avatar_path != "" and ResourceLoader.exists(avatar_path):
		avatar_tex = load(avatar_path)
	var align_right := speaker in protagonist_speakers
	var compact := speaker == _last_speaker and speaker != ""
	msg.setup_dialogue(speaker, message, avatar_tex, align_right, compact)
	if animate:
		msg.prepare_entrance()
	chat_feed.add_child(msg)


func _append_narration(message: String, animate: bool = true) -> void:
	var msg := CHAT_MESSAGE_SCENE.instantiate()
	msg.set_font(CHAT_FONT)
	msg.setup_narration(message)
	if animate:
		msg.prepare_entrance()
	chat_feed.add_child(msg)


func _append_location_divider(location: String) -> void:
	if location.is_empty():
		return
	var msg := CHAT_MESSAGE_SCENE.instantiate()
	msg.set_font(CHAT_FONT)
	msg.setup_location_divider(location)
	chat_feed.add_child(msg)


func _append_image(texture: Texture2D, align_right: bool = false, animate: bool = true) -> void:
	var msg := CHAT_MESSAGE_SCENE.instantiate()
	msg.setup_image(texture, align_right)
	if animate:
		msg.prepare_entrance()
	chat_feed.add_child(msg)
	
	
func play_sfx() -> void:
	# . Tạo một Node phát âm thanh mới
	var sfx_player := AudioStreamPlayer.new()
	add_child(sfx_player)
	
	
	# Phát âm thanh
	sfx_player.play()
	
	# Tự động xóa Node này đi sau khi phát xong để tránh nặng game
	sfx_player.finished.connect(sfx_player.queue_free)


func _scroll_to_bottom() -> void:
	if not is_inside_tree() or not is_instance_valid(scroll_container):
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(scroll_container):
		return
	var v_scroll := scroll_container.get_v_scroll_bar()
	v_scroll.value = v_scroll.max_value


func _update_continue_hint() -> void:
	var waiting_choice: bool = choice_container.get_parent().visible
	continue_hint.visible = not story_finished and not waiting_choice


func _current_line_choices() -> Array:
	if dialogue_index < 0 or dialogue_index >= current_dialogues.size():
		return []
	return current_dialogues[dialogue_index].get("choices", [])


func _try_show_inline_choices() -> void:
	var choices := _current_line_choices()
	if choices.is_empty() or _inline_choice_resolved:
		return
	show_choices(choices)


func show_current_line() -> void:
	# KIỂM TRA ĐỔI FILE KHI ĐÃ ĐỌC HẾT CÂU THOẠI CỦA FILE JSON HIỆN TẠI
	if dialogue_index >= current_dialogues.size():
		if choice_container.get_parent().visible:
			return
			
		if current_dialogues.size() > 0:
			var last_line: Dictionary = current_dialogues[current_dialogues.size() - 1]
			if last_line.has("next_file"):
				_trigger_next_file(str(last_line["next_file"]))
				return
		
		advance_scene()
		return

	if _lines_shown <= dialogue_index:
		_append_line(current_dialogues[dialogue_index])
		_lines_shown = dialogue_index + 1
		_inline_choice_resolved = false

	_try_show_inline_choices()
	_update_continue_hint()


# HÀM BỔ TRỢ ĐỔI FILE JSON AN TOÀN
func _trigger_next_file(next_file_name: String) -> void:
	var clean_file_name = next_file_name.get_file() # Chống lỗi bị lặp/cộng dồn đường dẫn dài
	var full_path = "res://data/chap1_story/" + clean_file_name
	
	if load_story(full_path):
		selected_choice_index = -1
		dialogue_index = 0
		_lines_shown = 0
		_last_speaker = ""
		load_scene_dialogues(false)
		show_current_line()
		save_progress()


# SỬ DỤNG _INPUT ĐỂ NHẬN DIỆN CÚ CLICK CHUỘT TOÀN MÀN HÌNH MƯỢT MÀ
func _input(event: InputEvent) -> void:
	if choice_container.get_parent().visible or story_finished:
		return
		
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if event is InputEventMouseButton and _is_pointer_over_button():
			return
		# Kiểm tra nếu click chuột ở câu thoại cuối cùng của file hiện tại để sẵn sàng chuyển file nhánh
		if dialogue_index >= current_dialogues.size() - 1:
			if current_dialogues.size() > 0:
				var last_line: Dictionary = current_dialogues[current_dialogues.size() - 1]
				if last_line.has("next_file"):
					_trigger_next_file(str(last_line["next_file"]))
					return # Đổi file thành công thì dừng tại đây, không tăng index bừa bãi
		
		dialogue_index += 1
		show_current_line()
		save_progress()


func advance_scene() -> void:
	if story_finished:
		return

	var episode: Dictionary = story_data["episodes"][episode_index]
	scene_index += 1

	if scene_index >= episode["scenes"].size():
		scene_index = 0
		episode_index += 1
		if episode_index >= story_data["episodes"].size():
			story_finished = true
			_append_narration("— Hết chương —")
			continue_hint.visible = false
			GameManager.change_to_next_chapter()
			return

	selected_choice_index = -1
	dialogue_index = 0
	_lines_shown = 0
	load_scene_dialogues(true)
	show_current_line()
	save_progress()


func show_choices(choices: Array) -> void:
	for child in choice_container.get_children():
		child.queue_free()

	for choice in choices:
		var btn := Button.new()
		btn.text = str(choice.get("text", choice.get("description", choice.get("option", "..."))))
		btn.add_theme_font_override("font", CHAT_FONT)
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.29, 0.47, 0.50, 1)
		style.set_corner_radius_all(10)
		style.content_margin_left = 16
		style.content_margin_top = 10
		style.content_margin_right = 16
		style.content_margin_bottom = 10
		btn.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate()
		hover.bg_color = Color(0.35, 0.55, 0.58, 1)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", hover)
		btn.pressed.connect(_on_choice_selected.bind(choice))
		choice_container.add_child(btn)

	choice_container.get_parent().visible = true
	continue_hint.visible = false


func _on_choice_selected(choice: Dictionary) -> void:
	choice_container.get_parent().visible = false
	for child in choice_container.get_children():
		child.queue_free()

	_inline_choice_resolved = true
	var chosen_text := str(choice.get("text", choice.get("description", "")))
	if chosen_text != "":
		_append_dialogue("Kiên", chosen_text, avatar_paths["Kiên"])
		call_deferred("_scroll_to_bottom")
		_last_speaker = "Kiên"

	# TÍNH NĂNG MỚI: Nếu lựa chọn yêu cầu đổi sang file JSON khác
	if choice.has("next_file"):
		var next_file_name = str(choice["next_file"])
		var full_path = "res://data/chap1_story/" + next_file_name
		
		# Nạp file mới và thiết lập lại từ đầu file đó
		if load_story(full_path):
			selected_choice_index = -1
			dialogue_index = 0
			_lines_shown = 0
			_last_speaker = ""
			load_scene_dialogues(false) # Không chèn lại vạch ngăn cách location nếu không cần
			show_current_line()
			save_progress()
		return

	if choice.has("dialogues"):
		selected_choice_index = get_current_scene().get("choices", []).find(choice)
		current_dialogues = choice.get("dialogues", [])
		dialogue_index = 0
		_lines_shown = 0
		_last_speaker = ""
		show_current_line()
		save_progress()
		return

	var next_index := int(choice.get("next", -1))
	if next_index >= 0 and next_index < current_dialogues.size():
		dialogue_index = next_index
		_lines_shown = mini(_lines_shown, dialogue_index)
	else:
		dialogue_index += 1

	show_current_line()
	save_progress()


func _unhandled_input(event: InputEvent) -> void:
	if choice_container.get_parent().visible or story_finished:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if event is InputEventMouseButton and _is_pointer_over_button():
			return
		dialogue_index += 1
		show_current_line()
		save_progress()


func _is_pointer_over_button() -> bool:
	var hovered_control := get_viewport().gui_get_hovered_control()
	while hovered_control != null:
		if hovered_control is BaseButton:
			return true
		hovered_control = hovered_control.get_parent() as Control
	return false


func restore_progress() -> void:
	var save_data: Dictionary = GameManager.load_game()
	if save_data.get("current_scene", "") != scene_file_path:
		return
	episode_index = clampi(int(save_data.get("episode_index", 0)), 0, story_data["episodes"].size() - 1)
	var scenes: Array = story_data["episodes"][episode_index].get("scenes", [])
	scene_index = clampi(int(save_data.get("scene_index", 0)), 0, scenes.size() - 1)
	selected_choice_index = int(save_data.get("selected_choice_index", -1))
	dialogue_index = maxi(int(save_data.get("dialogue_index", 0)), 0)


func save_progress() -> void:
	GameManager.save_game({
		"episode_index": episode_index,
		"scene_index": scene_index,
		"dialogue_index": dialogue_index,
		"selected_choice_index": selected_choice_index,
		"completed": story_finished,
	})
