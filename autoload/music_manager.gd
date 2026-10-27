extends Node
## Hai player xuyên scene; tween chỉ đổi âm lượng player, không sửa bus Music/SFX.

const LIBRARY_PATH := "res://data/audio/music.json"
var tracks: Dictionary = {}
var crossfade_seconds := 1.5
var current_track_id := ""
var current_path := ""
var _players: Array[AudioStreamPlayer] = []
var _keys: Array[String] = ["", ""]
var _active := 0
var _transition: Tween
var _finished := false
var _warned: Dictionary = {}

var active_player: AudioStreamPlayer:
	get:
		return _players[_active]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIBRARY_PATH))
	if data is Dictionary:
		tracks = data.get("tracks", {})
		crossfade_seconds = maxf(float(data.get("crossfade_seconds", 1.5)), 0.0)
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % index
		player.bus = "Music"
		player.volume_linear = 0.0
		add_child(player)
		player.finished.connect(_on_finished.bind(index))
		_players.append(player)


func play_track(id: String, duration: float = -1.0) -> void:
	play_event({"id": id}, duration)


## path chỉ dành cho truyện cũ/menu; chiến dịch dùng ID trong thư viện.
func play_event(event: Dictionary, duration: float = -1.0, position: float = 0.0, finished: bool = false) -> void:
	var id := str(event.get("id", ""))
	var track: Dictionary = tracks.get(id, {}) if not id.is_empty() else event
	var path := str(track.get("path", ""))
	var key := id if not id.is_empty() else path
	var current_key := current_track_id if not current_track_id.is_empty() else current_path
	# Cả bản đã kết thúc cũng không tự phát lại khi vào Credit hoặc gặp cùng cue.
	if key == current_key:
		return
	current_track_id = id
	current_path = path
	_finished = finished
	var seconds := maxf(float(event.get("duration", crossfade_seconds)) if duration < 0.0 else duration, 0.0)
	if is_instance_valid(_transition):
		_transition.kill()
	var incoming := -1
	for index in range(2):
		if _keys[index] == key and _players[index].playing and not finished:
			incoming = index
			break
	if incoming < 0 and not finished:
		var stream := _load_stream(path, bool(track.get("loop", false)))
		if stream != null:
			# Giữ player nghe rõ hơn khi đổi liên tiếp; tái sử dụng player còn lại.
			var outgoing := 0 if _players[0].volume_linear >= _players[1].volume_linear else 1
			incoming = 1 - outgoing
			_clear_player(incoming)
			_players[incoming].stream = stream
			_keys[incoming] = key
			_players[incoming].play(clampf(position, 0.0, maxf(stream.get_length() - 0.01, 0.0)))
		else:
			if not _warned.has(key):
				_warned[key] = true
				push_warning("[Music] Chưa gán hoặc không đọc được âm thanh: %s (%s). Chuyển về im lặng." % [key, path])
	if incoming >= 0:
		_active = incoming
	if seconds <= 0.0:
		for index in range(2):
			_players[index].volume_linear = 1.0 if index == incoming else 0.0
		_finish_transition(incoming)
		return
	_transition = create_tween().set_parallel(true)
	for index in range(2):
		_transition.tween_property(_players[index], "volume_linear", 1.0 if index == incoming else 0.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transition.chain().tween_callback(_finish_transition.bind(incoming))


func _load_stream(path: String, loop: bool) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var source := ResourceLoader.load(path) as AudioStream
	if source == null:
		return null
	# Không sửa tài nguyên dùng chung hay phụ thuộc loop trong file .import.
	var stream := source.duplicate() as AudioStream
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = loop
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	return stream


func _finish_transition(incoming: int) -> void:
	for index in range(2):
		if index != incoming:
			_clear_player(index)
	_transition = null


func _clear_player(index: int) -> void:
	_players[index].stop()
	_players[index].stream = null
	_players[index].volume_linear = 0.0
	_keys[index] = ""


func _on_finished(index: int) -> void:
	if index == _active:
		_finished = true


## Cue có thể đang chờ đổi nền; lưu đích cần tới thay vì bản đang fade đi.
func snapshot(event: Dictionary) -> Dictionary:
	var result := event.duplicate(true)
	var same := str(event.get("id", "")) == current_track_id and (not current_track_id.is_empty() or str(event.get("path", "")) == current_path)
	result["position"] = active_player.get_playback_position() if same and active_player.playing else 0.0
	result["finished"] = _finished if same else false
	return result


func restore(state: Dictionary) -> void:
	play_event(state, -1.0, float(state.get("position", 0.0)), bool(state.get("finished", false)))
