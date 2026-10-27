class_name StoryChapter
extends ChapterBase
## Mở rộng bộ đọc ChapterBase cho truyện năm chương: cờ, manh mối, nhánh theo ID và mốc lưu.
## Các chapter con chỉ cần cấu hình scene/JSON; luồng thoại và minigame cơ bản nằm ở lớp cha.

const Notebook = preload("res://scenes/ui/story_notebook.gd")
## Ba cờ chuẩn bị dùng để tổng kết và giải thích điều kiện mở kết thúc E1.
const PREPARATIONS = Notebook.FLAGS
var notebook: Control
# Giữ giờ gần nhất trong JSON để tên địa điểm của cảnh mới không ghi đè đồng hồ.
var _story_clock := ""


## Nạp cờ truyện trước khi lớp cha mở thoại, sau đó tạo sổ tay.
## Ghi mốc bằng call_deferred để chapter đã đăng ký với GameManager và phục hồi xong save.
func _ready() -> void:
	GameManager.load_campaign()
	super._ready()
	notebook = Notebook.new()
	add_child(notebook)
	call_deferred("_record_entry_checkpoint")


## Bổ sung mốc tại đầu cảnh khi chapter được mở từ save có sẵn ở dòng 0.
## Giữ mốc cũ nếu đã có để Continue không thay snapshot ban đầu bằng trạng thái về sau.
func _record_entry_checkpoint() -> void:
	# Chuyển chương tạo save tại dòng 0; lớp cha có thể đi qua nhánh phục hồi thay vì chơi mới.
	if not is_campaign() or story_finished or dialogue_index != 0:
		return
	var checkpoint := str(get_current_scene().get("checkpoint", ""))
	if not checkpoint.is_empty() and not GameManager.story_checkpoints.has(checkpoint):
		GameManager.remember_checkpoint(checkpoint, get_progress())


## Nhận diện dữ liệu chiến dịch hiện hành theo thư mục; fixture truyện cũ dùng cách đọc của lớp cha.
func is_campaign() -> bool:
	return current_story_path.begins_with("res://data/story/")


## Chuẩn bị thoại bằng lớp cha, rồi giữ giờ truyện gần nhất trên nhãn đồng hồ.
func load_scene_dialogues(show_location: bool = true) -> void:
	super.load_scene_dialogues(show_location)
	if is_campaign() and not _story_clock.is_empty():
		location_label.text = _story_clock


## Ghi nhớ trường time trước khi lớp cha tạo tin nhắn; cũng áp dụng khi dựng lịch sử Continue.
func _append_line(line: Dictionary, scroll: bool = true, play_sound: bool = true, animate: bool = true) -> void:
	if is_campaign() and not str(line.get("time", "")).is_empty():
		_story_clock = str(line["time"])
	super._append_line(line, scroll, play_sound, animate)


func _can_restore_line(line: Dictionary) -> bool:
	return not is_campaign() or matches(line.get("when", {}))


## Save cũ lưu bản sao thoại trước khi có ID nhạc: lấy cue mới từ đúng dòng đã đọc.
## Không xét lại when của lịch sử thật, vì cờ có thể đã đổi sau dòng đó.
func _process_json_events(line: Dictionary, animate: bool) -> void:
	if is_campaign() and not animate:
		var restored := line.duplicate(true)
		var events: Variant = restored.get("events", restored.get("event", []))
		var kept: Array = []
		for event in ([events] if events is Dictionary else events):
			if event is Dictionary and str(event.get("type", "")) != "change_music":
				kept.append(event)
		for scene in story_data["episodes"][0]["scenes"]:
			for authored in scene.get("dialogues", []):
				if str(authored.get("text", "")) != str(line.get("text", line.get("message", ""))) or authored.get("speaker", "") != line.get("speaker", ""):
					continue
				var cues: Variant = authored.get("events", authored.get("event", []))
				for cue in ([cues] if cues is Dictionary else cues):
					if cue is Dictionary and str(cue.get("type", "")) == "change_music":
						kept.append(cue)
		restored["events"] = kept
		super._process_json_events(restored, false)
		return
	super._process_json_events(line, animate)


## Trả true khi mọi cờ đều bằng giá trị yêu cầu; cờ chưa có được xem là false.
## Điều kiện rỗng luôn đúng, dùng cho dòng/nhánh mặc định.
func matches(conditions: Dictionary) -> bool:
	for key in conditions:
		if GameManager.campaign_state.get(key, false) != conditions[key]:
			return false
	return true


## Áp dụng set vào cờ truyện và thêm/cập nhật clue theo ID trong sổ tay.
## Chỉ sửa trạng thái trong bộ nhớ; nơi gọi quyết định thời điểm lưu tiến trình.
func apply_effects(data: Dictionary) -> void:
	for key in data.get("set", {}):
		GameManager.campaign_state[key] = data["set"][key]
	if data.has("clue"):
		var clue: Dictionary = data["clue"]
		var clues: Dictionary = GameManager.campaign_state.get("clues", {})
		clues[clue["id"]] = clue.duplicate(true)
		GameManager.campaign_state["clues"] = clues


## Bỏ qua dòng không thỏa when, áp dụng tác động của dòng mới rồi để lớp cha hiển thị.
## Dòng summary lấy nội dung từ ba việc chuẩn bị; cảnh có checkpoint ghi mốc ở dòng đầu.
func show_current_line() -> void:
	if is_campaign():
		while dialogue_index < current_dialogues.size() and not matches(current_dialogues[dialogue_index].get("when", {})):
			dialogue_index += 1
		if dialogue_index < current_dialogues.size() and _lines_shown <= dialogue_index:
			apply_effects(current_dialogues[dialogue_index])
			if current_dialogues[dialogue_index].has("summary"):
				current_dialogues[dialogue_index]["message"] = preparation_summary()
	super.show_current_line()
	if is_campaign() and dialogue_index == 0 and not story_finished:
		var checkpoint := str(get_current_scene().get("checkpoint", ""))
		if not checkpoint.is_empty():
			GameManager.remember_checkpoint(checkpoint, get_progress())


## Tạo đoạn tổng kết việc đã làm/còn thiếu từ các cờ hiện tại, không thay đổi điều kiện kết thúc.
func preparation_summary() -> String:
	var lines: Array[String] = ["Những việc đã chuẩn bị trước khi ngủ"]
	var all_preparations_ready := true
	for key in PREPARATIONS:
		var done := bool(GameManager.campaign_state.get(key, false))
		all_preparations_ready = all_preparations_ready and done
		lines.append("%s: %s" % ["Đã làm xong" if done else "Chưa làm xong", PREPARATIONS[key]])
	lines.append("Bạn đã chuẩn bị đủ để Vy nói trọn lời chào và Kiên trở về." if all_preparations_ready else "Bạn vẫn có thể đi tiếp, nhưng cần làm đủ các việc trên để mở thêm lựa chọn kết thúc.")
	return "\n".join(lines)


## Lọc lựa chọn theo when; requires được kiểm tra riêng để vẫn hiện lựa chọn đang khóa.
func _current_line_choices() -> Array:
	var choices: Array = []
	for choice in super._current_line_choices():
		if matches(choice.get("when", {})):
			choices.append(choice)
	return choices


## Dựng nút lựa chọn, khóa nút chưa đủ requires và ghi rõ việc chuẩn bị còn thiếu.
## Đặt focus vào nút khả dụng đầu tiên để người chơi có thể chọn bằng bàn phím.
func show_choices(choices: Array) -> void:
	super.show_choices(choices)
	for index in range(choices.size()):
		var choice: Dictionary = choices[index]
		var button := choice_container.get_child(index) as Button
		button.disabled = not matches(choice.get("requires", {}))
		if button.disabled:
			var missing: Array[String] = []
			for key in choice.get("requires", {}):
				if not bool(GameManager.campaign_state.get(key, false)):
					missing.append(PREPARATIONS.get(key, key))
			button.text += "\nCần làm thêm: " + ", ".join(missing)
		elif choice.has("description"):
			button.text += "\n" + str(choice["description"])
	_focus_available_choices()


## Xử lý xác nhận/hủy/tải mốc trước khi áp dụng lựa chọn và chuyển cảnh bằng go.
## Chặn thao tác khi sổ tay, sự kiện hoặc minigame đang mở; chỉ ghi cờ sau bước xác nhận.
func _on_choice_selected(choice: Dictionary) -> void:
	if is_instance_valid(notebook) and notebook.is_open():
		return
	if not is_campaign():
		super._on_choice_selected(choice)
		return
	if story_finished or _events_running or is_instance_valid(_active_minigame) or not matches(choice.get("requires", {})):
		return
	if choice.get("cancel", false):
		show_choices(_current_line_choices())
		return
	if choice.has("confirm"):
		var confirmed: Dictionary = choice.duplicate(true)
		confirmed.erase("confirm")
		confirmed["text"] = str(choice["confirm"])
		show_choices([confirmed, {"text": "Quay lại", "cancel": true}])
		return
	if choice.has("checkpoint"):
		GameManager.restore_checkpoint(str(choice["checkpoint"]))
		return
	apply_effects(choice)
	choice_overlay.hide()
	_inline_choice_resolved = true
	var reply := {"speaker": choice_speaker, "text": choice["text"]}
	if choice.has("avatar"):
		reply["avatar"] = choice["avatar"]
	_append_line(reply)
	if choice.has("go"):
		go_to_scene(str(choice["go"]))
	else:
		dialogue_index += 1
		show_current_line()
	save_progress()


## Tìm cảnh bằng ID trong episode đầu của chiến dịch, reset vị trí thoại rồi hiển thị và lưu.
## ID rỗng kết thúc chương; ID không tồn tại báo lỗi và giữ nguyên cảnh.
func go_to_scene(id: String) -> void:
	if id.is_empty():
		save_progress()
		complete_chapter()
		return
	var scenes: Array = story_data["episodes"][0]["scenes"]
	for index in range(scenes.size()):
		if str(scenes[index].get("id", "")) == id:
			episode_index = 0
			scene_index = index
			dialogue_index = 0
			_lines_shown = 0
			selected_choice_index = -1
			_has_dialogue_override = false
			_dialogue_override = []
			load_scene_dialogues()
			show_current_line()
			save_progress()
			return
	push_error("Không tìm thấy cảnh truyện: " + id)


## Chuyển theo next của cảnh: chuỗi ID hoặc nhánh đầu tiên thỏa when.
## Mảng nhánh cần có nhánh mặc định; truyện cũ vẫn chuyển tuần tự theo lớp cha.
func advance_scene() -> void:
	if not is_campaign():
		super.advance_scene()
		return
	var target: Variant = get_current_scene().get("next", "")
	if target is Array:
		for branch in target:
			if matches(branch.get("when", {})):
				go_to_scene(str(branch["go"]))
				return
		push_error("Cảnh truyện không có nhánh mặc định: " + _current_scene_id)
		return
	go_to_scene(str(target))


## Chỉ nhận tác động set/clue của sự kiện khi câu đố trả outcome = done và chapter chưa thoát.
## Sau đó lớp cha ghi kết quả, dọn câu đố và mở lại hội thoại.
func _on_minigame_finished(result: Dictionary) -> void:
	if not _exiting and result.get("outcome", "") == "done":
		apply_effects(_pending_minigame.get("event", {}))
	super._on_minigame_finished(result)


## Khi đọc hết chương 5, thêm kết thúc hợp lệ vào bộ sưu tập trước khi chuyển sang credits.
## Lớp cha bảo đảm signal hoàn thành chương chỉ phát một lần.
func complete_chapter() -> void:
	if is_campaign() and chapter_id == "chapter_05" and not story_finished:
		var ending := str(GameManager.campaign_state.get("ending_id", ""))
		if ending in ["E1", "E2", "E3", "E4"] and not GameManager.seen_endings.has(ending):
			GameManager.seen_endings.append(ending)
		save_progress()
	super.complete_chapter()


## Bổ sung điều kiện đóng sổ tay vào khóa tiếp tục thoại chung, dùng cho cả click/Enter và Auto.
func can_advance_dialogue() -> bool:
	if is_instance_valid(notebook) and notebook.is_open():
		return false
	return super.can_advance_dialogue()
