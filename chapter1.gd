extends Control

# Các node này được nối sẵn trong chapter1.tscn (mục Node Paths của Inspector),
# không cần sửa gì ở đây trừ khi bạn đổi tên node trong scene.
@export var name_label: Label
@export var message_label: Label
@export var avatar: TextureRect
@export var char1: Control
@export var char2: Control
@export var choice_container: VBoxContainer
@export var dialogue_box: Control
@export var narration_box: Control
@export var narration_label: Label

const STORY_PATH := "res://data/story.json"

# Điền đường dẫn ảnh avatar thật của bạn vào đây khi có.
# Nếu chưa có ảnh, để trống "" — avatar sẽ ẩn khung ảnh đi, không báo lỗi.
var avatar_paths := {
	"Kiên": "res://assets/avatars/kien.png",
	"Vy": "res://assets/avatars/vy.png",
	"Thư": "res://assets/avatars/thu.png",
	"Thầy giáo": "",
}

var story_data: Dictionary = {}
var episode_index := 0
var scene_index := 0
var dialogue_index := 0
var current_dialogues: Array = []
var story_finished := false


func _ready() -> void:
	print("[Chapter1] _ready() bắt đầu")
	if not load_story(STORY_PATH):
		return
	load_scene_dialogues()
	show_current_line()


func load_story(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("[Chapter1] Không tìm thấy file: %s" % path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	var result = JSON.parse_string(text)

	if result == null:
		push_error("[Chapter1] File JSON bị lỗi cú pháp, không parse được: %s" % path)
		return false

	story_data = result
	print("[Chapter1] Đã load story, số episode = ", story_data.get("episodes", []).size())
	return true


func get_current_scene() -> Dictionary:
	return story_data["episodes"][episode_index]["scenes"][scene_index]


func load_scene_dialogues() -> void:
	var scene := get_current_scene()
	print("[Chapter1] Vào scene: ", scene.get("id", "?"), " - ", scene.get("location", "?"))

	choice_container.visible = false
	for child in choice_container.get_children():
		child.queue_free()

	if scene.has("dialogues"):
		current_dialogues = scene["dialogues"]
	elif scene.has("choices"):
		current_dialogues = []
		show_choices(scene["choices"])
	else:
		current_dialogues = []

	dialogue_index = 0


func show_current_line() -> void:
	if dialogue_index >= current_dialogues.size():
		if choice_container.visible:
			return # đang chờ người chơi bấm chọn, không tự next
		advance_scene()
		return

	var line: Dictionary = current_dialogues[dialogue_index]
	# Ưu tiên field "type" tường minh; nếu không có, đoán qua speaker để
	# tương thích ngược với dữ liệu cũ (speaker == "Narrator").
	var line_type: String = line.get("type", "narration" if not line.has("speaker") else "dialogue")

	if line_type == "narration":
		show_narration_line(line)
	else:
		show_dialogue_line(line)


func show_narration_line(line: Dictionary) -> void:
	print("[Chapter1] Miêu tả: ", line.get("message", ""))

	dialogue_box.visible = false
	avatar.get_parent().visible = false
	char1.visible = false
	char2.visible = false

	narration_box.visible = true
	narration_label.text = line.get("message", "")


func show_dialogue_line(line: Dictionary) -> void:
	var speaker: String = line.get("speaker", "")
	print("[Chapter1] Thoại: [", speaker, "] ", line.get("message", ""))

	narration_box.visible = false
	dialogue_box.visible = true

	name_label.visible = true
	name_label.text = speaker
	message_label.text = line.get("message", "")

	avatar.get_parent().visible = avatar_paths.get(speaker, "") != ""
	if avatar_paths.get(speaker, "") != "":
		avatar.texture = load(avatar_paths[speaker])

	char1.visible = (speaker == "Kiên")
	char2.visible = not char1.visible


func advance_scene() -> void:
	if story_finished:
		return

	var episode: Dictionary = story_data["episodes"][episode_index]
	scene_index += 1

	if scene_index >= episode["scenes"].size():
		scene_index = 0
		episode_index += 1
		if episode_index >= story_data["episodes"].size():
			print("[Chapter1] Đã hết dữ liệu hội thoại trong file.")
			story_finished = true
			dialogue_box.visible = false
			avatar.get_parent().visible = false
			char1.visible = false
			char2.visible = false
			narration_box.visible = true
			narration_label.text = "— Hết chương —"
			return

	load_scene_dialogues()
	show_current_line()


func show_choices(choices: Array) -> void:
	for choice in choices:
		var btn := Button.new()
		btn.text = choice.get("description", choice.get("option", "..."))
		btn.pressed.connect(_on_choice_selected.bind(choice))
		choice_container.add_child(btn)
	choice_container.visible = true


func _on_choice_selected(choice: Dictionary) -> void:
	choice_container.visible = false
	for child in choice_container.get_children():
		child.queue_free()
	current_dialogues = choice.get("dialogues", [])
	dialogue_index = 0
	show_current_line()


func _unhandled_input(event: InputEvent) -> void:
	if choice_container.visible:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
		dialogue_index += 1
		show_current_line()
