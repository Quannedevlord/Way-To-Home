extends SceneTree
## Kiểm thử xuyên suốt chiến dịch: tuyến truyện, câu đố, mốc quay lại và bốn kết thúc.
## Chạy Godot --headless --path . --script res://tests/story_regression.gd; save riêng ở tests/.tmp/.

const FIRST := "res://scenes/chapters/chapter_01/chapter1.tscn"
const FLAGS := ["memory_verified", "farewell_ready", "anchor_ready"]
var manager: Node
var failures := 0
var checks := 0
var seen: Dictionary = {}
var resumed := false


## Chờ cây scene/autoload khởi tạo xong trước khi bắt đầu bộ kiểm thử.
func _initialize() -> void:
	call_deferred("run")


## Đếm kiểm tra và báo lỗi theo mô tả; dừng sớm khi có quá nhiều lỗi để tránh kéo dài lượt chạy.
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
		if failures > 4:
			quit(1)


## Chờ đổi scene/layout và hàng đợi hiệu ứng, nhưng trả quyền điều khiển khi gặp minigame.
## Có giới hạn số frame chờ để phát hiện hàng đợi bị kẹt.
func settle() -> void:
	for frame in range(4):
		await process_frame
	var count := 0
	while current_scene != null and current_scene.has_method("get_progress") and current_scene._events_running and not is_instance_valid(current_scene._active_minigame):
		await process_frame
		count += 1
		if count > 1000:
			check(false, "Event queue timed out")
			break


## Bắt đầu lượt mới từ menu, xác nhận xóa cờ/mốc rồi reset thống kê tuyến đang đi.
func start() -> void:
	manager.change_scene(manager.MAIN_MENU_PATH)
	await settle()
	manager.start_new_game()
	check(manager.campaign_state.is_empty() and manager.story_checkpoints.is_empty(), "New game resets flags and checkpoints")
	manager.change_scene(FIRST)
	await settle()
	seen = {}
	resumed = false


## Giả lập thao tác ui_accept trên chapter hiện tại rồi đợi xử lý ổn định.
func advance() -> void:
	var input := InputEventAction.new()
	input.action = "ui_accept"
	input.pressed = true
	current_scene._input(input)
	await settle()


## Giải câu đố bằng đáp án hoặc trợ giúp; kiểm tra khóa thoại, Continue giữa ván và hoàn thành một lần.
func solve(assisted: bool) -> void:
	var puzzle: Node = current_scene._active_minigame
	check(not puzzle.config.is_empty(), "Puzzle receives event configuration")
	var before: int = current_scene.dialogue_index
	await advance()
	check(current_scene.dialogue_index == before, "Puzzle blocks dialogue input")
	var answer: Array = puzzle.config["answer"]
	puzzle.choose(int(answer[0]))
	if not resumed and answer.size() > 1:
		var saved: Dictionary = puzzle.get_save_state()
		manager.save_game()
		var path: String = manager.current_scene_path
		manager.change_scene(manager.MAIN_MENU_PATH)
		await settle()
		manager.change_scene(path)
		await settle()
		puzzle = current_scene._active_minigame
		check(puzzle.get_save_state() == saved, "Resume preserves unfinished puzzle exactly")
		resumed = true
	if assisted:
		puzzle.assist()
	else:
		for index in answer:
			puzzle.choose(int(index))
	check(puzzle.solved, "Puzzle can be completed: " + str(puzzle.config) + " selected=" + str(puzzle.selected))
	puzzle.finish()
	puzzle.finish()
	await settle()
	check(not is_instance_valid(current_scene._active_minigame), "Puzzle finishes once and closes")


## Chọn nhánh có go bằng target, xử lý xác nhận nếu có và kiểm tra chưa chốt kết thúc quá sớm.
func choose_target(target: String) -> void:
	var chapter: Node = current_scene
	for choice in chapter._current_line_choices():
		if str(choice.get("go", "")) == target:
			chapter._on_choice_selected(choice)
			if choice.has("confirm"):
				check(not manager.campaign_state.has("ending_id"), "Ending is not committed before confirmation")
				var confirmed: Dictionary = choice.duplicate(true)
				confirmed.erase("confirm")
				chapter._on_choice_selected(confirmed)
			await settle()
			return
	check(false, "Missing choice to " + target)


## Tự đi qua truyện theo ánh xạ ID cảnh → đích trong options, giải minigame khi gặp.
## Các cờ skip_* bỏ việc chuẩn bị tương ứng; mặc định dừng trước lựa chọn kết thúc để kiểm tra.
func walk(options: Dictionary, stop_at_final: bool = true) -> void:
	for step in range(1200):
		await settle()
		if current_scene == null or not current_scene.has_method("is_campaign"):
			return
		var chapter: Node = current_scene
		var id: String = chapter._current_scene_id
		seen[id] = true
		if is_instance_valid(chapter._active_minigame):
			await solve(bool(options.get("assisted", false)))
		elif chapter.choice_container.get_parent().visible:
			if id == "c5choice" and stop_at_final:
				return
			var target: String = options.get(id, "")
			if id == "c4hub":
				if not manager.campaign_state.get("memory_verified", false) and not options.get("skip_memory", false):
					target = "c4a"
				elif not manager.campaign_state.get("farewell_ready", false) and not options.get("skip_farewell", false):
					target = "c4b"
				elif not manager.campaign_state.get("anchor_ready", false) and not options.get("skip_anchor", false):
					target = "c4c"
				else:
					target = "c4summary"
			if target.is_empty():
				target = str(chapter._current_line_choices()[0].get("go", ""))
			await choose_target(target)
		else:
			await advance()
	check(false, "Story failed to reach ending within step budget")


## Đọc hết kết thúc được chọn và xác nhận credits, cờ completed cùng bộ sưu tập đã lưu xuống đĩa.
func finish_ending(id: String) -> void:
	await choose_target(id.to_lower())
	await walk({}, false)
	check(manager.current_scene_path == manager.CREDITS_PATH, "Ending reaches credits: " + id)
	check(manager.campaign_state.get("ending_id", "") == id, "Explicit ending selection: " + id)
	check(manager.load_game().get("completed", false) and not manager.has_save(), "Credits preserve completion")
	manager.load_campaign()
	check(manager.campaign_state.get("ending_id", "") == id, "Ending persists on disk")
	check(manager.seen_endings.has(id), "Completed ending recorded in collection")


## Đọc/giải câu đố cho đến khi gặp lựa chọn ở cảnh id, có giới hạn bước để bắt vòng lặp lỗi.
func until_choice(id: String) -> void:
	for step in range(100):
		await settle()
		if current_scene._current_scene_id == id and current_scene.choice_container.get_parent().visible:
			return
		if is_instance_valid(current_scene._active_minigame):
			await solve(true)
		else:
			await advance()
	check(false, "Did not reach choice " + id)


## Chạy các tuyến đại diện, thử hủy xác nhận/tải mốc/sửa chuẩn bị và kiểm tra chơi mới giữ bộ sưu tập.
## Đổi save_path trước mọi thao tác chơi mới; mã thoát khác 0 khi có kiểm tra thất bại.
func run() -> void:
	manager = root.get_node("GameManager")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/.tmp"))
	manager.save_path = "res://tests/.tmp/story_save.save"
	var cases := [
		{"c1s4":"c1b", "c2s3":"c2b", "c3school":"c3a1", "c3a2":"c3record", "c4summary":"c4s2", "c4c":"c4anchor"},
		{"c1s4":"c1a", "c2s3":"c2a", "c3school":"c3b1", "c4summary":"c4s2", "c4c":"c4anchor", "assisted":true},
		{"c1s4":"c1c", "c2s3":"c2a", "c2meal":"c2photo", "c3s1":"c3school", "c3school":"c3b1", "c4summary":"c4s2", "c4c":"c4anchor"},
		{"c2s3":"c2b", "c3school":"c3a1", "c3a2":"c3borrow", "skip_memory":true, "c4summary":"c4s2", "c4c":"c4anchor"},
		{"c3school":"c3b1", "skip_memory":true, "skip_farewell":true, "skip_anchor":true, "c4summary":"c4s2"},
	]
	for index in range(cases.size()):
		print("STORY ROUTE ", index + 1)
		await start()
		await walk(cases[index])
		if current_scene == null or not current_scene.has_method("is_campaign"):
			check(false, "Route reached unexpected scene")
			break
		check(seen.has("c2a") != seen.has("c2b"), "Chapter 2 plays only one route")
		check(seen.has("c3a1") != seen.has("c3b1"), "Chapter 3 plays only one route")
		check(manager.campaign_state.get("clues", {}).has("map"), "Both routes acquire the map")
		check(manager.campaign_state.get("identity_confirmed", false), "Both routes confirm identity outside dreams")
		check(manager.story_checkpoints.has("preparation") and manager.story_checkpoints.has("final_choice"), "Both checkpoints exist")
		var ready := index < 3
		check(current_scene.matches(current_scene._current_line_choices()[0]["requires"]) == ready, "E1 gate matches actual preparation")
		if not ready:
			var old_id: String = current_scene._current_scene_id
			current_scene._on_choice_selected(current_scene._current_line_choices()[0])
			check(current_scene._current_scene_id == old_id and not manager.campaign_state.has("ending_id"), "Locked E1 cannot be selected")
		if index == 0:
			var waiting_index: int = current_scene.dialogue_index
			current_scene.notebook.open()
			current_scene._on_choice_selected(current_scene._current_line_choices()[1])
			await advance()
			check(current_scene.dialogue_index == waiting_index and not manager.campaign_state.has("ending_id"), "Notebook blocks underlying choices and dialogue")
			current_scene.notebook.close()
			# Hủy xác nhận kết thúc phải giữ nguyên cờ truyện và chưa ghi ending_id.
			for choice in current_scene._current_line_choices().slice(0, 3):
				current_scene._on_choice_selected(choice)
				current_scene._on_choice_selected({"cancel":true})
				check(not manager.campaign_state.has("ending_id"), "Cancel ending keeps state")
			await finish_ending("E1")
			for ending in ["E2", "E3"]:
				check(manager.restore_checkpoint("final_choice"), "Restore final checkpoint")
				await settle()
				check(not manager.campaign_state.has("ending_id"), "Checkpoint clears later ending")
				await finish_ending(ending)
			check(manager.restore_checkpoint("final_choice"), "Restore before E4")
			await settle()
			await choose_target("e4warning")
			while not current_scene.choice_container.get_parent().visible:
				await advance()
			await choose_target("c5choice")
			check(not manager.campaign_state.has("ending_id"), "E4 cancellation returns without committing")
			await choose_target("e4warning")
			while not current_scene.choice_container.get_parent().visible:
				await advance()
			await choose_target("e4")
			await walk({}, false)
			check(manager.campaign_state.get("ending_id") == "E4" and manager.campaign_state.get("anchor_ready", false), "E4 respects prepared anchor and explicit consent")
			check(manager.restore_checkpoint("preparation"), "Restore preparation checkpoint")
			await settle()
			check(not manager.campaign_state.get("anchor_ready", false) and not manager.campaign_state.get("farewell_ready", false), "Earlier checkpoint removes later preparation")
			check(manager.campaign_state.get("memory_verified", false), "Earlier checkpoint retains facts already learned")
			current_scene.go_to_scene("c4b")
			await until_choice("c4b")
			await choose_target("c4b2")
			await until_choice("c4b2")
			await choose_target("c4hub")
			check(not manager.campaign_state.get("farewell_ready", false), "Writing for Vy does not complete her farewell")
			await choose_target("c4b")
			await until_choice("c4b")
			await choose_target("c4b1")
			await until_choice("c4hub")
			check(manager.campaign_state.get("farewell_ready", false), "Can return and repair the farewell")
		else:
			await finish_ending("E1" if ready else "E2")
	manager.change_scene(manager.MAIN_MENU_PATH)
	await settle()
	check(manager.seen_endings.size() == 4, "Collection contains all four completed endings")
	manager.start_new_game()
	manager.load_campaign()
	check(manager.campaign_state.is_empty() and manager.story_checkpoints.is_empty() and manager.seen_endings.size() == 4, "New game clears campaign while preserving ending collection")
	stop_audio(root)
	await create_timer(0.2).timeout
	print("STORY REGRESSION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


## Dừng và gỡ stream của mọi player trước khi thoát để tài nguyên âm thanh được giải phóng.
func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
	for child in node.get_children():
		stop_audio(child)
