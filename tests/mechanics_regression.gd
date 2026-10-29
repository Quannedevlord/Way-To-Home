extends SceneTree
## Kiểm tra thao tác thật với thanh cuộn, xác nhận Chơi mới và đường rời mơ Chapter 4.
## Dùng save riêng trong tests/.tmp, không đụng tiến trình người chơi.

const CHAPTER4 := "res://scenes/chapters/chapter_04/chapter4.tscn"
const BEDROOM := "res://Giao_Dien/bg_phong_ngu_trua.png"
const AFTERNOON := "res://Giao_Dien/bg_phong_ngu_chieu_muon.png"
var manager: Node
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)


func settle() -> void:
	for frame in range(5):
		await process_frame
	var deadline := Time.get_ticks_msec() + 7000
	while manager.is_chapter_transition_active() or (current_scene != null and current_scene.has_method("get_progress") and current_scene._events_running):
		await process_frame
		if Time.get_ticks_msec() > deadline:
			check(false, "Scene finished loading")
			break


func pointer(viewport: Viewport, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = pressed
	viewport.push_input(event, true)


func motion(viewport: Viewport, point: Vector2, dragging: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if dragging else 0
	viewport.push_input(event, true)


func click(control: Control) -> void:
	await settle()
	var point := control.get_global_rect().get_center()
	var viewport := control.get_viewport()
	if viewport is Window and viewport != root and viewport.is_embedded():
		point += Vector2(viewport.position)
		viewport = root
	motion(viewport, point)
	pointer(viewport, point, true)
	pointer(viewport, point, false)
	await settle()


func key(viewport: Viewport, code: Key) -> void:
	if viewport is Window and viewport != root and viewport.is_embedded():
		viewport = root
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	viewport.push_input(event)
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event)
	await settle()


func until_choice() -> void:
	for step in range(50):
		await settle()
		if current_scene.choice_overlay.visible:
			return
		current_scene.advance_dialogue()
	check(false, "Reached a choice")


func choose(target: String) -> void:
	for choice in current_scene._current_line_choices():
		if choice.get("go", "") == target:
			current_scene._on_choice_selected(choice)
			await settle()
			return
	check(false, "Found choice " + target)


func resume(old_history: Array = []) -> void:
	var path: String = current_scene.scene_file_path
	manager.change_scene(manager.MAIN_MENU_PATH)
	await settle()
	if not old_history.is_empty():
		var config := ConfigFile.new()
		config.load(manager.save_path)
		config.set_value("progress", "chat_history", old_history)
		config.save(manager.save_path)
	manager.change_scene(path)
	await settle()


func check_context(path: String, time: String, description: String) -> void:
	check(current_scene.background.texture.resource_path == path, description + ": background")
	check(current_scene.location_label.text == time, description + ": clock")
	check(root.get_node("MusicManager").current_track_id == "BGM_TRUST", description + ": music")


func run() -> void:
	manager = root.get_node("GameManager")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/.tmp"))
	manager.save_path = "res://tests/.tmp/mechanics_regression.save"
	manager.start_new_game()
	manager.change_scene(manager.FIRST_CHAPTER_PATH)
	await settle()
	for step in range(12):
		current_scene.advance_dialogue()
		await settle()
	var bar: VScrollBar = current_scene.scroll_container.get_v_scroll_bar()
	check(bar.is_visible_in_tree(), "Long conversation has a scrollbar")
	var history: Array = current_scene._chat_history.duplicate(true)
	var flags: Dictionary = manager.campaign_state.duplicate(true)
	await click(bar)
	var point := bar.get_global_rect().get_center()
	pointer(root, point, true)
	motion(root, point - Vector2(0, 80), true)
	pointer(root, point - Vector2(0, 80), false)
	await settle()
	check(current_scene.dialogue_index == 12 and current_scene._chat_history == history, "Click and drag scrollbar leave dialogue unchanged")
	check(manager.campaign_state == flags, "Scrollbar cannot trigger story effects")
	point = current_scene.scroll_container.get_global_rect().get_center()
	motion(root, point)
	pointer(root, point, true)
	pointer(root, point, false)
	await settle()
	check(current_scene.dialogue_index == 13, "Ordinary chat click still advances")
	await key(root, KEY_ENTER)
	check(current_scene.dialogue_index == 14 and current_scene.choice_overlay.visible, "Enter still advances to choices")

	manager.change_scene(CHAPTER4)
	await settle()
	await until_choice()
	await choose("c4support")
	await until_choice()
	await choose("c4b")
	await until_choice()
	await choose("c4b2")
	await until_choice()
	await choose("c4hub")
	check_context(BEDROOM, "14:00", "Abandoning the letter wakes Kien")
	check(not manager.campaign_state.get("farewell_ready", false), "Abandoning does not complete the letter")
	await resume()
	check_context(BEDROOM, "14:00", "Continue after abandoning")
	flags = manager.campaign_state.duplicate(true)
	# Mô phỏng lịch sử từ bản chưa có biểu cảm và chưa sửa đường quay về.
	history = current_scene._chat_history.duplicate(true)
	for entry in history:
		entry.erase("avatar")
		if entry.get("text", "") == "Tạm dừng, quay lại sau":
			entry.erase("time")
			entry.erase("events")
	await resume(history)
	check_context(BEDROOM, "14:00", "Old save repairs the return context")
	check(manager.campaign_state == flags, "Old history does not replay story effects")
	var restored_choice := false
	for entry in current_scene._chat_history:
		if entry.get("text", "") == "Tạm dừng, quay lại sau":
			restored_choice = entry.get("avatar", "") == "res://assets/avatars/Avatar_Kien_Sad.png"
	check(restored_choice, "Old choice history gains the authored expression")

	manager.campaign_state["farewell_ready"] = true
	await choose("c4b")
	await until_choice()
	await choose("c4reread")
	await until_choice()
	check_context(BEDROOM, "14:00", "Rereading the letter wakes Kien")
	await resume()
	check_context(BEDROOM, "14:00", "Continue after rereading")
	await choose("c4summary")
	await until_choice()
	await choose("c4s2")
	check_context(AFTERNOON, "16:30", "Thu speaks in the real world before the last dream")
	await resume()
	check_context(AFTERNOON, "16:30", "Continue during Thu's conversation")
	while current_scene.dialogue_index < 6:
		current_scene.advance_dialogue()
		await settle()
	check(current_scene.location_label.text == "17:20", "Entering the last dream changes clock")
	check(root.get_node("MusicManager").current_track_id == "BGM_FINAL_ROAD", "Entering the last dream changes music")
	check(manager.restore_checkpoint("preparation"), "Preparation checkpoint can be restored")
	await settle()
	check(current_scene._current_scene_id == "c4s1" and current_scene.location_label.text == "07:00", "Checkpoint restores its own context")
	check(root.get_node("MusicManager").current_track_id == "BGM_DAILY", "Checkpoint restores its own music")

	manager.seen_endings = ["E2"]
	manager.save_game()
	manager.change_scene(manager.MAIN_MENU_PATH)
	await settle()
	var saved := FileAccess.get_file_as_string(manager.save_path)
	var checkpoints: Dictionary = manager.story_checkpoints.duplicate(true)
	var menu: Node = current_scene
	await click(menu.start_button)
	var dialog: ConfirmationDialog = menu.new_game_dialog
	check(is_instance_valid(dialog) and dialog.visible, "Existing progress requires confirmation")
	check(FileAccess.get_file_as_string(manager.save_path) == saved and manager.story_checkpoints == checkpoints, "Opening confirmation preserves save and checkpoints")
	check(dialog.gui_get_focus_owner() == dialog.get_cancel_button(), "Confirmation defaults to Cancel")
	menu._on_start_pressed()
	check(menu.new_game_dialog == dialog, "Repeated Start does not create another confirmation")
	await key(dialog, KEY_ESCAPE)
	check(not dialog.visible and current_scene == menu, "Esc cancels New Game")
	await click(menu.start_button)
	await key(dialog, KEY_ENTER)
	check(not dialog.visible and current_scene == menu, "Enter on default Cancel preserves progress")
	await click(menu.start_button)
	await click(dialog.get_cancel_button())
	check(FileAccess.get_file_as_string(manager.save_path) == saved, "Cancel leaves the save file unchanged")
	# Campaign hoàn tất vẫn phải bảo vệ các mốc có thể chơi lại.
	var config := ConfigFile.new()
	config.load(manager.save_path)
	config.set_value("progress", "completed", true)
	config.save(manager.save_path)
	check(not manager.has_save() and not manager.story_checkpoints.is_empty(), "Completed fixture retains checkpoints")
	await click(menu.start_button)
	check(dialog.visible, "Completed campaign still confirms before discarding checkpoints")
	await click(dialog.get_ok_button())
	check(current_scene.scene_file_path == manager.FIRST_CHAPTER_PATH and current_scene.dialogue_index == 0, "Confirm starts Chapter 1")
	check(manager.story_checkpoints.is_empty() and not manager.campaign_state.has("farewell_ready"), "Confirmed New Game resets campaign and checkpoints")
	check(manager.seen_endings == ["E2"], "Confirmed New Game preserves collected endings")
	manager.change_scene(manager.MAIN_MENU_PATH)
	await settle()
	manager.start_new_game()
	menu = current_scene
	menu._on_start_pressed()
	check(not is_instance_valid(menu.new_game_dialog), "No progress starts directly")
	await settle()
	check(current_scene.scene_file_path == manager.FIRST_CHAPTER_PATH, "Direct start opens Chapter 1")
	manager.change_scene(manager.MAIN_MENU_PATH)
	await settle()
	stop_audio(root)
	await create_timer(0.2).timeout
	print("MECHANICS REGRESSION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
	for child in node.get_children():
		stop_audio(child)
