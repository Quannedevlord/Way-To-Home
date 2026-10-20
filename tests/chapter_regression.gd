extends SceneTree
## Kiểm thử bộ đọc ChapterBase bằng truyện cũ: nhánh file, save/Continue, fade và giao thức minigame.
## Chạy Godot --headless --path . --script res://tests/chapter_regression.gd; scene/save tạm nằm trong tests/.tmp/.

# Scene thử nghiệm được tạo từ chapter1.tscn, nhưng dùng ChapterBase và fixture thay cho chiến dịch mới.
const CHAPTER1 := "res://tests/.tmp/chapter_01/chapter1.tscn"
const MAIN_STORY := "res://tests/fixtures/legacy_chapter_01/main_story.json"
const TEMP := "res://tests/.tmp"

var manager: Node
var failures := 0
var checks := 0


## Bắt đầu sau khi autoload đã có trong cây scene.
func _initialize() -> void:
	call_deferred("_run")


## Tăng tổng kiểm tra và báo lỗi có mô tả khi điều kiện không đạt.
func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)


## Đợi scene và sự kiện ổn định, không chờ minigame cần thao tác; báo lỗi nếu hàng đợi quá lâu.
func settle() -> void:
	for frame in range(4):
		await process_frame
	var attempts := 0
	while current_scene != null and current_scene.has_method("get_progress") and bool(current_scene.get("_events_running")) and not is_instance_valid(current_scene.get("_active_minigame")):
		await process_frame
		attempts += 1
		if attempts > 300:
			check(false, "Event queue không hoàn tất")
			break


## Mở chapter fixture và trả node sau khởi tạo; new_game xóa tiến trình trong save kiểm thử.
func open_chapter(new_game: bool = false) -> Node:
	if new_game:
		manager.start_new_game()
	manager.change_scene(CHAPTER1)
	await settle()
	return current_scene


## Gửi ui_accept trực tiếp đến chapter để thử tiếp tục thoại hoặc khóa input.
func accept(chapter: Node) -> void:
	var event := InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = true
	chapter._input(event)
	await settle()


## Lưu, về menu và mở lại fixture để mô phỏng Continue bằng một instance chapter mới.
func resume_chapter() -> Node:
	manager.save_game()
	manager.change_scene(manager.MAIN_MENU_PATH)
	await process_frame
	await process_frame
	check(manager.has_save(), "Menu giữ được save để Continue")
	return await open_chapter()


## Ghi dữ liệu JSON tạm cho từng tình huống kiểm thử vào đường dẫn do bộ kiểm thử cung cấp.
func write_json(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))


## Tạo fixture scene rồi chạy các kiểm tra đọc truyện, lưu nhánh, save cũ và chuyển chapter.
## Gọi thêm các nhóm kiểm tra chuyên biệt và trả mã thoát khác 0 nếu có lỗi.
func _run() -> void:
	manager = root.get_node("GameManager")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP))
	manager.save_path = TEMP + "/savegame.save"
	# Dùng truyện gốc làm fixture để tiếp tục kiểm tra bộ đọc cũ độc lập với nội dung chiến dịch.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP + "/chapter_01"))
	var legacy_script := FileAccess.open(TEMP + "/chapter_01/chapter1.gd", FileAccess.WRITE)
	legacy_script.store_string("extends ChapterBase\n")
	legacy_script.close()
	var fixture := FileAccess.get_file_as_string("res://scenes/chapters/chapter_01/chapter1.tscn")
	fixture = fixture.replace("uid=\"uid://cqn28ke6tf87y\"", "")
	fixture = fixture.replace("res://scenes/chapters/chapter_01/chapter1.gd", TEMP + "/chapter_01/chapter1.gd")
	fixture = fixture.replace("res://data/story/chapter_01.json", MAIN_STORY)
	var legacy_scene := FileAccess.open(CHAPTER1, FileAccess.WRITE)
	legacy_scene.store_string(fixture)
	legacy_scene.close()
	var chapter: Node = await open_chapter(true)
	check(chapter.get_script().get_base_script().get_global_name() == "ChapterBase", "Chapter 1 kế thừa ChapterBase")
	for property in ["chat_feed", "scroll_container", "location_label", "choice_container", "continue_hint", "minigame_container"]:
		check(is_instance_valid(chapter.get(property)), "Inspector/node: " + property)
	check(chapter.current_story_path == MAIN_STORY and chapter.dialogue_index == 0, "Chơi mới mở đúng file và dòng đầu")
	check(chapter.background.texture.resource_path == "res://assets/school.png", "Background đầu chương")
	check(chapter.bgm_player.stream.resource_path.ends_with("in game3.mp3"), "Nhạc mặc định")
	check(chapter.location_label.text == "07:50", "Ô đồng hồ hiển thị giờ từ truyện")
	check(chapter.continue_hint.visible, "Chơi mới hiện hướng dẫn tiếp tục")
	chapter = await resume_chapter()
	check(chapter.dialogue_index == 0 and chapter._chat_history.size() == 2, "Continue main_story không lặp dòng")
	check(chapter.continue_hint.visible, "Chưa nhấn tiếp tục thì tải lại vẫn có hướng dẫn")
	await test_continue_hint(chapter)
	for branch_index in range(2):
		chapter = await open_chapter(true)
		check(chapter.continue_hint.visible, "Chơi mới đặt lại hướng dẫn")
		while chapter.dialogue_index < chapter.current_dialogues.size() - 1:
			await accept(chapter)
			if chapter.dialogue_index == 13:
				check(chapter.location_label.text == "17:50", "Ô đồng hồ cập nhật khi thời gian truyện đổi")
			if chapter.dialogue_index == 19:
				check(chapter.background.texture.resource_path == "res://assets/hanhLang.png", "Ảnh vòng tay chỉ nằm trong chat")
		check(chapter.choice_container.get_parent().visible, "Hai lựa chọn xuất hiện cuối main_story")
		check(chapter.choice_container.get_child_count() == 2, "Giữ đủ hai lựa chọn")
		check(chapter.bgm_player.stream.resource_path.ends_with("Dream Portal (1).mp3"), "Đổi nhạc tại giấc mơ")
		chapter = await resume_chapter()
		check(chapter.choice_container.get_parent().visible, "Continue khi đang chờ lựa chọn")
		var choice: Dictionary = chapter._current_line_choices()[branch_index]
		chapter._on_choice_selected(choice)
		await settle()
		var branch_file := "dy.json" if branch_index == 0 else "tc.json"
		check(chapter.current_story_path.ends_with(branch_file), "Chọn nhánh " + branch_file)
		check(not chapter.continue_hint.visible, "Chuyển file nhánh không hiện lại hướng dẫn")
		check(chapter.episode_index == 0 and chapter.scene_index == 0 and chapter.dialogue_index == 0, "Reset index khi chuyển file")
		for line_index in range(2):
			var history_size: int = chapter._chat_history.size()
			chapter = await resume_chapter()
			check(chapter.current_story_path.ends_with(branch_file) and chapter.dialogue_index == line_index, "Continue " + branch_file + " dòng " + str(line_index))
			check(chapter._chat_history.size() == history_size, "Giữ lịch sử và lời lựa chọn ở " + branch_file)
			check(not chapter.continue_hint.visible, "Tải lại file nhánh vẫn ẩn hướng dẫn")
			check(chapter.background.texture.resource_path == "res://assets/dream.png", "Khôi phục background từ file trước")
			check(chapter.bgm_player.stream.resource_path.ends_with("Dream Portal (1).mp3"), "Khôi phục nhạc từ file trước")
			await accept(chapter)
		check(chapter.current_story_path.ends_with("endbranch.json"), "Nhánh nối đến endbranch")
		for line_index in range(chapter.current_dialogues.size()):
			chapter = await resume_chapter()
			check(chapter.current_story_path.ends_with("endbranch.json") and chapter.dialogue_index == line_index, "Continue endbranch dòng " + str(line_index))
			if line_index < chapter.current_dialogues.size() - 1:
				await accept(chapter)
		# Giữ scene cũ để xác minh save_progress sau signal không ghi đè chapter mới.
		var event := InputEventAction.new()
		event.action = "ui_accept"
		event.pressed = true
		chapter._input(event)
		check(manager.current_scene_path.ends_with("chapter2.tscn"), "Hoàn thành Chapter 1 chuyển Chapter 2")
		chapter.save_progress()
		check(manager.load_game().get("current_scene", "").ends_with("chapter2.tscn"), "Scene cũ không ghi đè save chapter mới")
		check(bool(manager.load_game().get("continue_hint_dismissed", false)), "Chuyển chapter giữ trạng thái đã xem hướng dẫn")
		await process_frame
		await process_frame
		await process_frame
		await process_frame
		check(manager.current_scene_path.ends_with("chapter2.tscn") and not current_scene.story_path.is_empty(), "Chapter 2 mở nội dung mới thay vì bỏ qua")
		for remaining_chapter in range(4):
			current_scene.complete_chapter()
			await settle()
		check(manager.current_scene_path == manager.CREDITS_PATH, "Hết Chapter 5 chuyển credits")
		manager.save_game()
		check(bool(manager.load_game().get("completed", false)) and not manager.has_save(), "Thoát tại credits giữ trạng thái completed")

	# Save cũ không có current_story_path: dùng story Inspector, clamp index.
	manager.change_scene(manager.MAIN_MENU_PATH)
	await process_frame
	await process_frame
	manager.current_scene_path = CHAPTER1
	manager.clear_save()
	manager.save_game({"episode_index": 999, "scene_index": 999, "dialogue_index": 999, "selected_choice_index": -1})
	chapter = await open_chapter()
	check(chapter.current_story_path == MAIN_STORY and chapter.dialogue_index == chapter.current_dialogues.size() - 1, "Save cũ dùng story mặc định và clamp index")
	check(bool(chapter.get_progress().get("continue_hint_dismissed", false)), "Save cũ không bắt người chơi xem lại hướng dẫn")
	var before: Dictionary = manager.load_game()
	manager.save_game()
	check(manager.load_game() == before, "save_game lúc thoát giữ snapshot đầy đủ")
	check(not manager.save_game({"dialogue_index": 0}, "res://old_chapter.tscn"), "Từ chối lưu từ chapter cũ")

	# File truyện đã gỡ: bỏ vị trí/lịch sử nhánh cũ và mở lại đầu chương.
	manager.change_scene(manager.MAIN_MENU_PATH)
	await settle()
	manager.current_scene_path = CHAPTER1
	manager.clear_save()
	manager.save_game({
		"current_story_path": "res://removed_story/branch.json",
		"episode_index": 0, "scene_index": 0, "dialogue_index": 2,
		"chat_history": [{"text": "Lịch sử của nhánh đã gỡ"}],
		"selected_choice_index": 1,
	})
	chapter = await open_chapter()
	check(chapter.current_story_path == MAIN_STORY and chapter.dialogue_index == 0, "Truyện đã gỡ trở về đầu chương hiện hành")
	check(chapter.selected_choice_index == -1 and chapter._chat_history.size() == 2, "Không phục hồi lựa chọn hoặc lịch sử của file đã gỡ")
	check(manager.load_game().get("current_story_path", "") == MAIN_STORY, "Lưu lại đường dẫn truyện hiện hành sau khi phục hồi")

	# Events fade chạy tuần tự, thay nền, khôi phục opacity cuối cùng.
	chapter._queue_json_events([
		{"type": "fade_out", "duration": 0.01},
		{"type": "change_background", "path": "res://assets/bedroom2.png", "duration": 0.01},
		{"type": "fade_in", "duration": 0.01},
	])
	await settle()
	check(is_zero_approx(chapter._fade_overlay.color.a), "Fade out/background/in hoàn tất")
	check(chapter.background.texture.resource_path == "res://assets/bedroom2.png", "Event đổi nền")
	check(not is_instance_valid(chapter._background_transition_layer), "Dọn transition layer")
	check(chapter._resolve_story_path("sub/../dy.json") == "res://tests/fixtures/legacy_chapter_01/dy.json", "next_file giữ đường dẫn tương đối theo file hiện tại")
	chapter.fade_screen("out", 0.01)
	await create_timer(0.02).timeout
	chapter = await resume_chapter()
	check(is_equal_approx(chapter._fade_overlay.color.a, 1.0), "Continue giữ opacity fade đã lưu")
	chapter.fade_screen("in", 0.01)
	await create_timer(0.02).timeout
	chapter._queue_json_events([{"type": "fade_out", "duration": 0.01}, {"type": "fade_in", "duration": 0.01}])
	check(is_zero_approx(chapter.get_progress()["fade_alpha"]), "Save giữa chuỗi fade giữ opacity cuối cùng")
	await settle()

	await test_minigame()
	await test_structured_story()
	await test_chapter_event_hooks()
	manager.change_scene(manager.MAIN_MENU_PATH)
	await process_frame
	await process_frame
	change_scene_to_file(CHAPTER1)
	await settle()
	check(manager.current_scene_path == CHAPTER1, "Chạy chapter trực tiếp đăng ký đúng scene với GameManager")
	manager.change_scene(manager.MAIN_MENU_PATH)
	await process_frame
	await process_frame
	stop_audio(root)
	await create_timer(0.1).timeout
	print("CHAPTER REGRESSION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


## Xác nhận hướng dẫn chỉ ẩn sau lần đọc tiếp hợp lệ và giữ trạng thái qua Continue/chơi mới.
func test_continue_hint(chapter: Node) -> void:
	chapter._queue_json_events([{"type": "fade_in", "duration": 0.01}])
	await accept(chapter)
	check(chapter.dialogue_index == 0 and chapter.continue_hint.visible, "Input bị khóa trong sự kiện không bỏ hướng dẫn")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	chapter._input(click)
	check(chapter.continue_hint.visible, "Nhấn chuột phải không bỏ hướng dẫn")
	await accept(chapter)
	check(chapter.dialogue_index == 1 and not chapter.continue_hint.visible, "Nhấn tiếp tục bằng bàn phím ẩn hướng dẫn")
	chapter = await resume_chapter()
	check(chapter.dialogue_index == 1 and not chapter.continue_hint.visible, "Tải lại sau lần tiếp tục đầu tiên vẫn ẩn hướng dẫn")
	manager.change_scene(manager.MAIN_MENU_PATH)
	await process_frame
	await process_frame
	chapter = await open_chapter(true)
	check(chapter.continue_hint.visible, "Chơi mới từ menu hiện lại hướng dẫn")
	click.button_index = MOUSE_BUTTON_LEFT
	chapter._input(click)
	await settle()
	check(chapter.dialogue_index == 1 and not chapter.continue_hint.visible, "Nhấn tiếp tục bằng chuột ẩn hướng dẫn")
	check(bool(manager.load_game().get("continue_hint_dismissed", false)), "Lưu trạng thái đã xem hướng dẫn sau click")
	manager.change_scene(manager.MAIN_MENU_PATH)
	await process_frame
	await process_frame


## Tạo minigame giả để thử signal/state, khôi phục ván dở và chuyển nhánh theo kết quả.
## Kiểm tra minigame đã hoàn thành không bị chạy lại khi dựng lịch sử.
func test_minigame() -> void:
	# Test double chỉ kiểm tra giao thức signal/state, không có gameplay mẫu.
	var stub_source := "extends Control\nsignal finished(result: Dictionary)\nvar state: Dictionary = {}\nfunc get_save_state() -> Dictionary:\n\treturn state\nfunc restore_state(value: Dictionary) -> void:\n\tstate = value\n"
	var script_file := FileAccess.open(TEMP + "/minigame_stub.gd", FileAccess.WRITE)
	script_file.store_string(stub_source)
	script_file.close()
	var instance := Control.new()
	instance.set_script(load(TEMP + "/minigame_stub.gd"))
	var packed := PackedScene.new()
	packed.pack(instance)
	ResourceSaver.save(packed, TEMP + "/minigame_stub.tscn")
	instance.free()
	var event := {"type": "minigame", "id": "test_gate", "scene": TEMP + "/minigame_stub.tscn", "branches": {"win": "branches/win.json"}}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP + "/branches"))
	write_json(TEMP + "/story.json", [{"type": "narration", "text": "test", "event": event}, {"text": "after"}])
	write_json(TEMP + "/branches/win.json", [{"text": "branch"}, {"text": "end"}])
	manager.change_scene(manager.MAIN_MENU_PATH)
	await process_frame
	await process_frame
	manager.clear_save()
	manager.current_scene_path = CHAPTER1
	manager.save_game({"current_story_path": TEMP + "/story.json", "episode_index": 0, "scene_index": 0, "dialogue_index": 0, "continue_hint_dismissed": false})
	var chapter: Node = await open_chapter()
	check(is_instance_valid(chapter._active_minigame), "Mở minigame sau khi phục hồi dòng chưa hoàn thành")
	check(not chapter.continue_hint.visible and chapter.minigame_container.visible, "Minigame khóa Continue và hiện container")
	var dialogue_index: int = chapter.dialogue_index
	await accept(chapter)
	check(chapter.dialogue_index == dialogue_index, "Input bị khóa khi minigame hoạt động")
	chapter._active_minigame.state = {"step": 3}
	chapter = await resume_chapter()
	check(chapter._active_minigame.state == {"step": 3}, "Minigame đang chơi khôi phục state")
	chapter._active_minigame.emit_signal("finished", {"outcome": "win", "score": 10})
	await settle()
	check(not is_instance_valid(chapter._active_minigame) and not chapter.minigame_container.visible, "Đóng và dọn minigame")
	check(chapter.current_story_path == TEMP + "/branches/win.json", "Kết quả quyết định file nhánh tương đối")
	check(chapter.minigame_state["test_gate"]["completed"], "Lưu kết quả completed")
	check(chapter.continue_hint.visible, "Chưa tiếp tục thì hướng dẫn hiện sau minigame")
	chapter = await resume_chapter()
	check(not is_instance_valid(chapter._active_minigame) and not chapter._events_running, "Dựng lại lịch sử không mở minigame đã xong")
	check(chapter.minigame_state["test_gate"]["result"]["score"] == 10, "Giữ kết quả trong save")
	# Completed ở ngay dòng chứa event cũng không chạy lại minigame.
	manager.change_scene(manager.MAIN_MENU_PATH)
	await process_frame
	await process_frame
	manager.clear_save()
	manager.current_scene_path = CHAPTER1
	event.erase("branches")
	write_json(TEMP + "/same_line.json", [{"text": "test", "event": event}, {"text": "after"}])
	manager.save_game({"current_story_path": TEMP + "/same_line.json", "episode_index": 0, "scene_index": 0, "dialogue_index": 0})
	chapter = await open_chapter()
	chapter._active_minigame.emit_signal("finished", {"outcome": "done"})
	await settle()
	chapter = await resume_chapter()
	check(not is_instance_valid(chapter._active_minigame), "Continue ngay dòng minigame completed không chạy lại")
	await accept(chapter)
	check(chapter.dialogue_index == 1, "Sau minigame tiếp tục truyện")


## Thử JSON dạng episodes/scenes với lựa chọn ở cấp cảnh và ngay trong dòng thoại.
## Sau Continue, nhánh dialogues riêng phải được phục hồi đúng.
func test_structured_story() -> void:
	write_json(TEMP + "/structured.json", {"episodes": [{"scenes": [
		{"id": "first", "location": "test", "choices": [{"text": "choose", "dialogues": [{"text": "chosen"}, {"text": "chosen2"}]}]},
		{"id": "second", "dialogues": [{"text": "inline", "choices": [{"text": "inline choice", "dialogues": [{"text": "override"}, {"text": "override2"}]}]}]},
	]}]})
	manager.change_scene(manager.MAIN_MENU_PATH)
	await process_frame
	await process_frame
	manager.clear_save()
	manager.current_scene_path = CHAPTER1
	manager.save_game({"current_story_path": TEMP + "/structured.json", "episode_index": 0, "scene_index": 0, "dialogue_index": 0})
	var chapter: Node = await open_chapter()
	check(chapter.choice_container.get_parent().visible, "JSON episodes hỗ trợ choices của scene")
	chapter._on_choice_selected(chapter.get_current_scene()["choices"][0])
	await settle()
	chapter = await resume_chapter()
	check(chapter.selected_choice_index == 0 and chapter.current_dialogues[0]["message"] == "chosen", "Khôi phục thoại/lựa chọn trong scene có choices")
	await accept(chapter)
	await accept(chapter)
	check(chapter.scene_index == 1 and chapter.choice_container.get_parent().visible, "Chuyển scene rồi hiện inline choices")
	chapter._on_choice_selected(chapter._current_line_choices()[0])
	await settle()
	chapter = await resume_chapter()
	check(chapter.current_dialogues[0]["message"] == "override" and not chapter.choice_container.get_parent().visible, "Khôi phục dialogues từ inline choice")


## Tạo chapter giả có hook đồng bộ/bất đồng bộ; chỉ chạy hook lúc chơi, bỏ qua khi dựng lịch sử.
func test_chapter_event_hooks() -> void:
	for asynchronous in [false, true]:
		var mode := "async" if asynchronous else "sync"
		var script_path := TEMP + "/chapter_hook_" + mode + ".gd"
		var source := "extends \"res://scenes/chapters/base/chapter_base.gd\"\nvar handled := false\nfunc _handle_chapter_event(_event: Dictionary) -> bool:\n"
		if asynchronous:
			source += "\tawait Engine.get_main_loop().process_frame\n"
		source += "\thandled = true\n\treturn true\n"
		var file := FileAccess.open(script_path, FileAccess.WRITE)
		file.store_string(source)
		file.close()
		var chapter: Node = load(script_path).new()
		await chapter._process_json_event({"type": "test_custom"}, false)
		check(not chapter.handled, "Không chạy hook " + mode + " khi dựng lại lịch sử")
		await chapter._process_json_event({"type": "test_custom"}, true)
		check(chapter.handled, "Đợi hook " + mode + " xử lý xong trước khi tiếp tục")
		chapter.free()


## Dừng và gỡ các AudioStreamPlayer trước khi thoát để không giữ tài nguyên âm thanh.
func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
	for child in node.get_children():
		stop_audio(child)
