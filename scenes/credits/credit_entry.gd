class_name CreditEntry
extends Resource
## Dữ liệu của một mục cảm ơn, cho phép chỉnh chữ và ảnh ngay trong Inspector.
## credits.gd đọc các Resource này theo thứ tự trong mảng credit_entries.

## Đoạn chữ nằm trên ảnh của mục này; có thể xuống dòng để ghi tên, vai trò hoặc lời cảm ơn.
@export_multiline var text := ""
## Ảnh nằm ngay dưới Text; để trống nếu mục chỉ cần chữ.
@export var image: Texture2D
