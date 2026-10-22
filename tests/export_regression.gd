extends SceneTree
## Kiểm tra chuyển đủ năm chapter trên project và gói export có scene .tscn.remap.
## Chạy với --script res://tests/export_regression.gd; save riêng trong tests/.tmp/.
## Với gói export, truyền -- --test-output-dir=<thư mục tuyệt đối để ghi save thử>.

var manager: Node
var checks := 0
var failures := 0
const CHAPTER_TITLES := [
	"Người lạ trong giấc mơ", "Chiếc vòng không có người nhận",
	"Người vắng mặt trong bức ảnh", "Điều chưa kịp nói", "Đường về nhà",
]


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, description: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	return ok


func settle() -> void:
	for frame in range(5):
		await process_frame


## Kiểm tra intro qua luồng thật: chữ/nền, khóa input/Auto, tự kết thúc và giữ dòng đầu.
func verify_intro(number: int) -> void:
	var intro := root.get_node_or_null("ChapterTransition")
	if not check(intro != null and manager.is_chapter_transition_active(), "Chapter %d has an intro" % number):
		return
	check(paused, "Chapter intro pauses gameplay")
	check(intro._number_label.text == "CHƯƠNG %d" % number, "Intro displays the destination chapter number")
	check(intro._title_label.text == CHAPTER_TITLES[number - 1], "Intro displays the correct Vietnamese title")
	var chapter: Node = current_scene
	var initial_line: int = chapter.dialogue_index
	var global_menu := root.get_node("GlobalMenu")
	var previous_mode: int = global_menu.auto_mode
	global_menu.auto_mode = 2
	global_menu._process(60.0)
	check(not global_menu.canvas_layer.visible, "Intro hides global controls")
	global_menu.auto_mode = previous_mode
	for action in ["ui_accept", "ui_cancel"]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = true
		root.push_input(event)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	root.push_input(touch)
	global_menu._open_settings()
	check(root.get_node_or_null("Setting") == null, "Settings cannot interrupt the intro")
	manager.change_to_next_chapter()
	check(current_scene == chapter and manager.current_scene_path == chapter.scene_file_path, "Duplicate transition cannot skip a chapter")
	await create_timer(1.2).timeout
	check(intro._overlay.color == Color.BLACK and is_equal_approx(intro._overlay.modulate.a, 1.0), "Title appears over an opaque black screen")
	check(is_equal_approx(intro._titles.modulate.a, 1.0), "Title fades fully into view")
	check(chapter.dialogue_index == initial_line, "Input and Auto cannot advance dialogue under the intro")
	var deadline := Time.get_ticks_msec() + 6000
	while manager.is_chapter_transition_active():
		await process_frame
		if Time.get_ticks_msec() > deadline:
			check(false, "Intro must end automatically")
			quit(1)
			return
	await settle()
	check(not paused and root.get_node_or_null("ChapterTransition") == null, "Intro releases pause and removes its overlay")
	check(chapter.dialogue_index == initial_line, "Chapter opens on its first line")


func run() -> void:
	manager = root.get_node("GameManager")
	# Trong bản export, đường dẫn tuyệt đối cho phép ghi save bên ngoài PCK.
	var save_directory := ProjectSettings.globalize_path("res://tests/.tmp")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--test-output-dir="):
			save_directory = argument.trim_prefix("--test-output-dir=")
	if not check(DirAccess.make_dir_recursive_absolute(save_directory) == OK, "Create isolated test save directory"):
		quit(1)
		return
	manager.save_path = save_directory.path_join("export_regression.save")
	manager.start_new_game()

	print("CHAPTER 2 PACK FILES: ", DirAccess.get_files_at("res://scenes/chapters/chapter_02"))
	if not check(manager.change_scene(manager.MAIN_MENU_PATH), "Open main menu"):
		quit(1)
		return
	await settle()
	current_scene._on_start_pressed()
	await settle()

	for number in range(1, 6):
		var expected := "res://scenes/chapters/chapter_%02d/chapter%d.tscn" % [number, number]
		if not check(manager.current_scene_path == expected and current_scene != null and current_scene.scene_file_path == expected, "Play chapter %d before credits" % number):
			break
		var chapter: Node = current_scene
		await verify_intro(number)
		if not check(not chapter.story_data.is_empty() and not chapter.current_dialogues.is_empty(), "Chapter %d loads JSON and dialogue from the package" % number):
			break
		var next_path := "res://scenes/chapters/chapter_%02d/chapter%d.tscn" % [number + 1, number + 1] if number < 5 else ""
		check(manager.get_next_chapter_path(expected) == next_path, "Resolve chapter after %d" % number)
		check(not bool(manager.load_game().get("completed", false)), "Chapter %d is not a completed campaign" % number)
		print("EXPORT CHAPTER ", number, ": loaded, next=", next_path)
		if number == 1:
			chapter.advance_dialogue()
			var saved_line: int = chapter.dialogue_index
			manager.change_scene(manager.MAIN_MENU_PATH)
			await settle()
			current_scene._on_continue_pressed()
			await settle()
			check(not manager.is_chapter_transition_active() and not paused, "Continue resumes without replaying the intro")
			check(current_scene.dialogue_index == saved_line, "Continue preserves the saved dialogue")
			chapter = current_scene
		# Dùng đúng signal hoàn thành của chapter để kiểm tra điều phối và save.
		chapter.complete_chapter()
		await settle()

	check(manager.current_scene_path == manager.CREDITS_PATH and current_scene != null and current_scene.scene_file_path == manager.CREDITS_PATH, "Credits follow chapter 5")
	check(bool(manager.load_game().get("completed", false)) and not manager.has_save(), "Credits save the completed campaign")
	manager.change_scene(manager.MAIN_MENU_PATH)
	await settle()
	stop_audio(root)
	await create_timer(0.2).timeout
	print("EXPORT REGRESSION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
	for child in node.get_children():
		stop_audio(child)
