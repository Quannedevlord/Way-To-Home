extends Control

@export var chat_feed: VBoxContainer
@export var scroll_container: ScrollContainer
@export var location_label: Label
@export var choice_container: VBoxContainer
@export var continue_hint: Control

const STORY_PATH := "res://data/story.json"
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
		_append_line(current_dialogues[i], false)

	_lines_shown = mini(dialogue_index + 1, current_dialogues.size())
	_try_show_inline_choices()
	_update_continue_hint()
	call_deferred("_scroll_to_bottom")


func _append_line(line: Dictionary, scroll: bool = true) -> void:
	if str(line.get("time", "")) != "":
		location_label.text = str(line["time"])

	var line_type: String = line.get("type", "narration" if not line.has("speaker") else "dialogue")
	var message: String = str(line.get("message", line.get("text", "")))
	var illustration: String = str(line.get("illustration", ""))

	match line_type:
		"narration":
			_last_speaker = ""
			if illustration != "" and ResourceLoader.exists(illustration):
				_append_image(load(illustration), false)
			if message != "":
				_append_narration(message)
		"image":
			_last_speaker = ""
			var image_path: String = str(line.get("path", illustration))
			if image_path != "" and ResourceLoader.exists(image_path):
				_append_image(load(image_path), str(line.get("align", "left")) == "right")
		_:
			var speaker: String = str(line.get("speaker", "???"))
			var avatar_path: String = str(line.get("avatar", avatar_paths.get(speaker, "")))
			_append_dialogue(speaker, message, avatar_path)
			_last_speaker = speaker

	if scroll:
		call_deferred("_scroll_to_bottom")


func _append_dialogue(speaker: String, message: String, avatar_path: String = "") -> void:
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
	chat_feed.add_child(msg)


func _append_narration(message: String) -> void:
	var msg := CHAT_MESSAGE_SCENE.instantiate()
	msg.set_font(CHAT_FONT)
	msg.setup_narration(message)
	chat_feed.add_child(msg)


func _append_location_divider(location: String) -> void:
	if location.is_empty():
		return
	var msg := CHAT_MESSAGE_SCENE.instantiate()
	msg.set_font(CHAT_FONT)
	msg.setup_location_divider(location)
	chat_feed.add_child(msg)


func _append_image(texture: Texture2D, align_right: bool = false) -> void:
	var msg := CHAT_MESSAGE_SCENE.instantiate()
	msg.setup_image(texture, align_right)
	chat_feed.add_child(msg)


func _scroll_to_bottom() -> void:
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
	if dialogue_index >= current_dialogues.size():
		if choice_container.get_parent().visible:
			return
		advance_scene()
		return

	if _lines_shown <= dialogue_index:
		_append_line(current_dialogues[dialogue_index])
		_lines_shown = dialogue_index + 1
		_inline_choice_resolved = false

	_try_show_inline_choices()
	_update_continue_hint()


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
			GameManager.save_game({"completed": true})
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
		_last_speaker = "Kiên"

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
		dialogue_index += 1
		show_current_line()
		save_progress()


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
