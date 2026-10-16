class_name ChapterBase
extends Control

@export var chat_feed: VBoxContainer
@export var scroll_container: ScrollContainer
@export var location_label: Label
@export var choice_container: VBoxContainer
@export var continue_hint: Control

@onready var background: TextureRect = $Background
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer

signal chapter_completed
signal minigame_completed(event_id: String, result: Dictionary)

@export_group("Chapter")
@export var chapter_id := ""
@export var chapter_name := ""
@export_file("*.json") var story_path := ""
@export var avatar_paths: Dictionary = {}
@export var protagonist_speakers: Array[String] = []
@export var choice_speaker := ""
@export var default_background: Texture2D
@export var default_music: AudioStream

@onready var minigame_container: Control = $MinigameContainer

const CHAT_MESSAGE_SCENE := preload("res://scenes/ui/chat/chat_message.tscn")
const CHAT_FONT := preload("res://assets/backgrounds/fonts/Roboto-Light.ttf")
const SettingsScript = preload("res://scenes/settings/settings.gd")

var current_story_path := ""
var minigame_state: Dictionary = {}
var _active_minigame: Node
var _active_minigame_id := ""
var _pending_minigame: Dictionary = {}
var _event_queue: Array = []
var _events_running := false
var _rebuilding_history := false
var _chat_history: Array = []
var _dialogue_override: Array = []
var _has_dialogue_override := false
var _progress_initialized := false
var _continue_hint_dismissed := false
var _exiting := false

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
var _background_tween: Tween
var _background_transition_layer: TextureRect
var _fade_tween: Tween
var _fade_overlay: ColorRect
var _fade_target_alpha := 0.0


## Godot gọi khi chapter vào cây scene: chuẩn bị UI, âm thanh và lớp phủ fade.
## Nhạc mặc định lấy từ Default Music trên node root trong Inspector.
## Bắt đầu truyện mới hoặc nạp đúng file/index đã lưu; chapter override phải gọi super._ready().
func _ready() -> void:
	SettingsScript.apply_saved_audio_settings()
	_create_fade_overlay()
	call_deferred("_register_current_chapter")
	chapter_completed.connect(GameManager.on_chapter_completed.bind(self))
	location_label.text = chapter_name
	choice_container.get_parent().hide()
	minigame_container.hide()
	if default_background != null:
		background.texture = default_background
	if default_music != null:
		bgm_player.stream = default_music
		bgm_player.play()
	continue_hint.hide()
	if story_path.is_empty():
		return

	var save_data: Dictionary = GameManager.load_game()
	# Save cũ đã có tiến trình được xem là người chơi đã biết cách tiếp tục.
	_continue_hint_dismissed = bool(save_data.get("continue_hint_dismissed", not save_data.is_empty()))
	var has_saved_progress: bool = save_data.get("current_scene", "") == scene_file_path and save_data.has("dialogue_index") and not bool(save_data.get("completed", false))
	var path := str(save_data.get("current_story_path", story_path)) if has_saved_progress else story_path
	if path.is_empty():
		path = story_path
	if not load_story(path):
		# File đã bị gỡ: khởi động lại chương thay vì dùng index của file khác.
		if path == story_path or not load_story(story_path):
			return
		has_saved_progress = false
	_progress_initialized = true
	if not has_saved_progress:
		load_scene_dialogues(true)
		show_current_line()
		save_progress()
		return

	restore_progress()
	var saved_dialogue_index := dialogue_index
	var inline_choice_resolved := bool(save_data.get("inline_choice_resolved", false))
	load_scene_dialogues(false)
	dialogue_index = clampi(saved_dialogue_index, 0, maxi(current_dialogues.size() - 1, 0))
	_inline_choice_resolved = inline_choice_resolved
	_rebuild_chat_history()
	restore_chapter_state(save_data.get("chapter_state", {}))
	# Chỉ tiếp tục minigame chưa hoàn thành, sau khi dựng xong lịch sử.
	if not _pending_minigame.is_empty():
		_queue_json_events([_pending_minigame["event"]])
	elif dialogue_index < current_dialogues.size():
		var events: Variant = current_dialogues[dialogue_index].get("events", current_dialogues[dialogue_index].get("event", []))
		if events is Dictionary:
			events = [events]
		if events is Array:
			for event in events:
				if event is Dictionary and str(event.get("type", "")) == "minigame":
					_queue_json_events([event])
	if save_data.has("fade_alpha"):
		_fade_overlay.color.a = clampf(float(save_data["fade_alpha"]), 0.0, 1.0)
		_fade_target_alpha = _fade_overlay.color.a
	save_progress()


## Báo cho GameManager biết chapter nào đang mở, kể cả khi chạy trực tiếp bằng F6.
## Chạy sau khởi tạo để current_scene đã trỏ tới chapter, rồi lưu tiến trình nếu có.
func _register_current_chapter() -> void:
	# Hỗ trợ chạy inherited scene trực tiếp từ editor (F6).
	if not is_inside_tree() or _exiting:
		return
	if get_tree().current_scene == self and not story_finished:
		GameManager.current_scene_path = scene_file_path
		save_progress()


## Godot gọi khi rời chapter: đánh dấu đang thoát và giải phóng đoạn code chờ minigame.
## Kết quả hủy chỉ dùng để kết thúc chờ, không chọn nhánh truyện hay đánh dấu đã thắng.
func _exit_tree() -> void:
	_exiting = true
	if is_instance_valid(_active_minigame):
		minigame_completed.emit(_active_minigame_id, {"cancelled": true})


## Tạo lớp phủ đen kín màn hình; độ trong suốt ban đầu là 0 nên chưa che truyện.
## fade_screen() sẽ đổi độ trong suốt của lớp này để làm màn hình tối hoặc sáng dần.
func _create_fade_overlay() -> void:
	_fade_overlay = ColorRect.new()
	_fade_overlay.name = "FadeOverlay"
	_fade_overlay.color = Color(0, 0, 0, 0)
	_fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.z_index = 100
	add_child(_fade_overlay)


## Đọc file JSON tại path, chấp nhận mảng thoại cũ hoặc cấu trúc episodes/scenes.
## Trả true khi nạp được và cập nhật current_story_path; lỗi thì trả false, giữ dữ liệu cũ.
## Hàm này chỉ nạp dữ liệu; _trigger_next_file() mới đặt lại các index khi chuyển file.
func load_story(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("[ChapterBase] Không tìm thấy file: %s" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[ChapterBase] Không thể đọc file: %s" % path)
		return false
	var result: Variant = JSON.parse_string(file.get_as_text())
	var normalized: Dictionary = {}
	if result is Array:
		normalized = {"episodes": [{"title": chapter_name, "scenes": [{
			"id": chapter_id + ".1", "location": chapter_name,
			"dialogues": _normalize_script(result),
		}]}]}
	elif result is Dictionary and result.get("episodes") is Array:
		normalized = result.duplicate(true)
	else:
		push_error("[ChapterBase] JSON không hợp lệ: %s" % path)
		return false
	if normalized["episodes"].is_empty():
		push_error("[ChapterBase] Story không có episode: %s" % path)
		return false
	for episode in normalized["episodes"]:
		if not episode is Dictionary or not episode.get("scenes") is Array or episode["scenes"].is_empty():
			push_error("[ChapterBase] Episode không có scenes hợp lệ: %s" % path)
			return false
		for scene in episode["scenes"]:
			if not scene is Dictionary:
				return false
			if scene.has("dialogues"):
				if not scene["dialogues"] is Array:
					return false
				scene["dialogues"] = _normalize_script(scene["dialogues"])
			if scene.has("choices"):
				if not scene["choices"] is Array:
					return false
				scene["choices"] = _normalize_choices(scene["choices"])
	story_data = normalized
	current_story_path = path.simplify_path()
	return true


## Sao chép các lựa chọn hợp lệ và chuẩn hóa phần dialogues bên trong mỗi lựa chọn.
## Trả mảng mới để code hiển thị dùng cùng định dạng mà không sửa dữ liệu đầu vào.
func _normalize_choices(choices: Array) -> Array:
	var out: Array = []
	for item in choices:
		if not item is Dictionary:
			continue
		var choice: Dictionary = item.duplicate(true)
		if choice.get("dialogues") is Array:
			choice["dialogues"] = _normalize_script(choice["dialogues"])
		out.append(choice)
	return out


## Đưa các dòng JSON về một định dạng: text thành message, bổ sung type nếu thiếu.
## Chuẩn hóa avatar/illustration và lựa chọn có thoại riêng; trả về mảng đã sao chép.
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
		if line.get("choices") is Array:
			line["choices"] = _normalize_choices(line["choices"])
		if not line.has("type"):
			line["type"] = "narration" if not line.has("speaker") else "dialogue"
		out.append(line)
	return out


## Tìm đường dẫn ảnh hợp lệ từ tên asset cũ, ưu tiên avatar cấu hình trong Inspector.
## Nếu không tìm được thì trả chuỗi rỗng; UI có thể dùng ảnh đại diện mặc định.
func _remap_asset(path: String) -> String:
	if path.is_empty():
		return ""
	var file_name := path.get_file()
	for avatar_path in avatar_paths.values():
		if str(avatar_path).get_file() == file_name and ResourceLoader.exists(str(avatar_path)):
			return str(avatar_path)
	if ResourceLoader.exists(path):
		return path
	var alt := "res://assets/avatars/" + file_name
	if ResourceLoader.exists(alt):
		return alt
	return ""


## Trả dữ liệu cảnh truyện theo episode_index và scene_index trong JSON.
## Đây là Dictionary của truyện, không phải node hay scene .tscn của Godot.
func get_current_scene() -> Dictionary:
	return story_data["episodes"][episode_index]["scenes"][scene_index]


## Chuẩn bị danh sách thoại, lựa chọn và tên địa điểm của cảnh truyện hiện tại.
## show_location = true thêm dòng phân cách địa điểm vào chat; false bỏ bước này.
## Ưu tiên thoại của nhánh đã chọn/đã lưu; nếu chưa chọn thì hiện các nút lựa chọn.
func load_scene_dialogues(show_location: bool = true) -> void:
	var scene := get_current_scene()
	_current_scene_id = scene.get("id", "")
	_last_speaker = ""
	_inline_choice_resolved = false

	choice_container.get_parent().visible = false
	for child in choice_container.get_children():
		child.queue_free()

	location_label.text = scene.get("location", chapter_name)

	if _has_dialogue_override:
		current_dialogues = _dialogue_override
	elif scene.has("dialogues"):
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


## Dựng lại chat khi Continue, gồm ảnh, địa điểm và lời lựa chọn đã hiển thị.
## Chỉ khôi phục nền/nhạc; không phát lại SFX, animation, minigame hay sự kiện riêng.
## Save cũ chưa có lịch sử được dựng lại từ các dòng đã đọc trong file hiện tại.
func _rebuild_chat_history() -> void:
	for child in chat_feed.get_children():
		child.queue_free()
	_lines_shown = 0
	_last_speaker = ""
	if _chat_history.is_empty():
		# Save cũ chỉ có index: dựng các dòng của file được xác định ở _ready.
		_append_location_divider(get_current_scene().get("location", ""))
		for i in range(mini(dialogue_index + 1, current_dialogues.size())):
			_append_line(current_dialogues[i], false, false, false)
	else:
		_rebuilding_history = true
		for entry in _chat_history:
			if entry.has("location_divider"):
				_append_location_divider(str(entry["location_divider"]))
			else:
				_append_line(entry, false, false, false)
		_rebuilding_history = false
	_lines_shown = mini(dialogue_index + 1, current_dialogues.size())
	_try_show_inline_choices()
	_update_continue_hint()
	call_deferred("_scroll_to_bottom")


## Đọc một dòng JSON rồi tạo thoại, lời dẫn hoặc ảnh và xử lý sự kiện kèm theo.
## scroll bật cuộn chat; play_sound bật SFX; animate bật hiệu ứng và sự kiện gameplay.
## Khi dựng lịch sử, truyền false cho cả ba để khôi phục nội dung đã đọc.
func _append_line(line: Dictionary, scroll: bool = true, play_sound: bool = true, animate: bool = true) -> void:
	if not _rebuilding_history:
		_chat_history.append(line.duplicate(true))
	_process_json_events(line, animate)

	if str(line.get("time", "")) != "":
		location_label.text = str(line["time"])
		
	if play_sound and line.has("sfx") and str(line["sfx"]) != "":
		var sfx_path = "res://assets/sound_effect/" + str(line["sfx"]) + ".mp3" # Tự động tìm trong thư mục sound_effect của bạn
		if ResourceLoader.exists(sfx_path):
			play_sfx(load(sfx_path) as AudioStream)

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


## Gom event hoặc events của dòng thoại, kèm đổi nền từ ảnh nếu use_as_background bật.
## animate = true đưa sự kiện vào hàng đợi; false chỉ khôi phục nền và nhạc ngay lập tức.
## Đặt use_as_background = false trong JSON nếu ảnh chỉ dùng để minh họa trong chat.
func _process_json_events(line: Dictionary, animate: bool) -> void:
	var events_to_run: Array = []
	var line_type := str(line.get("type", "narration" if not line.has("speaker") else "dialogue"))
	var background_path := str(line.get("path", line.get("illustration", ""))) if line_type == "image" else str(line.get("illustration", ""))
	if not background_path.is_empty() and bool(line.get("use_as_background", true)):
		events_to_run.append({"type": "change_background", "path": background_path})

	var events: Variant = line.get("events", line.get("event", []))
	if events is Dictionary:
		events_to_run.append(events)
	elif events is Array:
		events_to_run.append_array(events.duplicate(true))
	elif events != null and events != "":
		push_error("[ChapterBase] Trường event/events phải là object hoặc array.")
	if not events_to_run.is_empty():
		if not animate:
			for event in events_to_run:
				# Lịch sử chỉ khôi phục hình/nhạc, không chạy gameplay hay fade.
				if event is Dictionary and str(event.get("type", "")) in ["change_background", "background", "change_music"]:
					_process_json_event(event, false)
		else:
			_queue_json_events(events_to_run)


## Lấy từng sự kiện trong hàng đợi và chờ hiệu ứng/minigame hoàn tất trước sự kiện sau.
## Khi hết hàng đợi, mở lại lựa chọn/gợi ý tiếp tục và lưu trạng thái mới.
func _run_json_events() -> void:
	while not _event_queue.is_empty() and is_inside_tree() and not story_finished and not _exiting:
		await _process_json_event(_event_queue.pop_front(), true)
	_events_running = false
	if is_inside_tree() and not story_finished and not _exiting:
		_try_show_inline_choices()
		_update_continue_hint()
		save_progress()


## Thêm sự kiện vào hàng đợi, ghi file nguồn và tạo ID cho minigame nếu chưa khai báo.
## Khóa tiếp tục thoại trước khi chạy để người chơi không nhảy qua dòng đang có hiệu ứng.
func _queue_json_events(events: Array) -> void:
	for event in events:
		if event is Dictionary:
			var queued: Dictionary = event.duplicate(true)
			queued["_story_path"] = current_story_path
			if str(queued.get("type", "")) == "minigame":
				queued["id"] = str(queued.get("id", "%s:%s:%s:%s:%s" % [current_story_path, episode_index, scene_index, dialogue_index, str(event).hash()]))
			_event_queue.append(queued)
		else:
			_event_queue.append(event)
	if _event_queue.is_empty() or _events_running:
		return
	_events_running = true
	_update_continue_hint()
	call_deferred("_run_json_events")


## Thực hiện một sự kiện theo type: đổi nền, đổi nhạc, fade hoặc mở minigame.
## duration trong JSON tính bằng giây; minigame chọn nhánh qua result.outcome và branches.
## Sự kiện chưa nhận diện được chuyển cho _handle_chapter_event() của chapter con.
func _process_json_event(event: Variant, animate: bool) -> void:
	if not event is Dictionary:
		push_error("[ChapterBase] Mỗi sự kiện JSON phải là object.")
		return

	var event_type := str(event.get("type", ""))
	var duration := maxf(float(event.get("duration", 0.35)), 0.0) if animate else 0.0
	match event_type:
		"change_background", "background":
			var path := str(event.get("path", event.get("background", "")))
			if path.is_empty():
				push_error("[ChapterBase] Sự kiện đổi nền cần có trường path.")
				return
			var use_fade := bool(event.get("fade", true))
			var background_changed := change_background(path, duration, use_fade)
			if background_changed and animate and use_fade and duration > 0.0:
				if is_instance_valid(_background_tween) and _background_tween.is_running():
					await _background_tween.finished
		"change_music":
			var path := str(event.get("path", ""))
			if path.is_empty() or not ResourceLoader.exists(path):
				push_error("[ChapterBase] Không tìm thấy file nhạc: %s" % path)
				return
			var music := ResourceLoader.load(path) as AudioStream
			if music == null:
				push_error("[ChapterBase] File không phải AudioStream: %s" % path)
				return
			if bgm_player.stream != music:
				bgm_player.stream = music
				bgm_player.play()
		"fade", "fade_in", "fade_out":
			if not animate:
				return
			var direction := str(event.get("direction", event_type.trim_prefix("fade_")))
			if event_type == "fade":
				direction = str(event.get("direction", "out"))
			fade_screen(direction, duration)
			if is_instance_valid(_fade_tween) and _fade_tween.is_running():
				await _fade_tween.finished
		"minigame":
			if not animate:
				return
			var event_id := str(event.get("id", ""))
			if minigame_state.has(event_id) and bool(minigame_state[event_id].get("completed", false)):
				return
			var path := str(event.get("scene", ""))
			var packed := load(path) as PackedScene if ResourceLoader.exists(path) else null
			if not start_minigame(packed, event_id, event):
				return
			var finished: Array = await minigame_completed
			if _exiting or not is_inside_tree():
				return
			var result: Dictionary = finished[1]
			var branch: Variant = event.get("branches", {}).get(str(result.get("outcome", "")), {})
			if branch is String:
				branch = {"next_file": branch}
			if branch is Dictionary:
				if branch.has("next_file"):
					_trigger_next_file(str(branch["next_file"]))
				elif branch.has("next"):
					dialogue_index = clampi(int(branch["next"]), 0, current_dialogues.size())
					_lines_shown = mini(_lines_shown, dialogue_index)
					show_current_line()
			save_progress()
		_:
			if not animate:
				return
			# Gọi động vì chapter con có thể override hook bằng coroutine.
			var handled: bool = await call("_handle_chapter_event", event)
			if not handled:
				push_error("[ChapterBase] Loại sự kiện JSON không được hỗ trợ: %s" % event_type)


## Đặt ảnh nền mới rồi làm lớp nền cũ mờ dần để ảnh mới hiện ra phía dưới.
## duration là số giây chuyển nền; use_fade = false hoặc duration <= 0 đổi ngay lập tức.
## Trả true khi ảnh hợp lệ. Chỉnh tween bên dưới để đổi kiểu hiệu ứng chung của chapter.
func change_background(path: String, duration: float = 0.35, use_fade: bool = true) -> bool:
	if not ResourceLoader.exists(path):
		push_error("[ChapterBase] Không tìm thấy ảnh nền: %s" % path)
		return false
	var texture := ResourceLoader.load(path) as Texture2D
	if texture == null:
		push_error("[ChapterBase] Asset không phải Texture2D: %s" % path)
		return false

	if is_instance_valid(_background_tween) and _background_tween.is_running():
		_background_tween.kill()
	_clear_background_transition_layer()
	if not use_fade or duration <= 0.0:
		background.texture = texture
		background.modulate.a = 1.0
		return true

	var previous_texture := background.texture
	background.texture = texture
	background.modulate.a = 1.0
	if previous_texture == null:
		return true

	_background_transition_layer = TextureRect.new()
	_background_transition_layer.name = "BackgroundTransition"
	_background_transition_layer.texture = previous_texture
	_background_transition_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background_transition_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background_transition_layer.stretch_mode = background.stretch_mode
	_background_transition_layer.expand_mode = background.expand_mode
	_background_transition_layer.self_modulate = background.self_modulate
	add_child(_background_transition_layer)
	move_child(_background_transition_layer, background.get_index() + 1)

	_background_tween = create_tween()
	_background_tween.tween_property(_background_transition_layer, "modulate:a", 0.0, maxf(duration, 0.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_background_tween.tween_callback(_clear_background_transition_layer)
	return true


## Dọn lớp ảnh nền cũ được tạo riêng cho hiệu ứng chuyển nền.
## Cũng được gọi trước lần đổi nền tiếp theo để không để lại lớp phủ thừa.
func _clear_background_transition_layer() -> void:
	if is_instance_valid(_background_transition_layer):
		_background_transition_layer.queue_free()
	_background_transition_layer = null


## Fade toàn màn hình: direction = "out" làm đen dần, "in" làm sáng dần.
## duration tính bằng giây. Chỉnh tween ở đây nếu muốn đổi hiệu ứng fade chung.
## Hàm tạo tween rồi trả về; bộ xử lý sự kiện sẽ chờ tween kết thúc khi cần.
func fade_screen(direction: String, duration: float = 0.35) -> void:
	if direction != "in" and direction != "out":
		push_error("[ChapterBase] Hướng fade không hợp lệ: %s" % direction)
		return
	if is_instance_valid(_fade_tween) and _fade_tween.is_running():
		_fade_tween.kill()

	var start_alpha := 1.0 if direction == "in" else 0.0
	var end_alpha := 0.0 if direction == "in" else 1.0
	_fade_target_alpha = end_alpha
	_fade_overlay.color.a = start_alpha
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_overlay, "color:a", end_alpha, maxf(duration, 0.0))


## Tạo một bong bóng thoại từ speaker, message và avatar_path rồi thêm vào chat.
## Nhân vật trong protagonist_speakers căn phải; nói liên tiếp thì ẩn tên/avatar lặp lại.
## animate bật hiệu ứng xuất hiện; hình dáng và animation của bubble nằm trong chat_message.gd.
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


## Thêm lời dẫn ở giữa khung chat; message là nội dung hiển thị.
## animate = false hiển thị ngay, dùng khi dựng lại lịch sử từ save.
func _append_narration(message: String, animate: bool = true) -> void:
	var msg := CHAT_MESSAGE_SCENE.instantiate()
	msg.set_font(CHAT_FONT)
	msg.setup_narration(message)
	if animate:
		msg.prepare_entrance()
	chat_feed.add_child(msg)


## Thêm dòng phân cách dạng "— địa điểm —" và ghi vào lịch sử chat nếu đang chơi.
## Bỏ qua địa điểm rỗng và đặt lại người nói trước để nhóm thoại mới hiển thị đầy đủ.
func _append_location_divider(location: String) -> void:
	if location.is_empty():
		return
	if not _rebuilding_history:
		_chat_history.append({"location_divider": location})
	_last_speaker = ""
	var msg := CHAT_MESSAGE_SCENE.instantiate()
	msg.set_font(CHAT_FONT)
	msg.setup_location_divider(location)
	chat_feed.add_child(msg)


## Thêm ảnh minh họa vào chat; align_right chọn căn phải, animate bật hiệu ứng xuất hiện.
## Hàm này chỉ tạo ảnh trong chat; việc đổi nền do _process_json_events() quyết định.
func _append_image(texture: Texture2D, align_right: bool = false, animate: bool = true) -> void:
	var msg := CHAT_MESSAGE_SCENE.instantiate()
	msg.setup_image(texture, align_right)
	if animate:
		msg.prepare_entrance()
	chat_feed.add_child(msg)
	
	
## Phát AudioStream trên bus SFX bằng một player riêng để có thể phát nhiều tiếng.
## Player tự xóa khi âm thanh kết thúc; stream rỗng thì bỏ qua.
func play_sfx(stream: AudioStream = null) -> void:
	if stream == null:
		return
	var sfx_player := AudioStreamPlayer.new()
	sfx_player.bus = "SFX"
	sfx_player.stream = stream
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)


## Chờ hai khung hình để Godot cập nhật kích thước bubble rồi cuộn chat xuống cuối.
## Kiểm tra chapter còn trong tree trước khi cuộn để tránh truy cập UI đã bị đóng.
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


## Chỉ hướng dẫn trước lần tiếp tục đầu tiên của lượt chơi; trạng thái được lưu.
## Ẩn gợi ý lúc chờ lựa chọn, chạy sự kiện/minigame hoặc đã hoàn thành chapter.
func _update_continue_hint() -> void:
	var waiting_choice: bool = choice_container.get_parent().visible
	continue_hint.visible = _progress_initialized and not _continue_hint_dismissed and not story_finished and not waiting_choice and not _events_running and not is_instance_valid(_active_minigame)


## Trả mảng choices gắn ngay trên dòng thoại hiện tại, còn gọi là lựa chọn nội tuyến.
## Trả mảng rỗng nếu dòng không có lựa chọn hoặc dialogue_index nằm ngoài danh sách.
func _current_line_choices() -> Array:
	if dialogue_index < 0 or dialogue_index >= current_dialogues.size():
		return []
	return current_dialogues[dialogue_index].get("choices", [])


## Hiện choices của dòng thoại hiện tại nếu người chơi chưa giải quyết lựa chọn đó.
## Chờ sự kiện/minigame kết thúc rồi mới cho chọn để không điều hướng nhánh quá sớm.
func _try_show_inline_choices() -> void:
	var choices := _current_line_choices()
	if choices.is_empty() or _inline_choice_resolved or _events_running or is_instance_valid(_active_minigame):
		return
	show_choices(choices)


## Hiển thị dòng tại dialogue_index, tránh thêm trùng một dòng đã hiện trong cảnh này.
## Nếu hết thoại: chờ lựa chọn, chuyển next_file nếu có, hoặc sang cảnh truyện kế tiếp.
## Sau khi thêm dòng, cập nhật lựa chọn nội tuyến và gợi ý tiếp tục.
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


## Nạp file next_file tương đối với file truyện đang đọc, rồi hiện dòng đầu của file mới.
## Chỉ khi nạp thành công mới reset các index/lựa chọn; giữ lịch sử chat và lưu file mới.
func _trigger_next_file(next_file_name: String) -> void:
	var full_path := _resolve_story_path(next_file_name)
	if load_story(full_path):
		episode_index = 0
		scene_index = 0
		selected_choice_index = -1
		_has_dialogue_override = false
		_dialogue_override = []
		dialogue_index = 0
		_lines_shown = 0
		_last_speaker = ""
		load_scene_dialogues(false)
		show_current_line()
		save_progress()


## Trả đường dẫn đầy đủ của file truyện; đường dẫn res:// được giữ nguyên và rút gọn.
## Tên file tương đối, thư mục con hoặc ../ được tính từ thư mục current_story_path.
func _resolve_story_path(path: String) -> String:
	if path.begins_with("res://"):
		return path.simplify_path()
	return current_story_path.get_base_dir().path_join(path).simplify_path()


## Godot chuyển input vào đây: ui_accept hoặc click trái sẽ đọc tiếp và lưu tiến trình.
## Bỏ qua khi chờ lựa chọn, chạy sự kiện/minigame, truyện chưa sẵn sàng hoặc đã kết thúc.
## Click lên Button không tiến thoại; dòng cuối có next_file sẽ chuyển file trước.
func _input(event: InputEvent) -> void:
	if not _progress_initialized or choice_container.get_parent().visible or story_finished or _events_running or is_instance_valid(_active_minigame):
		return
		
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if event is InputEventMouseButton and _is_pointer_over_button():
			return
		_continue_hint_dismissed = true
		continue_hint.hide()
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


## Tăng scene_index, sang episode tiếp theo nếu hết cảnh, rồi hiện dòng đầu cảnh mới.
## Khi hết toàn bộ truyện, gọi complete_chapter() để GameManager chọn chapter/credits.
func advance_scene() -> void:
	if story_finished:
		return

	var episode: Dictionary = story_data["episodes"][episode_index]
	scene_index += 1

	if scene_index >= episode["scenes"].size():
		scene_index = 0
		episode_index += 1
		if episode_index >= story_data["episodes"].size():
			_append_narration("— Hết chương —")
			complete_chapter()
			return

	selected_choice_index = -1
	_has_dialogue_override = false
	_dialogue_override = []
	dialogue_index = 0
	_lines_shown = 0
	load_scene_dialogues(true)
	show_current_line()
	save_progress()


## Tạo một Button cho mỗi lựa chọn JSON và nối pressed tới _on_choice_selected().
## Chỉnh màu, font, bo góc và khoảng đệm của nút tại đây; hiện overlay và ẩn Continue.
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


## Nhận lựa chọn vừa bấm, đóng overlay và hiện lời lựa chọn bằng choice_speaker.
## Ưu tiên next_file, sau đó dialogues riêng, rồi next (index thoại); lưu tiến trình mới.
## Hàm không nhận lựa chọn trong lúc đang chạy sự kiện/minigame hoặc đã kết thúc truyện.
func _on_choice_selected(choice: Dictionary) -> void:
	if story_finished or _events_running or is_instance_valid(_active_minigame):
		return
	choice_container.get_parent().visible = false
	for child in choice_container.get_children():
		child.queue_free()

	_inline_choice_resolved = true
	var chosen_text := str(choice.get("text", choice.get("description", "")))
	if chosen_text != "":
		_append_line({"type": "dialogue", "speaker": choice_speaker, "message": chosen_text})
		call_deferred("_scroll_to_bottom")
		_last_speaker = choice_speaker

	# TÍNH NĂNG MỚI: Nếu lựa chọn yêu cầu đổi sang file JSON khác
	if choice.has("next_file"):
		_trigger_next_file(str(choice["next_file"]))
		return

	if choice.has("dialogues"):
		selected_choice_index = get_current_scene().get("choices", []).find(choice)
		current_dialogues = choice.get("dialogues", [])
		_has_dialogue_override = true
		_dialogue_override = current_dialogues
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


## Trả true nếu con trỏ đang ở trên Button hoặc Control con của một Button.
## Dùng để click chọn/menu không đồng thời làm hội thoại nhảy sang dòng tiếp theo.
func _is_pointer_over_button() -> bool:
	var hovered_control := get_viewport().gui_get_hovered_control()
	while hovered_control != null:
		if hovered_control is BaseButton:
			return true
		hovered_control = hovered_control.get_parent() as Control
	return false


## Đọc lại index, lịch sử, nhánh thoại và trạng thái minigame của đúng chapter đang mở.
## Cần nạp đúng file bằng load_story() trước để giới hạn index theo dữ liệu của file đó.
## Hàm khôi phục dữ liệu; _rebuild_chat_history() mới dựng phần hiển thị lên UI.
func restore_progress() -> void:
	var save_data: Dictionary = GameManager.load_game()
	if save_data.get("current_scene", "") != scene_file_path:
		return
	episode_index = clampi(int(save_data.get("episode_index", 0)), 0, story_data["episodes"].size() - 1)
	var scenes: Array = story_data["episodes"][episode_index].get("scenes", [])
	scene_index = clampi(int(save_data.get("scene_index", 0)), 0, scenes.size() - 1)
	selected_choice_index = int(save_data.get("selected_choice_index", -1))
	dialogue_index = maxi(int(save_data.get("dialogue_index", 0)), 0)
	_chat_history = save_data.get("chat_history", []).duplicate(true)
	minigame_state = save_data.get("minigame_state", {}).duplicate(true)
	_pending_minigame = save_data.get("pending_minigame", {}).duplicate(true)
	_has_dialogue_override = bool(save_data.get("has_dialogue_override", false))
	_dialogue_override = save_data.get("dialogue_override", []).duplicate(true)


## Gửi snapshot của chapter hiện tại cho GameManager để ghi file save.
## Bỏ qua nếu chưa khởi tạo, đã hoàn thành hoặc scene này không còn là chapter đang chơi.
## Kiểm tra này ngăn callback của chapter cũ ghi đè tiến trình chapter vừa chuyển tới.
func save_progress() -> void:
	if story_finished or not _progress_initialized or GameManager.current_scene_path != scene_file_path or get_tree().current_scene != self:
		return
	GameManager.save_game(get_progress(), scene_file_path)


## Trả Dictionary chứa file truyện, index, lựa chọn, lịch sử và trạng thái cần lưu.
## Nếu minigame có get_save_state(), lấy thêm trạng thái ván đang chơi vào snapshot.
## Hàm chỉ gom dữ liệu; GameManager dùng nó khi thoát hoặc chuyển scene để ghi save.
func get_progress() -> Dictionary:
	if not _progress_initialized or story_finished:
		return {}
	if is_instance_valid(_active_minigame) and _active_minigame.has_method("get_save_state"):
		_pending_minigame["state"] = _active_minigame.call("get_save_state")
	return {
		"chapter_id": chapter_id,
		"current_story_path": current_story_path,
		"episode_index": episode_index,
		"scene_index": scene_index,
		"dialogue_index": dialogue_index,
		"continue_hint_dismissed": _continue_hint_dismissed,
		"selected_choice_index": selected_choice_index,
		"inline_choice_resolved": _inline_choice_resolved,
		"has_dialogue_override": _has_dialogue_override,
		"dialogue_override": _dialogue_override,
		"chat_history": _chat_history,
		"minigame_state": minigame_state,
		"pending_minigame": _pending_minigame,
		"chapter_state": get_chapter_state(),
		"fade_alpha": _get_saved_fade_alpha(),
		"completed": false,
	}


## Tính độ đen cuối cùng cần lưu: 0 là không che màn hình, 1 là đen hoàn toàn.
## Xét cả fade còn trong hàng đợi để Continue không dừng ở trạng thái màn hình nửa tối.
func _get_saved_fade_alpha() -> float:
	# Khi thoát giữa chuỗi fade, lưu trạng thái cuối thay vì màn hình nửa tối.
	var alpha := _fade_target_alpha
	for event in _event_queue:
		if not event is Dictionary:
			continue
		var event_type := str(event.get("type", ""))
		if event_type in ["fade", "fade_in", "fade_out"]:
			var direction := str(event.get("direction", "out" if event_type == "fade" else event_type.trim_prefix("fade_")))
			if direction in ["in", "out"]:
				alpha = 0.0 if direction == "in" else 1.0
	return alpha


## Đánh dấu chapter đã xong, ẩn Continue và phát signal cho GameManager điều phối.
## Chapter con có thể gọi hàm này khi logic riêng kết thúc; gọi nhiều lần vẫn chỉ báo một lần.
func complete_chapter() -> void:
	if story_finished:
		return
	story_finished = true
	continue_hint.hide()
	chapter_completed.emit()


## Điểm mở rộng: override trong chapter1.gd/chapter2.gd... để xử lý event riêng.
## Trả true nếu đã xử lý, false nếu không nhận diện; có thể await hiệu ứng hoặc minigame.
## Không gọi hàm này khi dựng lịch sử, tránh chạy lại gameplay đã xảy ra.
func _handle_chapter_event(_event: Dictionary) -> bool:
	return false


## Override ở chapter con để trả dữ liệu đặc thù cần đưa vào save, ví dụ cờ sự kiện.
## Mặc định trả Dictionary rỗng; chỉ lưu dữ liệu, không lưu Node hoặc Callable runtime.
func get_chapter_state() -> Dictionary:
	return {}


## Override ở chapter con để áp dụng dữ liệu đã lưu bởi get_chapter_state().
## Được gọi sau khi dựng lịch sử; khôi phục trạng thái thay vì phát lại sự kiện cũ.
func restore_chapter_state(_state: Dictionary) -> void:
	pass


## Tạo minigame từ PackedScene vào MinigameContainer và khóa tiếp tục hội thoại.
## event_id nhận diện kết quả trong save; scene phải có signal finished(result: Dictionary).
## Trả true nếu mở được; nếu có restore_state(), truyền trạng thái ván đang chơi vào đó.
func start_minigame(scene: PackedScene, event_id: String, event: Dictionary = {}) -> bool:
	if scene == null or is_instance_valid(_active_minigame):
		push_error("[ChapterBase] Minigame scene không hợp lệ hoặc đang có minigame hoạt động.")
		if scene == null:
			_pending_minigame = {}
		return false
	if minigame_state.has(event_id) and bool(minigame_state[event_id].get("completed", false)):
		return false
	var instance := scene.instantiate()
	if not instance.has_signal("finished"):
		push_error("[ChapterBase] Minigame thiếu signal finished(result: Dictionary).")
		instance.free()
		_pending_minigame = {}
		return false
	var saved_state: Dictionary = _pending_minigame.get("state", {})
	_pending_minigame = {"event": event.duplicate(true), "state": saved_state}
	_pending_minigame["event"]["type"] = "minigame"
	_pending_minigame["event"]["id"] = event_id
	_pending_minigame["event"]["scene"] = scene.resource_path
	_active_minigame = instance
	_active_minigame_id = event_id
	# Deferred để minigame có thể phát kết quả trong _ready mà bên gọi vẫn kịp await.
	instance.connect("finished", _on_minigame_finished, CONNECT_ONE_SHOT | CONNECT_DEFERRED)
	minigame_container.show()
	choice_container.get_parent().hide()
	_update_continue_hint()
	minigame_container.add_child(instance)
	if instance.has_method("restore_state"):
		instance.call("restore_state", saved_state)
	save_progress()
	return true


## Nhận signal finished của minigame, lưu completed/result và dọn instance cùng container.
## Phát minigame_completed để đoạn code đang chờ xử lý nhánh, rồi cập nhật UI và save.
func _on_minigame_finished(result: Dictionary) -> void:
	if _exiting or not is_instance_valid(_active_minigame):
		return
	var event_id := _active_minigame_id
	minigame_state[event_id] = {"completed": true, "result": result.duplicate(true)}
	_active_minigame.queue_free()
	_active_minigame = null
	_active_minigame_id = ""
	_pending_minigame = {}
	minigame_container.hide()
	minigame_completed.emit(event_id, result)
	_try_show_inline_choices()
	_update_continue_hint()
	save_progress()
