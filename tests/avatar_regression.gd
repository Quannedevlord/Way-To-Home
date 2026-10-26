extends SceneTree
## Kiểm tra avatar thực sự hiển thị khi đổi biểu cảm, chọn nhánh và tiếp tục save.
## Chạy Godot --headless --path . --script res://tests/avatar_regression.gd.

const FIRST := "res://scenes/chapters/chapter_01/chapter1.tscn"
const SURPRISED := "res://assets/avatars/Avatar_Kien_Sudden.png"
const SAD := "res://assets/avatars/Avatar_Kien_Sad.png"
var manager: Node
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, description: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	return ok


func settle() -> void:
	for frame in range(4):
		await process_frame
	var deadline := Time.get_ticks_msec() + 6000
	while manager.is_chapter_transition_active() or (current_scene != null and current_scene.has_method("get_progress") and current_scene._events_running):
		await process_frame
		if Time.get_ticks_msec() > deadline:
			check(false, "Chapter finished loading")
			break


func texture_in(message: Node) -> TextureRect:
	for texture in message.find_children("*", "TextureRect", true, false):
		return texture as TextureRect
	return null


func last_portrait(chapter: Node) -> TextureRect:
	return texture_in(chapter.chat_feed.get_child(chapter.chat_feed.get_child_count() - 1))


func check_portrait(texture: TextureRect, path: String, visible_avatar: bool, description: String) -> void:
	if not check(texture != null and texture.texture != null, description + ": texture exists"):
		return
	check(texture.texture.resource_path == path, description + ": correct expression")
	# Compact chat hides the avatar's wrapper, while retaining its space in the row.
	check((texture.get_parent().get_parent().modulate.a > 0.0) == visible_avatar, description + ": avatar visibility")


func advance() -> void:
	var event := InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = true
	current_scene._input(event)
	await settle()


func resume() -> void:
	manager.save_game()
	manager.change_scene(manager.MAIN_MENU_PATH)
	await settle()
	manager.change_scene(FIRST)
	await settle()


func run() -> void:
	manager = root.get_node("GameManager")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/.tmp"))
	manager.save_path = "res://tests/.tmp/avatar_regression.save"
	manager.start_new_game()
	manager.change_scene(FIRST)
	await settle()
	for index in range(2):
		await advance()
	check(current_scene.dialogue_index == 2, "Reached Kien's first spoken line")
	check_portrait(last_portrait(current_scene), SURPRISED, true, "Kien arrives late, startled")
	await advance()
	check_portrait(last_portrait(current_scene), SAD, true, "Next Kien line changes to an apologetic expression")
	await resume()
	check(current_scene.dialogue_index == 3, "Continue preserves the current line")
	check_portrait(last_portrait(current_scene), SAD, true, "Continue preserves the visible expression change")
	var chapter: Node = current_scene
	var same_expression: Dictionary = chapter.current_dialogues[3].duplicate(true)
	chapter._append_line(same_expression, false, false, false)
	check_portrait(last_portrait(chapter), SAD, false, "Same speaker and same expression stay compact")
	chapter._append_line({"type": "narration", "text": "Khoảng nghỉ giữa hai câu thoại."}, false, false, false)
	chapter._append_line(same_expression, false, false, false)
	check_portrait(last_portrait(chapter), SAD, true, "Narration starts a new visible avatar group")

	# Each supplied portrait is loaded by a real authored line, not just checked on disk.
	var examples: Dictionary = {}
	for number in range(1, 6):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/chapter_%02d.json" % number))
		for scene in data["episodes"][0]["scenes"]:
			for line in scene["dialogues"]:
				if line.has("avatar"):
					examples[line["avatar"]] = line
	check(examples.size() == 12, "Campaign uses all twelve supplied expression portraits")
	for path in examples:
		chapter._append_line({"type": "narration", "text": ""}, false, false, false)
		chapter._append_line(examples[path], false, false, false)
		check_portrait(last_portrait(chapter), path, true, "Authored portrait " + str(path).get_file())

	# An authored choice must retain its avatar when appended to history and restored.
	chapter.go_to_scene("c1s4")
	chapter.dialogue_index = chapter.current_dialogues.size() - 1
	chapter.show_current_line()
	var choice: Dictionary = chapter._current_line_choices()[2]
	var choice_text: String = choice["text"]
	check(choice.get("avatar") == SURPRISED, "The frightened choice has its own avatar")
	chapter._on_choice_selected(choice)
	await settle()
	check(chapter._current_scene_id == "c1c", "Choice still follows its authored branch")
	var reply: Dictionary = {}
	for entry in chapter._chat_history:
		if entry.get("text", "") == choice_text:
			reply = entry
	check(reply.get("avatar") == SURPRISED, "Choice avatar is recorded in chat history")
	var expected_history: Array = chapter._chat_history.duplicate(true)
	await resume()
	chapter = current_scene
	check(chapter._chat_history == expected_history, "Continue preserves history including choice avatars")
	check_portrait(last_portrait(chapter), SAD, true, "Branch expression displays after Continue")
	var choice_visible := false
	for message in chapter.chat_feed.get_children():
		for label in message.find_children("*", "Label", true, false):
			if label.text == choice_text:
				check_portrait(texture_in(message), SURPRISED, true, "Restored choice shows its authored expression")
				choice_visible = true
	check(choice_visible, "Restored choice is present in the visible chat")
	var normalized: Array = chapter._normalize_choices([{"text": "test", "avatar": "Avatar_Kien_Sad.png"}])
	check(normalized[0]["avatar"] == SAD, "Choice avatars accept the same asset remapping as dialogue")
	manager.change_scene(manager.MAIN_MENU_PATH)
	await settle()
	stop_audio(root)
	await create_timer(0.2).timeout
	print("AVATAR REGRESSION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
	for child in node.get_children():
		stop_audio(child)
