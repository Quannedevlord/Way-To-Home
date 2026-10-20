extends SceneTree
## Kiểm tra chuyển đủ năm chapter trên project và gói export có scene .tscn.remap.
## Chạy với --script res://tests/export_regression.gd; save riêng trong tests/.tmp/.
## Với gói export, truyền -- --test-output-dir=<thư mục tuyệt đối để ghi save thử>.

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
	for frame in range(5):
		await process_frame


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
	if not check(manager.change_scene(manager.FIRST_CHAPTER_PATH), "Open chapter 1"):
		quit(1)
		return
	await settle()

	for number in range(1, 6):
		var expected := "res://scenes/chapters/chapter_%02d/chapter%d.tscn" % [number, number]
		if not check(manager.current_scene_path == expected and current_scene != null and current_scene.scene_file_path == expected, "Play chapter %d before credits" % number):
			break
		var chapter: Node = current_scene
		if not check(not chapter.story_data.is_empty() and not chapter.current_dialogues.is_empty(), "Chapter %d loads JSON and dialogue from the package" % number):
			break
		var next_path := "res://scenes/chapters/chapter_%02d/chapter%d.tscn" % [number + 1, number + 1] if number < 5 else ""
		check(manager.get_next_chapter_path(expected) == next_path, "Resolve chapter after %d" % number)
		check(not bool(manager.load_game().get("completed", false)), "Chapter %d is not a completed campaign" % number)
		print("EXPORT CHAPTER ", number, ": loaded, next=", next_path)
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
