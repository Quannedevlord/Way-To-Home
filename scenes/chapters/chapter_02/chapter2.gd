extends Control


func _ready() -> void:
	call_deferred("_continue_to_next_chapter")


func _continue_to_next_chapter() -> void:
	if get_tree().current_scene == self:
		GameManager.change_to_next_chapter()
