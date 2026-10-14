extends ChapterBase


## Khởi tạo nền bằng `super._ready()` rồi kiểm tra cấu hình truyện của Chapter 2.
## Chưa có `story_path` thì hẹn chuyển chapter sau khi scene khởi tạo xong.
func _ready() -> void:
	super._ready()
	# Scene tạm vẫn bỏ qua chương khi chưa cấu hình story, như trước refactor.
	if story_path.is_empty():
		call_deferred("_continue_to_next_chapter")


## Báo hoàn thành chapter tạm để GameManager mở chapter kế tiếp hoặc credits.
## Chỉ thực hiện nếu scene này vẫn đang hoạt động, tránh callback của scene đã đóng.
func _continue_to_next_chapter() -> void:
	if get_tree().current_scene == self:
		complete_chapter()
