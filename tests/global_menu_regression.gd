extends SceneTree
## Kiểm thử nút Auto/cài đặt, phím Esc, focus bàn phím và tạm dừng khi đang chơi câu đố.
## Chạy Godot --headless --path . --script res://tests/global_menu_regression.gd; dùng save tests/.tmp/global_menu.save.

var checks := 0
var failures := 0


## Hoãn chạy kiểm thử đến khi autoload và cây scene đã sẵn sàng.
func _initialize() -> void:
	call_deferred("run")


## Ghi nhận kết quả từng kiểm tra để tổng hợp lỗi và chọn mã thoát cuối lượt chạy.
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)


## Chờ vài frame để input, queue_free và layout hoàn tất trước khi đọc trạng thái UI.
func settle() -> void:
	for frame in range(5):
		await process_frame


## Gửi cả nhấn và thả Esc qua viewport; echo = true mô phỏng phím tự lặp khi giữ.
func escape(echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	event.echo = echo
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await settle()


## Gửi di chuyển chuột và click trái vào tâm control để kiểm tra đường xử lý input thực của UI.
func click(control: Control) -> void:
	# Container cần hoàn tất bố cục trước khi lấy tọa độ của nút vừa tạo.
	await settle()
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await settle()


## Mở câu đố với save riêng, kiểm tra lớp cài đặt/pause/focus và lưu-tiếp tục sau khi về menu.
## Khi chạy có đồ họa, lưu thêm ảnh lớp phủ; mã thoát khác 0 nếu có lỗi.
func run() -> void:
	var manager := root.get_node("GameManager")
	var global_menu := root.get_node("GlobalMenu")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/.tmp"))
	manager.save_path = "res://tests/.tmp/global_menu.save"
	manager.start_new_game()
	manager.change_scene(manager.FIRST_CHAPTER_PATH)
	await create_timer(0.5).timeout
	await test_auto_play(global_menu, manager)
	current_scene.go_to_scene("c1s2")
	await create_timer(0.3).timeout
	for index in range(current_scene.current_dialogues.size()):
		if current_scene.current_dialogues[index].has("event"):
			current_scene.dialogue_index = index
			current_scene.show_current_line()
			break
	await settle()
	var puzzle: Node = current_scene._active_minigame
	check(is_instance_valid(puzzle), "Minigame active")
	if not is_instance_valid(puzzle):
		quit(1)
		return
	puzzle.choose(0)
	puzzle.cards.get_child(1).grab_focus()
	var puzzle_state: Dictionary = puzzle.get_save_state()
	var line_index: int = current_scene.dialogue_index
	check(global_menu.auto_button.is_visible_in_tree(), "Auto remains visible above minigame")
	await click(global_menu.auto_button)
	check(global_menu.auto_mode == 2, "Auto speed can be changed while waiting for minigame")
	global_menu._process(60.0)
	check(current_scene.dialogue_index == line_index and puzzle.get_save_state() == puzzle_state, "Auto never plays or skips an unfinished minigame")
	check(global_menu.menu_button.is_visible_in_tree(), "Gear remains visible during minigame")
	await click(global_menu.menu_button)
	var settings: Node = root.get_node_or_null("Setting")
	check(settings != null, "Click gear opens settings over minigame")
	if settings == null:
		quit(1)
		return
	var previous_focus: Control = settings._previous_focus
	check(paused and not puzzle.can_process(), "Settings pause the puzzle")
	check(settings.get_node("CanvasLayer").layer > global_menu.canvas_layer.layer, "Settings draw above the global button and chapter overlays")
	for property in ["close_button", "music_slider", "sfx_slider", "fullscreen_toggle", "returnMainMenu_button"]:
		check(is_instance_valid(settings.get(property)), "Settings Inspector reference: " + property)
	check(root.gui_get_focus_owner() == settings.close_button, "Focus moves into settings")
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
		DisplayServer.window_set_position(Vector2i(-32000, -32000))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/global_menu_above_minigame.png")
	await escape(true)
	check(root.get_node_or_null("Setting") == settings, "Holding Esc does not repeatedly toggle settings")
	await escape()
	check(root.get_node_or_null("Setting") == null and not paused, "Esc closes settings and resumes")
	check(current_scene._active_minigame == puzzle and puzzle.get_save_state() == puzzle_state, "Closing preserves unfinished puzzle")
	check(current_scene.dialogue_index == line_index, "Esc does not advance dialogue")
	check(root.gui_get_focus_owner() == previous_focus, "Focus returns to the control used before settings")
	puzzle.cards.get_child(1).grab_focus()
	await escape()
	settings = root.get_node_or_null("Setting")
	check(settings != null and paused, "Esc opens settings from minigame")
	await click(settings.close_button)
	check(root.get_node_or_null("Setting") == null and not paused, "Close button remains clickable above minigame")
	check(root.gui_get_focus_owner() == puzzle.cards.get_child(1), "Opening with Esc then closing returns focus to puzzle")
	await escape()
	await click(root.get_node("Setting").returnMainMenu_button)
	check(current_scene.name == "MainMenu" and not paused, "Settings can return to main menu")
	check(global_menu.auto_mode == 0 and not global_menu.auto_button.is_visible_in_tree(), "Returning to main menu turns Auto off and hides the button")
	check(manager.load_game().get("pending_minigame", {}).get("state", {}) == puzzle_state, "Return to menu saves puzzle progress")
	manager.change_scene(manager.FIRST_CHAPTER_PATH)
	await settle()
	check(is_instance_valid(current_scene._active_minigame) and current_scene._active_minigame.get_save_state() == puzzle_state, "Continue restores puzzle after leaving through settings")
	check(global_menu.auto_mode == 0, "Continue does not automatically enable Auto")
	await click(global_menu.auto_button)
	puzzle = current_scene._active_minigame
	puzzle.choose(1)
	puzzle.choose(2)
	check(puzzle.solved, "Restored puzzle can be completed")
	global_menu._process(60.0)
	check(is_instance_valid(current_scene._active_minigame), "Auto still waits for the puzzle Continue button")
	await click(puzzle.finish_button)
	check(not is_instance_valid(current_scene._active_minigame), "Player can leave the solved puzzle while Auto is enabled")
	global_menu._process(current_scene.get_auto_read_delay() + 0.1)
	check(current_scene.dialogue_index == line_index + 1, "Auto resumes after player finishes minigame")
	manager.change_scene(manager.MAIN_MENU_PATH)
	await settle()
	await escape()
	check(root.get_node_or_null("Setting") == null, "Esc in main menu does not open hidden global menu")
	current_scene._on_setting_pressed()
	await settle()
	check(root.get_node_or_null("Setting") != null, "Settings still open from main menu")
	await escape()
	check(root.get_node_or_null("Setting") == null and not paused, "Esc closes main-menu settings without reopening")
	stop_audio(root)
	await create_timer(0.2).timeout
	print("GLOBAL MENU REGRESSION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


## Kiểm tra chu kỳ Auto thường/x2/tắt, thời gian đọc và các điểm phải chờ người chơi.
## Kiểm tra bằng frame thật trước, sau đó chủ động truyền delta để thử ranh giới thời gian.
func test_auto_play(global_menu: Node, manager: Node) -> void:
	var chapter: Node = current_scene
	check(global_menu.auto_mode == 0 and global_menu.auto_button.text == "Auto: Tắt", "Auto starts disabled")
	var auto_rect: Rect2 = global_menu.auto_button.get_global_rect()
	var menu_rect: Rect2 = global_menu.menu_button.get_global_rect()
	check(auto_rect.end.x < menu_rect.position.x and absf(auto_rect.position.y - menu_rect.position.y) < 1.0, "Auto sits next to the gear without overlapping it")
	chapter.advance_dialogue()
	var line_index: int = chapter.dialogue_index
	await click(global_menu.auto_button)
	check(global_menu.auto_mode == 1 and chapter.dialogue_index == line_index, "Click enables normal Auto without skipping dialogue")
	await create_timer(1.0).timeout
	check(chapter.dialogue_index == line_index, "Normal Auto allows time to read the line")
	await create_timer(1.15).timeout
	check(chapter.dialogue_index == line_index + 1, "Normal Auto advances through the real frame loop")
	# Điều khiển delta cho các ranh giới thời gian còn lại, tránh phụ thuộc FPS.
	global_menu.set_process(false)
	line_index = chapter.dialogue_index
	await click(global_menu.auto_button)
	check(global_menu.auto_mode == 2 and global_menu.auto_button.text == "Auto x2", "Second click enables x2")
	var delay: float = chapter.get_auto_read_delay()
	check(delay > 2.0, "Longer dialogue receives more reading time")
	global_menu._process(delay / 2.0 - 0.1)
	check(chapter.dialogue_index == line_index, "x2 does not advance before half the normal delay")
	global_menu._process(0.11)
	check(chapter.dialogue_index == line_index + 1, "x2 advances at half the normal delay")
	check(int(manager.load_game().get("dialogue_index", -1)) == chapter.dialogue_index, "Auto saves progress after advancing")
	check(is_equal_approx(Engine.time_scale, 1.0), "x2 does not change game, music or minigame speed")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/auto_button_x2.png")
	await click(global_menu.auto_button)
	line_index = chapter.dialogue_index
	global_menu._process(60.0)
	check(global_menu.auto_mode == 0 and chapter.dialogue_index == line_index, "Third click turns Auto off immediately")
	await click(global_menu.auto_button)
	global_menu._process(chapter.get_auto_read_delay() - 0.1)
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	root.push_input(accept)
	accept = accept.duplicate()
	accept.pressed = false
	root.push_input(accept)
	await settle()
	check(chapter.dialogue_index == line_index + 1 and global_menu.auto_mode == 1, "Enter advances manually without changing Auto mode")
	global_menu._process(0.2)
	check(chapter.dialogue_index == line_index + 1, "Manual advance gives the new line a full reading delay")
	line_index = chapter.dialogue_index
	global_menu._process(chapter.get_auto_read_delay() - 0.3)
	await escape()
	global_menu._process(60.0)
	check(chapter.dialogue_index == line_index and paused, "Settings pause Auto")
	await escape()
	global_menu._process(0.2)
	check(chapter.dialogue_index == line_index and global_menu.auto_mode == 1, "Closing settings resumes Auto with a fresh reading delay")
	chapter.notebook.open()
	global_menu._process(60.0)
	check(chapter.dialogue_index == line_index, "Notebook pauses Auto")
	chapter.notebook.close()
	global_menu._process(0.2)
	check(chapter.dialogue_index == line_index, "Closing notebook gives a fresh reading delay")
	chapter.go_to_scene("c1s2")
	global_menu._process(60.0)
	check(chapter.dialogue_index == 0, "Auto waits for queued background and music events")
	await create_timer(0.3).timeout
	global_menu._process(0.2)
	check(chapter.dialogue_index == 0, "Event completion does not consume the reading delay")
	chapter.go_to_scene("c1s1")
	await create_timer(0.3).timeout
	chapter.dialogue_index = chapter.current_dialogues.size() - 1
	chapter.show_current_line()
	line_index = chapter.dialogue_index
	global_menu._process(60.0)
	check(chapter.dialogue_index == line_index and chapter.choice_overlay.visible, "Auto waits for the player's story choice")
	await click(chapter.choice_container.get_child(0))
	check(chapter._current_scene_id == "c1notice" and chapter.dialogue_index == 0, "Player choice works while Auto is enabled")
	global_menu._process(0.2)
	check(chapter._current_scene_id == "c1notice", "Choice starts a fresh reading delay")
	global_menu._process(chapter.get_auto_read_delay())
	check(chapter._current_scene_id == "c1s2" and chapter.dialogue_index == 0, "Auto advances through story scene transitions")
	await create_timer(0.3).timeout
	chapter.complete_chapter()
	await create_timer(0.4).timeout
	global_menu._process(0.2)
	check(current_scene.chapter_id == "chapter_02" and global_menu.auto_mode == 1, "Auto mode carries across chapter transitions")
	check(manager.is_chapter_transition_active() and paused, "Chapter intro pauses reading")
	await create_timer(4.0).timeout
	check(not manager.is_chapter_transition_active() and not paused, "Reading resumes after chapter intro")
	manager.change_scene(manager.FIRST_CHAPTER_PATH)
	await create_timer(0.4).timeout
	global_menu.set_process(true)


## Dọn stream âm thanh đệ quy trước khi kết thúc tiến trình kiểm thử.
func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
	for child in node.get_children():
		stop_audio(child)
