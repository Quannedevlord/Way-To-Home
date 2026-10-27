extends SceneTree
## Godot --headless --path . --script res://tests/music_regression.gd

var music: Node
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
	while current_scene != null and current_scene.has_method("get_progress") and current_scene._events_running:
		await process_frame


func playing_count() -> int:
	var count := 0
	for player in music._players:
		if player.playing:
			count += 1
	return count


func run() -> void:
	music = root.get_node("MusicManager")
	manager = root.get_node("GameManager")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/.tmp"))
	manager.save_path = "res://tests/.tmp/music_save.save"
	manager.start_new_game()
	check(is_equal_approx(music.crossfade_seconds, 1.5), "Default crossfade is 1.5 seconds")
	music.play_track("BGM_DAILY", 0.0)
	check(playing_count() == 1 and music.active_player.bus == "Music", "Music uses its own bus and one active player")
	check(music.active_player.stream.loop, "Background track loops")
	music.active_player.seek(12.0)
	await create_timer(0.1).timeout
	var same_player: AudioStreamPlayer = music.active_player
	var same_stream: AudioStream = same_player.stream
	var position: float = same_player.get_playback_position()
	music.play_track("BGM_DAILY")
	check(music.active_player == same_player and same_player.stream == same_stream, "Repeated cue retains player and stream")
	check(same_player.get_playback_position() >= position - 0.1, "Repeated cue keeps playback position")

	var bus := AudioServer.get_bus_index("Music")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	var volume := AudioServer.get_bus_volume_db(bus)
	var muted := AudioServer.is_bus_mute(bus)
	var sfx_volume := AudioServer.get_bus_volume_db(sfx_bus)
	AudioServer.set_bus_volume_db(bus, -18.0)
	AudioServer.set_bus_mute(bus, true)
	var sfx := AudioStreamPlayer.new()
	sfx.bus = "SFX"
	sfx.stream = load("res://assets/sound_effect/schoolbell.mp3")
	root.add_child(sfx)
	sfx.play()
	music.play_track("BGM_DREAM", 0.4)
	await create_timer(0.1).timeout
	check(playing_count() == 2, "Both tracks play only during crossfade")
	check(music._players[0].volume_linear > 0.0 and music._players[1].volume_linear > 0.0, "Crossfade blends player gains")
	music.play_track("BGM_DAILY", 0.08)
	check(music.active_player == same_player and same_player.get_playback_position() > 10.0, "Reversing a fade reuses the outgoing track")
	for id in ["BGM_DREAM", "BGM_INVESTIGATION", "BGM_TRUST", "BGM_FINAL_ROAD"]:
		music.play_track(id, 0.08)
		await create_timer(0.02).timeout
	await create_timer(0.2).timeout
	check(playing_count() == 1 and music.get_child_count() == 2, "Rapid changes leave no extra players")
	check(music.current_track_id == "BGM_FINAL_ROAD", "Latest request wins")
	check(AudioServer.is_bus_mute(bus) and is_equal_approx(AudioServer.get_bus_volume_db(bus), -18.0), "Transitions preserve volume and mute")
	check(sfx.playing and AudioServer.get_bus_volume_db(sfx_bus) == sfx_volume, "Music changes do not interrupt SFX")
	sfx.stop()
	sfx.queue_free()
	AudioServer.set_bus_volume_db(bus, volume)
	AudioServer.set_bus_mute(bus, muted)

	var grief: Dictionary = music.tracks["BGM_GRIEF"].duplicate(true)
	music.tracks["BGM_GRIEF"]["path"] = ""
	music.play_track("BGM_GRIEF", 0.05)
	await create_timer(0.1).timeout
	check(playing_count() == 0 and music.current_track_id == "BGM_GRIEF", "Unassigned cue fades to silence")
	music.play_event({"path": "res://missing_music.mp3"}, 0.0)
	check(playing_count() == 0, "Missing path is safe")
	music.tracks["BGM_GRIEF"] = grief
	music.play_track("BGM_ENDING_E1", 0.0)
	check(not music.active_player.stream.loop, "Ending track does not loop")
	music.active_player.seek(music.active_player.stream.get_length() - 0.15)
	await create_timer(0.6).timeout
	check(not music.active_player.playing and music._finished, "Ending stops naturally")
	music.play_track("BGM_ENDING_E1")
	check(not music.active_player.playing, "Finished ending is not restarted by a repeated cue")
	var ended: Dictionary = music.snapshot({"id": "BGM_ENDING_E1"})
	music.play_track("BGM_DAILY", 0.0)
	music.restore(ended)
	await create_timer(1.6).timeout
	check(playing_count() == 0 and music.current_track_id == "BGM_ENDING_E1", "Restoring a finished ending stays silent")

	await test_resume()
	same_stream = null
	same_player = null
	await create_timer(1.6).timeout
	manager.change_scene(manager.MAIN_MENU_PATH)
	await settle()
	await create_timer(1.6).timeout
	for player in music._players:
		player.stop()
		player.stream = null
	await create_timer(0.2).timeout
	print("MUSIC REGRESSION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func test_resume() -> void:
	var chapter_path := "res://scenes/chapters/chapter_02/chapter2.tscn"
	manager.change_scene(chapter_path)
	await settle()
	for route in ["sleep", "outside"]:
		manager.campaign_state["route2"] = route
		manager.campaign_state["promise_vy"] = "help"
		current_scene.go_to_scene("c2s5")
		await settle()
		var expected := "BGM_INVESTIGATION" if route == "sleep" else "BGM_DREAM"
		check(music.current_track_id == expected, "c2s5 respects route2=" + route)
		music.active_player.seek(9.0)
		await create_timer(0.1).timeout
		manager.save_game()
		manager.change_scene(manager.MAIN_MENU_PATH)
		await settle()
		# Đợi menu chiếm player để kiểm tra seek từ snapshot, không dùng nhạc còn fade.
		await create_timer(1.6).timeout
		manager.change_scene(chapter_path)
		await settle()
		check(music.current_track_id == expected and music.active_player.get_playback_position() >= 8.0, "Continue restores track and position: " + route)
		check(current_scene._chat_history.filter(func(line: Dictionary) -> bool: return str(line.get("text", "")).begins_with("Đêm ấy Kiên")).size() == (0 if route == "sleep" else 1), "Skipped dialogue is absent from history")
		# Save cũ chỉ có index: điều kiện sai không được đưa cue vào lịch sử.
		var old_save: Dictionary = current_scene.get_progress().duplicate(true)
		manager.change_scene(manager.MAIN_MENU_PATH)
		await settle()
		manager.change_scene(chapter_path)
		old_save.erase("music_state")
		old_save["chat_history"] = []
		manager.save_game(old_save)
		var config := ConfigFile.new()
		config.load(manager.save_path)
		config.erase_section_key("progress", "music_state")
		config.save(manager.save_path)
		await settle()
		check(music.current_track_id == expected, "Index-only save filters conditional music: " + route)
		check(current_scene._chat_history.filter(func(line: Dictionary) -> bool: return str(line.get("text", "")).begins_with("Đêm ấy Kiên")).size() == (0 if route == "sleep" else 1), "Index-only history skips false when")
		# Save cũ có lịch sử dùng đường dẫn nhạc trước khi chuyển sang cấu hình ID.
		old_save = current_scene.get_progress().duplicate(true)
		for line in old_save["chat_history"]:
			for event in line.get("events", []):
				if event.get("type") == "change_music":
					event.erase("id")
					event["path"] = "res://assets/backgrounds/audio/bgm/Dream Portal (1).mp3"
		manager.change_scene(manager.MAIN_MENU_PATH)
		await settle()
		manager.change_scene(chapter_path)
		old_save.erase("music_state")
		manager.save_game(old_save)
		config.load(manager.save_path)
		config.erase_section_key("progress", "music_state")
		config.save(manager.save_path)
		await settle()
		check(music.current_track_id == expected, "Old history migrates to authored ID: " + route)
